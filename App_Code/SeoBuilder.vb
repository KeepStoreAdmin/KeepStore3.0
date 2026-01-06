Imports System
Imports System.Text
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Data.Common
Imports System.Globalization
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls

' ============================================================
' SEO BUILDER - KeepStore / taikun.it
' - JSON-LD avanzato in un unico @graph
' - Helper meta OpenGraph
' - Funzione JsonEscape centralizzata
'
' NOTE:
' - Compatibile .NET Framework 4.x / VB 2012
' - Query parametrizzate
' - Database-agnostico via DbProviderFactory (EntropicConnectionString)
' ============================================================

Public Interface ISeoMaster
    Property SeoJsonLd As String
End Interface

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ------------------------------
    ' Public API
    ' ------------------------------
    Public Shared Sub ApplyOpenGraph(ByVal page As Page, ByVal title As String, ByVal description As String, ByVal url As String, ByVal imageUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return

        AddOrReplaceMetaProperty(page, "og:type", "website")
        AddOrReplaceMetaProperty(page, "og:title", title)
        AddOrReplaceMetaProperty(page, "og:description", description)
        AddOrReplaceMetaProperty(page, "og:url", url)

        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMetaProperty(page, "og:image", imageUrl)
        End If

        ' Twitter (minimo)
        AddOrReplaceMetaName(page, "twitter:card", "summary_large_image")
        AddOrReplaceMetaName(page, "twitter:title", title)
        AddOrReplaceMetaName(page, "twitter:description", description)
        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMetaName(page, "twitter:image", imageUrl)
        End If
    End Sub

    Public Shared Function BuildHomeJsonLd(ByVal page As Page,
                                          ByVal pageTitle As String,
                                          ByVal pageDescription As String,
                                          ByVal canonicalUrl As String,
                                          ByVal logoUrl As String) As String

        Dim baseUrl As String = GetBaseUrl(page, canonicalUrl)
        Dim siteName As String = SafeSessionString(page, "AziendaNome", "KeepStore")
        Dim currency As String = SafeSessionString(page, "AziendaValuta", "EUR")
        Dim lang As String = SafeSessionString(page, "AziendaLanguage", "it-IT")

        Dim company As SeoCompany = TryGetCompany(page)
        Dim categories As List(Of SeoCategory) = TryGetCategories(page, 24)
        Dim products As List(Of SeoProduct) = TryGetHomeProducts(page, 12)

        Dim graph As New List(Of String)()

        ' --- ImageObject (logo)
        Dim logoId As String = baseUrl & "#logo"
        If Not String.IsNullOrEmpty(logoUrl) Then
            Dim logoAbs As String = MakeAbsoluteUrl(baseUrl, logoUrl)
            graph.Add("{" &
                      """@type"":""ImageObject""," &
                      """@id"":""" & JsonEscape(logoId) & """," &
                      """url"":""" & JsonEscape(logoAbs) & """," &
                      """contentUrl"":""" & JsonEscape(logoAbs) & """," &
                      """caption"":""" & JsonEscape(siteName & " - Logo") & """" &
                      "}")
        End If

        ' --- Organization
        Dim orgId As String = baseUrl & "#organization"
        graph.Add("{" &
                  """@type"":""Organization""," &
                  """@id"":""" & JsonEscape(orgId) & """," &
                  """name"":""" & JsonEscape(siteName) & """," &
                  """url"":""" & JsonEscape(baseUrl) & """" &
                  If(String.IsNullOrEmpty(logoUrl), "", ","""logo"":{""@id"":""" & JsonEscape(logoId) & """}") &
                  If(String.IsNullOrEmpty(company.Email), "", ","""email"":""" & JsonEscape(company.Email) & """") &
                  If(String.IsNullOrEmpty(company.Telephone), "", ","""telephone"":""" & JsonEscape(company.Telephone) & """") &
                  "}")

        ' --- LocalBusiness / Store
        Dim storeId As String = baseUrl & "#store"
        Dim addrJson As String = ""
        If company.HasAddress Then
            addrJson =
                ",""address"":{" &
                """@type"":""PostalAddress""," &
                """streetAddress"":""" & JsonEscape(company.Indirizzo) & """," &
                """postalCode"":""" & JsonEscape(company.Cap) & """," &
                """addressLocality"":""" & JsonEscape(company.Citta) & """," &
                """addressRegion"":""" & JsonEscape(company.Provincia) & """," &
                """addressCountry"":""" & JsonEscape(company.IdPaese) & """" &
                "}"
        End If

        graph.Add("{" &
                  """@type"":""Store""," &
                  """@id"":""" & JsonEscape(storeId) & """," &
                  """name"":""" & JsonEscape(siteName) & """," &
                  """url"":""" & JsonEscape(baseUrl) & """" &
                  If(String.IsNullOrEmpty(company.Telephone), "", ","""telephone"":""" & JsonEscape(company.Telephone) & """") &
                  If(String.IsNullOrEmpty(company.Email), "", ","""email"":""" & JsonEscape(company.Email) & """") &
                  If(String.IsNullOrEmpty(logoUrl), "", ","""image"":{""@id"":""" & JsonEscape(logoId) & """}") &
                  addrJson &
                  ",""parentOrganization"":{""@id"":""" & JsonEscape(orgId) & """}" &
                  "}")

        ' --- WebSite + SearchAction
        Dim websiteId As String = baseUrl & "#website"
        Dim searchTarget As String = baseUrl & "articoli.aspx?q={search_term_string}"
        graph.Add("{" &
                  """@type"":""WebSite""," &
                  """@id"":""" & JsonEscape(websiteId) & """," &
                  """url"":""" & JsonEscape(baseUrl) & """," &
                  """name"":""" & JsonEscape(siteName) & """," &
                  """inLanguage"":""" & JsonEscape(lang) & """," &
                  """publisher"":{""@id"":""" & JsonEscape(orgId) & """}," &
                  """potentialAction"":{" &
                    """@type"":""SearchAction""," &
                    """target"":""" & JsonEscape(searchTarget) & """," &
                    """query-input"":""required name=search_term_string""" &
                  "}" &
                  "}")

        ' --- WebPage (Home)
        Dim webpageId As String = canonicalUrl.TrimEnd("/"c) & "#webpage"
        graph.Add("{" &
                  """@type"":""WebPage""," &
                  """@id"":""" & JsonEscape(webpageId) & """," &
                  """url"":""" & JsonEscape(canonicalUrl) & """," &
                  """name"":""" & JsonEscape(pageTitle) & """," &
                  """description"":""" & JsonEscape(pageDescription) & """," &
                  """isPartOf"":{""@id"":""" & JsonEscape(websiteId) & """}," &
                  """about"":{""@id"":""" & JsonEscape(storeId) & """}," &
                  """inLanguage"":""" & JsonEscape(lang) & """" &
                  "}")

        ' --- BreadcrumbList (Home)
        graph.Add("{" &
                  """@type"":""BreadcrumbList""," &
                  """@id"":""" & JsonEscape(canonicalUrl.TrimEnd("/"c) & "#breadcrumb") & """," &
                  """itemListElement"":[{" &
                    """@type"":""ListItem"",""position"":1," &
                    """name"":""Home""," &
                    """item"":""" & JsonEscape(baseUrl) & """" &
                  "}]" &
                  "}")

        ' --- ItemList Categorie
        If categories IsNot Nothing AndAlso categories.Count > 0 Then
            Dim items As New List(Of String)()
            Dim pos As Integer = 1
            For Each c As SeoCategory In categories
                Dim catUrl As String = baseUrl & "articoli.aspx?ct=" & c.Id.ToString()
                items.Add("{" &
                          """@type"":""ListItem""," &
                          """position"":" & pos.ToString() & "," &
                          """name"":""" & JsonEscape(c.Name) & """," &
                          """item"":""" & JsonEscape(catUrl) & """" &
                          "}")
                pos += 1
            Next

            graph.Add("{" &
                      """@type"":""ItemList""," &
                      """@id"":""" & JsonEscape(baseUrl & "#categories") & """," &
                      """name"":""Categorie""," &
                      """itemListElement"":[" & String.Join(",", items.ToArray()) & "]" &
                      "}")
        End If

        ' --- Products + ItemList
        If products IsNot Nothing AndAlso products.Count > 0 Then
            Dim productRefs As New List(Of String)()
            Dim pos As Integer = 1

            For Each p As SeoProduct In products
                Dim prodUrl As String = baseUrl & "articolo.aspx?pid=" & p.Id.ToString()
                Dim prodId As String = prodUrl & "#product"

                Dim offerJson As String = ""
                If p.Price > 0D Then
                    offerJson =
                        ",""offers"":{" &
                        """@type"":""Offer""," &
                        """url"":""" & JsonEscape(prodUrl) & """," &
                        """priceCurrency"":""" & JsonEscape(currency) & """," &
                        """price"":""" & p.Price.ToString("0.##", CultureInfo.InvariantCulture) & """," &
                        """availability"":""" & JsonEscape(p.AvailabilitySchemaUrl) & """," &
                        """itemCondition"":""https://schema.org/NewCondition""" &
                        "}"
                End If

                Dim imgJson As String = ""
                If Not String.IsNullOrEmpty(p.ImageUrl) Then
                    Dim imgAbs As String = MakeAbsoluteUrl(baseUrl, p.ImageUrl)
                    imgJson = ",""image"":[""" & JsonEscape(imgAbs) & """]"
                End If

                graph.Add("{" &
                          """@type"":""Product""," &
                          """@id"":""" & JsonEscape(prodId) & """," &
                          """name"":""" & JsonEscape(p.Name) & """," &
                          """sku"":""" & JsonEscape(p.Id.ToString()) & """," &
                          """url"":""" & JsonEscape(prodUrl) & """" &
                          imgJson &
                          offerJson &
                          "}")

                productRefs.Add("{" &
                                """@type"":""ListItem""," &
                                """position"":" & pos.ToString() & "," &
                                """item"":{""@id"":""" & JsonEscape(prodId) & """}" &
                                "}")
                pos += 1
            Next

            graph.Add("{" &
                      """@type"":""ItemList""," &
                      """@id"":""" & JsonEscape(baseUrl & "#home-products") & """," &
                      """name"":""Prodotti in evidenza""," &
                      """itemListElement"":[" & String.Join(",", productRefs.ToArray()) & "]" &
                      "}")
        End If

        ' --- FAQPage (generico, estendibile)
        Dim faq As List(Of SeoFaq) = GetDefaultHomeFaq()
        If faq IsNot Nothing AndAlso faq.Count > 0 Then
            Dim qas As New List(Of String)()
            For Each f As SeoFaq In faq
                qas.Add("{" &
                        """@type"":""Question""," &
                        """name"":""" & JsonEscape(f.Question) & """," &
                        """acceptedAnswer"":{""@type"":""Answer"",""text"":""" & JsonEscape(f.Answer) & """}" &
                        "}")
            Next

            graph.Add("{" &
                      """@type"":""FAQPage""," &
                      """@id"":""" & JsonEscape(baseUrl & "#faq") & """," &
                      """mainEntity"":[" & String.Join(",", qas.ToArray()) & "]" &
                      "}")
        End If

        Dim json As String =
            "{" &
            """@context"":""https://schema.org""," &
            """@graph"":[" & String.Join(",", graph.ToArray()) & "]" &
            "}"

        Return "<script type=""application/ld+json"">" & json & "</script>"
    End Function

    ' ------------------------------
    ' Data fetch helpers
    ' ------------------------------
    Private Shared Function TryGetCompany(ByVal page As Page) As SeoCompany
        Dim c As New SeoCompany()

        ' Prima prova: Session (se valorizzate dalla master)
        c.RagioneSociale = SafeSessionString(page, "AziendaNome", "")
        c.Email = SafeSessionString(page, "AziendaEmail", "")
        c.Telephone = SafeSessionString(page, "AziendaTelefono", "")
        c.Indirizzo = SafeSessionString(page, "AziendaIndirizzo", "")
        c.Cap = SafeSessionString(page, "AziendaCap", "")
        c.Citta = SafeSessionString(page, "AziendaCitta", "")
        c.Provincia = SafeSessionString(page, "AziendaProvincia", "")
        c.IdPaese = SafeSessionString(page, "AziendaIdPaese", SafeSessionString(page, "AziendaFE_IdPaese", "IT"))

        ' Seconda prova: query Aziende
        If c.HasAddress AndAlso (Not String.IsNullOrEmpty(c.Email) OrElse Not String.IsNullOrEmpty(c.Telephone)) Then
            Return c
        End If

        Try
            Dim aziendaId As Integer = SafeSessionInt(page, "AziendaID", 0)
            Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then Return c

            Dim provider As String = cs.ProviderName
            Dim isMySql As Boolean = (Not String.IsNullOrEmpty(provider) AndAlso provider.IndexOf("MySql", StringComparison.OrdinalIgnoreCase) >= 0)

            Dim sql As String
            If aziendaId > 0 Then
                sql = "SELECT RagioneSociale, Indirizzo, Cap, Citta, Provincia, FE_IdPaese, Telefono, Email FROM Aziende WHERE Id = @id"
            Else
                If isMySql Then
                    sql = "SELECT RagioneSociale, Indirizzo, Cap, Citta, Provincia, FE_IdPaese, Telefono, Email FROM Aziende ORDER BY Id LIMIT 1"
                Else
                    sql = "SELECT TOP 1 RagioneSociale, Indirizzo, Cap, Citta, Provincia, FE_IdPaese, Telefono, Email FROM Aziende ORDER BY Id"
                End If
            End If

            Using cn As DbConnection = CreateConnection(cs)
                cn.Open()
                Using cmd As DbCommand = cn.CreateCommand()
                    cmd.CommandText = sql
                    cmd.CommandType = CommandType.Text
                    If aziendaId > 0 Then
                        Dim p As DbParameter = cmd.CreateParameter()
                        p.ParameterName = "@id"
                        p.Value = aziendaId
                        cmd.Parameters.Add(p)
                    End If

                    Using dr As DbDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            c.RagioneSociale = SafeDbString(dr, 0, c.RagioneSociale)
                            c.Indirizzo = SafeDbString(dr, 1, c.Indirizzo)
                            c.Cap = SafeDbString(dr, 2, c.Cap)
                            c.Citta = SafeDbString(dr, 3, c.Citta)
                            c.Provincia = SafeDbString(dr, 4, c.Provincia)
                            c.IdPaese = SafeDbString(dr, 5, c.IdPaese)
                            c.Telephone = SafeDbString(dr, 6, c.Telephone)
                            c.Email = SafeDbString(dr, 7, c.Email)
                        End If
                    End Using
                End Using
            End Using
        Catch
            ' fail safe: ritorna quanto abbiamo
        End Try

        If String.IsNullOrEmpty(c.IdPaese) Then c.IdPaese = "IT"
        Return c
    End Function

    Private Shared Function TryGetCategories(ByVal page As Page, ByVal maxItems As Integer) As List(Of SeoCategory)
        Dim list As New List(Of SeoCategory)()

        Try
            Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then Return list
            Dim provider As String = cs.ProviderName
            Dim isMySql As Boolean = (Not String.IsNullOrEmpty(provider) AndAlso provider.IndexOf("MySql", StringComparison.OrdinalIgnoreCase) >= 0)

            Dim sql As String
            If isMySql Then
                sql = "SELECT Id, Descrizione FROM Categorie ORDER BY Ordinamento, Descrizione LIMIT " & Math.Max(1, maxItems).ToString()
            Else
                sql = "SELECT TOP " & Math.Max(1, maxItems).ToString() & " Id, Descrizione FROM Categorie ORDER BY Ordinamento, Descrizione"
            End If

            Using cn As DbConnection = CreateConnection(cs)
                cn.Open()
                Using cmd As DbCommand = cn.CreateCommand()
                    cmd.CommandText = sql
                    cmd.CommandType = CommandType.Text
                    Using dr As DbDataReader = cmd.ExecuteReader()
                        While dr.Read()
                            Dim c As New SeoCategory()
                            c.Id = SafeDbInt(dr, 0, 0)
                            c.Name = SafeDbString(dr, 1, "")
                            If c.Id > 0 AndAlso Not String.IsNullOrEmpty(c.Name) Then
                                list.Add(c)
                            End If
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try

        Return list
    End Function

    Private Shared Function TryGetHomeProducts(ByVal page As Page, ByVal maxItems As Integer) As List(Of SeoProduct)
        Dim list As New List(Of SeoProduct)()

        Try
            Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then Return list
            Dim provider As String = cs.ProviderName
            Dim isMySql As Boolean = (Not String.IsNullOrEmpty(provider) AndAlso provider.IndexOf("MySql", StringComparison.OrdinalIgnoreCase) >= 0)

            Dim take As Integer = Math.Max(1, maxItems)

            Dim sql As String
            If isMySql Then
                sql = "SELECT a.id, a.Descrizione1, a.Prezzo, a.PrezzoScontato, a.Img1, IFNULL(g.Giacenza,0) AS Giacenza " &
                      "FROM Articoli a " &
                      "LEFT JOIN articoli_giacenze g ON g.ArticoliId = a.id " &
                      "ORDER BY a.id DESC LIMIT " & take.ToString()
            Else
                sql = "SELECT TOP " & take.ToString() & " a.id, a.Descrizione1, a.Prezzo, a.PrezzoScontato, a.Img1, ISNULL(g.Giacenza,0) AS Giacenza " &
                      "FROM Articoli a " &
                      "LEFT JOIN articoli_giacenze g ON g.ArticoliId = a.id " &
                      "ORDER BY a.id DESC"
            End If

            Using cn As DbConnection = CreateConnection(cs)
                cn.Open()
                Using cmd As DbCommand = cn.CreateCommand()
                    cmd.CommandText = sql
                    cmd.CommandType = CommandType.Text
                    Using dr As DbDataReader = cmd.ExecuteReader()
                        While dr.Read()
                            Dim p As New SeoProduct()
                            p.Id = SafeDbInt(dr, 0, 0)
                            p.Name = SafeDbString(dr, 1, "")
                            p.Price = SafeDbDecimal(dr, 2, 0D)
                            Dim ps As Decimal = SafeDbDecimal(dr, 3, 0D)
                            If ps > 0D AndAlso ps < p.Price Then
                                p.Price = ps
                            End If
                            p.ImageUrl = SafeDbString(dr, 4, "")
                            Dim giac As Integer = SafeDbInt(dr, 5, 0)
                            p.AvailabilitySchemaUrl = If(giac > 0, "https://schema.org/InStock", "https://schema.org/OutOfStock")

                            If p.Id > 0 AndAlso Not String.IsNullOrEmpty(p.Name) Then
                                list.Add(p)
                            End If
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try

        Return list
    End Function

    ' ------------------------------
    ' Low-level helpers
    ' ------------------------------
    Private Shared Function CreateConnection(ByVal cs As ConnectionStringSettings) As DbConnection
        Dim provider As String = cs.ProviderName
        If String.IsNullOrEmpty(provider) Then
            provider = "System.Data.SqlClient"
        End If
        Dim factory As DbProviderFactory = DbProviderFactories.GetFactory(provider)
        Dim cn As DbConnection = factory.CreateConnection()
        cn.ConnectionString = cs.ConnectionString
        Return cn
    End Function

    Private Shared Function GetBaseUrl(ByVal page As Page, ByVal canonicalUrl As String) As String
        Dim baseUrl As String = ""
        If Not String.IsNullOrEmpty(canonicalUrl) Then
            baseUrl = canonicalUrl
        ElseIf page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then
            baseUrl = page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/")
        End If
        If Not baseUrl.EndsWith("/") Then baseUrl &= "/"
        Return baseUrl
    End Function

    Private Shared Function MakeAbsoluteUrl(ByVal baseUrl As String, ByVal url As String) As String
        If String.IsNullOrEmpty(url) Then Return ""
        If url.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then Return url
        Return baseUrl.TrimEnd("/"c) & "/" & url.TrimStart("/"c)
    End Function

    Private Shared Function SafeSessionString(ByVal page As Page, ByVal key As String, ByVal fallback As String) As String
        Try
            If page IsNot Nothing AndAlso page.Session IsNot Nothing Then
                Dim o As Object = page.Session(key)
                If o IsNot Nothing Then
                    Dim s As String = o.ToString().Trim()
                    If s.Length > 0 Then Return s
                End If
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Shared Function SafeSessionInt(ByVal page As Page, ByVal key As String, ByVal fallback As Integer) As Integer
        Try
            If page IsNot Nothing AndAlso page.Session IsNot Nothing Then
                Dim o As Object = page.Session(key)
                If o IsNot Nothing Then
                    Dim n As Integer = fallback
                    If Integer.TryParse(o.ToString(), n) Then
                        Return n
                    End If
                End If
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Shared Function SafeDbString(ByVal dr As DbDataReader, ByVal ordinal As Integer, ByVal fallback As String) As String
        Try
            If dr IsNot Nothing AndAlso Not dr.IsDBNull(ordinal) Then
                Dim s As String = Convert.ToString(dr.GetValue(ordinal))
                If s IsNot Nothing Then
                    s = s.Trim()
                    If s.Length > 0 Then Return s
                End If
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Shared Function SafeDbInt(ByVal dr As DbDataReader, ByVal ordinal As Integer, ByVal fallback As Integer) As Integer
        Try
            If dr IsNot Nothing AndAlso Not dr.IsDBNull(ordinal) Then
                Dim v As Object = dr.GetValue(ordinal)
                Dim n As Integer = fallback
                If Integer.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), n) Then
                    Return n
                End If
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Shared Function SafeDbDecimal(ByVal dr As DbDataReader, ByVal ordinal As Integer, ByVal fallback As Decimal) As Decimal
        Try
            If dr IsNot Nothing AndAlso Not dr.IsDBNull(ordinal) Then
                Dim v As Object = dr.GetValue(ordinal)
                Dim d As Decimal = fallback
                If Decimal.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
                    Return d
                End If
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Shared Sub AddOrReplaceMetaName(ByVal page As Page, ByVal name As String, ByVal content As String)
        AddOrReplaceMeta(page, "name", name, content)
    End Sub

    Private Shared Sub AddOrReplaceMetaProperty(ByVal page As Page, ByVal [property] As String, ByVal content As String)
        AddOrReplaceMeta(page, "property", [property], content)
    End Sub

    Private Shared Sub AddOrReplaceMeta(ByVal page As Page, ByVal attrKey As String, ByVal attrValue As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return

        ' Remove existing
        For i As Integer = page.Header.Controls.Count - 1 To 0 Step -1
            Dim hm As HtmlMeta = TryCast(page.Header.Controls(i), HtmlMeta)
            If hm IsNot Nothing Then
                Dim v As String = ""
                If String.Equals(attrKey, "name", StringComparison.OrdinalIgnoreCase) Then
                    v = hm.Name
                Else
                    If hm.Attributes IsNot Nothing AndAlso hm.Attributes(attrKey) IsNot Nothing Then
                        v = hm.Attributes(attrKey)
                    End If
                End If

                If Not String.IsNullOrEmpty(v) AndAlso String.Equals(v, attrValue, StringComparison.OrdinalIgnoreCase) Then
                    page.Header.Controls.RemoveAt(i)
                End If
            End If
        Next

        Dim m As New HtmlMeta()
        If String.Equals(attrKey, "name", StringComparison.OrdinalIgnoreCase) Then
            m.Name = attrValue
        Else
            m.Attributes(attrKey) = attrValue
        End If
        m.Content = If(content, "")
        page.Header.Controls.Add(m)
    End Sub

    ' ------------------------------
    ' JSON helpers
    ' ------------------------------
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim s As String = value

        ' Normalize whitespace
        s = s.Replace(vbCrLf, "\n").Replace(vbCr, "\n").Replace(vbLf, "\n")
        s = s.Replace(vbTab, "\t")

        ' Escape
        s = s.Replace("\", "\\")
        s = s.Replace(ChrW(34), "\" & ChrW(34))
        Return s
    End Function

    ' ------------------------------
    ' Default FAQ (Home)
    ' ------------------------------
    Private Shared Function GetDefaultHomeFaq() As List(Of SeoFaq)
        Dim list As New List(Of SeoFaq)()

        list.Add(New SeoFaq("Quali sono i tempi di spedizione?", "Normalmente la spedizione avviene entro 24/48 ore lavorative, salvo disponibilità del prodotto e periodi di picco."))
        list.Add(New SeoFaq("Quali metodi di pagamento accettate?", "Accettiamo i principali metodi di pagamento disponibili sul sito, inclusi carte e soluzioni di pagamento online integrate."))
        list.Add(New SeoFaq("È possibile richiedere assistenza tecnica?", "Sì. Offriamo assistenza tecnica e supporto pre e post vendita. Contattaci tramite i canali indicati sul sito."))

        Return list
    End Function

End Class

' ------------------------------
' DTOs
' ------------------------------
Public Class SeoCompany
    Public Property RagioneSociale As String
    Public Property Indirizzo As String
    Public Property Cap As String
    Public Property Citta As String
    Public Property Provincia As String
    Public Property IdPaese As String
    Public Property Telephone As String
    Public Property Email As String

    Public ReadOnly Property HasAddress As Boolean
        Get
            Return (Not String.IsNullOrEmpty(Indirizzo) OrElse Not String.IsNullOrEmpty(Citta) OrElse Not String.IsNullOrEmpty(Cap))
        End Get
    End Property
End Class

Public Class SeoCategory
    Public Property Id As Integer
    Public Property Name As String
End Class

Public Class SeoProduct
    Public Property Id As Integer
    Public Property Name As String
    Public Property Price As Decimal
    Public Property ImageUrl As String
    Public Property AvailabilitySchemaUrl As String
End Class

Public Class SeoFaq
    Public Sub New(ByVal q As String, ByVal a As String)
        Question = q
        Answer = a
    End Sub

    Public Property Question As String
    Public Property Answer As String
End Class
