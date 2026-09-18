Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO

Module StorefrontSameDatabaseTenantHarness
    Private NotInheritable Class SyntheticStorefront
        Public Property Identity As StorefrontSeoTenantIdentity
        Public Property ApplicationLabel As String
        Public Property DatabaseIdentity As String
        Public Property CssFileName As String
        Public Property ContactLabel As String
        Public Property InitialUserPriceListId As Integer
        Public Property SharedArticleId As Integer
    End Class

    Private _tests As Integer
    Private _failures As Integer

    Private Sub AssertEqual(ByVal name As String, ByVal expected As Object, ByVal actual As Object)
        _tests += 1
        If Object.Equals(expected, actual) Then Return
        _failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Sub AssertTrue(ByVal name As String, ByVal value As Boolean)
        AssertEqual(name, True, value)
    End Sub

    Private Function SelectTenant(ByVal identities As IList(Of StorefrontSeoTenantIdentity),
                                  ByVal host As String) As StorefrontSeoTenantIdentity
        Return StorefrontCanonicalHostPolicy.SelectExactTenant(identities, host, False)
    End Function

    Private Function ProfileFor(ByVal profiles As IList(Of SyntheticStorefront),
                                ByVal identity As StorefrontSeoTenantIdentity) As SyntheticStorefront
        If identity Is Nothing Then Return Nothing
        For Each profile As SyntheticStorefront In profiles
            If profile IsNot Nothing AndAlso profile.Identity IsNot Nothing AndAlso
               profile.Identity.CompanyId = identity.CompanyId Then Return profile
        Next
        Return Nothing
    End Function

    Sub Main(ByVal args As String())
        If args Is Nothing OrElse args.Length <> 1 OrElse String.IsNullOrWhiteSpace(args(0)) Then
            Console.Error.WriteLine("SAME_DATABASE_FIXTURE_ROOT_REQUIRED")
            Environment.ExitCode = 2
            Return
        End If

        Dim root As String = Path.GetFullPath(args(0))
        Dim styles As String = Path.Combine(root, "Public", "style")
        Directory.CreateDirectory(styles)
        File.WriteAllText(Path.Combine(styles, "storefront-a.css"), "body{--storefront:a}")
        File.WriteAllText(Path.Combine(styles, "storefront-b.css"), "body{--storefront:b}")

        Dim storefrontA As New SyntheticStorefront() With {
            .Identity = StorefrontCanonicalHostPolicy.CreateTenant(
                101, "Synthetic Storefront A", "Shared catalog A", "store-a.example", "alias-a.example", "logo-a.svg", 11),
            .ApplicationLabel = "IIS_APP_A",
            .DatabaseIdentity = "SYNTHETIC_SHARED_DATABASE",
            .CssFileName = "storefront-a.css",
            .ContactLabel = "CONTACT_A",
            .InitialUserPriceListId = 111,
            .SharedArticleId = 42
        }
        Dim storefrontB As New SyntheticStorefront() With {
            .Identity = StorefrontCanonicalHostPolicy.CreateTenant(
                202, "Synthetic Storefront B", "Shared catalog B", "store-b.example", "alias-b.example", "logo-b.svg", 22),
            .ApplicationLabel = "IIS_APP_B",
            .DatabaseIdentity = "SYNTHETIC_SHARED_DATABASE",
            .CssFileName = "storefront-b.css",
            .ContactLabel = "CONTACT_B",
            .InitialUserPriceListId = 222,
            .SharedArticleId = 42
        }
        Dim profiles As IList(Of SyntheticStorefront) = New List(Of SyntheticStorefront) From {storefrontA, storefrontB}
        Dim identities As IList(Of StorefrontSeoTenantIdentity) = New List(Of StorefrontSeoTenantIdentity) From {
            storefrontA.Identity, storefrontB.Identity
        }

        Dim selectedA As StorefrontSeoTenantIdentity = SelectTenant(identities, "STORE-A.EXAMPLE.")
        Dim selectedAliasA As StorefrontSeoTenantIdentity = SelectTenant(identities, "alias-a.example")
        Dim selectedB As StorefrontSeoTenantIdentity = SelectTenant(identities, "store-b.example")
        Dim selectedAliasB As StorefrontSeoTenantIdentity = SelectTenant(identities, "ALIAS-B.EXAMPLE.")

        AssertEqual("canonical A selects storefront A", 101, If(selectedA Is Nothing, 0, selectedA.CompanyId))
        AssertEqual("alias A selects storefront A", 101, If(selectedAliasA Is Nothing, 0, selectedAliasA.CompanyId))
        AssertEqual("alias A canonical remains A", "https://store-a.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedAliasA, "/articolo.aspx?id=42"))
        AssertEqual("canonical B selects storefront B", 202, If(selectedB Is Nothing, 0, selectedB.CompanyId))
        AssertEqual("alias B selects storefront B", 202, If(selectedAliasB Is Nothing, 0, selectedAliasB.CompanyId))
        AssertEqual("alias B canonical remains B", "https://store-b.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedAliasB, "/articolo.aspx?id=42"))

        Dim profileA As SyntheticStorefront = ProfileFor(profiles, selectedA)
        Dim profileB As SyntheticStorefront = ProfileFor(profiles, selectedB)
        AssertEqual("A name isolated", "Synthetic Storefront A", profileA.Identity.CompanyName)
        AssertEqual("A request belongs to IIS application A", "IIS_APP_A", profileA.ApplicationLabel)
        AssertEqual("A logo isolated", "logo-a.svg", profileA.Identity.LogoFileName)
        AssertEqual("A contact isolated", "CONTACT_A", profileA.ContactLabel)
        AssertEqual("A default price list follows selected row", 11, profileA.Identity.DefaultPriceListId)
        AssertEqual("A initial user price list follows selected row", 111, profileA.InitialUserPriceListId)
        AssertEqual("B name isolated", "Synthetic Storefront B", profileB.Identity.CompanyName)
        AssertEqual("B request belongs to IIS application B", "IIS_APP_B", profileB.ApplicationLabel)
        AssertEqual("B logo isolated", "logo-b.svg", profileB.Identity.LogoFileName)
        AssertEqual("B contact isolated", "CONTACT_B", profileB.ContactLabel)
        AssertEqual("B default price list follows selected row", 22, profileB.Identity.DefaultPriceListId)
        AssertEqual("B initial user price list follows selected row", 222, profileB.InitialUserPriceListId)
        AssertEqual("two IIS applications share one database identity", profileA.DatabaseIdentity, profileB.DatabaseIdentity)
        AssertTrue("A never exposes B name", Not profileA.Identity.CompanyName.Contains("Storefront B"))
        AssertTrue("B never exposes A name", Not profileB.Identity.CompanyName.Contains("Storefront A"))

        AssertEqual("A css isolated", "/Public/style/storefront-a.css", TenantRuntimeAssetResolver.ResolveTenantStylesheet(profileA.CssFileName, root))
        AssertEqual("B css isolated", "/Public/style/storefront-b.css", TenantRuntimeAssetResolver.ResolveTenantStylesheet(profileB.CssFileName, root))
        AssertEqual("missing A css never falls back to B", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("missing-a.css", root))
        AssertEqual("legacy missing stylesheet omitted", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("style_1.css", root))
        AssertEqual("legacy missing background omitted", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground("Default1.png", root))

        Const sharedArticleId As Integer = 42
        AssertEqual("same article id in storefront A", sharedArticleId, profileA.SharedArticleId)
        AssertEqual("same article id in storefront B", sharedArticleId, profileB.SharedArticleId)
        AssertEqual("same article canonical A", "https://store-a.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedA, "/articolo.aspx?id=" & sharedArticleId.ToString(CultureInfo.InvariantCulture)))
        AssertEqual("same article canonical B", "https://store-b.example/articolo.aspx?id=42", StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedB, "/articolo.aspx?id=" & sharedArticleId.ToString(CultureInfo.InvariantCulture)))
        AssertTrue("same product stays in different storefront contexts", Not String.Equals(
            StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedA, "/articolo.aspx?id=42"),
            StorefrontCanonicalHostPolicy.BuildCanonicalUrl(selectedB, "/articolo.aspx?id=42"),
            StringComparison.OrdinalIgnoreCase))
        AssertEqual("seller A follows selected row", "Synthetic Storefront A", selectedA.CompanyName)
        AssertEqual("seller B follows selected row", "Synthetic Storefront B", selectedB.CompanyName)

        Dim repeatA1 As StorefrontSeoTenantIdentity = SelectTenant(identities, "store-a.example")
        Dim repeatB As StorefrontSeoTenantIdentity = SelectTenant(identities, "store-b.example")
        Dim repeatA2 As StorefrontSeoTenantIdentity = SelectTenant(identities, "store-a.example")
        AssertEqual("A B A first A", 101, If(repeatA1 Is Nothing, 0, repeatA1.CompanyId))
        AssertEqual("A B A B", 202, If(repeatB Is Nothing, 0, repeatB.CompanyId))
        AssertEqual("A B A second A", 101, If(repeatA2 Is Nothing, 0, repeatA2.CompanyId))
        AssertEqual("A B A restores A default price list", 11, If(repeatA2 Is Nothing, 0, repeatA2.DefaultPriceListId))

        AssertTrue("unknown host fails closed", SelectTenant(identities, "unknown.example") Is Nothing)
        Dim duplicate As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(
            303, "Duplicate", "Duplicate host", "store-a.example", "duplicate.example", "duplicate.svg", 3)
        Dim ambiguous As IList(Of StorefrontSeoTenantIdentity) = New List(Of StorefrontSeoTenantIdentity) From {
            storefrontA.Identity, storefrontB.Identity, duplicate
        }
        AssertTrue("ambiguous host fails closed", SelectTenant(ambiguous, "store-a.example") Is Nothing)
        AssertTrue("url2 without canonical url1 rejected", StorefrontCanonicalHostPolicy.CreateTenant(
            404, "Alias Only", "Invalid", "", "alias-only.example", "alias.svg", 1) Is Nothing)

        Dim robotsA As String = StorefrontCanonicalHostPolicy.BuildRobotsText(selectedA)
        Dim robotsB As String = StorefrontCanonicalHostPolicy.BuildRobotsText(selectedB)
        AssertTrue("robots A uses canonical A", robotsA.Contains("https://store-a.example/sitemap.xml"))
        AssertTrue("robots B uses canonical B", robotsB.Contains("https://store-b.example/sitemap.xml"))
        AssertTrue("robots A excludes B", Not robotsA.Contains("store-b.example"))
        AssertTrue("robots B excludes A", Not robotsB.Contains("store-a.example"))

        Console.WriteLine("SAME_DATABASE_TENANT_TESTS=" & _tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("SAME_DATABASE_TENANT_FAILURES=" & _failures.ToString(CultureInfo.InvariantCulture))
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
