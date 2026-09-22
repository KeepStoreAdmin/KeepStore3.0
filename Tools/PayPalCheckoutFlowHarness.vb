#If Not PAYPAL_DB_TEST Then
Option Strict On
Option Explicit On

Imports System
Imports System.IO
Imports System.Web
Imports System.Web.SessionState

Public Class OrderStorefrontIdentity
    Public Property CompanyId As Integer
    Public Property UtentiId As Long
    Public Property LoginId As Long
    Public ReadOnly Property IsComplete As Boolean
        Get
            Return CompanyId > 0 AndAlso UtentiId > 0 AndAlso LoginId > 0
        End Get
    End Property
End Class

Public Class PayPalCheckoutConfig
    Public Property AziendeId As Integer
    Public Property IsConfigured As Boolean
End Class

Public Class StorefrontSeoTenantIdentity
    Public Property CompanyId As Integer
    Public Property Host As String
End Class

Public NotInheritable Class StorefrontSeoTenantContext
    Public Shared Function Resolve(ByVal context As HttpContext) As StorefrontSeoTenantIdentity
        Select Case context.Request.Url.Host
            Case "tenant-a.invalid"
                Return New StorefrontSeoTenantIdentity With {.CompanyId = 1, .Host = "tenant-a.invalid"}
            Case "tenant-b.invalid"
                Return New StorefrontSeoTenantIdentity With {.CompanyId = 2, .Host = "tenant-b.invalid"}
            Case Else
                Return Nothing
        End Select
    End Function
End Class

Public NotInheritable Class StorefrontCanonicalHostPolicy
    Public Shared Function IsRequestHostAllowed(ByVal tenant As StorefrontSeoTenantIdentity,
                                                ByVal host As String, ByVal unused As Boolean) As Boolean
        Return tenant IsNot Nothing AndAlso String.Equals(tenant.Host, host, StringComparison.OrdinalIgnoreCase)
    End Function
End Class

Module PayPalCheckoutFlowHarness
    Private _passed As Integer
    Private Sub Check(ByVal condition As Boolean, ByVal name As String)
        If Not condition Then Throw New Exception("PAYPAL_FLOW_FAILED: " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function Context(Optional ByVal url As String = "https://tenant-a.invalid/paypalcheckout.aspx") As HttpContext
        Dim result As New HttpContext(New HttpRequest("", url, ""),
                                      New HttpResponse(New StringWriter()))
        Dim session As New HttpSessionStateContainer("synthetic-session", New SessionStateItemCollection(),
                                                     New HttpStaticObjectsCollection(), 10, True,
                                                     HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(result, session)
        Return result
    End Function

    Sub Main()
        Dim owner As New OrderStorefrontIdentity With {.CompanyId = 1, .UtentiId = 101, .LoginId = 201}
        Dim ctx As HttpContext = Context()
        PayPalWebLaunchContext.Issue(ctx, 9001, owner, "CHECKOUT-ONE")
        Check(Not PayPalWebLaunchContext.Consume(ctx, 9002, owner), "wrong document blocked")
        Check(PayPalWebLaunchContext.Consume(ctx, 9001, owner), "wrong document did not erase correct context")
        PayPalWebLaunchContext.Issue(ctx, 9001, owner, "CHECKOUT-ONE")
        Check(PayPalWebLaunchContext.BeginPayPal(ctx, 9001, owner), "web launch initially authorized")
        Check(PayPalWebLaunchContext.BindPayPalAttempt(ctx, 9001, owner, 1, "PP-CREATE-1-9001-1", "exact-payload"), "web attempt bound")
        Check(PayPalWebLaunchContext.BeginPayPal(ctx, 9001, owner), "OAuth timeout permits same technical continuation")
        Check(PayPalWebLaunchContext.BindPayPalAttempt(ctx, 9001, owner, 1, "PP-CREATE-1-9001-1", "exact-payload"), "same attempt and payload accepted")
        Check(Not PayPalWebLaunchContext.BindPayPalAttempt(ctx, 9001, owner, 1, "PP-CREATE-1-9001-1", "different-payload"), "changed payload blocked")
        Check(Not PayPalWebLaunchContext.BindPayPalAttempt(ctx, 9001, owner, 2, "PP-CREATE-1-9001-2", "exact-payload"), "new web attempt blocked")
        Check(Not PayPalWebLaunchContext.BeginPayPal(ctx, 9002, owner), "other document blocked")
        Check(PayPalWebLaunchContext.BeginPayPal(ctx, 9001, owner), "other document did not consume valid launch")
        Dim otherOwner As New OrderStorefrontIdentity With {.CompanyId = 1, .UtentiId = 102, .LoginId = 202}
        Dim otherTenant As New OrderStorefrontIdentity With {.CompanyId = 2, .UtentiId = 101, .LoginId = 201}
        Check(Not PayPalWebLaunchContext.BeginPayPal(ctx, 9001, otherOwner), "other owner blocked")
        Check(Not PayPalWebLaunchContext.BeginPayPal(ctx, 9001, otherTenant), "other tenant blocked")
        PayPalWebLaunchContext.FinishPayPal(ctx, 9001, owner)
        Check(Not PayPalWebLaunchContext.BeginPayPal(ctx, 9001, owner), "handoff closes web launch")

        PayPalWebLaunchContext.Issue(ctx, 9001, owner, "CHECKOUT-TWO")
        DirectCast(ctx.Session("KeepStore:PayPal:WebLaunch"), PayPalWebLaunchContext).IssuedUtc = DateTime.UtcNow.AddMinutes(-6)
        Check(Not PayPalWebLaunchContext.BeginPayPal(ctx, 9001, owner), "expired context blocked")
        PayPalWebLaunchContext.Issue(ctx, 9001, owner, "CHECKOUT-SELLA", "SELLA", 12.34D)
        Check(Not PayPalWebLaunchContext.Consume(ctx, 9002, owner, "SELLA", 12.34D), "Sella other document blocked")
        Check(PayPalWebLaunchContext.Consume(ctx, 9001, owner, "SELLA", 12.34D), "Sella initial launch preserved")
        Check(Not PayPalWebLaunchContext.Consume(ctx, 9001, owner, "SELLA", 12.34D), "Sella launch one-shot")

        Check(Not PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("https", True, True, "tenant-a.invalid", "203.0.113.10", "203.0.113.11"), "local runtime blocked")
        Check(Not PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("https", True, False, "localhost", "203.0.113.10", "203.0.113.11"), "localhost host blocked")
        Check(Not PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("https", True, False, "tenant-a.invalid", "127.0.0.1", "203.0.113.11"), "loopback client blocked")
        Check(Not PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("https", True, False, "tenant-a.invalid", "203.0.113.10", "127.0.0.1"), "loopback listener blocked")
        Check(Not PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("http", False, False, "tenant-a.invalid", "203.0.113.10", "203.0.113.11"), "HTTP blocked")
        Check(PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed("https", True, False, "tenant-a.invalid", "203.0.113.10", "203.0.113.11"), "non-local HTTPS eligible")
        Dim ingressA As New StorefrontSeoTenantIdentity With {.CompanyId = 1, .Host = "tenant-a.invalid"}
        Check(PayPalCheckoutSafetyPolicy.CanUseLiveWebhookIngress("https", True, False, "tenant-a.invalid", "203.0.113.10", "203.0.113.11", ingressA), "authorized webhook ingress")
        Check(Not PayPalCheckoutSafetyPolicy.CanUseLiveWebhookIngress("https", True, False, "unknown.invalid", "203.0.113.10", "203.0.113.11", Nothing), "unknown webhook host blocked")
        Check(Not PayPalCheckoutSafetyPolicy.CanUseLiveWebhookIngress("https", True, False, "localhost", "203.0.113.10", "203.0.113.11", ingressA), "localhost webhook blocked")
        Check(PayPalCheckoutSafetyPolicy.CanUseLiveWebhookIngress("https", True, False, "tenant-a.invalid", "203.0.113.10", "203.0.113.11", ingressA), "shared account accepts tenant B event on authorized A ingress")
        Console.WriteLine("PAYPAL_FLOW_TOTAL=" & _passed.ToString())
    End Sub
End Module
#Else
Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Threading
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class PayPalPaymentDocumentInfo
    Public Property DocumentId As Integer
    Public Property UtentiId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property OrigineOrdine As String
    Public Property TotalDocument As Decimal
End Class

Public Module PayPalPaymentState
    Public Const PAYPAL_ONLINE_VALUE As Integer = 2
    Public Function SanitizeExternalId(ByVal value As String) As String
        Return If(value, String.Empty).Trim()
    End Function
    Public Function BuildOrderMarker(ByVal value As String) As String
        Return "PP-ORDER:" & SanitizeExternalId(value)
    End Function
    Public Function BuildCaptureMarker(ByVal value As String) As String
        Return "TXN:" & SanitizeExternalId(value)
    End Function
End Module

Public NotInheritable Class KeepStoreLog
    Public Shared Sub [Error](ByVal category As String, ByVal message As String, ByVal ex As Exception, ByVal context As HttpContext)
        Dim missing As FileNotFoundException = TryCast(ex, FileNotFoundException)
        Dim loadFailed As FileLoadException = TryCast(ex, FileLoadException)
        Throw New Exception("ISOLATED_REPOSITORY_FAILURE: " & ex.GetType().Name &
            If(missing Is Nothing, String.Empty, " " & missing.FileName) &
            If(loadFailed Is Nothing, String.Empty, " " & loadFailed.FileName))
    End Sub
End Class

Module PayPalCheckoutPersistenceHarness
    Private _passed As Integer
    Private ReadOnly _cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    Private Sub Check(ByVal result As Boolean, ByVal name As String)
        If Not result Then Throw New Exception("PAYPAL_DB_FAILED: " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Sub Execute(ByVal conn As MySqlConnection, ByVal sql As String)
        Using cmd As New MySqlCommand(sql, conn)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Function Scalar(ByVal sql As String) As String
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using cmd As New MySqlCommand(sql, conn)
                Return Convert.ToString(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
            End Using
        End Using
    End Function

    Private Function Attempt(ByVal docId As Integer, ByVal company As Integer, ByVal txId As Integer) As PayPalCheckoutTransactionInfo
        Return New PayPalCheckoutTransactionInfo With {.Exists = True, .Id = txId, .DocumentiId = docId,
            .AziendeId = company, .PagamentiTipoId = 19, .PayPalAccountId = 1,
            .PayPalOrderId = "ORDER-" & docId.ToString(CultureInfo.InvariantCulture),
            .Importo = 12.34D, .Valuta = "EUR", .IsCurrent = True}
    End Function

    Private Function Snapshot(ByVal docId As Integer, ByVal captureId As String,
                              ByVal amount As Decimal, ByVal valid As Boolean) As PayPalOrderSnapshot
        Return New PayPalOrderSnapshot With {.OrderId = "ORDER-" & docId.ToString(CultureInfo.InvariantCulture),
            .Status = "COMPLETED", .CaptureId = captureId, .CaptureStatus = "COMPLETED",
            .CaptureCount = 1, .CaptureAmount = amount, .CaptureCurrencyCode = "EUR", .CaptureAmountValid = valid}
    End Function

    Sub Main()
        Dim settings As New MySqlConnectionStringBuilder(_cs)
        Dim labName As String = settings.Database
        If Not labName.StartsWith("ks_paypal_rev3_", StringComparison.Ordinal) OrElse
           Not String.Equals(settings.Server, "localhost", StringComparison.OrdinalIgnoreCase) OrElse
           Not _cs.Contains("Protocol=pipe") OrElse Not _cs.Contains("Pipe Name=KS_PAYPAL_REV2_PIPE") Then
            Throw New Exception("ISOLATED_DATABASE_REQUIRED")
        End If
        Dim master As New MySqlConnectionStringBuilder(_cs)
        master.Database = "mysql"
        Dim created As Boolean = False
        Using admin As New MySqlConnection(master.ConnectionString)
            admin.Open()
            Try
                Using check As New MySqlCommand("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=@name", admin)
                    check.Parameters.Add("@name", MySqlDbType.VarChar, 64).Value = labName
                    If Convert.ToInt32(check.ExecuteScalar(), CultureInfo.InvariantCulture) <> 0 Then Throw New Exception("LAB_DATABASE_ALREADY_EXISTS")
                End Using
                Execute(admin, "CREATE DATABASE `" & labName & "` CHARACTER SET utf8mb4")
                created = True
                Using conn As New MySqlConnection(_cs)
                    conn.Open()
                    Execute(conn, "CREATE TABLE documenti (Id int PRIMARY KEY,AziendeId int,UtentiId int,PagamentiTipoId int,Pagato int,OrigineOrdine varchar(16),StatoPagamentoWeb int,IdTransazione varchar(150),DataStatoPagamentoWeb datetime,UltimoEsitoPagamentoWeb varchar(255)) ENGINE=InnoDB")
                    Execute(conn, "CREATE TABLE documentipie (DocumentiId int PRIMARY KEY,TotaleDocumento decimal(15,2)) ENGINE=InnoDB")
                    Execute(conn, "CREATE TABLE paypal_checkout_transazioni (Id bigint AUTO_INCREMENT PRIMARY KEY,DocumentiId int,TentativoNo int,CurrentSlot int,AziendeId int,PagamentiTipoId int,PayPalAccountId int,PayPalOrderId varchar(100),PayPalCaptureId varchar(100),Stato varchar(40),Importo decimal(15,2),Valuta char(3),PayeeEmail varchar(254),MerchantId varchar(128),CreateRequestId varchar(80),CaptureRequestId varchar(80),UltimoEsito varchar(255),UpdatedAt timestamp DEFAULT CURRENT_TIMESTAMP,UNIQUE KEY UX_doc_attempt(DocumentiId,TentativoNo),UNIQUE KEY UX_doc_current(DocumentiId,CurrentSlot)) ENGINE=InnoDB")
                    Execute(conn, "CREATE TABLE paypal_checkout_eventi (Id bigint AUTO_INCREMENT PRIMARY KEY,EventId varchar(100) UNIQUE,TransazioniId bigint,EventType varchar(80),CaptureId varchar(100),Stato varchar(40)) ENGINE=InnoDB")
                    For index As Integer = 1 To 3
                        Dim docId As Integer = 9000 + index
                        Execute(conn, "INSERT INTO documenti (Id,AziendeId,UtentiId,PagamentiTipoId,Pagato,OrigineOrdine) VALUES (" & docId & "," & If(index = 3, 2, 1) & ",101,19,0,'WEB')")
                        Execute(conn, "INSERT INTO documentipie VALUES (" & docId & ",12.34)")
                        Execute(conn, "INSERT INTO paypal_checkout_transazioni (Id,DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,PayPalOrderId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId) VALUES (" & index & "," & docId & ",1,1," & If(index = 3, 2, 1) & ",19,1,'ORDER-" & docId & "','APPROVED',12.34,'EUR','lab@example.invalid','LAB','CREATE-LAB-" & index & "','CAPTURE-LAB-" & index & "')")
                    Next
                    Execute(conn, "INSERT INTO documenti (Id,AziendeId,UtentiId,PagamentiTipoId,Pagato,OrigineOrdine) VALUES (9004,1,101,19,0,'WEB')")
                    Execute(conn, "INSERT INTO documentipie VALUES (9004,12.34)")
                End Using
                Dim freshDoc As New PayPalPaymentDocumentInfo With {.DocumentId = 9004, .AziendeId = 1,
                    .UtentiId = 101, .PagamentiTipoId = 19, .OrigineOrdine = "WEB", .TotalDocument = 12.34D}
                Dim freshConfig As New PayPalCheckoutConfig With {.AccountId = 1, .CurrencyCode = "EUR",
                    .PayeeEmail = "lab@example.invalid", .MerchantId = "LAB"}
                Dim createdAttempts(1) As PayPalCheckoutTransactionInfo
                Dim createA As New Thread(Sub() createdAttempts(0) = PayPalCheckoutRepository.EnsureTransaction(freshDoc, freshConfig))
                Dim createB As New Thread(Sub() createdAttempts(1) = PayPalCheckoutRepository.EnsureTransaction(freshDoc, freshConfig))
                createA.Start() : createB.Start() : createA.Join() : createB.Join()
                Check(createdAttempts(0) IsNot Nothing AndAlso createdAttempts(1) IsNot Nothing AndAlso
                    createdAttempts(0).Exists AndAlso createdAttempts(1).Exists AndAlso createdAttempts(0).Id = createdAttempts(1).Id AndAlso
                    createdAttempts(0).CreateRequestId = createdAttempts(1).CreateRequestId AndAlso
                    Scalar("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=9004") = "1",
                    "concurrent Web refresh reuses one attempt and RequestId")
                Dim tx As PayPalCheckoutTransactionInfo = Attempt(9001, 1, 1)
                Check(Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, Snapshot(9001, "CAPTURE-1", 0D, False), "EV-INVALID"), "missing captured amount fails closed")
                Check(Not PayPalCheckoutRepository.ApplyAuthoritativeState(tx, Snapshot(9001, "CAPTURE-1", 10D, True), "EV-PARTIAL"), "partial capture fails closed")
                Check(Scalar("SELECT Pagato FROM documenti WHERE Id=9001") = "0" AndAlso Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi") = "0", "invalid capture no document or event DML")
                Dim cross As PayPalCheckoutTransactionInfo = Attempt(9001, 2, 1)
                Check(Not PayPalCheckoutRepository.ApplyAuthoritativeState(cross, Snapshot(9001, "CAPTURE-1", 12.34D, True), "EV-CROSS"), "cross-tenant transaction blocked")
                Check(PayPalCheckoutRepository.ApplyAuthoritativeState(tx, Snapshot(9001, "CAPTURE-1", 12.34D, True), "EV-VALID"), "valid full capture persisted")
                Check(Scalar("SELECT Pagato FROM documenti WHERE Id=9001") = "1" AndAlso Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi WHERE TransazioniId=1") = "1", "one paid document and event")
                Dim txB As PayPalCheckoutTransactionInfo = Attempt(9003, 2, 3)
                Check(PayPalCheckoutRepository.ApplyAuthoritativeState(txB, Snapshot(9003, "CAPTURE-B", 12.34D, True), "EV-B"), "shared account tenant B paid separately")
                Check(Scalar("SELECT Pagato FROM documenti WHERE Id=9003") = "1", "tenant B owner-scoped state")
                Dim txConcurrent As PayPalCheckoutTransactionInfo = Attempt(9002, 1, 2)
                Dim concurrently As PayPalOrderSnapshot = Snapshot(9002, "CAP-CONCURRENT", 12.34D, True)
                Dim results(1) As Boolean
                Dim first As New Thread(Sub() results(0) = PayPalCheckoutRepository.ApplyAuthoritativeState(txConcurrent, concurrently, "EV-CONCURRENT"))
                Dim second As New Thread(Sub() results(1) = PayPalCheckoutRepository.ApplyAuthoritativeState(txConcurrent, concurrently, "EV-CONCURRENT"))
                first.Start() : second.Start() : first.Join() : second.Join()
                Check(results(0) AndAlso results(1), "concurrent replay resolved")
                Check(Scalar("SELECT Pagato FROM documenti WHERE Id=9002") = "1" AndAlso Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi WHERE TransazioniId=2") = "1", "concurrent replay one paid state and event")
                Console.WriteLine("PAYPAL_DB_TOTAL=" & _passed.ToString(CultureInfo.InvariantCulture))
            Finally
                If created Then Execute(admin, "DROP DATABASE `" & labName & "`")
            End Try
        End Using
    End Sub
End Module
#End If
