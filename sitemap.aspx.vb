Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Text
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
    Private Const CACHE_MINUTES As Integer = 60

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.ContentType = "application/xml"
        Response.ContentEncoding = Encoding.UTF8

        Dim allUrls As List(Of String) = GetOrBuildUrlList()
        If allUrls Is Nothing Then allUrls = New List(Of String)()

        Dim part As Integer = 0
        Integer.TryParse(Request.QueryString("part"), part)

        If allUrls.Count > MAX_URLS_PER_SITEMAP AndAlso part <= 0 Then
            WriteSitemapIndex(allUrls.Count)
        Else
            WriteUrlSet(allUrls, part)
        End If

        Response.Flush()
        HttpContext.Current.ApplicationInstance.CompleteRequest()
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

    Private Sub WriteSitemapIndex(totalCount As Integer)
        Dim baseUrl As String = GetBaseUrl()
        Dim parts As Integer = CInt(Math.Ceiling(totalCount / CDbl(MAX_URLS_PER_SITEMAP)))

        Dim settings As New XmlWriterSettings()
        settings.Encoding = Encoding.UTF8
        settings.Indent = True
        settings.OmitXmlDeclaration = False

        Using xw As XmlWriter = XmlWriter.Create(Response.Output, settings)
            xw.WriteStartDocument()
            xw.WriteStartElement("sitemapindex", "http://www.sitemaps.org/schemas/sitemap/0.9")

            For i As Integer = 1 To parts
                xw.WriteStartElement("sitemap")
                xw.WriteElementString("loc", CombineUrl(baseUrl, "sitemap.aspx?part=" & i.ToString()))
                xw.WriteElementString("lastmod", DateTime.UtcNow.ToString("yyyy-MM-dd"))
                xw.WriteEndElement()
            Next

            xw.WriteEndElement()
            xw.WriteEndDocument()
        End Using
    End Sub

    Private Sub WriteUrlSet(allUrls As List(Of String), part As Integer)
        Dim startIndex As Integer = 0
        If part > 0 Then
            startIndex = (part - 1) * MAX_URLS_PER_SITEMAP
        End If

        If startIndex < 0 Then startIndex = 0
        If startIndex > allUrls.Count Then startIndex = allUrls.Count

        Dim takeCount As Integer = Math.Min(MAX_URLS_PER_SITEMAP, Math.Max(0, allUrls.Count - startIndex))
        Dim slice As List(Of String)
        If startIndex = 0 AndAlso takeCount = allUrls.Count Then
            slice = allUrls
        Else
            slice = allUrls.GetRange(startIndex, takeCount)
        End If

        Dim settings As New XmlWriterSettings()
        settings.Encoding = Encoding.UTF8
        settings.Indent = True
        settings.OmitXmlDeclaration = False

        Using xw As XmlWriter = XmlWriter.Create(Response.Output, settings)
            xw.WriteStartDocument()
            xw.WriteStartElement("urlset", "http://www.sitemaps.org/schemas/sitemap/0.9")

            For Each url As String In slice
                If String.IsNullOrEmpty(url) Then Continue For
                xw.WriteStartElement("url")
                xw.WriteElementString("loc", url)
                xw.WriteElementString("lastmod", DateTime.UtcNow.ToString("yyyy-MM-dd"))
                xw.WriteEndElement()
            Next

            xw.WriteEndElement()
            xw.WriteEndDocument()
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
