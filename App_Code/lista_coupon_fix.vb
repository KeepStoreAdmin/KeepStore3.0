Option Strict On

Imports System.Web.UI.WebControls

' Fix compilazione: in lista_coupon.aspx.vb viene usato sdsDocumenti,
' ma nel markup esiste (ed è usato altrove nello stesso file) SqlDataCoupon.
' Questa property fa da alias verso SqlDataCoupon, senza alterare la logica della pagina.
Partial Class lista_coupon

    Protected ReadOnly Property sdsDocumenti As SqlDataSource
        Get
            ' SqlDataCoupon deve essere definito nel markup (.aspx)
            Return SqlDataCoupon
        End Get
    End Property

End Class
