Option Strict On
Option Explicit On

Imports System

' Harness del task KS-STD-RUNTIME-TENANT-DOMAIN-1A: compilato insieme al template e-mail REALE
' (App_Code/KeepStoreEmailTemplate.vb). Prova che l'URL del logo non ripiega mai su un dominio fisso
' e che il renderer non emette un'immagine con src vuoto.
Module EmailTemplateTenantDomainHarness
    Private _failures As Integer

    Private Sub Assert(ByVal condition As Boolean, ByVal code As String)
        If condition Then
            Console.WriteLine("PASS " & code)
        Else
            _failures += 1
            Console.WriteLine("FAIL " & code)
        End If
    End Sub

    Private Function Render(ByVal siteUrl As String) As String
        Dim model As New KeepStoreEmailMessageModel()
        model.Title = "Prova"
        model.Brand.CompanyName = "Azienda di prova"
        model.Brand.SiteUrl = siteUrl
        model.Brand.LogoWeb = "logo.png"
        Return KeepStoreEmailRenderer.RenderHtml(model)
    End Function

    Function Main() As Integer
        ' 1) Base vuota o non sicura: nessun ripiego su un dominio, nessun URL.
        Assert(KeepStoreEmailLogo.BuildLogoUrl("", "logo.png") = "", "01_LOGO_EMPTY_BASE_NO_FALLBACK")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("   ", "logo.png") = "", "02_LOGO_BLANK_BASE_NO_FALLBACK")
        Assert(KeepStoreEmailLogo.BuildLogoUrl(Nothing, "logo.png") = "", "03_LOGO_NULL_BASE_NO_FALLBACK")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("//host.invalid", "logo.png") = "", "04_LOGO_PROTOCOL_RELATIVE_REFUSED")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("javascript:alert(1)", "logo.png") = "", "05_LOGO_JAVASCRIPT_REFUSED")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("data:text/html,x", "logo.png") = "", "06_LOGO_DATA_REFUSED")

        ' 2) Base valida: comportamento invariato (https forzato, percorso logo standard, barra finale pulita).
        Assert(KeepStoreEmailLogo.BuildLogoUrl("shop.example.test", "logo.png") = "https://shop.example.test/Public/assets/images/logo/logo.png", "07_LOGO_BARE_HOST_HTTPS")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("http://shop.example.test/", "logo.png") = "https://shop.example.test/Public/assets/images/logo/logo.png", "08_LOGO_HTTP_UPGRADED_TRAILING_SLASH")
        Assert(KeepStoreEmailLogo.BuildLogoUrl("https://shop.example.test", "../x.png") = "https://shop.example.test/Public/assets/images/logo/logo.svg", "09_LOGO_TRAVERSAL_USES_DEFAULT_FILE")

        ' 3) Renderer: senza base niente <img> con src vuoto e nessun dominio fisso; con base il logo c'e.
        Dim withoutSite As String = Render("")
        Assert(withoutSite.IndexOf("<img src=""""", StringComparison.OrdinalIgnoreCase) < 0, "10_RENDER_NO_EMPTY_IMG_SRC")
        Assert(withoutSite.IndexOf("taikun", StringComparison.OrdinalIgnoreCase) < 0, "11_RENDER_NO_CUSTOMER_DOMAIN_WITHOUT_SITE")
        Assert(withoutSite.IndexOf("Azienda di prova", StringComparison.Ordinal) >= 0, "12_RENDER_STILL_RENDERS_BODY")

        Dim withSite As String = Render("https://shop.example.test")
        Assert(withSite.IndexOf("<img src=""https://shop.example.test/Public/assets/images/logo/logo.png""", StringComparison.Ordinal) >= 0, "13_RENDER_LOGO_FROM_TENANT_SITE")

        ' 4) Icone si/no di Icecat (metodo REALE estratto da icecat_consult.aspx.vb, risolutore sostituito da un finto):
        ' markup identico a prima per i sei valori, URL assoluto della vetrina anche con un trattino nell'host,
        ' nessuna immagine con indirizzo vuoto quando la vetrina non si risolve.
        StorefrontSeoTenantContext.StubBase = "https://my-shop.example.test"
        Dim yesImg As String = "<img alt="""" src=""https://my-shop.example.test/Images/icecat/yes.png"" />"
        Dim noImg As String = "<img alt="""" src=""https://my-shop.example.test/Images/icecat/no.png"" />"
        Assert(IcecatFlagMarkupHost.IcecatFlagMarkup("Y", True) = yesImg, "14_ICECAT_Y_NO_SPACES")
        Assert(IcecatFlagMarkupHost.IcecatFlagMarkup("Si", True) = " " & yesImg & " " AndAlso IcecatFlagMarkupHost.IcecatFlagMarkup("S", True) = " " & yesImg & " ", "15_ICECAT_SI_AND_S_WITH_SPACES")
        Assert(IcecatFlagMarkupHost.IcecatFlagMarkup("N", False) = noImg, "16_ICECAT_N_NO_SPACES")
        Assert(IcecatFlagMarkupHost.IcecatFlagMarkup("No", False) = " " & noImg & " " AndAlso IcecatFlagMarkupHost.IcecatFlagMarkup("-", False) = " " & noImg & " ", "17_ICECAT_NO_AND_DASH_WITH_SPACES")
        Dim dashed As String = IcecatFlagMarkupHost.IcecatFlagMarkup("-", False)
        Assert(dashed.Split(New String() {"my-shop.example.test"}, StringSplitOptions.None).Length = 2 AndAlso dashed.Split(New String() {"<img"}, StringSplitOptions.None).Length = 2, "18_ICECAT_HOST_WITH_DASH_NOT_CORRUPTED")
        StorefrontSeoTenantContext.StubBase = ""
        Assert(IcecatFlagMarkupHost.IcecatFlagMarkup("Si", True) = "Si" AndAlso IcecatFlagMarkupHost.IcecatFlagMarkup("-", False) = "-", "19_ICECAT_UNRESOLVED_TENANT_KEEPS_TEXT")

        Console.WriteLine("FAILURES=" & _failures.ToString())
        Return If(_failures = 0, 0, 1)
    End Function
End Module
