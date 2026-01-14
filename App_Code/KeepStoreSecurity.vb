Imports System
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web

' KeepStoreSecurity
' - Output encoding helpers
' - Parsing/sanitization helpers for querystring/session
' - Response hardening (headers) + HTTPS enforcement
'
' Nota: le policy (CSP, cache, ecc.) sono volutamente "incrementali" per ridurre il rischio di breaking change
' sul template frontend.
Public Module KeepStoreSecurity

    ' -----------------------------
    ' Response hardening
    ' -----------------------------

    ' Imposta header di sicurezza "safe-by-default".
    ' NB: CSP volutamente permissiva per non rompere template legacy (inline/eval).
    Public Sub AddSecurityHeaders(resp As HttpResponse)
        If resp Is Nothing Then Return

        SafeSetHeader(resp, "X-Frame-Options", "SAMEORIGIN")
        SafeSetHeader(resp, "X-Content-Type-Options", "nosniff")
        SafeSetHeader(resp, "Referrer-Policy", "strict-origin-when-cross-origin")
        SafeSetHeader(resp, "Permissions-Policy", "geolocation=(), microphone=(), camera=()")

        ' CSP incrementale (da irrigidire quando si puliscono inline script e CDN)
        Dim csp As String = "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; " &
                            "img-src 'self' data: blob:; " &
                            "media-src 'self' data: blob:; " &
                            "font-src 'self' data:; " &
                            "connect-src 'self' *; " &
                            "frame-ancestors 'self';"
        SafeSetHeader(resp, "Content-Security-Policy", csp)

        ' Header moderni (best effort)
        SafeSetHeader(resp, "Cross-Origin-Opener-Policy", "same-origin")
        SafeSetHeader(resp, "Cross-Origin-Resource-Policy", "same-origin")

        ' Per pagine con sessione autenticata: evitare caching lato browser/proxy
        Dim ctx = HttpContext.Current
        If ctx IsNot Nothing AndAlso ctx.Request IsNot Nothing AndAlso ctx.Request.IsAuthenticated Then
            Try
                resp.Cache.SetCacheability(HttpCacheability.NoCache)
                resp.Cache.SetNoStore()
                resp.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
            Catch
                ' ignore
            End Try
        End If
    End Sub

    Private Sub SafeSetHeader(resp As HttpResponse, name As String, value As String)
        Try
            resp.Headers.Remove(name)
            resp.Headers.Add(name, value)
        Catch
            Try
                resp.AppendHeader(name, value)
            Catch
                ' ignore
            End Try
        End Try
    End Sub

    ' Redirect a HTTPS se necessario (considera anche reverse proxy con X-Forwarded-Proto).
    Public Sub RequireHttps(req As HttpRequest, resp As HttpResponse, Optional enableHsts As Boolean = True)
        If req Is Nothing OrElse resp Is Nothing Then Return

        Dim isHttps As Boolean = req.IsSecureConnection

        Dim xfproto As String = req.Headers("X-Forwarded-Proto")
        If Not String.IsNullOrEmpty(xfproto) Then
            isHttps = xfproto.Equals("https", StringComparison.OrdinalIgnoreCase)
        End If

        If Not isHttps AndAlso Not req.IsLocal Then
            Dim ub As New UriBuilder(req.Url)
            ub.Scheme = Uri.UriSchemeHttps
            ub.Port = -1
            resp.Redirect(ub.Uri.ToString(), True)
            Return
        End If

        If enableHsts AndAlso isHttps Then
            SafeSetHeader(resp, "Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        End If
    End Sub

    ' -----------------------------
    ' Encoding helpers (output)
    ' -----------------------------

    Public Function Html(value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Public Function HtmlAttr(value As Object) As String
        Return HttpUtility.HtmlAttributeEncode(Convert.ToString(value))
    End Function

    Public Function Url(value As Object) As String
        Return HttpUtility.UrlEncode(Convert.ToString(value))
    End Function

    Public Function Js(value As Object) As String
        Return HttpUtility.JavaScriptStringEncode(Convert.ToString(value))
    End Function

    ' -----------------------------
    ' Parsing/sanitization helpers
    ' -----------------------------

    Public Function ParseInt(value As Object, Optional defaultValue As Integer = 0) As Integer
        If value Is Nothing Then Return defaultValue
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue

        Dim n As Integer
        If Integer.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        If Integer.TryParse(s, NumberStyles.Integer, CultureInfo.CurrentCulture, n) Then Return n
        Return defaultValue
    End Function

    ' Convenienza: "sanitize" per input numerici attesi in querystring/session
    Public Function SqlCleanInt(value As Object, Optional defaultValue As Integer = 0) As Integer
        Return ParseInt(value, defaultValue)
    End Function

    Public Function SqlCleanDecimal(value As Object, Optional defaultValue As Decimal = 0D) As Decimal
        If value Is Nothing Then Return defaultValue
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue

        s = s.Trim()

        Dim d As Decimal
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, New CultureInfo("it-IT"), d) Then Return d
        Return defaultValue
    End Function

    ' Consente solo una lista di ID numerici separati da virgola: "1,2,3"
    Public Function SafeCsvIds(csv As String) As String
        If String.IsNullOrWhiteSpace(csv) Then Return ""
        Dim cleaned As String = Regex.Replace(csv, "[^0-9,]", "")
        cleaned = Regex.Replace(cleaned, ",+", ",")
        cleaned = cleaned.Trim(","c)
        Return cleaned
    End Function

    ' Escape per LIKE (SQL Server): %, _, [, ]
    Public Function SqlEscapeLike(value As String) As String
        If value Is Nothing Then Return ""
        Dim s As String = value
        s = s.Replace("[", "[[]")
        s = s.Replace("%", "[%]")
        s = s.Replace("_", "[_]")
        Return s
    End Function

End Module
