[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = '4458835840a966e86a14f9aeaeeaba4a8c7b0dcd',
    [switch]$BaselineOnly
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 / .NET Framework.' }
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
if (!$EvidenceDirectory.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence must be outside webroot, in TEMP.' }
if (Test-Path -LiteralPath $EvidenceDirectory) { throw 'Evidence directory must be new.' }
[void](New-Item -ItemType Directory -Path $EvidenceDirectory)
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object 'Collections.Generic.List[object]'
function Check([string]$name, [bool]$pass) {
    $checks.Add([pscustomobject]@{Name=$name;Pass=$pass})
    if (!$pass) { throw ('REGISTRATION_ASSERT: '+$name) }
}
function BaseSource([string]$path) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command git.exe -ErrorAction Stop).Source
    $info.WorkingDirectory = $RepositoryRoot
    $info.Arguments = 'show "'+$BaseRef+':'+$path+'"'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.StandardOutputEncoding=$utf8
    $p = [Diagnostics.Process]::Start($info)
    try {
        $text=$p.StandardOutput.ReadToEnd(); $diagnostic=$p.StandardError.ReadToEnd(); $p.WaitForExit()
        if ($p.ExitCode -ne 0) { throw 'Base source unavailable' }
        return $text.Replace("`r`n","`n")
    } finally { $p.Dispose() }
}
function Source([string]$path) { return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n") }
function Method([string]$text, [string]$name, [string]$kind) {
    $m=[regex]::Match($text,'(?ms)^    (?:Protected|Private) '+$kind+' '+$name+'\(.*?^    End '+$kind)
    if (!$m.Success) { throw ('Method not found: '+$name) }
    return $m.Value
}
function AfterSave([string]$text) {
    $start=$text.IndexOf('            If Not AggiungiUtente(codice) Then', [StringComparison]::Ordinal)
    $finish=$text.IndexOf("        End If`n`n        cmd.Dispose()",$start,[StringComparison]::Ordinal)
    if ($start -lt 0 -or $finish -le $start) { throw 'Post-save boundary not found' }
    return $text.Substring($start,$finish-$start)
}
$base=BaseSource 'registrazione.aspx.vb'
$candidate=Source 'registrazione.aspx.vb'
Add-Type -AssemblyName System.Web
$shared=@'
Imports System
Imports System.IO
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.SessionState
Imports System.Web.UI.WebControls
Public Class RoutingStop
    Inherits Exception
End Class
Public Class RedirectRecorder
    Public Count As Integer
    Public Target As String
    Public Sub Redirect(url As String)
        Count += 1
        Target = url
        ' Simulates the terminating Redirect overload, without Thread.Abort or transport.
        Throw New RoutingStop()
    End Sub
End Class
Public Class MasterChoice
    Public MasterPageFile As String = "~/Page.master"
End Class
Public Class KeepStoreLog
    Public Shared Sub [Error](area As String, message As String, ex As Exception, context As HttpContext)
        ' No real log, request, email or persistence is reached by this fixture.
    End Sub
End Class
Public Class HeaderRequest
    Inherits SimpleWorkerRequest
    Private ReadOnly origin As Uri
    Private ReadOnly referer As String
    Public Sub New(host As String, query As String, header As String)
        MyBase.New("/", "C:\synthetic-registration\", "registrazione.aspx", query, New StringWriter())
        origin = New Uri("https://" & host & "/registrazione.aspx")
        referer = header
    End Sub
    Public Overrides Function GetKnownRequestHeader(index As Integer) As String
        If index = HttpWorkerRequest.HeaderReferer Then Return referer
        If index = HttpWorkerRequest.HeaderHost Then Return origin.Authority
        Return MyBase.GetKnownRequestHeader(index)
    End Function
    Public Overrides Function GetServerName() As String
        Return origin.Host
    End Function
    Public Overrides Function GetLocalPort() As Integer
        Return 443
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return True
    End Function
End Class
'@
$fixture=@'
Imports System
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI.WebControls
Public Class __CLASS__
    Public ReadOnly Request As HttpRequest
    Public ReadOnly Session As HttpSessionState
    Public ReadOnly Response As New RedirectRecorder()
    Public ReadOnly Page As New MasterChoice()
    Public ReadOnly tbUsername As New TextBox()
    Private ReadOnly fixtureContext As HttpContext
    Public SaveCalls As Integer
    Public MailCalls As Integer
    Public SaveResult As Boolean = True
    Public SaveThrows As Boolean
    Public MailThrows As Boolean
    Public Failure As String = ""
    Public Sub New(host As String, query As String, header As String, cart As Integer)
        fixtureContext = New HttpContext(New HeaderRequest(host, query, header))
        Dim container As New HttpSessionStateContainer("SYNTHETIC-REGISTRATION", New SessionStateItemCollection(), New HttpStaticObjectsCollection(), 20, True, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(fixtureContext, container)
        Request = fixtureContext.Request
        Session = fixtureContext.Session
        Session("AziendaID") = If(host = "tech.invalid", 1, 2)
        If cart >= 0 Then Session("StavonelCarrello") = cart
        tbUsername.Text = "SYNTHETIC-USER-" & host
    End Sub
    Public Sub SelectMaster()
        Dim previous As HttpContext = HttpContext.Current
        Try
            HttpContext.Current = fixtureContext
            Page_PreInit(Nothing, EventArgs.Empty)
        Finally
            HttpContext.Current = previous
        End Try
    End Sub
    Public Sub Complete()
        Dim previous As HttpContext = HttpContext.Current
        Try
            HttpContext.Current = fixtureContext
            RunAfterSave()
        Catch ex As RoutingStop
        Catch ex As Exception
            Failure = ex.GetType().Name
        Finally
            HttpContext.Current = previous
        End Try
    End Sub
    Private Function AggiungiUtente(codice As Integer) As Boolean
        SaveCalls += 1
        If SaveThrows Then Throw New InvalidOperationException("SYNTHETIC-SAVE-FAILURE")
        Return SaveResult
    End Function
    Private Sub Email(subject As String, purpose As Integer)
        MailCalls += 1
        If MailThrows Then Throw New InvalidOperationException("SYNTHETIC-MAIL-FAILURE")
    End Sub
    Private Sub RunAfterSave()
        Dim codice As Integer = 1
__POSTSAVE__
    End Sub
__PREINIT__
__HELPER__
End Class
'@
function FixtureSource([string]$name,[string]$text,[bool]$withHelper) {
    $preinit=(Method $text 'Page_PreInit' 'Sub').Replace(' Handles Me.PreInit','')
    $helper=if($withHelper){Method $text 'IsCouponRegistration' 'Function'}else{''}
    return $fixture.Replace('__CLASS__',$name).Replace('__PREINIT__',$preinit).Replace('__HELPER__',$helper).Replace('__POSTSAVE__',(AfterSave $text))
}
$sources=@($shared,(FixtureSource 'BaselineRegistration' $base $false))
if (!$BaselineOnly) {
    $sources += FixtureSource 'CandidateRegistration' $candidate $true
    $confirmation=@'
Imports System
Imports System.Web
Public Class ConfirmationFixture
    Public Request As HttpRequest
    Public Page As New MasterChoice()
    Private _isCouponConfirmation As Boolean
    Public Function SelectMaster(host As String, query As String) As Boolean
        Request = New HttpContext(New HeaderRequest(host, query, Nothing)).Request
        Page_PreInit(Nothing, EventArgs.Empty)
        Return _isCouponConfirmation
    End Function
__PREINIT__
End Class
'@
    $sources += $confirmation.Replace('__PREINIT__',(Method (Source 'registrazioneok.aspx.vb') 'Page_PreInit' 'Sub').Replace(' Handles Me.PreInit',''))
}
$compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
$options=New-Object CodeDom.Compiler.CompilerParameters
$options.GenerateInMemory=$true
$options.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($EvidenceDirectory,$false)
@('System.dll','System.Core.dll','System.Web.dll') | ForEach-Object {[void]$options.ReferencedAssemblies.Add($_)}
$compiled=$compiler.CompileAssemblyFromSource($options,[string[]]$sources)
if ($compiled.Errors.HasErrors) { throw (($compiled.Errors|Where-Object {!$_.IsWarning}|ForEach-Object {$_.ErrorText}) -join '; ') }
function NewFixture([string]$type,[string]$hostName,[string]$query,[AllowNull()][string]$header,[int]$cart) {
    return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType($type,$true),[object[]]@($hostName,$query,$header,$cart))
}
foreach($query in @('','state=coupon')) {
    $f=NewFixture 'BaselineRegistration' 'tech.invalid' $query $null -1
    $f.SelectMaster(); $f.Complete()
    Check ('baseline missing referrer reproduces failure '+$query) ($f.Failure -eq 'NullReferenceException' -and $f.SaveCalls -eq 1 -and $f.MailCalls -eq 1 -and $f.Response.Count -eq 0)
    if ($query) { Check 'baseline coupon master falls back after swallowed failure' ($f.Page.MasterPageFile -eq '~/Page.master') }
}
if (!$BaselineOnly) {
    $baseHelperless=$base.Replace((Method $base 'Page_PreInit' 'Sub'),'PREINIT').Replace((AfterSave $base),'POSTSAVE')
    $newHelperless=$candidate.Replace((Method $candidate 'IsCouponRegistration' 'Function')+"`n`n",'').Replace((Method $candidate 'Page_PreInit' 'Sub'),'PREINIT').Replace((AfterSave $candidate),'POSTSAVE')
    Check 'only helper, PreInit and authorized post-save route changed' ($newHelperless -ceq $baseHelperless)
    $baseSave=AfterSave $base; $newSave=AfterSave $candidate
    Check 'save and email block byte content preserved' ($baseSave.Substring(0,$baseSave.IndexOf("            'Setto")) -ceq $newSave.Substring(0,$newSave.IndexOf("            'Setto")))
    foreach($p in @('registrazione.aspx','registrazioneok.aspx','registrazioneok.aspx.vb','App_Code/PostLoginReturnUrlPolicy.vb')) {
        Check ('unchanged contract '+$p) ((Source $p) -ceq (BaseSource $p))
    }
    $confirm=Source 'registrazioneok.aspx.vb'
    Check 'confirmation coupon/master and login policy unchanged' ($confirm.Contains('String.Equals(stateValues(0), "coupon", StringComparison.OrdinalIgnoreCase)') -and $confirm.Contains('PostLoginReturnUrlPolicy.BuildLoginUrl(Context, safeReturnUrl)'))
    $cases=@(
        @{Name='missing';Query='';Header=$null;Coupon=$false},
        @{Name='explicit coupon missing referrer';Query='state=coupon';Header=$null;Coupon=$true},
        @{Name='legacy coupon';Query='';Header='https://source.invalid/coupon.aspx';Coupon=$true},
        @{Name='ordinary';Query='';Header='https://source.invalid/catalogo.aspx';Coupon=$false},
        @{Name='empty referrer';Query='';Header='';Coupon=$false},
        @{Name='unusable referrer';Query='';Header='not a URI';Coupon=$false},
        @{Name='malformed';Query='';Header='http://[broken';Coupon=$false},
        @{Name='invalid port';Query='';Header='https://source.invalid:wrong/';Coupon=$false},
        @{Name='explicit coupon wins malformed';Query='state=coupon';Header='http://[broken';Coupon=$true},
        @{Name='case matches confirmation';Query='state=COUPON';Header=$null;Coupon=$true},
        @{Name='duplicate state not explicit coupon';Query='state=coupon&state=coupon';Header=$null;Coupon=$false},
        @{Name='unknown state';Query='state=other';Header=$null;Coupon=$false},
        @{Name='external return remains local';Query='redirect=https%3A%2F%2Fother.invalid%2F';Header=$null;Coupon=$false}
    )
    foreach($hostName in @('tech.invalid','food.invalid')) { foreach($case in $cases) { foreach($cart in @(-1,0,1)) {
        $f=NewFixture 'CandidateRegistration' $hostName $case.Query $case.Header $cart
        $f.SelectMaster(); $f.Complete()
        $name=$hostName+' '+$case.Name+' cart='+$cart
        $target=if($cart -eq 1){'carrello.aspx'}elseif($case.Coupon){'registrazioneok.aspx?state=coupon'}else{'registrazioneok.aspx?redirect='+[System.Web.HttpUtility]::ParseQueryString($case.Query)['redirect']}
        Check ($name+' completed once') ($f.Failure -eq '' -and $f.SaveCalls -eq 1 -and $f.MailCalls -eq 1 -and $f.Response.Count -eq 1)
        Check ($name+' destination/priority') ($f.Response.Target -ceq $target)
        Check ($name+' master consistent with coupon') ($f.Page.MasterPageFile -eq $(if($case.Coupon){'Coupon.master'}else{'Page.master'}))
        $uri=New-Object Uri ((New-Object Uri ('https://'+$hostName+'/shop/registrazione.aspx')),$f.Response.Target)
        Check ($name+' same tenant/application') ($uri.Host -eq $hostName -and $uri.AbsolutePath.StartsWith('/shop/') -and $f.Session['AziendaID'] -eq $(if($hostName -eq 'tech.invalid'){1}else{2}))
        if($cart -ne 1){
            $confirmationFixture=[Activator]::CreateInstance($compiled.CompiledAssembly.GetType('ConfirmationFixture',$true))
            Check ($name+' real confirmation PreInit agrees') ($confirmationFixture.SelectMaster($hostName,$uri.Query.TrimStart('?')) -eq $case.Coupon -and $confirmationFixture.Page.MasterPageFile -eq $(if($case.Coupon){'~/Coupon.master'}else{'~/Page.master'}))
        }
        Check ($name+' only existing session effects') ($f.Session.Count -eq $(if($cart -eq 1){2}elseif($case.Coupon){if($cart -ge 0){3}else{2}}else{if($cart -ge 0){2}else{1}}) -and $(if($cart -eq 1){$f.Session['StavonelCarrello'] -eq 0 -and $null -eq $f.Session['Login_User']}elseif($case.Coupon){$f.Session['Login_User'] -ceq $f.tbUsername.Text}else{$null -eq $f.Session['Login_User']}))
    }}}
    foreach($header in @('https://source.invalid/catalogo.aspx','https://source.invalid/coupon.aspx')) { foreach($cart in @(-1,0,1)) {
        $before=NewFixture 'BaselineRegistration' 'tech.invalid' '' $header $cart
        $after=NewFixture 'CandidateRegistration' 'tech.invalid' '' $header $cart
        $before.SelectMaster();$after.SelectMaster();$before.Complete();$after.Complete()
        Check ('legacy before/after route and calls cart='+$cart+' coupon='+$header.Contains('coupon')) ($before.Failure -eq '' -and $after.Failure -eq '' -and $before.Response.Target -ceq $after.Response.Target -and $before.Response.Count -eq $after.Response.Count -and $before.Page.MasterPageFile -eq $after.Page.MasterPageFile -and $before.SaveCalls -eq $after.SaveCalls -and $before.MailCalls -eq $after.MailCalls)
    }}
    foreach($mode in @('save rejected','save throws','mail throws')) {
        $f=NewFixture 'CandidateRegistration' 'tech.invalid' 'state=coupon' $null -1
        if($mode -eq 'save rejected'){$f.SaveResult=$false}
        if($mode -eq 'save throws'){$f.SaveThrows=$true}
        if($mode -eq 'mail throws'){$f.MailThrows=$true}
        $f.Complete()
        if($mode -eq 'mail throws') {
            Check $mode ($f.SaveCalls -eq 1 -and $f.MailCalls -eq 1 -and $f.Response.Count -eq 1 -and $f.Failure -eq '')
        } else {
            Check $mode ($f.SaveCalls -eq 1 -and $f.MailCalls -eq 0 -and $f.Response.Count -eq 0 -and $f.Failure -eq $(if($mode -eq 'save throws'){'InvalidOperationException'}else{''}))
        }
    }
    $a=NewFixture 'CandidateRegistration' 'tech.invalid' 'state=coupon' $null -1
    $b=NewFixture 'CandidateRegistration' 'food.invalid' '' $null 1
    $a.SelectMaster();$b.SelectMaster();$a.Complete();$b.Complete()
    Check 'alternating tenant contexts retain independent session and routing' ($a.Session['AziendaID'] -eq 1 -and $b.Session['AziendaID'] -eq 2 -and $a.Session['Login_User'] -ceq 'SYNTHETIC-USER-tech.invalid' -and $null -eq $b.Session['Login_User'] -and $a.Response.Target -eq 'registrazioneok.aspx?state=coupon' -and $b.Response.Target -eq 'carrello.aspx')
}
$report=@{Result='PASS';BaselineOnly=[bool]$BaselineOnly;Count=$checks.Count;Checks=$checks.ToArray();Limits='Extracted real VB statements and System.Web HTTP/session. Persistence/email and terminating redirect are simulated. No IIS lifecycle, DB, account or send.'}
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'report.json'),($report|ConvertTo-Json -Depth 8),$utf8)
Write-Output ('REGISTRATION_ROUTING_PASS checks='+$checks.Count+' baselineOnly='+[bool]$BaselineOnly)
