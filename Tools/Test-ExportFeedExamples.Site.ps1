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

# --- oracolo INDIPENDENTE dal motore (scritto qui, non ne usa il codice) ---
function Gs1-Valid([string]$raw) {
    $s = $raw.Trim()
    if ($s -notmatch '^(\d{8}|\d{12}|\d{13}|\d{14})$') { return '' }
    if ($s -match '^0+$') { return '' }
    $d = @($s.ToCharArray() | ForEach-Object { [int][string]$_ })
    $n = $d.Count; $sum = 0
    for ($k = 0; $k -lt $n - 1; $k++) { $w = 1; if ((($n - 1 - $k) % 2) -eq 1) { $w = 3 }; $sum += $d[$k] * $w }
    if (((10 - ($sum % 10)) % 10) -ne $d[$n - 1]) { return '' }
    if ($n -gt 8) {
        $e13 = $s; if ($n -eq 12) { $e13 = '0' + $s }; if ($n -eq 14) { $e13 = $s.Substring(1) }
        if ($e13 -match '^(02|04|98|99|2)') { return '' }
    }
    return $s
}
function Title-Norm([string]$t) {
    $t = Clean $t
    if ($t -eq '' -or $t -cmatch '\p{Ll}') { return $t }
    $words = $t.Split(' ')
    for ($i = 0; $i -lt $words.Count; $i++) {
        $w = $words[$i]
        if ($w.Length -gt 0 -and $w -notmatch '\d') { $words[$i] = $w.Substring(0, 1).ToUpperInvariant() + $w.Substring(1).ToLowerInvariant() }
    }
    return ($words -join ' ')
}
function Get-RowsRange([string]$template, [int]$maxId) {
    $all = New-Object Collections.Generic.List[object]
    for ($lo = 0; $lo -le $maxId; $lo += 1000) { $hi = $lo + 999; foreach ($r in @(Get-Rows ($template.Replace('{RANGE}', ('BETWEEN ' + $lo + ' AND ' + $hi))))) { $all.Add($r) } }
    return $all.ToArray()
}

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
    $o = Invoke-Sql $blocks['campi'] -Write
    Check (($o -join "`n") -match 'EXPORT_FEED_CAMPI_OK') 'D0 i quattro campi sono registrati per la prova HTTP'
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
    $ora = @(Get-Rows ('SELECT v.id AS id, IFNULL(v.Descrizione1, '''') AS t, IFNULL(v.MarcheDescrizione, '''') AS b, IFNULL(v.Ean, '''') AS e, IFNULL(v.Codice, '''') AS c, v.PrezzoIvato AS p, IFNULL(v.Img1, '''') AS i, COALESCE(v.Ricondizionato, 0) AS rc FROM vsuperarticoli v INNER JOIN articoli a ON a.id = v.id WHERE v.NListino = ' + $c1.Listino + ' AND COALESCE(v.Export, 0) = 1 AND COALESCE(a.Abilitato, 0) = 1 AND v.Giacenza >= 1 AND TRIM(COALESCE(v.Img1, '''')) <> '''' AND COALESCE(v.PrezzoIvato, 0) > 0;'))
    # Le immagini dei prodotti stanno sul server vero, non sul sito LAB: si creano file segnaposto (1 byte) per i primi 800 articoli con un nome di file semplice;
    # il motore scarta gli articoli la cui immagine non esiste (come sul server), quindi l'insieme atteso e quello degli articoli con file segnaposto o con indirizzo http/https.
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

    # oracolo dei prezzi del sito per un cliente anonimo (listino dell'azienda, IVA inclusa, offerta per 1 pezzo valida oggi): stessa logica di Test-ExportFeedEngine.ps1, per questa azienda e questo listino
    $L = [int]$c1.Listino; $C = [int]$c1.Id
    $maxArt = [int](Get-Scalar 'SELECT MAX(id) AS ksval FROM articoli;')
    $baseRows = @(Get-RowsRange ('SELECT al.ArticoliId AS id, al.Prezzo AS net, al.PrezzoIvato AS gross, IFNULL(al.TCid,-1) AS tc FROM articoli_listini al WHERE al.NListino=' + $L + ' AND al.ArticoliId {RANGE} AND (SELECT COUNT(*) FROM articoli_listini x WHERE x.ArticoliId=al.ArticoliId AND x.NListino=' + $L + ')=1;') $maxArt)
    $baseMap = @{}; foreach ($b in $baseRows) { $baseMap[$b['id']] = @{ net = (Dec $b['net']); gross = (Dec $b['gross']); tc = [int]$b['tc'] } }
    $offRows = @(Get-RowsRange ('SELECT va.id AS aid, o.Prezzo AS oprice, o.Sconto AS osc, IFNULL(od.TCId,-1) AS otc FROM voffertearticoli va JOIN offerte o ON o.id=va.OfferteID JOIN offertedettaglio od ON od.id=va.OfferteDettagliId AND od.OfferteId=o.id JOIN articoli a ON a.id=va.id ' +
        'WHERE o.AziendeId=' + $C + ' AND o.Abilitato=1 AND a.Abilitato=1 AND COALESCE(a.NoPromo,0)=0 AND o.DataInizio<=CURDATE() AND o.DataFine>=CURDATE() AND COALESCE(o.UtentiId,0)<=0 ' +
        'AND NOT (COALESCE(o.QntMinima,0)>0 AND COALESCE(o.Multipli,0)>0) AND ((COALESCE(o.QntMinima,0)>0 AND o.QntMinima<=1) OR (COALESCE(o.QntMinima,0)<=0 AND o.Multipli=1)) ' +
        'AND (COALESCE(o.DaListino,0)<=0 OR o.DaListino<=' + $L + ') AND (COALESCE(o.AListino,0)<=0 OR o.AListino>=' + $L + ') AND va.id {RANGE};') $maxArt)
    $offMap = @{}; foreach ($of in $offRows) { if (-not $offMap.ContainsKey($of['aid'])) { $offMap[$of['aid']] = New-Object Collections.Generic.List[object] }; $offMap[$of['aid']].Add($of) }
    function Expected-Price([string]$artId) {
        if (-not $baseMap.ContainsKey($artId)) { return $null }
        $net = $baseMap[$artId].net; $gross = $baseMap[$artId].gross
        $bestNet = $null; $bestExact = $null; $tc = $baseMap[$artId].tc
        if ($offMap.ContainsKey($artId) -and $net -gt 0 -and $gross -gt 0) {
            foreach ($of in $offMap[$artId]) {
                $otc = [int]$of['otc']
                if ($otc -gt 0 -and $otc -ne $tc) { continue }
                $p = Dec $of['oprice']; $sc = Dec $of['osc']
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
        if ($null -ne $bestNet) { return (Money ($bestNet * ($gross / $net))) }
        return (Money $gross)
    }
    $withOffer = @($oraMap.Keys | Where-Object { $offMap.ContainsKey($_) }).Count
    Check ($withOffer -gt 0) ('D1 oracolo prezzi: articoli del feed con un offerta valida oggi (' + $withOffer + ')')

    $defs = @(
        @{ Name = 'ESEMPIO Google Merchant'; Sep = "`t"; Csv = $false; IdCol = 0 },
        @{ Name = 'ESEMPIO Trovaprezzi 7Pixel'; Sep = '|'; Csv = $false; IdCol = 4 },
        @{ Name = 'ESEMPIO idealo'; Sep = ','; Csv = $true; IdCol = 0 }
    )
    $badBrands = @('n/a', 'generic', 'no brand', 'does not exist')
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
        $bad = 0; $ids = @{}; $valErr = New-Object Collections.Generic.List[string]; $ruleErr = New-Object Collections.Generic.List[string]
        $descBad = 0; $shipOk = 0; $shipN = 0; $gtinFile = 0; $gtinExp = 0; $skipTitle = 0; $quoteStart = 0; $priceChecked = 0
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $f = if ($d.Csv) { @(Parse-Csv $lines[$i] $d.Sep) } else { @($lines[$i].Split($d.Sep)) }
            if ($f.Count -ne $titles.Count) { $bad++; continue }
            $id = $f[$d.IdCol]
            if ($ids.ContainsKey($id)) { $valErr.Add('id doppio ' + $id) }
            $ids[$id] = $true
            if (-not $d.Csv) { foreach ($v in $f) { if ($v.StartsWith('"')) { $quoteStart++ } } }
            if (-not $oraMap.ContainsKey($id)) { continue }
            $a = $oraMap[$id]
            $tRaw = Clean (Unesc $a['t']); $br = Clean (Unesc $a['b']); $ean = (Unesc $a['e']).Trim(); $cod = Clean (Unesc $a['c'])
            # il titolo si confronta sempre, tranne quando e tutto maiuscolo E ha caratteri non ASCII: li la normalizzazione dipende da lettere che la console altera
            $nonAscii = (($tRaw -match '[^\x20-\x7E]|\?') -and ($tRaw -cnotmatch '[a-z]'))
            if ($nonAscii) { $skipTitle++ }
            $gx = Gs1-Valid $ean
            if ($gx -ne '') { $gtinExp++ }
            $expP = Expected-Price $id
            $link = 'https://www.taikun.it/articolo.aspx?id=' + $id
            $col = @{}; for ($k = 0; $k -lt $titles.Count; $k++) { $col[$titles[$k]] = $f[$k] }
            $priceKey = ''; $descVal = ''
            switch ($d.Name) {
                'ESEMPIO Google Merchant' {
                    $tn = Title-Norm $tRaw
                    if (-not $nonAscii) { if (-not (Same-Text $col['title'] $tn 150)) { $valErr.Add('title ' + $id) } }
                    if (-not (Same-Text $col['brand'] $br 70)) { $valErr.Add('brand ' + $id) }
                    if ($col['gtin'] -ne $gx) { $valErr.Add('gtin ' + $id) }
                    if ($col['gtin'] -ne '') { $gtinFile++ }
                    if (-not (Same-Text $col['mpn'] $cod 70)) { $valErr.Add('mpn ' + $id) }
                    if ($col['link'] -ne $link) { $valErr.Add('link ' + $id) }
                    $expCond = 'new'; if ($a['rc'] -eq '1') { $expCond = 'refurbished' }
                    if ($col['condition'] -ne $expCond) { $valErr.Add('condition ' + $id) }
                    if ($col['availability'] -ne 'in_stock') { $valErr.Add('availability ' + $id) }
                    if ($null -ne $expP) { $priceChecked++; if ($col['price'] -ne ($expP + ' EUR')) { $valErr.Add('price ' + $id + ' ' + $col['price'] + ' <> ' + $expP) } }
                    # regole Google riga per riga
                    if ($id.Length -gt 50) { $ruleErr.Add('id oltre 50 ' + $id) }
                    if ($col['title'].Trim() -eq '' -or $col['title'].Length -gt 150) { $ruleErr.Add('title vuoto o oltre 150 ' + $id) }
                    if ($col['description'].Length -gt 5000 -or $col['description'].Trim() -eq '') { $ruleErr.Add('description vuota o oltre 5000 ' + $id) }
                    if ($col['link'] -notmatch '^https://' -or $col['image_link'] -notmatch '^https://') { $ruleErr.Add('link non https ' + $id) }
                    if ($col['price'] -notmatch '^\d+\.\d\d EUR$' -or (Dec ($col['price'] -replace ' EUR$', '')) -le 0) { $ruleErr.Add('price formato o zero ' + $id) }
                    if (@('in_stock', 'out_of_stock', 'preorder', 'backorder') -notcontains $col['availability']) { $ruleErr.Add('availability ' + $id) }
                    if (@('new', 'refurbished', 'used') -notcontains $col['condition']) { $ruleErr.Add('condition ' + $id) }
                    if ($col['brand'].Trim() -eq '' -or $col['brand'].Length -gt 70 -or $badBrands -contains $col['brand'].ToLowerInvariant()) { $ruleErr.Add('brand ' + $id) }
                    if ($col['gtin'] -ne '' -and (Gs1-Valid $col['gtin']) -eq '') { $ruleErr.Add('gtin non valido ' + $id) }
                    if ($col['mpn'].Length -gt 70 -or $col['product_type'].Length -gt 750) { $ruleErr.Add('mpn o product_type troppo lunghi ' + $id) }
                    if ($col['shipping'] -ne '') { $shipN++; if ($col['shipping'] -match '^IT::Standard:\d+\.\d\d EUR$') { $shipOk++ } }
                    $descVal = $col['description']
                }
                'ESEMPIO Trovaprezzi 7Pixel' {
                    $tx = $tRaw.Replace('|', ' ')
                    if (-not $nonAscii) { if (-not (Same-Text $col['Nome'] $tx 0)) { $valErr.Add('Nome ' + $id) } }
                    if (-not (Same-Text $col['Marca'] $br.Replace('|', ' ') 0)) { $valErr.Add('Marca ' + $id) }
                    if ($col['EAN'] -ne $gx) { $valErr.Add('EAN ' + $id) }
                    if ($col['EAN'] -ne '') { $gtinFile++ }
                    if (-not (Same-Text $col['Codice produttore'] $cod 0)) { $valErr.Add('Codice produttore ' + $id) }
                    if ($col['Link'] -ne $link) { $valErr.Add('Link ' + $id) }
                    if ($col['Disponibilita'] -ne 'Disponibile') { $valErr.Add('Disponibilita ' + $id) }
                    if ($null -ne $expP) { $priceChecked++; if ($col['Prezzo'] -ne $expP) { $valErr.Add('Prezzo ' + $id + ' ' + $col['Prezzo'] + ' <> ' + $expP) } }
                    if ($col['Spese di spedizione'] -ne '') { $shipN++; if ($col['Spese di spedizione'] -match '^\d+\.\d\d$') { $shipOk++ } }
                    $descVal = $col['Descrizione']
                }
                'ESEMPIO idealo' {
                    if (-not $nonAscii) { if (-not (Same-Text $col['title'] $tRaw 0)) { $valErr.Add('title ' + $id) } }
                    if (-not (Same-Text $col['brand'] $br 0)) { $valErr.Add('brand ' + $id) }
                    if ($col['eans'] -ne $gx) { $valErr.Add('eans ' + $id) }
                    if ($col['eans'] -ne '') { $gtinFile++ }
                    if (-not (Same-Text $col['hans'] $cod 0)) { $valErr.Add('hans ' + $id) }
                    if ($col['url'] -ne $link) { $valErr.Add('url ' + $id) }
                    if ($col['sku'] -ne $id) { $valErr.Add('sku ' + $id) }
                    if ($null -ne $expP) { $priceChecked++; if ($col['price'] -ne $expP) { $valErr.Add('price ' + $id + ' ' + $col['price'] + ' <> ' + $expP) } }
                    if ($col['delivery'] -ne '3 giorni lavorativi') { $valErr.Add('delivery ' + $id) }
                    if ($col['deliveryCosts_dhl'] -ne '') { $shipN++; if ($col['deliveryCosts_dhl'] -match '^\d+\.\d\d$') { $shipOk++ } }
                    $descVal = $col['description']
                }
            }
            if ($descVal.Trim() -eq '' -or $descVal -match '</?[A-Za-z]' -or $descVal -match '&(amp|lt|gt|nbsp|quot|euro);') { $descBad++ }
        }
        Check ($bad -eq 0) ('D4 ' + $d.Name + ': stesso numero di campi in ogni riga (righe con campi diversi: ' + $bad + ')')
        $missing = @($oraMap.Keys | Where-Object { -not $ids.ContainsKey($_) }).Count
        $extra = @($ids.Keys | Where-Object { -not $oraMap.ContainsKey($_) }).Count
        Check ($missing -eq 0 -and $extra -eq 0 -and $ids.Count -eq $oraMap.Count) ('D5 ' + $d.Name + ': insieme esatto degli id (file ' + $ids.Count + ', attesi ' + $oraMap.Count + ', mancanti ' + $missing + ', in piu ' + $extra + ')')
        Check ($valErr.Count -eq 0) ('D6 ' + $d.Name + ': valori per id e colonna uguali all oracolo (errori ' + $valErr.Count + ' ' + (($valErr | Select-Object -First 3) -join ' ; ') + ')')
        Check ($priceChecked -eq $oraMap.Count) ('D6 ' + $d.Name + ': prezzo controllato per ogni articolo, offerte comprese (' + $priceChecked + ' su ' + $oraMap.Count + ')')
        Check ($descBad -eq 0) ('D6 ' + $d.Name + ': descrizione mai vuota e senza tag ne entita (difetti ' + $descBad + ')')
        Check ($shipN -gt 0 -and $shipOk -eq $shipN) ('D6 ' + $d.Name + ': spese di spedizione scritte con il formato giusto (scritte ' + $shipN + ', formato giusto ' + $shipOk + ')')
        Check ($gtinExp -gt 100 -and $gtinFile -eq $gtinExp) ('D6 ' + $d.Name + ': GTIN scritti = GTIN validi attesi (' + $gtinFile + ' su ' + $gtinExp + ' calcolati a parte)')
        Check ($quoteStart -eq 0) ('D6 ' + $d.Name + ': nessun valore inizia con virgolette (' + $quoteStart + ')')
        Check ($skipTitle -lt ($oraMap.Count / 20)) ('D6 ' + $d.Name + ': titoli tutto maiuscolo con caratteri non ASCII esclusi dal confronto del titolo: pochi (' + $skipTitle + ')')
        if ($d.Name -eq 'ESEMPIO Google Merchant') { Check ($ruleErr.Count -eq 0) ('D8 regole Google riga per riga (violazioni ' + $ruleErr.Count + ' ' + (($ruleErr | Select-Object -First 3) -join ' ; ') + ')') }
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
