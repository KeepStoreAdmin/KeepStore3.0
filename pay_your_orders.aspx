<%@ Page Language="VB" AutoEventWireup="false" %>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs)
        ' Alias page: in alcune versioni del template/account esisteva "pay_your_orders.aspx".
        ' Nel progetto KeepStore 3.0 la funzione di pagamento ordini è gestita dalla pagina documenti.aspx (Ordini: t=4).
        Response.Redirect("/documenti.aspx?t=4", True)
    End Sub
</script>
