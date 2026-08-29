Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

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
        _loginId = ResolveLoginId(context)
        _sessionId = ResolveSessionId(context)
        LoadSnapshot()
    End Sub

    Public Shared Function GetCurrent(ByVal context As HttpContext) As CartStateSnapshotProvider
        If context Is Nothing Then Return New CartStateSnapshotProvider(Nothing)

        Dim cached As CartStateSnapshotProvider = TryCast(context.Items(RequestCacheKey), CartStateSnapshotProvider)
        If cached IsNot Nothing Then Return cached

        cached = New CartStateSnapshotProvider(context)
        context.Items(RequestCacheKey) = cached
        Return cached
    End Function

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

    Private Sub LoadSnapshot()
        If _loginId <= 0 AndAlso String.IsNullOrEmpty(_sessionId) Then Return

        Dim settings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return

        Try
            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()
                Using command As New MySqlCommand()
                    command.Connection = connection
                    command.CommandType = CommandType.Text

                    If _loginId > 0 Then
                        command.CommandText = "SELECT ArticoliId, COALESCE(TCId,-1) AS TCId, SUM(COALESCE(Qnt,0)) AS Qty FROM carrello WHERE LoginId=@LoginId AND COALESCE(Qnt,0)>0 GROUP BY ArticoliId, COALESCE(TCId,-1)"
                        command.Parameters.Add("@LoginId", MySqlDbType.Int32).Value = _loginId
                    Else
                        command.CommandText = "SELECT ArticoliId, COALESCE(TCId,-1) AS TCId, SUM(COALESCE(Qnt,0)) AS Qty FROM carrello WHERE SessionId=@SessionId AND COALESCE(Qnt,0)>0 GROUP BY ArticoliId, COALESCE(TCId,-1)"
                        command.Parameters.Add("@SessionId", MySqlDbType.VarChar, 50).Value = _sessionId
                    End If

                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            Dim articleId As Integer = SafeInteger(reader("ArticoliId"), 0)
                            Dim tcId As Integer = NormalizeTCId(SafeInteger(reader("TCId"), -1))
                            Dim quantity As Decimal = SafeDecimal(reader("Qty"), 0D)
                            If articleId <= 0 OrElse quantity <= 0D Then Continue While

                            _items.Add(New CartStateSnapshotItem() With {
                                .ArticleId = articleId,
                                .TCId = tcId,
                                .Quantity = quantity
                            })
                            _quantities(BuildKey(articleId, tcId)) = quantity

                            Dim articleQuantity As Decimal = 0D
                            _articleQuantities.TryGetValue(articleId, articleQuantity)
                            _articleQuantities(articleId) = articleQuantity + quantity
                        End While
                    End Using
                End Using
            End Using
        Catch
            _items.Clear()
            _quantities.Clear()
            _articleQuantities.Clear()
        End Try
    End Sub

    Private Shared Function ResolveLoginId(ByVal context As HttpContext) As Integer
        If context Is Nothing OrElse context.Session Is Nothing Then Return 0

        Dim aliases As String() = {"LoginId", "LoginID", "LOGINID"}
        For Each aliasName As String In aliases
            Dim loginId As Integer = 0
            If Integer.TryParse(Convert.ToString(context.Session(aliasName)), loginId) AndAlso loginId > 0 Then Return loginId
        Next

        Return 0
    End Function

    Private Shared Function ResolveSessionId(ByVal context As HttpContext) As String
        Try
            If context IsNot Nothing AndAlso context.Session IsNot Nothing Then Return Convert.ToString(context.Session.SessionID)
        Catch
        End Try

        Return String.Empty
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
