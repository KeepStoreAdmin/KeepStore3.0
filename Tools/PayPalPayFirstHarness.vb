Option Strict On
Option Explicit On

' Harness per Test-PayPalPayFirst.ps1 (PAYPAL-PAY-FIRST-PAGES-1A, P3a1 del pay-first).
' Compila insieme al codice REALE di App_Code (PayPalPayFirst, PayPalPaymentAttempts, PayPalOrdersV2Client, ...) e lo esegue contro il database LAB LOCALE
' (connettore MySql.Data reale, schema reale) con un PayPal FINTO che mantiene lo stato (ordini, approvazione, autorizzazione, annullo, idempotenza per
' PayPal-Request-Id, risposte perse, rifiuti). Nessuna rete esterna. Dati sintetici con id 9301.. rimossi a fine corsa. Mai segreti: utente e password del LAB
' arrivano dall'ambiente del processo (KS_LAB_*). Uscita: numero di controlli falliti (0 = verde); 2 = ambiente non pronto.

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.Reflection
Imports System.Web
Imports System.Web.Script.Serialization
Imports MySql.Data.MySqlClient

Public Class FailFastException
    Inherits Exception
End Class

Public Class FakeSession
    Inherits HttpSessionStateBase
    Private ReadOnly _items As New Dictionary(Of String, Object)()
    Public Overrides Default Property Item(ByVal name As String) As Object
        Get
            Dim value As Object = Nothing
            _items.TryGetValue(name, value)
            Return value
        End Get
        Set(ByVal value As Object)
            _items(name) = value
        End Set
    End Property
    Public Overrides Sub Remove(ByVal name As String)
        _items.Remove(name)
    End Sub
    Public ReadOnly Property KeyCount As Integer
        Get
            Return _items.Count
        End Get
    End Property
End Class

Public Class FakeOrder
    Public Id As String = ""
    Public Status As String = "CREATED"
    Public Reference As String = ""
    Public Custom As String = ""
    Public Invoice As String = ""
    Public Amount As String = ""
    Public Currency As String = "EUR"
    Public Email As String = ""
    Public AuthId As String = ""
    Public AuthStatus As String = ""
    Public AuthExpires As String = ""
End Class

' PayPal finto con stato: crea (idempotente per request id), GET, approva (azione del test), authorize (idempotente), annulla.
Public Class FakePayPal
    Implements IPayPalHttpTransport
    Public ReadOnly Orders As New Dictionary(Of String, FakeOrder)()
    Public ReadOnly Requests As New List(Of PayPalHttpRequestData)()
    Public ReadOnly Kinds As New List(Of String)()
    Private ReadOnly _byRequest As New Dictionary(Of String, String)()
    Public Merchant As String = "KSMERCHANTPF"
    Public LoseResponseOn As String = ""
    Public FailNext As String = ""
    Public FailStatus As Integer = 500
    Public FailBody As String = ""
    Public AuthorizeResponseAuthId As String = ""
    Public AmountOverrideAtGet As String = ""
    Public AfterAuthorize As Action = Nothing
    Private _seq As Integer = 0

    Private Shared Function J(ByVal s As String) As String
        Return s.Replace("'"c, """"c)
    End Function

    Private Shared Function Resp(ByVal status As Integer, ByVal body As String) As PayPalHttpResponseData
        Return New PayPalHttpResponseData With {.StatusCode = status, .Body = body}
    End Function

    Public Function Count(ByVal kind As String) As Integer
        Dim n As Integer = 0
        For Each k As String In Kinds
            If k = kind Then n += 1
        Next
        Return n
    End Function

    Public Function LastRequestId(ByVal kind As String) As String
        For i As Integer = Kinds.Count - 1 To 0 Step -1
            If Kinds(i) = kind Then Return Requests(i).RequestId
        Next
        Return ""
    End Function

    Public Function LastBody(ByVal kind As String) As String
        For i As Integer = Kinds.Count - 1 To 0 Step -1
            If Kinds(i) = kind Then Return Convert.ToString(Requests(i).Body)
        Next
        Return ""
    End Function

    Public Sub Approve(ByVal orderId As String)
        If Orders.ContainsKey(orderId) AndAlso Orders(orderId).Status = "CREATED" Then Orders(orderId).Status = "APPROVED"
    End Sub

    Private Function OrderJson(ByVal o As FakeOrder, ByVal showAmountOverride As Boolean) As String
        Dim payments As String = ""
        If o.AuthId <> "" Then
            payments = ",'payments':{'authorizations':[{'id':'" & o.AuthId & "','status':'" & o.AuthStatus & "','amount':{'currency_code':'" & o.Currency & "','value':'" & o.Amount & "'},'invoice_id':'" & o.Invoice & "','custom_id':'" & o.Custom & "','expiration_time':'" & o.AuthExpires & "'}]}"
        End If
        Dim amount As String = If(showAmountOverride AndAlso AmountOverrideAtGet <> "", AmountOverrideAtGet, o.Amount)
        Dim unit As String = "{'reference_id':'" & o.Reference & "','custom_id':'" & o.Custom & "','invoice_id':'" & o.Invoice & "','amount':{'currency_code':'" & o.Currency & "','value':'" & amount & "'},'payee':{'email_address':'" & o.Email & "','merchant_id':'" & Merchant & "'}" & payments & "}"
        Return J("{'id':'" & o.Id & "','intent':'AUTHORIZE','status':'" & o.Status & "','purchase_units':[" & unit & "],'links':[{'rel':'payer-action','href':'https://www.paypal.com/checkoutnow?token=" & o.Id & "'}]}")
    End Function

    Private Function AuthorizeJson(ByVal o As FakeOrder) As String
        Dim authId As String = If(AuthorizeResponseAuthId <> "", AuthorizeResponseAuthId, o.AuthId)
        Return J("{'id':'" & o.Id & "','payment_source':{'paypal':{'account_status':'VERIFIED'}},'purchase_units':[{'reference_id':'" & o.Reference & "','payments':{'authorizations':[{'id':'" & authId & "','status':'CREATED','amount':{'currency_code':'" & o.Currency & "','value':'" & o.Amount & "'},'expiration_time':'" & o.AuthExpires & "'}]}}],'links':[]}")
    End Function

    Public Function Send(ByVal request As PayPalHttpRequestData) As PayPalHttpResponseData Implements IPayPalHttpTransport.Send
        Dim path As String = New Uri(request.Url).AbsolutePath
        Dim kind As String
        If path = "/v1/oauth2/token" Then
            Return Resp(200, J("{'access_token':'fake-access','token_type':'Bearer','expires_in':3000}"))
        ElseIf request.Method = "POST" AndAlso path = "/v2/checkout/orders" Then
            kind = "create"
        ElseIf request.Method = "GET" AndAlso path.StartsWith("/v2/checkout/orders/", StringComparison.Ordinal) Then
            kind = "get"
        ElseIf request.Method = "POST" AndAlso path.EndsWith("/authorize", StringComparison.Ordinal) Then
            kind = "authorize"
        ElseIf request.Method = "POST" AndAlso path.EndsWith("/void", StringComparison.Ordinal) Then
            kind = "void"
        ElseIf request.Method = "GET" AndAlso path.StartsWith("/v2/payments/authorizations/", StringComparison.Ordinal) Then
            kind = "getauth"
        Else
            kind = "other"
        End If
        Requests.Add(request)
        Kinds.Add(kind)
        If FailNext = kind Then
            FailNext = ""
            Return Resp(FailStatus, FailBody)
        End If
        Dim response As PayPalHttpResponseData
        Select Case kind
            Case "create"
                Dim key As String = "create:" & request.RequestId
                If _byRequest.ContainsKey(key) Then
                    response = Resp(201, OrderJson(Orders(_byRequest(key)), False))
                Else
                    Dim serializer As New JavaScriptSerializer()
                    Dim body As Dictionary(Of String, Object) = serializer.Deserialize(Of Dictionary(Of String, Object))(request.Body)
                    Dim units As System.Collections.ArrayList = CType(body("purchase_units"), System.Collections.ArrayList)
                    Dim unit As Dictionary(Of String, Object) = CType(units(0), Dictionary(Of String, Object))
                    Dim amount As Dictionary(Of String, Object) = CType(unit("amount"), Dictionary(Of String, Object))
                    Dim payee As Dictionary(Of String, Object) = CType(unit("payee"), Dictionary(Of String, Object))
                    _seq += 1
                    Dim o As New FakeOrder With {.Id = "KSFAKEORD" & Guid.NewGuid().ToString("N").Substring(0, 12).ToUpperInvariant(), .Reference = Convert.ToString(unit("reference_id")),
                        .Custom = Convert.ToString(unit("custom_id")), .Invoice = Convert.ToString(unit("invoice_id")), .Amount = Convert.ToString(amount("value")),
                        .Currency = Convert.ToString(amount("currency_code")), .Email = Convert.ToString(payee("email_address"))}
                    Orders(o.Id) = o
                    _byRequest(key) = o.Id
                    response = Resp(201, OrderJson(o, False))
                End If
            Case "get"
                Dim id As String = path.Substring("/v2/checkout/orders/".Length)
                If Orders.ContainsKey(id) Then response = Resp(200, OrderJson(Orders(id), True)) Else response = Resp(404, J("{'name':'RESOURCE_NOT_FOUND','message':'x','debug_id':'d'}"))
            Case "authorize"
                Dim id As String = path.Substring("/v2/checkout/orders/".Length)
                id = id.Substring(0, id.IndexOf("/"c))
                Dim key As String = "auth:" & request.RequestId
                If Not Orders.ContainsKey(id) Then
                    response = Resp(404, J("{'name':'RESOURCE_NOT_FOUND','message':'x','debug_id':'d'}"))
                ElseIf _byRequest.ContainsKey(key) Then
                    response = Resp(201, AuthorizeJson(Orders(id)))
                ElseIf Orders(id).Status <> "APPROVED" Then
                    response = Resp(422, J("{'name':'UNPROCESSABLE_ENTITY','message':'x','debug_id':'d','details':[{'issue':'ORDER_NOT_APPROVED'}]}"))
                Else
                    Dim o As FakeOrder = Orders(id)
                    o.Status = "COMPLETED"
                    o.AuthId = "KSFAKEAUTH" & Guid.NewGuid().ToString("N").Substring(0, 12).ToUpperInvariant()
                    o.AuthStatus = "CREATED"
                    o.AuthExpires = DateTime.UtcNow.AddDays(3).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture)
                    _byRequest(key) = id
                    response = Resp(201, AuthorizeJson(o))
                    If AfterAuthorize IsNot Nothing Then AfterAuthorize()
                End If
            Case "void"
                Dim authId As String = path.Substring("/v2/payments/authorizations/".Length)
                authId = authId.Substring(0, authId.IndexOf("/"c))
                For Each o As FakeOrder In Orders.Values
                    If o.AuthId = authId Then o.AuthStatus = "VOIDED"
                Next
                response = Resp(204, "")
            Case Else
                response = Resp(404, J("{'name':'RESOURCE_NOT_FOUND','message':'x','debug_id':'d'}"))
        End Select
        If LoseResponseOn = kind Then
            LoseResponseOn = ""
            Throw New System.Net.WebException("simulated lost response")
        End If
        Return response
    End Function
End Class

Public Module PayFirstHarness
    Private _failFast As Boolean = False
    Private _cs As String = String.Empty
    Private _pass As Integer = 0
    Private _fail As Integer = 0
    Private _docCursor As Integer = 9300
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const Scope As String = "KS_TEST_PF_SCOPE"
    Private Const KeyA As String = "KS_TEST_PF_A"
    Private _userId As Integer = 1
    Private _account As Integer = 0

    Private Sub Check(ByVal name As String, ByVal ok As Boolean)
        If ok Then
            _pass += 1
            Console.WriteLine("PASS " & name)
        Else
            _fail += 1
            Console.WriteLine("FAIL " & name)
            If _failFast Then Throw New FailFastException()
        End If
    End Sub

    Private Function Env(ByVal name As String) As String
        Return Convert.ToString(Environment.GetEnvironmentVariable(name))
    End Function

    Private Sub Exec(ByVal sql As String)
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using cmd As New MySqlCommand(sql, conn)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    Private Function Scalar(ByVal sql As String) As String
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using cmd As New MySqlCommand(sql, conn)
                Dim value As Object = cmd.ExecuteScalar()
                If value Is Nothing OrElse value Is DBNull.Value Then Return "<null>"
                Return Convert.ToString(value, CultureInfo.InvariantCulture)
            End Using
        End Using
    End Function

    Private Function Next32() As String
        Return Guid.NewGuid().ToString("N")
    End Function

    Private Function StateOf(ByVal id As Long) As String
        Return Scalar("SELECT Stato FROM paypal_checkout_tentativi WHERE Id=" & id.ToString(CultureInfo.InvariantCulture))
    End Function

    Private Function Cfg(Optional ByVal company As Integer = 9301) As PayPalCheckoutConfig
        Return New PayPalCheckoutConfig With {.AccountId = _account, .CompanyConfigId = 1, .AziendeId = company, .PagamentiTipoId = company, .CredentialKey = KeyA,
            .MerchantId = "KSMERCHANTPF", .PayeeEmail = "pf-a@example.invalid", .BrandName = "KS TEST PF", .CurrencyCode = "EUR", .ClientId = "ks-fixture-client",
            .ClientSecret = "FAKE-secret", .WebhookId = "ks-fixture-webhook", .AccountActive = True, .CompanyActive = True}
    End Function

    Private Function Client(ByVal fake As FakePayPal) As PayPalOrdersV2Client
        Return New PayPalOrdersV2Client(Cfg(), fake)
    End Function

    Private Function UrlFor() As Func(Of String, String)
        Return Function(path As String) "https://shop.test" & path
    End Function

    Private Function NewCtx(Optional ByVal minutes As Integer = 30, Optional ByVal draft As String = "", Optional ByVal fingerprint As String = "") As PayPalPayFirstContext
        Return New PayPalPayFirstContext With {.DraftRequestId = If(draft = "", Next32(), draft), .PayloadFingerprint = If(fingerprint = "", "fp-" & Next32(), fingerprint),
            .CheckoutToken = "TOKEN-" & Next32(), .DatabaseScopeKey = Scope, .AziendeId = 9301, .LoginId = 7301, .UtentiId = _userId, .PagamentiTipoId = 9301,
            .Amount = 12.34D, .DraftExpiresUtc = DateTime.UtcNow.AddMinutes(minutes)}
    End Function

    Private Function Latest(ByVal ctx As PayPalPayFirstContext) As PayPalAttemptRecord
        Return PayPalPaymentAttempts.LoadLatestForDraft(ctx.AziendeId, ctx.LoginId, ctx.DraftRequestId)
    End Function

    Private Function StartIt(ByVal ctx As PayPalPayFirstContext, ByVal fake As FakePayPal, Optional ByVal nowOffsetMinutes As Integer = 0) As PayFirstResult
        Return PayPalPayFirstService.Start(ctx, Cfg(), Client(fake), UrlFor(), DateTime.UtcNow.AddMinutes(nowOffsetMinutes))
    End Function

    Private Function ReturnIt(ByVal attempt As PayPalAttemptRecord, ByVal action As String, ByVal token As String, ByVal ctx As PayPalPayFirstContext,
                              ByVal fake As FakePayPal, Optional ByVal nowOffsetMinutes As Integer = 0) As PayFirstResult
        Return PayPalPayFirstService.HandleReturn(attempt, action, token, ctx, Cfg(), Client(fake), UrlFor(), DateTime.UtcNow.AddMinutes(nowOffsetMinutes))
    End Function

    ' Avvio + approvazione del cliente su PayPal (nel finto): restituisce il tentativo CREATED.
    Private Function StartedAndApproved(ByVal ctx As PayPalPayFirstContext, ByVal fake As FakePayPal) As PayPalAttemptRecord
        Dim r As PayFirstResult = StartIt(ctx, fake)
        Dim a As PayPalAttemptRecord = Latest(ctx)
        If r.Outcome <> PayFirstOutcome.ApprovalRedirect OrElse a Is Nothing OrElse a.Stato <> "CREATED" Then
            Check("Z01 helper: the attempt is created and waiting for approval", False)
            Throw New InvalidOperationException("STARTED_AND_APPROVED")
        End If
        fake.Approve(a.PayPalOrderId)
        Return a
    End Function

    Private Function Authorized(ByVal ctx As PayPalPayFirstContext, ByVal fake As FakePayPal) As PayPalAttemptRecord
        Dim a As PayPalAttemptRecord = StartedAndApproved(ctx, fake)
        Dim r As PayFirstResult = ReturnIt(a, "return", a.PayPalOrderId, ctx, fake)
        Dim b As PayPalAttemptRecord = Latest(ctx)
        If r.Outcome <> PayFirstOutcome.ProceedToOrder OrElse b Is Nothing OrElse b.Stato <> "AUTHORIZED" Then
            Check("Z02 helper: the attempt reaches AUTHORIZED", False)
            Throw New InvalidOperationException("AUTHORIZED")
        End If
        Return b
    End Function

    ' Stato forzato (fixture): rispetta i CHECK della tabella (slot, stato precedente, documento).
    Private Sub Force(ByVal id As Long, ByVal state As String, Optional ByVal previous As String = "")
        _docCursor += 1
        Dim slot As String = If(state = "FAILED" OrElse state = "CANCELED" OrElse state = "VOIDED" OrElse state = "CAPTURED_ORPHAN", "NULL", "1")
        Dim prev As String = If(previous = "", "NULL", "'" & previous & "'")
        Dim doc As String = If(state = "DOC_COMMITTED" OrElse state = "CAPTURING" OrElse state = "CAPTURE_REFUSED" OrElse state = "COMPLETED", _docCursor.ToString(CultureInfo.InvariantCulture), "NULL")
        Exec("UPDATE paypal_checkout_tentativi SET Stato='" & state & "',CurrentSlot=" & slot & ",StatoPrecedente=" & prev & ",DocumentiId=COALESCE(DocumentiId," & doc & ") WHERE Id=" & id.ToString(CultureInfo.InvariantCulture))
    End Sub

    Private Function ForcedAttempt(ByVal state As String, Optional ByVal previous As String = "") As PayPalPayFirstContext
        Dim ctx As PayPalPayFirstContext = NewCtx()
        Dim created As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(New PayPalAttemptCreateRequest With {
            .AziendeId = ctx.AziendeId, .LoginId = ctx.LoginId, .UtentiId = ctx.UtentiId, .PagamentiTipoId = ctx.PagamentiTipoId, .PayPalAccountId = _account,
            .DatabaseScopeKey = Scope, .DraftRequestId = ctx.DraftRequestId, .PayloadFingerprint = ctx.PayloadFingerprint, .DraftExpiresUtc = ctx.DraftExpiresUtc,
            .Importo = ctx.Amount, .Valuta = "EUR", .PayeeEmail = "pf-a@example.invalid", .MerchantId = "KSMERCHANTPF"})
        If created.Outcome <> PayPalAttemptCreateOutcome.Created Then
            Check("Z03 helper: a forced attempt is created", False)
            Throw New InvalidOperationException("FORCED")
        End If
        Force(created.Attempt.Id, state, previous)
        Return ctx
    End Function

    Public Function Main(ByVal args As String()) As Integer
        For Each arg As String In args
            If String.Equals(arg, "failfast=true", StringComparison.OrdinalIgnoreCase) Then _failFast = True
        Next
        Dim user As String = Env("KS_LAB_USER")
        Dim labCredential As String = Env("KS_LAB_PWD")
        Dim schema As String = Env("KS_LAB_SCHEMA")
        Dim port As String = Env("KS_LAB_PORT")
        If user = "" OrElse labCredential = "" OrElse schema = "" OrElse port = "" Then
            Console.WriteLine("ENV_NOT_READY")
            Return 2
        End If
        Dim sb As New MySqlConnectionStringBuilder()
        sb.Server = "127.0.0.1"
        sb.Port = CUInt(Integer.Parse(port, CultureInfo.InvariantCulture))
        sb.Database = schema
        sb.UserID = user
        sb("Password") = labCredential
        sb.SslMode = MySqlSslMode.Required
        sb.TreatTinyAsBoolean = True
        sb.MaximumPoolSize = 32
        _cs = sb.ConnectionString
        labCredential = String.Empty
        Dim coll As ConnectionStringSettingsCollection = ConfigurationManager.ConnectionStrings
        Dim readOnlyField As FieldInfo = GetType(ConfigurationElementCollection).GetField("bReadOnly", BindingFlags.Instance Or BindingFlags.NonPublic)
        readOnlyField.SetValue(coll, False)
        coll.Add(New ConnectionStringSettings("EntropicConnectionString", _cs))
        Try
            If Scalar("SELECT @@server_uuid") <> LabUuid OrElse Scalar("SELECT @@port") <> port OrElse Scalar("SELECT DATABASE()") <> schema OrElse Not schema.StartsWith("keepstore_regorder_lab", StringComparison.Ordinal) Then
                Console.WriteLine("LAB_IDENTITY_MISMATCH")
                Return 2
            End If
            If Scalar("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi'") <> "1" Then
                Console.WriteLine("LAB_SCHEMA_NOT_READY")
                Return 2
            End If
            If Scalar("SELECT (SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9301,9302) AND AziendeID NOT IN (9301,9302))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9301,9302) AND PayeeEmail NOT LIKE '%@example.invalid')+(SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE AziendeId IN (9301,9302) AND DatabaseScopeKey<>'" & Scope & "')") <> "0" Then
                Console.WriteLine("LAB_FIXTURE_ID_COLLISION")
                Return 2
            End If
        Catch ex As Exception
            Console.WriteLine("LAB_PREFLIGHT_FAILED " & ex.GetType().Name)
            Return 2
        End Try

        Try
            Cleanup()
            Setup()
            RunPolicy()
            RunContext()
            RunRepository()
            RunStart()
            RunReturn()
        Catch ex As FailFastException
        Catch ex As Exception
            _fail += 1
            Console.WriteLine("FAIL harness-exception-" & ex.GetType().Name)
            Console.WriteLine("EXC " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
        Finally
            Try
                Cleanup()
                _failFast = False
                Check("cleanup-no-residue", Scalar("SELECT (SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='" & Scope & "' OR AziendeId IN (9301,9302))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9301,9302))+(SELECT COUNT(*) FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "')+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9301,9302))") = "0")
            Catch ex As Exception
                Check("cleanup-exception-" & ex.GetType().Name, False)
            End Try
        End Try
        Console.WriteLine("RESULT pass=" & _pass.ToString(CultureInfo.InvariantCulture) & " fail=" & _fail.ToString(CultureInfo.InvariantCulture))
        Return _fail
    End Function

    Private Sub Cleanup()
        Exec("DELETE FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='" & Scope & "' OR AziendeId IN (9301,9302)")
        Exec("DELETE FROM paypal_checkout_azienda WHERE AziendeId IN (9301,9302)")
        Exec("DELETE FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'")
        Exec("DELETE FROM pagamentitipo WHERE id IN (9301,9302)")
    End Sub

    Private Sub Setup()
        _userId = Integer.Parse(Scalar("SELECT COALESCE(MIN(UtentiId),1) FROM documenti"), CultureInfo.InvariantCulture)
        For Each companyId As Integer In New Integer() {9301, 9302}
            Exec("INSERT INTO pagamentitipo (id,AziendeID,Descrizione,Informazioni,Abilitato,Web,Ordinamento,Predefinito,CostoPercentuale,CostoFisso,CostoMassimo,NumeroOrdini,Contrassegno,OnLine,Cassa,Banca) VALUES (" &
                 companyId & "," & companyId & ",'KS TEST PAYFIRST','fixture',1,1,1,0,0,0,5000,0,0,2,0,0)")
        Next
        Exec("INSERT INTO paypal_checkout_account (NomeProfilo,CredentialKey,MerchantId,Attivo,ClientId,ClientSecret,WebhookId) VALUES ('KS TEST PF A','" & KeyA & "','KSMERCHANTPF',1,'ks-fixture-client','FAKE-secret','ks-fixture-webhook')")
        _account = Integer.Parse(Scalar("SELECT Id FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'"), CultureInfo.InvariantCulture)
        For Each companyId As Integer In New Integer() {9301, 9302}
            Exec("INSERT INTO paypal_checkout_azienda (AziendeId,PagamentiTipoId,PayPalAccountId,PayeeEmail,BrandName,CurrencyCode,Attivo) VALUES (" & companyId & "," & companyId & "," & _account & ",'pf-a@example.invalid','KS TEST PF','EUR',1)")
        Next
    End Sub

    ' ----- politica e instradamento (puri) -----
    Private Sub RunPolicy()
        Check("P01 Applies: PayPal, flag 0, ordine, nessun coupon", PayPalPayFirstPolicy.Applies(2, 0, 1, False))
        Check("P02 Applies: flag 1 non si applica", Not PayPalPayFirstPolicy.Applies(2, 1, 1, False))
        Check("P03 Applies: pagamento non PayPal non si applica", Not PayPalPayFirstPolicy.Applies(1, 0, 1, False))
        Check("P04 Applies: il preventivo (tipo 2) non si applica", Not PayPalPayFirstPolicy.Applies(2, 0, 2, False))
        Check("P05 Applies: il coupon non si applica", Not PayPalPayFirstPolicy.Applies(2, 0, 1, True))
        Check("P06 Applies: tipo documento non valido non si applica", Not PayPalPayFirstPolicy.Applies(2, 0, 0, False))
        Check("P07 HasCoupon: codice di controllo", PayPalPayFirstPolicy.HasCoupon("ABC", 0))
        Check("P08 HasCoupon: coupon-articolo", PayPalPayFirstPolicy.HasCoupon("", 5))
        Check("P09 HasCoupon: il buono sconto non e un coupon", Not PayPalPayFirstPolicy.HasCoupon("", 0))
        Check("P10 Route: nessun tentativo, CREATING, CREATED, VOIDED, FAILED, CANCELED = avvio",
              PayPalPayFirstPolicy.RouteFor("", "") = PayFirstRoute.StartPayment AndAlso PayPalPayFirstPolicy.RouteFor("CREATING", "") = PayFirstRoute.StartPayment AndAlso
              PayPalPayFirstPolicy.RouteFor("CREATED", "") = PayFirstRoute.StartPayment AndAlso PayPalPayFirstPolicy.RouteFor("VOIDED", "") = PayFirstRoute.StartPayment AndAlso
              PayPalPayFirstPolicy.RouteFor("FAILED", "") = PayFirstRoute.StartPayment AndAlso PayPalPayFirstPolicy.RouteFor("CANCELED", "") = PayFirstRoute.StartPayment)
        Check("P11 Route: AUTHORIZED = ordine", PayPalPayFirstPolicy.RouteFor("AUTHORIZED", "") = PayFirstRoute.CreateOrder)
        Check("P12 Route: DOC_COMMITTED, CAPTURING, CAPTURE_REFUSED = ripresa", PayPalPayFirstPolicy.RouteFor("DOC_COMMITTED", "") = PayFirstRoute.Finish AndAlso
              PayPalPayFirstPolicy.RouteFor("CAPTURING", "") = PayFirstRoute.Finish AndAlso PayPalPayFirstPolicy.RouteFor("CAPTURE_REFUSED", "") = PayFirstRoute.Finish)
        Check("P13 Route: COMPLETED = conferma, VOIDING = attesa, orfano = manuale", PayPalPayFirstPolicy.RouteFor("COMPLETED", "") = PayFirstRoute.Confirmation AndAlso
              PayPalPayFirstPolicy.RouteFor("VOIDING", "") = PayFirstRoute.Busy AndAlso PayPalPayFirstPolicy.RouteFor("CAPTURED_ORPHAN", "") = PayFirstRoute.Manual)
        Check("P14 Route: UNKNOWN dopo il documento = ripresa, prima = attesa", PayPalPayFirstPolicy.RouteFor("UNKNOWN", "DOC_COMMITTED") = PayFirstRoute.Finish AndAlso
              PayPalPayFirstPolicy.RouteFor("UNKNOWN", "CAPTURING") = PayFirstRoute.Finish AndAlso PayPalPayFirstPolicy.RouteFor("UNKNOWN", "CREATED") = PayFirstRoute.Busy AndAlso
              PayPalPayFirstPolicy.RouteFor("UNKNOWN", "AUTHORIZED") = PayFirstRoute.Busy)
    End Sub

    ' ----- contesto di sessione per bozza -----
    ' Find con un proprietario diverso ELIMINA il contesto trovato (un contesto di un'altra identita non deve sopravvivere): ogni sonda usa una sessione propria.
    Private Function SessionWith(ByVal ParamArray contexts As PayPalPayFirstContext()) As FakeSession
        Dim s As New FakeSession()
        For Each c As PayPalPayFirstContext In contexts
            PayPalPayFirstContext.Issue(s, c)
        Next
        Return s
    End Function

    Private Sub RunContext()
        Dim c1 As PayPalPayFirstContext = NewCtx()
        Dim c2 As PayPalPayFirstContext = NewCtx()
        Dim s As FakeSession = SessionWith(c1, c2)
        Check("X01 Issue valido: due bozze, due chiavi", s.KeyCount = 2)
        Check("X02 le due bozze non si sovrascrivono", PayPalPayFirstContext.Find(s, c1.DraftRequestId, 9301, 7301, _userId, Scope, DateTime.UtcNow) Is c1 AndAlso
              PayPalPayFirstContext.Find(s, c2.DraftRequestId, 9301, 7301, _userId, Scope, DateTime.UtcNow) Is c2 AndAlso s.KeyCount = 2)
        Dim sLogin As FakeSession = SessionWith(c1)
        Check("X03 un altro login non lo trova e il contesto sparisce", PayPalPayFirstContext.Find(sLogin, c1.DraftRequestId, 9301, 7399, _userId, Scope, DateTime.UtcNow) Is Nothing AndAlso sLogin.KeyCount = 0)
        Dim sCompany As FakeSession = SessionWith(c1)
        Check("X04 un'altra azienda non lo trova", PayPalPayFirstContext.Find(sCompany, c1.DraftRequestId, 9302, 7301, _userId, Scope, DateTime.UtcNow) Is Nothing)
        Dim sScope As FakeSession = SessionWith(c1)
        Check("X05 un altro database non lo trova", PayPalPayFirstContext.Find(sScope, c1.DraftRequestId, 9301, 7301, _userId, "ALTRO_SCOPE", DateTime.UtcNow) Is Nothing)
        Dim sUser As FakeSession = SessionWith(c1)
        Check("X05b un altro utente non lo trova", PayPalPayFirstContext.Find(sUser, c1.DraftRequestId, 9301, 7301, _userId + 1, Scope, DateTime.UtcNow) Is Nothing)
        Dim c3 As PayPalPayFirstContext = NewCtx(minutes:=-1)
        Dim sOld As FakeSession = SessionWith(c3)
        Check("X06 una bozza scaduta non si trova e il contesto sparisce", PayPalPayFirstContext.Find(sOld, c3.DraftRequestId, 9301, 7301, _userId, Scope, DateTime.UtcNow) Is Nothing AndAlso sOld.KeyCount = 0)
        Dim bad As PayPalPayFirstContext = NewCtx()
        bad.Amount = 0D
        Check("X07 Issue rifiuta un importo nullo e un id richiesta non valido", Not PayPalPayFirstContext.Issue(New FakeSession(), bad) AndAlso PayPalPayFirstContext.SessionKeyFor("../x") = "")
        Dim sRem As FakeSession = SessionWith(c1, c2)
        PayPalPayFirstContext.Remove(sRem, c1.DraftRequestId)
        Check("X08 Remove toglie solo quella bozza", PayPalPayFirstContext.Find(sRem, c1.DraftRequestId, 9301, 7301, _userId, Scope, DateTime.UtcNow) Is Nothing AndAlso
              PayPalPayFirstContext.Find(sRem, c2.DraftRequestId, 9301, 7301, _userId, Scope, DateTime.UtcNow) Is c2)
    End Sub
    ' ----- repository: caricamento dell'ultimo tentativo e annullo protetto -----
    Private Sub RunRepository()
        Dim ctx As PayPalPayFirstContext = NewCtx()
        Check("V01 nessun tentativo: LoadLatestForDraft = Nothing", Latest(ctx) Is Nothing)
        Dim fake As New FakePayPal()
        StartIt(ctx, fake)
        Dim a As PayPalAttemptRecord = Latest(ctx)
        Check("V02 LoadLatestForDraft trova il tentativo e solo per il proprietario", a IsNot Nothing AndAlso PayPalPaymentAttempts.LoadLatestForDraft(9301, 7399, ctx.DraftRequestId) Is Nothing AndAlso
              PayPalPaymentAttempts.LoadLatestForDraft(9302, 7301, ctx.DraftRequestId) Is Nothing)
        Check("V03 RecordVoidingUnbound non parte da CREATED", Not PayPalPaymentAttempts.RecordVoidingUnbound(a.Id, a.AziendeId, "T") AndAlso StateOf(a.Id) = "CREATED")
        Force(a.Id, "DOC_COMMITTED")
        Check("V04 RecordVoidingUnbound non parte da DOC_COMMITTED (l'ordine esiste)", Not PayPalPaymentAttempts.RecordVoidingUnbound(a.Id, a.AziendeId, "T") AndAlso StateOf(a.Id) = "DOC_COMMITTED")
        Force(a.Id, "CAPTURE_REFUSED")
        Check("V05 RecordVoidingUnbound non parte da CAPTURE_REFUSED", Not PayPalPaymentAttempts.RecordVoidingUnbound(a.Id, a.AziendeId, "T") AndAlso StateOf(a.Id) = "CAPTURE_REFUSED")
        Dim ctx2 As PayPalPayFirstContext = ForcedAttempt("AUTHORIZED")
        Dim b As PayPalAttemptRecord = Latest(ctx2)
        Check("V06 RecordVoidingUnbound parte da AUTHORIZED", PayPalPaymentAttempts.RecordVoidingUnbound(b.Id, b.AziendeId, "T") AndAlso StateOf(b.Id) = "VOIDING")
        Dim ctx3 As PayPalPayFirstContext = ForcedAttempt("FAILED")
        Check("V07 LoadLatestForDraft trova anche un tentativo con lo slot rilasciato", Latest(ctx3) IsNot Nothing AndAlso Latest(ctx3).Stato = "FAILED")
    End Sub

    ' ----- avvio -----
    Private Sub RunStart()
        Dim fake As New FakePayPal()
        Dim ctx As PayPalPayFirstContext = NewCtx()
        Dim r As PayFirstResult = StartIt(ctx, fake)
        Dim a As PayPalAttemptRecord = Latest(ctx)
        Check("S01 avvio: reindirizza all'approvazione PayPal", r.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso r.Url.StartsWith("https://www.paypal.com/", StringComparison.Ordinal))
        Check("S02 avvio: tentativo CREATED con l'ordine PayPal registrato", a IsNot Nothing AndAlso a.Stato = "CREATED" AndAlso Not String.IsNullOrEmpty(a.PayPalOrderId) AndAlso fake.Orders.ContainsKey(a.PayPalOrderId))
        Check("S03 avvio: una sola creazione con il request id del tentativo", fake.Count("create") = 1 AndAlso a IsNot Nothing AndAlso fake.LastRequestId("create") = a.CreateRequestId)
        Check("S04 avvio: ordine AUTHORIZE da 12.34 EUR con la chiave del tentativo", fake.LastBody("create").Contains("""intent"":""AUTHORIZE""") AndAlso fake.LastBody("create").Contains("12.34") AndAlso
              a IsNot Nothing AndAlso fake.Orders(a.PayPalOrderId).Reference = PayPalOrdersV2Client.ExpectedAttemptReferenceId(New PayPalAttemptInfo With {.AziendeId = a.AziendeId, .PagamentiTipoId = a.PagamentiTipoId, .AttemptId = a.Id, .Amount = a.Importo}))
        Dim r2 As PayFirstResult = StartIt(ctx, fake)
        Check("S05 secondo avvio della stessa bozza: stesso ordine, nessuna seconda creazione", r2.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso fake.Count("create") = 1 AndAlso fake.Orders.Count = 1)

        Dim lost As New FakePayPal()
        Dim ctxL As PayPalPayFirstContext = NewCtx()
        lost.LoseResponseOn = "create"
        Dim rl As PayFirstResult = StartIt(ctxL, lost)
        Dim al As PayPalAttemptRecord = Latest(ctxL)
        Check("S06 risposta di creazione persa: attesa, tentativo ancora CREATING", rl.Outcome = PayFirstOutcome.Busy AndAlso al IsNot Nothing AndAlso al.Stato = "CREATING")
        Dim rl2 As PayFirstResult = StartIt(ctxL, lost)
        Check("S07 dopo la risposta persa: stessa richiesta, un solo ordine PayPal", rl2.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso lost.Orders.Count = 1 AndAlso lost.Count("create") = 2 AndAlso
              Latest(ctxL).Stato = "CREATED")

        Dim noTime As New FakePayPal()
        Dim ctxT As PayPalPayFirstContext = NewCtx(minutes:=10)
        Dim rt As PayFirstResult = StartIt(ctxT, noTime)
        Check("S08 poco tempo residuo: nessuna chiamata PayPal e nessun tentativo", rt.Outcome = PayFirstOutcome.BackToCart AndAlso noTime.Requests.Count = 0 AndAlso Latest(ctxT) Is Nothing)

        Dim refused As New FakePayPal()
        Dim ctxR As PayPalPayFirstContext = NewCtx()
        refused.FailNext = "create"
        refused.FailStatus = 400
        refused.FailBody = "{""name"":""INVALID_REQUEST"",""message"":""x"",""debug_id"":""d""}"
        Dim rr As PayFirstResult = StartIt(ctxR, refused)
        Check("S09 creazione rifiutata: carrello, tentativo FAILED", rr.Outcome = PayFirstOutcome.BackToCart AndAlso Latest(ctxR).Stato = "FAILED")
        Dim rr2 As PayFirstResult = StartIt(ctxR, refused)
        Check("S10 dopo il rifiuto si riparte con un tentativo nuovo", rr2.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso Latest(ctxR).TentativoNo = 2 AndAlso Latest(ctxR).Stato = "CREATED")

        Dim changed As New FakePayPal()
        Dim ctxC As PayPalPayFirstContext = NewCtx()
        StartIt(ctxC, changed)
        Dim first As PayPalAttemptRecord = Latest(ctxC)
        Dim ctxC2 As PayPalPayFirstContext = NewCtx(draft:=ctxC.DraftRequestId)
        Dim rc As PayFirstResult = StartIt(ctxC2, changed)
        Dim second As PayPalAttemptRecord = Latest(ctxC2)
        Check("S11 stessa bozza con contenuto cambiato: il vecchio tentativo e chiuso, ne nasce uno nuovo", rc.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso StateOf(first.Id) = "FAILED" AndAlso
              second.TentativoNo = 2 AndAlso second.Stato = "CREATED" AndAlso changed.Count("create") = 2 AndAlso changed.Count("void") = 0)

        Dim voidFake As New FakePayPal()
        Dim ctxV As PayPalPayFirstContext = NewCtx()
        Dim authorized1 As PayPalAttemptRecord = Authorized(ctxV, voidFake)
        Dim ctxV2 As PayPalPayFirstContext = NewCtx(draft:=ctxV.DraftRequestId)
        Dim rv As PayFirstResult = StartIt(ctxV2, voidFake)
        Check("S12 bozza cambiata con autorizzazione trattenuta: l'autorizzazione e annullata (stesso request id di annullo) e si riparte", rv.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso voidFake.Count("void") = 1 AndAlso
              voidFake.LastRequestId("void") = authorized1.VoidRequestId AndAlso StateOf(authorized1.Id) = "VOIDED" AndAlso Latest(ctxV2).TentativoNo = 2)

        Dim same As New FakePayPal()
        Dim ctxS As PayPalPayFirstContext = NewCtx()
        Authorized(ctxS, same)
        Dim before As Integer = same.Requests.Count
        Dim rs As PayFirstResult = StartIt(ctxS, same)
        Check("S13 tentativo AUTHORIZED con la stessa bozza: si va all'ordine senza chiamare PayPal", rs.Outcome = PayFirstOutcome.ProceedToOrder AndAlso same.Requests.Count = before)
        Dim rs2 As PayFirstResult = StartIt(ctxS, same, nowOffsetMinutes:=25)
        Check("S14 con poco tempo residuo un tentativo AUTHORIZED prosegue comunque", rs2.Outcome = PayFirstOutcome.ProceedToOrder)

        Dim routing As New List(Of KeyValuePair(Of String, String))()
        routing.Add(New KeyValuePair(Of String, String)("DOC_COMMITTED", ""))
        routing.Add(New KeyValuePair(Of String, String)("CAPTURING", ""))
        routing.Add(New KeyValuePair(Of String, String)("COMPLETED", ""))
        routing.Add(New KeyValuePair(Of String, String)("VOIDING", ""))
        routing.Add(New KeyValuePair(Of String, String)("CAPTURED_ORPHAN", ""))
        routing.Add(New KeyValuePair(Of String, String)("UNKNOWN", "CREATED"))
        routing.Add(New KeyValuePair(Of String, String)("UNKNOWN", "DOC_COMMITTED"))
        Dim expected As PayFirstOutcome() = New PayFirstOutcome() {PayFirstOutcome.Finish, PayFirstOutcome.Finish, PayFirstOutcome.Confirmation, PayFirstOutcome.Busy, PayFirstOutcome.Manual, PayFirstOutcome.Busy, PayFirstOutcome.Finish}
        Dim allRouted As Boolean = True
        Dim noCalls As Boolean = True
        For i As Integer = 0 To routing.Count - 1
            Dim f As New FakePayPal()
            Dim c As PayPalPayFirstContext = ForcedAttempt(routing(i).Key, routing(i).Value)
            Dim res As PayFirstResult = StartIt(c, f)
            If res.Outcome <> expected(i) Then
                allRouted = False
                Console.WriteLine("DETAIL S15 state=" & routing(i).Key & " previous=" & routing(i).Value & " got=" & res.Outcome.ToString() & " reason=" & res.Reason)
            End If
            If f.Requests.Count > 0 Then noCalls = False
        Next
        Check("S15 instradamento per stato dall'avvio (ripresa, conferma, attesa, manuale) senza nuove chiamate PayPal", allRouted AndAlso noCalls)

        Dim approved As New FakePayPal()
        Dim ctxA As PayPalPayFirstContext = NewCtx()
        Dim aa As PayPalAttemptRecord = StartedAndApproved(ctxA, approved)
        Dim ra As PayFirstResult = StartIt(ctxA, approved)
        Check("S16 ordine gia approvato: si va al ritorno con il token dell'ordine", ra.Outcome = PayFirstOutcome.ReturnRedirect AndAlso ra.Url.Contains("/paypalreturn.aspx?k=" & aa.AttemptKey) AndAlso
              ra.Url.Contains("token=" & aa.PayPalOrderId))

        Dim gone As New FakePayPal()
        Dim ctxG As PayPalPayFirstContext = NewCtx()
        StartIt(ctxG, gone)
        Dim ag As PayPalAttemptRecord = Latest(ctxG)
        gone.Orders(ag.PayPalOrderId).Status = "VOIDED"
        Dim rg As PayFirstResult = StartIt(ctxG, gone)
        Check("S17 ordine PayPal non piu utilizzabile: il tentativo si chiude e si torna al carrello", rg.Outcome = PayFirstOutcome.BackToCart AndAlso StateOf(ag.Id) = "FAILED")

        Dim unavailable As New FakePayPal()
        Dim ctxU As PayPalPayFirstContext = NewCtx()
        StartIt(ctxU, unavailable)
        unavailable.FailNext = "get"
        Dim ru As PayFirstResult = StartIt(ctxU, unavailable)
        Check("S18 lettura dell'ordine non disponibile: attesa, tentativo CREATED invariato", ru.Outcome = PayFirstOutcome.Busy AndAlso Latest(ctxU).Stato = "CREATED")

        Dim voidDoc As New FakePayPal()
        Dim ctxVd As PayPalPayFirstContext = ForcedAttempt("DOC_COMMITTED")
        Dim avd As PayPalAttemptRecord = Latest(ctxVd)
        Exec("UPDATE paypal_checkout_tentativi SET PayPalAuthorizationId='KSVOIDDOCAUTH" & avd.Id.ToString(CultureInfo.InvariantCulture) & "' WHERE Id=" & avd.Id.ToString(CultureInfo.InvariantCulture))
        Dim avd2 As PayPalAttemptRecord = Latest(ctxVd)
        Check("S20 l'annullo di un'autorizzazione non parte da un tentativo con ordine gia creato", Not PayPalPayFirstService.VoidAuthorized(avd2, Cfg(), Client(voidDoc)) AndAlso voidDoc.Count("void") = 0 AndAlso StateOf(avd.Id) = "DOC_COMMITTED")
        Dim noHost As New FakePayPal()
        Dim ctxNh As PayPalPayFirstContext = NewCtx()
        Dim rnh As PayFirstResult = PayPalPayFirstService.Start(ctxNh, Cfg(), Client(noHost), Function(path As String) String.Empty, DateTime.UtcNow)
        Check("S21 host canonico non ricavabile: nessuna chiamata PayPal, il tentativo resta CREATING", rnh.Outcome = PayFirstOutcome.TechnicalError AndAlso noHost.Requests.Count = 0 AndAlso Latest(ctxNh) IsNot Nothing AndAlso Latest(ctxNh).Stato = "CREATING")
        Dim noHost2 As New FakePayPal()
        Dim ctxNh2 As PayPalPayFirstContext = NewCtx()
        Dim approvedNh As PayPalAttemptRecord = StartedAndApproved(ctxNh2, noHost2)
        Dim rnh2 As PayFirstResult = PayPalPayFirstService.Start(ctxNh2, Cfg(), Client(noHost2), Function(path As String) String.Empty, DateTime.UtcNow)
        Check("S22 ordine approvato e host canonico non ricavabile: nessun redirect vuoto", rnh2.Outcome = PayFirstOutcome.TechnicalError AndAlso rnh2.Url = String.Empty AndAlso StateOf(approvedNh.Id) = "CREATED")

        Dim wrongCompany As PayPalPayFirstContext = NewCtx()
        wrongCompany.AziendeId = 9302
        wrongCompany.PagamentiTipoId = 9302
        Dim rw As PayFirstResult = StartIt(wrongCompany, New FakePayPal())
        Check("S19 configurazione di un'altra azienda: errore tecnico, nessun tentativo", rw.Outcome = PayFirstOutcome.TechnicalError AndAlso PayPalPaymentAttempts.LoadLatestForDraft(9302, 7301, wrongCompany.DraftRequestId) Is Nothing)
    End Sub

    ' ----- ritorno -----
    Private Sub RunReturn()
        Dim fake As New FakePayPal()
        fake.AuthorizeResponseAuthId = "KSWRONGAUTHID"
        Dim ctx As PayPalPayFirstContext = NewCtx()
        Dim a As PayPalAttemptRecord = StartedAndApproved(ctx, fake)
        Dim r As PayFirstResult = ReturnIt(a, "return", a.PayPalOrderId, ctx, fake)
        Dim b As PayPalAttemptRecord = Latest(ctx)
        Check("R01 ritorno: si prosegue verso l'ordine con il tentativo AUTHORIZED", r.Outcome = PayFirstOutcome.ProceedToOrder AndAlso b.Stato = "AUTHORIZED")
        Check("R02 una sola authorize, con il request id del tentativo", fake.Count("authorize") = 1 AndAlso fake.LastRequestId("authorize") = a.AuthorizeRequestId)
        Check("R03 l'id dell'autorizzazione e quello del GET dell'ordine, non quello della risposta di authorize", b.PayPalAuthorizationId = fake.Orders(a.PayPalOrderId).AuthId AndAlso b.PayPalAuthorizationId <> "KSWRONGAUTHID")
        Check("R04 la scadenza dell'autorizzazione e registrata", b.AuthorizationExpiresUtc.HasValue AndAlso b.AuthorizationExpiresUtc.Value > DateTime.UtcNow.AddDays(2))
        Dim r2 As PayFirstResult = ReturnIt(b, "return", a.PayPalOrderId, ctx, fake)
        Check("R05 ritorno ripetuto: si prosegue senza una seconda authorize", r2.Outcome = PayFirstOutcome.ProceedToOrder AndAlso fake.Count("authorize") = 1)

        Dim already As New FakePayPal()
        Dim ctxAl As PayPalPayFirstContext = NewCtx()
        Dim aal As PayPalAttemptRecord = StartedAndApproved(ctxAl, already)
        already.Send(New PayPalHttpRequestData With {.Method = "POST", .Url = "https://api-m.paypal.com/v2/checkout/orders/" & aal.PayPalOrderId & "/authorize", .RequestId = aal.AuthorizeRequestId, .Body = "{}"})
        Dim authorizeBefore As Integer = already.Count("authorize")
        Dim ral As PayFirstResult = ReturnIt(aal, "return", aal.PayPalOrderId, ctxAl, already)
        Check("R06 ordine gia autorizzato su PayPal ma tentativo CREATED: si registra senza una seconda authorize", ral.Outcome = PayFirstOutcome.ProceedToOrder AndAlso already.Count("authorize") = authorizeBefore AndAlso Latest(ctxAl).Stato = "AUTHORIZED")

        Dim cancel As New FakePayPal()
        Dim ctxCa As PayPalPayFirstContext = NewCtx()
        Dim aca As PayPalAttemptRecord = StartedAndApproved(ctxCa, cancel)
        Dim callsBefore As Integer = cancel.Requests.Count
        Dim rca As PayFirstResult = ReturnIt(aca, "cancel", aca.PayPalOrderId, ctxCa, cancel)
        Check("R07 annullo del cliente: carrello, nessuna chiamata, il tentativo resta CREATED (riapribile)", rca.Outcome = PayFirstOutcome.BackToCart AndAlso cancel.Requests.Count = callsBefore AndAlso Latest(ctxCa).Stato = "CREATED")

        Dim wrongToken As New FakePayPal()
        Dim ctxW As PayPalPayFirstContext = NewCtx()
        Dim aw As PayPalAttemptRecord = StartedAndApproved(ctxW, wrongToken)
        Dim callsW As Integer = wrongToken.Requests.Count
        Dim rw As PayFirstResult = ReturnIt(aw, "return", "NOT-THE-ORDER", ctxW, wrongToken)
        Check("R08 token PayPal diverso dall'ordine del tentativo: rifiutato senza chiamate", rw.Outcome = PayFirstOutcome.TechnicalError AndAlso wrongToken.Requests.Count = callsW AndAlso Latest(ctxW).Stato = "CREATED")

        Dim noCtx As New FakePayPal()
        Dim ctxN As PayPalPayFirstContext = NewCtx()
        Dim an As PayPalAttemptRecord = StartedAndApproved(ctxN, noCtx)
        Dim rn As PayFirstResult = ReturnIt(an, "return", an.PayPalOrderId, Nothing, noCtx)
        Check("R09 sessione persa: nessuna authorize (nessun fondo trattenuto), tentativo chiuso", rn.Outcome = PayFirstOutcome.BackToCart AndAlso noCtx.Count("authorize") = 0 AndAlso Latest(ctxN).Stato = "FAILED")

        Dim late As New FakePayPal()
        Dim ctxLt As PayPalPayFirstContext = NewCtx()
        Dim alt As PayPalAttemptRecord = StartedAndApproved(ctxLt, late)
        Dim rlt As PayFirstResult = ReturnIt(alt, "return", alt.PayPalOrderId, ctxLt, late, nowOffsetMinutes:=26)
        Check("R10 bozza quasi scaduta al ritorno: nessuna authorize, tentativo chiuso", rlt.Outcome = PayFirstOutcome.BackToCart AndAlso late.Count("authorize") = 0 AndAlso Latest(ctxLt).Stato = "FAILED")

        Dim lostAuth As New FakePayPal()
        Dim ctxLa As PayPalPayFirstContext = NewCtx()
        Dim ala As PayPalAttemptRecord = StartedAndApproved(ctxLa, lostAuth)
        lostAuth.LoseResponseOn = "authorize"
        Dim rla As PayFirstResult = ReturnIt(ala, "return", ala.PayPalOrderId, ctxLa, lostAuth)
        Check("R11 risposta di authorize persa: il GET conferma l'autorizzazione, una sola authorize", rla.Outcome = PayFirstOutcome.ProceedToOrder AndAlso lostAuth.Count("authorize") = 1 AndAlso Latest(ctxLa).Stato = "AUTHORIZED")

        Dim refusedAuth As New FakePayPal()
        Dim ctxRf As PayPalPayFirstContext = NewCtx()
        Dim arf As PayPalAttemptRecord = StartedAndApproved(ctxRf, refusedAuth)
        refusedAuth.FailNext = "authorize"
        refusedAuth.FailStatus = 422
        refusedAuth.FailBody = "{""name"":""UNPROCESSABLE_ENTITY"",""message"":""x"",""debug_id"":""d"",""details"":[{""issue"":""INSTRUMENT_DECLINED""}]}"
        Dim rrf As PayFirstResult = ReturnIt(arf, "return", arf.PayPalOrderId, ctxRf, refusedAuth)
        Check("R12 authorize rifiutata: carrello e tentativo FAILED", rrf.Outcome = PayFirstOutcome.BackToCart AndAlso Latest(ctxRf).Stato = "FAILED")

        Dim transient As New FakePayPal()
        Dim ctxTr As PayPalPayFirstContext = NewCtx()
        Dim atr As PayPalAttemptRecord = StartedAndApproved(ctxTr, transient)
        transient.FailNext = "authorize"
        transient.FailStatus = 500
        Dim rtr As PayFirstResult = ReturnIt(atr, "return", atr.PayPalOrderId, ctxTr, transient)
        Check("R13 authorize non eseguita (500): attesa, tentativo CREATED", rtr.Outcome = PayFirstOutcome.Busy AndAlso Latest(ctxTr).Stato = "CREATED")
        Dim rtr2 As PayFirstResult = ReturnIt(atr, "return", atr.PayPalOrderId, ctxTr, transient)
        Check("R14 al ritorno successivo si autorizza con lo stesso request id", rtr2.Outcome = PayFirstOutcome.ProceedToOrder AndAlso transient.Count("authorize") = 2 AndAlso transient.LastRequestId("authorize") = atr.AuthorizeRequestId)

        Dim race As New FakePayPal()
        Dim ctxRc As PayPalPayFirstContext = NewCtx()
        Dim arc As PayPalAttemptRecord = StartedAndApproved(ctxRc, race)
        race.AfterAuthorize = Sub() Force(arc.Id, "FAILED")
        Dim rrc As PayFirstResult = ReturnIt(arc, "return", arc.PayPalOrderId, ctxRc, race)
        Check("R15 corsa residua (tentativo cambiato durante authorize): autorizzazione orfana annullata con il request id di annullo", rrc.Outcome = PayFirstOutcome.TechnicalError AndAlso race.Count("void") = 1 AndAlso
              race.LastRequestId("void") = arc.VoidRequestId)

        Dim amountMismatch As New FakePayPal()
        Dim ctxAm As PayPalPayFirstContext = NewCtx()
        Dim aam As PayPalAttemptRecord = StartedAndApproved(ctxAm, amountMismatch)
        amountMismatch.AmountOverrideAtGet = "99.99"
        Dim ram As PayFirstResult = ReturnIt(aam, "return", aam.PayPalOrderId, ctxAm, amountMismatch)
        Check("R16 importo dell'ordine PayPal diverso dal tentativo: nessuna authorize", ram.Outcome = PayFirstOutcome.TechnicalError AndAlso amountMismatch.Count("authorize") = 0 AndAlso Latest(ctxAm).Stato = "CREATED")

        Dim notApproved As New FakePayPal()
        Dim ctxNa As PayPalPayFirstContext = NewCtx()
        StartIt(ctxNa, notApproved)
        Dim ana As PayPalAttemptRecord = Latest(ctxNa)
        Dim rna As PayFirstResult = ReturnIt(ana, "return", ana.PayPalOrderId, ctxNa, notApproved)
        Check("R17 ritorno senza approvazione: si rimanda all'approvazione, nessuna authorize", rna.Outcome = PayFirstOutcome.ApprovalRedirect AndAlso notApproved.Count("authorize") = 0)

        Dim stranger As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(ana.AttemptKey, 9302, 7301)
        Dim stranger2 As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(ana.AttemptKey, 9301, 7399)
        Check("R18 il tentativo di un altro login o di un'altra azienda non si carica", stranger Is Nothing AndAlso stranger2 Is Nothing)

        Dim keepAuth As New FakePayPal()
        Dim ctxKa As PayPalPayFirstContext = NewCtx()
        Dim aka As PayPalAttemptRecord = Authorized(ctxKa, keepAuth)
        Dim callsKa As Integer = keepAuth.Requests.Count
        Dim rka As PayFirstResult = ReturnIt(aka, "return", aka.PayPalOrderId, Nothing, keepAuth)
        Check("R19 autorizzazione senza contesto: si chiede di riconfermare, nessun annullo, nessuna chiamata", rka.Outcome = PayFirstOutcome.BackToCart AndAlso keepAuth.Requests.Count = callsKa AndAlso StateOf(aka.Id) = "AUTHORIZED")

        Dim fin As New FakePayPal()
        Dim ctxFi As PayPalPayFirstContext = ForcedAttempt("DOC_COMMITTED")
        Dim afi As PayPalAttemptRecord = Latest(ctxFi)
        Force(afi.Id, "DOC_COMMITTED")
        Exec("UPDATE paypal_checkout_tentativi SET PayPalOrderId='KSFINORDER" & afi.Id.ToString(CultureInfo.InvariantCulture) & "' WHERE Id=" & afi.Id.ToString(CultureInfo.InvariantCulture))
        Dim afi2 As PayPalAttemptRecord = Latest(ctxFi)
        Dim rfi As PayFirstResult = ReturnIt(afi2, "return", afi2.PayPalOrderId, ctxFi, fin)
        Check("R20 ritorno con ordine gia creato: ripresa dell'incasso, nessuna chiamata PayPal", rfi.Outcome = PayFirstOutcome.Finish AndAlso fin.Requests.Count = 0)
    End Sub
End Module
