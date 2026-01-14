Imports System
Imports System.Web
Imports System.Web.UI

' Base page implementing an Anti-CSRF token bound to ViewStateUserKey.
' Inherit from this page in all WebForms pages that perform state-changing actions.
Public Class AntiCsrfPage
    Inherits Page

    Private Const AntiXsrfTokenKey As String = "__AntiXsrfToken"
    Private Const AntiXsrfUserNameKey As String = "__AntiXsrfUserName"

    Private _antiXsrfTokenValue As String

    Protected Overrides Sub OnInit(e As EventArgs)
        MyBase.OnInit(e)

        Dim requestCookie As HttpCookie = Request.Cookies(AntiXsrfTokenKey)
        Dim cookieValue As String = If(requestCookie IsNot Nothing, requestCookie.Value, Nothing)

        Dim guid As Guid
        If Not String.IsNullOrEmpty(cookieValue) AndAlso Guid.TryParse(cookieValue, guid) Then
            _antiXsrfTokenValue = cookieValue
        Else
            _antiXsrfTokenValue = Guid.NewGuid().ToString("N")
            Dim responseCookie As New HttpCookie(AntiXsrfTokenKey) With {
                .HttpOnly = True,
                .Value = _antiXsrfTokenValue
            }

            If Request.IsSecureConnection Then
                responseCookie.Secure = True
            End If

            ' SameSite requires .NET 4.7.2+; ignore if not supported by runtime.
            Try
                responseCookie.SameSite = SameSiteMode.Lax
            Catch
            End Try

            Response.Cookies.Set(responseCookie)
        End If

        Page.ViewStateUserKey = _antiXsrfTokenValue
        AddHandler Page.PreLoad, AddressOf AntiXsrfPreLoad
    End Sub

    Private Sub AntiXsrfPreLoad(sender As Object, e As EventArgs)
        If Not IsPostBack Then
            ViewState(AntiXsrfTokenKey) = _antiXsrfTokenValue
            ViewState(AntiXsrfUserNameKey) = CurrentUserName()
        Else
            Dim vsToken As String = TryCast(ViewState(AntiXsrfTokenKey), String)
            Dim vsUser As String = TryCast(ViewState(AntiXsrfUserNameKey), String)

            If String.IsNullOrEmpty(vsToken) OrElse String.IsNullOrEmpty(vsUser) Then
                Throw New InvalidOperationException("Anti-CSRF token missing.")
            End If

            If Not String.Equals(vsToken, _antiXsrfTokenValue, StringComparison.Ordinal) Then
                Throw New InvalidOperationException("Anti-CSRF token validation failed.")
            End If

            If Not String.Equals(vsUser, CurrentUserName(), StringComparison.Ordinal) Then
                Throw New InvalidOperationException("Anti-CSRF user validation failed.")
            End If
        End If
    End Sub

    Protected Overridable Function CurrentUserName() As String
        If Context IsNot Nothing AndAlso Context.User IsNot Nothing AndAlso Context.User.Identity IsNot Nothing AndAlso Context.User.Identity.IsAuthenticated Then
            Return Context.User.Identity.Name
        End If
        ' Fallback for anonymous sessions.
        Return String.Empty
    End Function
End Class
