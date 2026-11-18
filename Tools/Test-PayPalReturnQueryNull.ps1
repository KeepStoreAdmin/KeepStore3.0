[CmdletBinding()]
param()

# PAYPAL-RETURN-NULL-QUERY-1A. Difetto riprodotto dal PO sul sito (2026-11-19): tornando indietro da PayPal senza pagare,
# paypalreturn.aspx?id=..&action=cancel&token=.. mostrava la pagina di errore generica. Causa: Convert.ToString(Request.QueryString("k")).Trim()
# con il parametro k assente: Convert.ToString(String) restituisce Nothing e .Trim() solleva NullReferenceException. Il parametro k esiste solo
# nel rientro del "paga prima": ogni rientro del percorso con documento (annullo E pagamento approvato) andava in errore.
# (A) comportamento: l'espressione vecchia solleva, il lettore nuovo no; (B) sorgente della pagina; (C) mutazioni. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$page = [IO.File]::ReadAllText((Join-Path $root 'paypalreturn.aspx.vb'), $utf8)

function Get-Reader([string]$text) {
    $m = [regex]::Match($text, '(?s)    Private Shared Function QueryText\(.*?End Function')
    if ($m.Success) { return $m.Value } else { return '' }
}

function Test-Behaviour([string]$text, [switch]$Quiet) {
    $reader = Get-Reader $text
    if ($reader -eq '') { if (-not $Quiet) { Write-Host '  FAIL A lettore QueryText assente' }; return $false }
    $src = @"
Imports System
Imports System.Collections.Specialized
Public Class PayPalReturnProbe
$($reader.Replace('Private Shared Function', 'Public Shared Function'))
    Public Shared Function OldExpressionThrows() As Boolean
        Dim query As New NameValueCollection()
        Try
            Dim value As String = Convert.ToString(query("k")).Trim()
            Return False
        Catch ex As NullReferenceException
            Return True
        End Try
    End Function
    Public Shared Function Run() As String
        Dim query As New NameValueCollection()
        query.Add("action", "  cancel ")
        query.Add("empty", "")
        Dim r As String = "A1_difetto_riprodotto=" & OldExpressionThrows().ToString()
        r &= ";A2_assente_vuoto=" & (QueryText(query, "k") = "").ToString()
        r &= ";A3_assente_non_nothing=" & (QueryText(query, "k") IsNot Nothing).ToString()
        r &= ";A4_presente_ripulito=" & (QueryText(query, "action") = "cancel").ToString()
        r &= ";A5_vuoto=" & (QueryText(query, "empty") = "").ToString()
        r &= ";A6_senza_raccolta=" & (QueryText(Nothing, "k") = "").ToString()
        Return r
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($src))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $ok = $true
    try { $out = [string]$c.CompiledAssembly.GetType('PayPalReturnProbe').GetMethod('Run').Invoke($null, @()) } catch { if (-not $Quiet) { Write-Host '  FAIL A il lettore solleva' }; return $false }
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

function Test-Source([string]$text, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    if ($text -match 'Convert\.ToString\(Request\.QueryString\("[A-Za-z]+"\)\)\.') { $fail.Add('B1 lettura della querystring con metodo su un possibile Nothing') }
    if ($text -notmatch 'Dim attemptKey As String = QueryText\(Request\.QueryString, "k"\)') { $fail.Add('B2 chiave del tentativo non letta col lettore') }
    if ($text -notmatch 'PayPalPayFirstGlue\.RunReturn\(HttpContext\.Current, attemptKey, QueryText\(Request\.QueryString, "action"\), Convert\.ToString\(Request\.QueryString\("token"\)\)\)') { $fail.Add('B3 rientro del paga prima') }
    if ($text -notmatch 'Dim actionName As String = QueryText\(Request\.QueryString, "action"\)') { $fail.Add('B4 azione non letta col lettore') }
    # il ramo k resta prima del percorso con documento, e solo con chiave non vuota
    $iKey = $text.IndexOf('If attemptKey.Length > 0 Then'); $iDoc = $text.IndexOf('Dim documentId As Integer = QueryInt("id")')
    if (-not ($iKey -gt 0 -and $iDoc -gt $iKey)) { $fail.Add('B5 ordine dei rami cambiato') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not ((Test-Behaviour $page) -and (Test-Source $page))) { Write-Host 'PAYPAL_RETURN_QUERY_NULL FAIL'; exit 1 }

$mutants = @(
    @{ Id = 'M01_OLD_KEY_READ'; Old = 'Dim attemptKey As String = QueryText(Request.QueryString, "k")'; New = 'Dim attemptKey As String = Convert.ToString(Request.QueryString("k")).Trim()' },
    @{ Id = 'M02_OLD_ACTION_READ'; Old = 'Dim actionName As String = QueryText(Request.QueryString, "action")'; New = 'Dim actionName As String = Convert.ToString(Request.QueryString("action")).Trim()' },
    @{ Id = 'M03_READER_RETURNS_NOTHING'; Old = 'If value Is Nothing Then Return String.Empty'; New = 'If value Is Nothing Then Return Nothing' },
    @{ Id = 'M04_READER_NO_TRIM'; Old = 'Return value.Trim()'; New = 'Return value' },
    @{ Id = 'M05_READER_NO_COLLECTION_GUARD'; Old = 'If query Is Nothing Then Return String.Empty'; New = '' },
    @{ Id = 'M06_READER_NO_NULL_GUARD'; Old = 'If value Is Nothing Then Return String.Empty'; New = '' },
    @{ Id = 'M07_KEY_BRANCH_ALWAYS'; Old = 'If attemptKey.Length > 0 Then'; New = 'If True Then' }
)
$bad = 0
foreach ($mu in $mutants) {
    if (-not $page.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $mutated = $page.Replace($mu.Old, $mu.New)
    if ((Test-Behaviour $mutated -Quiet) -and (Test-Source $mutated -Quiet)) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'PAYPAL_RETURN_QUERY_NULL FAIL (mutanti)'; exit 1 }
Write-Host ('PAYPAL_RETURN_QUERY_NULL PASS (' + $mutants.Count + ' mutanti)')
exit 0
