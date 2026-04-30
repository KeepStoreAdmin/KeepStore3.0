<%@ Page Title="Prodotto" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    <%= If(litNome IsNot Nothing AndAlso Not String.IsNullOrEmpty(litNome.Text), Server.HtmlEncode(litNome.Text), "Prodotto") %>
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />

    <!-- Product gallery / zoom -->
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/drift-basic.min.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/photoswipe.css") %>" />

    <script type="application/ld+json">
        <asp:Literal ID="litJsonLdHead" runat="server" EnableViewState="false" />
    </script>
</asp:Content>

<asp:Content ID="BreadcrumbContent1" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <div class="tf-sp-1">
        <div class="container">
            <ul class="breakcrumbs">
                <li><a href="/">Home</a></li>
                <li><i class="icon icon-arrow-right"></i></li>
                <li><a href="/articoli.aspx">Catalogo</a></li>
                <li><i class="icon icon-arrow-right"></i></li>
                <li><span><asp:Literal ID="litBreadcrumbCurrent" runat="server" /></span></li>
            </ul>
        </div>
    </div>
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <!-- NOT FOUND -->
    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="alert alert-warning">Prodotto non trovato o non disponibile.</div>
            </div>
        </section>
    </asp:PlaceHolder>

    <!-- PRODUCT DETAIL (Template: Product Detail) -->
    <asp:Panel ID="pnlProduct" runat="server" CssClass="flat-spacing-2">
        <div class="container">
            <div class="tf-main-product section-image-zoom">
                <div class="tf-product-info-wrap">

                    <!-- MEDIA (LEFT) -->
                    <div class="tf-product-media-wrap thumbs-default sticky-top">

                        <!-- Main gallery -->
                        <div class="thumbs-slider">
                            <div class="swiper tf-product-media-main" id="gallery-swiper-started">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptMainImages" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <a class="item" href='<%# Eval("Url") %>' data-pswp-width="800" data-pswp-height="800" target="_blank" rel="noopener">
                                                    <img class="tf-image-zoom lazyload"
                                                         alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>'
                                                         data-zoom='<%# Eval("Url") %>'
                                                         data-src='<%# Eval("Url") %>' src='<%# Eval("Url") %>' />
                                                </a>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                        <!-- Thumbs -->
                        <div class="container-swiper" id="ks-product-thumbs-wrap">
                            <div class="swiper tf-product-media-thumbs other-image-zoom" id="thumbs-swiper-started">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptThumbs" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <div class="item">
                                                    <img class="lazyload"
                                                         alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>'
                                                         data-zoom='<%# Eval("Url") %>'
                                                         data-src='<%# Eval("Url") %>' src='<%# Eval("Url") %>' />
                                                </div>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                    </div>

                    <!-- INFO (RIGHT) -->
                    <div class="tf-zoom-main"></div>
                    <div class="tf-product-info-list other-image-zoom flex-xxl-nowrap">

                        <!-- Content -->
                        <div class="tf-product-info-content">
                            <h1 class="tf-product-info-name">
                                <asp:Literal ID="litNome" runat="server" />
                            </h1>

                            <asp:PlaceHolder ID="phRefurbished" runat="server" Visible="false">
                                <div class="ks-refurbished-detail">
                                    <img src="/Public/assets/images/ico/refurbished.png" alt="Ricondizionato" />
                                    <span>Articolo ricondizionato</span>
                                    <asp:Literal ID="litRefurbishedNote" runat="server" />
                                </div>
                            </asp:PlaceHolder>

                            <div class="tf-product-info-desc">
                                <asp:Literal ID="litShortDesc" runat="server" />
                            </div>

                            <div class="tf-product-info-price">
                                <asp:Literal ID="litPriceHtml" runat="server" />
                            </div>

                            <div class="tf-product-info-meta">
                                <div class="meta-item">
                                    <span class="label">Codice:</span>
                                    <span class="value"><asp:Literal ID="litCodice" runat="server" /></span>
                                </div>

                                <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                    <div class="meta-item">
                                        <span class="label">EAN:</span>
                                        <span class="value"><asp:Literal ID="litEan" runat="server" /></span>
                                    </div>
                                </asp:PlaceHolder>

                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                    <div class="meta-item">
                                        <span class="label">Marca:</span>
                                        <span class="value"><asp:HyperLink ID="lnkMarca" runat="server" CssClass="link" /></span>
                                    </div>
                                </asp:PlaceHolder>
                            </div>

                            <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                <div class="tf-product-availability">
                                    <asp:Literal ID="litAvailability" runat="server" />
                                </div>
                            </asp:PlaceHolder>
                        </div>

                        <!-- Choose option (sticky) -->
                        <div class="tf-product-info-choose-option sticky-top">
                            <div class="tf-product-info-by">

                                <div class="tf-product-info-price">
                                    <asp:Literal ID="litPriceHtml2" runat="server" />
                                </div>

                                <div class="tf-product-info-meta">
                                    <div class="meta-item">
                                        <span class="label">Codice:</span>
                                        <span class="value"><asp:Literal ID="litCodice2" runat="server" /></span>
                                    </div>

                                    <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                        <div class="meta-item">
                                            <span class="label">EAN:</span>
                                            <span class="value"><asp:Literal ID="litEan2" runat="server" /></span>
                                        </div>
                                    </asp:PlaceHolder>

                                    <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                        <div class="meta-item">
                                            <span class="label">Marca:</span>
                                            <span class="value"><asp:Literal ID="litMarca2" runat="server" /></span>
                                        </div>
                                    </asp:PlaceHolder>
                                </div>

                                <asp:Panel ID="pnlVariants" runat="server" Visible="false" CssClass="mt-3">
                                    <label class="text-title">Variante</label>
                                    <asp:DropDownList ID="ddlTc" runat="server" CssClass="form-select" AutoPostBack="true" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                </asp:Panel>

                                <div class="tf-product-info-quantity mt-3">
                                    <div class="quantity-title">Quantità</div>
                                    <div class="wg-quantity">
                                        <span class="btn-quantity minus-btn" data-ks-qty="minus"></span>
                                        <asp:TextBox ID="txtQty" runat="server" CssClass="quantity-product__input" Text="1" />
                                        <span class="btn-quantity plus-btn" data-ks-qty="plus"></span>
                                    </div>
                                    <div class="small text-danger mt-1">
                                        <asp:Literal ID="litQtyHelp" runat="server" />
                                    </div>
                                </div>

                                <div class="tf-product-info-buy-button mt-3">
                                    <asp:Button ID="btnAddToCart" runat="server" CssClass="tf-btn btn-fill" Text="Aggiungi al carrello" OnClick="btnAddToCart_Click" />
                                </div>

                                <div class="mt-3">
                                    <a class="tf-btn btn-outline" href="/carrello.aspx">Vai al carrello</a>
                                </div>

                            </div>
                        </div>

                    </div>

                </div>
            </div>

            <!-- DESCRIPTION / DETAILS -->
            <div class="flat-title-tab-product-des mt-5">
                <ul class="nav-tab" role="tablist">
                    <li class="nav-tab-item" role="presentation">
                        <a href="#tab-desc" class="nav-tab-link active" data-bs-toggle="tab" role="tab">Descrizione</a>
                    </li>
                    <li class="nav-tab-item" role="presentation">
                        <a href="#tab-details" class="nav-tab-link" data-bs-toggle="tab" role="tab">Dettagli</a>
                    </li>
                </ul>
            </div>

            <div class="tab-content">
                <div class="tab-pane fade show active" id="tab-desc" role="tabpanel">
                    <div class="tf-rte">
                        <asp:Literal ID="litLongDesc" runat="server" />
                    </div>
                </div>

                <div class="tab-pane fade" id="tab-details" role="tabpanel">
                    <div class="tf-rte">
                        <p class="mb-1"><strong>Codice:</strong> <asp:Literal ID="litCodice3" runat="server" Visible="false" /></p>
                        <p class="mb-1"><strong>EAN:</strong> <asp:Literal ID="litEan3" runat="server" Visible="false" /></p>
                    </div>
                </div>
            </div>

        </div>
    </asp:Panel>

    <!-- RELATED PRODUCTS -->
    <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="tf-section-heading">
                    <h3 class="heading">Prodotti correlati</h3>
                    <a href="/articoli.aspx" class="link">Vedi tutto</a>
                </div>

                <div class="tf-grid-layout md-col-4">                    <asp:Repeater ID="rptRelated" runat="server">
                        <ItemTemplate>
                            <div class="card-product style-1">
                                <div class="card-product-wrapper">

                                    <a class="product-img" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             src='<%# Eval("Img") %>' />
                                    </a>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>

                                </div>

                                <div class="card-product-info">
                                    <a class="name-product link" href='<%# Eval("Url") %>'>
                                        <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                    </a>

                                    <div class="price-wrap">
                                        <%# Eval("PrezzoHtml") %>
                                    </div>
                                </div>

                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Public/assets/keepstore/js/keepstore-product.js"></script>
</asp:Content>
