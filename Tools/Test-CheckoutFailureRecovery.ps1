[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$harnessPath = Join-Path $PSScriptRoot 'CheckoutFailureRecoveryHarness.vb'
$logicalResolverPath = Join-Path $RepositoryRoot 'App_Code\OrderLogicalIdentityResolver.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCheckoutRecovery-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'CheckoutFailureRecoveryHarness.exe'

function Read-RepoFile([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $path)
    }
    return [IO.File]::ReadAllText($path)
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw ('CHECKOUT_FAILURE_RECOVERY_SOURCE_FAILED=' + $code) }
    Write-Output ('PASS SOURCE_' + $code)
}

function Get-VbMethod([string]$source, [string]$signature) {
    $pattern = '(?is)' + [regex]::Escape($signature) + '[\s\S]*?\r?\n\s*End (?:Function|Sub)'
    return [regex]::Match($source, $pattern).Value
}

foreach ($required in @($compiler, $harnessPath, $logicalResolverPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $required)
    }
}

$recovery = Read-RepoFile 'App_Code\CheckoutFailureRecoveryService.vb'
$dispatcher = Read-RepoFile 'App_Code\CheckoutTerminalOutcomeDispatcher.vb'
$durable = Read-RepoFile 'App_Code\OrderDurableIdempotencyService.vb'
$logicalResolver = Read-RepoFile 'App_Code\OrderLogicalIdentityResolver.vb'
$orderContext = Read-RepoFile 'App_Code\OrderStorefrontContext.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$cartMarkup = Read-RepoFile 'carrello.aspx'
$order = Read-RepoFile 'ordine.aspx.vb'
$readModel = Read-RepoFile 'App_Code\CartAuthoritativeReadModel.vb'
$miniCart = Read-RepoFile 'Public\ui\controls\MiniCart.ascx.vb'
$master = Read-RepoFile 'Page.master.vb'

$verifyAccount = Get-VbMethod $orderContext 'Public Shared Function VerifyAccount'
$loginOwnership = Get-VbMethod $durable 'Private Shared Function IsLoginOwnedByCompany'
$retireAndDispatch = Get-VbMethod $recovery 'Public Shared Function RetireAndDispatch'
$consumeFailure = Get-VbMethod $recovery 'Public Shared Function TryConsumeFailure'
$recordRetry = Get-VbMethod $durable 'Public Shared Function RecordRetryRequired'
$generateToken = Get-VbMethod $cart 'Private Function GenerateCheckoutToken'
$showFailure = Get-VbMethod $cart 'Private Sub ShowCheckoutFailureFromSession'

Assert-Source (
    $verifyAccount -match '(?i)SELECT\s+DISTINCT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $verifyAccount -notmatch '(?i)SELECT\s+COUNT\s*\('
) '01_VERIFY_ACCOUNT_COLLAPSES_IDENTICAL_PHYSICAL_ROWS'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($loginOwnership) -and
    $loginOwnership.Contains('OrderLogicalIdentityResolver.TryResolve') -and
    $loginOwnership -match '(?i)SELECT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $loginOwnership -notmatch '(?i)SELECT\s+COUNT\s*\(' -and
    $logicalResolver.Contains('row.UserId <= 0 OrElse row.PriceListId <= 0') -and
    $logicalResolver.Contains('row.UserId <> userId OrElse row.PriceListId <> priceListId')
) '02_IDEMPOTENCY_OWNER_CHECK_USES_LOGICAL_IDENTITY'

Assert-Source (
    $recovery.Contains('Public Shared Function RetireAndDispatch') -and
    $recovery.Contains('Public Shared Sub RetireRequest') -and
    $recovery.Contains('Public Shared Function IsRetiredRequest') -and
    $recovery.Contains('Public Shared Function TryConsumeFailure') -and
    $recovery.Contains('Public Shared Sub TracePhase') -and
    $recovery.Contains('Public Shared Function GetCorrelationId')
) '03_RECOVERY_SERVICE_EXPOSES_REQUIRED_CONTROL_FLOW'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($retireAndDispatch) -and
    $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -ge 0 -and
    $retireAndDispatch.IndexOf('CheckoutTerminalOutcome.CheckoutFailure', [StringComparison]::Ordinal) -gt
        $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -and
    $retireAndDispatch -match '(?i)Session'
) '04_FAILURE_RETIRES_THEN_STORES_SERVER_SIDE_AND_DISPATCHES'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($consumeFailure) -and
    $consumeFailure -match '(?i)Session' -and
    $consumeFailure -match '(?i)Remove|Nothing' -and
    $consumeFailure -notmatch '(?i)Request\.QueryString'
) '05_FAILURE_MESSAGE_IS_ONE_TIME_AND_NOT_QUERY_CONTROLLED'

Assert-Source (
    $dispatcher.Contains('CheckoutFailure') -and
    $dispatcher.Contains('carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError') -and
    $cartMarkup.Contains('ID="pnlCheckoutSubmitError"') -and
    $dispatcher.Contains('response.StatusCode = 303') -and
    $dispatcher.Contains('context.ApplicationInstance.CompleteRequest()')
) '06_FAILURE_OUTCOME_USES_TERMINAL_HTTP_303_PRG'

Assert-Source (
    $cart.Contains('CheckoutFailureRecoveryService.TryConsumeFailure') -and
    $cart.Contains('CheckoutFailureRecoveryService.RetireAndDispatch') -and
    $cart.Contains('CheckoutFailureRecoveryService.IsRetiredRequest') -and
    $cart.Contains('EnsureCheckoutRequestId()') -and
    $order.Contains('CheckoutFailureRecoveryService.IsRetiredRequest')
) '07_CART_CONSUMES_FLASH_ROTATES_REQUEST_AND_BLOCKS_RETIRED'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($recordRetry) -and
    $recordRetry.Contains('RetryRequiredState') -and
    $order.Contains('OrderDurableIdempotencyService.RecordRetryRequired') -and
    $order.Contains('CheckoutFailureRecoveryService.RetireAndDispatch')
) '08_POSTCLAIM_FAILURE_RECORDS_RETRY_BEFORE_RECOVERY'

$procedureIndex = $order.IndexOf('Carrello_Documento', [StringComparison]::Ordinal)
$completeIndex = $order.IndexOf('OrderDurableIdempotencyService.Complete(', $procedureIndex, [StringComparison]::Ordinal)
$commitIndex = $order.IndexOf('trns.Commit()', $completeIndex, [StringComparison]::Ordinal)
$emailIndex = $order.IndexOf('SendEmail(', $commitIndex, [StringComparison]::Ordinal)
Assert-Source (
    $procedureIndex -ge 0 -and $completeIndex -gt $procedureIndex -and
    $commitIndex -gt $completeIndex -and $emailIndex -gt $commitIndex
) '09_PROCEDURE_COMPLETE_COMMIT_EMAIL_ORDERING'

Assert-Source (
    $cart.Contains('Case "cvCheckoutShippingMethod"') -and
    $cart.Contains('Case "cvCheckoutPaymentMethod"') -and
    $cart.Contains('Seleziona un metodo di spedizione') -and
    $cart.Contains('Seleziona un metodo di pagamento')
) '10_SHIPPING_AND_PAYMENT_FAIL_BEFORE_DISPATCH'

Assert-Source (
    $order.Contains('record.AziendaId') -or
    ($order.Contains('receiptAziendaId') -and $order.Contains('LoadOrderEmailBrandData'))
) '11_EMAIL_BRANDING_USES_PERSISTED_COMPANY'

Assert-Source (
    $cartMarkup.Contains('TypeName="CartAuthoritativeReadDataSource" SelectMethod="SelectStandardItems"') -and
    $miniCart.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $master.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $readModel.Contains('KeepStore:CartAuthoritativeReadModel:Current')
) '12_CART_PAGE_MINICART_HEADER_SHARE_READ_MODEL'

$catchIndex = $order.IndexOf('Catch ex As Exception', $commitIndex, [StringComparison]::Ordinal)
$postCommitIndex = $order.IndexOf('If commitCompleted Then', $catchIndex, [StringComparison]::Ordinal)
$inventoryCatchIndex = $order.IndexOf('FindInventoryAvailabilityException(ex)', $catchIndex, [StringComparison]::Ordinal)
Assert-Source (
    $catchIndex -ge 0 -and $postCommitIndex -gt $catchIndex -and
    $inventoryCatchIndex -gt $postCommitIndex -and
    $order.Contains('CheckoutFailureRecoveryService.RetireRequest(HttpContext.Current, checkoutRequestId)') -and
    ([regex]::Matches($order, 'OrderDurableIdempotencyService\.RecordRetryRequired\s*\(').Count -ge 3)
) '13_POSTCOMMIT_FIRST_AND_FAILED_REQUESTS_RETIRED_DURABLY'

Assert-Source (
    $order.Contains('If Vettore <= 0 Then') -and
    $order.Contains('CheckoutFailureReason.ShippingMethodMissing') -and
    $order.Contains('If Pagamento <= 0 Then') -and
    $order.Contains('CheckoutFailureReason.PaymentMethodMissing') -and
    $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal) -lt
        $order.IndexOf('If Vettore <= 0 Then', [StringComparison]::Ordinal)
) '14_ORDER_SIDE_SELECTIONS_FAIL_SPECIFIC_BEFORE_CLAIM'

Assert-Source (
    $order.Contains('checkoutRequestId, "08-storefront-context", "resolved"') -and
    -not $order.Contains('String.Empty, "08-storefront-context", "resolved"') -and
    -not [string]::IsNullOrWhiteSpace($generateToken) -and
    $generateToken.Contains('normalizedRequestId, "08-storefront-context", "resolved"') -and
    -not $generateToken.Contains('ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY), CultureInfo.InvariantCulture),' + [Environment]::NewLine + '        "08-storefront-context"')
) '15_TRACE_USES_ONE_REQUEST_CORRELATION'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($showFailure) -and
    $showFailure.Contains('SetCheckoutStep("checkout")') -and
    $showFailure.Contains('tOrdine.Visible = True') -and
    $showFailure.Contains('ShowCheckoutSubmitError(failure.Message, False)') -and
    $order.Contains('CheckoutFailureReason.ShippingAddressInvalid') -and
    $order.Contains('CheckoutFailureReason.OrderNotesInvalid') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.AddressError)') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.NotesError)')
) '16_CORRECTION_FAILURE_REOPENS_CHECKOUT_CONTROLS'

$firstLoginRequired = $order.IndexOf('CheckoutTerminalOutcome.LoginRequired', [StringComparison]::Ordinal)
$secondLoginRequired = $order.IndexOf(
    'CheckoutTerminalOutcome.LoginRequired',
    $firstLoginRequired + 1,
    [StringComparison]::Ordinal)
$firstExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $firstLoginRequired,
    [StringComparison]::Ordinal)
$secondExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $secondLoginRequired,
    [StringComparison]::Ordinal)
Assert-Source (
    $order.Contains('Private Function TryExtractCheckoutRequestIdForRetirement') -and
    $firstLoginRequired -ge 0 -and $secondLoginRequired -gt $firstLoginRequired -and
    $firstExtract -ge 0 -and $firstExtract -lt $firstLoginRequired -and
    $secondExtract -gt $firstLoginRequired -and $secondExtract -lt $secondLoginRequired -and
    ([regex]::Matches($order, 'RetireRequest\(HttpContext\.Current,\s*(?:expiredRequestId|invalidIdentityRequestId)\)').Count -eq 2)
) '17_LOGIN_TIMEOUT_AND_PARTIAL_IDENTITY_RETIRE_OLD_REQUEST'

$completedLookupIndex = $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal)
$notesValidationIndex = $order.IndexOf('If OrderNotesAreTooLong(Note) Then', [StringComparison]::Ordinal)
$claimIndex = $order.IndexOf('OrderDurableIdempotencyService.TryClaim(', [StringComparison]::Ordinal)
Assert-Source (
    $completedLookupIndex -ge 0 -and
    $notesValidationIndex -gt $completedLookupIndex -and
    $claimIndex -gt $notesValidationIndex
) '18_COMPLETED_REPLAY_PRECEDES_SESSION_VALIDATION_AND_NEW_CLAIM'

Assert-Source (
    -not $recovery.Contains('MaxRetiredRequestIds') -and
    -not $recovery.Contains('RemoveAt(0)') -and
    $recovery.Contains('ids.Add(normalized)')
) '19_RETIRED_REQUESTS_ARE_NOT_REACTIVATED_BY_EVICTION'

$invalidTokenBranch = Get-VbMethod $order 'Private Function TryExtractCheckoutRequestIdForRetirement'
Assert-Source (
    -not [string]::IsNullOrWhiteSpace($invalidTokenBranch) -and
    $invalidTokenBranch.Contains('MachineKey.Unprotect') -and
    $invalidTokenBranch.Contains('parts.Length <> 7') -and
    $order.Contains('RetireRequest(HttpContext.Current, invalidTokenRequestId)')
) '20_INVALID_AUTHENTIC_TOKEN_IS_RETIRED_BEFORE_CART_REVIEW'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $logicalResolverPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_COMPILE_FAILED' }

    $harnessOutput = @(& $executable 2>&1 | ForEach-Object { $_.ToString() })
    $harnessExit = $LASTEXITCODE
    $harnessOutput | Write-Output
    if ($harnessExit -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_FAILED' }

    $scenarioPasses = @($harnessOutput | Where-Object { $_ -match '^PASS\s+\d{2}_' })
    if ($scenarioPasses.Count -ne 20) {
        throw ('CHECKOUT_FAILURE_RECOVERY_EXPECTED_20_SCENARIOS_ACTUAL_' + $scenarioPasses.Count)
    }
    if (@($harnessOutput | Where-Object { $_ -match '^FAIL\s+' }).Count -ne 0) {
        throw 'CHECKOUT_FAILURE_RECOVERY_REPORTED_FAILURE'
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_TEMP_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS CHECKOUT_FAILURE_RECOVERY_20_COMPILED_SCENARIOS'
