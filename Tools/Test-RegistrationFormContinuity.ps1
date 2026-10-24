[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = 'a2e10988fd435884c500424c6a47ea07c447675b',
    [switch]$BaselineOnly
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'Requires Windows PowerShell 5.1 / System.Web.'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
if(!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'Fresh TEMP evidence directory required.'}
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$utf8=New-Object Text.UTF8Encoding($false)
$checks=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$pass){$checks.Add([pscustomobject]@{Name=$name;Pass=$pass});if(!$pass){throw ('REGISTRATION_CONTINUITY_ASSERT: '+$name)}}
function Save([string]$name,[string]$value){$file=Join-Path $EvidenceDirectory $name;[void][IO.Directory]::CreateDirectory((Split-Path -Parent $file));[IO.File]::WriteAllText($file,$value,$utf8)}
function Json([string]$name,$value){Save $name ($value|ConvertTo-Json -Depth 16)}
function Source([string]$name){[IO.File]::ReadAllText((Join-Path $RepositoryRoot $name))}
function BaseSource([string]$name){
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=(Get-Command git.exe -ErrorAction Stop).Source;$info.WorkingDirectory=$RepositoryRoot
    $info.Arguments='show "'+$BaseRef+':'+$name+'"';$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.StandardOutputEncoding=$utf8
    $p=[Diagnostics.Process]::Start($info)
    try{$s=$p.StandardOutput.ReadToEnd();$err=$p.StandardError.ReadToEnd();$p.WaitForExit();if($p.ExitCode -ne 0){throw 'Authorized base unavailable.'};return $s}finally{$p.Dispose()}
}
function Norm([string]$s){$s.Replace("`r`n","`n")}
function Vb([string]$s){
    $value='"'+$s.Replace('"','""').Replace("`r",'" & ChrW(13) & "').Replace("`n",'" & ChrW(10) & "')+'"'
    if($script:expressions){foreach($key in $script:expressions.Keys){$value=$value.Replace($key,'" & CStr('+$script:expressions[$key]+') & "')}}
    return $value
}
function Attributes([string]$s){$a=@{};foreach($m in [regex]::Matches($s,'([\w:-]+)\s*=\s*(?:"([^"]*)"|''([^'']*)'')')){$a[$m.Groups[1].Value]=[System.Web.HttpUtility]::HtmlDecode(($m.Groups[2].Value+$m.Groups[3].Value))};return $a}
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Drawing
$baseline=BaseSource 'registrazione.aspx'
$candidate=Source 'registrazione.aspx'
foreach($path in @('registrazione.aspx.vb','Page.master','Page.master.vb','App_Code/ThemeManager.vb')){
    Check ('unchanged dependency '+$path) ((Norm (Source $path)) -ceq (Norm (BaseSource $path)))
}
function Contracts([string]$s){@([regex]::Matches($s,'(?is)<asp:(?:RequiredFieldValidator|RegularExpressionValidator|CompareValidator)\b(?:(?:"[^"]*"|''[^'']*''|[^>])*)>')|ForEach-Object {$a=Attributes $_.Value;if($a.CssClass -eq 'ks-registration-validation'){$a.Remove('CssClass')};($a.Keys|Sort-Object|ForEach-Object {$_+'='+$a[$_]}) -join '|'} ) -join "`n"}
Check 'all server validator contracts unchanged except UI class' ((Contracts $baseline) -ceq (Contracts $candidate))
function PostbackContracts([string]$s){@([regex]::Matches($s,'(?is)<asp:\w+\b(?:(?:"[^"]*"|''[^'']*''|[^>])*)>')|ForEach-Object {$a=Attributes $_.Value;if($a.ContainsKey('AutoPostBack')){($a.ID+'|'+$a.AutoPostBack+'|'+$a.CausesValidation+'|'+$a.ValidationGroup)}}) -join "`n"}
Check 'AutoPostBack and validation-group contracts unchanged' ((PostbackContracts $baseline) -ceq (PostbackContracts $candidate))
if(!$BaselineOnly){foreach($legacyScript in [regex]::Matches($baseline,'(?is)<script\b[^>]*>.*?</script>')){Check 'legacy script content preserved in candidate' ((Norm $candidate).Contains((Norm $legacyScript.Value)))}}
# Fixture changes below affect only rendering/transport. No application/configuration is copied or loaded.
$support=@'
Imports System
Imports System.IO
Imports System.Collections.Generic
Imports System.Collections
Imports System.ComponentModel
Imports System.Globalization
Imports System.Reflection
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports Microsoft.VisualBasic
Public Class FixtureScope
 Inherits Panel
 Implements INamingContainer
End Class
Public Class PageMaster
End Class
Public Class FixturePage
 Inherits Page
 Public Overrides Sub VerifyRenderingInServerForm(control As Control)
 End Sub
End Class
Public Class FixtureCore
 Public Master As New PageMaster()
 Public P As FixturePage
 Public Scope As FixtureScope
 Public Fields As New Dictionary(Of String, Control)(StringComparer.OrdinalIgnoreCase)
 Public pagetype As String = "Registrazione al sito - DATI SINTETICI"
 Public Sub Start(prefix As String, scopeName As String)
  HttpContext.Current = New HttpContext(New SimpleWorkerRequest("/", Path.GetTempPath(), "registration-fixture.aspx", "", New StringWriter()))
  ' SimpleWorkerRequest has no browser headers: explicitly describe the synthetic modern client.
  ' TextBox/DropDownList gate native AutoPostBack attributes on these System.Web capabilities.
  Dim capabilities As New Hashtable(StringComparer.OrdinalIgnoreCase)
  capabilities("javascript")="true"
  capabilities("ecmascriptversion")="3.0"
  capabilities("w3cdomversion")="1.0"
  capabilities("tagwriter")="System.Web.UI.HtmlTextWriter"
  Dim browser As New HttpBrowserCapabilities With {.Capabilities=capabilities}
  HttpContext.Current.Request.Browser=browser
  P = New FixturePage With {.EnableEventValidation=False, .ClientIDMode=ClientIDMode.AutoID}
  ' Rendering never calls ProcessRequest: bind only its native request/response intrinsics.
  ' Otherwise Page.ClientSupportsJavaScript sees a null _request and silently drops onchange.
  GetType(Page).GetField("_request",BindingFlags.Instance Or BindingFlags.NonPublic).SetValue(P,HttpContext.Current.Request)
  GetType(Page).GetField("_response",BindingFlags.Instance Or BindingFlags.NonPublic).SetValue(P,HttpContext.Current.Response)
  Dim form As New HtmlForm With {.ID="form1"}
  P.Controls.Add(form)
  GetType(Page).GetField("_form",BindingFlags.Instance Or BindingFlags.NonPublic).SetValue(P,form)
  Dim outer As New FixtureScope With {.ID=prefix, .ClientIDMode=ClientIDMode.AutoID}
  form.Controls.Add(outer)
  Scope = New FixtureScope With {.ID=scopeName, .ClientIDMode=ClientIDMode.AutoID}
  outer.Controls.Add(Scope)
 End Sub
 Public Sub Add(c As Control, id As String, parent As String)
  c.ID=id
  Fields.Add(id,c)
  If parent="" Then : Scope.Controls.Add(c) : Else : Fields(parent).Controls.Add(c) : End If
 End Sub
 Public Sub Attr(c As Control, name As String, value As String)
  If name.Equals("ID",StringComparison.OrdinalIgnoreCase) OrElse name.Equals("runat",StringComparison.OrdinalIgnoreCase) Then Return
  If name.Equals("DataSourceID",StringComparison.OrdinalIgnoreCase) OrElse name.Equals("DataTextField",StringComparison.OrdinalIgnoreCase) OrElse name.Equals("DataValueField",StringComparison.OrdinalIgnoreCase) Then Return
  ' Server event subscriptions never execute; native AutoPostBack itself remains intact.
  If name.Equals("OnTextChanged",StringComparison.OrdinalIgnoreCase) OrElse name.Equals("OnCheckedChanged",StringComparison.OrdinalIgnoreCase) OrElse name.Equals("OnSelectedIndexChanged",StringComparison.OrdinalIgnoreCase) Then Return
  Dim target As Object=c
  Dim bits=name.Split("-"c)
  For i As Integer=0 To bits.Length-2
   target=TypeDescriptor.GetProperties(target).Find(bits(i),True).GetValue(target)
  Next
  Dim descriptor=TypeDescriptor.GetProperties(target).Find(bits(bits.Length-1),True)
  If descriptor IsNot Nothing AndAlso Not descriptor.IsReadOnly Then
   descriptor.SetValue(target,descriptor.Converter.ConvertFromInvariantString(value))
  ElseIf TypeOf c Is WebControl Then
   DirectCast(c,WebControl).Attributes(name)=value
  ElseIf TypeOf c Is HtmlControl Then
   DirectCast(c,HtmlControl).Attributes(name)=value
  Else
   Throw New Exception("Unsupported rendering attribute: " & name)
  End If
 End Sub
 Public Function ResolveUrl(value As String) As String
  Return value.Replace("~/","/")
 End Function
 Public Sub Leaf(w As HtmlTextWriter,c As Control)
  c.RenderControl(w)
 End Sub
 Public Sub BeginContainer(w As HtmlTextWriter,c As Control)
  If TypeOf c Is WebControl Then
   DirectCast(c,WebControl).RenderBeginTag(w)
  Else
   Dim h=DirectCast(c,HtmlControl)
   w.AddAttribute("id",c.ClientID)
   For Each key As String In h.Attributes.Keys
    w.AddAttribute(key,h.Attributes(key))
   Next
   w.RenderBeginTag(h.TagName)
  End If
 End Sub
 Public Sub EndContainer(w As HtmlTextWriter)
  w.RenderEndTag()
 End Sub
 Public Sub State(kind As String, different As Boolean, optionalAbsent As Boolean, errors As Boolean)
  DirectCast(Fields("rTipoPrivato"),RadioButton).Checked=(kind="Privato")
  DirectCast(Fields("rTipoAzienda"),RadioButton).Checked=(kind="Azienda")
  DirectCast(Fields("rTipoPubblicaAmministrazione"),RadioButton).Checked=(kind="PA")
  Fields("tbNomeCognome").Visible=(kind="Privato")
  Fields("lblNomeCognome").Visible=(kind="Privato")
  Fields("RequiredFieldValidator7").Visible=(kind="Privato")
  DirectCast(Fields("RequiredFieldValidator16"),BaseValidator).Enabled=(kind="Azienda")
  DirectCast(Fields("RB_IndirizzoSpedizioneUguale"),RadioButton).Checked=Not different
  DirectCast(Fields("RB_IndirizzoSpedizioneDiverso"),RadioButton).Checked=different
  Fields("Panel_IndirizzoSecondario").Visible=different
  DirectCast(Fields("Panel_IndirizzoSecondario"),Panel).Enabled=different
  Fields("tipologiacliente").Visible=False
  Fields("PnlDestinazione").Visible=False
  Fields("TextBoxNote").Visible=False
  For Each id As String In New String(){"imgModAccesso","imgModIndirizzoP","imgModIndirizzoS","imgModFatturaElettronica"}
   Fields(id).Visible=False
  Next
  For Each pair As KeyValuePair(Of String, Control) In Fields
   If TypeOf pair.Value Is DropDownList Then
    Dim list=DirectCast(pair.Value,DropDownList)
    list.Items.Clear()
    list.Items.Add(New ListItem("SYNTHETIC CITY", "SYNTHETIC-CITY"))
    list.Items.Add(New ListItem("SYNTHETIC SECOND CITY", "SYNTHETIC-CITY-2"))
   End If
   If TypeOf pair.Value Is TextBox Then
    Dim text=DirectCast(pair.Value,TextBox)
    If text.TextMode<>TextBoxMode.Password AndAlso text.Visible Then text.Text="SYNTHETIC-" & pair.Key
   End If
   If TypeOf pair.Value Is BaseValidator Then
    DirectCast(pair.Value,BaseValidator).IsValid=Not errors
   End If
  Next
  DirectCast(Fields("tbCap"),TextBox).Text="00100"
  DirectCast(Fields("tbCap2"),TextBox).Text="00200"
  DirectCast(Fields("tbPartitaIva"),TextBox).Text=If(kind="Privato","","12345678901")
  DirectCast(Fields("tbEmail"),TextBox).Text="fixture@example.invalid"
  DirectCast(Fields("tbEmailConferma"),TextBox).Text="fixture@example.invalid"
  DirectCast(Fields("lblUser"),Label).Text=If(errors,"Username sintetico non disponibile","")
  DirectCast(Fields("lblEmail"),Label).Text=If(errors,"Email sintetica non disponibile","")
  Fields("ErrorCondizioni").Visible=errors
  If optionalAbsent Then
   For Each id As String In New String(){"tbCap","tbCodiceFiscale","tbPartitaIva","Panel_Fattura_Elettronica","PnlPrivacy","lblUser","lblEmail"}
    Fields(id).Visible=False
   Next
  End If
 End Sub
End Class
'@
function CompileTemplate([string]$text,[string]$className){
    # These are the two authorized standard master branches; excluded legacy bytes are tested separately.
    $text=[regex]::Replace($text,'(?is)<%\s*If TypeOf Me\.Master Is PageMaster Then\s*%>(.*?)<%\s*Else\s*%>.*?<%\s*End If\s*%>','$1')
    $text=[regex]::Replace($text,'(?is)<%@.*?%>','')
    $text=[regex]::Replace($text,'(?is)<asp:Content\b(?=[^>]*\bID="TitleContent")[^>]*>.*?</asp:Content>','')
    $text=[regex]::Replace($text,'(?is)</?asp:Content\b[^>]*>','')
    $text=[regex]::Replace($text,'(?is)<asp:SqlDataSource\b(?:(?:"[^"]*"|''[^'']*''|[^>])*)>.*?</asp:SqlDataSource>','')
    $text=[regex]::Replace($text,'(?is)<asp:Repeater\b[^>]*>.*?</asp:Repeater>','<a href="/synthetic-legal" target="_blank">Leggi (documento sintetico)</a>')
    $text=[regex]::Replace($text,'(?is)<asp:ListItem\b[^>]*>.*?</asp:ListItem>','')
    # The explicitly excluded standby branch is removed without executing or reproducing it.
    $text=[regex]::Replace($text,'(?is)<%\s*If \(Me\.Session\.Item\("AziendaID"\).*?<%End If\s+End If%>','')
    $script:expressions=@{}
    $text=[regex]::Replace($text,'(?s)<%\s*=\s*(.*?)%>',[Text.RegularExpressions.MatchEvaluator]{param($expressionMatch) $key='KS_FIXTURE_EXPR_'+$script:expressions.Count+'_END';$script:expressions[$key]=$expressionMatch.Groups[1].Value.Trim();return $key})
    $decl=New-Object 'Collections.Generic.List[string]';$init=New-Object 'Collections.Generic.List[string]';$render=New-Object 'Collections.Generic.List[string]'
    $stack=New-Object 'Collections.Generic.List[object]'
    $parent='';$cursor=0
    # Ordinary HTML comments do not suppress ASP.NET server controls; preserve their delimiters as literals.
    $pattern='(?s)<%.*?%>|</?[A-Za-z][\w:-]*(?:(?:"[^"]*"|''[^'']*''|[^>])*)>'
    foreach($m in [regex]::Matches($text,$pattern)){
        if($m.Index -gt $cursor){$render.Add('w.Write('+(Vb $text.Substring($cursor,$m.Index-$cursor))+')')};$cursor=$m.Index+$m.Length;$token=$m.Value
        if($token.StartsWith('<%')){
            $code=$token.Substring(2,$token.Length-4).Trim()
            if($code.StartsWith('=')){$render.Add('w.Write('+ $code.Substring(1).Trim()+')')}
            elseif($code -match '^(?i)(If |End\s*If|Else\b)'){$render.Add($code)}
            else{$render.Add($code)}
            continue
        }
        if($token.StartsWith('<!--')){$render.Add('w.Write('+(Vb $token)+')');continue}
        $tag=[regex]::Match($token,'^</?([\w:-]+)').Groups[1].Value
        if($token.StartsWith('</')){
            if($stack.Count -eq 0){throw ('Unexpected close '+$tag)}
            $item=$stack[$stack.Count-1];$stack.RemoveAt($stack.Count-1)
            if($item.Tag -ine $tag){throw ('Unbalanced actual markup '+$tag+' versus '+$item.Tag)}
            if($item.Server){
                if($item.Container){$render.Add('EndContainer(w)');$render.Add('End If')}
                $parent=$item.Parent
            }else{$render.Add('w.Write('+(Vb $token)+')')}
            continue
        }
        $attrs=Attributes $token;$server=$tag.StartsWith('asp:') -or $attrs.runat -ieq 'server'
        $void=$token.EndsWith('/>') -or $tag -match '^(?i)(br|input|img|meta|link|hr|area|base|embed|wbr|source)$'
        if(!$server){$render.Add('w.Write('+(Vb $token)+')');if(!$void){$stack.Add(@{Tag=$tag;Server=$false})};continue}
        $id=$attrs.ID;if(!$id){throw ('Server control without ID '+$tag)}
        $type=if($tag.StartsWith('asp:')){'System.Web.UI.WebControls.'+$tag.Substring(4)}else{'System.Web.UI.HtmlControls.HtmlGenericControl'}
        $container=(!$tag.StartsWith('asp:')) -or $tag -eq 'asp:Panel'
        $creation=if($tag.StartsWith('asp:')){'New '+$type+'()'}else{'New '+$type+'('+(Vb $tag)+')'}
        $decl.Add('Public '+$id+' As '+$type)
        $init.Add($id+'='+$creation);$init.Add('Add('+$id+','+(Vb $id)+','+(Vb $parent)+')')
        foreach($key in $attrs.Keys){$init.Add('Attr('+$id+','+(Vb $key)+','+(Vb $attrs[$key])+')')}
        if($container){$render.Add('If '+$id+'.Visible Then');$render.Add('BeginContainer(w,'+$id+')')}
        else{$render.Add('Leaf(w,'+$id+')')}
        if(!$void){$stack.Add(@{Tag=$tag;Server=$true;Container=$container;Parent=$parent});if($container){$parent=$id}}
    }
    if($cursor -lt $text.Length){$render.Add('w.Write('+(Vb $text.Substring($cursor))+')')}
    if($stack.Count){throw 'Unclosed markup in fixture.'}
    $code=$support+"`nPublic Class $className`nInherits FixtureCore`n"+($decl -join "`n")+"`nPublic Sub New(prefix As String, scopeName As String)`nStart(prefix,scopeName)`n"+($init -join "`n")+"`nEnd Sub`nPublic Function Html() As String`nDim output As New StringWriter()`nDim w As New HtmlTextWriter(output)`n"+($render -join "`n")+"`nReturn output.ToString()`nEnd Function`nEnd Class"
    Save ($className+'.vb') $code
    $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
    $options=New-Object CodeDom.Compiler.CompilerParameters;$options.GenerateInMemory=$true;$options.CompilerOptions='/optioninfer+'
    $options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($EvidenceDirectory,$false)
    @('System.dll','System.Core.dll','System.Web.dll','System.Drawing.dll')|ForEach-Object {[void]$options.ReferencedAssemblies.Add($_)}
    try{$result=$compiler.CompileAssemblyFromSource($options,[string[]]@($code));if($result.Errors.HasErrors){throw (($result.Errors|Where-Object {!$_.IsWarning}|ForEach-Object {$_.Line.ToString()+': '+$_.ErrorText}) -join '; ')};return $result.CompiledAssembly.GetType($className,$true)}finally{$compiler.Dispose()}
}
$css=@('fonts/font.css','icons/icomoon/style.css','css/bootstrap.min.css','css/keepstore.css','css/keepstore-overrides.css','css/account-ui.css','css/documents-ui.css','css/auth-ui.css','css/ks-ui.css','css/nice-select.css','css/swiper-bundle.min.css','css/animate.css','css/styles.css','css/minicart-ui.css','css/theme-overrides.css')
$assets=New-Object 'Collections.Generic.List[object]'
$dependencyNotes=New-Object 'Collections.Generic.List[object]'
foreach($variant in @('baseline','candidate')){foreach($relative in $css){
    $path='Public/assets/keepstore/'+$relative
    $content=if($variant -eq 'baseline'){BaseSource $path}else{Source $path}
    Save ('webroot/'+$variant+'/'+$path) $content
    $assets.Add(@{Variant=$variant;Path=$path;Bytes=$utf8.GetByteCount($content)})
}}
# Follow only local public CSS/font/image dependencies, never configuration or JavaScript.
foreach($variant in @('baseline','candidate')){
    $queue=New-Object 'Collections.Generic.Queue[string]';$seen=@{}
    foreach($relative in $css){$queue.Enqueue('Public/assets/keepstore/'+$relative)}
    while($queue.Count){
        $path=$queue.Dequeue();if($seen.ContainsKey($path)){continue};$seen[$path]=$true
        $content=[IO.File]::ReadAllText((Join-Path $EvidenceDirectory ('webroot/'+$variant+'/'+$path)))
        foreach($urlMatch in [regex]::Matches($content,'(?i)url\(\s*["'']?([^\)"'']+)["'']?\s*\)')){
            $url=$urlMatch.Groups[1].Value.Trim()
            if($url -match '^(data:|https?:|//|#)'){continue}
            $url=($url -split '[?#]')[0]
            if($url -match '(?i)coupon'){continue}
            $sourcePath=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Join-Path $RepositoryRoot $path)) $url))
            if(!$sourcePath.StartsWith((Join-Path $RepositoryRoot 'Public\assets\keepstore\'),[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourcePath) -notmatch '^\.(css|woff2?|ttf|otf|eot|svg|png|gif|jpe?g|webp)$'){continue}
            $relativePath=$sourcePath.Substring($RepositoryRoot.Length+1).Replace('\','/')
            if(!(Test-Path -LiteralPath $sourcePath -PathType Leaf)){$dependencyNotes.Add(@{Path=$relativePath;Status='MISSING_LEGACY_CSS_REFERENCE_NOT_REQUESTED_BY_FORM'});continue}
            $destination=Join-Path $EvidenceDirectory ('webroot/'+$variant+'/'+$relativePath)
            if(!(Test-Path -LiteralPath $destination)){
                if($variant -eq 'baseline'){
                    $baseHash=(git -C $RepositoryRoot rev-parse ($BaseRef+':'+$relativePath) 2>$null)
                    $liveHash=(git -C $RepositoryRoot hash-object -- $relativePath)
                    Check ('baseline public dependency unchanged '+$relativePath) ($LASTEXITCODE -eq 0 -and $baseHash -eq $liveHash)
                }
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination));[IO.File]::Copy($sourcePath,$destination)
                $assets.Add(@{Variant=$variant;Path=$relativePath;Bytes=(Get-Item -LiteralPath $destination).Length})
                if($destination.EndsWith('.css')){$queue.Enqueue($relativePath)}
            }
        }
    }
}
$fixtures=New-Object 'Collections.Generic.List[object]'
$variants=if($BaselineOnly){@('baseline')}else{@('baseline','candidate')}
foreach($variant in $variants){
    $text=if($variant -eq 'baseline'){$baseline}else{$candidate}
    $type=CompileTemplate $text ('RegistrationRender_'+$variant)
    foreach($theme in @('Tech','Food')){foreach($kind in @('Privato','Azienda','PA')){foreach($different in @($false,$true)){foreach($optionalAbsent in @($false,$true)){
        $prefix=if($theme -eq 'Tech'){'techShell7'}else{'foodLayout42'};$scope=if($theme -eq 'Tech'){'MainContent'}else{'NestedRegistration'}
        $fixture=[Activator]::CreateInstance($type,[object[]]@($prefix,$scope));$errors=$kind -ne 'Privato'
        $fixture.State($kind,$different,$optionalAbsent,$errors)
        $body=$fixture.Html()
        $renderedBody=[regex]::Replace($body,'(?s)<!--.*?-->','')
        $fields=@($fixture.Fields.GetEnumerator()|ForEach-Object {
            $c=$_.Value;$nativeTag=[regex]::Match($renderedBody,'<\w+\b[^>]*\bid="'+[regex]::Escape($c.ClientID)+'"[^>]*>');$nativeAttributes=Attributes $nativeTag.Value
            [pscustomobject]@{ID=$_.Key;ClientID=$c.ClientID;UniqueID=$c.UniqueID;PostName=$nativeAttributes.name;OnChange=$nativeAttributes.onchange;OnClick=$nativeAttributes.onclick;OnKeyPress=$nativeAttributes.onkeypress;Type=$c.GetType().FullName;Visible=$c.Visible;Rendered=$nativeTag.Success;AutoPostBack=if($c.PSObject.Properties['AutoPostBack']){$c.AutoPostBack}else{$false};'Password'=($c -is [System.Web.UI.WebControls.TextBox] -and $c.TextMode -eq 'Password')}
        })
        $name=$variant+'-'+$theme.ToLower()+'-'+$kind.ToLower()+'-'+$(if($different){'different'}else{'same'})+'-'+$(if($optionalAbsent){'absent'}else{'full'})
        $links=($css|ForEach-Object {'<link rel="stylesheet" href="/'+$variant+'/Public/assets/keepstore/'+$_+'">'}) -join "`n"
        $html='<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+$links+'<script src="/fixture-transport.js"></script></head><body><form id="form1" name="aspnetForm" method="post" action="/fixture/'+$name+'"><input type="hidden" name="__EVENTTARGET"><input type="hidden" name="__EVENTARGUMENT"><div id="wrapper"><main><div class="ks-account-shell"><aside class="ks-account-aside" aria-label="Menu account"></aside><div class="ks-account-main">'+$body+'</div></div></main></div></form><script>window.registrationFixtureName='+($name|ConvertTo-Json -Compress)+';</script></body></html>'
        Save ('webroot/fixtures/'+$name+'.html') $html
        $fixtures.Add([pscustomobject]@{Name=$name;Variant=$variant;Theme=$theme;Kind=$kind;DifferentShipping=$different;OptionalAbsent=$optionalAbsent;Errors=$errors;Path='fixtures/'+$name+'.html';Fields=$fields})
        Check ($name+' actual form layout retained') ($body.Contains('ks-register-card') -and $body.Contains('<table') -and $body.Contains('REGISTRATI'))
        Check ($name+' native variable ClientID') ($body.Contains($prefix+'_'+$scope+'_tbUsername') -and !$body.Contains('id="ctl00_cph_tbUsername"'))
        foreach($postbackField in @($fields|Where-Object {$_.Rendered -and $_.AutoPostBack -and $_.Type -in @('System.Web.UI.WebControls.TextBox','System.Web.UI.WebControls.DropDownList')})){
            Check ($name+' native onchange '+$postbackField.ID) ($postbackField.OnChange -match '__doPostBack|WebForm_DoPostBackWithOptions')
        }
    }}}}
}
Json 'fixtures-index.json' $fixtures.ToArray()
Json 'public-css-manifest.json' $assets.ToArray()
Json 'css-dependency-notes.json' $dependencyNotes.ToArray()
Save 'webroot/fixture-transport.js' @'
/* Synthetic host/transport only: actual native control event attributes remain in fixture HTML. */
window.WebForm_PostBackOptions=function(target,argument,validation,group,action,trackFocus,clientSubmit){Object.assign(this,{eventTarget:target,eventArgument:argument,validation,validationGroup:group,actionUrl:action,trackFocus,clientSubmit})};
window.Page_ClientValidate=function(){return true};
window.__doPostBack=function(target,argument){const form=document.getElementById('form1');if(typeof form.onsubmit==='function'&&form.onsubmit()===false)return;form.elements.__EVENTTARGET.value=target||'';form.elements.__EVENTARGUMENT.value=argument||'';HTMLFormElement.prototype.submit.call(form)};
window.WebForm_DoPostBackWithOptions=function(options){if(options.clientSubmit)window.__doPostBack(options.eventTarget,options.eventArgument)};
window.WebForm_FireDefaultButton=function(){return true};
window.WebForm_TextBoxKeyHandler=function(){return true};
'@
Json 'transport-contract.json' @{
    Host='Serve only generated webroot via loopback; reject all other origins, filesystem traversal and unsupported methods.'
    GET='/fixture/{Name} returns webroot/fixtures/{Name}.html; /synthetic-legal returns a synthetic privacy/terms document.'
    POST='Receive only synthetic URL-encoded values. Preserve text/select/consent fields by UniqueID on native field map and re-render the same template or selected state template. Never invoke ASPX, code-behind, IIS or an operational server.'
    TypeTransitions='rTipoPrivato/rTipoAzienda/rTipoPubblicaAmministrazione -> matching Kind fixture. Azienda/PA intentionally clear tbNomeCognome as authoritative source does; skip invisible fields. Preserve password fields in browser test only; never write synthetic passwords to logs.'
    ShippingTransitions='RB_IndirizzoSpedizioneDiverso/Uguale -> DifferentShipping true/false. Different clears secondary fields in actual server handler; receiver must model this explicitly and record server-cleared exclusions. Returning same may copy billing fields server-side. Do not attribute these synthetic transitions to WebForms runtime.'
    NativeRenderHost='Render-only Page request/response/form intrinsics bound to synthetic objects using reflection; Request.Browser capabilities explicitly enable ECMAScript3/W3CDOM1. These bindings replace host setup skipped by not invoking ProcessRequest. Native System.Web controls generate onclick/onchange/onkeypress; event strings are not handwritten. No backend lifecycle executes.'
    NativeSourceReference='https://github.com/microsoft/referencesource/blob/main/System.Web/UI/WebControls/TextBox.cs and https://github.com/microsoft/referencesource/blob/main/System.Web/UI/Page.cs: native TextBox gates AutoPostBack on Page.ClientSupportsJavaScript, which depends on bound Page._request; native Page.Form enables asynchronous AutoPostBack dispatch.'
    Limits='Real System.Web native rendering, ClientID/UniqueID/naming containers, markup layout and inline VB rendering conditions. No full WebForms lifecycle, ViewState MAC/event-validation processing, authoritative validation, backend, database, account persistence, email, coupon, IIS or production certification. Client validation dispatcher is stubbed; native attributes preserved.'
}
$vm=@'
'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const dir=process.argv[2],fixtures=JSON.parse(fs.readFileSync(path.join(dir,'fixtures-index.json'),'utf8')),checks=[];
function check(name,pass){checks.push({Name:name,Pass:!!pass});if(!pass)throw Error(name)}
const decode=s=>String(s||'').replace(/&quot;/g,'"').replace(/&#39;|&#x27;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
function mock(f){
 const html=fs.readFileSync(path.join(dir,'webroot',f.Path),'utf8'),visible=html.replace(/<!--[\s\S]*?-->/g,''),nodes={},listeners={},loads=[],errors=[];
 for(const m of visible.matchAll(/<(input|select|textarea|span|label|button)\b([^>]*)>/gi)){
  const attrs={};for(const a of m[2].matchAll(/([\w:-]+)\s*=\s*"([^"]*)"/g))attrs[a[1].toLowerCase()]=decode(a[2]);
  if(!attrs.id)continue;
  const events={},node={id:attrs.id,tagName:m[1].toUpperCase(),type:attrs.type||'text',value:attrs.value||'',checked:'checked'in attrs,disabled:'disabled'in attrs,readOnly:'readonly'in attrs,selectionStart:0,selectionEnd:0,style:{},events,
   addEventListener(name,fn){(events[name]??=[]).push(fn)},getAttribute(name){return attrs[name]??null},removeAttribute(name){delete attrs[name]},setSelectionRange(start,end){this.selectionStart=start;this.selectionEnd=end}};
  nodes[node.id]=node;
 }
 const root={contains:n=>!!n&&nodes[n.id]===n,querySelectorAll:()=>Object.values(nodes).filter(n=>n.tagName==='INPUT'&&(n.getAttribute('onkeyup')||n.getAttribute('onblur')))};
 const document={readyState:'complete',addEventListener(name,fn){(listeners[name]??=[]).push(fn)},getElementById:id=>nodes[id]||null,querySelector:selector=>selector.includes('[data-ks-registration-form="standard"]')&&!html.includes('data-ks-registration-form="standard"')?null:root,aspnetForm:{}};
 const context={document,console,Sys:{Application:{add_load:fn=>loads.push(fn)}}};context.window=context;vm.createContext(context);
 const scripts=[...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)].filter(m=>!m[1].includes('src='));
 function run(){for(const m of scripts){try{vm.runInContext(m[2],context,{timeout:1000})}catch(e){errors.push(String(e.message))}}}
 function fire(name,node,props={}){let prevented=false;const event={target:node,key:'',keyCode:0,preventDefault(){prevented=true},...props};for(const fn of node?.events[name]||[])fn.call(node,event);for(const fn of listeners[name]||[])fn(event);return prevented}
 const field=id=>nodes[f.Fields.find(x=>x.ID===id)?.ClientID]||null;
 return {html,context,nodes,listeners,loads,errors,run,fire,field,root};
}
try{
 for(const f of fixtures){
  const m=mock(f),n=f.Name,initial=JSON.stringify(Object.values(m.nodes).map(x=>[x.id,x.value,x.checked]));m.run();
  if(f.Variant==='baseline'){
   check(n+' baseline null filter startup failure characterized',m.errors.some(e=>/addEventListener/.test(e)));
   for(const name of ['nascondi_errore_username','nascondi_errore_email','compilaAutomaticamente']){let threw=false;try{m.context[name](m.field('tbIndirizzo').id,'nonexistent-target')}catch{threw=true}check(n+' obsolete '+name+' failure characterized',threw)}
   check(n+' baseline Enter suppresses real submit',m.fire('keydown',m.field('btRegistrati'),{key:'Enter',keyCode:13}));
   continue;
  }
  check(n+' candidate startup no exception',m.errors.length===0);
  check(n+' init preserves entered values and checks',initial===JSON.stringify(Object.values(m.nodes).map(x=>[x.id,x.value,x.checked])));
  check(n+' exports idempotent init',typeof m.context.ksRegistrationForm?.init==='function');
  const counts=()=>JSON.stringify({document:Object.fromEntries(Object.entries(m.listeners).map(([k,v])=>[k,v.length])),fields:Object.values(m.nodes).map(x=>[x.id,Object.fromEntries(Object.entries(x.events).map(([k,v])=>[k,v.length]))]),loads:m.loads.length});
  const before=counts();m.context.ksRegistrationForm.init();for(const fn of m.loads)fn();m.run();check(n+' repeated init/scripts add no duplicate handlers',before===counts());
  const bill=m.field('tbIndirizzo'),submit=m.field('btRegistrati'),radio=m.field('rTipoAzienda'),consent=m.field('cbPrivacy');
  check(n+' Enter on editable text suppresses accidental submit',m.fire('keydown',bill,{key:'Enter',keyCode:13}));
  for(const [kind,node]of [['submit',submit],['radio',radio],['consent',consent],['select',m.field('ddlCitta')]])if(node){check(n+' Enter preserves '+kind,m.fire('keydown',node,{key:'Enter',keyCode:13})===false);check(n+' Space preserves '+kind,m.fire('keydown',node,{key:' ',keyCode:32})===false);check(n+' Tab preserves '+kind,m.fire('keydown',node,{key:'Tab',keyCode:9})===false)}
  check(n+' composing Enter preserved',!m.fire('keydown',bill,{key:'Enter',keyCode:13,isComposing:true}));
  for(const name of ['nascondi_errore_username','nascondi_errore_email','privacy','condizioni']){m.context[name]();check(n+' helper '+name+' handles present/absent native controls',true)}
  if(consent){consent.checked=true;m.context.privacy();check(n+' explicit privacy helper accepted marker',m.field('tbPrivacy').value==='ok');consent.checked=false;m.context.privacy();check(n+' explicit privacy helper unchecked marker',m.field('tbPrivacy').value==='')}
  for(const [id,valid,invalid]of [['tbCap','12345','12A'],['tbPartitaIva','Ab123','A-1'],['tbCodiceFiscale','AbC123','A 1']]){
   const field=m.field(id);if(!field)continue;field.value=valid;m.fire('input',field);check(n+' '+id+' prior valid alphabet retained',field.value===valid);field.value=invalid;m.fire('input',field);check(n+' '+id+' invalid alphabet restores last value',field.value===valid);
  }
  const secondary=m.field('tbIndirizzo2');bill.value='SYNTHETIC NEW BILLING';const prior=secondary?.value;m.context.compilaAutomaticamente(bill.id,'obsolete-destination');
  if(f.DifferentShipping&&secondary)check(n+' different shipping never overwritten',secondary.value===prior);
  else check(n+' same shipping absent target tolerated',true);
  if(secondary){
   m.field('RB_IndirizzoSpedizioneUguale').checked=true;m.field('RB_IndirizzoSpedizioneDiverso').checked=false;
   m.context.compilaAutomaticamente(bill.id);check(n+' explicit same-address event uses mapped existing destination',secondary.value===bill.value);
   secondary.readOnly=true;secondary.value='SYNTHETIC SERVER AUTHORITY';bill.value='SYNTHETIC CHANGED';m.context.compilaAutomaticamente(bill.id);check(n+' readonly target preserved',secondary.value==='SYNTHETIC SERVER AUTHORITY');secondary.readOnly=false;
   secondary.disabled=true;m.context.compilaAutomaticamente(bill.id);check(n+' disabled target preserved',secondary.value==='SYNTHETIC SERVER AUTHORITY');
  }
  check(n+' native AutoPostBack not removed by initialization',['rTipoPrivato','rTipoAzienda','rTipoPubblicaAmministrazione'].some(id=>/(__doPostBack|WebForm_DoPostBackWithOptions)/.test(m.field(id).getAttribute('onclick')||'')));
  check(n+' startup remains exception-free after repeated events',m.errors.length===0);
 }
 fs.writeFileSync(path.join(dir,'vm-report.json'),JSON.stringify({Result:'PASS',Count:checks.length,Checks:checks,Limits:'Actual rendered inline scripts executed in node:vm with a small explicit DOM adapter derived from native rendered controls. This validates JS decisions and event binding only; real keyboard/default actions/layout and browser POST navigation require separate Chrome evidence.'},null,2));
 process.stdout.write('REGISTRATION_VM '+checks.length+'/'+checks.length+' PASS\n');
}catch(error){fs.writeFileSync(path.join(dir,'vm-report.json'),JSON.stringify({Result:'FAIL',Count:checks.length,Checks:checks,Error:String(error.stack)},null,2));throw error}
'@
Save 'registration-vm-tests.cjs' $vm
$node=(Get-Command node.exe -ErrorAction Stop).Source
& $node (Join-Path $EvidenceDirectory 'registration-vm-tests.cjs') $EvidenceDirectory
if($LASTEXITCODE -ne 0){throw 'Registration VM tests failed; see vm-report.json.'}
$vmReport=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'vm-report.json') -Raw|ConvertFrom-Json
$sourceHashes=@{};foreach($inputPath in @('registrazione.aspx','Public/assets/keepstore/css/auth-ui.css','Tools/Test-RegistrationFormContinuity.ps1')){$sourceHashes[$inputPath]=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepositoryRoot $inputPath)).Hash}
Json 'test-report.json' @{Result='PASS';Checks=$checks.Count;Details=$checks.ToArray();VMChecks=$vmReport.Count;Fixtures=$fixtures.Count;Base=$BaseRef;SourceSHA256=$sourceHashes;BaselineOnly=[bool]$BaselineOnly;Limits='Browser assertions and synthetic POST receiver are separate evidence; this report certifies fixture generation/static invariants and actual rendered JS via an explicit VM DOM adapter only. Page master public CSS/shell ancestry retained; header/sidebar/footer content omitted. Data-bound option lists and legal documents synthetic. Ordinary HTML-commented server controls instantiated, but absent from browser DOM.'}
Write-Output ('REGISTRATION_CONTINUITY_FIXTURES '+$fixtures.Count+' READY; '+$checks.Count+' static/render checks PASS; '+$vmReport.Count+' VM checks PASS; '+$EvidenceDirectory)
