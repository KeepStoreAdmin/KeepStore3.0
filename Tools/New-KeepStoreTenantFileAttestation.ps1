[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PlanPath,
    [Parameter(Mandatory=$true)][string]$InspectionRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$TargetLabel
)

# File observations only. No Git, enumeration of target directories, or apply mode.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$script:Utf8=New-Object Text.UTF8Encoding($false,$true)
$script:ReadBytes=0L
$script:Clock=[Diagnostics.Stopwatch]::StartNew()
$script:MaxFileBytes=134217728L
$script:MaxReadBytes=536870912L

function Initialize-ReadOnlyNative {
    # In-memory .NET interop, not compiled source, an installed module, or a helper file.
    $script:Native='KeepStore.FileObservationNativeV1' -as [type]
    if ($script:Native) { return }
    $assembly=[AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object Reflection.AssemblyName('KeepStore.FileObservationNativeV1')),[Reflection.Emit.AssemblyBuilderAccess]::Run)
    $module=$assembly.DefineDynamicModule('Native')
    $builder=$module.DefineType('KeepStore.FileObservationNativeV1',[Reflection.TypeAttributes]'Public,Abstract,Sealed')
    $safe=[Microsoft.Win32.SafeHandles.SafeFileHandle]
    $definitions=@(
        @('CreateFileW',$safe,[type[]]@([string],[uint32],[uint32],[IntPtr],[uint32],[uint32],[IntPtr])),
        @('GetFileInformationByHandle',[bool],[type[]]@($safe,[IntPtr])),
        @('GetFileInformationByHandleEx',[bool],[type[]]@($safe,[int],[IntPtr],[uint32])),
        @('GetFinalPathNameByHandleW',[uint32],[type[]]@($safe,[Text.StringBuilder],[uint32],[uint32])),
        @('GetFileType',[uint32],[type[]]@($safe))
    )
    foreach ($d in $definitions) {
        $m=$builder.DefineMethod($d[0],[Reflection.MethodAttributes]'Public,Static,PinvokeImpl',[Reflection.CallingConventions]::Standard,$d[1],$d[2])
        $ctor=[Runtime.InteropServices.DllImportAttribute].GetConstructor([type[]]@([string]))
        $fields=[Reflection.FieldInfo[]]@('SetLastError','CharSet','CallingConvention','ExactSpelling'|ForEach-Object{[Runtime.InteropServices.DllImportAttribute].GetField($_)})
        $attribute=New-Object Reflection.Emit.CustomAttributeBuilder($ctor,[object[]]@('kernel32.dll'),$fields,[object[]]@($true,[Runtime.InteropServices.CharSet]::Unicode,[Runtime.InteropServices.CallingConvention]::Winapi,$true))
        $m.SetCustomAttribute($attribute)
        $m.SetImplementationFlags($m.GetMethodImplementationFlags() -bor [Reflection.MethodImplAttributes]::PreserveSig)
        if($d[0] -eq 'CreateFileW'){$createMethod=$m}
    }
    # Capture the native error in the same managed call, before PowerShell can change it.
    $open=$builder.DefineMethod('OpenExisting',[Reflection.MethodAttributes]'Public,Static',[object[]],[type[]]@([string],[uint32],[uint32],[uint32]))
    $il=$open.GetILGenerator();[void]$il.DeclareLocal($safe);[void]$il.DeclareLocal([int])
    $il.Emit([Reflection.Emit.OpCodes]::Ldarg_0);$il.Emit([Reflection.Emit.OpCodes]::Ldarg_1);$il.Emit([Reflection.Emit.OpCodes]::Ldarg_2)
    $il.Emit([Reflection.Emit.OpCodes]::Ldsfld,[IntPtr].GetField('Zero'));$il.Emit([Reflection.Emit.OpCodes]::Ldc_I4_3);$il.Emit([Reflection.Emit.OpCodes]::Ldarg_3);$il.Emit([Reflection.Emit.OpCodes]::Ldsfld,[IntPtr].GetField('Zero'))
    $il.Emit([Reflection.Emit.OpCodes]::Call,$createMethod);$il.Emit([Reflection.Emit.OpCodes]::Stloc_0)
    $il.Emit([Reflection.Emit.OpCodes]::Call,[Runtime.InteropServices.Marshal].GetMethod('GetLastWin32Error'));$il.Emit([Reflection.Emit.OpCodes]::Stloc_1)
    $il.Emit([Reflection.Emit.OpCodes]::Ldc_I4_2);$il.Emit([Reflection.Emit.OpCodes]::Newarr,[object]);$il.Emit([Reflection.Emit.OpCodes]::Dup);$il.Emit([Reflection.Emit.OpCodes]::Ldc_I4_0);$il.Emit([Reflection.Emit.OpCodes]::Ldloc_0);$il.Emit([Reflection.Emit.OpCodes]::Stelem_Ref)
    $il.Emit([Reflection.Emit.OpCodes]::Dup);$il.Emit([Reflection.Emit.OpCodes]::Ldc_I4_1);$il.Emit([Reflection.Emit.OpCodes]::Ldloc_1);$il.Emit([Reflection.Emit.OpCodes]::Box,[int]);$il.Emit([Reflection.Emit.OpCodes]::Stelem_Ref);$il.Emit([Reflection.Emit.OpCodes]::Ret)
    $script:Native=$builder.CreateType()
}

function Get-LocalAbsolute([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\x00-\x1f\x7f]' -or $Path.Substring(2) -match '[:*?"<>|]') { throw 'KS_ATTEST_LOCAL_PATH_REQUIRED' }
    $parts=$Path.Substring(3).Replace('\','/').TrimEnd('/').Split('/')
    foreach ($p in $parts) { if ($p -in @('.','..') -or $p -match '[. ]$') { throw 'KS_ATTEST_AMBIGUOUS_LOCAL_PATH' } }
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($full.Length -eq 2) { $full+='\' }
    if ($full.Length -gt 240) { throw 'KS_ATTEST_LOCAL_PATH_LIMIT' }
    $drive=New-Object IO.DriveInfo($full.Substring(0,3))
    if ($drive.DriveType -notin @([IO.DriveType]::Fixed,[IO.DriveType]::Removable,[IO.DriveType]::Ram)) { throw 'KS_ATTEST_LOCAL_DISK_REQUIRED' }
    return $full
}

function Get-HandleMetadata($Handle) {
    $p=[Runtime.InteropServices.Marshal]::AllocHGlobal(52)
    $q=[Runtime.InteropServices.Marshal]::AllocHGlobal(40)
    try {
        if (-not $script:Native::GetFileInformationByHandle($Handle,$p) -or -not $script:Native::GetFileInformationByHandleEx($Handle,0,$q,40)) { throw 'KS_ATTEST_METADATA_UNAVAILABLE' }
        $bytes=New-Object byte[] 52; [Runtime.InteropServices.Marshal]::Copy($p,$bytes,0,52)
        $basic=New-Object byte[] 40; [Runtime.InteropServices.Marshal]::Copy($q,$basic,0,40)
        return [pscustomobject]@{
            Attributes=[BitConverter]::ToUInt32($bytes,0)
            Identity=([BitConverter]::ToString($bytes,28,4)+':'+[BitConverter]::ToString($bytes,44,8))
            Size=([uint64][BitConverter]::ToUInt32($bytes,32)*4294967296L+[BitConverter]::ToUInt32($bytes,36))
            Links=[BitConverter]::ToUInt32($bytes,40)
            Stable=[BitConverter]::ToString($basic,0,8)+':'+[BitConverter]::ToString($basic,16,20)
        }
    } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($p); [Runtime.InteropServices.Marshal]::FreeHGlobal($q) }
}

function Test-HandlePath($Handle,[string]$Expected) {
    $s=New-Object Text.StringBuilder 1024
    $n=$script:Native::GetFinalPathNameByHandleW($Handle,$s,1024,0)
    if ($n -eq 0 -or $n -ge 1024) { return $false }
    $actual=$s.ToString()
    if (-not $actual.StartsWith('\\?\') -or $actual.StartsWith('\\?\UNC\',[StringComparison]::OrdinalIgnoreCase)) { return $false }
    return [string]::Equals($actual.Substring(4).TrimEnd('\'),$Expected.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)
}

function Close-Chain($Chain) {
    if ($Chain) { for ($i=$Chain.Handles.Count-1;$i -ge 0;$i--) { $Chain.Handles[$i].Dispose() } }
}

function Open-DirectoryChain([string]$Path) {
    $handles=New-Object 'Collections.Generic.List[object]'
    $result=[pscustomobject]@{State='OK';Reason=$null;Handles=$handles}
    $paths=New-Object 'Collections.Generic.List[string]'
    $current=$Path.Substring(0,3); $paths.Add($current)
    foreach ($part in $Path.Substring(3).TrimEnd('\').Split('\')) { if ($part) { $current=[IO.Path]::Combine($current,$part); $paths.Add($current) } }
    try {
        foreach ($current in $paths) {
            # OPEN_EXISTING, READ_ATTRIBUTES, share READ only, BACKUP_SEMANTICS + OPEN_REPARSE_POINT.
            $opened=$script:Native::OpenExisting($current,128,1,35651584);$h=$opened[0];$errorCode=$opened[1]
            if ($h.IsInvalid) {
                $h.Dispose(); $result.State=if($errorCode -in @(2,3)){'MISSING'}else{'UNREADABLE'}; $result.Reason='DIRECTORY_UNAVAILABLE'; break
            }
            $handles.Add($h)
            $meta=Get-HandleMetadata $h
            if (($meta.Attributes -band 1024) -ne 0 -or ($meta.Attributes -band 16) -eq 0 -or -not (Test-HandlePath $h $current)) { $result.State='BLOCKED_UNSAFE_PATH';$result.Reason='DIRECTORY_REDIRECT_OR_TYPE';break }
            # No enumeration: reject case-sensitive directories rather than guessing collisions.
            $p=[Runtime.InteropServices.Marshal]::AllocHGlobal(4)
            try {
                if (-not $script:Native::GetFileInformationByHandleEx($h,23,$p,4)) { $result.State='UNREADABLE';$result.Reason='DIRECTORY_CASE_MODE_UNVERIFIABLE';break }
                if ([Runtime.InteropServices.Marshal]::ReadInt32($p) -ne 0) { $result.State='BLOCKED_UNSAFE_PATH';$result.Reason='CASE_SENSITIVE_DIRECTORY';break }
            } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($p) }
        }
    } catch { $result.State='UNREADABLE';$result.Reason='DIRECTORY_METADATA_UNVERIFIABLE' }
    if ($result.State -ne 'OK') { Close-Chain $result }
    return $result
}

function Open-ReadFile([string]$Path) {
    # GENERIC_READ, share READ only, OPEN_EXISTING; inspect directories/reparse before data.
    $opened=$script:Native::OpenExisting($Path,[uint32]2147483648,1,169869312);$h=$opened[0];$e=$opened[1]
    if ($h.IsInvalid) { $h.Dispose(); return [pscustomobject]@{State=$(if($e -in @(2,3)){'MISSING'}else{'UNREADABLE'});Reason='FILE_UNAVAILABLE';Handle=$null;Metadata=$null} }
    try {
        $m=Get-HandleMetadata $h
        if ($script:Native::GetFileType($h) -ne 1 -or ($m.Attributes -band 16) -ne 0 -or ($m.Attributes -band 4461568) -ne 0 -or $m.Links -ne 1 -or -not (Test-HandlePath $h $Path)) {
            $h.Dispose();return [pscustomobject]@{State='BLOCKED_UNSAFE_PATH';Reason='REPARSE_OFFLINE_HARDLINK_OR_TYPE';Handle=$null;Metadata=$null}
        }
        return [pscustomobject]@{State='OK';Reason=$null;Handle=$h;Metadata=$m}
    } catch { $h.Dispose();return [pscustomobject]@{State='UNREADABLE';Reason='FILE_METADATA_UNVERIFIABLE';Handle=$null;Metadata=$null} }
}

function Read-PlanBytes([string]$Path) {
    $chain=Open-DirectoryChain ([IO.Path]::GetDirectoryName($Path));$opened=$null;$stream=$null
    try {
        if ($chain.State -ne 'OK') { throw 'KS_ATTEST_PLAN_PATH_UNAVAILABLE' }
        $opened=Open-ReadFile $Path
        if ($opened.State -ne 'OK' -or $opened.Metadata.Size -gt 4194304) { throw 'KS_ATTEST_PLAN_UNREADABLE_OR_LIMIT' }
        $stream=New-Object IO.FileStream($opened.Handle,[IO.FileAccess]::Read,65536,$false)
        $data=New-Object byte[] ([int]$opened.Metadata.Size);$offset=0
        while ($offset -lt $data.Length) { $n=$stream.Read($data,$offset,$data.Length-$offset);if($n -eq 0){throw 'KS_ATTEST_PLAN_CHANGED'};$offset+=$n }
        $after=Get-HandleMetadata $opened.Handle
        if ($stream.ReadByte() -ne -1 -or $after.Stable -cne $opened.Metadata.Stable -or $after.Size -ne $opened.Metadata.Size) { throw 'KS_ATTEST_PLAN_CHANGED' }
        return ,$data
    } finally { if($stream){$stream.Dispose()};if($opened -and $opened.Handle){$opened.Handle.Dispose()};Close-Chain $chain }
}

function Assert-JsonMembers([byte[]]$Bytes) {
    # ConvertFrom-Json alone can overwrite duplicate JSON members. Reject them first.
    Add-Type -AssemblyName System.Runtime.Serialization
    $quotas=New-Object Xml.XmlDictionaryReaderQuotas
    $quotas.MaxDepth=32;$quotas.MaxStringContentLength=4194304;$quotas.MaxArrayLength=16384;$quotas.MaxBytesPerRead=65536;$quotas.MaxNameTableCharCount=65536
    $reader=[Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($Bytes,$quotas)
    $stack=New-Object 'Collections.Generic.List[object]'
    try {
        while ($reader.Read()) {
            if ($reader.NodeType -eq [Xml.XmlNodeType]::Element) {
                if ($stack.Count -and $null -ne $stack[$stack.Count-1]) {
                    $name=$reader.LocalName
                    if ($reader.GetAttribute('item')) { $name=$reader.GetAttribute('item') }
                    if (-not $stack[$stack.Count-1].Add($name)) { throw 'KS_ATTEST_DUPLICATE_JSON_MEMBER' }
                }
                $frame=$null
                if ($reader.GetAttribute('type') -eq 'object') { $frame=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase) }
                if (-not $reader.IsEmptyElement) { $stack.Add($frame) }
            } elseif ($reader.NodeType -eq [Xml.XmlNodeType]::EndElement) { $stack.RemoveAt($stack.Count-1) }
        }
    } finally { $reader.Dispose() }
}

function Assert-Keys($Object,[string[]]$Names) {
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { throw 'KS_ATTEST_OBJECT_REQUIRED' }
    $actual=@($Object.PSObject.Properties.Name)
    if ($actual.Count -ne $Names.Count) { throw 'KS_ATTEST_SCHEMA_MEMBERS_INVALID' }
    foreach ($n in $Names) { if ($actual -cnotcontains $n) { throw 'KS_ATTEST_SCHEMA_MEMBERS_INVALID' } }
}
function Assert-Array($Value) { if ($null -eq $Value -or $Value -isnot [array] -or $Value.Count -gt 4096) { throw 'KS_ATTEST_ARRAY_INVALID' } }
function Test-Sha($Value,[int]$Length=64) { return ($Value -is [string] -and $Value -cmatch ('^[0-9a-fA-F]{'+$Length+'}$') -and $Value -notmatch '^0+$') }
function Assert-Relative([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Length -gt 200 -or $Path -match '[\\:%<>"|?*\x00-\x1f\x7f]' -or $Path.StartsWith('/')) { throw 'KS_ATTEST_UNSAFE_MANIFEST_PATH' }
    foreach ($p in $Path.Split('/')) {
        if ($p -in @('','.','..') -or $p -match '[. ]$' -or $p.Length -gt 255 -or $p -match '(?i)^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3]|CONIN\$|CONOUT\$)(?:\.|$)' -or $p -match '[\p{Cf}\p{Cs}]') { throw 'KS_ATTEST_UNSAFE_MANIFEST_PATH' }
    }
}
function Get-PathClass([string]$Path) {
    # Independent input boundary matching v1; no Git engine or dependency expansion.
    $ext=[regex]::Match($Path,'\.[^./]*$').Value.ToLowerInvariant()
    if ($Path -match '(?i)(?:^|/)(?:web\.config(?:\..*)?|[^/]*\.config|\.env[^/]*|[^/]*\.(?:pfx|p12|pem|key|snk|kdbx))(?:/|$)') { return 'EXCLUDED_CONFIGURATION_OR_KEY' }
    if ($Path -match '(?i)(?:^|/)(?:App_Data|uploads?|backups?|logs?|temp|tmp|\.git)(?:/|$)' -or $Path -match '(?i)^Database(?:[ /]|$)' -or $ext -in @('.sql','.dump','.bak','.zip','.7z','.gz','.pfx','.p12','.pem','.key','.snk','.cer','.crt')) { return 'EXCLUDED_DATA_OR_ARCHIVE' }
    if ($Path -match '(?i)^(?:Tools|docs|tests?|fixtures?|\.github|\.vscode)/' -or $Path -match '(?i)(?:^|/)(?:tests?|fixtures?)/' -or $Path -match '(?i)(?:\.test\.|^AGENTS\.md$|^\.[^/]+$)' -or $ext -in @('.md','.ps1','.psm1','.psd1','.pdb')) { return 'EXCLUDED_TOOLS_OR_DOCUMENTATION' }
    if ($Path -match '(?i)\.(?:aspx|master|ascx|ashx|asmx|asax)(?:\.vb)?$' -or $Path -match '(?i)^App_Code/.+\.vb$' -or $Path -match '(?i)^Bin/.+\.dll$' -or $Path -match '(?i)^App_(?:GlobalResources|LocalResources)/.+\.resx$' -or $Path -match '(?i)^App_Browsers/.+\.browser$') { return 'RUNTIME_WEB' }
    if ($Path -match '(?i)^Public/' -and $ext -in @('.css','.js','.png','.jpg','.jpeg','.gif','.svg','.webp','.avif','.ico','.bmp','.woff','.woff2','.ttf','.otf','.eot','.webmanifest')) { return 'RUNTIME_WEB' }
    if ($Path -cmatch '^(?:robots\.txt|sitemap\.xml)$') { return 'RUNTIME_WEB' }
    return 'UNKNOWN_REVIEW_REQUIRED'
}

function Get-ValidatedPlan([byte[]]$Bytes) {
    Assert-JsonMembers $Bytes
    $p=$script:Utf8.GetString($Bytes).TrimStart([char]0xfeff) | ConvertFrom-Json
    Assert-Keys $p @('Schema','Mode','PayloadCreated','Comparison','Summary','Changes','RuntimePaths','Dependencies','TreeIssues','DependencyLimits','DependencyCoverage','Target','BackupAndRollback','Gates','SourceAnalysis','ReleaseReadiness','PublicationAuthorized')
    if ($p.Schema -cne 'KeepStore.TenantReleasePlan.v1' -or $p.Mode -cne 'PLAN_ONLY' -or $p.PayloadCreated -isnot [bool] -or $p.PayloadCreated -or $p.PublicationAuthorized -isnot [bool] -or $p.PublicationAuthorized -or $p.ReleaseReadiness -cne 'BLOCKED_TARGET_NOT_VERIFIED' -or $p.SourceAnalysis -cnotin @('REVIEW_REQUIRED','COMPLETE_WITH_DECLARED_LIMITS')) { throw 'KS_ATTEST_PLAN_CONTRACT_INVALID' }
    Assert-Keys $p.Comparison @('FromCommit','ToCommit','BaselineMeaning','RenamePolicy','ContentSource')
    $length=([string]$p.Comparison.FromCommit).Length
    if ($length -notin @(40,64) -or -not (Test-Sha $p.Comparison.FromCommit $length) -or -not (Test-Sha $p.Comparison.ToCommit $length) -or $p.Comparison.BaselineMeaning -cne 'EXPLICIT_GIT_COMPARISON_NOT_INSTALLED_ATTESTATION' -or $p.Comparison.ContentSource -cne 'VERIFIED_GIT_BLOBS_NOT_WORKTREE' -or $p.Comparison.RenamePolicy -cne 'EXACT_BLOB_RENAMES_100_PERCENT_EDITED_MOVES_ARE_DELETE_PLUS_ADD') { throw 'KS_ATTEST_COMPARISON_INVALID' }
    foreach ($a in @('Changes','RuntimePaths','Dependencies','TreeIssues','DependencyLimits','Gates')) { Assert-Array $p.$a }
    if ($p.TreeIssues.Count) { throw 'KS_ATTEST_PLAN_TREE_ISSUES_REQUIRE_REVIEW' }
    $seen=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $prefixes=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $runtime=New-Object 'Collections.Generic.List[object]';$excluded=0
    foreach ($c in $p.Changes) {
        Assert-Keys $c @('Operation','Path','OldPath','Classification','Disposition','OldMode','NewMode','BeforeGitBlob','AfterGitBlob','BeforeSHA256','AfterSHA256','CaseOnlyRename','Issues','FutureAction')
        if ($c.Operation -cnotin @('ADDED','MODIFIED','DELETED','RENAMED') -or $c.Path -isnot [string] -or $c.CaseOnlyRename -isnot [bool] -or $c.CaseOnlyRename) { throw 'KS_ATTEST_CHANGE_INVALID' }
        Assert-Array $c.Issues
        if ($c.Issues.Count) { throw 'KS_ATTEST_BLOCKED_CHANGE' }
        $paths=@($c.Path)
        if ($c.Operation -eq 'RENAMED') { if ($c.OldPath -isnot [string]) { throw 'KS_ATTEST_RENAME_INVALID' };$paths+=@($c.OldPath) } elseif ($null -ne $c.OldPath) { throw 'KS_ATTEST_OLD_PATH_INVALID' }
        foreach ($path in $paths) {
            Assert-Relative $path
            if ((Get-PathClass $path) -cne $c.Classification -or $c.Classification -eq 'UNKNOWN_REVIEW_REQUIRED') { throw 'KS_ATTEST_PATH_CLASS_MISMATCH' }
            $key=$path.Normalize([Text.NormalizationForm]::FormC)
            if ($seen.ContainsKey($key)) { throw 'KS_ATTEST_PATH_COLLISION' };$seen.Add($key,$path)
            $prefix=''
            foreach ($part in $path.Split('/')) {
                $prefix=if($prefix){$prefix+'/'+$part}else{$part};$k=$prefix.Normalize([Text.NormalizationForm]::FormC)
                if ($prefixes.ContainsKey($k) -and $prefixes[$k] -cne $prefix) { throw 'KS_ATTEST_DIRECTORY_COLLISION' }
                if (-not $prefixes.ContainsKey($k)) { $prefixes.Add($k,$prefix) }
            }
        }
        $isRuntime=$c.Classification -ceq 'RUNTIME_WEB'
        $expectedDisposition=if($isRuntime){'CANDIDATE_PLAN_ONLY'}else{'EXCLUDED_FROM_TRANSFER'}
        if ($c.Disposition -cne $expectedDisposition) { throw 'KS_ATTEST_DISPOSITION_MISMATCH' }
        $oldPresent=$c.Operation -ne 'ADDED';$newPresent=$c.Operation -ne 'DELETED'
        foreach ($side in @(@('Before','Old',$oldPresent),@('After','New',$newPresent))) {
            $hash=$c.($side[0]+'SHA256');$blob=$c.($side[0]+'GitBlob');$mode=$c.($side[1]+'Mode')
            if ($side[2]) { if ($mode -cnotin @('100644','100755')) { throw 'KS_ATTEST_MODE_INVALID' } } elseif ($mode -cne '000000') { throw 'KS_ATTEST_MODE_INVALID' }
            if ($isRuntime -and $side[2]) { if (-not(Test-Sha $hash) -or -not(Test-Sha $blob $length)){throw 'KS_ATTEST_HASH_MISSING_OR_INVALID'} } elseif ($null -ne $hash -or $null -ne $blob) { throw 'KS_ATTEST_UNEXPECTED_HASH' }
        }
        $action=switch($c.Operation){'ADDED'{'VERIFY_DESTINATION_ABSENT_BEFORE_FUTURE_ADD'};'MODIFIED'{'VERIFY_BASELINE_HASH_AND_BACKUP_BEFORE_FUTURE_REPLACE'};'DELETED'{'VERIFY_ACTUAL_FILE_AND_BACKUP_SEPARATE_DELETE_APPROVAL'};'RENAMED'{'VERIFY_BOTH_PATHS_AND_BACKUP_SEPARATE_RENAME_APPROVAL'}}
        if ($c.FutureAction -cne $action) { throw 'KS_ATTEST_FUTURE_ACTION_INVALID' }
        if ($c.Operation -eq 'RENAMED' -and $isRuntime -and ($c.BeforeSHA256 -ine $c.AfterSHA256 -or $c.BeforeGitBlob -ine $c.AfterGitBlob)) { throw 'KS_ATTEST_EXACT_RENAME_INVALID' }
        if($isRuntime){$runtime.Add($c)}else{$excluded++}
    }
    foreach($path in $seen.Values){$prefix=$path;while($prefix.Contains('/')){$prefix=$prefix.Substring(0,$prefix.LastIndexOf('/'));if($seen.ContainsKey($prefix.Normalize([Text.NormalizationForm]::FormC))){throw 'KS_ATTEST_FILE_DIRECTORY_COLLISION'}}}
    if ($p.RuntimePaths.Count -ne $runtime.Count) { throw 'KS_ATTEST_RUNTIME_LIST_MISMATCH' }
    for($i=0;$i -lt $runtime.Count;$i++){if($p.RuntimePaths[$i] -isnot [string] -or $p.RuntimePaths[$i] -cne $runtime[$i].Path){throw 'KS_ATTEST_RUNTIME_LIST_MISMATCH'}}
    Assert-Keys $p.Summary @('GitChanges','RuntimeWebChanges','ExcludedChanges','BlockedChanges','TreeIssues','DirectDependencies')
    $counts=@{GitChanges=$p.Changes.Count;RuntimeWebChanges=$runtime.Count;ExcludedChanges=$excluded;BlockedChanges=0;TreeIssues=0;DirectDependencies=$p.Dependencies.Count}
    foreach($k in $counts.Keys){if($p.Summary.$k -isnot [int] -or $p.Summary.$k -ne $counts[$k]){throw 'KS_ATTEST_SUMMARY_MISMATCH'}}
    if ($p.Target.InstalledCommit.Status -cne 'UNKNOWN' -or $null -ne $p.Target.InstalledCommit.SHA -or $p.Target.PhysicalPath.Status -cne 'UNKNOWN' -or $null -ne $p.Target.PhysicalPath.Value -or $p.Target.CandidateCommit -cne $p.Comparison.ToCommit -or $p.Target.Approval -cne 'NOT_AUTHORIZED') { throw 'KS_ATTEST_TARGET_CONTRACT_INVALID' }
    return [pscustomobject]@{From=$p.Comparison.FromCommit.ToLowerInvariant();To=$p.Comparison.ToCommit.ToLowerInvariant();Runtime=$runtime;Excluded=$excluded;DependencyCount=$p.Dependencies.Count;SourceAnalysis=$p.SourceAnalysis}
}

function Get-Observation([string]$Path) {
    $chain=$null;$opened=$null;$stream=$null;$sha=$null
    try {
        $chain=Open-DirectoryChain ([IO.Path]::GetDirectoryName($Path))
        if($chain.State -ne 'OK'){return [pscustomobject]@{State=$chain.State;Reason=$chain.Reason;Hash=$null}}
        $opened=Open-ReadFile $Path
        if($opened.State -ne 'OK'){return [pscustomobject]@{State=$opened.State;Reason=$opened.Reason;Hash=$null}}
        if($opened.Metadata.Size -gt $script:MaxFileBytes -or $script:Clock.Elapsed.TotalSeconds -gt 120){throw 'RESOURCE_LIMIT'}
        $stream=New-Object IO.FileStream($opened.Handle,[IO.FileAccess]::Read,65536,$false)
        $buffer=New-Object byte[] 65536;$hashes=@();$watch=[Diagnostics.Stopwatch]::StartNew()
        for($pass=0;$pass -lt 2;$pass++){
            [void]$stream.Seek(0,[IO.SeekOrigin]::Begin);$sha=[Security.Cryptography.SHA256]::Create();$readTotal=0L
            while(($n=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
                $readTotal+=$n;$script:ReadBytes+=$n
                if($readTotal -gt $script:MaxFileBytes -or $script:ReadBytes -gt $script:MaxReadBytes -or $watch.Elapsed.TotalSeconds -gt 15 -or $script:Clock.Elapsed.TotalSeconds -gt 120){throw 'RESOURCE_LIMIT'}
                [void]$sha.TransformBlock($buffer,0,$n,$buffer,0)
            }
            [void]$sha.TransformFinalBlock($buffer,0,0);$hashes+=@([BitConverter]::ToString($sha.Hash).Replace('-',''));$sha.Dispose();$sha=$null
            $after=Get-HandleMetadata $opened.Handle
            if($readTotal -ne $opened.Metadata.Size -or $after.Size -ne $opened.Metadata.Size -or $after.Identity -cne $opened.Metadata.Identity -or $after.Stable -cne $opened.Metadata.Stable){throw 'OBSERVATION_CHANGED'}
        }
        if($hashes[0] -cne $hashes[1]){throw 'OBSERVATION_CHANGED'}
        return [pscustomobject]@{State='READ';Reason='TWO_PASSES_SAME_HANDLE_METADATA_STABLE';Hash=$hashes[0]}
    }catch{
        $reason=[string]$_.Exception.Message;if($reason -cnotin @('RESOURCE_LIMIT','OBSERVATION_CHANGED')){$reason='READ_NOT_COMPLETED'}
        return [pscustomobject]@{State='UNREADABLE';Reason=$reason;Hash=$null}
    }finally{if($sha){$sha.Dispose()};if($stream){$stream.Dispose()};if($opened -and $opened.Handle){$opened.Handle.Dispose()};Close-Chain $chain}
}

function Escape-Markdown([string]$Value){return [Net.WebUtility]::HtmlEncode($Value).Replace('|','&#124;').Replace('`','&#96;').Replace('[','&#91;').Replace(']','&#93;').Replace('\','&#92;')}

$rootChain=$null;$outputChain=$null
try {
    if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'KS_ATTEST_WINDOWS_POWERSHELL_51_REQUIRED' }
    if ($TargetLabel -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$') { throw 'KS_ATTEST_OPAQUE_LABEL_REQUIRED' }
    Initialize-ReadOnlyNative
    $planFile=Get-LocalAbsolute $PlanPath;$root=Get-LocalAbsolute $InspectionRoot;$output=Get-LocalAbsolute $OutputDirectory;$temp=Get-LocalAbsolute ([IO.Path]::GetTempPath())
    if ([IO.Path]::GetExtension($planFile) -ine '.json') { throw 'KS_ATTEST_JSON_INPUT_REQUIRED' }
    if (-not $output.StartsWith($temp.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or $output -eq $root -or $output.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'KS_ATTEST_NEW_DISJOINT_TEMP_OUTPUT_REQUIRED' }
    # Validate the complete plan before opening any InspectionRoot file.
    $planBytes=Read-PlanBytes $planFile;$plan=Get-ValidatedPlan $planBytes
    $planHasher=[Security.Cryptography.SHA256]::Create();try{$planHash=[BitConverter]::ToString($planHasher.ComputeHash($planBytes)).Replace('-','')}finally{$planHasher.Dispose()}
    $outputChain=Open-DirectoryChain ([IO.Path]::GetDirectoryName($output))
    if($outputChain.State -ne 'OK'){throw 'KS_ATTEST_OUTPUT_PARENT_UNSAFE'}
    if([IO.Directory]::Exists($output) -or [IO.File]::Exists($output)){throw 'KS_ATTEST_OUTPUT_EXISTS'}
    $rootChain=Open-DirectoryChain $root
    if($rootChain.State -ne 'OK'){throw 'KS_ATTEST_INSPECTION_ROOT_UNSAFE_OR_UNAVAILABLE'}
    $items=New-Object 'Collections.Generic.List[object]'
    foreach($c in $plan.Runtime){
        $sides=New-Object 'Collections.Generic.List[object]'
        if($c.Operation -eq 'RENAMED'){$sides.Add(@('ORIGIN',$c.OldPath,$c.BeforeSHA256,$null));$sides.Add(@('DESTINATION',$c.Path,$null,$c.AfterSHA256))}else{$sides.Add(@('PATH',$c.Path,$c.BeforeSHA256,$c.AfterSHA256))}
        foreach($side in $sides){
            $relative=[string]$side[1];$full=[IO.Path]::GetFullPath([IO.Path]::Combine($root,$relative.Replace('/','\')))
            if(-not $full.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'KS_ATTEST_CONTAINMENT_FAILED'}
            $observed=if($full.Length -gt 240){[pscustomobject]@{State='BLOCKED_UNSAFE_PATH';Reason='PATH_LENGTH_LIMIT';Hash=$null}}else{Get-Observation $full}
            $status=$observed.State
            if($status -eq 'READ'){$status=if($side[3] -and $observed.Hash -ieq $side[3]){'CANDIDATE_MATCH'}elseif($side[2] -and $observed.Hash -ieq $side[2]){'BASELINE_MATCH'}else{'DIFFERENT_UNKNOWN'}}
            $condition=if($status -in @('UNREADABLE','BLOCKED_UNSAFE_PATH')){'OBSERVATION_NOT_ESTABLISHED'}elseif($c.Operation -eq 'ADDED'){if($status -eq 'MISSING'){'ADDITION_ABSENT'}elseif($status -eq 'CANDIDATE_MATCH'){'ADDITION_ALREADY_PRESENT_CANDIDATE'}else{'ADDITION_PREEXISTING_COLLISION'}}elseif($c.Operation -eq 'DELETED'){if($status -eq 'MISSING'){'DELETION_ALREADY_ABSENT'}elseif($status -eq 'BASELINE_MATCH'){'DELETION_BASELINE_STILL_PRESENT'}else{'DELETION_UNRECOGNIZED_PRESENT'}}elseif($c.Operation -eq 'RENAMED'){if($side[0] -eq 'ORIGIN'){'RENAME_ORIGIN_OBSERVATION_ONLY'}else{'RENAME_DESTINATION_OBSERVATION_ONLY'}}else{'MODIFICATION_OBSERVATION_ONLY'}
            $items.Add([pscustomobject][ordered]@{Operation=$c.Operation;Role=$side[0];Path=$relative;Status=$status;Condition=$condition;ExpectedBaselineSHA256=$side[2];ExpectedCandidateSHA256=$side[3];ObservedSHA256=$observed.Hash;MatchesBothExpected=([bool]($observed.Hash -and $side[2] -and $side[3] -and $observed.Hash -ieq $side[2] -and $observed.Hash -ieq $side[3]));Evidence=$observed.Reason})
        }
    }
    $counts=[ordered]@{};foreach($s in @('CANDIDATE_MATCH','BASELINE_MATCH','MISSING','DIFFERENT_UNKNOWN','UNREADABLE','BLOCKED_UNSAFE_PATH')){$counts[$s]=@($items|Where-Object{$_.Status -ceq $s}).Count}
    $report=[ordered]@{
        Schema='KeepStore.TenantFileAttestation.v1';Mode='READ_ONLY_FILE_OBSERVATION';OverallStatus='TARGET_ATTESTATION_INCOMPLETE';PublicationAuthorized=$false
        Plan=[ordered]@{Schema='KeepStore.TenantReleasePlan.v1';SHA256=$planHash;FromCommit=$plan.From;ToCommit=$plan.To;SourceAnalysis=$plan.SourceAnalysis;DependencyCountNotInspected=$plan.DependencyCount;ExcludedChangesNotInspected=$plan.Excluded}
        Target=[ordered]@{Id=$TargetLabel;InstalledCommitStatus='UNKNOWN';InstalledCommit=$null;ApplicationIdentity='NOT_VERIFIED';DatabaseTopology='NOT_VERIFIED'}
        Observations=@($items.ToArray());Counts=$counts
        Limits=@('ONLY_EXPLICIT_ALLOWED_RUNTIME_CHANGE_PATHS_NO_RECURSIVE_INVENTORY','DEPENDENCIES_NOT_AUTOMATICALLY_INSPECTED','EXPECTED_HASHES_ASSERTED_BY_INPUT_PLAN_NOT_REVALIDATED_WITH_GIT','NO_WHOLE_FILESYSTEM_ATOMIC_SNAPSHOT_OR_COMMIT_INFERENCE','NORMAL_WRITE_DELETE_SHARING_DENIED_WHILE_HANDLES_OPEN_TWO_HASH_PASSES_AND_METADATA_COMPARED','OS_FILESYSTEM_READ_ACCESS_TIME_POLICY_NOT_CHANGED','128_MIB_PER_FILE_512_MIB_TOTAL_READ_15_SECONDS_PER_FILE_120_SECONDS_BETWEEN_OPERATIONS_NOT_NATIVE_IO_DEADLINES','EXCLUDED_CONTENTS_AND_UNLISTED_FILES_NOT_READ')
        OpenGates=@('COMPLETE_AUTHORIZED_INVENTORY','IIS_IDENTITY_AND_MAPPING','INSTALLED_COMMIT_INDEPENDENT_VERIFICATION','BACKUP_AND_RESTORE','DEPENDENCY_COMPATIBILITY_AND_APPLICATION_TESTS','TENANT_AND_DATABASE_CONTRACTS','RELEASE_AUTHORIZATION_AND_ROLLBACK')
    }
    $json=($report|ConvertTo-Json -Depth 12)+"`n"
    $lines=New-Object 'Collections.Generic.List[string]'
    foreach($line in @('# KeepStore - osservazione file','','READ ONLY - TARGET_ATTESTATION_INCOMPLETE',('Destinazione opaca: '+$TargetLabel),('Piano SHA256: '+$planHash),('FROM: '+$plan.From+'; TO: '+$plan.To),'','Solo percorsi runtime espliciti; nessun commit installato o rilascio certificato.','','| Operazione / ruolo | Percorso | Stato | Condizione | SHA256 osservato |','| --- | --- | --- | --- | --- |')){$lines.Add($line)}
    foreach($item in $items){$lines.Add('| '+$item.Operation+' / '+$item.Role+' | '+(Escape-Markdown $item.Path)+' | '+$item.Status+' | '+$item.Condition+' | '+$item.ObservedSHA256+' |')}
    $lines.Add('');foreach($k in $counts.Keys){$lines.Add('- '+$k+': '+$counts[$k])}
    $lines.Add('');$lines.Add('Hash attesi e osservati, inclusi eventuali match di entrambi gli hash, sono nel JSON. Due passate sul medesimo handle e metadati confrontati non certificano atomicita del filesystem. File assenti non sono autorizzazioni ad aggiungere/rimuovere; rinomine sono due osservazioni indipendenti. Configurazioni escluse e dipendenze non sono ispezionate.');$lines.Add('')
    foreach($limit in $report.Limits){$lines.Add('- '+$limit)};$lines.Add('');foreach($gate in $report.OpenGates){$lines.Add('- GATE APERTO: '+$gate)};$lines.Add('')
    # Only output files are created, with CreateNew. Ancestor handles remain open.
    [void](New-Item -ItemType Directory -Path $output -ErrorAction Stop)
    $newChain=Open-DirectoryChain $output
    try{
        if($newChain.State -ne 'OK'){throw 'KS_ATTEST_OUTPUT_DIRECTORY_UNSAFE'}
        foreach($artifact in @(@('attestation.json',$json),@('attestation.md',($lines -join "`n")))){
            $stream=[IO.File]::Open([IO.Path]::Combine($output,$artifact[0]),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try{$data=$script:Utf8.GetBytes($artifact[1]);$stream.Write($data,0,$data.Length)}finally{$stream.Dispose()}
        }
    }finally{Close-Chain $newChain}
    Write-Output ('KS_ATTEST_COMPLETE;Observed='+$items.Count+';Status=TARGET_ATTESTATION_INCOMPLETE')
}catch{
    $code=[string]$_.Exception.Message;if($code -cnotmatch '^KS_ATTEST_[A-Z0-9_]+$'){$code='KS_ATTEST_FAILED'}
    [Console]::Error.WriteLine($code);exit 1
}finally{Close-Chain $rootChain;Close-Chain $outputChain}
