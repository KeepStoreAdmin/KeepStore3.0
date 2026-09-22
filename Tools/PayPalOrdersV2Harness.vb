Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic

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

Module PayPalOrdersV2Harness
    Private _passed As Integer
    Private Sub Check(ByVal condition As Boolean, ByVal name As String)
        If Not condition Then Throw New Exception("PAYPAL_ORDERS_V2_FAILED: " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function Config(ByVal company As Integer, ByVal email As String, ByVal brand As String) As PayPalCheckoutConfig
        Return New PayPalCheckoutConfig With {.AccountId = 9, .CompanyConfigId = company + 100, .AziendeId = company,
            .PagamentiTipoId = 19, .CredentialKey = "PAYPAL_TEST", .MerchantId = "MERCHANT-SHARED",
            .PayeeEmail = email, .BrandName = brand, .CurrencyCode = "EUR", .ClientId = "client", .ClientSecret = "secret",
            .WebhookId = "webhook", .AccountActive = True, .CompanyActive = True}
    End Function

    Private Function Doc(ByVal company As Integer) As PayPalPaymentDocumentInfo
        Return New PayPalPaymentDocumentInfo With {.DocumentId = 267, .AziendeId = company, .PagamentiTipoId = 19, .TotalDocument = 12.34D}
    End Function

    Private Function OAuth() As String
        Return "{""access_token"":""fake-access"",""token_type"":""Bearer""}"
    End Function

    Private Function OrderJson(ByVal company As Integer, ByVal status As String, ByVal amount As String, ByVal currency As String,
                               ByVal email As String, ByVal merchant As String, ByVal orderId As String,
                               Optional ByVal captureStatus As String = "", Optional ByVal approval As String = "https://www.paypal.com/checkoutnow?token=ORDER-123456") As String
        Dim capture As String = ""
        If captureStatus <> "" Then capture = ",""payments"":{""captures"":[{""id"":""CAPTURE-123456"",""status"":""" & captureStatus & """,""amount"":{""currency_code"":""" & currency & """,""value"":""" & amount & """}}]}"
        Return "{""id"":""" & orderId & """,""status"":""" & status & """,""intent"":""CAPTURE"",""purchase_units"":[{""reference_id"":""KS-" & company & "-267"",""custom_id"":""KS-DOC-" & company & "-267"",""invoice_id"":""KS-INV-" & company & "-267"",""amount"":{""currency_code"":""" & currency & """,""value"":""" & amount & """},""payee"":{""email_address"":""" & email & """,""merchant_id"":""" & merchant & """}" & capture & "}],""links"":[{""rel"":""payer-action"",""href"":""" & approval & """}]}"
    End Function

    Sub Main()
        Dim cfgA As PayPalCheckoutConfig = Config(1, "tenant-a@example.invalid", "TENANT A")
        Dim cfgB As PayPalCheckoutConfig = Config(2, "tenant-b@example.invalid", "TENANT B")
        Check(cfgA.IsConfigured, "01 credential complete")
        Check(Not Config(1, "bad", "A").IsConfigured, "02 invalid payee blocked")
        Check(Not PayPalCheckoutConfig.IsCredentialKeyValid("bad-key"), "03 invalid credential key blocked")

        Dim fake As New FakeTransport()
        fake.Add(200, OAuth())
        Dim token As PayPalAccessTokenResult = New PayPalOrdersV2Client(cfgA, fake).GetAccessToken()
        Check(token.Success AndAlso token.AccessToken = "fake-access", "04 OAuth OK")
        Check(fake.Requests(0).Url.EndsWith("/v1/oauth2/token"), "05 OAuth live endpoint")
        Check(fake.Requests(0).Body = "grant_type=client_credentials", "06 OAuth grant")

        fake = New FakeTransport()
        fake.Add(401, "{""name"":""AUTHENTICATION_FAILURE""}")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).GetAccessToken().Success, "07 OAuth 401")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(201, OrderJson(1, "CREATED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456"))
        Dim create As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfgA, fake).CreateOrder(Doc(1), "PP-CREATE-1-267", "https://tenant-a.invalid/paypalreturn.aspx", "https://tenant-a.invalid/paypalreturn.aspx?action=cancel")
        Check(create.Success, "08 Create Order 201")
        Check(create.Snapshot.ApprovalUrl.Contains("checkoutnow"), "09 approval URL present")
        Check(fake.Requests(1).RequestId = "PP-CREATE-1-267", "10 create idempotency header")
        Check(fake.Requests(1).Body.Contains("""experience_context"""), "11 experience context")
        Check(fake.Requests(1).Body.Contains("""payee"""), "12 tenant payee server payload")
        Check(fake.Requests(1).Prefer = "return=representation", "12a Create Prefer representation")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(201, "{""id"":""ORDER-123456"",""status"":""CREATED"",""links"":[]}")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).CreateOrder(Doc(1), "PP-CREATE-1-267", "https://a.invalid/r", "https://a.invalid/c").Success, "12b minimal Create response fails closed")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(422, "{""name"":""UNPROCESSABLE_ENTITY""}")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).CreateOrder(Doc(1), "PP-CREATE-1-267", "https://a.invalid/r", "https://a.invalid/c").Success, "13 Create Order error")
        Check(PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl("https://www.paypal.com/checkoutnow?token=x"), "14 approval host valid")
        Check(Not PayPalCheckoutSafetyPolicy.IsTrustedApprovalUrl("https://evil.invalid/checkoutnow"), "15 hostile approval blocked")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(200, OrderJson(1, "APPROVED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456"))
        Dim getResult As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfgA, fake).GetOrder("ORDER-123456")
        Check(getResult.Success AndAlso getResult.Snapshot.Status = "APPROVED", "16 Get Order APPROVED")
        Check(PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", getResult.Snapshot), "17 authoritative details match")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(201, OrderJson(1, "COMPLETED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456", "COMPLETED"))
        Dim capture As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfgA, fake).CaptureOrder("ORDER-123456", "PP-CAPTURE-1-267")
        Check(capture.Success AndAlso capture.Snapshot.CaptureStatus = "COMPLETED", "18 Capture COMPLETED")
        Check(fake.Requests(1).RequestId = "PP-CAPTURE-1-267", "19 capture idempotency header")
        Check(fake.Requests(1).Prefer = "return=representation", "19a Capture Prefer representation")

        fake = New FakeTransport()
        fake.Add(200, OAuth())
        fake.Add(201, "{""id"":""ORDER-123456"",""status"":""COMPLETED"",""links"":[]}")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).CaptureOrder("ORDER-123456", "PP-CAPTURE-1-267").Success, "19b minimal Capture response fails closed")

        fake = New FakeTransport() : fake.Add(200, OAuth()) : fake.Add(201, OrderJson(1, "COMPLETED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456", "PENDING"))
        Check(New PayPalOrdersV2Client(cfgA, fake).CaptureOrder("ORDER-123456", "PP-CAPTURE-1-267").Snapshot.CaptureStatus = "PENDING", "20 Capture PENDING")
        fake = New FakeTransport() : fake.Add(200, OAuth()) : fake.Add(201, OrderJson(1, "COMPLETED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456", "DECLINED"))
        Check(New PayPalOrdersV2Client(cfgA, fake).CaptureOrder("ORDER-123456", "PP-CAPTURE-1-267").Snapshot.CaptureStatus = "DECLINED", "21 Capture DECLINED")

        Dim valid As PayPalOrderSnapshot = capture.Snapshot
        valid.Amount = 1D : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", valid), "22 amount mismatch")
        valid = getResult.Snapshot : valid.CurrencyCode = "USD" : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", valid), "23 currency mismatch")
        valid = getResult.Snapshot : valid.PayeeEmail = "other@example.invalid" : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", valid), "24 payee mismatch")
        valid = getResult.Snapshot : valid.MerchantId = "OTHER" : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", valid), "25 merchant mismatch")
        valid = getResult.Snapshot : valid.CustomId = "KS-DOC-1-999" : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "ORDER-123456", valid), "26 document mismatch")
        valid = getResult.Snapshot : Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgA, "OTHER-ORDER", valid), "27 OrderId mismatch")
        Check(Not PayPalOrdersV2Client.ValidateSnapshot(Doc(1), cfgB, "ORDER-123456", getResult.Snapshot), "28 tenant mismatch")

        Dim abaA As String = cfgA.PayeeEmail & "|" & cfgA.BrandName
        Dim abaB As String = cfgB.PayeeEmail & "|" & cfgB.BrandName
        Check(abaA <> abaB, "29 tenant A/B separation")
        Check((cfgA.PayeeEmail & "|" & cfgA.BrandName) = abaA, "30 A-B-A no contamination")

        Dim rawEvent As String = "{" & vbCrLf & "  ""event_type"" : ""CHECKOUT.ORDER.APPROVED"", " & vbLf & " ""id"" : ""WH-RAW-1"", ""resource"" : { ""id"" : ""ORDER-123456"" }" & vbCrLf & "}"
        fake = New FakeTransport() : fake.Add(200, OAuth()) : fake.Add(200, "{""verification_status"":""SUCCESS""}")
        Dim webhook As PayPalWebhookVerificationResult = New PayPalOrdersV2Client(cfgA, fake).VerifyWebhookSignature("t","now","https://www.paypal.com/cert","SHA256withRSA","sig",rawEvent)
        Check(webhook.Success, "31 webhook SUCCESS")
        Check(fake.Requests(1).Body.Contains(rawEvent), "31a raw webhook text preserved exactly")
        Check(fake.Requests(1).Body.IndexOf(rawEvent, StringComparison.Ordinal) = fake.Requests(1).Body.LastIndexOf(rawEvent, StringComparison.Ordinal), "31b raw webhook inserted once")
        fake = New FakeTransport() : fake.Add(200, OAuth()) : fake.Add(200, "{""verification_status"":""FAILURE""}")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).VerifyWebhookSignature("t","now","https://www.paypal.com/cert","SHA256withRSA","sig",rawEvent).Success, "32 webhook FAILURE")
        Check(Not New PayPalOrdersV2Client(cfgA, fake).VerifyWebhookSignature("t","now","https://www.paypal.com/cert","SHA256withRSA","sig","not-json").Success, "32a invalid raw webhook blocked before network")

        Check(PayPalOrdersV2Client.IsReturnOrderTokenValid("ORDER-123456", "ORDER-123456"), "33 exact return token accepted")
        Check(Not PayPalOrdersV2Client.IsReturnOrderTokenValid(String.Empty, "ORDER-123456"), "34 missing return token blocked")
        Check(Not PayPalOrdersV2Client.IsReturnOrderTokenValid("ORDER-WRONG", "ORDER-123456"), "35 mismatched return token blocked")
        Check(Not PayPalOrdersV2Client.IsReturnOrderTokenValid("ORDER-123456?x=1", "ORDER-123456"), "36 invalid return token blocked")

        Dim captureRequestIds As New HashSet(Of String)(StringComparer.Ordinal)
        For attempt As Integer = 1 To 3
            fake = New FakeTransport()
            fake.Add(200, OAuth())
            fake.Add(201, OrderJson(1, "COMPLETED", "12.34", "EUR", cfgA.PayeeEmail, cfgA.MerchantId, "ORDER-123456", "COMPLETED"))
            Dim concurrentCapture As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfgA, fake).CaptureOrder("ORDER-123456", "PP-CAPTURE-1-267")
            Check(concurrentCapture.Success, "37 deterministic capture attempt " & attempt.ToString())
            captureRequestIds.Add(fake.Requests(1).RequestId)
        Next
        Check(captureRequestIds.Count = 1 AndAlso captureRequestIds.Contains("PP-CAPTURE-1-267"), "38 return/webhook/duplicate share one capture idempotency key")
        Console.WriteLine("PAYPAL_ORDERS_V2_TOTAL=" & _passed.ToString())
    End Sub
End Module
