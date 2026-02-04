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

' ---------------- Robots / Audit helpers ----------------

Private Function IsAuditAllowed() As Boolean
    If Not _auditEnabled Then Return False
    If String.IsNullOrEmpty(_auditToken) OrElse _auditToken.Length < 8 Then Return False

    Dim t As String = Convert.ToString(Request.QueryString("token"))
    If String.IsNullOrEmpty(t) Then Return False

    Return String.Equals(t, _auditToken, StringComparison.Ordinal)
End Function

Private Function BuildAuditReport(host As String) As String
    Dim sb As New StringBuilder()
    sb.AppendLine("KeepStore Sitemap Audit")
    sb.AppendLine("Host: " & host)
    sb.AppendLine("UtcNow: " & DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))
    sb.AppendLine("Cache.Enabled: " & _fileCacheEnabled.ToString())
    sb.AppendLine("Cache.TtlMinutes: " & _fileCacheTtlMinutes.ToString())
    sb.AppendLine("Robots.DisallowRegex.Count: " & If(_disallowRegex Is Nothing, 0, _disallowRegex.Count).ToString())

    Dim sig As CacheSignatureInfo = Nothing
    Dim urls As List(Of Tuple(Of String, String, String, String)) = CollectUrls(host, sig)

    sb.AppendLine("Sitemap.UrlCount: " & urls.Count.ToString())

    Dim mismatches As New List(Of String)()
    For Each t As Tuple(Of String, String, String, String) In urls
        Dim loc As String = t.Item1
        If IsDisallowedByRobots(loc) Then
            mismatches.Add(loc)
        End If
    Next

    sb.AppendLine("Mismatches (in sitemap but disallowed by robots): " & mismatches.Count.ToString())
    If mismatches.Count > 0 Then
        sb.AppendLine("First mismatches:")
        Dim maxN As Integer = Math.Min(200, mismatches.Count)
        For i As Integer = 0 To maxN - 1
            sb.AppendLine(mismatches(i))
        Next
    End If

    Return sb.ToString()
End Function

Private Function LoadDisallowRegexFromRobots() As List(Of Regex)
    Dim res As New List(Of Regex)()

    Try
        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Server Is Nothing Then Return res

        Dim robotsPhys As String = ctx.Server.MapPath("~/robots.txt")
        If String.IsNullOrEmpty(robotsPhys) OrElse Not File.Exists(robotsPhys) Then Return res

        Dim lines As String() = File.ReadAllLines(robotsPhys)

        Dim inStarGroup As Boolean = False
        Dim sawAnyUserAgent As Boolean = False

        For Each raw As String In lines
            Dim line As String = raw

            Dim hashPos As Integer = line.IndexOf("#"c)
            If hashPos >= 0 Then line = line.Substring(0, hashPos)

            line = line.Trim()
            If line.Length = 0 Then Continue For

            Dim colonPos As Integer = line.IndexOf(":"c)
            If colonPos <= 0 Then Continue For

            Dim key As String = line.Substring(0, colonPos).Trim().ToLowerInvariant()
            Dim val As String = line.Substring(colonPos + 1).Trim()

            If key = "user-agent" Then
                sawAnyUserAgent = True
                inStarGroup = String.Equals(val, "*", StringComparison.Ordinal)
            ElseIf key = "disallow" Then
                ' Consider only the "*" group. If robots.txt has no UA headers, treat it as global.
                If (Not sawAnyUserAgent) OrElse inStarGroup Then
                    If String.IsNullOrEmpty(val) Then Continue For ' empty Disallow means "allow all"
                    Dim rx As Regex = RobotsPatternToRegex(val)
                    If rx IsNot Nothing Then res.Add(rx)
                End If
            End If
        Next
    Catch
        ' Non bloccare sitemap se robots.txt è assente o non leggibile
    End Try

    Return res
End Function

Private Function RobotsPatternToRegex(disallowPattern As String) As Regex
    If String.IsNullOrEmpty(disallowPattern) Then Return Nothing

    Dim p As String = disallowPattern.Trim()
    If p.Length = 0 Then Return Nothing

    Dim endAnchor As Boolean = False
    If p.EndsWith("$") Then
        endAnchor = True
        p = p.Substring(0, p.Length - 1)
    End If

    If p.Length = 0 Then Return Nothing
    If Not p.StartsWith("/") Then p = "/" & p

    Dim sb As New StringBuilder()
    For Each ch As Char In p
        If ch = "*"c Then
            sb.Append(".*")
        Else
            sb.Append(Regex.Escape(ch.ToString()))
        End If
    Next

    Dim rxPattern As String = "^" & sb.ToString()
    If endAnchor Then rxPattern &= "$"

    Return New Regex(rxPattern, RegexOptions.IgnoreCase)
End Function

Private Function IsDisallowedByRobots(loc As String) As Boolean
    If _disallowRegex Is Nothing OrElse _disallowRegex.Count = 0 Then Return False
    If String.IsNullOrEmpty(loc) Then Return False

    Dim pathQuery As String = loc

    Try
        Dim u As Uri = Nothing
        If Uri.TryCreate(loc, UriKind.Absolute, u) Then
            pathQuery = u.AbsolutePath
            If Not String.IsNullOrEmpty(u.Query) Then pathQuery &= u.Query
        End If

        If String.IsNullOrEmpty(pathQuery) Then Return False
        If Not pathQuery.StartsWith("/") Then
            ' Fallback: estrai la parte a partire dal primo "/"
            Dim slashPos As Integer = pathQuery.IndexOf("/"c)
            If slashPos >= 0 Then pathQuery = pathQuery.Substring(slashPos)
        End If
    Catch
        ' ignore
    End Try

    For Each rx As Regex In _disallowRegex
        If rx IsNot Nothing AndAlso rx.IsMatch(pathQuery) Then Return True
    Next

    Return False
End Function



Private Function CollectUrls(host As String, sig As CacheSignatureInfo) As List(Of Tuple(Of String, String, String, String))
    Dim urls As New List(Of Tuple(Of String, String, String, String))()

    ' lastmod base
    Dim fallbackUtc As DateTime = DateTime.UtcNow.AddDays(-_fallbackLastModDays)

    ' Static URLs
    AddStaticUrls(urls, host, fallbackUtc)

    ' Dynamic content
    AddDynamicArticoliUrls(urls, host, fallbackUtc, sig)
    AddDynamicFacetUrls(urls, host, fallbackUtc)

    Return urls
End Function

Private Function BuildXml(host As String, sig As CacheSignatureInfo) As String
    Dim urls As List(Of Tuple(Of String, String, String, String)) = CollectUrls(host, sig)

    Dim sb As New StringBuilder()
    sb.AppendLine("<?xml version=""1.0"" encoding=""UTF-8""?>")
    sb.AppendLine("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")

    For Each t As Tuple(Of String, String, String, String) In urls
        sb.AppendLine("  <url>")
        sb.AppendLine("    <loc>" & XmlEscape(t.Item1) & "</loc>")
        If Not String.IsNullOrEmpty(t.Item2) Then
            sb.AppendLine("    <lastmod>" & t.Item2 & "</lastmod>")
        End If
        If Not String.IsNullOrEmpty(t.Item3) Then
            sb.AppendLine("    <changefreq>" & t.Item3 & "</changefreq>")
        End If
        If Not String.IsNullOrEmpty(t.Item4) Then
            sb.AppendLine("    <priority>" & t.Item4 & "</priority>")
        End If
        sb.AppendLine("  </url>")
    Next

    sb.AppendLine("</urlset>")
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

    Private Sub AddDynamicArticoliUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String)
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


    Private Iterator Function QueryUrlAndLastModInfo(viewName As String) As IEnumerable(Of UrlLastModInfo)
        Dim sql As String = "SELECT * FROM " & viewName

        Dim fallbackUtc As Nullable(Of DateTime) = Nothing
        If _fromDbLastMod Then
            fallbackUtc = DateTime.UtcNow.AddDays(-_fallbackLastModDays)
        End If

        Using cn As New MySqlConnection(GetConnectionString())
            cn.Open()
            Using cmd As New MySqlCommand(sql, cn)
                Using reader As MySqlDataReader = cmd.ExecuteReader()
                    Dim idxUrl As Integer = -1
                    Dim idxLastMod As Integer = -1

                    Try
                        idxUrl = reader.GetOrdinal("url")
                    Catch ex As Exception
                        Throw New ApplicationException("Sitemap view '" & viewName & "' must expose a 'url' column.", ex)
                    End Try

                    Try
                        idxLastMod = reader.GetOrdinal("last_mod")
                    Catch ex As Exception
                        idxLastMod = -1
                    End Try

                    While reader.Read()
                        Dim urlRel As String = Convert.ToString(reader.GetValue(idxUrl))
                        If String.IsNullOrEmpty(urlRel) Then
                            Continue While
                        End If

                        Dim hasExplicit As Boolean = False
                        Dim lastModUtc As Nullable(Of DateTime) = Nothing

                        If idxLastMod <> -1 AndAlso Not reader.IsDBNull(idxLastMod) Then
                            lastModUtc = ParseUtc(reader.GetValue(idxLastMod))
                            hasExplicit = lastModUtc.HasValue
                        End If

                        If Not lastModUtc.HasValue Then
                            lastModUtc = fallbackUtc
                        End If

                        Dim info As New UrlLastModInfo()
                        info.Url = urlRel
                        info.LastModUtc = lastModUtc
                        info.HasExplicitLastMod = hasExplicit
                        Yield info
                    End While
                End Using
            End Using
        End Using
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
