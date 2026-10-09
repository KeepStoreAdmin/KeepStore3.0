[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRepoRoot = Split-Path -Parent $PSScriptRoot
$taskBase = '24a6701293778c0b93827ee61904fa5876ec8b73'
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskCompiler = Join-Path $taskFramework 'vbc.exe'
$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTempRoot = Join-Path $taskTempBase ('ks-catalog-menu-cache-' + [Guid]::NewGuid().ToString('N'))
$taskExecutable = Join-Path $taskTempRoot 'CatalogMenuCacheHarness.exe'
$taskStaticChecks = 0

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    $script:taskStaticChecks++
    Write-Output ('PASS ' + $code)
}
function Read-Repo([string]$relative) {
    return [IO.File]::ReadAllText((Join-Path $taskRepoRoot $relative)).Replace("`r`n", "`n")
}
function Read-Base([string]$relative) {
    $value = @(git -C $taskRepoRoot show ($taskBase + ':' + $relative))
    if ($LASTEXITCODE -ne 0) { throw 'CATALOG_CACHE_BASE_READ_FAILED' }
    return ($value -join "`n") + "`n"
}
function Extract-Block([string]$text, [string]$start, [string]$end) {
    $first = $text.IndexOf($start, [StringComparison]::Ordinal)
    if ($first -lt 0) { throw 'CATALOG_CACHE_BLOCK_START_MISSING' }
    $last = $text.IndexOf($end, $first, [StringComparison]::Ordinal)
    if ($last -le $first) { throw 'CATALOG_CACHE_BLOCK_END_MISSING' }
    return $text.Substring($first, $last - $first)
}

$taskProvider = Read-Repo 'App_Code/CatalogMenuProvider.vb'
$taskBaseProvider = Read-Base 'App_Code/CatalogMenuProvider.vb'
$taskConsumers = @('Public/ui/controls/SiteHeader.ascx.vb', 'Public/ui/controls/HomeDepartmentsMenu.ascx.vb', 'Default.aspx.vb')
foreach ($relative in $taskConsumers) {
    $current = Read-Repo $relative
    $original = Read-Base $relative
    Assert-Source ($current -ceq $original.Replace('CatalogMenuProvider.LoadCatalogMenu()', 'CatalogMenuProvider.LoadCatalogMenuCached()')) ('CONSUMER_ONLY_CACHE_CALL_CHANGED_' + [IO.Path]::GetFileName($relative))
    Assert-Source (@([regex]::Matches($current, 'CatalogMenuProvider\.LoadCatalogMenuCached\(')).Count -eq 1) ('ONE_CACHED_CALL_' + [IO.Path]::GetFileName($relative))
}
Assert-Source ((Read-Repo 'articoli.aspx.vb') -ceq (Read-Base 'articoli.aspx.vb')) 'EXISTING_CATALOG_CALLER_UNCHANGED'
Assert-Source ((Read-Repo 'App_Code/CatalogTaxonomyResolver.vb') -ceq (Read-Base 'App_Code/CatalogTaxonomyResolver.vb')) 'EXISTING_RESOLVER_CALLER_UNCHANGED'
$start = '                conn.Open()'
$end = '    Public Function ResolveSectorImageUrl'
Assert-Source ((Extract-Block $taskProvider $start $end) -ceq (Extract-Block $taskBaseProvider $start $end)) 'TAXONOMY_SQL_ORDER_FILTERS_ROUTES_UNCHANGED'
$start = '    Public Function ResolveSectorImageUrl'
$end = '    Private Function ResolveColumnName('
Assert-Source ((Extract-Block $taskProvider $start $end) -ceq (Extract-Block $taskBaseProvider $start $end)) 'IMAGE_RESOLUTION_UNCHANGED'
$start = '        Using cmd As New MySqlCommand("SELECT COLUMN_NAME'
$end = '        Return found'
Assert-Source ((Extract-Block $taskProvider $start $end) -ceq (Extract-Block $taskBaseProvider $start $end).Replace('        ColumnCache(cacheKey) = found' + "`n", '')) 'SCHEMA_LOOKUP_AND_CANDIDATE_PRECEDENCE_UNCHANGED'
Assert-Source ($taskProvider.Contains('ResolveColumnName(conn, "categorie", "SettoriId", "Id_settore")') -and $taskProvider.Contains('ResolveColumnName(conn, "tipologie", "CategorieId", "Id_categoria")')) 'LEGACY_SCHEMA_ALLOWLIST_PRESERVED'
Assert-Source ($taskProvider.Contains('TABLE_SCHEMA = DATABASE()')) 'READ_ONLY_CONFIGURED_DATABASE_SCHEMA'
Assert-Source ($taskProvider -match 'If cacheSeconds < 60 Then cacheSeconds = 60') 'MINIMUM_TTL_60_UNCHANGED'
Assert-Source ($taskProvider -match 'If sectors IsNot Nothing AndAlso sectors.Count > 0 Then') 'EMPTY_FAILURE_NOT_INSERTED'
Assert-Source ($taskProvider -notmatch 'Cache\(MenuCacheKey\)|Insert\(MenuCacheKey') 'NO_GLOBAL_MENU_CACHE_ACCESS'
$identityBlock = Extract-Block $taskProvider '    Private Function DatabaseCacheIdentity' '    Private Function LoadMenuForScope'
Assert-Source ($identityBlock -notmatch 'UserID|Password|HttpContext|Request\.|Azienda|Session\(|Console|Trace|Log\(') 'IDENTITY_NO_CREDENTIALS_HOST_OWNER_OR_LOG'
Assert-Source ($identityBlock.Contains('builder.Server') -and $identityBlock.Contains('builder.Port') -and $identityBlock.Contains('builder.Database') -and $identityBlock.Contains('SHA256.Create()')) 'IDENTITY_ONLY_DATABASE_COORDINATES_HASHED'
Assert-Source ($taskProvider -match 'DatabaseCacheIdentity\(connectionString\), cacheSeconds,[\s\S]+?Function\(\) LoadCatalogMenu\(connectionString\)') 'CACHE_SCOPE_AND_LOAD_USE_SAME_CONFIGURATION'
Assert-Source ($taskProvider -match 'LoadColumnForScope\(DatabaseCacheIdentity\(conn.ConnectionString\)') 'COLUMN_SCOPE_USES_ACTUAL_CONNECTION'

$taskReferences = @('System.dll', 'System.Core.dll', 'System.Configuration.dll', 'System.Data.dll', 'System.Web.dll', 'System.Xml.dll') | ForEach-Object { Join-Path $taskFramework $_ }
$taskMySql = Join-Path $taskRepoRoot 'Bin/MySql.Data.dll'
New-Item -ItemType Directory -Path $taskTempRoot | Out-Null
try {
    Copy-Item -LiteralPath $taskMySql -Destination $taskTempRoot
    $taskReferenceArgument = '/reference:' + (($taskReferences + $taskMySql) -join ',')
    & $taskCompiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$taskExecutable" $taskReferenceArgument (Join-Path $taskRepoRoot 'App_Code/CatalogMenuProvider.vb') (Join-Path $PSScriptRoot 'CatalogMenuCacheHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'CATALOG_MENU_CACHE_HARNESS_COMPILE_FAILED' }
    & $taskExecutable
    if ($LASTEXITCODE -ne 0) { throw 'CATALOG_MENU_CACHE_HARNESS_FAILED' }
} finally {
    $taskResolvedTemp = [IO.Path]::GetFullPath($taskTempRoot).TrimEnd('\')
    if (-not $taskResolvedTemp.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolvedTemp) -notmatch '^ks-catalog-menu-cache-[0-9a-f]{32}$') {
        throw 'CATALOG_MENU_CACHE_UNSAFE_TEMP_CLEANUP'
    }
    if (Test-Path -LiteralPath $taskResolvedTemp) { Remove-Item -LiteralPath $taskResolvedTemp -Recurse -Force }
}
Write-Output ('CATALOG_MENU_CACHE_STATIC_CHECKS=' + $taskStaticChecks)
Write-Output 'CATALOG_MENU_CACHE_RESULT=PASS;DATABASE_ACCESSES=0'
