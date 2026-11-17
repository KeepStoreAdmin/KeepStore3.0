Option Strict On
Option Explicit On

' Harness per Test-PayPalAttemptRepositoryRealSchema.ps1 (PAYPAL-ATTEMPTS-TABLE-1A, fase P2 del pay-first).
' Compila insieme al codice REALE di App_Code (PayPalPaymentAttempts, PayPalPaymentAttemptStates, ...) e lo esegue contro il database LAB LOCALE con il
' connettore MySql.Data reale e lo schema reale (tabella creata dallo script della pagina docs), in due varianti di TreatTinyAsBoolean.
' Mai segreti nel file: utente e password del LAB arrivano dall'ambiente del processo (KS_LAB_*), la stringa di connessione resta in memoria.
' Dati sintetici con ID alti (9201..9220), rimossi in ogni caso a fine corsa. Uscita: numero di controlli falliti (0 = verde); 2 = ambiente non pronto.

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Reflection
Imports System.Threading
Imports MySql.Data.MySqlClient

Public Class FailFastException
    Inherits Exception
End Class

Public Module AttemptRepositoryHarness
    Private _failFast As Boolean = False
    Private _cs As String = String.Empty
    Private _tiny As Boolean = True
    Private _pass As Integer = 0
    Private _fail As Integer = 0
    Private _counter As Integer = 0
    Private _threadErrors As Integer = 0
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const Scope As String = "KS_TEST_ATT_SCOPE"
    Private Const KeyA As String = "KS_TEST_ATT_A"
    Private Const KeyB As String = "KS_TEST_ATT_B"
    Private Const FirstDoc As Integer = 9201
    Private Const LastDoc As Integer = 9260
    Private _userId As Integer = 1
    Private _typeId As Integer = 0
    Private _accountA As Integer = 0
    Private _accountB As Integer = 0
    Private _docCursor As Integer = FirstDoc + 12

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

    ' True se l'istruzione viene rifiutata dal database (vincolo, unique, chiave esterna).
    Private Function Rejected(ByVal sql As String) As Boolean
        Try
            Exec(sql)
            Return False
        Catch ex As MySqlException
            Return True
        End Try
    End Function

    Private Function Next32() As String
        Return Guid.NewGuid().ToString("N")
    End Function

    Private Function Uniq(ByVal prefix As String) As String
        Dim n As Integer = Interlocked.Increment(_counter)
        Return prefix & System.Diagnostics.Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture) & "X" & n.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function IdOf(ByVal r As PayPalAttemptRecord) As Long
        Return If(r Is Nothing, -1L, r.Id)
    End Function

    Private Function StateOf(ByVal id As Long) As String
        Return Scalar("SELECT Stato FROM paypal_checkout_tentativi WHERE Id=" & id.ToString(CultureInfo.InvariantCulture))
    End Function

    Private Function Req(ByVal company As Integer, ByVal login As Long, ByVal draft As String, ByVal fingerprint As String) As PayPalAttemptCreateRequest
        Return New PayPalAttemptCreateRequest With {
            .AziendeId = company, .LoginId = login, .UtentiId = _userId, .PagamentiTipoId = company, .PayPalAccountId = If(company = 9201, _accountA, _accountB),
            .DatabaseScopeKey = Scope, .DraftRequestId = draft, .PayloadFingerprint = fingerprint,
            .DraftExpiresUtc = DateTime.UtcNow.AddMinutes(30), .Importo = 12.34D, .Valuta = "EUR",
            .PayeeEmail = If(company = 9201, "fixture-a@example.invalid", "fixture-b@example.invalid"), .MerchantId = If(company = 9201, "KSMERCHANTA", "KSMERCHANTB")}
    End Function

    Private Function NewAttempt(Optional ByVal login As Long = 7001) As PayPalAttemptRecord
        Dim r As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, login, Next32(), "fp-" & Next32()))
        If r.Outcome <> PayPalAttemptCreateOutcome.Created OrElse r.Attempt Is Nothing Then
            Check("A05 helper: a new attempt is created", False)
            Throw New InvalidOperationException("NEW_ATTEMPT_NOT_CREATED")
        End If
        Return r.Attempt
    End Function

    Private Function ToCreated(ByVal a As PayPalAttemptRecord) As PayPalAttemptRecord
        Dim order As String = Uniq("KSORD")
        Dim moved As Boolean = PayPalPaymentAttempts.RecordOrderCreated(a.Id, a.AziendeId, a.LoginId, order)
        Dim loaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(a.AttemptKey, a.AziendeId, a.LoginId)
        If Not moved OrElse loaded Is Nothing OrElse loaded.PayPalOrderId <> order Then
            Check("A01 helper: the order id is stored by RecordOrderCreated", False)
            Throw New InvalidOperationException("TO_CREATED")
        End If
        Return loaded
    End Function

    Private Function ToAuthorized(ByVal a As PayPalAttemptRecord) As PayPalAttemptRecord
        Dim c As PayPalAttemptRecord = ToCreated(a)
        Dim authId As String = Uniq("KSAUTH")
        Dim moved As Boolean = PayPalPaymentAttempts.RecordAuthorized(c.Id, c.AziendeId, c.LoginId, c.PayPalOrderId, authId, DateTime.UtcNow.AddDays(3))
        Dim loaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(c.AttemptKey, c.AziendeId, c.LoginId)
        If Not moved OrElse loaded Is Nothing OrElse loaded.Stato <> "AUTHORIZED" OrElse loaded.PayPalAuthorizationId <> authId Then
            Check("A02 helper: RecordAuthorized stores the authorization", False)
            Throw New InvalidOperationException("TO_AUTHORIZED")
        End If
        Return loaded
    End Function

    Private Function BindInTx(ByVal a As PayPalAttemptRecord, ByVal docId As Integer, Optional ByVal commit As Boolean = True) As Boolean
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using tx As MySqlTransaction = conn.BeginTransaction(IsolationLevel.Serializable)
                Dim locked As PayPalAttemptRecord = PayPalPaymentAttempts.LockForDocument(conn, tx, a.Id, a.AziendeId, a.LoginId)
                Dim bound As Boolean = locked IsNot Nothing AndAlso locked.Stato = "AUTHORIZED" AndAlso PayPalPaymentAttempts.BindDocument(conn, tx, a.Id, a.AziendeId, a.LoginId, docId)
                If commit AndAlso bound Then tx.Commit() Else tx.Rollback()
                Return bound
            End Using
        End Using
    End Function

    Private Function NextDoc() As Integer
        _docCursor += 1
        If _docCursor > LastDoc Then Throw New InvalidOperationException("OUT_OF_FIXTURE_DOCS")
        Return _docCursor
    End Function

    Private Function ToDocCommitted(ByVal a As PayPalAttemptRecord) As PayPalAttemptRecord
        Dim auth As PayPalAttemptRecord = ToAuthorized(a)
        Dim bound As Boolean = BindInTx(auth, NextDoc())
        Dim loaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(auth.AttemptKey, auth.AziendeId, auth.LoginId)
        If Not bound OrElse loaded Is Nothing OrElse loaded.Stato <> "DOC_COMMITTED" Then
            Check("A03 helper: BindDocument commits an authorized attempt", False)
            Throw New InvalidOperationException("TO_DOC_COMMITTED")
        End If
        Return loaded
    End Function

    Private Function ToCapturing(ByVal a As PayPalAttemptRecord) As PayPalAttemptRecord
        Dim d As PayPalAttemptRecord = ToDocCommitted(a)
        Dim started As Boolean = PayPalPaymentAttempts.BeginCapture(d.Id, d.AziendeId) = PayPalBeginCaptureOutcome.Started
        Dim loaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(d.AttemptKey, d.AziendeId, d.LoginId)
        If Not started OrElse loaded Is Nothing OrElse loaded.Stato <> "CAPTURING" Then
            Check("A04 helper: BeginCapture starts a committed attempt", False)
            Throw New InvalidOperationException("TO_CAPTURING")
        End If
        Return loaded
    End Function

    Private Function RunThreads(ByVal count As Integer, ByVal work As Action(Of Integer)) As Integer
        Dim errors As Integer = 0
        Dim threads As New List(Of Thread)()
        Dim start As New ManualResetEvent(False)
        For i As Integer = 0 To count - 1
            Dim index As Integer = i
            Dim t As New Thread(Sub()
                                    start.WaitOne()
                                    Try
                                        work(index)
                                    Catch ex As Exception
                                        Interlocked.Increment(errors)
                                        Console.WriteLine("THREAD_ERROR " & ex.GetType().Name & " " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
                                    End Try
                                End Sub)
            t.IsBackground = True
            threads.Add(t)
            t.Start()
        Next
        start.Set()
        For Each t As Thread In threads
            t.Join(60000)
        Next
        Return errors
    End Function

    ' Valore di riferimento per la matrice delle transizioni dirette (scritto a mano: e l'oracolo della macchina a stati).
    Private Function ExpectedDirect() As Dictionary(Of String, String())
        Dim d As New Dictionary(Of String, String())()
        d("CREATING") = New String() {"CREATED", "FAILED", "UNKNOWN"}
        d("CREATED") = New String() {"AUTHORIZED", "CANCELED", "FAILED", "UNKNOWN"}
        d("AUTHORIZED") = New String() {"DOC_COMMITTED", "VOIDING", "FAILED", "CAPTURED_ORPHAN", "UNKNOWN"}
        d("VOIDING") = New String() {"VOIDED", "CAPTURED_ORPHAN", "UNKNOWN"}
        d("DOC_COMMITTED") = New String() {"CAPTURING", "COMPLETED", "VOIDING", "UNKNOWN"}
        d("CAPTURING") = New String() {"COMPLETED", "CAPTURE_REFUSED", "UNKNOWN"}
        d("CAPTURE_REFUSED") = New String() {"COMPLETED", "VOIDING"}
        d("VOIDED") = New String() {"CAPTURED_ORPHAN"}
        d("FAILED") = New String() {"CAPTURED_ORPHAN"}
        d("CANCELED") = New String() {"CAPTURED_ORPHAN"}
        d("COMPLETED") = New String() {}
        d("CAPTURED_ORPHAN") = New String() {}
        d("UNKNOWN") = New String() {}
        Return d
    End Function

    Private Function ExpectedResolve() As Dictionary(Of String, String())
        Dim d As New Dictionary(Of String, String())()
        d("CREATING") = New String() {"CREATING", "CREATED", "FAILED"}
        d("CREATED") = New String() {"CREATED", "AUTHORIZED", "CANCELED", "FAILED"}
        d("AUTHORIZED") = New String() {"AUTHORIZED", "VOIDING", "CAPTURED_ORPHAN"}
        d("VOIDING") = New String() {"VOIDING", "VOIDED", "CAPTURED_ORPHAN"}
        d("DOC_COMMITTED") = New String() {"DOC_COMMITTED", "CAPTURING", "COMPLETED", "VOIDING"}
        d("CAPTURING") = New String() {"CAPTURING", "COMPLETED", "CAPTURE_REFUSED"}
        Return d
    End Function

    Public Function Main(ByVal args As String()) As Integer
        For Each arg As String In args
            If String.Equals(arg, "tiny=false", StringComparison.OrdinalIgnoreCase) Then _tiny = False
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
        ' Solo loopback e identita del server verificata dopo la connessione; VerifyCA richiederebbe BouncyCastle.Crypto 1.9 non presente in Bin.
        sb.SslMode = MySqlSslMode.Required
        sb.TreatTinyAsBoolean = _tiny
        sb.MaximumPoolSize = 64
        _cs = sb.ConnectionString
        labCredential = String.Empty

        Dim coll As ConnectionStringSettingsCollection = ConfigurationManager.ConnectionStrings
        Dim readOnlyField As FieldInfo = GetType(ConfigurationElementCollection).GetField("bReadOnly", BindingFlags.Instance Or BindingFlags.NonPublic)
        readOnlyField.SetValue(coll, False)
        coll.Add(New ConnectionStringSettings("EntropicConnectionString", _cs))

        Console.WriteLine("VARIANT TreatTinyAsBoolean=" & _tiny.ToString())
        Try
            If Scalar("SELECT @@server_uuid") <> LabUuid OrElse Scalar("SELECT @@port") <> port OrElse Scalar("SELECT DATABASE()") <> schema OrElse Not schema.StartsWith("keepstore_regorder_lab", StringComparison.Ordinal) Then
                Console.WriteLine("LAB_IDENTITY_MISMATCH")
                Return 2
            End If
            If Scalar("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi'") <> "1" Then
                Console.WriteLine("LAB_SCHEMA_NOT_READY")
                Return 2
            End If
            If Scalar("SELECT (SELECT COUNT(*) FROM documenti WHERE Id BETWEEN " & FirstDoc & " AND " & LastDoc & " AND AziendeId NOT IN (9201,9202))+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9201,9202) AND AziendeID NOT IN (9201,9202))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9201,9202) AND PayeeEmail NOT LIKE '%@example.invalid')+(SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE AziendeId IN (9201,9202) AND DatabaseScopeKey<>'" & Scope & "')") <> "0" Then
                Console.WriteLine("LAB_FIXTURE_ID_COLLISION")
                Return 2
            End If
        Catch ex As Exception
            Dim detail As String = String.Empty
            Dim fnf As System.IO.FileNotFoundException = TryCast(ex, System.IO.FileNotFoundException)
            If fnf IsNot Nothing Then detail = " file=" & Convert.ToString(fnf.FileName)
            Console.WriteLine("LAB_PREFLIGHT_FAILED " & ex.GetType().Name & detail)
            Return 2
        End Try

        Try
            Cleanup()
            Setup()
            RunVariantEffective()
            RunStateMachine()
            RunSchemaRules()
            RunCreateAndLoad()
            RunTransitions()
            RunDocumentBinding()
            RunCapture()
            RunUnknownAndOrphans()
            RunConcurrency()
            RunListings()
        Catch ex As FailFastException
            ' primo controllo caduto: ci si ferma qui, la pulizia segue nel Finally
        Catch ex As Exception
            _fail += 1
            Console.WriteLine("FAIL harness-exception-" & ex.GetType().Name)
            Console.WriteLine("EXC " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
        Finally
            Try
                Cleanup()
                _failFast = False
                Check("cleanup-no-residue", Scalar("SELECT (SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='" & Scope & "' OR AziendeId IN (9201,9202))+(SELECT COUNT(*) FROM documenti WHERE Id BETWEEN " & FirstDoc & " AND " & LastDoc & ")+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9201,9202))+(SELECT COUNT(*) FROM paypal_checkout_account WHERE CredentialKey IN ('" & KeyA & "','" & KeyB & "'))+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9201,9202))") = "0")
            Catch ex As Exception
                Check("cleanup-exception-" & ex.GetType().Name, False)
            End Try
        End Try
        Console.WriteLine("RESULT variant=" & _tiny.ToString() & " pass=" & _pass.ToString(CultureInfo.InvariantCulture) & " fail=" & _fail.ToString(CultureInfo.InvariantCulture))
        Return _fail
    End Function

    Private Sub Cleanup()
        Exec("DELETE FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='" & Scope & "' OR AziendeId IN (9201,9202)")
        Exec("DELETE FROM paypal_checkout_azienda WHERE AziendeId IN (9201,9202)")
        Exec("DELETE FROM paypal_checkout_account WHERE CredentialKey IN ('" & KeyA & "','" & KeyB & "')")
        Exec("DELETE FROM documentipie WHERE DocumentiId BETWEEN " & FirstDoc & " AND " & LastDoc)
        Exec("DELETE FROM documenti WHERE Id BETWEEN " & FirstDoc & " AND " & LastDoc)
        Exec("DELETE FROM pagamentitipo WHERE id IN (9201,9202)")
    End Sub

    Private Sub Setup()
        _userId = Integer.Parse(Scalar("SELECT COALESCE(MIN(UtentiId),1) FROM documenti WHERE UtentiId > 0"), CultureInfo.InvariantCulture)
        _typeId = Integer.Parse(Scalar("SELECT COALESCE(MIN(TipoDocumentiId),0) FROM documenti WHERE TipoDocumentiId > 0"), CultureInfo.InvariantCulture)
        For Each companyId As Integer In New Integer() {9201, 9202}
            Exec("INSERT INTO pagamentitipo (id,AziendeID,Descrizione,Informazioni,Abilitato,Web,Ordinamento,Predefinito,CostoPercentuale,CostoFisso,CostoMassimo,NumeroOrdini,Contrassegno,OnLine,Cassa,Banca) VALUES (" &
                 companyId & "," & companyId & ",'KS TEST ATTEMPT','fixture',1,1,1,0,0,0,5000,0,0,2,0,0)")
        Next
        Exec("INSERT INTO paypal_checkout_account (NomeProfilo,CredentialKey,MerchantId,Attivo,ClientId,ClientSecret,WebhookId) VALUES ('KS TEST ATT A','" & KeyA & "','KSMERCHANTA',1,'ks-fixture-client-a','ks-fixture-secret-a','ks-fixture-webhook-a')")
        _accountA = Integer.Parse(Scalar("SELECT Id FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'"), CultureInfo.InvariantCulture)
        Exec("INSERT INTO paypal_checkout_account (NomeProfilo,CredentialKey,MerchantId,Attivo,ClientId,ClientSecret,WebhookId) VALUES ('KS TEST ATT B','" & KeyB & "','KSMERCHANTB',1,'ks-fixture-client-b','ks-fixture-secret-b','ks-fixture-webhook-b')")
        _accountB = Integer.Parse(Scalar("SELECT Id FROM paypal_checkout_account WHERE CredentialKey='" & KeyB & "'"), CultureInfo.InvariantCulture)
        Exec("INSERT INTO paypal_checkout_azienda (AziendeId,PagamentiTipoId,PayPalAccountId,PayeeEmail,BrandName,CurrencyCode,Attivo) VALUES (9201,9201," & _accountA & ",'fixture-a@example.invalid','KS TEST ATT A','EUR',1)")
        Exec("INSERT INTO paypal_checkout_azienda (AziendeId,PagamentiTipoId,PayPalAccountId,PayeeEmail,BrandName,CurrencyCode,Attivo) VALUES (9202,9202," & _accountB & ",'fixture-b@example.invalid','KS TEST ATT B','EUR',1)")
        For doc As Integer = FirstDoc To LastDoc
            Dim company As Integer = If(doc = FirstDoc + 4 OrElse doc = FirstDoc + 10, 9202, 9201)
            Dim payType As Integer = If(doc = FirstDoc + 4, 9202, If(doc = FirstDoc + 11, 9202, If(doc = FirstDoc + 10, 9201, company)))
            Dim paid As Integer = If(doc = FirstDoc + 6, 1, 0)
            Exec("INSERT INTO documenti (Id,AziendeId,UtentiId,PagamentiTipoId,TipoDocumentiId,Pagato,OrigineOrdine,DataDocumento) VALUES (" &
                 doc & "," & company & "," & _userId & "," & payType & "," & _typeId & "," & paid & ",'WEB',NOW())")
            ' 9203: totale diverso (12.35); 9204: 12.335 = 12.34 al centesimo half-up; tutti gli altri 12.34.
            Dim total As String = If(doc = FirstDoc + 2, "12.35", If(doc = FirstDoc + 3, "12.335", "12.34"))
            Exec("INSERT INTO documentipie (DocumentiId,TotaleDocumento) VALUES (" & doc & "," & total & ")")
        Next
    End Sub

    ' La variante deve davvero cambiare il tipo restituito dal connettore, altrimenti il test non prova nulla.
    Private Sub RunVariantEffective()
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT CAST(1 AS UNSIGNED) > 0, CAST(1 AS SIGNED) FROM DUAL", conn)
                Using reader As MySqlDataReader = cmd.ExecuteReader()
                    reader.Read()
                End Using
            End Using
            Using cmd As New MySqlCommand("SELECT Attivo FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'", conn)
                Dim value As Object = cmd.ExecuteScalar()
                Check("V01 variant TreatTinyAsBoolean really changes the returned type", If(_tiny, TypeOf value Is Boolean, Not TypeOf value Is Boolean))
            End Using
        End Using
    End Sub

    ' ----- S: macchina a stati pura -----
    Private Sub RunStateMachine()
        Dim all As String() = PayPalPaymentAttemptStates.All()
        Check("S01 thirteen distinct states", all.Length = 13 AndAlso New HashSet(Of String)(all).Count = 13)
        Dim direct As Dictionary(Of String, String()) = ExpectedDirect()
        Dim mismatches As New List(Of String)()
        For Each f As String In all
            For Each t As String In all
                Dim expected As Boolean = Array.IndexOf(direct(f), t) >= 0
                If PayPalPaymentAttemptStates.CanTransition(f, t) <> expected Then mismatches.Add(f & ">" & t)
            Next
        Next
        Check("S02 full direct transition matrix (13x13)" & If(mismatches.Count = 0, "", " " & String.Join(",", mismatches.ToArray())), mismatches.Count = 0)
        Check("S03 unknown names are never a transition", Not PayPalPaymentAttemptStates.CanTransition("CREATING", "NOPE") AndAlso Not PayPalPaymentAttemptStates.CanTransition("NOPE", "CREATED") AndAlso Not PayPalPaymentAttemptStates.CanTransition(Nothing, "CREATED"))
        Dim resolve As Dictionary(Of String, String()) = ExpectedResolve()
        Dim resolveMismatch As New List(Of String)()
        For Each p As String In all
            For Each t As String In all
                Dim expected As Boolean = resolve.ContainsKey(p) AndAlso Array.IndexOf(resolve(p), t) >= 0
                If PayPalPaymentAttemptStates.CanResolveUnknown(p, t) <> expected Then resolveMismatch.Add(p & ">" & t)
            Next
        Next
        Check("S04 unknown resolution matrix (previous state or direct successor, never DOC_COMMITTED, never UNKNOWN)" & If(resolveMismatch.Count = 0, "", " " & String.Join(",", resolveMismatch.ToArray())), resolveMismatch.Count = 0)
        Dim released As New List(Of String)()
        For Each s As String In all
            If PayPalPaymentAttemptStates.ReleasesSlot(s) Then released.Add(s)
        Next
        released.Sort()
        Check("S05 only FAILED, CANCELED, VOIDED and CAPTURED_ORPHAN release the slot", String.Join(",", released.ToArray()) = "CANCELED,CAPTURED_ORPHAN,FAILED,VOIDED")
        Dim noExit As New List(Of String)()
        For Each s As String In all
            If PayPalPaymentAttemptStates.HasNoExit(s) Then noExit.Add(s)
        Next
        noExit.Sort()
        Check("S06 only COMPLETED and CAPTURED_ORPHAN have no exit", String.Join(",", noExit.ToArray()) = "CAPTURED_ORPHAN,COMPLETED")
        Check("S07 recovery rule CREATING without order after 10 minutes", PayPalPaymentAttemptStates.RecommendedAction("CREATING", 10, False, False) = "FAIL_NO_ORDER" AndAlso PayPalPaymentAttemptStates.RecommendedAction("CREATING", 9, False, False) = "NONE")
        Check("S08 recovery rule CREATED is never canceled without reading PayPal", PayPalPaymentAttemptStates.RecommendedAction("CREATED", 30, True, False) = "READ_ORDER_THEN_DECIDE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("CREATED", 5, True, False) = "NONE")
        Check("S09 recovery rule AUTHORIZED with an expired draft is voided, a live one is left alone", PayPalPaymentAttemptStates.RecommendedAction("AUTHORIZED", 1, True, True) = "VOID_EXPIRED_DRAFT" AndAlso PayPalPaymentAttemptStates.RecommendedAction("AUTHORIZED", 500, True, False) = "NONE")
        Check("S10 recovery rules for DOC_COMMITTED, CAPTURING, VOIDING and UNKNOWN", PayPalPaymentAttemptStates.RecommendedAction("DOC_COMMITTED", 2, True, False) = "BEGIN_CAPTURE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("CAPTURING", 2, True, False) = "READ_PAYPAL_RETRY_CAPTURE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("VOIDING", 2, True, False) = "RETRY_VOID" AndAlso PayPalPaymentAttemptStates.RecommendedAction("UNKNOWN", 0, True, False) = "READ_PAYPAL_RESOLVE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("CAPTURING", 1, True, False) = "NONE")
        Check("S11 CAPTURE_REFUSED and CAPTURED_ORPHAN need a person, finals need nothing", PayPalPaymentAttemptStates.RecommendedAction("CAPTURE_REFUSED", 0, True, False) = "MANUAL_RECONCILE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("CAPTURED_ORPHAN", 0, True, False) = "MANUAL_RECONCILE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("COMPLETED", 999, True, True) = "NONE" AndAlso PayPalPaymentAttemptStates.RecommendedAction("VOIDED", 999, True, True) = "NONE")
        Check("S12 outcome sanitizer keeps upper-case codes only, drops markup and line breaks, and bounds the length", PayPalPaymentAttempts.SanitizeOutcome("ab<c>=d" & vbCrLf) = "ABCD" AndAlso PayPalPaymentAttempts.SanitizeOutcome("http 422 code:a_b-c.d") = "HTTP 422 CODE:A_B-C.D" AndAlso PayPalPaymentAttempts.SanitizeOutcome(Nothing) = "" AndAlso PayPalPaymentAttempts.SanitizeOutcome("ab<c>" & New String("x"c, 400)).Length = 255)
    End Sub

    ' ----- D: regole dello schema (il database rifiuta cio che il codice non dovrebbe mai scrivere) -----
    Private Function RawRow(ByVal extra As Dictionary(Of String, String)) As String
        Dim v As New Dictionary(Of String, String)()
        Dim key As String = Next32()
        v("AttemptKey") = "'" & key & "'"
        v("AziendeId") = "9201" : v("LoginId") = "7100" : v("UtentiId") = _userId.ToString(CultureInfo.InvariantCulture)
        v("PagamentiTipoId") = "9201" : v("PayPalAccountId") = _accountA.ToString(CultureInfo.InvariantCulture)
        v("DatabaseScopeKey") = "'" & Scope & "'" : v("DraftRequestId") = "'" & Next32() & "'" : v("PayloadFingerprint") = "'fp'"
        v("DraftExpiresAt") = "NOW()" : v("TentativoNo") = "1" : v("CurrentSlot") = "1" : v("Stato") = "'CREATING'"
        v("Importo") = "12.34" : v("Valuta") = "'EUR'" : v("PayeeEmail") = "'fixture-a@example.invalid'" : v("MerchantId") = "'KSMERCHANTA'"
        v("CreateRequestId") = "'c" & key & "'" : v("AuthorizeRequestId") = "'a" & key & "'" : v("CaptureRequestId") = "'k" & key & "'" : v("VoidRequestId") = "'v" & key & "'"
        If extra IsNot Nothing Then
            For Each kv As KeyValuePair(Of String, String) In extra
                v(kv.Key) = kv.Value
            Next
        End If
        Dim cols As New List(Of String)()
        Dim vals As New List(Of String)()
        For Each kv As KeyValuePair(Of String, String) In v
            cols.Add(kv.Key)
            vals.Add(kv.Value)
        Next
        Return "INSERT INTO paypal_checkout_tentativi (" & String.Join(",", cols.ToArray()) & ") VALUES (" & String.Join(",", vals.ToArray()) & ")"
    End Function

    Private Function O(ByVal key As String, ByVal value As String) As Dictionary(Of String, String)
        Dim d As New Dictionary(Of String, String)()
        d(key) = value
        Return d
    End Function

    Private Sub RunSchemaRules()
        Check("D01 a valid raw row is accepted (the harness base row is sound)", Not Rejected(RawRow(Nothing)))
        Check("D02 unknown state is rejected", Rejected(RawRow(O("Stato", "'NOPE'"))))
        Check("D03 a released state with an occupied slot is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"Stato", "'FAILED'"}, {"CurrentSlot", "1"}})))
        Check("D04 a live state without a slot is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"Stato", "'AUTHORIZED'"}, {"CurrentSlot", "NULL"}})))
        Check("D05 a released state with an empty slot is accepted", Not Rejected(RawRow(New Dictionary(Of String, String) From {{"Stato", "'FAILED'"}, {"CurrentSlot", "NULL"}})))
        Check("D06 UNKNOWN without a previous state is rejected", Rejected(RawRow(O("Stato", "'UNKNOWN'"))))
        Check("D07 a previous state outside UNKNOWN is rejected", Rejected(RawRow(O("StatoPrecedente", "'CREATED'"))))
        Check("D08 UNKNOWN with a valid previous state is accepted", Not Rejected(RawRow(New Dictionary(Of String, String) From {{"Stato", "'UNKNOWN'"}, {"StatoPrecedente", "'CAPTURING'"}})))
        Check("D09 UNKNOWN with a final previous state is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"Stato", "'UNKNOWN'"}, {"StatoPrecedente", "'COMPLETED'"}})))
        Check("D10 zero amount rejected", Rejected(RawRow(O("Importo", "0"))))
        Check("D11 bad currency rejected", Rejected(RawRow(O("Valuta", "'EU'"))))
        Check("D12 attempt number zero rejected", Rejected(RawRow(O("TentativoNo", "0"))))
        Check("D13 a free-text outcome is rejected, a code is accepted", Rejected(RawRow(O("UltimoEsito", "'<script>alert(1)</script>'"))) AndAlso Not Rejected(RawRow(O("UltimoEsito", "'HTTP 422 CODE AUTHORIZATION_EXPIRED'"))))
        Check("D14 a malformed attempt key is rejected", Rejected(RawRow(O("AttemptKey", "'not-a-key'"))))
        Dim dup As String = Next32()
        Dim first As String = RawRow(New Dictionary(Of String, String) From {{"AttemptKey", "'" & dup & "'"}, {"CreateRequestId", "'cd" & dup & "'"}, {"AuthorizeRequestId", "'ad" & dup & "'"}, {"CaptureRequestId", "'kd" & dup & "'"}, {"VoidRequestId", "'vd" & dup & "'"}, {"LoginId", "7200"}})
        Exec(first)
        Check("D15 duplicate attempt key rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"AttemptKey", "'" & dup & "'"}, {"LoginId", "7201"}})))
        Check("D16 duplicate request ids rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"CreateRequestId", "'cd" & dup & "'"}, {"LoginId", "7202"}})) AndAlso Rejected(RawRow(New Dictionary(Of String, String) From {{"AuthorizeRequestId", "'ad" & dup & "'"}, {"LoginId", "7203"}})) AndAlso Rejected(RawRow(New Dictionary(Of String, String) From {{"CaptureRequestId", "'kd" & dup & "'"}, {"LoginId", "7204"}})) AndAlso Rejected(RawRow(New Dictionary(Of String, String) From {{"VoidRequestId", "'vd" & dup & "'"}, {"LoginId", "7205"}})))
        Dim draft As String = Next32()
        Exec(RawRow(New Dictionary(Of String, String) From {{"DraftRequestId", "'" & draft & "'"}, {"LoginId", "7210"}}))
        Check("D17 a second live attempt for the same draft is rejected, a released one is not", Rejected(RawRow(New Dictionary(Of String, String) From {{"DraftRequestId", "'" & draft & "'"}, {"LoginId", "7210"}, {"TentativoNo", "2"}})) AndAlso Not Rejected(RawRow(New Dictionary(Of String, String) From {{"DraftRequestId", "'" & draft & "'"}, {"LoginId", "7210"}, {"TentativoNo", "3"}, {"Stato", "'FAILED'"}, {"CurrentSlot", "NULL"}})))
        Check("D18 the same attempt number for the same draft is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"DraftRequestId", "'" & draft & "'"}, {"LoginId", "7210"}, {"TentativoNo", "3"}, {"Stato", "'FAILED'"}, {"CurrentSlot", "NULL"}})))
        Check("D19 the same draft of another login is independent", Not Rejected(RawRow(New Dictionary(Of String, String) From {{"DraftRequestId", "'" & draft & "'"}, {"LoginId", "7211"}})))
        Dim orderId As String = Uniq("KSDUPORD")
        Exec(RawRow(New Dictionary(Of String, String) From {{"PayPalOrderId", "'" & orderId & "'"}, {"LoginId", "7220"}}))
        Check("D20 duplicate PayPal order, authorization, capture and document ids rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"PayPalOrderId", "'" & orderId & "'"}, {"LoginId", "7221"}})) AndAlso
              Not Rejected(RawRow(New Dictionary(Of String, String) From {{"PayPalAuthorizationId", "'AUTH" & dup & "'"}, {"PayPalCaptureId", "'CAP" & dup & "'"}, {"DocumentiId", "9299"}, {"LoginId", "7222"}})) AndAlso
              Rejected(RawRow(New Dictionary(Of String, String) From {{"PayPalAuthorizationId", "'AUTH" & dup & "'"}, {"LoginId", "7223"}})) AndAlso
              Rejected(RawRow(New Dictionary(Of String, String) From {{"PayPalCaptureId", "'CAP" & dup & "'"}, {"LoginId", "7224"}})) AndAlso
              Rejected(RawRow(New Dictionary(Of String, String) From {{"DocumentiId", "9299"}, {"LoginId", "7225"}})))
        Check("D21 a company and payment type without a PayPal configuration is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"AziendeId", "9201"}, {"PagamentiTipoId", "9202"}, {"LoginId", "7230"}})))
        Check("D22 an unknown PayPal account is rejected", Rejected(RawRow(New Dictionary(Of String, String) From {{"PayPalAccountId", "2000000000"}, {"LoginId", "7231"}})))
        Check("D23 the CHECK clauses are really enforced by the server (information_schema)", Scalar("SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND CONSTRAINT_TYPE='CHECK'") = "8" AndAlso Scalar("SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND CONSTRAINT_NAME LIKE 'CK\_ppt\_%' AND CHECK_CLAUSE LIKE '%CAPTURED_ORPHAN%'") = "2")
        Check("D24 the state/updated index exists for the stuck listing", Scalar("SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_tentativi' AND INDEX_NAME='IX_ppt_stato'") = "2")
        Exec("DELETE FROM paypal_checkout_tentativi WHERE DatabaseScopeKey='" & Scope & "'")
    End Sub

    ' ----- C: creazione, ripresa, caricamento, isolamento -----
    Private Sub RunCreateAndLoad()
        Dim draft As String = Next32()
        Dim r1 As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7001, draft, "fp-one"))
        Check("C01 first request creates the attempt", r1.Outcome = PayPalAttemptCreateOutcome.Created AndAlso r1.Attempt IsNot Nothing AndAlso r1.Attempt.Stato = "CREATING" AndAlso r1.Attempt.TentativoNo = 1 AndAlso r1.Attempt.IsCurrent)
        Dim a As PayPalAttemptRecord = r1.Attempt
        Check("C02 opaque key, derived request ids and stored identity", a.AttemptKey.Length = 32 AndAlso a.CreateRequestId <> a.AuthorizeRequestId AndAlso a.CaptureRequestId <> a.VoidRequestId AndAlso a.CreateRequestId.Contains(a.AttemptKey) AndAlso
              a.AziendeId = 9201 AndAlso a.LoginId = 7001 AndAlso a.UtentiId = _userId AndAlso a.Importo = 12.34D AndAlso a.Valuta = "EUR" AndAlso a.DatabaseScopeKey = Scope AndAlso a.DraftRequestId = draft AndAlso a.PayloadFingerprint = "fp-one")
        Dim r2 As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7001, draft, "fp-one"))
        Check("C03 same draft and same fingerprint resumes the same attempt", r2.Outcome = PayPalAttemptCreateOutcome.Resumed AndAlso r2.Attempt.Id = a.Id)
        Dim r3 As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7001, draft, "fp-two"))
        Check("C04 same draft with another fingerprint while an attempt is live is blocked", r3.Outcome = PayPalAttemptCreateOutcome.Blocked AndAlso r3.Attempt IsNot Nothing AndAlso r3.Attempt.Id = a.Id)
        Dim r4 As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7002, draft, "fp-one"))
        Check("C05 the same draft of another login is independent", r4.Outcome = PayPalAttemptCreateOutcome.Created AndAlso r4.Attempt.Id <> a.Id AndAlso r4.Attempt.TentativoNo = 1)
        Check("C06 a failed attempt releases the slot and the next one is number 2", PayPalPaymentAttempts.RecordFailed(a.Id, a.AziendeId, "NO_ORDER"))
        Dim r5 As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7001, draft, "fp-two"))
        Check("C07 after the release a new attempt is created with the next number and the old row is kept", r5.Outcome = PayPalAttemptCreateOutcome.Created AndAlso r5.Attempt.TentativoNo = 2 AndAlso r5.Attempt.Id <> a.Id AndAlso Scalar("SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DraftRequestId='" & draft & "' AND LoginId=7001") = "2" AndAlso Scalar("SELECT CurrentSlot IS NULL FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = "1")
        Dim loaded As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(r5.Attempt.AttemptKey, 9201, 7001)
        Check("C08 the owner loads its attempt", loaded IsNot Nothing AndAlso loaded.Id = r5.Attempt.Id AndAlso loaded.IsCurrent)
        Check("C09 another login, another company or a wrong key load nothing", PayPalPaymentAttempts.LoadForOwner(r5.Attempt.AttemptKey, 9201, 7002) Is Nothing AndAlso PayPalPaymentAttempts.LoadForOwner(r5.Attempt.AttemptKey, 9202, 7001) Is Nothing AndAlso PayPalPaymentAttempts.LoadForOwner(Next32(), 9201, 7001) Is Nothing AndAlso PayPalPaymentAttempts.LoadForOwner("x", 9201, 7001) Is Nothing)
        Dim bad As PayPalAttemptCreateRequest = Req(9201, 7001, Next32(), "fp")
        bad.Importo = 0D
        Dim bad2 As PayPalAttemptCreateRequest = Req(9201, 7001, "not-a-guid", "fp")
        Dim bad3 As PayPalAttemptCreateRequest = Req(9201, 0, Next32(), "fp")
        Check("C10 invalid requests (zero amount, bad draft id, no login) create nothing", PayPalPaymentAttempts.CreateOrResume(bad).Outcome = PayPalAttemptCreateOutcome.TechnicalError AndAlso PayPalPaymentAttempts.CreateOrResume(bad2).Outcome = PayPalAttemptCreateOutcome.TechnicalError AndAlso PayPalPaymentAttempts.CreateOrResume(bad3).Outcome = PayPalAttemptCreateOutcome.TechnicalError)
        Dim wrongTenant As PayPalAttemptCreateRequest = Req(9201, 7001, Next32(), "fp")
        wrongTenant.PagamentiTipoId = 9202
        Check("C11 a company/payment pair without a PayPal configuration is a technical error, not an exception", PayPalPaymentAttempts.CreateOrResume(wrongTenant).Outcome = PayPalAttemptCreateOutcome.TechnicalError)
        Dim b As PayPalAttemptRecord = ToAuthorized(NewAttempt())
        Check("C12 system lookups by order, authorization and document id", IdOf(PayPalPaymentAttempts.LoadForSystemByOrderId(b.PayPalOrderId)) = b.Id AndAlso IdOf(PayPalPaymentAttempts.LoadForSystemByAuthorizationId(b.PayPalAuthorizationId)) = b.Id AndAlso PayPalPaymentAttempts.LoadForSystemByOrderId("none") Is Nothing AndAlso PayPalPaymentAttempts.LoadForSystemByAuthorizationId("none") Is Nothing AndAlso PayPalPaymentAttempts.LoadForSystemByDocumentId(FirstDoc) Is Nothing AndAlso PayPalPaymentAttempts.LoadForSystemByCaptureId("none") Is Nothing)
        Check("C13 the authorization expiry is stored in UTC and read back", b.AuthorizationExpiresUtc.HasValue AndAlso b.AuthorizationExpiresUtc.Value > DateTime.UtcNow.AddDays(2) AndAlso b.AuthorizationExpiresUtc.Value < DateTime.UtcNow.AddDays(4))
    End Sub

    ' ----- T: transizioni semplici, guardate dallo stato, dal tenant e dall'utente -----
    Private Sub RunTransitions()
        Dim a As PayPalAttemptRecord = NewAttempt(7301)
        Dim order As String = Uniq("KSORD")
        Check("T01 RecordOrderCreated refuses another login and another company", Not PayPalPaymentAttempts.RecordOrderCreated(a.Id, a.AziendeId, 7399, order) AndAlso Not PayPalPaymentAttempts.RecordOrderCreated(a.Id, 9202, a.LoginId, order))
        Check("T02 RecordOrderCreated CREATING -> CREATED", PayPalPaymentAttempts.RecordOrderCreated(a.Id, a.AziendeId, a.LoginId, order) AndAlso StateOf(a.Id) = "CREATED")
        Check("T03 RecordOrderCreated twice is refused", Not PayPalPaymentAttempts.RecordOrderCreated(a.Id, a.AziendeId, a.LoginId, Uniq("KSORD")))
        Dim b As PayPalAttemptRecord = NewAttempt(7302)
        Check("T04 an order id already used by another attempt is refused", Not PayPalPaymentAttempts.RecordOrderCreated(b.Id, b.AziendeId, b.LoginId, order) AndAlso StateOf(b.Id) = "CREATING")
        Check("T05 RecordAuthorized refuses a wrong order id, a wrong login and an attempt not yet CREATED", Not PayPalPaymentAttempts.RecordAuthorized(a.Id, a.AziendeId, a.LoginId, "OTHERORDER1", Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3)) AndAlso Not PayPalPaymentAttempts.RecordAuthorized(a.Id, a.AziendeId, 7399, order, Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3)) AndAlso Not PayPalPaymentAttempts.RecordAuthorized(b.Id, b.AziendeId, b.LoginId, order, Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3)))
        Dim authId As String = Uniq("KSAUTH")
        Check("T06 RecordAuthorized CREATED -> AUTHORIZED stores the authorization", PayPalPaymentAttempts.RecordAuthorized(a.Id, a.AziendeId, a.LoginId, order, authId, DateTime.UtcNow.AddDays(3)) AndAlso StateOf(a.Id) = "AUTHORIZED" AndAlso Scalar("SELECT PayPalAuthorizationId FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = authId)
        Check("T07 RecordAuthorized twice is refused", Not PayPalPaymentAttempts.RecordAuthorized(a.Id, a.AziendeId, a.LoginId, order, Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3)))
        Dim c As PayPalAttemptRecord = ToCreated(NewAttempt(7303))
        Check("T08 a customer cancellation needs the same login and company", Not PayPalPaymentAttempts.RecordCanceled(c.Id, c.AziendeId, 7399) AndAlso Not PayPalPaymentAttempts.RecordCanceled(c.Id, 9202, c.LoginId) AndAlso PayPalPaymentAttempts.RecordCanceled(c.Id, c.AziendeId, c.LoginId) AndAlso StateOf(c.Id) = "CANCELED")
        Check("T09 a canceled attempt cannot be authorized later (late callback)", Not PayPalPaymentAttempts.RecordAuthorized(c.Id, c.AziendeId, c.LoginId, c.PayPalOrderId, Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3)))
        Dim f As PayPalAttemptRecord = NewAttempt(7304)
        Check("T10 RecordFailed works from CREATING with a sanitized reason and refuses another company", Not PayPalPaymentAttempts.RecordFailed(f.Id, 9202, "X") AndAlso PayPalPaymentAttempts.RecordFailed(f.Id, f.AziendeId, "no order <b>") AndAlso StateOf(f.Id) = "FAILED" AndAlso Scalar("SELECT UltimoEsito FROM paypal_checkout_tentativi WHERE Id=" & f.Id) = "NO ORDER B")
        Dim g As PayPalAttemptRecord = ToAuthorized(NewAttempt(7305))
        Check("T11 RecordFailed refuses an AUTHORIZED attempt (the authorization may still be valid)", Not PayPalPaymentAttempts.RecordFailed(g.Id, g.AziendeId, "X") AndAlso StateOf(g.Id) = "AUTHORIZED")
        Check("T12 RecordAuthorizationLost needs a remote status that proves no money is held", Not PayPalPaymentAttempts.RecordAuthorizationLost(g.Id, g.AziendeId, "CREATED") AndAlso Not PayPalPaymentAttempts.RecordAuthorizationLost(g.Id, g.AziendeId, "PENDING") AndAlso Not PayPalPaymentAttempts.RecordAuthorizationLost(g.Id, g.AziendeId, "") AndAlso StateOf(g.Id) = "AUTHORIZED" AndAlso PayPalPaymentAttempts.RecordAuthorizationLost(g.Id, g.AziendeId, "EXPIRED") AndAlso StateOf(g.Id) = "FAILED")
        Dim v As PayPalAttemptRecord = ToAuthorized(NewAttempt(7306))
        Check("T13 AUTHORIZED -> VOIDING -> VOIDED releases the slot", PayPalPaymentAttempts.RecordVoiding(v.Id, v.AziendeId, "DRAFT_EXPIRED") AndAlso StateOf(v.Id) = "VOIDING" AndAlso Scalar("SELECT CurrentSlot IS NULL FROM paypal_checkout_tentativi WHERE Id=" & v.Id) = "0" AndAlso PayPalPaymentAttempts.RecordVoided(v.Id, v.AziendeId) AndAlso StateOf(v.Id) = "VOIDED" AndAlso Scalar("SELECT CurrentSlot IS NULL FROM paypal_checkout_tentativi WHERE Id=" & v.Id) = "1")
        Check("T14 VOIDING/VOIDED transitions refuse the wrong states and another company", Not PayPalPaymentAttempts.RecordVoided(v.Id, v.AziendeId) AndAlso Not PayPalPaymentAttempts.RecordVoiding(v.Id, v.AziendeId, "X") AndAlso Not PayPalPaymentAttempts.RecordVoiding(g.Id, 9202, "X"))
        Dim v2 As PayPalAttemptRecord = ToAuthorized(NewAttempt(7307))
        Check("T15 BindDocument is refused once the attempt is VOIDING (void vs bind)", PayPalPaymentAttempts.RecordVoiding(v2.Id, v2.AziendeId, "X") AndAlso Not BindInTx(v2, NextDoc()) AndAlso StateOf(v2.Id) = "VOIDING")
        Dim d As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7308))
        Check("T16 DOC_COMMITTED can be voided (the document disappeared before the capture)", PayPalPaymentAttempts.RecordVoiding(d.Id, d.AziendeId, "NO_DOCUMENT") AndAlso StateOf(d.Id) = "VOIDING")
        Check("T17 the reason is stored as a bounded code", Scalar("SELECT UltimoEsito FROM paypal_checkout_tentativi WHERE Id=" & d.Id) = "NO_DOCUMENT")
        Dim long1 As String = New String("A"c, 400)
        Dim e As PayPalAttemptRecord = NewAttempt(7309)
        PayPalPaymentAttempts.RecordFailed(e.Id, e.AziendeId, long1)
        Check("T18 a very long reason is truncated to the column", Scalar("SELECT CHAR_LENGTH(UltimoEsito) FROM paypal_checkout_tentativi WHERE Id=" & e.Id) = "255")
    End Sub

    ' ----- B: legame con il documento nella transazione del chiamante -----
    Private Sub RunDocumentBinding()
        Dim a As PayPalAttemptRecord = ToAuthorized(NewAttempt(7401))
        Dim doc As Integer = FirstDoc
        Check("B01 commit binds the attempt to the document", BindInTx(a, doc) AndAlso StateOf(a.Id) = "DOC_COMMITTED" AndAlso Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = doc.ToString(CultureInfo.InvariantCulture) AndAlso IdOf(PayPalPaymentAttempts.LoadForSystemByDocumentId(doc)) = a.Id)
        Dim r As PayPalAttemptRecord = ToAuthorized(NewAttempt(7402))
        Dim inTx As Boolean = BindInTx(r, FirstDoc + 1, False)
        Check("B02 rollback leaves the attempt AUTHORIZED and the document unbound", inTx AndAlso StateOf(r.Id) = "AUTHORIZED" AndAlso Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & r.Id) = "<null>")
        Check("B03 after a rollback the same document can be bound again", BindInTx(r, FirstDoc + 1) AndAlso StateOf(r.Id) = "DOC_COMMITTED")
        Dim t As PayPalAttemptRecord = ToAuthorized(NewAttempt(7403))
        Check("B04 a document of another company (same payment type id) or of another payment type (same company) is refused", Not BindInTx(t, FirstDoc + 4) AndAlso Not BindInTx(t, FirstDoc + 10) AndAlso Not BindInTx(t, FirstDoc + 11) AndAlso StateOf(t.Id) = "AUTHORIZED")
        Check("B05 a document with another total is refused, a total equal at the cent half-up is accepted", Not BindInTx(t, FirstDoc + 2) AndAlso StateOf(t.Id) = "AUTHORIZED" AndAlso BindInTx(t, FirstDoc + 3) AndAlso StateOf(t.Id) = "DOC_COMMITTED")
        Dim o As PayPalAttemptRecord = NewAttempt(7404)
        Dim oc As PayPalAttemptRecord = ToAuthorized(o)
        Exec("UPDATE paypal_checkout_tentativi SET UtentiId=UtentiId+777 WHERE Id=" & oc.Id)
        Check("B06 a document of another customer (UtentiId) is refused", Not BindInTx(oc, FirstDoc + 5) AndAlso StateOf(oc.Id) = "AUTHORIZED")
        Dim m As PayPalAttemptRecord = ToAuthorized(NewAttempt(7405))
        Check("B07 a document that does not exist is refused", Not BindInTx(m, 9299) AndAlso StateOf(m.Id) = "AUTHORIZED")
        Check("B08 a document already bound to another attempt is refused", Not BindInTx(m, FirstDoc) AndAlso StateOf(m.Id) = "AUTHORIZED")
        Check("B09 a wrong login or company cannot bind", Not BindInTx(New PayPalAttemptRecord With {.Id = m.Id, .AziendeId = m.AziendeId, .LoginId = 7499}, FirstDoc + 7) AndAlso Not BindInTx(New PayPalAttemptRecord With {.Id = m.Id, .AziendeId = 9202, .LoginId = m.LoginId}, FirstDoc + 7))
        Dim x As PayPalAttemptRecord = NewAttempt(7406)
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using tx As MySqlTransaction = conn.BeginTransaction(IsolationLevel.Serializable)
                Dim locked As PayPalAttemptRecord = PayPalPaymentAttempts.LockForDocument(conn, tx, x.Id, x.AziendeId, x.LoginId)
                Dim notAuth As Boolean = locked IsNot Nothing AndAlso locked.Stato = "CREATING" AndAlso Not PayPalPaymentAttempts.BindDocument(conn, tx, x.Id, x.AziendeId, x.LoginId, FirstDoc + 7)
                tx.Rollback()
                Check("B10 BindDocument only works from AUTHORIZED", notAuth)
            End Using
        End Using
        Check("B11 LockForDocument returns nothing for another owner", LockOnly(x, 7499) Is Nothing AndAlso LockOnly(x, x.LoginId) IsNot Nothing)
        Dim dd As PayPalAttemptRecord = ToAuthorized(NewAttempt(7407))
        Dim aBound As Boolean = False, bBound As Boolean = False
        Dim bSaw As String = String.Empty
        Dim bWaitedMs As Long = 0
        Dim holding As New ManualResetEvent(False)
        Dim tA As New Thread(Sub()
                                 Try
                                     Using conn As New MySqlConnection(_cs)
                                         conn.Open()
                                         Using tx As MySqlTransaction = conn.BeginTransaction(IsolationLevel.Serializable)
                                             PayPalPaymentAttempts.LockForDocument(conn, tx, dd.Id, dd.AziendeId, dd.LoginId)
                                             holding.Set()
                                             Thread.Sleep(1500)
                                             aBound = PayPalPaymentAttempts.BindDocument(conn, tx, dd.Id, dd.AziendeId, dd.LoginId, FirstDoc + 8)
                                             tx.Commit()
                                         End Using
                                     End Using
                                 Catch ex As Exception
                                     Interlocked.Increment(_threadErrors)
                                     Console.WriteLine("THREAD_ERROR A " & ex.GetType().Name & " " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
                                     holding.Set()
                                 End Try
                             End Sub)
        Dim tB As New Thread(Sub()
                                 Try
                                     holding.WaitOne()
                                     Dim sw As System.Diagnostics.Stopwatch = System.Diagnostics.Stopwatch.StartNew()
                                     Using conn As New MySqlConnection(_cs)
                                         conn.Open()
                                         Using tx As MySqlTransaction = conn.BeginTransaction(IsolationLevel.Serializable)
                                             Dim locked As PayPalAttemptRecord = PayPalPaymentAttempts.LockForDocument(conn, tx, dd.Id, dd.AziendeId, dd.LoginId)
                                             bWaitedMs = sw.ElapsedMilliseconds
                                             bSaw = If(locked Is Nothing, "<null>", locked.Stato)
                                             bBound = locked IsNot Nothing AndAlso locked.Stato = "AUTHORIZED" AndAlso PayPalPaymentAttempts.BindDocument(conn, tx, dd.Id, dd.AziendeId, dd.LoginId, FirstDoc + 9)
                                             tx.Rollback()
                                         End Using
                                     End Using
                                 Catch ex As Exception
                                     Interlocked.Increment(_threadErrors)
                                     Console.WriteLine("THREAD_ERROR B " & ex.GetType().Name & " " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
                                 End Try
                             End Sub)
        _threadErrors = 0
        tA.Start()
        tB.Start()
        tA.Join(30000)
        tB.Join(30000)
        Check("B12 double submit: the second request waits for the first BEFORE touching documents, then sees DOC_COMMITTED and does not bind (lock order attempt -> documents, no deadlock)", _threadErrors = 0 AndAlso aBound AndAlso Not bBound AndAlso bSaw = "DOC_COMMITTED" AndAlso bWaitedMs >= 1000 AndAlso StateOf(dd.Id) = "DOC_COMMITTED" AndAlso Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & dd.Id) = (FirstDoc + 8).ToString(CultureInfo.InvariantCulture))
    End Sub

    Private Function LockOnly(ByVal a As PayPalAttemptRecord, ByVal login As Long) As PayPalAttemptRecord
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using tx As MySqlTransaction = conn.BeginTransaction(IsolationLevel.Serializable)
                Dim locked As PayPalAttemptRecord = PayPalPaymentAttempts.LockForDocument(conn, tx, a.Id, a.AziendeId, login)
                tx.Rollback()
                Return locked
            End Using
        End Using
    End Function

    ' ----- K: incasso -----
    Private Sub RunCapture()
        Dim a As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7501))
        Check("K01 BeginCapture DOC_COMMITTED -> CAPTURING", PayPalPaymentAttempts.BeginCapture(a.Id, a.AziendeId) = PayPalBeginCaptureOutcome.Started AndAlso StateOf(a.Id) = "CAPTURING")
        Check("K02 BeginCapture never starts from CAPTURING again", PayPalPaymentAttempts.BeginCapture(a.Id, a.AziendeId) = PayPalBeginCaptureOutcome.NotInState)
        Check("K03 BeginCapture refuses another company", PayPalPaymentAttempts.BeginCapture(a.Id, 9202) = PayPalBeginCaptureOutcome.NotInState)
        Dim gone As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7502))
        Exec("DELETE FROM documentipie WHERE DocumentiId=" & Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & gone.Id))
        Exec("DELETE FROM documenti WHERE Id=" & Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & gone.Id))
        Check("K04 BeginCapture refuses when the document no longer exists and leaves the state", PayPalPaymentAttempts.BeginCapture(gone.Id, gone.AziendeId) = PayPalBeginCaptureOutcome.DocumentInvalid AndAlso StateOf(gone.Id) = "DOC_COMMITTED")
        Dim paid As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7503))
        Exec("UPDATE documenti SET Pagato=1 WHERE Id=" & Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & paid.Id))
        Check("K05 BeginCapture refuses an already paid document", PayPalPaymentAttempts.BeginCapture(paid.Id, paid.AziendeId) = PayPalBeginCaptureOutcome.DocumentInvalid AndAlso StateOf(paid.Id) = "DOC_COMMITTED")
        Dim other As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7504))
        Exec("UPDATE documenti SET UtentiId=UtentiId+777 WHERE Id=" & Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & other.Id))
        Check("K06 BeginCapture refuses a document that changed owner", PayPalPaymentAttempts.BeginCapture(other.Id, other.AziendeId) = PayPalBeginCaptureOutcome.DocumentInvalid)
        Exec("UPDATE paypal_checkout_tentativi SET UpdatedAt=NOW() - INTERVAL 10 MINUTE WHERE Id=" & a.Id)
        Check("K07 a stale CAPTURING attempt is claimed for retry by exactly one caller and the state does not change", PayPalPaymentAttempts.TryClaimCaptureRetry(a.Id, a.AziendeId, 120) AndAlso Not PayPalPaymentAttempts.TryClaimCaptureRetry(a.Id, a.AziendeId, 120) AndAlso StateOf(a.Id) = "CAPTURING")
        Check("K08 a fresh CAPTURING attempt is not claimable and another company cannot claim", Not PayPalPaymentAttempts.TryClaimCaptureRetry(a.Id, a.AziendeId, 120) AndAlso Not PayPalPaymentAttempts.TryClaimCaptureRetry(a.Id, 9202, 0))
        Dim stale As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7509))
        Exec("UPDATE paypal_checkout_tentativi SET UpdatedAt=NOW() - INTERVAL 10 MINUTE WHERE Id=" & stale.Id)
        Check("K15 only a CAPTURING attempt can be claimed for a capture retry", Not PayPalPaymentAttempts.TryClaimCaptureRetry(stale.Id, stale.AziendeId, 0) AndAlso StateOf(stale.Id) = "DOC_COMMITTED")
        Dim cap As String = Uniq("KSCAP")
        Check("K09 a completed capture stores the capture id and keeps the slot", PayPalPaymentAttempts.RecordCaptureResult(a.Id, a.AziendeId, cap, True, "COMPLETED") AndAlso StateOf(a.Id) = "COMPLETED" AndAlso Scalar("SELECT PayPalCaptureId FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = cap AndAlso Scalar("SELECT COALESCE(CurrentSlot,0)+0 FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = "1")
        Check("K10 COMPLETED is final: no second result, no voiding", Not PayPalPaymentAttempts.RecordCaptureResult(a.Id, a.AziendeId, Uniq("KSCAP"), True, "X") AndAlso Not PayPalPaymentAttempts.RecordVoiding(a.Id, a.AziendeId, "X") AndAlso Not PayPalPaymentAttempts.RecordFailed(a.Id, a.AziendeId, "X"))
        Dim c2 As PayPalAttemptRecord = ToCapturing(NewAttempt(7505))
        Check("K11 a refused capture goes to CAPTURE_REFUSED, still current, and can later be reconciled to COMPLETED", PayPalPaymentAttempts.RecordCaptureResult(c2.Id, c2.AziendeId, "", False, "DECLINED") AndAlso StateOf(c2.Id) = "CAPTURE_REFUSED" AndAlso Scalar("SELECT COALESCE(CurrentSlot,0)+0 FROM paypal_checkout_tentativi WHERE Id=" & c2.Id) = "1" AndAlso PayPalPaymentAttempts.RecordCaptureResult(c2.Id, c2.AziendeId, Uniq("KSCAP"), True, "MANUAL") AndAlso StateOf(c2.Id) = "COMPLETED")
        Dim c3 As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7506))
        Check("K12 a capture seen as completed on PayPal before BeginCapture (manual capture) reconciles DOC_COMMITTED -> COMPLETED", PayPalPaymentAttempts.RecordCaptureResult(c3.Id, c3.AziendeId, Uniq("KSCAP"), True, "MANUAL") AndAlso StateOf(c3.Id) = "COMPLETED")
        Dim c4 As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7507))
        Check("K13 a refusal cannot be recorded from DOC_COMMITTED (only a started capture can be refused)", Not PayPalPaymentAttempts.RecordCaptureResult(c4.Id, c4.AziendeId, "", False, "DECLINED") AndAlso StateOf(c4.Id) = "DOC_COMMITTED")
        Dim c5 As PayPalAttemptRecord = ToCapturing(NewAttempt(7508))
        Check("K14 a refused capture can be voided (the unpaid order is canceled by hand)", PayPalPaymentAttempts.RecordCaptureResult(c5.Id, c5.AziendeId, "", False, "DECLINED") AndAlso PayPalPaymentAttempts.RecordVoiding(c5.Id, c5.AziendeId, "ORDER_CANCELED") AndAlso StateOf(c5.Id) = "VOIDING")
    End Sub

    ' ----- U: UNKNOWN e incassi orfani -----
    Private Sub RunUnknownAndOrphans()
        Dim a As PayPalAttemptRecord = ToAuthorized(NewAttempt(7601))
        Check("U01 RecordUnknown keeps the previous state", PayPalPaymentAttempts.RecordUnknown(a.Id, a.AziendeId, "LOST_RESPONSE") AndAlso StateOf(a.Id) = "UNKNOWN" AndAlso Scalar("SELECT StatoPrecedente FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = "AUTHORIZED")
        Check("U02 a second RecordUnknown does not overwrite the previous state", Not PayPalPaymentAttempts.RecordUnknown(a.Id, a.AziendeId, "AGAIN") AndAlso Scalar("SELECT StatoPrecedente FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = "AUTHORIZED")
        Check("U03 an UNKNOWN attempt cannot jump to COMPLETED, DOC_COMMITTED or FAILED", Not PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "COMPLETED", "X") AndAlso Not PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "DOC_COMMITTED", "X") AndAlso Not PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "FAILED", "X") AndAlso StateOf(a.Id) = "UNKNOWN")
        Check("U04 an UNKNOWN attempt resolves back to the previous state (nothing happened) and clears the previous state", PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "AUTHORIZED", "READ_BACK") AndAlso StateOf(a.Id) = "AUTHORIZED" AndAlso Scalar("SELECT StatoPrecedente FROM paypal_checkout_tentativi WHERE Id=" & a.Id) = "<null>")
        PayPalPaymentAttempts.RecordUnknown(a.Id, a.AziendeId, "AMBIGUOUS_VOID")
        Check("U05 an ambiguous void resolves to VOIDING (never straight to a final state) and a second resolve is refused", PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "VOIDING", "READ_BACK") AndAlso StateOf(a.Id) = "VOIDING" AndAlso Not PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "VOIDED", "X"))
        Dim b As PayPalAttemptRecord = ToCapturing(NewAttempt(7602))
        PayPalPaymentAttempts.RecordUnknown(b.Id, b.AziendeId, "CRASH_AFTER_PAYPAL")
        Check("U06 UNKNOWN(CAPTURING) resolves to COMPLETED or CAPTURE_REFUSED only", Not PayPalPaymentAttempts.ResolveUnknown(b.Id, b.AziendeId, "VOIDING", "X") AndAlso PayPalPaymentAttempts.ResolveUnknown(b.Id, b.AziendeId, "COMPLETED", "READ_BACK") AndAlso StateOf(b.Id) = "COMPLETED")
        Dim c As PayPalAttemptRecord = NewAttempt(7603)
        Check("U07 a final state cannot become UNKNOWN", PayPalPaymentAttempts.RecordFailed(c.Id, c.AziendeId, "X") AndAlso Not PayPalPaymentAttempts.RecordUnknown(c.Id, c.AziendeId, "X"))
        Check("U08 a late capture on a FAILED attempt is recorded as an orphan capture (not lost)", PayPalPaymentAttempts.RecordOrphanCapture(c.Id, c.AziendeId, Uniq("KSCAP")) AndAlso StateOf(c.Id) = "CAPTURED_ORPHAN" AndAlso Scalar("SELECT CurrentSlot IS NULL FROM paypal_checkout_tentativi WHERE Id=" & c.Id) = "1")
        Check("U09 an orphan capture has no exit", Not PayPalPaymentAttempts.RecordOrphanCapture(c.Id, c.AziendeId, Uniq("KSCAP")) AndAlso Not PayPalPaymentAttempts.RecordFailed(c.Id, c.AziendeId, "X"))
        Dim d As PayPalAttemptRecord = NewAttempt(7604)
        PayPalPaymentAttempts.RecordFailed(d.Id, d.AziendeId, "X")
        Dim d2 As PayPalAttemptRecord = ToAuthorized(NewAttempt(7605))
        PayPalPaymentAttempts.RecordVoiding(d2.Id, d2.AziendeId, "X")
        Check("U10 orphan capture from VOIDING and refused from COMPLETED / DOC_COMMITTED", PayPalPaymentAttempts.RecordOrphanCapture(d2.Id, d2.AziendeId, Uniq("KSCAP")) AndAlso Not PayPalPaymentAttempts.RecordOrphanCapture(ToDocCommitted(NewAttempt(7606)).Id, 9201, Uniq("KSCAP")))
        Check("U11 ResolveUnknown refuses a state that is not a state, and another company", Not PayPalPaymentAttempts.ResolveUnknown(a.Id, a.AziendeId, "NOPE", "X") AndAlso Not PayPalPaymentAttempts.ResolveUnknown(a.Id, 9202, "VOIDED", "X"))
    End Sub

    ' ----- P: concorrenza -----
    Private Sub RunConcurrency()
        Dim draft As String = Next32()
        Dim created As Integer = 0, resumed As Integer = 0, other As Integer = 0
        Dim ids As New List(Of Long)()
        Dim lockObj As New Object()
        Dim errors As Integer = RunThreads(8, Sub(i)
                                                  Dim r As PayPalAttemptCreateResult = PayPalPaymentAttempts.CreateOrResume(Req(9201, 7701, draft, "fp-race"))
                                                  SyncLock lockObj
                                                      If r.Outcome = PayPalAttemptCreateOutcome.Created Then created += 1 Else If r.Outcome = PayPalAttemptCreateOutcome.Resumed Then resumed += 1 Else other += 1
                                                      If r.Attempt IsNot Nothing Then ids.Add(r.Attempt.Id)
                                                  End SyncLock
                                              End Sub)
        Dim sameId As Boolean = ids.Count = 8
        For Each id As Long In ids
            If id <> ids(0) Then sameId = False
        Next
        Check("P01 eight concurrent first requests: one Created, seven Resumed, the same attempt, no thread error", errors = 0 AndAlso created = 1 AndAlso resumed = 7 AndAlso other = 0 AndAlso sameId AndAlso Scalar("SELECT COUNT(*) FROM paypal_checkout_tentativi WHERE DraftRequestId='" & draft & "'") = "1")

        Dim dc As PayPalAttemptRecord = ToDocCommitted(NewAttempt(7702))
        Dim started As Integer = 0
        Dim errors2 As Integer = RunThreads(8, Sub(i)
                                                   If PayPalPaymentAttempts.BeginCapture(dc.Id, dc.AziendeId) = PayPalBeginCaptureOutcome.Started Then Interlocked.Increment(started)
                                               End Sub)
        Check("P02 eight concurrent BeginCapture: exactly one Started", errors2 = 0 AndAlso started = 1 AndAlso StateOf(dc.Id) = "CAPTURING")

        Exec("UPDATE paypal_checkout_tentativi SET UpdatedAt=NOW() - INTERVAL 10 MINUTE WHERE Id=" & dc.Id)
        Dim claimed As Integer = 0
        Dim errors3 As Integer = RunThreads(8, Sub(i)
                                                   If PayPalPaymentAttempts.TryClaimCaptureRetry(dc.Id, dc.AziendeId, 120) Then Interlocked.Increment(claimed)
                                               End Sub)
        Check("P03 eight concurrent retry claims: exactly one winner", errors3 = 0 AndAlso claimed = 1)

        Dim winsCancel As Integer = 0, winsAuth As Integer = 0, both As Integer = 0, neither As Integer = 0
        Dim raceErrors As Integer = 0
        For iteration As Integer = 1 To 10
            Dim c As PayPalAttemptRecord = ToCreated(NewAttempt(7703))
            Dim canceled As Boolean = False, authorized As Boolean = False
            raceErrors += RunThreads(2, Sub(i)
                                            If i = 0 Then canceled = PayPalPaymentAttempts.RecordCanceled(c.Id, c.AziendeId, c.LoginId) Else authorized = PayPalPaymentAttempts.RecordAuthorized(c.Id, c.AziendeId, c.LoginId, c.PayPalOrderId, Uniq("KSAUTH"), DateTime.UtcNow.AddDays(3))
                                        End Sub)
            If canceled AndAlso authorized Then both += 1 Else If canceled Then winsCancel += 1 Else If authorized Then winsAuth += 1 Else neither += 1
        Next
        Check("P04 cancel versus authorize: exactly one winner every time, no error", raceErrors = 0 AndAlso both = 0 AndAlso neither = 0 AndAlso winsCancel + winsAuth = 10)

        Dim voidFinal As Integer = 0, inconsistent As Integer = 0
        Dim vbErrors As Integer = 0
        For iteration As Integer = 1 To 5
            Dim x As PayPalAttemptRecord = ToAuthorized(NewAttempt(7704))
            Dim docToBind As Integer = NextDoc()
            Dim voided As Boolean = False, bound As Boolean = False
            vbErrors += RunThreads(2, Sub(i)
                                          If i = 0 Then voided = PayPalPaymentAttempts.RecordVoiding(x.Id, x.AziendeId, "RACE") Else bound = BindInTx(x, docToBind)
                                      End Sub)
            Dim finalState As String = StateOf(x.Id)
            If voided AndAlso finalState = "VOIDING" Then voidFinal += 1
            Dim boundDoc As String = Scalar("SELECT DocumentiId FROM paypal_checkout_tentativi WHERE Id=" & x.Id)
            If bound <> (boundDoc <> "<null>") Then inconsistent += 1
        Next
        Check("P05 void versus bind: no error, the attempt always ends VOIDING (the recovery sees it) and a bound document is always recorded", vbErrors = 0 AndAlso voidFinal = 5 AndAlso inconsistent = 0)
    End Sub

    ' ----- L: elenchi per il recupero -----
    Private Sub RunListings()
        Dim a As PayPalAttemptRecord = ToAuthorized(NewAttempt(7801))
        Dim b As PayPalAttemptRecord = NewAttempt(7801)
        Dim done As PayPalAttemptRecord = NewAttempt(7801)
        PayPalPaymentAttempts.RecordFailed(done.Id, done.AziendeId, "X")
        Exec("UPDATE paypal_checkout_tentativi SET UpdatedAt=NOW() - INTERVAL 40 MINUTE WHERE Id IN (" & a.Id & "," & done.Id & ")")
        Dim stuck As List(Of PayPalAttemptRecord) = PayPalPaymentAttempts.ListStuck(30, 100)
        Dim hasA As Boolean = False, hasB As Boolean = False, hasDone As Boolean = False
        For Each s As PayPalAttemptRecord In stuck
            If s.Id = a.Id Then hasA = True
            If s.Id = b.Id Then hasB = True
            If s.Id = done.Id Then hasDone = True
        Next
        Check("L01 ListStuck returns old live attempts only (not recent ones, not final ones)", hasA AndAlso Not hasB AndAlso Not hasDone)
        Dim live As List(Of PayPalAttemptRecord) = PayPalPaymentAttempts.ListLiveByOwner(9201, 7801)
        Dim liveIds As New List(Of Long)()
        For Each l As PayPalAttemptRecord In live
            liveIds.Add(l.Id)
        Next
        Check("L02 ListLiveByOwner returns the live attempts of that owner only", liveIds.Contains(a.Id) AndAlso liveIds.Contains(b.Id) AndAlso Not liveIds.Contains(done.Id) AndAlso PayPalPaymentAttempts.ListLiveByOwner(9202, 7801).Count = 0 AndAlso PayPalPaymentAttempts.ListLiveByOwner(9201, 7899).Count = 0)
        Check("L03 listing limits are honored", PayPalPaymentAttempts.ListStuck(0, 1).Count <= 1)
        Dim rec As PayPalAttemptRecord = PayPalPaymentAttempts.LoadForOwner(a.AttemptKey, a.AziendeId, a.LoginId)
        Check("L04 the loaded record carries the age used by the recovery rules", rec.AgeMinutes >= 39 AndAlso PayPalPaymentAttemptStates.RecommendedAction(rec.Stato, rec.AgeMinutes, rec.PayPalOrderId.Length > 0, rec.DraftExpiresUtc < DateTime.UtcNow) = "NONE")
    End Sub
End Module
