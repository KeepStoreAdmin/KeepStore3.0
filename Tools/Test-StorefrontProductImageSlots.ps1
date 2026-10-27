[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
      [string]$BaseRef='frontend-rebuild')

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if([string]::IsNullOrWhiteSpace($RepositoryRoot)){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if(-not $EvidenceDirectory.StartsWith($temp+'\',[StringComparison]::OrdinalIgnoreCase) -and
   -not $EvidenceDirectory.StartsWith('C:\Temp\',[StringComparison]::OrdinalIgnoreCase)){throw 'IMAGE_SLOTS_EVIDENCE_MUST_BE_TEMP'}
if(-not(Test-Path -LiteralPath $EvidenceDirectory)){[void](New-Item -ItemType Directory -Path $EvidenceDirectory)}

function Read-Source([string]$path){return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace(([string][char]13+[char]10),[string][char]10)}
function Read-Base([string]$path){
    $lines=@(& git -C $RepositoryRoot show ($BaseRef+':'+$path))
    if($LASTEXITCODE -ne 0){throw 'IMAGE_SLOTS_BASE_READ_FAILED'}
    return $lines -join [char]10
}
function Extract-Member([string]$source,[string]$kind,[string]$name){
    $pattern='(?ms)^    (?:Private|Public|Protected) '+$kind+' '+[regex]::Escape($name)+'\b.*?^    End '+$kind
    $m=[regex]::Match($source,$pattern)
    if(-not $m.Success){throw ('IMAGE_SLOTS_MEMBER_MISSING '+$name)}
    return $m.Value
}
$checks=New-Object 'System.Collections.Generic.List[string]'
function Check([bool]$pass,[string]$name){if(-not $pass){throw ('IMAGE_SLOTS_FAIL '+$name)};$checks.Add($name)}
$pdp=Read-Source 'articolo.aspx.vb';$oldPdp=Read-Base 'articolo.aspx.vb'
$homeSource=Read-Source 'Default.aspx.vb';$catalog=Read-Source 'articoli.aspx.vb'
$preview=Read-Source 'Public/ui/controls/ProductDetailView.ascx.vb'
$markup=Read-Source 'articolo.aspx'
$seo=Extract-Member $pdp 'Function' 'BuildStructuredDataProductImages'
Check ($seo -ceq (Extract-Member $oldPdp 'Function' 'BuildStructuredDataProductImages')) 'SEO original-photo deduplication unchanged'
Check ($markup.TrimEnd([char]10) -ceq (Read-Base 'articolo.aspx').TrimEnd([char]10)) 'PDP Swiper zoom PhotoSwipe and thumb templates unchanged'
Check ($markup.Contains('ID="rptMainImages"') -and $markup.Contains('ID="rptThumbs"') -and $markup.Contains('data-pswp-width')) 'main thumbs PhotoSwipe still present'
Check ($pdp.Contains('extraImages.Img5, extraImages.Img6') -and $pdp.Contains('ImageArticleId=productSource.id')) 'PDP retrieves Img5 Img6 in same product query'
Check ($homeSource.Contains('v.Img3, v.Img4, aBase.Img5, aBase.Img6')) 'HOME extends existing article join'
Check ($catalog.Contains('extraImages.ImageArticleId=vsuperarticoli.id') -and $catalog.Contains('recent.Img5,recent.Img6')) 'catalog and recent bulk image projections'
Check ($catalog.Contains('model.HoverImageUrl = StorefrontProductImageSlots.HoverUrl(dataItem)')) 'catalog hover uses second effective slot'
Check ($homeSource.Contains('For i As Integer = 0 To galleryImages.Count - 1')) 'HOME exposes all six gallery positions'
Check (-not $homeSource.Contains('ProductImageFull(row("Img1"))')) 'HOME cover consumers share fallback'
$catalogMarkup=Read-Source 'articoli.aspx'
Check (-not $catalogMarkup.Contains('ThemeManager.ProductImageUrl(Eval("img1"))')) 'single-image catalog cards use common cover without extra thumbnails'
$newSql=Extract-Member $pdp 'Function' 'BuildProductSql'
$oldSql=Extract-Member $oldPdp 'Function' 'BuildProductSql'
Check ($newSql.Substring($newSql.IndexOf('        sb.AppendLine("WHERE')) -ceq $oldSql.Substring($oldSql.IndexOf('        sb.AppendLine("WHERE'))) 'PDP commercial WHERE ORDER LIMIT source unchanged'
$newRelated=Extract-Member $pdp 'Function' 'RelatedSelectSql'
$oldRelated=Extract-Member $oldPdp 'Function' 'RelatedSelectSql'
Check ($newRelated.EndsWith('" & tailSql'+[char]10+'    End Function')) 'related query preserves caller filters ordering and limit'
Check ($seo.Contains('seen.Add(imageUri.AbsoluteUri)') -and -not $seo.Contains('StorefrontProductImageSlots')) 'display padding never feeds JSON-LD'

Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
$fixture=Join-Path $EvidenceDirectory ('system-web-unit-'+[guid]::NewGuid().ToString('N'))
$bin=Join-Path $fixture 'Bin'
$photos=Join-Path $fixture 'Public\assets\images\articoli'
$placeholder=Join-Path $fixture 'Public\assets\images\img'
[void](New-Item -ItemType Directory -Path $bin,$photos,$placeholder -Force)
$utf8=New-Object Text.UTF8Encoding($false)
$svg='<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1"/></svg>'
foreach($name in @('A','B','C','D','E','F','Food')){[IO.File]::WriteAllText((Join-Path $photos ($name+'.svg')),$svg,$utf8)}
[IO.File]::WriteAllText((Join-Path $placeholder 'placeholder.svg'),$svg,$utf8)
$imgItem=[regex]::Match($pdp,'(?ms)^    Private Class ImgItem\b.*?^    End Class').Value
if(-not $imgItem){throw 'IMAGE_SLOTS_IMGITEM_MISSING'}
$bind=Extract-Member $pdp 'Sub' 'BindImages'
$gallery=Extract-Member $pdp 'Function' 'BuildProductDetailGalleryImageUrls'
$homeSourceGallery=Extract-Member $homeSource 'Function' 'ProductGalleryImages'
$previewProperty=[regex]::Match($preview,'(?ms)^    Public Property GalleryImageUrls\b.*?^    End Property').Value.Replace(' Implements IProductDetailView.GalleryImageUrls','')
if(-not $previewProperty){throw 'IMAGE_SLOTS_PREVIEW_PROPERTY_MISSING'}
$harness=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.UI
Imports System.Web.UI.WebControls

Public Class ImageSlotsConsumer
    Private rptMainImages As New Repeater()
    Private rptThumbs As New Repeater()
    Private _galleryImageUrls As New List(Of String)()
    IMGITEM_SOURCE
    BIND_SOURCE
    GALLERY_SOURCE
    HOME_SOURCE
    QUERY_SOURCE
    PREVIEW_PROPERTY

    Public Function RenderSlots(ByVal row As DataRow) As String
        Dim main As New List(Of String)(), thumbs As New List(Of String)()
        AddHandler rptMainImages.ItemDataBound, Sub(sender,e) main.Add(CStr(DataBinder.Eval(e.Item.DataItem,"Url")))
        AddHandler rptThumbs.ItemDataBound, Sub(sender,e) thumbs.Add(CStr(DataBinder.Eval(e.Item.DataItem,"Url")))
        BindImages(row,"synthetic")
        Return String.Join("|",main) & "#" & String.Join("|",thumbs)
    End Function
    Public Function PdpSlots(ByVal row As DataRow) As String
        Return String.Join("|",BuildProductDetailGalleryImageUrls(row))
    End Function
    Public Function HomeSlots(ByVal row As DataRow) As String
        Return String.Join("|",ProductGalleryImages(row))
    End Function
    Public Function ProductQuery(ByVal tcid As Boolean) As String
        Return BuildProductSql(tcid)
    End Function
End Class

Public Class ImageSlotsUnitHost
    Inherits MarshalByRefObject
    Private checks As New List(Of String)()
    Private Sub Check(ByVal passed As Boolean, ByVal name As String)
        If Not passed Then Throw New InvalidOperationException("IMAGE_SLOTS_FAIL " & name)
        checks.Add(name)
    End Sub
    Private Sub NewRequest()
        HttpContext.Current=New HttpContext(New SimpleWorkerRequest("unit.aspx","",New StringWriter()))
    End Sub
    Private Function Url(ByVal name As String) As String
        Return "/Public/assets/images/articoli/" & name & ".svg"
    End Function
    Private Function Row(ByVal raw As Object()) As DataRow
        Dim dt As New DataTable()
        For i As Integer=1 To 6
            dt.Columns.Add("Img" & i.ToString(),GetType(String))
        Next
        Dim item As DataRow=dt.NewRow()
        For i As Integer=0 To Math.Min(5,raw.Length-1)
            item(i)=If(raw(i),DBNull.Value)
        Next
        dt.Rows.Add(item)
        Return item
    End Function
    Private Sub Sequence(ByVal label As String, ByVal raw As Object(), ByVal expectedNames As String)
        NewRequest()
        Dim expected As String=String.Join("|",expectedNames.Split(","c).Select(Function(n) Url(n)))
        Dim actual=StorefrontProductImageSlots.Resolve(raw)
        Check(actual.Count=6 AndAlso String.Join("|",actual)=expected,label)
        Dim data=Row(raw), consumer As New ImageSlotsConsumer()
        Check(String.Join("|",StorefrontProductImageSlots.FromDataItem(data))=expected,label & " DataRow")
        Check(String.Join("|",StorefrontProductImageSlots.FromDataItem(data.Table.DefaultView(0)))=expected,label & " DataRowView")
        Check(consumer.RenderSlots(data)=expected & "#" & expected,label & " real BindImages main/thumbs")
        Check(consumer.PdpSlots(data)=expected AndAlso consumer.HomeSlots(data)=expected,label & " actual PDP preview/HOME methods")
        consumer.GalleryImageUrls=actual
        Check(String.Join("|",consumer.GalleryImageUrls)=expected,label & " actual preview property")
    End Sub
    Public Function Run() As String()
        Sequence("one",New Object() {"A.svg"},"A,A,A,A,A,A")
        Sequence("four",New Object() {"A.svg","B.svg","C.svg","D.svg"},"A,B,C,D,D,D")
        Sequence("two",New Object() {"A.svg","B.svg"},"A,B,B,B,B,B")
        Sequence("gap",New Object() {"A.svg","","C.svg"},"A,A,C,C,C,C")
        Sequence("six",New Object() {"A.svg","B.svg","C.svg","D.svg","E.svg","F.svg"},"A,B,C,D,E,F")
        Sequence("leading gap",New Object() {Nothing,"B.svg","C.svg"},"B,B,C,C,C,C")
        Sequence("late first",New Object() {DBNull.Value,"","img3","","E.svg","F.svg"},"E,E,E,E,E,F")
        Sequence("duplicates retained",New Object() {"A.svg","B.svg","A.svg","A.svg","B.svg","B.svg"},"A,B,A,A,B,B")
        Sequence("NULL and DBNull",New Object() {"A.svg",Nothing,DBNull.Value,"D.svg"},"A,A,A,D,D,D")
        Sequence("sentinels",New Object() {"A.svg","img2","IMG3","img4","img5","img6"},"A,A,A,A,A,A")
        Sequence("missing local",New Object() {"A.svg","not-present.svg","C.svg"},"A,A,C,C,C,C")
        Sequence("unsafe local",New Object() {"A.svg","../escape.svg","%2e%2e/escape.svg","D.svg"},"A,A,A,D,D,D")
        Sequence("trim",New Object() {" A.svg ","","C.svg"},"A,A,C,C,C,C")
        NewRequest()
        Dim none=StorefrontProductImageSlots.Resolve(New Object() {Nothing,DBNull.Value,"","img4","not-present.svg"})
        Check(none.Count=6 AndAlso none.All(Function(x) x=ThemeManager.PlaceholderProductImageUrl()),"no valid photos existing placeholder")
        Check(StorefrontProductImageSlots.Resolve(Nothing).Count=6,"Nothing collection")
        Check(StorefrontProductImageSlots.CoverUrl(Row(New Object() {Nothing,"B.svg"}))=Url("B"),"first valid cover")
        Check(StorefrontProductImageSlots.HoverUrl(Row(New Object() {"A.svg",Nothing,"C.svg"}))=Url("A"),"hover repeats cover on gap")
        Check(StorefrontProductImageSlots.Resolve(New Object() {"A.svg","B.svg","C.svg","D.svg","E.svg","F.svg","A.svg"}).Count=6,"ignore beyond six")
        Dim remote=StorefrontProductImageSlots.Resolve(New Object() {"https://images.example.invalid/A.svg"})
        Check(remote.All(Function(x) x="https://images.example.invalid/A.svg"),"existing external URL policy no HTTP")
        NewRequest()
        Check(StorefrontProductImageSlots.CoverUrl(Row(New Object() {"Food.svg"}))=Url("Food"),"second synthetic catalog own cover")
        NewRequest()
        Check(StorefrontProductImageSlots.CoverUrl(Row(New Object() {"A.svg"}))=Url("A"),"new request no cross-catalog cache")
        Dim query As New ImageSlotsConsumer()
        Check(query.ProductQuery(True).Contains("AND TCid=@tcid"),"actual product query variant predicate")
        Check(Not query.ProductQuery(False).Contains("AND TCid=@tcid"),"actual product query no optional variant predicate")
        Check(query.ProductQuery(False).Contains("extraImages.Img5, extraImages.Img6") AndAlso query.ProductQuery(False).Contains("LIMIT 1"),"actual product query image-only join")
        Return checks.ToArray()
    End Function
    Public Sub Shutdown()
        HttpContext.Current=Nothing
        HostingEnvironment.InitiateShutdown()
    End Sub
    Public Overrides Function InitializeLifetimeService() As Object
        Return Nothing
    End Function
End Class
'@
$harness=$harness.Replace('IMGITEM_SOURCE',$imgItem).Replace('BIND_SOURCE',$bind).Replace('GALLERY_SOURCE',$gallery).Replace('HOME_SOURCE',$homeSourceGallery).Replace('QUERY_SOURCE',$newSql).Replace('PREVIEW_PROPERTY',$previewProperty)
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
$parameters=New-Object CodeDom.Compiler.CompilerParameters
$parameters.GenerateExecutable=$false;$parameters.GenerateInMemory=$false
$parameters.OutputAssembly=Join-Path $bin 'KeepStoreImageSlotsUnit.dll'
$parameters.CompilerOptions='/optionexplicit+ /optionstrict+ /optioninfer+ /imports:Microsoft.VisualBasic'
@('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll')|ForEach-Object{[void]$parameters.ReferencedAssemblies.Add($_)}
$hostObject=$null
try{
    $sources=@($harness,(Read-Source 'App_Code/StorefrontProductImageSlots.vb'),(Read-Source 'App_Code/ThemeManager.vb'),(Read-Source 'App_Code/UiData.vb'))
    $compiled=$compiler.CompileAssemblyFromSource($parameters,[string[]]$sources)
    if($compiled.Errors.HasErrors){$compiled.Errors|ForEach-Object{Write-Output $_.ToString()};throw 'IMAGE_SLOTS_COMPILE_FAILED'}
    $assembly=[Reflection.Assembly]::LoadFrom($parameters.OutputAssembly)
    $hostObject=[System.Web.Hosting.ApplicationHost]::CreateApplicationHost($assembly.GetType('ImageSlotsUnitHost'),'/',$fixture)
    $runtimeChecks=@($hostObject.Run())
    foreach($name in $runtimeChecks){$checks.Add($name)}
    $result=[ordered]@{result='PASS';checks=$checks.Count;names=@($checks);scope='Deterministic actual VB, ThemeManager local-file validation, System.Web Repeater binding; no browser IIS database or HTTP';fixture=$fixture}
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'image-slots-results.json'),($result|ConvertTo-Json -Depth 5),$utf8)
    Write-Output ('IMAGE_SLOTS_PASS checks='+$checks.Count+' no_browser no_DB no_HTTP')
}finally{
    if($hostObject){try{$hostObject.Shutdown()}catch{}}
    $compiler.Dispose()
}
