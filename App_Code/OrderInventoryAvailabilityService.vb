Imports System
Imports System.Collections.Generic
Imports System.Data
Imports MySql.Data.MySqlClient

''' <summary>
''' Reserves the quantity of the current web cart against the canonical
''' warehouse-1 inventory rows.  The caller owns the connection and
''' transaction; no commit is ever performed here.
''' </summary>
Public NotInheritable Class OrderInventoryAvailabilityService
    Private Const WebWarehouseId As Integer = 1
    Private Const CanonicalVariantId As Integer = -1

    Public Const SessionMessageKey As String = "OrderInventoryAvailabilityMessage"
    Public Const InsufficientStockMessage As String = "La disponibilità di uno o più articoli è cambiata. Controlla il carrello e riprova."
    Public Const TechnicalErrorMessage As String = "Non è stato possibile verificare la disponibilità del carrello. Riprova."

    Private Sub New()
    End Sub

    Public Shared Function ReserveCurrentCart(ByVal connection As MySqlConnection,
                                               ByVal transaction As MySqlTransaction,
                                               ByVal loginId As Integer) As OrderInventoryReservationResult
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")
        If loginId <= 0 Then Throw New ArgumentOutOfRangeException("loginId")

        Dim requested As New SortedDictionary(Of String, OrderInventoryReservationLine)(StringComparer.Ordinal)

        ' Lock all owned cart rows first, in one deterministic order.  This
        ' prevents two checkout workers from taking inventory locks in reverse
        ' order and keeps ownership server-side.
        Using cartCommand As New MySqlCommand(
            "SELECT ArticoliId, TCId, Qnt FROM carrello " &
            "WHERE LoginId=?loginId ORDER BY ArticoliId, COALESCE(TCId,-1), ID FOR UPDATE",
            connection, transaction)
            cartCommand.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId

            Using reader As MySqlDataReader = cartCommand.ExecuteReader()
                While reader.Read()
                    If reader.IsDBNull(reader.GetOrdinal("ArticoliId")) Then
                        Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
                    End If

                    Dim articleId As Integer = Convert.ToInt32(reader("ArticoliId"))
                    If articleId <= 0 OrElse reader.IsDBNull(reader.GetOrdinal("TCId")) Then
                        Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
                    End If

                    Dim tcId As Integer = Convert.ToInt32(reader("TCId"))
                    Dim quantity As Decimal = Convert.ToDecimal(reader("Qnt"))
                    If quantity <= 0D Then
                        Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
                    End If

                    Dim key As String = articleId.ToString(Globalization.CultureInfo.InvariantCulture) & ":" & tcId.ToString(Globalization.CultureInfo.InvariantCulture)
                    Dim line As OrderInventoryReservationLine = Nothing
                    If Not requested.TryGetValue(key, line) Then
                        line = New OrderInventoryReservationLine() With {
                            .ArticleId = articleId,
                            .TCId = tcId,
                            .Quantity = 0D
                        }
                        requested.Add(key, line)
                    End If
                    line.Quantity += quantity
                End While
            End Using
        End Using

        If requested.Count = 0 Then
            Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
        End If

        Dim reserved As New List(Of OrderInventoryReservationLine)()
        For Each requestedLine As OrderInventoryReservationLine In requested.Values
            Dim inventoryId As Long = 0L
            Dim giacenza As Decimal = 0D
            Dim impegnata As Decimal = 0D

            ' Inventory locks are taken only for warehouse 1 and in the same
            ' article/variant order as the cart lock above.
            Using inventoryCommand As New MySqlCommand(
                "SELECT id, Giacenza, Impegnata FROM articoli_giacenze " &
                "WHERE MagazziniId=?warehouseId AND ArticoliId=?articleId AND TCId=?tcId FOR UPDATE",
                connection, transaction)
                inventoryCommand.Parameters.Add("?warehouseId", MySqlDbType.Int32).Value = WebWarehouseId
                inventoryCommand.Parameters.Add("?articleId", MySqlDbType.Int32).Value = requestedLine.ArticleId
                inventoryCommand.Parameters.Add("?tcId", MySqlDbType.Int32).Value = requestedLine.TCId

                Using reader As MySqlDataReader = inventoryCommand.ExecuteReader()
                    If Not reader.Read() Then
                        Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
                    End If
                    inventoryId = Convert.ToInt64(reader("id"))
                    giacenza = If(reader.IsDBNull(reader.GetOrdinal("Giacenza")), 0D, Convert.ToDecimal(reader("Giacenza")))
                    impegnata = If(reader.IsDBNull(reader.GetOrdinal("Impegnata")), 0D, Convert.ToDecimal(reader("Impegnata")))
                End Using
            End Using

            If giacenza - impegnata < requestedLine.Quantity Then
                Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
            End If

            Using updateCommand As New MySqlCommand(
                "UPDATE articoli_giacenze SET Impegnata=COALESCE(Impegnata,0)+?quantity " &
                "WHERE id=?inventoryId AND MagazziniId=?warehouseId AND ArticoliId=?articleId AND TCId=?tcId " &
                "AND (COALESCE(Giacenza,0)-COALESCE(Impegnata,0))>=?quantity",
                connection, transaction)
                updateCommand.Parameters.Add("?quantity", MySqlDbType.Decimal).Value = requestedLine.Quantity
                updateCommand.Parameters.Add("?inventoryId", MySqlDbType.Int64).Value = inventoryId
                updateCommand.Parameters.Add("?warehouseId", MySqlDbType.Int32).Value = WebWarehouseId
                updateCommand.Parameters.Add("?articleId", MySqlDbType.Int32).Value = requestedLine.ArticleId
                updateCommand.Parameters.Add("?tcId", MySqlDbType.Int32).Value = requestedLine.TCId

                If updateCommand.ExecuteNonQuery() <> 1 Then
                    Throw New OrderInventoryAvailabilityException(InsufficientStockMessage)
                End If
            End Using

            reserved.Add(New OrderInventoryReservationLine() With {
                .ArticleId = requestedLine.ArticleId,
                .TCId = requestedLine.TCId,
                .Quantity = requestedLine.Quantity,
                .InventoryId = inventoryId
            })
        Next

        Return New OrderInventoryReservationResult(reserved)
    End Function
End Class

Public NotInheritable Class OrderInventoryReservationResult
    Private ReadOnly _lines As IList(Of OrderInventoryReservationLine)

    Friend Sub New(ByVal lines As IList(Of OrderInventoryReservationLine))
        _lines = New List(Of OrderInventoryReservationLine)(lines)
    End Sub

    Public ReadOnly Property Lines As IList(Of OrderInventoryReservationLine)
        Get
            Return _lines
        End Get
    End Property
End Class

Public NotInheritable Class OrderInventoryReservationLine
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal
    Public Property InventoryId As Long
End Class

Public Class OrderInventoryAvailabilityException
    Inherits InvalidOperationException

    Public Sub New(ByVal message As String)
        MyBase.New(message)
    End Sub
End Class
