[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$checks = 0

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    $script:checks++
    Write-Output ('PASS ' + $Code)
}

function Read-Repo([string]$Path) {
    return [IO.File]::ReadAllText((Join-Path $repo $Path))
}

function Has-OrderedText([string]$Text, [string]$First, [string]$Second) {
    $firstIndex = $Text.IndexOf($First, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0) { return $false }
    return $Text.IndexOf($Second, $firstIndex, [StringComparison]::Ordinal) -gt $firstIndex
}

$order = Read-Repo 'ordine.aspx.vb'
$registration = Read-Repo 'registrazione.aspx.vb'
$passwordReset = Read-Repo 'App_Code\PasswordResetTokenService.vb'
$modernContact = Read-Repo 'Contattaci.aspx.vb'
$legacyContact = Read-Repo 'main.aspx.vb'
$documents = Read-Repo 'documenti.aspx.vb'
$coupons = Read-Repo 'coupon_utente.aspx.vb'
$master = Read-Repo 'Page.master.vb'
$facade = Read-Repo 'App_Code\TenantEmailDeliveryService.vb'
$contracts = Read-Repo 'App_Code\TenantEmailTransportContracts.vb'
$resolver = Read-Repo 'App_Code\TenantEmailTransportProfileResolver.vb'
$credentialStore = Read-Repo 'App_Code\EmailCredentialStore.vb'
$transport = Read-Repo 'App_Code\MailKitEmailTransport.vb'
$templates = Read-Repo 'App_Code\KeepStoreEmailTemplate.vb'
$runtimeHarness = Read-Repo 'Tools\EmailTransportRuntimeCoreHarness.vb'

Assert-Check ($order -match 'New TenantEmailDeliveryService\(\)\.Deliver\(emailRequest\)') '01_ORDER_CUSTOMER_CENTRAL_FACADE'
Assert-Check ($order -match 'emailRequest\.BccRecipients\.Add') '02_ORDER_ADMIN_BCC_PRESERVED'
Assert-Check (Has-OrderedText $order 'trns.Commit()' 'SendEmail(') '03_ORDER_EMAIL_AFTER_COMMIT'
$orderSender = [regex]::Match($order, '(?s)Public Function SendEmail\(.*?\n\s*End Function').Value
Assert-Check (([regex]::Matches($orderSender, 'TenantEmailDeliveryService\(\)\.Deliver')).Count -eq 1) '04_ORDER_SINGLE_SEND_NO_RETRY'

Assert-Check ($registration -match 'New TenantEmailDeliveryService\(\)\.Deliver\(request\)') '05_REGISTRATION_CENTRAL_FACADE'
Assert-Check ($registration -match 'AccountRegistration' -and $templates -match 'Registrazione account completata') '06_REGISTRATION_CONFIRMATION_PRESERVED'
Assert-Check ($passwordReset -match 'New TenantEmailDeliveryService\(\)\.Deliver\(deliveryRequest\)') '07_PASSWORD_RESET_CENTRAL_FACADE'
Assert-Check ($passwordReset -match 'GenericResetMessage' -and $passwordReset -match 'TryFindDeterministicAccount.*Then\s*\r?\n\s*Return') '08_PASSWORD_RESET_ANTI_ENUMERATION'
Assert-Check ($passwordReset -match 'resetpassword\.aspx' -and $passwordReset -match '\?token=' -and $templates -match 'RenderPasswordReset') '09_PASSWORD_RESET_ONE_TIME_LINK'

Assert-Check ($modernContact -match 'New TenantEmailDeliveryService\(\)\.Deliver\(deliveryRequest\)') '10_CONTACT_MODERN_CENTRAL_FACADE'
Assert-Check ($legacyContact -match 'New TenantEmailDeliveryService\(\)\.Deliver\(deliveryRequest\)') '11_CONTACT_LEGACY_CENTRAL_FACADE'
Assert-Check ($modernContact -match 'ReplyToRecipients\.Add' -and $legacyContact -match 'ReplyToRecipients\.Add') '12_CONTACT_REPLY_TO_PRESERVED'
Assert-Check ($facade -match 'CcRecipients' -and $facade -match 'AddAddresses\(message\.Cc') '13_FACADE_CC_SUPPORTED'
Assert-Check ($facade -match 'BccRecipients' -and $facade -match 'AddAddresses\(message\.Bcc') '14_FACADE_BCC_SUPPORTED'
Assert-Check ($facade -match 'TenantEmailAttachment' -and $facade -match 'builder\.Attachments\.Add') '15_FACADE_ATTACHMENTS_SUPPORTED'
Assert-Check ($registration -match 'AccountProfileUpdated' -and $registration -match 'Email\("Profilo aggiornato sul sito ", 2\)') '16_PROFILE_UPDATE_CENTRAL_FACADE'

Assert-Check ($documents -match 'INSERT INTO INVIADOCUMENTI') '17_DOCUMENT_QUEUE_PRESERVED'
Assert-Check ($coupons -match 'INVIADOCUMENTI' -and $coupons -notmatch '(?i)\bSmtpClient\b|System\.Net\.Mail|TenantEmailDeliveryService') '18_EXTERNAL_DOCUMENT_SENDER_BOUNDARY'
Assert-Check ($order -match 'LoadOrderEmailBrandData\(conn, receiptAziendaId, False\)' -and $order -match '\.AziendaId\s*=\s*receiptAziendaId') '19_ORDER_TENANT_FROM_PERSISTED_DOCUMENT'
Assert-Check ($modernContact -match 'StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)') '20_CONTACT_MODERN_SERVER_TENANT'
Assert-Check ($legacyContact -match 'StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)') '21_CONTACT_LEGACY_SERVER_TENANT'
Assert-Check ($registration -match 'StorefrontSeoTenantContext\.Resolve\(HttpContext\.Current\)') '22_REGISTRATION_SERVER_TENANT'
Assert-Check ($passwordReset -match '\.AziendaId\s*=\s*companyInfo\.AziendaId') '23_RESET_SERVER_TENANT'
Assert-Check ($facade -match 'Private Const TransactionalPurpose As String = "TRANSACTIONAL"' -and $facade -match '\.Purpose = TransactionalPurpose') '24_TRANSACTIONAL_PURPOSE_ENFORCED'

Assert-Check ($resolver -match 'TenantEmailTransportProfileState\.Disabled') '25_DISABLED_PROFILE_FAIL_CLOSED'
Assert-Check ($resolver -match 'NOT_VERIFIED' -and $resolver -match 'TenantEmailTransportProfileState\.NotOperational') '26_UNVERIFIED_PROFILE_FAIL_CLOSED'
Assert-Check ($credentialStore -match '\^dpapi-v1:' -and $resolver -match 'TryParseReference\(value, parts\)' -and $resolver -match 'CredentialMissing') '27_PLACEHOLDER_REFERENCE_REJECTED'
Assert-Check ($resolver -match 'String\.IsNullOrWhiteSpace\(record\.CredentialReference\)' -and $resolver -match 'CredentialMissing') '28_MISSING_CREDENTIAL_FAIL_CLOSED'
Assert-Check ($resolver -match 'SchemaUnavailable' -and $resolver -match 'NotConfigured') '29_SCHEMA_AND_EMPTY_PROFILE_FAIL_CLOSED'
Assert-Check ($runtimeHarness -match 'FACADE_DISABLED_NO_FALLBACK' -and $runtimeHarness -match 'FACADE_CREDENTIAL_MISSING_NO_FALLBACK') '30_ZERO_LEGACY_FALLBACK_HARNESS'

$runtimePaths = @(& git -C $repo ls-files -- '*.vb' '*.aspx' '*.ashx') | Where-Object { $_ -notlike 'Tools/*' -and $_ -notlike 'Database Taikun/*' }
$legacyViolations = New-Object System.Collections.Generic.List[string]
foreach ($relative in $runtimePaths) {
    if ($relative -eq 'App_Code/MailKitEmailTransport.vb') { continue }
    $text = Read-Repo ($relative.Replace('/', '\'))
    if ($text -match '(?i)System\.Net\.Mail|\bSmtpClient\b|\bMailMessage\b') { $legacyViolations.Add($relative) }
}
Assert-Check ($legacyViolations.Count -eq 0) '31_ZERO_DIRECT_SMTP_APPLICATION_CALLERS'
$callerText = @($order, $registration, $passwordReset, $modernContact, $legacyContact, $documents, $coupons, $master) -join "`n"
Assert-Check ($callerText -notmatch '(?i)Password_smtp|User_smtp|Session\s*\(\s*["'']smtp["'']') '32_ZERO_LEGACY_SMTP_READS'
Assert-Check ($templates -match 'non contiene password' -and $templates -notmatch '(?i)AddInfoItem\([^\r\n]+Password') '33_NO_USER_PASSWORD_IN_EMAIL'
Assert-Check ($facade -match 'SafeToken' -and $order -match 'ORDER_EMAIL_BUILD_FAILURE type=' -and $modernContact -match 'CONTACT_EMAIL_FAILURE type=') '34_SANITIZED_TELEMETRY_ONLY'
Assert-Check (([regex]::Matches($facade, '_transport\.Deliver')).Count -eq 1 -and $facade -notmatch '(?i)retry|Thread\.Sleep') '35_NO_AUTOMATIC_SEND_RETRY'
Assert-Check ($order -match 'receiptAziendaId' -and $order -notmatch '(?i)Session\.Item\("AziendaId"\)\s*=\s*2') '36_ORDER_MULTISTOREFRONT_PROVENANCE'
Assert-Check ($order -match 'If\(orderEmailSent, "completed", "failed"\)' -and $order -match 'Return deliveryResult IsNot Nothing AndAlso deliveryResult\.Status = EmailTransportOperationStatus\.Succeeded') '37_CHECKOUT_EMAIL_OUTCOME_ACCURATE'
Assert-Check ($transport -match 'Class MailKitEmailTransport' -and $facade -match 'Class TenantEmailDeliveryService') '38_RUNTIME_CORE_AND_FACADE_PRESENT'
Assert-Check ((Test-Path -LiteralPath (Join-Path $repo 'Tools\Restore-EmailTransportDependencies.ps1'))) '39_DEPENDENCY_RESTORE_AVAILABLE'

$parseErrors = New-Object System.Collections.Generic.List[string]
foreach ($script in @('Tools\Test-TenantEmailAllCallersMigration.ps1','Tools\Test-MultiProviderTenantEmailRuntimeCore.ps1','Tools\Test-OrderEmailDelivery.ps1','Tools\Test-OrderStorefrontProvenanceEmail.ps1')) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $script), [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { $parseErrors.Add($script) }
}
Assert-Check ($parseErrors.Count -eq 0) '40_POWERSHELL_SYNTAX'

$manuals = @('docs\KEEPSTORE_MASTERPLAN_OPERATIVO.md','docs\KEEPSTORE_SYSTEM_BLUEPRINT.md','docs\KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md')
$markdownOk = $true
foreach ($manual in $manuals) {
    $text = Read-Repo $manual
    if (([regex]::Matches($text, '(?m)^# ')).Count -ne 1 -or (([regex]::Matches($text, '(?m)^```')).Count % 2) -ne 0) { $markdownOk = $false }
}
Assert-Check $markdownOk '41_CANONICAL_MARKDOWN_STRUCTURE'
Assert-Check ($documents -notmatch '(?i)\bSmtpClient\b|System\.Net\.Mail|TenantEmailDeliveryService') '42_DOCUMENT_PAGE_REMAINS_QUEUE_ONLY'
$statusSender = @(& git -C $repo grep -l -E 'stato ordine|variazione stato' -- '*.vb' 2>$null)
$statusDirect = $false
foreach ($relative in $statusSender) {
    $text = Read-Repo ($relative.Replace('/', '\'))
    if ($text -match '(?i)\bSmtpClient\b|System\.Net\.Mail|TenantEmailDeliveryService') { $statusDirect = $true }
}
Assert-Check (-not $statusDirect) '43_NO_UNDISCLOSED_ORDER_STATUS_SENDER'
Assert-Check ($master -notmatch '(?i)Session\s*\(\s*["''](?:smtp|User_smtp|Password_smtp)["'']' -and
              $master -notmatch '(?i)SELECT\s+\*\s+["'']?\s*&?\s*\r?\n?\s*["'']?FROM\s+aziende') '44_SMTP_CREDENTIALS_REMOVED_FROM_SESSION'

if ($checks -ne 44) { throw ('UNEXPECTED_CHECK_COUNT=' + $checks) }
Write-Output ('TENANT_EMAIL_ALL_CALLERS_MIGRATION_PASS checks=' + $checks)
