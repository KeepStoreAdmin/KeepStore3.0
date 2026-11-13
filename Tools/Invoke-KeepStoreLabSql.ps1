[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [switch]$Write,
    # Keeps /* ... */ comments in the statements sent to the server (the mysql client strips them by default): needed to store a routine body exactly as written.
    [switch]$KeepComments,
    [string]$CredentialFile = (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'),
    [string]$MysqlRoot = 'C:\Temp\KeepStoreRegOrderLab-20261025\mysql',
    [string]$Schema = 'keepstore_regorder_lab_20261025',
    [ValidateRange(1024, 65535)][int]$Port = 13317,
    [int]$MaxChars = 60000
)

# Esegue un file SQL sul database LAB LOCALE (solo 127.0.0.1) con il client mysql.exe del LAB.
# - SQL da file via stdin: mai in argv. TLS con verifica della CA del LAB (VERIFY_CA).
# - Credenziale: PSCredential cifrata DPAPI CurrentUser in un file indicato; la password e decifrata in memoria e passata
#   solo come variabile di ambiente del processo figlio (mai in argv, output o file) e mascherata nell'output.
# - Default: sessione READ ONLY. -Write (mutazioni) solo per DDL/DML di prova sul LAB, mai su produzione.
# Richiede Windows PowerShell 5.1 (DPAPI/Import-Clixml). Non cerca ne legge altri depositi di credenziali.
$ErrorActionPreference = 'Stop'
$client = Join-Path $MysqlRoot 'engine\bin\mysql.exe'
$ca = Join-Path $MysqlRoot 'data\ca.pem'
foreach ($required in @($SqlFile, $CredentialFile, $client, $ca)) {
    if (-not (Test-Path -LiteralPath $required)) { Write-Output ('MISSING: ' + $required); exit 2 }
}
$cred = Import-Clixml -LiteralPath $CredentialFile
if ($cred -isnot [pscredential]) { Write-Output 'CREDENTIAL_FILE_NOT_PSCREDENTIAL'; exit 3 }
$user = $cred.UserName
$plain = $cred.GetNetworkCredential().Password
$body = [IO.File]::ReadAllText($SqlFile)
$prefix = if ($Write) { '' } else { "SET SESSION TRANSACTION READ ONLY;`n" }
$info = New-Object Diagnostics.ProcessStartInfo
$info.FileName = $client
$info.Arguments = '--protocol=TCP --host=127.0.0.1 --port=' + $Port + ' --user=' + $user + ' --ssl-mode=VERIFY_CA --ssl-ca="' + $ca + '" --connect-timeout=8 --batch --default-character-set=utf8mb4 --database=' + $Schema
if ($KeepComments) { $info.Arguments += ' --comments' }
$info.UseShellExecute = $false
$info.RedirectStandardInput = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.CreateNoWindow = $true
$info.StandardOutputEncoding = [Text.Encoding]::UTF8
$info.StandardErrorEncoding = [Text.Encoding]::UTF8
$info.EnvironmentVariables['MYSQL_PWD'] = $plain
$process = [Diagnostics.Process]::Start($info)
$process.StandardInput.Write($prefix + $body)
$process.StandardInput.Close()
$out = $process.StandardOutput.ReadToEnd()
$err = $process.StandardError.ReadToEnd()
$process.WaitForExit()
$code = $process.ExitCode
if ($plain) { $out = $out.Replace($plain, '<hidden>'); $err = $err.Replace($plain, '<hidden>') }
$plain = $null; $cred = $null
Write-Output ('mode=' + $(if ($Write) { 'READ-WRITE' } else { 'READ-ONLY' }) + ' client exit=' + $code)
if ($out.Length -gt $MaxChars) { Write-Output ($out.Substring(0, $MaxChars) + "`n...[truncated at $MaxChars chars]") } else { Write-Output $out }
if ($err.Trim()) { Write-Output ('stderr: ' + $err.Trim()) }
exit $code
