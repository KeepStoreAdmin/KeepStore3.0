Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class ProductPromotionOffer
    Public Property Label As String
    Public Property QntMinima As Decimal
    Public Property Multipli As Decimal
    Public Property PriceNet As Decimal
    Public Property PriceGross As Decimal
    Public Property DiscountPercent As Decimal
    Public Property StartsOn As Nullable(Of Date)
    Public Property EndsOn As Nullable(Of Date)
    Public Property AppliesToDefaultQuantity As Boolean
End Class

Public Class ProductPromotionDisplayModel
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
    Public Property BestQuantityTierPriceNet As Decimal
    Public Property BestQuantityTierPriceGross As Decimal
    Public Property BestQuantityTierDiscountPercent As Decimal
    Public Property BestQuantityTierOfferLabel As String
    Public Property Offers As List(Of ProductPromotionOffer)
    Public Property Html As String
End Class

Public Module ProductPromotionDisplayHelper
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Public Function BuildForProduct(ByVal connectionString As String,
                                    ByVal articleId As Integer,
                                    ByVal companyId As Integer,
                                    ByVal listino As Integer,
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

        If String.IsNullOrWhiteSpace(connectionString) OrElse articleId <= 0 OrElse companyId <= 0 OrElse listino <= 0 OrElse baseGrossPrice <= 0D Then
            model.Html = String.Empty
            Return model
        End If

        Try
            Using cn As New MySqlConnection(connectionString)
                cn.Open()
                Using cmd As New MySqlCommand(BuildSql(), cn)
                    cmd.Parameters.Add("@articleId", MySqlDbType.Int32).Value = articleId
                    cmd.Parameters.Add("@companyId", MySqlDbType.Int32).Value = companyId
                    cmd.Parameters.Add("@listino", MySqlDbType.Int32).Value = listino

                    Using rdr As MySqlDataReader = cmd.ExecuteReader()
                        LoadOffers(rdr, model, baseNetPrice, baseGrossPrice)
                    End Using
                End Using

            End Using
        Catch
            ResetOfferState(model, baseNetPrice, baseGrossPrice)
        End Try

        model.HasOffers = (model.Offers.Count > 0)
        model.Html = RenderHtml(model)
        Return model
    End Function

    Private Function BuildSql() As String
        Return "SELECT OfferteId, AziendeId, DataInizio, DataFine, QntMinima, Multipli, Prezzo, Sconto " &
               "FROM voffertedettagli " &
               "WHERE ArticoliId=@articleId " &
               "  AND AziendeId=@companyId " &
               "  AND COALESCE(Abilitato,0)=1 " &
               "  AND @listino BETWEEN COALESCE(DaListino,@listino) AND COALESCE(AListino,@listino) " &
               "  AND (DataInizio IS NULL OR DataInizio<=CURDATE()) " &
               "  AND (DataFine IS NULL OR DataFine>=CURDATE()) " &
               "ORDER BY CASE WHEN COALESCE(Multipli,0)=10 THEN 0 WHEN COALESCE(QntMinima,0)>0 THEN 1 WHEN COALESCE(Multipli,0)>0 THEN 2 ELSE 3 END, " &
               "         COALESCE(Multipli,0) ASC, COALESCE(QntMinima,0) ASC, OfferteId ASC"
    End Function

    Private Sub LoadOffers(ByVal rdr As MySqlDataReader,
                           ByVal model As ProductPromotionDisplayModel,
                           ByVal baseNetPrice As Decimal,
                           ByVal baseGrossPrice As Decimal)
        If rdr Is Nothing OrElse model Is Nothing Then Return

        While rdr.Read()
            Dim offer As ProductPromotionOffer = BuildOffer(rdr, baseNetPrice, baseGrossPrice)
            If offer Is Nothing Then Continue While
            model.Offers.Add(offer)
            If model.BestPriceGross <= 0D OrElse offer.PriceGross < model.BestPriceGross Then
                model.BestPriceNet = offer.PriceNet
                model.BestPriceGross = offer.PriceGross
                model.BestDiscountPercent = offer.DiscountPercent
                model.BestOfferLabel = offer.Label
                model.BestPriceRequiresQuantityTier = Not offer.AppliesToDefaultQuantity
            End If

            If offer.AppliesToDefaultQuantity Then
                If Not model.HasDefaultQuantityOffer OrElse offer.PriceGross < model.BestDefaultQuantityPriceGross Then
                    model.HasDefaultQuantityOffer = True
                    model.BestDefaultQuantityPriceNet = offer.PriceNet
                    model.BestDefaultQuantityPriceGross = offer.PriceGross
                    model.BestDefaultQuantityDiscountPercent = offer.DiscountPercent
                    model.BestDefaultQuantityOfferLabel = offer.Label
                End If
            ElseIf Not model.HasQuantityTierOffer OrElse offer.PriceGross < model.BestQuantityTierPriceGross Then
                model.HasQuantityTierOffer = True
                model.BestQuantityTierPriceNet = offer.PriceNet
                model.BestQuantityTierPriceGross = offer.PriceGross
                model.BestQuantityTierDiscountPercent = offer.DiscountPercent
                model.BestQuantityTierOfferLabel = offer.Label
            End If
        End While
    End Sub

    Private Function BuildOffer(ByVal rdr As IDataRecord, ByVal baseNetPrice As Decimal, ByVal baseGrossPrice As Decimal) As ProductPromotionOffer
        Dim qntMinima As Decimal = FieldDecimal(rdr, "QntMinima")
        Dim multipli As Decimal = FieldDecimal(rdr, "Multipli")
        Dim promoNet As Decimal = FieldDecimal(rdr, "Prezzo")
        Dim discount As Decimal = FieldDecimal(rdr, "Sconto")
        Dim netPrice As Decimal = 0D
        Dim grossPrice As Decimal = 0D

        If baseNetPrice <= 0D OrElse baseGrossPrice <= 0D Then Return Nothing
        If qntMinima <= 0D AndAlso multipli <= 0D Then Return Nothing

        If promoNet > 0D Then
            netPrice = promoNet
        ElseIf discount > 0D AndAlso discount < 100D Then
            netPrice = baseNetPrice * (1D - (discount / 100D))
        End If

        If netPrice <= 0D OrElse netPrice >= baseNetPrice Then Return Nothing

        grossPrice = netPrice * (baseGrossPrice / baseNetPrice)
        If grossPrice <= 0D OrElse grossPrice >= baseGrossPrice Then Return Nothing

        Dim label As String = BuildOfferLabel(qntMinima, multipli)
        Dim effectiveDiscount As Decimal = CalculateDiscount(baseNetPrice, netPrice)

        Return New ProductPromotionOffer() With {
            .Label = label,
            .QntMinima = qntMinima,
            .Multipli = multipli,
            .PriceNet = netPrice,
            .PriceGross = grossPrice,
            .DiscountPercent = effectiveDiscount,
            .StartsOn = FieldDate(rdr, "DataInizio"),
            .EndsOn = FieldDate(rdr, "DataFine"),
            .AppliesToDefaultQuantity = IsDefaultQuantityOffer(qntMinima, multipli)
        }
    End Function

    Private Function IsDefaultQuantityOffer(ByVal qntMinima As Decimal, ByVal multipli As Decimal) As Boolean
        If qntMinima > 0D Then Return qntMinima <= 1D
        If multipli > 0D Then Return Decimal.Remainder(1D, multipli) = 0D
        Return False
    End Function

    Private Function RenderHtml(ByVal model As ProductPromotionDisplayModel) As String
        If model Is Nothing OrElse Not model.HasOffers Then Return String.Empty

        Dim useNetPrices As Boolean = UseNetPriceDisplay()
        Dim sb As New StringBuilder()
        sb.Append("<div class=""ks-product-promos"" aria-label=""Offerte attive"">")
        sb.Append("<div class=""ks-product-promos__head"">")
        sb.Append("<span class=""ks-product-promos__eyebrow"">Offerte attive</span>")
        If model.HasDefaultQuantityOffer AndAlso model.BestDefaultQuantityDiscountPercent > 0D Then
            sb.Append("<span class=""ks-product-promos__discount"">-").Append(HtmlEncode(FormatQuantity(model.BestDefaultQuantityDiscountPercent))).Append("%</span>")
        End If
        sb.Append("</div>")
        sb.Append("<div class=""ks-product-promos__summary"">")
        sb.Append("<span>Prezzo di Listino <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.ListPriceNet, model.ListPriceGross, useNetPrices)))).Append("</strong></span>")
        sb.Append("<span>Prezzo Standard <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.StandardPriceNet, model.StandardPriceGross, useNetPrices)))).Append("</strong></span>")
        If model.HasDefaultQuantityOffer Then
            sb.Append("<span>Prezzo promo <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.BestDefaultQuantityPriceNet, model.BestDefaultQuantityPriceGross, useNetPrices)))).Append("</strong></span>")
        End If
        If model.HasQuantityTierOffer Then
            sb.Append("<span>Da <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.BestQuantityTierPriceNet, model.BestQuantityTierPriceGross, useNetPrices)))).Append("</strong>")
            If Not String.IsNullOrWhiteSpace(model.BestQuantityTierOfferLabel) Then
                sb.Append("<small class=""ks-product-promos__tier-note"">").Append(HtmlEncode(model.BestQuantityTierOfferLabel)).Append("</small>")
            End If
            sb.Append("</span>")
        End If
        sb.Append("</div>")
        sb.Append("<div class=""ks-product-promos__list"">")
        For Each offer As ProductPromotionOffer In model.Offers
            sb.Append("<div class=""ks-product-promos__item"">")
            sb.Append("<span class=""ks-product-promos__label"">").Append(HtmlEncode(offer.Label)).Append("</span>")
            sb.Append("<strong>A ").Append(HtmlEncode(FormatMoney(DisplayPrice(offer.PriceNet, offer.PriceGross, useNetPrices)))).Append("</strong>")
            sb.Append("<span class=""ks-product-promos__dates"">").Append(HtmlEncode(FormatDateRange(offer.StartsOn, offer.EndsOn))).Append("</span>")
            sb.Append("</div>")
        Next
        sb.Append("</div>")
        sb.Append("</div>")
        Return sb.ToString()
    End Function

    Public Function RenderCatalogSummaryHtml(ByVal model As ProductPromotionDisplayModel) As String
        If model Is Nothing OrElse Not model.HasOffers Then Return String.Empty

        Dim useNetPrices As Boolean = UseNetPriceDisplay()
        Dim sb As New StringBuilder()
        sb.Append("<div class=""ks-catalog-promos"" aria-label=""Offerte attive"">")
        If model.HasDefaultQuantityOffer Then
            If model.BestDefaultQuantityDiscountPercent > 0D Then
                sb.Append("<span class=""ks-catalog-promos__discount"">-").Append(HtmlEncode(FormatQuantity(model.BestDefaultQuantityDiscountPercent))).Append("%</span>")
            End If
            sb.Append("<span class=""ks-catalog-promos__price"">Promo <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.BestDefaultQuantityPriceNet, model.BestDefaultQuantityPriceGross, useNetPrices)))).Append("</strong></span>")
        End If
        If model.HasQuantityTierOffer Then
            sb.Append("<span class=""ks-catalog-promos__price"">Da <strong>").Append(HtmlEncode(FormatMoney(DisplayPrice(model.BestQuantityTierPriceNet, model.BestQuantityTierPriceGross, useNetPrices)))).Append("</strong></span>")
            If Not String.IsNullOrWhiteSpace(model.BestQuantityTierOfferLabel) Then
                sb.Append("<span class=""ks-catalog-promos__tier"">").Append(HtmlEncode(model.BestQuantityTierOfferLabel)).Append("</span>")
            End If
        End If
        If model.Offers.Count > 1 Then
            sb.Append("<span class=""ks-catalog-promos__count"">").Append(model.Offers.Count.ToString(CultureInfo.InvariantCulture)).Append(" offerte attive</span>")
        End If
        sb.Append("</div>")
        Return sb.ToString()
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

    Private Function FieldDecimal(ByVal record As IDataRecord, ByVal fieldName As String) As Decimal
        Dim ordinal As Integer = record.GetOrdinal(fieldName)
        If record.IsDBNull(ordinal) Then Return 0D
        Dim value As Decimal
        If Decimal.TryParse(Convert.ToString(record.GetValue(ordinal)), NumberStyles.Any, CultureInfo.CurrentCulture, value) Then Return value
        If Decimal.TryParse(Convert.ToString(record.GetValue(ordinal)), NumberStyles.Any, CultureInfo.InvariantCulture, value) Then Return value
        Return 0D
    End Function

    Private Function FieldDate(ByVal record As IDataRecord, ByVal fieldName As String) As Nullable(Of Date)
        Dim ordinal As Integer = record.GetOrdinal(fieldName)
        If record.IsDBNull(ordinal) Then Return Nothing
        Dim value As Date
        If Date.TryParse(Convert.ToString(record.GetValue(ordinal)), value) Then Return value
        Return Nothing
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
        model.BestQuantityTierPriceNet = 0D
        model.BestQuantityTierPriceGross = 0D
        model.BestQuantityTierDiscountPercent = 0D
        model.BestQuantityTierOfferLabel = String.Empty
    End Sub

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
