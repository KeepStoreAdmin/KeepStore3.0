[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$OnlyUnit, [switch]$SkipSite, [switch]$Cleanup, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# EXPORT-FEED-ENGINE-1A. Prova del motore dei feed (App_Code\KeepStoreFeedEngine.vb, KeepStoreFeedService.vb, feed.aspx):
#  (A) prova unitaria del motore puro (formati, escape, nomi XML, spedizione a token esatti, arrotondamenti, scarti) + mutazioni del motore;
#  (B) controlli sul sorgente del servizio (blocco con scope del database, connessione dedicata, tetti, 304 dopo l'autorizzazione, nessuna colonna di promozione della vista) + mutazioni;
#  (C) prova HTTP sul sito LAB (https, 127.0.0.1 forzato, porta 18843, database LAB, identita verificata prima di scrivere) con la migrazione REALE di docs\EXPORT_FEED_DB_SCRIPTS.md:
#      prezzo del sito per utente anonimo (14 casi di promozione sintetici + oracolo SQL su tutto il catalogo), formati, 304/HEAD/ETag, revoca, nuovo codice, URL statico negato,
#      azienda del feed, errori di configurazione senza pubblicare, cooldown, un solo lavoratore sotto richieste sovrapposte, nessuna interrogazione con file pronto, prestazioni.
# Scrive solo righe sintetiche (ID 9301-9330, offerte 9990101-9990140), tre campi di UN articolo (ripristinati) e i file in Public\assets\images\export del SITO LAB; la migrazione si annulla alla fine con il rollback.
# Durata circa 12 minuti con le mutazioni: con Tools\Run-KeepStoreRelatedTests.ps1 serve -TimeoutSec 1800 (il tempo predefinito di 480 s interrompe la prova e lascia sul LAB la migrazione e le righe
# sintetiche). Se la prova e stata interrotta: rilanciare con -Cleanup (riporta LAB e sito allo stato iniziale; non fa nient'altro).
# Un solo uso del sito LAB alla volta: mutex Global\KeepStoreLabSite18843. Mai password in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$exit = 0
$e2e = New-Object Collections.Generic.List[string]
$script:stopFirst = $false
function Check([bool]$ok, [string]$name) {
    if ($ok) { if (-not $script:stopFirst) { Write-Host ('  ok   ' + $name) } } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) }
}
function Read-Repo([string]$rel) { return ([IO.File]::ReadAllText((Join-Path $root $rel), $utf8)).Replace("`r`n", "`n") }
$tmp = Join-Path $env:TEMP ('ks-exportfeedengine-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'

# ====================================================================================================================
# (A) motore puro: compilazione con il collaudo e mutazioni
# ====================================================================================================================
$engineSrc = Read-Repo 'App_Code\KeepStoreFeedEngine.vb'
function Run-Unit([string]$engineText) {
    $dir = Join-Path $tmp ('u' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $dir | Out-Null
    $eng = Join-Path $dir 'KeepStoreFeedEngine.vb'; [IO.File]::WriteAllText($eng, $engineText, $utf8)
    $exe = Join-Path $dir 'h.exe'
    $b = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ ('/out:' + $exe) /reference:System.dll /reference:System.Core.dll (Join-Path $root 'Tools\ExportFeedEngineHarness.vb') $eng 2>&1
    if (-not (Test-Path -LiteralPath $exe)) { return @{ Compiled = $false; Out = (($b | Select-Object -First 3) -join ' | '); Code = -1; Fails = @() } }
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& $exe 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE } finally { $ErrorActionPreference = $prevEap }
    return @{ Compiled = $true; Out = ($o -join "`n"); Code = $code; Fails = @($o | Where-Object { $_ -match '^FAIL ' }) }
}
Write-Host '(A) motore puro'
$u = Run-Unit $engineSrc
Check ($u.Compiled) 'A0 il motore compila (Option Strict) con il collaudo'
if ($u.Compiled) {
    Write-Host ('  ' + (@($u.Out -split "`n" | Where-Object { $_ -match '^ok ' }).Count) + ' casi unitari ok')
    Check ($u.Code -eq 0 -and $u.Fails.Count -eq 0) ('A1 prova unitaria del motore: nessun caso fallito (' + (($u.Fails | Select-Object -First 3) -join '; ') + ')')
}

$engineMutants = @(
    @('token-esatti-persi', 'AndAlso n = listino Then Return True', 'AndAlso part.Trim().Contains(listino.ToString(Invariant)) Then Return True'),
    @('arrotondamento-pari', 'Math.Round(value, 2, MidpointRounding.AwayFromZero)', 'Math.Round(value, 2, MidpointRounding.ToEven)'),
    @('virgolette-non-raddoppiate', 'v.Replace(delim, delim & delim)', 'v'),
    @('separatore-nel-valore', 'sb.Append(v.Replace(sep, " "))', 'sb.Append(v)'),
    @('caratteri-xml-non-tolti', 'If c = 9 OrElse c = 10 OrElse c = 13 OrElse (c >= &H20 AndAlso c <= &HD7FF) OrElse (c >= &HE000 AndAlso c <= &HFFFD) Then sb.Append(ch)', 'sb.Append(ch)'),
    @('separatore-uguale-decimale', 'If sep = opts.DecimalSeparator AndAlso String.IsNullOrEmpty(opts.TextDelimiter) Then Return "CONFIG_SEPARATORE_DECIMALE"', ''),
    @('prefisso-su-vuoto', "If String.IsNullOrWhiteSpace(value) Then Return `"`"`n        value = Truncate", 'value = Truncate'),
    @('coppia-surrogata', 'If cut.Length > 0 AndAlso Char.IsHighSurrogate(cut(cut.Length - 1)) Then cut = cut.Substring(0, cut.Length - 1)', ''),
    @('tag-non-tolti', 'text = TagRegex.Replace(text, " ")', ''),
    @('campo-sconosciuto', 'If Not KnownTokens.Contains(m.Groups(1).Value) Then Return m.Groups(1).Value', ''),
    @('altro-feed-toccato', 'Regex.Escape(scope & "-" & exportId.ToString(Invariant) & "-")', 'Regex.Escape(scope & "-")'),
    @('fascia-peso', 'If weight <= band.Key Then Return band.Value', 'If weight < band.Key Then Return band.Value'),
    @('token-minuscolo', '^[0-9A-F]{48}$', '^[0-9A-Fa-f]{48}$'),
    @('nome-xml-riservato', 'If name.StartsWith("xml", StringComparison.OrdinalIgnoreCase) Then Return False', ''),
    @('tsv-senza-tab', 'If NormalizeFormat(opts.Format) = "tsv" Then Return vbTab', ''),
    @('giacenza-zero-disponibile', 'If row.Stock > 0D Then Return opts.WordAvailable', 'If row.Stock >= 0D Then Return opts.WordAvailable'),
    @('percorso-con-vuoti', 'If c.Length > 0 Then parts.Add(c)', 'parts.Add(c)'),
    @('minuscolo-su-vuoto', "Private Shared Function CapitalizeLower(ByVal text As String) As String`n        If String.IsNullOrEmpty(text) Then Return `"`"", "Private Shared Function CapitalizeLower(ByVal text As String) As String`n        If text Is Nothing Then Return `"`""),
    @('latin1-eccezione', 'Return Encoding.GetEncoding(28591, New EncoderReplacementFallback("?"), DecoderFallback.ReplacementFallback)', 'Return Encoding.GetEncoding(28591, New EncoderExceptionFallback(), DecoderFallback.ReplacementFallback)'),
    @('prezzo-zero-pubblicato', 'If opts.SkipZeroPrice AndAlso row.Price <= 0D Then Return "PREZZO_ZERO"', 'If opts.SkipZeroPrice AndAlso row.Price < 0D Then Return "PREZZO_ZERO"'),
    @('http-non-riscritto', 'Return "https://" & url.Substring(7)', 'Return url'),
    @('etag-senza-lunghezza', 'lastWriteTicks.ToString("x", Invariant) & "-" & length.ToString("x", Invariant)', 'lastWriteTicks.ToString("x", Invariant) & "-"'),
    @('link-con-http', 'Return "https://" & ctx.Domain & "/articolo.aspx?id="', 'Return "http://" & ctx.Domain & "/articolo.aspx?id="'),
    @('nome-senza-id', 'Return scope & "-" & exportId.ToString(Invariant) & "-" & token & "-" & fingerprint & "." & NormalizeFormat(format)', 'Return scope & "-" & token & "-" & fingerprint & "." & NormalizeFormat(format)'),
    @('nome-senza-impronta', 'Return scope & "-" & exportId.ToString(Invariant) & "-" & token & "-" & fingerprint & "." & NormalizeFormat(format)', 'Return scope & "-" & exportId.ToString(Invariant) & "-" & token & "." & NormalizeFormat(format)'),
    @('impronta-senza-lunghezze', 'sb.Append(v.Length.ToString(Invariant)).Append(":"c).Append(v).Append(";"c)', 'sb.Append(v)'),
    @('impronta-con-nothing-diverso', 'Dim v As String = NZ(p)', 'Dim v As String = If(p Is Nothing, "NULL", p)'),
    @('vecchio-file-senza-impronta-resta', '[0-9A-F]{48}(-[0-9a-f]{12})?\.(txt|csv|tsv|xml)$', '[0-9A-F]{48}-[0-9a-f]{12}\.(txt|csv|tsv|xml)$'),
    @('anteprima-riga-incompleta', 'If lines.Count > 0 AndAlso (cutByBytes OrElse lines(lines.Count - 1).Length = 0) Then lines.RemoveAt(lines.Count - 1)', 'If lines.Count > 0 AndAlso lines(lines.Count - 1).Length = 0 Then lines.RemoveAt(lines.Count - 1)'),
    @('anteprima-senza-tetto-righe', 'If lines.Count > maxLines Then lines.RemoveRange(maxLines, lines.Count - maxLines)', '')
)
if (-not $SkipMutants -and $u.Compiled) {
    $killed = 0; $total = 0
    foreach ($m in $engineMutants) {
        if ($MutantFilter -ne '' -and $m[0] -notlike ('*' + $MutantFilter + '*')) { continue }
        $total++
        if (-not $engineSrc.Contains($m[1])) { Write-Host ('  FAIL mutante ' + $m[0] + ': testo da mutare non trovato'); $e2e.Add('mutante ' + $m[0] + ' non applicabile'); continue }
        $r = Run-Unit ($engineSrc.Replace($m[1], $m[2]))
        if ($r.Compiled -and ($r.Code -ne 0 -or $r.Fails.Count -gt 0)) { $killed++; Write-Host ('  ok   mutante ' + $m[0] + ' ucciso') }
        elseif (-not $r.Compiled) { Write-Host ('  FAIL mutante ' + $m[0] + ' non compila: ' + $r.Out); $e2e.Add('mutante ' + $m[0] + ' non compila') }
        else { Write-Host ('  FAIL mutante ' + $m[0] + ' sopravvissuto'); $e2e.Add('mutante ' + $m[0] + ' sopravvissuto') }
    }
    Write-Host ('  mutanti del motore uccisi ' + $killed + '/' + $total)
}

# ====================================================================================================================
# (B) sorgente del servizio e della pagina
# ====================================================================================================================
$svcSrc = Read-Repo 'App_Code\KeepStoreFeedService.vb'
$pageSrc = Read-Repo 'feed.aspx.vb'
$pageMarkup = Read-Repo 'feed.aspx'
function Test-Source([string]$svc, [string]$eng, [string]$page, [string]$markup) {
    $f = New-Object Collections.Generic.List[string]
    # blocco: nome con il database, connessione dedicata senza pool, rilascio in Finally
    if ($svc -notmatch "GET_LOCK\(CONCAT\('ksfeed\.', MD5\(CONCAT\(DATABASE\(\), ':', @id\)\)\), 0\)") { $f.Add('S1 GET_LOCK senza il database nel nome o con attesa') }
    if ($svc -notmatch 'builder\.Pooling = False') { $f.Add('S2 la connessione del blocco deve essere senza pool') }
    $iFin = $svc.IndexOf('If acquired Then'); $iRel = $svc.IndexOf('RELEASE_LOCK(CONCAT')
    if ($iFin -lt 0 -or $iRel -lt $iFin -or $svc.Substring(0, $iFin).LastIndexOf('Finally') -lt 0) { $f.Add('S3 RELEASE_LOCK deve stare in Finally dopo l acquisizione') }
    if ($svc -notmatch 'Gate\.Wait\(0\)' -or $svc -notmatch 'Gate\.Release\(\)') { $f.Add('S4 un solo lavoratore per processo') }
    if ($svc -notmatch 'If FileIsFresh\(path, cfg\.Options\.MinutesCache\) Then Return True\s+Return GenerateAndPublish') { $f.Add('S5 dopo il blocco si ricontrolla il file') }
    # tetti e pubblicazione atomica
    if ($svc -notmatch 'rowCount > KeepStoreFeedEngine\.MaxRows' -or $svc -notmatch 'stopwatch\.Elapsed\.TotalSeconds > KeepStoreFeedEngine\.MaxSeconds' -or $svc -notmatch 'fs\.Length > KeepStoreFeedEngine\.MaxBytes') { $f.Add('S6 tetti di righe, tempo e byte') }
    if ($eng -notmatch 'Public Const MaxRows As Integer = 200000' -or $eng -notmatch 'Public Const MaxBytes As Long = 262144000L' -or $eng -notmatch 'Public Const MaxSeconds As Integer = 120') { $f.Add('S6b valori dei tetti') }
    if ($svc -notmatch 'File\.Replace\(tmp, final, Nothing, True\)' -or $svc -notmatch 'File\.Move\(tmp, final\)') { $f.Add('S7 sostituzione del file non atomica') }
    if ($svc -notmatch 'FileMode\.CreateNew') { $f.Add('S7b il file temporaneo si crea senza sovrascrivere') }
    if ($svc -notmatch 'FileShare\.ReadWrite Or FileShare\.Delete') { $f.Add('S8 lettura del file senza condivisione') }
    if ($svc -notmatch 'r\.BufferOutput = False') { $f.Add('S9 il file si invia a blocchi') }
    # l'autorizzazione precede il 304
    $iServe = $svc.IndexOf('Public Shared Sub Serve(')
    $iCfg = $svc.IndexOf('cfg = GetConfig(token, tooMany)', [Math]::Max($iServe, 0)); $iEn = $svc.IndexOf('Not cfg.Enabled Then', [Math]::Max($iCfg, 0)); $iTen = $svc.IndexOf('tenant.CompanyId <> cfg.CompanyId', [Math]::Max($iEn, 0)); $iNone = $svc.IndexOf('If-None-Match')
    if ($iServe -lt 0 -or $iCfg -lt 0 -or $iEn -lt 0 -or $iTen -lt 0 -or $iNone -lt 0 -or $iNone -lt $iTen) { $f.Add('S10 il 304 deve venire dopo codice, stato e azienda') }
    # prezzo: resolver del sito, mai le colonne promozionali della vista
    if ($svc -notmatch 'ProductPromotionEligibilityResolver\.CreateAnonymousContext' -or $svc -notmatch 'batch\.ResolveForProduct\(row\.Id, tcId, 1D, net, gross\)') { $f.Add('S11 il prezzo deve venire dal resolver del sito per un utente anonimo e 1 pezzo') }
    if ($svc -match '(?i)PrezzoPromo|InOfferta|OffertePrezzo|OfferteQntMinima') { $f.Add('S12 colonne promozionali della vista nel servizio') }
    if ($svc -match 'LIKE CONCAT') { $f.Add('S13 spedizione gratis con LIKE') }
    if ($svc -notmatch 'cfg\.CompanyId <= 0 Then Throw New KeepStoreFeedException\("AZIENDA_NON_RISOLTA"\)') { $f.Add('S14 azienda non risolta = nessun feed') }
    if ($svc -notmatch 'If matches <> 1 Then cfg\.CompanyId = 0') { $f.Add('S15 azienda ambigua = non risolta') }
    # limiti
    if ($svc -notmatch 'MissesPerSecond As Integer = 20' -or $svc -notmatch 'NegativeCacheMax As Integer = 1000' -or $svc -notmatch 'FailureCooldownMinutes As Integer = 5' -or $svc -notmatch 'FailureTableMax As Integer = 500') { $f.Add('S16 limiti di memoria e di tentativi') }
    if ($svc -notmatch 'MinMinutesCache As Integer = 15' -or $svc -notmatch 'MaxMinutesCache As Integer = 1440') { $f.Add('S17 tetto su MinutiCache') }
    if ($svc -notmatch 'Math\.Max\(24\.0R \* 60\.0R, 3\.0R \* cfg\.Options\.MinutesCache\)') { $f.Add('S18 eta massima del file servito') }
    if ($svc -match 'Response\.End|WriteFile\(|ThreadPool|Task\.Run|New Thread\(') { $f.Add('S19 invio intero in memoria o lavoro non supervisionato') }
    if ($svc -notmatch 'RequestStampMinutes As Integer = 10' -or $svc -notmatch 'WriteState\(cfg, 0, 0, "", True\)') { $f.Add('S20 la richiesta si registra al massimo ogni 10 minuti') }
    if ($svc -cmatch 'ex\.Message') { $f.Add('S21 messaggi di eccezione nello stato') }
    if ($svc -notmatch 'CARTELLA_NON_SCRIVIBILE') { $f.Add('S25 cartella non scrivibile con codice proprio') }
    if ($svc -notmatch 'MarkFailure\(cfg\)') { $f.Add('S22 attesa dopo un errore') }
    if ($svc -notmatch 'If InCooldown\(cfg\) Then Return False') { $f.Add('S23 nessun nuovo tentativo durante l attesa dopo un errore') }
    if ($svc -notmatch 'minutes >= MinMinutesCache AndAlso minutes <= MaxMinutesCache') { $f.Add('S24 MinutiCache fuori dai limiti non si usa') }
    # impronta della configurazione nel nome del file, filtri nella stessa fotografia, anteprima
    if ($svc -notmatch 'KeepStoreFeedEngine\.FileName\(ScopePrefix\(\), cfg\.ExportId, cfg\.Token, cfg\.Options\.Format, cfg\.Fingerprint\)') { $f.Add('S26 il nome del file deve portare l impronta della configurazione') }
    $iFp = $svc.IndexOf('Private Shared Function ComputeFingerprint('); $fpBody = if ($iFp -ge 0) { $t2 = $svc.Substring($iFp); $t2.Substring(0, $t2.IndexOf('End Function')) } else { '' }
    if ($fpBody -notmatch 'EngineVersion' -or $fpBody -notmatch 'Date\.Today' -or $fpBody -notmatch 'cfg\.CompanyId' -or $fpBody -notmatch 'cfg\.Domain' -or $fpBody -notmatch 'cfg\.Listino\.' -or $fpBody -notmatch 'For Each c As KeepStoreFeedColumn In cfg\.Columns' -or $fpBody -notmatch 'For Each f As Dictionary\(Of String, Integer\) In cfg\.Filters' -or $fpBody -notmatch 'o\.Separator' -or $fpBody -notmatch 'cfg\.IncludeTax') { $f.Add('S27 impronta incompleta (versione, giorno, azienda, dominio, listino, IVA, opzioni, colonne, filtri)') }
    if ($svc -notmatch 'FROM export_opzioni o JOIN export e ON e\.ID = o\.ExportId' -or $svc -notmatch 'WHERE o\.TokenAccesso=@t') { $f.Add('S28 la configurazione si cerca per il codice di export_opzioni') }
    if ($svc -notmatch 'cfg\.Filters = ReadFilters\(conn, cfg\.ExportId\)' -or $svc -match 'Dim filters As List\(Of Dictionary\(Of String, Integer\)\) = ReadFilters') { $f.Add('S29 i filtri si leggono con la configurazione, non durante la generazione') }
    $iPv = $svc.IndexOf('Private Shared Sub SendPreview('); $pvBody = if ($iPv -ge 0) { $t = $svc.Substring($iPv); $t.Substring(0, $t.IndexOf('End Sub')) } else { '' }
    if ($pvBody -eq '' -or $pvBody -match 'ETag|If-None-Match|TouchRequest|WriteState|EnsureFresh' -or $pvBody -notmatch 'SetNoStore' -or $pvBody -notmatch 'PreviewMaxBytes' -or $pvBody -notmatch 'X-Feed-Generato') { $f.Add('S30 anteprima: limite di byte, no-store, ora del file, nessun ETag ne registrazione') }
    if ($svc -notmatch 'If Not preview Then TouchRequest\(cfg\)' -or $svc.IndexOf('SendPreview(context, cfg, path, isHead)') -lt 0 -or $svc.IndexOf('SendPreview(context, cfg, path, isHead)') -gt $svc.IndexOf('SendFile(context, cfg, path, isHead)')) { $f.Add('S31 l anteprima precede la risposta ordinaria e non registra la richiesta') }
    if ($svc -notmatch 'xs\.Indent = True') { $f.Add('S32 xml indentato (l anteprima si legge per righe)') }
    # pagina e cartella
    if ($markup -notmatch 'EnableSessionState="false"') { $f.Add('P1 sessione spenta') }
    if ($page -notmatch 'Public Overrides Sub ProcessRequest' -or $page -match 'MyBase\.ProcessRequest') { $f.Add('P2 ProcessRequest senza ciclo della pagina') }
    if ($svc -notmatch 'fileExtensions allowUnlisted=""false"" />' -or $svc -match '<add ') { $f.Add('P3 cartella: nessuna estensione ammessa') }
    if ($svc -notmatch 'allowUnlisted=""false""') { $f.Add('P4 il servizio non ricrea la guardia della cartella') }
    return $f.ToArray()
}
Write-Host '(B) sorgente'
$sf = @(Test-Source $svcSrc $engineSrc $pageSrc $pageMarkup)
Check ($sf.Count -eq 0) ('B1 controlli sul sorgente (' + ($sf -join '; ') + ')')
$policySrc = Read-Repo 'App_Code\StorefrontCanonicalHostPolicy.vb'
Check ($policySrc -match '"listino-catalogo\.aspx", "feed\.aspx"') 'B2 feed.aspx e tra le pagine non indicizzabili'
Check ((Read-Repo '.gitignore') -match '(?m)^/Public/assets/images/export/\s*$' -and -not (Test-Path -LiteralPath (Join-Path $root 'Public\assets\images\export\web.config'))) 'B3 la cartella dei feed (e il web.config di guardia scritto dal motore) non si versionano'
$svcMutants = @(
    @('lock-senza-database', "MD5(CONCAT(DATABASE(), ':', @id))", "MD5(CONCAT('x', ':', @id))"),
    @('lock-con-attesa', "':', @id))), 0)", "':', @id))), 5)"),
    @('lock-con-pool', 'builder.Pooling = False', 'builder.Pooling = True'),
    @('lock-non-rilasciato', 'If acquired Then', 'If False Then'),
    @('nessun-ricontrollo', 'If FileIsFresh(path, cfg.Options.MinutesCache) Then Return True' + "`n" + '                    Return GenerateAndPublish', 'Return GenerateAndPublish'),
    @('tetto-righe-tolto', 'If rowCount > KeepStoreFeedEngine.MaxRows Then Throw New KeepStoreFeedException("TETTO_RIGHE")', ''),
    @('tetto-tempo-tolto', 'If stopwatch.Elapsed.TotalSeconds > KeepStoreFeedEngine.MaxSeconds Then Throw New KeepStoreFeedException("TETTO_TEMPO")', ''),
    @('tetto-byte-tolto', 'If (rowCount And 255) = 0 AndAlso fs.Length > KeepStoreFeedEngine.MaxBytes Then Throw New KeepStoreFeedException("TETTO_BYTE")', ''),
    @('file-non-atomico', 'File.Replace(tmp, final, Nothing, True)', 'File.Copy(tmp, final, True)'),
    @('lettura-esclusiva', 'FileShare.ReadWrite Or FileShare.Delete', 'FileShare.Read'),
    @('invio-bufferizzato', 'r.BufferOutput = False', 'r.BufferOutput = True'),
    @('prezzo-dalla-vista', 'batch.ResolveForProduct(row.Id, tcId, 1D, net, gross)', 'Nothing'),
    @('promo-dalla-vista', 'Dim net As Decimal = RowDec(reader, "Prezzo")', 'Dim net As Decimal = RowDec(reader, "PrezzoPromo")'),
    @('azienda-ambigua', 'If matches <> 1 Then cfg.CompanyId = 0', ''),
    @('cooldown-tolto', 'If InCooldown(cfg) Then Return False', ''),
    @('tetto-cache-tolto', 'o.MinutesCache = If(minutes >= MinMinutesCache AndAlso minutes <= MaxMinutesCache, minutes, 60)', 'o.MinutesCache = minutes'),
    @('304-prima-dell-autorizzazione', 'Dim cfg As KeepStoreFeedConfig = Nothing', 'Dim early As String = context.Request.Headers("If-None-Match")' + "`n" + '        Dim cfg As KeepStoreFeedConfig = Nothing'),
    @('stato-a-ogni-richiesta', 'RequestStampMinutes As Integer = 10', 'RequestStampMinutes As Integer = 0'),
    @('messaggio-nello-stato', 'Return "ERRORE_" & ex.GetType().Name', 'Return ex.Message'),
    @('guardia-cartella-persa', 'allowUnlisted=""false""', 'allowUnlisted=""true""'),
    @('impronta-fuori-dal-nome', 'cfg.Options.Format, cfg.Fingerprint))', 'cfg.Options.Format, ""))'),
    @('impronta-senza-colonne', 'For Each c As KeepStoreFeedColumn In cfg.Columns' + "`n" + '            p.Add(c.Title)', 'For Each c As KeepStoreFeedColumn In New List(Of KeepStoreFeedColumn)()' + "`n" + '            p.Add(c.Title)'),
    @('impronta-senza-giorno', 'p.Add(Date.Today.ToString("yyyyMMdd", Invariant))', 'p.Add("")'),
    @('filtri-riletti-in-generazione', 'Dim filters As List(Of Dictionary(Of String, Integer)) = cfg.Filters', 'Dim filters As List(Of Dictionary(Of String, Integer)) = ReadFilters(conn, cfg.ExportId)'),
    @('anteprima-registra-la-richiesta', 'If Not preview Then TouchRequest(cfg)', 'TouchRequest(cfg)'),
    @('anteprima-senza-limite-di-byte', 'Dim buffer(KeepStoreFeedEngine.PreviewMaxBytes - 1) As Byte', 'Dim buffer(104857599) As Byte'),
    @('anteprima-con-etag', 'r.AppendHeader("X-Feed-Generato"', 'r.AppendHeader("ETag", "x")' + "`n" + '        r.AppendHeader("X-Feed-Generato"'),
    @('xml-su-una-riga', 'xs.Indent = True', 'xs.Indent = False'),
    @('configurazione-dal-vecchio-schema', 'FROM export_opzioni o JOIN export e ON e.ID = o.ExportId', 'FROM export e JOIN export_opzioni o ON e.ID = o.ExportId'),
    @('eta-massima-tolta', 'Math.Max(24.0R * 60.0R, 3.0R * cfg.Options.MinutesCache)', '1.0E+30')
)
if (-not $SkipMutants) {
    $killed = 0; $total = 0
    foreach ($m in $svcMutants) {
        if ($MutantFilter -ne '' -and $m[0] -notlike ('*' + $MutantFilter + '*')) { continue }
        $total++
        if (-not $svcSrc.Contains($m[1])) { Write-Host ('  FAIL mutante sorgente ' + $m[0] + ': testo da mutare non trovato'); $e2e.Add('mutante sorgente ' + $m[0] + ' non applicabile'); continue }
        $mut = @(Test-Source $svcSrc.Replace($m[1], $m[2]) $engineSrc $pageSrc $pageMarkup)
        if ($mut.Count -gt 0) { $killed++; Write-Host ('  ok   mutante sorgente ' + $m[0] + ' ucciso (' + $mut[0] + ')') }
        else { Write-Host ('  FAIL mutante sorgente ' + $m[0] + ' sopravvissuto'); $e2e.Add('mutante sorgente ' + $m[0] + ' sopravvissuto') }
    }
    Write-Host ('  mutanti del sorgente uccisi ' + $killed + '/' + $total)
}

if ($OnlyUnit -or $SkipSite) {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($e2e.Count -gt 0) { Write-Host 'EXPORT_FEED_ENGINE FAIL'; exit 1 }
    Write-Host 'EXPORT_FEED_ENGINE PASS (solo A e B)'; exit 0
}

# ====================================================================================================================
# (C) sito LAB
# ====================================================================================================================
Write-Host '(C) sito LAB'
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'EXPORT_FEED_ENGINE FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$base = 'https://www.taikun.it:18843'
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$scriptsDoc = Join-Path $root 'docs\EXPORT_FEED_DB_SCRIPTS.md'
$prefixMig = '20261126_EXPORT_FEED_DB_2A_'
$migDir = Join-Path $tmp 'mig'; New-Item -ItemType Directory -Force -Path $migDir | Out-Null
$docText = [IO.File]::ReadAllText($scriptsDoc, $utf8)
foreach ($k in @('preflight', 'forward', 'verify', 'rollback')) {
    $mm = [regex]::Match($docText, '(?s)## ' + [regex]::Escape($prefixMig + $k) + '\.sql\r?\n\r?\n```sql\r?\n(.*?)\r?\n```')
    if (-not $mm.Success) { Write-Host ('EXPORT_FEED_ENGINE FAIL: script ' + $k + ' non trovato nel documento'); exit 1 }
    [IO.File]::WriteAllText((Join-Path $migDir ($prefixMig + $k + '.sql')), ($mm.Groups[1].Value -replace '\r\n', "`n"), $utf8)
}
function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write 2>&1 }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f 2>&1 }
        return @($o | ForEach-Object { [string]$_ })
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Sql-Failed([string[]]$out) { return (($out -join "`n") -match '(?m)^stderr:|ERROR \d+') }
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql $sql)
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ($o[$i].Trim() -eq 'ksval') { return $o[$i + 1].Trim() } }
    return ''
}
function Get-Rows([string]$sql) {
    $o = @(@(Invoke-Sql $sql) | Where-Object { $_ -notmatch '^mode=' -and $_ -notmatch '^stderr' -and $_.Trim() -ne '' })
    if ($o.Count -lt 1) { return @() }
    $h = $o[0].Split("`t"); $res = New-Object Collections.Generic.List[object]
    for ($i = 1; $i -lt $o.Count; $i++) { $c = $o[$i].Split("`t"); $r = @{}; for ($k = 0; $k -lt $h.Count; $k++) { $r[$h[$k]] = if ($k -lt $c.Count) { $c[$k] } else { '' } }; $res.Add($r) }
    return $res.ToArray()
}
function Get-RowsRange([string]$template, [int]$maxId) {
    $all = New-Object Collections.Generic.List[object]
    for ($lo = 0; $lo -le $maxId; $lo += 1000) {
        $hi = $lo + 999
        foreach ($r in @(Get-Rows ($template.Replace('{RANGE}', ('BETWEEN ' + $lo + ' AND ' + $hi))))) { $all.Add($r) }
    }
    return $all.ToArray()
}
function To-Hex([string]$s) { return (($utf8.GetBytes($s) | ForEach-Object { $_.ToString('X2') }) -join '') }
function Sql-Text([string]$s) { return ("CONVERT(UNHEX('" + (To-Hex $s) + "') USING utf8mb4)") }
$inv = [Globalization.CultureInfo]::InvariantCulture
function Dec([string]$s) { if ($s -eq '' -or $s -eq 'NULL') { return [decimal]0 }; return [decimal]::Parse($s, [Globalization.NumberStyles]::Float, $inv) }
function Round2([decimal]$d) { return [Math]::Round($d, 2, [MidpointRounding]::AwayFromZero) }
function Money([decimal]$d) { return (Round2 $d).ToString('0.00', $inv) }

# Una richiesta: stato, intestazioni (minuscole), corpo in byte, secondi.
function Get-Url([string]$pathQuery, [string[]]$extra = @(), [string]$method = 'GET', [switch]$Compressed) {
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.bin')
    $outTarget = if ($method -eq 'HEAD') { 'NUL' } else { $out }
    $a = @('--noproxy', '*', '-s', '--max-time', '120', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $outTarget, '-w', '%{http_code}|%{remote_ip}|%{time_total}')
    if ($method -eq 'HEAD') { $a += '-I' } elseif ($method -eq 'POST') { $a += @('-d', 'x') } elseif ($method -ne 'GET') { $a += @('-X', $method) }
    if ($Compressed) { $a += '--compressed' }
    foreach ($h in $extra) { $a += @('-H', $h.Replace('"', '\"')) }
    $a += ($base + $pathQuery)
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 3 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $headers = @{}
    if (Test-Path -LiteralPath $hdr) { foreach ($l in ([IO.File]::ReadAllText($hdr) -split "`r?`n")) { $ix = $l.IndexOf(':'); if ($ix -gt 0) { $headers[$l.Substring(0, $ix).Trim().ToLowerInvariant()] = $l.Substring($ix + 1).Trim() } } }
    [byte[]]$bytes = @()
    if (Test-Path -LiteralPath $out) { $bytes = [IO.File]::ReadAllBytes($out) }
    Remove-Item -LiteralPath $hdr, $out -Force -ErrorAction SilentlyContinue
    $secs = 0.0; [void][double]::TryParse($parts[2], [Globalization.NumberStyles]::Float, $inv, [ref]$secs)
    return @{ Status = [int]$parts[0]; Headers = $headers; Bytes = $bytes; Body = $utf8.GetString($bytes); Seconds = $secs }
}
function Diag([string]$name, $resp) { Write-Host ('  diag ' + $name + ': stato=' + $resp.Status + ' byte=' + $resp.Bytes.Length + ' intestazioni=' + (($resp.Headers.Keys | Sort-Object | ForEach-Object { $_ + '=' + $resp.Headers[$_] }) -join ' | ') + ' corpo=' + $resp.Body.Substring(0, [Math]::Min(80, $resp.Body.Length))) }
function Get-Feed([string]$token, [string[]]$extra = @(), [string]$method = 'GET') { return (Get-Url ('/feed.aspx?c=' + $token) $extra $method) }
# Molte richieste in parallelo con curl: restituisce i codici di stato.
function Get-Parallel([string[]]$urls, [int]$max = 60) {
    $cfgf = Join-Path $tmp ('par' + [Guid]::NewGuid().ToString('N') + '.cfg')
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine('silent')
    $ui = 0; foreach ($u in $urls) { $ui++; [void]$sb.AppendLine('url = "' + $base + $u + '"'); [void]$sb.AppendLine('output = "NUL"'); [void]$sb.AppendLine('noproxy = "*"'); [void]$sb.AppendLine('resolve = "www.taikun.it:18843:127.0.0.1"'); [void]$sb.AppendLine('write-out = "%{http_code} "'); if ($ui -lt $urls.Count) { [void]$sb.AppendLine('next') } }
    [IO.File]::WriteAllText($cfgf, $sb.ToString(), $utf8)
    try { $o = @(((& curl.exe --parallel --parallel-max $max -K $cfgf 2>&1 | ForEach-Object { [string]$_ }) -join ' ') -split '\s+' | Where-Object { $_ -match '^\d{3}$' }) } finally { Remove-Item -LiteralPath $cfgf -Force -ErrorAction SilentlyContinue }
    return ,$o
}
function Get-Counters {
    $rows = @(Get-Rows "SHOW GLOBAL STATUS WHERE Variable_name IN ('Com_select','Com_insert','Com_update','Com_delete','Connections');")
    $h = @{}; foreach ($r in $rows) { $h[$r['Variable_name']] = [long]$r['Value'] }
    if ($h.Count -ne 5) { throw 'COUNTERS_UNAVAILABLE' }
    return $h
}
# Interrogazioni "di lavoro" fra due fotografie, tolto il rumore del misuratore (una fotografia vuota subito dopo).
function Measure-Work([scriptblock]$work) {
    $s0 = Get-Counters; & $work | Out-Null; $s1 = Get-Counters; $s2 = Get-Counters
    $d = @{}; foreach ($k in $s0.Keys) { $d[$k] = ($s1[$k] - $s0[$k]) - ($s2[$k] - $s1[$k]) }
    return $d
}
$script:inReset = $false
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 80; $i++) {
        $st = 0; try { $st = (Get-Feed ('0' * 48)).Status } catch { $st = 0 }
        if ($st -eq 404) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Reset-App {
    $script:inReset = $true
    try { (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date; Start-Sleep -Seconds 6; Wait-Site } finally { $script:inReset = $false }
}
$siteFiles = @('feed.aspx', 'feed.aspx.vb', 'App_Code\KeepStoreFeedEngine.vb', 'App_Code\KeepStoreFeedService.vb', 'export.aspx.vb')
$orig = @{}
foreach ($rel in $siteFiles) { $p = Join-Path $SitePath $rel; $orig[$rel] = if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllBytes($p) } else { $null } }
function Deploy-Repo { foreach ($rel in $siteFiles) { [IO.File]::WriteAllBytes((Join-Path $SitePath $rel), [IO.File]::ReadAllBytes((Join-Path $root $rel))) }; Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site {
    foreach ($rel in $siteFiles) { $p = Join-Path $SitePath $rel; if ($null -ne $orig[$rel]) { [IO.File]::WriteAllBytes($p, $orig[$rel]) } elseif (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
}
$folder = Join-Path $SitePath 'Public\assets\images\export'
function Clear-FeedFiles { if (Test-Path -LiteralPath $folder) { Get-ChildItem -LiteralPath $folder -File | Remove-Item -Force } }
function Clear-FeedFolder { if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force } }

if ($Cleanup) {
    # Recupero dopo una prova interrotta: righe sintetiche, offerte, articoli, migrazione e file del sito.
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    $np = Get-Scalar 'SELECT ArticoliId AS ksval FROM offertedettaglio WHERE id=9990114;'
    $q = New-Object Text.StringBuilder
    if ($np -match '^[0-9]+$') { [void]$q.AppendLine('UPDATE articoli SET NoPromo=0 WHERE id=' + $np + ' AND NoPromo=1;') }
    if ((Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ks_feedengine_trick';") -eq '1') {
        [void]$q.AppendLine('UPDATE articoli a JOIN ks_feedengine_trick t ON t.id=a.id SET a.Descrizione1=t.Descrizione1, a.Descrizione2=t.Descrizione2, a.Ean=t.Ean, a.DescrizioneHTML=t.DescrizioneHTML, a.SpedizioneGratis_Listini=t.SpedizioneGratis_Listini, a.SpedizioneGratis_Data_Inizio=t.SpedizioneGratis_Data_Inizio, a.SpedizioneGratis_Data_Fine=t.SpedizioneGratis_Data_Fine;')
        [void]$q.AppendLine('DROP TABLE IF EXISTS ks_feedengine_trick;')
    }
    [void]$q.AppendLine('DELETE FROM voffertearticoli WHERE OfferteID BETWEEN 9990101 AND 9990140;')
    [void]$q.AppendLine('DELETE FROM offertedettaglio WHERE id BETWEEN 9990101 AND 9990140;')
    [void]$q.AppendLine('DELETE FROM offerte WHERE id BETWEEN 9990101 AND 9990140;')
    $null = Invoke-Sql $q.ToString() -Write
    if ((Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='export_opzioni';") -eq '1') {
        $null = Invoke-Sql 'DELETE FROM export_filtri WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM export_colonne WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM export_stato WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM `export` WHERE ID BETWEEN 9301 AND 9330 AND Descrizione LIKE ''KSFEEDENGINE%'';' -Write
        $rb = (Invoke-Sql ('SET @KeepStoreConfirmDropFeedData=1;' + "`n" + [IO.File]::ReadAllText((Join-Path $migDir ($prefixMig + 'rollback.sql')), $utf8)) -Write) -join "`n"
        Write-Host ('  rollback della migrazione: ' + $(if ($rb -match 'EXPORT_FEED_DB_ROLLBACK_OK') { 'ok' } else { 'NON RIUSCITO' }))
    }
    foreach ($rel in 'feed.aspx', 'feed.aspx.vb', 'App_Code\KeepStoreFeedEngine.vb', 'App_Code\KeepStoreFeedService.vb') { $p = Join-Path $SitePath $rel; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
    if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'EXPORT_FEED_ENGINE CLEANUP DONE'; exit 0
}

$siteMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLabSite18843'); $siteHeld = $false
$migApplied = $false; $fixtures = $false; $trickBackup = $false; $trickId = 0; $noPromoArt = $null; $folderPreexisted = Test-Path -LiteralPath $folder
try {
    try { $siteHeld = $siteMutex.WaitOne(1800000) } catch [System.Threading.AbandonedMutexException] { $siteHeld = $true }
    if (-not $siteHeld) { throw 'LAB_SITE_BUSY' }
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    if ($folderPreexisted) { throw 'FEED_FOLDER_ALREADY_ON_SITE' }
    if ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM `export` WHERE ID BETWEEN 9301 AND 9330;') -ne '0') { throw 'FIXTURE_IDS_NOT_FREE' }
    if ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM offerte WHERE id BETWEEN 9990101 AND 9990140;') -ne '0') { throw 'FIXTURE_OFFERS_NOT_FREE' }

    # --- migrazione reale: preflight, forward, verify ---
    $hasToken = Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='export_opzioni';"
    if ($hasToken -ne '0') { throw 'MIGRATION_ALREADY_APPLIED_ON_LAB (prova precedente interrotta: rilanciare con -Cleanup)' }
    $pf = (Invoke-Sql ([IO.File]::ReadAllText((Join-Path $migDir ($prefixMig + 'preflight.sql')), $utf8))) -join "`n"
    Check ($pf -match 'EXPORT_FEED_DB_PREFLIGHT_OK') 'C0 preflight della migrazione'
    $fw = (Invoke-Sql ([IO.File]::ReadAllText((Join-Path $migDir ($prefixMig + 'forward.sql')), $utf8)) -Write) -join "`n"
    $migApplied = $true
    Check ($fw -match 'EXPORT_FEED_DB_FORWARD_OK') 'C0 forward della migrazione'
    $vf = (Invoke-Sql ([IO.File]::ReadAllText((Join-Path $migDir ($prefixMig + 'verify.sql')), $utf8))) -join "`n"
    Check ($vf -match 'EXPORT_FEED_DB_VERIFY_OK') 'C0 verify della migrazione'

    Deploy-Repo

    # --- articoli di prova: non variante, un solo prezzo nel listino 10, nessuna offerta, esportabili ---
    $cand = @(Get-Rows ('SELECT al.ArticoliId AS id, al.Prezzo AS net, al.PrezzoIvato AS gross FROM articoli_listini al JOIN articoli a ON a.id=al.ArticoliId WHERE al.NListino=10 AND COALESCE(a.Abilitato,0)=1 AND al.Prezzo>=5 AND COALESCE(al.TCid,-1)<=0 ' +
        'AND NOT EXISTS (SELECT 1 FROM voffertearticoli va WHERE va.id=al.ArticoliId) AND (SELECT COUNT(*) FROM articoli_listini x WHERE x.ArticoliId=al.ArticoliId AND x.NListino=10)=1 ' +
        'AND EXISTS (SELECT 1 FROM vsuperarticoli v WHERE v.id=al.ArticoliId AND v.nlistino=10 AND v.export=1) ORDER BY al.ArticoliId DESC LIMIT 18;'))
    if ($cand.Count -lt 18) { throw 'NO_PROMO_ARTICLES' }
    # 14 casi di promozione: nome, offerte (azienda, utente, inizio, fine, qMin, multipli, prezzo, sconto, abilitata), articolo
    $day = { param([int]$n) "CURDATE() + INTERVAL $n DAY" }
    $cases = @(
        @{ n = 'valida10'; art = $cand[0]; offers = @(@(1, 0, -1, 30, 1, 0, 0, 10, 1)) },
        @{ n = 'migliore-di-due'; art = $cand[1]; offers = @(@(1, 0, -1, 30, 1, 0, 0, 10, 1), @(1, 0, -1, 30, 1, 0, 0, 20, 1)) },
        @{ n = 'scaduta-ieri'; art = $cand[2]; offers = @(@(1, 0, -30, -1, 1, 0, 0, 50, 1)) },
        @{ n = 'inizia-domani'; art = $cand[3]; offers = @(@(1, 0, 1, 30, 1, 0, 0, 50, 1)) },
        @{ n = 'scaglione-da-3'; art = $cand[4]; offers = @(@(1, 0, -1, 30, 3, 0, 0, 30, 1)) },
        @{ n = 'multipli-1'; art = $cand[5]; offers = @(@(1, 0, -1, 30, 0, 1, 0, 15, 1)) },
        @{ n = 'multipli-2'; art = $cand[6]; offers = @(@(1, 0, -1, 30, 0, 2, 0, 15, 1)) },
        @{ n = 'ambigua-q1-m2'; art = $cand[7]; offers = @(@(1, 0, -1, 30, 1, 2, 0, 10, 1)) },
        @{ n = 'riservata-utente'; art = $cand[8]; offers = @(@(1, 5, -1, 30, 1, 0, 0, 30, 1)) },
        @{ n = 'offerta-spenta'; art = $cand[9]; offers = @(@(1, 0, -1, 30, 1, 0, 0, 30, 0)) },
        @{ n = 'altra-azienda'; art = $cand[10]; offers = @(@(2, 0, -1, 30, 1, 0, 0, 30, 1)) },
        @{ n = 'prezzo-promo-maggiore'; art = $cand[11]; offers = @(@(1, 0, -1, 30, 1, 0, 99999, 0, 1)) },
        @{ n = 'articolo-NoPromo'; art = $cand[12]; offers = @(@(1, 0, -1, 30, 1, 0, 0, 40, 1)) },
        @{ n = 'prezzo-fisso'; art = $cand[13]; offers = @(@(1, 0, -1, 30, 1, 0, 'FIXED', 0, 1)) }
    )
    $offSql = New-Object Text.StringBuilder; $oid = 9990100
    foreach ($c in $cases) {
        $offList = $c.offers; if ($offList[0] -isnot [array]) { $offList = @(, $offList) }
        foreach ($of in $offList) {
            $oid++
            $price = $of[6]; if ($price -eq 'FIXED') { $price = (Round2 ((Dec $c.art['net']) * 0.7d)).ToString('0.00', $inv); $c['fixed'] = [decimal]$price }
            [void]$offSql.AppendLine('INSERT INTO offerte (id, AziendeId, Descrizione, DataInizio, DataFine, DaListino, AListino, UtentiId, QntMinima, Multipli, Prezzo, Sconto, Abilitato, Ordinamento, Vetrina) VALUES (' + $oid + ', ' + $of[0] + ', ''KSFEEDENGINE'', ' + (& $day $of[2]) + ', ' + (& $day $of[3]) + ', 0, 0, ' + $of[1] + ', ' + $of[4] + ', ' + $of[5] + ', ' + $price + ', ' + $of[7] + ', ' + $of[8] + ', 0, 0);')
            [void]$offSql.AppendLine('INSERT INTO offertedettaglio (id, OfferteId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottoGruppiId, ArticoliId, TcId) VALUES (' + $oid + ', ' + $oid + ', 0, 0, 0, 0, 0, 0, ' + $c.art['id'] + ', NULL);')
            [void]$offSql.AppendLine('INSERT INTO voffertearticoli (id, OfferteID, OfferteDettagliId, OfferteDescrizione, OfferteDataInizio, OfferteDataFine, OfferteDaListino, OfferteAListino, OfferteQntMinima, OfferteMultipli, OffertePrezzo, OfferteSconto) VALUES (' + $c.art['id'] + ', ' + $oid + ', ' + $oid + ', ''KSFEEDENGINE'', ' + (& $day $of[2]) + ', ' + (& $day $of[3]) + ', 0, 0, ' + $of[4] + ', ' + $of[5] + ', ' + $price + ', ' + $of[7] + ');')
            $c['oid'] = $oid
        }
        $c['oid'] = $oid
    }
    $noPromoArt = $cand[12]['id']
    [void]$offSql.AppendLine('UPDATE articoli SET NoPromo=1 WHERE id=' + $noPromoArt + ';')
    # Articolo con testi difficili (ripristinati alla fine): virgolette, &, <, |, ;, a-capo, carattere di controllo non ammesso da XML, HTML con entita.
    $trickId = $cand[14]['id']
    $freeA = $cand[15]['id']; $freeB = $cand[16]['id']
    [void]$offSql.AppendLine('DROP TABLE IF EXISTS ks_feedengine_trick;')
    [void]$offSql.AppendLine('CREATE TABLE ks_feedengine_trick AS SELECT id, Descrizione1, Descrizione2, Ean, DescrizioneHTML, SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine FROM articoli WHERE id IN (' + $trickId + ', ' + $freeA + ', ' + $freeB + ');')
    [void]$offSql.AppendLine('UPDATE articoli SET SpedizioneGratis_Listini=''10;11;'', SpedizioneGratis_Data_Inizio=CURDATE() - INTERVAL 1 DAY, SpedizioneGratis_Data_Fine=CURDATE() + INTERVAL 5 DAY WHERE id=' + $freeA + ';')
    [void]$offSql.AppendLine('UPDATE articoli SET SpedizioneGratis_Listini=''110;'', SpedizioneGratis_Data_Inizio=CURDATE() - INTERVAL 1 DAY, SpedizioneGratis_Data_Fine=CURDATE() + INTERVAL 5 DAY WHERE id=' + $freeB + ';')
    $trickBackup = $true
    $trickD1 = 'Cavo "A&B" <rosso>; 2|3 ' + [char]0xE8 + [char]0x20AC; $trickD2 = "riga1`nriga2" + [char]0xFFFE + 'x'; $trickH = '<p>Ciao&nbsp;<b>mondo</b> &amp; co</p>'
    [void]$offSql.AppendLine('UPDATE articoli SET Descrizione1=' + (Sql-Text $trickD1) + ', Descrizione2=' + (Sql-Text $trickD2) + ', Ean=''8001234567890'', DescrizioneHTML=' + (Sql-Text $trickH) + ' WHERE id=' + $trickId + ';')
    $r = Invoke-Sql $offSql.ToString() -Write
    if (Sql-Failed $r) { throw ('FIXTURE_OFFERS_FAILED ' + ($r -join ' ')) }
    $fixtures = $true

    # --- feed sintetici ---
    $pw = 'KsEngine-1'
    $fmt = '#id#|#Codice#|#Ean#|#Disponibilita#|#Prezzo#|#Link#'
    $ins = New-Object Text.StringBuilder
    function Add-Feed([int]$id, [string]$tipo, [string]$format, [int]$iva, [int]$abil, [string]$domain, [int]$lst = 10, [string]$giac = '-1', [int]$vet = 0) {
        $t = if ($tipo -eq '') { 'NULL' } else { "'" + $tipo + "'" }
        [void]$ins.AppendLine('INSERT INTO `export` (ID, Descrizione, `Password`, FormatString, NListino, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, NListino2, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, Abilitato) VALUES (' + $id + ', ''KSFEEDENGINE' + $id + ''', ''' + $pw + ''', ' + (Sql-Text $format) + ', ' + $lst + ', ' + $iva + ', ' + $giac + ', 5, 2, ''' + $domain + ''', ' + $t + ', ' + $vet + ', 0, 0, 0, 0, 0, ' + $abil + ');')
    }
    Add-Feed 9301 'txt' $fmt 2 1 'www.taikun.it'
    Add-Feed 9302 'txt' $fmt 1 1 'www.taikun.it'
    Add-Feed 9303 'csv' '#id#|#Descrizione1#|#Descrizione2#|#Prezzo#' 2 1 'www.taikun.it'
    Add-Feed 9304 'xml' '#Codice#' 2 1 'www.taikun.it'
    Add-Feed 9305 'tsv' '#Codice#' 2 1 'www.taikun.it'
    Add-Feed 9306 'txt' $fmt 2 0 'www.taikun.it'
    Add-Feed 9307 'txt' $fmt 2 1 'www.webaffare.it'
    Add-Feed 9308 'txt' $fmt 2 1 'www.entropic.it'
    Add-Feed 9309 'txt' $fmt 2 1 'www.taikun.it'
    Add-Feed 9310 'txt' '#id#|#Prezzo#' 2 1 'www.taikun.it'
    Add-Feed 9311 'csv' '#id#|#Descrizione1#' 2 1 'www.taikun.it'
    Add-Feed 9312 'txt' '#id#|#CostoSpedizioneProdo#|#SpeseSpedizione#|#Peso#|#Prezzo2#' 1 1 'www.taikun.it' 10 '-1' 5
    Add-Feed 9313 'txt' $fmt 2 1 'www.taikun.it'
    Add-Feed 9314 'txt' $fmt 2 1 'www.taikun.it'
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9310, -1, -1, -1, -1, -1, -1, ' + $cand[0]['id'] + ');')
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9310, -1, -1, -1, -1, -1, -1, ' + $cand[1]['id'] + ');')
    # colonne libere del feed xml 9304
    $cols = @(@('sku', '#Codice#', '', '', '', 0, ''), @('title', '#Descrizione1#', '', '', '', 0, ''), @('price', '#Prezzo#', '', ' EUR', '', 0, ''), @('description', '#DescrizioneHtml#', '', '', '', 0, 'nessuna'), @('desc2', '#Descrizione2#', '', '', '', 0, ''), @('link', '#Link#', '', '', '', 0, ''), @('availability', '#Disponibilita#', '', '', '', 0, ''), @('fisso', '', '', '', 'IT', 0, ''), @('path', '#CategoriaPercorso#', '', '', '', 0, ''))
    $pos = 0
    foreach ($c in $cols) { $pos++; [void]$ins.AppendLine('INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto) VALUES (9304, ' + $pos + ', ''' + $c[0] + ''', ' + (Sql-Text ($c[1] -replace '^#|#$', '')) + ', ''' + $c[2] + ''', ' + (Sql-Text $c[3]) + ', ''' + $c[4] + ''', NULL, ' + (Sql-Text $c[6]) + ');') }
    [void]$ins.AppendLine("INSERT INTO export_opzioni (ExportId) SELECT ID FROM export WHERE ID BETWEEN 9301 AND 9330;")
    [void]$ins.AppendLine("UPDATE export_opzioni SET XmlRadice='catalogo', XmlElemento='item', SeparatoreDecimale='.' WHERE ExportId=9304;")
    # tsv 9305: titolo e prezzo con virgola decimale
    [void]$ins.AppendLine("INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto) VALUES (9305, 1, 'id', 'id', '', '', '', NULL, ''), (9305, 2, 'prezzo', 'Prezzo', '', '', '', NULL, '');")
    [void]$ins.AppendLine("UPDATE export_opzioni SET SeparatoreDecimale=',', Separatore='|' WHERE ExportId=9305;")
    # csv 9311 in latin1 con delimitatore e separatore ';'
    [void]$ins.AppendLine("INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto) VALUES (9311, 1, 'id', 'id', '', '', '', NULL, ''), (9311, 2, 'titolo', 'Descrizione1', '', '', '', NULL, '');")
    [void]$ins.AppendLine("UPDATE export_opzioni SET Codifica='iso-8859-1', Separatore=';', DelimitatoreTesto='""' WHERE ExportId=9311;")
    # 9309: configurazione incoerente (separatore e decimale uguali, nessun delimitatore)
    [void]$ins.AppendLine("UPDATE export_opzioni SET Separatore=',', SeparatoreDecimale=',' WHERE ExportId=9309;")
    # 9301/9302 senza scarto del prezzo zero? predefinito: PrezzoZero=1 (scarta); 9313 lascia passare i prezzi zero
    [void]$ins.AppendLine("UPDATE export_opzioni SET PrezzoZero=0 WHERE ExportId=9313;")
    $r = Invoke-Sql $ins.ToString() -Write
    if (Sql-Failed $r) { throw ('FIXTURE_FEEDS_FAILED ' + ($r -join ' ')) }
    $tok = @{}
    foreach ($row in @(Get-Rows 'SELECT ExportId AS i, TokenAccesso AS t FROM export_opzioni WHERE ExportId BETWEEN 9301 AND 9314;')) { $tok[[int]$row['i']] = $row['t'] }
    Check ($tok.Count -eq 14 -and @($tok.Values | Where-Object { $_ -match '^[0-9A-F]{48}$' }).Count -eq 14) 'C1 i 14 feed di prova hanno il codice creato dal database'

    # --- oracolo: catalogo esportabile del listino 10 e prezzi ---
    $expIds = @(Get-Rows 'SELECT DISTINCT v.id AS id FROM vsuperarticoli v JOIN articoli a ON a.id=v.id WHERE v.export=1 AND v.nlistino=10 AND COALESCE(a.Abilitato,0)=1;' | ForEach-Object { $_['id'] })
    $expSet = New-Object Collections.Generic.HashSet[string]; foreach ($x in $expIds) { [void]$expSet.Add($x) }
    Check ($expIds.Count -gt 4000) ('C1 oracolo: articoli esportabili del listino 10 (' + $expIds.Count + ')')
    $maxArt = [int](Get-Scalar 'SELECT MAX(id) AS ksval FROM articoli;')
    $baseRows = @(Get-RowsRange 'SELECT al.ArticoliId AS id, al.Prezzo AS net, al.PrezzoIvato AS gross, IFNULL(al.TCid,-1) AS tc FROM articoli_listini al WHERE al.NListino=10 AND al.ArticoliId {RANGE} AND (SELECT COUNT(*) FROM articoli_listini x WHERE x.ArticoliId=al.ArticoliId AND x.NListino=10)=1;' $maxArt)
    $baseMap = @{}; foreach ($b in $baseRows) { $baseMap[$b['id']] = @{ net = (Dec $b['net']); gross = (Dec $b['gross']); tc = [int]$b['tc'] } }
    $offRows = @(Get-RowsRange ('SELECT va.id AS aid, o.Prezzo AS oprice, o.Sconto AS osc, IFNULL(od.TCId,-1) AS otc FROM voffertearticoli va JOIN offerte o ON o.id=va.OfferteID JOIN offertedettaglio od ON od.id=va.OfferteDettagliId AND od.OfferteId=o.id JOIN articoli a ON a.id=va.id ' +
        'WHERE o.AziendeId=1 AND o.Abilitato=1 AND a.Abilitato=1 AND COALESCE(a.NoPromo,0)=0 AND o.DataInizio<=CURDATE() AND o.DataFine>=CURDATE() AND COALESCE(o.UtentiId,0)<=0 ' +
        'AND NOT (COALESCE(o.QntMinima,0)>0 AND COALESCE(o.Multipli,0)>0) AND ((COALESCE(o.QntMinima,0)>0 AND o.QntMinima<=1) OR (COALESCE(o.QntMinima,0)<=0 AND o.Multipli=1)) ' +
        'AND (COALESCE(o.DaListino,0)<=0 OR o.DaListino<=10) AND (COALESCE(o.AListino,0)<=0 OR o.AListino>=10) AND va.id {RANGE};') $maxArt)
    $offMap = @{}; foreach ($o in $offRows) { if (-not $offMap.ContainsKey($o['aid'])) { $offMap[$o['aid']] = New-Object Collections.Generic.List[object] }; $offMap[$o['aid']].Add($o) }
    function Expected-Price([string]$artId, [int]$ivaTipo) {
        if (-not $baseMap.ContainsKey($artId)) { return $null }
        $net = $baseMap[$artId].net; $gross = $baseMap[$artId].gross
        $bestNet = $null; $bestExact = $null; $tc = $baseMap[$artId].tc
        if ($offMap.ContainsKey($artId) -and $net -gt 0 -and $gross -gt 0) {
            foreach ($o in $offMap[$artId]) {
                $otc = [int]$o['otc']
                if ($otc -gt 0 -and $otc -ne $tc) { continue }
                $p = Dec $o['oprice']; $sc = Dec $o['osc']
                $pn = [decimal]0
                if ($p -gt 0) { $pn = $p } elseif ($sc -gt 0 -and $sc -lt 100) { $pn = $net * (1 - $sc / 100) }
                if ($pn -le 0 -or $pn -ge $net) { continue }
                $pg = $pn * ($gross / $net)
                if ($pg -le 0 -or $pg -ge $gross) { continue }
                if ($otc -gt 0) { if ($null -eq $bestExact -or $pn -lt $bestExact) { $bestExact = $pn } }
                elseif ($null -eq $bestNet -or $pn -lt $bestNet) { $bestNet = $pn }
            }
        }
        if ($null -ne $bestExact) { $bestNet = $bestExact }
        if ($null -ne $bestNet) { if ($ivaTipo -eq 1) { return (Money $bestNet) } else { return (Money ($bestNet * ($gross / $net))) } }
        if ($ivaTipo -eq 1) { return (Money $net) } else { return (Money $gross) }
    }
    # Feed -> righe: colonne separate da '|', un record per riga (le descrizioni sono su una riga).
    function Parse-Txt([string]$body) { $lines = @($body -split "`r?`n" | Where-Object { $_ -ne '' }); $res = @{ Header = $lines[0]; Rows = @() }; $res.Rows = @($lines | Select-Object -Skip 1 | ForEach-Object { , ($_.Split('|')) }); return $res }
    $folderFiles = { if (Test-Path -LiteralPath $folder) { @(Get-ChildItem -LiteralPath $folder -File | ForEach-Object { $_.Name }) } else { @() } }

    # ---------------- cartella non scrivibile (come un server senza permessi): nessun file, 503, codice chiaro ----------------
    $w0 = Get-Feed $tok[9301]
    $s0 = Get-Scalar 'SELECT IFNULL(UltimoErrore, ''-'') AS ksval FROM export_stato WHERE ExportId=9301;'
    Check ($w0.Status -eq 503 -and $s0 -eq 'CARTELLA_NON_SCRIVIBILE' -and -not (Test-Path -LiteralPath $folder)) ('D0 identita del sito senza permessi di scrittura: 503 e codice CARTELLA_NON_SCRIVIBILE (visto ' + $w0.Status + ' ' + $s0 + ')')
    # Come sul server (cartella creata dal PO con i permessi del pool): si crea la cartella e si concede Modifica all'identita del sito LAB, solo su di essa.
    New-Item -ItemType Directory -Path $folder | Out-Null
    $acl = & icacls.exe $folder /grant ('IIS APPPOOL\KeepStoreRegOrderLabPool-20261025:(OI)(CI)M') 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'ICACLS_FAILED' }
    Reset-App
    # ---------------- F1 prima richiesta (a freddo) ----------------
    $t0 = Get-Date
    $r1 = Get-Feed $tok[9301]
    $coldSecs = ((Get-Date) - $t0).TotalSeconds
    if ($r1.Status -ne 200) { Write-Host ('  diag: stato=' + (Get-Scalar 'SELECT IFNULL(UltimoErrore, ''-'') AS ksval FROM export_stato WHERE ExportId=9301;') + ' corpo=' + $r1.Body.Trim()) }
    Check ($r1.Status -eq 200) ('F1 la prima richiesta genera e risponde 200 (visto ' + $r1.Status + ')')
    Check ($coldSecs -lt 10) ('F1 generazione completa sotto i 10 secondi (' + [Math]::Round($coldSecs, 1) + ' s)')
    $files = & $folderFiles
    Check (@($files | Where-Object { $_ -match '^[0-9a-f]{8}-9301-[0-9A-F]{48}-[0-9a-f]{12}\.txt$' }).Count -eq 1 -and ($files -contains 'web.config')) 'F1 nella cartella: il file pronto del feed e il web.config di guardia scritto dal motore'
    Check ((Test-Path -LiteralPath (Join-Path $folder 'web.config')) -and ([IO.File]::ReadAllText((Join-Path $folder 'web.config'), $utf8) -match 'allowUnlisted="false"')) 'F1 la guardia della cartella nega ogni estensione'
    $readyName = @($files | Where-Object { $_ -match '^[0-9a-f]{8}-9301-' })[0]
    $scope = $readyName.Substring(0, 8)
    $st = Get-Url ('/Public/assets/images/export/' + $readyName)
    Check ($st.Status -eq 404) ('F1 il file pronto NON si scarica direttamente dalla cartella (visto ' + $st.Status + ')')
    $st2 = Get-Url '/Public/assets/images/export/web.config'
    Check ($st2.Status -eq 404) 'F1 il web.config della cartella non si scarica'
    $p1 = Parse-Txt $r1.Body
    Check ($p1.Header -ceq 'id|Codice|Ean|Disponibilita|Prezzo|Link') 'F1 intestazione dal formato del feed'
    $ids = @($p1.Rows | ForEach-Object { $_[0] })
    Check ($ids.Count -eq @($ids | Sort-Object -Unique).Count) 'F1 nessun articolo ripetuto'
    $stateRows = @(Get-Rows 'SELECT UltimeRighe AS r, UltimeScartate AS s, UltimoErrore AS e, UltimaGenerazioneUtc AS g FROM export_stato WHERE ExportId=9301;')
    $inFeed = @($ids | Where-Object { $expSet.Contains($_) }).Count
    Check ($inFeed -eq $ids.Count) 'F1 ogni articolo del feed e nel catalogo esportabile'
    Check ($ids.Count -le $expIds.Count -and $ids.Count -ge [int]($expIds.Count * 0.9)) ('F1 il feed contiene quasi tutto il catalogo, meno i prezzi zero scartati (feed ' + $ids.Count + ', catalogo ' + $expIds.Count + ')')
    Check ($stateRows.Count -eq 1 -and $stateRows[0]['r'] -eq [string]$ids.Count -and ($stateRows[0]['e'] -eq 'NULL' -or $stateRows[0]['e'] -eq '') -and $stateRows[0]['g'] -ne 'NULL') 'F1 export_stato: righe scritte e nessun errore'
    Check (-not ($r1.Body -match 'http://')) 'F1 nessun http:// nel file'
    Check (@($p1.Rows | Where-Object { $_[5] -notmatch '^https://www\.taikun\.it/articolo\.aspx\?id=[0-9]+$' }).Count -eq 0) 'F1 ogni link e https://<dominio>/articolo.aspx?id=<n> senza parametri di comparatore'

    # ---------------- prezzo: tutto il catalogo contro l'oracolo SQL (IVA inclusa) ----------------
    $mis = @(); $checked = 0; $price2 = @{}
    foreach ($row in $p1.Rows) { $price2[$row[0]] = $row[4]; $e = Expected-Price $row[0] 2; if ($null -eq $e) { continue }; $checked++; if ($e -cne $row[4]) { $mis += ('id ' + $row[0] + ' atteso ' + $e + ' visto ' + $row[4]) } }
    Check ($checked -gt 3500 -and $mis.Count -eq 0) ('P1 prezzo IVA inclusa = oracolo SQL su ' + $checked + ' articoli non variante (differenze: ' + $mis.Count + ' ' + (($mis | Select-Object -First 3) -join '; ') + ')')
    $r2 = Get-Feed $tok[9302]
    $p2 = Parse-Txt $r2.Body
    $mis = @(); $checked = 0
    foreach ($row in $p2.Rows) { $e = Expected-Price $row[0] 1; if ($null -eq $e) { continue }; $checked++; if ($e -cne $row[4]) { $mis += ('id ' + $row[0] + ' atteso ' + $e + ' visto ' + $row[4]) } }
    Check ($checked -gt 3500 -and $mis.Count -eq 0) ('P2 prezzo IVA esclusa = oracolo SQL su ' + $checked + ' articoli (differenze: ' + $mis.Count + ' ' + (($mis | Select-Object -First 3) -join '; ') + ')')
    # 14 casi sintetici con valori attesi calcolati qui, senza passare dall'SQL delle offerte
    $feed1 = @{}; foreach ($row in $p1.Rows) { $feed1[$row[0]] = $row }
    $feed2 = @{}; foreach ($row in $p2.Rows) { $feed2[$row[0]] = $row }
    foreach ($c in $cases) {
        $net = Dec $c.art['net']; $gross = Dec $c.art['gross']; $id = $c.art['id']
        $promoNet = $null
        switch ($c.n) {
            'valida10' { $promoNet = $net * 0.9d }
            'migliore-di-due' { $promoNet = $net * 0.8d }
            'multipli-1' { $promoNet = $net * 0.85d }
            'prezzo-fisso' { $promoNet = [decimal]$c['fixed'] }
        }
        if ($null -ne $promoNet) { $expGross = Money ($promoNet * ($gross / $net)); $expNet = Money $promoNet } else { $expGross = Money $gross; $expNet = Money $net }
        Check ($feed1.ContainsKey($id) -and $feed1[$id][4] -ceq $expGross) ('P3 ' + $c.n + ': IVA inclusa atteso ' + $expGross + ' (visto ' + $(if ($feed1.ContainsKey($id)) { $feed1[$id][4] } else { 'assente' }) + ')')
        Check ($feed2.ContainsKey($id) -and $feed2[$id][4] -ceq $expNet) ('P3 ' + $c.n + ': IVA esclusa atteso ' + $expNet + ' (visto ' + $(if ($feed2.ContainsKey($id)) { $feed2[$id][4] } else { 'assente' }) + ')')
    }

    # ---------------- equivalenza con il vecchio feed (task 1) per gli articoli senza nessuna offerta ----------------
    $old = Get-Url ('/export.aspx?id=9301&pwd=' + [Uri]::EscapeDataString($pw))
    Check ($old.Status -eq 200) 'E1 il vecchio feed (oracolo del task 1) risponde'
    $oldRows = @{}; foreach ($line in @($old.Body -split "`r?`n" | Select-Object -Skip 1)) { $cs = $line.Split('|'); if ($cs.Count -ge 6 -and $cs[0] -match '^[0-9]+$') { $oldRows[$cs[0]] = $cs } }
    $noOffer = @{}; foreach ($b in @(Get-Rows 'SELECT DISTINCT va.id AS id FROM voffertearticoli va;')) { $noOffer[$b['id']] = $true }
    $cmp = 0; $diff = @()
    foreach ($id in $feed1.Keys) {
        if ($noOffer.ContainsKey($id) -or -not $oldRows.ContainsKey($id) -or -not $baseMap.ContainsKey($id)) { continue }
        $cmp++; $n = $feed1[$id]; $o = $oldRows[$id]
        foreach ($k in 1, 2, 3, 4, 5) { $ov = $o[$k].Trim(); if ($k -eq 5) { $ov = $ov.Replace('&comparatore=', '') }; if ($n[$k].Trim() -cne $ov) { $diff += ('id ' + $id + ' col ' + $k + ': nuovo [' + $n[$k] + '] vecchio [' + $o[$k] + ']') } }
    }
    Check ($cmp -gt 2500 -and $diff.Count -eq 0) ('E1 stessi valori del vecchio feed per id, codice, EAN, disponibilita, prezzo e link su ' + $cmp + ' articoli senza offerte (differenze ' + $diff.Count + ': ' + (($diff | Select-Object -First 3) -join '; ') + ')')

    # ---------------- formati ----------------
    $r4 = Get-Feed $tok[9304]
    Check ($r4.Status -eq 200 -and $r4.Headers['content-type'] -match '^application/xml; charset=utf-8') 'X1 xml: risponde 200 application/xml utf-8'
    $xdoc = $null; try { $xdoc = [xml]$r4.Body } catch { $xdoc = $null }
    Check ($null -ne $xdoc -and $xdoc.DocumentElement.Name -eq 'catalogo') 'X1 xml ben formato, radice scelta nel feed'
    if ($null -ne $xdoc) {
        $items = @($xdoc.DocumentElement.ChildNodes | Where-Object { $_.Name -eq 'item' })
        Check ($items.Count -gt 3500) ('X1 un elemento item per prodotto (' + $items.Count + ')')
        Check ($r4.Body -match "\r?\n  <item>\r?\n    <sku>") 'X1 xml indentato (due spazi per livello)'
        $it = $items | Where-Object { $_.link -match ('id=' + $trickId + '$') } | Select-Object -First 1
        Check ($null -ne $it -and $it.title -ceq $trickD1) 'X2 xml: testo con virgolette, & e < preservato dopo il parsing'
        Check ($null -ne $it -and $it.desc2 -ceq 'riga1 riga2x') 'X2 xml: a-capo diventano spazio e il carattere non ammesso da XML 1.0 e tolto'
        Check ($null -ne $it -and $it.description -ceq 'Ciao mondo & co') 'X2 xml: HTML tolto, entita decodificate'
        Check ($null -ne $it -and $it.price -match '^[0-9]+\.[0-9]{2} EUR$' -and $it.fisso -ceq 'IT' -and $it.availability -in @('Disponibile', 'In Arrivo', 'Non Disponibile')) 'X3 xml: prezzo con valuta come suffisso, valore fisso, disponibilita'
        Check ($null -ne $it -and $it.path -match ' > |^[^>]+$') 'X3 xml: percorso categoria'
        $emptyDesc = @($items | Where-Object { $_.description -ceq 'nessuna' }).Count
        Check ($emptyDesc -gt 0) ('X3 xml: "se vuoto" scritto dove la descrizione manca (' + $emptyDesc + ')')
    }
    $r5 = Get-Feed $tok[9305]
    $l5 = @($r5.Body -split "`r?`n" | Where-Object { $_ -ne '' })
    Check ($r5.Status -eq 200 -and $r5.Headers['content-type'] -match '^text/tab-separated-values' -and $l5[0] -ceq ('id' + [char]9 + 'prezzo') -and $l5[1] -match '^[0-9]+\t[0-9]+,[0-9]{2}$') 'X4 tsv: tabulazione, intestazione, virgola decimale'
    $r3 = Get-Feed $tok[9303]
    $csvLine = @($r3.Body -split "`r?`n" | Where-Object { $_ -match ('^"?' + $trickId + '"?;') })
    $expCsv = '"' + $trickId + '";"' + $trickD1.Replace('"', '""') + '";"riga1 riga2' + [char]0xFFFE + 'x";"'
    Check ($r3.Status -eq 200 -and $r3.Headers['content-type'] -match '^text/csv' -and $csvLine.Count -eq 1 -and $csvLine[0].StartsWith($expCsv)) 'X5 csv storico: ; e virgolette, virgolette interne raddoppiate'
    $r11 = Get-Feed $tok[9311]
    $l11 = $r11.Bytes
    $hasE8 = $false; for ($i = 0; $i -lt $l11.Length - 0; $i++) { if ($l11[$i] -eq 0xE8) { $hasE8 = $true; break } }
    $hasUtf8Pair = $false; for ($i = 0; $i -lt $l11.Length - 1; $i++) { if ($l11[$i] -eq 0xC3 -and $l11[$i + 1] -eq 0xA8) { $hasUtf8Pair = $true; break } }
    Check ($r11.Status -eq 200 -and $r11.Headers['content-type'] -match 'charset=iso-8859-1' -and $hasE8 -and -not $hasUtf8Pair) 'X6 latin1: byte E8 per la e accentata, nessuna sequenza utf-8'
    $lat = [Text.Encoding]::GetEncoding(28591).GetString($l11)
    Check ($lat -match ('\?\r?\n') -or $lat -match '\?"') 'X6 latin1: il carattere non rappresentabile (euro) diventa ?'
    $r12 = Get-Feed $tok[9312]
    $p12 = Parse-Txt $r12.Body
    Check ($r12.Status -eq 200 -and $p12.Rows.Count -gt 3500) 'X7 spedizione e secondo prezzo: il feed si genera'
    $rowA = @($p12.Rows | Where-Object { $_[0] -eq $freeA })[0]; $rowB = @($p12.Rows | Where-Object { $_[0] -eq $freeB })[0]
    Check ($null -ne $rowA -and $rowA[1] -ceq '0.00') 'X7 spedizione gratis: listino 10 nell elenco 10;11; e periodo in corso: 0.00'
    Check ($null -ne $rowB -and $rowB[1] -cmatch '^[0-9]+\.[0-9]{2}$' -and $rowB[1] -cne '0.00') 'X7 spedizione gratis: l elenco 110; NON vale per il listino 10 (token esatti; il vecchio LIKE lo avrebbe accettato)'

    # ---------------- intestazioni, 304, HEAD ----------------
    $h1 = Get-Feed $tok[9301]
    $etag = $h1.Headers['etag']
    Check ($h1.Status -eq 200 -and $etag -match '^W/"[0-9a-f]+-[0-9a-f]+"$' -and $h1.Headers.ContainsKey('last-modified') -and $h1.Headers['x-robots-tag'] -match 'noindex' -and $h1.Headers['cache-control'] -match 'private' -and $h1.Headers['cache-control'] -match 'max-age=60') 'H1 ETag debole, Last-Modified, noindex, cache privata di 60 s'
    Check ($h1.Headers['content-type'] -match '^text/plain; charset=utf-8' -and $h1.Headers['content-length'] -eq [string]$h1.Bytes.Length) 'H1 content type per formato e lunghezza corretta'
    $h304 = Get-Feed $tok[9301] @('If-None-Match: ' + $etag)
    if (-not ($h304.Status -eq 304 -and $h304.Bytes.Length -eq 0)) { Diag 'h304' $h304; Write-Host ('  diag etag inviato=' + $etag) }
    Check ($h304.Status -eq 304 -and $h304.Bytes.Length -eq 0) 'H2 If-None-Match uguale: 304 senza corpo'
    $hm = Get-Feed $tok[9301] @('If-Modified-Since: ' + [DateTime]::UtcNow.AddMinutes(5).ToString('R', $inv))
    Check ($hm.Status -eq 304) 'H2 If-Modified-Since piu recente del file: 304'
    $hother = Get-Feed $tok[9301] @('If-None-Match: W/"0-0"')
    Check ($hother.Status -eq 200 -and $hother.Bytes.Length -eq $h1.Bytes.Length) 'H2 If-None-Match diverso: 200 con il file'
    $hwrong = Get-Feed ('F' * 48) @('If-None-Match: ' + $etag)
    Check ($hwrong.Status -eq 404) 'H3 codice sconosciuto con If-None-Match valido di un altro feed: 404, non 304'
    $head = Get-Feed $tok[9301] @() 'HEAD'
    if (-not ($head.Status -eq 200 -and $head.Bytes.Length -eq 0)) { Diag 'head' $head }
    Check ($head.Status -eq 200 -and $head.Bytes.Length -eq 0 -and $head.Headers['content-length'] -eq [string]$h1.Bytes.Length -and $head.Headers['etag'] -eq $etag) 'H4 HEAD: intestazioni come GET, nessun corpo'
    $post = Get-Url ('/feed.aspx?c=' + $tok[9301]) @() 'POST'
    if ($post.Status -ne 405) { Diag 'post' $post }
    Check ($post.Status -eq 405 -and $post.Headers['allow'] -match 'GET') 'H5 POST: 405'
    foreach ($bad in @('', 'abc', ('Z' * 48), ('A' * 47), ('A' * 49), ($tok[9301].ToLowerInvariant() + 'x'), ("A' OR 1=1 -- " + ('A' * 30)))) {
        $rb = Get-Url ('/feed.aspx?c=' + [Uri]::EscapeDataString($bad))
        if ($rb.Status -ne 404) { Check $false ('H6 codice non valido [' + $bad + '] atteso 404 visto ' + $rb.Status); break }
    }
    Check ($true) 'H6 codici non validi: sempre 404'
    $nocode = Get-Url '/feed.aspx'
    if ($nocode.Status -ne 404) { Diag 'nocode' $nocode }
    Check ($nocode.Status -eq 404 -and -not ($nocode.Body -match '[0-9A-F]{48}')) 'H6 senza codice: 404'
    $gz = Get-Url ('/feed.aspx?c=' + $tok[9301]) @() 'GET' -Compressed
    Check ($gz.Status -eq 200 -and $gz.Bytes.Length -eq $h1.Bytes.Length) 'H7 con Accept-Encoding gzip il corpo decompresso e identico'

    # ---------------- richieste con il file pronto: nessuna interrogazione ----------------
    $null = Get-Feed $tok[9301]; Start-Sleep -Milliseconds 300
    $times = @(); for ($i = 0; $i -lt 20; $i++) { $times += (Get-Feed $tok[9301]).Seconds }
    $median = ($times | Sort-Object)[10]
    Check ($median -lt 0.05) ('R1 risposta dal file pronto sotto i 50 ms (mediana ' + [Math]::Round($median * 1000, 1) + ' ms, il file e di ' + [Math]::Round($h1.Bytes.Length / 1024) + ' KB)')
    $urls = @(); for ($i = 0; $i -lt 100; $i++) { $urls += ('/feed.aspx?c=' + $tok[9301]) }
    $codes = @()
    $d = Measure-Work { $script:codes = Get-Parallel $urls 50 }
    Check (@($codes | Where-Object { $_ -eq '200' }).Count -eq 100) ('R2 100 richieste sovrapposte: tutte 200 (' + @($codes | Where-Object { $_ -eq '200' }).Count + ')')
    Check ($d.Count -eq 5 -and $d['Com_select'] -le 0 -and $d['Com_insert'] -le 0 -and $d['Com_update'] -le 0 -and $d['Com_delete'] -le 0 -and $d['Connections'] -le 0) ('R2 nessuna interrogazione al database: select ' + $d['Com_select'] + ' insert ' + $d['Com_insert'] + ' update ' + $d['Com_update'] + ' delete ' + $d['Com_delete'] + ' connessioni ' + $d['Connections'])
    $dh = Measure-Work { $script:hcodes = Get-Parallel @(('/feed.aspx?c=' + $tok[9301]) * 1) 5 }
    Check ($dh['Com_select'] -le 0) 'R2 una richiesta con file pronto non interroga'

    # ---------------- generazione sotto richieste sovrapposte: un solo lavoratore ----------------
    $dBase = Measure-Work { $script:b = Get-Feed $tok[9313] }
    Check ($b.Status -eq 200) 'L0 generazione singola di riferimento'
    $baseSelect = $dBase['Com_select']
    Remove-Item -LiteralPath (Join-Path $folder (@(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9313-' })[0])) -Force
    Reset-App
    $urls = @(); for ($i = 0; $i -lt 30; $i++) { $urls += ('/feed.aspx?c=' + $tok[9313]) }
    $dc = Measure-Work { $script:ccodes = Get-Parallel $urls 30 }
    $n200 = @($ccodes | Where-Object { $_ -eq '200' }).Count; $n503 = @($ccodes | Where-Object { $_ -eq '503' }).Count
    Check ($ccodes.Count -eq 30 -and $n200 -ge 1 -and ($n200 + $n503) -eq 30) ('L1 30 richieste a freddo: una genera, le altre aspettano o ricevono 503 (200: ' + $n200 + ', 503: ' + $n503 + ')')
    Check ($dc['Com_select'] -le ($baseSelect + 12)) ('L1 una sola generazione (select ' + $dc['Com_select'] + ' contro ' + $baseSelect + ' di una singola)')
    $lockFree = Get-Scalar "SELECT IS_FREE_LOCK(CONCAT('ksfeed.', MD5(CONCAT(DATABASE(), ':', 9313)))) AS ksval;"
    Check ($lockFree -eq '1') 'L2 il blocco e libero dopo la generazione'
    $after = Get-Feed $tok[9313]
    Check ($after.Status -eq 200) 'L2 il file e pronto per chi arriva dopo'

    # ---------------- anteprima: le prime righe del file pronto ----------------
    $pv = Get-Feed ($tok[9301] + '&anteprima=1')
    $pvl = @($pv.Body -split "`r?`n" | Where-Object { $_ -ne '' })
    Check ($pv.Status -eq 200 -and $pv.Headers['content-type'] -match '^text/plain; charset=utf-8' -and $pv.Headers['cache-control'] -match 'no-store' -and -not $pv.Headers.ContainsKey('etag') -and $pv.Headers['x-feed-generato'] -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') 'PV1 anteprima: 200 text/plain no-store, nessun ETag, ora del file in X-Feed-Generato'
    Check ($pvl.Count -eq 21 -and $pvl[0] -ceq 'id|Codice|Ean|Disponibilita|Prezzo|Link') ('PV1 anteprima txt: intestazione piu 20 righe (viste ' + $pvl.Count + ')')
    Check (($pvl[1] -split '[|]')[0] -ceq $p1.Rows[0][0]) 'PV1 anteprima: le righe sono quelle del file'
    $pvx = Get-Feed ($tok[9304] + '&anteprima=1')
    $pvxl = @($pvx.Body -split "`r?`n" | Where-Object { $_ -ne '' })
    Check ($pvx.Status -eq 200 -and $pvxl.Count -eq 80 -and $pvxl[0] -match '^<\?xml' -and $pvxl[1] -match '^<catalogo>$' -and $pvxl[2] -match '^\s{2}<item>$') ('PV2 anteprima xml: 80 righe, xml indentato (viste ' + $pvxl.Count + ')')
    Check ((Get-Feed ('F' * 48 + '&anteprima=1')).Status -eq 404) 'PV3 anteprima con codice sconosciuto: 404'
    $pvh = Get-Feed ($tok[9301] + '&anteprima=1') @() 'HEAD'
    Check ($pvh.Status -eq 200 -and $pvh.Bytes.Length -eq 0) 'PV3 anteprima in HEAD: nessun corpo'
    $null = Get-Feed ($tok[9314] + '&anteprima=1')
    Check ((Get-Scalar 'SELECT IF(UltimaRichiestaUtc IS NULL, 1, 0) AS ksval FROM export_stato WHERE ExportId=9314;') -eq '1') 'PV4 l anteprima non registra la richiesta (UltimaRichiestaUtc resta vuota)'
    $null = Get-Feed $tok[9314]
    Check ((Get-Scalar 'SELECT IF(UltimaRichiestaUtc IS NULL, 1, 0) AS ksval FROM export_stato WHERE ExportId=9314;') -eq '0') 'PV4 una richiesta ordinaria la registra'

    # ---------------- impronta: ogni modifica della configurazione cambia il file, mai un file di una configurazione diversa ----------------
    $before9301 = @(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9301-' })
    $null = Invoke-Sql "UPDATE export_opzioni SET Separatore=';' WHERE ExportId=9301;" -Write
    Reset-App
    $fp1 = Get-Feed $tok[9301]
    $after9301 = @(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9301-' })
    Check ($fp1.Status -eq 200 -and $fp1.Body.StartsWith('id;Codice;Ean') -and $after9301.Count -eq 1 -and $before9301.Count -eq 1 -and $after9301[0] -ne $before9301[0]) 'FP1 cambio di un'' opzione nel gestionale: subito un file nuovo con il separatore nuovo, il vecchio e cancellato'
    $null = Invoke-Sql 'UPDATE `export` SET Azienda=''localhost2'' WHERE ID=9302;' -Write
    Reset-App
    $fp2 = Get-Feed $tok[9302]
    Check ($fp2.Status -eq 200 -and $fp2.Body -match 'https://localhost2/articolo\.aspx\?id=' -and $fp2.Body -notmatch 'https://www\.taikun\.it/articolo') 'FP2 cambio di dominio (alias della stessa azienda): i link del file sono quelli nuovi, mai quelli del file vecchio'
    $null = Invoke-Sql ('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9310, -1, -1, -1, -1, -1, -1, ' + $cand[2]['id'] + ');') -Write
    Reset-App
    $fp3 = Get-Feed $tok[9310]
    $p3 = Parse-Txt $fp3.Body
    Check ($fp3.Status -eq 200 -and $p3.Rows.Count -eq 3) ('FP3 un filtro in piu: il file nuovo ha tre articoli (visti ' + $p3.Rows.Count + ')')

    # ---------------- file scaduto: rigenera, nel frattempo si serve quello vecchio, mai un file a meta ----------------
    $f9301 = Join-Path $folder (@(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9301-' })[0])
    $fullLen = (Get-Item -LiteralPath $f9301).Length
    (Get-Item -LiteralPath $f9301).LastWriteTime = (Get-Date).AddMinutes(-90)
    $urls = @(); for ($i = 0; $i -lt 16; $i++) { $urls += ('/feed.aspx?c=' + $tok[9301]) }
    $lc = Get-Parallel $urls 16
    Check ($lc.Count -eq 16 -and @($lc | Where-Object { $_ -eq '200' }).Count -eq 16) ('L3 file scaduto con 16 richieste sovrapposte: una rigenera, le altre ricevono il file vecchio (tutte 200: ' + @($lc | Where-Object { $_ -eq '200' }).Count + ')')
    $fresh = Get-Item -LiteralPath $f9301
    Check (((Get-Date) - $fresh.LastWriteTime).TotalMinutes -lt 5 -and $fresh.Length -ge ($fullLen * 0.99) -and $fresh.Length -le ($fullLen * 1.01)) 'L3 il file scaduto e stato rigenerato per intero (pubblicazione atomica)'
    $left = @(& $folderFiles | Where-Object { $_ -match '[.]tmp$' }).Count
    Check ($left -eq 0) 'L3 nessun file temporaneo rimasto nella cartella'

    # ---------------- revoca, nuovo codice ----------------
    $null = Invoke-Sql 'UPDATE `export` SET Abilitato=0 WHERE ID=9301;' -Write
    Reset-App
    $rv = Get-Feed $tok[9301]
    Check ($rv.Status -eq 404 -and @(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9301-' }).Count -eq 0) 'V1 feed spento: 404 e il file pronto e cancellato'
    $null = Invoke-Sql 'UPDATE `export` SET Abilitato=1 WHERE ID=9301;' -Write
    $oldTok = $tok[9302]
    $null = Invoke-Sql 'UPDATE export_opzioni SET TokenAccesso=DEFAULT WHERE ExportId=9302;' -Write
    $newTok = Get-Scalar 'SELECT TokenAccesso AS ksval FROM export_opzioni WHERE ExportId=9302;'
    Check ($newTok -match '^[0-9A-F]{48}$' -and $newTok -ne $oldTok) 'V2 Nuovo codice: il database ne crea uno diverso'
    Reset-App
    $ro = Get-Feed $oldTok; $rn = Get-Feed $newTok
    Check ($ro.Status -eq 404 -and $rn.Status -eq 200) 'V2 il vecchio codice non vale piu, il nuovo si'
    $f9302 = @(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9302-' })
    Check ($f9302.Count -eq 1 -and $f9302[0] -match [regex]::Escape($newTok)) 'V2 il file del codice vecchio e stato cancellato'
    $tok[9302] = $newTok

    # ---------------- azienda del feed e configurazione ----------------
    $x7 = Get-Feed $tok[9307]
    Check ($x7.Status -eq 404) ('T1 feed di un altro dominio/azienda richiesto sul sito della prima azienda: 404 (visto ' + $x7.Status + ')')
    Check (@(& $folderFiles | Where-Object { $_ -match '-9307-' }).Count -eq 0) 'T1 nessun file generato per l altra azienda'
    $x8 = Get-Feed $tok[9308]
    $s8 = Get-Scalar 'SELECT UltimoErrore AS ksval FROM export_stato WHERE ExportId=9308;'
    Check ($x8.Status -eq 503 -and $s8 -eq 'AZIENDA_NON_RISOLTA' -and @(& $folderFiles | Where-Object { $_ -match '-9308-' }).Count -eq 0) ('T2 dominio senza azienda: nessun file, 503, errore registrato (' + $s8 + ')')
    $x6 = Get-Feed $tok[9306]
    Check ($x6.Status -eq 404) 'T3 feed spento dall inizio: 404'
    $x9 = Get-Feed $tok[9309]
    $s9 = Get-Scalar 'SELECT UltimoErrore AS ksval FROM export_stato WHERE ExportId=9309;'
    Check ($x9.Status -eq 503 -and $s9 -eq 'CONFIG_SEPARATORE_DECIMALE' -and @(& $folderFiles | Where-Object { $_ -match '-9309-' }).Count -eq 0) ('T4 separatore uguale al decimale: nessun file, 503, errore registrato (' + $s9 + ')')
    $dcool = Measure-Work { $script:x9b = Get-Feed $tok[9309] }
    Check ($x9b.Status -eq 503 -and $dcool['Com_select'] -le 0) ('T5 dopo un errore nessun nuovo tentativo per 5 minuti (select ' + $dcool['Com_select'] + ')')
    # stessa configurazione, generazione che fallisce (cartella non scrivibile): fino a 24 ore si serve il file precedente, oltre 503
    $f13 = @(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9313-' })
    Check ($f13.Count -eq 1) 'T6 il feed 9313 ha il suo file pronto'
    $p13file = Join-Path $folder $f13[0]
    $pool = 'IIS APPPOOL\KeepStoreRegOrderLabPool-20261025'
    (Get-Item -LiteralPath $p13file).LastWriteTime = (Get-Date).AddHours(-3)
    $null = & icacls.exe $folder /deny ($pool + ':(OI)(CI)(WD,AD)')
    try {
        $xs = Get-Feed $tok[9313]
        Check ($xs.Status -eq 200 -and $xs.Body -match '^id\|Codice') 'T6 generazione in errore con file di 3 ore della stessa configurazione: si serve il precedente'
        Check ((Get-Scalar 'SELECT IFNULL(UltimoErrore, ''-'') AS ksval FROM export_stato WHERE ExportId=9313;') -eq 'CARTELLA_NON_SCRIVIBILE') 'T6 l errore e registrato con il suo codice'
        (Get-Item -LiteralPath $p13file).LastWriteTime = (Get-Date).AddHours(-30)
        $xs2 = Get-Feed $tok[9313]
        Check ($xs2.Status -eq 503) 'T6 file piu vecchio di 24 ore e generazione in errore: 503, mai prezzi vecchi'
    } finally {
        $null = & icacls.exe $folder /remove:d $pool
        $null = & icacls.exe $folder /grant ($pool + ':(OI)(CI)M')   # il deny di icacls ha tolto anche i diritti di scrittura al permesso concesso: si riconcede
        Reset-App
    }
    # codici sconosciuti ben formati: tetto al secondo
    $urls = @(); for ($i = 0; $i -lt 60; $i++) { $urls += ('/feed.aspx?c=' + ('{0:X48}' -f (Get-Random -Minimum 1000000 -Maximum 99999999))) }
    $dm = Measure-Work { $script:mcodes = Get-Parallel $urls 60 }
    Check (@($mcodes | Where-Object { $_ -eq '404' -or $_ -eq '429' }).Count -eq 60 -and @($mcodes | Where-Object { $_ -eq '429' }).Count -ge 1 -and $dm['Com_select'] -le 40) ('T7 60 codici sconosciuti in un secondo: 404 o 429, interrogazioni limitate (429: ' + @($mcodes | Where-Object { $_ -eq '429' }).Count + ', select ' + $dm['Com_select'] + ')')

    # ---------------- filtri di selezione e scarti ----------------
    $r10 = Get-Feed $tok[9310]
    $p10 = Parse-Txt $r10.Body
    $got = @($p10.Rows | ForEach-Object { $_[0] } | Sort-Object)
    $want = @(@($cand[0]['id'], $cand[1]['id'], $cand[2]['id']) | Sort-Object)
    Check ($r10.Status -eq 200 -and ($got -join ',') -eq ($want -join ',')) ('S1 feed con tre articoli scelti (due dall inizio, il terzo aggiunto dalla prova dell impronta): esattamente quei tre (visti ' + ($got -join ',') + ')')
    $r13 = Get-Feed $tok[9313]
    if ($r13.Status -ne 200) { Diag 'r13' $r13; Write-Host ('  diag errore=' + (Get-Scalar 'SELECT IFNULL(UltimoErrore, ''-'') AS ksval FROM export_stato WHERE ExportId=9313;')); Write-Host ('  diag acl=' + ((& icacls.exe $folder) -join ' ')) }
    $p13 = Parse-Txt $r13.Body
    $ids13 = @($p13.Rows | ForEach-Object { $_[0] })
    $extra13 = @($p13.Rows | Where-Object { -not $feed1.ContainsKey($_[0]) })
    Check ($ids13.Count -eq $expIds.Count -and @($ids13 | Where-Object { -not $expSet.Contains($_) }).Count -eq 0) ('S2 con PrezzoZero=0 il feed e esattamente il catalogo esportabile (' + $ids13.Count + ' contro ' + $expIds.Count + ')')
    Check (@($extra13 | Where-Object { $_[4] -cne '0.00' }).Count -eq 0) ('S2 i prodotti in piu rispetto al feed che scarta i prezzi zero hanno tutti prezzo 0.00 (' + $extra13.Count + ')')
    Check ($extra13.Count + $p1.Rows.Count -eq $ids13.Count) 'S2 scartati = catalogo meno feed standard'

    # ---------------- mutazioni sul sito ----------------
    if (-not $SkipMutants) {
        $siteMutants = @(
            @('feed-spento-servito', 'App_Code\KeepStoreFeedService.vb', 'If cfg Is Nothing OrElse Not cfg.Enabled Then', 'If cfg Is Nothing Then', 'V1'),
            @('altra-azienda-servita', 'App_Code\KeepStoreFeedService.vb', 'tenant.CompanyId <> cfg.CompanyId', 'tenant.CompanyId < 0', 'T1'),
            @('vecchi-file-restano', 'App_Code\KeepStoreFeedService.vb', 'RemoveStaleFiles(cfg, Path.GetFileName(finalPath))', 'Dim keepOld As Integer = 0', 'V2'),
            @('promozioni-ignorate', 'App_Code\KeepStoreFeedService.vb', 'If res.AppliedOffer IsNot Nothing Then', 'If False Then', 'P3'),
            @('cooldown-assente', 'App_Code\KeepStoreFeedService.vb', 'If InCooldown(cfg) Then Return False', '', 'T5'),
            @('304-sempre', 'App_Code\KeepStoreFeedService.vb', 'If part.Trim() = etag OrElse part.Trim() = "*" Then notModified = True', 'notModified = True', 'H3'),
            @('guardia-non-scritta', 'App_Code\KeepStoreFeedService.vb', 'File.WriteAllText(guard, GuardConfigText, New UTF8Encoding(False))', 'Dim noGuard As Integer = 0', 'F1'),
            @('impronta-persa', 'App_Code\KeepStoreFeedService.vb', 'cfg.Options.Format, cfg.Fingerprint))', 'cfg.Options.Format, ""))', 'FP1'),
            @('anteprima-con-etag-sito', 'App_Code\KeepStoreFeedService.vb', 'r.AppendHeader("X-Feed-Generato"', 'r.AppendHeader("ETag", "x")' + "`n" + '        r.AppendHeader("X-Feed-Generato"', 'PV1'),
            @('stato-errore-non-scritto', 'App_Code\KeepStoreFeedService.vb', 'WriteState(cfg, 0, 0, ex.Code, False)', 'Dim noState As Integer = 0', 'T2')
        )
        $killed = 0; $total = 0
        foreach ($m in $siteMutants) {
            if ($MutantFilter -ne '' -and $m[0] -notlike ('*' + $MutantFilter + '*')) { continue }
            $total++
            $svcText = [IO.File]::ReadAllText((Join-Path $root $m[1]), $utf8).Replace("`r`n", "`n")
            if (-not $svcText.Contains($m[2])) { Write-Host ('  FAIL mutante sito ' + $m[0] + ': testo da mutare non trovato'); $e2e.Add('mutante sito ' + $m[0] + ' non applicabile'); continue }
            $before = $e2e.Count
            try {
                [IO.File]::WriteAllText((Join-Path $SitePath $m[1]), $svcText.Replace($m[2], $m[3]), $utf8); Start-Sleep -Seconds 3; Wait-Site
                Clear-FeedFiles
                $null = Invoke-Sql 'UPDATE `export` SET Abilitato=1 WHERE ID IN (9301, 9306, 9307, 9308, 9309); UPDATE `export` SET Abilitato=0 WHERE ID=9306; DELETE FROM export_stato WHERE ExportId BETWEEN 9301 AND 9330;' -Write
                Reset-App
                switch ($m[4]) {
                    'V1' { $null = Invoke-Sql 'UPDATE `export` SET Abilitato=0 WHERE ID=9301;' -Write; Reset-App; $rr = Get-Feed $tok[9301]; Check ($rr.Status -eq 404) ('mutante ' + $m[0] + ': feed spento 404'); $null = Invoke-Sql 'UPDATE `export` SET Abilitato=1 WHERE ID=9301;' -Write }
                    'T1' { $rr = Get-Feed $tok[9307]; Check ($rr.Status -eq 404) ('mutante ' + $m[0] + ': altra azienda 404') }
                    'V2' { $a1 = Get-Feed $tok[9302]; $o2 = $tok[9302]; $null = Invoke-Sql 'UPDATE export_opzioni SET TokenAccesso=DEFAULT WHERE ExportId=9302;' -Write; $nt = Get-Scalar 'SELECT TokenAccesso AS ksval FROM export_opzioni WHERE ExportId=9302;'; Reset-App; $a2 = Get-Feed $nt; Check (@(& $folderFiles | Where-Object { $_ -match '^[0-9a-f]{8}-9302-' }).Count -eq 1) ('mutante ' + $m[0] + ': un solo file per feed'); $tok[9302] = $nt }
                    'P3' { $a1 = Get-Feed $tok[9301]; $q = Parse-Txt $a1.Body; $row = @($q.Rows | Where-Object { $_[0] -eq $cases[0].art['id'] })[0]; Check ($null -ne $row -and $row[4] -ceq (Money (((Dec $cases[0].art['net']) * 0.9d) * ((Dec $cases[0].art['gross']) / (Dec $cases[0].art['net']))))) ('mutante ' + $m[0] + ': promozione applicata') }
                    'T5' { $null = Get-Feed $tok[9309]; $dd = Measure-Work { $script:y = Get-Feed $tok[9309] }; Check ($dd['Com_select'] -le 0) ('mutante ' + $m[0] + ': nessun nuovo tentativo') }
                    'H3' { $a1 = Get-Feed $tok[9301]; $a2 = Get-Feed $tok[9301] @('If-None-Match: W/"0-0"'); Check ($a2.Status -eq 200) ('mutante ' + $m[0] + ': etag diverso = 200') }
                    'F1' { $a1 = Get-Feed $tok[9301]; Check (Test-Path -LiteralPath (Join-Path $folder 'web.config')) ('mutante ' + $m[0] + ': guardia scritta') }
                    'FP1' { $null = Invoke-Sql "UPDATE export_opzioni SET Separatore='|' WHERE ExportId=9301;" -Write; Reset-App; $b1 = Get-Feed $tok[9301]; Check ($b1.Body.StartsWith('id|Codice|Ean')) ('mutante ' + $m[0] + ': prima del cambio il separatore e |'); $null = Invoke-Sql "UPDATE export_opzioni SET Separatore=';' WHERE ExportId=9301;" -Write; Reset-App; $b2 = Get-Feed $tok[9301]; Check ($b2.Body.StartsWith('id;Codice;Ean')) ('mutante ' + $m[0] + ': separatore nuovo subito') }
                    'PV1' { $b1 = Get-Feed ($tok[9301] + '&anteprima=1'); Check (-not $b1.Headers.ContainsKey('etag')) ('mutante ' + $m[0] + ': anteprima senza ETag') }
                    'T2' { $null = Get-Feed $tok[9308]; $s = Get-Scalar 'SELECT UltimoErrore AS ksval FROM export_stato WHERE ExportId=9308;'; Check ($s -eq 'AZIENDA_NON_RISOLTA') ('mutante ' + $m[0] + ': errore registrato') }
                }
                $diff = $e2e.Count - $before
                if ($diff -gt 0) { $killed++; Write-Host ('  ok   mutante sito ' + $m[0] + ' ucciso'); while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) } }
                else { Write-Host ('  FAIL mutante sito ' + $m[0] + ' sopravvissuto'); $e2e.Add('mutante sito ' + $m[0] + ' sopravvissuto') }
            } catch {
                $killed++; Write-Host ('  ok   mutante sito ' + $m[0] + ' ucciso (prova non completabile: ' + $_.Exception.Message + ')')
                while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) }
            } finally {
                Deploy-Repo; Clear-FeedFiles
            }
        }
        Write-Host ('  mutanti sul sito uccisi ' + $killed + '/' + $total)
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); Write-Host ('  in: ' + ($_.InvocationInfo.PositionMessage -replace '\s+', ' ')); $e2e.Add('eccezione: ' + $_.Exception.Message)
} finally {
    try { Clear-FeedFolder } catch { Write-Host ('  ATTENZIONE: cartella dei feed non ripulita: ' + $_.Exception.Message) }
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $e2e.Add('ripristino del sito') }
    if ($fixtures) {
        try {
            $q = New-Object Text.StringBuilder
            [void]$q.AppendLine('DELETE FROM voffertearticoli WHERE OfferteID BETWEEN 9990101 AND 9990140;')
            [void]$q.AppendLine('DELETE FROM offertedettaglio WHERE id BETWEEN 9990101 AND 9990140;')
            [void]$q.AppendLine('DELETE FROM offerte WHERE id BETWEEN 9990101 AND 9990140;')
            if ($null -ne $noPromoArt) { [void]$q.AppendLine('UPDATE articoli SET NoPromo=0 WHERE id=' + $noPromoArt + ' AND NoPromo=1;') }
            if ($trickBackup) { [void]$q.AppendLine('UPDATE articoli a JOIN ks_feedengine_trick t ON t.id=a.id SET a.Descrizione1=t.Descrizione1, a.Descrizione2=t.Descrizione2, a.Ean=t.Ean, a.DescrizioneHTML=t.DescrizioneHTML, a.SpedizioneGratis_Listini=t.SpedizioneGratis_Listini, a.SpedizioneGratis_Data_Inizio=t.SpedizioneGratis_Data_Inizio, a.SpedizioneGratis_Data_Fine=t.SpedizioneGratis_Data_Fine;'); [void]$q.AppendLine('DROP TABLE IF EXISTS ks_feedengine_trick;') }
            $rr = Invoke-Sql $q.ToString() -Write; if (Sql-Failed $rr) { Write-Host '  ATTENZIONE: pulizia delle offerte o dell articolo non riuscita' ; $e2e.Add('pulizia offerte') }
        } catch { Write-Host ('  ATTENZIONE: pulizia: ' + $_.Exception.Message); $e2e.Add('pulizia') }
    }
    if ($migApplied) {
        try {
            $null = Invoke-Sql 'DELETE FROM export_filtri WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM export_colonne WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM export_stato WHERE ExportId BETWEEN 9301 AND 9330; DELETE FROM `export` WHERE ID BETWEEN 9301 AND 9330 AND Descrizione LIKE ''KSFEEDENGINE%'';' -Write
            $rb = (Invoke-Sql ('SET @KeepStoreConfirmDropFeedData=1;' + "`n" + [IO.File]::ReadAllText((Join-Path $migDir ($prefixMig + 'rollback.sql')), $utf8)) -Write) -join "`n"
            if ($rb -match 'ERROR \d+|^stderr:') { Write-Host '  ATTENZIONE: rollback della migrazione non riuscito'; $e2e.Add('rollback della migrazione') }
            $left = Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='export_opzioni';"
            Check ($left -eq '0') 'Z1 lo schema del LAB e tornato allo stato iniziale (nessuna colonna nuova)'
        } catch { Write-Host ('  ATTENZIONE: rollback: ' + $_.Exception.Message); $e2e.Add('rollback') }
    }
    if ($siteHeld) { try { $siteMutex.ReleaseMutex() } catch { } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'EXPORT_FEED_ENGINE PASS' } else { Write-Host 'EXPORT_FEED_ENGINE FAIL' }
exit $exit
