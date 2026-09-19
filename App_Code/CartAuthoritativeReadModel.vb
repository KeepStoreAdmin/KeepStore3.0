Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class CartAuthoritativeReadModel
    Private Const RequestCacheKey As String = "KeepStore:CartAuthoritativeReadModel:Current"

    Private ReadOnly _owner As CartStorefrontOwnerScope
    Private ReadOnly _items As DataTable
    Private _loadSucceeded As Boolean

    Private Sub New(ByVal context As HttpContext)
        _owner = CartStorefrontOwnerContext.Resolve(context)
        _items = New DataTable("CartItems")
        LoadItems(context)
    End Sub

    Public Shared Function GetCurrent(ByVal context As HttpContext) As CartAuthoritativeReadModel
        If context Is Nothing Then Return New CartAuthoritativeReadModel(Nothing)

        Dim cached As CartAuthoritativeReadModel = TryCast(context.Items(RequestCacheKey), CartAuthoritativeReadModel)
        If cached IsNot Nothing Then Return cached

        cached = New CartAuthoritativeReadModel(context)
        context.Items(RequestCacheKey) = cached
        Return cached
    End Function

    Public Shared Sub Invalidate(ByVal context As HttpContext)
        If context Is Nothing Then Return
        context.Items.Remove(RequestCacheKey)
        CartStateSnapshotProvider.Invalidate(context)
    End Sub

    Public ReadOnly Property HasOwner As Boolean
        Get
            Return _owner IsNot Nothing
        End Get
    End Property

    Public ReadOnly Property LoadSucceeded As Boolean
        Get
            Return _loadSucceeded
        End Get
    End Property

    Public ReadOnly Property LoginId As Integer
        Get
            Return If(_owner IsNot Nothing, _owner.LoginId, 0)
        End Get
    End Property

    Public ReadOnly Property SessionId As String
        Get
            Return If(_owner IsNot Nothing, _owner.SessionId, String.Empty)
        End Get
    End Property

    Public ReadOnly Property IsAuthenticated As Boolean
        Get
            Return _owner IsNot Nothing AndAlso _owner.IsAuthenticated
        End Get
    End Property

    Public ReadOnly Property TotalQuantity As Decimal
        Get
            Dim total As Decimal = 0D
            For Each row As DataRow In _items.Rows
                total += SafeDecimal(ReadColumn(row, "Qnt"), 0D)
            Next
            Return total
        End Get
    End Property

    Public ReadOnly Property TotalNet As Decimal
        Get
            Return SumLineAmount("Importo", "Prezzo")
        End Get
    End Property

    Public ReadOnly Property TotalGross As Decimal
        Get
            Return SumLineAmount("ImportoIvato", "PrezzoIvato")
        End Get
    End Property

    Public Function GetAllItems() As DataTable
        Return CopyRows(_items.Rows)
    End Function

    Public Function GetStandardItems() As DataTable
        Dim selected As DataTable = _items.Clone()
        For Each row As DataRow In _items.Rows
            If Not IsFreeShipping(row) Then selected.ImportRow(row)
        Next
        Return selected
    End Function

    Public Function GetFreeShippingItems() As DataTable
        Dim selected As DataTable = _items.Clone()
        For Each row As DataRow In _items.Rows
            If IsFreeShipping(row) Then selected.ImportRow(row)
        Next
        Return selected
    End Function

    Public Function GetMiniCartItems(ByVal maximumRows As Integer) As DataTable
        Dim selected As DataTable = _items.Clone()
        If maximumRows <= 0 OrElse _items.Rows.Count = 0 Then Return selected

        Dim rows() As DataRow
        Try
            rows = _items.Select(String.Empty, "id DESC")
        Catch
            rows = _items.Select()
        End Try

        Dim count As Integer = Math.Min(maximumRows, rows.Length)
        For index As Integer = 0 To count - 1
            selected.ImportRow(rows(index))
        Next
        Return selected
    End Function

    Private Sub LoadItems(ByVal context As HttpContext)
        If _owner Is Nothing Then Return

        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return

        Try
            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()
                Using command As New MySqlCommand()
                    command.Connection = connection
                    command.CommandType = CommandType.Text
                    command.CommandText =
                        "SELECT vcarrello.*, articoli.SpedizioneGratis_Listini, " &
                        "articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine, " &
                        "taglie.descrizione AS taglia, colori.descrizione AS colore " &
                        "FROM vcarrello " &
                        "LEFT OUTER JOIN articoli ON vcarrello.ArticoliId=articoli.id " &
                        "LEFT OUTER JOIN articoli_tagliecolori ON vcarrello.TCid=articoli_tagliecolori.id " &
                        "LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid=taglie.id " &
                        "LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid=colori.id WHERE " &
                        If(_owner.IsAuthenticated,
                           "vcarrello.LoginId=@LoginId ",
                           "COALESCE(vcarrello.LoginId,0)<=0 AND vcarrello.SessionId=@SessionId ") &
                        "ORDER BY vcarrello.id"

                    If _owner.IsAuthenticated Then
                        command.Parameters.Add("@LoginId", MySqlDbType.Int32).Value = _owner.LoginId
                    Else
                        command.Parameters.Add("@SessionId", MySqlDbType.VarChar, 50).Value = _owner.SessionId
                    End If

                    Using adapter As New MySqlDataAdapter(command)
                        adapter.Fill(_items)
                    End Using
                End Using
            End Using
            _loadSucceeded = True
        Catch ex As Exception
            _items.Clear()
            KeepStoreLog.Error(
                "cart-read-model",
                "Authoritative cart read failed. Error type: " & ex.GetType().Name & ".",
                Nothing,
                context)
        End Try
    End Sub

    Private Function IsFreeShipping(ByVal row As DataRow) As Boolean
        Dim configuredLists As String = Convert.ToString(ReadColumn(row, "SpedizioneGratis_Listini"))
        If configuredLists.Length = 0 OrElse _owner Is Nothing OrElse _owner.Listino <= 0 Then Return False

        Dim listToken As String = _owner.Listino.ToString(CultureInfo.InvariantCulture) & ";"
        If configuredLists.IndexOf(listToken, StringComparison.Ordinal) < 0 Then Return False

        Dim startDate As DateTime
        If Not TryReadDate(ReadColumn(row, "SpedizioneGratis_Data_Inizio"), startDate) OrElse startDate.Date > DateTime.Today Then
            Return False
        End If

        Dim endValue As Object = ReadColumn(row, "SpedizioneGratis_Data_Fine")
        If endValue Is Nothing OrElse endValue Is DBNull.Value OrElse Convert.ToString(endValue).Length = 0 Then Return True

        Dim endDate As DateTime
        Return TryReadDate(endValue, endDate) AndAlso endDate.Date >= DateTime.Today
    End Function

    Private Function SumLineAmount(ByVal amountColumn As String, ByVal unitPriceColumn As String) As Decimal
        Dim total As Decimal = 0D
        For Each row As DataRow In _items.Rows
            Dim amountValue As Object = ReadColumn(row, amountColumn)
            If amountValue IsNot Nothing AndAlso amountValue IsNot DBNull.Value Then
                total += SafeDecimal(amountValue, 0D)
            Else
                total += SafeDecimal(ReadColumn(row, "Qnt"), 0D) * SafeDecimal(ReadColumn(row, unitPriceColumn), 0D)
            End If
        Next
        Return total
    End Function

    Private Function CopyRows(ByVal rows As DataRowCollection) As DataTable
        Dim copy As DataTable = _items.Clone()
        For Each row As DataRow In rows
            copy.ImportRow(row)
        Next
        Return copy
    End Function

    Private Shared Function ReadColumn(ByVal row As DataRow, ByVal name As String) As Object
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(name) Then Return Nothing
        Return row(name)
    End Function

    Private Shared Function TryReadDate(ByVal value As Object, ByRef result As DateTime) As Boolean
        If value Is Nothing OrElse value Is DBNull.Value Then Return False
        Try
            result = Convert.ToDateTime(value, CultureInfo.InvariantCulture)
            Return True
        Catch
            Return DateTime.TryParse(Convert.ToString(value), result)
        End Try
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

Public NotInheritable Class CartAuthoritativeReadDataSource
    Public Function SelectStandardItems() As DataTable
        Return CartAuthoritativeReadModel.GetCurrent(HttpContext.Current).GetStandardItems()
    End Function

    Public Function SelectFreeShippingItems() As DataTable
        Return CartAuthoritativeReadModel.GetCurrent(HttpContext.Current).GetFreeShippingItems()
    End Function
End Class
