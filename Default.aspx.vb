Imports System
Imports System.Configuration
Imports System.Data
Imports System.Data.Common
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

Partial Public Class _Default
    Inherits Page

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        MarkBodyAsHome()
        If Not IsPostBack Then
            BindHome()
        End If
    End Sub

    Private Sub MarkBodyAsHome()
        Try
            Dim body = TryCast(Master.FindControl("PageBody"), HtmlGenericControl)
            If body IsNot Nothing Then
                Dim current = Convert.ToString(body.Attributes("class"))
                If current.IndexOf("ks-page-home", StringComparison.OrdinalIgnoreCase) < 0 Then
                    body.Attributes("class") = (current & " ks-page-home").Trim()
                End If
            End If
        Catch
        End Try
    End Sub

    Private Sub BindHome()
        Dim hero = GetHeroSlides()
        rptHeroSlides.DataSource = hero
        rptHeroSlides.DataBind()

        Dim sideBanners = GetSideBanners()
        rptSideBanners.DataSource = sideBanners
        rptSideBanners.DataBind()

        Dim deal = GetDealOfDayProducts(12)
        rptDealOfDay.DataSource = deal
        rptDealOfDay.DataBind()

        BindThreeColumnZone(GetFeaturedZoneProducts(7), rptFeatureLeft, rptFeatureCenter, rptFeatureRight)
        BindThreeColumnZone(GetTopRateZoneProducts(7), rptToprateLeft, rptToprateCenter, rptToprateRight)
        BindThreeColumnZone(GetOnSaleZoneProducts(7), rptOnSaleLeft, rptOnSaleCenter, rptOnSaleRight)

        rptBestSeller.DataSource = GetBestSellerProducts(12)
        rptBestSeller.DataBind()

        rptTop20Slides.DataSource = BuildSlidesTable(GetTop20Products(10), 5)
        rptTop20Slides.DataBind()

        rptFeaturedProductsSlides.DataSource = BuildSlidesTable(GetFeaturedProductsList(10), 5)
        rptFeaturedProductsSlides.DataBind()

        rptTopSellingProductSlides.DataSource = BuildSlidesTable(GetTopSellingProductsList(10), 5)
        rptTopSellingProductSlides.DataBind()

        rptOnSaleProductSlides.DataSource = BuildSlidesTable(GetOnSaleZoneProducts(10), 5)
        rptOnSaleProductSlides.DataBind()

        rptBrands.DataSource = GetBrands(12)
        rptBrands.DataBind()

        rptRecentlyViewed.DataSource = GetRecentlyViewedProducts(12)
        rptRecentlyViewed.DataBind()
    End Sub

    Private Sub BindThreeColumnZone(ByVal source As DataTable, ByVal leftRepeater As Repeater, ByVal centerRepeater As Repeater, ByVal rightRepeater As Repeater)
        Dim work = EnsureMinimumRows(source, 7)
        leftRepeater.DataSource = SliceTable(work, 0, 3)
        leftRepeater.DataBind()
        centerRepeater.DataSource = SliceTable(work, 3, 1)
        centerRepeater.DataBind()
        rightRepeater.DataSource = SliceTable(work, 4, 3)
        rightRepeater.DataBind()
    End Sub

    Private Function BuildSlidesTable(ByVal source As DataTable, ByVal groupSize As Integer) As DataTable
        Dim result As New DataTable()
        result.Columns.Add("Html", GetType(String))

        Dim effectiveGroupSize As Integer = Math.Max(groupSize, 1)
        Dim work = source
        If work Is Nothing OrElse work.Rows.Count = 0 Then
            work = SampleProducts(Math.Max(effectiveGroupSize * 2, 10))
        End If

        Dim total As Integer = work.Rows.Count
        Dim index As Integer = 0
        While index < total
            Dim sb As New StringBuilder()
            sb.Append("<ul class='product-list-wrap'>")
            Dim upper As Integer = Math.Min(index + effectiveGroupSize - 1, total - 1)
            For i As Integer = index To upper
                sb.Append("<li class='wow fadeInUp' data-wow-delay='0s'>")
                sb.Append(RenderRowCardFromRow(work.Rows(i)))
                sb.Append("</li>")
            Next
            sb.Append("</ul>")
            result.Rows.Add(sb.ToString())
            index += effectiveGroupSize
        End While

        If result.Rows.Count = 0 Then
            result.Rows.Add("<ul class='product-list-wrap'></ul>")
        End If

        Return result
    End Function

    Private Function RenderRowCardFromRow(ByVal row As DataRow) As String
        If row Is Nothing Then Return String.Empty
        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-row row-small-2'>")
        sb.Append("<div class='card-product-wrapper'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='product-img'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageThumb(row("Img1"))).Append("' data-src='").Append(ProductImageThumb(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a></div>")
        sb.Append("<div class='card-product-info'><div class='box-title'>")
        sb.Append("<div class='bg-white relative z-5'><p class='caption text-main-2 font-2'>").Append(HttpUtility.HtmlEncode(Convert.ToString(row("Descrizione2")))).Append("</p>")
        sb.Append("<h6><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6></div>")
        sb.Append("<p class='price-wrap fw-medium'><span class='new-price h6 fw-normal text-primary mb-0'>").Append(FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</span>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append(" <span class='old-price'>").Append(FormatMoney(row("PrezzoIvato"))).Append("</span>")
        End If
        sb.Append("</p></div></div></div>")
        Return sb.ToString()
    End Function

    Private Function GetHeroSlides() As DataTable
        Dim sql As String = "SELECT id, caption AS Caption, image AS Image, link AS LinkUrl FROM slideshow_new WHERE (start_date IS NULL OR start_date <= CURDATE()) AND (stop_date IS NULL OR stop_date >= CURDATE()) ORDER BY id DESC LIMIT 5"
        Dim dt As DataTable = SafeQuery(sql, HeroSlidesFallback())
        If Not dt.Columns.Contains("Eyebrow") Then dt.Columns.Add("Eyebrow", GetType(String))
        If Not dt.Columns.Contains("Description") Then dt.Columns.Add("Description", GetType(String))
        If Not dt.Columns.Contains("ProductId") Then dt.Columns.Add("ProductId", GetType(Integer))
        For i As Integer = 0 To dt.Rows.Count - 1
            If IsDBNull(dt.Rows(i)("Eyebrow")) OrElse String.IsNullOrWhiteSpace(Convert.ToString(dt.Rows(i)("Eyebrow"))) Then
                dt.Rows(i)("Eyebrow") = If(i = 0, "The New Standard", "KeepStore Deals")
            End If
            If IsDBNull(dt.Rows(i)("Description")) OrElse String.IsNullOrWhiteSpace(Convert.ToString(dt.Rows(i)("Description"))) Then
                dt.Rows(i)("Description") = "Under favorable conditions for electronics, accessories and best sellers."
            End If
            If dt.Rows(i)("ProductId") Is DBNull.Value Then
                dt.Rows(i)("ProductId") = 0
            End If
        Next
        Return dt
    End Function

    Private Function HeroSlidesFallback() As DataTable
        Dim dt As DataTable = New DataTable()
        dt.Columns.Add("Caption", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Eyebrow", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("ProductId", GetType(Integer))
        dt.Rows.Add("The New Standard", "/Public/assets/images/banner/banner-1.jpg", "articoli.aspx", "The New Standard", "Under favorable conditions for electronics and cameras.", 0)
        dt.Rows.Add("Catch big deals on cameras", "/Public/assets/images/banner/banner-2.jpg", "articoli.aspx", "Big Deal", "Offers selected from the KeepStore catalog.", 0)
        dt.Rows.Add("Top promo tech", "/Public/assets/images/banner/banner-3.jpg", "articoli.aspx", "Sale", "Best offers and flagship products.", 0)
        Return dt
    End Function

    Private Function GetSideBanners() As DataTable
        Dim sql As String = "SELECT titolo AS Title, descrizione AS Description, img_path AS Image, link AS LinkUrl, CASE WHEN COALESCE(ordinamento,0)=1 THEN 'Sale' ELSE 'Promo' END AS Badge FROM pubblicita WHERE COALESCE(abilitato,0)=1 AND COALESCE(id_posizione_banner,0)=4 AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione <= CURDATE()) AND (data_fine_pubblicazione IS NULL OR data_fine_pubblicazione >= CURDATE()) ORDER BY COALESCE(ordinamento,0), id DESC LIMIT 2"
        Return SafeQuery(sql, SideBannersFallback())
    End Function

    Private Function SideBannersFallback() As DataTable
        Dim dt As DataTable = New DataTable()
        dt.Columns.Add("Title", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Badge", GetType(String))
        dt.Rows.Add("Catch big deals", "Offers on cameras and accessories", "/Public/assets/images/banner/banner-3.jpg", "articoli.aspx", "Sale")
        dt.Rows.Add("Top promo tech", "Featured electronics and gaming", "/Public/assets/images/banner/banner-4.jpg", "articoli.aspx", "Promo")
        Return dt
    End Function

    Private Function GetDealOfDayProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("COALESCE(v.InOfferta,0)=1 AND COALESCE(v.PrezzoPromoIvato,0)>0", "COALESCE(v.QtaVenduta,0) DESC, v.id DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetFeaturedZoneProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("COALESCE(v.Vetrina,0)=1", "COALESCE(v.visite,0) DESC, v.id DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetTopRateZoneProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("1=1", "COALESCE(v.PrezzoIvato,0) DESC, COALESCE(v.visite,0) DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetOnSaleZoneProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("COALESCE(v.InOfferta,0)=1", "COALESCE(v.PrezzoPromoIvato,0) DESC, COALESCE(v.visite,0) DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetBestSellerProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("1=1", "COALESCE(v.QtaVenduta,0) DESC, COALESCE(v.visite,0) DESC, v.id DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetTop20Products(ByVal limit As Integer) As DataTable
        Return GetBestSellerProducts(limit)
    End Function

    Private Function GetFeaturedProductsList(ByVal limit As Integer) As DataTable
        Return GetFeaturedZoneProducts(limit)
    End Function

    Private Function GetTopSellingProductsList(ByVal limit As Integer) As DataTable
        Return GetBestSellerProducts(limit)
    End Function

    Private Function GetRecentlyViewedProducts(ByVal limit As Integer) As DataTable
        Dim sql As String = BuildViewSql("1=1", "COALESCE(v.visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC", limit)
        Return SafeQuery(sql, GetFallbackProducts(limit))
    End Function

    Private Function GetBrands(ByVal limit As Integer) As DataTable
        Dim sql As String = "SELECT id, Descrizione, img, link FROM marche WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Ordinamento,0), Descrizione LIMIT " & limit.ToString()
        Return SafeQuery(sql, BrandsFallback())
    End Function

    Private Function BrandsFallback() As DataTable
        Dim dt As DataTable = New DataTable()
        dt.Columns.Add("Descrizione", GetType(String))
        dt.Columns.Add("img", GetType(String))
        dt.Columns.Add("link", GetType(String))
        dt.Rows.Add("KeepStore", "/Public/assets/images/logo/short-logo.svg", "articoli.aspx")
        dt.Rows.Add("KeepStore", "/Public/assets/images/logo/short-logo.svg", "articoli.aspx")
        dt.Rows.Add("KeepStore", "/Public/assets/images/logo/short-logo.svg", "articoli.aspx")
        dt.Rows.Add("KeepStore", "/Public/assets/images/logo/short-logo.svg", "articoli.aspx")
        dt.Rows.Add("KeepStore", "/Public/assets/images/logo/short-logo.svg", "articoli.aspx")
        Return dt
    End Function

    Private Function BuildViewSql(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As String
        Dim sql As New StringBuilder()
        sql.Append("SELECT v.id, v.Descrizione1, v.Descrizione2, v.Img1, v.PrezzoIvato, v.PrezzoPromoIvato, v.InOfferta, v.OfferteDataFine, v.Disponibilita, v.DataCreazione, v.visite, ")
        sql.Append("COALESCE(s.QtaVenduta,0) AS QtaVenduta ")
        sql.Append("FROM varticolilistinipromozioni_vetrina v ")
        sql.Append("LEFT JOIN (SELECT dr.ArticoliId, SUM(dr.Qnt) AS QtaVenduta FROM documentirighe dr INNER JOIN documenti d ON d.id = dr.DocumentiId WHERE COALESCE(d.Ordine_Web,0)=1 GROUP BY dr.ArticoliId) s ON s.ArticoliId = v.id ")
        sql.Append("WHERE COALESCE(v.id,0) > 0")
        If Not String.IsNullOrWhiteSpace(whereClause) Then
            sql.Append(" AND ")
            sql.Append(whereClause)
        End If
        sql.Append(" ORDER BY ")
        sql.Append(orderClause)
        sql.Append(" LIMIT ")
        sql.Append(limit.ToString())
        Return sql.ToString()
    End Function

    Private Function GetFallbackProducts(ByVal limit As Integer) As DataTable
        Dim sql As New StringBuilder()
        sql.Append("SELECT a.id, a.Descrizione1, a.Descrizione2, a.Img1, COALESCE(al.PrezzoIvato,0) AS PrezzoIvato, 0 AS PrezzoPromoIvato, 0 AS InOfferta, NULL AS OfferteDataFine, ")
        sql.Append("COALESCE(g.Disponibilita,0) AS Disponibilita, a.DataCreazione, a.Visite AS visite, 0 AS QtaVenduta ")
        sql.Append("FROM articoli a ")
        sql.Append("LEFT JOIN articoli_listini al ON al.ArticoliId = a.id AND al.NListino = 1 ")
        sql.Append("LEFT JOIN (SELECT ArticoliId, SUM(Disponibilita) AS Disponibilita FROM articoli_giacenze GROUP BY ArticoliId) g ON g.ArticoliId = a.id ")
        sql.Append("WHERE COALESCE(a.Abilitato,1)=1 ORDER BY COALESCE(a.Visite,0) DESC, a.id DESC LIMIT ")
        sql.Append(limit.ToString())
        Return SafeQuery(sql.ToString(), SampleProducts(limit))
    End Function

    Private Function SampleProducts(ByVal limit As Integer) As DataTable
        Dim dt As DataTable = New DataTable()
        dt.Columns.Add("id", GetType(Integer))
        dt.Columns.Add("Descrizione1", GetType(String))
        dt.Columns.Add("Descrizione2", GetType(String))
        dt.Columns.Add("Img1", GetType(String))
        dt.Columns.Add("PrezzoIvato", GetType(Double))
        dt.Columns.Add("PrezzoPromoIvato", GetType(Double))
        dt.Columns.Add("InOfferta", GetType(Integer))
        dt.Columns.Add("OfferteDataFine", GetType(String))
        dt.Columns.Add("Disponibilita", GetType(Integer))
        dt.Columns.Add("DataCreazione", GetType(Date))
        dt.Columns.Add("visite", GetType(Integer))
        dt.Columns.Add("QtaVenduta", GetType(Integer))
        Dim sample = {
            New Object() {1, "Notebook Gaming", "Top performance", "laptop.webp", 1499.9, 1299.9, 1, Date.Today.AddDays(5).ToString("yyyy-MM-dd"), 12, Date.Today.AddDays(-5), 120, 44},
            New Object() {2, "Smart TV 4K", "Cinema experience", "tivi.webp", 799.9, 699.9, 1, Date.Today.AddDays(3).ToString("yyyy-MM-dd"), 25, Date.Today.AddDays(-10), 98, 31},
            New Object() {3, "Mirrorless Camera", "Content creator", "camera-1.webp", 1099.9, 0, 0, Date.Today.AddDays(7).ToString("yyyy-MM-dd"), 8, Date.Today.AddDays(-20), 88, 18},
            New Object() {4, "Wireless Mouse", "Everyday office", "camera-2.webp", 39.9, 29.9, 1, Date.Today.AddDays(2).ToString("yyyy-MM-dd"), 64, Date.Today.AddDays(-2), 40, 56},
            New Object() {5, "Gaming Headset", "Surround audio", "camera-3.webp", 129.9, 99.9, 1, Date.Today.AddDays(4).ToString("yyyy-MM-dd"), 40, Date.Today.AddDays(-8), 75, 23}
        }
        For i As Integer = 0 To limit - 1
            Dim row = sample(i Mod sample.Length)
            dt.Rows.Add(row)
        Next
        Return dt
    End Function

    Private Function SafeQuery(ByVal sql As String, ByVal fallback As DataTable) As DataTable
        Try
            Dim cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then Return fallback
            Dim provider As String = If(String.IsNullOrWhiteSpace(cs.ProviderName), "MySql.Data.MySqlClient", cs.ProviderName)
            Dim factory = DbProviderFactories.GetFactory(provider)
            Using conn = factory.CreateConnection()
                conn.ConnectionString = cs.ConnectionString
                Using cmd = conn.CreateCommand()
                    cmd.CommandText = sql
                    Using da = factory.CreateDataAdapter()
                        da.SelectCommand = cmd
                        Dim dt As New DataTable()
                        conn.Open()
                        da.Fill(dt)
                        If dt Is Nothing OrElse dt.Rows.Count = 0 Then
                            Return fallback
                        End If
                        Return dt
                    End Using
                End Using
            End Using
        Catch
            Return fallback
        End Try
    End Function

    Private Function EnsureMinimumRows(ByVal source As DataTable, ByVal minimum As Integer) As DataTable
        Dim work = If(source IsNot Nothing, source.Copy(), New DataTable())
        If work.Rows.Count >= minimum Then Return work
        Dim fallback = GetFallbackProducts(minimum)
        If work.Columns.Count = 0 Then work = fallback.Clone()
        Dim i As Integer = 0
        While work.Rows.Count < minimum AndAlso fallback.Rows.Count > 0
            work.ImportRow(fallback.Rows(i Mod fallback.Rows.Count))
            i += 1
        End While
        Return work
    End Function

    Private Function SliceTable(ByVal source As DataTable, ByVal skip As Integer, ByVal take As Integer) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), New DataTable())
        If source Is Nothing Then Return result
        For i As Integer = skip To Math.Min(source.Rows.Count - 1, skip + take - 1)
            result.ImportRow(source.Rows(i))
        Next
        Return result
    End Function

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Protected Function SafeInt(ByVal value As Object) As Integer
        Dim n As Integer
        Integer.TryParse(Convert.ToString(value), n)
        Return n
    End Function

    Protected Function ProductTitle(ByVal descrizione1 As Object, ByVal descrizione2 As Object, ByVal id As Object) As String
        Dim t1 = Convert.ToString(descrizione1).Trim()
        Dim t2 = Convert.ToString(descrizione2).Trim()
        If Not String.IsNullOrWhiteSpace(t1) Then Return HttpUtility.HtmlEncode(t1)
        If Not String.IsNullOrWhiteSpace(t2) Then Return HttpUtility.HtmlEncode(t2)
        Return "Articolo " & Convert.ToString(id)
    End Function

    Protected Function ProductUrl(ByVal id As Object) As String
        Return "articolo.aspx?id=" & Convert.ToString(id)
    End Function

    Protected Function ResolveLink(ByVal value As Object, ByVal fallback As String) As String
        Dim link As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(link) Then Return fallback
        Return link
    End Function

    Protected Function ResolveBannerImage(ByVal value As Object, ByVal fallback As String) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return fallback
        fileName = fileName.Replace("\", "/")
        If fileName.StartsWith("/") OrElse fileName.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then Return fileName
        fileName = Path.GetFileName(fileName)
        Return "/Public/assets/images/banner/" & fileName
    End Function

    Protected Function ProductImageThumb(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return "/Public/assets/images/item/laptop.webp"
        fileName = fileName.Replace("\", "/")
        fileName = Path.GetFileName(fileName)
        If fileName.StartsWith("_") Then
            Return "/Public/assets/images/articoli/" & fileName
        End If
        Return "/Public/assets/images/articoli/_" & fileName
    End Function

    Protected Function ProductImageFull(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return "/Public/assets/images/item/laptop.webp"
        fileName = fileName.Replace("\", "/")
        fileName = Path.GetFileName(fileName)
        Return "/Public/assets/images/articoli/" & fileName
    End Function

    Protected Function BrandImage(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return "/Public/assets/images/logo/short-logo.svg"
        fileName = fileName.Replace("\", "/")
        If fileName.StartsWith("/") OrElse fileName.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then Return fileName
        Return "/Public/assets/images/marche/" & Path.GetFileName(fileName)
    End Function

    Protected Function CurrentPrice(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Dim listino = ToDecimal(priceIvato)
        Dim promo = ToDecimal(promoIvato)
        Dim offerta = SafeInt(inOfferta)
        If offerta = 1 AndAlso promo > 0D Then Return promo
        Return listino
    End Function

    Protected Function SavingsAmount(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Dim listino = ToDecimal(priceIvato)
        Dim current = CurrentPrice(priceIvato, promoIvato, inOfferta)
        If listino > current AndAlso current > 0D Then Return listino - current
        Return 0D
    End Function

    Protected Function ShowDiscount(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Boolean
        Return SavingsAmount(priceIvato, promoIvato, inOfferta) > 0D
    End Function

    Protected Function DiscountPercent(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Integer
        Dim listino = ToDecimal(priceIvato)
        Dim current = CurrentPrice(priceIvato, promoIvato, inOfferta)
        If listino <= 0D OrElse current <= 0D OrElse current >= listino Then Return 0
        Return Convert.ToInt32(Math.Round(((listino - current) / listino) * 100D, MidpointRounding.AwayFromZero))
    End Function

    Protected Function FormatMoney(ByVal value As Object) As String
        Dim amount = ToDecimal(value)
        Return amount.ToString("C0", ItCulture)
    End Function

    Protected Function FormatOldPrice(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As String
        If Not ShowDiscount(priceIvato, promoIvato, inOfferta) Then Return String.Empty
        Return FormatMoney(priceIvato)
    End Function

    Protected Function AvailabilityPercent(ByVal disponibilita As Object, ByVal sold As Object) As Integer
        Dim available = Math.Max(0, SafeInt(disponibilita))
        Dim soldCount = Math.Max(1, SafeInt(sold))
        Dim total = Math.Max(1, soldCount + available)
        Return Convert.ToInt32(Math.Round((soldCount / CDbl(total)) * 100D, MidpointRounding.AwayFromZero))
    End Function

    Protected Function CountdownSeconds(ByVal offerteDataFine As Object) As Integer
        Dim target As DateTime
        If DateTime.TryParse(Convert.ToString(offerteDataFine), target) Then
            Dim diff = target.Date.AddDays(1).Subtract(DateTime.Now)
            Return Math.Max(60, Convert.ToInt32(diff.TotalSeconds))
        End If
        Return 172800
    End Function

    Private Function ToDecimal(ByVal value As Object) As Decimal
        Dim d As Decimal
        Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, d)
        If d = 0D Then Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, ItCulture, d)
        Return d
    End Function

    Protected Function RenderRowCard(ByVal dataItem As Object) As String
        Dim row = TryCast(dataItem, DataRowView)
        If row Is Nothing Then Return String.Empty
        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-row row-small-2'>")
        sb.Append("<div class='card-product-wrapper'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='product-img'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageThumb(row("Img1"))).Append("' data-src='").Append(ProductImageThumb(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a></div>")
        sb.Append("<div class='card-product-info'><div class='box-title'>")
        sb.Append("<div class='bg-white relative z-5'><p class='caption text-main-2 font-2'>").Append(HttpUtility.HtmlEncode(Convert.ToString(row("Descrizione2")))).Append("</p>")
        sb.Append("<h6><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6></div>")
        sb.Append("<p class='price-wrap fw-medium'><span class='new-price h6 fw-normal text-primary mb-0'>").Append(FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</span>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append(" <span class='old-price'>").Append(FormatMoney(row("PrezzoIvato"))).Append("</span>")
        End If
        sb.Append("</p></div></div></div>")
        Return sb.ToString()
    End Function

    Protected Function RenderBigCard(ByVal dataItem As Object) As String
        Dim row = TryCast(dataItem, DataRowView)
        If row Is Nothing Then Return String.Empty
        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-border hover-img'>")
        sb.Append("<div class='card-product-wrapper overflow-visible'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='card-image product-img d-block'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append("<div class='box-sale-wrap top-0 start-0 z-5'><p class='small-text'>Sale</p><p class='title-sidebar-2'>").Append(DiscountPercent(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta"))).Append("%</p></div>")
        End If
        sb.Append("</div><div class='card-product-info'>")
        sb.Append("<p class='caption text-main-2 font-2'>").Append(HttpUtility.HtmlEncode(Convert.ToString(row("Descrizione2")))).Append("</p>")
        sb.Append("<h5><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h5>")
        sb.Append("<p class='price-wrap fw-medium'><span class='new-price h4 fw-normal text-primary mb-0'>").Append(FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</span></p>")
        sb.Append("</div></div>")
        Return sb.ToString()
    End Function

    Protected Function RenderGridCard(ByVal dataItem As Object) As String
        Dim row = TryCast(dataItem, DataRowView)
        If row Is Nothing Then Return String.Empty
        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-img-border wow fadeInLeft' data-wow-delay='0s'>")
        sb.Append("<div class='card-product-wrapper'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='product-img'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' src='").Append(ProductImageThumb(row("Img1"))).Append("' data-src='").Append(ProductImageThumb(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a>")
        sb.Append("<ul class='list-product-btn'>")
        sb.Append("<li><a href='").Append(ProductUrl(row("id"))).Append("' class='box-icon btn-icon-action hover-tooltip tooltip-left'><i class='icon icon-cart2'></i><span class='tooltip'>Add to Cart</span></a></li>")
        sb.Append("<li><a href='compare.aspx?add=").Append(Convert.ToString(row("id"))).Append("' class='box-icon btn-icon-action hover-tooltip tooltip-left'><i class='icon icon-compare1'></i><span class='tooltip'>Compare</span></a></li>")
        sb.Append("</ul>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append("<div class='box-sale-wrap top-0 start-0 z-5'><p class='small-text'>Sale</p><p class='title-sidebar-2'>").Append(DiscountPercent(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta"))).Append("%</p></div>")
        End If
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'><div class='box-title'><div class='bg-white relative z-5'><p class='caption text-main-2 font-2'>").Append(HttpUtility.HtmlEncode(Convert.ToString(row("Descrizione2")))).Append("</p><h6><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6></div>")
        sb.Append("<p class='price-wrap fw-medium'><span class='new-price h6 fw-normal text-primary mb-0'>").Append(FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</span></p></div></div></div>")
        Return sb.ToString()
    End Function
End Class
