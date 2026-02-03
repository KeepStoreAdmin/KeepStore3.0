<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" %>

<script runat="server">
    ' ============================================================
    ' Alias page (hardening):
    ' - Alcuni link puntano a /pay_your_orders.aspx
    ' - In KeepStore il pagamento ordini è gestito da /documenti.aspx?t=4
    ' - Questa pagina esegue SOLO un redirect server-side, con noindex + no-store
    ' ============================================================
    Protected Overrides Sub OnLoad(ByVal e As EventArgs)
        ' Hardening: no-store / no-cache (anche per response di redirect)
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.Cache.SetRevalidation(System.Web.HttpCacheRevalidation.AllCaches)
        Response.Cache.SetExpires(System.DateTime.UtcNow.AddMinutes(-1))
        Response.Cache.SetMaxAge(System.TimeSpan.Zero)
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
    <meta name="robots" content="noindex, nofollow" />
    <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
</asp:Content>

<asp:Content ID="cntMain" ContentPlaceHolderID="MainContent" runat="server">
</asp:Content>
