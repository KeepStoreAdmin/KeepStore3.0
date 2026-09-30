[CmdletBinding()]
param(
    [string[]]$DatabaseNames,
    [switch]$Apply,
    [switch]$ListCandidates,
    [string]$Server = '127.0.0.1',
    [int]$Port = 3306,
    [PSCredential]$Credential
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$dll = Join-Path $repo 'Bin\MySql.Data.dll'
$canonical = Join-Path $repo 'Database Taikun\Migrations\20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql'
$historical = Join-Path $repo 'Database Taikun\Migrations\20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_rollback.sql'
$excluded = @('mysql','sys','information_schema','performance_schema','connessioni','city_registry')
$q = [char]96

function Body-Hash([string]$Sql) {
    $lf = [string][char]10
    $text = $Sql.Replace(([string][char]13 + [char]10),$lf).Replace([string][char]13,$lf)
    $body = [regex]::Match($text,'(?is)\bBEGIN\b[\s\S]*\bEND\b(?=\s*(?:\$\$|;|$))')
    if (-not $body.Success) { throw 'BODY_NOT_FOUND' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($body.Value.Trim())) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}
function Open-Db([string]$Database) {
    $builder = [MySql.Data.MySqlClient.MySqlConnectionStringBuilder]::new()
    $builder.Server = $Server; $builder.Port = $Port; $builder.Database = $Database
    $builder.UserID = $Credential.UserName
    $builder.Password = $Credential.GetNetworkCredential().Password
    $connection = [MySql.Data.MySqlClient.MySqlConnection]::new($builder.ConnectionString)
    $connection.Open()
    return $connection
}
function Scalar($Connection,[string]$Sql) {
    $cmd = $Connection.CreateCommand(); $cmd.CommandText = $Sql
    try { return $cmd.ExecuteScalar() } finally { $cmd.Dispose() }
}
function Rows($Connection,[string]$Sql) {
    $cmd = $Connection.CreateCommand(); $cmd.CommandText = $Sql
    $reader = $cmd.ExecuteReader()
    try {
        $result = @()
        while ($reader.Read()) {
            $row = [ordered]@{}
            for ($i=0; $i -lt $reader.FieldCount; $i++) {
                $value = $reader.GetValue($i)
                $row[$reader.GetName($i)] = if ($value -is [DBNull]) { $null } else { $value }
            }
            $result += [pscustomobject]$row
        }
        return $result
    } finally { $reader.Dispose(); $cmd.Dispose() }
}
function Exec($Connection,[string]$Sql) {
    $cmd = $Connection.CreateCommand(); $cmd.CommandText = $Sql
    try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
}
function Show-Create($Connection,[string]$Database,[string]$Kind) {
    $object = if ($Kind -eq 'PROCEDURE') { 'Carrello_Documento' } elseif ($Kind -eq 'TABLE') { 'carrello' } else { throw 'SHOW_CREATE_KIND_INVALID' }
    $column = if ($Kind -eq 'PROCEDURE') { 'Create Procedure' } else { 'Create Table' }
    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "SHOW CREATE $Kind $q$Database$q.$q$object$q"
    $reader = $cmd.ExecuteReader()
    try {
        if (-not $reader.Read()) { throw 'SHOW_CREATE_EMPTY' }
        return [string]$reader.GetValue($reader.GetOrdinal($column))
    } finally { $reader.Dispose(); $cmd.Dispose() }
}
function Index-Status($Connection,[string]$Index,[string]$Owner) {
    $rows = @(Rows $Connection "SELECT SEQ_IN_INDEX,COLUMN_NAME,NON_UNIQUE,INDEX_TYPE,SUB_PART FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='carrello' AND INDEX_NAME='$Index' ORDER BY SEQ_IN_INDEX")
    if ($rows.Count -eq 0) { return 'MISSING' }
    if ($rows.Count -ne 2) { return 'MISMATCH' }
    if ([int]$rows[0].SEQ_IN_INDEX -ne 1 -or $rows[0].COLUMN_NAME -cne $Owner -or
        [int]$rows[1].SEQ_IN_INDEX -ne 2 -or $rows[1].COLUMN_NAME -cne 'id') { return 'MISMATCH' }
    foreach ($row in $rows) {
        if ([int]$row.NON_UNIQUE -ne 1 -or $row.INDEX_TYPE -cne 'BTREE' -or $null -ne $row.SUB_PART) { return 'MISMATCH' }
    }
    return 'OK'
}
function Routine-State($Connection,[string]$Database,[string]$CanonicalHash) {
    $tables = [int](Scalar $Connection "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('carrello','vcarrello','articoli_giacenze','tipodocumenti','documenti','documentirighe')")
    if ($tables -ne 6) { throw 'DATABASE_STRUCTURE_MISMATCH' }
    [void](Rows $Connection 'SELECT 1 AS V FROM vcarrello LIMIT 0')
    $meta = @(Rows $Connection "SELECT SHA2(DEFINER,256) AS DefinerHash,SECURITY_TYPE,SQL_MODE,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'")
    if ($meta.Count -ne 1) { throw 'ROUTINE_NOT_UNIQUE' }
    $params = [int](Scalar $Connection "SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'")
    if ($params -ne 19 -or $meta[0].SECURITY_TYPE -cne 'DEFINER') { throw 'ROUTINE_CONTRACT_MISMATCH' }
    $create = Show-Create $Connection $Database 'PROCEDURE'
    $match = [regex]::Match($create,'(?is)^\s*CREATE\s+DEFINER\s*=\s*(?<d>[^\s;]+)\s+PROCEDURE\b')
    if (-not $match.Success -or $match.Groups['d'].Value -notmatch '@') { throw 'DEFINER_FORMAT_INVALID' }
    $hash = Body-Hash $create
    $status = if ($hash -ceq $CanonicalHash -and $meta[0].SQL_MODE -ceq 'NO_AUTO_VALUE_ON_ZERO') {
        'ALREADY_COMPLIANT'
    } elseif ($hash -ceq $historicalHash -and $meta[0].SQL_MODE -ceq 'NO_AUTO_VALUE_ON_ZERO') {
        'LEGACY'
    } else { 'MISMATCH' }
    return [pscustomobject]@{
        Database=$Database; Procedure=$status; BodyHash=$hash; Create=$create; Definer=$match.Groups['d'].Value
        DefinerHash=$meta[0].DefinerHash; Mode=$meta[0].SQL_MODE
        Charset=$meta[0].CHARACTER_SET_CLIENT; Collation=$meta[0].COLLATION_CONNECTION
        DbCollation=$meta[0].DATABASE_COLLATION
        LoginIndex=(Index-Status $Connection 'IX_carrello_LoginId_ID' 'LoginId')
        SessionIndex=(Index-Status $Connection 'IX_carrello_SessionId_ID' 'SessionId')
    }
}
function Backup-State($Connection,$State,[string]$Root) {
    $dir = Join-Path $Root $State.Database
    if (Test-Path -LiteralPath $dir) { throw 'BACKUP_EXISTS' }
    [void](New-Item -ItemType Directory -Path $dir)
    $routinePath = Join-Path $dir 'Carrello_Documento_before.sql'
    $tablePath = Join-Path $dir 'carrello_before.sql'
    [IO.File]::WriteAllText($routinePath,$State.Create,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($tablePath,(Show-Create $Connection $State.Database 'TABLE'),[Text.UTF8Encoding]::new($false))
    $sums = @()
    foreach ($path in @($routinePath,$tablePath)) {
        if ((Get-Item -LiteralPath $path).Length -eq 0) { throw 'BACKUP_EMPTY' }
        $sums += "$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant())  $(Split-Path -Leaf $path)"
    }
    [IO.File]::WriteAllLines((Join-Path $dir 'SHA256SUMS.txt'),$sums,[Text.UTF8Encoding]::new($false))
    return [pscustomobject]@{Directory=$dir;RoutinePath=$routinePath}
}
function Create-WithMetadata($Connection,[string]$Create,[string]$Mode,[string]$Charset,[string]$Collation) {
    if ($Mode -notmatch '^[A-Z0-9_,]*$' -or $Charset -notmatch '^[A-Za-z0-9_]+$' -or $Collation -notmatch '^[A-Za-z0-9_]+$') { throw 'ROUTINE_METADATA_INVALID' }
    $priorMode = [string](Scalar $Connection 'SELECT @@SESSION.sql_mode')
    $priorCharset = [string](Scalar $Connection 'SELECT @@SESSION.character_set_client')
    $priorCollation = [string](Scalar $Connection 'SELECT @@SESSION.collation_connection')
    if ($priorMode -notmatch '^[A-Z0-9_,]*$' -or $priorCharset -notmatch '^[A-Za-z0-9_]+$' -or $priorCollation -notmatch '^[A-Za-z0-9_]+$') { throw 'SESSION_METADATA_INVALID' }
    try {
        Exec $Connection "SET NAMES $Charset COLLATE $Collation"
        Exec $Connection ("SET SESSION sql_mode='" + $Mode + "'")
        Exec $Connection $Create
    } finally {
        try { Exec $Connection ("SET SESSION sql_mode='" + $priorMode + "'") }
        finally { Exec $Connection "SET NAMES $priorCharset COLLATE $priorCollation" }
    }
    if ([string](Scalar $Connection 'SELECT @@SESSION.sql_mode') -cne $priorMode -or
        [string](Scalar $Connection 'SELECT @@SESSION.character_set_client') -cne $priorCharset -or
        [string](Scalar $Connection 'SELECT @@SESSION.collation_connection') -cne $priorCollation) {
        throw 'SESSION_METADATA_RESTORE_FAILED'
    }
}
function Check-Explain($Connection,[string]$Index,[string]$Predicate) {
    $plan = @(Rows $Connection "EXPLAIN SELECT id FROM carrello FORCE INDEX ($q$Index$q) WHERE $Predicate ORDER BY id LIMIT 1")
    if ($plan.Count -ne 1 -or $plan[0].type -ceq 'ALL' -or ($plan[0].key -and $plan[0].key -cne $Index)) { throw 'OWNER_INDEX_EXPLAIN_FAILED' }
}
if (-not (Test-Path -LiteralPath $dll)) { throw 'MYSQL_ASSEMBLY_UNAVAILABLE' }
Add-Type -Path $dll
if (-not $ListCandidates -and (-not $DatabaseNames -or $DatabaseNames.Count -eq 0)) { Write-Output 'DATABASE_ALLOWLIST_REQUIRED'; return }
if ($ListCandidates -and $Apply) { throw 'DISCOVERY_APPLY_FORBIDDEN' }
if ($DatabaseNames) {
    $DatabaseNames = @($DatabaseNames | ForEach-Object { $_.Trim() })
    if (@($DatabaseNames | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw 'DATABASE_NAME_EMPTY' }
    if (@($DatabaseNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) { throw 'DATABASE_NAME_DUPLICATE' }
    if (@($DatabaseNames | Where-Object { $_ -notmatch '^[A-Za-z0-9_]+$' -or $_ -in $excluded }).Count -gt 0) { throw 'DATABASE_NAME_INVALID' }
}
if (-not $Credential) { $Credential = Get-Credential -Message 'Credenziale MySQL locale (password nascosta)' }
try {
    if ($ListCandidates) {
        $cn = Open-Db ''
        try { Write-Output ('CANDIDATES_READ_ONLY=' + ((Rows $cn 'SHOW DATABASES' | ForEach-Object { $_.PSObject.Properties.Value[0] } | Where-Object { $_ -notin $excluded }) -join ', ')) }
        finally { $cn.Dispose() }
        return
    }
    $source = [IO.File]::ReadAllText($canonical)
    if ([regex]::Matches($source,'__KEEPSTORE_HISTORICAL_DEFINER__').Count -ne 1) { throw 'CANONICAL_PLACEHOLDER_INVALID' }
    $match = [regex]::Match($source,'(?is)CREATE\s+DEFINER=__KEEPSTORE_HISTORICAL_DEFINER__\s+PROCEDURE[\s\S]*?END\s*\$\$')
    if (-not $match.Success) { throw 'CANONICAL_CREATE_NOT_FOUND' }
    $template = [regex]::Replace($match.Value,'\s*\$\$$','')
    $canonicalHash = Body-Hash $template
    $historicalHash = Body-Hash ([IO.File]::ReadAllText($historical))
    if ($canonicalHash -ceq $historicalHash) { throw 'CANONICAL_HISTORICAL_BODY_COLLISION' }
    Write-Output "CANONICAL_BODY_SHA256=$canonicalHash"
    $states = @()
    foreach ($db in $DatabaseNames) {
        $cn = $null
        try {
            $cn = Open-Db $db
            $state = Routine-State $cn $db $canonicalHash
            $states += $state
            Write-Output ("DRYRUN DB={0} PROCEDURE={1} LOGIN_INDEX={2} SESSION_INDEX={3}" -f $db,$state.Procedure,$state.LoginIndex,$state.SessionIndex)
        } finally { if ($cn) { $cn.Dispose() } }
    }
    Write-Output ('AUTHORIZED_DATABASES=' + ($DatabaseNames -join ', '))
    Write-Output ('AUTHORIZED_COUNT=' + $DatabaseNames.Count)
    if (@($states | Where-Object { $_.LoginIndex -eq 'MISMATCH' -or $_.SessionIndex -eq 'MISMATCH' -or $_.Procedure -eq 'MISMATCH' }).Count -gt 0) { throw 'SCHEMA_MISMATCH_NO_APPLY' }
    if (-not $Apply) { Write-Output 'MODE=DRYRUN'; return }
    if ((Read-Host "Digitare APPLY $($DatabaseNames.Count) per confermare") -cne "APPLY $($DatabaseNames.Count)") { Write-Output 'APPLY_CANCELLED'; return }
    $backupRoot = Join-Path 'C:\Temp' ('KeepStore_MultiDb_Backups_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
    [void](New-Item -ItemType Directory -Path $backupRoot)
    foreach ($state in $states) {
        if ($state.Procedure -eq 'ALREADY_COMPLIANT' -and $state.LoginIndex -eq 'OK' -and $state.SessionIndex -eq 'OK') {
            Write-Output "APPLY DB=$($state.Database) RESULT=ALREADY_COMPLIANT"
            continue
        }
        $cn=$null; $backup=$null; $dropped=$false; $current=$null
        try {
            $cn=Open-Db $state.Database
            $current=Routine-State $cn $state.Database $canonicalHash
            if ($current.BodyHash -cne $state.BodyHash -or $current.DefinerHash -cne $state.DefinerHash -or $current.LoginIndex -cne $state.LoginIndex -or $current.SessionIndex -cne $state.SessionIndex) { throw 'PREFLIGHT_STATE_CHANGED' }
            $backup=Backup-State $cn $current $backupRoot
            foreach ($index in @(
                @{Name='IX_carrello_LoginId_ID';Column='LoginId';Status=$current.LoginIndex},
                @{Name='IX_carrello_SessionId_ID';Column='SessionId';Status=$current.SessionIndex}
            )) {
                if ($index.Status -eq 'MISSING') { Exec $cn ("CREATE INDEX $q$($index.Name)$q ON carrello ($q$($index.Column)$q, $q" + 'id' + "$q)") }
                if ((Index-Status $cn $index.Name $index.Column) -cne 'OK') { throw 'INDEX_VERIFY_FAILED' }
            }
            Check-Explain $cn 'IX_carrello_LoginId_ID' 'LoginId=-2147483648'
            Check-Explain $cn 'IX_carrello_SessionId_ID' "SessionId='__ks_synthetic_never_match__'"
            if ($current.Procedure -ne 'ALREADY_COMPLIANT') {
                $create=$template.Replace('__KEEPSTORE_HISTORICAL_DEFINER__',$current.Definer)
                $unqualified='PROCEDURE ' + $q + 'Carrello_Documento' + $q
                if ([regex]::Matches($create,[regex]::Escape($unqualified)).Count -ne 1) { throw 'CANONICAL_ROUTINE_NAME_INVALID' }
                $create=$create.Replace($unqualified,('PROCEDURE ' + $q + $state.Database + $q + '.' + $q + 'Carrello_Documento' + $q))
                if ((Body-Hash $create) -cne $canonicalHash) { throw 'GENERATED_BODY_MISMATCH' }
                Exec $cn ('DROP PROCEDURE ' + $q + $state.Database + $q + '.' + $q + 'Carrello_Documento' + $q)
                $dropped=$true
                Create-WithMetadata $cn $create 'NO_AUTO_VALUE_ON_ZERO' $current.Charset $current.Collation
                $after=Routine-State $cn $state.Database $canonicalHash
                if ($after.Procedure -cne 'ALREADY_COMPLIANT' -or $after.DefinerHash -cne $current.DefinerHash -or $after.Charset -cne $current.Charset -or $after.Collation -cne $current.Collation -or $after.DbCollation -cne $current.DbCollation) { throw 'PROCEDURE_VERIFY_FAILED' }
            }
            Write-Output ("APPLY DB={0} RESULT=OK BACKUP={1}" -f $state.Database,$backup.Directory)
        } catch {
            if ($dropped -and $cn -and $backup) {
                try {
                    Exec $cn ('DROP PROCEDURE IF EXISTS ' + $q + $state.Database + $q + '.' + $q + 'Carrello_Documento' + $q)
                    Create-WithMetadata $cn ([IO.File]::ReadAllText($backup.RoutinePath)) $current.Mode $current.Charset $current.Collation
                    $restored=Routine-State $cn $state.Database $canonicalHash
                    if ($restored.BodyHash -cne $current.BodyHash -or $restored.DefinerHash -cne $current.DefinerHash -or
                        $restored.Mode -cne $current.Mode -or $restored.Charset -cne $current.Charset -or
                        $restored.Collation -cne $current.Collation -or $restored.DbCollation -cne $current.DbCollation) {
                        throw 'RECOVERY_VERIFY_FAILED'
                    }
                    Write-Output "RECOVERY DB=$($state.Database) RESULT=OK"
                } catch { throw "PROCEDURE_RECOVERY_FAILED:$($state.Database)" }
            }
            throw "APPLY_STOPPED:$($state.Database)"
        } finally { if ($cn) { $cn.Dispose() } }
    }
} catch {
    $errorValue = $_.Exception
    while ($errorValue.InnerException) { $errorValue = $errorValue.InnerException }
    $code = if ($errorValue.Message -match '^[A-Z_]+(?::[A-Za-z0-9_]+)?$') { $errorValue.Message } else { 'UNEXPECTED_FAILURE' }
    $number = if ($errorValue -is [MySql.Data.MySqlClient.MySqlException]) { $errorValue.Number } else { 'N/A' }
    $sqlState = if ($errorValue -is [MySql.Data.MySqlClient.MySqlException]) { $errorValue.SqlState } else { 'N/A' }
    Write-Output "STOP CODE=$code TYPE=$($errorValue.GetType().Name) MYSQL=$number SQLSTATE=$sqlState"
    throw 'INSTALLER_STOP'
} finally { $Credential=$null }
