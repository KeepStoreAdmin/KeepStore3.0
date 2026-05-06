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

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        phBadge.Visible = IsOnSale AndAlso Not String.IsNullOrWhiteSpace(BadgeText)
        phOldPrice.Visible = IsOnSale AndAlso Not String.IsNullOrWhiteSpace(OldPriceText)
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
            Return "Azione non attiva"
        End Get
    End Property

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
