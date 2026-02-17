<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false"  CodeFile="pay_your_orders.aspx.vb" Inherits="pay_your_orders" %>
<%@ OutputCache Location="None" NoStore="true" Duration="0" VaryByParam="None" %>
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
