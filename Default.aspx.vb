Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Net
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
    Private Const RuntimeSiteBaseUrl As String = "https://www.taikun.it"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        MarkBodyAsHome()
        ApplyHomeSeo()
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
                    current = Convert.ToString(body.Attributes("class"))
                End If
                If current.IndexOf("ks-home-main", StringComparison.OrdinalIgnoreCase) < 0 Then
                    body.Attributes("class") = (current & " ks-home-main").Trim()
                End If
            End If
        Catch
        End Try
    End Sub

    Private Sub ApplyHomeSeo()
        Const pageTitle As String = "KeepStore - Informatica, telefonia, assistenza e accessori"
        Const description As String = "Tecnologia, assistenza e accessori per lavoro e casa: computer, telefonia, stampanti, consumabili, periferiche e supporto tecnico KeepStore."
        Dim canonical As String = HomeCanonicalUrl()
        Dim heroImage As String = BuildRuntimeAssetUrl("/Public/assets/images/banner/Banner_PC_ricondizionati_1200x560.png")
        Dim logoUrl As String = BuildRuntimeAssetUrl("/Public/assets/images/logo/logo.webp")

        Page.Title = pageTitle
        SeoBuilder.AddOrReplaceMeta(Me, "description", description)
        SeoBuilder.AddOrReplaceMeta(Me, "keywords", "KeepStore,informatica,telefonia,assistenza tecnica,computer,stampanti,consumabili,periferiche,accessori")
        SeoBuilder.AddOrReplaceMeta(Me, "robots", "index,follow")
        SeoBuilder.SetCanonical(Me, canonical)
        SeoBuilder.ApplyOpenGraph(Me, pageTitle, description, canonical, heroImage)
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:card", "summary_large_image")
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:title", pageTitle)
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:description", description)
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:image", heroImage)
        SeoBuilder.ApplyJsonLd(Me, SeoBuilder.BuildHomeJsonLd(Me, pageTitle, description, canonical, logoUrl))
    End Sub

    Private Function HomeCanonicalUrl() As String
        Try
            Dim root As String = ResolveUrl("~/")
            If String.IsNullOrWhiteSpace(root) Then
                root = "/"
            End If
            If Not root.StartsWith("/", StringComparison.Ordinal) Then
                root = "/" & root.TrimStart("/"c)
            End If
            Return RuntimeSiteBaseUrl.TrimEnd("/"c) & root.TrimEnd("/"c) & "/"
        Catch
            Return RuntimeSiteBaseUrl.TrimEnd("/"c) & "/"
        End Try
    End Function

    Private Sub BindHome()
        Dim hero As DataTable = GetHeroSlides()
        rptHeroSlides.DataSource = hero
        rptHeroSlides.DataBind()

        Dim sideBanners As DataTable = GetSideBanners()
        rptSideBanners.DataSource = sideBanners
        rptSideBanners.DataBind()
        ApplyHeroMode(ResolveHeroMode(rptHeroSlides.Items.Count > 0, If(sideBanners Is Nothing, 0, sideBanners.Rows.Count)))

        Dim sectors As List(Of CatalogMenuSector) = CatalogMenuProvider.LoadCatalogMenu()
        If sectors Is Nothing Then
            sectors = New List(Of CatalogMenuSector)()
        End If
        If sectors.Count = 0 Then
            sectors = BuildHomeFallbackSectors()
        End If
        Dim sectorRows As List(Of CatalogMenuSector) = If(sectors.Count > 12, sectors.GetRange(0, 12), sectors)
        Dim heroSectorRows As List(Of CatalogMenuSector) = If(sectors.Count > 9, sectors.GetRange(0, 9), sectors)
        rptHeroDepartments.DataSource = heroSectorRows
        rptHeroDepartments.DataBind()
        If HomeHeroDepartmentsPanel IsNot Nothing Then
            HomeHeroDepartmentsPanel.Visible = (heroSectorRows.Count > 0)
        End If
        rptHomeMainCategories.DataSource = sectorRows
        rptHomeMainCategories.DataBind()
        If HomeMainCategoriesSection IsNot Nothing Then
            HomeMainCategoriesSection.Visible = (sectorRows.Count > 0)
        End If

        Dim usedBusinessKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim usedDisplayKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim offerPool As DataTable = GetOfferPool(96)
        Dim dealPool As DataTable = GetDealOfferPool(96)
        Dim featuredPool As DataTable = GetFeaturedPool(96)
        Dim newArrivalsPool As DataTable = GetNewArrivalsPool(120)
        Dim topRatedPool As DataTable = GetTopRatedPool(120)
        Dim bestSellerPool As DataTable = GetBestSellerPool(120)
        Dim currentYearSellingPool As DataTable = GetCurrentYearSellingPool(120)
        Dim topSellingPool As DataTable = GetPureTopSellingPool(120)
        Dim fallbackCatalogPool As DataTable = GetCatalogFallbackPool(160)

        Dim dealRows As DataTable = TakeDistinctRows(6, usedBusinessKeys, dealPool)
        CommitDisplayKeys(dealRows, usedDisplayKeys)
        rptDealOfDay.DataSource = dealRows
        rptDealOfDay.DataBind()
        If HomeOffersSection IsNot Nothing Then
            HomeOffersSection.Visible = True
        End If
        If HomeOffersFallback IsNot Nothing Then
            HomeOffersFallback.Visible = IsTableEmpty(dealRows)
        End If
        If HomeOffersSliderWrap IsNot Nothing Then
            HomeOffersSliderWrap.Visible = Not IsTableEmpty(dealRows)
        End If

        Dim featuredRows As DataTable = TakeDistinctRows(8, usedBusinessKeys, featuredPool, newArrivalsPool, fallbackCatalogPool)
        CommitDisplayKeys(featuredRows, usedDisplayKeys)
        rptHomeFeaturedProducts.DataSource = featuredRows
        rptHomeFeaturedProducts.DataBind()
        If HomeFeaturedProductsSection IsNot Nothing Then
            HomeFeaturedProductsSection.Visible = Not IsTableEmpty(featuredRows)
        End If

        If HomeWidePromoSection IsNot Nothing Then HomeWidePromoSection.Visible = True
        If HomeCollectionSection IsNot Nothing Then HomeCollectionSection.Visible = True
        If HomeBottomPromoSection IsNot Nothing Then HomeBottomPromoSection.Visible = True

        If HomeLegacyEditorialSection IsNot Nothing Then
            HomeLegacyEditorialSection.Visible = False
        End If

        Dim bestRows As DataTable = TakeDistinctRows(8, usedBusinessKeys, bestSellerPool, currentYearSellingPool, topSellingPool, topRatedPool, fallbackCatalogPool)
        rptBestSeller.DataSource = bestRows
        rptBestSeller.DataBind()
        If HomeLegacyBestSection IsNot Nothing Then
            HomeLegacyBestSection.Visible = Not IsTableEmpty(bestRows)
        End If

        Dim recentRows As DataTable = GetRecentlyViewedProducts(8, New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), True, Nothing, False)
        rptRecentlyViewed.DataSource = recentRows
        rptRecentlyViewed.DataBind()
        If HomeRecentlyViewedSection IsNot Nothing Then
            HomeRecentlyViewedSection.Visible = True
        End If

        If HomeLowerColumnsSection IsNot Nothing Then
            HomeLowerColumnsSection.Visible = False
        End If

        Dim brandRows As DataTable = FilterBrandRows(GetBrands(24), 12)
        rptBrands.DataSource = brandRows
        rptBrands.DataBind()
        If HomeBrandsSection IsNot Nothing Then
            HomeBrandsSection.Visible = Not IsTableEmpty(brandRows)
        End If
    End Sub

    Private Function BuildHomeFallbackSectors() As List(Of CatalogMenuSector)
        Dim result As New List(Of CatalogMenuSector)()
        result.Add(BuildHomeFallbackSector("Computer e notebook", "articoli.aspx?q=computer"))
        result.Add(BuildHomeFallbackSector("Telefonia e accessori", "articoli.aspx?q=telefonia"))
        result.Add(BuildHomeFallbackSector("Stampanti e consumabili", "articoli.aspx?q=stampanti"))
        result.Add(BuildHomeFallbackSector("Periferiche e reti", "articoli.aspx?q=periferiche"))
        Return result
    End Function

    Private Function BuildHomeFallbackSector(ByVal description As String, ByVal url As String) As CatalogMenuSector
        Dim sector As New CatalogMenuSector()
        sector.Id = 0
        sector.Descrizione = description
        sector.Img = String.Empty
        sector.ImgUrl = String.Empty
        sector.DefaultUrl = url
        Return sector
    End Function

    Private Function ResolveHeroMode(ByVal hasHeroSlides As Boolean, ByVal sideBannerCount As Integer) As String
        If Not hasHeroSlides Then
            Return "none"
        End If

        Return "full"
    End Function

    Private Sub ApplyHeroMode(ByVal heroMode As String)
        Dim normalizedMode As String = heroMode
        If String.IsNullOrWhiteSpace(normalizedMode) Then
            normalizedMode = "none"
        End If
        normalizedMode = normalizedMode.Trim().ToLowerInvariant()

        Slide_Show_Container.Visible = (normalizedMode <> "none")
        HeroSliderWrap.Visible = (normalizedMode <> "none")
        HeroSideWrap.Visible = (normalizedMode = "full")
        rptSideBanners.Visible = (normalizedMode = "full")
        HomeHeroSection.Visible = (normalizedMode <> "none")

        If HomeHeroShell IsNot Nothing Then
            Dim sideClass As String = If(normalizedMode = "full", " ks-home-has-promos", " ks-home-no-promos")
            HomeHeroShell.Attributes("class") = "ks-home-hero-grid ks-home-hero-mode-" & normalizedMode & sideClass
            HomeHeroShell.Attributes("data-ks-hero-mode") = normalizedMode
        End If

        If HomeHeroSection IsNot Nothing Then
            HomeHeroSection.Attributes("class") = "ks-home-hero-area ks-home-hero-mode-" & normalizedMode
            HomeHeroSection.Attributes("data-ks-hero-mode") = normalizedMode
        End If
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
        Dim wideSource As DataTable = DistinctRowsByColumn(GetHeroWideBanners(), "Image")
        If wideSource IsNot Nothing AndAlso wideSource.Rows.Count > 0 Then
            Return SliceTable(wideSource, 0, 1)
        End If

        Return HeroSlidesFallback()
    End Function

    Private Function HeroSlidesFallback() As DataTable
        Dim dt As New DataTable()
        dt.Columns.Add("Caption", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Eyebrow", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("ProductId", GetType(Integer))
        dt.Rows.Add(New Object() {"Tecnologia, assistenza e accessori per il tuo lavoro e la tua casa",
                                  "/Public/assets/images/banner/Banner_PC_ricondizionati_1200x560.png",
                                  "articoli.aspx?inpromo=1",
                                  "KeepStore tech",
                                  "Computer, telefonia, stampanti, consumabili e periferiche selezionate, con supporto tecnico diretto.",
                                  0})
        Return dt
    End Function

    Private Function GetSideBanners() As DataTable
        Dim sideSource As DataTable = DistinctRowsByColumn(GetHeroSideBannerSource(), "Image")
        Return EnsureTwoSideBanners(sideSource)
    End Function

    Private Function EnsureTwoSideBanners(ByVal source As DataTable) As DataTable
        Dim fallback As DataTable = SideBannersFallback()
        Dim result As DataTable = fallback.Clone()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        AddSideBannerRows(result, seen, source, 2)
        AddSideBannerRows(result, seen, fallback, 2)

        Return result
    End Function

    Private Sub AddSideBannerRows(ByVal target As DataTable, ByVal seen As HashSet(Of String), ByVal source As DataTable, ByVal limit As Integer)
        If target Is Nothing OrElse source Is Nothing Then
            Return
        End If

        For Each row As DataRow In source.Rows
            Dim imageKey As String = Convert.ToString(If(row.Table.Columns.Contains("Image"), row("Image"), String.Empty)).Trim()
            Dim titleKey As String = Convert.ToString(If(row.Table.Columns.Contains("Title"), row("Title"), String.Empty)).Trim()
            Dim key As String = If(Not String.IsNullOrWhiteSpace(imageKey), imageKey, titleKey)
            If String.IsNullOrWhiteSpace(key) OrElse seen.Contains(key) Then
                Continue For
            End If

            seen.Add(key)
            target.ImportRow(row)
            If target.Rows.Count >= limit Then
                Exit For
            End If
        Next
    End Sub

    Private Function GetHeroWideBanners() As DataTable
        Dim sql As String = "SELECT id, COALESCE(NULLIF(Descrizione,''),'Promozioni KeepStore') AS Caption, Immagine AS Image, Link AS LinkUrl " &
                            "FROM bannerv2 " &
                            "WHERE COALESCE(AziendeId,1)=1 AND COALESCE(Posizione,0)=3 " &
                            "ORDER BY COALESCE(Ordinamento,0), id DESC LIMIT 24"
        Dim dt As DataTable = SafeTableQuery(sql, HeroSlidesFallback(), "GetHeroWideBanners")
        dt = FilterRowsByResolvedImage(dt, "Image", AddressOf ResolveAdvertisingImagePath)
        Return PrepareHeroRows(dt, "Promo KeepStore", "Selezione reale KeepStore")
    End Function

    Private Function GetHeroSideBannerSource() As DataTable
        Dim sql As String = "SELECT p.id, " &
                            "COALESCE(NULLIF(p.caption,''), NULLIF(s.titolo,''), NULLIF(s.descrizione,''), 'Selezione KeepStore') AS Title, " &
                            "NULLIF(s.descrizione,'') AS Description, " &
                            "p.image AS Image, p.link AS LinkUrl, 'Promo' AS Badge " &
                            "FROM slideshows s " &
                            "INNER JOIN slideshows_parts p ON p.slideshowid = s.id " &
                            "WHERE COALESCE(s.abilitato,0)=1 AND LOWER(COALESCE(s.placeholder,''))='defaultpage' " &
                            "AND (s.dataInizioPubblicazione IS NULL OR s.dataInizioPubblicazione <= CURDATE()) " &
                            "AND (s.dataFinePubblicazione IS NULL OR s.dataFinePubblicazione >= CURDATE()) " &
                            "ORDER BY CASE WHEN NULLIF(p.orderPosition,'') IS NULL THEN 999 ELSE CAST(p.orderPosition AS UNSIGNED) END, p.id DESC " &
                            "LIMIT 12"
        Dim dt As DataTable = SafeTableQuery(sql, SideBannersFallback(), "GetHeroSideBannerSource")
        dt = FilterRowsByResolvedImage(dt, "Image", AddressOf ResolveHeroSlideImagePath)
        Return PrepareSideBannerRows(dt)
    End Function

    Private Function PrepareHeroRows(ByVal source As DataTable, ByVal defaultEyebrow As String, ByVal defaultDescription As String) As DataTable
        Dim result As DataTable = HeroSlidesFallback().Clone()
        If source Is Nothing Then
            Return result
        End If

        For Each row As DataRow In source.Rows
            Dim newRow As DataRow = result.NewRow()
            newRow("Caption") = CleanMarketingText(If(row.Table.Columns.Contains("Caption"), row("Caption"), String.Empty), "Promozioni KeepStore")
            newRow("Image") = Convert.ToString(row("Image")).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Eyebrow") = BuildHeroEyebrow(Convert.ToString(newRow("Caption")), defaultEyebrow)
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), defaultDescription)
            newRow("ProductId") = 0
            result.Rows.Add(newRow)
        Next

        Return result
    End Function

    Private Function PrepareSideBannerRows(ByVal source As DataTable) As DataTable
        Dim result As DataTable = SideBannersFallback().Clone()
        If source Is Nothing Then
            Return SideBannersFallback()
        End If

        For Each row As DataRow In source.Rows
            Dim newRow As DataRow = result.NewRow()
            Dim title As String = CleanMarketingText(If(row.Table.Columns.Contains("Title"), row("Title"), String.Empty), "Selezione KeepStore")
            newRow("Title") = title
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), String.Empty)
            newRow("Image") = Convert.ToString(row("Image")).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Badge") = BuildSideBannerBadge(title, Convert.ToString(newRow("Description")))
            result.Rows.Add(newRow)
        Next

        Return result
    End Function

    Private Function ConvertSideRowsToHeroRows(ByVal source As DataTable) As DataTable
        Dim result As DataTable = HeroSlidesFallback().Clone()
        If source Is Nothing Then
            Return result
        End If

        For Each row As DataRow In source.Rows
            Dim newRow As DataRow = result.NewRow()
            newRow("Caption") = CleanMarketingText(If(row.Table.Columns.Contains("Title"), row("Title"), String.Empty), "Selezione KeepStore")
            newRow("Image") = Convert.ToString(If(row.Table.Columns.Contains("Image"), row("Image"), String.Empty)).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Eyebrow") = BuildHeroEyebrow(Convert.ToString(newRow("Caption")), "Selezione KeepStore")
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), "Prodotti e promozioni reali KeepStore.")
            newRow("ProductId") = 0
            result.Rows.Add(newRow)
        Next

        Return result
    End Function

    Private Function ConvertHeroRowsToSideRows(ByVal source As DataTable) As DataTable
        Dim result As DataTable = SideBannersFallback()
        If source Is Nothing Then
            Return result
        End If

        For Each row As DataRow In source.Rows
            Dim newRow As DataRow = result.NewRow()
            Dim title As String = CleanMarketingText(If(row.Table.Columns.Contains("Caption"), row("Caption"), String.Empty), "Selezione KeepStore")
            newRow("Title") = title
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), String.Empty)
            newRow("Image") = Convert.ToString(If(row.Table.Columns.Contains("Image"), row("Image"), String.Empty)).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Badge") = BuildSideBannerBadge(title, Convert.ToString(newRow("Description")))
            result.Rows.Add(newRow)
        Next

        Return result
    End Function

    Private Function MergeSideBannerRows(ByVal primary As DataTable, ByVal secondary As DataTable, ByVal limit As Integer) As DataTable
        Dim result As DataTable = SideBannersFallback()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        For Each source As DataTable In New DataTable() {primary, secondary}
            If source Is Nothing Then
                Continue For
            End If

            For Each row As DataRow In source.Rows
                Dim imageKey As String = Convert.ToString(If(row.Table.Columns.Contains("Image"), row("Image"), String.Empty)).Trim()
                If String.IsNullOrWhiteSpace(imageKey) OrElse seen.Contains(imageKey) Then
                    Continue For
                End If

                seen.Add(imageKey)
                result.ImportRow(row)
                If result.Rows.Count >= limit Then
                    Return result
                End If
            Next
        Next

        Return result
    End Function

    Private Function CleanMarketingText(ByVal value As Object, ByVal fallback As String) As String
        Dim text As String = HttpUtility.HtmlDecode(Convert.ToString(value)).Trim()
        text = System.Text.RegularExpressions.Regex.Replace(text, "\s+", " ").Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return fallback
        End If

        If text.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           text.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return fallback
        End If

        Return text
    End Function

    Private Function BuildHeroEyebrow(ByVal title As String, ByVal fallback As String) As String
        Dim source As String = Convert.ToString(title).Trim().ToLowerInvariant()
        If source.Contains("ricondizionat") Then Return "Ricondizionati"
        If source.Contains("monitor") Then Return "Monitor"
        If source.Contains("ssd") OrElse source.Contains("nvme") Then Return "Archiviazione"
        If source.Contains("stamp") OrElse source.Contains("etichette") Then Return "Stampa"
        If source.Contains("webcam") OrElse source.Contains("conferenza") Then Return "Videoconferenza"
        Return If(String.IsNullOrWhiteSpace(fallback), "Promo KeepStore", fallback)
    End Function

    Private Function BuildSideBannerBadge(ByVal title As String, ByVal description As String) As String
        Dim source As String = (Convert.ToString(title) & " " & Convert.ToString(description)).Trim().ToLowerInvariant()
        If source.Contains("ricondizionat") Then Return "Ricondizionati"
        If source.Contains("monitor") Then Return "Monitor"
        If source.Contains("ssd") OrElse source.Contains("nvme") Then Return "SSD"
        If source.Contains("webcam") OrElse source.Contains("conferenza") Then Return "Webcam"
        If source.Contains("alimentatore") Then Return "Componenti"
        Return "Promo"
    End Function

    Private Function NormalizeProjectLink(ByVal rawLink As String, ByVal fallback As String) As String
        Dim defaultLink As String = Convert.ToString(fallback).Trim()
        If String.IsNullOrWhiteSpace(defaultLink) Then
            defaultLink = "articoli.aspx"
        End If

        Dim link As String = HttpUtility.HtmlDecode(Convert.ToString(rawLink)).Trim()
        If String.IsNullOrWhiteSpace(link) Then
            Return defaultLink
        End If

        link = link.Replace("\", "/")
        If link.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then
            Return defaultLink
        End If

        Dim hosts As String() = {
            "https://www.taikun.it",
            "http://www.taikun.it",
            "https://taikun.it",
            "http://taikun.it",
            "https://www.webaffare.it",
            "http://www.webaffare.it",
            "https://webaffare.it",
            "http://webaffare.it"
        }

        For Each host As String In hosts
            If link.StartsWith(host, StringComparison.OrdinalIgnoreCase) Then
                Try
                    Dim uri As New Uri(link)
                    Dim pathAndQuery As String = uri.PathAndQuery
                    If String.IsNullOrWhiteSpace(pathAndQuery) Then
                        Return defaultLink
                    End If
                    Return pathAndQuery
                Catch
                    Return defaultLink
                End Try
            End If
        Next

        If link.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl(link)
        End If

        Return link
    End Function

    Private Function SideBannersFallback() As DataTable
        Dim dt As New DataTable()
        dt.Columns.Add("Title", GetType(String))
        dt.Columns.Add("Description", GetType(String))
        dt.Columns.Add("Image", GetType(String))
        dt.Columns.Add("LinkUrl", GetType(String))
        dt.Columns.Add("Badge", GetType(String))
        dt.Rows.Add("Monitor e periferiche", "Soluzioni tech selezionate per lavoro e casa", "/Public/assets/images/banner/Banner_samsung_odyssey_g40B_1200x560.png", "articoli.aspx?q=monitor%20gaming", "Catalogo")
        dt.Rows.Add("PC ricondizionati", "Computer controllati e pronti per l'uso", "/Public/assets/images/banner/Banner_PC_ricondizionati_1200x560.png", "articoli.aspx?q=pc%20ricondizionato", "KeepStore")
        Return dt
    End Function

    Private Function FilterRowsByResolvedImage(ByVal source As DataTable, ByVal fieldName As String, ByVal resolver As Func(Of Object, String)) As DataTable
        If source Is Nothing OrElse source.Columns.Count = 0 OrElse String.IsNullOrWhiteSpace(fieldName) OrElse Not source.Columns.Contains(fieldName) OrElse resolver Is Nothing Then
            Return source
        End If

        Dim filtered As DataTable = source.Clone()
        For Each row As DataRow In source.Rows
            Dim resolved As String = resolver(row(fieldName))
            If String.IsNullOrWhiteSpace(resolved) Then
                Continue For
            End If

            Dim clone As DataRow = filtered.NewRow()
            clone.ItemArray = CType(row.ItemArray.Clone(), Object())
            clone(fieldName) = resolved
            filtered.Rows.Add(clone)
        Next

        Return filtered
    End Function

    Private Function GetOfferPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(OfferWhereClause(), "CASE WHEN v.OfferteDataFine IS NULL THEN 1 ELSE 0 END ASC, COALESCE(v.OfferteDataFine,'9999-12-31') ASC, COALESCE(sy.VendutiAnno,0) DESC, COALESCE(v.Visite,0) DESC, v.id DESC", limit)
    End Function

    Private Function GetDealOfferPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(OfferWhereClause(), "CASE WHEN v.OfferteDataFine IS NULL THEN 1 ELSE 0 END ASC, COALESCE(v.OfferteDataFine,'9999-12-31') ASC, COALESCE(sy.VendutiAnno,0) DESC, COALESCE(v.Visite,0) DESC, v.id DESC", limit)
    End Function

    Private Function GetFeaturedPool(ByVal limit As Integer) As DataTable
        Return QueryProducts("COALESCE(v.Vetrina,0)=1 AND COALESCE(NULLIF(v.Img1,''),'')<>'' AND " & StockWhereClause() & ">=1",
                             "COALESCE(v.DataCreazione,CURDATE()) DESC, COALESCE(v.Visite,0) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetMostViewedPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(v.Visite,0)>0",
                             "COALESCE(v.Visite,0) DESC, COALESCE(v.DataCreazione,CURDATE()) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetTopRatedPool(ByVal limit As Integer) As DataTable
        Return GetMostViewedPool(limit)
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

    Private Function GetCurrentYearSellingPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(sy.VendutiAnno,0)>0",
                             "COALESCE(sy.VendutiAnno,0) DESC, COALESCE(s.QtaVenduta,0) DESC, COALESCE(v.Visite,0) DESC, v.id DESC",
                             limit)
    End Function

    Private Function GetCatalogFallbackPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(StockWhereClause() & ">=1 AND COALESCE(NULLIF(v.Img1,''),'')<>''",
                             "COALESCE(v.DataCreazione,CURDATE()) DESC, COALESCE(v.Visite,0) DESC, v.id DESC",
                             limit)
    End Function

    Private Function QueryProducts(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As DataTable
        Dim dt As DataTable = TryLoadProducts(whereClause, orderClause, limit)
        If dt IsNot Nothing AndAlso dt.Rows.Count > 0 Then
            Return dt
        End If
        Return EmptyProductsTable()
    End Function

    Private Function GetRecentlyViewedProducts(ByVal limit As Integer,
                                               Optional ByVal excludedBusinessKeys As HashSet(Of String) = Nothing,
                                               Optional ByVal reserveExcludedKeys As Boolean = True,
                                               Optional ByVal excludedDisplayKeys As HashSet(Of String) = Nothing,
                                               Optional ByVal reserveExcludedDisplayKeys As Boolean = True) As DataTable
        Dim ids As List(Of Integer) = GetRecentlyViewedIds()
        If ids.Count = 0 Then
            Return EmptyProductsTable()
        End If

        Dim orderedIds As New List(Of Integer)()
        For Each id As Integer In ids
            If id > 0 AndAlso Not orderedIds.Contains(id) Then
                orderedIds.Add(id)
            End If
        Next

        If orderedIds.Count = 0 Then Return EmptyProductsTable()

        Dim idsCsv As String = String.Join(",", orderedIds.ToArray())
        Dim orderSql As New StringBuilder()
        orderSql.Append("CASE v.id ")
        For i As Integer = 0 To orderedIds.Count - 1
            orderSql.Append("WHEN ").Append(orderedIds(i).ToString(CultureInfo.InvariantCulture)).Append(" THEN ").Append(i.ToString(CultureInfo.InvariantCulture)).Append(" ")
        Next
        orderSql.Append("ELSE 9999 END")

        Dim dt As DataTable = TryLoadProducts("v.id IN (" & idsCsv & ") AND " & StockWhereClause() & ">=1", orderSql.ToString(), orderedIds.Count)
        If dt IsNot Nothing AndAlso dt.Rows.Count > 0 Then
            dt = DistinctRowsByProductId(dt)
            dt = DistinctRowsByBusinessKey(dt)
            dt = DistinctRowsByDisplayKey(dt)
            dt = ExcludeBusinessKeys(dt, excludedBusinessKeys, reserveExcludedKeys)
            dt = ExcludeDisplayKeys(dt, excludedDisplayKeys, reserveExcludedDisplayKeys)
            If dt.Rows.Count <= limit Then
                Return dt
            End If
            Return SliceTable(dt, 0, limit)
        End If

        Return EmptyProductsTable()
    End Function

    Private Function DistinctRowsByProductId(ByVal source As DataTable) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), EmptyProductsTable())
        If source Is Nothing OrElse source.Rows.Count = 0 Then
            Return result
        End If

        Dim seen As New HashSet(Of Integer)()
        For Each row As DataRow In source.Rows
            Dim id As Integer = SafeInt(row("id"))
            If id <= 0 OrElse seen.Contains(id) Then
                Continue For
            End If

            seen.Add(id)
            result.ImportRow(row)
        Next

        Return result
    End Function

    Private Function DistinctRowsByBusinessKey(ByVal source As DataTable) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), EmptyProductsTable())
        If source Is Nothing OrElse source.Rows.Count = 0 Then
            Return result
        End If

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each row As DataRow In source.Rows
            Dim businessKey As String = GetBusinessKey(row)
            If String.IsNullOrWhiteSpace(businessKey) OrElse seen.Contains(businessKey) Then
                Continue For
            End If

            seen.Add(businessKey)
            result.ImportRow(row)
        Next

        Return result
    End Function

    Private Function DistinctRowsByDisplayKey(ByVal source As DataTable) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), EmptyProductsTable())
        If source Is Nothing OrElse source.Rows.Count = 0 Then
            Return result
        End If

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each row As DataRow In source.Rows
            Dim displayKey As String = GetDisplayKey(row)
            If String.IsNullOrWhiteSpace(displayKey) OrElse seen.Contains(displayKey) Then
                Continue For
            End If

            seen.Add(displayKey)
            result.ImportRow(row)
        Next

        Return result
    End Function

    Private Function ExcludeBusinessKeys(ByVal source As DataTable,
                                         ByVal excludedBusinessKeys As HashSet(Of String),
                                         Optional ByVal reserveExcludedKeys As Boolean = True) As DataTable
        If source Is Nothing OrElse source.Rows.Count = 0 OrElse excludedBusinessKeys Is Nothing Then
            Return source
        End If

        Dim filtered As DataTable = source.Clone()
        For Each row As DataRow In source.Rows
            Dim businessKey As String = GetBusinessKey(row)
            If String.IsNullOrWhiteSpace(businessKey) OrElse excludedBusinessKeys.Contains(businessKey) Then
                Continue For
            End If

            filtered.ImportRow(row)
            If reserveExcludedKeys Then
                excludedBusinessKeys.Add(businessKey)
            End If
        Next

        Return filtered
    End Function

    Private Function ExcludeDisplayKeys(ByVal source As DataTable,
                                        ByVal excludedDisplayKeys As HashSet(Of String),
                                        Optional ByVal reserveExcludedKeys As Boolean = True) As DataTable
        If source Is Nothing OrElse source.Rows.Count = 0 OrElse excludedDisplayKeys Is Nothing Then
            Return source
        End If

        Dim filtered As DataTable = source.Clone()
        For Each row As DataRow In source.Rows
            Dim displayKey As String = GetDisplayKey(row)
            If String.IsNullOrWhiteSpace(displayKey) OrElse excludedDisplayKeys.Contains(displayKey) Then
                Continue For
            End If

            filtered.ImportRow(row)
            If reserveExcludedKeys Then
                excludedDisplayKeys.Add(displayKey)
            End If
        Next

        Return filtered
    End Function

    Private Function TryLoadProducts(ByVal whereClause As String, ByVal orderClause As String, ByVal limit As Integer) As DataTable
        Dim prezzoIvatoSql As String = BuildPrezzoIvatoSql()
        Dim prezzoPromoIvatoSql As String = BuildPrezzoPromoIvatoSql()

        Dim sql As New StringBuilder()
        sql.Append("SELECT ")
        sql.Append("v.id, COALESCE(v.TCid,-1) AS TCid, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, IFNULL(v.DescrizioneLunga,'') AS DescrizioneLunga, ")
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
        sql.Append("COALESCE(v.Prezzo,0) AS Prezzo, ")
        sql.Append(prezzoIvatoSql).Append(" AS PrezzoIvato, ")
        sql.Append("COALESCE(v.PrezzoPromo,0) AS PrezzoPromo, ")
        sql.Append(prezzoPromoIvatoSql).Append(" AS PrezzoPromoIvato, ")
        sql.Append("COALESCE(v.InOfferta,0) AS InOfferta, ")
        sql.Append("v.OfferteDataInizio, v.OfferteDataFine, ")
        sql.Append("COALESCE(v.OfferteDaListino,0) AS OfferteDaListino, COALESCE(v.OfferteAListino,0) AS OfferteAListino, ")
        sql.Append("COALESCE(v.OfferteQntMinima,0) AS OfferteQntMinima, COALESCE(v.OfferteMultipli,0) AS OfferteMultipli, ")
        sql.Append("COALESCE(v.OffertePrezzo,0) AS OffertePrezzo, COALESCE(v.OfferteSconto,0) AS OfferteSconto, ")
        sql.Append("COALESCE(v.IdIvaRC,-1) AS IdIvaRC, COALESCE(v.ValoreIvaRC,-1) AS ValoreIvaRC, ")
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
        sql.Append("AND (COALESCE(v.Prezzo,0)>0 OR COALESCE(v.PrezzoIvato,0)>0 OR COALESCE(v.PrezzoPromo,0)>0 OR COALESCE(v.PrezzoPromoIvato,0)>0) ")
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

    Private Function GetReverseChargeEnabled() As Integer
        Dim flag As Integer = 0
        If Session("AbilitatoIvaReverseCharge") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("AbilitatoIvaReverseCharge")), flag)
        End If
        If flag <> 1 Then
            flag = 0
        End If
        Return flag
    End Function

    Private Function GetCurrentUserIva() As Integer
        Dim ivaUtente As Integer = 0
        If Session("Iva_Utente") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("Iva_Utente")), ivaUtente)
        End If
        If ivaUtente < 0 Then
            ivaUtente = 0
        End If
        Return ivaUtente
    End Function

    Private Function BuildPrezzoIvatoSql() As String
        Dim abilRC As Integer = GetReverseChargeEnabled()
        Dim ivaUtente As Integer = GetCurrentUserIva()

        Return "IF((" & abilRC.ToString(CultureInfo.InvariantCulture) & "=1) AND (COALESCE(v.ValoreIvaRC,-1)>-1)," &
               " (COALESCE(v.Prezzo,0)*((COALESCE(v.ValoreIvaRC,0)/100)+1))," &
               " IF(" & ivaUtente.ToString(CultureInfo.InvariantCulture) & ">0,(COALESCE(v.Prezzo,0)*((" & ivaUtente.ToString(CultureInfo.InvariantCulture) & "/100)+1)),COALESCE(v.PrezzoIvato,0))" &
               " )"
    End Function

    Private Function BuildPrezzoPromoIvatoSql() As String
        Dim abilRC As Integer = GetReverseChargeEnabled()
        Dim ivaUtente As Integer = GetCurrentUserIva()

        Return "IF(COALESCE(v.PrezzoPromoIvato,0)>0,COALESCE(v.PrezzoPromoIvato,0)," &
               " IF((" & abilRC.ToString(CultureInfo.InvariantCulture) & "=1) AND (COALESCE(v.ValoreIvaRC,-1)>-1)," &
               " (COALESCE(v.PrezzoPromo,0)*((COALESCE(v.ValoreIvaRC,0)/100)+1))," &
               " IF(" & ivaUtente.ToString(CultureInfo.InvariantCulture) & ">0,(COALESCE(v.PrezzoPromo,0)*((" & ivaUtente.ToString(CultureInfo.InvariantCulture) & "/100)+1)),COALESCE(v.PrezzoPromo,0))" &
               " ))"
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
        Dim prezzoBaseSql As String = BuildPrezzoIvatoSql()
        Dim prezzoPromoSql As String = BuildPrezzoPromoIvatoSql()

        Return "COALESCE(v.InOfferta,0)=1 AND " &
               "(v.OfferteDaListino IS NULL OR @listino >= v.OfferteDaListino) AND " &
               "(v.OfferteAListino IS NULL OR @listino <= v.OfferteAListino) AND " &
               "((" & prezzoPromoSql & ">0 AND " & prezzoPromoSql & " < " & prezzoBaseSql & ") " &
               "OR (" & prezzoPromoSql & "=0 AND COALESCE(v.PrezzoPromo,0)>0 AND COALESCE(v.PrezzoPromo,0) < COALESCE(v.Prezzo,0))) " &
               "AND " & StockWhereClause() & ">=1"
    End Function

    Private Function GetRecentlyViewedIds() As List(Of Integer)
        Dim result As New List(Of Integer)()

        MergeRecentIds(result, Convert.ToString(Session("ks_recent_ids")))
        MergeRecentIds(result, Convert.ToString(Session("ks_recent_session")))

        Dim cookie As HttpCookie = Request.Cookies("ks_recent")
        If cookie IsNot Nothing Then
            MergeRecentIds(result, HttpUtility.UrlDecode(cookie.Value))
        End If

        Dim sessionCookie As HttpCookie = Request.Cookies("ks_recent_session")
        If sessionCookie IsNot Nothing Then
            MergeRecentIds(result, HttpUtility.UrlDecode(sessionCookie.Value))
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

    Private Function GetBusinessKey(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim ean As String = NormalizeBusinessIdentifier(If(row.Table.Columns.Contains("Ean"), row("Ean"), Nothing))
        If Not String.IsNullOrWhiteSpace(ean) Then
            Return "EAN:" & ean
        End If

        Dim codice As String = NormalizeBusinessIdentifier(If(row.Table.Columns.Contains("Codice"), row("Codice"), Nothing))
        If Not String.IsNullOrWhiteSpace(codice) Then
            Return "COD:" & codice
        End If

        Dim marca As String = NormalizeBusinessText(If(row.Table.Columns.Contains("MarcheDescrizione"), row("MarcheDescrizione"), Nothing))
        Dim descrizione As String = NormalizeBusinessText(If(row.Table.Columns.Contains("Descrizione1"), row("Descrizione1"), Nothing))
        If Not String.IsNullOrWhiteSpace(marca & descrizione) Then
            Return "TXT:" & marca & "|" & descrizione
        End If

        Return "ID:" & SafeInt(row("id")).ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function GetDisplayKey(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim categoryCaption As String = NormalizeDisplayText(GetDisplayCategoryCaption(row))
        Dim brand As String = NormalizeDisplayText(If(row.Table.Columns.Contains("MarcheDescrizione"), row("MarcheDescrizione"), Nothing))
        Dim stem As String = BuildDisplayStem(row, brand, categoryCaption)

        If String.IsNullOrWhiteSpace(stem) Then
            stem = NormalizeDisplayText(If(row.Table.Columns.Contains("Descrizione1"), row("Descrizione1"), Nothing))
        End If
        If String.IsNullOrWhiteSpace(stem) Then
            stem = GetBusinessKey(row)
        End If

        Return ("DSP:" & categoryCaption & "|" & brand & "|" & stem).Trim("|"c)
    End Function

    Private Function GetDisplayCategoryCaption(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim candidates As String() = {
            Convert.ToString(If(row.Table.Columns.Contains("CategorieDescrizione"), row("CategorieDescrizione"), String.Empty)),
            Convert.ToString(If(row.Table.Columns.Contains("TipologieDescrizione"), row("TipologieDescrizione"), String.Empty)),
            Convert.ToString(If(row.Table.Columns.Contains("SettoriDescrizione"), row("SettoriDescrizione"), String.Empty)),
            Convert.ToString(If(row.Table.Columns.Contains("GruppiDescrizione"), row("GruppiDescrizione"), String.Empty))
        }

        For Each candidate As String In candidates
            If Not String.IsNullOrWhiteSpace(candidate) Then
                Return candidate
            End If
        Next

        Return String.Empty
    End Function

    Private Function BuildDisplayStem(ByVal row As DataRow, ByVal normalizedBrand As String, ByVal normalizedCategory As String) As String
        Dim description As String = NormalizeDisplayText(If(row.Table.Columns.Contains("Descrizione1"), row("Descrizione1"), Nothing))
        If String.IsNullOrWhiteSpace(description) Then
            Return String.Empty
        End If

        Dim brandTokens As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each token As String In normalizedBrand.Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
            brandTokens.Add(token)
        Next

        Dim categoryTokens As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each token As String In normalizedCategory.Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
            categoryTokens.Add(token)
        Next

        Dim significant As New List(Of String)()
        For Each token As String In description.Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
            If token.Length <= 1 Then
                Continue For
            End If
            If brandTokens.Contains(token) OrElse categoryTokens.Contains(token) Then
                Continue For
            End If
            If IsDisplayVariantToken(token) Then
                Continue For
            End If
            significant.Add(token)
            If significant.Count >= 3 Then
                Exit For
            End If
        Next

        If significant.Count = 0 Then
            For Each token As String In description.Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
                If token.Length <= 1 Then
                    Continue For
                End If
                significant.Add(token)
                If significant.Count >= 3 Then
                    Exit For
                End If
            Next
        End If

        Return String.Join(" ", significant.ToArray())
    End Function

    Private Function IsDisplayVariantToken(ByVal token As String) As Boolean
        If String.IsNullOrWhiteSpace(token) Then
            Return True
        End If

        Dim normalized As String = token.Trim().ToUpperInvariant()
        Dim blocked As String() = {
            "BLACK", "WHITE", "BLUE", "RED", "GREEN", "PINK", "ROSE", "GOLD", "SILVER", "GRAY", "GREY",
            "CLEAR", "CASE", "COVER", "CUSTODIA", "SILICONE", "TPU", "TRASPARENTE", "SOFT", "SLIM", "ULTRA",
            "NERO", "BIANCO", "BLU", "ROSSO", "VERDE", "ROSA", "ORO", "ARGENTO", "GRIGIO",
            "PER", "CON", "DEL", "DELLA", "DELLO", "THE", "FOR", "WITH",
            "2MM", "3MM", "TB31", "M11"
        }

        For Each candidate As String In blocked
            If String.Equals(candidate, normalized, StringComparison.OrdinalIgnoreCase) Then
                Return True
            End If
        Next

        If System.Text.RegularExpressions.Regex.IsMatch(normalized, "^\d+(GB|TB|MM)$") Then
            Return True
        End If

        If System.Text.RegularExpressions.Regex.IsMatch(normalized, "^(TB|M)\d+[A-Z0-9]*$") Then
            Return True
        End If

        Return False
    End Function

    Private Function NormalizeBusinessIdentifier(ByVal value As Object) As String
        Dim text As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return String.Empty
        End If

        text = text.ToUpperInvariant()
        text = text.Replace(" ", String.Empty)
        Return text
    End Function

    Private Function NormalizeBusinessText(ByVal value As Object) As String
        Dim text As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return String.Empty
        End If

        text = text.ToUpperInvariant()
        text = System.Text.RegularExpressions.Regex.Replace(text, "\s+", " ")
        Return text
    End Function

    Private Function NormalizeDisplayText(ByVal value As Object) As String
        Dim text As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return String.Empty
        End If

        text = text.ToUpperInvariant()
        text = System.Text.RegularExpressions.Regex.Replace(text, "[^A-Z0-9]+", " ")
        text = System.Text.RegularExpressions.Regex.Replace(text, "\s+", " ").Trim()
        Return text
    End Function

    Private Function TakeDistinctRows(ByVal count As Integer, ByVal usedBusinessKeys As HashSet(Of String), ParamArray ByVal sources() As DataTable) As DataTable
        Return CollectDistinctRows(count, usedBusinessKeys, Nothing, True, False, False, sources)
    End Function

    Private Function PreviewDistinctRows(ByVal count As Integer, ByVal usedBusinessKeys As HashSet(Of String), ParamArray ByVal sources() As DataTable) As DataTable
        Return CollectDistinctRows(count, usedBusinessKeys, Nothing, False, False, False, sources)
    End Function

    Private Function TakeDiverseRows(ByVal count As Integer,
                                     ByVal usedBusinessKeys As HashSet(Of String),
                                     ByVal usedDisplayKeys As HashSet(Of String),
                                     ParamArray ByVal sources() As DataTable) As DataTable
        Return CollectDistinctRows(count, usedBusinessKeys, usedDisplayKeys, True, True, True, sources)
    End Function

    Private Function PreviewDiverseRows(ByVal count As Integer,
                                        ByVal usedBusinessKeys As HashSet(Of String),
                                        ByVal usedDisplayKeys As HashSet(Of String),
                                        ParamArray ByVal sources() As DataTable) As DataTable
        Return CollectDistinctRows(count, usedBusinessKeys, usedDisplayKeys, False, False, True, sources)
    End Function

    Private Function CollectDistinctRows(ByVal count As Integer,
                                         ByVal usedBusinessKeys As HashSet(Of String),
                                         ByVal usedDisplayKeys As HashSet(Of String),
                                         ByVal reserveBusinessKeys As Boolean,
                                         ByVal reserveDisplayKeys As Boolean,
                                         ByVal enforceDisplayDiversity As Boolean,
                                         ParamArray ByVal sources() As DataTable) As DataTable
        Dim result As DataTable = CloneFirstTable(sources)
        Dim seenBusinessKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim seenDisplayKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        AddDistinctRows(result, count, usedBusinessKeys, usedDisplayKeys, seenBusinessKeys, seenDisplayKeys, reserveBusinessKeys, reserveDisplayKeys, enforceDisplayDiversity, sources)

        Return result
    End Function

    Private Sub AddDistinctRows(ByVal target As DataTable,
                                ByVal count As Integer,
                                ByVal usedBusinessKeys As HashSet(Of String),
                                ByVal usedDisplayKeys As HashSet(Of String),
                                ByVal seenBusinessKeys As HashSet(Of String),
                                ByVal seenDisplayKeys As HashSet(Of String),
                                ByVal reserveBusinessKeys As Boolean,
                                ByVal reserveDisplayKeys As Boolean,
                                ByVal enforceDisplayDiversity As Boolean,
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
                Dim businessKey As String = GetBusinessKey(row)
                Dim displayKey As String = If(enforceDisplayDiversity, GetDisplayKey(row), String.Empty)
                If id <= 0 OrElse String.IsNullOrWhiteSpace(businessKey) Then
                    Continue For
                End If
                If seenBusinessKeys.Contains(businessKey) Then
                    Continue For
                End If
                If usedBusinessKeys IsNot Nothing AndAlso usedBusinessKeys.Contains(businessKey) Then
                    Continue For
                End If
                If enforceDisplayDiversity Then
                    If String.IsNullOrWhiteSpace(displayKey) Then
                        Continue For
                    End If
                    If seenDisplayKeys.Contains(displayKey) Then
                        Continue For
                    End If
                    If usedDisplayKeys IsNot Nothing AndAlso usedDisplayKeys.Contains(displayKey) Then
                        Continue For
                    End If
                End If

                target.ImportRow(row)
                seenBusinessKeys.Add(businessKey)
                If enforceDisplayDiversity Then
                    seenDisplayKeys.Add(displayKey)
                End If
                If reserveBusinessKeys AndAlso usedBusinessKeys IsNot Nothing Then
                    usedBusinessKeys.Add(businessKey)
                End If
                If enforceDisplayDiversity AndAlso reserveDisplayKeys AndAlso usedDisplayKeys IsNot Nothing Then
                    usedDisplayKeys.Add(displayKey)
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
        dt.Columns.Add("Prezzo", GetType(Decimal))
        dt.Columns.Add("PrezzoIvato", GetType(Decimal))
        dt.Columns.Add("PrezzoPromo", GetType(Decimal))
        dt.Columns.Add("PrezzoPromoIvato", GetType(Decimal))
        dt.Columns.Add("InOfferta", GetType(Integer))
        dt.Columns.Add("OfferteDataInizio", GetType(Date))
        dt.Columns.Add("OfferteDataFine", GetType(Date))
        dt.Columns.Add("OfferteDaListino", GetType(Integer))
        dt.Columns.Add("OfferteAListino", GetType(Integer))
        dt.Columns.Add("OfferteQntMinima", GetType(Integer))
        dt.Columns.Add("OfferteMultipli", GetType(Integer))
        dt.Columns.Add("OffertePrezzo", GetType(Decimal))
        dt.Columns.Add("OfferteSconto", GetType(Decimal))
        dt.Columns.Add("IdIvaRC", GetType(Integer))
        dt.Columns.Add("ValoreIvaRC", GetType(Decimal))
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

    Private Sub CommitBusinessKeys(ByVal source As DataTable, ByVal usedBusinessKeys As HashSet(Of String))
        If source Is Nothing OrElse usedBusinessKeys Is Nothing Then
            Return
        End If

        For Each row As DataRow In source.Rows
            Dim businessKey As String = GetBusinessKey(row)
            If String.IsNullOrWhiteSpace(businessKey) Then
                Continue For
            End If

            usedBusinessKeys.Add(businessKey)
        Next
    End Sub

    Private Sub CommitDisplayKeys(ByVal source As DataTable, ByVal usedDisplayKeys As HashSet(Of String))
        If source Is Nothing OrElse usedDisplayKeys Is Nothing Then
            Return
        End If

        For Each row As DataRow In source.Rows
            Dim displayKey As String = GetDisplayKey(row)
            If String.IsNullOrWhiteSpace(displayKey) Then
                Continue For
            End If

            usedDisplayKeys.Add(displayKey)
        Next
    End Sub

    Private Sub BindLowerBlock(ByVal wrapper As Control,
                               ByVal repeater As Repeater,
                               ByVal source As DataTable,
                               ByVal minItems As Integer,
                               ByVal usedBusinessKeys As HashSet(Of String),
                               ByVal usedDisplayKeys As HashSet(Of String))
        Dim visible As Boolean = (source IsNot Nothing AndAlso source.Rows.Count >= minItems)

        If wrapper IsNot Nothing Then
            wrapper.Visible = visible
        End If

        If repeater Is Nothing Then
            Return
        End If

        If visible Then
            CommitBusinessKeys(source, usedBusinessKeys)
            CommitDisplayKeys(source, usedDisplayKeys)
            repeater.DataSource = BuildSlidesTable(source, 5)
        Else
            repeater.DataSource = Nothing
        End If

        repeater.DataBind()
    End Sub

    Private Function GetBrands(ByVal limit As Integer) As DataTable
        Dim sql As String = "SELECT id, Descrizione, img, link FROM marche WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Ordinamento,0), Descrizione LIMIT " & Math.Max(1, limit).ToString(CultureInfo.InvariantCulture)
        Return SafeTableQuery(sql, New DataTable(), "GetBrands")
    End Function

    Private Function FilterBrandRows(ByVal source As DataTable, ByVal limit As Integer) As DataTable
        If source Is Nothing Then
            Return New DataTable()
        End If

        Dim filtered As DataTable = source.Clone()
        For Each row As DataRow In source.Rows
            If Not row.Table.Columns.Contains("img") Then
                Continue For
            End If

            If Not IsApprovedBrandAsset(row("img")) Then
                Continue For
            End If

            Dim imageUrl As String = ResolveBrandImage(row("img"))
            If String.IsNullOrWhiteSpace(imageUrl) Then
                Continue For
            End If

            filtered.ImportRow(row)
            If filtered.Rows.Count >= limit Then
                Exit For
            End If
        Next

        Return filtered
    End Function

    Private Function IsApprovedBrandAsset(ByVal value As Object) As Boolean
        Dim fileName As String = Path.GetFileName(Convert.ToString(value).Trim())
        If String.IsNullOrWhiteSpace(fileName) Then
            Return False
        End If

        Dim extension As String = Path.GetExtension(fileName).ToLowerInvariant()
        Select Case extension
            Case ".png", ".jpg", ".jpeg", ".webp", ".svg"
            Case Else
                Return False
        End Select

        Dim normalized As String = fileName.ToLowerInvariant()
        Dim blockedTokens As String() = {
            "banner", "slide", "slideshow", "promo", "collection",
            "camera", "tivi", "tablet", "phone", "device", "desert"
        }

        For Each token As String In blockedTokens
            If normalized.Contains(token) Then
                Return False
            End If
        Next

        Return True
    End Function

    Private Function DistinctRowsByColumn(ByVal source As DataTable, ByVal columnName As String) As DataTable
        If source Is Nothing Then
            Return New DataTable()
        End If

        Dim result As DataTable = source.Clone()
        If String.IsNullOrWhiteSpace(columnName) OrElse Not source.Columns.Contains(columnName) Then
            For Each row As DataRow In source.Rows
                result.ImportRow(row)
            Next
            Return result
        End If

        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each row As DataRow In source.Rows
            Dim key As String = Convert.ToString(row(columnName)).Trim()
            If String.IsNullOrWhiteSpace(key) Then
                Continue For
            End If
            If seen.Contains(key) Then
                Continue For
            End If
            seen.Add(key)
            result.ImportRow(row)
        Next

        Return result
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

    Protected Function RenderHomeSectorMedia(ByVal imgUrl As Object, ByVal description As Object) As String
        Dim resolved As String = Convert.ToString(imgUrl).Trim()
        Dim alt As String = SafeText(description)
        If Not String.IsNullOrWhiteSpace(resolved) Then
            Return "<img class='lazyload' src='" & SafeText(resolved) & "' data-src='" & SafeText(resolved) & "' alt='" & alt & "' loading='lazy' />"
        End If
        Return "<span class='ks-home-category-initial' aria-hidden='true'>" & HomeSectorInitial(description) & "</span>"
    End Function

    Private Function HomeSectorInitial(ByVal value As Object) As String
        Dim text As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return "K"
        End If
        Return SafeText(text.Substring(0, 1).ToUpperInvariant())
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
        Return "cart_add.aspx?id=" & HttpUtility.UrlEncode(Convert.ToString(id)) & "&TCid=-1&qty=1"
    End Function

    Protected Function CartAddUrl(ByVal row As DataRow) As String
        If row Is Nothing Then Return CartAddUrl(0)
        Dim tcid As String = "-1"
        If row.Table.Columns.Contains("TCid") Then
            tcid = Convert.ToString(row("TCid"))
            If String.IsNullOrWhiteSpace(tcid) Then tcid = "-1"
        End If
        Dim tcidInt As Integer = -1
        Integer.TryParse(tcid, tcidInt)
        If tcidInt <= 0 Then tcid = "-1"
        Return "cart_add.aspx?id=" & HttpUtility.UrlEncode(Convert.ToString(row("id"))) &
               "&TCid=" & HttpUtility.UrlEncode(tcid) &
               "&qty=1"
    End Function

    Protected Function WishlistAddUrl(ByVal id As Object) As String
        Return "wishlist_add.aspx?id=" & HttpUtility.UrlEncode(Convert.ToString(id))
    End Function

    Protected Function ResolveLink(ByVal value As Object, ByVal fallback As String) As String
        Dim link As String = Convert.ToString(value).Trim()
        Return NormalizeProjectLink(link, fallback)
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
        Return ResolveProjectImage(value, fallback, "/Public/assets/images/slideshows/", "/Public/assets/images/banner/")
    End Function

    Private Function ResolveHeroSlideImagePath(ByVal value As Object) As String
        Return ResolveHeroSlideImage(value, String.Empty)
    End Function

    Protected Function ResolveAdvertisingImage(ByVal value As Object, ByVal fallback As String) As String
        Return ResolveProjectImage(value, fallback, "/Public/assets/images/banner/")
    End Function

    Private Function ResolveAdvertisingImagePath(ByVal value As Object) As String
        Return ResolveAdvertisingImage(value, String.Empty)
    End Function

    Private Function ResolveProjectImage(ByVal value As Object, ByVal fallback As String, ParamArray ByVal candidateFolders() As String) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return fallback

        fileName = fileName.Replace("\", "/")
        If fileName.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            Return fileName
        End If
        If fileName.StartsWith("/") Then
            If VirtualPathExists(fileName) Then
                Return fileName
            End If
            Return If(VirtualPathExists(fallback), fallback, String.Empty)
        End If

        fileName = Path.GetFileName(fileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return If(VirtualPathExists(fallback), fallback, String.Empty)
        End If

        If candidateFolders IsNot Nothing Then
            For Each folder As String In candidateFolders
                If String.IsNullOrWhiteSpace(folder) Then
                    Continue For
                End If

                Dim virtualPath As String = folder.TrimEnd("/"c) & "/" & fileName
                If VirtualPathExists(virtualPath) Then
                    Return virtualPath
                End If
            Next
        End If

        Return If(VirtualPathExists(fallback), fallback, String.Empty)
    End Function

    Private Function VirtualPathExists(ByVal virtualPath As String) As Boolean
        If String.IsNullOrWhiteSpace(virtualPath) Then
            Return False
        End If

        Try
            Dim candidate As String = virtualPath
            If candidate.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
               candidate.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
               candidate.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then
                Return True
            End If

            If candidate.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
                candidate = candidate.Substring(1)
            End If
            If Not candidate.StartsWith("/") Then
                candidate = "/" & candidate.TrimStart("/"c)
            End If

            Dim physicalPath As String = HostingEnvironment.MapPath("~" & candidate)
            Return Not String.IsNullOrWhiteSpace(physicalPath) AndAlso File.Exists(physicalPath)
        Catch
            Return False
        End Try
    End Function

    Private Function BuildRuntimeAssetUrl(ByVal virtualPath As String) As String
        If String.IsNullOrWhiteSpace(virtualPath) Then
            Return String.Empty
        End If

        Dim candidate As String = virtualPath.Trim()
        If candidate.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           candidate.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return candidate
        End If

        If candidate.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            candidate = candidate.Substring(1)
        End If
        If Not candidate.StartsWith("/") Then
            candidate = "/" & candidate.TrimStart("/"c)
        End If

        Return RuntimeSiteBaseUrl.TrimEnd("/"c) & candidate
    End Function

    Private Function RuntimeUrlExistsCached(ByVal absoluteUrl As String) As Boolean
        If String.IsNullOrWhiteSpace(absoluteUrl) Then
            Return False
        End If

        Dim cacheKey As String = "ks-runtime-asset:" & absoluteUrl.ToLowerInvariant()
        Dim cached As Object = HttpRuntime.Cache(cacheKey)
        If cached IsNot Nothing Then
            Return Convert.ToBoolean(cached)
        End If

        Dim exists As Boolean = False
        Try
            Dim request As HttpWebRequest = CType(WebRequest.Create(absoluteUrl), HttpWebRequest)
            request.Method = "HEAD"
            request.Timeout = 1500
            request.ReadWriteTimeout = 1500
            request.AllowAutoRedirect = True

            Using response As HttpWebResponse = CType(request.GetResponse(), HttpWebResponse)
                exists = (response.StatusCode = HttpStatusCode.OK)
            End Using
        Catch
            exists = False
        End Try

        HttpRuntime.Cache.Insert(cacheKey, exists, Nothing, DateTime.UtcNow.AddMinutes(60), System.Web.Caching.Cache.NoSlidingExpiration)
        Return exists
    End Function

    Protected Function ProductImageThumb(ByVal value As Object) As String
        Return ThemeManager.ProductThumbnailImageUrl(value)
    End Function

    Protected Function ProductImageFull(ByVal value As Object) As String
        Return ThemeManager.ProductImageUrl(value)
    End Function

    Private Function ProductImagePlaceholder() As String
        Return ThemeManager.PlaceholderProductImageUrl()
    End Function

    Private Function ResolveBrandImage(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then Return String.Empty
        fileName = fileName.Replace("\", "/")
        Dim candidate As String = String.Empty
        If fileName.StartsWith("/") OrElse fileName.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            candidate = fileName
        Else
            candidate = "/Public/assets/images/marche/" & Path.GetFileName(fileName)
        End If

        If VirtualPathExists(candidate) Then
            Return candidate
        End If

        If IsApprovedBrandAsset(fileName) Then
            Dim runtimeUrl As String = BuildRuntimeAssetUrl(candidate)
            If RuntimeUrlExistsCached(runtimeUrl) Then
                Return runtimeUrl
            End If
        End If

        Return String.Empty
    End Function

    Protected Function BrandImage(ByVal value As Object) As String
        Return ResolveBrandImage(value)
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

    Private Function CurrentPrice(ByVal row As DataRow) As Decimal
        If row Is Nothing Then
            Return 0D
        End If

        Dim promoPrice As Decimal = 0D
        If TryGetValidPromoPrice(row, promoPrice) Then
            Return promoPrice
        End If

        Return GetBasePrice(row)
    End Function

    Protected Function CurrentPrice(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Dim listino As Decimal = ToDecimal(priceIvato)
        Dim promoPrice As Decimal = 0D
        If TryGetValidPromoPrice(priceIvato, promo, promoIvato, inOfferta, promoPrice) Then
            Return promoPrice
        End If
        Return listino
    End Function

    Private Function GetBasePrice(ByVal row As DataRow) As Decimal
        If row Is Nothing Then
            Return 0D
        End If

        Dim listino As Decimal = If(row.Table.Columns.Contains("PrezzoIvato"), ToDecimal(row("PrezzoIvato")), 0D)
        If listino <= 0D AndAlso row.Table.Columns.Contains("Prezzo") Then
            listino = ToDecimal(row("Prezzo"))
        End If
        Return listino
    End Function

    Protected Function SavingsAmount(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Decimal
        Return SavingsAmount(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Private Function SavingsAmount(ByVal row As DataRow) As Decimal
        If row Is Nothing Then
            Return 0D
        End If

        Dim listino As Decimal = GetBasePrice(row)
        Dim current As Decimal = CurrentPrice(row)
        If listino > current AndAlso current > 0D Then
            Return listino - current
        End If
        Return 0D
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

    Private Function ShowDiscount(ByVal row As DataRow) As Boolean
        Return SavingsAmount(row) > 0D
    End Function

    Protected Function ShowDiscount(ByVal priceIvato As Object, ByVal promo As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Boolean
        Return SavingsAmount(priceIvato, promo, promoIvato, inOfferta) > 0D
    End Function

    Protected Function DiscountPercent(ByVal priceIvato As Object, ByVal promoIvato As Object, ByVal inOfferta As Object) As Integer
        Return DiscountPercent(priceIvato, 0D, promoIvato, inOfferta)
    End Function

    Private Function DiscountPercent(ByVal row As DataRow) As Integer
        If row Is Nothing Then
            Return 0
        End If

        Dim listino As Decimal = GetBasePrice(row)
        Dim current As Decimal = CurrentPrice(row)
        If listino <= 0D OrElse current <= 0D OrElse current >= listino Then
            Return 0
        End If
        Return Convert.ToInt32(Math.Round(((listino - current) / listino) * 100D, MidpointRounding.AwayFromZero))
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
        Return amount.ToString("N2", ItCulture) & " " & ChrW(8364)
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
            If diff.TotalSeconds > 0 Then
                Return Math.Max(1, Convert.ToInt32(Math.Floor(diff.TotalSeconds)))
            End If
        End If
        Return 0
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

    Private Function TryGetValidPromoPrice(ByVal row As DataRow, ByRef promoPrice As Decimal) As Boolean
        promoPrice = 0D
        If row Is Nothing OrElse Not IsPromoRowValid(row) Then
            Return False
        End If

        Dim basePrice As Decimal = GetBasePrice(row)
        Dim promoGross As Decimal = ToDecimal(row("PrezzoPromoIvato"))
        Dim promoNet As Decimal = ToDecimal(row("PrezzoPromo"))
        Dim candidate As Decimal = If(promoGross > 0D, promoGross, promoNet)

        If candidate <= 0D Then
            Return False
        End If

        If basePrice > 0D AndAlso candidate >= basePrice Then
            Return False
        End If

        promoPrice = candidate
        Return True
    End Function

    Private Function IsPromoRowValid(ByVal row As DataRow) As Boolean
        If row Is Nothing OrElse SafeInt(row("InOfferta")) <> 1 Then
            Return False
        End If

        Dim currentListino As Integer = GetCurrentListino()
        Dim daListino As Integer = SafeInt(If(row.Table.Columns.Contains("OfferteDaListino"), row("OfferteDaListino"), 0))
        Dim aListino As Integer = SafeInt(If(row.Table.Columns.Contains("OfferteAListino"), row("OfferteAListino"), 0))
        If daListino > 0 AndAlso currentListino < daListino Then
            Return False
        End If
        If aListino > 0 AndAlso currentListino > aListino Then
            Return False
        End If

        Dim startDate As DateTime
        If row.Table.Columns.Contains("OfferteDataInizio") AndAlso TryParseKeepStoreDate(row("OfferteDataInizio"), startDate) Then
            If startDate.Date > Date.Today Then
                Return False
            End If
        End If

        Dim endDate As DateTime
        If row.Table.Columns.Contains("OfferteDataFine") AndAlso TryParseKeepStoreDate(row("OfferteDataFine"), endDate) Then
            If endDate.Date < Date.Today Then
                Return False
            End If
        End If

        Return True
    End Function

    Private Function TryParseKeepStoreDate(ByVal value As Object, ByRef parsed As DateTime) As Boolean
        parsed = DateTime.MinValue
        If value Is Nothing OrElse value Is DBNull.Value Then
            Return False
        End If

        If TypeOf value Is DateTime Then
            parsed = DirectCast(value, DateTime)
            Return True
        End If

        Dim raw As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(raw) Then
            Return False
        End If

        Dim formats As String() = {"yyyy-MM-dd", "yyyy-M-d", "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy", "yyyyMMdd"}
        If DateTime.TryParseExact(raw, formats, ItCulture, DateTimeStyles.None, parsed) Then
            Return True
        End If
        If DateTime.TryParseExact(raw, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then
            Return True
        End If
        If DateTime.TryParse(raw, ItCulture, DateTimeStyles.None, parsed) Then
            Return True
        End If
        If DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then
            Return True
        End If

        Return False
    End Function

    Private Function TryGetPromoDeadline(ByVal row As DataRow, ByRef deadline As DateTime) As Boolean
        deadline = DateTime.MinValue
        If row Is Nothing OrElse Not IsPromoRowValid(row) Then
            Return False
        End If

        Dim raw As Object = Nothing
        If row.Table.Columns.Contains("OfferteDataFine") Then
            raw = row("OfferteDataFine")
        End If

        If raw Is Nothing OrElse raw Is DBNull.Value Then
            Return False
        End If

        Dim parsed As DateTime
        If Not TryParseKeepStoreDate(raw, parsed) Then
            Return False
        End If

        deadline = parsed.Date.AddDays(1)
        Return deadline > DateTime.Now
    End Function

    Private Function RenderCountdownBlock(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim deadline As DateTime
        If Not TryGetPromoDeadline(row, deadline) Then
            Return String.Empty
        End If

        Dim seconds As Integer = CountdownSeconds(deadline.AddSeconds(-1))
        If seconds <= 0 Then
            Return String.Empty
        End If

        Return "<div class='countdown-box'><div class='js-countdown' data-timer='" &
               seconds.ToString(ItCulture) &
               "' data-labels='Giorni,Ore,Min,Sec'></div></div>"
    End Function

    Private Function ToDecimal(ByVal value As Object) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then
            Return 0D
        End If

        Try
            If TypeOf value Is Decimal OrElse TypeOf value Is Double OrElse TypeOf value Is Single OrElse
               TypeOf value Is Integer OrElse TypeOf value Is Long OrElse TypeOf value Is Short Then
                Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
            End If
        Catch
        End Try

        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then
            Return 0D
        End If

        s = s.Trim().Replace("€", String.Empty).Replace("EUR", String.Empty).Trim()

        Dim d As Decimal
        Dim normalized As String = NormalizeDecimalText(s)
        If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        If Decimal.TryParse(s, NumberStyles.Any, ItCulture, d) Then
            Return d
        End If

        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        Return 0D
    End Function

    Private Function NormalizeDecimalText(ByVal value As String) As String
        Dim s As String = CleanMoneyText(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        Dim comma As Integer = s.LastIndexOf(","c)
        Dim dot As Integer = s.LastIndexOf("."c)

        If comma >= 0 AndAlso dot >= 0 Then
            If comma > dot Then
                s = s.Replace(".", "").Replace(","c, "."c)
            Else
                s = s.Replace(",", "")
            End If
        ElseIf dot >= 0 Then
            s = NormalizeSingleDecimalSeparator(s, "."c)
        ElseIf comma >= 0 Then
            s = NormalizeSingleDecimalSeparator(s, ","c)
        End If

        Return s
    End Function

    Private Function CleanMoneyText(ByVal value As String) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Trim()
        s = s.Replace(ChrW(8364), "")
        s = s.Replace(ChrW(226) & ChrW(8218) & ChrW(172), "")
        s = s.Replace("&euro;", "").Replace("&#8364;", "")
        s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
        s = s.Replace(ChrW(8722), "-")
        s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "")
        s = s.Replace(" ", "").Replace("'", "")

        Return s
    End Function

    Private Function NormalizeSingleDecimalSeparator(ByVal value As String, ByVal separator As Char) As String
        Dim parts() As String = value.Split(separator)
        If parts.Length <= 1 Then Return value

        Dim last As String = parts(parts.Length - 1)

        If parts.Length > 2 Then
            If last.Length > 0 AndAlso last.Length <= 2 Then
                Return JoinAllButLast(parts) & "." & last
            End If

            Return String.Join("", parts)
        End If

        If last.Length = 3 Then
            Return parts(0) & last
        End If

        If separator = ","c Then
            Return parts(0) & "." & last
        End If

        Return value
    End Function

    Private Function JoinAllButLast(ByVal parts() As String) As String
        Dim output As String = ""
        For i As Integer = 0 To parts.Length - 2
            output &= parts(i)
        Next
        Return output
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
        Dim tcidText As String = If(row.Table.Columns.Contains("TCid"), Convert.ToString(row("TCid")), "-1")
        If String.IsNullOrWhiteSpace(tcidText) Then tcidText = "-1"
        Dim title As String = HttpUtility.HtmlDecode(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id")))
        Dim brand As String = Convert.ToString(row("MarcheDescrizione")).Trim()
        Dim category As String = CardCaption(row)
        Dim code As String = Convert.ToString(row("Codice")).Trim()
        Dim url As String = ProductUrl(row("id"))
        Dim img As String = ProductImageFull(row("Img1"))
        Dim priceText As String = FormatMoney(CurrentPrice(row))
        Dim soldText As String = FormatQuantity(row("VendutiAnno"))
        Dim availableText As String = FormatQuantity(row("Giacenza"))
        Dim description As String = QuickViewDescription(row)
        Dim progress As String = AvailabilityPercent(row("Giacenza"), row("VendutiAnno")).ToString("0.##", CultureInfo.InvariantCulture)

        Dim sb As New StringBuilder()
        sb.Append(" data-ks-id='").Append(EncodeAttr(idText)).Append("'")
        sb.Append(" data-ks-tcid='").Append(EncodeAttr(tcidText)).Append("'")
        sb.Append(" data-ks-title='").Append(EncodeAttr(title)).Append("'")
        sb.Append(" data-ks-brand='").Append(EncodeAttr(brand)).Append("'")
        sb.Append(" data-ks-category='").Append(EncodeAttr(category)).Append("'")
        sb.Append(" data-ks-code='").Append(EncodeAttr(code)).Append("'")
        sb.Append(" data-ks-url='").Append(EncodeAttr(url)).Append("'")
        sb.Append(" data-ks-img='").Append(EncodeAttr(img)).Append("'")
        sb.Append(" data-ks-price='").Append(EncodeAttr(priceText)).Append("'")
        sb.Append(" data-ks-sold='").Append(EncodeAttr(soldText)).Append("'")
        sb.Append(" data-ks-available='").Append(EncodeAttr(availableText)).Append("'")
        sb.Append(" data-ks-progress='").Append(EncodeAttr(progress)).Append("'")
        sb.Append(" data-ks-cart-url='").Append(EncodeAttr(CartAddUrl(row))).Append("'")
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
        sb.Append("<li><a href='").Append(CartAddUrl(row)).Append("' class='box-icon add-to-cart btn-icon-action ks-home-buy-cta ").Append(tooltipClass).Append(" js-ks-cart-link'").Append(quickViewAttrs).Append(" aria-label='Acquista: aggiungi al carrello' title='Acquista: aggiungi al carrello'><span class='ks-card-buy-cta__icon icon-cart-2' aria-hidden='true'></span><span class='ks-home-buy-cta__text'>Acquista</span><span class='tooltip'>Acquista</span></a></li>")
        sb.Append("<li class='wishlist'><a href='").Append(WishlistAddUrl(row("id"))).Append("' class='box-icon btn-icon-action ").Append(tooltipClass).Append(" js-ks-wishlist-link'").Append(quickViewAttrs).Append(" aria-label='Wishlist'><i class='icon icon-heart2'></i><span class='tooltip'>Wishlist</span></a></li>")
        sb.Append("<li><a href='#quickView' data-bs-toggle='modal' class='box-icon quickview btn-icon-action ").Append(tooltipClass).Append(" js-ks-quickview'").Append(quickViewAttrs).Append(" aria-label='Vedi prodotto'><i class='icon icon-view'></i><span class='tooltip'>Vedi prodotto</span></a></li>")
        sb.Append("<li><a href='#compare' data-bs-toggle='offcanvas' data-bs-target='#compare' aria-controls='compare' class='box-icon btn-icon-action ").Append(tooltipClass).Append(" js-ks-compare'").Append(compareAttrs).Append(" aria-label='Confronta'><i class='icon icon-compare1'></i><span class='tooltip'>Confronta</span></a></li>")
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Function RenderSaleBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not ShowDiscount(row) Then
            Return String.Empty
        End If

        Return "<div class='box-sale-wrap top-0 start-0 pst-default z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>" &
               DiscountPercent(row).ToString(ItCulture) &
               "%</p></div>"
    End Function

    Private Function RenderCenterSaleBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not ShowDiscount(row) Then
            Return String.Empty
        End If

        Return "<div class='box-sale-wrap style-2 z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>" &
               HttpUtility.HtmlEncode(FormatMoney(SavingsAmount(row))) &
               "</p></div>"
    End Function

    Private Function RenderRefurbishedBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not IsRefurbished(row) Then
            Return String.Empty
        End If

        Return "<div class='badge-refurbished'><img src='/Public/assets/images/img/refurbished.png' alt='Ricondizionato'></div>"
    End Function

    Private Function RenderPriceBlock(ByVal row As DataRow, ByVal emphasize As Boolean) As String
        Dim sb As New StringBuilder()
        Dim priceClass As String = If(emphasize, "new-price h4 fw-normal text-primary mb-0", "new-price body-md-2 fw-medium text-primary mb-0")
        Dim oldPriceClass As String = If(emphasize, "old-price price-text text-main-2", "old-price body-md-2 text-main-2")

        sb.Append("<p class='price-wrap fw-medium'>")
        sb.Append("<span class='").Append(priceClass).Append("'>").Append(FormatMoney(CurrentPrice(row))).Append("</span>")
        If ShowDiscount(row) Then
            sb.Append("<span class='").Append(oldPriceClass).Append("'>").Append(FormatMoney(GetBasePrice(row))).Append("</span>")
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
        Dim galleryImages As List(Of String) = ProductGalleryImages(row)
        If galleryImages.Count > 0 Then
            sb.Append("<ul class='list-image-product ks-deal-thumbs'>")
            For i As Integer = 0 To Math.Min(4, galleryImages.Count - 1)
                sb.Append("<li class='image-swap")
                If i = 0 Then sb.Append(" active")
                sb.Append("'><img class='lazyload' src='").Append(galleryImages(i)).Append("' data-src='").Append(galleryImages(i)).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append(" anteprima ").Append((i + 1).ToString(CultureInfo.InvariantCulture)).Append("'></li>")
            Next
            sb.Append("</ul>")
        End If
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
        If ShowDiscount(row) Then
            sb.Append("<p class='box-sale-tag'>Risparmi ").Append(FormatMoney(SavingsAmount(row))).Append("</p>")
        End If
        sb.Append("<div class='box-infor-detail gap-xl-20'>")
        sb.Append(RenderCountdownBlock(row))
        Dim progressValue As Decimal = AvailabilityPercent(row("Giacenza"), row("VendutiAnno"))
        sb.Append("<div class='product-progress-sale'>")
        sb.Append("<div class='progress-sold progress ks-home-progress' role='progressbar' aria-valuemin='0' aria-valuemax='100' aria-valuenow='").Append(progressValue.ToString("0.##", CultureInfo.InvariantCulture)).Append("'>")
        sb.Append("<div class='progress-bar bg-danger ks-home-progress-bar' style='width:").Append(progressValue.ToString("0.##", CultureInfo.InvariantCulture)).Append("%'></div>")
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
        Dim hasDiscount As Boolean = ShowDiscount(row)

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
        If hasDiscount Then sb.Append(RenderCountdownBlock(row))
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
