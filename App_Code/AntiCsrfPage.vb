Imports System
Imports System.Web
Imports System.Web.UI

' Base page implementing an Anti-CSRF token bound to ViewStateUserKey.
' Inherit from this page in WebForms pages that perform state-changing actions.
Public Class AntiCsrfPage
    Inherits Page

    Private Const AntiXsrfTokenKey As String = "__AntiXsrfToken"
    Private Const AntiXsrfUserNameKey As String = "__AntiXsrfUserName"

    Private _antiXsrfTokenValue As String

    Protected Overrides Sub OnPreInit(e As EventArgs)
        MyBase.OnPreInit(e)

        ' 1) HTTPS + HSTS (best effort) + 2) security headers
        KeepStoreSecurity.AddSecurityHeaders(Response)
        KeepStoreSecurity.RequireHttps(Request, Response, enableHsts:=True)
    End Sub

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

            ' NOTE: vsUser can legitimately be empty for anonymous sessions.
            If vsUser Is Nothing Then vsUser = String.Empty

            ' If ViewState is missing or tampered, safely drop the POST and reload the page.
            ' This prevents hard crashes from malformed/bot POSTs and from anonymous postbacks.
            If String.IsNullOrEmpty(vsToken) Then
                RejectPostBack("Anti-CSRF token missing")
                Exit Sub
            End If

            If Not String.Equals(vsToken, _antiXsrfTokenValue, StringComparison.Ordinal) Then
                RejectPostBack("Anti-CSRF token validation failed")
                Exit Sub
            End If

            If Not String.Equals(vsUser, CurrentUserName(), StringComparison.Ordinal) Then
                RejectPostBack("Anti-CSRF user validation failed")
                Exit Sub
            End If
        End If
    End Sub

    Private Sub RejectPostBack(ByVal reason As String)
        ' Best-effort: redirect to the same URL via GET (discard POST payload)
        Try
            ' (Optional) header for diagnostics; harmless if stripped by proxies
            Response.Headers("X-KeepStore-CSRF") = reason
        Catch
        End Try

        If Request IsNot Nothing AndAlso String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
            Try
                Response.Redirect(Request.RawUrl, False)
                If Context IsNot Nothing AndAlso Context.ApplicationInstance IsNot Nothing Then
                    Context.ApplicationInstance.CompleteRequest()
                End If
            Catch
            End Try
        End If
    End Sub

    Protected Overridable Function CurrentUserName() As String
        If Context IsNot Nothing AndAlso Context.User IsNot Nothing AndAlso Context.User.Identity IsNot Nothing AndAlso Context.User.Identity.IsAuthenticated Then
            Return Context.User.Identity.Name
        End If
        Return String.Empty
    End Function

End Class
