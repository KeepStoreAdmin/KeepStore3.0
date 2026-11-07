[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [switch]$ListinoAuthorityOnly,
    [string]$EvidenceDirectory,
    [string]$BaselineRef = '161b8d517082dd4e458f8f9d7974332c8475bb53'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

if($ListinoAuthorityOnly){
    # Reuse the real-method extraction, vbc and System.Web session-fixture approach
    # of this harness and Test-RegOrderSql8Compatibility. No existing suite is run.
    $ErrorActionPreference='Stop'
    if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
    if(!$EvidenceDirectory){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    $evidence=[IO.Path]::GetFullPath($EvidenceDirectory)
    if(!$evidence.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
    [void][IO.Directory]::CreateDirectory($evidence)
    if($BaselineRef -cnotmatch '^[0-9a-f]{40}$'){throw 'EXACT_BASELINE_REQUIRED'}
    $utf8=New-Object Text.UTF8Encoding($false)
    function Source([string]$file){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $file))}
    function Original([string]$file){$s=(& git -C $RepositoryRoot show ($BaselineRef+':'+$file)) -join "`n";if($LASTEXITCODE){throw 'BASELINE_UNAVAILABLE'};return $s}
    function Method([string]$s,[string]$name){$m=[regex]::Match($s,'(?ms)^\s*(?:Public|Private|Protected) (?:Shared )?(?:Function|Sub) '+$name+'\b.*?^\s*End (?:Function|Sub)');if(!$m.Success){throw ('SOURCE_METHOD_MISSING '+$name)};return $m.Value}
    function OrderBlock([string]$s){$a=$s.IndexOf('                If Not isLegacyCouponFlow Then');$b=$s.IndexOf('                CheckoutFailureRecoveryService.TracePhase(', $s.IndexOf('                End If', $s.IndexOf('If priceRevalidation.HasChanges Then',$a))+22);if($a -lt 0 -or $b -lt $a){throw 'ORDER_BLOCK_MISSING'};return $s.Substring($a,$b-$a)}
    function Flat([string]$s){return ($s -replace '\r\n',"`n").Trim()}
    $order=Source 'ordine.aspx.vb';$cart=Source 'carrello.aspx.vb';$oldOrder=Original 'ordine.aspx.vb';$oldCart=Original 'carrello.aspx.vb'
    $block=OrderBlock $order;$oldBlock=OrderBlock $oldOrder;$handler=Method $cart 'rPromo_ItemDataBound';$oldHandler=Method $oldCart 'rPromo_ItemDataBound'
    if((Flat $order.Replace($block,'')) -cne (Flat $oldOrder.Replace($oldBlock,'')) -or (Flat $cart.Replace($handler,'')) -cne (Flat $oldCart.Replace($oldHandler,''))){throw 'RUNTIME_SCOPE_EXPANDED'}
    foreach($file in @('Page.master','App_Code/StorefrontPriceDisplayContextProvider.vb','App_Code/StorefrontPriceDisplayContext.vb','App_Code/StorefrontCommercialIsolationPolicy.vb','App_Code/OrderStorefrontContext.vb','App_Code/CartPriceRevalidationHelper.vb','App_Code/OrderDurableIdempotencyService.vb','App_Code/CheckoutFailureRecoveryService.vb','App_Code/CheckoutTerminalOutcomeDispatcher.vb','App_Code/ProductPromotionEligibilityResolver.vb','App_Code/ProductPromotionDisplayHelper.vb')){
        if((Flat (Source $file)) -cne (Flat (Original $file))){throw ('AUTHORITY_CHANGED '+$file)}
    }
    if($order.IndexOf($block) -ge $order.IndexOf('Using cmd As New MySqlCommand("Carrello_Documento"') -or $order.IndexOf('SendEmail(', $order.IndexOf($block)) -lt $order.IndexOf($block)+$block.Length){throw 'SIDE_EFFECT_ORDER_CHANGED'}
    $price=Source 'App_Code/CartPriceRevalidationHelper.vb';$resolver=Source 'App_Code/ProductPromotionEligibilityResolver.vb';$durable=Source 'App_Code/OrderDurableIdempotencyService.vb';$dispatcher=Source 'App_Code/CheckoutTerminalOutcomeDispatcher.vb'
    $priceTypes=$price.Substring($price.IndexOf('Public Class CartPriceRevalidationChange'),$price.IndexOf('Friend Class CartPriceRevalidationRow')-$price.IndexOf('Public Class CartPriceRevalidationChange'))
    $eligibilityTypes=$resolver.Substring($resolver.IndexOf('Public Class ProductPromotionEligibilityContext'),$resolver.IndexOf('Public Module ProductPromotionEligibilityResolver')-$resolver.IndexOf('Public Class ProductPromotionEligibilityContext'))
    $contexts=([regex]::Matches($resolver,'(?ms)^    Public Function CreateContext\b.*?^    End Function')|ForEach-Object {$_.Value}) -join "`n"
    $constants=([regex]::Matches($price,'(?m)^    Public Const (?:SessionMessageKey|SessionChangedKey|GenericChangedMessage|GenericTechnicalErrorMessage).*')|ForEach-Object {$_.Value}) -join "`n"
    $priceMethods=@('StoreResultInSession','BuildMessageHtml','PriceChanged','FormatCurrencyIt')|ForEach-Object {Method $price $_}
    $template=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Configuration
Imports System.Text
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
PRICE_TYPES
ELIGIBILITY_TYPES
Public Module Io
 Public Events As New List(Of String), PriceCalls As Integer, LastList As Integer, PromoCalls As Integer, Documents As Integer, Gateways As Integer, Emails As Integer, Confirmations As Integer
 Public ExpectedCompany As Integer, ExpectedList As Integer, RetryPersists As Boolean=True, Failure As Boolean, Changed As Boolean, OfferAllowed As Boolean=True, PromoTechnical As Boolean
 Public Sub Reset()
  Events.Clear():PriceCalls=0:LastList=0:PromoCalls=0:Documents=0:Gateways=0:Emails=0:Confirmations=0:RetryPersists=True:Failure=False:Changed=False:OfferAllowed=True:PromoTechnical=False
 End Sub
End Module
Public Class FixtureTransaction
 Public Sub Rollback()
  Io.Events.Add("rollback")
 End Sub
 Public Sub Dispose()
  Io.Events.Add("dispose")
 End Sub
 Public Sub Commit()
  Io.Events.Add("commit")
 End Sub
End Class
Public Class OrderIdentityFixture
 Public CompanyId As Integer,PriceListId As Integer
End Class
Public Class OrderPageFixture
 Public isLegacyCouponFlow As Boolean=False
 Public orderIdentity As New OrderIdentityFixture
 Public LoginId As Integer=42,TipoDoc As Integer=4
 Public checkoutRequestId As String="11111111111111111111111111111111",payloadFingerprint As String="synthetic-payload"
 Public conn As New Object,trns As FixtureTransaction=New FixtureTransaction
 Private Function GetSessionInt(key As String,Optional fallback As Integer=0) As Integer
  Dim parsed As Integer:Return If(Integer.TryParse(Convert.ToString(HttpContext.Current.Session(key)),parsed),parsed,fallback)
 End Function
 Public Sub Execute()
ORDER_BLOCK
  ' Observable boundary only: never execute a document, gateway, email or order.
  Io.Documents+=1:Io.Gateways+=1:Io.Emails+=1:Io.Confirmations+=1
 End Sub
End Class
Public Module CartPriceRevalidationHelper
PRICE_CONSTANTS
 Private ReadOnly PriceCulture As CultureInfo=CultureInfo.GetCultureInfo("it-IT")
 Public Function RevalidateCurrentCart(context As HttpContext,conn As Object,trns As Object,login As Integer,sessionId As String,listino As Integer,a As Boolean,b As Boolean,unused As Object) As CartPriceRevalidationResult
  Io.PriceCalls+=1:Io.LastList=listino
  Dim result As New CartPriceRevalidationResult With {.HasBlockingError=Io.Failure,.HasTechnicalError=Io.Failure,.ErrorMessage=GenericTechnicalErrorMessage}
  If Io.Changed Then result.Changes.Add(New CartPriceRevalidationChange With {.ArticleId=901,.OldPriceIvato=12.2D,.NewPriceIvato=13.42D})
  Return result
 End Function
PRICE_METHODS
End Module
Public Module OrderDurableIdempotencyService
NORMALIZE_REQUEST
 Public Function RecordRetryRequired(conn As Object,request As String,login As Integer,company As Integer,tipo As Integer,payload As String) As Boolean
  Io.Events.Add("retry-after-rollback"):Return Io.RetryPersists
 End Function
 Public Sub MarkRetryRequired(conn As Object,trns As Object,request As String,login As Integer,company As Integer,tipo As Integer,payload As String)
  Io.Events.Add("mark-retry")
 End Sub
End Module
Public Enum CheckoutTerminalOutcome
ENUM_VALUES
End Enum
Public Module CheckoutTerminalOutcomeDispatcher
 Public Function Dispatch(context As HttpContext,outcome As CheckoutTerminalOutcome,Optional token As String="") As Boolean
  If context.Items("KeepStore:CheckoutTerminalOutcome") IsNot Nothing Then Return False
  context.Items("KeepStore:CheckoutTerminalOutcome")=outcome.ToString()
  context.Response.StatusCode=303:context.Response.RedirectLocation=ResolveTarget(outcome,token)
  Io.Events.Add("dispatch"):Return True
 End Function
RESOLVE_TARGET
End Module
Public Module CheckoutDurableTelemetry
 Public Sub Write(context As HttpContext,request As String,phase As String,outcome As String,failure As Exception,idempotency As String,transaction As String,checkpoint As String)
 End Sub
End Module
Public Module KeepStoreLog
 Public Sub [Error](scope As String,message As String,ex As Exception,context As HttpContext)
 End Sub
End Module
Public Module StorefrontSeoTenantContext
 Public Function ConfiguredDatabaseScopeKey() As String
  Return "isolated-source-fixture"
 End Function
End Module
Public Module ProductPromotionEligibilityResolver
CONTEXT_METHODS
SESSION_INT
FIRST_POSITIVE
 Public Function Resolve(batch As ProductPromotionEligibilityBatch,article As Integer,tc As Integer,quantity As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
  Throw New InvalidOperationException("UNEXPECTED_BATCH_IO")
 End Function
 Public Function Resolve(connection As String,context As ProductPromotionEligibilityContext,article As Integer,tc As Integer,quantity As Decimal,net As Decimal,gross As Decimal) As ProductPromotionEligibilityResult
  Io.PromoCalls+=1
  Dim result As New ProductPromotionEligibilityResult With {.BasePriceNet=net,.BasePriceGross=gross}
  If Io.PromoTechnical Then Throw New InvalidOperationException("synthetic read failure")
  If Io.OfferAllowed AndAlso context.CompanyId=Io.ExpectedCompany AndAlso context.Listino=Io.ExpectedList AndAlso article=901 AndAlso tc=5 Then result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=11,.OfferDetailId=101,.QntMinima=2,.PriceNet=8D,.PriceGross=9.76D})
  Return result
 End Function
End Module
Public Class PromoPageFixture
 Public ReadOnly Property Session As HttpSessionState
  Get
   Return HttpContext.Current.Session
  End Get
 End Property
SESSION_GETTER
SAFE_INT
SAFE_INT_TEXT
READ_DECIMAL
PROMO_HANDLER
 Public Function Display(Optional detail As Integer=101,Optional tc As Integer=5) As Label
  Dim table As New DataTable
  table.Columns.Add("ID",GetType(Integer)):table.Columns.Add("TCid",GetType(Integer)):table.Columns.Add("OfferteDettagliId",GetType(Integer)):table.Columns.Add("Prezzo",GetType(Decimal)):table.Columns.Add("PrezzoIvato",GetType(Decimal))
  table.Rows.Add(901,tc,detail,10D,12.2D)
  Dim item As New RepeaterItem(0,ListItemType.Item):item.DataItem=table.DefaultView(0)
  Dim label As New Label With {.ID="lblOfferta",.Visible=True}:item.Controls.Add(label)
  rPromo_ItemDataBound(Nothing,New RepeaterItemEventArgs(item)):Return label
 End Function
End Class
Public Module ListinoAuthorityCases
 Private passed As Integer,failed As Integer
 Private Sub Check(name As String,valid As Boolean)
  If valid Then
   passed+=1:Console.WriteLine("PASS "+name)
  Else
   failed+=1:Console.WriteLine("FAIL "+name)
  End If
 End Sub
 Private Function Configure(company As Integer,list As Object,authenticated As Boolean,Optional tenant As Boolean=True) As HttpContext
  Io.Reset():Io.ExpectedCompany=company:Io.ExpectedList=If(company=1,If(authenticated,4,1),If(authenticated,13,10))
  Dim context As New HttpContext(New HttpRequest("","https://fixture.invalid/ordine.aspx",""),New HttpResponse(New System.IO.StringWriter))
  SessionStateUtility.AddHttpSessionStateToContext(context,New HttpSessionStateContainer("synthetic",New SessionStateItemCollection,New HttpStaticObjectsCollection,20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False))
  HttpContext.Current=context:context.Session("AziendaID")=company:context.Session("Listino")=list:context.Session("LoginId")=If(authenticated,42,0):context.Session("AuthenticatedAziendaID")=If(authenticated,company,0):context.Session("UtentiId")=If(authenticated,101,0):context.Session("IvaTipo")=2
  If tenant Then StorefrontPriceDisplayContextProvider.SetTenantDefaults(context,company,If(company=1,1,10),2)
  Return context
 End Function
 Private Sub Denied(name As String,company As Integer,list As Object,Optional tenant As Boolean=True,Optional anonymous As Boolean=False,Optional identityCompany As Integer=0,Optional identityList As Integer=0,Optional sessionCompany As Integer=0)
  Dim context=Configure(company,list,Not anonymous,tenant),order As New OrderPageFixture
  order.orderIdentity.CompanyId=If(identityCompany>0,identityCompany,company):order.orderIdentity.PriceListId=If(identityList>0,identityList,If(company=1,4,13))
  If sessionCompany>0 Then context.Session("AziendaID")=sessionCompany
  order.Execute()
  Check(name+"/no-revalidation",Io.PriceCalls=0)
  Check(name+"/no-document-email-gateway-confirmation",Io.Documents+Io.Emails+Io.Gateways+Io.Confirmations=0)
  Check(name+"/rollback-retry-dispatch",String.Join(",",Io.Events.ToArray())="rollback,dispose,retry-after-rollback,dispatch")
  Check(name+"/technical-feedback-and-retirement",Convert.ToString(context.Session("CartPriceRevalidationMessage"))=HttpUtility.HtmlEncode(CartPriceRevalidationHelper.GenericTechnicalErrorMessage) AndAlso CheckoutFailureRecoveryService.IsRetiredRequest(context,order.checkoutRequestId))
  Check(name+"/existing-terminal-target",context.Response.StatusCode=303 AndAlso context.Response.RedirectLocation="carrello.aspx?pricechanged=1")
 End Sub
 Public Sub Main()
  For Each company As Integer In New Integer(){1,2}
   For Each authenticated As Boolean In New Boolean(){False,True}
    Dim list=If(company=1,If(authenticated,4,1),If(authenticated,13,10)),context=Configure(company,list,authenticated),promo=New PromoPageFixture().Display()
    Check("valid/"+company.ToString()+"/"+authenticated.ToString()+"/promo",promo.Visible AndAlso promo.Text.Contains("9,76") AndAlso Io.PromoCalls=1)
    If authenticated Then
     Dim order As New OrderPageFixture:order.orderIdentity.CompanyId=company:order.orderIdentity.PriceListId=list:order.Execute()
     Check("valid/order/"+company.ToString(),Io.PriceCalls=1 AndAlso Io.LastList=list AndAlso Io.Documents=1 AndAlso Io.Events.Count=0)
    Else
     Denied("anonymous/order/"+company.ToString(),company,list,True,True)
    End If
   Next
   For Each bad As Object In New Object(){Nothing,0,-3,"invalid","10.5",DBNull.Value}
    Dim name="invalid-list/"+company.ToString()+"/"+Convert.ToString(bad,CultureInfo.InvariantCulture)
    Denied(name,company,bad)
    Configure(company,bad,True):Dim label=New PromoPageFixture().Display():Check(name+"/badge-hidden-no-read",Not label.Visible AndAlso Io.PromoCalls=0)
   Next
   Denied("missing-provider/"+company.ToString(),company,Io.ExpectedList,False)
   Configure(company,If(company=1,4,13),True,False):Check("missing-provider/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
   Denied("wrong-order-company/"+company.ToString(),company,If(company=1,4,13),True,False,99)
   Denied("wrong-checkout-list/"+company.ToString(),company,If(company=1,4,13),True,False,0,99)
   Denied("wrong-session-tenant/order/"+company.ToString(),company,If(company=1,4,13),True,False,0,0,99)
   Dim ctx=Configure(company,If(company=1,4,13),True):ctx.Session("AziendaID")=99
   Check("wrong-session-tenant/provider",StorefrontPriceDisplayContextProvider.GetCurrent(ctx) Is Nothing)
   Check("wrong-session-tenant/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  Next
  Dim cached=Configure(1,4,True):StorefrontPriceDisplayContextProvider.GetCurrent(cached):cached.Session("AziendaID")=2
  Check("cached-context-company/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  cached=Configure(1,4,True):StorefrontPriceDisplayContextProvider.GetCurrent(cached):cached.Session("UtentiId")=0
  Check("inconsistent-promotion-auth/badge",Not New PromoPageFixture().Display().Visible AndAlso Io.PromoCalls=0)
  Configure(2,13,True):Io.OfferAllowed=False:Check("unauthorized-offer/badge",Not New PromoPageFixture().Display().Visible)
  Configure(2,13,True):Io.PromoTechnical=True:Check("technical-offer-read/badge",Not New PromoPageFixture().Display().Visible)
  Configure(2,13,True):Check("wrong-detail/badge",Not New PromoPageFixture().Display(999).Visible)
  Configure(2,13,True):Check("wrong-variant/badge",Not New PromoPageFixture().Display(101,6).Visible)
  Dim net=Configure(2,13,True):net.Session("IvaTipo")=1:Check("net-vat-mode-preserved/badge",New PromoPageFixture().Display().Text.Contains("8,00"))
  Dim retry=Configure(2,Nothing,True),page As New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.RetryPersists=False:page.Execute()
  Check("retry-write-failure/session-retired",CheckoutFailureRecoveryService.IsRetiredRequest(retry,page.checkoutRequestId) AndAlso Io.Documents=0 AndAlso Io.Events.Contains("retry-after-rollback"))
  Configure(2,13,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.Changed=True:page.Execute()
  Check("normal-price-change/commit-retry",String.Join(",",Io.Events.ToArray())="mark-retry,commit,dispose,dispatch" AndAlso Io.Documents=0)
  Configure(1,1,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=1:page.orderIdentity.PriceListId=1:page.Execute()
  Check("verified-list-one-still-valid",Io.PriceCalls=1 AndAlso Io.LastList=1 AndAlso Io.Documents=1)
  Configure(2,13,True):page=New OrderPageFixture:page.orderIdentity.CompanyId=2:page.orderIdentity.PriceListId=13:Io.Failure=True:page.Execute()
  Check("existing-revalidation-technical-failure",String.Join(",",Io.Events.ToArray())="rollback,dispose,retry-after-rollback,dispatch" AndAlso Io.Documents=0)
  Console.WriteLine("LISTINO_AUTHORITY_PASSED="+passed.ToString()+";FAILED="+failed.ToString())
  Environment.ExitCode=If(failed=0,0,1)
 End Sub
End Module
'@
    $template=$template.Replace('PRICE_TYPES',$priceTypes).Replace('ELIGIBILITY_TYPES',$eligibilityTypes).Replace('PRICE_CONSTANTS',$constants).Replace('PRICE_METHODS',($priceMethods -join "`n")).Replace('NORMALIZE_REQUEST',((Method $durable 'TryNormalizeRequestId').Replace('Public Shared Function','Public Function'))).Replace('ENUM_VALUES',([regex]::Match($dispatcher,'(?s)Public Enum CheckoutTerminalOutcome(.*?)End Enum').Groups[1].Value)).Replace('RESOLVE_TARGET',((Method $dispatcher 'ResolveTarget').Replace('Private Shared Function','Private Function'))).Replace('CONTEXT_METHODS',$contexts).Replace('SESSION_INT',(Method $resolver 'SessionInt')).Replace('FIRST_POSITIVE',(Method $resolver 'FirstPositive')).Replace('SESSION_GETTER',(Method $cart 'GetSessionInt')).Replace('SAFE_INT_TEXT',(Method $cart 'SafeIntFromText')).Replace('SAFE_INT',(Method $cart 'SafeInt')).Replace('READ_DECIMAL',(Method $cart 'TryReadDatabaseDecimal'))
    $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $shared=@('StorefrontPriceDisplayContext.vb','StorefrontPriceDisplayContextProvider.vb','StorefrontCommercialIsolationPolicy.vb','ProductPromotionDisplayHelper.vb','UiPriceFormatter.vb','CheckoutFailureRecoveryService.vb')|ForEach-Object{Join-Path $RepositoryRoot ('App_Code/'+$_)}
    $results=@()
    foreach($variant in @('baseline','candidate')){
        $vb=Join-Path $evidence ($variant+'.vb');$exe=Join-Path $evidence ($variant+'.exe')
        [IO.File]::WriteAllText($vb,$template.Replace('ORDER_BLOCK',$(if($variant -eq 'baseline'){$oldBlock}else{$block})).Replace('PROMO_HANDLER',$(if($variant -eq 'baseline'){$oldHandler}else{$handler})),$utf8)
        $compilation=@(& $compiler /nologo /target:exe /main:ListinoAuthorityCases ("/out:"+$exe) /r:System.dll,System.Core.dll,System.Web.dll,System.Data.dll,System.Configuration.dll $vb $shared 2>&1)
        if($LASTEXITCODE){[IO.File]::WriteAllLines((Join-Path $evidence ($variant+'-compile.log')),[string[]]$compilation,$utf8);throw ('LISTINO_COMPILE_FAILED '+$variant)}
        [IO.File]::WriteAllText(($exe+'.config'),'<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="KS-DBCFG-FIXTURE-listino" /></connectionStrings></configuration>',$utf8)
        $output=@(& $exe 2>&1|ForEach-Object{$_.ToString()});$code=$LASTEXITCODE
        [IO.File]::WriteAllLines((Join-Path $evidence ($variant+'.log')),[string[]]$output,$utf8)
        if(($variant -eq 'candidate' -and $code -ne 0) -or ($variant -eq 'baseline' -and ($code -ne 1 -or !($output -match '^FAIL invalid-list/.*/no-revalidation')))){throw ('LISTINO_EXECUTION_FAILED '+$variant)}
        $results+=@{Variant=$variant;Passes=@($output|Where-Object{$_ -match '^PASS '}).Count;Failures=@($output|Where-Object{$_ -match '^FAIL '}).Count}
    }
    [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Result='PASS SOURCE';Base=$BaselineRef;Variants=$results;RealSource='provider/context/policy, page methods and revalidation block, price feedback, recovery retirement, promo display helper; dispatcher target';Io='transaction, durable database write, resolver data and HTTP completion replaced; no IIS/MySQL/gateway/email; post-gate effects are counters';Scope='two runtime targets only; unchanged authorities checked'}|ConvertTo-Json -Depth 6),$utf8)
    $results|ForEach-Object{Write-Output ('LISTINO_AUTHORITY '+$_.Variant+' passes='+$_.Passes+' failures='+$_.Failures)}
    exit 0
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$harnessPath = Join-Path $PSScriptRoot 'CheckoutFailureRecoveryHarness.vb'
$logicalResolverPath = Join-Path $RepositoryRoot 'App_Code\OrderLogicalIdentityResolver.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreCheckoutRecovery-' + [Guid]::NewGuid().ToString('N'))
$executable = Join-Path $tempRoot 'CheckoutFailureRecoveryHarness.exe'

function Read-RepoFile([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $path)
    }
    return [IO.File]::ReadAllText($path)
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw ('CHECKOUT_FAILURE_RECOVERY_SOURCE_FAILED=' + $code) }
    Write-Output ('PASS SOURCE_' + $code)
}

function Get-VbMethod([string]$source, [string]$signature) {
    $pattern = '(?is)' + [regex]::Escape($signature) + '[\s\S]*?\r?\n\s*End (?:Function|Sub)'
    return [regex]::Match($source, $pattern).Value
}

foreach ($required in @($compiler, $harnessPath, $logicalResolverPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw ('REQUIRED_FILE_MISSING=' + $required)
    }
}

$recovery = Read-RepoFile 'App_Code\CheckoutFailureRecoveryService.vb'
$dispatcher = Read-RepoFile 'App_Code\CheckoutTerminalOutcomeDispatcher.vb'
$durable = Read-RepoFile 'App_Code\OrderDurableIdempotencyService.vb'
$logicalResolver = Read-RepoFile 'App_Code\OrderLogicalIdentityResolver.vb'
$orderContext = Read-RepoFile 'App_Code\OrderStorefrontContext.vb'
$cart = Read-RepoFile 'carrello.aspx.vb'
$cartMarkup = Read-RepoFile 'carrello.aspx'
$order = Read-RepoFile 'ordine.aspx.vb'
$readModel = Read-RepoFile 'App_Code\CartAuthoritativeReadModel.vb'
$miniCart = Read-RepoFile 'Public\ui\controls\MiniCart.ascx.vb'
$master = Read-RepoFile 'Page.master.vb'

$verifyAccount = Get-VbMethod $orderContext 'Public Shared Function VerifyAccount'
$loginOwnership = Get-VbMethod $durable 'Private Shared Function IsLoginOwnedByCompany'
$retireAndDispatch = Get-VbMethod $recovery 'Public Shared Function RetireAndDispatch'
$consumeFailure = Get-VbMethod $recovery 'Public Shared Function TryConsumeFailure'
$recordRetry = Get-VbMethod $durable 'Public Shared Function RecordRetryRequired'
$generateToken = Get-VbMethod $cart 'Private Function GenerateCheckoutToken'
$showFailure = Get-VbMethod $cart 'Private Sub ShowCheckoutFailureFromSession'

Assert-Source (
    $verifyAccount -match '(?i)SELECT\s+DISTINCT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $verifyAccount -notmatch '(?i)SELECT\s+COUNT\s*\('
) '01_VERIFY_ACCOUNT_COLLAPSES_IDENTICAL_PHYSICAL_ROWS'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($loginOwnership) -and
    $loginOwnership.Contains('OrderLogicalIdentityResolver.TryResolve') -and
    $loginOwnership -match '(?i)SELECT\s+utentiid\s*,\s*COALESCE\s*\(\s*listino\s*,\s*0\s*\)' -and
    $loginOwnership -notmatch '(?i)SELECT\s+COUNT\s*\(' -and
    $logicalResolver.Contains('row.UserId <= 0 OrElse row.PriceListId <= 0') -and
    $logicalResolver.Contains('row.UserId <> userId OrElse row.PriceListId <> priceListId')
) '02_IDEMPOTENCY_OWNER_CHECK_USES_LOGICAL_IDENTITY'

Assert-Source (
    $recovery.Contains('Public Shared Function RetireAndDispatch') -and
    $recovery.Contains('Public Shared Sub RetireRequest') -and
    $recovery.Contains('Public Shared Function IsRetiredRequest') -and
    $recovery.Contains('Public Shared Function TryConsumeFailure') -and
    $recovery.Contains('Public Shared Sub TracePhase') -and
    $recovery.Contains('Public Shared Function GetCorrelationId')
) '03_RECOVERY_SERVICE_EXPOSES_REQUIRED_CONTROL_FLOW'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($retireAndDispatch) -and
    $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -ge 0 -and
    $retireAndDispatch.IndexOf('CheckoutTerminalOutcome.CheckoutFailure', [StringComparison]::Ordinal) -gt
        $retireAndDispatch.IndexOf('RetireRequest', [StringComparison]::Ordinal) -and
    $retireAndDispatch -match '(?i)Session'
) '04_FAILURE_RETIRES_THEN_STORES_SERVER_SIDE_AND_DISPATCHES'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($consumeFailure) -and
    $consumeFailure -match '(?i)Session' -and
    $consumeFailure -match '(?i)Remove|Nothing' -and
    $consumeFailure -notmatch '(?i)Request\.QueryString'
) '05_FAILURE_MESSAGE_IS_ONE_TIME_AND_NOT_QUERY_CONTROLLED'

Assert-Source (
    $dispatcher.Contains('CheckoutFailure') -and
    $dispatcher.Contains('carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError') -and
    $cartMarkup.Contains('ID="pnlCheckoutSubmitError"') -and
    $dispatcher.Contains('response.StatusCode = 303') -and
    $dispatcher.Contains('context.ApplicationInstance.CompleteRequest()')
) '06_FAILURE_OUTCOME_USES_TERMINAL_HTTP_303_PRG'

Assert-Source (
    $cart.Contains('CheckoutFailureRecoveryService.TryConsumeFailure') -and
    $cart.Contains('CheckoutFailureRecoveryService.RetireAndDispatch') -and
    $cart.Contains('CheckoutFailureRecoveryService.IsRetiredRequest') -and
    $cart.Contains('EnsureCheckoutRequestId()') -and
    $order.Contains('CheckoutFailureRecoveryService.IsRetiredRequest')
) '07_CART_CONSUMES_FLASH_ROTATES_REQUEST_AND_BLOCKS_RETIRED'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($recordRetry) -and
    $recordRetry.Contains('RetryRequiredState') -and
    $order.Contains('OrderDurableIdempotencyService.RecordRetryRequired') -and
    $order.Contains('CheckoutFailureRecoveryService.RetireAndDispatch')
) '08_POSTCLAIM_FAILURE_RECORDS_RETRY_BEFORE_RECOVERY'

$procedureIndex = $order.IndexOf('Carrello_Documento', [StringComparison]::Ordinal)
$completeIndex = $order.IndexOf('OrderDurableIdempotencyService.Complete(', $procedureIndex, [StringComparison]::Ordinal)
$commitIndex = $order.IndexOf('trns.Commit()', $completeIndex, [StringComparison]::Ordinal)
$emailIndex = $order.IndexOf('SendEmail(', $commitIndex, [StringComparison]::Ordinal)
Assert-Source (
    $procedureIndex -ge 0 -and $completeIndex -gt $procedureIndex -and
    $commitIndex -gt $completeIndex -and $emailIndex -gt $commitIndex
) '09_PROCEDURE_COMPLETE_COMMIT_EMAIL_ORDERING'

Assert-Source (
    $cart.Contains('Case "cvCheckoutShippingMethod"') -and
    $cart.Contains('Case "cvCheckoutPaymentMethod"') -and
    $cart.Contains('Seleziona un metodo di spedizione') -and
    $cart.Contains('Seleziona un metodo di pagamento')
) '10_SHIPPING_AND_PAYMENT_FAIL_BEFORE_DISPATCH'

Assert-Source (
    $order.Contains('record.AziendaId') -or
    ($order.Contains('receiptAziendaId') -and $order.Contains('LoadOrderEmailBrandData'))
) '11_EMAIL_BRANDING_USES_PERSISTED_COMPANY'

Assert-Source (
    $cartMarkup.Contains('TypeName="CartAuthoritativeReadDataSource" SelectMethod="SelectStandardItems"') -and
    $miniCart.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $master.Contains('CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)') -and
    $readModel.Contains('KeepStore:CartAuthoritativeReadModel:Current')
) '12_CART_PAGE_MINICART_HEADER_SHARE_READ_MODEL'

$catchIndex = $order.IndexOf('Catch ex As Exception', $commitIndex, [StringComparison]::Ordinal)
$postCommitIndex = $order.IndexOf('If commitCompleted Then', $catchIndex, [StringComparison]::Ordinal)
$inventoryCatchIndex = $order.IndexOf('FindInventoryAvailabilityException(ex)', $catchIndex, [StringComparison]::Ordinal)
Assert-Source (
    $catchIndex -ge 0 -and $postCommitIndex -gt $catchIndex -and
    $inventoryCatchIndex -gt $postCommitIndex -and
    $order.Contains('CheckoutFailureRecoveryService.RetireRequest(HttpContext.Current, checkoutRequestId)') -and
    ([regex]::Matches($order, 'OrderDurableIdempotencyService\.RecordRetryRequired\s*\(').Count -ge 3)
) '13_POSTCOMMIT_FIRST_AND_FAILED_REQUESTS_RETIRED_DURABLY'

Assert-Source (
    $order.Contains('If Vettore <= 0 Then') -and
    $order.Contains('CheckoutFailureReason.ShippingMethodMissing') -and
    $order.Contains('If Pagamento <= 0 Then') -and
    $order.Contains('CheckoutFailureReason.PaymentMethodMissing') -and
    $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal) -lt
        $order.IndexOf('If Vettore <= 0 Then', [StringComparison]::Ordinal)
) '14_ORDER_SIDE_SELECTIONS_FAIL_SPECIFIC_BEFORE_CLAIM'

Assert-Source (
    $order.Contains('checkoutRequestId, "08-storefront-context", "resolved"') -and
    -not $order.Contains('String.Empty, "08-storefront-context", "resolved"') -and
    -not [string]::IsNullOrWhiteSpace($generateToken) -and
    $generateToken.Contains('normalizedRequestId, "08-storefront-context", "resolved"') -and
    -not $generateToken.Contains('ViewState(CHECKOUT_REQUEST_VIEWSTATE_KEY), CultureInfo.InvariantCulture),' + [Environment]::NewLine + '        "08-storefront-context"')
) '15_TRACE_USES_ONE_REQUEST_CORRELATION'

Assert-Source (
    -not [string]::IsNullOrWhiteSpace($showFailure) -and
    $showFailure.Contains('SetCheckoutStep("checkout")') -and
    $showFailure.Contains('tOrdine.Visible = True') -and
    $showFailure.Contains('ShowCheckoutSubmitError(failure.Message, False)') -and
    $order.Contains('CheckoutFailureReason.ShippingAddressInvalid') -and
    $order.Contains('CheckoutFailureReason.OrderNotesInvalid') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.AddressError)') -and
    -not $order.Contains('CheckoutTerminalOutcomeDispatcher.Dispatch(HttpContext.Current, CheckoutTerminalOutcome.NotesError)')
) '16_CORRECTION_FAILURE_REOPENS_CHECKOUT_CONTROLS'

$firstLoginRequired = $order.IndexOf('CheckoutTerminalOutcome.LoginRequired', [StringComparison]::Ordinal)
$secondLoginRequired = $order.IndexOf(
    'CheckoutTerminalOutcome.LoginRequired',
    $firstLoginRequired + 1,
    [StringComparison]::Ordinal)
$firstExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $firstLoginRequired,
    [StringComparison]::Ordinal)
$secondExtract = $order.LastIndexOf(
    'TryExtractCheckoutRequestIdForRetirement',
    $secondLoginRequired,
    [StringComparison]::Ordinal)
Assert-Source (
    $order.Contains('Private Function TryExtractCheckoutRequestIdForRetirement') -and
    $firstLoginRequired -ge 0 -and $secondLoginRequired -gt $firstLoginRequired -and
    $firstExtract -ge 0 -and $firstExtract -lt $firstLoginRequired -and
    $secondExtract -gt $firstLoginRequired -and $secondExtract -lt $secondLoginRequired -and
    ([regex]::Matches($order, 'RetireRequest\(HttpContext\.Current,\s*(?:expiredRequestId|invalidIdentityRequestId)\)').Count -eq 2)
) '17_LOGIN_TIMEOUT_AND_PARTIAL_IDENTITY_RETIRE_OLD_REQUEST'

$completedLookupIndex = $order.IndexOf('Dim completedBeforeWork As OrderDurableIdempotencyRecord', [StringComparison]::Ordinal)
$notesValidationIndex = $order.IndexOf('If OrderNotesAreTooLong(Note) Then', [StringComparison]::Ordinal)
$claimIndex = $order.IndexOf('OrderDurableIdempotencyService.TryClaim(', [StringComparison]::Ordinal)
Assert-Source (
    $completedLookupIndex -ge 0 -and
    $notesValidationIndex -gt $completedLookupIndex -and
    $claimIndex -gt $notesValidationIndex
) '18_COMPLETED_REPLAY_PRECEDES_SESSION_VALIDATION_AND_NEW_CLAIM'

Assert-Source (
    -not $recovery.Contains('MaxRetiredRequestIds') -and
    -not $recovery.Contains('RemoveAt(0)') -and
    $recovery.Contains('ids.Add(normalized)')
) '19_RETIRED_REQUESTS_ARE_NOT_REACTIVATED_BY_EVICTION'

$invalidTokenBranch = Get-VbMethod $order 'Private Function TryExtractCheckoutRequestIdForRetirement'
Assert-Source (
    -not [string]::IsNullOrWhiteSpace($invalidTokenBranch) -and
    $invalidTokenBranch.Contains('MachineKey.Unprotect') -and
    $invalidTokenBranch.Contains('parts.Length <> 8') -and
    $invalidTokenBranch.Contains('"v4"') -and
    $order.Contains('RetireRequest(HttpContext.Current, invalidTokenRequestId)')
) '20_INVALID_AUTHENTIC_TOKEN_IS_RETIRED_BEFORE_CART_REVIEW'

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" $logicalResolverPath $harnessPath
    if ($LASTEXITCODE -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_COMPILE_FAILED' }

    $harnessOutput = @(& $executable 2>&1 | ForEach-Object { $_.ToString() })
    $harnessExit = $LASTEXITCODE
    $harnessOutput | Write-Output
    if ($harnessExit -ne 0) { throw 'CHECKOUT_FAILURE_RECOVERY_HARNESS_FAILED' }

    $scenarioPasses = @($harnessOutput | Where-Object { $_ -match '^PASS\s+\d{2}_' })
    if ($scenarioPasses.Count -ne 20) {
        throw ('CHECKOUT_FAILURE_RECOVERY_EXPECTED_20_SCENARIOS_ACTUAL_' + $scenarioPasses.Count)
    }
    if (@($harnessOutput | Where-Object { $_ -match '^FAIL\s+' }).Count -ne 0) {
        throw 'CHECKOUT_FAILURE_RECOVERY_REPORTED_FAILURE'
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'UNSAFE_TEMP_CLEANUP_PATH'
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS CHECKOUT_FAILURE_RECOVERY_20_COMPILED_SCENARIOS'
