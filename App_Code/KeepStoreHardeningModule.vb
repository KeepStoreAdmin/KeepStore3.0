Imports System
Imports System.Configuration
Imports System.Web

' KeepStoreHardeningModule
' Applica hardening HTTP in modo centrale (headers + HTTPS/HSTS) per ridurre codice duplicato nelle singole pagine.
'
' NOTE:
' - Modulo "best effort": non deve mai bloccare o rompere richieste; in caso di eccezioni, fail-open.
' - Se alcune pagine hanno già KeepStoreSecurity.AddSecurityHeaders/RequireHttps, non è un problema: gli header vengono sovrascritti in modo sicuro.

Public Class KeepStoreHardeningModule
    Implements IHttpModule

    Public Sub Init(ByVal context As HttpApplication) Implements IHttpModule.Init
        AddHandler context.BeginRequest, AddressOf OnBeginRequest
    End Sub

    Public Sub Dispose() Implements IHttpModule.Dispose
        ' no-op
    End Sub

    Private Sub OnBeginRequest(ByVal sender As Object, ByVal e As EventArgs)
        Try
            Dim app As HttpApplication = CType(sender, HttpApplication)
            Dim ctx As HttpContext = app.Context
            If ctx Is Nothing OrElse ctx.Request Is Nothing OrElse ctx.Response Is Nothing Then Exit Sub

            If Not IsEnabled() Then Exit Sub

            ' 1) HTTPS (redirect) + HSTS (solo se HTTPS)
            '    IMPORTANT: chiamata senza named-args per compatibilita' VB2012.
            KeepStoreSecurity.RequireHttps(ctx.Request, ctx.Response)

            ' 2) Headers di hardening
            KeepStoreSecurity.AddSecurityHeaders(ctx.Response)

        Catch
            ' fail-open
        End Try
    End Sub

    Private Function IsEnabled() As Boolean
        Try
            Dim v As String = ConfigurationManager.AppSettings("KeepStore.HardeningModule.Enabled")
            If String.IsNullOrWhiteSpace(v) Then Return True
            Return v.Trim().Equals("true", StringComparison.OrdinalIgnoreCase)
        Catch
            Return True
        End Try
    End Function

End Class
