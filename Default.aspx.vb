Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Class _Default
    Inherits System.Web.UI.Page

    Private Const RecentCookieName As String = "ks_recent"
    Private Const RecentSessionKey As String = "ks_recent"

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim ivaTipo As Integer = SafeInt(Session("IvaTipo"), 0)
        Dim ordineChiuso As Integer = GetSettingInt("OrdineStatoChiuso", 3)
        Dim currentListino As Integer = GetCurrentListino()

        ConfigureHomeDataSources(ivaTipo, ordineChiuso, currentListino)

        If Not IsPostBack Then
            BindHomeGridTabs()
            BindRecentlyViewed(ivaTipo, ordineChiuso, currentListino)
        End If
    End Sub

    Private Sub ConfigureHomeDataSources(ivaTipo As Integer, ordineChiuso As Integer, currentListino As Integer)
        Dim baseSelect As String = BuildVsuperArticoliSelect(ivaTipo, ordineChiuso, currentListino)

        ' Home KeepStore:
        ' - Occasione Imperdibile: promo attive con giacenza reale > 0, rotazione casuale
        ' - Best Seller: alimentato con la logica vetrina / nuovi arrivi del sito storico
        ' - Feature / Featured Products: prodotti in vetrina e ad alta evidenza
        ' - Toprate / Top 20: prodotti più visitati
        ' - Top Selling Product: prodotti più venduti, privilegiando quelli non in promo
        ' - On Sale / On-sale Product: promo attive, ordinate per convenienza
        sdsDealOfDay.SelectCommand = BuildDealOfDayQuery(baseSelect, 8)
        sdsBestSeller.SelectCommand = BuildBestSellerQuery(baseSelect, 12)

        sdsTabFeature.SelectCommand = BuildFeatureQuery(baseSelect, 7)
        sdsTabToprate.SelectCommand = BuildTopViewedQuery(baseSelect, 7)
        sdsTabOnSale.SelectCommand = BuildOnSaleQuery(baseSelect, 7)

        sdsTop20.SelectCommand = BuildTop20Query(baseSelect, 10)
        sdsFeaturedMini.SelectCommand = BuildFeaturedMiniQuery(baseSelect, 10)
        sdsTopSellingMini.SelectCommand = BuildTopSellingMiniQuery(baseSelect, 10)
        sdsOnSaleMini.SelectCommand = BuildOnSaleMiniQuery(baseSelect, 10)

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
        BindGridTab(sdsTabFeature, rptFeatureLeft, rptFeatureCenter, rptFeatureRight, 3, 1, 3)
        BindGridTab(sdsTabToprate, rptToprateLeft, rptToprateCenter, rptToprateRight, 3, 1, 3)
        BindGridTab(sdsTabOnSale, rptOnSaleLeft, rptOnSaleCenter, rptOnSaleRight, 3, 1, 3)
    End Sub

    Private Sub BindGridTab(ds As SqlDataSource,
                            rptLeft As Repeater,
                            rptCenter As Repeater,
                            rptRight As Repeater,
                            leftCount As Integer,
                            centerCount As Integer,
                            rightCount As Integer)
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
            Dim provider As String = Convert.ToString(ds.ProviderName)
            If String.IsNullOrWhiteSpace(provider) OrElse provider.Equals("System.Data.SqlClient", StringComparison.OrdinalIgnoreCase) Then
                ds.ProviderName = "MySql.Data.MySqlClient"
            End If
        Catch
            ' Non bloccare la pagina se il datasource è già valorizzato diversamente.
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

    Private Sub BindRecentlyViewed(ivaTipo As Integer, ordineChiuso As Integer, currentListino As Integer)
        Dim ids As List(Of Integer) = ReadRecentIds(10)
        Dim baseSelect As String = BuildVsuperArticoliSelect(ivaTipo, ordineChiuso, currentListino)

        phRecentlyViewed.Visible = True

        If ids.Count = 0 Then
            sdsRecentlyViewed.SelectCommand = BuildTopViewedQuery(baseSelect, 10)
            Return
        End If

        sdsRecentlyViewed.SelectCommand = BuildRecentlyViewedQuery(baseSelect, ids, 10)
    End Sub

    Private Function ReadRecentIds(maxCount As Integer) As List(Of Integer)
        Dim items As New List(Of Integer)()

        MergeRecentIds(items, Convert.ToString(Session(RecentSessionKey)), maxCount)

        Try
            Dim c As HttpCookie = Request.Cookies(RecentCookieName)
            If c IsNot Nothing Then
                MergeRecentIds(items, HttpUtility.UrlDecode(c.Value), maxCount)
            End If
        Catch
            ' ignore
        End Try

        Return items
    End Function

    Private Sub MergeRecentIds(target As List(Of Integer), raw As String, maxCount As Integer)
        If target Is Nothing OrElse maxCount <= 0 Then Exit Sub
        If String.IsNullOrWhiteSpace(raw) Then Exit Sub

        Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        For Each part As String In parts
            Dim n As Integer
            If Integer.TryParse(part.Trim(), n) AndAlso n > 0 Then
                If Not target.Contains(n) Then
                    target.Add(n)
                    If target.Count >= maxCount Then Exit For
                End If
            End If
        Next
    End Sub

    ' -------------------------------------------------
    ' Query builders
    ' -------------------------------------------------
    Private Function BuildVsuperArticoliSelect(ivaTipo As Integer, ordineChiuso As Integer, currentListino As Integer) As String
        Return "SELECT " &
               "vsuperarticoli.id AS Articoliid, " &
               "vsuperarticoli.Codice, " &
               "vsuperarticoli.Ean, " &
               "vsuperarticoli.Descrizione1, " &
               "vsuperarticoli.Descrizione2, " &
               "vsuperarticoli.DescrizioneLunga, " &
               "vsuperarticoli.MarcheDescrizione, " &
               "vsuperarticoli.CategorieDescrizione, " &
               "vsuperarticoli.SettoriDescrizione, " &
               "vsuperarticoli.TipologieDescrizione, " &
               "vsuperarticoli.Img1, vsuperarticoli.Img2, vsuperarticoli.Img3, vsuperarticoli.Img4, " &
               "vsuperarticoli.Prezzo, " &
               "(CASE WHEN " & ivaTipo.ToString(CultureInfo.InvariantCulture) & "=2 THEN vsuperarticoli.PrezzoIvato ELSE vsuperarticoli.Prezzo END) AS PrezzoMostrato, " &
               "(CASE WHEN " & ivaTipo.ToString(CultureInfo.InvariantCulture) & "=2 THEN vsuperarticoli.PrezzoPromoIvato ELSE vsuperarticoli.PrezzoPromo END) AS PrezzoPromoMostrato, " &
               "vsuperarticoli.InOfferta, " &
               "vsuperarticoli.PrezzoIvato, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, " &
               "vsuperarticoli.SpeditoGratis, " &
               "COALESCE(vsuperarticoli.Giacenza,0) AS Giacenza, " &
               "COALESCE(vsuperarticoli.Disponibilita,0) AS Disponibilita, " &
               "COALESCE(vsuperarticoli.Impegnata,0) AS Impegnata, " &
               "COALESCE(vsuperarticoli.VendutiTotali,0) AS VendutiTotali, " &
               "COALESCE(vsuperarticoli.VendutiAnno,0) AS VendutiAnno, " &
               "COALESCE(vsuperarticoli.Visite,0) AS Visite, " &
               "COALESCE(vsuperarticoli.Vetrina,0) AS Vetrina, " &
               "COALESCE(vsuperarticoli.NListino,0) AS NListino, " &
               "vsuperarticoli.DataCreazione, " &
               "COALESCE(vsuperarticoli.Ricondizionato,0) AS Ricondizionato, " &
               "vsuperarticoli.NoteRicondizionato, " &
               "vsuperarticoli.OfferteDataFine " &
               "FROM (" & BuildScopedCatalogQuery(ordineChiuso, currentListino) & ") vsuperarticoli"
    End Function

    Private Function BuildScopedCatalogQuery(ordineChiuso As Integer, currentListino As Integer) As String
        Dim listino As Integer = currentListino
        If listino <= 0 Then listino = 1

        Dim wh As String = "dr.TipoRiga = 'A' AND IFNULL(dr.ArticoliId,0) > 0 AND ABS(IFNULL(dr.Qnt,0)) > 0 AND COALESCE(d.TipoDocumentiId,0) > 0 AND (COALESCE(d.StatiId,0) >= " & ordineChiuso.ToString(CultureInfo.InvariantCulture) & " OR COALESCE(d.Pagato,0) = 1 OR COALESCE(d.Ordine_Web,0) = 1)"

        ' La view vsuperarticoli può restituire più righe per lo stesso articolo
        ' (es. varianti / giacenze / listini). In HOME servono card univoche per articolo.
        ' Qui aggreghiamo a livello ArticoloId, mantenendo i campi descrittivi stabili
        ' e sommando le disponibilità reali.
        Return "SELECT " &
               "v.id, " &
               "MAX(v.Codice) AS Codice, " &
               "MAX(v.Ean) AS Ean, " &
               "MAX(v.Descrizione1) AS Descrizione1, " &
               "MAX(v.Descrizione2) AS Descrizione2, " &
               "MAX(v.DescrizioneLunga) AS DescrizioneLunga, " &
               "MAX(v.MarcheDescrizione) AS MarcheDescrizione, " &
               "MAX(v.CategorieDescrizione) AS CategorieDescrizione, " &
               "MAX(v.SettoriDescrizione) AS SettoriDescrizione, " &
               "MAX(v.TipologieDescrizione) AS TipologieDescrizione, " &
               "MAX(v.Img1) AS Img1, " &
               "MAX(v.Img2) AS Img2, " &
               "MAX(v.Img3) AS Img3, " &
               "MAX(v.Img4) AS Img4, " &
               "MAX(v.Prezzo) AS Prezzo, " &
               "MAX(v.PrezzoIvato) AS PrezzoIvato, " &
               "MIN(CASE WHEN COALESCE(v.InOfferta,0)=1 AND COALESCE(v.PrezzoPromo,0)>0 THEN v.PrezzoPromo ELSE NULL END) AS PrezzoPromo, " &
               "MIN(CASE WHEN COALESCE(v.InOfferta,0)=1 AND COALESCE(v.PrezzoPromoIvato,0)>0 THEN v.PrezzoPromoIvato ELSE NULL END) AS PrezzoPromoIvato, " &
               "MAX(COALESCE(v.InOfferta,0)) AS InOfferta, " &
               "MAX(COALESCE(v.SpeditoGratis,0)) AS SpeditoGratis, " &
               "SUM(COALESCE(v.Giacenza,0)) AS Giacenza, " &
               "SUM(COALESCE(v.Disponibilita,0)) AS Disponibilita, " &
               "SUM(COALESCE(v.Impegnata,0)) AS Impegnata, " &
               "MAX(COALESCE(Vendite.QntTot,0)) AS VendutiTotali, " &
               "MAX(COALESCE(Vendite.QntAnno,0)) AS VendutiAnno, " &
               "MAX(COALESCE(v.Visite,0)) AS Visite, " &
               "MAX(COALESCE(v.Vetrina,0)) AS Vetrina, " &
               "MAX(COALESCE(v.NListino,0)) AS NListino, " &
               "MAX(v.DataCreazione) AS DataCreazione, " &
               "MAX(COALESCE(v.Ricondizionato,0)) AS Ricondizionato, " &
               "MAX(v.NoteRicondizionato) AS NoteRicondizionato, " &
               "MIN(CASE WHEN COALESCE(v.InOfferta,0)=1 THEN v.OfferteDataFine ELSE NULL END) AS OfferteDataFine " &
               "FROM vsuperarticoli v " &
               "LEFT JOIN ( " &
               "   SELECT dr.ArticoliId AS articoli_id, SUM(ABS(IFNULL(dr.Qnt,0))) AS QntTot, " &
               "          SUM(CASE WHEN YEAR(COALESCE(d.DataDocumento, STR_TO_DATE(CONCAT(COALESCE(d.Anno, YEAR(CURDATE())),'-12-31'), '%Y-%m-%d'))) = YEAR(CURDATE()) THEN ABS(IFNULL(dr.Qnt,0)) ELSE 0 END) AS QntAnno " &
               "   FROM documentirighe dr " &
               "   INNER JOIN documenti d ON d.id = dr.DocumentiId " &
               "   WHERE " & wh & " " &
               "   GROUP BY dr.ArticoliId " &
               ") Vendite ON Vendite.articoli_id = v.id " &
               "WHERE COALESCE(v.NListino,1) = " & listino.ToString(CultureInfo.InvariantCulture) & " " &
               "GROUP BY v.id"
    End Function

    Private Function AvailableWhere(useStrictGiacenza As Boolean) As String
        If useStrictGiacenza Then
            Return "COALESCE(vsuperarticoli.Giacenza,0) >= 1"
        End If

        Return "(COALESCE(vsuperarticoli.Giacenza,0) >= 1 OR COALESCE(vsuperarticoli.Disponibilita,0) >= 1)"
    End Function

    Private Function PromoWhere() As String
        Return "COALESCE(vsuperarticoli.InOfferta,0) = 1 AND (COALESCE(vsuperarticoli.PrezzoPromo,0) > 0 OR COALESCE(vsuperarticoli.PrezzoPromoIvato,0) > 0)"
    End Function

    Private Function BuildPooledQuery(baseSelect As String,
                                      whereClause As String,
                                      innerOrderBy As String,
                                      limit As Integer,
                                      Optional poolMultiplier As Integer = 4,
                                      Optional outerOrderBy As String = "RAND()") As String
        If limit <= 0 Then limit = 8
        If poolMultiplier <= 0 Then poolMultiplier = 4

        Dim poolSize As Integer = Math.Max(limit * poolMultiplier, limit)
        Dim sql As String = "SELECT pool_items.* FROM (" & baseSelect

        If Not String.IsNullOrWhiteSpace(whereClause) Then
            sql &= " WHERE " & whereClause
        End If

        sql &= " ORDER BY " & innerOrderBy
        sql &= " LIMIT " & poolSize.ToString(CultureInfo.InvariantCulture)
        sql &= ") pool_items"

        If Not String.IsNullOrWhiteSpace(outerOrderBy) Then
            sql &= " ORDER BY " & outerOrderBy
        End If

        sql &= " LIMIT " & limit.ToString(CultureInfo.InvariantCulture)
        Return sql
    End Function

    Private Function BuildDealOfDayQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(True) & " AND " & PromoWhere(),
                                "COALESCE(vsuperarticoli.OfferteDataFine,'9999-12-31') ASC, (COALESCE(PrezzoMostrato,0) - COALESCE(PrezzoPromoMostrato,0)) DESC, COALESCE(vsuperarticoli.VendutiTotali,0) DESC",
                                limit,
                                5,
                                "RAND()")
    End Function

    Private Function BuildBestSellerQuery(baseSelect As String, limit As Integer) As String
        ' Per richiesta: il blocco Best Seller eredita la logica visiva della vecchia vetrina / nuovi arrivi.
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.Vetrina,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC, COALESCE(vsuperarticoli.VendutiTotali,0) DESC, COALESCE(vsuperarticoli.Visite,0) DESC",
                                limit,
                                4,
                                "COALESCE(pool_items.Vetrina,0) DESC, COALESCE(pool_items.DataCreazione,DATE('1000-01-01')) DESC, COALESCE(pool_items.VendutiTotali,0) DESC, RAND()")
    End Function

    Private Function BuildFeatureQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.Vetrina,0) DESC, COALESCE(vsuperarticoli.InOfferta,0) DESC, COALESCE(vsuperarticoli.Visite,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC",
                                limit,
                                4,
                                "COALESCE(pool_items.Vetrina,0) DESC, RAND()")
    End Function

    Private Function BuildTopViewedQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.Visite,0) DESC, COALESCE(vsuperarticoli.VendutiTotali,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC",
                                limit,
                                5,
                                "RAND()")
    End Function

    Private Function BuildOnSaleQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(True) & " AND " & PromoWhere(),
                                "(COALESCE(PrezzoMostrato,0) - COALESCE(PrezzoPromoMostrato,0)) DESC, COALESCE(vsuperarticoli.OfferteDataFine,'9999-12-31') ASC, COALESCE(vsuperarticoli.VendutiTotali,0) DESC",
                                limit,
                                5,
                                "COALESCE(pool_items.OfferteDataFine,'9999-12-31') ASC, RAND()")
    End Function

    Private Function BuildTop20Query(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.Visite,0) DESC, COALESCE(vsuperarticoli.VendutiTotali,0) DESC, COALESCE(vsuperarticoli.InOfferta,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC",
                                limit,
                                5,
                                "RAND()")
    End Function

    Private Function BuildFeaturedMiniQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.Vetrina,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC, COALESCE(vsuperarticoli.Visite,0) DESC",
                                limit,
                                5,
                                "RAND()")
    End Function

    Private Function BuildTopSellingMiniQuery(baseSelect As String, limit As Integer) As String
        Return BuildPooledQuery(baseSelect,
                                AvailableWhere(False),
                                "COALESCE(vsuperarticoli.VendutiTotali,0) DESC, COALESCE(vsuperarticoli.InOfferta,0) ASC, COALESCE(vsuperarticoli.Visite,0) DESC, COALESCE(vsuperarticoli.DataCreazione,DATE('1000-01-01')) DESC",
                                limit,
                                5,
                                "RAND()")
    End Function

    Private Function BuildOnSaleMiniQuery(baseSelect As String, limit As Integer) As String
        Return BuildOnSaleQuery(baseSelect, limit)
    End Function

    Private Function BuildRecentlyViewedQuery(baseSelect As String, ids As IList(Of Integer), limit As Integer) As String
        If ids Is Nothing OrElse ids.Count = 0 Then
            Return BuildTopViewedQuery(baseSelect, limit)
        End If

        If limit <= 0 Then limit = 10

        Dim safeIds As New List(Of Integer)()
        For Each id As Integer In ids
            If id > 0 AndAlso Not safeIds.Contains(id) Then
                safeIds.Add(id)
                If safeIds.Count >= limit Then Exit For
            End If
        Next

        If safeIds.Count = 0 Then
            Return BuildTopViewedQuery(baseSelect, limit)
        End If

        Dim idsCsv As String = String.Join(",", safeIds.Select(Function(x) x.ToString(CultureInfo.InvariantCulture)).ToArray())
        Dim visitedLimit As Integer = Math.Min(limit, safeIds.Count)
        Dim extraLimit As Integer = Math.Max(0, limit - visitedLimit)

        Dim visitedSql As String =
            "SELECT recent_items.*, 0 AS sort_group, FIELD(recent_items.Articoliid," & idsCsv & ") AS sort_pos FROM (" &
            baseSelect &
            " WHERE vsuperarticoli.id IN (" & idsCsv & ") " &
            " ORDER BY FIELD(vsuperarticoli.id," & idsCsv & ") " &
            " LIMIT " & visitedLimit.ToString(CultureInfo.InvariantCulture) &
            ") recent_items"

        If extraLimit <= 0 Then
            Return "SELECT * FROM (" & visitedSql & ") recent_final ORDER BY sort_group ASC, sort_pos ASC"
        End If

        Dim fillerSql As String =
            "SELECT filler_items.*, 1 AS sort_group, 999999 AS sort_pos FROM (" &
            baseSelect &
            " WHERE " & AvailableWhere(False) &
            " AND vsuperarticoli.id NOT IN (" & idsCsv & ") " &
            " ORDER BY COALESCE(vsuperarticoli.Visite,0) DESC, COALESCE(vsuperarticoli.DataCreazione,CURDATE()) DESC, RAND() " &
            " LIMIT " & extraLimit.ToString(CultureInfo.InvariantCulture) &
            ") filler_items"

        Return "SELECT * FROM ((" & visitedSql & ") UNION ALL (" & fillerSql & ")) recent_union ORDER BY sort_group ASC, sort_pos ASC"
    End Function

    ' -------------------------------------------------
    ' Lettura sessione / configurazione
    ' -------------------------------------------------
    Private Function GetSettingInt(key As String, defaultValue As Integer) As Integer
        Try
            Dim value As String = ConfigurationManager.AppSettings(key)
            Dim n As Integer
            If Integer.TryParse(value, n) Then Return n
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function GetSessionInt(key As String, defaultValue As Integer) As Integer
        Try
            If Session(key) Is Nothing Then Return defaultValue
            Dim tmp As Integer
            If Integer.TryParse(Convert.ToString(Session(key), CultureInfo.InvariantCulture), tmp) Then
                Return tmp
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function GetCurrentListino() As Integer
        Dim n As Integer = GetSessionInt("Listino", 0)
        If n <= 0 Then n = GetSessionInt("listino", 0)
        If n <= 0 Then n = 1

        Session("Listino") = n
        Session("listino") = n

        Return n
    End Function

    Private Function SafeInt(value As Object, defaultValue As Integer) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim n As Integer
            If Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), n) Then Return n
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function SafeDecimal(value As Object) As Decimal
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return 0D

            Dim d As Decimal
            If Decimal.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
                Return d
            End If

            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then
                Return d
            End If
        Catch
        End Try
        Return 0D
    End Function

    Private Function SafeWholeNumber(value As Object) As Integer
        Dim d As Decimal = SafeDecimal(value)
        If d <= 0D Then Return 0
        If d > Integer.MaxValue Then Return Integer.MaxValue
        Return CInt(Math.Round(d, 0, MidpointRounding.AwayFromZero))
    End Function

    ' -------------------------------------------------
    ' Helper immagini / output ASPX
    ' -------------------------------------------------
    Protected Function GetHomeProductImage(primaryImg As Object, fallbackImg As Object) As String
        Dim fileName As String = ResolveImageFileName(primaryImg, fallbackImg)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return ThemeManager.ProductImageUrl(String.Empty)
        End If

        Dim lowFile As String = BuildLowResHomeFileName(fileName)
        Dim lowPublicVirtual As String = "~/Public/assets/images/articoli/" & HttpUtility.UrlPathEncode(lowFile)
        Return ResolveUrl(lowPublicVirtual)
    End Function

    Protected Function GetHomeProductImageFallback(primaryImg As Object, fallbackImg As Object) As String
        Dim fileName As String = ResolveImageFileName(primaryImg, fallbackImg)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return ThemeManager.ProductImageUrl(String.Empty)
        End If

        Dim publicOriginalVirtual As String = "~/Public/assets/images/articoli/" & HttpUtility.UrlPathEncode(fileName)
        Dim publicOriginalPhysical As String = SafeMapPath("~/Public/assets/images/articoli/" & fileName)
        If Not String.IsNullOrWhiteSpace(publicOriginalPhysical) AndAlso File.Exists(publicOriginalPhysical) Then
            Return ResolveUrl(publicOriginalVirtual)
        End If

        Dim lowFile As String = BuildLowResHomeFileName(fileName)
        Dim lowPublicVirtual As String = "~/Public/assets/images/articoli/" & HttpUtility.UrlPathEncode(lowFile)
        Dim lowPublicPhysical As String = SafeMapPath("~/Public/assets/images/articoli/" & lowFile)
        If Not String.IsNullOrWhiteSpace(lowPublicPhysical) AndAlso File.Exists(lowPublicPhysical) Then
            Return ResolveUrl(lowPublicVirtual)
        End If

        Return ThemeManager.ProductImageUrl(fileName)
    End Function

    Private Function ResolveImageFileName(primaryImg As Object, fallbackImg As Object) As String
        Dim p As String = CleanImageFileName(primaryImg)
        If String.IsNullOrWhiteSpace(p) OrElse p = "0" Then
            p = CleanImageFileName(fallbackImg)
        End If
        Return p
    End Function

    Private Function CleanImageFileName(value As Object) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return String.Empty

        s = s.Trim().Replace("\", "/")
        If s = "0" Then Return String.Empty

        Try
            s = Path.GetFileName(s)
        Catch
            ' fallback sul valore già pulito
        End Try

        Return If(s, String.Empty).Trim()
    End Function

    Private Function BuildLowResHomeFileName(fileName As String) As String
        Dim cleanName As String = CleanImageFileName(fileName)
        If String.IsNullOrWhiteSpace(cleanName) Then Return String.Empty
        If cleanName.StartsWith("_", StringComparison.Ordinal) Then Return cleanName
        Return "_" & cleanName
    End Function

    Private Function SafeMapPath(virtualPath As String) As String
        Try
            Return Server.MapPath(virtualPath)
        Catch
            Return String.Empty
        End Try
    End Function

    Protected Function RenderCaptionLabel(ParamArray values() As Object) As String
        If values IsNot Nothing Then
            For Each value As Object In values
                Dim s As String = Convert.ToString(value)
                If Not String.IsNullOrWhiteSpace(s) Then
                    s = s.Trim()
                    If Not s.Equals("0", StringComparison.OrdinalIgnoreCase) Then
                        Return s
                    End If
                End If
            Next
        End If
        Return "Prodotto"
    End Function

    Protected Function ComposeSearchDescription(shortDesc As Object, longDesc As Object) As String
        Dim s1 As String = Convert.ToString(shortDesc)
        Dim s2 As String = Convert.ToString(longDesc)
        If String.IsNullOrWhiteSpace(s1) Then Return If(s2, String.Empty)
        If String.IsNullOrWhiteSpace(s2) Then Return s1
        Return s1.Trim() & " " & s2.Trim()
    End Function

    Protected Function IsRefurbished(value As Object) As Boolean
        Return SafeInt(value, 0) = 1
    End Function

    Protected Function RenderRefurbishedBadge(value As Object, Optional extraCss As String = "") As String
        If Not IsRefurbished(value) Then Return String.Empty
        Dim cls As String = "ks-refurbished-badge"
        If Not String.IsNullOrWhiteSpace(extraCss) Then cls &= " " & extraCss.Trim()
        Return "<span class=""" & HttpUtility.HtmlAttributeEncode(cls) & """ title=""Ricondizionato""><img src=""" & ResolveUrl("~/Public/assets/images/ico/refurbished.png") & """ alt=""Ricondizionato"" /></span>"
    End Function

    Protected Function GetCountdownSeconds(endDate As Object) As Integer
        Dim dt As DateTime
        If Not TryParseOfferEndDate(endDate, dt) Then Return 0

        Dim sec As Double = (dt.ToUniversalTime() - DateTime.UtcNow).TotalSeconds
        If sec < 0 Then sec = 0
        If sec > Integer.MaxValue Then sec = Integer.MaxValue
        Return CInt(Math.Floor(sec))
    End Function

    Private Function TryParseOfferEndDate(value As Object, ByRef result As DateTime) As Boolean
        result = DateTime.MinValue
        If value Is Nothing OrElse value Is DBNull.Value Then Return False

        If TypeOf value Is DateTime Then
            result = DirectCast(value, DateTime)
        Else
            Dim s As String = Convert.ToString(value).Trim()
            If s.Length = 0 Then Return False

            Dim formats As String() = {"yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy", "dd/MM/yyyy HH:mm:ss", "yyyy/MM/dd", "MM/dd/yyyy"}
            If Not DateTime.TryParseExact(s, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, result) Then
                If Not DateTime.TryParseExact(s, formats, CultureInfo.GetCultureInfo("it-IT"), DateTimeStyles.None, result) Then
                    If Not DateTime.TryParse(s, result) Then
                        Return False
                    End If
                End If
            End If
        End If

        If result.TimeOfDay = TimeSpan.Zero Then
            result = result.Date.AddDays(1).AddSeconds(-1)
        End If

        Return True
    End Function

    Protected Function GetSoldQty(vendutiTotali As Object) As Integer
        Dim n As Integer = SafeWholeNumber(vendutiTotali)
        If n < 0 Then n = 0
        Return n
    End Function

    Protected Function GetAvailableQty(giacenza As Object) As Integer
        Dim n As Integer = SafeWholeNumber(giacenza)
        If n < 0 Then n = 0
        Return n
    End Function

    Protected Function GetSoldPercent(vendutiTotali As Object, giacenza As Object) As Integer
        Dim sold As Integer = GetSoldQty(vendutiTotali)
        Dim available As Integer = GetAvailableQty(giacenza)
        Dim total As Integer = sold + available
        If total <= 0 Then Return 0

        Dim perc As Integer = CInt(Math.Round((sold * 100D) / total, 0, MidpointRounding.AwayFromZero))
        If sold > 0 AndAlso perc < 1 Then perc = 1
        If perc < 0 Then perc = 0
        If perc > 100 Then perc = 100
        Return perc
    End Function

    Protected Function RenderPricePair(prezzoMostrato As Object,
                                       prezzoPromoMostrato As Object,
                                       inOfferta As Object,
                                       newCss As String,
                                       oldCss As String) As String
        Dim currentPrice As Decimal = GetCurrentPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta)
        Dim regularPrice As Decimal = GetRegularPrice(prezzoMostrato)
        Dim parts As New List(Of String)()

        parts.Add("<span class=""" & newCss & """>" & HttpUtility.HtmlEncode(FormatMoney(currentPrice)) & "</span>")

        If HasPromoPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta) Then
            parts.Add("<span class=""" & oldCss & """>" & HttpUtility.HtmlEncode(FormatMoney(regularPrice)) & "</span>")
        End If

        Return String.Join(String.Empty, parts.ToArray())
    End Function

    Protected Function RenderPriceWithSave(prezzoMostrato As Object,
                                           prezzoPromoMostrato As Object,
                                           inOfferta As Object,
                                           newCss As String,
                                           saveCss As String) As String
        Dim currentPrice As Decimal = GetCurrentPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta)
        Dim saved As Decimal = GetSavedAmount(prezzoMostrato, prezzoPromoMostrato, inOfferta)
        Dim parts As New List(Of String)()

        parts.Add("<span class=""" & newCss & """>" & HttpUtility.HtmlEncode(FormatMoney(currentPrice)) & "</span>")

        If saved > 0D Then
            parts.Add("<span class=""" & saveCss & """>Risparmi: " & HttpUtility.HtmlEncode(FormatMoney(saved)) & "</span>")
        End If

        Return String.Join(String.Empty, parts.ToArray())
    End Function

    Protected Function RenderSaleWrap(prezzoMostrato As Object,
                                      prezzoPromoMostrato As Object,
                                      inOfferta As Object,
                                      labelText As String,
                                      valueCss As String,
                                      Optional extraCss As String = "") As String
        Dim perc As Integer = GetDiscountPercent(prezzoMostrato, prezzoPromoMostrato, inOfferta)
        If perc <= 0 Then Return String.Empty

        Dim cls As String = "box-sale-wrap"
        If Not String.IsNullOrWhiteSpace(extraCss) Then
            cls &= " " & extraCss.Trim()
        End If

        Return "<div class=""" & cls & """><p class=""small-text"">" & HttpUtility.HtmlEncode(labelText) & "</p><p class=""" & valueCss & """>" & perc.ToString(CultureInfo.InvariantCulture) & "%</p></div>"
    End Function

    Protected Function RenderSavedWrap(prezzoMostrato As Object,
                                       prezzoPromoMostrato As Object,
                                       inOfferta As Object,
                                       labelText As String,
                                       valueCss As String,
                                       Optional extraCss As String = "") As String
        Dim saved As Decimal = GetSavedAmount(prezzoMostrato, prezzoPromoMostrato, inOfferta)
        If saved <= 0D Then Return String.Empty

        Dim cls As String = "box-sale-wrap"
        If Not String.IsNullOrWhiteSpace(extraCss) Then
            cls &= " " & extraCss.Trim()
        End If

        Return "<div class=""" & cls & """><p class=""small-text"">" & HttpUtility.HtmlEncode(labelText) & "</p><p class=""" & valueCss & """>" & HttpUtility.HtmlEncode(FormatMoney(saved)) & "</p></div>"
    End Function

    Private Function HasPromoPrice(prezzoMostrato As Object,
                                   prezzoPromoMostrato As Object,
                                   inOfferta As Object) As Boolean
        If SafeInt(inOfferta, 0) <> 1 Then Return False

        Dim regularPrice As Decimal = GetRegularPrice(prezzoMostrato)
        Dim promoPrice As Decimal = GetPromoPrice(prezzoPromoMostrato)

        Return regularPrice > 0D AndAlso promoPrice > 0D AndAlso promoPrice < regularPrice
    End Function

    Private Function GetRegularPrice(prezzoMostrato As Object) As Decimal
        Dim d As Decimal = SafeDecimal(prezzoMostrato)
        If d < 0D Then d = 0D
        Return d
    End Function

    Private Function GetPromoPrice(prezzoPromoMostrato As Object) As Decimal
        Dim d As Decimal = SafeDecimal(prezzoPromoMostrato)
        If d < 0D Then d = 0D
        Return d
    End Function

    Private Function GetCurrentPrice(prezzoMostrato As Object,
                                     prezzoPromoMostrato As Object,
                                     inOfferta As Object) As Decimal
        If HasPromoPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta) Then
            Return GetPromoPrice(prezzoPromoMostrato)
        End If
        Return GetRegularPrice(prezzoMostrato)
    End Function

    Private Function GetSavedAmount(prezzoMostrato As Object,
                                    prezzoPromoMostrato As Object,
                                    inOfferta As Object) As Decimal
        If Not HasPromoPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta) Then Return 0D

        Dim saved As Decimal = GetRegularPrice(prezzoMostrato) - GetPromoPrice(prezzoPromoMostrato)
        If saved < 0D Then saved = 0D
        Return saved
    End Function

    Private Function GetDiscountPercent(prezzoMostrato As Object,
                                        prezzoPromoMostrato As Object,
                                        inOfferta As Object) As Integer
        If Not HasPromoPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta) Then Return 0

        Dim regularPrice As Decimal = GetRegularPrice(prezzoMostrato)
        Dim promoPrice As Decimal = GetPromoPrice(prezzoPromoMostrato)
        If regularPrice <= 0D Then Return 0

        Dim perc As Integer = CInt(Math.Round((1D - (promoPrice / regularPrice)) * 100D, 0, MidpointRounding.AwayFromZero))
        If perc < 0 Then perc = 0
        If perc > 100 Then perc = 100
        Return perc
    End Function

    Private Function FormatMoney(value As Decimal) As String
        Return value.ToString("C", CultureInfo.GetCultureInfo("it-IT"))
    End Function


    Private Function JsEscaped(value As String) As String
        If String.IsNullOrEmpty(value) Then Return String.Empty
        Return HttpUtility.JavaScriptStringEncode(value)
    End Function

    Protected Function RenderProductActions(articoloId As Object,
                                            descrizione As Object,
                                            img1 As Object,
                                            prezzoMostrato As Object,
                                            prezzoPromoMostrato As Object,
                                            inOfferta As Object,
                                            wrapperCss As String,
                                            Optional ean As Object = Nothing,
                                            Optional brand As Object = Nothing,
                                            Optional descrizioneBreve As Object = Nothing,
                                            Optional codice As Object = Nothing,
                                            Optional ricondizionato As Object = Nothing) As String
        Dim id As Integer = SafeInt(articoloId, 0)
        If id <= 0 Then Return String.Empty

        Dim url As String = "articolo.aspx?id=" & id.ToString(CultureInfo.InvariantCulture)
        Dim title As String = Convert.ToString(descrizione)
        Dim imageUrl As String = GetHomeProductImage(img1, Nothing)
        Dim priceText As String = FormatMoney(GetCurrentPrice(prezzoMostrato, prezzoPromoMostrato, inOfferta))
        Dim eanText As String = Convert.ToString(ean)
        Dim brandText As String = Convert.ToString(brand)
        Dim descText As String = Convert.ToString(descrizioneBreve)
        If String.IsNullOrWhiteSpace(descText) Then descText = Convert.ToString(descrizione)
        Dim codeText As String = Convert.ToString(codice)
        Dim descLongText As String = descText
        Dim refurbishedText As String = If(IsRefurbished(ricondizionato), "1", "0")
        Dim tipCss As String = If(Not String.IsNullOrWhiteSpace(wrapperCss) AndAlso (wrapperCss.IndexOf("top-0", StringComparison.OrdinalIgnoreCase) >= 0 OrElse wrapperCss.IndexOf("end-0", StringComparison.OrdinalIgnoreCase) >= 0), " tooltip-left", String.Empty)

        Dim sb As New StringBuilder()
        sb.Append("<ul class=""").Append(HttpUtility.HtmlAttributeEncode(wrapperCss)).Append(""">")

        sb.Append("<li><a href=""#"" class=""box-icon add-to-cart btn-icon-action hover-tooltip js-ks-add-cart")
        sb.Append(tipCss)
        sb.Append(""" data-ks-id=""").Append(id.ToString(CultureInfo.InvariantCulture))
        sb.Append(""" onclick=""return ksHomeClientAction('cart',this);"">")
        sb.Append("<i class=""icon icon-cart2""></i><span class=""tooltip"">Aggiungi al carrello</span></a></li>")

        sb.Append("<li class=""wishlist""><a href=""#"" class=""box-icon btn-icon-action hover-tooltip js-ks-wishlist")
        sb.Append(tipCss)
        sb.Append(""" data-ks-id=""").Append(id.ToString(CultureInfo.InvariantCulture))
        sb.Append(""" onclick=""return ksHomeWishlist(this);"">")
        sb.Append("<i class=""icon icon-heart2""></i><span class=""tooltip"">Aggiungi ai preferiti</span></a></li>")

        sb.Append("<li><a href=""").Append(HttpUtility.HtmlAttributeEncode(url))
        sb.Append(""" class=""box-icon quickview btn-icon-action hover-tooltip")
        sb.Append(tipCss)
        sb.Append(""">")
        sb.Append("<i class=""icon icon-view""></i><span class=""tooltip"">Vedi prodotto</span></a></li>")

        sb.Append("<li><a href=""#ksCompareCanvas"" data-bs-toggle=""offcanvas"" class=""box-icon btn-icon-action hover-tooltip js-ks-compare")
        sb.Append(tipCss)
        sb.Append(""" data-ks-id=""").Append(id.ToString(CultureInfo.InvariantCulture))
        sb.Append(""" data-ks-title=""").Append(HttpUtility.HtmlAttributeEncode(title))
        sb.Append(""" data-ks-url=""").Append(HttpUtility.HtmlAttributeEncode(url))
        sb.Append(""" data-ks-img=""").Append(HttpUtility.HtmlAttributeEncode(imageUrl))
        sb.Append(""" data-ks-price=""").Append(HttpUtility.HtmlAttributeEncode(priceText))
        sb.Append(""" data-ks-ean=""").Append(HttpUtility.HtmlAttributeEncode(eanText))
        sb.Append(""" data-ks-brand=""").Append(HttpUtility.HtmlAttributeEncode(brandText))
        sb.Append(""" data-ks-desc=""").Append(HttpUtility.HtmlAttributeEncode(descText))
        sb.Append(""" data-ks-desc-long=""").Append(HttpUtility.HtmlAttributeEncode(descLongText))
        sb.Append(""" data-ks-code=""").Append(HttpUtility.HtmlAttributeEncode(codeText))
        sb.Append(""" data-ks-refurbished=""").Append(HttpUtility.HtmlAttributeEncode(refurbishedText))
        sb.Append(""" onclick=""return ksHomeCompare(this);"">")
        sb.Append("<i class=""icon icon-compare1""></i><span class=""tooltip"">Confronta</span></a></li>")

        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Protected Sub btnHomeAction_Click(sender As Object, e As EventArgs)
        Dim actionType As String = String.Empty
        Dim productId As Integer = 0

        Try
            actionType = If(hfHomeActionType.Value, String.Empty).Trim().ToLowerInvariant()
        Catch
            actionType = String.Empty
        End Try

        Try
            productId = SafeInt(hfHomeActionProductId.Value, 0)
        Catch
            productId = 0
        End Try

        If productId <= 0 Then Exit Sub

        Select Case actionType
            Case "cart"
                Session("Carrello_ArticoloId") = productId
                Session("Carrello_TCId") = -1
                Session("Carrello_Quantita") = 1
                Session("Carrello_Pagina") = Request.RawUrl
                Response.Redirect("aggiungi.aspx", False)
                Context.ApplicationInstance.CompleteRequest()
        End Select
    End Sub

End Class
