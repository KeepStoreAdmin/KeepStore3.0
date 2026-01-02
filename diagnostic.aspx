<%@ Page Language="VB" %>
<%@ Import Namespace="System" %>

<script runat="server">
    Private Const TOKEN_OK As String = "KS_DEBUG_2026"

    Protected Sub Page_Load(sender As Object, e As EventArgs)
        Dim token As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrWhiteSpace(token) OrElse Not token.Equals(Germano_2026_TOKEN_LUNGO, StringComparison.Ordinal) Then
            Response.StatusCode = 404
            Response.End()
            Return
        End If

        Response.Clear()
        Response.ContentType = "text/plain; charset=utf-8"
        Response.Write("DIAGNOSTIC")
        Response.End()
    End Sub
</script>
