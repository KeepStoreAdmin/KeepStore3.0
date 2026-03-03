Imports System
Imports System.Data

' Helper per DataBinding sicuro (evita eccezioni se una colonna non esiste)
Public Module UiData

    Public Function HasColumn(ByVal dataItem As Object, ByVal columnName As String) As Boolean
        If dataItem Is Nothing OrElse String.IsNullOrWhiteSpace(columnName) Then Return False

        Dim drv As DataRowView = TryCast(dataItem, DataRowView)
        If drv IsNot Nothing AndAlso drv.DataView IsNot Nothing AndAlso drv.DataView.Table IsNot Nothing Then
            Return drv.DataView.Table.Columns.Contains(columnName)
        End If

        Dim dr As DataRow = TryCast(dataItem, DataRow)
        If dr IsNot Nothing AndAlso dr.Table IsNot Nothing Then
            Return dr.Table.Columns.Contains(columnName)
        End If

        Return False
    End Function

    Public Function [Get](ByVal dataItem As Object, ByVal columnName As String) As Object
        If Not HasColumn(dataItem, columnName) Then Return Nothing

        Dim drv As DataRowView = TryCast(dataItem, DataRowView)
        If drv IsNot Nothing Then
            Return drv(columnName)
        End If

        Dim dr As DataRow = TryCast(dataItem, DataRow)
        If dr IsNot Nothing Then
            Return dr(columnName)
        End If

        Return Nothing
    End Function

    Public Function [Str](ByVal dataItem As Object, ByVal columnName As String, Optional ByVal defaultValue As String = "") As String
        Dim v As Object = [Get](dataItem, columnName)
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return defaultValue
        Return Convert.ToString(v)
    End Function

    Public Function [Int](ByVal dataItem As Object, ByVal columnName As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Dim v As Object = [Get](dataItem, columnName)
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return defaultValue

        Dim n As Integer
        If Integer.TryParse(Convert.ToString(v), n) Then Return n
        Return defaultValue
    End Function

    Public Function [Bool](ByVal dataItem As Object, ByVal columnName As String, Optional ByVal defaultValue As Boolean = False) As Boolean
        Dim v As Object = [Get](dataItem, columnName)
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return defaultValue

        Dim s As String = Convert.ToString(v).Trim()
        If String.Equals(s, "1") OrElse String.Equals(s, "true", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(s, "yes", StringComparison.OrdinalIgnoreCase) Then
            Return True
        End If

        If String.Equals(s, "0") OrElse String.Equals(s, "false", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(s, "no", StringComparison.OrdinalIgnoreCase) Then
            Return False
        End If

        Dim b As Boolean
        If Boolean.TryParse(s, b) Then Return b

        Return defaultValue
    End Function

End Module
