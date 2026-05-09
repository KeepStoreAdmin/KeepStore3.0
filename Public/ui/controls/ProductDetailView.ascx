<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductDetailView.ascx.vb" Inherits="Public_ui_controls_ProductDetailView" %>

<div class="alert alert-info mb-4" role="note">
    <p class="mb-2"><strong>Preview nuova scheda prodotto attiva solo in locale</strong></p>

    <asp:PlaceHolder ID="phMainImage" runat="server" Visible="false">
        <p class="mb-2">
            <asp:Image ID="imgMain" runat="server" />
        </p>
    </asp:PlaceHolder>

    <p class="mb-1">Prodotto: <asp:Literal ID="litProductName" runat="server" /></p>
    <p class="mb-1">Codice: <asp:Literal ID="litProductCode" runat="server" /></p>
    <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
        <p class="mb-1">Marca: <asp:Literal ID="litBrandName" runat="server" /></p>
    </asp:PlaceHolder>
    <asp:PlaceHolder ID="phCategory" runat="server" Visible="false">
        <p class="mb-1">Categoria: <asp:Literal ID="litCategoryName" runat="server" /></p>
    </asp:PlaceHolder>
    <p class="mb-1">Prezzo: <asp:Literal ID="litPrice" runat="server" /></p>
    <asp:PlaceHolder ID="phOldPrice" runat="server" Visible="false">
        <p class="mb-1">Prezzo precedente: <asp:Literal ID="litOldPrice" runat="server" /></p>
    </asp:PlaceHolder>
    <asp:PlaceHolder ID="phPromo" runat="server" Visible="false">
        <p class="mb-1">Promo: <asp:Literal ID="litPromo" runat="server" /></p>
    </asp:PlaceHolder>
    <asp:PlaceHolder ID="phIva" runat="server" Visible="false">
        <p class="mb-1">IVA: <asp:Literal ID="litIvaLabel" runat="server" /></p>
    </asp:PlaceHolder>
    <p class="mb-1">Disponibilita: <asp:Literal ID="litAvailability" runat="server" /></p>
    <asp:PlaceHolder ID="phRefurbished" runat="server" Visible="false">
        <p class="mb-1">Ricondizionato: <asp:Literal ID="litRefurbished" runat="server" /></p>
    </asp:PlaceHolder>
    <p class="mb-1">Varianti: <asp:Literal ID="litVariants" runat="server" /></p>
    <p class="mb-1">Add-to-cart: <asp:Literal ID="litAddToCartStatus" runat="server" /></p>
    <asp:PlaceHolder ID="phProductUrl" runat="server" Visible="false">
        <p class="mb-1">Link prodotto: <asp:Literal ID="litProductUrl" runat="server" /></p>
    </asp:PlaceHolder>
    <p class="mb-1">TCId: <asp:Literal ID="litTCId" runat="server" /></p>
    <div class="mb-0"><asp:Literal ID="litShortDescription" runat="server" /></div>
</div>
