Imports System
Imports System.Globalization
Imports System.Web

Partial Class Public_ui_controls_ProductDetailView
    Inherits System.Web.UI.UserControl

    Public Property ProductName As String
    Public Property ProductCode As String
    Public Property PriceHtml As String
    Public Property AvailabilityHtml As String
    Public Property TCId As Integer
    Public Property ShortDescriptionHtml As String
    Public Property MainImageUrl As String
    Public Property BrandName As String
    Public Property CategoryName As String
    Public Property OldPriceText As String
    Public Property IvaLabel As String
    Public Property IsPromo As Boolean
    Public Property IsRefurbished As Boolean
    Public Property RefurbishedText As String
    Public Property ProductUrl As String
    Public Property AddToCartEnabled As Boolean
    Public Property ShowVariants As Boolean
    Public Property SelectedVariantTCId As Integer

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        phMainImage.Visible = Not String.IsNullOrWhiteSpace(MainImageUrl)
        If phMainImage.Visible Then
            imgMain.ImageUrl = MainImageUrl
            imgMain.AlternateText = If(String.IsNullOrWhiteSpace(ProductName), "Prodotto", ProductName)
        End If

        litProductName.Text = HttpUtility.HtmlEncode(If(ProductName, String.Empty))
        litProductCode.Text = HttpUtility.HtmlEncode(If(ProductCode, String.Empty))
        litBrandName.Text = HttpUtility.HtmlEncode(If(BrandName, String.Empty))
        phBrand.Visible = Not String.IsNullOrWhiteSpace(BrandName)
        litCategoryName.Text = HttpUtility.HtmlEncode(If(CategoryName, String.Empty))
        phCategory.Visible = Not String.IsNullOrWhiteSpace(CategoryName)
        litPrice.Text = If(PriceHtml, String.Empty)
        litOldPrice.Text = HttpUtility.HtmlEncode(If(OldPriceText, String.Empty))
        phOldPrice.Visible = Not String.IsNullOrWhiteSpace(OldPriceText)
        litPromo.Text = If(IsPromo, "attiva", String.Empty)
        phPromo.Visible = IsPromo
        litIvaLabel.Text = HttpUtility.HtmlEncode(If(IvaLabel, String.Empty))
        phIva.Visible = Not String.IsNullOrWhiteSpace(IvaLabel)
        litAvailability.Text = If(AvailabilityHtml, String.Empty)
        litRefurbished.Text = HttpUtility.HtmlEncode(If(RefurbishedText, "Articolo ricondizionato"))
        phRefurbished.Visible = IsRefurbished OrElse Not String.IsNullOrWhiteSpace(RefurbishedText)
        litVariants.Text = HttpUtility.HtmlEncode(BuildVariantText())
        litAddToCartStatus.Text = HttpUtility.HtmlEncode(BuildAddToCartText())
        litProductUrl.Text = HttpUtility.HtmlEncode(If(ProductUrl, String.Empty))
        phProductUrl.Visible = Not String.IsNullOrWhiteSpace(ProductUrl)
        litTCId.Text = HttpUtility.HtmlEncode(TCId.ToString(CultureInfo.InvariantCulture))
        litShortDescription.Text = If(ShortDescriptionHtml, String.Empty)
    End Sub

    Private Function BuildVariantText() As String
        If ShowVariants Then
            Return "abilitate, TCId selezionato " & SelectedVariantTCId.ToString(CultureInfo.InvariantCulture)
        End If

        Return "non abilitate"
    End Function

    Private Function BuildAddToCartText() As String
        If AddToCartEnabled Then
            Return "demo non operativo, flusso reale disponibile nella scheda esistente"
        End If

        Return "demo non operativo"
    End Function
End Class
