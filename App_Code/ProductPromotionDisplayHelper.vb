Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class ProductPromotionOffer
    Public Property Label As String
    Public Property PriceGross As Decimal
    Public Property DiscountPercent As Decimal
    Public Property StartsOn As Nullable(Of Date)
    Public Property EndsOn As Nullable(Of Date)
End Class

Public Class ProductPromotionDisplayModel
    Public Property HasOffers As Boolean
    Public Property ListPriceGross As Decimal
    Public Property StandardPriceGross As Decimal
    Public Property BestPriceGross As Decimal
    Public Property BestDiscountPercent As Decimal
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
        model.ListPriceGross = baseGrossPrice
        model.StandardPriceGross = baseGrossPrice
        model.BestPriceGross = baseGrossPrice

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

                If model.Offers.Count = 0 Then
                    Using cmdProduct As New MySqlCommand(BuildProductRowSql(), cn)
                        cmdProduct.Parameters.Add("@articleId", MySqlDbType.Int32).Value = articleId
                        cmdProduct.Parameters.Add("@companyId", MySqlDbType.Int32).Value = companyId
                        cmdProduct.Parameters.Add("@listino", MySqlDbType.Int32).Value = listino

                        Using rdrProduct As MySqlDataReader = cmdProduct.ExecuteReader()
                            LoadOffers(rdrProduct, model, baseNetPrice, baseGrossPrice)
                        End Using
                    End Using
                End If
            End Using
        Catch
            model.Offers.Clear()
        End Try

        model.HasOffers = (model.Offers.Count > 0)
        If model.HasOffers AndAlso model.BestDiscountPercent <= 0D AndAlso model.BestPriceGross > 0D AndAlso model.StandardPriceGross > model.BestPriceGross Then
            model.BestDiscountPercent = Math.Round((1D - (model.BestPriceGross / model.StandardPriceGross)) * 100D, 0, MidpointRounding.AwayFromZero)
        End If
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

    Private Function BuildProductRowSql() As String
        Return "SELECT COALESCE(OfferteDettagliId,0) AS OfferteId, @companyId AS AziendeId, " &
               "OfferteDataInizio AS DataInizio, OfferteDataFine AS DataFine, OfferteQntMinima AS QntMinima, " &
               "OfferteMultipli AS Multipli, OffertePrezzo AS Prezzo, OfferteSconto AS Sconto " &
               "FROM vsuperarticoli " &
               "WHERE ID=@articleId " &
               "  AND NListino=@listino " &
               "  AND COALESCE(InOfferta,0)=1 " &
               "  AND COALESCE(OfferteDettagliId,0)>0 " &
               "  AND (OfferteDataInizio IS NULL OR OfferteDataInizio<=CURDATE()) " &
               "  AND (OfferteDataFine IS NULL OR OfferteDataFine>=CURDATE()) " &
               "ORDER BY CASE WHEN COALESCE(OfferteMultipli,0)=10 THEN 0 WHEN COALESCE(OfferteQntMinima,0)>0 THEN 1 WHEN COALESCE(OfferteMultipli,0)>0 THEN 2 ELSE 3 END, " &
               "         COALESCE(OfferteMultipli,0) ASC, COALESCE(OfferteQntMinima,0) ASC, COALESCE(OfferteDettagliId,0) ASC"
    End Function

    Private Sub LoadOffers(ByVal rdr As MySqlDataReader,
                           ByVal model As ProductPromotionDisplayModel,
                           ByVal baseNetPrice As Decimal,
                           ByVal baseGrossPrice As Decimal)
        If rdr Is Nothing OrElse model Is Nothing Then Return

        While rdr.Read()
            Dim offer As ProductPromotionOffer = BuildOffer(rdr, baseNetPrice, baseGrossPrice)
            If offer Is Nothing OrElse offer.PriceGross <= 0D Then Continue While
            model.Offers.Add(offer)
            If model.BestPriceGross <= 0D OrElse offer.PriceGross < model.BestPriceGross Then
                model.BestPriceGross = offer.PriceGross
                model.BestDiscountPercent = offer.DiscountPercent
            End If
        End While
    End Sub

    Private Function BuildOffer(ByVal rdr As IDataRecord, ByVal baseNetPrice As Decimal, ByVal baseGrossPrice As Decimal) As ProductPromotionOffer
        Dim qntMinima As Decimal = FieldDecimal(rdr, "QntMinima")
        Dim multipli As Decimal = FieldDecimal(rdr, "Multipli")
        Dim promoNet As Decimal = FieldDecimal(rdr, "Prezzo")
        Dim discount As Decimal = FieldDecimal(rdr, "Sconto")
        Dim grossPrice As Decimal = 0D

        If promoNet > 0D Then
            Dim vatFactor As Decimal = 1D
            If baseNetPrice > 0D AndAlso baseGrossPrice > 0D Then
                vatFactor = baseGrossPrice / baseNetPrice
            End If
            grossPrice = promoNet * vatFactor
        ElseIf discount > 0D AndAlso baseGrossPrice > 0D Then
            grossPrice = baseGrossPrice * (1D - (discount / 100D))
        End If

        If grossPrice <= 0D Then Return Nothing

        Dim label As String
        If multipli > 0D Then
            label = "MULTIPLI " & FormatQuantity(multipli) & " PZ."
        ElseIf qntMinima > 0D Then
            label = "MINIMO " & FormatQuantity(qntMinima) & " PZ."
        Else
            label = "PROMO"
        End If

        Dim effectiveDiscount As Decimal = discount
        If effectiveDiscount <= 0D AndAlso baseGrossPrice > grossPrice Then
            effectiveDiscount = Math.Round((1D - (grossPrice / baseGrossPrice)) * 100D, 0, MidpointRounding.AwayFromZero)
        End If

        Return New ProductPromotionOffer() With {
            .Label = label,
            .PriceGross = grossPrice,
            .DiscountPercent = effectiveDiscount,
            .StartsOn = FieldDate(rdr, "DataInizio"),
            .EndsOn = FieldDate(rdr, "DataFine")
        }
    End Function

    Private Function RenderHtml(ByVal model As ProductPromotionDisplayModel) As String
        If model Is Nothing OrElse Not model.HasOffers Then Return String.Empty

        Dim sb As New StringBuilder()
        sb.Append("<div class=""ks-product-promos"" aria-label=""Offerte attive"">")
        sb.Append("<div class=""ks-product-promos__head"">")
        sb.Append("<span class=""ks-product-promos__eyebrow"">Offerte attive</span>")
        If model.BestDiscountPercent > 0D Then
            sb.Append("<span class=""ks-product-promos__discount"">-").Append(HtmlEncode(FormatQuantity(model.BestDiscountPercent))).Append("%</span>")
        End If
        sb.Append("</div>")
        sb.Append("<div class=""ks-product-promos__summary"">")
        sb.Append("<span>Prezzo di Listino <strong>").Append(HtmlEncode(FormatMoney(model.ListPriceGross))).Append("</strong></span>")
        sb.Append("<span>Prezzo Standard <strong>").Append(HtmlEncode(FormatMoney(model.StandardPriceGross))).Append("</strong></span>")
        sb.Append("<span>Prezzo promo <strong>").Append(HtmlEncode(FormatMoney(model.BestPriceGross))).Append("</strong></span>")
        sb.Append("</div>")
        sb.Append("<div class=""ks-product-promos__list"">")
        For Each offer As ProductPromotionOffer In model.Offers
            sb.Append("<div class=""ks-product-promos__item"">")
            sb.Append("<span class=""ks-product-promos__label"">").Append(HtmlEncode(offer.Label)).Append("</span>")
            sb.Append("<strong>").Append(HtmlEncode(FormatMoney(offer.PriceGross))).Append("</strong>")
            sb.Append("<span class=""ks-product-promos__dates"">").Append(HtmlEncode(FormatDateRange(offer.StartsOn, offer.EndsOn))).Append("</span>")
            sb.Append("</div>")
        Next
        sb.Append("</div>")
        sb.Append("</div>")
        Return sb.ToString()
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
            Return "dal " & startDate.Value.ToString("dd/MM/yyyy", ItCulture) & " al " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        End If
        If endDate.HasValue Then Return "fino al " & endDate.Value.ToString("dd/MM/yyyy", ItCulture)
        Return "promo attiva"
    End Function

    Private Function FormatQuantity(ByVal value As Decimal) As String
        Return value.ToString("0.##", CultureInfo.InvariantCulture)
    End Function

    Private Function HtmlEncode(ByVal value As String) As String
        Return HttpUtility.HtmlEncode(If(value, String.Empty))
    End Function
End Module
