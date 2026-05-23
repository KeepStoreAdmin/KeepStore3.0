Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Module PayPalExpressRepository
    Public Function LoadConfigForDocument(ByVal documentId As Integer) As PayPalCheckoutConfig
        If documentId <= 0 Then Return Nothing

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Dim sql As String = ""
                sql &= "SELECT v.id, v.AziendeId, v.PagamentiTipoId, v.Environment, v.ApiUsername, v.ApiPasswordProtetta, v.ApiSignatureProtetta, "
                sql &= "v.BusinessAccount, v.CurrencyCode, v.AllowLive "
                sql &= "FROM documenti d "
                sql &= "INNER JOIN vpaypal_express_azienda v ON v.AziendeId=d.AziendeId AND v.PagamentiTipoId=d.PagamentiTipoId "
                sql &= "WHERE d.id=@id AND v.Attivo=1 AND v.OnLine=@online "
                sql &= "LIMIT 1"

                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@online", MySqlDbType.Int32).Value = PayPalPaymentState.PAYPAL_ONLINE_VALUE
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            Dim cfg As New PayPalCheckoutConfig()
                            cfg.Source = "database"
                            cfg.ConfigId = SafeInt(dr("id"), 0)
                            cfg.AziendeId = SafeInt(dr("AziendeId"), 0)
                            cfg.PagamentiTipoId = SafeInt(dr("PagamentiTipoId"), 0)
                            cfg.EnvironmentName = Convert.ToString(dr("Environment")).Trim()
                            If String.IsNullOrWhiteSpace(cfg.EnvironmentName) Then cfg.EnvironmentName = "sandbox"
                            cfg.ApiUsername = Convert.ToString(dr("ApiUsername")).Trim()
                            cfg.ApiPassword = Convert.ToString(dr("ApiPasswordProtetta")).Trim()
                            cfg.ApiSignature = Convert.ToString(dr("ApiSignatureProtetta")).Trim()
                            cfg.BusinessAccount = Convert.ToString(dr("BusinessAccount")).Trim()
                            cfg.CurrencyCode = Convert.ToString(dr("CurrencyCode")).Trim().ToUpperInvariant()
                            If String.IsNullOrWhiteSpace(cfg.CurrencyCode) Then cfg.CurrencyCode = "EUR"
                            cfg.AllowLive = (SafeInt(dr("AllowLive"), 0) = 1)
                            Return cfg
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-express-repository", "LoadConfigForDocument documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        Return Nothing
    End Function

    Public Sub RecordSetExpressToken(ByVal doc As PayPalPaymentDocumentInfo, ByVal token As String, ByVal response As PayPalExpressResponse, Optional ByVal currencyCode As String = Nothing)
        If doc Is Nothing OrElse doc.DocumentId <= 0 Then Return

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("INSERT INTO paypal_express_transazioni (DocumentiId, AziendeId, PagamentiTipoId, Token, Stato, Ack, Importo, Valuta, ErrorCode, ShortMessage) VALUES (@doc, @azienda, @pagamento, @token, @stato, @ack, @importo, @valuta, @errore, @msg)", conn)
                    cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                    cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = NullIfZero(doc.AziendeId)
                    cmd.Parameters.Add("@pagamento", MySqlDbType.Int32).Value = NullIfZero(doc.PagamentiTipoId)
                    cmd.Parameters.Add("@token", MySqlDbType.VarChar, 120).Value = PayPalPaymentState.SanitizeTransactionId(token)
                    cmd.Parameters.Add("@stato", MySqlDbType.VarChar, 40).Value = "SET"
                    cmd.Parameters.Add("@ack", MySqlDbType.VarChar, 40).Value = SafeResponse(response, "ACK")
                    cmd.Parameters.Add("@importo", MySqlDbType.Decimal).Value = Math.Round(doc.TotalDocument, 2, MidpointRounding.AwayFromZero)
                    cmd.Parameters.Add("@valuta", MySqlDbType.VarChar, 3).Value = SafeCurrency(currencyCode, response)
                    cmd.Parameters.Add("@errore", MySqlDbType.VarChar, 40).Value = SafeResponse(response, "ERROR")
                    cmd.Parameters.Add("@msg", MySqlDbType.VarChar, 255).Value = SafeResponse(response, "MESSAGE")
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-express-repository", "RecordSetExpressToken documentId=" & doc.DocumentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        WriteLog(doc.DocumentId, doc.AziendeId, "SetExpressCheckout", "OK", "Token Express creato", token, Nothing)
    End Sub

    Public Sub RecordOutcome(ByVal doc As PayPalPaymentDocumentInfo, ByVal eventName As String, ByVal outcome As String, ByVal message As String, Optional ByVal token As String = Nothing, Optional ByVal errorCode As String = Nothing)
        Dim documentId As Integer = 0
        Dim aziendaId As Integer = 0
        If doc IsNot Nothing Then
            documentId = doc.DocumentId
            aziendaId = doc.AziendeId
        End If

        WriteLog(documentId, aziendaId, eventName, outcome, message, token, errorCode)
    End Sub

    Public Sub RecordOutcome(ByVal documentId As Integer, ByVal eventName As String, ByVal outcome As String, ByVal message As String, Optional ByVal token As String = Nothing, Optional ByVal errorCode As String = Nothing)
        WriteLog(documentId, 0, eventName, outcome, message, token, errorCode)
    End Sub

    Public Sub RecordPaymentResult(ByVal doc As PayPalPaymentDocumentInfo, ByVal stateValue As String, ByVal token As String, ByVal payerId As String, ByVal response As PayPalExpressResponse)
        If doc Is Nothing OrElse doc.DocumentId <= 0 Then Return

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("UPDATE paypal_express_transazioni SET PayerId=@payer, TransactionId=@txn, Stato=@stato, Ack=@ack, PaymentStatus=@paymentStatus, Valuta=COALESCE(NULLIF(@valuta, ''), Valuta), ErrorCode=@errore, ShortMessage=@msg, DataAggiornamento=CURRENT_TIMESTAMP WHERE DocumentiId=@doc AND Token=@token", conn)
                    cmd.Parameters.Add("@payer", MySqlDbType.VarChar, 120).Value = SafeText(payerId, 120)
                    cmd.Parameters.Add("@txn", MySqlDbType.VarChar, 120).Value = SafeText(If(response Is Nothing, "", response.TransactionId), 120)
                    cmd.Parameters.Add("@stato", MySqlDbType.VarChar, 40).Value = SafeText(stateValue, 40)
                    cmd.Parameters.Add("@ack", MySqlDbType.VarChar, 40).Value = SafeResponse(response, "ACK")
                    cmd.Parameters.Add("@paymentStatus", MySqlDbType.VarChar, 60).Value = SafeText(If(response Is Nothing, "", response.PaymentStatus), 60)
                    cmd.Parameters.Add("@valuta", MySqlDbType.VarChar, 3).Value = SafeResponse(response, "CURRENCY")
                    cmd.Parameters.Add("@errore", MySqlDbType.VarChar, 40).Value = SafeResponse(response, "ERROR")
                    cmd.Parameters.Add("@msg", MySqlDbType.VarChar, 255).Value = SafeResponse(response, "MESSAGE")
                    cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = doc.DocumentId
                    cmd.Parameters.Add("@token", MySqlDbType.VarChar, 120).Value = PayPalPaymentState.SanitizeTransactionId(token)
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-express-repository", "RecordPaymentResult documentId=" & doc.DocumentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        WriteLog(doc.DocumentId, doc.AziendeId, "DoExpressCheckoutPayment", stateValue, SafeResponse(response, "MESSAGE"), token, SafeResponse(response, "ERROR"))
    End Sub

    Private Sub WriteLog(ByVal documentId As Integer, ByVal aziendaId As Integer, ByVal eventName As String, ByVal outcome As String, ByVal message As String, ByVal token As String, ByVal errorCode As String)
        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("INSERT INTO paypal_express_log (DocumentiId, AziendeId, Evento, Esito, Messaggio, TokenMasked, ErrorCode) VALUES (@doc, @azienda, @evento, @esito, @msg, @token, @errore)", conn)
                    cmd.Parameters.Add("@doc", MySqlDbType.Int32).Value = NullIfZero(documentId)
                    cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = NullIfZero(aziendaId)
                    cmd.Parameters.Add("@evento", MySqlDbType.VarChar, 80).Value = SafeText(eventName, 80)
                    cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 40).Value = SafeText(outcome, 40)
                    cmd.Parameters.Add("@msg", MySqlDbType.VarChar, 255).Value = PayPalPaymentState.SanitizeOutcome(message)
                    cmd.Parameters.Add("@token", MySqlDbType.VarChar, 80).Value = MaskToken(token)
                    cmd.Parameters.Add("@errore", MySqlDbType.VarChar, 40).Value = SafeText(errorCode, 40)
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch
            ' Logging PayPal must never block checkout.
        End Try
    End Sub

    Private Function SafeResponse(ByVal response As PayPalExpressResponse, ByVal field As String) As String
        If response Is Nothing Then Return ""
        Select Case field
            Case "ACK"
                Return SafeText(response.Ack, 40)
            Case "CURRENCY"
                Return SafeText(response.CurrencyCode, 3)
            Case "ERROR"
                Return SafeText(response.ErrorCode, 40)
            Case "MESSAGE"
                Return PayPalPaymentState.SanitizeOutcome(response.ShortMessage)
        End Select

        Return ""
    End Function

    Private Function SafeCurrency(ByVal preferredCurrency As String, ByVal response As PayPalExpressResponse) As String
        Dim clean As String = SafeText(If(preferredCurrency, ""), 3).ToUpperInvariant()
        If clean = "" Then clean = SafeResponse(response, "CURRENCY").ToUpperInvariant()
        If clean = "" Then clean = "EUR"
        Return clean
    End Function

    Private Function MaskToken(ByVal token As String) As String
        Dim clean As String = PayPalPaymentState.SanitizeTransactionId(token)
        If clean = "" Then Return ""
        If clean.Length <= 10 Then Return "***"
        Return clean.Substring(0, 6) & "..." & clean.Substring(clean.Length - 4)
    End Function

    Private Function SafeText(ByVal value As String, ByVal maxLen As Integer) As String
        If value Is Nothing Then Return ""
        Dim clean As String = value.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
        If clean.Length > maxLen Then clean = clean.Substring(0, maxLen)
        Return clean
    End Function

    Private Function NullIfZero(ByVal value As Integer) As Object
        If value <= 0 Then Return DBNull.Value
        Return value
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
End Module
