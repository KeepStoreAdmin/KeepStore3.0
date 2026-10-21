[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$FromCommit,
    [Parameter(Mandatory=$true)][string]$ToCommit,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$TargetLabel = 'target-unverified'
)

# PLAN ONLY. No target path, installed-state attestation, payload, or apply mode.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$script:Utf8 = New-Object Text.UTF8Encoding($false, $true)
$script:BlobCache = @{}
$script:MaxBlobBytes = 33554432
$script:CachedBytes = 0L

function Assert-LocalPathChain([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\x00-\x1f]') { throw 'KS_RELEASE_LOCAL_ABSOLUTE_PATH_REQUIRED' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $drive = New-Object IO.DriveInfo($full.Substring(0,3))
    if ($drive.DriveType -eq [IO.DriveType]::Network) { throw 'KS_RELEASE_NETWORK_PATH_REJECTED' }
    $current = $full
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'KS_RELEASE_REPARSE_POINT_REJECTED' }
            if (-not $item.PSIsContainer) { throw 'KS_RELEASE_DIRECTORY_REQUIRED' }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $full
}

function Invoke-PlanGit([string[]]$Arguments, [byte[]]$InputBytes = $null, [switch]$AllowFailure) {
    $process = $null; $buffer = $null
    try {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $script:GitExecutable
        $info.WorkingDirectory = $script:Root
        $info.UseShellExecute = $false; $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
        $info.RedirectStandardInput = $true
        foreach ($name in @('GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR','GIT_INDEX_FILE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE')) { $info.EnvironmentVariables.Remove($name) }
        $info.EnvironmentVariables['GIT_OPTIONAL_LOCKS'] = '0'
        $info.EnvironmentVariables['GIT_NO_REPLACE_OBJECTS'] = '1'
        $info.EnvironmentVariables['GIT_NO_LAZY_FETCH'] = '1'
        $info.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
        $all = @('--no-lazy-fetch','--no-replace-objects','--no-pager','--literal-pathspecs') + $Arguments
        $info.Arguments = (@($all | ForEach-Object {
            $arg = [regex]::Replace([string]$_, '(\\*)"', '$1$1\"')
            $arg = [regex]::Replace($arg, '(\\+)$', '$1$1')
            '"' + $arg + '"'
        }) -join ' ')
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $info
        [void]$process.Start()
        $stderr = $process.StandardError.ReadToEndAsync()
        if ($null -ne $InputBytes) { $process.StandardInput.BaseStream.Write($InputBytes,0,$InputBytes.Length) }
        $process.StandardInput.Close()
        $buffer = New-Object IO.MemoryStream
        $chunk = New-Object byte[] 65536
        while (($read = $process.StandardOutput.BaseStream.Read($chunk,0,$chunk.Length)) -gt 0) {
            if ($buffer.Length + $read -gt $script:MaxBlobBytes) { throw 'KS_RELEASE_GIT_OUTPUT_LIMIT' }
            $buffer.Write($chunk,0,$read)
        }
        $process.WaitForExit(); [void]$stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -and -not $AllowFailure) { throw 'KS_RELEASE_GIT_READ_FAILED' }
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Bytes=$buffer.ToArray() }
    } finally {
        if ($buffer) { $buffer.Dispose() }
        if ($process) { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }; $process.Dispose() }
    }
}

function Get-GitText([string[]]$Arguments) {
    $result = Invoke-PlanGit $Arguments
    return $script:Utf8.GetString($result.Bytes)
}

function Get-PathProblems([string]$Path) {
    $problems = New-Object 'Collections.Generic.List[string]'
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('/') -or $Path -match '[\\:<>"|?*\x00-\x1f\x7f]') { $problems.Add('WINDOWS_INVALID_PATH') }
    if ($Path -match '(?i)%(?:2e|2f|5c)') { $problems.Add('ENCODED_PATH_REVIEW_REQUIRED') }
    foreach ($part in $Path.Split('/')) {
        if ($part -in @('','.','..') -or $part -match '[. ]$' -or $part.Length -gt 255) { $problems.Add('INVALID_PATH_SEGMENT') }
        if ($part -match '(?i)^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3]|CONIN\$|CONOUT\$)(?:\.|$)') { $problems.Add('WINDOWS_RESERVED_NAME') }
    }
    if ($Path.Length -gt 240) { $problems.Add('WINDOWS_PATH_LENGTH_REVIEW_REQUIRED') }
    return @($problems.ToArray() | Select-Object -Unique)
}

function Get-PathClass([string]$Path) {
    # Reuses the historical collector's deny-first scope; no tenant allowlist.
    $ext = [regex]::Match($Path,'\.[^./]*$').Value.ToLowerInvariant()
    if ($Path -match '(?i)(?:^|/)(?:web\.config(?:\..*)?|[^/]*\.config|\.env[^/]*|[^/]*\.(?:pfx|p12|pem|key|snk|kdbx))(?:/|$)') { return 'EXCLUDED_CONFIGURATION_OR_KEY' }
    if ($Path -match '(?i)(?:^|/)(?:App_Data|uploads?|backups?|logs?|temp|tmp|\.git)(?:/|$)' -or $Path -match '(?i)^Database(?:[ /]|$)' -or $ext -in @('.sql','.dump','.bak','.zip','.7z','.gz','.pfx','.p12','.pem','.key','.snk','.cer','.crt')) { return 'EXCLUDED_DATA_OR_ARCHIVE' }
    if ($Path -match '(?i)^(?:Tools|docs|tests?|fixtures?|\.github|\.vscode)/' -or $Path -match '(?i)(?:^|/)(?:tests?|fixtures?)/' -or $Path -match '(?i)(?:\.test\.|^AGENTS\.md$|^\.[^/]+$)' -or $ext -in @('.md','.ps1','.psm1','.psd1','.pdb')) { return 'EXCLUDED_TOOLS_OR_DOCUMENTATION' }
    if ($Path -match '(?i)\.(?:aspx|master|ascx|ashx|asmx|asax)(?:\.vb)?$') { return 'RUNTIME_WEB' }
    if ($Path -match '(?i)^App_Code/.+\.vb$' -or $Path -match '(?i)^Bin/.+\.dll$') { return 'RUNTIME_WEB' }
    if ($Path -match '(?i)^App_(?:GlobalResources|LocalResources)/.+\.resx$' -or $Path -match '(?i)^App_Browsers/.+\.browser$') { return 'RUNTIME_WEB' }
    if ($Path -match '(?i)^Public/' -and $ext -in @('.css','.js','.png','.jpg','.jpeg','.gif','.svg','.webp','.avif','.ico','.bmp','.woff','.woff2','.ttf','.otf','.eot','.webmanifest')) { return 'RUNTIME_WEB' }
    if ($Path -cmatch '^(?:robots\.txt|sitemap\.xml)$') { return 'RUNTIME_WEB' }
    return 'UNKNOWN_REVIEW_REQUIRED'
}

function Get-Tree([string]$Commit) {
    $tree = New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $raw = Get-GitText @('ls-tree','-r','-z','--full-tree',$Commit)
    foreach ($record in $raw.Split([char]0)) {
        if ($record -eq '') { continue }
        if ($record -notmatch '^(?<mode>[0-7]{6}) (?<type>blob|commit) (?<oid>[0-9a-f]{40,64})\t(?<path>[\s\S]+)$') { throw 'KS_RELEASE_TREE_METADATA_INVALID' }
        $tree.Add($Matches.path,[pscustomobject]@{ Path=$Matches.path; Mode=$Matches.mode; Type=$Matches.type; Oid=$Matches.oid })
    }
    return ,$tree
}

function Get-TreeIssues($Tree, [string]$Side) {
    $seen = New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $keys = [string[]]@($Tree.Keys); [Array]::Sort($keys,[StringComparer]::Ordinal)
    foreach ($path in $keys) {
        $parts = $path.Split('/'); $prefix = ''
        foreach ($part in $parts) {
            $prefix = if ($prefix) { $prefix+'/'+$part } else { $part }
            $key = $prefix.Normalize([Text.NormalizationForm]::FormC)
            if ($seen.ContainsKey($key) -and $seen[$key] -cne $prefix) {
                [pscustomobject]@{ Side=$Side; Code='WINDOWS_CASE_OR_NORMALIZATION_COLLISION'; Path=$prefix; OtherPath=$seen[$key] }
            } elseif (-not $seen.ContainsKey($key)) { $seen.Add($key,$prefix) }
        }
    }
}

function Read-RawChanges([string[]]$Arguments) {
    $raw = Get-GitText $Arguments
    if (-not $raw) { return }
    $fields = $raw.Split([char]0); $i=0
    while ($i -lt $fields.Length-1) {
        $meta = $fields[$i++]
        if ($meta -notmatch '^:(?<oldMode>[0-7]{6}) (?<newMode>[0-7]{6}) (?<old>[0-9a-f]{40,64}) (?<new>[0-9a-f]{40,64}) (?<status>[AMDRT])(?<score>[0-9]*)$') { throw 'KS_RELEASE_DIFF_METADATA_INVALID' }
        $m = $Matches.Clone(); $path=$fields[$i++]; $oldPath=$path
        if ($m.status -eq 'R') { $path=$fields[$i++] }
        [pscustomobject]@{ Status=$m.status; OldPath=$oldPath; Path=$path; OldMode=$m.oldMode; NewMode=$m.newMode; OldOid=$m.old; NewOid=$m.new; Score=$m.score }
    }
    if ($fields[$fields.Length-1] -ne '') { throw 'KS_RELEASE_DIFF_TERMINATOR_INVALID' }
}

function Get-BlobInfo($Entry) {
    if ($null -eq $Entry -or $Entry.Mode -notin @('100644','100755') -or $Entry.Type -ne 'blob') { throw 'KS_RELEASE_NONREGULAR_BLOB_REJECTED' }
    if (-not $script:BlobCache.ContainsKey($Entry.Oid)) {
        $result = Invoke-PlanGit @('cat-file','blob',$Entry.Oid)
        $bytes = $result.Bytes
        if ($script:CachedBytes + $bytes.Length -gt 134217728) { throw 'KS_RELEASE_BLOB_CACHE_LIMIT' }
        $sha = [Security.Cryptography.SHA256]::Create()
        $objectHasher = if ($Entry.Oid.Length -eq 40) { [Security.Cryptography.SHA1]::Create() } else { [Security.Cryptography.SHA256]::Create() }
        try {
            $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')
            $header = $script:Utf8.GetBytes('blob '+$bytes.Length+[char]0)
            [void]$objectHasher.TransformBlock($header,0,$header.Length,$header,0)
            [void]$objectHasher.TransformFinalBlock($bytes,0,$bytes.Length)
            if ([BitConverter]::ToString($objectHasher.Hash).Replace('-','').ToLowerInvariant() -cne $Entry.Oid) { throw 'KS_RELEASE_BLOB_ID_MISMATCH' }
            $script:BlobCache[$Entry.Oid] = [pscustomobject]@{ SHA256=$hash; Bytes=$bytes }
            $script:CachedBytes += $bytes.Length
        } finally { $sha.Dispose(); $objectHasher.Dispose() }
    }
    return $script:BlobCache[$Entry.Oid]
}

function Resolve-SourceReference([string]$Source, [string]$Reference) {
    $ref = ($Reference -split '[?#]',2)[0]
    if ($ref -match '^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)' -or $ref -eq '') { return $null }
    if ($ref -match '[%\\]' -or $ref.Contains('<%')) { return $null }
    $parts = New-Object 'Collections.Generic.List[string]'
    if (-not $ref.StartsWith('/') -and -not $ref.StartsWith('~/')) {
        $slash=$Source.LastIndexOf('/'); if ($slash -ge 0) { foreach($part in $Source.Substring(0,$slash).Split('/')) { $parts.Add($part) } }
    }
    foreach ($part in ($ref -replace '^~?/','').Split('/')) {
        if ($part -in @('','.')) { continue }
        if ($part -eq '..') { if ($parts.Count -eq 0) { return $null }; $parts.RemoveAt($parts.Count-1) } else { $parts.Add($part) }
    }
    $resolved = $parts -join '/'
    if (@(Get-PathProblems $resolved).Count) { return $null }
    return $resolved
}

function Add-Dependency([string]$Source,[string]$Path,[string]$Kind,[bool]$CacheBuster=$false) {
    $key=$Source+'|'+$Kind+'|'+$Path
    if (-not $script:DependencyKeys.Add($key)) { return }
    $entry=$null; $hash=$null; $state='MISSING_IN_SOURCE'; $oid=$null
    if ($script:ToTree.ContainsKey($Path)) {
        $entry=$script:ToTree[$Path]
        if ((Get-PathClass $Path) -ne 'RUNTIME_WEB' -or @(Get-PathProblems $Path).Count -or $entry.Mode -notin @('100644','100755')) { $state='BLOCKED_NOT_READ' }
        else { $state='SOURCE_PRESENT'; $hash=(Get-BlobInfo $entry).SHA256; $oid=$entry.Oid }
    }
    $script:Dependencies.Add([pscustomobject][ordered]@{ Source=$Source; Path=$Path; Kind=$Kind; Resolution=$state; InDelta=$script:ChangedPaths.Contains($Path); GitBlob=$oid; SHA256=$hash; CacheBusterPresent=$CacheBuster; TargetStatus='NOT_VERIFIED' })
}

function Find-DirectDependencies($Change) {
    $path=$Change.Path
    if ($path -match '(?i)\.(?:aspx|master|ascx|ashx|asmx|asax)\.vb$') { Add-Dependency $path $path.Substring(0,$path.Length-3) 'MARKUP_PAIR' }
    if ($Change.Operation -eq 'DELETED' -or $path -notmatch '(?i)\.(?:aspx|master|ascx|ashx|asmx|asax|css|js)$') { return }
    if ($path -match '(?i)\.js$') { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='JAVASCRIPT_RUNTIME_REFERENCES_REQUIRE_REVIEW'}); return }
    $bytes=(Get-BlobInfo $script:ToTree[$path]).Bytes
    if ($bytes.Length -gt 2097152) { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='DIRECT_SCAN_SIZE_LIMIT'}); return }
    try { $text=$script:Utf8.GetString($bytes) } catch { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='NON_UTF8_DIRECT_SCAN_REQUIRES_REVIEW'}); return }
    $isMarkup=$path -match '(?i)\.(?:aspx|master|ascx|ashx|asmx|asax)$'
    if ($isMarkup) {
    foreach ($match in [regex]::Matches($text,'(?is)<%@\s*(?:Page|Master|Control|Register|WebHandler|WebService)\b.*?%>')) {
        foreach ($attr in [regex]::Matches($match.Value,'(?i)\b(CodeFile|CodeBehind|MasterPageFile|Src)\s*=\s*["'']([^"'']+)["'']')) {
            $resolved=Resolve-SourceReference $path $attr.Groups[2].Value
            if ($resolved) { Add-Dependency $path $resolved ('WEBFORMS_'+$attr.Groups[1].Value.ToUpperInvariant()) }
            else { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='UNRESOLVED_DIRECTIVE_REFERENCE'}) }
        }
    }
    foreach ($match in [regex]::Matches($text,'(?i)ThemeManager\.Asset\(\s*["'']([^"'']+)["'']\s*\)')) {
        $suffix=$match.Groups[1].Value
        $found=$false
        $tailStart=$match.Index+$match.Length
        $tail=$text.Substring($tailStart,[Math]::Min(160,$text.Length-$tailStart))
        $hasCacheBuster=$tail -match '^\s*(?:&\s*["'']|%>)\?v='
        if (@(Get-PathProblems $suffix).Count -eq 0) {
            $keys=[string[]]@($script:ToTree.Keys); [Array]::Sort($keys,[StringComparer]::Ordinal)
            foreach ($candidate in $keys) {
                if ($candidate -cmatch ('^Public/assets/[^/]+/'+[regex]::Escape($suffix)+'$')) { Add-Dependency $path $candidate 'THEME_MANAGER_ASSET' $hasCacheBuster; $found=$true }
            }
        }
        if (-not $found) { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='THEME_ASSET_NOT_RESOLVED'}) }
    }
    foreach ($match in [regex]::Matches($text,'(?is)<(?:script|link|img|source)\b[^>]*?\b(?:src|href)\s*=\s*(["''])(.*?)\1')) {
        $value=$match.Groups[2].Value
        if ($value.Contains('<%')) {
            if ($value -notmatch 'ThemeManager\.Asset\(') { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='DYNAMIC_MARKUP_REFERENCE_REQUIRES_REVIEW'}) }
            continue
        }
        $resolved=Resolve-SourceReference $path $value
        if ($resolved) { Add-Dependency $path $resolved 'STATIC_WEB_REFERENCE' ($value -match '\?v=') }
        elseif ($value -and $value -notmatch '^(?:data:|#)') { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='EXTERNAL_OR_DYNAMIC_REFERENCE_NOT_FETCHED'}) }
    }
    }
    if ($path -match '(?i)\.css$') {
        foreach ($match in [regex]::Matches($text,'(?i)url\(\s*["'']?([^"'')\s]+)["'']?\s*\)')) {
            $value=$match.Groups[1].Value; $resolved=Resolve-SourceReference $path $value
            if ($resolved) { Add-Dependency $path $resolved 'CSS_URL' ($value -match '\?v=') }
            elseif ($value -and $value -notmatch '^(?:data:|#)') { $script:DependencyLimits.Add([pscustomobject]@{Source=$path;Code='CSS_REFERENCE_NOT_RESOLVED'}) }
        }
    }
}

function Escape-PlanMarkdown([string]$Value) {
    # Repo names are untrusted Markdown, not commands, links, HTML, or directives.
    return [Net.WebUtility]::HtmlEncode($Value).Replace('|','&#124;').Replace('`','&#96;').Replace('[','&#91;').Replace(']','&#93;').Replace('\','&#92;').Replace("`r",'&#13;').Replace("`n",'&#10;')
}

try {
    if ($TargetLabel -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$') { throw 'KS_RELEASE_OPAQUE_LABEL_REQUIRED' }
    $script:Root=Assert-LocalPathChain $RepoRoot
    if (-not (Test-Path -LiteralPath $script:Root -PathType Container)) { throw 'KS_RELEASE_REPOSITORY_MISSING' }
    $script:GitExecutable=@(Get-Command git.exe -CommandType Application -ErrorAction Stop)[0].Source
    $top=(Get-GitText @('rev-parse','--show-toplevel')).Trim()
    if (-not [string]::Equals([IO.Path]::GetFullPath($top).TrimEnd('\','/'),$script:Root,[StringComparison]::OrdinalIgnoreCase)) { throw 'KS_RELEASE_REPO_ROOT_REQUIRED' }
    foreach ($sha in @($FromCommit,$ToCommit)) { if ($sha -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') { throw 'KS_RELEASE_FULL_COMMIT_SHA_REQUIRED' } }
    $from=(Get-GitText @('rev-parse','--verify',($FromCommit+'^{commit}'))).Trim()
    $to=(Get-GitText @('rev-parse','--verify',($ToCommit+'^{commit}'))).Trim()
    if ($from -cne $FromCommit.ToLowerInvariant() -or $to -cne $ToCommit.ToLowerInvariant()) { throw 'KS_RELEASE_EXACT_COMMIT_REQUIRED' }
    $ancestor=Invoke-PlanGit @('merge-base','--is-ancestor',$from,$to) -AllowFailure
    if ($ancestor.ExitCode -ne 0) { throw 'KS_RELEASE_BASE_NOT_ANCESTOR' }
    $output=Assert-LocalPathChain $OutputDirectory
    $temp=(Assert-LocalPathChain ([IO.Path]::GetTempPath())).TrimEnd('\')
    if (-not $output.StartsWith($temp+'\',[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($script:Root+'\',[StringComparison]::OrdinalIgnoreCase) -or $output -eq $script:Root) { throw 'KS_RELEASE_NEW_TEMP_OUTPUT_REQUIRED' }
    if (Test-Path -LiteralPath $output) { throw 'KS_RELEASE_OUTPUT_ALREADY_EXISTS' }
    if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($output)) -PathType Container)) { throw 'KS_RELEASE_OUTPUT_PARENT_MISSING' }

    $fromTree=Get-Tree $from; $script:ToTree=Get-Tree $to
    $treeIssues=@(Get-TreeIssues $fromTree 'FROM') + @(Get-TreeIssues $script:ToTree 'TO')
    # Exact renames need object metadata only, including excluded paths: never read configuration blobs.
    $diffArgs=@('diff-tree','-r','--no-commit-id','--raw','-z','--no-abbrev','--no-ext-diff','--no-textconv','--find-renames=100%',$from,$to,'--')
    $rawChanges=@(Read-RawChanges $diffArgs)
    $changes=New-Object 'Collections.Generic.List[object]'
    $script:ChangedPaths=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($r in $rawChanges) {
        [void]$script:ChangedPaths.Add($r.Path)
        $class=Get-PathClass $r.Path; $oldClass=Get-PathClass $r.OldPath
        $issues=@(Get-PathProblems $r.Path) + @(Get-PathProblems $r.OldPath)
        foreach ($t in $treeIssues) {
            foreach ($affected in @($r.Path,$r.OldPath)) {
                $normalized=$affected.Normalize([Text.NormalizationForm]::FormC)
                $collision=$t.Path.Normalize([Text.NormalizationForm]::FormC)
                if ([string]::Equals($normalized,$collision,[StringComparison]::OrdinalIgnoreCase) -or $normalized.StartsWith($collision+'/',[StringComparison]::OrdinalIgnoreCase)) { $issues+=@('WINDOWS_TREE_COLLISION_REQUIRES_REVIEW') }
            }
        }
        $caseRename=$r.Status -eq 'R' -and [string]::Equals($r.Path,$r.OldPath,[StringComparison]::OrdinalIgnoreCase)
        if ($caseRename) { $issues+=@('WINDOWS_CASE_ONLY_RENAME_REQUIRES_MANUAL_PLAN') }
        foreach ($mode in @($r.OldMode,$r.NewMode)) { if ($mode -notin @('000000','100644','100755')) { $issues+=@('SYMLINK_SUBMODULE_OR_UNSUPPORTED_TYPE') } }
        if ($r.Status -eq 'T') { $issues+=@('GIT_TYPE_CHANGE_REQUIRES_REVIEW') }
        if ($r.Status -eq 'R' -and $oldClass -cne $class) { $issues+=@('RENAME_CROSSES_CLASSIFICATION_BOUNDARY') }
        $disposition=if ($issues.Count -or $class -eq 'UNKNOWN_REVIEW_REQUIRED') { 'BLOCKED_REVIEW_REQUIRED' } elseif ($class -eq 'RUNTIME_WEB') { 'CANDIDATE_PLAN_ONLY' } else { 'EXCLUDED_FROM_TRANSFER' }
        $before=$null; $after=$null; $oldOid=$null; $newOid=$null
        if ($class -eq 'RUNTIME_WEB' -and $oldClass -eq 'RUNTIME_WEB' -and @($issues|Where-Object {$_ -ne 'WINDOWS_CASE_ONLY_RENAME_REQUIRES_MANUAL_PLAN'}).Count -eq 0) {
            if ($r.Status -ne 'A') { $oldOid=$r.OldOid; $before=(Get-BlobInfo $fromTree[$r.OldPath]).SHA256 }
            if ($r.Status -ne 'D') { $newOid=$r.NewOid; $after=(Get-BlobInfo $script:ToTree[$r.Path]).SHA256 }
        }
        $op=@{A='ADDED';M='MODIFIED';D='DELETED';R='RENAMED';T='TYPE_CHANGED'}[$r.Status]
        $action=switch ($op) {
            'ADDED' {'VERIFY_DESTINATION_ABSENT_BEFORE_FUTURE_ADD'}
            'MODIFIED' {'VERIFY_BASELINE_HASH_AND_BACKUP_BEFORE_FUTURE_REPLACE'}
            'DELETED' {'VERIFY_ACTUAL_FILE_AND_BACKUP_SEPARATE_DELETE_APPROVAL'}
            'RENAMED' {'VERIFY_BOTH_PATHS_AND_BACKUP_SEPARATE_RENAME_APPROVAL'}
            default {'MANUAL_REVIEW_NO_TRANSFER'}
        }
        $changes.Add([pscustomobject][ordered]@{Operation=$op;Path=$r.Path;OldPath=$(if($r.Status -eq 'R'){$r.OldPath}else{$null});Classification=$class;Disposition=$disposition;OldMode=$r.OldMode;NewMode=$r.NewMode;BeforeGitBlob=$oldOid;AfterGitBlob=$newOid;BeforeSHA256=$before;AfterSHA256=$after;CaseOnlyRename=$caseRename;Issues=@($issues|Select-Object -Unique);FutureAction=$action})
    }
    $script:Dependencies=New-Object 'Collections.Generic.List[object]'
    $script:DependencyKeys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $script:DependencyLimits=New-Object 'Collections.Generic.List[object]'
    foreach ($change in $changes) { if ($change.Classification -eq 'RUNTIME_WEB' -and $change.Disposition -eq 'CANDIDATE_PLAN_ONLY') { Find-DirectDependencies $change } }
    $runtime=@($changes|Where-Object {$_.Classification -eq 'RUNTIME_WEB'})
    $blocked=@($changes|Where-Object {$_.Disposition -eq 'BLOCKED_REVIEW_REQUIRED'})
    $depBlocked=@($script:Dependencies|Where-Object {$_.Resolution -ne 'SOURCE_PRESENT'})
    $sourceReview=$blocked.Count -gt 0 -or $treeIssues.Count -gt 0 -or $depBlocked.Count -gt 0 -or $script:DependencyLimits.Count -gt 0
    $gates=@(
        'TARGET_APPLICATION_IDENTITY_AND_PHYSICAL_PATH', 'INSTALLED_COMMIT_AND_FILE_HASH_ATTESTATION',
        'EXPLICIT_TARGET_AND_DEPLOYMENT_AUTHORIZATION', 'PRIVATE_CONFIGURATION_AND_TENANT_ASSET_PRESERVATION',
        'BACKUP_HASH_ACL_METADATA_AND_RESTORE_REHEARSAL', 'WEBFORMS_APPCODE_BIN_COMPATIBILITY_AND_COMPILE',
        'DIRECT_AND_DYNAMIC_DEPENDENCY_REVIEW_ACTIVE_THEME_AND_CACHE_BUSTERS', 'DATABASE_SCHEMA_AND_MIGRATION_ASSESSMENT_NO_IMPLICIT_APPLY',
        'INPROC_SESSIONS_CALLBACKS_AND_JOBS_WINDOW', 'ANONYMOUS_AUTHENTICATED_COMMERCIAL_AND_TENANT_SMOKE',
        'TLS_AND_TARGET_SPECIFIC_SECURITY_GATES', 'ROLLBACK_VALIDATION_AND_POST_PUBLICATION_HASHES'
    ) | ForEach-Object {[pscustomobject][ordered]@{Code=$_;Status='OPEN_NOT_VERIFIED'}}
    $plan=[ordered]@{
        Schema='KeepStore.TenantReleasePlan.v1';Mode='PLAN_ONLY';PayloadCreated=$false
        Comparison=[ordered]@{FromCommit=$from;ToCommit=$to;BaselineMeaning='EXPLICIT_GIT_COMPARISON_NOT_INSTALLED_ATTESTATION';RenamePolicy='EXACT_BLOB_RENAMES_100_PERCENT_EDITED_MOVES_ARE_DELETE_PLUS_ADD';ContentSource='VERIFIED_GIT_BLOBS_NOT_WORKTREE'}
        Summary=[ordered]@{GitChanges=$changes.Count;RuntimeWebChanges=$runtime.Count;ExcludedChanges=@($changes|Where-Object {$_.Disposition -eq 'EXCLUDED_FROM_TRANSFER'}).Count;BlockedChanges=$blocked.Count;TreeIssues=$treeIssues.Count;DirectDependencies=$script:Dependencies.Count}
        Changes=@($changes.ToArray());RuntimePaths=@($runtime|ForEach-Object {$_.Path});Dependencies=@($script:Dependencies.ToArray());TreeIssues=@($treeIssues);DependencyLimits=@($script:DependencyLimits.ToArray())
        DependencyCoverage=[ordered]@{Scope='DIRECT_LITERAL_WEBFORMS_PAIRS_STATIC_ASSET_REFERENCES_AND_TRACKED_THEME_VARIANTS';RecursiveClosure=$false;AppCodeAndBin='GLOBAL_COMPILATION_GATE_NOT_INFERRED_CLASS_GRAPH';DynamicCodeAndConfiguration='MANUAL_REVIEW_REQUIRED';UnchangedDependencies='VERIFY_INSTALLED_COMPATIBILITY_NOT_AUTOMATIC_TRANSFER';CacheBusters='PRESENCE_RECORDED_VALUES_AND_ACTIVE_THEME_REQUIRE_REVIEW'}
        Target=[ordered]@{Id=$TargetLabel;Environment='UNKNOWN';InstalledCommit=[ordered]@{Status='UNKNOWN';SHA=$null};CandidateCommit=$to;PhysicalPath=[ordered]@{Status='UNKNOWN';Value=$null};ApplicationIdentity='UNKNOWN';DatabaseTopology='UNKNOWN_SHARED_OR_INDEPENDENT';TenantBrandingAndAssets='NOT_VERIFIED';Approval='NOT_AUTHORIZED';Backup='NOT_VERIFIED';Compilation='NOT_EXECUTED';Smoke='NOT_EXECUTED';DatabaseMigrations='NOT_ASSESSED_NOT_EXECUTED';Rollback='NOT_VERIFIED';Publication='NOT_EXECUTED';EvidenceReferences=@()}
        BackupAndRollback=[ordered]@{Before='Verify actual baseline or recognized state; encrypted backup outside webroot/repository; record absence, SHA256, ACL, attributes, dates for each affected file and both rename paths.';PrivateFiles='Preserve configuration, keys, tenant assets, data, uploads, logs, ignored and untracked files; no content collected.';Apply='Future separately authorized operation only; apply dependency groups together; no executable copy/delete/restart commands in this plan.';Added='Only after actual absence attestation; future rollback removal needs explicit authorization and recorded initial absence.';ModifiedDeletedRenamed='Restore verified complete affected group and metadata; unknown target hash blocks replacement/removal.';Database='Git/file rollback cannot restore database, credentials or operational transactions; separate DB recovery contract required.';After='Verify candidate hashes and target smoke; on rollback verify original hashes, metadata and preserved private state.'}
        Gates=@($gates);SourceAnalysis=$(if($sourceReview){'REVIEW_REQUIRED'}else{'COMPLETE_WITH_DECLARED_LIMITS'});ReleaseReadiness='BLOCKED_TARGET_NOT_VERIFIED';PublicationAuthorized=$false
    }
    $json=($plan|ConvertTo-Json -Depth 12)+"`n"
    $lines=New-Object 'Collections.Generic.List[string]'
    foreach($line in @('# KeepStore - piano offline di rilascio','','PLAN ONLY - nessun payload, accesso al target o autorizzazione di pubblicazione.',('Confronto: '+$from+' -> '+$to),('Destinazione opaca: '+(Escape-PlanMarkdown $TargetLabel)),('Git: '+$changes.Count+'; runtime web: '+$runtime.Count+'; esclusi: '+$plan.Summary.ExcludedChanges+'; bloccati: '+$blocked.Count),('Analisi sorgente: '+$plan.SourceAnalysis+'; readiness target: BLOCKED_TARGET_NOT_VERIFIED.'),'','Il FROM e una baseline di confronto: commit installato e physical path restano UNKNOWN.','','| Operazione | Percorso | Origine rinomina | Classe / stato | SHA256 candidato |','| --- | --- | --- | --- | --- |')){$lines.Add($line)}
    foreach($c in $changes){$lines.Add('| '+$c.Operation+' | '+(Escape-PlanMarkdown $c.Path)+' | '+(Escape-PlanMarkdown $c.OldPath)+' | '+$c.Classification+' / '+$c.Disposition+' | '+$c.AfterSHA256+' |')}
    $lines.Add('');$lines.Add('Dipendenze dirette (nessuna chiusura transitiva automatica):')
    foreach($d in $script:Dependencies){$lines.Add('- '+(Escape-PlanMarkdown $d.Source)+' -> '+(Escape-PlanMarkdown $d.Path)+' ['+$d.Kind+'; '+$d.Resolution+'; target NOT_VERIFIED]')}
    $lines.Add('');$lines.Add('Problemi dei percorsi e limiti da riesaminare:')
    foreach($c in $blocked){$lines.Add('- '+(Escape-PlanMarkdown $c.Path)+': '+($c.Issues -join ', ')+$(if($c.Classification -eq 'UNKNOWN_REVIEW_REQUIRED'){' UNKNOWN_REVIEW_REQUIRED'}else{''}))}
    foreach($t in $treeIssues){$lines.Add('- '+$t.Code+' '+$t.Side+': '+(Escape-PlanMarkdown $t.Path)+' / '+(Escape-PlanMarkdown $t.OtherPath))}
    foreach($d in $script:DependencyLimits){$lines.Add('- '+(Escape-PlanMarkdown $d.Source)+': '+$d.Code)}
    $lines.Add('');$lines.Add('Backup e rollback futuri, non eseguiti:')
    foreach($entry in $plan.BackupAndRollback.GetEnumerator()){$lines.Add('- '+$entry.Key+': '+$entry.Value)}
    $lines.Add('');$lines.Add('Gate target aperti per questa destinazione:')
    foreach($g in $gates){$lines.Add('- '+$g.Code+': '+$g.Status)}
    $lines.Add('');$lines.Add('Nessuna configurazione/untracked letta; file esclusi senza hash di contenuto. Rinomine esatte tramite metadata Git; spostamenti con modifica restano DELETE + ADD e richiedono review. Symlink, submodule, percorsi ambigui e tipi ignoti sono bloccati. Hash corretti non attestano installazione o correttezza commerciale.');$lines.Add('')
    $markdown=$lines -join "`n"
    [void](New-Item -ItemType Directory -Path $output -ErrorAction Stop)
    [void](Assert-LocalPathChain $output)
    foreach($artifact in @(@('plan.json',$json),@('plan.md',$markdown))){
        $stream=[IO.File]::Open([IO.Path]::Combine($output,$artifact[0]),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$data=$script:Utf8.GetBytes($artifact[1]);$stream.Write($data,0,$data.Length)}finally{$stream.Dispose()}
    }
    Write-Output ('KS_RELEASE_PLAN_COMPLETE;Git='+$changes.Count+';Runtime='+$runtime.Count+';Target=BLOCKED')
} catch {
    $code=[string]$_.Exception.Message
    if($code -notmatch '^KS_RELEASE_[A-Z_]+$'){$code='KS_RELEASE_PLAN_FAILED'}
    [Console]::Error.WriteLine($code)
    exit 1
}
