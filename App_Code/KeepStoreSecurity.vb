Imports System
Imports System.Web

' Shared security helper methods.
' Note: keep these functions side-effect free and unit-testable where possible.
Public Module KeepStoreSecurity

    Public Function Html(value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Public Function HtmlAttr(value As Object) As String
        Return HttpUtility.HtmlAttributeEncode(Convert.ToString(value))
    End Function

    Public Function Js(value As Object) As String
        Return HttpUtility.JavaScriptStringEncode(Convert.ToString(value))
    End Function

    Public Function Url(value As Object) As String
        Return HttpUtility.UrlEncode(Convert.ToString(value))
    End Function

    ' Parses an integer and clamps it.
    Public Function ParseInt(value As String, Optional defaultValue As Integer = 0,
                             Optional minValue As Integer = Integer.MinValue,
                             Optional maxValue As Integer = Integer.MaxValue) As Integer
        Dim n As Integer
        If Integer.TryParse(value, n) Then
            If n < minValue Then Return minValue
            If n > maxValue Then Return maxValue
            Return n
        End If
        Return defaultValue
    End Function

    ' Builds a comma-separated list of positive integer ids, safe for SQL IN(...).
    ' Use only when parameter arrays are not feasible.
    Public Function SafeCsvIds(csv As String, Optional maxItems As Integer = 100) As String
        If String.IsNullOrWhiteSpace(csv) Then Return ""
        Dim parts = csv.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        Dim outParts As New System.Collections.Generic.List(Of String)()
        For Each p In parts
            Dim n As Integer
            If Integer.TryParse(p.Trim(), n) AndAlso n > 0 Then
                outParts.Add(n.ToString())
                If outParts.Count >= maxItems Then Exit For
            End If
        Next
        Return String.Join(",", outParts)
    End Function

    ' Escapes a value for safe inclusion inside MySQL string literals within LIKE patterns.
    Public Function SqlEscapeLike(value As String, Optional maxLen As Integer = 120) As String
        If value Is Nothing Then Return ""
        Dim v As String = value.Trim()
        If v.Length > maxLen Then v = v.Substring(0, maxLen)
        Return MySql.Data.MySqlClient.MySqlHelper.EscapeString(v)
    End Function
End Module
