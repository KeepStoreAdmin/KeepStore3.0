<%@ Page Language="VB" AutoEventWireup="false" ValidateRequest="false" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>KeepStore Diagnostic</title>
    <meta charset="utf-8" />
</head>
<body>
<form id="form1" runat="server">
    <div style="font-family: Consolas, monospace; padding: 16px;">
        <h2>Diagnostic</h2>
        <asp:Literal ID="lit" runat="server" />
    </div>
</form>

<script runat="server">

    ' CAMBIA QUESTO TOKEN con uno tuo, poi usa lo stesso nell'URL:
    ' https://www.taikun.it/diagnostic.aspx?token=IL_TOKEN_ESATTO
    Private Const DIAG_TOKEN As String = "KS_DEBUG_2026_CAMBIA_QUESTO"

    Protected Sub Page_Load(sender As Object, e As EventArgs)
        Dim token As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(token) OrElse token <> DIAG_TOKEN Then
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
        sb.AppendLine("")
        If File.Exists(logPath) Then
            sb.AppendLine("--- last_error.txt ---")
            sb.AppendLine(File.ReadAllText(logPath, Encoding.UTF8))
        Else
            sb.AppendLine("(Nessun last_error.txt in App_Data)")
        End If

        lit.Text = "<pre>" & Server.HtmlEncode(sb.ToString()) & "</pre>"
    End Sub

</script>
</body>
</html>
