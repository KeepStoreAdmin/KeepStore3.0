Imports System.Net
Imports System.IO
Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class var
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        'Post back to either sandbox or live
        Dim strSandbox As String = "https://www.sandbox.paypal.com/cgi-bin/webscr"
        Dim strLive As String = "https://www.paypal.com/cgi-bin/webscr"
        Dim req As HttpWebRequest = CType(WebRequest.Create(strLive), HttpWebRequest)

        'Set values for the request back
        req.Method = "POST"
        req.ContentType = "application/x-www-form-urlencoded"
        Dim Param() As Byte = Request.BinaryRead(HttpContext.Current.Request.ContentLength)
        Dim strRequest As String = Encoding.ASCII.GetString(Param)
        strRequest = strRequest + "&cmd=_notify-validate"
        req.ContentLength = strRequest.Length

        'Send the request to PayPal and get the response
        Dim streamOut As StreamWriter = New StreamWriter(req.GetRequestStream(), Encoding.ASCII)
        streamOut.Write(strRequest)
        streamOut.Close()
        Dim streamIn As StreamReader = New StreamReader(req.GetResponse().GetResponseStream())
        Dim strResponse As String = streamIn.ReadToEnd()
        streamIn.Close()

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        conn.Open()
        cmd.Connection = conn

        cmd.Parameters.AddWithValue("@idtransazione", Request.Form("txn_id"))
        cmd.Parameters.AddWithValue("@id", Request.QueryString("id"))
        If strResponse = "VERIFIED" Then
            If (Request.Form("payment_status") = "Completed") Or (Request.Form("payment_status") = "Eseguito") Then
                cmd.CommandText = "update documenti set pagato=1, idtransazione=@idtransazione where id=@id"
            Else
                cmd.CommandText = "update documenti set pagato=2, idtransazione=@idtransazione where id=@id"
            End If
            cmd.ExecuteNonQuery()
            cmd.Parameters.AddWithValue("@payment_status", Request.Form("payment_status"))
            cmd.CommandText = "insert into payment_event (idDocumento,idTransazione,Stato_Transazione) values (@id, @idtransazione, @payment_status)"
            cmd.ExecuteNonQuery()

            cmd.Dispose()

            conn.Close()
            conn.Dispose()
        Else
            'Response wasn't VERIFIED or INVALID, log for manual investigation
            cmd.Parameters.AddWithValue("@response", strResponse.ToString)
            cmd.CommandText = "insert into payment_event (idDocumento,idTransazione,Stato_Transazione) values (@id, @idtransazione, @response)"
            cmd.ExecuteNonQuery()

            cmd.Dispose()

            conn.Close()
            conn.Dispose()
        End If
    End Sub
End Class