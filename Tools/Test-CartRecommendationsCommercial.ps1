[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'REQUIRES_WINDOWS_POWERSHELL_51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path $EvidenceDirectory)){throw 'NEW_TEMP_EVIDENCE_DIRECTORY_REQUIRED'}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
function Check($name,[bool]$ok){$checks.Add(@{Name=$name;Pass=$ok});if(!$ok){throw ('CART_RECOMMENDATIONS_ASSERT: '+$name)}}
function Json($name,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 16),$utf8)}
function Methods($source){$m=@{};foreach($hit in [regex]::Matches($source,'(?ms)^[ \t]*(?:Private|Public|Protected) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^[ \t]*End (?:Function|Sub)')){$m[$hit.Groups[1].Value]=$hit.Value};return $m}
$source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'carrello.aspx.vb'))
$map=Methods $source
$baseline=(git -C $RepositoryRoot show 'f3703ed9266843673bf3ef613c0de3299fa1c0aa:carrello.aspx.vb') -join "`n"
if($LASTEXITCODE -ne 0){throw 'BASE_UNAVAILABLE'}
$old=Methods $baseline
$changed=@('CartRecommendationImage','CartRecommendationPrice','CartRecommendationSelectFields','CartRecommendationStockWhere','LoadCartRecentlyViewedProducts','LoadCartFallbackRecommendations','LoadCatalogFallbackRecommendations','LoadCartRecommendations','RenderCartRecommendationCard','RenderCartRecommendationsSection','BindCartRecentlyViewed')
$added=@('CartRecommendationGrossSql','LoadCartRecommendationPool','CreateCartRecommendationPromotionBatch','PrepareCartRecommendationRows')
foreach($n in $old.Keys){if($changed -notcontains $n){Check ('unchanged method '+$n) (($map[$n] -replace '\s+',' ').Trim() -ceq ($old[$n] -replace '\s+',' ').Trim())}}
Check 'only recommendation methods added' (@($map.Keys|Where-Object{!$old.ContainsKey($_) -and $added -notcontains $_}).Count -eq 0)
Check 'cart markup unchanged' ((git -C $RepositoryRoot hash-object carrello.aspx) -eq (git -C $RepositoryRoot rev-parse f3703ed9266843673bf3ef613c0de3299fa1c0aa:carrello.aspx))
Check 'no HOME Vetrina predicate in recommendation pool' ($map.LoadCartRecommendationPool -notmatch 'Vetrina')
Check 'price rendering and dedup perform no database work' (($map.CartRecommendationPrice+$map.CartRecommendationKey+$map.RenderCartRecommendationCard) -notmatch 'MySql|BuildForProduct|ConnectionStrings')

Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
$names=@($map.Keys|Where-Object{$_ -match '^(CartRecommendation|LoadCartRecommendation|LoadCartRecentlyViewedProducts|LoadCartFallbackRecommendations|LoadCatalogFallbackRecommendations|RenderCartRecommendation|BindCartRecentlyViewed|PrepareCartRecommendationRows|CreateCartRecommendationPromotionBatch|GetCartArticleIds|AddCartArticleIdsFromRepeater|GetCartRecentlyViewedIds|MergeCartRecentIds|SafeInt$|SafeDbl$|SafeIntFromText|SafeDblFromText|ParseDecimalForDb|NormalizeDecimalForDb|JoinAllButLast|NormalizeMoneyText|NormalizeSingleDecimalSeparator|IsCheckoutStepVisible|IsCartEmptyState)'})
$bodies=foreach($n in $names){
    if($n -eq 'LoadCartRecommendationPool'){
        $body=$map[$n];$boundary=$body.IndexOf('        Using conn As New MySqlConnection')
        if($boundary -lt 0){throw 'SQL_IO_BOUNDARY_MISSING'}
        $body.Substring(0,$boundary)+@'
        LastSql=sql
        SqlReads+=1
        If CaptureOnly Then Return Nothing
        Dim pool As String=If(recentOrder,"recent",If(filter="1=1","catalog","related"))
        Return If(Pools.ContainsKey(pool),Pools(pool),Nothing)
    End Function
'@
    }elseif($n -eq 'CreateCartRecommendationPromotionBatch'){@'
    Private Function CreateCartRecommendationPromotionBatch(priceContext As StorefrontPriceDisplayContext) As IProductPromotionEligibilityBatch
        BatchReads+=1
        Dim context=ProductPromotionEligibilityResolver.CreateContext(HttpContext.Current,priceContext.CompanyId,priceContext.PriceListId,0)
        Dim snapshot As New ProductPromotionEligibilitySnapshot()
        For Each offer As ProductPromotionEligibilityRawOffer In Offers
            If Not ProductPromotionEligibilityResolver.IsOwnerAuthorized(offer.OwnerUserId,context) Then Continue For
            If Not snapshot.OffersByArticle.ContainsKey(offer.ArticleId) Then snapshot.OffersByArticle(offer.ArticleId)=New List(Of ProductPromotionEligibilityRawOffer)()
            snapshot.OffersByArticle(offer.ArticleId).Add(offer)
        Next
        Return New ProductPromotionEligibilityBatch(context,snapshot)
    End Function
'@
    }else{$map[$n]}
}
$wrapper=@'
Imports System
Imports System.Data
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI
Imports System.Web.UI.WebControls
Public Class ArticleTemplate
    Implements ITemplate
    Public Sub InstantiateIn(container As Control) Implements ITemplate.InstantiateIn
        Dim box As New TextBox() With {.ID="tbArtID"}
        AddHandler box.DataBinding, Sub(sender,eventArgs)
            Dim item=DirectCast(box.NamingContainer,RepeaterItem)
            box.Text=Convert.ToString(DirectCast(item.DataItem,DataRowView)("id"))
        End Sub
        container.Controls.Add(box)
    End Sub
End Class
Public Class CartFixture
    Private Shared ReadOnly CartCulture As CultureInfo=CultureInfo.GetCultureInfo("it-IT")
    Private Const SessCheckoutStep As String="CartCheckoutStep"
    Private _cartHasItems As Boolean=True
    Public tOrdine As New Panel()
    Public Repeater1 As New Repeater()
    Public gvArticoliGratis As New Repeater()
    Public RecommendedProductsPanel As New PlaceHolder()
    Public RecommendedProductsHtml As New Literal()
    Public Pools As New Dictionary(Of String,DataTable)()
    Private Offers As New List(Of ProductPromotionEligibilityRawOffer)()
    Public LastSql As String
    Public SqlReads As Integer
    Public BatchReads As Integer
    Public CaptureOnly As Boolean
    Public ReadOnly Property Session As HttpSessionState
        Get
            Return HttpContext.Current.Session
        End Get
    End Property
    Public ReadOnly Property Request As HttpRequest
        Get
            Return HttpContext.Current.Request
        End Get
    End Property
    Public Sub Configure(company As Integer,listino As Integer,authenticated As Boolean,included As Boolean,rate As Decimal,rc As Boolean)
        Dim context As New HttpContext(New HttpRequest("","http://fixture.invalid/carrello.aspx",""),New HttpResponse(New IO.StringWriter()))
        Dim state As New HttpSessionStateContainer("synthetic",New SessionStateItemCollection(),New HttpStaticObjectsCollection(),20,True,HttpCookieMode.UseCookies,SessionStateMode.InProc,False)
        SessionStateUtility.AddHttpSessionStateToContext(context,state)
        HttpContext.Current=context
        context.Items("ks_product_placeholder_exists")=True
        Session("Listino")=listino : Session("AziendaID")=company
        Session("AuthenticatedAziendaID")=If(authenticated,company,0)
        Session("LoginID")=If(authenticated,42,0) : Session("UtentiId")=If(authenticated,42,0)
        Session("IvaTipo")=If(included,2,1) : Session("Iva_Utente")=rate
        Session("AbilitatoIvaReverseCharge")=If(rc,1,0)
        StorefrontPriceDisplayContextProvider.SetTenantDefaults(context,company,listino,If(included,2,1))
        Session("ks_recent_ids")="1,2,3,4,5,6,7,8,9,10,100,200"
        Dim rows As New DataTable() : rows.Columns.Add("id",GetType(Integer)) : rows.Rows.Add(900)
        Repeater1.ItemTemplate=New ArticleTemplate() : Repeater1.DataSource=rows : Repeater1.DataBind()
        tOrdine.Visible=False : SqlReads=0 : BatchReads=0 : CaptureOnly=False : Pools.Clear() : Offers.Clear()
    End Sub
    Public Function Sql(pool As String) As String
        CaptureOnly=True
        Select Case pool
            Case "recent" : LoadCartRecentlyViewedProducts(8,GetCartArticleIds())
            Case "related" : LoadCartFallbackRecommendations(8,GetCartArticleIds())
            Case "catalog" : LoadCatalogFallbackRecommendations(8,GetCartArticleIds())
        End Select
        CaptureOnly=False
        Return LastSql
    End Function
    Public Function Run(stepName As String,hasItems As Boolean) As String
        tOrdine.Visible=stepName<>"cart" : Session(SessCheckoutStep)=stepName
        _cartHasItems=hasItems
        BindCartRecentlyViewed()
        Return RecommendedProductsHtml.Text
    End Function
    Public Sub Offer(article As Integer,tc As Integer,minimum As Decimal,owner As Integer,price As Decimal)
        Offers.Add(New ProductPromotionEligibilityRawOffer() With {.ArticleId=article,.OfferId=1,.OfferDetailId=article,.TargetTCId=tc,.QntMinima=minimum,.Multipli=0D,.OwnerUserId=owner,.PromoPriceNet=price,.StartsOn=Date.Today.AddDays(-1),.EndsOn=Date.Today.AddDays(1)})
    End Sub
__METHODS__
End Class
Public Module KeepStoreLog
    Public Sub [Error](component As String,message As String,ex As Exception,ctx As HttpContext)
        If ex IsNot Nothing Then Console.Error.WriteLine(ex.ToString())
    End Sub
End Module
Public Module CartTransactionRetryPolicy
    Public Function GetMySqlErrorNumber(ex As Exception) As Integer
        Return -1
    End Function
End Module
Public Module StorefrontSeoTenantContext
    Public Function ConfiguredDatabaseScopeKey() As String
        Return "synthetic-only"
    End Function
End Module
'@
$code=$wrapper.Replace('__METHODS__',($bodies -join "`r`n"))
$shared=@('StorefrontPriceDisplayContext.vb','StorefrontPriceDisplayContextProvider.vb','StorefrontEffectivePriceSqlBuilder.vb','StorefrontCommercialIsolationPolicy.vb','ProductPromotionEligibilityResolver.vb','ProductPromotionDisplayHelper.vb','ThemeManager.vb','UiPriceFormatter.vb','UiData.vb')|ForEach-Object{[IO.File]::ReadAllText((Join-Path $RepositoryRoot ('App_Code/'+$_)))}
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
try{
    $options=New-Object CodeDom.Compiler.CompilerParameters
    $options.GenerateInMemory=$true;$options.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll',(Join-Path $RepositoryRoot 'Bin/MySql.Data.dll'))|ForEach-Object{[void]$options.ReferencedAssemblies.Add($_)}
    $compiled=$compiler.CompileAssemblyFromSource($options,[string[]](@($code)+$shared))
    if($compiled.Errors.HasErrors){throw (($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{'line '+$_.Line+': '+$_.ErrorText}) -join '; ')}
    $cart=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('CartFixture'))
    $queries=@()
    foreach($tenant in @(@{Name='Tech';Company=1;Listino=1},@{Name='Food';Company=2;Listino=10})){
        foreach($mode in @(@{Name='included';Included=$true;Rate=-1;Rc=$false},@{Name='excluded';Included=$false;Rate=-1;Rc=$false},@{Name='override';Included=$true;Rate=10;Rc=$false},@{Name='reverse';Included=$true;Rate=10;Rc=$true})){
            $cart.Configure($tenant.Company,$tenant.Listino,$true,$mode.Included,$mode.Rate,$mode.Rc)
            $queries+=@{Name=($tenant.Name+'-'+$mode.Name);Tenant=$tenant;Mode=$mode;Recent=$cart.Sql('recent');Related=$cart.Sql('related');Catalog=$cart.Sql('catalog')}
        }
    }
    Json 'queries.json' $queries
    $sql=@'
const fs=require('node:fs'),path=require('node:path'),{DatabaseSync}=require('node:sqlite');
const dir=process.argv[2],queries=JSON.parse(fs.readFileSync(path.join(dir,'queries.json'),'utf8')),checks=[],fixtures=[];
function check(Name,Pass){checks.push({Name,Pass:!!Pass});if(!Pass)throw Error(Name)}
const db=new DatabaseSync(':memory:');db.function('GREATEST',(a,b)=>Math.max(a,b));
const columns={id:'INTEGER',TCid:'INTEGER',NListino:'INTEGER',Codice:'TEXT',Descrizione1:'TEXT',Descrizione2:'TEXT',MarcheDescrizione:'TEXT',CategorieDescrizione:'TEXT',Img1:'TEXT',Prezzo:'NUMERIC',PrezzoIvato:'NUMERIC',PrezzoPromo:'NUMERIC',PrezzoPromoIvato:'NUMERIC',IdIvaRC:'INTEGER',ValoreIvaRC:'NUMERIC',InOfferta:'INTEGER',visite:'INTEGER',Export:'INTEGER',Vetrina:'INTEGER',CategorieId:'INTEGER',TipologieId:'INTEGER',MarcheId:'INTEGER',SettoriId:'INTEGER',Giacenza:'NUMERIC',Disponibilita:'NUMERIC',Impegnata:'NUMERIC'};
db.exec('CREATE TABLE vsuperarticoli('+Object.entries(columns).map(([n,t])=>n+' '+t).join(',')+');CREATE TABLE articoli(id INTEGER PRIMARY KEY,Abilitato INTEGER);CREATE TABLE articoli_tagliecolori(id INTEGER,ArticoliId INTEGER);CREATE TABLE articoli_giacenze(ArticoliId INTEGER,TCId INTEGER,MagazziniId INTEGER,Giacenza NUMERIC,Impegnata NUMERIC)');
const insert=db.prepare('INSERT INTO vsuperarticoli VALUES('+Object.keys(columns).map(()=>'?').join(',')+')'),stock=db.prepare('INSERT INTO articoli_giacenze VALUES(?,?,?,?,?)');
let listino=1,sector='Tech';
function product(id,over={},inventory=true,wh=1,enabled=1,validTc=true){const r={id,TCid:-1,NListino:listino,Codice:sector+'-'+id,Descrizione1:sector==='Tech'?'Computer professionale con descrizione lunga e dettagli della variante':'Prodotto alimentare con descrizione lunga e dettagli del formato',Descrizione2:'',MarcheDescrizione:sector,CategorieDescrizione:'Catalogo',Img1:null,Prezzo:10,PrezzoIvato:12.2,IdIvaRC:1,ValoreIvaRC:0,InOfferta:0,visite:0,Export:1,Vetrina:0,CategorieId:1,TipologieId:1,MarcheId:1,SettoriId:1,Giacenza:10,Disponibilita:999,Impegnata:0,...over};r.Descrizione1+=' '+id;db.prepare('INSERT OR IGNORE INTO articoli VALUES(?,?)').run(id,enabled);insert.run(...Object.keys(columns).map(c=>r[c]??null));if(inventory)stock.run(id,r.TCid,wh,r.Giacenza,r.Impegnata);if(r.TCid>0&&validTc)db.prepare('INSERT INTO articoli_tagliecolori VALUES(?,?)').run(r.TCid,id)}
function reset(){db.exec('DELETE FROM vsuperarticoli;DELETE FROM articoli;DELETE FROM articoli_tagliecolori;DELETE FROM articoli_giacenze')}
for(const q of queries){listino=q.Tenant.Listino;sector=q.Tenant.Name;const m=q.Mode,params={listino,ksRcEnabled:+m.Rc,ksHasVatOverride:+(m.Rate>=0),ksVatOverride:Math.max(0,m.Rate)};
 const run=(sql=q.Catalog)=>db.prepare(sql).all(Object.fromEntries([...new Set(sql.match(/@\w+/g))].map(p=>[p.slice(1),params[p.slice(1)]])));
 for(const [label,over,inventory,wh,enabled,valid] of [
 ['reserved',{Giacenza:2,Impegnata:2}],['fractional',{Giacenza:1,Impegnata:.1}],['foreign variant',{TCid:2,Giacenza:0}],['wrong warehouse',{},true,2],['missing stock',{},false],['disabled',{},true,1,0],['not published',{Export:0}],['null publication',{Export:null}],['foreign listino',{NListino:99}],['invalid TCId',{TCid:0}],['orphan variant',{TCid:3},true,1,1,false],['promo only',{Prezzo:0,PrezzoIvato:0,PrezzoPromo:5,PrezzoPromoIvato:6.1}],['selected price missing',m.Included&&m.Rate<0?{PrezzoIvato:0}:{Prezzo:0}]
 ]){reset();product(1,over,inventory,wh,enabled,valid);check(q.Name+' excludes '+label,run().length===0)}
 reset();product(1);stock.run(1,-1,1,10,0);check(q.Name+' duplicate stock fails closed',run().length===0);
 reset();product(1,{TCid:2,Giacenza:0});stock.run(1,3,1,20,0);check(q.Name+' sibling variant stock cannot qualify',run().length===0);
 reset();product(900);for(let id=1;id<=12;id++)product(id);product(100,{TCid:1,...(m.Included&&m.Rate<0?{PrezzoIvato:0}:{Prezzo:0})});product(100,{TCid:2});product(200,{Prezzo:0,PrezzoIvato:0,PrezzoPromo:8});
 const rows=run();check(q.Name+' eight unique valid slots',rows.length===8&&new Set(rows.map(r=>r.id)).size===8&&!rows.some(r=>r.id===900||r.id===200));check(q.Name+' eligible later variant',rows[0].id===100&&rows[0].TCid===2);check(q.Name+' positive selected prices',rows.every(r=>(m.Included?r.PrezzoIvato:r.Prezzo)>0));check(q.Name+' Vetrina is not required',rows.length===8);check(q.Name+' fiscal authority',Math.abs(rows[0].PrezzoIvato-(m.Rc?10:m.Rate>=0?11:12.2))<1e-8);
 check(q.Name+' recent order preserved',run(q.Recent)[0]?.id===1);check(q.Name+' related remains relevant and excludes cart',run(q.Related).length===8&&!run(q.Related).some(r=>r.id===900));
 fixtures.push({...q,rows});
}
fs.writeFileSync(path.join(dir,'sql-report.json'),JSON.stringify({Result:'PASS',Checks:checks.length,ChecksDetail:checks,Backend:'SQLite synthetic executing actual VB-emitted SQL; not MySQL'},null,2));fs.writeFileSync(path.join(dir,'fixtures.json'),JSON.stringify(fixtures,null,2));
'@
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$sql,$utf8)
    & node (Join-Path $EvidenceDirectory 'sql-fixture.cjs') $EvidenceDirectory
    if($LASTEXITCODE -ne 0){throw 'SQL_FIXTURE_FAILED'}
    $sqlReport=Get-Content (Join-Path $EvidenceDirectory 'sql-report.json') -Raw|ConvertFrom-Json
    foreach($c in $sqlReport.ChecksDetail){Check $c.Name $c.Pass}
    function Rows($items){$t=New-Object Data.DataTable;foreach($p in $items[0].PSObject.Properties){[void]$t.Columns.Add($p.Name,$(if($p.Value -is [string]){[string]}elseif($p.Name -eq 'Img1'){[string]}else{[decimal]}))};foreach($item in $items){$r=$t.NewRow();foreach($p in $item.PSObject.Properties){if($null -ne $p.Value){$r[$p.Name]=$p.Value}};$t.Rows.Add($r)};return ,$t}
    $fixtures=Get-Content (Join-Path $EvidenceDirectory 'fixtures.json') -Raw|ConvertFrom-Json
    $browser=New-Object 'Collections.Generic.List[object]'
    foreach($f in $fixtures){
        $cart.Configure($f.Tenant.Company,$f.Tenant.Listino,$true,$f.Mode.Included,$f.Mode.Rate,$f.Mode.Rc)
        $t=Rows @($f.rows);$cart.Pools['recent']=$t
        $html=$cart.Run('cart',$true)
        Check ($f.Name+' eight priced cards') (([regex]::Matches($html,'<article ').Count -eq 8) -and ([regex]::Matches($html,'ks-rv-price').Count -eq 8))
        Check ($f.Name+' no buy action; exact TCId PDP') ($html -notmatch 'cart_add|Acquista' -and $html -match 'id=100&amp;TCid=2')
        Check ($f.Name+' approved placeholder retained') ($html -match 'placeholder.svg')
        Check ($f.Name+' one pool and one promotion batch') ($cart.SqlReads -eq 1 -and $cart.BatchReads -eq 1)
        foreach($step in @('checkout','confirm')){$reads=$cart.SqlReads;$batch=$cart.BatchReads;Check ($f.Name+' '+$step+' no HTML or I/O') (($cart.Run($step,$true)) -eq '' -and $cart.SqlReads -eq $reads -and $cart.BatchReads -eq $batch -and !$cart.RecommendedProductsPanel.Visible)}
        if($f.Mode.Name -eq 'included'){$browser.Add(@{Name=$f.Tenant.Name;Html=$html})}
        # A nonempty but unusable recent pool must not suppress the next pool.
        $cart.Configure($f.Tenant.Company,$f.Tenant.Listino,$true,$f.Mode.Included,$f.Mode.Rate,$f.Mode.Rc)
        $invalid=$t.Copy();foreach($r in $invalid.Rows){$r.Prezzo=0;$r.PrezzoIvato=0}
        $cart.Pools['recent']=$invalid;$cart.Pools['related']=$t.Copy()
        Check ($f.Name+' unusable recent falls to related') ($cart.Run('cart',$true) -match 'Potrebbe interessarti anche' -and $cart.SqlReads -eq 2)
        $cart.Configure($f.Tenant.Company,$f.Tenant.Listino,$true,$f.Mode.Included,$f.Mode.Rate,$f.Mode.Rc)
        $cart.Pools['related']=$invalid;$cart.Pools['catalog']=$t.Copy()
        Check ($f.Name+' unusable related falls to catalog') ($cart.Run('cart',$true) -match 'ks-rv-card' -and $cart.SqlReads -eq 3)
        $cart.Configure($f.Tenant.Company,$f.Tenant.Listino,$true,$f.Mode.Included,$f.Mode.Rate,$f.Mode.Rc)
        Check ($f.Name+' empty cart no I/O') ($cart.Run('cart',$false) -eq '' -and $cart.SqlReads -eq 0 -and $cart.BatchReads -eq 0)
        # Real promotion helper/resolver over a synthetic authorized snapshot: quantity one only.
        $cart.Configure($f.Tenant.Company,$f.Tenant.Listino,$true,$f.Mode.Included,$f.Mode.Rate,$f.Mode.Rc)
        $one=$t.Clone();$one.ImportRow($t.Rows[0]);$cart.Pools['recent']=$one
        $cart.Offer(100,2,1,42,8);$cart.Offer(100,2,1,99,1);$cart.Offer(100,3,1,42,1);$cart.Offer(100,2,5,42,1)
        $discount=$cart.Run('cart',$true);$expected=if(!$f.Mode.Included -or $f.Mode.Rc){'8,00'}elseif($f.Mode.Rate -ge 0){'8,80'}else{'9,76'}
        Check ($f.Name+' authorized exact variant quantity-one promo') ($discount -match ([regex]::Escape($expected)))
        Check ($f.Name+' renderer I/O bounded after promotion') ($cart.SqlReads -eq 1 -and $cart.BatchReads -eq 1)
    }
    Json 'browser-fixtures.json' $browser
    foreach($tenant in @(@{Company=1;Listino=1},@{Company=2;Listino=10})){
        $cart.Configure($tenant.Company,$tenant.Listino,$false,$true,-1,$false)
        $own=$fixtures|Where-Object{$_.Tenant.Company -eq $tenant.Company -and $_.Mode.Name -eq 'included'}
        $t=Rows @($own.rows);$cart.Pools['recent']=$t
        Check ('anonymous tenant '+$tenant.Company+' renders own request context') ($cart.Run('cart',$true) -match 'ks-rv-price')
        $cart.Configure($tenant.Company,$tenant.Listino,$true,$true,-1,$false)
        $cart.Pools['recent']=$t
        [Web.HttpContext]::Current.Session['AuthenticatedAziendaID']=99
        $provider=$compiled.CompiledAssembly.GetType('StorefrontPriceDisplayContextProvider')
        $provider.GetMethod('Invalidate').Invoke($null,@([Web.HttpContext]::Current))
        Check ('cross-tenant authentication '+$tenant.Company+' fails closed before I/O') ($cart.Run('cart',$true) -eq '' -and $cart.SqlReads -eq 0 -and $cart.BatchReads -eq 0)
    }
    Json 'test-report.json' @{Result='PASS';Checks=$checks.Count;ChecksDetail=$checks;Limits='Real extracted recommendation methods, WebForms controls, fiscal/promotion helpers and resolver; SQLite and database snapshot I/O synthetic; no IIS/MySQL/production';SourceSha256=(Get-FileHash (Join-Path $RepositoryRoot 'carrello.aspx.vb')).Hash}
    Write-Output ('CART_RECOMMENDATIONS '+$checks.Count+'/'+$checks.Count+' PASS')
}finally{$compiler.Dispose()}
