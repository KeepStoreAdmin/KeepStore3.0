Imports System.Data
Imports MySql.Data.MySqlClient
Imports it.sella.ecomms2s
Imports System.Xml

Partial Class BancaSella_responseClient
    Inherits System.Web.UI.Page
    Public shopTransactionID As String
    Public errore As String

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
                    errore = decryptedData.SelectSingleNode("ErrorDescription").InnerText
                    risultato = errore
                End If
                writeDBLog(risultato, decryptedData)
            End If
        Catch ex As Exception
            writeDBLog("Errore ResponseClient -> " & ex.Message)
        End Try
        If esitoTransizione = "OK" OrElse codiceErrore = "1143" Then
            If (Not sitoWeb.Contains("http://")) Then
                sitoWeb = "http://" & sitoWeb
            End If
			if coupon then
				Response.Redirect(sitoWeb & "/pagamento.aspx?cod_controllo=" & shopTransactionID & "&bancasella=true")
			else
				Response.Redirect(sitoWeb & "/documentidettaglio.aspx?id=" & idDocumento & "&ndoc=" & shopTransactionID.Replace("/", "|"))
			end if
        End If
    End Sub

    Private Sub writeDBLog(ByVal log As String)
        writeDBLog(log, "")
    End Sub

    Private Sub writeDBLog(ByVal log As String, ByVal decryptedData As XmlNode)
        Dim xmlFinale As String = ""
        Dim nodeName As String
        Dim i As Integer
        For i = 0 To decryptedData.ChildNodes.Count - 1
            nodeName = decryptedData.ChildNodes(i).Name
            If decryptedData.SelectSingleNode(nodeName).InnerText <> "" Then
                xmlFinale = xmlFinale & "<" & nodeName & ">" & decryptedData.SelectSingleNode(nodeName).InnerText & "</" & nodeName & ">"
            End If
        Next i
        writeDBLog(log, xmlFinale)
    End Sub

    Private Sub writeDBLog(ByVal log As String, ByVal xmlFinale As String)
        Dim ipClient As String = Request.UserHostAddress
        Dim params As New Dictionary(Of String, String)
        params.add("@ipClient", ipClient)
        params.add("@log", log)
        params.add("@xmlFinale", xmlFinale)
        ExecuteInsert("bancasella_log", "IP, Log, XML", "@ipClient,@log,@xmlFinale", params)
    End Sub

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim conn As New MySqlConnection
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
                cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Function

End Class
