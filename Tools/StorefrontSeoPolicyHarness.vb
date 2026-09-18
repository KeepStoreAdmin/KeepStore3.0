Option Strict On
Option Explicit On

Imports System

Module StorefrontSeoPolicyHarness
    Private _tests As Integer
    Private _failures As Integer

    Private Sub AssertEqual(ByVal name As String, ByVal expected As Object, ByVal actual As Object)
        _tests += 1
        If Not Object.Equals(expected, actual) Then
            _failures += 1
            Console.Error.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Sub AssertTrue(ByVal name As String, ByVal value As Boolean)
        AssertEqual(name, True, value)
    End Sub

    Private Sub AssertFalse(ByVal name As String, ByVal value As Boolean)
        AssertEqual(name, False, value)
    End Sub

    Sub Main()
        Dim tenantA As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(
            101, "Synthetic Alpha", "Alpha catalog", "shop-alpha.example", "www.shop-alpha.example", "alpha.svg", 1)
        Dim tenantB As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(
            202, "Synthetic Beta", "Beta catalog", "https://store-beta.example/path", "", "beta.svg", 2)

        AssertTrue("tenant A created", tenantA IsNot Nothing)
        AssertTrue("tenant B created", tenantB IsNot Nothing)
        AssertEqual("tenant A canonical base", "https://shop-alpha.example", tenantA.CanonicalBaseUrl)
        AssertEqual("tenant B canonical base", "https://store-beta.example", tenantB.CanonicalBaseUrl)
        AssertEqual("tenant A product canonical", "https://shop-alpha.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantA, "/articolo.aspx?id=42#details"))
        AssertEqual("tenant B product canonical", "https://store-beta.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantB, "/articolo.aspx?id=42"))
        AssertEqual("absolute canonical input rejected", "", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantA, "https://attacker.example/product"))
        AssertEqual("scheme-relative canonical input rejected", "", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantA, "//attacker.example/product"))

        AssertTrue("primary host accepted", StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenantA, "SHOP-ALPHA.EXAMPLE.", False))
        AssertTrue("configured alias accepted", StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenantA, "www.shop-alpha.example", False))
        AssertFalse("local flag does not bypass exact host", StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenantA, "localhost", True))
        AssertFalse("unknown host rejected", StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenantA, "altered.example", False))
        AssertFalse("cross-tenant host rejected", StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenantA, tenantB.CanonicalHost, False))

        Dim aliasRequest As New Uri("http://www.shop-alpha.example/articoli.aspx?q=desk")
        AssertEqual("alias redirected to canonical HTTPS", "https://shop-alpha.example/articoli.aspx?q=desk", StorefrontCanonicalHostPolicy.BuildCanonicalRedirect(aliasRequest, False, tenantA))
        AssertEqual("unknown host never redirected", "", StorefrontCanonicalHostPolicy.BuildCanonicalRedirect(New Uri("https://altered.example/articoli.aspx"), False, tenantA))
        AssertEqual("canonical HTTPS no redirect", "", StorefrontCanonicalHostPolicy.BuildCanonicalRedirect(New Uri("https://shop-alpha.example/articoli.aspx"), False, tenantA))

        Dim robotsA As String = StorefrontCanonicalHostPolicy.BuildRobotsText(tenantA)
        Dim robotsB As String = StorefrontCanonicalHostPolicy.BuildRobotsText(tenantB)
        AssertTrue("tenant A robots sitemap", robotsA.Contains("Sitemap: https://shop-alpha.example/sitemap.xml"))
        AssertTrue("tenant B robots sitemap", robotsB.Contains("Sitemap: https://store-beta.example/sitemap.xml"))
        AssertFalse("tenant A robots isolated from B", robotsA.Contains(tenantB.CanonicalHost))
        AssertFalse("tenant B robots isolated from A", robotsB.Contains(tenantA.CanonicalHost))

        Dim sitemapPaths As String() = {"/", "/articoli.aspx", "/articolo.aspx?id=42"}
        For Each sitemapPath As String In sitemapPaths
            Dim tenantAUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantA, sitemapPath)
            Dim tenantBUrl As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenantB, sitemapPath)
            AssertTrue("tenant A sitemap authority " & sitemapPath, tenantAUrl.StartsWith(tenantA.CanonicalBaseUrl & "/", StringComparison.Ordinal))
            AssertTrue("tenant B sitemap authority " & sitemapPath, tenantBUrl.StartsWith(tenantB.CanonicalBaseUrl & "/", StringComparison.Ordinal))
            AssertFalse("tenant A sitemap excludes B " & sitemapPath, tenantAUrl.Contains(tenantB.CanonicalHost))
            AssertFalse("tenant B sitemap excludes A " & sitemapPath, tenantBUrl.Contains(tenantA.CanonicalHost))
        Next

        AssertTrue("cart noindex", StorefrontCanonicalHostPolicy.IsNoIndexPath("/carrello.aspx"))
        AssertTrue("account noindex", StorefrontCanonicalHostPolicy.IsNoIndexPath("/my-account-orders.aspx?page=2"))
        AssertTrue("checkout noindex", StorefrontCanonicalHostPolicy.IsNoIndexPath("/ordine.aspx?ReturnUrl=x"))
        AssertTrue("legacy promotions noindex", StorefrontCanonicalHostPolicy.IsNoIndexPath("/promozioni.aspx"))
        AssertFalse("home indexable", StorefrontCanonicalHostPolicy.IsNoIndexPath("/Default.aspx"))
        AssertFalse("catalog indexable", StorefrontCanonicalHostPolicy.IsNoIndexPath("/articoli.aspx"))
        AssertFalse("product indexable", StorefrontCanonicalHostPolicy.IsNoIndexPath("/articolo.aspx"))

        AssertEqual("localhost configuration rejected", "", StorefrontCanonicalHostPolicy.NormalizeConfiguredBaseUrl("https://localhost:8443"))
        AssertEqual("credentialed URL rejected", "", StorefrontCanonicalHostPolicy.NormalizeConfiguredBaseUrl("https://user:pass@shop-alpha.example"))

        Console.WriteLine("SEO_POLICY_TESTS=" & _tests.ToString())
        Console.WriteLine("SEO_POLICY_FAILURES=" & _failures.ToString())
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
