Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization

' Rotazione delle vetrine: l'ordine dei candidati, GIA idonei e ordinati dalla regola commerciale, viene rimescolato dentro una finestra
' (i primi K x N) in modo che a ogni richiesta compaia un sottoinsieme diverso. Non allarga mai l'idoneita: restituisce le stesse righe,
' in un altro ordine, e non tocca prezzi ne promozioni (che restano calcolati per ogni articolo dal resolver autorevole).
' Gli articoli mostrati l'ultima volta vanno in coda alla finestra: con almeno 2 x N candidati il nuovo insieme e disgiunto dal precedente.
Public NotInheritable Class StorefrontShowcaseRotation
    Public Const WindowFactor As Integer = 3

    Private Sub New()
    End Sub

    Public Shared Function Rotate(ByVal source As DataTable,
                                  ByVal take As Integer,
                                  ByVal recentIds As ICollection(Of Integer),
                                  ByVal random As Random) As DataTable
        If source Is Nothing OrElse source.Rows.Count = 0 OrElse take <= 0 OrElse random Is Nothing OrElse
           Not source.Columns.Contains("id") Then Return source

        Dim windowSize As Integer = Math.Min(source.Rows.Count, take * WindowFactor)
        Dim fresh As New List(Of DataRow)()
        Dim stale As New List(Of DataRow)()
        For index As Integer = 0 To windowSize - 1
            Dim row As DataRow = source.Rows(index)
            Dim id As Integer = RowId(row)
            If recentIds IsNot Nothing AndAlso id > 0 AndAlso recentIds.Contains(id) Then
                stale.Add(row)
            Else
                fresh.Add(row)
            End If
        Next
        Shuffle(fresh, random)
        Shuffle(stale, random)

        Dim result As DataTable = source.Clone()
        For Each row As DataRow In fresh
            result.ImportRow(row)
        Next
        For Each row As DataRow In stale
            result.ImportRow(row)
        Next
        For index As Integer = windowSize To source.Rows.Count - 1
            result.ImportRow(source.Rows(index))
        Next
        Return result
    End Function

    Public Shared Function ParseIds(ByVal raw As Object) As HashSet(Of Integer)
        Dim result As New HashSet(Of Integer)()
        Dim text As String = Convert.ToString(raw)
        If String.IsNullOrWhiteSpace(text) Then Return result
        For Each part As String In text.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
            Dim id As Integer
            If Integer.TryParse(part.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, id) AndAlso id > 0 Then result.Add(id)
            If result.Count >= 64 Then Exit For
        Next
        Return result
    End Function

    Public Shared Function FormatIds(ByVal table As DataTable) As String
        If table Is Nothing OrElse Not table.Columns.Contains("id") Then Return String.Empty
        Dim ids As New List(Of String)()
        For Each row As DataRow In table.Rows
            Dim id As Integer = RowId(row)
            If id > 0 Then ids.Add(id.ToString(CultureInfo.InvariantCulture))
            If ids.Count >= 64 Then Exit For
        Next
        Return String.Join(",", ids.ToArray())
    End Function

    Private Shared Function RowId(ByVal row As DataRow) As Integer
        Dim id As Integer
        If row Is Nothing OrElse row.IsNull("id") Then Return 0
        If Integer.TryParse(Convert.ToString(row("id"), CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, id) Then Return id
        Return 0
    End Function

    Private Shared Sub Shuffle(ByVal rows As List(Of DataRow), ByVal random As Random)
        For index As Integer = rows.Count - 1 To 1 Step -1
            Dim other As Integer = random.Next(index + 1)
            Dim keep As DataRow = rows(index)
            rows(index) = rows(other)
            rows(other) = keep
        Next
    End Sub
End Class
