Option Strict On
Option Explicit On

Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Data
Imports MySql.Data.MySqlClient

Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ============================================================
    ' Public DTOs (riusabili per binding e JSON-LD)
    ' ============================================================
    Public Class CompanyData
        Public Property Name As String
        Public Property LegalName As String
        Public Property Address As String
        Public Property City As String
        Public Property Province As String
        Public Property PostalCode As String
        Public Property CountryCode As String
        Public Property Telephone As String
        Public Property Email As String
    End Class

    Public Class SeoCategory
        Public Property Id As Integer
        Public Property Name As String
        Public Property Url As String
    End Class

    Public Class SeoProduct
        Public Property Id As Integer
        Public Property Sku As String
        Public Property Name As String
        Public Property Url As String
        Public Property ImageUrl As String
        Public Property Price As Decimal
        Public Property SalePrice As Decimal
        Public Property HasSalePrice As Boolean
        Public Property Currency As String
        Public Property AvailabilityUrl As String
    End Class

    Public Class SeoFaq
        Public Property Question As String
        Public Property Answer As String
    End Class

    ' ============================================================
    ' Meta helpers
    ' ============================================================
    Public Shared Sub SetTitle(page As Page, titleText As String)
        If page Is Nothing Then Return
        If Not String.IsNullOrEmpty(titleText) Then
            page.Title = titleText
        End If
    End Sub

    Public Shared Sub SetMetaDescription(page As Page, description As String)
        If page Is Nothing Then Return
        AddOrReplaceMeta(page, "description", If(description, ""))
    End Sub

    Public Shared Sub SetCanonical(page As Page, canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(canonicalUrl) Then Return

        Dim existing As HtmlLink = Nothing

        For Each ctrl As Control In page.Header.Controls
            Dim lnk As HtmlLink = TryCast(ctrl, HtmlLink)
            If lnk IsNot Nothing Then
                Dim rel As String = Nothing
                If lnk.Attributes IsNot Nothing Then rel = lnk.Attributes("rel")
                If rel IsNot Nothing AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    existing = lnk
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlLink()
            existing.Attributes("rel") = "canonical"
            page.Header.Controls.Add(existing)
        End If

        existing.Href = canonicalUrl
    End Sub

    Public Shared Sub SetMetaTag(page As Page, metaName As String, metaContent As String)
        AddOrReplaceMeta(page, metaName, If(metaContent, ""))
    End Sub

    Private Shared Sub AddOrReplaceMeta(page As Page, name As String, content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(name) Then Return

        Dim existing As HtmlMeta = Nothing

        For Each ctrl As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(ctrl, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                existing = m
                Exit For
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Name = name
            page.Header.Controls.Add(existing)
        End If

        existing.Content = If(content, "")
    End Sub

    Private Shared Sub AddOrReplaceMetaProperty(page As Page, propName As String, content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Return
        If String.IsNullOrEmpty(propName) Then Return

        Dim existing As HtmlMeta = Nothing

        For Each ctrl As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(ctrl, HtmlMeta)
            If m IsNot Nothing Then
                Dim p As String = Nothing
                If m.Attributes IsNot Nothing Then p = m.Attributes("property")
                If p IsNot Nothing AndAlso String.Equals(p, propName, StringComparison.OrdinalIgnoreCase) Then
                    existing = m
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Attributes("property") = propName
            page.Header.Controls.Add(existing)
        End If

        existing.Content = If(content, "")
    End Sub

    Public Shared Sub ApplyOpenGraph(page As Page, titleText As String, description As String, pageUrl As String, imageUrl As String)
        If page Is Nothing Then Return

        AddOrReplaceMetaProperty(page, "og:type", "website")
        AddOrReplaceMetaProperty(page, "og:locale", "it_IT")
        AddOrReplaceMetaProperty(page, "og:site_name", GetSiteName(page))
        AddOrReplaceMetaProperty(page, "og:title", If(titleText, ""))
        AddOrReplaceMetaProperty(page, "og:description", If(description, ""))
        AddOrReplaceMetaProperty(page, "og:url", If(pageUrl, ""))

        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMetaProperty(page, "og:image", imageUrl)
        End If

        AddOrReplaceMeta(page, "twitter:card", If(String.IsNullOrEmpty(imageUrl), "summary", "summary_large_image"))
        AddOrReplaceMeta(page, "twitter:title", If(titleText, ""))
        AddOrReplaceMeta(page, "twitter:description", If(description, ""))

        If Not String.IsNullOrEmpty(imageUrl) Then
            AddOrReplaceMeta(page, "twitter:image", imageUrl)
        End If
    End Sub

    ' ============================================================
    ' FAQ (single source of truth: HTML + JSON-LD)
    ' ============================================================
    Public Shared Function GetHomeFaq() As List(Of SeoFaq)
        Dim list As New List(Of SeoFaq)()

        list.Add(New SeoFaq With {
            .Question = "Come posso trovare velocemente un prodotto?",
            .Answer = "Usa la barra di ricerca in alto e inserisci marca, modello o parola chiave. Puoi anche navigare per categoria."
        })

        list.Add(New SeoFaq With {
            .Question = "Come posso contattare l'assistenza?",
            .Answer = "Puoi utilizzare la pagina Contatti oppure i riferimenti presenti nel footer del sito."
        })

        list.Add(New SeoFaq With {
            .Question = "Quali metodi di pagamento sono disponibili?",
            .Answer = "I metodi di pagamento disponibili vengono mostrati durante il checkout, prima della conferma dell'ordine."
        })

        list.Add(New SeoFaq With {
            .Question = "Posso richiedere fattura?",
            .Answer = "Durante l'ordine puoi inserire i dati di fatturazione. Per richieste specifiche contatta il supporto prima di completare l'acquisto."
        })

        list.Add(New SeoFaq With {
            .Question = "Spedizione e consegna: dove trovo le informazioni?",
            .Answer = "Costi e tempi di spedizione sono indicati nel checkout e nelle pagine informative. Se hai dubbi, contattaci."
        })

        Return list
    End Function

    ' ============================================================
    ' JSON-LD Home (advanced graph)
    ' - Organization + LocalBusiness + WebSite + WebPage
    ' - BreadcrumbList
    ' - ItemList (Categorie) + Product + Offer (prodotti VISIBILI in Home)
    ' - FAQPage (coerente con la sezione HTML)
    ' ============================================================
    Public Shared Function BuildHomeJsonLd(page As Page, titleText As String, description As String, canonicalUrl As String, logoUrl As String) As String
        If page Is Nothing Then Return String.Empty

        Dim baseUrl As String = GetBaseUrl(page)
        If String.IsNullOrEmpty(baseUrl) Then baseUrl = canonicalUrl
        If Not String.IsNullOrEmpty(baseUrl) AndAlso Not baseUrl.EndsWith("/") Then baseUrl &= "/"

        Dim canonical As String = canonicalUrl
        If String.IsNullOrEmpty(canonical) Then canonical = baseUrl

        Dim absLogo As String = ToAbsoluteUrl(page, baseUrl, logoUrl)

        Dim company As CompanyData = GetCompanyData(page)

        ' Categorie: DB (leggere e leggere cache)
        Dim categories As List(Of SeoCategory) = GetHomeCategories(baseUrl, 12)

        ' Prodotti: preferire i prodotti effettivamente mostrati in Home (SqlDataSource già presenti)
        Dim products As List(Of SeoProduct) = GetHomeProductsFromHomeDataSources(page, baseUrl, 12)
        If products.Count = 0 Then
            ' fallback (se per qualunque motivo i DS non sono disponibili)
            products = GetHomeProductsFromDb(page, baseUrl, 12)
        End If

        Dim faqs As List(Of SeoFaq) = GetHomeFaq()

        Return BuildHomeJsonLdGraph(baseUrl, canonical, titleText, description, absLogo, company, categories, products, faqs)
    End Function

    Private Shared Function BuildHomeJsonLdGraph(baseUrl As String,
                                                canonical As String,
                                                titleText As String,
                                                description As String,
                                                absLogo As String,
                                                company As CompanyData,
                                                categories As List(Of SeoCategory),
                                                products As List(Of SeoProduct),
                                                faqs As List(Of SeoFaq)) As String

        Const Q As String = """"

        Dim orgId As String = baseUrl & "#org"
        Dim localId As String = baseUrl & "#localbusiness"
        Dim websiteId As String = baseUrl & "#website"
        Dim logoId As String = baseUrl & "#logo"

        Dim webpageId As String = canonical & "#webpage"
        Dim breadcrumbId As String = canonical & "#breadcrumb"
        Dim categoriesId As String = canonical & "#categories"
        Dim productsId As String = canonical & "#products"
        Dim faqId As String = canonical & "#faq"

        Dim orgName As String = If(company IsNot Nothing AndAlso Not String.IsNullOrEmpty(company.Name), company.Name, GetSiteNameFromBase(baseUrl))
        Dim orgEmail As String = If(company IsNot Nothing, company.Email, String.Empty)
        Dim orgPhone As String = If(company IsNot Nothing, company.Telephone, String.Empty)

        Dim sellerId As String = If(company IsNot Nothing AndAlso (Not String.IsNullOrEmpty(company.Email) OrElse Not String.IsNullOrEmpty(company.Telephone)), localId, orgId)

        Dim sb As New StringBuilder(8192)
        sb.Append("<script type=""application/ld+json"">")
        sb.Append("{")
        sb.Append(Q).Append("@context").Append(Q).Append(":").Append(Q).Append("https://schema.org").Append(Q).Append(",")
        sb.Append(Q).Append("@graph").Append(Q).Append(":[")

        Dim firstGraph As Boolean = True

        ' ------------------------------------------------------------
        ' Logo (ImageObject)
        ' ------------------------------------------------------------
        If Not String.IsNullOrEmpty(absLogo) Then
            AppendGraphSep(sb, firstGraph)
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ImageObject").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append(",")
            sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(absLogo)).Append(Q).Append(",")
            sb.Append(Q).Append("contentUrl").Append(Q).Append(":").Append(Q).Append(JsonEscape(absLogo)).Append(Q)
            sb.Append("}")
        End If

        ' ------------------------------------------------------------
        ' Organization
        ' ------------------------------------------------------------
        AppendGraphSep(sb, firstGraph)
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Organization").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgName)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q)

        If Not String.IsNullOrEmpty(absLogo) Then
            sb.Append(",").Append(Q).Append("logo").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
        End If
        If Not String.IsNullOrEmpty(orgEmail) Then
            sb.Append(",").Append(Q).Append("email").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgEmail)).Append(Q)
        End If
        If Not String.IsNullOrEmpty(orgPhone) Then
            sb.Append(",").Append(Q).Append("telephone").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgPhone)).Append(Q)
        End If

        Dim fb As String = SafeSessionString("facebookLink")
        If Not String.IsNullOrEmpty(fb) Then
            sb.Append(",").Append(Q).Append("sameAs").Append(Q).Append(":[").Append(Q).Append(JsonEscape(fb)).Append(Q).Append("]")
        End If

        sb.Append("}")

        ' ------------------------------------------------------------
        ' LocalBusiness
        ' ------------------------------------------------------------
        If company IsNot Nothing AndAlso (Not String.IsNullOrEmpty(company.Address) OrElse Not String.IsNullOrEmpty(company.Telephone) OrElse Not String.IsNullOrEmpty(company.Email)) Then
            AppendGraphSep(sb, firstGraph)
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("LocalBusiness").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(localId)).Append(Q).Append(",")
            sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgName)).Append(Q).Append(",")
            sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q).Append(",")
            sb.Append(Q).Append("parentOrganization").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("}")

            If Not String.IsNullOrEmpty(absLogo) Then
                sb.Append(",").Append(Q).Append("image").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
                sb.Append(",").Append(Q).Append("logo").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
            End If
            If Not String.IsNullOrEmpty(company.Telephone) Then
                sb.Append(",").Append(Q).Append("telephone").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Telephone)).Append(Q)
            End If
            If Not String.IsNullOrEmpty(company.Email) Then
                sb.Append(",").Append(Q).Append("email").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Email)).Append(Q)
            End If

            Dim hasAddress As Boolean = Not String.IsNullOrEmpty(company.Address) OrElse Not String.IsNullOrEmpty(company.City) OrElse Not String.IsNullOrEmpty(company.PostalCode)
            If hasAddress Then
                sb.Append(",").Append(Q).Append("address").Append(Q).Append(":{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("PostalAddress").Append(Q)

                If Not String.IsNullOrEmpty(company.Address) Then
                    sb.Append(",").Append(Q).Append("streetAddress").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Address)).Append(Q)
                End If
                If Not String.IsNullOrEmpty(company.City) Then
                    sb.Append(",").Append(Q).Append("addressLocality").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.City)).Append(Q)
                End If
                If Not String.IsNullOrEmpty(company.Province) Then
                    sb.Append(",").Append(Q).Append("addressRegion").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Province)).Append(Q)
                End If
                If Not String.IsNullOrEmpty(company.PostalCode) Then
                    sb.Append(",").Append(Q).Append("postalCode").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.PostalCode)).Append(Q)
                End If

                Dim cc As String = company.CountryCode
                If String.IsNullOrEmpty(cc) Then cc = "IT"
                sb.Append(",").Append(Q).Append("addressCountry").Append(Q).Append(":").Append(Q).Append(JsonEscape(cc)).Append(Q)

                sb.Append("}")
            End If

            sb.Append("}")
        End If

        ' ------------------------------------------------------------
        ' WebSite + SearchAction
        ' ------------------------------------------------------------
        AppendGraphSep(sb, firstGraph)
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebSite").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgName)).Append(Q).Append(",")
        sb.Append(Q).Append("publisher").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("},")
        sb.Append(Q).Append("potentialAction").Append(Q).Append(":{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("SearchAction").Append(Q).Append(",")
        sb.Append(Q).Append("target").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl & "articoli.aspx?q={search_term_string}")).Append(Q).Append(",")
        sb.Append(Q).Append("query-input").Append(Q).Append(":").Append(Q).Append("required name=search_term_string").Append(Q)
        sb.Append("}")
        sb.Append("}")

        ' ------------------------------------------------------------
        ' WebPage
        ' ------------------------------------------------------------
        AppendGraphSep(sb, firstGraph)
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebPage").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(webpageId)).Append(Q).Append(",")
        sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(canonical)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(If(titleText, ""))).Append(Q).Append(",")
        sb.Append(Q).Append("description").Append(Q).Append(":").Append(Q).Append(JsonEscape(If(description, ""))).Append(Q).Append(",")
        sb.Append(Q).Append("isPartOf").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append("},")
        sb.Append(Q).Append("breadcrumb").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(breadcrumbId)).Append(Q).Append("}")

        If Not String.IsNullOrEmpty(absLogo) Then
            sb.Append(",").Append(Q).Append("primaryImageOfPage").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
        End If

        sb.Append("}")

        ' ------------------------------------------------------------
        ' BreadcrumbList
        ' ------------------------------------------------------------
        AppendGraphSep(sb, firstGraph)
        sb.Append("{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("BreadcrumbList").Append(Q).Append(",")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(breadcrumbId)).Append(Q).Append(",")
        sb.Append(Q).Append("itemListElement").Append(Q).Append(":[{")
        sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
        sb.Append(Q).Append("position").Append(Q).Append(":1,")
        sb.Append(Q).Append("item").Append(Q).Append(":{")
        sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(canonical)).Append(Q).Append(",")
        sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape("Home")).Append(Q)
        sb.Append("}}]")
        sb.Append("}")

        ' ------------------------------------------------------------
        ' Categories ItemList
        ' ------------------------------------------------------------
        If categories IsNot Nothing AndAlso categories.Count > 0 Then
            AppendGraphSep(sb, firstGraph)
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ItemList").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(categoriesId)).Append(Q).Append(",")
            sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape("Categorie")).Append(Q).Append(",")
            sb.Append(Q).Append("itemListElement").Append(Q).Append(":[")

            Dim cpos As Integer = 0
            For Each c As SeoCategory In categories
                If c Is Nothing OrElse String.IsNullOrEmpty(c.Url) OrElse String.IsNullOrEmpty(c.Name) Then Continue For
                cpos += 1
                If cpos > 1 Then sb.Append(",")
                sb.Append("{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
                sb.Append(Q).Append("position").Append(Q).Append(":").Append(cpos).Append(",")
                sb.Append(Q).Append("item").Append(Q).Append(":{")
                sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(c.Url)).Append(Q).Append(",")
                sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(c.Name)).Append(Q)
                sb.Append("}}")
            Next

            sb.Append("]")
            sb.Append("}")
        End If

        ' ------------------------------------------------------------
        ' Product entities + ItemList
        ' ------------------------------------------------------------
        If products IsNot Nothing AndAlso products.Count > 0 Then

            For Each p As SeoProduct In products
                If p Is Nothing OrElse String.IsNullOrEmpty(p.Url) OrElse String.IsNullOrEmpty(p.Name) Then Continue For

                AppendGraphSep(sb, firstGraph)
                sb.Append("{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Product").Append(Q).Append(",")
                sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Url)).Append(Q).Append(",")
                sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Name)).Append(Q)

                If Not String.IsNullOrEmpty(p.Sku) Then
                    sb.Append(",").Append(Q).Append("sku").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Sku)).Append(Q)
                End If

                If Not String.IsNullOrEmpty(p.ImageUrl) Then
                    sb.Append(",").Append(Q).Append("image").Append(Q).Append(":[").Append(Q).Append(JsonEscape(p.ImageUrl)).Append(Q).Append("]")
                End If

                Dim cur As String = If(String.IsNullOrEmpty(p.Currency), "EUR", p.Currency)
                Dim priceToUse As Decimal = If(p.HasSalePrice AndAlso p.SalePrice > 0D, p.SalePrice, p.Price)
                Dim availability As String = If(String.IsNullOrEmpty(p.AvailabilityUrl), "https://schema.org/InStock", p.AvailabilityUrl)

                sb.Append(",").Append(Q).Append("offers").Append(Q).Append(":{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Offer").Append(Q).Append(",")
                sb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Url)).Append(Q).Append(",")
                sb.Append(Q).Append("priceCurrency").Append(Q).Append(":").Append(Q).Append(JsonEscape(cur)).Append(Q).Append(",")
                sb.Append(Q).Append("price").Append(Q).Append(":").Append(Q).Append(priceToUse.ToString("0.00", CultureInfo.InvariantCulture)).Append(Q).Append(",")
                sb.Append(Q).Append("availability").Append(Q).Append(":").Append(Q).Append(JsonEscape(availability)).Append(Q).Append(",")
                sb.Append(Q).Append("itemCondition").Append(Q).Append(":").Append(Q).Append("https://schema.org/NewCondition").Append(Q).Append(",")
                sb.Append(Q).Append("seller").Append(Q).Append(":").Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(sellerId)).Append(Q).Append("}")
                sb.Append("}")

                sb.Append("}")
            Next

            AppendGraphSep(sb, firstGraph)
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ItemList").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(productsId)).Append(Q).Append(",")
            sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape("Prodotti in evidenza")).Append(Q).Append(",")
            sb.Append(Q).Append("itemListElement").Append(Q).Append(":[")

            Dim ppos As Integer = 0
            For Each p As SeoProduct In products
                If p Is Nothing OrElse String.IsNullOrEmpty(p.Url) OrElse String.IsNullOrEmpty(p.Name) Then Continue For
                ppos += 1
                If ppos > 1 Then sb.Append(",")
                sb.Append("{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
                sb.Append(Q).Append("position").Append(Q).Append(":").Append(ppos).Append(",")
                sb.Append(Q).Append("item").Append(Q).Append(":{")
                sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Url)).Append(Q).Append(",")
                sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(p.Name)).Append(Q)
                sb.Append("}}")
            Next

            sb.Append("]")
            sb.Append("}")
        End If

        ' ------------------------------------------------------------
        ' FAQPage
        ' ------------------------------------------------------------
        If faqs IsNot Nothing AndAlso faqs.Count > 0 Then
            AppendGraphSep(sb, firstGraph)
            sb.Append("{")
            sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("FAQPage").Append(Q).Append(",")
            sb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(faqId)).Append(Q).Append(",")
            sb.Append(Q).Append("mainEntity").Append(Q).Append(":[")

            Dim qpos As Integer = 0
            For Each f As SeoFaq In faqs
                If f Is Nothing OrElse String.IsNullOrEmpty(f.Question) OrElse String.IsNullOrEmpty(f.Answer) Then Continue For
                qpos += 1
                If qpos > 1 Then sb.Append(",")
                sb.Append("{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Question").Append(Q).Append(",")
                sb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(f.Question)).Append(Q).Append(",")
                sb.Append(Q).Append("acceptedAnswer").Append(Q).Append(":{")
                sb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Answer").Append(Q).Append(",")
                sb.Append(Q).Append("text").Append(Q).Append(":").Append(Q).Append(JsonEscape(f.Answer)).Append(Q)
                sb.Append("}}")
            Next

            sb.Append("]")
            sb.Append("}")
        End If

        sb.Append("]}")
        sb.Append("</script>")

        Return sb.ToString()
    End Function

    Private Shared Sub AppendGraphSep(sb As StringBuilder, ByRef firstGraph As Boolean)
        If Not firstGraph Then sb.Append(",")
        firstGraph = False
    End Sub

    ' ============================================================
    ' JSON-LD injection (Master or fallback literal)
    ' ============================================================
    Public Shared Sub SetJsonLdOnMaster(page As Page, jsonLdScript As String)
        If page Is Nothing Then Return

        Dim masterSeo As ISeoMaster = TryCast(page.Master, ISeoMaster)
        If masterSeo IsNot Nothing Then
            masterSeo.SeoJsonLd = jsonLdScript
            Return
        End If

        Dim mp As MasterPage = page.Master
        If mp IsNot Nothing Then
            Dim litCtrl As Control = mp.FindControl("litSeoJsonLd")
            Dim lit As Literal = TryCast(litCtrl, Literal)
            If lit IsNot Nothing Then
                lit.Text = jsonLdScript
            End If
        End If
    End Sub

    ' ============================================================
    ' Data retrieval helpers
    ' ============================================================
    Private Shared Function GetCompanyData(page As Page) As CompanyData
        Dim host As String = ""
        If page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then host = page.Request.Url.Host

        Dim aziendaId As Integer = 0
        Try
            Dim idObj As Object = Nothing
            If page IsNot Nothing AndAlso page.Session IsNot Nothing Then idObj = page.Session("AziendaID")
            If idObj IsNot Nothing Then Integer.TryParse(idObj.ToString(), aziendaId)
        Catch
        End Try

        Dim cacheKey As String = If(aziendaId > 0, "SEO_COMPANY_" & aziendaId.ToString(), "SEO_COMPANY_HOST_" & host)
        Dim cached As CompanyData = TryCast(HttpRuntime.Cache(cacheKey), CompanyData)
        If cached IsNot Nothing Then Return cached

        Dim result As New CompanyData()
        result.CountryCode = "IT"

        Try
            Dim cs As String = ""
            If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
                cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            End If
            If String.IsNullOrEmpty(cs) Then
                ' Fallback solo da session/appsettings
                result.Name = SafeSessionString("AziendaNome")
                result.Email = SafeSessionString("AziendaEmail")
                result.Telephone = GetCompanyPhone(page)
                HttpRuntime.Cache.Insert(cacheKey, result, Nothing, DateTime.UtcNow.AddHours(6), System.Web.Caching.Cache.NoSlidingExpiration)
                Return result
            End If

            Using conn As New MySqlConnection(cs)
                conn.Open()

                If aziendaId > 0 Then
                    Using cmd As New MySqlCommand("SELECT Nome, RagioneSociale, Indirizzo, Citta, Provincia, Cap, Telefono, Email, IdPaese FROM aziende WHERE Id=@id LIMIT 1", conn)
                        cmd.Parameters.AddWithValue("@id", aziendaId)
                        Using r As MySqlDataReader = cmd.ExecuteReader()
                            If r.Read() Then
                                result.Name = SafeDbString(r, "Nome")
                                result.LegalName = SafeDbString(r, "RagioneSociale")
                                If String.IsNullOrEmpty(result.Name) Then result.Name = result.LegalName
                                result.Address = SafeDbString(r, "Indirizzo")
                                result.City = SafeDbString(r, "Citta")
                                result.Province = SafeDbString(r, "Provincia")
                                result.PostalCode = SafeDbString(r, "Cap")
                                result.Telephone = SafeDbString(r, "Telefono")
                                result.Email = SafeDbString(r, "Email")
                                Dim idPaeseStr As String = SafeDbString(r, "IdPaese")
                                If Not String.IsNullOrEmpty(idPaeseStr) AndAlso idPaeseStr.Length = 2 Then
                                    result.CountryCode = idPaeseStr.ToUpperInvariant()
                                End If
                            End If
                        End Using
                    End Using
                ElseIf Not String.IsNullOrEmpty(host) Then
                    Using cmd As New MySqlCommand("SELECT a.Nome, a.RagioneSociale, a.Indirizzo, a.Citta, a.Provincia, a.Cap, a.Telefono, a.Email, a.IdPaese FROM aziende a LEFT JOIN pagine p ON a.Id=p.IdAziende WHERE p.Url1 LIKE @h OR p.Url2 LIKE @h OR p.Url3 LIKE @h OR p.Url4 LIKE @h LIMIT 1", conn)
                        cmd.Parameters.AddWithValue("@h", "%" & host & "%")
                        Using r As MySqlDataReader = cmd.ExecuteReader()
                            If r.Read() Then
                                result.Name = SafeDbString(r, "Nome")
                                result.LegalName = SafeDbString(r, "RagioneSociale")
                                If String.IsNullOrEmpty(result.Name) Then result.Name = result.LegalName
                                result.Address = SafeDbString(r, "Indirizzo")
                                result.City = SafeDbString(r, "Citta")
                                result.Province = SafeDbString(r, "Provincia")
                                result.PostalCode = SafeDbString(r, "Cap")
                                result.Telephone = SafeDbString(r, "Telefono")
                                result.Email = SafeDbString(r, "Email")
                                Dim idPaeseStr As String = SafeDbString(r, "IdPaese")
                                If Not String.IsNullOrEmpty(idPaeseStr) AndAlso idPaeseStr.Length = 2 Then
                                    result.CountryCode = idPaeseStr.ToUpperInvariant()
                                End If
                            End If
                        End Using
                    End Using
                End If
            End Using

        Catch
            ' Non interrompere il rendering della pagina per SEO
        End Try

        If String.IsNullOrEmpty(result.Name) Then result.Name = SafeSessionString("AziendaNome")
        If String.IsNullOrEmpty(result.Email) Then result.Email = GetCompanyEmail(page)
        If String.IsNullOrEmpty(result.Telephone) Then result.Telephone = GetCompanyPhone(page)

        HttpRuntime.Cache.Insert(cacheKey, result, Nothing, DateTime.UtcNow.AddHours(6), System.Web.Caching.Cache.NoSlidingExpiration)
        Return result
    End Function

    Private Shared Function GetHomeCategories(baseUrl As String, limit As Integer) As List(Of SeoCategory)
        Dim host As String = ""
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx IsNot Nothing AndAlso ctx.Request IsNot Nothing AndAlso ctx.Request.Url IsNot Nothing Then host = ctx.Request.Url.Host
        Catch
        End Try

        Dim lim As Integer = limit
        If lim <= 0 Then lim = 12
        If lim > 50 Then lim = 50

        Dim cacheKey As String = "SEO_HOME_CATEGORIES_" & host & "_" & lim.ToString()
        Dim cached As List(Of SeoCategory) = TryCast(HttpRuntime.Cache(cacheKey), List(Of SeoCategory))
        If cached IsNot Nothing Then Return cached

        Dim list As New List(Of SeoCategory)()

        Try
            Dim cs As String = ""
            If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
                cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            End If
            If String.IsNullOrEmpty(cs) Then Return list

            Using conn As New MySqlConnection(cs)
                conn.Open()
                Dim sql As String = "SELECT id, descrizione FROM categorie ORDER BY ordinamento LIMIT " & lim.ToString()
                Using cmd As New MySqlCommand(sql, conn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            If Not r.IsDBNull(0) Then Integer.TryParse(r.GetValue(0).ToString(), id)
                            Dim name As String = If(r.IsDBNull(1), "", r.GetValue(1).ToString())
                            If id > 0 AndAlso Not String.IsNullOrEmpty(name) Then
                                list.Add(New SeoCategory With {.Id = id, .Name = name, .Url = baseUrl & "articoli.aspx?ct=" & id.ToString()})
                            End If
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try

        HttpRuntime.Cache.Insert(cacheKey, list, Nothing, DateTime.UtcNow.AddHours(6), System.Web.Caching.Cache.NoSlidingExpiration)
        Return list
    End Function

    Private Shared Function GetHomeProductsFromHomeDataSources(page As Page, baseUrl As String, maxItems As Integer) As List(Of SeoProduct)
        Dim result As New List(Of SeoProduct)()
        Dim seen As New HashSet(Of Integer)()

        Dim ids As String() = {"SdsNewArticoli", "sdsPiuAcquistati", "SdsArticoliInVetrina"}
        For Each dsId As String In ids
            If result.Count >= maxItems Then Exit For

            Dim ds As SqlDataSource = TryCast(FindControlRecursive(page, dsId), SqlDataSource)
            If ds Is Nothing Then Continue For

            Dim dv As DataView = Nothing
            Try
                dv = TryCast(ds.Select(DataSourceSelectArguments.Empty), DataView)
            Catch
                dv = Nothing
            End Try

            If dv Is Nothing Then Continue For

            For Each row As DataRowView In dv
                If result.Count >= maxItems Then Exit For

                Try
                    If row Is Nothing OrElse row.Row Is Nothing OrElse row.Row.Table Is Nothing Then Continue For
                    Dim t As DataTable = row.Row.Table

                    If Not t.Columns.Contains("id") Then Continue For
                    If Not t.Columns.Contains("descrizione1") Then Continue For

                    Dim id As Integer = SafeInt(row("id"))
                    If id <= 0 Then Continue For
                    If seen.Contains(id) Then Continue For

                    Dim name As String = SafeStr(row("descrizione1"))
                    If String.IsNullOrEmpty(name) Then Continue For

                    Dim sku As String = If(t.Columns.Contains("codice"), SafeStr(row("codice")), "")
                    Dim img As String = If(t.Columns.Contains("img1"), SafeStr(row("img1")), "")

                    Dim absImg As String = ToAbsoluteUrl(page, baseUrl, img)
                    Dim url As String = baseUrl & "articolo.aspx?id=" & id.ToString()

                    ' prezzo coerente con quanto mostrato a video (promo + iva)
                    Dim ivaUtente As Integer = SafeIntFromSession(page, "Iva_Utente", 1)

                    Dim prezzo As Decimal = If(t.Columns.Contains("prezzo"), SafeDec(row("prezzo")), 0D)
                    Dim prezzoIvato As Decimal = If(t.Columns.Contains("prezzoIvato"), SafeDec(row("prezzoIvato")), 0D)
                    Dim prezzoPromo As Decimal = If(t.Columns.Contains("prezzoPromo"), SafeDec(row("prezzoPromo")), 0D)
                    Dim prezzoPromoIvato As Decimal = If(t.Columns.Contains("prezzoPromoIvato"), SafeDec(row("prezzoPromoIvato")), 0D)

                    Dim regular As Decimal = If(ivaUtente = 0, prezzo, prezzoIvato)
                    Dim promo As Decimal = If(ivaUtente = 0, prezzoPromo, prezzoPromoIvato)

                    Dim hasSale As Boolean = (promo > 0D AndAlso promo < regular)

                    Dim giac As Integer = 0
                    If t.Columns.Contains("giacenza") Then giac = SafeInt(row("giacenza"))
                    Dim availability As String = If(giac > 0, "https://schema.org/InStock", "https://schema.org/OutOfStock")

                    Dim p As New SeoProduct()
                    p.Id = id
                    p.Sku = sku
                    p.Name = name
                    p.Url = url
                    p.ImageUrl = absImg
                    p.Price = regular
                    p.SalePrice = promo
                    p.HasSalePrice = hasSale
                    p.Currency = "EUR"
                    p.AvailabilityUrl = availability

                    result.Add(p)
                    seen.Add(id)

                Catch
                    ' Ignora singola riga non coerente
                End Try

            Next
        Next

        Return result
    End Function

    Private Shared Function GetHomeProductsFromDb(page As Page, baseUrl As String, limit As Integer) As List(Of SeoProduct)
        Dim list As New List(Of SeoProduct)()

        Dim lim As Integer = limit
        If lim <= 0 Then lim = 12
        If lim > 30 Then lim = 30

        Dim host As String = ""
        If page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then host = page.Request.Url.Host

        Dim cacheKey As String = "SEO_HOME_PRODUCTS_DB_" & host & "_" & lim.ToString()
        Dim cached As List(Of SeoProduct) = TryCast(HttpRuntime.Cache(cacheKey), List(Of SeoProduct))
        If cached IsNot Nothing Then Return cached

        Try
            Dim cs As String = ""
            If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
                cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            End If
            If String.IsNullOrEmpty(cs) Then Return list

            Using conn As New MySqlConnection(cs)
                conn.Open()
                Dim sql As String =
                    "SELECT a.id, a.codice, a.descrizione1, a.prezzo, a.prezzoscontato, a.img1, COALESCE(g.giacenza,0) AS giacenza " &
                    "FROM varticoligiacenze a " &
                    "LEFT JOIN articoli_giacenze g ON g.ArticoliId = a.id " &
                    "WHERE a.abilitato=1 " &
                    "ORDER BY a.visite DESC " &
                    "LIMIT " & lim.ToString()

                Using cmd As New MySqlCommand(sql, conn)
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim id As Integer = 0
                            If Not r.IsDBNull(0) Then Integer.TryParse(r.GetValue(0).ToString(), id)
                            If id <= 0 Then Continue While

                            Dim sku As String = If(r.IsDBNull(1), "", r.GetValue(1).ToString())
                            Dim name As String = If(r.IsDBNull(2), "", r.GetValue(2).ToString())
                            If String.IsNullOrEmpty(name) Then Continue While

                            Dim price As Decimal = 0D
                            If Not r.IsDBNull(3) Then price = Convert.ToDecimal(r.GetValue(3), CultureInfo.InvariantCulture)

                            Dim sale As Decimal = 0D
                            Dim hasSale As Boolean = False
                            If Not r.IsDBNull(4) Then
                                sale = Convert.ToDecimal(r.GetValue(4), CultureInfo.InvariantCulture)
                                If sale > 0D AndAlso sale < price Then hasSale = True
                            End If

                            Dim img As String = If(r.IsDBNull(5), "", r.GetValue(5).ToString())
                            Dim absImg As String = ToAbsoluteUrl(page, baseUrl, img)

                            Dim giac As Integer = 0
                            If Not r.IsDBNull(6) Then Integer.TryParse(r.GetValue(6).ToString(), giac)
                            Dim availability As String = If(giac > 0, "https://schema.org/InStock", "https://schema.org/OutOfStock")

                            Dim url As String = baseUrl & "articolo.aspx?id=" & id.ToString()

                            Dim p As New SeoProduct()
                            p.Id = id
                            p.Sku = sku
                            p.Name = name
                            p.Url = url
                            p.ImageUrl = absImg
                            p.Price = price
                            p.SalePrice = sale
                            p.HasSalePrice = hasSale
                            p.Currency = "EUR"
                            p.AvailabilityUrl = availability

                            list.Add(p)
                        End While
                    End Using
                End Using
            End Using
        Catch
        End Try

        HttpRuntime.Cache.Insert(cacheKey, list, Nothing, DateTime.UtcNow.AddMinutes(30), System.Web.Caching.Cache.NoSlidingExpiration)
        Return list
    End Function

    Private Shared Function FindControlRecursive(root As Control, id As String) As Control
        If root Is Nothing OrElse String.IsNullOrEmpty(id) Then Return Nothing
        If String.Equals(root.ID, id, StringComparison.OrdinalIgnoreCase) Then Return root

        For Each child As Control In root.Controls
            Dim found As Control = FindControlRecursive(child, id)
            If found IsNot Nothing Then Return found
        Next
        Return Nothing
    End Function

    Private Shared Function SafeDbString(r As MySqlDataReader, fieldName As String) As String
        Try
            Dim idx As Integer = r.GetOrdinal(fieldName)
            If idx >= 0 AndAlso Not r.IsDBNull(idx) Then
                Return r.GetValue(idx).ToString()
            End If
        Catch
        End Try
        Return ""
    End Function

    Private Shared Function SafeSessionString(key As String) As String
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return ""
            Dim o As Object = ctx.Session(key)
            If o Is Nothing Then Return ""
            Return o.ToString()
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function SafeInt(value As Object) As Integer
        If value Is Nothing Then Return 0
        Dim n As Integer = 0
        Integer.TryParse(value.ToString(), n)
        Return n
    End Function

    Private Shared Function SafeStr(value As Object) As String
        If value Is Nothing Then Return ""
        Return value.ToString()
    End Function

    Private Shared Function SafeDec(value As Object) As Decimal
        If value Is Nothing Then Return 0D

        Try
            If TypeOf value Is Decimal Then Return CType(value, Decimal)
            If TypeOf value Is Double Then Return Convert.ToDecimal(CType(value, Double), CultureInfo.InvariantCulture)
            If TypeOf value Is Single Then Return Convert.ToDecimal(CType(value, Single), CultureInfo.InvariantCulture)
        Catch
        End Try

        Dim d As Decimal = 0D
        Decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, d)
        Return d
    End Function

    Private Shared Function SafeIntFromSession(page As Page, sessionKey As String, defaultValue As Integer) As Integer
        Try
            If page IsNot Nothing AndAlso page.Session IsNot Nothing Then
                Dim o As Object = page.Session(sessionKey)
                If o IsNot Nothing Then
                    Dim n As Integer = 0
                    If Integer.TryParse(o.ToString(), n) Then Return n
                End If
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    ' ============================================================
    ' Low-level helpers
    ' ============================================================
    Private Shared Function GetBaseUrl(page As Page) As String
        If page Is Nothing OrElse page.Request Is Nothing OrElse page.Request.Url Is Nothing Then Return ""
        Return page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/")
    End Function

    Private Shared Function GetSiteName(page As Page) As String
        Dim s As String = ConfigurationManager.AppSettings("SiteName")
        If Not String.IsNullOrEmpty(s) Then Return s

        If page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then
            Return page.Request.Url.Host
        End If

        Return "KeepStore"
    End Function

    Private Shared Function GetSiteNameFromBase(baseUrl As String) As String
        If String.IsNullOrEmpty(baseUrl) Then Return "KeepStore"
        Try
            Dim uri As New Uri(baseUrl)
            Return uri.Host
        Catch
            Return "KeepStore"
        End Try
    End Function

    Private Shared Function GetCompanyEmail(page As Page) As String
        Dim email As String = ConfigurationManager.AppSettings("CompanyEmail")
        If Not String.IsNullOrEmpty(email) Then Return email

        Dim ses As Object = Nothing
        If page IsNot Nothing AndAlso page.Session IsNot Nothing Then ses = page.Session("AziendaEmail")
        If ses IsNot Nothing Then Return ses.ToString()

        Return ""
    End Function

    Private Shared Function GetCompanyPhone(page As Page) As String
        Dim phone As String = ConfigurationManager.AppSettings("CompanyPhone")
        If Not String.IsNullOrEmpty(phone) Then Return phone

        ' In alcuni progetti la chiave non è presente: fallback vuoto
        Return ""
    End Function

    Private Shared Function ToAbsoluteUrl(page As Page, baseUrl As String, urlOrPath As String) As String
        If String.IsNullOrEmpty(urlOrPath) Then Return ""
        Dim u As String = urlOrPath.Trim()

        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return u
        End If

        If u.StartsWith("//") Then
            If page IsNot Nothing AndAlso page.Request IsNot Nothing AndAlso page.Request.Url IsNot Nothing Then
                Return page.Request.Url.Scheme & ":" & u
            End If
            Return "https:" & u
        End If

        If page IsNot Nothing Then
            u = page.ResolveUrl(u)
        End If

        If u.StartsWith("/") Then u = u.Substring(1)
        If Not baseUrl.EndsWith("/") Then baseUrl &= "/"
        Return baseUrl & u
    End Function

    Private Shared Function JsonEscape(s As String) As String
        If s Is Nothing Then Return ""
        Dim sb As New StringBuilder(s.Length + 16)
        Const BS As Char = "\"c

        For Each ch As Char In s
            Select Case ch
                Case """"c
                    sb.Append(BS).Append(""""c)
                Case "\"c
                    sb.Append(BS).Append(BS)
                Case ControlChars.Tab
                    sb.Append(BS).Append("t"c)
                Case ControlChars.Back
                    sb.Append(BS).Append("b"c)
                Case ControlChars.FormFeed
                    sb.Append(BS).Append("f"c)
                Case ControlChars.Cr
                    sb.Append(BS).Append("r"c)
                Case ControlChars.Lf
                    sb.Append(BS).Append("n"c)
                Case Else
                    If AscW(ch) < 32 Then
                        sb.Append(BS).Append("u").Append(AscW(ch).ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

End Class
