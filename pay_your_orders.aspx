<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" %>
<%@ OutputCache Location="None" NoStore="true" Duration="0" VaryByParam="None" %>

<script runat="server">
    ' ============================================================
    ' Alias page (hardening):
    ' - Alcuni template/account puntano a /pay_your_orders.aspx
    ' - In KeepStore il pagamento ordini è gestito da /documenti.aspx?t=4
    ' - Questa pagina esegue solo redirect server-side, con noindex + no-store
    ' ============================================================
    Protected Overrides Sub OnLoad(ByVal e As EventArgs)
        ' Hardening: no-store / no-cache
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))
        Response.Cache.SetMaxAge(TimeSpan.Zero)
        Response.Cache.AppendCacheExtension("must-revalidate, proxy-revalidate")

        ' Hardening: noindex
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow")

        ' Redirect (alias) -> pagina corretta
        Response.Redirect("/documenti.aspx?t=4", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
</script>

<asp:Content ID="cntTitle" ContentPlaceHolderID="TitleContent" runat="server">
    Pagamenti
</asp:Content>

<asp:Content ID="cntHead" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- In caso di body (client/edge che mostra contenuto di una 302), mantieni noindex + no-store anche in markup -->
    <meta name="robots" content="noindex, nofollow" />
    <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
</asp:Content>

<asp:Content ID="cntMain" ContentPlaceHolderID="MainContent" runat="server">
</asp:Content>

<!-- Legacy placeholders (presenti in Page.master) -->
<asp:Content ID="cntLegacy1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
</asp:Content>
<asp:Content ID="cntLegacy2" ContentPlaceHolderID="cph" runat="server">
</asp:Content>
