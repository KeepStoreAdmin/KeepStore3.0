Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Web.Script.Serialization

' PAYPAL-AUTHORIZE-CLIENT-1A (fase P1 del progetto pay-first): prove del client PayPal per AUTHORIZE / incasso dell'autorizzazione / annullo.
' Transport finto, nessuna rete. Le fixture seguono gli ESEMPI della specifica ufficiale PayPal (Orders v2 e Payments v2), non risposte reali.

Public Class PayPalPaymentDocumentInfo
    Public Property DocumentId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property TotalDocument As Decimal
End Class

Public Module PayPalCheckoutRepository
    Public Function LoadConfigForDocument(ByVal id As Integer) As PayPalCheckoutConfig
        Return Nothing
    End Function
    Public Function LoadConfigForCompanyPayment(ByVal company As Integer, ByVal payment As Integer) As PayPalCheckoutConfig
        Return Nothing
    End Function
End Module

Public Class StorefrontSeoTenantIdentity
    Public Property CompanyId As Integer
End Class

Public NotInheritable Class StorefrontSeoTenantContext
    Public Shared Function Resolve(ByVal context As System.Web.HttpContext) As StorefrontSeoTenantIdentity
        Return Nothing
    End Function
End Class

Public NotInheritable Class StorefrontCanonicalHostPolicy
    Public Shared Function IsRequestHostAllowed(ByVal tenant As StorefrontSeoTenantIdentity, ByVal host As String, ByVal local As Boolean) As Boolean
        Return False
    End Function
End Class

Public Class FakeTransport
    Implements IPayPalHttpTransport
    Private ReadOnly _responses As New Queue(Of PayPalHttpResponseData)()
    Public ReadOnly Requests As New List(Of PayPalHttpRequestData)()
    Public Sub Add(ByVal status As Integer, ByVal body As String)
        _responses.Enqueue(New PayPalHttpResponseData With {.StatusCode = status, .Body = body})
    End Sub
    Public Function Send(ByVal request As PayPalHttpRequestData) As PayPalHttpResponseData Implements IPayPalHttpTransport.Send
        Requests.Add(request)
        If _responses.Count = 0 Then Throw New InvalidOperationException("No fake response")
        Return _responses.Dequeue()
    End Function
End Class

Module PayPalAuthorizeHarness
    Private _passed As Integer
    Private _rawRequest As String = String.Empty
    Private Const OrderId As String = "ORDER-123456"
    Private Const AuthId As String = "0AW2184448108334S"
    Private Const CaptureId As String = "2GG279541U471931P"

    Private Sub Check(ByVal condition As Boolean, ByVal name As String)
        If Not condition Then Throw New Exception("PAYPAL_AUTHORIZE_FAILED: " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function J(ByVal s As String) As String
        Return s.Replace("'"c, """"c)
    End Function

    Private Function Cfg(ByVal company As Integer) As PayPalCheckoutConfig
        Return New PayPalCheckoutConfig With {.AccountId = 9, .CompanyConfigId = company + 100, .AziendeId = company,
            .PagamentiTipoId = 19, .CredentialKey = "PAYPAL_TEST", .MerchantId = "MERCHANT-SHARED",
            .PayeeEmail = "tenant-" & company & "@example.invalid", .BrandName = "TENANT " & company, .CurrencyCode = "EUR",
            .ClientId = "client", .ClientSecret = "FAKE-secret", .WebhookId = "webhook", .AccountActive = True, .CompanyActive = True}
    End Function

    Private Function Att(ByVal company As Integer) As PayPalAttemptInfo
        Return New PayPalAttemptInfo With {.AziendeId = company, .PagamentiTipoId = 19, .AttemptId = 77, .Amount = 12.34D}
    End Function

    Private Function OAuth() As String
        Return J("{'access_token':'fake-access','token_type':'Bearer'}")
    End Function

    ' Ordine completo (come lo restituisce un GET): intent, id del tentativo, importo, payee. Parametri per rompere un campo alla volta.
    Private Function OrderFull(ByVal status As String, Optional ByVal intent As String = "AUTHORIZE", Optional ByVal reference As String = "KS-A-1-77",
                               Optional ByVal custom As String = "KS-ATT-1-77", Optional ByVal invoice As String = "KS-AINV-1-77",
                               Optional ByVal amount As String = "12.34", Optional ByVal currency As String = "EUR",
                               Optional ByVal email As String = "tenant-1@example.invalid", Optional ByVal merchant As String = "MERCHANT-SHARED",
                               Optional ByVal payments As String = "", Optional ByVal id As String = OrderId, Optional ByVal units As Integer = 1) As String
        Dim unit As String = "{'reference_id':'" & reference & "','custom_id':'" & custom & "','invoice_id':'" & invoice & "','amount':{'currency_code':'" & currency & "','value':'" & amount & "'},'payee':{'email_address':'" & email & "','merchant_id':'" & merchant & "'}" & payments & "}"
        Dim unitList As String = unit
        For i As Integer = 2 To units
            unitList &= "," & unit
        Next
        Dim intentJson As String = If(intent = "", "", "'intent':'" & intent & "',")
        Return J("{'id':'" & id & "'," & intentJson & "'status':'" & status & "','purchase_units':[" & unitList & "],'links':[{'rel':'payer-action','href':'https://www.paypal.com/checkoutnow?token=" & id & "'}]}")
    End Function

    Private Function PaymentsAuth(ByVal status As String, ByVal amount As String, ByVal currency As String, Optional ByVal extra As String = "", Optional ByVal id As String = AuthId) As String
        Return ",'payments':{'authorizations':[{'id':'" & id & "','status':'" & status & "','amount':{'currency_code':'" & currency & "','value':'" & amount & "'}" & extra & ",'expiration_time':'2026-12-16T21:20:49Z'}]}"
    End Function

    ' Risposta di authorize come nell'esempio ufficiale: niente intent, payee, amount/custom_id/invoice_id di unita; ordine senza status.
    Private Function AuthorizeOfficial(ByVal status As String, ByVal amount As String, ByVal currency As String, Optional ByVal extra As String = "", Optional ByVal count As Integer = 1) As String
        Dim one As String = "{'id':'" & AuthId & "','status':'" & status & "','amount':{'currency_code':'" & currency & "','value':'" & amount & "'}" & extra & ",'seller_protection':{'status':'ELIGIBLE'},'expiration_time':'2026-12-16T21:20:49Z','links':[{'href':'https://api-m.paypal.com/v2/payments/authorizations/" & AuthId & "','rel':'self','method':'GET'}]}"
        Dim list As String = ""
        For i As Integer = 1 To count
            If i > 1 Then list &= ","
            list &= one
        Next
        Dim payments As String = If(count = 0, "", ",'payments':{'authorizations':[" & list & "]}")
        Return J("{'id':'" & OrderId & "','payment_source':{'paypal':{'account_status':'VERIFIED'}},'purchase_units':[{'reference_id':'KS-A-1-77'" & payments & "}],'payer':{'payer_id':'QYR5Z8XDVJNXQ'},'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/" & OrderId & "','rel':'self','method':'GET'}]}")
    End Function

    Private Function AuthorizationGetJson(ByVal status As String, ByVal amount As String, ByVal currency As String, Optional ByVal invoice As String = "KS-AINV-1-77") As String
        Dim inv As String = If(invoice = "", "", "'invoice_id':'" & invoice & "',")
        Return J("{'id':'" & AuthId & "','status':'" & status & "','amount':{'value':'" & amount & "','currency_code':'" & currency & "'}," & inv & "'payee':{'email_address':'tenant-1@example.invalid','merchant_id':'MERCHANT-SHARED'},'expiration_time':'2026-12-16T21:20:49Z','links':[]}")
    End Function

    Private Function CaptureFull(ByVal status As String, ByVal amount As String, ByVal currency As String, Optional ByVal invoice As String = "KS-INV-1-169277", Optional ByVal finalCapture As String = "true") As String
        Dim inv As String = If(invoice = "", "", "'invoice_id':'" & invoice & "',")
        Dim fin As String = If(finalCapture = "", "", "'final_capture':" & finalCapture & ",")
        Return J("{'id':'" & CaptureId & "','status':'" & status & "','status_details':{},'amount':{'value':'" & amount & "','currency_code':'" & currency & "'}," & fin & inv & "'create_time':'2026-11-16T21:24:01Z','links':[{'rel':'up','method':'GET','href':'https://api-m.paypal.com/v2/payments/authorizations/" & AuthId & "'}]}")
    End Function

    Private Function CaptureMinimal(ByVal status As String) As String
        Return J("{'id':'" & CaptureId & "','status':'" & status & "','links':[]}")
    End Function

    Private Function ErrorJson(ByVal name As String, ByVal issue As String) As String
        Dim details As String = If(issue = "", "", ",'details':[{'issue':'" & issue & "'}]")
        Return J("{'name':'" & name & "','message':'x','debug_id':'abc'" & details & "}")
    End Function

    ' Server HTTP minimo su loopback (TcpListener, nessuna rete esterna, nessun URL ACL): registra i byte della richiesta e risponde con il testo dato.
    Private Function RoundTrip(ByVal request As PayPalHttpRequestData, ByVal responseText As String) As PayPalHttpResponseData
        Dim listener As New System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0)
        listener.Start()
        Try
            Dim port As Integer = CType(listener.LocalEndpoint, System.Net.IPEndPoint).Port
            request.Url = "http://127.0.0.1:" & port & request.Url
            _rawRequest = String.Empty
            Dim worker As New System.Threading.Thread(Sub()
                                                          Using c As System.Net.Sockets.TcpClient = listener.AcceptTcpClient()
                                                              Dim s As System.Net.Sockets.NetworkStream = c.GetStream()
                                                              Dim text As New System.Text.StringBuilder()
                                                              Dim buf(4095) As Byte
                                                              Dim need As Integer = -1
                                                              Dim start As Integer = -1
                                                              Do
                                                                  Dim n As Integer = s.Read(buf, 0, buf.Length)
                                                                  If n <= 0 Then Exit Do
                                                                  text.Append(System.Text.Encoding.ASCII.GetString(buf, 0, n))
                                                                  Dim all As String = text.ToString()
                                                                  Dim h As Integer = all.IndexOf(vbCrLf & vbCrLf, StringComparison.Ordinal)
                                                                  If h >= 0 Then
                                                                      If need < 0 Then
                                                                          Dim cl As Integer = all.IndexOf("Content-Length:", StringComparison.OrdinalIgnoreCase)
                                                                          need = 0
                                                                          If cl >= 0 AndAlso cl < h Then
                                                                              Dim eol As Integer = all.IndexOf(vbCrLf, cl, StringComparison.Ordinal)
                                                                              need = Integer.Parse(all.Substring(cl + 15, eol - cl - 15).Trim())
                                                                          End If
                                                                          start = h + 4
                                                                      End If
                                                                      If all.Length - start >= need Then Exit Do
                                                                  End If
                                                              Loop
                                                              _rawRequest = text.ToString()
                                                              Dim reply() As Byte = System.Text.Encoding.ASCII.GetBytes(responseText)
                                                              s.Write(reply, 0, reply.Length)
                                                              s.Flush()
                                                          End Using
                                                      End Sub)
            worker.IsBackground = True
            worker.Start()
            Dim response As PayPalHttpResponseData = New PayPalHttpWebRequestTransport().Send(request)
            worker.Join(5000)
            Return response
        Finally
            listener.Stop()
        End Try
    End Function

    ' Ordine COMPLETED con autorizzazione e cattura (replay dopo l'incasso).
    Private Function PaymentsBoth(ByVal authStatus As String, ByVal capStatus As String, ByVal capAmount As String, ByVal capCurrency As String) As String
        Return ",'payments':{'authorizations':[{'id':'" & AuthId & "','status':'" & authStatus & "','amount':{'currency_code':'EUR','value':'12.34'},'expiration_time':'2026-12-16T21:20:49Z'}]," &
               "'captures':[{'id':'" & CaptureId & "','status':'" & capStatus & "','amount':{'currency_code':'" & capCurrency & "','value':'" & capAmount & "'}}]}"
    End Function

    ' --- Esempi LETTERALI della specifica ufficiale (non formano una transazione coerente: servono solo al parser) ---
    Private Function LiteralAuthorize() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{'name':{'given_name':'John','surname':'Doe'},'account_status':'VERIFIED','email_address':'customer@example.com','account_id':'QYR5Z8XDVJNXQ'}}," &
            "'purchase_units':[{'reference_id':'d9f80740-38f0-11e8-b467-0ed5f89f718b','shipping':{'address':{'address_line_1':'2211 N First Street','admin_area_2':'San Jose','admin_area_1':'CA','postal_code':'95131','country_code':'US'}}," &
            "'payments':{'authorizations':[{'id':'0AW2184448108334S','status':'CREATED','amount':{'currency_code':'USD','value':'100.00'},'seller_protection':{'status':'ELIGIBLE','dispute_categories':['ITEM_NOT_RECEIVED']}," &
            "'expiration_time':'2018-05-01T21:20:49Z','create_time':'2018-04-01T21:20:49Z','update_time':'2018-04-01T21:20:49Z'," &
            "'links':[{'href':'https://api-m.paypal.com/v2/payments/authorizations/0AW2184448108334S','rel':'self','method':'GET'}]}]}}]," &
            "'payer':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','payer_id':'QYR5Z8XDVJNXQ'}," &
            "'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'}]}")
    End Function

    Private Function LiteralCapture() As String
        Return J("{'id':'2GG279541U471931P','status':'COMPLETED','status_details':{},'amount':{'value':'10.99','currency_code':'USD'},'final_capture':true," &
            "'seller_protection':{'status':'ELIGIBLE','dispute_categories':['ITEM_NOT_RECEIVED','UNAUTHORIZED_TRANSACTION']}," &
            "'seller_receivable_breakdown':{'gross_amount':{'value':'10.99','currency_code':'USD'},'paypal_fee':{'value':'0.33','currency_code':'USD'},'net_amount':{'value':'10.66','currency_code':'USD'}}," &
            "'invoice_id':'INV-123','create_time':'2017-09-11T23:24:01Z','update_time':'2017-09-11T23:24:01Z'," &
            "'links':[{'rel':'self','method':'GET','href':'https://api-m.paypal.com/v2/payments/captures/2GG279541U471931P'}," &
            "{'rel':'refund','method':'POST','href':'https://api-m.paypal.com/v2/payments/captures/2GG279541U471931P/refund'}," &
            "{'rel':'up','method':'GET','href':'https://api-m.paypal.com/v2/payments/authorizations/0VF52814937998046'}]}")
    End Function

    Private Function LiteralGetAuthorization() As String
        Return J("{'id':'0VF52814937998046','status':'CREATED','amount':{'value':'10.99','currency_code':'USD'},'invoice_id':'INVOICE-123'," &
            "'seller_protection':{'status':'ELIGIBLE'},'payee':{'email_address':'merchant@example.com','merchant_id':'7KNGBPH2U58GQ'}," &
            "'expiration_time':'2017-10-10T23:23:45Z','create_time':'2017-09-11T23:23:45Z','update_time':'2017-09-11T23:23:45Z'," &
            "'links':[{'rel':'self','method':'GET','href':'https://api-m.paypal.com/v2/payments/authorizations/0VF52814937998046'}]}")
    End Function

    Private Function Dict(ByVal json As String) As IDictionary(Of String, Object)
        Return TryCast(New JavaScriptSerializer().DeserializeObject(json), IDictionary(Of String, Object))
    End Function

    Private Function OrderSnap(ByVal json As String) As PayPalOrderSnapshot
        Dim fake As New FakeTransport()
        fake.Add(200, OAuth()) : fake.Add(200, json)
        Return New PayPalOrdersV2Client(Cfg(1), fake).GetOrder(OrderId).Snapshot
    End Function

    Private Function AuthSnap(ByVal json As String) As PayPalAuthorizationSnapshot
        Dim fake As New FakeTransport()
        fake.Add(200, OAuth()) : fake.Add(200, json)
        Return New PayPalOrdersV2Client(Cfg(1), fake).GetAuthorization(AuthId).Authorization
    End Function

    Private Function CapSnap(ByVal json As String) As PayPalCaptureSnapshot
        Dim fake As New FakeTransport()
        fake.Add(200, OAuth()) : fake.Add(201, json)
        Return New PayPalOrdersV2Client(Cfg(1), fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "").Capture
    End Function

    Private Function Fk(ByVal status As Integer, ByVal body As String) As FakeTransport
        Dim f As New FakeTransport()
        f.Add(200, OAuth()) : f.Add(status, body)
        Return f
    End Function

    Private Function Cl(ByVal f As FakeTransport) As PayPalOrdersV2Client
        Return New PayPalOrdersV2Client(Cfg(1), f)
    End Function

    Function Main() As Integer
        Try
            Run()
            Console.WriteLine("PAYPAL_AUTHORIZE_TOTAL=" & _passed)
            Return 0
        Catch ex As Exception
            Console.WriteLine("FAIL " & ex.Message)
            Return 1
        End Try
    End Function

    Private Sub Run()
        Dim cfg1 As PayPalCheckoutConfig = Cfg(1)
        Dim att1 As PayPalAttemptInfo = Att(1)
        Dim nowUtc As New DateTime(2026, 11, 16, 21, 0, 0, DateTimeKind.Utc)
        Dim fake As FakeTransport

        ' ---- A. riferimenti e payload del tentativo ----
        Check(PayPalOrdersV2Client.ExpectedAttemptReferenceId(att1) = "KS-A-1-77", "A01 attempt reference id")
        Check(PayPalOrdersV2Client.ExpectedAttemptCustomId(att1) = "KS-ATT-1-77", "A02 attempt custom id")
        Check(PayPalOrdersV2Client.ExpectedAttemptInvoiceId(att1) = "KS-AINV-1-77", "A03 attempt invoice id")
        Dim client0 As New PayPalOrdersV2Client(cfg1, New FakeTransport())
        Dim payload As String = client0.BuildCreateAuthorizeOrderPayload(att1, "https://t1.invalid/r", "https://t1.invalid/c")
        Dim pd As IDictionary(Of String, Object) = Dict(payload)
        Dim unit As IDictionary(Of String, Object) = DirectCast(DirectCast(pd("purchase_units"), IList)(0), IDictionary(Of String, Object))
        Dim amountD As IDictionary(Of String, Object) = DirectCast(unit("amount"), IDictionary(Of String, Object))
        Dim payeeD As IDictionary(Of String, Object) = DirectCast(unit("payee"), IDictionary(Of String, Object))
        Dim exp As IDictionary(Of String, Object) = DirectCast(DirectCast(DirectCast(pd("payment_source"), IDictionary(Of String, Object))("paypal"), IDictionary(Of String, Object))("experience_context"), IDictionary(Of String, Object))
        Check(Convert.ToString(pd("intent")) = "AUTHORIZE", "A04 payload intent AUTHORIZE")
        Check(Convert.ToString(unit("reference_id")) = "KS-A-1-77" AndAlso Convert.ToString(unit("custom_id")) = "KS-ATT-1-77" AndAlso Convert.ToString(unit("invoice_id")) = "KS-AINV-1-77", "A05 payload carries the attempt ids")
        Check(Convert.ToString(amountD("value")) = "12.34" AndAlso Convert.ToString(amountD("currency_code")) = "EUR", "A06 payload amount and currency")
        Check(Convert.ToString(payeeD("email_address")) = "tenant-1@example.invalid", "A07 payload payee from tenant config")
        Check(Convert.ToString(exp("return_url")) = "https://t1.invalid/r" AndAlso Convert.ToString(exp("cancel_url")) = "https://t1.invalid/c" AndAlso Convert.ToString(exp("user_action")) = "PAY_NOW", "A08 payload experience context")
        Check(Not payload.Contains("KS-DOC") AndAlso Not payload.Contains("KS-INV-"), "A09 payload never carries a document id (no number exists yet)")
        Check(client0.BuildCreateAuthorizeOrderPayload(Nothing, "a", "b") = String.Empty, "A10 payload without attempt is empty")
        Dim noId As PayPalAttemptInfo = Att(1)
        noId.AttemptId = 0
        Dim noAmount As PayPalAttemptInfo = Att(1)
        noAmount.Amount = 0D
        Dim tiny As PayPalAttemptInfo = Att(1)
        tiny.Amount = 0.004D
        Check(client0.BuildCreateAuthorizeOrderPayload(noId, "a", "b") = String.Empty AndAlso client0.BuildCreateAuthorizeOrderPayload(noAmount, "a", "b") = String.Empty AndAlso client0.BuildCreateAuthorizeOrderPayload(tiny, "a", "b") = String.Empty, "A11 attempt without id or with a zero amount (after rounding) gives no payload")
        Check(client0.BuildCreateAuthorizeOrderPayload(Att(2), "a", "b") = String.Empty, "A12 attempt of another tenant than the config gives no payload")

        ' ---- B. creazione dell'ordine AUTHORIZE ----
        fake = Fk(201, OrderFull("CREATED"))
        Dim create As PayPalOrdersV2Result = Cl(fake).CreateAuthorizeOrder(att1, "PP-AUTH-CREATE-1-77", "https://t1.invalid/r", "https://t1.invalid/c")
        Check(create.Success AndAlso create.Snapshot.ApprovalUrl.Contains("checkoutnow"), "B01 create authorize order 201 with full representation")
        Check(fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/v2/checkout/orders"), "B02 create authorize route")
        Check(fake.Requests(1).RequestId = "PP-AUTH-CREATE-1-77" AndAlso fake.Requests(1).Prefer = "return=representation", "B03 create authorize idempotency and representation headers")
        Check(fake.Requests(1).Body = payload, "B04 create authorize sends the exact payload")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, create.Snapshot) = "", "B05 created order accepted")
        Dim minimal As PayPalOrdersV2Result = Cl(Fk(201, J("{'id':'" & OrderId & "','status':'CREATED','links':[{'rel':'payer-action','href':'https://www.paypal.com/checkoutnow?token=" & OrderId & "'}]}"))).CreateAuthorizeOrder(att1, "PP-AUTH-CREATE-1-77", "r", "c")
        Check(minimal.Success AndAlso PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, minimal.Snapshot) = "", "B06 minimal create response (id, status, approval link) is enough")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("CREATED", intent:="CAPTURE"))) = "INTENT", "B07 created order with intent CAPTURE refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("CREATED", amount:="12.35"))) = "AMOUNT", "B08 created order with another amount refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED"))) = "STATE", "B09 created order in APPROVED refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, "OTHER-ORDER-1", OrderSnap(OrderFull("CREATED"))) = "ORDER_ID", "B10 created order with another order id refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(J("{'id':'" & OrderId & "','status':'CREATED','links':[]}"))) = "APPROVAL_URL", "B11 created order without approval link refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("CREATED", payments:=PaymentsAuth("CREATED", "12.34", "EUR")))) = "STATE", "B12 created order that already has an authorization refused")
        Check(PayPalOrdersV2Client.CheckCreatedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("CREATED", merchant:="OTHER-MERCHANT"))) = "MERCHANT", "B13 created order with a present but different merchant refused")
        fake = New FakeTransport()
        Dim noAttempt As PayPalOrdersV2Result = Cl(fake).CreateAuthorizeOrder(Nothing, "PP-AUTH-CREATE-1-77", "r", "c")
        Check(Not noAttempt.Success AndAlso noAttempt.NotSent AndAlso fake.Requests.Count = 0, "B14 no attempt: no request")
        fake = New FakeTransport()
        Check(Cl(fake).CreateAuthorizeOrder(noId, "PP-AUTH-CREATE-1-77", "r", "c").NotSent AndAlso Cl(fake).CreateAuthorizeOrder(Att(2), "PP-AUTH-CREATE-1-77", "r", "c").NotSent AndAlso fake.Requests.Count = 0, "B15 attempt without id or of another tenant: no request, NotSent")
        Dim createRefused As PayPalOrdersV2Result = Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "PAYER_ACTION_REQUIRED"))).CreateAuthorizeOrder(att1, "PP-AUTH-CREATE-1-77", "r", "c")
        Check(Not createRefused.Success AndAlso createRefused.ErrorCode = "UNPROCCESSABLE_ENTITY:PAYER_ACTION_REQUIRED" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(createRefused), "B16 create refused with 422 is definitive and keeps the issue")

        ' ---- C. GET ordine: validatore stretto (APPROVED / COMPLETED) ----
        Dim approved As PayPalOrderSnapshot = OrderSnap(OrderFull("APPROVED"))
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, approved) = "", "C01 approved authorize order accepted")
        Check(PayPalOrdersV2Client.ValidateApprovedAuthorizeOrder(att1, cfg1, OrderId, approved), "C02 boolean wrapper agrees")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", intent:="CAPTURE"))) = "INTENT", "C03 intent CAPTURE refused with reason INTENT")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", intent:=""))) = "INTENT", "C04 missing intent refused in strict mode")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", reference:="KS-A-1-78"))) = "REFERENCE_ID", "C05 wrong reference refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", custom:="KS-ATT-1-78"))) = "CUSTOM_ID", "C06 wrong custom id refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", invoice:="KS-AINV-2-77"))) = "INVOICE_ID", "C07 wrong invoice id refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", amount:="12.35"))) = "AMOUNT", "C08 wrong amount refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", currency:="USD"))) = "CURRENCY", "C09 wrong currency refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", email:="tenant-2@example.invalid"))) = "PAYEE", "C10 other tenant payee refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", merchant:="OTHER-MERCHANT"))) = "MERCHANT", "C11 other merchant refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", units:=2))) = "UNIT_COUNT", "C12 two purchase units refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, Cfg(2), OrderId, approved) = "TENANT", "C13 config of another tenant refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, "OTHER-ORDER-1", approved) = "ORDER_ID", "C14 other order id refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("CREATED"))) = "STATE", "C15 order not yet approved refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("APPROVED", payments:=PaymentsAuth("CREATED", "12.34", "EUR")))) = "STATE", "C16 APPROVED with an authorization refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, Nothing) = "INPUT", "C17 null snapshot refused")
        Dim completed As PayPalOrderSnapshot = OrderSnap(OrderFull("COMPLETED", payments:=PaymentsAuth("CREATED", "12.34", "EUR")))
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, completed) = "", "C18 COMPLETED order with one matching authorization accepted (replay)")
        Check(completed.AuthorizationCount = 1 AndAlso completed.Authorization IsNot Nothing AndAlso completed.Authorization.Id = AuthId, "C19 parser reads the authorization of the order")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED", payments:=PaymentsAuth("CREATED", "99.00", "EUR")))) = "AUTHORIZATION_AMOUNT", "C20 COMPLETED order with another authorization amount refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED"))) = "STATE", "C21 COMPLETED order without authorization refused")
        Check(PayPalOrdersV2Client.ValidateSnapshot(New PayPalPaymentDocumentInfo With {.DocumentId = 77, .AziendeId = 1, .PagamentiTipoId = 19, .TotalDocument = 12.34D}, cfg1, OrderId, approved) = False, "C22 the existing CAPTURE validator refuses an AUTHORIZE order")
        Dim amountEmpty As String = OrderFull("APPROVED").Replace("""amount"":{""currency_code"":""EUR"",""value"":""12.34""}", """amount"":{}")
        Check(amountEmpty.Contains("""amount"":{}") AndAlso PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(amountEmpty)) = "AMOUNT", "C23 present but empty amount refused")
        Dim amountNull As String = OrderFull("APPROVED").Replace("""amount"":{""currency_code"":""EUR"",""value"":""12.34""}", """amount"":null")
        Check(amountNull.Contains("""amount"":null") AndAlso PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(amountNull)) = "AMOUNT", "C24 null amount refused in strict mode")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED", payments:=PaymentsBoth("CAPTURED", "COMPLETED", "12.34", "EUR")))) = "", "C25 COMPLETED order, authorization CAPTURED and one matching capture accepted (replay after the charge)")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED", payments:=PaymentsBoth("CAPTURED", "COMPLETED", "99.00", "EUR")))) = "CAPTURE_AMOUNT", "C26 capture with another amount refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED", payments:=PaymentsBoth("CAPTURED", "WEIRD", "12.34", "EUR")))) = "CAPTURE_STATUS", "C27 capture with an unknown status refused")
        Check(PayPalOrdersV2Client.CheckApprovedAuthorizeOrder(att1, cfg1, OrderId, OrderSnap(OrderFull("COMPLETED", payments:=PaymentsBoth("CAPTURED", "COMPLETED", "12.34", "USD")))) = "CAPTURE_CURRENCY", "C28 capture with another currency refused")

        ' ---- D. authorize ----
        fake = Fk(201, AuthorizeOfficial("CREATED", "12.34", "EUR"))
        Dim auth As PayPalOrdersV2Result = Cl(fake).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(auth.Success AndAlso auth.Snapshot.AuthorizationCount = 1 AndAlso auth.Snapshot.Authorization.Id = AuthId AndAlso auth.Snapshot.Authorization.Status = "CREATED", "D01 official-shaped authorize response accepted without intent, payee or unit amount")
        Check(fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/v2/checkout/orders/" & OrderId & "/authorize"), "D02 authorize route")
        Check(fake.Requests(1).RequestId = "PP-AUTH-1-77" AndAlso fake.Requests(1).Prefer = "return=representation" AndAlso fake.Requests(1).Body = "{}", "D03 authorize headers and body")
        Check(auth.Snapshot.Authorization.Amount = 12.34D AndAlso auth.Snapshot.Authorization.Currency = "EUR" AndAlso auth.Snapshot.Authorization.AmountValid AndAlso auth.Snapshot.Authorization.ExpirationTime.StartsWith("2026-12-16"), "D04 authorization amount, currency and expiration read")
        Check(PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, OrderId, auth.Snapshot) = "", "D05 authorize response accepted for the attempt")
        Check(Cl(Fk(200, AuthorizeOfficial("CREATED", "12.34", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Success, "D06 idempotent replay 200 accepted")
        For Each code As Integer In New Integer() {202, 207}
            Dim r As PayPalOrdersV2Result = Cl(Fk(code, AuthorizeOfficial("CREATED", "12.34", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
            Check(Not r.Success AndAlso r.StatusCode = code AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(r), "D07 authorize " & code & " is not a success and is uncertain")
        Next
        Dim lost As PayPalOrdersV2Result = Cl(Fk(0, String.Empty)).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not lost.Success AndAlso lost.StatusCode = 0 AndAlso Not lost.NotSent AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(lost), "D08 lost authorize response (after the token) is uncertain")
        Dim refused As PayPalOrdersV2Result = Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "PAYER_ACTION_REQUIRED"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not refused.Success AndAlso refused.ErrorCode = "UNPROCCESSABLE_ENTITY:PAYER_ACTION_REQUIRED" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(refused), "D09 422 is definitive and the issue is kept in the error code")
        Dim noAuth As PayPalOrdersV2Result = Cl(Fk(201, AuthorizeOfficial("CREATED", "12.34", "EUR", count:=0))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not noAuth.Success AndAlso noAuth.ErrorCode = "AUTHORIZE_REPRESENTATION_INCOMPLETE" AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(noAuth), "D10 201 without authorization is incomplete and uncertain")
        Check(Not Cl(Fk(201, AuthorizeOfficial("CREATED", "12.34", "EUR", count:=2))).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Success, "D11 two authorizations refused")
        Check(Not Cl(Fk(201, AuthorizeOfficial("CREATED", "0.00", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Success, "D12 authorization with zero amount refused")
        fake = New FakeTransport()
        Check(Not Cl(fake).AuthorizeOrder("x", "PP-AUTH-1-77").Success AndAlso Cl(fake).AuthorizeOrder("x", "PP-AUTH-1-77").NotSent AndAlso fake.Requests.Count = 0, "D13 invalid order id: no request, NotSent")
        Dim otherOrder As PayPalOrdersV2Result = Cl(Fk(201, AuthorizeOfficial("CREATED", "12.34", "EUR").Replace("""id"":""" & OrderId & """,""payment_source""", """id"":""OTHER-ORDER-1"",""payment_source"""))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not otherOrder.Success AndAlso otherOrder.ErrorCode = "ORDER_ID_MISMATCH" AndAlso otherOrder.Snapshot.AuthorizationCount = 1 AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(otherOrder), "D14 a valid authorize response for ANOTHER order id is refused")
        Check(PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, OrderId, Cl(Fk(201, AuthorizeOfficial("CREATED", "12.34", "EUR").Replace("KS-A-1-77", "KS-A-1-78"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Snapshot) = "REFERENCE_ID", "D15 authorize response with another reference id refused")
        Check(PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, OrderId, Cl(Fk(201, AuthorizeOfficial("CREATED", "99.00", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Snapshot) = "AUTHORIZATION_AMOUNT", "D16 authorize response with another amount refused")
        Dim withStatus As String = AuthorizeOfficial("CREATED", "12.34", "EUR").Replace("""id"":""" & OrderId & """,""payment_source""", """id"":""" & OrderId & """,""status"":""COMPLETED"",""payment_source""")
        Dim withBadStatus As String = withStatus.Replace("""status"":""COMPLETED"",""payment_source""", """status"":""CREATED"",""payment_source""")
        Check(PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, OrderId, Cl(Fk(201, withStatus)).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Snapshot) = "" AndAlso PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, OrderId, Cl(Fk(201, withBadStatus)).AuthorizeOrder(OrderId, "PP-AUTH-1-77").Snapshot) = "STATE", "D17 order status, when present, must be COMPLETED")
        Dim pending As PayPalOrdersV2Result = Cl(Fk(201, AuthorizeOfficial("PENDING", "12.34", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Dim denied As PayPalOrdersV2Result = Cl(Fk(201, AuthorizeOfficial("DENIED", "12.34", "EUR"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(pending.Success AndAlso denied.Success AndAlso Not PayPalOrdersV2Client.IsAuthorizationCapturable(pending.Snapshot.Authorization, nowUtc) AndAlso Not PayPalOrdersV2Client.IsAuthorizationCapturable(denied.Snapshot.Authorization, nowUtc), "D18 PENDING and DENIED authorizations are call-level successes but never capturable")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "ORDER_ALREADY_AUTHORIZED"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")), "D19 422 ORDER_ALREADY_AUTHORIZED means the effect happened: uncertain (read it back)")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "PAYMENT_DENIED"))).AuthorizeOrder(OrderId, "PP-AUTH-1-77")), "D20 422 PAYMENT_DENIED is definitive")
        Dim litAuth As PayPalOrdersV2Result = Cl(Fk(201, LiteralAuthorize())).AuthorizeOrder("5O190127TN364715T", "PP-AUTH-1-77")
        Check(litAuth.Success AndAlso litAuth.Snapshot.Status = String.Empty AndAlso litAuth.Snapshot.Authorization.Id = "0AW2184448108334S" AndAlso litAuth.Snapshot.Authorization.Status = "CREATED" AndAlso litAuth.Snapshot.Authorization.Amount = 100D AndAlso litAuth.Snapshot.Authorization.Currency = "USD" AndAlso litAuth.Snapshot.Authorization.ExpirationTime = "2018-05-01T21:20:49Z", "D21 LITERAL official authorize example parsed (no order status, USD 100.00)")
        Check(PayPalOrdersV2Client.CheckAuthorizeResponse(att1, cfg1, "5O190127TN364715T", litAuth.Snapshot) = "REFERENCE_ID", "D22 the literal example belongs to another attempt: its reference id is refused")

        ' ---- E. autorizzazione ----
        Dim goodAuth As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        Check(PayPalOrdersV2Client.IsAuthorizationCapturable(goodAuth, nowUtc), "E01 CREATED and not expired is capturable")
        For Each st As String In New String() {"PENDING", "DENIED", "VOIDED", "CAPTURED", "PARTIALLY_CAPTURED", "EXPIRED", ""}
            Check(Not PayPalOrdersV2Client.IsAuthorizationCapturable(AuthSnap(AuthorizationGetJson(st, "12.34", "EUR")), nowUtc), "E02 status '" & st & "' is not capturable")
        Next
        Check(Not PayPalOrdersV2Client.IsAuthorizationCapturable(Nothing, nowUtc), "E03 null authorization is not capturable")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, goodAuth, AuthId, True) = "" AndAlso goodAuth.PayeeEmail = "tenant-1@example.invalid" AndAlso goodAuth.MerchantId = "MERCHANT-SHARED" AndAlso goodAuth.InvoiceId = "KS-AINV-1-77", "E04 GET authorization accepted in strict mode and parsed")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(AuthorizationGetJson("CREATED", "12.35", "EUR")), "", True) = "AMOUNT", "E05 authorization amount mismatch refused")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(AuthorizationGetJson("CREATED", "12.34", "USD")), "", True) = "CURRENCY", "E06 authorization currency mismatch refused")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR", "KS-AINV-1-78")), "", False) = "INVOICE_ID", "E07 present invoice id that differs is refused")
        Dim noInvoice As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR", ""))
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, noInvoice, "", False) = "" AndAlso PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, noInvoice, "", True) = "INVOICE_ID", "E08 absent invoice id: tolerated on the authorize response, required on GET")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, Cfg(2), goodAuth, "", False) = "TENANT", "E09 other tenant config refused")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, Nothing, "", False) = "INPUT", "E10 null authorization refused")
        Dim otherPayee As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        otherPayee.PayeeEmail = "tenant-2@example.invalid"
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, otherPayee, "", False) = "PAYEE", "E11 present payee of another tenant refused")
        Dim otherCustom As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        otherCustom.CustomId = "KS-ATT-1-78"
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, otherCustom, "", False) = "CUSTOM_ID", "E12 present custom id that differs is refused")
        Dim badId As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        badId.Id = "x"
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, badId, "", False) = "AUTHORIZATION_ID", "E13 invalid authorization id refused")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, goodAuth, "OTHER-AUTH-1", True) = "AUTHORIZATION_ID", "E14 an authorization with the same amount but another id than the validated one is refused")
        Dim expiredAuth As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        expiredAuth.ExpirationTime = "2026-11-16T20:00:00Z"
        Check(Not PayPalOrdersV2Client.IsAuthorizationCapturable(expiredAuth, nowUtc), "E15 CREATED but already expired is not capturable")
        Dim garbageExp As PayPalAuthorizationSnapshot = AuthSnap(AuthorizationGetJson("CREATED", "12.34", "EUR"))
        garbageExp.ExpirationTime = "not-a-date"
        Check(Not PayPalOrdersV2Client.IsAuthorizationCapturable(garbageExp, nowUtc) AndAlso PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, garbageExp, "", True) = "EXPIRATION", "E16 present but unreadable expiration: refused and not capturable")
        Dim emptyAmount As String = AuthorizationGetJson("CREATED", "12.34", "EUR").Replace("""amount"":{""value"":""12.34"",""currency_code"":""EUR""}", """amount"":{}")
        Check(emptyAmount.Contains("""amount"":{}") AndAlso PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(emptyAmount), "", True) = "AMOUNT", "E17 present but empty amount refused")
        Check(PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(AuthorizationGetJson("WEIRD", "12.34", "EUR")), "", True) = "STATUS", "E18 unknown status refused")
        Dim noPayee As String = AuthorizationGetJson("CREATED", "12.34", "EUR").Replace("""payee"":{""email_address"":""tenant-1@example.invalid"",""merchant_id"":""MERCHANT-SHARED""},", "")
        Check(Not noPayee.Contains("payee") AndAlso PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(noPayee), "", True) = "PAYEE" AndAlso PayPalOrdersV2Client.CheckAuthorizationSnapshot(att1, cfg1, AuthSnap(noPayee), "", False) = "", "E19 absent payee: required on GET, tolerated on the authorize response")
        Dim litGet As PayPalAuthorizationSnapshot = AuthSnap(LiteralGetAuthorization())
        Check(litGet.Id = "0VF52814937998046" AndAlso litGet.Status = "CREATED" AndAlso litGet.Amount = 10.99D AndAlso litGet.Currency = "USD" AndAlso litGet.InvoiceId = "INVOICE-123" AndAlso litGet.PayeeEmail = "merchant@example.com" AndAlso litGet.MerchantId = "7KNGBPH2U58GQ", "E20 LITERAL official GET authorization example parsed")
        Check(Not PayPalOrdersV2Client.IsAuthorizationCapturable(litGet, nowUtc) AndAlso PayPalOrdersV2Client.IsAuthorizationCapturable(litGet, New DateTime(2017, 9, 12, 0, 0, 0, DateTimeKind.Utc)), "E21 the literal example is capturable only before its 2017 expiration")

        ' ---- F. GET autorizzazione ----
        fake = Fk(200, AuthorizationGetJson("CREATED", "12.34", "EUR"))
        Dim getAuth As PayPalPaymentsResult = Cl(fake).GetAuthorization(AuthId)
        Check(getAuth.Success AndAlso fake.Requests(1).Method = "GET" AndAlso fake.Requests(1).Url.EndsWith("/v2/payments/authorizations/" & AuthId) AndAlso fake.Requests(1).Body = String.Empty, "F01 GET authorization route")
        fake = New FakeTransport()
        Check(Not Cl(fake).GetAuthorization("../x").Success AndAlso Cl(fake).GetAuthorization("../x").NotSent AndAlso fake.Requests.Count = 0, "F02 invalid authorization id: no request, NotSent")
        Dim notFound As PayPalPaymentsResult = Cl(Fk(404, ErrorJson("RESOURCE_NOT_FOUND", ""))).GetAuthorization(AuthId)
        Check(Not notFound.Success AndAlso notFound.ErrorCode = "RESOURCE_NOT_FOUND" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(notFound), "F03 404 is definitive")
        Dim otherAuthBody As String = AuthorizationGetJson("CREATED", "12.34", "EUR").Replace(AuthId, "0OTHERAUTH12345")
        Dim otherAuth As PayPalPaymentsResult = Cl(Fk(200, otherAuthBody)).GetAuthorization(AuthId)
        Check(Not otherAuth.Success AndAlso otherAuth.ErrorCode = "AUTHORIZATION_ID_MISMATCH", "F04 GET answering for another authorization id is refused")
        Check(Cl(Fk(200, LiteralGetAuthorization())).GetAuthorization("0VF52814937998046").Success, "F05 LITERAL official GET authorization example accepted")

        ' ---- G. incasso dell'autorizzazione ----
        fake = Fk(201, CaptureFull("COMPLETED", "12.34", "EUR"))
        Dim cap As PayPalPaymentsResult = Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "KS-INV-1-169277")
        Check(cap.Success AndAlso cap.Capture.Id = CaptureId AndAlso cap.Capture.Status = "COMPLETED" AndAlso cap.Capture.Amount = 12.34D AndAlso cap.Capture.FinalCapturePresent AndAlso cap.Capture.FinalCapture AndAlso cap.Capture.UpAuthorizationId = AuthId, "G01 full capture response parsed (amount, final_capture, up link)")
        Check(fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/v2/payments/authorizations/" & AuthId & "/capture"), "G02 capture route")
        Check(fake.Requests(1).RequestId = "PP-CAP-1-77" AndAlso fake.Requests(1).Prefer = "return=representation", "G03 capture headers")
        Dim cb As IDictionary(Of String, Object) = Dict(fake.Requests(1).Body)
        Dim cbAmount As IDictionary(Of String, Object) = DirectCast(cb("amount"), IDictionary(Of String, Object))
        Check(Convert.ToBoolean(cb("final_capture")) = True AndAlso Convert.ToString(cbAmount("value")) = "12.34" AndAlso Convert.ToString(cbAmount("currency_code")) = "EUR" AndAlso Convert.ToString(cb("invoice_id")) = "KS-INV-1-169277", "G04 capture body: final capture, explicit amount, real invoice id")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, cap.Capture) = "", "G05 capture accepted")
        fake = Fk(201, CaptureMinimal("COMPLETED"))
        Dim capMin As PayPalPaymentsResult = Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")
        Dim cb2 As IDictionary(Of String, Object) = Dict(fake.Requests(1).Body)
        Check(capMin.Success AndAlso capMin.Capture.Status = "COMPLETED" AndAlso Not cb2.ContainsKey("invoice_id") AndAlso Convert.ToBoolean(cb2("final_capture")), "G06 minimal capture response accepted; empty invoice id omitted from the body")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "", AuthId, capMin.Capture) = "", "G07 minimal capture passes the validator (amount, invoice and up link absent)")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(CaptureFull("COMPLETED", "12.35", "EUR"))) = "AMOUNT", "G08 capture amount mismatch refused")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(CaptureFull("COMPLETED", "12.34", "USD"))) = "CURRENCY", "G09 capture currency mismatch refused")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(CaptureFull("COMPLETED", "12.34", "EUR", "KS-INV-1-1"))) = "INVOICE_ID", "G10 present capture invoice id that differs is refused")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(CaptureFull("COMPLETED", "12.34", "EUR", "KS-INV-1-169277", "false"))) = "FINAL_CAPTURE", "G11 present final_capture=false refused")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(CaptureFull("COMPLETED", "12.34", "EUR", "KS-INV-1-169277", ""))) = "", "G12 absent final_capture tolerated")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "", AuthId, CapSnap(CaptureFull("WEIRD", "12.34", "EUR", ""))) = "STATUS", "G13 unknown capture status refused")
        For Each st As String In New String() {"COMPLETED", "PENDING", "DECLINED", "FAILED", "DENIED", "REFUNDED", "PARTIALLY_REFUNDED"}
            Dim snap As PayPalCaptureSnapshot = CapSnap(CaptureFull(st, "12.34", "EUR", ""))
            Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "", AuthId, snap) = "" AndAlso (PayPalOrdersV2Client.IsCaptureCompleted(snap) = (st = "COMPLETED")), "G14 capture status " & st & " is recognized, and only COMPLETED counts as paid")
        Next
        Check(Not PayPalOrdersV2Client.IsCaptureCompleted(Nothing), "G15 null capture is not paid")
        Dim expired As PayPalPaymentsResult = Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "AUTHORIZATION_EXPIRED"))).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")
        Check(Not expired.Success AndAlso expired.ErrorCode = "UNPROCCESSABLE_ENTITY:AUTHORIZATION_EXPIRED" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(expired), "G16 expired authorization is a definitive refusal")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(409, ErrorJson("RESOURCE_CONFLICT", "PREVIOUS_REQUEST_IN_PROGRESS"))).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")), "G17 409 previous request in progress is uncertain")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(0, String.Empty)).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")), "G18 lost capture response is uncertain")
        Dim noCapId As PayPalPaymentsResult = Cl(Fk(201, J("{'status':'COMPLETED'}"))).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")
        Check(Not noCapId.Success AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(noCapId), "G19 201 without capture id is incomplete and uncertain")
        Dim emptyJson As PayPalPaymentsResult = Cl(Fk(201, "{}")).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")
        Check(Not emptyJson.Success AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(emptyJson), "G20 201 with an empty JSON object is incomplete and uncertain")
        fake = New FakeTransport()
        Check(Cl(fake).CaptureAuthorization("x", "PP-CAP-1-77", 12.34D, "EUR", "").NotSent AndAlso Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 0D, "EUR", "").NotSent AndAlso Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "", "").NotSent AndAlso Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "bad invoice with spaces").NotSent AndAlso fake.Requests.Count = 0, "G21 invalid id, amount, currency or invoice id: no request, NotSent")
        fake = Fk(201, CaptureFull("COMPLETED", "12.35", "EUR"))
        Call Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.345D, "EUR", "")
        Check(Convert.ToString(DirectCast(Dict(fake.Requests(1).Body)("amount"), IDictionary(Of String, Object))("value")) = "12.35", "G22 amount rounded half-up to the cent in the body")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", "OTHER-AUTH-1", cap.Capture) = "AUTHORIZATION_ID", "G23 capture whose up link points to another authorization refused")
        Dim emptyCapAmount As String = CaptureFull("COMPLETED", "12.34", "EUR").Replace("""amount"":{""value"":""12.34"",""currency_code"":""EUR""}", """amount"":{}")
        Check(emptyCapAmount.Contains("""amount"":{}") AndAlso PayPalOrdersV2Client.CheckCaptureSnapshot(12.34D, "EUR", "KS-INV-1-169277", AuthId, CapSnap(emptyCapAmount)) = "AMOUNT", "G24 present but empty capture amount refused")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "DUPLICATE_INVOICE_ID"))).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "KS-INV-1-169277")), "G25 DUPLICATE_INVOICE_ID may mean the capture already happened: uncertain")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "MAX_CAPTURE_AMOUNT_EXCEEDED"))).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")), "G26 MAX_CAPTURE_AMOUNT_EXCEEDED is definitive")
        Dim litCap As PayPalCaptureSnapshot = CapSnap(LiteralCapture())
        Check(litCap.Id = "2GG279541U471931P" AndAlso litCap.Status = "COMPLETED" AndAlso litCap.Amount = 10.99D AndAlso litCap.Currency = "USD" AndAlso litCap.FinalCapture AndAlso litCap.InvoiceId = "INV-123" AndAlso litCap.UpAuthorizationId = "0VF52814937998046", "G27 LITERAL official capture example parsed")
        Check(PayPalOrdersV2Client.CheckCaptureSnapshot(10.99D, "USD", "INV-123", "0VF52814937998046", litCap) = "" AndAlso PayPalOrdersV2Client.CheckCaptureSnapshot(10.99D, "USD", "INV-123", AuthId, litCap) = "AUTHORIZATION_ID", "G28 literal capture example validated against its own authorization and refused against another")

        ' ---- H. annullo ----
        fake = New FakeTransport()
        fake.Add(200, OAuth()) : fake.Add(204, String.Empty)
        Dim voided As PayPalPaymentsResult = Cl(fake).VoidAuthorization(AuthId, "PP-VOID-1-77")
        Check(voided.Success AndAlso voided.StatusCode = 204, "H01 void 204 accepted")
        Check(fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/v2/payments/authorizations/" & AuthId & "/void") AndAlso fake.Requests(1).RequestId = "PP-VOID-1-77" AndAlso fake.Requests(1).Prefer = "return=representation" AndAlso String.IsNullOrEmpty(fake.Requests(1).Body), "H02 void route, request id, Prefer and no body")
        Check(Cl(Fk(200, AuthorizationGetJson("VOIDED", "12.34", "EUR"))).VoidAuthorization(AuthId, "PP-VOID-1-77").Success, "H03 void 200 with VOIDED and the expected id accepted")
        Dim voidCreated As PayPalPaymentsResult = Cl(Fk(200, AuthorizationGetJson("CREATED", "12.34", "EUR"))).VoidAuthorization(AuthId, "PP-VOID-1-77")
        Check(Not voidCreated.Success AndAlso voidCreated.ErrorCode = "VOID_REPRESENTATION_MISMATCH" AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(voidCreated), "H04 void 200 whose body says CREATED is not a success and is uncertain")
        Dim voidOther As PayPalPaymentsResult = Cl(Fk(200, AuthorizationGetJson("VOIDED", "12.34", "EUR").Replace(AuthId, "0OTHERAUTH12345"))).VoidAuthorization(AuthId, "PP-VOID-1-77")
        Check(Not voidOther.Success AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(voidOther), "H05 void 200 for another authorization id is not a success")
        Dim voidCaptured As PayPalPaymentsResult = Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "PREVIOUSLY_CAPTURED"))).VoidAuthorization(AuthId, "PP-VOID-1-77")
        Check(Not voidCaptured.Success AndAlso voidCaptured.ErrorCode = "UNPROCCESSABLE_ENTITY:PREVIOUSLY_CAPTURED" AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(voidCaptured), "H06 void refused because already captured: the issue is kept and the state must be read back")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(0, String.Empty)).VoidAuthorization(AuthId, "PP-VOID-1-77")), "H07 lost void response is uncertain")
        fake = New FakeTransport()
        Check(Cl(fake).VoidAuthorization("x", "PP-VOID-1-77").NotSent AndAlso fake.Requests.Count = 0, "H08 invalid authorization id: no request, NotSent")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(422, ErrorJson("UNPROCCESSABLE_ENTITY", "AUTHORIZATION_EXPIRED"))).VoidAuthorization(AuthId, "PP-VOID-1-77")), "H09 void of an expired authorization is a definitive refusal")

        ' ---- I. classificazione dell'esito incerto ----
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(0, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(202, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(207, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(409, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(500, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(503, False), "I01 0, 202, 207, 409 and 5xx are uncertain")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(400, False) AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(401, False) AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(404, False) AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(422, False), "I02 definitive 4xx are not uncertain")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(200, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(201, False) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(204, False), "I03 an HTTP success whose representation is incomplete is uncertain")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(201, True) AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(0, True), "I04 a success is never uncertain")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(DirectCast(Nothing, PayPalOrdersV2Result)) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(DirectCast(Nothing, PayPalPaymentsResult)), "I05 a missing result is uncertain")
        Check(PayPalOrdersV2Client.IsStateConflictCode("UNPROCCESSABLE_ENTITY:PREVIOUSLY_CAPTURED") AndAlso PayPalOrdersV2Client.IsStateConflictCode("RESOURCE_CONFLICT:PREVIOUS_REQUEST_IN_PROGRESS") AndAlso PayPalOrdersV2Client.IsStateConflictCode("X:ORDER_ALREADY_CAPTURED") AndAlso Not PayPalOrdersV2Client.IsStateConflictCode("UNPROCCESSABLE_ENTITY:AUTHORIZATION_EXPIRED") AndAlso Not PayPalOrdersV2Client.IsStateConflictCode("") AndAlso Not PayPalOrdersV2Client.IsStateConflictCode(Nothing), "I06 conflict issue set")

        ' ---- N. fallimenti locali e OAuth: nessuna chiamata finanziaria partita ----
        fake = New FakeTransport()
        fake.Add(401, ErrorJson("AUTHENTICATION_FAILURE", ""))
        Dim tokenFail As PayPalOrdersV2Result = Cl(fake).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not tokenFail.Success AndAlso tokenFail.NotSent AndAlso tokenFail.StatusCode = 401 AndAlso tokenFail.ErrorCode = "AUTHENTICATION_FAILURE" AndAlso fake.Requests.Count = 1 AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(tokenFail), "N01 OAuth 401: NotSent, status and code kept, not uncertain")
        fake = New FakeTransport()
        fake.Add(0, String.Empty)
        Dim tokenLost As PayPalPaymentsResult = Cl(fake).CaptureAuthorization(AuthId, "PP-CAP-1-77", 12.34D, "EUR", "")
        Check(Not tokenLost.Success AndAlso tokenLost.NotSent AndAlso fake.Requests.Count = 1 AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(tokenLost), "N02 OAuth transport failure: the financial call never left, not uncertain")
        fake = New FakeTransport()
        fake.Add(500, String.Empty)
        Dim existing As PayPalOrdersV2Result = Cl(fake).GetOrder(OrderId)
        Check(Not existing.Success AndAlso existing.StatusCode = 500 AndAlso existing.NotSent AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(existing), "N03 existing path: the OAuth status (even a 5xx) is kept on the failure and the call counts as never sent")
        fake = New FakeTransport()
        fake.Add(0, String.Empty)
        Dim tokenLostOrder As PayPalOrdersV2Result = Cl(fake).AuthorizeOrder(OrderId, "PP-AUTH-1-77")
        Check(Not tokenLostOrder.Success AndAlso tokenLostOrder.NotSent AndAlso tokenLostOrder.StatusCode = 0 AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(tokenLostOrder), "N04 OAuth transport failure on an order call: never sent, not uncertain")

        ' ---- J. il percorso CAPTURE non cambia ----
        Check(New PayPalOrdersV2Client(cfg1, New FakeTransport()).BuildCreateOrderPayload(New PayPalPaymentDocumentInfo With {.DocumentId = 267, .AziendeId = 1, .PagamentiTipoId = 19, .TotalDocument = 12.34D}, "r", "c").Contains("""intent"":""CAPTURE"""), "J01 existing create payload still CAPTURE")

        ' ---- K. trasporto reale su loopback: una POST senza corpo (annullo) deve dichiarare Content-Length: 0 ----
        Dim voidReq As New PayPalHttpRequestData With {.Method = "POST", .Url = "/v2/payments/authorizations/" & AuthId & "/void", .ContentType = "application/json",
            .Authorization = "Bearer fake-access", .RequestId = "PP-VOID-1-77", .Body = String.Empty}
        Dim voidResp As PayPalHttpResponseData = RoundTrip(voidReq, "HTTP/1.1 204 No Content" & vbCrLf & "Connection: close" & vbCrLf & vbCrLf)
        Dim rawVoid As String = _rawRequest
        Check(voidResp.StatusCode = 204 AndAlso String.IsNullOrEmpty(voidResp.Body), "K01 real transport: 204 without body read")
        Check(rawVoid.StartsWith("POST /v2/payments/authorizations/" & AuthId & "/void ", StringComparison.Ordinal), "K02 real transport: void request line")
        Check(rawVoid.IndexOf("Content-Length: 0", StringComparison.OrdinalIgnoreCase) >= 0, "K03 real transport: empty POST declares Content-Length 0")
        Check(rawVoid.IndexOf("PayPal-Request-Id: PP-VOID-1-77", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso rawVoid.IndexOf("Authorization: Bearer fake-access", StringComparison.OrdinalIgnoreCase) >= 0, "K04 real transport: request id and bearer header sent")
        Dim bodyReq As New PayPalHttpRequestData With {.Method = "POST", .Url = "/v2/payments/authorizations/" & AuthId & "/capture", .ContentType = "application/json",
            .Authorization = "Bearer fake-access", .RequestId = "PP-CAP-1-77", .Body = "{""final_capture"":true}"}
        Dim bodyResp As PayPalHttpResponseData = RoundTrip(bodyReq, "HTTP/1.1 201 Created" & vbCrLf & "Content-Type: application/json" & vbCrLf & "Content-Length: 2" & vbCrLf & "Connection: close" & vbCrLf & vbCrLf & "{}")
        Check(bodyResp.StatusCode = 201 AndAlso bodyResp.Body = "{}" AndAlso _rawRequest.IndexOf("Content-Length: 22", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso _rawRequest.EndsWith("{""final_capture"":true}", StringComparison.Ordinal), "K05 real transport: POST with body unchanged")
    End Sub
End Module
