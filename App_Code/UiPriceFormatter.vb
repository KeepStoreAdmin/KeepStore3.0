Option Explicit On
Option Strict Off

Imports System
Imports System.Globalization
Imports System.Web

' ============================================================
' UI Price Formatter (centralizzato)
' - WebForms Web Site (App_Code)
' - Nessuna dipendenza DB
' - Rende HTML prezzo coerente con il tema
' ============================================================
Public Module UiPriceFormatter
    Private ReadOnly PriceCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    ' Versione base (5 parametri) - compatibilità
    Public Function RenderPriceHtml(ByVal prezzo As Object,
                                              ByVal prezzoIvato As Object,
                                              ByVal prezzoPromo As Object,
                                              ByVal prezzoPromoIvato As Object,
                                              ByVal ivaTipo As Object) As String
        Return RenderPriceHtmlInternal(prezzo, prezzoIvato, prezzoPromo, prezzoPromoIvato, Nothing, ivaTipo)
    End Function

    ' Versione estesa (6 parametri) - per liste che passano anche InOfferta
    Public Function RenderPriceHtml(ByVal prezzo As Object,
                                              ByVal prezzoIvato As Object,
                                              ByVal prezzoPromo As Object,
                                              ByVal prezzoPromoIvato As Object,
                                              ByVal inOfferta As Object,
                                              ByVal ivaTipo As Object) As String
        Return RenderPriceHtmlInternal(prezzo, prezzoIvato, prezzoPromo, prezzoPromoIvato, inOfferta, ivaTipo)
    End Function

    ' ============================================================
    ' Internals
    ' ============================================================
    Private Function RenderPriceHtmlInternal(ByVal prezzo As Object,
                                             ByVal prezzoIvato As Object,
                                             ByVal prezzoPromo As Object,
                                             ByVal prezzoPromoIvato As Object,
                                             ByVal inOfferta As Object,
                                             ByVal ivaTipo As Object) As String

        Dim pNet As Decimal = ToDec(prezzo)
        Dim pIva As Decimal = ToDec(prezzoIvato)
        Dim promoNet As Decimal = ToDec(prezzoPromo)
        Dim promoIva As Decimal = ToDec(prezzoPromoIvato)

        Dim ivaMode As Integer = ToInt(ivaTipo) ' 1 = IVA esclusa (storico KeepStore)
        Dim promoFlag As Integer = ToInt(inOfferta)

        Dim baseValue As Decimal = If(ivaMode = 1, pNet, pIva)
        If baseValue <= 0D Then baseValue = FirstPositive(If(ivaMode = 1, pIva, pNet), pIva, pNet)

        Dim promoValue As Decimal = If(ivaMode = 1, promoNet, promoIva)
        If promoValue <= 0D Then promoValue = FirstPositive(If(ivaMode = 1, promoIva, promoNet), promoIva, promoNet)

        Dim isPromo As Boolean
        If inOfferta Is Nothing Then
            isPromo = (promoValue > 0D AndAlso baseValue > 0D AndAlso promoValue < baseValue)
        Else
            isPromo = (promoFlag <> 0 AndAlso promoValue > 0D AndAlso baseValue > 0D AndAlso promoValue < baseValue)
        End If

        If baseValue <= 0D AndAlso (Not isPromo OrElse promoValue <= 0D) Then
            Return "<span class=""ks-price-ask"">Prezzo su richiesta</span>"
        End If

        If isPromo Then
            Dim oldHtml As String = If(baseValue > 0D, "<del class=""ks-price-old"">" & FormatPrice(baseValue) & "</del>", "")
            Dim promoHtml As String = "<ins class=""ks-price-now"">" & FormatPrice(promoValue) & "</ins>"
            Dim ivaSuffix As String = If(ivaMode = 1, "<span class=""ks-price-iva""> + IVA</span>", "")

            Return "<span class=""ks-price"">" & promoHtml & oldHtml & ivaSuffix & "</span>"
        Else
            Dim priceHtml As String = "<span class=""ks-price-now"">" & FormatPrice(baseValue) & "</span>"
            Dim ivaSuffix As String = If(ivaMode = 1, "<span class=""ks-price-iva""> + IVA</span>", "")

            Return "<span class=""ks-price"">" & priceHtml & ivaSuffix & "</span>"
        End If

    End Function

    Public Function RenderPriceText(ByVal prezzo As Object,
                                    ByVal prezzoIvato As Object,
                                    ByVal prezzoPromo As Object,
                                    ByVal prezzoPromoIvato As Object,
                                    ByVal inOfferta As Object,
                                    ByVal ivaTipo As Object) As String
        Dim pNet As Decimal = ToDec(prezzo)
        Dim pIva As Decimal = ToDec(prezzoIvato)
        Dim promoNet As Decimal = ToDec(prezzoPromo)
        Dim promoIva As Decimal = ToDec(prezzoPromoIvato)

        Dim ivaMode As Integer = ToInt(ivaTipo)
        Dim promoFlag As Integer = ToInt(inOfferta)
        Dim baseValue As Decimal = If(ivaMode = 1, pNet, pIva)
        If baseValue <= 0D Then baseValue = FirstPositive(If(ivaMode = 1, pIva, pNet), pIva, pNet)

        Dim promoValue As Decimal = If(ivaMode = 1, promoNet, promoIva)
        If promoValue <= 0D Then promoValue = FirstPositive(If(ivaMode = 1, promoIva, promoNet), promoIva, promoNet)

        If promoFlag <> 0 AndAlso promoValue > 0D AndAlso baseValue > 0D AndAlso promoValue < baseValue Then
            Return FormatPrice(promoValue)
        End If

        If baseValue > 0D Then Return FormatPrice(baseValue)
        Return "Prezzo su richiesta"
    End Function

    Private Function ToDec(ByVal v As Object) As Decimal
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return 0D

        Try
            If TypeOf v Is Decimal OrElse TypeOf v Is Double OrElse TypeOf v Is Single OrElse
               TypeOf v Is Integer OrElse TypeOf v Is Long OrElse TypeOf v Is Short Then
                Return Convert.ToDecimal(v, CultureInfo.InvariantCulture)
            End If
        Catch
        End Try

        Dim s As String = Convert.ToString(v)
        If String.IsNullOrWhiteSpace(s) Then Return 0D
        s = s.Trim()

        Dim d As Decimal
        Dim normalized As String = NormalizeDecimalString(s)
        If Decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, PriceCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

        Return 0D
    End Function

    Private Function FirstPositive(ParamArray values() As Decimal) As Decimal
        For Each value As Decimal In values
            If value > 0D Then Return value
        Next
        Return 0D
    End Function

    Private Function FormatPrice(ByVal value As Decimal) As String
        Return value.ToString("N2", PriceCulture) & " " & ChrW(8364)
    End Function

    Private Function NormalizeDecimalString(ByVal value As String) As String
        Dim s As String = StripMoneyText(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Trim().Replace("€", "").Replace(" ", "")
        Dim comma As Integer = s.LastIndexOf(","c)
        Dim dot As Integer = s.LastIndexOf("."c)

        If comma >= 0 AndAlso dot >= 0 Then
            If comma > dot Then
                s = s.Replace(".", "").Replace(","c, "."c)
            Else
                s = s.Replace(",", "")
            End If
        ElseIf dot >= 0 Then
            s = NormalizeSingleSeparator(s, "."c)
        ElseIf comma >= 0 Then
            s = NormalizeSingleSeparator(s, ","c)
        End If

        Return s
    End Function

    Private Function StripMoneyText(ByVal value As String) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Trim()
        s = s.Replace(ChrW(8364), "")
        s = s.Replace(ChrW(226) & ChrW(8218) & ChrW(172), "")
        s = s.Replace("&euro;", "").Replace("&#8364;", "")
        s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
        s = s.Replace(ChrW(8722), "-")
        s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "")
        s = s.Replace(" ", "").Replace("'", "")

        Return s
    End Function

    Private Function NormalizeSingleSeparator(ByVal value As String, ByVal separator As Char) As String
        Dim parts() As String = value.Split(separator)
        If parts.Length <= 1 Then Return value

        Dim last As String = parts(parts.Length - 1)

        If parts.Length > 2 Then
            If last.Length > 0 AndAlso last.Length <= 2 Then
                Return JoinAllButLast(parts) & "." & last
            End If

            Return String.Join("", parts)
        End If

        If last.Length = 3 Then
            Return parts(0) & last
        End If

        If separator = ","c Then
            Return parts(0) & "." & last
        End If

        Return value
    End Function

    Private Function JoinAllButLast(ByVal parts() As String) As String
        Dim output As String = ""
        For i As Integer = 0 To parts.Length - 2
            output &= parts(i)
        Next
        Return output
    End Function

    Private Function ToInt(ByVal v As Object) As Integer
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return 0

        Try
            Return Convert.ToInt32(v, CultureInfo.InvariantCulture)
        Catch
        End Try

        Dim s As String = Convert.ToString(v)
        Dim i As Integer
        If Integer.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, i) Then Return i
        If Integer.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, i) Then Return i

        Return 0
    End Function

End Module
