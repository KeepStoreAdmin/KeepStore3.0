[CmdletBinding()]
param([string]$BaselineRef = '966a8ed5d3c10fc09e5ba64fd5b8a417c92fc0cb')

# KS-C02-WISHLIST-HEADER-OWNER-KEY-1A: il badge wishlist dell'header deve usare utenti.Id (Session("UtentiId")),
# la stessa chiave di wishlist.aspx e wishlist_add.aspx, e non login.id (Session("LoginId")).
# Controlli sorgente sul diff contro la base + esecuzione del metodo runtime reale estratto meccanicamente.
# Nessun database, IIS, sessione ASP.NET o rete.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTemp = Join-Path $taskTempBase ('ks-wishlist-owner-' + [Guid]::NewGuid().ToString('N'))
$taskStatic = 0
function Check-Source([bool]$condition, [string]$name) {
    if (-not $condition) { throw $name }
    $script:taskStatic++
    Write-Output ('PASS ' + $name)
}
function Read-Source([string]$path) {
    return [IO.File]::ReadAllText((Join-Path $taskRoot $path)).Replace("`r`n", "`n")
}
function Read-Base([string]$path) {
    $lines = @(git -C $taskRoot show ($BaselineRef + ':' + $path))
    if ($LASTEXITCODE -ne 0) { throw 'WISHLIST_BASE_READ_FAILED' }
    return ($lines -join "`n") + "`n"
}
function Get-IconBlock([string]$source) {
    $start = $source.IndexOf('            Dim lblWish As Label = FindCtrl(Of Label)("lblWishlistCount")', [StringComparison]::Ordinal)
    if ($start -lt 0) { throw 'WISHLIST_ICON_BLOCK_START_MISSING' }
    $end = $source.IndexOf("        Catch ex As Exception`n            ' fail-safe", $start, [StringComparison]::Ordinal)
    if ($end -lt $start) { throw 'WISHLIST_ICON_BLOCK_END_MISSING' }
    return $source.Substring($start, $end - $start)
}
function Get-CountBlock([string]$source, [string]$startMarker) {
    $start = $source.IndexOf($startMarker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw 'WISHLIST_COUNT_BLOCK_START_MISSING' }
    $function = $source.IndexOf('Private Function GetWishlistCountForHeader(', $start, [StringComparison]::Ordinal)
    if ($function -lt 0) { throw 'WISHLIST_COUNT_FUNCTION_MISSING' }
    $endToken = $source.IndexOf("End Function`n", $function, [StringComparison]::Ordinal)
    if ($endToken -lt 0) { throw 'WISHLIST_COUNT_BLOCK_END_MISSING' }
    return $source.Substring($start, ($endToken + 'End Function'.Length) - $start)
}

$taskMaster = Read-Source 'Page.master.vb'
$taskMasterBase = Read-Base 'Page.master.vb'
$taskIcon = Get-IconBlock $taskMaster
$taskIconBase = Get-IconBlock $taskMasterBase
$taskCount = Get-CountBlock $taskMaster "' Proprietario della wishlist:"
$taskCountBase = Get-CountBlock $taskMasterBase 'Private Function GetWishlistCountForHeader('

Check-Source ($taskMaster.Replace($taskIcon, '').Replace($taskCount, '') -ceq $taskMasterBase.Replace($taskIconBase, '').Replace($taskCountBase, '')) 'ONLY_WISHLIST_HEADER_BLOCKS_CHANGED'
Check-Source ($taskMaster -cne $taskMasterBase) 'MASTER_ACTUALLY_CHANGED'
# Difetto della base: il conteggio usava login.id.
Check-Source ($taskIconBase.Contains('GetWishlistCountForHeader(loginIdVal)') -and $taskIconBase.Contains('Session("LoginId")')) 'BASELINE_KEYED_BY_LOGIN_ID'
Check-Source ($taskCountBase.Contains('cmd.Parameters.AddWithValue("@id", loginId)')) 'BASELINE_PARAMETER_WAS_LOGIN_ID'
# Candidato: chiave utenti.Id, gate LoginId, nessun ripiego.
Check-Source ($taskIcon.Contains('GetWishlistCountForHeader(ResolveWishlistOwnerId(Session("LoginId"), Session("UtentiId")))')) 'CALL_SITE_USES_RESOLVED_UTENTI_ID'
Check-Source (-not $taskIcon.Contains('loginIdVal') -and -not $taskIcon.Contains('GetWishlistCountForHeader(loginId')) 'NO_LOGIN_ID_KEY_LEFT_IN_CALL_SITE'
Check-Source ($taskIcon.Contains('lblWish.Text = wishCount.ToString()') -and $taskIcon.Contains('lblWish.Visible = True')) 'LABEL_RENDERING_UNCHANGED'
Check-Source ($taskCount.Contains('"SELECT COUNT(*) FROM wishlist WHERE id_utente=@id"') -and $taskCountBase.Contains('"SELECT COUNT(*) FROM wishlist WHERE id_utente=@id"')) 'SQL_TEXT_UNCHANGED'
Check-Source ($taskCount.Contains('cmd.Parameters.AddWithValue("@id", ownerUtentiId)') -and -not $taskCount.Contains('AddWithValue("@id", loginId)')) 'SQL_PARAMETER_IS_OWNER_UTENTI_ID'
Check-Source ($taskCount.Contains('If ownerUtentiId <= 0 Then') -and $taskCount.Contains('Catch') -and $taskCount.Contains('Return 0')) 'FAIL_CLOSED_AND_ERROR_PATH_PRESERVED'
Check-Source (([regex]::Matches($taskMaster, 'FROM wishlist')).Count -eq 1) 'SINGLE_WISHLIST_QUERY_IN_MASTER'

$taskResolver = [regex]::Match($taskCount, '(?ms)^Private Shared Function ResolveWishlistOwnerId\(.*?^End Function').Value
if (-not $taskResolver) { throw 'WISHLIST_RESOLVER_EXTRACTION_FAILED' }
Check-Source ($taskResolver -notmatch 'Session\(|HttpContext|MySql|Cache|Request|Response|Cookies') 'RESOLVER_IS_PURE_NO_SESSION_DB_OR_HTTP'
Check-Source ($taskResolver.Contains('Return utentiId') -and -not ($taskResolver -match 'Return loginId')) 'RESOLVER_NEVER_RETURNS_LOGIN_ID'

# Consumatori della chiave e login restano invariati e confermano il contratto UtentiId / LoginId distinti.
foreach ($path in @('wishlist.aspx.vb', 'wishlist_add.aspx.vb', 'login.aspx.vb', 'wishlist.aspx', 'Page.master')) {
    Check-Source ((Read-Source $path) -ceq (Read-Base $path)) ('UNCHANGED_' + [IO.Path]::GetFileName($path))
}
Check-Source ((Read-Source 'wishlist.aspx.vb').Contains('Dim idUtenteStr As String = Convert.ToString(Session("UtentiId"))')) 'WISHLIST_PAGE_KEYED_BY_UTENTI_ID'
Check-Source ((Read-Source 'wishlist_add.aspx.vb').Contains('Integer.TryParse(Convert.ToString(Session("UtentiId")), userId)')) 'WISHLIST_ADD_KEYED_BY_UTENTI_ID'
$taskLogin = Read-Source 'login.aspx.vb'
Check-Source ($taskLogin.Contains('Session("LoginId") = dr.Item("id")') -and $taskLogin.Contains('Session("UtentiId") = dr.Item("utentiid")')) 'LOGIN_SETS_DISTINCT_LOGIN_ID_AND_UTENTI_ID'

New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
    $taskFixturePath = Join-Path $taskTemp 'ExtractedWishlistOwnerResolver.vb'
    # Estrazione meccanica del metodo runtime reale: nessuna reimplementazione.
    $taskFixture = "Option Strict On`nImports System`nPublic Class WishlistOwnerFixture`n$taskResolver`nEnd Class`n"
    [IO.File]::WriteAllText($taskFixturePath, $taskFixture)
    $taskExecutable = Join-Path $taskTemp 'WishlistHeaderOwnerKeyHarness.exe'
    $taskReferences = @('System.dll', 'System.Core.dll') | ForEach-Object { Join-Path $taskFramework $_ }
    & (Join-Path $taskFramework 'vbc.exe') /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$taskExecutable" ('/reference:' + ($taskReferences -join ',')) $taskFixturePath (Join-Path $PSScriptRoot 'WishlistHeaderOwnerKeyHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'WISHLIST_OWNER_HARNESS_COMPILE_FAILED' }
    & $taskExecutable
    if ($LASTEXITCODE -ne 0) { throw 'WISHLIST_OWNER_HARNESS_FAILED' }
} finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTemp).TrimEnd('\')
    if (-not $taskResolved.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolved) -notmatch '^ks-wishlist-owner-[0-9a-f]{32}$') { throw 'WISHLIST_OWNER_UNSAFE_TEMP_CLEANUP' }
    if (Test-Path -LiteralPath $taskResolved) { Remove-Item -LiteralPath $taskResolved -Recurse -Force }
}
Write-Output ('WISHLIST_HEADER_OWNER_STATIC_CHECKS=' + $taskStatic)
Write-Output 'WISHLIST_HEADER_OWNER_RESULT=PASS;DATABASE_ACCESSES=0'
