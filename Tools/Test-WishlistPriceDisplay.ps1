[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# WISHLIST-PRICE-DISPLAY-1A. La pagina Preferiti mostra il prezzo che il carrello applichera a un pezzo (stessa routine del carrello, sola lettura),
# per un articolo senza promo e per uno in promo, senza barrato; mai un numero se il prezzo non e risolvibile. Prova HTTP sul sito LAB (https,
# 127.0.0.1, porta 18843, utente di prova). Atteso calcolato da SQL (vista), non dal formatter. Fixture inserita DIRETTAMENTE in wishlist (solo gli id
# creati si cancellano; le righe preesistenti dell'utente si salvano e si rimettono). Mutazioni sulla copia LAB; i byte originali sono rimessi alla fine.
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'WISHLIST_PRICE FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$files = @('wishlist.aspx', 'wishlist.aspx.vb', 'App_Code\KeepStoreWishlistPriceDisplay.vb')
$repoBytes = @{}; $origBytes = @{}; $origExists = @{}
foreach ($f in $files) {
    $rp = Join-Path $root $f; $sp = Join-Path $SitePath $f
    $repoBytes[$f] = if (Test-Path -LiteralPath $rp) { [IO.File]::ReadAllBytes($rp) } else { $null }
    $origExists[$f] = (Test-Path -LiteralPath $sp)
    $origBytes[$f] = if ($origExists[$f]) { [IO.File]::ReadAllBytes($sp) } else { $null }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-wlprice-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')
$jar = Join-Path $tmp 'auth.txt'

function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Http '/privacy.aspx' (Join-Path $tmp 'wait.txt')).Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
# Mette sul sito LAB i file del repo (o una variante mutata di uno di essi) e aspetta che il sito risponda.
function Set-SiteFile([string]$f, $bytes) {
    $sp = Join-Path $SitePath $f
    if ($null -eq $bytes) { if (Test-Path -LiteralPath $sp) { Remove-Item -LiteralPath $sp -Force } } else { [IO.File]::WriteAllBytes($sp, $bytes) }
}
function Deploy-Repo { foreach ($f in $files) { Set-SiteFile $f $repoBytes[$f] }; Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site { foreach ($f in $files) { if ($origExists[$f]) { Set-SiteFile $f $origBytes[$f] } else { Set-SiteFile $f $null } }; Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$f, [string]$text) { $bom = ($repoBytes[$f].Length -ge 3 -and $repoBytes[$f][0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $f), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

# Restituisce, per ogni card, il testo del blocco prezzo (dentro price-wrap) e lo stato.
function Get-Prices {
    $r = @{}
    $x = Invoke-Http '/wishlist.aspx' $jar
    $r.Status200 = ($x.Status -eq 200)
    $b = $x.Body
    $r.Label = ''
    $lm = [regex]::Match($b, '(?i)\*Prezzi\s+Iva\s+(Esclusa|Inclusa)'); if ($lm.Success) { $r.Label = $lm.Groups[1].Value.ToLower() }
    # una card per bottone Rimuovi; in ogni card: id articolo dal primo link di dettaglio e blocco price-wrap
    $chunks = @([regex]::Split($b, 'id="[^"]*_BT_Rimuovi_wishlist_\d+"') | Select-Object -Skip 1)
    $r.Cards = @{}
    foreach ($c in $chunks) {
        $m = [regex]::Match($c, 'articolo\.aspx\?id=(\d+)'); if (-not $m.Success) { continue }
        $id = [int]$m.Groups[1].Value
        $pw = [regex]::Match($c, '(?s)<(p|div)[^>]*class="[^"]*price-wrap[^"]*"[^>]*>(.*?)</\1>')
        $html = if ($pw.Success) { $pw.Groups[2].Value } else { '' }
        $text = ([regex]::Replace($html, '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
        $r.Cards[$id] = @{ Html = $html; Text = $text; HasDel = ($html -match '(?i)<del') }
    }
    return $r
}
function Fmt([string]$dec) { return ([decimal]::Parse($dec, [Globalization.CultureInfo]::InvariantCulture)).ToString('N2', [Globalization.CultureInfo]::GetCultureInfo('it-IT')) }

$exit = 0
$uid = 0; $before = 0; $saved = ''
try {
    $uid = [int](Get-Scalar "SELECT UtentiId AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $lst = [int](Get-Scalar "SELECT Listino AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    # articolo senza promo (riga unica, nessuna offerta) e articolo in promo semplice (una sola riga promo valida)
    $idPlain = [int](Get-Scalar "SELECT MIN(a.id) AS ksval FROM vsuperarticoli a WHERE a.NListino = $lst AND a.Prezzo > 0 AND COALESCE(a.InOfferta,0) = 0 AND a.id NOT IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst GROUP BY id HAVING COUNT(*) > 1);")
    $idPromo = [int](Get-Scalar "SELECT MIN(a.id) AS ksval FROM vsuperarticoli a WHERE a.NListino = $lst AND a.InOfferta = 1 AND a.OfferteDataInizio <= CURDATE() AND a.OfferteDataFine >= CURDATE() AND a.PrezzoPromo > 0 AND a.id IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst AND InOfferta = 1 GROUP BY id HAVING COUNT(*) = 1);")
    # articolo con prezzo zero (riga unica): il carrello non lo accetta, quindi la scheda non mostra mai un numero
    $idZero = [int](Get-Scalar "SELECT MIN(a.id) AS ksval FROM vsuperarticoli a WHERE a.NListino = $lst AND COALESCE(a.Prezzo,0) <= 0 AND a.id NOT IN (SELECT id FROM vsuperarticoli WHERE NListino = $lst GROUP BY id HAVING COUNT(*) > 1);")
    if ($uid -le 0 -or $idPlain -le 0 -or $idPromo -le 0 -or $idZero -le 0) { throw 'FIXTURE_NOT_FOUND' }
    $plainNet = Get-Scalar "SELECT Prezzo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $plainGross = Get-Scalar "SELECT PrezzoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPlain LIMIT 1;"
    $promoNet = Get-Scalar "SELECT PrezzoPromo AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $promoGross = Get-Scalar "SELECT PrezzoPromoIvato AS ksval FROM vsuperarticoli WHERE NListino = $lst AND id = $idPromo AND InOfferta = 1 LIMIT 1;"
    $before = [int](Get-Scalar 'SELECT COALESCE(MAX(id_wishlist), 0) AS ksval FROM wishlist;')
    $saved = Get-Scalar "SELECT COALESCE(GROUP_CONCAT(CONCAT('(', id_wishlist, ',', id_utente, ',', id_articolo, ')') SEPARATOR ','), '') AS ksval FROM wishlist WHERE id_utente = $uid;"
    if ($saved -ne '') { $null = Invoke-Sql "DELETE FROM wishlist WHERE id_utente = $uid;" -Write }
    $null = Invoke-Sql ("INSERT INTO wishlist (id_utente, id_articolo) VALUES ($uid, $idPlain), ($uid, $idPromo), ($uid, $idZero);") -Write
    Deploy-Repo
    $null = Invoke-Login $jar $false

    # IVA esclusa = netto, IVA inclusa = lordo (utente di prova senza override ne reverse charge: la vista e la fonte)
    $expected = {
        param($label)
        if ($label -eq 'inclusa') { return @{ Plain = (Fmt $plainGross); Promo = (Fmt $promoGross) } }
        return @{ Plain = (Fmt $plainNet); Promo = (Fmt $promoNet) }
    }
    $p = Get-Prices
    Check $p.Status200 'la pagina Preferiti risponde 200'
    Check ($p.Label -ne '') ('etichetta IVA presente (' + $p.Label + ')')
    $exp = & $expected $p.Label
    Check ($p.Cards.ContainsKey($idPlain) -and $p.Cards.ContainsKey($idPromo)) 'due card presenti'
    if ($p.Cards.ContainsKey($idPlain)) { Check ($p.Cards[$idPlain].Text -match [regex]::Escape($exp.Plain)) ('articolo senza promo: prezzo ' + $exp.Plain + ' (trovato: ' + $p.Cards[$idPlain].Text + ')') }
    if ($p.Cards.ContainsKey($idPromo)) {
        Check ($p.Cards[$idPromo].Text -match [regex]::Escape($exp.Promo)) ('articolo in promo: prezzo promo ' + $exp.Promo + ' (trovato: ' + $p.Cards[$idPromo].Text + ')')
        Check (-not $p.Cards[$idPromo].HasDel) 'articolo in promo: nessun prezzo barrato (un solo prezzo pagabile)'
    }
    Check ($p.Cards.ContainsKey($idZero) -and $p.Cards[$idZero].Text -match '(?i)richiesta' -and $p.Cards[$idZero].Text -notmatch '\d') ('articolo con prezzo zero: Prezzo su richiesta e nessun numero (trovato: ' + $(if ($p.Cards.ContainsKey($idZero)) { $p.Cards[$idZero].Text } else { 'senza card' }) + ')')
    $wrapperPath = 'App_Code\KeepStoreWishlistPriceDisplay.vb'
    Check ($null -ne $repoBytes[$wrapperPath]) 'il file del wrapper esiste'
    if ($e2e.Count -gt 0) { $exit = 1 }

    if (-not $SkipMutants -and $exit -eq 0) {
        $wText = Get-Text $repoBytes[$wrapperPath]
        $aspx = Get-Text $repoBytes['wishlist.aspx']
        $mutants = [ordered]@{
            'M01_TCID_POSITIVE'    = @{ File = $wrapperPath; From = 'articleId, -1, 1D'; To = 'articleId, 1, 1D' }
            'M03_PROMO_TO_FORMAT'  = @{ File = $wrapperPath; From = 'resolved.PriceIvato, Nothing, Nothing, 0,'; To = 'resolved.PriceIvato, resolved.Price * 0.5D, resolved.PriceIvato * 0.5D, 1,' }
            'M05_NO_CALL'          = @{ File = 'wishlist.aspx'; From = '<%# WishlistPriceHtml(Container.DataItem) %>'; To = '' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            $src = if ($mu.File -eq 'wishlist.aspx') { $aspx } else { $wText }
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-Mutant $mu.File ($src.Replace($mu.From, $mu.To))
                $null = Invoke-Login $jar $false   # il ricaricamento del sito azzera la sessione
                $m = Get-Prices
                $ex = & $expected $m.Label
                $ok = $m.Status200 -and $m.Cards.ContainsKey($idPlain) -and $m.Cards.ContainsKey($idPromo) -and ($m.Cards[$idPlain].Text -match [regex]::Escape($ex.Plain)) -and ($m.Cards[$idPromo].Text -match [regex]::Escape($ex.Promo)) -and (-not $m.Cards[$idPromo].HasDel) -and ($m.Cards.ContainsKey($idZero) -and $m.Cards[$idZero].Text -match '(?i)richiesta' -and $m.Cards[$idZero].Text -notmatch '\d')
                if (-not $ok) { $killed++; $seen = if ($m.Cards.ContainsKey($idPlain)) { $m.Cards[$idPlain].Text + ' | ' + $(if ($m.Cards.ContainsKey($idPromo)) { $m.Cards[$idPromo].Text } else { '-' }) } else { 'senza card' }; Write-Host ('  ok   mutante ' + $id + ' ucciso (visto: ' + $seen + ')') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
    # nota: ignorare IsValid non e osservabile (equivalente): il formatter rifiuta comunque un prezzo zero (seconda difesa); il pin sotto controlla IsValid.
    Check ((Get-Text $repoBytes[$wrapperPath]).Contains('Not resolved.IsValid')) 'pin: il prezzo risolto deve essere valido'
    # nota: il lordo scambiato col netto non e distinguibile sul LAB (l'utente di prova vede i prezzi IVA esclusa): coperto dal pin statico sotto
    Check ($(if ($null -ne $repoBytes[$wrapperPath]) { (Get-Text $repoBytes[$wrapperPath]).Contains('resolved.Price, resolved.PriceIvato, Nothing') } else { $false })) 'pin: netto e lordo della routine del carrello passati al formatter'
    # pin statici: il wrapper usa la stessa routine del carrello, controlla il listino e fallisce chiuso
    $w = if ($null -ne $repoBytes[$wrapperPath]) { Get-Text $repoBytes[$wrapperPath] } else { '' }
    Check ($w.Contains('CartPriceRevalidationHelper.ResolveStandardPrice(')) 'pin: usa la routine di prezzo del carrello'
    Check ($w.Contains('listino <> context.PriceListId')) 'pin: il listino della sessione deve coincidere col contesto prezzi'
    Check ($w.Contains('PriceOnRequestHtml()')) 'pin: fallisce chiuso con Prezzo su richiesta'
    Check ($w.Contains('Catch ex As Exception')) 'pin: ogni eccezione e catturata'
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { if ($before -gt 0 -and $uid -gt 0) { $null = Invoke-Sql ("DELETE FROM wishlist WHERE id_wishlist > $before AND id_utente = $uid;") -Write } } catch { Write-Host '  ATTENZIONE: pulizia wishlist non riuscita' }
    try { if ($saved -ne '') { $null = Invoke-Sql ("INSERT INTO wishlist (id_wishlist, id_utente, id_articolo) VALUES " + $saved + ";") -Write } } catch { Write-Host '  ATTENZIONE: ripristino righe wishlist non riuscito' }
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'WISHLIST_PRICE PASS' } else { Write-Host 'WISHLIST_PRICE FAIL' }
exit $exit
