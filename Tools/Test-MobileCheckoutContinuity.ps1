[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = 'a64eb4f76ca68ece3f26e87aefc295ef6075cff3',
    [string]$PriorNativeFragmentsPath
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 / .NET Framework.' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (!$EvidenceDirectory.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence must be outside the repository in TEMP.' }
if (Test-Path -LiteralPath $EvidenceDirectory) {
    if (@(Get-ChildItem -LiteralPath $EvidenceDirectory -Force).Count -gt 0) { throw 'Evidence directory must be new or empty.' }
} else {
    New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
}
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok) {
    $checks.Add([pscustomobject]@{name=$name;pass=$ok})
    if (!$ok) { throw ('MOBILE_CHECKOUT_ASSERT: ' + $name) }
}
function SaveJson([string]$name,$data) { [IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($data|ConvertTo-Json -Depth 18),$utf8) }
function Source([string]$path) { [IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)) }
function Normalize([string]$value) { $value.Replace("`r`n","`n") }
function BaseSource([string]$path) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command git.exe -ErrorAction Stop).Source
    $info.WorkingDirectory = $RepositoryRoot
    $info.Arguments = 'show "' + $BaseRef + ':' + $path + '"'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.StandardOutputEncoding=$utf8
    $process=[Diagnostics.Process]::Start($info)
    try {
        $result=$process.StandardOutput.ReadToEnd(); $diagnostic=$process.StandardError.ReadToEnd(); $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw ('Baseline unavailable: ' + $path) }
        return $result
    } finally { $process.Dispose() }
}
function ControlBlocks([string]$source,[string]$id) {
    # ASP.NET expressions contain >; use a quoted-attribute-aware opening token.
    $pattern='(?s)<asp:(?<kind>\w+)\b(?=[^>]*\bID="'+[regex]::Escape($id)+'")(?<attrs>(?:"[^"]*"|''[^'']*''|[^''">])*)>'
    $result=@()
    foreach($m in [regex]::Matches($source,$pattern)) {
        $text=''; $markup=$m.Value
        if (!$markup.EndsWith('/>')) {
            $end=$source.IndexOf('</asp:'+$m.Groups['kind'].Value+'>',$m.Index+$m.Length,[StringComparison]::OrdinalIgnoreCase)
            if($end -lt 0){throw ('Unclosed control: '+$id)}
            $text=$source.Substring($m.Index+$m.Length,$end-$m.Index-$m.Length)
            $markup=$source.Substring($m.Index,$end+$m.Groups['kind'].Value.Length+7-$m.Index)
        }
        $attrs=[ordered]@{}
        foreach($a in [regex]::Matches($m.Groups['attrs'].Value,'(?<name>[\w:-]+)\s*=\s*(?:"(?<double>[^"]*)"|''(?<single>[^'']*)'')')) {
            $attrs[$a.Groups['name'].Value]=if($a.Groups['double'].Success){$a.Groups['double'].Value}else{$a.Groups['single'].Value}
        }
        $result+=,[pscustomobject]@{kind=$m.Groups['kind'].Value;attributes=$attrs;text=$text;markup=$markup}
    }
    return $result
}
Add-Type -AssemblyName System.Web
$source=Source 'carrello.aspx'; $baseline=BaseSource 'carrello.aspx'; $vb=Source 'carrello.aspx.vb'
$terms=[regex]::Match($vb,'(?s)    Private Function TermsConsentAccepted\(\) As Boolean.*?    End Function').Value
Check 'real authoritative consent method found' (![string]::IsNullOrWhiteSpace($terms))
$native=@'
Imports System
Imports System.IO
Imports System.Collections.Generic
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Public Class MobileNamingScope
    Inherits Panel
    Implements INamingContainer
End Class
Public Class MobileRenderPage
    Inherits Page
    Public Overrides Sub VerifyRenderingInServerForm(control As Control)
        ' Rendering and synthetic events only; no application page, DB or order.
    End Sub
End Class
Public Class MobileCheckoutFixture
    Private chkTermsConsent As CheckBox
    Private clicks As Integer
    Private commands As Integer
    Private validations As Integer
    Private lastCommand As String
    Public Function Accepted(mode As Integer) As Boolean
        chkTermsConsent=If(mode < 0,Nothing,New CheckBox With {.Checked=mode > 0})
        Return TermsConsentAccepted()
    End Function
    Private Function Attach(control As Control, scopePath As String) As MobileRenderPage
        Dim page As New MobileRenderPage With {.EnableEventValidation=False}
        Dim form As New HtmlForm With {.ID="form1"}
        page.Controls.Add(form)
        Dim parent As Control=form
        For Each segment As String In scopePath.Split("/"c)
            Dim scope As New MobileNamingScope With {.ID=segment}
            parent.Controls.Add(scope)
            parent=scope
        Next
        parent.Controls.Add(control)
        If TypeOf control Is Button OrElse TypeOf control Is LinkButton Then
            Dim validator As New CustomValidator With {.ID="cvCheckoutTerms",.ValidationGroup="checkoutSubmit",.EnableClientScript=False,.Display=ValidatorDisplay.None}
            parent.Controls.Add(validator)
            page.Validators.Add(validator)
            AddHandler validator.ServerValidate,AddressOf Validated
        End If
        Return page
    End Function
    Private Sub Attributes(control As WebControl, keys As String(), values As String())
        For i As Integer=0 To keys.Length-1
            Dim key As String=keys(i), value As String=values(i)
            Select Case key.ToLowerInvariant()
                Case "runat","onclick","onselectedindexchanged","imageurl","navigateurl","alternatetext"
                    ' Event handlers remain in source. Product bindings use synthetic fixture data below.
                Case Else
                    Dim prop=control.GetType().GetProperty(key,Reflection.BindingFlags.Public Or Reflection.BindingFlags.Instance Or Reflection.BindingFlags.IgnoreCase)
                    If prop IsNot Nothing AndAlso prop.CanWrite Then
                        If prop.PropertyType Is GetType(String) Then
                            prop.SetValue(control,value,Nothing)
                        ElseIf prop.PropertyType Is GetType(Boolean) Then
                            prop.SetValue(control,Boolean.Parse(value),Nothing)
                        ElseIf prop.PropertyType Is GetType(Integer) Then
                            prop.SetValue(control,Integer.Parse(value,Globalization.CultureInfo.InvariantCulture),Nothing)
                        ElseIf prop.PropertyType.IsEnum Then
                            prop.SetValue(control,[Enum].Parse(prop.PropertyType,value,True),Nothing)
                        ElseIf prop.PropertyType Is GetType(Unit) Then
                            prop.SetValue(control,Unit.Parse(value,Globalization.CultureInfo.InvariantCulture),Nothing)
                        End If
                    Else
                        control.Attributes(key)=value
                    End If
            End Select
        Next
    End Sub
    Private Function Make(kind As String, text As String, keys As String(), values As String()) As WebControl
        Dim control As WebControl
        Select Case kind
            Case "Button": control=New Button With {.Text=text}
            Case "LinkButton": control=New LinkButton With {.Text=text}
            Case "DropDownList": control=New DropDownList
            Case "TextBox": control=New TextBox
            Case "HyperLink": control=New HyperLink
            Case Else: Throw New InvalidOperationException("Unsupported native control: "+kind)
        End Select
        Attributes(control,keys,values)
        Return control
    End Function
    Public Function Fragment(kind As String,text As String,keys As String(),values As String(),scopePath As String,visible As Boolean,disabled As Boolean,product As String,imageAlt As Boolean) As String()
        Dim control=Make(kind,text,keys,values)
        control.Visible=visible
        control.Enabled=Not disabled
        If TypeOf control Is DropDownList Then
            Dim ddl=DirectCast(control,DropDownList)
            ddl.Items.Add(New ListItem("Citta selezionata - "+product,"fixture-city"))
            ddl.Items.Add(New ListItem("Seconda localita ""Q"" & dintorni","fixture-other"))
        ElseIf TypeOf control Is TextBox Then
            DirectCast(control,TextBox).Text=If(control.ID="tbQta","2",If(control.ID="txtNoteSpedizione","Consegna ""Q"" & dettagli <test>","Citta fixture"))
        ElseIf TypeOf control Is HyperLink Then
            Dim link=DirectCast(control,HyperLink)
            link.NavigateUrl="/articolo.aspx?id=101&TCid=0"
            link.Controls.Add(New Image With {.ID="Image2",.ImageUrl="/fixture-product.svg",.AlternateText=If(imageAlt,product,"")})
        End If
        Dim page=Attach(control,scopePath)
        Dim output As New StringWriter
        control.RenderControl(New HtmlTextWriter(output))
        Return New String(){output.ToString(),control.ClientID,control.UniqueID}
    End Function
    Private Sub Clicked(sender As Object,e As EventArgs)
        clicks+=1
    End Sub
    Private Sub Commanded(sender As Object,e As CommandEventArgs)
        commands+=1
        lastCommand=e.CommandName
    End Sub
    Private Sub Validated(sender As Object,e As ServerValidateEventArgs)
        validations+=1
        e.IsValid=True
    End Sub
    Public Function Events(kind As String,text As String,keys As String(),values As String()) As String
        Dim control=Make(kind,text,keys,values)
        Dim page=Attach(control,"MainContent")
        clicks=0:commands=0:validations=0:lastCommand=""
        If TypeOf control Is Button Then
            AddHandler DirectCast(control,Button).Click,AddressOf Clicked
            AddHandler DirectCast(control,Button).Command,AddressOf Commanded
        Else
            AddHandler DirectCast(control,LinkButton).Click,AddressOf Clicked
            AddHandler DirectCast(control,LinkButton).Command,AddressOf Commanded
        End If
        DirectCast(control,IPostBackEventHandler).RaisePostBackEvent("")
        Return clicks.ToString()+"|"+commands.ToString()+"|"+lastCommand+"|"+validations.ToString()
    End Function
__TERMS__
End Class
'@
$native=$native.Replace('__TERMS__',$terms)
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
$options=New-Object CodeDom.Compiler.CompilerParameters
$options.GenerateInMemory=$true
$options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($EvidenceDirectory,$false)
$options.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
@('System.dll','System.Web.dll')|ForEach-Object {[void]$options.ReferencedAssemblies.Add($_)}
$compiled=$compiler.CompileAssemblyFromSource($options,[string[]]@($native))
if($compiled.Errors.HasErrors){throw (($compiled.Errors|Where-Object {!$_.IsWarning}|ForEach-Object {$_.ErrorText})-join '; ')}
$fixture=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('MobileCheckoutFixture',$true))
Check 'real TermsConsentAccepted rejects missing checkbox' (!$fixture.Accepted(-1))
Check 'real TermsConsentAccepted rejects unchecked checkbox' (!$fixture.Accepted(0))
Check 'real TermsConsentAccepted accepts checked checkbox' ($fixture.Accepted(1))

$specs=@(
    @{key='rowUpdate1';id='LB_Aggiorna';index=0;scope='MainContent/Repeater1/ctl00'},
    @{key='rowUpdate2';id='LB_Aggiorna';index=1;scope='MainContent/Repeater2/ctl00'},
    @{key='rowInput1';id='tbQta';index=0;scope='MainContent/Repeater1/ctl00'},
    @{key='rowInput2';id='tbQta';index=1;scope='MainContent/Repeater2/ctl00'},
    @{key='btAggiorna';id='btAggiorna';index=0;scope='MainContent'},
    @{key='btContinua';id='btContinua';index=0;scope='MainContent'},
    @{key='btCompleta';id='btCompleta';index=0;scope='MainContent'},
    @{key='btnVaiConfermaOrdine';id='btnVaiConfermaOrdine';index=0;scope='MainContent'},
    @{key='btnModificaCheckout';id='btnModificaCheckout';index=0;scope='MainContent'},
    @{key='btInviaOrdine';id='btInviaOrdine';index=0;scope='MainContent'},
    @{key='citySelect';id='ddlCartCittaA';index=0;scope='MainContent'},
    @{key='cityText';id='tbCartCittaA';index=0;scope='MainContent'},
    @{key='notes';id='txtNoteSpedizione';index=0;scope='MainContent'},
    @{key='productImage1';id='HyperLink3';index=0;scope='MainContent/Repeater1/ctl00'},
    @{key='productImage2';id='HyperLink3';index=1;scope='MainContent/Repeater2/ctl00'}
)
$fragments=[ordered]@{baseline=$null;candidate=$null;scope='Synthetic System.Web rendering and control events; no application request, DB, IIS, order or payment.'}
foreach($phase in @('baseline','candidate')) {
    $markup=if($phase -eq 'baseline'){$baseline}else{$source}
    $variants=[ordered]@{}
    foreach($theme in @('Tech','Food')) {
        $product=if($theme -eq 'Tech'){'Workstation "Q" & accessori <test> con descrizione molto lunga per schermi mobili'}else{'Confezione alimentare "Q" & prodotti <test> con descrizione molto lunga per schermi mobili'}
        $controls=[ordered]@{}
        foreach($spec in $specs) {
            $blocks=@(ControlBlocks $markup $spec.id)
            if($blocks.Count -le $spec.index){throw ('Missing source control: '+$spec.key)}
            $block=$blocks[$spec.index]; $attrs=$block.attributes
            $text=if($attrs.Contains('Text')){$attrs['Text']}else{$block.text.Trim()}
            $keys=[string[]]@($attrs.Keys);$values=[string[]]@($attrs.Values)
            $hasAlt=$false
            if($block.kind -eq 'HyperLink') {
                $image=@(ControlBlocks $block.markup 'Image2')
                $hasAlt=$image.Count -eq 1 -and ![string]::IsNullOrWhiteSpace($image[0].attributes['AlternateText'])
            }
            $render=$fixture.Fragment($block.kind,$text,$keys,$values,$spec.scope,$true,$false,$product,$hasAlt)
            $disabled=$fixture.Fragment($block.kind,$text,$keys,$values,$spec.scope,$true,$true,$product,$hasAlt)
            $controls[$spec.key]=[ordered]@{html=$render[0];id=$render[1];name=$render[2];kind=$block.kind;text=$text;attributes=$attrs;disabledHtml=$disabled[0]}
            Check ($phase+' '+$theme+' '+$spec.key+' has native naming-scope id') ($render[1].StartsWith('MainContent_'))
            if($block.kind -in @('Button','LinkButton')) {
                $events=$fixture.Events($block.kind,$text,$keys,$values)
                $command=if($attrs.Contains('CommandName')){$attrs['CommandName']}else{''}
                $validationCount=if($attrs.Contains('ValidationGroup') -and $attrs['ValidationGroup'] -eq 'checkoutSubmit' -and $attrs['CausesValidation'] -eq 'true'){1}else{0}
                Check ($phase+' '+$theme+' '+$spec.key+' Click Command and grouped validation preserved') ($events -ceq ('1|1|'+$command+'|'+$validationCount))
                if($phase -eq 'candidate') {
                    Check ($theme+' '+$spec.key+' native submit without script URL') ($block.kind -eq 'Button' -and $render[0] -match 'type="submit"' -and $render[0] -notmatch '\bhref="javascript:')
                    Check ($theme+' '+$spec.key+' native disabled attribute') ($disabled[0] -match 'disabled="disabled"')
                }
            }
            if($spec.key -like 'productImage*') {
                Check ($phase+' '+$theme+' '+$spec.key+' raw product text never injected') (!$render[0].Contains('<test>'))
                if($phase -eq 'candidate') {
                    $renderedAlt=[regex]::Match($render[0],'\balt="([^"]*)"').Groups[1].Value
                    Check ($theme+' '+$spec.key+' native image name escapes quotes and round trips') ($render[0].Contains('&quot;Q&quot;') -and $render[0].Contains('&amp;') -and [System.Web.HttpUtility]::HtmlDecode($renderedAlt) -ceq $product)
                }
            }
        }
        $cityLabel=[regex]::Match($markup,'<label\b[^\r\n]*tbCartCittaA.ClientID[^\r\n]*</label>').Value
        $cityLabel=$cityLabel.Replace('<%= tbCartCittaA.ClientID %>',$controls.cityText.id)
        $notesLabel=[regex]::Match($markup,'<h5\b[^>]*>Note per l''ordine.*?</h5>').Value
        $notesHelp=[regex]::Match($markup,'<p\b[^>]*>Aggiungi solo le indicazioni utili.*?</p>').Value
        $variants[$theme]=[ordered]@{product=$product;controls=$controls;labels=[ordered]@{city=$cityLabel;notes=$notesLabel;notesHelp=$notesHelp}}
    }
    $fragments[$phase]=[ordered]@{controls=$variants.Tech.controls;variants=$variants}
}
SaveJson 'native-fragments.json' $fragments
if ($PriorNativeFragmentsPath) {
    $prior=[IO.File]::ReadAllText($PriorNativeFragmentsPath) | ConvertFrom-Json
    $sameNativeSemantics=$true
    foreach($phase in @('baseline','candidate')) {
        foreach($theme in @('Tech','Food')) {
            foreach($key in $fragments[$phase].variants[$theme].controls.Keys) {
                $currentControl=$fragments[$phase].variants[$theme].controls[$key]
                $priorControl=$prior.$phase.variants.$theme.controls.$key
                foreach($field in @('html','disabledHtml')) {
                    $currentHtml=$currentControl[$field]
                    if($phase -eq 'candidate' -and $key -in @('rowUpdate1','rowUpdate2')) {
                        $currentHtml=$currentHtml.Replace('ks-cart-qty-fallback tf-btn btn-gray','ks-cart-qty-fallback')
                    }
                    if($currentHtml -cne $priorControl.$field){$sameNativeSemantics=$false}
                }
            }
        }
    }
    Check 'prior native fragments byte identical except two row-button class additions' $sameNativeSemantics
}
foreach($phase in @('baseline','candidate')) {
    foreach($theme in @('Tech','Food')) {
        $html='<!doctype html><html lang="it"><meta charset="utf-8"><title>Synthetic native control fragments</title><body><form method="post" action="/fixture-receiver">'
        foreach($item in $fragments[$phase].variants[$theme].controls.Values){$html+=$item.html+"`n"}
        $html+='</form></body></html>'
        [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($phase+'-'+$theme+'-native.html')),$html,$utf8)
    }
}

# These helpers and commercial handlers are intentionally read-only in this batch.
foreach($path in @('carrello.aspx.vb','Public/ui/controls/MiniCart.ascx','Public/ui/controls/MiniCart.ascx.vb','articolo.aspx','articolo.aspx.vb','Page.master','Page.master.vb','Public/assets/keepstore/js/checkout-ui.js','Public/assets/keepstore/js/cart-ui.js','cart_add.aspx.vb','cart_quantity_async.aspx.vb')) {
    Check ($path+' unchanged from exact baseline') ((Normalize (Source $path)) -ceq (Normalize (BaseSource $path)))
}
Check 'server checkout validator declarations unchanged' ((([regex]::Matches($source,'<asp:CustomValidator\b[^>]*/>')|ForEach-Object {$_.Value}) -join "`n") -ceq (([regex]::Matches($baseline,'<asp:CustomValidator\b[^>]*/>')|ForEach-Object {$_.Value}) -join "`n"))
Check 'inline consent and notes scripts unchanged' ((Normalize (([regex]::Matches($source,'(?s)<script\b[^>]*>.*?</script>')|ForEach-Object {$_.Value}) -join "`n")) -ceq (Normalize (([regex]::Matches($baseline,'(?s)<script\b[^>]*>.*?</script>')|ForEach-Object {$_.Value}) -join "`n")))
$vbChanges=@(& git -C $RepositoryRoot diff --name-only $BaseRef -- '*.vb')
Check 'all VB commercial and helper sources unchanged' ($LASTEXITCODE -eq 0 -and $vbChanges.Count -eq 0)
foreach($path in @('.github/workflows/keepstore-ci.yml','Tools/Invoke-KeepStoreCiGates.ps1')) {
    Check ($path+' unchanged') ((Normalize (Source $path)) -ceq (Normalize (BaseSource $path)))
}
$normalizedCurrent=Normalize $source; $normalizedBase=Normalize $baseline
foreach($id in @('LB_Aggiorna','btAggiorna','btContinua','btnVaiConfermaOrdine','btnModificaCheckout','btInviaOrdine','ddlCartCittaA','txtNoteSpedizione','Image2')) {
    $old=@(ControlBlocks $baseline $id); $new=@(ControlBlocks $source $id)
    Check ($id+' control count preserved') ($old.Count -eq $new.Count -and $old.Count -gt 0)
    for($index=0;$index -lt $old.Count;$index++) {
        $expected=[ordered]@{}
        foreach($key in $old[$index].attributes.Keys){$expected[$key]=$old[$index].attributes[$key]}
        if($id -in @('LB_Aggiorna','btAggiorna','btContinua','btnVaiConfermaOrdine','btnModificaCheckout','btInviaOrdine')) {
            $expected['Text']=$old[$index].text.Trim();$expected['UseSubmitBehavior']='true'
            if($id -eq 'LB_Aggiorna') {$expected['CssClass']+=' tf-btn btn-gray'}
            Check ($id+' only native control type changed') ($old[$index].kind -eq 'LinkButton' -and $new[$index].kind -eq 'Button')
        } elseif($id -eq 'ddlCartCittaA') {
            $expected['aria-labelledby']='ksCartCityLabel'
        } elseif($id -eq 'txtNoteSpedizione') {
            $expected['aria-labelledby']='ksOrderNotesLabel';$expected['aria-describedby']='ksOrderNotesHelp ksOrderNotesCounter'
        } else {
            $expected['AlternateText']='<%# Convert.ToString(Eval("Descrizione1")) %>'
        }
        Check ($id+' attribute count matches exact intended delta') ($expected.Count -eq $new[$index].attributes.Count)
        foreach($key in $expected.Keys) {
            Check ($id+' preserves '+$key) ($new[$index].attributes.Contains($key) -and $new[$index].attributes[$key] -ceq $expected[$key])
        }
        $token='CONTROL_'+$id+'_'+$index
        # Duplicate row controls are equivalent; replace one occurrence at a time.
        $at=$normalizedCurrent.IndexOf((Normalize $new[$index].markup),[StringComparison]::Ordinal)
        if($at -lt 0){throw 'Candidate control normalization failed'}
        $normalizedCurrent=$normalizedCurrent.Remove($at,(Normalize $new[$index].markup).Length).Insert($at,$token)
        $at=$normalizedBase.IndexOf((Normalize $old[$index].markup),[StringComparison]::Ordinal)
        if($at -lt 0){throw 'Baseline control normalization failed'}
        $normalizedBase=$normalizedBase.Remove($at,(Normalize $old[$index].markup).Length).Insert($at,$token)
    }
}
foreach($id in @('ksCartCityLabel','ksOrderNotesLabel','ksOrderNotesHelp')) {
    Check ($id+' unique label anchor') ([regex]::Matches($normalizedCurrent,'\bid="'+$id+'"').Count -eq 1)
    $normalizedCurrent=$normalizedCurrent.Replace(' id="'+$id+'"','')
}
$fallbackPattern='<noscript>\s*<p class="mb-3"><a href="carrello.aspx" class="tf-btn btn-gray">Torna al carrello</a></p>\s*</noscript>'
$fallback=[regex]::Match($normalizedCurrent,$fallbackPattern).Value
Check 'one native GET fallback and no duplicated server control' ([regex]::Matches($normalizedCurrent,$fallbackPattern).Count -eq 1)
$normalizedCurrent=$normalizedCurrent.Replace($fallback,'')
$spinnerPattern='(?s)<div id="spinner_caricamento"[^>]*>\s*<div class="ks-inline-loader-text">.*?</div>\s*<span class="ks-inline-loader"[^>]*></span>\s*</div>'
$spinnerNew=[regex]::Match($normalizedCurrent,$spinnerPattern).Value
$spinnerOld=[regex]::Match($normalizedBase,$spinnerPattern).Value
Check 'same single spinner markup preserved verbatim' (![string]::IsNullOrEmpty($spinnerOld) -and $spinnerNew -ceq $spinnerOld -and [regex]::Matches($normalizedCurrent,$spinnerPattern).Count -eq 1)
$spinnerSiblingPattern='</div>\s*</div>\s*'+$spinnerPattern+'\s*</asp:Panel>\s*</asp:Panel>'
Check 'spinner retains baseline sibling position outside final actions' ([regex]::Matches($normalizedCurrent,$spinnerSiblingPattern).Count -eq 1 -and [regex]::Matches($normalizedBase,$spinnerSiblingPattern).Count -eq 1)
Check 'only intended native fallback and accessible naming markup deltas' (($normalizedCurrent -replace '\s','') -ceq ($normalizedBase -replace '\s',''))
SaveJson 'source-report.json' ([ordered]@{baseRef=$BaseRef;sourceSha256=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'carrello.aspx') -Algorithm SHA256).Hash;checks=$checks.ToArray();scope=$fragments.scope})
Write-Output ('PASS MOBILE_CHECKOUT_SOURCE_NATIVE '+$checks.Count)
