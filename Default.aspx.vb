Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Linq
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Class _Default
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim ivaTipo As Integer = SafeInt(Session("IvaTipo"), 0)
        Dim ordineChiuso As Integer = GetSettingInt("OrdineStatoChiuso", 3)

        ConfigureHomeDataSources(ivaTipo, ordineChiuso)

        If Not IsPostBack Then
            BindHomeGridTabs()
            BindRecentlyViewed(ivaTipo)
        End If
    End Sub

    Private Sub ConfigureHomeDataSources(ivaTipo As Integer, ordineChiuso As Integer)
        Dim vsFields As String = BuildVsuperArticoliSelect(ivaTipo)

        ' Criteri automatici home (stabili e coerenti con il DB attuale):
        ' - Occasione Imperdibile / On Sale: offerte attive ordinate per scadenza + popolarità
        ' - Best Seller / Top Selling Product: vendite storiche da documenti chiusi
        ' - Feature / Featured Products: articoli marcati Vetrina, più recenti e più cliccati
        ' - Toprate / Top 20: articoli più visti / popolari
        sdsDealOfDay.SelectCommand = BuildOnSaleQuery(vsFields, 8)
        sdsBestSeller.SelectCommand = BuildTopSoldQuery(vsFields, ordineChiuso, 12)

        ' Tabs (Onsus: Feature / Toprate / On Sale)
        sdsTabFeature.SelectCommand = BuildFeaturedQuery(vsFields, 8)
        sdsTabToprate.SelectCommand = BuildTopViewedQuery(vsFields, 8)
        sdsTabOnSale.SelectCommand = BuildOnSaleQuery(vsFields, 8)

        ' Grid laterale home (Top 20 / Featured / Top Selling / On-sale)
        sdsTop20.SelectCommand = BuildTopViewedQuery(vsFields, 5)
        sdsFeaturedMini.SelectCommand = BuildFeaturedQuery(vsFields, 5)
        sdsTopSellingMini.SelectCommand = BuildTopSoldQuery(vsFields, ordineChiuso, 5)
        sdsOnSaleMini.SelectCommand = BuildOnSaleQuery(vsFields, 5)

        ' MySQL provider esplicito per prevenire fallback a SqlClient
        EnsureMySqlProvider(sdsDealOfDay)
        EnsureMySqlProvider(sdsBestSeller)
        EnsureMySqlProvider(sdsTabFeature)
        EnsureMySqlProvider(sdsTabToprate)
        EnsureMySqlProvider(sdsTabOnSale)
        EnsureMySqlProvider(sdsTop20)
        EnsureMySqlProvider(sdsFeaturedMini)
        EnsureMySqlProvider(sdsTopSellingMini)
        EnsureMySqlProvider(sdsOnSaleMini)
        EnsureMySqlProvider(sdsRecentlyViewed)
    End Sub

    Private Sub BindHomeGridTabs()
        ' Feature tab
        BindGridTab(sdsTabFeature, rptFeatureLeft, rptFeatureCenter, rptFeatureRight, 3, 1, 4)

        ' Toprate tab
        BindGridTab(sdsTabToprate, rptToprateLeft, rptToprateCenter, rptToprateRight, 3, 1, 4)

        ' On Sale tab
        BindGridTab(sdsTabOnSale, rptOnSaleLeft, rptOnSaleCenter, rptOnSaleRight, 3, 1, 4)
    End Sub

    Private Sub BindGridTab(ds As SqlDataSource,
                            rptLeft As Repeater,
                            rptCenter As Repeater,
                            rptRight As Repeater,
                            leftCount As Integer,
                            centerCount As Integer,
                            rightCount As Integer)

        ' IMPORTANT:
        ' KeepStore usa MySQL (connection string con keyword come "port").
        ' Se ProviderName non è impostato, SqlDataSource usa di default SqlClient e va in errore.
        EnsureMySqlProvider(ds)

        Dim dv As DataView = Nothing
        Try
            dv = TryCast(ds.Select(DataSourceSelectArguments.Empty), DataView)
        Catch
            dv = Nothing
        End Try

        If dv Is Nothing OrElse dv.Table Is Nothing Then
            rptLeft.DataSource = Nothing : rptLeft.DataBind()
            rptCenter.DataSource = Nothing : rptCenter.DataBind()
            rptRight.DataSource = Nothing : rptRight.DataBind()
            Return
        End If

        Dim dt As DataTable = dv.Table

        rptLeft.DataSource = Slice(dt, 0, leftCount)
        rptLeft.DataBind()

        rptCenter.DataSource = Slice(dt, leftCount, centerCount)
        rptCenter.DataBind()

        rptRight.DataSource = Slice(dt, leftCount + centerCount, rightCount)
        rptRight.DataBind()
    End Sub

    Private Sub EnsureMySqlProvider(ds As SqlDataSource)
        If ds Is Nothing Then Exit Sub

        Try
            Dim pn As String = Convert.ToString(ds.ProviderName)
            If String.IsNullOrWhiteSpace(pn) OrElse pn.Equals("System.Data.SqlClient", StringComparison.OrdinalIgnoreCase) Then
                ' fallback hard-coded (coerente con la configurazione KeepStore)
                ds.ProviderName = "MySql.Data.MySqlClient"
            End If
        Catch
            ' ignore (non bloccare la pagina)
        End Try
    End Sub

    Private Function Slice(dt As DataTable, startIndex As Integer, count As Integer) As DataTable
        Dim clone As DataTable = dt.Clone()
        If dt Is Nothing OrElse dt.Rows.Count = 0 OrElse count <= 0 OrElse startIndex < 0 Then Return clone

        Dim maxIndex As Integer = Math.Min(dt.Rows.Count - 1, startIndex + count - 1)
        For i As Integer = startIndex To maxIndex
            clone.ImportRow(dt.Rows(i))
        Next
        Return clone
    End Function

    Private Sub BindRecentlyViewed(ivaTipo As Integer)
        Dim ids As List(Of Integer) = ReadRecentIds(10)
        Dim vsSelectRecently As String = BuildVsuperArticoliSelect(ivaTipo)

        ' Nel template Onsus la sezione rimane sempre presente.
        ' Se l'utente non ha ancora visitato prodotti, mostriamo un fallback popolare.
        phRecentlyViewed.Visible = True

        If ids Is Nothing OrElse ids.Count = 0 Then
            sdsRecentlyViewed.SelectCommand = BuildTopViewedQuery(vsSelectRecently, 10)
            Return
        End If

        Dim idsCsv As String = String.Join(",", ids.Select(Function(x) x.ToString(CultureInfo.InvariantCulture)))

        ' Manteniamo l'ordine di visita (MySQL: FIELD)
        sdsRecentlyViewed.SelectCommand =
            vsSelectRecently &
            " WHERE vsuperarticoli.id IN (" & idsCsv & ") " &
            " ORDER BY FIELD(vsuperarticoli.id," & idsCsv & ") " &
            " LIMIT 10"
    End Sub

    Private Function ReadRecentIds(maxCount As Integer) As List(Of Integer)
        Dim outList As New List(Of Integer)()

        Try
            Dim c As HttpCookie = Request.Cookies("ks_recent")
            If c Is Nothing OrElse String.IsNullOrWhiteSpace(c.Value) Then Return outList

            Dim raw As String = HttpUtility.UrlDecode(c.Value)
            If String.IsNullOrWhiteSpace(raw) Then Return outList

            Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
            For Each p As String In parts
                Dim n As Integer
                If Integer.TryParse(p.Trim(), n) AndAlso n > 0 Then
                    If Not outList.Contains(n) Then outList.Add(n)
                    If outList.Count >= maxCount Then Exit For
                End If
            Next
        Catch
            ' ignore
        End Try

        Return outList
    End Function

    ' ----------------------------
    ' Select builders
    ' ----------------------------
    Private Function BuildVsuperArticoliSelect(ivaTipo As Integer) As String
        ' NB: manteniamo alias/nomi campo già usati nelle pagine KeepStore.
        Return "SELECT " &
               "vsuperarticoli.id AS Articoliid, " &
               "vsuperarticoli.Codice, " &
               "vsuperarticoli.Descrizione1, " &
               "vsuperarticoli.Img1, vsuperarticoli.Img2, vsuperarticoli.Img3, vsuperarticoli.Img4, " &
               "vsuperarticoli.prezzo, " &
               "(CASE WHEN " & ivaTipo & "=2 THEN vsuperarticoli.prezzoIvato ELSE vsuperarticoli.prezzo END) AS PrezzoMostrato, " &
               "(CASE WHEN " & ivaTipo & "=2 THEN vsuperarticoli.PrezzoPromoIvato ELSE vsuperarticoli.prezzoPromo END) AS PrezzoPromoMostrato, " &
               "vsuperarticoli.InOfferta, " &
               "vsuperarticoli.prezzoIvato, vsuperarticoli.prezzoPromo, " &
               "vsuperarticoli.PrezzoPromoIvato, " &
               "vsuperarticoli.SpeditoGratis, " &
               "COALESCE(vsuperarticoli.Disponibilita,0) AS Disponibilita, " &
               "COALESCE(vsuperarticoli.Impegnata,0) AS Impegnata, " &
               "COALESCE(vsuperarticoli.visite,0) AS Visite, " &
               "COALESCE(vsuperarticoli.Vetrina,0) AS Vetrina, " &
               "vsuperarticoli.DataCreazione, " &
               "vsuperarticoli.OfferteDataFine " &
               "FROM vsuperarticoli"
    End Function

    Private Function BuildFeaturedQuery(vsFields As String, limit As Integer) As String
        ' Feature / Featured Products = articoli marcati in Vetrina.
        If limit <= 0 Then limit = 8

        Return vsFields &
               " WHERE COALESCE(vsuperarticoli.Vetrina,0) <> 0 " &
               " ORDER BY COALESCE(vsuperarticoli.DataCreazione, CURDATE()) DESC, " &
               "          COALESCE(vsuperarticoli.visite,0) DESC, " &
               "          vsuperarticoli.id DESC " &
               " LIMIT " & limit.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function BuildTopViewedQuery(vsFields As String, limit As Integer) As String
        ' Toprate / Top 20 = popolarità: più visite, poi disponibilità e freschezza.
        If limit <= 0 Then limit = 8

        Return vsFields &
               " ORDER BY COALESCE(vsuperarticoli.visite,0) DESC, " &
               "          COALESCE(vsuperarticoli.Disponibilita,0) DESC, " &
               "          COALESCE(vsuperarticoli.DataCreazione, CURDATE()) DESC, " &
               "          vsuperarticoli.id DESC " &
               " LIMIT " & limit.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function BuildOnSaleQuery(vsFields As String, limit As Integer) As String
        ' Deal Of The Day / On-sale = offerte attive in scadenza, con priorità agli articoli più cliccati.
        If limit <= 0 Then limit = 8

        Return vsFields &
               " WHERE COALESCE(vsuperarticoli.InOfferta,0)=1 " &
               "   AND (COALESCE(vsuperarticoli.prezzoPromo,0)>0 OR COALESCE(vsuperarticoli.PrezzoPromoIvato,0)>0) " &
               " ORDER BY (vsuperarticoli.OfferteDataFine IS NULL), " &
               "          vsuperarticoli.OfferteDataFine ASC, " &
               "          COALESCE(vsuperarticoli.visite,0) DESC, " &
               "          vsuperarticoli.id DESC " &
               " LIMIT " & limit.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function BuildTopSoldQuery(vsFields As String, ordineChiuso As Integer, limit As Integer) As String
        ' Best seller / Top Selling Product basato su documenti + righe documento dello schema attuale.
        If limit <= 0 Then limit = 8

        Dim whereParts As New List(Of String)()
        whereParts.Add("dr.TipoRiga = 'A'")
        If ordineChiuso > 0 Then
            whereParts.Add("d.StatiId = " & ordineChiuso.ToString(CultureInfo.InvariantCulture))
        End If

        Dim wh As String = String.Join(" AND ", whereParts.ToArray())

        Return vsFields &
               " LEFT JOIN ( " &
               "   SELECT dr.ArticoliId AS articoli_id, SUM(IFNULL(dr.Qnt,0)) AS QntTot " &
               "   FROM documentirighe dr " &
               "   INNER JOIN documenti d ON d.id = dr.DocumentiId " &
               "   WHERE " & wh & " " &
               "   GROUP BY dr.ArticoliId " &
               " ) Vendite ON Vendite.articoli_id = vsuperarticoli.id " &
               " ORDER BY COALESCE(Vendite.QntTot,0) DESC, " &
               "          COALESCE(vsuperarticoli.visite,0) DESC, " &
               "          COALESCE(vsuperarticoli.Disponibilita,0) DESC, " &
               "          vsuperarticoli.id DESC " &
               " LIMIT " & limit.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function GetSettingInt(key As String, defaultValue As Integer) As Integer
        Try
            Dim v As String = ConfigurationManager.AppSettings(key)
            Dim n As Integer
            If Integer.TryParse(v, n) Then Return n
        Catch
            ' ignore
        End Try
        Return defaultValue
    End Function

    Private Function SafeInt(value As Object, defaultValue As Integer) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim n As Integer
            If Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), n) Then Return n
        Catch
            ' ignore
        End Try
        Return defaultValue
    End Function

    ' ----------------------------
    ' Helpers used from ASPX
    ' ----------------------------
    Protected Function GetProductImage(primaryImg As Object, fallbackImg As Object) As String
        Dim p As String = Convert.ToString(primaryImg)
        If String.IsNullOrWhiteSpace(p) OrElse p = "0" Then
            p = Convert.ToString(fallbackImg)
        End If
        Return ThemeManager.ProductImageUrl(p)
    End Function

    Protected Function RenderDiscountBadge(prezzoMostrato As Object, prezzoPromoMostrato As Object, inOfferta As Object) As String
        Dim flag As Integer = SafeInt(inOfferta, 0)
        If flag <> 1 Then Return String.Empty

        Dim p As Decimal = SafeDecimal(prezzoMostrato)
        Dim promo As Decimal = SafeDecimal(prezzoPromoMostrato)
        If p <= 0D OrElse promo <= 0D OrElse promo >= p Then Return String.Empty

        Dim perc As Integer = CInt(Math.Round((1D - (promo / p)) * 100D, 0, MidpointRounding.AwayFromZero))
        If perc <= 0 Then Return String.Empty

        Return "<span class=""on-sale fw-semibold"">-" & perc.ToString(CultureInfo.InvariantCulture) & "%</span>"
    End Function

    Protected Function GetCountdownSeconds(endDate As Object) As Integer
        Try
            If endDate Is Nothing OrElse endDate Is DBNull.Value Then Return 0
            Dim dt As DateTime
            If TypeOf endDate Is DateTime Then
                dt = DirectCast(endDate, DateTime)
            Else
                If Not DateTime.TryParse(Convert.ToString(endDate), dt) Then Return 0
            End If

            Dim sec As Double = (dt.ToUniversalTime() - DateTime.UtcNow).TotalSeconds
            If sec < 0 Then sec = 0
            If sec > Integer.MaxValue Then sec = Integer.MaxValue
            Return CInt(Math.Floor(sec))
        Catch
            Return 0
        End Try
    End Function

    Protected Function GetSoldQty(impegnata As Object) As Integer
        Dim n As Integer = SafeInt(impegnata, 0)
        If n < 0 Then n = 0
        Return n
    End Function

    Protected Function GetAvailableQty(disponibilita As Object) As Integer
        Dim n As Integer = SafeInt(disponibilita, 0)
        If n < 0 Then n = 0
        Return n
    End Function

    Protected Function GetSoldPercent(impegnata As Object, disponibilita As Object) As Integer
        Dim sold As Integer = GetSoldQty(impegnata)
        Dim avail As Integer = GetAvailableQty(disponibilita)
        Dim total As Integer = sold + avail
        If total <= 0 Then Return 0
        Dim perc As Integer = CInt(Math.Round((sold * 100D) / total, 0, MidpointRounding.AwayFromZero))
        If perc < 0 Then perc = 0
        If perc > 100 Then perc = 100
        Return perc
    End Function

    Protected Function GetCaption(code As Object) As String
        Dim s As String = Convert.ToString(code)
        If String.IsNullOrWhiteSpace(s) Then Return "Prodotto"
        Return s
    End Function

    Private Function SafeDecimal(value As Object) As Decimal
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return 0D
            Dim d As Decimal
            If Decimal.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
            ' fallback per culture it-IT
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then Return d
        Catch
            ' ignore
        End Try
        Return 0D
    End Function

End Class
