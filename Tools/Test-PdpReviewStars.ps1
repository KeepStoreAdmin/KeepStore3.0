[CmdletBinding()]
param()

# PDP-REVIEW-STARS-1A. Recensioni della scheda prodotto: le stelle erano invertite (quelle ottenute uscivano grigie, le altre gialle),
# la testata mostrava sempre cinque stelle grigie e il conteggio diceva "recensioni verificate da KeepStore" anche per recensioni non
# verificate. Tre parti: (A) contratto dei sorgenti, (B) comportamento del modulo puro (compilato), (C) mutazioni. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    aspx = Read-Repo 'articolo.aspx'
    vb   = Read-Repo 'articolo.aspx.vb'
    info = Read-Repo 'App_Code/KeepStorePdpInfo.vb'
}

function Get-Between([string]$text, [string]$from, [string]$to) {
    $i = $text.IndexOf($from); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($to, $i + $from.Length); if ($j -lt 0) { return $text.Substring($i) }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $a = $f.aspx; $v = $f.vb
    # A1 nessuna dicitura di verifica che il sito non fa
    if (($a + $v) -match 'verificat[ae] da KeepStore') { $fail.Add('A1 dicitura "verificate da KeepStore"') }
    if ($a -match 'Il parere di chi ha gi') { $fail.Add('A1 sottotitolo che presume l''acquisto') }
    # A2 stelle di ogni recensione, della media e della testata dal modulo puro
    if ((Get-Between $v 'Private Function BuildReviewStarsHtml' 'End Function') -notmatch 'Return KeepStorePdpInfo\.ReviewStarsHtml\(rating\)') { $fail.Add('A2 stelle della recensione non dal modulo') }
    $bind = Get-Between $v 'Private Sub BindProductReviews' 'End Sub'
    if ($bind -notmatch 'Dim starsHtml As String = KeepStorePdpInfo\.ReviewStarsHtml\(average\)') { $fail.Add('A2 stelle della media') }
    if ($bind -notmatch 'litReviewStars\.Text = starsHtml' -or $bind -notmatch 'litHeaderReviewStars\.Text = starsHtml') { $fail.Add('A2 stelle di media e testata non legate') }
    if ($bind -notmatch 'litReviewCountText\.Text = KeepStorePdpInfo\.ReviewCountText\(reviewCount, verifiedCount\)') { $fail.Add('A2 conteggio non dal modulo') }
    if ($bind -notmatch 'If item\.Verified Then verifiedCount \+= 1') { $fail.Add('A2 recensioni verificate non contate dal dato') }
    $def = Get-Between $v 'Private Sub SetReviewDefaults' 'End Sub'
    if ($def -notmatch 'litReviewStars\.Text = emptyStars' -or $def -notmatch 'litHeaderReviewStars\.Text = emptyStars') { $fail.Add('A2 stelle vuote di partenza') }
    # A3 pagina: niente stelle fisse; la testata porta alla sezione delle recensioni
    if (([regex]::Matches($a, '<li><i class="icon-star text-main-4"></i></li>')).Count -ne 0) { $fail.Add('A3 stelle fisse nella pagina') }
    if ($a -notmatch '<ul class="list-star"><asp:Literal ID="litHeaderReviewStars" runat="server" EnableViewState="false" /></ul>') { $fail.Add('A3 stelle della testata') }
    if ($a -notmatch '<ul class="list-star justify-content-center"><asp:Literal ID="litReviewStars" runat="server" EnableViewState="false" /></ul>') { $fail.Add('A3 stelle della media') }
    if ($a -notmatch '<a class="caption text-main-2 link ks-pdp-review-link" href="#prd-review"><asp:Literal ID="litHeaderReviewText" runat="server" Text="Nessuna recensione" /></a>') { $fail.Add('A3 collegamento alla sezione recensioni') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Collections.Generic
Imports Microsoft.VisualBasic
Public Module ReviewProbe
    Private Function Count(ByVal html As String, ByVal needle As String) As Integer
        Return (html.Length - html.Replace(needle, "").Length) \ needle.Length
    End Function
    Public Function Run() As String
        Dim r As New List(Of String)()
        Dim onStar As String = "<li><i class=""icon-star""></i></li>"
        Dim offStar As String = "<li><i class=""icon-star text-main-4""></i></li>"
        Dim s5 As String = KeepStorePdpInfo.ReviewStarsHtml(5D)
        r.Add("B01=" & (s5 = String.Concat(onStar, onStar, onStar, onStar, onStar)).ToString())
        Dim s1 As String = KeepStorePdpInfo.ReviewStarsHtml(1D)
        r.Add("B02=" & (s1 = String.Concat(onStar, offStar, offStar, offStar, offStar)).ToString())
        r.Add("B03=" & (KeepStorePdpInfo.ReviewStarsHtml(0D) = String.Concat(offStar, offStar, offStar, offStar, offStar)).ToString())
        r.Add("B04=" & (Count(KeepStorePdpInfo.ReviewStarsHtml(4.5D), onStar) = 5 AndAlso Count(KeepStorePdpInfo.ReviewStarsHtml(4.4D), onStar) = 4 AndAlso Count(KeepStorePdpInfo.ReviewStarsHtml(2.5D), onStar) = 3).ToString())
        r.Add("B05=" & (Count(KeepStorePdpInfo.ReviewStarsHtml(-3D), onStar) = 0 AndAlso Count(KeepStorePdpInfo.ReviewStarsHtml(9D), onStar) = 5).ToString())
        r.Add("B06=" & (KeepStorePdpInfo.ReviewCountText(0, 0) = "Ancora nessuna valutazione." AndAlso KeepStorePdpInfo.ReviewCountText(-2, 5) = "Ancora nessuna valutazione.").ToString())
        r.Add("B07=" & (KeepStorePdpInfo.ReviewCountText(1, 0) = "1 recensione" AndAlso KeepStorePdpInfo.ReviewCountText(3, 0) = "3 recensioni").ToString())
        r.Add("B08=" & (KeepStorePdpInfo.ReviewCountText(1, 1) = "1 recensione, con acquisto verificato" AndAlso KeepStorePdpInfo.ReviewCountText(3, 2) = "3 recensioni, 2 con acquisto verificato" AndAlso KeepStorePdpInfo.ReviewCountText(3, 9) = "3 recensioni, 3 con acquisto verificato").ToString())
        r.Add("B09=" & (Not KeepStorePdpInfo.ReviewCountText(4, 0).ToLowerInvariant().Contains("verificat")).ToString())
        Return String.Join(";", r.ToArray())
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $out = [string]$c.CompiledAssembly.GetType('ReviewProbe').GetMethod('Run').Invoke($null, @())
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.info
if (-not ($okSource -and $okBehaviour)) { Write-Host 'PDP_REVIEW_STARS FAIL'; exit 1 }

$mutants = @(
    @{ Id = 'M01_VERIFIED_CLAIM_BACK'; File = 'vb'; Old = 'litReviewCountText.Text = KeepStorePdpInfo.ReviewCountText(reviewCount, verifiedCount)'; New = 'litReviewCountText.Text = reviewCount.ToString() & " recensioni verificate da KeepStore."' },
    @{ Id = 'M02_OLD_STARS'; File = 'vb'; Old = 'Return KeepStorePdpInfo.ReviewStarsHtml(rating)'; New = 'Return ""' },
    @{ Id = 'M03_HEADER_STARS_NOT_BOUND'; File = 'vb'; Old = 'litHeaderReviewStars.Text = starsHtml'; New = '' },
    @{ Id = 'M04_STATIC_STARS'; File = 'aspx'; Old = '<ul class="list-star"><asp:Literal ID="litHeaderReviewStars" runat="server" EnableViewState="false" /></ul>'; New = '<ul class="list-star"><li><i class="icon-star text-main-4"></i></li><asp:Literal ID="litHeaderReviewStars" runat="server" EnableViewState="false" /></ul>' },
    @{ Id = 'M05_NO_LINK'; File = 'aspx'; Old = '<a class="caption text-main-2 link ks-pdp-review-link" href="#prd-review">'; New = '<a class="caption text-main-2 link ks-pdp-review-link" href="#">' },
    @{ Id = 'M06_ALL_VERIFIED'; File = 'vb'; Old = 'If item.Verified Then verifiedCount += 1'; New = 'verifiedCount += 1' },
    @{ Id = 'M07_BOUGHT_CLAIM'; File = 'aspx'; Old = '<p class="ks-pdp-section__lead">Il parere dei clienti.</p>'; New = '<p class="ks-pdp-section__lead">Il parere di chi ha gi&agrave; acquistato.</p>' }
)
$behaviourMutants = @(
    @{ Id = 'N01_STARS_INVERTED'; Old = 'If(i <= full, StarOn, StarOff)'; New = 'If(i <= full, StarOff, StarOn)' },
    @{ Id = 'N03_ROUND_DOWN'; Old = 'MidpointRounding.AwayFromZero'; New = 'MidpointRounding.ToEven' },
    @{ Id = 'N04_VERIFIED_ALWAYS'; Old = 'If shown <= 0 Then Return text'; New = '' },
    @{ Id = 'N05_VERIFIED_OVER_TOTAL'; Old = 'Dim shown As Integer = Math.Min(verified, total)'; New = 'Dim shown As Integer = verified' }
)
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.info.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.info.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'PDP_REVIEW_STARS FAIL (mutanti)'; exit 1 }
Write-Host ('PDP_REVIEW_STARS PASS (' + ($mutants.Count + $behaviourMutants.Count) + ' mutanti)')
exit 0
