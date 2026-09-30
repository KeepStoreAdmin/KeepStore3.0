[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$cart = [IO.File]::ReadAllText((Join-Path $repoRoot 'carrello.aspx.vb'))
$intent = [IO.File]::ReadAllText((Join-Path $repoRoot 'App_Code\CartMutationIdempotencyService.vb'))
$async = [IO.File]::ReadAllText((Join-Path $repoRoot 'cart_quantity_async.aspx.vb'))

function Assert-Contains([string]$text, [string]$pattern, [string]$code) {
    if ($text -notmatch $pattern) { throw $code }
    Write-Output "PASS $code"
}

$preRender = [regex]::Match($cart, '(?s)Protected Sub Page_PreRender\b.*?End Sub')
$ensure = [regex]::Match($cart, '(?s)Private Sub EnsureCartUpdateRequestId\b.*?End Sub')
$handler = [regex]::Match($cart, '(?s)Protected Sub btAggiorna_Click\b.*?End Sub')
$builder = [regex]::Match($cart, '(?s)Private Function TryBuildCartQuantityMutationRequests\b.*?End Function')
$mutation = [regex]::Match($cart, '(?s)Function Aggiorna_Prezzi_Carrello\b.*?End Function')
foreach ($part in @($preRender, $ensure, $handler, $builder, $mutation)) {
    if (-not $part.Success) { throw 'TRADITIONAL_SECTION_MISSING' }
}

Assert-Contains $preRender.Value 'EnsureCartUpdateRequestId\(\)' 'VIEWSTATE_CREATED_BEFORE_RENDER'
Assert-Contains $ensure.Value 'ViewState\(CART_UPDATE_REQUEST_VIEWSTATE_KEY\)\s*=\s*CartMutationIdempotencyService\.CreateRequestId\(\)' 'NEW_RENDER_GETS_REQUEST_ID'
Assert-Contains $handler.Value 'ViewState\(CART_UPDATE_REQUEST_VIEWSTATE_KEY\)' 'POST_READS_PROTECTED_REQUEST_ID'
Assert-Contains $handler.Value 'Not CartMutationIdempotencyService\.NormalizeRequestId\(' 'MISSING_ID_FAILS_CLOSED'
if ($handler.Value -match 'CreateRequestId\(') { throw 'LATE_REQUEST_ID_GENERATION' }
Write-Output 'PASS NO_LATE_REQUEST_ID_GENERATION'
Assert-Contains $handler.Value 'BuildSetRowsQuantityPayload\(requests\)' 'PAYLOAD_USES_SHARED_REQUESTS'
Assert-Contains $handler.Value 'Aggiorna_Prezzi_Carrello\(requests\)' 'MUTATION_USES_SHARED_REQUESTS'
Assert-Contains $mutation.Value 'UpdateStandardQuantities\(\s*HttpContext\.Current,\s*loginId,\s*sessionId,\s*listino,\s*requests\)' 'SERVICE_USES_SHARED_REQUESTS'
Assert-Contains $handler.Value '"cart-set-batch"' 'BATCH_OPERATION_TYPE'
Assert-Contains $handler.Value 'RegisterIntent\(' 'TRADITIONAL_REGISTER'
Assert-Contains $handler.Value 'BeginIntent\(' 'TRADITIONAL_BEGIN'
Assert-Contains $handler.Value 'CompleteIntent\(' 'TRADITIONAL_COMPLETE'
Assert-Contains $handler.Value 'AbandonIntent\(' 'TRADITIONAL_ABANDON'
Assert-Contains $handler.Value 'CartMutationIntentDecision\.Indeterminate' 'INDETERMINATE_PRESERVED'
Assert-Contains $handler.Value 'decision <> CartMutationIntentDecision\.Completed' 'COMPLETED_REPLAY_NO_MUTATION'
Assert-Contains $handler.Value 'Response\.Redirect\("carrello\.aspx"\)' 'TRADITIONAL_REDIRECT_PRESERVED'
Assert-Contains $builder.Value 'Repeater1\.Items' 'STANDARD_ROWS_PRESERVED'
Assert-Contains $builder.Value 'gvArticoliGratis\.Items' 'GIFT_ROWS_PRESERVED'
Assert-Contains $intent 'rows-target-v1\|' 'VERSIONED_BATCH_PAYLOAD'
Assert-Contains $async 'BuildSetRowQuantityPayload\(rowId, CDec\(_requestedQuantity\)\)' 'ASYNC_ROW_PAYLOAD_INVARIANT'

foreach ($method in @('btCompleta_Click', 'lnkCheckoutStep2_Click', 'MoveToCheckoutConfirmStep', 'btInviaOrdine_Click')) {
    $section = [regex]::Match($cart, '(?s)(?:Protected|Private) Sub ' + $method + '\b.*?End Sub')
    if (-not $section.Success -or $section.Value -notmatch 'If GetLoginIdSafe\(0\) <= 0 Then' -or
        $section.Value -notmatch 'Aggiorna_Prezzi_Carrello\(\)') {
        throw ('CHECKOUT_AUTH_GUARD_MISSING_' + $method)
    }
    Write-Output ('PASS CHECKOUT_AUTH_GUARD_' + $method)
}

$diff = & git -C $repoRoot diff HEAD -- cart_quantity_async.aspx.vb
if ($LASTEXITCODE -ne 0 -or $diff) { throw 'ASYNC_QUANTITY_FILE_CHANGED' }
Write-Output 'PASS ASYNC_QUANTITY_FILE_UNCHANGED'
