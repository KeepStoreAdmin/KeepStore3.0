[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$BaseRef = 'origin/frontend-rebuild',
    [string]$CandidateManifestPath,
    [string]$ArtifactRoot,
    [switch]$SelfTest,
    [switch]$GitCandidateSelfTest,
    [string]$TestRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }

function Test-SyntheticValue([string]$Value) {
    return $Value -cmatch '^(?:KS-DBCFG-(?:FIXTURE|TEST)-[A-Za-z0-9_.:-]+|SYNTHETIC[_-][A-Za-z0-9_.:-]+|FAKE[_-][A-Za-z0-9_.:-]+|fixture-[A-Za-z0-9_.:-]+)$'
}

function Invoke-GuardGit([string]$Root, [string[]]$Arguments, [switch]$RawOutput) {
    $process=$null
    try {
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=@(Get-Command git.exe -CommandType Application -ErrorAction Stop)[0].Source
        $info.WorkingDirectory=$Root
        $info.UseShellExecute=$false
        $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true
        $info.RedirectStandardError=$true
        $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false, $true)
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
        if($RawOutput){return $stdout.Result}
        return @($stdout.Result -split '\r?\n'|Where-Object {$_ -ne ''})
    } finally {if($null -ne $process){$process.Dispose()}}
}

function Get-GuardPrivateIntroductions([string]$Root, [string]$Reference) {
    # --cached is independent of unstaged edits/deletions. --no-renames makes
    # copy/rename destinations additions, without examining blob similarity.
    $raw=[string](Invoke-GuardGit $Root @('diff','--cached','--name-status','-z','--no-renames',$Reference,'--') -RawOutput)
    if($raw.Length -eq 0){return}
    $fields=$raw.Split([char]0)
    if($fields[$fields.Length-1] -cne '' -or $fields.Length % 2 -ne 1){throw 'SECRETS_GUARD_METADATA_INVALID'}
    for($index=0;$index -lt $fields.Length-1;$index+=2){
        $status=$fields[$index]
        $path=$fields[$index+1]
        if($status -cnotmatch '^[AMDT]$' -or [string]::IsNullOrEmpty($path)){throw 'SECRETS_GUARD_METADATA_INVALID'}
        if($status -ceq 'A' -and (Test-PrivatePublicationPath $path)){$path}
    }
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

function Invoke-GuardGitCandidateSelfTest {
    if([string]::IsNullOrWhiteSpace($TestRoot) -or -not [IO.Path]::IsPathRooted($TestRoot) -or
       -not (Test-Path -LiteralPath $TestRoot -PathType Container)){throw 'SECRETS_GUARD_TEST_ROOT_REQUIRED'}
    if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'SECRETS_GUARD_TEST_EXECUTOR_INVALID'}
    $root=[IO.Path]::GetFullPath($TestRoot).TrimEnd('\')
    $work=Join-Path $root ('guard-git-'+[Guid]::NewGuid().ToString('N'))
    $journal=Join-Path $root ('guard-git-resources-'+[Guid]::NewGuid().ToString('N')+'.json')
    @{Status='PLANNED';Directory=$work}|ConvertTo-Json|Set-Content -LiteralPath $journal -Encoding UTF8
    $results=New-Object 'System.Collections.Generic.List[object]'
    $executor=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $guardPath=$PSCommandPath
    function New-GuardFixture([string]$Name,[bool]$PrivateBaseline=$false) {
        $directory=Join-Path $work $Name
        New-Item -ItemType Directory -Path $directory|Out-Null
        $null=Invoke-GuardGit $directory @('init','--quiet')
        [IO.File]::WriteAllText((Join-Path $directory 'seed.txt'),'KS-DBCFG-FIXTURE-seed')
        $null=Invoke-GuardGit $directory @('add','--','seed.txt')
        if($PrivateBaseline){
            [IO.File]::WriteAllText((Join-Path $directory 'web.config'),'KS-DBCFG-FIXTURE-private')
            $null=Invoke-GuardGit $directory @('add','--','web.config')
        }
        $null=Invoke-GuardGit $directory @('-c','user.name=KS-DBCFG-FIXTURE','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Synthetic baseline')
        $base=@(Invoke-GuardGit $directory @('rev-parse','HEAD'))[0]
        return [pscustomobject]@{Directory=$directory;Base=$base}
    }
    function Test-GuardEntrypoint($Fixture,[string]$Name,[bool]$Reject,[string]$ExpectedCode,[string[]]$Extra=@()) {
        $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$guardPath,'-RepositoryRoot',$Fixture.Directory,'-BaseRef',$Fixture.Base)+$Extra
        $output=@(& $executor @arguments)
        $exit=$LASTEXITCODE
        $text=$output -join ' '
        $pass=if($Reject){$exit -eq 1 -and $text -match $ExpectedCode -and $text -notmatch 'SECRETS_GUARD_PASS'}else{$exit -eq 0 -and $text -match 'SECRETS_GUARD_PASS'}
        $results.Add([pscustomobject]@{Name=$Name;Pass=[bool]$pass;Exit=$exit;ExpectedRejection=$Reject;Output=$output})
    }
    try {
        New-Item -ItemType Directory -Path $work|Out-Null
        foreach($name in @('staged','manifest','manifest-omits-private','deleted-working','modified-working','empty-casing')){
            $fixture=New-GuardFixture $name
            $fileName=if($name -eq 'empty-casing'){'WEB.CONFIG'}else{'web.config'}
            $private=Join-Path $fixture.Directory $fileName
            [IO.File]::WriteAllText($private,'')
            if($name -eq 'staged'){
                [IO.File]::WriteAllText((Join-Path $fixture.Directory '.gitignore'),'/web.config'+[Environment]::NewLine)
                $null=Invoke-GuardGit $fixture.Directory @('add','--force','--',$fileName)
            }else{$null=Invoke-GuardGit $fixture.Directory @('add','--',$fileName)}
            $extra=@()
            if($name.StartsWith('manifest')){
                $manifestPath=Join-Path $work 'explicit-manifest.json'
                $manifestText=if($name -eq 'manifest'){'["web.config"]'}else{'["seed.txt"]'}
                [IO.File]::WriteAllText($manifestPath,$manifestText)
                $extra=@('-CandidateManifestPath',$manifestPath)
            }
            if($name -eq 'deleted-working'){Remove-Item -LiteralPath $private}
            if($name -eq 'modified-working'){[IO.File]::WriteAllText($private,'KS-DBCFG-FIXTURE-working')}
            Test-GuardEntrypoint $fixture $name $true 'PRIVATE_PUBLICATION_PATH' $extra
        }
        foreach($destination in @('web.config','folder with spaces/Web.Config')){
            $fixture=New-GuardFixture ('rename-'+$results.Count)
            $parent=Split-Path -Parent (Join-Path $fixture.Directory $destination)
            if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent|Out-Null}
            $null=Invoke-GuardGit $fixture.Directory @('mv','--','seed.txt',$destination)
            Test-GuardEntrypoint $fixture ('rename-'+$destination) $true 'PRIVATE_PUBLICATION_PATH'
        }
        $fixture=New-GuardFixture 'copy'
        $copyPath=('folder with spaces caf'+[char]0x00e8+'/Web.Release.config')
        New-Item -ItemType Directory -Path (Split-Path -Parent (Join-Path $fixture.Directory $copyPath))|Out-Null
        Copy-Item -LiteralPath (Join-Path $fixture.Directory 'seed.txt') -Destination (Join-Path $fixture.Directory $copyPath)
        $null=Invoke-GuardGit $fixture.Directory @('add','--',$copyPath)
        Test-GuardEntrypoint $fixture 'copy-unicode-spaces' $true 'PRIVATE_PUBLICATION_PATH'
        $fixture=New-GuardFixture 'empty-private'
        [IO.File]::WriteAllText((Join-Path $fixture.Directory '.env'),'')
        $null=Invoke-GuardGit $fixture.Directory @('add','--','.env')
        Test-GuardEntrypoint $fixture 'empty-private' $true 'PRIVATE_PUBLICATION_PATH'
        $fixture=New-GuardFixture 'untracking' $true
        $private=Join-Path $fixture.Directory 'web.config'
        $before=(Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash
        $null=Invoke-GuardGit $fixture.Directory @('rm','--cached','--','web.config')
        $locked=[IO.File]::Open($private,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {Test-GuardEntrypoint $fixture 'untracking-locked-private-not-read' $false ''}finally{$locked.Dispose()}
        if((Get-FileHash -LiteralPath $private -Algorithm SHA256).Hash -cne $before){throw 'SECRETS_GUARD_FIXTURE_PRESERVATION_FAILED'}
        $fixture=New-GuardFixture 'ignored'
        [IO.File]::WriteAllText((Join-Path $fixture.Directory '.gitignore'),'/web.config'+[Environment]::NewLine)
        $null=Invoke-GuardGit $fixture.Directory @('add','--','.gitignore')
        $private=Join-Path $fixture.Directory 'web.config'
        [IO.File]::WriteAllText($private,'KS-DBCFG-FIXTURE-local')
        $manifestPath=Join-Path $work 'ignored-manifest.json'
        [IO.File]::WriteAllText($manifestPath,'["web.config"]')
        $locked=[IO.File]::Open($private,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {
            Test-GuardEntrypoint $fixture 'ignored-locked-no-manifest' $false ''
            Test-GuardEntrypoint $fixture 'ignored-locked-with-manifest' $false '' @('-CandidateManifestPath',$manifestPath)
        }finally{$locked.Dispose()}
        $fixture=New-GuardFixture 'template'
        [IO.File]::WriteAllText((Join-Path $fixture.Directory 'web.config.example'),'<configuration/>')
        $null=Invoke-GuardGit $fixture.Directory @('add','--','web.config.example')
        Test-GuardEntrypoint $fixture 'template' $false ''
        $fixture=New-GuardFixture 'invalid-base'
        $fixture.Base='missing-fixture-ref'
        Test-GuardEntrypoint $fixture 'invalid-base' $true 'SECRETS_GUARD_GIT_FAILED'
        $fixture=New-GuardFixture 'git-error'
        [IO.File]::WriteAllBytes((Join-Path $fixture.Directory '.git\index'),[byte[]]@(1,2,3))
        Test-GuardEntrypoint $fixture 'metadata-read-error' $true 'SECRETS_GUARD_GIT_FAILED'
        $fixture=New-GuardFixture 'not-a-repo'
        $fixture.Directory=Join-Path $work 'not-a-git-repository'
        New-Item -ItemType Directory -Path $fixture.Directory|Out-Null
        Test-GuardEntrypoint $fixture 'git-not-repository' $true 'SECRETS_GUARD_GIT_FAILED'
        $fixture=New-GuardFixture 'reintroduced-identical' $true
        $null=Invoke-GuardGit $fixture.Directory @('rm','--cached','--','web.config')
        $null=Invoke-GuardGit $fixture.Directory @('-c','user.name=KS-DBCFG-FIXTURE','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Synthetic untracking')
        $null=Invoke-GuardGit $fixture.Directory @('add','--','web.config')
        Test-GuardEntrypoint $fixture 'reintroduced-identical-to-base' $true 'PRIVATE_PUBLICATION_PATH'
        $fixture=New-GuardFixture 'committed-addition'
        [IO.File]::WriteAllText((Join-Path $fixture.Directory 'web.config'),'')
        $null=Invoke-GuardGit $fixture.Directory @('add','--','web.config')
        $null=Invoke-GuardGit $fixture.Directory @('-c','user.name=KS-DBCFG-FIXTURE','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Synthetic addition')
        Test-GuardEntrypoint $fixture 'already-committed-addition' $true 'PRIVATE_PUBLICATION_PATH'
        $fixture=New-GuardFixture 'ordinary-source'
        [IO.File]::WriteAllText((Join-Path $fixture.Directory 'seed.txt'),'KS-DBCFG-FIXTURE-update')
        $null=Invoke-GuardGit $fixture.Directory @('add','--','seed.txt')
        Test-GuardEntrypoint $fixture 'ordinary-modification' $false ''

        # Reuse actual ArtifactRoot entrypoint cases, not just the path predicate.
        $fixture=New-GuardFixture 'artifact-controls'
        $artifact=Join-Path $work 'artifact'
        New-Item -ItemType Directory -Path $artifact|Out-Null
        $passwordName='pass'+'word'
        $artifactCases=@(@{Name='safe';File='readme.txt';Text='public synthetic material';Reject=$false})
        foreach($extension in @('env','ini','toml','yml','yaml','','json','txt')){
            foreach($value in @('$KS-DBCFG-FIXTURE-literal','[KS-DBCFG-FIXTURE-literal]')){
                $text=if($extension -in @('yml','yaml')){$passwordName+': "'+$value+'"'}elseif($extension -eq 'json'){'{"'+$passwordName+'":"'+$value+'"}'}else{$passwordName+'="'+$value+'";'}
                $artifactCases+=@{Name=($extension+'-'+$artifactCases.Count);File=('release'+$(if($extension){'.'+$extension}else{''}));Text=$text;Reject=$true}
            }
        }
        $artifactCases+=@(
            @{Name='private-config-empty';File='WEB.CONFIG';Text='';Reject=$true},
            @{Name='private-recovery-empty';File='recovery.dpapi';Text='';Reject=$true},
            @{Name='rsa-multiline';File='rsa.xml';Text=('<RSA'+'KeyValue><Modulus>synthetic</Modulus>'+[Environment]::NewLine+'<D>synthetic</D></RSA'+'KeyValue>');Reject=$true},
            @{Name='pem';File='key.pem';Text=('-----BEGIN '+'PRIVATE KEY-----');Reject=$true},
            @{Name='yaml-comment';File='release.yml';Text=($passwordName+': "$KS-DBCFG-FIXTURE-literal" # comment');Reject=$true}
        )
        foreach($case in $artifactCases){
            $file=Join-Path $artifact $case.File
            [IO.File]::WriteAllText($file,$case.Text)
            Test-GuardEntrypoint $fixture ('artifact-'+$case.Name) $case.Reject 'SECRETS_GUARD_REJECTED' @('-ArtifactRoot',$artifact)
            Remove-Item -LiteralPath $file
        }
        $gitCount=$results.Count-$artifactCases.Count
        $failures=@($results|Where-Object {-not $_.Pass})
        @{Status=$(if($failures.Count){'FAIL'}else{'PASS'});GitCases=$gitCount;ArtifactCases=$artifactCases.Count;Results=$results.ToArray()}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $root 'guard-git-candidate-results.json') -Encoding UTF8
        if($failures.Count){throw 'SECRETS_GUARD_CANDIDATE_SELFTEST_FAILED'}
        Write-Output ('SECRETS_GUARD_GIT_CANDIDATE_SELFTEST_PASS cases='+$gitCount+' artifacts='+$artifactCases.Count)
    }finally{
        $full=[IO.Path]::GetFullPath($work)
        if(-not $full.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notmatch '^guard-git-[0-9a-f]{32}$'){throw 'SECRETS_GUARD_TEST_CLEANUP_INVALID'}
        if(Test-Path -LiteralPath $full){Remove-Item -LiteralPath $full -Recurse -Force}
        @{Status='CLEANED';Directory=$work;DirectoryExists=(Test-Path -LiteralPath $work)}|ConvertTo-Json|Set-Content -LiteralPath $journal -Encoding UTF8
    }
}

function Invoke-DatabaseSecretsGuard {
    if($SelfTest){Invoke-GuardSelfTest;return}
    if($GitCandidateSelfTest){Invoke-GuardGitCandidateSelfTest;return}
    $repo=[IO.Path]::GetFullPath($RepositoryRoot)
    if($BaseRef -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$'){throw 'SECRETS_GUARD_BASE_INVALID'}
    $resolved=@(Invoke-GuardGit $repo @('rev-parse','--verify',($BaseRef+'^{commit}')))
    if($resolved.Count -ne 1 -or $resolved[0] -notmatch '^[0-9a-f]{40}$'){throw 'SECRETS_GUARD_BASE_INVALID'}
    $head=@(Invoke-GuardGit $repo @('rev-parse','--verify','HEAD^{commit}'))
    if($head.Count -ne 1 -or $head[0] -notmatch '^[0-9a-f]{40}$'){throw 'SECRETS_GUARD_METADATA_INVALID'}
    # Inspect both cumulative and staged candidate metadata BEFORE any content
    # or manifest processing. A manifest can never exempt an indexed path.
    $privatePaths=@(foreach($reference in @($resolved[0],$head[0])|Select-Object -Unique){Get-GuardPrivateIntroductions $repo $reference})
    if($privatePaths.Count -gt 0){
        foreach($privatePath in @($privatePaths|Sort-Object -Unique)){Write-Output ('SECRETS_GUARD_REJECT PRIVATE_PUBLICATION_PATH '+$privatePath)}
        throw 'SECRETS_GUARD_REJECTED'
    }
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
        $rawBasePaths=[string](Invoke-GuardGit $repo @('ls-tree','-r','--name-only','-z',$resolved[0],'--') -RawOutput)
        if($rawBasePaths.Length -gt 0 -and -not $rawBasePaths.EndsWith([string][char]0)){throw 'SECRETS_GUARD_METADATA_INVALID'}
        $basePaths=@($rawBasePaths.Split([char]0)|Where-Object {$_ -cne ''})
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
