Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web

''' <summary>
''' Six display slots, preserving their original positions and repeated URLs.
''' Missing slots inherit the preceding image; leading gaps use the first valid image.
''' Structured-data consumers must continue to select distinct original photographs.
''' </summary>
Public NotInheritable Class StorefrontProductImageSlots
    Private Const ResolutionCacheKey As String = "KeepStore.ProductImageSlots.Resolution"

    Private Sub New()
    End Sub

    Public Shared Function FromDataItem(ByVal dataItem As Object) As List(Of String)
        Dim raw As New List(Of Object)()
        For index As Integer = 1 To 6
            raw.Add(UiData.Get(dataItem, "Img" & index.ToString(CultureInfo.InvariantCulture)))
        Next
        Return Resolve(raw)
    End Function

    Public Shared Function CoverUrl(ByVal dataItem As Object) As String
        Return FromDataItem(dataItem)(0)
    End Function

    Public Shared Function HoverUrl(ByVal dataItem As Object) As String
        Return FromDataItem(dataItem)(1)
    End Function

    Public Shared Function Resolve(ByVal rawImages As IEnumerable(Of Object)) As List(Of String)
        Dim urls(5) As String
        Dim index As Integer = 0
        If rawImages IsNot Nothing Then
            For Each raw As Object In rawImages
                If index = 6 Then Exit For
                urls(index) = ResolveValidImage(raw)
                index += 1
            Next
        End If

        Dim last As String = Nothing
        For Each url As String In urls
            If Not String.IsNullOrWhiteSpace(url) Then
                last = url
                Exit For
            End If
        Next
        If String.IsNullOrWhiteSpace(last) Then last = ThemeManager.PlaceholderProductImageUrl()

        Dim slots As New List(Of String)(6)
        For Each url As String In urls
            If Not String.IsNullOrWhiteSpace(url) Then last = url
            slots.Add(last)
        Next
        Return slots
    End Function

    Private Shared Function ResolveValidImage(ByVal value As Object) As String
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return String.Empty
        Dim raw As String = Convert.ToString(value, CultureInfo.InvariantCulture).Trim()
        If raw.Length = 0 Then Return String.Empty
        For index As Integer = 1 To 6
            If String.Equals(raw, "img" & index.ToString(CultureInfo.InvariantCulture), StringComparison.OrdinalIgnoreCase) Then Return String.Empty
        Next

        ' Cache validity checks per request, not slots: duplicates retain their positions.
        Dim context As HttpContext = HttpContext.Current
        Dim cache As Dictionary(Of String, String) = Nothing
        If context IsNot Nothing Then
            cache = TryCast(context.Items(ResolutionCacheKey), Dictionary(Of String, String))
            If cache Is Nothing Then
                cache = New Dictionary(Of String, String)(StringComparer.Ordinal)
                context.Items(ResolutionCacheKey) = cache
            End If
            Dim cached As String = Nothing
            If cache.TryGetValue(raw, cached) Then Return cached
        End If

        Dim resolved As String = ThemeManager.ProductImageUrl(raw)
        If String.Equals(resolved, ThemeManager.PlaceholderProductImageUrl(), StringComparison.Ordinal) Then resolved = String.Empty
        If cache IsNot Nothing Then cache(raw) = resolved
        Return resolved
    End Function
End Class
