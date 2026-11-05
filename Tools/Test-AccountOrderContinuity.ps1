[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaseRef = 'be61c814e0d11d2b5afb2ce42677f093c52686f3'
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Windows PowerShell 5.1 / .NET Framework.' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory)
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (!$EvidenceDirectory.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)) { throw 'A new TEMP evidence directory is required.' }
[void][IO.Directory]::CreateDirectory($EvidenceDirectory)
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('myaccount.aspx.vb','documenti.aspx.vb','documentidettaglio.aspx.vb')
function Extract([string]$source,[string]$name) {
    $matches = [regex]::Matches($source,'(?ms)^\s*(?:Protected|Private|Public) Function '+[regex]::Escape($name)+'\(.*?^\s*End Function')
    if ($matches.Count -ne 1) { throw ('METHOD_NOT_UNIQUE '+$name) }
    return $matches[0].Value
}
$vb = New-Object Text.StringBuilder
[void]$vb.AppendLine('Imports System')
[void]$vb.AppendLine('Imports System.IO')
[void]$vb.AppendLine('Imports System.Text')
[void]$vb.AppendLine('Public Interface IPaymentProbe')
[void]$vb.AppendLine('Function LabelFor(p As Object,s As Object) As String')
[void]$vb.AppendLine('Function CssFor(p As Object,s As Object) As String')
[void]$vb.AppendLine('Function DescriptionFor(p As Object,s As Object,e As Object) As String')
[void]$vb.AppendLine('End Interface')
$structural = @()
for ($i=0; $i -lt $files.Count; $i++) {
    $file=$files[$i]
    $baseline=@(& git.exe -C $RepositoryRoot show ($BaseRef+':'+$file)) -join "`n"
    if ($LASTEXITCODE) { throw ('BASE_SOURCE_UNAVAILABLE '+$file) }
    $candidate=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $file)).Replace("`r`n","`n").TrimEnd("`n")
    $baseline=$baseline.Replace("`r`n","`n").TrimEnd("`n")
    $a=$candidate; $b=$baseline
    foreach($name in @('GetPaymentStatusLabel','GetPaymentStatusDescription')) {
        $a=$a.Replace((Extract $a $name),'<'+$name+'>')
        $b=$b.Replace((Extract $b $name),'<'+$name+'>')
    }
    if ($a -cne $b) { throw ('OUTSIDE_PAYMENT_PRESENTATION_CHANGED '+$file) }
    $structural += [pscustomobject]@{File=$file;OutsideTwoFunctionsIdentical=$true}
    foreach($phase in @('Reference','Current')) {
        $source=if($phase -eq 'Reference'){$baseline}else{$candidate}
        [void]$vb.AppendLine('Public Class '+$phase+$i)
        [void]$vb.AppendLine('Implements IPaymentProbe')
        foreach($name in @('GetPaymentStatusLabel','GetPaymentStatusCssClass','GetPaymentStatusDescription','SafeInt','SafeStatusText')) { [void]$vb.AppendLine((Extract $source $name)) }
        if($i -lt 2) { foreach($name in @('SafePaymentMessage','TruncateText')) { [void]$vb.AppendLine((Extract $source $name)) } }
        [void]$vb.AppendLine('Public Function LabelFor(p As Object,s As Object) As String Implements IPaymentProbe.LabelFor')
        [void]$vb.AppendLine('Return GetPaymentStatusLabel(p,s)')
        [void]$vb.AppendLine('End Function')
        [void]$vb.AppendLine('Public Function CssFor(p As Object,s As Object) As String Implements IPaymentProbe.CssFor')
        [void]$vb.AppendLine('Return GetPaymentStatusCssClass(p,s)')
        [void]$vb.AppendLine('End Function')
        [void]$vb.AppendLine('Public Function DescriptionFor(p As Object,s As Object,e As Object) As String Implements IPaymentProbe.DescriptionFor')
        $args=if($i -eq 0){'p,s,e,"Bonifico sintetico"'}elseif($i -eq 1){'p,s,e,0,"Bonifico sintetico"'}else{'p,s,e'}
        [void]$vb.AppendLine('Return GetPaymentStatusDescription('+$args+')')
        [void]$vb.AppendLine('End Function')
        [void]$vb.AppendLine('End Class')
    }
}
[void]$vb.AppendLine(@'
Public Module Program
    Private checks As Integer
    Private Sub Check(ok As Boolean, name As String)
        If Not ok Then Throw New Exception("ACCOUNT_ORDER_DELTA_FAILED " & name)
        checks += 1
    End Sub
    Public Sub Main(args As String())
        Dim current() As IPaymentProbe = {New Current0(), New Current1(), New Current2()}
        Dim original() As IPaymentProbe = {New Reference0(), New Reference1(), New Reference2()}
        Dim labels() As String = {"Non avviato", "In verifica PayPal", "Pagato", "Non completato", "Annullato dall'utente", "In verifica"}
        Dim rendered As New StringBuilder("phase|page|state|label|css|description" & vbLf)
        For page As Integer = 0 To 2
            Check(original(page).LabelFor(0,99) = "Non avviato", "baseline misclassifies unknown state")
            For state As Integer = 0 To 5
                For paid As Integer = 0 To 1
                    For Each message As String In New String() {"", "Messaggio sintetico registrato"}
                        Check(current(page).LabelFor(paid,state) = original(page).LabelFor(paid,state), "known state label")
                        Check(current(page).CssFor(paid,state) = original(page).CssFor(paid,state), "known state style")
                        Check(current(page).DescriptionFor(paid,state,message) = original(page).DescriptionFor(paid,state,message), "known state description")
                    Next
                Next
                Check(current(page).LabelFor(0,state) = labels(state), "explicit state contract")
            Next
            For Each state As Object In New Object() {99, -7, 6, "bad", DBNull.Value, Nothing, 2147483648D}
                Check(current(page).LabelFor(0,state) = "Non verificabile", "unknown not mapped to unstarted")
                Check(current(page).DescriptionFor(0,state,"") = "Stato del pagamento non verificabile.", "unknown description")
                Check(current(page).DescriptionFor(0,state,"Pagamento confermato.") = "Stato del pagamento non verificabile.", "unknown does not trust stale text")
                Check(current(page).CssFor(0,state) = "ks-status-badge is-muted", "unknown not styled as paid")
                Check(current(page).LabelFor(1,state) = "Pagato", "authoritative paid flag preserved")
                Check(current(page).DescriptionFor(1,state,"") = original(page).DescriptionFor(1,state,""), "paid description unchanged")
            Next
            Check(current(page).LabelFor(0,"2") = "Pagato", "provider numeric string preserved")
            For Each state As Integer In New Integer() {0,1,2,3,4,5,99}
                rendered.AppendLine("before|" & page & "|" & state & "|" & original(page).LabelFor(0,state) & "|" & original(page).CssFor(0,state) & "|" & original(page).DescriptionFor(0,state,""))
                rendered.AppendLine("after|" & page & "|" & state & "|" & current(page).LabelFor(0,state) & "|" & current(page).CssFor(0,state) & "|" & current(page).DescriptionFor(0,state,""))
            Next
        Next
        File.WriteAllText(args(0),rendered.ToString(),New UTF8Encoding(False))
        Console.WriteLine("ACCOUNT_ORDER_DELTA_PASS checks=" & checks)
    End Sub
End Module
'@)
$native=Join-Path $EvidenceDirectory 'PaymentPresentation.vb'
[IO.File]::WriteAllText($native,$vb.ToString(),$utf8)
$exe=Join-Path $EvidenceDirectory 'PaymentPresentation.exe'
& (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe') /nologo /target:exe "/out:$exe" $native
if($LASTEXITCODE){throw 'NATIVE_COMPILE_FAILED'}
$result=@(& $exe (Join-Path $EvidenceDirectory 'render.tsv'))
if($LASTEXITCODE){throw 'NATIVE_TEST_FAILED'}
$structural|ConvertTo-Json|Set-Content (Join-Path $EvidenceDirectory 'invariants.json') -Encoding UTF8
[pscustomobject]@{Result='A';Native=$result;Structural=$structural;Limits='Extracted VB bodies, synthetic values; no WebForms lifecycle, IIS, MySQL, gateway or payment mutation. SQL, authorization, navigation and payment writers unchanged.'}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceDirectory 'result.json') -Encoding UTF8
$result
