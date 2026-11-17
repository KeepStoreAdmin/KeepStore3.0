[CmdletBinding()]
param([switch]$SkipMutations, [switch]$SkipLab)

# ORDER-REMOTE-PAYMENT-1A - "Paga adesso" in MyAccount per (1) ordini del sito il cui metodo il PO cambia nel gestionale in PayPal o carta Banca Sella e (2) ordini creati dal
# gestionale per un cliente registrato; divieto del PO: un ordine del sito con pagamento online FALLITO non si ripaga.
# Oracolo 1: i VERI file App_Code/KeepStoreRemotePayment.vb e InternalOrderRemotePaymentPolicy.vb compilati (Strict) e provati con una tabella scritta a mano di scenari e con il
#   rovesciamento di ogni condizione, una per volta, a partire da tre ordini ammessi (gestionale, INTERNO esplicito, sito con metodo cambiato).
# Oracolo 2: la VERA query dei fatti (KeepStoreRemotePaymentStore.FactsSql) eseguita sul LAB (mirror del taikun) su ordini sintetici inseriti e rimossi dal test, poi decisa con la
#   stessa policy compilata. Richiede il LAB acceso (Tools\Invoke-KeepStoreLabSql.ps1, scrittura solo sul LAB, righe 990101-990199 rimosse a fine prova).
# Oracolo 3 (testo del codice, senza commenti): le quattro superfici (lista, dettaglio, PayPal, Banca Sella) usano la decisione completa sui fatti; percorso web con contesto di
#   lancio separato (viaLaunch); avvio Banca Sella segnato; interfaccia (riquadro in alto nel dettaglio, pulsante e etichetta nella lista); stili.
# Mutazioni su copie in memoria (modulo, query, pagine, stili). Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

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
function Show-Failure([string]$id) { if ($env:KS_REMOTE_TEST_VERBOSE) { Write-Host ('REMOTE_CASE_FAILED ' + $id) } }

$moduleText = Read-Repo 'App_Code/KeepStoreRemotePayment.vb'
$policyText = Read-Repo 'App_Code/InternalOrderRemotePaymentPolicy.vb'
$storeText = Read-Repo 'App_Code/KeepStoreRemotePaymentStore.vb'
$listVb = Read-Repo 'documenti.aspx.vb'
$listAspx = Read-Repo 'documenti.aspx'
$detailVb = Read-Repo 'documentidettaglio.aspx.vb'
$detailAspx = Read-Repo 'documentidettaglio.aspx'
$ppVb = Read-Repo 'paypalcheckout.aspx.vb'
$sellaVb = Read-Repo 'bancasella.aspx.vb'
$repoVb = Read-Repo 'App_Code/PayPalCheckoutRepository.vb'
$stateVb = Read-Repo 'App_Code/PayPalPaymentState.vb'
$css = Read-Repo 'Public/assets/keepstore/css/order-ui.css'

# --- Oracolo 1: la decisione compilata -----------------------------------------------------------------------------------------------------------------
$probeSource = @"
Option Strict On
Option Explicit On
Imports System
Imports System.Globalization
Public Class RemoteProbe
    Public Function Decide(ByVal origin As String, ByVal ordineWeb As Integer, ByVal docAgeDays As Integer, ByVal paid As Integer, ByVal docState As Integer, ByVal payState As Integer,
                           ByVal stateAgeMinutes As Integer, ByVal lastOutcome As String, ByVal online As Integer, ByVal allow As Integer, ByVal total As Decimal, ByVal valid As Boolean, ByVal sella As Boolean,
                           ByVal ppAny As Boolean, ByVal ppOther As Boolean, ByVal marketplace As Boolean, ByVal owner As Boolean, ByVal tenant As Boolean) As Boolean
        Dim f As New RemotePaymentFacts()
        f.Origin = origin
        f.OrdineWeb = ordineWeb
        f.Today = New DateTime(2026, 11, 17)
        f.DbNow = New DateTime(2026, 11, 17, 12, 0, 0)
        If docAgeDays <> 99999 Then f.DocumentDate = f.Today.AddDays(-docAgeDays)
        f.Paid = paid
        f.DocumentState = docState
        f.PaymentState = payState
        If stateAgeMinutes <> 99999 Then f.PaymentStateDate = f.DbNow.AddMinutes(-stateAgeMinutes)
        f.LastOutcome = lastOutcome
        f.OnlineMethod = online
        f.AllowLater = allow
        f.Total = total
        f.ValidOrderType = valid
        f.SellaAuthorized = sella
        f.PayPalAny = ppAny
        f.PayPalOpenOther = ppOther
        f.Marketplace = marketplace
        Return InternalOrderRemotePaymentPolicy.CanPayNow(f, owner, tenant)
    End Function

    Public Function DecideNothing() As Boolean
        Return InternalOrderRemotePaymentPolicy.CanPayNow(CType(Nothing, RemotePaymentFacts), True, True)
    End Function

    Public Function DecideRow(ByVal origin As String, ByVal ordineWeb As Integer, ByVal docDate As String, ByVal todayText As String, ByVal nowText As String, ByVal paid As Integer,
                              ByVal docState As Integer, ByVal payState As Integer, ByVal stateDate As String, ByVal lastOutcome As String, ByVal online As Integer, ByVal allow As Integer, ByVal total As Decimal,
                              ByVal valid As Boolean, ByVal sella As Boolean, ByVal ppAny As Boolean, ByVal ppOther As Boolean, ByVal marketplace As Boolean) As Boolean
        Dim f As New RemotePaymentFacts()
        f.Origin = origin
        f.OrdineWeb = ordineWeb
        If docDate <> "" Then f.DocumentDate = DateTime.Parse(docDate, CultureInfo.InvariantCulture)
        f.Today = DateTime.Parse(todayText, CultureInfo.InvariantCulture)
        f.DbNow = DateTime.Parse(nowText, CultureInfo.InvariantCulture)
        f.Paid = paid
        f.DocumentState = docState
        f.PaymentState = payState
        If stateDate <> "" Then f.PaymentStateDate = DateTime.Parse(stateDate, CultureInfo.InvariantCulture)
        f.LastOutcome = lastOutcome
        f.OnlineMethod = online
        f.AllowLater = allow
        f.Total = total
        f.ValidOrderType = valid
        f.SellaAuthorized = sella
        f.PayPalAny = ppAny
        f.PayPalOpenOther = ppOther
        f.Marketplace = marketplace
        Return InternalOrderRemotePaymentPolicy.CanPayNow(f, True, True)
    End Function
End Class
"@
function New-RemoteProbe([string]$modText, [string]$polText) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($modText, $polText, $probeSource))
    if ($c.Errors.HasErrors) { throw ('REMOTE_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('RemoteProbe', $true))
}
# Tre ordini ammessi di partenza: G = gestionale (origine vuota, ordine non del sito, recente), I = INTERNO esplicito (anche vecchio), W = ordine del sito col metodo cambiato (stato 0, nessun tentativo)
$base = @{
    G = @{ origin = ''; ow = 0; age = 10; paid = 0; ds = 1; ps = 0; sage = 99999; lo = ''; online = 2; allow = 1; total = [decimal]50; valid = $true; sella = $false; ppAny = $false; ppOther = $false; mk = $false; owner = $true; tenant = $true }
    I = @{ origin = 'INTERNO'; ow = 0; age = 400; paid = 0; ds = 1; ps = 0; sage = 99999; lo = ''; online = 3; allow = 1; total = [decimal]50; valid = $true; sella = $false; ppAny = $false; ppOther = $false; mk = $false; owner = $true; tenant = $true }
    W = @{ origin = 'WEB'; ow = 1; age = 5; paid = 0; ds = 1; ps = 0; sage = 99999; lo = ''; online = 3; allow = 1; total = [decimal]50; valid = $true; sella = $false; ppAny = $false; ppOther = $false; mk = $false; owner = $true; tenant = $true }
}
# [nome, ordine di partenza, modifiche, atteso]
$cases = @(
    @('G ammesso (PayPal)', 'G', @{}, $true), @('G ammesso (Sella)', 'G', @{ online = 3 }, $true), @('I ammesso vecchio di 400 giorni', 'I', @{}, $true),
    @('W ammesso (offline cambiato in Sella)', 'W', @{}, $true), @('W ammesso (offline cambiato in PayPal)', 'W', @{ online = 2 }, $true),
    @('W con origine vuota e ordine del sito ammesso', 'W', @{ origin = '' }, $true), @('W con origine WEB e Ordine_Web 0 ammesso', 'W', @{ ow = 0 }, $true),
    # finestra
    @('G oggi', 'G', @{ age = 0 }, $true), @('G 90 giorni', 'G', @{ age = 90 }, $true), @('G 91 giorni NO', 'G', @{ age = 91 }, $false), @('G data futura NO', 'G', @{ age = -1 }, $false),
    @('G data mancante NO', 'G', @{ age = 99999 }, $false), @('W 91 giorni NO', 'W', @{ age = 91 }, $false), @('W data mancante NO', 'W', @{ age = 99999 }, $false),
    @('I data mancante ammesso (esplicito)', 'I', @{ age = 99999 }, $true),
    # origine
    @('G Amazon NO', 'G', @{ origin = 'AMAZON' }, $false), @('G eBay NO', 'G', @{ origin = 'EBAY' }, $false), @('G origine sconosciuta NO', 'G', @{ origin = 'XYZ' }, $false),
    @('G legato al marketplace NO', 'G', @{ mk = $true }, $false), @('G minuscolo interno ammesso', 'G', @{ origin = ' interno ' }, $true),
    # ordine del sito: pagamento online mai partito
    @('W stato 1 NO', 'W', @{ ps = 1 }, $false), @('W stato 3 (fallito) NO', 'W', @{ ps = 3 }, $false), @('W stato 4 (annullato) NO', 'W', @{ ps = 4 }, $false), @('W stato 5 NO', 'W', @{ ps = 5 }, $false),
    @('W con un tentativo PayPal NO', 'W', @{ ppAny = $true }, $false), @('Origine vuota con Ordine_Web e stato 3 NO', 'W', @{ origin = ''; ps = 3 }, $false),
    # gate comuni
    @('pagato NO', 'G', @{ paid = 1 }, $false), @('documento annullato NO', 'G', @{ ds = 3 }, $false), @('documento senza stato NO', 'G', @{ ds = 0 }, $false), @('stato pagamento 2 NO', 'G', @{ ps = 2 }, $false),
    @('metodo offline NO', 'G', @{ online = 0 }, $false), @('metodo 1 NO', 'G', @{ online = 1 }, $false), @('metodo 4 NO', 'G', @{ online = 4 }, $false), @('totale 0 NO', 'G', @{ total = [decimal]0 }, $false),
    @('totale negativo NO', 'G', @{ total = [decimal]-5 }, $false), @('permesso 0 NO', 'G', @{ allow = 0 }, $false), @('tipo non valido NO', 'G', @{ valid = $false }, $false),
    @('autorizzazione Sella presente NO', 'G', @{ sella = $true }, $false), @('altro utente NO', 'G', @{ owner = $false }, $false), @('altra azienda NO', 'G', @{ tenant = $false }, $false),
    @('G stato 3 ammesso (riprova)', 'G', @{ ps = 3 }, $true), @('G stato 4 ammesso (riprova)', 'G', @{ ps = 4 }, $true), @('G stato 5 ammesso', 'G', @{ ps = 5 }, $true),
    # mai due gateway insieme
    @('PayPal aperto su altro metodo NO', 'G', @{ ppOther = $true }, $false), @('PayPal aperto e metodo attuale Sella NO', 'G', @{ ppOther = $true; online = 3 }, $false),
    @('I con PayPal aperto su altro metodo NO', 'I', @{ ppOther = $true }, $false),
    @('PayPal chiuso male e stesso metodo ammesso', 'G', @{ ppAny = $true; ps = 4 }, $true),
    # Sella in corso (ultimo esito = avvio carta, nessun tentativo PayPal, metodo attuale PayPal)
    @('Sella avviata 10 minuti fa, ora PayPal NO', 'G', @{ lo = 'Pagamento con carta avviato'; sage = 10 }, $false), @('Sella avviata 59 minuti fa NO', 'G', @{ lo = 'Pagamento con carta avviato'; sage = 59 }, $false),
    @('Sella avviata 61 minuti fa ammesso', 'G', @{ lo = 'Pagamento con carta avviato'; sage = 61 }, $true), @('Sella avviata senza data NO', 'G', @{ lo = 'Pagamento con carta avviato' }, $false),
    @('Sella avviata ora e ripetuta con Sella ammessa', 'G', @{ lo = 'Pagamento con carta avviato'; sage = 5; online = 3 }, $true),
    @('Sella avviata ma c e un tentativo PayPal ammesso', 'G', @{ lo = 'Pagamento con carta avviato'; sage = 5; ppAny = $true }, $true),
    @('stato 1 senza avvio carta ammesso', 'G', @{ ps = 1; sage = 5 }, $true), @('esito diverso (maiuscolo) ammesso', 'G', @{ lo = 'PAGAMENTO CON CARTA AVVIATO'; sage = 5 }, $true),
    @('PayPal proprio in stato 1 ammesso', 'G', @{ ps = 1; sage = 5; ppAny = $true }, $true)
)
function Test-DecisionMatrix([string]$modText, [string]$polText) {
    try { $probe = New-RemoteProbe $modText $polText } catch { Show-Failure ('compile ' + $_.Exception.Message); return $false }
    $ok = $true
    foreach ($c in $cases) {
        $f = @{}; foreach ($k in $base[$c[1]].Keys) { $f[$k] = $base[$c[1]][$k] }; foreach ($k in $c[2].Keys) { $f[$k] = $c[2][$k] }
        $got = $probe.Decide([string]$f.origin, [int]$f.ow, [int]$f.age, [int]$f.paid, [int]$f.ds, [int]$f.ps, [int]$f.sage, [string]$f.lo, [int]$f.online, [int]$f.allow, [decimal]$f.total, [bool]$f.valid, [bool]$f.sella, [bool]$f.ppAny, [bool]$f.ppOther, [bool]$f.mk, [bool]$f.owner, [bool]$f.tenant)
        if ($got -ne $c[3]) { Show-Failure $c[0]; $ok = $false }
    }
    if ($probe.DecideNothing()) { Show-Failure 'nothing'; $ok = $false }
    return $ok
}
Assert-Source (Test-DecisionMatrix $moduleText $policyText) 'R01_THE_REAL_DECISION_MATCHES_EVERY_SCENARIO_AND_EVERY_SINGLE_CONDITION_FLIP'

function Test-ModuleStructure([string]$mod, [string]$pol) {
    $code = Strip-VbComments $mod
    if ($code -notmatch 'Public Const WindowDays As Integer = 90\b' -or $code -notmatch 'Public Const SellaStartGuardMinutes As Integer = 60\b') { return $false }
    foreach ($bad in @('MySqlConnection', 'Session', 'HttpContext', 'ConfigurationManager', 'Request', 'DateTime.Now', 'DateTime.Today', 'DateTime.UtcNow')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    if ($mod -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') { return $false }
    $pcode = Strip-VbComments $pol
    if ([regex]::Matches($pcode, '(?m)^\s*Public Function CanPayNow\(').Count -ne 2) { return $false }
    return $true
}
Assert-Source (Test-ModuleStructure $moduleText $policyText) 'R02_THE_DECISION_IS_PURE_HAS_NO_CLOCK_OF_ITS_OWN_AND_NO_CUSTOMER_NAME'

# --- Oracolo 2: la query dei fatti sul LAB -------------------------------------------------------------------------------------------------------------
function Get-FactsSql([string]$text, [string]$constName) {
    $m = [regex]::Match($text, '(?s)Public Const ' + $constName + ' As String =\s*\n(.*?)\n\s*\n')
    if (-not $m.Success) { return $null }
    $parts = [regex]::Matches($m.Groups[1].Value, '"((?:[^"]|"")*)"') | ForEach-Object { $_.Groups[1].Value.Replace('""', '"') }
    return ($parts -join '')
}
$factsSql = Get-FactsSql $storeText 'FactsSql'
if (-not $factsSql) { throw 'FACTS_SQL_NOT_FOUND' }
function New-LabScript([string]$sql) {
    $u = 5630; $a = 1
    $lo = 990101; $hi = 990199
    # id, origine, Ordine_Web, anni/giorni (null = NULL), metodo, stato, minuti dallo stato (null), pagato, tipo documento
    $docs = @(
        @(990101, "'WEB'", 1, '3', 19, 0, $null, 0), @(990102, 'NULL', 0, '5', 19, 0, $null, 0), @(990103, 'NULL', 0, '5', 46, 0, $null, 0), @(990104, 'NULL', 1, '5', 19, 3, $null, 0),
        @(990105, 'NULL', 0, '200', 19, 0, $null, 0), @(990106, 'NULL', 0, $null, 19, 0, $null, 0), @(990107, 'NULL', 0, '-3', 19, 0, $null, 0), @(990108, "'WEB'", 1, '3', 19, 4, 600, 0),
        @(990109, 'NULL', 0, '5', 46, 0, $null, 0), @(990110, 'NULL', 0, '5', 19, 0, $null, 0), @(990111, 'NULL', 0, '5', 19, 4, 600, 0), @(990112, 'NULL', 0, '5', 19, 0, 10, 0),
        @(990113, 'NULL', 0, '5', 19, 0, 120, 0), @(990114, 'NULL', 0, '5', 19, 0, $null, 1), @(990115, 'NULL', 0, '5', 6, 0, $null, 0), @(990116, "'INTERNO'", 0, '400', 19, 0, $null, 0),
        @(990117, "'AMAZON'", 0, '5', 19, 0, $null, 0), @(990118, 'NULL', 0, '5', 19, 0, $null, 0), @(990119, 'NULL', 0, '5', 19, 0, $null, 0), @(990120, 'NULL', 0, '5', 19, 0, $null, 0)
    )
    $sb = New-Object Text.StringBuilder
    $sbF = New-Object Text.StringBuilder
    $sbC = New-Object Text.StringBuilder
    [void]$sb.AppendLine("DELETE FROM bancasella_ordini_pagati WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sb.AppendLine("DELETE FROM paypal_checkout_transazioni WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sb.AppendLine("DELETE FROM documentipie WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sb.AppendLine("DELETE FROM documenti WHERE id BETWEEN $lo AND $hi;")
    foreach ($d in $docs) {
        $date = if ($null -eq $d[3]) { 'NULL' } else { 'DATE_SUB(CURDATE(), INTERVAL ' + $d[3] + ' DAY)' }
        $stDate = if ($null -eq $d[6]) { 'NULL' } else { 'DATE_SUB(NOW(), INTERVAL ' + $d[6] + ' MINUTE)' }
        $user = if ($d[0] -eq 990119) { $u + 100000 } else { $u }
        $esito = if ($d[0] -eq 990112 -or $d[0] -eq 990113) { "'Pagamento con carta avviato'" } else { 'NULL' }
        [void]$sb.AppendLine("INSERT INTO documenti (Id,AziendeId,UtentiId,PagamentiTipoId,TipoDocumentiId,StatiId,Pagato,StatoPagamentoWeb,DataStatoPagamentoWeb,UltimoEsitoPagamentoWeb,OrigineOrdine,Ordine_Web,DataDocumento) VALUES ($($d[0]),$a,$user,$($d[4]),4,1,$($d[7]),$($d[5]),$stDate,$esito,$($d[1]),$($d[2]),$date);")
        [void]$sb.AppendLine("INSERT INTO documentipie (DocumentiId,TotaleDocumento) VALUES ($($d[0]),50.00);")
    }
    # tentativi PayPal: 990108 annullato stesso metodo (sito), 990109 in cattura con metodo attuale Sella, 990110 approvato con metodo diverso, 990111 annullato stesso metodo (riprova)
    $tx = @(@(990108, 19, 'CANCELED'), @(990109, 19, 'CAPTURING'), @(990110, 12, 'APPROVED'), @(990111, 19, 'CANCELED'))
    $n = 0
    foreach ($t in $tx) {
        $n++
        [void]$sb.AppendLine("INSERT INTO paypal_checkout_transazioni (Id,DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,PayPalOrderId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId) VALUES ($(990100 + $n),$($t[0]),1,1,$a,$($t[1]),1,'ORDER-REMOTE-$($t[0])','$($t[2])',50.00,'EUR','lab@example.invalid','MERCHANT_LAB','CREATE-REMOTE-$($t[0])','CAPTURE-REMOTE-$($t[0])');")
    }
    [void]$sb.AppendLine("INSERT INTO bancasella_ordini_pagati (DocumentiId,numeroDocumento,codiceAutorizzazione) VALUES (990118,'990118/2026','AUTH-LAB-990118');")
    [void]$sb.AppendLine("INSERT INTO bancasella_ordini_pagati (DocumentiId,numeroDocumento,codiceAutorizzazione) VALUES (990120,'990120/2026','');")
    foreach ($d in $docs) {
        [void]$sbF.AppendLine("SELECT 'DOC=$($d[0])' AS marker;")
        [void]$sbF.AppendLine("SET @id=$($d[0]), @uid=$u, @azienda=$a;")
        [void]$sbF.AppendLine($sql + ';')
    }
    [void]$sbF.AppendLine("SELECT COUNT(*) AS marketplace_probe FROM ks_amazon_orders WHERE document_id=-1;")
    [void]$sbF.AppendLine("SELECT COUNT(*) AS marketplace_probe_ebay FROM ks_ebay_orders WHERE document_id=-1;")
    [void]$sbC.AppendLine("DELETE FROM bancasella_ordini_pagati WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sbC.AppendLine("DELETE FROM paypal_checkout_transazioni WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sbC.AppendLine("DELETE FROM documentipie WHERE DocumentiId BETWEEN $lo AND $hi;")
    [void]$sbC.AppendLine("DELETE FROM documenti WHERE id BETWEEN $lo AND $hi;")
    return @{ Setup = $sb.ToString(); Facts = $sbF.ToString(); Cleanup = $sbC.ToString() }
}
$labExpected = @{
    990101 = $true; 990102 = $true; 990103 = $true; 990104 = $false; 990105 = $false; 990106 = $false; 990107 = $false; 990108 = $false; 990109 = $false; 990110 = $false
    990111 = $true; 990112 = $false; 990113 = $true; 990114 = $false; 990115 = $false; 990116 = $true; 990117 = $false; 990118 = $false; 990119 = $false; 990120 = $true
}
function Invoke-LabSql([string]$text, [bool]$write) {
    $work = Join-Path ([IO.Path]::GetTempPath()) ('ks-remote-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.sql')
    try {
        [IO.File]::WriteAllText($work, $text, (New-Object Text.UTF8Encoding($false)))
        if ($write) { $out = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1') -SqlFile $work -Write 2>&1 }
        else { $out = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1') -SqlFile $work 2>&1 }
        return @($out | ForEach-Object { [string]$_ })
    } finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Force } }
}
function Invoke-LabFacts([string]$sql, [Text.StringBuilder]$log) {
    # tre chiamate separate: preparazione (scrittura), fatti (sola lettura), pulizia (scrittura, SEMPRE eseguita)
    $script = New-LabScript $sql
    $setupOut = Invoke-LabSql $script.Setup $true
    try {
        if (($setupOut -join "`n") -notmatch 'client exit=0') { return $setupOut }
        return (Invoke-LabSql $script.Facts $false)
    } finally {
        $cleanOut = Invoke-LabSql $script.Cleanup $true
        if (($cleanOut -join "`n") -notmatch 'client exit=0') { Write-Output ('LAB_CLEANUP_FAILED ' + ($cleanOut -join '|')) }
    }
}function Convert-LabOutput([string[]]$lines) {
    # restituisce DocId -> hashtable colonna/valore; nessuna riga = NOROW
    $result = @{}; $current = $null; $headers = $null; $expectRow = $false
    foreach ($line in $lines) {
        if ($line -match '^DOC=(\d+)$') { $current = [int]$Matches[1]; $headers = $null; $expectRow = $false; $result[$current] = 'NOROW'; continue }
        if ($null -eq $current) { continue }
        $cols = $line -split "`t"
        if ($cols[0] -eq 'id' -and $cols -contains 'RpOrigin') { $headers = $cols; $expectRow = $true; continue }
        if ($expectRow -and $headers -and $cols.Count -eq $headers.Count) { $h = @{}; for ($i = 0; $i -lt $headers.Count; $i++) { $h[$headers[$i]] = $cols[$i] }; $result[$current] = $h; $expectRow = $false }
    }
    return $result
}
function Test-LabScenarios([string]$sql, [Text.StringBuilder]$log, [string]$moduleForProbe, [string]$policyForProbe) {
    $lines = Invoke-LabFacts $sql $log
    if (($lines -join "`n") -notmatch 'client exit=0') { Show-Failure ('lab exit ' + ($lines -join '|')); return $false }
    if (($lines -join "`n") -match 'ERROR \d+') { Show-Failure ('lab error ' + (($lines | Where-Object { $_ -match 'ERROR' } | Select-Object -First 2) -join '|')); return $false }
    $facts = Convert-LabOutput $lines
    try { $probe = New-RemoteProbe $moduleForProbe $policyForProbe } catch { Show-Failure 'compile for lab'; return $false }
    $ok = $true
    foreach ($id in $labExpected.Keys) {
        $row = $facts[[int]$id]
        $got = $false
        if ($row -is [hashtable]) {
            $nowText = [string]$row['RpNow']; $todayText = [string]$row['RpToday']; $docDate = [string]$row['RpDocDate']; $stateDate = [string]$row['RpStatoData']
            if ($docDate -eq 'NULL') { $docDate = '' }; if ($stateDate -eq 'NULL') { $stateDate = '' }
            $got = $probe.DecideRow([string]$row['RpOrigin'], [int]$row['RpOrdineWeb'], $docDate, $todayText, $nowText, [int]$row['RpPagato'], [int]$row['RpStatiId'], [int]$row['RpStato'], $stateDate, $(if ([string]$row['RpEsito'] -eq 'NULL') { '' } else { [string]$row['RpEsito'] }),
                [int]$row['RpOnLine'], [int]$row['RpPermetti'], [decimal]::Parse([string]$row['RpTotale'], [Globalization.CultureInfo]::InvariantCulture), ([int]$row['RpValidType'] -eq 1), ([int]$row['RpSella'] -eq 1),
                ([int]$row['RpPayPalAny'] -eq 1), ([int]$row['RpPayPalOther'] -eq 1), $false)
        }
        if ($got -ne $labExpected[$id]) { Show-Failure ('lab doc ' + $id + ' got=' + $got); $ok = $false }
    }
    if ($facts[990119] -ne 'NOROW') { Show-Failure 'other user sees a row'; $ok = $false }
    if (($lines -join "`n") -notmatch 'marketplace_probe\s+0' -or ($lines -join "`n") -notmatch 'marketplace_probe_ebay\s+0') { Show-Failure 'marketplace probe'; $ok = $false }
    return $ok
}
$labLog = New-Object Text.StringBuilder
if (-not $SkipLab) {
    Assert-Source (Test-LabScenarios $factsSql $labLog $moduleText $policyText) 'R03_THE_REAL_FACTS_QUERY_ON_THE_LAB_GIVES_THE_RIGHT_ANSWER_TO_EVERY_ORDER_SCENARIO'
}

# --- Oracolo 3: le superfici --------------------------------------------------------------------------------------------------------------------------
function Test-Surfaces([string]$store, [string]$lVb, [string]$lAspx, [string]$dVb, [string]$dAspx, [string]$pVb, [string]$sVb, [string]$rVb, [string]$stVb, [string]$cssText) {
    $sc = Strip-VbComments $store
    if ($sc -notmatch 'd\.id=@id AND d\.UtentiId=@uid AND d\.AziendeId=@azienda LIMIT 1') { Show-Failure 'facts owner filter'; return $false }
    if ($sc -notmatch "ro\.Stato NOT IN \('CANCELED','FAILED','DENIED','DECLINED','VOIDED','SUPERSEDED'\)" -or $sc -notmatch 'ro\.PagamentiTipoId<>d\.PagamentiTipoId OR COALESCE\(p\.OnLine,0\)<>2') { Show-Failure 'facts paypal other'; return $false }
    if ($sc -notmatch 'COALESCE\(d\.Ordine_Web,0\) RpOrdineWeb' -or $sc -notmatch 'CURDATE\(\) RpToday' -or $sc -notmatch 'NOW\(\) RpNow') { Show-Failure 'facts columns'; return $false }
    if ($sc -notmatch 'AND COALESCE\(Pagato,0\)=0 AND COALESCE\(StatoPagamentoWeb,0\) IN \(0,3,4,5\)' -or $sc -notmatch 'UPDATE documenti SET DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@outcome WHERE' -or $sc -match 'UPDATE documenti SET StatoPagamentoWeb') { Show-Failure 'sella start sql'; return $false }
    if ($sc -notmatch 'COALESCE\(d\.UltimoEsitoPagamentoWeb,''''\) RpEsito') { Show-Failure 'facts outcome'; return $false }
    if ($sc -notmatch 'HasMarketplaceLink\(conn, "ks_amazon_orders", documentId\) OrElse HasMarketplaceLink\(conn, "ks_ebay_orders", documentId\)') { Show-Failure 'marketplace'; return $false }
    if ($sc -notmatch 'Catch ex As Exception\s*\n\s*KeepStoreLog\.Error\("remote-payment", "LoadFacts[^\n]*\n\s*Return Nothing') { Show-Failure 'fail closed'; return $false }
    foreach ($pair in @(@('list', $lVb), @('detail', $dVb), @('paypal', $pVb), @('sella', $sVb))) {
        $c = Strip-VbComments $pair[1]
        if ($c -notmatch 'InternalOrderRemotePaymentPolicy\.CanPayNow\(\s*(_?\s*\n\s*)?KeepStoreRemotePaymentStore\.LoadFacts\(') { Show-Failure ($pair[0] + ' uses facts'); return $false }
        if ($c -match 'CanPayNow\((info|doc|document)\.OrigineOrdine|CanPayNow\(Convert\.ToString\(dr\("OrigineOrdine"\)\)') { Show-Failure ($pair[0] + ' old origin-only call'); return $false }
    }
    $p = Strip-VbComments $pVb
    if ($p -notmatch 'Dim viaLaunch As Boolean = isWeb AndAlso PayPalWebLaunchContext\.BeginPayPal\(HttpContext\.Current, documentId, owner\)') { Show-Failure 'paypal viaLaunch'; return $false }
    if ($p -notmatch 'doc\.RemoteManaged = True') { Show-Failure 'paypal remote managed'; return $false }
    if ([regex]::Matches($p, 'If viaLaunch Then PayPalWebLaunchContext\.FinishPayPal').Count -ne 3 -or $p -notmatch 'If viaLaunch AndAlso Not PayPalWebLaunchContext\.BindPayPalAttempt' -or $p -notmatch 'If Not viaLaunch AndAlso \(String\.Equals\(tx\.Stato, "CANCELED"') { Show-Failure 'paypal viaLaunch uses'; return $false }
    if ([regex]::Matches($p, '\bisWeb\b').Count -ne 2) { Show-Failure 'paypal isWeb leftovers'; return $false }
    $s = Strip-VbComments $sVb
    if ($s -notmatch 'Dim viaLaunch As Boolean = String\.Equals\(document\.OrigineOrdine, "WEB", StringComparison\.OrdinalIgnoreCase\) AndAlso\s*\n\s*PayPalWebLaunchContext\.Consume\(HttpContext\.Current, documentId, owner, "SELLA", requestedAmount\)') { Show-Failure 'sella viaLaunch'; return $false }
    if ($s -notmatch 'requestedAmount <> Math\.Round\(document\.TotalDocument, 2, MidpointRounding\.AwayFromZero\)') { Show-Failure 'sella amount'; return $false }
    $iMark = $s.IndexOf('KeepStoreRemotePaymentStore.MarkSellaStarted(documentId, owner.UtentiId, owner.CompanyId)', [StringComparison]::Ordinal)
    $iRedirect = $s.IndexOf('Response.Redirect(urlPagamento, False)', [StringComparison]::Ordinal)
    if ($iMark -lt 0 -or $iRedirect -lt 0 -or $iMark -ge $iRedirect) { Show-Failure 'sella marker before redirect'; return $false }
    $r = Strip-VbComments $rVb
    if ($r -notmatch 'Not \(doc\.RemoteManaged OrElse String\.Equals\(doc\.OrigineOrdine, "INTERNO"' -or $r -notmatch 'MaySupersede\(If\(doc\.RemoteManaged, "INTERNO", doc\.OrigineOrdine\)') { Show-Failure 'next attempt'; return $false }
    if ((Strip-VbComments $stVb) -notmatch 'Public Property RemoteManaged As Boolean') { Show-Failure 'remote managed property'; return $false }
    # interfaccia: lista
    if ($lAspx -notmatch 'ID="hlListaPagaAdesso" runat="server"[^>]*NavigateUrl=''<%# Eval\("id", "documentidettaglio\.aspx\?id=\{0\}#ksPayNow"\) %>'' Visible=''<%# ListPayNowVisible\(Eval\("id"\)\) %>'' Text="Paga adesso"') { Show-Failure 'list button'; return $false }
    if ($lAspx -notmatch 'ID="lblListaDaPagare" runat="server" CssClass="ks-pay-now__badge" Text="Da pagare" Visible=''<%# ListPayNowVisible\(Eval\("id"\)\) %>''') { Show-Failure 'list badge'; return $false }
    if ($lAspx -notmatch 'order-ui\.css"\) %>\?v=20261117-pay-now-1a') { Show-Failure 'list css buster'; return $false }
    if ((Strip-VbComments $lVb) -notmatch 'Protected Function ListPayNowVisible\(ByVal documentIdObj As Object\) As Boolean\s*\n\s*Return CanShowPayNow\(SafeInt\(documentIdObj, 0\)\)') { Show-Failure 'list helper'; return $false }
    # interfaccia: dettaglio
    $iAnchor = $dAspx.IndexOf('<span id="ksPayNow"></span>', [StringComparison]::Ordinal)
    $iCard = $dAspx.IndexOf('id="pnlPayNowCard" runat="server" visible="false" class="ks-pay-now"', [StringComparison]::Ordinal)
    $iHero = $dAspx.IndexOf('<section class="ks-order-confirmation"', [StringComparison]::Ordinal)
    if ($iAnchor -lt 0 -or $iCard -lt 0 -or $iHero -lt 0 -or -not ($iAnchor -lt $iCard -and $iCard -lt $iHero)) { Show-Failure 'detail card above the summary'; return $false }
    $card = $dAspx.Substring($iCard, $iHero - $iCard)
    foreach ($id in @('tbTipo', 'tbOnline', 'hfPayNowDocumentId', 'hlBancaSella', 'hlPayPalCheckout', 'btIwBank', 'btPayPal')) { if ($card -notmatch ('ID="' + $id + '"')) { Show-Failure ('detail id ' + $id); return $false } }
    if ($card -notmatch 'aria-labelledby="ksPayNowTitle"' -or [regex]::Matches($card, '<h2 id="ksPayNowTitle">').Count -ne 1 -or $card -notmatch '<svg[^>]*aria-hidden="true"') { Show-Failure 'detail a11y'; return $false }
    if ($card -notmatch 'Eval\("TotaleDocumento", "\{0:C\}"\)' -or $card -notmatch 'Eval\("PagamentiTipoDescrizione"\)') { Show-Failure 'detail amount and method'; return $false }
    if ([regex]::Matches($card, 'ks-pay-now__btn').Count -lt 3) { Show-Failure 'detail buttons'; return $false }
    if ($dAspx -notmatch 'order-ui\.css"\) %>\?v=20261117-(pay-now|progress)-1a') { Show-Failure 'detail css buster'; return $false }
    if ($dAspx.Contains('I pulsanti di pagamento vengono mostrati solo')) { Show-Failure 'old jargon text'; return $false }
    # stili
    if ($cssText -notmatch '(?s)\.ks-pay-now__btn\s*\{[^}]*min-height:\s*44px') { Show-Failure 'css 44'; return $false }
    if ($cssText -notmatch '(?s)@media \(max-width: 575px\)\s*\{\s*\.ks-pay-now__actions\s*\{[^}]*flex-direction:\s*column') { Show-Failure 'css mobile'; return $false }
    if ($cssText -notmatch '(?s)\.ks-pay-now\s*\{[^}]*box-shadow:\s*5px 6px 30px 0 rgba\(0, 0, 0, \.1\)') { Show-Failure 'css onsus shadow'; return $false }
    return $true
}
Assert-Source (Test-Surfaces $storeText $listVb $listAspx $detailVb $detailAspx $ppVb $sellaVb $repoVb $stateVb $css) 'R04_THE_FOUR_SURFACES_USE_THE_FULL_DECISION_THE_WEB_LAUNCH_IS_SEPARATE_SELLA_START_IS_MARKED_AND_THE_UI_IS_PROMINENT'

if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED'; exit 0 }

# --- Mutazioni ------------------------------------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'D01_WINDOW_91'; Target = 'module'; Old = 'Public Const WindowDays As Integer = 90'; New = 'Public Const WindowDays As Integer = 91' },
    @{ Id = 'D02_NO_MARKETPLACE_CHECK'; Target = 'module'; Old = 'If facts.Marketplace OrElse Not InWindow(facts) Then Return ""'; New = 'If Not InWindow(facts) Then Return ""' },
    @{ Id = 'D03_EMPTY_ORIGIN_IGNORES_ORDINE_WEB'; Target = 'module'; Old = 'If origin = String.Empty AndAlso facts.OrdineWeb = 0 Then'; New = 'If origin = String.Empty Then' },
    @{ Id = 'D04_WEB_ALLOWS_ANY_PAYMENT_STATE'; Target = 'module'; Old = 'If facts.PaymentState <> 0 OrElse facts.PayPalAny OrElse Not InWindow(facts) Then Return ""'; New = 'If facts.PayPalAny OrElse Not InWindow(facts) Then Return ""' },
    @{ Id = 'D05_WEB_ALLOWS_PAYPAL_HISTORY'; Target = 'module'; Old = 'If facts.PaymentState <> 0 OrElse facts.PayPalAny OrElse Not InWindow(facts) Then Return ""'; New = 'If facts.PaymentState <> 0 OrElse Not InWindow(facts) Then Return ""' },
    @{ Id = 'D06_WEB_WITHOUT_WINDOW'; Target = 'module'; Old = 'If facts.PaymentState <> 0 OrElse facts.PayPalAny OrElse Not InWindow(facts) Then Return ""'; New = 'If facts.PaymentState <> 0 OrElse facts.PayPalAny Then Return ""' },
    @{ Id = 'D08_FUTURE_DATE_ALLOWED'; Target = 'module'; Old = 'Return days >= 0.0 AndAlso days <= CDbl(WindowDays)'; New = 'Return days <= CDbl(WindowDays)' },
    @{ Id = 'D09_WINDOW_BOUNDARY_OFF_BY_ONE'; Target = 'module'; Old = 'Return days >= 0.0 AndAlso days <= CDbl(WindowDays)'; New = 'Return days >= 0.0 AndAlso days < CDbl(WindowDays)' },
    @{ Id = 'D10_OTHER_ORIGINS_OPEN'; Target = 'module'; Old = '        Return ""
    End Function

    '' Un pagamento Banca Sella'; New = '        Return "INTERNO"
    End Function

    '' Un pagamento Banca Sella' },
    @{ Id = 'D11_SELLA_GUARD_MINUTES_30'; Target = 'module'; Old = 'Public Const SellaStartGuardMinutes As Integer = 60'; New = 'Public Const SellaStartGuardMinutes As Integer = 30' },
    @{ Id = 'D12_SELLA_UNKNOWN_DATE_ALLOWED'; Target = 'module'; Old = 'If facts.PaymentStateDate = DateTime.MinValue OrElse facts.DbNow = DateTime.MinValue Then Return True'; New = 'If facts.PaymentStateDate = DateTime.MinValue OrElse facts.DbNow = DateTime.MinValue Then Return False' },
    @{ Id = 'D13_SELLA_IN_FLIGHT_IGNORED'; Target = 'policy'; Old = 'If KeepStoreRemotePayment.SellaMayBeInFlight(facts) Then Return False'; New = '' },
    @{ Id = 'D14_PAYPAL_OTHER_IGNORED'; Target = 'policy'; Old = 'If facts.PayPalOpenOther Then Return False'; New = '' },
    @{ Id = 'D15_BASE_GATES_SKIPPED'; Target = 'policy'; Old = 'facts.PaymentState, facts.OnlineMethod, facts.AllowLater, facts.SellaAuthorized, facts.Total) Then Return False'; New = 'facts.PaymentState, facts.OnlineMethod, facts.AllowLater, facts.SellaAuthorized, facts.Total) AndAlso False Then Return False' },
    @{ Id = 'D16_NOTHING_ALLOWED'; Target = 'policy'; Old = 'If facts Is Nothing Then Return False
        Dim originClass'; New = 'If facts Is Nothing Then Return True
        Dim originClass' },
    @{ Id = 'D17_SELLA_GUARD_IGNORES_PAYPAL_HISTORY'; Target = 'module'; Old = 'If facts.OnlineMethod <> 2 OrElse facts.PayPalAny Then Return False'; New = 'If facts.OnlineMethod <> 2 Then Return False' },
    @{ Id = 'D19_SELLA_GUARD_WITHOUT_THE_MARKER'; Target = 'module'; Old = 'If Not String.Equals(If(facts.LastOutcome, String.Empty).Trim(), SellaStartedOutcome, StringComparison.Ordinal) Then Return False'; New = '' },
    @{ Id = 'D18_WEB_MARKED_INTERNO_WITHOUT_ORIGIN_CHECK'; Target = 'module'; Old = 'If origin = "WEB" OrElse (origin = String.Empty AndAlso facts.OrdineWeb <> 0) Then'; New = 'If origin = "WEB" Then' },
    @{ Id = 'S01_PAYPAL_HISTORY_TERMINAL_LIST_WITHOUT_VOIDED'; Target = 'store'; Old = "'DECLINED','VOIDED','SUPERSEDED'"; New = "'DECLINED','SUPERSEDED'" },
    @{ Id = 'S02_PAYPAL_OTHER_WITHOUT_METHOD_COMPARISON'; Target = 'store'; Old = 'AND (ro.PagamentiTipoId<>d.PagamentiTipoId OR COALESCE(p.OnLine,0)<>2)'; New = 'AND (COALESCE(p.OnLine,0)<>2)' },
    @{ Id = 'S03_ORDINE_WEB_NOT_READ'; Target = 'store'; Old = 'COALESCE(d.Ordine_Web,0) RpOrdineWeb'; New = '0 RpOrdineWeb' },
    @{ Id = 'S04_NO_OWNER_FILTER'; Target = 'store'; Old = 'WHERE d.id=@id AND d.UtentiId=@uid AND d.AziendeId=@azienda LIMIT 1'; New = 'WHERE d.id=@id AND d.AziendeId=@azienda LIMIT 1' },
    @{ Id = 'S06_SELLA_START_CHANGES_THE_PAYMENT_STATE'; Target = 'store'; Old = 'UPDATE documenti SET DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@outcome'; New = 'UPDATE documenti SET StatoPagamentoWeb=1,DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@outcome' },
    @{ Id = 'S05_SELLA_AUTHORIZATION_IGNORED'; Target = 'store'; Old = "AND COALESCE(rb.codiceAutorizzazione,'')<>''"; New = '' },
    @{ Id = 'P01_LIST_BACK_TO_ORIGIN_ONLY'; Target = 'listvb'; Old = 'KeepStoreRemotePaymentStore.LoadFacts(documentId, CurrentOrderIdentity.UtentiId, CurrentOrderIdentity.CompanyId)'; New = 'Nothing' },
    @{ Id = 'P02_PAYPAL_WEB_NO_LAUNCH_SEPARATION'; Target = 'ppvb'; Old = 'Dim viaLaunch As Boolean = isWeb AndAlso PayPalWebLaunchContext.BeginPayPal(HttpContext.Current, documentId, owner)'; New = 'Dim viaLaunch As Boolean = isWeb' },
    @{ Id = 'P03_PAYPAL_NO_REMOTE_MANAGED'; Target = 'ppvb'; Old = 'doc.RemoteManaged = True'; New = 'Dim unused As Boolean = True' },
    @{ Id = 'P04_PAYPAL_BIND_ON_ORIGIN'; Target = 'ppvb'; Old = 'If viaLaunch AndAlso Not PayPalWebLaunchContext.BindPayPalAttempt'; New = 'If isWeb AndAlso Not PayPalWebLaunchContext.BindPayPalAttempt' },
    @{ Id = 'P05_SELLA_NO_MARKER'; Target = 'sellavb'; Old = 'KeepStoreRemotePaymentStore.MarkSellaStarted(documentId, owner.UtentiId, owner.CompanyId)'; New = "Dim unused As Integer = 0" },
    @{ Id = 'P06_SELLA_AMOUNT_NOT_CHECKED'; Target = 'sellavb'; Old = 'requestedAmount <> Math.Round(document.TotalDocument, 2, MidpointRounding.AwayFromZero) Then'; New = 'False Then' },
    @{ Id = 'P07_REPO_NEXT_ATTEMPT_INTERNO_ONLY'; Target = 'repovb'; Old = 'Not (doc.RemoteManaged OrElse String.Equals(doc.OrigineOrdine, "INTERNO", StringComparison.OrdinalIgnoreCase))'; New = 'Not (String.Equals(doc.OrigineOrdine, "INTERNO", StringComparison.OrdinalIgnoreCase))' },
    @{ Id = 'U01_LIST_BUTTON_ALWAYS_VISIBLE'; Target = 'listaspx'; Old = "Visible='<%# ListPayNowVisible(Eval(""id"")) %>' Text=""Paga adesso"""; New = 'Text="Paga adesso"' },
    @{ Id = 'U02_LIST_BADGE_REMOVED'; Target = 'listaspx'; Old = 'ID="lblListaDaPagare" runat="server" CssClass="ks-pay-now__badge" Text="Da pagare"'; New = 'ID="lblListaDaPagare" runat="server" CssClass="body-small" Text="Da pagare"' },
    @{ Id = 'U03_DETAIL_CARD_AT_THE_BOTTOM'; Target = 'detailaspx'; Old = '<span id="ksPayNow"></span>'; New = '' },
    @{ Id = 'U04_DETAIL_CSS_BUSTER_UNCHANGED'; Target = 'detailaspx'; Old = 'order-ui.css") %>?v=20261117-progress-1a"'; New = 'order-ui.css") %>?v=20260609-order-confirmation-1a"' },
    @{ Id = 'U05_BUTTON_HEIGHT'; Target = 'css'; Old = '    min-height: 44px;
    align-items: center;
    justify-content: center;
    text-align: center;
}

.ks-pay-now__badge'; New = '    min-height: 30px;
    align-items: center;
    justify-content: center;
    text-align: center;
}

.ks-pay-now__badge' },
    @{ Id = 'U06_OLD_JARGON_TEXT_BACK'; Target = 'detailaspx'; Old = 'Premi il pulsante per andare alla pagina di pagamento.'; New = 'I pulsanti di pagamento vengono mostrati solo per documenti online non ancora saldati.' }
)
$labMutantsDone = 0
foreach ($mu in $mutants) {
    $mm = $moduleText; $mp = $policyText; $ms = $storeText; $mlv = $listVb; $mla = $listAspx; $mdv = $detailVb; $mda = $detailAspx; $mpv = $ppVb; $msv = $sellaVb; $mrv = $repoVb; $mcss = $css
    switch ($mu.Target) {
        'module' { $mm = Mutate-Text $moduleText $mu.Old $mu.New $mu.Id }
        'policy' { $mp = Mutate-Text $policyText $mu.Old $mu.New $mu.Id }
        'store' { $ms = Mutate-Text $storeText $mu.Old $mu.New $mu.Id }
        'listvb' { $mlv = Mutate-Text $listVb $mu.Old $mu.New $mu.Id }
        'listaspx' { $mla = Mutate-Text $listAspx $mu.Old $mu.New $mu.Id }
        'detailaspx' { $mda = Mutate-Text $detailAspx $mu.Old $mu.New $mu.Id }
        'ppvb' { $mpv = Mutate-Text $ppVb $mu.Old $mu.New $mu.Id }
        'sellavb' { $msv = Mutate-Text $sellaVb $mu.Old $mu.New $mu.Id }
        'repovb' { $mrv = Mutate-Text $repoVb $mu.Old $mu.New $mu.Id }
        'css' { $mcss = Mutate-Text $css $mu.Old $mu.New $mu.Id }
    }
    $still = $true
    if ($mu.Target -in @('module', 'policy')) { $still = (Test-DecisionMatrix $mm $mp) -and (Test-ModuleStructure $mm $mp) }
    elseif ($mu.Target -eq 'store') {
        $still = (Test-Surfaces $ms $listVb $listAspx $detailVb $detailAspx $ppVb $sellaVb $repoVb $stateVb $css)
        if ($still -and -not $SkipLab) { $mutSql = Get-FactsSql $ms 'FactsSql'; $still = Test-LabScenarios $mutSql $labLog $moduleText $policyText; $labMutantsDone++ }
    }
    else { $still = Test-Surfaces $ms $mlv $mla $mdv $mda $mpv $msv $mrv $stateVb $mcss }
    Assert-Detected $still $mu.Id
}
Write-Output ('REMOTE_PAYMENT_TEST_PASS mutants=' + $mutants.Count + ' labMutants=' + $labMutantsDone)
