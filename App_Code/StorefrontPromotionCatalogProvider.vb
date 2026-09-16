Imports System
Imports System.Web.UI.WebControls

Public Module StorefrontPromotionCatalogProvider
    Private Const CompanyParameter As String = "promoCompanyId"
    Private Const ListinoParameter As String = "promoListino"
    Private Const EvaluationDateParameter As String = "promoEvaluationDate"
    Private Const AuthenticatedParameter As String = "promoIsAuthenticated"
    Private Const CurrentUserParameter As String = "promoCurrentUserId"
    Private Const CampaignParameter As String = "promoCampaignId"

    Public Function BuildMainCatalogJoin() As String
        Return " INNER JOIN (" & BuildAuthorizedProductsSql() & ") ks_promo_catalog" &
               " ON ks_promo_catalog.ArticleId=vsuperarticoli.id" &
               " AND ks_promo_catalog.ArticleListPriceId=vsuperarticoli.ArticoliListiniId" &
               " AND (ks_promo_catalog.PreferredTCId<=0" &
               "      OR ks_promo_catalog.PreferredTCId=COALESCE(NULLIF(vsuperarticoli.TCid,0),atc_default.DefaultTCid,-1))"
    End Function

    Public Function BuildFacetCatalogJoin() As String
        Return " INNER JOIN (" & BuildAuthorizedProductsSql() & ") ks_promo_catalog" &
               " ON ks_promo_catalog.ArticleId=varticolibase.id "
    End Function

    Public Function BuildLegacyCatalogJoin() As String
        Return " INNER JOIN (" & BuildAuthorizedProductsSql() & ") ks_promo_catalog" &
               " ON ks_promo_catalog.ArticleId=a.id" &
               " AND ks_promo_catalog.ArticleListPriceId=a.ArticoliListiniId "
    End Function

    Public Function MainPreferredTCSelect() As String
        Return "ks_promo_catalog.PreferredTCId AS PromotionTCId,"
    End Function

    Public Sub AddParameters(ByVal parameters As ParameterCollection,
                             ByVal eligibilityContext As ProductPromotionEligibilityContext)
        If parameters Is Nothing Then Throw New ArgumentNullException("parameters")
        If eligibilityContext Is Nothing OrElse
           eligibilityContext.CompanyId <= 0 OrElse
           eligibilityContext.Listino <= 0 OrElse
           eligibilityContext.CampaignId < 0 Then
            Throw New ArgumentException("Invalid promotion catalog context.", "eligibilityContext")
        End If

        parameters.Add(New Parameter(CompanyParameter, TypeCode.Int32, eligibilityContext.CompanyId.ToString()))
        parameters.Add(New Parameter(ListinoParameter, TypeCode.Int32, eligibilityContext.Listino.ToString()))
        parameters.Add(New Parameter(EvaluationDateParameter, TypeCode.DateTime,
                                     eligibilityContext.EvaluationDate.ToString("yyyy-MM-dd", Globalization.CultureInfo.InvariantCulture)))
        parameters.Add(New Parameter(AuthenticatedParameter, TypeCode.Int32, If(eligibilityContext.IsAuthenticated, "1", "0")))
        parameters.Add(New Parameter(CurrentUserParameter, TypeCode.Int32,
                                     If(eligibilityContext.IsAuthenticated, eligibilityContext.CurrentUserId, 0).ToString()))
        parameters.Add(New Parameter(CampaignParameter, TypeCode.Int32, eligibilityContext.CampaignId.ToString()))
    End Sub

    Private Function BuildAuthorizedProductsSql() As String
        Return "SELECT ranked.ArticleId,ranked.ArticleListPriceId,ranked.PreferredTCId," &
               " ranked.OfferId,ranked.OfferDetailId,ranked.OfferDescription,ranked.OfferImage," &
               " ranked.OfferStartsOn,ranked.OfferEndsOn,ranked.OfferMinimumQuantity," &
               " ranked.OfferMultipleQuantity,ranked.OfferPrice,ranked.OfferDiscount" &
               " FROM (" &
               "SELECT catalog.id AS ArticleId," &
               "       catalog.ArticoliListiniId AS ArticleListPriceId," &
               "       CASE WHEN COALESCE(detail.TCId,-1)>0 THEN detail.TCId ELSE -1 END AS PreferredTCId," &
               "       offer_header.id AS OfferId,detail.id AS OfferDetailId," &
               "       legacy_detail.Descrizione AS OfferDescription,legacy_detail.Immagine AS OfferImage," &
               "       offer_header.DataInizio AS OfferStartsOn,offer_header.DataFine AS OfferEndsOn," &
               "       offer_header.QntMinima AS OfferMinimumQuantity,offer_header.Multipli AS OfferMultipleQuantity," &
               "       offer_header.Prezzo AS OfferPrice,offer_header.Sconto AS OfferDiscount," &
               "       ROW_NUMBER() OVER (PARTITION BY catalog.id ORDER BY" &
               "           CASE WHEN COALESCE(detail.TCId,-1)>0 THEN 0 ELSE 1 END ASC," &
               "           CASE" &
               "             WHEN COALESCE(offer_header.Prezzo,0)>0 THEN offer_header.Prezzo" &
               "             WHEN COALESCE(offer_header.Sconto,0)>0 AND offer_header.Sconto<100" &
               "               THEN catalog.Prezzo*(1-(offer_header.Sconto/100))" &
               "             ELSE 0" &
               "           END ASC," &
               "           detail.id ASC,catalog.ArticoliListiniId ASC) AS PromotionRank " &
               "FROM vOfferteDettagli legacy_detail " &
               "INNER JOIN varticolilistini catalog ON catalog.NListino=?" & ListinoParameter &
               " AND (COALESCE(legacy_detail.MarcheId,0)=0 OR catalog.MarcheId=legacy_detail.MarcheId)" &
               " AND (COALESCE(legacy_detail.SettoriId,0)=0 OR catalog.SettoriId=legacy_detail.SettoriId)" &
               " AND (COALESCE(legacy_detail.CategorieId,0)=0 OR catalog.CategorieId=legacy_detail.CategorieId)" &
               " AND (COALESCE(legacy_detail.TipologieId,0)=0 OR catalog.TipologieId=legacy_detail.TipologieId)" &
               " AND (COALESCE(legacy_detail.GruppiId,0)=0 OR catalog.GruppiId=legacy_detail.GruppiId)" &
               " AND (COALESCE(legacy_detail.SottoGruppiId,0)=0 OR catalog.SottoGruppiId=legacy_detail.SottoGruppiId)" &
               " AND (COALESCE(legacy_detail.ArticoliId,0)=0 OR catalog.id=legacy_detail.ArticoliId) " &
               "INNER JOIN voffertearticoli mapped ON mapped.id=catalog.id" &
               " AND mapped.OfferteID=legacy_detail.OfferteId" &
               " AND mapped.OfferteDettagliId=legacy_detail.id " &
               "INNER JOIN offerte offer_header ON offer_header.id=mapped.OfferteID " &
               "INNER JOIN offertedettaglio detail ON detail.id=mapped.OfferteDettagliId" &
               " AND detail.OfferteId=offer_header.id " &
               "INNER JOIN articoli article ON article.id=catalog.id " &
               "WHERE offer_header.AziendeId=?" & CompanyParameter &
               " AND legacy_detail.AziendeId=?" & CompanyParameter &
               " AND COALESCE(offer_header.Abilitato,0)=1" &
               " AND COALESCE(article.Abilitato,0)=1" &
               " AND COALESCE(article.NoPromo,0)=0" &
               " AND (COALESCE(detail.TCId,-1)<=0 OR COALESCE(catalog.TCId,-1)=detail.TCId)" &
               " AND (COALESCE(offer_header.DaListino,0)<=0 OR offer_header.DaListino<=?" & ListinoParameter & ")" &
               " AND (COALESCE(offer_header.AListino,0)<=0 OR offer_header.AListino>=?" & ListinoParameter & ")" &
               " AND (offer_header.DataInizio IS NULL OR offer_header.DataInizio<=?" & EvaluationDateParameter & ")" &
               " AND (offer_header.DataFine IS NULL OR offer_header.DataFine>=?" & EvaluationDateParameter & ")" &
               " AND (COALESCE(offer_header.UtentiId,0)<=0" &
               "      OR (?" & AuthenticatedParameter & "=1 AND ?" & CurrentUserParameter & ">0" &
               "          AND offer_header.UtentiId=?" & CurrentUserParameter & "))" &
               " AND (?" & CampaignParameter & "<=0 OR offer_header.id=?" & CampaignParameter & ")" &
               " AND NOT (COALESCE(offer_header.QntMinima,0)>0 AND COALESCE(offer_header.Multipli,0)>0)" &
               " AND (COALESCE(offer_header.QntMinima,0)>0 OR COALESCE(offer_header.Multipli,0)>0)" &
               " AND COALESCE(catalog.Prezzo,0)>0" &
               " AND (CASE" &
               "        WHEN COALESCE(offer_header.Prezzo,0)>0 THEN offer_header.Prezzo" &
               "        WHEN COALESCE(offer_header.Sconto,0)>0 AND offer_header.Sconto<100" &
               "          THEN catalog.Prezzo*(1-(offer_header.Sconto/100))" &
               "        ELSE 0" &
               "      END)>0" &
               " AND (CASE" &
               "        WHEN COALESCE(offer_header.Prezzo,0)>0 THEN offer_header.Prezzo" &
               "        WHEN COALESCE(offer_header.Sconto,0)>0 AND offer_header.Sconto<100" &
               "          THEN catalog.Prezzo*(1-(offer_header.Sconto/100))" &
               "        ELSE 0" &
               "      END)<catalog.Prezzo" &
               ") ranked WHERE ranked.PromotionRank=1"
    End Function
End Module
