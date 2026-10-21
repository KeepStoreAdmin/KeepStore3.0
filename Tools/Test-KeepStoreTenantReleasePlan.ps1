[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$EvidenceDirectory
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$utf8=New-Object Text.UTF8Encoding($false,$true)
$git=@(Get-Command git.exe -CommandType Application -ErrorAction Stop)[0].Source
$ps51=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$generator=Join-Path $PSScriptRoot 'New-KeepStoreTenantReleasePlan.ps1'
$policyBefore=@(Get-ExecutionPolicy -List | Where-Object {$_.Scope -ne 'Process'} | ForEach-Object {$_.Scope.ToString()+'='+$_.ExecutionPolicy.ToString()})
$checks=New-Object 'Collections.Generic.List[object]'
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreReleaseFixture-'+[Guid]::NewGuid().ToString('N'))
if(-not $EvidenceDirectory){$EvidenceDirectory=Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreReleaseTests-'+[Guid]::NewGuid().ToString('N'))}
$evidenceFull=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempFull=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if(-not $evidenceFull.StartsWith($tempFull+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidenceFull)){throw 'KS_RELEASE_TEST_NEW_TEMP_EVIDENCE_REQUIRED'}
[void](New-Item -ItemType Directory -Path $evidenceFull)
$failure=$null; $cleanup=$false; $historicalSummary=$null

function Assert-Check([bool]$Condition,[string]$Name){
    $checks.Add([pscustomobject]@{Name=$Name;Pass=$Condition})
    if(-not $Condition){throw ('KS_RELEASE_TEST_ASSERT_'+$Name)}
}

function Invoke-TestProcess([string]$Executable,[string[]]$Arguments,[byte[]]$InputBytes=$null,[string]$Working=$fixtureRoot){
    $p=$null; $ms=$null
    try{
        $i=New-Object Diagnostics.ProcessStartInfo
        $i.FileName=$Executable;$i.WorkingDirectory=$Working;$i.UseShellExecute=$false;$i.CreateNoWindow=$true
        $i.RedirectStandardOutput=$true;$i.RedirectStandardError=$true;$i.RedirectStandardInput=$true
        $i.EnvironmentVariables['GIT_TERMINAL_PROMPT']='0';$i.EnvironmentVariables['GIT_NO_LAZY_FETCH']='1'
        $i.Arguments=(@($Arguments|ForEach-Object {$a=[regex]::Replace([string]$_,'(\\*)"','$1$1\"');$a=[regex]::Replace($a,'(\\+)$','$1$1');'"'+$a+'"'}) -join ' ')
        $p=New-Object Diagnostics.Process;$p.StartInfo=$i;[void]$p.Start()
        $err=$p.StandardError.ReadToEndAsync()
        if($null -ne $InputBytes){$p.StandardInput.BaseStream.Write($InputBytes,0,$InputBytes.Length)}
        $p.StandardInput.Close();$ms=New-Object IO.MemoryStream
        $p.StandardOutput.BaseStream.CopyTo($ms);$p.WaitForExit()
        return [pscustomobject]@{Code=$p.ExitCode;Bytes=$ms.ToArray();Error=$err.GetAwaiter().GetResult()}
    }finally{if($ms){$ms.Dispose()};if($p){if(-not $p.HasExited){$p.Kill();$p.WaitForExit()};$p.Dispose()}}
}
function G([string[]]$Arguments,[byte[]]$InputBytes=$null){
    $r=Invoke-TestProcess $git $Arguments $InputBytes
    if($r.Code -ne 0){throw 'KS_RELEASE_TEST_FIXTURE_GIT_FAILED'}
    return $utf8.GetString($r.Bytes).TrimEnd("`r","`n")
}
function Write-Fixture([string]$Path,[string]$Text){
    $full=Join-Path $fixtureRoot $Path;$parent=[IO.Path]::GetDirectoryName($full)
    [void][IO.Directory]::CreateDirectory($parent);[IO.File]::WriteAllText($full,$Text,$utf8)
}
function Commit-Fixture([string]$Message){
    [void](G @('add','--all'));[void](G @('-c','commit.gpgsign=false','commit','-qm',$Message));return G @('rev-parse','HEAD')
}
function New-TestTree($Entries){
    $ms=New-Object IO.MemoryStream
    try{
        foreach($e in $Entries){$h=$utf8.GetBytes($e.Mode+' '+$e.Name+[char]0);$ms.Write($h,0,$h.Length);$raw=New-Object byte[] 20;for($n=0;$n -lt 20;$n++){$raw[$n]=[Convert]::ToByte($e.Oid.Substring($n*2,2),16)};$ms.Write($raw,0,$raw.Length)}
        return G @('hash-object','--literally','-t','tree','-w','--stdin') $ms.ToArray()
    }finally{$ms.Dispose()}
}
function Commit-Tree([string]$Tree,[string]$Parent){
    $a=@('commit-tree',$Tree);if($Parent){$a+=@('-p',$Parent)}
    return G $a $utf8.GetBytes("synthetic tree`n")
}
function Run-Plan([string]$From,[string]$To,[string]$Label='fixture-a',[string]$Output='',[string]$Root=$fixtureRoot){
    if(-not $Output){$Output=Join-Path $evidenceFull ('plan-'+[Guid]::NewGuid().ToString('N'))}
    $args=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$generator,'-RepoRoot',$Root,'-FromCommit',$From,'-ToCommit',$To,'-OutputDirectory',$Output,'-TargetLabel',$Label)
    $r=Invoke-TestProcess $ps51 $args $null $fixtureRoot
    $plan=$null;if($r.Code -eq 0){$plan=Get-Content -LiteralPath (Join-Path $Output 'plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json}
    return [pscustomobject]@{Code=$r.Code;Plan=$plan;Output=$Output;Error=$r.Error}
}

try{
    Assert-Check (Test-Path -LiteralPath $ps51) 'WINDOWS_POWERSHELL_51_AVAILABLE'
    [void](New-Item -ItemType Directory -Path $fixtureRoot)
    [void](G @('init','-q'));[void](G @('config','user.name','Synthetic Release Fixture'));[void](G @('config','user.email','release-fixture@example.invalid'));[void](G @('config','core.autocrlf','false'));[void](G @('config','core.hooksPath',(Join-Path $fixtureRoot '.git/empty-hooks')))
    Write-Fixture 'Default.aspx' '<%@ Page CodeFile="Default.aspx.vb" MasterPageFile="~/Page.master" %><link href="Public/assets/mock/css/site.css?v=1" />'
    Write-Fixture 'Default.aspx.vb' 'Partial Class FixturePage : End Class'
    Write-Fixture 'Page.master' '<%@ Master CodeFile="Page.master.vb" %>'
    Write-Fixture 'Page.master.vb' 'Partial Class FixtureMaster : End Class'
    Write-Fixture 'Public/assets/mock/css/site.css' 'body { color: black; }'
    Write-Fixture 'delete.aspx' '<p>unique removed fixture</p>'
    Write-Fixture 'rename old.aspx' '<p>unique renamed fixture</p>'
    Write-Fixture 'web.config' '<configuration>SYNTHETIC_PRIVATE_DO_NOT_REPORT_439</configuration>'
    Write-Fixture 'docs/fixture.md' 'SYNTHETIC_PRIVATE_DO_NOT_REPORT_439'
    Write-Fixture 'Tools/fixture.ps1' '# SYNTHETIC_PRIVATE_DO_NOT_REPORT_439'
    $base=Commit-Fixture 'base'
    Write-Fixture 'Default.aspx' '<%@ Page CodeFile="Default.aspx.vb" MasterPageFile="~/Page.master" %><link href="Public/assets/mock/css/site.css?v=2" /><script src="Public/assets/mock/js/new.js"></script><script src="<%= ThemeManager.Asset("js/new.js") %>?v=2"></script>'
    Write-Fixture 'Public/assets/mock/css/site.css' 'body { color: blue; }'
    Write-Fixture 'Public/assets/mock/js/new.js' 'window.syntheticFixture = true; var markup = "<img src=''" + dynamicImage + "''>";'
    Write-Fixture 'App_Code/NewHelper.vb' 'Public Class NewHelper : End Class'
    Write-Fixture 'Public/ui/controls/Widget.ascx' '<%@ Control CodeFile="Widget.ascx.vb" %>'
    Write-Fixture 'Public/ui/controls/Widget.ascx.vb' 'Partial Class Widget : End Class'
    [IO.File]::WriteAllBytes((Join-Path $fixtureRoot 'binary.tmp'),[byte[]]@(0,255,10,13,128,0,42))
    $image='Public/assets/images/with spaces/caf'+[char]0x00e8+'-'+[char]0x6771+[char]0x4eac+'.png'
    [void][IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'Public/assets/images/with spaces'))
    [IO.File]::Move((Join-Path $fixtureRoot 'binary.tmp'),(Join-Path $fixtureRoot $image))
    [void][IO.Directory]::CreateDirectory((Join-Path $fixtureRoot 'Bin'))
    [IO.File]::WriteAllBytes((Join-Path $fixtureRoot 'Bin/Synthetic.dll'),[byte[]]@(77,90,0,255,0))
    [IO.File]::Delete((Join-Path $fixtureRoot 'delete.aspx'))
    [void](G @('mv','rename old.aspx',('renamed '+[char]0x00e8+'.aspx')))
    Write-Fixture 'web.config' '<configuration>SYNTHETIC_PRIVATE_DO_NOT_REPORT_439 changed</configuration>'
    Write-Fixture 'docs/fixture.md' 'SYNTHETIC_PRIVATE_DO_NOT_REPORT_439 changed'
    Write-Fixture 'Tools/fixture.ps1' '# SYNTHETIC_PRIVATE_DO_NOT_REPORT_439 changed'
    $candidate=Commit-Fixture 'candidate'
    Write-Fixture '.gitignore' 'ignored.secret'
    Write-Fixture 'ignored.secret' 'SYNTHETIC_PRIVATE_DO_NOT_REPORT_439'
    Write-Fixture 'untracked.aspx' 'SYNTHETIC_PRIVATE_DO_NOT_REPORT_439'
    $statusBefore=G @('status','--porcelain=v1','-uall')
    $configHash=(Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'web.config') -Algorithm SHA256).Hash
    $r=Run-Plan $base $candidate
    Assert-Check ($r.Code -eq 0) 'MAIN_PLAN_EXECUTES_IN_51'
    $p=$r.Plan
    Assert-Check ($p.Mode -eq 'PLAN_ONLY' -and -not $p.PayloadCreated -and -not $p.PublicationAuthorized) 'NO_PAYLOAD_NO_APPLY_AUTHORITY'
    Assert-Check ($p.ReleaseReadiness -eq 'BLOCKED_TARGET_NOT_VERIFIED') 'UNKNOWN_TARGET_ALWAYS_BLOCKED'
    Assert-Check ($p.Target.InstalledCommit.Status -eq 'UNKNOWN' -and $null -eq $p.Target.InstalledCommit.SHA) 'FROM_IS_NOT_INSTALLED_ATTESTATION'
    Assert-Check ($p.Target.PhysicalPath.Status -eq 'UNKNOWN' -and $null -eq $p.Target.PhysicalPath.Value) 'NO_REAL_TARGET_PATH'
    Assert-Check (@($p.Changes|Where-Object {$_.Operation -eq 'ADDED'}).Count -ge 5) 'ADDITIONS_RETAINED'
    Assert-Check (@($p.Changes|Where-Object {$_.Operation -eq 'MODIFIED'}).Count -ge 4) 'MODIFICATIONS_RETAINED'
    Assert-Check (@($p.Changes|Where-Object {$_.Operation -eq 'DELETED' -and $_.Path -eq 'delete.aspx'}).Count -eq 1) 'DELETION_MANUAL_PLAN'
    $rename=@($p.Changes|Where-Object {$_.Operation -eq 'RENAMED'})
    Assert-Check ($rename.Count -eq 1 -and $rename[0].OldPath -eq 'rename old.aspx') 'RENAME_SOURCE_RETAINED'
    Assert-Check ($rename[0].Path -ceq ('renamed '+[char]0x00e8+'.aspx')) 'RENAME_UNICODE_DESTINATION'
    $bin=@($p.Changes|Where-Object {$_.Path -ceq $image})[0]
    Assert-Check ($bin.AfterSHA256 -eq (Get-FileHash -LiteralPath (Join-Path $fixtureRoot $image) -Algorithm SHA256).Hash) 'BINARY_BYTES_AND_UNICODE_PATH_HASH'
    Assert-Check (@($p.RuntimePaths|Where-Object {$_ -eq 'Bin/Synthetic.dll'}).Count -eq 1) 'ASSEMBLY_IN_MANIFEST_WITH_COMPILE_GATE'
    Assert-Check (@($p.RuntimePaths|Where-Object {$_ -eq 'App_Code/NewHelper.vb'}).Count -eq 1) 'NEW_APPCODE_HELPER_NOT_LOST'
    Assert-Check (@($p.Dependencies|Where-Object {$_.Kind -eq 'MARKUP_PAIR' -and $_.Resolution -eq 'SOURCE_PRESENT'}).Count -ge 1) 'CODE_BEHIND_PAIR'
    Assert-Check (@($p.Dependencies|Where-Object {$_.Path -eq 'Public/assets/mock/js/new.js' -and $_.InDelta -and $_.Resolution -eq 'SOURCE_PRESENT'}).Count -ge 1) 'NEW_JS_REFERENCE_RESOLVED_FROM_GIT'
    Assert-Check (@($p.Dependencies|Where-Object {$_.Path -eq 'Public/assets/mock/css/site.css' -and $_.CacheBusterPresent}).Count -eq 1) 'CSS_CACHE_BUSTER_REFERENCE'
    Assert-Check (@($p.Dependencies|Where-Object {$_.Kind -eq 'THEME_MANAGER_ASSET'}).Count -eq 1) 'THEME_VARIANT_REFERENCE'
    Assert-Check (@($p.Dependencies|Where-Object {$_.Source -eq 'Public/assets/mock/js/new.js'}).Count -eq 0 -and @($p.DependencyLimits|Where-Object {$_.Code -eq 'JAVASCRIPT_RUNTIME_REFERENCES_REQUIRE_REVIEW'}).Count -eq 1) 'JS_CONCATENATION_IS_NOT_STATIC_ASSET'
    foreach($path in @('web.config','Tools/fixture.ps1','docs/fixture.md')){
        $excluded=@($p.Changes|Where-Object {$_.Path -ceq $path})[0]
        Assert-Check ($excluded.Disposition -eq 'EXCLUDED_FROM_TRANSFER' -and $null -eq $excluded.AfterSHA256 -and $null -eq $excluded.BeforeSHA256) ('EXCLUDED_NOT_READ_'+$path)
    }
    $reportText=[IO.File]::ReadAllText((Join-Path $r.Output 'plan.json'))+[IO.File]::ReadAllText((Join-Path $r.Output 'plan.md'))
    Assert-Check (-not $reportText.Contains('SYNTHETIC_PRIVATE_DO_NOT_REPORT_439') -and -not $reportText.Contains($fixtureRoot)) 'NO_SECRET_OR_PRIVATE_ROOT_IN_REPORTS'
    Assert-Check (@(Get-ChildItem -LiteralPath $r.Output -File).Count -eq 2) 'ONLY_JSON_AND_MARKDOWN_OUTPUT'
    Assert-Check (-not (@($p.Changes.Path) -contains 'untracked.aspx') -and -not (@($p.Changes.Path) -contains 'ignored.secret')) 'UNTRACKED_IGNORED_NOT_ENUMERATED'
    Assert-Check ($statusBefore -ceq (G @('status','--porcelain=v1','-uall'))) 'GENERATOR_NO_WORKTREE_OR_INDEX_MUTATION'
    Assert-Check ($configHash -eq (Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'web.config') -Algorithm SHA256).Hash) 'CONFIGURATION_UNCHANGED'
    $again=Run-Plan $base $candidate
    foreach($name in @('plan.json','plan.md')){Assert-Check ((Get-FileHash (Join-Path $r.Output $name)).Hash -eq (Get-FileHash (Join-Path $again.Output $name)).Hash) ('DETERMINISTIC_'+$name)}
    $other=Run-Plan $candidate $candidate 'fixture-b'
    Assert-Check ($other.Code -eq 0 -and $other.Plan.Summary.GitChanges -eq 0 -and $p.Summary.GitChanges -gt 0) 'TWO_APPLICATIONS_DIFFERENT_COMPARISON_BASELINES'
    Assert-Check ($other.Plan.Target.InstalledCommit.Status -eq 'UNKNOWN' -and $other.Plan.Target.Id -ne $p.Target.Id -and $other.Plan.ReleaseReadiness -eq 'BLOCKED_TARGET_NOT_VERIFIED') 'TENANTS_NEVER_INHERIT_ATTESTATIONS'
    Assert-Check ($other.Plan.Target.DatabaseTopology -eq 'UNKNOWN_SHARED_OR_INDEPENDENT') 'DATABASE_NOT_TENANT_IDENTITY'

    $unknown=Run-Plan ('0'*40) $candidate
    Assert-Check ($unknown.Code -ne 0 -and -not (Test-Path $unknown.Output) -and $unknown.Error -match 'KS_RELEASE_GIT_READ_FAILED') 'NONEXISTENT_COMMIT_SANITIZED'
    $badRef=Run-Plan 'HEAD' $candidate
    Assert-Check ($badRef.Code -ne 0 -and -not (Test-Path $badRef.Output)) 'EXPLICIT_FULL_SHAS_ONLY'
    $reuse=Run-Plan $base $candidate 'fixture-a' $r.Output
    Assert-Check ($reuse.Code -ne 0 -and $reuse.Error -match 'KS_RELEASE_OUTPUT_ALREADY_EXISTS') 'EXISTING_OUTPUT_NOT_OVERWRITTEN'
    $inside=Run-Plan $base $candidate 'fixture-a' (Join-Path $fixtureRoot 'forbidden-output')
    Assert-Check ($inside.Code -ne 0 -and -not (Test-Path $inside.Output)) 'OUTPUT_CANNOT_ENTER_REPOSITORY'
    $badLabel=Run-Plan $base $candidate 'https://private.invalid/'
    Assert-Check ($badLabel.Code -ne 0 -and $badLabel.Error -notmatch 'private.invalid') 'LABEL_REJECTED_WITHOUT_ECHO'

    $blob=G @('hash-object','-w','--stdin') $utf8.GetBytes('<p>synthetic</p>')
    $tree=New-TestTree @(@{Mode='100644';Name='Case.aspx';Oid=$blob})
    $caseBase=Commit-Tree $tree $candidate
    $caseTree=New-TestTree @(@{Mode='100644';Name='case.aspx';Oid=$blob})
    $caseEnd=Commit-Tree $caseTree $caseBase
    $case=Run-Plan $caseBase $caseEnd
    Assert-Check ($case.Code -eq 0 -and $case.Plan.Changes[0].CaseOnlyRename -and $case.Plan.Changes[0].Disposition -eq 'BLOCKED_REVIEW_REQUIRED') 'CASE_ONLY_RENAME_MANUAL_GATE'
    $collisionTree=New-TestTree @(@{Mode='100644';Name='Case.aspx';Oid=$blob},@{Mode='100644';Name='case.aspx';Oid=$blob})
    $collision=Run-Plan $caseBase (Commit-Tree $collisionTree $caseBase)
    Assert-Check ($collision.Code -eq 0 -and @($collision.Plan.TreeIssues|Where-Object {$_.Code -eq 'WINDOWS_CASE_OR_NORMALIZATION_COLLISION'}).Count -ge 1) 'WINDOWS_CASE_COLLISION_BLOCKED'
    Assert-Check (@($collision.Plan.Changes|Where-Object {$_.Disposition -eq 'BLOCKED_REVIEW_REQUIRED'}).Count -ge 1) 'COLLIDING_CHANGE_CANNOT_BE_CANDIDATE'
    $secretBlob=G @('hash-object','-w','--stdin') $utf8.GetBytes('SYNTHETIC_PRIVATE_DO_NOT_REPORT_439')
    $secretTree=New-TestTree @(@{Mode='100644';Name='web.config';Oid=$secretBlob})
    $secretBase=Commit-Tree $secretTree $candidate
    $secretRenameTree=New-TestTree @(@{Mode='100644';Name='RenamedSecret.aspx';Oid=$secretBlob})
    $crossScope=Run-Plan $secretBase (Commit-Tree $secretRenameTree $secretBase)
    Assert-Check ($crossScope.Code -eq 0 -and $crossScope.Plan.Changes[0].Operation -eq 'RENAMED' -and $crossScope.Plan.Changes[0].Disposition -eq 'BLOCKED_REVIEW_REQUIRED' -and $null -eq $crossScope.Plan.Changes[0].AfterSHA256) 'PRIVATE_TO_RUNTIME_RENAME_NEVER_READ'
    $editedBlob=G @('hash-object','-w','--stdin') $utf8.GetBytes('<p>synthetic edited rename</p>')
    $editedTree=New-TestTree @(@{Mode='100644';Name='EditedName.aspx';Oid=$editedBlob})
    $edited=Run-Plan $caseBase (Commit-Tree $editedTree $caseBase)
    Assert-Check ($edited.Code -eq 0 -and @($edited.Plan.Changes|Where-Object {$_.Operation -eq 'ADDED'}).Count -eq 1 -and @($edited.Plan.Changes|Where-Object {$_.Operation -eq 'DELETED'}).Count -eq 1) 'EDITED_MOVE_IS_EXPLICIT_DELETE_AND_ADD'
    $subTree=New-TestTree @(@{Mode='100644';Name='escape.aspx';Oid=$blob})
    $badTree=New-TestTree @(@{Mode='40000';Name='..';Oid=$subTree},@{Mode='100644';Name='bad:name.aspx';Oid=$blob},@{Mode='120000';Name='link.aspx';Oid=$blob},@{Mode='160000';Name='submodule';Oid=$candidate},@{Mode='100644';Name='unrecognized.opaque';Oid=$blob},@{Mode='100644';Name='NUL.aspx';Oid=$blob})
    $unsafe=Run-Plan $caseBase (Commit-Tree $badTree $caseBase)
    Assert-Check ($unsafe.Code -eq 0 -and $unsafe.Plan.SourceAnalysis -eq 'REVIEW_REQUIRED') 'UNSAFE_SOURCE_REPORTS_BLOCKERS_NOT_READY'
    foreach($path in @('../escape.aspx','bad:name.aspx','link.aspx','submodule','unrecognized.opaque','NUL.aspx')){
        $item=@($unsafe.Plan.Changes|Where-Object {$_.Path -ceq $path})[0]
        Assert-Check ($item.Disposition -eq 'BLOCKED_REVIEW_REQUIRED' -and $null -eq $item.AfterSHA256) ('UNSAFE_NOT_READ_'+$path)
    }
    $unrelated=Commit-Tree $tree ''
    $diverged=Run-Plan $base $unrelated
    Assert-Check ($diverged.Code -ne 0 -and $diverged.Error -match 'KS_RELEASE_BASE_NOT_ANCESTOR') 'NONANCESTOR_REJECTED'
    $missingBlob=G @('hash-object','-w','--stdin') $utf8.GetBytes('<%@ Page CodeFile="Missing.aspx.vb" %><script src="Public/assets/mock/js/absent.js"></script>')
    $missingTree=New-TestTree @(@{Mode='100644';Name='Missing.aspx';Oid=$missingBlob})
    $missing=Run-Plan $caseBase (Commit-Tree $missingTree $caseBase)
    Assert-Check ($missing.Code -eq 0 -and @($missing.Plan.Dependencies|Where-Object {$_.Resolution -eq 'MISSING_IN_SOURCE'}).Count -eq 2) 'MISSING_DIRECT_DEPENDENCIES_EXPLICIT'
    Assert-Check ($missing.Plan.SourceAnalysis -eq 'REVIEW_REQUIRED') 'MISSING_DEPENDENCY_BLOCKS_READINESS'
    $missingObjectTree=New-TestTree @(@{Mode='100644';Name='MissingObject.aspx';Oid=('1'*40)})
    $missingObject=Run-Plan $caseBase (Commit-Tree $missingObjectTree $caseBase)
    Assert-Check ($missingObject.Code -ne 0 -and -not (Test-Path $missingObject.Output) -and $missingObject.Error -match '^KS_RELEASE_') 'MISSING_BLOB_FAILS_CLOSED_WITHOUT_NETWORK'
    Assert-Check ((G @('remote')) -eq '') 'FIXTURE_HAS_NO_NETWORK_REMOTE'

    $history=Run-Plan 'de85cdd4ba8dfe80ec3a9dcf12390480bd1afc42' 'c8373b08eff0cf9557798802ea4a2d6bfb8e4822' 'historical-comparison-only' (Join-Path $evidenceFull 'historical-363-366') $RepositoryRoot
    Assert-Check ($history.Code -eq 0) 'HISTORICAL_PLAN_GENERATED_OFFLINE'
    $historicalSummary=$history.Plan.Summary
    Assert-Check ($historicalSummary.GitChanges -eq 23 -and $historicalSummary.RuntimeWebChanges -eq 13 -and $historicalSummary.ExcludedChanges -eq 10) 'HISTORICAL_23_GIT_13_RUNTIME_10_EXCLUDED'
    Assert-Check (@($history.Plan.Changes|Where-Object {$_.Path -eq 'App_Code/SearchSuggestCommercialSupport.vb' -and $_.Operation -eq 'ADDED' -and $_.AfterSHA256}).Count -eq 1) 'HISTORICAL_NEW_HELPER_RETAINED'
    Assert-Check (@($history.Plan.Changes|Where-Object {$_.Path -eq 'Public/assets/keepstore/js/ks-shopping-guide.js' -and $_.Operation -eq 'ADDED' -and $_.AfterSHA256}).Count -eq 1) 'HISTORICAL_NEW_JS_RETAINED'
    Assert-Check ($history.Plan.Target.InstalledCommit.Status -eq 'UNKNOWN' -and -not $history.Plan.PublicationAuthorized) 'HISTORICAL_BASELINE_NEVER_PRODUCTION_ATTESTATION'
}catch{
    $failure=[string]$_.Exception.Message
    if($failure -notmatch '^KS_RELEASE_TEST_[A-Za-z0-9_./-]+$'){$failure='KS_RELEASE_TEST_FAILED'}
}finally{
    # Delete only the unique fixture root owned by this run; retain evidence/plans.
    if(Test-Path -LiteralPath $fixtureRoot){
        $resolved=[IO.Path]::GetFullPath($fixtureRoot)
        if(-not $resolved.StartsWith($tempFull+'\KeepStoreReleaseFixture-',[StringComparison]::OrdinalIgnoreCase) -or (Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'KS_RELEASE_TEST_CLEANUP_ROOT_REJECTED'}
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
    $cleanup=-not (Test-Path -LiteralPath $fixtureRoot)
    $policyAfter=@(Get-ExecutionPolicy -List | Where-Object {$_.Scope -ne 'Process'} | ForEach-Object {$_.Scope.ToString()+'='+$_.ExecutionPolicy.ToString()})
    $policyMatch=($policyBefore -join '|') -ceq ($policyAfter -join '|')
    if(-not $policyMatch){$failure='KS_RELEASE_TEST_PERSISTENT_POLICY_CHANGED'}
    $report=[ordered]@{Schema='KeepStore.TenantReleasePlanTests.v1';PowerShell=[string]$PSVersionTable.PSVersion;ProcessPolicy=[string](Get-ExecutionPolicy);PersistentPoliciesUnchanged=$policyMatch;Passed=@($checks|Where-Object {$_.Pass}).Count;Failed=@($checks|Where-Object {-not $_.Pass}).Count;Failure=$failure;FixtureCleanup=$cleanup;OperationalAccess=$false;NetworkUsed=$false;HistoricalComparison=$historicalSummary;Checks=@($checks.ToArray())}
    [IO.File]::WriteAllText((Join-Path $evidenceFull 'test-report.json'),($report|ConvertTo-Json -Depth 8),$utf8)
    Write-Output ('KS_RELEASE_TESTS;PASS='+$report.Passed+';FAIL='+$report.Failed+';CLEANUP='+$cleanup+';REPORT='+$evidenceFull)
}
if($failure -or -not $cleanup){[Console]::Error.WriteLine($failure);exit 1}
