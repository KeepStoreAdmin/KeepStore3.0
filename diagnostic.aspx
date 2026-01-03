<%@ Page Language="VB" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
    Protected Sub Page_Load(sender As Object, e As EventArgs)
        Dim token As String = Convert.ToString(Request.QueryString("token"))
        Dim expected As String = Convert.ToString(System.Configuration.ConfigurationManager.AppSettings("DiagToken"))

        If String.IsNullOrEmpty(expected) Then
            Response.StatusCode = 403
            Response.Write("DiagToken non configurato in Web.config")
            Response.End()
            Return
        End If

        If String.IsNullOrEmpty(token) OrElse token <> expected Then
            Response.StatusCode = 403
            Response.Write("Forbidden")
            Response.End()
            Return
        End If

        Dim path As String = Server.MapPath("~/App_Data/last_error.txt")
        Response.ContentType = "text/plain; charset=utf-8"

        If File.Exists(path) Then
            Response.Write(File.ReadAllText(path, Encoding.UTF8))
        Else
            Response.Write("Nessun last_error.txt presente. Genera un errore e riprova.")
        End If
    End Sub
</script>
