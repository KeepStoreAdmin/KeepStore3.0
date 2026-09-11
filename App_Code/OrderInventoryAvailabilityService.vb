Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports MySql.Data.MySqlClient

''' <summary>
''' Performs the transactional availability check used by checkout.
''' The canonical Carrello_Documento procedure owns the definitive inventory
''' reservation; this service never changes Impegnata.
''' </summary>
Public NotInheritable Class OrderInventoryAvailabilityService
    Private Const WebWarehouseId As Integer = 1
    Public Const CanonicalVariantId As Integer = -1

    Public Const SessionMessageKey As String = "OrderInventoryAvailabilityMessage"
    Public Const SessionLineKeysKey As String = "OrderInventoryAvailabilityLineKeys"
    Public Const InsufficientStockMessage As String = "Alcuni articoli non sono disponibili nella quantità richiesta. Controlla le quantità indicate, riducile oppure rimuovi gli articoli e premi 'Aggiorna carrello'. Potrai quindi procedere nuovamente con l'ordine."
    Public Const TechnicalErrorMessage As String = "Non è stato possibile verificare la disponibilità del carrello. Riprova."
    Public Const CanonicalProcedureSignalPrefix As String = "ORDER_INVENTORY_"

    Private Sub New()
    End Sub

    Public Shared Function ReserveCurrentCart(ByVal connection As MySqlConnection,
                                               ByVal transaction As MySqlTransaction,
                                               ByVal loginId As Integer) As OrderInventoryReservationResult
        ' Compatibility entry point for checkout. Reservation is deliberately
        ' performed only by the canonical stored procedure now.
        Return InspectCurrentCart(connection, transaction, loginId)
    End Function

    Public Shared Function InspectCurrentCart(ByVal connection As MySqlConnection,
                                              ByVal transaction As MySqlTransaction,
                                              ByVal loginId As Integer) As OrderInventoryReservationResult
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If transaction Is Nothing Then Throw New ArgumentNullException("transaction")
        If loginId <= 0 Then Throw New ArgumentOutOfRangeException("loginId")

        Dim requested As New SortedDictionary(Of String, OrderInventoryReservationLine)(StringComparer.Ordinal)
        Dim invalidLines As New List(Of OrderInventoryReservationLine)()

        ' Lock the owner-scoped cart deterministically. The transaction belongs
        ' to checkout and remains open for the canonical procedure.
        Using cartCommand As New MySqlCommand(
            "SELECT ID, ArticoliId, TCId, Qnt FROM carrello " &
            "WHERE LoginId=?loginId " &
            "ORDER BY ArticoliId, CASE WHEN TCId IS NULL THEN -2147483648 ELSE TCId END, ID FOR UPDATE",
            connection, transaction)
            cartCommand.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId

            Using reader As MySqlDataReader = cartCommand.ExecuteReader()
                While reader.Read()
                    Dim articleId As Integer = 0
                    If Not reader.IsDBNull(reader.GetOrdinal("ArticoliId")) Then
                        articleId = Convert.ToInt32(reader("ArticoliId"), CultureInfo.InvariantCulture)
                    End If

                    Dim hasTcId As Boolean = Not reader.IsDBNull(reader.GetOrdinal("TCId"))
                    Dim tcId As Integer = If(hasTcId, Convert.ToInt32(reader("TCId"), CultureInfo.InvariantCulture), CanonicalVariantId)
                    Dim quantity As Decimal = If(reader.IsDBNull(reader.GetOrdinal("Qnt")), 0D, Convert.ToDecimal(reader("Qnt"), CultureInfo.InvariantCulture))

                    If articleId <= 0 OrElse Not hasTcId OrElse quantity <= 0D Then
                        invalidLines.Add(New OrderInventoryReservationLine() With {
                            .ArticleId = articleId,
                            .TCId = tcId,
                            .RequestedQuantity = quantity,
                            .AvailableQuantity = 0D,
                            .IsInvalid = True
                        })
                        Continue While
                    End If

                    Dim key As String = BuildKey(articleId, tcId)
                    Dim line As OrderInventoryReservationLine = Nothing
                    If Not requested.TryGetValue(key, line) Then
                        line = New OrderInventoryReservationLine() With {
                            .ArticleId = articleId,
                            .TCId = tcId,
                            .RequestedQuantity = 0D
                        }
                        requested.Add(key, line)
                    End If
                    line.RequestedQuantity += quantity
                End While
            End Using
        End Using

        If invalidLines.Count > 0 Then
            Throw New OrderInventoryAvailabilityException(InsufficientStockMessage, invalidLines)
        End If
        If requested.Count = 0 Then
            Throw New OrderInventoryAvailabilityException(InsufficientStockMessage, New List(Of OrderInventoryReservationLine)())
        End If

        Dim failures As New List(Of OrderInventoryReservationLine)()
        For Each requestedLine As OrderInventoryReservationLine In requested.Values
            Using inventoryCommand As New MySqlCommand(
                "SELECT id, Giacenza, Impegnata FROM articoli_giacenze " &
                "WHERE MagazziniId=?warehouseId AND ArticoliId=?articleId AND TCId=?tcId FOR UPDATE",
                connection, transaction)
                inventoryCommand.Parameters.Add("?warehouseId", MySqlDbType.Int32).Value = WebWarehouseId
                inventoryCommand.Parameters.Add("?articleId", MySqlDbType.Int32).Value = requestedLine.ArticleId
                inventoryCommand.Parameters.Add("?tcId", MySqlDbType.Int32).Value = requestedLine.TCId

                Using reader As MySqlDataReader = inventoryCommand.ExecuteReader()
                    If Not reader.Read() Then
                        requestedLine.AvailableQuantity = 0D
                        requestedLine.IsMissing = True
                    Else
                        Dim giacenza As Decimal = If(reader.IsDBNull(reader.GetOrdinal("Giacenza")), 0D, Convert.ToDecimal(reader("Giacenza"), CultureInfo.InvariantCulture))
                        Dim impegnata As Decimal = If(reader.IsDBNull(reader.GetOrdinal("Impegnata")), 0D, Convert.ToDecimal(reader("Impegnata"), CultureInfo.InvariantCulture))
                        requestedLine.InventoryId = Convert.ToInt64(reader("id"), CultureInfo.InvariantCulture)
                        requestedLine.AvailableQuantity = Math.Max(0D, giacenza - impegnata)
                    End If
                End Using
            End Using

            If requestedLine.IsMissing OrElse requestedLine.AvailableQuantity < requestedLine.RequestedQuantity Then
                failures.Add(requestedLine)
            End If
        Next

        If failures.Count > 0 Then
            Throw New OrderInventoryAvailabilityException(InsufficientStockMessage, failures)
        End If

        Return New OrderInventoryReservationResult(New List(Of OrderInventoryReservationLine)(requested.Values))
    End Function

    Private Shared Function BuildKey(ByVal articleId As Integer, ByVal tcId As Integer) As String
        Return articleId.ToString(CultureInfo.InvariantCulture) & ":" & tcId.ToString(CultureInfo.InvariantCulture)
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
    Public Property RequestedQuantity As Decimal
    Public Property AvailableQuantity As Decimal
    Public Property InventoryId As Long
    Public Property IsMissing As Boolean
    Public Property IsInvalid As Boolean

    Public ReadOnly Property Quantity As Decimal
        Get
            Return RequestedQuantity
        End Get
    End Property

    Public ReadOnly Property Key As String
        Get
            Return ArticleId.ToString(CultureInfo.InvariantCulture) & ":" & TCId.ToString(CultureInfo.InvariantCulture)
        End Get
    End Property
End Class

Public Class OrderInventoryAvailabilityException
    Inherits InvalidOperationException

    Private ReadOnly _lines As IList(Of OrderInventoryReservationLine)

    Public Sub New(ByVal message As String, ByVal lines As IList(Of OrderInventoryReservationLine))
        MyBase.New(message)
        _lines = If(lines, New List(Of OrderInventoryReservationLine)())
    End Sub

    Public ReadOnly Property Lines As IList(Of OrderInventoryReservationLine)
        Get
            Return _lines
        End Get
    End Property

    Public Function BuildLineKeys() As String
        Dim keys As New List(Of String)()
        For Each line As OrderInventoryReservationLine In _lines
            If line IsNot Nothing Then keys.Add(line.Key)
        Next
        Return String.Join("|", keys.ToArray())
    End Function

    Public Function BuildUserMessage() As String
        Dim parts As New List(Of String)()
        parts.Add(Message)
        For Each line As OrderInventoryReservationLine In _lines
            If line Is Nothing Then Continue For
            Dim available As String = line.AvailableQuantity.ToString("0.###", CultureInfo.InvariantCulture)
            Dim requested As String = line.RequestedQuantity.ToString("0.###", CultureInfo.InvariantCulture)
            parts.Add("Articolo " & line.ArticleId.ToString(CultureInfo.InvariantCulture) & ": Quantità richiesta: " & requested & "; Disponibilità attuale: " & available)
        Next
        Return String.Join(Environment.NewLine, parts.ToArray())
    End Function
End Class
