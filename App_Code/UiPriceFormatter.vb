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

    ' Versione base (5 parametri) - compatibilità
    Public Overloads Function RenderPriceHtml(ByVal prezzo As Object,
                                              ByVal prezzoIvato As Object,
                                              ByVal prezzoPromo As Object,
                                              ByVal prezzoPromoIvato As Object,
                                              ByVal ivaTipo As Object) As String
        Return RenderPriceHtmlInternal(prezzo, prezzoIvato, prezzoPromo, prezzoPromoIvato, Nothing, ivaTipo)
    End Function

    ' Versione estesa (6 parametri) - per liste che passano anche InOfferta
    Public Overloads Function RenderPriceHtml(ByVal prezzo As Object,
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
        Dim promoValue As Decimal = If(ivaMode = 1, promoNet, promoIva)

        Dim isPromo As Boolean
        If inOfferta Is Nothing Then
            isPromo = (promoValue > 0D)
        Else
            isPromo = (promoFlag <> 0 AndAlso promoValue > 0D)
        End If

        If baseValue <= 0D AndAlso (Not isPromo OrElse promoValue <= 0D) Then
            Return "<span class=""ks-price-ask"">Prezzo su richiesta</span>"
        End If

        Dim cur As CultureInfo = CultureInfo.CurrentCulture

        If isPromo Then
            Dim oldHtml As String = If(baseValue > 0D, "<del class=""ks-price-old"">" & String.Format(cur, "{0:C}", baseValue) & "</del>", "")
            Dim promoHtml As String = "<ins class=""ks-price-now"">" & String.Format(cur, "{0:C}", promoValue) & "</ins>"
            Dim ivaSuffix As String = If(ivaMode = 1, "<span class=""ks-price-iva""> + IVA</span>", "")

            Return "<span class=""ks-price"">" & promoHtml & oldHtml & ivaSuffix & "</span>"
        Else
            Dim priceHtml As String = "<span class=""ks-price-now"">" & String.Format(cur, "{0:C}", baseValue) & "</span>"
            Dim ivaSuffix As String = If(ivaMode = 1, "<span class=""ks-price-iva""> + IVA</span>", "")

            Return "<span class=""ks-price"">" & priceHtml & ivaSuffix & "</span>"
        End If

    End Function

    Private Function ToDec(ByVal v As Object) As Decimal
        If v Is Nothing OrElse Convert.IsDBNull(v) Then Return 0D

        Try
            ' Prova conversione diretta
            Return Convert.ToDecimal(v, CultureInfo.CurrentCulture)
        Catch
        End Try

        Dim s As String = Convert.ToString(v)
        If String.IsNullOrWhiteSpace(s) Then Return 0D

        Dim d As Decimal
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, d) Then Return d
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

        Return 0D
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
