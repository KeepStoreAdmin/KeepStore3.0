[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$servicePath = Join-Path $repoRoot 'App_Code\OrderEmailDeliveryService.vb'
$harnessPath = Join-Path $PSScriptRoot 'OrderEmailDeliveryHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreOrderEmail-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'OrderEmailDeliveryHarness.exe'

function Read-RepoFile([string]$relativePath) {
    return [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

foreach ($required in @($compiler, $servicePath, $harnessPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw ('REQUIRED_FILE_MISSING=' + $required) }
}

$order = Read-RepoFile 'ordine.aspx.vb'
$service = Read-RepoFile 'App_Code\OrderEmailDeliveryService.vb'
$facade = Read-RepoFile 'App_Code\TenantEmailDeliveryService.vb'
$transport = Read-RepoFile 'App_Code\MailKitEmailTransport.vb'

Assert-Source ($order -match 'Function SendEmail\([\s\S]*?\) As Boolean') 'ORDER_EMAIL_RETURNS_DELIVERY_RESULT'
Assert-Source ($order -match 'If\(orderEmailSent, "completed", "failed"\)') 'ORDER_EMAIL_TRACE_REFLECTS_FAILURE'
Assert-Source ($order -match 'LoadOrderEmailBrandData\(conn, receiptAziendaId, False\)') 'ORDER_EMAIL_TENANT_FROM_PERSISTED_DOCUMENT'
Assert-Source ($order -match 'New TenantEmailDeliveryService\(\)\.Deliver\(emailRequest\)') 'ORDER_EMAIL_CENTRAL_FACADE'
Assert-Source ($order -match 'BuildResultLog\(receiptAziendaId, id, deliveryResult\)') 'ORDER_EMAIL_RESULT_DIAGNOSTICS_SANITIZED'
Assert-Source ($order -notmatch '(?i)\bSmtpClient\b|Password_smtp|User_smtp|emailBrand\.SmtpHost') 'ORDER_EMAIL_NO_LEGACY_SMTP'
Assert-Source ($order -notmatch 'emailRequest\.BccRecipients\.Add' -and
               $facade -match 'TenantEmailMessageClassifications\.OrderConfirmation\s+Return True' -and
               $transport -match 'If administrativeCopyFromProfileReplyTo Then ApplyAdministrativeCopy\(message, profile\)' -and
               $transport -match 'Dim address As String = profile\.ReplyToAddress' -and
               $transport -match 'message\.Bcc\.Add\(New MailboxAddress\(String\.Empty, address\)\)') 'ORDER_EMAIL_ADMIN_BCC_CENTRAL_PROFILE'
Assert-Source ($order -notmatch 'emailRequest\.ReplyToRecipients\.Add' -and
               $transport -match 'message\.ReplyTo\.Count = 0' -and
               $transport -match 'message\.ReplyTo\.Add\(New MailboxAddress\(String\.Empty, profile\.ReplyToAddress\)\)') 'ORDER_EMAIL_REPLY_TO_AUTHORITATIVE_PROFILE'
Assert-Source ($service -notmatch '(?i)taikun|webaffare') 'EMAIL_SERVICE_HAS_NO_CLIENT_HARDCODE'
Assert-Source ($service -notmatch '(?i)password\s*=\s*"[^\"]+"') 'EMAIL_SERVICE_HAS_NO_SECRET_LITERAL'
Assert-Source ($service -notmatch '(?i)System\.Net\.Mail|\bSmtpClient\b|\bMailMessage\b') 'ORDER_DIAGNOSTICS_NO_DIRECT_SMTP'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" /reference:System.dll $servicePath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'ORDER_EMAIL_HARNESS_COMPILE_FAILED' }
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'ORDER_EMAIL_HARNESS_FAILED' }
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

Write-Output 'PASS MULTISTOREFRONT_ORDER_EMAIL_DELIVERY'
