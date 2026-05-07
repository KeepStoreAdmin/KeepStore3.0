Partial Class Public_ui_controls_ProductCard
    Inherits System.Web.UI.UserControl

    Public Property ProductId As Integer
    Public Property TCId As Integer
    Public Property ProductName As String
    Public Property ProductCode As String
    Public Property ProductUrl As String
    Public Property ImageUrl As String
    Public Property HoverImageUrl As String
    Public Property BrandName As String
    Public Property CategoryName As String
    Public Property PriceText As String
    Public Property OldPriceText As String
    Public Property BadgeText As String
    Public Property IsOnSale As Boolean
    Public Property IsAvailable As Boolean = True
    Public Property AvailabilityText As String
    Public Property IsDemoMode As Boolean = True
    Public Property CartUrl As String
    Public Property WishlistUrl As String
    Public Property QuickViewTarget As String
    Public Property CompareTarget As String
    Public Property DescriptionText As String
    Public Property AvailabilityCss As String
    Public Property IsRefurbished As Boolean
    Public Property RefurbishedText As String
    Public Property ShowQuickActions As Boolean = True
    Public Property ShowWishlist As Boolean = True
    Public Property ShowCompare As Boolean = True
    Public Property ShowQuickView As Boolean = True
    Public Property ShowAddToCart As Boolean = True
    Public Property ShowMultiSelect As Boolean
    Public Property EnableLegacyServerControls As Boolean = False
    Public Property QuantityText As String = "1"
    Public Property ActionDataAttributes As String

    Public ReadOnly Property SelectedForMultiAdd As Boolean
        Get
            Return EnableLegacyServerControls AndAlso CheckBox_SelezioneMultipla IsNot Nothing AndAlso CheckBox_SelezioneMultipla.Checked
        End Get
    End Property

    Public ReadOnly Property LegacyQuantityText As String
        Get
            If EnableLegacyServerControls AndAlso tbQuantita IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(tbQuantita.Text) Then
                Return NormalizeQuantityText(tbQuantita.Text)
            End If

            Return NormalizeQuantityText(QuantityText)
        End Get
    End Property

    Public ReadOnly Property LegacyProductId As Integer
        Get
            Dim id As Integer = ProductId
            If EnableLegacyServerControls AndAlso hfID IsNot Nothing Then Integer.TryParse(hfID.Value, id)
            Return id
        End Get
    End Property

    Public ReadOnly Property LegacyTCId As Integer
        Get
            Dim id As Integer = TCId
            If EnableLegacyServerControls AndAlso hfTCId IsNot Nothing Then Integer.TryParse(hfTCId.Value, id)
            Return id
        End Get
    End Property

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        phBadge.Visible = IsOnSale AndAlso Not String.IsNullOrWhiteSpace(BadgeText)
        phOldPrice.Visible = IsOnSale AndAlso Not String.IsNullOrWhiteSpace(OldPriceText)
        SyncLegacyServerControls()
    End Sub

    Protected ReadOnly Property ProductTitleClientId As String
        Get
            Return ClientID & "_ProductName"
        End Get
    End Property

    Protected ReadOnly Property SafeProductUrl As String
        Get
            Return CleanUrl(ProductUrl)
        End Get
    End Property

    Protected ReadOnly Property SafeImageUrl As String
        Get
            Return CleanUrl(If(String.IsNullOrWhiteSpace(ImageUrl), "/Public/assets/images/img/placeholder.svg", ImageUrl))
        End Get
    End Property

    Protected ReadOnly Property SafeHoverImageUrl As String
        Get
            Dim hover As String = HoverImageUrl
            If String.IsNullOrWhiteSpace(hover) Then hover = SafeImageUrl
            Return CleanUrl(hover)
        End Get
    End Property

    Protected ReadOnly Property SafeProductName As String
        Get
            Return EncodeText(If(String.IsNullOrWhiteSpace(ProductName), "Prodotto dimostrativo", ProductName))
        End Get
    End Property

    Protected ReadOnly Property SafeProductNameAttribute As String
        Get
            Return EncodeAttribute(If(String.IsNullOrWhiteSpace(ProductName), "Prodotto dimostrativo", ProductName))
        End Get
    End Property

    Protected ReadOnly Property SafeMetaText As String
        Get
            Dim parts As New List(Of String)()
            If Not String.IsNullOrWhiteSpace(CategoryName) Then parts.Add(CategoryName)
            If Not String.IsNullOrWhiteSpace(BrandName) Then parts.Add(BrandName)
            If parts.Count = 0 Then parts.Add("Categoria demo")
            Return EncodeText(String.Join(" - ", parts.ToArray()))
        End Get
    End Property

    Protected ReadOnly Property SafePriceText As String
        Get
            Return EncodeText(If(String.IsNullOrWhiteSpace(PriceText), "Prezzo demo", PriceText))
        End Get
    End Property

    Protected ReadOnly Property SafeOldPriceText As String
        Get
            Return EncodeText(OldPriceText)
        End Get
    End Property

    Protected ReadOnly Property SafeBadgeText As String
        Get
            Return EncodeText(If(String.IsNullOrWhiteSpace(BadgeText), "Promo", BadgeText))
        End Get
    End Property

    Protected ReadOnly Property SafeAvailabilityText As String
        Get
            If Not IsAvailable Then Return "Non disponibile"
            Return EncodeText(If(String.IsNullOrWhiteSpace(AvailabilityText), "Disponibile", AvailabilityText))
        End Get
    End Property

    Protected ReadOnly Property SafeProductCodeText As String
        Get
            If String.IsNullOrWhiteSpace(ProductCode) Then Return "Codice demo"
            Return EncodeText("Cod. " & ProductCode)
        End Get
    End Property

    Protected ReadOnly Property CartButtonText As String
        Get
            If IsDemoMode Then Return "Azione demo"
            Return "Aggiungi al carrello"
        End Get
    End Property

    Protected ReadOnly Property RenderQuickActions As Boolean
        Get
            Return ShowQuickActions AndAlso (ShowAddToCart OrElse ShowWishlist OrElse ShowQuickView OrElse ShowCompare)
        End Get
    End Property

    Protected ReadOnly Property RenderAddToCart As Boolean
        Get
            Return ShowAddToCart
        End Get
    End Property

    Protected ReadOnly Property RenderWishlist As Boolean
        Get
            Return ShowWishlist
        End Get
    End Property

    Protected ReadOnly Property RenderQuickView As Boolean
        Get
            Return ShowQuickView
        End Get
    End Property

    Protected ReadOnly Property RenderCompare As Boolean
        Get
            Return ShowCompare
        End Get
    End Property

    Protected ReadOnly Property SafeCartUrl As String
        Get
            If IsDemoMode Then Return "#"
            Return CleanUrl(CartUrl)
        End Get
    End Property

    Protected ReadOnly Property SafeWishlistUrl As String
        Get
            If IsDemoMode Then Return "#"
            Return CleanUrl(WishlistUrl)
        End Get
    End Property

    Protected ReadOnly Property SafeQuickViewTarget As String
        Get
            If IsDemoMode Then Return "#"
            Dim target As String = If(String.IsNullOrWhiteSpace(QuickViewTarget), "#quickView", QuickViewTarget)
            Return CleanUrl(target)
        End Get
    End Property

    Protected ReadOnly Property SafeCompareTarget As String
        Get
            If IsDemoMode Then Return "#"
            Dim target As String = If(String.IsNullOrWhiteSpace(CompareTarget), "#compare", CompareTarget)
            Return CleanUrl(target)
        End Get
    End Property

    Protected ReadOnly Property AddToCartActionClass As String
        Get
            Return "box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left" & If(IsDemoMode, "", " js-ks-cart-link")
        End Get
    End Property

    Protected ReadOnly Property WishlistActionClass As String
        Get
            Return "box-icon btn-icon-action hover-tooltip tooltip-left" & If(IsDemoMode, "", " js-ks-wishlist-link")
        End Get
    End Property

    Protected ReadOnly Property QuickViewActionClass As String
        Get
            Return "box-icon quickview btn-icon-action hover-tooltip tooltip-left" & If(IsDemoMode, "", " js-ks-quickview")
        End Get
    End Property

    Protected ReadOnly Property CompareActionClass As String
        Get
            Return "box-icon btn-icon-action hover-tooltip tooltip-left" & If(IsDemoMode, "", " js-ks-compare")
        End Get
    End Property

    Protected ReadOnly Property PrimaryButtonClass As String
        Get
            Return "tf-btn btn-line w-100" & If(IsDemoMode, "", " js-ks-cart-link")
        End Get
    End Property

    Protected ReadOnly Property QuickViewToggleAttribute As String
        Get
            If IsDemoMode Then Return ""
            Return " data-bs-toggle=""modal"""
        End Get
    End Property

    Protected ReadOnly Property CompareToggleAttribute As String
        Get
            If IsDemoMode Then Return ""
            Return " data-bs-toggle=""offcanvas"""
        End Get
    End Property

    Protected ReadOnly Property SafeActionDataAttributes As String
        Get
            If IsDemoMode OrElse String.IsNullOrWhiteSpace(ActionDataAttributes) Then Return ""
            Return " " & ActionDataAttributes.Trim()
        End Get
    End Property

    Protected ReadOnly Property SafeAvailabilityCss As String
        Get
            Dim css As String = If(AvailabilityCss, String.Empty)
            css = System.Text.RegularExpressions.Regex.Replace(css, "[^A-Za-z0-9_\- ]", String.Empty)
            Return EncodeAttribute(css.Trim())
        End Get
    End Property

    Protected ReadOnly Property SafeRefurbishedText As String
        Get
            Return EncodeText(If(String.IsNullOrWhiteSpace(RefurbishedText), "Ricondizionato", RefurbishedText))
        End Get
    End Property

    Protected ReadOnly Property SafeQuantityText As String
        Get
            Return NormalizeQuantityText(QuantityText)
        End Get
    End Property

    Private Sub SyncLegacyServerControls()
        phLegacyServerControls.Visible = EnableLegacyServerControls
        If Not EnableLegacyServerControls Then Exit Sub

        hfID.Value = ProductId.ToString()
        hfTCId.Value = TCId.ToString()
        tbQuantita.Text = NormalizeQuantityText(QuantityText)
    End Sub

    Private Function NormalizeQuantityText(ByVal value As String) As String
        Dim qta As Integer = 1
        If Not Integer.TryParse(Convert.ToString(value), qta) Then qta = 1
        If qta <= 0 Then qta = 1
        If qta > 9999 Then qta = 9999
        Return qta.ToString()
    End Function

    Private Function EncodeText(ByVal value As String) As String
        Return Server.HtmlEncode(If(value, String.Empty))
    End Function

    Private Function EncodeAttribute(ByVal value As String) As String
        Return Server.HtmlEncode(If(value, String.Empty))
    End Function

    Private Function CleanUrl(ByVal value As String) As String
        Dim url As String = If(value, String.Empty).Trim()
        If url = String.Empty Then Return "#"
        If url.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then Return "#"
        Return System.Web.HttpUtility.HtmlAttributeEncode(url)
    End Function
End Class
