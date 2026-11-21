[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$SkipSite, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# STYLE-PRICE-STATES-1A. Il colore del prezzo dice lo stato commerciale vero, uguale su HOME, elenco e scheda prodotto:
# rosso solo con lo sconto MOSTRATO (prezzo precedente barrato accanto), nero per prezzo normale e ''Prezzo su richiesta''.
# Uno sconto si mostra con la regola unica StorefrontPromotionDisplayPolicy (almeno 1 centesimo e almeno l'1% sui prezzi stampati)
# anche in elenco e scheda prodotto. Gli importi non cambiano mai.
# (A) classe pura compilata; (B) sito LAB (https, 127.0.0.1, porta 18843) con i file di lavoro, letture dal DOM indipendenti dalla
# classe di stato: barrato VISIBILE con importo maggiore nello stesso contenitore; (C) percorso sotto soglia: nella sola copia LAB
# la soglia percentuale viene alzata per la durata della prova; (D) mutazioni sulla copia LAB. File del LAB rimessi alla fine.
# Sola lettura sul database. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$fail = New-Object Collections.Generic.List[string]
$files = @('Default.aspx.vb', 'articoli.aspx.vb', 'articolo.aspx', 'articolo.aspx.vb', 'Page.master', 'Public\ui\controls\ProductCard.ascx', 'Public\ui\controls\ProductCard.ascx.vb',
    'App_Code\UiPriceFormatter.vb', 'App_Code\StorefrontPriceState.vb', 'App_Code\StorefrontPromotionDisplayPolicy.vb', 'Public\assets\keepstore\css\price-states.css')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PRICE_STATES FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

# ---------- (A) classe pura ----------
Add-Type -Language VisualBasic -TypeDefinition ((Get-Text $repoBytes['App_Code\StorefrontPromotionDisplayPolicy.vb']) + "`r`n" + ((Get-Text $repoBytes['App_Code\StorefrontPriceState.vb']) -replace '(?m)^\s*(Option \w+ \w+|Imports System)\s*$', ''))
function Shows($b, $p) { return [StorefrontPriceState]::ShowsDiscount([Nullable[decimal]]$b, [Nullable[decimal]]$p) }
$unit = @(
    @('U01 100 -> 99,50 (0,5%): sconto non mostrato', (Shows 100 99.50), $false), @('U02 100 -> 99,00 (1%): sconto mostrato', (Shows 100 99.00), $true),
    @('U03 6 -> 5: sconto mostrato', (Shows 6 5), $true), @('U04 10,004 -> 10,003 (stesso prezzo stampato): non mostrato', (Shows 10.004 10.003), $false),
    @('U05 base zero: non mostrato', (Shows 0 5), $false), @('U06 prezzo maggiore della base: non mostrato', (Shows 5 6), $false),
    @('U07 valori assenti: non mostrato', ([StorefrontPriceState]::ShowsDiscount($null, [Nullable[decimal]]5)), $false),
    @('U08 classe dello sconto', ([StorefrontPriceState]::CssClass($true, $true)), 'ks-price-state--sale'), @('U09 classe del prezzo normale', ([StorefrontPriceState]::CssClass($true, $false)), 'ks-price-state--normal'),
    @('U10 classe su richiesta (anche se lo sconto fosse vero)', ([StorefrontPriceState]::CssClass($false, $true)), 'ks-price-state--ask'))
foreach ($u in $unit) { if ($u[1] -ne $u[2]) { $fail.Add($u[0]) } }
foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }
if ($SkipSite) { if ($fail.Count -eq 0) { Write-Host 'PRICE_STATES PASS (solo classe pura)'; exit 0 } else { Write-Host 'PRICE_STATES FAIL'; exit 1 } }

# ---------- (B) sito LAB ----------
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Default.aspx.vb'))) { Write-Host ('PRICE_STATES FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

$readJs = @'
(function(){
var cv=document.createElement('canvas');cv.width=cv.height=1;var cx=cv.getContext('2d',{willReadFrequently:true});
function hex(c){cx.clearRect(0,0,1,1);cx.fillStyle=c;cx.fillRect(0,0,1,1);var d=cx.getImageData(0,0,1,1).data;return ('#'+[d[0],d[1],d[2]].map(function(v){return ('0'+v.toString(16)).slice(-2);}).join('')).toUpperCase();}
function txt(e){return (e.textContent||'').replace(/\s+/g,' ').trim();}
function vis(e){if(!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden')return false;var b=e.getBoundingClientRect();if(!(b.width>1&&b.height>1))return false;var op=1,p=e;while(p&&p.nodeType===1){op*=parseFloat(getComputedStyle(p).opacity);p=p.parentElement;}return op>0.05;}
function amt(t){var m=t.match(/-?(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}/);return m?parseFloat(m[0].replace(/\./g,'').replace(',','.')):null;}
function prod(e){
if(e.closest('[id*="QuickView"], [id*="quickView"], [class*="minicart"], [class*="mini-cart"], .popup-shopping-cart, .ks-pdp-buybar, .modal, .offcanvas, header, footer'))return '';
var card=e.closest('.card-product');
if(card){if(card.classList.contains('ks-deal-card'))return 'occasioni';if(card.classList.contains('ks-grid-card'))return 'griglia-home';if(card.classList.contains('ks-recent-card'))return 'recenti';
var sec=card.closest('#prd-usually, #prd-similar, #prd-related, #prd-recent');if(sec)return 'sezione:'+sec.id;return 'elenco';}
var s2=e.closest('#prd-usually, #prd-similar, #prd-related, #prd-recent');if(s2)return 'sezione:'+s2.id;
if(/articolo\.aspx/i.test(location.pathname)&&e.closest('.ks-pdp-buybox-sticky'))return 'principale';
return '';}
var out=[];
document.querySelectorAll('.new-price, .ks-price-now, .ks-price-ask').forEach(function(e){
if(!vis(e))return;var p=prod(e);if(!p)return;
var up=e.parentElement||e;var wrap=up.closest('.price-wrap, .ks-price, .price-text, .ks-home-price-slot')||up;
var t=txt(e),a=amt(t),old=false,anyOld=false;
wrap.querySelectorAll('.old-price, .ks-price-old, del').forEach(function(o){if(!vis(o))return;var b=amt(txt(o));if(b===null)return;anyOld=true;if(a!==null&&b>a)old=true;});
var cls=['sale','normal','ask'].filter(function(k){return e.classList.contains('ks-price-state--'+k);}).join('+');
var card=e.closest('.card-product, .ks-pdp-buybox-sticky');var badge='',id='';
if(card){var bd=card.querySelector('.box-sale-wrap .title-sidebar-2, .box-sale-tag');if(bd&&vis(bd))badge=txt(bd);var a2=card.querySelector('a[href*="articolo.aspx"]');if(a2){var m=(a2.getAttribute('href')||'').match(/[?&]id=(\d+)/);if(m)id=m[1];}}
if(!id&&p==='principale'){var m2=location.search.match(/[?&]id=(\d+)/);if(m2)id=m2[1];}
out.push({p:p,t:t.substring(0,24),old:old,anyOld:anyOld,cls:cls,color:hex(getComputedStyle(e).color),ask:(a===null),badge:badge.substring(0,16),id:id});});
return JSON.stringify(out);})()
'@
function Read-Prices($browser, [string]$path) {
    # la copia in memoria dei fogli di stile falserebbe le mutazioni sul foglio dei colori
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + $path) 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    $h = [int](Invoke-KsJs $browser 'Math.max(document.body.scrollHeight,document.documentElement.scrollHeight)')
    for ($y = 0; $y -lt $h; $y += 700) { $null = Invoke-KsJs $browser ('window.scrollTo({top:' + $y + ',behavior:"instant"});1'); Start-Sleep -Milliseconds 90 }
    $null = Invoke-KsJs $browser 'window.scrollTo({top:0,behavior:"instant"});1'; Start-Sleep -Milliseconds 700
    return @(ConvertFrom-Json ([string](Invoke-KsJs $browser $readJs)))
}
# Regole valide per ogni prezzo corrente in perimetro. Restituisce i difetti con il prefisso del caso.
function Test-Rules([string]$case, $list) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($x in @($list)) {
        $who = $case + ' ' + [string]$x.p + ' [' + [string]$x.t + ']'
        if (@('sale', 'normal', 'ask') -notcontains [string]$x.cls) { $bad.Add($who + ': classe di stato assente o doppia (' + [string]$x.cls + ')'); continue }
        if ([bool]$x.ask -ne ([string]$x.cls -eq 'ask')) { $bad.Add($who + ': classe ' + [string]$x.cls + ' su testo ' + $(if ($x.ask) { 'senza importo' } else { 'con importo' })) }
        if ([bool]$x.old -ne ([string]$x.cls -eq 'sale')) { $bad.Add($who + ': classe ' + [string]$x.cls + ' con barrato maggiore ' + $(if ($x.old) { 'presente' } else { 'assente' })) }
        if ([bool]$x.anyOld -and -not [bool]$x.old) { $bad.Add($who + ': prezzo barrato non maggiore del prezzo corrente') }
        $want = if ([string]$x.cls -eq 'sale') { '#D80027' } else { '#000000' }
        if ([string]$x.color -ne $want) { $bad.Add($who + ': colore ' + [string]$x.color + ' invece di ' + $want) }
    }
    return $bad
}
function Count-Of($list, [string]$p, [string]$cls) { return @(@($list) | Where-Object { [string]$_.p -like $p -and [string]$_.cls -eq $cls }).Count }

$state = @{ saleId = ''; normalId = ''; askId = ''; texts = @{} }
function Invoke-Case([string]$case, $browser) {
    $bad = New-Object Collections.Generic.List[string]
    switch ($case) {
        'E1' {   # elenco delle offerte: sconto mostrato
            $l = Read-Prices $browser '/articoli.aspx?inpromo=1'
            foreach ($b in (Test-Rules 'E1' $l)) { $bad.Add($b) }
            $sale = @($l | Where-Object { [string]$_.p -eq 'elenco' -and [bool]$_.old -and [string]$_.id -ne '' })
            if ($sale.Count -lt 1) { $bad.Add('E1 NON PROVATO: nessuna scheda scontata nell''elenco delle offerte') } else { $state.saleId = [string]$sale[0].id; foreach ($s in $sale) { $state.texts[[string]$s.id] = [string]$s.t } }
            if (@($sale | Where-Object { [string]$_.badge -notmatch '%' }).Count -gt 0) { $bad.Add('E1 scheda scontata senza bollino con la percentuale') }
        }
        'E2' {   # elenco normale: prezzo normale e su richiesta
            $l = Read-Prices $browser '/articoli.aspx'
            foreach ($b in (Test-Rules 'E2' $l)) { $bad.Add($b) }
            $n = @($l | Where-Object { [string]$_.p -eq 'elenco' -and -not [bool]$_.anyOld -and -not [bool]$_.ask -and [string]$_.id -ne '' -and [string]$_.badge -eq '' })
            $a = @($l | Where-Object { [string]$_.p -eq 'elenco' -and [bool]$_.ask -and [string]$_.id -ne '' })
            if ($n.Count -lt 1) { $bad.Add('E2 NON PROVATO: nessun prezzo normale nell''elenco') } else { $state.normalId = [string]$n[0].id }
            if ($a.Count -lt 1) { $bad.Add('E2 NON PROVATO: nessun ''Prezzo su richiesta'' nell''elenco') } else { $state.askId = [string]$a[0].id }
        }
        'P1' {   # scheda prodotto: scontata, normale, su richiesta, con le loro sezioni
            foreach ($k in @(@('scontata', $state.saleId, 'sale'), @('normale', $state.normalId, 'normal'), @('su richiesta', $state.askId, 'ask'))) {
                if ([string]$k[1] -eq '') { $bad.Add('P1 NON PROVATO: scheda prodotto ' + $k[0]); continue }
                $l = Read-Prices $browser ('/articolo.aspx?id=' + $k[1])
                foreach ($b in (Test-Rules ('P1 ' + $k[0]) $l)) { $bad.Add($b) }
                $main = @($l | Where-Object { [string]$_.p -eq 'principale' })
                if ($main.Count -ne 1) { $bad.Add('P1 ' + $k[0] + ': prezzi principali trovati ' + $main.Count) } elseif ([string]$main[0].cls -ne [string]$k[2]) { $bad.Add('P1 ' + $k[0] + ': prezzo principale con classe ' + [string]$main[0].cls) }
                elseif ($k[2] -eq 'sale' -and $state.texts.ContainsKey([string]$k[1]) -and [string]$main[0].t -ne [string]$state.texts[[string]$k[1]]) { $bad.Add('P1 scontata: importo diverso fra elenco e scheda prodotto') }
            }
        }
        'R1' {   # visti di recente dell'elenco (schede in linea), dopo la visita di una scheda scontata
            if ($state.saleId -eq '') { $bad.Add('R1 NON PROVATO'); break }
            $null = Read-Prices $browser ('/articolo.aspx?id=' + $state.saleId)
            $l = Read-Prices $browser '/articoli.aspx'
            foreach ($b in (Test-Rules 'R1' $l)) { $bad.Add($b) }
            if ((Count-Of $l 'recenti' 'sale') -lt 1) { $bad.Add('R1 NON PROVATO: nessun visto di recente scontato nell''elenco (trovati ' + @($l | Where-Object { [string]$_.p -eq 'recenti' }).Count + ')') }
        }
        'H1' {   # HOME: occasioni tutte scontate, griglia normale e, su piu letture, griglia scontata
            $gridSale = 0; $gridNormal = 0; $deal = 0
            for ($i = 0; $i -lt 6 -and ($gridSale -eq 0 -or $i -lt 2); $i++) {
                $l = Read-Prices $browser '/Default.aspx'
                foreach ($b in (Test-Rules 'H1' $l)) { $bad.Add($b) }
                if (@($l | Where-Object { [string]$_.p -eq 'occasioni' -and [string]$_.cls -ne 'sale' }).Count -gt 0) { $bad.Add('H1 occasione senza sconto mostrato') }
                $deal += (Count-Of $l 'occasioni' 'sale'); $gridSale += (Count-Of $l 'griglia-home' 'sale'); $gridNormal += (Count-Of $l 'griglia-home' 'normal')
            }
            if ($deal -lt 1) { $bad.Add('H1 NON PROVATO: nessuna occasione') }
            if ($gridNormal -lt 1) { $bad.Add('H1 NON PROVATO: nessun prezzo normale nelle griglie') }
            if ($gridSale -lt 1) { $bad.Add('H1 NON PROVATO: nessuno sconto nelle griglie della HOME in sei letture') }
        }
        'T1' {   # sotto soglia: soglia percentuale alzata nella copia LAB; stessi importi, nessun barrato, nessuna percentuale, nero
            if ($state.saleId -eq '') { $bad.Add('T1 NON PROVATO'); break }
            $policy = Get-Text $repoBytes['App_Code\StorefrontPromotionDisplayPolicy.vb']
            $old = 'Public Const MinimumPercent As Decimal = 1D'
            if ($policy.IndexOf($old, [StringComparison]::Ordinal) -lt 0) { $bad.Add('T1 costante della soglia non trovata'); break }
            Write-SiteText 'App_Code\StorefrontPromotionDisplayPolicy.vb' $policy.Replace($old, 'Public Const MinimumPercent As Decimal = 99.5D')
            try {
                $l = Read-Prices $browser '/articoli.aspx?inpromo=1'
                foreach ($b in (Test-Rules 'T1 elenco' $l)) { $bad.Add($b) }
                $cards = @($l | Where-Object { [string]$_.p -eq 'elenco' -and $state.texts.ContainsKey([string]$_.id) })
                if ($cards.Count -lt 1) { $bad.Add('T1 NON PROVATO: gli articoli scontati non sono piu nell''elenco') }
                foreach ($c in $cards) {
                    if ([string]$c.t -ne [string]$state.texts[[string]$c.id]) { $bad.Add('T1 elenco: importo cambiato per l''articolo ' + [string]$c.id + ' (' + [string]$state.texts[[string]$c.id] + ' -> ' + [string]$c.t + ')') }
                    if ([string]$c.cls -ne 'normal' -or [bool]$c.anyOld) { $bad.Add('T1 elenco: sconto sotto soglia ancora mostrato per l''articolo ' + [string]$c.id) }
                    if ([string]$c.badge -match '%') { $bad.Add('T1 elenco: bollino con percentuale sotto soglia per l''articolo ' + [string]$c.id) }
                }
                $l = Read-Prices $browser ('/articolo.aspx?id=' + $state.saleId)
                foreach ($b in (Test-Rules 'T1 scheda' $l)) { $bad.Add($b) }
                $main = @($l | Where-Object { [string]$_.p -eq 'principale' })
                if ($main.Count -ne 1) { $bad.Add('T1 scheda: prezzo principale non trovato') }
                else {
                    if ([string]$main[0].t -ne [string]$state.texts[$state.saleId]) { $bad.Add('T1 scheda: importo cambiato (' + [string]$state.texts[$state.saleId] + ' -> ' + [string]$main[0].t + ')') }
                    if ([string]$main[0].cls -ne 'normal' -or [bool]$main[0].anyOld) { $bad.Add('T1 scheda: sconto sotto soglia ancora mostrato') }
                }
                if (@($l | Where-Object { [string]$_.p -like 'sezione:*' -and [string]$_.badge -match '%' }).Count -gt 0) { $bad.Add('T1 scheda: bollino con percentuale nei correlati sotto soglia') }
                $l = Read-Prices $browser '/articoli.aspx'
                foreach ($b in (Test-Rules 'T1 recenti' $l)) { $bad.Add($b) }
                if (@($l | Where-Object { [string]$_.p -eq 'recenti' -and ([string]$_.cls -eq 'sale' -or [bool]$_.anyOld) }).Count -gt 0) { $bad.Add('T1 recenti: sconto sotto soglia ancora mostrato') }
            } finally { Write-Site 'App_Code\StorefrontPromotionDisplayPolicy.vb' $repoBytes['App_Code\StorefrontPromotionDisplayPolicy.vb'] }
        }
    }
    return $bad
}

$exit = 0
if ($fail.Count -gt 0) { $exit = 1 }
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
$browser = $null
try {
    Sync-Site
    $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    foreach ($case in @('E1', 'E2', 'P1', 'R1', 'H1', 'T1')) {
        $bad = @(Invoke-Case $case $browser)
        if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $case) } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 12)) { Write-Host ('  FAIL ' + $b) }; if ($bad.Count -gt 12) { Write-Host ('  ... altri ' + ($bad.Count - 12)) } }
    }
    Stop-KsBrowser $browser; $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 390 -Height 844 -Mobile
    foreach ($p in @('/articoli.aspx?inpromo=1', '/Default.aspx', ('/articolo.aspx?id=' + $state.saleId), ('/articolo.aspx?id=' + $state.normalId))) {
        $bad = @(Test-Rules 'M390' (Read-Prices $browser $p))
        if ($bad.Count -gt 0) { $exit = 1; foreach ($b in ($bad | Select-Object -First 6)) { Write-Host ('  FAIL ' + $b) } }
    }
    if ($exit -eq 0) { Write-Host '  ok   telefono 390 px' }
    Stop-KsBrowser $browser; $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900

    if (-not $SkipMutants -and $exit -eq 0) {
        $mutants = @(
            @{ Id = 'M01_HOME_STATE_FROM_CARD_SIZE'; File = 'Default.aspx.vb'; Case = 'H1'; Expect = 'H1 griglia-home'; Old = 'StorefrontPriceState.CssClass(hasPrice, showsDiscount)'; New = 'StorefrontPriceState.CssClass(hasPrice, emphasize)' },
            @{ Id = 'M02_CARD_STATE_FROM_ANY_PROMOTION'; File = 'articoli.aspx.vb'; Case = 'T1'; Expect = 'T1 elenco'; Old = 'UiPriceFormatter.PriceOnRequestText, StringComparison.Ordinal), showsDiscount)'; New = 'UiPriceFormatter.PriceOnRequestText, StringComparison.Ordinal), hasPromotion)' },
            @{ Id = 'M03_LIST_THRESHOLD_IGNORED'; File = 'articoli.aspx.vb'; Case = 'T1'; Expect = 'T1 elenco'; Old = 'hasDefaultQuantityPromo AndAlso StorefrontPriceState.ShowsDiscount(basePrice, defaultQuantityPromoPrice)'; New = 'hasDefaultQuantityPromo AndAlso basePrice > 0D' },
            @{ Id = 'M04_PDP_ALWAYS_SALE'; File = 'articolo.aspx.vb'; Case = 'P1'; Expect = 'P1 normale'; Old = 'StorefrontPriceState.NormalClass & """>" & Server.HtmlEncode(priceText)'; New = 'StorefrontPriceState.SaleClass & """>" & Server.HtmlEncode(priceText)' },
            @{ Id = 'M05_PDP_THRESHOLD_IGNORED'; File = 'articolo.aspx.vb'; Case = 'T1'; Expect = 'T1 scheda'; Old = 'If StorefrontPriceState.ShowsDiscount(oldPrice, authorizedPrice) Then'; New = 'If True Then' },
            @{ Id = 'M06_ASK_CLASS_NOT_EMITTED'; File = 'articolo.aspx.vb'; Case = 'P1'; Expect = 'P1 su richiesta'; Old = 'StorefrontPriceState.AskClass & """>" & UiPriceFormatter.PriceOnRequestText'; New = 'StorefrontPriceState.NormalClass & """>" & UiPriceFormatter.PriceOnRequestText' },
            @{ Id = 'M07_INLINE_OLD_PRICE_WITHOUT_THRESHOLD'; File = 'App_Code\UiPriceFormatter.vb'; Case = 'T1'; Expect = 'T1 recenti'; Old = 'If StorefrontPriceState.ShowsDiscount(baseValue, promoValue) Then'; New = 'If True Then' },
            @{ Id = 'M08_CSS_SALE_RULE_REMOVED'; File = 'Public\assets\keepstore\css\price-states.css'; Case = 'E1'; Expect = 'E1 elenco'; Old = '.ks-price-state--sale {'; New = '.ks-price-state--sale-off {' },
            @{ Id = 'M09_CSS_NORMAL_RULE_REMOVED'; File = 'Public\assets\keepstore\css\price-states.css'; Case = 'P1'; Expect = 'P1 normale'; Old = '.ks-price-state--normal,'; New = '.ks-price-state--normal-off,' },
            @{ Id = 'M10_CARD_CLASS_NOT_RENDERED'; File = 'Public\ui\controls\ProductCard.ascx'; Case = 'E1'; Expect = 'E1 elenco'; Old = ' <%= SafePriceStateClass %>"'; New = '"' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = Get-Text $repoBytes[$mu.File]
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $src.Replace($mu.Old, $mu.New)
            try {
                $pre = if ($mu.Case -eq 'E1') { @() } else { @(Invoke-Case 'E1' $browser) + @(Invoke-Case 'E2' $browser) }
                $mb = @($pre) + @(Invoke-Case $mu.Case $browser)
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('PRICE_STATES PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (10 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'PRICE_STATES FAIL' }
exit $exit
