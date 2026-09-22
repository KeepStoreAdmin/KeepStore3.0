Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class PayPalCheckoutTransactionInfo
    Public Property Exists As Boolean
    Public Property Id As Long
    Public Property DocumentiId As Integer
    Public Property TentativoNo As Integer
    Public Property IsCurrent As Boolean
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property PayPalAccountId As Integer
    Public Property PayPalOrderId As String
    Public Property PayPalCaptureId As String
    Public Property Stato As String
    Public Property Importo As Decimal
    Public Property Valuta As String
    Public Property PayeeEmail As String
    Public Property MerchantId As String
    Public Property CreateRequestId As String
    Public Property CaptureRequestId As String
End Class

Public Module PayPalCheckoutRepository
    Private ReadOnly ConnectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

    Public Function LoadConfigForDocument(ByVal documentId As Integer) As PayPalCheckoutConfig
        If documentId <= 0 Then Return Nothing
        Const sql As String =
            "SELECT a.Id AccountId,c.Id CompanyConfigId,c.AziendeId,c.PagamentiTipoId,a.CredentialKey,a.MerchantId," &
            "c.PayeeEmail,c.BrandName,c.CurrencyCode,a.Attivo AccountActive,c.Attivo CompanyActive " &
            "FROM documenti d INNER JOIN paypal_checkout_azienda c ON c.AziendeId=d.AziendeId AND c.PagamentiTipoId=d.PagamentiTipoId " &
            "INNER JOIN paypal_checkout_account a ON a.Id=c.PayPalAccountId " &
            "INNER JOIN pagamentitipo p ON p.Id=d.PagamentiTipoId AND p.OnLine=@online " &
            "WHERE d.Id=@id LIMIT 1"
        Return LoadConfig(sql, Sub(cmd)
                                   cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                               End Sub)
    End Function

    Public Function LoadConfigForCompanyPayment(ByVal companyId As Integer,
                                                ByVal paymentMethodId As Integer) As PayPalCheckoutConfig
        If companyId <= 0 OrElse paymentMethodId <= 0 Then Return Nothing
        Const sql As String =
            "SELECT a.Id AccountId,c.Id CompanyConfigId,c.AziendeId,c.PagamentiTipoId,a.CredentialKey,a.MerchantId," &
            "c.PayeeEmail,c.BrandName,c.CurrencyCode,a.Attivo AccountActive,c.Attivo CompanyActive " &
            "FROM paypal_checkout_azienda c INNER JOIN paypal_checkout_account a ON a.Id=c.PayPalAccountId " &
            "INNER JOIN pagamentitipo p ON p.Id=c.PagamentiTipoId AND p.OnLine=@online " &
            "WHERE c.AziendeId=@azienda AND c.PagamentiTipoId=@pagamento LIMIT 1"
        Return LoadConfig(sql, Sub(cmd)
                                   cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = companyId
                                   cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = paymentMethodId
                               End Sub)
    End Function

    Public Function EnsureTransaction(ByVal doc As PayPalPaymentDocumentInfo,
                                      ByVal cfg As PayPalCheckoutConfig) As PayPalCheckoutTransactionInfo
        If doc Is Nothing OrElse cfg Is Nothing Then Return New PayPalCheckoutTransactionInfo()
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    If Not LockUnpaidDocument(conn, trns, doc) Then trns.Rollback() : Return New PayPalCheckoutTransactionInfo()
                    Dim currentId As Object
                    Using current As New MySqlCommand("SELECT Id FROM paypal_checkout_transazioni WHERE DocumentiId=@doc AND CurrentSlot=1 FOR UPDATE", conn, trns)
                        current.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                        currentId = current.ExecuteScalar()
                    End Using
                    If currentId IsNot Nothing Then
                        trns.Commit()
                        Return LoadTransactionForDocument(doc.DocumentId)
                    End If
                    ' Solo il primo tentativo nasce senza riconciliazione volontaria.
                    Dim historyCount As Long
                    Using history As New MySqlCommand("SELECT COUNT(*) FROM paypal_checkout_transazioni WHERE DocumentiId=@doc", conn, trns)
                        history.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                        historyCount = Convert.ToInt64(history.ExecuteScalar(), CultureInfo.InvariantCulture)
                    End Using
                    If historyCount <> 0 Then trns.Rollback() : Return New PayPalCheckoutTransactionInfo()
                    Using cmd As New MySqlCommand("INSERT INTO paypal_checkout_transazioni (DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId,UltimoEsito) VALUES (@doc,1,1,@azienda,@pagamento,@account,'CREATING',@importo,@valuta,@payee,@merchant,@createId,@captureId,'Create inizializzata')", conn, trns)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = doc.AziendeId
                        cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = doc.PagamentiTipoId
                        cmd.Parameters.Add("@account", MySqlDbType.Int32).Value = cfg.AccountId
                        cmd.Parameters.Add("@importo", MySqlDbType.Decimal).Value = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero)
                        cmd.Parameters.Add("@valuta", MySqlDbType.VarChar, 3).Value = cfg.CurrencyCode
                        cmd.Parameters.Add("@payee", MySqlDbType.VarChar, 254).Value = cfg.PayeeEmail
                        cmd.Parameters.Add("@merchant", MySqlDbType.VarChar, 128).Value = cfg.MerchantId
                        cmd.Parameters.Add("@createId", MySqlDbType.VarChar, 80).Value = BuildRequestId("CREATE", doc.AziendeId, doc.DocumentId, 1)
                        cmd.Parameters.Add("@captureId", MySqlDbType.VarChar, 80).Value = BuildRequestId("CAPTURE", doc.AziendeId, doc.DocumentId, 1)
                        cmd.ExecuteNonQuery()
                    End Using
                    trns.Commit()
                End Using
            End Using
        Catch ex As Exception
            LogFailure("EnsureTransaction", doc.DocumentId, ex)
        End Try
        Return LoadTransactionForDocument(doc.DocumentId)
    End Function

    Public Function LoadTransactionForDocument(ByVal documentId As Integer) As PayPalCheckoutTransactionInfo
        If documentId <= 0 Then Return New PayPalCheckoutTransactionInfo()
        Return LoadTransaction("SELECT * FROM paypal_checkout_transazioni WHERE DocumentiId=@value AND CurrentSlot=1 LIMIT 1", documentId.ToString(CultureInfo.InvariantCulture), MySqlDbType.Int32)
    End Function

    Public Function LoadTransactionForExternalReference(ByVal value As String) As PayPalCheckoutTransactionInfo
        Dim clean As String = PayPalPaymentState.SanitizeExternalId(value)
        If clean = String.Empty Then Return New PayPalCheckoutTransactionInfo()
        Return LoadTransaction("SELECT * FROM paypal_checkout_transazioni WHERE PayPalOrderId=@value OR PayPalCaptureId=@value LIMIT 1", clean, MySqlDbType.VarChar)
    End Function

    Public Function LoadTransactionForOrder(ByVal orderId As String) As PayPalCheckoutTransactionInfo
        Dim clean As String = PayPalPaymentState.SanitizeExternalId(orderId)
        If clean = String.Empty Then Return New PayPalCheckoutTransactionInfo()
        Return LoadTransaction("SELECT * FROM paypal_checkout_transazioni WHERE PayPalOrderId=@value LIMIT 1", clean, MySqlDbType.VarChar)
    End Function

    Public Function StartNextAttempt(ByVal doc As PayPalPaymentDocumentInfo,
                                     ByVal cfg As PayPalCheckoutConfig,
                                     ByVal previous As PayPalCheckoutTransactionInfo,
                                     ByVal reconciled As PayPalOrderSnapshot) As PayPalCheckoutTransactionInfo
        If doc Is Nothing OrElse cfg Is Nothing OrElse previous Is Nothing OrElse Not previous.IsCurrent OrElse
           reconciled Is Nothing OrElse Not String.Equals(doc.OrigineOrdine, "INTERNO", StringComparison.OrdinalIgnoreCase) OrElse
           String.IsNullOrEmpty(previous.PayPalOrderId) OrElse
           Not String.Equals(previous.PayPalOrderId, reconciled.OrderId, StringComparison.Ordinal) OrElse
           Not PayPalAttemptPolicy.MaySupersede(doc.OrigineOrdine, previous.Stato, reconciled.Status, reconciled.CaptureStatus) Then Return New PayPalCheckoutTransactionInfo()
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    If Not LockUnpaidDocument(conn, trns, doc) Then trns.Rollback() : Return New PayPalCheckoutTransactionInfo()
                    Dim currentId As Long = 0
                    Dim currentState As String = String.Empty
                    Dim currentOrder As String = String.Empty
                    Using cmd As New MySqlCommand("SELECT Id,Stato,PayPalOrderId FROM paypal_checkout_transazioni WHERE DocumentiId=@doc AND CurrentSlot=1 FOR UPDATE", conn, trns)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                        Using reader As MySqlDataReader = cmd.ExecuteReader()
                            If reader.Read() Then
                                currentId = Convert.ToInt64(reader("Id"), CultureInfo.InvariantCulture)
                                currentState = Convert.ToString(reader("Stato"))
                                currentOrder = Convert.ToString(reader("PayPalOrderId"))
                            End If
                        End Using
                    End Using
                    If currentId <> previous.Id OrElse Not String.Equals(currentState, previous.Stato, StringComparison.OrdinalIgnoreCase) OrElse
                       Not String.Equals(currentOrder, previous.PayPalOrderId, StringComparison.Ordinal) Then
                        trns.Commit()
                        Return LoadTransactionForDocument(doc.DocumentId)
                    End If
                    Dim attemptNo As Integer = previous.TentativoNo + 1
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_transazioni SET CurrentSlot=NULL,Stato='SUPERSEDED',UpdatedAt=CURRENT_TIMESTAMP WHERE Id=@id AND CurrentSlot=1 AND Stato=@stato", conn, trns)
                        cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = previous.Id
                        cmd.Parameters.Add("@stato", MySqlDbType.VarChar, 40).Value = previous.Stato
                        If cmd.ExecuteNonQuery() <> 1 Then trns.Rollback() : Return New PayPalCheckoutTransactionInfo()
                    End Using
                    Using cmd As New MySqlCommand("INSERT INTO paypal_checkout_transazioni (DocumentiId,TentativoNo,CurrentSlot,AziendeId,PagamentiTipoId,PayPalAccountId,Stato,Importo,Valuta,PayeeEmail,MerchantId,CreateRequestId,CaptureRequestId,UltimoEsito) VALUES (@doc,@attempt,1,@azienda,@pagamento,@account,'CREATING',@importo,@valuta,@payee,@merchant,@createId,@captureId,'Nuovo tentativo interno')", conn, trns)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                        cmd.Parameters.Add("@attempt", MySqlDbType.Int32).Value = attemptNo
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = doc.AziendeId
                        cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = doc.PagamentiTipoId
                        cmd.Parameters.Add("@account", MySqlDbType.Int32).Value = cfg.AccountId
                        cmd.Parameters.Add("@importo", MySqlDbType.Decimal).Value = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero)
                        cmd.Parameters.Add("@valuta", MySqlDbType.VarChar, 3).Value = cfg.CurrencyCode
                        cmd.Parameters.Add("@payee", MySqlDbType.VarChar, 254).Value = cfg.PayeeEmail
                        cmd.Parameters.Add("@merchant", MySqlDbType.VarChar, 128).Value = cfg.MerchantId
                        cmd.Parameters.Add("@createId", MySqlDbType.VarChar, 80).Value = BuildRequestId("CREATE", doc.AziendeId, doc.DocumentId, attemptNo)
                        cmd.Parameters.Add("@captureId", MySqlDbType.VarChar, 80).Value = BuildRequestId("CAPTURE", doc.AziendeId, doc.DocumentId, attemptNo)
                        cmd.ExecuteNonQuery()
                    End Using
                    trns.Commit()
                End Using
            End Using
        Catch ex As Exception
            LogFailure("StartNextAttempt", doc.DocumentId, ex)
            Return New PayPalCheckoutTransactionInfo()
        End Try
        Return LoadTransactionForDocument(doc.DocumentId)
    End Function

    Private Function BuildRequestId(ByVal operation As String, ByVal companyId As Integer,
                                    ByVal documentId As Integer, ByVal attemptNo As Integer) As String
        Return "PP-" & operation & "-" & companyId.ToString(CultureInfo.InvariantCulture) & "-" &
            documentId.ToString(CultureInfo.InvariantCulture) & "-" & attemptNo.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function LockUnpaidDocument(ByVal conn As MySqlConnection, ByVal trns As MySqlTransaction,
                                        ByVal doc As PayPalPaymentDocumentInfo) As Boolean
        Using cmd As New MySqlCommand("SELECT COALESCE(Pagato,0),COALESCE(OrigineOrdine,'') FROM documenti WHERE id=@doc AND AziendeId=@azienda AND UtentiId=@utente AND PagamentiTipoId=@pagamento FOR UPDATE", conn, trns)
            cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
            cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = doc.AziendeId
            cmd.Parameters.Add("@utente", MySqlDbType.Int32).Value = doc.UtentiId
            cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = doc.PagamentiTipoId
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                Return reader.Read() AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 0 AndAlso
                    String.Equals(Convert.ToString(reader(1)), doc.OrigineOrdine, StringComparison.OrdinalIgnoreCase)
            End Using
        End Using
    End Function

    Public Function RecordOrderCreated(ByVal tx As PayPalCheckoutTransactionInfo,
                                       ByVal snapshot As PayPalOrderSnapshot) As Boolean
        If tx Is Nothing OrElse Not tx.Exists OrElse snapshot Is Nothing OrElse String.IsNullOrWhiteSpace(snapshot.OrderId) Then Return False
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    Using docLock As New MySqlCommand("SELECT Id FROM documenti WHERE Id=@doc AND AziendeId=@azienda AND COALESCE(Pagato,0)=0 FOR UPDATE", conn, trns)
                        docLock.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        docLock.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        If docLock.ExecuteScalar() Is Nothing Then trns.Rollback() : Return False
                    End Using
                    Dim affected As Integer
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_transazioni SET PayPalOrderId=@orderId,Stato='CREATED',UltimoEsito='Order creato',UpdatedAt=CURRENT_TIMESTAMP WHERE Id=@id AND DocumentiId=@doc AND AziendeId=@azienda AND CurrentSlot=1 AND Stato IN ('CREATING','CREATED') AND (PayPalOrderId IS NULL OR PayPalOrderId=@orderId)", conn, trns)
                        AddIdentity(cmd, tx)
                        cmd.Parameters.Add("@orderId", MySqlDbType.VarChar, 100).Value = snapshot.OrderId
                        affected = cmd.ExecuteNonQuery()
                    End Using
                    If affected <> 1 Then trns.Rollback() : Return False
                    Using cmd As New MySqlCommand("UPDATE documenti SET Pagato=0,StatoPagamentoWeb=1,IdTransazione=@marker,DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb='PayPal Checkout: order creato' WHERE Id=@doc AND AziendeId=@azienda AND COALESCE(Pagato,0)=0", conn, trns)
                        cmd.Parameters.Add("@marker", MySqlDbType.VarChar, 150).Value = PayPalPaymentState.BuildOrderMarker(snapshot.OrderId)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        If cmd.ExecuteNonQuery() <> 1 Then trns.Rollback() : Return False
                    End Using
                    trns.Commit()
                    Return True
                End Using
            End Using
        Catch ex As Exception
            LogFailure("RecordOrderCreated", tx.DocumentiId, ex)
            Return False
        End Try
    End Function

    Public Function TryBeginCapture(ByVal tx As PayPalCheckoutTransactionInfo) As Boolean
        If tx Is Nothing OrElse Not tx.Exists OrElse Not tx.IsCurrent Then Return False
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    Dim paid As Integer = -1
                    Using cmd As New MySqlCommand("SELECT COALESCE(Pagato,0) FROM documenti WHERE id=@doc AND AziendeId=@azienda FOR UPDATE", conn, trns)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        Dim result As Object = cmd.ExecuteScalar()
                        If result IsNot Nothing Then paid = Convert.ToInt32(result, CultureInfo.InvariantCulture)
                    End Using
                    If paid <> 0 Then trns.Rollback() : Return False
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_transazioni SET Stato='CAPTURING',UpdatedAt=CURRENT_TIMESTAMP WHERE Id=@id AND DocumentiId=@doc AND AziendeId=@azienda AND CurrentSlot=1 AND Stato IN ('CREATED','APPROVED','CAPTURING','CANCELED','FAILED')", conn, trns)
                        AddIdentity(cmd, tx)
                        If cmd.ExecuteNonQuery() <> 1 Then trns.Rollback() : Return False
                    End Using
                    trns.Commit()
                    Return True
                End Using
            End Using
        Catch ex As Exception
            LogFailure("TryBeginCapture", tx.DocumentiId, ex)
            Return False
        End Try
    End Function

    Public Function ApplyAuthoritativeState(ByVal tx As PayPalCheckoutTransactionInfo,
                                            ByVal snapshot As PayPalOrderSnapshot,
                                            ByVal eventId As String) As Boolean
        If tx Is Nothing OrElse Not tx.Exists OrElse snapshot Is Nothing Then Return False
        Dim normalized As String = If(snapshot.CaptureStatus, String.Empty).Trim().ToUpperInvariant()
        If normalized = String.Empty Then normalized = If(snapshot.Status, String.Empty).Trim().ToUpperInvariant()
        If normalized <> "COMPLETED" AndAlso normalized <> "PENDING" AndAlso normalized <> "DENIED" AndAlso normalized <> "DECLINED" AndAlso normalized <> "FAILED" Then Return False
        If normalized = "COMPLETED" AndAlso Not String.Equals(snapshot.CaptureStatus, "COMPLETED", StringComparison.OrdinalIgnoreCase) Then Return False
        If Not String.IsNullOrWhiteSpace(snapshot.CaptureStatus) AndAlso
           Not PayPalOrdersV2Client.HasMatchingCapture(snapshot, tx.Importo, tx.Valuta) Then Return False
        If normalized = "COMPLETED" AndAlso Not PayPalOrdersV2Client.HasMatchingCapture(snapshot, tx.Importo, tx.Valuta) Then Return False
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    Using docLock As New MySqlCommand("SELECT d.PagamentiTipoId,COALESCE(pie.TotaleDocumento,0) FROM documenti d LEFT JOIN documentipie pie ON pie.DocumentiId=d.Id WHERE d.Id=@doc AND d.AziendeId=@azienda FOR UPDATE", conn, trns)
                        docLock.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        docLock.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        Dim documentMatches As Boolean = False
                        Using reader As MySqlDataReader = docLock.ExecuteReader()
                            documentMatches = reader.Read() AndAlso
                                Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = tx.PagamentiTipoId AndAlso
                                Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture) = tx.Importo
                        End Using
                        If Not documentMatches Then trns.Rollback() : Return False
                    End Using
                    If Not String.IsNullOrWhiteSpace(eventId) Then
                        Using eventCmd As New MySqlCommand("INSERT IGNORE INTO paypal_checkout_eventi (EventId,TransazioniId,EventType,CaptureId,Stato) VALUES (@eventId,@txId,'WEBHOOK',@capture,@stato)", conn, trns)
                            eventCmd.Parameters.Add("@eventId", MySqlDbType.VarChar, 100).Value = PayPalPaymentState.SanitizeExternalId(eventId)
                            eventCmd.Parameters.Add("@txId", MySqlDbType.Int64).Value = tx.Id
                            eventCmd.Parameters.Add("@capture", MySqlDbType.VarChar, 100).Value = PayPalPaymentState.SanitizeExternalId(snapshot.CaptureId)
                            eventCmd.Parameters.Add("@stato", MySqlDbType.VarChar, 40).Value = normalized
                            If eventCmd.ExecuteNonQuery() = 0 Then trns.Rollback() : Return True
                        End Using
                    End If
                    Dim currentSlot As Boolean = False
                    Dim storedState As String = String.Empty
                    Using cmd As New MySqlCommand("SELECT CurrentSlot,Stato,Importo,Valuta,PayPalOrderId FROM paypal_checkout_transazioni WHERE Id=@id AND DocumentiId=@doc AND AziendeId=@azienda FOR UPDATE", conn, trns)
                        AddIdentity(cmd, tx)
                        Dim storedAttemptMatches As Boolean = False
                        Using reader As MySqlDataReader = cmd.ExecuteReader()
                            If reader.Read() Then
                                currentSlot = Not reader.IsDBNull(0) AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 1
                                storedState = Convert.ToString(reader(1))
                                storedAttemptMatches = Convert.ToDecimal(reader(2), CultureInfo.InvariantCulture) = tx.Importo AndAlso
                                    String.Equals(Convert.ToString(reader(3)), tx.Valuta, StringComparison.OrdinalIgnoreCase) AndAlso
                                    String.Equals(Convert.ToString(reader(4)), snapshot.OrderId, StringComparison.Ordinal)
                            End If
                        End Using
                        If Not storedAttemptMatches Then trns.Rollback() : Return False
                    End Using
                    If String.Equals(storedState, "COMPLETED", StringComparison.OrdinalIgnoreCase) AndAlso normalized <> "COMPLETED" Then trns.Rollback() : Return True
                    If Not currentSlot AndAlso normalized <> "COMPLETED" Then trns.Commit() : Return True
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_transazioni SET PayPalCaptureId=COALESCE(NULLIF(@capture,''),PayPalCaptureId),Stato=@stato,UltimoEsito=@esito,UpdatedAt=CURRENT_TIMESTAMP WHERE Id=@id AND DocumentiId=@doc AND AziendeId=@azienda", conn, trns)
                        AddIdentity(cmd, tx)
                        cmd.Parameters.Add("@capture", MySqlDbType.VarChar, 100).Value = PayPalPaymentState.SanitizeExternalId(snapshot.CaptureId)
                        cmd.Parameters.Add("@stato", MySqlDbType.VarChar, 40).Value = normalized
                        cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = "PayPal Checkout: " & normalized
                        ' La riga e gia stata bloccata e verificata: un replay identico
                        ' puo risultare in zero righe cambiate su alcune configurazioni MySQL.
                        cmd.ExecuteNonQuery()
                    End Using
                    Dim paid As Boolean = normalized = "COMPLETED" AndAlso Not String.IsNullOrWhiteSpace(snapshot.CaptureId)
                    If Not currentSlot AndAlso Not paid Then trns.Commit() : Return True
                    Using cmd As New MySqlCommand("UPDATE documenti SET Pagato=@pagato,StatoPagamentoWeb=@stato,IdTransazione=@marker,DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@esito WHERE Id=@doc AND AziendeId=@azienda AND COALESCE(Pagato,0)=0", conn, trns)
                        cmd.Parameters.Add("@pagato", MySqlDbType.Int16).Value = If(paid, 1, 0)
                        cmd.Parameters.Add("@stato", MySqlDbType.Int16).Value = If(paid, 2, If(normalized = "PENDING", 1, 3))
                        cmd.Parameters.Add("@marker", MySqlDbType.VarChar, 150).Value = If(paid, PayPalPaymentState.BuildCaptureMarker(snapshot.CaptureId), PayPalPaymentState.BuildOrderMarker(tx.PayPalOrderId))
                        cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = "PayPal Checkout: " & normalized
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        If cmd.ExecuteNonQuery() <> 1 Then
                            Dim priorMarker As String = String.Empty
                            Using prior As New MySqlCommand("SELECT COALESCE(IdTransazione,'') FROM documenti WHERE Id=@doc AND AziendeId=@azienda AND Pagato=1", conn, trns)
                                prior.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                                prior.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                                priorMarker = Convert.ToString(prior.ExecuteScalar())
                            End Using
                            If Not paid OrElse Not String.Equals(priorMarker, PayPalPaymentState.BuildCaptureMarker(snapshot.CaptureId), StringComparison.Ordinal) Then
                                trns.Rollback() : Return False
                            End If
                        End If
                    End Using
                    trns.Commit()
                    Return True
                End Using
            End Using
        Catch ex As Exception
            LogFailure("ApplyAuthoritativeState", tx.DocumentiId, ex)
            Return False
        End Try
    End Function

    Public Function MarkCanceled(ByVal tx As PayPalCheckoutTransactionInfo) As Boolean
        If tx Is Nothing OrElse Not tx.Exists Then Return False
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using trns As MySqlTransaction = conn.BeginTransaction()
                    Using docLock As New MySqlCommand("SELECT Id FROM documenti WHERE Id=@doc AND AziendeId=@azienda AND COALESCE(Pagato,0)=0 FOR UPDATE", conn, trns)
                        docLock.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        docLock.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        If docLock.ExecuteScalar() Is Nothing Then trns.Rollback() : Return False
                    End Using
                    Using cmd As New MySqlCommand("UPDATE paypal_checkout_transazioni SET Stato='CANCELED',UltimoEsito='Annullato dall''utente',UpdatedAt=CURRENT_TIMESTAMP WHERE Id=@id AND DocumentiId=@doc AND AziendeId=@azienda AND CurrentSlot=1 AND Stato IN ('CREATING','CREATED')", conn, trns)
                        AddIdentity(cmd, tx)
                        If cmd.ExecuteNonQuery() <> 1 Then trns.Rollback() : Return False
                    End Using
                    Using cmd As New MySqlCommand("UPDATE documenti SET Pagato=0,StatoPagamentoWeb=4,DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb='PayPal Checkout: annullato' WHERE Id=@doc AND AziendeId=@azienda AND COALESCE(Pagato,0)=0", conn, trns)
                        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
                        cmd.ExecuteNonQuery()
                    End Using
                    trns.Commit()
                    Return True
                End Using
            End Using
        Catch ex As Exception
            LogFailure("MarkCanceled", tx.DocumentiId, ex)
            Return False
        End Try
    End Function

    Private Function LoadConfig(ByVal sql As String, ByVal bind As Action(Of MySqlCommand)) As PayPalCheckoutConfig
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.Add("@online", MySqlDbType.Int32).Value = PayPalPaymentState.PAYPAL_ONLINE_VALUE
                    bind(cmd)
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            Dim cfg As New PayPalCheckoutConfig With {
                                .AccountId = SafeInt(dr("AccountId")), .CompanyConfigId = SafeInt(dr("CompanyConfigId")),
                                .AziendeId = SafeInt(dr("AziendeId")), .PagamentiTipoId = SafeInt(dr("PagamentiTipoId")),
                                .CredentialKey = Convert.ToString(dr("CredentialKey")).Trim(), .MerchantId = Convert.ToString(dr("MerchantId")).Trim(),
                                .PayeeEmail = Convert.ToString(dr("PayeeEmail")).Trim(), .BrandName = Convert.ToString(dr("BrandName")).Trim(),
                                .CurrencyCode = Convert.ToString(dr("CurrencyCode")).Trim().ToUpperInvariant(),
                                .AccountActive = SafeInt(dr("AccountActive")) = 1, .CompanyActive = SafeInt(dr("CompanyActive")) = 1}
                            Return PayPalCheckoutConfig.HydrateServerCredentials(cfg)
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogFailure("LoadConfig", 0, ex)
        End Try
        Return Nothing
    End Function

    Private Function LoadTransaction(ByVal sql As String, ByVal value As String, ByVal dbType As MySqlDbType) As PayPalCheckoutTransactionInfo
        Dim info As New PayPalCheckoutTransactionInfo()
        Try
            Using conn As New MySqlConnection(ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.Add("@value", dbType).Value = If(dbType = MySqlDbType.Int32, CType(Integer.Parse(value, CultureInfo.InvariantCulture), Object), value)
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            info.Exists = True
                            info.Id = Convert.ToInt64(dr("Id"), CultureInfo.InvariantCulture)
                            info.DocumentiId = SafeInt(dr("DocumentiId"))
                            info.TentativoNo = SafeInt(dr("TentativoNo"))
                            info.IsCurrent = Not dr.IsDBNull(dr.GetOrdinal("CurrentSlot")) AndAlso SafeInt(dr("CurrentSlot")) = 1
                            info.AziendeId = SafeInt(dr("AziendeId"))
                            info.PagamentiTipoId = SafeInt(dr("PagamentiTipoId"))
                            info.PayPalAccountId = SafeInt(dr("PayPalAccountId"))
                            info.PayPalOrderId = Convert.ToString(dr("PayPalOrderId")).Trim()
                            info.PayPalCaptureId = Convert.ToString(dr("PayPalCaptureId")).Trim()
                            info.Stato = Convert.ToString(dr("Stato")).Trim()
                            info.Importo = Convert.ToDecimal(dr("Importo"), CultureInfo.InvariantCulture)
                            info.Valuta = Convert.ToString(dr("Valuta")).Trim()
                            info.PayeeEmail = Convert.ToString(dr("PayeeEmail")).Trim()
                            info.MerchantId = Convert.ToString(dr("MerchantId")).Trim()
                            info.CreateRequestId = Convert.ToString(dr("CreateRequestId")).Trim()
                            info.CaptureRequestId = Convert.ToString(dr("CaptureRequestId")).Trim()
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogFailure("LoadTransaction", 0, ex)
        End Try
        Return info
    End Function

    Private Sub AddIdentity(ByVal cmd As MySqlCommand, ByVal tx As PayPalCheckoutTransactionInfo)
        cmd.Parameters.Add("@id", MySqlDbType.Int64).Value = tx.Id
        cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = tx.DocumentiId
        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tx.AziendeId
    End Sub

    Private Function SafeInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return 0
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed)
        Return parsed
    End Function

    Private Sub LogFailure(ByVal operation As String, ByVal documentId As Integer, ByVal ex As Exception)
        KeepStoreLog.Error("paypal-checkout-repository", operation & " documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
    End Sub
End Module
