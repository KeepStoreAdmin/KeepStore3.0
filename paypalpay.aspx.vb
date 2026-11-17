Imports System
Imports System.Web

' PAYPAL-PAY-FIRST-PAGES-1A (P3a1): avvio del pagamento PayPal PRIMA che esista l'ordine. Raggiungibile solo con un contesto di sessione emesso da ordine.aspx
' (P3a2) per la stessa bozza e lo stesso proprietario; senza contesto torna al carrello. Nessuna regola qui: PayPalPayFirstGlue/PayPalPayFirstService.
Partial Class paypalpay
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If IsPostBack Then Return
        PayPalPayFirstGlue.RunStart(HttpContext.Current, Convert.ToString(Request.QueryString("r")))
    End Sub
End Class
