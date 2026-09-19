Imports System
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports System.Web.UI.WebControls

Partial Class MiniCart
    Inherits System.Web.UI.UserControl

    ' 1 = prezzi + IVA (netto), 2 = prezzi IVA inclusa (ivato)
    Private _ivaTipo As Integer = 2

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
        If Not cart.HasOwner Then
            phMiniCartEmpty.Visible = True
            phMiniCartList.Visible = False
            lblMiniCartTotale.Text = "0,00"
            Return
        End If
        _ivaTipo = GetIvaTipoSafe()

        Dim dt As DataTable = cart.GetMiniCartItems(10)
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
        Dim requestId As String = CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
            HttpContext.Current, "cart-remove:mini:" & rowId.ToString(CultureInfo.InvariantCulture),
            "cart-remove-row", payload)
        Return HttpUtility.HtmlAttributeEncode(
            CartMutationIdempotencyService.BuildNativeRemoveRowActionValue(rowId, requestId))
    End Function

    Public Function BuildClearCartActionValue() As String
        Dim payload As String = CartMutationIdempotencyService.BuildClearCartPayload()
        Dim requestId As String = CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
            HttpContext.Current, "cart-clear:mini", "cart-clear", payload)
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
            Return amount.ToString("N2", CultureInfo.GetCultureInfo("it-IT")) & " " & ChrW(8364)
        Catch
            Return amount.ToString("N2") & " " & ChrW(8364)
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

End Class
