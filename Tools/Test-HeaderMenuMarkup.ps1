[CmdletBinding()]
param(
    [string]$CaptureDirectory,
    [string]$LocalBaseUrl,
    [switch]$AllowLocalCertificate,
    [switch]$CaptureOnly,
    [string]$CompareBefore,
    [string]$CompareAfter
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskBase = 'c4e1d25f9e4e47725461115fbc8d6ce17a20dd6a'
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
$taskHtmlLibrary = Join-Path $taskRoot 'Bin/HtmlAgilityPack.dll'
$taskChecks = 0
function Check([bool]$condition, [string]$name) {
    if (-not $condition) { throw $name }
    $script:taskChecks++
    Write-Output ('PASS ' + $name)
}
function Read-Source([string]$path) {
    return [IO.File]::ReadAllText((Join-Path $taskRoot $path)).Replace("`r`n", "`n")
}
function Read-Base([string]$path) {
    $lines = @(git -C $taskRoot show ($taskBase + ':' + $path))
    if ($LASTEXITCODE -ne 0) { throw 'MARKUP_BASE_READ_FAILED' }
    return ($lines -join "`n") + "`n"
}
function Extract([string]$source, [string]$start, [string]$end) {
    $a = $source.IndexOf($start, [StringComparison]::Ordinal)
    $b = $source.IndexOf($end, $a, [StringComparison]::Ordinal)
    if ($a -lt 0 -or $b -le $a) { throw 'MARKUP_EXTRACTION_FAILED' }
    return $source.Substring($a, $b - $a)
}

if ($CaptureDirectory) {
    # Capture only public menu markup, never page hidden fields, cookies or account data.
    if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'LOCAL_CAPTURE_REQUIRES_POWERSHELL_7' }
    $taskUri = [Uri]$LocalBaseUrl
    if ($taskUri.Scheme -ne 'https' -or $taskUri.UserInfo -or $taskUri.Query -or $taskUri.Fragment) { throw 'LOCAL_CAPTURE_URL_INVALID' }
    $taskAddresses = @([Net.Dns]::GetHostAddresses($taskUri.DnsSafeHost))
    if (-not $taskAddresses.Count -or @($taskAddresses | Where-Object { -not [Net.IPAddress]::IsLoopback($_) }).Count) { throw 'LOCAL_CAPTURE_REQUIRES_LOOPBACK' }
    $taskCapturePath = [IO.Path]::GetFullPath($CaptureDirectory).TrimEnd('\')
    if ($taskCapturePath.StartsWith($taskRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'CAPTURE_MUST_BE_OUTSIDE_REPOSITORY' }
    if (Test-Path -LiteralPath $taskCapturePath) { throw 'CAPTURE_DIRECTORY_ALREADY_EXISTS' }
    New-Item -ItemType Directory -Path $taskCapturePath | Out-Null
    Add-Type -Path $taskHtmlLibrary
    $taskRoutes = [ordered]@{ home = 'Default.aspx'; catalog = 'articoli.aspx?st=2&ct=35'; pdp = 'articolo.aspx?id=21906' }
    foreach ($entry in $taskRoutes.GetEnumerator()) {
        $taskUrl = [Uri]::new($taskUri, $entry.Value)
        try {
            $taskResponse = Invoke-WebRequest -Uri $taskUrl -NoProxy -SkipCertificateCheck:$AllowLocalCertificate -MaximumRedirection 0 -TimeoutSec 180 -SkipHttpErrorCheck
        } catch { throw 'LOCAL_CAPTURE_TRANSPORT_FAILED' }
        if ($taskResponse.StatusCode -ne 200) {
            $taskCompilerCode = [regex]::Match([string]$taskResponse.Content, '\bBC[0-9]{5}\b').Value
            throw ('LOCAL_CAPTURE_HTTP_' + [int]$taskResponse.StatusCode + ';COMPILER=' + $taskCompilerCode)
        }
        $taskDocument = [HtmlAgilityPack.HtmlDocument]::new()
        $taskDocument.LoadHtml($taskResponse.Content)
        $taskDesktop = $taskDocument.DocumentNode.SelectSingleNode("//*[contains(concat(' ',normalize-space(@class),' '),' ks-header-all-categories ')]")
        $taskMobile = $taskDocument.DocumentNode.SelectSingleNode("//*[@id='ks-mobile-catalog-root']")
        $taskSelects = @($taskDocument.DocumentNode.SelectNodes("//select[contains(@class,'ks-search-category-select')]"))
        if ($null -eq $taskDesktop -or $null -eq $taskMobile -or $taskSelects.Count -ne 2) { throw 'LOCAL_CAPTURE_MENU_MISSING' }
        $taskMarkup = $taskDesktop.OuterHtml + $taskMobile.OuterHtml + (($taskSelects | ForEach-Object { $_.OuterHtml }) -join '')
        [IO.File]::WriteAllText((Join-Path $taskCapturePath ($entry.Key + '.html')), $taskMarkup, [Text.UTF8Encoding]::new($false))
        Write-Output ('CAPTURE ' + $entry.Key + ' HTTP=200 ELEMENTS=' + @($taskDocument.DocumentNode.SelectNodes('//*')).Count)
    }
    if ($CaptureOnly) { return }
}

$taskMarkup = Read-Source 'Public/ui/controls/SiteHeader.ascx'
$taskOriginalMarkup = Read-Base 'Public/ui/controls/SiteHeader.ascx'
$taskHeader = Read-Source 'Public/ui/controls/SiteHeader.ascx.vb'
$taskOriginalHeader = Read-Base 'Public/ui/controls/SiteHeader.ascx.vb'
$taskSpan = '<span><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>'
$taskStart = '                        <div id="ks-mobile-catalog-root"'
$taskEnd = '                    </li>' + "`n" + '                    <li class="nav-mb-item"><a href="articoli.aspx?inpromo=1"'
$taskOriginalBlock = Extract $taskOriginalMarkup $taskStart $taskEnd
$taskBlock = Extract $taskMarkup $taskStart $taskEnd
# Whitelist the exact presentation-only transformation; all other ASCX bytes must match.
$taskTipLink = '<a class="sub-nav-link body-md-2" href=''<%# Eval("DefaultUrl") %>''>'
$taskExpectedBlock = [regex]::Replace($taskOriginalBlock, [regex]::Escape($taskTipLink) + '\s*' + [regex]::Escape($taskSpan) + '\s*</a>', $taskTipLink + '<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></a>')
$taskExpectedBlock = [regex]::Replace($taskExpectedBlock, '>\s+<', '><').TrimEnd() + "`n"
Check ($taskBlock -ceq $taskExpectedBlock) 'MOBILE_ONLY_WHITESPACE_AND_TIPOLOGY_SPAN_REMOVED'
Check ($taskMarkup.Replace($taskBlock, '') -ceq $taskOriginalMarkup.Replace($taskOriginalBlock, '')) 'OTHER_ASCX_MARKUP_IDENTICAL'
$taskExpectedHeader = $taskOriginalHeader.Replace("ks-header-catalog-tipology-link'><span>", "ks-header-catalog-tipology-link'>")
$taskExpectedHeader = $taskExpectedHeader.Replace('sb.Append(HttpUtility.HtmlEncode(If(tipologia.Descrizione, String.Empty)))' + "`n" + '                            sb.Append("</span></a>")', 'sb.Append(HttpUtility.HtmlEncode(If(tipologia.Descrizione, String.Empty)))' + "`n" + '                            sb.Append("</a>")')
Check ($taskHeader -ceq $taskExpectedHeader) 'ONLY_DESKTOP_TIPOLOGY_SPAN_REMOVED'
foreach ($path in @('App_Code/CatalogMenuProvider.vb', 'App_Code/CatalogTaxonomyResolver.vb', 'Page.master', 'Page.master.vb', 'Public/assets/keepstore/css/theme-overrides.css', 'Public/assets/keepstore/css/styles.css', 'Public/assets/keepstore/js/ks-page-flags.js', 'Public/assets/keepstore/js/main.js')) {
    Check ((Read-Source $path) -ceq (Read-Base $path)) ('UNCHANGED_' + [IO.Path]::GetFileName($path))
}
Check ($taskBlock -match 'OnItemDataBound="rptNavSettoriMobile_ItemDataBound"' -and $taskBlock -match 'OnItemDataBound="rptNavCategorieMobile_ItemDataBound"') 'REPEATER_BINDINGS_UNCHANGED'
Check ($taskBlock -match 'aria-hidden="true"' -and $taskBlock -match 'data-bs-toggle="collapse"') 'BOOTSTRAP_DECORATIVE_ICONS_UNCHANGED'

$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTemp = Join-Path $taskTempBase ('ks-header-markup-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
    $taskMySql = Join-Path $taskRoot 'Bin/MySql.Data.dll'
    Copy-Item -LiteralPath $taskMySql, $taskHtmlLibrary -Destination $taskTemp
    $taskReferences = @('System.dll', 'System.Core.dll', 'System.Configuration.dll', 'System.Data.dll', 'System.Web.dll', 'System.Xml.dll') | ForEach-Object { Join-Path $taskFramework $_ }
    function Compile-Run([string]$name, [string[]]$sources, [string[]]$runArguments = @()) {
        $taskExecutable = Join-Path $taskTemp ($name + '.exe')
        & (Join-Path $taskFramework 'vbc.exe') /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$taskExecutable" ('/reference:' + (($taskReferences + $taskMySql + $taskHtmlLibrary) -join ',')) @sources
        if ($LASTEXITCODE -ne 0) { throw ('COMPILE_FAILED_' + $name) }
        & $taskExecutable @runArguments
        if ($LASTEXITCODE -ne 0) { throw ('HARNESS_FAILED_' + $name) }
    }
    $taskDesktopStart = '    Private Function BuildDesktopCatalogMegaMenuHtml('
    $taskDesktopEnd = '    Private Function SafeString('
    $taskDesktopMethods = Extract $taskHeader $taskDesktopStart $taskDesktopEnd
    $taskOriginalMethods = Extract $taskOriginalHeader $taskDesktopStart $taskDesktopEnd
    $taskScope = Extract $taskHeader '    Private Sub BindSearchCategories(' '    Private Sub BindMobileCatalog('
    $taskFixture = @"
Option Strict On
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI.WebControls
Public Class HeaderMenuMarkupFixture
$taskDesktopMethods
End Class
Public Class HeaderMenuMarkupBaseline
$taskOriginalMethods
End Class
Public Class HeaderCurrentScopeFixture
    Public Request As HttpRequest
    Public product_cat As New DropDownList()
    Public product_cat_mobile As New DropDownList()
$taskScope
End Class
"@
    $taskBreadcrumb = Read-Source 'App_Code/ProductStructuredDataBuilder.vb'
    $taskBreadcrumbType = [regex]::Match($taskBreadcrumb, '(?ms)^Public NotInheritable Class StorefrontBreadcrumbItem\b.*?^End Class').Value
    if (-not $taskBreadcrumbType) { throw 'BREADCRUMB_EXTRACTION_FAILED' }
    $taskFixturePath = Join-Path $taskTemp 'ExtractedMethods.vb'
    $taskBreadcrumbPath = Join-Path $taskTemp 'ExtractedBreadcrumb.vb'
    [IO.File]::WriteAllText($taskFixturePath, $taskFixture)
    [IO.File]::WriteAllText($taskBreadcrumbPath, "Imports System`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text.RegularExpressions`nImports System.Web`n" + $taskBreadcrumbType)
    $taskCommon = @((Join-Path $taskRoot 'App_Code/CatalogMenuProvider.vb'), (Join-Path $taskRoot 'App_Code/CatalogTaxonomyResolver.vb'), $taskFixturePath, $taskBreadcrumbPath)
    $taskCompareArguments = @()
    if ($CompareBefore -or $CompareAfter) {
        if (-not $CompareBefore -or -not $CompareAfter) { throw 'BOTH_CAPTURE_DIRECTORIES_REQUIRED' }
        $taskCompareArguments = @($CompareBefore, $CompareAfter)
    }
    Compile-Run 'HeaderMenuMarkup' ($taskCommon + (Join-Path $PSScriptRoot 'HeaderMenuMarkupHarness.vb')) $taskCompareArguments
    Compile-Run 'HeaderCurrentScopeRegression' ($taskCommon + (Join-Path $PSScriptRoot 'HeaderCurrentScopeHarness.vb'))
    Compile-Run 'CatalogMenuCacheRegression' @((Join-Path $taskRoot 'App_Code/CatalogMenuProvider.vb'), (Join-Path $PSScriptRoot 'CatalogMenuCacheHarness.vb'))
} finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTemp).TrimEnd('\')
    if (-not $taskResolved.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolved) -notmatch '^ks-header-markup-[0-9a-f]{32}$') { throw 'UNSAFE_MARKUP_TEMP_CLEANUP' }
    if (Test-Path -LiteralPath $taskResolved) { Remove-Item -LiteralPath $taskResolved -Recurse -Force }
}
Write-Output ('HEADER_MENU_MARKUP_STATIC_CHECKS=' + $taskChecks)
Write-Output 'HEADER_MENU_MARKUP_RESULT=PASS;DATABASE_WRITES=0;BROWSER_NOT_COVERED'
