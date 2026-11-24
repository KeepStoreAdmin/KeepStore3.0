[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Red, [switch]$Stress, [string]$KeepXls = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CATALOG-DOWNLOAD-1B (XLS). Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843, utente di prova) del download Excel del listino: il file e un vero .xls
# (HSSF) rileggibile, ha i fogli Indice + un foglio per settore + Elenco, ogni articolo compare UNA volta nell'ordine atteso (calcolato da SQL), il prezzo
# e quello del profilo, l'offerta ha nome, vecchio prezzo e validita, la foto e ancorata alla riga del SUO articolo, i nomi dei fogli sono validi e unici,
# gli stili restano sotto il limite, il peso e contenuto; anonimo e POST senza controllo CSRF non ricevono nessun file. Atteso da SQL, non dal codice sotto prova.
# Limite dichiarato: nessun Excel/LibreOffice su questo PC, quindi l'apertura nei programmi destinatari non e provata (solo rilettura con NPOI).
# -Stress: crea una miniatura finta per OGNI articolo (copie dello stesso file nel sito LAB, poi rimosse) e verifica che l'XLS regga piu di 1.024 foto in un foglio:
# una foto per articolo, ognuna sulla propria riga, peso e tempo misurati.
# Mutazioni sulla copia LAB; i byte originali sono rimessi alla fine. -Red non copia i file del repo (mostra il test rosso prima del codice).
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'CATALOG_XLS FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$files = @('listino-catalogo.aspx', 'listino-catalogo.aspx.vb', 'App_Code\KeepStoreCatalogExportSnapshot.vb', 'App_Code\KeepStoreCatalogExportImages.vb',
    'App_Code\KeepStoreCatalogPdfWriter.vb', 'App_Code\KeepStoreCatalogXlsWriter.vb', 'App_Code\KeepStoreCatalogExportFileName.vb','App_Code\StorefrontCanonicalHostPolicy.vb', 'App_Code\KeepStoreAccountTiles.vb')
$repoBytes = @{}; $origBytes = @{}
foreach ($f in $files) {
    $rp = Join-Path $root $f; $sp = Join-Path $SitePath $f
    $repoBytes[$f] = if (Test-Path -LiteralPath $rp) { [IO.File]::ReadAllBytes($rp) } else { $null }
    $origBytes[$f] = if (Test-Path -LiteralPath $sp) { [IO.File]::ReadAllBytes($sp) } else { $null }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$tmp = Join-Path $env:TEMP ('ks-catxls-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')
$jar = Join-Path $tmp 'auth.txt'; $anon = Join-Path $tmp 'anon.txt'
# il file in Bin porta il marchio di provenienza (0x80131515 con Add-Type -Path): si carica dai byte
[void][Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $root 'Bin\NPOI.dll')))

function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 80; $i++) {
        $st = 0; try { $st = (Invoke-Http '/privacy.aspx' (Join-Path $tmp 'wait.txt')).Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Set-SiteFile([string]$f, $bytes) {
    $sp = Join-Path $SitePath $f
    if ($null -eq $bytes) { if (Test-Path -LiteralPath $sp) { Remove-Item -LiteralPath $sp -Force } } else { [IO.File]::WriteAllBytes($sp, $bytes) }
}
function Deploy-Repo { if ($Red) { return }; foreach ($f in $files) { if ($null -ne $repoBytes[$f]) { Set-SiteFile $f $repoBytes[$f] } }; Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site { foreach ($f in $files) { Set-SiteFile $f $origBytes[$f] }; Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$f, [string]$text) { $bom = ($repoBytes[$f].Length -ge 3 -and $repoBytes[$f][0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $f), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

function Get-Form([string]$jarFile) {
    $x = Invoke-Http '/listino-catalogo.aspx' $jarFile
    $fields = New-Object Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($x.Body, '<input[^>]*type="hidden"[^>]*>')) {
        $n = [regex]::Match($m.Value, 'name="([^"]*)"'); $v = [regex]::Match($m.Value, 'value="([^"]*)"')
        if ($n.Success) { $fields.Add($n.Groups[1].Value + '=' + [Uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($(if ($v.Success) { $v.Groups[1].Value } else { '' })))) }
    }
    $btn = [regex]::Match($x.Body, 'name="([^"]*btnXls)"')
    return @{ Status = $x.Status; Fields = $fields; Button = $(if ($btn.Success) { $btn.Groups[1].Value } else { '' }); Body = $x.Body }
}
function Post-Xls([string]$jarFile, $form, [string]$outFile, [switch]$DropViewState) {
    $parts = New-Object Collections.Generic.List[string]
    foreach ($f in $form.Fields) { if ($DropViewState -and $f -like '__VIEWSTATE*') { continue }; $parts.Add($f) }
    $parts.Add([Uri]::EscapeDataString($form.Button) + '=' + [Uri]::EscapeDataString('Scarica Excel'))
    $body = Join-Path $tmp ('post' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($body, ($parts -join '&'), $utf8)
    if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
    $a = @('--noproxy', '*', '-s', '--max-time', '600', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-b', $jarFile, '-c', $jarFile, '-o', $outFile, '-w', '%{http_code}|%{content_type}',
        '-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + '/listino-catalogo.aspx'), '--data', ('@' + $body), ($base + '/listino-catalogo.aspx'))
    $w = ((& curl.exe @a) -join '').Split('|')
    $len = if (Test-Path -LiteralPath $outFile) { (Get-Item -LiteralPath $outFile).Length } else { 0 }
    return @{ Status = [int]$w[0]; Type = $w[1]; Length = $len }
}
function Fmt([string]$dec) { return ([decimal]::Parse($dec, [Globalization.CultureInfo]::InvariantCulture)).ToString('N2', [Globalization.CultureInfo]::GetCultureInfo('it-IT')) }

function Read-Anchors($rec, $acc) {
    if ($rec.GetType().Name -eq 'EscherClientAnchorRecord') { $acc.Add([int]$rec.Row1) }
    if ($null -ne $rec.GetType().GetProperty('ChildRecords')) { foreach ($c in @($rec.ChildRecords)) { Read-Anchors $c $acc } }
}
# Rilettura dell'XLS con NPOI: per ogni foglio righe con collegamento URL alla scheda (= articolo) e ancore delle foto.
function Get-XlsInfo([string]$file) {
    $fs = [IO.File]::OpenRead($file)
    try { $wb = New-Object NPOI.HSSF.UserModel.HSSFWorkbook -ArgumentList $fs } finally { $fs.Close() }
    $info = @{ Sheets = @(); Names = @(); Items = New-Object Collections.Generic.List[object]; ElencoItems = New-Object Collections.Generic.List[object]; DocLinks = 0; Styles = [int]$wb.NumCellStyles; Pictures = 0; Anchors = @{}; Texts = (New-Object Text.StringBuilder); DocTargets = (New-Object 'Collections.Generic.List[string]') }
    $info.Pictures = @($wb.GetAllPictures()).Count
    for ($s = 0; $s -lt $wb.NumberOfSheets; $s++) {
        $sh = $wb.GetSheetAt($s); $name = $wb.GetSheetName($s)
        $info.Names += $name
        $isElenco = ($name -eq 'Elenco')
        for ($r = $sh.FirstRowNum; $r -le $sh.LastRowNum; $r++) {
            $row = $sh.GetRow($r); if ($null -eq $row) { continue }
            for ($c = 0; $c -lt 14; $c++) {
                $cell = $row.GetCell($c); if ($null -eq $cell) { continue }
                $ct = [string]$cell.CellType
                if ($ct -eq 'STRING') { [void]$info.Texts.Append($cell.StringCellValue + ' | ') }
                $hl = $null; try { $hl = $cell.Hyperlink } catch { $hl = $null }
                if ($null -eq $hl) { continue }
                $addr = [string]$hl.Address
                # in lettura NPOI 1.2.3 non distingue il tipo (Unknown): il collegamento interno ha etichetta "place" e indirizzo 'foglio'!A1
                if ([string]$hl.Label -eq 'place' -or $addr -match "^'.*'![A-Z]+[0-9]+$") { if ($name -eq 'Indice') { $info.DocLinks++; [void]$info.DocTargets.Add(($addr -replace "^'(.*)'!.*$", '$1').Replace("''", "'")) }; continue }
                $m = [regex]::Match($addr, 'articolo\.aspx\?id=([0-9]+)$')
                if (-not $m.Success) { continue }
                # riga articolo: id dal collegamento, EAN e prezzi letti dalla riga con intestazioni fisse
                $item = @{ Id = [int]$m.Groups[1].Value; Sheet = $name; Row = $r; Cells = @{} }
                for ($k = 0; $k -lt 14; $k++) { $x = $row.GetCell($k); if ($null -ne $x) { $t = [string]$x.CellType; $item.Cells[$k] = if ($t -eq 'NUMERIC') { [string]$x.NumericCellValue } elseif ($t -eq 'STRING') { $x.StringCellValue } else { '' } } }
                if ($isElenco) { $info.ElencoItems.Add($item) } else { $info.Items.Add($item) }
            }
        }
        # NPOI 1.2.3 non rilegge le forme (Children e vuoto): le ancore delle foto si leggono dai record Escher del foglio
        $pat = $null; try { $pat = ([NPOI.HSSF.UserModel.HSSFSheet]$sh).DrawingPatriarch } catch { $pat = $null }
        if ($null -ne $pat) {
            $agg = $pat.GetType().GetField('boundAggregate', [Reflection.BindingFlags]'NonPublic,Instance').GetValue($pat)
            $rowsFound = New-Object Collections.Generic.List[int]
            foreach ($er in @($agg.EscherRecords)) { Read-Anchors $er $rowsFound }
            if ($rowsFound.Count -gt 0) { $info.Anchors[$name] = $rowsFound }
        }
    }
    $info.Sheets = $info.Names
    return $info
}
function Is-ValidSheetName([string]$n) { return ($n.Length -ge 1 -and $n.Length -le 31 -and $n -notmatch "[\[\]:*?/\\]" -and -not $n.StartsWith("'") -and -not $n.EndsWith("'")) }

$exit = 0
$uid = 0; $lst = 0; $copied = New-Object Collections.Generic.List[string]
try {
    $uid = [int](Get-Scalar "SELECT UtentiId AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $lst = [int](Get-Scalar "SELECT Listino AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $where = "v.NListino = $lst AND COALESCE(a.Abilitato,0) = 1 AND COALESCE(v.Export,0) <> 0"
    $expectedSql = "SELECT x.ArticleId AS ksval FROM (SELECT v.id AS ArticleId, v.Codice, v.Descrizione1, v.SettoriId, v.SettoriDescrizione, v.SettoriOrdINamento, v.CategorieId, v.CategorieDescrizione, v.CategorieOrdiNAmento, v.TipologieId, v.TipologieDescrizione, v.TipologieOrdinamento, v.GruppiId, v.GruppiDEscrizione, v.GruppiOrdinamento, ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY CASE WHEN COALESCE(v.TCid,0)>0 THEN 0 ELSE 1 END, COALESCE(v.TCid,-1), COALESCE(v.ArticoliListiniId,0), COALESCE(v.OfferteDettagliId,0)) AS rk FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where) x WHERE x.rk = 1 ORDER BY (x.SettoriId IS NULL OR x.SettoriId<=0), COALESCE(x.SettoriOrdINamento,0), x.SettoriDescrizione, x.SettoriId, (x.CategorieId IS NULL OR x.CategorieId<=0), COALESCE(x.CategorieOrdiNAmento,0), x.CategorieDescrizione, x.CategorieId, (x.TipologieId IS NULL OR x.TipologieId<=0), COALESCE(x.TipologieOrdinamento,0), x.TipologieDescrizione, x.TipologieId, (x.GruppiId IS NULL OR x.GruppiId<=0), COALESCE(x.GruppiOrdinamento,0), x.GruppiDEscrizione, x.GruppiId, x.Descrizione1, x.ArticleId;"
    $ids = @(Invoke-Sql $expectedSql | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
    if ($ids.Count -lt 10) { throw 'FIXTURE_NOT_FOUND' }
    $sectorCount = [int](Get-Scalar "SELECT COUNT(DISTINCT COALESCE(v.SettoriId,0)) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where;")
    $idPlain = [int](Get-Scalar "SELECT MIN(v.id) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.Prezzo > 0 AND COALESCE(v.InOfferta,0) = 0 AND v.id NOT IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst GROUP BY id HAVING COUNT(*) > 1);")
    $idPromo = [int](Get-Scalar "SELECT MIN(v.id) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.InOfferta = 1 AND v.OfferteDataInizio <= CURDATE() AND v.OfferteDataFine >= CURDATE() AND v.PrezzoPromo > 0 AND v.id IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst AND InOfferta = 1 GROUP BY id HAVING COUNT(*) = 1);")
    $plainNet = Get-Scalar "SELECT Prezzo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $plainGross = Get-Scalar "SELECT PrezzoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $promoNet = Get-Scalar "SELECT PrezzoPromo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoGross = Get-Scalar "SELECT PrezzoPromoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoBaseNet = Get-Scalar "SELECT Prezzo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoBaseGross = Get-Scalar "SELECT PrezzoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoEnd = Get-Scalar "SELECT DATE_FORMAT(OfferteDataFine, '%d/%m/%Y') AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"

    # foto vere: i file presenti nella copia locale del progetto si copiano nel sito LAB (e si tolgono alla fine). Atteso: articoli con quel nome in Img1..Img4
    $photoNames = @()
    $photoDir = Join-Path $SitePath 'Public\assets\images\articoli'
    New-Item -ItemType Directory -Force -Path $photoDir | Out-Null
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'Public\assets\images\articoli') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '(?i)^\.(jpg|jpeg|png)$' })) {
        $dest = Join-Path $photoDir $f.Name
        if (-not (Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $f.FullName -Destination $dest -Force; $copied.Add($dest) }
        $photoNames += $f.Name.ToLowerInvariant().Replace("'", "''")
    }
    $photoIds = @()
    if ($photoNames.Count -gt 0) { $in = "'" + ($photoNames -join "','") + "'"; $photoIds = @(Invoke-Sql "SELECT DISTINCT v.id FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND (LOWER(v.Img1) IN ($in) OR LOWER(v.Img2) IN ($in) OR LOWER(v.Img3) IN ($in) OR LOWER(v.Img4) IN ($in));" | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }) }

    $stressIds = @()
    if ($Stress) {
        $sample = @(Get-ChildItem -LiteralPath (Join-Path $root 'Public\assets\images\articoli') -File | Where-Object { $_.Extension -match '(?i)^\.(jpg|jpeg|png)$' -and $_.Name -notmatch "^_" -and $_.Length -lt 200KB } | Sort-Object Length)[0]
        if ($null -eq $sample) { throw 'STRESS_SAMPLE_PHOTO_NOT_FOUND' }
        $rankSql = "SELECT x.ArticleId, x.Img1, x.Img2, x.Img3, x.Img4 FROM (SELECT v.id AS ArticleId, v.Img1, v.Img2, v.Img3, v.Img4, ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY CASE WHEN COALESCE(v.TCid,0)>0 THEN 0 ELSE 1 END, COALESCE(v.TCid,-1), COALESCE(v.ArticoliListiniId,0), COALESCE(v.OfferteDettagliId,0)) AS rk FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where) x WHERE x.rk = 1 ORDER BY x.ArticleId LIMIT 250 OFFSET {0};"
        $made = 0
        $stressLines = New-Object Collections.Generic.List[string]
        for ($off = 0; $off -lt 20000; $off += 250) {
            $page = @(Invoke-Sql ($rankSql -f $off) | Where-Object { $_ -match '^[0-9]+' })
            foreach ($pl in $page) { $stressLines.Add([string]$pl) }
            if ($page.Count -eq 0) { break }
        }
        foreach ($line in $stressLines) {
            $p = ([string]$line).Split("`t"); if ($p.Count -lt 5 -or $p[0] -notmatch '^\d+$') { continue }
            foreach ($n in $p[1..4]) {
                $n = $n.Trim(); if ($n -eq '' -or $n -eq 'NULL' -or $n -notmatch '^[A-Za-z0-9 ._()-]+\.(?i:jpg|jpeg|png)$') { continue }
                $dest = Join-Path $photoDir ('_' + $n)
                if (-not (Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $sample.FullName -Destination $dest -Force; $copied.Add($dest); $made++ }
                $stressIds += [int]$p[0]; break
            }
        }
        Write-Host ('  stress: ' + $made + ' miniature finte create, ' + $stressIds.Count + ' articoli con foto')
    }

    Deploy-Repo
    $null = Invoke-Login $jar $false

    $a = Invoke-Http '/listino-catalogo.aspx' $anon
    Check ($a.Status -eq 302 -and $a.Location -match '(?i)accessonegato') 'anonimo: rinvio ad accessonegato'

    $form = Get-Form $jar
    Check ($form.Status -eq 200 -and $form.Button -ne '') 'collegato: la pagina del download risponde 200 con il pulsante Excel'
    $xlsFile = Join-Path $tmp 'listino.xls'
    if ($form.Button -ne '') {
        $bad = Post-Xls $jar $form (Join-Path $tmp 'bad.xls') -DropViewState
        Check ($bad.Type -notmatch 'excel|octet|spreadsheet') ('POST senza token di stato: nessun Excel (stato ' + $bad.Status + ', tipo ' + $bad.Type + ')')
        $form = Get-Form $jar
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $ok = Post-Xls $jar $form $xlsFile
        $sw.Stop()
        Check ($ok.Status -eq 200 -and $ok.Type -match 'application/vnd\.ms-excel') ('POST valido: Excel ricevuto (stato ' + $ok.Status + ', tipo ' + $ok.Type + ', ' + [math]::Round($ok.Length / 1024) + ' KB, ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s)')
        if ($ok.Type -match 'excel') {
            if ($KeepXls -ne '') { Copy-Item -LiteralPath $xlsFile -Destination $KeepXls -Force }
            $info = Get-XlsInfo $xlsFile
            Write-Host ('  misura: ' + $info.Names.Count + ' fogli, ' + $ids.Count + ' articoli attesi, ' + $info.Pictures + ' foto, ' + $info.Styles + ' stili')
            Check ($info.Names.Count -eq ($sectorCount + 2) -and $info.Names[0] -eq 'Indice' -and $info.Names[$info.Names.Count - 1] -eq 'Elenco') ('fogli: Indice + ' + $sectorCount + ' settori + Elenco (trovati ' + $info.Names.Count + ')')
            $badNames = @($info.Names | Where-Object { -not (Is-ValidSheetName $_) })
            $dupNames = @($info.Names | Group-Object { $_.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })
            Check ($badNames.Count -eq 0 -and $dupNames.Count -eq 0) ('nomi dei fogli validi e unici (non validi ' + $badNames.Count + ', doppi ' + $dupNames.Count + ')')
            $missingTargets = @($info.Names | Where-Object { $_ -ne 'Indice' -and $info.DocTargets -notcontains $_ }).Count
            Check ($info.DocLinks -ge $sectorCount -and $missingTargets -eq 0) ('indice: un collegamento a ogni foglio di settore e all''Elenco (' + $info.DocLinks + ', fogli senza collegamento ' + $missingTargets + ')')
            # tutti gli articoli, una volta, nell'ordine atteso (fogli settore in sequenza, poi Elenco)
            $secIds = @($info.Items | ForEach-Object { $_.Id }); $elIds = @($info.ElencoItems | ForEach-Object { $_.Id })
            $miss = @($ids | Where-Object { $secIds -notcontains $_ }).Count; $extra = @($secIds | Where-Object { $ids -notcontains $_ }).Count
            $dupIds = @($secIds | Group-Object | Where-Object { $_.Count -gt 1 }).Count
            Check ($miss -eq 0 -and $extra -eq 0 -and $dupIds -eq 0) ('fogli settore: ogni articolo atteso una volta (mancanti ' + $miss + ' su ' + $ids.Count + ', in piu ' + $extra + ', doppi ' + $dupIds + ')')
            Check (($secIds -join ',') -eq ($ids -join ',')) 'fogli settore: ordine settore/categoria/tipologia/gruppo come da SQL'
            Check (($elIds -join ',') -eq ($ids -join ',')) ('Elenco: stesso insieme e stesso ordine (' + $elIds.Count + ' righe)')
            # prezzi: colonna Prezzo (numero) dei fogli settore, indice di colonna 5
            $label = if ($info.Texts.ToString() -match '(?i)Iva\s+inclusa') { 'inclusa' } else { 'esclusa' }
            $expPlain = [double]::Parse($(if ($label -eq 'inclusa') { $plainGross } else { $plainNet }), [Globalization.CultureInfo]::InvariantCulture)
            $expPromo = [double]::Parse($(if ($label -eq 'inclusa') { $promoGross } else { $promoNet }), [Globalization.CultureInfo]::InvariantCulture)
            $expOld = [double]::Parse($(if ($label -eq 'inclusa') { $promoBaseGross } else { $promoBaseNet }), [Globalization.CultureInfo]::InvariantCulture)
            $iPlain = @($info.Items | Where-Object { $_.Id -eq $idPlain })[0]; $iPromo = @($info.Items | Where-Object { $_.Id -eq $idPromo })[0]
            $vPlain = if ($null -ne $iPlain -and $iPlain.Cells.ContainsKey(5)) { [double]::Parse($iPlain.Cells[5], [Globalization.CultureInfo]::InvariantCulture) } else { -1 }
            $vPromo = if ($null -ne $iPromo -and $iPromo.Cells.ContainsKey(5)) { [double]::Parse($iPromo.Cells[5], [Globalization.CultureInfo]::InvariantCulture) } else { -1 }
            $vOld = if ($null -ne $iPromo -and $iPromo.Cells.ContainsKey(6) -and $iPromo.Cells[6] -ne '') { [double]::Parse($iPromo.Cells[6], [Globalization.CultureInfo]::InvariantCulture) } else { -1 }
            Check ([math]::Abs($vPlain - $expPlain) -lt 0.005) ('articolo senza offerta: prezzo numerico ' + $expPlain + ' (profilo IVA ' + $label + ', letto ' + $vPlain + ')')
            Check ([math]::Abs($vPromo - $expPromo) -lt 0.005) ('articolo in offerta: prezzo promo ' + $expPromo + ' (letto ' + $vPromo + ')')
            Check ([math]::Abs($vOld - $expOld) -lt 0.005) ('articolo in offerta: prezzo di listino ' + $expOld + ' (letto ' + $vOld + ')')
            $offCell = if ($null -ne $iPromo -and $iPromo.Cells.ContainsKey(7)) { $iPromo.Cells[7] } else { '' }
            Check ($offCell -match 'OFFERTA|Offerta' -and $offCell.Contains($promoEnd)) ('articolo in offerta: nome offerta e validita fino al ' + $promoEnd + ' (letto: ' + $offCell + ')')
            # foto: l'ancora della foto sta sulla riga del SUO articolo (nessuna foto sbagliata o spostata)
            $bad2 = 0; $withAnchor = 0
            foreach ($phId in $photoIds) { $it = @($info.Items | Where-Object { $_.Id -eq $phId })[0]; if ($null -eq $it) { $bad2++; continue }; if ($info.Anchors.ContainsKey($it.Sheet) -and $info.Anchors[$it.Sheet].Contains([int]$it.Row)) { $withAnchor++ } else { $bad2++ } }
            Check ($photoIds.Count -gt 0) ('fixture foto: articoli con foto vera nel listino (' + $photoIds.Count + ')')
            Check ($bad2 -eq 0 -and $info.Pictures -ge 1) ('foto sulla riga del proprio articolo (' + $withAnchor + ' su ' + $photoIds.Count + ', fuori posto ' + $bad2 + ')')
            # disponibilita: tre colori diversi nelle celle (verde, giallo, rosso)
            if ($Stress) {
                $totalAnch = 0; foreach ($k in $info.Anchors.Keys) { $totalAnch += $info.Anchors[$k].Count }
                $wrong = 0; foreach ($sid in $stressIds) { $it = @($info.Items | Where-Object { $_.Id -eq $sid })[0]; if ($null -eq $it -or -not ($info.Anchors.ContainsKey($it.Sheet) -and $info.Anchors[$it.Sheet].Contains([int]$it.Row))) { $wrong++ } }
                $maxSheet = 0; foreach ($k in $info.Anchors.Keys) { if ($info.Anchors[$k].Count -gt $maxSheet) { $maxSheet = $info.Anchors[$k].Count } }
                Check ($totalAnch -ge $stressIds.Count -and $wrong -eq 0) ('stress: una foto per articolo sulla propria riga (foto ' + $totalAnch + ' su ' + $stressIds.Count + ', fuori posto ' + $wrong + ', foglio piu grande ' + $maxSheet + ' foto)')
                Write-Host ('  stress: ' + [math]::Round($ok.Length / 1MB, 1) + ' MB, ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s, immagini uniche nel file ' + $info.Pictures)
            }
            Check ($info.Texts.ToString().Contains('Disponibile') -and $info.Texts.ToString().Contains('Non disponibile')) 'colonna disponibilita: testi Disponibile e Non disponibile presenti'
            Check ($info.Styles -lt 3500) ('stili sotto il limite di 4000 (' + $info.Styles + ')')
            Check ($ok.Length -lt 25MB) ('peso del file sotto 25 MB (' + [math]::Round($ok.Length / 1MB, 1) + ' MB)')
            Check ($info.Texts.ToString() -match 'Fanno fede') 'nota: fanno fede i prezzi del sito'
        }
    }
    if ($e2e.Count -gt 0) { $exit = 1 }

    if (-not $SkipMutants -and -not $Red -and $exit -eq 0) {
        $snap = Get-Text $repoBytes['App_Code\KeepStoreCatalogExportSnapshot.vb']
        $xw = Get-Text $repoBytes['App_Code\KeepStoreCatalogXlsWriter.vb']
        $mutants = [ordered]@{
            'M01_NO_RANK_FILTER' = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = ' WHERE x.CatalogRowRank=1"'; To = '"'; Kill = 'ids' }
            'M02_CATEGORY_ORDER' = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = 'COALESCE(x.CategorieOrdiNAmento,0),x.CategorieDescrizione,x.CategorieId,'; To = 'x.CategorieId DESC,'; Kill = 'order' }
            'M03_NO_PROMO'       = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = 'If model.HasDefaultQuantityOffer Then'; To = 'If False Then'; Kill = 'promo' }
            'M04_PHOTO_ROW'      = @{ File = 'App_Code\KeepStoreCatalogXlsWriter.vb'; From = 'Dim anchorRow As Integer = r ''PHOTO_ROW'; To = 'Dim anchorRow As Integer = r + 1 ''PHOTO_ROW'; Kill = 'photo' }
            'M05_NO_SHEETNAME_CLEAN' = @{ File = 'App_Code\KeepStoreCatalogXlsWriter.vb'; From = 'candidate = SanitizeSheetName(raw) ''SHEET_SANITIZE'; To = 'candidate = raw ''SHEET_SANITIZE'; Kill = 'names' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            $src = if ($mu.File -like '*Snapshot*') { $snap } else { $xw }
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-Mutant $mu.File ($src.Replace($mu.From, $mu.To))
                $null = Invoke-Login $jar $false
                $f2 = Get-Form $jar
                $r = Post-Xls $jar $f2 (Join-Path $tmp 'm.xls')
                $dead = $false; $why = ''
                if ($r.Type -notmatch 'excel') { $dead = $true; $why = 'nessun Excel' } else {
                    $inf = Get-XlsInfo (Join-Path $tmp 'm.xls'); $sid = @($inf.Items | ForEach-Object { $_.Id })
                    if ($mu.Kill -eq 'ids') { $dead = (@($sid | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0 -or $sid.Count -ne $ids.Count); $why = 'articoli ripetuti' }
                    elseif ($mu.Kill -eq 'order') { $dead = (($sid -join ',') -ne ($ids -join ',')); $why = 'ordine diverso' }
                    elseif ($mu.Kill -eq 'promo') { $ip = @($inf.Items | Where-Object { $_.Id -eq $idPromo })[0]; $vv = if ($null -ne $ip -and $ip.Cells.ContainsKey(5)) { [double]::Parse($ip.Cells[5], [Globalization.CultureInfo]::InvariantCulture) } else { -1 }; $dead = ([math]::Abs($vv - $expPromo) -ge 0.005); $why = 'prezzo promo diverso' }
                    elseif ($mu.Kill -eq 'photo') { $b3 = 0; foreach ($phId in $photoIds) { $it = @($inf.Items | Where-Object { $_.Id -eq $phId })[0]; if ($null -eq $it -or -not ($inf.Anchors.ContainsKey($it.Sheet) -and $inf.Anchors[$it.Sheet].Contains([int]$it.Row))) { $b3++ } }; $dead = ($b3 -gt 0); $why = 'foto fuori riga' }
                    elseif ($mu.Kill -eq 'names') { $dn = @($inf.Names | Group-Object { $_.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 }).Count; $dead = ($dn -gt 0 -or $inf.Names.Count -ne ($sectorCount + 2)); $why = 'nomi fogli doppi' }
                }
                if ($dead) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $why + ')') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }

    # pin statici (testo del codice)
    $pageText = if ($null -ne $repoBytes['listino-catalogo.aspx.vb']) { Get-Text $repoBytes['listino-catalogo.aspx.vb'] } else { '' }
    $iRej = $pageText.IndexOf('If Response.IsRequestBeingRedirected Then Return'); $iGen = $pageText.IndexOf('CatalogExportSnapshotProvider.LoadCurrent')
    Check ($iRej -ge 0 -and $iGen -gt $iRej) 'pin: il rifiuto CSRF precede ogni generazione'
    Check ($pageText.Contains('SemaphoreSlim') -and $pageText.Contains('ActiveUsers') -and $pageText.Contains('btnXls_Click') -and $pageText.Contains('RunExport')) 'pin: Excel e PDF passano dalle stesse guardie (un file alla volta per utente, limite globale)'
    $xlsText = if ($null -ne $repoBytes['App_Code\KeepStoreCatalogXlsWriter.vb']) { Get-Text $repoBytes['App_Code\KeepStoreCatalogXlsWriter.vb'] } else { '' }
    Check ($xlsText -ne '' -and $xlsText -notmatch 'PrezzoPromo|InOfferta|CartPriceRevalidation') 'pin: il writer Excel legge solo lo snapshot (nessun secondo calcolo di prezzo o promo)'
    $pageAspx = Get-Text ([IO.File]::ReadAllBytes((Join-Path $root 'listino-catalogo.aspx')))
    Check ($pageAspx -match 'settore, categoria, tipologia' -and $pageAspx -notmatch 'puo richiedere') 'pin: testi della pagina con la categoria e con gli accenti'
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { foreach ($c in @($copied)) { if (Test-Path -LiteralPath $c) { Remove-Item -LiteralPath $c -Force } } } catch { Write-Host '  ATTENZIONE: file di prova non rimossi' }
    try { $th = Join-Path $SitePath 'App_Data\CatalogExportThumbs'; if (Test-Path -LiteralPath $th) { Remove-Item -LiteralPath $th -Recurse -Force } } catch { }
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'CATALOG_XLS PASS' } else { Write-Host 'CATALOG_XLS FAIL' }
exit $exit
