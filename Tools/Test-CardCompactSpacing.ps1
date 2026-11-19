[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$ThemeCssPath = '')

# UX-COMPACT-SPACING-SITEWIDE-1A (prima tranche: schede prodotto condivise). Richiesta del PO del 2026-11-19: nessuno spazio inutile
# nelle schede. Contratti geometrici misurati nel browser, sui riquadri degli elementi:
#  - la riga della categoria e alta UNA riga (regola condivisa .ks-card-category), anche quando la categoria e lunga o manca;
#  - nelle schede delle griglie della HOME: 2-8 px fra categoria e titolo, 2-8 px fra titolo e prezzo, nessuna altezza riservata
#    attorno al prezzo (ne sul prezzo ne sul suo contenitore), disponibilita ancorata in fondo;
#  - nella stessa fila: schede alte uguali, titoli, prezzi e disponibilita allineati.
# (A) pagina di prova statica con i fogli VERI nell'ordine di Page.master e i casi difficili (prezzo barrato lungo, prezzo a quantita,
#     categoria lunga, categoria assente, targhetta), a 390 / 768 / 1024 / 1280 px; (B) mutazioni del foglio di stile eseguite nel browser;
# (C) sito LAB reale (https, 127.0.0.1, porta 18843). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$assets = Join-Path $root 'Public\assets\keepstore'
if ($ThemeCssPath -eq '') { $ThemeCssPath = Join-Path $assets 'css\theme-overrides.css' }
$themeCss = [IO.File]::ReadAllText($ThemeCssPath, $utf8)
$master = [IO.File]::ReadAllText((Join-Path $root 'Page.master'), $utf8)
$homePage = [IO.File]::ReadAllText((Join-Path $root 'Default.aspx'), $utf8)
$work = Join-Path $env:TEMP ('ks-cardspacing-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

function ConvertTo-FileUrl([string]$path) { return 'file:///' + ($path -replace '\\', '/') }

# Fogli di stile nello stesso ordine di Page.master; al posto di HeadContent i blocchi di stile della HOME; theme-overrides per ultimo.
function New-Fixture([string]$themeText, [string]$name) {
    $themeFile = Join-Path $work ($name + '.css')
    [IO.File]::WriteAllText($themeFile, $themeText, $utf8)
    $head = New-Object Text.StringBuilder
    $links = [regex]::Matches($master, '<link rel="stylesheet" href="<%= ThemeManager\.Asset\("([^"]+)"\)[^>]*>|<asp:ContentPlaceHolder ID="HeadContent" runat="server" />')
    $seenTheme = $false; $seenSlot = $false
    foreach ($m in $links) {
        if ($m.Value.StartsWith('<asp:')) {
            $seenSlot = $true
            $headContent = [regex]::Match($homePage, '(?s)ContentPlaceHolderID="HeadContent"[^>]*>(.*?)</asp:Content>').Groups[1].Value
            foreach ($st in [regex]::Matches($headContent, '(?s)<style[^>]*>.*?</style>')) { $null = $head.AppendLine($st.Value) }
            continue
        }
        $rel = $m.Groups[1].Value
        if ($rel -eq 'css/theme-overrides.css') { if (-not $seenSlot) { throw 'ORDER_CHANGED_THEME_BEFORE_HEADCONTENT' }; $seenTheme = $true; $null = $head.AppendLine('<link rel="stylesheet" href="' + (ConvertTo-FileUrl $themeFile) + '">'); continue }
        $null = $head.AppendLine('<link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets ($rel -replace '/', '\'))) + '">')
    }
    if (-not $seenTheme -or -not $seenSlot) { throw 'MASTER_STYLESHEETS_NOT_FOUND' }
    $cases = @(
        @{ Cat = 'Intel Xeon'; Tag = 'Novit&#224;'; Title = 'WORKSTATION RICONDIZIONATO Lenovo ThinkStation P720 INTEL Xeon Silver 4210 2.6 GHz - DDR4 16GB ECC - SSD 512GB - SVGA Quadro RTX 4000 8 GB'; Price = '5.000,00'; Old = ''; Tier = $false },
        @{ Cat = 'Accessori per stampanti multifunzione laser e a getto di inchiostro professionali da ufficio'; Tag = ''; Title = 'ADATTATORE VGA HDMI'; Price = '22,90'; Old = '29,90'; Tier = $false },
        @{ Cat = ''; Tag = ''; Title = 'MONITOR 27 POLLICI CURVO WQHD SAMSUNG Odyssey G5 C27G55 GAMING 144Hz HDMI DisplayPort'; Price = '12.345,67'; Old = '13.999,99'; Tier = $false },
        @{ Cat = 'Carta in Risma'; Tag = 'In arrivo'; Title = 'RISMA CARTA A4 80gr 500fg'; Price = '5,00'; Old = '6,00'; Tier = $true },
        @{ Cat = 'Pen Drive USB Type-A'; Tag = ''; Title = 'PEN DRIVE USB 3.2 KINGSTON DTKN/32GB DataTraveler Kyson METAL'; Price = '12,99'; Old = ''; Tier = $false },
        @{ Cat = 'Tablet'; Tag = ''; Title = 'TABLET LENOVO Tab M11 TB330FU WiFi + Tab Pen - LUNA GRAY'; Price = '194,99'; Old = '199,00'; Tier = $false },
        @{ Cat = 'Cavi'; Tag = ''; Title = 'CAVO HDMI 2 MT'; Price = '3,50'; Old = ''; Tier = $true },
        @{ Cat = "Unita Ottiche"; Tag = ''; Title = 'MASTERIZZATORE LG ULTRA SLIM DVD-RW GP60NS60 PER NOTEBOOK'; Price = '34,99'; Old = '39,90'; Tier = $false }
    )
    $cards = New-Object Text.StringBuilder
    $img = ConvertTo-FileUrl (Join-Path $root 'Public\assets\images\img\placeholder.svg')
    foreach ($c in $cases) {
        $tag = if ($c.Tag -ne '') { "<span class='ks-card-tag'>" + $c.Tag + '</span>' } else { '' }
        $old = if ($c.Old -ne '') { "<span class='old-price body-md-2 text-main-2 ks-home-price-value ks-home-price-value--old'>" + $c.Old + '</span>' } else { '' }
        $tier = if ($c.Tier) { "<p class='caption text-main-2 mb-0 ks-home-promo-tier'>Da <strong>4,00</strong> - Multipli 5 pz.</p>" } else { '' }
        $null = $cards.Append("<div class='card-product style-img-border ks-grid-card'><div class='card-product-wrapper'><a href='#' class='product-img'><img class='img-product' src='$img' alt=''></a></div>")
        $null = $cards.Append("<div class='card-product-info'><div class='box-title'><div class='bg-white relative z-5'><p class='caption text-main-2 font-2 ks-card-category'>" + $tag + $c.Cat + "</p>")
        $null = $cards.Append("<a href='#' class='name-product body-md-2 fw-semibold text-secondary link ks-card-title'>" + $c.Title + "</a></div>")
        $null = $cards.Append("<div class='ks-home-price-stack ks-home-price-stack--compact'><p class='price-wrap fw-medium ks-home-price-slot ks-home-price-slot--compact'><span class='new-price body-md-2 mb-0 ks-home-price-value ks-home-price-value--current'>" + $c.Price + '</span>' + $old + '</p>' + $tier + '</div>')
        $null = $cards.AppendLine('<span class="ks-availability ks-availability--synthetic" role="status"><span class="ks-availability__status is-ok"><span class="ks-availability__dot" aria-hidden="true"></span><span class="ks-availability__status-text">Disponibile</span></span></span></div></div></div>')
    }
    $html = '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $head.ToString() +
            '</head><body id="PageBody" class="ks-page-home ks-home-main color-primary ks-theme-keepstore"><main><section id="ksHomePage" class="ks-home-main">' +
            '<section class="ks-home-section ks-home-featured"><div class="container"><div class="ks-home-product-grid">' + $cards.ToString() + '</div></div></section></section></main></body></html>'
    $file = Join-Path $work ($name + '.html')
    [IO.File]::WriteAllText($file, $html, $utf8)
    return (ConvertTo-FileUrl $file)
}

$measure = "(function(){var out=[];var cards=document.querySelectorAll('.ks-home-product-grid .ks-grid-card');for(var i=0;i<cards.length;i++){var c=cards[i],rc=c.getBoundingClientRect();" +
    "var cat=c.querySelector('.ks-card-category'),ti=c.querySelector('.ks-card-title'),st=c.querySelector('.ks-home-price-stack'),pw=c.querySelector('.price-wrap'),tier=c.querySelector('.ks-home-promo-tier'),av=c.querySelector('.box-title > .ks-availability');" +
    "if(!cat||!ti||!st||!pw||!av){out.push({missing:true});continue;}" +
    "var g=document.createRange();g.selectNodeContents(pw);var rects=g.getClientRects(),lt=1e9,lb=-1e9;for(var k=0;k<rects.length;k++){if(rects[k].height>0){lt=Math.min(lt,rects[k].top);lb=Math.max(lb,rects[k].bottom);}}" +
    "var rcat=cat.getBoundingClientRect(),rti=ti.getBoundingClientRect(),rst=st.getBoundingClientRect(),rpw=pw.getBoundingClientRect(),rav=av.getBoundingClientRect(),rtier=tier?tier.getBoundingClientRect():null;" +
    "var tierOuter=0;if(tier){var ts=getComputedStyle(tier);tierOuter=rtier.height+(parseFloat(ts.marginTop)||0)+(parseFloat(ts.marginBottom)||0);}" +
    "out.push({missing:false,top:Math.round(rc.top),h:Math.round(rc.height),lh:parseFloat(getComputedStyle(cat).lineHeight)||0,catH:rcat.height,catTitle:rti.top-rcat.bottom,titleTop:Math.round(rti.top-rc.top),titlePrice:rst.top-rti.bottom," +
    "priceTop:Math.round(rst.top-rc.top),priceExtra:rpw.height-(lb-lt),stackExtra:rst.height-rpw.height-tierOuter,priceAvail:rav.top-rst.bottom,availBottom:Math.round(rav.bottom-rc.top),inside:(rpw.right<=rc.right+1&&rav.bottom<=rc.bottom+1),tier:!!tier});}" +
    "return JSON.stringify({cards:out,scroll:document.documentElement.scrollWidth-window.innerWidth});})()"

function Test-Cards($r, [string]$tag, [int]$minimum, [bool]$rows) {
    $fail = New-Object Collections.Generic.List[string]
    $cards = @($r.cards)
    if ($cards.Count -lt $minimum) { $fail.Add($tag + ' schede misurate: ' + $cards.Count + ' (minimo ' + $minimum + ')') }
    $n = 0
    foreach ($c in $cards) {
        $n++
        if ($c.missing) { $fail.Add($tag + ' scheda ' + $n + ' senza un elemento atteso'); continue }
        if ($c.lh -le 0 -or $c.catH -gt ($c.lh + 1.5) -or $c.catH -lt ($c.lh - 1.5)) { $fail.Add($tag + ' scheda ' + $n + ' categoria non alta una riga: ' + [Math]::Round($c.catH, 1) + ' px (riga ' + [Math]::Round($c.lh, 1) + ')') }
        if ($c.catTitle -lt 2 -or $c.catTitle -gt 8) { $fail.Add($tag + ' scheda ' + $n + ' spazio fra categoria e titolo: ' + [Math]::Round($c.catTitle, 1) + ' px') }
        if ($c.titlePrice -lt 2 -or $c.titlePrice -gt 8) { $fail.Add($tag + ' scheda ' + $n + ' spazio fra titolo e prezzo: ' + [Math]::Round($c.titlePrice, 1) + ' px') }
        if ($c.priceExtra -gt 6) { $fail.Add($tag + ' scheda ' + $n + ' altezza riservata sul prezzo: ' + [Math]::Round($c.priceExtra, 1) + ' px') }
        if ($c.stackExtra -gt 6) { $fail.Add($tag + ' scheda ' + $n + ' altezza riservata sul contenitore del prezzo: ' + [Math]::Round($c.stackExtra, 1) + ' px') }
        if ($c.priceAvail -lt 2) { $fail.Add($tag + ' scheda ' + $n + ' disponibilita attaccata al prezzo: ' + [Math]::Round($c.priceAvail, 1) + ' px') }
        if (-not $c.inside) { $fail.Add($tag + ' scheda ' + $n + ' contenuto fuori dalla scheda') }
    }
    $ok = @($cards | Where-Object { -not $_.missing })
    if ($rows) {
        foreach ($grp in ($ok | Group-Object top)) {
            $g = @($grp.Group); if ($g.Count -lt 2) { continue }
            foreach ($prop in @('h', 'titleTop', 'priceTop', 'availBottom')) {
                $vals = @($g | ForEach-Object { $_.$prop })
                if ((($vals | Measure-Object -Maximum).Maximum - ($vals | Measure-Object -Minimum).Minimum) -gt 1) { $fail.Add($tag + ' fila a ' + $grp.Name + ' px non allineata (' + $prop + '): ' + ($vals -join ',')) }
            }
            # la scheda piu alta di contenuto non ha vuoto fra prezzo e disponibilita
            $minGap = ($g | ForEach-Object { $_.priceAvail } | Measure-Object -Minimum).Minimum
            if ($minGap -gt 10) { $fail.Add($tag + ' fila a ' + $grp.Name + ' px: vuoto fra prezzo e disponibilita anche nella scheda piu piena: ' + [Math]::Round($minGap, 1) + ' px') }
        }
    }
    return $fail
}

$widths = @(@{ W = 390; H = 844; M = $true }, @{ W = 768; H = 1024; M = $false }, @{ W = 1024; H = 800; M = $false }, @{ W = 1280; H = 900; M = $false })
$nl = "`r`n"; if (-not $themeCss.Contains($nl)) { $nl = "`n" }
$P = 'body.ks-page-home #ksHomePage .ks-grid-card '
$mutants = @(
    @{ Id = 'M01_CATEGORY_TWO_LINES'; Old = '  max-height: 1lh !important;' + $nl + '  -webkit-line-clamp: 1 !important;'; New = '  max-height: 2lh !important;' + $nl + '  height: 2lh !important;' + $nl + '  min-height: 2lh !important;' + $nl + '  -webkit-line-clamp: 2 !important;' },
    @{ Id = 'M02_PRICE_HEIGHT_BACK'; Old = $P + '.price-wrap.ks-home-price-slot--compact { height: auto; min-height: 0; }'; New = $P + '.price-wrap.ks-home-price-slot--compact { height: 52px; min-height: 0; }' },
    @{ Id = 'M03_PRICE_MIN_HEIGHT_ONLY'; Old = $P + '.price-wrap.ks-home-price-slot--compact { height: auto; min-height: 0; }'; New = $P + '.price-wrap.ks-home-price-slot--compact { height: auto; min-height: 52px; }' },
    @{ Id = 'M04_RESERVE_ON_CONTAINER'; Old = $P + '.ks-home-price-stack--compact { min-height: 0; }'; New = $P + '.ks-home-price-stack--compact { min-height: 78px; }' },
    @{ Id = 'M05_TITLE_MARGIN_BACK'; Old = $P + '.name-product { margin-bottom: 0; }'; New = $P + '.name-product { margin-bottom: 10px; }' },
    @{ Id = 'M06_FOOTER_NOT_ANCHORED'; Old = $P + '.box-title > .ks-availability { flex: 0 0 auto; margin-top: auto; }'; New = $P + '.box-title > .ks-availability { flex: 0 0 auto; margin-top: 0; }' },
    @{ Id = 'M07_GAP_WIDER'; Old = 'flex: 1 1 auto; gap: 6px; }'; New = 'flex: 1 1 auto; gap: 16px; }' },
    @{ Id = 'M08_CATEGORY_MARGIN_BACK'; Old = $P + '.ks-card-category { margin-bottom: 4px; }'; New = $P + '.ks-card-category { margin-bottom: 14px; }' }
)

$exitCode = 0
try {
    $baseUrl = New-Fixture $themeCss 'base'
    $variants = New-Object Collections.Generic.List[object]
    if (-not $SkipMutants) {
        foreach ($mu in $mutants) {
            $count = ([regex]::Matches($themeCss, [regex]::Escape($mu.Old))).Count
            if ($count -ne 1) { $variants.Add(@{ Id = $mu.Id; Url = ''; Killed = $false; Note = 'ancora non unica (' + $count + ')' }); continue }
            $variants.Add(@{ Id = $mu.Id; Url = (New-Fixture ($themeCss.Replace($mu.Old, $mu.New)) $mu.Id); Killed = $false; Note = '' })
        }
    }
    $baseFail = New-Object Collections.Generic.List[string]
    foreach ($vp in $widths) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            Open-KsUrl $b $baseUrl 60
            $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
            $f = @(Test-Cards $r ('A' + $vp.W) 8 $true)
            foreach ($x in $f) { $baseFail.Add($x) }
            Write-Host ('  A' + $vp.W + ': schede ' + @($r.cards).Count + ', altezze ' + ((@($r.cards | ForEach-Object { $_.h } | Select-Object -Unique)) -join ',') + ', difetti ' + $f.Count)
            foreach ($v in $variants) {
                if ($v.Url -eq '' -or $v.Killed) { continue }
                Open-KsUrl $b $v.Url 60
                $rm = (Invoke-KsJs $b $measure) | ConvertFrom-Json
                if (@(Test-Cards $rm 'M' 8 $true).Count -gt 0) { $v.Killed = $true }
            }
            if (-not $SkipLab) {
                Open-KsUrl $b 'https://www.taikun.it:18843/Default.aspx' 240
                Start-Sleep -Milliseconds 1500
                $rl = (Invoke-KsJs $b $measure) | ConvertFrom-Json
                # sul sito reale le file possono essere strisce scorrevoli con schede fuori schermo: si provano i contratti della singola scheda
                $fl = @(Test-Cards $rl ('C' + $vp.W) 8 ($vp.W -ge 1200))
                foreach ($x in $fl) { $baseFail.Add($x) }
                Write-Host ('  C' + $vp.W + ' (sito LAB): schede ' + @($rl.cards).Count + ', difetti ' + $fl.Count)
            }
        } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($baseFail.Count -gt 0) { foreach ($x in ($baseFail | Select-Object -First 40)) { Write-Host ('  FAIL ' + $x) }; Write-Host ('CARD_COMPACT_SPACING FAIL: ' + $baseFail.Count); $exitCode = 1 }
    else {
        Write-Host 'CARD_COMPACT_SPACING contratti OK'
        if (-not $SkipMutants) {
            $survived = @($variants | Where-Object { -not $_.Killed } | ForEach-Object { $_.Id + $(if ($_.Note) { ' (' + $_.Note + ')' } else { '' }) })
            if ($survived.Count -gt 0) { Write-Host ('CARD_COMPACT_SPACING FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); $exitCode = 1 }
            else { Write-Host ('CARD_COMPACT_SPACING mutanti rilevati: ' + $variants.Count) }
        }
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
if ($exitCode -eq 0) { Write-Host 'CARD_COMPACT_SPACING OK' }
exit $exitCode
