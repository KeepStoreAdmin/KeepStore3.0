Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.Caching
Imports System.Configuration
Imports MySql.Data.MySqlClient

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
        Dim csp As String =
            "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; " &
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

    Public Function Js(value As Object) As String
        Dim s As String = Convert.ToString(value)
        If s Is Nothing Then Return ""
        s = s.Replace("\", "\\").Replace("'", "\'").Replace("""", "\""")
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
            If Integer.TryParse(p.Trim(), n) Then clean.Add(n.ToString(CultureInfo.InvariantCulture))
        Next
        Return String.Join(",", clean)
    End Function

    Public Function SqlEscapeLike(value As String) As String
        If value Is Nothing Then Return ""
        Return Regex.Replace(value, "([\[\]%_])", "[$1]")
    End Function

    ' ==========================
' Analytics GET logging robusto
' ==========================
Public Sub LogAnalyticsQueryStringGet(request As HttpRequest, pageName As String)
    If request Is Nothing Then Exit Sub
    If String.IsNullOrWhiteSpace(pageName) Then pageName = "page"

    ' Solo GET (analytics). Nessuna write su POST qui.
    If Not request.HttpMethod.Equals("GET", StringComparison.OrdinalIgnoreCase) Then Exit Sub

    ' Skip crawler/bot (best effort)
    Try
        If request.Browser IsNot Nothing AndAlso request.Browser.Crawler Then Exit Sub
    Catch
        ' ignore
    End Try

    ' Non loggare richieste che contengono parametri tipici di azione (state change)
    Dim actionKeys As String() = {"del", "delete", "remove", "removeall", "add", "apply", "save", "op", "action"}
    For Each k In actionKeys
        If Not String.IsNullOrEmpty(Convert.ToString(request.QueryString(k))) Then Exit Sub
    Next

    ' Allowlist parametri "navigazione/filtri" (autodiscovery: registra solo quelli presenti)
    Dim allowed As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "q", "s", "sg", "st", "ct", "tp", "gr", "mr", "inpromo", "dispo", "spedgratis",
        "page", "p", "sort", "ord", "view"
    }

    Dim sb As New StringBuilder()
    sb.Append(pageName).Append("|")

    Dim any As Boolean = False
    Dim keys As String() = request.QueryString.AllKeys
    If keys Is Nothing OrElse keys.Length = 0 Then Exit Sub

    For Each key As String In keys
        If String.IsNullOrWhiteSpace(key) Then Continue For
        If Not allowed.Contains(key) Then Continue For

        Dim raw As String = Convert.ToString(request.QueryString(key))
        Dim norm As String = NormalizeAnalyticsValue(raw)
        If String.IsNullOrEmpty(norm) Then Continue For

        If any Then sb.Append("&")
        sb.Append(key).Append("=").Append(norm)
        any = True
    Next

    If Not any Then Exit Sub

    Dim payload As String = sb.ToString()

    ' Limite colonna legacy (QString tipicamente 250/255)
    If payload.Length > 250 Then payload = payload.Substring(0, 250)

    ' Rate-limit per IP (max 30 log/min per IP)
    Dim ip As String = GetClientIp(request)
    If String.IsNullOrEmpty(ip) Then ip = "0.0.0.0"

    If Not RateLimitIp(ip, 30) Then Exit Sub

    ' Deduplica (stesso ip+payload per 10 minuti)
    Dim dedupeKey As String = "qslog:" & HashKey(ip & "|" & payload)
    If HttpRuntime.Cache(dedupeKey) IsNot Nothing Then Exit Sub
    HttpRuntime.Cache.Insert(
        dedupeKey, "1", Nothing,
        DateTime.UtcNow.AddMinutes(10),
        Cache.NoSlidingExpiration
    )

    ' Insert parametrizzato
    Try
        Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Using conn As New MySqlConnection(cs)
            conn.Open()
            Using cmd As New MySqlCommand("INSERT INTO query_string (QString) VALUES (?qs)", conn)
                cmd.Parameters.Add("?qs", MySqlDbType.VarChar, 250).Value = payload
                cmd.ExecuteNonQuery()
            End Using
        End Using
    Catch
        ' Analytics must never break the page
    End Try
End Sub

Private Function NormalizeAnalyticsValue(value As String) As String
    If String.IsNullOrEmpty(value) Then Return ""

    Dim v As String = value

    ' Decode best-effort
    Try
        v = HttpUtility.UrlDecode(v)
    Catch
        ' ignore
    End Try
    Try
        v = HttpUtility.HtmlDecode(v)
    Catch
        ' ignore
    End Try

    v = v.Trim()
    If v.Length = 0 Then Return ""

    ' Hard filters: evita payload HTML/JS/URL
    Dim low As String = v.ToLowerInvariant()
    If low.Contains("<") OrElse low.Contains(">") Then Return ""
    If low.Contains("script") OrElse low.Contains("onerror") OrElse low.Contains("onload") Then Return ""
    If low.Contains("http://") OrElse low.Contains("https://") Then Return ""

    ' Evita email (PII)
    If v.Contains("@") Then Return ""

    ' Normalizza spazi
    v = Regex.Replace(v, "\s+", " ").Trim()

    ' Permetti: lettere/numeri/spazio e pochi separatori utili ai filtri
    ' (Unicode letters + digits)
    v = Regex.Replace(v, "[^\p{L}\p{Nd}\s\-\_\.\,\:\|\/]", "")

    ' Limite per valore
    If v.Length > 80 Then v = v.Substring(0, 80)

    Return v
End Function

Private Function GetClientIp(request As HttpRequest) As String
    If request Is Nothing Then Return ""
    Dim xff As String = Convert.ToString(request.Headers("X-Forwarded-For"))
    If Not String.IsNullOrEmpty(xff) Then
        Dim first As String = xff.Split(","c)(0).Trim()
        If first.Length > 0 Then Return first
    End If
    Return Convert.ToString(request.UserHostAddress)
End Function

Private Function RateLimitIp(ip As String, maxPerMinute As Integer) As Boolean
    Try
        Dim key As String = "qslogip:" & ip
        Dim obj = HttpRuntime.Cache(key)
        Dim n As Integer = 0
        If obj IsNot Nothing Then
            Integer.TryParse(Convert.ToString(obj), n)
        End If
        If n >= maxPerMinute Then Return False

        HttpRuntime.Cache.Insert(
            key, (n + 1).ToString(),
            Nothing,
            DateTime.UtcNow.AddMinutes(1),
            Cache.NoSlidingExpiration
        )
        Return True
    Catch
        ' se cache fallisce, non bloccare (ma perderai rate-limit)
        Return True
    End Try
End Function

Private Function HashKey(input As String) As String
    If input Is Nothing Then input = ""
    Using sha As SHA256 = SHA256.Create()
        Dim bytes = Encoding.UTF8.GetBytes(input)
        Dim hash = sha.ComputeHash(bytes)
        ' 24 char bastano per key cache
        Return BitConverter.ToString(hash).Replace("-", "").Substring(0, 24)
    End Using
End Function

End Module
