Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization

' Shared presentation model; standalone Product harness stays self-contained.
Public NotInheritable Class StorefrontBreadcrumbItem
    Public Property Name As String
    Public Property Url As String
    Public Sub New(name As String, url As String)
        Me.Name = NormalizeName(name)
        Me.Url = url
    End Sub
    Public Shared Function NormalizeName(raw As String) As String
        Dim text As String = HttpUtility.HtmlDecode(If(raw, String.Empty))
        text = Regex.Replace(text, "<[^>]*>", " ", RegexOptions.CultureInvariant)
        text = Regex.Replace(text, "[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]", String.Empty, RegexOptions.CultureInvariant)
        Return Regex.Replace(text, "\s+", " ", RegexOptions.CultureInvariant).Trim()
    End Function
    Public Shared Function ToAbsolute(items As IList(Of StorefrontBreadcrumbItem), homeUrl As String) As IList(Of StorefrontBreadcrumbItem)
        Dim home As Uri = Nothing
        Dim result As New List(Of StorefrontBreadcrumbItem)()
        If items Is Nothing OrElse Not Uri.TryCreate(homeUrl, UriKind.Absolute, home) OrElse
           home.Scheme <> Uri.UriSchemeHttps OrElse Not String.IsNullOrEmpty(home.UserInfo) Then Return result
        For Each item As StorefrontBreadcrumbItem In items
            If item Is Nothing Then Return New List(Of StorefrontBreadcrumbItem)()
            Dim target As Uri = Nothing
            Dim raw As String = If(item.Url, String.Empty)
            If raw.StartsWith("~/", StringComparison.Ordinal) Then
                raw = If(HttpContext.Current IsNot Nothing, VirtualPathUtility.ToAbsolute(raw), raw.Substring(1))
            End If
            If Not Uri.TryCreate(home, raw, target) OrElse
               target.Scheme <> Uri.UriSchemeHttps OrElse Not String.IsNullOrEmpty(target.UserInfo) OrElse
               Not String.Equals(target.Authority, home.Authority, StringComparison.OrdinalIgnoreCase) Then Return New List(Of StorefrontBreadcrumbItem)()
            result.Add(New StorefrontBreadcrumbItem(item.Name, target.AbsoluteUri))
        Next
        Return result
    End Function
    Public Shared Function BuildListElements(items As IList(Of StorefrontBreadcrumbItem), canonicalUrl As String) As Object()
        Dim canonical As Uri = Nothing
        If items Is Nothing OrElse items.Count < 2 OrElse items.Count > 16 OrElse
           Not Uri.TryCreate(canonicalUrl, UriKind.Absolute, canonical) OrElse canonical.Scheme <> Uri.UriSchemeHttps Then Return Nothing
        Dim result As New List(Of Object)()
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        For Each item As StorefrontBreadcrumbItem In items
            Dim url As Uri = Nothing
            If item Is Nothing OrElse String.IsNullOrWhiteSpace(NormalizeName(item.Name)) OrElse
               Not Uri.TryCreate(item.Url, UriKind.Absolute, url) OrElse url.Scheme <> Uri.UriSchemeHttps OrElse
               Not String.IsNullOrEmpty(url.UserInfo) OrElse Not String.IsNullOrEmpty(url.Fragment) OrElse
               Not String.Equals(url.Authority, canonical.Authority, StringComparison.OrdinalIgnoreCase) OrElse
               Not seen.Add(url.AbsoluteUri) Then Return Nothing
            ' Structural links only: commercial/search facets are not breadcrumb nodes.
            Dim query = HttpUtility.ParseQueryString(url.Query)
            For Each key As String In query.AllKeys
                If key Is Nothing OrElse Not (key = "st" OrElse key = "ct" OrElse key = "tp" OrElse key = "id" OrElse key = "TCid") Then Return Nothing
                Dim id As Integer = 0
                If Not Integer.TryParse(query(key), NumberStyles.Integer, CultureInfo.InvariantCulture, id) OrElse
                   (id <= 0 AndAlso key <> "TCid") Then Return Nothing
            Next
            result.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"}, {"position", result.Count + 1},
                {"name", NormalizeName(item.Name)}, {"item", url.AbsoluteUri}
            })
        Next
        Return result.ToArray()
    End Function
End Class

Public NotInheritable Class ProductStructuredDataInput
    Public Property CanonicalUrl As String
    Public Property RequestHost As String
    Public Property IsLocalRequest As Boolean
    Public Property AllowedRequestHosts As IList(Of String)
    Public Property TenantName As String
    Public Property TenantDescription As String
    Public Property TenantHomeUrl As String
    Public Property TenantLogoUrl As String
    Public Property ProductName As String
    Public Property ProductDescription As String
    Public Property CommercialSku As String
    Public Property BrandName As String
    Public Property CategoryName As String
    Public Property Gtin As String
    Public Property ProductImages As IList(Of String)
    Public Property OfferPrice As Nullable(Of Decimal)
    Public Property CurrencyCode As String
    Public Property IsAvailable As Nullable(Of Boolean)
    Public Property PriceValidUntil As Nullable(Of DateTime)
    Public Property CommercialResolutionSucceeded As Boolean
    Public Property BreadcrumbItems As IList(Of StorefrontBreadcrumbItem)
End Class

Public NotInheritable Class ProductStructuredDataBuilder
    Private Const SchemaContext As String = "https://schema.org"
    Private Shared ReadOnly GtinPattern As New Regex("^[0-9]+$", RegexOptions.CultureInvariant)
    Private Shared ReadOnly CurrencyPattern As New Regex("^[A-Z]{3}$", RegexOptions.CultureInvariant)

    Private Sub New()
    End Sub

    Public Shared Function BuildJson(ByVal input As ProductStructuredDataInput) As String
        Try
            If input Is Nothing OrElse Not input.CommercialResolutionSucceeded Then Return String.Empty

            Dim canonicalUri As Uri = Nothing
            Dim homeUri As Uri = Nothing
            If Not TryCreateTenantHttpsUri(input.CanonicalUrl, canonicalUri) OrElse
               Not TryCreateTenantHttpsUri(input.TenantHomeUrl, homeUri) OrElse
               canonicalUri Is Nothing OrElse homeUri Is Nothing OrElse
               Not SameAuthority(canonicalUri, homeUri) OrElse
               Not IsRequestHostAuthorized(input, canonicalUri) Then
                Return String.Empty
            End If

            Dim productName As String = NormalizePlainText(input.ProductName)
            Dim tenantName As String = NormalizePlainText(input.TenantName)
            Dim currency As String = Convert.ToString(input.CurrencyCode, CultureInfo.InvariantCulture).Trim().ToUpperInvariant()
            If String.IsNullOrEmpty(productName) OrElse String.IsNullOrEmpty(tenantName) OrElse
               Not input.OfferPrice.HasValue OrElse input.OfferPrice.Value <= 0D OrElse
               Not input.IsAvailable.HasValue OrElse Not CurrencyPattern.IsMatch(currency) Then
                Return String.Empty
            End If

            Dim homeUrl As String = homeUri.GetLeftPart(UriPartial.Authority).TrimEnd("/"c) & "/"
            Dim canonicalUrl As String = canonicalUri.AbsoluteUri
            Dim orgId As String = homeUrl.TrimEnd("/"c) & "#organization"
            Dim websiteId As String = homeUrl.TrimEnd("/"c) & "#website"
            Dim webPageId As String = canonicalUrl & "#webpage"
            Dim productId As String = canonicalUrl & "#product"

            Dim organization As New Dictionary(Of String, Object)()
            organization("@type") = "Organization"
            organization("@id") = orgId
            organization("name") = tenantName
            organization("url") = homeUrl

            Dim tenantDescription As String = NormalizePlainText(input.TenantDescription)
            If Not String.IsNullOrEmpty(tenantDescription) Then organization("description") = tenantDescription

            Dim tenantLogo As String = ValidTenantAssetUrl(input.TenantLogoUrl, canonicalUri)
            If Not String.IsNullOrEmpty(tenantLogo) Then
                organization("logo") = New Dictionary(Of String, Object) From {
                    {"@type", "ImageObject"},
                    {"url", tenantLogo}
                }
            End If

            Dim website As New Dictionary(Of String, Object)()
            website("@type") = "WebSite"
            website("@id") = websiteId
            website("url") = homeUrl
            website("name") = tenantName
            website("publisher") = New Dictionary(Of String, Object) From {{"@id", orgId}}

            Dim product As New Dictionary(Of String, Object)()
            product("@type") = "Product"
            product("@id") = productId
            product("url") = canonicalUrl
            product("name") = productName

            Dim description As String = NormalizePlainText(input.ProductDescription)
            If Not String.IsNullOrEmpty(description) Then product("description") = description

            Dim sku As String = NormalizePlainText(input.CommercialSku)
            If Not String.IsNullOrEmpty(sku) Then product("sku") = sku

            Dim brand As String = NormalizePlainText(input.BrandName)
            If Not String.IsNullOrEmpty(brand) Then
                product("brand") = New Dictionary(Of String, Object) From {
                    {"@type", "Brand"},
                    {"name", brand}
                }
            End If

            Dim category As String = NormalizePlainText(input.CategoryName)
            If Not String.IsNullOrEmpty(category) Then product("category") = category

            Dim gtinProperty As String = String.Empty
            Dim gtinValue As String = String.Empty
            If TryGetValidGtin(input.Gtin, gtinProperty, gtinValue) Then product(gtinProperty) = gtinValue

            Dim images As IList(Of String) = ValidProductImages(input.ProductImages, canonicalUri)
            If images.Count > 0 Then product("image") = New List(Of String)(images).ToArray()

            Dim offer As New Dictionary(Of String, Object)()
            offer("@type") = "Offer"
            offer("url") = canonicalUrl
            offer("price") = input.OfferPrice.Value.ToString("0.00", CultureInfo.InvariantCulture)
            offer("priceCurrency") = currency
            offer("availability") = If(input.IsAvailable.Value,
                                         "https://schema.org/InStock",
                                         "https://schema.org/OutOfStock")
            offer("seller") = New Dictionary(Of String, Object) From {{"@id", orgId}}
            If input.PriceValidUntil.HasValue Then
                offer("priceValidUntil") = input.PriceValidUntil.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
            End If
            product("offers") = offer

            Dim breadcrumb As New Dictionary(Of String, Object)()
            breadcrumb("@type") = "BreadcrumbList"
            breadcrumb("@id") = canonicalUrl & "#breadcrumb"
            breadcrumb("itemListElement") = New Object() {
                New Dictionary(Of String, Object) From {
                    {"@type", "ListItem"}, {"position", 1}, {"name", "Home"}, {"item", homeUrl}
                },
                New Dictionary(Of String, Object) From {
                    {"@type", "ListItem"}, {"position", 2}, {"name", "Catalogo"}, {"item", homeUrl.TrimEnd("/"c) & "/articoli.aspx"}
                },
                New Dictionary(Of String, Object) From {
                    {"@type", "ListItem"}, {"position", 3}, {"name", productName}, {"item", canonicalUrl}
                }
            }

            Dim webPage As New Dictionary(Of String, Object)()
            Dim customBreadcrumb As Object() = StorefrontBreadcrumbItem.BuildListElements(input.BreadcrumbItems, canonicalUrl)
            If customBreadcrumb IsNot Nothing AndAlso
               String.Equals(input.BreadcrumbItems(input.BreadcrumbItems.Count - 1).Url, canonicalUrl, StringComparison.Ordinal) AndAlso
               String.Equals(StorefrontBreadcrumbItem.NormalizeName(input.BreadcrumbItems(input.BreadcrumbItems.Count - 1).Name), productName, StringComparison.Ordinal) Then
                breadcrumb("itemListElement") = customBreadcrumb
            End If

            webPage("@type") = "WebPage"
            webPage("@id") = webPageId
            webPage("url") = canonicalUrl
            webPage("name") = productName
            If Not String.IsNullOrEmpty(description) Then webPage("description") = description
            webPage("isPartOf") = New Dictionary(Of String, Object) From {{"@id", websiteId}}
            webPage("about") = New Dictionary(Of String, Object) From {{"@id", productId}}
            webPage("mainEntity") = New Dictionary(Of String, Object) From {{"@id", productId}}
            If images.Count > 0 Then
                webPage("primaryImageOfPage") = New Dictionary(Of String, Object) From {
                    {"@type", "ImageObject"}, {"url", images(0)}
                }
            End If

            Dim root As New Dictionary(Of String, Object)()
            root("@context") = SchemaContext
            root("@graph") = New Object() {organization, website, webPage, breadcrumb, product}

            Dim serializer As New JavaScriptSerializer()
            Dim json As String = serializer.Serialize(root)
            Return MakeScriptSafe(json)
        Catch
            Return String.Empty
        End Try
    End Function

    Public Shared Function TryGetValidGtin(ByVal rawValue As String,
                                           ByRef propertyName As String,
                                           ByRef normalizedValue As String) As Boolean
        propertyName = String.Empty
        normalizedValue = Convert.ToString(rawValue, CultureInfo.InvariantCulture).Trim()
        If Not (normalizedValue.Length = 8 OrElse normalizedValue.Length = 12 OrElse
                normalizedValue.Length = 13 OrElse normalizedValue.Length = 14) OrElse
           Not GtinPattern.IsMatch(normalizedValue) OrElse Not HasValidGtinCheckDigit(normalizedValue) Then
            normalizedValue = String.Empty
            Return False
        End If

        propertyName = "gtin" & normalizedValue.Length.ToString(CultureInfo.InvariantCulture)
        Return True
    End Function

    Private Shared Function HasValidGtinCheckDigit(ByVal digits As String) As Boolean
        Dim sum As Integer = 0
        Dim weight As Integer = 3
        For index As Integer = digits.Length - 2 To 0 Step -1
            sum += (AscW(digits(index)) - AscW("0"c)) * weight
            weight = If(weight = 3, 1, 3)
        Next
        Dim expected As Integer = (10 - (sum Mod 10)) Mod 10
        Return expected = (AscW(digits(digits.Length - 1)) - AscW("0"c))
    End Function

    Private Shared Function TryCreateTenantHttpsUri(ByVal rawValue As String, ByRef value As Uri) As Boolean
        value = Nothing
        Dim candidate As Uri = Nothing
        If Not Uri.TryCreate(Convert.ToString(rawValue, CultureInfo.InvariantCulture).Trim(), UriKind.Absolute, candidate) OrElse
           candidate Is Nothing OrElse
           Not String.Equals(candidate.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.IsNullOrEmpty(candidate.UserInfo) OrElse
           String.IsNullOrWhiteSpace(candidate.DnsSafeHost) Then
            Return False
        End If
        value = candidate
        Return True
    End Function

    Private Shared Function SameAuthority(ByVal first As Uri, ByVal second As Uri) As Boolean
        Return first IsNot Nothing AndAlso second IsNot Nothing AndAlso
               String.Equals(first.Authority, second.Authority, StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function IsRequestHostAuthorized(ByVal input As ProductStructuredDataInput,
                                                    ByVal canonicalUri As Uri) As Boolean
        If input.IsLocalRequest Then Return True
        Dim requestHost As String = NormalizeHost(input.RequestHost)
        If String.IsNullOrEmpty(requestHost) Then Return False
        If String.Equals(requestHost, NormalizeHost(canonicalUri.DnsSafeHost), StringComparison.OrdinalIgnoreCase) Then Return True
        If input.AllowedRequestHosts Is Nothing Then Return False
        For Each host As String In input.AllowedRequestHosts
            If String.Equals(requestHost, NormalizeHost(host), StringComparison.OrdinalIgnoreCase) Then Return True
        Next
        Return False
    End Function

    Private Shared Function NormalizeHost(ByVal value As String) As String
        Return Convert.ToString(value, CultureInfo.InvariantCulture).Trim().TrimEnd("."c).ToLowerInvariant()
    End Function

    Private Shared Function ValidTenantAssetUrl(ByVal rawValue As String, ByVal canonicalUri As Uri) As String
        Dim asset As Uri = Nothing
        If Not TryCreateTenantHttpsUri(rawValue, asset) OrElse Not SameAuthority(asset, canonicalUri) Then Return String.Empty
        Dim absolute As String = asset.AbsoluteUri
        If IsNonAuthoritativeImage(absolute) Then Return String.Empty
        Return absolute
    End Function

    Private Shared Function ValidProductImages(ByVal candidates As IList(Of String),
                                               ByVal canonicalUri As Uri) As IList(Of String)
        Dim result As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        If candidates Is Nothing Then Return result

        For Each candidate As String In candidates
            Dim asset As Uri = Nothing
            If Not TryCreateTenantHttpsUri(candidate, asset) OrElse Not SameAuthority(asset, canonicalUri) Then Continue For
            Dim absolute As String = asset.AbsoluteUri
            If IsNonAuthoritativeImage(absolute) OrElse Not seen.Add(absolute) Then Continue For
            result.Add(absolute)
        Next
        Return result
    End Function

    Private Shared Function IsNonAuthoritativeImage(ByVal value As String) As Boolean
        Dim lowered As String = Convert.ToString(value, CultureInfo.InvariantCulture).ToLowerInvariant()
        Return lowered.Contains("placeholder") OrElse lowered.Contains("no-image") OrElse
               lowered.Contains("no_image") OrElse lowered.Contains("/demo/") OrElse
               lowered.StartsWith("data:", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function NormalizePlainText(ByVal rawValue As String) As String
        Dim decoded As String = HttpUtility.HtmlDecode(Convert.ToString(rawValue, CultureInfo.InvariantCulture))
        If String.IsNullOrWhiteSpace(decoded) Then Return String.Empty
        decoded = Regex.Replace(decoded, "<[^>]*>", " ", RegexOptions.CultureInvariant)
        decoded = Regex.Replace(decoded, "[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]", String.Empty, RegexOptions.CultureInvariant)
        decoded = Regex.Replace(decoded, "\s+", " ", RegexOptions.CultureInvariant).Trim()
        Return decoded
    End Function

    Private Shared Function MakeScriptSafe(ByVal json As String) As String
        If String.IsNullOrEmpty(json) Then Return String.Empty
        Return json.Replace("&", "\u0026").Replace("<", "\u003c").Replace(">", "\u003e")
    End Function
End Class
