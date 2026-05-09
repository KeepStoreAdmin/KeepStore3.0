<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductDetailView.ascx.vb" Inherits="Public_ui_controls_ProductDetailView" %>

<div class="alert alert-info mb-4" role="note">
    <div class="d-flex justify-content-between gap-3 mb-3">
        <div>
            <p class="mb-1"><strong>Preview nuova scheda prodotto</strong></p>
            <p class="mb-0 small text-muted">Demo locale non operativa. La scheda reale resta sotto questa preview.</p>
        </div>
        <span class="small text-muted">ksProductDetailPreview=1</span>
    </div>

    <div class="row g-3">
        <div class="col-md-5">
            <div class="border rounded p-3 mb-3">
                <p class="mb-2"><strong>Media demo</strong></p>
                <asp:PlaceHolder ID="phMainImage" runat="server" Visible="false">
                    <div class="mb-3">
                        <asp:Image ID="imgMain" runat="server" />
                    </div>
                </asp:PlaceHolder>

                <asp:PlaceHolder ID="phDemoGallery" runat="server" Visible="false">
                    <p class="mb-2 small text-muted">Gallery demo statica</p>
                    <div class="d-flex gap-2">
                        <asp:Repeater ID="rptDemoGalleryImages" runat="server">
                            <ItemTemplate>
                                <span class="d-inline-block border rounded p-1">
                                    <asp:Image ID="imgDemoGalleryThumb" runat="server" ImageUrl='<%# Container.DataItem %>' AlternateText="Miniatura prodotto" Width="72" Height="72" />
                                </span>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </asp:PlaceHolder>
            </div>
        </div>

        <div class="col-md-7">
            <div class="border rounded p-3 mb-3">
                <p class="mb-1"><strong><asp:Literal ID="litProductName" runat="server" /></strong></p>
                <div class="small text-muted mb-2">
                    Codice: <asp:Literal ID="litProductCode" runat="server" />
                    <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                        <span class="ms-2">EAN: <asp:Literal ID="litEan" runat="server" /></span>
                    </asp:PlaceHolder>
                </div>
                <div class="d-flex gap-3 mb-2">
                    <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                        <span>Marca: <asp:Literal ID="litBrandName" runat="server" /></span>
                    </asp:PlaceHolder>
                    <asp:PlaceHolder ID="phCategory" runat="server" Visible="false">
                        <span>Categoria: <asp:Literal ID="litCategoryName" runat="server" /></span>
                    </asp:PlaceHolder>
                </div>
                <asp:PlaceHolder ID="phRefurbished" runat="server" Visible="false">
                    <p class="mb-0 small">Ricondizionato: <asp:Literal ID="litRefurbished" runat="server" /></p>
                </asp:PlaceHolder>
                <p class="mb-0 small text-muted">TCId: <asp:Literal ID="litTCId" runat="server" /></p>
            </div>

            <div class="border rounded p-3 mb-3">
                <p class="mb-1"><strong>Prezzo e disponibilita</strong></p>
                <p class="mb-1">Prezzo: <asp:Literal ID="litPrice" runat="server" /></p>
                <asp:PlaceHolder ID="phOldPrice" runat="server" Visible="false">
                    <p class="mb-1 small text-muted">Prezzo precedente: <asp:Literal ID="litOldPrice" runat="server" /></p>
                </asp:PlaceHolder>
                <asp:PlaceHolder ID="phPromo" runat="server" Visible="false">
                    <p class="mb-1">Promo: <asp:Literal ID="litPromo" runat="server" /></p>
                </asp:PlaceHolder>
                <asp:PlaceHolder ID="phIva" runat="server" Visible="false">
                    <p class="mb-1 small text-muted">IVA: <asp:Literal ID="litIvaLabel" runat="server" /></p>
                </asp:PlaceHolder>
                <p class="mb-0">Disponibilita: <asp:Literal ID="litAvailability" runat="server" /></p>
            </div>

            <div class="border rounded p-3 mb-3">
                <p class="mb-1"><strong>Mini buy-box demo</strong></p>
                <p class="mb-1">Quantita demo: <asp:Literal ID="litQuantity" runat="server" /></p>
                <p class="mb-1">Varianti: <asp:Literal ID="litVariants" runat="server" /></p>
                <p class="mb-1">Add-to-cart: <asp:Literal ID="litAddToCartStatus" runat="server" /></p>
                <p class="mb-0 small text-muted">Il carrello reale resta gestito dalla scheda originale sotto la preview.</p>
            </div>

            <asp:PlaceHolder ID="phProductUrl" runat="server" Visible="false">
                <div class="border rounded p-3 mb-3">
                    <p class="mb-0 small text-muted">Link prodotto informativo: <asp:Literal ID="litProductUrl" runat="server" /></p>
                </div>
            </asp:PlaceHolder>
        </div>
    </div>

    <div class="row g-3">
        <div class="col-md-7">
            <div class="border rounded p-3">
                <p class="mb-2"><strong>Descrizione demo</strong></p>
                <asp:PlaceHolder ID="phShortDescription" runat="server" Visible="false">
                    <div class="mb-2"><asp:Literal ID="litShortDescription" runat="server" /></div>
                </asp:PlaceHolder>
                <asp:PlaceHolder ID="phLongDescription" runat="server" Visible="false">
                    <div class="mb-0"><asp:Literal ID="litLongDescription" runat="server" /></div>
                </asp:PlaceHolder>
            </div>
        </div>

        <div class="col-md-5">
            <div class="border rounded p-3">
                <p class="mb-2"><strong>Informazioni prodotto demo</strong></p>
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
    </div>
</div>
