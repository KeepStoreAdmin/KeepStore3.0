Imports System
Imports System.Collections.Specialized
Imports System.Collections.Generic
Imports System.Globalization

Public NotInheritable Class LegacyPromotionRoutePolicy
    Private Const ModernPage As String = "articoli.aspx"
    Private Const InvalidCampaignMarker As String = "invalid"

    Private Shared ReadOnly LegacyKeys() As String = {
        "pid", "pmr", "pst", "pct", "ptp", "pgr", "psg"
    }

    Private Shared ReadOnly ModernKeys() As String = {
        "pid", "mr", "st", "ct", "tp", "gr", "sg"
    }

    Private Sub New()
    End Sub

    Public Shared Function BuildModernPath(ByVal query As NameValueCollection,
                                           ByVal applicationPath As String) As String
        Dim baseDestination As String = ApplicationPagePath(applicationPath, ModernPage) & "?inpromo=1"
        Dim invalidDestination As String = baseDestination & "&pid=" & InvalidCampaignMarker

        If query Is Nothing OrElse query.Count = 0 Then Return baseDestination

        Dim allowed As New HashSet(Of String)(LegacyKeys, StringComparer.OrdinalIgnoreCase)
        allowed.Add("part")

        For Each rawKey As String In query.AllKeys
            If String.IsNullOrWhiteSpace(rawKey) OrElse Not allowed.Contains(rawKey) Then
                Return invalidDestination
            End If
        Next

        ' part era un filtro per ArticoliId della pagina legacy. Il catalogo moderno
        ' non espone un filtro equivalente: qualunque sua presenza deve fallire chiusa.
        If query.GetValues("part") IsNot Nothing Then Return invalidDestination

        Dim destinationParts As New List(Of String) From {"inpromo=1"}
        For index As Integer = 0 To LegacyKeys.Length - 1
            Dim values() As String = query.GetValues(LegacyKeys(index))
            If values Is Nothing Then Continue For
            If values.Length <> 1 Then Return invalidDestination

            Dim parsed As Integer
            If LegacyKeys(index) = "pid" AndAlso String.Equals(values(0), "0", StringComparison.Ordinal) Then
                Continue For
            End If
            If Not TryParsePositiveId(values(0), parsed) Then Return invalidDestination

            destinationParts.Add(ModernKeys(index) & "=" & parsed.ToString(CultureInfo.InvariantCulture))
        Next

        Return ApplicationPagePath(applicationPath, ModernPage) & "?" & String.Join("&", destinationParts.ToArray())
    End Function

    Public Shared Function IsLegacyPage(ByVal pageName As String) As Boolean
        Return String.Equals(pageName, "promozioni.aspx", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function TryParsePositiveId(ByVal rawValue As String,
                                               ByRef parsed As Integer) As Boolean
        parsed = 0
        If String.IsNullOrEmpty(rawValue) Then Return False

        For Each character As Char In rawValue
            If character < "0"c OrElse character > "9"c Then Return False
        Next

        Return Integer.TryParse(rawValue,
                                NumberStyles.None,
                                CultureInfo.InvariantCulture,
                                parsed) AndAlso parsed > 0
    End Function

    Private Shared Function ApplicationPagePath(ByVal applicationPath As String,
                                                ByVal pageName As String) As String
        Dim root As String = Convert.ToString(applicationPath)
        If String.IsNullOrWhiteSpace(root) OrElse root = "/" Then Return "/" & pageName
        Return "/" & root.Trim("/"c) & "/" & pageName
    End Function
End Class
