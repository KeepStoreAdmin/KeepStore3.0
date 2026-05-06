Partial Class ThemeTest
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        DemoProductCardSale.ProductId = 101
        DemoProductCardSale.TCId = -1
        DemoProductCardSale.ProductName = "Notebook demo 15 pollici con SSD e display antiriflesso"
        DemoProductCardSale.ProductCode = "DEMO-NB-15"
        DemoProductCardSale.ProductUrl = "#"
        DemoProductCardSale.ImageUrl = "/Public/assets/images/product/product-1.jpg"
        DemoProductCardSale.HoverImageUrl = "/Public/assets/images/product/product-2.jpg"
        DemoProductCardSale.BrandName = "Theme"
        DemoProductCardSale.CategoryName = "Informatica"
        DemoProductCardSale.PriceText = "649,90 €"
        DemoProductCardSale.OldPriceText = "799,90 €"
        DemoProductCardSale.BadgeText = "Promo"
        DemoProductCardSale.IsOnSale = True
        DemoProductCardSale.IsAvailable = True
        DemoProductCardSale.AvailabilityText = "Disponibile"
        DemoProductCardSale.IsDemoMode = True

        DemoProductCardUnavailable.ProductId = 102
        DemoProductCardUnavailable.TCId = -1
        DemoProductCardUnavailable.ProductName = "Accessorio demo compatto per postazione ufficio"
        DemoProductCardUnavailable.ProductCode = "DEMO-ACC-02"
        DemoProductCardUnavailable.ProductUrl = "#"
        DemoProductCardUnavailable.ImageUrl = "/Public/assets/images/product/product-3.jpg"
        DemoProductCardUnavailable.HoverImageUrl = ""
        DemoProductCardUnavailable.BrandName = "Default"
        DemoProductCardUnavailable.CategoryName = "Accessori"
        DemoProductCardUnavailable.PriceText = "29,90 €"
        DemoProductCardUnavailable.OldPriceText = ""
        DemoProductCardUnavailable.BadgeText = ""
        DemoProductCardUnavailable.IsOnSale = False
        DemoProductCardUnavailable.IsAvailable = False
        DemoProductCardUnavailable.AvailabilityText = ""
        DemoProductCardUnavailable.IsDemoMode = True
    End Sub
End Class
