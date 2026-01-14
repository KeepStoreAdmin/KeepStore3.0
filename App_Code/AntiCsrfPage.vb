Imports System
Imports System.Web
Imports System.Web.UI

' AntiCsrfPage: mitigazione CSRF per WebForms
' Pattern: ViewStateUserKey + token in cookie + token in ViewState (double submit)
Public Class AntiCsrfPage
    Inherits Page

    Private Const AntiCsrfTokenKey As String = "__AntiCsrfToken"
    Private Const AntiCsrfUserNameKey As String = "__AntiCsrfUserName"
    Private _antiCsrfTokenValue As String

    Protected Overrides Sub OnInit(e As EventArgs)
        MyBase.OnInit(e)

        Dim requestCookie As HttpCookie = Request.Cookies(AntiCsrfTokenKey)
        Dim cookieValue As String = If(requestCookie IsNot Nothing, requestCookie.Value, Nothing)

        If Not String.IsNullOrEmpty(cookieValue) AndAlso IsGuid(cookieValue) Then
            _antiCsrfTokenValue = cookieValue
        Else
            _antiCsrfTokenValue = Guid.NewGuid().ToString("N")
            Dim responseCookie As New HttpCookie(AntiCsrfTokenKey, _antiCsrfTokenValue)
            responseCookie.HttpOnly = True
            responseCookie.SameSite = SameSiteMode.Lax
            If Request.IsSecureConnection Then
                responseCookie.Secure = True
            End If
            Response.Cookies.Set(responseCookie)
        End If

        ViewStateUserKey = _antiCsrfTokenValue
        AddHandler PreLoad, AddressOf AntiCsrfPreLoad
    End Sub

    Private Sub AntiCsrfPreLoad(sender As Object, e As EventArgs)
        If Not IsPostBack Then
            ViewState(AntiCsrfTokenKey) = _antiCsrfTokenValue
            ViewState(AntiCsrfUserNameKey) = If(Context IsNot Nothing AndAlso Context.User IsNot Nothing AndAlso Context.User.Identity IsNot Nothing, Context.User.Identity.Name, String.Empty)
        Else
            Dim token As String = TryCast(ViewState(AntiCsrfTokenKey), String)
            Dim userName As String = TryCast(ViewState(AntiCsrfUserNameKey), String)
            Dim currentUser As String = If(Context IsNot Nothing AndAlso Context.User IsNot Nothing AndAlso Context.User.Identity IsNot Nothing, Context.User.Identity.Name, String.Empty)

            If String.IsNullOrEmpty(token) OrElse Not String.Equals(token, _antiCsrfTokenValue, StringComparison.Ordinal) OrElse Not String.Equals(userName, currentUser, StringComparison.Ordinal) Then
                Throw New HttpException(403, "CSRF validation failed.")
            End If
        End If
    End Sub

    Private Shared Function IsGuid(value As String) As Boolean
        If String.IsNullOrEmpty(value) Then Return False
        Dim g As Guid
        Return Guid.TryParse(value, g)
    End Function
End Class
