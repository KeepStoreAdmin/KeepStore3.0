Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports MySql.Data.MySqlClient

' PAYPAL-ATTEMPTS-TABLE-1A (fase P2 del pay-first): tentativi di pagamento PayPal durevoli, creati PRIMA del documento (nessun numero ordine esiste ancora).
' Codice INERTE: nessuna pagina lo chiama finche non arriva P3. Tabella e regole: docs/PAYPAL_PAY_FIRST_ATTEMPTS_TABLE.md (script SQL nella stessa pagina).
' REGOLE DI BLOCCO (ordine globale: tentativo -> documenti -> transazioni): nessuna transazione tiene una riga del tentativo mentre chiama PayPal; nella transazione
' dei documenti il tentativo si blocca PER PRIMO (LockForDocument) e solo dopo si inserisce il documento e si lega (BindDocument); le altre transizioni sono UPDATE
' brevi di una sola riga, guardati dallo stato (e dall'azienda; dall'utente quando il chiamante e il cliente). Ogni scrittura di stato passa da
' PayPalPaymentAttemptStates: il repository non scrive mai una transizione che la macchina a stati non ammette.

Public Enum PayPalAttemptCreateOutcome
    Created = 1
    Resumed = 2
    Blocked = 3
    TechnicalError = 4
End Enum

Public Enum PayPalBeginCaptureOutcome
    Started = 1
    NotInState = 2
    DocumentInvalid = 3
    TechnicalError = 4
End Enum

Public Class PayPalAttemptCreateRequest
    Public Property AziendeId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property PagamentiTipoId As Integer
    Public Property PayPalAccountId As Integer
    Public Property DatabaseScopeKey As String
    Public Property DraftRequestId As String
    Public Property PayloadFingerprint As String
    Public Property DraftExpiresUtc As DateTime
    Public Property Importo As Decimal
    Public Property Valuta As String
    Public Property PayeeEmail As String
    Public Property MerchantId As String
End Class

Public Class PayPalAttemptRecord
    Public Property Id As Long
    Public Property AttemptKey As String
    Public Property AziendeId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property PagamentiTipoId As Integer
    Public Property PayPalAccountId As Integer
    Public Property DatabaseScopeKey As String
    Public Property DraftRequestId As String
    Public Property PayloadFingerprint As String
    Public Property DraftExpiresUtc As DateTime
    Public Property TentativoNo As Integer
    Public Property IsCurrent As Boolean
    Public Property Stato As String
    Public Property StatoPrecedente As String
    Public Property Importo As Decimal
    Public Property Valuta As String
    Public Property PayeeEmail As String
    Public Property MerchantId As String
    Public Property CreateRequestId As String
    Public Property AuthorizeRequestId As String
    Public Property CaptureRequestId As String
    Public Property VoidRequestId As String
    Public Property PayPalOrderId As String
    Public Property PayPalAuthorizationId As String
    Public Property PayPalCaptureId As String
    Public Property AuthorizationExpiresUtc As DateTime?
    Public Property DocumentiId As Integer
    Public Property UltimoEsito As String
    ' Minuti dall'ultimo aggiornamento, calcolati dal database (stesso orologio di UpdatedAt).
    Public Property AgeMinutes As Integer
End Class

Public NotInheritable Class PayPalPaymentAttempts
    Private Sub New()
    End Sub

    Private Const SelectColumns As String =
        "Id,AttemptKey,AziendeId,LoginId,UtentiId,PagamentiTipoId,PayPalAccountId,DatabaseScopeKey,DraftRequestId,PayloadFingerprint,DraftExpiresAt,TentativoNo,CurrentSlot," &
        "Stato,StatoPrecedente,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,AuthorizeRequestId,CaptureRequestId,VoidRequestId,PayPalOrderId,PayPalAuthorizationId," &
        "PayPalCaptureId,AuthorizationExpiresAt,DocumentiId,UltimoEsito,TIMESTAMPDIFF(MINUTE,UpdatedAt,NOW()) AS AgeMinutes"

    Private Shared ReadOnly KeyPattern As New Regex("^[0-9a-f]{32}$", RegexOptions.Compiled Or RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly CurrencyPattern As New Regex("^[A-Z]{3}$", RegexOptions.Compiled Or RegexOptions.CultureInvariant)

    Private Shared Function ConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function

    ' ----- creazione e ripresa -----

    ' Un solo tentativo vivo per (azienda, login, bozza). Stessa bozza e stesso fingerprint = Resumed; bozza cambiata con un tentativo vivo = Blocked (P3 lo annulla
    ' prima); altrimenti Created con il numero successivo. Nessun lock su righe inesistenti: INSERT e, su duplicato/deadlock, rilettura (al massimo 3 giri).
    Public Shared Function CreateOrResume(ByVal request As PayPalAttemptCreateRequest) As PayPalAttemptCreateResult
        Dim failure As New PayPalAttemptCreateResult With {.Outcome = PayPalAttemptCreateOutcome.TechnicalError}
        If Not IsRequestValid(request) Then Return failure
        Dim importo As Decimal = Math.Round(request.Importo, 2, MidpointRounding.AwayFromZero)
        Try
            For round As Integer = 1 To 3
                Using conn As New MySqlConnection(ConnectionString())
                    conn.Open()
                    Dim live As PayPalAttemptRecord = ReadOne(conn, Nothing,
                        "SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE AziendeId=@az AND LoginId=@login AND DraftRequestId=@draft AND CurrentSlot=1 LIMIT 1",
                        Sub(cmd)
                            cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = request.AziendeId
                            cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = request.LoginId
                            cmd.Parameters.Add("@draft", MySqlDbType.String).Value = request.DraftRequestId
                        End Sub)
                    If live IsNot Nothing Then
                        Dim same As Boolean = String.Equals(live.PayloadFingerprint, request.PayloadFingerprint, StringComparison.Ordinal) AndAlso live.PagamentiTipoId = request.PagamentiTipoId
                        Return New PayPalAttemptCreateResult With {.Outcome = If(same, PayPalAttemptCreateOutcome.Resumed, PayPalAttemptCreateOutcome.Blocked), .Attempt = live}
                    End If
                    Dim nextNumber As Integer
                    Using next1 As New MySqlCommand("SELECT COALESCE(MAX(TentativoNo),0)+1 FROM paypal_checkout_tentativi WHERE AziendeId=@az AND LoginId=@login AND DraftRequestId=@draft", conn)
                        next1.Parameters.Add("@az", MySqlDbType.Int32).Value = request.AziendeId
                        next1.Parameters.Add("@login", MySqlDbType.Int64).Value = request.LoginId
                        next1.Parameters.Add("@draft", MySqlDbType.String).Value = request.DraftRequestId
                        nextNumber = Convert.ToInt32(next1.ExecuteScalar(), CultureInfo.InvariantCulture)
                    End Using
                    Dim key As String = Guid.NewGuid().ToString("N")
                    Try
                        Using insert As New MySqlCommand(
                            "INSERT INTO paypal_checkout_tentativi (AttemptKey,AziendeId,LoginId,UtentiId,PagamentiTipoId,PayPalAccountId,DatabaseScopeKey,DraftRequestId,PayloadFingerprint,DraftExpiresAt," &
                            "TentativoNo,CurrentSlot,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,AuthorizeRequestId,CaptureRequestId,VoidRequestId) VALUES (" &
                            "@key,@az,@login,@utenti,@pagamento,@account,@scope,@draft,@fp,@expires,@no,1,'CREATING',@importo,@valuta,@payee,@merchant,@rc,@ra,@rk,@rv)", conn)
                            insert.Parameters.Add("@key", MySqlDbType.String).Value = key
                            insert.Parameters.Add("@az", MySqlDbType.Int32).Value = request.AziendeId
                            insert.Parameters.Add("@login", MySqlDbType.Int64).Value = request.LoginId
                            insert.Parameters.Add("@utenti", MySqlDbType.Int64).Value = request.UtentiId
                            insert.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = request.PagamentiTipoId
                            insert.Parameters.Add("@account", MySqlDbType.Int32).Value = request.PayPalAccountId
                            insert.Parameters.Add("@scope", MySqlDbType.String).Value = request.DatabaseScopeKey
                            insert.Parameters.Add("@draft", MySqlDbType.String).Value = request.DraftRequestId
                            insert.Parameters.Add("@fp", MySqlDbType.String).Value = request.PayloadFingerprint
                            insert.Parameters.Add("@expires", MySqlDbType.DateTime).Value = request.DraftExpiresUtc.ToUniversalTime()
                            insert.Parameters.Add("@no", MySqlDbType.Int32).Value = nextNumber
                            insert.Parameters.Add("@importo", MySqlDbType.Decimal).Value = importo
                            insert.Parameters.Add("@valuta", MySqlDbType.String).Value = request.Valuta
                            insert.Parameters.Add("@payee", MySqlDbType.String).Value = request.PayeeEmail
                            insert.Parameters.Add("@merchant", MySqlDbType.String).Value = request.MerchantId
                            insert.Parameters.Add("@rc", MySqlDbType.String).Value = "PPA-" & key & "-C"
                            insert.Parameters.Add("@ra", MySqlDbType.String).Value = "PPA-" & key & "-A"
                            insert.Parameters.Add("@rk", MySqlDbType.String).Value = "PPA-" & key & "-K"
                            insert.Parameters.Add("@rv", MySqlDbType.String).Value = "PPA-" & key & "-V"
                            insert.ExecuteNonQuery()
                        End Using
                    Catch ex As MySqlException When ex.Number = 1062 OrElse ex.Number = 1213 OrElse ex.Number = 1205
                        ' un'altra richiesta ha vinto la stessa bozza: si rilegge (il giro successivo trovera il tentativo vivo)
                        Continue For
                    End Try
                    Dim created As PayPalAttemptRecord = ReadOne(conn, Nothing, "SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE AttemptKey=@key LIMIT 1",
                        Sub(cmd)
                            cmd.Parameters.Add("@key", MySqlDbType.String).Value = key
                        End Sub)
                    If created Is Nothing Then Return failure
                    Return New PayPalAttemptCreateResult With {.Outcome = PayPalAttemptCreateOutcome.Created, .Attempt = created}
                End Using
            Next
        Catch ex As Exception
            LogFailure("CreateOrResume", ex)
        End Try
        Return failure
    End Function

    Private Shared Function IsRequestValid(ByVal r As PayPalAttemptCreateRequest) As Boolean
        If r Is Nothing Then Return False
        If r.AziendeId <= 0 OrElse r.LoginId <= 0 OrElse r.UtentiId <= 0 OrElse r.PagamentiTipoId <= 0 OrElse r.PayPalAccountId <= 0 Then Return False
        If String.IsNullOrEmpty(r.DraftRequestId) OrElse Not KeyPattern.IsMatch(r.DraftRequestId) Then Return False
        If String.IsNullOrWhiteSpace(r.PayloadFingerprint) OrElse r.PayloadFingerprint.Length > 128 Then Return False
        If String.IsNullOrWhiteSpace(r.DatabaseScopeKey) OrElse r.DatabaseScopeKey.Length > 128 Then Return False
        If Math.Round(r.Importo, 2, MidpointRounding.AwayFromZero) <= 0D Then Return False
        If String.IsNullOrEmpty(r.Valuta) OrElse Not CurrencyPattern.IsMatch(r.Valuta) Then Return False
        If String.IsNullOrWhiteSpace(r.PayeeEmail) OrElse r.PayeeEmail.Length > 254 OrElse String.IsNullOrWhiteSpace(r.MerchantId) OrElse r.MerchantId.Length > 128 Then Return False
        Return True
    End Function

    ' ----- letture -----

    ' Il cliente carica il proprio tentativo: serve azienda E login (nessun fallback tra utenti della stessa azienda).
    Public Shared Function LoadForOwner(ByVal attemptKey As String, ByVal aziendeId As Integer, ByVal loginId As Long) As PayPalAttemptRecord
        If String.IsNullOrEmpty(attemptKey) OrElse Not KeyPattern.IsMatch(attemptKey) OrElse aziendeId <= 0 OrElse loginId <= 0 Then Return Nothing
        Return LoadOne("WHERE AttemptKey=@v AND AziendeId=@az AND LoginId=@login", attemptKey, aziendeId, loginId, "LoadForOwner")
    End Function

    ' Ultimo tentativo della bozza (anche con lo slot gia rilasciato: serve a riconoscere CAPTURED_ORPHAN e a non aprire un secondo pagamento). Azienda E login.
    ' Nothing = nessun tentativo oppure errore tecnico (il chiamante apre il pagamento e CreateOrResume fallisce chiuso se il database non risponde).
    Public Shared Function LoadLatestForDraft(ByVal aziendeId As Integer, ByVal loginId As Long, ByVal draftRequestId As String) As PayPalAttemptRecord
        If aziendeId <= 0 OrElse loginId <= 0 OrElse String.IsNullOrEmpty(draftRequestId) Then Return Nothing
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Return ReadOne(conn, Nothing, "SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE AziendeId=@az AND LoginId=@login AND DraftRequestId=@draft ORDER BY TentativoNo DESC LIMIT 1",
                    Sub(cmd)
                        cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                        cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                        cmd.Parameters.Add("@draft", MySqlDbType.String).Value = draftRequestId
                    End Sub)
            End Using
        Catch ex As Exception
            LogFailure("LoadLatestForDraft", ex)
            Return Nothing
        End Try
    End Function

    ' Caricamenti di SISTEMA (webhook firmato da PayPal, recupero): niente login; solo codice fidato, mai un input del cliente.
    Public Shared Function LoadForSystemByOrderId(ByVal orderId As String) As PayPalAttemptRecord
        If String.IsNullOrWhiteSpace(orderId) OrElse orderId.Length > 100 Then Return Nothing
        Return LoadOne("WHERE PayPalOrderId=@v", orderId, 0, 0, "LoadForSystemByOrderId")
    End Function

    Public Shared Function LoadForSystemByAuthorizationId(ByVal authorizationId As String) As PayPalAttemptRecord
        If String.IsNullOrWhiteSpace(authorizationId) OrElse authorizationId.Length > 100 Then Return Nothing
        Return LoadOne("WHERE PayPalAuthorizationId=@v", authorizationId, 0, 0, "LoadForSystemByAuthorizationId")
    End Function

    Public Shared Function LoadForSystemByCaptureId(ByVal captureId As String) As PayPalAttemptRecord
        If String.IsNullOrWhiteSpace(captureId) OrElse captureId.Length > 100 Then Return Nothing
        Return LoadOne("WHERE PayPalCaptureId=@v", captureId, 0, 0, "LoadForSystemByCaptureId")
    End Function

    Public Shared Function LoadForSystemByDocumentId(ByVal documentId As Integer) As PayPalAttemptRecord
        If documentId <= 0 Then Return Nothing
        Return LoadOne("WHERE DocumentiId=@v", documentId.ToString(CultureInfo.InvariantCulture), 0, 0, "LoadForSystemByDocumentId")
    End Function

    Private Shared Function LoadOne(ByVal whereClause As String, ByVal value As String, ByVal aziendeId As Integer, ByVal loginId As Long, ByVal operation As String) As PayPalAttemptRecord
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Return ReadOne(conn, Nothing, "SELECT " & SelectColumns & " FROM paypal_checkout_tentativi " & whereClause & " LIMIT 1",
                    Sub(cmd)
                        cmd.Parameters.Add("@v", MySqlDbType.String).Value = value
                        If whereClause.Contains("@az") Then cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                        If whereClause.Contains("@login") Then cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                    End Sub)
            End Using
        Catch ex As Exception
            LogFailure(operation, ex)
            Return Nothing
        End Try
    End Function

    ' Tentativi vivi e fermi da almeno N minuti (il recupero li classifica con PayPalPaymentAttemptStates.RecommendedAction).
    Public Shared Function ListStuck(ByVal olderThanMinutes As Integer, ByVal maxRows As Integer) As List(Of PayPalAttemptRecord)
        Dim minutes As Integer = Math.Max(0, olderThanMinutes)
        Dim limit As Integer = Math.Min(1000, Math.Max(1, maxRows))
        Return ReadMany("SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE Stato NOT IN ('COMPLETED','VOIDED','FAILED','CANCELED','CAPTURED_ORPHAN') " &
                        "AND UpdatedAt <= NOW() - INTERVAL " & minutes.ToString(CultureInfo.InvariantCulture) & " MINUTE ORDER BY UpdatedAt LIMIT " & limit.ToString(CultureInfo.InvariantCulture), Nothing, "ListStuck")
    End Function

    ' Tentativi con lo slot occupato di un proprietario (per annullare quelli vecchi prima di aprirne uno nuovo: politica di P3).
    Public Shared Function ListLiveByOwner(ByVal aziendeId As Integer, ByVal loginId As Long) As List(Of PayPalAttemptRecord)
        If aziendeId <= 0 OrElse loginId <= 0 Then Return New List(Of PayPalAttemptRecord)()
        Return ReadMany("SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE AziendeId=@az AND LoginId=@login AND CurrentSlot=1 ORDER BY Id LIMIT 100",
                        Sub(cmd)
                            cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                            cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                        End Sub, "ListLiveByOwner")
    End Function

    Private Shared Function ReadMany(ByVal sql As String, ByVal bind As Action(Of MySqlCommand), ByVal operation As String) As List(Of PayPalAttemptRecord)
        Dim list As New List(Of PayPalAttemptRecord)()
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Using cmd As New MySqlCommand(sql, conn)
                    If bind IsNot Nothing Then bind(cmd)
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            list.Add(ReadRecord(reader))
                        End While
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogFailure(operation, ex)
        End Try
        Return list
    End Function

    Private Shared Function ReadOne(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal sql As String, ByVal bind As Action(Of MySqlCommand)) As PayPalAttemptRecord
        Using cmd As New MySqlCommand(sql, conn, tx)
            If bind IsNot Nothing Then bind(cmd)
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                If reader.Read() Then Return ReadRecord(reader)
            End Using
        End Using
        Return Nothing
    End Function

    Private Shared Function ReadRecord(ByVal reader As MySqlDataReader) As PayPalAttemptRecord
        Return New PayPalAttemptRecord With {
            .Id = Convert.ToInt64(reader("Id"), CultureInfo.InvariantCulture),
            .AttemptKey = Text(reader("AttemptKey")),
            .AziendeId = Convert.ToInt32(reader("AziendeId"), CultureInfo.InvariantCulture),
            .LoginId = Convert.ToInt64(reader("LoginId"), CultureInfo.InvariantCulture),
            .UtentiId = Convert.ToInt64(reader("UtentiId"), CultureInfo.InvariantCulture),
            .PagamentiTipoId = Convert.ToInt32(reader("PagamentiTipoId"), CultureInfo.InvariantCulture),
            .PayPalAccountId = Convert.ToInt32(reader("PayPalAccountId"), CultureInfo.InvariantCulture),
            .DatabaseScopeKey = Text(reader("DatabaseScopeKey")),
            .DraftRequestId = Text(reader("DraftRequestId")),
            .PayloadFingerprint = Text(reader("PayloadFingerprint")),
            .DraftExpiresUtc = AsUtc(reader("DraftExpiresAt")),
            .TentativoNo = Convert.ToInt32(reader("TentativoNo"), CultureInfo.InvariantCulture),
            .IsCurrent = SafeInt(reader("CurrentSlot")) = 1,
            .Stato = Text(reader("Stato")),
            .StatoPrecedente = Text(reader("StatoPrecedente")),
            .Importo = Convert.ToDecimal(reader("Importo"), CultureInfo.InvariantCulture),
            .Valuta = Text(reader("Valuta")),
            .PayeeEmail = Text(reader("PayeeEmail")),
            .MerchantId = Text(reader("MerchantId")),
            .CreateRequestId = Text(reader("CreateRequestId")),
            .AuthorizeRequestId = Text(reader("AuthorizeRequestId")),
            .CaptureRequestId = Text(reader("CaptureRequestId")),
            .VoidRequestId = Text(reader("VoidRequestId")),
            .PayPalOrderId = Text(reader("PayPalOrderId")),
            .PayPalAuthorizationId = Text(reader("PayPalAuthorizationId")),
            .PayPalCaptureId = Text(reader("PayPalCaptureId")),
            .AuthorizationExpiresUtc = If(reader("AuthorizationExpiresAt") Is DBNull.Value, CType(Nothing, DateTime?), CType(AsUtc(reader("AuthorizationExpiresAt")), DateTime?)),
            .DocumentiId = SafeInt(reader("DocumentiId")),
            .UltimoEsito = Text(reader("UltimoEsito")),
            .AgeMinutes = SafeInt(reader("AgeMinutes"))}
    End Function

    ' ----- transizioni del cliente (azienda e login) -----

    Public Shared Function RecordOrderCreated(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal loginId As Long, ByVal orderId As String) As Boolean
        If String.IsNullOrWhiteSpace(orderId) OrElse orderId.Length > 100 OrElse loginId <= 0 Then Return False
        Return Transition(attemptId, aziendeId, loginId, PayPalPaymentAttemptStates.Created, New String() {PayPalPaymentAttemptStates.Creating}, String.Empty,
                          "PayPalOrderId=@order", Sub(cmd) cmd.Parameters.Add("@order", MySqlDbType.String).Value = orderId, "RecordOrderCreated")
    End Function

    Public Shared Function RecordAuthorized(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal loginId As Long, ByVal orderId As String,
                                            ByVal authorizationId As String, ByVal authorizationExpiresUtc As DateTime) As Boolean
        If String.IsNullOrWhiteSpace(orderId) OrElse orderId.Length > 100 OrElse String.IsNullOrWhiteSpace(authorizationId) OrElse authorizationId.Length > 100 OrElse loginId <= 0 Then Return False
        Return Transition(attemptId, aziendeId, loginId, PayPalPaymentAttemptStates.Authorized, New String() {PayPalPaymentAttemptStates.Created}, String.Empty,
                          "PayPalAuthorizationId=@auth,AuthorizationExpiresAt=@expires",
                          Sub(cmd)
                              cmd.Parameters.Add("@auth", MySqlDbType.String).Value = authorizationId
                              cmd.Parameters.Add("@expires", MySqlDbType.DateTime).Value = authorizationExpiresUtc.ToUniversalTime()
                              cmd.Parameters.Add("@order", MySqlDbType.String).Value = orderId
                          End Sub, "RecordAuthorized", "PayPalOrderId=@order")
    End Function

    Public Shared Function RecordCanceled(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal loginId As Long) As Boolean
        If loginId <= 0 Then Return False
        Return Transition(attemptId, aziendeId, loginId, PayPalPaymentAttemptStates.Canceled, New String() {PayPalPaymentAttemptStates.Created}, "CUSTOMER_CANCELED", String.Empty, Nothing, "RecordCanceled")
    End Function

    ' ----- legame con il documento, nella transazione del chiamante (P3: la stessa dei documenti, ordine di blocco tentativo -> documenti) -----

    Public Shared Function LockForDocument(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal loginId As Long) As PayPalAttemptRecord
        If conn Is Nothing OrElse tx Is Nothing OrElse attemptId <= 0 OrElse aziendeId <= 0 OrElse loginId <= 0 Then Return Nothing
        Return ReadOne(conn, tx, "SELECT " & SelectColumns & " FROM paypal_checkout_tentativi WHERE Id=@id AND AziendeId=@az AND LoginId=@login FOR UPDATE",
                       Sub(cmd)
                           cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                           cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                           cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                       End Sub)
    End Function

    ' AUTHORIZED -> DOC_COMMITTED nella transazione del chiamante. Legge il documento da se (azienda, cliente, tipo di pagamento, totale al centesimo half-up) e
    ' lo confronta con il tentativo: nessun valore del chiamante e creduto. Se qualcosa non torna restituisce False e il chiamante annulla la transazione.
    Public Shared Function BindDocument(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal attemptId As Long, ByVal aziendeId As Integer,
                                        ByVal loginId As Long, ByVal documentId As Integer) As Boolean
        If conn Is Nothing OrElse tx Is Nothing OrElse attemptId <= 0 OrElse aziendeId <= 0 OrElse loginId <= 0 OrElse documentId <= 0 Then Return False
        Try
            Dim importo As Decimal
            Dim utenti As Long
            Dim pagamento As Integer
            Using cmd As New MySqlCommand("SELECT Importo,UtentiId,PagamentiTipoId FROM paypal_checkout_tentativi WHERE Id=@id AND AziendeId=@az AND LoginId=@login AND Stato='AUTHORIZED'", conn, tx)
                cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                Using reader As MySqlDataReader = cmd.ExecuteReader()
                    If Not reader.Read() Then Return False
                    importo = Convert.ToDecimal(reader(0), CultureInfo.InvariantCulture)
                    utenti = Convert.ToInt64(reader(1), CultureInfo.InvariantCulture)
                    pagamento = Convert.ToInt32(reader(2), CultureInfo.InvariantCulture)
                End Using
            End Using
            Using cmd As New MySqlCommand("SELECT d.AziendeId,d.UtentiId,d.PagamentiTipoId,COALESCE(pie.TotaleDocumento,0) FROM documenti d LEFT JOIN documentipie pie ON pie.DocumentiId=d.Id WHERE d.Id=@doc", conn, tx)
                cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = documentId
                Using reader As MySqlDataReader = cmd.ExecuteReader()
                    If Not reader.Read() Then Return False
                    ' TotaleDocumento e double(15,5): il confronto e al centesimo half-up (stessa regola del PayPal e del repository esistente).
                    Dim total As Decimal = Math.Round(Convert.ToDecimal(reader(3), CultureInfo.InvariantCulture), 2, MidpointRounding.AwayFromZero)
                    If Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) <> aziendeId OrElse Convert.ToInt64(reader(1), CultureInfo.InvariantCulture) <> utenti OrElse
                       Convert.ToInt32(reader(2), CultureInfo.InvariantCulture) <> pagamento OrElse total <> importo Then Return False
                End Using
            End Using
            Using cmd As New MySqlCommand("UPDATE paypal_checkout_tentativi SET Stato='DOC_COMMITTED',DocumentiId=@doc,StatoPrecedente=NULL WHERE Id=@id AND AziendeId=@az AND LoginId=@login AND Stato='AUTHORIZED'", conn, tx)
                cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = documentId
                cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                Return cmd.ExecuteNonQuery() = 1
            End Using
        Catch ex As MySqlException When ex.Number = 1062
            Return False
        Catch ex As Exception
            LogFailure("BindDocument", ex)
            Return False
        End Try
    End Function

    ' ----- incasso -----

    ' DOC_COMMITTED -> CAPTURING in una transazione breve: prima il tentativo (FOR UPDATE), poi il documento (esiste, stessa azienda e cliente, non pagato).
    ' Parte solo da DOC_COMMITTED, mai da CAPTURING: il recupero di un incasso fermo usa TryClaimCaptureRetry (nessun cambio di stato).
    Public Shared Function BeginCapture(ByVal attemptId As Long, ByVal aziendeId As Integer) As PayPalBeginCaptureOutcome
        If attemptId <= 0 OrElse aziendeId <= 0 Then Return PayPalBeginCaptureOutcome.NotInState
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Using tx As MySqlTransaction = conn.BeginTransaction()
                    Dim documentId As Integer
                    Dim utenti As Long
                    Dim pagamento As Integer
                    Using cmd As New MySqlCommand("SELECT DocumentiId,UtentiId,PagamentiTipoId FROM paypal_checkout_tentativi WHERE Id=@id AND AziendeId=@az AND Stato='DOC_COMMITTED' FOR UPDATE", conn, tx)
                        cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                        cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                        Using reader As MySqlDataReader = cmd.ExecuteReader()
                            If Not reader.Read() OrElse reader(0) Is DBNull.Value Then
                                reader.Close()
                                tx.Rollback()
                                Return PayPalBeginCaptureOutcome.NotInState
                            End If
                            documentId = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                            utenti = Convert.ToInt64(reader(1), CultureInfo.InvariantCulture)
                            pagamento = Convert.ToInt32(reader(2), CultureInfo.InvariantCulture)
                        End Using
                    End Using
                    Dim documentOk As Boolean = False
                    Using cmd As New MySqlCommand("SELECT COALESCE(Pagato,0) FROM documenti WHERE Id=@doc AND AziendeId=@az AND UtentiId=@utenti AND PagamentiTipoId=@pagamento FOR UPDATE", conn, tx)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = documentId
                        cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                        cmd.Parameters.Add("@utenti", MySqlDbType.Int64).Value = utenti
                        cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = pagamento
                        Using reader As MySqlDataReader = cmd.ExecuteReader()
                            documentOk = reader.Read() AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 0
                        End Using
                    End Using
                    If Not documentOk Then
                        tx.Rollback()
                        Return PayPalBeginCaptureOutcome.DocumentInvalid
                    End If
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_tentativi SET Stato='CAPTURING',StatoPrecedente=NULL WHERE Id=@id AND AziendeId=@az AND Stato='DOC_COMMITTED'", conn, tx)
                        cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                        cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                        If cmd.ExecuteNonQuery() <> 1 Then
                            tx.Rollback()
                            Return PayPalBeginCaptureOutcome.NotInState
                        End If
                    End Using
                    tx.Commit()
                    Return PayPalBeginCaptureOutcome.Started
                End Using
            End Using
        Catch ex As Exception
            LogFailure("BeginCapture", ex)
            Return PayPalBeginCaptureOutcome.TechnicalError
        End Try
    End Function

    ' Un solo esecutore per volta riprova un incasso fermo (stesso request id, dopo la rilettura su PayPal): contratto di locazione su UpdatedAt.
    Public Shared Function TryClaimCaptureRetry(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal olderThanSeconds As Integer) As Boolean
        If attemptId <= 0 OrElse aziendeId <= 0 Then Return False
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Using cmd As New MySqlCommand("UPDATE paypal_checkout_tentativi SET UpdatedAt=NOW() WHERE Id=@id AND AziendeId=@az AND Stato='CAPTURING' AND UpdatedAt <= NOW() - INTERVAL @s SECOND", conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                    cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                    cmd.Parameters.Add("@s", MySqlDbType.Int32).Value = Math.Max(0, olderThanSeconds)
                    Return cmd.ExecuteNonQuery() = 1
                End Using
            End Using
        Catch ex As Exception
            LogFailure("TryClaimCaptureRetry", ex)
            Return False
        End Try
    End Function

    ' completed=True: l'incasso e COMPLETED su PayPal (da CAPTURING, da DOC_COMMITTED o da CAPTURE_REFUSED se e stato incassato a mano); completed=False: rifiutato
    ' (solo un incasso avviato puo essere rifiutato: da CAPTURING a CAPTURE_REFUSED, il tentativo resta "corrente").
    Public Shared Function RecordCaptureResult(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal captureId As String, ByVal completed As Boolean, ByVal reason As String) As Boolean
        If completed Then
            If String.IsNullOrWhiteSpace(captureId) OrElse captureId.Length > 100 Then Return False
            Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Completed,
                              New String() {PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.Capturing, PayPalPaymentAttemptStates.CaptureRefused}, reason,
                              "PayPalCaptureId=@cap", Sub(cmd) cmd.Parameters.Add("@cap", MySqlDbType.String).Value = captureId, "RecordCaptureResult")
        End If
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.CaptureRefused, New String() {PayPalPaymentAttemptStates.Capturing}, reason, String.Empty, Nothing, "RecordCaptureResult")
    End Function

    ' ----- annullo, fallimento, incasso orfano, stato incerto -----

    Public Shared Function RecordVoiding(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal reason As String) As Boolean
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Voiding,
                          New String() {PayPalPaymentAttemptStates.Authorized, PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.CaptureRefused}, reason, String.Empty, Nothing, "RecordVoiding")
    End Function

    ' Annullo di un'autorizzazione SENZA documento: parte solo da AUTHORIZED. RecordVoiding (sopra) ammette anche DOC_COMMITTED e CAPTURE_REFUSED per il
    ' rifiuto dell'incasso; il percorso di avvio/ritorno e di ordine.aspx non deve mai poter annullare l'autorizzazione di un ordine gia creato.
    Public Shared Function RecordVoidingUnbound(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal reason As String) As Boolean
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Voiding, New String() {PayPalPaymentAttemptStates.Authorized}, reason, String.Empty, Nothing, "RecordVoidingUnbound")
    End Function

    Public Shared Function RecordVoided(ByVal attemptId As Long, ByVal aziendeId As Integer) As Boolean
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Voided, New String() {PayPalPaymentAttemptStates.Voiding}, "VOIDED", String.Empty, Nothing, "RecordVoided")
    End Function

    ' Solo prima dell'autorizzazione: da AUTHORIZED non si "fallisce" (l'autorizzazione puo essere ancora valida): si annulla (VOIDING) o si prova che e persa.
    Public Shared Function RecordFailed(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal reason As String) As Boolean
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Failed,
                          New String() {PayPalPaymentAttemptStates.Creating, PayPalPaymentAttemptStates.Created}, reason, String.Empty, Nothing, "RecordFailed")
    End Function

    ' AUTHORIZED -> FAILED solo con la prova remota che nessun fondo e trattenuto (DENIED, VOIDED o EXPIRED letti su PayPal).
    Public Shared Function RecordAuthorizationLost(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal remoteStatus As String) As Boolean
        Dim status As String = If(remoteStatus, String.Empty).Trim().ToUpperInvariant()
        If status <> "DENIED" AndAlso status <> "VOIDED" AndAlso status <> "EXPIRED" Then Return False
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Failed, New String() {PayPalPaymentAttemptStates.Authorized}, "AUTHORIZATION_" & status, String.Empty, Nothing, "RecordAuthorizationLost")
    End Function

    ' Incasso (anche tardivo, dal pannello PayPal) su un tentativo senza ordine: non si perde, si registra per la riconciliazione manuale.
    Public Shared Function RecordOrphanCapture(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal captureId As String) As Boolean
        If String.IsNullOrWhiteSpace(captureId) OrElse captureId.Length > 100 Then Return False
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.CapturedOrphan,
                          New String() {PayPalPaymentAttemptStates.Authorized, PayPalPaymentAttemptStates.Voiding, PayPalPaymentAttemptStates.Voided, PayPalPaymentAttemptStates.Failed, PayPalPaymentAttemptStates.Canceled},
                          "ORPHAN_CAPTURE", "PayPalCaptureId=@cap", Sub(cmd) cmd.Parameters.Add("@cap", MySqlDbType.String).Value = captureId, "RecordOrphanCapture")
    End Function

    ' Esito incerto (risposta persa, crash dopo l'effetto): ricorda lo stato precedente; un secondo RecordUnknown non lo sovrascrive (UNKNOWN non ha uscite dirette).
    Public Shared Function RecordUnknown(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal reason As String) As Boolean
        Dim from1 As String() = New String() {PayPalPaymentAttemptStates.Creating, PayPalPaymentAttemptStates.Created, PayPalPaymentAttemptStates.Authorized,
                                              PayPalPaymentAttemptStates.Voiding, PayPalPaymentAttemptStates.DocCommitted, PayPalPaymentAttemptStates.Capturing}
        Return Transition(attemptId, aziendeId, 0, PayPalPaymentAttemptStates.Unknown, from1, reason, "StatoPrecedente=Stato", Nothing, "RecordUnknown", String.Empty, True)
    End Function

    ' Risolve UNKNOWN solo verso lo stato precedente o un suo successore diretto (mai DOC_COMMITTED, mai FAILED da AUTHORIZED): la rilettura su PayPal decide.
    Public Shared Function ResolveUnknown(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal targetState As String, ByVal reason As String) As Boolean
        If attemptId <= 0 OrElse aziendeId <= 0 OrElse Not PayPalPaymentAttemptStates.IsKnown(targetState) Then Return False
        Try
            Dim previous As String = String.Empty
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Using cmd As New MySqlCommand("SELECT StatoPrecedente FROM paypal_checkout_tentativi WHERE Id=@id AND AziendeId=@az AND Stato='UNKNOWN'", conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                    cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                    Dim value As Object = cmd.ExecuteScalar()
                    If value Is Nothing OrElse value Is DBNull.Value Then Return False
                    previous = Convert.ToString(value, CultureInfo.InvariantCulture)
                End Using
                If Not PayPalPaymentAttemptStates.CanResolveUnknown(previous, targetState) Then Return False
                Dim slot As Object = If(PayPalPaymentAttemptStates.ReleasesSlot(targetState), CType(DBNull.Value, Object), CType(1, Object))
                Using cmd As New MySqlCommand("UPDATE paypal_checkout_tentativi SET Stato=@to,StatoPrecedente=NULL,CurrentSlot=@slot,UltimoEsito=@esito WHERE Id=@id AND AziendeId=@az AND Stato='UNKNOWN' AND StatoPrecedente=@prev", conn)
                    cmd.Parameters.Add("@to", MySqlDbType.String).Value = targetState
                    cmd.Parameters.Add("@slot", MySqlDbType.Int32).Value = slot
                    cmd.Parameters.Add("@esito", MySqlDbType.String).Value = OutcomeOrNull(reason)
                    cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                    cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                    cmd.Parameters.Add("@prev", MySqlDbType.String).Value = previous
                    Return cmd.ExecuteNonQuery() = 1
                End Using
            End Using
        Catch ex As Exception
            LogFailure("ResolveUnknown", ex)
            Return False
        End Try
    End Function

    ' ----- trasporto comune delle transizioni -----

    ' UPDATE guardato dallo stato (solo gli stati di partenza che la macchina a stati ammette verso `toState`), dall'azienda e, se loginId > 0, dal login.
    ' extraSet/extraWhere sono frammenti fissi del codice (mai valori del chiamante nel testo SQL: solo parametri).
    Private Shared Function Transition(ByVal attemptId As Long, ByVal aziendeId As Integer, ByVal loginId As Long, ByVal toState As String, ByVal fromStates As String(),
                                       ByVal reason As String, ByVal extraSet As String, ByVal bindExtra As Action(Of MySqlCommand), ByVal operation As String,
                                       Optional ByVal extraWhere As String = "", Optional ByVal keepSlot As Boolean = False) As Boolean
        If attemptId <= 0 OrElse aziendeId <= 0 Then Return False
        Dim allowed As New List(Of String)()
        For Each f As String In fromStates
            If PayPalPaymentAttemptStates.CanTransition(f, toState) Then allowed.Add(f)
        Next
        If allowed.Count = 0 Then Return False
        Dim stateList As New StringBuilder()
        For Each f As String In allowed
            If stateList.Length > 0 Then stateList.Append(","c)
            stateList.Append("'"c).Append(f).Append("'"c)
        Next
        Dim sql As New StringBuilder("UPDATE paypal_checkout_tentativi SET ")
        If extraSet.Length > 0 Then sql.Append(extraSet).Append(","c)
        If toState <> PayPalPaymentAttemptStates.Unknown Then sql.Append("StatoPrecedente=NULL,")
        sql.Append("Stato=@to,CurrentSlot=@slot,UltimoEsito=@esito WHERE Id=@id AND AziendeId=@az")
        If loginId > 0 Then sql.Append(" AND LoginId=@login")
        If extraWhere.Length > 0 Then sql.Append(" AND ").Append(extraWhere)
        sql.Append(" AND Stato IN (").Append(stateList.ToString()).Append(")")
        Try
            Using conn As New MySqlConnection(ConnectionString())
                conn.Open()
                Using cmd As New MySqlCommand(sql.ToString(), conn)
                    cmd.Parameters.Add("@to", MySqlDbType.String).Value = toState
                    cmd.Parameters.Add("@slot", MySqlDbType.Int32).Value = If(PayPalPaymentAttemptStates.ReleasesSlot(toState), CType(DBNull.Value, Object), CType(1, Object))
                    cmd.Parameters.Add("@esito", MySqlDbType.String).Value = OutcomeOrNull(reason)
                    cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = attemptId
                    cmd.Parameters.Add("@az", MySqlDbType.Int32).Value = aziendeId
                    If loginId > 0 Then cmd.Parameters.Add("@login", MySqlDbType.Int64).Value = loginId
                    If bindExtra IsNot Nothing Then bindExtra(cmd)
                    Return cmd.ExecuteNonQuery() = 1
                End Using
            End Using
        Catch ex As MySqlException When ex.Number = 1062
            Return False
        Catch ex As Exception
            LogFailure(operation, ex)
            Return False
        End Try
    End Function

    ' Solo codici: maiuscole, cifre, _ : . spazio e trattino; tutto il resto (markup, a capo, '=') e scartato; al massimo 255 caratteri. Mai corpi di risposta.
    Public Shared Function SanitizeOutcome(ByVal value As String) As String
        If String.IsNullOrEmpty(value) Then Return String.Empty
        Dim sb As New StringBuilder()
        For Each ch As Char In value.ToUpperInvariant()
            If (ch >= "A"c AndAlso ch <= "Z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "_"c OrElse ch = ":"c OrElse ch = "."c OrElse ch = " "c OrElse ch = "-"c Then
                sb.Append(ch)
                If sb.Length >= 255 Then Exit For
            End If
        Next
        Return sb.ToString()
    End Function

    Private Shared Function OutcomeOrNull(ByVal reason As String) As Object
        Dim clean As String = SanitizeOutcome(reason)
        If clean.Length = 0 Then Return DBNull.Value
        Return clean
    End Function

    Private Shared Function Text(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return String.Empty
        Return Convert.ToString(value, CultureInfo.InvariantCulture)
    End Function

    Private Shared Function AsUtc(ByVal value As Object) As DateTime
        Return DateTime.SpecifyKind(Convert.ToDateTime(value, CultureInfo.InvariantCulture), DateTimeKind.Utc)
    End Function

    ' Una colonna tinyint(1) arriva dal connettore come System.Boolean (opzione predefinita): "True" non e un intero e diventerebbe 0 in silenzio.
    Private Shared Function SafeInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return 0
        If TypeOf value Is Boolean Then Return If(CBool(value), 1, 0)
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed)
        Return parsed
    End Function

    Private Shared Sub LogFailure(ByVal operation As String, ByVal ex As Exception)
        Try
            KeepStoreLog.Error("paypal-attempts", operation, ex, HttpContext.Current)
        Catch
        End Try
    End Sub
End Class

Public Class PayPalAttemptCreateResult
    Public Property Outcome As PayPalAttemptCreateOutcome
    Public Property Attempt As PayPalAttemptRecord
End Class
