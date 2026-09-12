[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$Server = '127.0.0.1',
    [int]$Port = 3306,
    [PSCredential]$Credential
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$dll = Join-Path $repo 'Bin\MySql.Data.dll'
$canonical = Join-Path $repo 'Database Taikun\Migrations\20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql'
$newFingerprint = '6d50508d402d4f35e5a8918825a5e6b66b5cfdcf5e4cf5fc41697b5535b6af23'
$excluded = @('mysql','sys','information_schema','performance_schema','connessioni','city_registry')
$requiredTables = @('carrello','articoli_giacenze','tipodocumenti','documenti','documentirighe','vcarrello')

function Open-KeepStoreConnection([string]$Database) {
    $builder = New-Object MySql.Data.MySqlClient.MySqlConnectionStringBuilder
    $builder.Server = $Server
    $builder.Port = $Port
    $builder.Database = $Database
    $builder.UserID = $Credential.UserName
    $builder.Password = $Credential.GetNetworkCredential().Password
    $builder.SslMode = [MySql.Data.MySqlClient.MySqlSslMode]::None
    $builder.AllowUserVariables = $true
    $c = New-Object MySql.Data.MySqlClient.MySqlConnection($builder.ConnectionString)
    $c.Open(); return $c
}
function Scalar($Connection, [string]$Sql) { $cmd=$Connection.CreateCommand(); $cmd.CommandText=$Sql; try { return $cmd.ExecuteScalar() } finally { $cmd.Dispose() } }
function QueryRows($Connection, [string]$Sql) { $cmd=$Connection.CreateCommand(); $cmd.CommandText=$Sql; $r=$cmd.ExecuteReader(); try { $rows=@(); while($r.Read()){ $o=[ordered]@{}; for($i=0;$i -lt $r.FieldCount;$i++){ $o[$r.GetName($i)]=$r.GetValue($i) }; $rows += [pscustomobject]$o }; return $rows } finally { $r.Dispose(); $cmd.Dispose() } }
function ExecuteSql($Connection, [string]$Sql) { $cmd=$Connection.CreateCommand(); $cmd.CommandText=$Sql; try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() } }
function New-SafeRoutineSql([string]$CreateSql, [string]$Database) {
    $s = $CreateSql.Trim().TrimEnd(';')
    if (([regex]::Matches($s,'(?i)\bCREATE\s+PROCEDURE\b')).Count -ne 1) { throw 'CREATE non univoca' }
    if ($s -match '(?i)\b(DROP|ALTER|GRANT|CREATE\s+USER|USE)\b') { throw 'istruzione non consentita nel CREATE' }
    $s = [regex]::Replace($s,'(?i)(^CREATE\s+(?:DEFINER\s*=\s*[^\s]+\s+)?PROCEDURE\s+)(?:`[^`]+`\.)?`?Carrello_Documento`?','$1`'+$Database+'`.`Carrello_Documento`')
    return $s + ';'
}
function Get-CreateProcedure($Connection, [string]$Database) {
    $cmd=$Connection.CreateCommand(); $cmd.CommandText='SHOW CREATE PROCEDURE `'+$Database+'`.`Carrello_Documento`'; $r=$cmd.ExecuteReader(); try { if(-not $r.Read()){throw 'SHOW CREATE vuoto'}; return [string]$r.GetValue(2) } finally { $r.Dispose(); $cmd.Dispose() }
}

if (-not (Test-Path -LiteralPath $dll)) { throw 'MySql.Data non disponibile' }
Add-Type -Path $dll
if (-not $Credential) { $Credential = Get-Credential -Message 'Credenziale MySQL locale (password nascosta)' }
$root = Open-KeepStoreConnection 'information_schema'
try {
    $names = QueryRows $root 'SHOW DATABASES' | ForEach-Object { [string]$_.'Database' } | Where-Object { $_ -and ($_ -notin $excluded) }
    $candidates=@(); foreach($db in $names){
        if($db -notmatch '^[A-Za-z0-9_]+$'){ continue }
        try {
            $routineCount=[int](Scalar $root "SELECT COUNT(*) FROM information_schema.routines WHERE ROUTINE_SCHEMA='$db' AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'")
            $tableCount=[int](Scalar $root ("SELECT COUNT(*) FROM information_schema.tables WHERE TABLE_SCHEMA='$db' AND ((TABLE_NAME IN ('" + ($requiredTables -join "','") + "')) OR (TABLE_NAME='vCarrello' AND TABLE_TYPE='VIEW'))"))
            $paramCount=[int](Scalar $root "SELECT COUNT(*) FROM information_schema.parameters WHERE SPECIFIC_SCHEMA='$db' AND SPECIFIC_NAME='Carrello_Documento'")
            $idxCount=[int](Scalar $root "SELECT COUNT(*) FROM information_schema.statistics WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='articoli_giacenze' AND INDEX_NAME='idxTC'")
            if($routineCount -eq 1 -and $tableCount -eq $requiredTables.Count -and $paramCount -eq 19 -and $idxCount -gt 0){$candidates += $db}
        } catch { }
    }
    Write-Output ('KEEPSTORE_DATABASES=' + (($candidates | Sort-Object) -join ', '))
    if($candidates.Count -eq 0){ Write-Output 'NO_COMPLIANT_DATABASES'; return }
    $states=@{}; foreach($db in ($candidates | Sort-Object)){
        $fp=[string](Scalar $root "SELECT SHA2(ROUTINE_DEFINITION,256) FROM information_schema.routines WHERE ROUTINE_SCHEMA='$db' AND ROUTINE_NAME='Carrello_Documento'")
        $states[$db]=[pscustomobject]@{Database=$db;Preflight='OK';Fingerprint=$fp;Apply='DRYRUN';Verify='NOT_RUN';Rollback='NOT_RUN'}
    }
    $states.Values | Select-Object Database,Preflight,Apply,Verify,Rollback | Format-Table -AutoSize
    if(-not $Apply){ Write-Output 'MODE=DRYRUN'; return }
    $confirm=Read-Host 'Digitare APPLY per autorizzare il DDL sequenziale'; if($confirm -cne 'APPLY'){ Write-Output 'APPLY_CANCELLED'; return }
    $template=Get-Content -Raw $canonical; $cm=[regex]::Match($template,'(?is)CREATE\s+DEFINER=__KEEPSTORE_HISTORICAL_DEFINER__\s+PROCEDURE[\s\S]*?END\s*\$\$'); if(-not $cm.Success){throw 'sorgente canonica non riconosciuta'}; $canonicalCreate=$cm.Value -replace '\$\$$',''
    $stamp=(Get-Date -Format 'yyyyMMdd_HHmmss'); $backupRoot="C:\Temp\KeepStore_MultiDb_Backups_$stamp"; New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    foreach($db in ($candidates | Sort-Object)){
        $cn=$null; $backupPath=Join-Path $backupRoot ($db+'.sql')
        try {
            $cn=Open-KeepStoreConnection $db; $current=Get-CreateProcedure $cn $db; [IO.File]::WriteAllText($backupPath,$current,(New-Object Text.UTF8Encoding($false)))
            $before=[string](Scalar $cn "SELECT SHA2(ROUTINE_DEFINITION,256) FROM information_schema.routines WHERE ROUTINE_SCHEMA='$db' AND ROUTINE_NAME='Carrello_Documento'")
            if($before -eq $newFingerprint){$states[$db].Apply='ALREADY_COMPLIANT';$states[$db].Verify='OK';continue}
            $def=[regex]::Match($current,'(?i)^CREATE\s+DEFINER\s*=\s*([^\s]+)\s+PROCEDURE').Groups[1].Value; if([string]::IsNullOrWhiteSpace($def)){throw 'DEFINER non acquisito'}
            $create=$canonicalCreate.Replace('__KEEPSTORE_HISTORICAL_DEFINER__',$def); $create=[regex]::Replace($create,'(?i)(PROCEDURE\s+)(?:`[^`]+`\.)?`?Carrello_Documento`?','$1`'+$db+'`.`Carrello_Documento`')
            ExecuteSql $cn ('DROP PROCEDURE `'+$db+'`.`Carrello_Documento`'); ExecuteSql $cn $create; $states[$db].Apply='APPLIED'
            $after=[string](Scalar $cn "SELECT SHA2(ROUTINE_DEFINITION,256) FROM information_schema.routines WHERE ROUTINE_SCHEMA='$db' AND ROUTINE_NAME='Carrello_Documento'"); if($after -ne $newFingerprint){throw 'verify fingerprint non conforme'}; $states[$db].Verify='OK'
        } catch { $states[$db].Apply='FAILED'; try { if($cn -and (Test-Path $backupPath)){ $old=Get-Content -Raw $backupPath; ExecuteSql $cn ('DROP PROCEDURE `'+$db+'`.`Carrello_Documento`'); ExecuteSql $cn (New-SafeRoutineSql $old $db); $states[$db].Rollback='OK' } } catch { $states[$db].Rollback='FAILED' }; throw } finally { if($cn){$cn.Dispose()} }
    }
    $states.Values | Select-Object Database,Preflight,Apply,Verify,Rollback | Format-Table -AutoSize
} finally { $root.Dispose(); if($Credential){$Credential=$null} }
