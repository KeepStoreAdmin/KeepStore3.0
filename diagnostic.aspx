<%@ Page Language="VB" %>

<script runat="server">
    Private Const TOKEN As String = "KS_DEBUG_2026" ' <-- Cambia questo token con una stringa lunga e segreta

    Protected Sub Page_Load(sender As Object, e As EventArgs)
        Dim t As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(t) OrElse Not String.Equals(t, TOKEN, StringComparison.Ordinal) Then
            Response.StatusCode = 404
            Response.End()
            Return
        End If

        Response.ContentType = "text/plain"
        Response.ContentEncoding = System.Text.Encoding.UTF8

        Try
            Dim path As String = Server.MapPath("~/App_Data/errors.log")
            If System.IO.File.Exists(path) Then
                Response.Write(System.IO.File.ReadAllText(path, System.Text.Encoding.UTF8))
            Else
                Response.Write("Nessun log trovato: " & path)
            End If
        Catch ex As Exception
            Response.Write("Errore nel leggere log: " & ex.ToString())
        End Try
    End Sub
</script>
