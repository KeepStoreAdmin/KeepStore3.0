Imports System
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web

' KeepStoreSecurity
' - Output encoding helpers
' - Parsing/sanitization helpers for querystring/session
' - Response hardening (headers) + HTTPS enforcement
'
' Nota: le policy (CSP, cache, ecc.) sono volutamente "incrementali" per ridurre il rischio di breaking change.

Public Module KeepStoreSecurity

    ' -----------------------------
    ' Response hardening
    ' -----------------------------

    Public Sub AddSecurityHeaders(resp As HttpResponse)
        If resp Is Nothing Then Return

        SafeSetHeader(resp, "X-Frame-Options", "SAMEORIGIN")
        SafeSetHeader(resp, "X-Content-Type-Options", "nosniff")
        SafeSetHeader(resp, "Referrer-Policy", "strict-origin-when-cross-origin")
        SafeSetHeader(resp, "Permissions-Policy", "geolocation=(), microphone=(), camera=()")

        ' CSP "compatibile" (per template legacy): molto permissiva, ma aggiunge frame-ancestors.
        Dim csp As String = "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; " &
                            "img-src 'self' data: blob:; " &
                            "media-src 'self' data: blob:; " &
                            "font-src 'self' data:; " &
                            "connect-src 'self' *; " &
                            "frame-ancestors 'self';"
        SafeSetHeader(resp, "Content-Security-Policy", csp)

        SafeSetHeader(resp, "Cross-Origin-Opener-Policy", "same-origin")
        SafeSetHeader(resp, "Cross-Origin-Resource-Policy", "same-origin")

        ' No-store sulle pagine autenticate (wishlist/rettifiche tipicamente lo sono)
        Dim ctx = HttpContext.Current
        Dim isAuth As Boolean = False
        If ctx IsNot Nothing AndAlso ctx.Request IsNot Nothing Then
            isAuth = ctx.Request.IsAuthenticated
        End If

        If isAuth Then
            resp.Cache.SetCacheability(HttpCacheability.NoCache)
            resp.Cache.SetNoStore()
            resp.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        End If
    End Sub

    Public Sub RequireHttps(req As HttpRequest, resp As HttpResponse, Optional enableHsts As Boolean = True)
        If req Is Nothing OrElse resp Is Nothing Then Return

        Dim isHttps As Boolean = req.IsSecureConnection

        ' Supporto proxy / load balancer
        Dim xfproto As String = req.Headers("X-Forwarded-Proto")
        If Not String.IsNullOrEmpty(xfproto) Then
            isHttps = xfproto.Equals("https", StringComparison.OrdinalIgnoreCase)
        End If

        If Not isHttps AndAlso Not req.IsLocal Then
            Dim url = req.Url
            Dim builder As New UriBuilder(url)
            builder.Scheme = Uri.UriSchemeHttps
            builder.Port = -1
            resp.Redirect(builder.Uri.ToString(), True)
            Return
        End If

        If enableHsts AndAlso isHttps Then
            SafeSetHeader(resp, "Strict-Transport-Security", "max-age=31536000; includeSubDomains")
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

    ' -----------------------------
    ' Output encoding
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

    ' Alias legacy: molti .aspx usano H / HA / U direttamente.
    Public Function H(value As Object) As String
        Return Html(value)
    End Function

    Public Function HA(value As Object) As String
        Return HtmlAttr(value)
    End Function

    Public Function U(value As Object) As String
        Return Url(value)
    End Function

    Public Function Js(value As Object) As String
        Dim s As String = Convert.ToString(value)
        If s Is Nothing Then Return ""

        s = s.Replace("\\", "\\\\").Replace("'", "\\'").Replace("""", "\\""")
        s = s.Replace(vbCrLf, "\n").Replace(vbCr, "\n").Replace(vbLf, "\n")
        Return s
    End Function

    ' -----------------------------
    ' Parsing / sanitizzazione
    ' -----------------------------

    Public Function ParseInt(value As Object, Optional defaultValue As Integer = 0) As Integer
        If value Is Nothing Then Return defaultValue
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue

        Dim n As Integer
        If Integer.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        Return defaultValue
    End Function

    Public Function SqlCleanInt(value As Object, Optional defaultValue As Integer = 0) As Integer
        Return ParseInt(value, defaultValue)
    End Function

    Public Function SqlCleanDecimal(value As Object, Optional defaultValue As Decimal = 0D) As Decimal
        If value Is Nothing Then Return defaultValue
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue

        s = s.Trim()

        Dim dec As Decimal
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, dec) Then Return dec
        If Decimal.TryParse(s, NumberStyles.Any, New CultureInfo("it-IT"), dec) Then Return dec

        Return defaultValue
    End Function

    Public Function SafeCsvIds(csv As String) As String
        If String.IsNullOrWhiteSpace(csv) Then Return ""

        Dim parts = csv.Split(","c)
        Dim clean As New System.Collections.Generic.List(Of String)()

        For Each p In parts
            Dim n As Integer
            If Integer.TryParse(p.Trim(), n) Then
                clean.Add(n.ToString(CultureInfo.InvariantCulture))
            End If
        Next

        Return String.Join(",", clean)
    End Function

    Public Function SqlEscapeLike(value As String) As String
        If value Is Nothing Then Return ""
        Return Regex.Replace(value, "([\[\]%_])", "[$1]")
    End Function

End Module
