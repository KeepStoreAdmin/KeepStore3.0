[CmdletBinding()]
param([string]$RepositoryRoot)
# ORDER-CHAIN-UNIVERSAL-1A: static source checks of the four universal migration files (no database connection).
# Behavioural proof on the local LAB (shadow routines Carrello_Documento_UniLab / Carrello_Totali_UniLab): preflight, forward, verify,
# rollback from the final state and from the partial states (Carrello_Totali only, Carrello_Documento missing), forward again, refusal cases,
# Tools/Test-OrderSqlMatrixLab.ps1 -Procedure -TotaliProcedure and -FooterDump (footers identical to the real LAB routine at the same code level).
# This test also mutates the sources and requires every mutation to be caught.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('ORDER_CHAIN_TEST_FAILED: ' + $Name) }
    $script:checks++
}
function Read-Lf([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) ('file exists: ' + $RelativePath)
    ([IO.File]::ReadAllText($path).Replace("`r`n", "`n")).Replace("`r", "`n")
}
function Get-Sha256([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
# Body of a CREATE ... PROCEDURE `name` ... from the line "BEGIN" to the closing line "    END" (the text the server stores).
function Get-Body([string]$Sql, [string]$Name) {
    $pattern = '(?ms)^CREATE DEFINER=__KEEPSTORE_[A-Z_]+__ PROCEDURE `' + [regex]::Escape($Name) + '`\(.*?^(BEGIN\n.*?\n    END)(?:\n|\$\$)'
    $m = [regex]::Match($Sql, $pattern)
    if (-not $m.Success) { return $null }
    $m.Groups[1].Value
}
$docFinalHash = '7095b84d5a4f7cf9287d6e581f46d09626fa6e0874fd924f5efe927b52880bad'
$totFinalHash = '68bec9adc80468dc35c73f14ec829e1b958cbc67a1240ceb4752e28cd29e5abc'
$docAtomicHash = '0cf106a48261adcf190a52ab76630076905a70aa8d1aee6116de1db3299df394'
$baseHashes = @(
    '0cf106a48261adcf190a52ab76630076905a70aa8d1aee6116de1db3299df394',
    '892f48de889a647d75770c2286bdc4ad2d4671790ef4e22f1cbb159996e9adc2',
    '6d50508d402d4f35e5a8918825a5e6b66b5cfdcf5e4cf5fc41697b5535b6af23',
    '1d1bfdbeb988f546968e5a5e9a56198dd6ccb1ad1d76de3139ea0f876c199519'
)
$attestations = @('@KeepStoreRoutineBackupVerified', '@KeepStoreCheckoutQuiesced', '@KeepStoreExpectedServerUuid', '@KeepStoreExpectedDatabase')

# a combined guard variable must be computed (never a constant) and must list every component
function Test-Lists([System.Collections.Generic.List[string]]$v, [string]$file, [string]$text, [string]$var, [string[]]$required) {
    $lines = @([regex]::Matches($text, '(?m)^SET @' + [regex]::Escape($var) + '=IF\((.*)\);$') | ForEach-Object { $_.Groups[1].Value })
    if ($lines.Count -lt 1) { $v.Add($file + ': ' + $var + ' is not computed'); return }
    $line = $lines[$lines.Count - 1]
    foreach ($r in $required) { if (-not $line.Contains('@' + $r + '=1')) { $v.Add($file + ': ' + $var + ' does not require ' + $r) } }
}
function Pos([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::Ordinal) }
function Test-Order([System.Collections.Generic.List[string]]$v, [string]$file, [string]$text, [string[]]$steps) {
    $o = @($steps | ForEach-Object { Pos $text $_ })
    for ($i = 0; $i -lt $o.Count; $i++) {
        if ($o[$i] -lt 0) { $v.Add($file + ': step ' + $i + ' missing (' + $steps[$i].Trim() + ')') }
        elseif ($i -gt 0 -and $o[$i] -le $o[$i - 1]) { $v.Add($file + ': step ' + $i + ' out of order (' + $steps[$i].Trim() + ')') }
    }
}

function Get-Violations([hashtable]$F) {
    $v = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('preflight', 'forward', 'verify', 'rollback')) {
        $t = $F[$k]
        if ($t -match '[^\x09\x0A\x20-\x7E]') { $v.Add($k + ': non-ASCII character') }
        if ($t -cmatch '(?m)^\s*USE\s') { $v.Add($k + ': USE statement') }
        if ($t -match '(?i)taikun|onsus|ks_taikun') { $v.Add($k + ': customer or template name') }
        if ($t -match '__KEEPSTORE_(?!ORIGINAL_DEFINER__)') { $v.Add($k + ': unknown placeholder') }
        if ($t -match '(?m)^SET @ks_ck_\w+=\d+;') { $v.Add($k + ': guard variable assigned a constant') }
        if ($t -match "CHAR\(13\),''") { $v.Add($k + ': removes every CR instead of CRLF pairs') }
        if (-not $t.Contains('q.CHARACTER_SET_NAME IS NOT NULL')) { $v.Add($k + ': parameter charset check missing') }
    }
    # forward: probe + Carrello_Totali + Carrello_Documento + the instruction comment; rollback: probe + restored Carrello_Documento + the instruction comment
    $slots = @{ preflight = 0; forward = 4; verify = 0; rollback = 3 }
    foreach ($k in $slots.Keys) {
        $n = ([regex]::Matches($F[$k], '__KEEPSTORE_ORIGINAL_DEFINER__')).Count
        if ($n -ne $slots[$k]) { $v.Add($k + ': definer slot count ' + $n + ' instead of ' + $slots[$k]) }
    }
    $delims = @{ forward = 3; rollback = 2 }
    foreach ($k in $delims.Keys) {
        $open = ([regex]::Matches($F[$k], '(?m)^DELIMITER \$\$$')).Count
        $close = ([regex]::Matches($F[$k], '(?m)^DELIMITER ;$')).Count
        if ($open -ne $delims[$k] -or $close -ne $delims[$k]) { $v.Add($k + ': DELIMITER blocks ' + $open + '/' + $close) }
    }
    foreach ($k in @('preflight', 'verify')) {
        if ($F[$k] -imatch '(?m)^\s*(CREATE|DROP|ALTER|INSERT|UPDATE|DELETE|GRANT|REVOKE|TRUNCATE|CALL|DELIMITER|REPLACE|RENAME)\b') { $v.Add($k + ': not read-only') }
        if (-not $F[$k].Contains('(this script cannot see them)')) { $v.Add($k + ': grants reminder missing') }
        foreach ($a in $attestations) { if ($F[$k].Contains($a)) { $v.Add($k + ': must not require ' + $a) } }
    }
    # bodies
    $totBody = Get-Body $F['forward'] 'Carrello_Totali'
    $docBody = Get-Body $F['forward'] 'Carrello_Documento'
    $atomBody = Get-Body $F['rollback'] 'Carrello_Documento'
    if ($null -eq $totBody -or (Get-Sha256 $totBody) -cne $totFinalHash) { $v.Add('forward: Carrello_Totali body differs from the tested one') }
    if ($null -eq $docBody -or (Get-Sha256 $docBody) -cne $docFinalHash) { $v.Add('forward: Carrello_Documento body differs from the tested one') }
    if ($null -eq $atomBody -or (Get-Sha256 $atomBody) -cne $docAtomicHash) { $v.Add('rollback: restored Carrello_Documento body differs from the atomic-reservation body') }
    # order of the steps
    Test-Order $v 'forward' $F['forward'] @(
        'ORDER_CHAIN_FORWARD_PRECHECK_A',
        'SELECT CHARACTER_SET_CLIENT, COLLATION_CONNECTION, DEFINER INTO @ks_chain_cs, @ks_chain_co, @ks_chain_definer',
        'PROCEDURE `ks_chain_definer_probe`',
        'ORDER_CHAIN_DEFINER_SLOT_A',
        'PROCEDURE `Carrello_Totali`',
        'ORDER_CHAIN_TOTALI_DEFINER_A',
        "`nDROP PROCEDURE Carrello_Documento;",
        'PROCEDURE `Carrello_Documento`',
        'SET @ks_ck_definer_orig=',
        'ORDER_CHAIN_FORWARD_A',
        'SET SESSION group_concat_max_len=@ks_chain_init_gcml;')
    Test-Order $v 'rollback' $F['rollback'] @(
        'ORDER_CHAIN_ROLLBACK_PRECHECK_A',
        'SELECT CHARACTER_SET_CLIENT, COLLATION_CONNECTION, DEFINER INTO @ks_chain_cs, @ks_chain_co, @ks_chain_definer',
        'PROCEDURE `ks_chain_definer_probe`',
        'ORDER_CHAIN_DEFINER_SLOT_A',
        "`nDROP PROCEDURE IF EXISTS Carrello_Documento;",
        'PROCEDURE `Carrello_Documento`',
        "`nDROP PROCEDURE Carrello_Totali;",
        'SET @ks_ck_definer_orig=',
        'ORDER_CHAIN_ROLLBACK_A',
        'SET SESSION group_concat_max_len=@ks_chain_init_gcml;')
    $drops = @{ preflight = 0; forward = 2; verify = 0; rollback = 3 }
    foreach ($k in $drops.Keys) {
        $n = ([regex]::Matches($F[$k], '(?m)^DROP PROCEDURE ')).Count
        if ($n -ne $drops[$k]) { $v.Add($k + ': DROP PROCEDURE count ' + $n + ' instead of ' + $drops[$k]) }
    }
    # which routine each probe is compared with: the forward keeps the original Carrello_Documento definer, the rollback the one of Carrello_Totali
    if (-not $F['forward'].Contains("d.ROUTINE_NAME='Carrello_Documento'")) { $v.Add('forward: probe not compared with Carrello_Documento') }
    if (-not $F['rollback'].Contains("d.ROUTINE_NAME='Carrello_Totali'")) { $v.Add('rollback: probe not compared with Carrello_Totali') }
    foreach ($k in @('forward', 'rollback')) {
        if ($F[$k] -notmatch '(?m)^SET @ks_ck_slot=IF\(\(SELECT COUNT\(\*\) FROM information_schema\.ROUTINES p JOIN') { $v.Add($k + ': slot guard is not computed from the probe') }
        if ($F[$k] -notmatch 'BINARY DEFINER=BINARY @ks_chain_definer') { $v.Add($k + ': no comparison with the original definer') }
        foreach ($a in $attestations) { if (-not $F[$k].Contains($a)) { $v.Add($k + ': missing attestation ' + $a) } }
        foreach ($needle in @('SET SESSION character_set_client=@ks_chain_cs;', 'SET SESSION collation_connection=@ks_chain_co;', 'SET SESSION character_set_client=@ks_chain_init_cs;', 'SET SESSION collation_connection=@ks_chain_init_co;', 'SET SESSION sql_mode=@ks_chain_init_sql_mode;', 'SET @ks_chain_init_gcml=@@SESSION.group_concat_max_len;', 'SET SESSION group_concat_max_len=@ks_chain_init_gcml;')) {
            if (-not $F[$k].Contains($needle)) { $v.Add($k + ': missing ' + $needle) }
        }
        if (-not $F[$k].Contains('Halt Execution of Queries on Error')) { $v.Add($k + ': SQLyog halt-on-error instruction missing') }
        if (-not $F[$k].Contains('close the connection')) { $v.Add($k + ': close-the-connection instruction missing') }
    }
    if ($F['forward'] -notmatch '(?m)^SET @ks_ck_totdef=IF\(\(SELECT COUNT\(\*\).*ROUTINE_NAME IN \(''Carrello_Totali''\).*BINARY DEFINER=BINARY @ks_chain_definer\)=1,1,0\);') { $v.Add('forward: Carrello_Totali definer not checked before the DROP') }
    # the combined variables must list every component
    $pre = @('ks_ck_doc_text', 'ks_ck_doc_attr', 'ks_ck_doc_meta', 'ks_ck_doc_dbcoll', 'ks_ck_doc_sig', 'ks_ck_totali_absent', 'ks_ck_probe_absent', 'ks_ck_t_documenti', 'ks_ck_t_pie', 'ks_ck_t_vcarrello', 'ks_ck_t_engine')
    Test-Lists $v 'preflight' $F['preflight'] 'ks_ck_overall' $pre
    Test-Lists $v 'forward' $F['forward'] 'ks_ck_overall' ($pre + 'ks_ck_attest')
    Test-Lists $v 'forward' $F['forward'] 'ks_ck_final' @('ks_ck_doc_all', 'ks_ck_tot_all', 'ks_ck_probe_absent', 'ks_ck_definer_same', 'ks_ck_meta_same', 'ks_ck_definer_orig')
    Test-Lists $v 'verify' $F['verify'] 'ks_ck_overall' @('ks_ck_doc_all', 'ks_ck_tot_all', 'ks_ck_probe_absent', 'ks_ck_definer_same', 'ks_ck_meta_same', 'ks_ck_t_documenti', 'ks_ck_t_pie', 'ks_ck_t_vcarrello', 'ks_ck_t_engine')
    Test-Lists $v 'rollback' $F['rollback'] 'ks_ck_overall' @('ks_ck_tot_all', 'ks_ck_doc_state', 'ks_ck_same_ok', 'ks_ck_probe_absent', 'ks_ck_t_documenti', 'ks_ck_t_pie', 'ks_ck_t_vcarrello', 'ks_ck_t_engine', 'ks_ck_attest')
    Test-Lists $v 'rollback' $F['rollback'] 'ks_ck_final' @('ks_ck_doc_all', 'ks_ck_totali_absent', 'ks_ck_probe_absent', 'ks_ck_definer_orig')
    foreach ($pfx in @('doc', 'tot')) {
        foreach ($k in @('forward', 'verify')) {
            Test-Lists $v $k $F[$k] ('ks_ck_' + $pfx + '_all') @(('ks_ck_' + $pfx + '_text'), ('ks_ck_' + $pfx + '_attr'), ('ks_ck_' + $pfx + '_meta'), ('ks_ck_' + $pfx + '_dbcoll'), ('ks_ck_' + $pfx + '_sig'))
        }
    }
    # known starting texts, same list everywhere they are checked
    $inList = ($baseHashes | ForEach-Object { "'" + $_ + "'" }) -join ','
    foreach ($k in @('preflight', 'forward', 'rollback')) { if (-not $F[$k].Contains('IN (' + $inList + ')')) { $v.Add($k + ': starting text list differs') } }
    foreach ($k in @('forward', 'verify')) {
        if (-not ($F[$k].Contains($docFinalHash) -and $F[$k].Contains($totFinalHash))) { $v.Add($k + ': target text hashes missing') }
    }
    $v.ToArray()
}

$names = @('preflight', 'forward', 'verify', 'rollback')
$prefix = '20261113_ORDER_CHAIN_UNIVERSAL_1A_'
$files = @{}
foreach ($n in $names) { $files[$n] = Read-Lf ('Database Taikun/Migrations/' + $prefix + $n + '.sql') }
$base = @(Get-Violations $files)
Assert-Contract ($base.Count -eq 0) ('the four files satisfy every invariant' + $(if ($base.Count) { ': ' + ($base -join '; ') } else { '' }))

# the bodies are the ones already integrated and proven (not re-typed)
$totalsSql = Read-Lf 'Database Taikun/Migrations/20261112_ORDER_TOTALS_DB_SOURCE_1A_forward.sql'
$atomicSql = Read-Lf 'Database Taikun/Migrations/20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql'
Assert-Contract ((Get-Body $files['forward'] 'Carrello_Totali') -ceq (Get-Body $totalsSql 'Carrello_Totali')) 'Carrello_Totali body equals the integrated totals migration'
Assert-Contract ((Get-Body $files['forward'] 'Carrello_Documento') -ceq (Get-Body $totalsSql 'Carrello_Documento')) 'Carrello_Documento body equals the integrated totals migration'
$atomicBody = Get-Body $atomicSql 'Carrello_Documento'
Assert-Contract ((Get-Body $files['rollback'] 'Carrello_Documento') -ceq $atomicBody) 'restored body equals the atomic-reservation migration body'

# the four accepted starting texts are all derived from that one source body (fixtures, not independent claims)
$noComments = [regex]::Replace($atomicBody, '/\*[\s\S]*?\*/', '')
$derived = @(
    (Get-Sha256 $atomicBody),
    (Get-Sha256 ($atomicBody -replace "\n    END$", "`nEND")),
    (Get-Sha256 $noComments),
    (Get-Sha256 ((($noComments -split "`n") | ForEach-Object { $_.TrimEnd() }) -join "`n"))
)
for ($i = 0; $i -lt 4; $i++) { Assert-Contract ($derived[$i] -ceq $baseHashes[$i]) ('accepted starting text ' + $i + ' is derived from the atomic-reservation body') }
# a CRLF copy of the installed text hashes like the LF one; a lone CR does not
$crlf = $atomicBody.Replace("`n", "`r`n")
Assert-Contract ((Get-Sha256 $crlf.Replace("`r`n", "`n")) -ceq $docAtomicHash) 'CRLF text normalizes to the LF hash'
Assert-Contract ((Get-Sha256 $atomicBody.Replace('BUONOSCONTO', "BUONO`rSCONTO").Replace("`r`n", "`n")) -cne $docAtomicHash) 'a lone CR inside the text is not hidden by the normalization'

# the files are approved by name in the secret guard
$guard = Read-Lf 'Tools/Test-DatabaseSecretsGuard.ps1'
foreach ($n in $names) { Assert-Contract ($guard.Contains('Database Taikun/Migrations/' + $prefix + $n + '.sql')) ('secret guard names the file: ' + $n) }
Assert-Contract ($guard.Contains("'" + $prefix + "'")) 'secret guard self-test covers the new prefix'

# the rollback embeds the historical body with its trailing blanks: only that path is exempt from the whitespace check of git diff --check
$attributes = Read-Lf '.gitattributes'
Assert-Contract ($attributes.Contains('Database?Taikun/Migrations/' + $prefix + 'rollback.sql whitespace=-trailing-space')) 'the rollback is exempt from the trailing-space check (embedded historical text)'
Assert-Contract (-not ($attributes -match '(?m)^\S*(preflight|forward|verify)\.sql\s')) 'no other migration file is exempt'

# mutations: each must be caught
$mutations = [ordered]@{
    'slot guard removed'                      = { param($f) $f['forward'] = $f['forward'].Replace('ORDER_CHAIN_DEFINER_SLOT_A', 'X'); $f }
    'slot guard made a constant'              = { param($f) $f['forward'] = [regex]::Replace($f['forward'], '(?m)^SET @ks_ck_slot=IF\(.*$', 'SET @ks_ck_slot=1;'); $f }
    'overall made a constant'                 = { param($f) $f['forward'] = [regex]::Replace($f['forward'], '(?m)^SET @ks_ck_overall=IF\(.*$', 'SET @ks_ck_overall=1;'); $f }
    'DROP moved before the probe'             = { param($f) $f['forward'] = $f['forward'].Replace('DROP PROCEDURE Carrello_Documento;', '').Replace("DELIMITER `$`$`nCREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE ``ks_chain_definer_probe``", "DROP PROCEDURE Carrello_Documento;`nDELIMITER `$`$`nCREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE ``ks_chain_definer_probe``"); $f }
    'Totali definer guard removed'            = { param($f) $f['forward'] = $f['forward'].Replace('ORDER_CHAIN_TOTALI_DEFINER_A', 'X'); $f }
    'final original-definer check dropped'    = { param($f) $f['forward'] = $f['forward'].Replace('AND @ks_ck_definer_orig=1', ''); $f }
    'rollback original-definer check dropped' = { param($f) $f['rollback'] = $f['rollback'].Replace('AND @ks_ck_definer_orig=1', ''); $f }
    'rollback probe compares Documento'       = { param($f) $f['rollback'] = $f['rollback'].Replace("d.ROUTINE_NAME='Carrello_Totali'", "d.ROUTINE_NAME='Carrello_Documento'"); $f }
    'one character of the final body'         = { param($f) $f['forward'] = $f['forward'].Replace('SET pTotMerce=ROUND(impExact,2);', 'SET pTotMerce=ROUND(impExact,3);'); $f }
    'one character of the atomic body'        = { param($f) $f['rollback'] = $f['rollback'].Replace('SET totsconto=0;', 'SET totsconto=1;'); $f }
    'USE statement in the preflight'          = { param($f) $f['preflight'] = "USE db1;`n" + $f['preflight']; $f }
    'customer name in the verify'             = { param($f) $f['verify'] = $f['verify'] + "-- taikun`n"; $f }
    'write statement in the verify'           = { param($f) $f['verify'] = $f['verify'] + "UPDATE documenti SET id=id;`n"; $f }
    'lowercase write statement in the verify' = { param($f) $f['verify'] = $f['verify'] + "update documenti set id=id;`n"; $f }
    'attestation dropped from forward'        = { param($f) $f['forward'] = $f['forward'].Replace('@KeepStoreCheckoutQuiesced', '@KeepStoreSomething'); $f }
    'extra definer slot in the preflight'     = { param($f) $f['preflight'] = $f['preflight'] + "-- __KEEPSTORE_ORIGINAL_DEFINER__`n"; $f }
    'starting text list shortened'            = { param($f) $f['forward'] = $f['forward'].Replace("'1d1bfdbeb988f546968e5a5e9a56198dd6ccb1ad1d76de3139ea0f876c199519'", "'x'"); $f }
    'charset restore removed'                 = { param($f) $f['rollback'] = $f['rollback'].Replace('SET SESSION character_set_client=@ks_chain_init_cs;', ''); $f }
    'group_concat_max_len not restored'       = { param($f) $f['forward'] = $f['forward'].Replace('SET SESSION group_concat_max_len=@ks_chain_init_gcml;', ''); $f }
    'rollback keeps Carrello_Totali'          = { param($f) $f['rollback'] = $f['rollback'].Replace('DROP PROCEDURE Carrello_Totali;', ''); $f }
    'every CR removed instead of CRLF'        = { param($f) $f['preflight'] = $f['preflight'].Replace('REPLACE(ROUTINE_DEFINITION,CONCAT(CHAR(13),CHAR(10)),CHAR(10))', "REPLACE(ROUTINE_DEFINITION,CHAR(13),'')"); $f }
    'parameter charset check removed'         = { param($f) $f['verify'] = $f['verify'].Replace('q.CHARACTER_SET_NAME IS NOT NULL', 'q.CHARACTER_SET_NAME IS NULL'); $f }
    'halt-on-error instruction removed'       = { param($f) $f['forward'] = $f['forward'].Replace('Halt Execution of Queries on Error', 'x'); $f }
}
foreach ($name in $mutations.Keys) {
    $copy = @{}
    foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    $mutated = & $mutations[$name] $copy
    $violations = @(Get-Violations $mutated)
    Assert-Contract ($violations.Count -gt 0) ('mutation is caught: ' + $name)
}
Write-Output ('ORDER_CHAIN_UNIVERSAL_TEST_PASS checks=' + $checks + ' mutations=' + $mutations.Count)
