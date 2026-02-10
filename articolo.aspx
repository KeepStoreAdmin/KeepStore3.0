<%@ Page Language="VB" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" MasterPageFile="~/Page.master" %>

<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litJsonLdHead" runat="server" />
</asp:Content>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumbs -->
    <div class="tf-sp-1">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="articoli.aspx" class="text">Articoli</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text"><asp:Literal ID="litBreadcrumbCurrent" runat="server" /></span>
                </div>
            </div>
        </div>
    </div>

    <!-- Not found -->
    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="flat-spacing">
            <div class="container">
                <div class="tf-page-title">
                    <div class="heading text-center">Articolo non trovato</div>
                    <p class="text text-center mt-3">
                        Non è stato possibile trovare l'articolo richiesto.
                    </p>
                    <div class="text-center mt-4">
                        <a class="tf-btn btn-fill" href="articoli.aspx">Torna agli articoli</a>
                    </div>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <!-- Product -->
    <asp:Panel ID="pnlProduct" runat="server" Visible="false">
        <section class="flat-spacing">
            <div class="container">
                <div class="tf-main-product section-image-zoom">
                    <!-- Media -->
                    <div class="tf-product-media-wrap">
                        <div class="thumbs-slider">
                            <div class="swiper tf-product-media-main" id="gallery-swiper-started">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptMainImages" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <a href='<%# Eval("Url") %>' target="_blank" class="item">
                                                    <img class="tf-image-zoom lazyload"
                                                         data-src='<%# Eval("Url") %>'
                                                         src='<%# Eval("Url") %>'
                                                         data-zoom='<%# Eval("Url") %>'
                                                         alt='<%# Eval("Alt") %>' />
                                                </a>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                                <div class="swiper-button-next button-style-arrow thumbs-next"></div>
                                <div class="swiper-button-prev button-style-arrow thumbs-prev"></div>
                            </div>

                            <div class="swiper tf-product-media-thumbs other-image-zoom" data-direction="vertical">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptThumbs" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <div class="item">
                                                    <img class="lazyload"
                                                         data-src='<%# Eval("Url") %>'
                                                         src='<%# Eval("Url") %>'
                                                         alt='<%# Eval("Alt") %>' />
                                                </div>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>
                        <div class="tf-zoom-main"></div>
                    </div>

                    <!-- Info -->
                    <div class="tf-product-info-wrap position-relative">
                        <div class="tf-product-info-list">
                            <div class="tf-product-info-title">
                                <h1 class="title"><asp:Literal ID="litNome" runat="server" /></h1>
                            </div>

                            <div class="tf-product-info-price">
                                <asp:Literal ID="litPriceHtml" runat="server" />
                            </div>

                            <div class="tf-product-info-desc">
                                <asp:Literal ID="litShortDesc" runat="server" />
                            </div>

                            <asp:Panel ID="pnlVariants" runat="server" Visible="false">
                                <div class="tf-product-info-variant">
                                    <div class="variant-picker-item">
                                        <div class="variant-picker-label">Variante</div>
                                        <asp:DropDownList ID="ddlTc" runat="server" AutoPostBack="true" CssClass="form-select" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                    </div>
                                </div>
                            </asp:Panel>

                            <div class="tf-product-info-quantity">
                                <div class="quantity-title">Quantità</div>
                                <div class="wg-quantity">
                                    <asp:TextBox ID="txtQty" runat="server" CssClass="quantity-input" Text="1" />
                                </div>
                                <asp:Literal ID="litQtyHelp" runat="server" />
                            </div>

                            <div class="tf-product-info-buy-button">
                                <asp:LinkButton ID="btnAddToCart" runat="server" CssClass="tf-btn btn-fill justify-content-center fw-6 fs-16 flex-grow-1 animate-hover-btn" OnClick="btnAddToCart_Click">
                                    Aggiungi al carrello
                                </asp:LinkButton>
                            </div>

                            <div class="tf-product-info-meta">
                                <div class="meta-item">
                                    Codice:
                                    <span class="meta-value"><asp:Literal ID="litCodice" runat="server" /></span>
                                </div>

                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                    <div class="meta-item">
                                        Marca:
                                        <span class="meta-value"><asp:HyperLink ID="lnkMarca" runat="server" /></span>
                                    </div>
                                </asp:PlaceHolder>

                                <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                    <div class="meta-item">
                                        EAN:
                                        <span class="meta-value"><asp:Literal ID="litEan" runat="server" /></span>
                                    </div>
                                </asp:PlaceHolder>

                                <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                    <div class="meta-item">
                                        Disponibilità:
                                        <span class="meta-value"><asp:Literal ID="litAvailability" runat="server" /></span>
                                    </div>
                                </asp:PlaceHolder>
                            </div>

                        </div>
                    </div>
                </div>

                <!-- Tabs -->
                <div class="flat-spacing pt-0">
                    <div class="tf-product-description">
                        <ul class="nav nav-tabs" role="tablist">
                            <li class="nav-item" role="presentation">
                                <a class="nav-link active" data-bs-toggle="tab" href="#tab-desc" role="tab" aria-selected="true">Descrizione</a>
                            </li>
                            <li class="nav-item" role="presentation">
                                <a class="nav-link" data-bs-toggle="tab" href="#tab-info" role="tab" aria-selected="false">Dettagli</a>
                            </li>
                            <li class="nav-item" role="presentation">
                                <a class="nav-link" data-bs-toggle="tab" href="#tab-shipping" role="tab" aria-selected="false">Spedizione</a>
                            </li>
                        </ul>

                        <div class="tab-content">
                            <div class="tab-pane fade show active" id="tab-desc" role="tabpanel">
                                <div class="tf-accordion-content">
                                    <asp:Literal ID="litLongDesc" runat="server" Mode="PassThrough" />
                                </div>
                            </div>

                            <div class="tab-pane fade" id="tab-info" role="tabpanel">
                                <div class="tf-accordion-content">
                                    <ul class="list-unstyled mb-0">
                                        <li><strong>Codice:</strong> <asp:Literal ID="litCodice2" runat="server" /></li>

                                        <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                            <li><strong>EAN:</strong> <asp:Literal ID="litEan2" runat="server" /></li>
                                        </asp:PlaceHolder>

                                        <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                            <li><strong>Marca:</strong> <asp:Literal ID="litMarca2" runat="server" /></li>
                                        </asp:PlaceHolder>
                                    </ul>
                                </div>
                            </div>

                            <div class="tab-pane fade" id="tab-shipping" role="tabpanel">
                                <div class="tf-accordion-content">
                                    <p class="mb-2">
                                        Spedizione e resi vengono calcolati al checkout in base all'indirizzo e al peso/volume dell'ordine.
                                    </p>
                                    <p class="mb-0">
                                        Per informazioni aggiuntive puoi contattarci dalla pagina <a href="Contattaci.aspx">Contatti</a>.
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </section>
    </asp:Panel>

	    <!-- Related products (bound server-side; no inline functions in markup) -->
	    <asp:PlaceHolder ID="phRelated" runat="server" Visible="False">
	        <section class="flat-spacing pt-0">
	            <div class="container">
	                <div class="tf-section-title mb_30">
	                    <h2 class="title">Prodotti correlati</h2>
	                </div>
	                <div class="tf-grid-layout tf-col-4 gap30">
	                    <asp:Repeater ID="rptRelated" runat="server" OnItemDataBound="rptRelated_ItemDataBound">
	                        <ItemTemplate>
	                            <div class="card-product">
	                                <div class="card-product-wrapper">
	                                    <asp:HyperLink ID="hlRelImg" runat="server" CssClass="product-img">
	                                        <asp:Image ID="imgRel" runat="server" CssClass="img-fluid" AlternateText="" />
	                                    </asp:HyperLink>
	                                </div>
	                                <div class="card-product-info">
	                                    <asp:HyperLink ID="hlRelName" runat="server" CssClass="title link" />
	                                    <div class="price">
	                                        <asp:Literal ID="litRelPrice" runat="server" EnableViewState="False" />
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

	<asp:Content ID="ScriptsArticolo" ContentPlaceHolderID="ScriptsContent" runat="server">
	    <script type="module" src="/Public/assets/onsus/js/zoom.js"></script>
	</asp:Content>
