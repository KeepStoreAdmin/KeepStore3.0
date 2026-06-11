Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.SessionState
Imports System.Web.UI

Public Module SessionDiagnostics
    Private Const FlagFileVirtualPath As String = "~/App_Data/session-diagnostics.enabled"
    Private Const LogFileVirtualPath As String = "~/App_Data/session-diagnostics.log"
    Private ReadOnly SyncRoot As New Object()

    Public Sub Write(ByVal contextName As String, ByVal page As Page, Optional ByVal details As String = "")
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx Is Nothing OrElse page Is Nothing OrElse Not IsEnabled(ctx) Then Return

            Dim logPath As String = ctx.Server.MapPath(LogFileVirtualPath)
            Dim logDir As String = Path.GetDirectoryName(logPath)
            If Not String.IsNullOrEmpty(logDir) AndAlso Not Directory.Exists(logDir) Then
                Directory.CreateDirectory(logDir)
            End If

            Dim line As String = BuildLine(ctx, contextName, details)
            SyncLock SyncRoot
                File.AppendAllText(logPath, line & Environment.NewLine, Encoding.UTF8)
            End SyncLock
        Catch
            ' Diagnostic logging must never affect runtime behavior.
        End Try
    End Sub

    Public Sub Write(ByVal contextName As String, ByVal master As MasterPage, Optional ByVal details As String = "")
        If master Is Nothing Then Return
        Write(contextName, master.Page, details)
    End Sub

    Private Function IsEnabled(ByVal ctx As HttpContext) As Boolean
        Try
            If ctx.IsDebuggingEnabled Then Return True
        Catch
        End Try

        Try
            Dim req As HttpRequest = ctx.Request
            If req IsNot Nothing AndAlso req.IsLocal Then Return True
        Catch
        End Try

        Try
            Dim flagPath As String = ctx.Server.MapPath(FlagFileVirtualPath)
            If File.Exists(flagPath) Then Return True
        Catch
        End Try

        Return False
    End Function

    Private Function BuildLine(ByVal ctx As HttpContext, ByVal contextName As String, ByVal details As String) As String
        Dim req As HttpRequest = ctx.Request
        Dim sess As HttpSessionState = ctx.Session
        Dim parts As New List(Of String)()

        parts.Add("utc=" & DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture))
        parts.Add("local=" & DateTime.Now.ToString("o", CultureInfo.InvariantCulture))
        parts.Add("context=" & Clean(contextName, 80))
        parts.Add("path=" & Clean(GetPath(req), 180))
        parts.Add("queryKeys=" & Clean(GetQueryKeys(req), 200))
        parts.Add("sessionId=" & Clean(GetSessionId(sess), 120))
        parts.Add("sessionTimeout=" & Clean(GetSessionTimeout(sess), 20))
        parts.Add("hasLoginId=" & BoolText(SessionHas(sess, "LoginId")))
        parts.Add("loginIdPositive=" & BoolText(SessionPositive(sess, "LoginId")))
        parts.Add("hasLoginID=" & BoolText(SessionHas(sess, "LoginID")))
        parts.Add("loginIDPositive=" & BoolText(SessionPositive(sess, "LoginID")))
        parts.Add("hasUserName=" & BoolText(SessionHas(sess, "UserName")))
        parts.Add("hasListino=" & BoolText(SessionHas(sess, "Listino")))
        parts.Add("requestAuthenticated=" & BoolText(IsRequestAuthenticated(req)))
        parts.Add("sessionCookiePresent=" & BoolText(HasSessionCookie(req)))
        If Not String.IsNullOrWhiteSpace(details) Then
            parts.Add("details=" & Clean(details, 220))
        End If

        Return String.Join(" | ", parts.ToArray())
    End Function

    Private Function GetPath(ByVal req As HttpRequest) As String
        If req Is Nothing Then Return ""
        Try
            Return If(req.Path, "")
        Catch
            Return ""
        End Try
    End Function

    Private Function GetQueryKeys(ByVal req As HttpRequest) As String
        If req Is Nothing OrElse req.QueryString Is Nothing Then Return ""
        Try
            Dim keys As New List(Of String)()
            For Each rawKey As String In req.QueryString.AllKeys
                Dim key As String = If(rawKey, "")
                If key.Trim() <> "" Then
                    keys.Add(key.Trim() & "=present")
                End If
            Next
            keys.Sort(StringComparer.OrdinalIgnoreCase)
            Return String.Join(",", keys.ToArray())
        Catch
            Return ""
        End Try
    End Function

    Private Function GetSessionId(ByVal sess As HttpSessionState) As String
        Try
            If sess Is Nothing Then Return ""
            Return sess.SessionID
        Catch
            Return ""
        End Try
    End Function

    Private Function GetSessionTimeout(ByVal sess As HttpSessionState) As String
        Try
            If sess Is Nothing Then Return ""
            Return sess.Timeout.ToString(CultureInfo.InvariantCulture)
        Catch
            Return ""
        End Try
    End Function

    Private Function SessionHas(ByVal sess As HttpSessionState, ByVal key As String) As Boolean
        Try
            Return sess IsNot Nothing AndAlso sess(key) IsNot Nothing
        Catch
            Return False
        End Try
    End Function

    Private Function SessionPositive(ByVal sess As HttpSessionState, ByVal key As String) As Boolean
        Try
            If sess Is Nothing OrElse sess(key) Is Nothing Then Return False
            Dim value As Integer = 0
            Return Integer.TryParse(Convert.ToString(sess(key), CultureInfo.InvariantCulture), value) AndAlso value > 0
        Catch
            Return False
        End Try
    End Function

    Private Function IsRequestAuthenticated(ByVal req As HttpRequest) As Boolean
        Try
            Return req IsNot Nothing AndAlso req.IsAuthenticated
        Catch
            Return False
        End Try
    End Function

    Private Function HasSessionCookie(ByVal req As HttpRequest) As Boolean
        Try
            Return req IsNot Nothing AndAlso req.Cookies IsNot Nothing AndAlso req.Cookies("ASP.NET_SessionId") IsNot Nothing
        Catch
            Return False
        End Try
    End Function

    Private Function BoolText(ByVal value As Boolean) As String
        If value Then Return "true"
        Return "false"
    End Function

    Private Function Clean(ByVal value As String, ByVal maxLength As Integer) As String
        Dim text As String = If(value, "")
        text = text.Replace(vbCr, " ").Replace(vbLf, " ").Replace("|", "/").Trim()
        If text.Length > maxLength Then
            text = text.Substring(0, maxLength)
        End If
        Return text
    End Function
End Module
