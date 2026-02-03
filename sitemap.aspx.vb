Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Text
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient

Partial Class sitemap
    Inherits System.Web.UI.Page

    ' Google / Sitemap protocol limits:
    ' - max 50.000 URL per sitemap
    ' - max 50MB (uncompressed)
    Private Const MAX_URLS_PER_SITEMAP As Integer = 50000
    Private Const MAX_BYTES_PER_SITEMAP As Integer = 52428800 ' 50MB

    Private Const DEFAULT_TTL_MINUTES As Integer = 1440
    Private Const DEFAULT_FALLBACK_LASTMOD_DAYS As Integer = 7

    Private ReadOnly _fileCacheEnabled As Boolean
    Private ReadOnly _fileCacheTtlMinutes As Integer
    Private ReadOnly _fileCachePath As String

    Private ReadOnly _fromDbLastMod As Boolean
    Private ReadOnly _fallbackLastModDays As Integer

    Private ReadOnly _homePath As String
    Private ReadOnly _listingPath As String

    Private ReadOnly _staticUrls As List(Of String)

    ' HTTP caching / canonical host
    Private ReadOnly _hostOverride As String
    Private ReadOnly _httpCacheEnabled As Boolean
    Private ReadOnly _httpCacheMaxAgeSeconds As Integer

    ' Robots-aligned hard filter (defense-in-depth)
    Private ReadOnly _disallowPrefixes As List(Of String)

    Private Class CacheSignatureInfo
        Public Property Signature As String
        Public Property DataMaxUtc As Nullable(Of DateTime)
        Public Property TotalUrlCount As Integer
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

        _hostOverride = (GetStringAppSetting("KeepStore.Sitemap.HostOverride", "") & "").Trim()
        _httpCacheEnabled = GetBoolAppSetting("KeepStore.Sitemap.HttpCache.Enabled", True)
        _httpCacheMaxAgeSeconds = GetIntAppSetting("KeepStore.Sitemap.HttpCache.MaxAgeSeconds", Math.Max(60, _fileCacheTtlMinutes * 60))

        _staticUrls = New List(Of String)()
        _staticUrls.Add(_homePath)
        _staticUrls.Add(_listingPath)
        _staticUrls.Add("about.html")
        _staticUrls.Add("contact.html")
        _staticUrls.Add("privacy.html")
        _staticUrls.Add("faq.html")
        _staticUrls.Add("track-your-order.html")

        _disallowPrefixes = New List(Of String)()
        _disallowPrefixes.Add("/myaccount")
        _disallowPrefixes.Add("/myaccount.aspx")
        _disallowPrefixes.Add("/carrello.aspx")
        _disallowPrefixes.Add("/ordine.aspx")
        _disallowPrefixes.Add("/pagamento.aspx")
        _disallowPrefixes.Add("/wishlist.aspx")
        _disallowPrefixes.Add("/documenti.aspx")
        _disallowPrefixes.Add("/documentidettaglio.aspx")
        _disallowPrefixes.Add("/datiutente.aspx")
        _disallowPrefixes.Add("/cambiapassword.aspx")
        _disallowPrefixes.Add("/pay_your_orders.aspx")
    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Response.ContentType = "application/xml"
        Response.Charset = "utf-8"
        Response.ContentEncoding = Encoding.UTF8

        ' Sitemap is not a user-facing document
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow")

        Dim host As String = GetHost()

        ' Requested page for paginated sitemap (1-based).
        Dim p As Integer = 0
        Integer.TryParse((Request.QueryString("p") & "").Trim(), p)

        ' Calcolo signature (per HTTP cache e/o file cache)
        Dim sig As CacheSignatureInfo = Nothing
        Try
            sig = ComputeCacheSignature(host)
        Catch
            sig = New CacheSignatureInfo() With {.Signature = "", .DataMaxUtc = Nothing, .TotalUrlCount = 0}
        End Try

        ' HTTP caching (ETag / Last-Modified / 304)
        If _httpCacheEnabled Then
            ApplyHttpCacheHeaders(sig)

            If IsNotModified(sig) Then
                Response.StatusCode = 304
                Response.SuppressContent = True
                Return
            End If
        End If

        ' File cache (serve xml già generato)
        If _fileCacheEnabled Then
            Dim requestedKey As String = If(p > 0, "p" & p.ToString(), "root")
            If TryServeFromCache(host, sig, requestedKey) Then
                Return
            End If
        End If

        Dim effectiveCacheKey As String = "root"
        Dim xml As String = BuildXml(host, sig, p, effectiveCacheKey)

        If _fileCacheEnabled Then
            WriteCache(host, sig, effectiveCacheKey, xml)
        End If

        Response.Write(xml)
    End Sub

    '================== Build XML (urlset / sitemapindex) ==================

    Private Function BuildXml(host As String, sig As CacheSignatureInfo, requestedPage As Integer, ByRef effectiveCacheKey As String) As String
        ' reset per-request dedupe bucket
        HttpContext.Current.Items("KeepStore.Sitemap.Seen") = Nothing

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

        Dim needsPaging As Boolean = RequiresPagination(urls)
        Dim p As Integer = requestedPage

        If needsPaging Then
            Dim totalPages As Integer = CInt(Math.Ceiling(urls.Count / CDbl(MAX_URLS_PER_SITEMAP)))
            If totalPages < 1 Then totalPages = 1

            If p <= 0 Then
                ' root request -> sitemapindex
                effectiveCacheKey = "root"
                Return BuildSitemapIndexXml(host, sig, totalPages)
            Else
                ' page request -> urlset slice
                effectiveCacheKey = "p" & p.ToString()
                Return BuildUrlsetXml(SliceUrls(urls, p))
            End If
        End If

        ' no pagination needed -> always urlset (even if p passed)
        effectiveCacheKey = "root"
        Return BuildUrlsetXml(urls)
    End Function

    Private Function BuildSitemapIndexXml(host As String, sig As CacheSignatureInfo, totalPages As Integer) As String
        Dim lastmod As String = ""
        If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
            lastmod = FormatAsW3C(sig.DataMaxUtc)
        End If

        Dim baseLoc As String = host.TrimEnd("/"c) & "/sitemap.aspx"

        Dim sb As New StringBuilder()
        sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>")
        sb.Append(vbCrLf)
        sb.Append("<sitemapindex xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">")
        sb.Append(vbCrLf)

        For i As Integer = 1 To totalPages
            sb.Append("  <sitemap>")
            sb.Append(vbCrLf)
            sb.Append("    <loc>")
            sb.Append(HttpUtility.HtmlEncode(baseLoc & "?p=" & i.ToString()))
            sb.Append("</loc>")
            sb.Append(vbCrLf)
            If lastmod <> "" Then
                sb.Append("    <lastmod>")
                sb.Append(lastmod)
                sb.Append("</lastmod>")
                sb.Append(vbCrLf)
            End If
            sb.Append("  </sitemap>")
            sb.Append(vbCrLf)
        Next

        sb.Append("</sitemapindex>")
        sb.Append(vbCrLf)

        Return sb.ToString()
    End Function

    Private Function BuildUrlsetXml(urls As List(Of Tuple(Of String, String, String, String))) As String
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

    Private Function RequiresPagination(urls As List(Of Tuple(Of String, String, String, String))) As Boolean
        If urls Is Nothing Then Return False
        If urls.Count > MAX_URLS_PER_SITEMAP Then Return True

        ' Rough size guard (prevents exceeding 50MB uncompressed)
        Dim approxBytes As Long = 200L ' header
        For Each t In urls
            approxBytes += (t.Item1.Length + 220)
            If approxBytes > MAX_BYTES_PER_SITEMAP Then Return True
        Next
        Return False
    End Function

    Private Function SliceUrls(urls As List(Of Tuple(Of String, String, String, String)), page As Integer) As List(Of Tuple(Of String, String, String, String))
        Dim p As Integer = Math.Max(1, page)
        Dim start As Integer = (p - 1) * MAX_URLS_PER_SITEMAP
        If start >= urls.Count Then
            Return New List(Of Tuple(Of String, String, String, String))()
        End If
        Dim count As Integer = Math.Min(MAX_URLS_PER_SITEMAP, urls.Count - start)
        Return urls.GetRange(start, count)
    End Function

    '================== URL collection ==================

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
            AddUrl(urls, MakeAbsolute(host, rel), FormatAsW3C(lastModUtc), "monthly", "0.4")
        Next
    End Sub

    Private Sub AddDynamicArticoliUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String)
        For Each info As UrlLastModInfo In QueryUrlAndLastModInfo("v_sitemap_prodotti")
            Dim absUrl As String = MakeAbsolute(host, info.Url)
            AddUrl(urls, absUrl, FormatAsW3C(info.LastModUtc), "weekly", "0.7")
        Next
    End Sub

    Private Sub AddDynamicCategoryUrls(urls As List(Of Tuple(Of String, String, String, String)), host As String, globalLastModUtc As Nullable(Of DateTime))
        Dim catMap As Dictionary(Of Integer, DateTime) = Nothing
        If _fromDbLastMod Then
            catMap = GetCategoryLastModUtcMap()
        End If

        For Each info As UrlLastModInfo In QueryUrlAndLastModInfo("v_sitemap_categorie")
            Dim urlRel As String = info.Url
            Dim lastModUtc As Nullable(Of DateTime) = info.LastModUtc

            ' Se la vista non espone last_mod, proviamo a derivare da tabella articoli/categorie
            If _fromDbLastMod AndAlso (Not info.HasExplicitLastMod) Then
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
        If String.IsNullOrEmpty(loc) Then Return

        Dim normalizedLoc As String = NormalizeLoc(loc)
        If String.IsNullOrEmpty(normalizedLoc) Then Return

        If IsDisallowed(normalizedLoc) Then Return

        Dim seen As HashSet(Of String) = TryCast(HttpContext.Current.Items("KeepStore.Sitemap.Seen"), HashSet(Of String))
        If seen Is Nothing Then
            seen = New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
            HttpContext.Current.Items("KeepStore.Sitemap.Seen") = seen
        End If

        If seen.Contains(normalizedLoc) Then Return
        seen.Add(normalizedLoc)

        urls.Add(New Tuple(Of String, String, String, String)(normalizedLoc, lastmodW3c, changefreq, priority))
    End Sub

    Private Function NormalizeLoc(loc As String) As String
        Dim u As String = (loc & "").Trim()
        If u = "" Then Return ""

        ' Remove accidental double slashes after host (except "https://")
        Dim protoSep As Integer = u.IndexOf("://"c)
        If protoSep > 0 Then
            Dim head As String = u.Substring(0, protoSep + 3)
            Dim tail As String = u.Substring(protoSep + 3)
            While tail.Contains("//")
                tail = tail.Replace("//", "/")
            End While
            u = head & tail
        End If

        Return u
    End Function

    Private Function IsDisallowed(absUrl As String) As Boolean
        Try
            Dim uri As New Uri(absUrl, UriKind.Absolute)
            Dim path As String = (uri.AbsolutePath & "").ToLowerInvariant()

            For Each pfx As String In _disallowPrefixes
                Dim d As String = (pfx & "").ToLowerInvariant()
                If path.StartsWith(d) Then
                    Return True
                End If
            Next

            ' Block action parameter rimuovi= (crawl trap)
            Dim qs As String = (uri.Query & "").ToLowerInvariant()
            If qs.Contains("rimuovi=") Then
                Return True
            End If
        Catch
            Return True
        End Try

        Return False
    End Function

    '================== DB: URL + last_mod ==================

    Private Function QueryUrlAndLastMod(viewName As String) As IEnumerable(Of Tuple(Of String, Nullable(Of DateTime)))
        For Each info As UrlLastModInfo In QueryUrlAndLastModInfo(viewName)
            Yield New Tuple(Of String, Nullable(Of DateTime))(info.Url, info.LastModUtc)
        Next
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

    Private Function ParseUtc(obj As Object) As Nullable(Of DateTime)
        Try
            If obj Is Nothing OrElse obj Is DBNull.Value Then Return Nothing
            Dim dt As DateTime = Convert.ToDateTime(obj)
            Return dt.ToUniversalTime()
        Catch
            Return Nothing
        End Try
    End Function

    Private Function GetCategoryLastModUtcMap() As Dictionary(Of Integer, DateTime)
        Dim map As New Dictionary(Of Integer, DateTime)()

        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand("SELECT IDCategoria, MAX(DataAggiornamento) AS last_mod FROM categorie GROUP BY IDCategoria", cn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            Dim dt As DateTime
                            If Not Integer.TryParse(Convert.ToString(r("IDCategoria")), id) Then Continue While
                            If r("last_mod") Is Nothing OrElse r("last_mod") Is DBNull.Value Then Continue While
                            dt = Convert.ToDateTime(r("last_mod")).ToUniversalTime()
                            If Not map.ContainsKey(id) Then
                                map.Add(id, dt)
                            End If
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' ignore
        End Try

        Return map
    End Function

    Private Function TryGetIntParamFromUrl(url As String, param As String, ByRef value As Integer) As Boolean
        value = 0
        If String.IsNullOrEmpty(url) OrElse String.IsNullOrEmpty(param) Then Return False

        Dim qPos As Integer = url.IndexOf("?"c)
        If qPos < 0 Then Return False

        Dim qs As String = url.Substring(qPos + 1)
        Dim parts As String() = qs.Split("&"c)

        For Each part As String In parts
            Dim kv As String() = part.Split("="c)
            If kv.Length <> 2 Then Continue For
            If String.Equals(kv(0), param, StringComparison.OrdinalIgnoreCase) Then
                Return Integer.TryParse(HttpUtility.UrlDecode(kv(1)), value)
            End If
        Next

        Return False
    End Function

    '================== Signature / freshness ==================

    Private Function ComputeCacheSignature(host As String) As CacheSignatureInfo
        Dim info As New CacheSignatureInfo()

        Dim maxUtc As Nullable(Of DateTime) = Nothing
        If _fromDbLastMod Then
            maxUtc = GetSitemapDataMaxUtc()
        End If
        info.DataMaxUtc = maxUtc

        ' URL count (prevents stale cache if the volume changes without changing max date)
        Dim staticCount As Integer = _staticUrls.Count
        Dim prodCount As Integer = TryGetCount("SELECT COUNT(*) FROM v_sitemap_prodotti")
        Dim catCount As Integer = TryGetCount("SELECT COUNT(*) FROM v_sitemap_categorie")
        If prodCount < 0 Then prodCount = 0
        If catCount < 0 Then catCount = 0

        info.TotalUrlCount = staticCount + prodCount + catCount

        If maxUtc.HasValue Then
            info.Signature = host.ToLowerInvariant() & "|" & maxUtc.Value.ToString("yyyyMMddHHmmss") & "|" & info.TotalUrlCount.ToString()
        Else
            info.Signature = host.ToLowerInvariant() & "|0|" & info.TotalUrlCount.ToString()
        End If

        Return info
    End Function

    Private Function TryGetCount(sql As String) As Integer
        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand(sql, cn)
                    Dim obj As Object = cmd.ExecuteScalar()
                    If obj Is Nothing OrElse obj Is DBNull.Value Then Return -1
                    Dim n As Integer
                    If Integer.TryParse(Convert.ToString(obj), n) Then Return n
                    Return -1
                End Using
            End Using
        Catch
            Return -1
        End Try
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

    '================== File cache ==================

    Private Function TryServeFromCache(host As String, sig As CacheSignatureInfo, cacheKey As String) As Boolean
        Dim dirPath As String = Server.MapPath(_fileCachePath)
        If String.IsNullOrEmpty(dirPath) Then Return False

        If Not Directory.Exists(dirPath) Then Return False

        Dim xmlPath As String = Path.Combine(dirPath, CacheXmlFileName(cacheKey))
        Dim metaPath As String = Path.Combine(dirPath, CacheMetaFileName(cacheKey))

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

            ' Modalità "intelligente": confronto signature (MAX(data) + COUNT(url))
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

    Private Sub WriteCache(host As String, sig As CacheSignatureInfo, cacheKey As String, xml As String)
        Dim dirPath As String = Server.MapPath(_fileCachePath)
        If String.IsNullOrEmpty(dirPath) Then Return

        If Not Directory.Exists(dirPath) Then
            Directory.CreateDirectory(dirPath)
        End If

        Dim xmlPath As String = Path.Combine(dirPath, CacheXmlFileName(cacheKey))
        Dim metaPath As String = Path.Combine(dirPath, CacheMetaFileName(cacheKey))

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

            sb.AppendLine("TotalUrlCount=" & If(sig IsNot Nothing, sig.TotalUrlCount.ToString(), "0"))

            File.WriteAllText(metaPath, sb.ToString(), Encoding.UTF8)
        Catch
            ' ignore
        End Try
    End Sub

    Private Function CacheXmlFileName(cacheKey As String) As String
        Dim k As String = (cacheKey & "").Trim().ToLowerInvariant()
        If k = "" OrElse k = "root" Then
            Return "sitemap.xml"
        End If
        Return "sitemap_" & k & ".xml"
    End Function

    Private Function CacheMetaFileName(cacheKey As String) As String
        Dim k As String = (cacheKey & "").Trim().ToLowerInvariant()
        If k = "" OrElse k = "root" Then
            Return "sitemap.meta"
        End If
        Return "sitemap_" & k & ".meta"
    End Function

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

    '================== Helpers ==================

    Private Function FormatAsW3C(dtUtc As Nullable(Of DateTime)) As String
        If Not dtUtc.HasValue Then Return ""
        Return dtUtc.Value.ToString("yyyy-MM-ddTHH:mm:ssZ")
    End Function

    Private Function GetHost() As String
        If Not String.IsNullOrEmpty(_hostOverride) Then
            Try
                Dim u As Uri = New Uri(_hostOverride, UriKind.Absolute)
                Return u.Scheme & "://" & u.Authority
            Catch
                Dim h As String = _hostOverride.Trim().TrimEnd("/"c)
                If h.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse h.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
                    Return h
                End If
            End Try
        End If

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

        Return host.TrimEnd("/"c) & rel
    End Function

    Private Function NormalizePath(path As String) As String
        If String.IsNullOrEmpty(path) Then Return ""
        Dim p As String = path.Trim()
        p = p.Replace("", "/")
        If p.StartsWith("/", StringComparison.Ordinal) Then p = p.Substring(1)
        Return p
    End Function

    '================== HTTP cache helpers ==================

    Private Sub ApplyHttpCacheHeaders(sig As CacheSignatureInfo)
        Dim maxAge As Integer = _httpCacheMaxAgeSeconds
        If maxAge < 60 Then maxAge = 60

        Response.Cache.SetCacheability(HttpCacheability.Public)
        Response.Cache.SetMaxAge(TimeSpan.FromSeconds(maxAge))
        Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        Response.Cache.SetExpires(DateTime.UtcNow.AddSeconds(maxAge))
        Response.Cache.AppendCacheExtension("stale-while-revalidate=60")
        Response.Cache.VaryByHeaders("Accept-Encoding") = True

        Dim lastModUtc As Nullable(Of DateTime) = Nothing
        If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
            lastModUtc = sig.DataMaxUtc.Value
        End If

        If lastModUtc.HasValue Then
            Response.Cache.SetLastModified(lastModUtc.Value)
        End If

        Dim etag As String = ComputeEtag(sig)
        If Not String.IsNullOrEmpty(etag) Then
            Response.Cache.SetETag(etag)
        End If
    End Sub

    Private Function IsNotModified(sig As CacheSignatureInfo) As Boolean
        Dim etag As String = ComputeEtag(sig)
        If Not String.IsNullOrEmpty(etag) Then
            Dim inm As String = (Request.Headers("If-None-Match") & "").Trim()
            If String.Equals(inm, etag, StringComparison.Ordinal) Then
                Return True
            End If
        End If

        Dim imsRaw As String = (Request.Headers("If-Modified-Since") & "").Trim()
        If Not String.IsNullOrEmpty(imsRaw) Then
            Dim ims As DateTime
            If DateTime.TryParse(imsRaw, ims) Then
                Dim lastModUtc As Nullable(Of DateTime) = Nothing
                If sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue Then
                    lastModUtc = sig.DataMaxUtc.Value
                End If

                If lastModUtc.HasValue Then
                    Dim lastModNoMs As DateTime = New DateTime(lastModUtc.Value.Year, lastModUtc.Value.Month, lastModUtc.Value.Day, lastModUtc.Value.Hour, lastModUtc.Value.Minute, lastModUtc.Value.Second, DateTimeKind.Utc)
                    Dim imsUtc As DateTime = ims.ToUniversalTime()
                    If imsUtc >= lastModNoMs Then
                        Return True
                    End If
                End If
            End If
        End If

        Return False
    End Function

    Private Function ComputeEtag(sig As CacheSignatureInfo) As String
        Try
            Dim baseStr As String = ""
            If sig IsNot Nothing AndAlso Not String.IsNullOrEmpty(sig.Signature) Then
                baseStr = sig.Signature
            End If

            If String.IsNullOrEmpty(baseStr) Then
                Return ""
            End If

            Using sha As SHA256 = SHA256.Create()
                Dim bytes As Byte() = Encoding.UTF8.GetBytes(baseStr)
                Dim hash As Byte() = sha.ComputeHash(bytes)
                Dim sb As New StringBuilder(hash.Length * 2)
                For Each b As Byte In hash
                    sb.Append(b.ToString("x2"))
                Next
                Return "W/""" & sb.ToString() & """"
            End Using
        Catch
            Return ""
        End Try
    End Function

    '================== Config helpers ==================

    Private Function GetConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("taikunConnectionString").ConnectionString
    End Function

    Private Function GetStringAppSetting(key As String, def As String) As String
        Try
            Dim v As String = ConfigurationManager.AppSettings(key)
            If String.IsNullOrEmpty(v) Then Return def
            Return v
        Catch
            Return def
        End Try
    End Function

    Private Function GetBoolAppSetting(key As String, def As Boolean) As Boolean
        Dim v As String = GetStringAppSetting(key, "")
        If String.IsNullOrEmpty(v) Then Return def
        Dim b As Boolean
        If Boolean.TryParse(v, b) Then Return b
        Return def
    End Function

    Private Function GetIntAppSetting(key As String, def As Integer) As Integer
        Dim v As String = GetStringAppSetting(key, "")
        If String.IsNullOrEmpty(v) Then Return def
        Dim i As Integer
        If Integer.TryParse(v, i) Then Return i
        Return def
    End Function

End Class
