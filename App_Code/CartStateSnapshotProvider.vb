Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Data
Imports System.Globalization
Imports System.Web

Public NotInheritable Class CartStateSnapshotItem
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal
End Class

Public NotInheritable Class CartStateSnapshotProvider
    Private Const RequestCacheKey As String = "KeepStore:CartStateSnapshotProvider:Current"

    Private ReadOnly _items As List(Of CartStateSnapshotItem)
    Private ReadOnly _quantities As Dictionary(Of String, Decimal)
    Private ReadOnly _articleQuantities As Dictionary(Of Integer, Decimal)
    Private ReadOnly _loginId As Integer
    Private ReadOnly _sessionId As String

    Private Sub New(ByVal context As HttpContext)
        _items = New List(Of CartStateSnapshotItem)()
        _quantities = New Dictionary(Of String, Decimal)(StringComparer.Ordinal)
        _articleQuantities = New Dictionary(Of Integer, Decimal)()
        Dim readModel As CartAuthoritativeReadModel = CartAuthoritativeReadModel.GetCurrent(context)
        _loginId = readModel.LoginId
        _sessionId = readModel.SessionId
        LoadSnapshot(readModel.GetAllItems())
    End Sub

    Public Shared Function GetCurrent(ByVal context As HttpContext) As CartStateSnapshotProvider
        If context Is Nothing Then Return New CartStateSnapshotProvider(Nothing)

        Dim cached As CartStateSnapshotProvider = TryCast(context.Items(RequestCacheKey), CartStateSnapshotProvider)
        If cached IsNot Nothing Then Return cached

        cached = New CartStateSnapshotProvider(context)
        context.Items(RequestCacheKey) = cached
        Return cached
    End Function

    Public Shared Sub Invalidate(ByVal context As HttpContext)
        If context Is Nothing Then Return
        context.Items.Remove(RequestCacheKey)
    End Sub

    Public ReadOnly Property LoginId As Integer
        Get
            Return _loginId
        End Get
    End Property

    Public ReadOnly Property SessionId As String
        Get
            Return _sessionId
        End Get
    End Property

    Public ReadOnly Property IsAuthenticated As Boolean
        Get
            Return _loginId > 0
        End Get
    End Property

    Public ReadOnly Property Items As IList(Of CartStateSnapshotItem)
        Get
            Return New ReadOnlyCollection(Of CartStateSnapshotItem)(_items)
        End Get
    End Property

    Public Function GetQuantity(ByVal articleId As Integer, ByVal tcId As Integer) As Decimal
        If articleId <= 0 Then Return 0D

        Dim quantity As Decimal = 0D
        If _quantities.TryGetValue(BuildKey(articleId, NormalizeTCId(tcId)), quantity) Then Return quantity
        Return 0D
    End Function

    Public Function GetArticleQuantity(ByVal articleId As Integer) As Decimal
        If articleId <= 0 Then Return 0D

        Dim quantity As Decimal = 0D
        If _articleQuantities.TryGetValue(articleId, quantity) Then Return quantity
        Return 0D
    End Function

    Public Shared Function NormalizeTCId(ByVal tcId As Integer) As Integer
        If tcId <= 0 Then Return -1
        Return tcId
    End Function

    Private Sub LoadSnapshot(ByVal rows As DataTable)
        If rows Is Nothing Then Return

        For Each row As DataRow In rows.Rows
            Dim articleId As Integer = SafeInteger(ReadColumn(row, "ArticoliId"), 0)
            Dim tcId As Integer = NormalizeTCId(SafeInteger(ReadColumn(row, "TCId"), -1))
            Dim quantity As Decimal = SafeDecimal(ReadColumn(row, "Qnt"), 0D)
            If articleId <= 0 OrElse quantity <= 0D Then Continue For

            Dim key As String = BuildKey(articleId, tcId)
            Dim rowQuantity As Decimal = 0D
            _quantities.TryGetValue(key, rowQuantity)
            _quantities(key) = rowQuantity + quantity

            Dim articleQuantity As Decimal = 0D
            _articleQuantities.TryGetValue(articleId, articleQuantity)
            _articleQuantities(articleId) = articleQuantity + quantity
        Next

        For Each pair As KeyValuePair(Of String, Decimal) In _quantities
            Dim parts() As String = pair.Key.Split(":"c)
            If parts.Length <> 2 Then Continue For
            _items.Add(New CartStateSnapshotItem() With {
                .ArticleId = SafeInteger(parts(0), 0),
                .TCId = NormalizeTCId(SafeInteger(parts(1), -1)),
                .Quantity = pair.Value
            })
        Next
    End Sub

    Private Shared Function ReadColumn(ByVal row As DataRow, ByVal name As String) As Object
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(name) Then Return Nothing
        Return row(name)
    End Function

    Private Shared Function BuildKey(ByVal articleId As Integer, ByVal tcId As Integer) As String
        Return articleId.ToString(CultureInfo.InvariantCulture) & ":" & NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function SafeInteger(ByVal value As Object, ByVal fallback As Integer) As Integer
        Dim parsed As Integer = fallback
        If value IsNot Nothing AndAlso value IsNot DBNull.Value AndAlso Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Return fallback
    End Function

    Private Shared Function SafeDecimal(ByVal value As Object, ByVal fallback As Decimal) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then Return fallback
        Try
            Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
        Catch
            Dim parsed As Decimal = fallback
            If Decimal.TryParse(Convert.ToString(value), parsed) Then Return parsed
            Return fallback
        End Try
    End Function
End Class
