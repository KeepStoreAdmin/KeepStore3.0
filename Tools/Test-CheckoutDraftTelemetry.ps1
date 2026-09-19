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
$harness = Join-Path $PSScriptRoot 'CheckoutDraftTelemetryHarness.vb'
$draftService = Join-Path $RepositoryRoot 'App_Code\CheckoutDraftService.vb'
$telemetry = Join-Path $RepositoryRoot 'App_Code\CheckoutDurableTelemetry.vb'
$mysql = Join-Path $RepositoryRoot 'Bin\MySql.Data.dll'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCheckoutDraft-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'CheckoutDraftTelemetryHarness.exe'

function Read-RepoFile([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $path)
    }
    return [IO.File]::ReadAllText($path)
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw ('CHECKOUT_DRAFT_SOURCE_FAILED=' + $code) }
    Write-Output ('PASS SOURCE_' + $code)
}

foreach ($required in @($compiler, $harness, $draftService, $telemetry, $mysql)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $required)
    }
}

$address = Read-RepoFile 'App_Code\CheckoutAddressService.vb'
$draft = Read-RepoFile 'App_Code\CheckoutDraftService.vb'
$durableTelemetry = Read-RepoFile 'App_Code\CheckoutDurableTelemetry.vb'
$recovery = Read-RepoFile 'App_Code\CheckoutFailureRecoveryService.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$order = Read-RepoFile 'ordine.aspx.vb'

Assert-Source (
    $address.Contains('FROM utentiindirizzi ui') -and
    $address.Contains('vl.AziendeId=?aziendaId') -and
    $address.Contains('vl.id=?loginId') -and
    $address.Contains('vl.utentiid=ui.UtenteId')
) '01_ADDRESS_QUERY_OWNER_AND_TENANT_SCOPED'

Assert-Source (
    $cart -match '(?s)If\s+Not\s+Page\.IsPostBack\s+Then.*?FillTableInfo\(\).*?BindLstDestinazioneLstScegliIndirizzo\(\)'
) '02_ADDRESS_LIST_REBUILT_ON_NEW_GET'

Assert-Source (
    $cart.Contains('CheckoutDraftService.TryReadSelectionForRetry') -and
    $cart.Contains('RestoreCheckoutDraftSelectionAfterPrg') -and
    $cart.Contains('SetCartShippingAddressId(draft.ShippingAddressId)') -and
    $cart.Contains('ApplyCurrentShippingAddress()')
) '03_RETRY_SELECTION_RESTORED_FROM_AUTHORITATIVE_DRAFT'

Assert-Source (
    $cart.Contains('CheckoutAddressService.TryResolve') -and
    $cart.Contains('StoreCheckoutOrderSession') -and
    $cart.Contains('TryCaptureAuthoritativeCheckoutDraft')
) '04_CONFIRMATION_USES_VALIDATED_ADDRESS_ID'

Assert-Source (
    $draft.Contains('CurrentVersion As Integer = 4') -and
    $draft.Contains('DatabaseScopeKey') -and $draft.Contains('ShippingAddressId') -and
    $draft.Contains('DeliveryMethodId') -and $draft.Contains('PaymentMethodId') -and
    $draft.Contains('CartFingerprint') -and $draft.Contains('OptionsFingerprint') -and
    $draft.Contains('RequestId') -and $draft.Contains('ExpiresUtc')
) '05_VERSIONED_OWNER_SCOPED_DRAFT_CONTRACT'

Assert-Source (
    $cart.Contains('"v4|" & normalizedRequestId') -and
    $order.Contains('parts.Length <> 8') -and
    $order.Contains('checkoutDraftFingerprint')
) '06_TOKEN_BINDS_DRAFT_FINGERPRINT'

Assert-Source (
    $order.IndexOf('CheckoutDraftService.TryRead(', [StringComparison]::Ordinal) -ge 0 -and
    $order.IndexOf('OrderDurableIdempotencyService.TryClaim', [StringComparison]::Ordinal) -gt
        $order.IndexOf('CheckoutDraftService.TryRead(', [StringComparison]::Ordinal)
) '07_DRAFT_VALIDATED_BEFORE_IDEMPOTENCY_CLAIM'

Assert-Source (
    $order.Contains('CheckoutDraftService.ValidateAuthoritativeSelections') -and
    $order.Contains('CheckoutAddressService.TryResolve') -and
    $order.Contains('checkoutDraft.ShippingAddressId')
) '08_ORDER_REVALIDATES_SAME_ADDRESS_ID'

Assert-Source (
    $durableTelemetry.Contains('checkout-durable.log') -and
    $durableTelemetry.Contains('MaxFileBytes') -and
    $durableTelemetry.Contains('MaxArchives') -and
    $durableTelemetry.Contains('WriteToPaths') -and
    $durableTelemetry.Contains('ContainsCorrelation')
) '09_TELEMETRY_IS_BOUNDED_PERSISTENT_AND_READABLE'

Assert-Source (
    $recovery.Contains('CheckoutDurableTelemetry.Write') -and
    $durableTelemetry.Contains('ConfirmGet') -and
    $durableTelemetry.Contains('ConfirmPost') -and
    $durableTelemetry.Contains('ValidateDraft') -and
    $durableTelemetry.Contains('PostCommitEmail')
) '10_REQUIRED_PHASES_ROUTE_TO_DURABLE_TELEMETRY'

Assert-Source (
    $durableTelemetry.Contains('BuildOrderToken') -and
    $durableTelemetry.Contains('ProtectOrderToken') -and
    $durableTelemetry.Contains('order-token-protect') -and
    $cart.Contains('"order-token-payload", "ready"') -and
    $cart.Contains('"order-token-protect", "entered"') -and
    $cart.Contains('"not-claimed", "none", "BuildOrderToken"')
) '11_ORDER_TOKEN_BOUNDARY_IS_EXPLICIT_AND_STATEFUL'

$blockInvalidStart = $order.IndexOf('Private Sub BlockInvalidShippingAddress', [StringComparison]::Ordinal)
$blockInvalidEnd = if ($blockInvalidStart -ge 0) { $order.IndexOf('End Sub', $blockInvalidStart, [StringComparison]::Ordinal) } else { -1 }
$blockInvalid = if ($blockInvalidStart -ge 0 -and $blockInvalidEnd -gt $blockInvalidStart) {
    $order.Substring($blockInvalidStart, $blockInvalidEnd - $blockInvalidStart)
} else { '' }
Assert-Source (
    -not [string]::IsNullOrWhiteSpace($blockInvalid) -and
    -not $blockInvalid.Contains('Session("SCEGLIINDIRIZZO") = Nothing')
) '12_FAILURE_DOES_NOT_DESTROY_RETRY_ADDRESS_SELECTION'

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $references = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.dll'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Core.dll'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Data.dll'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Web.dll'),
        $mysql
    )
    $arguments = @('/nologo', '/target:exe', '/optionstrict+', ('/out:' + $executable))
    foreach ($reference in $references) { $arguments += ('/reference:' + $reference) }
    $arguments += @($harness, $draftService, $telemetry)

    & $compiler @arguments
    if ($LASTEXITCODE -ne 0) { throw ('VBC_EXIT=' + $LASTEXITCODE) }

    $output = & $executable 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Output $_ }
    if ($exitCode -ne 0) { throw ('HARNESS_EXIT=' + $exitCode) }
    $scenarioPasses = @($output | Where-Object { $_ -match '^PASS \d{2}_' }).Count
    if ($scenarioPasses -ne 22) { throw ('EXPECTED_22_COMPILED_SCENARIOS_ACTUAL=' + $scenarioPasses) }
    if (@($output | Where-Object { $_ -match '^FAIL ' }).Count -ne 0) { throw 'COMPILED_SCENARIO_FAILURE' }
    Write-Output 'PASS CHECKOUT_DRAFT_TELEMETRY_COMPILED=22/22'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
