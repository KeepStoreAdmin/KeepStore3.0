Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Security
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient

' Sitemap generator with:
' - Optional file cache in ~/App_Data/Sitemaps (served dynamically by sitemap.aspx)
' - Optional audit mode: /sitemap.aspx?audit=1&token=...
' - Optional robots.txt Disallow alignment (URLs matching Disallow are excluded)
Public Class sitemap
    Inherits Page

    ' === Config keys (web.config / appSettings) ===
    Private Const KEY_AUDIT_ENABLED As String = "KeepStore.Sitemap.Audit.Enabled"
    Private Const KEY_AUDIT_TOKEN As String = "KeepStore.Sitemap.Audit.Token"

    Private Const KEY_CACHE_ENABLED As String = "KeepStore.Sitemap.FileCache.Enabled"
    Private Const KEY_CACHE_PATH As String = "KeepStore.Sitemap.FileCache.Path"
    Private Const KEY_CACHE_TTL As String = "KeepStore.Sitemap.FileCache.TtlMinutes"

    Private Const KEY_MYSQL_VIEW_ARTICOLI As String = "KeepStore.Sitemap.MySql.ViewArticoli"
    Private Const KEY_MYSQL_VIEW_FACETS As String = "KeepStore.Sitemap.MySql.ViewCategorie"
    Private Const KEY_MYSQL_CONNNAME As String = "KeepStore.Sitemap.MySql.ConnectionStringName"

    Private Const KEY_ROBOTS_ENABLED As String = "KeepStore.Sitemap.Robots.Enabled"
    Private Const KEY_ROBOTS_UA As String = "KeepStore.Sitemap.Robots.UserAgent"

    ' === Runtime state ===
    Private _auditEnabled As Boolean
    Private _auditToken As String

    Private _fileCacheEnabled As Boolean
    Private _fileCachePath As String
    Private _fileCacheTtlMinutes As Integer

    Private _mysqlViewArticoli As String
    Private _mysqlViewFacets As String
    Private _mysqlConnName As String

    Private _robotsEnabled As Boolean
    Private _robotsUserAgent As String
    Private _disallowRegex As List(Of Regex)

    Protected Overrides Sub OnInit(e As EventArgs)
        MyBase.OnInit(e)
        InitializeSettings()
        ' Pre-load robots rules (never throws to caller)
        _disallowRegex = SafeLoadDisallowRegex()
    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim host As String = GetHostBase()
        Dim isAuditReq As Boolean = IsAuditRequest()

        If isAuditReq Then
            ' Audit should be able to surface exceptions even when customErrors is RemoteOnly.
            Response.TrySkipIisCustomErrors = True
            Response.Clear()
            Response.ContentType = "text/plain; charset=utf-8"

            If Not IsAuditAllowed() Then
                Response.StatusCode = 403
                Response.Write("403 Forbidden" & Environment.NewLine & "Audit is disabled or token invalid.")
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If

            Try
                Dim report As String = BuildAuditReport(host)
                Response.StatusCode = 200
                Response.Write(report)
            Catch ex As Exception
                Response.StatusCode = 500
                Response.Write("AUDIT ERROR: " & ex.GetType().FullName & Environment.NewLine)
                Response.Write(ex.Message & Environment.NewLine & Environment.NewLine)
                Response.Write(ex.StackTrace)
            End Try

            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        ' Normal sitemap XML
        Response.TrySkipIisCustomErrors = True
        Response.Clear()
        Response.ContentType = "application/xml; charset=utf-8"

        Try
            Dim xml As String = Nothing

            ' Try cache first
            If _fileCacheEnabled Then
                xml = TryReadCache(host)
            End If

            If String.IsNullOrEmpty(xml) Then
                xml = BuildXml(host)

                ' Write cache best-effort (never fail request on cache errors)
                If _fileCacheEnabled Then
                    TryWriteCache(host, xml)
                End If
            End If

            Response.StatusCode = 200
            Response.Write(xml)
        Catch ex As Exception
            ' Never expose details publicly; keep generic.
            Response.StatusCode = 500
            Response.ContentType = "text/plain; charset=utf-8"
            Response.Write("Internal Server Error")
        End Try

        Context.ApplicationInstance.CompleteRequest()
    End Sub

    ' =========================
    ' Settings
    ' =========================
    Private Sub InitializeSettings()
        _auditEnabled = GetBool(KEY_AUDIT_ENABLED, False)
        _auditToken = GetString(KEY_AUDIT_TOKEN, "")

        _fileCacheEnabled = GetBool(KEY_CACHE_ENABLED, True)
        _fileCachePath = GetString(KEY_CACHE_PATH, "~/App_Data/Sitemaps")
        _fileCacheTtlMinutes = GetInt(KEY_CACHE_TTL, 720)

        _mysqlViewArticoli = GetString(KEY_MYSQL_VIEW_ARTICOLI, "").Trim()
        _mysqlViewFacets = GetString(KEY_MYSQL_VIEW_FACETS, "").Trim()
        _mysqlConnName = GetString(KEY_MYSQL_CONNNAME, "EntropicConnectionString").Trim()

        _robotsEnabled = GetBool(KEY_ROBOTS_ENABLED, True)
        _robotsUserAgent = GetString(KEY_ROBOTS_UA, "*").Trim()
        If String.IsNullOrEmpty(_robotsUserAgent) Then _robotsUserAgent = "*"
    End Sub

    Private Function GetString(key As String, def As String) As String
        Dim v As String = Convert.ToString(ConfigurationManager.AppSettings(key))
        If String.IsNullOrEmpty(v) Then Return def
        Return v
    End Function

    Private Function GetBool(key As String, def As Boolean) As Boolean
        Dim v As String = Convert.ToString(ConfigurationManager.AppSettings(key))
        If String.IsNullOrEmpty(v) Then Return def
        v = v.Trim().ToLowerInvariant()
        If v = "1" OrElse v = "true" OrElse v = "yes" Then Return True
        If v = "0" OrElse v = "false" OrElse v = "no" Then Return False
        Return def
    End Function

    Private Function GetInt(key As String, def As Integer) As Integer
        Dim v As String = Convert.ToString(ConfigurationManager.AppSettings(key))
        Dim n As Integer = 0
        If Integer.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        Return def
    End Function

    ' =========================
    ' Audit
    ' =========================
    Private Function IsAuditRequest() As Boolean
        Dim q As String = Convert.ToString(Request.QueryString("audit"))
        If String.IsNullOrEmpty(q) Then Return False
        q = q.Trim()
        Return (q = "1" OrElse q.Equals("true", StringComparison.OrdinalIgnoreCase))
    End Function

    Private Function IsAuditAllowed() As Boolean
        If Not _auditEnabled Then Return False

        ' Local requests allowed (useful for server-side debugging)
        Try
            If Request IsNot Nothing AndAlso Request.IsLocal Then Return True
        Catch
            ' ignore
        End Try

        If String.IsNullOrEmpty(_auditToken) OrElse _auditToken.Length < 12 Then Return False

        Dim t As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(t) Then Return False

        Return SecureEquals(t, _auditToken)
    End Function

    Private Function SecureEquals(a As String, b As String) As Boolean
        If a Is Nothing OrElse b Is Nothing Then Return False
        Dim ba() As Byte = Encoding.UTF8.GetBytes(a)
        Dim bb() As Byte = Encoding.UTF8.GetBytes(b)
        If ba.Length <> bb.Length Then Return False
        Dim diff As Integer = 0
        For i As Integer = 0 To ba.Length - 1
            diff = diff Or (ba(i) Xor bb(i))
        Next
        Return diff = 0
    End Function

    Private Function BuildAuditReport(host As String) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("=== KeepStore Sitemap Audit ===")
        sb.AppendLine("Time (UTC): " & DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture))
        sb.AppendLine("Host: " & host)
        sb.AppendLine("")
        sb.AppendLine("Audit.Enabled: " & _auditEnabled.ToString())
        sb.AppendLine("Cache.Enabled: " & _fileCacheEnabled.ToString())
        sb.AppendLine("Cache.Path: " & _fileCachePath)
        sb.AppendLine("Cache.TtlMinutes: " & _fileCacheTtlMinutes.ToString(CultureInfo.InvariantCulture))
        sb.AppendLine("MySql.ConnName: " & _mysqlConnName)
        sb.AppendLine("MySql.ViewArticoli: " & _mysqlViewArticoli)
        sb.AppendLine("MySql.ViewCategorie: " & _mysqlViewFacets)
        sb.AppendLine("Robots.Enabled: " & _robotsEnabled.ToString())
        sb.AppendLine("Robots.UserAgent: " & _robotsUserAgent)
        sb.AppendLine("Robots.DisallowRegex.Count: " & If(_disallowRegex Is Nothing, 0, _disallowRegex.Count).ToString(CultureInfo.InvariantCulture))
        sb.AppendLine("")

        ' Cache status
        If _fileCacheEnabled Then
            Dim info As String = DescribeCache(host)
            sb.AppendLine(info)
            sb.AppendLine("")
        End If

        ' Build full list and filtered list
        Dim allUrls As List(Of SitemapUrl) = BuildUrlList(host, includeRobotsDisallowed:=True)
        Dim filtered As New List(Of SitemapUrl)()
        Dim disallowed As New List(Of SitemapUrl)()

        For Each u As SitemapUrl In allUrls
            If IsDisallowedByRobots(u.Loc) Then
                disallowed.Add(u)
            Else
                filtered.Add(u)
            End If
        Next

        sb.AppendLine("URL Counts")
        sb.AppendLine("  Total (before robots filter): " & allUrls.Count.ToString(CultureInfo.InvariantCulture))
        sb.AppendLine("  Robots disallowed: " & disallowed.Count.ToString(CultureInfo.InvariantCulture))
        sb.AppendLine("  Final (after filter): " & filtered.Count.ToString(CultureInfo.InvariantCulture))
        sb.AppendLine("")

        If disallowed.Count > 0 Then
            sb.AppendLine("Disallowed URLs (first 200):")
            Dim n As Integer = Math.Min(200, disallowed.Count)
            For i As Integer = 0 To n - 1
                sb.AppendLine("  - " & disallowed(i).Loc)
            Next
            If disallowed.Count > 200 Then sb.AppendLine("  ... (" & (disallowed.Count - 200).ToString(CultureInfo.InvariantCulture) & " more)")
            sb.AppendLine("")
        End If

        sb.AppendLine("Sample Final URLs (first 50):")
        Dim m As Integer = Math.Min(50, filtered.Count)
        For i As Integer = 0 To m - 1
            sb.AppendLine("  - " & filtered(i).Loc)
        Next

        Return sb.ToString()
    End Function

    ' =========================
    ' Build XML
    ' =========================
    Private Function BuildXml(host As String) As String
        Dim urls As List(Of SitemapUrl) = BuildUrlList(host, includeRobotsDisallowed:=False)

        ' Sitemaps.org limit
        If urls.Count > 50000 Then
            urls = urls.GetRange(0, 50000)
        End If

        Dim sb As New StringBuilder()
        sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.AppendLine("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

        For Each u As SitemapUrl In urls
            sb.AppendLine("  <url>")
            sb.AppendLine("    <loc>" & XmlEscape(u.Loc) & "</loc>")
            If u.LastModUtc.HasValue Then
                sb.AppendLine("    <lastmod>" & u.LastModUtc.Value.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture) & "</lastmod>")
            End If
            If Not String.IsNullOrEmpty(u.ChangeFreq) Then
                sb.AppendLine("    <changefreq>" & XmlEscape(u.ChangeFreq) & "</changefreq>")
            End If
            If Not String.IsNullOrEmpty(u.Priority) Then
                sb.AppendLine("    <priority>" & XmlEscape(u.Priority) & "</priority>")
            End If
            sb.AppendLine("  </url>")
        Next

        sb.AppendLine("</urlset>")
        Return sb.ToString()
    End Function

    Private Function BuildUrlList(host As String, includeRobotsDisallowed As Boolean) As List(Of SitemapUrl)
        Dim urls As New List(Of SitemapUrl)()
        Dim fallbackUtc As DateTime = DateTime.UtcNow

        AddStaticUrls(urls, host, fallbackUtc)
        AddDynamicArticoliUrls(urls, host, fallbackUtc)
        AddDynamicFacetUrls(urls, host, fallbackUtc)

        ' De-dup and (optionally) robots filter
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim out As New List(Of SitemapUrl)()

        For Each u As SitemapUrl In urls
            If u Is Nothing Then Continue For
            If String.IsNullOrEmpty(u.Loc) Then Continue For

            Dim loc As String = NormalizeAbsoluteUrl(host, u.Loc)
            If String.IsNullOrEmpty(loc) Then Continue For

            If Not seen.Add(loc) Then Continue For

            If (Not includeRobotsDisallowed) AndAlso IsDisallowedByRobots(loc) Then
                Continue For
            End If

            u.Loc = loc
            out.Add(u)
        Next

        Return out
    End Function

    Private Sub AddStaticUrls(urls As List(Of SitemapUrl), host As String, fallbackUtc As DateTime)
        ' IMPORTANT: keep these limited and stable. Add more if you have real public pages.
        Dim staticPaths As String() = New String() { _
            "/", _
            "/articoli.aspx", _
            "/categorie.aspx", _
            "/contatti.aspx", _
            "/privacy.aspx", _
            "/faq.aspx" _
        }

        For Each p As String In staticPaths
            urls.Add(New SitemapUrl(host & p, fallbackUtc, "weekly", "0.8"))
        Next
    End Sub

    ' =========================
    ' Dynamic URLs from MySQL views
    ' Expected columns: url (VARCHAR), last_mod (DATETIME/TIMESTAMP nullable)
    ' =========================
    Private Sub AddDynamicArticoliUrls(urls As List(Of SitemapUrl), host As String, fallbackUtc As DateTime)
        If String.IsNullOrEmpty(_mysqlViewArticoli) Then Return
        Dim items As List(Of SitemapUrl) = TryLoadFromView(_mysqlViewArticoli, host, fallbackUtc)
        For Each u As SitemapUrl In items
            u.ChangeFreq = "daily"
            u.Priority = "0.9"
            urls.Add(u)
        Next
    End Sub

    Private Sub AddDynamicFacetUrls(urls As List(Of SitemapUrl), host As String, fallbackUtc As DateTime)
        If String.IsNullOrEmpty(_mysqlViewFacets) Then Return
        Dim items As List(Of SitemapUrl) = TryLoadFromView(_mysqlViewFacets, host, fallbackUtc)
        For Each u As SitemapUrl In items
            u.ChangeFreq = "weekly"
            u.Priority = "0.7"
            urls.Add(u)
        Next
    End Sub

    Private Function TryLoadFromView(viewName As String, host As String, fallbackUtc As DateTime) As List(Of SitemapUrl)
        Dim res As New List(Of SitemapUrl)()

        Dim safeView As String = ValidateSqlIdentifier(viewName)
        If String.IsNullOrEmpty(safeView) Then
            Return res
        End If

        Dim cs As String = Nothing
        Try
            Dim csObj = ConfigurationManager.ConnectionStrings(_mysqlConnName)
            If csObj IsNot Nothing Then cs = csObj.ConnectionString
        Catch
            cs = Nothing
        End Try

        If String.IsNullOrEmpty(cs) Then Return res

        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT url, last_mod FROM " & safeView & " ORDER BY url", conn)
                    cmd.CommandTimeout = 30
                    Using rd As MySqlDataReader = cmd.ExecuteReader()
                        While rd.Read()
                            Dim u As String = SafeDbString(rd, 0)
                            If String.IsNullOrEmpty(u) Then Continue While

                            Dim lmUtc As Nullable(Of DateTime) = Nothing
                            Dim lm As Nullable(Of DateTime) = SafeDbDateTime(rd, 1)
                            If lm.HasValue Then
                                lmUtc = DateTime.SpecifyKind(lm.Value, DateTimeKind.Utc)
                            Else
                                lmUtc = fallbackUtc
                            End If

                            res.Add(New SitemapUrl(u, lmUtc, Nothing, Nothing))
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' On DB errors: keep sitemap alive (audit will show counts, but we don't crash).
        End Try

        Return res
    End Function

    Private Function ValidateSqlIdentifier(name As String) As String
        If String.IsNullOrEmpty(name) Then Return Nothing
        name = name.Trim()
        ' allow schema-qualified: schema.view
        If Not Regex.IsMatch(name, "^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)?$") Then Return Nothing
        Return name
    End Function

    Private Function SafeDbString(rd As MySqlDataReader, ordinal As Integer) As String
        Try
            If rd.IsDBNull(ordinal) Then Return Nothing
            Return Convert.ToString(rd.GetValue(ordinal))
        Catch
            Return Nothing
        End Try
    End Function

    Private Function SafeDbDateTime(rd As MySqlDataReader, ordinal As Integer) As Nullable(Of DateTime)
        Try
            If rd.IsDBNull(ordinal) Then Return Nothing
            Dim v As Object = rd.GetValue(ordinal)
            If TypeOf v Is DateTime Then
                Return CType(v, DateTime)
            End If
            Dim s As String = Convert.ToString(v)
            Dim dt As DateTime
            If DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal Or DateTimeStyles.AdjustToUniversal, dt) Then
                Return dt
            End If
        Catch
        End Try
        Return Nothing
    End Function

    ' =========================
    ' Robots.txt Disallow
    ' =========================
    Private Function SafeLoadDisallowRegex() As List(Of Regex)
        Dim empty As New List(Of Regex)()
        If Not _robotsEnabled Then Return empty

        Try
            Dim robotsPhys As String = Server.MapPath("~/robots.txt")
            If String.IsNullOrEmpty(robotsPhys) OrElse Not File.Exists(robotsPhys) Then
                Return empty
            End If

            Dim lines() As String = File.ReadAllLines(robotsPhys, Encoding.UTF8)

            ' Parse groups
            Dim currentApplies As Boolean = False
            Dim disallowPatterns As New List(Of String)()

            For Each raw As String In lines
                Dim line As String = raw
                If line Is Nothing Then Continue For

                ' strip comments
                Dim hash As Integer = line.IndexOf("#"c)
                If hash >= 0 Then line = line.Substring(0, hash)
                line = line.Trim()
                If line.Length = 0 Then Continue For

                Dim colon As Integer = line.IndexOf(":"c)
                If colon <= 0 Then Continue For

                Dim key As String = line.Substring(0, colon).Trim().ToLowerInvariant()
                Dim val As String = line.Substring(colon + 1).Trim()

                If key = "user-agent" Then
                    Dim ua As String = val.Trim()
                    ' When a new UA is encountered, recompute whether this group applies.
                    currentApplies = UserAgentMatches(ua, _robotsUserAgent)
                ElseIf key = "disallow" Then
                    If currentApplies Then
                        If Not String.IsNullOrEmpty(val) Then
                            disallowPatterns.Add(val)
                        End If
                    End If
                End If
            Next

            Dim regs As New List(Of Regex)()
            For Each p As String In disallowPatterns
                Dim rx As Regex = CompileRobotsPattern(p)
                If rx IsNot Nothing Then regs.Add(rx)
            Next

            Return regs
        Catch
            Return empty
        End Try
    End Function

    Private Function UserAgentMatches(robotsUa As String, targetUa As String) As Boolean
        If String.IsNullOrEmpty(robotsUa) Then Return False
        If robotsUa = "*" Then Return True
        If String.Equals(targetUa, "*", StringComparison.OrdinalIgnoreCase) Then
            ' target is wildcard: accept all groups
            Return True
        End If
        Return robotsUa.Trim().ToLowerInvariant() = targetUa.Trim().ToLowerInvariant()
    End Function

    Private Function CompileRobotsPattern(pattern As String) As Regex
        If String.IsNullOrEmpty(pattern) Then Return Nothing
        pattern = pattern.Trim()
        If pattern = "/" Then
            ' Disallow all
            Return New Regex("^/.*", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
        End If

        Dim anchorEnd As Boolean = False
        If pattern.EndsWith("$", StringComparison.Ordinal) Then
            anchorEnd = True
            pattern = pattern.Substring(0, pattern.Length - 1)
        End If

        ' Escape regex special chars, then unescape '*' wildcards
        Dim escaped As String = Regex.Escape(pattern).Replace("\*", ".*")
        Dim rxPattern As String = "^" & escaped
        If anchorEnd Then rxPattern &= "$"
        Return New Regex(rxPattern, RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
    End Function

    Private Function IsDisallowedByRobots(absUrl As String) As Boolean
        If Not _robotsEnabled Then Return False
        If _disallowRegex Is Nothing OrElse _disallowRegex.Count = 0 Then Return False
        If String.IsNullOrEmpty(absUrl) Then Return False

        Dim pathAndQuery As String = absUrl
        Try
            Dim uri As New Uri(absUrl, UriKind.Absolute)
            pathAndQuery = uri.PathAndQuery
        Catch
            ' keep as-is
        End Try

        For Each rx As Regex In _disallowRegex
            If rx Is Nothing Then Continue For
            If rx.IsMatch(pathAndQuery) Then Return True
        Next

        Return False
    End Function

    ' =========================
    ' Cache
    ' =========================
    Private Function DescribeCache(host As String) As String
        Dim sb As New StringBuilder()
        sb.AppendLine("Cache Status")
        Try
            Dim dirPhys As String = Server.MapPath(_fileCachePath)
            Dim filePhys As String = Path.Combine(dirPhys, GetCacheFileName(host))
            sb.AppendLine("  Dir: " & dirPhys)
            sb.AppendLine("  File: " & filePhys)

            If File.Exists(filePhys) Then
                Dim fi As New FileInfo(filePhys)
                sb.AppendLine("  Exists: True")
                sb.AppendLine("  Size: " & fi.Length.ToString(CultureInfo.InvariantCulture))
                sb.AppendLine("  LastWriteUtc: " & fi.LastWriteTimeUtc.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture))
                sb.AppendLine("  AgeMinutes: " & (DateTime.UtcNow - fi.LastWriteTimeUtc).TotalMinutes.ToString("0.0", CultureInfo.InvariantCulture))
            Else
                sb.AppendLine("  Exists: False")
            End If
        Catch ex As Exception
            sb.AppendLine("  ERROR: " & ex.Message)
        End Try
        Return sb.ToString()
    End Function

    Private Function TryReadCache(host As String) As String
        Try
            Dim dirPhys As String = Server.MapPath(_fileCachePath)
            Dim filePhys As String = Path.Combine(dirPhys, GetCacheFileName(host))

            If Not File.Exists(filePhys) Then Return Nothing

            Dim age As TimeSpan = DateTime.UtcNow - File.GetLastWriteTimeUtc(filePhys)
            If age.TotalMinutes > _fileCacheTtlMinutes Then Return Nothing

            Return File.ReadAllText(filePhys, Encoding.UTF8)
        Catch
            Return Nothing
        End Try
    End Function

    Private Sub TryWriteCache(host As String, xml As String)
        Try
            Dim dirPhys As String = Server.MapPath(_fileCachePath)
            If String.IsNullOrEmpty(dirPhys) Then Return

            If Not Directory.Exists(dirPhys) Then
                Directory.CreateDirectory(dirPhys)
            End If

            Dim filePhys As String = Path.Combine(dirPhys, GetCacheFileName(host))
            Dim tmpPhys As String = filePhys & ".tmp"

            File.WriteAllText(tmpPhys, xml, Encoding.UTF8)

            ' atomic replace
            If File.Exists(filePhys) Then
                File.Delete(filePhys)
            End If
            File.Move(tmpPhys, filePhys)
        Catch
            ' Do not fail sitemap on cache errors.
        End Try
    End Sub

    Private Function GetCacheFileName(host As String) As String
        ' Host may contain scheme and port; hash to a safe file name.
        Dim h As String = host.ToLowerInvariant()
        Dim bytes() As Byte = Encoding.UTF8.GetBytes(h)
        Dim hash() As Byte
        Using sha As SHA256 = SHA256.Create()
            hash = sha.ComputeHash(bytes)
        End Using
        Dim hex As New StringBuilder()
        For Each b As Byte In hash
            hex.Append(b.ToString("x2", CultureInfo.InvariantCulture))
        Next
        Return "sitemap_" & hex.ToString().Substring(0, 16) & ".xml"
    End Function

    ' =========================
    ' Utilities
    ' =========================
    Private Function GetHostBase() As String
        ' Always prefer current request authority.
        Dim u As Uri = Request.Url
        Return u.Scheme & "://" & u.Authority
    End Function

    Private Function NormalizeAbsoluteUrl(host As String, url As String) As String
        If String.IsNullOrEmpty(url) Then Return Nothing
        url = url.Trim()

        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If

        If Not url.StartsWith("/", StringComparison.Ordinal) Then
            url = "/" & url
        End If

        Return host & url
    End Function

    Private Function XmlEscape(s As String) As String
        If s Is Nothing Then Return ""
        Return SecurityElement.Escape(s)
    End Function

    ' Simple container
    Private Class SitemapUrl
        Public Property Loc As String
        Public Property LastModUtc As Nullable(Of DateTime)
        Public Property ChangeFreq As String
        Public Property Priority As String

        Public Sub New(loc As String, lastModUtc As Nullable(Of DateTime), changeFreq As String, priority As String)
            Me.Loc = loc
            Me.LastModUtc = lastModUtc
            Me.ChangeFreq = changeFreq
            Me.Priority = priority
        End Sub
    End Class
End Class
