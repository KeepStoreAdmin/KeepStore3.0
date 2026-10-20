[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$BaseRef = 'origin/frontend-rebuild',
    [string]$CandidateManifestPath,
    [string]$ArtifactRoot,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }

function Test-SyntheticValue([string]$Value) {
    return $Value -cmatch '^(?:KS-DBCFG-(?:FIXTURE|TEST)-[A-Za-z0-9_.:-]+|SYNTHETIC[_-][A-Za-z0-9_.:-]+|FAKE[_-][A-Za-z0-9_.:-]+|fixture-[A-Za-z0-9_.:-]+)$'
}

function Invoke-GuardGit([string]$Root, [string[]]$Arguments) {
    $process=$null
    try {
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=@(Get-Command git.exe -CommandType Application -ErrorAction Stop)[0].Source
        $info.WorkingDirectory=$Root
        $info.UseShellExecute=$false
        $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true
        $info.RedirectStandardError=$true
        $info.EnvironmentVariables['GIT_OPTIONAL_LOCKS']='0'
        $quoted=@($Arguments|ForEach-Object {
            $argument=[regex]::Replace([string]$_,'(\\*)"','$1$1\"')
            $argument=[regex]::Replace($argument,'(\\+)$','$1$1')
            '"'+$argument+'"'
        })
        $info.Arguments=$quoted -join ' '
        $process=New-Object Diagnostics.Process
        $process.StartInfo=$info
        [void]$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr))
        if($process.ExitCode -ne 0){throw 'SECRETS_GUARD_GIT_FAILED'}
        # Git's CRLF warnings are not content or failures. Do not forward them.
        return @($stdout.Result -split '\r?\n'|Where-Object {$_ -ne ''})
    } finally {if($null -ne $process){$process.Dispose()}}
}

function Test-PrivatePublicationPath([string]$Path) {
    $normalized = $Path.Replace('\','/')
    return $normalized -match '(?i)(?:^|/)(?:web(?:\.[^/]+)?\.config|\.env(?:\.[^/]+)?|[^/]+\.(?:pfx|p12|key|dpapi|bak|backup|sql|log))$' -or
        $normalized -match '(?i)(?:^|/)(?:App_Data|backups|EmailCredentials)(?:/|$)'
}

function Find-SecretViolations([string]$Text, [string]$Path, [bool]$AllowSynthetic) {
    $codes = New-Object 'System.Collections.Generic.HashSet[string]'
    $rules = @(
        @{ Code='CONNECTION_PASSWORD'; Pattern='(?i)\b(?:password|pwd)\s*=\s*(?:(?<quote>["''])(?<value>[^"''\r\n]*)\k<quote>|(?<value>[^;\s"''<>]+))' },
        @{ Code='KEY_OR_TOKEN_LITERAL'; Pattern='(?i)\b(?:validationKey|decryptionKey|client_secret|api_key|access_token|refresh_token)\s*[:=]\s*["''](?<value>[^"''\r\n]+)["'']' },
        @{ Code='SECRET_ASSIGNMENT'; Pattern='(?i)(?:\$(?:password|pwd|secret|clientSecret|apiKey|accessToken|refreshToken)|\b(?:Password|Pwd|ClientSecret|ApiKey)(?:\s+As\s+String)?)\s*=\s*["''](?<value>[^"''\r\n]+)["'']' },
        @{ Code='JSON_SECRET'; Pattern='(?i)["''](?:password|pwd|secret|clientSecret|apiKey|accessToken|refreshToken)["'']\s*:\s*["''](?<value>[^"''\r\n]+)["'']' },
        @{ Code='YAML_SECRET'; Pattern='(?im)^\s*(?:password|pwd|secret|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token)\s*:\s*(?:["''](?<value>[^"''\r\n]+)["'']|(?<value>[^\r\n#]+))\s*(?:#.*)?$' }
    )
    foreach ($rule in $rules) {
        foreach ($match in [regex]::Matches($Text, $rule.Pattern)) {
            $value = $match.Groups['value'].Value.Trim()
            # Dynamic expressions are code, not an embedded credential. Literal
            # fixture values must each carry an explicit marker; no file exemption.
            if ($value.Length -eq 0) { continue }
            if ($AllowSynthetic -and $rule.Code -eq 'CONNECTION_PASSWORD' -and
                -not $match.Groups['quote'].Success -and $value -cmatch '^\$[A-Za-z_][A-Za-z0-9_.]*$') { continue }
            if ($AllowSynthetic -and (Test-SyntheticValue $value)) { continue }
            [void]$codes.Add($rule.Code)
        }
    }
    foreach ($match in [regex]::Matches($Text, '(?is)<add\b[^>]*\bkey\s*=\s*["''](?<key>[^"'']+)["''][^>]*\bvalue\s*=\s*["''](?<value>[^"'']*)["''][^>]*>')) {
        if ($match.Groups['key'].Value -notmatch '(?i)password|secret|token|api[_-]?key') { continue }
        $value = $match.Groups['value'].Value
        if ($value.Length -gt 0 -and -not ($AllowSynthetic -and (Test-SyntheticValue $value))) { [void]$codes.Add('XML_SECRET_SETTING') }
    }
    if ($Text -match '(?i)-----BEGIN (?:RSA |EC |ENCRYPTED )?PRIVATE KEY-----') { [void]$codes.Add('PRIVATE_KEY_MATERIAL') }
    if ($Text -match '(?is)<RSAKeyValue>\s*<Modulus>[^<]+</Modulus>.*?<D>[^<]+</D>') { [void]$codes.Add('PRIVATE_RSA_XML') }
    if ($Text -match '(?i)dpapi-v1:[0-9a-f]{64}:[1-9][0-9]*:(?:TRANSACTIONAL|MARKETING):[0-9a-f]{32}') { [void]$codes.Add('CREDENTIAL_REFERENCE') }
    if (($Path -match '(?i)\.example$' -or -not $AllowSynthetic) -and $Text -match '(?i)<machineKey\b') { [void]$codes.Add('INSTALLATION_MACHINE_KEY') }
    foreach ($code in $codes) { [pscustomobject]@{Path=$Path;Code=$code} }
}

function Invoke-GuardSelfTest {
    $marker='KS-DBCFG-FIXTURE-guard-value'
    $connectionName='Pass'+'word'
    $shortName='P'+'wd'
    $jsonName='pass'+'word'
    $cases=@(
        @{Name='empty-connection';Text='<add name="EntropicConnectionString" connectionString="" />';Path='web.config.example';Source=$false;Fail=$false},
        @{Name='marked-fixture';Text=($connectionName+'='+$marker+';');Path='Tools/Test-Fixture.ps1';Source=$true;Fail=$false},
        @{Name='marked-artifact-still-secret';Text=($connectionName+'='+$marker+';');Path='release.txt';Source=$false;Fail=$true},
        @{Name='unmarked-source';Text=($connectionName+'='+('not-'+'a-fixture')+';');Path='candidate.vb';Source=$true;Fail=$true},
        @{Name='second-secret-same-line';Text=($connectionName+'='+$marker+'; '+$shortName+'='+('not-'+'a-fixture')+';');Path='candidate.vb';Source=$true;Fail=$true},
        @{Name='dynamic-expression';Text='$builder.Password = $secureValue';Path='candidate.ps1';Source=$true;Fail=$false},
        @{Name='machine-key-template';Text=('<machine'+'Key validationKey="'+$marker+'" />');Path='web.config.example';Source=$true;Fail=$true},
        @{Name='json-secret';Text=('{"'+$jsonName+'":"'+('not-'+'a-fixture')+'"}');Path='new.json';Source=$true;Fail=$true},
        @{Name='xml-secret-setting';Text=('<add key="ApiToken" value="'+('not-'+'a-fixture')+'" />');Path='new.config';Source=$true;Fail=$true},
        @{Name='xml-empty-setting';Text='<add key="ApiToken" value="" />';Path='web.config.example';Source=$false;Fail=$false},
        @{Name='quoted-password';Text=($shortName+'="'+('not-'+'a-fixture')+'";');Path='candidate.vb';Source=$true;Fail=$true},
        @{Name='quoted-dollar';Text=($shortName+'="$unmarkedLiteral";');Path='candidate.vb';Source=$true;Fail=$true},
        @{Name='json-dollar';Text=('{"'+$jsonName+'":"$unmarkedLiteral"}');Path='new.json';Source=$true;Fail=$true},
        @{Name='artifact-dollar';Text=($connectionName+'=$unmarkedLiteral;');Path='release.txt';Source=$false;Fail=$true},
        @{Name='artifact-bracket';Text=($connectionName+'=[unmarkedLiteral];');Path='release.txt';Source=$false;Fail=$true},
        @{Name='multiline-rsa';Text=("<RSA"+'KeyValue><Modulus>synthetic</Modulus>'+"`n"+'<D>synthetic</D></RSA'+'KeyValue>');Path='release.txt';Source=$false;Fail=$true},
        @{Name='yaml-dollar';Text=($jsonName+': "$unmarkedLiteral"');Path='release.yml';Source=$false;Fail=$true},
        @{Name='yaml-bracket';Text=($jsonName+': [unmarkedLiteral]');Path='release.yaml';Source=$false;Fail=$true},
        @{Name='yaml-inline-comment';Text=($jsonName+': "$unmarkedLiteral" # synthetic comment');Path='release.yaml';Source=$false;Fail=$true}
    )
    foreach($case in $cases){
        $found=@(Find-SecretViolations $case.Text $case.Path $case.Source)
        if (($found.Count -gt 0) -ne $case.Fail) { throw 'SECRETS_GUARD_SELFTEST_FAILED' }
    }
    $privateCases=@('web.config','folder/Web.config','new.pfx','App_Data/new.json','.env','.env.local','recovery.dpapi','config.bak')
    foreach($path in $privateCases) {
        if(-not (Test-PrivatePublicationPath $path)){throw 'SECRETS_GUARD_PATH_SELFTEST_FAILED'}
    }
    if(Test-PrivatePublicationPath 'web.config.example'){throw 'SECRETS_GUARD_EXAMPLE_REJECTED'}
    Write-Output ('SECRETS_GUARD_SELFTEST_PASS checks='+($cases.Count+$privateCases.Count+1))
}

function Invoke-DatabaseSecretsGuard {
    if($SelfTest){Invoke-GuardSelfTest;return}
    $repo=[IO.Path]::GetFullPath($RepositoryRoot)
    if($BaseRef -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$'){throw 'SECRETS_GUARD_BASE_INVALID'}
    $resolved=@(Invoke-GuardGit $repo @('rev-parse','--verify',($BaseRef+'^{commit}')))
    if($resolved.Count -ne 1 -or $resolved[0] -notmatch '^[0-9a-f]{40}$'){throw 'SECRETS_GUARD_BASE_INVALID'}
    $texts=@{}
    # Read only newly added lines of the current delta. Never request or print
    # operational web.config, removed lines, history, dumps, logs or old copies.
    $patch=@(Invoke-GuardGit $repo @('diff','--no-ext-diff','--no-color','--unified=0',$resolved[0],'--','.',':(exclude)web.config',':(exclude)Web.config'))
    $path=$null
    foreach($line in $patch){
        if($line.StartsWith('+++ b/')){$path=$line.Substring(6);continue}
        if($line.StartsWith('+++ ')){$path=$null;continue}
        if($null -ne $path -and $line.StartsWith('+')){
            if(-not $texts.ContainsKey($path)){$texts[$path]=New-Object Text.StringBuilder}
            [void]$texts[$path].AppendLine($line.Substring(1))
        }
    }
    if(-not [string]::IsNullOrWhiteSpace($CandidateManifestPath)){
        $parsedManifest=Get-Content -LiteralPath $CandidateManifestPath -Raw|ConvertFrom-Json
        $candidates=@($parsedManifest|ForEach-Object {$_})
        $basePaths=@(Invoke-GuardGit $repo @('ls-tree','-r','--name-only',$resolved[0],'--'))
        $baseNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach($basePath in $basePaths){[void]$baseNames.Add($basePath)}
        foreach($relative in $candidates){
            if($relative -isnot [string] -or [IO.Path]::IsPathRooted($relative)){throw 'SECRETS_GUARD_MANIFEST_INVALID'}
            if($relative -match '^(?i:web\.config)$'){continue}
            $full=[IO.Path]::GetFullPath((Join-Path $repo $relative))
            if(-not $full.StartsWith($repo.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'SECRETS_GUARD_MANIFEST_INVALID'}
            if(-not (Test-Path -LiteralPath $full -PathType Leaf)){throw 'SECRETS_GUARD_CANDIDATE_MISSING'}
            if(-not $baseNames.Contains($relative.Replace('\','/'))){$texts[$relative]=[IO.File]::ReadAllText($full)}
        }
    }
    $violations=@()
    foreach($relative in $texts.Keys){
        if(Test-PrivatePublicationPath $relative){$violations+=@([pscustomobject]@{Path=$relative;Code='PRIVATE_PUBLICATION_PATH'})}
        $allowFixture=($relative -match '(?i)\.(?:ps1|vb)$')
        $violations+=@(Find-SecretViolations ([string]$texts[$relative]) $relative $allowFixture)
    }
    if(-not [string]::IsNullOrWhiteSpace($ArtifactRoot)){
        $artifact=[IO.Path]::GetFullPath($ArtifactRoot).TrimEnd('\')
        if(-not (Test-Path -LiteralPath $artifact -PathType Container)){throw 'SECRETS_GUARD_ARTIFACT_MISSING'}
        $items=@(Get-ChildItem -LiteralPath $artifact -Recurse -Force)
        foreach($item in $items){
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'SECRETS_GUARD_ARTIFACT_REPARSE'}
            if($item.PSIsContainer){continue}
            $relative=$item.FullName.Substring($artifact.Length+1)
            if(Test-PrivatePublicationPath $relative){$violations+=@([pscustomobject]@{Path=$relative;Code='PRIVATE_PUBLICATION_PATH'})}
            if($item.Extension -in @('','.ps1','.vb','.aspx','.ascx','.master','.ashx','.asax','.xml','.json','.html','.js','.css','.md','.txt','.config','.example','.env','.ini','.yml','.yaml','.toml','.pem')){
                $violations+=@(Find-SecretViolations ([IO.File]::ReadAllText($item.FullName)) $relative $false)
            }
        }
    }
    if($violations.Count -gt 0){
        foreach($violation in @($violations|Sort-Object Path,Code -Unique)){Write-Output ('SECRETS_GUARD_REJECT '+$violation.Code+' '+$violation.Path)}
        throw 'SECRETS_GUARD_REJECTED'
    }
    Write-Output ('SECRETS_GUARD_PASS changed_files='+$texts.Count)
}

if($MyInvocation.InvocationName -ne '.'){
    try {Invoke-DatabaseSecretsGuard} catch {
        Write-Verbose ('SECRETS_GUARD_EXCEPTION_TYPE='+$_.Exception.GetType().FullName+' LOCATION='+$_.InvocationInfo.ScriptLineNumber)
        Write-Verbose ('SECRETS_GUARD_BASE_EXCEPTION='+$_.Exception.GetBaseException().GetType().FullName+' HRESULT='+$_.Exception.GetBaseException().HResult)
        if($_.Exception.GetBaseException() -is [ComponentModel.Win32Exception]){Write-Verbose ('SECRETS_GUARD_NATIVE_CODE='+$_.Exception.GetBaseException().NativeErrorCode)}
        $code=[string]$_.Exception.Message
        if($code -notmatch '^SECRETS_GUARD_[A-Z0-9_]+$'){$code='SECRETS_GUARD_FAILED'}
        Write-Output $code
        exit 1
    }
}
