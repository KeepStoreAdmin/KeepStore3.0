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
    Public Property LowStockThreshold As Decimal
    Public Property IsAvailable As Boolean
    Public Property DisplayMode As Integer
    Public Property StatusText As String
    Public Property StatusCssClass As String
    Public Property StatusStyle As String
    Public Property DotCssClass As String
    Public Property DotStyle As String
    Public Property LegacyText As String
    Public Property Text As String
    Public Property Html As String
End Class

Public Module AvailabilityDisplayHelper
    Private Const DefaultDisplayMode As Integer = 1
    Private Const DefaultLowStockThreshold As Decimal = 2D

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
        model.CommittedQty = Quantity(dataItem, "Impegnata")
        model.IncomingQty = Quantity(dataItem, "InOrdine")
        model.AvailableQty = EffectiveAvailableQty(dataItem, model.StockQty, model.CommittedQty)
        model.LowStockThreshold = LowStockThreshold(dataItem)

        ApplySyntheticStatus(model)
        model.LegacyText = BuildLegacyStatusText(dataItem, model.AvailableQty, model.IncomingQty)

        If model.DisplayMode = 2 Then
            model.Text = "Disponibilità: " & FormatQuantity(model.AvailableQty) &
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
            Dim sbSynthetic As New StringBuilder()
            sbSynthetic.Append("<span class=""ks-availability-synthetic"" style=""display:inline-flex;align-items:center;gap:7px;line-height:1.35;"">")
            sbSynthetic.Append("<span class=""ks-availability-dot ").Append(model.DotCssClass).Append(""" style=""display:inline-block;width:9px;height:9px;border-radius:50%;flex:0 0 9px;").Append(model.DotStyle).Append(""" aria-hidden=""true""></span>")
            sbSynthetic.Append("<span class=""").Append(model.StatusCssClass).Append("""" & model.StatusStyle & ">").Append(HtmlEncode(model.StatusText)).Append("</span>")
            sbSynthetic.Append("</span>")
            Return sbSynthetic.ToString()
        End If

        Dim sb As New StringBuilder()
        sb.Append("<span class=""ks-availability-numeric"" style=""display:inline-flex;flex-direction:column;gap:2px;line-height:1.35;"">")
        sb.Append("<span><span class=""fw-semibold"">Disponibilità:</span> ").Append(HtmlEncode(FormatQuantity(model.AvailableQty))).Append("</span>")
        sb.Append("<span><span class=""fw-semibold"">Impegnati:</span> ").Append(HtmlEncode(FormatQuantity(model.CommittedQty))).Append("</span>")
        sb.Append("<span><span class=""fw-semibold"">In Arrivo:</span> ").Append(HtmlEncode(FormatQuantity(model.IncomingQty))).Append("</span>")
        sb.Append("<span class=""").Append(model.StatusCssClass).Append("""" & model.StatusStyle & ">").Append(HtmlEncode(model.StatusText)).Append("</span>")
        sb.Append("</span>")
        Return sb.ToString()
    End Function

    Private Sub ApplySyntheticStatus(ByVal model As AvailabilityDisplayModel)
        If model Is Nothing Then Return

        If model.AvailableQty > 0D Then
            If model.AvailableQty <= model.LowStockThreshold Then
                ApplyStatus(model, "Pochi pezzi", "ks-availability-status-low", "ks-availability-dot-low", "#b45309")
            Else
                ApplyStatus(model, "Disponibile", "ks-availability-status-ok", "ks-availability-dot-ok", "#15803d")
            End If
        ElseIf model.IncomingQty > 0D Then
            ApplyStatus(model, "In arrivo", "ks-availability-status-low", "ks-availability-dot-low", "#b45309")
        Else
            ApplyStatus(model, "Non disponibile", "ks-availability-status-ko", "ks-availability-dot-ko", "#b42318")
        End If

        model.IsAvailable = (model.AvailableQty > 0D)
    End Sub

    Private Sub ApplyStatus(ByVal model As AvailabilityDisplayModel, ByVal text As String, ByVal statusCssClass As String, ByVal dotCssClass As String, ByVal color As String)
        model.StatusText = text
        model.StatusCssClass = statusCssClass
        model.DotCssClass = dotCssClass
        model.StatusStyle = " style=""color:" & color & ";font-weight:700;"""
        model.DotStyle = "background-color:" & color & ";"
    End Sub

    Private Function BuildLegacyStatusText(ByVal dataItem As Object, ByVal availabilityQty As Decimal, ByVal incomingQty As Decimal) As String
        If availabilityQty > 0D Then Return "Disponibile"

        Dim arrivalText As String = FirstNonEmpty(TextValue(dataItem, "Arrivo"), StripHtml(TextValue(dataItem, "arrivi")))
        If Not String.IsNullOrEmpty(arrivalText) Then
            Return "In arrivo: " & ThemeManager.CompactText(arrivalText, 90)
        End If

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

    Private Function EffectiveAvailableQty(ByVal dataItem As Object, ByVal stockQty As Decimal, ByVal committedQty As Decimal) As Decimal
        Dim raw As Object = UiData.Get(dataItem, "Disponibilita")
        If raw IsNot Nothing AndAlso Not Convert.IsDBNull(raw) Then
            Dim parsed As Decimal
            If Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.CurrentCulture, parsed) AndAlso parsed > 0D Then Return parsed
            If Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.InvariantCulture, parsed) AndAlso parsed > 0D Then Return parsed
        End If

        If stockQty > 0D Then Return stockQty
        Return stockQty - committedQty
    End Function

    Private Function LowStockThreshold(ByVal dataItem As Object) As Decimal
        Dim threshold As Decimal = Quantity(dataItem, "ScortaMinima")
        If threshold <= 0D Then threshold = DefaultLowStockThreshold
        Return threshold
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
