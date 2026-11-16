Option Strict On
Option Explicit On

' Harness per Test-PayPalRepositoryRealSchema.ps1.
' Compila insieme al codice REALE di App_Code (PayPalCheckoutRepository, PayPalCheckoutConfig, PayPalPaymentState, ...) e lo esegue contro il database
' LAB LOCALE con il connettore MySql.Data reale e lo schema reale (colonne tinyint(1)), in due varianti dell'opzione TreatTinyAsBoolean.
' Mai segreti nel file: l'utente e la password del LAB arrivano dall'ambiente del processo (KS_LAB_*), la stringa di connessione resta in memoria.
' Dati di prova sintetici con ID alti (9101..9106), rimossi in ogni caso a fine corsa.
' Uscita: numero di controlli falliti (0 = tutto verde); 2 = ambiente non pronto.

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.Reflection
Imports System.Threading
Imports MySql.Data.MySqlClient

Public Module RealSchemaHarness
    Private _cs As String = String.Empty
    Private _tiny As Boolean = True
    Private _pass As Integer = 0
    Private _fail As Integer = 0
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const DocIds As String = "9101,9102,9103,9104,9105,9106,9107,9108"
    Private Const KeyA As String = "KS_TEST_ACC_A"
    Private Const KeyB As String = "KS_TEST_ACC_B"

    Private Sub Check(ByVal name As String, ByVal ok As Boolean)
        If ok Then
            _pass += 1
            Console.WriteLine("PASS " & name)
        Else
            _fail += 1
            Console.WriteLine("FAIL " & name)
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

    Private Function NewDoc(ByVal docId As Integer, ByVal companyId As Integer, ByVal paymentId As Integer,
                            ByVal origin As String, ByVal userId As Integer) As PayPalPaymentDocumentInfo
        Return New PayPalPaymentDocumentInfo With {.Exists = True, .DocumentId = docId, .AziendeId = companyId,
            .PagamentiTipoId = paymentId, .UtentiId = userId, .OrigineOrdine = origin, .TotalDocument = 12.34D}
    End Function

    Private Function Snap(ByVal orderId As String, ByVal captureId As String, ByVal amount As Decimal) As PayPalOrderSnapshot
        Return New PayPalOrderSnapshot With {.OrderId = orderId, .Status = "COMPLETED", .CaptureId = captureId,
            .CaptureStatus = "COMPLETED", .CaptureCount = 1, .CaptureAmount = amount, .CaptureCurrencyCode = "EUR",
            .CaptureAmountValid = True}
    End Function

    ' Copia verbatim della versione precedente di SafeInt: serve al differenziale sui valori non Boolean.
    Private Function LegacySafeInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return 0
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed)
        Return parsed
    End Function

    Public Function Main(ByVal args As String()) As Integer
        If args.Length > 0 AndAlso String.Equals(args(0), "tiny=false", StringComparison.OrdinalIgnoreCase) Then _tiny = False
        Dim user As String = Env("KS_LAB_USER")
        Dim pwd As String = Env("KS_LAB_PWD")
        Dim schema As String = Env("KS_LAB_SCHEMA")
        Dim port As String = Env("KS_LAB_PORT")
        If user = "" OrElse pwd = "" OrElse schema = "" OrElse port = "" Then
            Console.WriteLine("ENV_NOT_READY")
            Return 2
        End If
        Dim sb As New MySqlConnectionStringBuilder()
        sb.Server = "127.0.0.1"
        sb.Port = CUInt(Integer.Parse(port, CultureInfo.InvariantCulture))
        sb.Database = schema
        sb.UserID = user
        sb.Password = pwd
        ' Solo loopback (127.0.0.1) e identita del server verificata dopo la connessione; VerifyCA richiederebbe BouncyCastle.Crypto 1.9 non presente in Bin.
        sb.SslMode = MySqlSslMode.Required
        sb.TreatTinyAsBoolean = _tiny
        _cs = sb.ConnectionString
        pwd = String.Empty

        ' Stringa di connessione solo in memoria, prima di qualunque uso del repository (campo statico inizializzato una volta).
        Dim coll As ConnectionStringSettingsCollection = ConfigurationManager.ConnectionStrings
        Dim readOnlyField As FieldInfo = GetType(ConfigurationElementCollection).GetField("bReadOnly", BindingFlags.Instance Or BindingFlags.NonPublic)
        readOnlyField.SetValue(coll, False)
        coll.Add(New ConnectionStringSettings("EntropicConnectionString", _cs))

        Console.WriteLine("VARIANT TreatTinyAsBoolean=" & _tiny.ToString())
        Try
            If Not LabIdentityOk(schema) Then
                Console.WriteLine("LAB_IDENTITY_MISMATCH")
                Return 2
            End If
            If Scalar("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND ((TABLE_NAME='paypal_checkout_account' AND COLUMN_NAME IN ('ClientId','ClientSecret','WebhookId')) OR (TABLE_NAME='pagamentitipo' AND COLUMN_NAME='PermettiPagamentoSuccessivo'))") <> "4" Then
                Console.WriteLine("LAB_SCHEMA_NOT_READY")
                Return 2
            End If
            ' Le righe con questi ID devono essere solo le nostre sintetiche: mai cancellare dati che non sono di questo test.
            If Scalar("SELECT (SELECT COUNT(*) FROM documenti WHERE Id IN (" & DocIds & ") AND AziendeId NOT IN (9101,9102))+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9101,9102) AND AziendeID NOT IN (9101,9102))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9101,9102) AND PayeeEmail NOT LIKE '%@example.invalid')") <> "0" Then
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
            RunProbe()
            RunConfig()
            RunTransactions()
            RunPaymentOutcomes()
        Catch ex As Exception
            Check("harness-exception-" & ex.GetType().Name, False)
            Console.WriteLine("EXC " & ex.Message.Replace(vbCr, " ").Replace(vbLf, " "))
        Finally
            Try
                Cleanup()
                Check("cleanup-no-residue", Scalar("SELECT (SELECT COUNT(*) FROM documenti WHERE Id IN (" & DocIds & "))+(SELECT COUNT(*) FROM paypal_checkout_azienda WHERE AziendeId IN (9101,9102))+(SELECT COUNT(*) FROM paypal_checkout_account WHERE CredentialKey IN ('" & KeyA & "','" & KeyB & "'))+(SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId IN (" & DocIds & "))+(SELECT COUNT(*) FROM pagamentitipo WHERE id IN (9101,9102))") = "0")
            Catch ex As Exception
                Check("cleanup-exception-" & ex.GetType().Name, False)
            End Try
        End Try
        Console.WriteLine("RESULT variant=" & _tiny.ToString() & " pass=" & _pass.ToString(CultureInfo.InvariantCulture) & " fail=" & _fail.ToString(CultureInfo.InvariantCulture))
        Return _fail
    End Function

    Private Function LabIdentityOk(ByVal schema As String) As Boolean
        Return Scalar("SELECT @@server_uuid") = LabUuid AndAlso Scalar("SELECT @@port") = Env("KS_LAB_PORT") AndAlso
               Scalar("SELECT DATABASE()") = schema AndAlso schema.StartsWith("keepstore_regorder_lab", StringComparison.Ordinal)
    End Function

    Private Sub Cleanup()
        Exec("DELETE e FROM paypal_checkout_eventi e INNER JOIN paypal_checkout_transazioni t ON t.Id=e.TransazioniId WHERE t.DocumentiId IN (" & DocIds & ")")
        Exec("DELETE FROM paypal_checkout_transazioni WHERE DocumentiId IN (" & DocIds & ")")
        Exec("DELETE FROM paypal_checkout_azienda WHERE AziendeId IN (9101,9102)")
        Exec("DELETE FROM paypal_checkout_account WHERE CredentialKey IN ('" & KeyA & "','" & KeyB & "')")
        Exec("DELETE FROM documentipie WHERE DocumentiId IN (" & DocIds & ")")
        Exec("DELETE FROM documenti WHERE Id IN (" & DocIds & ")")
        Exec("DELETE FROM pagamentitipo WHERE id IN (9101,9102)")
    End Sub

    Private _userId As Integer = 1
    Private _typeId As Integer = 0
    Private _accountA As Integer = 0
    Private _accountB As Integer = 0

    Private Sub Setup()
        _userId = Integer.Parse(Scalar("SELECT COALESCE(MIN(UtentiId),1) FROM documenti"), CultureInfo.InvariantCulture)
        _typeId = Integer.Parse(Scalar("SELECT COALESCE(MIN(TipoDocumentiId),0) FROM documenti"), CultureInfo.InvariantCulture)
        For Each companyId As Integer In New Integer() {9101, 9102}
            Exec("INSERT INTO pagamentitipo (id,AziendeID,Descrizione,Informazioni,Abilitato,Web,Ordinamento,Predefinito,CostoPercentuale,CostoFisso,CostoMassimo,NumeroOrdini,Contrassegno,OnLine,Cassa,Banca) VALUES (" &
                 companyId & "," & companyId & ",'KS TEST PAYPAL','fixture',1,1,1,0,0,0,5000,0,0,2,0,0)")
        Next
        Exec("INSERT INTO paypal_checkout_account (NomeProfilo,CredentialKey,MerchantId,Attivo,ClientId,ClientSecret,WebhookId) VALUES ('KS TEST A','" & KeyA & "','KSMERCHANTA',1,'ks-fixture-client-a','ks-fixture-secret-a','ks-fixture-webhook-a')")
        _accountA = Integer.Parse(Scalar("SELECT Id FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'"), CultureInfo.InvariantCulture)
        Exec("INSERT INTO paypal_checkout_account (NomeProfilo,CredentialKey,MerchantId,Attivo,ClientId,ClientSecret,WebhookId) VALUES ('KS TEST B','" & KeyB & "','KSMERCHANTB',1,'ks-fixture-client-b','ks-fixture-secret-b','ks-fixture-webhook-b')")
        _accountB = Integer.Parse(Scalar("SELECT Id FROM paypal_checkout_account WHERE CredentialKey='" & KeyB & "'"), CultureInfo.InvariantCulture)
        Exec("INSERT INTO paypal_checkout_azienda (AziendeId,PagamentiTipoId,PayPalAccountId,PayeeEmail,BrandName,CurrencyCode,Attivo) VALUES (9101,9101," & _accountA & ",'fixture-a@example.invalid','KS TEST A','EUR',1)")
        Exec("INSERT INTO paypal_checkout_azienda (AziendeId,PagamentiTipoId,PayPalAccountId,PayeeEmail,BrandName,CurrencyCode,Attivo) VALUES (9102,9102," & _accountB & ",'fixture-b@example.invalid','KS TEST B','EUR',1)")
        Dim docs As String() = {"9101,9101,9101,'WEB'", "9102,9101,9101,'WEB'", "9103,9101,9101,'WEB'", "9104,9101,9101,'INTERNO'", "9105,9102,9102,'WEB'", "9106,9101,9101,'WEB'", "9107,9101,9101,'WEB'", "9108,9101,9101,'WEB'"}
        For Each row As String In docs
            Dim parts As String() = row.Split(","c)
            Exec("INSERT INTO documenti (Id,AziendeId,UtentiId,PagamentiTipoId,TipoDocumentiId,Pagato,OrigineOrdine,DataDocumento) VALUES (" &
                 parts(0) & "," & parts(1) & "," & _userId & "," & parts(2) & "," & _typeId & ",0," & parts(3) & ",NOW())")
            ' 9106: totale con piu di due decimali, come i vecchi ordini del gestionale (double(15,5), es. 69.95997).
            Exec("INSERT INTO documentipie (DocumentiId,TotaleDocumento) VALUES (" & parts(0) & "," & If(parts(0) = "9106", "12.34567", If(parts(0) = "9108", "12.345", "12.34")) & ")")
        Next
    End Sub

    ' La variante deve davvero cambiare il tipo restituito dal connettore, altrimenti il test non prova nulla.
    Private Sub RunVariantEffective()
        Using conn As New MySqlConnection(_cs)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT Attivo,(Attivo=1) AS Espressione FROM paypal_checkout_account WHERE CredentialKey='" & KeyA & "'", conn)
                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If dr.Read() Then
                        Dim rawName As String = dr.GetValue(0).GetType().Name
                        Check("variant-effective-raw-type", rawName = If(_tiny, "Boolean", "SByte"))
                        Check("variant-expression-is-integer", dr.GetValue(1).GetType().Name = "Int64")
                    Else
                        Check("variant-fixture-present", False)
                    End If
                End Using
            End Using
        End Using
    End Sub

    Private Sub RunProbe()
        Dim repoType As Type = Assembly.GetExecutingAssembly().GetType("PayPalCheckoutRepository")
        Dim mi As MethodInfo = If(repoType Is Nothing, Nothing, repoType.GetMethod("SafeInt", BindingFlags.NonPublic Or BindingFlags.Static))
        Check("probe-safeint-found", mi IsNot Nothing)
        If mi Is Nothing Then Return
        Dim Run As Func(Of Object, Integer) = Function(v As Object) Convert.ToInt32(mi.Invoke(Nothing, New Object() {v}), CultureInfo.InvariantCulture)
        Check("probe-boolean-true", Run(True) = 1)
        Check("probe-boolean-false", Run(False) = 0)
        Dim samples As Object() = {Nothing, DBNull.Value, CType(1, SByte), CType(0, SByte), 1, 7, -3, 1L, 0L, "1", "0", "42", "abc", "", " 5 ", "True"}
        Dim same As Boolean = True
        For Each sample As Object In samples
            If Run(sample) <> LegacySafeInt(sample) Then same = False
        Next
        Check("probe-non-boolean-unchanged-vs-legacy", same)

        ' Stessa guardia nel modulo PayPalPaymentState, che ha un SafeInt proprio (oggi legge solo int/CASE/COALESCE: trappola latente).
        Dim stateType As Type = Assembly.GetExecutingAssembly().GetType("PayPalPaymentState")
        Dim sm As MethodInfo = If(stateType Is Nothing, Nothing, stateType.GetMethod("SafeInt", BindingFlags.NonPublic Or BindingFlags.Static))
        Check("probe-state-safeint-found", sm IsNot Nothing)
        If sm IsNot Nothing Then
            Dim RunState As Func(Of Object, Integer) = Function(v As Object) Convert.ToInt32(sm.Invoke(Nothing, New Object() {v}), CultureInfo.InvariantCulture)
            Check("probe-state-boolean-true", RunState(True) = 1)
            Check("probe-state-boolean-false", RunState(False) = 0)
            Dim sameState As Boolean = True
            For Each sample As Object In samples
                If RunState(sample) <> LegacyStateSafeInt(sample) Then sameState = False
            Next
            Check("probe-state-non-boolean-unchanged-vs-legacy", sameState)
        End If
    End Sub

    ' Copia verbatim della versione precedente di SafeInt di PayPalPaymentState.
    Private Function LegacyStateSafeInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return 0
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(value), parsed)
        Return parsed
    End Function

    Private Sub RunConfig()
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-company-loaded", cfg IsNot Nothing)
        If cfg IsNot Nothing Then
            Check("cfg-account-active", cfg.AccountActive)
            Check("cfg-mapping-active", cfg.CompanyActive)
            Check("cfg-is-configured", cfg.IsConfigured)
            Check("cfg-fields", cfg.AziendeId = 9101 AndAlso cfg.PagamentiTipoId = 9101 AndAlso cfg.AccountId = _accountA AndAlso cfg.CurrencyCode = "EUR" AndAlso
                  cfg.PayeeEmail = "fixture-a@example.invalid" AndAlso cfg.MerchantId = "KSMERCHANTA" AndAlso cfg.CredentialKey = KeyA)
            Check("cfg-webhook-configured", cfg.IsWebhookConfigured)
        End If
        Dim viaDoc As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForDocument(9101)
        Check("cfg-document-loaded", viaDoc IsNot Nothing)
        If viaDoc IsNot Nothing Then
            Check("cfg-document-is-configured", viaDoc.IsConfigured)
            Check("cfg-document-same-account", viaDoc.AccountId = _accountA AndAlso viaDoc.AziendeId = 9101)
        End If
        Dim other As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9102, 9102)
        Check("cfg-other-company-own-data", other IsNot Nothing AndAlso other.IsConfigured AndAlso other.AccountId = _accountB AndAlso other.PayeeEmail = "fixture-b@example.invalid")
        Check("cfg-cross-company-1", PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9102) Is Nothing)
        Check("cfg-cross-company-2", PayPalCheckoutRepository.LoadConfigForCompanyPayment(9102, 9101) Is Nothing)

        ' Flag a 0: la configurazione si carica ma non e pronta.
        Exec("UPDATE paypal_checkout_account SET Attivo=0 WHERE CredentialKey='" & KeyA & "'")
        Dim accountOff As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-account-off", accountOff IsNot Nothing AndAlso Not accountOff.AccountActive AndAlso accountOff.CompanyActive AndAlso Not accountOff.IsConfigured)
        Dim accountOffDoc As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForDocument(9101)
        Check("cfg-account-off-document", accountOffDoc IsNot Nothing AndAlso Not accountOffDoc.AccountActive AndAlso Not accountOffDoc.IsConfigured)
        ' Valore anomalo 2: non e attivo in nessuna variante del connettore (fail chiuso).
        Exec("UPDATE paypal_checkout_account SET Attivo=2 WHERE CredentialKey='" & KeyA & "'")
        Dim accountTwo As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-account-value-2-not-active", accountTwo IsNot Nothing AndAlso Not accountTwo.AccountActive AndAlso Not accountTwo.IsConfigured)
        Dim accountTwoDoc As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForDocument(9101)
        Check("cfg-account-value-2-not-active-document", accountTwoDoc IsNot Nothing AndAlso Not accountTwoDoc.AccountActive AndAlso Not accountTwoDoc.IsConfigured)
        Exec("UPDATE paypal_checkout_account SET Attivo=1 WHERE CredentialKey='" & KeyA & "'")

        Exec("UPDATE paypal_checkout_azienda SET Attivo=0 WHERE AziendeId=9101")
        Dim mappingOff As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-mapping-off", mappingOff IsNot Nothing AndAlso mappingOff.AccountActive AndAlso Not mappingOff.CompanyActive AndAlso Not mappingOff.IsConfigured)
        Exec("UPDATE paypal_checkout_azienda SET Attivo=2 WHERE AziendeId=9101")
        Dim mappingTwo As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-mapping-value-2-not-active", mappingTwo IsNot Nothing AndAlso Not mappingTwo.CompanyActive AndAlso Not mappingTwo.IsConfigured)
        Dim mappingTwoDoc As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForDocument(9101)
        Check("cfg-mapping-value-2-not-active-document", mappingTwoDoc IsNot Nothing AndAlso Not mappingTwoDoc.CompanyActive AndAlso Not mappingTwoDoc.IsConfigured)
        Exec("UPDATE paypal_checkout_azienda SET Attivo=1 WHERE AziendeId=9101")

        Exec("UPDATE paypal_checkout_account SET ClientSecret='' WHERE CredentialKey='" & KeyA & "'")
        Dim noSecret As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-empty-secret-not-configured", noSecret IsNot Nothing AndAlso noSecret.AccountActive AndAlso Not noSecret.IsConfigured)
        Exec("UPDATE paypal_checkout_account SET ClientSecret='ks-fixture-secret-a' WHERE CredentialKey='" & KeyA & "'")

        Exec("UPDATE pagamentitipo SET OnLine=3 WHERE id=9102")
        Check("cfg-not-paypal-method-ignored", PayPalCheckoutRepository.LoadConfigForCompanyPayment(9102, 9102) Is Nothing)
        Exec("UPDATE pagamentitipo SET OnLine=2 WHERE id=9102")

        Dim again As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        Check("cfg-restored", again IsNot Nothing AndAlso again.IsConfigured)
    End Sub

    Private Sub RunTransactions()
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        If cfg Is Nothing Then
            Check("tx-config-available", False)
            Return
        End If

        ' 1) primo tentativo web
        Dim doc1 As PayPalPaymentDocumentInfo = NewDoc(9101, 9101, 9101, "WEB", _userId)
        Dim tx1 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc1, cfg)
        Check("tx-ensure-exists", tx1 IsNot Nothing AndAlso tx1.Exists)
        Check("tx-ensure-current", tx1 IsNot Nothing AndAlso tx1.IsCurrent)
        Check("tx-ensure-fields", tx1 IsNot Nothing AndAlso tx1.TentativoNo = 1 AndAlso tx1.Stato = "CREATING" AndAlso tx1.Importo = 12.34D AndAlso tx1.Valuta = "EUR" AndAlso tx1.AziendeId = 9101)
        Dim tx1b As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc1, cfg)
        Check("tx-ensure-idempotent", tx1b IsNot Nothing AndAlso tx1b.Exists AndAlso tx1b.IsCurrent AndAlso tx1b.Id = tx1.Id)
        Dim byDoc As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForDocument(9101)
        Check("tx-load-for-document-current", byDoc IsNot Nothing AndAlso byDoc.Exists AndAlso byDoc.IsCurrent)
        Check("tx-not-found", Not PayPalCheckoutRepository.LoadTransactionForDocument(9106).Exists)

        ' 2) order creato, ricerche per riferimento esterno
        Dim created As PayPalOrderSnapshot = New PayPalOrderSnapshot With {.OrderId = "KSORD9101A", .Status = "CREATED"}
        Check("tx-record-order-created", PayPalCheckoutRepository.RecordOrderCreated(tx1, created))
        Dim byOrder As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9101A")
        Check("tx-load-for-order", byOrder IsNot Nothing AndAlso byOrder.Exists AndAlso byOrder.IsCurrent AndAlso byOrder.Stato = "CREATED" AndAlso byOrder.PayPalOrderId = "KSORD9101A")
        Dim viaRef As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForExternalReference("KSORD9101A")
        Check("tx-load-for-external-reference", viaRef IsNot Nothing AndAlso viaRef.Exists AndAlso viaRef.IsCurrent AndAlso viaRef.Id = tx1.Id)
        Check("tx-document-marked-pending", Scalar("SELECT CONCAT(StatoPagamentoWeb,'|',IdTransazione) FROM documenti WHERE Id=9101") = "1|PP-ORDER:KSORD9101A")

        ' 3) capture: prima gli esiti da rifiutare, poi quello valido
        Check("tx-begin-capture", PayPalCheckoutRepository.TryBeginCapture(byOrder))
        Check("tx-state-capturing", Scalar("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=9101 AND CurrentSlot=1") = "CAPTURING")
        Check("apply-partial-capture-rejected", Not PayPalCheckoutRepository.ApplyAuthoritativeState(byOrder, Snap("KSORD9101A", "KSCAP9101", 10D), "KSEV9101X"))
        Check("apply-document-untouched-after-reject", Scalar("SELECT CONCAT(Pagato,'|',StatoPagamentoWeb) FROM documenti WHERE Id=9101") = "0|1")
        Check("apply-completed", PayPalCheckoutRepository.ApplyAuthoritativeState(byOrder, Snap("KSORD9101A", "KSCAP9101", 12.34D), "KSEV9101"))
        Check("apply-document-paid", Scalar("SELECT CONCAT(Pagato,'|',StatoPagamentoWeb,'|',IdTransazione) FROM documenti WHERE Id=9101") = "1|2|TXN:KSCAP9101")
        Check("apply-transaction-completed", Scalar("SELECT CONCAT(Stato,'|',PayPalCaptureId) FROM paypal_checkout_transazioni WHERE DocumentiId=9101") = "COMPLETED|KSCAP9101")
        Check("apply-replay-same-event", PayPalCheckoutRepository.ApplyAuthoritativeState(byOrder, Snap("KSORD9101A", "KSCAP9101", 12.34D), "KSEV9101"))
        Check("apply-event-recorded-once", Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi WHERE EventId='KSEV9101'") = "1")
        Check("apply-document-still-paid", Scalar("SELECT CONCAT(Pagato,'|',StatoPagamentoWeb,'|',IdTransazione) FROM documenti WHERE Id=9101") = "1|2|TXN:KSCAP9101")

        ' 4) annullo web
        Dim doc3 As PayPalPaymentDocumentInfo = NewDoc(9103, 9101, 9101, "WEB", _userId)
        Dim tx3 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc3, cfg)
        Check("cancel-ensure-current", tx3.Exists AndAlso tx3.IsCurrent)
        Check("cancel-record-order", PayPalCheckoutRepository.RecordOrderCreated(tx3, New PayPalOrderSnapshot With {.OrderId = "KSORD9103A", .Status = "CREATED"}))
        Dim tx3b As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9103A")
        Check("cancel-mark", tx3b.IsCurrent AndAlso PayPalCheckoutRepository.MarkCanceled(tx3b))
        Check("cancel-state", Scalar("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=9103 AND CurrentSlot=1") = "CANCELED" AndAlso
              Scalar("SELECT StatoPagamentoWeb FROM documenti WHERE Id=9103") = "4")
        Check("cancel-capture-allowed-after-cancel", PayPalCheckoutRepository.TryBeginCapture(PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9103A")))

        ' 5) nuovo tentativo su ordine interno dopo annullo
        Dim doc4 As PayPalPaymentDocumentInfo = NewDoc(9104, 9101, 9101, "INTERNO", _userId)
        Dim tx4 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc4, cfg)
        Check("next-ensure-current", tx4.Exists AndAlso tx4.IsCurrent)
        Check("next-record-order", PayPalCheckoutRepository.RecordOrderCreated(tx4, New PayPalOrderSnapshot With {.OrderId = "KSORD9104A", .Status = "CREATED"}))
        Dim tx4b As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9104A")
        Check("next-cancel", tx4b.IsCurrent AndAlso PayPalCheckoutRepository.MarkCanceled(tx4b))
        Dim previous As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9104A")
        Dim voided As New PayPalOrderSnapshot With {.OrderId = "KSORD9104A", .Status = "VOIDED"}
        Dim second As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.StartNextAttempt(doc4, cfg, previous, voided)
        Check("next-attempt-started", second IsNot Nothing AndAlso second.Exists AndAlso second.IsCurrent AndAlso second.TentativoNo = 2 AndAlso String.IsNullOrEmpty(second.PayPalOrderId))
        Dim old As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9104A")
        Check("next-previous-not-current", old IsNot Nothing AndAlso old.Exists AndAlso Not old.IsCurrent AndAlso old.Stato = "SUPERSEDED")
        Check("next-previous-slot-null", Scalar("SELECT CurrentSlot FROM paypal_checkout_transazioni WHERE DocumentiId=9104 AND TentativoNo=1") = "<null>")
        Check("next-only-one-current", Scalar("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=9104 AND CurrentSlot=1") = "1")
        Check("next-capture-on-superseded-refused", Not PayPalCheckoutRepository.TryBeginCapture(old))
        Dim refused As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.StartNextAttempt(NewDoc(9101, 9101, 9101, "WEB", _userId), cfg, byOrder, voided)
        Check("next-not-allowed-on-web-order", refused IsNot Nothing AndAlso Not refused.Exists)

        ' 6) isolamento azienda: un documento dell'azienda 9102 non si paga con una transazione dell'azienda 9101
        Dim cfgB As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9102, 9102)
        Dim doc5 As PayPalPaymentDocumentInfo = NewDoc(9105, 9102, 9102, "WEB", _userId)
        Dim tx5 As PayPalCheckoutTransactionInfo = If(cfgB Is Nothing, New PayPalCheckoutTransactionInfo(), PayPalCheckoutRepository.EnsureTransaction(doc5, cfgB))
        Check("tenant-b-transaction", tx5.Exists AndAlso tx5.IsCurrent AndAlso tx5.AziendeId = 9102 AndAlso tx5.PayPalAccountId = _accountB)
        Check("tenant-wrong-company-rejected", Not PayPalCheckoutRepository.EnsureTransaction(NewDoc(9105, 9101, 9102, "WEB", _userId), cfgB).Exists)

        ' 7) concorrenza: due richieste insieme su un documento nuovo producono una sola riga corrente
        Dim doc2 As PayPalPaymentDocumentInfo = NewDoc(9102, 9101, 9101, "WEB", _userId)
        Dim results(1) As PayPalCheckoutTransactionInfo
        Dim t1 As New Thread(Sub() results(0) = PayPalCheckoutRepository.EnsureTransaction(doc2, cfg))
        Dim t2 As New Thread(Sub() results(1) = PayPalCheckoutRepository.EnsureTransaction(doc2, cfg))
        t1.Start() : t2.Start() : t1.Join() : t2.Join()
        Check("concurrent-ensure-one-row", Scalar("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=9102") = "1")
        Check("concurrent-ensure-both-current", results(0) IsNot Nothing AndAlso results(1) IsNot Nothing AndAlso results(0).IsCurrent AndAlso results(1).IsCurrent AndAlso results(0).Id = results(1).Id)
    End Sub
    Private Function Pending(ByVal orderId As String, ByVal captureId As String, ByVal status As String) As PayPalOrderSnapshot
        Dim s As PayPalOrderSnapshot = Snap(orderId, captureId, 12.34D)
        s.Status = "APPROVED"
        s.CaptureStatus = status
        Return s
    End Function

    Private Function DocState(ByVal docId As Integer) As String
        Return Scalar("SELECT CONCAT(Pagato,'|',StatoPagamentoWeb,'|',COALESCE(IdTransazione,'')) FROM documenti WHERE Id=" & docId.ToString(CultureInfo.InvariantCulture))
    End Function

    ' Esiti del pagamento con i tipi reali: documento letto dal codice reale, totale non arrotondato, rifiuti, pending, denied, tardivi.
    Private Sub RunPaymentOutcomes()
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutRepository.LoadConfigForCompanyPayment(9101, 9101)
        If cfg Is Nothing Then
            Check("outcome-config-available", False)
            Return
        End If

        ' A) il documento 9106 ha totale 12.34567 (come i vecchi ordini del gestionale): il PayPal addebita 12.35 e il documento deve risultare pagato.
        Dim realDoc As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForPayment(9106)
        Check("real-document-loaded", realDoc IsNot Nothing AndAlso realDoc.Exists AndAlso realDoc.AziendeId = 9101 AndAlso realDoc.PagamentiTipoId = 9101 AndAlso
              realDoc.PaymentOnline = 2 AndAlso realDoc.OrigineOrdine = "WEB" AndAlso realDoc.Pagato = 0 AndAlso realDoc.UtentiId = _userId)
        Check("real-document-total-unrounded", realDoc IsNot Nothing AndAlso realDoc.TotalDocument = 12.34567D)
        If realDoc Is Nothing OrElse Not realDoc.Exists Then Return
        Dim txR As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(realDoc, cfg)
        Check("rounding-attempt", txR.Exists AndAlso txR.IsCurrent AndAlso txR.Importo = 12.35D)
        Check("rounding-record-order", PayPalCheckoutRepository.RecordOrderCreated(txR, New PayPalOrderSnapshot With {.OrderId = "KSORD9106A", .Status = "CREATED"}))
        Dim txR2 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9106A")
        Check("rounding-begin-capture", PayPalCheckoutRepository.TryBeginCapture(txR2))
        Check("rounding-apply-completed", PayPalCheckoutRepository.ApplyAuthoritativeState(txR2, Snap("KSORD9106A", "KSCAP9106A", 12.35D), "KSEV9106"))
        Check("rounding-document-paid", DocState(9106) = "1|2|TXN:KSCAP9106A")

        ' A2) il mezzo centesimo esatto (12.345) si arrotonda verso l'alto (12.35), non al pari: stessa regola dell'arrotondamento dei documenti
        Dim doc8 As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForPayment(9108)
        Dim tx8 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc8, cfg)
        Check("midpoint-attempt", tx8.Exists AndAlso tx8.IsCurrent AndAlso tx8.Importo = 12.35D)
        Check("midpoint-record-order", PayPalCheckoutRepository.RecordOrderCreated(tx8, New PayPalOrderSnapshot With {.OrderId = "KSORD9108A", .Status = "CREATED"}))
        Dim txM As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9108A")
        Check("midpoint-apply-completed", PayPalCheckoutRepository.TryBeginCapture(txM) AndAlso PayPalCheckoutRepository.ApplyAuthoritativeState(txM, Snap("KSORD9108A", "KSCAP9108A", 12.35D), "KSEV9108"))
        Check("midpoint-document-paid", DocState(9108) = "1|2|TXN:KSCAP9108A")

        ' B) documento 9107: rifiuti (importo, valuta, ordine, azienda), poi pending e denied sul tentativo corrente
        Dim doc7 As PayPalPaymentDocumentInfo = PayPalPaymentState.LoadDocumentForPayment(9107)
        Dim tx7 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.EnsureTransaction(doc7, cfg)
        Check("outcome-ensure", tx7.Exists AndAlso tx7.IsCurrent AndAlso tx7.Importo = 12.34D)
        Check("outcome-record-order", PayPalCheckoutRepository.RecordOrderCreated(tx7, New PayPalOrderSnapshot With {.OrderId = "KSORD9107A", .Status = "CREATED"}))
        Dim cur7 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9107A")
        Check("outcome-amount-mismatch-rejected", Not PayPalCheckoutRepository.ApplyAuthoritativeState(cur7, Snap("KSORD9107A", "KSCAP9107A", 12.35D), "KSEV9107A"))
        Dim usd As PayPalOrderSnapshot = Snap("KSORD9107A", "KSCAP9107A", 12.34D)
        usd.CaptureCurrencyCode = "USD"
        Check("outcome-currency-mismatch-rejected", Not PayPalCheckoutRepository.ApplyAuthoritativeState(cur7, usd, "KSEV9107B"))
        Check("outcome-other-order-rejected", Not PayPalCheckoutRepository.ApplyAuthoritativeState(cur7, Snap("KSORD9999Z", "KSCAP9107A", 12.34D), "KSEV9107C"))
        Dim forged As New PayPalCheckoutTransactionInfo With {.Exists = True, .Id = cur7.Id, .DocumentiId = cur7.DocumentiId, .TentativoNo = cur7.TentativoNo,
            .IsCurrent = True, .AziendeId = 9102, .PagamentiTipoId = cur7.PagamentiTipoId, .PayPalAccountId = cur7.PayPalAccountId, .PayPalOrderId = cur7.PayPalOrderId,
            .Stato = cur7.Stato, .Importo = cur7.Importo, .Valuta = cur7.Valuta}
        Check("outcome-cross-tenant-rejected", Not PayPalCheckoutRepository.ApplyAuthoritativeState(forged, Snap("KSORD9107A", "KSCAP9107A", 12.34D), "KSEV9107D"))
        Check("outcome-document-untouched-after-rejects", DocState(9107) = "0|1|PP-ORDER:KSORD9107A")
        Check("outcome-no-events-after-rejects", Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi e INNER JOIN paypal_checkout_transazioni t ON t.Id=e.TransazioniId WHERE t.DocumentiId=9107") = "0")
        Check("outcome-pending-applied", PayPalCheckoutRepository.ApplyAuthoritativeState(cur7, Pending("KSORD9107A", "KSCAP9107A", "PENDING"), "KSEV9107P"))
        Check("outcome-pending-state", Scalar("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=9107 AND CurrentSlot=1") = "PENDING" AndAlso DocState(9107) = "0|1|PP-ORDER:KSORD9107A")
        Check("outcome-denied-applied", PayPalCheckoutRepository.ApplyAuthoritativeState(cur7, Pending("KSORD9107A", "KSCAP9107A", "DENIED"), "KSEV9107X"))
        Check("outcome-denied-state", Scalar("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=9107 AND CurrentSlot=1") = "DENIED" AndAlso DocState(9107) = "0|3|PP-ORDER:KSORD9107A")

        ' C) stesso capture con un altro evento sul documento 9101 gia pagato: nessun doppio pagamento, evento registrato
        Dim paid1 As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9101A")
        Check("outcome-same-capture-other-event", PayPalCheckoutRepository.ApplyAuthoritativeState(paid1, Snap("KSORD9101A", "KSCAP9101", 12.34D), "KSEV9101B"))
        Check("outcome-same-capture-document-unchanged", DocState(9101) = "1|2|TXN:KSCAP9101")
        Check("outcome-two-events-recorded", Scalar("SELECT COUNT(*) FROM paypal_checkout_eventi e INNER JOIN paypal_checkout_transazioni t ON t.Id=e.TransazioniId WHERE t.DocumentiId=9101") = "2")

        ' D) tentativo SUPERSEDED (documento interno 9104): un pending non lo cambia, un completamento tardivo paga il documento
        Dim old As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForOrder("KSORD9104A")
        Check("late-attempt-is-superseded", old.Exists AndAlso Not old.IsCurrent)
        Check("late-pending-ignored", PayPalCheckoutRepository.ApplyAuthoritativeState(old, Pending("KSORD9104A", "KSCAP9104A", "PENDING"), "KSEV9104P"))
        Check("late-pending-changed-nothing", Scalar("SELECT Stato FROM paypal_checkout_transazioni WHERE DocumentiId=9104 AND TentativoNo=1") = "SUPERSEDED" AndAlso DocState(9104).StartsWith("0|", StringComparison.Ordinal))
        Check("late-completed-applied", PayPalCheckoutRepository.ApplyAuthoritativeState(old, Snap("KSORD9104A", "KSCAP9104A", 12.34D), "KSEV9104"))
        Check("late-document-paid", DocState(9104) = "1|2|TXN:KSCAP9104A")
        Check("late-old-attempt-completed", Scalar("SELECT CONCAT(Stato,'|',PayPalCaptureId) FROM paypal_checkout_transazioni WHERE DocumentiId=9104 AND TentativoNo=1") = "COMPLETED|KSCAP9104A")
        Check("late-new-attempt-kept", Scalar("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=9104 AND CurrentSlot=1") = "1")
    End Sub
End Module
