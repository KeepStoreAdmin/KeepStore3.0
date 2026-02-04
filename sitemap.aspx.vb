Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Xml
Imports System.Web
Imports System.Web.UI
Imports MySql.Data.MySqlClient

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

    ' Audit: coerenza sitemap vs robots
    Private _auditEnabled As Boolean
    Private _auditToken As String

    ' Robots-aligned filter (defense-in-depth)
    Private _disallowRules As List(Of String)


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
        _staticUrls.Add("track-your-order.html")

        ' Audit settings
        _auditEnabled = GetBoolAppSetting("KeepStore.Sitemap.Audit.Enabled", False)
        _auditToken = GetStringAppSetting("KeepStore.Sitemap.Audit.Token", "")

        ' Robots Disallow alignment (optional)
        _disallowRules = LoadDisallowRulesFromRobots()
        If _disallowRules Is Nothing OrElse _disallowRules.Count = 0 Then
            _disallowRules = New List(Of String)()
            _disallowRules.Add("/myaccount")
            _disallowRules.Add("/myaccount/")
            _disallowRules.Add("/myaccount.aspx")
            _disallowRules.Add("/carrello.aspx")
            _disallowRules.Add("/ordine.aspx")
            _disallowRules.Add("/pagamento.aspx")
            _disallowRules.Add("/wishlist.aspx")
            _disallowRules.Add("/documenti.aspx")
            _disallowRules.Add("/documentidettaglio.aspx")
            _disallowRules.Add("/datiutente.aspx")
            _disallowRules.Add("/cambiapassword.aspx")
            _disallowRules.Add("/pay_your_orders.aspx")
            _disallowRules.Add("/app_data/")
            _disallowRules.Add("/app_code/")
            _disallowRules.Add("/bin/")
            _disallowRules.Add("/*rimuovi=")
            _disallowRules.Add("/*?rimuovi=")
            _disallowRules.Add("/*&rimuovi=")
        End If

    End Sub

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim host As String = GetHost()
        Dim wantAudit As Boolean = String.Equals((Request.QueryString("audit") & "").Trim(), "1", StringComparison.OrdinalIgnoreCase) OrElse _
                             String.Equals((Request.QueryString("audit") & "").Trim(), "true", StringComparison.OrdinalIgnoreCase)

        If wantAudit Then
            If Not IsAuditAllowed() Then
                Response.StatusCode = 404
                Response.SuppressContent = True
                Return
            End If

            Response.ContentType = "text/plain"
            Response.Charset = "utf-8"
            Response.ContentEncoding = Encoding.UTF8
            Response.Cache.SetCacheability(HttpCacheability.NoCache)
            Response.Cache.SetNoStore()
            Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1))
            Response.AddHeader("X-Robots-Tag", "noindex, nofollow")

            Response.Write(BuildAuditReport(host))
            Return
        End If

        Response.ContentType = "application/xml"
        Response.Charset = "utf-8"
        Response.ContentEncoding = Encoding.UTF8
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow")
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
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

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
        AddStaticUrls(urls, seen, host, fallbackUtc)

        ' Dynamic URLs
        AddDynamicArticoliUrls(urls, seen, host)
        AddDynamicCategoryUrls(urls, seen, host, globalLastModUtc)

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

    Private Sub AddStaticUrls(urls As List(Of Tuple(Of String, String, String, String)), seen As HashSet(Of String), host As String, lastModUtc As Nullable(Of DateTime))
        ' Home
        AddUrl(urls, seen, MakeAbsolute(host, _homePath), FormatAsW3C(lastModUtc), "daily", "1.0")

        ' Listing (articoli.aspx) -> lastmod "reale" (MAX(data))
        AddUrl(urls, seen, MakeAbsolute(host, _listingPath), FormatAsW3C(lastModUtc), "daily", "0.9")

        ' Other static pages
        For Each rel As String In _staticUrls
            If rel.Equals(_homePath, StringComparison.OrdinalIgnoreCase) OrElse rel.Equals(_listingPath, StringComparison.OrdinalIgnoreCase) Then
                Continue For
            End If
            AddUrl(urls, seen, MakeAbsolute(host, rel), FormatAsW3C(lastModUtc), "monthly", "0.4")
        Next
    End Sub

    Private Sub AddDynamicArticoliUrls(urls As List(Of Tuple(Of String, String, String, String)), seen As HashSet(Of String), host As String)
        For Each row As Tuple(Of String, Nullable(Of DateTime)) In QueryUrlAndLastMod("v_sitemap_prodotti")
            Dim absUrl As String = MakeAbsolute(host, row.Item1)
            Dim lastmod As String = FormatAsW3C(row.Item2)
            AddUrl(urls, seen, absUrl, lastmod, "weekly", "0.7")
        Next
    End Sub

    Private Sub AddDynamicCategoryUrls(urls As List(Of Tuple(Of String, String, String, String)), seen As HashSet(Of String), host As String, globalLastModUtc As Nullable(Of DateTime))
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
            AddUrl(urls, seen, absUrl, FormatAsW3C(lastModUtc), "weekly", "0.6")
        Next
    End Sub

    Private Sub AddUrl(urls As List(Of Tuple(Of String, String, String, String)), seen As HashSet(Of String), loc As String, lastmodW3c As String, changefreq As String, priority As String)
        If String.IsNullOrEmpty(loc) Then Return
        Dim norm As String = NormalizeLoc(loc)
        If String.IsNullOrEmpty(norm) Then Return
        If IsDisallowedByRobots(norm) Then Return
        If seen IsNot Nothing Then
            If seen.Contains(norm) Then Return
            seen.Add(norm)
        End If
        urls.Add(New Tuple(Of String, String, String, String)(norm, lastmodW3c, changefreq, priority))
    End Sub

    '---------------- DB: URL + last_mod ----------------
    Private Iterator Function QueryUrlAndLastMod(viewName As String) As IEnumerable(Of Tuple(Of String, Nullable(Of DateTime)))
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


    Private Function NormalizeLoc(loc As String) As String
        Dim u As String = (loc & "").Trim()
        If u = "" Then Return ""

        Dim protoSep As Integer = u.IndexOf("://")
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

    Private Function IsDisallowedByRobots(absUrl As String) As Boolean
        Try
            If _disallowRules Is Nothing OrElse _disallowRules.Count = 0 Then
                Dim u As String = (absUrl & "").ToLowerInvariant()
                If u.Contains("rimuovi=") Then Return True
                Return False
            End If

            Dim uri As New Uri(absUrl, UriKind.Absolute)
            Dim target As String = (uri.AbsolutePath & uri.Query).ToLowerInvariant()

            For Each rule As String In _disallowRules
                Dim r As String = (rule & "").Trim()
                If r = "" Then Continue For
                If r = "/" Then Continue For

                Dim rr As String = r.ToLowerInvariant()

                If rr.Contains("*") Then
                    Dim pattern As String = "^" & Regex.Escape(rr).Replace("\*", ".*")
                    If Regex.IsMatch(target, pattern, RegexOptions.IgnoreCase) Then
                        Return True
                    End If
                Else
                    If target.StartsWith(rr, StringComparison.OrdinalIgnoreCase) Then
                        Return True
                    End If
                End If
            Next

            If target.Contains("rimuovi=") Then Return True

        Catch
            Return True
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


    ' ===== Robots.txt parsing (Disallow) =====
    Private Function LoadDisallowRulesFromRobots() As List(Of String)
        Dim rules As New List(Of String)()

        Try
            Dim p As String = Server.MapPath("~/robots.txt")
            If Not File.Exists(p) Then Return rules

            Dim lines() As String = File.ReadAllLines(p, Encoding.UTF8)

            Dim inStarSection As Boolean = False
            For Each raw As String In lines
                Dim line As String = (raw & "")
                Dim hashPos As Integer = line.IndexOf("#"c)
                If hashPos >= 0 Then line = line.Substring(0, hashPos)
                line = line.Trim()
                If line = "" Then Continue For

                Dim lower As String = line.ToLowerInvariant()

                If lower.StartsWith("user-agent:") Then
                    Dim ua As String = line.Substring("user-agent:".Length).Trim()
                    inStarSection = (ua = "*" OrElse ua = """*""" OrElse ua.ToLowerInvariant() = "*")
                    Continue For
                End If

                ' Se non ci sono sezioni specifiche, accettiamo comunque i Disallow (robust)
                If lower.StartsWith("disallow:") Then
                    If (Not inStarSection) AndAlso HasAnyUserAgent(lines) Then
                        ' se ci sono sezioni User-agent e questa non è la *, ignoriamo
                        Continue For
                    End If

                    Dim pathRule As String = line.Substring("disallow:".Length).Trim()
                    If pathRule = "" Then Continue For
                    If pathRule = "/" Then
                        ' Disallow: / => blocco totale (non lo applichiamo qui per non azzerare sitemap per errore)
                        rules.Add("/")
                        Continue For
                    End If

                    If Not pathRule.StartsWith("/") Then pathRule = "/" & pathRule
                    rules.Add(pathRule)
                End If
            Next

        Catch
            ' ignore: in caso di errori torniamo lista vuota e usiamo fallback
        End Try

        Return rules
    End Function

    Private Function HasAnyUserAgent(lines() As String) As Boolean
        Try
            For Each raw As String In lines
                Dim line As String = (raw & "").Trim().ToLowerInvariant()
                If line.StartsWith("user-agent:") Then Return True
            Next
        Catch
        End Try
        Return False
    End Function

    ' ===== Audit access control =====
    Private Function IsAuditAllowed() As Boolean
        Try
            If Request IsNot Nothing AndAlso Request.IsLocal Then Return True
        Catch
        End Try

        If Not _auditEnabled Then Return False

        If String.IsNullOrEmpty(_auditToken) Then Return False
        If _auditToken.Length < 16 Then Return False

        Dim t As String = (Request.QueryString("token") & "")
        If t = "" Then Return False

        Return SlowEquals(t, _auditToken)
    End Function

    Private Function SlowEquals(a As String, b As String) As Boolean
        If a Is Nothing OrElse b Is Nothing Then Return False
        Dim ba() As Byte = Encoding.UTF8.GetBytes(a)
        Dim bb() As Byte = Encoding.UTF8.GetBytes(b)
        Dim diff As Integer = ba.Length Xor bb.Length
        Dim maxLen As Integer = Math.Min(ba.Length, bb.Length)
        For i As Integer = 0 To maxLen - 1
            diff = diff Or (ba(i) Xor bb(i))
        Next
        Return diff = 0
    End Function

    ' ===== Audit report: sitemap URLs vs robots rules =====
    Private Function BuildAuditReport(host As String) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("KeepStore Sitemap Audit (sitemap vs robots)")
        sb.AppendLine("UTC: " & DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
        sb.AppendLine("Host: " & host)
        sb.AppendLine("Robots rules loaded: " & If(_disallowRules Is Nothing, "0", _disallowRules.Count.ToString()))
        sb.AppendLine("")

        Dim xml As String = BuildXml(host)
        Dim urls As List(Of String) = ExtractLocUrls(xml)

        sb.AppendLine("URLs in sitemap: " & urls.Count.ToString())

        ' duplicates
        Dim setLower As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim dupCount As Integer = 0
        For Each u As String In urls
            If Not setLower.Add(u) Then dupCount += 1
        Next
        sb.AppendLine("Duplicates: " & dupCount.ToString())

        ' scheme checks
        Dim nonHttps As Integer = 0
        For Each u As String In urls
            If Not u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then nonHttps += 1
        Next
        sb.AppendLine("Non-HTTPS: " & nonHttps.ToString())

        ' disallowed checks
        Dim disallowed As New List(Of String)()
        For Each u As String In urls
            If IsDisallowedByRobots(u) Then
                disallowed.Add(u)
            End If
        Next
        sb.AppendLine("Robots-disallowed: " & disallowed.Count.ToString())

        If disallowed.Count > 0 Then
            sb.AppendLine("")
            sb.AppendLine("Sample disallowed (max 50):")
            Dim maxN As Integer = Math.Min(50, disallowed.Count)
            For i As Integer = 0 To maxN - 1
                sb.AppendLine("- " & disallowed(i))
            Next
        End If

        Return sb.ToString()
    End Function

    Private Function ExtractLocUrls(xml As String) As List(Of String)
        Dim res As New List(Of String)()
        If String.IsNullOrEmpty(xml) Then Return res

        Try
            Dim doc As New XmlDocument()
            doc.XmlResolver = Nothing
            doc.LoadXml(xml)

            Dim nsmgr As New XmlNamespaceManager(doc.NameTable)
            nsmgr.AddNamespace("sm", "http://www.sitemaps.org/schemas/sitemap/0.9")
            Dim nodes As XmlNodeList = doc.SelectNodes("//sm:url/sm:loc", nsmgr)
            If nodes IsNot Nothing Then
                For Each n As XmlNode In nodes
                    Dim v As String = (n.InnerText & "").Trim()
                    If v <> "" Then res.Add(v)
                Next
            End If

        Catch
            ' fallback regex
            Dim rx As New Regex("<loc>(.*?)</loc>", RegexOptions.IgnoreCase Or RegexOptions.Singleline)
            For Each m As Match In rx.Matches(xml)
                Dim v As String = (m.Groups(1).Value & "").Trim()
                If v <> "" Then res.Add(System.Web.HttpUtility.HtmlDecode(v))
            Next
        End Try

        Return res
    End Function

End Class
