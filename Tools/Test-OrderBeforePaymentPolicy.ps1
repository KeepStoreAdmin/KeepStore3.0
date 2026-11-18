[CmdletBinding()]
param([switch]$SkipLab)

# PAYMENT-PAY-FIRST-BY-FLAG-1A (T1). Il campo pagamentitipo.ConfermaOrdinePrimaPagamento decide per metodo: con 0 il sito non crea mai un ordine
# prima del pagamento. PayPal (OnLine 2) ha gia il percorso "paga prima"; per ogni altro metodo (carta Banca Sella, contanti, bonifico) il sito
# rifiuta il metodo senza creare documenti finche quel percorso non esiste. Quattro parti: (A) contratto dei sorgenti, (B) comportamento del
# modulo compilato (tabella di verita completa, equivalenza con PayPalPayFirstPolicy.Applies), (C) mutazioni, (D) lettore sul LAB locale con il
# connettore del sito (riga giusta, altra azienda, id inesistente, flag 0 dentro una transazione annullata). Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    module   = Read-Repo 'App_Code/KeepStoreOrderBeforePaymentPolicy.vb'
    order    = Read-Repo 'ordine.aspx.vb'
    cart     = Read-Repo 'carrello.aspx.vb'
    recovery = Read-Repo 'App_Code/CheckoutFailureRecoveryService.vb'
    payfirst = Read-Repo 'App_Code/PayPalPayFirst.vb'
}

function Get-Index([string]$text, [string]$needle, [int]$from = 0) { if ($from -lt 0) { return -1 }; return $text.IndexOf($needle, $from, [StringComparison]::Ordinal) }

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $o = $f.order; $c = $f.cart; $r = $f.recovery; $m = $f.module; $pf = $f.payfirst

    # A1 il gate PayPal prima del lock resta quello di sempre (nessuna delega: le ancore dei mutanti PayPal restano valide)
    if ($pf -notmatch [regex]::Escape('Return paymentOnline = PayPalOnlineValue AndAlso confirmBeforePayment = 0 AndAlso documentType > 0 AndAlso documentType <> QuoteDocumentType AndAlso Not hasCoupon')) { $fail.Add('A1 PayPalPayFirstPolicy.Applies cambiata') }

    # A2 ordine.aspx: il controllo nuovo sta DOPO la riconciliazione dei replay completati e dopo ValidateAuthoritativeSelections, PRIMA di transazione e claim
    $iLock = Get-Index $o 'SyncLock Semaforo'
    $iReplay = Get-Index $o 'OrderDurableIdempotencyService.TryReadCompleted(' $iLock
    $iRetired = Get-Index $o '"11-state-reconciliation", "new")' $iLock
    $iValidate = Get-Index $o 'CheckoutDraftService.ValidateAuthoritativeSelections(' $iLock
    $iGate = Get-Index $o 'KeepStoreOrderBeforePaymentPolicy.TryRead(conn, Nothing, orderIdentity.CompanyId, checkoutDraft.PaymentMethodId, paymentPolicy)'
    $iProfile = Get-Index $o 'Dim currentCommercialProfile As String'
    $iTxn = Get-Index $o 'trns = conn.BeginTransaction(IsolationLevel.Serializable)'
    $iClaim = Get-Index $o 'OrderDurableIdempotencyService.TryClaim('
    if ($iGate -lt 0) { $fail.Add('A2 controllo della politica assente in ordine.aspx') }
    else {
        if (-not ($iLock -ge 0 -and $iLock -lt $iReplay -and $iReplay -lt $iRetired -and $iRetired -lt $iValidate -and $iValidate -lt $iGate)) { $fail.Add('A2 il controllo non segue riconciliazione e validazione della bozza') }
        if (-not ($iGate -lt $iProfile)) { $fail.Add('A2 il controllo non precede il profilo commerciale') }
        if (-not ($iTxn -gt $iGate -and $iClaim -gt $iGate)) { $fail.Add('A2 il controllo non precede transazione e claim') }
        if ($o.IndexOf('KeepStoreOrderBeforePaymentPolicy.TryRead(', $iGate + 10, [StringComparison]::Ordinal) -ge 0) { $fail.Add('A2 controllo duplicato') }
        $block = $o.Substring($iGate - 260, [Math]::Min(1700, $o.Length - $iGate + 260))
        if ($block -notmatch 'If Not payFirst Then\s+Dim paymentPolicy As PaymentPolicySnapshot = Nothing\s+Dim paymentPolicyRead As Boolean = KeepStoreOrderBeforePaymentPolicy\.TryRead\(') { $fail.Add('A2 il controllo non e limitato alle creazioni senza tentativo autorizzato') }
        if ($block -notmatch 'KeepStoreOrderBeforePaymentPolicy\.Evaluate\(\s*paymentPolicyRead, paymentPolicy, checkoutDraft\.PaymentOnline, checkoutDraft\.ConfirmBeforePayment, checkoutDraft\.TipoDocumentiId,\s*PayPalPayFirstPolicy\.HasCoupon\(Convert\.ToString\(Session\("Coupon_Codice_Controllo"\), CultureInfo\.InvariantCulture\), GetSessionInt\("Coupon_idArticolo", 0\)\)\)') { $fail.Add('A2 Evaluate non riceve lettura, bozza, tipo documento e coupon') }
        if ($block -notmatch 'If paymentPolicyOutcome <> PaymentPolicyGateOutcome\.Allowed Then\s+Dim paymentPolicyReason As CheckoutFailureReason = CheckoutFailureReason\.TechnicalTransient\s+If paymentPolicyOutcome = PaymentPolicyGateOutcome\.NotAllowed Then paymentPolicyReason = CheckoutFailureReason\.PaymentMethodNotAllowed\s+If paymentPolicyOutcome = PaymentPolicyGateOutcome\.Changed Then paymentPolicyReason = CheckoutFailureReason\.CartChanged\s+DispatchDurableCheckoutFailure\(checkoutRequestId, paymentPolicyReason, "ValidatePaymentPolicy"\)\s+Exit Sub\s+End If\s+End If') { $fail.Add('A2 esito diverso da Allowed non esce senza documento') }
    }
    # A3 il testo falso non esiste piu; il ramo dei preventivi e dei coupon resta con un testo vero
    if ($o -match 'enforcement non ancora attivo') { $fail.Add('A3 testo "enforcement non ancora attivo" ancora presente') }
    if ($o -notmatch 'If confermaOrdinePrimaPagamento = 0 Then\s+statoPagamentoWeb = 1\s+ultimoEsito = "In attesa pagamento online \(preventivo o coupon\)"') { $fail.Add('A3 ramo flag 0 di InitializeWebPaymentStatus') }

    # A4 carrello: lettura autorevole dopo la validazione del metodo, errore = rifiuto, sessione riscritta, flag 0 non supportato = motivo dedicato
    $iPay = Get-Index $c '"not-claimed", "none", "ValidatePayment")'
    $iRead = Get-Index $c 'If Not KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, identity.CompanyId, paymentId, paymentPolicy) Then'
    $iSeal = Get-Index $c 'draft = CheckoutDraftService.Seal('
    $iOpt = Get-Index $c 'Dim optionsFingerprint As String' $iRead
    if ($iRead -lt 0) { $fail.Add('A4 lettura autorevole assente nel carrello') }
    else {
        if (-not ($iPay -ge 0 -and $iPay -lt $iRead -and $iOpt -gt $iRead -and $iOpt -lt $iSeal)) { $fail.Add('A4 la lettura non sta fra validazione del metodo e bozza') }
        $cb = $c.Substring($iRead, [Math]::Min(1500, $c.Length - $iRead))
        if ($cb -notmatch '^If Not KeepStoreOrderBeforePaymentPolicy\.TryRead\([^\r\n]+\) Then\s+failureReason = CheckoutFailureReason\.TechnicalTransient\s+Return False\s+End If') { $fail.Add('A4 errore di lettura non rifiuta') }
        foreach ($pair in @(@('Ordine_Pagamento_OnLine', 'OnLine'), @('Ordine_ConfermaOrdinePrimaPagamento', 'ConfirmBeforePayment'), @('Ordine_PermettiPagamentoSuccessivo', 'AllowLaterPayment'), @('Ordine_InviaEmailOrdinePrimaPagamento', 'SendEmailBeforePayment'))) {
            if ($cb -notmatch [regex]::Escape('Session("' + $pair[0] + '") = paymentPolicy.' + $pair[1])) { $fail.Add('A4 sessione non riscritta: ' + $pair[0]) }
        }
        if ($cb -notmatch 'If KeepStoreOrderBeforePaymentPolicy\.Decide\(paymentPolicy\.OnLine, paymentPolicy\.ConfirmBeforePayment, tipoDocumento,\s*PayPalPayFirstPolicy\.HasCoupon\(Convert\.ToString\(Session\("Coupon_Codice_Controllo"\)\), GetSessionInt\("Coupon_idArticolo", 0\)\)\) = OrderBeforePaymentDecision\.NotSupported Then\s+failureReason = CheckoutFailureReason\.PaymentMethodNotAllowed\s+Return False\s+End If') { $fail.Add('A4 flag 0 non supportato non rifiuta') }
    }
    # A5 il motivo nuovo riporta al passo di scelta del pagamento, con il suo messaggio
    if ($c -notmatch 'CheckoutFailureReason\.PaymentMethodMissing,\s+CheckoutFailureReason\.PaymentMethodNotAllowed\s+SetCheckoutStep\("checkout"\)') { $fail.Add('A5 il motivo nuovo non riporta al passo checkout') }
    if ($r -notmatch 'PaymentMethodNotAllowed = 10') { $fail.Add('A5 motivo PaymentMethodNotAllowed assente') }
    if ($r -notmatch 'Case CheckoutFailureReason\.PaymentMethodNotAllowed\s+Return "Il metodo di pagamento scelto al momento non accetta ordini dal sito\. Scegli un altro metodo di pagamento e conferma di nuovo l''ordine\."') { $fail.Add('A5 messaggio del motivo nuovo') }

    # A6 lettore: una riga esatta per id E azienda sulla tabella (la vista non espone il flag), errore = False
    if ($m -notmatch 'FROM pagamentitipo WHERE id=\?id AND AziendeID=\?aziendaId"') { $fail.Add('A6 lettore senza filtro azienda') }
    if ($m -match 'vpagamentitipo') { $fail.Add('A6 lettore sulla vista') }
    if ($m -match 'HttpContext|Session\(|ConfigurationManager') { $fail.Add('A6 modulo non autonomo') }

    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Text
Public Module OrderBeforePaymentProbe
    Private sb As New StringBuilder()
    Private Sub T(ByVal name As String, ByVal ok As Boolean)
        If sb.Length > 0 Then sb.Append(";")
        sb.Append(name).Append("=").Append(ok.ToString())
    End Sub
    ' Regola attesa scritta a mano, indipendente dal modulo.
    Private Function Expected(ByVal onLine As Integer, ByVal flag As Integer, ByVal docType As Integer, ByVal coupon As Boolean) As OrderBeforePaymentDecision
        If docType <= 0 Then Return OrderBeforePaymentDecision.OrderFirst
        If docType = 2 Then Return OrderBeforePaymentDecision.OrderFirst
        If coupon Then Return OrderBeforePaymentDecision.OrderFirst
        If flag <> 0 Then Return OrderBeforePaymentDecision.OrderFirst
        If onLine = 2 Then Return OrderBeforePaymentDecision.PayFirstPayPal
        Return OrderBeforePaymentDecision.NotSupported
    End Function
    ' Espressione di PayPalPayFirstPolicy.Applies (controllata nel sorgente dalla parte A1).
    Private Function Applies(ByVal onLine As Integer, ByVal flag As Integer, ByVal docType As Integer, ByVal coupon As Boolean) As Boolean
        Return onLine = 2 AndAlso flag = 0 AndAlso docType > 0 AndAlso docType <> 2 AndAlso Not coupon
    End Function
    Private Function Snap(ByVal onLine As Integer, ByVal flag As Integer) As PaymentPolicySnapshot
        Return New PaymentPolicySnapshot() With {.OnLine = onLine, .ConfirmBeforePayment = flag, .AllowLaterPayment = 1, .SendEmailBeforePayment = 1}
    End Function
    Public Function Run() As String
        Dim okTable As Boolean = True, okApplies As Boolean = True, cells As Integer = 0
        For Each onLine As Integer In New Integer() {-1, 0, 1, 2, 3, 4, 9}
            For Each flag As Integer In New Integer() {-1, 0, 1, 2}
                For Each docType As Integer In New Integer() {-1, 0, 1, 2, 4, 7}
                    For Each coupon As Boolean In New Boolean() {False, True}
                        cells += 1
                        Dim got As OrderBeforePaymentDecision = KeepStoreOrderBeforePaymentPolicy.Decide(onLine, flag, docType, coupon)
                        If got <> Expected(onLine, flag, docType, coupon) Then okTable = False
                        If (got = OrderBeforePaymentDecision.PayFirstPayPal) <> Applies(onLine, flag, docType, coupon) Then okApplies = False
                    Next
                Next
            Next
        Next
        T("B01_tabella_di_verita", okTable AndAlso cells = 336)
        T("B02_equivalenza_con_Applies", okApplies)
        T("B03_carta_flag0_ordine", KeepStoreOrderBeforePaymentPolicy.Decide(3, 0, 4, False) = OrderBeforePaymentDecision.NotSupported)
        T("B04_offline_flag0_ordine", KeepStoreOrderBeforePaymentPolicy.Decide(0, 0, 4, False) = OrderBeforePaymentDecision.NotSupported)
        T("B05_carta_flag1", KeepStoreOrderBeforePaymentPolicy.Decide(3, 1, 4, False) = OrderBeforePaymentDecision.OrderFirst)
        T("B06_preventivo_flag0", KeepStoreOrderBeforePaymentPolicy.Decide(3, 0, 2, False) = OrderBeforePaymentDecision.OrderFirst)
        T("B07_coupon_flag0", KeepStoreOrderBeforePaymentPolicy.Decide(3, 0, 4, True) = OrderBeforePaymentDecision.OrderFirst)
        T("B08_paypal_flag0", KeepStoreOrderBeforePaymentPolicy.Decide(2, 0, 4, False) = OrderBeforePaymentDecision.PayFirstPayPal)
        ' Evaluate: lettura, confronto con la bozza, decisione
        T("B10_lettura_fallita", KeepStoreOrderBeforePaymentPolicy.Evaluate(False, Snap(3, 1), 3, 1, 4, False) = PaymentPolicyGateOutcome.Unreadable)
        T("B11_lettura_senza_riga", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Nothing, 3, 1, 4, False) = PaymentPolicyGateOutcome.Unreadable)
        T("B12_uguale_flag1", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 1), 3, 1, 4, False) = PaymentPolicyGateOutcome.Allowed)
        T("B13_flag_cambiato_a_0", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 0), 3, 1, 4, False) = PaymentPolicyGateOutcome.Changed)
        T("B14_flag_cambiato_a_1", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 1), 3, 0, 4, False) = PaymentPolicyGateOutcome.Changed)
        T("B15_online_cambiato", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(0, 1), 3, 1, 4, False) = PaymentPolicyGateOutcome.Changed)
        T("B16_carta_flag0", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 0), 3, 0, 4, False) = PaymentPolicyGateOutcome.NotAllowed)
        T("B17_offline_flag0", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(0, 0), 0, 0, 4, False) = PaymentPolicyGateOutcome.NotAllowed)
        T("B18_preventivo_flag0", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 0), 3, 0, 2, False) = PaymentPolicyGateOutcome.Allowed)
        T("B19_coupon_flag0", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(3, 0), 3, 0, 4, True) = PaymentPolicyGateOutcome.Allowed)
        T("B20_paypal_flag0_senza_tentativo", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(2, 0), 2, 0, 4, False) = PaymentPolicyGateOutcome.Changed)
        T("B21_paypal_flag1", KeepStoreOrderBeforePaymentPolicy.Evaluate(True, Snap(2, 1), 2, 1, 4, False) = PaymentPolicyGateOutcome.Allowed)
        ' Lettore: argomenti non validi = False, mai eccezioni
        Dim s As PaymentPolicySnapshot = Snap(9, 9)
        T("B30_lettore_senza_connessione", Not KeepStoreOrderBeforePaymentPolicy.TryRead(Nothing, Nothing, 1, 46, s) AndAlso s Is Nothing)
        Return sb.ToString()
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    if ($moduleText -eq '') { if (-not $Quiet) { Write-Host '  FAIL B modulo assente' }; return $false }
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    [void]$p.ReferencedAssemblies.Add('System.Data.dll')
    [void]$p.ReferencedAssemblies.Add((Join-Path $root 'Bin\MySql.Data.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Bin\MySql.Data.dll'))
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $out = [string]$c.CompiledAssembly.GetType('OrderBeforePaymentProbe').GetMethod('Run').Invoke($null, @())
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.module
if (-not ($okSource -and $okBehaviour)) { Write-Host 'ORDER_BEFORE_PAYMENT_POLICY FAIL'; exit 1 }

# --- (C) mutazioni (devono tutte fallire) ---
$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_GATE_ALSO_FOR_AUTHORIZED_PAYFIRST'; File = 'order'; Old = "If Not payFirst Then$nl                    Dim paymentPolicy As PaymentPolicySnapshot = Nothing"; New = "If True Then$nl                    Dim paymentPolicy As PaymentPolicySnapshot = Nothing" },
    @{ Id = 'M02_OUTCOME_IGNORED'; File = 'order'; Old = 'If paymentPolicyOutcome <> PaymentPolicyGateOutcome.Allowed Then'; New = 'If False Then' },
    @{ Id = 'M03_NO_EXIT_AFTER_REFUSAL'; File = 'order'; Old = "DispatchDurableCheckoutFailure(checkoutRequestId, paymentPolicyReason, `"ValidatePaymentPolicy`")$nl                        Exit Sub"; New = "DispatchDurableCheckoutFailure(checkoutRequestId, paymentPolicyReason, `"ValidatePaymentPolicy`")" },
    @{ Id = 'M04_DRAFT_FLAG_NOT_COMPARED'; File = 'order'; Old = 'paymentPolicyRead, paymentPolicy, checkoutDraft.PaymentOnline, checkoutDraft.ConfirmBeforePayment, checkoutDraft.TipoDocumentiId,'; New = 'paymentPolicyRead, paymentPolicy, checkoutDraft.PaymentOnline, paymentPolicy.ConfirmBeforePayment, checkoutDraft.TipoDocumentiId,' },
    @{ Id = 'M05_COUPON_FORCED_FALSE'; File = 'order'; Old = "checkoutDraft.TipoDocumentiId,$nl                        PayPalPayFirstPolicy.HasCoupon(Convert.ToString(Session(`"Coupon_Codice_Controllo`"), CultureInfo.InvariantCulture), GetSessionInt(`"Coupon_idArticolo`", 0)))"; New = "checkoutDraft.TipoDocumentiId,$nl                        False)" },
    @{ Id = 'M06_OTHER_COMPANY_READ'; File = 'order'; Old = 'KeepStoreOrderBeforePaymentPolicy.TryRead(conn, Nothing, orderIdentity.CompanyId, checkoutDraft.PaymentMethodId, paymentPolicy)'; New = 'KeepStoreOrderBeforePaymentPolicy.TryRead(conn, Nothing, GetSessionInt("AziendaID", 0), checkoutDraft.PaymentMethodId, paymentPolicy)' },
    @{ Id = 'M07_NOTALLOWED_AS_TRANSIENT'; File = 'order'; Old = 'If paymentPolicyOutcome = PaymentPolicyGateOutcome.NotAllowed Then paymentPolicyReason = CheckoutFailureReason.PaymentMethodNotAllowed'; New = '' },
    @{ Id = 'M08_FALSE_TEXT_BACK'; File = 'order'; Old = 'ultimoEsito = "In attesa pagamento online (preventivo o coupon)"'; New = 'ultimoEsito = "Policy bloccante configurata; enforcement non ancora attivo"' },
    @{ Id = 'M09_PAYPAL_GATE_DELEGATED'; File = 'payfirst'; Old = 'Return paymentOnline = PayPalOnlineValue AndAlso confirmBeforePayment = 0 AndAlso documentType > 0 AndAlso documentType <> QuoteDocumentType AndAlso Not hasCoupon'; New = 'Return paymentOnline = PayPalOnlineValue AndAlso confirmBeforePayment = 0 AndAlso documentType > 0 AndAlso Not hasCoupon' },
    @{ Id = 'M10_CART_READ_ERROR_OPEN'; File = 'cart'; Old = "paymentId, paymentPolicy) Then$nl            failureReason = CheckoutFailureReason.TechnicalTransient$nl            Return False$nl        End If"; New = "paymentId, paymentPolicy) Then$nl            paymentPolicy = New PaymentPolicySnapshot()$nl        End If" },
    @{ Id = 'M11_CART_SESSION_FLAG_NOT_REWRITTEN'; File = 'cart'; Old = 'Session("Ordine_ConfermaOrdinePrimaPagamento") = paymentPolicy.ConfirmBeforePayment'; New = '' },
    @{ Id = 'M12_CART_SESSION_ONLINE_NOT_REWRITTEN'; File = 'cart'; Old = 'Session("Ordine_Pagamento_OnLine") = paymentPolicy.OnLine'; New = '' },
    @{ Id = 'M13_CART_REFUSAL_REMOVED'; File = 'cart'; Old = "= OrderBeforePaymentDecision.NotSupported Then$nl            failureReason = CheckoutFailureReason.PaymentMethodNotAllowed$nl            Return False"; New = "= OrderBeforePaymentDecision.NotSupported Then$nl            failureReason = CheckoutFailureReason.PaymentMethodNotAllowed" },
    @{ Id = 'M14_CART_SWITCH_WITHOUT_REASON'; File = 'cart'; Old = "CheckoutFailureReason.PaymentMethodMissing,$nl                 CheckoutFailureReason.PaymentMethodNotAllowed"; New = 'CheckoutFailureReason.PaymentMethodMissing' },
    @{ Id = 'M15_CART_DOCTYPE_FIXED'; File = 'cart'; Old = 'paymentPolicy.ConfirmBeforePayment, tipoDocumento,'; New = 'paymentPolicy.ConfirmBeforePayment, 2,' },
    @{ Id = 'M16_MESSAGE_LOST'; File = 'recovery'; Old = 'Return "Il metodo di pagamento scelto al momento non accetta ordini dal sito.'; New = 'Return "Seleziona un metodo di pagamento.' },
    @{ Id = 'M17_READER_WITHOUT_COMPANY'; File = 'module'; Old = 'FROM pagamentitipo WHERE id=?id AND AziendeID=?aziendaId"'; New = 'FROM pagamentitipo WHERE id=?id"' },
    @{ Id = 'M18_READER_ON_VIEW'; File = 'module'; Old = 'FROM pagamentitipo WHERE id=?id AND AziendeID=?aziendaId"'; New = 'FROM vpagamentitipo WHERE id=?id AND AziendeID=?aziendaId"' }
)
$behaviourMutants = @(
    @{ Id = 'N01_CARD_FLAG0_ORDER_FIRST'; Old = 'Return OrderBeforePaymentDecision.NotSupported'; New = 'Return OrderBeforePaymentDecision.OrderFirst' },
    @{ Id = 'N02_FLAG_IGNORED'; Old = 'If confirmBeforePayment <> 0 Then Return OrderBeforePaymentDecision.OrderFirst'; New = 'If True Then Return OrderBeforePaymentDecision.OrderFirst' },
    @{ Id = 'N03_QUOTE_BLOCKED'; Old = 'documentType = QuoteDocumentType OrElse '; New = '' },
    @{ Id = 'N04_COUPON_BLOCKED'; Old = ' OrElse hasCoupon Then Return OrderBeforePaymentDecision.OrderFirst'; New = ' Then Return OrderBeforePaymentDecision.OrderFirst' },
    @{ Id = 'N05_PAYPAL_NOT_RECOGNISED'; Old = 'If paymentOnline = PayPalOnlineValue Then Return OrderBeforePaymentDecision.PayFirstPayPal'; New = '' },
    @{ Id = 'N06_ANY_ONLINE_IS_PAYPAL'; Old = 'If paymentOnline = PayPalOnlineValue Then Return OrderBeforePaymentDecision.PayFirstPayPal'; New = 'If paymentOnline <> 0 Then Return OrderBeforePaymentDecision.PayFirstPayPal' },
    @{ Id = 'N07_FLAG_NONZERO_AS_ZERO'; Old = 'If confirmBeforePayment <> 0 Then Return'; New = 'If confirmBeforePayment = 1 Then Return' },
    @{ Id = 'N08_UNREADABLE_OPEN'; Old = 'If Not readOk OrElse snapshot Is Nothing Then Return PaymentPolicyGateOutcome.Unreadable'; New = 'If Not readOk OrElse snapshot Is Nothing Then Return PaymentPolicyGateOutcome.Allowed' },
    @{ Id = 'N09_READ_FLAG_NOT_CHECKED'; Old = 'If Not readOk OrElse snapshot Is Nothing Then'; New = 'If snapshot Is Nothing Then' },
    @{ Id = 'N10_FLAG_DIVERGENCE_IGNORED'; Old = ' OrElse snapshot.ConfirmBeforePayment <> draftConfirmBeforePayment Then'; New = ' Then' },
    @{ Id = 'N11_ONLINE_DIVERGENCE_IGNORED'; Old = 'If snapshot.OnLine <> draftPaymentOnline OrElse '; New = 'If ' },
    @{ Id = 'N12_NOTALLOWED_OPEN'; Old = 'Return PaymentPolicyGateOutcome.NotAllowed'; New = 'Return PaymentPolicyGateOutcome.Allowed' },
    @{ Id = 'N13_PAYPAL_WITHOUT_ATTEMPT_OPEN'; Old = 'Return PaymentPolicyGateOutcome.Changed' + $nl + '            Case Else'; New = 'Return PaymentPolicyGateOutcome.Allowed' + $nl + '            Case Else' },
    @{ Id = 'N14_DECISION_FROM_DRAFT'; Old = 'Select Case Decide(snapshot.OnLine, snapshot.ConfirmBeforePayment, documentType, hasCoupon)'; New = 'Select Case Decide(draftPaymentOnline, 1, documentType, hasCoupon)' },
    @{ Id = 'N15_READER_SNAPSHOT_LEAK'; Old = "snapshot = Nothing$nl        If connection Is Nothing"; New = "If connection Is Nothing" }
)
$minMutants = 30
if (($mutants.Count + $behaviourMutants.Count) -lt $minMutants) { Write-Host 'ORDER_BEFORE_PAYMENT_POLICY FAIL (pochi mutanti)'; exit 1 }
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.module.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'ORDER_BEFORE_PAYMENT_POLICY FAIL (mutanti)'; exit 1 }

# ---- (D) LAB: il lettore reale sul connettore del sito ----
$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath $credFile) -and (Test-Path -LiteralPath $vbc) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $work = Join-Path $env:TEMP ('ks-orderbeforepay-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        try {
            foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll') {
                if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $work -Force }
            }
            $cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
                '<dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>' +
                '<dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>' +
                '</assemblyBinding></runtime></configuration>'
            $exe = Join-Path $work 'OrderBeforePaymentLabHarness.exe'
            [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
            $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
            $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\OrderBeforePaymentLabHarness.vb') (Join-Path $root 'App_Code\KeepStoreOrderBeforePaymentPolicy.vb') 2>&1
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { $build | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'ORDER_BEFORE_PAYMENT_POLICY FAIL (harness LAB non compila)'; exit 1 }
            $cred = Import-Clixml -LiteralPath $credFile
            $plain = $cred.GetNetworkCredential().Password
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
            $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
            $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
            $proc = [Diagnostics.Process]::Start($info)
            $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
            if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
            $plain = $null; $cred = $null
            $summary = @($stdout -split "`r?`n" | Where-Object { $_ -match '^ORDER_BEFORE_PAYMENT_LAB ' }) | Select-Object -Last 1
            if ($proc.ExitCode -ne 0 -or $summary -notmatch 'FAIL=0$') {
                @($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|ORDER_BEFORE_PAYMENT_LAB)' }) | ForEach-Object { Write-Host ('  ' + $_) }
                if ($stderr.Trim()) { Write-Host ('  stderr: ' + $stderr.Trim()) }
                Write-Host 'ORDER_BEFORE_PAYMENT_POLICY FAIL (LAB)'; exit 1
            }
            $labNote = $summary
        } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host ('ORDER_BEFORE_PAYMENT_POLICY PASS (' + ($mutants.Count + $behaviourMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
