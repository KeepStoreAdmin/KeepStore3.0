Imports System
Imports System.Data
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web
Imports System.Web.UI.WebControls

Partial Class MiniCart
    Inherits System.Web.UI.UserControl

    ' 1 = prezzi + IVA (netto), 2 = prezzi IVA inclusa (ivato)
    Private _ivaTipo As Integer = 2
    Private _editableKeys As New HashSet(Of String)(StringComparer.Ordinal)

    ' Only the read-only cart snapshot endpoint uses this mode. Normal pages retain
    ' their progressive request IDs and existing native POST behavior.
    Public Property StatelessActionRequestIds As Boolean

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As EventArgs) Handles Me.PreRender
        BindMiniCartSafe()
        RenderClearCartAction()
    End Sub

    Private Sub BindMiniCartSafe()
        Try
            BindMiniCart()
        Catch
            ' Fail-safe: non bloccare mai il rendering dell'header
            Try
                lblMiniCartTotale.Text = "0,00"
                phMiniCartEmpty.Visible = True
                phMiniCartList.Visible = False
            Catch
            End Try
        End Try
    End Sub

    Private Sub BindMiniCart()
        Dim cart As CartAuthoritativeReadModel = CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)
        phMiniMoreItems.Visible = False
        _editableKeys.Clear()
        If Not cart.HasOwner Then
            phMiniCartEmpty.Visible = True
            phMiniCartList.Visible = False
            lblMiniCartTotale.Text = "0,00"
            Return
        End If
        _ivaTipo = GetIvaTipoSafe()

        Dim dt As DataTable = cart.GetMiniCartItems(10)
        Dim allItems As DataTable = cart.GetAllItems()
        _editableKeys = BuildEditableQuantityKeys(allItems)
        Dim qty As Decimal = cart.TotalQuantity
        Dim total As Decimal = If(_ivaTipo = 1, cart.TotalNet, cart.TotalGross)

        lblMiniCartTotale.Text = FormatCurrency(total)

        If qty <= 0 OrElse dt Is Nothing OrElse dt.Rows.Count = 0 Then
            phMiniCartEmpty.Visible = True
            phMiniCartList.Visible = False
            Return
        End If

        phMiniCartEmpty.Visible = False
        phMiniCartList.Visible = True
        Dim hiddenRows As Integer = HiddenRowCount(allItems.Rows.Count, dt.Rows.Count)
        phMiniMoreItems.Visible = hiddenRows > 0
        If hiddenRows > 0 Then
            litMiniMoreItems.Text = "Mostrate " & dt.Rows.Count.ToString(CultureInfo.InvariantCulture) &
                " di " & allItems.Rows.Count.ToString(CultureInfo.InvariantCulture) & " righe. Righe aggiuntive nel carrello completo: " &
                hiddenRows.ToString(CultureInfo.InvariantCulture) & "."
        End If

        rptMiniCart.DataSource = dt
        rptMiniCart.DataBind()
    End Sub

    ' ------------------------------------------------------------
    ' Binding helpers (usati nel markup)
    ' ------------------------------------------------------------
    Public Function BuildRemoveCartActionValue(ByVal rowIdObj As Object) As String
        Dim rowId As Integer = SafeInt(rowIdObj, 0)
        If rowId <= 0 Then Return String.Empty
        Dim payload As String = CartMutationIdempotencyService.BuildRemoveRowPayload(rowId)
        Dim requestId As String = If(StatelessActionRequestIds,
            CartMutationIdempotencyService.CreateRequestId(),
            CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
                HttpContext.Current, "cart-remove:mini:" & rowId.ToString(CultureInfo.InvariantCulture),
                "cart-remove-row", payload))
        Return HttpUtility.HtmlAttributeEncode(
            CartMutationIdempotencyService.BuildNativeRemoveRowActionValue(rowId, requestId))
    End Function

    Public Function BuildClearCartActionValue() As String
        Dim payload As String = CartMutationIdempotencyService.BuildClearCartPayload()
        Dim requestId As String = If(StatelessActionRequestIds,
            CartMutationIdempotencyService.CreateRequestId(),
            CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
                HttpContext.Current, "cart-clear:mini", "cart-clear", payload))
        Return HttpUtility.HtmlAttributeEncode(
            CartMutationIdempotencyService.BuildNativeClearCartActionValue(requestId))
    End Function

    Private Sub RenderClearCartAction()
        Dim value As String = BuildClearCartActionValue()
        litMiniClearCart.Text = "<button type=""submit"" form=""ksNativeCartForm"" name=""ksCartAction"" value=""" &
            value & """ class=""link small text-decoration-underline border-0 bg-transparent p-0"">Svuota</button>"
    End Sub

    Public Function GetProductUrl(ByVal articoliIdObj As Object, ByVal tcIdObj As Object) As String
        Dim id As Integer = SafeInt(articoliIdObj, 0)
        Dim tcText As String = SafeString(tcIdObj)

        If id <= 0 Then
            Return ResolveUrl("~/articoli.aspx")
        End If

        Dim url As String = "~/articolo.aspx?id=" & id.ToString()
        If Not String.IsNullOrWhiteSpace(tcText) Then
            url &= "&TCid=" & HttpUtility.UrlEncode(tcText)
        End If

        Return ResolveUrl(url)
    End Function

    Public Function GetProductImg(ByVal imgObj As Object) As String
        Return ThemeManager.ProductImageUrl(imgObj)
    End Function

    Public Function GetLineTotalText(ByVal importoObj As Object, ByVal importoIvatoObj As Object) As String
        Dim v As Decimal = If(_ivaTipo = 1, SafeDec(importoObj, 0D), SafeDec(importoIvatoObj, 0D))
        Return FormatCurrency(v)
    End Function

    Public Function GetUnitPriceText(ByVal prezzoObj As Object, ByVal prezzoIvatoObj As Object) As String
        Dim v As Decimal = If(_ivaTipo = 1, SafeDec(prezzoObj, 0D), SafeDec(prezzoIvatoObj, 0D))
        Return FormatCurrency(v)
    End Function

    Private Function FormatCurrency(ByVal amount As Decimal) As String
        Try
            Return UiPriceFormatter.FormatStorefrontAmount(amount)
        Catch
            Return amount.ToString("N2")
        End Try
    End Function

    ' ------------------------------------------------------------
    ' Safe helpers
    ' ------------------------------------------------------------
    Private Function GetIvaTipoSafe() As Integer
        Dim iva As Integer = 2
        Try
            Dim o As Object = Session("IvaTipo")
            If o IsNot Nothing AndAlso Integer.TryParse(o.ToString(), iva) Then
                If iva = 1 OrElse iva = 2 Then Return iva
            End If
        Catch
        End Try
        Return 2
    End Function

    Private Function SafeInt(ByVal o As Object, Optional ByVal defaultValue As Integer = 0) As Integer
        If o Is Nothing OrElse o Is DBNull.Value Then Return defaultValue
        Dim v As Integer
        If Integer.TryParse(o.ToString(), v) Then Return v
        Return defaultValue
    End Function

    Private Function SafeString(ByVal o As Object) As String
        If o Is Nothing OrElse o Is DBNull.Value Then Return String.Empty
        Return Convert.ToString(o, CultureInfo.InvariantCulture).Trim()
    End Function

    Private Function SafeDec(ByVal o As Object, Optional ByVal defaultValue As Decimal = 0D) As Decimal
        If o Is Nothing OrElse o Is DBNull.Value Then Return defaultValue

        Try
            If TypeOf o Is Decimal OrElse TypeOf o Is Double OrElse TypeOf o Is Single OrElse
               TypeOf o Is Integer OrElse TypeOf o Is Long OrElse TypeOf o Is Short Then
                Return Convert.ToDecimal(o, CultureInfo.InvariantCulture)
            End If
        Catch
        End Try

        Dim s As String = Convert.ToString(o)
        If String.IsNullOrWhiteSpace(s) Then Return defaultValue
        s = s.Trim()

        Dim d As Decimal
        Dim normalized As String = NormalizeDecimalString(s)
        If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then Return d

        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

        Return defaultValue
    End Function

    Private Function NormalizeDecimalString(ByVal value As String) As String
        Dim s As String = If(value, "").Trim()
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Replace(ChrW(8364), "")
        s = s.Replace("&euro;", "").Replace("&#8364;", "")
        s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
        s = s.Replace(ChrW(8722), "-")
        s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "")
        s = s.Replace(" ", "").Replace("'", "")

        Dim comma As Integer = s.LastIndexOf(","c)
        Dim dot As Integer = s.LastIndexOf("."c)

        If comma >= 0 AndAlso dot >= 0 Then
            If comma > dot Then
                s = s.Replace(".", "").Replace(","c, "."c)
            Else
                s = s.Replace(",", "")
            End If
        ElseIf dot >= 0 Then
            s = NormalizeSingleDecimalSeparator(s, "."c)
        ElseIf comma >= 0 Then
            s = NormalizeSingleDecimalSeparator(s, ","c)
        End If

        Return s
    End Function

    Private Function NormalizeSingleDecimalSeparator(ByVal value As String, ByVal separator As Char) As String
        Dim parts() As String = value.Split(separator)
        If parts.Length <= 1 Then Return value

        Dim last As String = parts(parts.Length - 1)

        If parts.Length > 2 Then
            If last.Length > 0 AndAlso last.Length <= 2 Then
                Return JoinAllButLast(parts) & "." & last
            End If

            Return String.Join("", parts)
        End If

        If last.Length = 3 Then Return parts(0) & last

        If separator = ","c Then Return parts(0) & "." & last

        Return value
    End Function

    Private Function JoinAllButLast(ByVal parts() As String) As String
        Dim output As String = ""
        For i As Integer = 0 To parts.Length - 2
            output &= parts(i)
        Next
        Return output
    End Function

    Public Shared Function HiddenRowCount(ByVal totalRows As Integer, ByVal shownRows As Integer) As Integer
        Return Math.Max(0, totalRows - Math.Max(0, shownRows))
    End Function

    Private Function QuantityKey(ByVal articleId As Integer, ByVal tcId As Integer) As String
        Return articleId.ToString(CultureInfo.InvariantCulture) & ":" & tcId.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function QuantityTCId(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return -1
        Dim parsed As Integer
        If Not Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) OrElse parsed < -1 Then Return Integer.MinValue
        Return If(parsed = 0, -1, parsed)
    End Function

    Private Function BuildEditableQuantityKeys(ByVal rows As DataTable) As HashSet(Of String)
        Dim counts As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
        Dim eligible As New HashSet(Of String)(StringComparer.Ordinal)
        If rows Is Nothing Then Return eligible
        For Each row As DataRow In rows.Rows
            Dim articleId As Integer = SafeInt(row("ArticoliId"))
            Dim tcId As Integer = QuantityTCId(row("TCId"))
            Dim key As String = QuantityKey(articleId, tcId)
            If Not counts.ContainsKey(key) Then counts(key) = 0
            counts(key) += 1
            Dim quantity As Decimal = SafeDec(row("Qnt"))
            If SafeInt(row("id")) > 0 AndAlso articleId > 0 AndAlso tcId <> Integer.MinValue AndAlso quantity >= 1D AndAlso quantity <= 9999D AndAlso
               Decimal.Truncate(quantity) = quantity AndAlso
               (SafeDec(row("Prezzo")) > 0D OrElse SafeDec(row("PrezzoIvato")) > 0D) Then eligible.Add(key)
        Next
        eligible.RemoveWhere(Function(key As String) counts(key) <> 1)
        Return eligible
    End Function

    Public Function RenderQuantityControl(ByVal dataItem As Object) As String
        Dim item As DataRowView = TryCast(dataItem, DataRowView)
        If item Is Nothing Then Return String.Empty
        Dim row As DataRow = item.Row
        Dim articleId As Integer = SafeInt(row("ArticoliId"))
        Dim tcId As Integer = QuantityTCId(row("TCId"))
        Dim quantity As String = SafeDec(row("Qnt")).ToString("0.########", CultureInfo.InvariantCulture)
        If Not _editableKeys.Contains(QuantityKey(articleId, tcId)) Then
            Return "<div class='ks-mini-quantity-readonly'>Quantità <strong>" & HttpUtility.HtmlEncode(quantity) &
                "</strong> · <a class='link js-ks-cart-context' data-ks-cart-full-link href='/carrello.aspx'>Gestisci nel carrello</a></div>"
        End If
        Dim rowId As Integer = SafeInt(row("id"))
        Dim field As String = "ksMiniQty_" & rowId.ToString(CultureInfo.InvariantCulture)
        Dim requestId As String = If(StatelessActionRequestIds, CartMutationIdempotencyService.CreateRequestId(),
            CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(HttpContext.Current,
                "cart-set:mini:" & rowId.ToString(CultureInfo.InvariantCulture), "cart-set",
                CartMutationIdempotencyService.BuildSetQuantityPayload(articleId, tcId, SafeDec(row("Qnt")))))
        Dim action As String = CartMutationIdempotencyService.BuildNativeSetActionValue(articleId, tcId, field, requestId)
        Dim label As String = HttpUtility.HtmlAttributeEncode("Quantità intera da 1 a 9999 di " & Convert.ToString(row("Descrizione1")))
        Return "<div class='ks-mini-quantity-editor' data-ks-mini-quantity data-ks-id='" & articleId.ToString(CultureInfo.InvariantCulture) &
            "' data-ks-tcid='" & tcId.ToString(CultureInfo.InvariantCulture) & "' data-ks-quantity='" & quantity & "'>" &
            "<label for='" & field & "'>Quantità</label><div class='ks-mini-quantity-fields'>" &
            "<textarea rows='1' inputmode='numeric' autocomplete='off' form='ksNativeCartForm' id='" & field &
            "' name='" & field & "' aria-label='" & label & "' data-ks-mini-quantity-input>" & quantity & "</textarea>" &
            "<button type='submit' form='ksNativeCartForm' name='ksCartAction' value='" & HttpUtility.HtmlAttributeEncode(action) &
            "' class='tf-btn btn-line ks-mini-quantity-update' data-ks-mini-update aria-label='" & HttpUtility.HtmlAttributeEncode("Aggiorna quantità di " & Convert.ToString(row("Descrizione1"))) &
            "'>Aggiorna</button></div></div>"
    End Function

End Class
