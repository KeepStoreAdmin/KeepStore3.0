Imports System.Collections.Generic

Public Interface IProductDetailView
    Property ArticleId As Integer
    Property ProductName As String
    Property ProductCode As String
    Property Ean As String
    Property MainImageUrl As String
    Property PlaceholderImageUrl As String
    Property BrandName As String
    Property CategoryName As String
    Property PriceHtml As String
    Property CurrentPriceText As String
    Property OldPriceText As String
    Property IvaLabel As String
    Property VatText As String
    Property IsPromo As Boolean
    Property PromoText As String
    Property AvailabilityHtml As String
    Property AvailabilityText As String
    Property AvailabilityCssClass As String
    Property IsAvailable As Boolean
    Property TCId As Integer
    Property ShortDescriptionHtml As String
    Property LongDescriptionHtml As String
    Property DescriptionHtml As String
    Property TechnicalInfoHtml As String
    Property IsRefurbished As Boolean
    Property RefurbishedText As String
    Property RefurbishedBadgeUrl As String
    Property ProductUrl As String
    Property QuantityText As String
    Property AddToCartEnabled As Boolean
    Property CanAddToCart As Boolean
    Property AddToCartPlaceholderText As String
    Property ShowVariants As Boolean
    Property HasVariants As Boolean
    Property SelectedVariantTCId As Integer
    Property VariantSummaryText As String
    Property ReviewsSummaryText As String
    Property RelatedProductsTitle As String
    Property HasRelatedProducts As Boolean
    Property HasRecentProducts As Boolean
    Property SeoTitle As String
    Property SeoMetaDescription As String
    Property CanonicalUrl As String
    Property OpenGraphImageUrl As String
    Property JsonLdHtml As String
    Property GalleryDomId As String
    Property GalleryThumbsDomId As String
    Property SupportsSwiperGallery As Boolean
    Property SupportsPhotoSwipe As Boolean
    Property SupportsDriftZoom As Boolean
    Property SupportsQuantityStepper As Boolean
    Property GalleryImageUrls As IEnumerable(Of String)
End Interface
