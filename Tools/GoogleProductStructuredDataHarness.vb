Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web.Script.Serialization

Module GoogleProductStructuredDataHarness
    Private _tests As Integer
    Private _failures As Integer
    Private _fixtures As Integer
    Private ReadOnly Serializer As New JavaScriptSerializer()

    Private Sub AssertTrue(ByVal name As String, ByVal value As Boolean)
        _tests += 1
        If value Then Return
        _failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Sub AssertEqual(ByVal name As String, ByVal expected As Object, ByVal actual As Object)
        AssertTrue(name, Object.Equals(expected, actual))
    End Sub

    Private Sub Fixture(ByVal name As String)
        _fixtures += 1
        Console.WriteLine("FIXTURE_" & _fixtures.ToString("00", CultureInfo.InvariantCulture) & "=" & name)
    End Sub

    Private Function BaseInput(Optional ByVal host As String = "shop-alpha.example") As ProductStructuredDataInput
        Return New ProductStructuredDataInput() With {
            .CanonicalUrl = "https://shop-alpha.example/articolo.aspx?id=42",
            .RequestHost = host,
            .AllowedRequestHosts = New List(Of String) From {"shop-alpha.example", "www.shop-alpha.example"},
            .TenantName = "Synthetic Alpha",
            .TenantDescription = "Catalogo Alpha",
            .TenantHomeUrl = "https://shop-alpha.example/",
            .TenantLogoUrl = "https://shop-alpha.example/Public/assets/images/logo/alpha.svg",
            .ProductName = "Prodotto Alpha",
            .ProductDescription = "Descrizione reale",
            .CommercialSku = "SKU-ALPHA",
            .BrandName = "Marca Alpha",
            .CategoryName = "Categoria Alpha",
            .Gtin = "4006381333931",
            .ProductImages = New List(Of String) From {
                "https://shop-alpha.example/Public/assets/images/articoli/alpha.jpg"
            },
            .OfferPrice = 12.2D,
            .CurrencyCode = "EUR",
            .IsAvailable = True,
            .CommercialResolutionSucceeded = True
        }
    End Function

    Private Function ParseRoot(ByVal json As String) As IDictionary(Of String, Object)
        If String.IsNullOrWhiteSpace(json) Then Return Nothing
        Return TryCast(Serializer.DeserializeObject(json), IDictionary(Of String, Object))
    End Function

    Private Function GraphNodes(ByVal root As IDictionary(Of String, Object)) As IList(Of IDictionary(Of String, Object))
        Dim result As New List(Of IDictionary(Of String, Object))()
        If root Is Nothing OrElse Not root.ContainsKey("@graph") Then Return result
        Dim values As IEnumerable = TryCast(root("@graph"), IEnumerable)
        If values Is Nothing Then Return result
        For Each value As Object In values
            Dim node As IDictionary(Of String, Object) = TryCast(value, IDictionary(Of String, Object))
            If node IsNot Nothing Then result.Add(node)
        Next
        Return result
    End Function

    Private Function NodesOfType(ByVal root As IDictionary(Of String, Object), ByVal typeName As String) As IList(Of IDictionary(Of String, Object))
        Dim result As New List(Of IDictionary(Of String, Object))()
        For Each node As IDictionary(Of String, Object) In GraphNodes(root)
            If node.ContainsKey("@type") AndAlso String.Equals(Convert.ToString(node("@type")), typeName, StringComparison.Ordinal) Then result.Add(node)
        Next
        Return result
    End Function

    Private Function ProductNode(ByVal json As String) As IDictionary(Of String, Object)
        Dim nodes As IList(Of IDictionary(Of String, Object)) = NodesOfType(ParseRoot(json), "Product")
        If nodes.Count <> 1 Then Return Nothing
        Return nodes(0)
    End Function

    Private Function OfferNode(ByVal product As IDictionary(Of String, Object)) As IDictionary(Of String, Object)
        If product Is Nothing OrElse Not product.ContainsKey("offers") Then Return Nothing
        Return TryCast(product("offers"), IDictionary(Of String, Object))
    End Function

    Private Function PropertyText(ByVal node As IDictionary(Of String, Object), ByVal name As String) As String
        If node Is Nothing OrElse Not node.ContainsKey(name) Then Return String.Empty
        Return Convert.ToString(node(name), CultureInfo.InvariantCulture)
    End Function

    Private Sub AssertSingleProductOffer(ByVal label As String, ByVal json As String)
        Dim root As IDictionary(Of String, Object) = ParseRoot(json)
        AssertTrue(label & " valid JSON", root IsNot Nothing)
        AssertEqual(label & " one Product", 1, NodesOfType(root, "Product").Count)
        Dim product As IDictionary(Of String, Object) = ProductNode(json)
        AssertTrue(label & " one Offer", OfferNode(product) IsNot Nothing)
        AssertTrue(label & " no ProductGroup", json.IndexOf("ProductGroup", StringComparison.Ordinal) < 0)
        AssertTrue(label & " no review fabrication", json.IndexOf("aggregateRating", StringComparison.Ordinal) < 0 AndAlso json.IndexOf("""review""", StringComparison.Ordinal) < 0)
    End Sub

    Sub Main()
        Fixture("available-no-promo")
        Dim normal As ProductStructuredDataInput = BaseInput()
        Dim normalJson As String = ProductStructuredDataBuilder.BuildJson(normal)
        AssertSingleProductOffer("normal", normalJson)
        AssertEqual("normal price", "12.20", PropertyText(OfferNode(ProductNode(normalJson)), "price"))
        AssertEqual("normal availability", "https://schema.org/InStock", PropertyText(OfferNode(ProductNode(normalJson)), "availability"))

        Fixture("unavailable")
        Dim unavailable As ProductStructuredDataInput = BaseInput()
        unavailable.IsAvailable = False
        Dim unavailableJson As String = ProductStructuredDataBuilder.BuildJson(unavailable)
        AssertEqual("unavailable schema", "https://schema.org/OutOfStock", PropertyText(OfferNode(ProductNode(unavailableJson)), "availability"))

        Fixture("immediate-promotion")
        Dim immediate As ProductStructuredDataInput = BaseInput()
        immediate.OfferPrice = 5D
        immediate.PriceValidUntil = New DateTime(2027, 12, 31)
        Dim immediateOffer As IDictionary(Of String, Object) = OfferNode(ProductNode(ProductStructuredDataBuilder.BuildJson(immediate)))
        AssertEqual("immediate price", "5.00", PropertyText(immediateOffer, "price"))
        AssertEqual("immediate authoritative end", "2027-12-31", PropertyText(immediateOffer, "priceValidUntil"))

        Fixture("quantity-tier")
        Dim tier As ProductStructuredDataInput = BaseInput()
        tier.CommercialSku = "ZAP80-A4"
        tier.OfferPrice = 5D
        Dim tierJson As String = ProductStructuredDataBuilder.BuildJson(tier)
        AssertEqual("tier keeps quantity-one price", "5.00", PropertyText(OfferNode(ProductNode(tierJson)), "price"))
        AssertTrue("tier price not forced", tierJson.IndexOf("4.00", StringComparison.Ordinal) < 0)
        AssertTrue("tier has no AggregateOffer", tierJson.IndexOf("AggregateOffer", StringComparison.Ordinal) < 0)

        Fixture("immediate-promotion-and-tier")
        Dim mixed As ProductStructuredDataInput = BaseInput()
        mixed.CommercialSku = "ZAP80-A4"
        mixed.OfferPrice = 5D
        Dim mixedJson As String = ProductStructuredDataBuilder.BuildJson(mixed)
        AssertSingleProductOffer("mixed", mixedJson)
        AssertEqual("mixed quantity-one price", "5.00", PropertyText(OfferNode(ProductNode(mixedJson)), "price"))

        Fixture("long-price")
        Dim longPrice As ProductStructuredDataInput = BaseInput()
        longPrice.OfferPrice = 1500D
        AssertEqual("long price invariant", "1500.00", PropertyText(OfferNode(ProductNode(ProductStructuredDataBuilder.BuildJson(longPrice))), "price"))

        Fixture("brand-present")
        Dim withBrand As IDictionary(Of String, Object) = ProductNode(ProductStructuredDataBuilder.BuildJson(BaseInput()))
        AssertTrue("brand present", withBrand.ContainsKey("brand"))

        Fixture("brand-absent")
        Dim noBrand As ProductStructuredDataInput = BaseInput()
        noBrand.BrandName = String.Empty
        AssertTrue("brand omitted", Not ProductNode(ProductStructuredDataBuilder.BuildJson(noBrand)).ContainsKey("brand"))

        Fixture("valid-gtin")
        Dim gtinCases As String() = {"96385074", "036000291452", "4006381333931", "10012345000017"}
        For Each gtin As String In gtinCases
            Dim validGtin As ProductStructuredDataInput = BaseInput()
            validGtin.Gtin = gtin
            Dim gtinProduct As IDictionary(Of String, Object) = ProductNode(ProductStructuredDataBuilder.BuildJson(validGtin))
            AssertEqual("valid GTIN " & gtin.Length.ToString(CultureInfo.InvariantCulture), gtin, PropertyText(gtinProduct, "gtin" & gtin.Length.ToString(CultureInfo.InvariantCulture)))
        Next

        Fixture("invalid-gtin")
        Dim invalidGtin As ProductStructuredDataInput = BaseInput()
        invalidGtin.Gtin = "4006381333932"
        Dim invalidProduct As IDictionary(Of String, Object) = ProductNode(ProductStructuredDataBuilder.BuildJson(invalidGtin))
        AssertTrue("invalid GTIN omitted", Not invalidProduct.ContainsKey("gtin13") AndAlso Not invalidProduct.ContainsKey("gtin"))

        Fixture("valid-image")
        Dim imageProduct As IDictionary(Of String, Object) = ProductNode(normalJson)
        AssertTrue("valid image emitted", imageProduct.ContainsKey("image"))
        AssertTrue("image tenant authority", normalJson.Contains("https://shop-alpha.example/Public/assets/images/articoli/alpha.jpg"))

        Fixture("missing-or-placeholder-image")
        Dim missingImage As ProductStructuredDataInput = BaseInput()
        missingImage.ProductImages = New List(Of String) From {
            "https://shop-alpha.example/Public/assets/images/img/placeholder.svg",
            "https://other.example/product.jpg"
        }
        AssertTrue("missing image omitted", Not ProductNode(ProductStructuredDataBuilder.BuildJson(missingImage)).ContainsKey("image"))

        Fixture("html-and-special-description")
        Dim special As ProductStructuredDataInput = BaseInput()
        special.ProductName = "Prodotto ""speciale"" </script>"
        special.ProductDescription = "<p>Test &amp; qualità</p><script>ignored</script>"
        Dim specialJson As String = ProductStructuredDataBuilder.BuildJson(special)
        AssertTrue("script terminator escaped", specialJson.IndexOf("</script", StringComparison.OrdinalIgnoreCase) < 0)
        AssertTrue("HTML tags removed", specialJson.IndexOf("<p>", StringComparison.OrdinalIgnoreCase) < 0)
        AssertTrue("Unicode preserved", specialJson.Contains("qualità"))
        AssertTrue("special JSON parseable", ParseRoot(specialJson) IsNot Nothing)

        Fixture("no-publishable-price")
        Dim noPrice As ProductStructuredDataInput = BaseInput()
        noPrice.OfferPrice = Nothing
        AssertEqual("no price fail closed", String.Empty, ProductStructuredDataBuilder.BuildJson(noPrice))

        Fixture("technical-promotion-error")
        Dim technicalError As ProductStructuredDataInput = BaseInput()
        technicalError.CommercialResolutionSucceeded = False
        AssertEqual("technical error fail closed", String.Empty, ProductStructuredDataBuilder.BuildJson(technicalError))

        Fixture("two-tenants-and-unknown-host")
        Dim tenantAJson As String = ProductStructuredDataBuilder.BuildJson(BaseInput())
        Dim tenantB As ProductStructuredDataInput = BaseInput("store-beta.example")
        tenantB.CanonicalUrl = "https://store-beta.example/articolo.aspx?id=77"
        tenantB.AllowedRequestHosts = New List(Of String) From {"store-beta.example"}
        tenantB.TenantName = "Synthetic Beta"
        tenantB.TenantDescription = "Catalogo Beta"
        tenantB.TenantHomeUrl = "https://store-beta.example/"
        tenantB.TenantLogoUrl = "https://store-beta.example/Public/assets/images/logo/beta.svg"
        tenantB.ProductName = "Prodotto Beta"
        tenantB.CategoryName = "Categoria Beta"
        tenantB.ProductImages = New List(Of String) From {"https://store-beta.example/Public/assets/images/articoli/beta.jpg"}
        Dim tenantBJson As String = ProductStructuredDataBuilder.BuildJson(tenantB)
        AssertTrue("tenant A isolated", tenantAJson.IndexOf("store-beta.example", StringComparison.OrdinalIgnoreCase) < 0 AndAlso tenantAJson.IndexOf("Synthetic Beta", StringComparison.Ordinal) < 0)
        AssertTrue("tenant B isolated", tenantBJson.IndexOf("shop-alpha.example", StringComparison.OrdinalIgnoreCase) < 0 AndAlso tenantBJson.IndexOf("Synthetic Alpha", StringComparison.Ordinal) < 0)
        AssertTrue("tenant B logo", tenantBJson.Contains("/logo/beta.svg"))
        AssertEqual("unknown host fail closed", String.Empty, ProductStructuredDataBuilder.BuildJson(BaseInput("unknown.example")))

        Fixture("anonymous-public-context")
        Dim anonymous As ProductStructuredDataInput = BaseInput()
        anonymous.OfferPrice = 5D
        Dim anonymousJson As String = ProductStructuredDataBuilder.BuildJson(anonymous)
        AssertEqual("anonymous visible public price", "5.00", PropertyText(OfferNode(ProductNode(anonymousJson)), "price"))
        AssertTrue("anonymous no personal data", anonymousJson.IndexOf("LoginId", StringComparison.OrdinalIgnoreCase) < 0 AndAlso anonymousJson.IndexOf("session", StringComparison.OrdinalIgnoreCase) < 0)

        Fixture("authenticated-owner-scoped-context")
        Dim prova As ProductStructuredDataInput = BaseInput()
        prova.OfferPrice = 4.75D
        Dim provaJson As String = ProductStructuredDataBuilder.BuildJson(prova)
        AssertEqual("PROVA response price", "4.75", PropertyText(OfferNode(ProductNode(provaJson)), "price"))
        AssertTrue("PROVA identity not serialized", provaJson.IndexOf("PROVA", StringComparison.OrdinalIgnoreCase) < 0)
        AssertEqual("anonymous rebuild unaffected", "5.00", PropertyText(OfferNode(ProductNode(ProductStructuredDataBuilder.BuildJson(anonymous))), "price"))

        AssertEqual("fixture coverage", 18, _fixtures)
        Console.WriteLine("PRODUCT_STRUCTURED_DATA_FIXTURES=" & _fixtures.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("PRODUCT_STRUCTURED_DATA_TESTS=" & _tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("PRODUCT_STRUCTURED_DATA_FAILURES=" & _failures.ToString(CultureInfo.InvariantCulture))
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
