Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.UI

Imports MySql.Data.MySqlClient

' Sitemap dinamica + Audit Robots
' Nota: scritto per massima compatibilità (evita Iterator/Yield, Async, interpolazioni, ecc.)
Public Class sitemap
    Inherits System.Web.UI.Page

    Private Const MAX_URLS_PER_SITEMAP As Integer = 45000

    ' --- config ---
    Private _fileCacheEnabled As Boolean
    Private _fileCacheTtlMinutes As Integer
    Private _fileCachePath As String

    Private _fromDbLastMod As Boolean
    Private _fallbackLastModDays As Integer

    Private _homePath As String
    Private _listingPath As String
    Private _includeProductDetails As Boolean
    Private _includeCatalogFacets As Boolean

    Private _auditEnabled As Boolean
    Private _auditToken As String

    ' --- robots rules ---
    Private _robotsDisallowRaw As List(Of String)
    Private _robotsDisallowRegex As List(Of Regex)

    Private NotInheritable Class UrlEntry
        Public Url As String
        Public LastModUtc As Nullable(Of DateTime)

        Public Sub New(ByVal url As String, ByVal lastModUtc As Nullable(Of DateTime))
            Me.Url = url
            Me.LastModUtc = lastModUtc
        End Sub
    End Class

    Private NotInheritable Class RobotsDisallowRules
        Public Raw As List(Of String)
        Public RegexList As List(Of Regex)

        Public Sub New()
            Raw = New List(Of String)()
            RegexList = New List(Of Regex)()
        End Sub
    End Class

    Protected Sub Page_Init(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Init
        ' Cache
        _fileCacheEnabled = GetAppSettingBool("KeepStore.Sitemap.FileCache.Enabled", True)
        _fileCacheTtlMinutes = GetAppSettingInt("KeepStore.Sitemap.FileCache.TtlMinutes", 60)
        _fileCachePath = GetAppSetting("KeepStore.Sitemap.FileCache.Path", "~/App_Data/Sitemaps")

        ' LastMod
        _fromDbLastMod = GetAppSettingBool("KeepStore.Sitemap.LastMod.FromDb", True)
        _fallbackLastModDays = GetAppSettingInt("KeepStore.Sitemap.LastMod.FallbackDays", 15)
        If _fallbackLastModDays < 0 Then _fallbackLastModDays = 0

        ' URLs
        _homePath = GetAppSetting("KeepStore.Sitemap.Home", "default.aspx")
        _listingPath = GetAppSetting("KeepStore.Sitemap.Listing", "shop/default.aspx")
        _includeProductDetails = GetAppSettingBool("KeepStore.Sitemap.IncludeProductDetails", True)
        _includeCatalogFacets = GetAppSettingBool("KeepStore.Sitemap.IncludeCatalogFacets", True)

        ' Audit
        _auditEnabled = GetAppSettingBool("KeepStore.Sitemap.Audit.Enabled", False)
        _auditToken = GetAppSetting("KeepStore.Sitemap.Audit.Token", "")

        ' Robots disallow
        Dim rr As RobotsDisallowRules = LoadRobotsDisallowRulesFromRobotsTxt()
        _robotsDisallowRaw = rr.Raw
        _robotsDisallowRegex = rr.RegexList
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim host As String = DetermineHostBaseUrl()

        ' --- Audit ---
        Dim auditFlag As String = Convert.ToString(Request.QueryString("audit"))
        If String.Equals(auditFlag, "1", StringComparison.OrdinalIgnoreCase) Then
            If Not IsAuditAllowed() Then
                Response.StatusCode = 404
                Response.End()
                Return
            End If

            Response.Clear()
            Response.ContentType = "text/plain"
            Response.ContentEncoding = Encoding.UTF8
            Response.Write(BuildAuditReport(host))
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        ' --- Sitemap ---
        Dim part As Integer = 0
        Dim partStr As String = Convert.ToString(Request.QueryString("part"))
        If Not String.IsNullOrEmpty(partStr) Then
            Integer.TryParse(partStr, part)
        End If
        If part < 0 Then part = 0

        Dim cacheKey As String = BuildCacheKey(host, part)
        If _fileCacheEnabled Then
            Dim cached As String = TryReadFromFileCache(cacheKey)
            If cached IsNot Nothing Then
                Response.Clear()
                Response.ContentType = "application/xml"
                Response.ContentEncoding = Encoding.UTF8
                Response.Write(cached)
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If
        End If

        Dim xml As String = ""

        Try
            Dim allUrls As List(Of UrlEntry) = BuildAllUrls(host)
            Dim allowed As List(Of UrlEntry) = FilterAllowedByRobots(allUrls)

            If allowed.Count = 0 Then
                ' fallback minimo
                allowed.Add(New UrlEntry(CombineHostAndPath(host, NormalizePath(_homePath)), GetFallbackLastModUtc()))
            End If

            Dim parts As Integer = CInt(Math.Ceiling(allowed.Count / CDbl(MAX_URLS_PER_SITEMAP)))
            If parts < 1 Then parts = 1

            If part <= 0 AndAlso allowed.Count > MAX_URLS_PER_SITEMAP Then
                ' sitemap index
                Dim lmIndex As Nullable(Of DateTime) = ComputeLatestLastModUtc(allowed)
                xml = RenderSitemapIndex(host, lmIndex, parts)
            Else
                If part <= 0 Then part = 1
                If part > parts Then
                    Response.StatusCode = 404
                    Response.End()
                    Return
                End If

                Dim startIndex As Integer = (part - 1) * MAX_URLS_PER_SITEMAP
                Dim count As Integer = Math.Min(MAX_URLS_PER_SITEMAP, allowed.Count - startIndex)
                Dim subset As List(Of UrlEntry) = allowed.GetRange(startIndex, count)
                xml = RenderUrlSet(subset)
            End If

        Catch
            ' In caso di eccezioni, restituisco sitemap minimale per non rompere l'intero sito.
            Dim mini As New List(Of UrlEntry)()
            mini.Add(New UrlEntry(CombineHostAndPath(host, NormalizePath(_homePath)), GetFallbackLastModUtc()))
            xml = RenderUrlSet(mini)
        End Try

        If _fileCacheEnabled Then
            WriteToFileCache(cacheKey, xml)
        End If

        Response.Clear()
        Response.ContentType = "application/xml"
        Response.ContentEncoding = Encoding.UTF8
        Response.Write(xml)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    ' -------------------- Build URLs --------------------

    Private Function BuildAllUrls(ByVal host As String) As List(Of UrlEntry)
        Dim res As New List(Of UrlEntry)()

        AddStaticUrls(res, host)
        AddDynamicUrls(res, host)

        ' Normalizzazione + lastmod fallback
        Dim fallbackUtc As DateTime = GetFallbackLastModUtc().Value

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim normalized As New List(Of UrlEntry)()

        For Each it As UrlEntry In res
            If it Is Nothing Then Continue For
            If String.IsNullOrEmpty(it.Url) Then Continue For

            Dim absUrl As String = NormalizeToAbsoluteUrl(host, it.Url)
            If String.IsNullOrEmpty(absUrl) Then Continue For

            If Not seen.Contains(absUrl) Then
                seen.Add(absUrl)

                If Not it.LastModUtc.HasValue Then
                    it.LastModUtc = fallbackUtc
                Else
                    it.LastModUtc = ToUtcNullable(it.LastModUtc.Value)
                End If

                it.Url = absUrl
                normalized.Add(it)
            End If
        Next

        Return normalized
    End Function

    Private Sub AddStaticUrls(ByVal urls As List(Of UrlEntry), ByVal host As String)
        Dim fallbackUtc As Nullable(Of DateTime) = GetFallbackLastModUtc()

        Dim homeAbs As String = CombineHostAndPath(host, NormalizePath(_homePath))
        urls.Add(New UrlEntry(homeAbs, fallbackUtc))

        Dim listAbs As String = CombineHostAndPath(host, NormalizePath(_listingPath))
        urls.Add(New UrlEntry(listAbs, fallbackUtc))
    End Sub

    Private Sub AddDynamicUrls(ByVal urls As List(Of UrlEntry), ByVal host As String)
        If _includeProductDetails Then
            AddEntriesFromView(urls, host, "v_sitemap_prodotti")
        End If

        If _includeCatalogFacets Then
            AddEntriesFromView(urls, host, "v_sitemap_categorie")
        End If
    End Sub

    Private Sub AddEntriesFromView(ByVal urls As List(Of UrlEntry), ByVal host As String, ByVal viewName As String)
        Dim rows As List(Of UrlEntry) = QueryUrlsFromView(viewName)
        If rows Is Nothing OrElse rows.Count = 0 Then Return

        For Each row As UrlEntry In rows
            If row Is Nothing Then Continue For
            If String.IsNullOrEmpty(row.Url) Then Continue For
            urls.Add(row)
        Next
    End Sub

    ' -------------------- DB --------------------

    Private Function QueryUrlsFromView(ByVal viewName As String) As List(Of UrlEntry)
        Dim res As New List(Of UrlEntry)()

        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Return res

        Dim sql As String
        If _fromDbLastMod Then
            sql = "SELECT url, last_mod FROM " & viewName & " ORDER BY url"
        Else
            sql = "SELECT url, NULL AS last_mod FROM " & viewName & " ORDER BY url"
        End If

        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As New MySqlCommand(sql, conn)
                    cmd.CommandType = Data.CommandType.Text
                    Using rd As MySqlDataReader = cmd.ExecuteReader()
                        While rd.Read()
                            Dim u As String = SafeReadString(rd, "url")
                            If String.IsNullOrEmpty(u) Then Continue While

                            Dim lm As Nullable(Of DateTime) = Nothing
                            If _fromDbLastMod Then
                                lm = SafeReadUtcDate(rd, "last_mod")
                            End If

                            res.Add(New UrlEntry(u, lm))
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' non blocco la sitemap se il DB non risponde
        End Try

        Return res
    End Function

    Private Function GetConnectionString() As String
        Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("taikunConnectionString")
        If cs IsNot Nothing AndAlso Not String.IsNullOrEmpty(cs.ConnectionString) Then
            Return cs.ConnectionString
        End If

        ' fallback: prima connection string non vuota
        If ConfigurationManager.ConnectionStrings IsNot Nothing Then
            For Each s As ConnectionStringSettings In ConfigurationManager.ConnectionStrings
                If s IsNot Nothing AndAlso Not String.IsNullOrEmpty(s.ConnectionString) Then
                    Return s.ConnectionString
                End If
            Next
        End If

        Return ""
    End Function

    Private Function SafeReadString(ByVal rd As MySqlDataReader, ByVal fieldName As String) As String
        Try
            Dim ord As Integer = rd.GetOrdinal(fieldName)
            If rd.IsDBNull(ord) Then Return ""
            Return Convert.ToString(rd.GetValue(ord))
        Catch
            Return ""
        End Try
    End Function

    Private Function SafeReadUtcDate(ByVal rd As MySqlDataReader, ByVal fieldName As String) As Nullable(Of DateTime)
        Try
            Dim ord As Integer = rd.GetOrdinal(fieldName)
            If rd.IsDBNull(ord) Then Return Nothing

            Dim dt As DateTime = Convert.ToDateTime(rd.GetValue(ord))
            Return ToUtcNullable(dt)
        Catch
            Return Nothing
        End Try
    End Function

    Private Function ToUtcNullable(ByVal dt As DateTime) As DateTime
        If dt.Kind = DateTimeKind.Utc Then Return dt
        If dt.Kind = DateTimeKind.Local Then Return dt.ToUniversalTime()
        ' Unspecified: assumo sia già UTC (evita conversioni errate)
        Return DateTime.SpecifyKind(dt, DateTimeKind.Utc)
    End Function

    ' -------------------- Robots filtering --------------------

    Private Function LoadRobotsDisallowRulesFromRobotsTxt() As RobotsDisallowRules
        Dim res As New RobotsDisallowRules()

        Try
            Dim robotsPhys As String = Server.MapPath("~/robots.txt")
            If String.IsNullOrEmpty(robotsPhys) OrElse Not File.Exists(robotsPhys) Then
                Return res
            End If

            Dim lines() As String = File.ReadAllLines(robotsPhys)

            Dim isStarGroup As Boolean = False
            Dim seenRulesInGroup As Boolean = False
            Dim prevWasUserAgent As Boolean = False

            For Each rawLine As String In lines
                Dim line As String = rawLine
                If line Is Nothing Then Continue For

                Dim hashIdx As Integer = line.IndexOf("#"c)
                If hashIdx >= 0 Then line = line.Substring(0, hashIdx)
                line = line.Trim()
                If line.Length = 0 Then Continue For

                If line.StartsWith("User-agent:", StringComparison.OrdinalIgnoreCase) Then
                    Dim ua As String = line.Substring(11).Trim()

                    ' nuovo gruppo se arrivano nuove UA dopo regole
                    If seenRulesInGroup AndAlso Not prevWasUserAgent Then
                        isStarGroup = False
                        seenRulesInGroup = False
                    End If

                    If String.Equals(ua, "*", StringComparison.OrdinalIgnoreCase) Then
                        isStarGroup = True
                    End If

                    prevWasUserAgent = True
                    Continue For
                End If

                prevWasUserAgent = False

                If line.StartsWith("Disallow:", StringComparison.OrdinalIgnoreCase) Then
                    If Not isStarGroup Then Continue For

                    seenRulesInGroup = True
                    Dim rule As String = line.Substring(9).Trim()
                    If rule.Length = 0 Then
                        ' Disallow vuoto => allow all
                        Continue For
                    End If

                    Dim rxStr As String = RobotsPatternToRegex(rule)
                    If String.IsNullOrEmpty(rxStr) Then Continue For

                    res.Raw.Add(rule)
                    res.RegexList.Add(New Regex(rxStr, RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant))
                End If
            Next

        Catch
            ' ignore
        End Try

        Return res
    End Function

    Private Function RobotsPatternToRegex(ByVal pattern As String) As String
        If pattern Is Nothing Then Return ""

        Dim p As String = pattern.Trim()
        If p.Length = 0 Then Return ""

        Dim endAnchor As Boolean = False
        If p.EndsWith("$", StringComparison.Ordinal) Then
            endAnchor = True
            p = p.Substring(0, p.Length - 1)
        End If

        If Not p.StartsWith("/", StringComparison.Ordinal) Then
            p = "/" & p
        End If

        Dim esc As String = Regex.Escape(p)
        esc = esc.Replace("\\*", ".*")

        Dim rx As String = "^" & esc
        If endAnchor Then rx = rx & "$"

        Return rx
    End Function

    Private Function FilterAllowedByRobots(ByVal urls As List(Of UrlEntry)) As List(Of UrlEntry)
        Dim res As New List(Of UrlEntry)()

        If urls Is Nothing OrElse urls.Count = 0 Then Return res
        If _robotsDisallowRegex Is Nothing OrElse _robotsDisallowRegex.Count = 0 Then
            res.AddRange(urls)
            Return res
        End If

        For Each it As UrlEntry In urls
            If it Is Nothing OrElse String.IsNullOrEmpty(it.Url) Then Continue For
            If Not IsDisallowedByRobots(it.Url) Then
                res.Add(it)
            End If
        Next

        Return res
    End Function

    Private Function IsDisallowedByRobots(ByVal absUrl As String) As Boolean
        If String.IsNullOrEmpty(absUrl) Then Return False
        If _robotsDisallowRegex Is Nothing OrElse _robotsDisallowRegex.Count = 0 Then Return False

        Dim rel As String = ""

        Try
            Dim u As Uri = Nothing
            If Uri.TryCreate(absUrl, UriKind.Absolute, u) AndAlso u IsNot Nothing Then
                rel = u.PathAndQuery
            Else
                ' già relativo
                rel = absUrl
            End If
        Catch
            rel = absUrl
        End Try

        If String.IsNullOrEmpty(rel) Then Return False
        If Not rel.StartsWith("/", StringComparison.Ordinal) Then rel = "/" & rel

        For Each rx As Regex In _robotsDisallowRegex
            If rx Is Nothing Then Continue For
            If rx.IsMatch(rel) Then
                Return True
            End If
        Next

        Return False
    End Function

    ' -------------------- Audit --------------------

    Private Function IsAuditAllowed() As Boolean
        If Not _auditEnabled Then Return False
        If String.IsNullOrEmpty(_auditToken) OrElse _auditToken.Length < 8 Then Return False

        Dim t As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(t) Then Return False

        Return String.Equals(t, _auditToken, StringComparison.Ordinal)
    End Function

    Private Function BuildAuditReport(ByVal host As String) As String
        Dim sb As New StringBuilder()
        sb.AppendLine("Sitemap audit")
        sb.AppendLine("Host: " & host)
        sb.AppendLine("UtcNow: " & DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
        sb.AppendLine("")

        sb.AppendLine("Cache.Enabled: " & _fileCacheEnabled.ToString())
        sb.AppendLine("Cache.TtlMinutes: " & _fileCacheTtlMinutes.ToString())
        sb.AppendLine("Cache.Path: " & _fileCachePath)
        sb.AppendLine("")

        Dim allUrls As List(Of UrlEntry) = BuildAllUrls(host)
        Dim allowed As List(Of UrlEntry) = FilterAllowedByRobots(allUrls)

        sb.AppendLine("All URLs (pre-robots): " & allUrls.Count.ToString())
        sb.AppendLine("Allowed URLs: " & allowed.Count.ToString())
        sb.AppendLine("Excluded by robots: " & (allUrls.Count - allowed.Count).ToString())
        sb.AppendLine("")

        sb.AppendLine("Robots Disallow rules for UA=*")
        sb.AppendLine("Count: " & If(_robotsDisallowRaw Is Nothing, 0, _robotsDisallowRaw.Count).ToString())

        If _robotsDisallowRaw IsNot Nothing AndAlso _robotsDisallowRaw.Count > 0 Then
            For i As Integer = 0 To Math.Min(_robotsDisallowRaw.Count - 1, 100)
                sb.AppendLine("  - " & _robotsDisallowRaw(i))
            Next
            If _robotsDisallowRaw.Count > 101 Then
                sb.AppendLine("  ...")
            End If
        End If

        sb.AppendLine("")

        If allUrls.Count > 0 Then
            sb.AppendLine("Excluded URLs (first 100)")
            Dim shown As Integer = 0

            For Each it As UrlEntry In allUrls
                If it Is Nothing OrElse String.IsNullOrEmpty(it.Url) Then Continue For
                Dim matchRule As String = FindFirstMatchingRobotsRule(it.Url)
                If Not String.IsNullOrEmpty(matchRule) Then
                    sb.AppendLine("  - " & it.Url & "   [Disallow: " & matchRule & "]")
                    shown += 1
                    If shown >= 100 Then Exit For
                End If
            Next

            If shown = 0 Then
                sb.AppendLine("  (none)")
            End If
        End If

        Return sb.ToString()
    End Function

    Private Function FindFirstMatchingRobotsRule(ByVal absUrl As String) As String
        If String.IsNullOrEmpty(absUrl) Then Return ""
        If _robotsDisallowRegex Is Nothing OrElse _robotsDisallowRegex.Count = 0 Then Return ""

        Dim rel As String = ""

        Try
            Dim u As Uri = Nothing
            If Uri.TryCreate(absUrl, UriKind.Absolute, u) AndAlso u IsNot Nothing Then
                rel = u.PathAndQuery
            Else
                rel = absUrl
            End If
        Catch
            rel = absUrl
        End Try

        If String.IsNullOrEmpty(rel) Then Return ""
        If Not rel.StartsWith("/", StringComparison.Ordinal) Then rel = "/" & rel

        Dim lim As Integer = Math.Min(_robotsDisallowRegex.Count, If(_robotsDisallowRaw Is Nothing, 0, _robotsDisallowRaw.Count))
        For i As Integer = 0 To lim - 1
            Dim rx As Regex = _robotsDisallowRegex(i)
            If rx IsNot Nothing AndAlso rx.IsMatch(rel) Then
                Return _robotsDisallowRaw(i)
            End If
        Next

        ' fallback: match senza indice
        For Each rx As Regex In _robotsDisallowRegex
            If rx IsNot Nothing AndAlso rx.IsMatch(rel) Then
                Return "(matched)"
            End If
        Next

        Return ""
    End Function

    ' -------------------- Rendering --------------------

    Private Function RenderSitemapIndex(ByVal host As String, ByVal lastModUtc As Nullable(Of DateTime), ByVal parts As Integer) As String
        Dim sb As New StringBuilder()
        sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.AppendLine("<sitemapindex xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

        Dim lm As String = ""
        If lastModUtc.HasValue Then
            lm = lastModUtc.Value.ToString("yyyy-MM-dd")
        End If

        For i As Integer = 1 To parts
            Dim loc As String = host.TrimEnd("/"c) & "/sitemap.aspx?part=" & i.ToString()
            sb.AppendLine("  <sitemap>")
            sb.AppendLine("    <loc>" & XmlEscape(loc) & "</loc>")
            If lm.Length > 0 Then
                sb.AppendLine("    <lastmod>" & lm & "</lastmod>")
            End If
            sb.AppendLine("  </sitemap>")
        Next

        sb.AppendLine("</sitemapindex>")
        Return sb.ToString()
    End Function

    Private Function RenderUrlSet(ByVal entries As List(Of UrlEntry)) As String
        Dim sb As New StringBuilder()
        sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.AppendLine("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

        If entries IsNot Nothing Then
            For Each it As UrlEntry In entries
                If it Is Nothing OrElse String.IsNullOrEmpty(it.Url) Then Continue For

                sb.AppendLine("  <url>")
                sb.AppendLine("    <loc>" & XmlEscape(it.Url) & "</loc>")
                If it.LastModUtc.HasValue Then
                    sb.AppendLine("    <lastmod>" & it.LastModUtc.Value.ToString("yyyy-MM-dd") & "</lastmod>")
                End If
                sb.AppendLine("  </url>")
            Next
        End If

        sb.AppendLine("</urlset>")
        Return sb.ToString()
    End Function

    Private Function XmlEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""
        Return s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("""""", "&quot;").Replace("'", "&apos;")
    End Function

    Private Function ComputeLatestLastModUtc(ByVal urls As List(Of UrlEntry)) As Nullable(Of DateTime)
        If urls Is Nothing OrElse urls.Count = 0 Then Return Nothing

        Dim maxUtc As DateTime = DateTime.MinValue
        Dim has As Boolean = False

        For Each it As UrlEntry In urls
            If it Is Nothing OrElse Not it.LastModUtc.HasValue Then Continue For
            Dim v As DateTime = it.LastModUtc.Value
            If Not has OrElse v > maxUtc Then
                maxUtc = v
                has = True
            End If
        Next

        If Not has Then Return Nothing
        Return maxUtc
    End Function

    ' -------------------- File cache --------------------

    Private Function BuildCacheKey(ByVal host As String, ByVal part As Integer) As String
        Dim h As String = host
        If String.IsNullOrEmpty(h) Then h = "host"
        h = h.ToLowerInvariant()
        h = h.Replace("://", "__").Replace("/", "_").Replace("?", "_").Replace("&", "_").Replace("=", "_")
        h = Regex.Replace(h, "[^a-z0-9_\.-]", "_")

        Dim suffix As String = "index"
        If part > 0 Then suffix = "part" & part.ToString()

        Return "sitemap_" & h & "_" & suffix
    End Function

    Private Function TryReadFromFileCache(ByVal cacheKey As String) As String
        Try
            Dim dirPhys As String = Server.MapPath(_fileCachePath)
            If String.IsNullOrEmpty(dirPhys) Then Return Nothing

            Dim f As String = Path.Combine(dirPhys, cacheKey & ".xml")
            If Not File.Exists(f) Then Return Nothing

            Dim age As TimeSpan = DateTime.UtcNow - File.GetLastWriteTimeUtc(f)
            If age.TotalMinutes > CDbl(_fileCacheTtlMinutes) Then Return Nothing

            Return File.ReadAllText(f, Encoding.UTF8)
        Catch
            Return Nothing
        End Try
    End Function

    Private Sub WriteToFileCache(ByVal cacheKey As String, ByVal content As String)
        Try
            Dim dirPhys As String = Server.MapPath(_fileCachePath)
            If String.IsNullOrEmpty(dirPhys) Then Return

            If Not Directory.Exists(dirPhys) Then
                Directory.CreateDirectory(dirPhys)
            End If

            Dim f As String = Path.Combine(dirPhys, cacheKey & ".xml")
            File.WriteAllText(f, content, Encoding.UTF8)
        Catch
            ' ignore
        End Try
    End Sub

    ' -------------------- Helpers --------------------

    Private Function DetermineHostBaseUrl() As String
        ' Se vuoi forzare un host fisso, puoi aggiungere in web.config: KeepStore.Sitemap.BaseUrl
        Dim forced As String = GetAppSetting("KeepStore.Sitemap.BaseUrl", "")
        If Not String.IsNullOrEmpty(forced) Then
            If Not forced.EndsWith("/", StringComparison.Ordinal) Then forced &= "/"
            Return forced
        End If

        Dim u As Uri = Request.Url
        Dim baseUrl As String = u.Scheme & "://" & u.Authority & "/"
        Return baseUrl
    End Function

    Private Function NormalizeToAbsoluteUrl(ByVal host As String, ByVal inputUrlOrPath As String) As String
        If String.IsNullOrEmpty(inputUrlOrPath) Then Return ""

        Dim s As String = inputUrlOrPath.Trim()

        Dim uriAbs As Uri = Nothing
        If Uri.TryCreate(s, UriKind.Absolute, uriAbs) AndAlso uriAbs IsNot Nothing Then
            Return uriAbs.ToString()
        End If

        ' relativo
        Dim p As String = s
        If Not p.StartsWith("/", StringComparison.Ordinal) Then p = "/" & p
        Return CombineHostAndPath(host, p)
    End Function

    Private Function CombineHostAndPath(ByVal host As String, ByVal path As String) As String
        Dim h As String = host
        If String.IsNullOrEmpty(h) Then h = ""
        If Not h.EndsWith("/", StringComparison.Ordinal) Then h &= "/"

        Dim p As String = path
        If String.IsNullOrEmpty(p) Then p = ""
        p = p.Trim()
        If p.StartsWith("/", StringComparison.Ordinal) Then p = p.Substring(1)

        Return h & p
    End Function

    Private Function NormalizePath(ByVal path As String) As String
        If String.IsNullOrEmpty(path) Then Return "/"

        Dim p As String = path.Trim()
        If p.Length = 0 Then Return "/"

        If Not p.StartsWith("/", StringComparison.Ordinal) Then p = "/" & p
        Return p
    End Function

    Private Function GetFallbackLastModUtc() As Nullable(Of DateTime)
        Return DateTime.UtcNow.AddDays(-CDbl(_fallbackLastModDays))
    End Function

    Private Function GetAppSetting(ByVal key As String, ByVal defaultValue As String) As String
        Try
            Dim v As String = ConfigurationManager.AppSettings(key)
            If v Is Nothing Then Return defaultValue
            v = v.Trim()
            If v.Length = 0 Then Return defaultValue
            Return v
        Catch
            Return defaultValue
        End Try
    End Function

    Private Function GetAppSettingBool(ByVal key As String, ByVal defaultValue As Boolean) As Boolean
        Dim s As String = GetAppSetting(key, If(defaultValue, "true", "false"))
        If String.IsNullOrEmpty(s) Then Return defaultValue

        If String.Equals(s, "1", StringComparison.OrdinalIgnoreCase) Then Return True
        If String.Equals(s, "0", StringComparison.OrdinalIgnoreCase) Then Return False

        Dim b As Boolean
        If Boolean.TryParse(s, b) Then Return b
        Return defaultValue
    End Function

    Private Function GetAppSettingInt(ByVal key As String, ByVal defaultValue As Integer) As Integer
        Dim s As String = GetAppSetting(key, defaultValue.ToString())
        Dim i As Integer
        If Integer.TryParse(s, i) Then Return i
        Return defaultValue
    End Function

End Class