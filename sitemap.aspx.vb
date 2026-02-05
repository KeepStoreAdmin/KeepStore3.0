Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports MySql.Data.MySqlClient

Partial Class sitemap
    Inherits System.Web.UI.Page

    ' ----------------------------
    ' Settings (loaded per-request)
    ' ----------------------------
    Private _fileCacheEnabled As Boolean = True
    Private _fileCachePath As String = "~/App_Data/Sitemaps"
    Private _fileCacheTtlMinutes As Integer = 60

    Private _auditEnabled As Boolean = False
    Private _auditToken As String = ""

    Private _alignRobotsDisallow As Boolean = False
    Private _disallowRegex As List(Of Regex) = Nothing

    Private _maxUrlsPerPart As Integer = 45000 ' below 50k hard limit

    ' ----------------------------
    ' Models
    ' ----------------------------
    Private Class CacheSignatureInfo
        Public Signature As String
        Public DataMaxUtc As Nullable(Of DateTime)
    End Class

    ' ----------------------------
    ' Page entry
    ' ----------------------------
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.BufferOutput = True

        Dim host As String = ResolveBaseUrl()
        LoadSettings()

        ' Optional: align sitemap output to robots.txt Disallow rules
        If _alignRobotsDisallow Then
            _disallowRegex = LoadDisallowRegexFromRobots()
            If _disallowRegex Is Nothing Then _disallowRegex = New List(Of Regex)()
        Else
            _disallowRegex = New List(Of Regex)()
        End If

        ' Audit endpoint (token protected)
        If StringEquals(Request.QueryString("audit"), "1") AndAlso IsAuditAllowed() Then
            Response.ContentType = "text/plain"
            Response.ContentEncoding = Encoding.UTF8
            Response.Write(BuildAuditReport(host))
            Return
        End If

        Try
            Dim sig As CacheSignatureInfo = ComputeCacheSignature(host)

            Dim part As Integer = 0
            Integer.TryParse(Convert.ToString(Request.QueryString("part")), part)

            Dim xml As String = TryReadFromFileCache(sig, part)
            If xml Is Nothing Then
                xml = BuildXml(host, sig, part)
                TryWriteToFileCache(sig, part, xml)
            End If

            Response.ContentType = "application/xml"
            Response.ContentEncoding = Encoding.UTF8
            Response.Write(xml)
        Catch ex As Exception
            ' If something goes wrong, do not leak details publicly.
            Response.StatusCode = 500
            Response.ContentType = "text/plain"
            Response.ContentEncoding = Encoding.UTF8

            If IsAuditAllowed() AndAlso StringEquals(Request.QueryString("debug"), "1") Then
                Response.Write("ERROR: " & ex.ToString())
            Else
                Response.Write("Internal Server Error")
            End If
        End Try
    End Sub

    ' ----------------------------
    ' Settings + helpers
    ' ----------------------------
    Private Sub LoadSettings()
        _fileCacheEnabled = GetAppSettingBool("KeepStore.Sitemap.FileCache.Enabled", True)
        _fileCachePath = GetAppSetting("KeepStore.Sitemap.FileCache.Path", "~/App_Data/Sitemaps")
        _fileCacheTtlMinutes = GetAppSettingInt("KeepStore.Sitemap.FileCache.TtlMinutes", 60)

        _auditEnabled = GetAppSettingBool("KeepStore.Sitemap.Audit.Enabled", False)
        _auditToken = GetAppSetting("KeepStore.Sitemap.Audit.Token", "")

        _alignRobotsDisallow = GetAppSettingBool("KeepStore.Sitemap.AlignRobotsDisallow", False)
        _maxUrlsPerPart = GetAppSettingInt("KeepStore.Sitemap.MaxUrlsPerPart", 45000)
        If _maxUrlsPerPart < 1000 Then _maxUrlsPerPart = 1000
        If _maxUrlsPerPart > 50000 Then _maxUrlsPerPart = 50000
    End Sub

    Private Function ResolveBaseUrl() As String
        Dim baseFromCfg As String = GetAppSetting("KeepStore.Sitemap.BaseUrl", "")
        If Not String.IsNullOrEmpty(baseFromCfg) Then
            Return baseFromCfg.TrimEnd("/"c)
        End If

        If Request Is Nothing OrElse Request.Url Is Nothing Then Return "https://www.taikun.it"
        Return Request.Url.GetLeftPart(UriPartial.Authority)
    End Function

    Private Shared Function StringEquals(a As String, b As String) As Boolean
        Return String.Equals(Convert.ToString(a), Convert.ToString(b), StringComparison.Ordinal)
    End Function

    Private Shared Function GetAppSetting(key As String, Optional defaultValue As String = "") As String
        Dim v As String = Convert.ToString(ConfigurationManager.AppSettings(key))
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Return v
    End Function

    Private Shared Function GetAppSettingBool(key As String, defaultValue As Boolean) As Boolean
        Dim v As String = GetAppSetting(key, Nothing)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Dim b As Boolean
        If Boolean.TryParse(v, b) Then Return b
        If v = "1" Then Return True
        If v = "0" Then Return False
        Return defaultValue
    End Function

    Private Shared Function GetAppSettingInt(key As String, defaultValue As Integer) As Integer
        Dim v As String = GetAppSetting(key, Nothing)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Dim i As Integer
        If Integer.TryParse(v, i) Then Return i
        Return defaultValue
    End Function

    ' ----------------------------
    ' Audit
    ' ----------------------------
    Private Function IsAuditAllowed() As Boolean
        If Not _auditEnabled Then Return False
        If String.IsNullOrEmpty(_auditToken) OrElse _auditToken.Length < 16 Then Return False

        Dim t As String = Convert.ToString(Request.QueryString("token"))
        If String.IsNullOrEmpty(t) Then Return False

        Return StringEquals(t, _auditToken)
    End Function

    Private Function BuildAuditReport(host As String) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("KeepStore Sitemap Audit")
        sb.AppendLine("Time(UTC): " & DateTime.UtcNow.ToString("o"))
        sb.AppendLine("Host: " & host)
        sb.AppendLine("")
        sb.AppendLine("Cache.Enabled: " & _fileCacheEnabled.ToString())
        sb.AppendLine("Cache.Path: " & _fileCachePath)
        sb.AppendLine("Cache.TtlMinutes: " & _fileCacheTtlMinutes.ToString())
        sb.AppendLine("MaxUrlsPerPart: " & _maxUrlsPerPart.ToString())
        sb.AppendLine("AlignRobotsDisallow: " & _alignRobotsDisallow.ToString())
        sb.AppendLine("Robots.DisallowRegex.Count: " & If(_disallowRegex Is Nothing, 0, _disallowRegex.Count).ToString())
        sb.AppendLine("")

        Try
            Dim sig As CacheSignatureInfo = ComputeCacheSignature(host)
            sb.AppendLine("Signature: " & If(sig Is Nothing, "(null)", sig.Signature))
            sb.AppendLine("DataMaxUtc: " & If(sig Is Nothing OrElse Not sig.DataMaxUtc.HasValue, "(null)", sig.DataMaxUtc.Value.ToString("o")))
        Catch ex As Exception
            sb.AppendLine("Signature: ERROR - " & ex.Message)
        End Try

        ' Check cache directory
        Try
            If _fileCacheEnabled Then
                Dim physDir As String = SafeMapPath(_fileCachePath)
                sb.AppendLine("")
                sb.AppendLine("Cache.PhysicalPath: " & physDir)
                sb.AppendLine("Cache.DirExists: " & Directory.Exists(physDir).ToString())
            End If
        Catch ex As Exception
            sb.AppendLine("Cache.PhysicalPath: ERROR - " & ex.Message)
        End Try

        Return sb.ToString()
    End Function

    ' ----------------------------
    ' Robots.txt alignment
    ' ----------------------------
    Private Function LoadDisallowRegexFromRobots() As List(Of Regex)
        Dim res As New List(Of Regex)()

        Try
            Dim robotsPhys As String = SafeMapPath("~/robots.txt")
            If String.IsNullOrEmpty(robotsPhys) OrElse Not File.Exists(robotsPhys) Then
                Return res
            End If

            Dim active As Boolean = False

            For Each rawLine As String In File.ReadAllLines(robotsPhys, Encoding.UTF8)
                Dim line As String = If(rawLine, "").Trim()
                If line = "" Then Continue For

                Dim hashIdx As Integer = line.IndexOf("#"c)
                If hashIdx >= 0 Then line = line.Substring(0, hashIdx).Trim()
                If line = "" Then Continue For

                If line.StartsWith("User-agent:", StringComparison.OrdinalIgnoreCase) Then
                    Dim ua As String = line.Substring("User-agent:".Length).Trim()
                    active = (ua = "*")
                    Continue For
                End If

                If Not active Then Continue For

                If line.StartsWith("Disallow:", StringComparison.OrdinalIgnoreCase) Then
                    Dim pat As String = line.Substring("Disallow:".Length).Trim()
                    If String.IsNullOrEmpty(pat) Then Continue For ' empty Disallow means allow all
                    ' Prefix match per robots spec; support wildcard *
                    Dim rx As String = "^" & WildcardPathToRegex(pat)
                    res.Add(New Regex(rx, RegexOptions.IgnoreCase Or RegexOptions.Compiled))
                End If
            Next
        Catch
            ' Ignore robots parsing errors; sitemap should still work
        End Try

        Return res
    End Function

    Private Shared Function WildcardPathToRegex(pathPattern As String) As String
        ' Escape everything, then restore wildcard support for *
        Dim esc As String = Regex.Escape(pathPattern)
        esc = esc.Replace("\*", ".*")
        Return esc
    End Function

    Private Function IsDisallowedByRobots(loc As String) As Boolean
        If _disallowRegex Is Nothing OrElse _disallowRegex.Count = 0 Then Return False

        Try
            Dim u As New Uri(loc)
            Dim p As String = u.AbsolutePath
            For Each rx As Regex In _disallowRegex
                If rx IsNot Nothing AndAlso rx.IsMatch(p) Then Return True
            Next
        Catch
            ' If URL is malformed, do not include it in sitemap
            Return True
        End Try

        Return False
    End Function

    ' ----------------------------
    ' File cache
    ' ----------------------------
    Private Function TryReadFromFileCache(sig As CacheSignatureInfo, part As Integer) As String
        If Not _fileCacheEnabled Then Return Nothing
        If sig Is Nothing OrElse String.IsNullOrEmpty(sig.Signature) Then Return Nothing

        Try
            Dim physDir As String = SafeMapPath(_fileCachePath)
            If String.IsNullOrEmpty(physDir) OrElse Not Directory.Exists(physDir) Then Return Nothing

            Dim physFile As String = GetCacheFilePath(physDir, sig.Signature, part)
            If Not File.Exists(physFile) Then Return Nothing

            Dim fi As New FileInfo(physFile)
            Dim ageMinutes As Double = (DateTime.UtcNow - fi.LastWriteTimeUtc).TotalMinutes
            If ageMinutes > _fileCacheTtlMinutes Then Return Nothing

            Return File.ReadAllText(physFile, Encoding.UTF8)
        Catch
            Return Nothing
        End Try
    End Function

    Private Sub TryWriteToFileCache(sig As CacheSignatureInfo, part As Integer, xml As String)
        If Not _fileCacheEnabled Then Return
        If sig Is Nothing OrElse String.IsNullOrEmpty(sig.Signature) Then Return

        Try
            Dim physDir As String = SafeMapPath(_fileCachePath)
            If String.IsNullOrEmpty(physDir) Then Return

            ' Safety: never write outside the application root
            Dim appRoot As String = HttpRuntime.AppDomainAppPath
            If Not physDir.StartsWith(appRoot, StringComparison.OrdinalIgnoreCase) Then Return

            If Not Directory.Exists(physDir) Then Directory.CreateDirectory(physDir)

            Dim physFile As String = GetCacheFilePath(physDir, sig.Signature, part)
            Dim tmp As String = physFile & ".tmp"

            File.WriteAllText(tmp, xml, Encoding.UTF8)

            ' Atomic-ish replace
            If File.Exists(physFile) Then
                File.Delete(physFile)
            End If
            File.Move(tmp, physFile)
        Catch
            ' Ignore cache write failures
        End Try
    End Sub

    Private Shared Function GetCacheFilePath(physDir As String, signature As String, part As Integer) As String
        Dim h As String = Sha1Hex(signature)
        Dim suffix As String = If(part <= 0, "_index", "_part" & part.ToString())
        Return Path.Combine(physDir, "sitemap_" & h & suffix & ".xml")
    End Function

    Private Shared Function Sha1Hex(input As String) As String
        Using sha As SHA1 = SHA1.Create()
            Dim b() As Byte = Encoding.UTF8.GetBytes(If(input, ""))
            Dim h() As Byte = sha.ComputeHash(b)
            Dim sb As New StringBuilder(h.Length * 2)
            For Each bb As Byte In h
                sb.Append(bb.ToString("x2"))
            Next
            Return sb.ToString()
        End Using
    End Function

    Private Function SafeMapPath(virtualPath As String) As String
        Try
            If Server Is Nothing Then
                Dim ctx As HttpContext = HttpContext.Current
                If ctx IsNot Nothing AndAlso ctx.Server IsNot Nothing Then
                    Return ctx.Server.MapPath(virtualPath)
                End If
                Return Nothing
            End If
            Return Server.MapPath(virtualPath)
        Catch
            Return Nothing
        End Try
    End Function

    ' ----------------------------
    ' Sitemap generation
    ' ----------------------------
    Private Function ComputeCacheSignature(host As String) As CacheSignatureInfo
        Dim info As New CacheSignatureInfo()
        info.DataMaxUtc = Nothing

        Dim maxUtc As Nullable(Of DateTime) = Nothing

        ' Try to use DB last_mod max (optional)
        Dim cs As String = GetConnectionString()
        If Not String.IsNullOrEmpty(cs) Then
            Dim vArt As String = GetAppSetting("KeepStore.Sitemap.DbView.Articoli", "v_sitemap_articoli")
            Dim vFac As String = GetAppSetting("KeepStore.Sitemap.DbView.Facets", "v_sitemap_facets")
            Dim vProd As String = GetAppSetting("KeepStore.Sitemap.DbView.Products", "v_sitemap_products")

            maxUtc = MaxUtc(maxUtc, TryGetMaxUtcFromView(cs, vArt))
            maxUtc = MaxUtc(maxUtc, TryGetMaxUtcFromView(cs, vFac))
            maxUtc = MaxUtc(maxUtc, TryGetMaxUtcFromView(cs, vProd))
        End If

        info.DataMaxUtc = maxUtc

        Dim sigParts As New List(Of String)()
        sigParts.Add(host)
        sigParts.Add("mx=" & If(maxUtc.HasValue, maxUtc.Value.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture), "none"))
        sigParts.Add("robots=" & _alignRobotsDisallow.ToString())
        sigParts.Add("mpp=" & _maxUrlsPerPart.ToString())
        info.Signature = String.Join("|", sigParts.ToArray())

        Return info
    End Function

    Private Shared Function MaxUtc(a As Nullable(Of DateTime), b As Nullable(Of DateTime)) As Nullable(Of DateTime)
        If Not a.HasValue Then Return b
        If Not b.HasValue Then Return a
        If b.Value > a.Value Then Return b
        Return a
    End Function

    Private Function TryGetMaxUtcFromView(cs As String, viewName As String) As Nullable(Of DateTime)
        If String.IsNullOrEmpty(cs) OrElse String.IsNullOrEmpty(viewName) Then Return Nothing
        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As MySqlCommand = CreateCommand(conn, "SELECT MAX(last_mod) FROM " & viewName)
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse o Is DBNull.Value Then Return Nothing
                    Dim dt As DateTime
                    If TypeOf o Is DateTime Then
                        dt = CType(o, DateTime)
                    Else
                        If Not DateTime.TryParse(Convert.ToString(o), dt) Then Return Nothing
                    End If
                    If dt.Kind = DateTimeKind.Unspecified Then
                        dt = DateTime.SpecifyKind(dt, DateTimeKind.Utc)
                    Else
                        dt = dt.ToUniversalTime()
                    End If
                    Return dt
                End Using
            End Using
        Catch
            Return Nothing
        End Try
    End Function

    Private Function BuildXml(host As String, sig As CacheSignatureInfo, part As Integer) As String
        Dim urls As New List(Of Tuple(Of String, String, String, String))()

        ' Static + dynamic content
        AddStaticUrls(urls, host, sig)

        Dim fallbackUtc As Nullable(Of DateTime) = Nothing
        If sig IsNot Nothing Then fallbackUtc = sig.DataMaxUtc

        AddDynamicArticoliUrls(urls, host, fallbackUtc, sig)
        AddDynamicFacetUrls(urls, host, fallbackUtc)
        AddDynamicProductUrls(urls, host, fallbackUtc)

        ' Deduplicate + robots filter
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim filtered As New List(Of Tuple(Of String, String, String, String))()
        For Each t In urls
            Dim loc As String = t.Item1
            If String.IsNullOrEmpty(loc) Then Continue For
            If Not seen.Add(loc) Then Continue For
            If _alignRobotsDisallow AndAlso IsDisallowedByRobots(loc) Then Continue For
            filtered.Add(t)
        Next

        ' Split into parts (if needed)
        If part <= 0 AndAlso filtered.Count > _maxUrlsPerPart Then
            Return BuildIndexXml(host, sig, filtered.Count)
        End If

        If part > 0 Then
            Dim startIdx As Integer = (part - 1) * _maxUrlsPerPart
            Dim endIdx As Integer = Math.Min(startIdx + _maxUrlsPerPart, filtered.Count)
            If startIdx < 0 OrElse startIdx >= filtered.Count Then
                ' out-of-range part -> empty urlset
                filtered = New List(Of Tuple(Of String, String, String, String))()
            Else
                filtered = filtered.GetRange(startIdx, endIdx - startIdx)
            End If
        End If

        Dim sb As New StringBuilder()
        sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.AppendLine("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

        For Each t In filtered
            sb.AppendLine("  <url>")
            sb.AppendLine("    <loc>" & XmlEscape(t.Item1) & "</loc>")
            If Not String.IsNullOrEmpty(t.Item2) Then
                sb.AppendLine("    <lastmod>" & XmlEscape(t.Item2) & "</lastmod>")
            End If
            If Not String.IsNullOrEmpty(t.Item3) Then
                sb.AppendLine("    <changefreq>" & XmlEscape(t.Item3) & "</changefreq>")
            End If
            If Not String.IsNullOrEmpty(t.Item4) Then
                sb.AppendLine("    <priority>" & XmlEscape(t.Item4) & "</priority>")
            End If
            sb.AppendLine("  </url>")
        Next

        sb.AppendLine("</urlset>")
        Return sb.ToString()
    End Function

    Private Function BuildIndexXml(host As String, sig As CacheSignatureInfo, totalUrls As Integer) As String
        Dim parts As Integer = CInt(Math.Ceiling(totalUrls / CDbl(_maxUrlsPerPart)))
        If parts < 1 Then parts = 1

        Dim sb As New StringBuilder()
        sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.AppendLine("<sitemapindex xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

        For i As Integer = 1 To parts
            Dim loc As String = host.TrimEnd("/"c) & "/sitemap.aspx?part=" & i.ToString()
            sb.AppendLine("  <sitemap>")
            sb.AppendLine("    <loc>" & XmlEscape(loc) & "</loc>")
            If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
                sb.AppendLine("    <lastmod>" & sig.DataMaxUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) & "</lastmod>")
            End If
            sb.AppendLine("  </sitemap>")
        Next

        sb.AppendLine("</sitemapindex>")
        Return sb.ToString()
    End Function

    Private Sub AddStaticUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, sig As CacheSignatureInfo)
        Dim lastMod As String = ""
        If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
            lastMod = sig.DataMaxUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
        End If

        Dim homePath As String = GetAppSetting("KeepStore.Sitemap.Home", "/")
        If String.IsNullOrEmpty(homePath) Then homePath = "/"
        urls.Add(Tuple.Create(CombineUrl(host, homePath), lastMod, "daily", "1.0"))

        ' Add some common static pages if present
        Dim staticCsv As String = GetAppSetting("KeepStore.Sitemap.StaticPaths", "/about.html,/contact.html,/privacy.html")
        For Each p As String In staticCsv.Split(","c)
            Dim pp As String = If(p, "").Trim()
            If pp = "" Then Continue For
            urls.Add(Tuple.Create(CombineUrl(host, pp), lastMod, "weekly", "0.6"))
        Next
    End Sub

    Private Sub AddDynamicArticoliUrls(urls As List(Of Tuple(Of String, String, String, String)),
                                       host As String,
                                       Optional fallbackUtc As Nullable(Of DateTime) = Nothing,
                                       Optional sig As CacheSignatureInfo = Nothing)

        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Return

        Dim viewName As String = GetAppSetting("KeepStore.Sitemap.DbView.Articoli", "v_sitemap_articoli")

        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As MySqlCommand = CreateCommand(conn, "SELECT url, last_mod FROM " & viewName & " ORDER BY url")
                    Using rd As MySqlDataReader = cmd.ExecuteReader()
                        While rd.Read()
                            Dim u As String = SafeDbString(rd, 0)
                            If String.IsNullOrEmpty(u) Then Continue While

                            Dim lmUtc As Nullable(Of DateTime) = SafeDbDateUtc(rd, 1)
                            Dim lm As String = ""
                            If lmUtc.HasValue Then
                                lm = lmUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            ElseIf fallbackUtc.HasValue Then
                                lm = fallbackUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            End If

                            urls.Add(Tuple.Create(NormalizeUrl(host, u), lm, "weekly", "0.7"))
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' Ignore DB issues; sitemap should still return static urls
        End Try
    End Sub

    Private Sub AddDynamicFacetUrls(urls As List(Of Tuple(Of String, String, String, String)),
                                    host As String,
                                    Optional fallbackUtc As Nullable(Of DateTime) = Nothing)

        If Not GetAppSettingBool("KeepStore.Sitemap.IncludeCatalogFacets", False) Then Return

        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Return

        Dim viewName As String = GetAppSetting("KeepStore.Sitemap.DbView.Facets", "v_sitemap_facets")

        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As MySqlCommand = CreateCommand(conn, "SELECT url, last_mod FROM " & viewName & " ORDER BY url")
                    Using rd As MySqlDataReader = cmd.ExecuteReader()
                        While rd.Read()
                            Dim u As String = SafeDbString(rd, 0)
                            If String.IsNullOrEmpty(u) Then Continue While

                            Dim lmUtc As Nullable(Of DateTime) = SafeDbDateUtc(rd, 1)
                            Dim lm As String = ""
                            If lmUtc.HasValue Then
                                lm = lmUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            ElseIf fallbackUtc.HasValue Then
                                lm = fallbackUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            End If

                            urls.Add(Tuple.Create(NormalizeUrl(host, u), lm, "weekly", "0.5"))
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try
    End Sub

    Private Sub AddDynamicProductUrls(urls As List(Of Tuple(Of String, String, String, String)),
                                      host As String,
                                      Optional fallbackUtc As Nullable(Of DateTime) = Nothing)

        If Not GetAppSettingBool("KeepStore.Sitemap.IncludeProductDetails", False) Then Return

        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Return

        Dim viewName As String = GetAppSetting("KeepStore.Sitemap.DbView.Products", "v_sitemap_products")

        Try
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Using cmd As MySqlCommand = CreateCommand(conn, "SELECT url, last_mod FROM " & viewName & " ORDER BY url")
                    Using rd As MySqlDataReader = cmd.ExecuteReader()
                        While rd.Read()
                            Dim u As String = SafeDbString(rd, 0)
                            If String.IsNullOrEmpty(u) Then Continue While

                            Dim lmUtc As Nullable(Of DateTime) = SafeDbDateUtc(rd, 1)
                            Dim lm As String = ""
                            If lmUtc.HasValue Then
                                lm = lmUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            ElseIf fallbackUtc.HasValue Then
                                lm = fallbackUtc.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                            End If

                            urls.Add(Tuple.Create(NormalizeUrl(host, u), lm, "weekly", "0.8"))
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try
    End Sub

    ' ----------------------------
    ' DB helpers
    ' ----------------------------
    Private Function GetConnectionString() As String
        Dim name As String = GetAppSetting("KeepStore.Sitemap.Db.ConnectionStringName", "EntropicConnectionString")
        Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings(name)
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then Return Nothing
        Return cs.ConnectionString
    End Function

    Private Function CreateCommand(conn As MySqlConnection, sql As String) As MySqlCommand
        Dim cmd As New MySqlCommand(sql, conn)
        cmd.CommandTimeout = GetAppSettingInt("KeepStore.Sitemap.Db.CommandTimeoutSec", 30)
        Return cmd
    End Function

    Private Shared Function SafeDbString(rd As MySqlDataReader, ordinal As Integer) As String
        If rd Is Nothing Then Return ""
        If rd.IsDBNull(ordinal) Then Return ""
        Return Convert.ToString(rd.GetValue(ordinal))
    End Function

    Private Shared Function SafeDbDateUtc(rd As MySqlDataReader, ordinal As Integer) As Nullable(Of DateTime)
        If rd Is Nothing OrElse rd.IsDBNull(ordinal) Then Return Nothing
        Dim o As Object = rd.GetValue(ordinal)
        Dim dt As DateTime

        If TypeOf o Is DateTime Then
            dt = CType(o, DateTime)
        Else
            If Not DateTime.TryParse(Convert.ToString(o), dt) Then Return Nothing
        End If

        If dt.Kind = DateTimeKind.Unspecified Then
            dt = DateTime.SpecifyKind(dt, DateTimeKind.Utc)
        Else
            dt = dt.ToUniversalTime()
        End If
        Return dt
    End Function

    ' ----------------------------
    ' URL + XML helpers
    ' ----------------------------
    Private Shared Function CombineUrl(host As String, path As String) As String
        Dim h As String = If(host, "").TrimEnd("/"c)
        Dim p As String = If(path, "")
        If p = "" Then p = "/"
        If Not p.StartsWith("/") AndAlso Not p.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            p = "/" & p
        End If
        If p.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            Return p
        End If
        Return h & p
    End Function

    Private Shared Function NormalizeUrl(host As String, u As String) As String
        Dim s As String = If(u, "").Trim()
        If s = "" Then Return ""
        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If
        Return CombineUrl(host, s)
    End Function

    Private Shared Function XmlEscape(s As String) As String
        If s Is Nothing Then Return ""
        Return System.Security.SecurityElement.Escape(s)
    End Function

End Class
