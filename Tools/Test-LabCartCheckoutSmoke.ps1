[CmdletBinding()]
param(
    [string]$HostName = 'www.taikun.it',
    [int]$Port = 18843,
    [string]$UserName = 'ks_test_regorder_1a',
    [string]$SecretFile = (Join-Path $env:APPDATA 'KeepStore\lab-18843-webuser-ks_test_regorder_1a.dpapi'),
    [string]$EvidenceDirectory = '',
    [switch]$PlaceOrder
)

# Prova nel browser del carrello e del checkout sul LAB isolato (sito 40390): login dell'utente sintetico, riga nel
# carrello, step spedizione/pagamento con IVA e totale letti dal database, e (solo con -PlaceOrder) invio di UN ordine.
# Usa il pilota Edge/CDP del repository con risoluzione forzata a 127.0.0.1. NON va puntato su Smoke (:8443): il database
# di Smoke e condiviso e potenzialmente operativo. Per -PlaceOrder servono nel LAB una fascia in vettoricosti e un
# pagamento con CostoMassimo sufficiente (fixture temporanee, da ripristinare). Solo ASCII (PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Port -ne 18843) { throw 'LAB_ONLY: la prova mutativa e ammessa solo sul LAB :18843' }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')

$base = 'https://' + $HostName + ':' + $Port
$results = New-Object System.Collections.Generic.List[string]
function Assert-Step([bool]$ok, [string]$code, [string]$detail = '') {
    if (-not $ok) { throw ('SMOKE_FAIL ' + $code + ' ' + $detail) }
    $results.Add('PASS ' + $code + $(if ($detail) { ' ' + $detail } else { '' }))
    Write-Output ('PASS ' + $code + $(if ($detail) { ' ' + $detail } else { '' }))
}
function ConvertTo-KsDecimal([string]$text) {
    return [decimal]::Parse(($text -replace '\.', '' -replace ',', '.'), [Globalization.CultureInfo]::InvariantCulture)
}
function Get-KsSummary($b) {
    # Legge le righe del riepilogo ordine (Imponibile, Spedizione, Assicurazione, IVA, Pagamento, Sconto, Totale).
    $t = (Get-KsText $b 'body') -replace '\s+', ' '
    $i = $t.LastIndexOf('Riepilogo ordine')
    if ($i -lt 0) { return $null }
    $s = $t.Substring($i)
    $r = @{}
    foreach ($k in 'Imponibile', 'Spedizione', 'Assicurazione', 'IVA', 'Pagamento', 'Sconto', 'Totale') {
        $m = [regex]::Match($s, '\b' + $k + ' (-?[0-9.]+,[0-9]{2}|n/d)')
        if ($m.Success) { $r[$k] = $m.Groups[1].Value }
    }
    return $r
}

if (-not (Test-Path -LiteralPath $SecretFile)) { throw 'SECRET_FILE_MISSING' }
$sec = ConvertTo-SecureString (Get-Content -LiteralPath $SecretFile)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$labSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$b = $null
try {
    $b = Start-KsBrowser -LoopbackHosts @($HostName) -Width 430 -Height 900 -Mobile
    Open-KsUrl $b ($base + '/login.aspx')
    Set-KsValue $b '#MainContent_tbUsername' $UserName
    Set-KsValue $b '#MainContent_tbPassword' $labSecret
    Invoke-KsClick $b '#MainContent_btnLogin'
    Assert-Step ((Invoke-KsJs $b 'location.href') -notmatch 'login\.aspx') 'S01_LOGIN_SYNTHETIC_USER'

    Open-KsUrl $b ($base + '/carrello.aspx')
    if (((Get-KsText $b 'body') -replace '\s+', ' ') -match 'carrello .{1,2} vuoto') {
        Open-KsUrl $b ($base + '/articoli.aspx')
        Invoke-KsClick $b 'button.js-ks-cart-link' -NoWait
        Start-Sleep -Seconds 4
        Open-KsUrl $b ($base + '/carrello.aspx')
    }
    Assert-Step ([bool](Invoke-KsJs $b '!!document.querySelector("#MainContent_btCompleta")')) 'S02_CART_HAS_LINE_AND_CONTINUE_BUTTON'

    Invoke-KsClick $b '#MainContent_btCompleta'
    $s2 = Get-KsSummary $b
    Assert-Step ($s2 -ne $null -and $s2.ContainsKey('Totale') -and $s2['Totale'] -ne 'n/d') 'S03_STEP2_TOTALS_FROM_DATABASE_NOT_ND' ('Totale=' + $s2['Totale'])
    $sum = (ConvertTo-KsDecimal $s2['Imponibile']) + (ConvertTo-KsDecimal $s2['Spedizione']) + (ConvertTo-KsDecimal $s2['Assicurazione']) +
           (ConvertTo-KsDecimal $s2['IVA']) + (ConvertTo-KsDecimal $s2['Pagamento']) - (ConvertTo-KsDecimal $s2['Sconto'])
    Assert-Step ($sum -eq (ConvertTo-KsDecimal $s2['Totale'])) 'S04_STEP2_TOTAL_EQUALS_SUM_OF_LINES' ('somma=' + $sum.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture))
    if ($EvidenceDirectory) { New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null; Save-KsScreenshot $b (Join-Path $EvidenceDirectory 'lab-checkout-step2.png') -FullPage }

    if ($PlaceOrder) {
        Invoke-KsClick $b '#MainContent_btnVaiConfermaOrdine'
        $s3 = Get-KsSummary $b
        Assert-Step ($s3 -ne $null -and $s3['Totale'] -eq $s2['Totale']) 'S05_STEP3_TOTAL_UNCHANGED' ('Totale=' + $s3['Totale'])
        $null = Invoke-KsJs $b '(function(){var c=document.getElementById("chkTermsConsent");if(c&&!c.checked){c.click();}return c?c.checked:null;})()'
        Invoke-KsClick $b '#MainContent_btInviaOrdine'
        $t = (Get-KsText $b 'body') -replace '\s+', ' '
        Assert-Step ($t -match 'Ordine inviato') 'S06_ORDER_CONFIRMATION_PAGE'
        $tot = [regex]::Match($t, 'Totale ordine ([0-9.]+,[0-9]{2})')
        Assert-Step ($tot.Success -and $tot.Groups[1].Value -eq $s2['Totale']) 'S07_CONFIRMATION_TOTAL_EQUALS_CHECKOUT_TOTAL' ('Totale=' + $tot.Groups[1].Value)
        $num = [regex]::Match($t, 'Ordine N\. ([0-9]+)')
        Write-Output ('INFO numero ordine assegnato dal database: ' + $num.Groups[1].Value + ' (confrontare con documenti/documentipie sul LAB)')
        if ($EvidenceDirectory) { Save-KsScreenshot $b (Join-Path $EvidenceDirectory 'lab-conferma-ordine.png') -FullPage }
    }
}
finally { if ($b) { Stop-KsBrowser $b } }
Write-Output 'PASS LAB_CART_CHECKOUT_SMOKE'
