<#
.SYNOPSIS
Verifica in sola lettura i contratti HTTP/SEO di una installazione KeepStore.

.DESCRIPTION
Esegue soltanto richieste GET e HEAD verso target espliciti. Non effettua login,
discovery, accesso diretto al database o modifiche remote. La validazione TLS
resta quella predefinita del sistema operativo.

.EXAMPLE
.\Test-KeepStoreTenantOnboarding.ps1 `
  -CanonicalUrl 'https://shop-a.example.invalid/' `
  -AliasUrls @('https://www.shop-a.example.invalid/') `
  -HomePath '/' `
  -CatalogPath '/articoli.aspx' `
  -ProductPath '/articolo.aspx?id=42' `
  -PrivatePaths @('/login.aspx', '/carrello.aspx') `
  -ForbiddenTenantHosts @('shop-b.example.invalid') `
  -UnknownHostUrls @('https://unknown.example.invalid/')
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Uri]$CanonicalUrl,

    [Parameter()]
    [Uri[]]$AliasUrls = @(),

    [Parameter(Mandatory = $true)]
    [string]$HomePath,

    [Parameter(Mandatory = $true)]
    [string]$CatalogPath,

    [Parameter(Mandatory = $true)]
    [string]$ProductPath,

    [Parameter(Mandatory = $true)]
    [string[]]$PrivatePaths,

    [Parameter()]
    [string[]]$ForbiddenTenantHosts = @(),

    [Parameter()]
    [Uri[]]$UnknownHostUrls = @(),

    [Parameter()]
    [switch]$AllowHttpForLoopbackTest,

    [ValidateRange(1, 120)]
    [int]$TimeoutSeconds = 20
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$checks = New-Object 'System.Collections.Generic.List[object]'

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )

    $checks.Add([PSCustomObject]@{
        Name = $Name
        Passed = $Passed
        Detail = $Detail
    })
}

function Get-Origin {
    param([Uri]$Uri)

    return $Uri.GetLeftPart([System.UriPartial]::Authority).TrimEnd('/')
}

function Assert-OriginTarget {
    param(
        [Uri]$Uri,
        [string]$ParameterName
    )

    if ($null -eq $Uri -or -not $Uri.IsAbsoluteUri) {
        throw ($ParameterName + '_ABSOLUTE_URL_REQUIRED')
    }
    if ($Uri.Scheme -ne [Uri]::UriSchemeHttps -and $Uri.Scheme -ne [Uri]::UriSchemeHttp) {
        throw ($ParameterName + '_HTTP_SCHEME_REQUIRED')
    }
    if ([string]::IsNullOrWhiteSpace($Uri.DnsSafeHost)) {
        throw ($ParameterName + '_HOST_REQUIRED')
    }
    if (-not [string]::IsNullOrEmpty($Uri.UserInfo)) {
        throw ($ParameterName + '_CREDENTIALS_NOT_ALLOWED')
    }
    if ($Uri.Scheme -eq [Uri]::UriSchemeHttp) {
        $loopbackHost = $Uri.DnsSafeHost -ieq 'localhost' -or $Uri.DnsSafeHost -eq '127.0.0.1' -or $Uri.DnsSafeHost -eq '::1'
        if (-not $AllowHttpForLoopbackTest -or -not $loopbackHost) {
            throw ($ParameterName + '_HTTPS_REQUIRED')
        }
    }
    if ($Uri.AbsolutePath -ne '/' -or -not [string]::IsNullOrEmpty($Uri.Query) -or -not [string]::IsNullOrEmpty($Uri.Fragment)) {
        throw ($ParameterName + '_ORIGIN_ONLY_REQUIRED')
    }
}

function Assert-RelativeTargetPath {
    param(
        [string]$Path,
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not $Path.StartsWith('/', [StringComparison]::Ordinal) -or $Path.StartsWith('//', [StringComparison]::Ordinal)) {
        throw ($ParameterName + '_LOCAL_PATH_REQUIRED')
    }
    if ($Path.IndexOf('#') -ge 0) {
        throw ($ParameterName + '_FRAGMENT_NOT_ALLOWED')
    }

    $absolute = $null
    if ([Uri]::TryCreate($Path, [UriKind]::Absolute, [ref]$absolute)) {
        throw ($ParameterName + '_ABSOLUTE_URL_NOT_ALLOWED')
    }
}

function New-TargetUri {
    param(
        [Uri]$Origin,
        [string]$Path
    )

    $base = New-Object Uri ((Get-Origin -Uri $Origin) + '/')
    return New-Object Uri ($base, $Path.TrimStart('/'))
}

function Invoke-ReadOnlyRequest {
    param(
        [Uri]$Uri,
        [ValidateSet('GET', 'HEAD')]
        [string]$Method = 'GET'
    )

    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = $Method
    $request.AllowAutoRedirect = $false
    $request.Timeout = $TimeoutSeconds * 1000
    $request.ReadWriteTimeout = $TimeoutSeconds * 1000
    $request.UserAgent = 'KeepStore-Tenant-Onboarding-Validator/1.0'
    $request.KeepAlive = $false
    $request.PreAuthenticate = $false
    $request.UseDefaultCredentials = $false
    $request.Headers['Purpose'] = 'prefetch'
    $request.Headers['Sec-Purpose'] = 'prefetch'

    $response = $null
    try {
        try {
            $response = [System.Net.HttpWebResponse]$request.GetResponse()
        }
        catch [System.Net.WebException] {
            if ($null -eq $_.Exception.Response) {
                return [PSCustomObject]@{
                    StatusCode = 0
                    Location = ''
                    Headers = $null
                    Body = ''
                }
            }
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
        }

        $body = ''
        if ($Method -eq 'GET') {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                try {
                    $body = $reader.ReadToEnd()
                }
                finally {
                    $reader.Dispose()
                }
            }
        }

        return [PSCustomObject]@{
            StatusCode = [int]$response.StatusCode
            Location = [string]$response.Headers['Location']
            Headers = $response.Headers
            Body = $body
        }
    }
    finally {
        if ($null -ne $response) {
            $response.Close()
        }
    }
}

function Get-HtmlAttribute {
    param(
        [string]$Tag,
        [string]$Name
    )

    $pattern = '(?is)\b' + [Regex]::Escape($Name) + '\s*=\s*(?:"(?<dq>[^"]*)"|''(?<sq>[^'']*)''|(?<uq>[^\s>]+))'
    $match = [Regex]::Match($Tag, $pattern)
    if (-not $match.Success) { return '' }
    if ($match.Groups['dq'].Success) { return $match.Groups['dq'].Value }
    if ($match.Groups['sq'].Success) { return $match.Groups['sq'].Value }
    return $match.Groups['uq'].Value
}

function Get-CanonicalUris {
    param([string]$Html)

    $result = New-Object 'System.Collections.Generic.List[Uri]'
    foreach ($tagMatch in [Regex]::Matches($Html, '(?is)<link\b[^>]*>')) {
        $tag = $tagMatch.Value
        $rel = Get-HtmlAttribute -Tag $tag -Name 'rel'
        if (@(@($rel -split '\s+') | Where-Object { $_ -ieq 'canonical' }).Count -eq 0) { continue }

        $href = Get-HtmlAttribute -Tag $tag -Name 'href'
        $uri = $null
        if ([Uri]::TryCreate($href, [UriKind]::Absolute, [ref]$uri)) {
            $result.Add($uri)
        }
        else {
            $result.Add($null)
        }
    }
    return @($result)
}

function Test-SameOrigin {
    param(
        [Uri]$Left,
        [Uri]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) { return $false }
    return (Get-Origin -Uri $Left) -ceq (Get-Origin -Uri $Right)
}

function Test-ForbiddenTenantHost {
    param([Uri]$Uri)

    if ($null -eq $Uri) { return $true }
    foreach ($forbiddenHost in $ForbiddenTenantHosts) {
        $normalized = ([string]$forbiddenHost).Trim().TrimEnd('.').ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($normalized)) { continue }
        if ($Uri.DnsSafeHost.TrimEnd('.').ToLowerInvariant() -eq $normalized) { return $true }
    }
    return $false
}

Assert-OriginTarget -Uri $CanonicalUrl -ParameterName 'CANONICAL_URL'

$seenOrigins = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
[void]$seenOrigins.Add((Get-Origin -Uri $CanonicalUrl))
foreach ($aliasUrl in $AliasUrls) {
    Assert-OriginTarget -Uri $aliasUrl -ParameterName 'ALIAS_URL'
    if (-not $seenOrigins.Add((Get-Origin -Uri $aliasUrl))) { throw 'DUPLICATE_TARGET_ORIGIN' }
}
foreach ($unknownUrl in $UnknownHostUrls) {
    Assert-OriginTarget -Uri $unknownUrl -ParameterName 'UNKNOWN_HOST_URL'
    if (-not $seenOrigins.Add((Get-Origin -Uri $unknownUrl))) { throw 'DUPLICATE_TARGET_ORIGIN' }
}

Assert-RelativeTargetPath -Path $HomePath -ParameterName 'HOME_PATH'
Assert-RelativeTargetPath -Path $CatalogPath -ParameterName 'CATALOG_PATH'
Assert-RelativeTargetPath -Path $ProductPath -ParameterName 'PRODUCT_PATH'
if ($null -eq $PrivatePaths -or $PrivatePaths.Count -eq 0) { throw 'PRIVATE_PATHS_REQUIRED' }
foreach ($privatePath in $PrivatePaths) {
    Assert-RelativeTargetPath -Path $privatePath -ParameterName 'PRIVATE_PATH'
}

$publicTargets = @(
    [PSCustomObject]@{ Name = 'HOME'; Path = $HomePath },
    [PSCustomObject]@{ Name = 'CATALOG'; Path = $CatalogPath },
    [PSCustomObject]@{ Name = 'PDP'; Path = $ProductPath }
)

foreach ($target in $publicTargets) {
    $targetUri = New-TargetUri -Origin $CanonicalUrl -Path $target.Path
    $response = Invoke-ReadOnlyRequest -Uri $targetUri -Method 'GET'
    Add-Check -Name ($target.Name + '_HTTP_200') -Passed ($response.StatusCode -eq 200) -Detail ('HTTP=' + $response.StatusCode)

    $canonicalUris = @(Get-CanonicalUris -Html $response.Body)
    Add-Check -Name ($target.Name + '_ONE_CANONICAL') -Passed ($canonicalUris.Count -eq 1) -Detail ('COUNT=' + $canonicalUris.Count)

    $validCanonical = $canonicalUris.Count -eq 1 -and $null -ne $canonicalUris[0] -and
        (Test-SameOrigin -Left $canonicalUris[0] -Right $CanonicalUrl) -and
        -not (Test-ForbiddenTenantHost -Uri $canonicalUris[0])
    Add-Check -Name ($target.Name + '_CANONICAL_TENANT') -Passed $validCanonical -Detail 'EXPECTED_TENANT_ORIGIN'
}

$aliasIndex = 0
foreach ($aliasUrl in $AliasUrls) {
    $aliasIndex += 1
    $aliasTarget = New-TargetUri -Origin $aliasUrl -Path $HomePath
    $response = Invoke-ReadOnlyRequest -Uri $aliasTarget -Method 'HEAD'
    $permanent = $response.StatusCode -eq 301 -or $response.StatusCode -eq 308
    Add-Check -Name ('ALIAS_' + $aliasIndex + '_PERMANENT_REDIRECT') -Passed $permanent -Detail ('HTTP=' + $response.StatusCode)

    $locationUri = $null
    $validLocation = [Uri]::TryCreate($response.Location, [UriKind]::Absolute, [ref]$locationUri) -and
        (Test-SameOrigin -Left $locationUri -Right $CanonicalUrl) -and
        -not (Test-ForbiddenTenantHost -Uri $locationUri)
    Add-Check -Name ('ALIAS_' + $aliasIndex + '_CANONICAL_TARGET') -Passed $validLocation -Detail 'EXPECTED_TENANT_ORIGIN'
}

$robotsUri = New-TargetUri -Origin $CanonicalUrl -Path '/robots.txt'
$robotsResponse = Invoke-ReadOnlyRequest -Uri $robotsUri -Method 'GET'
Add-Check -Name 'ROBOTS_HTTP_200' -Passed ($robotsResponse.StatusCode -eq 200) -Detail ('HTTP=' + $robotsResponse.StatusCode)
$sitemapLines = @($robotsResponse.Body -split "`r?`n" | Where-Object { $_ -match '^\s*Sitemap\s*:' })
$robotsSitemapUri = $null
$robotsSitemapValid = $false
if ($sitemapLines.Count -eq 1) {
    $sitemapValue = ($sitemapLines[0] -replace '^\s*Sitemap\s*:\s*', '').Trim()
    $robotsSitemapValid = [Uri]::TryCreate($sitemapValue, [UriKind]::Absolute, [ref]$robotsSitemapUri) -and
        (Test-SameOrigin -Left $robotsSitemapUri -Right $CanonicalUrl) -and
        $robotsSitemapUri.AbsolutePath -ieq '/sitemap.xml' -and
        -not (Test-ForbiddenTenantHost -Uri $robotsSitemapUri)
}
Add-Check -Name 'ROBOTS_CANONICAL_SITEMAP' -Passed $robotsSitemapValid -Detail ('SITEMAP_LINES=' + $sitemapLines.Count)

$sitemapUri = New-TargetUri -Origin $CanonicalUrl -Path '/sitemap.xml'
$sitemapResponse = Invoke-ReadOnlyRequest -Uri $sitemapUri -Method 'GET'
Add-Check -Name 'SITEMAP_HTTP_200' -Passed ($sitemapResponse.StatusCode -eq 200) -Detail ('HTTP=' + $sitemapResponse.StatusCode)

$sitemapValid = $false
$sitemapLocationCount = 0
try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.XmlResolver = $null
    $xml.LoadXml($sitemapResponse.Body)
    $manager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $manager.AddNamespace('sm', 'http://www.sitemaps.org/schemas/sitemap/0.9')
    $locationNodes = @($xml.SelectNodes('//sm:loc', $manager))
    $sitemapLocationCount = $locationNodes.Count
    $sitemapValid = $sitemapLocationCount -gt 0
    foreach ($locationNode in $locationNodes) {
        $locationUri = $null
        if (-not [Uri]::TryCreate($locationNode.InnerText.Trim(), [UriKind]::Absolute, [ref]$locationUri) -or
            -not (Test-SameOrigin -Left $locationUri -Right $CanonicalUrl) -or
            (Test-ForbiddenTenantHost -Uri $locationUri)) {
            $sitemapValid = $false
            break
        }
    }
}
catch {
    $sitemapValid = $false
}
Add-Check -Name 'SITEMAP_TENANT_ISOLATION' -Passed $sitemapValid -Detail ('URL_COUNT=' + $sitemapLocationCount)

$privateIndex = 0
foreach ($privatePath in $PrivatePaths) {
    $privateIndex += 1
    $privateUri = New-TargetUri -Origin $CanonicalUrl -Path $privatePath
    $response = Invoke-ReadOnlyRequest -Uri $privateUri -Method 'GET'
    $robotsHeader = ''
    if ($null -ne $response.Headers) { $robotsHeader = [string]$response.Headers['X-Robots-Tag'] }
    $metaNoIndex = [Regex]::IsMatch($response.Body, '(?is)<meta\b[^>]*\bname\s*=\s*["'']robots["''][^>]*\bcontent\s*=\s*["''][^"'']*noindex') -or
        [Regex]::IsMatch($response.Body, '(?is)<meta\b[^>]*\bcontent\s*=\s*["''][^"'']*noindex[^"'']*["''][^>]*\bname\s*=\s*["'']robots["'']')
    $hasNoIndex = $robotsHeader.IndexOf('noindex', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $metaNoIndex
    Add-Check -Name ('PRIVATE_' + $privateIndex + '_NOINDEX') -Passed $hasNoIndex -Detail 'NOINDEX_REQUIRED'
}

$unknownIndex = 0
foreach ($unknownUrl in $UnknownHostUrls) {
    $unknownIndex += 1
    $unknownTarget = New-TargetUri -Origin $unknownUrl -Path $HomePath
    $response = Invoke-ReadOnlyRequest -Uri $unknownTarget -Method 'HEAD'
    $safeFailure = @(400, 403, 404, 421).Contains($response.StatusCode) -and [string]::IsNullOrWhiteSpace($response.Location)
    Add-Check -Name ('UNKNOWN_HOST_' + $unknownIndex + '_FAIL_CLOSED') -Passed $safeFailure -Detail ('HTTP=' + $response.StatusCode)
}

Write-Output ('TARGET=' + (Get-Origin -Uri $CanonicalUrl))
foreach ($check in $checks) {
    $state = if ($check.Passed) { 'PASS' } else { 'FAIL' }
    Write-Output ($state + ' ' + $check.Name + ' ' + $check.Detail)
}

$failures = @($checks | Where-Object { -not $_.Passed })
Write-Output ('SUMMARY PASS=' + ($checks.Count - $failures.Count) + ' FAIL=' + $failures.Count)
if ($failures.Count -gt 0) { exit 1 }
