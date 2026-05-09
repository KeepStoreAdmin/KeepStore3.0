<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductDetailView.ascx.vb" Inherits="Public_ui_controls_ProductDetailView" %>

<div class="alert alert-info mb-4" role="note">
    <p class="mb-2"><strong>Preview nuova scheda prodotto attiva solo in locale</strong></p>

    <asp:PlaceHolder ID="phMainImage" runat="server" Visible="false">
        <p class="mb-2">
            <asp:Image ID="imgMain" runat="server" />
        </p>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phDemoGallery" runat="server" Visible="false">
        <p class="mb-1">Gallery demo statica:</p>
        <div>
            <asp:Repeater ID="rptDemoGalleryImages" runat="server">
                <ItemTemplate>
                    <span class="d-inline-block me-2 mb-2">
                        <asp:Image ID="imgDemoGalleryThumb" runat="server" ImageUrl='<%# Container.DataItem %>' AlternateText="Miniatura prodotto" Width="72" Height="72" />
                    </span>
                </ItemTemplate>
            </asp:Repeater>
        </div>
    </asp:PlaceHolder>

    <p class="mb-1">Prodotto: <asp:Literal ID="litProductName" runat="server" /></p>
    <p class="mb-1">Codice: <asp:Literal ID="litProductCode" runat="server" /></p>
    <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
        <p class="mb-1">EAN: <asp:Literal ID="litEan" runat="server" /></p>
    </asp:PlaceHolder>
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
    <div>
        <p class="mb-1"><strong>Mini buy-box demo</strong></p>
        <p class="mb-1">Quantita demo: <asp:Literal ID="litQuantity" runat="server" /></p>
        <p class="mb-1">Varianti: <asp:Literal ID="litVariants" runat="server" /></p>
        <p class="mb-1">Add-to-cart: <asp:Literal ID="litAddToCartStatus" runat="server" /></p>
        <p class="mb-1">Il carrello reale resta gestito dalla scheda originale sotto la preview.</p>
    </div>
    <asp:PlaceHolder ID="phProductUrl" runat="server" Visible="false">
        <p class="mb-1">Link prodotto: <asp:Literal ID="litProductUrl" runat="server" /></p>
    </asp:PlaceHolder>
    <p class="mb-1">TCId: <asp:Literal ID="litTCId" runat="server" /></p>

    <div>
        <p class="mb-1"><strong>Descrizione demo</strong></p>
        <asp:PlaceHolder ID="phShortDescription" runat="server" Visible="false">
            <div class="mb-1"><asp:Literal ID="litShortDescription" runat="server" /></div>
        </asp:PlaceHolder>
        <asp:PlaceHolder ID="phLongDescription" runat="server" Visible="false">
            <div class="mb-1"><asp:Literal ID="litLongDescription" runat="server" /></div>
        </asp:PlaceHolder>
    </div>

    <div>
        <p class="mb-1"><strong>Informazioni prodotto demo</strong></p>
        <p class="mb-1">Codice: <asp:Literal ID="litInfoProductCode" runat="server" /></p>
        <asp:PlaceHolder ID="phInfoEan" runat="server" Visible="false">
            <p class="mb-1">EAN: <asp:Literal ID="litInfoEan" runat="server" /></p>
        </asp:PlaceHolder>
        <asp:PlaceHolder ID="phInfoBrand" runat="server" Visible="false">
            <p class="mb-1">Marca: <asp:Literal ID="litInfoBrandName" runat="server" /></p>
        </asp:PlaceHolder>
        <asp:PlaceHolder ID="phInfoCategory" runat="server" Visible="false">
            <p class="mb-1">Categoria: <asp:Literal ID="litInfoCategoryName" runat="server" /></p>
        </asp:PlaceHolder>
        <p class="mb-1">TCId: <asp:Literal ID="litInfoTCId" runat="server" /></p>
        <p class="mb-0">Varianti: <asp:Literal ID="litInfoVariants" runat="server" /></p>
    </div>
</div>
