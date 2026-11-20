[CmdletBinding()]
param([switch]$SkipMutants, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CART-RECENT-PRICE-1A. Prezzi delle schede "Visti di recente" del carrello (richiesta del PO del 2026-11-20: "i prezzi ... sballano").
# Difetto: i prezzi letti dal database come numeri passavano da testo e da una regola pensata per il testo scritto a mano
# (un solo separatore seguito da tre cifre = migliaia): 35,502 diventava 35.502,00 e il netto 4,918 diventava 4918 (offerta a 0,00).
# Prova COMPORTAMENTALE sul percorso reale (sito LAB, https, 127.0.0.1, porta 18843, browser vero): prodotti visitati -> carrello ->
# riga del database -> scelta IVA -> offerta -> scheda. Ogni prezzo mostrato deve essere uguale a un calcolo indipendente fatto in SQL.
# (A) sorgente, (B) sito LAB con il file di lavoro, (C) mutazioni eseguite sul sito LAB (il file di lavoro viene rimesso alla fine).
# Il test copia carrello.aspx.vb della copia di lavoro nella cartella del sito LAB (solo quel file). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$it = [Globalization.CultureInfo]::GetCultureInfo('it-IT')
$repoFile = Join-Path $root 'carrello.aspx.vb'
$siteFile = Join-Path $SitePath 'carrello.aspx.vb'
$fail = New-Object Collections.Generic.List[string]

# ---------- (A) sorgente ----------
$repoBytes = [IO.File]::ReadAllBytes($repoFile)
$hasBom = ($repoBytes.Length -ge 3 -and $repoBytes[0] -eq 0xEF -and $repoBytes[1] -eq 0xBB -and $repoBytes[2] -eq 0xBF)
$source = (New-Object Text.UTF8Encoding($false)).GetString($repoBytes, $(if ($hasBom) { 3 } else { 0 }), $repoBytes.Length - $(if ($hasBom) { 3 } else { 0 }))
$i0 = $source.IndexOf('Private Function PrepareCartRecommendationRows(', [StringComparison]::Ordinal)
$i1 = if ($i0 -ge 0) { $source.IndexOf('End Function', $i0, [StringComparison]::Ordinal) } else { -1 }
$block = if ($i0 -ge 0 -and $i1 -gt $i0) { $source.Substring($i0, $i1 - $i0) } else { '' }
$netLine = 'If Not TryReadDatabaseDecimal(row("Prezzo"), net) Then Continue For'
$grossLine = 'If Not TryReadDatabaseDecimal(row("PrezzoIvato"), gross) Then gross = 0D'
if ($block -eq '') { $fail.Add('S00 funzione delle schede non trovata') }
if (-not $block.Contains($netLine) -or -not $block.Contains($grossLine)) { $fail.Add('S01 netto e lordo letti come numeri del database; scheda saltata se il netto non si legge, lordo illeggibile = zero') }
if ($block -match 'SafeDbl\(|ParseDecimalForDb\(|SafeMoney\(|SafeDblFromText\(') { $fail.Add('S02 nessuna conversione pensata per il testo sui prezzi delle schede') }
foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }
$sourceFailed = ($fail.Count -gt 0)

# ---------- (B) sito LAB ----------
if (-not (Test-Path -LiteralPath $siteFile)) { Write-Host ('CART_RECENT_PRICE FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
$must = @(15499, 21906)            # tre decimali nel lordo; tre decimali nel netto con un'offerta
$visit = @(15499, 16100, 19765, 21906, 20225)
$cardJs = "(function(){var o=[];var cs=document.querySelectorAll('.ks-rv-card');for(var i=0;i<cs.length;i++){var a=cs[i].querySelector('a.ks-rv-link'),p=cs[i].querySelector('.ks-rv-price');o.push({href:a?a.getAttribute('href'):'',price:p?p.textContent.replace(/\s+/g,' ').trim():''});}return JSON.stringify(o);})()"

function Write-SiteFile([string]$text) {
    $enc = New-Object Text.UTF8Encoding($hasBom)
    [IO.File]::WriteAllText($siteFile, $text, $enc)
}
function Get-Oracle([int[]]$ids, [string]$company, [string]$listino) {
    # prezzo atteso per chi non e collegato: lordo di listino, oppure lordo dell'offerta pubblica valida oggi che vale gia per un pezzo
    $offer = "SELECT GROUP_CONCAT(DISTINCT CAST(CASE WHEN COALESCE(o.Prezzo,0) > 0 THEN o.Prezzo ELSE v.Prezzo * (1 - COALESCE(o.Sconto,0) / 100) END AS DECIMAL(20,8)) SEPARATOR ';') " +
             "FROM voffertearticoli va JOIN offerte o ON o.id = va.OfferteID JOIN offertedettaglio od ON od.id = va.OfferteDettagliId AND od.OfferteId = o.id JOIN articoli a ON a.id = va.id " +
             "WHERE va.id = v.id AND o.AziendeId = $company AND COALESCE(o.Abilitato,0) = 1 AND COALESCE(a.Abilitato,0) = 1 AND COALESCE(a.NoPromo,0) = 0 " +
             "AND (COALESCE(o.DaListino,0) <= 0 OR o.DaListino <= $listino) AND (COALESCE(o.AListino,0) <= 0 OR o.AListino >= $listino) " +
             "AND (o.DataInizio IS NULL OR o.DataInizio <= NOW()) AND (o.DataFine IS NULL OR o.DataFine >= CURDATE()) AND COALESCE(o.UtentiId,0) <= 0 " +
             "AND COALESCE(od.TCId,-1) <= 0 AND ((COALESCE(o.QntMinima,0) > 0 AND o.QntMinima <= 1 AND COALESCE(o.Multipli,0) <= 0) OR (COALESCE(o.QntMinima,0) <= 0 AND COALESCE(o.Multipli,0) > 0 AND MOD(1, o.Multipli) = 0)) " +
             "AND EXISTS (SELECT 1 FROM articoli_listini al WHERE al.ArticoliId = va.id AND al.NListino = $listino) " +
             "AND (COALESCE(o.Prezzo,0) > 0 OR (COALESCE(o.Sconto,0) > 0 AND o.Sconto < 100))"
    $sql = "SELECT DISTINCT CONCAT('ksrow|', v.id, '|', v.Prezzo, '|', v.PrezzoIvato, '|', COALESCE(($offer), '')) AS r FROM vsuperarticoli v " +
           "WHERE v.id IN (" + ($ids -join ',') + ") AND v.NListino = $listino AND COALESCE(v.TCid,-1) <= 0;"
    $map = @{}
    foreach ($line in @(Invoke-Sql $sql)) {
        $mm = [regex]::Match([string]$line, '^ksrow\|(\d+)\|([0-9.]+)\|([0-9.]+)\|(.*)$'); if (-not $mm.Success) { continue }
        $id = [int]$mm.Groups[1].Value
        $net = [decimal]::Parse($mm.Groups[2].Value, $inv); $gross = [decimal]::Parse($mm.Groups[3].Value, $inv)
        $promos = @($mm.Groups[4].Value.Split(';') | Where-Object { $_ -ne '' } | ForEach-Object { [decimal]::Parse($_, $inv) } | Where-Object { $_ -gt 0 -and $_ -lt $net })
        if ($map.ContainsKey($id)) { $map[$id] = $null; continue }      # piu righe diverse per lo stesso articolo: oracolo non univoco
        if ($net -le 0 -or $gross -le 0) { $map[$id] = $null; continue }
        $value = $gross; $applied = $false
        if ($promos.Count -ge 1) { $best = ($promos | Measure-Object -Minimum).Minimum; $pg = [decimal]$best * ($gross / $net); if ($pg -gt 0 -and $pg -lt $gross) { $value = $pg; $applied = $true } }
        $map[$id] = [pscustomobject]@{ Gross = $gross; Text = ([Math]::Round($value, 2, [MidpointRounding]::AwayFromZero)).ToString('N2', $it); Promo = $applied }
    }
    return $map
}
function Read-Cards($browser) {
    Open-KsUrl $browser ($base + '/carrello.aspx') 300; Start-Sleep -Milliseconds 1500
    $raw = [string](Invoke-KsJs $browser $cardJs)
    $cards = New-Object Collections.Generic.List[object]
    $parsed = ConvertFrom-Json $raw      # in PowerShell 5.1 la pipeline consegnerebbe l'elenco come un solo oggetto
    foreach ($c in $parsed) {
        $mm = [regex]::Match([string]$c.href, 'articolo\.aspx\?id=(\d+)(&TCid=(\d+))?')
        if ($mm.Success) { $cards.Add([pscustomobject]@{ Id = [int]$mm.Groups[1].Value; Variant = $mm.Groups[3].Success; Price = [string]$c.price }) }
    }
    return $cards
}
# Restituisce l'elenco dei difetti (vuoto = tutto giusto).
function Test-Cards($cards, $oracle) {
    $bad = New-Object Collections.Generic.List[string]
    if (@($cards).Count -lt 3) { $bad.Add('schede lette: ' + @($cards).Count + ' (minimo 3): riquadro assente o vuoto') }
    foreach ($id in $must) { if (@($cards | Where-Object { $_.Id -eq $id -and -not $_.Variant }).Count -ne 1) { $bad.Add('scheda dell''articolo ' + $id + ' assente') } }
    $checked = 0
    foreach ($c in $cards) {
        if ($c.Variant) { continue }
        if (-not $oracle.ContainsKey($c.Id) -or $null -eq $oracle[$c.Id]) { $bad.Add('articolo ' + $c.Id + ': calcolo indipendente non univoco'); continue }
        $o = $oracle[$c.Id]; $checked++
        if ($c.Price -ne $o.Text) { $bad.Add('articolo ' + $c.Id + ': mostrato "' + $c.Price + '", atteso "' + $o.Text + '"') }
        $shown = 0D
        if (-not [decimal]::TryParse($c.Price, [Globalization.NumberStyles]::Number, $it, [ref]$shown) -or $shown -gt ($o.Gross * 1.01D) -or $shown -lt ($o.Gross / 10D)) { $bad.Add('articolo ' + $c.Id + ': prezzo fuori da ogni misura ("' + $c.Price + '", listino ' + $o.Gross.ToString($inv) + ')') }
    }
    if ($checked -lt 3) { $bad.Add('schede confrontate: ' + $checked + ' (minimo 3)') }
    return $bad.ToArray()
}

$browser = $null
$mutantFail = New-Object Collections.Generic.List[string]
$siteFailed = $false
$fixtureEnd = ''
try {
    $siteBytes = [IO.File]::ReadAllBytes($siteFile)
    if ([Convert]::ToBase64String($siteBytes) -ne [Convert]::ToBase64String($repoBytes)) { [IO.File]::WriteAllBytes($siteFile, $repoBytes); Write-Host '  sito LAB: carrello.aspx.vb allineato alla copia di lavoro' }
    $company = Get-Scalar "SELECT id AS ksval FROM aziende WHERE LOWER(TRIM(COALESCE(url1,''))) LIKE '%www.taikun.it%' OR LOWER(TRIM(COALESCE(url2,''))) LIKE '%www.taikun.it%' ORDER BY id LIMIT 1;"
    Check ($company -match '^\d+$') 'L01 azienda dell''host trovata nel database LAB'
    $listino = Get-Scalar "SELECT COALESCE(ListinoDefault,0) AS ksval FROM aziende WHERE id = $company;"
    Check ($listino -match '^\d+$' -and [int]$listino -gt 0) 'L02 listino di chi non e collegato trovato'

    # il mutante "lordo dal testo" si vede solo se l'articolo con tre decimali nel netto ha un'offerta valida a un pezzo: se e scaduta la si allunga sul LAB
    $pre = Get-Oracle $must $company $listino
    if (-not ($pre.ContainsKey(21906) -and $pre[21906] -and $pre[21906].Promo)) {
        $fixtureEnd = Get-Scalar 'SELECT DATE_FORMAT(DataFine, ''%Y-%m-%d'') AS ksval FROM offerte WHERE id = 19524;'
        if ($fixtureEnd -match '^\d{4}-\d{2}-\d{2}$') { $null = Invoke-Sql 'UPDATE offerte SET DataFine = CURDATE() + INTERVAL 1 DAY WHERE id = 19524;' -Write; Write-Host '  LAB: scadenza dell''offerta di prova allungata per la durata del test' } else { $fixtureEnd = '' }
        $pre = Get-Oracle $must $company $listino
    }
    Check ($pre.ContainsKey(21906) -and $pre[21906] -and $pre[21906].Promo) 'L02b l''articolo con tre decimali nel netto ha un''offerta valida a un pezzo'
    $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width 1280 -Height 900
    foreach ($id in $visit) { Open-KsUrl $browser ($base + '/articolo.aspx?id=' + $id) 300; Start-Sleep -Milliseconds 700 }
    Open-KsUrl $browser ($base + '/articoli.aspx') 300
    Invoke-KsClick $browser 'button.js-ks-cart-link' -NoWait; Start-Sleep -Seconds 5
    $cards = Read-Cards $browser
    $oracle = Get-Oracle (@($cards | Where-Object { -not $_.Variant } | ForEach-Object { $_.Id }) + $must | Select-Object -Unique) $company $listino
    foreach ($id in $must) { Check ($oracle.ContainsKey($id) -and $null -ne $oracle[$id]) ('L03 calcolo indipendente disponibile per l''articolo ' + $id) }
    $bad = @(Test-Cards $cards $oracle)
    Check ($bad.Count -eq 0) ('L04 ogni scheda mostra il prezzo del calcolo indipendente (schede ' + @($cards).Count + ')' + $(if ($bad.Count) { ' -> ' + ($bad -join '; ') } else { '' }))
    $shown = @($cards | Where-Object { $must -contains $_.Id } | ForEach-Object { $_.Id.ToString() + '=' + $_.Price + $(if ($oracle[$_.Id] -and $oracle[$_.Id].Promo) { ' (offerta)' } else { '' }) })
    Write-Host ('  prezzi mostrati: ' + ($shown -join ', '))
    $siteFailed = ($e2e.Count -gt 0)

    # ---------- (C) mutazioni sul sito LAB ----------
    if (-not $siteFailed -and -not $sourceFailed -and -not $SkipMutants) {
        $oldNet = 'net = Convert.ToDecimal(SafeDbl(row("Prezzo"), 0), CultureInfo.InvariantCulture)'
        $oldGross = 'gross = Convert.ToDecimal(SafeDbl(row("PrezzoIvato"), 0), CultureInfo.InvariantCulture)'
        $pair = $netLine + "`r`n            " + $grossLine
        $mutants = @(
            @{ Id = 'M01_NET_FROM_TEXT'; New = ($oldNet + "`r`n            " + $grossLine) },
            @{ Id = 'M02_GROSS_FROM_TEXT'; New = ($netLine + "`r`n            " + $oldGross) },
            @{ Id = 'M03_SWAPPED'; New = ('If Not TryReadDatabaseDecimal(row("PrezzoIvato"), net) Then Continue For' + "`r`n            " + 'If Not TryReadDatabaseDecimal(row("Prezzo"), gross) Then gross = 0D') },
            @{ Id = 'M04_BOTH_FROM_TEXT'; New = ($oldNet + "`r`n            " + $oldGross) }
        )
        foreach ($m in $mutants) {
            if (([regex]::Matches($source, [regex]::Escape($pair))).Count -ne 1) { $mutantFail.Add($m.Id + ' ancora non unica'); continue }
            Write-SiteFile ($source.Replace($pair, $m.New))
            try {
                $mc = Read-Cards $browser
                $mb = @(Test-Cards $mc $oracle)
                if ($mb.Count -eq 0) { $mutantFail.Add($m.Id + ' sopravvive') } else { Write-Host ('  ucciso ' + $m.Id + ': ' + $mb[0]) }
            } catch { $mutantFail.Add($m.Id + ' errore: ' + $_.Exception.Message) }
        }
        [IO.File]::WriteAllBytes($siteFile, $repoBytes)
        $after = @(Test-Cards (Read-Cards $browser) $oracle)
        if ($after.Count -ne 0) { $mutantFail.Add('dopo il ripristino il sito non torna verde: ' + $after[0]) }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    try { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($siteFile)) -ne [Convert]::ToBase64String($repoBytes)) { [IO.File]::WriteAllBytes($siteFile, $repoBytes) } } catch { Write-Host '  ATTENZIONE: file del sito LAB non ripristinato' }
    if ($fixtureEnd -ne '') { try { $null = Invoke-Sql ("UPDATE offerte SET DataFine = '" + $fixtureEnd + "' WHERE id = 19524;") -Write } catch { Write-Host '  ATTENZIONE: scadenza dell''offerta di prova non ripristinata sul LAB' } }
    Close-LabSite
}

if ($sourceFailed) { Write-Host 'CART_RECENT_PRICE FAIL (sorgente)' }
if ($e2e.Count -gt 0) { Write-Host ('CART_RECENT_PRICE FAIL (sito LAB): ' + $e2e.Count) }
foreach ($x in $mutantFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFailed -or $e2e.Count -gt 0 -or $mutantFail.Count -gt 0) { exit 1 }
if ($SkipMutants) { Write-Host 'CART_RECENT_PRICE OK (mutazioni saltate)' } else { Write-Host 'CART_RECENT_PRICE OK (4 mutazioni uccise sul sito LAB)' }
exit 0
