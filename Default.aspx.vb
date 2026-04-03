Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Hosting
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Partial Public Class _Default
    Inherits Page

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private Shared ReadOnly Rng As New Random()

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
        Dim hero As DataTable = GetHeroSlides()
        rptHeroSlides.DataSource = hero
        rptHeroSlides.DataBind()
        Dim hasHeroSlides As Boolean = hero IsNot Nothing AndAlso hero.Rows.Count > 0
        Slide_Show_Container.Visible = hasHeroSlides
        HeroSliderWrap.Visible = hasHeroSlides

        Dim sideBanners As DataTable = GetSideBanners()
        rptSideBanners.DataSource = sideBanners
        rptSideBanners.DataBind()
        Dim hasSideBanners As Boolean = sideBanners IsNot Nothing AndAlso sideBanners.Rows.Count > 0
        HeroSideWrap.Visible = hasSideBanners
        HomeHeroSection.Visible = hasHeroSlides OrElse hasSideBanners

        Dim usedIds As New HashSet(Of Integer)()

        Dim offerPool As DataTable = GetOfferPool(120)
        Dim featuredPool As DataTable = GetFeaturedPool(120)
        Dim newArrivalsPool As DataTable = GetNewArrivalsPool(120)
        Dim bestSellerPool As DataTable = GetBestSellerPool(120)
        Dim topSellingPool As DataTable = GetPureTopSellingPool(120)

        Dim dealPool As DataTable = TakeDistinctRows(12, usedIds, offerPool)
        rptDealOfDay.DataSource = dealPool
        rptDealOfDay.DataBind()

        BindThreeColumnZone(TakeDistinctRows(7, usedIds, offerPool), rptFeatureLeft, rptFeatureCenter, rptFeatureRight)
        BindThreeColumnZone(TakeDistinctRows(7, usedIds, featuredPool), rptToprateLeft, rptToprateCenter, rptToprateRight)
        BindThreeColumnZone(TakeDistinctRows(7, usedIds, newArrivalsPool), rptOnSaleLeft, rptOnSaleCenter, rptOnSaleRight)

        rptBestSeller.DataSource = TakeDistinctRows(10, usedIds, bestSellerPool)
        rptBestSeller.DataBind()

        rptTop20Slides.DataSource = BuildSlidesTable(TakeDistinctRows(5, usedIds, topSellingPool), 5)
        rptTop20Slides.DataBind()

        rptFeaturedProductsSlides.DataSource = BuildSlidesTable(TakeDistinctRows(5, usedIds, featuredPool), 5)
        rptFeaturedProductsSlides.DataBind()

        rptTopSellingProductSlides.DataSource = BuildSlidesTable(TakeDistinctRows(5, usedIds, topSellingPool), 5)
        rptTopSellingProductSlides.DataBind()

        rptOnSaleProductSlides.DataSource = BuildSlidesTable(TakeDistinctRows(5, usedIds, offerPool), 5)
        rptOnSaleProductSlides.DataBind()

        rptBrands.DataSource = GetBrands(12)
        rptBrands.DataBind()

        rptRecentlyViewed.DataSource = GetRecentlyViewedProducts(12)
        rptRecentlyViewed.DataBind()
    End Sub

    Private Sub BindThreeColumnZone(ByVal source As DataTable, ByVal leftRepeater As Repeater, ByVal centerRepeater As Repeater, ByVal rightRepeater As Repeater)
        Dim work As DataTable = If(source IsNot Nothing, source.Copy(), EmptyProductsTable())
        Dim total As Integer = If(work Is Nothing, 0, work.Rows.Count)
        Dim leftStart As Integer = 0
        Dim leftCount As Integer = 0
        Dim centerStart As Integer = 0
        Dim centerCount As Integer = 0
        Dim rightStart As Integer = 0
        Dim rightCount As Integer = 0

        Select Case total
            Case Is >= 7
                leftCount = 3
                centerStart = 3
                centerCount = 1
                rightStart = 4
                rightCount = Math.Min(3, total - rightStart)
            Case 5, 6
                leftCount = 2
                centerStart = 2
                centerCount = 1
                rightStart = 3
                rightCount = Math.Min(3, total - rightStart)
            Case 3, 4
                leftCount = 1
                centerStart = 1
                centerCount = 1
                rightStart = 2
                rightCount = Math.Max(0, total - rightStart)
            Case 2
                centerCount = 1
                rightStart = 1
                rightCount = 1
            Case 1
                centerCount = 1
        End Select

        leftRepeater.DataSource = SliceTable(work, leftStart, leftCount)
        leftRepeater.DataBind()
        centerRepeater.DataSource = SliceTable(work, centerStart, centerCount)
        centerRepeater.DataBind()
        rightRepeater.DataSource = SliceTable(work, rightStart, rightCount)
        rightRepeater.DataBind()
    End Sub

    Private Function BuildSlidesTable(ByVal source As DataTable, ByVal groupSize As Integer) As DataTable
        Dim result As New DataTable()
        result.Columns.Add("Html", GetType(String))

        Dim work As DataTable = source
        If work Is Nothing OrElse work.Rows.Count = 0 Then
            result.Rows.Add("<ul class='product-list-wrap'></ul>")
            Return result
        End If

        Dim effectiveGroupSize As Integer = Math.Max(groupSize, 1)
        Dim index As Integer = 0
        While index < work.Rows.Count
            Dim sb As New StringBuilder()
            sb.Append("<ul class='product-list-wrap'>")
            Dim upper As Integer = Math.Min(index + effectiveGroupSize - 1, work.Rows.Count - 1)
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

    Private Function GetHeroSlides() As DataTable
        Dim sql As String = "SELECT id, caption AS Caption, image AS Image, link AS LinkUrl FROM slideshow_new WHERE (start_date IS NULL OR start_date <= CURDATE()) AND (stop_date IS NULL OR stop_date >= CURDATE()) ORDER BY id DESC LIMIT 5"
        Dim dt As DataTable = SafeTableQuery(sql, HeroSlidesFallback(), "GetHeroSlides")

        If Not dt.Columns.Contains("Eyebrow") Then dt.Columns.Add("Eyebrow", GetType(String))
        If Not dt.Columns.Contains("Description") Then dt.Columns.Add("Description", GetType(String))
        If Not dt.Columns.Contains("ProductId") Then dt.Columns.Add("ProductId", GetType(Integer))

        For i As Integer = 0 To dt.Rows.Count - 1
            If String.IsNullOrWhiteSpace(Convert.ToString(dt.Rows(i)("Eyebrow"))) Then
                dt.Rows(i)("Eyebrow") = If(i = 0, "KeepStore 3.0", "Selezione Onsus")
            End If
            If String.IsNullOrWhiteSpace(Convert.ToString(dt.Rows(i)("Description"))) Then
                dt.Rows(i)("Description") = "Promozioni, novita e prodotti selezionati in evidenza."
            End If
            If dt.Rows(i)("ProductId") Is DBNull.Value Then
                dt.Rows(i)("ProductId") = 0
            End If
        Next

        Return dt
    End Function

    Private Function HeroSlidesFallback() As DataTable
        Dim dt As New DataTable()
        dt.Columns.Add("Caption", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Eyebrow", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("ProductId", GetType(Integer))
        Return dt
    End Function

    Private Function GetSideBanners() As DataTable
        Dim sql As String = "SELECT titolo AS Title, descrizione AS Description, img_path AS Image, link AS LinkUrl, CASE WHEN COALESCE(ordinamento,0)=1 THEN 'Offerta' ELSE 'Promo' END AS Badge FROM pubblicita WHERE COALESCE(abilitato,0)=1 AND COALESCE(id_posizione_banner,0)=4 AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione <= CURDATE()) AND (data_fine_pubblicazione IS NULL OR data_fine_pubblicazione >= CURDATE()) ORDER BY COALESCE(ordinamento,0), id DESC LIMIT 2"
        Return SafeTableQuery(sql, SideBannersFallback(), "GetSideBanners")
    End Function

    Private Function SideBannersFallback() As DataTable
        Dim dt As New DataTable()
        dt.Columns.Add("Title", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Badge", GetType(String))
        Return dt
    End Function

    Private Function GetOfferPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(OfferWhereClause(), "CASE WHEN v.OfferteDataFine IS NULL THEN 1 ELSE 0 END ASC, COALESCE(v.OfferteDataFine,'9999-12-31') ASC, COALESCE(sy.VendutiAnno,0) DESC, COALESCE(v.Visite,0) DESC, v.id DESC", limit)
    End Function

    Private Function GetFeaturedPool(ByVal limit As Integer) As DataTable
        Return QueryProducts("COALESCE(v.Vetrina,0)=1 AND " & StockWhereClause() & ">=1",
                             "COALESCE(v.DataCreazione,CURDATE()) DESC, COALESCE(v.Visite,0) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetMostViewedPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(v.Visite,0)>0",
                             "COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetNewArrivalsPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(v.DataCreazione,'1900-01-01') >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)",
                             "COALESCE(v.DataCreazione,CURDATE()) DESC, COALESCE(v.Visite,0) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetBestSellerPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(s.QtaVenduta,0)>0", "COALESCE(s.QtaVenduta,0) DESC, COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC", limit)
    End Function

    Private Function GetPureTopSellingPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(s.QtaVenduta,0)>0", "COALESCE(s.QtaVenduta,0) DESC, COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC", limit)
    End Function

    Private Function QueryProducts(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As DataTable
        Dim dt As DataTable = TryLoadProducts(whereClause, orderClause, limit)
        If dt IsNot Nothing AndAlso dt.Rows.Count > 0 Then
            Return dt
        End If
        Return EmptyProductsTable()
    End Function

    Private Function GetRecentlyViewedProducts(ByVal limit As Integer) As DataTable
        Dim ids As List(Of Integer) = GetRecentlyViewedIds()
        If ids.Count = 0 Then
            Return EmptyProductsTable()
        End If

        Dim orderedIds As New List(Of Integer)()
        For Each id As Integer In ids
            If id > 0 AndAlso Not orderedIds.Contains(id) Then
                orderedIds.Add(id)
            End If
            If orderedIds.Count >= limit Then Exit For
        Next

        If orderedIds.Count = 0 Then Return EmptyProductsTable()

        Dim idsCsv As String = String.Join(",", orderedIds.ToArray())
        Dim orderSql As New StringBuilder()
        orderSql.Append("CASE v.id ")
        For i As Integer = 0 To orderedIds.Count - 1
            orderSql.Append("WHEN ").Append(orderedIds(i).ToString(CultureInfo.InvariantCulture)).Append(" THEN ").Append(i.ToString(CultureInfo.InvariantCulture)).Append(" ")
        Next
        orderSql.Append("ELSE 9999 END")

        Dim dt As DataTable = TryLoadProducts("v.id IN (" & idsCsv & ") AND " & StockWhereClause() & ">=1", orderSql.ToString(), limit)
        If dt IsNot Nothing AndAlso dt.Rows.Count > 0 Then
            Return dt
        End If

        Return EmptyProductsTable()
    End Function

    Private Function TryLoadProducts(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As DataTable
        Dim sql As New StringBuilder()
        sql.Append("SELECT ")
        sql.Append("v.id, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, IFNULL(v.DescrizioneLunga,'') AS DescrizioneLunga, ")
        sql.Append("COALESCE(v.MarcheId,0) AS MarcheId, IFNULL(v.MarcheDescrizione,'') AS MarcheDescrizione, ")
        sql.Append("IFNULL(v.SettoriDescrizione,'') AS SettoriDescrizione, IFNULL(v.CategorieDescrizione,'') AS CategorieDescrizione, ")
        sql.Append("IFNULL(v.TipologieDescrizione,'') AS TipologieDescrizione, IFNULL(v.GruppiDescrizione,'') AS GruppiDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, ")
        sql.Append("COALESCE(aBase.Abilitato,1) AS Abilitato, COALESCE(aBase.Abilitato,1) AS Attivo, ")
        sql.Append("COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.DataCreazione,CURDATE()) AS DataCreazione, COALESCE(v.Visite,0) AS Visite, ")
        sql.Append("0 AS Stato, COALESCE(v.Ricondizionato,0) AS Ricondizionato, ")
        sql.Append(StockWhereClause()).Append(" AS Giacenza, ")
        sql.Append(AvailabilityWhereClause()).Append(" AS Disponibilita, ")
        sql.Append(ReservedWhereClause()).Append(" AS Impegnata, ")
        sql.Append("COALESCE(v.PrezzoIvato,0) AS PrezzoIvato, COALESCE(v.PrezzoPromo,0) AS PrezzoPromo, COALESCE(v.PrezzoPromoIvato,0) AS PrezzoPromoIvato, ")
        sql.Append("COALESCE(v.InOfferta,0) AS InOfferta, v.OfferteDataFine, ")
        sql.Append("COALESCE(s.QtaVenduta,0) AS QtaVenduta, COALESCE(sy.VendutiAnno,0) AS VendutiAnno ")
        sql.Append("FROM vsuperarticoli v ")
        sql.Append("INNER JOIN articoli aBase ON aBase.id = v.id ")
        sql.Append("LEFT JOIN (")
        sql.Append(" SELECT ArticoliId, SUM(COALESCE(Giacenza,0)) AS Giacenza, SUM(COALESCE(Disponibilita,0)) AS Disponibilita, SUM(COALESCE(Impegnata,0)) AS Impegnata")
        sql.Append(" FROM articoli_giacenze")
        sql.Append(" GROUP BY ArticoliId")
        sql.Append(") stk ON stk.ArticoliId = v.id ")
        sql.Append("LEFT JOIN (")
        sql.Append(" SELECT dr.ArticoliId, SUM(COALESCE(dr.Qnt,0)) AS QtaVenduta")
        sql.Append(" FROM documentirighe dr")
        sql.Append(" INNER JOIN documenti d ON d.id = dr.DocumentiId")
        sql.Append(" WHERE d.TipoDocumentiId = 4 AND COALESCE(d.StatiId,0)=@closedState")
        sql.Append(" GROUP BY dr.ArticoliId")
        sql.Append(") s ON s.ArticoliId = v.id ")
        sql.Append("LEFT JOIN (")
        sql.Append(" SELECT dr.ArticoliId, SUM(COALESCE(dr.Qnt,0)) AS VendutiAnno")
        sql.Append(" FROM documentirighe dr")
        sql.Append(" INNER JOIN documenti d ON d.id = dr.DocumentiId")
        sql.Append(" WHERE d.TipoDocumentiId = 4 AND COALESCE(d.StatiId,0)=@closedState AND YEAR(COALESCE(d.DataDocumento,CURDATE())) = YEAR(CURDATE())")
        sql.Append(" GROUP BY dr.ArticoliId")
        sql.Append(") sy ON sy.ArticoliId = v.id ")
        sql.Append("WHERE COALESCE(v.NListino,1)=@listino AND COALESCE(v.id,0)>0 ")
        sql.Append("AND COALESCE(aBase.Abilitato,1)=1 ")
        sql.Append("AND ").Append(StockWhereClause()).Append(">=1 ")
        sql.Append("AND (COALESCE(v.PrezzoIvato,0)>0 OR COALESCE(v.PrezzoPromoIvato,0)>0 OR COALESCE(v.PrezzoPromo,0)>0) ")
        If Not String.IsNullOrWhiteSpace(whereClause) Then
            sql.Append("AND ").Append(whereClause).Append(" ")
        End If
        sql.Append("ORDER BY ").Append(orderClause).Append(" ")
        sql.Append("LIMIT ").Append(Math.Max(1, limit).ToString(CultureInfo.InvariantCulture))

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                Using cmd As New MySqlCommand(sql.ToString(), conn)
                    cmd.Parameters.AddWithValue("@listino", GetCurrentListino())
                    cmd.Parameters.AddWithValue("@closedState", GetClosedOrderState())
                    Using da As New MySqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        conn.Open()
                        da.Fill(dt)
                        Return dt
                    End Using
                End Using
            End Using
        Catch ex As Exception
            ReportHomeError("TryLoadProducts", ex)
        End Try

        Return Nothing
    End Function

    Private Function GetClosedOrderState() As Integer
        Dim state As Integer = 3
        Try
            Dim raw As String = Convert.ToString(ConfigurationManager.AppSettings("OrdineStatoChiuso"))
            If Not Integer.TryParse(raw, state) OrElse state <= 0 Then
                state = 3
            End If
        Catch
            state = 3
        End Try
        Return state
    End Function

    Private Function StockWhereClause() As String
        Return "COALESCE(stk.Giacenza, COALESCE(v.Giacenza,0))"
    End Function

    Private Function AvailabilityWhereClause() As String
        Return "COALESCE(stk.Disponibilita, COALESCE(v.Disponibilita,0))"
    End Function

    Private Function ReservedWhereClause() As String
        Return "COALESCE(stk.Impegnata, COALESCE(v.Impegnata,0))"
    End Function

    Private Function OfferWhereClause() As String
        Return "COALESCE(v.InOfferta,0)=1 AND " &
               "(v.OfferteDataInizio IS NULL OR CURDATE() >= v.OfferteDataInizio) AND " &
               "(v.OfferteDataFine IS NULL OR CURDATE() <= v.OfferteDataFine) AND " &
               "(v.OfferteDaListino IS NULL OR @listino >= v.OfferteDaListino) AND " &
               "(v.OfferteAListino IS NULL OR @listino <= v.OfferteAListino) AND " &
               "((COALESCE(v.PrezzoPromoIvato,0)>0 AND COALESCE(v.PrezzoPromoIvato,0) < COALESCE(v.PrezzoIvato,0)) " &
               "OR (COALESCE(v.PrezzoPromoIvato,0)=0 AND COALESCE(v.PrezzoPromo,0)>0 AND COALESCE(v.PrezzoPromo,0) < COALESCE(v.PrezzoIvato,0))) " &
               "AND " & StockWhereClause() & ">=1"
    End Function

    Private Function GetRecentlyViewedIds() As List(Of Integer)
        Dim result As New List(Of Integer)()

        MergeRecentIds(result, Convert.ToString(Session("ks_recent_ids")))

        Dim cookie As HttpCookie = Request.Cookies("ks_recent")
        If cookie IsNot Nothing Then
            MergeRecentIds(result, HttpUtility.UrlDecode(cookie.Value))
        End If

        Return result
    End Function

    Private Sub MergeRecentIds(ByVal target As List(Of Integer), ByVal raw As String)
        If target Is Nothing OrElse String.IsNullOrWhiteSpace(raw) Then
            Return
        End If

        Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        For Each part As String In parts
            Dim id As Integer = 0
            If Integer.TryParse(part.Trim(), id) AndAlso id > 0 AndAlso Not target.Contains(id) Then
                target.Add(id)
            End If
        Next
    End Sub

    Private Function TakeDistinctRows(ByVal count As Integer, ByVal used As HashSet(Of Integer), ParamArray ByVal sources() As DataTable) As DataTable
        Dim result As DataTable = CloneFirstTable(sources)
        Dim seen As New HashSet(Of Integer)()

        AddDistinctRows(result, count, used, seen, False, sources)
        If result.Rows.Count < count AndAlso used IsNot Nothing Then
            AddDistinctRows(result, count, used, seen, True, sources)
        End If

        Return result
    End Function

    Private Sub AddDistinctRows(ByVal target As DataTable,
                                ByVal count As Integer,
                                ByVal used As HashSet(Of Integer),
                                ByVal seen As HashSet(Of Integer),
                                ByVal ignoreGlobalUsed As Boolean,
                                ParamArray ByVal sources() As DataTable)
        If target Is Nothing OrElse sources Is Nothing Then
            Return
        End If

        For Each source As DataTable In sources
            If source Is Nothing Then
                Continue For
            End If

            For Each row As DataRow In source.Rows
                Dim id As Integer = SafeInt(row("id"))
                If id <= 0 Then
                    Continue For
                End If
                If seen.Contains(id) Then
                    Continue For
                End If
                If used IsNot Nothing AndAlso Not ignoreGlobalUsed AndAlso used.Contains(id) Then
                    Continue For
                End If

                target.ImportRow(row)
                seen.Add(id)
                If used IsNot Nothing AndAlso Not ignoreGlobalUsed Then
                    used.Add(id)
                End If

                If target.Rows.Count >= count Then
                    Exit Sub
                End If
            Next
        Next
    End Sub

    Private Function CloneFirstTable(ByVal sources() As DataTable) As DataTable
        If sources IsNot Nothing Then
            For Each source As DataTable In sources
                If source IsNot Nothing AndAlso source.Columns.Count > 0 Then
                    Return source.Clone()
                End If
            Next
        End If

        Return EmptyProductsTable()
    End Function

    Private Function EmptyProductsTable() As DataTable
        Dim dt As New DataTable()
        dt.Columns.Add("id", GetType(Integer))
        dt.Columns.Add("Codice", GetType(String))
        dt.Columns.Add("Ean", GetType(String))
        dt.Columns.Add("Descrizione1", GetType(String))
        dt.Columns.Add("Descrizione2", GetType(String))
        dt.Columns.Add("DescrizioneLunga", GetType(String))
        dt.Columns.Add("MarcheId", GetType(Integer))
        dt.Columns.Add("MarcheDescrizione", GetType(String))
        dt.Columns.Add("SettoriDescrizione", GetType(String))
        dt.Columns.Add("CategorieDescrizione", GetType(String))
        dt.Columns.Add("TipologieDescrizione", GetType(String))
        dt.Columns.Add("GruppiDescrizione", GetType(String))
        dt.Columns.Add("Img1", GetType(String))
        dt.Columns.Add("Img2", GetType(String))
        dt.Columns.Add("Img3", GetType(String))
        dt.Columns.Add("Img4", GetType(String))
        dt.Columns.Add("Abilitato", GetType(Integer))
        dt.Columns.Add("Attivo", GetType(Integer))
        dt.Columns.Add("Vetrina", GetType(Integer))
        dt.Columns.Add("DataCreazione", GetType(Date))
        dt.Columns.Add("Visite", GetType(Integer))
        dt.Columns.Add("Stato", GetType(Integer))
        dt.Columns.Add("Ricondizionato", GetType(Integer))
        dt.Columns.Add("Giacenza", GetType(Decimal))
        dt.Columns.Add("Disponibilita", GetType(Decimal))
        dt.Columns.Add("Impegnata", GetType(Decimal))
        dt.Columns.Add("PrezzoIvato", GetType(Decimal))
        dt.Columns.Add("PrezzoPromo", GetType(Decimal))
        dt.Columns.Add("PrezzoPromoIvato", GetType(Decimal))
        dt.Columns.Add("InOfferta", GetType(Integer))
        dt.Columns.Add("OfferteDataFine", GetType(Date))
        dt.Columns.Add("QtaVenduta", GetType(Decimal))
        dt.Columns.Add("VendutiAnno", GetType(Decimal))
        Return dt
    End Function

    Private Function ShuffleTable(ByVal source As DataTable) As DataTable
        If source Is Nothing OrElse source.Rows.Count <= 1 Then
            Return source
        End If

        Dim rows As New List(Of DataRow)()
        For Each row As DataRow In source.Rows
            rows.Add(row)
        Next

        For i As Integer = rows.Count - 1 To 1 Step -1
            Dim swapIndex As Integer = Rng.Next(0, i + 1)
            Dim tmp As DataRow = rows(i)
            rows(i) = rows(swapIndex)
            rows(swapIndex) = tmp
        Next

        Dim shuffled As DataTable = source.Clone()
        For Each row As DataRow In rows
            shuffled.ImportRow(row)
        Next
        Return shuffled
    End Function

    Private Function GetBrands(ByVal limit As Integer) As DataTable
        Dim sql As String = "SELECT id, Descrizione, img, link FROM marche WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Ordinamento,0), Descrizione LIMIT " & Math.Max(1, limit).ToString(CultureInfo.InvariantCulture)
        Return SafeTableQuery(sql, New DataTable(), "GetBrands")
    End Function

    Private Function IsTableEmpty(ByVal table As DataTable) As Boolean
        Return table Is Nothing OrElse table.Rows.Count = 0
    End Function

    Private Function SafeTableQuery(ByVal sql As String, ByVal fallback As DataTable, Optional ByVal context As String = "SafeTableQuery") As DataTable
        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                Using cmd As New MySqlCommand(sql, conn)
                    Using da As New MySqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        conn.Open()
                        da.Fill(dt)
                        If dt.Rows.Count > 0 Then
                            Return dt
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            ReportHomeError(context, ex)
        End Try

        Return fallback
    End Function

    Private Function SliceTable(ByVal source As DataTable, ByVal skip As Integer, ByVal take As Integer) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), EmptyProductsTable())
        If source Is Nothing Then
            Return result
        End If

        For i As Integer = skip To Math.Min(source.Rows.Count - 1, skip + take - 1)
            result.ImportRow(source.Rows(i))
        Next
        Return result
    End Function


    Private Function GetCurrentListino() As Integer
        Dim listino As Integer = 1
        If Session("Listino") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("Listino")), listino)
        End If
        If listino <= 0 Then listino = 1
        Return listino
    End Function

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Protected Function SafeInt(ByVal value As Object) As Integer
        Dim n As Integer = 0
        Integer.TryParse(Convert.ToString(value), n)
        Return n
    End Function

    Protected Function ProductTitle(ByVal descrizione1 As Object, ByVal descrizione2 As Object, ByVal id As Object) As String
        Dim t1 As String = Convert.ToString(descrizione1).Trim()
        Dim t2 As String = Convert.ToString(descrizione2).Trim()
        If Not String.IsNullOrWhiteSpace(t1) Then Return HttpUtility.HtmlEncode(t1)
        If Not String.IsNullOrWhiteSpace(t2) Then Return HttpUtility.HtmlEncode(t2)
        Return "Articolo " & Convert.ToString(id)
    End Function

    Protected Function ProductUrl(ByVal id As Object) As String
        Return "articolo.aspx?id=" & Convert.ToString(id)
    End Function

    Protected Function CartAddUrl(ByVal id As Object) As String
        Return "aggiungi.aspx?id=" & HttpUtility.UrlEncode(Convert.ToString(id))
    End Function

    Protected Function WishlistAddUrl(ByVal id As Object) As String
        Return "wishlist_add.aspx?id=" & HttpUtility.UrlEncode(Convert.ToString(id))
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

    Protected Function ResolveHeroSlideImage(ByVal value As Object, ByVal fallback As String) As String
        Return ResolveProjectImage(value, fallback, "/Public/assets/images/slideshows/")
    End Function

    Protected Function ResolveAdvertisingImage(ByVal value As Object, ByVal fallback As String) As String
        Return ResolveProjectImage(value, fallback, "/Public/assets/images/banner/")
    End Function

    Private Function ResolveProjectImage(ByVal value As Object, ByVal fallback As String, ParamArray ByVal candidateFolders() As String) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return fallback

        fileName = fileName.Replace("\", "/")
        If fileName.StartsWith("/") OrElse fileName.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            Return fileName
        End If

        fileName = Path.GetFileName(fileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return fallback
        End If

        If candidateFolders IsNot Nothing Then
            For Each folder As String In candidateFolders
                If String.IsNullOrWhiteSpace(folder) Then
                    Continue For
                End If

                Dim virtualPath As String = folder.TrimEnd("/"c) & "/" & fileName
                Try
                    Dim physicalPath As String = HostingEnvironment.MapPath("~" & virtualPath)
                    If Not String.IsNullOrWhiteSpace(physicalPath) AndAlso File.Exists(physicalPath) Then
                        Return virtualPath
                    End If
                Catch
                End Try
            Next
        End If

        Return fallback
    End Function

    Protected Function ProductImageThumb(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return "/Public/assets/images/item/laptop.webp"
        fileName = fileName.Replace("\", "/")
        fileName = Path.GetFileName(fileName)
        If fileName.StartsWith("_", StringComparison.OrdinalIgnoreCase) Then
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

    Protected Function BrandLink(ByVal brandId As Object, ByVal fallback As Object) As String
        Dim id As Integer = SafeInt(brandId)
        If id > 0 Then
            Return "articoli.aspx?mr=" & id.ToString(CultureInfo.InvariantCulture)
        End If
        Return ResolveLink(fallback, "articoli.aspx")
    End Function

    Protected Function CurrentPrice(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Return CurrentPrice(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Protected Function CurrentPrice(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Dim listino As Decimal = ToDecimal(priceIvato)
        Dim promoPrice As Decimal = 0D
        If TryGetValidPromoPrice(priceIvato, promo, promoIvato, inOfferta, promoPrice) Then
            Return promoPrice
        End If
        Return listino
    End Function

    Protected Function SavingsAmount(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Return SavingsAmount(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Protected Function SavingsAmount(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Dim listino As Decimal = ToDecimal(priceIvato)
        Dim current As Decimal = CurrentPrice(priceIvato, promo, promoIvato, inOfferta)
        If listino > current AndAlso current > 0D Then
            Return listino - current
        End If
        Return 0D
    End Function

    Protected Function ShowDiscount(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Boolean
        Return ShowDiscount(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Protected Function ShowDiscount(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Boolean
        Return SavingsAmount(priceIvato, promo, promoIvato, inOfferta) > 0D
    End Function

    Protected Function DiscountPercent(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Integer
        Return DiscountPercent(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Protected Function DiscountPercent(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Integer
        Dim listino As Decimal = ToDecimal(priceIvato)
        Dim current As Decimal = CurrentPrice(priceIvato, promo, promoIvato, inOfferta)
        If listino <= 0D OrElse current <= 0D OrElse current >= listino Then
            Return 0
        End If
        Return Convert.ToInt32(Math.Round(((listino - current) / listino) * 100D, MidpointRounding.AwayFromZero))
    End Function

    Protected Function FormatMoney(ByVal value As Object) As String
        Dim amount As Decimal = ToDecimal(value)
        Return amount.ToString("C2", ItCulture)
    End Function

    Protected Function AvailabilityPercent(ByVal giacenza As Object, ByVal sold As Object) As Decimal
        Dim available As Decimal = Math.Max(0D, ToDecimal(giacenza))
        Dim soldCount As Decimal = Math.Max(0D, ToDecimal(sold))
        Dim total As Decimal = soldCount + available
        If total <= 0D Then Return 0D
        Return Decimal.Round((soldCount / total) * 100D, 2, MidpointRounding.AwayFromZero)
    End Function

    Protected Function CountdownSeconds(ByVal offerteDataFine As Object) As Integer
        Dim target As DateTime
        If DateTime.TryParse(Convert.ToString(offerteDataFine), target) Then
            Dim diff As TimeSpan = target.Date.AddDays(1).Subtract(DateTime.Now)
            Return Math.Max(60, Convert.ToInt32(diff.TotalSeconds))
        End If
        Return 172800
    End Function

    Protected Function FormatQuantity(ByVal value As Object) As String
        Dim amount As Decimal = Math.Max(0D, ToDecimal(value))
        If amount = Math.Truncate(amount) Then
            Return Convert.ToInt32(amount).ToString(ItCulture)
        End If
        Return amount.ToString("N2", ItCulture)
    End Function

    Private Function TryGetValidPromoPrice(ByVal priceIvato As Object,
                                           ByVal promo As Object,
                                           ByVal promoIvato As Object,
                                           ByVal inOfferta As Object,
                                           ByRef promoPrice As Decimal) As Boolean
        promoPrice = 0D
        If SafeInt(inOfferta) <> 1 Then
            Return False
        End If

        Dim listino As Decimal = ToDecimal(priceIvato)
        Dim promoGross As Decimal = ToDecimal(promoIvato)
        Dim promoNet As Decimal = ToDecimal(promo)
        Dim candidate As Decimal = If(promoGross > 0D, promoGross, promoNet)

        If candidate <= 0D Then
            Return False
        End If

        If listino > 0D AndAlso candidate >= listino Then
            Return False
        End If

        promoPrice = candidate
        Return True
    End Function

    Private Function ToDecimal(ByVal value As Object) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then
            Return 0D
        End If

        Dim d As Decimal = 0D
        Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, d)
        If d = 0D Then
            Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, ItCulture, d)
        End If
        Return d
    End Function

    Private Function EncodeAttr(ByVal value As String) As String
        Return HttpUtility.HtmlAttributeEncode(If(value, String.Empty))
    End Function

    Private Function CardCaption(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim candidates As String() = {
            If(row.Table.Columns.Contains("TipologieDescrizione"), Convert.ToString(row("TipologieDescrizione")).Trim(), String.Empty),
            If(row.Table.Columns.Contains("CategorieDescrizione"), Convert.ToString(row("CategorieDescrizione")).Trim(), String.Empty),
            If(row.Table.Columns.Contains("MarcheDescrizione"), Convert.ToString(row("MarcheDescrizione")).Trim(), String.Empty),
            If(row.Table.Columns.Contains("Descrizione2"), Convert.ToString(row("Descrizione2")).Trim(), String.Empty)
        }

        For Each candidate As String In candidates
            If Not String.IsNullOrWhiteSpace(candidate) Then
                Return HttpUtility.HtmlEncode(candidate)
            End If
        Next

        Return String.Empty
    End Function

    Private Function QuickViewDescription(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim description As String = Convert.ToString(row("DescrizioneLunga")).Trim()
        If String.IsNullOrWhiteSpace(description) Then
            description = Convert.ToString(row("Descrizione2")).Trim()
        End If
        If String.IsNullOrWhiteSpace(description) Then
            description = HttpUtility.HtmlDecode(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id")))
        End If
        If description.Length > 220 Then
            description = description.Substring(0, 217).Trim() & "..."
        End If
        Return description
    End Function

    Private Function BuildQuickViewAttributes(ByVal row As DataRow) As String
        If row Is Nothing Then Return String.Empty

        Dim idText As String = Convert.ToString(row("id"))
        Dim title As String = HttpUtility.HtmlDecode(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id")))
        Dim brand As String = Convert.ToString(row("MarcheDescrizione")).Trim()
        Dim url As String = ProductUrl(row("id"))
        Dim img As String = ProductImageFull(row("Img1"))
        Dim priceText As String = FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")))
        Dim soldText As String = FormatQuantity(row("VendutiAnno"))
        Dim availableText As String = FormatQuantity(row("Giacenza"))
        Dim description As String = QuickViewDescription(row)
        Dim progress As String = AvailabilityPercent(row("Giacenza"), row("VendutiAnno")).ToString("0.##", CultureInfo.InvariantCulture)

        Dim sb As New StringBuilder()
        sb.Append(" data-ks-id='").Append(EncodeAttr(idText)).Append("'")
        sb.Append(" data-ks-title='").Append(EncodeAttr(title)).Append("'")
        sb.Append(" data-ks-brand='").Append(EncodeAttr(brand)).Append("'")
        sb.Append(" data-ks-url='").Append(EncodeAttr(url)).Append("'")
        sb.Append(" data-ks-img='").Append(EncodeAttr(img)).Append("'")
        sb.Append(" data-ks-price='").Append(EncodeAttr(priceText)).Append("'")
        sb.Append(" data-ks-sold='").Append(EncodeAttr(soldText)).Append("'")
        sb.Append(" data-ks-available='").Append(EncodeAttr(availableText)).Append("'")
        sb.Append(" data-ks-progress='").Append(EncodeAttr(progress)).Append("'")
        sb.Append(" data-ks-description='").Append(EncodeAttr(description)).Append("'")
        Return sb.ToString()
    End Function

    Private Function ProductGalleryImages(ByVal row As DataRow) As List(Of String)
        Dim images As New List(Of String)()
        If row Is Nothing Then
            images.Add(ProductImageFull(Nothing))
            Return images
        End If

        Dim fields As String() = {"Img1", "Img2", "Img3", "Img4"}
        For Each fieldName As String In fields
            If row.Table.Columns.Contains(fieldName) Then
                Dim rawValue As String = Convert.ToString(row(fieldName)).Trim()
                If String.IsNullOrWhiteSpace(rawValue) Then
                    Continue For
                End If

                Dim imageUrl As String = ProductImageFull(rawValue)
                If Not String.IsNullOrWhiteSpace(imageUrl) AndAlso Not images.Contains(imageUrl) Then
                    images.Add(imageUrl)
                End If
            End If
        Next

        If images.Count = 0 Then
            images.Add(ProductImageFull(Nothing))
        End If

        Return images
    End Function

    Private Function RenderActionButtons(ByVal row As DataRow, ByVal compact As Boolean) As String
        If row Is Nothing Then Return String.Empty

        Dim quickViewAttrs As String = BuildQuickViewAttributes(row)
        Dim compareAttrs As String = quickViewAttrs
        Dim buttonClass As String = If(compact, "list-product-btn flex-row", "list-product-btn top-0 end-0")
        Dim tooltipClass As String = If(compact, "hover-tooltip", "hover-tooltip tooltip-left")

        Dim sb As New StringBuilder()
        sb.Append("<ul class='").Append(buttonClass).Append("'>")
        sb.Append("<li><a href='").Append(CartAddUrl(row("id"))).Append("' class='box-icon add-to-cart btn-icon-action ").Append(tooltipClass).Append("' aria-label='Aggiungi al carrello'><i class='icon icon-cart2'></i><span class='tooltip'>Aggiungi al carrello</span></a></li>")
        sb.Append("<li class='wishlist'><a href='").Append(WishlistAddUrl(row("id"))).Append("' class='box-icon btn-icon-action ").Append(tooltipClass).Append("' aria-label='Wishlist'><i class='icon icon-heart2'></i><span class='tooltip'>Wishlist</span></a></li>")
        sb.Append("<li><a href='#quickView' data-bs-toggle='modal' class='box-icon quickview btn-icon-action ").Append(tooltipClass).Append(" js-ks-quickview'").Append(quickViewAttrs).Append(" aria-label='Vedi prodotto'><i class='icon icon-view'></i><span class='tooltip'>Vedi prodotto</span></a></li>")
        sb.Append("<li><a href='#compare' data-bs-toggle='offcanvas' class='box-icon btn-icon-action ").Append(tooltipClass).Append(" js-ks-compare'").Append(compareAttrs).Append(" aria-label='Confronta'><i class='icon icon-compare1'></i><span class='tooltip'>Confronta</span></a></li>")
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Function RenderSaleBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not ShowDiscount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            Return String.Empty
        End If

        Return "<div class='box-sale-wrap top-0 start-0 pst-default z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>" &
               DiscountPercent(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")).ToString(ItCulture) &
               "%</p></div>"
    End Function

    Private Function RenderCenterSaleBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not ShowDiscount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            Return String.Empty
        End If

        Return "<div class='box-sale-wrap style-2 z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>" &
               HttpUtility.HtmlEncode(FormatMoney(SavingsAmount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")))) &
               "</p></div>"
    End Function

    Private Function RenderRefurbishedBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not IsRefurbished(row) Then
            Return String.Empty
        End If

        Return "<div class='badge-refurbished'><img src='/Public/assets/images/ico/refurbished.png' alt='Ricondizionato'></div>"
    End Function

    Private Function RenderPriceBlock(ByVal row As DataRow, ByVal emphasize As Boolean) As String
        Dim sb As New StringBuilder()
        Dim priceClass As String = If(emphasize, "new-price h4 fw-normal text-primary mb-0", "new-price body-md-2 fw-medium text-primary mb-0")
        Dim oldPriceClass As String = If(emphasize, "old-price price-text text-main-2", "old-price body-md-2 text-main-2")

        sb.Append("<p class='price-wrap fw-medium'>")
        sb.Append("<span class='").Append(priceClass).Append("'>").Append(FormatMoney(CurrentPrice(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</span>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append("<span class='").Append(oldPriceClass).Append("'>").Append(FormatMoney(row("PrezzoIvato"))).Append("</span>")
        End If
        sb.Append("</p>")

        Return sb.ToString()
    End Function

    Protected Function RenderDealCard(ByVal dataItem As Object) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return String.Empty
        Dim row As DataRow = rowView.Row

        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-border ks-deal-card wow fadeInLeft' data-wow-delay='0s'>")
        sb.Append("<div class='card-product-wrapper overflow-visible'>")
        sb.Append("<div class='product-thumb-image'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='card-image'>")
        sb.Append("<img class='lazyload img-product' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("' />")
        sb.Append("</a>")
        sb.Append(RenderActionButtons(row, False))
        sb.Append(RenderRefurbishedBadge(row))
        sb.Append(RenderSaleBadge(row))
        sb.Append("</div>")
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'>")
        sb.Append("<div class='box-title gap-xl-12'>")
        sb.Append("<div class='d-flex flex-column'>")
        If Not String.IsNullOrWhiteSpace(Convert.ToString(row("MarcheDescrizione"))) Then
            sb.Append("<p class='caption text-main-2 font-2'>").Append(HttpUtility.HtmlEncode(Convert.ToString(row("MarcheDescrizione")))).Append("</p>")
        End If
        sb.Append("<h6><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6>")
        sb.Append("</div>")
        sb.Append(RenderPriceBlock(row, True))
        sb.Append("</div>")
        If ShowDiscount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")) Then
            sb.Append("<p class='box-sale-tag'>Risparmi ").Append(FormatMoney(SavingsAmount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta")))).Append("</p>")
        End If
        sb.Append("<div class='box-infor-detail gap-xl-20'>")
        sb.Append("<div class='countdown-box'><div class='js-countdown' data-timer='").Append(CountdownSeconds(row("OfferteDataFine")).ToString(ItCulture)).Append("' data-labels='Giorni,Ore,Min,Sec'></div></div>")
        sb.Append("<div class='product-progress-sale'>")
        sb.Append("<div class='progress-sold progress' role='progressbar' aria-valuemin='0' aria-valuemax='100'>")
        sb.Append("<div class='progress-bar bg-danger' style='width:").Append(AvailabilityPercent(row("Giacenza"), row("VendutiAnno")).ToString("0.##", CultureInfo.InvariantCulture)).Append("%'></div>")
        sb.Append("</div>")
        sb.Append("<div class='box-quantity d-flex justify-content-between'>")
        sb.Append("<p class='text-avaiable caption'>Venduti: <span class='fw-bold'>").Append(FormatQuantity(row("VendutiAnno"))).Append("</span></p>")
        sb.Append("<p class='text-avaiable caption'>Disponibili: <span class='fw-bold'>").Append(FormatQuantity(row("Giacenza"))).Append("</span></p>")
        sb.Append("</div>")
        sb.Append("</div>")
        sb.Append("</div>")
        sb.Append("</div>")
        sb.Append("</div>")
        Return sb.ToString()
    End Function

    Private Function RenderRowCardFromRow(ByVal row As DataRow) As String
        If row Is Nothing Then Return String.Empty

        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-row row-small-2 ks-row-card'>")
        sb.Append("<div class='card-product-wrapper'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='product-img'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageThumb(row("Img1"))).Append("' data-src='").Append(ProductImageThumb(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a>")
        sb.Append(RenderRefurbishedBadge(row))
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'><div class='box-title'>")
        Dim caption As String = CardCaption(row)
        If Not String.IsNullOrWhiteSpace(caption) Then
            sb.Append("<div class='bg-white relative z-5'><p class='caption text-main-2 font-2'>").Append(caption).Append("</p>")
        Else
            sb.Append("<div class='bg-white relative z-5'>")
        End If
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='name-product body-md-2 fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></div>")
        sb.Append("<div class='group-btn'>")
        sb.Append(RenderPriceBlock(row, False))
        sb.Append(RenderActionButtons(row, True))
        sb.Append("</div>")
        sb.Append("</div></div>")
        Return sb.ToString()
    End Function

    Protected Function RenderRowCard(ByVal dataItem As Object) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return String.Empty
        Return RenderRowCardFromRow(rowView.Row)
    End Function

    Protected Function RenderBigCard(ByVal dataItem As Object) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return String.Empty
        Dim row As DataRow = rowView.Row
        Dim images As List(Of String) = ProductGalleryImages(row)
        Dim caption As String = CardCaption(row)
        Dim hasDiscount As Boolean = ShowDiscount(row("PrezzoIvato"), row("PrezzoPromo"), row("PrezzoPromoIvato"), row("InOfferta"))

        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-border style-thums-2 p-lg-30 wow fadeInUp ks-big-card' data-wow-delay='0s'>")
        sb.Append("<div class='card-product-wrapper overflow-visible aspect-ratio-0'>")
        sb.Append("<div class='product-thumb-slider thumbs-right ks-home-product-view'>")
        sb.Append("<div class='swiper tf-product-view-main'><div class='swiper-wrapper'>")
        For Each imageUrl As String In images
            sb.Append("<div class='swiper-slide'><a href='").Append(ProductUrl(row("id"))).Append("' class='d-block tf-image-view'>")
            sb.Append("<img class='lazyload' src='").Append(imageUrl).Append("' data-src='").Append(imageUrl).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
            sb.Append("</a></div>")
        Next
        sb.Append("</div></div>")
        sb.Append("<div class='swiper tf-product-view-thumbs' data-direction='vertical'><div class='swiper-wrapper'>")
        For Each imageUrl As String In images
            sb.Append("<div class='swiper-slide'><div class='item'><img class='lazyload' src='").Append(imageUrl).Append("' data-src='").Append(imageUrl).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'></div></div>")
        Next
        sb.Append("</div></div>")
        sb.Append("</div>")
        sb.Append(RenderActionButtons(row, False))
        sb.Append(RenderRefurbishedBadge(row))
        sb.Append(RenderCenterSaleBadge(row))
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'>")
        sb.Append("<div class='box-title gap-xl-6'>")
        If Not String.IsNullOrWhiteSpace(caption) Then
            sb.Append("<p class='caption text-main-2 font-2'>").Append(caption).Append("</p>")
        End If
        sb.Append("<h6 class='bg-white relative z-5'><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6>")
        sb.Append("</div>")
        If hasDiscount Then
            sb.Append("<div class='countdown-box'><div class='js-countdown' data-timer='").Append(CountdownSeconds(row("OfferteDataFine")).ToString(ItCulture)).Append("' data-labels='Giorni,Ore,Min,Sec'></div></div>")
        End If
        sb.Append("<div class='group-btn'>")
        sb.Append(RenderPriceBlock(row, True))
        sb.Append(RenderActionButtons(row, True))
        sb.Append("</div>")
        sb.Append("</div></div>")
        Return sb.ToString()
    End Function

    Protected Function RenderGridCard(ByVal dataItem As Object) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return String.Empty
        Dim row As DataRow = rowView.Row

        Dim sb As New StringBuilder()
        sb.Append("<div class='card-product style-img-border wow fadeInLeft ks-grid-card' data-wow-delay='0s'>")
        sb.Append("<div class='card-product-wrapper'>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='product-img'>")
        sb.Append("<img class='img-product lazyload' src='").Append(ProductImageFull(row("Img1"))).Append("' data-src='").Append(ProductImageFull(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' src='").Append(ProductImageThumb(row("Img1"))).Append("' data-src='").Append(ProductImageThumb(row("Img1"))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("</a>")
        sb.Append(RenderActionButtons(row, False))
        sb.Append(RenderRefurbishedBadge(row))
        sb.Append(RenderSaleBadge(row))
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'>")
        sb.Append("<div class='box-title'>")
        Dim caption As String = CardCaption(row)
        If Not String.IsNullOrWhiteSpace(caption) Then
            sb.Append("<div class='bg-white relative z-5'><p class='caption text-main-2 font-2'>").Append(caption).Append("</p>")
        Else
            sb.Append("<div class='bg-white relative z-5'>")
        End If
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='name-product body-md-2 fw-semibold text-secondary link'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></div>")
        sb.Append(RenderPriceBlock(row, False))
        sb.Append("</div>")
        sb.Append("</div></div>")
        Return sb.ToString()
    End Function

    Protected Function IsRefurbished(ByVal row As DataRowView) As Boolean
        If row Is Nothing Then Return False
        Return IsRefurbished(row.Row)
    End Function

    Protected Function IsRefurbished(ByVal row As DataRow) As Boolean
        If row Is Nothing Then Return False

        Dim stato As Integer = 0
        Try
            If row.Table.Columns.Contains("Stato") Then
                stato = SafeInt(row("Stato"))
            End If
        Catch
        End Try

        If stato = 34 Then Return True
        If row.Table.Columns.Contains("Ricondizionato") AndAlso SafeInt(row("Ricondizionato")) = 1 Then Return True

        Dim d1 As String = Convert.ToString(row("Descrizione1")).ToLowerInvariant()
        Dim d2 As String = Convert.ToString(row("Descrizione2")).ToLowerInvariant()
        Return (d1 & " " & d2).Contains("ricondizionato")
    End Function

    Private Sub ReportHomeError(ByVal context As String, ByVal ex As Exception)
        If ex Is Nothing Then
            Return
        End If

        Try
            KeepStoreLog.Error("Default.aspx", context, ex, HttpContext.Current)
        Catch
            System.Diagnostics.Trace.TraceError("HOME - " & context & " - " & ex.ToString())
        End Try
    End Sub

End Class
