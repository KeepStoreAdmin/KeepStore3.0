[CmdletBinding()]
param([string]$RepositoryRoot, [switch]$DiagnosticTestOnly)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'SAFE_PRECOMPILE_COMPILER_MISSING' }
$operationalConfig = Join-Path $RepositoryRoot 'web.config'
if (-not (Test-Path -LiteralPath $operationalConfig -PathType Leaf)) { throw 'SAFE_PRECOMPILE_SOURCE_CONFIG_MISSING' }

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$workRoot = Join-Path $tempBase ('ks-safe-precompile-' + [Guid]::NewGuid().ToString('N'))
$stage = Join-Path $workRoot 'source'
$output = Join-Path $workRoot 'compiled'
$cleanupError = $null

function Assert-PlainSourcePath([string]$path, [string]$root) {
    $current = [IO.Path]::GetFullPath($path)
    if (-not $current.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'SAFE_PRECOMPILE_PATH_OUTSIDE_REPOSITORY'
    }
    while ($current.Length -gt $root.Length) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'SAFE_PRECOMPILE_REPARSE_POINT'
        }
        $current = Split-Path -Parent $current
    }
}

function Remove-XmlComments([System.Xml.XmlNode]$node) {
    foreach ($child in @($node.ChildNodes)) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Comment) {
            [void]$node.RemoveChild($child)
        } else {
            Remove-XmlComments $child
        }
    }
}

function Assert-SyntheticConfigs([string]$directory, [string]$sourceHash, [string[]]$forbiddenValues) {
    $configs = @(Get-ChildItem -LiteralPath $directory -Recurse -File -Filter '*.config')
    foreach ($config in $configs) {
        if ((Get-FileHash -LiteralPath $config.FullName -Algorithm SHA256).Hash -eq $sourceHash) {
            throw 'SAFE_PRECOMPILE_OPERATIONAL_CONFIG_COPIED'
        }
        $content = Get-Content -LiteralPath $config.FullName -Raw
        foreach ($value in $forbiddenValues) {
            if ($content.IndexOf($value, [StringComparison]::Ordinal) -ge 0) {
                throw 'SAFE_PRECOMPILE_OPERATIONAL_VALUE_COPIED'
            }
        }
        if ($content -match '(?i)(?:password|pwd|client_secret|private_key)\s*=\s*[^;"''\s][^;"''\r\n]*') {
            throw 'SAFE_PRECOMPILE_NONEMPTY_SECRET_SETTING'
        }
    }
}

function Protect-CompilerDiagnostic(
    [string]$raw,
    [string[]]$forbiddenValues,
    [string]$stageRoot,
    [string]$outputRoot,
    [string]$repositoryRoot,
    [string]$temporaryRoot
) {
    if ([string]::IsNullOrEmpty($raw)) { return '' }
    $safe = $raw
    # Mask a complete connection setting before masking individual keys. The
    # source configuration itself is never included in the compiler stage.
    $safe = [regex]::Replace($safe,
        '(?is)\bconnectionString\s*=\s*(?:"[^"]*"|''[^'']*''|[^\s<>]+)',
        'connectionString=[REDACTED]')
    $safe = [regex]::Replace($safe,
        '(?i)\b(?:server|host|data source|user id|uid|database|initial catalog)\s*=\s*(?:"[^"]*"|''[^'']*''|[^\s;,<>]+)',
        '[REDACTED_CONNECTION_PART]')
    $safe = [regex]::Replace($safe, '(?i)\bBearer\s+[^\s,;]+', 'Bearer [REDACTED]')
    $safe = [regex]::Replace($safe,
        '(?i)\b(?:password|pwd|passphrase|client[_-]?secret|private[_-]?key|access[_-]?token|refresh[_-]?token|session[_-]?token|api[_-]?key|authorization|validationKey|decryptionKey)\s*[:=]\s*(?:"[^"]*"|''[^'']*''|[^\s;,<>]+)',
        '[REDACTED_SECRET]')
    $safe = [regex]::Replace($safe, '(?i)\b(?:ghp_|sk_live_)[A-Za-z0-9_-]{12,}\b', '[REDACTED_TOKEN]')
    $safe = [regex]::Replace($safe,
        '(?is)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----',
        '[REDACTED_PRIVATE_KEY]')
    foreach ($value in @($forbiddenValues | Sort-Object Length -Descending -Unique)) {
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $safe = [regex]::Replace($safe, [regex]::Escape($value), '[REDACTED_VALUE]',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    $roots = @(
        @{ Path = $stageRoot; Label = '<SAFE_STAGE>' },
        @{ Path = $outputRoot; Label = '<SAFE_OUTPUT>' },
        @{ Path = $repositoryRoot; Label = '<REPOSITORY>' },
        @{ Path = $temporaryRoot; Label = '<TEMP>' },
        @{ Path = $env:USERPROFILE; Label = '<USERPROFILE>' }
    )
    foreach ($item in $roots) {
        if ([string]::IsNullOrWhiteSpace($item.Path)) { continue }
        $safe = [regex]::Replace($safe, [regex]::Escape([string]$item.Path), [string]$item.Label,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $safe
}

function Assert-DiagnosticSanitizer([string]$stageRoot, [string]$outputRoot,
    [string]$repositoryRoot, [string]$temporaryRoot) {
    $fake = 'FAKE_PASSWORD_FOR_SANITIZER_12345'
    $sample = @(
        ($stageRoot + '\web.config(12): error ASPCONFIG: Unrecognized attribute targetFramework.'),
        'error ASPCONFIG: Cannot load assembly Example.Provider; section system.codedom; type Example.Compiler.',
        'Configuration error across multiple lines.',
        'Section: system.web',
        ('Password=' + $fake + '; connectionString="Server=fake.invalid;Password=' + $fake + '"'),
        'Authorization: Bearer FAKE_BEARER_TOKEN_123456',
        'ApiKey=FAKE_API_KEY_123456',
        ('Source File: ' + $stageRoot + '\App_Code\Example.vb')
    ) -join "`n"
    $clean = Protect-CompilerDiagnostic $sample @($fake) $stageRoot $outputRoot $repositoryRoot $temporaryRoot
    if ($clean.Contains($fake) -or $clean.Contains('fake.invalid') -or
        $clean.Contains('FAKE_BEARER_TOKEN_123456') -or $clean.Contains('FAKE_API_KEY_123456') -or
        -not $clean.Contains('ASPCONFIG: Unrecognized attribute targetFramework') -or
        -not $clean.Contains('Example.Provider') -or -not $clean.Contains('system.codedom') -or
        -not $clean.Contains('Section: system.web') -or
        -not $clean.Contains('<SAFE_STAGE>\web.config(12)')) {
        throw 'SAFE_PRECOMPILE_DIAGNOSTIC_SANITIZER_TEST_FAILED'
    }
    Write-Output 'SAFE_PRECOMPILE_DIAGNOSTIC_SANITIZER_TEST=PASS'
}

if ($DiagnosticTestOnly) {
    Assert-DiagnosticSanitizer (Join-Path $tempBase 'ks-safe-precompile-synthetic\source') `
        (Join-Path $tempBase 'ks-safe-precompile-synthetic\compiled') $RepositoryRoot $tempBase
    return
}

try {
    New-Item -ItemType Directory -Path $stage, $output -Force | Out-Null

    # Only tracked compilation inputs are copied. Every original .config,
    # App_Data file, document, tool, log and untracked asset is excluded first.
    $trackedRaw = git -C $RepositoryRoot ls-files -z --cached
    if ($LASTEXITCODE -ne 0) { throw 'SAFE_PRECOMPILE_GIT_INVENTORY_FAILED' }
    $tracked = @($trackedRaw -split "`0" | Where-Object { $_ })
    $sourceExtensions = @('.aspx', '.ascx', '.master', '.ashx', '.asax', '.vb', '.sitemap')
    $webReferenceExtensions = @('.wsdl', '.disco', '.discomap', '.svcmap', '.svcinfo')
    $copied = 0
    foreach ($relative in $tracked) {
        $normalized = $relative.Replace('\', '/')
        if ($normalized -match '^(?i:Tools|docs|Database Taikun|Dependencies|App_Data)/') { continue }
        $extension = [IO.Path]::GetExtension($normalized).ToLowerInvariant()
        $isSource = $sourceExtensions -contains $extension
        $isLibrary = $normalized -match '^(?i:Bin)/[^/]+\.dll$'
        $isWebReference = $normalized -match '^(?i:App_WebReferences)/' -and $webReferenceExtensions -contains $extension
        if (-not $isSource -and -not $isLibrary -and -not $isWebReference) { continue }
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $relative))
        Assert-PlainSourcePath $sourcePath $RepositoryRoot
        if ($isWebReference) {
            $metadata = Get-Content -LiteralPath $sourcePath -Raw
            if ($metadata -match '(?i)password\s*=|client_secret\s*=|-----BEGIN .*PRIVATE KEY|\b(?:ghp_|sk_live_)[A-Za-z0-9_-]{16,}') {
                throw 'SAFE_PRECOMPILE_WEB_REFERENCE_SENSITIVE'
            }
        }
        $destination = Join-Path $stage $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourcePath -Destination $destination
        $copied++
    }
    if ($copied -lt 100 -or -not (Test-Path -LiteralPath (Join-Path $stage 'paypalwebhook.aspx.vb')) -or
        -not (Test-Path -LiteralPath (Join-Path $stage 'Bin\MySql.Data.dll')) -or
        -not (Test-Path -LiteralPath (Join-Path $stage 'Global.asax'))) {
        throw 'SAFE_PRECOMPILE_INCOMPLETE_SOURCE_STAGE'
    }

    # Read the operational XML only in memory. Import exclusively compilation
    # settings; never serialize its connection, key, SMTP or service sections.
    $sourceXml = New-Object Xml.XmlDocument
    $sourceXml.Load($operationalConfig)
    $forbiddenValues = New-Object 'System.Collections.Generic.List[string]'
    foreach ($connection in @($sourceXml.SelectNodes('/configuration/connectionStrings/add'))) {
        $raw = [string]$connection.GetAttribute('connectionString')
        foreach ($match in [regex]::Matches($raw, '(?i)(?:password|pwd)\s*=\s*([^;]+)')) {
            $value = $match.Groups[1].Value.Trim()
            if ($value.Length -ge 8) { $forbiddenValues.Add($value) }
        }
    }
    foreach ($attribute in @($sourceXml.SelectNodes('/configuration/system.web/machineKey/@*'))) {
        if ($attribute.Value.Length -ge 8) { $forbiddenValues.Add($attribute.Value) }
    }
    foreach ($setting in @($sourceXml.SelectNodes('/configuration/appSettings/add'))) {
        if ($setting.GetAttribute('key') -match '(?i)secret|password|token|credential|api[_-]?key') {
            $value = $setting.GetAttribute('value')
            if ($value.Length -ge 8) { $forbiddenValues.Add($value) }
        }
    }

    $safeXml = New-Object Xml.XmlDocument
    $safeXml.LoadXml('<configuration/>')
    $safeConnections = $safeXml.CreateElement('connectionStrings')
    foreach ($connection in @($sourceXml.SelectNodes('/configuration/connectionStrings/add'))) {
        $name = $connection.GetAttribute('name')
        if ($name -notmatch '^[A-Za-z0-9_.-]{1,100}$') { throw 'SAFE_PRECOMPILE_CONNECTION_NAME_INVALID' }
        $entry = $safeXml.CreateElement('add')
        $entry.SetAttribute('name', $name)
        $entry.SetAttribute('connectionString', '')
        $provider = $connection.GetAttribute('providerName')
        if ($provider -match '^[A-Za-z0-9_.-]+$') { $entry.SetAttribute('providerName', $provider) }
        [void]$safeConnections.AppendChild($entry)
    }
    [void]$safeXml.DocumentElement.AppendChild($safeConnections)
    $safeAppSettings = $safeXml.CreateElement('appSettings')
    foreach ($setting in @($sourceXml.SelectNodes('/configuration/appSettings/add'))) {
        $key = $setting.GetAttribute('key')
        if ($key -notmatch '^[A-Za-z0-9_.:-]{1,150}$') { throw 'SAFE_PRECOMPILE_APPSETTING_NAME_INVALID' }
        $entry = $safeXml.CreateElement('add')
        $entry.SetAttribute('key', $key)
        $entry.SetAttribute('value', '')
        [void]$safeAppSettings.AppendChild($entry)
    }
    [void]$safeXml.DocumentElement.AppendChild($safeAppSettings)

    $safeWeb = $safeXml.CreateElement('system.web')
    foreach ($name in @('compilation', 'globalization', 'pages', 'customErrors', 'httpHandlers', 'httpModules', 'httpRuntime')) {
        $node = $sourceXml.SelectSingleNode('/configuration/system.web/' + $name)
        if ($null -eq $node) { continue }
        if ($node.OuterXml -match '(?i)configSource\s*=|\sfile\s*=|password\s*=|pwd\s*=|connectionString\s*=|clientSecret\s*=|privateKey\s*=') {
            throw 'SAFE_PRECOMPILE_COMPILE_SECTION_NOT_SAFE'
        }
        $imported = $safeXml.ImportNode($node, $true)
        Remove-XmlComments $imported
        if ($name -eq 'compilation' -and $imported.Attributes.GetNamedItem('targetFramework') -eq $null) {
            $imported.SetAttribute('targetFramework', '4.8')
        }
        [void]$safeWeb.AppendChild($imported)
    }
    [void]$safeXml.DocumentElement.AppendChild($safeWeb)
    foreach ($name in @('system.data', 'system.codedom', 'runtime')) {
        $node = $sourceXml.SelectSingleNode('/configuration/' + $name)
        if ($null -eq $node) { continue }
        if ($node.OuterXml -match '(?i)configSource\s*=|\sfile\s*=|password\s*=|pwd\s*=|connectionString\s*=|clientSecret\s*=|privateKey\s*=') {
            throw 'SAFE_PRECOMPILE_COMPILE_SECTION_NOT_SAFE'
        }
        $imported = $safeXml.ImportNode($node, $true)
        Remove-XmlComments $imported
        if ($name -eq 'system.codedom') {
            # The operational site has CompilerVersion=v3.5 and no explicit
            # targetFramework. The isolated .NET 4.8 compile must use v4.0.
            $versionOptions = @($imported.SelectNodes('compilers/compiler/providerOption[@name="CompilerVersion"]'))
            if ($versionOptions.Count -ne 1 -or $versionOptions[0].GetAttribute('value') -ne 'v3.5') {
                throw 'SAFE_PRECOMPILE_UNEXPECTED_COMPILER_VERSION'
            }
            $versionOptions[0].SetAttribute('value', 'v4.0')
        }
        [void]$safeXml.DocumentElement.AppendChild($imported)
    }
    $safeConfigPath = Join-Path $stage 'web.config'
    $safeXml.Save($safeConfigPath)

    $sourceHash = (Get-FileHash -LiteralPath $operationalConfig -Algorithm SHA256).Hash
    $stagedConfigs = @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter '*.config')
    if ($stagedConfigs.Count -ne 1 -or $stagedConfigs[0].FullName -ne $safeConfigPath) {
        throw 'SAFE_PRECOMPILE_UNEXPECTED_CONFIG'
    }
    Assert-SyntheticConfigs $stage $sourceHash $forbiddenValues.ToArray()
    Write-Output ('SAFE_PRECOMPILE_STAGED_FILES=' + $copied)
    Write-Output 'SAFE_PRECOMPILE_SYNTHETIC_CONFIG=PASS'
    Assert-DiagnosticSanitizer $stage $output $RepositoryRoot $tempBase

    $compilerStdout = ''
    $compilerStderr = ''
    $compilerExitCode = -1
    $compilerProcess = New-Object System.Diagnostics.Process
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $compiler
        $startInfo.Arguments = '-v / -errorstack -p "' + $stage + '" "' + $output + '"'
        $startInfo.WorkingDirectory = $stage
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $compilerProcess.StartInfo = $startInfo
        Write-Output 'SAFE_PRECOMPILE_COMPILER=FRAMEWORK64_V4_8'
        Write-Output 'SAFE_PRECOMPILE_INVOCATION=-v / -errorstack -p <SAFE_STAGE> <SAFE_OUTPUT>'
        try { [void]$compilerProcess.Start() }
        catch {
            Write-Output ('SAFE_PRECOMPILE_PROCESS_EXCEPTION_TYPE=' + $_.Exception.GetType().Name)
            throw 'SAFE_PRECOMPILE_PROCESS_START_FAILED'
        }
        # Both streams are drained concurrently, before waiting for exit.
        $stdoutTask = $compilerProcess.StandardOutput.ReadToEndAsync()
        $stderrTask = $compilerProcess.StandardError.ReadToEndAsync()
        if (-not $compilerProcess.WaitForExit(900000)) {
            try { $compilerProcess.Kill(); [void]$compilerProcess.WaitForExit(10000) } catch { }
            throw 'SAFE_PRECOMPILE_COMPILER_TIMEOUT'
        }
        if (-not [System.Threading.Tasks.Task]::WaitAll(
            [System.Threading.Tasks.Task[]]@($stdoutTask, $stderrTask), 30000)) {
            throw 'SAFE_PRECOMPILE_OUTPUT_DRAIN_TIMEOUT'
        }
        $compilerStdout = $stdoutTask.Result
        $compilerStderr = $stderrTask.Result
        $compilerExitCode = $compilerProcess.ExitCode
    } finally {
        $compilerProcess.Dispose()
    }
    Write-Output ('SAFE_PRECOMPILE_STDOUT_CHARS=' + $compilerStdout.Length)
    Write-Output ('SAFE_PRECOMPILE_STDERR_CHARS=' + $compilerStderr.Length)
    if ($compilerExitCode -ne 0) {
        $sanitizedStdout = Protect-CompilerDiagnostic $compilerStdout $forbiddenValues.ToArray() $stage $output $RepositoryRoot $tempBase
        $sanitizedStderr = Protect-CompilerDiagnostic $compilerStderr $forbiddenValues.ToArray() $stage $output $RepositoryRoot $tempBase
        $diagnostic = ($sanitizedStdout + "`n" + $sanitizedStderr)
        foreach ($value in $forbiddenValues) {
            if ($value.Length -ge 8 -and $diagnostic.IndexOf($value, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw 'SAFE_PRECOMPILE_DIAGNOSTIC_SANITIZATION_FAILED'
            }
        }
        $codes = @([regex]::Matches($diagnostic,
            '(?i)\b(?:BC\d{4,6}|CS\d{4,6}|ASPNET\d{4,6}|ASPCONFIG|ASPPARSE|ASPRUNTIME|ASPGEN)\b') |
            ForEach-Object { $_.Value.ToUpperInvariant() } | Select-Object -Unique)
        $relativeErrorFile = 'N/A'
        $errorLine = 'N/A'
        $component = 'COMPILER'
        $location = [regex]::Match($diagnostic,
            '(?i)<SAFE_STAGE>[\\/](?<path>[^\r\n()]+)\((?<line>\d+)(?:,\d+)?\)')
        if ($location.Success) {
            $relativeErrorFile = $location.Groups['path'].Value.Replace('\', '/')
            $errorLine = $location.Groups['line'].Value
            if ($relativeErrorFile -match '^(?i:App_Code)/') { $component = 'APP_CODE' }
            elseif ($relativeErrorFile -match '^(?i:App_WebReferences)/') { $component = 'WEB_REFERENCE' }
            elseif ($relativeErrorFile -ieq 'web.config') { $component = 'SYNTHETIC_CONFIG' }
            else { $component = 'WEBFORMS' }
        }
        $safeLines = @($diagnostic -split '\r?\n' | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and
            $_ -notmatch '^\s*(?:at\s+|--- End of stack trace|<[/!A-Za-z]|\d+\s*:)' })
        Write-Output 'SAFE_PRECOMPILE_FAILURE_PHASE=COMPILE'
        Write-Output ('SAFE_PRECOMPILE_FAILURE_CODES=' + $(if ($codes.Count) { $codes -join ',' } else { 'N/A' }))
        Write-Output ('SAFE_PRECOMPILE_FAILURE_FILE=' + $relativeErrorFile)
        Write-Output ('SAFE_PRECOMPILE_FAILURE_LINE=' + $errorLine)
        Write-Output ('SAFE_PRECOMPILE_FAILURE_COMPONENT=' + $component)
        Write-Output 'SAFE_PRECOMPILE_SANITIZED_DIAGNOSTIC_BEGIN'
        foreach ($line in @($safeLines | Select-Object -First 40)) {
            $boundedLine = if ($line.Length -gt 800) { $line.Substring(0, 800) + ' [TRUNCATED]' } else { $line }
            Write-Output $boundedLine
        }
        Write-Output 'SAFE_PRECOMPILE_SANITIZED_DIAGNOSTIC_END'
        Write-Output ('SAFE_PRECOMPILE_SANITIZED_LINES_TOTAL=' + $safeLines.Count)
        throw ('SAFE_PRECOMPILE_COMPILER_EXIT_' + $compilerExitCode)
    }
    Assert-SyntheticConfigs $output $sourceHash $forbiddenValues.ToArray()
    Write-Output 'SAFE_PRECOMPILE_RESULT=PASS'
    Write-Output 'SAFE_PRECOMPILE_OPERATIONAL_CONFIG_COPIES=0'
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath($workRoot).TrimEnd('\')
    if ($resolvedRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedRoot) -match '^ks-safe-precompile-[0-9a-f]{32}$' -and
        (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        try {
            Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop
            Write-Output 'SAFE_PRECOMPILE_OWN_TEMP_CLEANUP=PASS'
        } catch {
            $cleanupError = 'SAFE_PRECOMPILE_OWN_TEMP_CLEANUP_BLOCKED'
            Write-Warning $cleanupError
        }
    }
    if ($cleanupError) { throw $cleanupError }
}
