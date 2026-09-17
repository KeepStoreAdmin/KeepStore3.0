[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:Passed++
        Write-Output ('PASS ' + $Message)
        return
    }
    $script:Failed++
    Write-Output ('FAIL ' + $Message)
}

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Message)
    Assert-True ($Text.IndexOf($Expected, [StringComparison]::Ordinal) -ge 0) $Message
}

function Assert-NotContains {
    param([string]$Text, [string]$Unexpected, [string]$Message)
    Assert-True ($Text.IndexOf($Unexpected, [StringComparison]::Ordinal) -lt 0) $Message
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$homeSource = [IO.File]::ReadAllText((Join-Path $root 'Default.aspx.vb'))
$resolver = [IO.File]::ReadAllText((Join-Path $root 'App_Code\ProductPromotionEligibilityResolver.vb'))
$display = [IO.File]::ReadAllText((Join-Path $root 'App_Code\ProductPromotionDisplayHelper.vb'))

Assert-Contains $homeSource '_homePromotionModelCache As New Dictionary(Of String, ProductPromotionDisplayModel)(StringComparer.Ordinal)' 'HOME uses a page/request-scoped promotion model cache'
Assert-Contains $homeSource 'PopulatePromotionDisplaySnapshot(featuredRows)' 'HOME resolves only the final featured rows'
Assert-Contains $homeSource 'PopulatePromotionDisplaySnapshot(bestRows)' 'HOME resolves only the final best-seller rows'
Assert-Contains $homeSource 'PopulatePromotionDisplaySnapshot(recentRows)' 'HOME resolves only the final recent rows'

$poolPattern = '(?s)da\.Fill\(dt\)\s+EnsurePromotionDisplayColumns\(dt\)\s+If requireAuthorizedPromotion Then\s+PopulatePromotionDisplaySnapshot\(dt\)\s+dt = FilterAuthorizedPromotionRows\(dt\)\s+End If'
Assert-True ([regex]::IsMatch($homeSource, $poolPattern)) 'full-pool resolution is retained only when promotion authorization is required'
Assert-True (-not [regex]::IsMatch($homeSource, 'da\.Fill\(dt\)\s+PopulatePromotionDisplaySnapshot\(dt\)')) 'ordinary HOME pools are not resolved before final selection'

Assert-Contains $homeSource 'tcId.ToString(CultureInfo.InvariantCulture) & ":" & contextKey & ":"' 'cache key distinguishes article variant and eligibility context'
Assert-Contains $homeSource 'baseNetPrice.ToString(CultureInfo.InvariantCulture) & ":" &' 'cache key includes the net base price'
Assert-Contains $homeSource 'baseGrossPrice.ToString(CultureInfo.InvariantCulture)' 'cache key includes the gross base price'
Assert-Contains $homeSource 'model.ResolutionState <> ProductPromotionDisplayResolutionState.TechnicalError' 'TechnicalError display models are never cached'
Assert-Contains $homeSource 'ProductPromotionDisplayHelper.BuildForProduct(' 'HOME keeps the canonical promotion display engine'

Assert-Contains $resolver 'RequestCachePrefix & eligibilityContext.CacheKey' 'resolver snapshot remains request-scoped by the full eligibility context'
Assert-Contains $resolver 'current.Items(cacheKey) = snapshot' 'resolver retains one request snapshot per context'
Assert-Contains $resolver 'If cached IsNot Nothing Then Return cached' 'resolver reuses the request snapshot'

Assert-True (-not [regex]::IsMatch($homeSource, 'Shared\s+ReadOnly\s+_homePromotionModelCache')) 'promotion model cache is not shared across requests'
Assert-NotContains $homeSource 'Session("KeepStore.Promotion' 'HOME introduces no session promotion cache'
Assert-NotContains $homeSource 'ProductPromotionPerformanceProbe' 'temporary performance probe is absent from HOME'
Assert-NotContains $resolver 'ProductPromotionPerformanceProbe' 'temporary performance probe is absent from resolver'
Assert-NotContains $display 'ProductPromotionPerformanceProbe' 'temporary performance probe is absent from display helper'

Write-Output ('RESULT Passed={0} Failed={1}' -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
