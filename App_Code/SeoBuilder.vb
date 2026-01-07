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

    ' ============================================================
' Build HOME JSON-LD (@graph completo)
' ============================================================
Private Shared Function BuildHomeJsonLdGraph(page As Page,
                                            titleText As String,
                                            descriptionText As String,
                                            canonicalUrl As String,
                                            ogImageUrl As String) As String
    Try
        Dim baseUrl As String = GetBaseUrl(page)
        If String.IsNullOrEmpty(baseUrl) Then
            ' Fallback ultra-safe
            If page IsNot Nothing AndAlso page.Request IsNot Nothing Then
                baseUrl = page.Request.Url.GetLeftPart(UriPartial.Authority) & page.ResolveUrl("~/")
            Else
                Return ""
            End If
        End If
        If Not baseUrl.EndsWith("/", StringComparison.Ordinal) Then baseUrl &= "/"

        Dim canonical As String = SafeTrim(canonicalUrl)
        If String.IsNullOrEmpty(canonical) Then canonical = baseUrl

        Dim siteName As String = GetSiteName(page)
        If String.IsNullOrEmpty(siteName) Then siteName = "TAIKUN.IT"

        Dim company As CompanyInfo = GetCompanyFromSession(page)

        ' ID stabili
        Dim orgId As String = baseUrl & "#org"
        Dim logoId As String = baseUrl & "#logo"
        Dim lbId As String = baseUrl & "#localbusiness"
        Dim websiteId As String = baseUrl & "#website"
        Dim webpageId As String = canonical & "#webpage"
        Dim breadcrumbId As String = canonical & "#breadcrumb"
        Dim categoriesId As String = canonical & "#categories"
        Dim productsId As String = canonical & "#products"
        Dim faqId As String = canonical & "#faq"

        Dim companyName As String = SafeTrim(company.Name)
        If String.IsNullOrEmpty(companyName) Then companyName = siteName

        Dim logoUrlAbs As String = SafeTrim(company.LogoUrl)
        If String.IsNullOrEmpty(logoUrlAbs) Then logoUrlAbs = SafeTrim(ogImageUrl)
        logoUrlAbs = ToAbsoluteUrl(baseUrl, logoUrlAbs)

        Dim ogImageAbs As String = ToAbsoluteUrl(baseUrl, ogImageUrl)

        Dim graph As New List(Of String)()

        ' ----------------------------
        ' Organization
        ' ----------------------------
        Dim orgSb As New StringBuilder()
        orgSb.Append("{")
        orgSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Organization").Append(Q).Append(",")
        orgSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append(",")
        orgSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(companyName)).Append(Q).Append(",")
        orgSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q)
        If Not String.IsNullOrEmpty(logoUrlAbs) Then
            orgSb.Append(",").Append(Q).Append("logo").Append(Q).Append(":")
            orgSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
        End If
        If Not String.IsNullOrEmpty(company.VatId) Then
            orgSb.Append(",").Append(Q).Append("vatID").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.VatId)).Append(Q)
        End If
        orgSb.Append("}")
        graph.Add(orgSb.ToString())

        ' ----------------------------
        ' ImageObject (logo)
        ' ----------------------------
        If Not String.IsNullOrEmpty(logoUrlAbs) Then
            Dim logoSb As New StringBuilder()
            logoSb.Append("{")
            logoSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ImageObject").Append(Q).Append(",")
            logoSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append(",")
            logoSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoUrlAbs)).Append(Q).Append(",")
            logoSb.Append(Q).Append("contentUrl").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoUrlAbs)).Append(Q).Append(",")
            logoSb.Append(Q).Append("caption").Append(Q).Append(":").Append(Q).Append(JsonEscape(companyName & " logo")).Append(Q).Append(",")
            logoSb.Append(Q).Append("inLanguage").Append(Q).Append(":").Append(Q).Append("it-IT").Append(Q)
            logoSb.Append("}")
            graph.Add(logoSb.ToString())
        End If

        ' ----------------------------
        ' LocalBusiness
        ' ----------------------------
        Dim hasAddress As Boolean =
            (Not String.IsNullOrEmpty(company.StreetAddress)) OrElse
            (Not String.IsNullOrEmpty(company.PostalCode)) OrElse
            (Not String.IsNullOrEmpty(company.AddressLocality)) OrElse
            (Not String.IsNullOrEmpty(company.AddressRegion)) OrElse
            (Not String.IsNullOrEmpty(company.CountryCode))

        Dim addrJson As String = ""
        If hasAddress Then
            Dim aSb As New StringBuilder()
            aSb.Append("{")
            aSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("PostalAddress").Append(Q)
            If Not String.IsNullOrEmpty(company.StreetAddress) Then
                aSb.Append(",").Append(Q).Append("streetAddress").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.StreetAddress)).Append(Q)
            End If
            If Not String.IsNullOrEmpty(company.PostalCode) Then
                aSb.Append(",").Append(Q).Append("postalCode").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.PostalCode)).Append(Q)
            End If
            If Not String.IsNullOrEmpty(company.AddressLocality) Then
                aSb.Append(",").Append(Q).Append("addressLocality").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.AddressLocality)).Append(Q)
            End If
            If Not String.IsNullOrEmpty(company.AddressRegion) Then
                aSb.Append(",").Append(Q).Append("addressRegion").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.AddressRegion)).Append(Q)
            End If
            If Not String.IsNullOrEmpty(company.CountryCode) Then
                aSb.Append(",").Append(Q).Append("addressCountry").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.CountryCode)).Append(Q)
            End If
            aSb.Append("}")
            addrJson = aSb.ToString()
        End If

        Dim lbSb As New StringBuilder()
        lbSb.Append("{")
        lbSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("LocalBusiness").Append(Q).Append(",")
        lbSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(lbId)).Append(Q).Append(",")
        lbSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(companyName)).Append(Q).Append(",")
        lbSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q)
        If Not String.IsNullOrEmpty(logoUrlAbs) Then
            lbSb.Append(",").Append(Q).Append("image").Append(Q).Append(":")
            lbSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(logoId)).Append(Q).Append("}")
        End If
        If Not String.IsNullOrEmpty(company.Email) Then
            lbSb.Append(",").Append(Q).Append("email").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Email)).Append(Q)
        End If
        If Not String.IsNullOrEmpty(company.Telephone) Then
            lbSb.Append(",").Append(Q).Append("telephone").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.Telephone)).Append(Q)
        End If
        If Not String.IsNullOrEmpty(company.VatId) Then
            lbSb.Append(",").Append(Q).Append("vatID").Append(Q).Append(":").Append(Q).Append(JsonEscape(company.VatId)).Append(Q)
        End If
        If Not String.IsNullOrEmpty(addrJson) Then
            lbSb.Append(",").Append(Q).Append("address").Append(Q).Append(":").Append(addrJson)
        End If
        lbSb.Append(",").Append(Q).Append("parentOrganization").Append(Q).Append(":")
        lbSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("}")
        lbSb.Append("}")
        graph.Add(lbSb.ToString())

        ' ----------------------------
        ' WebSite + SearchAction
        ' ----------------------------
        Dim searchTarget As String = baseUrl & "articoli.aspx?q={search_term_string}"

        Dim wSb As New StringBuilder()
        wSb.Append("{")
        wSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebSite").Append(Q).Append(",")
        wSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append(",")
        wSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(baseUrl)).Append(Q).Append(",")
        wSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(siteName)).Append(Q).Append(",")
        wSb.Append(Q).Append("potentialAction").Append(Q).Append(":").Append("{")
        wSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("SearchAction").Append(Q).Append(",")
        wSb.Append(Q).Append("target").Append(Q).Append(":").Append(Q).Append(JsonEscape(searchTarget)).Append(Q).Append(",")
        wSb.Append(Q).Append("query-input").Append(Q).Append(":").Append(Q).Append("required name=search_term_string").Append(Q)
        wSb.Append("}")
        wSb.Append("}")
        graph.Add(wSb.ToString())

        ' ----------------------------
        ' BreadcrumbList (Home)
        ' ----------------------------
        Dim bSb As New StringBuilder()
        bSb.Append("{")
        bSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("BreadcrumbList").Append(Q).Append(",")
        bSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(breadcrumbId)).Append(Q).Append(",")
        bSb.Append(Q).Append("itemListElement").Append(Q).Append(":[{")
        bSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
        bSb.Append(Q).Append("position").Append(Q).Append(":1,")
        bSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append("Home").Append(Q).Append(",")
        bSb.Append(Q).Append("item").Append(Q).Append(":").Append(Q).Append(JsonEscape(canonical)).Append(Q)
        bSb.Append("}]}")
        graph.Add(bSb.ToString())

        ' ----------------------------
        ' WebPage (Home)
        ' ----------------------------
        Dim pSb As New StringBuilder()
        pSb.Append("{")
        pSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("WebPage").Append(Q).Append(",")
        pSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(webpageId)).Append(Q).Append(",")
        pSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(canonical)).Append(Q).Append(",")
        pSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(SafeTrim(titleText))).Append(Q)
        If Not String.IsNullOrEmpty(descriptionText) Then
            pSb.Append(",").Append(Q).Append("description").Append(Q).Append(":").Append(Q).Append(JsonEscape(SafeTrim(descriptionText))).Append(Q)
        End If
        pSb.Append(",").Append(Q).Append("isPartOf").Append(Q).Append(":")
        pSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(websiteId)).Append(Q).Append("}")
        pSb.Append(",").Append(Q).Append("about").Append(Q).Append(":")
        pSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("}")
        pSb.Append(",").Append(Q).Append("publisher").Append(Q).Append(":")
        pSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(orgId)).Append(Q).Append("}")
        pSb.Append(",").Append(Q).Append("breadcrumb").Append(Q).Append(":")
        pSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(breadcrumbId)).Append(Q).Append("}")
        pSb.Append(",").Append(Q).Append("inLanguage").Append(Q).Append(":").Append(Q).Append("it-IT").Append(Q)
        If Not String.IsNullOrEmpty(ogImageAbs) Then
            pSb.Append(",").Append(Q).Append("primaryImageOfPage").Append(Q).Append(":")
            pSb.Append("{").Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ImageObject").Append(Q).Append(",")
            pSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(ogImageAbs)).Append(Q)
            pSb.Append("}")
        End If
        pSb.Append("}")
        graph.Add(pSb.ToString())

        ' ----------------------------
        ' ItemList categorie (DB)
        ' ----------------------------
        Dim categories As List(Of SeoCategory) = LoadHomeCategories(page, baseUrl, 30)
        If categories IsNot Nothing AndAlso categories.Count > 0 Then
            Dim cSb As New StringBuilder()
            cSb.Append("{")
            cSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ItemList").Append(Q).Append(",")
            cSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(categoriesId)).Append(Q).Append(",")
            cSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape("Categorie")).Append(Q).Append(",")
            cSb.Append(Q).Append("itemListElement").Append(Q).Append(":[")
            For i As Integer = 0 To categories.Count - 1
                If i > 0 Then cSb.Append(",")
                cSb.Append("{")
                cSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
                cSb.Append(Q).Append("position").Append(Q).Append(":").Append((i + 1).ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(",")
                cSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(categories(i).Name)).Append(Q).Append(",")
                cSb.Append(Q).Append("item").Append(Q).Append(":").Append(Q).Append(JsonEscape(categories(i).Url)).Append(Q)
                cSb.Append("}")
            Next
            cSb.Append("]}")
            graph.Add(cSb.ToString())
        End If

        ' ----------------------------
        ' Prodotti HOME (DB) + ItemList + Product/Offer
        ' ----------------------------
        Dim products As List(Of SeoProduct) = LoadHomeProducts(page, baseUrl, 12)
        If products IsNot Nothing AndAlso products.Count > 0 Then
            ' ItemList prodotti
            Dim lSb As New StringBuilder()
            lSb.Append("{")
            lSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ItemList").Append(Q).Append(",")
            lSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(productsId)).Append(Q).Append(",")
            lSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape("Prodotti in evidenza")).Append(Q).Append(",")
            lSb.Append(Q).Append("itemListElement").Append(Q).Append(":[")
            For i As Integer = 0 To products.Count - 1
                If i > 0 Then lSb.Append(",")
                lSb.Append("{")
                lSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("ListItem").Append(Q).Append(",")
                lSb.Append(Q).Append("position").Append(Q).Append(":").Append((i + 1).ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(",")
                lSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(products(i).Name)).Append(Q).Append(",")
                lSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(products(i).Url)).Append(Q).Append(",")
                lSb.Append(Q).Append("item").Append(Q).Append(":")
                lSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(products(i).ProductId)).Append(Q).Append("}")
                lSb.Append("}")
            Next
            lSb.Append("]}")
            graph.Add(lSb.ToString())

            ' Product nodes
            For Each pr As SeoProduct In products
                Dim prSb As New StringBuilder()
                prSb.Append("{")
                prSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Product").Append(Q).Append(",")
                prSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(pr.ProductId)).Append(Q).Append(",")
                prSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(pr.Name)).Append(Q).Append(",")
                prSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(pr.Url)).Append(Q)

                If Not String.IsNullOrEmpty(pr.ImageUrl) Then
                    prSb.Append(",").Append(Q).Append("image").Append(Q).Append(":[").Append(Q).Append(JsonEscape(pr.ImageUrl)).Append(Q).Append("]")
                End If
                If Not String.IsNullOrEmpty(pr.CategoryName) Then
                    prSb.Append(",").Append(Q).Append("category").Append(Q).Append(":").Append(Q).Append(JsonEscape(pr.CategoryName)).Append(Q)
                End If

                ' Brand (minimo ma utile agli assistenti AI)
                prSb.Append(",").Append(Q).Append("brand").Append(Q).Append(":")
                prSb.Append("{").Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Brand").Append(Q).Append(",")
                prSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(siteName)).Append(Q)
                prSb.Append("}")

                ' Offer
                If pr.Price > 0D Then
                    Dim priceStr As String = pr.Price.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
                    Dim availability As String = If(pr.InStock, "https://schema.org/InStock", "https://schema.org/OutOfStock")
                    Dim offerId As String = pr.Url & "#offer"

                    prSb.Append(",").Append(Q).Append("offers").Append(Q).Append(":")
                    prSb.Append("{")
                    prSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Offer").Append(Q).Append(",")
                    prSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(offerId)).Append(Q).Append(",")
                    prSb.Append(Q).Append("url").Append(Q).Append(":").Append(Q).Append(JsonEscape(pr.Url)).Append(Q).Append(",")
                    prSb.Append(Q).Append("priceCurrency").Append(Q).Append(":").Append(Q).Append("EUR").Append(Q).Append(",")
                    prSb.Append(Q).Append("price").Append(Q).Append(":").Append(Q).Append(JsonEscape(priceStr)).Append(Q).Append(",")
                    prSb.Append(Q).Append("availability").Append(Q).Append(":").Append(Q).Append(JsonEscape(availability)).Append(Q).Append(",")
                    prSb.Append(Q).Append("itemCondition").Append(Q).Append(":").Append(Q).Append("https://schema.org/NewCondition").Append(Q).Append(",")
                    prSb.Append(Q).Append("seller").Append(Q).Append(":")
                    prSb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(lbId)).Append(Q).Append("}")
                    prSb.Append("}")
                End If

                prSb.Append("}")
                graph.Add(prSb.ToString())
            Next
        End If

        ' ----------------------------
        ' FAQPage
        ' ----------------------------
        Dim faqs As List(Of FaqItem) = GetHomeFaq()
        If faqs IsNot Nothing AndAlso faqs.Count > 0 Then
            Dim fSb As New StringBuilder()
            fSb.Append("{")
            fSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("FAQPage").Append(Q).Append(",")
            fSb.Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(faqId)).Append(Q).Append(",")
            fSb.Append(Q).Append("mainEntity").Append(Q).Append(":[")
            For i As Integer = 0 To faqs.Count - 1
                If i > 0 Then fSb.Append(",")
                fSb.Append("{")
                fSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Question").Append(Q).Append(",")
                fSb.Append(Q).Append("name").Append(Q).Append(":").Append(Q).Append(JsonEscape(faqs(i).Question)).Append(Q).Append(",")
                fSb.Append(Q).Append("acceptedAnswer").Append(Q).Append(":")
                fSb.Append("{")
                fSb.Append(Q).Append("@type").Append(Q).Append(":").Append(Q).Append("Answer").Append(Q).Append(",")
                fSb.Append(Q).Append("text").Append(Q).Append(":").Append(Q).Append(JsonEscape(faqs(i).Answer)).Append(Q)
                fSb.Append("}")
                fSb.Append("}")
            Next
            fSb.Append("]}")
            graph.Add(fSb.ToString())
        End If

        ' ----------------------------
        ' Root
        ' ----------------------------
        If graph.Count = 0 Then Return ""

        Dim root As New StringBuilder()
        root.Append("{")
        root.Append(Q).Append("@context").Append(Q).Append(":").Append(Q).Append("https://schema.org").Append(Q).Append(",")
        root.Append(Q).Append("@graph").Append(Q).Append(":[")
        root.Append(String.Join(",", graph.ToArray()))
        root.Append("]}")
        Return root.ToString()

    Catch
        ' SEO non deve mai rompere la pagina
        Return ""
    End Try
End Function

' ============================================================
' DB helpers per HOME JSON-LD (categorie + prodotti)
' ============================================================
Private NotInheritable Class SeoCategory
    Public ReadOnly Id As Integer
    Public ReadOnly Name As String
    Public ReadOnly Url As String

    Public Sub New(id As Integer, name As String, url As String)
        Me.Id = id
        Me.Name = name
        Me.Url = url
    End Sub
End Class

Private NotInheritable Class SeoProduct
    Public ReadOnly Id As Integer
    Public ReadOnly Name As String
    Public ReadOnly Url As String
    Public ReadOnly ImageUrl As String
    Public ReadOnly Price As Decimal
    Public ReadOnly InStock As Boolean
    Public ReadOnly CategoryName As String
    Public ReadOnly ProductId As String

    Public Sub New(id As Integer, name As String, url As String, imageUrl As String, price As Decimal, inStock As Boolean, categoryName As String)
        Me.Id = id
        Me.Name = name
        Me.Url = url
        Me.ImageUrl = imageUrl
        Me.Price = price
        Me.InStock = inStock
        Me.CategoryName = categoryName
        Me.ProductId = url & "#product"
    End Sub
End Class

Private Shared Function LoadHomeCategories(page As Page, baseUrl As String, maxCount As Integer) As List(Of SeoCategory)
    Dim cacheKey As String = "SEO_HOME_CATS_" & maxCount.ToString(System.Globalization.CultureInfo.InvariantCulture)
    Dim cached As List(Of SeoCategory) = TryCast(System.Web.HttpRuntime.Cache(cacheKey), List(Of SeoCategory))
    If cached IsNot Nothing Then Return cached

    Dim list As New List(Of SeoCategory)()

    Try
        Dim cs As String = System.Configuration.ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Using cn As New MySqlConnection(cs)
            cn.Open()
            Using cmd As New MySqlCommand("SELECT Id, Descrizione FROM Categorie ORDER BY Ordinamento ASC, Descrizione ASC LIMIT @lim", cn)
                cmd.Parameters.AddWithValue("@lim", maxCount)
                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim id As Integer = SafeInt32(rdr("Id"), 0)
                        Dim name As String = SafeTrim(rdr("Descrizione"))
                        If id > 0 AndAlso Not String.IsNullOrEmpty(name) Then
                            Dim url As String = baseUrl & "articoli.aspx?ct=" & id.ToString(System.Globalization.CultureInfo.InvariantCulture)
                            list.Add(New SeoCategory(id, name, url))
                        End If
                    End While
                End Using
            End Using
        End Using
    Catch
        ' ignora
    End Try

    System.Web.HttpRuntime.Cache.Insert(
        cacheKey,
        list,
        Nothing,
        DateTime.UtcNow.AddMinutes(30),
        System.Web.Caching.Cache.NoSlidingExpiration
    )

    Return list
End Function

Private Shared Function LoadHomeProducts(page As Page, baseUrl As String, maxCount As Integer) As List(Of SeoProduct)
    Dim cacheKey As String = "SEO_HOME_PROD_" & maxCount.ToString(System.Globalization.CultureInfo.InvariantCulture)
    Dim cached As List(Of SeoProduct) = TryCast(System.Web.HttpRuntime.Cache(cacheKey), List(Of SeoProduct))
    If cached IsNot Nothing Then Return cached

    Dim list As New List(Of SeoProduct)()

    Try
        Dim cs As String = System.Configuration.ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Using cn As New MySqlConnection(cs)
            cn.Open()

            Dim sql As String =
                "SELECT a.id, a.Descrizione1, a.Prezzo, a.PrezzoScontato, a.Img1, " &
                "IFNULL(g.Giacenza,0) AS Giacenza, c.Descrizione AS Categoria " &
                "FROM Articoli a " &
                "LEFT JOIN articoli_giacenze g ON g.ArticoliId = a.id " &
                "LEFT JOIN Categorie c ON c.Id = a.CategorieId " &
                "ORDER BY a.id DESC " &
                "LIMIT @lim"

            Using cmd As New MySqlCommand(sql, cn)
                cmd.Parameters.AddWithValue("@lim", maxCount)

                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim id As Integer = SafeInt32(rdr("id"), 0)
                        Dim name As String = SafeTrim(rdr("Descrizione1"))
                        If id <= 0 OrElse String.IsNullOrEmpty(name) Then Continue While

                        Dim prezzo As Decimal = SafeDec(rdr("Prezzo"), 0D)
                        Dim sconto As Decimal = SafeDec(rdr("PrezzoScontato"), 0D)
                        Dim finalPrice As Decimal = prezzo
                        If sconto > 0D AndAlso (prezzo <= 0D OrElse sconto < prezzo) Then finalPrice = sconto

                        Dim giac As Integer = SafeInt32(rdr("Giacenza"), 0)
                        Dim inStock As Boolean = (giac > 0)

                        Dim catName As String = SafeTrim(rdr("Categoria"))

                        Dim url As String = baseUrl & "articolo.aspx?id=" & id.ToString(System.Globalization.CultureInfo.InvariantCulture)
                        Dim img As String = SafeTrim(rdr("Img1"))
                        Dim imgAbs As String = ToAbsoluteUrl(baseUrl, img)

                        list.Add(New SeoProduct(id, name, url, imgAbs, finalPrice, inStock, catName))
                    End While
                End Using
            End Using
        End Using
    Catch
        ' ignora
    End Try

    System.Web.HttpRuntime.Cache.Insert(
        cacheKey,
        list,
        Nothing,
        DateTime.UtcNow.AddMinutes(15),
        System.Web.Caching.Cache.NoSlidingExpiration
    )

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
    ' Public overload with default value
    Public Shared Function SafeSessionString(ByVal key As String, ByVal defaultValue As String) As String
        Dim v As String = SafeSessionString(key)
        If String.IsNullOrEmpty(v) Then Return defaultValue
        Return v
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
