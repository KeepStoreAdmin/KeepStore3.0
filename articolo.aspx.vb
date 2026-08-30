Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.UI.WebControls
Imports HtmlAgilityPack
Imports MySql.Data.MySqlClient

Partial Class articolo
    Inherits System.Web.UI.Page

    Private _id As Integer
    Private _tcid As Integer
    Private _tcidPresent As Boolean
    Private _listino As Integer
    Private _tcEnabled As Boolean
    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private Class ImgItem
        Public Property Url As String
        Public Property Alt As String
    End Class

    Private Class ProductDetailViewModel
        Public Property ProductId As Integer
        Public Property TCId As Integer
        Public Property ProductName As String
        Public Property ProductCode As String
        Public Property Ean As String
        Public Property BrandName As String
        Public Property CategoryName As String
        Public Property ProductUrl As String
        Public Property MainImageUrl As String
        Public Property PlaceholderImageUrl As String
        Public Property ShortDescriptionHtml As String
        Public Property LongDescriptionHtml As String
        Public Property TechnicalInfoHtml As String
        Public Property PriceHtml As String
        Public Property PriceText As String
        Public Property OldPriceText As String
        Public Property IvaLabel As String
        Public Property PromoText As String
        Public Property IsPromo As Boolean
        Public Property AvailabilityHtml As String
        Public Property AvailabilityText As String
        Public Property AvailabilityCss As String
        Public Property IsAvailable As Boolean
        Public Property IsRefurbished As Boolean
        Public Property RefurbishedText As String
        Public Property RefurbishedBadgeUrl As String
        Public Property QuantityText As String
        Public Property AddToCartEnabled As Boolean
        Public Property CanAddToCart As Boolean
        Public Property AddToCartPlaceholderText As String
        Public Property ShowVariants As Boolean
        Public Property HasVariants As Boolean
        Public Property SelectedVariantTCId As Integer
        Public Property VariantSummaryText As String
        Public Property ReviewsSummaryText As String
        Public Property RelatedProductsTitle As String
        Public Property HasRelatedProducts As Boolean
        Public Property HasRecentProducts As Boolean
        Public Property SeoTitle As String
        Public Property SeoMetaDescription As String
        Public Property CanonicalUrl As String
        Public Property OpenGraphImageUrl As String
        Public Property JsonLdHtml As String
        Public Property GalleryDomId As String
        Public Property GalleryThumbsDomId As String
        Public Property SupportsSwiperGallery As Boolean
        Public Property SupportsPhotoSwipe As Boolean
        Public Property SupportsDriftZoom As Boolean
        Public Property SupportsQuantityStepper As Boolean
        Public Property GalleryImageUrls As IEnumerable(Of String)
    End Class

    Private Class RelatedItem
        Public Property Id As Integer
        Public Property Tcid As Integer
        Public Property Nome As String
        Public Property Img As String
        Public Property ImgHover As String
        Public Property Url As String
        Public Property PrezzoHtml As String
        Public Property InOfferta As Boolean
        Public Property Codice As String
        Public Property Ean As String
        Public Property BrandName As String
        Public Property CategoryName As String
        Public Property CategoryId As Integer
        Public Property TipologiaId As Integer
        Public Property BrandId As Integer
        Public Property TagliaName As String
        Public Property ColoreName As String
        Public Property AvailabilityText As String
        Public Property PriceValue As Nullable(Of Decimal)
        Public Property IsCurrent As Boolean
        Public Property BusinessKey As String
        Public Property AddToCartUrl As String
        Public Property WishlistUrl As String
        Public Property QuickViewAttrs As String
        Public Property CompareAttrs As String
    End Class

    Private Class BrandItem
        Public Property Nome As String
        Public Property Url As String
        Public Property LogoHtml As String
    End Class

    Private Class ReviewItem
        Public Property Rating As Integer
        Public Property RatingText As String
        Public Property StarsHtml As String
        Public Property TitleText As String
        Public Property BodyText As String
        Public Property AuthorText As String
        Public Property DateText As String
        Public Property Verified As Boolean
    End Class

    Private Class PriceContext
        Public Property CurrentPrice As Nullable(Of Decimal)
        Public Property OldPrice As Nullable(Of Decimal)
        Public Property IsPromo As Boolean
        Public Property IvaLabel As String
    End Class

    Private Class VariantInfo
        Public Property Taglia As String
        Public Property Colore As String
        Public Property Descrizione As String
    End Class

    Private Class AffinityProfile
        Public Property CodeTokens As List(Of String)
        Public Property DescriptionTokens As List(Of String)
        Public Property BrandId As Integer
        Public Property CategoryId As Integer
        Public Property TipologiaId As Integer
        Public Property BrandName As String
        Public Property CategoryName As String
        Public Property TipologiaName As String
        Public Property Taglia As String
        Public Property Colore As String

        Public Sub New()
            CodeTokens = New List(Of String)()
            DescriptionTokens = New List(Of String)()
        End Sub
    End Class

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not TryParseParams() Then
            Return
        End If

        EnsureArticleCompanyContext()

        ' ==========================================================
        ' LISTINO: nel progetto è gestito principalmente tramite Session("Listino")
        ' (default anonimi = 1). Alcune parti legacy usano anche Session("listino").
        ' Se qui leggiamo 0, la query su vsuperarticoli (NListino=@nlistino) non
        ' ritorna righe e si ottiene "Articolo non trovato" con ID valido.
        ' ==========================================================
        _listino = GetCurrentListino()
        _tcEnabled = (GetSessionInt("TC", 0) = 1)

        If Not IsPostBack Then
            LoadPage()
        End If
    End Sub

    Private Function TryParseParams() As Boolean
        Dim idStr As String = Convert.ToString(Request.QueryString("id"))
        If Not Integer.TryParse(idStr, _id) OrElse _id <= 0 Then
            Response.Redirect("default.aspx", True)
            Return False
        End If

        _tcidPresent = (Request.QueryString("TCid") IsNot Nothing)
        If _tcidPresent Then
            Dim tmp As Integer
            ' Nel DB Taikun/KeepStore il "non variante" è storicamente TCid = -1.
            ' Il listing (articoli.aspx) costruisce link includendo sempre TCid; se qui
            ' rifiutiamo -1, generiamo redirect e (con listino errato) si arriva al "non trovato".
            If Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), tmp) AndAlso tmp >= -1 Then
                _tcid = tmp
            Else
                ' Parametro non valido -> pulisco URL
                Response.Redirect("articolo.aspx?id=" & _id.ToString(), True)
                Return False
            End If
        Else
            ' Coerenza col progetto: default TCid = -1
            _tcid = -1
        End If

        Return True
    End Function

    Private Function IsProductDetailDebugModeAllowed() As Boolean
        Try
            Dim context As System.Web.HttpContext = System.Web.HttpContext.Current
            If context Is Nothing OrElse context.Request Is Nothing Then Return False
            Return context.Request.IsLocal
        Catch
            Return False
        End Try
    End Function

    Private Function IsProductDetailPreviewEnabled() As Boolean
        If Not IsProductDetailDebugModeAllowed() Then Return False
        Return String.Equals(Convert.ToString(Request.QueryString("ksProductDetailPreview")), "1", StringComparison.Ordinal)
    End Function

    Private Sub LoadPage()
        Dim row As DataRow = GetProductRow(_id, _tcid, includeTcidFilter:=(_tcidPresent AndAlso _tcEnabled AndAlso _tcid > 0))

        ' Se TCid presente ma non esiste (vecchio link o variante rimossa), provo a caricare senza TCid e redirigo sulla variante di default
        If row Is Nothing AndAlso _tcEnabled AndAlso _tcidPresent Then
            Dim fallback As DataRow = GetProductRow(_id, -1, includeTcidFilter:=False)
            If fallback IsNot Nothing Then
                Dim defaultTcid As Integer = GetRowInt(fallback, "TCid", -1)
                Dim redirectUrl As String = BuildProductUrl(_id, defaultTcid, includeTcid:=True)
                Response.Redirect(redirectUrl, True)
                Return
            End If
        End If

        If row Is Nothing Then
            ShowNotFound()
            Return
        End If

        BindProduct(row)
        BindProductDetailPreview(row)
        TrackRecentlyViewed(_id)
        ApplySeo(row)
        BindProductReviews()
        BindProductRelations(row)
    End Sub

    Private Sub BindProductDetailPreview(row As DataRow)
        phProductDetailPreview.Controls.Clear()
        phProductDetailPreview.Visible = False

        If Not IsProductDetailPreviewEnabled() Then Return

        Dim previewModel As ProductDetailViewModel = BuildProductDetailViewModel(row)
        If previewModel Is Nothing Then Return

        Dim previewControl As System.Web.UI.Control = LoadControl("~/Public/ui/controls/ProductDetailView.ascx")
        Dim detailView As IProductDetailView = TryCast(previewControl, IProductDetailView)
        If detailView Is Nothing Then Return

        ConfigureProductDetailPreview(detailView, previewModel)
        phProductDetailPreview.Controls.Add(previewControl)
        phProductDetailPreview.Visible = True
    End Sub

    Private Sub ConfigureProductDetailPreview(detailView As IProductDetailView, previewModel As ProductDetailViewModel)
        If detailView Is Nothing OrElse previewModel Is Nothing Then Return

        detailView.ArticleId = previewModel.ProductId
        detailView.TCId = previewModel.TCId
        detailView.ProductName = previewModel.ProductName
        detailView.ProductCode = previewModel.ProductCode
        detailView.Ean = previewModel.Ean
        detailView.BrandName = previewModel.BrandName
        detailView.CategoryName = previewModel.CategoryName
        detailView.ProductUrl = previewModel.ProductUrl
        detailView.MainImageUrl = previewModel.MainImageUrl
        detailView.PlaceholderImageUrl = previewModel.PlaceholderImageUrl
        detailView.GalleryImageUrls = previewModel.GalleryImageUrls
        detailView.PriceHtml = previewModel.PriceHtml
        detailView.CurrentPriceText = previewModel.PriceText
        detailView.OldPriceText = previewModel.OldPriceText
        detailView.IvaLabel = previewModel.IvaLabel
        detailView.VatText = previewModel.IvaLabel
        detailView.IsPromo = previewModel.IsPromo
        detailView.PromoText = previewModel.PromoText
        detailView.AvailabilityHtml = previewModel.AvailabilityHtml
        detailView.AvailabilityText = previewModel.AvailabilityText
        detailView.AvailabilityCssClass = previewModel.AvailabilityCss
        detailView.IsAvailable = previewModel.IsAvailable
        detailView.QuantityText = previewModel.QuantityText
        detailView.AddToCartEnabled = previewModel.AddToCartEnabled
        detailView.CanAddToCart = previewModel.CanAddToCart
        detailView.AddToCartPlaceholderText = previewModel.AddToCartPlaceholderText
        detailView.ShowVariants = previewModel.ShowVariants
        detailView.HasVariants = previewModel.HasVariants
        detailView.SelectedVariantTCId = previewModel.SelectedVariantTCId
        detailView.VariantSummaryText = previewModel.VariantSummaryText
        detailView.IsRefurbished = previewModel.IsRefurbished
        detailView.RefurbishedText = previewModel.RefurbishedText
        detailView.RefurbishedBadgeUrl = previewModel.RefurbishedBadgeUrl
        detailView.ShortDescriptionHtml = previewModel.ShortDescriptionHtml
        detailView.LongDescriptionHtml = previewModel.LongDescriptionHtml
        detailView.DescriptionHtml = previewModel.LongDescriptionHtml
        detailView.TechnicalInfoHtml = previewModel.TechnicalInfoHtml
        detailView.ReviewsSummaryText = previewModel.ReviewsSummaryText
        detailView.RelatedProductsTitle = previewModel.RelatedProductsTitle
        detailView.HasRelatedProducts = previewModel.HasRelatedProducts
        detailView.HasRecentProducts = previewModel.HasRecentProducts
        detailView.SeoTitle = previewModel.SeoTitle
        detailView.SeoMetaDescription = previewModel.SeoMetaDescription
        detailView.CanonicalUrl = previewModel.CanonicalUrl
        detailView.OpenGraphImageUrl = previewModel.OpenGraphImageUrl
        detailView.JsonLdHtml = previewModel.JsonLdHtml
        detailView.GalleryDomId = previewModel.GalleryDomId
        detailView.GalleryThumbsDomId = previewModel.GalleryThumbsDomId
        detailView.SupportsSwiperGallery = previewModel.SupportsSwiperGallery
        detailView.SupportsPhotoSwipe = previewModel.SupportsPhotoSwipe
        detailView.SupportsDriftZoom = previewModel.SupportsDriftZoom
        detailView.SupportsQuantityStepper = previewModel.SupportsQuantityStepper
    End Sub

    Private Sub BindProductRelations(row As DataRow)
        Dim compatibleItems As List(Of RelatedItem) = LoadPairRelation("articoli_compatibili", "ArticoliCompatibiliId", 10)
        If compatibleItems.Count = 0 Then
            compatibleItems = LoadSmartRelationFallback(row, "compatibili", 10)
        End If

        Dim linkedItems As List(Of RelatedItem) = LoadPairRelation("articoli_collegati", "ArticoliCollegatiId", 10)
        If linkedItems.Count = 0 Then
            linkedItems = LoadSmartRelationFallback(row, "collegati", 10)
        End If

        Dim manualRelated As List(Of RelatedItem) = LoadManualRelated(10)
        Dim similarItems As List(Of RelatedItem) = LoadSimilarProducts(row, 10)
        Dim companionItems As List(Of RelatedItem) = LoadCompanionProducts(row, 10)

        BindBundleProducts(row, companionItems, compatibleItems, linkedItems, manualRelated, similarItems)

        BindProductCarousel(phSimilar, rptSimilar, similarItems)

        Dim relatedItems As New List(Of RelatedItem)()
        AddUniqueRelatedItems(relatedItems, manualRelated, 10)
        AddUniqueRelatedItems(relatedItems, linkedItems, 10)
        AddUniqueRelatedItems(relatedItems, compatibleItems, 10)
        AddUniqueRelatedItems(relatedItems, similarItems, 10)
        BindProductCarousel(phRelated, rptRelated, relatedItems)

        BindBrandCarousel(row)
        BindRecentlyViewed(row)
    End Sub

    Private Sub BindRelatedProducts(row As DataRow)
        ' Correlati "AI-like" basati solo su tabelle esistenti.
        ' Strategia:
        ' 1) stessa categoria (CategorieId)
        ' 2) stesso brand (MarcheId)
        ' Ordinamento: popolarità + disponibilità + offerta.
        Try
            Dim catId As Integer = GetRowInt(row, "CategorieId", 0)
            Dim marcaId As Integer = GetRowInt(row, "MarcheId", 0)

            Dim items As List(Of RelatedItem) = LoadManualRelated(8)
            If items.Count < 8 Then
                AddUniqueRelatedItems(items, LoadRelatedInternal(catId, marcaId, 8), 8)
            End If
            If items Is Nothing OrElse items.Count = 0 Then
                phRelated.Visible = False
                Return
            End If

            phRelated.Visible = True
            rptRelated.DataSource = items
            rptRelated.DataBind()
        Catch ex As Exception
            ' Non blocca la pagina prodotto se fallisce la sezione correlati
            phRelated.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindRelatedProducts (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub BindPairRelationSection(holder As PlaceHolder, repeater As Repeater, tableName As String, relationColumn As String, logLabel As String, currentRow As DataRow)
        Try
            Dim items As List(Of RelatedItem) = LoadPairRelation(tableName, relationColumn, 8)
            If (items Is Nothing OrElse items.Count = 0) AndAlso currentRow IsNot Nothing Then
                items = LoadSmartRelationFallback(currentRow, logLabel, 8)
            End If

            If items Is Nothing OrElse items.Count = 0 Then
                holder.Visible = False
                Return
            End If

            holder.Visible = True
            repeater.DataSource = items
            repeater.DataBind()
        Catch ex As Exception
            holder.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindPairRelationSection " & logLabel & " (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub BindBundleProducts(row As DataRow, companionItems As List(Of RelatedItem), compatibleItems As List(Of RelatedItem), linkedItems As List(Of RelatedItem), manualRelated As List(Of RelatedItem), similarItems As List(Of RelatedItem))
        Dim bundleItems As New List(Of RelatedItem)()
        Dim currentItem As RelatedItem = BuildCurrentRelatedItem(row)
        If currentItem IsNot Nothing Then
            bundleItems.Add(currentItem)
        End If

        AddUniqueRelatedItems(bundleItems, companionItems, 4)
        AddUniqueRelatedItems(bundleItems, compatibleItems, 3)
        AddUniqueRelatedItems(bundleItems, linkedItems, 3)
        AddUniqueRelatedItems(bundleItems, manualRelated, 3)
        AddUniqueRelatedItems(bundleItems, similarItems, 3)

        rptBundle.DataSource = bundleItems
        rptBundle.DataBind()

        phBundleEmpty.Visible = (bundleItems.Count <= 1)
        litBundleTotal.Text = Server.HtmlEncode(FormatBundleTotal(bundleItems))
        StoreBundleCartItems(bundleItems)
    End Sub

    Private Sub StoreBundleCartItems(items As List(Of RelatedItem))
        Dim cartItems As New ArrayList()
        If items IsNot Nothing Then
            For Each item As RelatedItem In items
                If item Is Nothing OrElse item.Id <= 0 Then Continue For
                Dim tcid As Integer = If(item.Tcid > 0, item.Tcid, -1)
                cartItems.Add(item.Id.ToString(CultureInfo.InvariantCulture) & "," &
                              tcid.ToString(CultureInfo.InvariantCulture) & ",1,0")
            Next
        End If
        Session("ks_product_bundle_cart_items") = cartItems
    End Sub

    Private Sub BindProductCarousel(holder As PlaceHolder, repeater As Repeater, items As List(Of RelatedItem))
        If items Is Nothing OrElse items.Count = 0 Then
            holder.Visible = False
            Return
        End If

        holder.Visible = True
        repeater.DataSource = items
        repeater.DataBind()
    End Sub

    Private Function BuildCurrentRelatedItem(row As DataRow) As RelatedItem
        If row Is Nothing Then Return Nothing

        Dim nameVal As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
        Dim imgVal As String = NormalizeImageUrl(GetRowString(row, "Img1"))
        If String.IsNullOrEmpty(imgVal) Then
            imgVal = ThemeManager.PlaceholderProductImageUrl()
        End If
        Dim imgHover As String = NormalizeImageUrl(GetRowString(row, "Img2"))
        If String.IsNullOrEmpty(imgHover) Then imgHover = imgVal

        Dim inOfferta As Integer = GetEffectiveInOfferta(row)
        Dim tcidVal As Integer = GetRowInt(row, "TCid", _tcid)
        Dim codiceVal As String = FirstNonEmpty(GetRowString(row, "Codice"), GetRowString(row, "SKU"))
        Dim eanVal As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))
        Dim brandName As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        Dim categoryName As String = BuildCategoryCaption(row)
        Dim variantInfo As VariantInfo = LoadVariantInfo(_id, tcidVal)
        Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                      GetRowDecimal(row, "PrezzoIvato"),
                                                      GetRowDecimal(row, "PrezzoPromo"),
                                                      GetRowDecimal(row, "PrezzoPromoIvato"),
                                                      inOfferta)

        Dim item As New RelatedItem() With {
            .Id = _id,
            .Tcid = tcidVal,
            .Nome = nameVal,
            .Img = imgVal,
            .ImgHover = imgHover,
            .Url = BuildProductUrl(_id, tcidVal, includeTcid:=(Request.QueryString("TCid") IsNot Nothing)),
            .PrezzoHtml = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo),
            .InOfferta = (inOfferta = 1),
            .Codice = codiceVal,
            .Ean = eanVal,
            .BrandName = brandName,
            .CategoryName = categoryName,
            .CategoryId = GetRowInt(row, "CategorieId", 0),
            .TipologiaId = GetRowInt(row, "TipologieId", 0),
            .BrandId = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0)),
            .TagliaName = If(variantInfo IsNot Nothing, variantInfo.Taglia, String.Empty),
            .ColoreName = If(variantInfo IsNot Nothing, variantInfo.Colore, String.Empty),
            .AvailabilityText = BuildAvailabilityText(row),
            .PriceValue = price.CurrentPrice,
            .IsCurrent = True
        }
        FinalizeRelatedItem(item)
        Return item
    End Function

    Private Function FormatBundleTotal(items As List(Of RelatedItem)) As String
        If items Is Nothing OrElse items.Count = 0 Then
            Return "Prezzo su richiesta"
        End If

        Dim total As Decimal = 0D
        Dim hasPrice As Boolean = False
        For Each it As RelatedItem In items
            If it IsNot Nothing AndAlso it.PriceValue.HasValue AndAlso it.PriceValue.Value > 0D Then
                total += it.PriceValue.Value
                hasPrice = True
            End If
        Next

        If Not hasPrice Then Return "Prezzo su richiesta"
        Return FormatMoney(total)
    End Function

    Private Sub AddUniqueRelatedItems(target As List(Of RelatedItem), source As List(Of RelatedItem), maxItems As Integer)
        If target Is Nothing OrElse source Is Nothing Then Exit Sub

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each it As RelatedItem In target
            Dim key As String = RelatedBusinessKey(it)
            If Not String.IsNullOrEmpty(key) Then seen.Add(key)
        Next

        For Each it As RelatedItem In source
            If target.Count >= maxItems Then Exit For
            If it Is Nothing OrElse it.Id <= 0 Then Continue For
            Dim key As String = RelatedBusinessKey(it)
            If String.IsNullOrEmpty(key) OrElse seen.Contains(key) Then Continue For
            target.Add(it)
            seen.Add(key)
        Next
    End Sub

    Private Function LoadManualRelated(maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = RelatedSelectSql("articoli_correlati rel JOIN vsuperarticoli v ON v.id = rel.ArticoloFiglioId",
                                                   "WHERE v.NListino=?n AND rel.ArticoloPadreId=?idParent AND rel.ArticoloFiglioId<>?idChild AND rel.ArticoloFiglioId>0 " &
                                                   "ORDER BY rel.id ASC, v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                   "LIMIT " & SafeLimit(maxItems * 2))
                cmd.Parameters.AddWithValue("?n", _listino)
                cmd.Parameters.AddWithValue("?idParent", _id)
                cmd.Parameters.AddWithValue("?idChild", _id)
                AppendRelated(cmd, results, maxItems)
            End Using
        End Using

        Return results
    End Function

    Private Function LoadPairRelation(tableName As String, relationColumn As String, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()

        If Not ((tableName = "articoli_compatibili" AndAlso relationColumn = "ArticoliCompatibiliId") OrElse
                (tableName = "articoli_collegati" AndAlso relationColumn = "ArticoliCollegatiId")) Then
            Return results
        End If

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                Dim joinSql As String = tableName & " rel JOIN vsuperarticoli v ON v.id = CASE WHEN rel.ArticoliId=?idJoin THEN rel." & relationColumn & " ELSE rel.ArticoliId END"
                Dim whereSql As String = "WHERE v.NListino=?n AND (rel.ArticoliId=?idA OR rel." & relationColumn & "=?idB) AND v.id<>?idCurrent " &
                                         "ORDER BY rel.id ASC, v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                         "LIMIT " & SafeLimit(maxItems * 2)
                cmd.CommandText = RelatedSelectSql(joinSql, whereSql)
                cmd.Parameters.AddWithValue("?idJoin", _id)
                cmd.Parameters.AddWithValue("?n", _listino)
                cmd.Parameters.AddWithValue("?idA", _id)
                cmd.Parameters.AddWithValue("?idB", _id)
                cmd.Parameters.AddWithValue("?idCurrent", _id)
                AppendRelated(cmd, results, maxItems)
            End Using
        End Using

        Return results
    End Function

    Private Function RelatedSelectSql(fromSql As String, tailSql As String) As String
        Return "SELECT v.id, v.TCid, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, v.Img1, v.Img2, v.InOfferta, " &
               "v.CategorieId, v.TipologieId, v.MarcheId, " &
               "v.SettoriDescrizione, v.CategorieDescrizione, v.TipologieDescrizione, v.MarcheDescrizione, " &
               "v.Prezzo, v.PrezzoIvato, v.PrezzoPromo, v.PrezzoPromoIvato, " &
               "v.Giacenza, v.Impegnata, v.Disponibilita, v.InOrdine, " &
               "IFNULL(tg.Descrizione,'') AS TCTaglia, IFNULL(cl.Descrizione,'') AS TCColore, " &
               "TRIM(CONCAT(IFNULL(tg.Descrizione,''), ' ', IFNULL(cl.Descrizione,''), ' ', IFNULL(atc.Barcode,''))) AS TCDescrizione " &
               "FROM " & fromSql & " " &
               "LEFT JOIN articoli_tagliecolori atc ON atc.id=v.TCid " &
               "LEFT JOIN taglie tg ON tg.id=atc.TagliaId " &
               "LEFT JOIN colori cl ON cl.id=atc.ColoreId " & tailSql
    End Function

    Private Function SafeLimit(value As Integer) As String
        If value <= 0 Then value = 8
        If value > 24 Then value = 24
        Return value.ToString()
    End Function

    Private Function LoadRelatedInternal(catId As Integer, marcaId As Integer, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()

            ' 1) stessa categoria
            If catId > 0 Then
                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                       "WHERE v.NListino=?n AND v.id<>?id AND v.CategorieId=?cat " &
                                                       "ORDER BY v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                       "LIMIT " & SafeLimit(maxItems))
                    cmd.Parameters.AddWithValue("?n", _listino)
                    cmd.Parameters.AddWithValue("?id", _id)
                    cmd.Parameters.AddWithValue("?cat", catId)
                    AppendRelated(cmd, results, maxItems)
                End Using
            End If

            ' 2) stessa marca (integrazione se non basta)
            If (results.Count < maxItems) AndAlso (marcaId > 0) Then
                Using cmd2 As New MySqlCommand()
                    cmd2.Connection = conn
                    cmd2.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                        "WHERE v.NListino=?n AND v.id<>?id AND v.MarcheId=?mr " &
                                                        "ORDER BY v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                        "LIMIT " & SafeLimit(maxItems))
                    cmd2.Parameters.AddWithValue("?n", _listino)
                    cmd2.Parameters.AddWithValue("?id", _id)
                    cmd2.Parameters.AddWithValue("?mr", marcaId)
                    AppendRelated(cmd2, results, maxItems)
                End Using
            End If
        End Using

        Return results
    End Function

    Private Function LoadSimilarProducts(row As DataRow, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        If row Is Nothing Then Return results

        Dim catId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tipologiaId As Integer = GetRowInt(row, "TipologieId", 0)
        Dim marcaId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                If catId > 0 Then
                    Using cmdCat As New MySqlCommand()
                        cmdCat.Connection = conn
                        cmdCat.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                              "WHERE v.NListino=?n AND v.id<>?id AND v.CategorieId=?cat " &
                                                              "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                              "LIMIT " & SafeLimit(maxItems))
                        cmdCat.Parameters.AddWithValue("?n", _listino)
                        cmdCat.Parameters.AddWithValue("?id", _id)
                        cmdCat.Parameters.AddWithValue("?cat", catId)
                        AppendRelated(cmdCat, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso tipologiaId > 0 Then
                    Using cmdTp As New MySqlCommand()
                        cmdTp.Connection = conn
                        cmdTp.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                             "WHERE v.NListino=?n AND v.id<>?id AND v.TipologieId=?tp " &
                                                             "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                             "LIMIT " & SafeLimit(maxItems))
                        cmdTp.Parameters.AddWithValue("?n", _listino)
                        cmdTp.Parameters.AddWithValue("?id", _id)
                        cmdTp.Parameters.AddWithValue("?tp", tipologiaId)
                        AppendRelated(cmdTp, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso marcaId > 0 Then
                    Using cmdBrand As New MySqlCommand()
                        cmdBrand.Connection = conn
                        cmdBrand.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                                "WHERE v.NListino=?n AND v.id<>?id AND v.MarcheId=?mr " &
                                                                "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                                "LIMIT " & SafeLimit(maxItems))
                        cmdBrand.Parameters.AddWithValue("?n", _listino)
                        cmdBrand.Parameters.AddWithValue("?id", _id)
                        cmdBrand.Parameters.AddWithValue("?mr", marcaId)
                        AppendRelated(cmdBrand, results, maxItems)
                    End Using
                End If
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore LoadSimilarProducts (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try

        Return results
    End Function

    Private Function LoadCompanionProducts(row As DataRow, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        If row Is Nothing OrElse maxItems <= 0 Then Return results

        Dim profile As AffinityProfile = BuildAffinityProfile(row)
        Dim candidateLimit As Integer = Math.Max(maxItems * 5, 20)

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                ' Ordine richiesto: codice, descrizione, marca, categoria, tipologia, taglia TC, colore TC.
                AddCompanionCandidates(conn, results, profile, "code", candidateLimit)
                AddCompanionCandidates(conn, results, profile, "description", candidateLimit)

                If results.Count < candidateLimit Then AddCompanionCandidates(conn, results, profile, "brand", candidateLimit)
                If results.Count < candidateLimit Then AddCompanionCandidates(conn, results, profile, "category", candidateLimit)
                If results.Count < candidateLimit Then AddCompanionCandidates(conn, results, profile, "tipologia", candidateLimit)
                If results.Count < candidateLimit Then AddCompanionCandidates(conn, results, profile, "taglia", candidateLimit)
                If results.Count < candidateLimit Then AddCompanionCandidates(conn, results, profile, "colore", candidateLimit)
            End Using

            results.Sort(Function(a As RelatedItem, b As RelatedItem)
                             Dim scoreA As Integer = ScoreCompanion(profile, a)
                             Dim scoreB As Integer = ScoreCompanion(profile, b)
                             Dim cmp As Integer = scoreB.CompareTo(scoreA)
                             If cmp <> 0 Then Return cmp
                             Dim distanceA As Integer = Math.Abs(a.Id - _id)
                             Dim distanceB As Integer = Math.Abs(b.Id - _id)
                             cmp = distanceA.CompareTo(distanceB)
                             If cmp <> 0 Then Return cmp
                             Return StringComparer.OrdinalIgnoreCase.Compare(a.Nome, b.Nome)
                         End Function)

            Dim filtered As New List(Of RelatedItem)()
            Dim seenFiltered As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
            For Each item As RelatedItem In results
                If filtered.Count >= maxItems Then Exit For
                If ScoreCompanion(profile, item) <= 0 Then Continue For
                Dim key As String = RelatedBusinessKey(item)
                If String.IsNullOrEmpty(key) OrElse seenFiltered.Contains(key) Then Continue For
                filtered.Add(item)
                seenFiltered.Add(key)
            Next
            Return filtered
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore LoadCompanionProducts (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try

        Return results
    End Function

    Private Function BuildAffinityProfile(row As DataRow) As AffinityProfile
        Dim profile As New AffinityProfile()
        If row Is Nothing Then Return profile

        profile.BrandId = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))
        profile.CategoryId = GetRowInt(row, "CategorieId", 0)
        profile.TipologiaId = GetRowInt(row, "TipologieId", 0)
        profile.BrandName = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        profile.CategoryName = FirstNonEmpty(GetRowString(row, "CategorieDescrizione"), GetRowString(row, "SettoriDescrizione"))
        profile.TipologiaName = GetRowString(row, "TipologieDescrizione")

        Dim variantInfo As VariantInfo = LoadVariantInfo(_id, GetRowInt(row, "TCid", _tcid))
        If variantInfo IsNot Nothing Then
            profile.Taglia = variantInfo.Taglia
            profile.Colore = variantInfo.Colore
        End If

        Dim codeSeen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        AddCodeAffinityTokens(profile.CodeTokens, codeSeen, GetRowString(row, "Codice"))
        AddCodeAffinityTokens(profile.CodeTokens, codeSeen, GetRowString(row, "Ean"))

        Dim textSeen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim descriptionText As String = String.Join(" ", New String() {
            GetRowString(row, "Descrizione1"),
            GetRowString(row, "Descrizione2"),
            GetRowString(row, "DescrizioneLunga"),
            GetRowString(row, "DescrizioneHTML")
        })
        AddDescriptionAffinityTokens(profile.DescriptionTokens, textSeen, descriptionText)

        If String.IsNullOrWhiteSpace(profile.Colore) Then
            profile.Colore = ExtractColorKey(NormalizeAffinityText(descriptionText & " " & GetRowString(row, "Codice")))
        End If

        Return profile
    End Function

    Private Sub AddCompanionCandidates(conn As MySqlConnection,
                                       results As List(Of RelatedItem),
                                       profile As AffinityProfile,
                                       mode As String,
                                       candidateLimit As Integer)
        If conn Is Nothing OrElse results Is Nothing OrElse profile Is Nothing Then Exit Sub

        Using cmd As New MySqlCommand()
            cmd.Connection = conn
            Dim whereClause As String = BuildCompanionWhere(cmd, profile, mode)
            If String.IsNullOrWhiteSpace(whereClause) Then Exit Sub

            cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                               "WHERE v.NListino=?n AND NOT (v.id=?id AND v.TCid=?currentTcid) AND (" & whereClause & ") " &
                                               "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                               "LIMIT " & SafeLimit(candidateLimit))
            cmd.Parameters.AddWithValue("?n", _listino)
            cmd.Parameters.AddWithValue("?id", _id)
            cmd.Parameters.AddWithValue("?currentTcid", _tcid)
            AppendRelated(cmd, results, candidateLimit)
        End Using
    End Sub

    Private Function BuildCompanionWhere(cmd As MySqlCommand, profile As AffinityProfile, mode As String) As String
        Select Case (If(mode, String.Empty).ToLowerInvariant())
            Case "code"
                Return BuildTokenWhere(cmd, profile.CodeTokens, "cd", True, True, False)
            Case "description"
                Return BuildTokenWhere(cmd, profile.DescriptionTokens, "ds", True, True, True)
            Case "brand"
                If profile.BrandId <= 0 Then Return ""
                cmd.Parameters.AddWithValue("?brand", profile.BrandId)
                Return "v.MarcheId=?brand"
            Case "category"
                If profile.CategoryId <= 0 Then Return ""
                cmd.Parameters.AddWithValue("?cat", profile.CategoryId)
                Return "v.CategorieId=?cat"
            Case "tipologia"
                If profile.TipologiaId <= 0 Then Return ""
                cmd.Parameters.AddWithValue("?tp", profile.TipologiaId)
                Return "v.TipologieId=?tp"
            Case "taglia"
                Dim taglia As String = NormalizeAffinityText(profile.Taglia)
                If taglia.Length < 2 Then Return ""
                cmd.Parameters.AddWithValue("?taglia", "%" & taglia & "%")
                Return "(UPPER(COALESCE(tg.Descrizione,'')) LIKE ?taglia OR UPPER(COALESCE(atc.Barcode,'')) LIKE ?taglia)"
            Case "colore"
                Dim colore As String = NormalizeAffinityText(profile.Colore)
                If colore.Length < 3 Then Return ""
                cmd.Parameters.AddWithValue("?colore", "%" & colore & "%")
                Return "(UPPER(COALESCE(cl.Descrizione,'')) LIKE ?colore OR UPPER(COALESCE(v.Descrizione1,'')) LIKE ?colore OR UPPER(COALESCE(v.Descrizione2,'')) LIKE ?colore)"
        End Select

        Return ""
    End Function

    Private Function BuildTokenWhere(cmd As MySqlCommand,
                                     tokens As List(Of String),
                                     prefix As String,
                                     includeCode As Boolean,
                                     includeDescription As Boolean,
                                     includeVariant As Boolean) As String
        If cmd Is Nothing OrElse tokens Is Nothing OrElse tokens.Count = 0 Then Return ""

        Dim filters As New List(Of String)()
        Dim idx As Integer = 0

        For Each rawToken As String In tokens
            If idx >= 10 Then Exit For
            Dim token As String = NormalizeAffinityText(rawToken).Replace(" ", "")
            If token.Length < 3 Then Continue For

            Dim paramName As String = "?" & prefix & idx.ToString(CultureInfo.InvariantCulture)
            Dim clauses As New List(Of String)()

            If includeCode Then
                clauses.Add("UPPER(COALESCE(v.Codice,'')) LIKE " & paramName)
                clauses.Add("REPLACE(REPLACE(UPPER(COALESCE(v.Codice,'')),'-',''),' ','') LIKE " & paramName)
            End If
            If includeDescription Then
                clauses.Add("UPPER(COALESCE(v.Descrizione1,'')) LIKE " & paramName)
                clauses.Add("UPPER(COALESCE(v.Descrizione2,'')) LIKE " & paramName)
                clauses.Add("REPLACE(REPLACE(UPPER(COALESCE(v.Descrizione1,'')),'-',''),' ','') LIKE " & paramName)
                clauses.Add("REPLACE(REPLACE(UPPER(COALESCE(v.Descrizione2,'')),'-',''),' ','') LIKE " & paramName)
            End If
            If includeVariant Then
                clauses.Add("UPPER(COALESCE(cl.Descrizione,'')) LIKE " & paramName)
                clauses.Add("UPPER(COALESCE(tg.Descrizione,'')) LIKE " & paramName)
                clauses.Add("UPPER(COALESCE(atc.Barcode,'')) LIKE " & paramName)
                clauses.Add("REPLACE(REPLACE(UPPER(COALESCE(atc.Barcode,'')),'-',''),' ','') LIKE " & paramName)
            End If

            If clauses.Count > 0 Then
                filters.Add("(" & String.Join(" OR ", clauses.ToArray()) & ")")
                cmd.Parameters.AddWithValue(paramName, "%" & token & "%")
                idx += 1
            End If
        Next

        If filters.Count = 0 Then Return ""
        Return "(" & String.Join(" OR ", filters.ToArray()) & ")"
    End Function

    Private Sub AddCodeAffinityTokens(tokens As List(Of String), seen As HashSet(Of String), rawValue As String)
        If String.IsNullOrWhiteSpace(rawValue) Then Exit Sub

        Dim compact As String = NormalizeAffinityText(rawValue).Replace(" ", "")
        AddAffinityToken(tokens, seen, compact)

        For Each m As Match In Regex.Matches(compact, "[A-Z]{1,6}\d{2,8}[A-Z0-9]*")
            Dim value As String = m.Value
            AddAffinityToken(tokens, seen, value)
            If value.Length >= 5 AndAlso Regex.IsMatch(value, "\d$") Then
                AddAffinityToken(tokens, seen, value.Substring(0, value.Length - 1))
            End If
        Next
    End Sub

    Private Sub AddDescriptionAffinityTokens(tokens As List(Of String), seen As HashSet(Of String), rawText As String)
        If String.IsNullOrWhiteSpace(rawText) Then Exit Sub

        Dim text As String = NormalizeAffinityText(rawText)
        Dim patterns As String() = {
            "\b[A-Z]{1,6}\d{2,8}[A-Z0-9]*\b",
            "\b[A-Z]{1,6}[- ]?\d{2,8}[A-Z0-9]*\b",
            "\b\d{2,4}XL\b",
            "\bT\d{3,6}\b",
            "\bXP[- ]?\d{2,5}\b"
        }

        For Each pattern As String In patterns
            For Each m As Match In Regex.Matches(text, pattern)
                Dim token As String = m.Value.Replace(" ", "").Replace("-", "")
                AddAffinityToken(tokens, seen, token)
                If Regex.IsMatch(token, "^[A-Z]+\d{4,}$") Then
                    AddAffinityToken(tokens, seen, token.Substring(0, token.Length - 1))
                End If
            Next
        Next
    End Sub

    Private Sub AddAffinityToken(tokens As List(Of String), seen As HashSet(Of String), rawToken As String)
        If tokens Is Nothing OrElse seen Is Nothing OrElse String.IsNullOrWhiteSpace(rawToken) Then Exit Sub
        Dim token As String = NormalizeAffinityText(rawToken).Replace(" ", "")
        If token.Length < 3 Then Exit Sub
        If Not Regex.IsMatch(token, "\d") Then Exit Sub
        If seen.Contains(token) Then Exit Sub
        tokens.Add(token)
        seen.Add(token)
    End Sub

    Private Function ScoreCompanion(profile As AffinityProfile, item As RelatedItem) As Integer
        If profile Is Nothing OrElse item Is Nothing Then Return 0

        Dim score As Integer = 0
        Dim candidateText As String = NormalizeAffinityText(item.Nome & " " & item.Codice & " " & item.TagliaName & " " & item.ColoreName)
        Dim candidateCode As String = NormalizeAffinityText(item.Codice).Replace(" ", "")
        Dim candidateCompact As String = candidateText.Replace(" ", "")

        score += CountTokenMatches(candidateCode & " " & candidateCompact, profile.CodeTokens) * 1000
        score += CountTokenMatches(candidateCompact & " " & candidateText, profile.DescriptionTokens) * 700

        If profile.BrandId > 0 AndAlso item.BrandId = profile.BrandId Then score += 420
        If profile.CategoryId > 0 AndAlso item.CategoryId = profile.CategoryId Then score += 260
        If profile.TipologiaId > 0 AndAlso item.TipologiaId = profile.TipologiaId Then score += 180

        If SameAffinityValue(profile.Taglia, item.TagliaName) OrElse TextContainsAffinity(candidateText, profile.Taglia) Then score += 90

        Dim currentColor As String = FirstNonEmpty(ExtractColorKey(profile.Colore), NormalizeAffinityText(profile.Colore))
        Dim candidateColor As String = FirstNonEmpty(ExtractColorKey(item.ColoreName), ExtractColorKey(candidateText), NormalizeAffinityText(item.ColoreName))
        If Not String.IsNullOrEmpty(currentColor) AndAlso Not String.IsNullOrEmpty(candidateColor) Then
            If String.Equals(currentColor, candidateColor, StringComparison.OrdinalIgnoreCase) Then
                score += 10
            Else
                score += 80
            End If
        End If

        If String.Equals(item.AvailabilityText, "Disponibile", StringComparison.OrdinalIgnoreCase) Then score += 20

        Return score
    End Function

    Private Function CountTokenMatches(candidateText As String, tokens As List(Of String)) As Integer
        If String.IsNullOrWhiteSpace(candidateText) OrElse tokens Is Nothing Then Return 0
        Dim count As Integer = 0
        For Each token As String In tokens
            Dim normalizedToken As String = NormalizeAffinityText(token).Replace(" ", "")
            If normalizedToken.Length >= 3 AndAlso candidateText.Contains(normalizedToken) Then
                count += 1
            End If
        Next
        Return count
    End Function

    Private Function SameAffinityValue(a As String, b As String) As Boolean
        Dim leftValue As String = NormalizeAffinityText(a)
        Dim rightValue As String = NormalizeAffinityText(b)
        Return leftValue.Length > 0 AndAlso String.Equals(leftValue, rightValue, StringComparison.OrdinalIgnoreCase)
    End Function

    Private Function TextContainsAffinity(text As String, value As String) As Boolean
        Dim normalizedValue As String = NormalizeAffinityText(value)
        If normalizedValue.Length < 2 Then Return False
        Return (" " & NormalizeAffinityText(text) & " ").Contains(" " & normalizedValue & " ")
    End Function

    Private Function NormalizeAffinityText(value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return ""
        Dim text As String = HttpUtility.HtmlDecode(StripHtml(value)).ToUpperInvariant()
        text = Regex.Replace(text, "[^A-Z0-9]+", " ")
        text = Regex.Replace(text, "\s+", " ").Trim()
        Return text
    End Function

    Private Function ExtractColorKey(normalizedText As String) As String
        If String.IsNullOrWhiteSpace(normalizedText) Then Return ""
        Dim text As String = " " & NormalizeAffinityText(normalizedText) & " "

        Dim colorMap As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase) From {
            {" GIALLO ", "YELLOW"}, {" YELLOW ", "YELLOW"},
            {" NERO ", "BLACK"}, {" BLACK ", "BLACK"},
            {" CIANO ", "CYAN"}, {" CYAN ", "CYAN"}, {" AZZURRO ", "CYAN"},
            {" MAGENTA ", "MAGENTA"},
            {" ROSSO ", "RED"}, {" RED ", "RED"},
            {" BLU ", "BLUE"}, {" BLUE ", "BLUE"},
            {" BIANCO ", "WHITE"}, {" WHITE ", "WHITE"},
            {" GRIGIO ", "GREY"}, {" GREY ", "GREY"}, {" GRAY ", "GREY"}
        }

        For Each kvp As KeyValuePair(Of String, String) In colorMap
            If text.Contains(kvp.Key) Then Return kvp.Value
        Next

        Return ""
    End Function

    Private Function LoadSmartRelationFallback(row As DataRow, relationMode As String, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        If row Is Nothing Then Return results

        Dim catId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tipologiaId As Integer = GetRowInt(row, "TipologieId", 0)
        Dim marcaId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                If relationMode = "compatibili" AndAlso tipologiaId > 0 Then
                    Using cmd As New MySqlCommand()
                        cmd.Connection = conn
                        cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                           "WHERE v.NListino=?n AND v.id<>?id AND v.TipologieId=?tp " &
                                                           "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                           "LIMIT " & SafeLimit(maxItems))
                        cmd.Parameters.AddWithValue("?n", _listino)
                        cmd.Parameters.AddWithValue("?id", _id)
                        cmd.Parameters.AddWithValue("?tp", tipologiaId)
                        AppendRelated(cmd, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso relationMode = "collegati" AndAlso marcaId > 0 Then
                    Using cmdBrand As New MySqlCommand()
                        cmdBrand.Connection = conn
                        cmdBrand.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                                "WHERE v.NListino=?n AND v.id<>?id AND v.MarcheId=?mr " &
                                                                "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                                "LIMIT " & SafeLimit(maxItems))
                        cmdBrand.Parameters.AddWithValue("?n", _listino)
                        cmdBrand.Parameters.AddWithValue("?id", _id)
                        cmdBrand.Parameters.AddWithValue("?mr", marcaId)
                        AppendRelated(cmdBrand, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso catId > 0 Then
                    Using cmdCat As New MySqlCommand()
                        cmdCat.Connection = conn
                        cmdCat.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                              "WHERE v.NListino=?n AND v.id<>?id AND v.CategorieId=?cat " &
                                                              "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                              "LIMIT " & SafeLimit(maxItems))
                        cmdCat.Parameters.AddWithValue("?n", _listino)
                        cmdCat.Parameters.AddWithValue("?id", _id)
                        cmdCat.Parameters.AddWithValue("?cat", catId)
                        AppendRelated(cmdCat, results, maxItems)
                    End Using
                End If
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore LoadSmartRelationFallback " & relationMode & " (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try

        Return results
    End Function

    Private Sub AppendRelated(cmd As MySqlCommand, results As List(Of RelatedItem), maxItems As Integer)
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each it As RelatedItem In results
            Dim key As String = RelatedBusinessKey(it)
            If Not String.IsNullOrEmpty(key) Then seen.Add(key)
        Next

        Using rdr As MySqlDataReader = cmd.ExecuteReader()
            While rdr.Read() AndAlso results.Count < maxItems
                Dim idVal As Integer = SafeInt(rdr("id"), 0)
                If idVal <= 0 Then Continue While

                Dim tcidVal As Integer = SafeInt(rdr("TCid"), -1)
                Dim codiceVal As String = Convert.ToString(rdr("Codice"))
                Dim eanVal As String = SafeReaderString(rdr, "Ean")
                Dim nameVal As String = Convert.ToString(rdr("Descrizione1"))
                Dim imgVal As String = NormalizeImageUrl(Convert.ToString(rdr("Img1")))
                Dim imgHover As String = NormalizeImageUrl(SafeReaderString(rdr, "Img2"))
                If String.IsNullOrEmpty(imgHover) Then imgHover = imgVal
                If String.IsNullOrEmpty(imgVal) Then imgVal = ThemeManager.PlaceholderProductImageUrl()
                If String.IsNullOrEmpty(imgHover) Then imgHover = imgVal
                Dim inOfferta As Integer = SafeInt(rdr("InOfferta"), 0)

                Dim price As PriceContext = BuildPriceContext(SafeDec(rdr("Prezzo"), 0D),
                                                               SafeDec(rdr("PrezzoIvato"), 0D),
                                                               SafeDec(rdr("PrezzoPromo"), 0D),
                                                               SafeDec(rdr("PrezzoPromoIvato"), 0D),
                                                               inOfferta)

                Dim item As New RelatedItem()
                item.Id = idVal
                item.Tcid = tcidVal
                item.Nome = nameVal
                item.Img = imgVal
                item.ImgHover = imgHover
                item.Url = BuildProductUrl(idVal, tcidVal, includeTcid:=(_tcEnabled AndAlso tcidVal <> -1))
                item.PrezzoHtml = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo)
                item.InOfferta = (inOfferta = 1)
                item.Codice = codiceVal
                item.Ean = eanVal
                item.BrandName = SafeReaderString(rdr, "MarcheDescrizione")
                item.CategoryName = FirstNonEmpty(SafeReaderString(rdr, "TipologieDescrizione"), SafeReaderString(rdr, "CategorieDescrizione"), SafeReaderString(rdr, "SettoriDescrizione"), item.BrandName)
                item.CategoryId = SafeInt(rdr("CategorieId"), 0)
                item.TipologiaId = SafeInt(rdr("TipologieId"), 0)
                item.BrandId = SafeInt(rdr("MarcheId"), 0)
                item.TagliaName = SafeReaderString(rdr, "TCTaglia")
                item.ColoreName = FirstNonEmpty(SafeReaderString(rdr, "TCColore"), ExtractColorKey(nameVal & " " & codiceVal))
                item.PriceValue = price.CurrentPrice
                item.IsCurrent = False
                item.AvailabilityText = BuildRelatedAvailabilityText(SafeInt(rdr("Giacenza"), 0),
                                                                     SafeInt(rdr("Impegnata"), 0),
                                                                     SafeInt(rdr("Disponibilita"), 0),
                                                                     SafeInt(rdr("InOrdine"), 0))
                FinalizeRelatedItem(item)

                Dim businessKey As String = RelatedBusinessKey(item)
                If String.IsNullOrEmpty(businessKey) OrElse seen.Contains(businessKey) Then Continue While

                results.Add(item)
                seen.Add(businessKey)
            End While
        End Using
    End Sub

    Private Sub FinalizeRelatedItem(item As RelatedItem)
        If item Is Nothing Then Exit Sub

        If String.IsNullOrWhiteSpace(item.Img) Then item.Img = ThemeManager.PlaceholderProductImageUrl()
        If String.IsNullOrWhiteSpace(item.ImgHover) Then item.ImgHover = item.Img
        If String.IsNullOrWhiteSpace(item.CategoryName) Then item.CategoryName = "Catalogo"
        If String.IsNullOrWhiteSpace(item.BrandName) Then item.BrandName = ""
        If String.IsNullOrWhiteSpace(item.Url) Then item.Url = BuildProductUrl(item.Id, item.Tcid, includeTcid:=(_tcEnabled AndAlso item.Tcid <> -1))

        item.BusinessKey = RelatedBusinessKey(item)
        item.AddToCartUrl = BuildCartAddUrl(item.Id, item.Tcid)
        item.WishlistUrl = BuildWishlistAddUrl(item.Id, item.Tcid)
        item.QuickViewAttrs = BuildActionDataAttributes(item)
        item.CompareAttrs = item.QuickViewAttrs
    End Sub

    Private Function RelatedBusinessKey(item As RelatedItem) As String
        If item Is Nothing Then Return ""
        If Not String.IsNullOrWhiteSpace(item.BusinessKey) Then Return item.BusinessKey

        Dim variantSuffix As String = ""
        If item.Tcid >= 0 Then
            variantSuffix = ":TC:" & item.Tcid.ToString(CultureInfo.InvariantCulture)
        End If

        Dim eanKey As String = NormalizeBusinessIdentifier(item.Ean)
        If Not String.IsNullOrWhiteSpace(eanKey) Then Return "EAN:" & eanKey & variantSuffix

        Dim codiceKey As String = NormalizeBusinessIdentifier(item.Codice)
        If Not String.IsNullOrWhiteSpace(codiceKey) Then Return "COD:" & codiceKey & variantSuffix

        Dim textKey As String = NormalizeBusinessText(item.BrandName & "|" & item.Nome)
        If Not String.IsNullOrWhiteSpace(textKey) Then Return "TXT:" & textKey & variantSuffix

        Return "ID:" & item.Id.ToString(CultureInfo.InvariantCulture) & ":" & item.Tcid.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function BuildActionDataAttributes(item As RelatedItem) As String
        If item Is Nothing Then Return ""

        Dim priceText As String = BuildPriceText(item.PriceValue)
        Dim descriptionText As String = FirstNonEmpty(item.CategoryName, item.BrandName, item.AvailabilityText, "Prodotto")

        Dim sb As New StringBuilder()
        sb.Append("data-ks-id='").Append(EncodeAttr(item.Id.ToString(CultureInfo.InvariantCulture))).Append("' ")
        sb.Append("data-ks-tcid='").Append(EncodeAttr(item.Tcid.ToString(CultureInfo.InvariantCulture))).Append("' ")
        sb.Append("data-ks-title='").Append(EncodeAttr(item.Nome)).Append("' ")
        sb.Append("data-ks-brand='").Append(EncodeAttr(item.BrandName)).Append("' ")
        sb.Append("data-ks-category='").Append(EncodeAttr(item.CategoryName)).Append("' ")
        sb.Append("data-ks-url='").Append(EncodeAttr(item.Url)).Append("' ")
        sb.Append("data-ks-img='").Append(EncodeAttr(item.Img)).Append("' ")
        sb.Append("data-ks-price='").Append(EncodeAttr(priceText)).Append("' ")
        sb.Append("data-ks-available='").Append(EncodeAttr(item.AvailabilityText)).Append("' ")
        sb.Append("data-ks-cart-url='").Append(EncodeAttr(item.AddToCartUrl)).Append("' ")
        sb.Append("data-ks-description='").Append(EncodeAttr(ThemeManager.CompactText(descriptionText, 140))).Append("'")
        Return sb.ToString()
    End Function

    Private Function BuildCartAddUrl(id As Integer, tcid As Integer) As String
        If tcid <= 0 Then tcid = -1
        Return ResolveUrl("~/cart_add.aspx?id=" & HttpUtility.UrlEncode(id.ToString(CultureInfo.InvariantCulture)) &
                          "&TCid=" & HttpUtility.UrlEncode(tcid.ToString(CultureInfo.InvariantCulture)) &
                          "&qty=1")
    End Function

    Private Function BuildWishlistAddUrl(id As Integer, tcid As Integer) As String
        Return ResolveUrl("~/wishlist_add.aspx?id=" & HttpUtility.UrlEncode(id.ToString(CultureInfo.InvariantCulture)) &
                          "&TCid=" & HttpUtility.UrlEncode(tcid.ToString(CultureInfo.InvariantCulture)))
    End Function

    Private Function EncodeAttr(value As String) As String
        Return HttpUtility.HtmlAttributeEncode(If(value, String.Empty))
    End Function

    Private Function SafeReaderString(rdr As MySqlDataReader, columnName As String) As String
        If rdr Is Nothing OrElse String.IsNullOrWhiteSpace(columnName) Then Return ""
        Try
            Dim ordinal As Integer = rdr.GetOrdinal(columnName)
            If ordinal < 0 OrElse rdr.IsDBNull(ordinal) Then Return ""
            Return Convert.ToString(rdr.GetValue(ordinal))
        Catch
            Return ""
        End Try
    End Function

    Private Function BuildCategoryCaption(row As DataRow) As String
        If row Is Nothing Then Return "Catalogo"
        Return FirstNonEmpty(GetRowString(row, "TipologieDescrizione"),
                             GetRowString(row, "CategorieDescrizione"),
                             GetRowString(row, "SettoriDescrizione"),
                             GetRowString(row, "MarcheDescrizione"),
                             "Catalogo")
    End Function

    Private Function NormalizeBusinessIdentifier(value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return ""
        Return value.Trim().ToUpperInvariant().Replace(" ", String.Empty)
    End Function

    Private Function NormalizeBusinessText(value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return ""
        Dim text As String = value.Trim().ToUpperInvariant()
        text = Regex.Replace(text, "\s+", " ")
        Return text
    End Function

    Private Function BuildRelatedAvailabilityText(giacenza As Integer, impegnata As Integer, disponibilita As Integer, inOrdine As Integer) As String
        If (giacenza - impegnata) > 0 Then Return "Disponibile"
        If disponibilita > 0 Then Return "In arrivo"
        If inOrdine > 0 Then Return "In ordine"
        Return "Verifica disponibilita"
    End Function

    Private Function SafeInt(v As Object, fallback As Integer) As Integer
        If v Is Nothing OrElse v Is DBNull.Value Then Return fallback
        Dim n As Integer
        If Integer.TryParse(Convert.ToString(v), n) Then Return n
        Return fallback
    End Function

    Private Function SafeDec(v As Object, fallback As Decimal) As Decimal
        If v Is Nothing OrElse v Is DBNull.Value Then Return fallback
        Dim d As Decimal
        If TryParseKeepStoreDecimal(v, d) Then Return d
        Return fallback
    End Function


    Private Function GetProductRow(id As Integer, tcid As Integer, includeTcidFilter As Boolean) As DataRow
        ' Nota: in alcuni DB TCid "non variante" puo' essere -1 oppure 0.
        ' Per evitare falsi "Articolo non trovato" quando arriva TCid dal listing,
        ' se il filtro TCid non restituisce righe riproviamo senza filtro.
        Try
            Dim row As DataRow = TryGetProductRowInternal(id, tcid, includeTcidFilter)
            If row Is Nothing AndAlso includeTcidFilter Then
                row = TryGetProductRowInternal(id, tcid, False)
            End If
            Return row
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore GetProductRow (id=" & id.ToString() & ", tcid=" & tcid.ToString() & ", listino=" & _listino.ToString() & ")", ex, HttpContext.Current)
            Return Nothing
        End Try
    End Function

    Private Function TryGetProductRowInternal(id As Integer, tcid As Integer, includeTcidFilter As Boolean) As DataRow
        Dim sql As String = BuildProductSql(includeTcidFilter)

        Using cn As New MySqlConnection(GetConnectionString())
            cn.Open()
            Using cmd As New MySqlCommand(sql, cn)
                cmd.Parameters.AddWithValue("@id", id)
                cmd.Parameters.AddWithValue("@nlistino", _listino)

                If includeTcidFilter Then
                    cmd.Parameters.AddWithValue("@tcid", tcid)
                End If

                Dim dt As New DataTable()
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using

                If dt.Rows.Count = 0 Then Return Nothing
                Return dt.Rows(0)
            End Using
        End Using
    End Function

    Private Function BuildProductSql(includeTcidFilter As Boolean) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("SELECT *")
        sb.AppendLine("FROM vsuperarticoli")
        sb.AppendLine("WHERE ID=@id AND NListino=@nlistino")

        If includeTcidFilter Then
            sb.AppendLine("  AND TCid=@tcid")
        End If

        sb.AppendLine("ORDER BY")
        sb.AppendLine("  CASE")
        ' Keep row selection aligned with cart/add-to-cart: QntMinima wins, Multipli is fallback.
        sb.AppendLine("    WHEN COALESCE(InOfferta,0)=1 AND (OfferteDataInizio IS NULL OR OfferteDataInizio<=CURDATE()) AND (OfferteDataFine IS NULL OR OfferteDataFine>=CURDATE()) AND ((COALESCE(OfferteQntMinima,0)>0 AND COALESCE(OfferteQntMinima,0)<=1) OR (COALESCE(OfferteQntMinima,0)<=0 AND COALESCE(OfferteMultipli,0)>0 AND MOD(1, COALESCE(OfferteMultipli,0))=0)) THEN 0")
        sb.AppendLine("    WHEN COALESCE(InOfferta,0)<>1 OR COALESCE(OfferteDettagliId,0)=0 THEN 1")
        sb.AppendLine("    ELSE 2")
        sb.AppendLine("  END,")
        sb.AppendLine("  CASE WHEN COALESCE(PrezzoPromoIvato,0)>0 THEN PrezzoPromoIvato WHEN COALESCE(PrezzoPromo,0)>0 THEN PrezzoPromo ELSE COALESCE(PrezzoIvato, Prezzo, 999999999) END ASC,")
        sb.AppendLine("  COALESCE(PrezzoIvato, Prezzo, 999999999) ASC,")
        sb.AppendLine("  COALESCE(OfferteDettagliId,0) ASC")
        sb.AppendLine("LIMIT 1")
        Return sb.ToString()
    End Function

    Private Function BuildProductDetailViewModel(row As DataRow) As ProductDetailViewModel
        If row Is Nothing Then Return Nothing

        Dim productId As Integer = FirstPositiveInt(GetRowInt(row, "ID", 0), GetRowInt(row, "id", 0), _id)
        Dim selectedTcid As Integer = GetRowInt(row, "TCid", _tcid)
        Dim productName As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), GetRowString(row, "Descrizione"), "Articolo")
        Dim productCode As String = FirstNonEmpty(GetRowString(row, "Codice"), GetRowString(row, "SKU"))
        Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))
        Dim brandName As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        Dim categoryName As String = FirstNonEmpty(GetRowString(row, "TipologieDescrizione"), GetRowString(row, "CategorieDescrizione"), GetRowString(row, "SettoriDescrizione"), "Catalogo")

        Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                      GetRowDecimal(row, "PrezzoIvato"),
                                                      GetRowDecimal(row, "PrezzoPromo"),
                                                      GetRowDecimal(row, "PrezzoPromoIvato"),
                                                      GetEffectiveInOfferta(row))

        Dim shortDesc As String = FirstNonEmpty(GetRowString(row, "Descrizione2"), GetRowString(row, "Sottotitolo"))
        Dim shortDescHtml As String = String.Empty
        If Not String.IsNullOrEmpty(shortDesc) Then
            shortDescHtml = "<li><p class=""body-text-3"">" & Server.HtmlEncode(shortDesc) & "</p></li>"
        End If

        Dim mainImageUrl As String = NormalizeImageUrl(GetRowString(row, "Img1"))
        Dim placeholderImageUrl As String = ThemeManager.PlaceholderProductImageUrl()
        If String.IsNullOrWhiteSpace(mainImageUrl) Then
            mainImageUrl = placeholderImageUrl
        End If

        Dim galleryImageUrls As List(Of String) = BuildProductDetailGalleryImageUrls(row)
        If galleryImageUrls.Count = 0 AndAlso Not String.IsNullOrWhiteSpace(mainImageUrl) Then
            galleryImageUrls.Add(mainImageUrl)
        End If

        Dim longValue As String = FirstNonEmpty(GetRowString(row, "DescrizioneHTML"), GetRowString(row, "DescrizioneLunga"), GetRowString(row, "Descrizione2"))
        Dim availabilityText As String = BuildAvailabilityText(row)
        Dim availabilityCss As String = BuildAvailabilityCss(row)

        Dim stockAvailable As Integer = GetRowInt(row, "Giacenza", 0) - GetRowInt(row, "Impegnata", 0)

        Dim isRefurbished As Boolean = (GetRowInt(row, "Ricondizionato", 0) = 1)
        Dim refurbishedNote As String = GetRowString(row, "NoteRicondizionato")
        Dim refurbishedText As String = String.Empty
        If isRefurbished Then
            refurbishedText = FirstNonEmpty(refurbishedNote, "Articolo ricondizionato")
        End If

        Dim includeTcid As Boolean = (_tcEnabled AndAlso selectedTcid <> -1)
        Dim hasVariants As Boolean = (_tcEnabled AndAlso pnlVariants.Visible AndAlso ddlTc.Items.Count > 1)
        Dim variantSummary As String = "non abilitate"
        If hasVariants Then
            variantSummary = ddlTc.Items.Count.ToString(CultureInfo.InvariantCulture) & " varianti, TCId selezionato " & selectedTcid.ToString(CultureInfo.InvariantCulture)
        End If

        Dim seoTitle As String = productName
        If Not String.IsNullOrWhiteSpace(brandName) Then
            seoTitle &= " | " & brandName
        End If

        Dim canonicalUrl As String = BuildCanonicalUrl()
        Dim metaDescription As String = BuildMetaDescription(row, productName)
        Dim openGraphImageUrl As String = String.Empty
        If Not String.IsNullOrWhiteSpace(mainImageUrl) Then
            openGraphImageUrl = MakeAbsoluteUrl(mainImageUrl)
        End If

        Return New ProductDetailViewModel() With {
            .ProductId = productId,
            .TCId = selectedTcid,
            .ProductName = productName,
            .ProductCode = productCode,
            .Ean = ean,
            .BrandName = brandName,
            .CategoryName = categoryName,
            .ProductUrl = BuildProductUrl(productId, selectedTcid, includeTcid),
            .MainImageUrl = mainImageUrl,
            .PlaceholderImageUrl = placeholderImageUrl,
            .ShortDescriptionHtml = shortDescHtml,
            .LongDescriptionHtml = NormalizeDescriptionHtml(longValue),
            .TechnicalInfoHtml = String.Empty,
            .PriceHtml = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo),
            .PriceText = BuildPriceText(price.CurrentPrice),
            .OldPriceText = BuildPriceText(price.OldPrice),
            .IvaLabel = price.IvaLabel,
            .PromoText = If(price.IsPromo, "In offerta", String.Empty),
            .IsPromo = price.IsPromo,
            .AvailabilityHtml = BuildAvailabilityHtml(row),
            .AvailabilityText = availabilityText,
            .AvailabilityCss = availabilityCss,
            .IsAvailable = (stockAvailable > 0),
            .IsRefurbished = isRefurbished,
            .RefurbishedText = refurbishedText,
            .RefurbishedBadgeUrl = "/Public/assets/images/img/refurbished.png",
            .QuantityText = "1",
            .AddToCartEnabled = False,
            .CanAddToCart = False,
            .AddToCartPlaceholderText = "preview locale: carrello reale non collegato",
            .ShowVariants = hasVariants,
            .HasVariants = hasVariants,
            .SelectedVariantTCId = selectedTcid,
            .VariantSummaryText = variantSummary,
            .ReviewsSummaryText = String.Empty,
            .RelatedProductsTitle = String.Empty,
            .HasRelatedProducts = False,
            .HasRecentProducts = False,
            .SeoTitle = seoTitle,
            .SeoMetaDescription = metaDescription,
            .CanonicalUrl = canonicalUrl,
            .OpenGraphImageUrl = openGraphImageUrl,
            .JsonLdHtml = BuildProductJsonLd(row, canonicalUrl, metaDescription),
            .GalleryDomId = String.Empty,
            .GalleryThumbsDomId = String.Empty,
            .SupportsSwiperGallery = False,
            .SupportsPhotoSwipe = False,
            .SupportsDriftZoom = False,
            .SupportsQuantityStepper = False,
            .GalleryImageUrls = galleryImageUrls
        }
    End Function

    Private Function BuildProductDetailGalleryImageUrls(row As DataRow) As List(Of String)
        Dim images As New List(Of String)()
        If row Is Nothing Then Return images

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For i As Integer = 1 To 6
            Dim imageUrl As String = NormalizeImageUrl(GetRowString(row, "Img" & i.ToString(CultureInfo.InvariantCulture)))
            If String.IsNullOrWhiteSpace(imageUrl) Then Continue For
            If seen.Add(imageUrl) Then images.Add(imageUrl)
        Next

        Return images
    End Function

    Private Sub BindProduct(row As DataRow)
        pnlProduct.Visible = True
        phNotFound.Visible = False

        Dim nome As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), GetRowString(row, "Descrizione"))
        If String.IsNullOrEmpty(nome) Then
            nome = "Articolo"
        End If

        litBreadcrumbCurrent.Text = Server.HtmlEncode(nome)
        litNome.Text = Server.HtmlEncode(nome)

        Dim categoryName As String = FirstNonEmpty(GetRowString(row, "TipologieDescrizione"), GetRowString(row, "CategorieDescrizione"), GetRowString(row, "SettoriDescrizione"))
        If String.IsNullOrEmpty(categoryName) Then
            categoryName = "Catalogo"
        End If
        lnkCategory.Text = Server.HtmlEncode(categoryName)
        lnkCategory.NavigateUrl = BuildCategoryCatalogUrl(row)
        phCategoryFeature.Visible = (Not String.IsNullOrEmpty(categoryName))
        phCategoryInfo.Visible = phCategoryFeature.Visible
        litCategory2.Text = Server.HtmlEncode(categoryName)
        litCategoryInfo.Text = Server.HtmlEncode(categoryName)

        Dim codice As String = FirstNonEmpty(GetRowString(row, "Codice"), GetRowString(row, "SKU"))
        litCodice.Text = Server.HtmlEncode(codice)
        litCodice2.Text = Server.HtmlEncode(codice)
        litCodice3.Text = Server.HtmlEncode(codice)
        litCodice4.Text = Server.HtmlEncode(codice)

        Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))
        If Not String.IsNullOrEmpty(ean) Then
            phEan.Visible = True
            phEan2.Visible = True
            phEan3.Visible = True
            phEanInfo.Visible = True
            litEan.Text = Server.HtmlEncode(ean)
            litEan2.Text = Server.HtmlEncode(ean)
            litEan3.Text = Server.HtmlEncode(ean)
            litEan4.Text = Server.HtmlEncode(ean)
        Else
            phEan.Visible = False
            phEan2.Visible = False
            phEan3.Visible = False
            phEanInfo.Visible = False
            litEan3.Text = String.Empty
            litEan4.Text = String.Empty
        End If

        ' Marca
        Dim brandName As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        Dim brandId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))
        If brandId > 0 AndAlso Not String.IsNullOrEmpty(brandName) Then
            phBrand.Visible = True
            phBrand2.Visible = True
            phBrandFeature.Visible = True
            phBrandInfo.Visible = True

            lnkMarca.Text = Server.HtmlEncode(brandName)
            lnkMarca.NavigateUrl = BuildBrandCatalogUrl(row, brandId)

            litMarca2.Text = Server.HtmlEncode(brandName)
            litMarcaFeature.Text = Server.HtmlEncode(brandName)
            litMarcaInfo.Text = Server.HtmlEncode(brandName)
        Else
            phBrand.Visible = False
            phBrand2.Visible = False
            phBrandFeature.Visible = False
            phBrandInfo.Visible = False
            litMarcaFeature.Text = String.Empty
            litMarcaInfo.Text = String.Empty
        End If

        ' Prezzi
        Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                      GetRowDecimal(row, "PrezzoIvato"),
                                                      GetRowDecimal(row, "PrezzoPromo"),
                                                      GetRowDecimal(row, "PrezzoPromoIvato"),
                                                      GetEffectiveInOfferta(row))

        litPriceHtml.Text = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo)
        ' Box prezzo sticky (stesso HTML del prezzo principale)
        litPriceHtml2.Text = litPriceHtml.Text
        litPriceInfo.Text = BuildPriceText(price.CurrentPrice)
        litIvaInfo.Text = Server.HtmlEncode(price.IvaLabel)

        Dim promotionModel As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(GetConnectionString(),
                                                                                                            _id,
                                                                                                            GetCurrentAziendaId(),
                                                                                                            _listino,
                                                                                                            GetRowDecimal(row, "Prezzo"),
                                                                                                            GetRowDecimal(row, "PrezzoIvato"))
        phPromotionOffers.Visible = (promotionModel IsNot Nothing AndAlso promotionModel.HasOffers)
        litPromotionOffers.Text = If(promotionModel IsNot Nothing, promotionModel.Html, String.Empty)

        Dim isRefurbished As Boolean = (GetRowInt(row, "Ricondizionato", 0) = 1)
        phRefurbished.Visible = isRefurbished
        If isRefurbished Then
            Dim noteRefurbished As String = GetRowString(row, "NoteRicondizionato")
            If Not String.IsNullOrWhiteSpace(noteRefurbished) Then
                litRefurbishedNote.Text = "<span class='body-text-3' style='font-weight:500;'>" & Server.HtmlEncode(noteRefurbished) & "</span>"
            Else
                litRefurbishedNote.Text = String.Empty
            End If
        Else
            litRefurbishedNote.Text = String.Empty
        End If

        ' Descrizione breve
        Dim shortDesc As String = FirstNonEmpty(GetRowString(row, "Descrizione2"), GetRowString(row, "Sottotitolo"))
        If String.IsNullOrEmpty(shortDesc) Then
            litShortDesc.Text = ""
        Else
            litShortDesc.Text = "<li><p class=""body-text-3"">" & Server.HtmlEncode(shortDesc) & "</p></li>"
        End If

        ' Descrizione lunga (preferisco HTML)
        Dim longValue As String = FirstNonEmpty(GetRowString(row, "DescrizioneHTML"), GetRowString(row, "DescrizioneLunga"), GetRowString(row, "Descrizione2"))
        litLongDesc.Text = NormalizeDescriptionHtml(longValue)

        ' Disponibilità (Arrivo)
        Dim availabilityText As String = BuildAvailabilityText(row)
        Dim availabilityHtml As String = BuildAvailabilityHtml(row)
        phAvailability.Visible = False
        phAvailabilityInfo.Visible = Not String.IsNullOrEmpty(availabilityText)
        litAvailability.Text = String.Empty
        litBuyBoxAvailability.Text = availabilityHtml
        litAvailabilityInfo.Text = availabilityHtml

        ' Varianti (Taglia/Colore)
        Dim currentTcid As Integer = GetRowInt(row, "TCid", _tcid)
        ' Mantengo il TCid effettivo caricato (serve per Aggiungi al carrello anche quando il dropdown non è visibile)
        _tcid = currentTcid
        BindVariantsIfNeeded(_id, currentTcid)

        ' Immagini
        BindImages(row, nome)
        EmitRecentlyViewedClientScript(row, price, categoryName, brandName, codice, availabilityText, currentTcid)

        ' Quantità desiderata e stato carrello corrente.
        BindPdpCartState(_id, currentTcid, True)
    End Sub

    Private Sub BindVariantsIfNeeded(id As Integer, currentTcid As Integer)
        If Not _tcEnabled Then
            pnlVariants.Visible = False
            Return
        End If

        Dim options As List(Of KeyValuePair(Of Integer, String)) = LoadVariantOptions(id, _listino)
        If options Is Nothing OrElse options.Count <= 1 Then
            pnlVariants.Visible = False
            Return
        End If

        pnlVariants.Visible = True
        ddlTc.Items.Clear()

        For Each kv As KeyValuePair(Of Integer, String) In options
            ddlTc.Items.Add(New ListItem(kv.Value, kv.Key.ToString()))
        Next

        Dim sel As ListItem = ddlTc.Items.FindByValue(currentTcid.ToString())
        If sel IsNot Nothing Then
            ddlTc.ClearSelection()
            sel.Selected = True
        End If
    End Sub

    Private Function LoadVariantOptions(id As Integer, listino As Integer) As List(Of KeyValuePair(Of Integer, String))
        Dim results As New List(Of KeyValuePair(Of Integer, String))()

        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()

                Dim sql As String = "SELECT atc.id AS tcid, TRIM(CONCAT(IFNULL(c.Descrizione,''), ' ', IFNULL(t.Descrizione,''), ' ', IFNULL(atc.Barcode,''))) AS descrizione " &
                                    "FROM articoli_tagliecolori atc " &
                                    "LEFT JOIN colori c ON c.id=atc.ColoreId " &
                                    "LEFT JOIN taglie t ON t.id=atc.TagliaId " &
                                    "WHERE atc.ArticoliId=@idarticolo " &
                                    "ORDER BY c.Descrizione, t.Descrizione, atc.id"

                Using cmd As New MySqlCommand(sql, cn)
                    cmd.Parameters.AddWithValue("@idarticolo", id)

                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim tcid As Integer
                            If Not Integer.TryParse(Convert.ToString(r.GetValue(0)), tcid) Then
                                Continue While
                            End If

                            Dim descr As String = Convert.ToString(r.GetValue(1))
                            If String.IsNullOrEmpty(descr) Then
                                descr = "Variante " & tcid.ToString()
                            End If

                            results.Add(New KeyValuePair(Of Integer, String)(tcid, descr.Trim()))
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' best-effort
        End Try

        Return results
    End Function

    Private Function LoadVariantInfo(id As Integer, tcid As Integer) As VariantInfo
        If id <= 0 Then Return Nothing

        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()

                Dim sql As String = "SELECT c.Descrizione AS colore, t.Descrizione AS taglia, atc.Barcode AS descrizione " &
                                    "FROM articoli_tagliecolori atc " &
                                    "LEFT JOIN colori c ON c.id=atc.ColoreId " &
                                    "LEFT JOIN taglie t ON t.id=atc.TagliaId " &
                                    "WHERE atc.ArticoliId=@idarticolo " &
                                    "  AND (@tcid=-1 OR atc.id=@tcid) " &
                                    "ORDER BY CASE WHEN atc.id=@tcid THEN 0 ELSE 1 END, c.Descrizione, t.Descrizione " &
                                    "LIMIT 1"

                Using cmd As New MySqlCommand(sql, cn)
                    cmd.Parameters.AddWithValue("@idarticolo", id)
                    cmd.Parameters.AddWithValue("@tcid", tcid)

                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        If r.Read() Then
                            Return New VariantInfo() With {
                                .Colore = Convert.ToString(r("colore")),
                                .Taglia = Convert.ToString(r("taglia")),
                                .Descrizione = Convert.ToString(r("descrizione"))
                            }
                        End If
                    End Using
                End Using
            End Using
        Catch
            ' best-effort: l'affinita' resta basata su codice/descrizione.
        End Try

        Return Nothing
    End Function

    Private Sub BindImages(row As DataRow, productName As String)
        Dim imgs As New List(Of ImgItem)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        For i As Integer = 1 To 6
            Dim raw As String = GetRowString(row, "Img" & i.ToString())
            Dim url As String = NormalizeImageUrl(raw)

            If String.IsNullOrEmpty(url) Then
                Continue For
            End If

            If seen.Contains(url) Then
                Continue For
            End If

            seen.Add(url)
            imgs.Add(New ImgItem() With {.Url = url, .Alt = productName})
        Next

        If imgs.Count = 0 Then
            imgs.Add(New ImgItem() With {.Url = ThemeManager.PlaceholderProductImageUrl(), .Alt = productName})
        End If

        Dim fillUrl As String = imgs(0).Url
        If String.IsNullOrEmpty(fillUrl) Then
            fillUrl = ThemeManager.PlaceholderProductImageUrl()
        End If

        While imgs.Count < 6
            imgs.Add(New ImgItem() With {.Url = fillUrl, .Alt = productName})
        End While

        If imgs.Count > 6 Then
            imgs.RemoveRange(6, imgs.Count - 6)
        End If

        rptMainImages.DataSource = imgs
        rptMainImages.DataBind()

        rptThumbs.DataSource = imgs
        rptThumbs.DataBind()
    End Sub

    Private Sub ApplySeo(row As DataRow)
        Dim nome As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
        Dim brand As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))

        Dim title As String
        If Not String.IsNullOrEmpty(brand) Then
            title = nome & " | " & brand
        Else
            title = nome
        End If

        Page.Title = title

        Dim metaDesc As String = BuildMetaDescription(row, nome)
        SeoBuilder.AddOrReplaceNameMeta(Page, "description", metaDesc)
        SeoBuilder.AddOrReplaceNameMeta(Page, "robots", "index,follow")

        Dim canonical As String = BuildCanonicalUrl()
        SeoBuilder.SetCanonical(Page, canonical)

        ' Open Graph
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:type", "product")
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:title", title)
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:description", metaDesc)
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:url", canonical)

        Dim img As String = NormalizeImageUrl(GetRowString(row, "Img1"))
        If Not String.IsNullOrEmpty(img) Then
            SeoBuilder.AddOrReplacePropertyMeta(Page, "og:image", MakeAbsoluteUrl(img))
        End If

        ' JSON-LD in <head>
        litJsonLdHead.Text = BuildProductJsonLd(row, canonical, metaDesc)
    End Sub

    Private Function BuildCanonicalUrl() As String
        Dim includeTcid As Boolean = (Request.QueryString("TCid") IsNot Nothing) ' come da richiesta: tieni TCid quando presente
        Dim rel As String = "~/articolo.aspx?id=" & _id.ToString()

        If includeTcid Then
            rel &= "&TCid=" & _tcid.ToString()
        End If

        Return MakeAbsoluteUrl(ResolveUrl(rel))
    End Function

    Private Function MakeAbsoluteUrl(relativeOrAbsolute As String) As String
        If String.IsNullOrEmpty(relativeOrAbsolute) Then
            Return GetSiteBaseUrl()
        End If

        If relativeOrAbsolute.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse relativeOrAbsolute.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return relativeOrAbsolute
        End If

        Dim path As String = relativeOrAbsolute
        If Not path.StartsWith("/", StringComparison.Ordinal) Then
            path = "/" & path
        End If

        Return GetSiteBaseUrl() & path
    End Function

    Private Function GetSiteBaseUrl() As String
        Dim uri As Uri = Request.Url
        Return uri.Scheme & "://" & uri.Authority
    End Function

        Private Function BuildProductJsonLd(row As DataRow, canonical As String, metaDesc As String) As String
        ' Miglioramento SEO/AI:
        ' - JSON-LD @graph coerente (Organization + WebSite + WebPage + BreadcrumbList + Product)
        ' - Include GTIN (EAN) se presente
        ' - Offer con currency e (se disponibile) availability
        Try
            Dim js As New System.Web.Script.Serialization.JavaScriptSerializer()

            Dim name As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
            Dim brand As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
            Dim sku As String = FirstNonEmpty(GetRowString(row, "SKU"), GetRowString(row, "Codice"), _id.ToString())
            Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))

            Dim img As String = NormalizeImageUrl(GetRowString(row, "Img1"))
            If Not String.IsNullOrEmpty(img) Then
                img = MakeAbsoluteUrl(img)
            End If

            Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                          GetRowDecimal(row, "PrezzoIvato"),
                                                          GetRowDecimal(row, "PrezzoPromo"),
                                                          GetRowDecimal(row, "PrezzoPromoIvato"),
                                                          GetEffectiveInOfferta(row))

            ' --- Base entity ids
            Dim baseUrl As String = canonical.TrimEnd("/"c)
            Dim orgId As String = baseUrl & "#organization"
            Dim webSiteId As String = baseUrl & "#website"
            Dim webPageId As String = baseUrl & "#webpage"
            Dim productId As String = baseUrl & "#product"

            ' --- Organization (dati best-effort da Session)
            Dim orgName As String = ""
            Try
                orgName = TryCast(Session("AziendaNome"), String)
            Catch
            End Try
            If String.IsNullOrEmpty(orgName) Then orgName = "Taikun"

            Dim organization As New Dictionary(Of String, Object)()
            organization("@type") = "Organization"
            organization("@id") = orgId
            organization("name") = orgName
            organization("url") = Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/")

            ' --- WebSite
            Dim webSite As New Dictionary(Of String, Object)()
            webSite("@type") = "WebSite"
            webSite("@id") = webSiteId
            webSite("url") = organization("url")
            webSite("name") = orgName
            webSite("publisher") = New Dictionary(Of String, Object) From {{"@id", orgId}}

            ' --- BreadcrumbList (Home > Catalogo > Prodotto)
            Dim breadcrumbItems As New List(Of Object)()
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 1},
                {"name", "Home"},
                {"item", Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/")}
            })
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 2},
                {"name", "Catalogo"},
                {"item", Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/articoli.aspx")}
            })
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 3},
                {"name", name},
                {"item", canonical}
            })

            Dim breadcrumb As New Dictionary(Of String, Object)()
            breadcrumb("@type") = "BreadcrumbList"
            breadcrumb("@id") = baseUrl & "#breadcrumb"
            breadcrumb("itemListElement") = breadcrumbItems.ToArray()

            ' --- Product
            Dim product As New Dictionary(Of String, Object)()
            product("@type") = "Product"
            product("@id") = productId
            product("name") = name
            If Not String.IsNullOrEmpty(metaDesc) Then product("description") = metaDesc
            product("sku") = sku
            product("url") = canonical
            If Not String.IsNullOrEmpty(img) Then product("image") = img
            If Not String.IsNullOrEmpty(brand) Then
                product("brand") = New Dictionary(Of String, Object) From {{"@type", "Brand"}, {"name", brand}}
            End If

            ' GTIN: se EAN 13 -> gtin13, se 14 -> gtin14, altrimenti generic gtin
            If Not String.IsNullOrEmpty(ean) Then
                Dim sbDigits As New StringBuilder()
                For Each ch As Char In ean
                    If Char.IsDigit(ch) Then sbDigits.Append(ch)
                Next
                Dim digitsOnly As String = sbDigits.ToString()
                If digitsOnly.Length = 13 Then
                    product("gtin13") = digitsOnly
                ElseIf digitsOnly.Length = 14 Then
                    product("gtin14") = digitsOnly
                ElseIf digitsOnly.Length > 0 Then
                    product("gtin") = digitsOnly
                End If
            End If

            ' Offer
            If price.CurrentPrice.HasValue AndAlso price.CurrentPrice.Value > 0D Then
                Dim offer As New Dictionary(Of String, Object)()
                offer("@type") = "Offer"
                offer("price") = price.CurrentPrice.Value.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
                offer("priceCurrency") = "EUR"
                offer("url") = canonical

                Dim stockAvailable As Integer = GetRowInt(row, "Giacenza", 0) - GetRowInt(row, "Impegnata", 0)
                If stockAvailable > 0 OrElse GetRowInt(row, "Disponibilita", 0) > 0 OrElse GetRowInt(row, "InOrdine", 0) > 0 Then
                    offer("availability") = "https://schema.org/InStock"
                Else
                    offer("availability") = "https://schema.org/OutOfStock"
                End If

                offer("itemCondition") = "https://schema.org/NewCondition"
                offer("seller") = New Dictionary(Of String, Object) From {{"@id", orgId}}

                product("offers") = offer
            End If

            ' --- WebPage
            Dim webPage As New Dictionary(Of String, Object)()
            webPage("@type") = "WebPage"
            webPage("@id") = webPageId
            webPage("url") = canonical
            webPage("name") = name
            If Not String.IsNullOrEmpty(metaDesc) Then webPage("description") = metaDesc
            webPage("isPartOf") = New Dictionary(Of String, Object) From {{"@id", webSiteId}}
            webPage("about") = New Dictionary(Of String, Object) From {{"@id", orgId}}
            webPage("mainEntity") = New Dictionary(Of String, Object) From {{"@id", productId}}
            If Not String.IsNullOrEmpty(img) Then
                webPage("primaryImageOfPage") = New Dictionary(Of String, Object) From {{"@type", "ImageObject"}, {"url", img}}
            End If

            Dim graph As New List(Of Object)()
            graph.Add(organization)
            graph.Add(webSite)
            graph.Add(webPage)
            graph.Add(breadcrumb)
            graph.Add(product)

            Dim root As New Dictionary(Of String, Object)()
            root("@context") = "https://schema.org"
            root("@graph") = graph

            Dim json As String = js.Serialize(root)
            Return "<script type=""application/ld+json"">" & json & "</script>"
        Catch
            Return ""
        End Try
    End Function

    Private Function JsonString(value As String) As String
        If value Is Nothing Then value = ""
        Return """" & value.Replace("\", "\\").Replace("""", "\""").Replace(vbCr, " ").Replace(vbLf, " ") & """"
    End Function

    Private Function JsonNumber(value As Decimal) As String
        Return value.ToString(System.Globalization.CultureInfo.InvariantCulture)
    End Function

    Private Function BuildMetaDescription(row As DataRow, fallbackName As String) As String
        Dim raw As String = FirstNonEmpty(GetRowString(row, "MetaDescription"), GetRowString(row, "Descrizione2"), GetRowString(row, "DescrizioneLunga"))
        If String.IsNullOrEmpty(raw) Then
            raw = fallbackName
        End If

        Dim plain As String = StripHtml(raw)
        plain = NormalizeWhitespace(plain)

        If plain.Length > 160 Then
            plain = plain.Substring(0, 157).Trim() & "..."
        End If

        Return plain
    End Function

    Private Function NormalizeDescriptionHtml(value As String) As String
        If String.IsNullOrEmpty(value) Then
            Return ""
        End If

        Dim s As String = value.Trim()

        ' Se sembra HTML, lascio passare (rimuovo solo eventuali <script>)
        Dim looksHtml As Boolean = (s.IndexOf("<"c) >= 0 AndAlso s.IndexOf(">"c) >= 0)
        If looksHtml Then
            ' Hardening XSS: sanitizzazione allowlist (tag/attributi) + rimozione script/iframe.
            Return SanitizeHtmlAllowBasic(s)
        End If

        s = Server.HtmlEncode(s)
        s = s.Replace(vbCrLf, "<br />").Replace(vbLf, "<br />")
        Return "<p>" & s & "</p>"
    End Function

    Private Function RemoveScriptBlocks(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        Try
            Dim lower As String = html.ToLowerInvariant()
            Dim start As Integer = lower.IndexOf("<script")
            While start >= 0
                Dim endTag As Integer = lower.IndexOf("</script>", start)
                If endTag < 0 Then Exit While

                Dim endPos As Integer = endTag + 9
                html = html.Remove(start, endPos - start)

                lower = html.ToLowerInvariant()
                start = lower.IndexOf("<script")
            End While
        Catch
        End Try

        Return html
    End Function

    Private Function SanitizeHtmlAllowBasic(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        ' 1) rimuove blocchi <script> (fallback) e poi parse HTML.
        Dim input As String = RemoveScriptBlocks(html)

        Try
            Dim doc As New HtmlDocument()
            doc.OptionFixNestedTags = True
            doc.LoadHtml(input)

            ' tag consentiti (basic eCommerce)
            Dim allowedTags As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
                "p", "br", "strong", "b", "em", "i", "u",
                "ul", "ol", "li",
                "h1", "h2", "h3", "h4", "h5", "h6",
                "div", "span",
                "table", "thead", "tbody", "tr", "th", "td",
                "a", "img"
            }

            ' attributi consentiti
            Dim allowedAttrs As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
                "href", "src", "alt", "title", "class", "id", "name", "target", "rel"
            }

            Dim nodes As HtmlNodeCollection = doc.DocumentNode.SelectNodes("//*")
            If nodes Is Nothing Then Return ""

            Dim i As Integer
            For i = nodes.Count - 1 To 0 Step -1
                Dim n As HtmlNode = nodes(i)
                Dim tag As String = n.Name

                ' rimuove tag pericolosi e quelli non in allowlist (sostituisce con testo)
                If tag.Equals("script", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("iframe", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("object", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("embed", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("link", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("meta", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("style", StringComparison.OrdinalIgnoreCase) Then
                    n.Remove()
                    Continue For
                End If

                If Not allowedTags.Contains(tag) Then
                    ' conserva testo interno (se presente)
                    Dim text As String = HttpUtility.HtmlEncode(n.InnerText)
                    n.ParentNode.ReplaceChild(HtmlNode.CreateNode(text), n)
                    Continue For
                End If

                ' pulizia attributi
                If n.HasAttributes Then
                    Dim toRemove As New List(Of HtmlAttribute)()
                    For Each a As HtmlAttribute In n.Attributes
                        Dim an As String = a.Name
                        Dim av As String = If(a.Value, "")

                        ' elimina handler on* e attributi non consentiti
                        If an.StartsWith("on", StringComparison.OrdinalIgnoreCase) OrElse Not allowedAttrs.Contains(an) Then
                            toRemove.Add(a)
                            Continue For
                        End If

                        ' elimina javascript: nelle URL
                        If (an.Equals("href", StringComparison.OrdinalIgnoreCase) OrElse an.Equals("src", StringComparison.OrdinalIgnoreCase)) Then
                            Dim v As String = av.Trim()
                            If v.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then
                                toRemove.Add(a)
                                Continue For
                            End If
                        End If

                        ' normalizza target
                        If an.Equals("target", StringComparison.OrdinalIgnoreCase) Then
                            If Not av.Equals("_blank", StringComparison.OrdinalIgnoreCase) Then
                                toRemove.Add(a)
                            Else
                                ' security: rel
                                If n.Name.Equals("a", StringComparison.OrdinalIgnoreCase) Then
                                    If n.Attributes("rel") Is Nothing Then
                                        n.Attributes.Add("rel", "noopener")
                                    End If
                                End If
                            End If
                        End If
                    Next

                    For Each a As HtmlAttribute In toRemove
                        n.Attributes.Remove(a)
                    Next
                End If
            Next

            Return doc.DocumentNode.InnerHtml
        Catch
            ' fallback: encode
            Dim safe As String = HttpUtility.HtmlEncode(input)
            safe = safe.Replace(vbCrLf, "<br />").Replace(vbLf, "<br />")
            Return "<p>" & safe & "</p>"
        End Try
    End Function


    Private Function StripHtml(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        Dim inside As Boolean = False
        Dim sb As New StringBuilder()

        For Each ch As Char In html
            If ch = "<"c Then
                inside = True
            ElseIf ch = ">"c Then
                inside = False
            ElseIf Not inside Then
                sb.Append(ch)
            End If
        Next

        Return HttpUtility.HtmlDecode(sb.ToString())
    End Function

    Private Function NormalizeWhitespace(s As String) As String
        If String.IsNullOrEmpty(s) Then Return ""

        Dim sb As New StringBuilder()
        Dim prevSpace As Boolean = False

        For Each ch As Char In s
            Dim isSpace As Boolean = Char.IsWhiteSpace(ch)
            If isSpace Then
                If Not prevSpace Then
                    sb.Append(" "c)
                End If
            Else
                sb.Append(ch)
            End If
            prevSpace = isSpace
        Next

        Return sb.ToString().Trim()
    End Function

    Private Function BuildPriceHtml(prezzo As Nullable(Of Decimal), prezzoOld As Nullable(Of Decimal), inOfferta As Boolean) As String
        If Not prezzo.HasValue OrElse prezzo.Value <= 0D Then
            Return "<span class=""new-price price-text fw-medium mb-0"">Prezzo su richiesta</span>"
        End If

        Dim priceText As String = FormatMoney(prezzo.Value)

        If inOfferta AndAlso prezzoOld.HasValue AndAlso prezzoOld.Value > 0D AndAlso prezzo.HasValue AndAlso prezzoOld.Value > prezzo.Value Then
            Dim oldText As String = FormatMoney(prezzoOld.Value)
            Return "<span class=""new-price price-text fw-medium mb-0"">" & Server.HtmlEncode(priceText) & "</span><span class=""old-price body-md-2 text-main-2 fw-normal"">" & Server.HtmlEncode(oldText) & "</span>"
        End If

        Return "<span class=""new-price price-text fw-medium mb-0"">" & Server.HtmlEncode(priceText) & "</span>"
    End Function

    Private Function BuildPriceText(prezzo As Nullable(Of Decimal)) As String
        If prezzo.HasValue AndAlso prezzo.Value > 0D Then
            Return Server.HtmlEncode(FormatMoney(prezzo.Value))
        End If
        Return "Prezzo su richiesta"
    End Function

    Private Function BuildPriceContext(prezzo As Nullable(Of Decimal),
                                       prezzoIvato As Nullable(Of Decimal),
                                       prezzoPromo As Nullable(Of Decimal),
                                       prezzoPromoIvato As Nullable(Of Decimal),
                                       inOfferta As Integer) As PriceContext
        Dim ctx As New PriceContext()
        Dim ivaTipo As Integer = GetSessionInt("IvaTipo", 2)

        If ivaTipo = 1 Then
            ctx.CurrentPrice = prezzo
            ctx.OldPrice = Nothing
            ctx.IvaLabel = "IVA esclusa"
            If IsValidPromoPrice(prezzo, prezzoPromo, inOfferta) Then
                ctx.CurrentPrice = prezzoPromo
                If prezzo.HasValue AndAlso prezzo.Value > prezzoPromo.Value Then
                    ctx.OldPrice = prezzo
                End If
                ctx.IsPromo = True
            End If
        Else
            ctx.CurrentPrice = prezzoIvato
            ctx.OldPrice = Nothing
            ctx.IvaLabel = "IVA inclusa"
            If IsValidPromoPrice(prezzoIvato, prezzoPromoIvato, inOfferta) Then
                ctx.CurrentPrice = prezzoPromoIvato
                If prezzoIvato.HasValue AndAlso prezzoIvato.Value > prezzoPromoIvato.Value Then
                    ctx.OldPrice = prezzoIvato
                End If
                ctx.IsPromo = True
            End If
        End If

        If Not ctx.CurrentPrice.HasValue OrElse ctx.CurrentPrice.Value <= 0D Then
            ctx.CurrentPrice = FirstPositiveDecimal(prezzoIvato, prezzo, prezzoPromoIvato, prezzoPromo)
        End If

        Return ctx
    End Function

    Private Function IsValidPromoPrice(basePrice As Nullable(Of Decimal), promoPrice As Nullable(Of Decimal), inOfferta As Integer) As Boolean
        If inOfferta <> 1 Then Return False
        If Not promoPrice.HasValue OrElse promoPrice.Value <= 0D Then Return False
        If basePrice.HasValue AndAlso basePrice.Value > 0D AndAlso promoPrice.Value >= basePrice.Value Then Return False
        Return True
    End Function

    Private Function GetEffectiveInOfferta(row As DataRow) As Integer
        If row Is Nothing Then Return 0
        If GetRowInt(row, "InOfferta", 0) <> 1 Then Return 0
        If Not IsProductRowPromoActive(row) Then Return 0
        If Not IsProductRowPromoApplicableToDefaultQuantity(row) Then Return 0
        Return 1
    End Function

    Private Function IsProductRowPromoApplicableToDefaultQuantity(row As DataRow) As Boolean
        If row Is Nothing Then Return False
        Dim qntMinima As Decimal = GetRowDecimal(row, "OfferteQntMinima").GetValueOrDefault(0D)
        If qntMinima > 0D Then Return qntMinima <= 1D

        Dim multipli As Decimal = GetRowDecimal(row, "OfferteMultipli").GetValueOrDefault(0D)
        If multipli > 0D Then Return Decimal.Remainder(1D, multipli) = 0D
        Return False
    End Function

    Private Function IsProductRowPromoActive(row As DataRow) As Boolean
        If row Is Nothing Then Return False

        Dim fromListino As Integer = GetRowInt(row, "OfferteDaListino", 0)
        Dim toListino As Integer = GetRowInt(row, "OfferteAListino", 0)
        If fromListino > 0 AndAlso _listino < fromListino Then Return False
        If toListino > 0 AndAlso _listino > toListino Then Return False

        Dim today As Date = Date.Today
        Dim startsOn As Nullable(Of Date) = GetRowDate(row, "OfferteDataInizio")
        Dim endsOn As Nullable(Of Date) = GetRowDate(row, "OfferteDataFine")
        If startsOn.HasValue AndAlso startsOn.Value.Date > today Then Return False
        If endsOn.HasValue AndAlso endsOn.Value.Date < today Then Return False

        Return True
    End Function

    Private Function GetRowDate(row As DataRow, columnName As String) As Nullable(Of Date)
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(columnName) Then Return Nothing

        Dim raw As Object = row(columnName)
        If raw Is Nothing OrElse Convert.IsDBNull(raw) Then Return Nothing

        Dim parsed As Date
        If Date.TryParse(Convert.ToString(raw), parsed) Then Return parsed
        Return Nothing
    End Function

    Private Function FormatMoney(value As Decimal) As String
        Return value.ToString("C2", ItCulture)
    End Function

    Private Function FirstPositiveDecimal(ParamArray values() As Nullable(Of Decimal)) As Nullable(Of Decimal)
        If values Is Nothing Then Return Nothing
        For Each v As Nullable(Of Decimal) In values
            If v.HasValue AndAlso v.Value > 0D Then Return v
        Next
        Return Nothing
    End Function

    Private Function BuildAvailabilityText(row As DataRow) As String
        Return AvailabilityDisplayHelper.BuildText(row, HttpContext.Current)
    End Function

    Private Function BuildAvailabilityHtml(row As DataRow) As String
        Return AvailabilityDisplayHelper.BuildHtml(row, HttpContext.Current)
    End Function

    Private Function BuildAvailabilityCss(row As DataRow) As String
        Return AvailabilityDisplayHelper.BuildCssClass(row, HttpContext.Current)
    End Function

    Private Sub EmitRecentlyViewedClientScript(row As DataRow,
                                               price As PriceContext,
                                               categoryName As String,
                                               brandName As String,
                                               codice As String,
                                               availabilityText As String,
                                               currentTcid As Integer)
        Try
            If row Is Nothing OrElse _id <= 0 Then
                litRecentlyViewedScript.Text = String.Empty
                Return
            End If

            Dim name As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Prodotto")
            Dim img As String = NormalizeImageUrl(GetRowString(row, "Img1"))
            If String.IsNullOrWhiteSpace(img) Then img = ThemeManager.PlaceholderProductImageUrl()

            Dim item As New Dictionary(Of String, Object)()
            item("id") = _id.ToString()
            item("tcid") = If(currentTcid > 0, currentTcid.ToString(), "")
            item("name") = name
            item("code") = codice
            item("brand") = brandName
            item("category") = categoryName
            item("image") = img
            item("price") = BuildPriceText(price.CurrentPrice)
            item("availability") = availabilityText
            item("url") = BuildProductUrl(_id, currentTcid, includeTcid:=(currentTcid > 0))
            item("cartUrl") = BuildCartAddUrl(_id, currentTcid)
            item("wishlistUrl") = BuildWishlistAddUrl(_id, currentTcid)

            Dim js As New System.Web.Script.Serialization.JavaScriptSerializer()
            litRecentlyViewedScript.Text = "<script>(function(){try{if(window.KeepStoreRecentlyViewed&&window.KeepStoreRecentlyViewed.add){window.KeepStoreRecentlyViewed.add(" & js.Serialize(item) & ");}}catch(e){}})();</script>"
        Catch ex As Exception
            litRecentlyViewedScript.Text = String.Empty
            KeepStoreLog.Error("articolo.aspx", "Errore EmitRecentlyViewedClientScript (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub BindBrandCarousel(row As DataRow)
        Try
            Dim items As List(Of BrandItem) = LoadBrandItems(row, 12)
            If items Is Nothing OrElse items.Count = 0 Then
                phBrands.Visible = False
                Return
            End If

            phBrands.Visible = True
            rptBrands.DataSource = items
            rptBrands.DataBind()
        Catch ex As Exception
            phBrands.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindBrandCarousel (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub BindRecentlyViewed(row As DataRow)
        Try
            Dim items As List(Of RelatedItem) = LoadRecentlyViewedProducts(row, 10)
            If items Is Nothing OrElse items.Count = 0 Then
                phRecentlyViewed.Visible = False
                Return
            End If

            phRecentlyViewed.Visible = True
            rptRecentlyViewed.DataSource = items
            rptRecentlyViewed.DataBind()
        Catch ex As Exception
            phRecentlyViewed.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindRecentlyViewed (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Function LoadRecentlyViewedProducts(row As DataRow, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        Dim orderedIds As List(Of Integer) = GetMergedRecentlyViewedIds(100)
        If Not orderedIds.Contains(_id) Then orderedIds.Insert(0, _id)

        Dim safeIds As New List(Of Integer)()
        For Each idVal As Integer In orderedIds
            If idVal > 0 AndAlso Not safeIds.Contains(idVal) Then safeIds.Add(idVal)
        Next

        If safeIds.Count > 0 Then
            Try
                Dim idsCsv As String = String.Join(",", safeIds.ToArray())
                Dim orderSql As New StringBuilder()
                orderSql.Append("CASE v.id ")
                For i As Integer = 0 To safeIds.Count - 1
                    orderSql.Append("WHEN ").Append(safeIds(i).ToString(CultureInfo.InvariantCulture)).Append(" THEN ").Append(i.ToString(CultureInfo.InvariantCulture)).Append(" ")
                Next
                orderSql.Append("ELSE 9999 END")

                Using conn As New MySqlConnection(GetConnectionString())
                    conn.Open()
                    Using cmd As New MySqlCommand()
                        cmd.Connection = conn
                        cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                           "WHERE v.NListino=?n AND v.id IN (" & idsCsv & ") " &
                                                           "ORDER BY " & orderSql.ToString() & " " &
                                                           "LIMIT " & SafeLimit(Math.Max(maxItems * 3, maxItems)))
                        cmd.Parameters.AddWithValue("?n", _listino)
                        AppendRelated(cmd, results, Math.Max(maxItems * 3, maxItems))
                    End Using
                End Using
            Catch ex As Exception
                KeepStoreLog.Error("articolo.aspx", "Errore LoadRecentlyViewedProducts query (id=" & _id.ToString() & ")", ex, HttpContext.Current)
            End Try
        End If

        Dim deduped As New List(Of RelatedItem)()
        AddUniqueRelatedItems(deduped, results, maxItems)

        If deduped.Count = 0 AndAlso row IsNot Nothing Then
            Dim currentItem As RelatedItem = BuildCurrentRelatedItem(row)
            If currentItem IsNot Nothing Then deduped.Add(currentItem)
        End If

        Return deduped
    End Function

    Private Function GetMergedRecentlyViewedIds(maxCount As Integer) As List(Of Integer)
        Dim result As New List(Of Integer)()
        MergeRecentIdsDeep(result, Convert.ToString(Session("ks_recent_ids")), maxCount)
        MergeRecentIdsDeep(result, Convert.ToString(Session("ks_recent_session")), maxCount)

        Dim cookie As HttpCookie = Request.Cookies("ks_recent")
        If cookie IsNot Nothing Then
            MergeRecentIdsDeep(result, HttpUtility.UrlDecode(cookie.Value), maxCount)
        End If

        Dim sessionCookie As HttpCookie = Request.Cookies("ks_recent_session")
        If sessionCookie IsNot Nothing Then
            MergeRecentIdsDeep(result, HttpUtility.UrlDecode(sessionCookie.Value), maxCount)
        End If

        Return result
    End Function

    Private Sub MergeRecentIdsDeep(target As List(Of Integer), raw As String, maxCount As Integer)
        If target Is Nothing OrElse String.IsNullOrWhiteSpace(raw) Then Exit Sub
        Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        For Each part As String In parts
            If target.Count >= maxCount Then Exit For
            Dim n As Integer
            If Integer.TryParse(part.Trim(), n) AndAlso n > 0 AndAlso Not target.Contains(n) Then
                target.Add(n)
            End If
        Next
    End Sub

    Private Function LoadBrandItems(row As DataRow, maxItems As Integer) As List(Of BrandItem)
        Dim results As New List(Of BrandItem)()
        Dim catId As Integer = GetRowInt(row, "CategorieId", 0)

        Using conn As New MySqlConnection(GetConnectionString())
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = "SELECT MarcheId, MarcheDescrizione, Marche_img, COUNT(*) AS Numero " &
                                  "FROM vsuperarticoli " &
                                  "WHERE NListino=?n AND MarcheId IS NOT NULL AND MarcheId>0 " &
                                  "  AND MarcheDescrizione IS NOT NULL AND TRIM(MarcheDescrizione)<>'' " &
                                  If(catId > 0, " AND CategorieId=?cat ", " ") &
                                  "GROUP BY MarcheId, MarcheDescrizione, Marche_img " &
                                  "ORDER BY Numero DESC, MarcheDescrizione ASC " &
                                  "LIMIT " & SafeLimit(maxItems)
                cmd.Parameters.AddWithValue("?n", _listino)
                If catId > 0 Then cmd.Parameters.AddWithValue("?cat", catId)

                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim brandId As Integer = SafeInt(rdr("MarcheId"), 0)
                        Dim brandName As String = Convert.ToString(rdr("MarcheDescrizione"))
                        If brandId <= 0 OrElse String.IsNullOrWhiteSpace(brandName) Then Continue While

                        Dim logoUrl As String = NormalizeBrandLogoUrl(Convert.ToString(rdr("Marche_img")))
                        Dim item As New BrandItem()
                        item.Nome = brandName
                        item.Url = ResolveUrl("~/articoli.aspx?mr=" & brandId.ToString())
                        item.LogoHtml = BuildBrandLogoHtml(brandName, logoUrl)
                        results.Add(item)
                    End While
                End Using
            End Using
        End Using

        Return results
    End Function

    Private Function NormalizeBrandLogoUrl(raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return ""

        Dim s As String = raw.Trim().Replace("\", "/")
        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        Dim fileOnly As String = IO.Path.GetFileName(s)
        If String.IsNullOrWhiteSpace(fileOnly) Then Return ""

        Dim rel As String = "~/Public/assets/images/marche/" & fileOnly
        Try
            If IO.File.Exists(Server.MapPath(rel)) Then
                Return ResolveUrl(rel)
            End If
        Catch
        End Try

        Return ""
    End Function

    Private Function BuildBrandLogoHtml(brandName As String, logoUrl As String) As String
        Dim safeName As String = Server.HtmlEncode(brandName)
        If Not String.IsNullOrEmpty(logoUrl) Then
            Return "<img src=""" & Server.HtmlEncode(logoUrl) & """ alt=""" & safeName & """ />"
        End If

        Return "<span class=""ks-brand-text"">" & safeName & "</span>"
    End Function

    Private Function BuildCategoryCatalogUrl(row As DataRow) As String
        Dim rel As String = "~/articoli.aspx"
        Dim parts As New List(Of String)()

        Dim stId As Integer = GetRowInt(row, "SettoriId", 0)
        Dim ctId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tpId As Integer = GetRowInt(row, "TipologieId", 0)

        If stId > 0 Then parts.Add("st=" & stId.ToString())
        If ctId > 0 Then parts.Add("ct=" & ctId.ToString())
        If tpId > 0 Then parts.Add("tp=" & tpId.ToString())

        If parts.Count > 0 Then rel &= "?" & String.Join("&", parts.ToArray())
        Return ResolveUrl(rel)
    End Function

    Private Function BuildBrandCatalogUrl(row As DataRow, brandId As Integer) As String
        Dim rel As String = "~/articoli.aspx"
        Dim parts As New List(Of String)()

        Dim stId As Integer = GetRowInt(row, "SettoriId", 0)
        Dim ctId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tpId As Integer = GetRowInt(row, "TipologieId", 0)

        If stId > 0 Then parts.Add("st=" & stId.ToString())
        If ctId > 0 Then parts.Add("ct=" & ctId.ToString())
        If tpId > 0 Then parts.Add("tp=" & tpId.ToString())
        If brandId > 0 Then parts.Add("mr=" & brandId.ToString())

        If parts.Count > 0 Then rel &= "?" & String.Join("&", parts.ToArray())
        Return ResolveUrl(rel)
    End Function

    Private Function NormalizeImageUrl(raw As String) As String
        Return ThemeManager.ProductImageUrl(raw)
    End Function

    Protected Sub ddlTc_SelectedIndexChanged(sender As Object, e As EventArgs)
        Dim selected As Integer
        If Not Integer.TryParse(ddlTc.SelectedValue, selected) Then
            selected = 0
        End If

        Response.Redirect(BuildProductUrl(_id, selected, includeTcid:=True), True)
    End Sub

    Protected Sub btnAddToCart_Click(sender As Object, e As EventArgs)
        Dim desiredQty As Integer = NormalizeCartQuantity(txtQty.Text, 1, 9999)
        txtQty.Text = desiredQty.ToString(CultureInfo.InvariantCulture)

        ' Risolve il TCid effettivo prima del redirect legacy verso aggiungi.aspx.
        Dim tcidToUse As Integer = _tcid
        If _tcEnabled Then
            tcidToUse = _tcid

            If pnlVariants.Visible Then
                Dim tmp As Integer
                If Integer.TryParse(ddlTc.SelectedValue, tmp) Then
                    tcidToUse = tmp
                End If
            End If
        End If

        Dim cartRow As DataRow = GetProductRow(_id, tcidToUse, includeTcidFilter:=(_tcEnabled AndAlso tcidToUse > 0))
        If cartRow Is Nothing Then
            cartRow = GetProductRow(_id, -1, includeTcidFilter:=False)
        End If

        If cartRow Is Nothing Then
            litQtyHelp.Text = "Articolo non disponibile per l'aggiunta al carrello."
            Return
        End If

        tcidToUse = GetRowInt(cartRow, "TCid", tcidToUse)

        Dim existingQty As Integer = GetPdpCartQuantity(_id, tcidToUse)
        Dim qtyToAdd As Integer = If(existingQty > 0, desiredQty - existingQty, desiredQty)
        If qtyToAdd <= 0 Then
            ApplyPdpCartState(existingQty, False)
            txtQty.Text = existingQty.ToString(CultureInfo.InvariantCulture)
            litQtyHelp.Text = Server.HtmlEncode("Nel carrello sono gia presenti " & existingQty.ToString(CultureInfo.GetCultureInfo("it-IT")) & " pezzi. Aumenta la quantita se vuoi aggiungerne altri.")
            Return
        End If

        Session("ProdottoGratis") = GetRowInt(cartRow, "SpeditoGratis", 0)
        Session("Carrello_ArticoloId") = _id.ToString()
        Session("Carrello_TCId") = tcidToUse.ToString()
        Session("Carrello_Quantita") = qtyToAdd.ToString(CultureInfo.InvariantCulture)
        Session("Carrello_Pagina") = Request.RawUrl
        Session("Carrello_SelezioneMultipla") = Nothing

        Dim addToCartUrl As String = "aggiungi.aspx?id=" & HttpUtility.UrlEncode(_id.ToString(CultureInfo.InvariantCulture)) &
                                      "&TCid=" & HttpUtility.UrlEncode(tcidToUse.ToString(CultureInfo.InvariantCulture)) &
                                      "&qty=" & HttpUtility.UrlEncode(qtyToAdd.ToString(CultureInfo.InvariantCulture))

        Response.Redirect(addToCartUrl, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Sub BindPdpCartState(ByVal articleId As Integer, ByVal tcId As Integer, ByVal initializeInput As Boolean)
        Dim existingQty As Integer = GetPdpCartQuantity(articleId, tcId)
        ApplyPdpCartState(existingQty, initializeInput)
        litQtyHelp.Text = ""
    End Sub

    Private Sub ApplyPdpCartState(ByVal existingQty As Integer, ByVal initializeInput As Boolean)
        Dim hasCartQuantity As Boolean = existingQty > 0
        pnlPdpCartState.Visible = hasCartQuantity

        If hasCartQuantity Then
            Dim quantityText As String = existingQty.ToString(CultureInfo.GetCultureInfo("it-IT"))
            Dim label As String = "Nel carrello: " & quantityText
            litPdpCartQty.Text = quantityText
            pnlPdpCartState.ToolTip = label
            pnlPdpCartState.Attributes("aria-label") = label
            If initializeInput Then txtQty.Text = existingQty.ToString(CultureInfo.InvariantCulture)
        Else
            litPdpCartQty.Text = ""
            pnlPdpCartState.ToolTip = ""
            pnlPdpCartState.Attributes.Remove("aria-label")
            If initializeInput Then txtQty.Text = "1"
        End If
    End Sub

    Private Function GetPdpCartQuantity(ByVal articleId As Integer, ByVal tcId As Integer) As Integer
        Try
            Dim quantity As Decimal = CartStateSnapshotProvider.GetCurrent(HttpContext.Current).GetQuantity(articleId, tcId)
            If quantity <= 0D Then Return 0
            If quantity >= 9999D Then Return 9999
            Return Math.Max(0, Convert.ToInt32(Decimal.Truncate(quantity)))
        Catch
            Return 0
        End Try
    End Function

    Protected Sub btnBundleAddToCart_Click(sender As Object, e As EventArgs)
        Dim bundleItems As ArrayList = TryCast(Session("ks_product_bundle_cart_items"), ArrayList)
        If bundleItems Is Nothing OrElse bundleItems.Count = 0 Then
            btnAddToCart_Click(sender, e)
            Return
        End If

        Session("ProdottoGratis") = 0
        Session("Carrello_ArticoloId") = "0"
        Session("Carrello_TCId") = Nothing
        Session("Carrello_Quantita") = "1"
        Session("Carrello_Pagina") = Request.RawUrl
        Session("Carrello_SelezioneMultipla") = bundleItems

        Response.Redirect("aggiungi.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function NormalizeCartQuantity(ByVal rawValue As String, ByVal fallbackValue As Integer, ByVal maxValue As Integer) As Integer
        Dim qty As Integer = fallbackValue
        If Not Integer.TryParse(Convert.ToString(rawValue), qty) Then
            qty = fallbackValue
        End If

        If qty <= 0 Then qty = fallbackValue
        If qty > maxValue Then qty = maxValue

        Return qty
    End Function

    Private Sub BindProductReviews()
        SetReviewDefaults()

        Try
            EnsureReviewsTable()

            Dim reviews As List(Of ReviewItem) = LoadProductReviews(_id)
            Dim counts As Integer() = New Integer(5) {}
            Dim totalRating As Integer = 0

            For Each item As ReviewItem In reviews
                If item.Rating >= 1 AndAlso item.Rating <= 5 Then
                    counts(item.Rating) += 1
                    totalRating += item.Rating
                End If
            Next

            Dim reviewCount As Integer = reviews.Count
            If reviewCount > 0 Then
                Dim average As Decimal = Convert.ToDecimal(totalRating) / Convert.ToDecimal(reviewCount)
                litReviewAverage.Text = average.ToString("0.0", ItCulture)
                litReviewCountText.Text = If(reviewCount = 1, "1 recensione verificata da KeepStore.", reviewCount.ToString(ItCulture) & " recensioni verificate da KeepStore.")
                litHeaderReviewText.Text = litReviewCountText.Text
            Else
                litReviewAverage.Text = "0"
                litReviewCountText.Text = "Ancora nessuna valutazione."
                litHeaderReviewText.Text = "Nessuna recensione"
            End If

            litReviewDistribution.Text = BuildReviewDistributionHtml(counts, reviewCount)
            phReviewEmpty.Visible = (reviewCount = 0)
            rptProductReviews.DataSource = reviews
            rptProductReviews.DataBind()

            Dim flash As String = Convert.ToString(Session("ks_review_flash"))
            If Not String.IsNullOrWhiteSpace(flash) Then
                litReviewMessage.Text = BuildReviewMessage("success", flash)
                Session("ks_review_flash") = Nothing
            End If
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore BindProductReviews (id=" & _id.ToString() & ")", ex, HttpContext.Current)
            litReviewMessage.Text = BuildReviewMessage("warning", "Le recensioni non sono temporaneamente disponibili. Puoi continuare la navigazione e riprovare piu tardi.")
            phReviewEmpty.Visible = False
            rptProductReviews.DataSource = New List(Of ReviewItem)()
            rptProductReviews.DataBind()
        End Try
    End Sub

    Private Sub SetReviewDefaults()
        litReviewAverage.Text = "0"
        litReviewCountText.Text = "Ancora nessuna valutazione."
        litReviewDistribution.Text = BuildReviewDistributionHtml(New Integer(5) {}, 0)
        litHeaderReviewText.Text = "Nessuna recensione"
        litReviewMessage.Text = String.Empty
        phReviewEmpty.Visible = True

        If Not IsPostBack Then
            txtReviewName.Text = FirstNonEmpty(Convert.ToString(Session("Nome")), Convert.ToString(Session("NomeCliente")), Convert.ToString(Session("RagioneSociale")))
            txtReviewEmail.Text = FirstNonEmpty(Convert.ToString(Session("Email")), Convert.ToString(Session("EmailCliente")), Convert.ToString(Session("UserName")))
        End If
    End Sub

    Private Sub EnsureReviewsTable()
        Dim sql As String =
            "CREATE TABLE IF NOT EXISTS articoli_recensioni (" &
            "id INT NOT NULL AUTO_INCREMENT," &
            "ArticoliId INT NOT NULL," &
            "TCid INT NOT NULL DEFAULT -1," &
            "UtentiId INT NOT NULL DEFAULT 0," &
            "Nome VARCHAR(120) NOT NULL DEFAULT ''," &
            "Email VARCHAR(180) NOT NULL DEFAULT ''," &
            "Rating TINYINT NOT NULL," &
            "Titolo VARCHAR(160) NOT NULL DEFAULT ''," &
            "Testo TEXT NOT NULL," &
            "Approvata TINYINT NOT NULL DEFAULT 1," &
            "Verificata TINYINT NOT NULL DEFAULT 0," &
            "Fonte VARCHAR(30) NOT NULL DEFAULT 'articolo.aspx'," &
            "Ip VARCHAR(45) NOT NULL DEFAULT ''," &
            "UserAgent VARCHAR(255) NOT NULL DEFAULT ''," &
            "DataCreazione DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP," &
            "DataAggiornamento DATETIME NULL," &
            "PRIMARY KEY(id)," &
            "KEY idx_articolo_app (ArticoliId, Approvata, DataCreazione)," &
            "KEY idx_articolo_tcid (ArticoliId, TCid)," &
            "KEY idx_utente (UtentiId)" &
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8"

        Using cn As New MySqlConnection(GetConnectionString())
            cn.Open()

            Try
                Using checkCmd As New MySqlCommand("SELECT 1 FROM articoli_recensioni LIMIT 1", cn)
                    checkCmd.ExecuteScalar()
                    Return
                End Using
            Catch ex As MySqlException
                If ex.Number <> 1146 Then
                    Throw
                End If
            End Try

            Using cmd As New MySqlCommand(sql, cn)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    Private Function LoadProductReviews(productId As Integer) As List(Of ReviewItem)
        Dim results As New List(Of ReviewItem)()
        If productId <= 0 Then Return results

        Using cn As New MySqlConnection(GetConnectionString())
            cn.Open()
            Using cmd As New MySqlCommand("SELECT Rating, Titolo, Testo, Nome, Verificata, DataCreazione FROM articoli_recensioni WHERE ArticoliId=@id AND Approvata=1 ORDER BY DataCreazione DESC, id DESC LIMIT 50", cn)
                cmd.Parameters.AddWithValue("@id", productId)
                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim rating As Integer = SafeInt(rdr("Rating"), 0)
                        If rating < 1 OrElse rating > 5 Then Continue While

                        Dim item As New ReviewItem()
                        item.Rating = rating
                        item.RatingText = rating.ToString(ItCulture) & "/5"
                        item.StarsHtml = BuildReviewStarsHtml(rating)
                        item.TitleText = Server.HtmlEncode(FirstNonEmpty(Convert.ToString(rdr("Titolo")), "Recensione prodotto"))
                        item.BodyText = Server.HtmlEncode(Convert.ToString(rdr("Testo")))
                        item.AuthorText = Server.HtmlEncode(FirstNonEmpty(Convert.ToString(rdr("Nome")), "Cliente KeepStore"))
                        item.Verified = (SafeInt(rdr("Verificata"), 0) = 1)

                        Dim reviewDate As DateTime
                        If rdr("DataCreazione") IsNot DBNull.Value AndAlso DateTime.TryParse(Convert.ToString(rdr("DataCreazione")), reviewDate) Then
                            item.DateText = reviewDate.ToString("dd MMM yyyy", ItCulture)
                        Else
                            item.DateText = ""
                        End If

                        results.Add(item)
                    End While
                End Using
            End Using
        End Using

        Return results
    End Function

    Protected Sub btnReviewSubmit_Click(sender As Object, e As EventArgs)
        Dim message As String = ""
        Dim rating As Integer = 0
        Dim reviewerName As String = ""
        Dim reviewerEmail As String = ""
        Dim title As String = ""
        Dim body As String = ""

        Try
            If Not ValidateReviewInput(rating, reviewerName, reviewerEmail, title, body, message) Then
                LoadPage()
                litReviewMessage.Text = BuildReviewMessage("danger", message)
                Return
            End If

            EnsureReviewsTable()

            If IsDuplicateReview(_id, reviewerEmail, body) Then
                LoadPage()
                litReviewMessage.Text = BuildReviewMessage("warning", "Questa recensione risulta gia inserita di recente.")
                Return
            End If

            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand("INSERT INTO articoli_recensioni (ArticoliId, TCid, UtentiId, Nome, Email, Rating, Titolo, Testo, Approvata, Verificata, Fonte, Ip, UserAgent, DataCreazione) VALUES (@articolo, @tcid, @utente, @nome, @email, @rating, @titolo, @testo, @approvata, @verificata, @fonte, @ip, @ua, NOW())", cn)
                    cmd.Parameters.AddWithValue("@articolo", _id)
                    cmd.Parameters.AddWithValue("@tcid", _tcid)
                    cmd.Parameters.AddWithValue("@utente", GetCurrentUserId())
                    cmd.Parameters.AddWithValue("@nome", reviewerName)
                    cmd.Parameters.AddWithValue("@email", reviewerEmail)
                    cmd.Parameters.AddWithValue("@rating", rating)
                    cmd.Parameters.AddWithValue("@titolo", title)
                    cmd.Parameters.AddWithValue("@testo", body)
                    cmd.Parameters.AddWithValue("@approvata", 1)
                    cmd.Parameters.AddWithValue("@verificata", 0)
                    cmd.Parameters.AddWithValue("@fonte", "articolo.aspx")
                    cmd.Parameters.AddWithValue("@ip", GetClientIp())
                    cmd.Parameters.AddWithValue("@ua", LimitText(Convert.ToString(Request.UserAgent), 255))
                    cmd.ExecuteNonQuery()
                End Using
            End Using

            Session("ks_review_last_submit") = DateTime.UtcNow
            Session("ks_review_flash") = "Grazie, la recensione e stata salvata su KeepStore."

            Dim redirectUrl As String = Request.RawUrl
            If redirectUrl.IndexOf("#", StringComparison.Ordinal) >= 0 Then
                redirectUrl = redirectUrl.Substring(0, redirectUrl.IndexOf("#", StringComparison.Ordinal))
            End If
            Response.Redirect(redirectUrl & "#prd-review", False)
            Context.ApplicationInstance.CompleteRequest()
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore salvataggio recensione (id=" & _id.ToString() & ")", ex, HttpContext.Current)
            LoadPage()
            litReviewMessage.Text = BuildReviewMessage("danger", "Non e stato possibile salvare la recensione. Riprova tra qualche minuto.")
        End Try
    End Sub

    Private Function ValidateReviewInput(ByRef rating As Integer, ByRef reviewerName As String, ByRef reviewerEmail As String, ByRef title As String, ByRef body As String, ByRef message As String) As Boolean
        If Not Integer.TryParse(Convert.ToString(ddlReviewRating.SelectedValue), rating) OrElse rating < 1 OrElse rating > 5 Then
            message = "Seleziona una valutazione valida."
            Return False
        End If

        reviewerName = CleanReviewText(txtReviewName.Text, 120)
        reviewerEmail = CleanReviewText(txtReviewEmail.Text, 180)
        title = CleanReviewText(txtReviewTitle.Text, 160)
        body = CleanReviewText(txtReviewText.Text, 1000)

        If reviewerName.Length < 2 Then
            message = "Inserisci il tuo nome."
            Return False
        End If

        If Not IsValidEmail(reviewerEmail) Then
            message = "Inserisci un indirizzo email valido. L'email non viene mostrata pubblicamente."
            Return False
        End If

        If title.Length = 0 Then
            title = "Recensione prodotto"
        End If

        If body.Length < 20 Then
            message = "Scrivi un commento di almeno 20 caratteri, utile agli altri clienti."
            Return False
        End If

        If LooksLikeSpam(title & " " & body) Then
            message = "La recensione contiene elementi non ammessi. Rimuovi link, testo ripetuto o contenuti promozionali."
            Return False
        End If

        Dim lastSubmit As Object = Session("ks_review_last_submit")
        If lastSubmit IsNot Nothing Then
            Dim lastDate As DateTime
            If DateTime.TryParse(Convert.ToString(lastSubmit), lastDate) AndAlso DateTime.UtcNow.Subtract(lastDate).TotalSeconds < 20 Then
                message = "Attendi qualche secondo prima di inviare una nuova recensione."
                Return False
            End If
        End If

        Return True
    End Function

    Private Function IsDuplicateReview(productId As Integer, email As String, body As String) As Boolean
        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand("SELECT COUNT(*) FROM articoli_recensioni WHERE ArticoliId=@id AND (Email=@email OR Ip=@ip) AND Testo=@testo AND DataCreazione >= DATE_SUB(NOW(), INTERVAL 1 DAY)", cn)
                    cmd.Parameters.AddWithValue("@id", productId)
                    cmd.Parameters.AddWithValue("@email", email)
                    cmd.Parameters.AddWithValue("@ip", GetClientIp())
                    cmd.Parameters.AddWithValue("@testo", body)
                    Return SafeInt(cmd.ExecuteScalar(), 0) > 0
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function BuildReviewDistributionHtml(counts As Integer(), total As Integer) As String
        Dim sb As New StringBuilder()
        For star As Integer = 5 To 1 Step -1
            Dim starCount As Integer = 0
            If counts IsNot Nothing AndAlso counts.Length > star Then starCount = counts(star)
            Dim pct As Integer = If(total > 0, CInt(Math.Round((Convert.ToDecimal(starCount) / Convert.ToDecimal(total)) * 100D)), 0)
            sb.Append("<li>")
            sb.Append("<p class=""start-number body-text-3"">").Append(star.ToString(ItCulture)).Append("<i class=""icon-star text-third""></i></p>")
            sb.Append("<div class=""rating-progress""><div class=""progress style-2"" role=""progressbar"" aria-valuenow=""").Append(pct.ToString(ItCulture)).Append(""" aria-valuemin=""0"" aria-valuemax=""100""><div class=""progress-bar"" style=""width:").Append(pct.ToString(ItCulture)).Append("%;""></div></div></div>")
            sb.Append("<p class=""count-review body-text-3"">").Append(starCount.ToString(ItCulture)).Append("</p>")
            sb.Append("</li>")
        Next
        Return sb.ToString()
    End Function

    Private Function BuildReviewStarsHtml(rating As Integer) As String
        Dim sb As New StringBuilder()
        For i As Integer = 1 To 5
            Dim css As String = If(i <= rating, "text-main-4", "text-main-3")
            sb.Append("<li><i class=""icon-star ").Append(css).Append("""></i></li>")
        Next
        Return sb.ToString()
    End Function

    Private Function BuildReviewMessage(cssName As String, text As String) As String
        If String.IsNullOrWhiteSpace(text) Then Return ""
        Return "<div class=""alert alert-" & Server.HtmlEncode(cssName) & " ks-review-message"">" & Server.HtmlEncode(text) & "</div>"
    End Function

    Private Function CleanReviewText(value As String, maxLength As Integer) As String
        Dim cleaned As String = HttpUtility.HtmlDecode(StripHtml(Convert.ToString(value)))
        cleaned = NormalizeWhitespace(cleaned)
        Return LimitText(cleaned, maxLength)
    End Function

    Private Function LimitText(value As String, maxLength As Integer) As String
        Dim text As String = Convert.ToString(value)
        If String.IsNullOrEmpty(text) Then Return ""
        If maxLength > 0 AndAlso text.Length > maxLength Then
            text = text.Substring(0, maxLength).Trim()
        End If
        Return text
    End Function

    Private Function LooksLikeSpam(value As String) As Boolean
        Dim text As String = Convert.ToString(value).ToLowerInvariant()
        If Regex.Matches(text, "https?://|www\.").Count > 0 Then Return True
        If Regex.IsMatch(text, "(.)\1{12,}") Then Return True
        If Regex.Matches(text, "\b(casino|crypto|bitcoin|forex|viagra|loan|escort|telegram|whatsapp)\b").Count > 0 Then Return True
        If text.Length > 0 Then
            Dim letters As MatchCollection = Regex.Matches(text, "[a-z0-9]")
            If letters.Count > 30 Then
                Dim unique As New HashSet(Of Char)()
                For Each ch As Char In text
                    If Char.IsLetterOrDigit(ch) Then unique.Add(ch)
                Next
                If unique.Count <= 4 Then Return True
            End If
        End If
        Return False
    End Function

    Private Function IsValidEmail(value As String) As Boolean
        If String.IsNullOrWhiteSpace(value) OrElse value.Length > 180 Then Return False
        Return Regex.IsMatch(value, "^[^@\s]+@[^@\s]+\.[^@\s]+$")
    End Function

    Private Function GetCurrentUserId() As Integer
        Return FirstPositiveInt(GetSessionInt("UtenteId", 0),
                                GetSessionInt("UserId", 0),
                                GetSessionInt("ClienteId", 0),
                                GetSessionInt("ClientiId", 0),
                                GetSessionInt("IdUtente", 0),
                                GetSessionInt("IDUtente", 0))
    End Function

    Private Function GetClientIp() As String
        Dim forwarded As String = Convert.ToString(Request.ServerVariables("HTTP_X_FORWARDED_FOR"))
        If Not String.IsNullOrWhiteSpace(forwarded) Then
            Dim parts As String() = forwarded.Split(","c)
            If parts.Length > 0 Then Return LimitText(parts(0).Trim(), 45)
        End If
        Return LimitText(Convert.ToString(Request.UserHostAddress), 45)
    End Function

    Private Sub TrackRecentlyViewed(productId As Integer)
        If productId <= 0 Then Exit Sub

        Try
            Dim ids As New List(Of Integer)()
            Dim sessionRaw As String = Convert.ToString(Session("ks_recent_ids"))
            If Not String.IsNullOrWhiteSpace(sessionRaw) Then
                Dim sessionParts As String() = sessionRaw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
                For Each part As String In sessionParts
                    Dim n As Integer
                    If Integer.TryParse(part.Trim(), n) AndAlso n > 0 AndAlso n <> productId Then
                        If Not ids.Contains(n) Then
                            ids.Add(n)
                        End If
                    End If
                Next
            End If

            Dim existing As HttpCookie = Request.Cookies("ks_recent")

            If existing IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(existing.Value) Then
                Dim raw As String = HttpUtility.UrlDecode(existing.Value)
                If Not String.IsNullOrWhiteSpace(raw) Then
                    Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
                    For Each part As String In parts
                        Dim n As Integer
                        If Integer.TryParse(part.Trim(), n) AndAlso n > 0 AndAlso n <> productId Then
                            If Not ids.Contains(n) Then
                                ids.Add(n)
                            End If
                        End If
                    Next
                End If
            End If

            ids.Insert(0, productId)
            If ids.Count > 100 Then
                ids.RemoveRange(100, ids.Count - 100)
            End If

            Dim cookie As New HttpCookie("ks_recent")
            cookie.Value = HttpUtility.UrlEncode(String.Join(",", ids.ToArray()))
            cookie.Path = "/"
            cookie.Expires = DateTime.Now.AddDays(30)
            cookie.HttpOnly = False
            Response.Cookies.Add(cookie)

            Dim orderedRecentIds As String = String.Join(",", ids.ToArray())
            Session("ks_recent_ids") = orderedRecentIds
            Session("ks_recent_session") = orderedRecentIds

            Dim sessionCookie As New HttpCookie("ks_recent_session")
            sessionCookie.Value = HttpUtility.UrlEncode(orderedRecentIds)
            sessionCookie.Path = "/"
            sessionCookie.HttpOnly = False
            Response.Cookies.Add(sessionCookie)
        Catch
            ' Best effort: la pagina prodotto non deve rompersi se la scrittura cookie fallisce.
        End Try
    End Sub

    Private Function BuildProductUrl(id As Integer, tcid As Integer, includeTcid As Boolean) As String
        Dim rel As String = "~/articolo.aspx?id=" & id.ToString()
        If includeTcid Then
            rel &= "&TCid=" & tcid.ToString()
        End If
        Return ResolveUrl(rel)
    End Function

    Private Sub ShowNotFound()
        pnlProduct.Visible = False
        phNotFound.Visible = True
        litBreadcrumbCurrent.Text = "Articolo"

        ' SEO: 404 soft (noindex) + canonical verso listing
        SeoBuilder.AddOrReplaceNameMeta(Page, "robots", "noindex,follow")
        SeoBuilder.SetCanonical(Page, MakeAbsoluteUrl(ResolveUrl("~/articoli.aspx")))
    End Sub

    '----- Helpers: safe read + session -----

    Private Function GetRowString(row As DataRow, col As String) As String
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) Then
            Return ""
        End If
        If row.IsNull(col) Then Return ""
        Return Convert.ToString(row(col))
    End Function

    Private Function GetRowInt(row As DataRow, col As String, defaultValue As Integer) As Integer
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) OrElse row.IsNull(col) Then
            Return defaultValue
        End If
        Dim tmp As Integer
        If Integer.TryParse(Convert.ToString(row(col)), tmp) Then
            Return tmp
        End If
        Return defaultValue
    End Function

    Private Function GetRowDecimal(row As DataRow, col As String) As Nullable(Of Decimal)
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) OrElse row.IsNull(col) Then
            Return Nothing
        End If
        Dim tmp As Decimal
        If TryParseKeepStoreDecimal(row(col), tmp) Then
            Return tmp
        End If
        Return Nothing
    End Function

    Private Function TryParseKeepStoreDecimal(value As Object, ByRef result As Decimal) As Boolean
        result = 0D
        If value Is Nothing OrElse value Is DBNull.Value Then Return False

        If TypeOf value Is Decimal OrElse
           TypeOf value Is Double OrElse
           TypeOf value Is Single OrElse
           TypeOf value Is Integer OrElse
           TypeOf value Is Long OrElse
           TypeOf value Is Short OrElse
           TypeOf value Is Byte Then
            Try
                result = Convert.ToDecimal(value, CultureInfo.InvariantCulture)
                Return True
            Catch
            End Try
        End If

        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return False

        s = s.Trim().Replace(ChrW(8364), String.Empty).Replace("EUR", String.Empty).Trim()

        Dim commaIndex As Integer = s.LastIndexOf(","c)
        Dim dotIndex As Integer = s.LastIndexOf("."c)
        Dim normalized As String = s

        If commaIndex >= 0 AndAlso dotIndex >= 0 Then
            If commaIndex > dotIndex Then
                normalized = s.Replace(".", String.Empty).Replace(",", ".")
            Else
                normalized = s.Replace(",", String.Empty)
            End If
            If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
        End If

        If commaIndex >= 0 AndAlso dotIndex < 0 Then
            normalized = s.Replace(",", ".")
            If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
        End If

        If dotIndex >= 0 AndAlso commaIndex < 0 Then
            If Regex.IsMatch(s, "^\s*\d+\.\d{1,4}\s*$") Then
                If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
            End If

            If Regex.IsMatch(s, "^\s*\d{1,3}(\.\d{3})+(\.\d{1,4})?\s*$") Then
                normalized = s.Replace(".", String.Empty)
                If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
            End If
        End If

        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
        If Decimal.TryParse(s, NumberStyles.Any, ItCulture, result) Then Return True
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, result) Then Return True
        Return False
    End Function

    Private Function GetSessionInt(key As String, defaultValue As Integer) As Integer
        Try
            If Session(key) Is Nothing Then Return defaultValue
            Dim tmp As Integer
            If Integer.TryParse(Convert.ToString(Session(key)), tmp) Then
                Return tmp
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then Return ""
        For Each v As String In values
            If Not String.IsNullOrEmpty(v) Then
                Dim s As String = v.Trim()
                If s.Length > 0 Then Return s
            End If
        Next
        Return ""
    End Function

    Private Function FirstPositiveInt(ParamArray values() As Integer) As Integer
        If values Is Nothing Then Return 0
        For Each v As Integer In values
            If v > 0 Then Return v
        Next
        Return 0
    End Function

    Private Function GetConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function

    Private Function GetCurrentAziendaId() As Integer
        Return FirstPositiveInt(GetSessionInt("AziendaID", 0),
                                GetSessionInt("AziendaId", 0),
                                GetSessionInt("AziendeId", 0))
    End Function

    Private Sub EnsureArticleCompanyContext()
        Try
            If Request Is Nothing OrElse Request.Url Is Nothing Then Return

            Dim host As String = Convert.ToString(Request.Url.Host)
            If String.IsNullOrWhiteSpace(host) Then Return
            host = host.Trim()
            If host.Length > 255 Then host = host.Substring(0, 255)

            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand("SELECT Id, ListinoDefault, ListinoUser, IvaTipo, DispoTipo, url1, url2 FROM aziende WHERE (url1 LIKE @dominio OR url2 LIKE @dominio) LIMIT 1", cn)
                    cmd.Parameters.AddWithValue("@dominio", "%" & host & "%")
                    Using rdr As MySqlDataReader = cmd.ExecuteReader()
                        If Not rdr.Read() Then Return

                        Dim aziendaId As Integer = SafeReaderInt(rdr, "Id", 0)
                        If aziendaId <= 0 Then Return

                        Session("AziendaID") = aziendaId
                        Session("AziendaId") = aziendaId
                        Session("AziendeId") = aziendaId

                        Dim ivaTipo As Integer = SafeReaderInt(rdr, "IvaTipo", 0)
                        If ivaTipo > 0 Then Session("IvaTipo") = ivaTipo

                        Dim dispoTipo As Integer = SafeReaderInt(rdr, "DispoTipo", 0)
                        If dispoTipo > 0 Then Session("DispoTipo") = dispoTipo

                        Dim isLogged As Boolean = (GetSessionInt("LoginId", 0) > 0 OrElse GetSessionInt("LoginID", 0) > 0)
                        Dim defaultListino As Integer = SafeReaderInt(rdr, "ListinoDefault", 0)
                        If defaultListino > 0 AndAlso (Not isLogged OrElse GetCurrentListinoValueOnly() <= 0) Then
                            Session("Listino") = defaultListino
                            Session("listino") = defaultListino
                        End If

                        Dim listinoUser As Integer = SafeReaderInt(rdr, "ListinoUser", 0)
                        If listinoUser > 0 Then Session("ListinoUser") = listinoUser
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore EnsureArticleCompanyContext", ex, HttpContext.Current)
        End Try
    End Sub

    Private Function GetCurrentListinoValueOnly() As Integer
        Dim n As Integer = GetSessionInt("Listino", 0)
        If n <= 0 Then n = GetSessionInt("listino", 0)
        Return n
    End Function

    ' Listino robusto: usa Session("Listino") come fonte principale, con fallback a Session("listino").
    ' Imposta anche in Session per coerenza con le altre pagine.
    Private Function GetCurrentListino() As Integer
        Dim n As Integer = 0

        n = GetSessionInt("Listino", 0)
        If n <= 0 Then
            n = GetSessionInt("listino", 0)
        End If

        If n <= 0 Then
            n = 1
        End If

        ' Mantengo entrambe le chiavi per compatibilità con codice legacy
        Session("Listino") = n
        Session("listino") = n

        Return n
    End Function



    ' VB2012-safe conversion helper (DBNull/Null -> 0)
    Private Function SafeToInt(ByVal o As Object) As Integer
        Try
            If o Is Nothing OrElse o Is DBNull.Value Then Return 0
            Dim s As String = Convert.ToString(o)
            Dim n As Integer = 0
            If Integer.TryParse(s, n) Then Return n
        Catch
        End Try
        Return 0
    End Function

    Private Function SafeReaderInt(rdr As MySqlDataReader, columnName As String, fallback As Integer) As Integer
        If rdr Is Nothing OrElse String.IsNullOrWhiteSpace(columnName) Then Return fallback
        Try
            Dim ordinal As Integer = rdr.GetOrdinal(columnName)
            If ordinal < 0 OrElse rdr.IsDBNull(ordinal) Then Return fallback
            Dim value As Integer
            If Integer.TryParse(Convert.ToString(rdr.GetValue(ordinal)), value) Then Return value
        Catch
        End Try
        Return fallback
    End Function

End Class
