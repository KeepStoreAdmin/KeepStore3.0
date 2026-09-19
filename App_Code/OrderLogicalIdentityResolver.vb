Imports System
Imports System.Collections.Generic

Public NotInheritable Class OrderLogicalIdentityRow
    Public Property UserId As Long
    Public Property PriceListId As Integer
End Class

''' <summary>
''' Collapses duplicate physical vlogin rows only when every row represents the
''' same complete logical account. Any missing, invalid or different identity
''' remains fail-closed.
''' </summary>
Public NotInheritable Class OrderLogicalIdentityResolver
    Private Sub New()
    End Sub

    Public Shared Function TryResolve(ByVal rows As IEnumerable(Of OrderLogicalIdentityRow),
                                      ByRef userId As Long,
                                      ByRef priceListId As Integer) As Boolean
        userId = 0
        priceListId = 0
        If rows Is Nothing Then Return False

        Dim found As Boolean = False
        For Each row As OrderLogicalIdentityRow In rows
            If row Is Nothing OrElse row.UserId <= 0 OrElse row.PriceListId <= 0 Then Return False
            If Not found Then
                userId = row.UserId
                priceListId = row.PriceListId
                found = True
            ElseIf row.UserId <> userId OrElse row.PriceListId <> priceListId Then
                Return False
            End If
        Next
        Return found
    End Function
End Class
