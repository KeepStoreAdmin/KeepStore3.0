[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://localhost:8443'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Passed = 0
$script:Failed = 0
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:Passed++
        Write-Host ('PASS ' + $Name)
    } else {
        $script:Failed++
        Write-Host ('FAIL ' + $Name)
    }
}

function New-HttpClient {
    param([bool]$FollowRedirects)
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $FollowRedirects
    $handler.ServerCertificateCustomValidationCallback = [Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(180)
    return $client
}

function Invoke-Request {
    param(
        [Net.Http.HttpClient]$Client,
        [string]$Method,
        [string]$PathAndQuery
    )
    $request = [Net.Http.HttpRequestMessage]::new(
        [Net.Http.HttpMethod]::new($Method),
        $BaseUrl.TrimEnd('/') + '/' + $PathAndQuery.TrimStart('/'))
    if ($Method -eq 'POST') {
        $request.Content = [Net.Http.StringContent]::new('__EVENTTARGET=legacy')
        $request.Content.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new('application/x-www-form-urlencoded')
    }
    try {
        return $Client.SendAsync($request).GetAwaiter().GetResult()
    } finally {
        $request.Dispose()
    }
}

function Assert-Redirect {
    param(
        [Net.Http.HttpClient]$Client,
        [string]$Method,
        [string]$PathAndQuery,
        [int]$Status,
        [string]$Location,
        [string]$Name
    )
    $response = Invoke-Request $Client $Method $PathAndQuery
    try {
        $actualLocation = if ($null -eq $response.Headers.Location) { '' } else { $response.Headers.Location.OriginalString }
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        Assert-True ([int]$response.StatusCode -eq $Status) ($Name + ' status ' + $Status)
        Assert-True ($actualLocation -ceq $Location) ($Name + ' controlled Location')
        Assert-True ($actualLocation.StartsWith('/', [StringComparison]::Ordinal) -and -not $actualLocation.StartsWith('//', [StringComparison]::Ordinal)) ($Name + ' local relative Location')
        Assert-True ([string]::IsNullOrEmpty($body)) ($Name + ' no legacy body')
    } finally {
        $response.Dispose()
    }
}

function Assert-HealthyGet {
    param([Net.Http.HttpClient]$Client, [string]$PathAndQuery, [string]$Name)
    $response = Invoke-Request $Client 'GET' $PathAndQuery
    try {
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        Assert-True ([int]$response.StatusCode -eq 200) ($Name + ' HTTP 200')
        Assert-True ($body.IndexOf('Server Error in', [StringComparison]::OrdinalIgnoreCase) -lt 0) ($Name + ' no ASP.NET error page')
        Assert-True ($body.IndexOf('MySqlException', [StringComparison]::OrdinalIgnoreCase) -lt 0) ($Name + ' no database error disclosure')
        return @{ Response = $response; Body = $body }
    } catch {
        $response.Dispose()
        throw
    }
}

function Get-TrackedFileText {
    param([string]$RelativePath)
    return [IO.File]::ReadAllText((Join-Path $repositoryRoot $RelativePath))
}

$noRedirectClient = New-HttpClient $false
$followClient = New-HttpClient $true
try {
    $validCases = @(
        @('promozioni.aspx', '/articoli.aspx?inpromo=1', 'all promotions'),
        @('promozioni.aspx?pid=0', '/articoli.aspx?inpromo=1', 'legacy pid zero'),
        @('promozioni.aspx?pid=19524', '/articoli.aspx?inpromo=1&pid=19524', 'single campaign'),
        @('promozioni.aspx?pid=14556', '/articoli.aspx?inpromo=1&pid=14556', 'multi campaign'),
        @('promozioni.aspx?pid=2147483647', '/articoli.aspx?inpromo=1&pid=2147483647', 'missing campaign')
    )
    foreach ($case in $validCases) {
        Assert-Redirect $noRedirectClient 'GET' $case[0] 301 $case[1] $case[2]
    }

    Assert-Redirect $noRedirectClient 'HEAD' 'promozioni.aspx?pid=19524' 301 '/articoli.aspx?inpromo=1&pid=19524' 'HEAD navigation'
    Assert-Redirect $noRedirectClient 'POST' 'promozioni.aspx?pid=19524' 303 '/articoli.aspx?inpromo=1&pid=19524' 'POST converted to GET navigation'

    $invalidLocation = '/articoli.aspx?inpromo=1&pid=invalid'
    $invalidCases = @(
        @('promozioni.aspx?pid=abc', 'text pid'),
        @('promozioni.aspx?pid=-1', 'negative pid'),
        @('promozioni.aspx?pid=1&pid=2', 'duplicate pid'),
        @('promozioni.aspx?pid=2147483648', 'overflow pid'),
        @('promozioni.aspx?unknown=1', 'unknown parameter'),
        @('promozioni.aspx?ReturnUrl=https%3A%2F%2Fevil.example%2F', 'external ReturnUrl'),
        @('promozioni.aspx?ReturnUrl=%2Fpromozioni.aspx%3Fpid%3D19524', 'nested ReturnUrl'),
        @('promozioni.aspx?part=21906', 'unrepresentable part filter')
    )
    foreach ($case in $invalidCases) {
        Assert-Redirect $noRedirectClient 'GET' $case[0] 301 $invalidLocation $case[1]
    }

    $filterCases = @(
        @('pmr', 'mr'), @('pst', 'st'), @('pct', 'ct'),
        @('ptp', 'tp'), @('pgr', 'gr'), @('psg', 'sg')
    )
    foreach ($mapping in $filterCases) {
        Assert-Redirect $noRedirectClient 'GET' ('promozioni.aspx?' + $mapping[0] + '=17') 301 ('/articoli.aspx?inpromo=1&' + $mapping[1] + '=17') ($mapping[0] + ' maps to ' + $mapping[1])
    }

    $promo = Assert-HealthyGet $followClient 'articoli.aspx?inpromo=1' 'modern promotion catalog'
    try {
        $robotsHeader = @($promo.Response.Headers.GetValues('X-Robots-Tag')) -join ','
        Assert-True ($robotsHeader.IndexOf('noindex,follow', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'filtered promotion catalog sends noindex,follow'
        Assert-True ($promo.Body.IndexOf('rel="canonical"', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'modern catalog emits canonical'
        Assert-True ($promo.Body.IndexOf('articoli.aspx?inpromo=1', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'all-promotions canonical keeps modern route'
        Assert-True ($promo.Body.IndexOf('promozioni.aspx', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'modern canonical/body never references legacy route'
    } finally {
        $promo.Response.Dispose()
    }

    $campaign = Assert-HealthyGet $followClient 'articoli.aspx?inpromo=1&pid=19524' 'specific campaign destination'
    try {
        Assert-True ($campaign.Body.IndexOf('articoli.aspx?inpromo=1&amp;pid=19524', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                     $campaign.Body.IndexOf('articoli.aspx?inpromo=1&pid=19524', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'campaign canonical preserves valid pid'
    } finally {
        $campaign.Response.Dispose()
    }

    $returnUrlPage = Assert-HealthyGet $followClient 'accessonegato.aspx?ReturnUrl=%2Fpromozioni.aspx%3Fpid%3D19524' 'legacy post-login ReturnUrl'
    try {
        Assert-True ($returnUrlPage.Body.IndexOf('login.aspx?ReturnUrl=%2farticoli.aspx%3finpromo%3d1%26pid%3d19524', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'login link carries normalized modern ReturnUrl'
        Assert-True ($returnUrlPage.Body.IndexOf('/articoli.aspx?inpromo=1&amp;pid=19524', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'safe return link targets modern campaign'
        Assert-True (-not [regex]::IsMatch($returnUrlPage.Body, 'href="[^"]*promozioni\.aspx', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'no navigable post-login link retains legacy route'
    } finally {
        $returnUrlPage.Response.Dispose()
    }

    $externalReturn = Assert-HealthyGet $followClient 'accessonegato.aspx?ReturnUrl=https%3A%2F%2Fevil.example%2Fpromozioni.aspx' 'external ReturnUrl rejection'
    try {
        Assert-True (-not [regex]::IsMatch($externalReturn.Body, 'href="[^"]*evil\.example', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'external ReturnUrl never reaches navigable output'
    } finally {
        $externalReturn.Response.Dispose()
    }

    $missing = Assert-HealthyGet $followClient 'articoli.aspx?inpromo=1&pid=2147483647' 'missing campaign destination'
    try {
        Assert-True ($missing.Body.IndexOf('La campagna promozionale richiesta non', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                     $missing.Body.IndexOf('0 prodotti', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                     $missing.Body.IndexOf('0 articoli', [StringComparison]::OrdinalIgnoreCase) -ge 0) 'missing campaign remains empty/fail-closed'
    } finally {
        $missing.Response.Dispose()
    }

    foreach ($regression in @(
        @('Default.aspx', 'HOME'),
        @('articoli.aspx', 'normal catalog'),
        @('articolo.aspx?id=21906', 'PDP')
    )) {
        $result = Assert-HealthyGet $followClient $regression[0] $regression[1]
        $result.Response.Dispose()
    }

    $shimMarkup = Get-TrackedFileText 'promozioni.aspx'
    $shimCode = Get-TrackedFileText 'promozioni.aspx.vb'
    $policy = Get-TrackedFileText 'App_Code\LegacyPromotionRoutePolicy.vb'
    $returnPolicy = Get-TrackedFileText 'App_Code\PostLoginReturnUrlPolicy.vb'
    Assert-True ($shimMarkup.Trim() -eq '<%@ Page Language="VB" AutoEventWireup="false" CodeFile="promozioni.aspx.vb" Inherits="promozioni" %>') 'legacy markup is directive-only'
    Assert-True ($shimCode.IndexOf('MySql', [StringComparison]::OrdinalIgnoreCase) -lt 0 -and $shimCode.IndexOf('Session(', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'legacy code has no database or Session filter access'
    Assert-True ($shimCode.IndexOf('Response.StatusCode = If(permanentNavigation, 301, 303)', [StringComparison]::Ordinal) -ge 0) 'shim has explicit GET/HEAD and POST semantics'
    Assert-True ($policy.IndexOf('query.GetValues("part")', [StringComparison]::Ordinal) -ge 0) 'part fails closed explicitly'
    Assert-True ($returnPolicy.IndexOf('LegacyPromotionRoutePolicy.BuildModernPath', [StringComparison]::Ordinal) -ge 0) 'post-login ReturnUrl normalizes the legacy route'
    Assert-True ($returnPolicy.IndexOf('"promozioni.aspx",', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'legacy route removed from final-page whitelist'

    $sitemapText = (Get-TrackedFileText 'sitemap.xml') + (Get-TrackedFileText 'sitemap.aspx.vb')
    Assert-True ($sitemapText.IndexOf('promozioni.aspx', [StringComparison]::OrdinalIgnoreCase) -lt 0) 'legacy route absent from sitemap sources'

    $navigableReferenceFound = $false
    $trackedFiles = & git -C $repositoryRoot ls-files '*.aspx' '*.ascx' '*.master' '*.vb' '*.js'
    foreach ($relativePath in $trackedFiles) {
        if ($relativePath -in @('promozioni.aspx', 'promozioni.aspx.vb')) { continue }
        if ($relativePath.StartsWith('Tools/', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $text = Get-TrackedFileText $relativePath
        if ([regex]::IsMatch($text, '(?i)(?:href|navigateurl|action)\s*=\s*["''][^"'']*promozioni\.aspx')) {
            $navigableReferenceFound = $true
            break
        }
    }
    Assert-True (-not $navigableReferenceFound) 'zero internal navigable links target the legacy route'
} finally {
    $noRedirectClient.Dispose()
    $followClient.Dispose()
}

Write-Output ('RESULT Passed=' + $script:Passed + ' Failed=' + $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
