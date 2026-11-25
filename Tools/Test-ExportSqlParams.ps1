[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Baseline, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# EXPORT-SQL-PARAMS-1A. export.aspx (feed per i comparatori) legge id e pwd dall'URL: il testo SQL non deve piu contenere valori della richiesta, ne altri valori
# (listino, giacenza, vettore, filtri): tutto passa da parametri. Il risultato per i link legittimi non cambia (parita con il comportamento precedente).
# Prova HTTP sul sito LAB (https, 127.0.0.1 forzato, porta 18843, DB LAB, identita verificata prima di scrivere). Righe sintetiche 9101-9109 nella tabella export
# (e in export_filtri), eliminate alla fine. La copia di export.aspx.vb sul sito LAB e sostituita con quella del repository e poi i byte originali sono rimessi.
# -Baseline: NON installa il codice del repository (il sito resta com'e): serve a vedere il test ROSSO sul codice vecchio e VERDE nei casi di parita.
# EXPORT-FEED-REPAIR-1A: la pagina ora scrive TUTTE le righe (prima: intestazione + una riga per il Response.End nel ciclo) e il primo filtro applica anche ArticoliId:
# i casi P6 verificano il contenuto completo; la completezza e i prezzi sono in Tools/Test-ExportFeedRepair.ps1. Un solo uso del sito LAB alla volta (mutex).
# Mai password reali in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'EXPORT_SQL FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$pageFile = 'export.aspx.vb'
$repoBytes = [IO.File]::ReadAllBytes((Join-Path $root $pageFile))
$origBytes = [IO.File]::ReadAllBytes((Join-Path $SitePath $pageFile))
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$tmp = Join-Path $env:TEMP ('ks-exportsql-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$e2e = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) } }

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f }
        return @($o)
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
# Il valore e la riga che segue l'intestazione 'ksval' (la query deve chiamare ksval la colonna).
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql $sql)
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ([string]$o[$i] -eq 'ksval') { return ([string]$o[$i + 1]).Trim() } }
    return ''
}
function To-Hex([string]$s) { return (($utf8.GetBytes($s) | ForEach-Object { $_.ToString('X2') }) -join '') }
function From-Hex([string]$h) { $b = New-Object byte[] ($h.Length / 2); for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($h.Substring(2 * $i, 2), 16) }; return $utf8.GetString($b) }
function Sql-Text([string]$s) { return ("CONVERT(UNHEX('" + (To-Hex $s) + "') USING utf8mb4)") }

# Una richiesta GET: stato, Location e corpo (UTF-8). La query e codificata UNA volta sola (EscapeDataString).
function Invoke-Export([string]$idText, $pwd) {
    # La pagina non chiude la connessione quando termina con Response.End (difetto preesistente, fuori da questo task): il LAB ha max_connections=40.
    # Ogni 12 richieste si fa ripartire l'applicazione (data di web.config) per liberare le connessioni, come negli altri test sul sito LAB.
    if (-not $script:inReset -and $script:reqCount -ge 12) { Reset-App }
    $script:reqCount++
    $q = 'id=' + $idText
    if ($null -ne $pwd) { $q += '&pwd=' + [Uri]::EscapeDataString([string]$pwd) }
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.txt')
    $a = @('--noproxy', '*', '-s', '--max-time', '170', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}', ($base + '/export.aspx?' + $q))
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 2 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $h = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $loc = ''; $m = [regex]::Match($h, '(?im)^Location:\s*(\S+)'); if ($m.Success) { $loc = $m.Groups[1].Value }
    $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, $utf8) } else { '' }
    return @{ Status = [int]$parts[0]; Location = $loc; Body = $body }
}
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Export '1' 'zz-nonexistent-probe').Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
$script:reqCount = 0; $script:inReset = $false
function Reset-App {
    $script:inReset = $true
    try { (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date; Start-Sleep -Seconds 6; $script:reqCount = 0; Wait-Site; $script:reqCount = 0 } finally { $script:inReset = $false }
}
function Deploy-Repo { [IO.File]::WriteAllBytes((Join-Path $SitePath $pageFile), $repoBytes); Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site { [IO.File]::WriteAllBytes((Join-Path $SitePath $pageFile), $origBytes); Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$text) { $bom = ($repoBytes.Length -ge 3 -and $repoBytes[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $pageFile), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

$rejected = 'ID o Password errati.'
$ids = @(9101, 9102, 9103, 9104, 9105, 9106, 9107, 9108, 9109)
$pwdWeird = 'O' + [char]39 + 'Br"i' + [char]92 + 'en x' + [char]39 + ' or ' + [char]39 + '1' + [char]39 + '=' + [char]39 + '1 union select'
$pwdPlain = 'KsExp-Ab C'
$fmtHead = '#Codice#|#Descrizione1#'

$exit = 0
$created = $false
$siteMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLabSite18843'); $siteHeld = $false
try {
    try { $siteHeld = $siteMutex.WaitOne(1800000) } catch [System.Threading.AbandonedMutexException] { $siteHeld = $true }
    if (-not $siteHeld) { throw 'LAB_SITE_BUSY' }
    # --- Identita del LAB e righe libere ---
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    $busy = Get-Scalar ('SELECT COUNT(*) AS ksval FROM `export` WHERE ID BETWEEN 9101 AND 9109;')
    if ($busy -ne '0') { throw 'FIXTURE_IDS_NOT_FREE' }
    $unfilt = 'AND (isnull(offerteid) OR offerteqntminima = 1 OR offertemultipli=1)'

    # --- Dati di riferimento letti dal LAB (nessuna password in output) ---
    $realPlain = Get-Scalar 'SELECT ID AS ksval FROM `export` WHERE Abilitato=1 AND NListino>0 AND FormatString NOT LIKE ''%CostoSpedizioneProdo%'' AND `Password` REGEXP ''^[A-Za-z0-9]+$'' ORDER BY ID LIMIT 1;'
    $realOdd = Get-Scalar 'SELECT ID AS ksval FROM `export` WHERE Abilitato=1 AND NListino>0 AND FormatString NOT LIKE ''%CostoSpedizioneProdo%'' AND (INSTR(`Password`,''%'')>0 OR INSTR(`Password`,''_'')>0 OR INSTR(`Password`,'' '')>0) ORDER BY ID LIMIT 1;'
    $mkt = Get-Scalar ('SELECT MarcheId AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId=1 ' + $unfilt + ' GROUP BY MarcheId HAVING COUNT(*)>=2 ORDER BY MarcheId LIMIT 1;')
    $mktOther = Get-Scalar ('SELECT MarcheId AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId=1 ' + $unfilt + ' AND MarcheId>' + $mkt + ' ORDER BY MarcheId DESC LIMIT 1;')
    if ($mkt -eq '' -or $mktOther -eq '') { throw 'NO_FILTER_DATA' }
    $ord = 'ORDER BY settoriid, categorieid, tipologieid, marcheid, codice'
    $codeFirstMkt = Get-Scalar ('SELECT TRIM(LEFT(codice,255)) AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId=1 AND MarcheId=' + $mkt + ' ' + $unfilt + ' ' + $ord + ' LIMIT 1;')
    $artSecond = Get-Scalar ('SELECT id AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId=1 AND MarcheId=' + $mkt + ' ' + $unfilt + ' ' + $ord + ' LIMIT 1 OFFSET 1;')
    $codeUnion = Get-Scalar ('SELECT TRIM(LEFT(codice,255)) AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND ((SettoriId=1 AND MarcheId=' + $mktOther + ') OR id=' + $artSecond + ') ' + $unfilt + ' ' + $ord + ' LIMIT 1;')
    if ($artSecond -eq '') { throw 'NO_FILTER_DATA_SECOND_ARTICLE' }
    $codeOther = Get-Scalar ('SELECT TRIM(LEFT(codice,255)) AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId=1 AND MarcheId=' + $mktOther + ' ' + $unfilt + ' ' + $ord + ' LIMIT 1;')
    $codeAny = Get-Scalar ('SELECT TRIM(LEFT(codice,255)) AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND Giacenza>=-1 ' + $unfilt + ' ' + $ord + ' LIMIT 1;')

    # --- Righe sintetiche ---
    $ins = New-Object Text.StringBuilder
    function Add-Row([int]$id, [string]$desc, $pwdText, [string]$fmt, [int]$listino, [string]$giac, [int]$ivaTipo, [int]$vet) {
        $p = if ($null -eq $pwdText) { 'NULL' } else { Sql-Text $pwdText }
        [void]$ins.AppendLine('INSERT INTO `export` (ID, Descrizione, `Password`, FormatString, NListino, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, NListino2, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, Abilitato) VALUES (' + $id + ', ''KSEXPORTTEST' + $id + ''', ' + $p + ', ' + (Sql-Text $fmt) + ', ' + $listino + ', ' + $ivaTipo + ', ' + $giac + ', 0, 1, ''www.taikun.it'', ''txt'', ' + $vet + ', 0, 0, 0, 0, 0, 1);')
    }
    Add-Row 9101 'a' $pwdWeird $fmtHead 10 '2000000000' 2 0
    Add-Row 9102 'b' $pwdPlain $fmtHead 10 '-1' 2 0
    Add-Row 9103 'c' $pwdPlain '#Codice#|#Marca#' 10 '2000000000' 2 0
    Add-Row 9104 'd' '' '#Codice#' 10 '2000000000' 2 0
    Add-Row 9105 'e' 'KsExpVet' '#Codice#|#CostoSpedizioneProdo#' 10 '-1' 1 3
    Add-Row 9106 'f' 'KsExpFlt1' '#Codice#' 10 '-1' 2 0
    Add-Row 9107 'g' 'KsExpFlt2' '#Codice#' 10 '-1' 2 0
    Add-Row 9108 'h' 'KsExpFlt3' '#Codice#' 10 '-1' 2 0
    # Filtri: 9106 = una riga (marca A, settore 1); 9107 = riga 1 marca altra + riga 2 marca A con articolo preciso (ramo OR);
    # 9108 = UNA riga con marca A e un ArticoliId che NON e il primo: il primo filtro ignora ArticoliId (difetto preesistente, da non correggere).
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9106, ' + $mkt + ', 1, -1, -1, -1, -1, -1);')
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9107, ' + $mktOther + ', 1, -1, -1, -1, -1, -1);')
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9107, ' + $mkt + ', 1, -1, -1, -1, -1, ' + $artSecond + ');')
    [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (9108, ' + $mkt + ', 1, -1, -1, -1, -1, ' + $artSecond + ');')
    $null = Invoke-Sql $ins.ToString() -Write
    $created = $true
    $made = Get-Scalar 'SELECT COUNT(*) AS ksval FROM `export` WHERE ID BETWEEN 9101 AND 9109;'
    Check ($made -eq '8') 'fixture create sul LAB (8 righe in export)'

    if (-not $Baseline) { Deploy-Repo } else { Wait-Site }
    $codeOfArt = Get-Scalar ('SELECT TRIM(LEFT(codice,255)) AS ksval FROM vsuperarticoli WHERE id=' + $artSecond + ' LIMIT 1;')
    Check ($codeFirstMkt -cne $codeOfArt -and $codeUnion -cne '') 'fixture filtri discriminante (secondo articolo diverso dal primo della marca)'
    $headerAB = 'Codice|Titolo'

    function Is-Rejected($r) { return ($r.Status -eq 200 -and $r.Body.Trim() -ceq $rejected) }
    function Is-Header($r, [string]$h) { return ($r.Status -eq 200 -and $r.Body.StartsWith($h)) -and ($r.Body.Trim() -cne $rejected) }

    function Run-Cases {
        # P1: password con apice, virgolette, barra rovesciata e parole SQL: e un valore come un altro.
        $r = Invoke-Export '9101' $pwdWeird
        Check (Is-Header $r $headerAB) 'P1 password con apice/virgolette/barra/parole SQL = accesso, solo intestazione'
        Check (@($r.Body -split "`r?`n" | Where-Object { $_ -ne '' }).Count -eq 1) 'P1 nessun articolo (giacenza irraggiungibile)'
        # P2: payload d'iniezione = rifiuto esatto, mai errore ne feed.
        $payloads = @(
            @('apice+or', ('x' + [char]39 + ' or ' + [char]39 + '1' + [char]39 + '=' + [char]39 + '1')),
            @('apice+or-commento', ('x' + [char]39 + ' or 1=1-- ')),
            @('barra', [string][char]92),
            @('union', (' ' + [char]39 + ' union select 1-- ')),
            @('percento', '%'),
            @('underscore', '_'),
            @('lunga', ('A' * 400))
        )
        foreach ($p in $payloads) {
            $r = Invoke-Export '9102' $p[1]
            Check (Is-Rejected $r) ('P2 payload "' + $p[0] + '" = ID o Password errati (visto ' + $r.Status + ' ' + $r.Location + ')')
        }
        Check (Is-Rejected (Invoke-Export '9101' ($pwdWeird + 'x'))) 'P2 password quasi giusta = rifiuto'
        # P3: parita con il confronto di prima (collation ai_ci, spazi significativi, percento e underscore letterali).
        Check (Is-Header (Invoke-Export '9102' $pwdPlain) $headerAB) 'P3 password esatta'
        Check (Is-Header (Invoke-Export '9102' 'ksexp-ab c') $headerAB) 'P3 maiuscole/minuscole indifferenti (come prima)'
        Check (Is-Header (Invoke-Export '9102' ('KsExp-Ab C').Replace('E', [string][char]0x00C9)) $headerAB) 'P3 accento indifferente (collation ai_ci, come prima)'
        Check (Is-Rejected (Invoke-Export '9102' ($pwdPlain + ' '))) 'P3 spazio finale = rifiuto (come prima)'
        Check (Is-Rejected (Invoke-Export '9102' 'KsExp-Ab%')) 'P3 percento non e un carattere jolly'
        Check (Is-Rejected (Invoke-Export '9102' 'KsExp_Ab C')) 'P3 underscore non e un carattere jolly'
        foreach ($rid in @($realPlain, $realOdd)) {
            if ($rid -eq '') { Check $false 'P3 manca una riga reale del LAB per la parita'; continue }
            $realPwd = From-Hex (Get-Scalar ('SELECT HEX(`Password`) AS ksval FROM `export` WHERE ID=' + $rid + ';'))
            $realFmt = Get-Scalar ('SELECT HEX(FormatString) AS ksval FROM `export` WHERE ID=' + $rid + ';')
            $expHead = (From-Hex $realFmt).Replace('#', '').Replace('Descrizione1', 'Titolo')
            $r = Invoke-Export $rid $realPwd
            Check (Is-Header $r $expHead) ('P3 riga reale ' + $rid + ' del LAB: stesso feed (intestazione) con la sua password')
            Check (Is-Rejected (Invoke-Export $rid ($realPwd + 'Z'))) ('P3 riga reale ' + $rid + ': password sbagliata = rifiuto')
        }
        # P4: password assente o vuota con riga a password vuota = accesso (parita con la password vuota di prima).
        Check (Is-Header (Invoke-Export '9104' $null) 'Codice') 'P4 pwd assente + riga con password vuota = accesso (come prima)'
        Check (Is-Header (Invoke-Export '9104' '') 'Codice') 'P4 pwd vuota + riga con password vuota = accesso (come prima)'
        Check (Is-Rejected (Invoke-Export '9102' $null)) 'P4 pwd assente + riga con password piena = rifiuto'
        # P5: id e password restano legati.
        Check (Is-Header (Invoke-Export '9103' $pwdPlain) 'Codice|Marca') 'P5 stessa password, riga 9103 = il suo formato'
        Check (Is-Header (Invoke-Export '9102' $pwdPlain) 'Codice|Titolo') 'P5 stessa password, riga 9102 = il suo formato'
        Check (Is-Rejected (Invoke-Export '9101' $pwdPlain)) 'P5 id di una riga con la password di un altra = rifiuto'
        Check (Is-Rejected (Invoke-Export '9199' $pwdPlain)) 'P5 id inesistente con una password valida = rifiuto'
        Check (Is-Rejected (Invoke-Export '9105' 'KsExp-Ab C')) 'P5 id 9105 con la password di 9102 = rifiuto'
        # P6: percorso con articoli, vettore, filtri.
        $r = Invoke-Export '9102' $pwdPlain
        $lines = @($r.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        Check ($lines.Count -gt 2 -and $lines[1].StartsWith($codeAny + '|')) 'P6 giacenza -1: intestazione + tutti gli articoli, il primo e il primo dell ordine (listino 10)'
        $r = Invoke-Export '9105' 'KsExpVet'
        $lines = @($r.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        $bodyLines = @($lines | Select-Object -Skip 1)
        Check ($r.Status -eq 200 -and $bodyLines.Count -gt 1 -and @($bodyLines | Where-Object { $_ -notmatch '\|[0-9]+([.,][0-9]+)?$' }).Count -eq 0) 'P6 costo spedizione reale da vettoricosti (vettore 3) in ogni riga'
        $r = Invoke-Export '9106' 'KsExpFlt1'
        $lines = @($r.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        Check ($lines.Count -ge 3 -and $lines[1] -ceq $codeFirstMkt) 'P6 filtro con una riga: tutti gli articoli della marca, il primo in ordine'
        $r = Invoke-Export '9107' 'KsExpFlt2'
        $lines = @($r.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        Check ($lines.Count -ge 3 -and $lines[1] -ceq $codeUnion) 'P6 filtro con due righe (ramo OR con ArticoliId): il primo dell unione in ordine'
        $r = Invoke-Export '9108' 'KsExpFlt3'
        $lines = @($r.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        Check ($lines.Count -eq 2 -and $lines[1] -ceq $codeOfArt) 'P6 il primo filtro applica ArticoliId (una riga con marca e articolo = quel solo articolo)'
    }

    Run-Cases

    # --- P7: sorgente. Nessun testo SQL con valori composti. ---
    $src = Get-Text $repoBytes
    $sqlLines = @($src -split "`r?`n" | Where-Object { $_ -match 'CommandText\s*=|CommandText\s*&' -and $_.TrimStart() -notmatch "^'" })
    $bad = @($sqlLines | Where-Object { $_ -match '&\s*(ID|Password|nListino|idArticolo|idVettore|Listino|Giacenza)\b' -or $_ -match '&\s*dr2\.Item' })
    Check ($bad.Count -eq 0) ('P7 nessun CommandText compone valori (righe sospette: ' + $bad.Count + ')')
    Check ($src -match '(?i)Parameters\.AddWithValue\("@pwd"') 'P7 la password passa da un parametro'
    Check ($src -match '(?i)export\.id\s*=\s*@id') 'P7 il predicato export.id e un parametro'

    if ($e2e.Count -gt 0) { $exit = 1 }

    # --- Mutanti ---
    if (-not $SkipMutants -and -not $Baseline -and $exit -eq 0) {
        $mutants = [ordered]@{
            'M1_CONCAT_PWD'     = @{ From = 'export.`password`=@pwd'; To = 'export.`password`=''" & Password & "''' }
            'M2_PARAM_NAME'     = @{ From = 'export.`password`=@pwd'; To = 'export.`password`=@password' }
            'M3_NULL_PWD'       = @{ From = 'If(Password, "")'; To = 'If(Password, Nothing)' }
            'M4_REPLACE_APOS'   = @{ From = '"@pwd", If(Password, "")'; To = '"@pwd", If(Password, "").Replace("''", "")' }
            'M5_ID_IGNORED'     = @{ From = 'AddWithValue("@id", ID)'; To = 'AddWithValue("@id", 1)' }
            'M6_ID_PRED_OMITTED' = @{ From = 'export.id=@id and '; To = '' }
            'M7_LIKE'           = @{ From = 'export.`password`=@pwd'; To = 'export.`password` like @pwd' }
            'M8_FIRST_FILTER_ARTICLE' = @{ From = '" and ( ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (" & FiltroArticolo(dr2, cmd, idxFiltro) & "))"'; To = '" and ( ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (1=1))"' }
            'M9_FILTER_SUFFIX'  = @{ From = 'Dim suffisso As String = indice.ToString()'; To = 'Dim suffisso As String = "0"' }
            'M10_GIACENZA_PARAM' = @{ From = 'AddWithValue("@gia", Giacenza)'; To = 'AddWithValue("@gia", -1)' }
            'M11_VETTORE_PARAM' = @{ From = 'AddWithValue("@vet", idVettore)'; To = 'AddWithValue("@vet", 99999)' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $mu = $mutants[$id]
            $total++
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            $before = $e2e.Count
            try {
                Set-Mutant ($src.Replace($mu.From, $mu.To))
                Run-Cases
                $diff = $e2e.Count - $before
                if ($diff -gt 0) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $diff + ' casi diversi)') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
                # i FAIL dei mutanti non sono fallimenti del test: li riporto fuori dall'elenco
                while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    if ($created) {
        try { $null = Invoke-Sql ('DELETE FROM export_filtri WHERE ExportId BETWEEN 9101 AND 9109; DELETE FROM `export` WHERE ID BETWEEN 9101 AND 9109 AND Descrizione LIKE ''KSEXPORTTEST%'';') -Write } catch { Write-Host ('  ATTENZIONE: pulizia delle righe sintetiche non riuscita: ' + $_.Exception.Message); $exit = 1 }
    }
    if ($siteHeld) { try { $siteMutex.ReleaseMutex() } catch { } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'EXPORT_SQL PASS' } else { Write-Host 'EXPORT_SQL FAIL' }
exit $exit
