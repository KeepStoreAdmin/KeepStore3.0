[CmdletBinding()]
param()

# KS-STD-CHECKOUT-COMPARATOR-TRACKERS-1A - nessun tracker di comparatori di prezzo o di affiliazione nel codice
# delle pagine, e nessuna immagine con indirizzo vuoto nell'intestazione dell'e-mail d'ordine.
# Controllo statico con mutazioni. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$trackerPattern = '(?i)bestshopping|kelkoo|pangora|tradedoubler|trovaprezzi|shoppydoo|idealo|salesTracker|OB_image_'

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Assert-Detects([string]$code, [bool]$checkResultOnMutation) {
    if ($checkResultOnMutation) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Read-Repo([string]$relativePath) {
    $full = Join-Path $repoRoot $relativePath
    if (Test-Path -LiteralPath $full) { return [IO.File]::ReadAllText($full) }
    # file tracciato cancellato in locale (eccezione protetta): si legge la versione del commit
    $blob = @(& git -C $repoRoot show ('HEAD:' + $relativePath.Replace('\', '/')))
    if ($LASTEXITCODE -ne 0) { throw ('FILE_NOT_AVAILABLE=' + $relativePath) }
    return ($blob -join "`n")
}
function Test-NoTrackerText([string]$text) { return -not ($text -match $trackerPattern) }
function Test-LogoGuarded([string]$text) {
    return $text -match '(?s)If Not String\.IsNullOrWhiteSpace\(logoUrl\) Then\s*\r?\n\s*sb\.Append\("<div class=""ks-order-company-logo"">"\)'
}

# ---- 1) nessun tracker nei file di codice tracciati ----------------------------
$tracked = @(& git -C $repoRoot ls-files -- '*.vb' '*.aspx' '*.ascx' '*.master' '*.js' '*.config' '*.asax' '*.ashx') |
    Where-Object { $_ -notmatch '^(docs|Tools|Tests|Database Taikun|\.github|\.vs|Public/Export)/' }
Assert-Source ($tracked.Count -gt 100) 'T00_CODE_FILE_LIST_NOT_EMPTY'

$offenders = @()
foreach ($rel in $tracked) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    if (-not (Test-NoTrackerText ([IO.File]::ReadAllText($full)))) { $offenders += $rel }
}
Assert-Source ($offenders.Count -eq 0) ('T01_NO_COMPARATOR_OR_AFFILIATE_TRACKER_IN_CODE ' + ($offenders -join ','))
Assert-Source (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'App_Code\OB_image_bestshopping.vb'))) 'T02_TRACKER_CLASS_REMOVED'

$orderPage = Read-Repo 'ordine.aspx'
$order = Read-Repo 'ordine.aspx.vb'
Assert-Source ($orderPage -notmatch 'img_bs_label|DivImg|litScript') 'T03_ORDER_PAGE_HAS_NO_TRACKER_CONTROLS'
Assert-Source ($order -notmatch 'img_bs_label|DivImg|litScript|Contatore_BestShopping|Sub track_|Sub Track_') 'T04_ORDER_CODE_HAS_NO_TRACKER_METHODS'
Assert-Source (Test-LogoGuarded $order) 'T05_ORDER_EMAIL_HEADER_OMITS_EMPTY_LOGO'

# ---- 2) mutazioni --------------------------------------------------------------
Assert-Detects 'M1_TRACKER_NAME_REAPPEARS' (Test-NoTrackerText ($order + "`n' track_Kelkoo(x)"))
Assert-Detects 'M2_PANGORA_SCRIPT_REAPPEARS' (Test-NoTrackerText ($order + "`n var s = 'https://clicks.example.test/sales-tracking/salesTracker.js'"))
$unguarded = $order.Replace('If Not String.IsNullOrWhiteSpace(logoUrl) Then', 'If True Then')
if ($unguarded -eq $order) { throw 'MUTATION_NOT_APPLIED=M3' }
Assert-Detects 'M3_LOGO_GUARD_REMOVED' (Test-LogoGuarded $unguarded)

Write-Output 'PASS KS_STD_CHECKOUT_COMPARATOR_TRACKERS'
