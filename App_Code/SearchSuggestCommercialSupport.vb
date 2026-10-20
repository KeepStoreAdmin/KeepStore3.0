Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class SearchSuggestCommercialException
    Inherits Exception
    Public ReadOnly Code As String
    Public ReadOnly Status As Integer
    Public Sub New(ByVal code As String, ByVal status As Integer)
        MyBase.New(code)
        Me.Code = code
        Me.Status = status
    End Sub
End Class

Public NotInheritable Class SearchSuggestParameter
    Public ReadOnly Name As String
    Public ReadOnly Value As Object
    Public ReadOnly Kind As DbType
    Public Sub New(ByVal name As String, ByVal value As Object)
        Me.New(name, value, If(TypeOf value Is Decimal, DbType.Decimal, If(TypeOf value Is Integer, DbType.Int32, DbType.String)))
    End Sub
    Public Sub New(ByVal name As String, ByVal value As Object, ByVal kind As DbType)
        Me.Name = name
        Me.Value = value
        Me.Kind = kind
    End Sub
End Class

' Request-local orchestration only. The delegates are I/O boundaries for compiled
' offline fixtures; no request/configuration flag can replace them in production.
Public NotInheritable Class SearchSuggestCommercialSupport
    Private ReadOnly _context As HttpContext
    Private ReadOnly _query As Func(Of String, IList(Of SearchSuggestParameter), DataTable)
    Private ReadOnly _settings As ConnectionStringSettings
    Private ReadOnly _batchLoader As Func(Of String, ProductPromotionEligibilityContext, ProductPromotionEligibilityBatch)
    Private _batch As ProductPromotionEligibilityBatch
    Public ReadOnly PriceContext As StorefrontPriceDisplayContext
    Public ReadOnly Eligibility As ProductPromotionEligibilityContext
    Public ReadOnly VariantsEnabled As Boolean

    Public Sub New(ByVal context As HttpContext)
        Me.New(context, ConfigurationManager.ConnectionStrings("EntropicConnectionString"), Nothing, Nothing)
    End Sub

    Public Sub New(ByVal context As HttpContext, ByVal settings As ConnectionStringSettings,
                   ByVal query As Func(Of String, IList(Of SearchSuggestParameter), DataTable),
                   ByVal batchLoader As Func(Of String, ProductPromotionEligibilityContext, ProductPromotionEligibilityBatch))
        ValidateSettings(settings)
        _context = context
        _settings = settings
        _query = If(query, AddressOf ExecuteDatabaseQuery)
        _batchLoader = If(batchLoader, AddressOf ProductPromotionEligibilityResolver.CreateBatch)
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        PriceContext = InitializeContext(context, tenant, _query)
        VariantsEnabled = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("TC")) = 1
        Eligibility = ProductPromotionEligibilityResolver.CreateContext(context, PriceContext.CompanyId, PriceContext.PriceListId, ReadCampaign(context.Request))
        ' Same identity derivation as the canonical resolver, using the validated
        ' settings supplied to this request (also works with synthetic settings).
        Eligibility.DatabaseScopeKey = StorefrontSeoTenantContext.BuildDatabaseScopeKey(settings.ConnectionString)
        If Eligibility.IsAuthenticated <> PriceContext.IsAuthenticated Then Fail("storefront_context_invalid", 403)
    End Sub

    Private Shared Function ReadCampaign(ByVal request As HttpRequest) As Integer
        Dim values As String() = request.QueryString.GetValues("pid")
        If values Is Nothing Then Return 0
        Dim campaign As Integer
        If values.Length <> 1 OrElse Not System.Text.RegularExpressions.Regex.IsMatch(values(0), "^[1-9][0-9]{0,9}$") OrElse
           Not Integer.TryParse(values(0), campaign) OrElse campaign <= 0 OrElse request.QueryString("inpromo") = "0" Then
            Fail("invalid_campaign", 400)
        End If
        Return campaign
    End Function

    Public Shared Sub ValidateSettings(ByVal settings As ConnectionStringSettings)
        If settings Is Nothing OrElse settings.Name <> "EntropicConnectionString" OrElse
           Not String.Equals(settings.ProviderName, "MySql.Data.MySqlClient", StringComparison.Ordinal) OrElse
           String.IsNullOrWhiteSpace(settings.ConnectionString) Then Fail("connection_configuration_invalid", 503)
        Try
            Dim explicit As New System.Data.Common.DbConnectionStringBuilder()
            explicit.ConnectionString = settings.ConnectionString
            Dim hasServer As Boolean = False
            Dim hasDatabase As Boolean = False
            For Each key As String In explicit.Keys
                If String.IsNullOrWhiteSpace(Convert.ToString(explicit(key), CultureInfo.InvariantCulture)) Then Continue For
                Select Case key.ToLowerInvariant()
                    Case "server", "host", "data source", "address", "addr", "network address" : hasServer = True
                    Case "database", "initial catalog" : hasDatabase = True
                End Select
            Next
            If Not hasServer OrElse Not hasDatabase Then Fail("connection_configuration_invalid", 503)
            Dim builder As New MySqlConnectionStringBuilder(settings.ConnectionString)
            If String.IsNullOrWhiteSpace(builder.Server) OrElse String.IsNullOrWhiteSpace(builder.Database) Then
                Fail("connection_configuration_invalid", 503)
            End If
        Catch ex As SearchSuggestCommercialException
            Throw
        Catch
            Fail("connection_configuration_invalid", 503)
        End Try
    End Sub

    Public Shared Function InitializeContext(ByVal context As HttpContext, ByVal tenant As StorefrontSeoTenantIdentity,
                                            ByVal query As Func(Of String, IList(Of SearchSuggestParameter), DataTable)) As StorefrontPriceDisplayContext
        If context Is Nothing OrElse context.Session Is Nothing Then Fail("storefront_context_required", 403)
        If tenant Is Nothing OrElse tenant.CompanyId <= 0 OrElse tenant.DefaultPriceListId <= 0 Then Fail("unknown_storefront", 421)
        Dim session = context.Session
        Dim company As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(session("KeepStore.PriceDisplay.TenantCompanyId"))
        Dim list As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(session("KeepStore.PriceDisplay.TenantPriceListId"))
        Dim mode As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(session("KeepStore.PriceDisplay.TenantMode"))
        If company <> tenant.CompanyId OrElse list <> tenant.DefaultPriceListId OrElse
           (mode <> 1 AndAlso mode <> 2) OrElse StorefrontCommercialIsolationPolicy.PositiveInteger(session("AziendaID")) <> company Then
            Fail("storefront_context_required", 403)
        End If
        StorefrontPriceDisplayContextProvider.SetTenantDefaults(context, company, list, mode)
        Dim result As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(context)
        If result Is Nothing Then Fail("storefront_context_invalid", 403)
        Dim login As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(session("LoginId"))
        Dim owner As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(session("UtentiId"))
        If Not result.IsAuthenticated Then
            If login > 0 OrElse owner > 0 OrElse StorefrontCommercialIsolationPolicy.PositiveInteger(session("AuthenticatedAziendaID")) > 0 Then
                Fail("storefront_context_invalid", 403)
            End If
            Return result
        End If
        If login <= 0 OrElse owner <= 0 Then Fail("storefront_context_invalid", 403)
        Dim parameters As New List(Of SearchSuggestParameter) From {
            New SearchSuggestParameter("@loginId", login, DbType.Int32),
            New SearchSuggestParameter("@companyId", company, DbType.Int32)}
        Dim rows As DataTable = query("SELECT id,AziendeID,listino,utentiid,IvaTipo,IdEsenzioneIva,ValoreEsenzioneIva," &
            "DescrizioneEsenzioneIva,AbilitatoIvaReverseCharge FROM vlogin WHERE id=@loginId AND AziendeID=@companyId " &
            "AND Abilitato=1 AND UtentiAbilitato=1 LIMIT 2", parameters)
        If rows Is Nothing OrElse rows.Rows.Count <> 1 Then Fail("account_context_invalid", 403)
        Dim row As DataRow = rows.Rows(0)
        If Convert.ToInt32(row("id")) <> login OrElse Convert.ToInt32(row("utentiid")) <> owner OrElse
           StorefrontCommercialIsolationPolicy.ResolveAuthenticatedPriceList(company, Convert.ToInt32(row("AziendeID")),
                Convert.ToInt32(row("listino"))) <> result.PriceListId Then Fail("account_context_invalid", 403)
        ' A changed fiscal/account scope must be rehydrated by the normal page,
        ' never silently updated or downgraded by this read-only endpoint.
        ' Compare the effective pair produced by PageMaster.ApplyAuthenticatedPriceDisplayState:
        ' an invalid/absent exemption suppresses the rate, and an absent rate suppresses the ID.
        Dim exemptionId As Integer = StorefrontPriceDisplayContextProvider.NormalizeExemptionId(row("IdEsenzioneIva"))
        Dim vatOverride As Nullable(Of Decimal) = Nothing
        If exemptionId >= 0 Then vatOverride = StorefrontPriceDisplayContextProvider.NormalizeVatOverride(row("ValoreEsenzioneIva"))
        If Not vatOverride.HasValue Then exemptionId = -1
        If StorefrontPriceDisplayContextProvider.ResolveDisplayMode(row("IvaTipo"), CType(mode, StorefrontVatDisplayMode)) <> result.DisplayMode OrElse
           Not Nullable.Equals(vatOverride, result.VatOverride) OrElse
           exemptionId <> result.ExemptionId OrElse
           (StorefrontCommercialIsolationPolicy.PositiveInteger(row("AbilitatoIvaReverseCharge")) = 1) <> result.ReverseChargeEnabled Then
            Fail("account_context_stale", 403)
        End If
        Return result
    End Function

    Public Function Parameters() As List(Of SearchSuggestParameter)
        Return New List(Of SearchSuggestParameter) From {
            New SearchSuggestParameter("?promoCompanyId", Eligibility.CompanyId, DbType.Int32),
            New SearchSuggestParameter("?promoListino", Eligibility.Listino, DbType.Int32),
            New SearchSuggestParameter("?promoEvaluationDate", Eligibility.EvaluationDate, DbType.Date),
            New SearchSuggestParameter("?promoIsAuthenticated", If(Eligibility.IsAuthenticated, 1, 0), DbType.Int32),
            New SearchSuggestParameter("?promoCurrentUserId", Eligibility.CurrentUserId, DbType.Int32),
            New SearchSuggestParameter("?promoCampaignId", Eligibility.CampaignId, DbType.Int32),
            New SearchSuggestParameter("?ksRcEnabled", If(PriceContext.ReverseChargeEnabled, 1, 0), DbType.Int32),
            New SearchSuggestParameter("?ksHasVatOverride", If(PriceContext.VatOverride.HasValue, 1, 0), DbType.Int32),
            New SearchSuggestParameter("?ksVatOverride", If(PriceContext.VatOverride.HasValue, CType(PriceContext.VatOverride.Value, Object), DBNull.Value), DbType.Decimal),
            New SearchSuggestParameter("?suggestVariants", If(VariantsEnabled, 1, 0), DbType.Int32)}
    End Function

    Public Function CatalogFrom() As String
        Dim gross As String = StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.Prezzo",
            "vsuperarticoli.PrezzoIvato", "vsuperarticoli.IdIvaRC", "vsuperarticoli.ValoreIvaRC",
            "?ksRcEnabled", "?ksHasVatOverride", "?ksVatOverride")
        Dim price As String = StorefrontEffectivePriceSqlBuilder.BuildQuantityOneDisplayPriceExpression(
            gross, PriceContext.IsVatExcluded)
        Dim normalizedTC As String = "CASE WHEN ?suggestVariants=1 THEN COALESCE(NULLIF(vsuperarticoli.TCId,0),-1) ELSE -1 END"
        ' Normalize the required projection after ALL joins, before window counts,
        ' filtering, ranking and LIMIT. Legacy promo columns are deliberately absent:
        ' repetitions differing only in those columns are not commercial conflicts.
        ' Different required facts remain ambiguous; never pick an arbitrary row.
        Dim fields As String() = {"id", "NListino", "Codice", "Ean", "Descrizione1", "Descrizione2",
            "DescrizioneLunga", "DescrizioneHTML", "MarcheDescrizione", "SettoriDescrizione", "CategorieDescrizione",
            "TipologieDescrizione", "GruppiDescrizione", "SottogruppiDescrizione", "Img1", "Img2", "Img3", "Img4",
            "Prezzo", "PrezzoIvato", "IdIvaRC", "ValoreIvaRC", "Giacenza", "Disponibilita", "Impegnata", "InOrdine",
            "ScortaMinima", "Vetrina", "visite", "Ricondizionato", "NoteRicondizionato", "DataCreazione",
            "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottoGruppiId", "MarcheId"}
        Dim projection As New List(Of String)()
        For Each field As String In fields
            projection.Add("vsuperarticoli." & field)
        Next
        For image As Integer = 1 To 6
            projection.Add("i.Immagine" & image.ToString(CultureInfo.InvariantCulture))
        Next
        Return " FROM (SELECT normalized.*, COUNT(*) OVER(PARTITION BY normalized.id,normalized.SuggestTC,normalized.NListino) AS SuggestMultiplicity" &
            " FROM (SELECT DISTINCT " & String.Join(",", projection.ToArray()) & "," & price & " AS SuggestPrice," &
            " CASE WHEN ks_qty1_price.AppliedPromoNet>0 THEN 1 ELSE 0 END AS SuggestOffer," &
            " CASE WHEN ks_promo_catalog.ArticleId IS NOT NULL THEN 1 ELSE 0 END AS SuggestHasPromotion," &
            " GREATEST(CAST(0 AS DECIMAL(38,16)),vsuperarticoli.Giacenza-vsuperarticoli.Impegnata) AS SuggestAvailable," &
            " (" & normalizedTC & ") AS SuggestTC" &
            " FROM vsuperarticoli INNER JOIN articoli enabled ON enabled.id=vsuperarticoli.id AND enabled.Abilitato=1" &
            StorefrontPromotionCatalogProvider.BuildQuantityOnePriceJoin(False) &
            StorefrontPromotionCatalogProvider.BuildSuggestPromotionJoin() &
            " LEFT JOIN immagini i ON i.id=vsuperarticoli.id" &
            " WHERE vsuperarticoli.NListino=?promoListino" &
            " AND COALESCE(vsuperarticoli.Export,0)<>0" &
            " AND (?suggestVariants=1 OR COALESCE(vsuperarticoli.TCId,-1)<=0)" &
            " AND (COALESCE(vsuperarticoli.TCId,-1)<=0 OR EXISTS(SELECT 1 FROM articoli_tagliecolori valid_tc" &
            " WHERE valid_tc.id=vsuperarticoli.TCId AND valid_tc.ArticoliId=vsuperarticoli.id))" &
            ") normalized) v WHERE 1=1 "
    End Function

    Public Function Execute(ByVal sql As String, ByVal parameters As List(Of SearchSuggestParameter)) As DataTable
        If _batch Is Nothing Then _batch = _batchLoader(_settings.ConnectionString, Eligibility)
        If _batch Is Nothing OrElse _batch.Status <> ProductPromotionEligibilityLoadStatus.Success Then Fail("promotion_unavailable", 503)
        Dim allParameters As List(Of SearchSuggestParameter) = Me.Parameters()
        allParameters.AddRange(parameters)
        Dim rows As DataTable = _query(sql, allParameters)
        If rows Is Nothing Then Fail("commercial_unavailable", 503)
        Return rows
    End Function

    Public Sub VerifyCandidateProjection(ByVal selectSql As String, ByVal parameters As List(Of SearchSuggestParameter))
        Dim start As Integer = selectSql.IndexOf(" FROM (SELECT", StringComparison.Ordinal)
        If start < 0 Then Fail("commercial_query_invalid", 503)
        Dim result As DataTable = Execute("SELECT COUNT(*) AS InvalidCount" & selectSql.Substring(start) &
            " AND (v.SuggestPrice IS NULL OR v.SuggestPrice<=0 OR v.SuggestAvailable IS NULL" &
            " OR v.Disponibilita IS NULL OR v.SuggestMultiplicity<>1)", parameters)
        If result.Rows.Count <> 1 OrElse Convert.ToInt32(result.Rows(0)("InvalidCount")) <> 0 Then Fail("commercial_unavailable", 503)
    End Sub

    Public Sub VerifyRows(ByVal rows As DataTable)
        If rows.Rows.Count = 0 Then Return
        If _batch Is Nothing Then _batch = _batchLoader(_settings.ConnectionString, Eligibility)
        If _batch Is Nothing OrElse _batch.Status <> ProductPromotionEligibilityLoadStatus.Success Then Fail("promotion_unavailable", 503)
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        For Each row As DataRow In rows.Rows
            Dim id As Integer = Convert.ToInt32(row("id"))
            Dim tc As Integer = Convert.ToInt32(row("TCid"))
            If Convert.ToInt32(row("SuggestPriceList")) <> PriceContext.PriceListId Then Fail("commercial_scope_mismatch", 503)
            If id <= 0 OrElse tc < -1 OrElse (tc > 0 AndAlso Not VariantsEnabled) OrElse Convert.ToInt32(row("SuggestMultiplicity")) <> 1 OrElse
               Not seen.Add(id.ToString() & ":" & tc.ToString()) Then Fail("commercial_ambiguous", 503)
            For Each name As String In New String() {"Prezzo", "PrezzoFinale", "Giacenza", "Disponibilita", "Impegnata"}
                If Not rows.Columns.Contains(name) OrElse row.IsNull(name) Then Fail("commercial_unavailable", 503)
            Next
            Dim net As Decimal = Convert.ToDecimal(row("Prezzo"), CultureInfo.InvariantCulture)
            Dim gross As Nullable(Of Decimal) = StorefrontEffectivePriceResolver.ResolveEffectiveGross(net,
                If(row.IsNull("PrezzoIvato"), New Nullable(Of Decimal)(), Convert.ToDecimal(row("PrezzoIvato"))),
                PriceContext.ReverseChargeEnabled, PriceContext.VatOverride,
                If(row.IsNull("IdIvaRC"), -1, Convert.ToInt32(row("IdIvaRC"))),
                If(row.IsNull("ValoreIvaRC"), New Nullable(Of Decimal)(), Convert.ToDecimal(row("ValoreIvaRC"))))
            If net <= 0D OrElse Not gross.HasValue OrElse gross.Value <= 0D Then Fail("commercial_unavailable", 503)
            Dim promo As ProductPromotionEligibilityResult = _batch.ResolveForProduct(id, tc, 1D, net, gross.Value)
            If promo Is Nothing OrElse promo.Status <> ProductPromotionEligibilityLoadStatus.Success Then Fail("promotion_unavailable", 503)
            Dim display As Nullable(Of Decimal) = PriceContext.SelectPrice(promo.EffectivePriceNet, promo.EffectivePriceGross)
            If Not display.HasValue OrElse Decimal.Round(display.Value, 2, MidpointRounding.AwayFromZero) <>
                Convert.ToDecimal(row("PrezzoFinale")) OrElse promo.HasAppliedOffer <> (Convert.ToInt32(row("InOfferta")) = 1) Then
                Fail("commercial_projection_mismatch", 503)
            End If
            Dim availability As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItem(row, _context)
            If availability.AvailableQty <> Convert.ToDecimal(row("Disponibilita")) Then Fail("availability_unavailable", 503)
        Next
    End Sub

    Private Function ExecuteDatabaseQuery(ByVal sql As String, ByVal parameters As IList(Of SearchSuggestParameter)) As DataTable
        Using connection As New MySqlConnection(_settings.ConnectionString)
            connection.Open()
            Using command As MySqlCommand = connection.CreateCommand()
                command.CommandText = sql
                For Each value As SearchSuggestParameter In parameters
                    Dim parameter As New MySqlParameter() With {.ParameterName = value.Name, .DbType = value.Kind, .Value = value.Value}
                    command.Parameters.Add(parameter)
                Next
                Using reader = command.ExecuteReader()
                    Dim result As New DataTable()
                    result.Load(reader)
                    Return result
                End Using
            End Using
        End Using
    End Function

    Private Shared Sub Fail(ByVal code As String, ByVal status As Integer)
        Throw New SearchSuggestCommercialException(code, status)
    End Sub
End Class
