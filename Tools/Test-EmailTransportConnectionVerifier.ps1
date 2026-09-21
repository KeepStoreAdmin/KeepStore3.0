[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runnerPath = Join-Path $PSScriptRoot 'Verify-EmailTransportConnection.ps1'
$hostPath = Join-Path $PSScriptRoot 'EmailTransportConnectionVerifier.vb'
$passed = 0

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    $script:passed += 1
    Write-Output ('PASS ' + $Code)
}

function Invoke-InternalVerifier([string]$Executable, [string[]]$Arguments) {
    $lines = @(& $Executable @Arguments 2>$null)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Lines = @($lines)
        Text = ($lines -join "`n")
    }
}

$tokens = $null
$parseErrors = $null
$runnerAst = [Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$parseErrors)
$runnerText = Get-Content -LiteralPath $runnerPath -Raw
$hostText = Get-Content -LiteralPath $hostPath -Raw
$combinedText = $runnerText + "`n" + $hostText
$build = $null

try {
    Assert-Check ($parseErrors.Count -eq 0) '01_POWERSHELL_PARSE'
    Assert-Check ($runnerText -match 'Test-EmailVerifierAdministrator' -and
                  $runnerText -match 'EMAIL_VERIFY_ADMINISTRATOR_REQUIRED') '02_ADMINISTRATOR_REQUIRED'

    $parameterNames = @($runnerAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    $allowedParameters = @('AziendaId','Purpose','ApplicationRoot','ConnectionStringName','CredentialRoot')
    Assert-Check ($parameterNames.Count -eq $allowedParameters.Count -and
                  @($parameterNames | Where-Object { $_ -notin $allowedParameters }).Count -eq 0) '03_ONLY_ALLOWED_PARAMETERS'

    . $runnerPath -AziendaId 1 -Purpose 'TRANSACTIONAL' -ApplicationRoot $repo
    $build = New-EmailVerifierBuild $repo

    $baseArguments = @(
        '--azienda-id','1',
        '--purpose','TRANSACTIONAL',
        '--application-root',$repo,
        '--connection-string-name','EntropicConnectionString',
        '--credential-root','C:\ProgramData\KeepStore\EmailCredentials'
    )
    $passwordAttempt = Invoke-InternalVerifier $build.Executable @('--password','fixture','--purpose','TRANSACTIONAL','--application-root',$repo,'--connection-string-name','EntropicConnectionString','--credential-root','C:\ProgramData\KeepStore\EmailCredentials')
    Assert-Check ($passwordAttempt.ExitCode -eq 10 -and $passwordAttempt.Text -match 'CODE=EMAIL_VERIFY_ARGUMENT_NOT_ALLOWED') '04_PASSWORD_ARGUMENT_REJECTED'

    $referenceAttempt = Invoke-InternalVerifier $build.Executable @('--credential-reference','fixture','--purpose','TRANSACTIONAL','--application-root',$repo,'--connection-string-name','EntropicConnectionString','--credential-root','C:\ProgramData\KeepStore\EmailCredentials')
    Assert-Check ($referenceAttempt.ExitCode -eq 10 -and $referenceAttempt.Text -match 'CODE=EMAIL_VERIFY_ARGUMENT_NOT_ALLOWED') '05_CREDENTIAL_REFERENCE_ARGUMENT_REJECTED'

    $hostAttempt = Invoke-InternalVerifier $build.Executable @('--host','fixture.invalid','--purpose','TRANSACTIONAL','--application-root',$repo,'--connection-string-name','EntropicConnectionString','--credential-root','C:\ProgramData\KeepStore\EmailCredentials')
    $userAttempt = Invoke-InternalVerifier $build.Executable @('--username','fixture','--purpose','TRANSACTIONAL','--application-root',$repo,'--connection-string-name','EntropicConnectionString','--credential-root','C:\ProgramData\KeepStore\EmailCredentials')
    Assert-Check ($hostAttempt.ExitCode -eq 10 -and $userAttempt.ExitCode -eq 10) '06_HOST_AND_USERNAME_ARGUMENTS_REJECTED'

    $company1 = Invoke-InternalVerifier $build.Executable $baseArguments
    $company2Arguments = [string[]]$baseArguments.Clone()
    $company2Arguments[1] = '2'
    $company2 = Invoke-InternalVerifier $build.Executable $company2Arguments

    Assert-Check ($hostText -match 'Path\.Combine\(applicationRoot, "web\.config"\)' -and
                  $company1.Text -notmatch 'EMAIL_VERIFY_CONFIGURATION_INVALID') '07_WEB_CONFIG_REAL_PATH'
    Assert-Check ($hostText -match 'New EmailDatabaseIdentityProvider\(\)\.GetIdentity\(connectionString\)') '08_DATABASE_IDENTITY_DERIVED_BY_RUNTIME'
    Assert-Check ($company1.ExitCode -eq 21 -and
                  $company1.Text -match 'PROFILE_STATE=CREDENTIAL_MISSING' -and
                  $company1.Text -match 'CODE=PROFILE_CREDENTIAL_MISSING') '09_AZIENDA_1_REAL_PROFILE_PLACEHOLDER_FAIL_CLOSED'
    Assert-Check ($company2.ExitCode -eq 21 -and
                  $company2.Text -match 'PROFILE_STATE=CREDENTIAL_MISSING' -and
                  $company2.Text -match 'CODE=PROFILE_CREDENTIAL_MISSING') '10_AZIENDA_2_REAL_PROFILE_PLACEHOLDER_FAIL_CLOSED'
    Assert-Check ($runnerText -match "ValidateSet\('TRANSACTIONAL', 'MARKETING'\)" -and
                  $hostText -match 'purpose <> "TRANSACTIONAL" AndAlso purpose <> "MARKETING"') '11_PURPOSE_VALIDATED'

    $runtimeOutput = @(& (Join-Path $PSScriptRoot 'Test-MultiProviderTenantEmailRuntimeCore.ps1'))
    $runtimeText = $runtimeOutput -join "`n"
    Assert-Check ($runtimeText -match '03B_VERIFICATION_ACCEPTS_DISABLED_NOT_VERIFIED') '12_DISABLED_NOT_VERIFIED_ACCEPTED_FOR_ADMIN_VERIFY'
    Assert-Check ($runtimeText -match '03A_SEND_REJECTS_NOT_VERIFIED') '13_DISABLED_NOT_VERIFIED_REJECTED_FOR_DELIVERY'
    Assert-Check ($runtimeText -match '03C_VERIFICATION_REJECTS_PLACEHOLDER') '14_PLACEHOLDER_REJECTED_BEFORE_SMTP'
    Assert-Check ($runtimeText -match '17_CREDENTIAL_SCOPE_INVALID') '15_REFERENCE_SCOPE_MISMATCH_REJECTED'
    Assert-Check ($runtimeText -match '16_CREDENTIAL_FILE_MISSING') '16_CREDENTIAL_MISSING_REJECTED'
    Assert-Check ($runtimeText -match '17A_CREDENTIAL_DPAPI_INVALID') '17_DPAPI_INVALID_REJECTED'
    Assert-Check ($runtimeText -match '19_STARTTLS_EXPLICIT') '18_STARTTLS_EXPLICIT'
    Assert-Check ($runtimeText -match '21_IMPLICIT_TLS_EXPLICIT') '19_IMPLICIT_TLS_EXPLICIT'
    Assert-Check ($runtimeText -match '23_CERTIFICATE_REJECTED') '20_CERTIFICATE_REJECTED'
    Assert-Check ($runtimeText -match '24_HOSTNAME_MISMATCH') '21_HOSTNAME_MISMATCH_REJECTED'
    Assert-Check ($runtimeText -match '25_AUTHENTICATION_REJECTED') '22_AUTHENTICATION_REJECTED'
    Assert-Check ($runtimeText -match '26_TIMEOUT') '23_TIMEOUT_CLASSIFIED'
    Assert-Check ($runtimeText -match '11_OAUTH2_NOT_OPERATIONAL') '24_OAUTH2_NOT_OPERATIONAL'
    Assert-Check ($hostText -notmatch '(?i)MAIL FROM' -and $runtimeText -match '20_VERIFY_NO_MAIL_COMMANDS_AND_QUIT') '25_ZERO_MAIL_FROM'
    Assert-Check ($hostText -notmatch '(?i)RCPT TO' -and $runtimeText -match '20_VERIFY_NO_MAIL_COMMANDS_AND_QUIT') '26_ZERO_RCPT_TO'
    Assert-Check ($hostText -notmatch '(?i)\bDATA\b' -and $runtimeText -match '20_VERIFY_NO_MAIL_COMMANDS_AND_QUIT') '27_ZERO_DATA'
    Assert-Check ($runtimeText -match '20_VERIFY_NO_MAIL_COMMANDS_AND_QUIT') '28_QUIT_ON_VERIFICATION'

    $correlation1 = ($company1.Lines | Where-Object { $_ -match '^CORRELATION_ID=' }) -replace '^CORRELATION_ID=', ''
    $correlation2 = ($company2.Lines | Where-Object { $_ -match '^CORRELATION_ID=' }) -replace '^CORRELATION_ID=', ''
    Assert-Check ($correlation1 -match '^[a-f0-9]{32}$' -and
                  $correlation2 -match '^[a-f0-9]{32}$' -and
                  $correlation1 -ne $correlation2) '29_CORRELATION_ID_GENERATED'
    Assert-Check ((Test-EmailVerifierOutput $company1.Lines) -and
                  (Test-EmailVerifierOutput $company2.Lines)) '30_SANITIZED_OUTPUT_SCHEMA'
    Assert-Check (($company1.Text + $company2.Text) -notmatch '(?i)dpapi-v1:|password|server=|uid=|user id=|@|\\EmailCredentials\\') '31_NO_SECRET_OR_IDENTITY_OUTPUT'
    Assert-Check ($hostText -match 'ExitSuccess As Integer = 0' -and
                  $hostText -match 'ExitConfiguration As Integer = 10' -and
                  $hostText -match 'ExitProfileUnavailable As Integer = 20' -and
                  $hostText -match 'ExitCredential As Integer = 21' -and
                  $hostText -match 'ExitTls As Integer = 30' -and
                  $hostText -match 'ExitAuthentication As Integer = 31' -and
                  $hostText -match 'ExitTimeout As Integer = 32' -and
                  $hostText -match 'ExitTransport As Integer = 33' -and
                  $hostText -match 'ExitInternal As Integer = 40') '32_STABLE_EXIT_CODES'

    Assert-Check ($combinedText -notmatch '(?i)INSERT\s+INTO|UPDATE\s+`?aziende_email_transport|DELETE\s+FROM|DROP\s+(TABLE|DATABASE)|ALTER\s+TABLE|CREATE\s+TABLE') '33_NO_DATABASE_MUTATION'
    Assert-Check ($combinedText -notmatch '(?i)Restart-WebAppPool|Stop-WebAppPool|Start-WebAppPool|iisreset|ServerManager\.Sites\.Add|Set-WebBinding') '34_NO_IIS_MUTATION'
    Assert-Check ($combinedText -notmatch '(?i)HttpListener|TcpListener|New-Website|New-WebApplication|\.aspx|\.ashx') '35_NO_ENDPOINT_OR_LISTENER'

    $restoreOutput = @(& (Join-Path $PSScriptRoot 'Restore-EmailTransportDependencies.ps1') -DestinationBin (Join-Path $repo 'Bin') -VerifyOnly)
    Assert-Check (($restoreOutput -join "`n") -match 'EMAIL_DEPENDENCIES_VERIFIED') '36_CLEAN_DEPENDENCY_RESTORE_VERIFY'
    Assert-Check (Test-Path -LiteralPath (Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe')) '37_NET48_PRECOMPILE_TOOL_AVAILABLE'
    Assert-Check ($runtimeText -match 'EMAIL_TRANSPORT_RUNTIME_CORE_PASS checks=57') '38_RUNTIME_CORE_PASS'

    $callerOutput = @(& (Join-Path $PSScriptRoot 'Test-TenantEmailAllCallersMigration.ps1'))
    Assert-Check (($callerOutput -join "`n") -match 'TENANT_EMAIL_ALL_CALLERS_MIGRATION_PASS') '39_ALL_CALLERS_MIGRATED'

    $diffCheck = @(& git -C $repo diff --check 2>&1)
    Assert-Check ($LASTEXITCODE -eq 0) '40_GIT_DIFF_CHECK'
    $scanPaths = @(
        'Tools\Verify-EmailTransportConnection.ps1',
        'Tools\EmailTransportConnectionVerifier.vb',
        'Tools\Test-EmailTransportConnectionVerifier.ps1',
        'Tools\EmailTransportRuntimeCoreHarness.vb',
        'Tools\Test-MultiProviderTenantEmailRuntimeCore.ps1',
        'docs\KEEPSTORE_MASTERPLAN_OPERATIVO.md',
        'docs\KEEPSTORE_SYSTEM_BLUEPRINT.md',
        'docs\KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md'
    )
    $scanText = ($scanPaths | ForEach-Object { Get-Content -LiteralPath (Join-Path $repo $_) -Raw }) -join "`n"
    Assert-Check ($scanText -notmatch '(?i)(password|pwd)\s*=\s*["''][^<\r\n]+|server\s*=.*(password|pwd)\s*=|dpapi-v1:[0-9a-f]{64}:[1-9]') '41_SECRET_SCAN'

    $untracked = @(git -C $repo ls-files --others --exclude-standard)
    Assert-Check (@($untracked | Where-Object { $_ -like 'Public/assets/images/*' }).Count -eq 48 -and
                  @($untracked | Where-Object { $_ -like 'App_Data/Logs/*' }).Count -eq 5 -and
                  (git -C $repo diff --name-status) -contains "D`tDatabase Taikun/KeepStore.sql") '42_PROTECTED_FILES_PRESERVED'

    $manuals = @(
        'docs\KEEPSTORE_MASTERPLAN_OPERATIVO.md',
        'docs\KEEPSTORE_SYSTEM_BLUEPRINT.md',
        'docs\KEEPSTORE_AI_ASSISTED_SEARCH_BLUEPRINT.md'
    )
    $markdownOk = $true
    foreach ($relative in $manuals) {
        $content = Get-Content -LiteralPath (Join-Path $repo $relative) -Raw
        if (([regex]::Matches($content, '(?m)^# ')).Count -ne 1 -or
            ([regex]::Matches($content, '(?m)^```')).Count % 2 -ne 0) { $markdownOk = $false }
    }
    Assert-Check $markdownOk '43_MARKDOWN_VALID'

    Write-Output ('EMAIL_TRANSPORT_CONNECTION_VERIFIER_PASS checks=' + $passed)
} finally {
    if ($null -ne $build -and (Test-Path -LiteralPath $build.Root)) {
        Remove-Item -LiteralPath $build.Root -Recurse -Force
    }
}
