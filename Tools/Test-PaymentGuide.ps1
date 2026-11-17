[CmdletBinding()]
param([switch]$SkipMutations)

# PAYPAL-FAILED-PAYMENT-GUIDE-1A - guida visuale nel carrello dopo un pagamento PayPal pay-first non riuscito.
# Oracolo 1: il VERO modulo App_Code/KeepStorePaymentGuide.vb compilato (Strict) con le VERE costanti Msg* lette da App_Code/PayPalPayFirst.vb: ogni costante ha
#   un tipo atteso scritto qui a mano (Retry / Wait / Contact / None); una costante nuova non elencata fa fallire il test (nessuna deriva). Varianti ostili: spazi,
#   maiuscole, prefissi, apostrofo codificato, Nothing, testo dell'avviso prezzi => None.
# Oracolo 2 (testo del codice, senza commenti): il pannello sta PRIMA dell'avviso prezzi, ha tre varianti con i propri passi e collegamenti (Retry = due
#   collegamenti al passo di pagamento, Wait e Contact nessun collegamento di pagamento), nessun LinkButton ne postback, SVG decorativi, un solo role=alert per
#   variante di errore; il code-behind mostra la guida solo con utente loggato e carrello con articoli, codifica il testo, nasconde l'avviso prezzi solo se la guida
#   e resa, e apre il passo di pagamento con la query payguide=1 solo da loggato (stesso modello di pricechanged), richiudendolo a carrello vuoto.
# Il rendering a 320/360/390 px e provato da Test-PaymentGuideLayout.ps1. Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'WINDOWS_POWERSHELL_5_1_REQUIRED_FOR_CODEDOM' }
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) {
    $p = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $p)) { throw ('FILE_MISSING ' + $relativePath) }
    return (Norm ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)))
}
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Mutate-First([string]$text, [string]$pattern, [string]$new, [string]$code) {
    $rx = New-Object Text.RegularExpressions.Regex($pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    $out = $rx.Replace($text, $new.Replace('$', '$$'), 1)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Strip-VbComments([string]$text) { return (([regex]::Replace($text, "(?m)^[ \t]*'.*$", '')) -replace "(?m)[ \t]+'[^`"\n]*$", '') }
function Show-Failure([string]$id) { if ($env:KS_GUIDE_TEST_VERBOSE) { Write-Host ('GUIDE_CASE_FAILED ' + $id) } }

$moduleRel = 'App_Code/KeepStorePaymentGuide.vb'
$payFirst = Read-Repo 'App_Code/PayPalPayFirst.vb'
$module = Read-Repo $moduleRel
$aspx = Read-Repo 'carrello.aspx'
$vb = Read-Repo 'carrello.aspx.vb'
$css = Read-Repo 'Public/assets/keepstore/css/cart-ui.css'

# --- Oracolo 1: il modulo compilato -------------------------------------------------------------------------------------------------------------------
$expectedKind = @{ MsgNotStarted = 'Retry'; MsgCanceled = 'Retry'; MsgExpired = 'Retry'; MsgBusy = 'Wait'; MsgManual = 'Contact'; MsgChanged = 'None'; MsgResubmit = 'None' }
$constMatches = [regex]::Matches($payFirst, '(?m)^\s*Public Const (Msg\w+) As String = "((?:[^"]|"")*)"\s*$')
if ($constMatches.Count -lt 7) { throw 'MSG_CONSTANTS_NOT_FOUND' }
$consts = [ordered]@{}
$stub = New-Object Text.StringBuilder
[void]$stub.AppendLine('Public NotInheritable Class PayPalPayFirstService')
foreach ($m in $constMatches) {
    $consts[$m.Groups[1].Value] = $m.Groups[2].Value.Replace('""', '"')
    [void]$stub.AppendLine('    Public Const ' + $m.Groups[1].Value + ' As String = "' + $m.Groups[2].Value + '"')
}
[void]$stub.AppendLine('End Class')
$unknownConsts = @($consts.Keys | Where-Object { -not $expectedKind.ContainsKey($_) })
if ($unknownConsts.Count -gt 0) { throw ('NEW_MSG_CONSTANT_WITHOUT_GUIDE_DECISION ' + ($unknownConsts -join ',')) }
foreach ($k in $expectedKind.Keys) { if (-not $consts.Contains($k)) { throw ('EXPECTED_CONSTANT_MISSING ' + $k) } }

$probeSource = @"
Option Strict On
Option Explicit On
Imports System
Public Class GuideProbe
    Public Function K(ByVal m As String) As String
        Return KeepStorePaymentGuide.Resolve(m).ToString()
    End Function
End Class
"@
function New-GuideProbe([string]$moduleText) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $stub.ToString(), $probeSource))
    if ($c.Errors.HasErrors) { throw ('GUIDE_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('GuideProbe', $true))
}
$matrixCache = @{}
function Test-KindMatrix([string]$moduleText) {
    if ($matrixCache.ContainsKey($moduleText)) { return $matrixCache[$moduleText] }
    $ok = $false
    try {
        $probe = New-GuideProbe $moduleText
        $ok = $true
        foreach ($k in $consts.Keys) {
            $text = $consts[$k]
            $want = $expectedKind[$k]
            if ($probe.K($text) -cne $want) { Show-Failure ('exact ' + $k); $ok = $false }
            if ($probe.K('  ' + $text + "`r`n") -cne $want) { Show-Failure ('trim ' + $k); $ok = $false }
            if ($probe.K($text.ToUpperInvariant()) -cne 'None') { Show-Failure ('upper ' + $k); $ok = $false }
            if ($probe.K('x' + $text) -cne 'None') { Show-Failure ('prefix ' + $k); $ok = $false }
            if ($probe.K($text + ' x') -cne 'None') { Show-Failure ('suffix ' + $k); $ok = $false }
            if ($probe.K($text.Replace("'", '&#39;')) -cne ($(if ($text.Contains("'")) { 'None' } else { $want }))) { Show-Failure ('encoded ' + $k); $ok = $false }
        }
        if ($probe.K([NullString]::Value) -cne 'None') { Show-Failure 'real null'; $ok = $false }
        foreach ($c in @('', '   ', 'Prezzi modificati: controlla il carrello.', '<script>alert(1)</script>', 'Il pagamento PayPal')) {
            if ($probe.K($c) -cne 'None') { Show-Failure ('other [' + $c + ']'); $ok = $false }
        }
    } catch { Show-Failure ('exception ' + $_.Exception.Message); $ok = $false }
    $matrixCache[$moduleText] = $ok
    return $ok
}
function Test-ModuleStructure([string]$text) {
    $code = Strip-VbComments $text
    if ($code -notmatch '(?m)^Public NotInheritable Class KeepStorePaymentGuide\s*$') { return $false }
    if ($code -notmatch '(?ms)^Public Enum PaymentGuideKind\s*\n\s*None = 0\s*\n\s*Retry = 1\s*\n\s*Wait = 2\s*\n\s*Contact = 3\s*\nEnd Enum') { return $false }
    if ([regex]::Matches($code, '(?m)^\s*Public Shared Function Resolve\(').Count -ne 1) { return $false }
    if ([regex]::Matches($code, 'StringComparison\.Ordinal\)').Count -ne 5) { return $false }
    if ($code.Contains('OrdinalIgnoreCase') -or $code.Contains('InvariantCultureIgnoreCase') -or $code -match '(?i)Option Compare Text') { return $false }
    foreach ($name in @('MsgNotStarted', 'MsgCanceled', 'MsgExpired', 'MsgBusy', 'MsgManual')) {
        if ([regex]::Matches($code, 'PayPalPayFirstService\.' + $name + '\b').Count -ne 1) { return $false }
    }
    foreach ($name in @('MsgChanged', 'MsgResubmit')) { if ($code.Contains($name)) { return $false } }
    if ($code -match '"[^"]{12,}"') { return $false }
    foreach ($bad in @('MySqlConnection', 'Session', 'HttpContext', 'ConfigurationManager', 'Request')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    if ($text -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') { return $false }
    return $true
}

# --- Oracolo 2: pagina e code-behind -----------------------------------------------------------------------------------------------------------------
function Get-Region([string]$text, [string]$startPattern, [string]$endPattern) {
    $m = [regex]::Match($text, '(?s)' + $startPattern + '(.*?)' + $endPattern)
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Test-AspxGuide([string]$text, [string]$cssText) {
    $iGuide = $text.IndexOf('<asp:Panel ID="pnlPaymentGuide"', [StringComparison]::Ordinal)
    $iNotice = $text.IndexOf('<asp:Panel ID="pnlCartPriceRevalidation"', [StringComparison]::Ordinal)
    if ($iGuide -lt 0 -or $iNotice -lt 0 -or $iGuide -ge $iNotice) { Show-Failure 'order'; return $false }
    $guide = $text.Substring($iGuide, $iNotice - $iGuide)
    $retry = Get-Region $guide '<asp:PlaceHolder ID="phGuideRetry"[^>]*>' '</asp:PlaceHolder>'
    $wait = Get-Region $guide '<asp:PlaceHolder ID="phGuideWait"[^>]*>' '</asp:PlaceHolder>'
    $contact = Get-Region $guide '<asp:PlaceHolder ID="phGuideContact"[^>]*>' '</asp:PlaceHolder>'
    if ($null -eq $retry -or $null -eq $wait -or $null -eq $contact) { Show-Failure 'variants'; return $false }
    if ($guide -match '(?i)asp:(LinkButton|Button|ImageButton)') { Show-Failure 'postback control'; return $false }
    if ($guide -match '(?i)\btabindex\b|\bonclick\b|<script') { Show-Failure 'tabindex/onclick/script'; return $false }
    if ([regex]::Matches($guide, 'runat="server"').Count -ne 7) { Show-Failure 'runat count'; return $false }
    foreach ($v in @($retry, $wait, $contact)) {
        if ($v -notmatch '<asp:Literal ID="litPaymentGuideMessage(Retry|Wait|Contact)"[^>]*runat="server"') { Show-Failure 'message literal'; return $false }
        if ($v -notmatch '(?s)<section\b[^>]*aria-labelledby="(ksPayGuide\w+Title)"') { Show-Failure 'aria-labelledby'; return $false }
        $id = [regex]::Match($v, 'aria-labelledby="(ksPayGuide\w+Title)"').Groups[1].Value
        if ([regex]::Matches($v, '<h2\b[^>]*\bid="' + $id + '"').Count -ne 1) { Show-Failure 'h2 id'; return $false }
        if ([regex]::Matches($v, '<h[13456]\b').Count -ne 0) { Show-Failure 'other headings'; return $false }
        if ([regex]::Matches($v, '<ol\b').Count -ne 1 -or [regex]::Matches($v, '<li\b').Count -ne 3) { Show-Failure 'three steps'; return $false }
        $svg = [regex]::Matches($v, '<svg\b').Count
        if ($svg -lt 1 -or [regex]::Matches($v, '<svg\b[^>]*aria-hidden="true"').Count -ne $svg) { Show-Failure 'svg decorative'; return $false }
        if ($v -match '(?i)nessun addebito|non ti e stato addebitato|non e stato addebitato') { Show-Failure 'charge claim'; return $false }
    }
    # Retry: due collegamenti al passo di pagamento (riprova, cambia metodo); Wait e Contact nessuno
    if ([regex]::Matches($retry, 'href="carrello\.aspx\?payguide=1"').Count -ne 2) { Show-Failure 'retry links'; return $false }
    if ($retry -notmatch 'data-ks-pay-guide-action="retry"' -or $retry -notmatch 'data-ks-pay-guide-action="change"') { Show-Failure 'retry actions'; return $false }
    if ($retry -notmatch 'Riprova il pagamento' -or $retry -notmatch 'Cambia metodo di pagamento') { Show-Failure 'retry labels'; return $false }
    if ($wait -cmatch 'payguide=1' -or $contact -cmatch 'payguide=1') { Show-Failure 'payguide outside retry'; return $false }
    if ($wait -match '(?i)paga di nuovo|riprova|ripeti il pagamento') { Show-Failure 'wait says pay again'; return $false }
    if ($contact -match '(?i)paga di nuovo|riprova|ripeti il pagamento') { Show-Failure 'contact says pay again'; return $false }
    if ($wait -notmatch 'href="documenti\.aspx\?t=4"') { Show-Failure 'wait link'; return $false }
    if ($contact -notmatch 'href="Contattaci\.aspx"') { Show-Failure 'contact link'; return $false }
    # role: un solo alert per variante di errore, status per l'attesa
    if ([regex]::Matches($retry, 'role="alert"').Count -ne 1 -or [regex]::Matches($contact, 'role="alert"').Count -ne 1) { Show-Failure 'role alert'; return $false }
    if ($wait -match 'role="alert"' -or $wait -notmatch 'role="status"') { Show-Failure 'role status'; return $false }
    if ($retry -notmatch 'images/pagamenti/paypal\.svg') { Show-Failure 'paypal asset'; return $false }
    if ($cssText -notmatch '(?m)^\.ks-cart-page \.ks-pay-guide__btn\s*\{') { Show-Failure 'css btn'; return $false }
    if ($cssText -notmatch '(?s)\.ks-pay-guide__btn\s*\{[^}]*min-height:\s*44px') { Show-Failure 'css 44px'; return $false }
    if ($cssText -notmatch '(?s)@media \(max-width: 575px\)\s*\{[^@]*\.ks-pay-guide__actions[^}]*\{[^}]*flex-direction:\s*column') { Show-Failure 'css mobile column'; return $false }
    if ($text -match 'cart-ui\.css"\)\s*&\s*"\?v=20261115-focus-fc1a"') { Show-Failure 'css cache buster unchanged'; return $false }
    return $true
}
function Test-VbGuide([string]$text) {
    $code = Strip-VbComments $text
    if ([regex]::Matches($code, 'KeepStorePaymentGuide\.Resolve\(').Count -ne 1) { Show-Failure 'resolve once'; return $false }
    $apply = Get-Region $code '(?m)^\s*Private Sub ApplyPaymentGuide\(\)\s*\n' '\n\s*End Sub'
    if ($null -eq $apply) { Show-Failure 'ApplyPaymentGuide'; return $false }
    foreach ($need in @('GetSessionInt("LoginId", 0) <= 0', 'Not _cartHasItems', 'HttpUtility.HtmlEncode(', 'pnlCartPriceRevalidation.Visible = False', 'pnlPaymentGuide.Visible = True')) {
        if (-not $apply.Contains($need)) { Show-Failure ('apply needs ' + $need); return $false }
    }
    if ($apply -notmatch 'PaymentGuideKind\.Retry' -or $apply -notmatch 'PaymentGuideKind\.Wait' -or $apply -notmatch 'PaymentGuideKind\.Contact') { Show-Failure 'three kinds'; return $false }
    if ($apply -match 'Resubmit|MsgChanged') { Show-Failure 'resubmit in guide'; return $false }
    $complete = Get-Region $code '(?m)^\s*Protected Sub Page_PreRenderComplete\([^\n]*\n' '\n\s*End Sub'
    if ($null -eq $complete -or $complete -notmatch 'ApplyPaymentGuide\(\)') { Show-Failure 'PreRenderComplete apply'; return $false }
    if ($complete -notmatch 'payguide' -or $complete -notmatch 'tOrdine\.Visible = False') { Show-Failure 'PreRenderComplete empty cart reset'; return $false }
    $show = Get-Region $code '(?m)^\s*Private Sub ShowCartPriceRevalidationMessage\(\)\s*\n' '\n\s*End Sub'
    if ($null -eq $show -or $show -notmatch '_paymentGuideMessage = msg') { Show-Failure 'ShowCartPriceRevalidationMessage stores message'; return $false }
    $line = [regex]::Match($code, '(?ms)^\s*ElseIf String\.Equals\(Request\.QueryString\("payguide"\), "1", StringComparison\.OrdinalIgnoreCase\) AndAlso isLogged AndAlso Not Page\.IsPostBack Then\s*\n(.*?)\n\s*End If').Groups[1].Value
    if ($line -eq '' -or $line -notmatch 'SetCheckoutStep\("checkout"\)' -or $line -notmatch 'tOrdine\.Visible = True' -or $line -notmatch 'ApplyCheckoutStepUi\(\)') { Show-Failure 'payguide branch'; return $false }
    if ([regex]::Matches($code, 'Request\.QueryString\("payguide"\)').Count -ne 2) { Show-Failure 'payguide count'; return $false }
    return $true
}
function Test-All([string]$moduleText, [string]$aspxText, [string]$vbText, [string]$cssText) {
    if (-not (Test-ModuleStructure $moduleText)) { Show-Failure 'module structure'; return $false }
    if (-not (Test-KindMatrix $moduleText)) { return $false }
    if (-not (Test-AspxGuide $aspxText $cssText)) { return $false }
    if (-not (Test-VbGuide $vbText)) { return $false }
    return $true
}

Assert-Source (Test-ModuleStructure $module) 'G01_THE_MODULE_HAS_THE_FOUR_KINDS_FIVE_EXACT_COMPARISONS_AND_NO_COPIED_TEXT'
Assert-Source (Test-KindMatrix $module) 'G02_EVERY_REAL_MSG_CONSTANT_MAPS_TO_ITS_KIND_AND_HOSTILE_TEXT_TO_NONE'
Assert-Source (Test-AspxGuide $aspx $css) 'G03_THE_PANEL_HAS_THREE_VARIANTS_WITH_THEIR_OWN_STEPS_LINKS_AND_NO_POSTBACK'
Assert-Source (Test-VbGuide $vb) 'G04_THE_CODE_BEHIND_SHOWS_THE_GUIDE_ONLY_LOGGED_IN_WITH_ITEMS_AND_OPENS_THE_PAYMENT_STEP_BY_GET'
Assert-Source (Test-All $module $aspx $vb $css) 'G05_ALL_ORACLES_TOGETHER'

if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED'; exit 0 }

# --- Mutazioni ------------------------------------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'V01_CASE_INSENSITIVE_COMPARISON'; Kind = 'module'; Old = 'MsgCanceled, StringComparison.Ordinal)'; New = 'MsgCanceled, StringComparison.OrdinalIgnoreCase)' },
    @{ Id = 'V02_NO_TRIM'; Kind = 'module'; Old = 'message.Trim()'; New = 'message' },
    @{ Id = 'V03_BUSY_BECOMES_RETRY'; Kind = 'module'; Old = 'MsgBusy, StringComparison.Ordinal) Then Return PaymentGuideKind.Wait'; New = 'MsgBusy, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry' },
    @{ Id = 'V04_MANUAL_BECOMES_RETRY'; Kind = 'module'; Old = 'MsgManual, StringComparison.Ordinal) Then Return PaymentGuideKind.Contact'; New = 'MsgManual, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry' },
    @{ Id = 'V05_CANCELED_BECOMES_NONE'; Kind = 'module'; Old = 'MsgCanceled, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry'; New = 'MsgCanceled, StringComparison.Ordinal) Then Return PaymentGuideKind.None' },
    @{ Id = 'V06_RESUBMIT_ENTERS_THE_GUIDE'; Kind = 'module'; Old = "        Return PaymentGuideKind.None`n    End Function"; New = "        If String.Equals(text, PayPalPayFirstService.MsgResubmit, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry`n        Return PaymentGuideKind.None`n    End Function" },
    @{ Id = 'V07_CHANGED_ENTERS_THE_GUIDE'; Kind = 'module'; Old = "        Return PaymentGuideKind.None`n    End Function"; New = "        If String.Equals(text, PayPalPayFirstService.MsgChanged, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry`n        Return PaymentGuideKind.None`n    End Function" },
    @{ Id = 'V08_NOTHING_NOT_HANDLED'; Kind = 'module'; Old = 'If message Is Nothing Then Return PaymentGuideKind.None'; New = "' removed" },
    @{ Id = 'A01_WAIT_GETS_A_PAYMENT_LINK'; Kind = 'aspx'; Old = 'href="documenti.aspx?t=4"'; New = 'href="carrello.aspx?payguide=1"' },
    @{ Id = 'A02_GUIDE_AFTER_THE_PRICE_NOTICE'; Kind = 'aspx'; Old = '<asp:Panel ID="pnlPaymentGuide"'; New = '<asp:Panel ID="pnlCartPriceRevalidation" runat="server" Visible="false"></asp:Panel><asp:Panel ID="pnlPaymentGuide"' },
    @{ Id = 'A03_POSTBACK_BUTTON_IN_THE_GUIDE'; Kind = 'aspxfirst'; Pattern = '<asp:PlaceHolder ID="phGuideRetry"[^>]*>'; New = '<asp:PlaceHolder ID="phGuideRetry" runat="server" Visible="false"><asp:LinkButton ID="btnX" runat="server" Text="x" />' },
    @{ Id = 'A04_SVG_NOT_DECORATIVE'; Kind = 'aspxfirst'; Pattern = '<svg\b[^>]*aria-hidden="true"'; New = '<svg viewBox="0 0 24 24"' },
    @{ Id = 'A05_WAIT_IS_AN_ALERT'; Kind = 'aspxwait'; Old = 'role="status"'; New = 'role="alert"' },
    @{ Id = 'A06_CHARGE_CLAIM_IN_CONTACT'; Kind = 'aspxfirst'; Pattern = '<asp:PlaceHolder ID="phGuideContact"[^>]*>'; New = '<asp:PlaceHolder ID="phGuideContact" runat="server" Visible="false"><p>Nessun addebito.</p>' },
    @{ Id = 'A07_WAIT_SAYS_PAY_AGAIN'; Kind = 'aspxfirst'; Pattern = '<asp:PlaceHolder ID="phGuideWait"[^>]*>'; New = '<asp:PlaceHolder ID="phGuideWait" runat="server" Visible="false"><p>Paga di nuovo.</p>' },
    @{ Id = 'A08_CSS_CACHE_BUSTER_UNCHANGED'; Kind = 'aspxfirst'; Pattern = 'cart-ui\.css"\) & "\?v=[^"]+"'; New = 'cart-ui.css") & "?v=20261115-focus-fc1a"' },
    @{ Id = 'B01_PAYGUIDE_WITHOUT_LOGIN'; Kind = 'vb'; Old = 'AndAlso isLogged AndAlso Not Page.IsPostBack Then'; New = 'AndAlso Not Page.IsPostBack Then' },
    @{ Id = 'B07_PAYGUIDE_ALSO_ON_POSTBACK'; Kind = 'vb'; Old = 'AndAlso isLogged AndAlso Not Page.IsPostBack Then'; New = 'AndAlso isLogged Then' },
    @{ Id = 'B02_GUIDE_WITH_EMPTY_CART'; Kind = 'vb'; Old = ' OrElse Not _cartHasItems'; New = '' },
    @{ Id = 'B03_MESSAGE_NOT_ENCODED'; Kind = 'vb'; Old = 'HttpUtility.HtmlEncode(_paymentGuideMessage.Trim())'; New = '_paymentGuideMessage.Trim()' },
    @{ Id = 'B04_PRICE_NOTICE_STAYS_VISIBLE'; Kind = 'vb'; Old = 'pnlCartPriceRevalidation.Visible = False'; New = 'pnlCartPriceRevalidation.Visible = pnlCartPriceRevalidation.Visible' },
    @{ Id = 'B05_NO_EMPTY_CART_RESET'; Kind = 'vb'; Old = 'tOrdine.Visible = False : SetCheckoutStep("cart")'; New = 'SetCheckoutStep("cart")' },
    @{ Id = 'B06_GUIDE_NOT_APPLIED'; Kind = 'vb'; Old = 'ApplyPaymentGuide()' ; New = 'ApplyPaymentGuideNever()' },
    @{ Id = 'C01_BUTTON_HEIGHT_40'; Kind = 'css'; Old = 'min-height: 44px'; New = 'min-height: 40px' }
)
foreach ($mu in $mutants) {
    $mm = $module; $ma = $aspx; $mv = $vb; $mc = $css
    switch ($mu.Kind) {
        'module' { $mm = Mutate-Text $module $mu.Old $mu.New $mu.Id }
        'aspx' { $ma = Mutate-Text $aspx $mu.Old $mu.New $mu.Id }
        'aspxfirst' { $ma = Mutate-First $aspx $mu.Pattern $mu.New $mu.Id }
        'aspxwait' {
            $s = $aspx.IndexOf('<asp:PlaceHolder ID="phGuideWait"', [StringComparison]::Ordinal)
            if ($s -lt 0) { throw ('MUTATION_NOT_APPLIED=' + $mu.Id) }
            $head = $aspx.Substring(0, $s); $tail = $aspx.Substring($s)
            $ma = $head + (Mutate-Text $tail $mu.Old $mu.New $mu.Id)
        }
        'aspxcache' { $ma = Mutate-Text $aspx '?v=20261115-focus-fc1a' '?v=20261115-focus-fc1a' $mu.Id }
        'vb' { $mv = Mutate-Text $vb $mu.Old $mu.New $mu.Id }
        'css' { $mc = Mutate-Text $css $mu.Old $mu.New $mu.Id }
    }
    Assert-Detected (Test-All $mm $ma $mv $mc) $mu.Id
}
Write-Output ('GUIDE_TEST_PASS mutants=' + $mutants.Count)
