Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.Text
Imports System.IO
Imports System.Web
Imports System.Web.Caching
Imports System.Xml
Imports MySql.Data.MySqlClient

' KeepStore 3.0 - Sitemap generator (STEP33B)
' - Generates an XML Sitemap (or Sitemap Index if too many URLs)
' - Includes:
'   * Home + core public pages
'   * Catalog listing URLs (articoli.aspx) only for SEO-indexable combinations (st/ct/tp/gr/sg/mr)
'   * Product detail URLs (articolo.aspx?id=...&TCid=...)
Public Class sitemap
    Inherits System.Web.UI.Page

    Private Const MAX_URLS_PER_SITEMAP As Integer = 40000
    Private Const CACHE_KEY_URLS As String = "KeepStore.Sitemap.UrlList.v1"
    Private Const CACHE_KEY_LASTMOD As String = "KeepStore.Sitemap.LastModMap.v1"

    Private Shared ReadOnly _fileCacheLock As New Object()
    Private Const CACHE_MINUTES As Integer = 60

        Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.ContentType = "application/xml"
        Response.ContentEncoding = Encoding.UTF8

        Dim part As Integer = SafeInt(Request.QueryString("part"))
        If part < 0 Then part = 0

        ' File cache (App_Data) — avoids DB queries when warm
        Dim cacheFileName As String = If(part <= 0, "sitemap.xml", "sitemap-part-" & part.ToString() & ".xml")
        If TryServeFileCache(cacheFileName) Then Return

        Dim allUrls As List(Of String) = GetOrBuildUrlList()

        If part <= 0 AndAlso allUrls.Count > MAX_URLS_PER_SITEMAP Then
            ' Serve sitemap index
            WriteSitemapIndex(allUrls.Count, cacheFileName)
        Else
            If part <= 0 Then part = 1
            WriteUrlSet(allUrls, part, cacheFileName)
        End If
    End Sub

    Private Function GetOrBuildUrlList() As List(Of String)
        Dim nocache As String = Convert.ToString(Request.QueryString("nocache"))
        If String.Equals(nocache, "1", StringComparison.Ordinal) Then
            HttpRuntime.Cache.Remove(CACHE_KEY_URLS)
        End If

        Dim cached As Object = HttpRuntime.Cache(CACHE_KEY_URLS)
        Dim urls As List(Of String) = TryCast(cached, List(Of String))
        If urls IsNot Nothing AndAlso urls.Count > 0 Then
            Return urls
        End If

        urls = BuildUrlList()
        HttpRuntime.Cache.Insert(CACHE_KEY_URLS, urls, Nothing, DateTime.UtcNow.AddMinutes(CACHE_MINUTES), Cache.NoSlidingExpiration)
        Return urls
    End Function

    Private Function BuildUrlList() As List(Of String)
        Dim baseUrl As String = GetBaseUrl()
        Dim setUrls As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        ' --- Core public pages (keep intentionally small)
        Dim homeRel As String = Convert.ToString(ConfigurationManager.AppSettings("KeepStore.Sitemap.Home"))
        If String.IsNullOrEmpty(homeRel) Then homeRel = "default.aspx"

        AddAbs(setUrls, baseUrl, homeRel)
        AddAbs(setUrls, baseUrl, "articoli.aspx")
        AddAbs(setUrls, baseUrl, "contattaci.aspx")

        ' --- Catalog listing URLs (SEO allowlist)
        Try
            AddCatalogListingUrlsFromDb(setUrls, baseUrl)
        Catch
            ' Best-effort: sitemap still works with core URLs
        End Try

        ' --- Product detail URLs
        Try
            AddProductUrlsFromDb(setUrls, baseUrl)
        Catch
            ' Best-effort
        End Try

        Dim urls As New List(Of String)(setUrls)
        urls.Sort(StringComparer.OrdinalIgnoreCase)
        Return urls
    End Function

        Private Sub WriteSitemapIndex(totalCount As Integer, cacheFileName As String)
        Dim baseUrl As String = GetBaseUrl()
        Dim parts As Integer = CInt(Math.Ceiling(totalCount / CDbl(MAX_URLS_PER_SITEMAP)))
        If parts < 1 Then parts = 1

        Dim settings As New XmlWriterSettings() With {
            .Encoding = Encoding.UTF8,
            .Indent = True,
            .OmitXmlDeclaration = False
        }

        Using ms As New MemoryStream()
            Using xw As XmlWriter = XmlWriter.Create(ms, settings)
                xw.WriteStartDocument()
                xw.WriteStartElement("sitemapindex", "http://www.sitemaps.org/schemas/sitemap/0.9")

                Dim today As String = DateTime.UtcNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

                For i As Integer = 1 To parts
                    xw.WriteStartElement("sitemap")
                    xw.WriteElementString("loc", CombineUrl(baseUrl, "sitemap.aspx?part=" & i))
                    xw.WriteElementString("lastmod", today)
                    xw.WriteEndElement()
                Next

                xw.WriteEndElement()
                xw.WriteEndDocument()
            End Using

            Dim bytes As Byte() = ms.ToArray()
            TryWriteFileCache(cacheFileName, bytes)
            Response.BinaryWrite(bytes)
        End Using
    End Sub

        Private Sub WriteUrlSet(allUrls As List(Of String), part As Integer, cacheFileName As String)
        Dim startIndex As Integer = (part - 1) * MAX_URLS_PER_SITEMAP
        Dim slice As IEnumerable(Of String) = allUrls.Skip(startIndex).Take(MAX_URLS_PER_SITEMAP)

        Dim lastModMap As Dictionary(Of String, DateTime) = GetOrBuildLastModMap()

        Dim settings As New XmlWriterSettings() With {
            .Encoding = Encoding.UTF8,
            .Indent = True,
            .OmitXmlDeclaration = False
        }

        Using ms As New MemoryStream()
            Using xw As XmlWriter = XmlWriter.Create(ms, settings)
                xw.WriteStartDocument()
                xw.WriteStartElement("urlset", "http://www.sitemaps.org/schemas/sitemap/0.9")

                Dim todayUtc As DateTime = DateTime.UtcNow

                For Each u As String In slice
                    xw.WriteStartElement("url")
                    xw.WriteElementString("loc", u)

                    Dim lm As DateTime = todayUtc
                    If lastModMap IsNot Nothing AndAlso lastModMap.ContainsKey(u) Then
                        lm = lastModMap(u)
                    End If
                    xw.WriteElementString("lastmod", lm.ToUniversalTime().ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))

                    xw.WriteEndElement()
                Next

                xw.WriteEndElement()
                xw.WriteEndDocument()
            End Using

            Dim bytes As Byte() = ms.ToArray()
            TryWriteFileCache(cacheFileName, bytes)
            Response.BinaryWrite(bytes)
        End Using
    End Sub

    Private Sub AddCatalogListingUrlsFromDb(target As HashSet(Of String), baseUrl As String)
        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Exit Sub

        Using conn As New MySqlConnection(cs)
            conn.Open()

            ' 1) st+ct
            Using cmd As New MySqlCommand("SELECT DISTINCT SettoriId, CategorieId FROM vsuperarticoli WHERE CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0", conn)
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    While r.Read()
                        Dim st As Integer = SafeInt(r, 0)
                        Dim ct As Integer = SafeInt(r, 1)
                        If IsSeoIndexAllowed(st, ct, 0, 0, 0, 0) Then
                            AddAbs(target, baseUrl, BuildCatalogUrl(st, ct, 0, 0, 0, 0))
                        End If
                    End While
                End Using
            End Using

            ' 2) st+ct+tp
            Using cmd As New MySqlCommand("SELECT DISTINCT SettoriId, CategorieId, TipologieId FROM vsuperarticoli WHERE TipologieId IS NOT NULL AND TipologieId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0", conn)
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    While r.Read()
                        Dim st As Integer = SafeInt(r, 0)
                        Dim ct As Integer = SafeInt(r, 1)
                        Dim tp As Integer = SafeInt(r, 2)
                        If IsSeoIndexAllowed(st, ct, tp, 0, 0, 0) Then
                            AddAbs(target, baseUrl, BuildCatalogUrl(st, ct, tp, 0, 0, 0))
                        End If
                    End While
                End Using
            End Using

            ' 3) st+ct+(gr|sg|mr) WITHOUT tp
            AddFacetListingWithoutTp(conn, target, baseUrl, "GruppiId", "SELECT DISTINCT SettoriId, CategorieId, GruppiId FROM vsuperarticoli WHERE GruppiId IS NOT NULL AND GruppiId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")
            AddFacetListingWithoutTp(conn, target, baseUrl, "SottogruppiId", "SELECT DISTINCT SettoriId, CategorieId, SottogruppiId FROM vsuperarticoli WHERE SottogruppiId IS NOT NULL AND SottogruppiId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")
            AddFacetListingWithoutTp(conn, target, baseUrl, "MarcheId", "SELECT DISTINCT SettoriId, CategorieId, MarcheId FROM vsuperarticoli WHERE MarcheId IS NOT NULL AND MarcheId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")

            ' 4) st+ct+tp+(gr|sg|mr)
            AddFacetListingWithTp(conn, target, baseUrl, "GruppiId", "SELECT DISTINCT SettoriId, CategorieId, TipologieId, GruppiId FROM vsuperarticoli WHERE TipologieId IS NOT NULL AND TipologieId<>0 AND GruppiId IS NOT NULL AND GruppiId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")
            AddFacetListingWithTp(conn, target, baseUrl, "SottogruppiId", "SELECT DISTINCT SettoriId, CategorieId, TipologieId, SottogruppiId FROM vsuperarticoli WHERE TipologieId IS NOT NULL AND TipologieId<>0 AND SottogruppiId IS NOT NULL AND SottogruppiId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")
            AddFacetListingWithTp(conn, target, baseUrl, "MarcheId", "SELECT DISTINCT SettoriId, CategorieId, TipologieId, MarcheId FROM vsuperarticoli WHERE TipologieId IS NOT NULL AND TipologieId<>0 AND MarcheId IS NOT NULL AND MarcheId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0")

            ' 5) st+ct+tp+gr+sg (hier pair)
            Using cmd As New MySqlCommand("SELECT DISTINCT SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId FROM vsuperarticoli WHERE TipologieId IS NOT NULL AND TipologieId<>0 AND GruppiId IS NOT NULL AND GruppiId<>0 AND SottogruppiId IS NOT NULL AND SottogruppiId<>0 AND CategorieId IS NOT NULL AND CategorieId<>0 AND SettoriId IS NOT NULL AND SettoriId<>0", conn)
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    While r.Read()
                        Dim st As Integer = SafeInt(r, 0)
                        Dim ct As Integer = SafeInt(r, 1)
                        Dim tp As Integer = SafeInt(r, 2)
                        Dim gr As Integer = SafeInt(r, 3)
                        Dim sg As Integer = SafeInt(r, 4)
                        If IsSeoIndexAllowed(st, ct, tp, gr, sg, 0) Then
                            AddAbs(target, baseUrl, BuildCatalogUrl(st, ct, tp, gr, sg, 0))
                        End If
                    End While
                End Using
            End Using

        End Using
    End Sub

    Private Sub AddFacetListingWithoutTp(conn As MySqlConnection, target As HashSet(Of String), baseUrl As String, facetName As String, sql As String)
        Using cmd As New MySqlCommand(sql, conn)
            Using r As MySqlDataReader = cmd.ExecuteReader()
                While r.Read()
                    Dim st As Integer = SafeInt(r, 0)
                    Dim ct As Integer = SafeInt(r, 1)
                    Dim v As Integer = SafeInt(r, 2)

                    Dim gr As Integer = 0
                    Dim sg As Integer = 0
                    Dim mr As Integer = 0

                    If String.Equals(facetName, "GruppiId", StringComparison.OrdinalIgnoreCase) Then gr = v
                    If String.Equals(facetName, "SottogruppiId", StringComparison.OrdinalIgnoreCase) Then sg = v
                    If String.Equals(facetName, "MarcheId", StringComparison.OrdinalIgnoreCase) Then mr = v

                    If IsSeoIndexAllowed(st, ct, 0, gr, sg, mr) Then
                        AddAbs(target, baseUrl, BuildCatalogUrl(st, ct, 0, gr, sg, mr))
                    End If
                End While
            End Using
        End Using
    End Sub

    Private Sub AddFacetListingWithTp(conn As MySqlConnection, target As HashSet(Of String), baseUrl As String, facetName As String, sql As String)
        Using cmd As New MySqlCommand(sql, conn)
            Using r As MySqlDataReader = cmd.ExecuteReader()
                While r.Read()
                    Dim st As Integer = SafeInt(r, 0)
                    Dim ct As Integer = SafeInt(r, 1)
                    Dim tp As Integer = SafeInt(r, 2)
                    Dim v As Integer = SafeInt(r, 3)

                    Dim gr As Integer = 0
                    Dim sg As Integer = 0
                    Dim mr As Integer = 0

                    If String.Equals(facetName, "GruppiId", StringComparison.OrdinalIgnoreCase) Then gr = v
                    If String.Equals(facetName, "SottogruppiId", StringComparison.OrdinalIgnoreCase) Then sg = v
                    If String.Equals(facetName, "MarcheId", StringComparison.OrdinalIgnoreCase) Then mr = v

                    If IsSeoIndexAllowed(st, ct, tp, gr, sg, mr) Then
                        AddAbs(target, baseUrl, BuildCatalogUrl(st, ct, tp, gr, sg, mr))
                    End If
                End While
            End Using
        End Using
    End Sub

    Private Sub AddProductUrlsFromDb(target As HashSet(Of String), baseUrl As String)
        Dim cs As String = GetConnectionString()
        If String.IsNullOrEmpty(cs) Then Exit Sub

        Using conn As New MySqlConnection(cs)
            conn.Open()

            Using cmd As New MySqlCommand("SELECT DISTINCT id, TCid FROM vsuperarticoli WHERE id IS NOT NULL AND id<>0", conn)
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    While r.Read()
                        Dim id As Integer = SafeInt(r, 0)
                        Dim tc As Integer = SafeInt(r, 1)
                        If id <= 0 Then Continue While

                        Dim rel As String
                        If tc > 0 Then
                            rel = "articolo.aspx?id=" & id.ToString() & "&TCid=" & tc.ToString()
                        Else
                            rel = "articolo.aspx?id=" & id.ToString()
                        End If
                        AddAbs(target, baseUrl, rel)
                    End While
                End Using
            End Using
        End Using
    End Sub

    Private Shared Function BuildCatalogUrl(st As Integer, ct As Integer, tp As Integer, gr As Integer, sg As Integer, mr As Integer) As String
        Dim sb As New StringBuilder("articoli.aspx")
        Dim hasQ As Boolean = False

        AppendParam(sb, hasQ, "st", st)
        AppendParam(sb, hasQ, "ct", ct)
        AppendParam(sb, hasQ, "tp", tp)
        AppendParam(sb, hasQ, "gr", gr)
        AppendParam(sb, hasQ, "sg", sg)
        AppendParam(sb, hasQ, "mr", mr)

        Return sb.ToString()
    End Function

    Private Shared Sub AppendParam(sb As StringBuilder, ByRef hasQ As Boolean, key As String, value As Integer)
        If value <= 0 Then Exit Sub
        sb.Append(If(hasQ, "&", "?"))
        hasQ = True
        sb.Append(key)
        sb.Append("=")
        sb.Append(value.ToString())
    End Sub

    ' SEO allowlist (must match articoli.aspx.vb - STEP27)
    Private Shared Function IsSeoIndexAllowed(stId As Integer, ctId As Integer, tpId As Integer, grId As Integer, sgId As Integer, mrId As Integer) As Boolean
        If stId <= 0 OrElse ctId <= 0 Then Return False

        Dim facetCount As Integer = 0
        If grId > 0 Then facetCount += 1
        If sgId > 0 Then facetCount += 1
        If mrId > 0 Then facetCount += 1

        If tpId <= 0 Then
            ' Allow only: st+ct OR st+ct+(one facet)
            Return facetCount <= 1
        End If

        ' With tp:
        ' Allow: st+ct+tp OR st+ct+tp+(one facet)
        If facetCount <= 1 Then Return True

        ' Allow only the hierarchy pair: gr+sg (no mr) when tp is present
        If mrId > 0 Then Return False
        Return (grId > 0 AndAlso sgId > 0)
    End Function


    ' =========================
    ' LastMod map (best-effort from DB)
    ' =========================
    Private Function GetOrBuildLastModMap() As Dictionary(Of String, DateTime)
        Dim cached As Dictionary(Of String, DateTime) = TryCast(HttpRuntime.Cache(CACHE_KEY_LASTMOD), Dictionary(Of String, DateTime))
        If cached IsNot Nothing Then Return cached

        Dim map As Dictionary(Of String, DateTime) = BuildLastModMapFromDb()
        HttpRuntime.Cache.Insert(CACHE_KEY_LASTMOD, map, Nothing, DateTime.UtcNow.AddMinutes(CACHE_MINUTES), Cache.NoSlidingExpiration)
        Return map
    End Function

    Private Function BuildLastModMapFromDb() As Dictionary(Of String, DateTime)
        Dim result As New Dictionary(Of String, DateTime)(StringComparer.OrdinalIgnoreCase)

        Dim connStr As String = GetConnectionString()
        If String.IsNullOrEmpty(connStr) Then Return result

        Dim baseUrl As String = GetBaseUrl()

        Using conn As New MySqlConnection(connStr)
            conn.Open()

            Dim explicitCol As String = ConfigurationManager.AppSettings("KeepStore.Sitemap.LastModColumn")
            Dim lastModCol As String = Nothing
            If Not String.IsNullOrWhiteSpace(explicitCol) Then
                lastModCol = explicitCol.Trim()
            Else
                lastModCol = FindBestLastModColumn(conn, "vsuperarticoli")
            End If

            If String.IsNullOrWhiteSpace(lastModCol) Then
                Return result
            End If

            Dim safeCol As String = lastModCol.Replace("`", "``")

            Dim sql As String =
                "SELECT id, TCid, MAX(`" & safeCol & "`) AS lastmod " &
                "FROM vsuperarticoli " &
                "WHERE id IS NOT NULL AND id <> 0 AND TCid IS NOT NULL AND TCid <> 0 " &
                "GROUP BY id, TCid"

            Using cmd As New MySqlCommand(sql, conn)
                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim id As String = Convert.ToString(rdr("id"))
                        Dim tcid As String = Convert.ToString(rdr("TCid"))
                        If String.IsNullOrWhiteSpace(id) OrElse String.IsNullOrWhiteSpace(tcid) Then Continue While
                        If Convert.IsDBNull(rdr("lastmod")) Then Continue While

                        Dim lm As DateTime
                        Try
                            lm = Convert.ToDateTime(rdr("lastmod"), CultureInfo.InvariantCulture)
                        Catch
                            Continue While
                        End Try

                        If lm.Year <= 1900 Then Continue While

                        Dim url As String = EnsureAbsolute(baseUrl, BuildProductUrl(id, tcid))

                        If result.ContainsKey(url) Then
                            If lm > result(url) Then result(url) = lm
                        Else
                            result.Add(url, lm)
                        End If
                    End While
                End Using
            End Using
        End Using

        Return result
    End Function

    Private Function FindBestLastModColumn(conn As MySqlConnection, viewName As String) As String
        Dim candidates As String() = New String() {
            "lastmod", "last_mod", "modified", "modified_at", "updated_at",
            "datamodifica", "data_modifica", "datamod", "data_mod",
            "dataaggiornamento", "data_aggiornamento", "dataagg", "data_agg",
            "dataultima", "data_ultima", "dataultimamodifica", "data_ultimamodifica"
        }

        Dim inList As New StringBuilder()
        For i As Integer = 0 To candidates.Length - 1
            If i > 0 Then inList.Append(",")
            inList.Append("'")
            inList.Append(candidates(i).Replace("'", "''"))
            inList.Append("'")
        Next

        Dim sql As String =
            "SELECT COLUMN_NAME " &
            "FROM INFORMATION_SCHEMA.COLUMNS " &
            "WHERE TABLE_SCHEMA = DATABASE() " &
            "  AND TABLE_NAME = @tbl " &
            "  AND LOWER(COLUMN_NAME) IN (" & inList.ToString() & ") " &
            "LIMIT 1"

        Using cmd As New MySqlCommand(sql, conn)
            cmd.Parameters.AddWithValue("@tbl", viewName)
            Dim o As Object = cmd.ExecuteScalar()
            If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                Return Convert.ToString(o)
            End If
        End Using

        Return Nothing
    End Function

    ' =========================
    ' File cache (App_Data)
    ' =========================
    Private Function FileCacheEnabled() As Boolean
        Return ReadAppSettingBool("KeepStore.Sitemap.FileCacheEnabled", True)
    End Function

    Private Function FileCacheMinutes() As Integer
        Return ReadAppSettingInt("KeepStore.Sitemap.FileCacheMinutes", CACHE_MINUTES)
    End Function

    Private Function FileCacheFolderVirtual() As String
        Dim v As String = ConfigurationManager.AppSettings("KeepStore.Sitemap.FileCacheFolder")
        If String.IsNullOrWhiteSpace(v) Then v = "~/App_Data/Sitemaps"
        Return v.Trim()
    End Function

    Private Function GetFileCachePath(fileName As String) As String
        Dim folder As String = FileCacheFolderVirtual()

        Dim physicalFolder As String
        If folder.StartsWith("~", StringComparison.Ordinal) OrElse folder.StartsWith("/", StringComparison.Ordinal) Then
            physicalFolder = Server.MapPath(folder)
        ElseIf folder.IndexOf(":\", StringComparison.Ordinal) >= 0 OrElse folder.StartsWith("\\", StringComparison.Ordinal) Then
            physicalFolder = folder
        Else
            physicalFolder = Server.MapPath("~/" & folder.TrimStart("/"c))
        End If

        Return Path.Combine(physicalFolder, fileName)
    End Function

    Private Function TryServeFileCache(fileName As String) As Boolean
        If Not FileCacheEnabled() Then Return False

        Dim ttl As Integer = FileCacheMinutes()
        If ttl <= 0 Then Return False

        Dim p As String = GetFileCachePath(fileName)

        Try
            If File.Exists(p) Then
                Dim last As DateTime = File.GetLastWriteTimeUtc(p)
                If (DateTime.UtcNow - last) <= TimeSpan.FromMinutes(ttl) Then
                    Dim bytes As Byte() = File.ReadAllBytes(p)

                    Response.Clear()
                    Response.ContentType = "application/xml"
                    Response.ContentEncoding = Encoding.UTF8
                    Response.BinaryWrite(bytes)
                    Response.Flush()
                    Context.ApplicationInstance.CompleteRequest()
                    Return True
                End If
            End If
        Catch
        End Try

        Return False
    End Function

    Private Sub TryWriteFileCache(fileName As String, bytes As Byte())
        If Not FileCacheEnabled() Then Exit Sub

        Dim p As String = GetFileCachePath(fileName)

        Try
            SyncLock _fileCacheLock
                Dim dir As String = Path.GetDirectoryName(p)
                If Not Directory.Exists(dir) Then Directory.CreateDirectory(dir)
                File.WriteAllBytes(p, bytes)
            End SyncLock
        Catch
        End Try
    End Sub

    Private Function ReadAppSettingInt(key As String, defaultValue As Integer) As Integer
        Try
            Dim raw As String = ConfigurationManager.AppSettings(key)
            Dim v As Integer
            If Integer.TryParse(raw, v) Then Return v
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function ReadAppSettingBool(key As String, defaultValue As Boolean) As Boolean
        Try
            Dim raw As String = ConfigurationManager.AppSettings(key)
            If String.IsNullOrWhiteSpace(raw) Then Return defaultValue

            Dim v As Boolean
            If Boolean.TryParse(raw, v) Then Return v

            If String.Equals(raw.Trim(), "1", StringComparison.OrdinalIgnoreCase) Then Return True
            If String.Equals(raw.Trim(), "0", StringComparison.OrdinalIgnoreCase) Then Return False
        Catch
        End Try
        Return defaultValue
    End Function

    Private Shared Function SafeInt(r As MySqlDataReader, ordinal As Integer) As Integer
        If r Is Nothing OrElse ordinal < 0 OrElse ordinal >= r.FieldCount Then Return 0
        If r.IsDBNull(ordinal) Then Return 0
        Dim o As Object = r.GetValue(ordinal)
        If o Is Nothing Then Return 0
        Dim v As Integer = 0
        Integer.TryParse(Convert.ToString(o), v)
        Return v
    End Function

    Private Shared Sub AddAbs(target As HashSet(Of String), baseUrl As String, relOrAbs As String)
        If target Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(relOrAbs) Then Exit Sub

        Dim u As String = relOrAbs.Trim()
        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            target.Add(u)
            Exit Sub
        End If

        target.Add(CombineUrl(baseUrl, u))
    End Sub

    Private Shared Function CombineUrl(baseUrl As String, rel As String) As String
        Dim b As String = If(baseUrl, "").Trim()
        Dim r As String = If(rel, "").Trim()

        If String.IsNullOrEmpty(b) Then Return r
        If String.IsNullOrEmpty(r) Then Return b

        If b.EndsWith("/", StringComparison.Ordinal) Then b = b.Substring(0, b.Length - 1)
        If r.StartsWith("/", StringComparison.Ordinal) Then r = r.Substring(1)
        Return b & "/" & r
    End Function

    Private Function GetBaseUrl() As String
        Dim configured As String = Convert.ToString(ConfigurationManager.AppSettings("KeepStore.Sitemap.BaseUrl"))
        If Not String.IsNullOrEmpty(configured) Then
            configured = configured.Trim()
            If configured.EndsWith("/", StringComparison.Ordinal) Then
                configured = configured.Substring(0, configured.Length - 1)
            End If
            Return configured
        End If

        Dim req As HttpRequest = HttpContext.Current.Request
        Dim root As String = req.Url.GetLeftPart(UriPartial.Authority)
        Dim appPath As String = VirtualPathUtility.ToAbsolute("~")
        If String.IsNullOrEmpty(appPath) Then appPath = "/"
        If Not appPath.EndsWith("/", StringComparison.Ordinal) Then appPath &= "/"
        If appPath.StartsWith("/", StringComparison.Ordinal) Then appPath = appPath.Substring(1)

        Dim b As String = root
        If b.EndsWith("/", StringComparison.Ordinal) Then b = b.Substring(0, b.Length - 1)
        If String.IsNullOrEmpty(appPath) Then Return b
        Return b & "/" & appPath.TrimEnd("/"c)
    End Function

    Private Function GetConnectionString() As String
        Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("ConnString")
        If cs IsNot Nothing AndAlso Not String.IsNullOrEmpty(cs.ConnectionString) Then Return cs.ConnectionString

        cs = ConfigurationManager.ConnectionStrings("MySqlConnection")
        If cs IsNot Nothing AndAlso Not String.IsNullOrEmpty(cs.ConnectionString) Then Return cs.ConnectionString

        cs = ConfigurationManager.ConnectionStrings("MySqlConnectionString")
        If cs IsNot Nothing AndAlso Not String.IsNullOrEmpty(cs.ConnectionString) Then Return cs.ConnectionString

        ' Fallback: first connection string
        If ConfigurationManager.ConnectionStrings IsNot Nothing AndAlso ConfigurationManager.ConnectionStrings.Count > 0 Then
            Dim first As ConnectionStringSettings = ConfigurationManager.ConnectionStrings(0)
            If first IsNot Nothing AndAlso Not String.IsNullOrEmpty(first.ConnectionString) Then Return first.ConnectionString
        End If

        Return Nothing
    End Function

End Class