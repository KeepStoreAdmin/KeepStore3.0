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
            Dim target As String = builder.Uri.ToString()

            Try
                resp.Clear()
            Catch
            End Try

            Dim method As String = Convert.ToString(req.HttpMethod)
            If method.Equals("POST", StringComparison.OrdinalIgnoreCase) Then
                resp.StatusCode = 303
                resp.StatusDescription = "See Other"
            Else
                resp.StatusCode = 301
                resp.StatusDescription = "Moved Permanently"
            End If

            resp.RedirectLocation = target
            SafeSetHeader(resp, "Location", target)

            Try
                resp.SuppressContent = True
            Catch
            End Try

            Try
                resp.TrySkipIisCustomErrors = True
            Catch
            End Try

            Dim ctx As HttpContext = HttpContext.Current
            If ctx IsNot Nothing AndAlso ctx.ApplicationInstance IsNot Nothing Then
                ctx.ApplicationInstance.CompleteRequest()
            End If
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

        Try
            If TypeOf value Is Decimal OrElse TypeOf value Is Double OrElse TypeOf value Is Single OrElse
               TypeOf value Is Integer OrElse TypeOf value Is Long OrElse TypeOf value Is Short Then
                Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
            End If
        Catch
        End Try

        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue

        s = s.Trim().Replace("€", "").Replace(" ", "")

        Dim dec As Decimal
        Dim normalized As String = NormalizeDecimalString(s)
        If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, dec) Then Return dec
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), dec) Then Return dec
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, dec) Then Return dec

        Return defaultValue
    End Function

    Private Function NormalizeDecimalString(value As String) As String
        Dim s As String = StripMoneyText(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        Dim comma As Integer = s.LastIndexOf(","c)
        Dim dot As Integer = s.LastIndexOf("."c)

        If comma >= 0 AndAlso dot >= 0 Then
            If comma > dot Then
                s = s.Replace(".", "").Replace(","c, "."c)
            Else
                s = s.Replace(",", "")
            End If
        ElseIf dot >= 0 Then
            s = NormalizeSingleSeparator(s, "."c)
        ElseIf comma >= 0 Then
            s = NormalizeSingleSeparator(s, ","c)
        End If

        Return s
    End Function

    Private Function StripMoneyText(value As String) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Trim()
        s = s.Replace(ChrW(8364), "")
        s = s.Replace(ChrW(226) & ChrW(8218) & ChrW(172), "")
        s = s.Replace("&euro;", "").Replace("&#8364;", "")
        s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
        s = s.Replace(ChrW(8722), "-")
        s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "")
        s = s.Replace(" ", "").Replace("'", "")

        Return s
    End Function

    Private Function NormalizeSingleSeparator(value As String, separator As Char) As String
        Dim parts() As String = value.Split(separator)
        If parts.Length <= 1 Then Return value

        Dim last As String = parts(parts.Length - 1)

        If parts.Length > 2 Then
            If last.Length > 0 AndAlso last.Length <= 2 Then
                Return JoinAllButLast(parts) & "." & last
            End If

            Return String.Join("", parts)
        End If

        If last.Length = 3 Then
            Return parts(0) & last
        End If

        If separator = ","c Then
            Return parts(0) & "." & last
        End If

        Return value
    End Function

    Private Function JoinAllButLast(parts() As String) As String
        Dim output As String = ""
        For i As Integer = 0 To parts.Length - 2
            output &= parts(i)
        Next
        Return output
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
