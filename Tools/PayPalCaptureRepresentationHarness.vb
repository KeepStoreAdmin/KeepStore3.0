Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Web.Script.Serialization

' PAYPAL-CAPTURE-REPRESENTATION-1A: il percorso CAPTURE (create, capture, GET di verifica) accetta la rappresentazione documentata da PayPal.
' Transport finto, nessuna rete. Le fixture "Official*" sono gli ESEMPI della specifica OpenAPI pubblica di PayPal (Orders v2), copiati
' letteralmente; le sole sostituzioni sono dichiarate nel test (reference_id e, dove serve, gli id del commerciante). Non sono risposte reali.

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

' ---- Fixture ufficiali (specifica OpenAPI pubblica PayPal, checkout_orders_v2.json): JSON letterale, apice singolo al posto del doppio ----
Module OfficialFixtures
    Private Function J(ByVal s As String) As String
        Return s.Replace("'"c, """"c)
    End Function
    Public Function OfficialCreateSimple() As String
        Return J("{'id':'5O190127TN364715T','links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'},{'href':'https://www.paypal.com/checkoutnow?token=5O190127TN364715T','rel':'approve','method':'GET'},{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'edit','method':'PATCH'},{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T/capture','rel':'capture','method':'POST'}]}")
    End Function
    Public Function OfficialCreatePickup() As String
        Return J("{'id':'4SP74185RW2405200','purchase_units':[{'reference_id':'PUHF','amount':{'currency_code':'USD','value':'50.00'},'payee':{'email_address':'merchant@example.com'},'shipping':{'address':{'address_line_1':'123 Townsend St','address_line_2':'Floor 6','admin_area_2':'San Francisco','admin_area_1':'CA','postal_code':'94107','country_code':'US'},'type':'PICKUP_IN_STORE'}}],'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/4SP74185RW2405200','rel':'self','method':'GET'},{'href':'https://www.paypal.com/checkoutnow?token=4SP74185RW2405200','rel':'approve','method':'GET'},{'href':'https://api-m.paypal.com/v2/checkout/orders/4SP74185RW2405200','rel':'edit','method':'PATCH'},{'href':'https://api-m.paypal.com/v2/checkout/orders/4SP74185RW2405200/authorize','rel':'authorize','method':'POST'}]}")
    End Function
    Public Function OfficialCreatePayerAction() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{}},'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'},{'href':'https://www.paypal.com/checkoutnow?token=5O190127TN364715T','rel':'payer-action','method':'GET'}]}")
    End Function
    Public Function OfficialGet() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','account_id':'QYR5Z8XDVJNXQ'}},'purchase_units':[{'reference_id':'d9f80740-38f0-11e8-b467-0ed5f89f718b','amount':{'currency_code':'USD','value':'100.00'}}],'payer':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','payer_id':'QYR5Z8XDVJNXQ'},'create_time':'2018-04-01T21:18:49Z','links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'},{'href':'https://www.paypal.com/checkoutnow?token=5O190127TN364715T','rel':'approve','method':'GET'},{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'edit','method':'PATCH'},{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T/capture','rel':'capture','method':'POST'}]}")
    End Function
    Public Function OfficialCapture201() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','account_id':'QYR5Z8XDVJNXQ'}},'purchase_units':[{'reference_id':'d9f80740-38f0-11e8-b467-0ed5f89f718b','shipping':{'address':{'address_line_1':'2211 N First Street','address_line_2':'Building 17','admin_area_2':'San Jose','admin_area_1':'CA','postal_code':'95131','country_code':'US'}},'payments':{'captures':[{'id':'3C679366HH908993F','status':'COMPLETED','amount':{'currency_code':'USD','value':'100.00'},'seller_protection':{'status':'ELIGIBLE','dispute_categories':['ITEM_NOT_RECEIVED','UNAUTHORIZED_TRANSACTION']},'final_capture':true,'seller_receivable_breakdown':{'gross_amount':{'currency_code':'USD','value':'100.00'},'paypal_fee':{'currency_code':'USD','value':'3.00'},'net_amount':{'currency_code':'USD','value':'97.00'}},'create_time':'2018-04-01T21:20:49Z','update_time':'2018-04-01T21:20:49Z','links':[{'href':'https://api-m.paypal.com/v2/payments/captures/3C679366HH908993F','rel':'self','method':'GET'},{'href':'https://api-m.paypal.com/v2/payments/captures/3C679366HH908993F/refund','rel':'refund','method':'POST'}]}]}}],'payer':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','payer_id':'QYR5Z8XDVJNXQ'},'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'}]}")
    End Function
    Public Function OfficialCaptureIdempotent200() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','account_id':'QYR5Z8XDVJNXQ','account_status':'VERIFIED'}},'purchase_units':[{'reference_id':'d9f80740-38f0-11e8-b467-0ed5f89f718b','shipping':{'address':{'address_line_1':'2211 N First Street','address_line_2':'Building 17','admin_area_2':'San Jose','admin_area_1':'CA','postal_code':'95131','country_code':'US'}},'payments':{'captures':[{'id':'3C679366HH908993F','status':'COMPLETED','amount':{'currency_code':'USD','value':'100.00'},'seller_protection':{'status':'ELIGIBLE','dispute_categories':['ITEM_NOT_RECEIVED','UNAUTHORIZED_TRANSACTION']},'final_capture':true,'seller_receivable_breakdown':{'gross_amount':{'currency_code':'USD','value':'100.00'},'paypal_fee':{'currency_code':'USD','value':'3.00'},'net_amount':{'currency_code':'USD','value':'97.00'}},'create_time':'2018-04-01T21:20:49Z','update_time':'2018-04-01T21:20:49Z','links':[{'href':'https://api-m.paypal.com/v2/payments/captures/3C679366HH908993F','rel':'self','method':'GET'},{'href':'https://api-m.paypal.com/v2/payments/captures/3C679366HH908993F/refund','rel':'refund','method':'POST'}]}]}}],'payer':{'name':{'given_name':'John','surname':'Doe'},'email_address':'customer@example.com','payer_id':'QYR5Z8XDVJNXQ'},'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'}]}")
    End Function
    Public Function OfficialCaptureVault() As String
        Return J("{'id':'5O190127TN364715T','payment_source':{'paypal':{'attributes':{'vault':{'id':'m6yd4yw','status':'CREATED'}}}},'purchase_units':[{'reference_id':'refernece_id_1001','shipping':{'name':{'full_name':'William Chris'},'address':{'address_line_1':'500 Hillside Street','address_line_2':'#100','admin_area_2':'San Jose','admin_area_1':'CA','postal_code':'95131','country_code':'US'}},'payments':{'captures':[{'id':'54986457XR262021N','status':'COMPLETED','amount':{'currency_code':'USD','value':'31.01'},'final_capture':true,'seller_protection':{'status':'ELIGIBLE','dispute_categories':['ITEM_NOT_RECEIVED','UNAUTHORIZED_TRANSACTION']},'seller_receivable_breakdown':{'gross_amount':{'currency_code':'USD','value':'31.01'},'platform_fees':[{'amount':{'currency_code':'USD','value':'10.01'},'payee':{'merchant_id':'J8NCBBULP5JH2'}}],'net_amount':{'currency_code':'USD','value':'21.00'}},'invoice_id':'invoice_id_380358551C5240203','custom_id':'custom_id_1001','links':[{'href':'https://api-m.paypal.com/v2/payments/captures/54986457XR262021N','rel':'self','method':'GET'},{'href':'https://api-m.paypal.com/v2/payments/captures/54986457XR262021N/refund','rel':'refund','method':'POST'},{'href':'https://api-m.paypal.com/v2/checkout/orders/12645781RH9888226','rel':'up','method':'GET'}],'create_time':'2020-06-08T23:11:34Z','update_time':'2020-06-08T23:11:34Z'}]}}],'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/5O190127TN364715T','rel':'self','method':'GET'},{'href':'https://api-m.paypal.com/v2/vault/payment-tokens/m6yd4yw','rel':'payment-token','method':'GET'}]}")
    End Function
End Module

Module PayPalCaptureRepresentationHarness
    Private _passed As Integer
    Private Const OrderId As String = "5O190127TN364715T"
    Private Const CapId As String = "3C679366HH908993F"
    Private Const OfficialReference As String = "d9f80740-38f0-11e8-b467-0ed5f89f718b"
    Private Const Ref As String = "KS-1-267"
    Private Const Cus As String = "KS-DOC-1-267"
    Private Const Inv As String = "KS-INV-1-267"
    Private Const Payee As String = "merchant@example.com"
    Private Const Merchant As String = "MERCHANT-SHARED"

    Private Sub Check(ByVal condition As Boolean, ByVal name As String)
        If Not condition Then Throw New Exception("PAYPAL_CAPTURE_REPRESENTATION_FAILED: " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function J(ByVal s As String) As String
        Return s.Replace("'"c, """"c)
    End Function

    Private Function Cfg(Optional ByVal company As Integer = 1) As PayPalCheckoutConfig
        Return New PayPalCheckoutConfig With {.AccountId = 9, .CompanyConfigId = company + 100, .AziendeId = company,
            .PagamentiTipoId = 19, .CredentialKey = "PAYPAL_TEST", .MerchantId = Merchant,
            .PayeeEmail = If(company = 1, Payee, "tenant-2@example.invalid"), .BrandName = "TENANT " & company, .CurrencyCode = "USD",
            .ClientId = "client", .ClientSecret = "FAKE-secret", .WebhookId = "webhook", .AccountActive = True, .CompanyActive = True}
    End Function

    Private Function Doc(Optional ByVal total As Decimal = 100D, Optional ByVal company As Integer = 1) As PayPalPaymentDocumentInfo
        Return New PayPalPaymentDocumentInfo With {.DocumentId = 267, .AziendeId = company, .PagamentiTipoId = 19, .TotalDocument = total}
    End Function

    Private Function OAuth() As String
        Return J("{'access_token':'fake-access','token_type':'Bearer'}")
    End Function

    Private Function Fk(ByVal ParamArray steps() As Object) As FakeTransport
        ' steps = coppie (stato, corpo) dopo l'OAuth: Fk(201, body, 200, body2) mette un OAuth davanti a ogni chiamata
        Dim f As New FakeTransport()
        For i As Integer = 0 To steps.Length - 1 Step 2
            f.Add(200, OAuth())
            f.Add(CInt(steps(i)), CStr(steps(i + 1)))
        Next
        Return f
    End Function

    Private Function Cl(ByVal f As FakeTransport, Optional ByVal company As Integer = 1) As PayPalOrdersV2Client
        Return New PayPalOrdersV2Client(Cfg(company), f)
    End Function

    Private Function Sub1(ByVal json As String, ByVal what As String, ByVal replacement As String) As String
        If Not json.Contains(what) Then Throw New Exception("FIXTURE_ANCHOR_MISSING: " & what)
        Return json.Replace(what, replacement)
    End Function

    ' Capture "documentata": come gli esempi ufficiali (reference_id, payments.captures[0]); il resto si aggiunge per parametri.
    Private Function CaptureDoc(Optional ByVal orderId As String = OrderId, Optional ByVal unitExtra As String = "", Optional ByVal capId As String = CapId,
                                Optional ByVal capStatus As String = "COMPLETED", Optional ByVal amount As String = "100.00", Optional ByVal currency As String = "USD",
                                Optional ByVal capExtra As String = "", Optional ByVal captures As Integer = 1, Optional ByVal units As Integer = 1,
                                Optional ByVal reference As String = Ref, Optional ByVal topExtra As String = "", Optional ByVal withCaptureAmount As Boolean = True) As String
        Dim amountJson As String = If(withCaptureAmount, ",'amount':{'currency_code':'" & currency & "','value':'" & amount & "'}", "")
        Dim cap As String = "{'id':'" & capId & "','status':'" & capStatus & "'" & amountJson & ",'final_capture':true" & capExtra & ",'links':[{'href':'https://api-m.paypal.com/v2/payments/captures/" & capId & "','rel':'self','method':'GET'}]}"
        Dim list As String = ""
        For i As Integer = 1 To captures
            If i > 1 Then list &= ","
            list &= cap
        Next
        Dim payments As String = If(captures = 0, "", ",'payments':{'captures':[" & list & "]}")
        Dim unit As String = "{'reference_id':'" & reference & "'" & unitExtra & payments & "}"
        Dim unitList As String = ""
        For i As Integer = 1 To units
            If i > 1 Then unitList &= ","
            unitList &= unit
        Next
        Return J("{'id':'" & orderId & "'" & topExtra & ",'purchase_units':[" & unitList & "],'links':[{'href':'https://api-m.paypal.com/v2/checkout/orders/" & orderId & "','rel':'self','method':'GET'}]}")
    End Function

    ' Ordine completo come lo restituisce un GET: tutti i campi di unita; un parametro vuoto omette il campo.
    Private Function GetFull(Optional ByVal status As String = "COMPLETED", Optional ByVal intent As String = "CAPTURE", Optional ByVal reference As String = Ref,
                             Optional ByVal custom As String = Cus, Optional ByVal invoice As String = Inv, Optional ByVal amount As String = "100.00",
                             Optional ByVal currency As String = "USD", Optional ByVal email As String = Payee, Optional ByVal merchant As String = Merchant,
                             Optional ByVal id As String = OrderId, Optional ByVal capId As String = CapId, Optional ByVal capStatus As String = "COMPLETED",
                             Optional ByVal capAmount As String = "100.00", Optional ByVal capCurrency As String = "USD", Optional ByVal captures As Integer = 1,
                             Optional ByVal units As Integer = 1, Optional ByVal approval As String = "") As String
        Dim parts As New List(Of String)
        If reference <> "" Then parts.Add("'reference_id':'" & reference & "'")
        If custom <> "" Then parts.Add("'custom_id':'" & custom & "'")
        If invoice <> "" Then parts.Add("'invoice_id':'" & invoice & "'")
        If amount <> "" Then parts.Add("'amount':{'currency_code':'" & currency & "','value':'" & amount & "'}")
        Dim payee As String = ""
        If email <> "" Then payee &= "'email_address':'" & email & "'"
        If merchant <> "" Then payee &= If(payee = "", "", ",") & "'merchant_id':'" & merchant & "'"
        If payee <> "" Then parts.Add("'payee':{" & payee & "}")
        If captures > 0 Then
            Dim cap As String = "{'id':'" & capId & "','status':'" & capStatus & "','amount':{'currency_code':'" & capCurrency & "','value':'" & capAmount & "'},'final_capture':true}"
            Dim list As String = ""
            For i As Integer = 1 To captures
                If i > 1 Then list &= ","
                list &= cap
            Next
            parts.Add("'payments':{'captures':[" & list & "]}")
        End If
        Dim unit As String = "{" & String.Join(",", parts.ToArray()) & "}"
        Dim unitList As String = ""
        For i As Integer = 1 To units
            If i > 1 Then unitList &= ","
            unitList &= unit
        Next
        Dim top As String = "{'id':'" & id & "'"
        If intent <> "" Then top &= ",'intent':'" & intent & "'"
        If status <> "" Then top &= ",'status':'" & status & "'"
        Dim links As String = If(approval = "", "[{'rel':'self','href':'https://api-m.paypal.com/v2/checkout/orders/" & id & "'}]",
                                 "[{'rel':'approve','href':'" & approval & "'}]")
        Return J(top & ",'purchase_units':[" & unitList & "],'links':" & links & "}")
    End Function

    Private Function SnapFromGet(ByVal json As String) As PayPalOrderSnapshot
        Return Cl(Fk(200, json)).GetOrder(OrderId).Snapshot
    End Function

    Private Function SnapFromCapture(ByVal json As String) As PayPalOrderSnapshot
        Return Cl(Fk(201, json)).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Snapshot
    End Function

    ' Un fallimento dopo l'addebito non porta MAI uno snapshot utilizzabile da ApplyAuthoritativeState (stato e id vuoti).
    Private Function EmptySnap(ByVal r As PayPalOrdersV2Result) As Boolean
        Return r.Snapshot IsNot Nothing AndAlso r.Snapshot.Status = "" AndAlso r.Snapshot.CaptureStatus = "" AndAlso r.Snapshot.OrderId = "" AndAlso r.Snapshot.CaptureCount = 0 AndAlso r.Snapshot.CaptureId = ""
    End Function

    Private Function Err422(ByVal issue As String) As String
        Return J("{'name':'UNPROCESSABLE_ENTITY','message':'x','debug_id':'abc','details':[{'issue':'" & issue & "'}]}")
    End Function

    ' --- vecchia espressione di ValidateSnapshot / ValidateSnapshotAgainstAttempt (stable 30029c97), trascritta come oracolo di equivalenza ---
    Private Function OldValidateSnapshot(ByVal d As PayPalPaymentDocumentInfo, ByVal c As PayPalCheckoutConfig, ByVal expectedOrderId As String, ByVal s As PayPalOrderSnapshot) As Boolean
        If d Is Nothing OrElse c Is Nothing OrElse s Is Nothing Then Return False
        Return c.AziendeId = d.AziendeId AndAlso c.PagamentiTipoId = d.PagamentiTipoId AndAlso
               s.PurchaseUnitCount = 1 AndAlso s.OrderAmountValid AndAlso
               String.Equals(s.OrderId, expectedOrderId, StringComparison.Ordinal) AndAlso
               String.Equals(s.Intent, "CAPTURE", StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(s.ReferenceId, PayPalOrdersV2Client.ExpectedReferenceId(d), StringComparison.Ordinal) AndAlso
               String.Equals(s.CustomId, PayPalOrdersV2Client.ExpectedCustomId(d), StringComparison.Ordinal) AndAlso
               String.Equals(s.InvoiceId, PayPalOrdersV2Client.ExpectedInvoiceId(d), StringComparison.Ordinal) AndAlso
               s.Amount = Math.Round(d.TotalDocument, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(s.CurrencyCode, c.CurrencyCode, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(s.PayeeEmail, c.PayeeEmail, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(s.MerchantId, c.MerchantId, StringComparison.Ordinal) AndAlso
               s.CaptureCount <= 1 AndAlso
               (s.CaptureCount = 0 AndAlso Not String.Equals(s.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase) OrElse
                PayPalOrdersV2Client.HasMatchingCapture(s, d.TotalDocument, c.CurrencyCode))
    End Function

    Private Function OldValidateAgainstAttempt(ByVal d As PayPalPaymentDocumentInfo, ByVal c As PayPalCheckoutConfig, ByVal expectedOrderId As String, ByVal s As PayPalOrderSnapshot,
                                               ByVal attemptAmount As Decimal, ByVal attemptCurrency As String) As Boolean
        Return OldValidateSnapshot(d, c, expectedOrderId, s) AndAlso
               attemptAmount = Math.Round(d.TotalDocument, 2, MidpointRounding.AwayFromZero) AndAlso
               String.Equals(attemptCurrency, c.CurrencyCode, StringComparison.OrdinalIgnoreCase) AndAlso
               (s.CaptureCount = 0 OrElse PayPalOrdersV2Client.HasMatchingCapture(s, attemptAmount, attemptCurrency))
    End Function

    Function Main() As Integer
        Try
            Run()
            Console.WriteLine("PAYPAL_CAPTURE_REPRESENTATION_TOTAL=" & _passed)
            Return 0
        Catch ex As Exception
            Console.WriteLine("FAIL " & ex.Message)
            Return 1
        End Try
    End Function

    Private Sub Run()
        Dim cfg1 As PayPalCheckoutConfig = Cfg(1)
        Dim doc1 As PayPalPaymentDocumentInfo = Doc()
        Dim fake As FakeTransport

        ' ---- A. CaptureOrder (livello chiamata) con gli ESEMPI UFFICIALI ----
        fake = Fk(201, OfficialFixtures.OfficialCapture201())
        Dim off1 As PayPalOrdersV2Result = Cl(fake).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(off1.Success AndAlso off1.StatusCode = 201 AndAlso off1.Snapshot.CaptureCount = 1 AndAlso off1.Snapshot.CaptureId = CapId, "A01 official capture 201 accepted at call level (no intent, payee, custom_id, invoice_id, unit amount)")
        Check(off1.Snapshot.CaptureStatus = "COMPLETED" AndAlso off1.Snapshot.CaptureAmount = 100D AndAlso off1.Snapshot.CaptureCurrencyCode = "USD" AndAlso off1.Snapshot.CaptureAmountValid, "A02 official capture facts parsed (status, amount, currency)")
        Check(off1.Snapshot.Intent = "" AndAlso off1.Snapshot.PayeeEmail = "" AndAlso off1.Snapshot.CustomId = "" AndAlso off1.Snapshot.InvoiceId = "" AndAlso Not off1.Snapshot.OrderAmountPresent, "A03 the official example really lacks the fields the old code demanded")
        Check(fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/v2/checkout/orders/" & OrderId & "/capture") AndAlso fake.Requests(1).RequestId = "PP-CAPTURE-1-267" AndAlso fake.Requests(1).Prefer = "return=representation" AndAlso fake.Requests(1).Body = "{}", "A04 capture request: route, persisted request id, Prefer representation, empty body")
        Dim off200 As PayPalOrdersV2Result = Cl(Fk(200, OfficialFixtures.OfficialCaptureIdempotent200())).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(off200.Success AndAlso off200.StatusCode = 200 AndAlso off200.Snapshot.CaptureId = CapId, "A05 official idempotent replay 200 accepted")
        Dim vault As PayPalOrdersV2Result = Cl(Fk(201, OfficialFixtures.OfficialCaptureVault())).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(vault.Success AndAlso vault.Snapshot.CaptureAmount = 31.01D AndAlso vault.Snapshot.CaptureInvoiceId = "invoice_id_380358551C5240203" AndAlso vault.Snapshot.CaptureCustomId = "custom_id_1001", "A06 official vault example: capture-level invoice_id and custom_id parsed")
        Dim otherId As PayPalOrdersV2Result = Cl(Fk(201, CaptureDoc(orderId:="OTHER-ORDER-123"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(Not otherId.Success AndAlso otherId.ErrorCode = "ORDER_ID_MISMATCH" AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(otherId), "A07 response for another order id refused and uncertain")
        Dim noCap As PayPalOrdersV2Result = Cl(Fk(201, CaptureDoc(captures:=0))).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(Not noCap.Success AndAlso noCap.ErrorCode = "CAPTURE_REPRESENTATION_INCOMPLETE" AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(noCap), "A08 201 without capture is incomplete and uncertain")
        Check(Not Cl(Fk(201, CaptureDoc(captures:=2))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Success, "A09 two captures refused")
        Check(Not Cl(Fk(201, CaptureDoc(withCaptureAmount:=False))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Success, "A10 capture without amount refused")
        Check(Not Cl(Fk(201, CaptureDoc(capId:="x"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Success, "A11 capture with an invalid id refused")
        Check(Not Cl(Fk(201, CaptureDoc(capStatus:="WEIRD"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Success, "A12 capture with an unknown status refused")
        Check(Not Cl(Fk(201, CaptureDoc(amount:="0.00"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Success, "A13 capture with a zero amount refused")
        Check(Cl(Fk(201, CaptureDoc(capStatus:="PENDING"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Snapshot.CaptureStatus = "PENDING" AndAlso Cl(Fk(201, CaptureDoc(capStatus:="DECLINED"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267").Snapshot.CaptureStatus = "DECLINED", "A14 PENDING and DECLINED captures are returned as such")
        Dim declined As PayPalOrdersV2Result = Cl(Fk(422, Err422("INSTRUMENT_DECLINED"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(Not declined.Success AndAlso declined.ErrorCode = "UNPROCESSABLE_ENTITY:INSTRUMENT_DECLINED" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(declined), "A15 422 keeps the issue in the error code and is definitive")
        Dim already As PayPalOrdersV2Result = Cl(Fk(422, Err422("ORDER_ALREADY_CAPTURED"))).CaptureOrder(OrderId, "PP-CAPTURE-1-267")
        Check(Not already.Success AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(already), "A16 422 ORDER_ALREADY_CAPTURED means the effect happened: uncertain")
        Check(PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(500, "")).CaptureOrder(OrderId, "PP-CAPTURE-1-267")) AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(Cl(Fk(0, "")).CaptureOrder(OrderId, "PP-CAPTURE-1-267")), "A17 500 and a lost response are uncertain")
        fake = New FakeTransport()
        Check(Not Cl(fake).CaptureOrder("x", "PP-CAPTURE-1-267").Success AndAlso Cl(fake).CaptureOrder("x", "PP-CAPTURE-1-267").NotSent AndAlso fake.Requests.Count = 0, "A18 invalid order id: no request, NotSent")

        ' ---- B. CheckCaptureResponse: regola presente-e-diverso => rifiuto, assente => ammesso ----
        Dim okSnap As PayPalOrderSnapshot = SnapFromCapture(CaptureDoc())
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, okSnap, 100D, "USD") = "", "B01 minimal documented capture accepted")
        Dim officialRefReplaced As String = Sub1(OfficialFixtures.OfficialCapture201(), OfficialReference, Ref)
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(officialRefReplaced), 100D, "USD") = "", "B02 official capture 201 (only reference_id replaced) accepted")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(OfficialFixtures.OfficialCapture201()), 100D, "USD") = "REFERENCE_ID", "B03 official capture 201 as is: its reference_id is present and different, refused")
        Dim idemReplaced As String = Sub1(OfficialFixtures.OfficialCaptureIdempotent200(), OfficialReference, Ref)
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(idemReplaced), 100D, "USD") = "", "B04 official idempotent replay (reference_id replaced) accepted")
        Dim vaultReplaced As String = Sub1(Sub1(Sub1(OfficialFixtures.OfficialCaptureVault(), "refernece_id_1001", Ref), "invoice_id_380358551C5240203", Inv), "custom_id_1001", Cus)
        Check(PayPalOrdersV2Client.CheckCaptureResponse(Doc(31.01D), cfg1, OrderId, SnapFromCapture(vaultReplaced), 31.01D, "USD") = "", "B05 official vault example with our ids in the capture accepted")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(Doc(31.01D), cfg1, OrderId, SnapFromCapture(OfficialFixtures.OfficialCaptureVault()), 31.01D, "USD") <> "", "B06 official vault example as is refused (other reference and ids)")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(Doc(31.01D), cfg1, OrderId, SnapFromCapture(Sub1(vaultReplaced, Inv, "KS-INV-1-999")), 31.01D, "USD") = "CAPTURE_INVOICE_ID", "B07 capture-level invoice_id present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(Doc(31.01D), cfg1, OrderId, SnapFromCapture(Sub1(vaultReplaced, Cus, "KS-DOC-1-999")), 31.01D, "USD") = "CAPTURE_CUSTOM_ID", "B08 capture-level custom_id present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'custom_id':'" & Cus & "','invoice_id':'" & Inv & "','payee':{'email_address':'" & Payee & "','merchant_id':'" & Merchant & "'},'amount':{'currency_code':'USD','value':'100.00'}", topExtra:=",'intent':'CAPTURE'")), 100D, "USD") = "", "B09 full representation (every unit field present and equal) accepted")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(topExtra:=",'intent':'AUTHORIZE'")), 100D, "USD") = "INTENT", "B10 intent present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(reference:="KS-1-268")), 100D, "USD") = "REFERENCE_ID", "B11 reference_id of another document refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'custom_id':'KS-DOC-1-268'")), 100D, "USD") = "CUSTOM_ID", "B12 unit custom_id present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'invoice_id':'KS-INV-1-268'")), 100D, "USD") = "INVOICE_ID", "B13 unit invoice_id present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'amount':{'currency_code':'USD','value':'99.00'}")), 100D, "USD") = "AMOUNT", "B14 unit amount present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'amount':{'currency_code':'EUR','value':'100.00'}")), 100D, "USD") = "CURRENCY", "B15 unit currency present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'amount':{}")), 100D, "USD") = "AMOUNT", "B16 unit amount present but empty refused (presence is not validity)")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'payee':{'email_address':'other@example.invalid'}")), 100D, "USD") = "PAYEE", "B17 payee email present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'payee':{'email_address':'MERCHANT@EXAMPLE.COM'}")), 100D, "USD") = "", "B18 payee email compared ignoring case")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'payee':{'merchant_id':'OTHER-MERCHANT'}")), 100D, "USD") = "MERCHANT", "B19 merchant id present and different refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(unitExtra:=",'payee':{'email_address':'','merchant_id':''}")), 100D, "USD") = "", "B20 empty strings are the same as absent (documented tolerance, verified later by the strict GET)")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(units:=2)), 100D, "USD") = "UNIT_COUNT", "B21 two purchase units refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(captures:=2)), 100D, "USD") = "CAPTURE_COUNT", "B22 two captures refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(captures:=0)), 100D, "USD") = "CAPTURE_COUNT", "B23 no capture refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(capId:="x")), 100D, "USD") = "CAPTURE_ID", "B24 invalid capture id refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(capStatus:="WEIRD")), 100D, "USD") = "CAPTURE_STATUS", "B25 unknown capture status refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(amount:="99.99")), 100D, "USD") = "CAPTURE_AMOUNT", "B26 captured amount different from the attempt refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(withCaptureAmount:=False)), 100D, "USD") = "CAPTURE_AMOUNT", "B27 captured amount missing refused (the capture amount is the one fact that must be there)")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, SnapFromCapture(CaptureDoc(currency:="EUR")), 100D, "USD") = "CAPTURE_CURRENCY", "B28 captured currency different from the configured one refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, "OTHER-ORDER-123", okSnap, 100D, "USD") = "ORDER_ID", "B29 order id different from the expected one refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, Cfg(2), OrderId, okSnap, 100D, "USD") = "TENANT", "B30 config of another tenant refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, okSnap, 99D, "USD") = "ATTEMPT_AMOUNT", "B31 attempt amount different from the document total refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, okSnap, 100D, "EUR") = "ATTEMPT_CURRENCY", "B32 attempt currency different from the configured one refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(doc1, cfg1, OrderId, Nothing, 100D, "USD") = "INPUT" AndAlso PayPalOrdersV2Client.CheckCaptureResponse(Nothing, cfg1, OrderId, okSnap, 100D, "USD") = "INPUT" AndAlso PayPalOrdersV2Client.CheckCaptureResponse(doc1, Nothing, OrderId, okSnap, 100D, "USD") = "INPUT", "B33 missing input refused")
        Check(PayPalOrdersV2Client.CheckCaptureResponse(Doc(100.004D), cfg1, OrderId, okSnap, 100D, "USD") = "", "B34 amounts are compared at the cent (half up), like the strict validator")

        ' ---- C. CaptureOrderVerified: cattura + controllo + GET stretto ----
        Dim full As String = GetFull()
        fake = Fk(201, OfficialFixtures.OfficialCapture201().Replace(OfficialReference, Ref), 200, full)
        Dim v1 As PayPalOrdersV2Result = Cl(fake).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
        Check(v1.Success AndAlso v1.Snapshot.CaptureId = CapId AndAlso v1.Snapshot.Intent = "CAPTURE" AndAlso v1.Snapshot.PayeeEmail = Payee, "C01 official minimal capture response then a coherent GET: success, snapshot is the GET")
        Check(fake.Requests.Count = 4 AndAlso fake.Requests(0).Url.EndsWith("/v1/oauth2/token") AndAlso fake.Requests(1).Method = "POST" AndAlso fake.Requests(1).Url.EndsWith("/capture") AndAlso fake.Requests(2).Url.EndsWith("/v1/oauth2/token") AndAlso fake.Requests(3).Method = "GET" AndAlso fake.Requests(3).Url.EndsWith("/v2/checkout/orders/" & OrderId), "C02 sequence: token, POST capture, token, GET order")
        Check(fake.Requests(1).RequestId = "PP-CAPTURE-1-267" AndAlso fake.Requests(1).Prefer = "return=representation" AndAlso fake.Requests(3).RequestId = "", "C03 the capture keeps the persisted request id; the GET has none")
        Check(PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc1, cfg1, OrderId, v1.Snapshot, 100D, "USD"), "C04 the returned snapshot passes the strict validator (what ApplyAuthoritativeState will use)")
        Check(Not PayPalOrdersV2Client.IsOutcomeUncertain(v1), "C05 a success is never uncertain")
        ' fallimenti dopo l'addebito: sempre non riusciti, incerti, mai NotSent
        Dim cases As New List(Of Object())
        cases.Add(New Object() {"C10 capture response with another capture amount", CType(CaptureDoc(amount:="99.00"), Object), CType(full, Object), "CAPTURE_RESPONSE_CAPTURE_AMOUNT"})
        cases.Add(New Object() {"C11 capture response with a different payee", CaptureDoc(unitExtra:=",'payee':{'email_address':'other@example.invalid'}"), full, "CAPTURE_RESPONSE_PAYEE"})
        cases.Add(New Object() {"C12 capture response with another reference_id", CaptureDoc(reference:="KS-1-268"), full, "CAPTURE_RESPONSE_REFERENCE_ID"})
        cases.Add(New Object() {"C13 GET with a different payee", CaptureDoc(), GetFull(email:="other@example.invalid"), "CAPTURE_READBACK_PAYEE"})
        cases.Add(New Object() {"C14 GET with a different merchant", CaptureDoc(), GetFull(merchant:="OTHER"), "CAPTURE_READBACK_MERCHANT"})
        cases.Add(New Object() {"C15 GET with a different custom_id", CaptureDoc(), GetFull(custom:="KS-DOC-1-999"), "CAPTURE_READBACK_CUSTOM_ID"})
        cases.Add(New Object() {"C16 GET with a different invoice_id", CaptureDoc(), GetFull(invoice:="KS-INV-1-999"), "CAPTURE_READBACK_INVOICE_ID"})
        cases.Add(New Object() {"C17 GET with a different order amount", CaptureDoc(), GetFull(amount:="99.00"), "CAPTURE_READBACK_AMOUNT"})
        cases.Add(New Object() {"C18 GET with a different intent", CaptureDoc(), GetFull(intent:="AUTHORIZE"), "CAPTURE_READBACK_INTENT"})
        cases.Add(New Object() {"C19 GET without intent (strict: absent refused)", CaptureDoc(), GetFull(intent:=""), "CAPTURE_READBACK_INTENT"})
        cases.Add(New Object() {"C20 GET without payee (strict: absent refused)", CaptureDoc(), GetFull(email:="", merchant:=""), "CAPTURE_READBACK_PAYEE"})
        cases.Add(New Object() {"C21 GET without the capture", CaptureDoc(), GetFull(captures:=0, status:="APPROVED"), "CAPTURE_READBACK_CAPTURE_COUNT"})
        cases.Add(New Object() {"C22 GET with another capture id", CaptureDoc(), GetFull(capId:="9ZZ279541U471931P"), "CAPTURE_READBACK_CAPTURE_ID"})
        cases.Add(New Object() {"C23 GET with a different captured amount", CaptureDoc(), GetFull(capAmount:="99.00"), "CAPTURE_READBACK_CAPTURE"})
        cases.Add(New Object() {"C24 GET with two captures", CaptureDoc(), GetFull(captures:=2), "CAPTURE_READBACK_CAPTURE_COUNT"})
        cases.Add(New Object() {"C25 GET with two purchase units", CaptureDoc(), GetFull(units:=2), "CAPTURE_READBACK_UNIT_COUNT"})
        cases.Add(New Object() {"C26 GET for another order id", CaptureDoc(), GetFull(id:="OTHER-ORDER-123"), "CAPTURE_READBACK_ORDER_ID"})
        cases.Add(New Object() {"C27 capture response for another order id", CaptureDoc(orderId:="OTHER-ORDER-123"), full, "ORDER_ID_MISMATCH"})
        cases.Add(New Object() {"C28 capture response without a capture", CaptureDoc(captures:=0), full, "CAPTURE_REPRESENTATION_INCOMPLETE"})
        For Each c As Object() In cases
            fake = Fk(201, CStr(c(1)), 200, CStr(c(2)))
            Dim r As PayPalOrdersV2Result = Cl(fake).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
            Check(Not r.Success AndAlso r.ErrorCode = CStr(c(3)) AndAlso r.StatusCode = 201 AndAlso Not r.NotSent AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(r) AndAlso EmptySnap(r), CStr(c(0)) & " -> " & CStr(c(3)) & ", uncertain, status of the capture kept")
        Next
        For Each g As Integer In New Integer() {0, 404, 500}
            fake = Fk(201, CaptureDoc(), g, "")
            Dim r As PayPalOrdersV2Result = Cl(fake).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
            Check(Not r.Success AndAlso r.ErrorCode = "CAPTURE_READBACK_GET_" & g AndAlso r.StatusCode = 201 AndAlso Not r.NotSent AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(r) AndAlso EmptySnap(r), "C30 GET failing with " & g & " after the capture: not a success, uncertain, status in the code, empty snapshot")
        Next
        fake = New FakeTransport()
        fake.Add(200, OAuth()) : fake.Add(201, CaptureDoc()) : fake.Add(401, J("{'name':'AUTHENTICATION_FAILURE'}"))
        Dim tokenLostAfter As PayPalOrdersV2Result = Cl(fake).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
        Check(Not tokenLostAfter.Success AndAlso Not tokenLostAfter.NotSent AndAlso PayPalOrdersV2Client.IsOutcomeUncertain(tokenLostAfter), "C31 OAuth failing for the GET after the capture is still uncertain (the money moved), never NotSent")
        fake = Fk(422, Err422("INSTRUMENT_DECLINED"))
        Dim refused As PayPalOrdersV2Result = Cl(fake).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
        Check(Not refused.Success AndAlso refused.ErrorCode = "UNPROCESSABLE_ENTITY:INSTRUMENT_DECLINED" AndAlso Not PayPalOrdersV2Client.IsOutcomeUncertain(refused) AndAlso fake.Requests.Count = 2, "C32 a refused capture stops there: definitive, no GET")
        fake = New FakeTransport()
        Check(Not Cl(fake).CaptureOrderVerified(Nothing, OrderId, "PP-CAPTURE-1-267", 100D, "USD").Success AndAlso Cl(fake).CaptureOrderVerified(Nothing, OrderId, "PP-CAPTURE-1-267", 100D, "USD").NotSent AndAlso fake.Requests.Count = 0, "C33 no document: no request, NotSent")
        Check(Cl(fake).CaptureOrderVerified(doc1, "x", "PP-CAPTURE-1-267", 100D, "USD").NotSent AndAlso fake.Requests.Count = 0, "C34 invalid order id: no request, NotSent")
        Dim tenantFake As FakeTransport = Fk(201, CaptureDoc(), 200, full)
        Dim wrongTenant As PayPalOrdersV2Result = Cl(tenantFake, 2).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
        Check(Not wrongTenant.Success AndAlso wrongTenant.NotSent AndAlso tenantFake.Requests.Count = 0, "C35 document of another tenant than the config: refused before any request (a full valid sequence was ready)")
        Dim pend As New FakeTransport()
        pend.Add(200, OAuth()) : pend.Add(201, CaptureDoc(capStatus:="PENDING")) : pend.Add(200, OAuth()) : pend.Add(200, GetFull(capStatus:="PENDING"))
        Dim pendR As PayPalOrdersV2Result = Cl(pend).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD")
        Check(pendR.Success AndAlso pendR.Snapshot.CaptureStatus = "PENDING" AndAlso Not PayPalOrdersV2Client.IsCaptureCompleted(New PayPalCaptureSnapshot With {.Status = pendR.Snapshot.CaptureStatus}), "C36 PENDING capture verified, still not a completed payment")
        Dim declinedFlow As New FakeTransport()
        declinedFlow.Add(200, OAuth()) : declinedFlow.Add(201, CaptureDoc(capStatus:="DECLINED")) : declinedFlow.Add(200, OAuth()) : declinedFlow.Add(200, GetFull(capStatus:="DECLINED"))
        Check(Cl(declinedFlow).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD").Snapshot.CaptureStatus = "DECLINED", "C37 DECLINED capture verified and reported as DECLINED")
        Dim twoDocs As New FakeTransport()
        twoDocs.Add(200, OAuth()) : twoDocs.Add(201, CaptureDoc()) : twoDocs.Add(200, OAuth()) : twoDocs.Add(200, GetFull())
        Check(Cl(twoDocs).CaptureOrderVerified(Doc(100D, 1), OrderId, "PP-CAPTURE-1-267", 100D, "USD").Success, "C38 tenant 1 end to end")
        Dim twoDocs2 As New FakeTransport()
        twoDocs2.Add(200, OAuth()) : twoDocs2.Add(201, CaptureDoc(reference:="KS-2-267")) : twoDocs2.Add(200, OAuth()) : twoDocs2.Add(200, GetFull(reference:="KS-2-267", custom:="KS-DOC-2-267", invoice:="KS-INV-2-267", email:="tenant-2@example.invalid"))
        Check(Cl(twoDocs2, 2).CaptureOrderVerified(Doc(100D, 2), OrderId, "PP-CAPTURE-2-267", 100D, "USD").Success, "C39 tenant 2 end to end with its own payee and ids")
        Dim cross As New FakeTransport()
        cross.Add(200, OAuth()) : cross.Add(201, CaptureDoc()) : cross.Add(200, OAuth()) : cross.Add(200, GetFull(email:="tenant-2@example.invalid"))
        Check(Not Cl(cross).CaptureOrderVerified(doc1, OrderId, "PP-CAPTURE-1-267", 100D, "USD").Success, "C40 tenant 1 never accepts the order of tenant 2 (payee)")

        ' ---- D. validatore stretto in forma a motivo e sua equivalenza con la vecchia espressione ----
        Dim strictOk As PayPalOrderSnapshot = SnapFromGet(GetFull())
        Check(PayPalOrdersV2Client.CheckOrderAgainstAttempt(doc1, cfg1, OrderId, strictOk, 100D, "USD") = "", "D01 a complete coherent GET is valid")
        Check(PayPalOrdersV2Client.CheckOrderAgainstAttempt(doc1, cfg1, OrderId, SnapFromGet(GetFull(status:="APPROVED", captures:=0)), 100D, "USD") = "", "D02 an APPROVED order without captures is valid")
        Check(PayPalOrdersV2Client.CheckOrderAgainstAttempt(doc1, cfg1, OrderId, SnapFromGet(Sub1(OfficialFixtures.OfficialGet(), OfficialReference, Ref)), 100D, "USD") = "INTENT", "D03 the official minimal GET example is refused by the strict check (no intent): documented fail-closed limit")
        Dim reasons As New List(Of Object())
        reasons.Add(New Object() {"D10", GetFull(intent:=""), "INTENT"})
        reasons.Add(New Object() {"D11", GetFull(reference:=""), "REFERENCE_ID"})
        reasons.Add(New Object() {"D12", GetFull(custom:=""), "CUSTOM_ID"})
        reasons.Add(New Object() {"D13", GetFull(invoice:=""), "INVOICE_ID"})
        reasons.Add(New Object() {"D14", GetFull(amount:=""), "ORDER_AMOUNT"})
        reasons.Add(New Object() {"D15", GetFull(email:=""), "PAYEE"})
        reasons.Add(New Object() {"D16", GetFull(merchant:=""), "MERCHANT"})
        reasons.Add(New Object() {"D17", GetFull(currency:="EUR"), "CURRENCY"})
        reasons.Add(New Object() {"D18", GetFull(status:="COMPLETED", captures:=0), "CAPTURE"})
        reasons.Add(New Object() {"D19", GetFull(units:=0), "UNIT_COUNT"})
        For Each rc As Object() In reasons
            Check(PayPalOrdersV2Client.CheckOrderAgainstAttempt(doc1, cfg1, OrderId, SnapFromGet(CStr(rc(1))), 100D, "USD") = CStr(rc(2)), CStr(rc(0)) & " strict reason " & CStr(rc(2)))
        Next
        ' griglia: ogni deviazione di un campo su tre basi; booleano nuovo == vecchia espressione == (motivo vuoto)
        Dim bases As New List(Of PayPalOrderSnapshot)
        bases.Add(SnapFromGet(GetFull(status:="APPROVED", captures:=0)))
        bases.Add(SnapFromGet(GetFull()))
        bases.Add(SnapFromGet(GetFull(capStatus:="PENDING")))
        Dim baseNames() As String = {"approved", "completed", "pending"}
        Dim muts As New List(Of KeyValuePair(Of String, Action(Of PayPalOrderSnapshot)))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("none", Sub(s) s.Status = s.Status & ""))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("units0", Sub(s) s.PurchaseUnitCount = 0))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("units2", Sub(s) s.PurchaseUnitCount = 2))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("amountinvalid", Sub(s) s.OrderAmountValid = False))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("order", Sub(s) s.OrderId = "OTHER-ORDER-123"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("intent", Sub(s) s.Intent = "AUTHORIZE"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("intentlower", Sub(s) s.Intent = "capture"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("intentempty", Sub(s) s.Intent = ""))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("ref", Sub(s) s.ReferenceId = "KS-1-268"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("refempty", Sub(s) s.ReferenceId = ""))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("custom", Sub(s) s.CustomId = "KS-DOC-1-268"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("invoice", Sub(s) s.InvoiceId = "KS-INV-1-268"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("amount", Sub(s) s.Amount = 99.99D))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("currency", Sub(s) s.CurrencyCode = "EUR"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("payee", Sub(s) s.PayeeEmail = "other@example.invalid"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("payeecase", Sub(s) s.PayeeEmail = s.PayeeEmail.ToUpperInvariant()))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("merchant", Sub(s) s.MerchantId = "OTHER"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("merchantcase", Sub(s) s.MerchantId = s.MerchantId.ToLowerInvariant()))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capcount2", Sub(s) s.CaptureCount = 2))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capcount0", Sub(s) s.CaptureCount = 0))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capamount", Sub(s) s.CaptureAmount = 99D))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capinvalid", Sub(s) s.CaptureAmountValid = False))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capcur", Sub(s) s.CaptureCurrencyCode = "EUR"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capid", Sub(s) s.CaptureId = "x"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatus", Sub(s) s.CaptureStatus = "WEIRD"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("statuscompleted0", Sub(s)
                                                                                                    s.Status = "COMPLETED"
                                                                                                    s.CaptureCount = 0
                                                                                                End Sub))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("statusempty", Sub(s) s.Status = ""))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("statusvoided", Sub(s) s.Status = "VOIDED"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatusrefunded", Sub(s) s.CaptureStatus = "REFUNDED"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatusdenied", Sub(s) s.CaptureStatus = "DENIED"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatusfailed", Sub(s) s.CaptureStatus = "FAILED"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatuslower", Sub(s) s.CaptureStatus = "completed"))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatusempty", Sub(s) s.CaptureStatus = ""))
        muts.Add(New KeyValuePair(Of String, Action(Of PayPalOrderSnapshot))("capstatusempty_completed", Sub(s)
                                                                                                                  s.CaptureStatus = ""
                                                                                                                  s.Status = "COMPLETED"
                                                                                                              End Sub))
        Dim cfgType20 As PayPalCheckoutConfig = Cfg(1)
        cfgType20.PagamentiTipoId = 20
        Dim gridPairs As Integer = 0
        Dim gridSame As Boolean = True
        Dim gridWrapper As Boolean = True
        Dim gridReason As Boolean = True
        For b As Integer = 0 To bases.Count - 1
            For Each m As KeyValuePair(Of String, Action(Of PayPalOrderSnapshot)) In muts
                For Each vr As Integer In New Integer() {0, 1, 2, 3, 4}
                    Dim snap As PayPalOrderSnapshot = SnapFromGet(GetFull(status:=If(b = 0, "APPROVED", "COMPLETED"), captures:=If(b = 0, 0, 1), capStatus:=If(b = 2, "PENDING", "COMPLETED")))
                    m.Value.Invoke(snap)
                    Dim attemptAmount As Decimal = If(vr = 1, 99D, 100D)
                    Dim attemptCurrency As String = If(vr = 2, "EUR", "usd")
                    Dim d As PayPalPaymentDocumentInfo = If(vr = 3, Doc(100.004D), doc1)
                    Dim gc As PayPalCheckoutConfig = If(vr = 4, cfgType20, cfg1)
                    Dim oldV As Boolean = OldValidateAgainstAttempt(d, gc, OrderId, snap, attemptAmount, attemptCurrency)
                    Dim newV As Boolean = PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(d, gc, OrderId, snap, attemptAmount, attemptCurrency)
                    Dim reason As String = PayPalOrdersV2Client.CheckOrderAgainstAttempt(d, gc, OrderId, snap, attemptAmount, attemptCurrency)
                    If oldV <> newV Then gridSame = False : Console.WriteLine("GRID_DIFF base=" & baseNames(b) & " mut=" & m.Key & " variant=" & vr)
                    If newV <> (reason.Length = 0) Then gridReason = False
                    If OldValidateSnapshot(d, gc, OrderId, snap) <> PayPalOrdersV2Client.ValidateSnapshot(d, gc, OrderId, snap) Then gridWrapper = False : Console.WriteLine("GRID_WRAPPER_DIFF base=" & baseNames(b) & " mut=" & m.Key)
                    gridPairs += 1
                Next
            Next
        Next
        Check(gridPairs >= 500 AndAlso gridSame, "D20 equivalence grid: ValidateSnapshotAgainstAttempt == the old expression on " & gridPairs & " snapshots")
        Check(gridWrapper, "D21 equivalence grid: ValidateSnapshot == the old expression")
        Check(gridReason, "D22 the boolean wrapper is exactly 'reason is empty'")
        Check(Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(Nothing, cfg1, OrderId, strictOk, 100D, "USD") AndAlso Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc1, Nothing, OrderId, strictOk, 100D, "USD") AndAlso Not PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc1, cfg1, OrderId, Nothing, 100D, "USD"), "D23 missing input is invalid")
        Check(PayPalOrdersV2Client.CheckOrderAgainstAttempt(doc1, Cfg(2), OrderId, strictOk, 100D, "USD") = "TENANT", "D24 config of another tenant refused with TENANT")

        ' ---- E. create ----
        fake = Fk(201, OfficialFixtures.OfficialCreateSimple())
        Dim cs As PayPalOrdersV2Result = Cl(fake).CreateOrder(doc1, "PP-CREATE-1-267", "https://t1.invalid/r", "https://t1.invalid/c")
        Check(cs.Success AndAlso cs.Snapshot.OrderId = OrderId AndAlso cs.Snapshot.ApprovalUrl.Contains("checkoutnow"), "E01 official minimal create (id and approve link) accepted at call level")
        Check(fake.Requests(1).Prefer = "return=representation" AndAlso fake.Requests(1).RequestId = "PP-CREATE-1-267" AndAlso fake.Requests(1).Body = Cl(fake).BuildCreateOrderPayload(doc1, "https://t1.invalid/r", "https://t1.invalid/c"), "E02 create still asks for the representation and sends the exact payload")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, cs.Snapshot, 100D, "USD") = "", "E03 official minimal create passes the lenient check")
        Dim pickup As String = Sub1(OfficialFixtures.OfficialCreatePickup(), "PUHF", Ref)
        Dim cp As PayPalOrdersV2Result = Cl(Fk(201, pickup)).CreateOrder(Doc(50D), "PP-CREATE-1-267", "https://t1.invalid/r", "https://t1.invalid/c")
        Check(cp.Success AndAlso PayPalOrdersV2Client.CheckCreatedOrder(Doc(50D), cfg1, cp.Snapshot, 50D, "USD") = "", "E04 official create with representation (payee email only, no intent, no merchant id, reference_id replaced) accepted")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(Doc(50D), cfg1, Cl(Fk(201, OfficialFixtures.OfficialCreatePickup())).CreateOrder(Doc(50D), "PP-CREATE-1-267", "r", "c").Snapshot, 50D, "USD") = "REFERENCE_ID", "E05 official create as is: its reference_id is present and different, refused")
        Dim ca As PayPalOrdersV2Result = Cl(Fk(200, OfficialFixtures.OfficialCreatePayerAction())).CreateOrder(doc1, "PP-CREATE-1-267", "r", "c")
        Check(ca.Success AndAlso ca.StatusCode = 200 AndAlso ca.Snapshot.ApprovalUrl.Contains("checkoutnow"), "E06 official 200 create with the payer-action link accepted")
        Check(Not Cl(Fk(201, J("{'id':'" & OrderId & "','status':'CREATED','links':[]}"))).CreateOrder(doc1, "PP-CREATE-1-267", "r", "c").Success, "E07 create without an approval link is not a success")
        Check(Cl(Fk(201, J("{'id':'" & OrderId & "','status':'CREATED','links':[]}"))).CreateOrder(doc1, "PP-CREATE-1-267", "r", "c").ErrorCode = "APPROVAL_URL_MISSING", "E08 the reason is APPROVAL_URL_MISSING, not a generic code")
        Check(Not Cl(Fk(201, J("{'id':'x','links':[{'rel':'approve','href':'https://www.paypal.com/checkoutnow?token=x'}]}"))).CreateOrder(doc1, "PP-CREATE-1-267", "r", "c").Success, "E09 create with an invalid order id is not a success")
        Dim createFull As PayPalOrderSnapshot = SnapFromGet(GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId))
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, createFull, 100D, "USD") = "", "E10 full create representation accepted")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(GetFull(status:="PAYER_ACTION_REQUIRED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId)), 100D, "USD") = "", "E11 PAYER_ACTION_REQUIRED accepted")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(GetFull(status:="APPROVED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId)), 100D, "USD") = "STATE", "E12 a status that is present and not CREATED/PAYER_ACTION_REQUIRED refused")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(GetFull(status:="CREATED", captures:=1, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId)), 100D, "USD") = "STATE", "E13 a created order that already carries a capture refused")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(GetFull(status:="CREATED", captures:=0)), 100D, "USD") = "APPROVAL_URL", "E14 created order without approval link refused")
        Dim createReasons As New List(Of Object())
        createReasons.Add(New Object() {"E20", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, intent:="AUTHORIZE"), "INTENT"})
        createReasons.Add(New Object() {"E21", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, reference:="KS-1-268"), "REFERENCE_ID"})
        createReasons.Add(New Object() {"E22", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, custom:="KS-DOC-1-268"), "CUSTOM_ID"})
        createReasons.Add(New Object() {"E23", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, invoice:="KS-INV-1-268"), "INVOICE_ID"})
        createReasons.Add(New Object() {"E24", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, amount:="99.00"), "AMOUNT"})
        createReasons.Add(New Object() {"E25", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, currency:="EUR"), "CURRENCY"})
        createReasons.Add(New Object() {"E26", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, email:="other@example.invalid"), "PAYEE"})
        createReasons.Add(New Object() {"E27", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, merchant:="OTHER"), "MERCHANT"})
        createReasons.Add(New Object() {"E28", GetFull(status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=" & OrderId, units:=2), "UNIT_COUNT"})
        For Each rc As Object() In createReasons
            Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(CStr(rc(1))), 100D, "USD") = CStr(rc(2)), CStr(rc(0)) & " create reason " & CStr(rc(2)))
        Next
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, Cfg(2), createFull, 100D, "USD") = "TENANT" AndAlso PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, createFull, 99D, "USD") = "ATTEMPT_AMOUNT" AndAlso PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, createFull, 100D, "EUR") = "ATTEMPT_CURRENCY" AndAlso PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, Nothing, 100D, "USD") = "INPUT", "E29 tenant, attempt amount, attempt currency and missing input refused")
        Check(PayPalOrdersV2Client.CheckCreatedOrder(doc1, cfg1, SnapFromGet(GetFull(id:="x", status:="CREATED", captures:=0, approval:="https://www.paypal.com/checkoutnow?token=x")), 100D, "USD") = "ORDER_ID", "E30 invalid order id refused")
        Dim createErr As PayPalOrdersV2Result = Cl(Fk(422, Err422("MISSING_REQUIRED_PARAMETER"))).CreateOrder(doc1, "PP-CREATE-1-267", "r", "c")
        Check(Not createErr.Success AndAlso createErr.ErrorCode = "UNPROCESSABLE_ENTITY:MISSING_REQUIRED_PARAMETER", "E31 create 422 keeps the issue in the error code")

        ' ---- F. nessuna regressione sui metodi gia esistenti ----
        Check(Cl(New FakeTransport()).BuildCreateOrderPayload(doc1, "r", "c").Contains("""intent"":""CAPTURE"""), "F01 the create payload still asks for intent CAPTURE")
        Dim getOne As PayPalOrdersV2Result = Cl(Fk(200, GetFull(status:="APPROVED", captures:=0))).GetOrder(OrderId)
        Check(getOne.Success AndAlso getOne.Snapshot.Status = "APPROVED" AndAlso PayPalOrdersV2Client.ValidateSnapshotAgainstAttempt(doc1, cfg1, OrderId, getOne.Snapshot, 100D, "USD"), "F02 GET of an approved order unchanged")
        Check(PayPalOrdersV2Client.DescribeFailure(New PayPalOrdersV2Result With {.StatusCode = 201, .ErrorCode = "CAPTURE_READBACK_PAYEE"}) = "http=201 code=CAPTURE_READBACK_PAYEE", "F03 the log line carries the readback reason")
    End Sub
End Module
