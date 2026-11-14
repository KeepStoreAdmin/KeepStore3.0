[CmdletBinding()]
param()

# KS-A04-HOME-PRICE-AUDIT-1A - prezzi e sconti della HOME e variazione delle vetrine a ogni richiesta.
# Parte 1: le VERE classi App_Code/StorefrontPromotionDisplayPolicy.vb e StorefrontShowcaseRotation.vb sono compilate e provate
#          (regola dello sconto sui prezzi arrotondati, soglie, rotazione con memoria, mai fuori dalla finestra, mai fuori dai candidati).
# Parte 2: controlli statici su Default.aspx.vb (la regola e usata da prezzo barrato, badge e "Risparmi"; quantita netta e prezzo base
#          in ogni pool; promozione solo da snapshot; rotazione sui candidati selezionabili; intestazione di cache).
# Ogni regola e provata con mutazioni: se la regola viene tolta il test deve fallire.
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
    $old = $old -replace "`r`n", "`n"; $new = $new -replace "`r`n", "`n"
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Get-Method([string]$source, [string]$name) {
    $m = [regex]::Match($source, '(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) ' + [regex]::Escape($name) + '\b.*?^    End (?:Function|Sub)')
    if (-not $m.Success) { return '' }
    return $m.Value
}

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 1 - comportamento reale
# ---------------------------------------------------------------------------------------------------------------------------------
$probe = @'
Public Class HomeProbe
    Public Shared Function Show(ByVal basePrice As Decimal, ByVal payable As Decimal) As String
        Dim d As StorefrontPromotionDisplay = StorefrontPromotionDisplayPolicy.Resolve(basePrice, payable)
        Return d.HasDiscount.ToString() & "|" & d.BasePrice.ToString("0.00", CultureInfo.InvariantCulture) & "|" &
               d.PayablePrice.ToString("0.00", CultureInfo.InvariantCulture) & "|" & d.Savings.ToString("0.00", CultureInfo.InvariantCulture) & "|" & d.Percent.ToString()
    End Function

    Public Shared Function Property20000(ByVal seed As Integer) As String
        Dim rnd As New Random(seed)
        Dim bad As Integer = 0
        Dim withDiscount As Integer = 0
        For i As Integer = 1 To 20000
            Dim basePrice As Decimal = Math.Round(CDec(0.5 + rnd.NextDouble() * 500.0), 4)
            Dim factor As Decimal = CDec(0.9 + rnd.NextDouble() * 0.1)
            Dim payable As Decimal = Math.Round(basePrice * factor, 4)
            Dim d As StorefrontPromotionDisplay = StorefrontPromotionDisplayPolicy.Resolve(basePrice, payable)
            Dim b As Decimal = Math.Round(basePrice, 2, MidpointRounding.AwayFromZero)
            Dim p As Decimal = Math.Round(payable, 2, MidpointRounding.AwayFromZero)
            If d.HasDiscount Then
                withDiscount += 1
                Dim exact As Decimal = (b - p) / b * 100D
                If d.Savings <> b - p OrElse d.Percent < 1 OrElse d.Percent > 99 OrElse exact < 1D OrElse p >= b OrElse d.BasePrice <> b OrElse d.PayablePrice <> p Then bad += 1
            Else
                If d.Savings <> 0D OrElse d.Percent <> 0 Then bad += 1
                If p < b AndAlso (b - p) >= 0.01D AndAlso (b - p) / b * 100D >= 1D Then bad += 1
            End If
        Next
        Return bad.ToString() & "|" & withDiscount.ToString()
    End Function

    Public Shared Function Order(ByVal ids As String, ByVal take As Integer, ByVal recent As String, ByVal seed As Integer) As String
        Dim table As DataTable = Build(ids)
        Dim rotated As DataTable = StorefrontShowcaseRotation.Rotate(table, take, If(recent Is Nothing, Nothing, StorefrontShowcaseRotation.ParseIds(recent)), New Random(seed))
        Return StorefrontShowcaseRotation.FormatIds(rotated)
    End Function

    Public Shared Function SourceUntouched(ByVal ids As String) As String
        Dim table As DataTable = Build(ids)
        Dim before As String = StorefrontShowcaseRotation.FormatIds(table)
        Dim rotated As DataTable = StorefrontShowcaseRotation.Rotate(table, 6, Nothing, New Random(5))
        Return (before = StorefrontShowcaseRotation.FormatIds(table)).ToString() & "|" & (Not Object.ReferenceEquals(rotated, table)).ToString()
    End Function

    Public Shared Function Degenerate() As String
        Dim t As DataTable = Build("1,2,3,4")
        Dim noId As New DataTable()
        noId.Columns.Add("x", GetType(Integer))
        noId.Rows.Add(1)
        Dim a As Boolean = Object.ReferenceEquals(StorefrontShowcaseRotation.Rotate(Nothing, 6, Nothing, New Random(1)), Nothing)
        Dim b As Boolean = Object.ReferenceEquals(StorefrontShowcaseRotation.Rotate(t, 0, Nothing, New Random(1)), t)
        Dim c As Boolean = Object.ReferenceEquals(StorefrontShowcaseRotation.Rotate(t, 6, Nothing, Nothing), t)
        Dim d As Boolean = Object.ReferenceEquals(StorefrontShowcaseRotation.Rotate(noId, 6, Nothing, New Random(1)), noId)
        Dim e As Boolean = StorefrontShowcaseRotation.Rotate(New DataTable(), 6, Nothing, New Random(1)).Rows.Count = 0
        Return a.ToString() & b.ToString() & c.ToString() & d.ToString() & e.ToString()
    End Function

    Public Shared Function Ids(ByVal raw As String) As String
        Dim parsed As HashSet(Of Integer) = StorefrontShowcaseRotation.ParseIds(raw)
        Dim list As New List(Of Integer)(parsed)
        list.Sort()
        Return String.Join(",", list.ConvertAll(Function(n As Integer) n.ToString()).ToArray())
    End Function

    Private Shared Function Build(ByVal ids As String) As DataTable
        Dim t As New DataTable()
        t.Columns.Add("id", GetType(Integer))
        For Each part As String In ids.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
            t.Rows.Add(Integer.Parse(part))
        Next
        Return t
    End Function
End Class
'@

function Invoke-Behaviour([string]$policyText, [string]$rotationText) {
    $failed = New-Object 'Collections.Generic.List[string]'
    $clean = { param($s) [regex]::Replace($s, '(?m)^(Option .*|Imports .*)\r?\n', '') }
    $code = "Imports System`nImports System.Collections.Generic`nImports System.Data`nImports System.Globalization`n" + (& $clean $policyText) + "`n" + (& $clean $rotationText) + "`n" + $probe
    Add-Type -AssemblyName Microsoft.VisualBasic
    $compiler = New-Object Microsoft.VisualBasic.VBCodeProvider
    try {
        $parameters = New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory = $true
        $parameters.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict-'
        foreach ($a in @('System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Xml.dll')) { [void]$parameters.ReferencedAssemblies.Add($a) }
        $compiled = $compiler.CompileAssemblyFromSource($parameters, $code)
        if ($compiled.Errors.HasErrors) { return @{ Compiled = $false; Failed = @(($compiled.Errors | ForEach-Object { $_.ErrorText }) -join '; ') } }
        $pt = $compiled.CompiledAssembly.GetType('HomeProbe', $true)
        function Call([string]$name, [object[]]$args2) { return [string]$pt.GetMethod($name).Invoke($null, $args2) }
        function Check([bool]$ok, [string]$name) { if (-not $ok) { $failed.Add($name) } }
        function Show([decimal]$b, [decimal]$p) { return (Call 'Show' @($b, $p)) }

        # --- prezzi e sconti
        Check ((Show 6.00 4.99) -ceq 'True|6.00|4.99|1.01|17') 'list 6,00 promo 4,99 -> saving 1,01 (-17%)'
        Check ((Show 5.00 4.99) -ceq 'False|5.00|4.99|0.00|0') 'list 5,00 promo 4,99 -> no discount decoration, payable price kept'
        Check ((Show 6.004 5.996) -ceq 'False|6.00|6.00|0.00|0') 'raw 6,004 and 5,996 print the same price: no saving of 0,01'
        Check ((Show 100.00 99.49) -ceq 'False|100.00|99.49|0.00|0') '0,51 percent is not an offer even if the badge would round to 1'
        Check ((Show 100.00 99.00) -ceq 'True|100.00|99.00|1.00|1') 'exactly 1 percent is an offer'
        Check ((Show 100.00 99.01) -ceq 'False|100.00|99.01|0.00|0') '0,99 percent is not an offer'
        Check ((Show 24.90 14.994) -ceq 'True|24.90|14.99|9.91|40') 'saving is the difference of the two printed prices'
        Check ((Show 6.00 4.995) -ceq 'True|6.00|5.00|1.00|17') 'half-up on the printed price'
        Check ((Show 5.00 5.00) -ceq 'False|5.00|5.00|0.00|0') 'promo equal to base is not a discount'
        Check ((Show 5.00 6.00) -ceq 'False|5.00|6.00|0.00|0') 'promo above base is not a discount'
        Check ((Show 0 4.99) -ceq 'False|0.00|4.99|0.00|0') 'no base price: no discount'
        Check ((Show 5.00 0.004) -ceq 'False|5.00|0.00|0.00|0') 'a payable price that prints 0,00 is not a discount'
        Check ((Show 1.00 0.99) -ceq 'True|1.00|0.99|0.01|1') 'one cent on one euro is exactly 1 percent'
        Check ((Show 10000.00 0.01) -ceq 'True|10000.00|0.01|9999.99|99') 'a positive price is never presented as -100%'
        Check ((Call 'Property20000' @(20261114)) -match '^0\|\d+$') 'property: 20000 random pairs keep every invariant'

        # --- rotazione
        $src = (1..40) -join ','
        $first = (Call 'Order' @($src, 6, $null, 7)).Split(',')
        Check ($first.Count -eq 40 -and (@($first | Sort-Object { [int]$_ }) -join ',') -ceq $src) 'rotation returns exactly the same rows (a permutation)'
        $top = @($first[0..5] | ForEach-Object { [int]$_ })
        Check (@($top | Where-Object { $_ -gt 18 }).Count -eq 0) 'the first slots come only from the window (first 3 x N candidates)'
        $tail = @($first[18..39] | ForEach-Object { [int]$_ })
        Check ((($tail) -join ',') -ceq ((19..40) -join ',')) 'candidates beyond the window keep their original order'
        $recent = ($top -join ',')
        $next = (Call 'Order' @($src, 6, $recent, 8)).Split(',')
        $nextTop = @($next[0..5] | ForEach-Object { [int]$_ })
        Check (@($nextTop | Where-Object { $top -contains $_ }).Count -eq 0) 'the next request shows 6 different items when 12 alternatives exist'
        $union = New-Object 'Collections.Generic.HashSet[int]'
        $prev = $recent; $disjoint = $true; $outside = $false; $distinctOrders = New-Object 'Collections.Generic.HashSet[string]'
        foreach ($i in 1..300) {
            $r = (Call 'Order' @($src, 6, $prev, (1000 + $i))).Split(',')
            $t6 = @($r[0..5] | ForEach-Object { [int]$_ })
            if (@($t6 | Where-Object { @($prev.Split(',') | ForEach-Object { [int]$_ }) -contains $_ }).Count -ne 0) { $disjoint = $false }
            foreach ($v in $t6) { [void]$union.Add($v); if ($v -gt 18) { $outside = $true } }
            [void]$distinctOrders.Add(($t6 -join ','))
            $prev = ($t6 -join ',')
        }
        Check ($disjoint) 'over 300 consecutive requests two consecutive selections never share an item'
        Check ((-not $outside) -and $union.Count -eq 18) 'every candidate of the window appears over time, none from outside'
        Check ($distinctOrders.Count -gt 250) 'selections and orders keep changing'
        $few = (Call 'Order' @('1,2,3,4,5,6', 6, '1,2,3', 3)).Split(',')
        Check ((@($few | Sort-Object { [int]$_ }) -join ',') -ceq '1,2,3,4,5,6') 'with only N candidates the assortment is the same (only the order can change)'
        $mix = (Call 'Order' @(((1..18) -join ','), 6, ((1..15) -join ','), 4)).Split(',')
        Check ($mix.Count -eq 18 -and (@($mix[0..2] | ForEach-Object { [int]$_ }) -join ',') -ceq '16,17,18' -or (@($mix[0..2] | ForEach-Object { [int]$_ } | Sort-Object) -join ',') -ceq '16,17,18') 'fresh candidates come first even when fewer than N'
        Check ((Call 'SourceUntouched' @($src)) -ceq 'True|True') 'the source table is never modified'
        Check ((Call 'Degenerate' @()) -ceq 'TrueTrueTrueTrueTrue') 'empty, null, no id column, no random, take 0: returned as is'
        Check ((Call 'Ids' @('1,2,2,abc,-3, 4 ,0,999999999999,5x')) -ceq '1,2,4') 'ParseIds ignores garbage'
        Check ((Call 'Ids' @($null)) -ceq '') 'ParseIds of nothing is empty'
        $many = (1..100) -join ','
        Check ((Call 'Ids' @($many)).Split(',').Count -eq 64) 'ParseIds caps the memory at 64 ids'
    }
    catch { $failed.Add('exception: ' + $_.Exception.Message) }
    finally { $compiler.Dispose() }
    return @{ Compiled = $true; Failed = @($failed) }
}

$policy = Read-Repo 'App_Code/StorefrontPromotionDisplayPolicy.vb'
$rotation = Read-Repo 'App_Code/StorefrontShowcaseRotation.vb'
$run = Invoke-Behaviour $policy $rotation
Assert-Source ($run.Compiled) 'REAL_CLASSES_COMPILE'
Assert-Source (@($run.Failed).Count -eq 0) ('REAL_CLASSES_BEHAVE' + $(if (@($run.Failed).Count -gt 0) { ' failed: ' + ($run.Failed -join ' | ') } else { '' }))

function Test-Mutation([string]$text, [string]$old, [string]$new, [string]$code, [bool]$onPolicy) {
    $mutated = Mutate-Text $text $old $new $code
    $r = $(if ($onPolicy) { Invoke-Behaviour $mutated $rotation } else { Invoke-Behaviour $policy $mutated })
    if (-not $r.Compiled) { throw ('MUTATION_DOES_NOT_COMPILE=' + $code + ' ' + ($r.Failed -join '; ')) }
    Assert-Detected (@($r.Failed).Count -eq 0) $code
}
Test-Mutation $policy 'Dim baseRounded As Decimal = RoundMoney(basePrice)' 'Dim baseRounded As Decimal = basePrice' 'P01_BASE_NOT_ROUNDED' $true
Test-Mutation $policy 'Dim payableRounded As Decimal = RoundMoney(payablePrice)' 'Dim payableRounded As Decimal = payablePrice' 'P02_PAYABLE_NOT_ROUNDED' $true
Test-Mutation $policy 'If savings < MinimumSavings OrElse exactPercent < MinimumPercent Then' 'If savings < MinimumSavings Then' 'P03_NO_PERCENT_THRESHOLD' $true
# Soglia del centesimo: con prezzi arrotondati a due decimali ogni differenza positiva e gia di almeno 0,01, quindi e una guardia ridondante (mutante equivalente, non provabile).
Test-Mutation $policy 'Dim percent As Integer = Math.Min(99, Convert.ToInt32(Math.Round(exactPercent, 0, MidpointRounding.AwayFromZero)))' 'Dim percent As Integer = Convert.ToInt32(Math.Round(exactPercent, 0, MidpointRounding.AwayFromZero))' 'P05_PERCENT_CAP_REMOVED' $true
Test-Mutation $policy 'If savings < MinimumSavings OrElse exactPercent < MinimumPercent Then' 'If savings < MinimumSavings OrElse Math.Round(exactPercent, 0, MidpointRounding.AwayFromZero) < MinimumPercent Then' 'P06_THRESHOLD_ON_THE_ROUNDED_PERCENT' $true
Test-Mutation $policy 'Return Math.Round(value, 2, MidpointRounding.AwayFromZero)' 'Return Math.Round(value, 2, MidpointRounding.ToEven)' 'P07_BANKERS_ROUNDING' $true
Test-Mutation $policy 'If baseRounded <= 0D OrElse payableRounded <= 0D OrElse payableRounded >= baseRounded Then' 'If baseRounded <= 0D OrElse payableRounded >= baseRounded Then' 'P08_ZERO_PAYABLE_PRICE_BECOMES_A_DISCOUNT' $true
Test-Mutation $rotation 'If recentIds IsNot Nothing AndAlso id > 0 AndAlso recentIds.Contains(id) Then' 'If False Then' 'R01_RECENT_ITEMS_NOT_DEFERRED' $false
Test-Mutation $rotation 'Public Const WindowFactor As Integer = 3' 'Public Const WindowFactor As Integer = 30' 'R02_WINDOW_TOO_WIDE' $false
Test-Mutation $rotation '        Shuffle(fresh, random)
' '' 'R03_FRESH_NOT_SHUFFLED' $false
Test-Mutation $rotation '        For index As Integer = windowSize To source.Rows.Count - 1
            result.ImportRow(source.Rows(index))
        Next' '' 'R04_ROWS_BEYOND_THE_WINDOW_DROPPED' $false
Test-Mutation $rotation 'If result.Count >= 64 Then Exit For' '' 'R05_MEMORY_NOT_CAPPED' $false
Test-Mutation $rotation '        Dim result As DataTable = source.Clone()' '        Dim result As DataTable = source' 'R06_SOURCE_MUTATED' $false

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 2 - controlli statici
# ---------------------------------------------------------------------------------------------------------------------------------
$vb = Read-Repo 'Default.aspx.vb'

function Test-DisplayRule([string]$v) {
    $pd = Get-Method $v 'PromotionDisplay'
    return ($pd.Contains('Return StorefrontPromotionDisplayPolicy.Resolve(GetBasePrice(row), CurrentPrice(row))') -and
            (Get-Method $v 'SavingsAmount').Contains('Return PromotionDisplay(row).Savings') -and
            (Get-Method $v 'ShowDiscount').Contains('Return PromotionDisplay(row).HasDiscount') -and
            (Get-Method $v 'DiscountPercent').Contains('Return PromotionDisplay(row).Percent') -and
            $v -notmatch 'listino\s*-\s*current' -and
            (Get-Method $v 'FilterAuthorizedPromotionRows').Contains('If ShowDiscount(row) Then') -and
            (Get-Method $v 'FilterAuthorizedPromotionRows') -notmatch 'DisplayPromoTierPrice')
}
function Test-PayablePriceUntouched([string]$v) {
    $cp = Get-Method $v 'CurrentPrice'
    $price = Get-Method $v 'RenderPriceBlock'
    return ($cp.Contains('If TryGetValidPromoPrice(row, promoPrice) Then') -and $cp.Contains('Return promoPrice') -and $cp.Contains('Return GetBasePrice(row)') -and $cp -notmatch 'RoundMoney' -and
            $price.Contains('If ShowDiscount(row) Then') -and $price.Contains('FormatMoney(GetBasePrice(row))') -and $price.Contains('StorefrontPromotionDisplayPolicy.RoundMoney(current) > 0D'))
}
function Test-NetStockEverywhere([string]$v) {
    $net = Get-Method $v 'NetStockSql'
    $load = Get-Method $v 'TryLoadProducts'
    return ($net.Contains('Return "(" & StockWhereClause() & "-" & ReservedWhereClause() & ")"') -and
            $load.Contains('sql.Append("AND ").Append(NetStockSql()).Append(">=1 ")') -and $load.Contains('sql.Append("AND (").Append(NetStockSql()).Append(">=1 OR COALESCE(v.InOrdine,0)>0) ")') -and
            (Get-Method $v 'OfferWhereClause').Contains('NetStockSql() & ">=1"') -and (Get-Method $v 'GetNewArrivalsPool').Contains('NetStockSql() & ">=1 AND COALESCE(v.InOrdine,0)<=0') -and
            (Get-Method $v 'GetRecentlyViewedProducts').Contains('NetStockSql() & ">=1"') -and
            $v -notmatch 'StockWhereClause\(\) & "\s*>=\s*1' -and $load -notmatch 'Append\(StockWhereClause\(\)\)')
}
function Test-BasePriceEverywhere([string]$v) {
    $load = Get-Method $v 'TryLoadProducts'
    $idx = $load.IndexOf('sql.Append("AND ").Append(If(_priceDisplayContext.IsVatIncluded, prezzoIvatoSql, "COALESCE(v.Prezzo,0)")).Append(">0 ")')
    $disc = $load.IndexOf('If catalogDiscovery Then')
    return ($idx -ge 0 -and $load -notmatch 'PrezzoPromo,0\)>0 OR' -and $load -notmatch 'COALESCE\(v\.PrezzoIvato,0\)>0 OR' -and
            ($load.Substring(0, $idx) -notmatch '(?s)If catalogDiscovery Then\s*\r?\n\s*''[^\n]*\n\s*sql\.Append\("AND "\)\.Append\(If\(_priceDisplayContext' ))
}
function Test-SnapshotOnly([string]$v) {
    $promo = Get-Method $v 'TryGetValidPromoPrice'
    $tier = Get-Method $v 'TryGetValidTierPrice'
    $pop = Get-Method $v 'PopulatePromotionDisplaySnapshot'
    return ($promo.Contains('If HasPromotionDisplayTechnicalError(row) OrElse Not HasPromotionDisplaySnapshot(row) Then Return False') -and
            $tier.Contains('If HasPromotionDisplayTechnicalError(row) OrElse Not HasPromotionDisplaySnapshot(row) Then Return False') -and
            $v -notmatch 'TryGetCommercialPromoPrice|IsPromoRowValid|IsQuantityCompatible' -and
            $pop.Contains('row("DisplayPromoQtyOnePrice") = DBNull.Value') -and $pop.Contains('row("DisplayPromoTierPrice") = DBNull.Value') -and
            $pop.Contains('row("DisplayPromoDeadline") = DBNull.Value') -and
            $pop.Contains('If model.HasDefaultQuantityOffer Then') -and $pop.Contains('deadline = model.BestDefaultQuantityEndsOn') -and
            $pop -notmatch 'earliestDeadline')
}
function Test-RotationWiring([string]$v) {
    $bind = Get-Method $v 'BindHome'
    $rot = Get-Method $v 'RotateHomePool'
    $key = Get-Method $v 'HomeRotationSessionKey'
    $load = Get-Method $v 'Page_Load'
    $iDeal = $bind.IndexOf('dealPool = RotateHomePool("deals", dealPool, 6, usedBusinessKeys, usedDisplayKeys)')
    $iDealTake = $bind.IndexOf('Dim dealRows As DataTable = TakeDiverseRows(6')
    $iArr = $bind.IndexOf('newArrivalsPool = RotateHomePool("arrivals", newArrivalsPool, 8, usedBusinessKeys, usedDisplayKeys)')
    $iArrInc = $bind.IndexOf('incomingPool = RotateHomePool("arrivals", incomingPool, 8, usedBusinessKeys, usedDisplayKeys)')
    $iArrTake = $bind.IndexOf('Dim featuredRows As DataTable = TakeHomeArrivalsRows(8')
    $iBest = $bind.IndexOf('bestSellerPool = RotateHomePool("best", bestSellerPool, 8, usedBusinessKeys, usedDisplayKeys)')
    $iBestTake = $bind.IndexOf('Dim bestRows As DataTable = TakeRankedHomeRows(8')
    return ($iDeal -ge 0 -and $iDeal -lt $iDealTake -and $iArr -ge 0 -and $iArr -lt $iArrInc -and $iArrInc -lt $iArrTake -and $iBest -ge 0 -and $iBest -lt $iBestTake -and
            $bind.Contains('RememberHomeSelection("deals", dealRows)') -and $bind.Contains('RememberHomeSelection("arrivals", featuredRows)') -and $bind.Contains('RememberHomeSelection("best", bestRows)') -and
            $rot.Contains('CollectDistinctRows(Integer.MaxValue, usedBusinessKeys, usedDisplayKeys, False, False, True, pool)') -and
            $rot.Contains('StorefrontShowcaseRotation.Rotate(candidates, take, recent, _homeRandom)') -and
            $key.Contains('GetCurrentAziendaId()') -and $key.Contains('GetCurrentListino()') -and $key.Contains('_priceDisplayContext.IsAuthenticated') -and $key.Contains('_priceDisplayContext.IsVatIncluded') -and
            $v.Contains('Private ReadOnly _homeRandom As New Random(Guid.NewGuid().GetHashCode())') -and
            $bind -notmatch 'RotateHomePool\("recent' -and $v -notmatch 'RAND\(\)' -and
            $load.Contains('Response.Cache.SetCacheability(HttpCacheability.NoCache)'))
}
function Test-RotationStoresOnlyIds([string]$v) {
    $rem = Get-Method $v 'RememberHomeSelection'
    return ($rem.Contains('StorefrontShowcaseRotation.FormatIds(shown)') -and $rem -notmatch 'Prezzo|Price|Decimal')
}

Assert-Source (Test-DisplayRule $vb) 'S01_STRIKETHROUGH_BADGE_SAVING_AND_OFFER_QUALIFICATION_SHARE_ONE_ROUNDED_RULE'
Assert-Source (Test-PayablePriceUntouched $vb) 'S02_THE_PAYABLE_PRICE_IS_NEVER_CHANGED_BY_THE_PRESENTATION_RULE'
Assert-Source (Test-NetStockEverywhere $vb) 'S03_EVERY_POOL_REQUIRES_THE_NET_QUANTITY_THE_CARD_LABEL_READS'
Assert-Source (Test-BasePriceEverywhere $vb) 'S04_EVERY_POOL_REQUIRES_A_POSITIVE_BASE_PRICE_IN_THE_REQUEST_VAT_MODE'
Assert-Source (Test-SnapshotOnly $vb) 'S05_PROMOTIONS_COME_ONLY_FROM_THE_AUTHORITATIVE_SNAPSHOT_RESET_AND_WITH_THE_RIGHT_DEADLINE'
Assert-Source (Test-RotationWiring $vb) 'S06_ROTATION_RUNS_ON_SELECTABLE_CANDIDATES_BEFORE_EACH_SELECTION_AND_REMEMBERS_AFTER'
Assert-Source (Test-RotationStoresOnlyIds $vb) 'S07_ROTATION_MEMORY_HOLDS_ONLY_IDENTIFIERS'

$m = Mutate-Text $vb 'Return StorefrontPromotionDisplayPolicy.Resolve(GetBasePrice(row), CurrentPrice(row))' 'Return StorefrontPromotionDisplayPolicy.Resolve(CurrentPrice(row), GetBasePrice(row))' 'M01'
Assert-Detected (Test-DisplayRule $m) 'M01_RULE_ARGUMENTS_SWAPPED'
$m = Mutate-Text $vb 'Return PromotionDisplay(row).Savings' 'Return Math.Max(0D, GetBasePrice(row) - CurrentPrice(row))' 'M02'
Assert-Detected (Test-DisplayRule $m) 'M02_SAVING_FROM_UNROUNDED_VALUES_AGAIN'
$m = Mutate-Text $vb '            If ShowDiscount(row) Then
                filtered.ImportRow(row)' '            If ToDecimal(row("DisplayPromoQtyOnePrice")) > 0D OrElse ToDecimal(row("DisplayPromoTierPrice")) > 0D Then
                filtered.ImportRow(row)' 'M03'
Assert-Detected (Test-DisplayRule $m) 'M03_TIER_ONLY_OR_TRIVIAL_PROMO_QUALIFIES_FOR_THE_DEALS'
$m = Mutate-Text $vb 'Return promoPrice
        End If

        Return GetBasePrice(row)' 'Return StorefrontPromotionDisplayPolicy.RoundMoney(promoPrice)
        End If

        Return GetBasePrice(row)' 'M04'
Assert-Detected (Test-PayablePriceUntouched $m) 'M04_PAYABLE_PRICE_ROUNDED_BY_THE_PRESENTATION'
$m = Mutate-Text $vb 'If(StorefrontPromotionDisplayPolicy.RoundMoney(current) > 0D, FormatMoney(current), "Prezzo su richiesta")' 'If(current > 0D, FormatMoney(current), "Prezzo su richiesta")' 'M05'
Assert-Detected (Test-PayablePriceUntouched $m) 'M05_PRICE_THAT_PRINTS_0_00_IS_SHOWN'
$m = Mutate-Text $vb '            sql.Append("AND ").Append(NetStockSql()).Append(">=1 ")' '            sql.Append("AND ").Append(StockWhereClause()).Append(">=1 ")' 'M06'
Assert-Detected (Test-NetStockEverywhere $m) 'M06_GROSS_STOCK_IN_THE_GENERIC_POOL'
$m = Mutate-Text $vb 'NetStockSql() & ">=1"
    End Function' 'StockWhereClause() & ">=1"
    End Function' 'M07'
Assert-Detected (Test-NetStockEverywhere $m) 'M07_GROSS_STOCK_IN_THE_DEALS'
$m = Mutate-Text $vb 'Return QueryProducts(NetStockSql() & ">=1 AND COALESCE(v.InOrdine,0)<=0' 'Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(v.InOrdine,0)<=0' 'M08'
Assert-Detected (Test-NetStockEverywhere $m) 'M08_GROSS_STOCK_IN_THE_NEW_ARRIVALS'
$m = Mutate-Text $vb 'sql.Append("AND ").Append(If(_priceDisplayContext.IsVatIncluded, prezzoIvatoSql, "COALESCE(v.Prezzo,0)")).Append(">0 ")' 'sql.Append("AND (COALESCE(v.Prezzo,0)>0 OR COALESCE(v.PrezzoIvato,0)>0 OR COALESCE(v.PrezzoPromo,0)>0 OR COALESCE(v.PrezzoPromoIvato,0)>0) ")' 'M09'
Assert-Detected (Test-BasePriceEverywhere $m) 'M09_PROMO_PRICE_OR_OTHER_VAT_MODE_QUALIFIES_AGAIN'
$m = Mutate-Text $vb 'If HasPromotionDisplayTechnicalError(row) OrElse Not HasPromotionDisplaySnapshot(row) Then Return False
        promoPrice = ToDecimal(row("DisplayPromoQtyOnePrice"))' 'If HasPromotionDisplayTechnicalError(row) Then Return False
        promoPrice = ToDecimal(row("DisplayPromoQtyOnePrice"))' 'M10'
Assert-Detected (Test-SnapshotOnly $m) 'M10_PROMOTION_WITHOUT_AN_AUTHORITATIVE_SNAPSHOT'
$m = Mutate-Text $vb '            row("DisplayPromoQtyOnePrice") = DBNull.Value
' '' 'M11'
Assert-Detected (Test-SnapshotOnly $m) 'M11_STALE_PROMOTION_VALUES_SURVIVE_A_SECOND_PASS'
$m = Mutate-Text $vb 'deadline = model.BestDefaultQuantityEndsOn' 'deadline = model.BestQuantityTierEndsOn' 'M12'
Assert-Detected (Test-SnapshotOnly $m) 'M12_DEADLINE_OF_ANOTHER_OFFER'
$m = Mutate-Text $vb 'dealPool = RotateHomePool("deals", dealPool, 6, usedBusinessKeys, usedDisplayKeys)
' '' 'M13'
Assert-Detected (Test-RotationWiring $m) 'M13_DEALS_NOT_ROTATED'
$m = Mutate-Text $vb 'bestSellerPool = RotateHomePool("best", bestSellerPool, 8, usedBusinessKeys, usedDisplayKeys)
        Dim bestRows' '        Dim bestRows' 'M14'
Assert-Detected (Test-RotationWiring $m) 'M14_BEST_SELLERS_NOT_ROTATED'
$m = Mutate-Text $vb 'CollectDistinctRows(Integer.MaxValue, usedBusinessKeys, usedDisplayKeys, False, False, True, pool)' 'pool' 'M15'
Assert-Detected (Test-RotationWiring $m) 'M15_WINDOW_BUILT_ON_RAW_ROWS_INSTEAD_OF_SELECTABLE_CANDIDATES'
$m = Mutate-Text $vb 'GetCurrentListino().ToString(CultureInfo.InvariantCulture) & "." &' '"" &' 'M16'
Assert-Detected (Test-RotationWiring $m) 'M16_HISTORY_NOT_SEPARATED_BY_PRICE_LIST'
$m = Mutate-Text $vb 'RememberHomeSelection("arrivals", featuredRows)' '' 'M17'
Assert-Detected (Test-RotationWiring $m) 'M17_NOTHING_REMEMBERED_SO_NO_CHANGE_IS_GUARANTEED'
$m = Mutate-Text $vb 'Response.Cache.SetCacheability(HttpCacheability.NoCache)' '' 'M18'
Assert-Detected (Test-RotationWiring $m) 'M18_RESPONSE_CAN_BE_REUSED_WITHOUT_REVALIDATION'
$m = Mutate-Text $vb 'Private ReadOnly _homeRandom As New Random(Guid.NewGuid().GetHashCode())' 'Private ReadOnly _homeRandom As New Random(12345)' 'M19'
Assert-Detected (Test-RotationWiring $m) 'M19_FIXED_SEED_SAME_SELECTION_EVERY_TIME'
$m = Mutate-Text $vb 'StorefrontShowcaseRotation.FormatIds(shown)' 'StorefrontShowcaseRotation.FormatIds(shown) & ":" & Convert.ToString(shown.Rows(0)("Prezzo"))' 'M20'
Assert-Detected (Test-RotationStoresOnlyIds $m) 'M20_PRICES_STORED_IN_THE_SESSION_HISTORY'
Write-Output 'HOME_PRICE_DISPLAY_OK'
