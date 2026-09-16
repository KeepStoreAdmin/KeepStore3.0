[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://localhost:8443',
    [int]$SingleCampaignId = 0,
    [int]$MultiCampaignId = 0,
    [int]$TierCampaignId = 0,
    [switch]$SkipRuntime,
    [switch]$RunReversibleCartAdd,
    [switch]$OnlyReversibleCartAdd
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Passed = 0
$script:Failed = 0
$script:OriginalCertificateCallback = $null

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:Passed++
        Write-Output ('PASS ' + $Name)
        return
    }

    $script:Failed++
    Write-Output ('FAIL ' + $Name)
}

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Name)
    Assert-True ($null -ne $Text -and $Text.IndexOf($Expected, [StringComparison]::Ordinal) -ge 0) $Name
}

function Assert-NotContains {
    param([string]$Text, [string]$Unexpected, [string]$Name)
    Assert-True ($null -eq $Text -or $Text.IndexOf($Unexpected, [StringComparison]::Ordinal) -lt 0) $Name
}

function Get-RepositoryRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-FileText {
    param([string]$RelativePath)
    return [IO.File]::ReadAllText((Join-Path (Get-RepositoryRoot) $RelativePath))
}

function Enable-LocalCertificateCompatibility {
    if ($PSVersionTable.PSVersion.Major -ge 7) { return }
    $script:OriginalCertificateCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

function Restore-LocalCertificateCompatibility {
    if ($PSVersionTable.PSVersion.Major -ge 7) { return }
    [Net.ServicePointManager]::ServerCertificateValidationCallback = $script:OriginalCertificateCallback
}

function Invoke-LocalGet {
    param(
        [string]$PathAndQuery,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )

    $uri = $BaseUrl.TrimEnd('/') + '/' + $PathAndQuery.TrimStart('/')
    $arguments = @{
        Uri = $uri
        MaximumRedirection = 5
        TimeoutSec = 120
    }
    if ($null -ne $WebSession) { $arguments.WebSession = $WebSession }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $arguments.SkipCertificateCheck = $true }
    return Invoke-WebRequest @arguments
}

function Get-ProductIds {
    param([string]$Html)
    $values = [regex]::Matches($Html, 'data-ks-id="([0-9]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase) |
        ForEach-Object { $_.Groups[1].Value }
    return @($values | Sort-Object -Unique)
}

function Get-ReportedProductCount {
    param([string]$Html)
    $match = [regex]::Match($Html, '([0-9]+)\s+prodott[io]\s+trovat[io]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return -1 }
    return [int]$match.Groups[1].Value
}

function Get-CardCount {
    param([string]$Html)
    return [regex]::Matches($Html, 'class="[^"]*card-product(?:\s|")', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
}

function Get-ProductCardByCode {
    param([string]$Html, [string]$Code)
    foreach ($match in [regex]::Matches($Html, '<article\b.*?</article>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($match.Value.IndexOf($Code, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $match.Value
        }
    }
    return ''
}

function Get-SectionById {
    param([string]$Html, [string]$Id)
    if ([string]::IsNullOrWhiteSpace($Html) -or [string]::IsNullOrWhiteSpace($Id)) { return '' }
    $pattern = '<section\b[^>]*\bid="' + [regex]::Escape($Id) + '"[^>]*>.*?</section>'
    $match = [regex]::Match($Html, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return '' }
    return $match.Value
}

function Get-PageText {
    param([string]$Html)
    $withoutScripts = [regex]::Replace($Html, '<script\b[^>]*>.*?</script>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $withoutStyles = [regex]::Replace($withoutScripts, '<style\b[^>]*>.*?</style>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    return [Net.WebUtility]::HtmlDecode(([regex]::Replace($withoutStyles, '<[^>]+>', ' ') -replace '\s+', ' ')).Trim()
}

function Assert-HealthyResponse {
    param($Response, [string]$Name)
    Assert-True ([int]$Response.StatusCode -eq 200) ($Name + ' HTTP 200')
    Assert-NotContains $Response.Content 'MySqlException' ($Name + ' no MySQL error disclosure')
    Assert-NotContains $Response.Content 'Server Error in' ($Name + ' no ASP.NET error page')
}

function Test-StaticContract {
    $provider = Get-FileText 'App_Code\StorefrontPromotionCatalogProvider.vb'
    $resolver = Get-FileText 'App_Code\ProductPromotionEligibilityResolver.vb'
    $displayHelper = Get-FileText 'App_Code\ProductPromotionDisplayHelper.vb'
    $catalog = Get-FileText 'articoli.aspx.vb'
    $markup = Get-FileText 'articoli.aspx'
    $homePage = Get-FileText 'Default.aspx.vb'
    $recentScript = Get-FileText 'Public\assets\keepstore\js\keepstore-recently-viewed.js'
    $themeCss = Get-FileText 'Public\assets\keepstore\css\theme-overrides.css'

    Assert-Contains $provider 'FROM vOfferteDettagli legacy_detail' 'provider expands the legacy campaign scope set-based'
    Assert-Contains $provider 'INNER JOIN voffertearticoli mapped' 'provider intersects canonical authorized mappings'
    Assert-Contains $provider 'ROW_NUMBER() OVER (PARTITION BY catalog.id ORDER BY' 'provider returns one deterministic row per product'
    Assert-Contains $provider 'detail.id ASC,catalog.ArticoliListiniId ASC' 'provider deterministic detail tie-break'
    Assert-Contains $provider 'offer_header.AziendeId=?' 'provider company scope is parameterized'
    Assert-Contains $provider 'offer_header.UtentiId=?' 'provider owner scope is parameterized'
    Assert-Contains $provider 'offer_header.DataInizio IS NULL' 'provider accepts an open start boundary'
    Assert-Contains $provider 'offer_header.DataFine IS NULL' 'provider accepts an open end boundary'
    Assert-Contains $provider 'NOT (COALESCE(offer_header.QntMinima,0)>0 AND COALESCE(offer_header.Multipli,0)>0)' 'ambiguous quantity rules fail closed'
    Assert-Contains $provider 'COALESCE(offer_header.QntMinima,0)>0 OR COALESCE(offer_header.Multipli,0)>0' 'a positive quantity rule is required'
    Assert-Contains $provider 'END)<catalog.Prezzo' 'promotion price must improve the list price'
    Assert-NotContains $provider 'InOfferta=1' 'materialized InOfferta is not authoritative'
    Assert-NotContains $provider 'Session(' 'provider has no browser-controlled owner or listino state'

    Assert-Contains $resolver 'Public Property CampaignId As Integer' 'campaign is part of the shared eligibility context'
    Assert-Contains $resolver 'AND (@campaignId<=0 OR o.id=@campaignId)' 'shared resolver enforces campaign id'
    Assert-Contains $resolver 'Public Function PreloadStatus' 'shared resolver supports fail-closed preloading'
    Assert-Contains $resolver 'CurrentUserId.ToString' 'owner participates in the request cache key'
    Assert-Contains $resolver 'ByVal listino As Integer) As ProductPromotionEligibilityContext' 'listino-only overload cannot consume a campaign id'

    Assert-Contains $displayHelper 'offer.PriceGross < best.PriceGross' 'quantity-tier teaser selects the lowest authorized price'
    Assert-Contains $displayHelper 'model.BestPriceGross' 'catalog promotion summary uses the overall best price'
    Assert-Contains $displayHelper 'Promo</span>' 'promo label is separated from its price'
    Assert-Contains $homePage 'Math.Min(quantityOnePrice, tierPrice)' 'home cards select the lowest authorized promotion price'

    Assert-Contains $catalog 'StorefrontPromotionCatalogProvider.BuildMainCatalogJoin()' 'modern route uses the provider for products'
    Assert-Contains $catalog 'StorefrontPromotionCatalogProvider.BuildFacetCatalogJoin()' 'modern route uses the provider for facets'
    Assert-Contains $catalog '^[1-9][0-9]{0,9}$' 'pid is a strict positive integer'
    Assert-Contains $catalog 'values.Length <> 1' 'duplicate pid parameters fail closed'
    Assert-Contains $catalog 'catalogPromotionRequestInvalid OrElse catalogPromotionTechnicalError' 'invalid and technical states fail closed'
    Assert-Contains $catalog 'qs.Remove("pid")' 'removing the promotion route also removes its campaign'
    Assert-Contains $catalog 'CatalogPriceHtml' 'catalog price uses the promotion display contract'
    Assert-Contains $catalog 'promoModel.BestPriceGross' 'catalog cards display the overall best promotion price'
    Assert-NotContains $catalog 'strWhere &= " AND (InOfferta = 1)' 'modern membership no longer trusts InOfferta'
    Assert-Contains $markup 'CatalogPriceHtml(Container.DataItem)' 'inline cards use canonical display pricing'
    Assert-Contains $markup 'data-ks-server-fallback="1"' 'catalog recent products prefer live server cards'
    Assert-Contains $markup 'RecentCatalogPromoDetailsHtml(Container.DataItem)' 'catalog recent products render promotion conditions'
    Assert-Contains $catalog 'BindCatalogRecentlyViewed()' 'catalog binds recent products from server-side history'
    Assert-Contains $catalog 'CatalogPromotionModel(dataItem, False)' 'recent products evaluate all authorized campaigns'
    Assert-Contains $recentScript 'target.children.length' 'client history preserves server-rendered cards'
    Assert-Contains $recentScript 'renderPromotionBadge(item)' 'client fallback renders a promotion badge'
    Assert-Contains $themeCss 'ks-home-price-stack--emphasized' 'home reserves stable geometry for long promotional prices'

    $ownerVisible = {
        param([int]$OwnerId, [bool]$Authenticated, [int]$CurrentUserId)
        return ($OwnerId -le 0) -or ($Authenticated -and $CurrentUserId -gt 0 -and $OwnerId -eq $CurrentUserId)
    }
    Assert-True (& $ownerVisible 0 $false 0) 'anonymous sees public promotion'
    Assert-True (-not (& $ownerVisible 42 $false 0)) 'anonymous cannot see personal promotion'
    Assert-True (& $ownerVisible 42 $true 42) 'authenticated owner sees own promotion'
    Assert-True (-not (& $ownerVisible 43 $true 42)) 'authenticated owner cannot see another owner promotion'

    $quantityRuleValid = {
        param([decimal]$Minimum, [decimal]$Multiple)
        return -not ($Minimum -gt 0 -and $Multiple -gt 0) -and ($Minimum -gt 0 -or $Multiple -gt 0)
    }
    Assert-True (& $quantityRuleValid 1 0) 'minimum quantity rule is accepted'
    Assert-True (& $quantityRuleValid 0 5) 'multiple quantity rule is accepted'
    Assert-True (-not (& $quantityRuleValid 2 5)) 'combined minimum and multiple rule is rejected'
    Assert-True (-not (& $quantityRuleValid 0 0)) 'missing quantity rule is rejected'
}

function Test-RuntimeContract {
    Enable-LocalCertificateCompatibility
    try {
        $all = Invoke-LocalGet 'articoli.aspx?inpromo=1'
        Assert-HealthyResponse $all 'all promotions'
        $allIds = @(Get-ProductIds $all.Content)
        Assert-True ($allIds.Count -gt 0) 'all promotions contains products'
        Assert-True ($allIds.Count -eq (Get-CardCount $all.Content)) 'all promotions has no duplicate card on the first page'
        Assert-True (Get-ReportedProductCount $all.Content -ge $allIds.Count) 'reported promotion total is coherent'

        $pageTwo = Invoke-LocalGet 'articoli.aspx?inpromo=1&pg=2'
        Assert-HealthyResponse $pageTwo 'promotion page 2'
        $pageTwoIds = @(Get-ProductIds $pageTwo.Content)
        Assert-True ($pageTwoIds.Count -gt 0) 'promotion page 2 contains products'
        Assert-True ($pageTwoIds.Count -eq (Get-CardCount $pageTwo.Content)) 'promotion page 2 has no duplicate card'
        Assert-True (@($pageTwoIds | Where-Object { $allIds -contains $_ }).Count -eq 0) 'page 2 advances without repeating first-page products'
        Assert-True ([Net.WebUtility]::HtmlDecode($pageTwo.Content).IndexOf('inpromo=1', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'pager preserves promotion route'

        $search = Invoke-LocalGet 'articoli.aspx?inpromo=1&q=hp'
        Assert-HealthyResponse $search 'promotion search'
        Assert-True ([Net.WebUtility]::HtmlDecode($search.Content).IndexOf('inpromo=1', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'search preserves promotion route'

        if ($SingleCampaignId -gt 0) {
            $single = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $SingleCampaignId)
            Assert-HealthyResponse $single 'single-product campaign'
            Assert-True (@(Get-ProductIds $single.Content).Count -eq 1) 'single-product campaign returns one product'
            Assert-True ((Get-CardCount $single.Content) -eq 1) 'single-product campaign has one card'
            Assert-True ([Net.WebUtility]::HtmlDecode($single.Content).IndexOf(('pid=' + $SingleCampaignId), [StringComparison]::OrdinalIgnoreCase) -ge 0) 'single campaign pid is preserved'
        }

        if ($MultiCampaignId -gt 0) {
            $multi = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $MultiCampaignId)
            Assert-HealthyResponse $multi 'multi-product campaign'
            $multiIds = @(Get-ProductIds $multi.Content)
            Assert-True ($multiIds.Count -gt 1) 'multi-product campaign returns multiple products'
            Assert-True ($multiIds.Count -eq (Get-CardCount $multi.Content)) 'multi-product campaign has no duplicate card'
            Assert-True ([Net.WebUtility]::HtmlDecode($multi.Content).IndexOf(('pid=' + $MultiCampaignId), [StringComparison]::OrdinalIgnoreCase) -ge 0) 'multi campaign pid is preserved'
        }

        if ($TierCampaignId -gt 0) {
            $tier = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $TierCampaignId)
            Assert-HealthyResponse $tier 'quantity-tier campaign'
            $tierText = Get-PageText $tier.Content
            Assert-True ($tierText.IndexOf('Da ', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'quantity-tier card labels the future tier price'
            Assert-True ($tierText.IndexOf('MULTIPLI', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $tierText.IndexOf('MINIMO', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'quantity-tier card states its quantity rule'
        }

        $missing = Invoke-LocalGet 'articoli.aspx?inpromo=1&pid=2147483647'
        Assert-HealthyResponse $missing 'missing campaign'
        Assert-True (@(Get-ProductIds $missing.Content).Count -eq 0) 'missing campaign fails closed'

        foreach ($badPid in @('', 'abc', '-1', '0', '%20', '2147483648', '1%26pid%3D2')) {
            $invalid = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $badPid)
            Assert-HealthyResponse $invalid ('invalid pid ' + $badPid)
            Assert-True (@(Get-ProductIds $invalid.Content).Count -eq 0) ('invalid pid fails closed ' + $badPid)
            Assert-True ((Get-PageText $invalid.Content).IndexOf('campagna promozionale richiesta non è disponibile', [StringComparison]::OrdinalIgnoreCase) -ge 0) ('invalid pid has controlled message ' + $badPid)
        }

        $duplicatePid = Invoke-LocalGet 'articoli.aspx?inpromo=1&pid=1&pid=2'
        Assert-HealthyResponse $duplicatePid 'duplicate pid parameters'
        Assert-True (@(Get-ProductIds $duplicatePid.Content).Count -eq 0) 'duplicate pid parameters fail closed'
        Assert-True ((Get-PageText $duplicatePid.Content).IndexOf('campagna promozionale richiesta non è disponibile', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'duplicate pid parameters have controlled message'

        $normal = Invoke-LocalGet 'articoli.aspx'
        Assert-HealthyResponse $normal 'normal catalog'
        Assert-True (@(Get-ProductIds $normal.Content).Count -gt 0) 'normal catalog still renders products'

        $bestPromoSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $bestPromo = Invoke-LocalGet 'articoli.aspx?inpromo=1&q=ZAP80-A4' $bestPromoSession
        Assert-HealthyResponse $bestPromo 'multiple-promotion product catalog'
        $bestPromoCard = Get-ProductCardByCode $bestPromo.Content 'ZAP80-A4'
        Assert-True (-not [string]::IsNullOrWhiteSpace($bestPromoCard)) 'multiple-promotion product card is present'
        if (-not [string]::IsNullOrWhiteSpace($bestPromoCard)) {
            $bestPromoText = Get-PageText $bestPromoCard
            Assert-True ($bestPromoText.IndexOf('Da 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'multiple-promotion card leads with the lowest price'
            Assert-True ($bestPromoText.IndexOf('-33% Promo 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'promo label and lowest price are distinct and visible'
            Assert-True ($bestPromoText.IndexOf('MULTIPLI 5 PZ.', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'lowest tier price keeps its quantity condition'
            Assert-True ($bestPromoText.IndexOf('2 offerte attive', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'multiple-promotion card reports all active offers'
        }

        $bestPromoPdp = Invoke-LocalGet 'articolo.aspx?id=21906' $bestPromoSession
        Assert-HealthyResponse $bestPromoPdp 'multiple-promotion product PDP'
        Assert-True ([regex]::Matches($bestPromoPdp.Content, 'ks-product-promos__item', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 2) 'PDP lists both authorized promotion types'
        $bestPromoPdpText = Get-PageText $bestPromoPdp.Content
        Assert-True ($bestPromoPdpText.IndexOf('A 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                     $bestPromoPdpText.IndexOf('A 5,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'PDP preserves every authorized promotion price'

        $recentCatalog = Invoke-LocalGet 'articoli.aspx?q=ZAP80-A4&ksreview=recent-promo' $bestPromoSession
        Assert-HealthyResponse $recentCatalog 'catalog recently viewed'
        $recentCatalogSection = Get-SectionById $recentCatalog.Content 'ksRecentlyViewedBlock'
        $recentCatalogText = Get-PageText $recentCatalogSection
        Assert-True ($recentCatalogText.IndexOf('ZAP80-A4', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'catalog recently viewed contains the visited product'
        Assert-True ($recentCatalogText.IndexOf('Promo', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'catalog recently viewed displays the promotion badge'
        Assert-True ($recentCatalogText.IndexOf('4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'catalog recently viewed displays the lowest promotion price'
        Assert-True ($recentCatalogText.IndexOf('MULTIPLI 5 PZ.', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'catalog recently viewed displays the promotion condition'

        $homeResponse = Invoke-LocalGet 'Default.aspx?ksreview=recent-promo' $bestPromoSession
        Assert-HealthyResponse $homeResponse 'home'
        $homeRecentSection = Get-SectionById $homeResponse.Content 'HomeRecentlyViewedSection'
        $homeRecentText = Get-PageText $homeRecentSection
        Assert-True ($homeRecentSection.IndexOf('ZAP80-A4', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'home recently viewed contains the visited product'
        Assert-True ($homeRecentText.IndexOf('Promo', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'home recently viewed displays the promotion badge'
        Assert-True ($homeRecentText.IndexOf('4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'home recently viewed displays the lowest promotion price'
        Assert-True ($homeRecentText.IndexOf('Multipli 5 pz.', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'home recently viewed displays the promotion condition'
        Assert-Contains $homeResponse.Content 'ks-home-price-stack--emphasized' 'home deal cards use stable promotional price geometry'

        if ($allIds.Count -gt 0) {
            $pdp = Invoke-LocalGet ('articolo.aspx?id=' + $allIds[0])
            Assert-HealthyResponse $pdp 'promotional product PDP'
        }

        if ($RunReversibleCartAdd) {
            Test-ReversibleAsyncCartAdd
        }
    }
    finally {
        Restore-LocalCertificateCompatibility
    }
}

function Test-ReversibleAsyncCartAdd {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $catalogPath = if ($SingleCampaignId -gt 0) {
        'articoli.aspx?inpromo=1&pid=' + $SingleCampaignId
    } else {
        'articoli.aspx?inpromo=1'
    }
    $catalog = Invoke-LocalGet $catalogPath $session
    $ids = @(Get-ProductIds $catalog.Content)
    Assert-True ($ids.Count -gt 0) 'reversible add fixture resolved'
    if ($ids.Count -eq 0) { return }

    $csrfMatch = [regex]::Match($catalog.Content, 'name="csrfToken"\s+value="([^"]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $tcMatch = [regex]::Match($catalog.Content, 'data-ks-id="' + [regex]::Escape($ids[0]) + '"\s+data-ks-tcid="(-?[0-9]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    Assert-True $csrfMatch.Success 'reversible add CSRF token present'
    Assert-True $tcMatch.Success 'reversible add product variant present'
    if (-not $csrfMatch.Success -or -not $tcMatch.Success) { return }

    $origin = ([uri]$BaseUrl).GetLeftPart([UriPartial]::Authority)
    $referrer = $BaseUrl.TrimEnd('/') + '/' + $catalogPath
    $headers = @{
        Origin = $origin
        Referer = $referrer
        'X-Requested-With' = 'XMLHttpRequest'
        'Sec-Fetch-Site' = 'same-origin'
    }
    $requestId = [guid]::NewGuid().ToString('N')
    $postArguments = @{
        Uri = $BaseUrl.TrimEnd('/') + '/catalog_cart_async.aspx'
        Method = 'POST'
        WebSession = $session
        Headers = $headers
        Body = @{
            csrfToken = [Net.WebUtility]::HtmlDecode($csrfMatch.Groups[1].Value)
            id = $ids[0]
            tcid = $tcMatch.Groups[1].Value
            qty = '1'
            requestId = $requestId
        }
        TimeoutSec = 120
    }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $postArguments.SkipCertificateCheck = $true }
    $added = Invoke-WebRequest @postArguments
    $payload = $added.Content | ConvertFrom-Json
    Assert-True ([int]$added.StatusCode -eq 200 -and [bool]$payload.ok) 'asynchronous cart add succeeds'
    Assert-True ([decimal]$payload.cart.count -ge 1) 'asynchronous response returns populated cart snapshot'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$payload.miniCartHtml)) 'asynchronous response renders MiniCart'

    $clearArguments = @{
        Uri = $BaseUrl.TrimEnd('/') + '/cart_add.aspx'
        Method = 'POST'
        WebSession = $session
        Headers = @{ Origin = $origin; Referer = $referrer }
        Body = @{
            csrfToken = [Net.WebUtility]::HtmlDecode($csrfMatch.Groups[1].Value)
            ReturnUrl = '/' + $catalogPath
            ksCartAction = 'operation=cart-clear&requestId=' + [guid]::NewGuid().ToString('N')
        }
        MaximumRedirection = 5
        TimeoutSec = 120
    }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $clearArguments.SkipCertificateCheck = $true }
    $cleared = Invoke-WebRequest @clearArguments
    Assert-True ([int]$cleared.StatusCode -eq 200) 'reversible fixture clear returns to storefront'

    $after = Invoke-LocalGet $catalogPath $session
    $existingPattern = 'data-ks-id="' + [regex]::Escape($ids[0]) + '"[^>]*data-ks-existing-cart-qty='
    Assert-True (-not [regex]::IsMatch($after.Content, $existingPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'reversible fixture is removed from the anonymous cart'
}

Test-StaticContract
if ($OnlyReversibleCartAdd) {
    Enable-LocalCertificateCompatibility
    try { Test-ReversibleAsyncCartAdd }
    finally { Restore-LocalCertificateCompatibility }
} elseif (-not $SkipRuntime) {
    Test-RuntimeContract
}

Write-Output ('RESULT PASS={0} FAIL={1}' -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
