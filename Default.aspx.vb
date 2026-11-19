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
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Private ReadOnly _homePromotionModelCache As New Dictionary(Of String, ProductPromotionDisplayModel)(StringComparer.Ordinal)
    Private _homeTiming As HomeServerStageTiming
    ' 0 = status not observed; never infer HTTP 200 when capture is unavailable.
    Private _homeTimingHttpStatus As Integer = 0
    ' Owned only by this page's synchronous BindHome call, never by another request.
    Private _homeQueryScopeActive As Boolean
    Private _homeQueryConnection As MySqlConnection

    Private NotInheritable Class HomeQueryConnectionLease
        Implements IDisposable

        Public ReadOnly Connection As MySqlConnection
        Private ReadOnly _ownsConnection As Boolean
        Private _disposed As Boolean

        Public Sub New(ByVal connection As MySqlConnection, ByVal ownsConnection As Boolean)
            Me.Connection = connection
            _ownsConnection = ownsConnection
        End Sub

        Public Sub Dispose() Implements IDisposable.Dispose
            If _disposed Then Return
            _disposed = True
            If _ownsConnection Then Connection.Dispose()
        End Sub
    End Class

    Private Function AcquireHomeQueryLease() As HomeQueryConnectionLease
        If Not _homeQueryScopeActive Then
            Return New HomeQueryConnectionLease(
                New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString), True)
        End If

        If _homeQueryConnection IsNot Nothing AndAlso _homeQueryConnection.State <> ConnectionState.Open Then
            InvalidateHomeQueryConnection()
        End If
        If _homeQueryConnection Is Nothing Then
            _homeQueryConnection = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
        End If
        Return New HomeQueryConnectionLease(_homeQueryConnection, False)
    End Function

    Private Sub InvalidateHomeQueryConnection()
        Dim connection As MySqlConnection = _homeQueryConnection
        _homeQueryConnection = Nothing
        If connection Is Nothing Then Return

        Try
            connection.Close()
        Catch
            System.Diagnostics.Trace.TraceWarning("HOME query connection close failed.")
        Finally
            Try
                connection.Dispose()
            Catch
                System.Diagnostics.Trace.TraceWarning("HOME query connection dispose failed.")
            End Try
        End Try
    End Sub

    Protected Overrides Sub OnPreInit(ByVal e As EventArgs)
        _homeTiming = HomeServerStageTiming.TryStart(HttpContext.Current)
        HomeServerStageTiming.Mark(_homeTiming, "page.preinit.enter")
        Using HomeServerStageTiming.Measure(_homeTiming, "page.preinit.callbacks")
            MyBase.OnPreInit(e)
        End Using
    End Sub

    Protected Overrides Sub OnInit(ByVal e As EventArgs)
        HomeServerStageTiming.Mark(_homeTiming, "page.init.enter")
        Using HomeServerStageTiming.Measure(_homeTiming, "page.init.callbacks")
            MyBase.OnInit(e)
        End Using
    End Sub

    Protected Overrides Sub OnLoad(ByVal e As EventArgs)
        HomeServerStageTiming.Mark(_homeTiming, "page.load.enter")
        Using HomeServerStageTiming.Measure(_homeTiming, "page.load.callbacks")
            MyBase.OnLoad(e)
        End Using
    End Sub

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        HomeServerStageTiming.Mark(_homeTiming, "page.prerender.enter")
        Using HomeServerStageTiming.Measure(_homeTiming, "page.prerender.callbacks")
            MyBase.OnPreRender(e)
        End Using
    End Sub

    Protected Overrides Sub OnPreRenderComplete(ByVal e As EventArgs)
        HomeServerStageTiming.Mark(_homeTiming, "page.prerender.complete")
        MyBase.OnPreRenderComplete(e)
    End Sub

    Protected Overrides Sub OnSaveStateComplete(ByVal e As EventArgs)
        HomeServerStageTiming.Mark(_homeTiming, "page.state.complete")
        MyBase.OnSaveStateComplete(e)
    End Sub

    Protected Overrides Sub Render(ByVal writer As HtmlTextWriter)
        _homeTimingHttpStatus = 0
        Using HomeServerStageTiming.Measure(_homeTiming, "page.render")
            MyBase.Render(writer)
        End Using
        If _homeTiming IsNot Nothing Then
            Try
                Dim observedStatus As Integer = Response.StatusCode
                If observedStatus >= 100 AndAlso observedStatus <= 599 Then
                    _homeTimingHttpStatus = observedStatus
                End If
            Catch
                ' Status capture is diagnostic only; completion still receives 0.
                _homeTimingHttpStatus = 0
            End Try
        End If
    End Sub

    Protected Overrides Sub OnUnload(ByVal e As EventArgs)
        Try
            Using HomeServerStageTiming.Measure(_homeTiming, "page.unload.callbacks")
                MyBase.OnUnload(e)
            End Using
        Finally
            Try
                If _homeTiming IsNot Nothing Then _homeTiming.Complete(_homeTimingHttpStatus)
            Catch
                ' A diagnostic/logging failure must not alter the HTTP outcome.
            End Try
        End Try
    End Sub

    Protected ReadOnly Property HomeAsyncCartToken As String
        Get
            Return CatalogAsyncCartSupport.GetOrCreateCsrfToken(HttpContext.Current)
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ' La composizione delle vetrine cambia a ogni richiesta: la risposta non si riusa senza rivalidare (Cache-Control: no-cache).
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Using HomeServerStageTiming.Measure(_homeTiming, "home.context")
            _priceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(HttpContext.Current)
        End Using
        If _priceDisplayContext Is Nothing OrElse
           _priceDisplayContext.CompanyId <> GetCurrentAziendaId() OrElse
           _priceDisplayContext.PriceListId <= 0 Then
            Response.StatusCode = 421
            Response.TrySkipIisCustomErrors = True
            HomePriceDisplayNote.Visible = False
            Return
        End If
        If _homeTiming IsNot Nothing Then _homeTiming.SetCompany(_priceDisplayContext.CompanyId)
        litHomePriceDisplayLabel.Text = HttpUtility.HtmlEncode(_priceDisplayContext.DisplayLabel)
        MarkBodyAsHome()
        ApplyHomeSeo()
        ' I repeater della HOME non salvano lo stato nel ViewState (il testo collegato ai dati lo riempiva di centinaia di KB):
        ' si ricostruiscono a ogni richiesta, anche in un eventuale postback.
        BindHome()
    End Sub

    ' Un solo generatore per richiesta, con un seme casuale (due istanze create nello stesso istante darebbero la stessa sequenza).
    Private ReadOnly _homeRandom As New Random(Guid.NewGuid().GetHashCode())

    ' La memoria di cio che e stato mostrato contiene SOLO identificativi (mai prezzi) ed e separata per azienda, listino, stato di accesso
    ' e modalita IVA: al cambio di contesto la storia precedente non si usa.
    Private Function HomeRotationSessionKey(ByVal section As String) As String
        Return "KeepStore.HomeRotation." & section & "." &
               GetCurrentAziendaId().ToString(CultureInfo.InvariantCulture) & "." &
               GetCurrentListino().ToString(CultureInfo.InvariantCulture) & "." &
               If(_priceDisplayContext.IsAuthenticated, "a", "g") & If(_priceDisplayContext.IsVatIncluded, "i", "e")
    End Function

    Private Function RotateHomePool(ByVal section As String,
                                    ByVal pool As DataTable,
                                    ByVal take As Integer,
                                    ByVal usedBusinessKeys As HashSet(Of String),
                                    ByVal usedDisplayKeys As HashSet(Of String)) As DataTable
        If IsTableEmpty(pool) Then Return pool
        Dim recent As ICollection(Of Integer) = Nothing
        Try
            If Session IsNot Nothing Then recent = StorefrontShowcaseRotation.ParseIds(Session(HomeRotationSessionKey(section)))
        Catch
            recent = Nothing
        End Try
        ' La finestra si forma sui candidati realmente selezionabili (distinti per codice e per chiave di visualizzazione, esclusi gli
        ' articoli gia usati da altre sezioni), non sulle righe grezze della query.
        Dim candidates As DataTable = CollectDistinctRows(Integer.MaxValue, usedBusinessKeys, usedDisplayKeys, False, False, True, pool)
        Return StorefrontShowcaseRotation.Rotate(candidates, take, recent, _homeRandom)
    End Function

    Private Sub RememberHomeSelection(ByVal section As String, ByVal shown As DataTable)
        Try
            If Session IsNot Nothing Then Session(HomeRotationSessionKey(section)) = StorefrontShowcaseRotation.FormatIds(shown)
        Catch
        End Try
    End Sub

    ' KS-A04-HOME-BODY-CLASS-1A: le classi della HOME stanno nell'HTML servito, non solo dopo il JavaScript (altrimenti gli stili `body.ks-page-home`
    ' scattano a pagina caricata e la HOME si sposta). In questo punto il body del master non ha ancora `class`: la lettura e a prova di Nothing.
    Private Sub MarkBodyAsHome()
        Try
            Dim body = TryCast(Master.FindControl("PageBody"), HtmlGenericControl)
            If body IsNot Nothing Then
                body.Attributes("class") = AppendBodyClass(AppendBodyClass(body.Attributes("class"), "ks-page-home"), "ks-home-main")
            End If
        Catch
        End Try
    End Sub

#Region "BodyClassPure"
    ' Aggiunge un token alla lista delle classi, senza duplicati (confronto per token e senza maiuscole) e senza fallire se l'attributo non esiste ancora:
    ' Convert.ToString su un String Nothing restituisce Nothing, ed e per questo che la versione precedente non ha mai scritto nulla (NullReferenceException nascosta dal Catch).
    Friend Shared Function AppendBodyClass(ByVal current As String, ByVal token As String) As String
        Dim existing As String = If(current, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(token) Then Return existing
        For Each part As String In existing.Split(New Char() {" "c, ControlChars.Tab, ControlChars.Cr, ControlChars.Lf}, StringSplitOptions.RemoveEmptyEntries)
            If String.Equals(part, token.Trim(), StringComparison.OrdinalIgnoreCase) Then Return existing
        Next
        If existing.Length = 0 Then Return token.Trim()
        Return existing & " " & token.Trim()
    End Function
#End Region

    Private Sub ApplyHomeSeo()
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        If tenant Is Nothing Then
            HomeTrustSection.Visible = False
            Return
        End If

        Dim brandName As String = CleanMarketingText(tenant.CompanyName, "KeepStore")
        Dim businessDescription As String = CleanMarketingText(tenant.CompanyDescription, String.Empty)
        Dim pageTitle As String = brandName & " | Negozio online"
        Dim description As String = If(String.IsNullOrWhiteSpace(businessDescription),
                                       "Scopri il catalogo online di " & brandName & ".",
                                       businessDescription)
        Dim canonical As String = HomeCanonicalUrl()
        Dim logoUrl As String = String.Empty

        litHomePageTitle.Text = pageTitle
        litHomeCompanyName.Text = brandName
        litHomeCompanyDescription.Text = businessDescription
        litHomeIntroName.Text = brandName
        litHomeIntroDescription.Text = If(String.IsNullOrWhiteSpace(businessDescription),
                                          "Esplora il catalogo e trova quello che cerchi.", businessDescription)
        HomeTrustSection.Visible = Not String.IsNullOrWhiteSpace(businessDescription) AndAlso Not HomeIntroSection.Visible

        Dim logoFileName As String = Convert.ToString(tenant.LogoFileName).Trim()
        If logoFileName <> "" AndAlso
           String.Equals(IO.Path.GetFileName(logoFileName), logoFileName, StringComparison.Ordinal) AndAlso
           Not logoFileName.Contains("..") Then
            Dim logoPath As String = "/Public/assets/images/logo/" & logoFileName
            If String.Equals(Convert.ToString(Session("AziendaLogo")).Trim(), logoPath, StringComparison.OrdinalIgnoreCase) Then
                Try
                    If IO.File.Exists(Server.MapPath("~" & logoPath)) Then
                        Dim candidateUrl As String = BuildRuntimeAssetUrl("/Public/assets/images/logo/" & Uri.EscapeDataString(logoFileName))
                        Dim candidateUri As Uri = Nothing
                        If Uri.TryCreate(candidateUrl, UriKind.Absolute, candidateUri) AndAlso
                           String.Equals(candidateUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) AndAlso
                           String.Equals(candidateUri.DnsSafeHost, tenant.CanonicalHost, StringComparison.OrdinalIgnoreCase) Then
                            logoUrl = candidateUrl
                        End If
                    End If
                Catch
                    logoUrl = String.Empty
                End Try
            End If
        End If

        Page.Title = pageTitle
        SeoBuilder.AddOrReplaceMeta(Me, "description", description)
        SeoBuilder.AddOrReplaceMeta(Me, "robots", "index,follow")
        SeoBuilder.SetCanonical(Me, canonical)
        SeoBuilder.ApplyOpenGraph(Me, pageTitle, description, canonical, String.Empty)
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:card", "summary")
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:title", pageTitle)
        SeoBuilder.AddOrReplaceMeta(Me, "twitter:description", description)
        SeoBuilder.ApplyJsonLd(Me, SeoBuilder.BuildHomeJsonLd(Me, pageTitle, description, canonical, logoUrl))
    End Sub

    Private Function HomeCanonicalUrl() As String
        Return StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/")
    End Function

    Private Sub BindHome()
        If _homeQueryScopeActive Then Throw New InvalidOperationException("Nested HOME query scopes are not supported.")
        _homeQueryScopeActive = True
        Try
        Using HomeServerStageTiming.Measure(_homeTiming, "home.bind.inclusive")
        Dim sideBanners As DataTable = GetSideBanners()
        Dim hero As DataTable = GetHeroSlides()
        If IsTableEmpty(hero) AndAlso Not IsTableEmpty(sideBanners) Then
            hero = SliceTable(ConvertSideRowsToHeroRows(sideBanners), 0, 1)
            sideBanners = SliceTable(sideBanners, 1, 1)
        End If
        rptHeroSlides.DataSource = hero
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHeroSlides")
            rptHeroSlides.DataBind()
        End Using

        rptSideBanners.DataSource = sideBanners
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptSideBanners")
            rptSideBanners.DataBind()
        End Using
        ApplyHeroMode(ResolveHeroMode(rptHeroSlides.Items.Count > 0, If(sideBanners Is Nothing, 0, sideBanners.Rows.Count)), rptSideBanners.Items.Count)

        Dim realSectors As List(Of CatalogMenuSector) = CatalogMenuProvider.LoadCatalogMenuCached()
        If realSectors Is Nothing Then realSectors = New List(Of CatalogMenuSector)()
        Dim navigationAssortment As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "home.navigation.assortment")
            navigationAssortment = LoadHomeNavigationAssortment()
        End Using
        realSectors = FilterHomeAssortmentSectors(realSectors, navigationAssortment)
        Dim editorialNavigation As HomeEditorialNavigation = BuildHomeEditorialNavigation(realSectors)
        Dim sectorRows As List(Of CatalogMenuSector) = editorialNavigation.MainSectors
        Dim heroSectorRows As List(Of CatalogMenuSector) = editorialNavigation.HeroSectors
        rptHeroDepartments.DataSource = heroSectorRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHeroDepartments")
            rptHeroDepartments.DataBind()
        End Using
        If HomeHeroDepartmentsPanel IsNot Nothing Then
            HomeHeroDepartmentsPanel.Visible = (heroSectorRows.Count > 0)
        End If
        rptHomeMainCategories.DataSource = sectorRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeMainCategories")
            rptHomeMainCategories.DataBind()
        End Using
        If HomeMainCategoriesSection IsNot Nothing Then
            HomeMainCategoriesSection.Visible = (sectorRows.Count > 0)
            HomeMainCategoriesSection.Attributes("data-ks-sector-count") = sectorRows.Count.ToString(CultureInfo.InvariantCulture)
        End If
        HomeCategoriesCatalogLink.Visible = Not HomeIntroSection.Visible

        Dim directCategories As List(Of HomeDirectCategory) = SelectHomeDirectCategories(realSectors, navigationAssortment)
        rptHomeDirectCategories.DataSource = directCategories
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeDirectCategories")
            rptHomeDirectCategories.DataBind()
        End Using
        HomeDirectCategoriesSection.Visible = (directCategories.Count > 0)
        BindHomeIntroNavigation(navigationAssortment IsNot Nothing)

        ' The secondary editorial areas continue the main grid; hero and guide keep their own navigation.
        Dim collectionRows As List(Of CatalogMenuSector) = editorialNavigation.CollectionSectors
        Dim bottomRows As List(Of CatalogMenuSector) = editorialNavigation.BottomSectors
        Dim searchRows As List(Of CatalogMenuSector) = editorialNavigation.SearchSectors
        rptHomeCollection.DataSource = collectionRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeCollection")
            rptHomeCollection.DataBind()
        End Using
        rptHomeBottomPromo.DataSource = bottomRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeBottomPromo")
            rptHomeBottomPromo.DataBind()
        End Using
        rptHomeAiExamples.DataSource = searchRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeAiExamples")
            rptHomeAiExamples.DataBind()
        End Using
        rptHomeAiQuickLinks.DataSource = searchRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeAiQuickLinks")
            rptHomeAiQuickLinks.DataBind()
        End Using
        HomeAiExamplesPanel.Visible = (searchRows.Count > 0)
        HomeAiQuickLinksPanel.Visible = (searchRows.Count > 0)

        Dim usedBusinessKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim usedDisplayKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim dealPool As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "pool.deals")
            dealPool = GetDealOfferPool(96)
        End Using
        Dim newArrivalsPool As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "pool.new_arrivals")
            newArrivalsPool = GetNewArrivalsPool(60)
        End Using
        Dim incomingPool As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "pool.incoming")
            incomingPool = GetIncomingPool(60)
        End Using
        Dim bestSellerPool As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "pool.bestseller")
            bestSellerPool = GetBestSellerPool(120)
        End Using

        ' Rotazione: dai candidati GIA idonei, distinti e ordinati dalla regola commerciale si estrae un sottoinsieme diverso a ogni richiesta
        ' (i mostrati l'ultima volta vanno in coda). Prezzi e promozioni restano quelli del resolver autorevole.
        Using HomeServerStageTiming.Measure(_homeTiming, "pool.deals.sold")
            ApplyDealSoldUnits(dealPool)
        End Using
        dealPool = RotateHomePool("deals", dealPool, 6, usedBusinessKeys, usedDisplayKeys)
        dealPool = PrioritizeSoldDeals(dealPool)
        Dim dealRows As DataTable = TakeDiverseRows(6, usedBusinessKeys, usedDisplayKeys, dealPool)
        RememberHomeSelection("deals", dealRows)
        rptDealOfDay.DataSource = dealRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptDealOfDay")
            rptDealOfDay.DataBind()
        End Using
        If HomeOffersSection IsNot Nothing Then
            HomeOffersSection.Visible = Not IsTableEmpty(dealRows)
        End If
        If HomeOffersSliderWrap IsNot Nothing Then
            HomeOffersSliderWrap.Visible = Not IsTableEmpty(dealRows)
        End If

        newArrivalsPool = RotateHomePool("arrivals", newArrivalsPool, 8, usedBusinessKeys, usedDisplayKeys)
        incomingPool = RotateHomePool("arrivals", incomingPool, 8, usedBusinessKeys, usedDisplayKeys)
        Dim featuredRows As DataTable = TakeHomeArrivalsRows(8, usedBusinessKeys, usedDisplayKeys, newArrivalsPool, incomingPool)
        RememberHomeSelection("arrivals", featuredRows)
        PopulatePromotionDisplaySnapshot(featuredRows)
        rptHomeFeaturedProducts.DataSource = featuredRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeFeaturedProducts")
            rptHomeFeaturedProducts.DataBind()
        End Using
        If HomeFeaturedProductsSection IsNot Nothing Then
            HomeFeaturedProductsSection.Visible = Not IsTableEmpty(featuredRows)
        End If

        If HomeCollectionSection IsNot Nothing Then HomeCollectionSection.Visible = (collectionRows.Count > 0)
        If HomeBottomPromoSection IsNot Nothing Then HomeBottomPromoSection.Visible = (bottomRows.Count > 0)

        ' Only the configured commercial index qualifies this section; no visits/catalog fallback.
        bestSellerPool = RotateHomePool("best", bestSellerPool, 8, usedBusinessKeys, usedDisplayKeys)
        Dim bestRows As DataTable = TakeRankedHomeRows(8, usedBusinessKeys, usedDisplayKeys, bestSellerPool)
        RememberHomeSelection("best", bestRows)
        PopulatePromotionDisplaySnapshot(bestRows)
        rptBestSeller.DataSource = bestRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptBestSeller")
            rptBestSeller.DataBind()
        End Using
        If HomeLegacyBestSection IsNot Nothing Then
            HomeLegacyBestSection.Visible = Not IsTableEmpty(bestRows)
        End If

        Dim recentRows As DataTable = GetRecentlyViewedProducts(8, usedBusinessKeys, True, usedDisplayKeys, True)
        PopulatePromotionDisplaySnapshot(recentRows)
        rptRecentlyViewed.DataSource = recentRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptRecentlyViewed")
            rptRecentlyViewed.DataBind()
        End Using
        If HomeRecentlyViewedSection IsNot Nothing Then
            HomeRecentlyViewedSection.Visible = Not IsTableEmpty(recentRows)
        End If

        Dim discoveryRows As DataTable = LoadHomeCatalogDiscovery(dealRows, featuredRows, bestRows, recentRows)
        PopulatePromotionDisplaySnapshot(discoveryRows)
        rptHomeCatalogDiscovery.DataSource = discoveryRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptHomeCatalogDiscovery")
            rptHomeCatalogDiscovery.DataBind()
        End Using
        HomeCatalogDiscoverySection.Visible = Not IsTableEmpty(discoveryRows)

        HomePriceDisplayNote.Visible = Not IsTableEmpty(featuredRows) OrElse
                                       Not IsTableEmpty(dealRows) OrElse
                                       Not IsTableEmpty(bestRows) OrElse Not IsTableEmpty(recentRows) OrElse
                                       Not IsTableEmpty(discoveryRows)

        ApplyHomeComposition(HomePriceDisplayNote.Visible)

        Dim brandRows As DataTable
        Using HomeServerStageTiming.Measure(_homeTiming, "home.brands.resolve")
            brandRows = FilterBrandRows(SelectHomeAssortmentBrands(navigationAssortment), 12)
        End Using
        rptBrands.DataSource = brandRows
        Using HomeServerStageTiming.Measure(_homeTiming, "bind.rptBrands")
            rptBrands.DataBind()
        End Using
        If HomeBrandsSection IsNot Nothing Then
            HomeBrandsSection.Visible = Not IsTableEmpty(brandRows)
        End If
        End Using
        Finally
            _homeQueryScopeActive = False
            InvalidateHomeQueryConnection()
        End Try
    End Sub

    Private NotInheritable Class HomeDirectCategory
        Public Property Id As Integer
        Public Property SectorId As Integer
        Public Property Name As String
        Public Property SectorName As String
        Public Property DefaultUrl As String
    End Class

    Private Shared Function SelectHomeDirectCategories(ByVal source As List(Of CatalogMenuSector),
                                                       ByVal assortment As DataTable,
                                                       Optional ByVal limit As Integer = 8) As List(Of HomeDirectCategory)
        Dim result As New List(Of HomeDirectCategory)()
        If source Is Nothing OrElse assortment Is Nothing OrElse limit <= 0 Then Return result
        limit = Math.Min(limit, 8)
        Dim present As New HashSet(Of String)(StringComparer.Ordinal)
        For Each row As DataRow In assortment.Rows
            Dim sectorId As Integer
            Dim categoryId As Integer
            If Integer.TryParse(Convert.ToString(row("SectorId")), sectorId) AndAlso sectorId > 0 AndAlso
               Integer.TryParse(Convert.ToString(row("CategoryId")), categoryId) AndAlso categoryId > 0 Then
                present.Add(sectorId.ToString(CultureInfo.InvariantCulture) & ":" & categoryId.ToString(CultureInfo.InvariantCulture))
            End If
        Next

        Dim sectors As New List(Of CatalogMenuSector)()
        Dim positions As New Dictionary(Of Integer, Integer)()
        For Each sector As CatalogMenuSector In source
            If sector Is Nothing OrElse sector.Id <= 0 OrElse String.IsNullOrWhiteSpace(sector.Descrizione) OrElse
               sector.Categories Is Nothing OrElse sector.Categories.Count = 0 OrElse positions.ContainsKey(sector.Id) Then Continue For
            If Not String.Equals(sector.DefaultUrl, "articoli.aspx?st=" & sector.Id.ToString(CultureInfo.InvariantCulture), StringComparison.OrdinalIgnoreCase) Then Continue For
            sectors.Add(sector)
            positions.Add(sector.Id, 0)
        Next

        Dim seen As New HashSet(Of Integer)()
        Dim added As Boolean = True
        While result.Count < limit AndAlso added
            added = False
            For Each sector As CatalogMenuSector In sectors
                While positions(sector.Id) < sector.Categories.Count
                    Dim category As CatalogMenuCategory = sector.Categories(positions(sector.Id))
                    positions(sector.Id) += 1
                    If category Is Nothing OrElse category.Id <= 0 OrElse category.SettoriId <> sector.Id OrElse
                       String.IsNullOrWhiteSpace(category.Descrizione) OrElse seen.Contains(category.Id) Then Continue While
                    Dim key As String = sector.Id.ToString(CultureInfo.InvariantCulture) & ":" & category.Id.ToString(CultureInfo.InvariantCulture)
                    If Not present.Contains(key) Then Continue While
                    ' Pure overload: validate against the already-loaded authoritative tree, without SQL/cache lookups.
                    Dim taxonomy As CatalogTaxonomyContext = CatalogTaxonomyResolver.Resolve(source, sector.Id, category.Id, String.Empty)
                    If Not taxonomy.IsCoherent OrElse taxonomy.SectorId <> sector.Id OrElse taxonomy.CategoryId <> category.Id OrElse
                       String.IsNullOrWhiteSpace(taxonomy.CategoryName) OrElse String.IsNullOrWhiteSpace(taxonomy.SectorName) OrElse
                       Not String.Equals(taxonomy.CategoryUrl, "~/" & category.DefaultUrl, StringComparison.OrdinalIgnoreCase) Then Continue While
                    result.Add(New HomeDirectCategory With {.Id = category.Id, .SectorId = sector.Id,
                               .Name = taxonomy.CategoryName, .SectorName = taxonomy.SectorName, .DefaultUrl = taxonomy.CategoryUrl})
                    seen.Add(category.Id)
                    added = True
                    Exit While
                End While
                If result.Count >= limit Then Return result
            Next
        End While
        Return result
    End Function

    Private NotInheritable Class HomeEditorialNavigation
        Public ReadOnly MainSectors As New List(Of CatalogMenuSector)()
        Public ReadOnly CollectionSectors As New List(Of CatalogMenuSector)()
        Public ReadOnly BottomSectors As New List(Of CatalogMenuSector)()
        Public ReadOnly HeroSectors As New List(Of CatalogMenuSector)()
        Public ReadOnly SearchSectors As New List(Of CatalogMenuSector)()
    End Class



    Private Shared Function BuildHomeEditorialNavigation(ByVal source As List(Of CatalogMenuSector)) As HomeEditorialNavigation
        ' One ordered, validated set from the existing enabled-sector provider, owned by this request.
        Dim sectors As List(Of CatalogMenuSector) = SelectHomeEditorialSectors(source, 18)
        Dim result As New HomeEditorialNavigation()
        result.MainSectors.AddRange(sectors.GetRange(0, Math.Min(12, sectors.Count)))
        result.HeroSectors.AddRange(sectors.GetRange(0, Math.Min(9, sectors.Count)))
        result.SearchSectors.AddRange(sectors.GetRange(0, Math.Min(5, sectors.Count)))

        ' Both existing secondary grids have three columns. Show complete rows only;
        ' any remainder stays reachable through the unchanged full-catalog links.
        If sectors.Count >= 15 Then result.CollectionSectors.AddRange(sectors.GetRange(12, 3))
        If sectors.Count >= 18 Then result.BottomSectors.AddRange(sectors.GetRange(15, 3))
        Return result
    End Function

    Private Shared Function SelectHomeEditorialSectors(ByVal source As List(Of CatalogMenuSector), Optional ByVal limit As Integer = 9) As List(Of CatalogMenuSector)
        Dim result As New List(Of CatalogMenuSector)()
        If source Is Nothing Then Return result

        Dim seenIds As New HashSet(Of Integer)()
        For Each sector As CatalogMenuSector In source
            If sector Is Nothing OrElse sector.Id <= 0 OrElse String.IsNullOrWhiteSpace(sector.Descrizione) Then Continue For
            Dim expectedUrl As String = "articoli.aspx?st=" & sector.Id.ToString(CultureInfo.InvariantCulture)
            If Not String.Equals(sector.DefaultUrl, expectedUrl, StringComparison.OrdinalIgnoreCase) Then Continue For
            If seenIds.Add(sector.Id) Then result.Add(sector)
            If result.Count >= limit Then Exit For
        Next
        Return result
    End Function



    Protected Function HomeSectorMicrocopy(ByVal value As Object) As String
        Dim categories As List(Of CatalogMenuCategory) = TryCast(value, List(Of CatalogMenuCategory))
        If categories Is Nothing Then Return "Esplora gli articoli del reparto"

        Dim names As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each category As CatalogMenuCategory In categories
            If category Is Nothing OrElse String.IsNullOrWhiteSpace(category.Descrizione) Then Continue For
            Dim name As String = category.Descrizione.Trim()
            If seen.Add(name) Then names.Add(name)
            If names.Count >= 3 Then Exit For
        Next
        If names.Count = 0 Then Return "Esplora gli articoli del reparto"
        Return String.Join(", ", names.ToArray())
    End Function

    Protected Function HomeHeroCtaText(ByVal value As Object) As String
        Dim link As String = ResolveLink(value, "articoli.aspx")
        Dim queryStart As Integer = link.IndexOf("?"c)
        Dim path As String = If(queryStart >= 0, link.Substring(0, queryStart), link).TrimEnd("/"c)

        If IsHomeRoute(path, "articolo.aspx") Then Return "Vedi il prodotto"
        If IsHomeRoute(path, "articoli.aspx") Then
            If queryStart >= 0 AndAlso
               String.Equals(HttpUtility.ParseQueryString(link.Substring(queryStart + 1))("inpromo"), "1", StringComparison.Ordinal) Then
                Return "Scopri le offerte"
            End If
            Return "Esplora il catalogo"
        End If
        Return "Scopri di più"
    End Function

    Private Shared Function IsHomeRoute(ByVal path As String, ByVal routeName As String) As Boolean
        Return String.Equals(path, routeName, StringComparison.OrdinalIgnoreCase) OrElse
               path.EndsWith("/" & routeName, StringComparison.OrdinalIgnoreCase)
    End Function

    Private Function ResolveHeroMode(ByVal hasHeroSlides As Boolean, ByVal sideBannerCount As Integer) As String
        If Not hasHeroSlides Then
            Return "none"
        End If

        Return If(sideBannerCount > 0, "full", "hero-only")
    End Function

    Private Sub ApplyHeroMode(ByVal heroMode As String, ByVal sideBannerCount As Integer)
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
        HomeIntroSection.Visible = (normalizedMode = "none")

        If HomeHeroShell IsNot Nothing Then
            Dim sideClass As String = If(normalizedMode = "full", " ks-home-has-promos", " ks-home-no-promos")
            HomeHeroShell.Attributes("class") = "ks-home-hero-grid ks-home-hero-mode-" & normalizedMode & sideClass
            HomeHeroShell.Attributes("data-ks-hero-mode") = normalizedMode
            If normalizedMode = "hero-only" Then
                HomeHeroShell.Style("grid-template-columns") = "minmax(0, 1fr)"
            End If
        End If

        If HeroSideWrap IsNot Nothing AndAlso sideBannerCount = 1 Then
            HeroSideWrap.Style("grid-template-rows") = "minmax(0, 1fr)"
        End If

        If HomeHeroSection IsNot Nothing Then
            HomeHeroSection.Attributes("class") = "ks-home-hero-area ks-home-hero-mode-" & normalizedMode
            HomeHeroSection.Attributes("data-ks-hero-mode") = normalizedMode
        End If
    End Sub

    Private Sub BindHomeIntroNavigation(ByVal hasVerifiedAssortment As Boolean)
        Dim target As HtmlGenericControl = Nothing
        If hasVerifiedAssortment AndAlso HomeDirectCategoriesSection.Visible Then
            target = HomeDirectCategoriesSection
        ElseIf hasVerifiedAssortment AndAlso HomeMainCategoriesSection.Visible Then
            target = HomeMainCategoriesSection
        End If
        HomeIntroBrowseLink.Visible = (target IsNot Nothing)
        HomeIntroBrowseLink.HRef = String.Empty
        HomeIntroBrowseLabel.InnerText = String.Empty
        If target IsNot Nothing Then
            HomeIntroBrowseLink.HRef = "#" & target.ClientID
            HomeIntroBrowseLabel.InnerText = If(HomeDirectCategoriesSection.Visible, "Esplora le categorie", "Esplora i reparti")
        End If
    End Sub

    Private Sub ApplyHomeComposition(ByVal hasProductSelections As Boolean)
        ' An absent selection can also be a technical failure: do not claim an empty catalog.
        HomeWidePromoSection.Visible = Not HomeIntroSection.Visible AndAlso Not hasProductSelections
        If HomeIntroSection.Visible Then HomeTrustSection.Visible = False
        ' Recently viewed also has a client lifecycle; leave its visibility unchanged.
    End Sub

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
        Dim companyId As Integer = GetCurrentAziendaId()
        If companyId <= 0 Then Return HeroSlidesFallback()
        Dim sql As String = "SELECT id, NULLIF(Descrizione,'') AS Caption, Immagine AS Image, Link AS LinkUrl " &
                            "FROM bannerv2 " &
                            "WHERE AziendeId=@companyId AND COALESCE(Posizione,0)=3 " &
                            "ORDER BY COALESCE(Ordinamento,0), id DESC LIMIT 24"
        Dim parameters As New Dictionary(Of String, Object) From {{"@companyId", companyId}}
        Dim dt As DataTable = SafeTableQuery(sql, HeroSlidesFallback(), "GetHeroWideBanners", parameters)
        dt = FilterRowsByResolvedImage(dt, "Image", AddressOf ResolveAdvertisingImagePath)
        Return PrepareHeroRows(dt, "In evidenza", String.Empty)
    End Function

    Private Function GetHeroSideBannerSource() As DataTable
        Dim companyId As Integer = GetCurrentAziendaId()
        If companyId <= 0 Then Return SideBannersFallback()
        Dim sql As String = "SELECT p.id, " &
                            "COALESCE(NULLIF(p.caption,''), NULLIF(s.titolo,''), NULLIF(s.descrizione,'')) AS Title, " &
                            "NULLIF(s.descrizione,'') AS Description, " &
                            "p.image AS Image, p.link AS LinkUrl, 'In evidenza' AS Badge " &
                            "FROM slideshows s " &
                            "INNER JOIN slideshows_parts p ON p.slideshowid = s.id " &
                            "WHERE s.aziendeId=@companyId AND COALESCE(s.abilitato,0)=1 AND LOWER(COALESCE(s.placeholder,''))='defaultpage' " &
                            "AND (s.dataInizioPubblicazione IS NULL OR s.dataInizioPubblicazione <= CURDATE()) " &
                            "AND (s.dataFinePubblicazione IS NULL OR s.dataFinePubblicazione >= CURDATE()) " &
                            "ORDER BY CASE WHEN NULLIF(p.orderPosition,'') IS NULL THEN 999 ELSE CAST(p.orderPosition AS UNSIGNED) END, p.id DESC " &
                            "LIMIT 12"
        Dim parameters As New Dictionary(Of String, Object) From {{"@companyId", companyId}}
        Dim dt As DataTable = SafeTableQuery(sql, SideBannersFallback(), "GetHeroSideBannerSource", parameters)
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
            newRow("Caption") = CleanMarketingText(If(row.Table.Columns.Contains("Caption"), row("Caption"), String.Empty), "Scopri i prodotti")
            newRow("Image") = Convert.ToString(row("Image")).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Eyebrow") = BuildHeroEyebrow(defaultEyebrow)
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), defaultDescription)
            newRow("ProductId") = 0
            result.Rows.Add(newRow)
        Next

        Return result
    End Function

    Private Function PrepareSideBannerRows(ByVal source As DataTable) As DataTable
        Dim result As DataTable = SideBannersFallback().Clone()
        If source Is Nothing Then
            Return result
        End If

        For Each row As DataRow In source.Rows
            Dim newRow As DataRow = result.NewRow()
            Dim title As String = CleanMarketingText(If(row.Table.Columns.Contains("Title"), row("Title"), String.Empty), "Scopri i prodotti")
            newRow("Title") = title
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), String.Empty)
            newRow("Image") = Convert.ToString(row("Image")).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Badge") = BuildSideBannerBadge()
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
            newRow("Caption") = CleanMarketingText(If(row.Table.Columns.Contains("Title"), row("Title"), String.Empty), "Scopri i prodotti")
            newRow("Image") = Convert.ToString(If(row.Table.Columns.Contains("Image"), row("Image"), String.Empty)).Trim()
            newRow("LinkUrl") = NormalizeProjectLink(Convert.ToString(If(row.Table.Columns.Contains("LinkUrl"), row("LinkUrl"), String.Empty)), "articoli.aspx")
            newRow("Eyebrow") = BuildHeroEyebrow(String.Empty)
            newRow("Description") = CleanMarketingText(If(row.Table.Columns.Contains("Description"), row("Description"), String.Empty), String.Empty)
            newRow("ProductId") = 0
            result.Rows.Add(newRow)
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

    Private Function BuildHeroEyebrow(ByVal fallback As String) As String
        Return If(String.IsNullOrWhiteSpace(fallback), "In evidenza", fallback)
    End Function

    Private Function BuildSideBannerBadge() As String
        Return "In evidenza"
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

        Dim absoluteLink As Uri = Nothing
        If Uri.TryCreate(link, UriKind.Absolute, absoluteLink) AndAlso absoluteLink IsNot Nothing Then
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
            If tenant Is Nothing OrElse
               Not StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, absoluteLink.DnsSafeHost, False) Then
                Return defaultLink
            End If
            Return If(String.IsNullOrWhiteSpace(absoluteLink.PathAndQuery), defaultLink, absoluteLink.PathAndQuery)
        End If

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

    Private Function GetDealOfferPool(ByVal limit As Integer) As DataTable
        Dim authorized As DataTable = QueryProducts(OfferWhereClause(),
                                                    "COALESCE(v.Visite,0) DESC, v.id DESC, COALESCE(v.TCid,-1) ASC",
                                                    0,
                                                    True)
        Return SortAuthorizedDealRows(authorized, limit)
    End Function

    ' HOME-DEAL-PROGRESS-1A (decisione del PO del 2026-11-19: "tutte le vendite"). I venduti di un'occasione sono la STESSA misura commerciale
    ' usata per "I piu scelti dai clienti" (BuildHomeCommercialActivitySql): per articolo, il maggiore fra quantita ordinate e quantita
    ' scaricate, ultimi 12 mesi, azienda dell'host, stati non annullati. Una sola lettura per tutti gli articoli candidati; ogni errore
    ' lascia i venduti a zero (nessuna barra), senza fermare la HOME. Restituisce False se la lettura non e riuscita.
    Private Function ApplyDealSoldUnits(ByVal pool As DataTable) As Boolean
        If IsTableEmpty(pool) OrElse Not pool.Columns.Contains("QtaVenduta") Then Return False
        Dim ids As New List(Of Integer)()
        Dim seen As New HashSet(Of Integer)()
        For Each row As DataRow In pool.Rows
            Dim id As Integer = SafeInt(row("id"))
            If id > 0 AndAlso seen.Add(id) AndAlso ids.Count < DealSoldUnitsMaxArticles Then ids.Add(id)
        Next
        If ids.Count = 0 Then Return False
        Dim idList As String = String.Join(",", ids.ConvertAll(Function(value As Integer) value.ToString(CultureInfo.InvariantCulture)).ToArray())
        Dim sold As New Dictionary(Of Integer, Decimal)()
        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT x.ArticoliId, x.CommercialScore FROM (" & BuildHomeCommercialActivitySql(idList) & ") x", conn)
                    cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = GetCurrentAziendaId()
                    cmd.Parameters.Add("@commercialStart", MySqlDbType.Date).Value = Date.Today.AddMonths(-12)
                    cmd.Parameters.Add("@commercialEnd", MySqlDbType.Date).Value = Date.Today.AddDays(1)
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            If reader.IsDBNull(0) OrElse reader.IsDBNull(1) Then Continue While
                            sold(Convert.ToInt32(reader.GetValue(0), CultureInfo.InvariantCulture)) = Convert.ToDecimal(reader.GetValue(1), CultureInfo.InvariantCulture)
                        End While
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("home-deal-progress", "Deal sold units unavailable. Error type: " & ex.GetType().Name & ".", Nothing, HttpContext.Current)
            Return False
        End Try
        pool.Columns("QtaVenduta").ReadOnly = False
        For Each row As DataRow In pool.Rows
            Dim units As Decimal = 0D
            If sold.TryGetValue(SafeInt(row("id")), units) AndAlso units > 0D Then row("QtaVenduta") = units Else row("QtaVenduta") = 0D
        Next
        Return True
    End Function

    ' Prima le occasioni che hanno vendite; dentro ciascun gruppo resta l'ordine ricevuto (regola commerciale e rotazione).
    Private Function PrioritizeSoldDeals(ByVal pool As DataTable) As DataTable
        If IsTableEmpty(pool) OrElse Not pool.Columns.Contains("QtaVenduta") Then Return pool
        Dim result As DataTable = pool.Clone()
        For Each wanted As Boolean In New Boolean() {True, False}
            For Each row As DataRow In pool.Rows
                If (ToDecimal(row("QtaVenduta")) > 0D) = wanted Then result.ImportRow(row)
            Next
        Next
        Return result
    End Function

    Private Function SortAuthorizedDealRows(ByVal source As DataTable, ByVal limit As Integer) As DataTable
        Dim result As DataTable = If(source IsNot Nothing, source.Clone(), EmptyProductsTable())
        If source Is Nothing OrElse source.Rows.Count = 0 OrElse limit <= 0 Then Return result

        Dim rows As New List(Of DataRow)()
        For Each row As DataRow In source.Rows
            rows.Add(row)
        Next

        rows.Sort(
            Function(left As DataRow, right As DataRow) As Integer
                Dim leftDeadline As Nullable(Of Date) = RowDateValue(left, "DisplayPromoDeadline")
                Dim rightDeadline As Nullable(Of Date) = RowDateValue(right, "DisplayPromoDeadline")
                If leftDeadline.HasValue <> rightDeadline.HasValue Then
                    Return If(leftDeadline.HasValue, -1, 1)
                End If
                If leftDeadline.HasValue Then
                    Dim byDeadline As Integer = Date.Compare(leftDeadline.Value, rightDeadline.Value)
                    If byDeadline <> 0 Then Return byDeadline
                End If

                Dim byVisits As Integer = SafeInt(right("Visite")).CompareTo(SafeInt(left("Visite")))
                If byVisits <> 0 Then Return byVisits
                Dim byId As Integer = SafeInt(right("id")).CompareTo(SafeInt(left("id")))
                If byId <> 0 Then Return byId
                Return SafeInt(left("TCid")).CompareTo(SafeInt(right("TCid")))
            End Function)

        For i As Integer = 0 To Math.Min(limit, rows.Count) - 1
            result.ImportRow(rows(i))
        Next
        Return result
    End Function

    Private Function GetNewArrivalsPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(NetStockSql() & ">=1 AND COALESCE(v.InOrdine,0)<=0 AND v.DataCreazione >= @homeNewStart AND v.DataCreazione < @homeTodayEnd",
                             "DataCreazione DESC, id DESC, TCid ASC",
                             limit, False, False, False, True)
    End Function

    Private Function GetIncomingPool(ByVal limit As Integer) As DataTable
        Return QueryProducts("COALESCE(v.InOrdine,0)>0",
                             "InOrdine DESC, id DESC, TCid ASC",
                             limit, False, True, False, True)
    End Function

    Private Function GetBestSellerPool(ByVal limit As Integer) As DataTable
        Return QueryProducts("COALESCE(ca.CommercialScore,0)>0",
                             "CommercialScore DESC, LastCommercialActivity DESC, id DESC, TCid ASC",
                             limit, False, False, True)
    End Function

    Private Function BuildHomeFiscalCompanyScopeSql() As String
        ' Only a formal Italian VAT identity can expand the scope; unknown formats stay local.
        ' Trim outer spaces and accept the standard IT prefix, never strip arbitrary characters.
        Dim rawVat As String = "TRIM(COALESCE(Piva,''))"
        Dim normalizedVat As String = "CASE WHEN ASCII(SUBSTRING(" & rawVat & ",1,1)) IN (73,105) AND ASCII(SUBSTRING(" & rawVat & ",2,1)) IN (84,116) THEN SUBSTRING(" & rawVat & ",3) ELSE " & rawVat & " END"
        Dim checksumTerms As New List(Of String)()
        For position As Integer = 1 To 10
            Dim digit As String = "CAST(SUBSTRING(currentFiscal.FiscalVat," & position.ToString(CultureInfo.InvariantCulture) & ",1) AS UNSIGNED)"
            If position Mod 2 = 0 Then
                checksumTerms.Add("CAST(SUBSTRING('0246813579'," & digit & "+1,1) AS UNSIGNED)")
            Else
                checksumTerms.Add(digit)
            End If
        Next
        ' UNION prevents counting the current company twice. No per-card query or shared cache.
        Return "SELECT @commercialCompany AS AziendaId UNION " &
               "SELECT peer.id AS AziendaId FROM (SELECT id," & normalizedVat & " AS FiscalVat FROM aziende) peer " &
               "INNER JOIN (SELECT " & normalizedVat & " AS FiscalVat FROM aziende WHERE id=@commercialCompany) currentFiscal " &
               "ON peer.FiscalVat=currentFiscal.FiscalVat " &
               "AND peer.id>0 AND CHAR_LENGTH(peer.FiscalVat)=11 AND peer.FiscalVat NOT REGEXP '[^0-9]' " &
               "WHERE CHAR_LENGTH(currentFiscal.FiscalVat)=11 AND currentFiscal.FiscalVat NOT REGEXP '[^0-9]' " &
               "AND currentFiscal.FiscalVat<>'00000000000' " &
               "AND MOD(10-MOD(" & String.Join("+", checksumTerms.ToArray()) & ",10),10)=CAST(SUBSTRING(currentFiscal.FiscalVat,11,1) AS UNSIGNED)"
    End Function

    Private Function BuildHomeCommercialActivitySql(Optional ByVal articleIdList As String = "") As String
        ' Ranking index, not certified sales. Fiscal scope affects only aggregate activity.
        ' The direction lookup is configuration, never the document's name or a type-ID list.
        Return "SELECT q.ArticoliId, GREATEST(SUM(q.QtaOrdini),SUM(q.QtaScarichi)) AS CommercialScore, MAX(q.LastActivity) AS LastCommercialActivity " &
               "FROM (SELECT dr.ArticoliId, dr.TCid, " &
               "SUM(CASE WHEN COALESCE(td.ImpegnaQnt,0)=1 THEN dr.Qnt ELSE 0 END) AS QtaOrdini, " &
               "SUM(CASE WHEN COALESCE(td.Segno,0)<0 THEN dr.Qnt ELSE 0 END) AS QtaScarichi, MAX(d.DataDocumento) AS LastActivity " &
               "FROM documentirighe dr INNER JOIN documenti d ON d.id=dr.DocumentiId " &
               "INNER JOIN tipodocumenti td ON td.id=d.TipoDocumentiId " &
               "INNER JOIN movimentitipo mt ON mt.id=td.MovimentiTipoId " &
               "LEFT JOIN documentistati ds ON ds.id=d.StatiId " &
               "INNER JOIN (" & BuildHomeFiscalCompanyScopeSql() & ") fiscalScope ON fiscalScope.AziendaId=d.AziendeId " &
               "WHERE @commercialCompany>0 " &
               "AND UPPER(TRIM(COALESCE(mt.Descrizione,'')))='USCITA' " &
               "AND (COALESCE(td.GestioneStato,0)=0 OR ds.id IS NOT NULL) AND (ds.id IS NULL OR (COALESCE(ds.Abilitato,0)=1 AND LOWER(TRIM(COALESCE(ds.Descrizione1,''))) NOT LIKE 'annull%')) " &
               "AND d.DataDocumento>=@commercialStart AND d.DataDocumento<@commercialEnd " &
               "AND COALESCE(dr.ArticoliId,0)>0 AND COALESCE(dr.Qnt,0)>0 AND COALESCE(dr.TipoRiga,'A')='A' " &
               If(String.IsNullOrEmpty(articleIdList), String.Empty, "AND dr.ArticoliId IN (" & articleIdList & ") ") &
               "AND (COALESCE(td.ImpegnaQnt,0)=1 OR COALESCE(td.Segno,0)<0) " &
               "AND NOT EXISTS (SELECT 1 FROM tipodocumenticontabili tc WHERE tc.TipoDocumentiId=td.id " &
               "AND (COALESCE(tc.NotaCreditoClienti,0)=1 OR COALESCE(tc.NotaCreditoFornitori,0)=1)) " &
               "GROUP BY dr.ArticoliId, dr.TCid) q GROUP BY q.ArticoliId"
    End Function

    Private Function TakeRankedHomeRows(ByVal count As Integer,
                                        ByVal usedBusinessKeys As HashSet(Of String),
                                        ByVal usedDisplayKeys As HashSet(Of String),
                                        ByVal source As DataTable) As DataTable
        Dim result As DataTable = If(source Is Nothing, EmptyProductsTable(), source.Clone())
        If source Is Nothing OrElse count <= 0 Then Return result
        Dim articles As New HashSet(Of Integer)()
        For Each row As DataRow In source.Rows
            Dim id As Integer = SafeInt(row("id"))
            If id <= 0 OrElse articles.Contains(id) OrElse ToDecimal(row("CommercialScore")) <= 0D Then Continue For
            Dim businessKey As String = GetBusinessKey(row)
            Dim displayKey As String = GetDisplayKey(row)
            If usedBusinessKeys.Contains(businessKey) OrElse usedDisplayKeys.Contains(displayKey) Then Continue For
            result.ImportRow(row)
            articles.Add(id)
            usedBusinessKeys.Add(businessKey)
            usedDisplayKeys.Add(displayKey)
            If result.Rows.Count >= count Then Exit For
        Next
        Return result
    End Function

    Private Function TakeHomeArrivalsRows(ByVal count As Integer,
                                          ByVal usedBusinessKeys As HashSet(Of String),
                                          ByVal usedDisplayKeys As HashSet(Of String),
                                          ByVal newRows As DataTable,
                                          ByVal incomingRows As DataTable) As DataTable
        Dim result As DataTable = CloneFirstTable(New DataTable() {newRows, incomingRows})
        result.Columns.Add("HomeMerchandisingLabel", GetType(String))
        result.Columns.Add("HomeInformativeOnly", GetType(Boolean))
        Dim pools() As DataTable = {newRows, incomingRows}
        Dim positions() As Integer = {0, 0}
        Dim articles As New HashSet(Of Integer)()
        Do While result.Rows.Count < count
            Dim added As Boolean = False
            For group As Integer = 0 To 1
                Dim pool As DataTable = pools(group)
                If pool Is Nothing Then Continue For
                While positions(group) < pool.Rows.Count AndAlso result.Rows.Count < count
                    Dim row As DataRow = pool.Rows(positions(group))
                    positions(group) += 1
                    Dim id As Integer = SafeInt(row("id"))
                    Dim businessKey As String = GetBusinessKey(row)
                    Dim displayKey As String = GetDisplayKey(row)
                    If id <= 0 OrElse articles.Contains(id) OrElse usedBusinessKeys.Contains(businessKey) OrElse usedDisplayKeys.Contains(displayKey) Then Continue While
                    result.ImportRow(row)
                    Dim selected As DataRow = result.Rows(result.Rows.Count - 1)
                    selected("HomeMerchandisingLabel") = If(group = 0, "Novità", "In arrivo")
                    selected("HomeInformativeOnly") = (group = 1 AndAlso
                        (ToDecimal(row("Giacenza")) <= 0D OrElse Not AvailabilityDisplayHelper.BuildFromDataItem(row, HttpContext.Current).IsAvailable))
                    articles.Add(id)
                    usedBusinessKeys.Add(businessKey)
                    usedDisplayKeys.Add(displayKey)
                    added = True
                    Exit While
                End While
            Next
            If Not added Then Exit Do
        Loop
        Return result
    End Function

    Private Function LoadHomeCatalogDiscovery(ByVal deals As DataTable,
                                              ByVal arrivals As DataTable,
                                              ByVal ranked As DataTable,
                                              ByVal recent As DataTable) As DataTable
        If Not IsTableEmpty(deals) OrElse Not IsTableEmpty(ranked) OrElse
           Not IsTableEmpty(recent) Then Return EmptyProductsTable()
        If IsTableEmpty(arrivals) Then Return GetCatalogFallbackPool(8)
        If Not HasOnlyInformativeHomeArrivals(arrivals) Then Return EmptyProductsTable()

        ' Reuse the authoritative pool once; never fetch extra rows to fill gaps.
        Dim pool As DataTable = GetCatalogFallbackPool(8)
        Dim result As DataTable = If(pool Is Nothing, EmptyProductsTable(), pool.Clone())
        If IsTableEmpty(pool) Then Return result

        Dim articleIds As New HashSet(Of Integer)()
        Dim businessKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim displayKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each row As DataRow In arrivals.Rows
            articleIds.Add(SafeInt(row("id")))
            businessKeys.Add(GetBusinessKey(row))
            displayKeys.Add(GetDisplayKey(row))
        Next
        For Each row As DataRow In pool.Rows
            Dim articleId As Integer = SafeInt(row("id"))
            Dim businessKey As String = GetBusinessKey(row)
            Dim displayKey As String = GetDisplayKey(row)
            If articleId <= 0 OrElse articleIds.Contains(articleId) OrElse
               businessKeys.Contains(businessKey) OrElse displayKeys.Contains(displayKey) Then Continue For
            result.ImportRow(row)
            articleIds.Add(articleId)
            businessKeys.Add(businessKey)
            displayKeys.Add(displayKey)
            If result.Rows.Count >= 8 Then Exit For
        Next
        Return result
    End Function

    Private Function HasOnlyInformativeHomeArrivals(ByVal arrivals As DataTable) As Boolean
        If IsTableEmpty(arrivals) OrElse Not arrivals.Columns.Contains("HomeInformativeOnly") OrElse
           Not arrivals.Columns.Contains("id") Then Return False
        For Each row As DataRow In arrivals.Rows
            If Not TypeOf row("HomeInformativeOnly") Is Boolean OrElse
               Not CBool(row("HomeInformativeOnly")) OrElse SafeInt(row("id")) <= 0 OrElse
               HasPromotionDisplayTechnicalError(row) Then Return False
        Next
        Return True
    End Function

    Private Function GetCatalogFallbackPool(ByVal limit As Integer) As DataTable
        If limit <= 0 Then Return EmptyProductsTable()
        ' Neutral selection only; images use the existing renderer/ThemeManager placeholder.
        Return QueryProducts(String.Empty, "DataCreazione DESC, Visite DESC, id DESC, TCid ASC",
                             Math.Min(8, limit), False, False, False, True, True)
    End Function

    Private Function QueryProducts(ByVal whereClause As String,
                                   ByVal orderClause As String,
                                   ByVal limit As Integer,
                                   Optional ByVal requireAuthorizedPromotion As Boolean = False,
                                   Optional ByVal allowIncoming As Boolean = False,
                                   Optional ByVal commercialRanking As Boolean = False,
                                   Optional ByVal onePerArticle As Boolean = False, Optional ByVal catalogDiscovery As Boolean = False) As DataTable
        Dim dt As DataTable = TryLoadProducts(whereClause, orderClause, limit, requireAuthorizedPromotion, allowIncoming, commercialRanking, onePerArticle, catalogDiscovery)
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

        Dim dt As DataTable = TryLoadProducts("v.id IN (" & idsCsv & ") AND " & NetStockSql() & ">=1", orderSql.ToString(), orderedIds.Count)
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

    Private Function TryLoadProducts(ByVal whereClause As String,
                                     ByVal orderClause As String,
                                     ByVal limit As Integer,
                                     Optional ByVal requireAuthorizedPromotion As Boolean = False,
                                     Optional ByVal allowIncoming As Boolean = False,
                                     Optional ByVal commercialRanking As Boolean = False,
                                     Optional ByVal onePerArticle As Boolean = False, Optional ByVal catalogDiscovery As Boolean = False) As DataTable
        Dim prezzoIvatoSql As String = StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression(
            "v.Prezzo", "v.PrezzoIvato", "v.IdIvaRC", "v.ValoreIvaRC",
            "@ksRcEnabled", "@ksHasVatOverride", "@ksVatOverride")
        Dim prezzoPromoIvatoSql As String = StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression(
            "v.PrezzoPromo", "v.PrezzoPromoIvato", "v.IdIvaRC", "v.ValoreIvaRC",
            "@ksRcEnabled", "@ksHasVatOverride", "@ksVatOverride")

        Dim stockSql As String = If(catalogDiscovery, "COALESCE(stk.Giacenza,0)", StockWhereClause())
        Dim reservedSql As String = If(catalogDiscovery, "COALESCE(stk.Impegnata,0)", ReservedWhereClause())
        ' Same net quantity as OrderInventoryAvailabilityService; the card initially requests one unit.
        Dim availableSql As String = If(catalogDiscovery,
            "GREATEST(0,COALESCE(stk.Giacenza,0)-COALESCE(stk.Impegnata,0))", AvailabilityWhereClause())
        Dim sql As New StringBuilder()
        sql.Append("SELECT ")
        sql.Append("v.id, COALESCE(v.TCid,-1) AS TCid, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, IFNULL(v.DescrizioneLunga,'') AS DescrizioneLunga, ")
        sql.Append("COALESCE(v.MarcheId,0) AS MarcheId, IFNULL(v.MarcheDescrizione,'') AS MarcheDescrizione, ")
        sql.Append("IFNULL(v.SettoriDescrizione,'') AS SettoriDescrizione, IFNULL(v.CategorieDescrizione,'') AS CategorieDescrizione, ")
        sql.Append("IFNULL(v.TipologieDescrizione,'') AS TipologieDescrizione, IFNULL(v.GruppiDescrizione,'') AS GruppiDescrizione, ")
        sql.Append("v.Img1, v.Img2, v.Img3, v.Img4, aBase.Img5, aBase.Img6, ")
        sql.Append("COALESCE(aBase.Abilitato,1) AS Abilitato, COALESCE(aBase.Abilitato,1) AS Attivo, ")
        sql.Append("COALESCE(v.Vetrina,0) AS Vetrina, COALESCE(v.DataCreazione,CURDATE()) AS DataCreazione, COALESCE(v.Visite,0) AS Visite, ")
        sql.Append("0 AS Stato, COALESCE(v.Ricondizionato,0) AS Ricondizionato, ")
        sql.Append(stockSql).Append(" AS Giacenza, ")
        sql.Append(availableSql).Append(" AS Disponibilita, ")
        sql.Append(reservedSql).Append(" AS Impegnata, ")
        sql.Append("COALESCE(v.InOrdine,0) AS InOrdine, ")
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
        If commercialRanking Then
            sql.Append("0 AS QtaVenduta, 0 AS VendutiAnno, ca.CommercialScore, ca.LastCommercialActivity, ")
            sql.Append("ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY COALESCE(v.TCid,-1) ASC) AS HomeVariantOrdinal ")
        Else
            sql.Append("0 AS QtaVenduta, 0 AS VendutiAnno, ")
            sql.Append("0 AS CommercialScore, NULL AS LastCommercialActivity")
            If onePerArticle Then
                sql.Append(", ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY COALESCE(v.TCid,-1) ASC) AS HomeVariantOrdinal")
            End If
            sql.Append(" ")
        End If
        sql.Append("FROM vsuperarticoli v ")
        sql.Append("INNER JOIN articoli aBase ON aBase.id = v.id ")
        If catalogDiscovery Then
            ' Web warehouse 1 and exact TCId match the existing inventory service.
            ' Missing or ambiguous stock identities fail closed; never borrow another variant/warehouse.
            sql.Append("INNER JOIN (SELECT ArticoliId, TCId, MAX(COALESCE(Giacenza,0)) AS Giacenza, MAX(COALESCE(Impegnata,0)) AS Impegnata ")
            sql.Append("FROM articoli_giacenze WHERE MagazziniId=1 GROUP BY ArticoliId, TCId HAVING COUNT(*)=1")
            sql.Append(") stk ON stk.ArticoliId=v.id AND stk.TCId=COALESCE(v.TCid,-1) ")
        Else
            sql.Append("LEFT JOIN (")
            sql.Append(" SELECT ArticoliId, SUM(COALESCE(Giacenza,0)) AS Giacenza, SUM(COALESCE(Disponibilita,0)) AS Disponibilita, SUM(COALESCE(Impegnata,0)) AS Impegnata")
            sql.Append(" FROM articoli_giacenze")
            sql.Append(" GROUP BY ArticoliId")
            sql.Append(") stk ON stk.ArticoliId = v.id ")
        End If
        If commercialRanking Then
            sql.Append("INNER JOIN (").Append(BuildHomeCommercialActivitySql()).Append(") ca ON ca.ArticoliId=v.id ")
        End If
        sql.Append("WHERE v.NListino=@listino AND COALESCE(v.id,0)>0 ")
        sql.Append("AND COALESCE(aBase.Abilitato,1)=1 ")
        sql.Append("AND COALESCE(v.Vetrina,0)=1 ")
        If catalogDiscovery Then
            sql.Append("AND ").Append(availableSql).Append(">=1 ")
            sql.Append("AND (COALESCE(v.TCid,-1)=-1 OR v.TCid>0) ")
        ElseIf allowIncoming Then
            sql.Append("AND (").Append(NetStockSql()).Append(">=1 OR COALESCE(v.InOrdine,0)>0) ")
        Else
            ' Tutte le vetrine mostrano solo articoli acquistabili ora (quantita netta), non la sola giacenza lorda.
            sql.Append("AND ").Append(NetStockSql()).Append(">=1 ")
        End If
        ' Filter the selected base unit price (the VAT mode of the request) before variant ranking/LIMIT, in EVERY pool: a promo price
        ' or the other VAT mode alone cannot qualify (it would give "Prezzo su richiesta" or hide a valid variant).
        sql.Append("AND ").Append(If(_priceDisplayContext.IsVatIncluded, prezzoIvatoSql, "COALESCE(v.Prezzo,0)")).Append(">0 ")
        If Not String.IsNullOrWhiteSpace(whereClause) Then
            sql.Append("AND ").Append(whereClause).Append(" ")
        End If
        If commercialRanking OrElse onePerArticle Then
            ' Choose a single eligible variant before the final ranking/LIMIT.
            Dim eligibleSql As String = sql.ToString()
            sql.Clear()
            sql.Append("SELECT * FROM (").Append(eligibleSql).Append(") homeChosen WHERE HomeVariantOrdinal=1 ")
        End If
        sql.Append("ORDER BY ").Append(orderClause).Append(" ")
        If limit > 0 Then
            sql.Append("LIMIT ").Append(limit.ToString(CultureInfo.InvariantCulture))
        End If

        Try
            Using lease As HomeQueryConnectionLease = AcquireHomeQueryLease()
                Dim conn As MySqlConnection = lease.Connection
                Using cmd As New MySqlCommand(sql.ToString(), conn)
                    cmd.Parameters.AddWithValue("@listino", GetCurrentListino())
                    cmd.Parameters.Add("@ksRcEnabled", MySqlDbType.Int32).Value = If(_priceDisplayContext.ReverseChargeEnabled, 1, 0)
                    cmd.Parameters.Add("@ksHasVatOverride", MySqlDbType.Int32).Value = If(_priceDisplayContext.VatOverride.HasValue, 1, 0)
                    cmd.Parameters.Add("@ksVatOverride", MySqlDbType.Decimal).Value = _priceDisplayContext.VatOverride.GetValueOrDefault()
                    If whereClause.Contains("@homeNewStart") Then
                        cmd.Parameters.Add("@homeNewStart", MySqlDbType.Date).Value = Date.Today.AddDays(-90)
                        cmd.Parameters.Add("@homeTodayEnd", MySqlDbType.Date).Value = Date.Today.AddDays(1)
                    End If
                    If commercialRanking Then
                        cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = GetCurrentAziendaId()
                        cmd.Parameters.Add("@commercialStart", MySqlDbType.Date).Value = Date.Today.AddMonths(-12)
                        cmd.Parameters.Add("@commercialEnd", MySqlDbType.Date).Value = Date.Today.AddDays(1)
                    End If
                    Using da As New MySqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        If conn.State <> ConnectionState.Open Then
                            Using HomeServerStageTiming.Measure(_homeTiming, "db.products.open")
                                conn.Open()
                            End Using
                        End If
                        Using HomeServerStageTiming.Measure(_homeTiming, "db.products.fill")
                            da.Fill(dt)
                        End Using
                        EnsurePromotionDisplayColumns(dt)
                        If requireAuthorizedPromotion Then
                            PopulatePromotionDisplaySnapshot(dt)
                            dt = FilterAuthorizedPromotionRows(dt)
                        End If
                        Return dt
                    End Using
                End Using
            End Using
        Catch ex As Exception
            InvalidateHomeQueryConnection()
            ReportHomeError("TryLoadProducts", ex)
        End Try

        Return Nothing
    End Function

    Private Sub PopulatePromotionDisplaySnapshot(ByVal products As DataTable)
        If products Is Nothing Then Return

        EnsurePromotionDisplayColumns(products)
        Dim listino As Integer = GetCurrentListino()
        Dim eligibilityContext As ProductPromotionEligibilityContext =
            ProductPromotionEligibilityResolver.CreateContext(HttpContext.Current, GetCurrentAziendaId(), listino)
        Dim useNetPrices As Boolean = _priceDisplayContext.IsVatExcluded

        For Each row As DataRow In products.Rows
            row("DisplayPromoSnapshotReady") = False
            row("DisplayPromoTechnicalError") = False
            ' Nessun valore residuo di una elaborazione precedente della stessa riga.
            row("DisplayPromoQtyOnePrice") = DBNull.Value
            row("DisplayPromoTierPrice") = DBNull.Value
            row("DisplayPromoTierQntMinima") = DBNull.Value
            row("DisplayPromoTierMultipli") = DBNull.Value
            row("DisplayPromoDeadline") = DBNull.Value
            Dim articleId As Integer = SafeInt(row("id"))
            Dim tcId As Integer = If(row.Table.Columns.Contains("TCid"), SafeInt(row("TCid")), -1)
            Dim model As ProductPromotionDisplayModel = GetHomePromotionModel(articleId,
                                                                               tcId,
                                                                               eligibilityContext,
                                                                               ToDecimal(row("Prezzo")),
                                                                               ToDecimal(row("PrezzoIvato")))

            If model IsNot Nothing AndAlso
               model.ResolutionState = ProductPromotionDisplayResolutionState.TechnicalError Then
                row("DisplayPromoTechnicalError") = True
                Continue For
            End If

            row("DisplayPromoSnapshotReady") = True

            If model IsNot Nothing AndAlso model.HasDefaultQuantityOffer Then
                row("DisplayPromoQtyOnePrice") = If(useNetPrices, model.BestDefaultQuantityPriceNet, model.BestDefaultQuantityPriceGross)
            End If
            If model IsNot Nothing AndAlso model.HasQuantityTierOffer Then
                row("DisplayPromoTierPrice") = If(useNetPrices, model.BestQuantityTierPriceNet, model.BestQuantityTierPriceGross)
                Dim tier As ProductPromotionOffer = model.Offers.Find(
                    Function(offer As ProductPromotionOffer) offer IsNot Nothing AndAlso
                                                               Not offer.AppliesToDefaultQuantity AndAlso
                                                               offer.PriceNet = model.BestQuantityTierPriceNet AndAlso
                                                               offer.OfferDetailId > 0)
                If tier IsNot Nothing Then
                    row("DisplayPromoTierQntMinima") = tier.QntMinima
                    row("DisplayPromoTierMultipli") = tier.Multipli
                End If
            End If

            ' La scadenza e quella dell'offerta che determina il prezzo mostrato (immediata), mai quella di un'altra offerta a quantita.
            If model IsNot Nothing Then
                Dim deadline As Nullable(Of Date) = Nothing
                If model.HasDefaultQuantityOffer Then
                    deadline = model.BestDefaultQuantityEndsOn
                ElseIf model.HasQuantityTierOffer Then
                    deadline = model.BestQuantityTierEndsOn
                End If
                If deadline.HasValue Then
                    row("DisplayPromoDeadline") = deadline.Value.Date
                End If
            End If
        Next
    End Sub

    Private Function GetHomePromotionModel(ByVal articleId As Integer,
                                           ByVal tcId As Integer,
                                           ByVal eligibilityContext As ProductPromotionEligibilityContext,
                                           ByVal baseNetPrice As Decimal,
                                           ByVal baseGrossPrice As Decimal) As ProductPromotionDisplayModel
        Dim contextKey As String = If(eligibilityContext Is Nothing, String.Empty, eligibilityContext.CacheKey)
        Dim cacheKey As String = articleId.ToString(CultureInfo.InvariantCulture) & ":" &
                                 tcId.ToString(CultureInfo.InvariantCulture) & ":" & contextKey & ":" &
                                 baseNetPrice.ToString(CultureInfo.InvariantCulture) & ":" &
                                 baseGrossPrice.ToString(CultureInfo.InvariantCulture) & ":" &
                                 _priceDisplayContext.IsVatExcluded.ToString(CultureInfo.InvariantCulture)
        Dim cached As ProductPromotionDisplayModel = Nothing
        If _homePromotionModelCache.TryGetValue(cacheKey, cached) Then Return cached

        Dim model As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(
            ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString,
            articleId,
            tcId,
            eligibilityContext,
            baseNetPrice,
            baseGrossPrice,
            _priceDisplayContext.IsVatExcluded)
        If model IsNot Nothing AndAlso
           model.ResolutionState <> ProductPromotionDisplayResolutionState.TechnicalError Then
            _homePromotionModelCache(cacheKey) = model
        End If
        Return model
    End Function

    Private Function FilterAuthorizedPromotionRows(ByVal products As DataTable) As DataTable
        Dim filtered As DataTable = If(products IsNot Nothing, products.Clone(), EmptyProductsTable())
        If products Is Nothing Then Return filtered
        ' Occasione Imperdibile: solo promozioni IMMEDIATE (quantita uno) con uno sconto significativo; un prezzo valido solo a quantita
        ' superiori o una differenza trascurabile non qualificano (restano visibili altrove con le loro condizioni).
        For Each row As DataRow In products.Rows
            If ShowDiscount(row) Then
                filtered.ImportRow(row)
            End If
        Next
        Return filtered
    End Function

    Private Sub EnsurePromotionDisplayColumns(ByVal products As DataTable)
        If Not products.Columns.Contains("DisplayPromoSnapshotReady") Then products.Columns.Add("DisplayPromoSnapshotReady", GetType(Boolean))
        If Not products.Columns.Contains("DisplayPromoTechnicalError") Then products.Columns.Add("DisplayPromoTechnicalError", GetType(Boolean))
        If Not products.Columns.Contains("DisplayPromoQtyOnePrice") Then products.Columns.Add("DisplayPromoQtyOnePrice", GetType(Decimal))
        If Not products.Columns.Contains("DisplayPromoTierPrice") Then products.Columns.Add("DisplayPromoTierPrice", GetType(Decimal))
        If Not products.Columns.Contains("DisplayPromoTierQntMinima") Then products.Columns.Add("DisplayPromoTierQntMinima", GetType(Decimal))
        If Not products.Columns.Contains("DisplayPromoTierMultipli") Then products.Columns.Add("DisplayPromoTierMultipli", GetType(Decimal))
        If Not products.Columns.Contains("DisplayPromoDeadline") Then products.Columns.Add("DisplayPromoDeadline", GetType(Date))
    End Sub

    Private Function RowDateValue(ByVal row As DataRow, ByVal columnName As String) As Nullable(Of Date)
        If row Is Nothing OrElse Not row.Table.Columns.Contains(columnName) OrElse row.IsNull(columnName) Then Return Nothing
        Dim parsed As Date
        If TryParseKeepStoreDate(row(columnName), parsed) Then Return parsed
        Return Nothing
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

    ' Quantita netta acquistabile: giacenza meno impegnata, la stessa che la scheda e l'etichetta "Non disponibile" leggono
    ' (OrderInventoryAvailabilityService.CalculateNetAvailableQuantity). Mai NULL: entrambe le espressioni hanno COALESCE a 0.
    Private Function NetStockSql() As String
        Return "(" & StockWhereClause() & "-" & ReservedWhereClause() & ")"
    End Function

    Private Function OfferWhereClause() As String
        ' Coarse candidate filter only; the authorized snapshot decides eligibility.
        Return "COALESCE(v.InOfferta,0)=1 AND " &
               "(v.OfferteDaListino IS NULL OR @listino >= v.OfferteDaListino) AND " &
               "(v.OfferteAListino IS NULL OR @listino <= v.OfferteAListino) AND " &
               NetStockSql() & ">=1"
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

    Private Function TakeDiverseRows(ByVal count As Integer,
                                     ByVal usedBusinessKeys As HashSet(Of String),
                                     ByVal usedDisplayKeys As HashSet(Of String),
                                     ParamArray ByVal sources() As DataTable) As DataTable
        Return CollectDistinctRows(count, usedBusinessKeys, usedDisplayKeys, True, True, True, sources)
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
        dt.Columns.Add("InOrdine", GetType(Decimal))
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
        dt.Columns.Add("DisplayPromoSnapshotReady", GetType(Boolean))
        dt.Columns.Add("DisplayPromoTechnicalError", GetType(Boolean))
        dt.Columns.Add("DisplayPromoQtyOnePrice", GetType(Decimal))
        dt.Columns.Add("DisplayPromoTierPrice", GetType(Decimal))
        dt.Columns.Add("DisplayPromoTierQntMinima", GetType(Decimal))
        dt.Columns.Add("DisplayPromoTierMultipli", GetType(Decimal))
        dt.Columns.Add("DisplayPromoDeadline", GetType(Date))
        dt.Columns.Add("OffertePrezzo", GetType(Decimal))
        dt.Columns.Add("OfferteSconto", GetType(Decimal))
        dt.Columns.Add("IdIvaRC", GetType(Integer))
        dt.Columns.Add("ValoreIvaRC", GetType(Decimal))
        dt.Columns.Add("QtaVenduta", GetType(Decimal))
        dt.Columns.Add("VendutiAnno", GetType(Decimal))
        dt.Columns.Add("CommercialScore", GetType(Decimal))
        dt.Columns.Add("LastCommercialActivity", GetType(Date))
        Return dt
    End Function

    Private Shared Function BuildHomeNavigationAssortmentSql() As String
        ' Ordinary catalog membership only; enabled menu sectors and usable brand logos are filtered later.
        Return "SELECT DISTINCT COALESCE(v.SettoriId,0) AS SectorId, COALESCE(v.CategorieId,0) AS CategoryId, m.id, m.Descrizione, m.img, m.link," &
               " COALESCE(m.Ordinamento,0) AS BrandOrder FROM vsuperarticoli v" &
               " LEFT JOIN marche m ON m.id=v.MarcheId AND COALESCE(m.Abilitato,1)=1" &
               " WHERE v.NListino=@listino ORDER BY BrandOrder, m.Descrizione, m.id"
    End Function

    ' Struttura dell'assortimento (settori, categorie, marchi) senza prezzi, giacenze, promozioni ne dati dell'utente: si memorizza per
    ' pochi minuti con chiave database + azienda + listino. Ogni richiesta riceve una COPIA; una lettura fallita non si memorizza
    ' (Nothing = errore di lettura, tavola vuota = assortimento letto e vuoto, esattamente come prima).
    Private Const HomeAssortmentCacheSeconds As Integer = 120

    Private Function LoadHomeNavigationAssortment() As DataTable
        Dim listino As Integer = 0
        Try
            listino = GetCurrentListino()
        Catch
            listino = 0
        End Try
        If listino <= 0 Then
            InvalidateHomeQueryConnection()
            ' Do not log connector errors, SQL text or installation/connection details.
            ReportHomeError("HomeNavigationAssortment", New InvalidOperationException("HOME_NAVIGATION_ASSORTMENT_READ_FAILED"))
            Return Nothing
        End If

        Dim snapshot As StorefrontCachedTable = StorefrontTenantScopedCache.GetOrLoad(Of StorefrontCachedTable)(
            "HomeAssortment",
            StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(),
            GetCurrentAziendaId(),
            listino.ToString(CultureInfo.InvariantCulture),
            HomeAssortmentCacheSeconds,
            Function() ReadHomeNavigationAssortment(listino))
        If snapshot Is Nothing Then Return Nothing
        Return snapshot.CopyTable()
    End Function

    Private Function ReadHomeNavigationAssortment(ByVal listino As Integer) As StorefrontCachedTable
        Try
            Using lease As HomeQueryConnectionLease = AcquireHomeQueryLease()
                Using cmd As New MySqlCommand(BuildHomeNavigationAssortmentSql(), lease.Connection)
                    cmd.Parameters.Add("@listino", MySqlDbType.Int32).Value = listino
                    Using adapter As New MySqlDataAdapter(cmd)
                        Dim result As New DataTable()
                        If lease.Connection.State <> ConnectionState.Open Then lease.Connection.Open()
                        adapter.Fill(result)
                        Return New StorefrontCachedTable(result)
                    End Using
                End Using
            End Using
        Catch
            InvalidateHomeQueryConnection()
            ' Do not log connector errors, SQL text or installation/connection details.
            ReportHomeError("HomeNavigationAssortment", New InvalidOperationException("HOME_NAVIGATION_ASSORTMENT_READ_FAILED"))
            Return Nothing
        End Try
    End Function

    Private Shared Function FilterHomeAssortmentSectors(ByVal source As List(Of CatalogMenuSector),
                                                       ByVal assortment As DataTable) As List(Of CatalogMenuSector)
        Dim result As New List(Of CatalogMenuSector)()
        If source Is Nothing Then Return result
        ' Nothing is a read failure; an empty table is a successfully read empty assortment.
        If assortment Is Nothing Then Return New List(Of CatalogMenuSector)(source)
        Dim present As New HashSet(Of Integer)()
        For Each row As DataRow In assortment.Rows
            Dim sectorId As Integer
            If Integer.TryParse(Convert.ToString(row("SectorId")), sectorId) AndAlso sectorId > 0 Then present.Add(sectorId)
        Next
        For Each sector As CatalogMenuSector In source
            If sector IsNot Nothing AndAlso present.Contains(sector.Id) Then result.Add(sector)
        Next
        Return result
    End Function

    Private Shared Function SelectHomeAssortmentBrands(ByVal assortment As DataTable) As DataTable
        If assortment Is Nothing Then Return New DataTable()
        Dim result As DataTable = assortment.Clone()
        Dim seen As New HashSet(Of Integer)()
        For Each row As DataRow In assortment.Rows
            Dim brandId As Integer
            If Integer.TryParse(Convert.ToString(row("id")), brandId) AndAlso brandId > 0 AndAlso seen.Add(brandId) Then result.ImportRow(row)
        Next
        Return result
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

    Private Function SafeTableQuery(ByVal sql As String,
                                    ByVal fallback As DataTable,
                                    Optional ByVal context As String = "SafeTableQuery",
                                    Optional ByVal parameters As IDictionary(Of String, Object) = Nothing) As DataTable
        Try
            Using lease As HomeQueryConnectionLease = AcquireHomeQueryLease()
                Dim conn As MySqlConnection = lease.Connection
                Using cmd As New MySqlCommand(sql, conn)
                    If parameters IsNot Nothing Then
                        For Each item As KeyValuePair(Of String, Object) In parameters
                            cmd.Parameters.AddWithValue(item.Key, item.Value)
                        Next
                    End If
                    Using da As New MySqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        If conn.State <> ConnectionState.Open Then
                            Using HomeServerStageTiming.Measure(_homeTiming, "db." & context & ".open")
                                conn.Open()
                            End Using
                        End If
                        Using HomeServerStageTiming.Measure(_homeTiming, "db." & context & ".fill")
                            da.Fill(dt)
                        End Using
                        If dt.Rows.Count > 0 Then
                            Return dt
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            InvalidateHomeQueryConnection()
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
        Return _priceDisplayContext.PriceListId
    End Function

    Private Function GetCurrentAziendaId() As Integer
        Dim value As Integer = 0
        If Session("AziendaID") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("AziendaID")), value) AndAlso value > 0 Then Return value
        If Session("AziendaId") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("AziendaId")), value) AndAlso value > 0 Then Return value
        If Session("AziendeId") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("AziendeId")), value) AndAlso value > 0 Then Return value
        Return 0
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

        Return StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, candidate)
    End Function

    Protected Function ProductImageThumb(ByVal value As Object) As String
        Return ThemeManager.ProductThumbnailImageUrl(value)
    End Function

    Private Function ResolveBrandImage(ByVal value As Object) As String
        Const publicRoot As String = "/Public/assets/images/marche/"
        Try
            Dim reference As String = Convert.ToString(value)
            For Each character As Char In reference
                If Char.IsControl(character) Then Return String.Empty
            Next
            reference = Uri.UnescapeDataString(reference.Trim()).Replace("\", "/")
            For Each character As Char In reference
                If Char.IsControl(character) Then Return String.Empty
            Next
            If reference.StartsWith("~/", StringComparison.Ordinal) Then reference = reference.Substring(1)
            If reference.StartsWith(publicRoot.TrimStart("/"c), StringComparison.OrdinalIgnoreCase) Then reference = "/" & reference

            Dim fileName As String = reference
            If reference.StartsWith(publicRoot, StringComparison.OrdinalIgnoreCase) Then fileName = reference.Substring(publicRoot.Length)
            If String.IsNullOrWhiteSpace(fileName) OrElse fileName.Length > 255 OrElse
               fileName.Contains("..") OrElse fileName.Contains("/") OrElse fileName.Contains("%") OrElse
               fileName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 OrElse
               Not IsApprovedBrandAsset(fileName) Then Return String.Empty

            Dim applicationRoot As String = Path.GetFullPath(HostingEnvironment.MapPath("~/")).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            Dim authorizedRoot As String = Path.GetFullPath(Path.Combine(applicationRoot, "Public", "assets", "images", "marche")) & Path.DirectorySeparatorChar
            Dim physicalPath As String = Path.GetFullPath(Path.Combine(authorizedRoot, fileName))
            If Not physicalPath.StartsWith(authorizedRoot, StringComparison.OrdinalIgnoreCase) OrElse
               Not File.Exists(physicalPath) Then Return String.Empty

            ' Reject filesystem redirects as well as URL/path escaping.
            Dim currentPath As String = physicalPath
            Do
                If (File.GetAttributes(currentPath) And FileAttributes.ReparsePoint) <> 0 Then Return String.Empty
                If String.Equals(currentPath, applicationRoot, StringComparison.OrdinalIgnoreCase) Then Exit Do
                currentPath = Path.GetDirectoryName(currentPath)
            Loop While Not String.IsNullOrEmpty(currentPath)

            Return publicRoot & Uri.EscapeDataString(fileName)
        Catch
            Return String.Empty
        End Try
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

    Private Function GetBasePrice(ByVal row As DataRow) As Decimal
        If row Is Nothing Then
            Return 0D
        End If

        Dim netPrice As Decimal = If(row.Table.Columns.Contains("Prezzo"), ToDecimal(row("Prezzo")), 0D)
        Dim grossPrice As Decimal = If(row.Table.Columns.Contains("PrezzoIvato"), ToDecimal(row("PrezzoIvato")), 0D)
        Return _priceDisplayContext.SelectPrice(netPrice, grossPrice).GetValueOrDefault()
    End Function

    ' Prezzo barrato, badge, "Risparmi" e qualifica per le offerte nascono tutti dalla STESSA regola, calcolata sui prezzi arrotondati
    ' come li legge il cliente (StorefrontPromotionDisplayPolicy). Il prezzo pagabile (CurrentPrice) non cambia mai.
    Private Function PromotionDisplay(ByVal row As DataRow) As StorefrontPromotionDisplay
        If row Is Nothing Then Return StorefrontPromotionDisplayPolicy.Resolve(0D, 0D)
        Return StorefrontPromotionDisplayPolicy.Resolve(GetBasePrice(row), CurrentPrice(row))
    End Function

    Private Function SavingsAmount(ByVal row As DataRow) As Decimal
        Return PromotionDisplay(row).Savings
    End Function

    Private Function ShowDiscount(ByVal row As DataRow) As Boolean
        Return PromotionDisplay(row).HasDiscount
    End Function

    Private Function DiscountPercent(ByVal row As DataRow) As Integer
        Return PromotionDisplay(row).Percent
    End Function

    Protected Function FormatMoney(ByVal value As Object) As String
        Dim amount As Decimal = ToDecimal(value)
        Return UiPriceFormatter.FormatStorefrontAmount(amount)
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

    Private Function TryGetValidPromoPrice(ByVal row As DataRow, ByRef promoPrice As Decimal) As Boolean
        promoPrice = 0D
        ' Solo lo snapshot autorevole (resolver delle promozioni): senza snapshot o con errore tecnico non c'e promozione, mai un ripiego
        ' sui prezzi promozionali della vista (che non controllano proprietario, azienda o NoPromo).
        If HasPromotionDisplayTechnicalError(row) OrElse Not HasPromotionDisplaySnapshot(row) Then Return False
        promoPrice = ToDecimal(row("DisplayPromoQtyOnePrice"))
        Return promoPrice > 0D
    End Function

    Private Function TryGetValidTierPrice(ByVal row As DataRow, ByRef promoPrice As Decimal) As Boolean
        promoPrice = 0D
        If HasPromotionDisplayTechnicalError(row) OrElse Not HasPromotionDisplaySnapshot(row) Then Return False
        promoPrice = ToDecimal(row("DisplayPromoTierPrice"))
        Return promoPrice > 0D
    End Function

    Private Function HasPromotionDisplaySnapshot(ByVal row As DataRow) As Boolean
        Return row IsNot Nothing AndAlso
               row.Table.Columns.Contains("DisplayPromoSnapshotReady") AndAlso
               Not row.IsNull("DisplayPromoSnapshotReady") AndAlso
               Convert.ToBoolean(row("DisplayPromoSnapshotReady"), CultureInfo.InvariantCulture)
    End Function

    Private Function HasPromotionDisplayTechnicalError(ByVal row As DataRow) As Boolean
        Return row IsNot Nothing AndAlso
               row.Table.Columns.Contains("DisplayPromoTechnicalError") AndAlso
               Not row.IsNull("DisplayPromoTechnicalError") AndAlso
               Convert.ToBoolean(row("DisplayPromoTechnicalError"), CultureInfo.InvariantCulture)
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
        If Not HasPromotionDisplaySnapshot(row) OrElse Not row.Table.Columns.Contains("DisplayPromoDeadline") OrElse row.IsNull("DisplayPromoDeadline") Then Return False
        deadline = Convert.ToDateTime(row("DisplayPromoDeadline"), CultureInfo.InvariantCulture).Date.AddDays(1)
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

    Private Function CardCategoryLabel(ByVal row As DataRow) As String
        If row Is Nothing Then
            Return String.Empty
        End If

        Dim candidates As String() = {
            If(row.Table.Columns.Contains("TipologieDescrizione"), Convert.ToString(row("TipologieDescrizione")).Trim(), String.Empty),
            If(row.Table.Columns.Contains("CategorieDescrizione"), Convert.ToString(row("CategorieDescrizione")).Trim(), String.Empty),
            If(row.Table.Columns.Contains("SettoriDescrizione"), Convert.ToString(row("SettoriDescrizione")).Trim(), String.Empty)
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
        Dim img As String = StorefrontProductImageSlots.CoverUrl(row)
        Dim current As Decimal = CurrentPrice(row)
        Dim priceText As String = If(current > 0D, FormatMoney(current), "Prezzo su richiesta")
        Dim availableText As String = AvailabilityDisplayHelper.BuildText(row, HttpContext.Current)
        Dim description As String = QuickViewDescription(row)

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
        sb.Append(" data-ks-available='").Append(EncodeAttr(availableText)).Append("'")
        sb.Append(" data-ks-cart-url='").Append(EncodeAttr(CartAddUrl(row))).Append("'")
        sb.Append(" data-ks-description='").Append(EncodeAttr(description)).Append("'")
        Return sb.ToString()
    End Function

    Private Function ProductGalleryImages(ByVal row As DataRow) As List(Of String)
        Return StorefrontProductImageSlots.FromDataItem(row)
    End Function

    Private Function RenderActionButtons(ByVal row As DataRow, ByVal compact As Boolean) As String
        If row Is Nothing Then Return String.Empty

        Dim quickViewAttrs As String = BuildQuickViewAttributes(row)
        Dim compareAttrs As String = quickViewAttrs
        Dim buttonClass As String = If(compact, "list-product-btn flex-row", "list-product-btn top-0 end-0")
        Dim tooltipClass As String = If(compact, "hover-tooltip", "hover-tooltip tooltip-left")
        Dim articleId As Integer = 0
        Integer.TryParse(Convert.ToString(row("id")), articleId)
        Dim tcId As Integer = -1
        If row.Table.Columns.Contains("TCid") Then Integer.TryParse(Convert.ToString(row("TCid")), tcId)
        If tcId <= 0 Then tcId = -1
        Dim requestId As String = CartMutationIdempotencyService.CreateRequestId()
        Dim nativeAction As String = CartMutationIdempotencyService.BuildNativeActionValue(articleId, tcId, 1D, requestId)

        Dim sb As New StringBuilder()
        sb.Append("<ul class='").Append(buttonClass).Append("'>")
        sb.Append("<li><button type='submit' form='ksNativeCartForm' name='ksCartAction' value='").Append(EncodeAttr(nativeAction)).Append("' class='box-icon add-to-cart btn-icon-action ").Append(tooltipClass).Append(" ks-home-top-buy-action js-ks-cart-link'").Append(quickViewAttrs).Append(" data-ks-request-id='").Append(EncodeAttr(requestId)).Append("' aria-label='Acquista: aggiungi al carrello' title='Acquista: aggiungi al carrello'><span class='icon icon-cart-2' aria-hidden='true'></span><span class='tooltip d-none d-lg-block'>Acquista</span></button></li>")
        sb.Append("<li class='wishlist'><a href='").Append(WishlistAddUrl(row("id"))).Append("' class='box-icon btn-icon-action ").Append(tooltipClass).Append(" js-ks-wishlist-link'").Append(quickViewAttrs).Append(" aria-label='Wishlist'><i class='icon icon-heart2'></i><span class='tooltip'>Wishlist</span></a></li>")
        sb.Append("<li><a href='#quickView' data-bs-toggle='modal' class='box-icon quickview btn-icon-action ").Append(tooltipClass).Append(" js-ks-quickview'").Append(quickViewAttrs).Append(" aria-label='Vedi prodotto'><i class='icon icon-view'></i><span class='tooltip'>Vedi prodotto</span></a></li>")
        sb.Append("<li><a href='#compare' data-bs-toggle='offcanvas' data-bs-target='#compare' aria-controls='compare' class='box-icon btn-icon-action ").Append(tooltipClass).Append(" js-ks-compare'").Append(compareAttrs).Append(" aria-label='Confronta'><i class='icon icon-compare1'></i><span class='tooltip'>Confronta</span></a></li>")
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Function RenderSaleBadge(ByVal row As DataRow) As String
        If row Is Nothing Then Return String.Empty

        Dim tierPrice As Decimal = 0D
        Dim hasImmediateDiscount As Boolean = ShowDiscount(row)
        Dim hasQuantityTier As Boolean = TryGetValidTierPrice(row, tierPrice)
        If Not hasImmediateDiscount AndAlso Not hasQuantityTier Then Return String.Empty

        Dim discountPercentValue As Integer = DiscountPercent(row)
        Dim badgeText As String = If(hasImmediateDiscount,
                                     If(discountPercentValue > 0,
                                        "-" & discountPercentValue.ToString(ItCulture) & "%",
                                        "Offerta"),
                                     "Quantità")

        Return "<div class='box-sale-wrap top-0 start-0 pst-default z-5'><p class='small-text'>Promo</p><p class='title-sidebar-2'>" &
               badgeText &
               "</p></div>"
    End Function

    Private Function RenderRefurbishedBadge(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not IsRefurbished(row) Then
            Return String.Empty
        End If

        Return "<div class='badge-refurbished'><img src='/Public/assets/images/img/refurbished.png' alt='Ricondizionato'></div>"
    End Function

    Private Function RenderCornerBadgeStack(ByVal row As DataRow,
                                            ByVal includeSale As Boolean) As String
        If row Is Nothing Then Return String.Empty

        Dim badges As New StringBuilder()
        If includeSale Then
            badges.Append(RenderSaleBadge(row))
        End If
        badges.Append(RenderRefurbishedBadge(row))

        If badges.Length = 0 Then Return String.Empty
        Return "<div class='ks-home-corner-badge-stack'>" & badges.ToString() & "</div>"
    End Function

    Private Function RenderPriceBlock(ByVal row As DataRow,
                                      ByVal emphasize As Boolean,
                                      Optional ByVal reserveDealSlots As Boolean = False) As String
        Dim sb As New StringBuilder()
        Dim priceClass As String = If(emphasize, "new-price h4 fw-semibold text-primary mb-0", "new-price body-md-2 mb-0") & " ks-home-price-value ks-home-price-value--current"
        Dim oldPriceClass As String = If(emphasize, "old-price price-text text-main-2", "old-price body-md-2 text-main-2") & " ks-home-price-value ks-home-price-value--old"
        Dim slotClass As String = If(emphasize, "ks-home-price-slot--emphasized", "ks-home-price-slot--compact")
        Dim stackClass As String = If(emphasize, "ks-home-price-stack--emphasized", "ks-home-price-stack--compact")
        Dim tierHtml As String = RenderTierPrice(row)

        sb.Append("<div class='ks-home-price-stack ").Append(stackClass).Append("'>")
        If reserveDealSlots Then sb.Append("<div class='ks-deal-price-amount-slot'>")
        sb.Append("<p class='price-wrap fw-medium ks-home-price-slot ").Append(slotClass).Append("'>")
        Dim current As Decimal = CurrentPrice(row)
        sb.Append("<span class='").Append(priceClass).Append("'>").Append(If(StorefrontPromotionDisplayPolicy.RoundMoney(current) > 0D, FormatMoney(current), "Prezzo su richiesta")).Append("</span>")
        If ShowDiscount(row) Then
            sb.Append("<span class='").Append(oldPriceClass).Append("'>").Append(FormatMoney(GetBasePrice(row))).Append("</span>")
        End If
        sb.Append("</p>")
        If reserveDealSlots Then
            sb.Append("</div>")
            sb.Append("<div class='ks-deal-price-tier-slot'")
            If String.IsNullOrEmpty(tierHtml) Then sb.Append(" aria-hidden='true'")
            sb.Append(">").Append(tierHtml).Append("</div>")
        Else
            sb.Append(tierHtml)
        End If
        sb.Append("</div>")

        Return sb.ToString()
    End Function

    Private Function RenderTierPrice(ByVal row As DataRow) As String
        Dim tierPrice As Decimal = 0D
        If Not TryGetValidTierPrice(row, tierPrice) Then Return String.Empty

        Dim qntMinima As Decimal = ToDecimal(row("DisplayPromoTierQntMinima"))
        Dim multipli As Decimal = ToDecimal(row("DisplayPromoTierMultipli"))
        Dim condition As String = If(qntMinima > 0D,
                                     "Minimo " & FormatQuantity(qntMinima) & " pz.",
                                     "Multipli " & FormatQuantity(multipli) & " pz.")

        Return "<p class='caption text-main-2 mb-0 ks-home-promo-tier'>Da <strong>" &
               HttpUtility.HtmlEncode(FormatMoney(tierPrice)) &
               "</strong> - " & HttpUtility.HtmlEncode(condition) & "</p>"
    End Function

    Private Function RenderAvailability(ByVal row As DataRow) As String
        If row Is Nothing Then Return String.Empty
        Return AvailabilityDisplayHelper.BuildHtml(row, HttpContext.Current)
    End Function

    Private Const DealSoldUnitsMaxArticles As Integer = 400
    Private Const DealProgressHeading As String = "Venduti negli ultimi 12 mesi"

#Region "DealProgressPure"
    ' Percentuale della barra: venduti / (venduti + disponibili netti). Zero venduti = nessuna barra (0).
    ' exact = True solo per chi puo vedere i numeri di giacenza: valore intero fra 1 e 99.
    ' exact = False (ospiti e vista sintetica): gradini di 10 punti fra 10 e 90, cosi dalla barra non si ricava la giacenza.
    Friend Shared Function DealProgressPercent(ByVal sold As Decimal, ByVal available As Decimal, ByVal exact As Boolean) As Integer
        If sold <= 0D Then Return 0
        Dim stock As Decimal = Math.Max(0D, available)
        Dim raw As Decimal = (100D * sold) / (sold + stock)
        If exact Then
            If stock <= 0D Then Return 100
            Return CInt(Math.Max(1D, Math.Min(99D, Math.Floor(raw))))
        End If
        Dim stepped As Integer = CInt(Math.Round(raw / 10D, MidpointRounding.AwayFromZero)) * 10
        Return Math.Max(10, Math.Min(90, stepped))
    End Function

    ' Quantita mostrata: numero intero (le frazioni si troncano), separatore delle migliaia italiano.
    Friend Shared Function DealProgressUnits(ByVal value As Decimal) As String
        Dim whole As Decimal = Math.Floor(Math.Max(0D, value))
        Return whole.ToString("#,##0", System.Globalization.CultureInfo.GetCultureInfo("it-IT"))
    End Function
#End Region

    ' Barra delle vendite dell'occasione. Compare SOLO con venduti reali maggiori di zero; i numeri di disponibilita e la percentuale
    ' esatta solo a chi puo vedere i numeri di giacenza (AvailabilityDisplayModel.DisplayMode = 2).
    Private Function RenderDealProgress(ByVal row As DataRow) As String
        If row Is Nothing OrElse Not row.Table.Columns.Contains("QtaVenduta") Then Return String.Empty
        Dim sold As Decimal = Math.Floor(ToDecimal(row("QtaVenduta")))
        If sold <= 0D Then Return String.Empty
        Dim model As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItem(row, HttpContext.Current)
        If model Is Nothing Then Return String.Empty
        Dim exact As Boolean = model.DisplayMode = 2
        Dim available As Decimal = Math.Max(0D, model.AvailableQty)
        Dim percent As Integer = DealProgressPercent(sold, available, exact)
        If percent <= 0 Then Return String.Empty
        Dim percentText As String = percent.ToString(CultureInfo.InvariantCulture)
        Dim soldText As String = DealProgressUnits(sold)
        Dim productName As String = HttpUtility.HtmlDecode(Convert.ToString(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))))
        Dim valueText As String = If(exact,
            percentText & "% venduto: " & soldText & " venduti, " & DealProgressUnits(available) & " disponibili",
            soldText & " venduti negli ultimi 12 mesi")
        Dim sb As New StringBuilder()
        sb.Append("<div class='product-progress-sale ks-deal-slot ks-deal-slot--progress ks-deal-progress'>")
        sb.Append("<div class='ks-deal-progress__head'><span>").Append(DealProgressHeading).Append("</span>")
        If exact Then sb.Append("<strong>").Append(percentText).Append("%</strong>")
        sb.Append("</div>")
        sb.Append("<div class='progress-sold progress ks-deal-progress__track' role='progressbar' aria-valuemin='0' aria-valuemax='100' aria-valuenow='").Append(percentText)
        sb.Append("' aria-valuetext='").Append(EncodeAttr(valueText)).Append("' aria-label='").Append(EncodeAttr("Vendite di " & productName)).Append("'>")
        sb.Append("<div class='progress-bar ks-deal-progress__bar' style='width:").Append(percentText).Append("%'></div>")
        sb.Append("</div>")
        sb.Append("<div class='box-quantity ks-deal-progress__numbers'>")
        sb.Append("<p class='text-avaiable caption'>Venduti: <span class='fw-bold'>").Append(soldText).Append("</span></p>")
        If exact Then sb.Append("<p class='text-avaiable caption'>Disponibili: <span class='fw-bold'>").Append(DealProgressUnits(available)).Append("</span></p>")
        sb.Append("</div>")
        sb.Append("</div>")
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
        sb.Append("<img class='lazyload img-product' decoding='async' src='").Append(EncodeAttr(StorefrontProductImageSlots.CoverUrl(row))).Append("' data-src='").Append(EncodeAttr(StorefrontProductImageSlots.CoverUrl(row))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("' />")
        sb.Append("</a>")
        sb.Append(RenderActionButtons(row, False))
        sb.Append(RenderCornerBadgeStack(row, True))
        sb.Append("</div>")
        sb.Append("</div>")
        Dim galleryImages As List(Of String) = ProductGalleryImages(row)
        sb.Append("<div class='ks-deal-slot ks-deal-slot--gallery'")
        If galleryImages.Count = 0 Then sb.Append(" aria-hidden='true'")
        sb.Append(">")
        If galleryImages.Count > 0 Then
            sb.Append("<ul class='list-image-product ks-deal-thumbs'>")
            For i As Integer = 0 To galleryImages.Count - 1
                sb.Append("<li class='image-swap")
                If i = 0 Then sb.Append(" active")
                sb.Append("'><img class='lazyload' loading='lazy' decoding='async' src='").Append(EncodeAttr(galleryImages(i))).Append("' data-src='").Append(EncodeAttr(galleryImages(i))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append(" anteprima ").Append((i + 1).ToString(CultureInfo.InvariantCulture)).Append("'></li>")
            Next
            sb.Append("</ul>")
        End If
        sb.Append("</div>")

        Dim availabilityHtml As String = RenderAvailability(row)
        Dim countdownHtml As String = RenderCountdownBlock(row)
        Dim savingsHtml As String = String.Empty
        If ShowDiscount(row) Then
            savingsHtml = "<p class='box-sale-tag'>Risparmi " & FormatMoney(SavingsAmount(row)) & "</p>"
        End If

        sb.Append("<div class='card-product-info box-title gap-xl-12 ks-deal-card__content'>")
        sb.Append("<div class='ks-deal-slot ks-deal-slot--category'>")
        sb.Append("<p class='caption text-main-2 font-2 ks-card-category'>").Append(CardCategoryLabel(row)).Append("</p>")
        sb.Append("</div>")
        sb.Append("<div class='ks-deal-slot ks-deal-slot--title'>")
        sb.Append("<h6><a href='").Append(ProductUrl(row("id"))).Append("' class='name-product fw-semibold text-secondary link ks-card-title'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></h6>")
        sb.Append("</div>")
        sb.Append("<div class='ks-deal-slot ks-deal-slot--price'>").Append(RenderPriceBlock(row, True, True)).Append("</div>")
        sb.Append("<div class='ks-deal-slot ks-deal-slot--availability'")
        If String.IsNullOrEmpty(availabilityHtml) Then sb.Append(" aria-hidden='true'")
        sb.Append(">").Append(availabilityHtml).Append("</div>")
        sb.Append("<div class='ks-deal-slot ks-deal-slot--savings'")
        If String.IsNullOrEmpty(savingsHtml) Then sb.Append(" aria-hidden='true'")
        sb.Append(">").Append(savingsHtml).Append("</div>")
        Dim progressHtml As String = RenderDealProgress(row)
        If Not String.IsNullOrEmpty(countdownHtml) OrElse Not String.IsNullOrEmpty(progressHtml) Then
            sb.Append("<div class='box-infor-detail gap-xl-20 ks-deal-card__footer'>")
            If Not String.IsNullOrEmpty(countdownHtml) Then sb.Append("<div class='ks-deal-slot ks-deal-slot--countdown'>").Append(countdownHtml).Append("</div>")
            sb.Append(progressHtml)
            sb.Append("</div>")
        End If
        sb.Append("</div>")
        sb.Append("</div>")
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
        sb.Append("<img class='img-product lazyload' decoding='async' src='").Append(EncodeAttr(StorefrontProductImageSlots.CoverUrl(row))).Append("' data-src='").Append(EncodeAttr(StorefrontProductImageSlots.CoverUrl(row))).Append("' alt='").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("'>")
        sb.Append("<img class='img-hover lazyload' loading='lazy' decoding='async' src='").Append(EncodeAttr(ProductImageThumb(StorefrontProductImageSlots.HoverUrl(row)))).Append("' data-src='").Append(EncodeAttr(ProductImageThumb(StorefrontProductImageSlots.HoverUrl(row)))).Append("' alt='' aria-hidden='true'>")
        sb.Append("</a>")
        Dim informativeOnly As Boolean = row.Table.Columns.Contains("HomeInformativeOnly") AndAlso
                                       Not IsDBNull(row("HomeInformativeOnly")) AndAlso Convert.ToBoolean(row("HomeInformativeOnly"))
        If Not informativeOnly Then sb.Append(RenderActionButtons(row, False))
        sb.Append(RenderCornerBadgeStack(row, True))
        sb.Append("</div>")
        sb.Append("<div class='card-product-info'>")
        ' L'etichetta «Novità» / «In arrivo» e una piccola targhetta davanti alla categoria, nel flusso del testo: non copre la foto
        ' e non prende una riga intera della card. Solo le due parole ammesse, sempre codificate.
        Dim merchandisingTag As String = String.Empty
        If row.Table.Columns.Contains("HomeMerchandisingLabel") Then
            Dim label As String = Convert.ToString(row("HomeMerchandisingLabel"))
            If label = "Novità" OrElse label = "In arrivo" Then
                merchandisingTag = "<span class='ks-card-tag'>" & HttpUtility.HtmlEncode(label) & "</span>"
            End If
        End If
        sb.Append("<div class='box-title'>")
        sb.Append("<div class='bg-white relative z-5'><p class='caption text-main-2 font-2 ks-card-category'>").Append(merchandisingTag).Append(CardCategoryLabel(row)).Append("</p>")
        sb.Append("<a href='").Append(ProductUrl(row("id"))).Append("' class='name-product body-md-2 fw-semibold text-secondary link ks-card-title'>").Append(ProductTitle(row("Descrizione1"), row("Descrizione2"), row("id"))).Append("</a></div>")
        sb.Append(RenderPriceBlock(row, False))
        sb.Append(RenderAvailability(row))
        sb.Append("</div>")
        sb.Append("</div></div>")
        Return sb.ToString()
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
