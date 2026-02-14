
Partial Class coupon_stampa
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Seleziono il coupon da visualizzare
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon WHERE (coupon_tabella_temporanea.idCoupon=" & Request.QueryString("id") & ") AND (cod_controllo='" & Request.QueryString("cod") & "') AND (StatoPagamento=1)"
    End Sub
End Class
