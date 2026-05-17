Imports System.Data
Imports MySql.Data.MySqlClient
Imports it.sella.ecomms2s
Imports System.Xml

Partial Class BancaSella_responseClient
    Inherits System.Web.UI.Page
    Public shopTransactionID As String
    Public errore As String = "Pagamento non completato. Puoi riprovare dall'ordine o contattare l'assistenza."

    Private Sub BancaSella_responseClientError_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim idDocumento As String = ""
        Dim sitoWeb As String = ""
        Dim codiceErrore As String = ""
        Dim esitoTransizione As String = "KO"
		Dim coupon As Boolean = false
        Try
            If (Not Request.QueryString("a") Is Nothing) And (Not Request.QueryString("b") Is Nothing) Then
                Dim shopLogin As String = Request.QueryString("a")
                Dim stringaCryptata As String = Request.QueryString("b")
                Dim objCrypt As New WSCryptDecrypt()
                Dim decryptedData As XmlNode = objCrypt.Decrypt(shopLogin, stringaCryptata)
                esitoTransizione = decryptedData.SelectSingleNode("TransactionResult").InnerText
                shopTransactionID = decryptedData.SelectSingleNode("ShopTransactionID").InnerText
                Dim customInfo As String() = Split(decryptedData.SelectSingleNode("CustomInfo").InnerText, "*P1*")
                idDocumento = Split(customInfo(0), "=")(1)
				if idDocumento.Contains("coupon") then
					idDocumento = Split(idDocumento, "-")(1)
					coupon = true
				end if
                sitoWeb = Split(customInfo(1), "=")(1)
                Dim risultato As String = ""
                If esitoTransizione = "OK" Then
                    risultato = "Transazione eseguita con successo"
                Else
                    codiceErrore = decryptedData.SelectSingleNode("ErrorCode").InnerText
                    errore = "Pagamento non completato. Puoi riprovare dall'ordine o contattare l'assistenza."
                    risultato = errore
                End If
                writeDBLog(risultato, decryptedData)
            End If
        Catch ex As Exception
            writeDBLog("Errore ResponseClient -> " & ex.Message)
            errore = "Non e' stato possibile completare la verifica del pagamento. Puoi riprovare dall'ordine o contattare l'assistenza."
        End Try
        If Not IsValidDocumentId(idDocumento) Then
            shopTransactionID = ""
        End If
        If IsValidDocumentId(idDocumento) Then
            If (Not sitoWeb.Contains("http://")) Then
                sitoWeb = "http://" & sitoWeb
            End If
			if coupon then
				Response.Redirect(sitoWeb & "/pagamento.aspx?cod_controllo=" & shopTransactionID & "&bancasella=true")
			else
                Dim payReturn As String = If(esitoTransizione = "OK", "ok", "ko")
                Response.Redirect(sitoWeb & "/documentidettaglio.aspx?id=" & System.Web.HttpUtility.UrlEncode(idDocumento) & "&payreturn=" & payReturn)
			end if
        End If
    End Sub

    Private Function IsValidDocumentId(ByVal idDocumento As String) As Boolean
        Dim parsed As Integer = 0
        Return Integer.TryParse((idDocumento & "").Trim(), parsed) AndAlso parsed > 0
    End Function

        Private Function TruncValue(ByVal s As String, ByVal maxLen As Integer) As String
        If s Is Nothing Then Return ""
        If s.Length <= maxLen Then Return s
        Return s.Substring(0, maxLen)
    End Function

    Private Sub writeDBLog(ByVal log As String)
        writeDBLog(log, CType(Nothing, XmlNode))
    End Sub

    ' Log minimale + sicuro:
    ' - Non salva querystring
    ' - Non salva campi potenzialmente sensibili
    ' - Salva un sottoinsieme utile per diagnosi (esito, id transazione, errori)
    Private Sub writeDBLog(ByVal log As String, ByVal decryptedData As XmlNode)
        Dim xmlFinale As String = ""

        Try
            If decryptedData IsNot Nothing Then
                Dim allowed As String() = {
                    "TransactionResult",
                    "ShopTransactionID",
                    "AuthorizationCode",
                    "ErrorCode",
                    "ErrorDescription",
                    "BankTransactionID",
                    "CustomInfo"
                }

                For Each nodeName As String In allowed
                    Dim n As XmlNode = decryptedData.SelectSingleNode(nodeName)
                    If n IsNot Nothing Then
                        Dim v As String = n.InnerText
                        If Not String.IsNullOrEmpty(v) Then
                            ' Escape per evitare rotture del log XML
                            Dim esc As String = System.Security.SecurityElement.Escape(v)
                            xmlFinale &= "<" & nodeName & ">" & esc & "</" & nodeName & ">"
                        End If
                    End If
                Next
            End If
        Catch
            ' Se il building XML fallisce, logga comunque solo il messaggio testuale
            xmlFinale = ""
        End Try

        writeDBLog(log, xmlFinale)
    End Sub

    Private Sub writeDBLog(ByVal log As String, ByVal xmlFinale As String)
        Dim ipClient As String = Request.UserHostAddress
        If ipClient Is Nothing Then ipClient = ""
        If ipClient.Length > 20 Then ipClient = ipClient.Substring(0, 20)

        Dim safeLog As String = TruncValue(log, 1000)
        Dim safeXml As String = TruncValue(xmlFinale, 1000)

        Dim params As New Dictionary(Of String, String)
        params.Add("@ipClient", ipClient)
        params.Add("@log", safeLog)
        params.Add("@xmlFinale", safeXml)

        ExecuteInsert("bancasella_log", "IP, Log, XML", "@ipClient,@log,@xmlFinale", params)
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
                For Each paramName In params.Keys
                    If paramName = "?parPrezzo" Or paramName = "?parPrezzoIvato" Then
                        cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
                    Else
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    End If
                Next
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

End Class
