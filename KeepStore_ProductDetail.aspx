<%@ Page Language="VB" AutoEventWireup="false" %>
<%--
    DEPRECATO / COMPATIBILITÀ
    Questa pagina era una bozza del template Onsus "product-detail".

    La pagina prodotto reale del sito è: articolo.aspx
    Ora questo file è un alias verso articolo.aspx per evitare pagine duplicate.
    Puoi anche ELIMINARLO dal progetto se non ci sono link esterni che lo richiamano.
--%>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim qs As String = If(Request.Url IsNot Nothing, Request.Url.Query, "")
        Server.Transfer("~/articolo.aspx" & qs, True)
    End Sub
</script>
