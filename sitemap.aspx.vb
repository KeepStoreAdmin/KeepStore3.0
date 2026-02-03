Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient

Partial Class sitemap
    Inherits System.Web.UI.Page

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
        _staticUrls.Add("about.html")
        _staticUrls.Add("contact.html")
        _staticUrls.Add("privacy.html")
        _staticUrls.Add("faq.html")
        _staticUrls.Add("track-your-order.html")
    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Response.ContentType = "application/xml"
        Response.Charset = "utf-8"

        ' Hardening: evita che la sitemap venga indicizzata come "pagina"
        Try
            Response.Headers("X-Robots-Tag") = "noindex,follow"
        Catch
            Try
                Response.AddHeader("X-Robots-Tag", "noindex,follow")
            Catch
            End Try
        End Try

        ' Cache HTTP moderna (ETag + Last-Modified) per ridurre fetch inutili (Google/AI crawler)
        ' NB: usiamo come riferimento la signature/MAX(data) (se disponibile) oppure DateTime.UtcNow.

        Dim host As String = GetHost()

                Dim sig As CacheSignatureInfo = Nothing
        If _fileCacheEnabled Then
            sig = ComputeCacheSignature(host)

            ' HTTP caching headers (ETag + Last-Modified)
            Dim lastModUtc As DateTime = If(sig IsNot Nothing AndAlso sig.DataMaxUtc.HasValue, sig.DataMaxUtc.Value, DateTime.UtcNow)
            Dim etagBase As String = If(sig IsNot Nothing AndAlso Not String.IsNullOrEmpty(sig.Signature), sig.Signature, host.ToLowerInvariant() & "|" & lastModUtc.ToString("yyyyMMddHHmmss"))
            Dim etag As String = ComputeStrongEtag(etagBase)

            Try
                Response.Cache.SetCacheability(HttpCacheability.Public)
                Response.Cache.SetLastModified(lastModUtc)
                Response.Cache.SetETag(etag)
                Response.Cache.SetMaxAge(TimeSpan.FromMinutes(_fileCacheTtlMinutes))
                Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
            Catch
            End Try

            If IsNotModified(etag, lastModUtc) Then
                Response.StatusCode = 304
                Response.StatusDescription = "Not Modified"
                Response.SuppressContent = True
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If

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
        If String.IsNullOrEmpty(loc) Then Return
        urls.Add(New Tuple(Of String, String, String, String)(loc, lastmodW3c, changefreq, priority))
    End Sub

    '---------------- DB: URL + last_mod ----------------

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

    
    Private Function ComputeStrongEtag(ByVal input As String) As String
        If input Is Nothing Then input = ""
        Using sha As System.Security.Cryptography.SHA1 = System.Security.Cryptography.SHA1.Create()
            Dim bytes As Byte() = Encoding.UTF8.GetBytes(input)
            Dim hash As Byte() = sha.ComputeHash(bytes)
            Dim sb As New StringBuilder()
            For Each b As Byte In hash
                sb.Append(b.ToString("x2"))
            Next
            Return """ & sb.ToString() & """
        End Using
    End Function

    Private Function IsNotModified(ByVal etag As String, ByVal lastModUtc As DateTime) As Boolean
        Try
            Dim inm As String = Request.Headers("If-None-Match")
            If Not String.IsNullOrEmpty(inm) AndAlso Not String.IsNullOrEmpty(etag) Then
                If String.Equals(inm.Trim(), etag, StringComparison.Ordinal) Then
                    Return True
                End If
            End If
        Catch
        End Try

        Try
            Dim ims As String = Request.Headers("If-Modified-Since")
            If Not String.IsNullOrEmpty(ims) Then
                Dim since As DateTime
                If DateTime.TryParse(ims, since) Then
                    Dim sinceUtc As DateTime = since.ToUniversalTime()
                    ' Tolleranza 1 secondo
                    If lastModUtc <= sinceUtc.AddSeconds(1) Then
                        Return True
                    End If
                End If
            End If
        Catch
        End Try

        Return False
    End Function

'---------------- Helpers ----------------

    Private Function FormatAsW3C(dtUtc As Nullable(Of DateTime)) As String
        If Not dtUtc.HasValue Then Return Nothing
        Dim utc As DateTime = DateTime.SpecifyKind(dtUtc.Value, DateTimeKind.Utc)
        Return utc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    End Function

        Private Function GetHost() As String
        ' Se vuoi forzare un host canonico (es. dietro reverse proxy / multi-host), configura:
        ' <add key="KeepStore.Sitemap.HostOverride" value="https://www.taikun.it" />
        Dim overrideHost As String = GetStringAppSetting("KeepStore.Sitemap.HostOverride", "")
        If Not String.IsNullOrEmpty(overrideHost) Then
            Dim h As String = overrideHost.Trim()
            If h.StartsWith("//") Then h = "https:" & h
            If Not h.StartsWith("http://", StringComparison.OrdinalIgnoreCase) AndAlso Not h.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
                ' Se viene passato solo host (es. www.taikun.it), assumiamo https
                h = "https://" & h
            End If
            Return h.TrimEnd("/"c)
        End If

        Dim uri As Uri = Request.Url
        Return (uri.Scheme & "://" & uri.Authority).TrimEnd("/"c)
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
