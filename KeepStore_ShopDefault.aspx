<%@ Page Language="VB" AutoEventWireup="false" %>
<%--
    DEPRECATO / COMPATIBILITÀ
    Questa pagina era una copia/bozza del template Onsus "shop-default".

    Il catalogo reale del sito è: articoli.aspx
    Ora questo file è un alias verso articoli.aspx per evitare pagine duplicate.
    Puoi anche ELIMINARLO dal progetto se non ci sono link esterni che lo richiamano.
--%>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim qs As String = If(Request.Url IsNot Nothing, Request.Url.Query, "")
        Server.Transfer("~/articoli.aspx" & qs, True)
    End Sub
</script>
