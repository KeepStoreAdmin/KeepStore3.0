Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Web

Public Class ProductPromotionOffer
    Public Property OfferId As Integer
    Public Property OfferDetailId As Integer
    Public Property OwnerUserId As Integer
    Public Property Label As String
    Public Property QntMinima As Decimal
    Public Property Multipli As Decimal
    Public Property PriceNet As Decimal
    Public Property PriceGross As Decimal
    Public Property DiscountPercent As Decimal
    Public Property StartsOn As Nullable(Of Date)
    Public Property EndsOn As Nullable(Of Date)
    Public Property AppliesToDefaultQuantity As Boolean
    Public Property IsExactVariant As Boolean
End Class

Public Enum ProductPromotionDisplayResolutionState
    ResolvedWithoutOffers = 0
    ResolvedWithOffers = 1
    TechnicalError = 2
End Enum

Public Class ProductPromotionDisplayModel
    Public Property ResolutionState As ProductPromotionDisplayResolutionState
    Public Property HasOffers As Boolean
    Public Property HasDefaultQuantityOffer As Boolean
    Public Property HasQuantityTierOffer As Boolean
    Public Property ListPriceNet As Decimal
    Public Property ListPriceGross As Decimal
    Public Property StandardPriceNet As Decimal
    Public Property StandardPriceGross As Decimal
    Public Property BestPriceNet As Decimal
    Public Property BestPriceGross As Decimal
    Public Property BestDiscountPercent As Decimal
    Public Property BestOfferLabel As String
    Public Property BestPriceRequiresQuantityTier As Boolean
    Public Property BestDefaultQuantityPriceNet As Decimal
    Public Property BestDefaultQuantityPriceGross As Decimal
    Public Property BestDefaultQuantityDiscountPercent As Decimal
    Public Property BestDefaultQuantityOfferLabel As String
    Public Property BestDefaultQuantityEndsOn As Nullable(Of Date)
    Public Property BestQuantityTierPriceNet As Decimal
    Public Property BestQuantityTierPriceGross As Decimal
    Public Property BestQuantityTierDiscountPercent As Decimal
    Public Property BestQuantityTierOfferLabel As String
    Public Property BestQuantityTierEndsOn As Nullable(Of Date)
    Public Property Offers As List(Of ProductPromotionOffer)
    Public Property Html As String
End Class

Public Module ProductPromotionDisplayHelper
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Public Function BuildForProduct(ByVal connectionString As String,
                                    ByVal articleId As Integer,
                                    ByVal tcId As Integer,
                                    ByVal eligibilityContext As ProductPromotionEligibilityContext,
                                    ByVal baseNetPrice As Decimal,
                                    ByVal baseGrossPrice As Decimal) As ProductPromotionDisplayModel
        Dim model As New ProductPromotionDisplayModel()
        model.Offers = New List(Of ProductPromotionOffer)()
        model.ListPriceNet = baseNetPrice
        model.ListPriceGross = baseGrossPrice
        model.StandardPriceNet = baseNetPrice
        model.StandardPriceGross = baseGrossPrice
        model.BestPriceNet = baseNetPrice
        model.BestPriceGross = baseGrossPrice
        model.BestDefaultQuantityPriceNet = baseNetPrice
        model.BestDefaultQuantityPriceGross = baseGrossPrice
        model.ResolutionState = ProductPromotionDisplayResolutionState.ResolvedWithoutOffers

        If String.IsNullOrWhiteSpace(connectionString) OrElse articleId <= 0 OrElse eligibilityContext Is Nothing OrElse baseGrossPrice <= 0D Then
            SetTechnicalError(model, baseNetPrice, baseGrossPrice, "validation", "InvalidRequest")
            Return model
        End If

        Dim eligibility As ProductPromotionEligibilityResult = Nothing
        Try
            eligibility = ProductPromotionEligibilityResolver.Resolve(connectionString,
                                                                      eligibilityContext,
                                                                      articleId,
                                                                      tcId,
                                                                      1D,
                                                                      baseNetPrice,
                                                                      baseGrossPrice)
        Catch ex As Exception
            SetTechnicalError(model, baseNetPrice, baseGrossPrice, "resolver", ex.GetType().Name)
            Return model
        End Try

        If eligibility Is Nothing OrElse eligibility.Status <> ProductPromotionEligibilityLoadStatus.Success Then
            Dim statusName As String = If(eligibility Is Nothing, "NullResult", eligibility.Status.ToString())
            SetTechnicalError(model, baseNetPrice, baseGrossPrice, "resolver-status", statusName)
            Return model
        End If

        If eligibility.AuthorizedOffers Is Nothing Then
            SetTechnicalError(model, baseNetPrice, baseGrossPrice, "offer-loading", "MissingOfferCollection")
            Return model
        End If

        Try
            LoadOffers(eligibility, model)
        Catch ex As Exception
            SetTechnicalError(model, baseNetPrice, baseGrossPrice, "offer-loading", ex.GetType().Name)
            Return model
        End Try

        model.HasOffers = (model.Offers.Count > 0)
        model.ResolutionState = If(model.HasOffers,
                                   ProductPromotionDisplayResolutionState.ResolvedWithOffers,
                                   ProductPromotionDisplayResolutionState.ResolvedWithoutOffers)
        model.Html = RenderHtml(model)
        Return model
    End Function

    Private Sub LoadOffers(ByVal eligibility As ProductPromotionEligibilityResult,
                           ByVal model As ProductPromotionDisplayModel)
        If eligibility Is Nothing OrElse model Is Nothing OrElse eligibility.AuthorizedOffers Is Nothing Then Return

        For Each authorized As ProductPromotionEligibilityOffer In eligibility.AuthorizedOffers
            Dim offer As ProductPromotionOffer = BuildOffer(authorized)
            If offer Is Nothing Then Continue For
            model.Offers.Add(offer)
            If model.BestPriceGross <= 0D OrElse offer.PriceGross < model.BestPriceGross Then
                model.BestPriceNet = offer.PriceNet
                model.BestPriceGross = offer.PriceGross
                model.BestDiscountPercent = offer.DiscountPercent
                model.BestOfferLabel = offer.Label
                model.BestPriceRequiresQuantityTier = Not offer.AppliesToDefaultQuantity
            End If
        Next

        If eligibility.AppliedOffer IsNot Nothing Then
            SetDefaultQuantityOffer(model, BuildOffer(eligibility.AppliedOffer))
        End If

        Dim tier As ProductPromotionOffer = BestTierOffer(model.Offers)
        If tier IsNot Nothing Then SetQuantityTierOffer(model, tier)
    End Sub

    Private Function BuildOffer(ByVal authorized As ProductPromotionEligibilityOffer) As ProductPromotionOffer
        If authorized Is Nothing Then Return Nothing
        Return New ProductPromotionOffer() With {
            .OfferId = authorized.OfferId,
            .OfferDetailId = authorized.OfferDetailId,
            .OwnerUserId = authorized.OwnerUserId,
            .Label = BuildOfferLabel(authorized.QntMinima, authorized.Multipli),
            .QntMinima = authorized.QntMinima,
            .Multipli = authorized.Multipli,
            .PriceNet = authorized.PriceNet,
            .PriceGross = authorized.PriceGross,
            .DiscountPercent = authorized.DiscountPercent,
            .StartsOn = authorized.StartsOn,
            .EndsOn = authorized.EndsOn,
            .AppliesToDefaultQuantity = authorized.AppliesToQuantity(1D),
            .IsExactVariant = authorized.IsExactVariant
        }
    End Function

    Private Sub SetDefaultQuantityOffer(ByVal model As ProductPromotionDisplayModel, ByVal offer As ProductPromotionOffer)
        If model Is Nothing OrElse offer Is Nothing Then Return
        model.HasDefaultQuantityOffer = True
        model.BestDefaultQuantityPriceNet = offer.PriceNet
        model.BestDefaultQuantityPriceGross = offer.PriceGross
        model.BestDefaultQuantityDiscountPercent = offer.DiscountPercent
        model.BestDefaultQuantityOfferLabel = offer.Label
        model.BestDefaultQuantityEndsOn = offer.EndsOn
    End Sub

    Private Function BestTierOffer(ByVal offers As List(Of ProductPromotionOffer)) As ProductPromotionOffer
        If offers Is Nothing Then Return Nothing
        Dim best As ProductPromotionOffer = Nothing
        For Each offer As ProductPromotionOffer In offers
            If offer Is Nothing OrElse offer.AppliesToDefaultQuantity Then Continue For
            If best Is Nothing OrElse
               offer.PriceGross < best.PriceGross OrElse
               (offer.PriceGross = best.PriceGross AndAlso offer.IsExactVariant AndAlso Not best.IsExactVariant) OrElse
               (offer.PriceGross = best.PriceGross AndAlso offer.IsExactVariant = best.IsExactVariant AndAlso offer.OfferDetailId < best.OfferDetailId) Then
                best = offer
            End If
        Next
        Return best
    End Function

    Private Sub SetQuantityTierOffer(ByVal model As ProductPromotionDisplayModel, ByVal offer As ProductPromotionOffer)
        If model Is Nothing OrElse offer Is Nothing Then Return
        model.HasQuantityTierOffer = True
        model.BestQuantityTierPriceNet = offer.PriceNet
        model.BestQuantityTierPriceGross = offer.PriceGross
        model.BestQuantityTierDiscountPercent = offer.DiscountPercent
        model.BestQuantityTierOfferLabel = offer.Label
        model.BestQuantityTierEndsOn = offer.EndsOn
    End Sub

    Private Function RenderHtml(ByVal model As ProductPromotionDisplayModel) As String
        If model Is Nothing OrElse
           model.ResolutionState <> ProductPromotionDisplayResolutionState.ResolvedWithOffers OrElse
           Not model.HasOffers Then Return String.Empty

        Dim useNetPrices As Boolean = UseNetPriceDisplay()
        Dim sb As New StringBuilder()
        Dim offerCountLabel As String = model.Offers.Count.ToString(CultureInfo.InvariantCulture) &
                                        If(model.Offers.Count = 1, " offerta attiva", " offerte attive")
        sb.Append("<div class=""ks-product-promos"" aria-label=""Offerte attive"">")
        sb.Append("<div class=""ks-product-promos__head"">")
        sb.Append("<div class=""ks-product-promos__heading"">")
        sb.Append("<span class=""ks-product-promos__eyebrow"">Offerte attive</span>")
        sb.Append("<span class=""ks-product-promos__lede"">Prezzi e condizioni per quantità</span>")
        sb.Append("</div>")
        sb.Append("<span class=""ks-product-promos__count"" aria-label=""").Append(HtmlEncode(offerCountLabel)).Append(""">")
        sb.Append(model.Offers.Count.ToString(CultureInfo.InvariantCulture)).Append(If(model.Offers.Count = 1, " offerta", " offerte")).Append("</span>")
        sb.Append("</div>")
        sb.Append("<div class=""ks-product-promos__list"" role=""list"">")
        Dim primaryImmediateRendered As Boolean = False
        For Each offer As ProductPromotionOffer In model.Offers
            Dim isPrimaryImmediate As Boolean = offer.AppliesToDefaultQuantity AndAlso
                                                  Not primaryImmediateRendered AndAlso
                                                  DisplayPrice(offer.PriceNet, offer.PriceGross, useNetPrices) =
                                                  DisplayPrice(model.BestDefaultQuantityPriceNet, model.BestDefaultQuantityPriceGross, useNetPrices)
            If isPrimaryImmediate Then primaryImmediateRendered = True

            sb.Append("<div class=""ks-product-promos__item ")
            sb.Append(If(offer.AppliesToDefaultQuantity, "ks-product-promos__item--immediate", "ks-product-promos__item--tier"))
            sb.Append(""" role=""listitem"">")
            sb.Append("<div class=""ks-product-promos__item-head"">")
            sb.Append("<span class=""ks-product-promos__label"">")
            sb.Append(If(offer.AppliesToDefaultQuantity, "Promo immediata", "Offerta quantità"))
            sb.Append("</span>")
            If offer.DiscountPercent > 0D Then
                sb.Append("<span class=""ks-product-promos__discount"">-").Append(HtmlEncode(FormatQuantity(offer.DiscountPercent))).Append("%</span>")
            End If
            sb.Append("</div>")
            sb.Append("<div class=""ks-product-promos__item-body"">")
            If isPrimaryImmediate Then
                sb.Append("<span class=""ks-product-promos__condition"">").Append(HtmlEncode(offer.Label)).Append("</span>")
                sb.Append("<span class=""ks-product-promos__applied"">Già applicata al prezzo principale</span>")
            Else
                sb.Append("<span class=""ks-product-promos__price"">")
                sb.Append(If(offer.AppliesToDefaultQuantity, "A ", "Da "))
                sb.Append("<strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(offer.PriceNet, offer.PriceGross, useNetPrices)))).Append("</strong></span>")
                sb.Append("<span class=""ks-product-promos__condition"">").Append(HtmlEncode(offer.Label)).Append("</span>")
            End If
            sb.Append("</div>")
            Dim validity As String = FormatOfferValidity(offer.StartsOn, offer.EndsOn)
            If Not String.IsNullOrWhiteSpace(validity) Then
                sb.Append("<span class=""ks-product-promos__dates"">Validità: ").Append(HtmlEncode(validity)).Append("</span>")
            End If
            sb.Append("</div>")
        Next
        sb.Append("</div>")
        sb.Append("</div>")
        Return sb.ToString()
    End Function

    Public Function RenderCatalogSummaryHtml(ByVal model As ProductPromotionDisplayModel) As String
        If model Is Nothing OrElse
           model.ResolutionState <> ProductPromotionDisplayResolutionState.ResolvedWithOffers OrElse
           Not model.HasOffers Then Return String.Empty
        If Not model.HasQuantityTierOffer AndAlso model.Offers.Count <= 1 Then Return String.Empty

        Dim useNetPrices As Boolean = UseNetPriceDisplay()
        Dim sb As New StringBuilder()
        sb.Append("<div class=""ks-catalog-promos"" aria-label=""Dettagli promozione"">")
        If model.HasQuantityTierOffer Then
            sb.Append("<span class=""ks-catalog-promos__tier-block"">")
            sb.Append("<span class=""ks-catalog-promos__kicker"">Prezzo quantità</span>")
            sb.Append("<span class=""ks-catalog-promos__price"">Da <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.BestQuantityTierPriceNet, model.BestQuantityTierPriceGross, useNetPrices)))).Append("</strong></span>")
            If Not String.IsNullOrWhiteSpace(model.BestQuantityTierOfferLabel) Then
                sb.Append("<span class=""ks-catalog-promos__tier"">").Append(HtmlEncode(model.BestQuantityTierOfferLabel)).Append("</span>")
            End If
            sb.Append("</span>")
        End If
        If model.Offers.Count > 1 Then
            sb.Append("<span class=""ks-catalog-promos__count"">").Append(model.Offers.Count.ToString(CultureInfo.InvariantCulture)).Append(" offerte disponibili</span>")
        End If
        sb.Append("</div>")
        Return sb.ToString()
    End Function

    Private Function FormatOfferValidity(ByVal startDate As Nullable(Of Date),
                                         ByVal endDate As Nullable(Of Date)) As String
        If startDate.HasValue AndAlso endDate.HasValue Then
            Return "dal " & startDate.Value.ToString("dd/MM/yyyy", ItCulture) & " al " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        End If
        If startDate.HasValue Then Return "dal " & startDate.Value.ToString("dd/MM/yyyy", ItCulture)
        If endDate.HasValue Then Return "fino al " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        Return String.Empty
    End Function

    Public Function BuildLegacyOfferText(ByVal qntMinimaValue As Object,
                                         ByVal multipliValue As Object,
                                         ByVal promoPriceValue As Object,
                                         ByVal basePriceValue As Object,
                                         ByVal startDateValue As Object,
                                         ByVal endDateValue As Object) As String
        Dim qntMinima As Decimal = ParseDecimal(promoValue:=qntMinimaValue)
        Dim multipli As Decimal = ParseDecimal(promoValue:=multipliValue)
        Dim promoPrice As Decimal = ParseDecimal(promoValue:=promoPriceValue)
        Dim basePrice As Decimal = ParseDecimal(promoValue:=basePriceValue)
        If basePrice <= 0D OrElse promoPrice <= 0D OrElse promoPrice >= basePrice Then Return String.Empty

        Dim text As String = BuildOfferLabel(qntMinima, multipli) & " A " & FormatMoney(promoPrice)
        Dim dateText As String = FormatDateRange(ParseDate(startDateValue), ParseDate(endDateValue))
        If Not String.IsNullOrWhiteSpace(dateText) AndAlso dateText <> "promo attiva" Then
            text &= " - " & dateText
        End If

        Dim discount As Decimal = CalculateDiscount(basePrice, promoPrice)
        If discount > 0D Then
            text &= " - SCONTO -" & FormatQuantity(discount) & "%"
        End If

        Return text
    End Function

    Private Function FormatMoney(ByVal value As Decimal) As String
        Return value.ToString("C2", ItCulture)
    End Function

    Private Function FormatDateRange(ByVal startDate As Nullable(Of Date), ByVal endDate As Nullable(Of Date)) As String
        If startDate.HasValue AndAlso endDate.HasValue Then
            Return startDate.Value.ToString("dd/MM/yyyy", ItCulture) & " - " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        End If
        If endDate.HasValue Then Return "fino al " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        Return "promo attiva"
    End Function

    Private Function BuildOfferLabel(ByVal qntMinima As Decimal, ByVal multipli As Decimal) As String
        If qntMinima > 0D Then
            If qntMinima <= 1D Then Return "QUANTITA " & FormatQuantity(qntMinima) & " PZ."
            Return "MINIMO " & FormatQuantity(qntMinima) & " PZ."
        End If
        If multipli > 0D Then
            Return "MULTIPLI " & FormatQuantity(multipli) & " PZ."
        End If
        Return "PROMO"
    End Function

    Private Sub ResetOfferState(ByVal model As ProductPromotionDisplayModel,
                                ByVal baseNetPrice As Decimal,
                                ByVal baseGrossPrice As Decimal)
        If model Is Nothing Then Return
        model.Offers.Clear()
        model.HasOffers = False
        model.HasDefaultQuantityOffer = False
        model.HasQuantityTierOffer = False
        model.BestPriceNet = baseNetPrice
        model.BestPriceGross = baseGrossPrice
        model.BestDiscountPercent = 0D
        model.BestOfferLabel = String.Empty
        model.BestPriceRequiresQuantityTier = False
        model.BestDefaultQuantityPriceNet = baseNetPrice
        model.BestDefaultQuantityPriceGross = baseGrossPrice
        model.BestDefaultQuantityDiscountPercent = 0D
        model.BestDefaultQuantityOfferLabel = String.Empty
        model.BestDefaultQuantityEndsOn = Nothing
        model.BestQuantityTierPriceNet = 0D
        model.BestQuantityTierPriceGross = 0D
        model.BestQuantityTierDiscountPercent = 0D
        model.BestQuantityTierOfferLabel = String.Empty
        model.BestQuantityTierEndsOn = Nothing
    End Sub

    Private Sub SetTechnicalError(ByVal model As ProductPromotionDisplayModel,
                                  ByVal baseNetPrice As Decimal,
                                  ByVal baseGrossPrice As Decimal,
                                  ByVal phase As String,
                                  ByVal errorType As String)
        If model Is Nothing Then Return
        ResetOfferState(model, baseNetPrice, baseGrossPrice)
        model.ResolutionState = ProductPromotionDisplayResolutionState.TechnicalError
        model.Html = String.Empty

        Try
            KeepStoreLog.Error(
                "promotion-display",
                "Promotion display resolution failed. phase=" & SafeDiagnosticToken(phase) &
                " errorType=" & SafeDiagnosticToken(errorType) & ".",
                Nothing,
                HttpContext.Current)
        Catch logError As Exception
            System.Diagnostics.Trace.TraceError(
                "promotion-display logging failed. Error type: " & logError.GetType().Name & ".")
        End Try
    End Sub

    Private Function SafeDiagnosticToken(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return "Unknown"
        Dim safe As New StringBuilder()
        For Each ch As Char In value
            If Char.IsLetterOrDigit(ch) OrElse ch = "-"c OrElse ch = "_"c Then safe.Append(ch)
            If safe.Length >= 48 Then Exit For
        Next
        If safe.Length = 0 Then Return "Unknown"
        Return safe.ToString()
    End Function

    Private Function UseNetPriceDisplay() As Boolean
        Try
            Dim context As HttpContext = HttpContext.Current
            If context Is Nothing OrElse context.Session Is Nothing Then Return False
            Dim ivaTipo As Integer = 0
            Return Integer.TryParse(Convert.ToString(context.Session("IvaTipo")), ivaTipo) AndAlso ivaTipo = 1
        Catch
            Return False
        End Try
    End Function

    Private Function DisplayPrice(ByVal netPrice As Decimal, ByVal grossPrice As Decimal, ByVal useNetPrices As Boolean) As Decimal
        If useNetPrices AndAlso netPrice > 0D Then Return netPrice
        Return grossPrice
    End Function

    Private Function CalculateDiscount(ByVal basePrice As Decimal, ByVal promoPrice As Decimal) As Decimal
        If basePrice <= 0D OrElse promoPrice <= 0D OrElse promoPrice >= basePrice Then Return 0D
        Return Math.Round((1D - (promoPrice / basePrice)) * 100D, 0, MidpointRounding.AwayFromZero)
    End Function

    Private Function ParseDecimal(ByVal promoValue As Object) As Decimal
        If promoValue Is Nothing OrElse promoValue Is DBNull.Value Then Return 0D
        Dim result As Decimal
        If Decimal.TryParse(Convert.ToString(promoValue), NumberStyles.Any, ItCulture, result) Then Return result
        If Decimal.TryParse(Convert.ToString(promoValue), NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return result
        Return 0D
    End Function

    Private Function ParseDate(ByVal value As Object) As Nullable(Of Date)
        If value Is Nothing OrElse value Is DBNull.Value Then Return Nothing
        If TypeOf value Is Date Then Return DirectCast(value, Date)
        Dim result As Date
        If Date.TryParse(Convert.ToString(value), ItCulture, DateTimeStyles.None, result) Then Return result
        If Date.TryParse(Convert.ToString(value), CultureInfo.InvariantCulture, DateTimeStyles.None, result) Then Return result
        Return Nothing
    End Function

    Private Function FormatQuantity(ByVal value As Decimal) As String
        Return value.ToString("0.##", CultureInfo.InvariantCulture)
    End Function

    Private Function HtmlEncode(ByVal value As String) As String
        Return HttpUtility.HtmlEncode(If(value, String.Empty))
    End Function
End Module
