Imports System.Data
Imports MySql.Data.MySqlClient
Imports it.sella.ecomms2s
Imports System.Xml

Partial Class BancaSella_comunication
    Inherits System.Web.UI.Page

    Private Sub form1_Load(sender As Object, e As EventArgs) Handles form1.Load
        Dim idDocumento As String = ""
        Dim sitoWeb As String = ""
        Dim codiceErrore As String = ""
        Dim esitoTransizione As String = "KO"
        Try
            If (Not Request.QueryString("a") Is Nothing) And (Not Request.QueryString("b") Is Nothing) Then
                Dim shopLogin As String = Request.QueryString("a")
                Dim stringaCryptata As String = Request.QueryString("b")
                Dim objCrypt As New WSCryptDecrypt()
                Dim decryptedData As XmlNode = objCrypt.Decrypt(shopLogin, stringaCryptata)
                esitoTransizione = SafeNodeText(decryptedData, "TransactionResult")
                Dim shopTransactionID As String = SafeNodeText(decryptedData, "ShopTransactionID")
                Dim customInfo As String = SafeNodeText(decryptedData, "CustomInfo")
                idDocumento = ExtractDocumentId(customInfo)
                Dim codiceAutorizzazione As String = SafeNodeText(decryptedData, "AuthorizationCode")

                Dim documentIdValue As Integer = 0
                If Not Integer.TryParse(idDocumento, documentIdValue) OrElse documentIdValue <= 0 Then
                    WriteCallbackLog("InvalidDocument", idDocumento, esitoTransizione, Not String.IsNullOrEmpty(codiceAutorizzazione), "Documento non valido")
                    Exit Sub
                End If

                Dim params As New Dictionary(Of String, String)
                params.Add("@idDocumento", idDocumento)
                params.Add("@shopTransactionID", shopTransactionID)
                params.Add("@codiceAutorizzazione", codiceAutorizzazione)

                If esitoTransizione = "OK" Then
                    params.Add("@ultimoEsito", SanitizePaymentOutcome("BancaSella pagamento autorizzato"))

                    If GetExistingBancaSellaPaymentCount(idDocumento, codiceAutorizzazione) = 0 Then
                        ExecuteInsert("bancasella_ordini_pagati", "DocumentiId,numeroDocumento,codiceAutorizzazione", "@idDocumento,@shopTransactionID,@codiceAutorizzazione", params)
                    End If

                    ExecuteUpdate("documenti", "pagato=1, StatoPagamentoWeb=2, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@ultimoEsito", "where id=@idDocumento", params)
                Else
                    codiceErrore = SafeNodeText(decryptedData, "ErrorCode")
                    Dim descrizioneErrore As String = SafeNodeText(decryptedData, "ErrorDescription")
                    params.Add("@ultimoEsito", BuildKoPaymentOutcome(codiceErrore, descrizioneErrore))

                    ExecuteUpdate("documenti", "StatoPagamentoWeb=3, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@ultimoEsito", "where id=@idDocumento", params)
                End If
            End If
        Catch ex As Exception
            Dim ipClient As String = Request.UserHostAddress
            Dim params As New Dictionary(Of String, String)
            params.add("@ipClient", ipClient)
            Dim safeDetails As String = ex.Message
            Try
                If ex.StackTrace IsNot Nothing Then
                    Dim firstLine As String = ex.StackTrace.Split(New String() {vbCrLf, vbLf}, StringSplitOptions.RemoveEmptyEntries)(0)
                    safeDetails &= " | " & firstLine
                End If
            Catch
            End Try
            If safeDetails Is Nothing Then safeDetails = ""
            If safeDetails.Length > 1000 Then safeDetails = safeDetails.Substring(0, 1000)
            params.add("@log", "Errore comunication -> " & safeDetails)
            ExecuteInsert("bancasella_log", "IP, Log", "@ipClient,@log", params)
        End Try
    End Sub

    Private Function SafeNodeText(ByVal parent As XmlNode, ByVal nodeName As String) As String
        Try
            If parent Is Nothing Then Return ""
            Dim node As XmlNode = parent.SelectSingleNode(nodeName)
            If node Is Nothing OrElse node.InnerText Is Nothing Then Return ""
            Return node.InnerText.Trim()
        Catch
            Return ""
        End Try
    End Function

    Private Function ExtractDocumentId(ByVal customInfo As String) As String
        Try
            If String.IsNullOrEmpty(customInfo) Then Return ""
            Dim parts As String() = Split(customInfo, "*P1*")
            If parts Is Nothing OrElse parts.Length = 0 Then Return ""
            Dim firstPart As String = parts(0)
            Dim idx As Integer = firstPart.IndexOf("="c)
            If idx < 0 OrElse idx >= firstPart.Length - 1 Then Return ""
            Return firstPart.Substring(idx + 1).Trim()
        Catch
            Return ""
        End Try
    End Function

    Private Function BuildKoPaymentOutcome(ByVal errorCode As String, ByVal errorDescription As String) As String
        Dim outcome As String = "BancaSella pagamento non autorizzato"
        errorCode = SanitizePaymentOutcome(errorCode)
        errorDescription = SanitizePaymentOutcome(errorDescription)

        If Not String.IsNullOrEmpty(errorCode) Then
            outcome &= " - Codice " & errorCode
        End If

        If Not String.IsNullOrEmpty(errorDescription) Then
            outcome &= " - " & errorDescription
        End If

        Return SanitizePaymentOutcome(outcome)
    End Function

    Private Function SanitizePaymentOutcome(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sanitized As String = value.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
        While sanitized.Contains("  ")
            sanitized = sanitized.Replace("  ", " ")
        End While
        If sanitized.Length > 255 Then sanitized = sanitized.Substring(0, 255)
        Return sanitized
    End Function

    Private Function GetExistingBancaSellaPaymentCount(ByVal idDocumento As String, ByVal codiceAutorizzazione As String) As Integer
        Dim params As New Dictionary(Of String, String)
        params.Add("@idDocumento", idDocumento)

        Dim sqlString As String = "SELECT COUNT(*) FROM bancasella_ordini_pagati WHERE DocumentiId=@idDocumento"
        If Not String.IsNullOrEmpty(codiceAutorizzazione) Then
            sqlString &= " OR codiceAutorizzazione=@codiceAutorizzazione"
            params.Add("@codiceAutorizzazione", codiceAutorizzazione)
        End If

        Return ExecuteScalarInt(sqlString, params)
    End Function

    Private Sub WriteCallbackLog(ByVal stepName As String,
                                 ByVal idDocumento As String,
                                 ByVal transactionResult As String,
                                 ByVal hasAuthorizationCode As Boolean,
                                 ByVal details As String)
        Try
            Dim ipClient As String = Request.UserHostAddress
            If ipClient Is Nothing Then ipClient = ""
            If ipClient.Length > 20 Then ipClient = ipClient.Substring(0, 20)

            Dim safeDetails As String = SanitizePaymentOutcome(details)
            Dim safeLog As String = "BancaSella callback " & SanitizePaymentOutcome(stepName) &
                                    " idDocumento=" & SanitizePaymentOutcome(idDocumento) &
                                    " transactionResult=" & SanitizePaymentOutcome(transactionResult) &
                                    " hasAuthorizationCode=" & If(hasAuthorizationCode, "true", "false") &
                                    " details=" & safeDetails

            Dim params As New Dictionary(Of String, String)
            params.Add("@ipClient", ipClient)
            params.Add("@log", safeLog)
            ExecuteInsert("bancasella_log", "IP, Log", "@ipClient,@log", params)
        Catch
            ' Non interrompere mai il callback pagamento per problemi di logging
        End Try
    End Sub

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim conn As New MySqlConnection
        Dim affectedRows As Integer = 0
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandText = sqlString
                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        If paramName = "?parPrezzo" Or paramName = "?parPrezzoIvato" Then
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
                        Else
                            cmd.Parameters.AddWithValue(paramName, params(paramName))
                        End If
                    Next
                End If
                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If
                affectedRows = cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
        Return affectedRows
    End Function

    Protected Function ExecuteScalarInt(ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlString
                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                Dim value As Object = cmd.ExecuteScalar()
                cmd.Dispose()
                If value IsNot Nothing AndAlso Not IsDBNull(value) Then
                    Dim parsed As Integer = 0
                    If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
                End If
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return 0
    End Function

End Class
