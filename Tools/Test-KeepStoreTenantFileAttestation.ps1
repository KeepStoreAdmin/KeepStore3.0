[CmdletBinding()]
param(
    [string]$RepositoryRoot=(Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
$fixture=$null;$locked=$null;$privateLock=$null;$junction=$null;$cleanup=$false
$policyBefore=@(Get-ExecutionPolicy -List|Where-Object{$_.Scope -ne 'Process'}|ForEach-Object{$_.Scope.ToString()+':'+$_.ExecutionPolicy})
$verifier=Join-Path $RepositoryRoot 'Tools\New-KeepStoreTenantFileAttestation.ps1'
$generator=Join-Path $RepositoryRoot 'Tools\New-KeepStoreTenantReleasePlan.ps1'
$powershell=Join-Path $PSHOME 'powershell.exe'
function Check([string]$Name,[bool]$Passed){$checks.Add([pscustomobject]@{Name=$Name;Passed=$Passed});if(-not $Passed){throw ('CHECK_FAILED: '+$Name)}}
function Write-Fixture([string]$Root,[string]$Path,[byte[]]$Bytes){$p=Join-Path $Root $Path;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p));[IO.File]::WriteAllBytes($p,$Bytes)}
function Text-Bytes([string]$Text){return ,$utf8.GetBytes($Text)}
function Read-Json([string]$Path){return [IO.File]::ReadAllText($Path,$utf8)|ConvertFrom-Json}
function Fixture-Git([string[]]$Arguments){$r=@(& git -C $script:repo -c core.hooksPath=$script:emptyHooks -c commit.gpgsign=false -c protocol.allow=never @Arguments 2>&1);if($LASTEXITCODE -ne 0){throw 'FIXTURE_GIT_FAILED'};return ($r -join "`n").Trim()}
function Run-Script([string]$Script,[string[]]$Arguments){
    $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$powershell;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $argsAll=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$Script)+$Arguments
    $info.Arguments=(@($argsAll|ForEach-Object{'"'+([regex]::Replace(([regex]::Replace([string]$_,'(\\*)"','$1$1\"')),'(\\+)$','$1$1'))+'"'}) -join ' ')
    $p=New-Object Diagnostics.Process;$p.StartInfo=$info
    try{[void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(60000)){$p.Kill();throw 'FIXTURE_PROCESS_TIMEOUT'};return [pscustomobject]@{Code=$p.ExitCode;Out=$o.GetAwaiter().GetResult();Error=$e.GetAwaiter().GetResult()}}finally{$p.Dispose()}
}
function Run-Attestation([string]$Plan,[string]$Root,[string]$Output,[string]$Label='fixture-a'){
    return Run-Script $verifier @('-PlanPath',$Plan,'-InspectionRoot',$Root,'-OutputDirectory',$Output,'-TargetLabel',$Label)
}
function New-BadPlan([string]$Name,[scriptblock]$Mutation){$p=$script:planText|ConvertFrom-Json;& $Mutation $p;$path=Join-Path $fixture ($Name+'.json');[IO.File]::WriteAllText($path,($p|ConvertTo-Json -Depth 16),$utf8);return $path}
function Reject-Plan([string]$Name,[scriptblock]$Mutation,[string]$Expected='^KS_ATTEST_[A-Z0-9_]+\s*$'){
    $path=New-BadPlan $Name $Mutation;$output=Join-Path $EvidenceDirectory ('reject-'+$Name);$r=Run-Attestation $path $script:targetA $output
    Check $Name ($r.Code -eq 1 -and $r.Error -match $Expected -and -not(Test-Path -LiteralPath $output))
}
function Snapshot([string]$Root){
    $stable=New-Object 'Collections.Generic.List[object]';$access=New-Object 'Collections.Generic.List[object]'
    foreach($f in @(Get-Item -LiteralPath $Root)+@(Get-ChildItem -LiteralPath $Root -Recurse -Force|Sort-Object FullName)){
        $h=if($f.PSIsContainer){$null}else{(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash};$f.Refresh()
        $relative=$f.FullName.Substring($Root.Length)
        $stable.Add([pscustomobject][ordered]@{Path=$relative;SHA256=$h;Length=$(if($f.PSIsContainer){$null}else{$f.Length});Attributes=$f.Attributes.ToString();CreationTicks=$f.CreationTimeUtc.Ticks;WriteTicks=$f.LastWriteTimeUtc.Ticks;Acl=(Get-Acl -LiteralPath $f.FullName).Sddl})
        $access.Add([pscustomobject]@{Path=$relative;AccessTicks=$f.LastAccessTimeUtc.Ticks})
    }
    return [pscustomobject]@{Stable=@($stable.ToArray());InformationalLastAccess=@($access.ToArray())}
}
function Same-Stable($Before,$After){return ($Before.Stable|ConvertTo-Json -Depth 8 -Compress) -ceq ($After.Stable|ConvertTo-Json -Depth 8 -Compress)}
function Control-Metadata([string]$Path){$f=Get-Item -LiteralPath $Path;return [pscustomobject][ordered]@{Length=$f.Length;Attributes=$f.Attributes.ToString();CreationTicks=$f.CreationTimeUtc.Ticks;WriteTicks=$f.LastWriteTimeUtc.Ticks;AccessTicks=$f.LastAccessTimeUtc.Ticks;Acl=(Get-Acl -LiteralPath $Path).Sddl}}
try{
    Check 'Windows PowerShell 5.1 Desktop' ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1)
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\');$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
    if(-not $EvidenceDirectory.StartsWith($temp+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory) -or -not(Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($EvidenceDirectory)))){throw 'NEW_TEMP_EVIDENCE_REQUIRED'}
    [void][IO.Directory]::CreateDirectory($EvidenceDirectory)
    $fixture=Join-Path $temp ('KeepStoreAttestation-fixture-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($fixture)
    $script:repo=Join-Path $fixture 'git';$script:emptyHooks=Join-Path $fixture 'empty-hooks';[void][IO.Directory]::CreateDirectory($script:repo);[void][IO.Directory]::CreateDirectory($script:emptyHooks)
    [void](Fixture-Git @('init','--quiet'));[void](Fixture-Git @('config','user.name','Synthetic Fixture'));[void](Fixture-Git @('config','user.email','fixture@example.invalid'));[void](Fixture-Git @('config','core.autocrlf','false'))
    $names=@('Default.aspx','Baseline.aspx','Missing.aspx','Unknown.aspx','Deleted.aspx','Gone.aspx','Old.aspx','Locked.aspx','Directory.aspx','Hardlink.aspx')
    foreach($name in $names){Write-Fixture $script:repo $name (Text-Bytes ('before-'+$name))}
    $unicode='Public/assets/images/caff'+[char]0xe8+' uno.png';Write-Fixture $script:repo $unicode ([byte[]]@(0,255,128,10,13,3));Write-Fixture $script:repo 'Bin/fixture.dll' ([byte[]]@(0,17,255,90))
    Write-Fixture $script:repo 'web.config' (Text-Bytes 'SYNTHETIC_PRIVATE_MARKER_NOT_A_CREDENTIAL');Write-Fixture $script:repo 'docs/fixture.md' (Text-Bytes 'excluded')
    [void](Fixture-Git @('add','--','.'));[void](Fixture-Git @('commit','--quiet','-m','synthetic baseline'));$from=Fixture-Git @('rev-parse','HEAD')
    foreach($name in $names|Where-Object{$_ -notin @('Old.aspx','Deleted.aspx','Gone.aspx')}){Write-Fixture $script:repo $name (Text-Bytes ('after-'+$name))}
    [void](Fixture-Git @('mv','--','Old.aspx','New.aspx'));[void](Fixture-Git @('rm','--','Deleted.aspx','Gone.aspx'))
    foreach($name in @('Added.aspx','Absent.aspx','Collision.aspx')){Write-Fixture $script:repo $name (Text-Bytes ('added-'+$name))}
    Write-Fixture $script:repo $unicode ([byte[]]@(0,255,128,10,13,4));Write-Fixture $script:repo 'Bin/fixture.dll' ([byte[]]@(0,17,255,91));Write-Fixture $script:repo 'web.config' (Text-Bytes 'SYNTHETIC_PRIVATE_MARKER_CHANGED');Write-Fixture $script:repo 'docs/fixture.md' (Text-Bytes 'excluded changed')
    [void](Fixture-Git @('add','--','.'));[void](Fixture-Git @('commit','--quiet','-m','synthetic candidate'));$to=Fixture-Git @('rev-parse','HEAD')
    Check 'synthetic Git has no remotes' ([string]::IsNullOrEmpty((Fixture-Git @('remote'))))
    $planOutput=Join-Path $EvidenceDirectory 'synthetic-plan';$r=Run-Script $generator @('-RepoRoot',$script:repo,'-FromCommit',$from,'-ToCommit',$to,'-OutputDirectory',$planOutput,'-TargetLabel','synthetic-plan')
    Check 'real unchanged generator creates v1 synthetic plan' ($r.Code -eq 0)
    $planPath=Join-Path $planOutput 'plan.json';$script:planText=[IO.File]::ReadAllText($planPath,$utf8);$p=$script:planText|ConvertFrom-Json
    Check 'plan includes inert excluded configuration metadata' (@($p.Changes|Where-Object{$_.Path -eq 'web.config' -and $_.Disposition -eq 'EXCLUDED_FROM_TRANSFER' -and $null -eq $_.AfterSHA256}).Count -eq 1)
    $script:targetA=Join-Path $fixture 'app-a';$targetB=Join-Path $fixture 'app-b';[void][IO.Directory]::CreateDirectory($script:targetA);[void][IO.Directory]::CreateDirectory($targetB)
    foreach($target in @($script:targetA,$targetB)){
        Write-Fixture $target 'web.config' (Text-Bytes 'SYNTHETIC_PRIVATE_TARGET_NOT_READ');Write-Fixture $target 'unlisted.aspx' (Text-Bytes 'UNLISTED_CONTENT_NOT_READ');Write-Fixture $target 'Bin/fixture.dll' ([byte[]]@(0,17,255,91))
        Write-Fixture $target $unicode ([byte[]]@(0,255,128,10,13,4));Write-Fixture $target 'Added.aspx' (Text-Bytes 'added-Added.aspx');Write-Fixture $target 'Collision.aspx' (Text-Bytes 'unrecognized-existing-addition')
        Write-Fixture $target 'Unknown.aspx' (Text-Bytes 'unrecognized');Write-Fixture $target 'Deleted.aspx' (Text-Bytes 'before-Deleted.aspx');Write-Fixture $target 'Old.aspx' (Text-Bytes 'before-Old.aspx');Write-Fixture $target 'New.aspx' (Text-Bytes 'before-Old.aspx')
        Write-Fixture $target 'Locked.aspx' (Text-Bytes 'after-Locked.aspx');Write-Fixture $target 'Hardlink.aspx' (Text-Bytes 'after-Hardlink.aspx');[void][IO.Directory]::CreateDirectory((Join-Path $target 'Directory.aspx'))
        Write-Fixture $target 'Default.aspx' (Text-Bytes 'after-Default.aspx')
    }
    Write-Fixture $script:targetA 'Baseline.aspx' (Text-Bytes 'before-Baseline.aspx');Write-Fixture $targetB 'Baseline.aspx' (Text-Bytes 'after-Baseline.aspx')
    $beforeA=Snapshot $script:targetA;$beforeB=Snapshot $targetB
    # No hash/content read of the unlisted control during the observation window.
    $controlBeforeA=Control-Metadata (Join-Path $script:targetA 'unlisted.aspx');$controlBeforeB=Control-Metadata (Join-Path $targetB 'unlisted.aspx')
    $locked=[IO.File]::Open((Join-Path $script:targetA 'Locked.aspx'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    $privateLock=[IO.File]::Open((Join-Path $script:targetA 'web.config'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    $outputA=Join-Path $EvidenceDirectory 'app-a';$r=Run-Attestation $planPath $script:targetA $outputA
    if($r.Code -ne 0){throw ('ATTESTATION_A_FAILED: '+$r.Error)}
    $a=Read-Json (Join-Path $outputA 'attestation.json')
    function Observed($Report,[string]$Path){return @($Report.Observations|Where-Object{$_.Path -ceq $Path})[0]}
    Check 'candidate exact bytes' ((Observed $a 'Default.aspx').Status -eq 'CANDIDATE_MATCH')
    Check 'baseline exact bytes' ((Observed $a 'Baseline.aspx').Status -eq 'BASELINE_MATCH')
    Check 'missing file' ((Observed $a 'Missing.aspx').Status -eq 'MISSING')
    Check 'different unknown bytes' ((Observed $a 'Unknown.aspx').Status -eq 'DIFFERENT_UNKNOWN')
    Check 'added file already candidate' ((Observed $a 'Added.aspx').Condition -eq 'ADDITION_ALREADY_PRESENT_CANDIDATE')
    Check 'added file genuinely absent' ((Observed $a 'Absent.aspx').Condition -eq 'ADDITION_ABSENT')
    Check 'added preexisting collision distinct' ((Observed $a 'Collision.aspx').Condition -eq 'ADDITION_PREEXISTING_COLLISION')
    Check 'deleted baseline still present' ((Observed $a 'Deleted.aspx').Condition -eq 'DELETION_BASELINE_STILL_PRESENT')
    Check 'deleted already absent' ((Observed $a 'Gone.aspx').Condition -eq 'DELETION_ALREADY_ABSENT')
    Check 'rename origin observed independently' ((Observed $a 'Old.aspx').Role -eq 'ORIGIN' -and (Observed $a 'Old.aspx').Status -eq 'BASELINE_MATCH')
    Check 'rename destination observed independently' ((Observed $a 'New.aspx').Role -eq 'DESTINATION' -and (Observed $a 'New.aspx').Status -eq 'CANDIDATE_MATCH')
    Check 'spaces and Unicode' ((Observed $a $unicode).Status -eq 'CANDIDATE_MATCH')
    Check 'binary bytes without text conversion' ((Observed $a 'Bin/fixture.dll').Status -eq 'CANDIDATE_MATCH')
    Check 'unreadable sharing violation has no hash' ((Observed $a 'Locked.aspx').Status -eq 'UNREADABLE' -and $null -eq (Observed $a 'Locked.aspx').ObservedSHA256)
    Check 'directory cannot masquerade as file' ((Observed $a 'Directory.aspx').Status -eq 'BLOCKED_UNSAFE_PATH')
    Check 'no inspection of excluded or unlisted files' (@($a.Observations|Where-Object{$_.Path -in @('web.config','unlisted.aspx')}).Count -eq 0)
    Check 'read-only outputs exactly two files' ((@(Get-ChildItem -LiteralPath $outputA -File).Name|Sort-Object) -join ',' -eq 'attestation.json,attestation.md')
    Check 'target remains incomplete without commit inference' ($a.OverallStatus -eq 'TARGET_ATTESTATION_INCOMPLETE' -and $null -eq $a.Target.InstalledCommit -and $a.PublicationAuthorized -ceq $false)
    $repeat=Join-Path $EvidenceDirectory 'app-a-repeat';$r=Run-Attestation $planPath $script:targetA $repeat
    Check 'second observation succeeds with locks unchanged' ($r.Code -eq 0)
    foreach($name in @('attestation.json','attestation.md')){Check ('deterministic '+$name) ((Get-FileHash -LiteralPath (Join-Path $outputA $name)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $repeat $name)).Hash)}
    $locked.Dispose();$locked=$null;$privateLock.Dispose();$privateLock=$null
    $outputB=Join-Path $EvidenceDirectory 'app-b';$r=Run-Attestation $planPath $targetB $outputB 'fixture-b';Check 'independent application B observation' ($r.Code -eq 0)
    $b=Read-Json (Join-Path $outputB 'attestation.json')
    Check 'A and B do not inherit each other observation' ((Observed $a 'Baseline.aspx').Status -eq 'BASELINE_MATCH' -and (Observed $b 'Baseline.aspx').Status -eq 'CANDIDATE_MATCH' -and $a.Target.Id -ne $b.Target.Id)
    $controlAfterA=Control-Metadata (Join-Path $script:targetA 'unlisted.aspx');$controlAfterB=Control-Metadata (Join-Path $targetB 'unlisted.aspx')
    Check 'unread control A metadata including LastAccess unchanged' (($controlBeforeA|ConvertTo-Json -Compress) -ceq ($controlAfterA|ConvertTo-Json -Compress))
    Check 'unread control B metadata including LastAccess unchanged' (($controlBeforeB|ConvertTo-Json -Compress) -ceq ($controlAfterB|ConvertTo-Json -Compress))
    $afterA=Snapshot $script:targetA;$afterB=Snapshot $targetB
    Check 'test20 target A content size creation write attributes ACL preserved' (Same-Stable $beforeA $afterA)
    Check 'test20 target B content size creation write attributes ACL preserved' (Same-Stable $beforeB $afterB)
    $accessChanges=0;foreach($pair in @(@($beforeA,$afterA),@($beforeB,$afterB))){for($i=0;$i -lt $pair[0].InformationalLastAccess.Count;$i++){if($pair[0].InformationalLastAccess[$i].AccessTicks -ne $pair[1].InformationalLastAccess[$i].AccessTicks){$accessChanges++}}}
    foreach($field in @('SHA256','Length','CreationTicks','WriteTicks','Attributes','Acl','Path')){
        $changed=($beforeA|ConvertTo-Json -Depth 8)|ConvertFrom-Json;$row=@($changed.Stable|Where-Object{$null -ne $_.SHA256})[0]
        $row.$field=if($field -in @('Length','CreationTicks','WriteTicks')){[long]$row.$field+1}else{[string]$row.$field+'-different'}
        Check ('test20 rejects different '+$field) (-not(Same-Stable $beforeA $changed))
    }
    $changed=($beforeA|ConvertTo-Json -Depth 8)|ConvertFrom-Json;$changed.InformationalLastAccess[0].AccessTicks++
    Check 'test20 only automatic LastAccess is informational' (Same-Stable $beforeA $changed)
    $reportText=[IO.File]::ReadAllText((Join-Path $outputA 'attestation.json'))+[IO.File]::ReadAllText((Join-Path $outputA 'attestation.md'))
    Check 'no private physical root or content in reports' (-not $reportText.Contains($fixture) -and -not $reportText.Contains($env:USERNAME) -and $reportText -notmatch 'SYNTHETIC_PRIVATE|UNLISTED_CONTENT')
    $r=Run-Attestation $planPath $script:targetA $outputA;Check 'existing output rejected' ($r.Code -eq 1 -and $r.Error -match '^KS_ATTEST_OUTPUT_EXISTS')
    Reject-Plan 'unknown schema' {param($x)$x.Schema='Unknown.v1'}
    Reject-Plan 'wrong mode' {param($x)$x.Mode='APPLY'}
    Reject-Plan 'publication authorization must be boolean false' {param($x)$x.PublicationAuthorized='false'}
    Reject-Plan 'missing commit SHA' {param($x)$x.Comparison.FromCommit=$null}
    Reject-Plan 'invalid commit SHA' {param($x)$x.Comparison.ToCommit='HEAD'}
    Reject-Plan 'summary cannot omit changes' {param($x)$x.Summary.GitChanges=0}
    Reject-Plan 'runtime list cannot add private path' {param($x)$x.RuntimePaths+=@('web.config')}
    Reject-Plan 'missing required runtime hash' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).AfterSHA256=$null}
    Reject-Plan 'incompatible disposition' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Disposition='EXCLUDED_FROM_TRANSFER'}
    Reject-Plan 'private config cannot be promoted to runtime' {param($x)$c=$x.Changes|Where-Object{$_.Path -eq 'web.config'};$c.Classification='RUNTIME_WEB';$c.Disposition='CANDIDATE_PLAN_ONLY'}
    Reject-Plan 'excluded data cannot be promoted' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Path='App_Data/private.aspx'}
    Reject-Plan 'traversal rejected before inspection' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Path='../escape.aspx'}
    Reject-Plan 'absolute path rejected' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Path='C:/private.aspx'}
    Reject-Plan 'ADS rejected' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Path='Default.aspx:secret'}
    Reject-Plan 'device name rejected' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).Path='NUL.aspx'}
    Reject-Plan 'case insensitive path collision' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Baseline.aspx'}).Path='default.aspx'}
    Reject-Plan 'directory case collision' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Baseline.aspx'}).Path='public/other.aspx'}
    Reject-Plan 'rename source unsafe' {param($x)($x.Changes|Where-Object{$_.Operation -eq 'RENAMED'}).OldPath='../old.aspx'}
    Reject-Plan 'unsupported symlink mode' {param($x)($x.Changes|Where-Object{$_.Path -eq 'Default.aspx'}).NewMode='120000'}
    $malformed=Join-Path $fixture 'malformed.json';[IO.File]::WriteAllText($malformed,'{"Schema":',$utf8);$r=Run-Attestation $malformed $script:targetA (Join-Path $EvidenceDirectory 'malformed');Check 'malformed JSON sanitized' ($r.Code -eq 1 -and $r.Error -match '^KS_ATTEST_[A-Z0-9_]+\s*$')
    $duplicate=Join-Path $fixture 'duplicate.json';[IO.File]::WriteAllText($duplicate,($script:planText -replace '"Schema":','"Schema":"duplicate","Schema":'),$utf8);$r=Run-Attestation $duplicate $script:targetA (Join-Path $EvidenceDirectory 'duplicate');Check 'duplicate JSON members rejected' ($r.Code -eq 1 -and $r.Error -match '^KS_ATTEST_DUPLICATE_JSON_MEMBER')
    $outside=Join-Path $fixture 'outside';[void][IO.Directory]::CreateDirectory($outside);Write-Fixture $outside 'Default.aspx' (Text-Bytes 'redirect-private-marker')
    $junction=Join-Path $script:targetA 'Redirect';[void](New-Item -ItemType Junction -Path $junction -Target $outside)
    $redirectPlan=New-BadPlan 'redirect' {param($x)$c=$x.Changes|Where-Object{$_.Path -eq 'Default.aspx'};$c.Path='Redirect/Default.aspx';$x.RuntimePaths=@($x.Changes|Where-Object{$_.Classification -eq 'RUNTIME_WEB'}|ForEach-Object Path)}
    $r=Run-Attestation $redirectPlan $script:targetA (Join-Path $EvidenceDirectory 'junction');Check 'real junction observation completes fail closed' ($r.Code -eq 0)
    $j=Read-Json (Join-Path $EvidenceDirectory 'junction/attestation.json')
    Check 'reparse chain blocked before content read' ((Observed $j 'Redirect/Default.aspx').Status -eq 'BLOCKED_UNSAFE_PATH' -and $null -eq (Observed $j 'Redirect/Default.aspx').ObservedSHA256)
    $r=Run-Attestation $planPath $junction (Join-Path $EvidenceDirectory 'root-junction');Check 'root junction rejected' ($r.Code -eq 1)
    [IO.Directory]::Delete($junction);$junction=$null
    [void](New-Item -ItemType HardLink -Path (Join-Path $script:targetA 'hardlink-alias.aspx') -Target (Join-Path $script:targetA 'Hardlink.aspx'))
    $r=Run-Attestation $planPath $script:targetA (Join-Path $EvidenceDirectory 'hardlink');Check 'hardlink run completes' ($r.Code -eq 0)
    $j=Read-Json (Join-Path $EvidenceDirectory 'hardlink/attestation.json')
    Check 'hardlink content not hashed' ((Observed $j 'Hardlink.aspx').Status -eq 'BLOCKED_UNSAFE_PATH' -and $null -eq (Observed $j 'Hardlink.aspx').ObservedSHA256)
    [IO.File]::Delete((Join-Path $script:targetA 'hardlink-alias.aspx'))
    $r=Run-Attestation $planPath '\\invalid.example.invalid\share' (Join-Path $EvidenceDirectory 'network');Check 'UNC rejected lexically without network' ($r.Code -eq 1 -and $r.Error -match '^KS_ATTEST_LOCAL_PATH_REQUIRED')
    $r=Run-Attestation $planPath $script:targetA (Join-Path $script:targetA 'output');Check 'output cannot write in inspection root' ($r.Code -eq 1 -and $r.Error -match '^KS_ATTEST_NEW_DISJOINT_TEMP_OUTPUT_REQUIRED')
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($verifier,[ref]$tokens,[ref]$errors)
    Check 'verifier syntax' ($errors.Count -eq 0)
    $commands=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object{$_.GetCommandName()})
    Check 'no network database IIS Git enumeration or mutating target commands' (@($commands|Where-Object{$_ -match '^(?:git|Invoke-WebRequest|Invoke-RestMethod|Get-ChildItem|Get-Content|Copy-Item|Move-Item|Remove-Item|Set-Content|Set-Acl|Set-ItemProperty|Start-Service|Restart-Service)$'}).Count -eq 0)
    $source=[IO.File]::ReadAllText($verifier,$utf8)
    Check 'no timestamp registry policy or ACL write APIs' ($source -notmatch '(?i)SetLastAccessTime|SetFileTime|SetFileInformationByHandle|SetAccessControl|Set-ExecutionPolicy|Set-ItemProperty|RegistryKey|fsutil|reg\.exe')
    $policyAfter=@(Get-ExecutionPolicy -List|Where-Object{$_.Scope -ne 'Process'}|ForEach-Object{$_.Scope.ToString()+':'+$_.ExecutionPolicy})
    Check 'persistent execution policy scopes preserved' (($policyBefore -join '|') -ceq ($policyAfter -join '|'))
}catch{$failure=[string]$_.Exception.Message;Write-Output $failure}
finally{
    if($locked){$locked.Dispose()};if($privateLock){$privateLock.Dispose()}
    if($junction -and [IO.Directory]::Exists($junction)){[IO.Directory]::Delete($junction)}
    if($fixture -and [IO.Directory]::Exists($fixture)){
        $resolved=[IO.Path]::GetFullPath($fixture);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if($resolved.StartsWith($tempRoot+'\KeepStoreAttestation-fixture-',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop;$cleanup=-not(Test-Path -LiteralPath $resolved)}
    }
    if(Test-Path -LiteralPath $EvidenceDirectory){
        $report=[ordered]@{Schema='KeepStore.TenantFileAttestationTests.v1';PowerShell=$PSVersionTable.PSVersion.ToString();Edition=$PSVersionTable.PSEdition;Passed=@($checks|Where-Object Passed).Count;Failed=@($checks|Where-Object{-not $_.Passed}).Count;Failure=$(if(Get-Variable failure -ErrorAction SilentlyContinue){$failure}else{$null});Cleanup=$cleanup;Checks=@($checks.ToArray());Reused=@('PR367 generator 59/59 historical unchanged contracts NOT RERUN; generator invoked once on new synthetic Git fixture');InformationalLastAccessChanges=$(if(Get-Variable accessChanges -ErrorAction SilentlyContinue){$accessChanges}else{$null});LastAccessDecision='TEST20-LASTACCESS-ENVIRONMENT-1A technical decision within general authorization; automatic read effect only, no explicit timestamp writes';Limits=@('No IIS DB network login operational folders';'Unreadable tested using exclusive read handle, not operational ACL';'Normal concurrent writes denied by sharing mode; arbitrary malicious filesystem atomicity not claimed')}
        [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),($report|ConvertTo-Json -Depth 8)+"`n",$utf8)
    }
}
if((Get-Variable failure -ErrorAction SilentlyContinue) -or -not $cleanup -or @($checks|Where-Object{-not $_.Passed}).Count){exit 1}
Write-Output ('KS_ATTEST_TESTS_PASS;Checks='+$checks.Count+';Cleanup='+$cleanup)
