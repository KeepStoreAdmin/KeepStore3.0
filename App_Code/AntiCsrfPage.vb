Imports System
Imports System.Web
Imports System.Web.UI

' Base page:
' - HTTPS enforcement (con supporto X-Forwarded-Proto)
' - Security headers
' - Anti-CSRF token (cookie + viewstate)
Public Class AntiCsrfPage
    Inherits Page

    Private Const AntiXsrfTokenKey As String = "__AntiXsrfToken"
    Private Const AntiXsrfUserNameKey As String = "__AntiXsrfUserName"
    Private _antiXsrfTokenValue As String

    Protected Overrides Sub OnInit(e As EventArgs)

        ' 1) HTTPS + HSTS (best effort) + 2) headers di hardening
        KeepStoreSecurity.RequireHttps(Request, Response, enableHsts:=True)
        KeepStoreSecurity.AddSecurityHeaders(Response)

        ' Difesa aggiuntiva su ViewState (one-click / CSRF-like)
        Try
            If Context IsNot Nothing AndAlso Context.Session IsNot Nothing AndAlso
               Not String.IsNullOrEmpty(Context.Session.SessionID) Then
                ViewStateUserKey = Context.Session.SessionID
            End If
        Catch
            ' ignore
        End Try

        ' -----------------------------
        ' Anti-CSRF token (cookie + viewstate)
        ' -----------------------------
        Dim requestCookie As HttpCookie = Request.Cookies(AntiXsrfTokenKey)
        Dim guidValue As Guid

        If requestCookie IsNot Nothing AndAlso Guid.TryParse(requestCookie.Value, guidValue) Then
            _antiXsrfTokenValue = requestCookie.Value
        Else
            _antiXsrfTokenValue = Guid.NewGuid().ToString("N")

            Dim responseCookie As New HttpCookie(AntiXsrfTokenKey) With {
                .HttpOnly = True,
                .Value = _antiXsrfTokenValue
            }

            If Request.IsSecureConnection Then
                responseCookie.Secure = True
            End If

            ' SameSite: Lax = buon compromesso (blocca gran parte CSRF senza rompere navigazione da link esterni)
            Try
                responseCookie.SameSite = SameSiteMode.Lax
            Catch
                ' ignore (fallback framework vecchi)
            End Try

            Response.Cookies.Set(responseCookie)
        End If

        Page.ViewStateUserKey = _antiXsrfTokenValue

        AddHandler Page.PreLoad, AddressOf Master_Page_PreLoad

        MyBase.OnInit(e)
    End Sub

    Private Sub Master_Page_PreLoad(sender As Object, e As EventArgs)
        Dim currentUser As String = String.Empty
        Try
            If Context IsNot Nothing AndAlso Context.User IsNot Nothing AndAlso Context.User.Identity IsNot Nothing Then
                currentUser = Context.User.Identity.Name
            End If
        Catch
            currentUser = String.Empty
        End Try

        If Not IsPostBack Then
            ViewState(AntiXsrfTokenKey) = _antiXsrfTokenValue
            ViewState(AntiXsrfUserNameKey) = currentUser
        Else
            Dim viewStateToken As String = TryCast(ViewState(AntiXsrfTokenKey), String)
            Dim viewStateUser As String = TryCast(ViewState(AntiXsrfUserNameKey), String)

            If String.IsNullOrEmpty(viewStateToken) _
               OrElse Not String.Equals(viewStateToken, _antiXsrfTokenValue, StringComparison.Ordinal) _
               OrElse Not String.Equals(viewStateUser, currentUser, StringComparison.Ordinal) Then

                Throw New InvalidOperationException("Validation of Anti-CSRF token failed.")
            End If
        End If
    End Sub

End Class
