[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# UX-COMPACT-SPACING-SITEWIDE-1B (seconda tranche). Richiesta del PO del 2026-11-19: nessuno spazio inutile, su tutto il sito.
#  (A) sorgenti: spazi di sezione su telefono ridotti SOLO per le pagine elencate (contatti, area personale e pagine di servizio),
#      mai con una regola su tutte le .tf-sp-2;
#  (B) schede dei correlati della scheda prodotto (.ks-product-list-section, fuori da .ks-product-page): pagina di prova statica con i
#      fogli VERI nell'ordine reale (Page.master, poi i fogli di articolo.aspx, poi theme-overrides.css): 6-14 px fra immagine e
#      categoria, 4-8 px fra le righe di testo, nella fila il minimo fra testo e pulsante visibile 6-14 px, schede e pulsanti allineati,
#      pulsante mobile di almeno 44 px, nessuno scorrimento orizzontale; a 390 e 1280 px;
#  (C) mutazioni del foglio eseguite nel browser; (D) sito LAB reale (https, 127.0.0.1, porta 18843). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$assets = Join-Path $root 'Public\assets\keepstore'
$productCss = [IO.File]::ReadAllText((Join-Path $assets 'css\product-ui.css'), $utf8)
$themeCss = [IO.File]::ReadAllText((Join-Path $assets 'css\theme-overrides.css'), $utf8)
$master = [IO.File]::ReadAllText((Join-Path $root 'Page.master'), $utf8)
$pdp = [IO.File]::ReadAllText((Join-Path $root 'articolo.aspx'), $utf8)
$work = Join-Path $env:TEMP ('ks-relatedspacing-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
function ConvertTo-FileUrl([string]$path) { return 'file:///' + ($path -replace '\\', '/') }
function Norm([string]$s) { return ($s -replace "`r`n", "`n") }

# ---------------------------------------------------------------- (A) sorgenti
function Test-Source([string]$theme, [string]$product) {
    $fail = New-Object Collections.Generic.List[string]
    $t = Norm $theme; $p = Norm $product
    $block = [regex]::Match($t, '(?s)/\* ===== UX-COMPACT-SPACING-SITEWIDE-1B.*?(?=/\* ===== KS-A04-HOME-VETRINA-1A)').Value
    if ($block -eq '') { $fail.Add('S01 blocco della seconda tranche assente'); return $fail }
    $expected = "@media (max-width: 767.98px) {`n  .ks-contact > section.tf-sp-2,`n  .ks-myaccount > section.tf-sp-2,`n  .ks-address-page > section.tf-sp-2 { padding-top: 24px; padding-bottom: 32px; }`n}"
    if (-not $block.Contains($expected)) { $fail.Add('S02 spazi di sezione su telefono solo per le pagine elencate') }
    # nessuna regola che tocchi TUTTE le .tf-sp-2 (ne nel tema ne nel foglio della scheda prodotto, fuori dalla stampa)
    if ($block -match '(?m)^\s*\.tf-sp-2\s*[,{]' -or $block -match '\.ks-account-main\s+\.tf-sp-2') { $fail.Add('S03 regola su tutte le sezioni') }
    if (([regex]::Matches(($block -replace '(?s)/\*.*?\*/', ''), 'tf-sp-2')).Count -ne 3) { $fail.Add('S03 sezioni toccate diverse dalle tre previste') }
    if (-not $t.Contains('body.ks-page-home #ksHomePage .ks-grid-card { gap: 10px; }')) { $fail.Add('S04 distanza immagine-testo nelle griglie HOME') }
    if (-not $p.Contains("  .ks-product-list-section.tf-sp-2 {`n    padding-bottom: 32px;`n  }")) { $fail.Add('S05 fondo delle sezioni dei correlati su telefono') }
    return $fail
}
$sourceFail = @(Test-Source $themeCss $productCss)

# ---------------------------------------------------------------- (B) pagina di prova
function New-Fixture([string]$productText, [string]$name) {
    $productFile = Join-Path $work ($name + '.css')
    [IO.File]::WriteAllText($productFile, $productText, $utf8)
    $head = New-Object Text.StringBuilder
    $seenProduct = $false; $seenTheme = $false
    foreach ($m in [regex]::Matches($master, '<link rel="stylesheet" href="<%= ThemeManager\.Asset\("([^"]+)"\)[^>]*>|<asp:ContentPlaceHolder ID="HeadContent" runat="server" />')) {
        if ($m.Value.StartsWith('<asp:')) {
            $headContent = [regex]::Match($pdp, '(?s)ContentPlaceHolderID="HeadContent"[^>]*>(.*?)</asp:Content>').Groups[1].Value
            foreach ($l in [regex]::Matches($headContent, '<link rel="stylesheet" href="<%= ThemeManager\.Asset\("([^"]+)"\)')) {
                $rel = $l.Groups[1].Value
                if ($rel -eq 'css/product-ui.css') { $seenProduct = $true; $null = $head.AppendLine('<link rel="stylesheet" href="' + (ConvertTo-FileUrl $productFile) + '">') }
                else { $null = $head.AppendLine('<link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets ($rel -replace '/', '\'))) + '">') }
            }
            continue
        }
        $rel = $m.Groups[1].Value
        if ($rel -eq 'css/theme-overrides.css') { if (-not $seenProduct) { throw 'ORDER_CHANGED_THEME_BEFORE_PRODUCT_SHEET' }; $seenTheme = $true }
        $null = $head.AppendLine('<link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets ($rel -replace '/', '\'))) + '">')
    }
    if (-not $seenProduct -or -not $seenTheme) { throw 'STYLESHEETS_NOT_FOUND' }
    $cases = @(
        @{ Cat = 'Pen Drive USB Type-A'; Title = 'PEN DRIVE USB 3.2 KINGSTON DTKN/32GB DataTraveler Kyson METAL'; Price = '12,99'; Old = '20,00' },
        @{ Cat = 'Accessori per stampanti multifunzione laser e a getto di inchiostro professionali'; Title = 'CAVO HDMI'; Price = '3,50'; Old = '' },
        @{ Cat = ''; Title = 'MONITOR 27 POLLICI CURVO WQHD SAMSUNG Odyssey G5 C27G55 GAMING 144Hz HDMI DisplayPort REGOLABILE'; Price = '1.329,99'; Old = '1.379,90' },
        @{ Cat = 'Tablet'; Title = 'TABLET LENOVO Tab M11 TB330FU WiFi + Tab Pen'; Price = '194,99'; Old = '' },
        @{ Cat = 'Carta in Risma'; Title = 'RISMA CARTA A4 80gr 500fg'; Price = '5,00'; Old = '6,00' }
    )
    $img = ConvertTo-FileUrl (Join-Path $root 'Public\assets\images\img\placeholder.svg')
    $slides = New-Object Text.StringBuilder
    foreach ($c in $cases) {
        $old = if ($c.Old -ne '') { '<span class="old-price body-md-2 text-main-2 fw-normal">' + $c.Old + '</span>' } else { '' }
        # larghezza della scheda fissata nella sola pagina di prova: senza JavaScript il carosello non la calcola
        $null = $slides.Append('<div class="swiper-slide" style="width:var(--ks-test-slide);margin-right:15px"><div class="card-product style-img-border"><div class="card-product-wrapper"><a class="product-img is-loaded" href="#"><img class="img-product" alt="" src="' + $img + '"></a></div>')
        $null = $slides.Append('<div class="card-product-info"><div class="box-title"><p class="caption text-main-2 font-2 ks-card-category ks-pdp-card-category">' + $c.Cat + '</p><a class="name-product body-md-2 fw-semibold text-secondary link ks-card-title ks-pdp-card-title" href="#">' + $c.Title + '</a>')
        $null = $slides.Append('<div class="price-wrap fw-medium"><span class="new-price price-text fw-medium mb-0">' + $c.Price + '</span>' + $old + '</div><span class="ks-availability ks-availability--synthetic" role="status"><span class="ks-availability__status is-ok"><span class="ks-availability__dot" aria-hidden="true"></span><span class="ks-availability__status-text">Disponibile</span></span></span></div>')
        $null = $slides.AppendLine('<button type="button" class="tf-btn text-white w-100 ks-mobile-card-buy-cta js-ks-cart-link"><span class="icon-cart-2" aria-hidden="true"></span> <span>Acquista</span></button><div class="card-product-btn"><a class="tf-btn btn-line w-100" href="#"><span>Vedi prodotto</span> <i class="icon-view"></i></a></div></div></div></div>')
    }
    $html = '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' + $head.ToString() +
            '<style>:root{--ks-test-slide:172px}@media (min-width:768px){:root{--ks-test-slide:216px}}</style></head><body id="PageBody" class="color-primary ks-theme-keepstore"><main><div class="ks-account-shell"><div class="ks-account-main">' +
            '<section id="prd-similar" class="tf-sp-2 pt-0 ks-product-list-section ks-similar-products-section"><div class="container"><div class="swiper tf-sw-products ks-product-relation-swiper"><div class="swiper-wrapper">' +
            $slides.ToString() + '</div></div></div></section></div></div></main></body></html>'
    $file = Join-Path $work ($name + '.html')
    [IO.File]::WriteAllText($file, $html, $utf8)
    return (ConvertTo-FileUrl $file)
}

$measure = "(function(){var out=[];var sec=document.querySelector('.ks-product-list-section');var cards=document.querySelectorAll('.ks-product-list-section .swiper-slide > .card-product');" +
    "for(var i=0;i<cards.length;i++){var c=cards[i],rc=c.getBoundingClientRect();if(rc.width<=0){continue;}" +
    "var wr=c.querySelector('.card-product-wrapper'),cat=c.querySelector('.ks-card-category'),ti=c.querySelector('.ks-card-title'),pw=c.querySelector('.price-wrap'),av=c.querySelector('.box-title > .ks-availability'),bt=c.querySelector('.box-title');" +
    "var btn=null,bs=c.querySelectorAll('.ks-mobile-card-buy-cta,.card-product-btn');for(var k=0;k<bs.length;k++){var q=bs[k].getBoundingClientRect();if(q.height>0&&getComputedStyle(bs[k]).display!=='none'){btn=bs[k];break;}}" +
    "if(!wr||!cat||!ti||!pw||!bt){out.push({missing:true});continue;}" +
    "var rw=wr.getBoundingClientRect(),rcat=cat.getBoundingClientRect(),rti=ti.getBoundingClientRect(),rpw=pw.getBoundingClientRect(),rav=av?av.getBoundingClientRect():null,rbt=bt.getBoundingClientRect(),rb=btn?btn.getBoundingClientRect():null;" +
    "out.push({missing:false,hasAv:!!rav,hasBtn:!!rb,top:Math.round(rc.top),h:Math.round(rc.height),imgCat:rcat.top-rw.bottom,catTitle:rti.top-rcat.bottom,titlePrice:rpw.top-rti.bottom,priceAvail:rav?rav.top-rpw.bottom:5,textBtn:rb?rb.top-rbt.bottom:10,btnTop:rb?Math.round(rb.top-rc.top):0,btnH:rb?rb.height:44,mobileBtn:btn?btn.classList.contains('ks-mobile-card-buy-cta'):false,inside:rb?(rb.bottom<=rc.bottom+1):true});}" +
    "var ss=sec?getComputedStyle(sec):null;return JSON.stringify({cards:out,padBottom:ss?parseFloat(ss.paddingBottom):-1,scroll:document.documentElement.scrollWidth-window.innerWidth});})()"

function Test-Cards($r, [string]$tag, [int]$minimum, [bool]$withButton, [bool]$checkScroll) {
    $fail = New-Object Collections.Generic.List[string]
    $cards = @($r.cards)
    if ($cards.Count -lt $minimum) { $fail.Add($tag + ' schede misurate: ' + $cards.Count + ' (minimo ' + $minimum + ')') }
    $n = 0
    foreach ($c in $cards) {
        $n++
        if ($c.missing) { $fail.Add($tag + ' scheda ' + $n + ' senza un elemento atteso'); continue }
        if ($c.imgCat -lt 6 -or $c.imgCat -gt 14) { $fail.Add($tag + ' scheda ' + $n + ' spazio fra immagine e categoria: ' + [Math]::Round($c.imgCat, 1) + ' px') }
        foreach ($g in @(@('categoria e titolo', $c.catTitle), @('titolo e prezzo', $c.titlePrice), @('prezzo e disponibilita', $c.priceAvail))) {
            if ($g[1] -lt 4 -or $g[1] -gt 8) { $fail.Add($tag + ' scheda ' + $n + ' spazio fra ' + $g[0] + ': ' + [Math]::Round($g[1], 1) + ' px') }
        }
        if ($withButton) {
            if (-not $c.hasAv -or -not $c.hasBtn) { $fail.Add($tag + ' scheda ' + $n + ' senza disponibilita o pulsante') }
            if ($c.textBtn -lt 6) { $fail.Add($tag + ' scheda ' + $n + ' pulsante attaccato al testo: ' + [Math]::Round($c.textBtn, 1) + ' px') }
            if ($c.mobileBtn -and $c.btnH -lt 44) { $fail.Add($tag + ' scheda ' + $n + ' pulsante mobile sotto 44 px: ' + [Math]::Round($c.btnH, 1)) }
            if (-not $c.inside) { $fail.Add($tag + ' scheda ' + $n + ' pulsante fuori dalla scheda') }
        }
    }
    $ok = @($cards | Where-Object { -not $_.missing })
    if ($withButton -and $ok.Count -ge 2) {
        foreach ($grp in ($ok | Group-Object top)) {
            $g = @($grp.Group); if ($g.Count -lt 2) { continue }
            foreach ($prop in @('h', 'btnTop')) {
                $vals = @($g | ForEach-Object { $_.$prop })
                if ((($vals | Measure-Object -Maximum).Maximum - ($vals | Measure-Object -Minimum).Minimum) -gt 1) { $fail.Add($tag + ' fila non allineata (' + $prop + '): ' + ($vals -join ',')) }
            }
            $minGap = ($g | ForEach-Object { $_.textBtn } | Measure-Object -Minimum).Minimum
            if ($minGap -gt 14) { $fail.Add($tag + ' vuoto fra testo e pulsante anche nella scheda piu piena: ' + [Math]::Round($minGap, 1) + ' px') }
        }
    }
    if ($checkScroll -and $r.scroll -gt 1) { $fail.Add($tag + ' scorrimento orizzontale di ' + $r.scroll + ' px') }
    return $fail
}

$nl = "`r`n"; if (-not $productCss.Contains($nl)) { $nl = "`n" }
$mutants = @(
    @{ Id = 'M01_MOBILE_PADDING_BACK'; Old = '  .ks-product-list-section.tf-sp-2 {'; New = '  .ks-product-list-section .card-product-info {' + $nl + '    padding-top: 10px;' + $nl + '  }' + $nl + $nl + '  .ks-product-list-section.tf-sp-2 {' },
    @{ Id = 'M02_WEAK_ROW_SELECTOR'; Old = '.ks-product-list-section .card-product-info .box-title {'; New = '.ks-product-list-section .box-title {' },
    @{ Id = 'M03_CARD_GAP_BACK'; Old = '  flex-direction: column;' + $nl + '  gap: 10px;' + $nl + '  height: 100%;'; New = '  flex-direction: column;' + $nl + '  height: 100%;' },
    @{ Id = 'M04_INFO_PADDING_BACK'; Old = '  gap: 10px;' + $nl + '  min-width: 0;' + $nl + '  padding-top: 0;'; New = '  gap: 10px;' + $nl + '  min-width: 0;' + $nl + '  padding-top: 10px;' },
    @{ Id = 'M05_INFO_GAP_BACK'; Old = '  gap: 10px;' + $nl + '  min-width: 0;' + $nl + '  padding-top: 0;'; New = '  min-width: 0;' + $nl + '  padding-top: 0;' },
    @{ Id = 'M07_BUTTON_NOT_ANCHORED'; Old = '    margin-top: auto;' + $nl + '    min-height: 44px;'; New = '    margin-top: 0;' + $nl + '    min-height: 44px;' }
)
$sourceMutants = @(
    @{ Id = 'S-M01_ALL_SECTIONS'; Old = '  .ks-contact > section.tf-sp-2,'; New = '  .tf-sp-2,' + $nl + '  .ks-contact > section.tf-sp-2,' },
    @{ Id = 'S-M02_ACCOUNT_MAIN_SCOPE'; Old = '  .ks-contact > section.tf-sp-2,'; New = '  .ks-account-main .tf-sp-2,' },
    @{ Id = 'S-M03_HOME_GAP_BACK'; Old = 'body.ks-page-home #ksHomePage .ks-grid-card { gap: 10px; }'; New = 'body.ks-page-home #ksHomePage .ks-grid-card { gap: 20px; }' }
)

$exitCode = 0
try {
    if ($sourceFail.Count -gt 0) { foreach ($x in $sourceFail) { Write-Host ('  FAIL ' + $x) } }
    $baseUrl = New-Fixture $productCss 'base'
    $variants = New-Object Collections.Generic.List[object]
    if (-not $SkipMutants) {
        foreach ($mu in $mutants) {
            $count = ([regex]::Matches($productCss, [regex]::Escape($mu.Old))).Count
            if ($count -ne 1) { $variants.Add(@{ Id = $mu.Id; Url = ''; Killed = $false; Note = 'ancora non unica (' + $count + ')' }); continue }
            $variants.Add(@{ Id = $mu.Id; Url = (New-Fixture ($productCss.Replace($mu.Old, $mu.New)) $mu.Id); Killed = $false; Note = '' })
        }
    }
    $baseFail = New-Object Collections.Generic.List[string]
    foreach ($x in $sourceFail) { $baseFail.Add($x) }
    foreach ($vp in @(@{ W = 390; H = 844; M = $true }, @{ W = 1280; H = 900; M = $false })) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            Open-KsUrl $b $baseUrl 60
            $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
            $f = @(Test-Cards $r ('B' + $vp.W) 5 $true $false)
            if ($vp.M -and $r.padBottom -ne 32) { $f += ('B390 fondo della sezione dei correlati: ' + $r.padBottom + ' px') }
            foreach ($x in $f) { $baseFail.Add($x) }
            Write-Host ('  B' + $vp.W + ': schede ' + @($r.cards).Count + ', altezze ' + ((@($r.cards | ForEach-Object { $_.h } | Select-Object -Unique)) -join ',') + ', difetti ' + @($f).Count)
            foreach ($v in $variants) {
                if ($v.Url -eq '' -or $v.Killed) { continue }
                Open-KsUrl $b $v.Url 60
                $rm = (Invoke-KsJs $b $measure) | ConvertFrom-Json
                if (@(Test-Cards $rm 'M' 5 $true $false).Count -gt 0) { $v.Killed = $true }
            }
            if (-not $SkipLab) {
                Open-KsUrl $b 'https://www.taikun.it:18843/articolo.aspx?id=20033' 240
                Start-Sleep -Milliseconds 2000
                $rl = (Invoke-KsJs $b $measure) | ConvertFrom-Json
                $fl = @(Test-Cards $rl ('D' + $vp.W) 3 $false $true)
                foreach ($x in $fl) { $baseFail.Add($x) }
                Write-Host ('  D' + $vp.W + ' (sito LAB, scheda prodotto): schede ' + @($rl.cards).Count + ', difetti ' + $fl.Count)
                if ($vp.M) {
                    Open-KsUrl $b 'https://www.taikun.it:18843/contattaci.aspx' 240
                    $pad = Invoke-KsJs $b "(function(){var s=document.querySelector('.ks-contact > section.tf-sp-2');if(!s){return 'assente';}var c=getComputedStyle(s);return c.paddingTop+'/'+c.paddingBottom;})()"
                    if ($pad -ne '24px/32px') { $baseFail.Add('D390 contatti, spazi di sezione: ' + $pad) }
                    Write-Host ('  D390 (sito LAB, contatti): spazi di sezione ' + $pad)
                }
            }
        } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($baseFail.Count -gt 0) { foreach ($x in ($baseFail | Select-Object -First 30)) { Write-Host ('  FAIL ' + $x) }; Write-Host ('RELATED_CARDS_COMPACT FAIL: ' + $baseFail.Count); $exitCode = 1 }
    else {
        Write-Host 'RELATED_CARDS_COMPACT contratti OK'
        if (-not $SkipMutants) {
            $survived = New-Object Collections.Generic.List[string]
            foreach ($v in $variants) { if (-not $v.Killed) { $survived.Add($v.Id + $(if ($v.Note) { ' (' + $v.Note + ')' } else { '' })) } }
            foreach ($mu in $sourceMutants) {
                if (([regex]::Matches($themeCss, [regex]::Escape($mu.Old))).Count -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
                if (@(Test-Source ($themeCss.Replace($mu.Old, $mu.New)) $productCss).Count -eq 0) { $survived.Add($mu.Id) }
            }
            if ($survived.Count -gt 0) { Write-Host ('RELATED_CARDS_COMPACT FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); $exitCode = 1 }
            else { Write-Host ('RELATED_CARDS_COMPACT mutanti rilevati: ' + ($variants.Count + $sourceMutants.Count)) }
        }
    }
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
if ($exitCode -eq 0) { Write-Host 'RELATED_CARDS_COMPACT OK' }
exit $exitCode
