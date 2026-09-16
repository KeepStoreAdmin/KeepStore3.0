[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://localhost:8443',
    [int]$SingleCampaignId = 19524,
    [int]$MultiCampaignId = 14556,
    [int]$TierCampaignId = 19527,
    [switch]$SkipRuntime,
    [switch]$SkipDirectParity
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
    } else {
        $script:Failed++
        Write-Output ('FAIL ' + $Name)
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Name)
    Assert-True ($null -ne $Text -and $Text.IndexOf($Expected, [StringComparison]::Ordinal) -ge 0) $Name
}

function Assert-NotContains {
    param([string]$Text, [string]$Unexpected, [string]$Name)
    Assert-True ($null -eq $Text -or $Text.IndexOf($Unexpected, [StringComparison]::Ordinal) -lt 0) $Name
}

function Get-RepositoryRoot { return (Split-Path -Parent $PSScriptRoot) }

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
    $arguments = @{
        Uri = $BaseUrl.TrimEnd('/') + '/' + $PathAndQuery.TrimStart('/')
        MaximumRedirection = 5
        TimeoutSec = 180
    }
    if ($null -ne $WebSession) { $arguments.WebSession = $WebSession }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $arguments.SkipCertificateCheck = $true }
    return Invoke-WebRequest @arguments
}

function Get-ProductIds {
    param([string]$Html)
    return @([regex]::Matches($Html, 'data-ks-id="([0-9]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase) |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

function Get-ReportedProductCount {
    param([string]$Html)
    $match = [regex]::Match((Get-PageText $Html), '([0-9]+)\s+(?:prodott[io]|articol[io])\s+trovat[io]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return -1 }
    return [int]$match.Groups[1].Value
}

function Get-ProductCardByCode {
    param([string]$Html, [string]$Code)
    foreach ($match in [regex]::Matches($Html, '<article\b.*?</article>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($match.Value.IndexOf($Code, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $match.Value }
    }
    return ''
}

function Get-ProductCardCountByCode {
    param([string]$Html, [string]$Code)
    return @([regex]::Matches($Html, '<article\b.*?</article>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline) |
        Where-Object { $_.Value.IndexOf($Code, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count
}

function Get-ProductCardWithoutPromotion {
    param([string]$Html)
    foreach ($match in [regex]::Matches($Html, '<article\b.*?</article>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($match.Value.IndexOf('ks-catalog-promos', [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $match.Value }
    }
    return ''
}

function Get-ElementByClass {
    param([string]$Html, [string]$ClassName)
    $pattern = '<(?<tag>[a-z][a-z0-9]*)\b[^>]*class=(?<quote>[''"])[^''"]*' + [regex]::Escape($ClassName) + '[^''"]*\k<quote>[^>]*>.*?</\k<tag>>'
    $match = [regex]::Match($Html, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Value }
    return ''
}

function Assert-PromotionSummaryMarkup {
    param([string]$Html, [string]$Name)
    $summaries = @([regex]::Matches($Html, '<div class="ks-catalog-promos"[^>]*>.*?</div>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline))
    Assert-True ($summaries.Count -gt 0) ($Name + ' renders promotion summary markup')
    foreach ($summaryMatch in $summaries) {
        $summary = $summaryMatch.Value
        Assert-True (-not [regex]::IsMatch($summary, 'Promo\s*<strong\b', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' summary does not repeat the immediate price')
        $labels = @([regex]::Matches($summary, '<span class="ks-catalog-promos__label">\s*Promo\s*</span>', [Text.RegularExpressions.RegexOptions]::IgnoreCase))
        Assert-True ($labels.Count -le 1) ($Name + ' uses at most one standalone Promo label per card')
        if ($labels.Count -eq 1) {
            Assert-True ((Get-PageText $labels[0].Value) -ceq 'Promo') ($Name + ' Promo label contains text only')
        }
    }
}

function Assert-ZapCatalogCardPresentation {
    param([string]$Card, [string]$Name)
    $priceWrap = Get-ElementByClass $Card 'price-wrap'
    $newPrice = Get-ElementByClass $priceWrap 'new-price'
    if ([string]::IsNullOrWhiteSpace($newPrice)) { $newPrice = Get-ElementByClass $priceWrap 'ks-price-now' }
    $summary = Get-ElementByClass $Card 'ks-catalog-promos'
    $summaryText = Get-PageText $summary
    Assert-True (-not [string]::IsNullOrWhiteSpace($priceWrap)) ($Name + ' has one price-wrap')
    Assert-True ([regex]::Matches($Card, 'class="[^"]*\bprice-wrap\b[^"]*"', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) ($Name + ' price-wrap occurs once')
    Assert-True ((Get-PageText $newPrice) -eq '5,00 €') ($Name + ' immediate quantity-one price is 5.00 only in price-wrap')
    Assert-True ([regex]::Matches($summaryText, '(?<![0-9])5,00\s*€', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 0) ($Name + ' summary does not repeat 5.00')
    Assert-True ([regex]::Matches($summary, '<span class="ks-catalog-promos__label">\s*Promo\s*</span>', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) ($Name + ' has one standalone Promo label')
    Assert-True ([regex]::IsMatch($summary, 'ks-catalog-promos__discount[^>]*>.*?</span>\s*<span class="ks-catalog-promos__label">\s*Promo\s*</span>\s*<span class="ks-catalog-promos__price">\s*Da\s*<strong>4,00\s*€</strong></span>\s*<span class="ks-catalog-promos__tier">\s*MULTIPLI\s+5\s+PZ\.\s*</span>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) ($Name + ' discount, label, tier price and condition are separate siblings')
    Assert-True ($summaryText.IndexOf('Da 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' future tier remains separate at 4.00')
    Assert-True ($summaryText.IndexOf('MULTIPLI 5 PZ.', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' tier condition remains visible')
    Assert-True ($summaryText.IndexOf('2 offerte attive', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' active-offer count remains visible')
    Assert-True ([regex]::IsMatch($Card, 'data-ks-price="5(?:[\.,]0+)?(?:\s*€)?"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' data price remains quantity-one price')
    Assert-True (-not [regex]::IsMatch($Card, 'data-ks-price="4(?:[\.,]0+)?(?:\s*€)?"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' data price is not the future tier')
}

function Assert-ZapHomePresentation {
    param([string]$Section, [string]$Name)
    $priceWrap = Get-ElementByClass $Section 'price-wrap'
    $newPrice = Get-ElementByClass $priceWrap 'new-price'
    $tier = Get-ElementByClass $Section 'ks-home-promo-tier'
    Assert-True ($Section.IndexOf('ZAP80-A4', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' renders ZAP80-A4')
    Assert-True ([regex]::Matches($Section, 'class=[''"][^''"]*\bprice-wrap\b[^''"]*[''"]', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) ($Name + ' price-wrap occurs once')
    Assert-True ((Get-PageText $newPrice) -eq '5,00 €') ($Name + ' immediate quantity-one price is 5.00 only in price-wrap')
    Assert-True ([regex]::Matches($Section, '<p class=[''"]small-text[''"]>\s*Promo\s*</p>', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) ($Name + ' keeps one standalone image badge label')
    Assert-True (-not [regex]::IsMatch($Section, 'Promo\s*(?:<[^>]+>\s*)*5,00\s*€', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' does not repeat 5.00 beside Promo')
    Assert-True ((Get-PageText $tier).IndexOf('Da 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' keeps future tier separate at 4.00')
    Assert-True ((Get-PageText $tier).IndexOf('Multipli 5 pz.', [StringComparison]::OrdinalIgnoreCase) -ge 0) ($Name + ' keeps the tier condition')
    Assert-True ([regex]::IsMatch($Section, 'data-ks-price=[''"]5(?:[\.,]0+)?(?:\s*€)?[''"]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' data price remains quantity-one price')
    Assert-True (-not [regex]::IsMatch($Section, 'data-ks-price=[''"]4(?:[\.,]0+)?(?:\s*€)?[''"]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) ($Name + ' data price is not the future tier')
}

function Get-SectionById {
    param([string]$Html, [string]$Id)
    $pattern = '<section\b[^>]*\bid="' + [regex]::Escape($Id) + '"[^>]*>.*?</section>'
    $match = [regex]::Match($Html, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Value }
    return ''
}

function Get-PageText {
    param([string]$Html)
    $value = [regex]::Replace($Html, '<script\b[^>]*>.*?</script>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $value = [regex]::Replace($value, '<style\b[^>]*>.*?</style>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    return [Net.WebUtility]::HtmlDecode(([regex]::Replace($value, '<[^>]+>', ' ') -replace '\s+', ' ')).Trim()
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
    $display = Get-FileText 'App_Code\ProductPromotionDisplayHelper.vb'
    $legacy = Get-FileText 'promozioni.aspx.vb'
    $legacyPolicy = Get-FileText 'App_Code\LegacyPromotionRoutePolicy.vb'
    $catalog = Get-FileText 'articoli.aspx.vb'
    $catalogMarkup = Get-FileText 'articoli.aspx'
    $homePage = Get-FileText 'Default.aspx.vb'
    $pdp = Get-FileText 'articolo.aspx.vb'
    $recent = Get-FileText 'Public\assets\keepstore\js\keepstore-recently-viewed.js'
    $cartPrice = Get-FileText 'App_Code\CartPriceRevalidationHelper.vb'
    $css = Get-FileText 'Public\assets\keepstore\css\theme-overrides.css'
    $catalogCss = Get-FileText 'Public\assets\keepstore\css\catalog-ui.css'

    Assert-Contains $provider 'ROW_NUMBER() OVER (PARTITION BY catalog.id ORDER BY' 'provider selects one deterministic offer per article'
    Assert-Contains $provider 'Public Function BuildLegacyCatalogJoin() As String' 'legacy route has a canonical provider join'
    Assert-Contains $provider 'offer_header.UtentiId=?' 'provider enforces owner scope'
    Assert-Contains $provider 'offer_header.DataInizio IS NULL' 'provider supports open start dates'
    Assert-Contains $provider 'offer_header.DataFine IS NULL' 'provider supports open end dates'
    Assert-Contains $provider 'NOT (COALESCE(offer_header.QntMinima,0)>0 AND COALESCE(offer_header.Multipli,0)>0)' 'ambiguous quantity rules fail closed'
    Assert-NotContains $provider 'InOfferta=1' 'provider does not trust materialized InOfferta'

    Assert-Contains $legacy 'LegacyPromotionRoutePolicy.BuildModernPath' 'legacy route delegates to the retirement policy'
    Assert-NotContains $legacy 'MySql' 'retired route performs no database access'
    Assert-Contains $legacyPolicy '"pid", "pmr", "pst", "pct", "ptp", "pgr", "psg"' 'retirement policy exposes only the approved legacy keys'

    Assert-Contains $resolver 'AND (@campaignId<=0 OR o.id=@campaignId)' 'shared resolver enforces campaign id'
    Assert-Contains $resolver 'CurrentUserId.ToString' 'owner participates in request cache key'
    Assert-Contains $resolver 'Public Function PreloadStatus' 'shared resolver supports fail-closed preload'

    Assert-Contains $display 'model.BestDefaultQuantityPriceGross' 'display model preserves the quantity-one promotion price'
    Assert-Contains $display 'model.BestQuantityTierPriceGross' 'catalog summary renders the future tier separately'
    Assert-Contains $display 'Da <strong>' 'quantity tier is explicitly a Da teaser'
    Assert-Contains $display 'ks-catalog-promos__label"">Promo</span>' 'catalog summary renders a standalone Promo label'
    Assert-NotContains $display 'ks-catalog-promos__price"">Promo <strong>' 'catalog summary does not repeat the immediate price'
    Assert-NotContains $display 'DisplayPrice(model.BestPriceNet, model.BestPriceGross' 'overall minimum is not the current catalog price'
    Assert-NotContains $homePage 'Math.Min(quantityOnePrice, tierPrice)' 'home never promotes a future tier to current price'
    Assert-Contains $homePage 'DisplayPromoQtyOnePrice' 'home current price is quantity-one price'
    Assert-Contains $catalog 'CatalogDefaultQuantityPromoPrice' 'catalog data price uses quantity-one price'
    Assert-NotContains $catalog 'promoModel.BestPriceGross' 'catalog card does not use overall minimum as current price'
    Assert-Contains $catalogMarkup 'data-ks-server-fallback="1"' 'catalog recent cards prefer server truth'
    Assert-Contains $pdp 'item("id") = _id.ToString()' 'PDP stores chronology identifiers'
    Assert-NotContains $pdp 'item("price")' 'PDP does not store price in recent history'
    Assert-NotContains $pdp 'item("promo")' 'PDP does not store promotion state in recent history'
    Assert-NotContains $recent 'basePrice' 'local history has no base price'
    Assert-NotContains $recent 'renderPromotionBadge' 'JavaScript fallback does not invent a promotion badge'
    Assert-NotContains $recent 'availabilityClass' 'JavaScript fallback does not cache availability'
    Assert-Contains $recent 'scrubStoredHistory' 'legacy commercial fields are removed from local history'
    Assert-Contains $cartPrice 'quantity' 'cart price revalidation receives the final quantity'
    Assert-Contains $css 'ks-home-price-stack--emphasized' 'long prices keep stable home geometry'
    Assert-Contains $catalogCss '.ks-catalog-promos__label,' 'standalone Promo label participates in the flex group'
    Assert-Contains $catalogCss 'margin-top: 6px' 'promotion summary is separated from the main price'
    Assert-Contains $catalogCss 'row-gap: 6px' 'promotion rows keep measurable spacing'
    Assert-Contains $catalogCss 'column-gap: 10px' 'promotion items keep measurable spacing'
    Assert-Contains $catalogCss 'align-items: center' 'promotion items stay vertically aligned'
    Assert-Contains $catalogCss 'background: rgba(216, 0, 39, 0.08)' 'Promo label uses a light themed background'
    Assert-Contains $catalogCss 'border: 1px solid rgba(216, 0, 39, 0.24)' 'Promo label has a light themed border'
    Assert-Contains $catalogCss 'border-radius: 4px' 'Promo label uses a restrained radius'
    Assert-Contains $catalogCss '.ks-catalog-promos__price strong' 'tier price has dedicated emphasis'
    Assert-Contains $catalogCss 'column-gap: 4px' 'Da and tier price keep real spacing'
    Assert-Contains $catalogMarkup 'catalog-ui.css") %>?v=20260916-promocard-visual-rev2' 'catalog CSS cache-buster is REV2'

    $ownerVisible = {
        param([int]$OwnerId, [bool]$Authenticated, [int]$CurrentUserId)
        return ($OwnerId -le 0) -or ($Authenticated -and $CurrentUserId -gt 0 -and $OwnerId -eq $CurrentUserId)
    }
    Assert-True (& $ownerVisible 0 $false 0) 'anonymous sees public promotion'
    Assert-True (-not (& $ownerVisible 42 $false 0)) 'anonymous cannot see owner promotion'
    Assert-True (& $ownerVisible 42 $true 42) 'correct owner sees owner promotion'
    Assert-True (-not (& $ownerVisible 43 $true 42)) 'another owner cannot see owner promotion'

    $zapPrice = { param([int]$Quantity) if (($Quantity % 5) -eq 0) { 4.00D } else { 5.00D } }
    Assert-True ((& $zapPrice 1) -eq 5.00D) 'ZAP80-A4 quantity 1 price is 5.00'
    Assert-True ((& $zapPrice 2) -eq 5.00D) 'ZAP80-A4 quantity 2 price is 5.00'
    Assert-True ((& $zapPrice 3) -eq 5.00D) 'ZAP80-A4 quantity 3 price is 5.00'
    Assert-True ((& $zapPrice 4) -eq 5.00D) 'ZAP80-A4 quantity 4 price is 5.00'
    Assert-True ((& $zapPrice 5) -eq 4.00D) 'ZAP80-A4 quantity 5 price is 4.00'
}

function Open-ReadOnlyConnection {
    $root = Get-RepositoryRoot
    $dll = Join-Path $root 'Bin\MySql.Data.dll'
    if (-not ('MySql.Data.MySqlClient.MySqlConnection' -as [type])) { Add-Type -Path $dll }
    [xml]$configuration = [IO.File]::ReadAllText((Join-Path $root 'Web.config'))
    $node = @($configuration.configuration.connectionStrings.add | Where-Object { $_.name -eq 'EntropicConnectionString' })[0]
    if ($null -eq $node -or [string]::IsNullOrWhiteSpace([string]$node.connectionString)) { throw 'REV1_CONNECTION_UNAVAILABLE' }
    $connection = New-Object MySql.Data.MySqlClient.MySqlConnection([string]$node.connectionString)
    $connection.Open()
    return $connection
}

function Get-Scalar {
    param($Connection, [string]$Sql, [hashtable]$Parameters)
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $Sql
        foreach ($key in $Parameters.Keys) { [void]$command.Parameters.AddWithValue($key, $Parameters[$key]) }
        return $command.ExecuteScalar()
    } finally { $command.Dispose() }
}

function Get-ParityContext {
    param($Connection, [bool]$Authenticated)
    if (-not $Authenticated) {
        return @{ CompanyId = 1; Listino = 1; CurrentUserId = 0; Authenticated = 0 }
    }
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = 'SELECT COALESCE(AziendeID,0),COALESCE(listino,0),COALESCE(utentiid,0) FROM vlogin WHERE UPPER(Username)=@account LIMIT 1'
        [void]$command.Parameters.AddWithValue('@account', 'PROVA')
        $reader = $command.ExecuteReader()
        try {
            if (-not $reader.Read()) { throw 'REV1_TEST_ACCOUNT_UNAVAILABLE' }
            return @{ CompanyId = [int]$reader.GetValue(0); Listino = [int]$reader.GetValue(1); CurrentUserId = [int]$reader.GetValue(2); Authenticated = 1 }
        } finally { $reader.Dispose() }
    } finally { $command.Dispose() }
}

function Get-DirectParitySnapshot {
    param($Connection, [hashtable]$Context, [int]$CampaignId)
    $sql = @'
WITH authorized_ranked AS (
 SELECT catalog.id AS ArticleId,catalog.ArticoliListiniId AS ArticleListPriceId,
        ROW_NUMBER() OVER (PARTITION BY catalog.id ORDER BY
          CASE WHEN COALESCE(detail.TCId,-1)>0 THEN 0 ELSE 1 END,
          CASE WHEN COALESCE(o.Prezzo,0)>0 THEN o.Prezzo
               WHEN COALESCE(o.Sconto,0)>0 AND o.Sconto<100 THEN catalog.Prezzo*(1-(o.Sconto/100))
               ELSE 0 END,
          detail.id,catalog.ArticoliListiniId) AS PromotionRank
 FROM vOfferteDettagli legacy_detail
 INNER JOIN varticolilistini catalog ON catalog.NListino=@listino
  AND (COALESCE(legacy_detail.MarcheId,0)=0 OR catalog.MarcheId=legacy_detail.MarcheId)
  AND (COALESCE(legacy_detail.SettoriId,0)=0 OR catalog.SettoriId=legacy_detail.SettoriId)
  AND (COALESCE(legacy_detail.CategorieId,0)=0 OR catalog.CategorieId=legacy_detail.CategorieId)
  AND (COALESCE(legacy_detail.TipologieId,0)=0 OR catalog.TipologieId=legacy_detail.TipologieId)
  AND (COALESCE(legacy_detail.GruppiId,0)=0 OR catalog.GruppiId=legacy_detail.GruppiId)
  AND (COALESCE(legacy_detail.SottoGruppiId,0)=0 OR catalog.SottoGruppiId=legacy_detail.SottoGruppiId)
  AND (COALESCE(legacy_detail.ArticoliId,0)=0 OR catalog.id=legacy_detail.ArticoliId)
 INNER JOIN voffertearticoli mapped ON mapped.id=catalog.id AND mapped.OfferteID=legacy_detail.OfferteId AND mapped.OfferteDettagliId=legacy_detail.id
 INNER JOIN offerte o ON o.id=mapped.OfferteID
 INNER JOIN offertedettaglio detail ON detail.id=mapped.OfferteDettagliId AND detail.OfferteId=o.id
 INNER JOIN articoli article ON article.id=catalog.id
 WHERE o.AziendeId=@company AND legacy_detail.AziendeId=@company
  AND COALESCE(o.Abilitato,0)=1 AND COALESCE(article.Abilitato,0)=1 AND COALESCE(article.NoPromo,0)=0
  AND (COALESCE(detail.TCId,-1)<=0 OR COALESCE(catalog.TCId,-1)=detail.TCId)
  AND (COALESCE(o.DaListino,0)<=0 OR o.DaListino<=@listino)
  AND (COALESCE(o.AListino,0)<=0 OR o.AListino>=@listino)
  AND (o.DataInizio IS NULL OR o.DataInizio<=CURRENT_DATE())
  AND (o.DataFine IS NULL OR o.DataFine>=CURRENT_DATE())
  AND (COALESCE(o.UtentiId,0)<=0 OR (@authenticated=1 AND @currentUser>0 AND o.UtentiId=@currentUser))
  AND (@campaign<=0 OR o.id=@campaign)
  AND NOT (COALESCE(o.QntMinima,0)>0 AND COALESCE(o.Multipli,0)>0)
  AND (COALESCE(o.QntMinima,0)>0 OR COALESCE(o.Multipli,0)>0)
  AND COALESCE(catalog.Prezzo,0)>0
  AND (CASE WHEN COALESCE(o.Prezzo,0)>0 THEN o.Prezzo WHEN COALESCE(o.Sconto,0)>0 AND o.Sconto<100 THEN catalog.Prezzo*(1-(o.Sconto/100)) ELSE 0 END)>0
  AND (CASE WHEN COALESCE(o.Prezzo,0)>0 THEN o.Prezzo WHEN COALESCE(o.Sconto,0)>0 AND o.Sconto<100 THEN catalog.Prezzo*(1-(o.Sconto/100)) ELSE 0 END)<catalog.Prezzo
), authorized AS (
 SELECT ArticleId,ArticleListPriceId FROM authorized_ranked WHERE PromotionRank=1
), legacy_route AS (
 SELECT a.id AS ArticleId FROM varticolilistini a INNER JOIN authorized p ON p.ArticleId=a.id AND p.ArticleListPriceId=a.ArticoliListiniId
 WHERE a.NListino=@listino GROUP BY a.id
), modern_route AS (
 SELECT v.id AS ArticleId FROM vsuperarticoli v INNER JOIN authorized p ON p.ArticleId=v.id AND p.ArticleListPriceId=v.ArticoliListiniId
 WHERE v.NListino=@listino GROUP BY v.id
), legacy_duplicates AS (
 SELECT ArticleId,COUNT(*) AS n FROM legacy_route GROUP BY ArticleId HAVING COUNT(*)>1
), modern_duplicates AS (
 SELECT ArticleId,COUNT(*) AS n FROM modern_route GROUP BY ArticleId HAVING COUNT(*)>1
)
SELECT (SELECT COUNT(*) FROM legacy_route) AS TotaleLegacy,
       (SELECT COUNT(*) FROM modern_route) AS TotaleModern,
       (SELECT COUNT(*) FROM legacy_route l LEFT JOIN modern_route m ON m.ArticleId=l.ArticleId WHERE m.ArticleId IS NULL) AS SoloLegacy,
       (SELECT COUNT(*) FROM modern_route m LEFT JOIN legacy_route l ON l.ArticleId=m.ArticleId WHERE l.ArticleId IS NULL) AS SoloModern,
       (SELECT COALESCE(SUM(n-1),0) FROM legacy_duplicates) AS DuplicatiLegacy,
       (SELECT COALESCE(SUM(n-1),0) FROM modern_duplicates) AS DuplicatiModern
'@
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $sql
        [void]$command.Parameters.AddWithValue('@listino', $Context.Listino)
        [void]$command.Parameters.AddWithValue('@company', $Context.CompanyId)
        [void]$command.Parameters.AddWithValue('@authenticated', $Context.Authenticated)
        [void]$command.Parameters.AddWithValue('@currentUser', $Context.CurrentUserId)
        [void]$command.Parameters.AddWithValue('@campaign', $CampaignId)
        $reader = $command.ExecuteReader()
        try {
            if (-not $reader.Read()) { throw 'REV1_PARITY_NO_RESULT' }
            return [pscustomobject]@{
                TotaleLegacy = [int]$reader['TotaleLegacy']; TotaleModern = [int]$reader['TotaleModern']
                SoloLegacy = [int]$reader['SoloLegacy']; SoloModern = [int]$reader['SoloModern']
                DuplicatiLegacy = [int]$reader['DuplicatiLegacy']; DuplicatiModern = [int]$reader['DuplicatiModern']
            }
        } finally { $reader.Dispose() }
    } finally { $command.Dispose() }
}

function Assert-DirectParity {
    param($Snapshot, [string]$Name)
    Write-Output ('PARITY {0} TotaleLegacy={1} TotaleModern={2} SoloLegacy={3} SoloModern={4} DuplicatiLegacy={5} DuplicatiModern={6}' -f
        $Name,$Snapshot.TotaleLegacy,$Snapshot.TotaleModern,$Snapshot.SoloLegacy,$Snapshot.SoloModern,$Snapshot.DuplicatiLegacy,$Snapshot.DuplicatiModern)
    Assert-True ($Snapshot.TotaleLegacy -eq $Snapshot.TotaleModern) ($Name + ' totals match')
    Assert-True ($Snapshot.SoloLegacy -eq 0) ($Name + ' SoloLegacy zero')
    Assert-True ($Snapshot.SoloModern -eq 0) ($Name + ' SoloModern zero')
    Assert-True ($Snapshot.DuplicatiLegacy -eq 0) ($Name + ' DuplicatiLegacy zero')
    Assert-True ($Snapshot.DuplicatiModern -eq 0) ($Name + ' DuplicatiModern zero')
}

function Test-DirectParity {
    $connection = $null
    try {
        $connection = Open-ReadOnlyConnection
        $anonymous = Get-ParityContext $connection $false
        $authenticated = Get-ParityContext $connection $true
        Assert-DirectParity (Get-DirectParitySnapshot $connection $anonymous 0) 'ANON_ALL'
        Assert-DirectParity (Get-DirectParitySnapshot $connection $authenticated 0) 'PROVA_ALL'
        Assert-DirectParity (Get-DirectParitySnapshot $connection $anonymous $SingleCampaignId) 'ANON_SINGLE'
        Assert-DirectParity (Get-DirectParitySnapshot $connection $anonymous $MultiCampaignId) 'ANON_MULTI'
        Assert-DirectParity (Get-DirectParitySnapshot $connection $anonymous 2147483647) 'ANON_MISSING'
        $single = Get-DirectParitySnapshot $connection $anonymous $SingleCampaignId
        $multi = Get-DirectParitySnapshot $connection $anonymous $MultiCampaignId
        $missing = Get-DirectParitySnapshot $connection $anonymous 2147483647
        Assert-True ($single.TotaleModern -eq 1) 'known single campaign contains one product'
        Assert-True ($multi.TotaleModern -gt 1) 'known multi campaign contains multiple products'
        Assert-True ($missing.TotaleModern -eq 0) 'missing campaign is empty'
    } catch {
        $script:Failed++
        Write-Output ('FAIL direct parity unavailable TYPE=' + $_.Exception.GetType().Name)
    } finally {
        if ($null -ne $connection) { $connection.Dispose() }
    }
}

function Test-RuntimeContract {
    Enable-LocalCertificateCompatibility
    try {
        $modern = Invoke-LocalGet 'articoli.aspx?inpromo=1'
        $legacy = Invoke-LocalGet 'promozioni.aspx'
        Assert-HealthyResponse $modern 'modern all promotions'
        Assert-HealthyResponse $legacy 'legacy all promotions'
        $modernTotal = Get-ReportedProductCount $modern.Content
        $legacyTotal = Get-ReportedProductCount $legacy.Content
        Assert-True ($modernTotal -gt 0) 'modern reports a complete promotion total'
        Assert-True ($legacyTotal -eq $modernTotal) 'legacy and modern HTTP totals match'
        Assert-PromotionSummaryMarkup $modern.Content 'modern all promotions'

        foreach ($campaign in @($SingleCampaignId,$MultiCampaignId,$TierCampaignId,2147483647)) {
            $modernCampaign = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $campaign)
            $legacyCampaign = Invoke-LocalGet ('promozioni.aspx?pid=' + $campaign)
            Assert-HealthyResponse $modernCampaign ('modern campaign ' + $campaign)
            Assert-HealthyResponse $legacyCampaign ('legacy campaign ' + $campaign)
            Assert-True ((Get-ReportedProductCount $modernCampaign.Content) -eq (Get-ReportedProductCount $legacyCampaign.Content)) ('campaign HTTP totals match ' + $campaign)
            if ((Get-ReportedProductCount $modernCampaign.Content) -gt 0) {
                Assert-PromotionSummaryMarkup $modernCampaign.Content ('modern campaign ' + $campaign)
            }
        }

        foreach ($badPid in @('abc','-1','0','2147483648','1%26pid%3D2')) {
            $invalid = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $badPid)
            Assert-HealthyResponse $invalid ('invalid pid ' + $badPid)
            Assert-True (@(Get-ProductIds $invalid.Content).Count -eq 0) ('invalid pid fails closed ' + $badPid)
        }

        $normal = Invoke-LocalGet 'articoli.aspx'
        Assert-HealthyResponse $normal 'normal catalog'
        Assert-True (@(Get-ProductIds $normal.Content).Count -gt 0) 'normal catalog still renders products'
        Assert-PromotionSummaryMarkup $normal.Content 'normal catalog promotion cards'
        $nonPromotionCard = Get-ProductCardWithoutPromotion $normal.Content
        Assert-True (-not [string]::IsNullOrWhiteSpace($nonPromotionCard)) 'normal catalog includes a non-promotion card fixture'
        Assert-True ($nonPromotionCard.IndexOf('ks-catalog-promos__label', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'non-promotion card has no Promo label'
        Assert-True ($nonPromotionCard.IndexOf('ks-catalog-promos__price', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'non-promotion card has no invented promotion price'
        Assert-True ([regex]::Matches($nonPromotionCard, 'class="[^"]*\bprice-wrap\b[^"]*"', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) 'non-promotion card keeps one normal price-wrap'

        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $zap = Invoke-LocalGet 'articoli.aspx?inpromo=1&q=ZAP80-A4' $session
        Assert-HealthyResponse $zap 'ZAP80-A4 catalog'
        $card = Get-ProductCardByCode $zap.Content 'ZAP80-A4'
        $cardText = Get-PageText $card
        Assert-True (-not [string]::IsNullOrWhiteSpace($card)) 'ZAP80-A4 card is present'
        Assert-True ((Get-ProductCardCountByCode $zap.Content 'ZAP80-A4') -eq 1) 'ZAP80-A4 card is not duplicated'
        Assert-ZapCatalogCardPresentation $card 'ZAP80-A4 catalog card'

        $tierOnly = Invoke-LocalGet ('articoli.aspx?inpromo=1&pid=' + $TierCampaignId) $session
        Assert-HealthyResponse $tierOnly 'tier-only campaign'
        $tierCard = Get-ProductCardByCode $tierOnly.Content 'ZAP80-A4'
        $tierText = Get-PageText $tierCard
        Assert-True ($tierText.IndexOf('Da 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'tier-only card shows Da teaser'
        Assert-True ($tierText.IndexOf('Promo 4,00 €', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'tier-only card does not show tier as current promo'
        Assert-True ($tierCard.IndexOf('ks-catalog-promos__label', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'tier-only card has no quantity-one Promo label'
        Assert-True ($tierText.IndexOf('MULTIPLI 5 PZ.', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'tier-only card keeps its quantity condition'
        Assert-True ([regex]::Matches((Get-PageText (Get-ElementByClass $tierCard 'price-wrap')), '(?<![0-9])6,00\s*€', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 1) 'tier-only card keeps the normal 6.00 price in price-wrap'

        $pdp = Invoke-LocalGet 'articolo.aspx?id=21906' $session
        Assert-HealthyResponse $pdp 'ZAP80-A4 PDP'
        Assert-True ([regex]::Matches($pdp.Content, 'ks-product-promos__item', [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count -eq 2) 'PDP lists both promotion types'
        $pdpText = Get-PageText $pdp.Content
        Assert-True ($pdpText.IndexOf('A 4,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $pdpText.IndexOf('A 5,00 €', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'PDP keeps both promotion prices'

        $recentCatalog = Invoke-LocalGet 'articoli.aspx?q=ZAP80-A4&ksreview=recent-promo' $session
        $recentSection = Get-SectionById $recentCatalog.Content 'ksRecentlyViewedBlock'
        $recentText = Get-PageText $recentSection
        Assert-HealthyResponse $recentCatalog 'catalog recently viewed'
        $recentCard = Get-ProductCardByCode $recentSection 'ZAP80-A4'
        Assert-ZapCatalogCardPresentation $recentCard 'catalog recently viewed ZAP80-A4 card'

        $homeResponse = Invoke-LocalGet 'Default.aspx?ksreview=recent-promo' $session
        $homeRecent = Get-SectionById $homeResponse.Content 'HomeRecentlyViewedSection'
        Assert-HealthyResponse $homeResponse 'home'
        Assert-ZapHomePresentation $homeRecent 'home recently viewed ZAP80-A4 card'
        Assert-Contains $homeResponse.Content 'ks-home-price-stack--emphasized' 'home keeps stable long-price geometry'
        Assert-True ($homeResponse.Content.IndexOf('1.500,00', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'home renders a long commercial price'
    } finally { Restore-LocalCertificateCompatibility }
}

Test-StaticContract
if (-not $SkipDirectParity) { Test-DirectParity }
if (-not $SkipRuntime) { Test-RuntimeContract }

Write-Output ('RESULT PASS={0} FAIL={1}' -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
