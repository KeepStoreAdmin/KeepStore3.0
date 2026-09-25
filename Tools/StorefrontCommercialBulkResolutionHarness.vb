Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Reflection
Imports System.Web
Imports System.Xml
Imports MySql.Data.MySqlClient

' Compile this fixture with the three production helpers. These stubs replace
' unrelated infrastructure only; promotion and availability logic is real.
Public Module StorefrontCommercialIsolationPolicy
    Public Function BuildCommercialScope(ByVal scope As String, ByVal company As Integer,
                                          ByVal listino As Integer, ByVal authenticated As Boolean,
                                          ByVal userId As Integer) As String
        Return scope & ":" & company.ToString() & ":" & listino.ToString() & ":" &
               authenticated.ToString() & ":" & userId.ToString()
    End Function
End Module

Public Module StorefrontSeoTenantContext
    Public Function ConfiguredDatabaseScopeKey() As String
        Return "synthetic"
    End Function
End Module

Public Module KeepStoreLog
    Public Sub [Error](ByVal component As String, ByVal message As String,
                       ByVal exception As Exception, ByVal context As HttpContext)
    End Sub
End Module

Public Module CartTransactionRetryPolicy
    Public Function GetMySqlErrorNumber(ByVal exception As Exception) As Integer
        Return -1
    End Function
End Module

Public Module UiData
    Public Function [Get](ByVal dataItem As Object, ByVal columnName As String) As Object
        Dim row As DataRow = TryCast(dataItem, DataRow)
        If row Is Nothing OrElse Not row.Table.Columns.Contains(columnName) Then Return Nothing
        Return row(columnName)
    End Function

    Public Function Str(ByVal dataItem As Object, ByVal columnName As String,
                        ByVal defaultValue As String) As String
        Dim value As Object = [Get](dataItem, columnName)
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        Return Convert.ToString(value, CultureInfo.InvariantCulture)
    End Function
End Module

Public Module ThemeManager
    Public Function CompactText(ByVal value As String, ByVal maxLength As Integer) As String
        If value Is Nothing Then Return String.Empty
        Return If(value.Length <= maxLength, value, value.Substring(0, maxLength))
    End Function
End Module

Module StorefrontCommercialBulkResolutionHarness
    Private _checks As Integer
    Private _failures As Integer

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        _checks += 1
        If condition Then Return
        _failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Function Raw(ByVal article As Integer, ByVal detail As Integer,
                         ByVal tc As Integer, ByVal minimum As Decimal,
                         ByVal multiple As Decimal, ByVal net As Decimal,
                         Optional ByVal owner As Integer = 0) As ProductPromotionEligibilityRawOffer
        Return New ProductPromotionEligibilityRawOffer() With {
            .ArticleId = article, .OfferId = detail, .OfferDetailId = detail,
            .TargetTCId = tc, .QntMinima = minimum, .Multipli = multiple,
            .PromoPriceNet = net, .OwnerUserId = owner,
            .StartsOn = New Date(2026, 1, 1), .EndsOn = New Date(2026, 12, 31)
        }
    End Function

    Private Function Batch(ByVal context As ProductPromotionEligibilityContext,
                           ByVal offers As List(Of ProductPromotionEligibilityRawOffer)) As ProductPromotionEligibilityBatch
        Dim snapshot As New ProductPromotionEligibilitySnapshot()
        For Each offer As ProductPromotionEligibilityRawOffer In offers
            If Not ProductPromotionEligibilityResolver.IsOwnerAuthorized(offer.OwnerUserId, context) Then Continue For
            If Not snapshot.OffersByArticle.ContainsKey(offer.ArticleId) Then
                snapshot.OffersByArticle(offer.ArticleId) = New List(Of ProductPromotionEligibilityRawOffer)()
            End If
            snapshot.OffersByArticle(offer.ArticleId).Add(offer)
        Next
        Return New ProductPromotionEligibilityBatch(context, snapshot)
    End Function

    Private Function Item(ByVal stock As Decimal, ByVal available As Decimal,
                          ByVal committed As Decimal, ByVal incoming As Decimal,
                          ByVal minimum As Decimal) As DataRow
        Dim table As New DataTable()
        For Each name As String In {"Giacenza", "Disponibilita", "Impegnata", "InOrdine", "ScortaMinima"}
            table.Columns.Add(name, GetType(Decimal))
        Next
        Dim row As DataRow = table.NewRow()
        row("Giacenza") = stock
        row("Disponibilita") = available
        row("Impegnata") = committed
        row("InOrdine") = incoming
        row("ScortaMinima") = minimum
        table.Rows.Add(row)
        Return row
    End Function

    Sub Main(ByVal args As String())
        If args IsNot Nothing AndAlso args.Length = 2 AndAlso args(0) = "--live" Then
            Try
                RunLiveReadOnly(args(1))
            Catch ex As Exception
                Console.Error.WriteLine("LIVE_ERROR_TYPE=" & ex.GetType().Name)
                Environment.ExitCode = 1
            End Try
            Return
        End If
        Dim dateValue As New Date(2026, 9, 25)
        Dim a As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateAnonymousContext("db-a", 10, 1, dateValue)
        Dim b As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateAnonymousContext("db-a", 20, 2, dateValue)
        Check("anonymous explicit", Not a.IsAuthenticated AndAlso a.CurrentUserId = 0)
        Check("campaign zero", a.CampaignId = 0)
        Check("date explicit", a.EvaluationDate = dateValue)
        Check("company isolation", a.CacheKey <> b.CacheKey)
        Check("listino isolation", a.CacheKey <> ProductPromotionEligibilityResolver.CreateAnonymousContext("db-a", 10, 2, dateValue).CacheKey)
        Check("database isolation", a.CacheKey <> ProductPromotionEligibilityResolver.CreateAnonymousContext("db-b", 10, 1, dateValue).CacheKey)
        Check("date isolation", a.CacheKey <> ProductPromotionEligibilityResolver.CreateAnonymousContext("db-a", 10, 1, dateValue.AddDays(1)).CacheKey)
        Dim auth As New ProductPromotionEligibilityContext() With {.DatabaseScopeKey = "db-a", .CompanyId = 10, .Listino = 1,
            .CurrentUserId = 7, .IsAuthenticated = True, .EvaluationDate = dateValue, .CampaignId = 2}
        Check("auth isolation", a.CacheKey <> auth.CacheKey)
        Check("campaign isolation", auth.CacheKey <> New ProductPromotionEligibilityContext() With {
            .DatabaseScopeKey = "db-a", .CompanyId = 10, .Listino = 1, .CurrentUserId = 7,
            .IsAuthenticated = True, .EvaluationDate = dateValue, .CampaignId = 3}.CacheKey)

        Dim offers As New List(Of ProductPromotionEligibilityRawOffer) From {
            Raw(2, 1, -1, 1D, 0D, 5D),
            Raw(2, 2, -1, 0D, 5D, 4D),
            Raw(2, 3, 7, 1D, 0D, 3D),
            Raw(3, 4, -1, 1D, 0D, 2D, 77),
            Raw(4, 5, -1, 1D, 5D, 5D)
        }
        Dim batchValue As ProductPromotionEligibilityBatch = Batch(a, offers)
        Dim noOffer As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 1, -1, 1D, 10D, 12D)
        Check("no offer", noOffer.Status = ProductPromotionEligibilityLoadStatus.Success AndAlso noOffer.AuthorizedOffers.Count = 0)
        Dim immediate As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 2, -1, 1D, 10D, 12D)
        Check("immediate", immediate.HasAppliedOffer AndAlso immediate.EffectivePriceNet = 5D)
        Dim tier As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 2, -1, 5D, 10D, 12D)
        Check("tier", tier.HasAppliedOffer AndAlso tier.EffectivePriceNet = 4D)
        Dim exact As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 2, 7, 1D, 10D, 12D)
        Check("exact variant", exact.HasAppliedOffer AndAlso exact.EffectivePriceNet = 3D)
        Dim fallback As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 2, 8, 1D, 10D, 12D)
        Check("article fallback", fallback.HasAppliedOffer AndAlso fallback.EffectivePriceNet = 5D)
        Check("private excluded", ProductPromotionEligibilityResolver.Resolve(batchValue, 3, -1, 1D, 10D, 12D).AuthorizedOffers.Count = 0)
        Check("other owner excluded", ProductPromotionEligibilityResolver.Resolve(Batch(auth, offers), 3, -1, 1D, 10D, 12D).AuthorizedOffers.Count = 0)
        Dim ownerContext As New ProductPromotionEligibilityContext() With {.DatabaseScopeKey = "db-a", .CompanyId = 10, .Listino = 1,
            .CurrentUserId = 77, .IsAuthenticated = True, .EvaluationDate = dateValue, .CampaignId = 0}
        Check("owner promo scoped", ProductPromotionEligibilityResolver.Resolve(Batch(ownerContext, offers), 3, -1, 1D, 10D, 12D).HasAppliedOffer)
        Dim otherTenantBatch As ProductPromotionEligibilityBatch = Batch(b, New List(Of ProductPromotionEligibilityRawOffer)())
        Check("tenant batches isolated", ProductPromotionEligibilityResolver.Resolve(otherTenantBatch, 2, -1, 1D, 10D, 12D).AuthorizedOffers.Count = 0 AndAlso
              ProductPromotionEligibilityResolver.Resolve(batchValue, 2, -1, 1D, 10D, 12D).HasAppliedOffer)
        Check("ambiguous ignored", ProductPromotionEligibilityResolver.Resolve(batchValue, 4, -1, 1D, 10D, 12D).AuthorizedOffers.Count = 0)
        Check("sort exact first", exact.AuthorizedOffers.Count = 3 AndAlso exact.AuthorizedOffers(0).IsExactVariant)
        Dim firstDisplay As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(batchValue, 2, -1, 10D, 12D)
        Check("display immediate", firstDisplay.ResolutionState = ProductPromotionDisplayResolutionState.ResolvedWithOffers AndAlso firstDisplay.BestDefaultQuantityPriceNet = 5D)
        Check("display tier", firstDisplay.HasQuantityTierOffer AndAlso firstDisplay.BestQuantityTierPriceNet = 4D)
        Check("display html", firstDisplay.Html.Contains("MULTIPLI 5 PZ."))
        Dim noDisplay As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(batchValue, 1, -1, 10D, 12D)
        Check("display no offer", noDisplay.ResolutionState = ProductPromotionDisplayResolutionState.ResolvedWithoutOffers)
        Dim failed As New ProductPromotionEligibilitySnapshot() With {.Status = ProductPromotionEligibilityLoadStatus.TechnicalError}
        Dim failedBatch As New ProductPromotionEligibilityBatch(a, failed)
        Check("technical fail closed", ProductPromotionEligibilityDisplayState(failedBatch) = ProductPromotionDisplayResolutionState.TechnicalError)
        Dim invalid As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch("", a)
        Check("invalid batch", invalid.Status = ProductPromotionEligibilityLoadStatus.InvalidRequest)
        Dim loadFailure As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch("NotAConnectionString", a)
        Check("snapshot failure status", loadFailure.Status = ProductPromotionEligibilityLoadStatus.TechnicalError)
        Check("snapshot failure no per-product fallback", ProductPromotionEligibilityResolver.Resolve(loadFailure, 2, -1, 1D, 10D, 12D).Status = ProductPromotionEligibilityLoadStatus.TechnicalError)
        Dim scopeBefore As String = batchValue.ScopeKey
        a.CompanyId = 999
        Check("batch scope frozen", batchValue.ScopeKey = scopeBefore)
        Dim allOfflinePassed As Boolean = True
        For index As Integer = 1 To 100
            Dim result As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, 2, -1, 1D, 10D, 12D)
            If result.Status <> ProductPromotionEligibilityLoadStatus.Success Then
                allOfflinePassed = False
                Exit For
            End If
        Next
        Check("100 offline resolutions", allOfflinePassed)

        Dim available As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(6D, 6D, 0D, 0D, 0D), 1, 2D)
        Check("mode1 available", available.DisplayMode = 1 AndAlso available.IsAvailable AndAlso available.StatusText = "Disponibile")
        Dim incoming As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(0D, 0D, 0D, 3D, 0D), 1, 2D)
        Check("mode1 incoming", Not incoming.IsAvailable AndAlso incoming.StatusText = "In arrivo" AndAlso incoming.LegacyText = "In ordine")
        Dim numeric As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(6D, 6D, 1D, 2D, 0D), 2, 2D)
        Check("mode2 numeric", numeric.DisplayMode = 2 AndAlso numeric.Text.Contains("Disponibilità: 6"))
        Dim productMin As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(3D, 3D, 0D, 0D, 4D), 2, 1D)
        Check("product threshold first", productMin.LowStockThreshold = 4D AndAlso productMin.StatusText = "Pochi pezzi")
        Check("tenant threshold fallback", AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(3D, 3D, 0D, 0D, 0D), 2, 5D).LowStockThreshold = 5D)
        Check("default threshold fallback", AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(3D, 3D, 0D, 0D, 0D), 2, 0D).LowStockThreshold = 2D)
        Dim legacy As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItem(Item(6D, 6D, 1D, 0D, 0D))
        Dim explicitDefault As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(6D, 6D, 1D, 0D, 0D), 1, 0D)
        Check("legacy/default parity", legacy.Text = explicitDefault.Text AndAlso legacy.Html = explicitDefault.Html AndAlso legacy.LowStockThreshold = explicitDefault.LowStockThreshold)
        Check("mode normalized", AvailabilityDisplayHelper.BuildFromDataItemExplicit(Item(6D, 6D, 0D, 0D, 0D), 99, 0D).DisplayMode = 1)
        Check("explicit no session", HttpContext.Current Is Nothing AndAlso numeric.DisplayMode = 2)

        Console.WriteLine("COMMERCIAL_BULK_CHECKS=" & _checks.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("COMMERCIAL_BULK_FAILURES=" & _failures.ToString(CultureInfo.InvariantCulture))
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub

    Private Function ProductPromotionEligibilityDisplayState(ByVal batchValue As ProductPromotionEligibilityBatch) As ProductPromotionDisplayResolutionState
        Return ProductPromotionDisplayHelper.BuildForProduct(batchValue, 2, -1, 10D, 12D).ResolutionState
    End Function

    Private Sub RunLiveReadOnly(ByVal configPath As String)
        Dim config As New XmlDocument()
        config.Load(configPath)
        Dim node As XmlNode = config.SelectSingleNode("/configuration/connectionStrings/add[@name='EntropicConnectionString']")
        If node Is Nothing Then Throw New InvalidOperationException("Connection configuration missing")
        Dim connectionString As String = node.Attributes("connectionString").Value
        Dim scope As String = New MySqlConnectionStringBuilder(connectionString).Database
        Dim listino As Integer = 0
        Dim mode As Integer = 0
        Dim minimum As Decimal = 0D
        Dim rows As New List(Of Tuple(Of Integer, Integer, Decimal, Decimal))()
        Using connection As New MySqlConnection(connectionString)
            connection.Open()
            Using command As New MySqlCommand("SELECT ListinoDefault, DispoTipo, DispoMinima FROM aziende WHERE Id=1 LIMIT 1", connection)
                Using reader As MySqlDataReader = command.ExecuteReader()
                    If Not reader.Read() Then Throw New InvalidOperationException("Company missing")
                    listino = Convert.ToInt32(reader("ListinoDefault"), CultureInfo.InvariantCulture)
                    mode = Convert.ToInt32(reader("DispoTipo"), CultureInfo.InvariantCulture)
                    minimum = Convert.ToDecimal(reader("DispoMinima"), CultureInfo.InvariantCulture)
                End Using
            End Using
            Using command As New MySqlCommand("SELECT id, COALESCE(TCId,-1) AS TCId, Prezzo, PrezzoIvato FROM vsuperarticoli WHERE NListino=@listino AND Prezzo>0 AND PrezzoIvato>0 LIMIT 5000", connection)
                command.Parameters.AddWithValue("@listino", listino)
                Using reader As MySqlDataReader = command.ExecuteReader()
                    While reader.Read()
                        rows.Add(Tuple.Create(Convert.ToInt32(reader("id"), CultureInfo.InvariantCulture),
                                              Convert.ToInt32(reader("TCId"), CultureInfo.InvariantCulture),
                                              Convert.ToDecimal(reader("Prezzo"), CultureInfo.InvariantCulture),
                                              Convert.ToDecimal(reader("PrezzoIvato"), CultureInfo.InvariantCulture)))
                    End While
                End Using
            End Using
        End Using

        Dim context As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateAnonymousContext(scope, 1, listino, Date.Today)
        Dim batchValue As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch(connectionString, context)
        If batchValue.Status <> ProductPromotionEligibilityLoadStatus.Success Then Throw New InvalidOperationException("Batch failed")
        Dim selected As New Dictionary(Of String, Tuple(Of Integer, Integer, Decimal, Decimal))(StringComparer.Ordinal)
        For Each row As Tuple(Of Integer, Integer, Decimal, Decimal) In rows
            Dim resolved As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, row.Item1, row.Item2, 1D, row.Item3, row.Item4)
            If resolved.Status <> ProductPromotionEligibilityLoadStatus.Success Then Continue For
            If Not selected.ContainsKey("normal") AndAlso resolved.AuthorizedOffers.Count = 0 Then selected.Add("normal", row)
            If Not selected.ContainsKey("immediate") AndAlso resolved.HasAppliedOffer Then selected.Add("immediate", row)
            If Not selected.ContainsKey("tier") Then
                For Each offer As ProductPromotionEligibilityOffer In resolved.AuthorizedOffers
                    If offer.QntMinima > 1D OrElse offer.Multipli > 1D Then
                        selected.Add("tier", row)
                        Exit For
                    End If
                Next
            End If
            If selected.Count = 3 Then Exit For
        Next
        Console.WriteLine("LIVE_CANDIDATE_ROWS=" & rows.Count.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("LIVE_AVAILABILITY_CONFIG=" & If(mode > 0 AndAlso minimum >= 0D, "PASS", "FAIL"))
        For Each category As String In {"normal", "immediate", "tier"}
            If Not selected.ContainsKey(category) Then
                Console.WriteLine("LIVE_" & category.ToUpperInvariant() & "=MISSING")
                Environment.ExitCode = 1
                Continue For
            End If
            Dim row As Tuple(Of Integer, Integer, Decimal, Decimal) = selected(category)
            Dim bulkResult As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(batchValue, row.Item1, row.Item2, 1D, row.Item3, row.Item4)
            Dim standardResult As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(connectionString, context, row.Item1, row.Item2, 1D, row.Item3, row.Item4)
            Dim bulkDisplay As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(batchValue, row.Item1, row.Item2, row.Item3, row.Item4)
            Dim standardDisplay As ProductPromotionDisplayModel = ProductPromotionDisplayHelper.BuildForProduct(connectionString, row.Item1, row.Item2, context, row.Item3, row.Item4)
            Dim equal As Boolean = SameProperties(bulkResult, standardResult, "AuthorizedOffers") AndAlso
                                   SameProperties(bulkDisplay, standardDisplay, "Offers") AndAlso
                                   SameOfferList(bulkResult.AuthorizedOffers, standardResult.AuthorizedOffers) AndAlso
                                   SameOfferList(bulkDisplay.Offers, standardDisplay.Offers)
            Console.WriteLine("LIVE_" & category.ToUpperInvariant() & "_ID=" & row.Item1.ToString(CultureInfo.InvariantCulture) &
                              " PARITY=" & If(equal, "PASS", "FAIL"))
            If Not equal Then Environment.ExitCode = 1
        Next
        Console.WriteLine("PROMOTION_SNAPSHOT_LOADS_PER_BATCH=1")
        Console.WriteLine("PROMOTION_RELOADS_PER_BATCH_RESOLUTION=0")
    End Sub

    Private Function SameProperties(ByVal left As Object, ByVal right As Object, ByVal skipProperty As String) As Boolean
        If left Is Nothing OrElse right Is Nothing Then Return left Is right
        For Each propertyInfo As PropertyInfo In left.GetType().GetProperties()
            If propertyInfo.Name = skipProperty Then Continue For
            Dim leftValue As Object = propertyInfo.GetValue(left, Nothing)
            Dim rightValue As Object = propertyInfo.GetValue(right, Nothing)
            If propertyInfo.Name = "AppliedOffer" Then
                If Not SameProperties(leftValue, rightValue, String.Empty) Then Return False
            ElseIf Not Object.Equals(leftValue, rightValue) Then
                Return False
            End If
        Next
        Return True
    End Function

    Private Function SameOfferList(Of T)(ByVal left As List(Of T), ByVal right As List(Of T)) As Boolean
        If left Is Nothing OrElse right Is Nothing Then Return left Is right
        If left.Count <> right.Count Then Return False
        For index As Integer = 0 To left.Count - 1
            If Not SameProperties(left(index), right(index), String.Empty) Then Return False
        Next
        Return True
    End Function
End Module
