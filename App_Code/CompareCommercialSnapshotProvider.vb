Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class CompareCommercialProductKey
    Public Sub New(ByVal articleId As Integer, ByVal tcId As Integer)
        _articleId = articleId
        _tcId = tcId
    End Sub

    Private ReadOnly _articleId As Integer
    Private ReadOnly _tcId As Integer

    Public ReadOnly Property ArticleId As Integer
        Get
            Return _articleId
        End Get
    End Property

    Public ReadOnly Property TCId As Integer
        Get
            Return _tcId
        End Get
    End Property

    Friend ReadOnly Property BusinessKey As String
        Get
            Return ArticleId.ToString(CultureInfo.InvariantCulture) & ":" & TCId.ToString(CultureInfo.InvariantCulture)
        End Get
    End Property
End Class

Public Enum CompareCommercialSnapshotStatus
    Ready = 0
    InvalidInput = 1
    InvalidContext = 2
    TechnicalError = 3
End Enum

Public Enum CompareCommercialVerificationStatus
    NotVerified = 0
    Verified = 1
End Enum

Public Enum CompareCommercialFailure
    None = 0
    InvalidContext = 1
    MissingProductOrVariant = 2
    AmbiguousProduct = 3
    InvalidCommercialData = 4
    TechnicalError = 5
End Enum

Public NotInheritable Class CompareCommercialSnapshotItem
    Private ReadOnly _key As CompareCommercialProductKey
    Private ReadOnly _failure As CompareCommercialFailure
    Private ReadOnly _price As Nullable(Of Decimal)
    Private ReadOnly _isAvailable As Nullable(Of Boolean)
    Private ReadOnly _availabilityText As String

    Friend Sub New(ByVal key As CompareCommercialProductKey,
                   ByVal failure As CompareCommercialFailure,
                   Optional ByVal price As Nullable(Of Decimal) = Nothing,
                   Optional ByVal isAvailable As Nullable(Of Boolean) = Nothing,
                   Optional ByVal availabilityText As String = "")
        _key = key
        _failure = failure
        ' Failed verification never carries a usable commercial value.
        If failure = CompareCommercialFailure.None Then
            If Not price.HasValue OrElse price.Value <= 0D OrElse Not isAvailable.HasValue OrElse
               String.IsNullOrWhiteSpace(availabilityText) Then Throw New ArgumentException("Incomplete commercial snapshot.")
            _price = price
            _isAvailable = isAvailable
            _availabilityText = availabilityText
        Else
            _availabilityText = String.Empty
        End If
    End Sub

    Public ReadOnly Property Key As CompareCommercialProductKey
        Get
            Return _key
        End Get
    End Property

    Public ReadOnly Property Status As CompareCommercialVerificationStatus
        Get
            Return If(_failure = CompareCommercialFailure.None,
                      CompareCommercialVerificationStatus.Verified, CompareCommercialVerificationStatus.NotVerified)
        End Get
    End Property

    Public ReadOnly Property Failure As CompareCommercialFailure
        Get
            Return _failure
        End Get
    End Property

    Public ReadOnly Property Price As Nullable(Of Decimal)
        Get
            Return _price
        End Get
    End Property

    Public ReadOnly Property IsAvailable As Nullable(Of Boolean)
        Get
            Return _isAvailable
        End Get
    End Property

    Public ReadOnly Property AvailabilityText As String
        Get
            Return _availabilityText
        End Get
    End Property
End Class

Public NotInheritable Class CompareCommercialSnapshot
    Private ReadOnly _status As CompareCommercialSnapshotStatus
    Private ReadOnly _items As ReadOnlyCollection(Of CompareCommercialSnapshotItem)
    Private ReadOnly _vatDisplayLabel As String

    Friend Sub New(ByVal status As CompareCommercialSnapshotStatus,
                   ByVal items As IList(Of CompareCommercialSnapshotItem),
                   Optional ByVal vatDisplayLabel As String = "")
        _status = status
        _items = New List(Of CompareCommercialSnapshotItem)(items).AsReadOnly()
        _vatDisplayLabel = vatDisplayLabel
    End Sub

    ' Ready describes a completed read, not verification of every item.
    Public ReadOnly Property Status As CompareCommercialSnapshotStatus
        Get
            Return _status
        End Get
    End Property

    Public ReadOnly Property Items As ReadOnlyCollection(Of CompareCommercialSnapshotItem)
        Get
            Return _items
        End Get
    End Property

    Public ReadOnly Property VatDisplayLabel As String
        Get
            Return _vatDisplayLabel
        End Get
    End Property
End Class

' Internal server-side foundation only. No endpoint, storage, cart mutation or
' commercial parameters supplied by a browser. The master must validate context first.
Public NotInheritable Class CompareCommercialSnapshotProvider
    Public Const MaximumProducts As Integer = 12
    Private Const NormalizedTC As String = "COALESCE(NULLIF(v.TCid,0),-1)"

    Private Sub New()
    End Sub

    Public Shared Function LoadCurrent(ByVal context As HttpContext,
                                       ByVal requestedProducts As IEnumerable(Of CompareCommercialProductKey)) As CompareCommercialSnapshot
        Dim keys As List(Of CompareCommercialProductKey) = Nothing
        If Not TryNormalizeKeys(requestedProducts, keys) Then
            Return FailureSnapshot(CompareCommercialSnapshotStatus.InvalidInput, New List(Of CompareCommercialProductKey)(),
                                   CompareCommercialFailure.InvalidCommercialData)
        End If
        If keys.Count = 0 Then Return New CompareCommercialSnapshot(CompareCommercialSnapshotStatus.Ready,
                                                                    New List(Of CompareCommercialSnapshotItem)())
        Try
            Dim priceContext As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(context)
            If priceContext Is Nothing Then Return FailureSnapshot(CompareCommercialSnapshotStatus.InvalidContext,
                                                                  keys, CompareCommercialFailure.InvalidContext)
            Dim eligibility As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(
                context, priceContext.CompanyId, priceContext.PriceListId)
            If Not IsCoherentContext(priceContext, eligibility) Then
                Return FailureSnapshot(CompareCommercialSnapshotStatus.InvalidContext, keys, CompareCommercialFailure.InvalidContext)
            End If
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then
                Return FailureSnapshot(CompareCommercialSnapshotStatus.TechnicalError, keys, CompareCommercialFailure.TechnicalError)
            End If

            Dim rows As New DataTable()
            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()
                Using command As MySqlCommand = CreateProductCommand(keys, priceContext.PriceListId, connection)
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        rows.Load(reader)
                    End Using
                End Using
            End Using
            Dim batch As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch(
                settings.ConnectionString, eligibility)
            Return ResolveLoadedSnapshot(context, keys, priceContext, eligibility, batch, rows)
        Catch ex As Exception
            Return FailureSnapshot(CompareCommercialSnapshotStatus.TechnicalError, keys, CompareCommercialFailure.TechnicalError)
        End Try
    End Function

    Private Shared Function TryNormalizeKeys(ByVal requestedProducts As IEnumerable(Of CompareCommercialProductKey),
                                            ByRef keys As List(Of CompareCommercialProductKey)) As Boolean
        keys = New List(Of CompareCommercialProductKey)()
        If requestedProducts Is Nothing Then Return False
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        Dim inputCount As Integer = 0
        Try
            For Each requested As CompareCommercialProductKey In requestedProducts
                inputCount += 1
                If inputCount > MaximumProducts OrElse requested Is Nothing OrElse
                   requested.ArticleId <= 0 OrElse requested.TCId < -1 Then Return False
                Dim key As New CompareCommercialProductKey(requested.ArticleId, If(requested.TCId = 0, -1, requested.TCId))
                If seen.Add(key.BusinessKey) Then keys.Add(key)
            Next
            Return True
        Catch ex As Exception
            Return False
        End Try
    End Function

    Private Shared Function IsCoherentContext(ByVal priceContext As StorefrontPriceDisplayContext,
                                             ByVal eligibility As ProductPromotionEligibilityContext) As Boolean
        Return priceContext IsNot Nothing AndAlso eligibility IsNot Nothing AndAlso
               Not String.IsNullOrWhiteSpace(eligibility.DatabaseScopeKey) AndAlso
               eligibility.CompanyId = priceContext.CompanyId AndAlso eligibility.Listino = priceContext.PriceListId AndAlso
               eligibility.IsAuthenticated = priceContext.IsAuthenticated AndAlso eligibility.CampaignId = 0 AndAlso
               If(eligibility.IsAuthenticated, eligibility.CurrentUserId > 0, eligibility.CurrentUserId = 0)
    End Function

    Private Shared Function CreateProductCommand(ByVal keys As IList(Of CompareCommercialProductKey),
                                                 ByVal priceListId As Integer,
                                                 ByVal connection As MySqlConnection) As MySqlCommand
        Dim command As New MySqlCommand()
        command.Connection = connection
        command.Parameters.Add("@listino", MySqlDbType.Int32).Value = priceListId
        Dim predicates As New List(Of String)()
        For i As Integer = 0 To keys.Count - 1
            Dim suffix As String = i.ToString(CultureInfo.InvariantCulture)
            predicates.Add("(v.id=@id" & suffix & " AND " & NormalizedTC & "=@tc" & suffix & ")")
            command.Parameters.Add("@id" & suffix, MySqlDbType.Int32).Value = keys(i).ArticleId
            command.Parameters.Add("@tc" & suffix, MySqlDbType.Int32).Value = keys(i).TCId
        Next
        ' The shared view supplies base commercial/stock facts. SELECT DISTINCT
        ' removes repetitions from offer joins; conflicting facts remain ambiguous.
        command.CommandText = "SELECT DISTINCT v.id AS ArticleId," & NormalizedTC & " AS TCId," &
            " v.Prezzo,v.PrezzoIvato,v.IdIvaRC,v.ValoreIvaRC,v.Giacenza,v.Disponibilita,v.Impegnata,v.InOrdine,v.ScortaMinima" &
            " FROM vsuperarticoli v INNER JOIN articoli a ON a.id=v.id" &
            " WHERE v.NListino=@listino AND COALESCE(a.Abilitato,0)=1 AND COALESCE(v.Export,0)<>0" &
            " AND (" & String.Join(" OR ", predicates.ToArray()) & ")" &
            " AND ((" & NormalizedTC & "=-1 AND NOT EXISTS" &
            " (SELECT 1 FROM articoli_tagliecolori t WHERE t.ArticoliId=v.id))" &
            " OR (" & NormalizedTC & ">0 AND EXISTS" &
            " (SELECT 1 FROM articoli_tagliecolori t WHERE t.ArticoliId=v.id AND t.id=v.TCid)))"
        Return command
    End Function

    ' In-memory composition seam, also used by synthetic tests. All public reads
    ' enter through LoadCurrent; no caller may replace its validated commercial scope.
    Friend Shared Function ResolveLoadedSnapshot(ByVal context As HttpContext,
                                                ByVal keys As IList(Of CompareCommercialProductKey),
                                                ByVal priceContext As StorefrontPriceDisplayContext,
                                                ByVal eligibility As ProductPromotionEligibilityContext,
                                                ByVal batch As ProductPromotionEligibilityBatch,
                                                ByVal rows As DataTable) As CompareCommercialSnapshot
        If Not IsCoherentContext(priceContext, eligibility) Then
            Return FailureSnapshot(CompareCommercialSnapshotStatus.InvalidContext, keys, CompareCommercialFailure.InvalidContext)
        End If
        If batch Is Nothing OrElse batch.Status <> ProductPromotionEligibilityLoadStatus.Success OrElse
           Not String.Equals(batch.ScopeKey, eligibility.CacheKey, StringComparison.Ordinal) OrElse rows Is Nothing Then
            Return FailureSnapshot(CompareCommercialSnapshotStatus.TechnicalError, keys, CompareCommercialFailure.TechnicalError)
        End If
        Dim byKey As New Dictionary(Of String, DataRow)(StringComparer.Ordinal)
        Dim ambiguous As New HashSet(Of String)(StringComparer.Ordinal)
        For Each row As DataRow In rows.Rows
            Dim key As New CompareCommercialProductKey(Convert.ToInt32(row("ArticleId"), CultureInfo.InvariantCulture),
                                                       Convert.ToInt32(row("TCId"), CultureInfo.InvariantCulture))
            If byKey.ContainsKey(key.BusinessKey) Then
                ambiguous.Add(key.BusinessKey)
            Else
                byKey.Add(key.BusinessKey, row)
            End If
        Next
        Dim items As New List(Of CompareCommercialSnapshotItem)()
        For Each key As CompareCommercialProductKey In keys
            Dim row As DataRow = Nothing
            If Not byKey.TryGetValue(key.BusinessKey, row) Then
                items.Add(New CompareCommercialSnapshotItem(key, CompareCommercialFailure.MissingProductOrVariant))
            ElseIf ambiguous.Contains(key.BusinessKey) Then
                items.Add(New CompareCommercialSnapshotItem(key, CompareCommercialFailure.AmbiguousProduct))
            Else
                items.Add(ResolveItem(context, key, row, priceContext, batch))
            End If
        Next
        Return New CompareCommercialSnapshot(CompareCommercialSnapshotStatus.Ready, items, priceContext.DisplayLabel)
    End Function

    Private Shared Function ResolveItem(ByVal context As HttpContext,
                                       ByVal key As CompareCommercialProductKey,
                                       ByVal row As DataRow,
                                       ByVal priceContext As StorefrontPriceDisplayContext,
                                       ByVal batch As ProductPromotionEligibilityBatch) As CompareCommercialSnapshotItem
        Try
            Dim net As Nullable(Of Decimal) = ReadDecimal(row, "Prezzo")
            Dim gross As Nullable(Of Decimal) = StorefrontEffectivePriceResolver.ResolveEffectiveGross(net,
                ReadDecimal(row, "PrezzoIvato"), priceContext.ReverseChargeEnabled, priceContext.VatOverride,
                If(row.IsNull("IdIvaRC"), -1, Convert.ToInt32(row("IdIvaRC"), CultureInfo.InvariantCulture)),
                ReadDecimal(row, "ValoreIvaRC"))
            If Not net.HasValue OrElse net.Value <= 0D OrElse Not gross.HasValue OrElse gross.Value <= 0D Then
                Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.InvalidCommercialData)
            End If
            Dim promotion As ProductPromotionEligibilityResult = batch.ResolveForProduct(key.ArticleId, key.TCId, 1D,
                                                                                         net.Value, gross.Value)
            If promotion Is Nothing OrElse promotion.Status <> ProductPromotionEligibilityLoadStatus.Success Then
                Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.TechnicalError)
            End If
            Dim price As Nullable(Of Decimal) = priceContext.SelectPrice(promotion.EffectivePriceNet, promotion.EffectivePriceGross)
            If Not price.HasValue Then Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.InvalidCommercialData)
            ' The authoritative view already normalizes these three stock facts
            ' to zero. A residual NULL cannot certify their availability semantics.
            For Each column As String In New String() {"Giacenza", "Disponibilita", "Impegnata"}
                If Not ReadDecimal(row, column).HasValue Then
                    Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.InvalidCommercialData)
                End If
            Next
            ' Incoming NULL legitimately means zero in the legacy view/helper.
            ' An unset product threshold legitimately uses the tenant threshold.
            ' Both columns must exist and be convertible when populated.
            ReadDecimal(row, "InOrdine")
            ReadDecimal(row, "ScortaMinima")
            Dim availability As AvailabilityDisplayModel = AvailabilityDisplayHelper.BuildFromDataItem(row, context)
            Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.None, price,
                                                      availability.IsAvailable, availability.Text)
        Catch ex As Exception
            Return New CompareCommercialSnapshotItem(key, CompareCommercialFailure.TechnicalError)
        End Try
    End Function

    Private Shared Function ReadDecimal(ByVal row As DataRow, ByVal column As String) As Nullable(Of Decimal)
        If row.IsNull(column) Then Return Nothing
        Return Convert.ToDecimal(row(column), CultureInfo.InvariantCulture)
    End Function

    Private Shared Function FailureSnapshot(ByVal status As CompareCommercialSnapshotStatus,
                                            ByVal keys As IEnumerable(Of CompareCommercialProductKey),
                                            ByVal failure As CompareCommercialFailure) As CompareCommercialSnapshot
        Dim items As New List(Of CompareCommercialSnapshotItem)()
        For Each key As CompareCommercialProductKey In keys
            items.Add(New CompareCommercialSnapshotItem(key, failure))
        Next
        Return New CompareCommercialSnapshot(status, items)
    End Function
End Class
