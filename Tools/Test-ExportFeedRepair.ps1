[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Baseline, [switch]$NoPool, [switch]$BaselineNoEnd, [switch]$OnlyPerf, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# EXPORT-FEED-REPAIR-1A. I vecchi indirizzi dei feed (export.aspx = txt, export_csv.aspx = csv) tornano completi e corretti:
#  - il feed contiene TUTTI gli articoli esportabili (prima: intestazione + una riga, per il Response.End nel ciclo) e un articolo una sola volta;
#  - il csv risponde (prima: 302 per dizionario sensibile alle maiuscole + connessione mai aperta);
#  - un feed con Abilitato=0 risponde "Feed non disponibile" senza dati (e senza svelare lo stato a chi sbaglia la password);
#  - #DescrizioneLungaHtml# e riconosciuto; link e immagini sono https;
#  - prezzo = offerta per 1 pezzo se valida oggi (regola del sito), altrimenti listino; mai scaglioni ne multipli;
#  - le connessioni al database NON crescono con il numero di righe (una connessione ausiliaria fuori dal ciclo).
# Prova HTTP sul sito LAB (https, 127.0.0.1 forzato, porta 18843, database LAB, identita verificata prima di scrivere). Righe sintetiche 9201-9224, quattro offerte sintetiche (OfferteID 9990001) in `export`,
# eliminate alla fine. Le copie di export.aspx.vb e export_csv.aspx.vb sul sito LAB sono sostituite con quelle del repository e poi i byte originali sono rimessi.
# -Baseline: installa il codice della base (git ref fisso) invece di quello del repository: serve a vedere il test ROSSO sul codice vecchio.
# -BaselineNoEnd (con -Baseline) e -OnlyPerf: misura del costo "prima" = codice di base con i soli Response.End del ciclo tolti (il feed diventa completo e si vede il costo per riga).
# -NoPool: le pagine di prova usano Pooling=false (come il server online: ogni Open e una connessione fisica) per misurare le aperture; senza, il pool del LAB le nasconde.
# Un solo uso del sito LAB alla volta: mutex di sistema Global\KeepStoreLabSite18843 (come le altre prove sul sito LAB).
# Mai password in output (le password dei feed sintetici sono scelte qui; nessuna lettura di password reali). Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'EXPORT_FEED FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$baseRef = 'b2066478'
$pages = @('export.aspx.vb', 'export_csv.aspx.vb')
$origBytes = @{}; $repoBytes = @{}
foreach ($p in $pages) {
    $origBytes[$p] = [IO.File]::ReadAllBytes((Join-Path $SitePath $p))
    if ($Baseline) {
        $tmpGit = Join-Path $env:TEMP ('ks-base-' + [Guid]::NewGuid().ToString('N') + '.vb')
        $psi = New-Object Diagnostics.ProcessStartInfo; $psi.FileName = 'git'; $psi.Arguments = '-C "' + $root + '" show ' + $baseRef + ':' + $p
        $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.CreateNoWindow = $true
        $proc = [Diagnostics.Process]::Start($psi); $ms = New-Object IO.MemoryStream; $proc.StandardOutput.BaseStream.CopyTo($ms); $proc.WaitForExit()
        if ($proc.ExitCode -ne 0 -or $ms.Length -lt 1000) { Write-Host 'EXPORT_FEED FAIL: git show della base non riuscito'; exit 1 }
        $repoBytes[$p] = $ms.ToArray()
        if ($BaselineNoEnd) {
            $bt = [Text.Encoding]::UTF8.GetString($repoBytes[$p]); $bBom = ($bt.Length -gt 0 -and $bt[0] -eq [char]0xFEFF); if ($bBom) { $bt = $bt.Substring(1) }
            $bt = [regex]::Replace($bt, '(?m)^\t+Response\.End\(\)\r?$', '')
            $repoBytes[$p] = [byte[]]((New-Object Text.UTF8Encoding($bBom)).GetPreamble() + $utf8.GetBytes($bt))
        }
    } else { $repoBytes[$p] = [IO.File]::ReadAllBytes((Join-Path $root $p)) }
    if ($NoPool) {
        $tt = [Text.Encoding]::UTF8.GetString($repoBytes[$p]); $hasBom = ($tt.Length -gt 0 -and $tt[0] -eq [char]0xFEFF); if ($hasBom) { $tt = $tt.Substring(1) }
        $tt = $tt.Replace('ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString', 'ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString & ";Pooling=false"')
        $repoBytes[$p] = [byte[]]((New-Object Text.UTF8Encoding($hasBom)).GetPreamble() + $utf8.GetBytes($tt))
    }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$tmp = Join-Path $env:TEMP ('ks-exportfeed-' + [Guid]::NewGuid().ToString('N'))
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
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql $sql)
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ([string]$o[$i] -eq 'ksval') { return ([string]$o[$i + 1]).Trim() } }
    return ''
}
# Righe di un SELECT: la prima riga utile dopo 'mode=' e l'intestazione (tab), le altre sono righe di dati.
function Get-Rows([string]$sql) {
    $o = @(Invoke-Sql $sql) | Where-Object { ([string]$_) -notmatch '^mode=' -and ([string]$_) -notmatch '^stderr' -and ([string]$_).Trim() -ne '' }
    if ($o.Count -lt 1) { return @() }
    $h = ([string]$o[0]).Split("`t"); $res = New-Object Collections.Generic.List[object]
    for ($i = 1; $i -lt $o.Count; $i++) { $c = ([string]$o[$i]).Split("`t"); $r = @{}; for ($k = 0; $k -lt $h.Count; $k++) { $r[$h[$k]] = if ($k -lt $c.Count) { $c[$k] } else { '' } }; $res.Add($r) }
    return $res.ToArray()
}
function To-Hex([string]$s) { return (($utf8.GetBytes($s) | ForEach-Object { $_.ToString('X2') }) -join '') }
function Sql-Text([string]$s) { return ("CONVERT(UNHEX('" + (To-Hex $s) + "') USING utf8mb4)") }

# Una richiesta GET a una pagina feed: stato, Location, corpo (UTF-8) e secondi.
function Invoke-Feed([string]$page, [string]$id, [string]$pwd, [string]$extra = '') {
    $thr = [int](Get-Scalar 'SELECT VARIABLE_VALUE AS ksval FROM performance_schema.global_status WHERE VARIABLE_NAME=''Threads_connected'';')
    if (-not $script:inReset -and $thr -gt 20) { Reset-App }
    $q = 'id=' + $id + '&pwd=' + [Uri]::EscapeDataString($pwd) + $extra
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.txt')
    $a = @('--noproxy', '*', '-s', '--max-time', '300', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}|%{time_total}', ($base + '/' + $page + '?' + $q))
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 3 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $h = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $loc = ''; $m = [regex]::Match($h, '(?im)^Location:\s*(\S+)'); if ($m.Success) { $loc = $m.Groups[1].Value }
    $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, $utf8) } else { '' }
    Remove-Item -LiteralPath $hdr, $out -Force -ErrorAction SilentlyContinue
    $secs = 0.0; [void][double]::TryParse($parts[2], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$secs)
    return @{ Status = [int]$parts[0]; Location = $loc; Body = $body; Seconds = $secs }
}
$script:inReset = $false
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Feed 'export.aspx' '1' 'zz-nonexistent-probe').Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Reset-App {
    $script:inReset = $true
    try { (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date; Start-Sleep -Seconds 6; Wait-Site } finally { $script:inReset = $false }
}
function Deploy-Repo { foreach ($p in $pages) { [IO.File]::WriteAllBytes((Join-Path $SitePath $p), $repoBytes[$p]) }; Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site { foreach ($p in $pages) { [IO.File]::WriteAllBytes((Join-Path $SitePath $p), $origBytes[$p]) }; Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$page, [string]$text) {
    $bom = ($repoBytes[$page].Length -ge 3 -and $repoBytes[$page][0] -eq 0xEF)
    foreach ($p in $pages) { [IO.File]::WriteAllBytes((Join-Path $SitePath $p), $repoBytes[$p]) }
    [IO.File]::WriteAllText((Join-Path $SitePath $page), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site
}

# ---- analisi del corpo ----
function Split-Lines([string]$body) { return ,@($body -split "`r?`n" | Where-Object { $_ -ne '' }) }
# id articolo dalla colonna Link (prima colonna nei formati di prova); csv: colonne separate da ';' con virgolette.
# Divide una riga csv sul ';' fuori dalle virgolette; toglie le virgolette; la riga finisce con ';' (il campo dopo l'ultimo ';' non esiste).
function Split-Csv([string]$line) {
    $res = New-Object Collections.Generic.List[string]; $cur = New-Object Text.StringBuilder; $inq = $false
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq [char]34) { $inq = -not $inq } elseif ($ch -eq ';' -and -not $inq) { $res.Add($cur.ToString()); [void]$cur.Clear() } else { [void]$cur.Append($ch) }
    }
    if ($cur.Length -gt 0) { $res.Add($cur.ToString()) }
    return $res.ToArray()
}
function Get-FeedRows([string]$body, [bool]$csv) {
    $lines = Split-Lines $body
    # Un record comincia con il link; le righe che non cominciano con un link sono a-capo isolati dentro una descrizione (TrasformaTestoXHtml non converte un LF solo).
    $recs = New-Object Collections.Generic.List[string]
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^"?https?://') { $recs.Add($lines[$i]) } elseif ($recs.Count -gt 0) { $recs[$recs.Count - 1] += "`n" + $lines[$i] }
    }
    $rows = New-Object Collections.Generic.List[object]
    foreach ($l in $recs) {
        [string[]]$cols = if ($csv) { Split-Csv $l } else { $l.Split('|') }
        $m = [regex]::Match($cols[0], 'articolo\.aspx\?id=([0-9]+)')
        $rows.Add(@{ Id = $(if ($m.Success) { $m.Groups[1].Value } else { '' }); Cols = $cols; Line = $l })
    }
    return ,$rows.ToArray()
}
function Num([string]$s) { if ($s -eq '' -or $s -eq 'NULL') { return [decimal]0 }; return [decimal]::Parse($s, [Globalization.CultureInfo]::InvariantCulture) }
function Round2([string]$x) { return [Math]::Round([decimal]::Parse($x, [Globalization.CultureInfo]::InvariantCulture), 2, [MidpointRounding]::AwayFromZero).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture) }
# Prezzo atteso per 1 pezzo, calcolato qui con la regola del sito (articolo.aspx.vb, BuildProductSql) sulle righe della vista: NON usa il codice delle pagine.
function Expected-Price($rowsOfArticle, [int]$ivaTipo) {
    $valid = @($rowsOfArticle | Where-Object {
        $q = Num $_.OfferteQntMinima; $m = [int](Num $_.OfferteMultipli)
        $_.InOfferta -eq '1' -and ((($q -gt 0) -and ($q -le 1)) -or (($q -le 0) -and ($m -eq 1)))
    })
    $col = if ($ivaTipo -eq 1) { 'PrezzoPromo' } else { 'PrezzoPromoIvato' }
    if ($valid.Count -gt 0) {
        $min = $valid | ForEach-Object { Num $_[$col] } | Sort-Object | Select-Object -First 1
        return (Round2 $min.ToString([Globalization.CultureInfo]::InvariantCulture))
    }
    $lc = if ($ivaTipo -eq 1) { 'Prezzo' } else { 'PrezzoIvato' }
    return (Round2 $rowsOfArticle[0][$lc])
}

$exit = 0; $created = $false; $offCreated = $false
$siteMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLabSite18843'); $siteHeld = $false
try {
    try { $siteHeld = $siteMutex.WaitOne(1800000) } catch [System.Threading.AbandonedMutexException] { $siteHeld = $true }
    if (-not $siteHeld) { throw 'LAB_SITE_BUSY' }

    # --- Identita del LAB e righe libere ---
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    $busy = Get-Scalar 'SELECT COUNT(*) AS ksval FROM `export` WHERE ID BETWEEN 9201 AND 9224;'
    if ($busy -ne '0') { throw 'FIXTURE_IDS_NOT_FREE' }

    # Articoli per i filtri puntuali: i primi due esportabili (query di sola lettura).
    $expIdsPre = @(Get-Rows 'SELECT DISTINCT id AS ksid FROM vsuperarticoli WHERE export=1 AND nlistino=10 ORDER BY id LIMIT 2;' | ForEach-Object { $_['ksid'] })
    if ($expIdsPre.Count -ne 2) { throw 'NO_FILTER_ARTICLES' }
    $heavyId = Get-Scalar 'SELECT id AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND Peso>50 ORDER BY id LIMIT 1;'
    if ($heavyId -eq '') { throw 'NO_HEAVY_ARTICLE' }
    # Dati per i filtri di selezione: una marca con articoli disponibili e non, una coppia settore+categoria, un articolo di un'altra marca.
    $brandX = Get-Scalar 'SELECT MarcheId AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND MarcheId>0 GROUP BY MarcheId HAVING COUNT(DISTINCT id) BETWEEN 3 AND 150 AND COUNT(DISTINCT CASE WHEN Giacenza>=1 THEN id END)>=1 AND COUNT(DISTINCT CASE WHEN Giacenza>=1 THEN NULL ELSE id END)>=1 ORDER BY MarcheId LIMIT 1;'
    $sc = @(Get-Rows 'SELECT SettoriId AS ks, CategorieId AS kc FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND SettoriId>-1 AND CategorieId>-1 GROUP BY SettoriId, CategorieId HAVING COUNT(DISTINCT id) BETWEEN 3 AND 150 ORDER BY SettoriId, CategorieId LIMIT 1;')
    if ($brandX -eq '' -or $sc.Count -ne 1) { throw 'NO_FILTER_DATA' }
    $setX = $sc[0]['ks']; $catX = $sc[0]['kc']
    $artOther = Get-Scalar ('SELECT MIN(id) AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND MarcheId<>' + $brandX + ';')
    function Get-IdList([string]$where) { return ((@(Get-Rows ('SELECT DISTINCT id AS ksid FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND ' + $where + ' ORDER BY id;') | ForEach-Object { $_['ksid'] }) | Sort-Object { [int]$_ }) -join ',') }
    $listMarca = Get-IdList ('MarcheId=' + $brandX)
    $listSetCat = Get-IdList ('SettoriId=' + $setX + ' AND CategorieId=' + $catX)
    $listUnion = Get-IdList ('(MarcheId=' + $brandX + ' OR id=' + $artOther + ')')
    $listMarcaGiac = Get-IdList ('MarcheId=' + $brandX + ' AND Giacenza>=1')
    $listAllGiac = Get-IdList 'Giacenza>=1'
    $listSingle = [string]$artOther
    # --- Righe sintetiche (password scelte qui) ---
    $pw = 'KsFeedRep-1'
    $fmtPrice = '#Link#|#Prezzo#|#UrlImgBig#'
    $fmtGoogle = '#Link#|#Prezzo#'
    $fmtDesc = '#Link#|#DescrizioneLungaHtml#|#DescrizioneHtml#'
    $fmtPerf = '#Link#|#Prezzo#|#Prezzo2#|#CostoSpedizioneProdo#'
    $ins = New-Object Text.StringBuilder
    function Add-Row([int]$id, [string]$tipo, [string]$fmt, [int]$ivaTipo, [int]$abil, [int]$vet, [int]$lst2, [string]$giac = '-1') {
        [void]$ins.AppendLine('INSERT INTO `export` (ID, Descrizione, `Password`, FormatString, NListino, IvaTipo, Giacenza, SpeseSpedizione, GiorniSpedizione, Azienda, Tipo, IdVettore, NListino2, Tutto_in_minuscolo, Google, Amazon, NoVettoreSuGratis, Abilitato) VALUES (' + $id + ', ''KSFEEDREPAIR' + $id + ''', ' + (Sql-Text $pw) + ', ' + (Sql-Text $fmt) + ', 10, ' + $ivaTipo + ', ' + $giac + ', 0, 1, ''www.taikun.it'', ''' + $tipo + ''', ' + $vet + ', ' + $lst2 + ', 0, 0, 0, 0, ' + $abil + ');')
    }
    Add-Row 9201 'txt' $fmtPrice 2 1 0 0
    Add-Row 9202 'txt' $fmtPrice 1 1 0 0
    Add-Row 9203 'txt' $fmtGoogle 2 1 0 0
    Add-Row 9204 'csv' $fmtPrice 2 1 0 0
    Add-Row 9205 'csv' $fmtPrice 1 1 0 0
    Add-Row 9206 'txt' $fmtPrice 2 0 0 0
    Add-Row 9207 'csv' $fmtPrice 2 0 0 0
    Add-Row 9208 'txt' $fmtDesc 2 1 0 0
    Add-Row 9209 'txt' $fmtPerf 1 1 3 8
    Add-Row 9210 'csv' $fmtDesc 2 1 0 0
    Add-Row 9211 'csv' $fmtPerf 1 1 3 8
    Add-Row 9212 'txt' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9213 'csv' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9214 'csv' '#Link#|#id#' 2 1 0 0
    Add-Row 9215 'txt' '#Link#|#CostoSpedizioneProdo#' 1 1 17 0
    Add-Row 9216 'csv' '#Link#|#CostoSpedizioneProdo#' 1 1 17 0
    Add-Row 9217 'csv' '#Link#|#CostoSpedizioneProdo#' 2 1 5 0
    Add-Row 9218 'txt' '#Link#|#CostoSpedizioneProdo#' 2 1 5 0
    Add-Row 9219 'txt' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9220 'txt' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9221 'csv' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9222 'txt' '#Link#|#Prezzo#' 2 1 0 0
    Add-Row 9223 'csv' '#Link#|#Prezzo#' 2 1 0 0 '1'
    Add-Row 9224 'txt' '#Link#|#Prezzo#' 2 1 0 0 '1'
    function Add-Filter([int]$eid, [string]$marca, [string]$sett, [string]$cat, [string]$art) {
        [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (' + $eid + ', ' + $marca + ', ' + $sett + ', ' + $cat + ', -1, -1, -1, ' + $art + ');')
    }
    # 9219: una sola riga "articolo"; 9220: una riga marca; 9221: riga settore+categoria; 9222: riga articolo PRIMA + riga marca; 9223: riga marca con giacenza minima 1; 9224: nessun filtro con giacenza minima 1.
    Add-Filter 9219 '-1' '-1' '-1' $artOther
    Add-Filter 9220 $brandX '-1' '-1' '-1'
    Add-Filter 9221 '-1' $setX $catX '-1'
    Add-Filter 9222 '-1' '-1' '-1' $artOther
    Add-Filter 9222 $brandX '-1' '-1' '-1'
    Add-Filter 9223 $brandX '-1' '-1' '-1'
    # Filtri dei feed 9212 (txt) e 9213 (csv): DUE righe "solo articolo" (tutte le classificazioni a -1); la PRIMA non deve essere ignorata.
    $artA = $expIdsPre[0]; $artB = $expIdsPre[1]
    foreach ($fid in @(9212, 9213)) {
        foreach ($a in @($artA, $artB)) { [void]$ins.AppendLine('INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (' + $fid + ', -1, -1, -1, -1, -1, -1, ' + $a + ');') }
    }
    $null = Invoke-Sql $ins.ToString() -Write
    $created = $true
    $made = Get-Scalar 'SELECT COUNT(*) AS ksval FROM `export` WHERE ID BETWEEN 9201 AND 9224;'
    Check ($made -eq '24') 'fixture create sul LAB (24 righe in export)'
    # Offerte sintetiche su un articolo senza offerte: valida per 1 pezzo (10%), scaduta ieri (50%), scaglione da 3 (30%), valida per 1 pezzo (20%, la piu bassa). Prezzo atteso = listino - 20%.
    $offBusy = Get-Scalar 'SELECT COUNT(*) AS ksval FROM voffertearticoli WHERE OfferteID=9990001;'
    if ($offBusy -ne '0') { throw 'SYNTH_OFFER_ID_NOT_FREE' }
    $synId = Get-Scalar 'SELECT id AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 GROUP BY id HAVING COUNT(*)=1 AND MAX(offerteid IS NULL)=1 AND MAX(Prezzo)>1 ORDER BY id DESC LIMIT 1;'
    if ($synId -eq '') { throw 'NO_SYNTH_ARTICLE' }
    $offIns = New-Object Text.StringBuilder
    $offDef = @(@(9990001, 'CURDATE() - INTERVAL 1 DAY', 'CURDATE() + INTERVAL 30 DAY', 1, 10), @(9990002, 'CURDATE() - INTERVAL 30 DAY', 'CURDATE() - INTERVAL 1 DAY', 1, 50), @(9990003, 'CURDATE() - INTERVAL 1 DAY', 'CURDATE() + INTERVAL 30 DAY', 3, 30), @(9990004, 'CURDATE() - INTERVAL 1 DAY', 'CURDATE() + INTERVAL 30 DAY', 1, 20))
    foreach ($o in $offDef) { [void]$offIns.AppendLine('INSERT INTO voffertearticoli (id, OfferteID, OfferteDettagliId, OfferteDescrizione, OfferteDataInizio, OfferteDataFine, OfferteDaListino, OfferteAListino, OfferteQntMinima, OfferteMultipli, OffertePrezzo, OfferteSconto) VALUES (' + $synId + ', 9990001, ' + $o[0] + ', ''KSFEEDREPAIR'', ' + $o[1] + ', ' + $o[2] + ', 0, 99, ' + $o[3] + ', 0, 0, ' + $o[4] + ');') }
    $null = Invoke-Sql $offIns.ToString() -Write
    $offCreated = $true

    # --- Oracolo indipendente dalle pagine (sola lettura) ---
    $expIds = @(Get-Rows 'SELECT DISTINCT id AS ksid FROM vsuperarticoli WHERE export=1 AND nlistino=10 ORDER BY id;' | ForEach-Object { $_['ksid'] })
    $nExp = $expIds.Count
    Check ($nExp -gt 4000) ('oracolo: articoli esportabili letti dal LAB (' + $nExp + ')')
    $expSet = New-Object Collections.Generic.HashSet[string]; foreach ($x in $expIds) { [void]$expSet.Add($x) }

    # Articoli campione per i tipi (una query per tipo). Giacenza del feed = -1: nessun filtro sulla giacenza, come per i feed reali.
    function Pick([string]$having) { return (Get-Scalar ('SELECT id AS ksval FROM vsuperarticoli WHERE export=1 AND nlistino=10 GROUP BY id HAVING ' + $having + ' ORDER BY id LIMIT 1;')) }
    $sample = [ordered]@{
        'valida1'   = (Pick 'COUNT(*)=1 AND MAX(InOfferta=1 AND OfferteQntMinima=1)=1')
        'scaduta'   = (Pick 'COUNT(*)=1 AND MAX(InOfferta=0 AND offerteid IS NOT NULL)=1')
        'scaglioni' = (Pick 'SUM(InOfferta=1 AND OfferteQntMinima>1)>=1')
        'multipli'  = (Pick 'SUM(InOfferta=1 AND OfferteQntMinima<=0 AND OfferteMultipli>1)=COUNT(*)')
        'nessuna'   = (Pick 'COUNT(*)=1 AND MAX(offerteid IS NULL)=1')
        'doppie'    = (Pick 'SUM(InOfferta=1 AND OfferteQntMinima=1)>=2')
        'sintetica' = $synId
        'mista'     = (Pick 'SUM(InOfferta=1 AND OfferteQntMinima=1)>=1 AND SUM(InOfferta=0 AND offerteid IS NOT NULL)>=1')
    }
    foreach ($k in $sample.Keys) { if ([string]$sample[$k] -eq '') { Write-Host ('  nota: nessun articolo campione del tipo ' + $k + ' (oggi sul LAB)') } }
    $expPrice = @{}
    foreach ($k in $sample.Keys) {
        if ([string]$sample[$k] -eq '') { continue }
        $rr = @(Get-Rows ('SELECT id, Prezzo, PrezzoIvato, InOfferta, OfferteQntMinima, OfferteMultipli, PrezzoPromo, PrezzoPromoIvato FROM vsuperarticoli WHERE export=1 AND nlistino=10 AND id=' + $sample[$k] + ';'))
        $expPrice[$k] = @{ 1 = (Expected-Price $rr 1); 2 = (Expected-Price $rr 2) }
    }
    # Parita del listino: il prezzo di listino che la vista espone (Prezzo e PrezzoIvato per il listino del feed) e quello di articoli_listini, per tutti i listini dei feed.
    $parity = Get-Scalar 'SELECT COUNT(*) AS ksval FROM vsuperarticoli v LEFT JOIN articoli_listini l ON l.ArticoliId=v.id AND l.NListino=v.nlistino WHERE v.export=1 AND v.nlistino IN (1,5,6,7,8,9,10,11) AND (l.ArticoliId IS NULL OR NOT (v.Prezzo <=> l.Prezzo) OR NOT (v.PrezzoIvato <=> l.PrezzoIvato));'
    Check ($parity -eq '0') ('oracolo: Prezzo e PrezzoIvato della vista = articoli_listini per i listini dei feed (differenze: ' + $parity + ')')
    # Senza promozione valida per 1 pezzo il prezzo atteso e proprio quello di articoli_listini (stesso listino, IVA inclusa ed esclusa).
    # 'scaglioni' non e qui: quell'articolo ha anche una promozione valida per 1 pezzo, che deve prevalere sul listino (e sui prezzi a scaglioni).
    foreach ($k in @('scaduta', 'multipli', 'nessuna')) {
        if ([string]$sample[$k] -eq '') { continue }
        $ll = @(Get-Rows ('SELECT Prezzo, PrezzoIvato FROM articoli_listini WHERE NListino=10 AND ArticoliId=' + $sample[$k] + ';'))
        Check ($ll.Count -eq 1 -and (Round2 $ll[0]['Prezzo']) -ceq $expPrice[$k][1] -and (Round2 $ll[0]['PrezzoIvato']) -ceq $expPrice[$k][2]) ('oracolo: articolo ' + $sample[$k] + ' (' + $k + ') senza promo per 1 pezzo = listino di articoli_listini')
    }
    Check ($sample['valida1'] -ne '' -and $sample['scaglioni'] -ne '' -and $sample['multipli'] -ne '' -and $sample['nessuna'] -ne '') 'oracolo: campioni valida1, scaglioni, multipli e nessuna presenti sul LAB'

    if (-not $Baseline) { Deploy-Repo } else { Deploy-Repo }

    function Parse-Price([string]$s, [bool]$csv) { if ($csv) { return $s.Replace(',', '.') } else { return $s } }

    function Run-Cases {
        # F1: txt completo e senza ripetizioni, stesso insieme di articoli dell'oracolo.
        $r = Invoke-Feed 'export.aspx' '9201' $pw
        $rows = Get-FeedRows $r.Body $false
        Check ($r.Status -eq 200) ('F1 txt risponde 200 (visto ' + $r.Status + ')')
        Check ($rows.Count -eq $nExp) ('F1 txt: una riga per articolo esportabile (attese ' + $nExp + ', viste ' + $rows.Count + ')')
        $ids = @($rows | ForEach-Object { $_.Id })
        $distinct = @($ids | Sort-Object -Unique).Count
        Check ($distinct -eq $rows.Count -and $rows.Count -gt 0) 'F1 txt: nessun articolo ripetuto'
        $inOracle = @($ids | Where-Object { $expSet.Contains($_) }).Count
        Check ($inOracle -eq $rows.Count -and $distinct -eq $nExp) 'F1 txt: stessi articoli dell oracolo (nessuno perso, nessuno in piu)'
        Check ($r.Body.StartsWith('Link|Prezzo|UrlImgBig')) 'F1 txt: intestazione dal formato'
        Check ($r.Body -notmatch 'http://') 'F1 txt: nessun http:// (link e immagini sono https)'
        Check (@($rows | Where-Object { $_.Cols[0] -notmatch '^https://www\.taikun\.it/articolo\.aspx\?id=' }).Count -eq 0) 'F1 txt: ogni link e https://<dominio>/articolo.aspx'
        $withImg = @($rows | Where-Object { $_.Cols.Count -gt 2 -and $_.Cols[2] -ne '' })
        # Il LAB non ha le foto dei prodotti (cartella articoli vuota): nessuna riga ha un URL immagine; la costruzione https di ExportProductImageUrl e coperta dal controllo S2 sul sorgente.
        Check (@($withImg | Where-Object { $_.Cols[2] -notmatch '^https://' }).Count -eq 0) ('F1 txt: ogni immagine presente e https (' + $withImg.Count + ' con immagine sul LAB)')
        $price2 = @{}; foreach ($x in $rows) { $price2[$x.Id] = $x.Cols[1] }
        $r1 = Invoke-Feed 'export.aspx' '9202' $pw
        $rows1 = Get-FeedRows $r1.Body $false
        $price1 = @{}; foreach ($x in $rows1) { $price1[$x.Id] = $x.Cols[1] }

        # F2: csv completo (prima: 302), stessi controlli.
        $c = Invoke-Feed 'export_csv.aspx' '9204' $pw
        $crows = Get-FeedRows $c.Body $true
        Check ($c.Status -eq 200 -and $c.Location -eq '') ('F2 csv risponde 200 senza rinvio (visto ' + $c.Status + ' ' + $c.Location + ')')
        Check ($crows.Count -eq $nExp) ('F2 csv: una riga per articolo esportabile (attese ' + $nExp + ', viste ' + $crows.Count + ')')
        $cids = @($crows | ForEach-Object { $_.Id })
        Check (@($cids | Sort-Object -Unique).Count -eq $crows.Count -and $crows.Count -gt 0) 'F2 csv: nessun articolo ripetuto'
        Check (@($cids | Where-Object { $expSet.Contains($_) }).Count -eq $crows.Count) 'F2 csv: stessi articoli dell oracolo'
        Check ($c.Body -notmatch 'http://') 'F2 csv: nessun http://'
        $cprice2 = @{}; foreach ($x in $crows) { $cprice2[$x.Id] = (Parse-Price $x.Cols[1] $true) }
        $c1 = Invoke-Feed 'export_csv.aspx' '9205' $pw
        $cprice1 = @{}; foreach ($x in (Get-FeedRows $c1.Body $true)) { $cprice1[$x.Id] = (Parse-Price $x.Cols[1] $true) }

        # F3: ramo Google (tabulazioni, completo).
        $g = Invoke-Feed 'export.aspx' '9203' $pw '&google=1'
        $glines = Split-Lines $g.Body
        $grecs = @($glines | Select-Object -Skip 1 | Where-Object { $_ -match '^https?://' })
        Check ($g.Status -eq 200 -and $grecs.Count -eq $nExp) ('F3 google: intestazione + una riga per articolo (viste ' + $grecs.Count + ')')
        Check ($glines.Count -gt 1 -and $glines[0].Contains("`t") -and $glines[1].Contains("`t")) 'F3 google: colonne separate da tabulazione'

        # F4: feed spento in entrambe le pagine; chi sbaglia la password non scopre lo stato.
        $d1 = Invoke-Feed 'export.aspx' '9206' $pw
        $d2 = Invoke-Feed 'export_csv.aspx' '9207' $pw
        Check ($d1.Status -eq 200 -and $d1.Body.Trim() -ceq 'Feed non disponibile') 'F4 txt spento: solo "Feed non disponibile", nessun dato'
        Check ($d2.Status -eq 200 -and $d2.Body.Trim() -ceq 'Feed non disponibile') 'F4 csv spento: solo "Feed non disponibile", nessun dato'
        $d3 = Invoke-Feed 'export.aspx' '9206' ($pw + 'x')
        $d4 = Invoke-Feed 'export_csv.aspx' '9207' ($pw + 'x')
        Check ($d3.Body.Trim() -ceq 'ID o Password errati.' -and $d4.Body.Trim() -ceq 'ID o Password errati.') 'F4 password sbagliata su feed spento: rifiuto normale (stato non svelato)'
        $d5 = Invoke-Feed 'export.aspx' '9201' ($pw + 'x'); $d6 = Invoke-Feed 'export_csv.aspx' '9204' ($pw + 'x')
        Check ($d5.Body.Trim() -ceq 'ID o Password errati.' -and $d6.Body.Trim() -ceq 'ID o Password errati.') 'F4 password sbagliata: rifiuto invariato (nessun dato, nessun errore)'

        # F5: #DescrizioneLungaHtml# = #DescrizioneHtml#.
        foreach ($pair in @(@('export.aspx', '9208', $false), @('export_csv.aspx', '9210', $true))) {
            $dr = Invoke-Feed $pair[0] $pair[1] $pw
            $drows = Get-FeedRows $dr.Body $pair[2]
            Check ($dr.Status -eq 200 -and $drows.Count -eq $nExp) ('F5 ' + $pair[0] + ': feed completo con #DescrizioneLungaHtml# (' + $drows.Count + ')')
            $body = ((Split-Lines $dr.Body) | Select-Object -Skip 1) -join "`n"
            Check ($body -notmatch '#DescrizioneLungaHtml#') ('F5 ' + $pair[0] + ': nessun testo letterale #DescrizioneLungaHtml# nelle righe')
            $diff = @($drows | Where-Object { $_.Cols.Count -lt 3 -or $_.Cols[1] -cne $_.Cols[2] }).Count
            Check ($diff -eq 0 -and $drows.Count -gt 0) ('F5 ' + $pair[0] + ': la colonna DescrizioneLungaHtml e uguale a DescrizioneHtml in ogni riga (diverse: ' + $diff + ')')
            Check (@($drows | Where-Object { $_.Cols.Count -ge 2 -and $_.Cols[1] -match '&lt;br' }).Count -gt 0) ('F5 ' + $pair[0] + ': il testo HTML e presente (codificato come per #DescrizioneHtml#)')
        }

        # F7: filtri puntuali (due righe "solo articolo"): esattamente quei due articoli, anche con la riga puntuale per PRIMA.
        foreach ($pair in @(@('export.aspx', '9212', $false), @('export_csv.aspx', '9213', $true))) {
            $fr = Invoke-Feed $pair[0] $pair[1] $pw
            $frows = Get-FeedRows $fr.Body $pair[2]
            $fids = @($frows | ForEach-Object { $_.Id } | Sort-Object)
            $want = @($artA, $artB | Sort-Object)
            Check ($fr.Status -eq 200 -and $fids.Count -eq 2 -and $fids[0] -eq $want[0] -and $fids[1] -eq $want[1]) ('F7 ' + $pair[0] + ': due righe filtro solo-articolo = esattamente quei due articoli (visti ' + $fids.Count + ')')
        }
        # F11: filtri di selezione (righe in OR fra loro; dentro una riga le colonne sono in AND; una riga con ArticoliId seleziona quel solo articolo), da soli e con la giacenza minima.
        $fcases = @(
            @('export.aspx', '9219', $false, $listSingle, 'una riga articolo (prima e unica) = solo quell articolo'),
            @('export.aspx', '9220', $false, $listMarca, 'riga marca = tutti gli articoli della marca'),
            @('export_csv.aspx', '9221', $true, $listSetCat, 'riga settore+categoria (AND)'),
            @('export.aspx', '9222', $false, $listUnion, 'righe miste (articolo prima + marca) in OR'),
            @('export_csv.aspx', '9223', $true, $listMarcaGiac, 'riga marca con giacenza minima 1 (solo disponibili)'),
            @('export.aspx', '9224', $false, $listAllGiac, 'nessun filtro con giacenza minima 1 (solo disponibili)')
        )
        foreach ($fc in $fcases) {
            $fr = Invoke-Feed $fc[0] $fc[1] $pw
            $frs = Get-FeedRows $fr.Body $fc[2]
            $got = ((@($frs | ForEach-Object { $_.Id }) | Sort-Object { [int]$_ }) -join ',')
            Check ($fr.Status -eq 200 -and $fc[3] -ne '' -and $got -ceq $fc[3]) ('F11 ' + $fc[0] + ': ' + $fc[4] + ' (attesi ' + @($fc[3] -split ',').Count + ', visti ' + @($got -split ',' | Where-Object { $_ -ne '' }).Count + ')')
        }

        # F8: #id# nel csv e sostituito con l'id dell'articolo.
        $ir = Invoke-Feed 'export_csv.aspx' '9214' $pw
        $irows = Get-FeedRows $ir.Body $true
        Check ($irows.Count -eq $nExp -and @($irows | Where-Object { $_.Cols.Count -lt 2 -or $_.Cols[1] -ne $_.Id }).Count -eq 0) 'F8 csv: #id# = id dell articolo in ogni riga'
        # F9: peso oltre l'ultima fascia del vettore (articoli da 65 kg, fasce fino a 50): il feed resta completo, il campo spedizione e vuoto.
        foreach ($pair in @(@('export.aspx', '9215', $false), @('export_csv.aspx', '9216', $true))) {
            $wr = Invoke-Feed $pair[0] $pair[1] $pw
            $wrows = Get-FeedRows $wr.Body $pair[2]
            $heavy = @($wrows | Where-Object { $_.Id -eq $heavyId })
            Check ($wr.Status -eq 200 -and $wrows.Count -eq $nExp) ('F9 ' + $pair[0] + ': feed completo anche con articoli oltre l ultima fascia (' + $wrows.Count + ')')
            Check ($heavy.Count -eq 1 -and ($heavy[0].Cols.Count -lt 2 -or $heavy[0].Cols[1] -eq '')) ('F9 ' + $pair[0] + ': articolo piu pesante dell ultima fascia = costo di spedizione vuoto')
        }

        # F10: costo di spedizione con IVA inclusa (vettore con fascia a decimali): 6,56 + IVA 22% = 8,0032 (Val() lo tagliava a 6 prima dell IVA).
        $expShip = [double]::Parse((Get-Scalar ('SELECT ROUND(c.CostoFisso * (1 + i.valore / 100), 6) AS ksval FROM vettoricosti c JOIN vettori v ON v.id=5 JOIN iva i ON i.id=v.iva WHERE c.VettoriId=5 AND c.PesoMax=(SELECT MIN(PesoMax) FROM vettoricosti WHERE VettoriId=5 AND PesoMax>=(SELECT COALESCE(MAX(Peso),0) FROM vsuperarticoli WHERE nlistino=10 AND id=' + $artA + '));')), [Globalization.CultureInfo]::InvariantCulture)
        foreach ($pair in @(@('export.aspx', '9218', $false), @('export_csv.aspx', '9217', $true))) {
            $sr = Invoke-Feed $pair[0] $pair[1] $pw
            $srows = Get-FeedRows $sr.Body $pair[2]
            $mine = @($srows | Where-Object { $_.Id -eq $artA })
            $val = -1.0
            if ($mine.Count -eq 1 -and $mine[0].Cols.Count -ge 2) { [void][double]::TryParse(($mine[0].Cols[1] -replace ',', '.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$val) }
            Check ($sr.Status -eq 200 -and $srows.Count -eq $nExp -and [Math]::Abs($val - $expShip) -lt 0.001) ('F10 ' + $pair[0] + ': spedizione con IVA inclusa = ' + $expShip + ' (vista ' + $val + ')')
        }

        # F6: prezzo per i tipi di articolo, IVA inclusa (2) ed esclusa (1), txt e csv.
        foreach ($k in $sample.Keys) {
            $id = [string]$sample[$k]; if ($id -eq '') { continue }
            foreach ($iva in @(2, 1)) {
                $tx = if ($iva -eq 2) { $price2 } else { $price1 }
                $cs = if ($iva -eq 2) { $cprice2 } else { $cprice1 }
                $e = $expPrice[$k][$iva]
                Check ($tx.ContainsKey($id) -and $tx[$id] -ceq $e) ('F6 prezzo ' + $k + ' articolo ' + $id + ' IVA tipo ' + $iva + ' txt = ' + $e + ' (visto ' + $(if ($tx.ContainsKey($id)) { $tx[$id] } else { 'assente' }) + ')')
                Check ($cs.ContainsKey($id) -and $cs[$id] -ceq $e) ('F6 prezzo ' + $k + ' articolo ' + $id + ' IVA tipo ' + $iva + ' csv = ' + $e + ' (visto ' + $(if ($cs.ContainsKey($id)) { $cs[$id] } else { 'assente' }) + ')')
            }
        }
    }

    function Get-Opens {
        $x = @(Get-Rows 'SELECT VARIABLE_VALUE AS kc FROM performance_schema.global_status WHERE VARIABLE_NAME=''Connections'';')
        return @{ C = [int]$x[0]['kc'] }
    }
    function Run-Perf {
        # P1: il feed con #Prezzo2# e #CostoSpedizioneProdo# e completo e usa un numero di connessioni che NON dipende dalle righe.
        foreach ($pair in @(@('export.aspx', '9209', $false), @('export_csv.aspx', '9211', $true))) {
            $m0 = Get-Opens
            $r = Invoke-Feed $pair[0] $pair[1] $pw
            $m1 = Get-Opens
            $rows = Get-FeedRows $r.Body $pair[2]
            # Connessioni fisiche nuove della richiesta. Con il pool del LAB un Open per riga e invisibile (riuso): per misurarlo si esegue il test con -NoPool.
            # Nel delta ci sono la mia lettura di Threads_connected (1, dentro Invoke-Feed) e la lettura finale (1): si tolgono.
            $used = $m1.C - $m0.C - 2
            Write-Host ('  misura ' + $pair[0] + ': ' + $rows.Count + ' righe, ' + [Math]::Round($r.Seconds, 2) + ' s, connessioni fisiche aperte ' + $used + $(if ($NoPool) { ' (senza pool)' } else { ' (con pool)' }))
            Check ($r.Status -eq 200 -and $rows.Count -eq $nExp) ('P1 ' + $pair[0] + ': feed con secondo prezzo e spedizione completo (' + $rows.Count + ' righe)')
            Check ($used -le 8) ('P1 ' + $pair[0] + ': aperture di connessione della richiesta <= 8, indipendenti dalle righe (viste ' + $used + ')')
            Check (@($rows | Where-Object { $_.Cols.Count -lt 4 }).Count -eq 0) ('P1 ' + $pair[0] + ': tutte le righe hanno 4 colonne')
        }
    }

    if (-not $OnlyPerf) { Run-Cases }
    Run-Perf

    # --- Sorgente (controlli che la prova HTTP del LAB non puo fare: il LAB non ha foto prodotto) ---
    $srcTxt = Get-Text $repoBytes['export.aspx.vb']; $srcCsv = Get-Text $repoBytes['export_csv.aspx.vb']
    function Run-Source([string]$txt, [string]$csv) {
        foreach ($pair in @(@('export.aspx.vb', $txt), @('export_csv.aspx.vb', $csv))) {
            $loopOk = $true
            $m = [regex]::Match($pair[1], '(?s)While\s+dr\.Read\(\)(.*?)End While')
            if ($m.Success -and $m.Groups[1].Value -match 'Response\.End') { $loopOk = $false }
            Check $loopOk ('S1 ' + $pair[0] + ': nessun Response.End dentro il ciclo delle righe')
            Check ($pair[1] -notmatch '"http://"\s*&') ('S2 ' + $pair[0] + ': nessuna costruzione di URL http:// (link, immagini)')
        }
    }
    if (-not $Baseline) { Run-Source $srcTxt $srcCsv }

    if ($e2e.Count -gt 0) { $exit = 1 }
    if (-not $SkipMutants -and -not $Baseline -and $exit -eq 0) {
        # Ogni mutante: pagina, modifiche (da -> a, una riga di sorgente ciascuna) e se si misura solo il costo in connessioni.
        $fl = '" and ( ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (" & FiltroArticolo(dr2, cmd, idxFiltro) & "))"'
        $flM = '" and ( ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (1=1))"'
        $promo = 'promoPerUnPezzo = (qMin > 0 AndAlso qMin <= 1) OrElse (qMin <= 0 AndAlso multipli = 1)'
        $pT = 'export.aspx.vb'; $pC = 'export_csv.aspx.vb'
        $mutants = [ordered]@{
            'M01_TXT_RESPONSE_END_IN_LOOP' = @{ Page = $pT; Edits = @(, @('Response.Write(strLine + Environment.NewLine)', 'Response.Write(strLine + Environment.NewLine) : Response.End()')) }
            'M02_CSV_RESPONSE_END_IN_LOOP' = @{ Page = $pC; Edits = @(, @('Response.Write(strLine & ";" & Environment.NewLine)', 'Response.Write(strLine & ";" & Environment.NewLine) : Response.End()')) }
            'M03_CSV_CASE_SENSITIVE'       = @{ Page = $pC; Edits = @(, @('New Dictionary(Of String, Object)(StringComparer.OrdinalIgnoreCase)', 'New Dictionary(Of String, Object)()')) }
            'M04_CSV_CMD_WITHOUT_CONN'     = @{ Page = $pC; Edits = @(, @('        cmd.Connection = conn', '        cmd.CommandTimeout = 30')) }
            'M05_TXT_ABILITATO_IGNORED'    = @{ Page = $pT; Edits = @(, @('ElseIf IsDBNull(dr.Item("Abilitato")) OrElse Convert.ToInt32(dr.Item("Abilitato")) <> 1 Then', 'ElseIf False Then')) }
            'M06_CSV_ABILITATO_IGNORED'    = @{ Page = $pC; Edits = @(, @('ElseIf IsDBNull(drExport(0)("Abilitato")) OrElse Convert.ToInt32(drExport(0)("Abilitato")) <> 1 Then', 'ElseIf False Then')) }
            'M07_TXT_HTTP_LINK'            = @{ Page = $pT; Edits = @(, @('Link = "https://" & Dominio', 'Link = "http://" & Dominio')) }
            'M08_CSV_HTTP_LINK'            = @{ Page = $pC; Edits = @(, @('Link = "https://" & Dominio', 'Link = "http://" & Dominio')) }
            'M09_TXT_HTTP_IMAGE'           = @{ Page = $pT; Edits = @(, @('Return "https://" & dominio.Trim()', 'Return "http://" & dominio.Trim()')) }
            'M10_CSV_HTTP_IMAGE'           = @{ Page = $pC; Edits = @(, @('Return "https://" & dominio.Trim()', 'Return "http://" & dominio.Trim()')) }
            'M11_TXT_PRICE_ALWAYS_LIST'    = @{ Page = $pT; Edits = @(, @($promo, 'promoPerUnPezzo = False')) }
            'M12_CSV_PRICE_ALWAYS_LIST'    = @{ Page = $pC; Edits = @(, @($promo, 'promoPerUnPezzo = False')) }
            'M13_TXT_TIER_AS_PROMO'        = @{ Page = $pT; Edits = @(, @($promo, 'promoPerUnPezzo = True')) }
            'M14_CSV_TIER_AS_PROMO'        = @{ Page = $pC; Edits = @(, @($promo, 'promoPerUnPezzo = True')) }
            'M15_TXT_DUPLICATES_KEPT'      = @{ Page = $pT; Edits = @(, @('If ArtID = ultimoArtId Then Continue While', 'If False Then Continue While')) }
            'M16_CSV_DUPLICATES_KEPT'      = @{ Page = $pC; Edits = @(, @('If ArtID = ultimoArtId Then Continue While', 'If False Then Continue While')) }
            'M17_TXT_BEST_ROW_NOT_FIRST'   = @{ Page = $pT; Edits = @(, @('id, " & SqlPromoPerUnPezzo & " desc, (case when', 'id, 1 desc, (case when')) }
            'M18_TXT_NO_LOWEST_PRICE'      = @{ Page = $pT; Edits = @(, @('(case when " & SqlPromoPerUnPezzo & " then PrezzoPromoIvato end), coalesce', '0, coalesce')) }
            'M19_CSV_BEST_ROW_NOT_FIRST'   = @{ Page = $pC; Edits = @(, @('id, " & SqlPromoPerUnPezzo & " desc, (case when', 'id, 1 desc, (case when')) }
            'M20_TXT_ALIAS_DESC_LUNGA_HTML' = @{ Page = $pT; Edits = @(, @('If strLine.Contains("#DescrizioneLungaHtml#") Then', 'If False Then')) }
            'M21_CSV_ALIAS_DESC_LUNGA_HTML' = @{ Page = $pC; Edits = @(, @('If strLine.Contains("#DescrizioneLungaHtml#") Then', 'If False Then')) }
            'M22_TXT_FIRST_FILTER_NO_ARTICLE' = @{ Page = $pT; Edits = @(, @($fl, $flM)) }
            'M23_CSV_FIRST_FILTER_NO_ARTICLE' = @{ Page = $pC; Edits = @(, @($fl, $flM)) }
            'M24_CSV_ID_PLACEHOLDER'       = @{ Page = $pC; Edits = @(, @('strLine = strLine.Replace("#id#", ArtID)', 'strLine = strLine')) }
            'M25_TXT_WEIGHT_GUARD'         = @{ Page = $pT; Edits = @(, @('If dr.Length = 0 Then Return ""', 'If False Then Return ""')) }
            'M26_CSV_WEIGHT_GUARD'         = @{ Page = $pC; Edits = @(, @('If dr.Length = 0 Then Return ""', 'If False Then Return ""')) }
            'M27_CSV_VAL_TRUNCATES_COST'   = @{ Page = $pC; Edits = @(, @('(CDbl(costoFascia) * ((iva_Vettore / 100) + 1))', '(Val(costoFascia) * ((iva_Vettore / 100) + 1))')) }
            'M28_TXT_CONNECTION_PER_ROW'   = @{ Page = $pT; Perf = $true; Edits = @(@('If connAux Is Nothing Then', 'If True Then'), @('If cmdSecondoPrezzo Is Nothing Then', 'If True Then')) }
            'M31_TXT_FILTER_ROWS_AND'      = @{ Page = $pT; Edits = @(, @('" or ((" & FiltroCondizioni', '" and ((" & FiltroCondizioni')) }
            'M32_CSV_FILTER_ROWS_AND'      = @{ Page = $pC; Edits = @(, @('" or ((" & FiltroCondizioni', '" and ((" & FiltroCondizioni')) }
            'M33_TXT_NO_MIN_STOCK'         = @{ Page = $pT; Edits = @(, @('strGiacenza = " and Giacenza >= @gia"', 'strGiacenza = ""')) }
            'M34_CSV_NO_MIN_STOCK'         = @{ Page = $pC; Edits = @(, @('strGiacenza = " and Giacenza >= @gia"', 'strGiacenza = ""')) }
            'M29_CSV_CONNECTION_PER_ROW'   = @{ Page = $pC; Perf = $true; Edits = @(@('If connAux Is Nothing Then', 'If True Then'), @('If cmdSecondoPrezzo Is Nothing Then', 'If True Then')) }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $mu = $mutants[$id]; $total++
            $page = $mu.Page; $src = if ($page -eq 'export.aspx.vb') { $srcTxt } else { $srcCsv }
            $mutated = $src; $missing = $false
            foreach ($ed in $mu.Edits) { if (-not $mutated.Contains($ed[0])) { $missing = $true } else { $mutated = $mutated.Replace($ed[0], $ed[1]) } }
            if ($missing) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            $before = $e2e.Count
            try {
                Set-Mutant $page $mutated
                if ($mu.ContainsKey('Perf')) { Run-Perf } else { Run-Cases; if ($page -eq 'export.aspx.vb') { Run-Source $mutated $srcCsv } else { Run-Source $srcTxt $mutated } }
                $diff = $e2e.Count - $before
                if ($diff -gt 0) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $diff + ' casi diversi)') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
                while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) }
            } catch {
                # una pagina che va in errore e un mutante ucciso, non un fallimento del test
                $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (la prova non e stata completabile: ' + $_.Exception.Message + ')')
                while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) }
            } finally { Deploy-Repo; if ($mu.ContainsKey('Perf')) { Reset-App } }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    if ($offCreated) {
        try { $null = Invoke-Sql 'DELETE FROM voffertearticoli WHERE OfferteID=9990001 AND OfferteDescrizione=''KSFEEDREPAIR'';' -Write } catch { Write-Host ('  ATTENZIONE: pulizia delle offerte sintetiche non riuscita: ' + $_.Exception.Message); $exit = 1 }
    }
    if ($created) {
        try { $null = Invoke-Sql 'DELETE FROM export_filtri WHERE ExportId BETWEEN 9201 AND 9224; DELETE FROM `export` WHERE ID BETWEEN 9201 AND 9224 AND Descrizione LIKE ''KSFEEDREPAIR%'';' -Write } catch { Write-Host ('  ATTENZIONE: pulizia delle righe sintetiche non riuscita: ' + $_.Exception.Message); $exit = 1 }
    }
    if ($siteHeld) { try { $siteMutex.ReleaseMutex() } catch { } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'EXPORT_FEED PASS' } else { Write-Host 'EXPORT_FEED FAIL' }
exit $exit
