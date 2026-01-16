Imports System
Imports System.Text
Imports System.Web
Imports System.Configuration
Imports System.Globalization
Imports MySql.Data.MySqlClient

' KeepStore shared security helpers.
' Goal: safe-by-default utilities (SQL parameter safety, output encoding, headers, HTTPS).
Public Module KeepStoreSecurity

    ' ---------------------------
    ' Output encoding helpers
    ' ---------------------------
    Public Function Html(value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Public Function HtmlAttr(value As Object) As String
        Return HttpUtility.HtmlAttributeEncode(Convert.ToString(value))
    End Function

    Public Function Js(value As Object) As String
        Return HttpUtility.JavaScriptStringEncode(Convert.ToString(value))
    End Function

    Public Function Url(value As Object) As String
        Return HttpUtility.UrlEncode(Convert.ToString(value))
    End Function

    ' Backward-compatible aliases used across existing pages (.aspx markup):
    '   H  = HTML encode
    '   HA = HTML attribute encode
    '   U  = URL encode
    '   J  = JavaScript string encode
    Public Function H(value As Object) As String
        Return Html(value)
    End Function

    Public Function HA(value As Object) As String
        Return HtmlAttr(value)
    End Function

    Public Function U(value As Object) As String
        Return Url(value)
    End Function

    Public Function J(value As Object) As String
        Return Js(value)
    End Function

    ' ---------------------------
    ' Input cleaning / parsing
    ' ---------------------------
    Public Function SqlCleanInt(value As Object,
                               Optional defaultValue As Integer = 0,
                               Optional minValue As Integer = Integer.MinValue,
                               Optional maxValue As Integer = Integer.MaxValue) As Integer
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue
        s = s.Trim()

        Dim n As Integer
        ' Prefer invariant parsing; fall back to current culture.
        If Integer.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, n) OrElse Integer.TryParse(s, n) Then
            If n < minValue Then Return minValue
            If n > maxValue Then Return maxValue
            Return n
        End If

        Return defaultValue
    End Function

    Public Function SqlCleanDecimal(value As Object,
                                   Optional defaultValue As Decimal = 0D,
                                   Optional minValue As Decimal = Decimal.MinValue,
                                   Optional maxValue As Decimal = Decimal.MaxValue) As Decimal
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue
        s = s.Trim()

        Dim d As Decimal
        ' Invariant first
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return ClampDecimal(d, minValue, maxValue)
        End If

        ' it-IT fallback (common in input)
        Try
            Dim it As New CultureInfo("it-IT")
            If Decimal.TryParse(s, NumberStyles.Any, it, d) Then
                Return ClampDecimal(d, minValue, maxValue)
            End If
        Catch
        End Try

        ' Current culture fallback
        If Decimal.TryParse(s, d) Then
            Return ClampDecimal(d, minValue, maxValue)
        End If

        Return defaultValue
    End Function

    Private Function ClampDecimal(d As Decimal, minValue As Decimal, maxValue As Decimal) As Decimal
        If d < minValue Then Return minValue
        If d > maxValue Then Return maxValue
        Return d
    End Function

    ' Builds a comma-separated list of positive integer ids, safe for SQL IN(...)
    ' Use only when parameter arrays are not feasible.
    Public Function SafeCsvIds(csv As String, Optional maxItems As Integer = 100) As String
        If String.IsNullOrWhiteSpace(csv) Then Return ""
        Dim parts As String() = csv.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        Dim outParts As New System.Collections.Generic.List(Of String)()

        For Each p As String In parts
            Dim n As Integer
            If Integer.TryParse(p.Trim(), n) AndAlso n > 0 Then
                outParts.Add(n.ToString(CultureInfo.InvariantCulture))
                If outParts.Count >= maxItems Then Exit For
            End If
        Next

        Return String.Join(",", outParts.ToArray())
    End Function

    ' Escapes a value for safe inclusion inside MySQL string literals within LIKE patterns.
    ' Prefer parameters, but when a LIKE needs escaping this is useful.
    Public Function SqlEscapeLike(value As String, Optional maxLen As Integer = 120) As String
        If value Is Nothing Then Return ""
        Dim v As String = value.Trim()
        If v.Length > maxLen Then v = v.Substring(0, maxLen)
        Return MySqlHelper.EscapeString(v)
    End Function

    ' ---------------------------
    ' HTTPS + headers hardening
    ' ---------------------------
    Public Sub RequireHttps(req As HttpRequest, resp As HttpResponse, Optional enableHsts As Boolean = False)
        If req Is Nothing OrElse resp Is Nothing Then Exit Sub

        Dim isHttps As Boolean = req.IsSecureConnection
        Dim xfProto As String = Convert.ToString(req.Headers("X-Forwarded-Proto"))
        If Not String.IsNullOrEmpty(xfProto) AndAlso String.Equals(xfProto, "https", StringComparison.OrdinalIgnoreCase) Then
            isHttps = True
        End If

        If enableHsts AndAlso isHttps Then
            ' 1 year + include subdomains
            Try
                resp.Headers("Strict-Transport-Security") = "max-age=31536000; includeSubDomains"
            Catch
            End Try
        End If

        If isHttps Then Exit Sub

        ' Avoid redirect loops on local dev.
        If req.IsLocal Then Exit Sub

        ' Best-effort redirect to HTTPS for idempotent methods.
        Dim m As String = Convert.ToString(req.HttpMethod)
        If String.Equals(m, "GET", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(m, "HEAD", StringComparison.OrdinalIgnoreCase) Then
            Dim url As Uri = req.Url
            Dim httpsUrl As String = "https://" & url.Host
            httpsUrl &= url.PathAndQuery

            Try
                resp.Clear()
                resp.StatusCode = 301
                resp.StatusDescription = "Moved Permanently"
                resp.AddHeader("Location", httpsUrl)
                HttpContext.Current.ApplicationInstance.CompleteRequest()
            Catch
                Try
                    resp.Redirect(httpsUrl, True)
                Catch
                End Try
            End Try
        Else
            ' For POST/PUT etc, do not redirect automatically.
            Try
                resp.StatusCode = 403
                resp.Write("HTTPS required")
                HttpContext.Current.ApplicationInstance.CompleteRequest()
            Catch
            End Try
        End If
    End Sub

    Public Sub AddSecurityHeaders(resp As HttpResponse)
        If resp Is Nothing Then Exit Sub

        Try
            If String.IsNullOrEmpty(resp.Headers("X-Content-Type-Options")) Then
                resp.Headers("X-Content-Type-Options") = "nosniff"
            End If

            If String.IsNullOrEmpty(resp.Headers("X-Frame-Options")) Then
                resp.Headers("X-Frame-Options") = "SAMEORIGIN"
            End If

            If String.IsNullOrEmpty(resp.Headers("Referrer-Policy")) Then
                resp.Headers("Referrer-Policy") = "strict-origin-when-cross-origin"
            End If

            If String.IsNullOrEmpty(resp.Headers("X-XSS-Protection")) Then
                resp.Headers("X-XSS-Protection") = "0"
            End If

            If String.IsNullOrEmpty(resp.Headers("Permissions-Policy")) Then
                resp.Headers("Permissions-Policy") = "geolocation=(), microphone=(), camera=()"
            End If

            ' NOTE: CSP va tarata sul sito; questa è una base permissiva per non rompere il template.
            If String.IsNullOrEmpty(resp.Headers("Content-Security-Policy")) Then
                resp.Headers("Content-Security-Policy") = "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: https:; frame-ancestors 'self';"
            End If
        Catch
        End Try
    End Sub

    ' ---------------------------
    ' Analytics GET logging helpers
    ' ---------------------------
    Public Function BuildAnalyticsQueryString(req As HttpRequest, allowKeys As String(), Optional maxLen As Integer = 250) As String
        If req Is Nothing OrElse allowKeys Is Nothing OrElse allowKeys.Length = 0 Then Return ""

        Dim sb As New StringBuilder()

        For Each k As String In allowKeys
            Dim raw As String = Convert.ToString(req.QueryString(k))
            If String.IsNullOrWhiteSpace(raw) Then Continue For

            Dim v As String = SanitizeForLog(raw, 80)
            If v.Length = 0 Then Continue For

            If sb.Length > 0 Then sb.Append(" ")
            sb.Append(k).Append("=").Append(v)

            If sb.Length >= maxLen Then Exit For
        Next

        Dim out As String = sb.ToString()
        If out.Length > maxLen Then out = out.Substring(0, maxLen)
        Return out
    End Function

    Public Sub TryLogQueryStringToDb(qs As String, Optional connectionStringName As String = "EntropicConnectionString")
        If String.IsNullOrWhiteSpace(qs) Then Exit Sub

        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings(connectionStringName).ConnectionString
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As New MySqlCommand("INSERT INTO query_string (QString) VALUES (?qs)", conn)
                    cmd.Parameters.Add("?qs", MySqlDbType.VarChar).Value = qs
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch
            ' analytics non deve mai rompere la pagina
        End Try
    End Sub

    Public Function SanitizeForLog(value As String, Optional maxLen As Integer = 250) As String
        If value Is Nothing Then Return ""

        Dim v As String = value
        Try
            v = HttpUtility.UrlDecode(v)
        Catch
        End Try
        Try
            v = HttpUtility.HtmlDecode(v)
        Catch
        End Try

        v = v.Replace(ChrW(0), "")
        v = v.Replace(ChrW(10), " ").Replace(ChrW(13), " ")
        v = v.Trim()

        If v.Length > maxLen Then v = v.Substring(0, maxLen)
        Return v
    End Function

End Module
