[CmdletBinding()]
param(
 [string]$RepositoryRoot,
 [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
 [string]$NodePath,
 [string]$BaselineRef='6baf414919690550c5ed7b4521a7ce11aba9383c'
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'QTY1_VARIANT_REQUIRES_POWERSHELL51'}
if(-not $RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if(-not $EvidenceDirectory.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'QTY1_VARIANT_REQUIRES_NEW_TEMP_EVIDENCE'}
if($BaselineRef -cnotmatch '^[a-f0-9]{40}$'){throw 'QTY1_VARIANT_REQUIRES_EXACT_BASE_SHA'}
if(-not $NodePath){$NodePath=(Get-Command node -CommandType Application -ErrorAction Stop).Source}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
function Method([string]$source,[string]$name){
 $m=[regex]::Match($source,'(?ms)^    (?:Private|Protected|Public|Friend) (?:Shared )?Function '+[regex]::Escape($name)+'\b.*?^    End Function')
 if(-not $m.Success){throw ('QTY1_VARIANT_SOURCE_METHOD_MISSING_'+$name)}
 return $m.Value
}

$fixture=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient
Public Class CatalogQty1Fixture
 Public _priceDisplayContext As StorefrontPriceDisplayContext
 Public Batch As IProductPromotionEligibilityBatch
 Private Function EnsureCatalogPriceDisplayContext() As Boolean
  Return _priceDisplayContext IsNot Nothing
 End Function
 Private Function CatalogPromotionModel(item As Object, Optional restricted As Boolean=True) As ProductPromotionDisplayModel
  Return ProductPromotionDisplayHelper.BuildForProduct(Batch,UiData.Int(item,"id"),UiData.Int(item,"TCid"),CDec(item("Prezzo")),CDec(item("PrezzoIvato")),_priceDisplayContext.IsVatExcluded)
 End Function
 Public Function Price(item As DataRow) As String
  Return CatalogPriceTextFor(item,True)
 End Function
@@CARD@@
End Class
Public Class PdpQty1Fixture
 Public _priceDisplayContext As StorefrontPriceDisplayContext
 Public Batch As IProductPromotionEligibilityBatch
@@PRICECLASS@@
 Private Function GetAuthorizedPromotionModel(id As Integer,tc As Integer,net As Nullable(Of Decimal),gross As Nullable(Of Decimal)) As ProductPromotionDisplayModel
  Return ProductPromotionDisplayHelper.BuildForProduct(Batch,id,tc,net.GetValueOrDefault(),gross.GetValueOrDefault(),_priceDisplayContext.IsVatExcluded)
 End Function
 Public Function Price(id As Integer,tc As Integer,net As Nullable(Of Decimal),gross As Nullable(Of Decimal)) As Nullable(Of Decimal)
  Return BuildAuthorizedPriceContext(id,tc,net,gross).CurrentPrice
 End Function
@@PDP@@
End Class
Public Class CartQty1Fixture
 Friend Shared Batch As ProductPromotionEligibilityBatch
 Friend Shared CandidateRows As List(Of CartPriceCandidate)
 Private ReadOnly PriceCulture As CultureInfo=CultureInfo.GetCultureInfo("it-IT")
 Private Function LoadCandidates(conn As MySqlConnection,transaction As MySqlTransaction,id As Integer,list As Integer,locked As Boolean) As List(Of CartPriceCandidate)
  Return CandidateRows.FindAll(Function(x) x.ArticleId=id)
 End Function
 Private Class ProductPromotionEligibilityResolver
  Public Shared Function Resolve(cs As String,scope As ProductPromotionEligibilityContext,id As Integer,tc As Integer,qty As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
   Return Global.ProductPromotionEligibilityResolver.Resolve(Batch,id,tc,qty,net,gross)
  End Function
  Public Shared Function Resolve(conn As MySqlConnection,tr As MySqlTransaction,scope As ProductPromotionEligibilityContext,id As Integer,tc As Integer,qty As Decimal,net As Decimal,gross As Decimal,propagate As Boolean) As ProductPromotionEligibilityResult
   Return Global.ProductPromotionEligibilityResolver.Resolve(Batch,id,tc,qty,net,gross)
  End Function
 End Class
 Private Class ProductFreeShippingEligibilityResolver
  Public Shared Function Resolve(conn As MySqlConnection,tr As MySqlTransaction,id As Integer,company As Integer,list As Integer,day As Date,locked As Boolean,propagate As Boolean) As ProductFreeShippingEligibilityResult
   Return New ProductFreeShippingEligibilityResult With {.Status=ProductFreeShippingEligibilityStatus.Success,.Eligible=False}
  End Function
 End Class
@@CART@@
@@CARTGROSS@@
@@REVERSE@@
@@SESSIONINT@@
@@SESSIONDECIMAL@@
@@READDECIMAL@@
@@ROUND@@
End Class
Public Class CatalogQty1FailureFixture
 Private catalogQuantityOnePriceFailed As Boolean
 Private count As Integer=99
 Private message As String=""
 Private lvProdotti As New Panel,ksMultiFooter As New Panel,DataList1 As New Panel,DataList2 As New Panel,DataList3 As New Panel,DataList4 As New Panel,filtritagliaecolore As New Panel
 Private Sub SetCatalogCountText(value As Integer)
  count=value
 End Sub
 Private Sub ShowPromotionCatalogMessage(value As String)
  message=value
 End Sub
 Public Function FailClosed() As Boolean
  FailCatalogQuantityOnePrices()
  Return catalogQuantityOnePriceFailed AndAlso count=0 AndAlso Not lvProdotti.Visible AndAlso Not ksMultiFooter.Visible AndAlso Not DataList1.Visible AndAlso Not DataList2.Visible AndAlso Not DataList3.Visible AndAlso Not DataList4.Visible AndAlso Not filtritagliaecolore.Visible AndAlso message.Contains("prezzi")
 End Function
@@FAIL@@
End Class
Public Class CatalogQty1ListingFixture
 Public Shared Function QuerySql(expr As String,priceJoin As String,range As Boolean,descending As Boolean) As String
  Dim selectSql="SELECT "+expr+" AS CatalogDisplayPrice,vsuperarticoli.id AS id,vsuperarticoli.TCid AS tc,vsuperarticoli.Prezzo,vsuperarticoli.PrezzoIvato,vsuperarticoli.Giacenza,vsuperarticoli.Impegnata,"+BuildCatalogRowRankSql()+" FROM vsuperarticoli LEFT JOIN (SELECT ArticoliId,MIN(id) AS DefaultTCid FROM articoli_tagliecolori GROUP BY ArticoliId) atc_default ON atc_default.ArticoliId=vsuperarticoli.id "+priceJoin
  Dim predicate=" AND (vsuperarticoli.id=2 OR vsuperarticoli.TCid=@selectedTc)"
  If range Then predicate+=" AND ("+expr+")>0 AND ("+expr+") BETWEEN @pmin AND @pmax"
  Dim sort=" ORDER BY CASE WHEN CatalogDisplayPrice>0 THEN 0 ELSE 1 END ASC,CatalogDisplayPrice "+If(descending,"DESC","ASC")+",(Giacenza-Impegnata) DESC,id ASC"
  Return BuildCatalogListingSql(selectSql,predicate,sort)
 End Function
@@RANK@@
@@LIST@@
End Class

'@
$main=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Reflection
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.SessionState
Public Module PromotionVariantQty1Harness
 Private ReadOnly json As New JavaScriptSerializer With {.MaxJsonLength=Integer.MaxValue}
 Private ReadOnly checks As New List(Of Object),reproductions As New List(Of Object)
 Private Function Obj(value As Object) As Dictionary(Of String,Object)
  Return DirectCast(value,Dictionary(Of String,Object))
 End Function
 Private Function Items(value As Object) As Object()
  Return DirectCast(value,Object())
 End Function
 Private Function Money(value As Object) As Decimal
  Return If(value Is Nothing OrElse Convert.IsDBNull(value),0D,Convert.ToDecimal(value,CultureInfo.InvariantCulture))
 End Function
 Private Function Rounded(value As Object) As Decimal
  Return Math.Round(Money(value),2,MidpointRounding.AwayFromZero)
 End Function
 Private Sub Assert(condition As Boolean,name As String)
  checks.Add(New With {.name=name,.pass=condition})
  If Not condition Then Throw New Exception(name)
 End Sub
 Public Sub Main(args As String())
  Try
   AppDomain.CurrentDomain.SetData(".appPath",AppDomain.CurrentDomain.BaseDirectory)
   AppDomain.CurrentDomain.SetData(".appVPath","/")
   If args(0)="emit" Then
    Emit(args(1))
   Else
    Validate(args(1),args(2))
   End If
  Catch ex As Exception
   File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"failure.json"),json.Serialize(New With {.error=ex.GetBaseException().Message,.checks=checks}))
   Console.WriteLine("DELTA_FAILED="+ex.GetBaseException().Message)
   Environment.ExitCode=1
  End Try
 End Sub
 Private Sub Emit(outputPath As String)
@@HISTORICAL_ASSERTION@@
  Assert(StorefrontPromotionCatalogProvider.BuildMainCatalogJoin()=SearchSuggestBaselinePromotionCatalogProvider.BuildMainCatalogJoin(),"unchanged membership main SQL")
  Assert(StorefrontPromotionCatalogProvider.BuildFacetCatalogJoin()=SearchSuggestBaselinePromotionCatalogProvider.BuildFacetCatalogJoin(),"unchanged membership facet SQL")
  Assert(StorefrontPromotionCatalogProvider.BuildLegacyCatalogJoin()=SearchSuggestBaselinePromotionCatalogProvider.BuildLegacyCatalogJoin(),"unchanged legacy membership SQL")
  Assert(StorefrontPromotionCatalogProvider.BuildSuggestPromotionJoin()=SearchSuggestBaselinePromotionCatalogProvider.BuildSuggestPromotionJoin(),"unchanged suggest membership SQL")
  Dim gross=StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.Prezzo","vsuperarticoli.PrezzoIvato","vsuperarticoli.IdIvaRC","vsuperarticoli.ValoreIvaRC","?ksRcEnabled","?ksHasVatOverride","?ksVatOverride")
  Dim result As New Dictionary(Of String,Object) From {{"baseGross",gross},{"net",StorefrontEffectivePriceSqlBuilder.BuildQuantityOneDisplayPriceExpression(gross,True)},{"gross",StorefrontEffectivePriceSqlBuilder.BuildQuantityOneDisplayPriceExpression(gross,False)}}
  result("authorizedOffers")=GetType(ProductPromotionEligibilityResolver).GetMethod("BuildAuthorizedOffersSql",BindingFlags.NonPublic Or BindingFlags.Static).Invoke(Nothing,New Object(){False,False})
  For Each useDefault In New Boolean(){True,False}
   Dim joinSql=StorefrontPromotionCatalogProvider.BuildQuantityOnePriceJoin(useDefault),entry As New Dictionary(Of String,Object)
   entry("join")=joinSql : entry("baseline")=SearchSuggestBaselinePromotionCatalogProvider.BuildQuantityOnePriceJoin(useDefault)
   For Each excluded In New Boolean(){True,False}
    Dim prefix=If(excluded,"net","gross"),expr=CStr(result(prefix))
    entry(prefix+"Asc")=CatalogQty1ListingFixture.QuerySql(expr,joinSql,False,False)
    entry(prefix+"Desc")=CatalogQty1ListingFixture.QuerySql(expr,joinSql,False,True)
    entry(prefix+"Range")=CatalogQty1ListingFixture.QuerySql(expr,joinSql,True,False)
    entry("baseline"+prefix+"Asc")=CatalogQty1ListingFixture.QuerySql(expr,CStr(entry("baseline")),False,False)
    entry("baseline"+prefix+"Desc")=CatalogQty1ListingFixture.QuerySql(expr,CStr(entry("baseline")),False,True)
    entry("baseline"+prefix+"Range")=CatalogQty1ListingFixture.QuerySql(expr,CStr(entry("baseline")),True,False)
   Next
   result(If(useDefault,"default","exact"))=entry
  Next
  result("structuralChecks")=checks
  File.WriteAllText(outputPath,json.Serialize(result))
 End Sub
 Private Class ExpectedRow
  Public id As Integer,rawTc As Integer,tc As Integer,detail As Integer
  Public price As Decimal,card As String,pdp As Decimal,cart As Decimal
 End Class
 Private Function Context(scope As ProductPromotionEligibilityContext,excluded As Boolean,vatOverride As Nullable(Of Decimal),rc As Boolean) As HttpContext
  Dim ctx As New HttpContext(New HttpRequest("","https://synthetic.invalid/articolo.aspx",""),New HttpResponse(New StringWriter))
  Dim data As New SessionStateItemCollection
  data("AziendaID")=scope.CompanyId : data("Listino")=scope.Listino
  data("Iva_Utente")=If(vatOverride.HasValue,CObj(vatOverride.Value),CObj(-1D))
  data("AbilitatoIvaReverseCharge")=If(rc,1,0)
  data("IvaTipo")=If(excluded,1,2)
  SessionStateUtility.AddHttpSessionStateToContext(ctx,New HttpSessionStateContainer("synthetic",data,New HttpStaticObjectsCollection,20,False,HttpCookieMode.UseCookies,SessionStateMode.InProc,True))
  HttpContext.Current=ctx
  Return ctx
 End Function
 Private Function Canonical(c As Dictionary(Of String,Object),scope As ProductPromotionEligibilityContext,batch As ProductPromotionEligibilityBatch,policy As StorefrontPriceDisplayContext,ctx As HttpContext,raw As Dictionary(Of String,Object)) As ExpectedRow
  Dim id=CInt(raw("id")),sourceTc=CInt(raw("tc")),tc=If(sourceTc>0,sourceTc,-1),net=Money(raw("net"))
  Dim stored As Nullable(Of Decimal)=If(raw("storedGross") Is Nothing,New Nullable(Of Decimal)(),New Nullable(Of Decimal)(Money(raw("storedGross"))))
  Dim effective=StorefrontEffectivePriceResolver.ResolveEffectiveGross(net,stored,policy.ReverseChargeEnabled,policy.VatOverride,CInt(raw("rcid")),Money(raw("rcrate")))
  Assert(Rounded(effective)=Rounded(raw("gross")),CStr(c("name"))+"/fiscal-SQL-VB/"+id.ToString()+":"+tc.ToString())
  Dim gross=effective.GetValueOrDefault()
  Dim resolved=ProductPromotionEligibilityResolver.Resolve(batch,id,tc,1D,net,gross)
  Dim model=ProductPromotionDisplayHelper.BuildForProduct(batch,id,tc,net,gross,policy.IsVatExcluded)
  Dim data As New DataTable
  For Each col In New String(){"id","TCid","Prezzo","PrezzoIvato","CatalogDisplayPrice"}
   data.Columns.Add(col,GetType(Object))
  Next
  Dim row=data.NewRow() : row("id")=id : row("TCid")=tc : row("Prezzo")=net : row("PrezzoIvato")=gross
  row("CatalogDisplayPrice")=-999D : data.Rows.Add(row)
  Dim catalog As New CatalogQty1Fixture With {._priceDisplayContext=policy,.Batch=batch}
  Dim text=catalog.Price(row),display As Decimal=0D
  Dim hasNumeric=Decimal.TryParse(text,NumberStyles.Currency,CultureInfo.GetCultureInfo("it-IT"),display)
  Dim pdp As New PdpQty1Fixture With {._priceDisplayContext=policy,.Batch=batch}
  Dim pdpPrice=pdp.Price(id,tc,net,effective)
  Assert(If(hasNumeric,display,0D)=Rounded(pdpPrice),CStr(c("name"))+"/real-card-PDP/"+id.ToString()+":"+tc.ToString())
  CartQty1Fixture.Batch=batch
  Dim cart=New CartQty1Fixture().ResolveStandardPrice(ctx,Nothing,Nothing,scope,id,tc,1D,scope.Listino,False)
  If net>0D AndAlso gross>0D Then
   Assert(cart.IsValid AndAlso cart.Price=Rounded(resolved.EffectivePriceNet) AndAlso cart.PriceIvato=Rounded(resolved.EffectivePriceGross),CStr(c("name"))+"/real-cart-resolver/"+id.ToString()+":"+tc.ToString())
   Assert(Rounded(If(policy.IsVatExcluded,cart.Price,cart.PriceIvato))=If(hasNumeric,display,0D),CStr(c("name"))+"/cart-display/"+id.ToString()+":"+tc.ToString())
  Else
   Assert(Not cart.IsValid AndAlso Not model.HasDefaultQuantityOffer,CStr(c("name"))+"/invalid-base-no-promo/"+id.ToString()+":"+tc.ToString())
  End If
  Return New ExpectedRow With {.id=id,.rawTc=sourceTc,.tc=tc,.price=If(hasNumeric,display,0D),.card=text,.pdp=Rounded(pdpPrice),.cart=If(policy.IsVatExcluded,cart.Price,cart.PriceIvato),.detail=If(resolved.HasAppliedOffer,resolved.AppliedOffer.OfferDetailId,0)}
 End Function
 Private Function Key(id As Integer,tc As Integer,price As Decimal) As String
  Return id.ToString()+":"+tc.ToString()+":"+price.ToString("0.00",CultureInfo.InvariantCulture)
 End Function
 Private Function SqlKeys(rows As Object(),priceColumn As String) As String
  Return String.Join("|",rows.Select(Function(x) Key(CInt(Obj(x)("id")),CInt(Obj(x)("tc")),Rounded(Obj(x)(priceColumn)))))
 End Function
 Private Sub Validate(input As String,output As String)
  Dim matrix=Obj(json.DeserializeObject(File.ReadAllText(input))),caseCount=0
  For Each caseObject In Items(matrix("cases"))
   Dim c=Obj(caseObject),scope=ProductPromotionEligibilityResolver.CreateAnonymousContext("synthetic-"+CInt(c("company")).ToString(),CInt(c("company")),CInt(c("list")),New Date(2026,11,2))
   scope.IsAuthenticated=CBool(c("auth")) : scope.CurrentUserId=CInt(c("owner")) : scope.CampaignId=CInt(c("campaign"))
   Dim vatOverride As Nullable(Of Decimal)=If(c("override") Is Nothing,New Nullable(Of Decimal)(),New Nullable(Of Decimal)(Money(c("override"))))
   Dim policy As New StorefrontPriceDisplayContext(scope.CompanyId,scope.Listino,scope.IsAuthenticated,If(CBool(c("excluded")),StorefrontVatDisplayMode.VatExcluded,StorefrontVatDisplayMode.VatIncluded),vatOverride,If(vatOverride.HasValue,702,-1),"",CBool(c("rc")))
   Dim ctx=Context(scope,policy.IsVatExcluded,policy.VatOverride,policy.ReverseChargeEnabled)
   Dim snapshot As New ProductPromotionEligibilitySnapshot With {.Status=If(CBool(c("technical")),ProductPromotionEligibilityLoadStatus.TechnicalError,ProductPromotionEligibilityLoadStatus.Success)}
   For Each offerObject In Items(c("rawOffers"))
    Dim o=Obj(offerObject),id=CInt(o("ArticleId"))
    Assert(ProductPromotionEligibilityResolver.IsOwnerAuthorized(CInt(o("OwnerUserId")),scope),CStr(c("name"))+"/SQL-owner-filter")
    If Not snapshot.OffersByArticle.ContainsKey(id) Then snapshot.OffersByArticle(id)=New List(Of ProductPromotionEligibilityRawOffer)
    snapshot.OffersByArticle(id).Add(New ProductPromotionEligibilityRawOffer With {.ArticleId=id,.TargetTCId=CInt(o("TargetTCId")),.OfferId=CInt(o("OfferId")),.OfferDetailId=CInt(o("OfferDetailId")),.OwnerUserId=CInt(o("OwnerUserId")),.QntMinima=Money(o("QntMinima")),.Multipli=Money(o("Multipli")),.PromoPriceNet=Money(o("PromoPriceNet")),.DiscountPercent=Money(o("DiscountPercent"))})
   Next
   Dim batch As New ProductPromotionEligibilityBatch(scope,snapshot)
   CartQty1Fixture.Batch=batch : CartQty1Fixture.CandidateRows=New List(Of CartPriceCandidate)
   For Each rowObject In Items(c("baseRows"))
    Dim r=Obj(rowObject)
    CartQty1Fixture.CandidateRows.Add(New CartPriceCandidate With {.ArticleId=CInt(r("id")),.TCId=CInt(r("tc")),.Price=Money(r("net")),.PriceIvato=Money(r("storedGross")),.ReverseChargeVatId=CInt(r("rcid")),.ReverseChargeVatValue=Money(r("rcrate")),.Description="Synthetic",.Code="Synthetic"})
   Next
   If CBool(c("technical")) Then
    Dim fault=ProductPromotionDisplayHelper.BuildForProduct(batch,1,101,100D,122D,policy.IsVatExcluded)
    Dim cart=New CartQty1Fixture().ResolveStandardPrice(ctx,Nothing,Nothing,scope,1,101,1D,scope.Listino,False)
    Assert(fault.ResolutionState=ProductPromotionDisplayResolutionState.TechnicalError AndAlso Not fault.HasDefaultQuantityOffer,CStr(c("name"))+"/technical-no-promotion")
    Assert(cart.HasTechnicalError AndAlso Not cart.IsValid,CStr(c("name"))+"/technical-cart-blocked")
    Assert(New CatalogQty1FailureFixture().FailClosed(),CStr(c("name"))+"/real-catalog-error-state")
   Else
    Dim expected As New List(Of ExpectedRow)
    For Each rowObject In Items(c("baseRows"))
     expected.Add(Canonical(c,scope,batch,policy,ctx,Obj(rowObject)))
    Next
    For Each projectionObject In Items(c("projections"))
     Dim p=Obj(projectionObject),label=CStr(c("name"))+"/"+CBool(p("useDefault")).ToString()
     Assert(Items(p("current")).Length=expected.Count,label+"/one-projection-row-per-identity")
     For Each rowObject In Items(p("current"))
      Dim row=Obj(rowObject),e=expected.Single(Function(x) x.id=CInt(row("id")) AndAlso x.rawTc=CInt(row("tc")))
      Assert(Rounded(row("price"))=e.price,label+"/qty1-price/"+e.id.ToString()+":"+e.tc.ToString())
      Assert(CInt(Money(row("detail")))=e.detail,label+"/offer-identity/"+e.id.ToString()+":"+e.tc.ToString())
     Next
     Dim selected=expected.Where(Function(x) x.id=2 OrElse x.rawTc=102).ToList()
     Dim asc=selected.OrderBy(Function(x) If(x.price>0D,0,1)).ThenBy(Function(x) x.price).ThenBy(Function(x) x.id)
     Dim desc=selected.OrderBy(Function(x) If(x.price>0D,0,1)).ThenByDescending(Function(x) x.price).ThenBy(Function(x) x.id)
     Dim ranged=selected.Where(Function(x) x.price>0D AndAlso x.price<=Money(c("cutoff"))).OrderBy(Function(x) x.price).ThenBy(Function(x) x.id)
     Assert(SqlKeys(Items(p("asc")),"CatalogDisplayPrice")=String.Join("|",asc.Select(Function(x) Key(x.id,x.rawTc,x.price))),label+"/real-catalog-ascending")
     Assert(SqlKeys(Items(p("desc")),"CatalogDisplayPrice")=String.Join("|",desc.Select(Function(x) Key(x.id,x.rawTc,x.price))),label+"/real-catalog-descending")
     Assert(SqlKeys(Items(p("range")),"CatalogDisplayPrice")=String.Join("|",ranged.Select(Function(x) Key(x.id,x.rawTc,x.price))),label+"/real-pmin-pmax")
     Assert(CInt(p("invalidVariantRows"))=0,label+"/missing-TC-no-price-row")
     If p("baseline") IsNot Nothing Then
      Dim old=Obj(p("baseline")),bad=Items(old("projection")).Select(Function(x) Obj(x)).Single(Function(x) CInt(x("id"))=1 AndAlso CInt(x("tc"))=102),good=expected.Single(Function(x) x.id=1 AndAlso x.rawTc=102)
      Assert(Rounded(bad("price"))<>good.price,label+"/immutable-baseline-counterexample")
      Assert(SqlKeys(Items(old("asc")),"CatalogDisplayPrice")<>SqlKeys(Items(p("asc")),"CatalogDisplayPrice"),label+"/baseline-real-ascending-counterexample")
      Assert(SqlKeys(Items(old("desc")),"CatalogDisplayPrice")<>SqlKeys(Items(p("desc")),"CatalogDisplayPrice"),label+"/baseline-real-descending-counterexample")
      Assert(SqlKeys(Items(old("range")),"CatalogDisplayPrice")<>SqlKeys(Items(p("range")),"CatalogDisplayPrice"),label+"/baseline-real-pmin-pmax-counterexample")
      reproductions.Add(New With {.identity="1/102/list1/qty1",.useDefault=CBool(p("useDefault")),.baselineSql=Rounded(bad("price")),.card=good.card,.pdp=good.pdp,.cart=good.cart,.candidateSql=good.price,.baselineAscending=SqlKeys(Items(old("asc")),"CatalogDisplayPrice"),.candidateAscending=SqlKeys(Items(p("asc")),"CatalogDisplayPrice"),.baselineRangeMax110=SqlKeys(Items(old("range")),"CatalogDisplayPrice"),.candidateRangeMax110=SqlKeys(Items(p("range")),"CatalogDisplayPrice")})
     End If
    Next
    If CStr(c("scenario"))="exact-only" Then
     Dim invalid=New CartQty1Fixture().ResolveStandardPrice(ctx,Nothing,Nothing,scope,1,9999,1D,scope.Listino,False)
     Assert(Not invalid.IsValid AndAlso Not invalid.HasTechnicalError,CStr(c("name"))+"/real-cart-invalid-positive-no-base-fallback")
    End If
   End If
   caseCount+=1
  Next
  Assert(reproductions.Count=2,"both-default-mode-baseline-counterexamples")
  File.WriteAllText(output,json.Serialize(New With {.result="A",.conclusion="DIFETTO RIPRODOTTO E CORRETTO",.cases=caseCount,.checks=checks,.pass=checks.Count,.reproductions=reproductions,.limitations=matrix("limitations"),.boundaries="Original card/PDP/cart price methods, resolver and SQL builders; only candidate/offer/free-shipping I/O supplied by synthetic fixtures. No MySQL/IIS."}))
  Console.WriteLine("QTY1_VARIANT_RESULT PASS="+checks.Count.ToString()+" FAIL=0 CASES="+caseCount.ToString())
 End Sub
End Module

'@
$node=@'
'use strict';
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const root=__dirname,sqls=JSON.parse(fs.readFileSync(path.join(root,'sql.json'),'utf8')),cases=[];
const core=['exact-only','exact-over-generic','none'];
const rules=['generic-only','minimum3','multiple1','multiple2','ambiguous','future','expired','boundary','owner-other','owner-current','company-other','campaign-mismatch','campaign-generic','list-other','discount20','discount100','not-beneficial','disabled','no-promo','missing-gross','standard0','detail-tie'];
function add(company,scenario,auth,excluded,extra={}){
 cases.push({name:company+'/'+scenario+'/'+(auth?'owner':'anonymous')+'/'+(excluded?'net':'gross')+'/'+cases.length,company,list:company===1?1:10,factor:company,scenario,auth,excluded,owner:auth?77:0,override:null,rc:false,technical:false,...extra});
}
for(const company of [1,2]){
 for(const auth of [false,true])for(const excluded of [false,true])for(const scenario of core)add(company,scenario,auth,excluded);
 for(const [i,scenario]of rules.entries())add(company,scenario,['owner-current','owner-other'].includes(scenario)||i%2===0,i%3===0);
 add(company,'owner-current',false,false);
 for(const excluded of [false,true]){
  add(company,'exact-only',true,excluded,{override:0});
  add(company,'exact-only',true,excluded,{override:10});
  add(company,'exact-only',true,excluded,{override:10,rc:true});
  add(company,'technical',true,excluded,{technical:true});
 }
}
function run(c){
 const db=new DatabaseSync(':memory:');db.function('MOD',(a,b)=>a%b);
 db.function('IF',(condition,a,b)=>condition?a:b);
 db.exec("CREATE TABLE articoli(id PRIMARY KEY,Abilitato,NoPromo,IdIvaRC,ValoreIvaRC); INSERT INTO articoli VALUES(1,1,0,-1,-1),(2,1,0,-1,-1); CREATE TABLE stock(ArticoliId,TCId,Giacenza,Impegnata); INSERT INTO stock VALUES(1,101,15,0),(1,102,15,0),(2,-1,15,0); CREATE TABLE articoli_tagliecolori(id PRIMARY KEY,ArticoliId); INSERT INTO articoli_tagliecolori VALUES(101,1),(102,1); CREATE TABLE articoli_listini(id PRIMARY KEY,ArticoliId,TCId,NListino,Prezzo,PrezzoIvato,UNIQUE(ArticoliId,NListino)); CREATE TABLE offerte(id PRIMARY KEY,AziendeId,Abilitato,DaListino,AListino,DataInizio,DataFine,UtentiId,QntMinima,Multipli,Prezzo,Sconto); CREATE TABLE offertedettaglio(id PRIMARY KEY,OfferteId,ArticoliId,TCId); CREATE VIEW voffertearticoli AS SELECT od.ArticoliId AS id,o.id AS OfferteID,od.id AS OfferteDettagliId FROM offertedettaglio od JOIN offerte o ON o.id=od.OfferteId; CREATE VIEW varticolilistini AS SELECT a.id,s.TCId,p.id AS ArticoliListiniId,p.NListino,p.Prezzo,p.PrezzoIvato,a.IdIvaRC,a.ValoreIvaRC,s.Giacenza,s.Impegnata,0 AS OfferteDettagliId FROM stock s JOIN articoli_listini p ON p.ArticoliId=s.ArticoliId JOIN articoli a ON a.id=s.ArticoliId; CREATE VIEW vsuperarticoli AS SELECT * FROM varticolilistini;");
 db.prepare('INSERT INTO articoli_listini VALUES(501,1,101,?,?,?),(601,2,-1,?,?,?)').run(c.list,100*c.factor,122*c.factor,c.list,90*c.factor,109.8*c.factor);
 if(c.rc)db.exec('UPDATE articoli SET IdIvaRC=701,ValoreIvaRC=0 WHERE id=1;');
 if(c.scenario==='missing-gross')db.exec('UPDATE articoli_listini SET PrezzoIvato=NULL WHERE ArticoliId=1;');
 if(c.scenario==='no-promo')db.exec('UPDATE articoli SET NoPromo=1 WHERE id=1;');
 if(c.scenario==='standard0')db.exec('UPDATE stock SET TCId=0 WHERE ArticoliId=2;');
 function offer(id,tc,net,changes={}){
  const h={company:c.company,enabled:1,from:c.list,to:c.list,start:'2026-01-01',end:'2026-12-31',owner:0,min:1,multiple:0,price:net*c.factor,discount:0,...changes};
  db.prepare('INSERT INTO offerte VALUES(?,?,?,?,?,?,?,?,?,?,?,?)').run(id,h.company,h.enabled,h.from,h.to,h.start,h.end,h.owner,h.min,h.multiple,h.price,h.discount);
  db.prepare('INSERT INTO offertedettaglio VALUES(?,?,1,?)').run(id+100,id,tc);
 }
 switch(c.scenario){
  case'none':case'technical':break;
  case'generic-only':offer(201,-1,60);break;
  case'exact-over-generic':offer(201,101,80);offer(202,-1,60);break;
  case'minimum3':offer(201,101,80,{min:3});break;
  case'multiple1':offer(201,101,80,{min:0,multiple:1});break;
  case'multiple2':offer(201,101,80,{min:0,multiple:2});break;
  case'ambiguous':offer(201,101,80,{min:1,multiple:1});break;
  case'future':offer(201,101,80,{start:'2026-11-03'});break;
  case'expired':offer(201,101,80,{end:'2026-11-01'});break;
  case'boundary':offer(201,101,80,{start:'2026-11-02',end:'2026-11-02'});break;
  case'owner-other':offer(201,101,80,{owner:88});break;
  case'owner-current':offer(201,101,80,{owner:77});break;
  case'company-other':offer(201,101,80,{company:3-c.company});break;
  case'campaign-mismatch':offer(201,101,80);break;
  case'campaign-generic':offer(201,101,80);offer(202,-1,60);break;
  case'list-other':offer(201,101,80,{from:c.list===1?10:1,to:c.list===1?10:1});break;
  case'discount20':offer(201,101,0,{discount:20});break;
  case'discount100':offer(201,101,0,{discount:100});break;
  case'not-beneficial':offer(201,101,120);break;
  case'disabled':offer(201,101,80,{enabled:0});break;
  case'detail-tie':offer(201,101,80);offer(202,101,80);break;
  default:offer(201,101,80);
 }
 const campaign=c.scenario==='campaign-mismatch'?999:c.scenario==='campaign-generic'?202:0;
 const params={promoCompanyId:c.company,promoListino:c.list,promoEvaluationDate:'2026-11-02',promoIsAuthenticated:c.auth?1:0,promoCurrentUserId:c.owner,promoCampaignId:campaign,ksRcEnabled:c.rc?1:0,ksHasVatOverride:c.override===null?0:1,ksVatOverride:c.override||0,companyId:c.company,listino:c.list,evaluationDate:'2026-11-02',isAuthenticated:c.auth?1:0,currentUserId:c.owner,campaignId:campaign,NListino:c.list,selectedTc:102,pmin:0,pmax:(c.excluded?90:110)*c.factor};
 function query(raw){
  const text=raw.replace(/\?([A-Za-z]\w*)/g,'@$1').replace(/AS DECIMAL\(38,16\)/gi,'AS REAL'),used={};
  for(const m of text.matchAll(/@(\w+)/g)){if(!(m[1]in params))throw Error('UNBOUND_PARAMETER_'+m[1]);used['@'+m[1]]=params[m[1]];}
  return db.prepare(text).all(used);
 }
 const from=' FROM vsuperarticoli LEFT JOIN (SELECT ArticoliId,MIN(id) AS DefaultTCid FROM articoli_tagliecolori GROUP BY ArticoliId) atc_default ON atc_default.ArticoliId=vsuperarticoli.id ';
 const baseRows=query('SELECT vsuperarticoli.id AS id,vsuperarticoli.TCId AS tc,vsuperarticoli.Prezzo AS net,vsuperarticoli.PrezzoIvato AS storedGross,vsuperarticoli.IdIvaRC AS rcid,vsuperarticoli.ValoreIvaRC AS rcrate,'+sqls.baseGross+' AS gross'+from+' WHERE vsuperarticoli.NListino=@promoListino ORDER BY id,tc');
 const rawOffers=c.technical?[]:query(sqls.authorizedOffers);
 const projections=[];
 if(!c.technical)for(const useDefault of [true,false]){
  const k=useDefault?'default':'exact',expression=c.excluded?sqls.net:sqls.gross,join=sqls[k].join;
  const select='SELECT vsuperarticoli.id AS id,vsuperarticoli.TCId AS tc,'+expression+' AS price,ks_qty1_price.AppliedOfferDetailId AS detail'+(useDefault?from:' FROM vsuperarticoli ');
  const current=query(select+join+' WHERE vsuperarticoli.NListino=@promoListino ORDER BY id,tc');
  const asc=query(sqls[k][c.excluded?'netAsc':'grossAsc']),desc=query(sqls[k][c.excluded?'netDesc':'grossDesc']),range=query(sqls[k][c.excluded?'netRange':'grossRange']);
  let baseline=null;
  if(c.company===1&&c.scenario==='exact-only'&&!c.auth&&!c.excluded&&c.override===null&&!c.rc)baseline={projection:query(select+sqls[k].baseline+' WHERE vsuperarticoli.NListino=@promoListino ORDER BY id,tc'),asc:query(sqls[k].baselinegrossAsc),desc:query(sqls[k].baselinegrossDesc),range:query(sqls[k].baselinegrossRange)};
  const absent=query(select+join+' WHERE vsuperarticoli.NListino=@promoListino AND vsuperarticoli.TCId=9999');
  projections.push({useDefault,current,asc,desc,range,baseline,invalidVariantRows:absent.length});
 }
 const result={...c,campaign,cutoff:params.pmax,baseRows,rawOffers,projections};
 db.close();return result;
}
const result=cases.map(run);
fs.writeFileSync(path.join(root,'matrix.json'),JSON.stringify({cases:result,limitations:['Real emitted SQL; only MySQL parameter markers and DECIMAL->REAL adapted for SQLite','SQLite in-memory relations mirror required versioned view joins, not complete operational views','No IIS/MySQL/HTTP or operational data/credentials accessed']}));
console.log(JSON.stringify({syntheticSqlCases:result.length,database:'SQLite memory',operationalDatabaseConnections:0}));

'@
$catalog=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
$pdp=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articolo.aspx.vb'))
$cart=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartPriceRevalidationHelper.vb'))
$map=@{
 CARD=(Method $catalog 'CatalogPriceTextFor');PDP=(Method $pdp 'BuildAuthorizedPriceContext');
 CART=(Method $cart 'ResolveStandardPrice');CARTGROSS=(Method $cart 'ResolvePriceIvato');
 REVERSE=(Method $cart 'ReverseChargeEnabled');SESSIONINT=(Method $cart 'SessionInt');
 SESSIONDECIMAL=(Method $cart 'SessionDecimal');READDECIMAL=(Method $cart 'ReadDecimal');ROUND=(Method $cart 'RoundCurrency');
 RANK=(Method $catalog 'BuildCatalogRowRankSql');LIST=(Method $catalog 'BuildCatalogListingSql')
}
$failure=[regex]::Match($catalog,'(?ms)^    Private Sub FailCatalogQuantityOnePrices\(\).*?^    End Sub')
$priceClass=[regex]::Match($pdp,'(?ms)^    Private Class PriceContext\b.*?^    End Class')
if(-not $failure.Success -or -not $priceClass.Success){throw 'QTY1_VARIANT_PAGE_CONTRACT_MISSING'}
$map.FAIL=$failure.Value;$map.PRICECLASS=$priceClass.Value
foreach($key in $map.Keys){$fixture=$fixture.Replace(('@@'+$key+'@@'),$map[$key])}
if($fixture -match '@@[A-Z]+@@'){throw 'QTY1_VARIANT_UNRESOLVED_FIXTURE_SOURCE'}
$historicalSource=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Tools/SearchSuggestCommercialContextHarness.vb'))
$historical=[regex]::Match($historicalSource,'(?ms)^        Dim expectedQuantityOneJoin As String.*?^        Assert\(StorefrontPromotionCatalogProvider\.BuildQuantityOnePriceJoin\(\) = expectedQuantityOneJoin,.*?\)')
if(-not $historical.Success){throw 'QTY1_VARIANT_HISTORICAL_ASSERTION_NOT_ADAPTED'}
$main=$main.Replace('@@HISTORICAL_ASSERTION@@',$historical.Value)
$baseline=@(& git -C $RepositoryRoot show ($BaselineRef+':App_Code/StorefrontPromotionCatalogProvider.vb'))
if($LASTEXITCODE){throw 'QTY1_VARIANT_BASELINE_SOURCE_UNAVAILABLE'}
$baselineSource=($baseline -join [Environment]::NewLine).Replace('Public Module StorefrontPromotionCatalogProvider','Public Module SearchSuggestBaselinePromotionCatalogProvider')
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'BaselinePromotion.vb'),$baselineSource)
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'Fixture.vb'),$fixture)
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'Harness.vb'),$main)
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'Matrix.cjs'),$node)
$executable=Join-Path $EvidenceDirectory 'Harness.exe'
$references=@('System.dll','System.Core.dll','System.Data.dll','System.Configuration.dll','System.Web.dll','System.Web.Extensions.dll','System.Xml.dll','System.Xml.Linq.dll','System.Drawing.dll','System.Net.Http.dll','System.Runtime.Serialization.dll','System.ServiceModel.dll')
$compilerArgs=@('/nologo','/target:exe','/optioninfer+','/main:PromotionVariantQty1Harness',('/out:'+$executable),'/imports:Microsoft.VisualBasic,System,System.Collections,System.Collections.Generic,System.Data,System.Linq,System.Web,System.Configuration')
foreach($ref in $references){$compilerArgs+=('/reference:'+(Join-Path $framework $ref))}
foreach($dll in @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Bin') -File -Filter '*.dll')){$compilerArgs+=('/reference:'+$dll.FullName);Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $EvidenceDirectory $dll.Name)}
$compilerArgs+=@(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'App_Code') -File -Filter '*.vb'|ForEach-Object {$_.FullName})
$compilerArgs+=@('BaselinePromotion.vb','Fixture.vb','Harness.vb'|ForEach-Object {Join-Path $EvidenceDirectory $_})
$compile=@(& (Join-Path $framework 'vbc.exe') @compilerArgs 2>&1)
$compile|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'compile.log') -Encoding UTF8
if($LASTEXITCODE){throw ('QTY1_VARIANT_COMPILE_FAILED '+($compile -join [Environment]::NewLine))}
# Synthetic executable config only. No web.config, credentials, HTTP or MySQL endpoints are read.
[IO.File]::WriteAllText(($executable+'.config'),'<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="Server=synthetic.invalid;Database=synthetic;User Id=synthetic;" providerName="MySql.Data.MySqlClient"/></connectionStrings></configuration>')
& $executable emit (Join-Path $EvidenceDirectory 'sql.json')
if($LASTEXITCODE){throw 'QTY1_VARIANT_REAL_SQL_EMIT_FAILED'}
& $NodePath (Join-Path $EvidenceDirectory 'Matrix.cjs')
if($LASTEXITCODE){throw 'QTY1_VARIANT_RELATIONAL_MATRIX_FAILED'}
& $executable validate (Join-Path $EvidenceDirectory 'matrix.json') (Join-Path $EvidenceDirectory 'result.json')
if($LASTEXITCODE){throw 'QTY1_VARIANT_DIFFERENTIAL_ASSERTIONS_FAILED'}
$result=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'result.json') -Raw|ConvertFrom-Json
if($result.result -cne 'A'){throw 'QTY1_VARIANT_RESULT_NOT_A'}
Write-Output ('QTY1_VARIANT_DELTA_PASS cases='+$result.cases+' assertions='+$result.pass+' MYSQL=NOT_EXECUTED IIS=NOT_EXECUTED')
