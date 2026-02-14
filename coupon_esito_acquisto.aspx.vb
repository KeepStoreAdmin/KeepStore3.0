
Partial Class coupon_esito_acquisto
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        'Seleziono il coupon da visualizzare
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon WHERE (coupon_tabella_temporanea.idCoupon=" & Request.QueryString("id") & ") AND (cod_controllo='" & Request.QueryString("cod") & "')"
    End Sub
End Class
