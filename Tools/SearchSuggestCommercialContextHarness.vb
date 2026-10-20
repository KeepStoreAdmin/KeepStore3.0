Option Strict On
Option Explicit On
Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.SessionState

Public Module SearchSuggestCommercialContextHarness
    Private passed As Integer
    Private commands As New List(Of String)()
    Private captures As New List(Of IList(Of SearchSuggestParameter))()
    Private products As DataTable
    Private account As DataTable
    Private invalidProjection As Integer
    Private batchStatus As ProductPromotionEligibilityLoadStatus
    Private batchLoads As Integer
    Private offers As New List(Of ProductPromotionEligibilityRawOffer)()
    Private relationalRows As DataTable
    Private callerCases As Object()
    Private ReadOnly settings As New ConnectionStringSettings("EntropicConnectionString",
        "Server=synthetic.invalid;Database=synthetic;User Id=synthetic;", "MySql.Data.MySqlClient")

    Public Sub Main(ByVal args As String())
        Try
            If args.Length = 0 Then Throw New Exception("HEADER_CALLER_URLS_REQUIRED")
            callerCases = New System.Web.Script.Serialization.JavaScriptSerializer().Deserialize(Of Object())(File.ReadAllText(args(0)))
            Dim candidate As Boolean = args.Length > 1 AndAlso args(1) = "--review-candidate"
            If candidate Then
                RunRev1(True)
                Console.WriteLine("REVIEW_CANDIDATE=c624db0343b4f38b42ba49651c2c503d46a8e837; EXPECTED_DEFECTS=4")
            Else
                Run()
                RunRev1(False)
            End If
            Console.WriteLine("SEARCH_SUGGEST_ASSERTIONS=" & passed)
            Console.WriteLine("SQL_EXECUTED_ON_MYSQL=NO; REAL_ACCOUNT_LOGIN=NO; DATABASE_CONNECTIONS=0")
        Catch ex As Exception
            Dim cause As Exception = ex.GetBaseException()
            Console.WriteLine("HARNESS_FAILED=" & cause.GetType().Name & ":" & cause.Message)
            Environment.ExitCode = 1
        End Try
    End Sub

    Private Sub Assert(ByVal condition As Boolean, ByVal name As String)
        If Not condition Then Throw New Exception(name)
        passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Sub Reject(ByVal action As Action, ByVal name As String)
        Try
            action()
        Catch ex As SearchSuggestCommercialException
            Assert(ex.Status >= 400 AndAlso Not ex.Code.Contains("synthetic"), name)
            Return
        End Try
        Throw New Exception("EXPECTED_REJECTION:" & name)
    End Sub

    Private Function Context(ByVal company As Integer, ByVal list As Integer,
                             Optional ByVal authenticated As Boolean = False,
                             Optional ByVal queryString As String = "") As HttpContext
        Dim ctx As New HttpContext(New HttpRequest("", "https://tenant" & company & ".invalid/search_suggest.aspx", queryString),
                                   New HttpResponse(New StringWriter()))
        Dim data As New SessionStateItemCollection()
        data("AziendaID") = company
        data("KeepStore.PriceDisplay.TenantCompanyId") = company
        data("KeepStore.PriceDisplay.TenantPriceListId") = list
        data("KeepStore.PriceDisplay.TenantMode") = 2
        data("Listino") = If(authenticated, list + 3, list)
        If authenticated Then
            data("LoginId") = 11
            data("UtentiId") = 51
            data("AuthenticatedAziendaID") = company
            data("IvaTipo") = 2
            data("Iva_Utente") = -1
            data("IdEsenzioneIva") = -1
            data("AbilitatoIvaReverseCharge") = 0
        End If
        Dim state As New HttpSessionStateContainer("synthetic", data, New HttpStaticObjectsCollection(),
            20, False, HttpCookieMode.UseCookies, SessionStateMode.InProc, True)
        SessionStateUtility.AddHttpSessionStateToContext(ctx, state)
        Dim tenant = StorefrontCanonicalHostPolicy.CreateTenant(company, "Synthetic", "", "tenant" & company & ".invalid", "", "", list)
        Assert(StorefrontCanonicalHostPolicy.SelectExactTenant(New List(Of StorefrontSeoTenantIdentity) From {tenant},
            "tenant" & company & ".invalid", False) Is tenant, "host scoped tenant " & company)
        ctx.Items("KeepStore.StorefrontSeoTenant") = tenant
        HttpContext.Current = ctx
        Return ctx
    End Function

    Private Function MakeSupport(ByVal ctx As HttpContext) As SearchSuggestCommercialSupport
        commands.Clear()
        captures.Clear()
        batchLoads = 0
        Return New SearchSuggestCommercialSupport(ctx, settings, AddressOf Query, AddressOf LoadBatch)
    End Function

    Private Function Query(ByVal sql As String, ByVal parameters As IList(Of SearchSuggestParameter)) As DataTable
        commands.Add(sql)
        captures.Add(parameters)
        If sql.Contains("FROM vlogin") Then Return account
        If relationalRows IsNot Nothing Then Return RelationalQuery(sql, parameters)
        If sql.Contains("COUNT(*) AS InvalidCount") Then
            Dim table As New DataTable()
            table.Columns.Add("InvalidCount", GetType(Integer))
            table.Rows.Add(invalidProjection)
            Return table
        End If
        Return products.Copy()
    End Function

    ' This is a deliberately bounded relational counterexample model, not a SQL
    ' engine. Required transformations are linked to the real generated SQL;
    ' model-derived rows/counts then cross the real endpoint/resolver boundary.
    Private Function RelationalQuery(ByVal sql As String, ByVal parameters As IList(Of SearchSuggestParameter)) As DataTable
        Dim targetList As Integer = Convert.ToInt32(parameters.First(Function(x) x.Name = "?promoListino").Value)
        Dim listPredicate As Boolean = sql.Contains("vsuperarticoli.NListino=?promoListino")
        Dim enabledPredicate As Boolean = sql.Contains("enabled.Abilitato=1")
        Dim exportPredicate As Boolean = sql.Contains("COALESCE(vsuperarticoli.Export,0)<>0")
        Dim deduplicate As Boolean = sql.Contains("FROM (SELECT DISTINCT ") AndAlso Not sql.Contains("SELECT DISTINCT vsuperarticoli.*")
        Dim selected As New List(Of DataRow)()
        For Each row As DataRow In relationalRows.Rows
            If listPredicate AndAlso Convert.ToInt32(row("SuggestPriceList")) <> targetList Then Continue For
            If enabledPredicate AndAlso Convert.ToInt32(row("Enabled")) <> 1 Then Continue For
            If exportPredicate AndAlso (row.IsNull("Export") OrElse Convert.ToInt32(row("Export")) = 0) Then Continue For
            selected.Add(row)
        Next
        If deduplicate Then
            Dim facts As New HashSet(Of String)(StringComparer.Ordinal)
            selected = selected.Where(Function(row) facts.Add(AuthoritativeFacts(row))).ToList()
        End If
        Dim multiplicities = selected.GroupBy(Function(row) Identity(row)).ToDictionary(Function(g) g.Key, Function(g) g.Count())
        If sql.Contains("COUNT(*) AS InvalidCount") Then
            Dim invalid As New DataTable()
            invalid.Columns.Add("InvalidCount", GetType(Integer))
            invalid.Rows.Add(selected.Where(Function(row) multiplicities(Identity(row)) <> 1 OrElse row.IsNull("Giacenza") OrElse row.IsNull("Disponibilita")).Count())
            Return invalid
        End If
        If sql.Contains(" AND v.SuggestAvailable > 0") Then selected = selected.Where(Function(row) Convert.ToDecimal(row("Disponibilita")) > 0D).ToList()
        For Each spec In parameters
            If spec.Name = "@minPrice" Then selected = selected.Where(Function(row) Convert.ToDecimal(row("PrezzoFinale")) >= Convert.ToDecimal(spec.Value)).ToList()
            If spec.Name = "@maxPrice" Then selected = selected.Where(Function(row) Convert.ToDecimal(row("PrezzoFinale")) <= Convert.ToDecimal(spec.Value)).ToList()
        Next
        Dim exact As Integer = selected.Where(Function(row) Convert.ToString(row("Codice")) = "SKU120").Count()
        If sql.Contains("PrezzoFinale ASC") Then selected = selected.OrderBy(Function(row) Convert.ToDecimal(row("PrezzoFinale"))).ToList()
        If sql.Contains("PrezzoFinale DESC") Then selected = selected.OrderByDescending(Function(row) Convert.ToDecimal(row("PrezzoFinale"))).ToList()
        Dim limit = Regex.Match(sql, " LIMIT ([0-9]+)$")
        If limit.Success Then selected = selected.Take(Integer.Parse(limit.Groups(1).Value)).ToList()
        Dim result As DataTable = relationalRows.Clone()
        For Each row As DataRow In selected
            result.ImportRow(row)
            result.Rows(result.Rows.Count - 1)("SuggestMultiplicity") = multiplicities(Identity(row))
            result.Rows(result.Rows.Count - 1)("ExactMatches") = exact
        Next
        Return result
    End Function

    Private Function Identity(ByVal row As DataRow) As String
        Return CStr(row("id")) & ":" & CStr(row("TCid")) & ":" & CStr(row("SuggestPriceList"))
    End Function

    Private Function AuthoritativeFacts(ByVal row As DataRow) As String
        Dim fields As New List(Of String)()
        For Each column As DataColumn In row.Table.Columns
            If {"LegacyPromo", "LegacyPriceRow", "SuggestMultiplicity", "ExactMatches", "RankScore", "Enabled", "Export"}.Contains(column.ColumnName) Then Continue For
            Dim value = row(column)
            fields.Add(column.ColumnName & "=" & If(Convert.IsDBNull(value), "<NULL>", Convert.ToString(value, CultureInfo.InvariantCulture)))
        Next
        Return String.Join("|", fields)
    End Function

    Private Function RawRows(ByVal support As SearchSuggestCommercialSupport, Optional ByVal tc As Integer = -1) As DataTable
        Dim table As DataTable = ProductRows(support, tc)
        For Each name As String In {"Enabled", "Export", "LegacyPromo", "LegacyPriceRow"}
            table.Columns.Add(name, GetType(Object))
        Next
        table.Rows(0)("Enabled") = 1 : table.Rows(0)("Export") = 1
        table.Rows(0)("LegacyPromo") = 0 : table.Rows(0)("LegacyPriceRow") = 1
        Return table
    End Function

    Private Sub FiscalFixture(ByVal ctx As HttpContext, ByVal row As DataRow)
        HttpContext.Current = ctx
        Dim master As New SearchSuggestMasterFiscalFixture(Convert.ToInt32(row("AziendeID")))
        master.ApplyAuthenticatedPriceDisplayState(
            row("IvaTipo"), row("IdEsenzioneIva"), row("ValoreEsenzioneIva"), row("DescrizioneEsenzioneIva"), row("AbilitatoIvaReverseCharge"))
    End Sub

    Private Function Failed(ByVal action As Action) As Boolean
        Try
            action()
            Return False
        Catch ex As SearchSuggestCommercialException
            Return True
        End Try
    End Function

    Private Function Result(ByVal support As SearchSuggestCommercialSupport, Optional ByVal recent As Boolean = False, Optional ByVal limit As Integer = 8) As Dictionary(Of String, Object)
        Dim page = Endpoint(support)
        Dim filters = Invoke(page, "ReadFilters")
        If recent Then Return DirectCast(Invoke(page, "BuildRecentResult", New List(Of Integer) From {120}, filters, limit), Dictionary(Of String, Object))
        Return DirectCast(Invoke(page, "BuildSearchResult", "SKU120", filters, limit), Dictionary(Of String, Object))
    End Function

    Private Sub RunRev1(ByVal candidate As Boolean)
        relationalRows = Nothing
        Dim ctx = Context(2, 10, True)
        account = AccountRow(2, 13)
        account.Rows(0)("ValoreEsenzioneIva") = 0D
        FiscalFixture(ctx, account.Rows(0))
        Assert(CInt(ctx.Session("IdEsenzioneIva")) = -1 AndAlso CDec(ctx.Session("Iva_Utente")) = -1D, "F01 exact master body discards rate with absent exemption")
        Dim rejected As Boolean = Failed(Sub() MakeSupport(ctx))
        Assert(rejected = candidate, "F01 same ID=-1/rate=0 fixture " & If(candidate, "reproduces stale rejection", "accepted"))
        If Not candidate Then
            For Each id As Integer In {-1, 0, 5}
                For Each rate As Object In New Object() {DBNull.Value, "invalid", -1D, 0D, 7.125D}
                    ctx = Context(2, 10, True) : account = AccountRow(2, 13)
                    account.Rows(0)("IdEsenzioneIva") = id : account.Rows(0)("ValoreEsenzioneIva") = rate
                    FiscalFixture(ctx, account.Rows(0))
                    Dim support = MakeSupport(ctx)
                    Assert(support.PriceContext.ExemptionId = CInt(ctx.Session("IdEsenzioneIva")), "F01 master exemption parity " & id & "/" & Convert.ToString(rate))
                    Dim expected = StorefrontPriceDisplayContextProvider.NormalizeVatOverride(ctx.Session("Iva_Utente"))
                    Assert(Nullable.Equals(support.PriceContext.VatOverride, expected), "F01 master override parity " & id & "/" & Convert.ToString(rate))
                Next
            Next
            For Each changed As String In {"ValoreEsenzioneIva", "IdEsenzioneIva", "utentiid", "listino"}
                ctx = Context(2, 10, True) : account = AccountRow(2, 13)
                account.Rows(0)("IdEsenzioneIva") = 5 : account.Rows(0)("ValoreEsenzioneIva") = 7.125D
                FiscalFixture(ctx, account.Rows(0))
                account.Rows(0)(changed) = If(changed = "ValoreEsenzioneIva", CType(8.125D, Object), 99)
                Reject(Sub() MakeSupport(ctx), "F01 effective scope change rejected " & changed)
            Next
        End If

        ctx = Context(2, 10) : Dim commercial = MakeSupport(ctx)
        relationalRows = RawRows(commercial)
        relationalRows.Rows(0)("Export") = 0
        Dim output = Result(commercial)
        Assert(CInt(output("total")) = If(candidate, 1, 0), "F02 same enabled Export=0 row " & If(candidate, "reproduces admission", "excluded"))

        relationalRows = Nothing
        Dim caller = DirectCast(callerCases(0), Dictionary(Of String, Object))
        ctx = Context(2, 10, False, New Uri(CStr(caller("url"))).Query.TrimStart("?"c))
        commercial = MakeSupport(ctx) : products = ProductRows(commercial)
        output = Result(commercial)
        Dim filterPreserved As Boolean = commands.Last().Contains(" AND v.SuggestAvailable > 0") AndAlso CStr(output("catalogUrl")).Contains("disponibile=1")
        Assert(filterPreserved <> candidate, "F03 actual header canonical URL " & If(candidate, "reproduces lost availability", "preserves availability"))

        ctx = Context(2, 10) : commercial = MakeSupport(ctx)
        relationalRows = RawRows(commercial)
        relationalRows.ImportRow(relationalRows.Rows(0))
        relationalRows.Rows(1)("LegacyPromo") = 77 : relationalRows.Rows(1)("LegacyPriceRow") = 99
        rejected = Failed(Sub() Result(commercial))
        Assert(rejected = candidate, "F04 same equivalent facts with legacy/join repetition " & If(candidate, "reproduces global rejection", "accepted"))
        If candidate Then
            relationalRows = Nothing
            Return
        End If
        VerifyRev1RelationalCases()
        VerifyCallerCases()
        relationalRows = Nothing
        Console.WriteLine("REV1_RELATIONAL_MODEL=PASS; SQL_PLAN_STRUCTURE_CHECKED=YES; SQL_EXECUTED_ON_MYSQL=NO")
    End Sub

    Private Sub VerifyRev1RelationalCases()
        Dim ctx = Context(2, 10) : ctx.Session("TC") = 1
        Dim commercial = MakeSupport(ctx)
        Dim sql As String = commercial.CatalogFrom()
        Assert(sql.Contains("enabled.Abilitato=1") AndAlso sql.Contains("vsuperarticoli.NListino=?promoListino"), "F02 model enabled and list predicates present in real SQL")
        Dim distinctAt As Integer = sql.IndexOf("FROM (SELECT DISTINCT ", StringComparison.Ordinal)
        Dim sourceAt As Integer = sql.IndexOf(" FROM vsuperarticoli", StringComparison.Ordinal)
        Dim normalizedAt As Integer = sql.IndexOf(") normalized", StringComparison.Ordinal)
        Dim windowAt As Integer = sql.IndexOf("COUNT(*) OVER(PARTITION BY normalized.id,normalized.SuggestTC,normalized.NListino)", StringComparison.Ordinal)
        Assert(distinctAt >= 0 AndAlso windowAt >= 0 AndAlso sourceAt > distinctAt AndAlso normalizedAt > sourceAt, "F04 distinct authority source feeds identity window")
        Assert(Not sql.Contains("vsuperarticoli.*") AndAlso Not sql.Contains("SELECT DISTINCT normalized.*"), "F04 projection explicit instead of legacy view wildcard")
        Dim sourceFields As String = sql.Substring(distinctAt, sourceAt - distinctAt)
        For Each forbidden As String In {"InOfferta", "PrezzoPromo", "PrezzoOfferta", "ArticoliListiniId"}
            Assert(Not sourceFields.Contains("vsuperarticoli." & forbidden), "F04 legacy/surrogate field absent " & forbidden)
        Next
        Dim imageJoinAt As Integer = sql.IndexOf("LEFT JOIN immagini", StringComparison.Ordinal)
        Assert(imageJoinAt > sourceAt AndAlso imageJoinAt < normalizedAt, "F04 image join inside distinct source before window and outer exact count")
        For Each fact As String In {"Prezzo", "PrezzoIvato", "IdIvaRC", "ValoreIvaRC", "Giacenza", "Impegnata", "Disponibilita", "InOrdine", "ScortaMinima"}
            Assert(sourceFields.Contains("vsuperarticoli." & fact), "F04 authoritative field retained " & fact)
        Next
        For Each publish As Object In New Object() {0, DBNull.Value, 1, -1}
            For Each enabled As Integer In {0, 1}
                For Each list As Integer In {1, 10}
                    relationalRows = RawRows(commercial)
                    relationalRows.Rows(0)("Export") = publish : relationalRows.Rows(0)("Enabled") = enabled : relationalRows.Rows(0)("SuggestPriceList") = list
                    Dim expected As Integer = If(Not Convert.IsDBNull(publish) AndAlso Convert.ToInt32(If(Convert.IsDBNull(publish), 0, publish)) <> 0 AndAlso enabled = 1 AndAlso list = 10, 1, 0)
                    For Each recent As Boolean In {False, True}
                        Dim output = Result(commercial, recent, 1)
                        Assert(CInt(output("total")) = expected, "F02 relational publication matrix " & Convert.ToString(publish) & "/" & enabled & "/" & list & "/recent=" & recent)
                        Assert(commands.Last().Contains("COALESCE(vsuperarticoli.Export,0)<>0") AndAlso commands(commands.Count - 2).Contains("COALESCE(vsuperarticoli.Export,0)<>0"), "F02 both candidate count and result source scoped")
                    Next
                Next
            Next
        Next
        For Each mode As String In {"", "ai", "marketplace"}
            ctx = Context(2, 10, False, "mode=" & mode) : commercial = MakeSupport(ctx)
            relationalRows = RawRows(commercial) : relationalRows.Rows(0)("Export") = 0
            Dim output = Result(commercial, False, 1)
            Assert(CInt(output("total")) = 0 AndAlso Not CBool(DirectCast(output("strong"), Dictionary(Of String, Object))("canRedirect")), "F02 mode and exact redirect excludes hidden row " & mode)
        Next
        ctx = Context(2, 10) : ctx.Session("TC") = 1 : commercial = MakeSupport(ctx)
        For Each fact As String In {"Prezzo", "PrezzoIvato", "IdIvaRC", "ValoreIvaRC", "Giacenza", "Impegnata", "Disponibilita", "InOrdine", "ScortaMinima"}
            relationalRows = RawRows(commercial)
            relationalRows.ImportRow(relationalRows.Rows(0))
            relationalRows.Rows(1)(fact) = Convert.ToDecimal(relationalRows.Rows(1)(fact)) + 1D
            Reject(Sub() Result(commercial), "F04 conflicting fact rejected before LIMIT " & fact)
        Next
        commercial = MakeSupport(ctx)
        relationalRows = RawRows(commercial)
        Dim batchBeforeRequest As Integer = batchLoads
        For i As Integer = 1 To 101
            relationalRows.ImportRow(relationalRows.Rows(0))
            relationalRows.Rows(i)("LegacyPromo") = i
            relationalRows.Rows(i)("LegacyPriceRow") = i + 1
        Next
        Dim clean = Result(commercial, False, 1)
        Assert(CInt(clean("total")) = 1 AndAlso CBool(DirectCast(clean("strong"), Dictionary(Of String, Object))("canRedirect")), "F04 102 equivalent join rows deduplicate before exact uniqueness and LIMIT")
        Assert(batchLoads - batchBeforeRequest = 1, "F04 exactly one promotion batch for endpoint request")
        clean = Result(commercial, True, 1)
        Assert(CInt(clean("total")) = 1 AndAlso batchLoads - batchBeforeRequest = 1, "F04 repeated join rows recent remains coherent without another promotion batch")
        relationalRows = RawRows(commercial)
        relationalRows.ImportRow(relationalRows.Rows(0)) : relationalRows.Rows(1)("TCid") = 42
        Dim variants = Result(commercial, False, 8)
        Assert(CInt(variants("total")) = 2 AndAlso Not CBool(DirectCast(variants("strong"), Dictionary(Of String, Object))("canRedirect")), "F04 distinct variants not merged and prevent false strong redirect")
        relationalRows = RawRows(commercial)
        relationalRows.ImportRow(relationalRows.Rows(0)) : relationalRows.Rows(1)("SuggestPriceList") = 1
        clean = Result(commercial, False, 1)
        Assert(CInt(clean("total")) = 1, "F04 foreign list excluded rather than merged into active identity")
        For Each company As Integer In {1, 2}
            Dim list As Integer = If(company = 1, 1, 10)
            ctx = Context(company, list) : commercial = MakeSupport(ctx)
            relationalRows = RawRows(commercial)
            relationalRows.ImportRow(relationalRows.Rows(0))
            relationalRows.Rows(1)("id") = 121 : relationalRows.Rows(1)("Codice") = "SKU121"
            Dim page = Endpoint(commercial)
            Dim recent = DirectCast(Invoke(page, "BuildRecentResult", New List(Of Integer) From {120, 121}, Invoke(page, "ReadFilters"), 8), Dictionary(Of String, Object))
            Assert(CInt(recent("total")) = 2, "F04 distinct products remain separate in tenant " & company & "/list " & list)
        Next
    End Sub

    Private Sub VerifyCallerCases()
        relationalRows = Nothing
        For Each raw As Object In callerCases
            Dim caller = DirectCast(raw, Dictionary(Of String, Object))
            For Each recent As Boolean In {False, True}
                Dim uri As New Uri(CStr(caller(If(recent, "recentUrl", "url"))))
                Assert(uri.AbsolutePath = "/search_suggest.aspx" AndAlso uri.Host = "tenant2.invalid", "F03 actual header same-origin URL " & CStr(caller("name")))
                Dim ctx = Context(2, 10, False, uri.Query.TrimStart("?"c))
                Dim commercial = MakeSupport(ctx) : products = ProductRows(commercial)
                If CStr(caller("sort")) = "reject" Then
                    RejectFilters(Sub() Result(commercial, recent), "F03 conflicting caller aliases fail closed " & CStr(caller("name")))
                    Continue For
                End If
                Dim output = Result(commercial, recent, 1)
                Dim sql = commands.Last()
                Dim query = HttpUtility.ParseQueryString(New Uri("https://tenant2.invalid/" & CStr(output("catalogUrl"))).Query)
                Assert(sql.Contains(" AND v.SuggestAvailable > 0") AndAlso query("disponibile") = "1", "F03 caller availability reaches SQL and catalog " & CStr(caller("name")))
                Assert(query("ordinamento") = CStr(caller("sort")), "F03 caller sort reaches catalog " & CStr(caller("name")))
                If CStr(caller("name")) = "canonical" OrElse CStr(caller("name")) = "legacy" OrElse CStr(caller("name")) = "plural" Then
                    Assert(sql.Contains("SuggestPrice >= @minPrice") AndAlso sql.Contains("SuggestPrice <= @maxPrice"), "F03 caller price bounds in final SQL " & CStr(caller("name")))
                    Assert(captures.Last().Any(Function(p) p.Name = "@minPrice" AndAlso p.Kind = DbType.Decimal AndAlso CDec(p.Value) = 121.995D) AndAlso captures.Last().Any(Function(p) p.Name = "@maxPrice" AndAlso p.Kind = DbType.Decimal AndAlso CDec(p.Value) = 122.005D), "F03 caller typed bound values")
                    Assert(query("pmin") = "121.995" AndAlso query("pmax") = "122.005", "F03 caller bounds preserved in catalog URL")
                End If
                If Not recent AndAlso CStr(caller("sort")) = "p_basso" Then Assert(sql.Contains("PrezzoFinale ASC"), "F03 caller ascending SQL")
                If Not recent AndAlso CStr(caller("sort")) = "p_alto" Then Assert(sql.Contains("PrezzoFinale DESC"), "F03 caller descending SQL")
                If Not recent AndAlso CStr(caller("sort")) = "p_recenti" Then Assert(sql.Contains(" ORDER BY v.DataCreazione DESC"), "F03 caller recent sort SQL")
                If Not recent AndAlso CStr(caller("sort")) = "p_disponibilita" Then Assert(sql.Contains(" ORDER BY v.SuggestAvailable DESC"), "F03 caller stock sort SQL")
                If Not recent AndAlso CStr(caller("sort")) = "p_offerta" Then Assert(sql.Contains(" ORDER BY v.SuggestOffer DESC"), "F03 caller promotion sort SQL")
                If Not recent AndAlso CStr(caller("sort")) = "p_popolarita" Then Assert(sql.Contains(" ORDER BY RankScore DESC"), "F03 caller popularity sort SQL")
            Next
        Next
        For Each queryString As String In {"disponibile=0&disponibile=1", "pmin=100&pmin=90", "pmax=100&pmax=110", "ordinamento=p_basso&ordinamento=p_alto", "disponibile=-1", "disponibile=2", "pmin=121.995&min=122.000"}
            Dim ctx = Context(2, 10, False, queryString)
            Dim commercial = MakeSupport(ctx)
            RejectFilters(Sub() Invoke(Endpoint(commercial), "ReadFilters"), "F03 direct duplicate/conflicting filter rejected " & queryString)
            Assert(commands.Count = 0, "F03 invalid caller values rejected before product I/O")
        Next
    End Sub

    Private Sub RejectFilters(ByVal action As Action, ByVal name As String)
        Try
            action()
        Catch ex As SearchSuggestCommercialException
            Assert(ex.Status = 400 AndAlso ex.Code = "invalid_filters", name)
            Return
        End Try
        Throw New Exception("EXPECTED_INVALID_FILTERS:" & name)
    End Sub

    Private Function LoadBatch(ByVal ignored As String, ByVal scope As ProductPromotionEligibilityContext) As ProductPromotionEligibilityBatch
        batchLoads += 1
        Dim snapshot As New ProductPromotionEligibilitySnapshot() With {.Status = batchStatus}
        snapshot.OffersByArticle(120) = New List(Of ProductPromotionEligibilityRawOffer)(offers)
        Return New ProductPromotionEligibilityBatch(scope, snapshot)
    End Function

    Private Function AccountRow(ByVal company As Integer, ByVal list As Integer) As DataTable
        Dim table As New DataTable()
        For Each name As String In {"id", "AziendeID", "listino", "utentiid", "IvaTipo", "IdEsenzioneIva", "ValoreEsenzioneIva",
                                     "DescrizioneEsenzioneIva", "AbilitatoIvaReverseCharge"}
            table.Columns.Add(name, GetType(Object))
        Next
        table.Rows.Add(11, company, list, 51, 2, -1, -1, "", 0)
        Return table
    End Function

    Private Function ProductRows(ByVal support As SearchSuggestCommercialSupport, Optional ByVal tc As Integer = -1) As DataTable
        Dim table As New DataTable()
        For Each name As String In {"id", "SuggestPriceList", "TCid", "SuggestMultiplicity", "Prezzo", "PrezzoIvato", "IdIvaRC", "ValoreIvaRC",
            "Giacenza", "Impegnata", "Disponibilita", "InOrdine", "ScortaMinima", "PrezzoFinale", "InOfferta",
            "Ricondizionato", "SpeditoGratis", "RankScore", "ExactMatches", "Codice", "Ean", "Descrizione1", "Descrizione2",
            "DescrizioneLunga", "DescrizioneHTML", "MarcheDescrizione", "CategorieDescrizione", "TipologieDescrizione",
            "SettoriDescrizione", "Img1", "Img2", "Img3", "Img4", "Immagine1", "Immagine2", "Immagine3", "Immagine4", "Immagine5", "Immagine6"}
            table.Columns.Add(name, GetType(Object))
        Next
        Dim gross = StorefrontEffectivePriceResolver.ResolveEffectiveGross(100D, 122D,
            support.PriceContext.ReverseChargeEnabled, support.PriceContext.VatOverride, 3, 5D)
        Dim batch = LoadBatch("", support.Eligibility)
        Dim promo = batch.ResolveForProduct(120, tc, 1D, 100D, gross.Value)
        Dim row As DataRow = table.NewRow()
        For Each column As DataColumn In table.Columns
            row(column) = ""
        Next
        row("SuggestPriceList") = support.PriceContext.PriceListId
        row("id") = 120 : row("TCid") = tc : row("SuggestMultiplicity") = 1
        row("Prezzo") = 100D : row("PrezzoIvato") = 122D : row("IdIvaRC") = 3 : row("ValoreIvaRC") = 5D
        row("Giacenza") = 10D : row("Impegnata") = 3D : row("Disponibilita") = 7D
        row("InOrdine") = 0D : row("ScortaMinima") = 2D
        row("PrezzoFinale") = Decimal.Round(support.PriceContext.SelectPrice(promo.EffectivePriceNet, promo.EffectivePriceGross).Value, 2, MidpointRounding.AwayFromZero)
        row("InOfferta") = If(promo.HasAppliedOffer, 1, 0)
        row("Ricondizionato") = 0 : row("SpeditoGratis") = 0 : row("RankScore") = 10000000 : row("ExactMatches") = 1
        row("Codice") = "SKU120" : row("Ean") = "8000000000120" : row("Descrizione1") = "Synthetic product"
        row("SettoriDescrizione") = "Synthetic department"
        table.Rows.Add(row)
        Return table
    End Function

    Private Function Invoke(ByVal page As search_suggest, ByVal method As String, ParamArray args() As Object) As Object
        Try
            Return GetType(search_suggest).GetMethod(method, BindingFlags.Instance Or BindingFlags.NonPublic).Invoke(page, args)
        Catch ex As TargetInvocationException
            Throw ex.InnerException
        End Try
    End Function

    Private Function Endpoint(ByVal support As SearchSuggestCommercialSupport) As search_suggest
        Dim page As New search_suggest()
        For Each field As FieldInfo In GetType(System.Web.UI.Page).GetFields(BindingFlags.NonPublic Or BindingFlags.Instance)
            If field.FieldType Is GetType(HttpContext) Then field.SetValue(page, HttpContext.Current)
            If field.FieldType Is GetType(HttpRequest) Then field.SetValue(page, HttpContext.Current.Request)
            If field.FieldType Is GetType(HttpResponse) Then field.SetValue(page, HttpContext.Current.Response)
        Next
        GetType(search_suggest).GetField("_commercial", BindingFlags.NonPublic Or BindingFlags.Instance).SetValue(page, support)
        Return page
    End Function

    Private Sub Run()
        Reject(Sub() SearchSuggestCommercialSupport.ValidateSettings(Nothing), "missing connection")
        Reject(Sub() SearchSuggestCommercialSupport.ValidateSettings(New ConnectionStringSettings("other", "x", "MySql.Data.MySqlClient")), "no alias")
        Reject(Sub() SearchSuggestCommercialSupport.ValidateSettings(New ConnectionStringSettings("EntropicConnectionString", "x", "System.Data.SqlClient")), "no provider fallback")
        Reject(Sub() SearchSuggestCommercialSupport.ValidateSettings(New ConnectionStringSettings("EntropicConnectionString", "Database=SYNTHETIC_DB", "MySql.Data.MySqlClient")), "no implicit localhost")
        Reject(Sub() SearchSuggestCommercialSupport.ValidateSettings(New ConnectionStringSettings("EntropicConnectionString", "Server=synthetic.invalid", "MySql.Data.MySqlClient")), "database explicit")
        SearchSuggestCommercialSupport.ValidateSettings(settings) : Assert(True, "canonical settings")

        For Each company As Integer In {1, 2}
            Dim list As Integer = If(company = 1, 1, 10)
            Dim ctx = Context(company, list)
            Dim tenant = StorefrontSeoTenantContext.Resolve(ctx)
            Dim before As Integer = ctx.Session.Count
            Dim support = MakeSupport(ctx)
            Assert(support.PriceContext.CompanyId = company AndAlso support.PriceContext.PriceListId = list, "anonymous provenance even equal prices")
            Assert(ctx.Session.Count = before AndAlso ctx.Session.IsReadOnly, "read only session")
            products = ProductRows(support)
            support.VerifyRows(products)
            Dim sql = support.CatalogFrom()
            Assert(sql.Contains("NListino=?promoListino") AndAlso Not sql.Contains("NListino,1"), "scoped SQL")
            Assert(sql.Contains("ROW_NUMBER()") AndAlso sql.Contains("ROUND(CAST("), "canonical projection")
            Assert(sql.Contains("COUNT(*) OVER") AndAlso sql.Contains("valid_tc.ArticoliId=vsuperarticoli.id"), "identity and multiplicity")
            Assert(support.Parameters().Find(Function(spec) spec.Name = "?promoListino").Kind = DbType.Int32, "typed price list")
            Assert(support.Parameters().Find(Function(spec) spec.Name = "?ksVatOverride").Kind = DbType.Decimal, "typed VAT")
            Dim page = Endpoint(support)
            Dim filters = Invoke(page, "ReadFilters")
            ' Header-independent request values are obtained from the synthetic HttpContext.
            Dim result = DirectCast(Invoke(page, "BuildSearchResult", "SKU120", filters, 8), Dictionary(Of String, Object))
            Assert(CBool(result("strong").GetType().GetProperty("Item").GetValue(result("strong"), New Object() {"canRedirect"})), "unique exact redirect")
            Assert(commands(commands.Count - 1).EndsWith(" LIMIT 8") AndAlso Not commands(commands.Count - 1).Contains("LIMIT 80"), "limit after commercial filters")
            Assert(batchLoads <= 2, "one request batch after synthetic expected setup")
            Dim recent = DirectCast(Invoke(page, "BuildRecentResult", New List(Of Integer) From {120}, filters, 8), Dictionary(Of String, Object))
            Assert(CInt(recent("total")) = 1 AndAlso commands(commands.Count - 1).Contains("FIELD(v.id,120)"), "recent scoped query")
            For Each mode As String In {"", "ai", "marketplace"}
                filters.GetType().GetProperty("Mode").SetValue(filters, mode, Nothing)
                Invoke(page, "BuildSearchResult", "SKU120", filters, 96)
                Assert(commands(commands.Count - 1).EndsWith(" LIMIT 96"), "all modes " & mode)
            Next
            ctx.Session("KeepStore.PriceDisplay.TenantMode") = 0
            Reject(Sub() MakeSupport(ctx), "no invented fiscal default")
            ctx = Context(company, list) : ctx.Session("AuthenticatedAziendaID") = 9
            Reject(Sub() MakeSupport(ctx), "partial auth refused")
            ctx = Context(company, list) : ctx.Session("UtentiId") = 51
            Reject(Sub() MakeSupport(ctx), "partial owner refused")
            ctx = Context(company, list) : ctx.Session("Listino") = list + 5
            Reject(Sub() MakeSupport(ctx), "anonymous wrong list")
            ctx = Context(company, list, True) : account = AccountRow(company, list + 3)
            support = MakeSupport(ctx)
            Assert(support.PriceContext.PriceListId = list + 3 AndAlso support.PriceContext.IsAuthenticated, "authenticated own list")
            Assert(commands(0).Contains("Abilitato=1 AND UtentiAbilitato=1") AndAlso captures(0)(0).Kind = DbType.Int32, "account status query typed")
            account.Rows(0)("utentiid") = 88
            Reject(Sub() MakeSupport(ctx), "other owner")
            account = AccountRow(company, list + 3) : account.Rows.Clear()
            Reject(Sub() MakeSupport(ctx), "disabled or missing account")
            account = AccountRow(company, list + 4)
            Reject(Sub() MakeSupport(ctx), "changed list refused")
        Next

        For Each mode As Integer In {1, 2}
            For Each rate As Decimal In {-1D, 0D, 7.125D}
                For Each reverse As Integer In {0, 1}
                    Dim ctx = Context(1, 1, True)
                    account = AccountRow(1, 4)
                    account.Rows(0)("IvaTipo") = mode : account.Rows(0)("ValoreEsenzioneIva") = rate : account.Rows(0)("AbilitatoIvaReverseCharge") = reverse
                    account.Rows(0)("IdEsenzioneIva") = If(rate >= 0D, 5, -1)
                    FiscalFixture(ctx, account.Rows(0))
                    Dim support = MakeSupport(ctx)
                    products = ProductRows(support) : support.VerifyRows(products)
                    If mode = 2 AndAlso rate = 7.125D AndAlso reverse = 0 Then Assert(Convert.ToDecimal(products.Rows(0)("PrezzoFinale")) = 107.13D, "fractional VAT cent boundary")
                    If mode = 2 AndAlso rate = 0D AndAlso reverse = 0 Then Assert(Convert.ToDecimal(products.Rows(0)("PrezzoFinale")) = 100D, "zero VAT retained")
                    If mode = 2 AndAlso reverse = 1 Then Assert(Convert.ToDecimal(products.Rows(0)("PrezzoFinale")) = 105D, "reverse charge priority")
                    Assert(True, "real fiscal resolver parity " & mode & "/" & rate & "/" & reverse)
                Next
            Next
        Next

        Dim c = Context(2, 10) : c.Session("TC") = 1 : Dim s = MakeSupport(c)
        products = ProductRows(s, 42)
        s.VerifyRows(products) : Assert(True, "variant verified")
        Dim p = Endpoint(s)
        Dim mapped = DirectCast(Invoke(p, "MapSuggestions", products, "SKU120", Nothing), System.Collections.IList)
        Dim item = DirectCast(Invoke(p, "SerializeItem", mapped(0)), Dictionary(Of String, Object))
        Assert(CInt(item("TCId")) = 42 AndAlso CStr(item("url")).Contains("&TCId=42"), "variant JSON and URL")
        Dim browserItem As New Dictionary(Of String, Object)(item)
        browserItem("image") = "" : browserItem("image_fallback") = ""
        Console.WriteLine("SYNTHETIC_VARIANT_JSON=" & New System.Web.Script.Serialization.JavaScriptSerializer().Serialize(browserItem))
        products.Rows(0)("SuggestPriceList") = 1 : Reject(Sub() s.VerifyRows(products), "equal price wrong list rejected")
        products = ProductRows(s, 42)
        products.Rows(0)("SuggestMultiplicity") = 2 : Reject(Sub() s.VerifyRows(products), "duplicate rows blocked")
        products = ProductRows(s) : products.Rows(0)("TCid") = -2 : Reject(Sub() s.VerifyRows(products), "invalid variant blocked")
        products = ProductRows(s) : products.Rows(0)("Disponibilita") = DBNull.Value : Reject(Sub() s.VerifyRows(products), "stock unknown")
        products = ProductRows(s) : products.Rows(0)("Disponibilita") = 10D : Reject(Sub() s.VerifyRows(products), "stock net mismatch")
        products = ProductRows(s) : products.Rows(0)("PrezzoFinale") = 0D : Reject(Sub() s.VerifyRows(products), "no zero fallback")
        products = ProductRows(s) : products.Rows(0)("PrezzoFinale") = 122.01D : Reject(Sub() s.VerifyRows(products), "cent boundary mismatch")

        For Each quantity As Decimal In {1D, 3D}
            offers.Clear()
            offers.Add(New ProductPromotionEligibilityRawOffer With {.ArticleId = 120, .TargetTCId = -1, .OfferId = 7,
                .OfferDetailId = 8, .QntMinima = quantity, .PromoPriceNet = 80D})
            s = MakeSupport(Context(2, 10))
            products = ProductRows(s) : s.VerifyRows(products)
            Assert((Convert.ToInt32(products.Rows(0)("InOfferta")) = 1) = (quantity = 1D), "unit versus quantity promotion")
        Next
        offers.Clear() : batchStatus = ProductPromotionEligibilityLoadStatus.TechnicalError
        s = MakeSupport(Context(2, 10))
        Reject(Sub() s.Execute("SELECT test", New List(Of SearchSuggestParameter)), "promotion failure never empty success")
        batchStatus = ProductPromotionEligibilityLoadStatus.Success
        s = MakeSupport(Context(2, 10)) : invalidProjection = 1
        Reject(Sub() s.VerifyCandidateProjection("SELECT v.id" & s.CatalogFrom(), New List(Of SearchSuggestParameter)), "invalid candidate before LIMIT")
        invalidProjection = 0
        Dim projection = StorefrontPromotionCatalogProvider.BuildQuantityOnePriceJoin(False)
        For Each clause As String In {"offer_header.DataInizio<=?promoEvaluationDate", "offer_header.AziendeId=?promoCompanyId", "offer_header.UtentiId=?promoCurrentUserId",
                "offer_header.DataFine>=?promoEvaluationDate", "offer_header.QntMinima<=1", "allowed_tc.ArticoliId IS NOT NULL"}
            Assert(projection.Contains(clause), "real eligibility SQL " & clause)
        Next
        ' Intercept the actual endpoint query with hostile/client commercial input.
        Dim queryContext = Context(2, 10, False, "q=SKU120&min=121.995&max=122.005&sort=price-asc&st=7&listino=1&owner=999")
        s = MakeSupport(queryContext) : products = ProductRows(s)
        p = Endpoint(s)
        Dim filtersWithBounds = Invoke(p, "ReadFilters")
        Dim response = DirectCast(Invoke(p, "BuildSearchResult", "SKU120", filtersWithBounds, 1), Dictionary(Of String, Object))
        Dim productSql = commands(commands.Count - 1)
        Assert(productSql.Contains("SuggestPrice >= @minPrice") AndAlso productSql.Contains("SuggestPrice <= @maxPrice"), "range before final limit")
        Assert(productSql.IndexOf("SuggestPrice >= @minPrice") < productSql.LastIndexOf(" LIMIT 1"), "candidate beyond old pool is filtered before LIMIT")
        Assert(productSql.Contains("ORDER BY (PrezzoFinale IS NULL") AndAlso productSql.Contains("PrezzoFinale ASC"), "rounded price ordering")
        Dim capturedList As Object = Nothing
        For Each param In captures(captures.Count - 1)
            If param.Name = "?promoListino" Then capturedList = param.Value
            If param.Name = "@minPrice" OrElse param.Name = "@maxPrice" Then Assert(param.Kind = DbType.Decimal, "decimal bound parameter")
        Next
        Assert(Convert.ToInt32(capturedList) = 10, "client listino ignored")
        Assert(CStr(response("catalogUrl")).Contains("pmin=") AndAlso CStr(response("catalogUrl")).Contains("pmax=") AndAlso
               CStr(response("catalogUrl")).Contains("ordinamento=p_basso"), "catalog range and sort aliases")
        products.Rows.Clear()
        Dim empty = DirectCast(Invoke(p, "BuildSearchResult", "SKU missing", filtersWithBounds, 8), Dictionary(Of String, Object))
        Assert(CInt(empty("total")) = 0, "absent SKU is not borrowed from another list")
        Assert(Not CStr(Invoke(p, "NormalizeQuery", New String("x"c, 300))).Length > 80, "long input catalog boundary")
        Dim hostile As String = "x' OR 1=1 --"
        Invoke(p, "BuildSearchResult", hostile, filtersWithBounds, 8)
        Assert(Not commands(commands.Count - 1).Contains(hostile), "hostile input remains in parameters")
        Dim emptyLinks = DirectCast(Invoke(p, "LoadPopularQuickLinks", 5), System.Collections.IList)
        Assert(emptyLinks.Count = 0, "no hardcoded merchandise examples")
        For Each sort As String In {"price-desc", "available", "new", "promo"}
            filtersWithBounds.GetType().GetProperty("Sort").SetValue(filtersWithBounds, sort, Nothing)
            Invoke(p, "BuildSearchResult", "SKU120", filtersWithBounds, 8)
            Assert(commands(commands.Count - 1).Contains(" ORDER BY ") AndAlso commands(commands.Count - 1).EndsWith(" LIMIT 8"), "sort contract " & sort)
        Next
        For Each state As String In {"foreign-company", "stale-vat", "partial-marker"}
            Dim authContext = Context(2, 10, True)
            account = AccountRow(2, 13)
            If state = "foreign-company" Then account.Rows(0)("AziendeID") = 1
            If state = "stale-vat" Then
                account.Rows(0)("IdEsenzioneIva") = 5
                account.Rows(0)("ValoreEsenzioneIva") = 0D
            End If
            If state = "partial-marker" Then authContext.Session("AuthenticatedAziendaID") = Nothing
            Reject(Sub() MakeSupport(authContext), state)
        Next
        Dim noSession As New HttpContext(New HttpRequest("", "https://unknown.invalid/search_suggest.aspx", ""), New HttpResponse(New StringWriter()))
        Reject(Sub() SearchSuggestCommercialSupport.InitializeContext(noSession, Nothing, AddressOf Query), "session uninitialized")
        Dim tenantOne = StorefrontCanonicalHostPolicy.CreateTenant(1, "", "", "one.invalid", "", "", 1)
        Assert(StorefrontCanonicalHostPolicy.SelectExactTenant(New List(Of StorefrontSeoTenantIdentity) From {tenantOne}, "unknown.invalid", False) Is Nothing, "unknown host is not default tenant")

        Dim anonymousScope = ProductPromotionEligibilityResolver.CreateAnonymousContext("synthetic", 1, 1, Date.Today)
        For Each owner As Integer In {0, 51, 99}
            Assert(ProductPromotionEligibilityResolver.IsOwnerAuthorized(owner, anonymousScope) = (owner = 0), "anonymous owner eligibility " & owner)
        Next
        Dim authScope = ProductPromotionEligibilityResolver.CreateAnonymousContext("synthetic", 1, 4, Date.Today)
        authScope.IsAuthenticated = True : authScope.CurrentUserId = 51
        For Each owner As Integer In {0, 51, 99}
            Assert(ProductPromotionEligibilityResolver.IsOwnerAuthorized(owner, authScope) = (owner = 0 OrElse owner = 51), "authenticated owner eligibility " & owner)
        Next
        Dim campaignContext = Context(2, 10, False, "pid=7&inpromo=1")
        s = MakeSupport(campaignContext)
        Assert(s.Eligibility.CampaignId = 7 AndAlso Convert.ToInt32(s.Parameters().Find(Function(spec) spec.Name = "?promoCampaignId").Value) = 7, "campaign not article id")
        products = ProductRows(s)
        p = Endpoint(s)
        Dim campaignFilters = Invoke(p, "ReadFilters")
        response = DirectCast(Invoke(p, "BuildSearchResult", "SKU120", campaignFilters, 8), Dictionary(Of String, Object))
        Assert(commands(commands.Count - 1).Contains("SuggestHasPromotion <> 0") AndAlso
               Not commands(commands.Count - 1).Contains("v.id = @pid"), "promotion membership independent from unit price")
        Assert(CStr(response("catalogUrl")).Contains("pid=7"), "campaign catalog semantics")
        Reject(Sub() MakeSupport(Context(2, 10, False, "pid=invalid")), "invalid campaign")
        Assert(StorefrontPromotionCatalogProvider.BuildQuantityOnePriceJoin() = SearchSuggestBaselinePromotionCatalogProvider.BuildQuantityOnePriceJoin(), "catalog quantity join byte equivalence")
        Assert(StorefrontPromotionCatalogProvider.BuildMainCatalogJoin() = SearchSuggestBaselinePromotionCatalogProvider.BuildMainCatalogJoin(), "catalog membership join byte equivalence")
        Assert(StorefrontPromotionCatalogProvider.BuildFacetCatalogJoin() = SearchSuggestBaselinePromotionCatalogProvider.BuildFacetCatalogJoin(), "catalog facet join byte equivalence")

        For Each excluded As Boolean In {False, True}
            Dim gross = StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.Prezzo", "vsuperarticoli.PrezzoIvato",
                "vsuperarticoli.IdIvaRC", "vsuperarticoli.ValoreIvaRC", "?ksRcEnabled", "?ksHasVatOverride", "?ksVatOverride")
            Dim old = "(CASE WHEN ks_qty1_price.AppliedPromoNet>0 AND vsuperarticoli.Prezzo>0 AND ks_qty1_price.AppliedPromoNet<vsuperarticoli.Prezzo AND " & gross & ">0 THEN "
            old &= If(excluded, "ks_qty1_price.AppliedPromoNet ELSE vsuperarticoli.Prezzo END)",
                "ks_qty1_price.AppliedPromoNet*(CAST(" & gross & " AS DECIMAL(38,16))/CAST(vsuperarticoli.Prezzo AS DECIMAL(38,16))) ELSE " & gross & " END)")
            Assert(old = StorefrontEffectivePriceSqlBuilder.BuildQuantityOneDisplayPriceExpression(gross, excluded, False), "catalog extraction exact equivalence")
        Next
    End Sub
End Module
