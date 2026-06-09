Imports System
Imports System.Web.UI.HtmlControls

Partial Class accessonegato
    Inherits System.Web.UI.Page

    Private Function IsSafeLocalReturnUrl(ByVal value As String) As Boolean
        If String.IsNullOrWhiteSpace(value) Then Return False

        Dim candidate As String = value.Trim()
        Try
            candidate = Server.UrlDecode(candidate)
        Catch
        End Try

        If candidate.StartsWith("//", StringComparison.Ordinal) Then Return False
        If candidate.IndexOf("://", StringComparison.Ordinal) >= 0 Then Return False
        If candidate.IndexOf("\"c) >= 0 Then Return False
        If candidate.IndexOfAny(New Char() {ControlChars.Cr, ControlChars.Lf}) >= 0 Then Return False

        Dim lowered As String = candidate.ToLowerInvariant()
        If lowered.Contains("/accessonegato.aspx") OrElse lowered.EndsWith("accessonegato.aspx") Then Return False
        If lowered.Contains("/logout.aspx") OrElse lowered.EndsWith("logout.aspx") Then Return False
        If lowered.Contains("/resetpassword.aspx") OrElse lowered.EndsWith("resetpassword.aspx") Then Return False
        If lowered.Contains("/remind.aspx") OrElse lowered.EndsWith("remind.aspx") Then Return False
        If lowered.Contains("token=") Then Return False
        If lowered.Contains("javascript:") OrElse lowered.Contains("data:") Then Return False

        Return candidate.StartsWith("/", StringComparison.Ordinal) OrElse
               candidate.IndexOf(".aspx", StringComparison.OrdinalIgnoreCase) >= 0
    End Function

    Private Function SafeReturnUrl() As String
        Dim value As String = Convert.ToString(Request.QueryString("ReturnUrl"))
        If Not IsSafeLocalReturnUrl(value) Then Return String.Empty

        Try
            value = Server.UrlDecode(value).Trim()
        Catch
            value = value.Trim()
        End Try

        If value.StartsWith("/", StringComparison.Ordinal) Then Return value
        Return ResolveUrl("~/" & value.TrimStart("/"c))
    End Function

    Private Sub MarkBody()
        Try
            Dim body As HtmlGenericControl = TryCast(Master.FindControl("PageBody"), HtmlGenericControl)
            If body Is Nothing Then Return

            Dim current As String = Convert.ToString(body.Attributes("class"))
            If current.IndexOf("ks-page-auth", StringComparison.OrdinalIgnoreCase) < 0 Then
                current = (current & " ks-page-auth").Trim()
            End If
            If current.IndexOf("ks-page-accessonegato", StringComparison.OrdinalIgnoreCase) < 0 Then
                current = (current & " ks-page-accessonegato").Trim()
            End If
            body.Attributes("class") = current
        Catch
        End Try
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        MarkBody()

        If Not IsPostBack Then
            hlLogin.NavigateUrl = ResolveUrl("~/login.aspx")
            hlHome.NavigateUrl = ResolveUrl("~/Default.aspx")

            Dim returnUrl As String = SafeReturnUrl()
            If Not String.IsNullOrWhiteSpace(returnUrl) Then
                hlReturn.NavigateUrl = returnUrl
                hlReturn.Visible = True
            End If
        End If
    End Sub
End Class
