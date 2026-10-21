[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'HOME_EDITORIAL_REQUIRES_WINDOWS_POWERSHELL_51' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if (!$EvidenceDirectory.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $EvidenceDirectory)) { throw 'HOME_EDITORIAL_REQUIRES_NEW_TEMP_EVIDENCE' }
$work = Join-Path $tempRoot ('ks-home-editorial-compile-' + [Guid]::NewGuid().ToString('N'))
$checks = New-Object 'Collections.Generic.List[object]'
$fixtures = New-Object 'Collections.Generic.List[object]'
$flags = [Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
$utf8 = New-Object Text.UTF8Encoding($false)
function Check([string]$name, [bool]$pass) {
    $checks.Add([pscustomobject]@{Name=$name;Pass=$pass})
    if (!$pass) { throw ('HOME_EDITORIAL_ASSERT: ' + $name) }
}
function Write-Json([string]$path, $value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 12), $utf8) }
function Source-Function([string]$text, [string]$name) {
    $m = [regex]::Match($text, '(?ms)^    (?:Private|Protected) (?:Shared )?(?:Function|Sub) ' + $name + '\b.*?^    End (?:Function|Sub)')
    if (!$m.Success) { throw ('HOME_EDITORIAL_METHOD_MISSING: ' + $name) }
    return $m.Value
}
try {
    New-Item -ItemType Directory -Path $EvidenceDirectory, $work | Out-Null
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName Microsoft.VisualBasic
    $vb = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
    $aspx = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    $provider = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code\CatalogMenuProvider.vb'))
    $models = [regex]::Match($provider, '(?s)Public Class CatalogMenuSector.*?(?=Public Module CatalogMenuProvider)').Value
    $selection = [regex]::Match($vb, '(?ms)^    Private NotInheritable Class HomeEditorialNavigation.*?(?=^    Protected Function HomeSectorMicrocopy)').Value
    Check 'actual model and complete selection methods found' ($models.Length -gt 0 -and $selection.Length -gt 0)
    $methods = @('HomeSectorMicrocopy','SafeText','RenderHomeSectorMedia','HomeSectorInitial','ResolveHeroMode','ApplyHeroMode','ApplyHomeComposition') |
        ForEach-Object { Source-Function $vb $_ }
    # Compile the verbatim pure selection/render/composition methods, not a second selector.
    # Only unrelated page controls are stand-ins; no Page_Load/BindHome/DB lifecycle is invoked.
    $controlFields = @'
    Public Slide_Show_Container As New HtmlGenericControl()
    Public HeroSliderWrap As New HtmlGenericControl()
    Public HeroSideWrap As New Panel()
    Public rptSideBanners As New Repeater()
    Public HomeHeroSection As New HtmlGenericControl()
    Public HomeIntroSection As New HtmlGenericControl()
    Public HomeHeroShell As New HtmlGenericControl()
    Public HomeWidePromoSection As New HtmlGenericControl()
    Public HomeTrustSection As New HtmlGenericControl()
'@
    $code = "Imports System`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Web`nImports System.Web.UI.HtmlControls`nImports System.Web.UI.WebControls`n" +
        $models + "`nPublic Class HomeEditorialFixture`n" + $controlFields + "`n" + $selection + "`n" + ($methods -join "`n") + "`nEnd Class"
    $compiler = New-Object Microsoft.VisualBasic.VBCodeProvider
    $parameters = New-Object CodeDom.Compiler.CompilerParameters
    $parameters.GenerateInMemory = $true
    $parameters.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict-'
    $parameters.TempFiles = New-Object CodeDom.Compiler.TempFileCollection($work, $false)
    foreach ($assembly in @('System.dll','System.Core.dll','System.Web.dll')) { [void]$parameters.ReferencedAssemblies.Add($assembly) }
    $compiled = $compiler.CompileAssemblyFromSource($parameters, $code)
    if ($compiled.Errors.HasErrors) { throw ('HOME_EDITORIAL_VB_COMPILE: ' + (($compiled.Errors | ForEach-Object {$_.ErrorText}) -join '; ')) }
    $type = $compiled.CompiledAssembly.GetType('HomeEditorialFixture', $true)
    $sectorType = $compiled.CompiledAssembly.GetType('CatalogMenuSector', $true)
    $listType = [Collections.Generic.List[object]].GetGenericTypeDefinition().MakeGenericType($sectorType)
    $page = [Activator]::CreateInstance($type)
    function Call([string]$name, [object[]]$arguments) { return ,$type.GetMethod($name,$flags).Invoke($page,$arguments) }
    function Rows($navigation, [string]$area) { return ,$navigation.GetType().GetField($area).GetValue($navigation) }
    function Ids($rows) { return (@($rows | ForEach-Object {$_.Id}) -join ',') }
    function Sectors([string]$tenant, [int]$count) {
        $items = [Activator]::CreateInstance($listType)
        for ($i=0; $i -lt $count; $i++) {
            $s = [Activator]::CreateInstance($sectorType)
            $s.Id = 100 - $i # Deliberately not numeric order: the provider order must survive.
            $s.Descrizione = if ($tenant -eq 'Tech') { 'Tech - Componenti & accessori <' + $i + '>' } else { 'Food - Dispensa & prodotti freschi <' + $i + '>' }
            $s.DefaultUrl = 'articoli.aspx?st=' + $s.Id
            [void]$items.Add($s)
        }
        return ,$items
    }
    function Fragment([string]$id, $data, [bool]$intro) {
        $m = [regex]::Match($aspx, '(?s)<section id="' + $id + '"(?=\s|>).*?</section>')
        if (!$m.Success) { throw ('HOME_EDITORIAL_SECTION_MISSING: ' + $id) }
        $html = $m.Value
        $html = [regex]::Replace($html, '(?s)<asp:Repeater\b[^>]*>(.*?)</asp:Repeater>', [Text.RegularExpressions.MatchEvaluator]{
            param($repeater)
            $template = [regex]::Match($repeater.Groups[1].Value, '(?s)<ItemTemplate>(.*?)</ItemTemplate>').Groups[1].Value
            $parts = foreach ($sector in $data) {
                [regex]::Replace($template, '(?s)<%#(.*?)%>', [Text.RegularExpressions.MatchEvaluator]{
                    param($binding)
                    $expression = $binding.Groups[1].Value.Trim()
                    switch -Regex ($expression) {
                        '^Eval\("DefaultUrl"\)$' { return [string]$sector.DefaultUrl }
                        '^RenderHomeSectorMedia\(' { return [string](Call 'RenderHomeSectorMedia' @($sector.ImgUrl,$sector.Descrizione)) }
                        '^SafeText\(HomeSectorMicrocopy\(' { return [string](Call 'SafeText' @((Call 'HomeSectorMicrocopy' (,$sector.Categories)))) }
                        '^SafeText\(Eval\("(DefaultUrl|Descrizione)"\)\)$' { return [string](Call 'SafeText' @($sector.($Matches[1]))) }
                        default { throw 'HOME_EDITORIAL_UNSUPPORTED_TEMPLATE_BINDING' }
                    }
                })
            }
            return ($parts -join '')
        })
        if ($intro) { $html = [regex]::Replace($html, '(?s)<a\b[^>]*id="HomeCategoriesCatalogLink"[^>]*>.*?</a>', '') }
        $html = $html -replace '\srunat="server"','' -replace '\svisible="false"',''
        if ($html -match '<asp:|<%') { throw 'HOME_EDITORIAL_UNEXPANDED_FIXTURE_MARKUP' }
        return $html
    }
    foreach ($tenant in @('Tech','Food')) {
        foreach ($count in @(0,1,2,4,9,12,13,14,15,16,17,18,19,27)) {
            $source = Sectors $tenant $count
            $before = Ids $source
            $navigation = Call 'BuildHomeEditorialNavigation' (,$source)
            $main = Rows $navigation 'MainSectors'; $collection = Rows $navigation 'CollectionSectors'; $bottom = Rows $navigation 'BottomSectors'
            Check "$tenant/$count main count" ($main.Count -eq [Math]::Min(12,$count))
            Check "$tenant/$count collection complete triplet" ($collection.Count -eq $(if($count -ge 15){3}else{0}))
            Check "$tenant/$count bottom complete triplet" ($bottom.Count -eq $(if($count -ge 18){3}else{0}))
            $all = @($main) + @($collection) + @($bottom)
            Check "$tenant/$count no duplicate editorial ID" (@($all | Select-Object -ExpandProperty Id -Unique).Count -eq $all.Count)
            Check "$tenant/$count provider order, URLs and identities" ((Ids $all) -eq (Ids @($source | Select-Object -First $all.Count)) -and @($all | Where-Object {$_.DefaultUrl -cne ('articoli.aspx?st=' + $_.Id) -or !$_.Descrizione.StartsWith($tenant)}).Count -eq 0)
            Check "$tenant/$count hero unchanged first nine" ((Ids (Rows $navigation 'HeroSectors')) -eq (Ids @($source | Select-Object -First 9)))
            Check "$tenant/$count guide unchanged first five" ((Ids (Rows $navigation 'SearchSectors')) -eq (Ids @($source | Select-Object -First 5)))
            Check "$tenant/$count source unmodified" ((Ids $source) -eq $before)
            $html = ''
            if ($main.Count) { $html += Fragment 'HomeMainCategoriesSection' $main $false }
            if ($collection.Count) { $html += Fragment 'HomeCollectionSection' $collection $false }
            if ($bottom.Count) { $html += Fragment 'HomeBottomPromoSection' $bottom $false }
            # This fixture intentionally has no banners/products. The real intro catalog CTA is preserved.
            $intro = [regex]::Match($aspx, '(?s)<section id="HomeIntroSection"(?=\s|>).*?</section>').Value
            $intro = [regex]::Replace($intro, '<asp:Literal ID="litHomeIntroName"[^>]*/>', $tenant + ' - negozio sintetico')
            $intro = [regex]::Replace($intro, '<asp:Literal ID="litHomeIntroDescription"[^>]*/>', 'Catalogo sintetico, nessun dato operativo.')
            $intro = $intro -replace '\srunat="server"','' -replace '\svisible="false"',''
            if ($main.Count) { $html = $html -replace '(?s)<a\b[^>]*id="HomeCategoriesCatalogLink"[^>]*>.*?</a>','' }
            $html = $intro + $html
            Check "$tenant/$count no empty server container" (($collection.Count -gt 0) -eq $html.Contains('id="HomeCollectionSection"') -and ($bottom.Count -gt 0) -eq $html.Contains('id="HomeBottomPromoSection"'))
            Check "$tenant/$count catalog reachable without banners/products" ($html -match 'href="articoli.aspx"')
            Check "$tenant/$count encoded labels" (!$html.Contains('<' + [string]([Math]::Max(0,$count-1)) + '>') -and !$html.Contains('<asp:'))
            $file = "$tenant-$count.html"
            [IO.File]::WriteAllText((Join-Path $EvidenceDirectory $file), $html, $utf8)
            $fixtures.Add([pscustomobject]@{Tenant=$tenant;Count=$count;Main=$main.Count;Collection=$collection.Count;Bottom=$bottom.Count;File=$file;ExpectedIds=@($all|ForEach-Object{$_.Id})})
        }
        $valid = Sectors $tenant 27
        $dirty = [Activator]::CreateInstance($listType)
        [void]$dirty.Add($null)
        foreach ($bad in @(@{Id=0;Name='invalid';Url='articoli.aspx?st=0'},@{Id=-1;Name='invalid';Url='articoli.aspx?st=-1'},@{Id=501;Name=' ';Url='articoli.aspx?st=501'},@{Id=502;Name=$null;Url='articoli.aspx?st=502'},@{Id=503;Name='invalid';Url='https://other.invalid/articoli.aspx?st=503'},@{Id=504;Name='invalid';Url='articoli.aspx?st=504&ct=1'},@{Id=505;Name='invalid';Url=''})) {
            $s = [Activator]::CreateInstance($sectorType); $s.Id=$bad.Id; $s.Descrizione=$bad.Name; $s.DefaultUrl=$bad.Url; [void]$dirty.Add($s)
        }
        foreach ($s in $valid) { [void]$dirty.Add($s); [void]$dirty.Add($s) }
        $cleanResult = Call 'BuildHomeEditorialNavigation' (,$valid)
        $dirtyResult = Call 'BuildHomeEditorialNavigation' (,$dirty)
        foreach ($area in @('MainSectors','CollectionSectors','BottomSectors','HeroSectors','SearchSectors')) { Check "$tenant invalid/name/URL/duplicate rejection $area" ((Ids (Rows $cleanResult $area)) -eq (Ids (Rows $dirtyResult $area))) }
    }
    $empty = Call 'BuildHomeEditorialNavigation' @($null)
    foreach ($area in @('MainSectors','CollectionSectors','BottomSectors','HeroSectors','SearchSectors')) { Check "null provider $area" ((Rows $empty $area).Count -eq 0) }
    $a = Sectors 'Tech' 27; $b = Sectors 'Food' 16
    $a1 = Call 'BuildHomeEditorialNavigation' (,$a); $b1 = Call 'BuildHomeEditorialNavigation' (,$b); $a2 = Call 'BuildHomeEditorialNavigation' (,$a)
    foreach ($area in @('MainSectors','CollectionSectors','BottomSectors','HeroSectors','SearchSectors')) {
        Check "A/B/A deterministic $area" ((Ids (Rows $a1 $area)) -eq (Ids (Rows $a2 $area)))
        Check "no cross-tenant labels $area" (@((Rows $a2 $area) | Where-Object {!$_.Descrizione.StartsWith('Tech')}).Count -eq 0 -and @((Rows $b1 $area) | Where-Object {!$_.Descrizione.StartsWith('Food')}).Count -eq 0)
        Check "no shared result lists $area" (![object]::ReferenceEquals((Rows $a1 $area),(Rows $b1 $area)))
    }
    foreach ($mode in @('none','hero-only','full')) {
        foreach ($products in @($false,$true)) {
            $page = [Activator]::CreateInstance($type)
            [void](Call 'ApplyHeroMode' @($mode,$(if($mode -eq 'full'){1}else{0})))
            [void](Call 'ApplyHomeComposition' @($products))
            Check "banner/product independent $mode/$products" ($page.HomeIntroSection.Visible -eq ($mode -eq 'none') -and $page.HomeHeroSection.Visible -eq ($mode -ne 'none') -and $page.HomeWidePromoSection.Visible -eq ($mode -ne 'none' -and !$products))
        }
    }
    # Supplemental wiring/source checks; runtime behavior above uses the actual compiled methods.
    $bind = Source-Function $vb 'BindHome'
    Check 'one provider load and one composition per BindHome' ([regex]::Matches($bind,'CatalogMenuProvider.LoadCatalogMenuCached\(').Count -eq 1 -and [regex]::Matches($bind,'BuildHomeEditorialNavigation\(').Count -eq 1 -and !$bind.Contains('SelectHomeEditorialSectors('))
    foreach ($pair in @(@('sectorRows','MainSectors'),@('heroSectorRows','HeroSectors'),@('collectionRows','CollectionSectors'),@('bottomRows','BottomSectors'),@('searchRows','SearchSectors'))) { Check ('binding ' + $pair[0]) ($bind.Contains('= editorialNavigation.' + $pair[1])) }
    Check 'secondary server visibility follows actual rows' ($bind.Contains('HomeCollectionSection.Visible = (collectionRows.Count > 0)') -and $bind.Contains('HomeBottomPromoSection.Visible = (bottomRows.Count > 0)'))
    Check 'inactive sectors remain excluded by unchanged provider predicate' ($provider.Contains('FROM settori WHERE COALESCE(Abilitato,0)=1 ORDER BY'))
    Check 'correct sector heading and existing catalog CTA' ($aspx.Contains('>Esplora i reparti</h5>') -and $aspx.Contains('id="HomeCategoriesCatalogLink"'))
    foreach ($id in @('HomeCollectionSection','HomeBottomPromoSection')) {
        $section = [regex]::Match($aspx, '<section id="' + $id + '"[^>]*>').Value
        Check ($id + ' reuses existing keyboard focus and named region') ($section.Contains('ks-home-adaptive-discovery') -and $section.Contains('aria-label='))
    }
    $report = [pscustomobject]@{Passed=$checks.Count;Failed=0;Checks=$checks;Fixtures=$fixtures;Scope='Verbatim VB methods compiled in-memory on Framework 4.x; real ASPX editorial templates. No complete WebForms lifecycle, SQL, IIS or operational tenant. Inactive filtering is an unchanged provider-source contract.';SourceHashes=@{HomeVB=(Get-FileHash (Join-Path $RepositoryRoot 'Default.aspx.vb') -Algorithm SHA256).Hash;HomeASPX=(Get-FileHash (Join-Path $RepositoryRoot 'Default.aspx') -Algorithm SHA256).Hash;Provider=(Get-FileHash (Join-Path $RepositoryRoot 'App_Code\CatalogMenuProvider.vb') -Algorithm SHA256).Hash}}
    Write-Json (Join-Path $EvidenceDirectory 'test-report.json') $report
    Write-Output ('HOME_EDITORIAL_PASS=' + $checks.Count)
    Write-Output ('HOME_EDITORIAL_FIXTURES=' + $fixtures.Count)
} finally {
    if ($compiler) { $compiler.Dispose() }
    if ((Test-Path -LiteralPath $work) -and [IO.Path]::GetFullPath($work).StartsWith($tempRoot + '\ks-home-editorial-compile-', [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $work -Recurse -Force }
}
