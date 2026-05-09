Imports System.Collections.Generic

Public Interface IProductDetailView
    Property ProductName As String
    Property ProductCode As String
    Property MainImageUrl As String
    Property BrandName As String
    Property CategoryName As String
    Property PriceHtml As String
    Property OldPriceText As String
    Property IvaLabel As String
    Property IsPromo As Boolean
    Property AvailabilityHtml As String
    Property TCId As Integer
    Property ShortDescriptionHtml As String
    Property IsRefurbished As Boolean
    Property RefurbishedText As String
    Property ProductUrl As String
    Property AddToCartEnabled As Boolean
    Property ShowVariants As Boolean
    Property SelectedVariantTCId As Integer
    Property GalleryImageUrls As IEnumerable(Of String)
End Interface
