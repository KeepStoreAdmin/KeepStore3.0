Imports System
Imports System.Web.UI.HtmlControls

Partial Class accessonegato
    Inherits System.Web.UI.Page

    Private Function ResolveRequestedDestination() As String
        Return PostLoginReturnUrlPolicy.FirstValidReturnUrl(
            HttpContext.Current,
            Request.QueryString("ReturnUrl"),
            Session("Page"),
            Session("Pagina_visitata"),
            Request.UrlReferrer,
            PostLoginReturnUrlPolicy.PeekRememberedContext(HttpContext.Current))
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
            hlHome.NavigateUrl = ResolveUrl("~/Default.aspx")

            Dim returnUrl As String = ResolveRequestedDestination()
            If Not String.IsNullOrWhiteSpace(returnUrl) Then
                PostLoginReturnUrlPolicy.RememberContext(HttpContext.Current, returnUrl)
                hlLogin.NavigateUrl = PostLoginReturnUrlPolicy.BuildLoginUrl(HttpContext.Current, returnUrl)

                If Not PostLoginReturnUrlPolicy.IsProtectedDestination(HttpContext.Current, returnUrl) Then
                    hlReturn.NavigateUrl = returnUrl
                    hlReturn.Visible = True
                Else
                    hlReturn.Visible = False
                End If
            Else
                hlLogin.NavigateUrl = PostLoginReturnUrlPolicy.BuildLoginUrl(HttpContext.Current, Nothing)
                hlReturn.Visible = False
            End If
        End If
    End Sub
End Class
