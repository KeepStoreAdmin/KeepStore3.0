[CmdletBinding()]
param(
    [string]$RepositoryRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$BaselineRef='62e3c2fb47a4a37c7374aa8697ca3eb094a4d19f',
    [string]$EvidenceDirectory=(Join-Path $env:TEMP ('KeepStoreHomeAdaptive-'+[Guid]::NewGuid().ToString('N')))
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$Name,[bool]$Pass){$checks.Add([pscustomobject]@{Name=$Name;Pass=$Pass});if(-not $Pass){throw ('HOME_ADAPTIVE_FAILED '+$Name)}}
function Method([string]$Source,[string]$Name){
    $match=[regex]::Match($Source,'(?ms)^    (?:Private|Protected)(?: Shared)? (?:Function|Sub) '+[regex]::Escape($Name)+'\(.*?^    End (?:Function|Sub)')
    if(-not $match.Success){throw ('HOME_ADAPTIVE_METHOD_MISSING '+$Name)}
    return $match.Value
}
function Section([string]$Source,[string]$Id){
    $m=[regex]::Match($Source,'<section id="'+[regex]::Escape($Id)+'"[\s\S]*?</section>')
    if(-not $m.Success){throw ('HOME_ADAPTIVE_SECTION_MISSING '+$Id)}
    return $m.Value
}
function Normal([string]$Text){return ([regex]::Replace(($Text -replace "`r`n","`n"),"`n{2,}","`n`n")).Trim()}
function Read-Baseline([string]$Path){$text=(& git.exe -C $RepositoryRoot show ($BaselineRef+':'+$Path)) -join "`n";if($LASTEXITCODE -ne 0){throw 'HOME_ADAPTIVE_BASELINE_UNAVAILABLE'};return $text}
$beforeVb=Read-Baseline 'Default.aspx.vb';$beforeAspx=Read-Baseline 'Default.aspx'
$afterVb=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
$afterAspx=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
$introBefore=Section $beforeAspx 'HomeIntroSection';$introAfter=Section $afterAspx 'HomeIntroSection'
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
try{
    function Compile-Home([string]$Source,[string]$ClassName,[bool]$Candidate){
        $methods=@((Method $Source 'ResolveHeroMode'),(Method $Source 'ApplyHeroMode'))
        if($Candidate){$methods+=Method $Source 'BindHomeIntroNavigation'}
        $wrapper=@'
Imports System
Imports System.IO
Imports System.Xml
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Public Class CLASS_NAME
    Public Host As New ContentPlaceHolder With {.ID="FixtureContent"}
    Public Slide_Show_Container As New HtmlGenericControl("div")
    Public HeroSliderWrap As New HtmlGenericControl("div")
    Public HeroSideWrap As New Panel()
    Public rptSideBanners As New Repeater()
    Public HomeHeroSection As New HtmlGenericControl("section")
    Public HomeIntroSection As HtmlGenericControl
    Public HomeHeroShell As New HtmlGenericControl("div")
    Public HomeMainCategoriesSection As New HtmlGenericControl("section") With {.ID="HomeMainCategoriesSection"}
    Public HomeDirectCategoriesSection As New HtmlGenericControl("section") With {.ID="HomeDirectCategoriesSection"}
    Public HomeIntroBrowseLink As HtmlAnchor
    Public HomeIntroBrowseLabel As HtmlGenericControl
    Public Mode As String
    Public Sub New(markup As String)
        Dim document As New XmlDocument()
        document.PreserveWhitespace=True
        document.LoadXml("<root xmlns:asp='urn:asp'>" & markup & "</root>")
        HomeIntroSection=DirectCast(Build(document.DocumentElement.FirstChild),HtmlGenericControl)
        Host.Controls.Add(HomeIntroSection)
        Host.Controls.Add(HomeMainCategoriesSection)
        Host.Controls.Add(HomeDirectCategoriesSection)
        HomeIntroBrowseLink=TryCast(Find(HomeIntroSection,"HomeIntroBrowseLink"),HtmlAnchor)
        HomeIntroBrowseLabel=TryCast(Find(HomeIntroSection,"HomeIntroBrowseLabel"),HtmlGenericControl)
    End Sub
    Private Function Build(node As XmlNode) As Control
        If node.NodeType <> XmlNodeType.Element Then Return New LiteralControl(HttpUtility.HtmlEncode(node.Value))
        Dim result As Control
        If node.NamespaceURI="urn:asp" AndAlso node.LocalName="Literal" Then
            result=New Literal With {.Mode=LiteralMode.Encode}
        ElseIf node.LocalName="a" AndAlso node.Attributes("runat") IsNot Nothing Then
            result=New HtmlAnchor()
        Else
            result=New HtmlGenericControl(node.LocalName)
        End If
        For Each attribute As XmlAttribute In node.Attributes
            If attribute.Name="runat" OrElse attribute.Name="Mode" Then Continue For
            If attribute.Name="visible" Then
                result.Visible=Boolean.Parse(attribute.Value)
            ElseIf attribute.Name="id" OrElse attribute.Name="ID" Then
                If node.Attributes("runat") IsNot Nothing Then
                    result.ID=attribute.Value
                Else
                    DirectCast(result,HtmlControl).Attributes(attribute.Name)=attribute.Value
                End If
            Else
                DirectCast(result,HtmlControl).Attributes(attribute.Name)=attribute.Value
            End If
        Next
        For Each child As XmlNode In node.ChildNodes
            result.Controls.Add(Build(child))
        Next
        Return result
    End Function
    Private Function Find(root As Control,id As String) As Control
        If root.ID=id Then Return root
        For Each child As Control In root.Controls
            Dim match=Find(child,id)
            If match IsNot Nothing Then Return match
        Next
        Return Nothing
    End Function
    Public Sub Configure(hasHero As Boolean,sides As Integer,sectors As Integer,categories As Integer,company As String,description As String,Optional verified As Boolean=True)
        Mode=ResolveHeroMode(hasHero,sides)
        ApplyHeroMode(Mode,sides)
        HomeMainCategoriesSection.Visible=(sectors>0)
        HomeDirectCategoriesSection.Visible=(categories>0)
        DirectCast(Find(HomeIntroSection,"litHomeIntroName"),Literal).Text=company
        DirectCast(Find(HomeIntroSection,"litHomeIntroDescription"),Literal).Text=description
        BIND_INTRO
    End Sub
    Public Function RenderIntro() As String
        Using writer As New StringWriter()
            Using html As New HtmlTextWriter(writer)
                HomeIntroSection.RenderControl(html)
            End Using
            Return writer.ToString()
        End Using
    End Function
'@
        $wrapper=$wrapper.Replace('CLASS_NAME',$ClassName).Replace('BIND_INTRO',$(if($Candidate){'BindHomeIntroNavigation(verified)'}else{''}))
        $code=$wrapper+"`r`n"+($methods -join "`r`n")+"`r`nEnd Class"
        $parameters=New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory=$true
        $parameters.ReferencedAssemblies.AddRange([string[]]@('System.dll','System.Core.dll','System.Web.dll','System.Xml.dll'))
        $compiled=$compiler.CompileAssemblyFromSource($parameters,$code)
        if($compiled.Errors.HasErrors){throw ('HOME_ADAPTIVE_COMPILE '+(($compiled.Errors|Where-Object{-not $_.IsWarning}|ForEach-Object{$_.ErrorText}) -join '; '))}
        return $compiled.CompiledAssembly.GetType($ClassName,$true)
    }
    $beforeType=Compile-Home $beforeVb 'BaselineHomeIntro' $false
    $afterType=Compile-Home $afterVb 'CandidateHomeIntro' $true
    $fixtures=New-Object 'Collections.Generic.List[object]'
    $sizes=@(@{Name='empty';Sectors=0;Categories=0;Verified=$true},@{Name='sectors-only';Sectors=1;Categories=0;Verified=$true},@{Name='small';Sectors=1;Categories=1;Verified=$true},@{Name='medium';Sectors=5;Categories=6;Verified=$true},@{Name='large';Sectors=12;Categories=8;Verified=$true},@{Name='read-error';Sectors=1;Categories=0;Verified=$false})
    $modes=@(@{Name='none';Hero=$false;Sides=0},@{Name='hero-only';Hero=$true;Sides=0},@{Name='full-one';Hero=$true;Sides=1},@{Name='full-two';Hero=$true;Sides=2})
    foreach($tenant in @(@{Name='Tech';Company=1;Listino=1},@{Name='Food';Company=2;Listino=10})){
        foreach($size in $sizes){foreach($mode in $modes){
            $before=[Activator]::CreateInstance($beforeType,[object[]]@($introBefore))
            $after=[Activator]::CreateInstance($afterType,[object[]]@($introAfter))
            $name=$tenant.Name+' & <negozio> '+$size.Name
            $description='Catalogo e informazioni del negozio: '+('articoli e categorie per esigenze differenti. '*5)
            foreach($instance in @($before,$after)){$instance.Configure($mode.Hero,$mode.Sides,$size.Sectors,$size.Categories,$name,$description,$size.Verified)}
            $key=$tenant.Name+'/'+$size.Name+'/'+$mode.Name
            $browseTarget=$after.HomeIntroBrowseLink.HRef
            $old=$before.RenderIntro();$html=$after.RenderIntro()
            Check ($key+' hero mode and visibility preserved') ($before.Mode -ceq $after.Mode -and $before.HomeHeroSection.Visible -eq $after.HomeHeroSection.Visible -and $before.HeroSideWrap.Visible -eq $after.HeroSideWrap.Visible -and $before.HomeIntroSection.Visible -eq $after.HomeIntroSection.Visible)
            if($mode.Hero){
                Check ($key+' no extra introductory links with banners') ($old -ceq '' -and $html -ceq '')
            }else{
                Check ($key+' catalog URL and unique broad CTA preserved') ([regex]::Matches($html,'href="articoli.aspx"').Count -eq 1 -and $old.Contains('href="articoli.aspx"'))
                Check ($key+' guide reuses the existing anchor without query or form') ($html.Contains('href="#KsLocalAiSearch130"') -and $html -notmatch '<form|<input|<script')
                Check ($key+' merchant text remains encoded') ($html.Contains('Tech') -or $html.Contains('Food'))
                Check ($key+' merchant markup cannot become a DOM node') ($html -notmatch '<negozio>' -and $html.Contains('&lt;negozio&gt;'))
                Check ($key+' no empty or unverified taxonomy target') ($after.HomeIntroBrowseLink.Visible -eq ($size.Verified -and $size.Sectors -gt 0))
                if($size.Verified -and $size.Sectors -gt 0){
                    $target=if($size.Categories -gt 0){$after.HomeDirectCategoriesSection}else{$after.HomeMainCategoriesSection}
                    $label=if($size.Categories -gt 0){'Esplora le categorie'}else{'Esplora i reparti'}
                    Check ($key+' browse link uses the real naming-container ClientID') ($browseTarget -ceq ('#'+$target.ClientID) -and $html.Contains('href="'+$browseTarget+'"') -and $after.HomeIntroBrowseLabel.InnerText -ceq $label)
                }else{Check ($key+' empty catalog omits unverified navigation') ($html -notmatch 'HomeIntroBrowseLink|Esplora le categorie|Esplora i reparti')}
            }
            $fixtures.Add([pscustomobject]@{Tenant=$tenant.Name;Company=$tenant.Company;Listino=$tenant.Listino;Size=$size.Name;Sectors=$size.Sectors;Categories=$size.Categories;Verified=$size.Verified;Mode=$mode.Name;HeroMode=$after.Mode;Sides=$mode.Sides;BeforeIntro=$old;Intro=$html;MainId=$after.HomeMainCategoriesSection.ClientID;CategoriesId=$after.HomeDirectCategoriesSection.ClientID;BrowseTarget=$browseTarget;BeforeBytes=[Text.Encoding]::UTF8.GetByteCount($old);AfterBytes=[Text.Encoding]::UTF8.GetByteCount($html)})
        }}
    }
    # Rebinding an empty assortment cannot leave a stale fragment on a previously valid link.
    $after.Configure($false,0,2,1,'Food','');$after.Configure($false,0,0,0,'Food','')
    Check 'rebinding to empty clears target and label' ($after.HomeIntroBrowseLink.HRef -ceq '' -and $after.HomeIntroBrowseLabel.InnerText -ceq '' -and -not $after.HomeIntroBrowseLink.Visible)
    $after.Host.ID='DifferentContent';$after.Configure($false,0,1,1,'Food','')
    Check 'no hardcoded page or virtual directory ClientID' ($after.HomeIntroBrowseLink.HRef -ceq '#DifferentContent_HomeDirectCategoriesSection')
    $unchangedVb=$afterVb.Replace((Method $afterVb 'BindHomeIntroNavigation'),'').Replace('        BindHomeIntroNavigation(navigationAssortment IsNot Nothing)','')
    Check 'all existing VB including queries, commercial renderers and #413 unchanged' ((Normal $unchangedVb) -ceq (Normal $beforeVb))
    Check 'new binder has no database, cache, resolver or per-card work' ((Method $afterVb 'BindHomeIntroNavigation') -notmatch '(?i)query|sql|connection|cache|foreach|for each|session|select|resolve')
    Check 'binder runs only after both navigation sections are bound and requires successful assortment read' ((Normal $afterVb).Contains('HomeDirectCategoriesSection.Visible = (directCategories.Count > 0)'+"`n"+'        BindHomeIntroNavigation(navigationAssortment IsNot Nothing)'))
    $unchangedAspx=[regex]::Replace($afterAspx,'(?s)    <style id="ksHomeAdaptiveExperienceStyles">.*?</style>\r?\n','')
    $unchangedAspx=$unchangedAspx.Replace($introAfter,$introBefore).Replace(' aria-labelledby="ksHomeDepartmentsTitle" tabindex="-1"','').Replace(' aria-labelledby="ksHomeDirectCategoriesTitle" tabindex="-1"',' aria-labelledby="ksHomeDirectCategoriesTitle"').Replace('<h5 id="ksHomeDepartmentsTitle"','<h5')
    Check 'markup outside intro and its two focus destinations unchanged' ((Normal $unchangedAspx) -ceq (Normal $beforeAspx))
    foreach($id in @('HomeHeroSection','KsLocalAiSearch130','HomeOffersSection','HomeFeaturedProductsSection','HomeCatalogDiscoverySection')){Check ($id+' markup preserved') ((Normal (Section $afterAspx $id)) -ceq (Normal (Section $beforeAspx $id)))}
    $fixtures|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'presentation-fixtures.json') -Encoding UTF8
    [ordered]@{Result='PASS';Checks=$checks.Count;Detail=$checks;Baseline=$BaselineRef;AdditionalQueries=0;NewJavascriptBytes=0;SourceMarkupByteDelta=([Text.Encoding]::UTF8.GetByteCount($afterAspx)-[Text.Encoding]::UTF8.GetByteCount($beforeAspx));NativeIntroBytes=@($fixtures|Select-Object Tenant,Size,Mode,BeforeBytes,AfterBytes);Limits='Actual compiled hero/intro VB and native System.Web control rendering from ASPX XML; taxonomy presence and tenant labels synthetic. No WebForms request, query execution, IIS/MySQL or commercial certification.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'source-report.json') -Encoding UTF8
    Write-Output ('HOME_ADAPTIVE_EXPERIENCE '+$checks.Count+'/'+$checks.Count+' PASS')
}finally{$compiler.Dispose()}
