Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web

Partial Class Public_ui_controls_ProductDetailView
    Inherits System.Web.UI.UserControl
    Implements IProductDetailView

    Private _productName As String = String.Empty
    Private _productCode As String = String.Empty
    Private _ean As String = String.Empty
    Private _priceHtml As String = String.Empty
    Private _availabilityHtml As String = String.Empty
    Private _ivaLabel As String = String.Empty
    Private _longDescriptionHtml As String = String.Empty
    Private _addToCartEnabled As Boolean = False
    Private _showVariants As Boolean = False

    Public Property ArticleId As Integer Implements IProductDetailView.ArticleId

    Public Property ProductName As String Implements IProductDetailView.ProductName
        Get
            Return _productName
        End Get
        Set(value As String)
            _productName = If(value, String.Empty)
        End Set
    End Property

    Public Property ProductCode As String Implements IProductDetailView.ProductCode
        Get
            Return _productCode
        End Get
        Set(value As String)
            _productCode = If(value, String.Empty)
        End Set
    End Property

    Public Property Ean As String Implements IProductDetailView.Ean
        Get
            Return _ean
        End Get
        Set(value As String)
            _ean = If(value, String.Empty)
        End Set
    End Property

    Public Property PriceHtml As String Implements IProductDetailView.PriceHtml
        Get
            Return _priceHtml
        End Get
        Set(value As String)
            _priceHtml = If(value, String.Empty)
        End Set
    End Property

    Public Property CurrentPriceText As String Implements IProductDetailView.CurrentPriceText

    Public Property AvailabilityHtml As String Implements IProductDetailView.AvailabilityHtml
        Get
            Return _availabilityHtml
        End Get
        Set(value As String)
            _availabilityHtml = If(value, String.Empty)
        End Set
    End Property

    Public Property AvailabilityText As String Implements IProductDetailView.AvailabilityText
    Public Property AvailabilityCssClass As String Implements IProductDetailView.AvailabilityCssClass
    Public Property IsAvailable As Boolean Implements IProductDetailView.IsAvailable
    Public Property TCId As Integer Implements IProductDetailView.TCId
    Public Property ShortDescriptionHtml As String Implements IProductDetailView.ShortDescriptionHtml

    Public Property LongDescriptionHtml As String Implements IProductDetailView.LongDescriptionHtml
        Get
            Return _longDescriptionHtml
        End Get
        Set(value As String)
            _longDescriptionHtml = If(value, String.Empty)
        End Set
    End Property

    Public Property DescriptionHtml As String Implements IProductDetailView.DescriptionHtml
        Get
            Return _longDescriptionHtml
        End Get
        Set(value As String)
            _longDescriptionHtml = If(value, String.Empty)
        End Set
    End Property

    Public Property TechnicalInfoHtml As String Implements IProductDetailView.TechnicalInfoHtml
    Public Property MainImageUrl As String Implements IProductDetailView.MainImageUrl
    Public Property PlaceholderImageUrl As String Implements IProductDetailView.PlaceholderImageUrl
    Public Property BrandName As String Implements IProductDetailView.BrandName
    Public Property CategoryName As String Implements IProductDetailView.CategoryName
    Public Property OldPriceText As String Implements IProductDetailView.OldPriceText

    Public Property IvaLabel As String Implements IProductDetailView.IvaLabel
        Get
            Return _ivaLabel
        End Get
        Set(value As String)
            _ivaLabel = If(value, String.Empty)
        End Set
    End Property

    Public Property VatText As String Implements IProductDetailView.VatText
        Get
            Return _ivaLabel
        End Get
        Set(value As String)
            _ivaLabel = If(value, String.Empty)
        End Set
    End Property

    Public Property IsPromo As Boolean Implements IProductDetailView.IsPromo
    Public Property PromoText As String Implements IProductDetailView.PromoText
    Public Property IsRefurbished As Boolean Implements IProductDetailView.IsRefurbished
    Public Property RefurbishedText As String Implements IProductDetailView.RefurbishedText
    Public Property RefurbishedBadgeUrl As String Implements IProductDetailView.RefurbishedBadgeUrl
    Public Property ProductUrl As String Implements IProductDetailView.ProductUrl
    Public Property QuantityText As String Implements IProductDetailView.QuantityText

    Public Property AddToCartEnabled As Boolean Implements IProductDetailView.AddToCartEnabled
        Get
            Return _addToCartEnabled
        End Get
        Set(value As Boolean)
            _addToCartEnabled = value
        End Set
    End Property

    Public Property CanAddToCart As Boolean Implements IProductDetailView.CanAddToCart
        Get
            Return _addToCartEnabled
        End Get
        Set(value As Boolean)
            _addToCartEnabled = value
        End Set
    End Property

    Public Property AddToCartPlaceholderText As String Implements IProductDetailView.AddToCartPlaceholderText

    Public Property ShowVariants As Boolean Implements IProductDetailView.ShowVariants
        Get
            Return _showVariants
        End Get
        Set(value As Boolean)
            _showVariants = value
        End Set
    End Property

    Public Property HasVariants As Boolean Implements IProductDetailView.HasVariants
        Get
            Return _showVariants
        End Get
        Set(value As Boolean)
            _showVariants = value
        End Set
    End Property

    Public Property SelectedVariantTCId As Integer Implements IProductDetailView.SelectedVariantTCId
    Public Property VariantSummaryText As String Implements IProductDetailView.VariantSummaryText
    Public Property ReviewsSummaryText As String Implements IProductDetailView.ReviewsSummaryText
    Public Property RelatedProductsTitle As String Implements IProductDetailView.RelatedProductsTitle
    Public Property HasRelatedProducts As Boolean Implements IProductDetailView.HasRelatedProducts
    Public Property HasRecentProducts As Boolean Implements IProductDetailView.HasRecentProducts
    Public Property SeoTitle As String Implements IProductDetailView.SeoTitle
    Public Property SeoMetaDescription As String Implements IProductDetailView.SeoMetaDescription
    Public Property CanonicalUrl As String Implements IProductDetailView.CanonicalUrl
    Public Property OpenGraphImageUrl As String Implements IProductDetailView.OpenGraphImageUrl
    Public Property JsonLdHtml As String Implements IProductDetailView.JsonLdHtml
    Public Property GalleryDomId As String Implements IProductDetailView.GalleryDomId
    Public Property GalleryThumbsDomId As String Implements IProductDetailView.GalleryThumbsDomId
    Public Property SupportsSwiperGallery As Boolean Implements IProductDetailView.SupportsSwiperGallery
    Public Property SupportsPhotoSwipe As Boolean Implements IProductDetailView.SupportsPhotoSwipe
    Public Property SupportsDriftZoom As Boolean Implements IProductDetailView.SupportsDriftZoom
    Public Property SupportsQuantityStepper As Boolean Implements IProductDetailView.SupportsQuantityStepper

    Private _galleryImageUrls As New List(Of String)()

    Public Property GalleryImageUrls As IEnumerable(Of String) Implements IProductDetailView.GalleryImageUrls
        Get
            Return _galleryImageUrls
        End Get
        Set(value As IEnumerable(Of String))
            _galleryImageUrls = New List(Of String)()
            If value Is Nothing Then Return

            Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
            For Each imageUrl As String In value
                Dim safeUrl As String = If(imageUrl, String.Empty).Trim()
                If safeUrl.Length = 0 Then Continue For
                If seen.Add(safeUrl) Then _galleryImageUrls.Add(safeUrl)
            Next
        End Set
    End Property

    Public Sub New()
        RefurbishedBadgeUrl = "/Public/assets/images/img/refurbished.png"
        AvailabilityCssClass = String.Empty
        AddToCartPlaceholderText = "demo non operativo"
        RelatedProductsTitle = String.Empty
        GalleryDomId = String.Empty
        GalleryThumbsDomId = String.Empty
    End Sub

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        phMainImage.Visible = Not String.IsNullOrWhiteSpace(MainImageUrl)
        If phMainImage.Visible Then
            imgMain.ImageUrl = MainImageUrl
            imgMain.AlternateText = If(String.IsNullOrWhiteSpace(ProductName), "Prodotto", ProductName)
        End If

        phDemoGallery.Visible = (_galleryImageUrls.Count > 0)
        If phDemoGallery.Visible Then
            rptDemoGalleryImages.DataSource = _galleryImageUrls
            rptDemoGalleryImages.DataBind()
        End If

        litProductName.Text = HttpUtility.HtmlEncode(If(ProductName, String.Empty))
        litProductCode.Text = HttpUtility.HtmlEncode(If(ProductCode, String.Empty))
        litEan.Text = HttpUtility.HtmlEncode(If(Ean, String.Empty))
        phEan.Visible = Not String.IsNullOrWhiteSpace(Ean)
        litBrandName.Text = HttpUtility.HtmlEncode(If(BrandName, String.Empty))
        phBrand.Visible = Not String.IsNullOrWhiteSpace(BrandName)
        litCategoryName.Text = HttpUtility.HtmlEncode(If(CategoryName, String.Empty))
        phCategory.Visible = Not String.IsNullOrWhiteSpace(CategoryName)
        litPrice.Text = FirstNonEmpty(PriceHtml, HttpUtility.HtmlEncode(CurrentPriceText))
        litOldPrice.Text = HttpUtility.HtmlEncode(If(OldPriceText, String.Empty))
        phOldPrice.Visible = Not String.IsNullOrWhiteSpace(OldPriceText)
        litPromo.Text = HttpUtility.HtmlEncode(FirstNonEmpty(PromoText, If(IsPromo, "attiva", String.Empty)))
        phPromo.Visible = IsPromo
        litIvaLabel.Text = HttpUtility.HtmlEncode(If(IvaLabel, String.Empty))
        phIva.Visible = Not String.IsNullOrWhiteSpace(IvaLabel)
        litAvailability.Text = FirstNonEmpty(AvailabilityHtml, HttpUtility.HtmlEncode(AvailabilityText))
        litRefurbished.Text = HttpUtility.HtmlEncode(If(RefurbishedText, "Articolo ricondizionato"))
        phRefurbished.Visible = IsRefurbished OrElse Not String.IsNullOrWhiteSpace(RefurbishedText)
        litQuantity.Text = HttpUtility.HtmlEncode(BuildQuantityText())
        litVariants.Text = HttpUtility.HtmlEncode(BuildVariantText())
        litAddToCartStatus.Text = HttpUtility.HtmlEncode(BuildAddToCartText())
        litProductUrl.Text = HttpUtility.HtmlEncode(If(ProductUrl, String.Empty))
        phProductUrl.Visible = Not String.IsNullOrWhiteSpace(ProductUrl)
        litTCId.Text = HttpUtility.HtmlEncode(TCId.ToString(CultureInfo.InvariantCulture))
        litShortDescription.Text = If(ShortDescriptionHtml, String.Empty)
        phShortDescription.Visible = Not String.IsNullOrWhiteSpace(ShortDescriptionHtml)
        litLongDescription.Text = FirstNonEmpty(LongDescriptionHtml, DescriptionHtml)
        phLongDescription.Visible = Not String.IsNullOrWhiteSpace(litLongDescription.Text)
        litInfoProductCode.Text = HttpUtility.HtmlEncode(If(ProductCode, String.Empty))
        litInfoEan.Text = HttpUtility.HtmlEncode(If(Ean, String.Empty))
        phInfoEan.Visible = Not String.IsNullOrWhiteSpace(Ean)
        litInfoBrandName.Text = HttpUtility.HtmlEncode(If(BrandName, String.Empty))
        phInfoBrand.Visible = Not String.IsNullOrWhiteSpace(BrandName)
        litInfoCategoryName.Text = HttpUtility.HtmlEncode(If(CategoryName, String.Empty))
        phInfoCategory.Visible = Not String.IsNullOrWhiteSpace(CategoryName)
        litInfoTCId.Text = HttpUtility.HtmlEncode(TCId.ToString(CultureInfo.InvariantCulture))
        litInfoVariants.Text = HttpUtility.HtmlEncode(BuildVariantText())
    End Sub

    Private Function BuildVariantText() As String
        If Not String.IsNullOrWhiteSpace(VariantSummaryText) Then
            Return VariantSummaryText.Trim()
        End If

        If ShowVariants Then
            Return "abilitate, TCId selezionato " & SelectedVariantTCId.ToString(CultureInfo.InvariantCulture)
        End If

        Return "non abilitate"
    End Function

    Private Function BuildAddToCartText() As String
        If Not String.IsNullOrWhiteSpace(AddToCartPlaceholderText) Then
            Return AddToCartPlaceholderText.Trim()
        End If

        If AddToCartEnabled Then
            Return "demo non operativo, flusso reale disponibile nella scheda esistente"
        End If

        Return "demo non operativo"
    End Function

    Private Function BuildQuantityText() As String
        If Not String.IsNullOrWhiteSpace(QuantityText) Then
            Return QuantityText.Trim()
        End If

        Return "1"
    End Function

    Private Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then Return String.Empty
        For Each value As String In values
            If Not String.IsNullOrWhiteSpace(value) Then Return value
        Next
        Return String.Empty
    End Function
End Class
