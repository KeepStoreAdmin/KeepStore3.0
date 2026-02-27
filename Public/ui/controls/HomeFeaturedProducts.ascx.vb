Partial Class HomeFeaturedProducts
    Inherits System.Web.UI.UserControl

    ' Wrapper per compatibilità con vecchi databinding: centralizzato in App_Code.
    Protected Function controlla_prezzo(ByVal prezzo As Object,
                                       ByVal prezzoIvato As Object,
                                       ByVal prezzoPromo As Object,
                                       ByVal prezzoPromoIvato As Object,
                                       ByVal ivaTipo As Object) As String
        Return UiPriceFormatter.RenderPriceHtml(prezzo, prezzoIvato, prezzoPromo, prezzoPromoIvato, ivaTipo)
    End Function
End Class
