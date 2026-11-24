[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Red, [string]$KeepPdf = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CATALOG-DOWNLOAD-1A, task A (PDF). Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843, utente di prova) del download "Scarica listino e offerte":
# il PDF e valido, ha segnalibri settore > tipologia > gruppo, ogni articolo compare UNA volta nell'ordine atteso (calcolato da SQL), il prezzo e quello del
# profilo (netto o lordo), l'offerta ha etichetta, vecchio prezzo e validita, una foto vera viene incorporata, l'anonimo e un POST senza controllo CSRF
# non ricevono nessun file. Atteso da SQL, non dal codice sotto prova. Fixture foto: un solo valore Img1 (ripristinato) e un file copiato nel sito LAB.
# Mutazioni sulla copia LAB; i byte originali sono rimessi alla fine. -Red non copia i file del repo (mostra il test rosso prima del codice).
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'CATALOG_PDF FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$files = @('listino-catalogo.aspx', 'listino-catalogo.aspx.vb', 'App_Code\KeepStoreCatalogExportSnapshot.vb', 'App_Code\KeepStoreCatalogExportImages.vb',
    'App_Code\KeepStoreCatalogPdfWriter.vb', 'App_Code\StorefrontCanonicalHostPolicy.vb', 'App_Code\KeepStoreAccountTiles.vb')
$repoBytes = @{}; $origBytes = @{}
foreach ($f in $files) {
    $rp = Join-Path $root $f; $sp = Join-Path $SitePath $f
    $repoBytes[$f] = if (Test-Path -LiteralPath $rp) { [IO.File]::ReadAllBytes($rp) } else { $null }
    $origBytes[$f] = if (Test-Path -LiteralPath $sp) { [IO.File]::ReadAllBytes($sp) } else { $null }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-catpdf-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')
$jar = Join-Path $tmp 'auth.txt'; $anon = Join-Path $tmp 'anon.txt'
# il file in Bin porta il marchio di provenienza (0x80131515 con Add-Type -Path): si carica dai byte
[void][Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $root 'Bin\itextsharp.dll')))

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

# POST del modulo con tutti i campi nascosti, restituisce stato, tipo, byte del corpo.
function Get-Form([string]$jarFile) {
    $x = Invoke-Http '/listino-catalogo.aspx' $jarFile
    $fields = New-Object Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($x.Body, '<input[^>]*type="hidden"[^>]*>')) {
        $n = [regex]::Match($m.Value, 'name="([^"]*)"'); $v = [regex]::Match($m.Value, 'value="([^"]*)"')
        if ($n.Success) { $fields.Add($n.Groups[1].Value + '=' + [Uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($(if ($v.Success) { $v.Groups[1].Value } else { '' })))) }
    }
    $btn = [regex]::Match($x.Body, 'name="([^"]*btnPdf)"')
    return @{ Status = $x.Status; Fields = $fields; Button = $(if ($btn.Success) { $btn.Groups[1].Value } else { '' }); Body = $x.Body }
}
function Post-Pdf([string]$jarFile, $form, [string]$outFile, [switch]$DropViewState) {
    $parts = New-Object Collections.Generic.List[string]
    foreach ($f in $form.Fields) { if ($DropViewState -and $f -like '__VIEWSTATE*') { continue }; $parts.Add($f) }
    $parts.Add([Uri]::EscapeDataString($form.Button) + '=' + [Uri]::EscapeDataString('Scarica il PDF'))
    $body = Join-Path $tmp ('post' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($body, ($parts -join '&'), $utf8)
    if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
    $a = @('--noproxy', '*', '-s', '--max-time', '600', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-b', $jarFile, '-c', $jarFile, '-o', $outFile, '-w', '%{http_code}|%{content_type}',
        '-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + '/listino-catalogo.aspx'), '--data', ('@' + $body), ($base + '/listino-catalogo.aspx'))
    $w = ((& curl.exe @a) -join '').Split('|')
    $len = if (Test-Path -LiteralPath $outFile) { (Get-Item -LiteralPath $outFile).Length } else { 0 }
    return @{ Status = [int]$w[0]; Type = $w[1]; Length = $len }
}
function Get-PdfInfo([string]$file) {
    $bytes = [IO.File]::ReadAllBytes($file)
    $r = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList (, $bytes)
    $info = @{ Pages = $r.NumberOfPages; Index = ''; Text = ''; Images = 0; Dots = (New-Object 'Collections.Generic.HashSet[string]'); Links = 0; LinkIds = (New-Object 'Collections.Generic.HashSet[int]'); FirstLink = ''; Bookmarks = $null }
    $sb = New-Object Text.StringBuilder
    for ($p = 1; $p -le $r.NumberOfPages; $p++) { [void]$sb.Append([iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($r, $p)); [void]$sb.Append("`n") }
    $info.Text = $sb.ToString()
    $info.Index = [iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($r, 2)
    for ($i = 1; $i -lt $r.XrefSize; $i++) {
        $o = $r.GetPdfObject($i)
        if ($null -ne $o -and $o.IsStream()) { $st = $o; $sub = $st.Get([iTextSharp.text.pdf.PdfName]::SUBTYPE); if ($null -ne $sub -and $sub.ToString() -eq '/Image') { $info.Images++ } }
    }
    # pallini della disponibilita: colori di riempimento (rg) nel contenuto delle prime pagine con righe
    $lastPage = [math]::Min($r.NumberOfPages, 90)
    for ($p = 3; $p -le $lastPage; $p++) {
        $content = [Text.Encoding]::GetEncoding(28591).GetString($r.GetPageContent($p))
        foreach ($m in [regex]::Matches($content, '([0-9.]+) ([0-9.]+) ([0-9.]+) rg')) {
            $rgb = ((@(1, 2, 3) | ForEach-Object { [int][math]::Round([double]::Parse($m.Groups[$_].Value, [Globalization.CultureInfo]::InvariantCulture) * 255) }) -join ',')
            if ($rgb -in @('34,160,72', '240,176,0', '214,40,40')) { [void]$info.Dots.Add($rgb) }
        }
        if ($info.Dots.Count -ge 3) { break }
    }
    # collegamenti alle schede: annotazioni /A /URI delle pagine
    for ($p = 1; $p -le $r.NumberOfPages; $p++) {
        $ann = $r.GetPageN($p).GetAsArray([iTextSharp.text.pdf.PdfName]::ANNOTS)
        if ($null -eq $ann) { continue }
        for ($k = 0; $k -lt $ann.Size; $k++) {
            $d = $ann.GetAsDict($k); if ($null -eq $d) { continue }
            $act = $d.GetAsDict([iTextSharp.text.pdf.PdfName]::A); if ($null -eq $act) { continue }
            $u = $act.Get([iTextSharp.text.pdf.PdfName]::URI)
            if ($null -ne $u) { $info.Links++; $mid = [regex]::Match($u.ToString(), 'articolo\.aspx\?id=([0-9]+)$'); if ($mid.Success) { [void]$info.LinkIds.Add([int]$mid.Groups[1].Value) }; if ($info.FirstLink -eq '') { $info.FirstLink = $u.ToString() } }
        }
    }
    $info.Bookmarks = [iTextSharp.text.pdf.SimpleBookmark]::GetBookmark($r)
    $r.Close()
    return $info
}
function Fmt([string]$dec) { return ([decimal]::Parse($dec, [Globalization.CultureInfo]::InvariantCulture)).ToString('N2', [Globalization.CultureInfo]::GetCultureInfo('it-IT')) }
function Bookmark-Depth($list, [int]$d) {
    $max = $d
    foreach ($b in @($list)) { if ($null -eq $b) { continue }; if ($b.ContainsKey('Kids') -and $null -ne $b['Kids']) { $x = Bookmark-Depth $b['Kids'] ($d + 1); if ($x -gt $max) { $max = $x } } }
    return $max
}

$exit = 0
$uid = 0; $lst = 0; $photoSite = ''; $copied = New-Object Collections.Generic.List[string]
try {
    $uid = [int](Get-Scalar "SELECT UtentiId AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $lst = [int](Get-Scalar "SELECT Listino AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $where = "v.NListino = $lst AND COALESCE(a.Abilitato,0) = 1 AND COALESCE(v.Export,0) <> 0"
    # articoli attesi: un id una volta (riga con TCid positivo prima), ordinati come da regola; atteso calcolato qui da SQL
    $expectedSql = "SELECT x.ArticleId AS ksval FROM (SELECT v.id AS ArticleId, v.Codice, v.Descrizione1, v.SettoriId, v.SettoriDescrizione, v.SettoriOrdINamento, v.CategorieId, v.CategorieDescrizione, v.CategorieOrdiNAmento, v.TipologieId, v.TipologieDescrizione, v.TipologieOrdinamento, v.GruppiId, v.GruppiDEscrizione, v.GruppiOrdinamento, ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY CASE WHEN COALESCE(v.TCid,0)>0 THEN 0 ELSE 1 END, COALESCE(v.TCid,-1), COALESCE(v.ArticoliListiniId,0), COALESCE(v.OfferteDettagliId,0)) AS rk FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where) x WHERE x.rk = 1 ORDER BY (x.SettoriId IS NULL OR x.SettoriId<=0), COALESCE(x.SettoriOrdINamento,0), x.SettoriDescrizione, x.SettoriId, (x.CategorieId IS NULL OR x.CategorieId<=0), COALESCE(x.CategorieOrdiNAmento,0), x.CategorieDescrizione, x.CategorieId, (x.TipologieId IS NULL OR x.TipologieId<=0), COALESCE(x.TipologieOrdinamento,0), x.TipologieDescrizione, x.TipologieId, (x.GruppiId IS NULL OR x.GruppiId<=0), COALESCE(x.GruppiOrdinamento,0), x.GruppiDEscrizione, x.GruppiId, x.Descrizione1, x.ArticleId;"
    $ids = @(Invoke-Sql $expectedSql | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
    if ($ids.Count -lt 10) { throw 'FIXTURE_NOT_FOUND' }
    $codes = @{}
    $cl = @(Invoke-Sql "SELECT DISTINCT v.id, v.Codice FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where;")
    foreach ($line in $cl) { $p = ([string]$line).Split("`t"); if ($p.Count -eq 2 -and $p[0] -match '^\d+$') { $codes[[int]$p[0]] = $p[1].Trim() } }
    $eans = @{}
    foreach ($line in @(Invoke-Sql "SELECT v.id, v.Ean FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.id IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst GROUP BY id HAVING COUNT(*) = 1);")) { $p = ([string]$line).Split("`t"); if ($p.Count -eq 2 -and $p[0] -match '^\d+$' -and $p[1].Trim() -match '^\d{8,14}$') { $eans[[int]$p[0]] = $p[1].Trim() } }
    # un EAN vale come identita solo se in tutto il listino appartiene a UN articolo
    $eanCount = @{}
    foreach ($line in @(Invoke-Sql "SELECT v.Ean, COUNT(DISTINCT v.id) AS n FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.Ean REGEXP '^[0-9]{8,14}$' GROUP BY v.Ean;")) { $p = ([string]$line).Split("`t"); if ($p.Count -eq 2 -and $p[1] -match '^\d+$') { $eanCount[$p[0].Trim()] = [int]$p[1] } }
    $eanIds = @($ids | Where-Object { $eans.ContainsKey($_) -and $eanCount.ContainsKey($eans[$_]) -and $eanCount[$eans[$_]] -eq 1 } | Select-Object -First 400)
    # articoli con piu righe nella vista (varianti/offerte) ma UN solo EAN: devono comparire una volta sola (prova del filtro sulla riga scelta)
    $multi = @{}
    foreach ($line in @(Invoke-Sql "SELECT x.id, MIN(x.Ean) AS e FROM (SELECT v.id, v.Ean FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where) x GROUP BY x.id HAVING COUNT(*) > 1 AND COUNT(DISTINCT x.Ean) = 1 AND MIN(x.Ean) REGEXP '^[0-9]{8,14}$';")) { $p = ([string]$line).Split("`t"); if ($p.Count -eq 2 -and $p[0] -match '^\d+$' -and $eanCount.ContainsKey($p[1].Trim()) -and $eanCount[$p[1].Trim()] -eq 1) { $multi[[int]$p[0]] = $p[1].Trim() } }
    # un articolo semplice e uno in promo semplice per i controlli di prezzo
    $idPlain = [int](Get-Scalar "SELECT MIN(v.id) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.Prezzo > 0 AND COALESCE(v.InOfferta,0) = 0 AND v.id NOT IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst GROUP BY id HAVING COUNT(*) > 1);")
    $idPromo = [int](Get-Scalar "SELECT MIN(v.id) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND v.InOfferta = 1 AND v.OfferteDataInizio <= CURDATE() AND v.OfferteDataFine >= CURDATE() AND v.PrezzoPromo > 0 AND v.id IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst AND InOfferta = 1 GROUP BY id HAVING COUNT(*) = 1);")
    $plainNet = Get-Scalar "SELECT Prezzo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $plainGross = Get-Scalar "SELECT PrezzoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $promoNet = Get-Scalar "SELECT PrezzoPromo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoGross = Get-Scalar "SELECT PrezzoPromoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoBaseNet = Get-Scalar "SELECT Prezzo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoBaseGross = Get-Scalar "SELECT PrezzoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoEnd = Get-Scalar "SELECT DATE_FORMAT(OfferteDataFine, '%d/%m/%Y') AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"

    # foto vere: i file presenti nella copia locale del progetto (cartelle protette) si copiano nel sito LAB (e si tolgono alla fine); il logo dell'azienda
    # (LogoWeb dell'azienda dell'utente di prova) si copia nella cartella dei loghi. Attese: tante foto quanti sono gli articoli con quel nome in Img1.
    $photoNames = @()
    $photoDir = Join-Path $SitePath 'Public\assets\images\articoli'
    New-Item -ItemType Directory -Force -Path $photoDir | Out-Null
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'Public\assets\images\articoli') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '(?i)^\.(jpg|jpeg|png)$' })) {
        $dest = Join-Path $photoDir $f.Name
        if (-not (Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $f.FullName -Destination $dest -Force; $copied.Add($dest) }
        $photoNames += $f.Name.ToLowerInvariant().Replace("'", "''")
    }
    $expectedPhotos = 0
    if ($photoNames.Count -gt 0) { $in = "'" + ($photoNames -join "','") + "'"; $expectedPhotos = [int](Get-Scalar "SELECT COUNT(DISTINCT v.id) AS ksval FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE $where AND (LOWER(v.Img1) IN ($in) OR LOWER(v.Img2) IN ($in) OR LOWER(v.Img3) IN ($in) OR LOWER(v.Img4) IN ($in));") }
    $logoName = Get-Scalar "SELECT COALESCE(LogoWeb, '') AS ksval FROM aziende WHERE id = (SELECT AziendaId FROM vlogin WHERE UserName = 'PROVA' LIMIT 1);"
    if ($logoName -eq '') { $logoName = Get-Scalar "SELECT COALESCE(LogoWeb, '') AS ksval FROM aziende ORDER BY id LIMIT 1;" }
    $logoSrc = if ($logoName -ne '') { Join-Path $root ('Public\assets\images\logo\' + $logoName) } else { '' }
    $logoCopied = $false
    if ($logoSrc -ne '' -and (Test-Path -LiteralPath $logoSrc)) {
        $logoDir = Join-Path $SitePath 'Public\assets\images\logo'; New-Item -ItemType Directory -Force -Path $logoDir | Out-Null
        $logoDest = Join-Path $logoDir $logoName
        if (-not (Test-Path -LiteralPath $logoDest)) { Copy-Item -LiteralPath $logoSrc -Destination $logoDest -Force; $copied.Add($logoDest) }
        $logoCopied = $true
    }
    $photoSite = if ($copied.Count -gt 0) { 'x' } else { '' }

    Deploy-Repo
    $null = Invoke-Login $jar $false

    # anonimo: nessuna pagina e nessun file
    $a = Invoke-Http '/listino-catalogo.aspx' $anon
    Check ($a.Status -eq 302 -and $a.Location -match '(?i)accessonegato') 'anonimo: rinvio ad accessonegato'

    $form = Get-Form $jar
    Check ($form.Status -eq 200 -and $form.Button -ne '') 'collegato: la pagina del download risponde 200 con il pulsante PDF'
    $pdfFile = Join-Path $tmp 'listino.pdf'
    if ($form.Button -ne '') {
        # POST senza campo di stato (controllo CSRF respinto): nessun PDF
        $bad = Post-Pdf $jar $form (Join-Path $tmp 'bad.pdf') -DropViewState
        Check ($bad.Type -notmatch 'pdf') ('POST senza token di stato: nessun PDF (stato ' + $bad.Status + ', tipo ' + $bad.Type + ')')
        $form = Get-Form $jar
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $ok = Post-Pdf $jar $form $pdfFile
        $sw.Stop()
        Check ($ok.Status -eq 200 -and $ok.Type -match 'application/pdf') ('POST valido: PDF ricevuto (stato ' + $ok.Status + ', tipo ' + $ok.Type + ', ' + [math]::Round($ok.Length / 1024) + ' KB, ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s)')
        if ($ok.Type -match 'pdf') {
            if ($KeepPdf -ne '') { Copy-Item -LiteralPath $pdfFile -Destination $KeepPdf -Force }
            $info = Get-PdfInfo $pdfFile
            Write-Host ('  misura: ' + $info.Pages + ' pagine, ' + $ids.Count + ' articoli, ' + $info.Images + ' immagini')
            $text = $info.Text
            $textNs = ($text -replace '\s', '')
            Check ($text.Contains('Indice')) 'indice presente'
            Check (($info.Index -notmatch '(?<![0-9])000(?![0-9])') -and ($info.Index -match '[0-9]{1,3}')) 'indice con i numeri di pagina reali (nessun segnaposto)'
            $depth = Bookmark-Depth $info.Bookmarks 1
            Check ($null -ne $info.Bookmarks -and $depth -ge 4) ('segnalibri settore > categoria > tipologia > gruppo (profondita ' + $depth + ')')
            # tutti gli articoli, una volta, nell'ordine atteso: i codici si cercano in sequenza a partire dalla posizione precedente
            # ordine: solo gli articoli con un EAN univoco (identita certa); presenza: tutti, con il codice intero (se breve) o i primi 8 caratteri
            $pos = 0; $missing = 0; $order = 0
            foreach ($id in $ids) {
                if (-not $info.LinkIds.Contains($id)) { $missing++; if ($missing -le 6) { Write-Host ('    mancante: id ' + $id + ' codice [' + $codes[$id] + ']') } }
                if ($eans.ContainsKey($id) -and $eanCount.ContainsKey($eans[$id]) -and $eanCount[$eans[$id]] -eq 1) {
                    $ean = $eans[$id]
                    $idx = $textNs.IndexOf($ean, $pos, [StringComparison]::Ordinal)
                    if ($idx -lt 0) { $order++ } else { $pos = $idx + $ean.Length }
                }
            }
            $extra = 0; $expSet = New-Object 'Collections.Generic.HashSet[int]'; foreach ($e in $ids) { [void]$expSet.Add($e) }; foreach ($l in $info.LinkIds) { if (-not $expSet.Contains($l)) { $extra++ } }
            Check ($missing -eq 0 -and $extra -eq 0) ('ogni articolo atteso e nel PDF una volta e nessuno in piu (mancanti ' + $missing + ' su ' + $ids.Count + ', in piu ' + $extra + ')')
            Check ($order -eq 0) ('ordine settore/tipologia/gruppo come da SQL (fuori ordine ' + $order + ')')
            # codici duplicati: ogni codice atteso compare una sola volta come cella codice
            $dups = 0
            foreach ($id in @($multi.Keys)) { $c = ([regex]::Matches($textNs, [regex]::Escape($multi[$id]))).Count; $want = if (([string]$codes[$id]).Trim() -eq $multi[$id]) { 2 } else { 1 }; if ($c -ne $want) { $dups++; Write-Host ('    articolo a piu righe ' + $id + ' compare ' + $c + ' volte') } }
    foreach ($id in $eanIds) { $c = ([regex]::Matches($textNs, [regex]::Escape($eans[$id]))).Count; $want = if (([string]$codes[$id]).Trim() -eq $eans[$id]) { 2 } else { 1 }; if ($c -ne $want) { $dups++; if ($dups -le 5) { Write-Host ('    EAN ' + $eans[$id] + ' id ' + $id + ' compare ' + $c + ' volte') } } }
            Check ($dups -eq 0) ('ogni EAN compare una sola volta (' + $eanIds.Count + ' controllati, difformi ' + $dups + ')')
            $label = if ($text -match '(?i)Iva\s+Inclusa') { 'inclusa' } else { 'esclusa' }
            $expPlain = if ($label -eq 'inclusa') { Fmt $plainGross } else { Fmt $plainNet }
            $expPromo = if ($label -eq 'inclusa') { Fmt $promoGross } else { Fmt $promoNet }
            $expOld = if ($label -eq 'inclusa') { Fmt $promoBaseGross } else { Fmt $promoBaseNet }
            $iPlain = $textNs.IndexOf((([string]$codes[$idPlain]) -replace '\s', ''), [StringComparison]::Ordinal)
            $segPlain = if ($iPlain -ge 0) { $s0 = [math]::Max(0, $iPlain - 260); $textNs.Substring($s0, [math]::Min(560, $textNs.Length - $s0)) } else { '' }
            Check ($segPlain.Replace(' ', '').Contains($expPlain)) ('articolo senza offerta: prezzo ' + $expPlain + ' (profilo IVA ' + $label + ')')
            $iPromo = $textNs.IndexOf((([string]$codes[$idPromo]) -replace '\s', ''), [StringComparison]::Ordinal)
            $segPromo = if ($iPromo -ge 0) { $s1 = [math]::Max(0, $iPromo - 260); $textNs.Substring($s1, [math]::Min(560, $textNs.Length - $s1)) } else { '' }
            Check ($segPromo.Contains($expPromo)) ('articolo in offerta: prezzo promo ' + $expPromo + ' (visto: ' + $segPromo.Substring(0, [math]::Min(110, $segPromo.Length)) + ')')
            Check ($segPromo.Contains($expOld)) ('articolo in offerta: prezzo di listino ' + $expOld + ' visibile')
            Check ($segPromo.Contains($promoEnd)) ('articolo in offerta: validita fino al ' + $promoEnd)
            Check ($expectedPhotos -gt 0) ('fixture foto: articoli con foto vera nel listino (' + $expectedPhotos + ')')
            Check ($info.Images -ge ($expectedPhotos + $(if ($logoCopied) { 1 } else { 0 }))) ('foto e logo incorporati nel PDF (immagini ' + $info.Images + ', attese almeno ' + ($expectedPhotos + $(if ($logoCopied) { 1 } else { 0 })) + ')')
            Check ($info.Dots.Count -eq 3) ('colonna disponibilita: pallini verdi, gialli e rossi presenti (' + $info.Dots.Count + ' colori su 3)')
            Check ($info.Links -ge ($ids.Count / 2) -and $info.FirstLink -match '^https?://[^/]+/articolo\.aspx\?id=[0-9]+$') ('il codice apre la scheda sul sito (collegamenti ' + $info.Links + ', primo ' + $info.FirstLink + ')')
            Check ($ok.Length -lt 60MB) ('peso del PDF sotto 60 MB (' + [math]::Round($ok.Length / 1MB, 1) + ' MB)')
        }
    }
    if ($e2e.Count -gt 0) { $exit = 1 }

    if (-not $SkipMutants -and -not $Red -and $exit -eq 0) {
        $snap = Get-Text $repoBytes['App_Code\KeepStoreCatalogExportSnapshot.vb']
        $page = Get-Text $repoBytes['listino-catalogo.aspx.vb']
        $mutants = [ordered]@{
            'M01_NO_RANK_FILTER' = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = ' WHERE x.CatalogRowRank=1"'; To = '"' ; Kill = 'dups' }
            'M02_CATEGORY_ORDER' = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = 'COALESCE(x.CategorieOrdiNAmento,0),x.CategorieDescrizione,x.CategorieId,'; To = 'x.CategorieId DESC,'; Kill = 'order' }
            'M04_NO_GREEN'       = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = '"is-ok"'; To = '"is-okX"'; Kill = 'dots' }
            'M03_NO_PROMO'       = @{ File = 'App_Code\KeepStoreCatalogExportSnapshot.vb'; From = 'If model.HasDefaultQuantityOffer Then'; To = 'If False Then'; Kill = 'promo' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            $src = if ($mu.File -like 'listino*') { $page } else { $snap }
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-Mutant $mu.File ($src.Replace($mu.From, $mu.To))
                $null = Invoke-Login $jar $false
                $f2 = Get-Form $jar
                $dead = $false; $why = ''
                if ($mu.Kill -eq 'csrf') {
                    $r = Post-Pdf $jar $f2 (Join-Path $tmp 'm.pdf') -DropViewState
                    $dead = ($r.Type -match 'pdf'); $why = 'PDF con POST senza token'
                } else {
                    $r = Post-Pdf $jar $f2 (Join-Path $tmp 'm.pdf')
                    if ($r.Type -notmatch 'pdf') { $dead = $true; $why = 'nessun PDF' } else {
                        $inf = Get-PdfInfo (Join-Path $tmp 'm.pdf'); $t2 = ($inf.Text -replace '\s', '')
                        if ($mu.Kill -eq 'promo') {
                            $i2 = $t2.IndexOf((([string]$codes[$idPromo]) -replace '\s', ''), [StringComparison]::Ordinal); $s2 = if ($i2 -ge 0) { $q0 = [math]::Max(0, $i2 - 260); $t2.Substring($q0, [math]::Min(560, $t2.Length - $q0)) } else { '' }
                            $dead = -not $s2.Contains($expPromo); $why = 'prezzo promo mancante'
                        } elseif ($mu.Kill -eq 'order') {
                            $p2 = 0; $o2 = 0; foreach ($i in $ids) { if (-not ($eans.ContainsKey($i) -and $eanCount.ContainsKey($eans[$i]) -and $eanCount[$eans[$i]] -eq 1)) { continue }; $c = $eans[$i]; $x = $t2.IndexOf($c, $p2, [StringComparison]::Ordinal); if ($x -lt 0) { $o2++ } else { $p2 = $x + $c.Length } }
                            $dead = ($o2 -gt 0); $why = 'ordine diverso (' + $o2 + ')'
                        } elseif ($mu.Kill -eq 'dots') {
                            $dead = ($inf.Dots.Count -lt 3); $why = 'pallino verde assente'
                        } elseif ($mu.Kill -eq 'dups') {
                            $d2 = 0; foreach ($i in @($multi.Keys)) { $w3 = if (([string]$codes[$i]).Trim() -eq $multi[$i]) { 2 } else { 1 }; if (([regex]::Matches($t2, [regex]::Escape($multi[$i]))).Count -ne $w3) { $d2++ } }; foreach ($i in $eanIds) { $w2 = if (([string]$codes[$i]).Trim() -eq $eans[$i]) { 2 } else { 1 }; if (([regex]::Matches($t2, [regex]::Escape($eans[$i]))).Count -ne $w2) { $d2++ } }
                            $dead = ($d2 -gt 0); $why = 'articoli ripetuti (' + $d2 + ')'
                        }
                    }
                }
                if ($dead) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $why + ')') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }

    # nota: togliere la guardia IsRequestBeingRedirected non e osservabile via HTTP (senza viewstate il clic non viene nemmeno consegnato, con viewstate di altri la
    # validazione MAC fallisce prima): la guardia e difesa in profondita, coperta dal pin statico qui sotto.
    # pin statici (testo del codice)
    $pageText = if ($null -ne $repoBytes['listino-catalogo.aspx.vb']) { Get-Text $repoBytes['listino-catalogo.aspx.vb'] } else { '' }
    $snapText = if ($null -ne $repoBytes['App_Code\KeepStoreCatalogExportSnapshot.vb']) { Get-Text $repoBytes['App_Code\KeepStoreCatalogExportSnapshot.vb'] } else { '' }
    $iRej = $pageText.IndexOf('If Response.IsRequestBeingRedirected Then Return'); $iGen = $pageText.IndexOf('CatalogExportSnapshotProvider.LoadCurrent')
    Check ($iRej -ge 0 -and $iGen -gt $iRej) 'pin: il rifiuto CSRF precede ogni generazione'
    Check ($pageText.Contains('SemaphoreSlim') -and $pageText.Contains('ActiveUsers')) 'pin: limite globale e un file alla volta per utente'
    $sqlOnly = [regex]::Match($snapText, '(?s)Friend Const ListingSql.*?Public Shared Function LoadCurrent').Value
    Check ($sqlOnly -ne '' -and $sqlOnly -notmatch 'PrezzoPromo|InOfferta') 'pin: nessuna colonna promo della vista nella lettura (solo il batch)'
    $cat = Get-Text ([IO.File]::ReadAllBytes((Join-Path $root 'articoli.aspx.vb')))
    $rank = [regex]::Match($cat, '(?s)Private Shared Function BuildCatalogRowRankSql\(\) As String(.*?)End Function').Groups[1].Value
    $rank = (($rank -split "`n") | Where-Object { $_.Trim() -notmatch "^'" }) -join ' '
    $rankNorm = ($rank -replace 'vsuperarticoli\.', 'v.' -replace '[\s"&_]', '')
    $mineNorm = ([regex]::Match($snapText, '(?s)Friend Const RowRankSql As String =(.*?)Friend Const ListingSql').Groups[1].Value -replace '[\s"&_]', '')
    $rankNorm = ($rankNorm -replace '^Return', '')
    if ($rankNorm.Length -le 40 -or -not $mineNorm.Contains($rankNorm)) { Write-Host ('    catalogo: ' + $rankNorm); Write-Host ('    nuovo:    ' + $mineNorm) }
    Check ($rankNorm.Length -gt 40 -and $mineNorm.Contains($rankNorm.Replace('ASCatalogRowRank', 'ASCatalogRowRank'))) 'pin: stessa regola ROW_NUMBER del catalogo'
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { foreach ($c in @($copied)) { if (Test-Path -LiteralPath $c) { Remove-Item -LiteralPath $c -Force } } } catch { Write-Host '  ATTENZIONE: file di prova non rimossi' }
    try { $th = Join-Path $SitePath 'App_Data\CatalogExportThumbs'; if (Test-Path -LiteralPath $th) { Remove-Item -LiteralPath $th -Recurse -Force } } catch { }
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'CATALOG_PDF PASS' } else { Write-Host 'CATALOG_PDF FAIL' }
exit $exit
