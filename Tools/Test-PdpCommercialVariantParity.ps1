[CmdletBinding()]
param([string]$RepositoryRoot,[Parameter(Mandatory=$true)][string]$EvidenceDirectory,
      [string]$BaselineRef='74d430fe8b2b9243dfb839b1707c783f028d0ece',[switch]$ReproduceBaselineOnly)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'PDP_VARIANT_FRAMEWORK_PS51_REQUIRED'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if(!$EvidenceDirectory.StartsWith($temp+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'PDP_VARIANT_NEW_TEMP_REQUIRED'}
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
function Member($s,$name){$m=[regex]::Match($s,'(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) '+[regex]::Escape($name)+'\b.*?^    End (?:Function|Sub)');if(!$m.Success){throw ('PDP_METHOD_MISSING '+$name)};return $m.Value}
$baseline=(& git -C $RepositoryRoot show ($BaselineRef+':articolo.aspx.vb')) -join "`n"
if($LASTEXITCODE){throw 'PDP_BASELINE_UNAVAILABLE'}
$source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articolo.aspx.vb'))
$idempotency=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartMutationIdempotencyService.vb'))
$catalog=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
$node=@(Get-Command node.exe -CommandType Application -ErrorAction Stop)[0].Source
$runner=@'
const fs=require('fs'),{DatabaseSync}=require('node:sqlite');
const input=JSON.parse(fs.readFileSync(0,'utf8')),db=new DatabaseSync(':memory:');
db.function('CONCAT',(...v)=>v.join(''));db.function('CURDATE',()=> '2026-11-01');db.function('MOD',(a,b)=>b? a%b:null);
db.exec(`CREATE TABLE vsuperarticoli(ID INTEGER,TCid INTEGER,NListino INTEGER,Prezzo REAL,PrezzoIvato REAL,Codice TEXT,
InOfferta INTEGER,OfferteDataInizio TEXT,OfferteDataFine TEXT,OfferteQntMinima REAL,OfferteMultipli REAL,OfferteDettagliId INTEGER,PrezzoPromo REAL,PrezzoPromoIvato REAL);
CREATE TABLE articoli(id INTEGER,Img5 TEXT,Img6 TEXT);
CREATE TABLE articoli_tagliecolori(id INTEGER PRIMARY KEY,ArticoliId INTEGER,ColoreId INTEGER,TagliaId INTEGER,Barcode TEXT);
CREATE TABLE colori(id INTEGER PRIMARY KEY,Descrizione TEXT);CREATE TABLE taglie(id INTEGER PRIMARY KEY,Descrizione TEXT);
INSERT INTO articoli VALUES(1,'',''),(2,'','');
INSERT INTO colori VALUES(1,'Blu'),(2,'Rosso');INSERT INTO taglie VALUES(1,'M'),(2,'L');
INSERT INTO articoli_tagliecolori VALUES(11,1,1,1,'A'),(12,1,2,2,'B'),(13,1,2,2,'NO-LIST'),(21,2,1,1,'OTHER'),(42,1,1,2,'TEN');`);
const insert=db.prepare('INSERT INTO vsuperarticoli VALUES(?,?,?,?,?,?,0,NULL,NULL,0,0,0,0,0)');
for(const [id,tc,list,net] of [[1,-1,1,10],[1,11,1,20],[1,11,1,20],[1,0,10,12],[1,12,10,30],[1,42,10,35],[2,21,1,7],[1,11,77,20]])insert.run(id,tc,list,net,net*1.22,'P'+id+'T'+tc);
if(input.joinModel){
 // Relevant versioned view semantics: TCid comes from stock; price/listino joins by article, not listini.TCid.
 db.exec(`DELETE FROM vsuperarticoli;CREATE TABLE stock(ArticoliId INTEGER,TCid INTEGER);CREATE TABLE listini(ArticoliId INTEGER,NListino INTEGER,TCid INTEGER,Prezzo REAL);
 INSERT INTO stock VALUES(1,-1),(1,11),(1,12),(2,21);INSERT INTO listini VALUES(1,1,-1,10),(1,10,-1,12),(2,10,-1,30);
 INSERT INTO vsuperarticoli SELECT a.id,s.TCid,l.NListino,l.Prezzo,l.Prezzo*1.22,'SYNTHETIC',0,NULL,NULL,0,0,0,0,0
 FROM articoli a LEFT JOIN stock s ON s.ArticoliId=a.id LEFT JOIN listini l ON l.ArticoliId=a.id;`);
}
const params={};for(const [k,v]of Object.entries(input.parameters))params[k.replace(/^@/,'')]=v;
const rows=db.prepare(input.sql).all(params);process.stdout.write(JSON.stringify(rows));db.close();
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'sql-fixture.cjs'),$runner)
$seams=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Diagnostics
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Namespace MySql.Data.MySqlClient
 Public Class MySqlConnection
  Implements IDisposable
  Public Sub New(value As String)
   If value <> "SYNTHETIC_PDP_ONLY" Then Throw New Exception("NETWORK_FORBIDDEN")
  End Sub
  Public Sub Open()
  End Sub
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
 Public Class MySqlCommand
  Implements IDisposable
  Public Sql As String
  Public Parameters As New ParameterBag
  Public Sub New(value As String,connection As MySqlConnection)
   Sql=value
  End Sub
  Public Function ExecuteReader() As MySqlDataReader
   Return New MySqlDataReader(Fixture.Query(Me).CreateDataReader())
  End Function
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
 Public Class MySqlDataReader
  Implements IDisposable
  Private Reader As DataTableReader
  Public Sub New(value As DataTableReader)
   Reader=value
  End Sub
  Public Function Read() As Boolean
   Return Reader.Read()
  End Function
  Public Function GetValue(index As Integer) As Object
   Return Reader.GetValue(index)
  End Function
  Public Sub Dispose() Implements IDisposable.Dispose
   Reader.Dispose()
  End Sub
 End Class
 Public Class ParameterBag
  Public Values As New Dictionary(Of String,Object)
  Public Sub AddWithValue(name As String,value As Object)
   Values.Add(name,value)
  End Sub
 End Class
 Public Class MySqlDataAdapter
  Implements IDisposable
  Private Command As MySqlCommand
  Public Sub New(value As MySqlCommand)
   Command=value
  End Sub
  Public Sub Fill(table As DataTable)
   table.Merge(Fixture.Query(Command))
  End Sub
  Public Sub Dispose() Implements IDisposable.Dispose
  End Sub
 End Class
End Namespace
Public Class RedirectSignal
 Inherits Exception
End Class
Public Class ResponseSeam
 Public StatusCode As Integer=200
 Public TrySkipIisCustomErrors As Boolean
 Public Headers As New Dictionary(Of String,String)
 Public Destination As String
 Public Sub Redirect(url As String,abort As Boolean)
  Destination=url : StatusCode=302
  Throw New RedirectSignal
 End Sub
End Class
Public Module KeepStoreLog
 Public Sub [Error](area As String,message As String,ex As Exception,ctx As HttpContext)
  Fixture.Errors+=1
 End Sub
End Module
Public Module SeoBuilder
 Public Sub AddOrReplaceNameMeta(page As Object,name As String,value As String)
 End Sub
End Module
Public Class BreadcrumbSeam
 Public Sub Bind(items As Object)
 End Sub
End Class
Public Class CatalogTaxonomyContext
 Public Function BreadcrumbItems(name As String,url As String) As Object
  Return Nothing
 End Function
End Class
Public Module UiData
 Public Function Int(item As Object,column As String) As Integer
  Return Convert.ToInt32(DirectCast(item,DataRow)(column),CultureInfo.InvariantCulture)
 End Function
End Module
Public Class CartMutationIdempotencyService
@@INTENT@@
End Class
Public Class PdpFixture
 Private _id,_tcid,_listino As Integer
 Private _tcidPresent,_tcEnabled As Boolean
 Private _pdpCommercialCode As String
 Private _pdpMainCartRequestId As String="SYNTHETIC_REQUEST_ID"
 Public txtQty As New TextBox With {.ID="qty"}
 Public Response As New ResponseSeam
 Public pnlProduct As New Panel With {.Visible=False}
 Public phNotFound As New PlaceHolder
 Public ProductBreadcrumb As New BreadcrumbSeam
 Public Bound As DataRow
 Public Effects As Integer
 Public Host As String="www.taikun.it"
 Public ReadOnly Property Page As Object
  Get
   Return Me
  End Get
 End Property
 Public ReadOnly Property Request As HttpRequest
  Get
   Return HttpContext.Current.Request
  End Get
 End Property
 Public Sub Run(id As Integer,tc As Integer,list As Integer,enabled As Boolean,Optional present As Boolean=True)
  _id=id:_tcid=tc:_listino=list:_tcEnabled=enabled:_tcidPresent=present
  Try
   LoadPage()
  Catch ex As RedirectSignal
  End Try
 End Sub
 Public Function Row(id As Integer,tc As Integer,list As Integer,exact As Boolean) As DataRow
  _listino=list:Return GetProductRow(id,tc,exact)
 End Function
 Public Function Options(id As Integer,list As Integer) As List(Of KeyValuePair(Of Integer,String))
  Return LoadVariantOptions(id,list)
 End Function
 Public Function Canonical() As String
  Return BuildCanonicalUrl()
 End Function
 Public Function CatalogLink(item As Object) As String
  Return CatalogProductUrl(item)
 End Function
 Public Function Action() As String
  Return PdpMainNativeCartAttributes
 End Function
 Public Function GetConnectionString() As String
  Return "SYNTHETIC_PDP_ONLY"
 End Function
 Public Function ResolveUrl(url As String) As String
  Return url.Replace("~/","/shop/")
 End Function
 Public Function MakeAbsoluteUrl(url As String) As String
  Return "https://" & Host & url
 End Function
 Private Sub BindProduct(row As DataRow)
  Bound=row:pnlProduct.Visible=True
@@BIND_IDENTITY@@
 End Sub
 Private Sub IncrementVisitsForSession(row As DataRow)
  Effects+=1
 End Sub
 Private Sub BindProductDetailPreview(row As DataRow)
  Effects+=1
 End Sub
 Private Sub TrackRecentlyViewed(id As Integer)
  Effects+=1
 End Sub
 Private Sub ApplySeo(row As DataRow)
  Effects+=1
 End Sub
 Private Sub BindProductReviews()
  Effects+=1
 End Sub
 Private Sub BindProductRelations(row As DataRow)
  Effects+=1
 End Sub
 Public Function CatalogTcId(item As Object,cart As Boolean) As Integer
  Return Convert.ToInt32(DirectCast(item,DataRow)("TCid"))
 End Function
@@METHODS@@
@@ACTION@@
End Class
Public Module Fixture
 Public NodePath,Runner As String
 Public Errors As Integer
 Public FailReads As Boolean
 Public SuppressExact As Boolean
 Public JoinModel As Boolean
 Public Calls As New List(Of String)
 Public Checks As New List(Of String)
 Public Function Query(cmd As MySqlCommand) As DataTable
  Calls.Add(cmd.Sql)
  If FailReads Then Throw New Exception("SYNTHETIC_READ_FAILURE")
  If SuppressExact AndAlso cmd.Parameters.Values.ContainsKey("@tcid") Then Return New DataTable
  Dim start As New ProcessStartInfo(NodePath,ChrW(34) & Runner & ChrW(34))
  start.UseShellExecute=False:start.CreateNoWindow=True:start.RedirectStandardInput=True:start.RedirectStandardOutput=True:start.RedirectStandardError=True
  Dim json As New JavaScriptSerializer
  Using p As Process=Process.Start(start)
   p.StandardInput.Write(json.Serialize(New With {.sql=cmd.Sql,.parameters=cmd.Parameters.Values,.joinModel=JoinModel})):p.StandardInput.Close()
   Dim output=p.StandardOutput.ReadToEnd(),diagnostic=p.StandardError.ReadToEnd():p.WaitForExit()
   If p.ExitCode<>0 Then Throw New Exception("SQL_FIXTURE_FAILED " & diagnostic)
   Dim values=json.Deserialize(Of List(Of Dictionary(Of String,Object)))(output),table As New DataTable
   If values.Count>0 Then
    For Each key In values(0).Keys
     table.Columns.Add(key,GetType(Object))
    Next
    For Each value In values
     Dim row=table.NewRow()
     For Each key In value.Keys
      row(key)=If(value(key),DBNull.Value)
     Next
     table.Rows.Add(row)
    Next
   End If
   Return table
  End Using
 End Function
 Public Sub Check(name As String,pass As Boolean)
  If Not pass Then Throw New Exception("ASSERT " & name)
  Checks.Add(name)
 End Sub
 Public Function Page(query As String) As PdpFixture
  HttpContext.Current=New HttpContext(New HttpRequest("","https://www.taikun.it/shop/articolo.aspx",query),New HttpResponse(New StringWriter))
  Return New PdpFixture
 End Function
 Public Sub Main(args As String())
  NodePath=args(0):Runner=args(1)
  Dim legacy As Boolean=(args(2)="baseline")
  For Each list In New Integer(){1,10}
   Dim valid=If(list=1,11,12),foreign=If(list=1,12,11),baseTc=If(list=1,-1,0),net=If(list=1,20D,30D)
   Dim p=Page("id=1&TCid=999")
   Dim bad=p.Row(1,999,list,True)
   Check("missing positive resolver list" & list,If(legacy,bad IsNot Nothing,bad Is Nothing))
   Dim options=p.Options(1,list)
   Check("listino options list" & list,If(legacy,options.Exists(Function(k) k.Key=13),Not options.Exists(Function(k) k.Key=13) AndAlso Not options.Exists(Function(k) k.Key=foreign)))
   If legacy Then
    p.Run(1,999,list,True)
    Check("legacy misleading URL list" & list,p.Bound IsNot Nothing AndAlso p.Response.Destination Is Nothing)
    Continue For
   End If
   Check("options valid list" & list,options.Exists(Function(k) k.Key=valid))
   Check("options exact cardinality list" & list,options.Count=If(list=1,1,2))
   Check("options deterministic list" & list,options(0).Key=If(list=1,11,42))
   For Each badTc In New Integer(){999,21,foreign}
    p=Page("id=1&TCid=" & badTc):p.Run(1,badTc,list,True)
    Check("explicit redirect list" & list & " tc" & badTc,p.Response.StatusCode=302 AndAlso p.Response.Destination="/shop/articolo.aspx?id=1&TCid=" & baseTc)
    Check("no misleading content list" & list & " tc" & badTc,p.Bound Is Nothing AndAlso p.Effects=0)
    p=Page("id=1&TCid=" & baseTc):p.Run(1,baseTc,list,True)
    Check("redirect target terminates list" & list & " tc" & badTc,p.Bound IsNot Nothing AndAlso p.Response.Destination Is Nothing)
   Next
   p=Page("id=1&TCid=" & valid):p.Host=If(list=1,"www.taikun.it","www.webaffare.it")
   Dim catalogRow As New DataTable:catalogRow.Columns.Add("id",GetType(Integer)):catalogRow.Columns.Add("TCid",GetType(Integer))
   Dim item=catalogRow.Rows.Add(1,valid)
   Check("catalog link identity list" & list,p.CatalogLink(item)="/shop/articolo.aspx?id=1&TCid=" & valid)
   p.Run(1,valid,list,True)
   Check("exact product identity list" & list,Convert.ToInt32(p.Bound("TCid"))=valid AndAlso Convert.ToInt32(p.Bound("NListino"))=list)
   Check("net gross preserved list" & list,Convert.ToDecimal(p.Bound("Prezzo"))=net AndAlso Convert.ToDecimal(p.Bound("PrezzoIvato"))=net*1.22D)
   Check("canonical identity list" & list,p.Canonical()="https://" & p.Host & "/shop/articolo.aspx?id=1&TCid=" & valid)
   Check("native action identity list" & list,p.Action().Contains("id=1&amp;tcid=" & valid & "&amp;qtyField=") AndAlso p.Action().Contains("data-ks-tcid='" & valid & "'"))
   For Each standard In New Integer(){-1,0}
    p=Page("id=1&TCid=" & standard):p.Run(1,standard,list,True)
    Check("standard alias list" & list & " tc" & standard,p.Bound IsNot Nothing AndAlso p.Response.Destination Is Nothing AndAlso Convert.ToInt32(p.Bound("TCid"))=baseTc)
    p=Page("id=1&TCid=999"):p.Run(1,999,list,False)
    Check("TC disabled historical list" & list & " tc" & standard,p.Bound IsNot Nothing AndAlso Convert.ToInt32(p.Bound("TCid"))=baseTc AndAlso p.Response.Destination Is Nothing)
   Next
   p=Page("id=1"):p.Run(1,-1,list,True,False)
   Check("missing TC parameter list" & list,p.Bound IsNot Nothing AndAlso p.Response.Destination Is Nothing)
   p=Page("id=3&TCid=999"):p.Run(3,999,list,True)
   Check("missing product404 list" & list,p.Response.StatusCode=404 AndAlso p.Bound Is Nothing AndAlso Not p.pnlProduct.Visible AndAlso p.phNotFound.Visible AndAlso p.Effects=0)
   Check("notfound noindex list" & list,p.Response.Headers("X-Robots-Tag")="noindex, nofollow")
   Calls.Clear():p.Options(1,list):Check("one options query no Nplus1 list" & list,Calls.Count=1)
  Next
  If Not legacy Then
   Dim p=Page("id=1&TCid=999")
   Check("empty options",p.Options(3,1).Count=0)
   Check("invalid list no exposure",p.Options(1,0).Count=0)
   p=Page("id=1&TCid=11"):SuppressExact=True:p.Run(1,11,77,True):SuppressExact=False
   Check("same destination prevented no loop",p.Response.StatusCode=404 AndAlso p.Response.Destination Is Nothing AndAlso p.Bound Is Nothing)
   FailReads=True:p.Run(1,999,1,True):FailReads=False
   Check("technical failure no product",p.Response.StatusCode=404 AndAlso p.Bound Is Nothing AndAlso p.Effects=0 AndAlso Errors>0)
   JoinModel=True
   For Each list In New Integer(){1,10}
    p=Page("id=1&TCid=11")
    Dim options=p.Options(1,list)
    Check("versioned join no per-variant price restriction list" & list,options.Count=2 AndAlso options(0).Key=11 AndAlso options(1).Key=12)
    p.Run(1,11,list,True)
    Check("versioned stock TC exact identity list" & list,p.Bound IsNot Nothing AndAlso Convert.ToInt32(p.Bound("TCid"))=11)
    Check("versioned article list price list" & list,Convert.ToDecimal(p.Bound("Prezzo"))=If(list=1,10D,12D))
   Next
   p=Page("id=2&TCid=21"):p.Run(2,21,1,True)
   Check("versioned absent article-list no options",p.Options(2,1).Count=0)
   Check("versioned absent article-list404",p.Response.StatusCode=404 AndAlso p.Bound Is Nothing)
   p=Page("id=2&TCid=21"):p.Run(2,21,10,True)
   Check("versioned other-list valid identity",p.Bound IsNot Nothing AndAlso Convert.ToInt32(p.Bound("TCid"))=21 AndAlso Convert.ToInt32(p.Bound("NListino"))=10)
   JoinModel=False
  End If
  For Each name In Checks
   Console.WriteLine("PASS " & name)
  Next
  Console.WriteLine("PDP_VARIANT_" & args(2).ToUpperInvariant() & "=" & Checks.Count & "/" & Checks.Count)
 End Sub
End Module
'@
$intent=(@('CreateRequestId','BuildNativeSetActionValue','NormalizeTCId')|ForEach-Object{Member $idempotency $_}) -join "`n"
$bind=[regex]::Match($source,'(?m)^        Dim currentTcid As Integer = GetRowInt\(row, "TCid", _tcid\)\r?\n.*?\r?\n        _tcid = currentTcid').Value
if(!$bind){throw 'PDP_BIND_IDENTITY_MISSING'}
function Run-Harness($vb,$label){
 $methods=(@('GetProductRow','LoadPage','LoadVariantOptions','BuildProductSql','ShowNotFound','BuildProductUrl','BuildCanonicalUrl','GetRowInt','GetRowString','EncodeAttr')|ForEach-Object {Member $vb $_}) -join "`n"
 # Include both unchanged overloads verbatim; only the DB transport is replaced.
 $methods+="`n"+[regex]::Match($vb,'(?ms)^    Private Function TryGetProductRowInternal\(.*?^    End Function\r?\n\r?\n    Private Function TryGetProductRowInternal\(.*?^    End Function').Value
 $methods+="`n"+(Member $catalog 'CatalogProductUrl')
 $action=[regex]::Match($vb,'(?ms)^    Protected ReadOnly Property PdpMainNativeCartAttributes As String.*?^    End Property').Value
 $code=$seams.Replace('@@METHODS@@',$methods).Replace('@@ACTION@@',$action).Replace('@@INTENT@@',$intent).Replace('@@BIND_IDENTITY@@',$bind)
 $file=Join-Path $EvidenceDirectory ($label+'.vb');$exe=Join-Path $EvidenceDirectory ($label+'.exe')
 [IO.File]::WriteAllText($file,$code,(New-Object Text.UTF8Encoding($true)))
 $vbc=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/vbc.exe'
 & $vbc /nologo /target:exe /optioninfer+ /optionexplicit+ /optionstrict- /out:$exe /r:System.dll,System.Core.dll,System.Data.dll,System.Xml.dll,System.Web.dll,System.Web.Extensions.dll $file *> (Join-Path $EvidenceDirectory ($label+'-compile.log'))
 if($LASTEXITCODE){throw ('PDP_VB_COMPILE_FAILED '+$label)}
 & $exe $node (Join-Path $EvidenceDirectory 'sql-fixture.cjs') $label *> (Join-Path $EvidenceDirectory ($label+'-tests.log'))
 if($LASTEXITCODE){throw ('PDP_ASSERT_FAILED '+$label)}
 Get-Content (Join-Path $EvidenceDirectory ($label+'-tests.log')) | Select-Object -Last 1
}
Run-Harness $baseline 'baseline'
if(!$ReproduceBaselineOnly){
 foreach($name in @('LoadPage','GetProductRow','LoadVariantOptions')){
  $baseline=$baseline.Replace((Member $baseline $name),'')
  $source=$source.Replace((Member $source $name),'')
 }
 if($baseline.Replace("`r`n","`n").TrimEnd() -cne $source.Replace("`r`n","`n").TrimEnd()){throw 'PDP_OUTSIDE_METHOD_DELTA'}
 $source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articolo.aspx.vb'))
 Run-Harness $source 'candidate'
}
[ordered]@{baseline=$BaselineRef;baselineOnly=[bool]$ReproduceBaselineOnly;pdpSha256=(Get-FileHash (Join-Path $RepositoryRoot 'articolo.aspx.vb')).Hash;testSha256=(Get-FileHash $PSCommandPath).Hash;limits=@('Real extracted VB and real SQL executed on in-memory SQLite synthetic projections, plus relevant versioned stock-to-listino join model','MySql I/O/HTTP redirect transport/render side effects simulated; no IIS or MySQL connection','No fiscal resolver changes or re-certification','Current catalog and native-action helpers extracted; CatalogTcId input seam uses valid existing catalog identity')}|ConvertTo-Json|Set-Content (Join-Path $EvidenceDirectory 'report.json') -Encoding UTF8
