[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runnerPath = Join-Path $PSScriptRoot 'Verify-EmailTransportConnection.ps1'
$hostPath = Join-Path $PSScriptRoot 'EmailTransportConnectionVerifier.vb'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStore-EmailVerifierTests-' + [Guid]::NewGuid().ToString('N'))
$resourceRecord = Join-Path ([IO.Path]::GetTempPath()) ('email-verifier-resources-' + [Guid]::NewGuid().ToString('N') + '.json')
$resourceState = [ordered]@{ Directory = $temporaryRoot; Children = @('application\web.config','EmailOfflineSinks.vb','EmailOfflineProbe.exe','copied dependency DLLs'); GeneratedBuildDirectoryWithin = $temporaryRoot; BuildDirectory = ''; State = 'PLANNED' }
[IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject $resourceState -Depth 3))
$passed = 0
$build = $null

function Assert-Check([bool]$Condition, [string]$Code) {
    if (-not $Condition) { throw $Code }
    $script:passed += 1
    Write-Output ('PASS ' + $Code)
}

try {
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$parseErrors)
    Assert-Check (@($parseErrors).Count -eq 0) 'VERIFIER_POWERSHELL_PARSE'
    $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    $allowed = @('AziendaId','Purpose','ApplicationRoot','ConnectionStringName','CredentialRoot')
    Assert-Check ($parameterNames.Count -eq $allowed.Count -and @($parameterNames | Where-Object { $_ -notin $allowed }).Count -eq 0) 'VERIFIER_ARGUMENT_CONTRACT'

    [IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
    $application = Join-Path $temporaryRoot 'application'
    [IO.Directory]::CreateDirectory($application) | Out-Null
    [IO.File]::WriteAllText((Join-Path $application 'web.config'), '<configuration><connectionStrings><clear/><add name="alternative" connectionString="Server=alternative.invalid;Database=other;" providerName="MySql.Data.MySqlClient"/><add name="EntropicConnectionString" connectionString="Server=fixture-mail.invalid;Port=3306;Database=fixture_mail;User ID=fixture-user;Password=KS-DBCFG-FIXTURE-MAIL;" providerName="MySql.Data.MySqlClient"/></connectionStrings></configuration>')

    # Dot-sourcing never invokes the administrative entrypoint or reads a real profile.
    . $runnerPath -AziendaId 1 -Purpose 'TRANSACTIONAL' -ApplicationRoot $application -CredentialRoot (Join-Path $temporaryRoot 'credentials')
    $originalTemp = $env:TEMP
    $originalTmp = $env:TMP
    try {
        $env:TEMP = $temporaryRoot
        $env:TMP = $temporaryRoot
        $build = New-EmailVerifierBuild $repo
    } finally {
        $env:TEMP = $originalTemp
        $env:TMP = $originalTmp
    }
    $resourceState.BuildDirectory = $build.Root
    [IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject $resourceState -Depth 3))
    Assert-Check (Test-Path -LiteralPath $build.Executable -PathType Leaf) 'PRODUCTION_WRAPPER_AND_DEPENDENCIES_COMPILE'
    $invalidOutput = @(& $build.Executable '--password' 'KS-DBCFG-FIXTURE-ARGUMENT' 2>$null)
    Assert-Check ($LASTEXITCODE -eq 10 -and (Test-EmailVerifierOutput $invalidOutput)) 'PRODUCTION_ENTRYPOINT_INVALID_INPUT_NO_NETWORK'

    # Compile the actual verifier/reader/identity provider. Only external-effect
    # dependencies are replaced by sinks; no runtime test switch is introduced.
    $fixturePath = Join-Path $temporaryRoot 'EmailOfflineSinks.vb'
    $fixture = @'
Imports System
Imports System.IO
Imports System.Globalization
Imports System.Text.RegularExpressions

Public NotInheritable Class MailKitEmailSmtpSessionFactory
End Class

Public NotInheritable Class MailKitEmailTransport
    Public Shared Calls As Integer
    Public Shared LastCompany As Integer
    Public Shared LastPurpose As String
    Public Shared LastConnection As String
    Public Shared Result As EmailConnectionVerificationResult
    Public Sub New(ByVal resolver As Object, ByVal credentials As Object, ByVal sessions As Object, ByVal telemetry As Object)
    End Sub
    Public Function VerifyConnection(ByVal value As String, ByVal company As Integer,
                                     ByVal purpose As String, ByVal correlation As String) As EmailConnectionVerificationResult
        Calls += 1
        LastCompany = company
        LastPurpose = purpose
        LastConnection = value
        If Result IsNot Nothing Then Result.CorrelationId = correlation
        Return Result
    End Function
End Class

Public Module EmailOfflineProbe
    Private Checks As Integer
    Private Sub Check(ByVal condition As Boolean, ByVal code As String)
        If Not condition Then Throw New InvalidOperationException(code)
        Checks += 1
    End Sub

    Private Function Run(ByVal arguments As String(), ByRef output As String) As Integer
        Dim original As TextWriter = Console.Out
        Using sink As New StringWriter(CultureInfo.InvariantCulture)
            Try
                Console.SetOut(sink)
                Return EmailTransportConnectionVerifier.Main(arguments)
            Finally
                Console.SetOut(original)
                output = sink.ToString()
            End Try
        End Using
    End Function

    Private Function Arguments(ByVal application As String, ByVal credentials As String,
                               ByVal company As Integer, ByVal purpose As String,
                               Optional ByVal name As String = "EntropicConnectionString") As String()
        Return {"--azienda-id", company.ToString(CultureInfo.InvariantCulture),
                "--purpose", purpose, "--application-root", application,
                "--connection-string-name", name, "--credential-root", credentials}
    End Function

    Public Function Main(ByVal args As String()) As Integer
        Try
            Dim application As String = args(0)
            Dim credentials As String = Path.Combine(Path.GetDirectoryName(application), "credentials")
            Dim output As String = Nothing
            For Each company As Integer In {1, 2}
                For Each purpose As String In {"TRANSACTIONAL", "MARKETING"}
                    MailKitEmailTransport.Result = New EmailConnectionVerificationResult With {
                        .Status = EmailTransportOperationStatus.Succeeded, .ProfileState = TenantEmailTransportProfileState.Ready,
                        .FailureKind = EmailTransportFailureKind.None, .Phase = "VERIFY", .Code = "SYNTHETIC_VERIFIED",
                        .AuthenticationMode = "Password", .SecurityMode = "StartTls", .TimestampUtc = DateTime.UtcNow}
                    Check(Run(Arguments(application, credentials, company, purpose), output) = 0, "VERIFIER_SUCCESS")
                    Check(MailKitEmailTransport.LastCompany = company AndAlso MailKitEmailTransport.LastPurpose = purpose, "VERIFIER_SCOPE")
                    Check(MailKitEmailTransport.LastConnection = KeepStoreConfigurationReader.ReadConnectionString(application), "VERIFIER_NAMED_VALUE")
                    Check(output.Trim().Split({Environment.NewLine}, StringSplitOptions.None).Length = 9, "VERIFIER_OUTPUT_FIELDS")
                    Check(Not Regex.IsMatch(output, "(?i)password\s*=|server\s*=|fixture-mail|fixture-user|KS-DBCFG-FIXTURE"), "VERIFIER_SECRET_OUTPUT")
                Next
            Next
            Dim calls As Integer = MailKitEmailTransport.Calls
            Check(Run(Arguments(application, credentials, 1, "TRANSACTIONAL", "missing"), output) = 10, "VERIFIER_MISSING_NAME")
            Check(MailKitEmailTransport.Calls = calls, "VERIFIER_NO_FALLBACK_OR_TRANSPORT")
            Check(Regex.IsMatch(output, "CODE=DBCFG_[A-Z0-9_]+"), "VERIFIER_SANITIZED_CONFIGURATION_CODE")

            Dim failures As EmailTransportFailureKind() = {EmailTransportFailureKind.Credential, EmailTransportFailureKind.Certificate,
                EmailTransportFailureKind.HostnameMismatch, EmailTransportFailureKind.Authentication, EmailTransportFailureKind.Timeout,
                EmailTransportFailureKind.Dns, EmailTransportFailureKind.Tcp, EmailTransportFailureKind.InvalidRequest}
            Dim expected As Integer() = {21, 30, 30, 31, 32, 33, 33, 10}
            For index As Integer = 0 To failures.Length - 1
                MailKitEmailTransport.Result = New EmailConnectionVerificationResult With {
                    .Status = EmailTransportOperationStatus.Failed, .ProfileState = TenantEmailTransportProfileState.Ready,
                    .FailureKind = failures(index), .Phase = "VERIFY", .Code = "SYNTHETIC_FAILURE",
                    .AuthenticationMode = "Password", .SecurityMode = "StartTls", .TimestampUtc = DateTime.UtcNow}
                Dim actualExit As Integer = Run(Arguments(application, credentials, 1, "TRANSACTIONAL"), output)
                Check(actualExit = expected(index), "VERIFIER_FAILURE_EXIT_" & index.ToString(CultureInfo.InvariantCulture) & "_" & actualExit.ToString(CultureInfo.InvariantCulture))
            Next
            MailKitEmailTransport.Result = New EmailConnectionVerificationResult With {
                .Status = EmailTransportOperationStatus.Rejected, .ProfileState = TenantEmailTransportProfileState.NotConfigured,
                .FailureKind = EmailTransportFailureKind.Resolver, .Phase = "RESOLVER", .Code = "SYNTHETIC_PROFILE",
                .AuthenticationMode = "N_A", .SecurityMode = "N_A", .TimestampUtc = DateTime.UtcNow}
            Check(Run(Arguments(application, credentials, 1, "TRANSACTIONAL"), output) = 20, "VERIFIER_PROFILE_EXIT")
            MailKitEmailTransport.Result = Nothing
            Check(Run(Arguments(application, credentials, 1, "TRANSACTIONAL"), output) = 40, "VERIFIER_INTERNAL_EXIT")
            Console.WriteLine("EMAIL_VERIFIER_OFFLINE_SINK_PASS checks=" & Checks.ToString(CultureInfo.InvariantCulture))
            Return 0
        Catch ex As Exception
            Dim code As String = If(Regex.IsMatch(ex.Message, "^VERIFIER_[A-Z0-9_]+$"), ex.Message, "VERIFIER_INTERNAL_FAILURE")
            Console.Error.WriteLine("EMAIL_VERIFIER_OFFLINE_SINK_FAILED_" & code)
            Return 1
        End Try
    End Function
End Module
'@
    [IO.File]::WriteAllText($fixturePath, $fixture, [Text.UTF8Encoding]::new($false))
    $references = @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll','System.Security.dll',
        (Join-Path $repo 'Bin\MySql.Data.dll'), (Join-Path $repo 'Bin\MimeKit.dll'))
    $sources = @('Tools\EmailTransportConnectionVerifier.vb','Tools\KeepStoreConfigurationReader.vb',
        'App_Code\TenantEmailTransportContracts.vb','App_Code\TenantEmailTransportProfileResolver.vb','App_Code\EmailCredentialStore.vb') | ForEach-Object { Join-Path $repo $_ }
    $probe = Join-Path $temporaryRoot 'EmailOfflineProbe.exe'
    $compilerOutput = @(& (Get-EmailVerifierCompiler) /nologo /target:exe /main:EmailOfflineProbe /optionstrict+ ('/out:' + $probe) ('/reference:' + ($references -join ',')) $sources $fixturePath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $compilerOutput | ForEach-Object { if ([Convert]::ToString($_) -match '\berror BC[0-9]+:.*$') { Write-Output ('SYNTHETIC_COMPILER ' + $Matches[0]) } }
    }
    Assert-Check ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $probe)) 'OFFLINE_SINK_COMPILATION'
    foreach ($dependency in Get-ChildItem -LiteralPath $build.Root -Filter '*.dll' -File) {
        Copy-Item -LiteralPath $dependency.FullName -Destination $temporaryRoot
    }
    $probeOutput = @(& $probe $application 2>&1)
    Assert-Check ($LASTEXITCODE -eq 0 -and ($probeOutput -join "`n") -match 'EMAIL_VERIFIER_OFFLINE_SINK_PASS checks=33') 'REAL_VERIFIER_WITH_OFFLINE_EFFECT_SINKS'
    $probeOutput | Write-Output
    Assert-Check (($invalidOutput -join "`n") -notmatch '(?i)KS-DBCFG-FIXTURE|server\s*=|password\s*=|dpapi-v1:') 'PRODUCTION_FAILURE_OUTPUT_SANITIZED'
    Write-Output ('EMAIL_TRANSPORT_CONNECTION_VERIFIER_PASS checks=' + $passed)
} finally {
    foreach ($ownedRoot in @($(if ($null -ne $build) { $build.Root }), $temporaryRoot)) {
        if (-not [string]::IsNullOrWhiteSpace($ownedRoot) -and (Test-Path -LiteralPath $ownedRoot)) {
            $resolved = [IO.Path]::GetFullPath($ownedRoot)
            $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
            if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'UNSAFE_EMAIL_TEST_CLEANUP' }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
    $resourceState.State = 'CLEANED'
    [IO.File]::WriteAllText($resourceRecord, (ConvertTo-Json -InputObject $resourceState -Depth 3))
}
