[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef='9d77586ec2aaf19aa5858a94a3d7aaef380ffa39'
)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'POWERSHELL_DESKTOP_REQUIRED' }
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
if (-not $RepositoryRoot) { $RepositoryRoot=Split-Path -Parent $PSScriptRoot }
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if (-not $EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'TEMP_EVIDENCE_REQUIRED' }
if ($BaselineRef -cne '9d77586ec2aaf19aa5858a94a3d7aaef380ffa39') { throw 'IMMUTABLE_BASELINE_REQUIRED' }
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$utf8=New-Object Text.UTF8Encoding($false)
$assertions=New-Object 'Collections.Generic.List[object]'
function Assert-Source([string]$Name,[bool]$Passed) {
    $assertions.Add([pscustomobject]@{name=$Name;passed=$Passed})
    if (-not $Passed) { throw ('CONTINUITY_ASSERTION_FAILED: '+$Name) }
}
function Normalize([string]$Value) { return $Value.Replace("`r`n","`n").TrimStart([char]0xFEFF) }
function Read-Base([string]$Path) {
    $value=@(& git -C $RepositoryRoot show ($BaselineRef+':'+$Path)) -join "`n"
    if ($LASTEXITCODE) { throw ('BASELINE_READ_FAILED: '+$Path) }
    return (Normalize $value).TrimEnd("`n")
}
function Read-Candidate([string]$Path) { return (Normalize ([IO.File]::ReadAllText((Join-Path $RepositoryRoot $Path)))).TrimEnd("`n") }
function Save-Text([string]$Name,[string]$Value) { [IO.File]::WriteAllText((Join-Path $EvidenceDirectory $Name),$Value,$utf8) }
function Extract-Method([string]$Source,[string]$Name,[string]$Kind='Function') {
    $match=[regex]::Match($Source,'(?ms)^    Private '+$Kind+' '+[regex]::Escape($Name)+'\b.*?^    End '+$Kind)
    if (-not $match.Success) { throw ('SOURCE_METHOD_MISSING: '+$Name) }
    return $match.Value
}
$cardPath='Public/ui/controls/ProductCard.ascx'
$before=Read-Base $cardPath
$after=Read-Candidate $cardPath
$quantityName='Quantit'+[char]0xE0+' da acquistare'
$oldTag='<asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control form-control-sm ks-qty" Width="70" />'
$newTag=$oldTag.Replace(' />',' aria-label="'+$quantityName+'" />')
Assert-Source 'native quantity control appears exactly once' (([regex]::Matches($before,[regex]::Escape($oldTag))).Count -eq 1)
Assert-Source 'live ProductCard diff is only its quantity accessible name' ($after -ceq $before.Replace($oldTag,$newTag))
Save-Text 'ProductCard.before.ascx' $before
Save-Text 'ProductCard.after.ascx' $after
Save-Text 'quantity.before.ascx' $oldTag
Save-Text 'quantity.after.ascx' $newTag

$changed=@(& git -C $RepositoryRoot diff --name-only $BaselineRef --)
if ($LASTEXITCODE) { throw 'SOURCE_DIFF_FAILED' }
Assert-Source 'all VB and App_Code commercial sources unchanged' (@($changed | Where-Object { $_ -match '\.vb$|^App_Code/' }).Count -eq 0)
foreach ($path in @('articoli.aspx.vb','articolo.aspx.vb','Public/ui/controls/ProductCard.ascx.vb','Page.master','Page.master.vb','Public/assets/keepstore/js/catalog-ui.js','Public/assets/keepstore/js/catalog-product-flow.js','Public/assets/keepstore/css/catalog-ui.css','Public/assets/keepstore/css/catalog-filters-ui.css')) {
    Assert-Source ($path+' unchanged from baseline') ((Read-Candidate $path) -ceq (Read-Base $path))
}
$flowCssPath='Public/assets/keepstore/css/catalog-product-flow.css'
$flowCssBefore=Read-Base $flowCssPath
$flowCssAfter=Read-Candidate $flowCssPath
$keyboardRule=@'
/* Match hover visibility when keyboard navigation enters a catalog card. */
#ksCatalogPage #gridLayout article.card-product:focus-within .list-product-btn li,
#ksCatalogPage #gridLayout article.card-product:focus-within .list-product-btn .box-icon{
  opacity:1;
  visibility:visible;
  transform:none;
  transition:none;
}
'@
Assert-Source 'one exact catalog-scoped keyboard quick-action visibility rule added' (([regex]::Matches($flowCssAfter,[regex]::Escape($keyboardRule))).Count -eq 1)
Assert-Source 'all product-flow CSS outside dedicated keyboard rule unchanged' ($flowCssAfter.Replace($keyboardRule+"`n`n",'') -ceq $flowCssBefore)
foreach ($path in @('articoli.aspx','articolo.aspx')) {
    $pageBefore=Read-Base $path
    $oldVersion='20261028-quickview-focus-1a'
    Assert-Source ($path+' has one shared-script version') (([regex]::Matches($pageBefore,[regex]::Escape($oldVersion))).Count -eq 1)
    $pageExpected=$pageBefore.Replace($oldVersion,'20261106-catalog-pdp-shopping-continuity-1a')
    if ($path -ceq 'articoli.aspx') {
        $oldCssVersion='ThemeManager.Asset("css/catalog-product-flow.css") %>?v=20261015-mobile-excellence1a'
        $newCssVersion='ThemeManager.Asset("css/catalog-product-flow.css") %>?v=20261106-catalog-pdp-shopping-continuity-1a'
        Assert-Source 'catalog has one product-flow stylesheet version' (([regex]::Matches($pageExpected,[regex]::Escape($oldCssVersion))).Count -eq 1)
        $pageExpected=$pageExpected.Replace($oldCssVersion,$newCssVersion)
    }
    Assert-Source ($path+' changes only authorized script/CSS versions; controls, attributes and data bindings unchanged') ((Read-Candidate $path) -ceq $pageExpected)
}
$jsPath='Public/assets/keepstore/js/keepstore-product.js'
$jsBefore=Read-Base $jsPath
$jsAfter=Read-Candidate $jsPath
$jsCommercial=$jsAfter
foreach ($name in @('captureComparePageFocus','restoreComparePageFocus')) {
    $pattern='(?ms)^  function '+$name+'\(.*?^  \}\n\n'
    Assert-Source ($name+' has one dedicated helper') (([regex]::Matches($jsCommercial,$pattern)).Count -eq 1)
    $jsCommercial=[regex]::Replace($jsCommercial,$pattern,'')
}
foreach ($line in @('    var focus = captureComparePageFocus(grid, shell, !list.length);','      restoreComparePageFocus(grid, focus, true);','    restoreComparePageFocus(grid, focus, false);')) {
    Assert-Source ('one focus-only call: '+$line.Trim()) (([regex]::Matches($jsCommercial,[regex]::Escape($line))).Count -eq 1)
    $jsCommercial=$jsCommercial.Replace($line+"`n",'')
}
$drawerBefore=@'
        '<button type="button" class="remove link" data-ks-remove-compare="' + idx + '"><i class="icon icon-close"></i></button>' +
'@
$drawerAfter=@'
        '<button type="button" class="remove link" data-ks-remove-compare="' + idx + '" aria-label="' + escapeHtml('Rimuovi ' + (item.title || 'prodotto')) + '"><i class="icon icon-close"></i></button>' +
'@
$pageRemoveBefore=@'
        '<button type="button" class="remove link" data-ks-remove-compare="' + item.idx + '" aria-label="Rimuovi"><i class="icon icon-close"></i></button>' +
'@
$pageRemoveAfter=@'
        '<button type="button" class="remove link" data-ks-remove-compare="' + item.idx + '" aria-label="' + escapeHtml('Rimuovi ' + title) + '"><i class="icon icon-close"></i></button>' +
'@
foreach ($pair in @(@($drawerBefore,$drawerAfter),@($pageRemoveBefore,$pageRemoveAfter))) {
    Assert-Source 'one escaped product-specific removal label replaces its original button' (([regex]::Matches($jsCommercial,[regex]::Escape($pair[1]))).Count -eq 1)
    $jsCommercial=$jsCommercial.Replace($pair[1],$pair[0])
}
$quickViewBefore=@'
        var style = window.getComputedStyle(opener);
        if (!opener.getClientRects().length || style.visibility !== 'visible' || style.opacity === '0') {
'@
$quickViewAfter=@'
        var style = window.getComputedStyle(opener);
        if (style.visibility !== 'visible' && opener.closest('#ksCatalogPage #gridLayout article.card-product')) {
          var card = opener.closest('#ksCatalogPage #gridLayout article.card-product');
          var entry = card.querySelector('.product-img');
          if (entry) entry.focus({ preventScroll: true });
          style = window.getComputedStyle(opener);
        }
        if (!opener.getClientRects().length || style.visibility !== 'visible' || style.opacity === '0') {
'@
Assert-Source 'one exact catalog-only Quick View focus recovery precedes existing visibility validation' (([regex]::Matches($jsCommercial,[regex]::Escape($quickViewAfter))).Count -eq 1)
$jsCommercial=$jsCommercial.Replace($quickViewAfter,$quickViewBefore)
Assert-Source 'all JS outside dedicated compare focus, escaped removal names and scoped Quick View recovery unchanged; commercial rendering unchanged' ($jsCommercial -ceq $jsBefore)
$compareBefore=Read-Base 'compare.aspx'
$compareExpected=$compareBefore.Replace('<a class="tf-btn btn-fill" href="articoli.aspx">Vai al catalogo</a>','<a class="tf-btn btn-fill" href="articoli.aspx" id="ksCompareEmptyCatalogLink">Vai al catalogo</a>').Replace('20261012-compare-commercial-snapshot-1c','20261106-catalog-pdp-shopping-continuity-1a')
Assert-Source 'compare markup changes only empty-state focus id and script version' ((Read-Candidate 'compare.aspx') -ceq $compareExpected)

$catalogSource=Read-Candidate 'articoli.aspx.vb'
$quantityMethod=Extract-Method $catalogSource 'ApplyCatalogCartQuantityState' 'Sub'
$findMethod=Extract-Method $catalogSource 'FindControlRecursive'
$classMethod=Extract-Method $catalogSource 'AddCatalogCssClass'
$harness=@'
Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Text.RegularExpressions
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports System.Web.Script.Serialization

' Only the surrounding ProductCard type is substituted. The quantity state,
' recursive lookup and CSS helper below are extracted unchanged from the page.
Public Class Public_ui_controls_ProductCard
 Inherits UserControl
 Public Property CardStateCssClass As String
 Public Property LegacyQuantityStateCssClass As String
 Public Property LegacyQuantityStateText As String
End Class
Public Class NativeQuantityFixture
 Public Function Render(sourceTag As String, cartQuantity As Decimal) As Dictionary(Of String,Object)
  Dim card As New Public_ui_controls_ProductCard()
  Dim wrapper As New HtmlGenericControl("div")
  Dim input As New TextBox()
  For Each attribute As Match In Regex.Matches(sourceTag,"([\w-]+)=""([^""]*)""")
   Dim name As String=attribute.Groups(1).Value, value As String=attribute.Groups(2).Value
   Select Case name
    Case "ID": input.ID=value
    Case "runat"
    Case "CssClass": input.CssClass=value
    Case "Width": input.Width=Unit.Parse(value,Globalization.CultureInfo.InvariantCulture)
    Case Else: input.Attributes(name)=value
   End Select
  Next
  input.Text="1"
  wrapper.Controls.Add(input)
  card.Controls.Add(wrapper)
  ApplyCatalogCartQuantityState(card,1,-1,cartQuantity)
  Dim buffer As New StringWriter(Globalization.CultureInfo.InvariantCulture)
  Using writer As New HtmlTextWriter(buffer)
   input.RenderControl(writer)
  End Using
  Return New Dictionary(Of String,Object) From {{"html",buffer.ToString()},{"name",If(input.Attributes("aria-label"),"")},{"value",input.Text},{"quantity",cartQuantity},{"id",input.ID}}
 End Function
 Private Function GetCatalogCartQuantity(articleId As Integer, tcId As Integer) As Decimal
  Throw New Exception("Unexpected data access: known quantity is mandatory")
 End Function
 Private Function FormatCatalogCartQuantity(quantity As Decimal) As String
  Return quantity.ToString("0.####",Globalization.CultureInfo.InvariantCulture)
 End Function
@@QUANTITY@@
@@FIND@@
@@CLASS@@
End Class
Module NativeQuantityHarness
 Sub Main(args As String())
  Dim output As New Dictionary(Of String,Object)()
  For Each version As String In New String(){"before","after"}
   Dim tag As String=File.ReadAllText(Path.Combine(args(0),"quantity." & version & ".ascx"))
   For Each quantity As Decimal In New Decimal(){0D,3D}
    Dim name As String=version & If(quantity=0D,"-empty","-existing")
    Dim result=(New NativeQuantityFixture()).Render(tag,quantity)
    output(name)=result
    File.WriteAllText(Path.Combine(args(0),"quantity-" & name & ".html"),CStr(result("html")),New Text.UTF8Encoding(False))
   Next
  Next
  File.WriteAllText(Path.Combine(args(0),"native-inputs.json"),(New JavaScriptSerializer()).Serialize(output),New Text.UTF8Encoding(False))
 End Sub
End Module
'@
$harness=$harness.Replace('@@QUANTITY@@',$quantityMethod).Replace('@@FIND@@',$findMethod).Replace('@@CLASS@@',$classMethod)
Save-Text 'NativeQuantityHarness.vb' $harness
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$executable=Join-Path $EvidenceDirectory 'NativeQuantityHarness.exe'
$compilerArguments=@('/nologo','/target:exe','/optioninfer+','/codepage:65001','/main:NativeQuantityHarness',('/out:'+$executable))
foreach ($assembly in @('System.dll','System.Core.dll','System.Web.dll','System.Web.Extensions.dll')) { $compilerArguments+=('/reference:'+(Join-Path $framework $assembly)) }
$compilerArguments+=(Join-Path $EvidenceDirectory 'NativeQuantityHarness.vb')
$compilerOutput=@(& (Join-Path $framework 'vbc.exe') @compilerArguments 2>&1)
Save-Text 'compile.log' ($compilerOutput -join "`r`n")
Assert-Source 'real .NET Framework WebForms quantity harness compiled' ($LASTEXITCODE -eq 0)
& $executable $EvidenceDirectory
Assert-Source 'real System.Web TextBox renderer executed without data access' ($LASTEXITCODE -eq 0)
$native=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'native-inputs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Source 'baseline empty-cart native textbox has no accessible name' ($native.'before-empty'.name -ceq '')
Assert-Source 'candidate empty-cart native textbox has requested accessible name' ($native.'after-empty'.name -ceq $quantityName)
Assert-Source 'existing positive-cart native textbox override remains unchanged' (($native.'before-existing'.name -ceq $native.'after-existing'.name) -and ($native.'after-existing'.name -ceq 'Quantita da aggiungere. Nel carrello: 3'))
Assert-Source 'existing positive-cart rendered HTML remains identical' ($native.'before-existing'.html -ceq $native.'after-existing'.html)
Assert-Source 'initial input value and ID preserved' (($native.'after-empty'.value -ceq '1') -and ($native.'before-empty'.value -ceq '1') -and ($native.'after-empty'.id -ceq $native.'before-empty'.id))
Assert-Source 'positive-cart input value preserved' (($native.'after-existing'.value -ceq '3') -and ($native.'before-existing'.value -ceq '3'))
$report=[pscustomobject]@{
    result='PASS';baseline=$BaselineRef;assertionCount=$assertions.Count;assertions=$assertions.ToArray()
    evidence='Source guards plus compiled extracted page methods and real System.Web.UI.WebControls.TextBox rendering on .NET Framework'
    sourceAdapter='ASP TextBox attributes are read from exact source tags; no hosted ASP.NET page or full ProductCard is claimed by this harness'
    limitations=@('Synthetic local rendering only','No IIS/MySQL/HTTP/browser or operational commercial mutation','Full source precompile and browser focus regression are separate gates')
    outputs=@('ProductCard.before.ascx','ProductCard.after.ascx','quantity-before-empty.html','quantity-after-empty.html','quantity-before-existing.html','quantity-after-existing.html','native-inputs.json','NativeQuantityHarness.vb','compile.log')
}
Save-Text 'source-report.json' ($report | ConvertTo-Json -Depth 8)
$report | Select-Object result,baseline,assertionCount | ConvertTo-Json
