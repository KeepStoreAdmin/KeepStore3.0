[CmdletBinding()]
param()

# KS-A03-FILTER-BUTTONS-1A - pulsanti del pannello filtri (mobile) e Applica del prezzo: gerarchia e contrasto.
# Applica = principale (rosso scuro, testo bianco), Annulla = secondario (contorno), Reset = discreto (testo).
# Controllo statico con mutazioni (ogni regola, rotta apposta, deve far fallire il controllo).
# La prova nel browser (contrasti misurati, focus e hover, 44 px, 390/320 px, colori forzati, Annulla/Applica/Reset
# invariati) e descritta nel Masterplan.
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

function Get-ButtonBlock([string]$css) {
    $m = [regex]::Match($css, '(?s)/\* ===== Pulsanti del pannello filtri.*$')
    if ($m.Success) { return $m.Value } else { return '' }
}

# ---- controlli (usati sul sorgente reale e su quello mutato) ------------------
function Test-ApplyIsPrimary([string]$css) {
    $b = Get-ButtonBlock $css
    return ($b -match '(?s)\.ks-filter-batch-actions \[data-ks-batch-apply\] \{\s*flex: 2 1 0;\s*min-width: 0;\s*background-color: var\(--primary-2, #D80027\);\s*border: 1px solid var\(--primary-2, #D80027\);\s*color: #fff;' -and
            $b -match '(?s)\[data-ks-batch-apply\]:hover \{\s*background-color: #b90021;[^}]*color: #fff;')
}
function Test-CancelIsSecondary([string]$css) {
    $b = Get-ButtonBlock $css
    return ($b -match '(?s)\.ks-filter-batch-actions \[data-ks-batch-cancel\] \{\s*flex: 1 1 0;\s*min-width: 0;\s*background-color: #fff;\s*border: 1px solid var\(--gray-2, #73787d\);\s*color: var\(--text-4, #40484E\);' -and
            $b -match '(?s)\[data-ks-batch-cancel\]:hover \{\s*background-color: var\(--gray-6')
}
function Test-ResetIsDiscreet([string]$css) {
    $b = Get-ButtonBlock $css
    return ($b -match '(?s)\.btn-reset \{\s*min-height: 44px;\s*background-color: transparent;\s*box-shadow: none;\s*color: var\(--text-4, #40484E\);\s*text-decoration: underline;' -and
            $b -match '(?s)\.btn-reset \.caption \{\s*color: inherit !important;' -and
            $b -match '(?s)\.btn-reset:hover \{\s*background-color: var\(--gray-6')
}
function Test-PriceApply([string]$css) {
    $b = Get-ButtonBlock $css
    return ($b -match '(?s)#ksCatalogPage \.facet-price \.ks-catalog-price-apply \{\s*background: var\(--primary-2, #D80027\);\s*border-color: var\(--primary-2, #D80027\);' -and
            $b -match '(?s)\.ks-catalog-price-apply:hover:not\(:disabled\) \{\s*background: #b90021;' -and
            $b -match '(?s)\.ks-catalog-price-apply:disabled \{\s*opacity: 0\.55;')
}
function Test-ScopedAndNoOwnFocusRing([string]$css) {
    $b = Get-ButtonBlock $css
    if ($b -eq '') { return $false }
    $bad = 0
    foreach ($m in [regex]::Matches($b, '(?m)^([.#][^\n{]+?)\s*\{\s*$')) {
        $sel = $m.Groups[1].Value
        if (-not ($sel.StartsWith('.ks-filter-batch-actions ') -or $sel.StartsWith('#ksCatalogFiltersPanel .ks-filter-footer ') -or $sel.StartsWith('#ksCatalogPage .facet-price '))) { $bad++ }
    }
    # il contorno del focus lo decide la regola del pannello (#ksCatalogFiltersPanel :focus-visible), non queste
    return ($bad -eq 0 -and $b -notmatch 'outline')
}
function Test-CacheBuster([string]$aspx) {
    return ($aspx -match 'css/catalog-filters-ui\.css"\) %>\?v=20261114-filter-buttons1a')
}

# ---- 1) sorgente reale --------------------------------------------------------
$css = Read-Repo 'Public\assets\keepstore\css\catalog-filters-ui.css'
$aspx = Read-Repo 'articoli.aspx'

Assert-Source (Test-ApplyIsPrimary $css) 'S01_APPLY_IS_THE_PRIMARY_ACTION_DARK_RED_WHITE_TEXT'
Assert-Source (Test-CancelIsSecondary $css) 'S02_CANCEL_IS_OUTLINED_WITH_A_3_TO_1_BORDER'
Assert-Source (Test-ResetIsDiscreet $css) 'S03_RESET_IS_A_DISCREET_TEXT_ACTION_WITH_READABLE_LABEL'
Assert-Source (Test-PriceApply $css) 'S04_PRICE_APPLY_USES_THE_SAME_DARK_RED'
Assert-Source (Test-ScopedAndNoOwnFocusRing $css) 'S05_RULES_SCOPED_TO_THE_FILTER_FOOTER_AND_PRICE_AND_NO_OWN_FOCUS_RING'
Assert-Source (Test-CacheBuster $aspx) 'S06_CACHE_BUSTER_UPDATED'

# ---- 2) mutazioni -------------------------------------------------------------
$m = Mutate-Text $css "  background-color: var(--primary-2, #D80027);`n  border: 1px solid var(--primary-2, #D80027);`n  color: #fff;" "  background-color: var(--primary, #ff3d3d);`n  border: 1px solid var(--primary-2, #D80027);`n  color: #fff;" 'M01'
Assert-Detected (Test-ApplyIsPrimary $m) 'M01_APPLY_BACK_TO_THE_LIGHT_RED'
$m = Mutate-Text $css "  border: 1px solid var(--primary-2, #D80027);`n  color: #fff;" "  border: 1px solid var(--primary-2, #D80027);`n  color: #000;" 'M02'
Assert-Detected (Test-ApplyIsPrimary $m) 'M02_APPLY_TEXT_BLACK_AGAIN'
$m = Mutate-Text $css 'flex: 2 1 0;' 'flex: 1 1 0;' 'M03'
Assert-Detected (Test-ApplyIsPrimary $m) 'M03_APPLY_NOT_WIDER_THAN_CANCEL'
$m = Mutate-Text $css 'border: 1px solid var(--gray-2, #73787d);' 'border: 1px solid var(--line-4, #BFC6CC);' 'M04'
Assert-Detected (Test-CancelIsSecondary $m) 'M04_CANCEL_BORDER_TOO_LIGHT'
$m = Mutate-Text $css ("  background-color: #fff;" + [char]10 + "  border: 1px solid var(--gray-2") ("  background-color: var(--primary, #ff3d3d);" + [char]10 + "  border: 1px solid var(--gray-2") 'M05'
Assert-Detected (Test-CancelIsSecondary $m) 'M05_CANCEL_FILLED_LIKE_APPLY'
$m = Mutate-Text $css 'color: inherit !important;' 'color: inherit;' 'M06'
Assert-Detected (Test-ResetIsDiscreet $m) 'M06_RESET_LABEL_LOSES_TO_THE_WHITE_THEME_UTILITY'
$m = Mutate-Text $css '  text-decoration: underline;' '' 'M07'
Assert-Detected (Test-ResetIsDiscreet $m) 'M07_RESET_NOT_UNDERLINED'
$m = Mutate-Text $css "  min-height: 44px;`n  background-color: transparent;" "  min-height: 32px;`n  background-color: transparent;" 'M08'
Assert-Detected (Test-ResetIsDiscreet $m) 'M08_RESET_TOUCH_TARGET_TOO_SMALL'
$m = Mutate-Text $css "#ksCatalogPage .facet-price .ks-catalog-price-apply {`n  background: var(--primary-2, #D80027);" "#ksCatalogPage .facet-price .ks-catalog-price-apply {`n  background: var(--primary, #ff3d3d);" 'M09'
Assert-Detected (Test-PriceApply $m) 'M09_PRICE_APPLY_LIGHT_RED_AGAIN'
$m = Mutate-Text $css '  opacity: 0.55;' '' 'M10'
Assert-Detected (Test-PriceApply $m) 'M10_PRICE_APPLY_DISABLED_LOOKS_ACTIVE'
$m = Mutate-Text $css ".ks-filter-batch-actions [data-ks-batch-cancel]:hover {" ".ks-filter-batch-actions [data-ks-batch-cancel]:hover {`n  outline: 0;" 'M11'
Assert-Detected (Test-ScopedAndNoOwnFocusRing $m) 'M11_BLOCK_SETS_ITS_OWN_OUTLINE'
$m = Mutate-Text $css ".ks-filter-batch-actions [data-ks-batch-apply] {" ".tf-btn {`n  color: #fff;`n}`n`n.ks-filter-batch-actions [data-ks-batch-apply] {" 'M12'
Assert-Detected (Test-ScopedAndNoOwnFocusRing $m) 'M12_RULE_LEAKS_TO_EVERY_BUTTON'
$m = Mutate-Text $aspx 'css/catalog-filters-ui.css") %>?v=20261114-filter-buttons1a' 'css/catalog-filters-ui.css") %>?v=20261111-catalog-departments1a' 'M13'
Assert-Detected (Test-CacheBuster $m) 'M13_CACHE_BUSTER_NOT_UPDATED'

Write-Output 'CATALOG_FILTER_BUTTONS_OK'
