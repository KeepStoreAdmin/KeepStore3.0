#If PAYPAL_WEBHOOK_RUNNER Then
Option Strict On
Option Explicit On

Imports System

Public Module WebhookFlowRunner
    Public Sub Main(ByVal arguments As String())
        If arguments Is Nothing OrElse arguments.Length <> 1 Then Throw New InvalidOperationException("WEBHOOK_APP_PATH_REQUIRED")
        Dim report As String = WebhookFlowBootstrap.Run(arguments(0))
        Console.WriteLine(report)
        If Not report.Contains("WEBHOOK_FLOW_FAILED_COUNT=0") Then Environment.ExitCode = 1
    End Sub
End Module
#Else
Option Strict On
Option Explicit On

' Compiled only by Test-PayPalWebhookFlow.ps1 into a disposable ASP.NET app.
' The page, repository, policy, PayPal client and payment state are the real
' production sources; this file supplies only the isolated host and boundaries.
Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Threading
Imports System.Threading.Tasks
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient

Public NotInheritable Class OrderStorefrontIdentity
    Public Property CompanyId As Integer
    Public Property UtentiId As Integer
    Public Property LoginId As Integer
    Public ReadOnly Property IsComplete As Boolean
        Get
            Return CompanyId > 0 AndAlso UtentiId > 0
        End Get
    End Property
End Class

Public NotInheritable Class OrderStorefrontContext
    Public Shared Function Resolve(ByVal context As HttpContext) As OrderStorefrontIdentity
        ' Isolated session fixture for the actual paypalreturn.aspx.vb path.
        If context Is Nothing OrElse context.Session Is Nothing Then Return Nothing
        Dim userId As Integer = PayPalPaymentState.GetSessionInt("UtentiId")
        Dim loginId As Integer = PayPalPaymentState.GetSessionInt("LoginId")
        If userId <= 0 OrElse loginId <= 0 Then Return Nothing
        Return New OrderStorefrontIdentity With {
            .CompanyId = If(context.Request.Url.Host = "store-b.invalid", 2, 1),
            .UtentiId = userId, .LoginId = loginId}
    End Function
End Class

Public NotInheritable Class PayPalWebLaunchContext
    Public Shared Sub FinishPayPal(ByVal context As HttpContext, ByVal documentId As Integer,
                                   ByVal owner As OrderStorefrontIdentity)
        ' Launch-token cleanup is unrelated to webhook/return capture arbitration.
    End Sub
End Class

Public NotInheritable Class KeepStoreLog
    Public Shared Sub [Error](ByVal category As String, ByVal operation As String,
                              ByVal failure As Exception, ByVal context As HttpContext)
        ' Never persist lab payloads, identities or connection details.
        WebhookFlowHost.LastLogCategory = category
        WebhookFlowHost.LastLogException = If(failure Is Nothing, String.Empty, failure.GetType().Name)
    End Sub
End Class

Public NotInheritable Class WebhookFlowBootstrap
    Public Shared Function Run(ByVal appPath As String) As String
        Dim host As WebhookFlowHost = CType(ApplicationHost.CreateApplicationHost(GetType(WebhookFlowHost),
                                                                                  "/", appPath), WebhookFlowHost)
        Return host.Run()
    End Function
End Class

Public Class WebhookFlowHost
    Inherits MarshalByRefObject

    Friend Shared LastLogCategory As String = String.Empty
    Friend Shared LastLogException As String = String.Empty
    Private ReadOnly _lines As New List(Of String)()
    Private _failures As Integer
    Private _concurrentRawCaptureCalls As Integer
    Private ReadOnly _serializer As New JavaScriptSerializer()
    Private ReadOnly _connection As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

    Public Overrides Function InitializeLifetimeService() As Object
        Return Nothing
    End Function

    Public Function Run() As String
        VerifyIsolatedDatabase()
        PayPalOrdersV2Client.WebhookHarnessTransportFactory = Function() New WebhookFakeTransport()
        CreateLabDatabase()
        Try
            CreateSchemaAndFixtures()
            CheckInvariant("sanitize_capture_id_nothing", PayPalPaymentState.SanitizeExternalId(Nothing) = String.Empty)
            CheckInvariant("sanitize_capture_id_empty", PayPalPaymentState.SanitizeExternalId(String.Empty) = String.Empty)
            CheckInvariant("sanitize_capture_id_whitespace", PayPalPaymentState.SanitizeExternalId("  " & vbTab) = String.Empty)
            CheckInvariant("sanitize_capture_id_valid", PayPalPaymentState.SanitizeExternalId(" CAPTURE-LAB_1001 ") = "CAPTURE-LAB_1001")
            Dim found As WebhookReply = Post(CaptureEvent("EVENT-LAB-FOUND", 1001, "COMPLETED"))
            Check("complete_fixture_handler", found.Status = 200 AndAlso State(1001).Paid = 1 AndAlso
                  State(1001).TransactionState = "COMPLETED" AndAlso State(1001).Events = 1, found)
            Dim duplicate As WebhookReply = Post(CaptureEvent("EVENT-LAB-FOUND", 1001, "COMPLETED"))
            Check("capture_duplicate", duplicate.Status = 200 AndAlso State(1001).Events = 1 AndAlso State(1001).Paid = 1, duplicate)

            InsertFixture(1003, 1)
            Dim retryEvent As String = CaptureEvent("EVENT-LAB-RETRY", 1003, "COMPLETED")
            Dim fakeBefore As Integer = WebhookFakeTransport.TotalCalls
            Execute("RENAME TABLE paypal_checkout_transazioni TO paypal_checkout_transazioni_hold")
            Dim unavailable As WebhookReply
            Try
                unavailable = Post(retryEvent)
            Finally
                Execute("RENAME TABLE paypal_checkout_transazioni_hold TO paypal_checkout_transazioni")
            End Try
            Check("lookup_failure_503_pretransport", unavailable.Status = 503 AndAlso
                  WebhookFakeTransport.TotalCalls = fakeBefore AndAlso State(1003).Events = 0 AndAlso State(1003).Paid = 0,
                  unavailable)
            Dim recovered As WebhookReply = Post(retryEvent)
            Check("same_event_recovery", recovered.Status = 200 AndAlso State(1003).Events = 1 AndAlso State(1003).Paid = 1,
                  recovered)
            Dim recoveredDuplicate As WebhookReply = Post(retryEvent)
            Check("same_event_recovery_duplicate", recoveredDuplicate.Status = 200 AndAlso State(1003).Events = 1 AndAlso State(1003).Paid = 1,
                  recoveredDuplicate)

            Dim missing As WebhookReply = Post(CaptureEvent("EVENT-LAB-UNKNOWN", 9999, "COMPLETED"))
            Check("true_not_found_202", missing.Status = 202 AndAlso State(9999).Events = 0, missing)

            InsertFixture(1004, 1)
            Execute("ALTER TABLE paypal_checkout_transazioni MODIFY Importo varchar(30) NOT NULL")
            Execute("UPDATE paypal_checkout_transazioni SET Importo='BROKEN' WHERE DocumentiId=1004")
            fakeBefore = WebhookFakeTransport.TotalCalls
            Dim mappingFailure As WebhookReply
            Try
                mappingFailure = Post(CaptureEvent("EVENT-LAB-MAPPING", 1004, "COMPLETED"))
            Finally
                Execute("UPDATE paypal_checkout_transazioni SET Importo='12.34' WHERE DocumentiId=1004")
                Execute("ALTER TABLE paypal_checkout_transazioni MODIFY Importo decimal(15,2) NOT NULL")
            End Try
            Check("partial_mapping_503", mappingFailure.Status = 503 AndAlso State(1004).Events = 0 AndAlso
                  State(1004).Paid = 0 AndAlso WebhookFakeTransport.TotalCalls = fakeBefore, mappingFailure)

            InsertFixture(1005, 1)
            Dim approved As WebhookReply = Post(ApprovedEvent("EVENT-LAB-APPROVED", 1005))
            Check("approved_without_browser_return", approved.Status = 200 AndAlso State(1005).Paid = 1 AndAlso
                  State(1005).Events = 1 AndAlso WebhookFakeTransport.LastCaptureRequestId = "CAPTURE-LAB-1005", approved)
            Dim priorCaptures As Integer = WebhookFakeTransport.CaptureCalls
            Dim approvedReplay As WebhookReply = Post(ApprovedEvent("EVENT-LAB-APPROVED", 1005))
            Check("approved_replay_no_second_capture", approvedReplay.Status = 200 AndAlso State(1005).Events = 1 AndAlso
                  State(1005).Paid = 1 AndAlso WebhookFakeTransport.CaptureCalls = priorCaptures, approvedReplay)

            InsertFixture(1006, 1)
            Dim pending As WebhookReply = Post(CaptureEvent("EVENT-LAB-PENDING", 1006, "PENDING"))
            Check("capture_pending", pending.Status = 200 AndAlso State(1006).TransactionState = "PENDING" AndAlso
                  State(1006).Paid = 0 AndAlso State(1006).Events = 1, pending)
            Dim laterCompleted As WebhookReply = Post(CaptureEvent("EVENT-LAB-COMPLETE-LATER", 1006, "COMPLETED"))
            Check("pending_then_completed", laterCompleted.Status = 200 AndAlso State(1006).TransactionState = "COMPLETED" AndAlso
                  State(1006).Paid = 1 AndAlso State(1006).Events = 2, laterCompleted)
            Dim lateDenied As WebhookReply = Post(CaptureEvent("EVENT-LAB-LATE-DENIED", 1006, "DENIED"))
            Check("late_denied_monotonic", lateDenied.Status = 200 AndAlso State(1006).TransactionState = "COMPLETED" AndAlso
                  State(1006).Paid = 1 AndAlso State(1006).Events = 2, lateDenied)
            Dim paidBeforeReversal As WebhookLabState = State(1006)
            Dim captureBeforeReversal As String = PayPalCheckoutRepository.LoadTransactionForDocument(1006).PayPalCaptureId
            priorCaptures = WebhookFakeTransport.CaptureCalls
            Dim lateReversed As WebhookReply = Post(ReversedEvent("EVENT-LAB-LATE-REVERSED", 1006))
            Dim paidAfterReversal As WebhookLabState = State(1006)
            Check("late_reversal_preserves_completed", lateReversed.Status = 200 AndAlso
                  paidBeforeReversal.Paid = 1 AndAlso paidBeforeReversal.PaymentState = 2 AndAlso
                  paidBeforeReversal.DocumentMarker = PayPalPaymentState.BuildCaptureMarker("CAPTURE-LAB-1006") AndAlso
                  captureBeforeReversal = "CAPTURE-LAB-1006" AndAlso
                  paidAfterReversal.Paid = paidBeforeReversal.Paid AndAlso
                  paidAfterReversal.PaymentState = paidBeforeReversal.PaymentState AndAlso
                  paidAfterReversal.DocumentMarker = paidBeforeReversal.DocumentMarker AndAlso
                  paidAfterReversal.TransactionState = "COMPLETED" AndAlso paidAfterReversal.Events = 2 AndAlso
                  PayPalCheckoutRepository.LoadTransactionForDocument(1006).PayPalCaptureId = captureBeforeReversal AndAlso
                  WebhookFakeTransport.CaptureCalls = priorCaptures, lateReversed)

            InsertFixture(1007, 1)
            Dim denied As WebhookReply = Post(CaptureEvent("EVENT-LAB-DENIED", 1007, "DENIED"))
            Check("capture_denied", denied.Status = 200 AndAlso State(1007).TransactionState = "DENIED" AndAlso
                  State(1007).Paid = 0 AndAlso State(1007).Events = 1, denied)
            InsertFixture(1008, 1)
            priorCaptures = WebhookFakeTransport.CaptureCalls
            Dim reversed As WebhookReply = Post(ReversedEvent("EVENT-LAB-REVERSED", 1008))
            Dim reversedState As WebhookLabState = State(1008)
            Check("approval_reversed_without_capture_id", reversed.Status = 200 AndAlso
                  reversedState.TransactionState = "FAILED" AndAlso reversedState.Paid = 0 AndAlso
                  reversedState.PaymentState = 3 AndAlso reversedState.Events = 1 AndAlso
                  reversedState.DocumentMarker = PayPalPaymentState.BuildOrderMarker("ORDER-LAB-1008") AndAlso
                  EventCaptureIdIsNull("EVENT-LAB-REVERSED") AndAlso TransactionCaptureIdIsNull(1008) AndAlso
                  ReversalFixtureRowsUnchanged(1008) AndAlso
                  WebhookFakeTransport.CaptureCalls = priorCaptures, reversed)
            Dim reversedDuplicate As WebhookReply = Post(ReversedEvent("EVENT-LAB-REVERSED", 1008))
            Check("approval_reversed_duplicate_idempotent", reversedDuplicate.Status = 200 AndAlso
                  State(1008).Events = 1 AndAlso State(1008).TransactionState = "FAILED" AndAlso
                  State(1008).Paid = 0 AndAlso WebhookFakeTransport.CaptureCalls = priorCaptures,
                  reversedDuplicate)

            InsertFixture(1023, 1)
            Dim withoutCapture As IDictionary(Of String, Object) =
                CType(_serializer.DeserializeObject(CaptureEvent("EVENT-LAB-MISSING-CAPTURE-ID", 1023, "COMPLETED")), IDictionary(Of String, Object))
            CType(withoutCapture("resource"), IDictionary(Of String, Object)).Remove("id")
            priorCaptures = WebhookFakeTransport.CaptureCalls
            Dim missingCaptureId As WebhookReply = Post(_serializer.Serialize(withoutCapture))
            Check("completed_without_capture_id_rejected", missingCaptureId.Status = 409 AndAlso
                  State(1023).Paid = 0 AndAlso State(1023).Events = 0 AndAlso
                  State(1023).TransactionState = "CREATED" AndAlso TransactionCaptureIdIsNull(1023) AndAlso
                  WebhookFakeTransport.CaptureCalls = priorCaptures, missingCaptureId)

            InsertFixture(1009, 1)
            Dim wrongAmount As WebhookReply = Post(CaptureEvent("EVENT-LAB-WRONG-AMOUNT", 1009, "COMPLETED", "99.99"))
            Check("amount_mismatch", wrongAmount.Status = 409 AndAlso State(1009).Events = 0 AndAlso State(1009).Paid = 0,
                  wrongAmount)
            Dim wrongCurrency As WebhookReply = Post(CaptureEvent("EVENT-LAB-WRONG-CURRENCY", 1009, "COMPLETED", "12.34", "USD"))
            Check("currency_mismatch", wrongCurrency.Status = 409 AndAlso State(1009).Events = 0 AndAlso State(1009).Paid = 0,
                  wrongCurrency)
            Dim wrongMerchant As WebhookReply = Post(CaptureEvent("EVENT-LAB-WRONG-MERCHANT", 1009, "COMPLETED", "12.34", "EUR", "WRONG"))
            Check("merchant_mismatch", wrongMerchant.Status = 409 AndAlso State(1009).Events = 0 AndAlso State(1009).Paid = 0,
                  wrongMerchant)
            Dim wrongPayee As WebhookReply = Post(CaptureEvent("EVENT-LAB-WRONG-PAYEE", 1009, "COMPLETED", "12.34", "EUR", Nothing, "wrong@example.invalid"))
            Check("payee_mismatch", wrongPayee.Status = 409 AndAlso State(1009).Events = 0 AndAlso State(1009).Paid = 0,
                  wrongPayee)

            InsertFixture(1010, 1)
            Dim badSignature As WebhookReply = Post(CaptureEvent("EVENT-LAB-BAD-SIG", 1010, "COMPLETED"), signature:="LAB_BAD")
            Check("signature_failure", badSignature.Status = 400 AndAlso State(1010).Events = 0 AndAlso State(1010).Paid = 0,
                  badSignature)
            Dim noSignature As WebhookReply = Post(CaptureEvent("EVENT-LAB-NO-HEADERS", 1010, "COMPLETED"), signature:=Nothing)
            Check("missing_signature_headers", noSignature.Status = 400 AndAlso State(1010).Events = 0 AndAlso State(1010).Paid = 0,
                  noSignature)
            fakeBefore = WebhookFakeTransport.TotalCalls
            Dim badJson As WebhookReply = Post("{not-json")
            Check("malformed_json", badJson.Status = 400 AndAlso WebhookFakeTransport.TotalCalls = fakeBefore AndAlso
                  State(1010).Events = 0, badJson)

            Dim ingressEvent As String = CaptureEvent("EVENT-LAB-INGRESS", 1010, "COMPLETED")
            fakeBefore = WebhookFakeTransport.TotalCalls
            Dim insecure As WebhookReply = Post(ingressEvent, secure:=False)
            Check("http_ingress_pretransport", insecure.Status = 403 AndAlso WebhookFakeTransport.TotalCalls = fakeBefore, insecure)
            Dim localhost As WebhookReply = Post(ingressEvent, host:="localhost", remoteAddress:="127.0.0.1")
            Check("localhost_ingress_pretransport", localhost.Status = 403 AndAlso WebhookFakeTransport.TotalCalls = fakeBefore, localhost)
            Dim unknownHost As WebhookReply = Post(ingressEvent, host:="unlisted.invalid")
            Check("unknown_host_pretransport", unknownHost.Status = 403 AndAlso WebhookFakeTransport.TotalCalls = fakeBefore AndAlso
                  State(1010).Events = 0, unknownHost)

            Dim sharedIngress As WebhookReply = Post(CaptureEvent("EVENT-LAB-SHARED", 2001, "COMPLETED"), host:="store-a.invalid")
            Check("shared_webhook_tenant_b_on_host_a", sharedIngress.Status = 200 AndAlso State(2001).Paid = 1 AndAlso
                  State(2001).Events = 1 AndAlso State(1010).Paid = 0, sharedIngress)
            InsertFixture(2002, 2)
            Dim hostB As WebhookReply = Post(CaptureEvent("EVENT-LAB-HOST-B", 2002, "COMPLETED"), host:="store-b.invalid")
            Check("tenant_b_ingress", hostB.Status = 200 AndAlso State(2002).Paid = 1 AndAlso State(2002).Events = 1,
                  hostB)

            Dim crossOrder As String = CaptureEvent("EVENT-LAB-CROSS-ORDER", 1009, "COMPLETED").Replace(
                "ORDER-LAB-1009", "ORDER-LAB-2001")
            Dim crossReply As WebhookReply = Post(crossOrder)
            Check("order_tenant_mismatch", crossReply.Status = 409 AndAlso State(1009).Paid = 0 AndAlso
                  State(1009).Events = 0 AndAlso State(2001).Events = 1, crossReply)

            InsertFixture(1014, 1)
            Execute("UPDATE paypal_checkout_transazioni SET CurrentSlot=NULL WHERE DocumentiId=1014")
            priorCaptures = WebhookFakeTransport.CaptureCalls
            Dim historic As WebhookReply = Post(ApprovedEvent("EVENT-LAB-HISTORIC", 1014))
            Check("historic_attempt_no_new_capture", historic.Status = 200 AndAlso State(1014).Paid = 0 AndAlso
                  State(1014).Events = 0 AndAlso WebhookFakeTransport.CaptureCalls = priorCaptures, historic)

            InsertFixture(1015, 1)
            Dim verifyRetryEvent As String = CaptureEvent("EVENT-LAB-VERIFY-RETRY", 1015, "COMPLETED")
            WebhookFakeTransport.VerifyTransportFailure = True
            Dim verifyUnavailable As WebhookReply = Post(verifyRetryEvent)
            WebhookFakeTransport.VerifyTransportFailure = False
            Observe("transient_verify_no_false_success", verifyUnavailable.Status = 400 AndAlso State(1015).Events = 0 AndAlso
                    State(1015).Paid = 0, verifyUnavailable)
            Dim verifyRecovered As WebhookReply = Post(verifyRetryEvent)
            Check("transient_verify_same_event_recovered", verifyRecovered.Status = 200 AndAlso State(1015).Events = 1 AndAlso
                  State(1015).Paid = 1, verifyRecovered)

            InsertFixture(1016, 1)
            Dim oauthRetryEvent As String = CaptureEvent("EVENT-LAB-OAUTH-RETRY", 1016, "COMPLETED")
            WebhookFakeTransport.OAuthFailure = True
            Dim oauthUnavailable As WebhookReply = Post(oauthRetryEvent)
            WebhookFakeTransport.OAuthFailure = False
            Observe("transient_oauth_no_false_success", oauthUnavailable.Status = 400 AndAlso State(1016).Events = 0 AndAlso
                    State(1016).Paid = 0, oauthUnavailable)
            Dim oauthRecovered As WebhookReply = Post(oauthRetryEvent)
            Check("transient_oauth_same_event_recovered", oauthRecovered.Status = 200 AndAlso State(1016).Events = 1 AndAlso
                  State(1016).Paid = 1, oauthRecovered)

            InsertFixture(1017, 1)
            Dim getRetryEvent As String = ApprovedEvent("EVENT-LAB-GET-RETRY", 1017)
            WebhookFakeTransport.GetFailure = True
            Dim getUnavailable As WebhookReply = Post(getRetryEvent)
            WebhookFakeTransport.GetFailure = False
            Observe("transient_get_no_false_success", getUnavailable.Status = 409 AndAlso State(1017).Events = 0 AndAlso
                    State(1017).Paid = 0, getUnavailable)
            Dim getRecovered As WebhookReply = Post(getRetryEvent)
            Check("transient_get_same_event_recovered", getRecovered.Status = 200 AndAlso State(1017).Events = 1 AndAlso
                  State(1017).Paid = 1, getRecovered)

            InsertFixture(1018, 1)
            Dim captureRetryEvent As String = ApprovedEvent("EVENT-LAB-CAPTURE-RETRY", 1018)
            WebhookFakeTransport.CaptureFailure = True
            Dim captureUnavailable As WebhookReply = Post(captureRetryEvent)
            WebhookFakeTransport.CaptureFailure = False
            Observe("transient_capture_no_false_success", captureUnavailable.Status = 409 AndAlso
                    State(1018).TransactionState = "CAPTURING" AndAlso State(1018).Events = 0 AndAlso State(1018).Paid = 0,
                    captureUnavailable)
            Dim captureRecovered As WebhookReply = Post(captureRetryEvent)
            Check("transient_capture_same_request_recovered", captureRecovered.Status = 200 AndAlso
                  State(1018).TransactionState = "COMPLETED" AndAlso State(1018).Events = 1 AndAlso State(1018).Paid = 1 AndAlso
                  WebhookFakeTransport.LastCaptureRequestId = "CAPTURE-LAB-1018", captureRecovered)

            Dim seeded As WebhookReply = GetPage("seed.aspx", String.Empty, String.Empty)
            Observe("return_session_seed", seeded.Status = 200 AndAlso Not String.IsNullOrWhiteSpace(seeded.SetCookie), seeded)
            If seeded.Status = 200 AndAlso Not String.IsNullOrWhiteSpace(seeded.SetCookie) Then
                InsertFixture(1019, 1)
                Dim sessionCookie As String = seeded.SetCookie.Split(";"c)(0)
                Dim browserReturn As WebhookReply = GetPage("paypalreturn.aspx",
                    "id=1019&action=return&token=ORDER-LAB-1019", sessionCookie)
                Observe("actual_return_page_capture", browserReturn.Status = 302 AndAlso
                        browserReturn.Location.Contains("payreturn=ok") AndAlso State(1019).Paid = 1 AndAlso
                        State(1019).TransactionState = "COMPLETED", browserReturn)

                InsertFixture(1020, 1)
                Dim captureCountBefore As Integer = WebhookFakeTransport.CaptureCalls
                Dim logicalBefore As Integer = WebhookFakeTransport.LogicalCaptureCount()
                Dim gate As New ManualResetEvent(False)
                Dim competingWebhook As Task(Of WebhookReply) = Task.Factory.StartNew(
                    Function()
                        gate.WaitOne()
                        Return Post(ApprovedEvent("EVENT-LAB-CONCURRENT", 1020))
                    End Function)
                Dim competingReturn As Task(Of WebhookReply) = Task.Factory.StartNew(
                    Function()
                        gate.WaitOne()
                        Return GetPage("paypalreturn.aspx", "id=1020&action=return&token=ORDER-LAB-1020", sessionCookie)
                    End Function)
                gate.Set()
                Task.WaitAll(competingWebhook, competingReturn)
                Dim concurrentPaid As WebhookLabState = State(1020)
                _concurrentRawCaptureCalls = WebhookFakeTransport.CaptureCalls - captureCountBefore
                Observe("approved_webhook_return_concurrent", competingWebhook.Result.Status = 200 AndAlso
                        competingReturn.Result.Status = 302 AndAlso competingReturn.Result.Location.Contains("payreturn=ok") AndAlso
                        concurrentPaid.Paid = 1 AndAlso concurrentPaid.TransactionState = "COMPLETED" AndAlso
                        concurrentPaid.Events = 1 AndAlso Not WebhookFakeTransport.CaptureRequestConflict AndAlso
                        _concurrentRawCaptureCalls >= 1 AndAlso _concurrentRawCaptureCalls <= 2 AndAlso
                        WebhookFakeTransport.LogicalCaptureCount() - logicalBefore = 1,
                        competingWebhook.Result)
            End If

            InsertFixture(1021, 1)
            Execute("UPDATE paypal_checkout_transazioni SET CurrentSlot=NULL WHERE DocumentiId=1021")
            Execute("INSERT INTO paypal_checkout_transazioni (Id,DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,PayPalOrderId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId) VALUES (3021,1021,2,1,1,19,1,'ORDER-CURRENT-1021','CREATED',12.34,'EUR','a@example.invalid','MERCHANT_A','CREATE-CURRENT-1021','CAPTURE-CURRENT-1021')")
            Dim oldCapture As WebhookReply = Post(CaptureEvent("EVENT-LAB-OLD-COMPLETED", 1021, "COMPLETED"))
            Dim currentTx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForDocument(1021)
            Observe("historic_completed_reconciles_once", oldCapture.Status = 200 AndAlso State(1021).Paid = 1 AndAlso
                    State(1021).Events = 1 AndAlso TransactionState(1021) = "COMPLETED" AndAlso
                    TransactionState(3021) = "CREATED" AndAlso Not PayPalCheckoutRepository.TryBeginCapture(currentTx), oldCapture)

            InsertFixture(1022, 1)
            Dim applyRetryEvent As String = CaptureEvent("EVENT-LAB-APPLY-RETRY", 1022, "COMPLETED")
            Execute("RENAME TABLE paypal_checkout_eventi TO paypal_checkout_eventi_hold")
            Dim applyUnavailable As WebhookReply
            Try
                applyUnavailable = Post(applyRetryEvent)
            Finally
                Execute("RENAME TABLE paypal_checkout_eventi_hold TO paypal_checkout_eventi")
            End Try
            Observe("transient_apply_no_false_success", applyUnavailable.Status = 500 AndAlso State(1022).Paid = 0 AndAlso
                    State(1022).Events = 0 AndAlso State(1022).TransactionState = "CREATED", applyUnavailable)
            Dim applyRecovered As WebhookReply = Post(applyRetryEvent)
            Check("transient_apply_same_event_recovered", applyRecovered.Status = 200 AndAlso State(1022).Paid = 1 AndAlso
                  State(1022).Events = 1 AndAlso State(1022).TransactionState = "COMPLETED", applyRecovered)
            Return String.Join(Environment.NewLine, _lines.ToArray()) & Environment.NewLine &
                "WEBHOOK_FLOW_TOTAL=" & _lines.Count.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
                "WEBHOOK_FLOW_FAILED_COUNT=" & _failures.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
                "CONCURRENT_RAW_CAPTURE_CALLS=" & _concurrentRawCaptureCalls.ToString(CultureInfo.InvariantCulture) & Environment.NewLine &
                "WEBHOOK_SIGNATURE_BOUNDARY=FAKE_HTTP"
        Finally
            PayPalOrdersV2Client.WebhookHarnessTransportFactory = Nothing
            DropLabDatabase()
        End Try
    End Function

    Private Sub VerifyIsolatedDatabase()
        Dim settings As New MySqlConnectionStringBuilder(_connection)
        If Not settings.Database.StartsWith("ks_paypal_webhook_", StringComparison.Ordinal) OrElse
           Not String.Equals(settings.Server, "localhost", StringComparison.OrdinalIgnoreCase) OrElse
           Not _connection.Contains("Protocol=pipe") OrElse
           Not _connection.Contains("Pipe Name=KS_PAYPAL_WEBHOOK_PIPE") Then
            Throw New InvalidOperationException("ISOLATED_DATABASE_REQUIRED")
        End If
    End Sub

    Private Sub CreateLabDatabase()
        Dim settings As New MySqlConnectionStringBuilder(_connection)
        Dim labName As String = settings.Database
        settings.Database = "mysql"
        Using connection As New MySqlConnection(settings.ConnectionString)
            connection.Open()
            Using check As New MySqlCommand("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=@name", connection)
                check.Parameters.Add("@name", MySqlDbType.VarChar, 64).Value = labName
                If Convert.ToInt32(check.ExecuteScalar(), CultureInfo.InvariantCulture) <> 0 Then Throw New InvalidOperationException("LAB_DATABASE_ALREADY_EXISTS")
            End Using
            Sql(connection, "CREATE DATABASE `" & labName & "` CHARACTER SET utf8mb4")
        End Using
    End Sub

    Private Sub DropLabDatabase()
        Dim settings As New MySqlConnectionStringBuilder(_connection)
        Dim labName As String = settings.Database
        settings.Database = "mysql"
        Using connection As New MySqlConnection(settings.ConnectionString)
            connection.Open()
            Sql(connection, "DROP DATABASE IF EXISTS `" & labName & "`")
        End Using
    End Sub

    Private Sub CreateSchemaAndFixtures()
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Sql(connection, "CREATE TABLE aziende (Id int PRIMARY KEY, Nome varchar(100), Descrizione varchar(100), url1 varchar(255), url2 varchar(255), LogoWeb varchar(255), ListinoDefault int) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE pagamentitipo (Id int PRIMARY KEY, OnLine int, PermettiPagamentoSuccessivo int) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE tipodocumenti (Id int PRIMARY KEY, Web int, Abilitato int, ImpegnaQnt int) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE bancasella_ordini_pagati (DocumentiId int, codiceAutorizzazione varchar(100)) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE documenti (Id int PRIMARY KEY, UtentiId int, AziendeId int, PagamentiTipoId int, TipoDocumentiId int, OrigineOrdine varchar(16), StatiId int, NDocumento int, DataDocumento datetime, Pagato int, StatoPagamentoWeb int, IdTransazione varchar(150), DataStatoPagamentoWeb datetime, UltimoEsitoPagamentoWeb varchar(255)) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE documentipie (DocumentiId int PRIMARY KEY, TotaleDocumento decimal(15,2)) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE paypal_checkout_account (Id int PRIMARY KEY, NomeProfilo varchar(100), CredentialKey varchar(64), MerchantId varchar(128), Attivo int) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE paypal_checkout_azienda (Id int PRIMARY KEY, AziendeId int, PagamentiTipoId int, PayPalAccountId int, PayeeEmail varchar(254), BrandName varchar(127), CurrencyCode char(3), Attivo int) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE paypal_checkout_transazioni (Id bigint PRIMARY KEY, DocumentiId int, TentativoNo int, CurrentSlot int NULL, AziendeId int, PagamentiTipoId int, PayPalAccountId int, PayPalOrderId varchar(100), PayPalCaptureId varchar(100), Stato varchar(40), Importo decimal(15,2), Valuta char(3), PayeeEmail varchar(254), MerchantId varchar(128), CreateRequestId varchar(80), CaptureRequestId varchar(80), UltimoEsito varchar(255), UpdatedAt timestamp DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY UX_tx_attempt(DocumentiId,TentativoNo), UNIQUE KEY UX_tx_current(DocumentiId,CurrentSlot), UNIQUE KEY UX_tx_order(PayPalOrderId), UNIQUE KEY UX_tx_capture(PayPalCaptureId), UNIQUE KEY UX_tx_create_request(CreateRequestId), UNIQUE KEY UX_tx_capture_request(CaptureRequestId)) ENGINE=InnoDB")
            Sql(connection, "CREATE TABLE paypal_checkout_eventi (Id bigint AUTO_INCREMENT PRIMARY KEY, EventId varchar(100) NOT NULL UNIQUE, TransazioniId bigint, EventType varchar(80), CaptureId varchar(100), Stato varchar(40)) ENGINE=InnoDB")
            Sql(connection, "INSERT INTO aziende VALUES (1,'Lab A','','https://store-a.invalid','','',1),(2,'Lab B','','https://store-b.invalid','','',1)")
            Sql(connection, "INSERT INTO pagamentitipo VALUES (19,2,1)")
            Sql(connection, "INSERT INTO tipodocumenti VALUES (4,1,1,1)")
            Sql(connection, "INSERT INTO paypal_checkout_account VALUES (1,'Lab A','PAYPAL_LAB_A','MERCHANT_A',1),(2,'Lab B','PAYPAL_LAB_B','MERCHANT_B',1)")
            Sql(connection, "INSERT INTO paypal_checkout_azienda VALUES (1,1,19,1,'a@example.invalid','Lab A','EUR',1),(2,2,19,2,'b@example.invalid','Lab B','EUR',1)")
        End Using
        InsertFixture(1001, 1)
        InsertFixture(2001, 2)
    End Sub

    Private Shared Sub Sql(ByVal connection As MySqlConnection, ByVal statement As String)
        Using command As New MySqlCommand(statement, connection)
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub Execute(ByVal statement As String)
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Sql(connection, statement)
        End Using
    End Sub

    Private Sub InsertFixture(ByVal docId As Integer, ByVal company As Integer)
        Dim merchant As String = If(company = 1, "MERCHANT_A", "MERCHANT_B")
        Dim payee As String = If(company = 1, "a@example.invalid", "b@example.invalid")
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Sql(connection, "INSERT INTO documenti (Id,UtentiId,AziendeId,PagamentiTipoId,TipoDocumentiId,OrigineOrdine,StatiId,NDocumento,DataDocumento,Pagato,StatoPagamentoWeb,IdTransazione) VALUES (" & docId & ",101," & company & ",19,4,'WEB',1," & docId & ",CURRENT_TIMESTAMP,0,1,'')")
            Sql(connection, "INSERT INTO documentipie VALUES (" & docId & ",12.34)")
            Sql(connection, "INSERT INTO paypal_checkout_transazioni (Id,DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,PayPalOrderId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId) VALUES (" & docId & "," & docId & ",1,1," & company & ",19," & company & ",'ORDER-LAB-" & docId & "','CREATED',12.34,'EUR','" & payee & "','" & merchant & "','CREATE-LAB-" & docId & "','CAPTURE-LAB-" & docId & "')")
        End Using
    End Sub

    Private Function State(ByVal docId As Integer) As WebhookLabState
        Dim current As New WebhookLabState()
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Using command As New MySqlCommand("SELECT COALESCE(Pagato,0),COALESCE(StatoPagamentoWeb,0),COALESCE(IdTransazione,'') FROM documenti WHERE Id=@id", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = docId
                Using reader As MySqlDataReader = command.ExecuteReader()
                    If reader.Read() Then
                        current.Paid = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                        current.PaymentState = Convert.ToInt32(reader(1), CultureInfo.InvariantCulture)
                        current.DocumentMarker = Convert.ToString(reader(2), CultureInfo.InvariantCulture)
                    End If
                End Using
            End Using
            Using command As New MySqlCommand("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=@id", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = docId
                current.TransactionState = Convert.ToString(command.ExecuteScalar())
            End Using
            Using command As New MySqlCommand("SELECT COUNT(*) FROM paypal_checkout_eventi WHERE TransazioniId=@id", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = docId
                current.Events = Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture)
            End Using
        End Using
        Return current
    End Function

    Private Function EventCaptureIdIsNull(ByVal eventId As String) As Boolean
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Using command As New MySqlCommand("SELECT COUNT(*) FROM paypal_checkout_eventi WHERE EventId=@id AND CaptureId IS NULL", connection)
                command.Parameters.Add("@id", MySqlDbType.VarChar, 100).Value = eventId
                Return Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
            End Using
        End Using
    End Function

    Private Function TransactionCaptureIdIsNull(ByVal docId As Integer) As Boolean
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Using command As New MySqlCommand("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=@id AND PayPalCaptureId IS NULL", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = docId
                Return Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
            End Using
        End Using
    End Function

    Private Function ReversalFixtureRowsUnchanged(ByVal docId As Integer) As Boolean
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Using command As New MySqlCommand("SELECT (SELECT COUNT(*) FROM documenti WHERE Id=@id AND StatiId=1)," &
                                             "(SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=@id)", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = docId
                Using reader As MySqlDataReader = command.ExecuteReader()
                    Return reader.Read() AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 1 AndAlso
                        Convert.ToInt32(reader(1), CultureInfo.InvariantCulture) = 1
                End Using
            End Using
        End Using
    End Function

    Private Function TransactionState(ByVal transactionId As Integer) As String
        Using connection As New MySqlConnection(_connection)
            connection.Open()
            Using command As New MySqlCommand("SELECT Stato FROM paypal_checkout_transazioni WHERE Id=@id", connection)
                command.Parameters.Add("@id", MySqlDbType.Int32).Value = transactionId
                Return Convert.ToString(command.ExecuteScalar())
            End Using
        End Using
    End Function

    Private Function CaptureEvent(ByVal eventId As String, ByVal docId As Integer, ByVal state As String,
                                  Optional ByVal amount As String = "12.34", Optional ByVal currency As String = "EUR",
                                  Optional ByVal merchantOverride As String = Nothing,
                                  Optional ByVal payeeOverride As String = Nothing) As String
        Dim company As Integer = If(docId < 2000, 1, 2)
        Dim merchant As String = If(company = 1, "MERCHANT_A", "MERCHANT_B")
        Dim payee As String = If(company = 1, "a@example.invalid", "b@example.invalid")
        If merchantOverride IsNot Nothing Then merchant = merchantOverride
        If payeeOverride IsNot Nothing Then payee = payeeOverride
        Dim related As New Dictionary(Of String, Object) From {{"order_id", "ORDER-LAB-" & docId}}
        Dim resource As New Dictionary(Of String, Object) From {
            {"id", "CAPTURE-LAB-" & docId}, {"status", state},
            {"amount", New Dictionary(Of String, Object) From {{"value", amount}, {"currency_code", currency}}},
            {"payee", New Dictionary(Of String, Object) From {{"email_address", payee}, {"merchant_id", merchant}}},
            {"supplementary_data", New Dictionary(Of String, Object) From {{"related_ids", related}}}
        }
        Dim payload As New Dictionary(Of String, Object) From {
            {"id", eventId}, {"event_type", "PAYMENT.CAPTURE." & state}, {"resource", resource}
        }
        Return _serializer.Serialize(payload)
    End Function

    Private Function ApprovedEvent(ByVal eventId As String, ByVal docId As Integer) As String
        Dim payload As New Dictionary(Of String, Object) From {
            {"id", eventId}, {"event_type", "CHECKOUT.ORDER.APPROVED"},
            {"resource", New Dictionary(Of String, Object) From {{"id", "ORDER-LAB-" & docId}}}}
        Return _serializer.Serialize(payload)
    End Function

    Private Function ReversedEvent(ByVal eventId As String, ByVal docId As Integer) As String
        Dim company As Integer = If(docId < 2000, 1, 2)
        Dim unit As New Dictionary(Of String, Object) From {
            {"reference_id", "KS-" & company & "-" & docId},
            {"custom_id", "KS-DOC-" & company & "-" & docId},
            {"invoice_id", "KS-INV-" & company & "-" & docId}}
        Dim payload As New Dictionary(Of String, Object) From {
            {"id", eventId}, {"event_type", "CHECKOUT.PAYMENT-APPROVAL.REVERSED"},
            {"resource", New Dictionary(Of String, Object) From {
                {"order_id", "ORDER-LAB-" & docId}, {"purchase_units", New Object() {unit}}}}}
        Return _serializer.Serialize(payload)
    End Function

    Private Function Post(ByVal body As String, Optional ByVal host As String = "store-a.invalid",
                          Optional ByVal signature As String = "LAB_GOOD",
                          Optional ByVal secure As Boolean = True,
                          Optional ByVal remoteAddress As String = "198.51.100.20") As WebhookReply
        Dim worker As New WebhookWorkerRequest(body, host, signature, secure, remoteAddress)
        HttpRuntime.ProcessRequest(worker)
        Return New WebhookReply With {.Status = worker.ResponseStatus, .Body = worker.ResponseBody}
    End Function

    Private Function GetPage(ByVal path As String, ByVal query As String, ByVal cookie As String,
                         Optional ByVal host As String = "store-a.invalid") As WebhookReply
        Dim worker As New WebhookWorkerRequest(String.Empty, host, String.Empty, True, "198.51.100.20",
                                               path, query, "GET", cookie)
        HttpRuntime.ProcessRequest(worker)
        Return New WebhookReply With {.Status = worker.ResponseStatus, .Body = worker.ResponseBody,
                                      .SetCookie = worker.ResponseCookie, .Location = worker.ResponseLocation}
    End Function

    Private Sub Check(ByVal name As String, ByVal passed As Boolean, ByVal reply As WebhookReply)
        If Not passed Then Throw New InvalidOperationException("WEBHOOK_CASE_FAILED_" & name & "_HTTP_" & reply.Status.ToString(CultureInfo.InvariantCulture) &
                                                           "_LOG_" & LastLogCategory & "_" & LastLogException)
        _lines.Add(name & "=PASS HTTP=" & reply.Status.ToString(CultureInfo.InvariantCulture))
    End Sub

    Private Sub CheckInvariant(ByVal name As String, ByVal passed As Boolean)
        If Not passed Then Throw New InvalidOperationException("WEBHOOK_CASE_FAILED_" & name)
        _lines.Add(name & "=PASS")
    End Sub

    Private Sub Observe(ByVal name As String, ByVal passed As Boolean, ByVal reply As WebhookReply)
        If passed Then
            _lines.Add(name & "=PASS HTTP=" & reply.Status.ToString(CultureInfo.InvariantCulture))
        Else
            _failures += 1
            _lines.Add(name & "=FAIL HTTP=" & reply.Status.ToString(CultureInfo.InvariantCulture) &
                       " LOG=" & LastLogCategory & "/" & LastLogException)
        End If
    End Sub
End Class

Public Class WebhookReply
    Public Property Status As Integer
    Public Property Body As String
    Public Property SetCookie As String
    Public Property Location As String
End Class

Public Class WebhookLabState
    Public Property Paid As Integer
    Public Property PaymentState As Integer
    Public Property DocumentMarker As String
    Public Property TransactionState As String
    Public Property Events As Integer
End Class

Public Class WebhookWorkerRequest
    Inherits SimpleWorkerRequest

    Private ReadOnly _body As Byte()
    Private ReadOnly _host As String
    Private ReadOnly _signature As String
    Private ReadOnly _secure As Boolean
    Private ReadOnly _remote As String
    Private ReadOnly _verb As String
    Private ReadOnly _cookie As String
    Private ReadOnly _response As New MemoryStream()
    Public Property ResponseStatus As Integer = 200
    Public Property ResponseCookie As String = String.Empty
    Public Property ResponseLocation As String = String.Empty

    Public Sub New(ByVal body As String, ByVal host As String, ByVal signature As String,
                   ByVal secure As Boolean, ByVal remote As String,
                   Optional ByVal path As String = "paypalwebhook.aspx",
                   Optional ByVal query As String = "",
                   Optional ByVal verb As String = "POST",
                   Optional ByVal cookie As String = "")
        MyBase.New(path, query, New StringWriter(CultureInfo.InvariantCulture))
        _body = Encoding.UTF8.GetBytes(body)
        _host = host
        _signature = signature
        _secure = secure
        _remote = remote
        _verb = verb
        _cookie = cookie
    End Sub

    Public ReadOnly Property ResponseBody As String
        Get
            Return Encoding.UTF8.GetString(_response.ToArray())
        End Get
    End Property

    Public Overrides Function GetHttpVerbName() As String
        Return _verb
    End Function
    Public Overrides Function GetServerName() As String
        Return _host
    End Function
    Public Overrides Function GetLocalPort() As Integer
        Return If(_secure, 443, 80)
    End Function
    Public Overrides Function GetRemoteAddress() As String
        Return _remote
    End Function
    Public Overrides Function GetLocalAddress() As String
        Return "192.0.2.10"
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return _secure
    End Function
    Public Overrides Function GetServerVariable(ByVal name As String) As String
        If String.Equals(name, "HTTPS", StringComparison.OrdinalIgnoreCase) Then Return If(_secure, "on", "off")
        If String.Equals(name, "LOCAL_ADDR", StringComparison.OrdinalIgnoreCase) Then Return GetLocalAddress()
        Return MyBase.GetServerVariable(name)
    End Function
    Public Overrides Function GetKnownRequestHeader(ByVal index As Integer) As String
        If index = HeaderContentType Then Return "application/json"
        If index = HeaderContentLength Then Return _body.Length.ToString(CultureInfo.InvariantCulture)
        If index = HeaderHost Then Return _host
        If index = HeaderCookie Then Return _cookie
        Return MyBase.GetKnownRequestHeader(index)
    End Function
    Public Overrides Function GetUnknownRequestHeaders() As String()()
        Return New String()() {
            New String() {"PAYPAL-TRANSMISSION-ID", "LAB-TRANSMISSION"},
            New String() {"PAYPAL-TRANSMISSION-TIME", "2026-09-22T12:00:00Z"},
            New String() {"PAYPAL-CERT-URL", "https://api-m.paypal.com/certs/lab"},
            New String() {"PAYPAL-AUTH-ALGO", "SHA256withRSA"},
            New String() {"PAYPAL-TRANSMISSION-SIG", _signature}}
    End Function
    Public Overrides Function GetPreloadedEntityBody() As Byte()
        Return _body
    End Function
    Public Overrides Function IsEntireEntityBodyIsPreloaded() As Boolean
        Return True
    End Function
    Public Overrides Function GetTotalEntityBodyLength() As Integer
        Return _body.Length
    End Function
    Public Overrides Sub SendStatus(ByVal statusCode As Integer, ByVal statusDescription As String)
        ResponseStatus = statusCode
    End Sub
    Public Overrides Sub SendResponseFromMemory(ByVal data As Byte(), ByVal length As Integer)
        _response.Write(data, 0, length)
    End Sub
    Public Overrides Sub SendKnownResponseHeader(ByVal index As Integer, ByVal value As String)
        CaptureResponseHeader(GetKnownResponseHeaderName(index), value)
    End Sub
    Public Overrides Sub SendUnknownResponseHeader(ByVal name As String, ByVal value As String)
        CaptureResponseHeader(name, value)
    End Sub
    Private Sub CaptureResponseHeader(ByVal name As String, ByVal value As String)
        If String.Equals(name, "Set-Cookie", StringComparison.OrdinalIgnoreCase) Then ResponseCookie = value
        If String.Equals(name, "Location", StringComparison.OrdinalIgnoreCase) Then ResponseLocation = value
    End Sub
    Public Overrides Sub SendResponseFromFile(ByVal filename As String, ByVal offset As Long, ByVal length As Long)
        Throw New InvalidOperationException("FILE_RESPONSE_NOT_EXPECTED")
    End Sub
    Public Overrides Sub SendResponseFromFile(ByVal handle As IntPtr, ByVal offset As Long, ByVal length As Long)
        Throw New InvalidOperationException("FILE_RESPONSE_NOT_EXPECTED")
    End Sub
End Class

Public Class WebhookFakeTransport
    Implements IPayPalHttpTransport

    Public Shared TotalCalls As Integer
    Public Shared VerifyCalls As Integer
    Public Shared GetCalls As Integer
    Public Shared CaptureCalls As Integer
    Public Shared LastCaptureRequestId As String = String.Empty
    Public Shared OAuthFailure As Boolean
    Public Shared VerifyTransportFailure As Boolean
    Public Shared GetFailure As Boolean
    Public Shared CaptureFailure As Boolean
    Private Shared ReadOnly CapturedOrders As New HashSet(Of Integer)()
    Private Shared ReadOnly CaptureRequestByDocument As New Dictionary(Of Integer, String)()
    Public Shared CaptureRequestConflict As Boolean
    Private _account As String = String.Empty

    Public Function Send(ByVal request As PayPalHttpRequestData) As PayPalHttpResponseData Implements IPayPalHttpTransport.Send
        TotalCalls += 1
        If request.Url.EndsWith("/v1/oauth2/token", StringComparison.Ordinal) Then
            If OAuthFailure Then Return New PayPalHttpResponseData With {.StatusCode = 503, .Body = "{}"}
            Dim basic As String = If(request.Authorization, String.Empty)
            If Not basic.StartsWith("Basic ", StringComparison.Ordinal) Then Return New PayPalHttpResponseData With {.StatusCode = 401, .Body = "{}"}
            Dim decoded As String = Encoding.UTF8.GetString(Convert.FromBase64String(basic.Substring(6)))
            If decoded.StartsWith("LAB_A_CLIENT:", StringComparison.Ordinal) Then _account = "A"
            If decoded.StartsWith("LAB_B_CLIENT:", StringComparison.Ordinal) Then _account = "B"
            If _account = String.Empty Then Return New PayPalHttpResponseData With {.StatusCode = 401, .Body = "{}"}
            Return New PayPalHttpResponseData With {.StatusCode = 200, .Body = "{""access_token"":""LAB_ACCESS_" & _account & """}"}
        End If
        If request.Url.EndsWith("/v1/notifications/verify-webhook-signature", StringComparison.Ordinal) Then
            VerifyCalls += 1
            If VerifyTransportFailure Then Return New PayPalHttpResponseData With {.StatusCode = 503, .Body = "{}"}
            Dim data As IDictionary(Of String, Object) = TryCast(New JavaScriptSerializer().DeserializeObject(request.Body), IDictionary(Of String, Object))
            Dim valid As Boolean = _account <> String.Empty AndAlso request.Authorization = "Bearer LAB_ACCESS_" & _account AndAlso
                Value(data, "transmission_id") <> String.Empty AndAlso Value(data, "transmission_time") <> String.Empty AndAlso
                Value(data, "cert_url") <> String.Empty AndAlso Value(data, "auth_algo") <> String.Empty AndAlso
                Value(data, "transmission_sig") = "LAB_GOOD" AndAlso
                Value(data, "webhook_id") = "LAB-WEBHOOK-" & _account AndAlso
                TypeOf data("webhook_event") Is IDictionary(Of String, Object)
            Return New PayPalHttpResponseData With {.StatusCode = 200, .Body = If(valid, "{""verification_status"":""SUCCESS""}", "{""verification_status"":""FAILURE""}")}
        End If
        Dim orderMatch As Match = Regex.Match(request.Url, "/v2/checkout/orders/(ORDER-LAB-(\d+))(/capture)?$", RegexOptions.CultureInvariant)
        If orderMatch.Success Then
            Dim docId As Integer = Integer.Parse(orderMatch.Groups(2).Value, CultureInfo.InvariantCulture)
            Dim company As String = If(docId < 2000, "A", "B")
            If _account <> company OrElse request.Authorization <> "Bearer LAB_ACCESS_" & company Then
                Return New PayPalHttpResponseData With {.StatusCode = 403, .Body = "{}"}
            End If
            Dim capture As Boolean = orderMatch.Groups(3).Success
            If capture Then
                Interlocked.Increment(CaptureCalls)
                SyncLock CapturedOrders
                    Dim priorRequest As String = Nothing
                    If CaptureRequestByDocument.TryGetValue(docId, priorRequest) Then
                        If Not String.Equals(priorRequest, request.RequestId, StringComparison.Ordinal) Then
                            CaptureRequestConflict = True
                            Return New PayPalHttpResponseData With {.StatusCode = 409, .Body = "{}"}
                        End If
                    Else
                        CaptureRequestByDocument(docId) = request.RequestId
                    End If
                    LastCaptureRequestId = request.RequestId
                End SyncLock
                If CaptureFailure Then Return New PayPalHttpResponseData With {.StatusCode = 503, .Body = "{}"}
                SyncLock CapturedOrders
                    CapturedOrders.Add(docId)
                End SyncLock
                Return New PayPalHttpResponseData With {.StatusCode = 201, .Body = OrderRepresentation(docId, True)}
            End If
            GetCalls += 1
            If GetFailure Then Return New PayPalHttpResponseData With {.StatusCode = 503, .Body = "{}"}
            Dim previouslyCaptured As Boolean
            SyncLock CapturedOrders
                previouslyCaptured = CapturedOrders.Contains(docId)
            End SyncLock
            Return New PayPalHttpResponseData With {.StatusCode = 200, .Body = OrderRepresentation(docId, previouslyCaptured)}
        End If
        Return New PayPalHttpResponseData With {.StatusCode = 503, .Body = "{}"}
    End Function

    Public Shared Function LogicalCaptureCount() As Integer
        SyncLock CapturedOrders
            Return CapturedOrders.Count
        End SyncLock
    End Function

    Private Shared Function Value(ByVal data As IDictionary(Of String, Object), ByVal key As String) As String
        If data Is Nothing OrElse Not data.ContainsKey(key) OrElse data(key) Is Nothing Then Return String.Empty
        Return Convert.ToString(data(key), CultureInfo.InvariantCulture).Trim()
    End Function

    Private Shared Function OrderRepresentation(ByVal docId As Integer, ByVal captured As Boolean) As String
        Dim company As String = If(docId < 2000, "A", "B")
        Dim companyId As Integer = If(company = "A", 1, 2)
        Dim orderId As String = "ORDER-LAB-" & docId.ToString(CultureInfo.InvariantCulture)
        Dim unit As New Dictionary(Of String, Object) From {
            {"reference_id", "KS-" & companyId & "-" & docId},
            {"custom_id", "KS-DOC-" & companyId & "-" & docId},
            {"invoice_id", "KS-INV-" & companyId & "-" & docId},
            {"amount", New Dictionary(Of String, Object) From {{"value", "12.34"}, {"currency_code", "EUR"}}},
            {"payee", New Dictionary(Of String, Object) From {
                {"email_address", If(company = "A", "a@example.invalid", "b@example.invalid")},
                {"merchant_id", "MERCHANT_" & company}}}
        }
        If captured Then
            unit("payments") = New Dictionary(Of String, Object) From {
                {"captures", New Object() {New Dictionary(Of String, Object) From {
                    {"id", "CAPTURE-LAB-" & docId}, {"status", "COMPLETED"},
                    {"amount", New Dictionary(Of String, Object) From {{"value", "12.34"}, {"currency_code", "EUR"}}}}}}
            }
        End If
        Dim root As New Dictionary(Of String, Object) From {
            {"id", orderId}, {"status", If(captured, "COMPLETED", "APPROVED")},
            {"intent", "CAPTURE"}, {"purchase_units", New Object() {unit}}
        }
        Return New JavaScriptSerializer().Serialize(root)
    End Function
End Class
#End If
