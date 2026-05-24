Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class PayPalPaymentDocumentInfo
    Public Property Exists As Boolean
    Public Property DocumentId As Integer
    Public Property UtentiId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property DocumentNumber As Integer
    Public Property DocumentDate As DateTime
    Public Property Pagato As Integer
    Public Property PaymentState As Integer
    Public Property PaymentOnline As Integer
    Public Property TotalDocument As Decimal
    Public Property TransactionId As String
End Class

Public Class PayPalPendingRecheckResult
    Public Property Success As Boolean
    Public Property DocumentId As Integer
    Public Property Outcome As String
    Public Property Message As String
    Public Property PaymentStatus As String
    Public Property PendingReason As String
    Public Property ReasonCode As String
    Public Property TransactionId As String
    Public Property PayReturn As String = "ko"
End Class

Public Module PayPalPaymentState
    Public Const PAYPAL_ONLINE_VALUE As Integer = 2
    Public Const EXPRESS_TOKEN_PREFIX As String = "EC-TOKEN:"
    Public Const EXPRESS_TRANSACTION_PREFIX As String = "TXN:"

    Public Function LoadDocumentForUser(ByVal documentId As Integer, ByVal utentiId As Integer) As PayPalPaymentDocumentInfo
        Dim info As New PayPalPaymentDocumentInfo()
        If documentId <= 0 OrElse utentiId <= 0 Then Return info

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT d.id, d.UtentiId, COALESCE(d.AziendeId,0) AS AziendeId, COALESCE(d.PagamentiTipoId,0) AS PagamentiTipoId, COALESCE(d.NDocumento,0) AS NDocumento, d.DataDocumento, COALESCE(d.Pagato,0) AS Pagato, COALESCE(d.StatoPagamentoWeb,0) AS StatoPagamentoWeb, COALESCE(p.OnLine,0) AS PaymentOnline, COALESCE(pie.TotaleDocumento,0) AS TotaleDocumento, COALESCE(d.IdTransazione,'') AS IdTransazione FROM documenti d LEFT JOIN pagamentitipo p ON p.id=d.PagamentiTipoId LEFT JOIN documentipie pie ON pie.DocumentiId=d.id WHERE d.id=@id AND d.UtentiId=@uid LIMIT 1", conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = utentiId

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            info.Exists = True
                            info.DocumentId = SafeInt(dr("id"), 0)
                            info.UtentiId = SafeInt(dr("UtentiId"), 0)
                            info.AziendeId = SafeInt(dr("AziendeId"), 0)
                            info.PagamentiTipoId = SafeInt(dr("PagamentiTipoId"), 0)
                            info.DocumentNumber = SafeInt(dr("NDocumento"), 0)
                            info.DocumentDate = SafeDate(dr("DataDocumento"), DateTime.MinValue)
                            info.Pagato = SafeInt(dr("Pagato"), 0)
                            info.PaymentState = SafeInt(dr("StatoPagamentoWeb"), 0)
                            info.PaymentOnline = SafeInt(dr("PaymentOnline"), 0)
                            info.TotalDocument = SafeDecimal(dr("TotaleDocumento"), 0D)
                            info.TransactionId = Convert.ToString(dr("IdTransazione"))
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "LoadDocumentForUser documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        Return info
    End Function

    Public Function MarkPending(ByVal documentId As Integer, ByVal message As String, Optional ByVal conn As MySqlConnection = Nothing, Optional ByVal trns As MySqlTransaction = Nothing) As Integer
        Return UpdatePaymentState(documentId, 1, message, True, conn, trns)
    End Function

    Public Function MarkFailed(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 3, message, True, Nothing, Nothing)
    End Function

    Public Function MarkCanceled(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 4, message, True, Nothing, Nothing)
    End Function

    Public Function MarkPendingWithTransaction(ByVal documentId As Integer, ByVal message As String, ByVal transactionId As String) As Integer
        Return UpdatePaymentState(documentId, 1, message, True, Nothing, Nothing, transactionId)
    End Function

    Public Function MarkPendingWithExpressToken(ByVal documentId As Integer, ByVal message As String, ByVal token As String) As Integer
        Return MarkPendingWithTransaction(documentId, message, BuildExpressTokenValue(token))
    End Function

    Public Function MarkPendingWithExpressTransaction(ByVal documentId As Integer, ByVal message As String, ByVal transactionId As String) As Integer
        Return MarkPendingWithTransaction(documentId, message, BuildExpressTransactionValue(transactionId))
    End Function

    Public Function RecheckPendingPayment(ByVal documentId As Integer, ByVal utentiId As Integer) As PayPalPendingRecheckResult
        Dim result As New PayPalPendingRecheckResult()
        result.DocumentId = documentId

        If documentId <= 0 OrElse utentiId <= 0 Then
            result.Message = "PayPal Express: richiesta recheck non valida"
            Return result
        End If

        Dim doc As PayPalPaymentDocumentInfo = LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then
            result.Message = "PayPal Express: documento non trovato"
            Return result
        End If

        If doc.Pagato = 1 Then
            result.Success = True
            result.Outcome = "ALREADY_COMPLETED"
            result.PayReturn = "ok"
            result.Message = "PayPal Express: documento gia pagato"
            Return result
        End If

        If doc.PaymentOnline <> PAYPAL_ONLINE_VALUE Then
            result.Message = "PayPal: pagamento non coerente con il documento"
            Return result
        End If

        If doc.PaymentState <> 1 Then
            result.Message = "PayPal Express: documento non in attesa pagamento"
            Return result
        End If

        Dim transaction As PayPalExpressRepository.PayPalExpressTransactionInfo = PayPalExpressRepository.LoadPendingTransactionForDocument(documentId)
        If transaction Is Nothing OrElse Not transaction.Exists Then
            result.Message = "PayPal Express: transazione pending non trovata"
            Return result
        End If

        Dim transactionId As String = SanitizeTransactionId(transaction.TransactionId)
        If transactionId = "" Then transactionId = ExtractExpressTransaction(doc.TransactionId)
        If transactionId = "" Then
            result.Message = "PayPal Express: TransactionID assente"
            Return result
        End If

        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse Not cfg.IsExpressConfigured OrElse Not cfg.CanCallApi Then
            result.Message = "PayPal Express: configurazione non pronta"
            Return result
        End If

        Dim response As PayPalExpressResponse = New PayPalExpressClient(cfg).GetTransactionDetails(transactionId)
        result.TransactionId = transactionId
        result.PaymentStatus = If(response Is Nothing, "", response.PaymentStatus)
        result.PendingReason = If(response Is Nothing, "", response.PendingReason)
        result.ReasonCode = If(response Is Nothing, "", response.ReasonCode)

        If response Is Nothing OrElse Not response.IsSuccess Then
            PayPalExpressRepository.RecordRecheckResult(doc, transaction, "PENDING", response)
            result.Message = BuildRecheckFailureMessage(response)
            result.Outcome = "RECHECK_FAILED"
            result.PayReturn = "ok"
            Return result
        End If

        If Not ValidateRecheckResponse(doc, transaction, cfg, response) Then
            MarkFailed(documentId, "PayPal Express: recheck transazione non coerente")
            PayPalExpressRepository.RecordRecheckResult(doc, transaction, "FAILED", response)
            result.Outcome = "FAILED"
            result.Message = "PayPal Express: recheck transazione non coerente"
            Return result
        End If

        If response.IsCompletedPayment AndAlso Not String.IsNullOrWhiteSpace(response.TransactionId) Then
            MarkCompleted(documentId, response.TransactionId, "PayPal Express OK: " & ShortTransaction(response.TransactionId))
            PayPalExpressRepository.RecordRecheckResult(doc, transaction, "COMPLETED", response)
            result.Success = True
            result.Outcome = "COMPLETED"
            result.PayReturn = "ok"
            result.Message = "PayPal Express: pagamento completato"
            Return result
        End If

        If response.IsPendingPayment Then
            MarkPendingWithExpressTransaction(documentId, BuildPendingPaymentMessage(response), transactionId)
            PayPalExpressRepository.RecordRecheckResult(doc, transaction, "PENDING", response)
            result.Success = True
            result.Outcome = "PENDING"
            result.PayReturn = "ok"
            result.Message = BuildPendingPaymentMessage(response)
            Return result
        End If

        If response.IsFailedPayment Then
            MarkFailed(documentId, "PayPal Express: pagamento " & SanitizeOutcome(response.PaymentStatus))
            PayPalExpressRepository.RecordRecheckResult(doc, transaction, "FAILED", response)
            result.Outcome = "FAILED"
            result.Message = "PayPal Express: pagamento " & SanitizeOutcome(response.PaymentStatus)
            Return result
        End If

        MarkFailed(documentId, "PayPal Express: stato pagamento non completato")
        PayPalExpressRepository.RecordRecheckResult(doc, transaction, "FAILED", response)
        result.Outcome = "FAILED"
        result.Message = "PayPal Express: stato pagamento non completato"
        Return result
    End Function

    Public Function MarkCompleted(ByVal documentId As Integer, ByVal transactionId As String, ByVal message As String) As Integer
        If documentId <= 0 Then Return 0

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("UPDATE documenti SET Pagato=1, IdTransazione=@transazione, StatoPagamentoWeb=2, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@esito WHERE id=@id AND COALESCE(Pagato,0)<>1", conn)
                    cmd.Parameters.Add("@transazione", MySqlDbType.VarChar, 100).Value = BuildExpressTransactionValue(transactionId)
                    cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(message)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    Return cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "MarkCompleted documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        Return 0
    End Function

    Private Function UpdatePaymentState(ByVal documentId As Integer, ByVal stateValue As Integer, ByVal message As String, ByVal forceUnpaid As Boolean, ByVal existingConn As MySqlConnection, ByVal trns As MySqlTransaction) As Integer
        Return UpdatePaymentState(documentId, stateValue, message, forceUnpaid, existingConn, trns, Nothing)
    End Function

    Private Function UpdatePaymentState(ByVal documentId As Integer, ByVal stateValue As Integer, ByVal message As String, ByVal forceUnpaid As Boolean, ByVal existingConn As MySqlConnection, ByVal trns As MySqlTransaction, ByVal transactionId As String) As Integer
        If documentId <= 0 Then Return 0

        Dim ownsConnection As Boolean = False
        Dim conn As MySqlConnection = existingConn

        Try
            If conn Is Nothing Then
                conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                ownsConnection = True
            End If

            Dim sql As String = "UPDATE documenti SET "
            If forceUnpaid Then sql &= "Pagato=0, "
            If transactionId IsNot Nothing Then sql &= "IdTransazione=@transazione, "
            sql &= "StatoPagamentoWeb=@stato, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@esito WHERE id=@id AND COALESCE(Pagato,0)<>1"

            Using cmd As New MySqlCommand(sql, conn)
                If trns IsNot Nothing Then cmd.Transaction = trns
                If transactionId IsNot Nothing Then cmd.Parameters.Add("@transazione", MySqlDbType.VarChar, 100).Value = SanitizeTransactionId(transactionId)
                cmd.Parameters.Add("@stato", MySqlDbType.Int16).Value = stateValue
                cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(message)
                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                Return cmd.ExecuteNonQuery()
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "UpdatePaymentState documentId=" & documentId.ToString(CultureInfo.InvariantCulture) & " state=" & stateValue.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        Finally
            If ownsConnection AndAlso conn IsNot Nothing Then
                Try
                    conn.Close()
                    conn.Dispose()
                Catch
                End Try
            End If
        End Try

        Return 0
    End Function

    Public Function SanitizeOutcome(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sanitized As String = value.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
        While sanitized.Contains("  ")
            sanitized = sanitized.Replace("  ", " ")
        End While
        If sanitized.Length > 255 Then sanitized = sanitized.Substring(0, 255)
        Return sanitized
    End Function

    Public Function SanitizeTransactionId(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sanitized As String = value.Replace(vbCr, "").Replace(vbLf, "").Replace(vbTab, "").Trim()
        If sanitized.Length > 100 Then sanitized = sanitized.Substring(0, 100)
        Return sanitized
    End Function

    Public Function BuildExpressTokenValue(ByVal token As String) As String
        Return SanitizeTransactionId(EXPRESS_TOKEN_PREFIX & If(token, ""))
    End Function

    Public Function BuildExpressTransactionValue(ByVal transactionId As String) As String
        Return SanitizeTransactionId(EXPRESS_TRANSACTION_PREFIX & If(transactionId, ""))
    End Function

    Public Function ExtractExpressToken(ByVal value As String) As String
        Dim clean As String = SanitizeTransactionId(value)
        If clean.StartsWith(EXPRESS_TOKEN_PREFIX, StringComparison.Ordinal) Then
            Return clean.Substring(EXPRESS_TOKEN_PREFIX.Length)
        End If

        Return ""
    End Function

    Public Function ExtractExpressTransaction(ByVal value As String) As String
        Dim clean As String = SanitizeTransactionId(value)
        If clean.StartsWith(EXPRESS_TRANSACTION_PREFIX, StringComparison.Ordinal) Then
            Return clean.Substring(EXPRESS_TRANSACTION_PREFIX.Length)
        End If

        Return ""
    End Function

    Public Function IsExpressInProgressMarker(ByVal value As String) As Boolean
        Dim clean As String = SanitizeTransactionId(value)
        Return clean.StartsWith(EXPRESS_TOKEN_PREFIX, StringComparison.Ordinal) OrElse
               clean.StartsWith(EXPRESS_TRANSACTION_PREFIX, StringComparison.Ordinal)
    End Function

    Public Function GetSessionInt(ByVal key As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Try
            If HttpContext.Current Is Nothing OrElse HttpContext.Current.Session Is Nothing Then Return defaultValue
            Dim o As Object = HttpContext.Current.Session(key)
            If o Is Nothing Then Return defaultValue
            Return SafeInt(o, defaultValue)
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As Decimal
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.CurrentCulture, parsed) Then Return parsed
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeDate(ByVal value As Object, ByVal defaultValue As DateTime) As DateTime
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As DateTime
            If DateTime.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function ValidateRecheckResponse(ByVal doc As PayPalPaymentDocumentInfo, ByVal transaction As PayPalExpressRepository.PayPalExpressTransactionInfo, ByVal cfg As PayPalCheckoutConfig, ByVal response As PayPalExpressResponse) As Boolean
        If doc Is Nothing OrElse transaction Is Nothing OrElse response Is Nothing Then Return False
        If Not String.IsNullOrWhiteSpace(response.TransactionId) AndAlso Not String.Equals(SanitizeTransactionId(response.TransactionId), SanitizeTransactionId(transaction.TransactionId), StringComparison.Ordinal) Then Return False
        If Not String.IsNullOrWhiteSpace(response.CurrencyCode) AndAlso Not String.Equals(response.CurrencyCode.Trim(), cfg.CurrencyCode, StringComparison.OrdinalIgnoreCase) Then Return False
        If response.Amount > 0D AndAlso Math.Round(response.Amount, 2, MidpointRounding.AwayFromZero) <> Math.Round(transaction.Importo, 2, MidpointRounding.AwayFromZero) Then Return False
        Return True
    End Function

    Private Function BuildPendingPaymentMessage(ByVal response As PayPalExpressResponse) As String
        If response IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(response.PendingReason) Then
            Return "PayPal Express: pagamento pending (" & SanitizeOutcome(response.PendingReason) & ")"
        End If

        Return "PayPal Express: pagamento pending"
    End Function

    Private Function BuildRecheckFailureMessage(ByVal response As PayPalExpressResponse) As String
        If response Is Nothing Then Return "PayPal Express: recheck risposta assente"
        Dim code As String = SanitizeOutcome(response.ErrorCode)
        Dim message As String = SanitizeOutcome(response.ShortMessage)
        If code <> "" AndAlso message <> "" Then Return "PayPal Express recheck KO " & code & " " & message
        If code <> "" Then Return "PayPal Express recheck KO " & code
        If message <> "" Then Return "PayPal Express recheck KO " & message
        Return "PayPal Express recheck KO"
    End Function

    Private Function ShortTransaction(ByVal transactionId As String) As String
        Dim clean As String = SanitizeTransactionId(transactionId)
        If clean.StartsWith(EXPRESS_TRANSACTION_PREFIX, StringComparison.Ordinal) Then
            clean = clean.Substring(EXPRESS_TRANSACTION_PREFIX.Length)
        End If
        If clean.Length <= 12 Then Return clean
        Return clean.Substring(0, 12)
    End Function
End Module
