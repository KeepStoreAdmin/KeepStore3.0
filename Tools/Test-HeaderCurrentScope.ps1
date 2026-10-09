[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskBase = 'd5c55f64718b9e4468023ecc38a2161888891e2d'
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTemp = Join-Path $taskTempBase ('ks-header-scope-' + [Guid]::NewGuid().ToString('N'))
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
    $lines = @(git -C $taskRoot show ($taskBase + ':' + $path))
    if ($LASTEXITCODE -ne 0) { throw 'HEADER_BASE_READ_FAILED' }
    return ($lines -join "`n") + "`n"
}
function Search-Block([string]$source) {
    $start = $source.IndexOf('    Private Sub BindSearchCategories(', [StringComparison]::Ordinal)
    $end = $source.IndexOf('    Private Sub BindMobileCatalog(', $start, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -lt $start) { throw 'HEADER_METHOD_EXTRACTION_FAILED' }
    return $source.Substring($start, $end - $start)
}
$taskHeader = Read-Source 'Public/ui/controls/SiteHeader.ascx.vb'
$taskOriginal = Read-Base 'Public/ui/controls/SiteHeader.ascx.vb'
$taskBlock = Search-Block $taskHeader
Check-Source ($taskHeader.Replace($taskBlock, '') -ceq $taskOriginal.Replace((Search-Block $taskOriginal), '')) 'ONLY_HEADER_SEARCH_SCOPE_BLOCK_CHANGED'
Check-Source ($taskBlock -match 'CatalogTaxonomyResolver.Resolve\(sectors,') 'USES_EXISTING_PURE_RESOLVER'
Check-Source ($taskBlock -notmatch 'LoadCatalogMenu|MySql|Cache\.|Session\(|Response\.|Redirect|Request\.Form') 'NO_DUPLICATE_QUERY_CACHE_SESSION_OR_REDIRECT'
Check-Source ($taskBlock -match 'values.Length <> 1' -and $taskBlock -match 'NumberStyles.None') 'DUPLICATES_AND_INVALID_IDS_FAIL_NEUTRAL'
Check-Source ($taskBlock -match 'category.SettoriId = selectedSectorId AndAlso sector.Id = selectedSectorId') 'CATEGORY_SELECTION_HAS_AUTHORITATIVE_PARENT'
Check-Source ($taskBlock.Contains('Dim value As String = sector.DefaultUrl') -and $taskBlock.Contains('New ListItem(categoryText, category.DefaultUrl)')) 'SEARCH_OPTION_URLS_UNCHANGED'
Check-Source ($taskBlock.Contains('New ListItem("Tutti i settori", String.Empty)')) 'NEUTRAL_OPTION_UNCHANGED'
foreach ($path in @('App_Code/CatalogMenuProvider.vb', 'App_Code/CatalogTaxonomyResolver.vb', 'Page.master', 'Page.master.vb', 'Public/ui/controls/SiteHeader.ascx', 'Public/assets/keepstore/js/ks-page-flags.js')) {
    Check-Source ((Read-Source $path) -ceq (Read-Base $path)) ('UNCHANGED_' + [IO.Path]::GetFileName($path))
}
$taskBreadcrumb = Read-Source 'App_Code/ProductStructuredDataBuilder.vb'
$taskBreadcrumbType = [regex]::Match($taskBreadcrumb, '(?ms)^Public NotInheritable Class StorefrontBreadcrumbItem\b.*?^End Class').Value
if (-not $taskBreadcrumbType) { throw 'BREADCRUMB_SOURCE_EXTRACTION_FAILED' }
# Mechanical extraction of the actual runtime methods; no reimplementation or mock resolver.
$taskFixture = @"
Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web
Imports System.Web.UI.WebControls
Public Class HeaderCurrentScopeFixture
    Public Request As HttpRequest
    Public product_cat As New DropDownList()
    Public product_cat_mobile As New DropDownList()
$taskBlock
End Class
"@
$taskBreadcrumbFixture = "Option Strict On`nImports System`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text.RegularExpressions`nImports System.Web`n" + $taskBreadcrumbType
New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
    $taskFixturePath = Join-Path $taskTemp 'ExtractedHeaderMethods.vb'
    $taskBreadcrumbPath = Join-Path $taskTemp 'ExtractedBreadcrumbType.vb'
    [IO.File]::WriteAllText($taskFixturePath, $taskFixture)
    [IO.File]::WriteAllText($taskBreadcrumbPath, $taskBreadcrumbFixture)
    $taskMySql = Join-Path $taskRoot 'Bin/MySql.Data.dll'
    Copy-Item -LiteralPath $taskMySql -Destination $taskTemp
    $taskReferences = @('System.dll', 'System.Core.dll', 'System.Configuration.dll', 'System.Data.dll', 'System.Web.dll', 'System.Xml.dll') | ForEach-Object { Join-Path $taskFramework $_ }
    $taskExecutable = Join-Path $taskTemp 'HeaderCurrentScopeHarness.exe'
    & (Join-Path $taskFramework 'vbc.exe') /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$taskExecutable" ('/reference:' + (($taskReferences + $taskMySql) -join ',')) (Join-Path $taskRoot 'App_Code/CatalogMenuProvider.vb') (Join-Path $taskRoot 'App_Code/CatalogTaxonomyResolver.vb') $taskBreadcrumbPath $taskFixturePath (Join-Path $PSScriptRoot 'HeaderCurrentScopeHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'HEADER_SCOPE_HARNESS_COMPILE_FAILED' }
    & $taskExecutable
    if ($LASTEXITCODE -ne 0) { throw 'HEADER_SCOPE_HARNESS_FAILED' }
    $taskCacheExecutable = Join-Path $taskTemp 'CatalogMenuCacheRegression.exe'
    & (Join-Path $taskFramework 'vbc.exe') /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$taskCacheExecutable" ('/reference:' + (($taskReferences + $taskMySql) -join ',')) (Join-Path $taskRoot 'App_Code/CatalogMenuProvider.vb') (Join-Path $PSScriptRoot 'CatalogMenuCacheHarness.vb')
    if ($LASTEXITCODE -ne 0) { throw 'HEADER_CACHE_REGRESSION_COMPILE_FAILED' }
    & $taskCacheExecutable
    if ($LASTEXITCODE -ne 0) { throw 'HEADER_CACHE_REGRESSION_FAILED' }
} finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTemp).TrimEnd('\')
    if (-not $taskResolved.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolved) -notmatch '^ks-header-scope-[0-9a-f]{32}$') { throw 'HEADER_SCOPE_UNSAFE_TEMP_CLEANUP' }
    if (Test-Path -LiteralPath $taskResolved) { Remove-Item -LiteralPath $taskResolved -Recurse -Force }
}
Write-Output ('HEADER_CURRENT_SCOPE_STATIC_CHECKS=' + $taskStatic)
Write-Output 'HEADER_CURRENT_SCOPE_RESULT=PASS;DATABASE_ACCESSES=0'
