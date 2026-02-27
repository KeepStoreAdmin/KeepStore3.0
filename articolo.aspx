<%@ Page Language="VB" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" MasterPageFile="~/Public/ui/master/Site.master" %>

<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litJsonLdHead" runat="server" />
</asp:Content>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumbs (tema) -->
    <div class="tf-breakcrumb">
        <div class="container">
            <ul class="breakcrumb-list">
                <li>
                    <a href="default.aspx" class="body-small link">Home</a>
                </li>
                <li class="d-flex align-items-center">
                    <i class="icon icon-arrow-right"></i>
                </li>
                <li>
                    <a href="articoli.aspx" class="body-small link">Shop</a>
                </li>
                <li class="d-flex align-items-center">
                    <i class="icon icon-arrow-right"></i>
                </li>
                <li>
                    <span class="body-small"><asp:Literal ID="litBreadcrumbCurrent" runat="server" /></span>
                </li>
            </ul>
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
        <!-- Product Main (product-detail like) -->
        <section>
            <div class="tf-main-product section-image-zoom">
                <div class="container">
                    <div class="row">
                        <div class="col-md-6">
                            <!-- Product Image -->
                            <div class="tf-product-media-wrap thumbs-default sticky-top">
                                <div class="thumbs-slider">
                                    <div class="swiper tf-product-media-main" id="gallery-swiper-started">
                                        <div class="swiper-wrapper">
                                            <asp:Repeater ID="rptMainImages" runat="server">
                                                <ItemTemplate>
                                                    <div class="swiper-slide">
                                                        <a href='<%# Eval("Url") %>' target="_blank" class="item">
                                                            <img class="tf-image-zoom lazyload"
                                                                 src='<%# Eval("Url") %>'
                                                                 data-zoom='<%# Eval("Url") %>'
                                                                 data-src='<%# Eval("Url") %>'
                                                                 alt='<%# Eval("Alt") %>' />
                                                        </a>
                                                    </div>
                                                </ItemTemplate>
                                            </asp:Repeater>
                                        </div>
                                    </div>

                                    <div class="container-swiper">
                                        <div class="swiper tf-product-media-thumbs other-image-zoom" data-direction="horizontal">
                                            <div class="swiper-wrapper stagger-wrap">
                                                <asp:Repeater ID="rptThumbs" runat="server">
                                                    <ItemTemplate>
                                                        <div class="swiper-slide stagger-item">
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
                                </div>
                            </div>
                            <!-- /Product Image -->
                        </div>

                        <div class="col-md-6">
                            <!-- Product Info -->
                            <div class="tf-product-info-wrap position-relative">
                                <div class="tf-zoom-main"></div>
                                <div class="tf-product-info-list other-image-zoom flex-xxl-nowrap">
                                    <div class="tf-product-info-content">
                                        <div class="infor-heading">
                                            <p class="caption">
                                                <span class="text-main-2">Codice:</span>
                                                <span class="text-secondary fw-semibold"><asp:Literal ID="litCodice" runat="server" /></span>
                                            </p>
                                            <h5 class="product-info-name fw-semibold">
                                                <asp:Literal ID="litNome" runat="server" />
                                            </h5>
                                            <ul class="product-info-rate-wrap">
                                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                                    <li class="d-flex">
                                                        <span class="caption text-main-2">Marca:&nbsp;</span>
                                                        <asp:HyperLink ID="lnkMarca" runat="server" CssClass="caption text-secondary link fw-semibold" />
                                                    </li>
                                                </asp:PlaceHolder>
                                                <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                                    <li>
                                                        <span class="caption text-main-2">EAN:&nbsp;</span>
                                                        <span class="caption text-secondary fw-semibold"><asp:Literal ID="litEan" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                                <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                                    <li>
                                                        <span class="caption text-main-2">Disponibilità:&nbsp;</span>
                                                        <span class="caption text-secondary fw-semibold"><asp:Literal ID="litAvailability" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                            </ul>
                                        </div>

                                        <div class="infor-center">
                                            <div class="product-info-price">
                                                <asp:Literal ID="litPriceHtml" runat="server" />
                                            </div>
                                            <div class="mt-3">
                                                <asp:Literal ID="litShortDesc" runat="server" />
                                            </div>
                                        </div>

                                        <div class="infor-bottom">
                                            <h6 class="fw-semibold">Info</h6>
                                            <ul class="product-about-list">
                                                <li>
                                                    <p class="body-text-3 mb-0">Seleziona quantità e aggiungi al carrello.</p>
                                                </li>
                                            </ul>
                                        </div>
                                    </div>

                                    <!-- Sticky box (CTA/Quantity/Variant) -->
                                    <div class="tf-product-info-choose-option sticky-top">
                                        <div class="product-delivery">
                                            <p class="price-text fw-medium text-primary">
                                                <asp:Literal ID="litPriceHtml2" runat="server" />
                                            </p>
                                            <p>
                                                <i class="icon-delivery-2"></i>
                                                Spedizione calcolata al checkout
                                            </p>
                                        </div>

                                        <asp:Panel ID="pnlVariants" runat="server" Visible="false">
                                            <div class="product-color">
                                                <p class="title body-text-3">Variante</p>
                                                <div class="tf-select-color">
                                                    <asp:DropDownList ID="ddlTc" runat="server" AutoPostBack="true" CssClass="select-color" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                                </div>
                                            </div>
                                        </asp:Panel>

                                        <div class="product-quantity">
                                            <p class="title body-text-3">Quantity</p>
                                            <div class="wg-quantity">
                                                <button type="button" class="btn-quantity btn-decrease" onclick="(function(){var i=document.getElementById('<%= txtQty.ClientID %>'); if(!i) return; var v=parseInt(i.value||'1',10); if(isNaN(v)||v<=1){i.value='1';} else {i.value=(v-1).toString();}})();">
                                                    <i class="icon-minus"></i>
                                                </button>
                                                <asp:TextBox ID="txtQty" runat="server" CssClass="quantity-product" Text="1" />
                                                <button type="button" class="btn-quantity btn-increase" onclick="(function(){var i=document.getElementById('<%= txtQty.ClientID %>'); if(!i) return; var v=parseInt(i.value||'1',10); if(isNaN(v)||v<1){v=1;} i.value=(v+1).toString();})();">
                                                    <i class="icon-plus"></i>
                                                </button>
                                            </div>
                                            <div class="mt-2">
                                                <asp:Literal ID="litQtyHelp" runat="server" />
                                            </div>
                                        </div>

                                        <div class="product-box-btn">
                                            <asp:LinkButton ID="btnAddToCart" runat="server" CssClass="tf-btn text-white" OnClick="btnAddToCart_Click">
                                                Aggiungi al carrello
                                                <i class="icon-cart-2"></i>
                                            </asp:LinkButton>
                                            <a href="carrello.aspx" class="tf-btn text-white btn-gray">Vai al carrello</a>
                                        </div>

                                        <div class="product-detail">
                                            <p class="caption">Details</p>
                                            <p class="body-text-3">
                                                <span>Reso: 30 giorni (ove applicabile)</span>
                                                <span>Supporto: assistenza tecnica disponibile</span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- /Product Info -->
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Product Description Tab (tema) -->
        <section class="tf-sp-4">
            <div class="container">
                <div class="flat-animate-tab flat-title-tab-product-des">
                    <div class="flat-title-tab text-center">
                        <ul class="menu-tab-line" role="tablist">
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-des" class="tab-link product-title fw-semibold active" data-bs-toggle="tab">Description</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-infor" class="tab-link product-title fw-semibold" data-bs-toggle="tab">Product information</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-ship" class="tab-link product-title fw-semibold" data-bs-toggle="tab">Shipping</a>
                            </li>
                        </ul>
                    </div>
                    <div class="tab-content">
                        <div class="tab-pane active show" id="prd-des" role="tabpanel">
                            <div class="tab-main tab-des">
                                <asp:Literal ID="litLongDesc" runat="server" Mode="PassThrough" />
                            </div>
                        </div>
                        <div class="tab-pane" id="prd-infor" role="tabpanel">
                            <div class="tab-main tab-infor">
                                <ul class="product-fearture-list">
                                    <li>
                                        <p class="body-md-2 fw-semibold">Codice</p>
                                        <span class="body-text-3"><asp:Literal ID="litCodice2" runat="server" /></span>
                                    </li>
                                    <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                        <li>
                                            <p class="body-md-2 fw-semibold">EAN</p>
                                            <span class="body-text-3"><asp:Literal ID="litEan2" runat="server" /></span>
                                        </li>
                                    </asp:PlaceHolder>
                                    <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                        <li>
                                            <p class="body-md-2 fw-semibold">Marca</p>
                                            <span class="body-text-3"><asp:Literal ID="litMarca2" runat="server" /></span>
                                        </li>
                                    </asp:PlaceHolder>
                                </ul>
                            </div>
                        </div>
                        <div class="tab-pane" id="prd-ship" role="tabpanel">
                            <div class="tab-main tab-des">
                                <p class="body-text-3">
                                    Spedizione e resi vengono calcolati al checkout in base all'indirizzo e al peso/volume dell'ordine.
                                </p>
                                <p class="body-text-3 mb-0">
                                    Per informazioni aggiuntive puoi contattarci dalla pagina <a class="link text-secondary" href="Contattaci.aspx">Contatti</a>.
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </asp:Panel>

    <!-- Related products (slider style; bound server-side) -->
    <asp:PlaceHolder ID="phRelated" runat="server" Visible="False">
        <section class="tf-sp-2 pt-0">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Prodotti correlati</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2"
                     data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3"
                     data-pagination-md="4" data-pagination-lg="5" data-nav-prev=".nav-prev-products" data-nav-next=".nav-next-products">
                    <div class="swiper-wrapper">
                        <asp:Repeater ID="rptRelated" runat="server">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <div class="card-product">
                                        <div class="card-product-wrapper">
                                            <a href='<%# Eval("Url") %>' class="product-img">
                                                <img class="img-product lazyload" src='<%# Eval("Img") %>' data-src='<%# Eval("Img") %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Eval("Nome")) %>' />
                                                <img class="img-hover lazyload" src='<%# Eval("Img") %>' data-src='<%# Eval("Img") %>' alt='<%# System.Web.HttpUtility.HtmlAttributeEncode(Eval("Nome")) %>' />
                                            </a>
                                            <ul class="list-product-btn">
                                                <li>
                                                    <a href='<%# Eval("Url") %>' class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                                                        <span class="icon icon-cart2"></span>
                                                        <span class="tooltip">Vedi prodotto</span>
                                                    </a>
                                                </li>
                                                <li class="d-none d-sm-block">
                                                    <a href='<%# Eval("Url") %>' class="box-icon quickview btn-icon-action hover-tooltip tooltip-left">
                                                        <span class="icon icon-view"></span>
                                                        <span class="tooltip">Dettagli</span>
                                                    </a>
                                                </li>
                                            </ul>
                                        </div>
                                        <div class="card-product-info">
                                            <div class="box-title">
                                                <div class="d-flex flex-column">
                                                    <a href='<%# Eval("Url") %>' class="name-product body-md-2 fw-semibold text-secondary link">
                                                        <%# System.Web.HttpUtility.HtmlEncode(Eval("Nome")) %>
                                                    </a>
                                                </div>
                                                <p class="price-wrap fw-medium">
                                                    <%# Eval("PrezzoHtml") %>
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

</asp:Content>

<asp:Content ID="ScriptsArticolo" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script type="module" src="<%= ThemeManager.Asset("js/zoom.js") %>"></script>
</asp:Content>
