[CmdletBinding()]
param(
    [string]$HostName = 'www.taikun.it',
    [int]$Port = 18843,
    [string]$UserName = 'ks_test_regorder_1a',
    [string]$SecretFile = (Join-Path $env:APPDATA 'KeepStore\lab-18843-webuser-ks_test_regorder_1a.dpapi'),
    [string]$ProductPath = '/articolo.aspx?id=1&TCid=18',
    [switch]$ExpectNumericWhenLoggedIn,
    [string]$EvidenceDirectory = ''
)

# Regola del PO (2026-11-14): i numeri Disponibili / Impegnati / In arrivo solo a chi e loggato, le parole agli ospiti.
# Prova nel browser sul LAB isolato: ospite (home, catalogo, scheda, carrello, ricerca suggerita), poi login, poi logout
# e di nuovo ospite (la modalita deve tornare a parole). Con -ExpectNumericWhenLoggedIn il loggato deve vedere i numeri:
# il tenant del LAB deve avere DispoTipo=2 (modifica temporanea da ripristinare). Solo LAB :18843. Solo ASCII (PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Port -ne 18843) { throw 'LAB_ONLY' }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')

$base = 'https://' + $HostName + ':' + $Port
function Assert-Step([bool]$ok, [string]$code, [string]$detail = '') {
    if (-not $ok) { throw ('RULE_FAIL ' + $code + ' ' + $detail) }
    Write-Host ('PASS ' + $code + $(if ($detail) { ' ' + $detail } else { '' }))
}
# Conta i blocchi numerici e sintetici della disponibilita nella pagina corrente.
function Get-KsAvailabilityCounts($b) {
    $js = '(function(){var t=document.body?document.body.innerText:"";return JSON.stringify({numeric:document.querySelectorAll(".ks-availability--numeric").length,synthetic:document.querySelectorAll(".ks-availability--synthetic").length,labels:(/Impegnati/.test(t)||/Disponibili\s*[0-9]/.test(t))});})()'
    return (Invoke-KsJs $b $js) | ConvertFrom-Json
}
function Test-GuestPage($b, [string]$path, [string]$code) {
    Open-KsUrl $b ($base + $path)
    $c = Get-KsAvailabilityCounts $b
    Assert-Step (($c.numeric -eq 0) -and (-not $c.labels)) ($code + '_NO_NUMBERS_FOR_GUEST') ('numeric=' + $c.numeric + ' synthetic=' + $c.synthetic)
    return $c
}

if (-not (Test-Path -LiteralPath $SecretFile)) { throw 'SECRET_FILE_MISSING' }
$sec = ConvertTo-SecureString (Get-Content -LiteralPath $SecretFile)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$labSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$b = $null
try {
    $b = Start-KsBrowser -LoopbackHosts @($HostName) -Width 1280 -Height 900
    # 1) ospite
    $null = Test-GuestPage $b '/Default.aspx' 'V01_HOME'
    $cat = Test-GuestPage $b '/articoli.aspx' 'V02_CATALOG'
    Assert-Step ($cat.synthetic -ge 1) 'V03_CATALOG_SHOWS_WORDS' ('synthetic=' + $cat.synthetic)
    $pdp = Test-GuestPage $b $ProductPath 'V04_PRODUCT'
    Assert-Step ($pdp.synthetic -ge 1) 'V05_PRODUCT_SHOWS_WORDS' ('synthetic=' + $pdp.synthetic)
    if ($EvidenceDirectory) { New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null; Save-KsScreenshot $b (Join-Path $EvidenceDirectory 'pdp-guest-desktop.png') -FullPage }
    $suggest = Invoke-KsJs $b '(function(){return fetch("/search_suggest.aspx?q=prodotto",{credentials:"same-origin"}).then(function(r){return r.text();}).then(function(t){return JSON.stringify({len:t.length,labels:/Impegnati/.test(t)});});})()'
    $s = $suggest | ConvertFrom-Json
    Assert-Step (-not $s.labels) 'V06_SEARCH_SUGGEST_NO_NUMBERS_FOR_GUEST' ('len=' + $s.len)
    # carrello come ospite: una riga, poi controllo
    Open-KsUrl $b ($base + '/articoli.aspx')
    Invoke-KsClick $b 'button.js-ks-cart-link' -NoWait
    Start-Sleep -Seconds 4
    $null = Test-GuestPage $b '/carrello.aspx' 'V07_CART'

    # 2) loggato
    Open-KsUrl $b ($base + '/login.aspx')
    Set-KsValue $b '#MainContent_tbUsername' $UserName
    Set-KsValue $b '#MainContent_tbPassword' $labSecret
    Invoke-KsClick $b '#MainContent_btnLogin'
    Open-KsUrl $b ($base + $ProductPath)
    $logged = Get-KsAvailabilityCounts $b
    if ($ExpectNumericWhenLoggedIn) {
        Assert-Step (($logged.numeric -ge 1) -and $logged.labels) 'V08_PRODUCT_SHOWS_NUMBERS_WHEN_LOGGED_IN' ('numeric=' + $logged.numeric)
        Open-KsUrl $b ($base + '/articoli.aspx')
        $lc = Get-KsAvailabilityCounts $b
        Assert-Step ($lc.numeric -ge 1) 'V09_CATALOG_SHOWS_NUMBERS_WHEN_LOGGED_IN' ('numeric=' + $lc.numeric)
        $suggest2 = Invoke-KsJs $b '(function(){return fetch("/search_suggest.aspx?q=prodotto",{credentials:"same-origin"}).then(function(r){return r.text();}).then(function(t){return JSON.stringify({len:t.length});});})()'
        Write-Output ('INFO search suggest da loggato: ' + $suggest2)
        if ($EvidenceDirectory) { Open-KsUrl $b ($base + $ProductPath); Save-KsScreenshot $b (Join-Path $EvidenceDirectory 'pdp-logged-desktop.png') -FullPage }
    } else {
        Assert-Step ($logged.synthetic -ge 1) 'V08_PRODUCT_SHOWS_WORDS_WHEN_TENANT_MODE_IS_WORDS' ('synthetic=' + $logged.synthetic)
    }

    # 3) logout e di nuovo ospite: la modalita deve tornare a parole nella stessa sessione del browser
    Open-KsUrl $b ($base + '/logout.aspx')
    $null = Test-GuestPage $b $ProductPath 'V10_PRODUCT_AFTER_LOGOUT'
    $null = Test-GuestPage $b '/articoli.aspx' 'V11_CATALOG_AFTER_LOGOUT'
}
finally { if ($b) { Stop-KsBrowser $b } }
Write-Output 'PASS LAB_AVAILABILITY_VISITOR_RULE'
