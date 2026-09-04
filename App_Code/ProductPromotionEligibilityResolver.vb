Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class ProductPromotionEligibilityContext
    Public Property CompanyId As Integer
    Public Property Listino As Integer
    Public Property CurrentUserId As Integer
    Public Property IsAuthenticated As Boolean
    Public Property EvaluationDate As Date

    Public ReadOnly Property CacheKey As String
        Get
            Return CompanyId.ToString(CultureInfo.InvariantCulture) & ":" &
                   Listino.ToString(CultureInfo.InvariantCulture) & ":" &
                   If(IsAuthenticated, "1", "0") & ":" &
                   CurrentUserId.ToString(CultureInfo.InvariantCulture) & ":" &
                   EvaluationDate.ToString("yyyyMMdd", CultureInfo.InvariantCulture)
        End Get
    End Property
End Class

Public Class ProductPromotionEligibilityOffer
    Public Property OfferId As Integer
    Public Property OfferDetailId As Integer
    Public Property ArticleId As Integer
    Public Property TargetTCId As Integer
    Public Property OwnerUserId As Integer
    Public Property QntMinima As Decimal
    Public Property Multipli As Decimal
    Public Property PriceNet As Decimal
    Public Property PriceGross As Decimal
    Public Property DiscountPercent As Decimal
    Public Property StartsOn As Nullable(Of Date)
    Public Property EndsOn As Nullable(Of Date)
    Public Property IsExactVariant As Boolean

    Public Function AppliesToQuantity(ByVal quantity As Decimal) As Boolean
        If quantity <= 0D Then Return False
        If QntMinima > 0D Then Return quantity >= QntMinima
        If Multipli <= 0D Then Return False
        Return Decimal.Remainder(quantity, Multipli) = 0D
    End Function
End Class

Public Class ProductPromotionEligibilityResult
    Public Sub New()
        AuthorizedOffers = New List(Of ProductPromotionEligibilityOffer)()
    End Sub

    Public Property BasePriceNet As Decimal
    Public Property BasePriceGross As Decimal
    Public Property AuthorizedOffers As List(Of ProductPromotionEligibilityOffer)
    Public Property AppliedOffer As ProductPromotionEligibilityOffer

    Public ReadOnly Property HasAppliedOffer As Boolean
        Get
            Return AppliedOffer IsNot Nothing
        End Get
    End Property

    Public ReadOnly Property EffectivePriceNet As Decimal
        Get
            If AppliedOffer IsNot Nothing Then Return AppliedOffer.PriceNet
            Return BasePriceNet
        End Get
    End Property

    Public ReadOnly Property EffectivePriceGross As Decimal
        Get
            If AppliedOffer IsNot Nothing Then Return AppliedOffer.PriceGross
            Return BasePriceGross
        End Get
    End Property
End Class

Friend Class ProductPromotionEligibilityRawOffer
    Public Property OfferId As Integer
    Public Property OfferDetailId As Integer
    Public Property ArticleId As Integer
    Public Property TargetTCId As Integer
    Public Property OwnerUserId As Integer
    Public Property QntMinima As Decimal
    Public Property Multipli As Decimal
    Public Property PromoPriceNet As Decimal
    Public Property DiscountPercent As Decimal
    Public Property StartsOn As Nullable(Of Date)
    Public Property EndsOn As Nullable(Of Date)
End Class

Public Module ProductPromotionEligibilityResolver
    Private Const RequestCachePrefix As String = "KeepStore.ProductPromotionEligibility."

    Public Function CreateContext(ByVal ctx As HttpContext,
                                  ByVal companyId As Integer,
                                  ByVal listino As Integer) As ProductPromotionEligibilityContext
        Dim loginId As Integer = SessionInt(ctx, "LoginId", SessionInt(ctx, "LoginID", 0))
        Dim currentUserId As Integer = SessionInt(ctx, "UtentiId", 0)

        Return New ProductPromotionEligibilityContext() With {
            .CompanyId = companyId,
            .Listino = listino,
            .CurrentUserId = If(currentUserId > 0, currentUserId, 0),
            .IsAuthenticated = (loginId > 0 AndAlso currentUserId > 0),
            .EvaluationDate = Date.Today
        }
    End Function

    Public Function CreateContext(ByVal ctx As HttpContext,
                                  ByVal listino As Integer) As ProductPromotionEligibilityContext
        Return CreateContext(ctx,
                             FirstPositive(SessionInt(ctx, "AziendaID", 0),
                                           SessionInt(ctx, "AziendaId", 0),
                                           SessionInt(ctx, "AziendeId", 0)),
                             listino)
    End Function

    Public Function Resolve(ByVal connectionString As String,
                            ByVal eligibilityContext As ProductPromotionEligibilityContext,
                            ByVal articleId As Integer,
                            ByVal tcId As Integer,
                            ByVal quantity As Decimal,
                            ByVal basePriceNet As Decimal,
                            ByVal basePriceGross As Decimal) As ProductPromotionEligibilityResult
        Dim result As New ProductPromotionEligibilityResult() With {
            .BasePriceNet = basePriceNet,
            .BasePriceGross = basePriceGross
        }

        If String.IsNullOrWhiteSpace(connectionString) OrElse
           eligibilityContext Is Nothing OrElse
           eligibilityContext.CompanyId <= 0 OrElse
           eligibilityContext.Listino <= 0 OrElse
           articleId <= 0 OrElse
           basePriceNet <= 0D OrElse
           basePriceGross <= 0D Then
            Return result
        End If

        Dim snapshot As Dictionary(Of Integer, List(Of ProductPromotionEligibilityRawOffer)) =
            LoadAuthorizedSnapshot(connectionString, eligibilityContext)
        Dim rawOffers As List(Of ProductPromotionEligibilityRawOffer) = Nothing
        If snapshot Is Nothing OrElse Not snapshot.TryGetValue(articleId, rawOffers) OrElse rawOffers Is Nothing Then
            Return result
        End If

        Dim exactOffers As New List(Of ProductPromotionEligibilityOffer)()
        Dim articleOffers As New List(Of ProductPromotionEligibilityOffer)()

        For Each raw As ProductPromotionEligibilityRawOffer In rawOffers
            Dim isExact As Boolean = (tcId > 0 AndAlso raw.TargetTCId = tcId)
            Dim isArticleFallback As Boolean = (raw.TargetTCId <= 0)
            If Not isExact AndAlso Not isArticleFallback Then Continue For

            Dim offer As ProductPromotionEligibilityOffer = BuildOffer(raw, basePriceNet, basePriceGross, isExact)
            If offer Is Nothing Then Continue For

            result.AuthorizedOffers.Add(offer)
            If isExact Then
                exactOffers.Add(offer)
            Else
                articleOffers.Add(offer)
            End If
        Next

        SortOffers(result.AuthorizedOffers)
        SortOffers(exactOffers)
        SortOffers(articleOffers)

        result.AppliedOffer = BestApplicableOffer(exactOffers, quantity)
        If result.AppliedOffer Is Nothing Then
            result.AppliedOffer = BestApplicableOffer(articleOffers, quantity)
        End If

        Return result
    End Function

    Private Function LoadAuthorizedSnapshot(ByVal connectionString As String,
                                            ByVal eligibilityContext As ProductPromotionEligibilityContext) As Dictionary(Of Integer, List(Of ProductPromotionEligibilityRawOffer))
        Dim cacheKey As String = RequestCachePrefix & eligibilityContext.CacheKey
        Dim current As HttpContext = HttpContext.Current
        If current IsNot Nothing AndAlso current.Items IsNot Nothing Then
            Dim cached As Dictionary(Of Integer, List(Of ProductPromotionEligibilityRawOffer)) =
                TryCast(current.Items(cacheKey), Dictionary(Of Integer, List(Of ProductPromotionEligibilityRawOffer)))
            If cached IsNot Nothing Then Return cached
        End If

        Dim snapshot As New Dictionary(Of Integer, List(Of ProductPromotionEligibilityRawOffer))()
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        Try
            Using conn As New MySqlConnection(connectionString)
                conn.Open()
                Using cmd As New MySqlCommand(BuildAuthorizedOffersSql(), conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Add("@companyId", MySqlDbType.Int32).Value = eligibilityContext.CompanyId
                    cmd.Parameters.Add("@listino", MySqlDbType.Int32).Value = eligibilityContext.Listino
                    cmd.Parameters.Add("@evaluationDate", MySqlDbType.Date).Value = eligibilityContext.EvaluationDate.Date
                    cmd.Parameters.Add("@isAuthenticated", MySqlDbType.Int32).Value = If(eligibilityContext.IsAuthenticated, 1, 0)
                    cmd.Parameters.Add("@currentUserId", MySqlDbType.Int32).Value = If(eligibilityContext.IsAuthenticated, eligibilityContext.CurrentUserId, 0)

                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            Dim raw As New ProductPromotionEligibilityRawOffer() With {
                                .ArticleId = ReadInt(reader("ArticleId"), 0),
                                .TargetTCId = ReadInt(reader("TargetTCId"), -1),
                                .OfferId = ReadInt(reader("OfferId"), 0),
                                .OfferDetailId = ReadInt(reader("OfferDetailId"), 0),
                                .OwnerUserId = ReadInt(reader("OwnerUserId"), 0),
                                .QntMinima = ReadDecimal(reader("QntMinima"), 0D),
                                .Multipli = ReadDecimal(reader("Multipli"), 0D),
                                .PromoPriceNet = ReadDecimal(reader("PromoPriceNet"), 0D),
                                .DiscountPercent = ReadDecimal(reader("DiscountPercent"), 0D),
                                .StartsOn = ReadDate(reader("StartsOn")),
                                .EndsOn = ReadDate(reader("EndsOn"))
                            }

                            If raw.ArticleId <= 0 OrElse raw.OfferId <= 0 OrElse raw.OfferDetailId <= 0 Then Continue While
                            If Not IsOwnerAuthorized(raw.OwnerUserId, eligibilityContext) Then Continue While
                            Dim rowKey As String = raw.ArticleId.ToString(CultureInfo.InvariantCulture) & ":" &
                                                   raw.TargetTCId.ToString(CultureInfo.InvariantCulture) & ":" &
                                                   raw.OfferDetailId.ToString(CultureInfo.InvariantCulture)
                            If Not seen.Add(rowKey) Then Continue While

                            If Not snapshot.ContainsKey(raw.ArticleId) Then
                                snapshot(raw.ArticleId) = New List(Of ProductPromotionEligibilityRawOffer)()
                            End If
                            snapshot(raw.ArticleId).Add(raw)
                        End While
                    End Using
                End Using
            End Using
        Catch
            snapshot.Clear()
        End Try

        If current IsNot Nothing AndAlso current.Items IsNot Nothing Then
            current.Items(cacheKey) = snapshot
        End If
        Return snapshot
    End Function

    Private Function BuildAuthorizedOffersSql() As String
        Return "SELECT va.id AS ArticleId, COALESCE(od.TCId,-1) AS TargetTCId, " &
               "       o.id AS OfferId, od.id AS OfferDetailId, COALESCE(o.UtentiId,0) AS OwnerUserId, " &
               "       COALESCE(o.QntMinima,0) AS QntMinima, COALESCE(o.Multipli,0) AS Multipli, " &
               "       COALESCE(o.Prezzo,0) AS PromoPriceNet, COALESCE(o.Sconto,0) AS DiscountPercent, " &
               "       o.DataInizio AS StartsOn, o.DataFine AS EndsOn " &
               "FROM voffertearticoli va " &
               "INNER JOIN offerte o ON o.id=va.OfferteID " &
               "INNER JOIN offertedettaglio od ON od.id=va.OfferteDettagliId AND od.OfferteId=o.id " &
               "INNER JOIN articoli a ON a.id=va.id " &
               "WHERE o.AziendeId=@companyId " &
               "  AND COALESCE(o.Abilitato,0)=1 " &
               "  AND COALESCE(a.Abilitato,0)=1 " &
               "  AND COALESCE(a.NoPromo,0)=0 " &
               "  AND (COALESCE(o.DaListino,0)<=0 OR o.DaListino<=@listino) " &
               "  AND (COALESCE(o.AListino,0)<=0 OR o.AListino>=@listino) " &
               "  AND (o.DataInizio IS NULL OR o.DataInizio<=@evaluationDate) " &
               "  AND (o.DataFine IS NULL OR o.DataFine>=@evaluationDate) " &
               "  AND (COALESCE(o.UtentiId,0)<=0 OR (@isAuthenticated=1 AND @currentUserId>0 AND o.UtentiId=@currentUserId)) " &
               "  AND EXISTS (SELECT 1 FROM articoli_listini al " &
               "              WHERE al.ArticoliId=va.id AND al.NListino=@listino " &
               "                AND (COALESCE(od.TCId,-1)<=0 OR COALESCE(al.TCId,-1)=od.TCId)) " &
               "ORDER BY va.id ASC, CASE WHEN COALESCE(od.TCId,-1)>0 THEN 0 ELSE 1 END ASC, " &
               "         CASE WHEN COALESCE(o.QntMinima,0)>0 THEN 0 ELSE 1 END ASC, " &
               "         COALESCE(o.QntMinima,0) ASC, COALESCE(o.Multipli,0) ASC, o.id ASC, od.id ASC"
    End Function

    Private Function BuildOffer(ByVal raw As ProductPromotionEligibilityRawOffer,
                                ByVal basePriceNet As Decimal,
                                ByVal basePriceGross As Decimal,
                                ByVal isExactVariant As Boolean) As ProductPromotionEligibilityOffer
        If raw Is Nothing OrElse basePriceNet <= 0D OrElse basePriceGross <= 0D Then Return Nothing
        If raw.QntMinima <= 0D AndAlso raw.Multipli <= 0D Then Return Nothing

        Dim promoNet As Decimal = raw.PromoPriceNet
        If promoNet <= 0D AndAlso raw.DiscountPercent > 0D AndAlso raw.DiscountPercent < 100D Then
            promoNet = basePriceNet * (1D - (raw.DiscountPercent / 100D))
        End If
        If promoNet <= 0D OrElse promoNet >= basePriceNet Then Return Nothing

        Dim promoGross As Decimal = promoNet * (basePriceGross / basePriceNet)
        If promoGross <= 0D OrElse promoGross >= basePriceGross Then Return Nothing

        Return New ProductPromotionEligibilityOffer() With {
            .OfferId = raw.OfferId,
            .OfferDetailId = raw.OfferDetailId,
            .ArticleId = raw.ArticleId,
            .TargetTCId = raw.TargetTCId,
            .OwnerUserId = raw.OwnerUserId,
            .QntMinima = raw.QntMinima,
            .Multipli = raw.Multipli,
            .PriceNet = promoNet,
            .PriceGross = promoGross,
            .DiscountPercent = CalculateDiscount(basePriceNet, promoNet),
            .StartsOn = raw.StartsOn,
            .EndsOn = raw.EndsOn,
            .IsExactVariant = isExactVariant
        }
    End Function

    Private Function BestApplicableOffer(ByVal offers As List(Of ProductPromotionEligibilityOffer),
                                         ByVal quantity As Decimal) As ProductPromotionEligibilityOffer
        If offers Is Nothing Then Return Nothing
        For Each offer As ProductPromotionEligibilityOffer In offers
            If offer.AppliesToQuantity(quantity) Then Return offer
        Next
        Return Nothing
    End Function

    Private Function IsOwnerAuthorized(ByVal ownerUserId As Integer,
                                       ByVal eligibilityContext As ProductPromotionEligibilityContext) As Boolean
        If ownerUserId <= 0 Then Return True
        Return eligibilityContext IsNot Nothing AndAlso
               eligibilityContext.IsAuthenticated AndAlso
               eligibilityContext.CurrentUserId > 0 AndAlso
               ownerUserId = eligibilityContext.CurrentUserId
    End Function

    Private Sub SortOffers(ByVal offers As List(Of ProductPromotionEligibilityOffer))
        If offers Is Nothing Then Return
        offers.Sort(Function(left As ProductPromotionEligibilityOffer, right As ProductPromotionEligibilityOffer) As Integer
                        Dim exactCompare As Integer = If(left.IsExactVariant, 0, 1).CompareTo(If(right.IsExactVariant, 0, 1))
                        If exactCompare <> 0 Then Return exactCompare
                        Dim ruleCompare As Integer = If(left.QntMinima > 0D, 0, 1).CompareTo(If(right.QntMinima > 0D, 0, 1))
                        If ruleCompare <> 0 Then Return ruleCompare
                        Dim priceCompare As Integer = left.PriceNet.CompareTo(right.PriceNet)
                        If priceCompare <> 0 Then Return priceCompare
                        Return left.OfferDetailId.CompareTo(right.OfferDetailId)
                    End Function)
    End Sub

    Private Function CalculateDiscount(ByVal basePrice As Decimal, ByVal promoPrice As Decimal) As Decimal
        If basePrice <= 0D OrElse promoPrice <= 0D OrElse promoPrice >= basePrice Then Return 0D
        Return Math.Round((1D - (promoPrice / basePrice)) * 100D, 0, MidpointRounding.AwayFromZero)
    End Function

    Private Function SessionInt(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Integer) As Integer
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse ctx.Session(key) Is Nothing Then Return defaultValue
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(ctx.Session(key), CultureInfo.InvariantCulture), parsed) Then Return parsed
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function FirstPositive(ParamArray values() As Integer) As Integer
        If values Is Nothing Then Return 0
        For Each value As Integer In values
            If value > 0 Then Return value
        Next
        Return 0
    End Function

    Private Function ReadInt(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        Dim parsed As Integer
        If Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), parsed) Then Return parsed
        Return defaultValue
    End Function

    Private Function ReadDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        If TypeOf value Is Decimal OrElse TypeOf value Is Double OrElse TypeOf value Is Single OrElse
           TypeOf value Is Integer OrElse TypeOf value Is Long OrElse TypeOf value Is Short Then
            Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
        End If
        Dim parsed As Decimal
        If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, parsed) Then Return parsed
        If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), parsed) Then Return parsed
        Return defaultValue
    End Function

    Private Function ReadDate(ByVal value As Object) As Nullable(Of Date)
        If value Is Nothing OrElse value Is DBNull.Value Then Return Nothing
        If TypeOf value Is Date Then Return DirectCast(value, Date)
        Dim parsed As Date
        If Date.TryParse(Convert.ToString(value), CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then Return parsed
        Return Nothing
    End Function
End Module
