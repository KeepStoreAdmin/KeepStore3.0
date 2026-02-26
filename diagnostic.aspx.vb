Imports System
Imports System.IO
Imports System.Text

Partial Class diagnostic
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        ' Sicurezza: accesso consentito solo con token (impostalo tu e poi rimuovi questa pagina)
        Dim token As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(token) OrElse token <> "IL_TUO_TOKEN" Then
            Response.StatusCode = 404
            Response.End()
            Return
        End If

        Dim sb As New StringBuilder()
        sb.AppendLine("Time: " & DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))
        sb.AppendLine("Url: " & Request.Url.ToString())
        sb.AppendLine("IsLocal: " & Request.IsLocal.ToString())
        sb.AppendLine("UserAgent: " & Convert.ToString(Request.UserAgent))
        sb.AppendLine("AppPath: " & Request.ApplicationPath)
        sb.AppendLine("MachineName: " & Environment.MachineName)

        Dim logPath As String = Server.MapPath("~/App_Data/last_error.txt")
        If File.Exists(logPath) Then
            sb.AppendLine("")
            sb.AppendLine("--- last_error.txt ---")
            sb.AppendLine(File.ReadAllText(logPath, Encoding.UTF8))
        Else
            sb.AppendLine("")
            sb.AppendLine("(Nessun last_error.txt in App_Data)")
        End If

        Dim lit As Literal = TryCast(FindControl("lit"), Literal)
        If lit IsNot Nothing Then
            lit.Text = "<pre>" & Server.HtmlEncode(sb.ToString()) & "</pre>"
        End If
    End Sub
End Class
