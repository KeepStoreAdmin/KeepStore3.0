<%@ Page Language="VB" AutoEventWireup="false" %>
<%--
    DEPRECATO / COMPATIBILITÀ
    Questa pagina era una demo del template Onsus (home1) e non deve più essere usata nel progetto.

    Ora funge solo da alias verso Default.aspx per evitare confusione e pagine duplicate.
    Puoi anche ELIMINARLA dal progetto se non ci sono link esterni che la richiamano.
--%>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim qs As String = If(Request.Url IsNot Nothing, Request.Url.Query, "")
        Server.Transfer("~/Default.aspx" & qs, True)
    End Sub
</script>
