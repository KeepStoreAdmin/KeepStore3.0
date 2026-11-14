[CmdletBinding()]
param()

# KS-A04-HOME-DEADCODE-1A - codice morto della HOME e file mai referenziati.
# Controllo statico con mutazioni: i membri e i file rimossi non devono tornare, i contratti che SEMBRANO morti ma non lo sono
# (hook letti da JavaScript, id usati dai test, metodi compilati dai harness) devono restare.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-Repo([string]$relativePath) { return ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) -replace "`r`n", "`n") }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$removedMembers = @('BindThreeColumnZone', 'BuildSlidesTable', 'BindLowerBlock', 'CommitBusinessKeys', 'CommitDisplayKeys', 'RenderRowCardFromRow', 'RenderRowCard', 'RenderBigCard',
    'RenderCenterSaleBadge', 'ShuffleTable', 'TakeDistinctRows', 'PreviewDistinctRows', 'PreviewDiverseRows', 'MergeSideBannerRows', 'ConvertHeroRowsToSideRows', 'ResolveBannerImage',
    'ProductImagePlaceholder', 'GetFeaturedPool', 'GetMostViewedPool', 'GetTopRatedPool', 'GetPureTopSellingPool', 'GetCurrentYearSellingPool', 'ProductImageFull', 'AvailabilityPercent')
$removedMarkup = @('HomeLegacyEditorialSection', 'HomeLowerColumnsSection', 'rptFeatureLeft', 'rptFeatureCenter', 'rptFeatureRight', 'rptToprateLeft', 'rptToprateCenter', 'rptToprateRight',
    'rptOnSaleLeft', 'rptOnSaleCenter', 'rptOnSaleRight', 'rptTop20Slides', 'rptFeaturedProductsSlides', 'rptTopSellingProductSlides', 'rptOnSaleProductSlides', 'data-ks-i18n')
$removedFiles = @('Public/ui/controls/HomeHeroSlider.ascx', 'Public/ui/controls/HomeHeroSlider.ascx.vb', 'Public/ui/controls/HomeIconBoxes.ascx', 'Public/ui/controls/HomeIconBoxes.ascx.vb',
    'Public/ui/controls/HomeSideBanner.ascx', 'Public/ui/controls/HomeSideBanner.ascx.vb', 'Public/ui/controls/HomeSideBanners.ascx', 'Public/ui/controls/HomeSideBanners.ascx.vb',
    'Public/ui/controls/HomeFeaturedProducts.ascx', 'Public/ui/controls/HomeFeaturedProducts.ascx.vb', 'Public/ui/controls/HomeDepartmentsMenu.ascx', 'Public/ui/controls/HomeDepartmentsMenu.ascx.vb',
    'Public/assets/keepstore/js/home-slideshow.js', 'Public/assets/keepstore/js/keepstore-init.js', 'Public/assets/keepstore/js/keepstore.js', 'search-suggest.ashx', 'App_Code/SearchSuggest.vb',
    'Public/ui/master/Site.master', 'Public/ui/master/Site.master.vb')
# contratti: sembrano morti ma sono letti da JavaScript, da altre pagine o compilati dai harness
$keepMarkup = @('KsLocalAiSearch130', 'HomeRecentlyViewedSection', 'HomeLegacyBestSection', 'HomeWidePromoSection', 'HomeCategoriesCatalogLink', 'HeroSideWrap', 'ksHomeCartStatus',
    'data-ks-async-cart-endpoint', 'data-ks-async-cart-token', 'data-ks-async-cart-status', 'HomeBottomPromoSection', 'HomeCollectionSection')
$keepMembers = @('HomeAsyncCartToken', 'BuildHomeCommercialActivitySql', 'BuildHomeFiscalCompanyScopeSql', 'TakeRankedHomeRows', 'TakeHomeArrivalsRows', 'LoadHomeCatalogDiscovery',
    'HasOnlyInformativeHomeArrivals', 'SelectHomeDirectCategories', 'BuildHomeEditorialNavigation', 'SelectHomeEditorialSectors', 'ApplyHeroMode', 'ResolveHeroMode', 'BindHomeIntroNavigation',
    'ApplyHomeComposition', 'SortAuthorizedDealRows', 'FilterAuthorizedPromotionRows', 'GetBusinessKey', 'GetDisplayKey', 'BuildDisplayStem', 'FilterBrandRows', 'HomeSectorInitial',
    'TakeDiverseRows', 'CollectDistinctRows', 'RenderDealCard', 'RenderGridCard', 'RenderCornerBadgeStack')

function Test-MembersRemoved([string]$vb) {
    foreach ($n in $removedMembers) { if ([regex]::IsMatch($vb, '(?m)^\s*(?:Private|Protected|Public|Friend)\s+(?:Shared\s+)?(?:Function|Sub)\s+' + [regex]::Escape($n) + '\s*\(')) { return $false } }
    $objectOverloads = [regex]::Matches($vb, '(?m)^\s*(?:Protected|Private)\s+Function\s+(?:CurrentPrice|SavingsAmount|ShowDiscount|DiscountPercent|TryGetValidPromoPrice|IsRefurbished)\(ByVal (?:priceIvato As Object|row As DataRowView)')
    return ($objectOverloads.Count -eq 0 -and $vb -notmatch 'Private Shared ReadOnly Rng\b' -and $vb -notmatch 'HomeLegacyEditorialSection' -and $vb -notmatch 'HomeLowerColumnsSection')
}
function Test-MarkupRemoved([string]$aspx) {
    foreach ($n in $removedMarkup) { if ($aspx.Contains($n)) { return $false } }
    return $true
}
function Test-ContractsKept([string]$aspx, [string]$vb) {
    foreach ($n in $keepMarkup) { if (-not $aspx.Contains($n)) { return $false } }
    foreach ($n in $keepMembers) { if (-not [regex]::IsMatch($vb, '(?m)^\s*(?:Private|Protected|Public|Friend)\s+(?:Shared\s+)?(?:Function|Sub|ReadOnly Property)\s+' + [regex]::Escape($n) + '\b')) { return $false } }
    return $true
}
function Test-BadgeStack([string]$vb) {
    $fn = [regex]::Match($vb, '(?s)Private Function RenderCornerBadgeStack\(.*?End Function').Value
    $calls = [regex]::Matches($vb, 'RenderCornerBadgeStack\(row, True(?:, False)?\)')
    return ($fn -match 'RenderCornerBadgeStack\(ByVal row As DataRow,\s+ByVal includeSale As Boolean\) As String' -and $fn -match 'badges\.Append\(RenderSaleBadge\(row\)\)' -and
            $fn -notmatch 'useWideSaleBadge' -and $calls.Count -eq 2 -and (@($calls | Where-Object { $_.Value -match ', False' }).Count -eq 0))
}
function Test-NoDanglingReferences() {
    $pattern = '\b(?:HomeHeroSlider|HomeIconBoxes|HomeSideBanners?|HomeFeaturedProducts|HomeDepartmentsMenu)\b|home-slideshow\.js|keepstore-init\.js|search-suggest\.ashx|ui/master/Site\.master'
    $files = @(& git -C $repoRoot ls-files -- '*.aspx' '*.ascx' '*.vb' '*.master' '*.js' '*.config') | Where-Object { $_ -notmatch '^(docs|Doc|Tools)/' -and $_ -notmatch '^Public/Export' }
    foreach ($f in $files) {
        $p = Join-Path $repoRoot $f
        if (-not (Test-Path -LiteralPath $p)) { continue }
        if ([regex]::IsMatch([IO.File]::ReadAllText($p), $pattern)) { return $false }
    }
    return $true
}

$vb = Read-Repo 'Default.aspx.vb'
$aspx = Read-Repo 'Default.aspx'
Assert-Source (Test-MembersRemoved $vb) 'S01_DEAD_MEMBERS_AND_OBJECT_OVERLOADS_ARE_GONE'
Assert-Source (Test-MarkupRemoved $aspx) 'S02_HIDDEN_SECTIONS_REPEATERS_AND_I18N_MARKERS_ARE_GONE'
$filesGone = $true
foreach ($f in $removedFiles) { if (Test-Path -LiteralPath (Join-Path $repoRoot $f)) { $filesGone = $false } }
Assert-Source $filesGone 'S03_UNREFERENCED_CONTROLS_SCRIPTS_HANDLER_AND_MASTER_ARE_GONE'
Assert-Source (Test-ContractsKept $aspx $vb) 'S04_LOOKS_DEAD_BUT_IS_CONTRACT_STAYS'
Assert-Source (Test-BadgeStack $vb) 'S05_CORNER_BADGE_STACK_WITHOUT_THE_WIDE_VARIANT'
Assert-Source (Test-NoDanglingReferences) 'S06_NO_RUNTIME_FILE_STILL_REFERENCES_A_DELETED_ONE'

$m = $vb + "`n    Private Sub BindLowerBlock(ByVal x As Object)`n    End Sub`n"
Assert-Detected (Test-MembersRemoved $m) 'M01_DEAD_METHOD_COMES_BACK'
$m = $vb + "`n    Protected Function CurrentPrice(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal`n    End Function`n"
Assert-Detected (Test-MembersRemoved $m) 'M02_OBJECT_OVERLOAD_COMES_BACK'
$m = Mutate-Text $aspx 'HomeBottomPromoSection' 'HomeBottomPromo' 'M03'
Assert-Detected (Test-ContractsKept $m $vb) 'M03_CONTRACT_ID_REMOVED'
$m = Mutate-Text $aspx 'data-ks-async-cart-status' 'data-ks-removed' 'M04'
Assert-Detected (Test-ContractsKept $m $vb) 'M04_ASYNC_CART_STATUS_HOOK_REMOVED'
$m = Mutate-Text $vb 'Protected ReadOnly Property HomeAsyncCartToken' 'Protected ReadOnly Property HomeAsyncCartTokenX' 'M05'
Assert-Detected (Test-ContractsKept $aspx $m) 'M05_ASYNC_CART_TOKEN_REMOVED'
$m = Mutate-Text $vb 'Private Function TakeHomeArrivalsRows(' 'Private Function TakeHomeArrivalsRowsX(' 'M06'
Assert-Detected (Test-ContractsKept $aspx $m) 'M06_HARNESS_COMPILED_METHOD_REMOVED'
$m = Mutate-Text $vb 'badges.Append(RenderSaleBadge(row))' 'badges.Append(If(False, RenderSaleBadge(row), RenderSaleBadge(row)))' 'M07'
Assert-Detected (Test-BadgeStack $m) 'M07_BADGE_STACK_CHANGED'
$m = $aspx + "`n<section id=""HomeLowerColumnsSection"" runat=""server"" visible=""false""></section>`n"
Assert-Detected (Test-MarkupRemoved $m) 'M08_HIDDEN_SECTION_COMES_BACK'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ks-deadcode-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmp)
try {
    # il controllo reale sui riferimenti pendenti usa lo stesso schema: lo verifichiamo su un testo che lo contiene
    $pattern = '\b(?:HomeHeroSlider|HomeIconBoxes|HomeSideBanners?|HomeFeaturedProducts|HomeDepartmentsMenu)\b|home-slideshow\.js|keepstore-init\.js|search-suggest\.ashx|ui/master/Site\.master'
    Assert-Detected (-not [regex]::IsMatch('<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagName="s" %>', $pattern)) 'M09_DELETED_CONTROL_STILL_REGISTERED'
    Assert-Detected (-not [regex]::IsMatch('<script src="js/home-slideshow.js"></script>', $pattern)) 'M10_DELETED_SCRIPT_STILL_LOADED'
    Assert-Detected ([regex]::IsMatch('rptHomeFeaturedProducts HomeFeaturedProductsSection', $pattern)) 'M11_LIVE_NAMES_ARE_NOT_FALSE_POSITIVES'
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Write-Output 'HOME_DEADCODE_OK'
