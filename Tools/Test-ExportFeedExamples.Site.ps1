# (D) di Test-ExportFeedExamples.ps1: prova HTTP sul sito LAB. Non si lancia da solo: lo include il test principale (usa le sue funzioni e variabili).
# Un solo uso del sito LAB alla volta (mutex Global\KeepStoreLabSite18843). Solo ASCII (Windows PowerShell 5.1).

$base = 'https://www.taikun.it:18843'
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { throw 'IL_SITO_DI_PROVA_DEVE_ESSERE_QUELLO_DEL_LAB' }
$folder = Join-Path $SitePath 'Public\assets\images\export'
$siteFiles = @('feed.aspx', 'feed.aspx.vb', 'App_Code\KeepStoreFeedEngine.vb', 'App_Code\KeepStoreFeedService.vb', 'export.aspx.vb')
$orig = @{}
foreach ($rel in $siteFiles) { $p = Join-Path $SitePath $rel; $orig[$rel] = if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllBytes($p) } else { $null } }
$folderPreexisted = Test-Path -LiteralPath $folder

function Get-Url([string]$pathQuery) {
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.bin')
    $a = @('--noproxy', '*', '-s', '--max-time', '180', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}', ($base + $pathQuery))
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 2 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $headers = @{}
    if (Test-Path -LiteralPath $hdr) { foreach ($l in ([IO.File]::ReadAllText($hdr) -split "`r?`n")) { $ix = $l.IndexOf(':'); if ($ix -gt 0) { $headers[$l.Substring(0, $ix).Trim().ToLowerInvariant()] = $l.Substring($ix + 1).Trim() } } }
    [byte[]]$bytes = @()
    if (Test-Path -LiteralPath $out) { $bytes = [IO.File]::ReadAllBytes($out) }
    Remove-Item -LiteralPath $hdr, $out -Force -ErrorAction SilentlyContinue
    return @{ Status = [int]$parts[0]; Headers = $headers; Bytes = $bytes; Body = $utf8.GetString($bytes) }
}
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 80; $i++) {
        $st = 0; try { $st = (Get-Url ('/feed.aspx?c=' + ('0' * 48))).Status } catch { $st = 0 }
        if ($st -eq 404) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Reset-App { (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date; Start-Sleep -Seconds 6; Wait-Site }
function Deploy-Repo { foreach ($rel in $siteFiles) { [IO.File]::WriteAllBytes((Join-Path $SitePath $rel), [IO.File]::ReadAllBytes((Join-Path $root $rel))) }; Start-Sleep -Seconds 3 }
function Restore-Site {
    foreach ($rel in $siteFiles) { $p = Join-Path $SitePath $rel; if ($null -ne $orig[$rel]) { [IO.File]::WriteAllBytes($p, $orig[$rel]) } elseif (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
}
function Unesc([string]$s) { return ([regex]::Replace($s, '\\(.)', { param($m) switch ($m.Groups[1].Value) { 't' { ' ' } 'n' { ' ' } 'r' { ' ' } '0' { '' } default { $m.Groups[1].Value } } })) }
function Clean([string]$s) { return ([regex]::Replace($s, '\s+', ' ')).Trim() }
# Il testo dell'oracolo passa dal client mysql e dalla console: i caratteri non ASCII (virgolette tipografiche, TM) arrivano alterati. Il confronto avviene sul solo ASCII;
# se il titolo originale supera il massimo, il file deve essere un prefisso del titolo atteso (il motore tronca sui caratteri veri).
function Ascii([string]$s) { return Clean ([regex]::Replace($s, '[^\x20-\x7E]|\?', '')) }   # anche il '?': senza console reale i caratteri non ASCII arrivano come punti interrogativi
function Same-Text([string]$file, [string]$oracle, [int]$max) {
    $f = Ascii $file; $o = Ascii $oracle
    if ($max -gt 0 -and $oracle.Length -gt $max) { return ($o.StartsWith($f.TrimEnd())) }
    return ($f -eq $o)
}
function Parse-Csv([string]$line, [string]$sep) {
    $res = New-Object Collections.Generic.List[string]; $sb = New-Object Text.StringBuilder; $q = $false; $i = 0
    while ($i -lt $line.Length) {
        $ch = $line[$i]
        if ($q) {
            if ($ch -eq '"') { if ($i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') { [void]$sb.Append('"'); $i++ } else { $q = $false } } else { [void]$sb.Append($ch) }
        } else {
            if ($ch -eq '"') { $q = $true } elseif ($ch.ToString() -eq $sep) { $res.Add($sb.ToString()); [void]$sb.Clear() } else { [void]$sb.Append($ch) }
        }
        $i++
    }
    $res.Add($sb.ToString())
    return ,$res.ToArray()
}

$script:cur = New-Object Collections.Generic.List[string]
try { $siteHeld = $siteMutex.WaitOne(1800000) } catch [System.Threading.AbandonedMutexException] { $siteHeld = $true }
if (-not $siteHeld) { throw 'LAB_SITE_BUSY' }
$siteTouched = $false
try {
    if ($folderPreexisted) { throw 'FEED_FOLDER_ALREADY_ON_SITE' }
    Clean-Lab
    $companies = @(Eligible-Companies)
    $c1 = @($companies | Where-Object { $_.Dominio -eq 'www.taikun.it' })
    if ($c1.Count -ne 1) { throw 'AZIENDA_DEL_SITO_LAB_NON_IDONEA' }
    $c1 = $c1[0]
    $o = Invoke-Sql $blocks['esempi'] -Write
    Check (($o -join "`n") -match 'EXPORT_FEED_ESEMPI_OK') 'D0 gli esempi sono stati creati per la prova HTTP'
    $carrier = Get-Scalar 'SELECT VettoriId AS ksval FROM vettoricosti GROUP BY VettoriId ORDER BY COUNT(*) DESC LIMIT 1;'
    $null = Invoke-Sql ('UPDATE export SET Abilitato = 1, IdVettore = ' + $carrier + ', GiorniSpedizione = 3 WHERE Descrizione LIKE ''ESEMPIO % (azienda ' + $c1.Id + ')'';') -Write
    $tok = @{}
    foreach ($row in @(Get-Rows ("SELECT e.Descrizione AS d, o.TokenAccesso AS t FROM export e JOIN export_opzioni o ON o.ExportId = e.ID WHERE e.Descrizione LIKE 'ESEMPIO % (azienda " + $c1.Id + ")';"))) { $tok[$row['d']] = $row['t'] }
    Check ($tok.Count -eq 3) 'D0 tre esempi abilitati per l azienda del sito LAB'

    # sito: file del repository, cartella con il permesso del pool (come sul server)
    $siteTouched = $true
    Deploy-Repo
    New-Item -ItemType Directory -Path $folder | Out-Null
    $null = & icacls.exe $folder /grant ('IIS APPPOOL\KeepStoreRegOrderLabPool-20261025:(OI)(CI)M') 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'ICACLS_FAILED' }
    Reset-App

    # oracolo: articoli del listino con le stesse regole del feed (esportabile, abilitato, giacenza >= 1, prima immagine, prezzo > 0)
    $ora = @(Get-Rows ('SELECT v.id AS id, IFNULL(v.Descrizione1, '''') AS t, IFNULL(v.MarcheDescrizione, '''') AS b, IFNULL(v.Ean, '''') AS e, IFNULL(v.Codice, '''') AS c, v.PrezzoIvato AS p, IFNULL(v.Img1, '''') AS i, (SELECT COUNT(*) FROM voffertearticoli va WHERE va.id = v.id) AS o FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE v.NListino = ' + $c1.Listino + ' AND COALESCE(v.Export, 0) = 1 AND COALESCE(a.Abilitato, 0) = 1 AND v.Giacenza >= 1 AND TRIM(COALESCE(v.Img1, '''')) <> '''' AND COALESCE(v.PrezzoIvato, 0) > 0;'))
    # Le immagini dei prodotti stanno sul server vero, non sul sito LAB: per l'oracolo si creano file segnaposto (1 byte) per i primi 800 articoli con un nome di file semplice;
    # il motore scarta gli articoli la cui immagine non esiste (come sul server), quindi l'insieme atteso e quello degli articoli con file segnaposto o con indirizzo https/http.
    $imgDir = Join-Path $SitePath 'Public\assets\images\articoli'
    if (-not (Test-Path -LiteralPath $imgDir)) { New-Item -ItemType Directory -Path $imgDir | Out-Null; $imgDirCreated = $true } else { $imgDirCreated = $false }
    $created = New-Object Collections.Generic.List[string]; $nMade = 0
    $oraMap = @{}
    foreach ($x in $ora) {
        # una riga dell'oracolo spezzata da un a-capo dentro un titolo (la console la divide) non ha un id numerico: si scarta, non e un articolo
        if ($x['id'] -notmatch '^[0-9]+$') { continue }
        $raw = Unesc $x['i']; $raw = $raw.Trim()
        if ($raw -match '^https?://[^\s"''<>`]+$') { $oraMap[$x['id']] = $x; continue }
        if ($raw -notmatch '^[A-Za-z0-9_.\-]+$' -or $raw.Contains('..')) { continue }
        $fp = Join-Path $imgDir $raw
        if (Test-Path -LiteralPath $fp) { $oraMap[$x['id']] = $x; continue }
        if ($nMade -lt 800) { [IO.File]::WriteAllBytes($fp, [byte[]]@(0)); $created.Add($fp); $nMade++; $oraMap[$x['id']] = $x }
    }
    Check ($oraMap.Count -gt 300) ('D1 oracolo: articoli attesi nel feed (' + $oraMap.Count + ' con immagine su ' + $ora.Count + ' del listino)')

    $defs = @(
        @{ Name = 'ESEMPIO Google Merchant'; Sep = "`t"; Csv = $false; IdCol = 0; Price = 6; Dec = '.' },
        @{ Name = 'ESEMPIO Trovaprezzi 7Pixel'; Sep = '|'; Csv = $false; IdCol = 4; Price = 3; Dec = '.' },
        @{ Name = 'ESEMPIO idealo'; Sep = ','; Csv = $true; IdCol = 0; Price = 8; Dec = '.' }
    )
    foreach ($d in $defs) {
        $nm = $d.Name + ' (azienda ' + $c1.Id + ')'
        $e = $exp[$d.Name]
        $resp = Get-Url ('/feed.aspx?c=' + $tok[$nm])
        for ($t = 0; $t -lt 6 -and $resp.Status -eq 503; $t++) { Start-Sleep -Seconds 5; $resp = Get-Url ('/feed.aspx?c=' + $tok[$nm]) }
        Check ($resp.Status -eq 200) ('D2 ' + $d.Name + ': risposta 200 (vista ' + $resp.Status + ')')
        if ($resp.Status -ne 200) { Write-Host ('  diag ' + $resp.Body.Substring(0, [Math]::Min(120, $resp.Body.Length))); continue }
        Check ($resp.Headers['content-type'] -match 'charset=utf-8') ('D2 ' + $d.Name + ': tipo di contenuto con codifica utf-8 (' + $resp.Headers['content-type'] + ')')
        Check ($resp.Bytes.Length -lt 3 -or -not ($resp.Bytes[0] -eq 0xEF -and $resp.Bytes[1] -eq 0xBB)) ('D2 ' + $d.Name + ': UTF-8 senza BOM')
        $lines = @($resp.Body -split "`r?`n" | Where-Object { $_ -ne '' })
        $titles = @($e.Cols | ForEach-Object { (Col-Line $_)[0] })
        $head = if ($d.Csv) { @(Parse-Csv $lines[0] $d.Sep) } else { @($lines[0].Split($d.Sep)) }
        Check (($head -join '~') -eq ($titles -join '~')) ('D3 ' + $d.Name + ': intestazione esatta e in ordine (' + ($head -join ',') + ')')
        $bad = 0; $ids = @{}; $valErr = New-Object Collections.Generic.List[string]; $descEmpty = 0; $shipOk = 0; $shipN = 0
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $f = if ($d.Csv) { @(Parse-Csv $lines[$i] $d.Sep) } else { @($lines[$i].Split($d.Sep)) }
            if ($f.Count -ne $titles.Count) { $bad++; continue }
            $id = $f[$d.IdCol]
            if ($ids.ContainsKey($id)) { $valErr.Add('id doppio ' + $id) }
            $ids[$id] = $true
            if (-not $oraMap.ContainsKey($id)) { continue }
            $a = $oraMap[$id]
            $t = Clean (Unesc $a['t']); $br = Clean (Unesc $a['b']); $ean = Clean (Unesc $a['e']); $cod = Clean (Unesc $a['c'])
            if ($d.Name -like '*Trovaprezzi*') { $t = $t.Replace('|', ' '); $br = $br.Replace('|', ' ') }
            $price = Money (Dec $a['p'])
            $link = 'https://www.taikun.it/articolo.aspx?id=' + $id
            $col = @{}; for ($k = 0; $k -lt $titles.Count; $k++) { $col[$titles[$k]] = $f[$k] }
            switch ($d.Name) {
                'ESEMPIO Google Merchant' {
                    if (-not (Same-Text $col['title'] $t 150)) { $valErr.Add('title ' + $id) }
                    if (-not (Same-Text $col['brand'] $br 0)) { $valErr.Add('brand ' + $id) }
                    if ($col['gtin'] -ne $ean) { $valErr.Add('gtin ' + $id) }
                    if ($col['link'] -ne $link) { $valErr.Add('link ' + $id) }
                    if ($col['availability'] -ne 'in_stock') { $valErr.Add('availability ' + $id) }
                    if ($a['o'] -eq '0' -and $col['price'] -ne ($price + ' EUR')) { $valErr.Add('price ' + $id + ' ' + $col['price'] + ' <> ' + $price) }
                    if ($col['price'] -notmatch '^\d+\.\d\d EUR$') { $valErr.Add('formato price ' + $id) }
                    if ($col['image_link'] -notmatch '^https://') { $valErr.Add('image_link ' + $id) }
                    if ($col['description'].Trim() -eq '') { $descEmpty++ }
                    if ($col['shipping'] -ne '') { $shipN++; if ($col['shipping'] -match '^IT::Standard:\d+\.\d\d EUR$') { $shipOk++ } }
                }
                'ESEMPIO Trovaprezzi 7Pixel' {
                    if (-not (Same-Text $col['Nome'] $t 0)) { $valErr.Add('Nome ' + $id) }
                    if (-not (Same-Text $col['Marca'] $br 0)) { $valErr.Add('Marca ' + $id) }
                    if ($col['EAN'] -ne $ean) { $valErr.Add('EAN ' + $id) }
                    if ($col['Codice produttore'] -ne $cod) { $valErr.Add('Codice produttore ' + $id) }
                    if ($col['Link'] -ne $link) { $valErr.Add('Link ' + $id) }
                    if ($col['Disponibilita'] -ne 'Disponibile') { $valErr.Add('Disponibilita ' + $id) }
                    if ($a['o'] -eq '0' -and $col['Prezzo'] -ne $price) { $valErr.Add('Prezzo ' + $id + ' ' + $col['Prezzo'] + ' <> ' + $price) }
                    if ($col['Descrizione'].Trim() -eq '') { $descEmpty++ }
                    if ($col['Spese di spedizione'] -ne '') { $shipN++; if ($col['Spese di spedizione'] -match '^\d+\.\d\d$') { $shipOk++ } }
                }
                'ESEMPIO idealo' {
                    if (-not (Same-Text $col['title'] $t 0)) { $valErr.Add('title ' + $id) }
                    if (-not (Same-Text $col['brand'] $br 0)) { $valErr.Add('brand ' + $id) }
                    if ($col['eans'] -ne $ean) { $valErr.Add('eans ' + $id) }
                    if ($col['hans'] -ne $cod) { $valErr.Add('hans ' + $id) }
                    if ($col['url'] -ne $link) { $valErr.Add('url ' + $id) }
                    if ($col['sku'] -ne $id) { $valErr.Add('sku ' + $id) }
                    if ($a['o'] -eq '0' -and $col['price'] -ne $price) { $valErr.Add('price ' + $id + ' ' + $col['price'] + ' <> ' + $price) }
                    if ($col['delivery'] -ne '3 giorni lavorativi') { $valErr.Add('delivery ' + $id) }
                    if ($col['description'].Trim() -eq '') { $descEmpty++ }
                    if ($col['deliveryCosts_dhl'] -ne '') { $shipN++; if ($col['deliveryCosts_dhl'] -match '^\d+\.\d\d$') { $shipOk++ } }
                }
            }
        }
        Check ($bad -eq 0) ('D4 ' + $d.Name + ': stesso numero di campi in ogni riga (righe con campi diversi: ' + $bad + ')')
        $missing = @($oraMap.Keys | Where-Object { -not $ids.ContainsKey($_) }).Count
        $extra = @($ids.Keys | Where-Object { -not $oraMap.ContainsKey($_) }).Count
        Check ($missing -eq 0 -and $extra -eq 0 -and $ids.Count -eq $oraMap.Count) ('D5 ' + $d.Name + ': insieme esatto degli id (file ' + $ids.Count + ', attesi ' + $oraMap.Count + ', mancanti ' + $missing + ' ' + ((@($oraMap.Keys | Where-Object { -not $ids.ContainsKey($_) }) | Select-Object -First 5) -join ',') + ', in piu ' + $extra + ')')
        Check ($valErr.Count -eq 0) ('D6 ' + $d.Name + ': valori per id e colonna uguali all oracolo (errori ' + $valErr.Count + ' ' + (($valErr | Select-Object -First 3) -join ' ; ') + ')')
        Check ($descEmpty -eq 0) ('D6 ' + $d.Name + ': descrizione mai vuota (vuote ' + $descEmpty + ')')
        Check ($shipN -gt 0 -and $shipOk -eq $shipN) ('D6 ' + $d.Name + ': spese di spedizione scritte con il formato giusto (scritte ' + $shipN + ', formato giusto ' + $shipOk + ')')
    }

    # esempio disabilitato: 404
    $nmI = 'ESEMPIO idealo (azienda ' + $c1.Id + ')'
    $null = Invoke-Sql ('UPDATE export SET Abilitato = 0 WHERE Descrizione = ''' + $nmI + ''';') -Write
    Reset-App   # la configurazione dei feed resta in cache di processo 60 secondi: si riavvia l'applicazione prima di leggere lo stato nuovo
    $r404 = Get-Url ('/feed.aspx?c=' + $tok[$nmI])
    Check ($r404.Status -eq 404) ('D7 esempio disabilitato: 404 (visto ' + $r404.Status + ')')
} finally {
    $null = Invoke-Sql ('UPDATE export SET Abilitato = 0 WHERE Descrizione LIKE ''ESEMPIO %(azienda %)'';') -Write
    if (Test-Path variable:created) { foreach ($fp in $created) { Remove-Item -LiteralPath $fp -Force -ErrorAction SilentlyContinue } }
    if ((Test-Path variable:imgDirCreated) -and $imgDirCreated -and (Test-Path -LiteralPath $imgDir) -and @(Get-ChildItem -LiteralPath $imgDir).Count -eq 0) { Remove-Item -LiteralPath $imgDir -Force -ErrorAction SilentlyContinue }
    if ($siteTouched) {
        Restore-Site
        if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue }
        (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date
    }
    if ($siteHeld) { $siteMutex.ReleaseMutex() }
}
foreach ($x in $script:cur) { $fails.Add($x) }
