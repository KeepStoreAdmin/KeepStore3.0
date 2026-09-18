Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.IO

Module TenantRuntimeAssetResolverHarness
    Private _tests As Integer
    Private _failures As Integer
    Private _fixtures As Integer

    Private Sub Fixture(ByVal name As String)
        _fixtures += 1
        Console.WriteLine("FIXTURE_" & _fixtures.ToString("00", CultureInfo.InvariantCulture) & "=" & name)
    End Sub

    Private Sub AssertEqual(ByVal name As String, ByVal expected As String, ByVal actual As String)
        _tests += 1
        If String.Equals(expected, actual, StringComparison.Ordinal) Then Return
        _failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Sub Main(ByVal args As String())
        If args Is Nothing OrElse args.Length <> 1 OrElse String.IsNullOrWhiteSpace(args(0)) Then
            Console.Error.WriteLine("ASSET_FIXTURE_ROOT_REQUIRED")
            Environment.ExitCode = 2
            Return
        End If

        Dim root As String = Path.GetFullPath(args(0))
        Dim styles As String = Path.Combine(root, "Public", "style")
        Dim backgrounds As String = Path.Combine(root, "Public", "Sfondi")
        Directory.CreateDirectory(styles)
        Directory.CreateDirectory(backgrounds)
        File.WriteAllText(Path.Combine(styles, "tenant-a.css"), "body{}")
        File.WriteAllText(Path.Combine(styles, "tenant-b.css"), "body{}")
        File.WriteAllBytes(Path.Combine(backgrounds, "tenant-a.png"), New Byte() {0})
        File.WriteAllBytes(Path.Combine(backgrounds, "tenant-b.jpg"), New Byte() {0})

        Fixture("tenant-with-valid-css")
        AssertEqual("valid css", "/Public/style/tenant-a.css", TenantRuntimeAssetResolver.ResolveTenantStylesheet("tenant-a.css", root))

        Fixture("tenant-with-missing-css")
        AssertEqual("missing css", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("missing.css", root))

        Fixture("tenant-without-custom-css")
        AssertEqual("empty css", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet(String.Empty, root))

        Fixture("tenant-with-valid-background")
        AssertEqual("valid background", "/Public/Sfondi/tenant-a.png", TenantRuntimeAssetResolver.ResolveTenantBackground("tenant-a.png", root))

        Fixture("tenant-with-missing-background")
        AssertEqual("missing background", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground("missing.png", root))

        Fixture("tenant-without-background")
        AssertEqual("empty background", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground(Nothing, root))

        Fixture("external-url")
        AssertEqual("external css", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("https://external.invalid/theme.css", root))
        AssertEqual("protocol relative background", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground("//external.invalid/bg.png", root))

        Fixture("path-traversal")
        AssertEqual("traversal css", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("..\tenant-a.css", root))
        AssertEqual("nested background", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground("nested/tenant-a.png", root))

        Fixture("unauthorized-extension")
        AssertEqual("script as css", String.Empty, TenantRuntimeAssetResolver.ResolveTenantStylesheet("tenant-a.js", root))
        AssertEqual("markup as background", String.Empty, TenantRuntimeAssetResolver.ResolveTenantBackground("tenant-a.html", root))

        Fixture("two-tenant-isolation")
        AssertEqual("tenant A css", "/Public/style/tenant-a.css", TenantRuntimeAssetResolver.ResolveTenantStylesheet("tenant-a.css", root))
        AssertEqual("tenant B css", "/Public/style/tenant-b.css", TenantRuntimeAssetResolver.ResolveTenantStylesheet("tenant-b.css", root))
        AssertEqual("tenant A background", "/Public/Sfondi/tenant-a.png", TenantRuntimeAssetResolver.ResolveTenantBackground("tenant-a.png", root))
        AssertEqual("tenant B background", "/Public/Sfondi/tenant-b.jpg", TenantRuntimeAssetResolver.ResolveTenantBackground("tenant-b.jpg", root))

        Console.WriteLine("TENANT_ASSET_FIXTURES=" & _fixtures.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("TENANT_ASSET_TESTS=" & _tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("TENANT_ASSET_FAILURES=" & _failures.ToString(CultureInfo.InvariantCulture))
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
