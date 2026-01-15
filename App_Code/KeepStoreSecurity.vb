Imports System
Imports System.Collections.Generic
Imports System.Collections.Specialized
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Diagnostics

Public Module KeepStoreSecurity

    ' ==========================================================
    '  PARSING / CLEANING (SQL-safe)
    ' ==========================================================

    Public Function SqlCleanInt(value As Object, Optional defaultValue As Integer = 0) As Integer
        Try
            If value Is Nothing Then Return defaultValue
            Dim s As String = Convert.ToString(value)
            If String.IsNullOrWhiteSpace(s) Then Return defaultValue

            Dim n As Integer
            ' Compatibilità VB2012: NumberStyles/CultureInfo via Imports System.Globalization
            If Integer.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n

            ' Fallback: estrai prima sequenza numerica (anche se sporca)
            Dim m As Match = Regex.Match(s, "-?\d+")
            If m.Success AndAlso Integer.TryParse(m.Value, NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n

            Return defaultValue
        Catch
            Return defaultValue
        End Try
    End Function

    Public Function SqlCleanDecimal(value As Object, Optional defaultValue As Decimal = 0D) As Decimal
        Try
            If value Is Nothing Then Return defaultValue
            Dim s As String = Convert.ToString(value)
            If String.IsNullOrWhiteSpace(s) Then Return defaultValue

            Dim d As Decimal
            ' Prima prova InvariantCulture (.)
            If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
            ' Poi prova it-IT (,)
            If Decimal.TryParse(s, NumberStyles.Any, New CultureInfo("it-IT"), d) Then Return d

            ' Fallback: normalizza virgola/punto
            Dim normalized As String = s.Trim().Replace(",", ".")
            If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

            Return defaultValue
        Catch
            Return defaultValue
        End Try
    End Function

    ' CSV di interi: "1,2,3" -> solo numeri, massimo maxItems
    Public Function SqlCleanCsvInt(value As Object, Optional maxItems As Integer = 200) As String
        If value Is Nothing Then Return ""
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        Dim parts As String() = s.Split(New Char() {","c, ";"c, "|"c}, StringSplitOptions.RemoveEmptyEntries)
        Dim clean As New List(Of String)()

        For Each p As String In parts
            Dim n As Integer
            If Integer.TryParse(p.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then
                clean.Add(n.ToString(CultureInfo.InvariantCulture))
                If clean.Count >= maxItems Then Exit For
            End If
        Next

        Return String.Join(",", clean.ToArray())
    End Function


    ' ==========================================================
    '  OUTPUT ENCODING (XSS-safe)
    ' ==========================================================

    Public Function H(value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Public Function HA(value As Object) As String
        ' Encoding per attributi HTML (alt, title, data-*, ecc.)
        Return HttpUtility.HtmlAttributeEncode(Convert.ToString(value))
    End Function

    Public Function U(value As Object) As String
        Return HttpUtility.UrlEncode(Convert.ToString(value))
    End Function


    ' ==========================================================
    '  SECURITY HEADERS + HTTPS
    ' ==========================================================

    Public Sub AddSecurityHeaders(resp As HttpResponse)
        If resp Is Nothing Then Return

        Try
            ' X-Content-Type-Options
            SafeSetHeader(resp, "X-Content-Type-Options", "nosniff")

            ' Clickjacking
            SafeSetHeader(resp, "X-Frame-Options", "SAMEORIGIN")

            ' Referrer Policy
            SafeSetHeader(resp, "Referrer-Policy", "strict-origin-when-cross-origin")

            ' Basic CSP (conservativa, non rompe layout tipico)
            ' Nota: se in futuro usi JS inline, potresti dover allentare.
            SafeSetHeader(resp, "Content-Security-Policy", "default-src 'self' https: data:; img-src 'self' https: data:; style-src 'self' https: 'unsafe-inline'; script-src 'self' https: 'unsafe-inline'")

            ' Permissions Policy (minima)
            SafeSetHeader(resp, "Permissions-Policy", "geolocation=(), microphone=(), camera=()")
        Catch
            ' non bloccare la pagina per colpa headers
        End Try
    End Sub

    Private Sub SafeSetHeader(resp As HttpResponse, name As String, value As String)
        Try
            resp.Headers.Remove(name)
        Catch
        End Try
        Try
            resp.Headers.Set(name, value)
        Catch
        End Try
    End Sub

    Public Sub RequireHttps(req As HttpRequest, resp As HttpResponse)
        If req Is Nothing OrElse resp Is Nothing Then Return

        ' Se sei dietro proxy/CDN: gestisci anche X-Forwarded-Proto
        Dim xfproto As String = ""
        Try
            xfproto = Convert.ToString(req.Headers("X-Forwarded-Proto"))
        Catch
        End Try

        Dim isHttps As Boolean = req.IsSecureConnection OrElse String.Equals(xfproto, "https", StringComparison.OrdinalIgnoreCase)

        If Not isHttps Then
            Try
                Dim url As Uri = req.Url
                Dim b As New UriBuilder(url)
                b.Scheme = Uri.UriSchemeHttps
                b.Port = -1 ' default 443
                resp.Redirect(b.Uri.ToString(), True)
            Catch
                ' se non riesce, non bloccare
            End Try
        End If
    End Sub


    ' ==========================================================
    '  GET ANALYTICS LOGGING (robusto, senza supposizioni)
    ' ==========================================================
    ' Obiettivo: loggare querystring anche su GET per analytics,
    ' senza dipendere da parametri "noti".
    '
    ' - Logga SOLO GET
    ' - Sanitizza valori
    ' - Denylist chiavi sensibili (token, password, auth, ecc.)
    ' - Limita lunghezze per evitare log injection / DoS
    ' - Fallback: scrive in App_Data (di solito scrivibile in ASP.NET)
    ' ==========================================================

    Public Sub LogGetAnalytics(req As HttpRequest, pageKey As String)
        If req Is Nothing Then Return
        If Not String.Equals(req.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase) Then Return

        Dim qs As NameValueCollection = req.QueryString
        If qs Is Nothing OrElse qs.Count = 0 Then Return

        Dim pairs As New List(Of String)()

        For Each k As String In qs.AllKeys
            If String.IsNullOrWhiteSpace(k) Then Continue For
            If IsSensitiveKey(k) Then Continue For

            Dim v As String = qs(k)
            If v Is Nothing Then Continue For

            Dim safeKey As String = SanitizeForLog(k, 60)
            Dim safeVal As String = SanitizeForLog(v, 250)

            pairs.Add(safeKey & "=" & safeVal)
            If pairs.Count >= 30 Then Exit For ' hard cap
        Next

        If pairs.Count = 0 Then Return

        Dim ip As String = GetClientIp(req)
        Dim line As String = DateTime.UtcNow.ToString("o") & vbTab & SanitizeForLog(pageKey, 40) & vbTab & SanitizeForLog(ip, 80) & vbTab & String.Join("&", pairs.ToArray())

        AppendAnalyticsLine(line)
    End Sub

    Private Function IsSensitiveKey(key As String) As Boolean
        Dim k As String = key.Trim().ToLowerInvariant()

        ' Denylist tipica: evita di loggare credenziali / token / session
        If k.Contains("password") Then Return True
        If k.Contains("passwd") Then Return True
        If k.Contains("pwd") Then Return True
        If k.Contains("token") Then Return True
        If k.Contains("auth") Then Return True
        If k.Contains("session") Then Return True
        If k.Contains("cookie") Then Return True
        If k.Contains("apikey") OrElse k.Contains("api_key") Then Return True
        If k.StartsWith("__", StringComparison.Ordinal) Then Return True ' riservati ASP.NET

        Return False
    End Function

    Private Function SanitizeForLog(value As String, maxLen As Integer) As String
        If value Is Nothing Then Return ""
        Dim s As String = value

        ' no CR/LF/TAB (anti log injection)
        s = s.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")

        ' riduci whitespace
        s = Regex.Replace(s, "\s+", " ").Trim()

        ' taglia
        If maxLen > 0 AndAlso s.Length > maxLen Then s = s.Substring(0, maxLen)

        ' sostituisci caratteri “strani” con _
        ' (manteniamo lettere/numeri/spazi e pochi simboli utili)
        s = Regex.Replace(s, "[^\w\s\-\.\,\:\@\+\/\=\(\)\[\]]", "_")

        Return s
    End Function

    Private Sub AppendAnalyticsLine(line As String)
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx Is Nothing Then
                Trace.WriteLine("KS_ANALYTICS_GET: " & line)
                Return
            End If

            Dim path As String = ctx.Server.MapPath("~/App_Data/ks-analytics-get.log")

            SyncLock GetType(KeepStoreSecurity)
                File.AppendAllText(path, line & Environment.NewLine, Encoding.UTF8)
            End SyncLock

        Catch ex As Exception
            ' fallback: non rompere mai la pagina
            Try
                Trace.WriteLine("KS_ANALYTICS_GET_ERR: " & ex.Message)
            Catch
            End Try
        End Try
    End Sub

    Public Function GetClientIp(req As HttpRequest) As String
        Try
            Dim xff As String = Convert.ToString(req.Headers("X-Forwarded-For"))
            If Not String.IsNullOrWhiteSpace(xff) Then
                ' primo IP della catena
                Dim parts As String() = xff.Split(","c)
                If parts IsNot Nothing AndAlso parts.Length > 0 Then
                    Return parts(0).Trim()
                End If
            End If
        Catch
        End Try

        Try
            Return Convert.ToString(req.UserHostAddress)
        Catch
            Return ""
        End Try
    End Function

End Module
