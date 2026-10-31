[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef='fc71f14b01b84dd52327bd578f2cd9479748889d',
    [switch]$ReproduceBaselineOnly
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'FRAMEWORK_PS51_REQUIRED'}
if([string]::IsNullOrWhiteSpace($RepositoryRoot)){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$root=[IO.Path]::GetFullPath($RepositoryRoot)
$output=[IO.Path]::GetFullPath($EvidenceDirectory)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if(-not $output.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or $output.TrimEnd('\') -eq $temp.TrimEnd('\')){throw 'SCOPED_TEMP_REQUIRED'}
[void][IO.Directory]::CreateDirectory($output)
function Method([string]$source,[string]$name){
    $match=[regex]::Match($source,'(?ms)^    (?:Public|Private|Friend) (?:Function|Sub) '+[regex]::Escape($name)+'\(.*?^    End (?:Function|Sub)\s*\r?$')
    if(-not $match.Success){throw ('METHOD_MISSING '+$name)}
    return $match.Value
}
function Between([string]$source,[string]$start,[string]$end){
    $a=$source.IndexOf($start,[StringComparison]::Ordinal);if($a -lt 0){throw 'START_MISSING'}
    $b=$source.IndexOf($end,$a,[StringComparison]::Ordinal);if($b -le $a){throw 'END_MISSING'}
    return $source.Substring($a,$b-$a)
}
$price=[IO.File]::ReadAllText((Join-Path $root 'App_Code\CartPriceRevalidationHelper.vb'))
$mutation=[IO.File]::ReadAllText((Join-Path $root 'App_Code\CartMutationService.vb'))
$baseline=(& git -C $root show ($BaselineRef+':App_Code/CartPriceRevalidationHelper.vb')) -join "`n"
if($LASTEXITCODE){throw 'BASELINE_UNAVAILABLE'}
$imports="Imports System`nImports System.Collections.Generic`nImports System.Configuration`nImports System.Data`nImports System.Globalization`nImports System.IO`nImports System.Web`nImports System.Web.SessionState`nImports MySql.Data.MySqlClient`n"
$types=[regex]::Replace(($price.Substring(0,$price.IndexOf('Public Module CartPriceRevalidationHelper'))),'(?m)^Imports[^\r\n]*\r?\n','')
$types += [regex]::Replace(($mutation.Substring(0,$mutation.IndexOf('Public Module CartMutationService'))),'(?m)^Imports[^\r\n]*\r?\n','')
$single=Method $mutation 'MutateStandardProduct'
$singlePlan=Between $single '            Dim eligibilityContext As ProductPromotionEligibilityContext =' '            Dim stockChanges As New List(Of CartInventoryQuantityChange)'
$batchStart=$mutation.IndexOf('Dim effectiveByKey As New Dictionary', [StringComparison]::Ordinal)
$batchEnd=$mutation.IndexOf('            Dim stockChanges As New List(Of CartInventoryQuantityChange)', $batchStart, [StringComparison]::Ordinal)
if($batchStart -lt 0 -or $batchEnd -lt 0){throw 'BATCH_PLANNER_MISSING'}
$batchPlan=$mutation.Substring($batchStart,$batchEnd-$batchStart)
if($mutation.IndexOf('For planIndex As Integer = 0 To plans.Count - 1',$batchEnd,[StringComparison]::Ordinal) -lt $batchEnd){throw 'BATCH_WRITE_BOUNDARY_CHANGED'}
$mutationHelpers=(@('ResolvedFailureKind','FailedBatch','FailedProduct','NormalizeTCId','BatchKey','CompareBatchRequests','IsValidQuantity')|ForEach-Object {Method $mutation $_}) -join "`n"
$revalidate=Method $price 'RevalidateCurrentCart'
# The first overload owns the transaction. Extract the existing transactional overload instead.
$revalidate=[regex]::Match($price,'(?ms)^    Public Function RevalidateCurrentCart\(ByVal ctx As HttpContext,\r?\n.*?^    End Function\s*\r?$').Value
if(-not $revalidate){throw 'TRANSACTIONAL_REVALIDATION_MISSING'}
$helpers=(@('ResolvePriceIvato','RoundCurrency','ReverseChargeEnabled','PriceChanged','SessionInt','SessionDecimal','ReadDecimal','TechnicalFailureResult','CommercialRuleFailureResult')|ForEach-Object {Method $price $_}) -join "`n"
$seams=@'
Namespace MySql.Data.MySqlClient
 Public Class MySqlConnection
  Public ReadOnly Property State As ConnectionState
   Get
    Return ConnectionState.Open
   End Get
  End Property
 End Class
 Public Class MySqlTransaction
 End Class
End Namespace
Public Enum ProductPromotionEligibilityLoadStatus
 Success=0
 InvalidRequest=1
 TechnicalError=2
 AmbiguousCommercialRule=3
End Enum
Public Class ProductPromotionEligibilityContext
 Public CompanyId As Integer=1
 Public Listino As Integer
 Public EvaluationDate As DateTime=DateTime.UtcNow
End Class
Public Class ProductPromotionEligibilityOffer
 Public OfferDetailId As Integer=123
End Class
Public Class ProductPromotionEligibilityResult
 Public HasTechnicalError As Boolean
 Public Status As ProductPromotionEligibilityLoadStatus
 Public HasAppliedOffer As Boolean
 Public EffectivePriceNet As Decimal
 Public EffectivePriceGross As Decimal
 Public AppliedOffer As New ProductPromotionEligibilityOffer
End Class
Public Module ProductPromotionEligibilityResolver
 Public Function CreateContext(ctx As HttpContext,listino As Integer) As ProductPromotionEligibilityContext
  Return New ProductPromotionEligibilityContext With {.Listino=listino}
 End Function
 Public Function Resolve(conn As MySqlConnection,tr As MySqlTransaction,e As ProductPromotionEligibilityContext,id As Integer,tc As Integer,q As Decimal,net As Decimal,gross As Decimal,Optional propagate As Boolean=False) As ProductPromotionEligibilityResult
  Fixture.PromoCalls+=1
  Return New ProductPromotionEligibilityResult With {.HasTechnicalError=Fixture.Technical,.Status=If(Fixture.Ambiguous,ProductPromotionEligibilityLoadStatus.AmbiguousCommercialRule,ProductPromotionEligibilityLoadStatus.Success),.HasAppliedOffer=Fixture.Promo,.EffectivePriceNet=net/2D,.EffectivePriceGross=gross/2D}
 End Function
 Public Function Resolve(connectionString As String,e As ProductPromotionEligibilityContext,id As Integer,tc As Integer,q As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
  Throw New Exception("NONTRANSACTIONAL_IO_FORBIDDEN")
 End Function
End Module
Public Enum ProductFreeShippingEligibilityStatus
 Success=0
End Enum
Public Class ProductFreeShippingEligibilityResult
 Public Status As ProductFreeShippingEligibilityStatus
 Public Eligible As Boolean
End Class
Public Module ProductFreeShippingEligibilityResolver
 Public Function Resolve(conn As MySqlConnection,tr As MySqlTransaction,id As Integer,company As Integer,listino As Integer,at As DateTime,locked As Boolean,propagate As Boolean) As ProductFreeShippingEligibilityResult
  Return New ProductFreeShippingEligibilityResult With {.Eligible=True}
 End Function
End Module
Public Module CartTransactionRetryPolicy
 Public Function GetMySqlErrorNumber(ex As Exception) As Integer
  Return -1
 End Function
End Module
Public Class CartTransactionWorkResult(Of T)
 Public Value As T
 Public IsAbort As Boolean
 Public Shared Function Abort(value As T) As CartTransactionWorkResult(Of T)
  Return New CartTransactionWorkResult(Of T) With {.Value=value,.IsAbort=True}
 End Function
 Public Shared Function Commit(value As T) As CartTransactionWorkResult(Of T)
  Return New CartTransactionWorkResult(Of T) With {.Value=value}
 End Function
End Class
Public Module CartMutationIdempotencyService
 Public Const MaxStandardBatchItems As Integer=16
End Module
Public Module OrderInventoryAvailabilityService
 Public Const InsufficientStockMessage As String="Synthetic stock rejection"
End Module
Public Module Fixture
 Friend Candidates As New Dictionary(Of String,List(Of CartPriceCandidate))
 Friend Rows As New List(Of CartPriceRevalidationRow)
 Friend Existing As New List(Of CartMutationExistingRow)
 Public Writes As Integer
 Public MutationWriteBoundary As Integer
 Public LastRowTC As Integer
 Public LastPriceTC As Integer
 Public Promo As Boolean
 Public Technical As Boolean
 Public Ambiguous As Boolean
 Public PromoCalls As Integer
 Public Sub Reset()
  Candidates.Clear():Rows.Clear():Existing.Clear():Writes=0:MutationWriteBoundary=0:PromoCalls=0:Promo=False:Technical=False:Ambiguous=False
 End Sub
 Public Sub Candidate(listino As Integer,id As Integer,tc As Integer,Optional price As Decimal=10D)
  Dim key As String=listino.ToString() & ":" & id.ToString()
  If Not Candidates.ContainsKey(key) Then Candidates(key)=New List(Of CartPriceCandidate)
  Candidates(key).Add(New CartPriceCandidate With {.ArticleId=id,.TCId=tc,.Price=price,.PriceIvato=price*1.22D,.Code="SYNTHETIC",.Description="Synthetic product",.ReverseChargeVatId=701,.ReverseChargeVatValue=0D})
 End Sub
 Public Function Context() As HttpContext
  Dim c As New HttpContext(New HttpRequest("","https://fixture.invalid/", ""),New HttpResponse(New StringWriter()))
  SessionStateUtility.AddHttpSessionStateToContext(c,New HttpSessionStateContainer("SYNTHETIC",New SessionStateItemCollection(),New HttpStaticObjectsCollection(),20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
  Return c
 End Function
End Module
'@
$io=@'
 Private Function LoadCandidates(conn As MySqlConnection,tr As MySqlTransaction,id As Integer,listino As Integer,locked As Boolean) As List(Of CartPriceCandidate)
  Dim key As String=listino.ToString() & ":" & id.ToString()
  If Fixture.Candidates.ContainsKey(key) Then Return Fixture.Candidates(key)
  Return New List(Of CartPriceCandidate)
 End Function
 Private Function LoadCartRows(conn As MySqlConnection,tr As MySqlTransaction,login As Integer,session As String,locked As Boolean) As List(Of CartPriceRevalidationRow)
  Return Fixture.Rows
 End Function
 Private Function UpdateCartRow(conn As MySqlConnection,tr As MySqlTransaction,login As Integer,session As String,row As CartPriceRevalidationRow,resolved As CartResolvedPrice,ctx As HttpContext) As Boolean
  Fixture.Writes+=1:Fixture.LastRowTC=row.TCId:Fixture.LastPriceTC=resolved.EffectiveTCId
  Return True
 End Function
 Private Sub LogFailure(ctx As HttpContext,message As String,ex As Exception)
 End Sub
'@
$planner=@"
Public Module MutationPlanningHarness
 Private Const GenericMutationError As String="Synthetic error"
$mutationHelpers
 Public Function SinglePlan(ctx As HttpContext,id As Integer,tc As Integer,quantity As Decimal,listino As Integer,setAbsoluteQuantity As Boolean) As CartTransactionWorkResult(Of CartStandardMutationResult)
  Dim conn As New MySqlConnection, transaction As New MySqlTransaction
  Dim articleId As Integer=id, requestedTCId As Integer=tc, quantityValue As Decimal=quantity, attemptListino As Integer=listino
  Dim ownedArticleRows As List(Of CartMutationExistingRow)=Fixture.Existing
$singlePlan
  Fixture.MutationWriteBoundary+=1
  Return CartTransactionWorkResult(Of CartStandardMutationResult).Commit(New CartStandardMutationResult With {.Succeeded=True,.FailureKind=CartMutationFailureKind.None,.TCId=resolved.EffectiveTCId,.Price=resolved.Price,.PriceIvato=resolved.PriceIvato})
 End Function
 Public Function BatchPlan(ctx As HttpContext,normalizedItems As IList(Of CartStandardBatchMutationRequest),attemptListino As Integer) As CartTransactionWorkResult(Of CartStandardBatchMutationResult)
  Dim conn As New MySqlConnection, transaction As New MySqlTransaction
  Dim ownerRows As List(Of CartMutationExistingRow)=Fixture.Existing
  Dim eligibilityContext As ProductPromotionEligibilityContext=ProductPromotionEligibilityResolver.CreateContext(ctx,attemptListino)
$batchPlan
  Fixture.MutationWriteBoundary+=plans.Count
  Return CartTransactionWorkResult(Of CartStandardBatchMutationResult).Commit(New CartStandardBatchMutationResult With {.Succeeded=True,.FailureKind=CartMutationFailureKind.None})
 End Function
End Module
"@
$tests=@'
Public Module Tests
 Private count As Integer
 Private Sub Check(name As String,pass As Boolean)
  If Not pass Then Throw New Exception("FAILED " & name)
  count+=1:Console.WriteLine("PASS " & name)
 End Sub
 Private Function Price(ctx As HttpContext,listino As Integer,tc As Integer) As CartResolvedPrice
  Return CartPriceRevalidationHelper.ResolveStandardPrice(ctx,New MySqlConnection,New MySqlTransaction,ProductPromotionEligibilityResolver.CreateContext(ctx,listino),1,tc,1D,listino,True)
 End Function
 Private Function Revalidate(ctx As HttpContext,listino As Integer) As CartPriceRevalidationResult
  Return CartPriceRevalidationHelper.RevalidateCurrentCart(ctx,New MySqlConnection,New MySqlTransaction,1,"",listino,True,True,Nothing)
 End Function
 Public Sub Main(args As String())
  Dim legacy As Boolean=args.Length>0 AndAlso args(0)="legacy"
  For Each listino As Integer In New Integer(){1,10}
   Dim ctx As HttpContext=Fixture.Context()
   Dim amount As Decimal=If(listino=1,10D,20D)
   Fixture.Reset():Fixture.Candidate(listino,1,-1,amount)
   Dim missing As CartResolvedPrice=Price(ctx,listino,42)
   Check("missing positive exact variant list" & listino,If(legacy,missing.IsValid AndAlso missing.EffectiveTCId=-1,Not missing.IsValid AndAlso Not missing.HasTechnicalError))
   Fixture.Rows.Add(New CartPriceRevalidationRow With {.CartRowId=1,.ArticleId=1,.TCId=42,.Quantity=1D,.CurrentPrice=99D})
   Dim validation As CartPriceRevalidationResult=Revalidate(ctx,listino)
   Check("cart revalidation mismatch list" & listino,If(legacy,Not validation.HasBlockingError AndAlso Fixture.Writes=1 AndAlso Fixture.LastRowTC=42 AndAlso Fixture.LastPriceTC=-1,validation.HasBlockingError AndAlso Not validation.HasTechnicalError AndAlso Fixture.Writes=0))
   For Each absolute As Boolean In New Boolean(){False,True}
    Fixture.MutationWriteBoundary=0
    Dim p As CartTransactionWorkResult(Of CartStandardMutationResult)=MutationPlanningHarness.SinglePlan(ctx,1,42,2D,listino,absolute)
    Check("add/set missing variant " & absolute & " list" & listino,If(legacy,p.Value.Succeeded AndAlso p.Value.TCId=-1,p.IsAbort AndAlso p.Value.FailureKind=CartMutationFailureKind.Commercial AndAlso Fixture.MutationWriteBoundary=0))
   Next
   Fixture.Candidate(listino,2,7,amount*2D)
   For Each invalidFirst As Boolean In New Boolean(){False,True}
    Dim items As New List(Of CartStandardBatchMutationRequest) From {New CartStandardBatchMutationRequest With {.ArticleId=2,.RequestedTCId=7,.QuantityDelta=1D},New CartStandardBatchMutationRequest With {.ArticleId=1,.RequestedTCId=42,.QuantityDelta=1D}}
    If invalidFirst Then items.Reverse()
    Fixture.MutationWriteBoundary=0
    Dim b As CartTransactionWorkResult(Of CartStandardBatchMutationResult)=MutationPlanningHarness.BatchPlan(ctx,items,listino)
    Check("batch rejects before writes " & invalidFirst & " list" & listino,If(legacy,b.Value.Succeeded AndAlso Fixture.MutationWriteBoundary=2,b.IsAbort AndAlso b.Value.FailureKind=CartMutationFailureKind.Commercial AndAlso Fixture.MutationWriteBoundary=0))
   Next
   If legacy Then Continue For
   Fixture.Reset():Fixture.Candidate(listino,1,-1,amount):Fixture.Candidate(If(listino=1,10,1),1,42,77D)
   Check("variant only in other list rejected " & listino,Not Price(ctx,listino,42).IsValid)
   Check("invalid rejected before promotion " & listino,Fixture.PromoCalls=0)
   Fixture.Candidate(listino,1,42,amount*3D)
   Dim exact As CartResolvedPrice=Price(ctx,listino,42)
   Check("exact variant identity and price " & listino,exact.IsValid AndAlso exact.EffectiveTCId=42 AndAlso exact.Price=amount*3D AndAlso exact.PriceIvato=amount*3D*1.22D)
   For Each standard As Integer In New Integer(){-1,0}
    Dim normal As CartResolvedPrice=Price(ctx,listino,standard)
    Check("legacy standard alias " & standard & " list" & listino,normal.IsValid AndAlso normal.EffectiveTCId=-1 AndAlso normal.Price=amount)
   Next
   Fixture.Promo=True
   Dim offer As CartResolvedPrice=Price(ctx,listino,42)
   Check("valid promo pair retained " & listino,offer.Price=amount*3D/2D AndAlso offer.PriceIvato=amount*3D*1.22D/2D AndAlso offer.OfferDetailId=123)
   Fixture.Promo=False:ctx.Session("Iva_Utente")=10D
   Check("VAT override pair retained " & listino,Price(ctx,listino,42).PriceIvato=amount*3D*1.1D)
   ctx.Session("AbilitatoIvaReverseCharge")=1
   Dim rc As CartResolvedPrice=Price(ctx,listino,42)
   Check("RC precedence and ID retained " & listino,rc.PriceIvato=amount*3D AndAlso rc.ReverseChargeVatId=701 AndAlso rc.ReverseChargeVatValue=0D)
   ctx.Session.Remove("Iva_Utente"):ctx.Session.Remove("AbilitatoIvaReverseCharge")
   Fixture.Rows.Add(New CartPriceRevalidationRow With {.CartRowId=1,.ArticleId=1,.TCId=42,.Quantity=2D})
   Check("valid revalidation preserves identity " & listino,Not Revalidate(ctx,listino).HasBlockingError AndAlso Fixture.Writes=1 AndAlso Fixture.LastRowTC=Fixture.LastPriceTC)
   Fixture.Rows.Add(New CartPriceRevalidationRow With {.CartRowId=2,.ArticleId=1,.TCId=99,.Quantity=1D}):Fixture.Writes=0
   Check("all revalidation plans precede updates " & listino,Revalidate(ctx,listino).HasBlockingError AndAlso Fixture.Writes=0)
   For Each absolute As Boolean In New Boolean(){False,True}
    Dim good As CartTransactionWorkResult(Of CartStandardMutationResult)=MutationPlanningHarness.SinglePlan(ctx,1,42,2D,listino,absolute)
    Check("valid add/set identity " & absolute & " list" & listino,good.Value.Succeeded AndAlso good.Value.TCId=42 AndAlso good.Value.Price=amount*3D)
   Next
   Fixture.MutationWriteBoundary=0
   Dim validItems As New List(Of CartStandardBatchMutationRequest) From {New CartStandardBatchMutationRequest With {.ArticleId=1,.RequestedTCId=42,.QuantityDelta=1D},New CartStandardBatchMutationRequest With {.ArticleId=1,.RequestedTCId=-1,.QuantityDelta=1D}}
   Check("valid batch retains both identities " & listino,MutationPlanningHarness.BatchPlan(ctx,validItems,listino).Value.Succeeded AndAlso Fixture.MutationWriteBoundary=2)
   Fixture.Technical=True
   Check("technical classification unchanged " & listino,MutationPlanningHarness.SinglePlan(ctx,1,42,1D,listino,False).Value.FailureKind=CartMutationFailureKind.Technical)
   Fixture.Technical=False:Fixture.Ambiguous=True
   Check("ambiguous commercial classification " & listino,MutationPlanningHarness.SinglePlan(ctx,1,42,1D,listino,False).Value.FailureKind=CartMutationFailureKind.Commercial)
   Fixture.Reset():Fixture.Candidate(listino,1,9,amount)
   Check("another positive variant never substitutes " & listino,Not Price(ctx,listino,42).IsValid)
   Fixture.Reset()
   Check("empty assortment rejected " & listino,Not Price(ctx,listino,42).IsValid)
   Fixture.Candidate(listino,1,0,amount)
   Check("stored zero standard alias remains compatible " & listino,Price(ctx,listino,-1).IsValid AndAlso Price(ctx,listino,0).EffectiveTCId=-1)
  Next
  Console.WriteLine("VARIANT_ASSERTIONS=" & count & ";MODE=" & If(legacy,"LEGACY_DEFECT_REPRODUCED","CANDIDATE_PASS"))
 End Sub
End Module
'@
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$outcomes=@()
foreach($mode in @('legacy','candidate')){
    if($ReproduceBaselineOnly -and $mode -eq 'candidate'){continue}
    $inputSource=if($mode -eq 'legacy'){$baseline}else{$price}
    $resolver=Method $inputSource 'ResolveStandardPrice'
    $constants="Public Const GenericTechnicalErrorMessage As String=""Synthetic technical""`nPublic Const GenericCommercialRuleErrorMessage As String=""Synthetic ambiguous""`nPrivate ReadOnly PriceCulture As CultureInfo=CultureInfo.GetCultureInfo(""it-IT"")"
    $vb=$imports+$types+$seams+"`nPublic Module CartPriceRevalidationHelper`n"+$constants+"`n"+$resolver+"`n"+$helpers+"`n"+$revalidate+"`n"+$io+"`nEnd Module`n"+$planner+"`n"+$tests
    $path=Join-Path $output ($mode+'.vb');$exe=Join-Path $output ($mode+'.exe')
    [IO.File]::WriteAllText($path,$vb,(New-Object Text.UTF8Encoding($false)))
    $compile=@(& $compiler /nologo /optionexplicit+ /target:exe /main:Tests "/out:$exe" /reference:System.dll,System.Core.dll,System.Data.dll,System.Web.dll,System.Configuration.dll $path)
    $compile|Set-Content -LiteralPath (Join-Path $output ($mode+'-compile.log'))
    if($LASTEXITCODE){throw ('COMPILE_FAILED '+$mode+' '+($compile -join "`n"))}
    $run=@(& $exe $mode);$code=$LASTEXITCODE;$run|Set-Content -LiteralPath (Join-Path $output ($mode+'-tests.log'))
    if($code){throw ('HARNESS_FAILED '+$mode+' '+($run -join "`n"))}
    $summary=@($run|Where-Object {$_ -like 'VARIANT_ASSERTIONS=*'})[0]
    $outcomes += [pscustomobject]@{mode=$mode;summary=$summary;status='PASS'}
    Write-Output $summary
}
if(-not $ReproduceBaselineOnly){
    $line='        If candidates.Count = 0 Then candidates = allCandidates.FindAll(Function(x) x.TCId <= 0)'
    if($price.Replace("`r`n","`n").TrimEnd([char[]]"`n") -cne ($baseline.Replace("`r`n","`n").Replace($line+"`n",'').TrimEnd([char[]]"`n"))){throw 'RUNTIME_DELTA_EXCEEDS_ONE_FALLBACK_LINE'}
}
[pscustomobject]@{result='PASS';baseline=$BaselineRef;runs=$outcomes;sourceHashes=@(@('App_Code/CartPriceRevalidationHelper.vb','App_Code/CartMutationService.vb','Tools/Test-CommercialVariantIdentityIntegrity.ps1')|ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash}});realSource='Resolver,fiscal helpers,transactional revalidation and mutation planning fragments';simulated='Candidate/cart I/O,promotion/free-shipping I/O,transaction types; mutation write boundary counter only';limits='No DB,IIS,real commit/rollback,stock or complete mutation engine execution';externalRequests=0;databaseConnections=0}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $output 'report.json') -Encoding UTF8
