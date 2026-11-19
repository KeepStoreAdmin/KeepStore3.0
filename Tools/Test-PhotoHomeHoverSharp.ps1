[CmdletBinding()]
param([switch]$SkipBrowser, [switch]$SkipMutants)

# PHOTO-HOME-HOVER-SHARP-1A (sistema per le foto, docs/KEEPSTORE_PRODUCT_PHOTOS_SYSTEM_2026_11_20.md, regola 3.1).
# Nelle schede della HOME la seconda immagine (visibile al passaggio del mouse) usava una miniatura da 150 px in un riquadro da
# 206-244 px. Regole provate:
#  - la miniatura resta l'immagine di partenza (leggera); la foto piena viaggia in un attributo solo quando e diversa;
#  - lo script la carica al PRIMO passaggio del mouse (o della penna), la precarica a parte e la sostituisce solo se arriva,
#    aggiornando insieme src e data-src (il caricamento differito non puo rimettere la miniatura);
#  - con il tocco non si carica nulla; indirizzi non locali non si caricano; un errore lascia la miniatura; una sola richiesta.
# (A) sorgenti, (B) pagina di prova con script e fogli VERI e immagini create sul momento, pilotata con mouse e tocco veri,
# (C) mutazioni dello script eseguite nel browser e del markup sui sorgenti. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$assets = Join-Path $root 'Public\assets\keepstore'
$vb = [IO.File]::ReadAllText((Join-Path $root 'Default.aspx.vb'), $utf8)
$aspx = [IO.File]::ReadAllText((Join-Path $root 'Default.aspx'), $utf8)
$js = [IO.File]::ReadAllText((Join-Path $assets 'js\home-default.js'), $utf8)
function Count-Of([string]$text, [string]$needle) { return ([regex]::Matches($text, [regex]::Escape($needle))).Count }
function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i + $end.Length)
}

function Test-Source([string]$v, [string]$a, [string]$script) {
    $fail = New-Object Collections.Generic.List[string]
    $card = Get-Block $v 'Protected Function RenderGridCard(' 'End Function'
    # S01 la foto piena e la miniatura vengono dalla stessa fonte; l'attributo solo quando sono diverse, codificato
    if (-not $card.Contains('Dim hoverFull As String = StorefrontProductImageSlots.HoverUrl(row)')) { $fail.Add('S01 foto piena dalla seconda immagine della scheda') }
    if (-not $card.Contains('Dim hoverShown As String = ProductImageThumb(hoverFull)')) { $fail.Add('S01 la miniatura resta l''immagine di partenza') }
    $attrLine = 'If Not String.Equals(hoverFull, hoverShown, StringComparison.Ordinal) Then sb.Append("' + [char]39 + ' data-ks-hover-full=' + [char]39 + '").Append(EncodeAttr(hoverFull))'
    if (-not $card.Contains($attrLine)) { $fail.Add('S01 attributo solo quando la foto piena e diversa, codificato') }
    if ((Count-Of $v 'data-ks-hover-full') -ne 1) { $fail.Add('S01 un solo punto che scrive l''attributo') }
    # S02 markup esistente intatto (altri test lo cercano)
    if (-not $card.Contains("<img class='img-hover lazyload' loading='lazy' decoding='async' src='"").Append(EncodeAttr(hoverShown)).Append(""' data-src='"").Append(EncodeAttr(hoverShown))") -or -not $card.Contains("sb.Append(""' alt='' aria-hidden='true'>"")")) { $fail.Add('S02 markup della seconda immagine invariato') }
    # S03 script: registrazione unica a livello di modulo, fuori dall'inizializzazione della HOME
    if ((Count-Of $script 'window.__ksHomeHoverFullBound') -ne 2) { $fail.Add('S03 guardia contro la doppia registrazione') }
    $init = Get-Block $script 'function initHome() {' 'ready(initHome);'
    if ($init -eq '' -or $init.Contains('data-ks-hover-full') -or $init.Contains('__ksHomeHoverFullBound')) { $fail.Add('S03 nessuna registrazione dentro l''inizializzazione della HOME') }
    if (-not $init.Contains("    try {`r`n      initHomeSwipers();`r`n      initDepartmentsMenu();`r`n    } finally {`r`n      initShoppingGuide();`r`n    }") -and -not $init.Contains("    try {`n      initHomeSwipers();`n      initDepartmentsMenu();`n    } finally {`n      initShoppingGuide();`n    }")) { $fail.Add('S03 blocco di inizializzazione della HOME invariato') }
    # S04 nuova sigla dello script nella pagina
    if ($a -notmatch 'js/home-default\.js"\) & "\?v=20261120-hover-full1a"') { $fail.Add('S04 sigla dello script aggiornata') }
    return $fail
}

$sourceFail = @(Test-Source $vb $aspx $js)
foreach ($x in $sourceFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFail.Count -gt 0) { Write-Host 'PHOTO_HOME_HOVER_SHARP FAIL (sorgenti)'; if ($SkipBrowser) { exit 1 } } else { Write-Host 'PHOTO_HOME_HOVER_SHARP sorgenti OK' }

# ---------------------------------------------------------------- (B) pagina di prova
$work = Join-Path $env:TEMP ('ks-hoverfull-' + [Guid]::NewGuid().ToString('N'))
function ConvertTo-FileUrl([string]$path) { return 'file:///' + ($path -replace '\\', '/') }
function ConvertTo-LocalPath([string]$path) { return '/' + ($path -replace '\\', '/') }
function New-TestImage([string]$path, [int]$side, [Drawing.Color]$color) {
    $bmp = New-Object Drawing.Bitmap $side, $side
    $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::White)
    $brush = New-Object Drawing.SolidBrush $color
    $step = [Math]::Max(6, [int]($side / 12)); for ($i = 0; $i -lt $side; $i += 2 * $step) { $g.FillRectangle($brush, $i, [int]($side / 4), $step, [int]($side / 2)) }
    $g.Dispose(); $brush.Dispose(); $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
function New-Fixture([string]$scriptText, [string]$name, [bool]$lazyInit) {
    $scriptFile = Join-Path $work ($name + '.js')
    [IO.File]::WriteAllText($scriptFile, $scriptText, $utf8)
    $cover = ConvertTo-LocalPath (Join-Path $work 'cover.png'); $thumb = ConvertTo-LocalPath (Join-Path $work '_hover.png'); $full = ConvertTo-LocalPath (Join-Path $work 'hover.png')
    $missing = ConvertTo-LocalPath (Join-Path $work 'manca.png')
    $cards = New-Object Text.StringBuilder
    $defs = @(
        @{ Id = 'ok'; Full = " data-ks-hover-full='$full'" },
        @{ Id = 'missing'; Full = " data-ks-hover-full='$missing'" },
        @{ Id = 'external'; Full = " data-ks-hover-full='https://example.invalid/x.png'" },
        @{ Id = 'protocol'; Full = " data-ks-hover-full='//example.invalid/x.png'" },
        @{ Id = 'none'; Full = '' }
    )
    foreach ($d in $defs) {
        $null = $cards.AppendLine("<div class='card-product style-img-border ks-grid-card' id='card-$($d.Id)'><div class='card-product-wrapper'><a href='#' class='product-img'><img class='img-product lazyload' decoding='async' src='$cover' data-src='$cover' alt='prodotto'><img class='img-hover lazyload' loading='lazy' decoding='async' src='$thumb' data-src='$thumb' alt='' aria-hidden='true'$($d.Full)></a></div><div class='card-product-info'><div class='box-title'><p class='caption ks-card-category'>Categoria</p><a href='#' class='name-product ks-card-title'>Prodotto di prova</a></div></div></div>")
    }
    $counter = "<script>window.__ksImgLoads=[];(function(){var N=window.Image,d=Object.getOwnPropertyDescriptor(HTMLImageElement.prototype,'src');window.Image=function(){var i=new N();Object.defineProperty(i,'src',{configurable:true,set:function(v){window.__ksImgLoads.push(String(v).split('/').pop());d.set.call(i,v);},get:function(){return d.get.call(i);}});return i;};})();</script>"
    $cfg = $counter + $(if ($lazyInit) { '' } else { '<script>window.lazySizesConfig = { init: false };</script>' })
    $html = '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
            '<link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets 'css\bootstrap.min.css')) + '"><link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets 'css\styles.css')) + '"><link rel="stylesheet" href="' + (ConvertTo-FileUrl (Join-Path $assets 'css\theme-overrides.css')) + '">' +
            '</head><body id="PageBody" class="ks-page-home ks-home-main ks-theme-keepstore"><main><section id="ksHomePage" class="ks-home-main"><section class="ks-home-section ks-home-featured"><div class="container"><div class="ks-home-product-grid">' +
            $cards.ToString() + '</div></div></section></section></main>' + $cfg +
            '<script src="' + (ConvertTo-FileUrl (Join-Path $assets 'js\lazysize.min.js')) + '"></script><script src="' + (ConvertTo-FileUrl $scriptFile) + '"></script></body></html>'
    $file = Join-Path $work ($name + $(if ($lazyInit) { '-a' } else { '-b' }) + '.html')
    [IO.File]::WriteAllText($file, $html, $utf8)
    return (ConvertTo-FileUrl $file)
}
$state = "(function(){function one(id){var c=document.getElementById('card-'+id);if(!c){return null;}var i=c.querySelector('img.img-hover'),w=c.querySelector('.card-product-wrapper').getBoundingClientRect();" +
    "return {state:i.getAttribute('data-ks-hover-state')||'',src:(i.currentSrc||i.src||'').split('/').pop(),dataSrc:(i.getAttribute('data-src')||'').split('/').pop(),nat:i.naturalWidth,box:Math.round(w.width),x:Math.round(w.left+w.width/2),y:Math.round(w.top+w.height/2),cover:(c.querySelector('img.img-product').currentSrc||'').split('/').pop()};}" +
    "var res=(window.__ksImgLoads||[]);function n(f){return res.filter(function(x){return x===f;}).length;}" +
    "return JSON.stringify({ok:one('ok'),missing:one('missing'),external:one('external'),protocol:one('protocol'),none:one('none'),fullRequests:n('hover.png'),missingRequests:n('manca.png'),externalRequests:n('x.png'),dpr:window.devicePixelRatio});})()"

function Move-Mouse($b, [int]$x, [int]$y) { $null = Invoke-KsCdp $b 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $x; y = $y; pointerType = 'mouse' } }
function Wait-State($b, [string]$id, [string[]]$wanted) {
    for ($i = 0; $i -lt 40; $i++) { $s = (Invoke-KsJs $b $state) | ConvertFrom-Json; if ($wanted -contains $s.$id.state) { return $s }; Start-Sleep -Milliseconds 150 }
    return ((Invoke-KsJs $b $state) | ConvertFrom-Json)
}
# Esegue tutte le prove di comportamento su uno script (quello vero o un mutante) e restituisce i difetti.
function Test-Behaviour([string]$scriptText, [string]$name) {
    $fail = New-Object Collections.Generic.List[string]
    $urlA = New-Fixture $scriptText $name $true
    $urlB = New-Fixture $scriptText $name $false
    $b = $null
    try {
        # --- mouse, caricamento differito gia eseguito
        $b = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1280 -Height 900 -ExtraArgs '--allow-file-access-from-files'
        Open-KsUrl $b $urlA 60; Start-Sleep -Milliseconds 900
        Move-Mouse $b 2 2
        $s0 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($s0.ok.nat -ne 150 -or $s0.fullRequests -ne 0 -or $s0.ok.state -ne '') { $fail.Add('B01 prima del passaggio: miniatura da 150 px, nessuna richiesta della foto piena (nat ' + $s0.ok.nat + ', richieste ' + $s0.fullRequests + ')') }
        if ($s0.ok.box -lt 180) { $fail.Add('B01 riquadro della scheda non realistico: ' + $s0.ok.box + ' px') }
        Move-Mouse $b $s0.ok.x $s0.ok.y
        $s1 = Wait-State $b 'ok' @('done', 'failed')
        if ($s1.ok.state -ne 'done' -or $s1.ok.src -ne 'hover.png' -or $s1.ok.dataSrc -ne 'hover.png') { $fail.Add('B02 dopo il passaggio: foto piena in src e data-src (stato ' + $s1.ok.state + ', src ' + $s1.ok.src + ', data-src ' + $s1.ok.dataSrc + ')') }
        if ($s1.ok.nat -lt [int]($s1.ok.box * 1.05 * $s1.dpr)) { $fail.Add('B02 foto piu piccola del riquadro dipinto: ' + $s1.ok.nat + ' px per ' + $s1.ok.box) }
        if ($s1.ok.cover -ne 'cover.png') { $fail.Add('B02 la prima immagine non deve cambiare') }
        for ($k = 0; $k -lt 3; $k++) { Move-Mouse $b 2 2; Move-Mouse $b $s0.ok.x $s0.ok.y }
        Start-Sleep -Milliseconds 400
        $s2 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($s2.fullRequests -ne 1) { $fail.Add('B03 una sola richiesta della foto piena anche con passaggi ripetuti: ' + $s2.fullRequests) }
        # foto piena inesistente: resta la miniatura
        Move-Mouse $b $s0.missing.x $s0.missing.y
        $s3 = Wait-State $b 'missing' @('failed', 'done')
        if ($s3.missing.state -ne 'failed' -or $s3.missing.src -ne '_hover.png' -or $s3.missing.dataSrc -ne '_hover.png' -or $s3.missing.nat -ne 150) { $fail.Add('B04 foto piena inesistente: resta la miniatura (stato ' + $s3.missing.state + ', src ' + $s3.missing.src + ')') }
        # indirizzi non locali: mai caricati
        Move-Mouse $b $s0.external.x $s0.external.y; Start-Sleep -Milliseconds 250
        Move-Mouse $b $s0.protocol.x $s0.protocol.y; Start-Sleep -Milliseconds 250
        $s4 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($s4.external.state -ne 'blocked' -or $s4.protocol.state -ne 'blocked' -or $s4.external.src -ne '_hover.png' -or $s4.protocol.src -ne '_hover.png' -or $s4.externalRequests -ne 0) { $fail.Add('B05 indirizzi non locali rifiutati (stati ' + $s4.external.state + ', ' + $s4.protocol.state + ')') }
        Move-Mouse $b $s0.none.x $s0.none.y; Start-Sleep -Milliseconds 250
        $s5 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($s5.none.state -ne '' -or $s5.none.src -ne '_hover.png') { $fail.Add('B06 scheda senza attributo: nessun cambio') }
        # --- mouse PRIMA del caricamento differito
        Open-KsUrl $b $urlB 60; Start-Sleep -Milliseconds 700
        Move-Mouse $b 2 2
        $t0 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        Move-Mouse $b $t0.ok.x $t0.ok.y
        $null = Wait-State $b 'ok' @('done', 'failed')
        $null = Invoke-KsJs $b "(function(){if(window.lazySizes){window.lazySizes.init();}return 'ok';})()"
        Start-Sleep -Milliseconds 1200
        $t1 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($t1.ok.state -ne 'done' -or $t1.ok.src -ne 'hover.png' -or $t1.ok.nat -lt 1000) { $fail.Add('B07 il caricamento differito non deve rimettere la miniatura (src ' + $t1.ok.src + ', nat ' + $t1.ok.nat + ')') }
        Stop-KsBrowser $b; $b = $null
        # --- tocco: nessun caricamento
        $b = Start-KsBrowser -LoopbackHosts @('localhost') -Width 390 -Height 844 -Mobile -ExtraArgs '--allow-file-access-from-files'
        $null = Invoke-KsCdp $b 'Emulation.setTouchEmulationEnabled' @{ enabled = $true; maxTouchPoints = 5 }
        Open-KsUrl $b $urlA 60; Start-Sleep -Milliseconds 900
        $u0 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        $null = Invoke-KsCdp $b 'Input.dispatchTouchEvent' @{ type = 'touchStart'; touchPoints = @(@{ x = $u0.ok.x; y = $u0.ok.y }) }
        Start-Sleep -Milliseconds 120
        $null = Invoke-KsCdp $b 'Input.dispatchTouchEvent' @{ type = 'touchEnd'; touchPoints = @() }
        Start-Sleep -Milliseconds 900
        $u1 = (Invoke-KsJs $b $state) | ConvertFrom-Json
        if ($u1.ok.state -ne '' -or $u1.fullRequests -ne 0 -or $u1.ok.src -ne '_hover.png') { $fail.Add('B08 con il tocco nessun caricamento della foto piena (stato ' + $u1.ok.state + ', richieste ' + $u1.fullRequests + ')') }
    } catch { $fail.Add('B00 ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
    return $fail
}

$exitCode = 0
if (-not $SkipBrowser) {
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    Add-Type -AssemblyName System.Drawing
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        New-TestImage (Join-Path $work 'cover.png') 1200 ([Drawing.Color]::SteelBlue)
        New-TestImage (Join-Path $work 'hover.png') 1200 ([Drawing.Color]::Firebrick)
        New-TestImage (Join-Path $work '_hover.png') 150 ([Drawing.Color]::Firebrick)
        $behaviour = @(Test-Behaviour $js 'base')
        foreach ($x in $behaviour) { Write-Host ('  FAIL ' + $x) }
        if ($behaviour.Count -gt 0) { Write-Host 'PHOTO_HOME_HOVER_SHARP FAIL (comportamento)'; $exitCode = 1 }
        else {
            Write-Host 'PHOTO_HOME_HOVER_SHARP comportamento OK (mouse, ripetizioni, foto mancante, indirizzi non locali, caricamento differito, tocco)'
            if (-not $SkipMutants -and $sourceFail.Count -eq 0) {
                $jsMutants = @(
                    @{ Id = 'J01_ONLY_SRC'; Old = "img.setAttribute('data-src', full);"; New = '' },
                    @{ Id = 'J02_NO_PRELOAD'; Old = 'loader.src = full;'; New = "img.setAttribute('data-src', full); img.src = full; loader.src = full;" },
                    @{ Id = 'J03_NO_POINTER_FILTER'; Old = "if (e.pointerType !== 'mouse' && e.pointerType !== 'pen') return;"; New = '' },
                    @{ Id = 'J04_USES_COVER'; Old = "wrap.querySelector('img.img-hover[data-ks-hover-full]')"; New = "wrap.querySelector('img.img-product[data-ks-hover-full]')" },
                    @{ Id = 'J05_ACCEPTS_EXTERNAL'; Old = "if (!isLocalUrl(full)) {"; New = 'if (false) {' },
                    @{ Id = 'J06_PROTOCOL_RELATIVE'; Old = "value.charAt(1) !== '/'"; New = 'true' },
                    @{ Id = 'J07_STATE_NOT_KEPT'; Old = "img.setAttribute('data-ks-hover-state', 'done');"; New = "img.removeAttribute('data-ks-hover-state');" }
                )
                $survived = New-Object Collections.Generic.List[string]
                foreach ($mu in $jsMutants) {
                    if ((Count-Of $js $mu.Old) -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
                    if (@(Test-Behaviour ($js.Replace($mu.Old, $mu.New)) $mu.Id).Count -eq 0) { $survived.Add($mu.Id) }
                }
                $srcMutants = @(
                    @{ Id = 'V01_NOT_ENCODED'; Old = 'data-ks-hover-full=' + [char]39 + '").Append(EncodeAttr(hoverFull))'; New = 'data-ks-hover-full=' + [char]39 + '").Append(hoverFull)' },
                    @{ Id = 'V02_ALWAYS_PRESENT'; Old = 'If Not String.Equals(hoverFull, hoverShown, StringComparison.Ordinal) Then sb.Append('; New = 'sb.Append(' },
                    @{ Id = 'V03_FROM_COVER'; Old = 'Dim hoverFull As String = StorefrontProductImageSlots.HoverUrl(row)'; New = 'Dim hoverFull As String = StorefrontProductImageSlots.CoverUrl(row)' },
                    @{ Id = 'V04_FULL_ALWAYS_SHOWN'; Old = 'Dim hoverShown As String = ProductImageThumb(hoverFull)'; New = 'Dim hoverShown As String = hoverFull' }
                )
                foreach ($mu in $srcMutants) {
                    if ((Count-Of $vb $mu.Old) -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
                    if (@(Test-Source ($vb.Replace($mu.Old, $mu.New)) $aspx $js).Count -eq 0) { $survived.Add($mu.Id) }
                }
                if ($survived.Count -gt 0) { Write-Host ('PHOTO_HOME_HOVER_SHARP FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); $exitCode = 1 }
                else { Write-Host ('PHOTO_HOME_HOVER_SHARP mutanti rilevati: ' + ($jsMutants.Count + $srcMutants.Count)) }
            }
        }
    } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($sourceFail.Count -gt 0) { exit 1 }
if ($exitCode -eq 0) { Write-Host 'PHOTO_HOME_HOVER_SHARP OK' }
exit $exitCode
