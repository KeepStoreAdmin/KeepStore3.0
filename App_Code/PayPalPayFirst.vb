Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web

' PAYPAL-PAY-FIRST-PAGES-1A (P3a1 del progetto pay-first, docs/PAYPAL_PAY_FIRST_DESIGN.md): politica, contesto di sessione e servizio di avvio e ritorno.
' Il servizio NON usa HttpContext: riceve il contesto, la configurazione, il client e il costruttore degli URL, cosi si prova con un PayPal finto.
' Inerte finche nulla emette il contesto di sessione (lo fa ordine.aspx in P3a2) e finche il flag ConfermaOrdinePrimaPagamento resta 1.
' Regole (decisione del task): nessuna chiamata HTTP dentro il SyncLock di ordine.aspx; l'annullo di un'autorizzazione e solo da AUTHORIZED
' (RecordVoidingUnbound) e solo da qui, mai da ordine.aspx; il cancel del cliente non cambia lo stato (il tentativo resta CREATED e riapribile).

Public Enum PayFirstRoute
    StartPayment = 1
    CreateOrder = 2
    Finish = 3
    Confirmation = 4
    Busy = 5
    Manual = 6
End Enum

Public Enum PayFirstOutcome
    ApprovalRedirect = 1
    ReturnRedirect = 2
    ProceedToOrder = 3
    Finish = 4
    Confirmation = 5
    BackToCart = 6
    Busy = 7
    Manual = 8
    TechnicalError = 9
End Enum

Public NotInheritable Class PayFirstResult
    Public Property Outcome As PayFirstOutcome
    Public Property Url As String = String.Empty
    Public Property Message As String = String.Empty
    Public Property Reason As String = String.Empty
    Public Property AttemptKey As String = String.Empty
End Class

Public NotInheritable Class PayPalPayFirstPolicy
    Private Sub New()
    End Sub

    Public Const PayPalOnlineValue As Integer = 2
    Public Const QuoteDocumentType As Integer = 2
    ' La bozza e il token del checkout durano 30 minuti dal carrello: si lascia un margine e si pretende tempo per approvare e autorizzare.
    Public Const ReserveMinutes As Integer = 3
    Public Const MinutesNeededToStart As Integer = 8
    Public Const MinutesNeededToAuthorize As Integer = 2

    ' Pay-first solo per ordini web pagati con PayPal e con politica bloccante; preventivi e coupon restano sul flusso di oggi (perimetro del progetto).
    Public Shared Function Applies(ByVal paymentOnline As Integer, ByVal confirmBeforePayment As Integer, ByVal documentType As Integer, ByVal hasCoupon As Boolean) As Boolean
        Return paymentOnline = PayPalOnlineValue AndAlso confirmBeforePayment = 0 AndAlso documentType > 0 AndAlso documentType <> QuoteDocumentType AndAlso Not hasCoupon
    End Function

    ' Stesso test del codice esistente di ordine.aspx: coupon-articolo (Coupon_idArticolo > 0) o codice di controllo del coupon. Il buono sconto NON e un coupon.
    Public Shared Function HasCoupon(ByVal couponControlCode As String, ByVal couponArticleId As Integer) As Boolean
        Return Not String.IsNullOrEmpty(Convert.ToString(couponControlCode)) OrElse couponArticleId > 0
    End Function

    Public Shared Function RouteFor(ByVal attempt As PayPalAttemptRecord) As PayFirstRoute
        If attempt Is Nothing Then Return PayFirstRoute.StartPayment
        Return RouteFor(attempt.Stato, attempt.StatoPrecedente)
    End Function

    ' Instradamento unico per stato (gate di ordine.aspx, paypalpay e rientri): la bozza resta in sessione dopo il commit, quindi "indietro" o un
    ' rinfresco ricadono qui e devono trovare la strada giusta, mai un secondo pagamento.
    Public Shared Function RouteFor(ByVal state As String, ByVal previousState As String) As PayFirstRoute
        Select Case Convert.ToString(state)
            Case "", PayPalPaymentAttemptStates.Creating, PayPalPaymentAttemptStates.Created,
                 PayPalPaymentAttemptStates.Voided, PayPalPaymentAttemptStates.Failed, PayPalPaymentAttemptStates.Canceled
                Return PayFirstRoute.StartPayment
            Case PayPalPaymentAttemptStates.Authorized
                Return PayFirstRoute.CreateOrder
            Case PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.Capturing, PayPalPaymentAttemptStates.CaptureRefused
                Return PayFirstRoute.Finish
            Case PayPalPaymentAttemptStates.Completed
                Return PayFirstRoute.Confirmation
            Case PayPalPaymentAttemptStates.Voiding
                Return PayFirstRoute.Busy
            Case PayPalPaymentAttemptStates.Unknown
                Dim previous As String = Convert.ToString(previousState)
                If previous = PayPalPaymentAttemptStates.DocCommitted OrElse previous = PayPalPaymentAttemptStates.Capturing Then Return PayFirstRoute.Finish
                Return PayFirstRoute.Busy
            Case PayPalPaymentAttemptStates.CapturedOrphan
                Return PayFirstRoute.Manual
        End Select
        Return PayFirstRoute.Busy
    End Function
End Class

' Contesto per bozza (non per sessione): due schede non si sovrascrivono. Emesso da ordine.aspx dopo la validazione del token; mai da querystring.
Public NotInheritable Class PayPalPayFirstContext
    Private Const SessionPrefix As String = "KeepStore:PayFirst:Ctx:"
    Public Property DraftRequestId As String
    Public Property PayloadFingerprint As String
    Public Property CheckoutToken As String
    Public Property DatabaseScopeKey As String
    Public Property AziendeId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property PagamentiTipoId As Integer
    Public Property Amount As Decimal
    Public Property DraftExpiresUtc As DateTime
    Public Property IssuedUtc As DateTime

    Public Shared Function SessionKeyFor(ByVal requestId As String) As String
        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then Return String.Empty
        Return SessionPrefix & normalized
    End Function

    Public Shared Function Issue(ByVal session As HttpSessionStateBase, ByVal context As PayPalPayFirstContext) As Boolean
        If session Is Nothing OrElse context Is Nothing Then Return False
        Dim key As String = SessionKeyFor(context.DraftRequestId)
        If key.Length = 0 OrElse context.AziendeId <= 0 OrElse context.LoginId <= 0 OrElse context.UtentiId <= 0 OrElse context.PagamentiTipoId <= 0 OrElse
           context.Amount <= 0D OrElse String.IsNullOrWhiteSpace(context.PayloadFingerprint) OrElse String.IsNullOrWhiteSpace(context.CheckoutToken) OrElse
           String.IsNullOrWhiteSpace(context.DatabaseScopeKey) Then Return False
        context.IssuedUtc = DateTime.UtcNow
        session(key) = context
        Return True
    End Function

    ' Trovato solo per lo stesso proprietario (database, azienda, login, utente) e finche la bozza non e scaduta.
    Public Shared Function Find(ByVal session As HttpSessionStateBase, ByVal requestId As String, ByVal aziendeId As Integer,
                                ByVal loginId As Long, ByVal utentiId As Long, ByVal databaseScopeKey As String,
                                ByVal nowUtc As DateTime) As PayPalPayFirstContext
        If session Is Nothing Then Return Nothing
        Dim key As String = SessionKeyFor(requestId)
        If key.Length = 0 Then Return Nothing
        Dim found As PayPalPayFirstContext = TryCast(session(key), PayPalPayFirstContext)
        If found Is Nothing Then Return Nothing
        If found.AziendeId <> aziendeId OrElse found.LoginId <> loginId OrElse found.UtentiId <> utentiId OrElse
           Not String.Equals(found.DatabaseScopeKey, databaseScopeKey, StringComparison.Ordinal) OrElse found.DraftExpiresUtc <= nowUtc Then
            session.Remove(key)
            Return Nothing
        End If
        Return found
    End Function

    Public Shared Sub Remove(ByVal session As HttpSessionStateBase, ByVal requestId As String)
        If session Is Nothing Then Return
        Dim key As String = SessionKeyFor(requestId)
        If key.Length > 0 Then session.Remove(key)
    End Sub
End Class

Public NotInheritable Class PayPalPayFirstService
    Private Sub New()
    End Sub

    Public Const MsgNotStarted As String = "Il pagamento PayPal non e stato avviato. Il carrello e rimasto invariato: riprova tra qualche istante."
    Public Const MsgCanceled As String = "Hai annullato il pagamento PayPal. Il carrello e rimasto invariato."
    Public Const MsgExpired As String = "La sessione di pagamento e scaduta prima della conferma. Non e stato addebitato nulla: rivedi il carrello e riprova."
    Public Const MsgBusy As String = "Stiamo verificando il pagamento PayPal. Riprova tra qualche minuto senza ripetere il pagamento."
    Public Const MsgManual As String = "Il pagamento di questo ordine richiede una verifica. Contatta l'assistenza prima di riprovare."
    Public Const MsgChanged As String = "Il carrello e cambiato dopo l'autorizzazione PayPal e l'ordine non e stato creato. Rivedi il carrello e conferma di nuovo: ti verra chiesto di approvare di nuovo il pagamento. Nessun importo e stato addebitato."
    Public Const MsgResubmit As String = "Il pagamento PayPal era stato autorizzato, ma la sessione di conferma non e piu valida e l'ordine non e stato creato. Conferma di nuovo l'ordine dal carrello: ti verra chiesto di approvare di nuovo il pagamento. Nessun importo e stato addebitato."

    Private Shared Function Result(ByVal outcome As PayFirstOutcome, ByVal reason As String, Optional ByVal url As String = "", Optional ByVal message As String = "",
                                   Optional ByVal attemptKey As String = "") As PayFirstResult
        Return New PayFirstResult With {.Outcome = outcome, .Reason = SafeCode(reason), .Url = url, .Message = message, .AttemptKey = attemptKey}
    End Function

    Private Shared Function SafeCode(ByVal value As String) As String
        Return PayPalPaymentAttempts.SanitizeOutcome(value)
    End Function

    Private Shared Sub Log(ByVal text As String)
        Try
            KeepStoreLog.Info("paypal-payfirst", SafeCode(text), HttpContext.Current)
        Catch
        End Try
    End Sub

    Private Shared Function ToInfo(ByVal attempt As PayPalAttemptRecord) As PayPalAttemptInfo
        Return New PayPalAttemptInfo With {.AziendeId = attempt.AziendeId, .PagamentiTipoId = attempt.PagamentiTipoId, .AttemptId = attempt.Id, .Amount = attempt.Importo}
    End Function

    Private Shared Function ReturnPath(ByVal attemptKey As String, ByVal action As String, ByVal orderId As String) As String
        Dim path As String = "/paypalreturn.aspx?k=" & attemptKey & "&action=" & action
        If Not String.IsNullOrEmpty(orderId) Then path &= "&token=" & Uri.EscapeDataString(orderId)
        Return path
    End Function

    Private Shared Function ConfigMatches(ByVal cfg As PayPalCheckoutConfig, ByVal aziendeId As Integer, ByVal pagamentiTipoId As Integer) As Boolean
        Return cfg IsNot Nothing AndAlso cfg.IsConfigured AndAlso cfg.AziendeId = aziendeId AndAlso cfg.PagamentiTipoId = pagamentiTipoId
    End Function

    ' ----- avvio (paypalpay.aspx) -----

    Public Shared Function Start(ByVal ctx As PayPalPayFirstContext, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                 ByVal urlFor As Func(Of String, String), ByVal nowUtc As DateTime) As PayFirstResult
        If ctx Is Nothing OrElse client Is Nothing OrElse urlFor Is Nothing OrElse Not ConfigMatches(cfg, ctx.AziendeId, ctx.PagamentiTipoId) Then
            Return Result(PayFirstOutcome.TechnicalError, "START_INPUT", message:=MsgNotStarted)
        End If
        Dim request As New PayPalAttemptCreateRequest With {
            .AziendeId = ctx.AziendeId, .LoginId = ctx.LoginId, .UtentiId = ctx.UtentiId, .PagamentiTipoId = ctx.PagamentiTipoId, .PayPalAccountId = cfg.AccountId,
            .DatabaseScopeKey = ctx.DatabaseScopeKey, .DraftRequestId = ctx.DraftRequestId, .PayloadFingerprint = ctx.PayloadFingerprint,
            .DraftExpiresUtc = ctx.DraftExpiresUtc, .Importo = ctx.Amount, .Valuta = cfg.CurrencyCode, .PayeeEmail = cfg.PayeeEmail, .MerchantId = cfg.MerchantId}
        Dim hasTime As Boolean = ctx.DraftExpiresUtc.AddMinutes(-PayPalPayFirstPolicy.ReserveMinutes) - nowUtc >= TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToStart)
        For round As Integer = 1 To 2
            ' Un tentativo che prosegue verso l'ordine o l'incasso (AUTHORIZED, DOC_COMMITTED...) si instrada anche con poco tempo; aprire o riprendere
            ' un'approvazione richiede tempo, e senza tempo non si crea nemmeno la riga del tentativo.
            Dim latest As PayPalAttemptRecord = PayPalPaymentAttempts.LoadLatestForDraft(ctx.AziendeId, ctx.LoginId, ctx.DraftRequestId)
            ' Un incasso senza ordine (CAPTURED_ORPHAN) ha lo slot rilasciato: senza questo controllo si aprirebbe un SECONDO pagamento per la stessa bozza.
            If PayPalPayFirstPolicy.RouteFor(latest) = PayFirstRoute.Manual Then Return Result(PayFirstOutcome.Manual, "MANUAL_" & latest.Stato, message:=MsgManual, attemptKey:=latest.AttemptKey)
            If PayPalPayFirstPolicy.RouteFor(latest) = PayFirstRoute.StartPayment AndAlso Not hasTime Then Return Result(PayFirstOutcome.BackToCart, "DRAFT_EXPIRING", message:=MsgExpired)
            Dim created As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(request)
            If created Is Nothing OrElse created.Outcome = PayPalAttemptCreateOutcome.TechnicalError Then Return Result(PayFirstOutcome.TechnicalError, "ATTEMPT_STORE", message:=MsgNotStarted)
            If created.Outcome = PayPalAttemptCreateOutcome.Blocked Then
                Dim settled As PayFirstResult = SettleBlocked(created.Attempt, cfg, client)
                If settled IsNot Nothing Then Return settled
                Continue For
            End If
            Dim attempt As PayPalAttemptRecord = created.Attempt
            Select Case PayPalPayFirstPolicy.RouteFor(attempt)
                Case PayFirstRoute.CreateOrder
                    Return Result(PayFirstOutcome.ProceedToOrder, "AUTHORIZED", attemptKey:=attempt.AttemptKey)
                Case PayFirstRoute.Finish
                    Return Result(PayFirstOutcome.Finish, "FINISH", attemptKey:=attempt.AttemptKey)
                Case PayFirstRoute.Confirmation
                    Return Result(PayFirstOutcome.Confirmation, "COMPLETED", attemptKey:=attempt.AttemptKey)
                Case PayFirstRoute.Busy
                    Return Result(PayFirstOutcome.Busy, "BUSY_" & attempt.Stato, message:=MsgBusy, attemptKey:=attempt.AttemptKey)
                Case PayFirstRoute.Manual
                    Return Result(PayFirstOutcome.Manual, "MANUAL_" & attempt.Stato, message:=MsgManual, attemptKey:=attempt.AttemptKey)
            End Select
            If attempt.Stato = PayPalPaymentAttemptStates.Creating Then Return CreateRemote(attempt, cfg, client, urlFor)
            Return ResumeApproval(attempt, cfg, client, urlFor)
        Next
        Return Result(PayFirstOutcome.TechnicalError, "BLOCKED_UNSETTLED", message:=MsgNotStarted)
    End Function

    ' Stessa bozza con contenuto cambiato: il tentativo vecchio non si puo riusare. Prima di approvare/autorizzare lo si chiude; da AUTHORIZED si annulla
    ' l'autorizzazione (fondi liberati). Restituisce Nothing quando il tentativo e chiuso e si puo ripartire.
    Private Shared Function SettleBlocked(ByVal old As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As PayFirstResult
        If old Is Nothing Then Return Result(PayFirstOutcome.TechnicalError, "BLOCKED_NO_ATTEMPT", message:=MsgNotStarted)
        Select Case old.Stato
            Case PayPalPaymentAttemptStates.Creating, PayPalPaymentAttemptStates.Created
                If PayPalPaymentAttempts.RecordFailed(old.Id, old.AziendeId, "DRAFT_CHANGED") Then Return Nothing
                Return Result(PayFirstOutcome.Busy, "BLOCKED_RACE", message:=MsgBusy)
            Case PayPalPaymentAttemptStates.Authorized
                If VoidAuthorized(old, cfg, client) Then Return Nothing
                Return Result(PayFirstOutcome.Busy, "BLOCKED_VOID_PENDING", message:=MsgBusy, attemptKey:=old.AttemptKey)
            Case PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.Capturing, PayPalPaymentAttemptStates.CaptureRefused
                Return Result(PayFirstOutcome.Finish, "BLOCKED_HAS_DOCUMENT", attemptKey:=old.AttemptKey)
        End Select
        Return Result(PayFirstOutcome.Busy, "BLOCKED_" & old.Stato, message:=MsgBusy, attemptKey:=old.AttemptKey)
    End Function

    Private Shared Function CreateRemote(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                         ByVal urlFor As Func(Of String, String)) As PayFirstResult
        Dim info As PayPalAttemptInfo = ToInfo(attempt)
        Dim returnUrl As String = urlFor(ReturnPath(attempt.AttemptKey, "return", String.Empty))
        Dim cancelUrl As String = urlFor(ReturnPath(attempt.AttemptKey, "cancel", String.Empty))
        ' Host canonico non ricavabile: nessun ordine PayPal con URL vuoti (il tentativo resta CREATING e riprende al prossimo avvio).
        If String.IsNullOrWhiteSpace(returnUrl) OrElse String.IsNullOrWhiteSpace(cancelUrl) Then Return Result(PayFirstOutcome.TechnicalError, "HOST_INVALID", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        Dim response As PayPalOrdersV2Result = client.CreateAuthorizeOrder(info, attempt.CreateRequestId, returnUrl, cancelUrl)
        If response Is Nothing OrElse Not response.Success Then
            ' Esito incerto: il tentativo resta CREATING e il prossimo avvio ripete la STESSA richiesta (stesso PayPal-Request-Id), quindi nessun secondo ordine.
            If PayPalOrdersV2Client.IsOutcomeUncertain(response) Then Return Result(PayFirstOutcome.Busy, "CREATE_UNCERTAIN", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
            PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "CREATE_REFUSED")
            Log("create refused attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " " & PayPalOrdersV2Client.DescribeFailure(response))
            Return Result(PayFirstOutcome.BackToCart, "CREATE_REFUSED", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        End If
        Dim reason As String = PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(info, cfg, response.Snapshot.OrderId, response.Snapshot)
        If reason.Length > 0 OrElse Not PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(response.Snapshot.ApprovalUrl) Then
            PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "CREATE_INVALID")
            Log("create invalid attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & If(reason.Length > 0, reason, "APPROVAL_URL"))
            Return Result(PayFirstOutcome.TechnicalError, "CREATE_INVALID", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        End If
        If Not PayPalPaymentAttempts.RecordOrderCreated(attempt.Id, attempt.AziendeId, attempt.LoginId, response.Snapshot.OrderId) Then
            Return Result(PayFirstOutcome.Busy, "CREATE_NOT_RECORDED", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
        End If
        Return Result(PayFirstOutcome.ApprovalRedirect, "CREATED", response.Snapshot.ApprovalUrl, attemptKey:=attempt.AttemptKey)
    End Function

    ' Tentativo CREATED: lo stato vero e su PayPal. Ancora da approvare -> stesso link; approvato -> ritorno; altro -> il tentativo si chiude (nuovo al prossimo avvio).
    Private Shared Function ResumeApproval(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                           ByVal urlFor As Func(Of String, String)) As PayFirstResult
        Dim info As PayPalAttemptInfo = ToInfo(attempt)
        Dim order As PayPalOrdersV2Result = client.GetOrder(attempt.PayPalOrderId)
        If order Is Nothing OrElse Not order.Success OrElse order.Snapshot Is Nothing Then
            Return Result(PayFirstOutcome.Busy, "RESUME_GET_UNAVAILABLE", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
        End If
        If PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot).Length = 0 AndAlso
           PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(order.Snapshot.ApprovalUrl) Then
            Return Result(PayFirstOutcome.ApprovalRedirect, "RESUME_APPROVAL", order.Snapshot.ApprovalUrl, attemptKey:=attempt.AttemptKey)
        End If
        If PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot).Length = 0 Then
            Dim approvedUrl As String = urlFor(ReturnPath(attempt.AttemptKey, "return", attempt.PayPalOrderId))
            If String.IsNullOrWhiteSpace(approvedUrl) Then Return Result(PayFirstOutcome.TechnicalError, "HOST_INVALID", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
            Return Result(PayFirstOutcome.ReturnRedirect, "RESUME_APPROVED", approvedUrl, attemptKey:=attempt.AttemptKey)
        End If
        PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "RESUME_ORDER_STATE")
        Return Result(PayFirstOutcome.BackToCart, "RESUME_ORDER_STATE", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
    End Function

    ' ----- annullo di un'autorizzazione NON legata a un documento (fuori dal lock di ordine.aspx, mai da DOC_COMMITTED) -----

    Public Shared Function VoidAuthorized(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client) As Boolean
        If attempt Is Nothing OrElse client Is Nothing OrElse String.IsNullOrEmpty(attempt.PayPalAuthorizationId) Then Return False
        If Not PayPalPaymentAttempts.RecordVoidingUnbound(attempt.Id, attempt.AziendeId, "SUPERSEDED") Then
            Dim again As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId)
            If again Is Nothing OrElse again.Stato <> PayPalPaymentAttemptStates.Voiding Then Return False
        End If
        Dim voided As PayPalPaymentsResult = client.VoidAuthorization(attempt.PayPalAuthorizationId, attempt.VoidRequestId)
        If voided IsNot Nothing AndAlso voided.Success Then Return PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId)
        Dim reread As PayPalPaymentsResult = client.GetAuthorization(attempt.PayPalAuthorizationId)
        If reread IsNot Nothing AndAlso reread.Success AndAlso reread.Authorization IsNot Nothing AndAlso
           String.Equals(reread.Authorization.Status, "VOIDED", StringComparison.Ordinal) Then Return PayPalPaymentAttempts.RecordVoided(attempt.Id, attempt.AziendeId)
        PayPalPaymentAttempts.RecordUnknown(attempt.Id, attempt.AziendeId, "VOID_UNCERTAIN")
        Return False
    End Function

    ' ----- ritorno da PayPal (paypalreturn.aspx, ramo bozza) -----

    ' ctx = Nothing quando la sessione e persa o la bozza e scaduta. Un tentativo AUTHORIZED non si annulla per questo: e riusabile alla prossima conferma
    ' della stessa bozza; un tentativo solo approvato (CREATED) NON si autorizza senza contesto (nessun fondo trattenuto) e si chiude.
    Public Shared Function HandleReturn(ByVal attempt As PayPalAttemptRecord, ByVal action As String, ByVal rawToken As String, ByVal ctx As PayPalPayFirstContext,
                                        ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client, ByVal urlFor As Func(Of String, String),
                                        ByVal nowUtc As DateTime) As PayFirstResult
        If attempt Is Nothing OrElse client Is Nothing OrElse urlFor Is Nothing OrElse Not ConfigMatches(cfg, attempt.AziendeId, attempt.PagamentiTipoId) Then
            Return Result(PayFirstOutcome.TechnicalError, "RETURN_INPUT", message:=MsgNotStarted)
        End If
        Dim route As PayFirstRoute = PayPalPayFirstPolicy.RouteFor(attempt)
        Dim isCancel As Boolean = String.Equals(action, "cancel", StringComparison.OrdinalIgnoreCase)
        If Not isCancel AndAlso Not String.Equals(action, "return", StringComparison.OrdinalIgnoreCase) Then Return Result(PayFirstOutcome.TechnicalError, "RETURN_ACTION", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        If String.IsNullOrEmpty(attempt.PayPalOrderId) OrElse Not PayPalOrdersV2Client.IsReturnOrderTokenValid(rawToken, attempt.PayPalOrderId) Then
            Return Result(PayFirstOutcome.TechnicalError, "RETURN_TOKEN", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        End If
        If isCancel Then Return Result(PayFirstOutcome.BackToCart, "CUSTOMER_CANCELED", message:=MsgCanceled, attemptKey:=attempt.AttemptKey)
        Select Case route
            Case PayFirstRoute.CreateOrder
                If ctx Is Nothing Then Return Result(PayFirstOutcome.BackToCart, "AUTHORIZED_NO_CONTEXT", message:=MsgResubmit, attemptKey:=attempt.AttemptKey)
                Return Result(PayFirstOutcome.ProceedToOrder, "AUTHORIZED", attemptKey:=attempt.AttemptKey)
            Case PayFirstRoute.Finish
                Return Result(PayFirstOutcome.Finish, "FINISH", attemptKey:=attempt.AttemptKey)
            Case PayFirstRoute.Confirmation
                Return Result(PayFirstOutcome.Confirmation, "COMPLETED", attemptKey:=attempt.AttemptKey)
            Case PayFirstRoute.Busy
                Return Result(PayFirstOutcome.Busy, "BUSY_" & attempt.Stato, message:=MsgBusy, attemptKey:=attempt.AttemptKey)
            Case PayFirstRoute.Manual
                Return Result(PayFirstOutcome.Manual, "MANUAL_" & attempt.Stato, message:=MsgManual, attemptKey:=attempt.AttemptKey)
        End Select
        If attempt.Stato <> PayPalPaymentAttemptStates.Created Then Return Result(PayFirstOutcome.BackToCart, "RETURN_STATE_" & attempt.Stato, message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        If ctx Is Nothing OrElse ctx.DraftExpiresUtc.AddMinutes(-PayPalPayFirstPolicy.ReserveMinutes) - nowUtc < TimeSpan.FromMinutes(PayPalPayFirstPolicy.MinutesNeededToAuthorize) Then
            PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "RETURN_CONTEXT_EXPIRED")
            Return Result(PayFirstOutcome.BackToCart, "RETURN_CONTEXT_EXPIRED", message:=MsgExpired, attemptKey:=attempt.AttemptKey)
        End If
        Return AuthorizeApproved(attempt, cfg, client, urlFor, nowUtc)
    End Function

    Private Shared Function AuthorizeApproved(ByVal attempt As PayPalAttemptRecord, ByVal cfg As PayPalCheckoutConfig, ByVal client As PayPalOrdersV2Client,
                                              ByVal urlFor As Func(Of String, String), ByVal nowUtc As DateTime) As PayFirstResult
        Dim info As PayPalAttemptInfo = ToInfo(attempt)
        Dim order As PayPalOrdersV2Result = client.GetOrder(attempt.PayPalOrderId)
        If order Is Nothing OrElse Not order.Success OrElse order.Snapshot Is Nothing Then
            Return Result(PayFirstOutcome.Busy, "RETURN_GET_UNAVAILABLE", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
        End If
        ' Il cliente e tornato senza approvare: lo si rimanda sullo stesso ordine PayPal.
        If PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot).Length = 0 AndAlso
           PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl(order.Snapshot.ApprovalUrl) Then
            Return Result(PayFirstOutcome.ApprovalRedirect, "RETURN_NOT_APPROVED", order.Snapshot.ApprovalUrl, attemptKey:=attempt.AttemptKey)
        End If
        Dim reason As String = PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot)
        If reason.Length > 0 Then
            Log("return check failed attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & reason)
            Return Result(PayFirstOutcome.TechnicalError, "RETURN_ORDER_" & reason, message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        End If
        ' APPROVED = da autorizzare; COMPLETED con un'autorizzazione = gia autorizzato (ritorno ripetuto o processo interrotto): nessuna seconda authorize.
        If String.Equals(order.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then
            Dim authorized As PayPalOrdersV2Result = client.AuthorizeOrder(attempt.PayPalOrderId, attempt.AuthorizeRequestId)
            Dim authorizeReason As String = String.Empty
            If authorized Is Nothing OrElse Not authorized.Success Then
                If Not PayPalOrdersV2Client.IsOutcomeUncertain(authorized) Then
                    PayPalPaymentAttempts.RecordFailed(attempt.Id, attempt.AziendeId, "AUTHORIZE_REFUSED")
                    Log("authorize refused attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " " & PayPalOrdersV2Client.DescribeFailure(authorized))
                    Return Result(PayFirstOutcome.BackToCart, "AUTHORIZE_REFUSED", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
                End If
            Else
                authorizeReason = PayPalOrdersV2Client.CheckAuthorizeResponse(info, cfg, attempt.PayPalOrderId, authorized.Snapshot)
                If authorizeReason.Length > 0 Then Log("authorize response check attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " reason=" & authorizeReason)
            End If
            ' L'id dell'autorizzazione si legge SOLO dal GET dell'ordine validato (non dalla risposta di authorize). Se il GET non conferma, il tentativo resta
            ' CREATED: il ritorno e idempotente (GET, poi authorize con lo STESSO PayPal-Request-Id), quindi un rinfresco riprende senza un secondo effetto.
            order = client.GetOrder(attempt.PayPalOrderId)
            If order Is Nothing OrElse Not order.Success OrElse order.Snapshot Is Nothing Then
                Return Result(PayFirstOutcome.Busy, "AUTHORIZE_UNVERIFIED", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
            End If
            reason = PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(info, cfg, attempt.PayPalOrderId, order.Snapshot)
            If reason.Length > 0 OrElse Not String.Equals(order.Snapshot.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then
                Return Result(PayFirstOutcome.Busy, "AUTHORIZE_UNVERIFIED", message:=MsgBusy, attemptKey:=attempt.AttemptKey)
            End If
        End If
        Dim authorization As PayPalAuthorizationSnapshot = order.Snapshot.Authorization
        If authorization Is Nothing OrElse Not PayPalOrdersV2Client.IsAuthorizationCapturable(authorization, nowUtc) Then
            Log("authorization not capturable attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture))
            Return Result(PayFirstOutcome.TechnicalError, "AUTHORIZATION_NOT_CAPTURABLE", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
        End If
        Dim expires As DateTime = nowUtc.AddDays(3)
        Dim parsed As DateTime
        If Not String.IsNullOrEmpty(authorization.ExpirationTime) AndAlso DateTime.TryParse(authorization.ExpirationTime, CultureInfo.InvariantCulture,
               DateTimeStyles.AdjustToUniversal Or DateTimeStyles.AssumeUniversal, parsed) Then expires = parsed
        If PayPalPaymentAttempts.RecordAuthorized(attempt.Id, attempt.AziendeId, attempt.LoginId, attempt.PayPalOrderId, authorization.Id, expires) Then
            Return Result(PayFirstOutcome.ProceedToOrder, "AUTHORIZED", attemptKey:=attempt.AttemptKey)
        End If
        ' Corsa residua: l'autorizzazione c'e su PayPal ma il tentativo non e piu CREATED. Se un altro processo l'ha registrata e tutto a posto; altrimenti
        ' l'autorizzazione e orfana: annullo diretto (best effort, fuori dalla macchina a stati) e riga di registro distinta.
        Dim reloaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(attempt.AttemptKey, attempt.AziendeId, attempt.LoginId)
        If reloaded IsNot Nothing AndAlso reloaded.Stato = PayPalPaymentAttemptStates.Authorized AndAlso String.Equals(reloaded.PayPalAuthorizationId, authorization.Id, StringComparison.Ordinal) Then
            Return Result(PayFirstOutcome.ProceedToOrder, "AUTHORIZED", attemptKey:=attempt.AttemptKey)
        End If
        If reloaded IsNot Nothing AndAlso reloaded.DocumentiId > 0 Then Return Result(PayFirstOutcome.Finish, "FINISH", attemptKey:=attempt.AttemptKey)
        Log("ORPHAN_AUTHORIZATION attempt=" & attempt.Id.ToString(CultureInfo.InvariantCulture) & " authorization=" & PayPalPaymentState.SanitizeExternalId(authorization.Id))
        client.VoidAuthorization(authorization.Id, attempt.VoidRequestId)
        Return Result(PayFirstOutcome.TechnicalError, "ORPHAN_AUTHORIZATION", message:=MsgNotStarted, attemptKey:=attempt.AttemptKey)
    End Function
End Class

' Token del ramo pf (ripresa dell'incasso): MachineKey, scopo dedicato, tentativo + database + azienda + login + ora. Il payload e puro e si prova senza ASP.NET.
Public NotInheritable Class PayPalPayFirstToken
    Private Sub New()
    End Sub

    Private Const Purpose As String = "KeepStore.PayFirst.Finish.V1"
    Public Const QueryKey As String = "pf"
    Public Shared ReadOnly MaxAge As TimeSpan = TimeSpan.FromMinutes(30)
    Private Shared ReadOnly KeyPattern As New System.Text.RegularExpressions.Regex("^[0-9a-f]{32}$", System.Text.RegularExpressions.RegexOptions.CultureInvariant)

    Public Shared Function BuildPayload(ByVal attemptKey As String, ByVal identity As OrderStorefrontIdentity, ByVal nowUtc As DateTime) As String
        Dim scope As String = String.Empty
        If identity Is Nothing OrElse Not identity.IsComplete OrElse String.IsNullOrEmpty(attemptKey) OrElse Not KeyPattern.IsMatch(attemptKey) OrElse
           Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(identity.DatabaseScopeKey, scope) Then Return String.Empty
        Return "v1|" & attemptKey & "|" & scope & "|" & identity.CompanyId.ToString(CultureInfo.InvariantCulture) & "|" & identity.LoginId.ToString(CultureInfo.InvariantCulture) & "|" &
               nowUtc.Ticks.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function TryParsePayload(ByVal payload As String, ByVal identity As OrderStorefrontIdentity, ByVal nowUtc As DateTime, ByRef attemptKey As String) As Boolean
        attemptKey = String.Empty
        If identity Is Nothing OrElse Not identity.IsComplete OrElse String.IsNullOrEmpty(payload) Then Return False
        Dim parts() As String = payload.Split("|"c)
        If parts.Length <> 6 OrElse Not String.Equals(parts(0), "v1", StringComparison.Ordinal) OrElse Not KeyPattern.IsMatch(parts(1)) Then Return False
        Dim scope As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(parts(2), scope) OrElse Not String.Equals(scope, identity.DatabaseScopeKey, StringComparison.Ordinal) Then Return False
        Dim company As Integer
        Dim login As Long
        Dim ticks As Long
        If Not Integer.TryParse(parts(3), NumberStyles.None, CultureInfo.InvariantCulture, company) OrElse company <> identity.CompanyId Then Return False
        If Not Long.TryParse(parts(4), NumberStyles.None, CultureInfo.InvariantCulture, login) OrElse login <> identity.LoginId Then Return False
        If Not Long.TryParse(parts(5), NumberStyles.None, CultureInfo.InvariantCulture, ticks) Then Return False
        Dim age As TimeSpan = nowUtc.Subtract(New DateTime(ticks, DateTimeKind.Utc))
        If age < TimeSpan.FromMinutes(-1) OrElse age > MaxAge Then Return False
        attemptKey = parts(1)
        Return True
    End Function

    Public Shared Function Create(ByVal attemptKey As String, ByVal identity As OrderStorefrontIdentity) As String
        Dim payload As String = BuildPayload(attemptKey, identity, DateTime.UtcNow)
        If payload.Length = 0 Then Throw New InvalidOperationException("Pay-first finish token is not valid.")
        Dim clearBytes() As Byte = Nothing
        Dim protectedBytes() As Byte = Nothing
        Try
            clearBytes = System.Text.Encoding.UTF8.GetBytes(payload)
            protectedBytes = System.Web.Security.MachineKey.Protect(clearBytes, Purpose)
            If protectedBytes Is Nothing OrElse protectedBytes.Length = 0 Then Throw New InvalidOperationException("Pay-first finish token protection failed.")
            Return Convert.ToBase64String(protectedBytes).Replace("+"c, "-"c).Replace("/"c, "_"c).TrimEnd("="c)
        Finally
            If clearBytes IsNot Nothing Then Array.Clear(clearBytes, 0, clearBytes.Length)
            If protectedBytes IsNot Nothing Then Array.Clear(protectedBytes, 0, protectedBytes.Length)
        End Try
    End Function

    Public Shared Function TryValidate(ByVal token As String, ByVal identity As OrderStorefrontIdentity, ByRef attemptKey As String) As Boolean
        attemptKey = String.Empty
        If String.IsNullOrWhiteSpace(token) OrElse token.Length > 1024 Then Return False
        Dim protectedBytes() As Byte = Nothing
        Dim clearBytes() As Byte = Nothing
        Try
            Dim encoded As String = token.Trim().Replace("-"c, "+"c).Replace("_"c, "/"c)
            Select Case encoded.Length Mod 4
                Case 0
                Case 2
                    encoded &= "=="
                Case 3
                    encoded &= "="
                Case Else
                    Return False
            End Select
            protectedBytes = Convert.FromBase64String(encoded)
            clearBytes = System.Web.Security.MachineKey.Unprotect(protectedBytes, Purpose)
            If clearBytes Is Nothing OrElse clearBytes.Length = 0 Then Return False
            Return TryParsePayload(System.Text.Encoding.UTF8.GetString(clearBytes), identity, DateTime.UtcNow, attemptKey)
        Catch
            attemptKey = String.Empty
            Return False
        Finally
            If protectedBytes IsNot Nothing Then Array.Clear(protectedBytes, 0, protectedBytes.Length)
            If clearBytes IsNot Nothing Then Array.Clear(clearBytes, 0, clearBytes.Length)
        End Try
    End Function
End Class
' Colla delle pagine (paypalpay.aspx, paypalreturn.aspx): proprietario, messaggio nel carrello, redirect e URL canonici. Nessuna regola di business qui.
Public NotInheritable Class PayPalPayFirstGlue
    Private Sub New()
    End Sub

    Public Shared Function ResolveOwner(ByVal context As HttpContext) As OrderStorefrontIdentity
        If context Is Nothing OrElse context.Session Is Nothing Then Return Nothing
        Dim loginId As Integer = PayPalPaymentState.GetSessionInt("LoginId", 0)
        Dim utentiId As Integer = PayPalPaymentState.GetSessionInt("UtentiId", 0)
        If loginId <= 0 OrElse utentiId <= 0 Then Return Nothing
        Dim owner As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(context)
        If owner Is Nothing OrElse Not owner.IsComplete OrElse owner.LoginId <> loginId OrElse owner.UtentiId <> utentiId Then Return Nothing
        Return owner
    End Function

    Public Shared Function UrlBuilder(ByVal context As HttpContext) As Func(Of String, String)
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        Return Function(path As String) StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, path)
    End Function

    Public Shared Sub Redirect(ByVal context As HttpContext, ByVal url As String)
        context.Response.Redirect(url, False)
        context.ApplicationInstance.CompleteRequest()
    End Sub

    ' Stesso meccanismo di ordine.aspx (ReturnToCartWithReviewMessage): messaggio in sessione e 303 verso il carrello.
    Public Shared Sub ReturnToCart(ByVal context As HttpContext, ByVal message As String)
        context.Session(CartPriceRevalidationHelper.SessionMessageKey) = If(String.IsNullOrWhiteSpace(message), PayPalPayFirstService.MsgNotStarted, message.Trim())
        context.Session(CartPriceRevalidationHelper.SessionChangedKey) = 1
        CheckoutTerminalOutcomeDispatcher.Dispatch(context, CheckoutTerminalOutcome.CartReview)
    End Sub

    Public Shared Sub Apply(ByVal context As HttpContext, ByVal result As PayFirstResult, ByVal payCtx As PayPalPayFirstContext, ByVal owner As OrderStorefrontIdentity)
        If result Is Nothing Then ReturnToCart(context, PayPalPayFirstService.MsgNotStarted) : Return
        Select Case result.Outcome
            Case PayFirstOutcome.ApprovalRedirect, PayFirstOutcome.ReturnRedirect
                Redirect(context, result.Url)
            Case PayFirstOutcome.ProceedToOrder
                If payCtx Is Nothing Then ReturnToCart(context, PayPalPayFirstService.MsgResubmit) : Return
                Redirect(context, VirtualPathUtility.ToAbsolute("~/ordine.aspx") & "?t=" & HttpUtility.UrlEncode(payCtx.CheckoutToken))
            Case PayFirstOutcome.Finish, PayFirstOutcome.Confirmation
                ' Un tentativo con l'ordine gia creato o completato: si riprende l'incasso (ramo pf di ordine.aspx), mai un nuovo pagamento.
                If owner Is Nothing OrElse String.IsNullOrEmpty(result.AttemptKey) Then ReturnToCart(context, PayPalPayFirstService.MsgBusy) : Return
                Redirect(context, VirtualPathUtility.ToAbsolute("~/ordine.aspx") & "?" & PayPalPayFirstToken.QueryKey & "=" & HttpUtility.UrlEncode(PayPalPayFirstToken.Create(result.AttemptKey, owner)))
            Case Else
                ReturnToCart(context, If(String.IsNullOrEmpty(result.Message), PayPalPayFirstService.MsgBusy, result.Message))
        End Select
    End Sub

    Public Shared Sub RunStart(ByVal context As HttpContext, ByVal requestId As String)
        Dim owner As OrderStorefrontIdentity = ResolveOwner(context)
        If owner Is Nothing Then Redirect(context, "login.aspx") : Return
        Dim payCtx As PayPalPayFirstContext = PayPalPayFirstContext.Find(New HttpSessionStateWrapper(context.Session), requestId, owner.CompanyId, owner.LoginId,
                                                                          owner.UtentiId, owner.DatabaseScopeKey, DateTime.UtcNow)
        If payCtx Is Nothing Then ReturnToCart(context, PayPalPayFirstService.MsgExpired) : Return
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForCompanyPayment(owner.CompanyId, payCtx.PagamentiTipoId)
        If cfg Is Nothing OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(context, cfg) Then
            PayPalPaymentState.LogCheckoutFailure("paypal-payfirst", 0, "Configurazione PayPal Checkout non disponibile")
            ReturnToCart(context, PayPalPayFirstService.MsgNotStarted)
            Return
        End If
        ' Autorizzazioni abbandonate dello stesso cliente (bozze scadute, mai arrivate all'ordine): si liberano i fondi. Best effort: non blocca mai il pagamento.
        Try
            PayPalPayFirstRecovery.SweepOwner(owner.CompanyId, owner.LoginId, payCtx.DraftRequestId, cfg, New PayPalOrdersV2Client(cfg), DateTime.UtcNow)
        Catch ex As Exception
            PayPalPaymentState.LogCheckoutFailure("paypal-payfirst", 0, "Pulizia delle autorizzazioni abbandonate non riuscita")
        End Try
        Apply(context, PayPalPayFirstService.Start(payCtx, cfg, New PayPalOrdersV2Client(cfg), UrlBuilder(context), DateTime.UtcNow), payCtx, owner)
    End Sub

    Public Shared Sub RunReturn(ByVal context As HttpContext, ByVal attemptKey As String, ByVal action As String, ByVal rawToken As String)
        Dim owner As OrderStorefrontIdentity = ResolveOwner(context)
        If owner Is Nothing Then Redirect(context, "login.aspx") : Return
        Dim attempt As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(attemptKey, owner.CompanyId, owner.LoginId)
        If attempt Is Nothing OrElse attempt.UtentiId <> owner.UtentiId Then Redirect(context, "accessonegato.aspx") : Return
        Dim payCtx As PayPalPayFirstContext = PayPalPayFirstContext.Find(New HttpSessionStateWrapper(context.Session), attempt.DraftRequestId, owner.CompanyId, owner.LoginId,
                                                                          owner.UtentiId, owner.DatabaseScopeKey, DateTime.UtcNow)
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForCompanyPayment(attempt.AziendeId, attempt.PagamentiTipoId)
        If cfg Is Nothing OrElse cfg.AccountId <> attempt.PayPalAccountId OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(context, cfg) Then
            PayPalPaymentState.LogCheckoutFailure("paypal-payfirst", 0, "Configurazione PayPal Checkout non disponibile")
            ReturnToCart(context, PayPalPayFirstService.MsgNotStarted)
            Return
        End If
        Apply(context, PayPalPayFirstService.HandleReturn(attempt, action, rawToken, payCtx, cfg, New PayPalOrdersV2Client(cfg), UrlBuilder(context), DateTime.UtcNow), payCtx, owner)
    End Sub
End Class
