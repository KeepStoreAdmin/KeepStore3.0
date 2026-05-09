<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductDetailView.ascx.vb" Inherits="Public_ui_controls_ProductDetailView" %>

<div class="alert alert-info mb-4" role="note">
    <p class="mb-1"><strong>Preview nuova scheda prodotto attiva solo in locale</strong></p>
    <p class="mb-1">Prodotto: <asp:Literal ID="litProductName" runat="server" /></p>
    <p class="mb-1">Codice: <asp:Literal ID="litProductCode" runat="server" /></p>
    <p class="mb-1">Prezzo: <asp:Literal ID="litPrice" runat="server" /></p>
    <p class="mb-1">Disponibilita: <asp:Literal ID="litAvailability" runat="server" /></p>
    <p class="mb-1">TCId: <asp:Literal ID="litTCId" runat="server" /></p>
    <div class="mb-0"><asp:Literal ID="litShortDescription" runat="server" /></div>
</div>
