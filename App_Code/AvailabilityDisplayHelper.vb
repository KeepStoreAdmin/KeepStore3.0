Imports System
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web

Public Class AvailabilityDisplayModel
    Public Property StockQty As Decimal
    Public Property AvailableQty As Decimal
    Public Property CommittedQty As Decimal
    Public Property IncomingQty As Decimal
    Public Property IsAvailable As Boolean
    Public Property DisplayMode As Integer
    Public Property StatusText As String
    Public Property StatusCssClass As String
    Public Property LegacyText As String
    Public Property Text As String
    Public Property Html As String
End Class

Public Module AvailabilityDisplayHelper
    Private Const DefaultDisplayMode As Integer = 1

    Public Function GetDisplayMode(Optional ByVal ctx As HttpContext = Nothing) As Integer
        Dim mode As Integer = DefaultDisplayMode

        Try
            If ctx Is Nothing Then ctx = HttpContext.Current
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing Then
                Dim raw As Object = ctx.Session("DispoTipo")
                If raw IsNot Nothing AndAlso Not Convert.IsDBNull(raw) Then
                    Integer.TryParse(Convert.ToString(raw), mode)
                End If
            End If
        Catch
            mode = DefaultDisplayMode
        End Try

        If mode <> 2 Then mode = DefaultDisplayMode
        Return mode
    End Function

    Public Function BuildFromDataItem(ByVal dataItem As Object, Optional ByVal ctx As HttpContext = Nothing) As AvailabilityDisplayModel
        Dim model As New AvailabilityDisplayModel()
        model.DisplayMode = GetDisplayMode(ctx)
        model.StockQty = Quantity(dataItem, "Giacenza")
        model.AvailableQty = Quantity(dataItem, "Disponibilita")
        model.CommittedQty = Quantity(dataItem, "Impegnata")
        model.IncomingQty = Quantity(dataItem, "InOrdine")

        Dim effectiveStock As Decimal = model.StockQty - model.CommittedQty
        model.IsAvailable = (effectiveStock > 0D OrElse model.AvailableQty > 0D)
        model.StatusText = If(model.IsAvailable, "Disponibile", "Non disponibile")
        model.StatusCssClass = If(model.IsAvailable, "ks-availability-ok", "ks-availability-check")
        model.LegacyText = BuildLegacyStatusText(dataItem, effectiveStock, model.AvailableQty, model.IncomingQty)

        If model.DisplayMode = 2 Then
            model.Text = "Disponibilita: " & FormatQuantity(model.AvailableQty) &
                         "; Impegnati: " & FormatQuantity(model.CommittedQty) &
                         "; In Arrivo: " & FormatQuantity(model.IncomingQty) &
                         "; " & model.StatusText
        Else
            model.Text = model.LegacyText
        End If

        model.Html = BuildHtml(model)
        Return model
    End Function

    Public Function BuildText(ByVal dataItem As Object, Optional ByVal ctx As HttpContext = Nothing) As String
        Return BuildFromDataItem(dataItem, ctx).Text
    End Function

    Public Function BuildHtml(ByVal dataItem As Object, Optional ByVal ctx As HttpContext = Nothing) As String
        Return BuildFromDataItem(dataItem, ctx).Html
    End Function

    Public Function BuildCssClass(ByVal dataItem As Object, Optional ByVal ctx As HttpContext = Nothing) As String
        Return BuildFromDataItem(dataItem, ctx).StatusCssClass
    End Function

    Private Function BuildHtml(ByVal model As AvailabilityDisplayModel) As String
        If model Is Nothing Then Return String.Empty

        If model.DisplayMode <> 2 Then
            Dim legacyCss As String = CssClassForLegacyStatus(model.LegacyText)
            Return "<span class=""" & legacyCss & """>" & HtmlEncode(model.LegacyText) & "</span>"
        End If

        Dim statusStyle As String = If(model.IsAvailable, "", " style=""color:#b42318;font-weight:700;""")
        Dim sb As New StringBuilder()
        sb.Append("<span class=""ks-availability-numeric"" style=""display:inline-flex;flex-direction:column;gap:2px;line-height:1.35;"">")
        sb.Append("<span><span class=""fw-semibold"">Disponibilita:</span> ").Append(HtmlEncode(FormatQuantity(model.AvailableQty))).Append("</span>")
        sb.Append("<span><span class=""fw-semibold"">Impegnati:</span> ").Append(HtmlEncode(FormatQuantity(model.CommittedQty))).Append("</span>")
        sb.Append("<span><span class=""fw-semibold"">In Arrivo:</span> ").Append(HtmlEncode(FormatQuantity(model.IncomingQty))).Append("</span>")
        sb.Append("<span class=""").Append(model.StatusCssClass).Append("""" & statusStyle & ">").Append(HtmlEncode(model.StatusText)).Append("</span>")
        sb.Append("</span>")
        Return sb.ToString()
    End Function

    Private Function BuildLegacyStatusText(ByVal dataItem As Object, ByVal effectiveStock As Decimal, ByVal availabilityQty As Decimal, ByVal incomingQty As Decimal) As String
        If effectiveStock > 0D Then Return "Disponibile"

        Dim arrivalText As String = FirstNonEmpty(TextValue(dataItem, "Arrivo"), StripHtml(TextValue(dataItem, "arrivi")))
        If Not String.IsNullOrEmpty(arrivalText) Then
            Return "In arrivo: " & ThemeManager.CompactText(arrivalText, 90)
        End If

        If availabilityQty > 0D Then Return "Disponibile su ordinazione"
        If incomingQty > 0D Then Return "In ordine"
        Return "Verifica disponibilita"
    End Function

    Private Function CssClassForLegacyStatus(ByVal text As String) As String
        If String.IsNullOrWhiteSpace(text) Then Return "ks-availability-check"
        If text.IndexOf("Disponibile", StringComparison.OrdinalIgnoreCase) >= 0 Then Return "ks-availability-ok"
        If text.IndexOf("arrivo", StringComparison.OrdinalIgnoreCase) >= 0 OrElse text.IndexOf("ordine", StringComparison.OrdinalIgnoreCase) >= 0 Then Return "ks-availability-wait"
        Return "ks-availability-check"
    End Function

    Private Function Quantity(ByVal dataItem As Object, ByVal columnName As String) As Decimal
        Dim raw As Object = UiData.Get(dataItem, columnName)
        If raw Is Nothing OrElse Convert.IsDBNull(raw) Then Return 0D

        Dim d As Decimal
        If Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.CurrentCulture, d) Then Return d
        If Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
        Return 0D
    End Function

    Private Function TextValue(ByVal dataItem As Object, ByVal columnName As String) As String
        Return UiData.Str(dataItem, columnName, String.Empty)
    End Function

    Private Function FormatQuantity(ByVal value As Decimal) As String
        Return value.ToString("0.##", CultureInfo.InvariantCulture)
    End Function

    Private Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then Return String.Empty
        For Each value As String In values
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Next
        Return String.Empty
    End Function

    Private Function StripHtml(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return String.Empty
        Return Regex.Replace(value, "<[^>]+>", " ").Trim()
    End Function

    Private Function HtmlEncode(ByVal value As String) As String
        Return HttpUtility.HtmlEncode(If(value, String.Empty))
    End Function
End Module
