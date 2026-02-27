Imports System
Imports System.Globalization

' Centralizzazione rendering prezzo (solo HTML). Nessun accesso DB.
' Usare da databinding: <%# UiPriceFormatter.RenderPriceHtml(...) %>
Public Module UiPriceFormatter

    Public Function RenderPriceHtml(ByVal prezzo As Object,
                                    ByVal prezzoIvato As Object,
                                    ByVal prezzoPromo As Object,
                                    ByVal prezzoPromoIvato As Object,
                                    ByVal ivaTipo As Object) As String

        Dim useIvato As Boolean = True
        Try
            ' Convenzione KeepStore: 1 = IVA esclusa, altrimenti IVA inclusa
            useIvato = (Convert.ToInt32(ivaTipo) <> 1)
        Catch
            useIvato = True
        End Try

        Dim pBase As Decimal = ToDecimal(prezzo)
        Dim pIvato As Decimal = ToDecimal(prezzoIvato)
        Dim pPromoBase As Decimal = ToDecimal(prezzoPromo)
        Dim pPromoIvato As Decimal = ToDecimal(prezzoPromoIvato)

        Dim basePrice As Decimal = If(useIvato, pIvato, pBase)
        Dim promoPrice As Decimal = If(useIvato, pPromoIvato, pPromoBase)

        Dim hasPromo As Boolean = (promoPrice > 0D AndAlso basePrice > 0D AndAlso promoPrice < basePrice)

        ' Se il prezzo è 0, non stampiamo importi non significativi.
        If basePrice <= 0D AndAlso promoPrice <= 0D Then
            Return "<span class=""price text-muted"">Prezzo su richiesta</span>"
        End If

        Dim ivaSuffix As String = If(useIvato,
                                     String.Empty,
                                     "<span class=""ks-price-iva text-muted ms-1"">+ IVA</span>")

        If hasPromo Then
            Return "<span class=""price text-primary"">" & FormatMoney(promoPrice) & "</span>" &
                   "<span class=""old-price text-muted text-decoration-line-through ms-2"">" & FormatMoney(basePrice) & "</span>" &
                   ivaSuffix
        End If

        Return "<span class=""price"">" & FormatMoney(basePrice) & "</span>" & ivaSuffix
    End Function

    Private Function ToDecimal(ByVal value As Object) As Decimal
        If value Is Nothing OrElse Convert.IsDBNull(value) Then
            Return 0D
        End If

        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then
            Return 0D
        End If

        Dim d As Decimal
        ' Prova con cultura corrente
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, d) Then
            Return d
        End If
        ' Fallback invariant (es. valori con punto)
        If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        Try
            Return Convert.ToDecimal(value)
        Catch
            Return 0D
        End Try
    End Function

    Private Function FormatMoney(ByVal amount As Decimal) As String
        Return amount.ToString("C", CultureInfo.CurrentCulture)
    End Function

End Module
