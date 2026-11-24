Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

' Listino e offerte da scaricare (CATALOG-DOWNLOAD-1A). Una sola lettura per l'utente collegato: gli stessi importi della scheda del catalogo
' (prezzo base con override IVA anche a zero e reverse charge, offerte del batch condiviso con quelle riservate all'utente, quantita 1).
' Mai le colonne PrezzoPromo/InOfferta della vista (non filtrano utente ne stato). Nessuna cache fra utenti: lo snapshot vive solo per la richiesta.
' Una riga coerente per articolo con la stessa regola del catalogo (ROW_NUMBER su articolo, variante positiva prima). Il file non e indicizzabile ne persistito.

Public Enum CatalogExportStatus
    Ready = 0
    NotAuthenticated = 1
    InvalidContext = 2
    TechnicalError = 3
End Enum

Public NotInheritable Class CatalogExportRow
    Public ReadOnly ArticleId As Integer
    Public ReadOnly TcId As Integer
    Public ReadOnly Code As String
    Public ReadOnly Ean As String
    Public ReadOnly Description As String
    Public ReadOnly Detail As String
    Public ReadOnly SectorKey As String
    Public ReadOnly SectorName As String
    Public ReadOnly CategoryKey As String
    Public ReadOnly CategoryName As String
    Public ReadOnly TypeKey As String
    Public ReadOnly TypeName As String
    Public ReadOnly GroupKey As String
    Public ReadOnly GroupName As String
    Public ReadOnly ImageFiles As String()
    Public ReadOnly HasPrice As Boolean
    Public ReadOnly Price As Decimal
    Public ReadOnly ListPrice As Decimal
    Public ReadOnly ShowsDiscount As Boolean
    Public ReadOnly OfferEndsOn As Nullable(Of Date)
    Public ReadOnly OfferLabel As String
    Public ReadOnly TierNote As String
    Public ReadOnly ProductUrl As String
    ' 0 = disponibile (verde), 1 = pochi pezzi o in arrivo (giallo), 2 = non disponibile (rosso): stessa regola della scheda del sito.
    Public ReadOnly AvailabilityTone As Integer
    Public ReadOnly AvailabilityText As String

    Public Sub New(ByVal articleId As Integer, ByVal tcId As Integer, ByVal code As String, ByVal ean As String,
                   ByVal description As String, ByVal detail As String,
                   ByVal sectorKey As String, ByVal sectorName As String, ByVal categoryKey As String, ByVal categoryName As String, ByVal typeKey As String, ByVal typeName As String,
                   ByVal groupKey As String, ByVal groupName As String, ByVal imageFiles As String(),
                   ByVal hasPrice As Boolean, ByVal price As Decimal, ByVal listPrice As Decimal, ByVal showsDiscount As Boolean,
                   ByVal offerEndsOn As Nullable(Of Date), ByVal offerLabel As String, ByVal tierNote As String, ByVal productUrl As String,
                   ByVal availabilityTone As Integer, ByVal availabilityText As String)
        Me.ArticleId = articleId
        Me.TcId = tcId
        Me.Code = code
        Me.Ean = ean
        Me.Description = description
        Me.Detail = detail
        Me.SectorKey = sectorKey
        Me.SectorName = sectorName
        Me.CategoryKey = categoryKey
        Me.CategoryName = categoryName
        Me.TypeKey = typeKey
        Me.TypeName = typeName
        Me.GroupKey = groupKey
        Me.GroupName = groupName
        Me.ImageFiles = imageFiles
        Me.HasPrice = hasPrice
        Me.Price = price
        Me.ListPrice = listPrice
        Me.ShowsDiscount = showsDiscount
        Me.OfferEndsOn = offerEndsOn
        Me.OfferLabel = offerLabel
        Me.TierNote = tierNote
        Me.ProductUrl = productUrl
        Me.AvailabilityTone = availabilityTone
        Me.AvailabilityText = availabilityText
    End Sub

    Public ReadOnly Property IsOffer As Boolean
        Get
            Return HasPrice AndAlso (ShowsDiscount OrElse Not String.IsNullOrEmpty(OfferLabel) OrElse Not String.IsNullOrEmpty(TierNote))
        End Get
    End Property
End Class

Public NotInheritable Class CatalogExportSnapshot
    Public ReadOnly Status As CatalogExportStatus
    Public ReadOnly Rows As List(Of CatalogExportRow)
    Public ReadOnly PriceLabel As String
    Public ReadOnly CompanyName As String
    Public ReadOnly GeneratedOn As Date
    Public ReadOnly PriceUnavailableCount As Integer
    Public ReadOnly Company As CatalogExportCompany

    Public Sub New(ByVal status As CatalogExportStatus, ByVal rows As List(Of CatalogExportRow), ByVal priceLabel As String,
                   ByVal companyName As String, ByVal generatedOn As Date, ByVal priceUnavailableCount As Integer,
                   Optional ByVal company As CatalogExportCompany = Nothing)
        Me.Status = status
        Me.Rows = rows
        Me.PriceLabel = priceLabel
        Me.CompanyName = companyName
        Me.GeneratedOn = generatedOn
        Me.PriceUnavailableCount = priceUnavailableCount
        Me.Company = company
    End Sub
End Class

' Dati aziendali della prima pagina: solo cio che l'azienda dell'host ha gia pubblicato nel sito (stessa identita del piede della pagina).
Public NotInheritable Class CatalogExportCompany
    Public ReadOnly Name As String
    Public ReadOnly LegalName As String
    Public ReadOnly VatNumber As String
    Public ReadOnly RegisteredOffice As String
    Public ReadOnly OperationalOffice As String
    Public ReadOnly Phone As String
    Public ReadOnly Email As String
    Public ReadOnly Website As String
    Public ReadOnly LogoFile As String

    Public Sub New(ByVal name As String, ByVal legalName As String, ByVal vatNumber As String, ByVal registeredOffice As String,
                   ByVal operationalOffice As String, ByVal phone As String, ByVal email As String, ByVal website As String, ByVal logoFile As String)
        Me.Name = name
        Me.LegalName = legalName
        Me.VatNumber = vatNumber
        Me.RegisteredOffice = registeredOffice
        Me.OperationalOffice = operationalOffice
        Me.Phone = phone
        Me.Email = email
        Me.Website = website
        Me.LogoFile = logoFile
    End Sub
End Class

Public NotInheritable Class CatalogExportSnapshotProvider
    Private Sub New()
    End Sub

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    ' Stessa regola di scelta della riga del catalogo (articoli.aspx.vb, BuildCatalogRowRankSql): variante positiva prima.
    Friend Const RowRankSql As String =
        " ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY" &
        " CASE WHEN COALESCE(v.TCid,0)>0 THEN 0 ELSE 1 END," &
        " COALESCE(v.TCid,-1),COALESCE(v.ArticoliListiniId,0)," &
        " COALESCE(v.OfferteDettagliId,0)) AS CatalogRowRank"

    Friend Const ListingSql As String =
        "SELECT x.* FROM (SELECT v.id AS ArticleId,COALESCE(NULLIF(v.TCid,0),-1) AS TCId,v.Codice,v.Ean,v.Descrizione1,v.Descrizione2," &
        "v.SettoriId,v.SettoriDescrizione,v.SettoriOrdINamento,v.CategorieId,v.CategorieDescrizione,v.CategorieOrdiNAmento,v.TipologieId,v.TipologieDescrizione,v.TipologieOrdinamento," &
        "v.GruppiId,v.GruppiDEscrizione,v.GruppiOrdinamento,v.Img1,v.Img2,v.Img3,v.Img4,v.Prezzo,v.PrezzoIvato,v.IdIvaRC,v.ValoreIvaRC,v.Giacenza,v.Disponibilita,v.Impegnata,v.InOrdine,v.ScortaMinima," &
        RowRankSql &
        " FROM vsuperarticoli v INNER JOIN articoli a ON a.id=v.id" &
        " WHERE v.NListino=@listino AND COALESCE(a.Abilitato,0)=1 AND COALESCE(v.Export,0)<>0) x" &
        " WHERE x.CatalogRowRank=1" &
        " ORDER BY (x.SettoriId IS NULL OR x.SettoriId<=0),COALESCE(x.SettoriOrdINamento,0),x.SettoriDescrizione,x.SettoriId," &
        "(x.CategorieId IS NULL OR x.CategorieId<=0),COALESCE(x.CategorieOrdiNAmento,0),x.CategorieDescrizione,x.CategorieId," &
        "(x.TipologieId IS NULL OR x.TipologieId<=0),COALESCE(x.TipologieOrdinamento,0),x.TipologieDescrizione,x.TipologieId," &
        "(x.GruppiId IS NULL OR x.GruppiId<=0),COALESCE(x.GruppiOrdinamento,0),x.GruppiDEscrizione,x.GruppiId," &
        "x.Descrizione1,x.ArticleId"

    Public Shared Function LoadCurrent(ByVal context As HttpContext) As CatalogExportSnapshot
        Dim empty As New List(Of CatalogExportRow)()
        Try
            If context Is Nothing Then Return Failure(CatalogExportStatus.InvalidContext)
            Dim priceContext As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(context)
            If priceContext Is Nothing Then Return Failure(CatalogExportStatus.InvalidContext)
            If Not priceContext.IsAuthenticated Then Return Failure(CatalogExportStatus.NotAuthenticated)
            If priceContext.CompanyId <= 0 OrElse priceContext.PriceListId <= 0 Then Return Failure(CatalogExportStatus.InvalidContext)
            Dim eligibility As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(
                context, priceContext.CompanyId, priceContext.PriceListId)
            If Not IsCoherentContext(priceContext, eligibility) Then Return Failure(CatalogExportStatus.InvalidContext)

            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return Failure(CatalogExportStatus.TechnicalError)

            Dim table As New DataTable()
            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()
                Using command As New MySqlCommand(ListingSql, connection)
                    command.CommandTimeout = 120
                    command.Parameters.Add("@listino", MySqlDbType.Int32).Value = priceContext.PriceListId
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        table.Load(reader)
                    End Using
                End Using
            End Using

            Dim batch As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch(settings.ConnectionString, eligibility)
            If batch Is Nothing OrElse batch.Status <> ProductPromotionEligibilityLoadStatus.Success OrElse
               Not String.Equals(batch.ScopeKey, eligibility.CacheKey, StringComparison.Ordinal) Then
                Return Failure(CatalogExportStatus.TechnicalError)
            End If

            Return BuildSnapshot(context, priceContext, batch, table)
        Catch ex As Exception
            Try
                KeepStoreLog.Error("catalog-export", "Lettura listino non riuscita: " & ex.GetType().Name, Nothing, context)
            Catch
            End Try
            Return New CatalogExportSnapshot(CatalogExportStatus.TechnicalError, empty, "", "", Date.Today, 0)
        End Try
    End Function

    Private Shared Function Failure(ByVal status As CatalogExportStatus) As CatalogExportSnapshot
        Return New CatalogExportSnapshot(status, New List(Of CatalogExportRow)(), "", "", Date.Today, 0)
    End Function

    Private Shared Function IsCoherentContext(ByVal priceContext As StorefrontPriceDisplayContext,
                                              ByVal eligibility As ProductPromotionEligibilityContext) As Boolean
        Return priceContext IsNot Nothing AndAlso eligibility IsNot Nothing AndAlso
               Not String.IsNullOrWhiteSpace(eligibility.DatabaseScopeKey) AndAlso
               eligibility.CompanyId = priceContext.CompanyId AndAlso eligibility.Listino = priceContext.PriceListId AndAlso
               eligibility.IsAuthenticated = priceContext.IsAuthenticated AndAlso eligibility.CampaignId = 0 AndAlso
               If(eligibility.IsAuthenticated, eligibility.CurrentUserId > 0, eligibility.CurrentUserId = 0)
    End Function

    ' Composizione in memoria, usata anche dai test sintetici.
    Friend Shared Function BuildSnapshot(ByVal context As HttpContext,
                                         ByVal priceContext As StorefrontPriceDisplayContext,
                                         ByVal batch As IProductPromotionEligibilityBatch,
                                         ByVal table As DataTable) As CatalogExportSnapshot
        Dim rows As New List(Of CatalogExportRow)()
        Dim unavailable As Integer = 0
        For Each row As DataRow In table.Rows
            Dim built As CatalogExportRow = BuildRow(context, priceContext, batch, row)
            If built Is Nothing Then Continue For
            If Not built.HasPrice Then unavailable += 1
            rows.Add(built)
        Next
        Dim company As String = ""
        Try
            company = StorefrontSeoTenantContext.BrandName(context)
        Catch
        End Try
        Return New CatalogExportSnapshot(CatalogExportStatus.Ready, rows, priceContext.DisplayLabel, company, Date.Today, unavailable, LoadCompany(context))
    End Function

    ' Dati aziendali gia pubblicati dall'identita dell'host (stessa fonte del piede del sito); Nothing se non disponibili.
    Private Shared Function LoadCompany(ByVal context As HttpContext) As CatalogExportCompany
        Try
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
            If tenant Is Nothing Then Return Nothing
            Dim legal As StorefrontCompanyLegalProfile = tenant.LegalProfile
            Dim legalName As String = ""
            Dim vat As String = ""
            Dim registered As String = ""
            Dim operational As String = ""
            If legal IsNot Nothing AndAlso legal.CompanyId = tenant.CompanyId Then
                legalName = Clean(legal.LegalName, 120)
                vat = Clean(legal.VatNumber, 30)
                registered = JoinAddress(legal.RegisteredAddress, legal.RegisteredPostalCode, legal.RegisteredCity, legal.RegisteredProvince)
                operational = JoinAddress(legal.OperationalAddress, legal.OperationalPostalCode, legal.OperationalCity, legal.OperationalProvince)
                If String.Equals(operational, registered, StringComparison.OrdinalIgnoreCase) Then operational = ""
            End If
            Return New CatalogExportCompany(Clean(tenant.CompanyName, 120), legalName, vat, registered, operational,
                                            Clean(tenant.SupportPhone, 40), Clean(tenant.SupportEmail, 120), Clean(tenant.CanonicalBaseUrl, 160), Clean(tenant.LogoFileName, 150))
        Catch
            Return Nothing
        End Try
    End Function

    Private Shared Function JoinAddress(ByVal street As String, ByVal postalCode As String, ByVal city As String, ByVal province As String) As String
        Dim place As String = (Clean(postalCode, 10) & " " & Clean(city, 60)).Trim()
        If Not String.IsNullOrEmpty(Clean(province, 5)) Then place = (place & " (" & Clean(province, 5) & ")").Trim()
        Dim parts As New List(Of String)()
        If Not String.IsNullOrEmpty(Clean(street, 120)) Then parts.Add(Clean(street, 120))
        If Not String.IsNullOrEmpty(place) Then parts.Add(place)
        Return String.Join(", ", parts.ToArray())
    End Function

    Private Shared Function BuildRow(ByVal context As HttpContext,
                                     ByVal priceContext As StorefrontPriceDisplayContext,
                                     ByVal batch As IProductPromotionEligibilityBatch,
                                     ByVal row As DataRow) As CatalogExportRow
        Dim articleId As Integer = ToInt(row, "ArticleId", 0)
        If articleId <= 0 Then Return Nothing
        Dim tcId As Integer = ToInt(row, "TCId", -1)
        Dim sectorKey As String = NodeKey(ToInt(row, "SettoriId", -1))
        Dim categoryKey As String = NodeKey(ToInt(row, "CategorieId", -1))
        Dim typeKey As String = NodeKey(ToInt(row, "TipologieId", -1))
        Dim groupKey As String = NodeKey(ToInt(row, "GruppiId", -1))

        Dim hasPrice As Boolean = False
        Dim price As Decimal = 0D
        Dim listPrice As Decimal = 0D
        Dim showsDiscount As Boolean = False
        Dim endsOn As Nullable(Of Date) = Nothing
        Dim offerLabel As String = ""
        Dim tierNote As String = ""

        Dim net As Nullable(Of Decimal) = ToDecimal(row, "Prezzo")
        Dim gross As Nullable(Of Decimal) = StorefrontEffectivePriceResolver.ResolveEffectiveGross(net, ToDecimal(row, "PrezzoIvato"),
            priceContext.ReverseChargeEnabled, priceContext.VatOverride, ToInt(row, "IdIvaRC", -1), ToDecimal(row, "ValoreIvaRC"))
        ' Prezzo non valido: nessun calcolo promo (e nessuna riga di log per articolo): la scheda dice "Prezzo su richiesta".
        If net.HasValue AndAlso net.Value > 0D AndAlso gross.HasValue AndAlso gross.Value > 0D Then
            Dim model As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(
                batch, articleId, tcId, net.Value, gross.Value, priceContext.IsVatExcluded)
            If model IsNot Nothing AndAlso model.ResolutionState <> ProductPromotionDisplayResolutionState.TechnicalError Then
                Dim basePrice As Nullable(Of Decimal) = priceContext.SelectPrice(net.Value, gross.Value)
                If basePrice.HasValue AndAlso basePrice.Value > 0D Then
                    hasPrice = True
                    price = Money(basePrice.Value)
                    listPrice = price
                    If model.HasDefaultQuantityOffer Then
                        Dim promo As Nullable(Of Decimal) = priceContext.SelectPrice(model.BestDefaultQuantityPriceNet, model.BestDefaultQuantityPriceGross)
                        If promo.HasValue AndAlso promo.Value > 0D Then
                            price = Money(promo.Value)
                            showsDiscount = StorefrontPriceState.ShowsDiscount(Money(basePrice.Value), price)
                            endsOn = model.BestDefaultQuantityEndsOn
                            offerLabel = Clean(model.BestDefaultQuantityOfferLabel, 60)
                            If String.IsNullOrEmpty(offerLabel) Then offerLabel = "Offerta"
                        End If
                    End If
                    tierNote = BuildTierNote(model, priceContext)
                End If
            End If
        End If

        ' Disponibilita: stessa regola della scheda del sito (verde disponibile, giallo pochi pezzi o in arrivo, rosso non disponibile).
        Dim availabilityTone As Integer = 2
        Dim availabilityText As String = "Non disponibile"
        Try
            Dim availability As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItem(row, context)
            If availability IsNot Nothing Then
                availabilityText = Clean(availability.StatusText, 30)
                If String.Equals(availability.StatusToneClass, "is-ok", StringComparison.Ordinal) Then
                    availabilityTone = 0
                ElseIf String.Equals(availability.StatusToneClass, "is-low", StringComparison.Ordinal) OrElse String.Equals(availability.StatusToneClass, "is-incoming", StringComparison.Ordinal) Then
                    availabilityTone = 1
                End If
            End If
        Catch
        End Try

        Dim code As String = Clean(Convert.ToString(row("Codice"), CultureInfo.InvariantCulture), 40)
        Dim description As String = Clean(Convert.ToString(row("Descrizione1"), CultureInfo.InvariantCulture), 160)
        If String.IsNullOrEmpty(description) Then description = code
        Dim detail As String = Clean(Convert.ToString(row("Descrizione2"), CultureInfo.InvariantCulture), 200)
        Dim url As String = ""
        Try
            url = StorefrontSeoTenantContext.BuildCanonicalUrl(context, "/articolo.aspx?id=" & articleId.ToString(CultureInfo.InvariantCulture))
        Catch
        End Try

        Return New CatalogExportRow(articleId, tcId, code, Clean(Convert.ToString(row("Ean"), CultureInfo.InvariantCulture), 20), description, detail,
            sectorKey, NodeName(row, "SettoriDescrizione", "Altri articoli"), categoryKey, NodeName(row, "CategorieDescrizione", "Altre categorie"), typeKey, NodeName(row, "TipologieDescrizione", "Altre tipologie"),
            groupKey, NodeName(row, "GruppiDEscrizione", "Altri"), New String() {Convert.ToString(row("Img1"), CultureInfo.InvariantCulture), Convert.ToString(row("Img2"), CultureInfo.InvariantCulture),
                      Convert.ToString(row("Img3"), CultureInfo.InvariantCulture), Convert.ToString(row("Img4"), CultureInfo.InvariantCulture)},
            hasPrice, price, listPrice, showsDiscount, endsOn, offerLabel, tierNote, url, availabilityTone, availabilityText)
    End Function

    ' Offerta a quantita (minimo o multiplo): mai un prezzo universale, ma una nota con condizione e validita.
    Private Shared Function BuildTierNote(ByVal model As ProductPromotionDisplayModel, ByVal priceContext As StorefrontPriceDisplayContext) As String
        If model Is Nothing OrElse Not model.HasQuantityTierOffer OrElse model.Offers Is Nothing Then Return ""
        Dim best As ProductPromotionOffer = Nothing
        Dim bestPrice As Decimal = Decimal.MaxValue
        For Each offer As ProductPromotionOffer In model.Offers
            If offer Is Nothing OrElse offer.AppliesToDefaultQuantity Then Continue For
            Dim p As Nullable(Of Decimal) = priceContext.SelectPrice(offer.PriceNet, offer.PriceGross)
            If Not p.HasValue OrElse p.Value <= 0D Then Continue For
            If p.Value < bestPrice Then
                bestPrice = p.Value
                best = offer
            End If
        Next
        If best Is Nothing Then Return ""
        Dim condition As String
        If best.QntMinima > 1D Then
            condition = "da " & best.QntMinima.ToString("0.##", ItCulture) & " pz"
        ElseIf best.Multipli > 1D Then
            condition = "multipli di " & best.Multipli.ToString("0.##", ItCulture)
        Else
            Return ""
        End If
        Dim text As String = condition & ": " & Money(bestPrice).ToString("N2", ItCulture)
        If best.EndsOn.HasValue Then text &= " fino al " & best.EndsOn.Value.ToString("dd/MM/yyyy", ItCulture)
        Return text
    End Function

    Private Shared Function NodeKey(ByVal id As Integer) As String
        If id <= 0 Then Return "0"
        Return id.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function NodeName(ByVal row As DataRow, ByVal column As String, ByVal fallback As String) As String
        Dim text As String = Clean(Convert.ToString(row(column), CultureInfo.InvariantCulture), 80)
        If String.IsNullOrEmpty(text) Then Return fallback
        Return text
    End Function

    Private Shared Function ToInt(ByVal row As DataRow, ByVal column As String, ByVal fallback As Integer) As Integer
        If row.IsNull(column) Then Return fallback
        Try
            Return Convert.ToInt32(row(column), CultureInfo.InvariantCulture)
        Catch
            Return fallback
        End Try
    End Function

    Private Shared Function ToDecimal(ByVal row As DataRow, ByVal column As String) As Nullable(Of Decimal)
        If row.IsNull(column) Then Return Nothing
        Try
            Return Convert.ToDecimal(row(column), CultureInfo.InvariantCulture)
        Catch
            Return Nothing
        End Try
    End Function

    Friend Shared Function Money(ByVal value As Decimal) As Decimal
        Return Math.Round(value, 2, MidpointRounding.AwayFromZero)
    End Function

    ' Testo semplice per il file: niente controlli, spazi compressi, lunghezza limitata.
    Friend Shared Function Clean(ByVal raw As String, ByVal maxLength As Integer) As String
        If String.IsNullOrEmpty(raw) Then Return ""
        Dim sb As New System.Text.StringBuilder(raw.Length)
        For Each ch As Char In raw
            If Char.IsControl(ch) Then
                sb.Append(" "c)
            Else
                sb.Append(ch)
            End If
        Next
        Dim text As String = System.Text.RegularExpressions.Regex.Replace(sb.ToString(), "\s+", " ").Trim()
        If text.Length > maxLength Then text = text.Substring(0, maxLength - 1).TrimEnd() & "..."
        Return text
    End Function
End Class
