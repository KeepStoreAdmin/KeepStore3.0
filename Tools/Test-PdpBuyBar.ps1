[CmdletBinding()]
param()

# KS-A03-PDP-BUYBAR-1A - barra fissa di acquisto sulla scheda articolo (telefono e tablet).
# Controllo statico di script, CSS e pagina con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La prova nel browser (comparsa e scomparsa, prezzo, delega al pulsante principale con ogni richiesta bloccata, tastiera,
# osservatore sul pulsante principale, messaggio di conferma, 390/320/1199/1200 px, senza JavaScript) e nel Masterplan.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-Repo([string]$relativePath) { return ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) -replace "`r`n", "`n") }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

function Get-BarBlock([string]$css) {
    $m = [regex]::Match($css, '(?s)/\* ===== Barra fissa di acquisto.*$')
    if ($m.Success) { return $m.Value } else { return '' }
}

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-DelegatesToMainButton([string]$js) {
    # la barra non costruisce ne invia nessuna azione di carrello: preme il pulsante principale
    return ($js -match 'main\.click\(\)' -and
            $js -notmatch 'ksCartAction|cart_add|fetch\(|XMLHttpRequest|ksNativeCartForm|\.submit\(|requestSubmit|FormData')
}
function Test-RechecksBeforeClick([string]$js) {
    return ($js -match "(?s)cta\.addEventListener\('click', function \(\) \{\s*if \(cooldown\) \{ return; \}.*?if \(!narrow\.matches \|\| !mainUsable\(\)\) \{ update\(\); return; \}.*?main\.click\(\);")
}
function Test-Visibility([string]$js) {
    return ($js -match "matchMedia\('\(max-width: 1199\.98px\)'\)" -and
            $js -match 'var show = narrow\.matches && mainUsable\(\) && main\.getClientRects\(\)\.length > 0 && !mainInView\(\);' -and
            $js -match 'r\.bottom > 0 && r\.top < vh' -and
            $js -match "!main\.disabled && main\.getAttribute\('aria-disabled'\) !== 'true' && !main\.classList\.contains\('disabled'\)")
}
function Test-FocusHandling([string]$js) {
    return ($js -match "(?s)if \(!show && bar\.contains\(document\.activeElement\)\) \{\s*if \(mainUsable\(\)\) \{ main\.focus\(\{ preventScroll: true \}\); \} else \{ document\.activeElement\.blur\(\); \}")
}
function Test-DoubleTapPause([string]$js) {
    return ($js -match 'cta\.disabled = true;' -and $js -match "cta\.setAttribute\('aria-busy', 'true'\);" -and
            $js -match 'window\.setTimeout\(release, 1500\)' -and
            $js -match "(?s)addEventListener\('pageshow', function \(\) \{ release\(\); update\(\); \}\)")
}
function Test-Synchronisation([string]$js) {
    return ($js -match "addEventListener\('scroll', update, \{ passive: true \}\)" -and
            $js -match "addEventListener\('resize', update\)" -and
            $js -match 'window\.visualViewport\.addEventListener\(''resize'', update\)' -and
            $js -match "narrow\.addEventListener\('change', update\)" -and
            $js -match "observe\(main, \{ attributes: true, attributeFilter: \['disabled', 'aria-disabled', 'class'\] \}\)")
}
function Test-PriceSummary([string]$js) {
    return ($js -match "box\.querySelector\('\.new-price'\) \|\| box\.querySelector\('\.price-text'\)" -and
            $js -match "box\.querySelector\('\.price-text \+ p\.body-text-3'\)" -and
            $js -match 'setText\(priceEl, info\.price\);' -and $js -match 'setText\(noteEl, info\.note\);')
}
function Test-MeasuredHeight([string]$js, [string]$css) {
    $b = Get-BarBlock $css
    return ($js -match "setProperty\('--ks-pdp-buybar-h', h \+ 'px'\)" -and
            $b -match 'body\.ks-pdp-buybar-on \{ padding-bottom: var\(--ks-pdp-buybar-h,' -and
            $b -match 'body\.ks-pdp-buybar-on \.ks-cart-feedback-toast \{ bottom: calc\(var\(--ks-pdp-buybar-h, 72px\) \+ 16px\); \}' -and
            $b -match 'html \{ scroll-padding-bottom: var\(--ks-pdp-buybar-h, 0px\); \}')
}
function Test-BarCss([string]$css) {
    $b = Get-BarBlock $css
    if ($b -eq '') { return $false }
    return ($b -match '^\S*[^\n]*\n[^\n]*\n\.ks-pdp-buybar \{ display: none; \}' -and
            $b -match '@media \(max-width: 1199\.98px\) \{' -and
            $b -match 'position: fixed;' -and $b -match 'z-index: 1020;' -and
            $b -match 'padding: 8px 16px calc\(8px \+ env\(safe-area-inset-bottom, 0px\)\);' -and
            $b -match '\.ks-pdp-buybar\[hidden\] \{ display: none; \}' -and
            $b -match 'min-height: 48px;' -and
            $b -match '__cta:focus-visible \{\s*outline: 3px solid' -and
            $b -match 'prefers-reduced-motion: no-preference' -and
            $b -match '@media \(forced-colors: active\)' -and
            $b -match 'inset-inline: 0;' -and $b -match 'margin-inline-start: auto;')
}
function Test-PageWiring([string]$aspx) {
    $i = $aspx.IndexOf('js/keepstore-product.js')
    $j = $aspx.IndexOf('js/ks-pdp-buybar.js')
    return ($i -gt 0 -and $j -gt $i -and
            $aspx -match 'js/ks-pdp-buybar\.js"\) %>\?v=20261114-pdp-buybar1a' -and
            $aspx -match 'css/product-ui\.css"\) %>\?v=(?:20261114-(?:pdp-buybar1a|deadcode-c1a)|20261115-palette-aa1a|20261115-focus-fc1a|20261115-focus-obscured1a|20261118-pdp-sections1a)')
}

# ---- 1) sorgente reale --------------------------------------------------------
$js = Read-Repo 'Public\assets\keepstore\js\ks-pdp-buybar.js'
$css = Read-Repo 'Public\assets\keepstore\css\product-ui.css'
$aspx = Read-Repo 'articolo.aspx'

Assert-Source (Test-DelegatesToMainButton $js) 'S01_BAR_PRESSES_THE_MAIN_BUTTON_AND_BUILDS_NO_CART_ACTION'
Assert-Source (Test-RechecksBeforeClick $js) 'S02_MAIN_BUTTON_RECHECKED_RIGHT_BEFORE_THE_CLICK'
Assert-Source (Test-Visibility $js) 'S03_VISIBLE_ONLY_ON_NARROW_VIEWPORT_WITH_ACTIVE_MAIN_BUTTON_OUT_OF_VIEW'
Assert-Source (Test-FocusHandling $js) 'S04_FOCUS_MOVES_TO_MAIN_BUTTON_WITHOUT_SCROLL_OR_IS_RELEASED'
Assert-Source (Test-DoubleTapPause $js) 'S05_DOUBLE_TAP_PAUSE_AND_RELEASE_ON_PAGESHOW'
Assert-Source (Test-Synchronisation $js) 'S06_STATE_FOLLOWS_SCROLL_RESIZE_VIEWPORT_AND_MAIN_BUTTON_ATTRIBUTES'
Assert-Source (Test-PriceSummary $js) 'S07_PRICE_WITH_ITS_QUALIFIER_AND_FALLBACK'
Assert-Source (Test-MeasuredHeight $js $css) 'S08_FOOTER_SPACE_AND_TOAST_FOLLOW_THE_MEASURED_BAR_HEIGHT'
Assert-Source (Test-BarCss $css) 'S09_CSS_FIXED_BELOW_OFFCANVAS_SAFE_AREA_TOUCH_TARGET_FOCUS_MOTION_FORCED_COLORS'
Assert-Source (Test-PageWiring $aspx) 'S10_SCRIPT_LOADED_ON_PRODUCT_PAGE_ONLY_WITH_CACHE_BUSTERS'
Assert-Source ($js -notmatch '(?i)onsus|taikun') 'S11_NO_TEMPLATE_OR_CUSTOMER_NAME_IN_NEW_RUNTIME_CODE'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $js '  update();' "  fetch('/cart_add.aspx');`n  update();" 'M01'
Assert-Detected (Test-DelegatesToMainButton $m) 'M01_BAR_SENDS_ITS_OWN_CART_REQUEST'
$m = Mutate-Text $js '      main.click();' '' 'M02'
Assert-Detected (Test-DelegatesToMainButton $m) 'M02_BAR_DOES_NOT_PRESS_THE_MAIN_BUTTON'
$m = Mutate-Text $js '      if (!narrow.matches || !mainUsable()) { update(); return; }' '' 'M03'
Assert-Detected (Test-RechecksBeforeClick $m) 'M03_NO_RECHECK_BEFORE_THE_CLICK'
$m = Mutate-Text $js '(max-width: 1199.98px)' '(max-width: 1199px)' 'M04'
Assert-Detected (Test-Visibility $m) 'M04_NARROW_THRESHOLD_CHANGED'
$m = Mutate-Text $js ' && !mainInView();' ';' 'M05'
Assert-Detected (Test-Visibility $m) 'M05_BAR_SHOWN_EVEN_WHEN_MAIN_BUTTON_IS_VISIBLE'
$m = Mutate-Text $js "main.focus({ preventScroll: true });" 'main.focus();' 'M06'
Assert-Detected (Test-FocusHandling $m) 'M06_FOCUS_TRANSFER_SCROLLS_THE_PAGE'
$m = Mutate-Text $js '      cta.disabled = true;' '' 'M07'
Assert-Detected (Test-DoubleTapPause $m) 'M07_NO_DOUBLE_TAP_PAUSE'
$m = Mutate-Text $js "attributeFilter: ['disabled', 'aria-disabled', 'class']" "attributeFilter: ['class']" 'M08'
Assert-Detected (Test-Synchronisation $m) 'M08_MAIN_BUTTON_DISABLED_STATE_NOT_OBSERVED'
$m = Mutate-Text $js "window.visualViewport.addEventListener('resize', update);" '' 'M09'
Assert-Detected (Test-Synchronisation $m) 'M09_VISUAL_VIEWPORT_IGNORED'
$m = Mutate-Text $js "box.querySelector('.price-text + p.body-text-3')" 'null' 'M10'
Assert-Detected (Test-PriceSummary $m) 'M10_PRICE_QUALIFIER_LOST'
$m = Mutate-Text $css 'z-index: 1020;' 'z-index: 1100;' 'M11'
Assert-Detected (Test-BarCss $m) 'M11_BAR_ABOVE_THE_OFFCANVAS'
$m = Mutate-Text $css '  .ks-pdp-buybar[hidden] { display: none; }' '' 'M12'
Assert-Detected (Test-BarCss $m) 'M12_HIDDEN_ATTRIBUTE_OVERRIDDEN'
$m = Mutate-Text $css 'bottom: calc(var(--ks-pdp-buybar-h, 72px) + 16px);' 'bottom: 88px;' 'M13'
Assert-Detected (Test-MeasuredHeight $js $m) 'M13_TOAST_OFFSET_FIXED_NOT_MEASURED'
$m = Mutate-Text $css 'padding-bottom: var(--ks-pdp-buybar-h, calc(72px + env(safe-area-inset-bottom, 0px)));' 'padding-bottom: 72px;' 'M14'
Assert-Detected (Test-MeasuredHeight $js $m) 'M14_FOOTER_SPACE_FIXED_NOT_MEASURED'
$m = Mutate-Text $css 'padding: 8px 16px calc(8px + env(safe-area-inset-bottom, 0px));' 'padding: 8px 16px;' 'M15'
Assert-Detected (Test-BarCss $m) 'M15_SAFE_AREA_LOST'
$m = Mutate-Text $css 'min-height: 48px;' 'min-height: 32px;' 'M16'
Assert-Detected (Test-BarCss $m) 'M16_TOUCH_TARGET_TOO_SMALL'
$m = Mutate-Text $aspx 'js/ks-pdp-buybar.js") %>?v=20261114-pdp-buybar1a' 'js/ks-pdp-buybar.js") %>?v=old' 'M17'
Assert-Detected (Test-PageWiring $m) 'M17_SCRIPT_CACHE_BUSTER_NOT_UPDATED'

$m = Mutate-Text $css 'html { scroll-padding-bottom: var(--ks-pdp-buybar-h, 0px); }' 'html { }' 'M18'
Assert-Detected (Test-MeasuredHeight $js $m) 'M18_FOCUS_SCROLLS_BEHIND_THE_BAR_NO_SCROLL_PADDING'

Write-Output 'PDP_BUY_BAR_OK'
