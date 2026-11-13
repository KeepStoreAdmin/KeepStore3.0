param(
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$true)][string]$Out,
  [switch]$UnescapeBatch
)
# Rebuilds the routine text from the rows "C nnn" of Database Taikun/Diagnostics/20261113_ROUTINE_EXPORT_READONLY_1A.sql,
# verifies every chunk (length and MD5) and the whole text (length, SHA-256 with and without CR) against the row "B totale".
# Standard and universal: it names no database or customer. Local read-only tool: it never connects to a database.
# -UnescapeBatch: use it only when the grid was produced by the mysql client in batch mode (backslashes are escaped there).
$md5 = [System.Security.Cryptography.MD5]::Create(); $sha = [System.Security.Cryptography.SHA256]::Create()
function Get-KeepStoreHash($algorithm, [string]$text) { ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) -replace '-','').ToLower() }
$lines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
$chunks = @{}; $bad = New-Object System.Collections.Generic.List[string]; $b = $null; $meta = $null
foreach ($l in $lines) {
  if ($l -match '^B totale\s+(.*)$') { $b = $Matches[1]; continue }
  if ($l -match '^A meta\s+(.*)$') { $meta = $Matches[1]; continue }
  if ($l -match '^C (\d{3})\s+(\d+) \| ([0-9a-f]{32}) \| \[(.*)\]\s*$') {
    $n = [int]$Matches[1]; $len = [int]$Matches[2]; $m5 = $Matches[3]; $txt = $Matches[4]
    if ($UnescapeBatch) { $txt = $txt.Replace('\\', '\') }
    $txt = $txt.Replace('{CR}', "`r").Replace('{LF}', "`n").Replace('{TAB}', "`t")
    if ($txt.Length -ne $len) { $bad.Add("chunk $n length $($txt.Length) instead of $len") }
    elseif ((Get-KeepStoreHash $md5 $txt) -ne $m5) { $bad.Add("chunk $n MD5 differs") }
    $chunks[$n] = $txt
  }
}
if ($chunks.Count -eq 0) { 'NO CHUNK FOUND'; return }
$max = ($chunks.Keys | Measure-Object -Maximum).Maximum
$missing = 0..$max | Where-Object { -not $chunks.ContainsKey($_) }
if ($missing) { "MISSING CHUNKS: " + ($missing -join ',') }
$full = -join (0..$max | Where-Object { $chunks.ContainsKey($_) } | ForEach-Object { $chunks[$_] })
[IO.File]::WriteAllText($Out, $full, (New-Object Text.UTF8Encoding($false)))
$noCr = $full.Replace("`r", '')
"meta: $meta"
"expected (row B): $b"
"rebuilt: len=$($full.Length) sha=$(Get-KeepStoreHash $sha $full) sha_lf=$(Get-KeepStoreHash $sha $noCr)"
if ($bad.Count) { "INVALID CHUNKS: " + ($bad -join '; ') } else { 'all chunks valid (length and MD5)' }