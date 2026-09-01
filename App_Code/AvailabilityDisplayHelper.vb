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
    Public Property StatusToneClass As String
    Public Property StatusStyle As String
    Public Property DotCssClass As String
    Public Property DotStyle As String
    Public Property IncomingTooltipText As String
    Public Property AvailableQtyText As String
    Public Property CommittedQtyText As String
    Public Property IncomingQtyText As String
    Public Property AvailableMetricClass As String
    Public Property IncomingMetricClass As String
    Public Property LegacyText As String
    Public Property Text As String
    Public Property Html As String
End Class

Public Module AvailabilityDisplayHelper
    Private Const DefaultDisplayMode As Integer = 1
    Private Const DefaultLowStockThreshold As Decimal = 2D
    Private Const DefaultIncomingTooltipText As String = "Il tempo di consegna indicativo e di 7 / 14 giorni lavorativi dalla data di inserimento dell'ordine. Le date di arrivo merce sono indicative: l'effettiva consegna presso i nostri magazzini potrebbe variare per cause esterne. Ti aggiorneremo in caso di variazioni."

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
        Dim stockQty As Decimal = Quantity(dataItem, "Giacenza")
        Dim committedQty As Decimal = Quantity(dataItem, "Impegnata")
        Dim incomingQty As Decimal = Quantity(dataItem, "InOrdine")
        Dim rawAvailableQty As Decimal = Quantity(dataItem, "Disponibilita")
        Dim model As AvailabilityDisplayModel = BuildFromValues(stockQty,
                                                                 rawAvailableQty,
                                                                 committedQty,
                                                                 incomingQty,
                                                                 LowStockThreshold(dataItem, ctx),
                                                                 ctx)
        model.LegacyText = BuildLegacyStatusText(dataItem, model.AvailableQty, model.IncomingQty)
        CompletePresentation(model)
        Return model
    End Function

    Public Function BuildFromValues(ByVal stockQty As Decimal,
                                    ByVal rawAvailableQty As Decimal,
                                    ByVal committedQty As Decimal,
                                    ByVal incomingQty As Decimal,
                                    ByVal lowStockThreshold As Decimal,
                                    Optional ByVal ctx As HttpContext = Nothing) As AvailabilityDisplayModel
        Dim model As New AvailabilityDisplayModel()
        model.DisplayMode = GetDisplayMode(ctx)
        model.StockQty = stockQty
        model.CommittedQty = committedQty
        model.IncomingQty = incomingQty
        model.AvailableQty = EffectiveAvailableQty(rawAvailableQty, stockQty, committedQty)
        model.LowStockThreshold = ResolveLowStockThreshold(lowStockThreshold, ctx)
        model.IncomingTooltipText = DefaultIncomingTooltipText

        ApplySyntheticStatus(model)
        model.LegacyText = If(model.AvailableQty > 0D,
                              "Disponibile",
                              If(model.IncomingQty > 0D, "In ordine", "Verifica disponibilita"))
        CompletePresentation(model)
        Return model
    End Function

    Private Sub CompletePresentation(ByVal model As AvailabilityDisplayModel)
        If model Is Nothing Then Return

        model.AvailableQtyText = FormatQuantity(model.AvailableQty)
        model.CommittedQtyText = FormatQuantity(model.CommittedQty)
        model.IncomingQtyText = FormatQuantity(model.IncomingQty)
        model.AvailableMetricClass = If(model.AvailableQty > 0D, "has-value", String.Empty)
        model.IncomingMetricClass = If(model.IncomingQty > 0D, "has-value", String.Empty)
        If model.DisplayMode = 2 Then
            model.Text = "Disponibilità: " & model.AvailableQtyText &
                         "; Impegnati: " & model.CommittedQtyText &
                         "; In Arrivo: " & model.IncomingQtyText &
                         "; " & model.StatusText
        Else
            model.Text = model.LegacyText
        End If

        model.Html = BuildHtml(model)
    End Sub

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
            sbSynthetic.Append("<span class=""ks-availability ks-availability--synthetic"" role=""status"" aria-label=""Disponibilita: ").Append(HtmlAttributeEncode(model.StatusText)).Append(""">")
            AppendStatus(sbSynthetic, model)
            sbSynthetic.Append("</span>")
            Return sbSynthetic.ToString()
        End If

        Dim sb As New StringBuilder()
        Dim ariaText As String = "Disponibili: " & model.AvailableQtyText & ". Impegnati: " & model.CommittedQtyText & ". In arrivo: " & model.IncomingQtyText & ". " & model.StatusText
        sb.Append("<span class=""ks-availability ks-availability--numeric"" role=""status"" aria-label=""").Append(HtmlAttributeEncode(ariaText)).Append(""">")
        sb.Append("<span class=""ks-availability__metrics"">")
        AppendMetric(sb, "Disponibili", model.AvailableQtyText, "is-available " & model.AvailableMetricClass)
        AppendMetric(sb, "Impegnati", model.CommittedQtyText, "is-committed")
        sb.Append("<span class=""ks-availability__metric is-incoming ").Append(model.IncomingMetricClass).Append("""><span class=""ks-availability__label"">In arrivo</span><strong class=""ks-availability__value"">").Append(HtmlEncode(model.IncomingQtyText)).Append("</strong>")
        If model.IncomingQty > 0D Then
            Dim tooltipText As String = HtmlEncode(model.IncomingTooltipText)
            sb.Append("<button type=""button"" class=""ks-availability__info"" title=""").Append(tooltipText).Append(""" aria-label=""Informazioni sugli articoli in arrivo: ").Append(tooltipText).Append("""><span aria-hidden=""true"">i</span></button>")
        End If
        sb.Append("</span></span>")
        AppendStatus(sb, model)
        sb.Append("</span>")
        Return sb.ToString()
    End Function

    Private Sub AppendMetric(ByVal sb As StringBuilder, ByVal label As String, ByVal value As String, ByVal modifier As String)
        sb.Append("<span class=""ks-availability__metric ").Append(modifier).Append("""><span class=""ks-availability__label"">").Append(HtmlEncode(label)).Append("</span><strong class=""ks-availability__value"">").Append(HtmlEncode(value)).Append("</strong></span>")
    End Sub

    Private Sub AppendStatus(ByVal sb As StringBuilder, ByVal model As AvailabilityDisplayModel)
        sb.Append("<span class=""ks-availability__status ").Append(model.StatusToneClass).Append("""><span class=""ks-availability__dot"" aria-hidden=""true""></span><span class=""ks-availability__status-text"">").Append(HtmlEncode(model.StatusText)).Append("</span></span>")
    End Sub

    Private Sub ApplySyntheticStatus(ByVal model As AvailabilityDisplayModel)
        If model Is Nothing Then Return

        If model.AvailableQty > 0D Then
            If model.AvailableQty <= model.LowStockThreshold Then
                ApplyStatus(model, "Pochi pezzi", "ks-availability-status-low", "ks-availability-dot-low", "is-low", "#b45309")
            Else
                ApplyStatus(model, "Disponibile", "ks-availability-status-ok", "ks-availability-dot-ok", "is-ok", "#15803d")
            End If
        ElseIf model.IncomingQty > 0D Then
            ApplyStatus(model, "In arrivo", "ks-availability-status-low", "ks-availability-dot-low", "is-incoming", "#b45309")
        Else
            ApplyStatus(model, "Non disponibile", "ks-availability-status-ko", "ks-availability-dot-ko", "is-unavailable", "#b42318")
        End If

        model.IsAvailable = (model.AvailableQty > 0D)
    End Sub

    Private Sub ApplyStatus(ByVal model As AvailabilityDisplayModel, ByVal text As String, ByVal statusCssClass As String, ByVal dotCssClass As String, ByVal toneClass As String, ByVal color As String)
        model.StatusText = text
        model.StatusCssClass = statusCssClass
        model.StatusToneClass = toneClass
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

    Private Function EffectiveAvailableQty(ByVal rawAvailableQty As Decimal, ByVal stockQty As Decimal, ByVal committedQty As Decimal) As Decimal
        If rawAvailableQty > 0D Then Return rawAvailableQty
        If stockQty > 0D Then Return stockQty
        Return stockQty - committedQty
    End Function

    Private Function LowStockThreshold(ByVal dataItem As Object, ByVal ctx As HttpContext) As Decimal
        Dim threshold As Decimal = Quantity(dataItem, "ScortaMinima")
        Return ResolveLowStockThreshold(threshold, ctx)
    End Function

    Private Function ResolveLowStockThreshold(ByVal threshold As Decimal, ByVal ctx As HttpContext) As Decimal
        If threshold > 0D Then Return threshold

        Try
            If ctx Is Nothing Then ctx = HttpContext.Current
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing Then
                Dim raw As Object = ctx.Session("DispoMinima")
                If raw IsNot Nothing AndAlso Not Convert.IsDBNull(raw) Then
                    Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.CurrentCulture, threshold)
                    If threshold <= 0D Then Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.InvariantCulture, threshold)
                End If
            End If
        Catch
            threshold = 0D
        End Try

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

    Private Function HtmlAttributeEncode(ByVal value As String) As String
        Return HttpUtility.HtmlAttributeEncode(If(value, String.Empty))
    End Function
End Module
