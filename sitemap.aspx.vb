Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.Caching
Imports MySql.Data.MySqlClient

Partial Class sitemap
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Clear()
        Response.ContentType = "application/xml"
        Response.ContentEncoding = Encoding.UTF8

        ' Cache (default 60 minuti)
        Dim cacheMinutes As Integer = GetIntAppSetting("KeepStore.Sitemap.CacheMinutes", 60)
        Dim cacheKey As String = "KeepStore.Sitemap.Xml.v33"
        Dim cached As String = TryCast(Context.Cache(cacheKey), String)

        If Not String.IsNullOrEmpty(cached) Then
            Response.Write(cached)
            Response.End()
            Return
        End If

        Dim baseUrl As String = GetBaseUrl()
        Dim lastMod As String = DateTime.UtcNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

        ' Limiti anti-esplosione (default 45000 url)
        Dim maxUrls As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxUrls", 45000)
        Dim urlCount As Integer = 0

        Dim sb As New StringBuilder(1024 * 64)
        sb.Append("<?xml version=""1.0"" encoding=""UTF-8""?>").Append(vbCrLf)
        sb.Append("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">").Append(vbCrLf)

        ' ---- URL STATICHE (minime e sicure) ----
        AddUrl(sb, "/", lastMod, "daily", "1.0", baseUrl, urlCount, maxUrls)
        AddUrl(sb, "/articoli.aspx", lastMod, "daily", "0.9", baseUrl, urlCount, maxUrls)

        ' Se queste pagine esistono nel tuo progetto, bene; se non esistono, puoi commentarle.
        AddUrl(sb, "/about.aspx", lastMod, "monthly", "0.4", baseUrl, urlCount, maxUrls)
        AddUrl(sb, "/contact.aspx", lastMod, "monthly", "0.4", baseUrl, urlCount, maxUrls)
        AddUrl(sb, "/privacy.aspx", lastMod, "yearly", "0.2", baseUrl, urlCount, maxUrls)
        AddUrl(sb, "/faq.aspx", lastMod, "yearly", "0.2", baseUrl, urlCount, maxUrls)

        ' ---- STEP33: URL DINAMICHE DA DB (prodotti + facet SEO consentite) ----
        Try
            AddDynamicDbUrls(sb, baseUrl, lastMod, urlCount, maxUrls)
        Catch
            ' Non blocchiamo mai la sitemap: in caso di errore DB, pubblichiamo almeno le statiche.
        End Try

        sb.Append("</urlset>")

        Dim xmlOut As String = sb.ToString()

        ' Cache pubblica lato crawler + cache server-side
        Response.Cache.SetCacheability(HttpCacheability.Public)
        Response.Cache.SetMaxAge(TimeSpan.FromMinutes(cacheMinutes))
        Context.Cache.Insert(cacheKey, xmlOut, Nothing, DateTime.UtcNow.AddMinutes(cacheMinutes), Cache.NoSlidingExpiration)

        Response.Write(xmlOut)
        Response.End()
    End Sub

    Private Sub AddDynamicDbUrls(ByVal sb As StringBuilder,
                                 ByVal baseUrl As String,
                                 ByVal lastMod As String,
                                 ByRef urlCount As Integer,
                                 ByVal maxUrls As Integer)

        Dim connName As String = GetStringAppSetting("KeepStore.Sitemap.ConnectionStringName", "EntropicConnectionString")
        Dim cs = ConfigurationManager.ConnectionStrings(connName)
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then Exit Sub

        ' Tabella/view sorgente: preferisco vsuperarticoli (se esiste), altrimenti articoli
        Dim preferredSource As String = GetStringAppSetting("KeepStore.Sitemap.Source", "vsuperarticoli")
        Dim source As String = SafeIdentifier(preferredSource)
        If String.IsNullOrEmpty(source) Then source = "vsuperarticoli"

        Dim includeProducts As Boolean = (GetStringAppSetting("KeepStore.Sitemap.IncludeProducts", "1") <> "0")
        Dim includeFacets As Boolean = (GetStringAppSetting("KeepStore.Sitemap.IncludeFacets", "1") <> "0")

        ' Limiti “per ramo”
        Dim maxProducts As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxProducts", 20000)
        Dim maxPairs As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxSettoreCategoria", 2000)
        Dim maxBrands As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxBrandsPerPair", 30)
        Dim maxGroups As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxGroupsPerPair", 30)
        Dim maxGroupSubPairs As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxGroupSubPairsPerPair", 40)
        Dim maxTypes As Integer = GetIntAppSetting("KeepStore.Sitemap.MaxTipologiePerPair", 12)

        Dim productDetailFmt As String = GetStringAppSetting("KeepStore.Sitemap.ProductDetailFormat", "articolo.aspx?id={0}")

        Using cn As New MySqlConnection(cs.ConnectionString)
            cn.Open()

            If Not DbObjectExists(cn, source) Then
                source = "articoli"
                If Not DbObjectExists(cn, source) Then Exit Sub
            End If

            ' ========== 1) DETTAGLIO PRODOTTI ==========
            If includeProducts AndAlso urlCount < maxUrls Then
                Dim sqlProd As String =
                    "SELECT DISTINCT id " &
                    "FROM `" & source & "` " &
                    "WHERE id > 0 " &
                    "ORDER BY id DESC " &
                    "LIMIT @lim;"

                Using cmd As New MySqlCommand(sqlProd, cn)
                    cmd.CommandTimeout = 30
                    cmd.Parameters.AddWithValue("@lim", maxProducts)

                    Using r = cmd.ExecuteReader()
                        While r.Read() AndAlso urlCount < maxUrls
                            Dim id As Integer = Convert.ToInt32(r(0))
                            Dim rel As String = String.Format(CultureInfo.InvariantCulture, productDetailFmt, id)
                            AddUrl(sb, "/" & rel.TrimStart("/"c), lastMod, "weekly", "0.7", baseUrl, urlCount, maxUrls)
                        End While
                    End Using
                End Using
            End If

            ' ========== 2) LISTING FACET SEO (solo combinazioni consentite) ==========
            If includeFacets AndAlso urlCount < maxUrls Then

                ' Coppie base: st+ct
                Dim sqlPairs As String =
                    "SELECT DISTINCT SettoriId, CategorieId " &
                    "FROM `" & source & "` " &
                    "WHERE SettoriId > 0 AND CategorieId > 0 " &
                    "LIMIT @lim;"

                Dim pairs As New List(Of Tuple(Of Integer, Integer))()

                Using cmdPairs As New MySqlCommand(sqlPairs, cn)
                    cmdPairs.CommandTimeout = 30
                    cmdPairs.Parameters.AddWithValue("@lim", maxPairs)

                    Using r = cmdPairs.ExecuteReader()
                        While r.Read()
                            Dim st As Integer = Convert.ToInt32(r(0))
                            Dim ct As Integer = Convert.ToInt32(r(1))
                            pairs.Add(Tuple.Create(st, ct))
                        End While
                    End Using
                End Using

                For Each p In pairs
                    If urlCount >= maxUrls Then Exit For

                    Dim st As Integer = p.Item1
                    Dim ct As Integer = p.Item2

                    ' Base indexabile: st+ct
                    AddUrl(sb, "/" & BuildArticoliUrl(st, ct, 0, 0, 0, 0), lastMod, "daily", "0.8", baseUrl, urlCount, maxUrls)
                    If urlCount >= maxUrls Then Exit For

                    ' Tipologie (tp) - opzionale, sempre con st+ct
                    Dim tpList As List(Of Integer) = GetTopIds(cn, source, "TipologieId", st, ct, maxTypes)
                    For Each tp In tpList
                        If urlCount >= maxUrls Then Exit For
                        AddUrl(sb, "/" & BuildArticoliUrl(st, ct, tp, 0, 0, 0), lastMod, "weekly", "0.7", baseUrl, urlCount, maxUrls)
                    Next

                    ' Marche (mr) - (st+ct + mr) (tp NON combinato qui, per evitare esplosione)
                    Dim mrList As List(Of Integer) = GetTopIds(cn, source, "MarcheId", st, ct, maxBrands)
                    For Each mr In mrList
                        If urlCount >= maxUrls Then Exit For
                        AddUrl(sb, "/" & BuildArticoliUrl(st, ct, 0, mr, 0, 0), lastMod, "weekly", "0.65", baseUrl, urlCount, maxUrls)
                    Next

                    ' Gruppi (gr) - (st+ct + gr)
                    Dim grList As List(Of Integer) = GetTopIds(cn, source, "GruppiId", st, ct, maxGroups)
                    For Each gr In grList
                        If urlCount >= maxUrls Then Exit For
                        AddUrl(sb, "/" & BuildArticoliUrl(st, ct, 0, 0, gr, 0), lastMod, "weekly", "0.65", baseUrl, urlCount, maxUrls)
                    Next

                    ' Gruppo + Sottogruppo (gr+sg) - combinazione consentita
                    Dim sqlGrSg As String =
                        "SELECT GruppiId, SottoGruppiId, COUNT(*) AS cnt " &
                        "FROM `" & source & "` " &
                        "WHERE SettoriId=@st AND CategorieId=@ct AND GruppiId>0 AND SottoGruppiId>0 " &
                        "GROUP BY GruppiId, SottoGruppiId " &
                        "ORDER BY cnt DESC " &
                        "LIMIT @lim;"

                    Using cmd As New MySqlCommand(sqlGrSg, cn)
                        cmd.CommandTimeout = 30
                        cmd.Parameters.AddWithValue("@st", st)
                        cmd.Parameters.AddWithValue("@ct", ct)
                        cmd.Parameters.AddWithValue("@lim", maxGroupSubPairs)

                        Using r = cmd.ExecuteReader()
                            While r.Read() AndAlso urlCount < maxUrls
                                Dim gr As Integer = Convert.ToInt32(r(0))
                                Dim sg As Integer = Convert.ToInt32(r(1))
                                AddUrl(sb, "/" & BuildArticoliUrl(st, ct, 0, 0, gr, sg), lastMod, "weekly", "0.6", baseUrl, urlCount, maxUrls)
                            End While
                        End Using
                    End Using
                Next
            End If

        End Using
    End Sub

    Private Function GetTopIds(ByVal cn As MySqlConnection,
                              ByVal source As String,
                              ByVal col As String,
                              ByVal st As Integer,
                              ByVal ct As Integer,
                              ByVal lim As Integer) As List(Of Integer)

        Dim safeCol As String = SafeIdentifier(col)
        Dim res As New List(Of Integer)()
        If String.IsNullOrEmpty(safeCol) Then Return res
        If lim <= 0 Then Return res

        Dim sql As String =
            "SELECT " & safeCol & " AS id, COUNT(*) AS cnt " &
            "FROM `" & source & "` " &
            "WHERE SettoriId=@st AND CategorieId=@ct AND " & safeCol & " > 0 " &
            "GROUP BY " & safeCol & " " &
            "ORDER BY cnt DESC " &
            "LIMIT @lim;"

        Using cmd As New MySqlCommand(sql, cn)
            cmd.CommandTimeout = 30
            cmd.Parameters.AddWithValue("@st", st)
            cmd.Parameters.AddWithValue("@ct", ct)
            cmd.Parameters.AddWithValue("@lim", lim)

            Using r = cmd.ExecuteReader()
                While r.Read()
                    res.Add(Convert.ToInt32(r(0)))
                End While
            End Using
        End Using

        Return res
    End Function

    Private Function BuildArticoliUrl(ByVal st As Integer,
                                      ByVal ct As Integer,
                                      ByVal tp As Integer,
                                      ByVal mr As Integer,
                                      ByVal gr As Integer,
                                      ByVal sg As Integer) As String

        ' Canonical stabile: st, ct, tp, mr, gr, sg
        Dim q As New List(Of String)()
        q.Add("st=" & st.ToString(CultureInfo.InvariantCulture))
        q.Add("ct=" & ct.ToString(CultureInfo.InvariantCulture))

        If tp > 0 Then q.Add("tp=" & tp.ToString(CultureInfo.InvariantCulture))
        If mr > 0 Then q.Add("mr=" & mr.ToString(CultureInfo.InvariantCulture))
        If gr > 0 Then q.Add("gr=" & gr.ToString(CultureInfo.InvariantCulture))
        If sg > 0 Then q.Add("sg=" & sg.ToString(CultureInfo.InvariantCulture))

        Return "articoli.aspx?" & String.Join("&", q.ToArray())
    End Function

    Private Sub AddUrl(ByVal sb As StringBuilder,
                       ByVal loc As String,
                       ByVal lastmod As String,
                       ByVal changefreq As String,
                       ByVal priority As String,
                       ByVal baseUrl As String,
                       ByRef urlCount As Integer,
                       ByVal maxUrls As Integer)

        If urlCount >= maxUrls Then Exit Sub

        Dim fullLoc As String = loc
        If Not fullLoc.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            If Not fullLoc.StartsWith("/", StringComparison.Ordinal) Then fullLoc = "/" & fullLoc
            fullLoc = baseUrl.TrimEnd("/"c) & fullLoc
        End If

        sb.Append("  <url>").Append(vbCrLf)
        sb.Append("    <loc>").Append(HttpUtility.HtmlEncode(fullLoc)).Append("</loc>").Append(vbCrLf)
        sb.Append("    <lastmod>").Append(lastmod).Append("</lastmod>").Append(vbCrLf)
        sb.Append("    <changefreq>").Append(changefreq).Append("</changefreq>").Append(vbCrLf)
        sb.Append("    <priority>").Append(priority).Append("</priority>").Append(vbCrLf)
        sb.Append("  </url>").Append(vbCrLf)

        urlCount += 1
    End Sub

    Private Function GetBaseUrl() As String
        Dim absApp As String = VirtualPathUtility.ToAbsolute("~/")
        Dim u As Uri = Request.Url
        Dim basePart As String = u.Scheme & "://" & u.Authority
        Return basePart.TrimEnd("/"c) & absApp.TrimEnd("/"c)
    End Function

    Private Function DbObjectExists(ByVal cn As MySqlConnection, ByVal name As String) As Boolean
        Dim obj As String = SafeIdentifier(name)
        If String.IsNullOrEmpty(obj) Then Return False

        Dim sql As String =
            "SELECT COUNT(*) " &
            "FROM information_schema.tables " &
            "WHERE table_schema = DATABASE() AND table_name = @n;"

        Using cmd As New MySqlCommand(sql, cn)
            cmd.CommandTimeout = 15
            cmd.Parameters.AddWithValue("@n", obj)
            Dim n As Integer = Convert.ToInt32(cmd.ExecuteScalar())
            Return (n > 0)
        End Using
    End Function

    Private Function SafeIdentifier(ByVal s As String) As String
        If String.IsNullOrEmpty(s) Then Return ""
        s = s.Trim()

        ' Permettiamo solo A-Z a-z 0-9 _
        For Each ch As Char In s
            If Not (Char.IsLetterOrDigit(ch) OrElse ch = "_"c) Then
                Return ""
            End If
        Next

        Return s
    End Function

    Private Function GetStringAppSetting(ByVal key As String, ByVal defValue As String) As String
        Dim v As String = ConfigurationManager.AppSettings(key)
        If String.IsNullOrEmpty(v) Then Return defValue
        Return v
    End Function

    Private Function GetIntAppSetting(ByVal key As String, ByVal defValue As Integer) As Integer
        Dim v As String = ConfigurationManager.AppSettings(key)
        Dim n As Integer
        If Integer.TryParse(v, n) Then Return n
        Return defValue
    End Function

End Class
