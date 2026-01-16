Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web

' KeepStoreAnalyticsGetModule
' Logging "analytics" delle GET (querystring) in modo robusto e sicuro.
'
' - Log su file in App_Data\logs (evita dipendenze DB)
' - Filtra chiavi sensibili (pwd/token/etc.)
' - Limita lunghezza (anti log-injection / anti DOS)
' - Fail-open: mai interrompere la richiesta

Public Class KeepStoreAnalyticsGetModule
    Implements IHttpModule

    Private Shared ReadOnly _lockObj As New Object()

    Public Sub Init(ByVal context As HttpApplication) Implements IHttpModule.Init
        AddHandler context.AcquireRequestState, AddressOf OnAcquireRequestState
    End Sub

    Public Sub Dispose() Implements IHttpModule.Dispose
        ' no-op
    End Sub

    Private Sub OnAcquireRequestState(ByVal sender As Object, ByVal e As EventArgs)
        Try
            Dim app As HttpApplication = CType(sender, HttpApplication)
            Dim ctx As HttpContext = app.Context
            If ctx Is Nothing OrElse ctx.Request Is Nothing Then Exit Sub

            If Not IsEnabled() Then Exit Sub

            Dim req As HttpRequest = ctx.Request
            If Not "GET".Equals(req.HttpMethod, StringComparison.OrdinalIgnoreCase) Then Exit Sub

            If IsStaticAsset(req) Then Exit Sub
            If Not IsIncludedPath(req) Then Exit Sub

            WriteLogLine(ctx)

        Catch
            ' fail-open
        End Try
    End Sub

    Private Function IsEnabled() As Boolean
        Try
            Dim v As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.Enabled")
            If String.IsNullOrWhiteSpace(v) Then Return False
            Return v.Trim().Equals("true", StringComparison.OrdinalIgnoreCase)
        Catch
            Return False
        End Try
    End Function

    Private Function IsStaticAsset(ByVal req As HttpRequest) As Boolean
        Try
            Dim ext As String = VirtualPathUtility.GetExtension(req.Path)
            If String.IsNullOrEmpty(ext) Then Return False

            Dim excl As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.ExcludeExtensions")
            If String.IsNullOrWhiteSpace(excl) Then
                excl = ".css;.js;.png;.jpg;.jpeg;.gif;.svg;.woff;.woff2;.ttf;.eot;.map;.ico"
            End If

            Dim parts() As String = excl.Split(";"c)
            For Each p As String In parts
                If ext.Equals(p.Trim(), StringComparison.OrdinalIgnoreCase) Then Return True
            Next

            Return False
        Catch
            Return False
        End Try
    End Function

    Private Function IsIncludedPath(ByVal req As HttpRequest) As Boolean
        Try
            Dim incl As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.IncludePaths")
            If String.IsNullOrWhiteSpace(incl) Then
                ' default: solo pagine note sensibili/di interesse analytics
                incl = "wishlist.aspx;rettificaMagazzino.aspx;articoli.aspx"
            End If

            Dim page As String = Path.GetFileName(req.Path)
            Dim parts() As String = incl.Split(";"c)
            For Each p As String In parts
                If page.Equals(p.Trim(), StringComparison.OrdinalIgnoreCase) Then Return True
            Next

            Return False
        Catch
            Return False
        End Try
    End Function

    Private Sub WriteLogLine(ByVal ctx As HttpContext)
        Dim req As HttpRequest = ctx.Request
        Dim nowUtc As DateTime = DateTime.UtcNow

        Dim maxLen As Integer = GetMaxLen()

        Dim userId As String = SafeString(GetSessionValue(ctx, "UtentiID"), maxLen)
        If String.IsNullOrEmpty(userId) Then userId = SafeString(GetSessionValue(ctx, "utenteid"), maxLen)

        Dim ip As String = GetClientIp(req)
        Dim ua As String = SafeString(req.UserAgent, maxLen)
        Dim referer As String = ""
        If req.UrlReferrer IsNot Nothing Then referer = SafeString(req.UrlReferrer.ToString(), maxLen)

        Dim qs As String = BuildSafeQueryString(req, maxLen)

        Dim line As String = String.Format(CultureInfo.InvariantCulture,
                                           "{0}\t{1}\t{2}\t{3}\t{4}\t{5}\t{6}",
                                           nowUtc.ToString("o", CultureInfo.InvariantCulture),
                                           SafeString(req.Url.AbsolutePath, maxLen),
                                           SafeString(userId, maxLen),
                                           SafeString(ip, maxLen),
                                           ua,
                                           referer,
                                           qs)

        AppendToFile(ctx, line)
    End Sub

    Private Function GetMaxLen() As Integer
        Try
            Dim v As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.MaxLen")
            Dim n As Integer
            If Integer.TryParse(v, n) AndAlso n > 0 Then Return n
        Catch
        End Try
        Return 2000
    End Function

    Private Function GetSessionValue(ByVal ctx As HttpContext, ByVal key As String) As Object
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return Nothing
            Return ctx.Session(key)
        Catch
            Return Nothing
        End Try
    End Function

    Private Function GetClientIp(ByVal req As HttpRequest) As String
        Try
            Dim xff As String = req.Headers("X-Forwarded-For")
            If Not String.IsNullOrEmpty(xff) Then
                Dim parts() As String = xff.Split(","c)
                If parts.Length > 0 Then Return parts(0).Trim()
            End If
        Catch
        End Try

        Try
            Return req.UserHostAddress
        Catch
            Return ""
        End Try
    End Function

    Private Function BuildSafeQueryString(ByVal req As HttpRequest, ByVal maxLen As Integer) As String
        Try
            If req.QueryString Is Nothing OrElse req.QueryString.Count = 0 Then Return ""

            Dim deny As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
            deny.Add("password")
            deny.Add("pwd")
            deny.Add("pass")
            deny.Add("token")
            deny.Add("key")
            deny.Add("auth")
            deny.Add("session")
            deny.Add("phpsessid")

            Dim sb As New StringBuilder()

            For Each k As String In req.QueryString.AllKeys
                Dim keyName As String = If(k, "")
                Dim v As String = req.QueryString(keyName)

                If deny.Contains(keyName) Then
                    v = "***"
                Else
                    v = SafeString(v, maxLen)
                End If

                If sb.Length > 0 Then sb.Append("&")
                sb.Append(HttpUtility.UrlEncode(keyName))
                sb.Append("=")
                sb.Append(HttpUtility.UrlEncode(v))

                If sb.Length >= maxLen Then Exit For
            Next

            Dim s As String = sb.ToString()
            If s.Length > maxLen Then s = s.Substring(0, maxLen)
            Return s

        Catch
            Return ""
        End Try
    End Function

    Private Function SafeString(ByVal s As String, ByVal maxLen As Integer) As String
        If s Is Nothing Then Return ""

        Dim t As String = s
        t = t.Replace(vbCrLf, " ").Replace(vbCr, " ").Replace(vbLf, " ")
        t = t.Trim()

        If t.Length > maxLen Then t = t.Substring(0, maxLen)
        Return t
    End Function

    Private Sub AppendToFile(ByVal ctx As HttpContext, ByVal line As String)
        Try
            Dim baseDir As String = ctx.Server.MapPath("~/App_Data")
            Dim logDir As String = Path.Combine(baseDir, "logs")
            Dim filePath As String = Path.Combine(logDir, "analytics-get-" & DateTime.UtcNow.ToString("yyyyMMdd", CultureInfo.InvariantCulture) & ".log")

            SyncLock _lockObj
                If Not Directory.Exists(logDir) Then Directory.CreateDirectory(logDir)
                Using fs As New FileStream(filePath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)
                    Using sw As New StreamWriter(fs, Encoding.UTF8)
                        sw.WriteLine(line)
                    End Using
                End Using
            End SyncLock

        Catch
            ' ignore
        End Try
    End Sub

End Class
