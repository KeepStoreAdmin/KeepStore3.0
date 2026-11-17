[CmdletBinding()]
param([switch]$SkipMutations)

# KS-MYACCOUNT-1A - avanzamento dell'ordine e tracciamento nel dettaglio ordine.
# Fatti verificati (gestionale e LAB): il tracking si salva senza cambiare lo stato (btnSalvaTracking_Click), quindi il passo dipende SOLO da documenti.StatiId; DataTrasporto
# e la data di creazione del documento, non di spedizione: non si mostra; i codici reali sono separati anche da virgola e hanno caratteri di controllo ai bordi.
# Oracolo 1: il VERO modulo App_Code/KeepStoreOrderProgress.vb compilato (Strict) e provato con tabelle scritte a mano: stati -1..9, tracking (separatori, duplicati, limiti, markup,
#   caratteri di controllo), contratto URL (schema, userinfo, segnaposto nell'autorita, percorso/query/frammento, codifica del codice).
# Oracolo 2 (testo del codice, senza commenti): la pagina mostra la barra solo per gli ordini web, con quattro passi, un solo aria-current, testo nascosto per ogni passo, nessuna data
#   di spedizione e nessuna promozione da tracking; i testi del database sono codificati; i collegamenti passano dal modulo; il testo dell'hero non promette piu «prossimi passi».
# Il rendering a 320-1280 px e provato da Test-OrderProgressLayout.ps1. Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'WINDOWS_POWERSHELL_5_1_REQUIRED_FOR_CODEDOM' }
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$rel) {
    $p = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { throw ('FILE_MISSING ' + $rel) }
    return (Norm ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)))
}
function Assert-Source([bool]$condition, [string]$code) { if (-not $condition) { throw $code }; Write-Output ('PASS ' + $code) }
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) { if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }; Write-Output ('PASS MUTATION_DETECTED ' + $code) }
function Strip-VbComments([string]$text) { return (([regex]::Replace($text, "(?m)^[ \t]*'.*$", '')) -replace "(?m)[ \t]+'[^`"\n]*$", '') }
function Show-Failure([string]$id) { if ($env:KS_PROGRESS_TEST_VERBOSE) { Write-Host ('PROGRESS_CASE_FAILED ' + $id) } }

$module = Read-Repo 'App_Code/KeepStoreOrderProgress.vb'
$aspx = Read-Repo 'documentidettaglio.aspx'
$vb = Read-Repo 'documentidettaglio.aspx.vb'
$css = Read-Repo 'Public/assets/keepstore/css/order-ui.css'

# --- Oracolo 1: il modulo compilato -------------------------------------------------------------------------------------------------------------------
$probeSource = @"
Option Strict On
Option Explicit On
Imports System
Imports System.Collections.Generic
Public Class ProgressProbe
    Public Function R(ByVal statiId As Integer) As String
        Dim p As OrderProgress = KeepStoreOrderProgress.Resolve(statiId)
        Return p.Known.ToString() & "|" & p.Cancelled.ToString() & "|" & p.StepNumber.ToString()
    End Function
    Public Function P(ByVal tracking As String) As String
        Dim parts As New List(Of String)()
        For Each t As TrackingToken In KeepStoreOrderProgress.ParseTracking(tracking)
            parts.Add(t.Text & ":" & If(t.Linkable, "L", "N"))
        Next
        Return String.Join("/", parts.ToArray())
    End Function
    Public Function PNothing() As Integer
        Return KeepStoreOrderProgress.ParseTracking(CType(Nothing, String)).Count
    End Function
    Public Function U(ByVal template As String, ByVal code As String) As String
        Return KeepStoreOrderProgress.BuildTrackingUrl(template, code)
    End Function
End Class
"@
function New-ProgressProbe([string]$modText) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($modText, $probeSource))
    if ($c.Errors.HasErrors) { throw ('PROGRESS_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('ProgressProbe', $true))
}
# stato -> noto|annullato|passo
$stateCases = @(
    @(-1, 'False|False|0'), @(0, 'False|False|0'), @(1, 'True|False|1'), @(2, 'True|False|2'), @(3, 'True|True|0'), @(4, 'True|False|4'), @(5, 'True|False|3'), @(6, 'True|False|1'),
    @(7, 'False|False|0'), @(9, 'False|False|0'), @(99, 'False|False|0')
)
$ctl = [string][char]9; $nbsp = [string][char]0x00A0; $esc = [string][char]27
# tracking -> elenco atteso (testo:L = collegabile, N = solo testo)
$trackCases = @(
    @('', ''), @('   ', ''), @('3UW1WHC117829', '3UW1WHC117829:L'), @('  3UW1WHC117829  ', '3UW1WHC117829:L'), @('AAA111;BBB222', 'AAA111:L/BBB222:L'), @('AAA111,BBB222', 'AAA111:L/BBB222:L'),
    @('AAA111, BBB222', 'AAA111:L/BBB222:L'), @('AAA111 ; BBB222 ,CCC333', 'AAA111:L/BBB222:L/CCC333:L'), @('AAA111;;;BBB222', 'AAA111:L/BBB222:L'), @(($ctl + 'AAA111' + $ctl), 'AAA111:L'),
    @(('AAA111' + $esc + 'BBB222'), 'AAA111:L/BBB222:L'), @('aaa111;AAA111', 'aaa111:L'), @('AAA111;BBB222;aaa111', 'AAA111:L/BBB222:L'), @('AB', 'AB:N'), @('A.B.C-123', 'A.B.C-123:N'),
    @('LIC26925278', 'LIC26925278:L'), @('abc_def-123', 'abc_def-123:L'), @(('A' * 40), (('A' * 40) + ':L')), @(('A' * 41), (('A' * 41) + ':N')), @(('A' * 61), (('A' * 60) + ':N')),
    @('<b>x</b>', '<b>x</b>:N'), @('javascript:alert(1)', 'javascript:alert(1):N'), @('AAA111;<script>', 'AAA111:L/<script>:N'), @('Accénto123', 'Accénto123:N'), @('A/B/C123', 'A/B/C123:N'),
    @('a1;a2;a3;a4;a5;a6;a7;a8;a9;a10;a11', 'a1:N/a2:N/a3:N/a4:N/a5:N/a6:N/a7:N/a8:N/a9:N/a10:L'),
    @('AAA111;AAA222;AAA333;AAA444;AAA555;AAA666;AAA777;AAA888;AAA999;AAA000;AAA001', 'AAA111:L/AAA222:L/AAA333:L/AAA444:L/AAA555:L/AAA666:L/AAA777:L/AAA888:L/AAA999:L/AAA000:L')
)
# modello, codice -> url atteso ('' = nessun collegamento)
$urlCases = @(
    @('https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&ChiSono=#ID#&ClienteM', 'ABC123', 'https://vas.brt.it/vas/sped_det_show.hsm?referer=sped_numspe_par.htm&ChiSono=ABC123&ClienteM'),
    @('https://www.dhl.com/it-it/home/tracciabilita.html?tracking-id=#ID#', 'ABC-123', 'https://www.dhl.com/it-it/home/tracciabilita.html?tracking-id=ABC-123'),
    @('https://www.poste.it/cerca/index.html#/risultati-spedizioni/#ID#', 'ABC123', 'https://www.poste.it/cerca/index.html#/risultati-spedizioni/ABC123'),
    @('https://my.liccarditrasporti.com/segui/#ID#', 'LIC26925278', 'https://my.liccarditrasporti.com/segui/LIC26925278'),
    @('http://corriere.example/t/#ID#', 'ABC123', 'http://corriere.example/t/ABC123'), @('  https://corriere.example/t/#ID#  ', 'ABC123', 'https://corriere.example/t/ABC123'),
    @('https://corriere.example/t/#ID#/#ID#', 'ABC123', 'https://corriere.example/t/ABC123/ABC123'),
    @('', 'ABC123', ''), @('   ', 'ABC123', ''), @('https://corriere.example/t/', 'ABC123', ''), @('https://corriere.example/t/#id#', 'ABC123', ''),
    @('javascript:alert(1)//#ID#', 'ABC123', ''), @('data:text/html,#ID#', 'ABC123', ''), @('file:///c:/#ID#', 'ABC123', ''), @('ftp://corriere.example/#ID#', 'ABC123', ''),
    @('/relativo/#ID#', 'ABC123', ''), @('//corriere.example/t/#ID#', 'ABC123', ''), @('corriere.example/t/#ID#', 'ABC123', ''),
    @('https://#ID#@evil.example/', 'ABC123', ''), @('https://user:pw@corriere.example/t/#ID#', 'ABC123', ''), @('https://corriere.example#ID#', 'ABC123', ''), @('https://#ID#.evil.example/x', 'ABC123', ''),
    @('https://corriere.example:#ID#/x', 'ABC123', ''), @('https:///t/#ID#', 'ABC123', ''), @("https://corriere.example/t/#ID#`r`nSet-Cookie: x", 'ABC123', ''), @('https://corriere.example/t/ #ID#', 'ABC123', ''),
    @('https://corriere.example/t/#ID#', '', ''), @('https://corriere.example/t/#ID#', 'A.B', ''), @('https://corriere.example/t/#ID#', 'A/B/C', ''), @('https://corriere.example/t/#ID#', 'AB', ''),
    @('https://corriere.example/t/#ID#', 'A&B=C', ''), @('https://corriere.example/t/#ID#', 'a b c', ''), @('https://corriere.example/t/#ID#', '..', ''), @('https://corriere.example/t/#ID#', ('A' * 41), ''),
    @('https://corriere.example/t/#ID#', 'ABC#123', '')
)
$cache = @{}
function Test-ModuleMatrix([string]$modText) {
    if ($cache.ContainsKey($modText)) { return $cache[$modText] }
    $ok = $true
    try {
        $probe = New-ProgressProbe $modText
        foreach ($c in $stateCases) { if ($probe.R([int]$c[0]) -cne $c[1]) { Show-Failure ('state ' + $c[0]); $ok = $false } }
        foreach ($c in $trackCases) { $got = $probe.P([string]$c[0]); if ($got -cne $c[1]) { Show-Failure ('track [' + $c[0] + '] got [' + $got + ']'); $ok = $false } }
        if ($probe.PNothing() -ne 0) { Show-Failure 'track nothing'; $ok = $false }
        foreach ($c in $urlCases) { $got = $probe.U([string]$c[0], [string]$c[1]); if ($got -cne $c[2]) { Show-Failure ('url [' + $c[0] + '] [' + $c[1] + '] got [' + $got + ']'); $ok = $false } }
        if ($probe.U([NullString]::Value, 'ABC123') -cne '' -or $probe.U('https://corriere.example/t/#ID#', [NullString]::Value) -cne '') { Show-Failure 'url nothing'; $ok = $false }
    } catch { Show-Failure ('exception ' + $_.Exception.Message); $ok = $false }
    $cache[$modText] = $ok
    return $ok
}
function Test-ModuleStructure([string]$text) {
    $code = Strip-VbComments $text
    if ($code -notmatch '(?m)^Public Module KeepStoreOrderProgress\s*$') { return $false }
    foreach ($bad in @('MySqlConnection', 'Session', 'HttpContext', 'ConfigurationManager', 'Request', 'DateTime.Now', 'DataTrasporto')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    if ($code -match 'Tracking\w*\s*As String\)\s*As OrderProgress') { return $false }
    if ($code -notmatch 'Public Function Resolve\(ByVal statiId As Integer\) As OrderProgress') { return $false }
    if ($code -notmatch 'Uri\.EscapeDataString\(' -or $code -match 'UrlEncode') { return $false }
    if ($text -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') { return $false }
    return $true
}
Assert-Source (Test-ModuleMatrix $module) 'O01_THE_REAL_MODULE_MAPS_EVERY_STATE_PARSES_REAL_TRACKING_AND_ONLY_BUILDS_SAFE_LINKS'
Assert-Source (Test-ModuleStructure $module) 'O02_THE_STEP_DEPENDS_ONLY_ON_THE_STATE_THE_LINK_IS_ESCAPED_AS_A_URL_PART_AND_NOTHING_TOUCHES_THE_DATABASE'

# --- Oracolo 2: pagina e code-behind -----------------------------------------------------------------------------------------------------------------
function Test-Page([string]$aspxText, [string]$vbText, [string]$cssText) {
    $a = $aspxText; $v = Strip-VbComments $vbText
    if ($a.Contains('ks-confirm-steps') -or $a.Contains('Prossimi passi') -or $a.Contains('GetTimelineStepCssClass') -or $a.Contains('GetTimelinePaymentText') -or $a.Contains('GetTimelineShippingText')) { Show-Failure 'old timeline'; return $false }
    if ($a -notmatch 'AS DettaglioOrdineWeb' -or $a -notmatch 'LEFT JOIN tipodocumenti dtd ON dtd\.id = vd\.TipoDocumentiId') { Show-Failure 'order type in query'; return $false }
    $i0 = $a.IndexOf('<article class="ks-confirm-card ks-order-progress-card"', [StringComparison]::Ordinal)
    $i1 = $a.IndexOf('<article class="ks-confirm-card ks-order-tracking-card"', [StringComparison]::Ordinal)
    if ($i0 -lt 0 -or $i1 -le $i0) { Show-Failure 'two cards'; return $false }
    $progress = $a.Substring($i0, $i1 - $i0)
    $iEnd = $a.IndexOf('</article>', $i1, [StringComparison]::Ordinal)
    if ($iEnd -lt 0) { return $false }
    $tracking = $a.Substring($i1, $iEnd - $i1)
    if ($progress -notmatch "runat=""server""[^>]*visible='<%# IsOrderDocument\(Eval\(""DettaglioOrdineWeb""\)\) %>'" -and $progress -notmatch "visible='<%# IsOrderDocument\(Eval\(""DettaglioOrdineWeb""\)\) %>'[^>]*runat=""server""") { Show-Failure 'progress only for orders'; return $false }
    if ([regex]::Matches($progress, '<ol class="ks-order-progress"').Count -ne 1 -or [regex]::Matches($progress, '<li\b').Count -ne 4) { Show-Failure 'four steps'; return $false }
    if ([regex]::Matches($progress, 'aria-current').Count -ne 0 -or [regex]::Matches($progress, 'ProgressAriaCurrent\(Eval\("StatiId"\), [1-4]\)').Count -ne 4 -or [regex]::Matches($v, 'aria-current=""step""').Count -ne 1) { Show-Failure 'one aria-current'; return $false }
    if ([regex]::Matches($progress, 'ks-order-progress__sr').Count -ne 4) { Show-Failure 'screen reader text'; return $false }
    foreach ($label in @('Ordine ricevuto', 'In lavorazione', 'Pronto', 'Spedito o consegnato')) { if ($progress -notmatch ('>' + [regex]::Escape($label) + '<')) { Show-Failure ('label ' + $label); return $false } }
    if ($progress -notmatch 'HtmlText\(Eval\("StatiDescrizione1"\)\)' -or $progress -notmatch 'HtmlText\(Eval\("StatiDescrizione2"\)\)') { Show-Failure 'db texts encoded'; return $false }
    if ($progress -match 'Spedito il|DataTrasporto|Consegnato il') { Show-Failure 'shipping date'; return $false }
    if ($progress -notmatch 'Annullato' -or $progress -notmatch 'role="status"' -or $progress -match 'aria-live') { Show-Failure 'cancelled static'; return $false }
    if ($tracking -notmatch 'Dove si trova il tuo ordine' -or $tracking -match 'DataTrasporto|Spedito il') { Show-Failure 'tracking card'; return $false }
    if ($tracking -notmatch 'TrackingHtml\(Eval\("Tracking"\), Eval\("Link_Tracking"\), Eval\("StatiId"\)\)' -or $tracking -notmatch 'HtmlText\(Eval\("VettoriDescrizione"\)\)') { Show-Failure 'tracking via helper and encoded carrier'; return $false }
    if ([regex]::Matches($a, 'Eval\("Tracking"\)').Count -ne 2 -or $a -notmatch 'ShowTrackingCard\(Eval\("DettaglioOrdineWeb"\), Eval\("Tracking"\)\)') { Show-Failure 'raw tracking'; return $false }
    if ($a -notmatch 'order-ui\.css"\) %>\?v=20261117-pay-now-1a' -and $a -notmatch 'order-ui\.css"\) %>\?v=20261117-progress-1a') { Show-Failure 'buster'; return $false }
    if ($a -notmatch 'order-ui\.css"\) %>\?v=20261117-progress-1a') { Show-Failure 'buster changed'; return $false }
    # code-behind
    if ($v -notmatch 'KeepStoreOrderProgress\.Resolve\(' -or $v -notmatch 'KeepStoreOrderProgress\.ParseTracking\(' -or $v -notmatch 'KeepStoreOrderProgress\.BuildTrackingUrl\(') { Show-Failure 'uses module'; return $false }
    if ($v -notmatch 'Protected Function IsOrderDocument\(') { Show-Failure 'IsOrderDocument'; return $false }
    $fn = [regex]::Match($v, '(?s)Protected Function TrackingHtml\(.*?End Function').Value
    if ($fn -eq '' -or $fn -notmatch 'HttpUtility\.HtmlEncode\(' -or $fn -notmatch 'HttpUtility\.HtmlAttributeEncode\(' -or $fn -notmatch 'target=""_blank"" rel=""noopener noreferrer""') { Show-Failure 'tracking html encoded'; return $false }
    if ($fn -match 'Spedito|spedito il|DataTrasporto') { Show-Failure 'tracking says shipped'; return $false }
    if ($fn -notmatch 'Segui la spedizione') { Show-Failure 'link text'; return $false }
    if ($v -match '(?i)prossimi passi') { Show-Failure 'hero promises next steps'; return $false }
    # stili
    if ($cssText -notmatch '(?m)^\.ks-order-progress\s*\{' -or $cssText -notmatch '\.ks-order-progress__sr\s*\{[^}]*position:\s*absolute') { Show-Failure 'css base'; return $false }
    if ($cssText -notmatch '(?s)@media \(min-width: 576px\)\s*\{\s*\.ks-order-progress\s*\{[^}]*grid-template-columns:\s*repeat\(4') { Show-Failure 'css horizontal from 576'; return $false }
    if ($cssText -notmatch '(?s)\.ks-order-tracking__btn\s*\{[^}]*min-height:\s*44px') { Show-Failure 'css 44'; return $false }
    return $true
}
Assert-Source (Test-Page $aspx $vb $css) 'O03_THE_PAGE_SHOWS_A_FOUR_STEP_BAR_ONLY_FOR_ORDERS_NO_SHIPPING_DATE_AND_ENCODED_SAFE_TRACKING_LINKS'

if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED'; exit 0 }

# --- Mutazioni ------------------------------------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'M01_STATE_5_BECOMES_STEP_4'; T = 'module'; Old = 'p.StepNumber = 3'; New = 'p.StepNumber = 4' },
    @{ Id = 'M02_CANCELLED_WITH_A_STEP'; T = 'module'; Old = 'p.Cancelled = True'; New = 'p.Cancelled = True : p.StepNumber = 1' },
    @{ Id = 'M03_UNKNOWN_STATE_IS_KNOWN'; T = 'module'; Old = 'Case Else' + "`n" + '                p.Known = False'; New = 'Case Else' + "`n" + '                p.Known = True' },
    @{ Id = 'M04_STATE_6_BECOMES_STEP_2'; T = 'module'; Old = 'Case 1, 6'; New = 'Case 1' },
    @{ Id = 'M05_NO_COMMA_SEPARATOR'; T = 'module'; Old = '[;,\s]+'; New = '[;\s]+' },
    @{ Id = 'M06_NO_DEDUP'; T = 'module'; Old = 'If seen.Contains(token) Then Continue For'; New = '' },
    @{ Id = 'M07_NO_TOKEN_LIMIT'; T = 'module'; Old = 'If result.Count >= MaxTrackingTokens Then Exit For'; New = '' },
    @{ Id = 'M08_NO_LENGTH_CUT'; T = 'module'; Old = 'token = token.Substring(0, MaxTokenLength)'; New = 'token = token' },
    @{ Id = 'M09_ANY_TOKEN_LINKABLE'; T = 'module'; Old = 'Dim linkable As Boolean = LinkablePattern.IsMatch(token)'; New = 'Dim linkable As Boolean = True' },
    @{ Id = 'M10_CONTROL_CHARS_KEPT'; T = 'module'; Old = 'If Char.IsControl(ch) Then sb.Append(" "c) Else sb.Append(ch)'; New = 'sb.Append(ch)' },
    @{ Id = 'M11_ALLOWS_JAVASCRIPT_SCHEME'; T = 'module'; Old = 'If u.Scheme <> Uri.UriSchemeHttp AndAlso u.Scheme <> Uri.UriSchemeHttps Then Return ""'; New = '' },
    @{ Id = 'M12_ALLOWS_USERINFO'; T = 'module'; Old = 'If Not String.IsNullOrEmpty(u.UserInfo) OrElse '; New = 'If ' },
    @{ Id = 'M13_PLACEHOLDER_IN_HOST_ALLOWED'; T = 'module'; Old = ' OrElse u.Host.IndexOf(Probe, StringComparison.OrdinalIgnoreCase) >= 0'; New = '' },
    @{ Id = 'M14_URLENCODE_INSTEAD_OF_ESCAPEDATASTRING'; T = 'module'; Old = 'Uri.EscapeDataString(code)'; New = 'System.Web.HttpUtility.UrlEncode(code)' },
    @{ Id = 'M15_CODE_NOT_VALIDATED'; T = 'module'; Old = 'If Not LinkablePattern.IsMatch(code) Then Return ""'; New = '' },
    @{ Id = 'M16_TEMPLATE_WITHOUT_PLACEHOLDER_OK'; T = 'module'; Old = 'If t.IndexOf("#ID#", StringComparison.Ordinal) < 0 Then Return ""'; New = '' },
    @{ Id = 'P01_OLD_TIMELINE_BACK'; T = 'aspx'; Old = '<article class="ks-confirm-card ks-order-progress-card"'; New = '<article class="ks-confirm-card ks-order-progress-card ks-confirm-steps"' },
    @{ Id = 'P02_PROGRESS_FOR_EVERY_DOCUMENT'; T = 'aspx'; Old = "visible='<%# IsOrderDocument(Eval(""DettaglioOrdineWeb"")) %>'"; New = '' },
    @{ Id = 'P03_SHIPPING_DATE_SHOWN'; T = 'aspx'; Old = 'Dove si trova il tuo ordine'; New = 'Dove si trova il tuo ordine - Spedito il <%# Eval("DataTrasporto", "{0:d}") %>' },
    @{ Id = 'P04_DB_TEXT_NOT_ENCODED'; T = 'aspx'; Old = 'HtmlText(Eval("StatiDescrizione2"))'; New = 'Eval("StatiDescrizione2")' },
    @{ Id = 'P05_TWO_ARIA_CURRENT'; T = 'aspx'; Old = '<li class=''<%# ProgressStepCss(Eval("StatiId"), 2) %>'''; New = '<li aria-current="step" class=''<%# ProgressStepCss(Eval("StatiId"), 2) %>''' },
    @{ Id = 'P06_RAW_TRACKING'; T = 'aspx'; Old = 'TrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId"))'; New = 'Eval("Tracking")' },
    @{ Id = 'P07_CARRIER_NOT_ENCODED'; T = 'aspx'; Old = 'HtmlText(Eval("VettoriDescrizione"))'; New = 'Eval("VettoriDescrizione")' },
    @{ Id = 'P08_LIVE_REGION_ON_CANCELLED'; T = 'aspx'; Old = 'role="status"'; New = 'role="status" aria-live="assertive"' },
    @{ Id = 'P09_HERO_PROMISES_NEXT_STEPS'; T = 'vb'; Old = 'Trovi qui riepilogo, indirizzi, stato e tracking.'; New = 'Trovi qui riepilogo, indirizzi e prossimi passi.' },
    @{ Id = 'P10_TRACKING_LINK_WITHOUT_REL'; T = 'vb'; Old = 'target=""_blank"" rel=""noopener noreferrer""'; New = 'target=""_blank""' },
    @{ Id = 'P11_TRACKING_SAYS_SHIPPED'; T = 'vb'; Old = 'Segui la spedizione'; New = 'Spedito: segui la spedizione' },
    @{ Id = 'P12_CSS_BUTTON_HEIGHT'; T = 'css'; Old = '.ks-order-tracking__btn{' + "`n" + '    display: inline-flex;' + "`n" + '    min-height: 44px;'; New = '.ks-order-tracking__btn{' + "`n" + '    display: inline-flex;' + "`n" + '    min-height: 30px;' }
)
foreach ($mu in $mutants) {
    $mm = $module; $ma = $aspx; $mv = $vb; $mc = $css
    switch ($mu.T) {
        'module' { $mm = Mutate-Text $module $mu.Old $mu.New $mu.Id }
        'aspx' { $ma = Mutate-Text $aspx $mu.Old $mu.New $mu.Id }
        'vb' { $mv = Mutate-Text $vb $mu.Old $mu.New $mu.Id }
        'css' { $mc = Mutate-Text $css $mu.Old $mu.New $mu.Id }
    }
    if ($mu.T -eq 'module') { $still = (Test-ModuleMatrix $mm) -and (Test-ModuleStructure $mm) } else { $still = Test-Page $ma $mv $mc }
    Assert-Detected $still $mu.Id
}
Write-Output ('PROGRESS_TEST_PASS mutants=' + $mutants.Count)
