Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient
Imports System.Text.RegularExpressions

Partial Class sitemap
    Inherits System.Web.UI.Page

    Private Const DEFAULT_TTL_MINUTES As Integer = 1440
    Private Const DEFAULT_FALLBACK_LASTMOD_DAYS As Integer = 7
    Private _fileCacheEnabled As Boolean
    Private _fileCacheTtlMinutes As Integer
    Private _fileCachePath As String
    Private _fromDbLastMod As Boolean
    Private _fallbackLastModDays As Integer
    Private _homePath As String
    Private _listingPath As String
    Private _staticUrls As List(Of String)

    ' Audit (optional) and Robots alignment
    Private _auditEnabled As Boolean
    Private _auditToken As String
    Private _disallowRegex As List(Of Regex)

    Private Class CacheSignatureInfo
        Public Property Signature As String
        Public Property DataMaxUtc As Nullable(Of DateTime)
    End Class

    Private Class UrlLastModInfo
    Public Property Url As String
    Public Property LastModUtc As Nullable(Of DateTime)
    Public Property HasExplicitLastMod As Boolean

    Public Sub New()
    End Sub

    Public Sub New(url As String, lastModUtc As Nullable(Of DateTime))
        Me.Url = url
        Me.LastModUtc = lastModUtc
    End Sub
End Class


    Protected Sub Page_Init(sender As Object, e As EventArgs) Handles Me.Init
        ' Config (appSettings)
        _fileCacheEnabled = GetBoolAppSetting("KeepStore.Sitemap.FileCache.Enabled", True)
        _fileCacheTtlMinutes = GetIntAppSetting("KeepStore.Sitemap.FileCache.TtlMinutes", DEFAULT_TTL_MINUTES)
        _fileCachePath = GetStringAppSetting("KeepStore.Sitemap.FileCache.Path", "~/App_Data/Sitemaps")

        _fromDbLastMod = GetBoolAppSetting("KeepStore.Sitemap.LastMod.FromDb", True)
        _fallbackLastModDays = GetIntAppSetting("KeepStore.Sitemap.LastMod.FallbackDays", DEFAULT_FALLBACK_LASTMOD_DAYS)

        _homePath = NormalizePath(GetStringAppSetting("KeepStore.Sitemap.Home", "default.aspx"))
        _listingPath = NormalizePath(GetStringAppSetting("KeepStore.Sitemap.Listing", "articoli.aspx"))

        _staticUrls = New List(Of String)()
        _staticUrls.Add(_homePath)
        _staticUrls.Add(_listingPath)
        _staticUrls.Add("about.aspx")
        _staticUrls.Add("contact.aspx")
        _staticUrls.Add("privacy.aspx")
        _staticUrls.Add("faq.aspx")
        _staticUrls.Add("track-your-order.aspx")
' Audit (optional)
_auditEnabled = GetBoolAppSetting("KeepStore.Sitemap.Audit.Enabled", False)
_auditToken = GetStringAppSetting("KeepStore.Sitemap.Audit.Token", "")

' Robots Disallow alignment (optional)
_disallowRegex = LoadDisallowRegexFromRobots()
If _disallowRegex Is Nothing Then _disallowRegex = New List(Of Regex)()

    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
    Dim host As String = GetHost()

    ' Optional audit endpoint: sitemap.aspx?audit=1&token=...
    If String.Equals(Request.QueryString("audit"), "1", StringComparison.Ordinal) Then
        If Not IsAuditAllowed() Then
            Response.StatusCode = 404
            Response.End()
            Return
        End If

        Response.ContentType = "text/plain"
        Response.Charset = "utf-8"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()

        Response.Write(BuildAuditReport(host))
        Return
    End If

    Response.ContentType = "application/xml"
    Response.Charset = "utf-8"

    Dim sig As CacheSignatureInfo = Nothing
    If _fileCacheEnabled Then
        sig = ComputeCacheSignature(host)
        If TryServeFromCache(host, sig) Then
            Return
        End If
    End If

    Dim xml As String = BuildXml(host, sig)

    If _fileCacheEnabled Then
        WriteCache(host, sig, xml)
    End If

    Response.Write(xml)
End Sub


    Private Function BuildXml(host As String, sig As CacheSignatureInfo) As String
        Dim urls As New List(Of Tuple(Of String, String, String, String))()

        Dim globalLastModUtc As Nullable(Of DateTime) = Nothing
        If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
            globalLastModUtc = sig.DataMaxUtc
        ElseIf _fromDbLastMod Then
            globalLastModUtc = GetSitemapDataMaxUtc()
        End If

        Dim fallbackUtc As Nullable(Of DateTime) = Nothing
        If _fromDbLastMod Then
            If globalLastModUtc.HasValue Then
                fallbackUtc = globalLastModUtc
            Else
                fallbackUtc = DateTime.UtcNow.AddDays(-_fallbackLastModDays)
            End If
        End If

        ' Static URLs (home + listing + static pages)
        AddStaticUrls(urls, host, fallbackUtc)

        ' Dynamic URLs
        AddDynamicArticoliUrls(urls, host)
        AddDynamicCategoryUrls(urls, host, globalLastModUtc)

        Dim sb As New StringBuilder()
        sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.Append(vbCrLf)
        sb.Append("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")
        sb.Append(vbCrLf)

        For Each t As Tuple(Of String, String, String, String) In urls
            sb.Append("  <url>")
            sb.Append(vbCrLf)

            sb.Append("    <loc>")
            sb.Append(HttpUtility.HtmlEncode(t.Item1))
            sb.Append("</loc>")
            sb.Append(vbCrLf)

            If Not String.IsNullOrEmpty(t.Item2) Then
                sb.Append("    <lastmod>")
                sb.Append(t.Item2)
                sb.Append("</lastmod>")
                sb.Append(vbCrLf)
            End If

            If Not String.IsNullOrEmpty(t.Item3) Then
                sb.Append("    <changefreq>")
                sb.Append(t.Item3)
                sb.Append("</changefreq>")
                sb.Append(vbCrLf)
            End If

            If Not String.IsNullOrEmpty(t.Item4) Then
                sb.Append("    <priority>")
                sb.Append(t.Item4)
                sb.Append("</priority>")
                sb.Append(vbCrLf)
            End If

            sb.Append("  </url>")
            sb.Append(vbCrLf)
        Next

        sb.Append("</urlset>")
        sb.Append(vbCrLf)

        Return sb.ToString()
    End Function

    Private Sub AddStaticUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, lastModUtc As Nullable(Of DateTime))
        ' Home
        AddUrl(urls, MakeAbsolute(host, _homePath), FormatAsW3C(lastModUtc), "daily", "1.0")

        ' Listing (articoli.aspx) -> lastmod "reale" (MAX(data))
        AddUrl(urls, MakeAbsolute(host, _listingPath), FormatAsW3C(lastModUtc), "daily", "0.9")

' Other static pages
For Each rel As String In _staticUrls
    If rel.Equals(_homePath, StringComparison.OrdinalIgnoreCase) OrElse rel.Equals(_listingPath, StringComparison.OrdinalIgnoreCase) Then
        Continue For
    End If

    ' Best-effort: do not emit static URLs that don't exist physically (prevents sitemap 404 noise)
    Try
        Dim relPhys As String = "~/" & rel.TrimStart("/"c)
        Dim phys As String = Server.MapPath(relPhys)
        If Not String.IsNullOrEmpty(phys) AndAlso Not File.Exists(phys) Then
            Continue For
        End If
    Catch
        ' ignore (keep URL)
    End Try

    AddUrl(urls, MakeAbsolute(host, rel), FormatAsW3C(lastModUtc), "monthly", "0.4")
Next
    End Sub

    Private Sub AddDynamicArticoliUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, Optional fallbackUtc As Nullable(Of DateTime) = Nothing, Optional sig As String = Nothing, Optional bypassRobots As Boolean = False)
        For Each row As Tuple(Of String, Nullable(Of DateTime)) In QueryUrlAndLastMod("v_sitemap_prodotti")
            Dim absUrl As String = MakeAbsolute(host, row.Item1)
            Dim lastmod As String = FormatAsW3C(row.Item2)
            AddUrl(urls, absUrl, lastmod, "weekly", "0.7")
        Next
    End Sub

    Private Sub AddDynamicCategoryUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, globalLastModUtc As Nullable(Of DateTime))
        Dim catMap As Dictionary(Of Integer, DateTime) = Nothing
        If _fromDbLastMod Then
            catMap = GetCategoryLastModUtcMap()
        End If

        For Each row As UrlLastModInfo In QueryUrlAndLastModInfo("v_sitemap_categorie")
            Dim urlRel As String = row.Url
            Dim lastModUtc As Nullable(Of DateTime) = row.LastModUtc

            ' Se la vista NON fornisce last_mod (o è NULL), provo a ricavarlo dalla categoria (ct=)
            If _fromDbLastMod AndAlso (Not row.HasExplicitLastMod) Then
                Dim ct As Integer
                If catMap IsNot Nothing AndAlso TryGetIntParamFromUrl(urlRel, "ct", ct) Then
                    If catMap.ContainsKey(ct) Then
                        lastModUtc = catMap(ct)
                    ElseIf globalLastModUtc.HasValue Then
                        lastModUtc = globalLastModUtc
                    End If
                ElseIf globalLastModUtc.HasValue Then
                    lastModUtc = globalLastModUtc
                End If
            End If

            Dim absUrl As String = MakeAbsolute(host, urlRel)
            AddUrl(urls, absUrl, FormatAsW3C(lastModUtc), "weekly", "0.6")
        Next
    End Sub
' Compatibility wrapper: older patches referenced AddDynamicFacetUrls.
Private Sub AddDynamicFacetUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, globalLastModUtc As Nullable(Of DateTime))
    AddDynamicCategoryUrls(urls, host, globalLastModUtc)
End Sub


    Private Sub AddUrl(urls As List(Of Tuple(Of String, String, String, String)), loc As String, lastmodW3c As String, changefreq As String, priority As String)
    If urls Is Nothing Then Return
    If String.IsNullOrEmpty(loc) Then Return

    ' Skip URLs disallowed by robots.txt (best-effort)
    If IsDisallowedByRobots(loc) Then
        Return
    End If

    ' De-duplicate (per-request)
    Dim key As String = "__KS_SITEMAP_SEEN__"
    Dim seen As HashSet(Of String) = TryCast(Context.Items(key), HashSet(Of String))
    If seen Is Nothing Then
        seen = New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Context.Items(key) = seen
    End If
    If seen.Contains(loc) Then Return
    seen.Add(loc)

    urls.Add(New Tuple(Of String, String, String, String)(loc, lastmodW3c, changefreq, priority))
End Sub


    '---------------- DB: URL + last_mod ----------------

    Private Function QueryUrlAndLastMod(viewName As String) As IEnumerable(Of Tuple(Of String, Nullable(Of DateTime)))
    Dim list As New List(Of Tuple(Of String, Nullable(Of DateTime)))()
    For Each info As UrlLastModInfo In QueryUrlAndLastModInfo(viewName)
        list.Add(New Tuple(Of String, Nullable(Of DateTime))(info.Url, info.LastModUtc))
    Next
    Return list
End Function


    Private Function QueryUrlAndLastModInfo(viewName As String) As List(Of UrlLastModInfo)
    Dim res As New List(Of UrlLastModInfo)()
    If String.IsNullOrWhiteSpace(viewName) Then Return res

    Dim cs As String = GetConnectionString()
    If String.IsNullOrEmpty(cs) Then Return res

    Try
        Using conn As New MySqlConnection(cs)
            conn.Open()
            Using cmd As MySqlCommand = CreateCommand(conn, "SELECT url, last_mod FROM " & viewName & " ORDER BY url")
                Using rd As MySqlDataReader = cmd.ExecuteReader()
                    While rd.Read()
                        Dim u As String = Convert.ToString(rd("url"))
                        If String.IsNullOrWhiteSpace(u) Then Continue While

                        Dim lmUtc As Nullable(Of DateTime) = Nothing
                        Dim hasLm As Boolean = False
                        Try
                            Dim ordLm As Integer = rd.GetOrdinal("last_mod")
                            If ordLm >= 0 AndAlso Not rd.IsDBNull(ordLm) Then
                                Dim dt As DateTime = Convert.ToDateTime(rd.GetValue(ordLm))
                                lmUtc = DateTime.SpecifyKind(dt, DateTimeKind.Utc)
                                hasLm = True
                            End If
                        Catch
                            ' ignore
                        End Try

                        Dim info As New UrlLastModInfo(u, lmUtc)
                        info.HasExplicitLastMod = hasLm
                        res.Add(info)
                    End While
                End Using
            End Using
        End Using
    Catch
        ' If the view/table doesn't exist or DB is down, keep sitemap functional.
    End Try

    Return res
End Function


    Private Function GetCategoryLastModUtcMap() As Dictionary(Of Integer, DateTime)
        Dim map As New Dictionary(Of Integer, DateTime)()

        ' lastmod "reale" per categoria: MAX(DataCreazione) degli articoli
        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand("SELECT CategoriaId, MAX(DataCreazione) AS last_mod FROM articoli GROUP BY CategoriaId", cn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            If r.IsDBNull(0) OrElse r.IsDBNull(1) Then
                                Continue While
                            End If

                            Dim ct As Integer
                            If Not Integer.TryParse(Convert.ToString(r.GetValue(0)), ct) Then
                                Continue While
                            End If

                            Dim dt As DateTime = Convert.ToDateTime(r.GetValue(1))
                            map(ct) = dt.ToUniversalTime()
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' best-effort
        End Try

        Return map
    End Function

    Private Function TryGetIntParamFromUrl(url As String, key As String, ByRef value As Integer) As Boolean
        value = 0
        If String.IsNullOrEmpty(url) Then Return False

        Dim idx As Integer = url.IndexOf("?"c)
        If idx < 0 Then Return False

        Dim query As String = url.Substring(idx + 1)
        Dim nvc As System.Collections.Specialized.NameValueCollection = HttpUtility.ParseQueryString(query)
        Dim s As String = nvc(key)

        If String.IsNullOrEmpty(s) Then Return False
        Return Integer.TryParse(s, value)
    End Function

    Private Function ParseUtc(obj As Object) As Nullable(Of DateTime)
        If obj Is Nothing OrElse obj Is DBNull.Value Then Return Nothing
        Try
            Dim dt As DateTime = Convert.ToDateTime(obj)
            Return dt.ToUniversalTime()
        Catch
            Return Nothing
        End Try
    End Function

    '---------------- Cache signature: invalidazione su MAX(data) ----------------

    Private Function ComputeCacheSignature(host As String) As CacheSignatureInfo
        Dim info As New CacheSignatureInfo()

        Dim maxUtc As Nullable(Of DateTime) = Nothing
        If _fromDbLastMod Then
            maxUtc = GetSitemapDataMaxUtc()
        End If

        info.DataMaxUtc = maxUtc

        ' Firma cache: se riesco a calcolare il MAX(data), uso host + MAX(data) come invalidazione.
        ' Se NON riesco a calcolare il MAX(data), lascio Signature vuota e uso la logica TTL (fallback).
        If maxUtc.HasValue Then
            info.Signature = host.ToLowerInvariant() & "|" & maxUtc.Value.ToString("yyyyMMddHHmmss")
        Else
            info.Signature = ""
        End If

        Return info
    End Function

    Private Function GetSitemapDataMaxUtc() As Nullable(Of DateTime)
        Dim maxUtc As Nullable(Of DateTime) = Nothing

        ' 1) Tabella "aggiornamentodb" (se mantenuta aggiornata dai processi di import/sync)
        Dim dt As Nullable(Of DateTime) = TryGetMaxUtc("SELECT MAX(UltimoAggiornamento) FROM aggiornamentodb")
        If dt.HasValue Then
            maxUtc = dt
        End If

        ' 2) Fallback: MAX(DataCreazione) su articoli
        If Not maxUtc.HasValue Then
            dt = TryGetMaxUtc("SELECT MAX(DataCreazione) FROM articoli")
            If dt.HasValue Then
                maxUtc = dt
            End If
        End If

        ' 3) Fallback ulteriori: viste sitemap (se hanno last_mod)
        If Not maxUtc.HasValue Then
            dt = TryGetMaxUtc("SELECT MAX(last_mod) FROM v_sitemap_prodotti")
            If dt.HasValue Then
                maxUtc = dt
            End If
        End If

        If Not maxUtc.HasValue Then
            dt = TryGetMaxUtc("SELECT MAX(last_mod) FROM v_sitemap_categorie")
            If dt.HasValue Then
                maxUtc = dt
            End If
        End If

        Return maxUtc
    End Function

    Private Function TryGetMaxUtc(sql As String) As Nullable(Of DateTime)
        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand(sql, cn)
                    Dim obj As Object = cmd.ExecuteScalar()
                    If obj Is Nothing OrElse obj Is DBNull.Value Then
                        Return Nothing
                    End If
                    Dim dt As DateTime = Convert.ToDateTime(obj)
                    Return dt.ToUniversalTime()
                End Using
            End Using
        Catch
            Return Nothing
        End Try
    End Function

    '---------------- File cache ----------------

    Private Function TryServeFromCache(host As String, sig As CacheSignatureInfo) As Boolean
        Dim dirPath As String = Server.MapPath(_fileCachePath)
        If String.IsNullOrEmpty(dirPath) Then Return False

        Dim xmlPath As String = Path.Combine(dirPath, "sitemap.xml")
        Dim metaPath As String = Path.Combine(dirPath, "sitemap.meta")

        If Not File.Exists(xmlPath) Then Return False
        If Not File.Exists(metaPath) Then Return False

        Try
            Dim meta As Dictionary(Of String, String) = ReadMeta(metaPath)

            Dim cachedHost As String = Nothing
            If meta.ContainsKey("Host") Then cachedHost = meta("Host")

            Dim cachedSignature As String = Nothing
            If meta.ContainsKey("Signature") Then cachedSignature = meta("Signature")

            Dim cachedGeneratedUtc As Nullable(Of DateTime) = Nothing
            If meta.ContainsKey("GeneratedUtc") Then
                Dim tmp As DateTime
                If DateTime.TryParse(meta("GeneratedUtc"), tmp) Then
                    cachedGeneratedUtc = DateTime.SpecifyKind(tmp, DateTimeKind.Utc)
                End If
            End If

            ' Modalità "intelligente": confronto signature (MAX(data))
            If sig IsNot Nothing AndAlso Not String.IsNullOrEmpty(sig.Signature) Then
                If String.Equals(cachedSignature, sig.Signature, StringComparison.Ordinal) AndAlso String.Equals(cachedHost, host, StringComparison.OrdinalIgnoreCase) Then
                    Response.Write(File.ReadAllText(xmlPath, Encoding.UTF8))
                    Return True
                End If
            Else
                ' Fallback: TTL (comportamento legacy)
                If cachedGeneratedUtc.HasValue Then
                    Dim ageMinutes As Double = (DateTime.UtcNow - cachedGeneratedUtc.Value).TotalMinutes
                    If ageMinutes <= _fileCacheTtlMinutes Then
                        Response.Write(File.ReadAllText(xmlPath, Encoding.UTF8))
                        Return True
                    End If
                End If
            End If

        Catch
            ' ignore and regenerate
        End Try

        Return False
    End Function

    Private Sub WriteCache(host As String, sig As CacheSignatureInfo, xml As String)
        Dim dirPath As String = Server.MapPath(_fileCachePath)
        If String.IsNullOrEmpty(dirPath) Then Return

        If Not Directory.Exists(dirPath) Then
            Directory.CreateDirectory(dirPath)
        End If

        Dim xmlPath As String = Path.Combine(dirPath, "sitemap.xml")
        Dim metaPath As String = Path.Combine(dirPath, "sitemap.meta")

        Try
            File.WriteAllText(xmlPath, xml, Encoding.UTF8)

            Dim sb As New StringBuilder()
            sb.AppendLine("GeneratedUtc=" & DateTime.UtcNow.ToString("o"))
            sb.AppendLine("Host=" & host)

            If sig IsNot Nothing AndAlso Not String.IsNullOrEmpty(sig.Signature) Then
                sb.AppendLine("Signature=" & sig.Signature)
            Else
                sb.AppendLine("Signature=")
            End If

            If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
                sb.AppendLine("DataMaxUtc=" & sig.DataMaxUtc.Value.ToString("o"))
            Else
                sb.AppendLine("DataMaxUtc=")
            End If

            File.WriteAllText(metaPath, sb.ToString(), Encoding.UTF8)
        Catch
            ' ignore
        End Try
    End Sub

    Private Function ReadMeta(metaPath As String) As Dictionary(Of String, String)
        Dim dict As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        Dim lines() As String = File.ReadAllLines(metaPath, Encoding.UTF8)

        For Each line As String In lines
            If String.IsNullOrEmpty(line) Then Continue For
            Dim idx As Integer = line.IndexOf("="c)
            If idx <= 0 Then Continue For

            Dim k As String = line.Substring(0, idx).Trim()
            Dim v As String = line.Substring(idx + 1).Trim()
            dict(k) = v
        Next

        Return dict
    End Function

    '---------------- Helpers ----------------

    Private Function FormatAsW3C(dtUtc As Nullable(Of DateTime)) As String
        If Not dtUtc.HasValue Then Return Nothing
        Dim utc As DateTime = DateTime.SpecifyKind(dtUtc.Value, DateTimeKind.Utc)
        Return utc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    End Function

    Private Function GetHost() As String
        Dim uri As Uri = Request.Url
        Return uri.Scheme & "://" & uri.Authority
    End Function

    Private Function MakeAbsolute(host As String, url As String) As String
        If String.IsNullOrEmpty(url) Then Return host & "/"

        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If

        Dim rel As String = url.Trim()
        If rel.StartsWith("~/", StringComparison.Ordinal) Then
            rel = rel.Substring(2)
        End If

        If Not rel.StartsWith("/", StringComparison.Ordinal) Then
            rel = "/" & rel
        End If

        Return host & rel
    End Function

    Private Function NormalizePath(path As String) As String
        If String.IsNullOrEmpty(path) Then Return ""
        Dim p As String = path.Trim()

        If p.StartsWith("~/", StringComparison.Ordinal) Then
            p = p.Substring(2)
        End If
        If p.StartsWith("/", StringComparison.Ordinal) Then
            p = p.Substring(1)
        End If

        Return p
    End Function

    Private Function GetConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function

    
' =========================
' Robots.txt alignment
' =========================

Private Function LoadDisallowRegexFromRobots() As List(Of Regex)
    Dim res As New List(Of Regex)()

    Try
        Dim robotsPhys As String = Nothing

        ' Prefer HttpContext.Current to avoid edge cases.
        Dim ctx As HttpContext = HttpContext.Current
        If ctx IsNot Nothing Then
            Try
                robotsPhys = ctx.Server.MapPath("~/robots.txt")
            Catch
            End Try
        End If

        If String.IsNullOrEmpty(robotsPhys) Then
            Try
                robotsPhys = Server.MapPath("~/robots.txt")
            Catch
            End Try
        End If

        If String.IsNullOrEmpty(robotsPhys) OrElse Not File.Exists(robotsPhys) Then Return res

        Dim currentAgents As New List(Of String)()
        Dim currentDisallow As New List(Of String)()
        Dim hasDirective As Boolean = False

        For Each raw As String In File.ReadAllLines(robotsPhys)
            Dim line As String = raw
            If line Is Nothing Then Continue For

            ' Strip comments
            Dim hashIdx As Integer = line.IndexOf("#"c)
            If hashIdx >= 0 Then line = line.Substring(0, hashIdx)

            line = line.Trim()
            If line.Length = 0 Then
                ' blank line separates groups
                If hasDirective Then FinalizeRobotsGroup(currentAgents, currentDisallow, res, hasDirective)
                Continue For
            End If

            Dim colonIdx As Integer = line.IndexOf(":"c)
            If colonIdx <= 0 Then Continue For

            Dim key As String = line.Substring(0, colonIdx).Trim().ToLowerInvariant()
            Dim value As String = ""
            If colonIdx + 1 < line.Length Then value = line.Substring(colonIdx + 1).Trim()

            If key = "user-agent" Then
                ' If directives were already seen, a new user-agent starts a new group.
                If hasDirective Then FinalizeRobotsGroup(currentAgents, currentDisallow, res, hasDirective)
                currentAgents.Add(value)
            ElseIf key = "disallow" Then
                hasDirective = True
                currentDisallow.Add(value)
            ElseIf key = "allow" Then
                ' We ignore Allow (sitemap filtering is conservative). Audit output still shows what gets excluded.
                hasDirective = True
            Else
                ' ignore
            End If
        Next

        If currentAgents.Count > 0 OrElse currentDisallow.Count > 0 Then
            FinalizeRobotsGroup(currentAgents, currentDisallow, res, hasDirective)
        End If

    Catch
        ' ignore
    End Try

    Return res
End Function

Private Sub FinalizeRobotsGroup(currentAgents As List(Of String), currentDisallow As List(Of String), res As List(Of Regex), ByRef hasDirective As Boolean)
    If currentAgents Is Nothing OrElse currentAgents.Count = 0 Then
        If currentAgents IsNot Nothing Then currentAgents.Clear()
        If currentDisallow IsNot Nothing Then currentDisallow.Clear()
        hasDirective = False
        Return
    End If

    Dim appliesToAll As Boolean = False
    For Each a As String In currentAgents
        If String.Equals(a, "*", StringComparison.OrdinalIgnoreCase) Then
            appliesToAll = True
            Exit For
        End If
    Next

    If appliesToAll AndAlso currentDisallow IsNot Nothing Then
        For Each rule As String In currentDisallow
            Dim rx As Regex = RobotsPatternToRegex(rule)
            If rx IsNot Nothing Then res.Add(rx)
        Next
    End If

    currentAgents.Clear()
    currentDisallow.Clear()
    hasDirective = False
End Sub


Private Function RobotsPatternToRegex(rule As String) As Regex
    If rule Is Nothing Then Return Nothing

    Dim pat As String = rule.Trim()
    If pat.Length = 0 Then Return Nothing ' empty Disallow => allow all
    If pat = "/" Then pat = "/*" ' disallow everything

    ' Support wildcard (*) and end-anchor ($) as commonly used in robots.txt
    Dim endAnchor As Boolean = False
    If pat.EndsWith("$") Then
        endAnchor = True
        pat = pat.Substring(0, pat.Length - 1)
    End If

    Dim rxPat As String = Regex.Escape(pat).Replace("\*", ".*")
    rxPat = "^" & rxPat
    If endAnchor Then rxPat &= "$"

    Return New Regex(rxPat, RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant)
End Function

Private Function IsDisallowedByRobots(loc As String) As Boolean
    If _disallowRegex Is Nothing OrElse _disallowRegex.Count = 0 Then Return False
    If String.IsNullOrWhiteSpace(loc) Then Return False

    Dim pathAndQuery As String = loc

    Try
        Dim u As Uri = Nothing
        If Uri.TryCreate(loc, UriKind.Absolute, u) AndAlso u IsNot Nothing Then
            pathAndQuery = u.PathAndQuery
        End If
    Catch
        ' keep raw loc
    End Try

    If String.IsNullOrWhiteSpace(pathAndQuery) Then Return False

    For Each rx As Regex In _disallowRegex
        If rx IsNot Nothing AndAlso rx.IsMatch(pathAndQuery) Then
            Return True
        End If
    Next

    Return False
End Function

' =========================
' Audit endpoint
' =========================

Private Function IsAuditAllowed() As Boolean
    If Not _auditEnabled Then Return False

    Try
        If Request IsNot Nothing AndAlso Request.IsLocal Then
            Return True
        End If
    Catch
    End Try

    If String.IsNullOrEmpty(_auditToken) OrElse _auditToken.Length < 8 Then Return False
    Dim t As String = Convert.ToString(Request.QueryString("token"))
    Return String.Equals(t, _auditToken, StringComparison.Ordinal)
End Function

Private Function BuildAuditReport(host As String) As String
    Dim sb As New StringBuilder()

    sb.AppendLine("KeepStore Sitemap Audit")
    sb.AppendLine("UTC Now: " & DateTime.UtcNow.ToString("u"))
    sb.AppendLine("Host: " & host)
    sb.AppendLine("Cache.Enabled: " & _fileCacheEnabled.ToString())
    sb.AppendLine("Cache.TtlMinutes: " & _fileCacheTtlMinutes.ToString())
    sb.AppendLine("Robots.DisallowRegex.Count: " & If(_disallowRegex Is Nothing, 0, _disallowRegex.Count).ToString())
    sb.AppendLine()

    Dim sig As String = ""
    Try
        sig = ComputeCacheSignature(host)
    Catch
        sig = ""
    End Try

    Dim filteredXml As String = ""
    Dim filteredLocs As New List(Of String)()
    Try
        filteredXml = BuildXml(host, sig)
        filteredLocs = ExtractLocsFromXml(filteredXml)
    Catch
    End Try

    ' Build an "unfiltered" sitemap by temporarily disabling robots filtering
    Dim allLocs As New List(Of String)()
    Dim disallowed As New List(Of String)()
    Dim saved As List(Of Regex) = _disallowRegex

    Try
        _disallowRegex = New List(Of Regex)() ' disables filtering inside AddUrl()
        Dim allXml As String = BuildXml(host, sig & "_AUDIT_ALL")
        allLocs = ExtractLocsFromXml(allXml)
    Catch
    Finally
        _disallowRegex = saved
    End Try

    Try
        For Each u As String In allLocs
            If IsDisallowedByRobots(u) Then disallowed.Add(u)
        Next
    Catch
    End Try

    ' Verify filtered sitemap doesn't contain disallowed URLs
    Dim disallowedInFiltered As New List(Of String)()
    Try
        For Each u As String In filteredLocs
            If IsDisallowedByRobots(u) Then disallowedInFiltered.Add(u)
        Next
    Catch
    End Try

    sb.AppendLine("URLs (without robots filtering): " & allLocs.Count.ToString())
    sb.AppendLine("URLs disallowed by robots.txt: " & disallowed.Count.ToString())
    sb.AppendLine("URLs (final sitemap output): " & filteredLocs.Count.ToString())
    sb.AppendLine("Disallowed URLs still present in final sitemap: " & disallowedInFiltered.Count.ToString())
    sb.AppendLine()

    If disallowed.Count > 0 Then
        sb.AppendLine("First disallowed URLs (max 200):")
        Dim maxN As Integer = Math.Min(200, disallowed.Count)
        For i As Integer = 0 To maxN - 1
            sb.AppendLine(" - " & disallowed(i))
        Next
        sb.AppendLine()
    End If

    If disallowedInFiltered.Count > 0 Then
        sb.AppendLine("ERROR: Disallowed URLs found in final sitemap (max 200):")
        Dim maxN As Integer = Math.Min(200, disallowedInFiltered.Count)
        For i As Integer = 0 To maxN - 1
            sb.AppendLine(" - " & disallowedInFiltered(i))
        Next
        sb.AppendLine()
    End If

    Return sb.ToString()
End Function

Private Function ExtractLocsFromXml(xml As String) As List(Of String)
    Dim res As New List(Of String)()
    If String.IsNullOrEmpty(xml) Then Return res

    Try
        For Each m As Match In Regex.Matches(xml, "<loc>(.*?)</loc>", RegexOptions.IgnoreCase Or RegexOptions.Singleline)
            Dim v As String = m.Groups(1).Value
            If String.IsNullOrEmpty(v) Then Continue For
            Try
                v = HttpUtility.HtmlDecode(v)
            Catch
            End Try
            res.Add(v.Trim())
        Next
    Catch
    End Try

    Return res
End Function

Private Function GetStringAppSetting(key As String, defaultValue As String) As String
        Dim v As String = ConfigurationManager.AppSettings(key)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Return v.Trim()
    End Function

    Private Function GetBoolAppSetting(key As String, defaultValue As Boolean) As Boolean
        Dim v As String = ConfigurationManager.AppSettings(key)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Dim b As Boolean
        If Boolean.TryParse(v, b) Then Return b
        Return defaultValue
    End Function

    Private Function GetIntAppSetting(key As String, defaultValue As Integer) As Integer
        Dim v As String = ConfigurationManager.AppSettings(key)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Dim i As Integer
        If Integer.TryParse(v, i) Then Return i
        Return defaultValue
    End Function

End Class