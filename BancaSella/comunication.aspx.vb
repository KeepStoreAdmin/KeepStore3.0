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
                esitoTransizione = decryptedData.SelectSingleNode("TransactionResult").InnerText
                Dim shopTransactionID As String = decryptedData.SelectSingleNode("ShopTransactionID").InnerText
                Dim customInfo As String() = Split(decryptedData.SelectSingleNode("CustomInfo").InnerText, "*P1*")
                idDocumento = Split(customInfo(0), "=")(1)
                Dim codiceAutorizzazione As String = decryptedData.SelectSingleNode("AuthorizationCode").InnerText
                If esitoTransizione = "OK" Then
                    Dim params As New Dictionary(Of String, String)
                    params.add("@idDocumento", idDocumento)
                    params.add("@shopTransactionID", shopTransactionID)
                    params.add("@codiceAutorizzazione", codiceAutorizzazione)
                    ExecuteInsert("bancasella_ordini_pagati", "DocumentiId,numeroDocumento,codiceAutorizzazione", "@idDocumento,@shopTransactionID,@codiceAutorizzazione", params)
                    ExecuteUpdate("documenti", "pagato=1", "where id=@idDocumento", params)
                End If
            End If
        Catch ex As Exception
            Dim ipClient As String = Request.UserHostAddress
            Dim params As New Dictionary(Of String, String)
            params.add("@ipClient", ipClient)
            params.add("@log", "Errore comunication -> " & ex.Message)
            ExecuteInsert("bancasella_log", "IP, Log", "@ipClient,@log", params)
        End Try
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
