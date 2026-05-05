<%@ Page Title="Prodotto" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    <%= If(litNome IsNot Nothing AndAlso Not String.IsNullOrEmpty(litNome.Text), Server.HtmlEncode(litNome.Text), "Prodotto") %>
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />

    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/drift-basic.min.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/photoswipe.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/product-ui.css") %>" />

    <asp:Literal ID="litJsonLdHead" runat="server" EnableViewState="false" />
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

    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="alert alert-warning">Prodotto non trovato o non disponibile.</div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:Panel ID="pnlProduct" runat="server" CssClass="ks-product-page">
        <section class="ks-product-main-section">
            <div class="tf-main-product section-image-zoom">
                <div class="container">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="tf-product-media-wrap thumbs-default sticky-top">
                                <div class="thumbs-slider">
                                    <div class="swiper tf-product-media-main ks-product-gallery-main" id="gallery-swiper-started">
                                        <div class="swiper-wrapper">
                                            <asp:Repeater ID="rptMainImages" runat="server">
                                                <ItemTemplate>
                                                    <div class="swiper-slide">
                                                        <a class="item" href='<%# Eval("Url") %>' data-pswp-width="800" data-pswp-height="800" target="_blank" rel="noopener">
                                                            <img class="tf-image-zoom lazyload"
                                                                 alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>'
                                                                 data-zoom='<%# Eval("Url") %>'
                                                                 data-src='<%# Eval("Url") %>'
                                                                 src='<%# Eval("Url") %>' />
                                                        </a>
                                                    </div>
                                                </ItemTemplate>
                                            </asp:Repeater>
                                        </div>
                                    </div>

                                    <div class="container-swiper" id="ks-product-thumbs-wrap">
                                        <div class="swiper tf-product-media-thumbs other-image-zoom ks-product-gallery-thumbs" id="thumbs-swiper-started" data-direction="horizontal">
                                            <div class="swiper-wrapper stagger-wrap">
                                                <asp:Repeater ID="rptThumbs" runat="server">
                                                    <ItemTemplate>
                                                        <div class="swiper-slide stagger-item">
                                                            <div class="item">
                                                                <img class="lazyload ks-product-thumb"
                                                                     alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>'
                                                                     data-zoom='<%# Eval("Url") %>'
                                                                     data-src='<%# Eval("Url") %>'
                                                                     src='<%# Eval("Url") %>' />
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="tf-product-info-wrap position-relative">
                                <div class="tf-zoom-main"></div>
                                <div class="tf-product-info-list other-image-zoom flex-xxl-nowrap">
                                    <div class="tf-product-info-content">
                                        <div class="infor-heading">
                                            <p class="caption">
                                                Categoria:
                                                <asp:HyperLink ID="lnkCategory" runat="server" CssClass="link text-secondary" NavigateUrl="/articoli.aspx" Text="Catalogo" />
                                            </p>
                                            <h1 class="product-info-name fw-semibold">
                                                <asp:Literal ID="litNome" runat="server" />
                                            </h1>

                                            <ul class="product-info-rate-wrap">
                                                <li>
                                                    <p class="caption text-main-2">
                                                        Codice:
                                                        <span class="text-secondary"><asp:Literal ID="litCodice" runat="server" /></span>
                                                    </p>
                                                </li>
                                                <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                                    <li>
                                                        <p class="caption text-main-2">
                                                            EAN:
                                                            <span class="text-secondary"><asp:Literal ID="litEan" runat="server" /></span>
                                                        </p>
                                                    </li>
                                                </asp:PlaceHolder>
                                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                                    <li class="d-flex">
                                                        <span class="caption text-main-2">Marca:&nbsp;</span>
                                                        <asp:HyperLink ID="lnkMarca" runat="server" CssClass="caption text-secondary link" />
                                                    </li>
                                                </asp:PlaceHolder>
                                                <li class="star-review">
                                                    <ul class="list-star">
                                                        <li><i class="icon-star text-main-4"></i></li>
                                                        <li><i class="icon-star text-main-4"></i></li>
                                                        <li><i class="icon-star text-main-4"></i></li>
                                                        <li><i class="icon-star text-main-4"></i></li>
                                                        <li><i class="icon-star text-main-4"></i></li>
                                                    </ul>
                                                    <p class="caption text-main-2"><asp:Literal ID="litHeaderReviewText" runat="server" Text="Nessuna recensione" /></p>
                                                </li>
                                            </ul>
                                        </div>

                                        <div class="infor-center">
                                            <div class="product-info-price ks-product-price">
                                                <asp:Literal ID="litPriceHtml" runat="server" />
                                            </div>

                                            <ul class="product-fearture-list">
                                                <asp:PlaceHolder ID="phCategoryFeature" runat="server" Visible="false">
                                                    <li>
                                                        <p class="body-md-2 fw-semibold">Categoria</p>
                                                        <span class="body-text-3"><asp:Literal ID="litCategory2" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                                <asp:PlaceHolder ID="phBrandFeature" runat="server" Visible="false">
                                                    <li>
                                                        <p class="body-md-2 fw-semibold">Marca</p>
                                                        <span class="body-text-3"><asp:Literal ID="litMarcaFeature" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                                <li>
                                                    <p class="body-md-2 fw-semibold">Codice</p>
                                                    <span class="body-text-3"><asp:Literal ID="litCodice3" runat="server" /></span>
                                                </li>
                                                <asp:PlaceHolder ID="phEan3" runat="server" Visible="false">
                                                    <li>
                                                        <p class="body-md-2 fw-semibold">EAN</p>
                                                        <span class="body-text-3"><asp:Literal ID="litEan3" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                                <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                                    <li>
                                                        <p class="body-md-2 fw-semibold">Stock</p>
                                                        <span class="body-text-3 text-secondary"><asp:Literal ID="litAvailability" runat="server" /></span>
                                                    </li>
                                                </asp:PlaceHolder>
                                            </ul>
                                        </div>

                                        <asp:PlaceHolder ID="phRefurbished" runat="server" Visible="false">
                                            <div class="ks-refurbished-detail">
                                                <img src="/Public/assets/images/ico/refurbished.png" alt="Ricondizionato" />
                                                <span>Articolo ricondizionato</span>
                                                <asp:Literal ID="litRefurbishedNote" runat="server" />
                                            </div>
                                        </asp:PlaceHolder>

                                        <div class="infor-bottom">
                                            <h6 class="fw-semibold">In breve</h6>
                                            <ul class="product-about-list">
                                                <asp:Literal ID="litShortDesc" runat="server" />
                                            </ul>
                                        </div>
                                    </div>

                                    <div class="tf-product-info-choose-option sticky-top ks-product-buy">
                                        <div class="product-delivery">
                                            <div class="price-text fw-medium text-primary ks-product-price">
                                                <asp:Literal ID="litPriceHtml2" runat="server" />
                                            </div>
                                            <p>
                                                <i class="icon-delivery-2"></i>
                                                <asp:Literal ID="litBuyBoxAvailability" runat="server" />
                                            </p>
                                            <div class="shipping-to">
                                                <p class="body-md-2">Riferimenti</p>
                                                <div class="body-text-3">
                                                    <span>Codice: <asp:Literal ID="litCodice2" runat="server" /></span>
                                                    <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                                        <span>EAN: <asp:Literal ID="litEan2" runat="server" /></span>
                                                    </asp:PlaceHolder>
                                                    <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                                        <span>Marca: <asp:Literal ID="litMarca2" runat="server" /></span>
                                                    </asp:PlaceHolder>
                                                </div>
                                            </div>
                                        </div>

                                        <asp:Panel ID="pnlVariants" runat="server" Visible="false" CssClass="product-color">
                                            <p class="title body-text-3">Variante</p>
                                            <div class="tf-select-color">
                                                <asp:DropDownList ID="ddlTc" runat="server" CssClass="select-color" AutoPostBack="true" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                            </div>
                                        </asp:Panel>

                                        <div class="product-quantity">
                                            <p class="title body-text-3">Quantita</p>
                                            <div class="wg-quantity ks-qty-stepper">
                                                <button class="btn-quantity btn-decrease" type="button" data-ks-qty="minus">
                                                    <i class="icon-minus"></i>
                                                </button>
                                                <asp:TextBox ID="txtQty" runat="server" CssClass="quantity-product" Text="1" />
                                                <button class="btn-quantity btn-increase" type="button" data-ks-qty="plus">
                                                    <i class="icon-plus"></i>
                                                </button>
                                            </div>
                                            <div class="small text-danger mt-1">
                                                <asp:Literal ID="litQtyHelp" runat="server" />
                                            </div>
                                        </div>

                                        <div class="product-box-btn">
                                            <asp:LinkButton ID="btnAddToCart" runat="server" CssClass="tf-btn text-white" OnClick="btnAddToCart_Click" CausesValidation="false">
                                                <span>Aggiungi al carrello</span>
                                                <i class="icon-cart-2"></i>
                                            </asp:LinkButton>
                                            <a class="tf-btn text-white btn-gray" href="/carrello.aspx">Vai al carrello</a>
                                        </div>

                                        <div class="product-detail">
                                            <p class="caption">Acquisto</p>
                                            <p class="body-text-3">
                                                <span>Prezzi e disponibilita sono calcolati con il listino corrente.</span>
                                                <span>Puoi modificare la quantita prima di aggiungere il prodotto al carrello.</span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section class="tf-sp-4">
            <div class="container">
                <div class="flat-animate-tab flat-title-tab-product-des">
                    <div class="flat-title-tab text-center">
                        <ul class="menu-tab-line" role="tablist">
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-usually" class="tab-link product-title fw-semibold active" data-bs-toggle="tab" role="tab">Spesso acquistati insieme</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-des" class="tab-link product-title fw-semibold" data-bs-toggle="tab" role="tab">Descrizione</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-infor" class="tab-link product-title fw-semibold" data-bs-toggle="tab" role="tab">Informazioni prodotto</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-review" class="tab-link product-title fw-semibold" data-bs-toggle="tab" role="tab">Recensioni</a>
                            </li>
                        </ul>
                    </div>

                    <div class="tab-content">
                        <div class="tab-pane active show" id="prd-usually" role="tabpanel">
                            <div class="tab-main tab-usually flex-md-wrap">
                                <asp:Repeater ID="rptBundle" runat="server">
                                    <ItemTemplate>
                                        <div class="card-usually hover-img">
                                            <a href='<%# Eval("Url") %>' class="image img-style">
                                                <img src='<%# Eval("Img") %>' data-src='<%# Eval("Img") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>' class="lazyload" />
                                            </a>
                                            <div class="content">
                                                <div class="checkbox-item-wrap">
                                                    <label>
                                                        <input type="checkbox" class="checkbox-item" checked="checked" disabled="disabled" />
                                                        <span class="btn-checkbox"></span>
                                                    </label>
                                                </div>
                                                <div class="box-name">
                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %></p>
                                                    <a href='<%# Eval("Url") %>' class="prd-name body-md-2 text-main link-secondary fw-semibold">
                                                        <%# If(Convert.ToBoolean(Eval("IsCurrent")), "Questo articolo: ", String.Empty) & Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 88)) %>
                                                    </a>
                                                    <p class="price-text fw-medium"><%# Eval("PrezzoHtml") %></p>
                                                </div>
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                    <SeparatorTemplate>
                                        <span class="icon"><i class="icon-plus fs-28"></i></span>
                                    </SeparatorTemplate>
                                </asp:Repeater>
                                <asp:PlaceHolder ID="phBundleEmpty" runat="server" Visible="false">
                                    <p class="body-text-3 text-main-2">Non ci sono ancora articoli abbinabili per questo prodotto.</p>
                                </asp:PlaceHolder>
                                <div class="box-total-btn">
                                    <p class="body-text-3 text-center">Totale selezione: <span class="text-primary"><asp:Literal ID="litBundleTotal" runat="server" /></span></p>
                                    <asp:LinkButton ID="btnBundleAddToCart" runat="server" CssClass="tf-btn btn-line" OnClick="btnBundleAddToCart_Click" CausesValidation="false">
                                        Aggiungi al carrello
                                        <i class="icon-cart-2"></i>
                                    </asp:LinkButton>
                                </div>
                            </div>
                        </div>

                        <div class="tab-pane" id="prd-des" role="tabpanel">
                            <div class="tab-main tab-des ks-product-description">
                                <asp:Literal ID="litLongDesc" runat="server" />
                            </div>
                        </div>

                        <div class="tab-pane" id="prd-infor" role="tabpanel">
                            <div class="tab-main tab-info">
                                <ul class="list-feature">
                                    <asp:PlaceHolder ID="phCategoryInfo" runat="server" Visible="false">
                                        <li>
                                            <p class="name-feature">Categoria</p>
                                            <p class="property"><asp:Literal ID="litCategoryInfo" runat="server" /></p>
                                        </li>
                                    </asp:PlaceHolder>
                                    <asp:PlaceHolder ID="phBrandInfo" runat="server" Visible="false">
                                        <li>
                                            <p class="name-feature">Marca</p>
                                            <p class="property"><asp:Literal ID="litMarcaInfo" runat="server" /></p>
                                        </li>
                                    </asp:PlaceHolder>
                                    <li>
                                        <p class="name-feature">Codice</p>
                                        <p class="property"><asp:Literal ID="litCodice4" runat="server" /></p>
                                    </li>
                                    <asp:PlaceHolder ID="phEanInfo" runat="server" Visible="false">
                                        <li>
                                            <p class="name-feature">EAN</p>
                                            <p class="property"><asp:Literal ID="litEan4" runat="server" /></p>
                                        </li>
                                    </asp:PlaceHolder>
                                    <asp:PlaceHolder ID="phAvailabilityInfo" runat="server" Visible="false">
                                        <li>
                                            <p class="name-feature">Disponibilita</p>
                                            <p class="property"><asp:Literal ID="litAvailabilityInfo" runat="server" /></p>
                                        </li>
                                    </asp:PlaceHolder>
                                    <li>
                                        <p class="name-feature">Prezzo</p>
                                        <p class="property"><asp:Literal ID="litPriceInfo" runat="server" /></p>
                                    </li>
                                    <li>
                                        <p class="name-feature">IVA</p>
                                        <p class="property"><asp:Literal ID="litIvaInfo" runat="server" /></p>
                                    </li>
                                </ul>
                            </div>
                        </div>

                        <div class="tab-pane" id="prd-review" role="tabpanel">
                            <div class="ks-review-widget">
                            <div class="tab-main tab-review flex-lg-nowrap">
                                <div class="tab-rating-wrap">
                                    <div class="rating-percent">
                                        <p class="rate-percent"><asp:Literal ID="litReviewAverage" runat="server" Text="0" /> <span>/ 5</span></p>
                                        <ul class="list-star justify-content-center">
                                            <li><i class="icon-star text-main-4"></i></li>
                                            <li><i class="icon-star text-main-4"></i></li>
                                            <li><i class="icon-star text-main-4"></i></li>
                                            <li><i class="icon-star text-main-4"></i></li>
                                            <li><i class="icon-star text-main-4"></i></li>
                                        </ul>
                                        <p class="text-cl-3"><asp:Literal ID="litReviewCountText" runat="server" Text="Ancora nessuna valutazione." /></p>
                                    </div>
                                    <ul class="rating-progress-list">
                                        <asp:Literal ID="litReviewDistribution" runat="server" />
                                    </ul>
                                </div>
                                <div class="tab-review-wrap">
                                    <div class="review-list-wrap">
                                        <asp:Literal ID="litReviewMessage" runat="server" EnableViewState="false" />
                                        <asp:PlaceHolder ID="phReviewEmpty" runat="server" Visible="false">
                                            <div class="alert alert-light mb-3">
                                                Non ci sono ancora recensioni per questo prodotto. Puoi essere il primo a lasciare una valutazione utile agli altri clienti.
                                            </div>
                                        </asp:PlaceHolder>
                                        <asp:Repeater ID="rptProductReviews" runat="server">
                                            <ItemTemplate>
                                                <div class="ks-review-item">
                                                    <div class="d-flex align-items-center justify-content-between gap-2 flex-wrap mb-1">
                                                        <div class="d-flex align-items-center gap-2">
                                                            <strong><%# Eval("RatingText") %></strong>
                                                            <ul class="list-star ks-review-stars mb-0"><%# Eval("StarsHtml") %></ul>
                                                        </div>
                                                        <span class="caption text-main-2"><%# Eval("DateText") %></span>
                                                    </div>
                                                    <p class="body-md-2 fw-semibold mb-1"><%# Eval("TitleText") %></p>
                                                    <p class="body-text-3 mb-1"><%# Eval("BodyText") %></p>
                                                    <p class="caption text-main-2 mb-0">
                                                        <%# Eval("AuthorText") %>
                                                        <%# If(Convert.ToBoolean(Eval("Verified")), " - Acquisto verificato", String.Empty) %>
                                                    </p>
                                                </div>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                        <div class="reply-comment style-1 ks-review-form-wrap">
                                            <h6 class="mb-2">Lascia una recensione</h6>
                                            <p class="body-text-3 text-main-2 mb-3">La recensione viene salvata su KeepStore, verificata con controlli anti-spam e pubblicata nella scheda prodotto.</p>
                                            <div class="ks-review-form">
                                                <label class="body-text-3 fw-semibold" for="<%= ddlReviewRating.ClientID %>">Valutazione</label>
                                                <asp:DropDownList ID="ddlReviewRating" runat="server" CssClass="form-select">
                                                    <asp:ListItem Value="5" Text="5 stelle" />
                                                    <asp:ListItem Value="4" Text="4 stelle" />
                                                    <asp:ListItem Value="3" Text="3 stelle" />
                                                    <asp:ListItem Value="2" Text="2 stelle" />
                                                    <asp:ListItem Value="1" Text="1 stella" />
                                                </asp:DropDownList>
                                                <label class="body-text-3 fw-semibold" for="<%= txtReviewName.ClientID %>">Nome</label>
                                                <asp:TextBox ID="txtReviewName" runat="server" CssClass="form-control" MaxLength="120" placeholder="Il tuo nome" />
                                                <label class="body-text-3 fw-semibold" for="<%= txtReviewEmail.ClientID %>">Email</label>
                                                <asp:TextBox ID="txtReviewEmail" runat="server" CssClass="form-control" MaxLength="180" TextMode="Email" placeholder="Email non visibile pubblicamente" />
                                                <label class="body-text-3 fw-semibold" for="<%= txtReviewTitle.ClientID %>">Titolo</label>
                                                <asp:TextBox ID="txtReviewTitle" runat="server" CssClass="form-control" MaxLength="160" placeholder="Sintesi della recensione" />
                                                <label class="body-text-3 fw-semibold" for="<%= txtReviewText.ClientID %>">Commento</label>
                                                <asp:TextBox ID="txtReviewText" runat="server" CssClass="form-control" TextMode="MultiLine" Rows="4" MaxLength="1000" placeholder="Scrivi una nota utile sul prodotto" />
                                                <asp:LinkButton ID="btnReviewSubmit" runat="server" CssClass="tf-btn btn-line" OnClick="btnReviewSubmit_Click" CausesValidation="false">
                                                    <span>Salva recensione</span>
                                                </asp:LinkButton>
                                            </div>
                                            <a class="link text-secondary d-inline-flex mt-3" href="Contattaci.aspx">Hai dubbi prima dell'acquisto? Contatta l'assistenza</a>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </asp:Panel>

    <asp:PlaceHolder ID="phSimilar" runat="server" Visible="false">
        <section class="tf-sp-2 pt-0 ks-product-relation-section">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Scopri articoli simili</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>

                <div class="swiper tf-sw-products ks-product-relation-swiper" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                    <asp:Repeater ID="rptSimilar" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                            <div class="card-product style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                        <img class="lazyload img-hover"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("ImgHover") %>'
                                             src='<%# Eval("ImgHover") %>' />
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href='<%# Eval("AddToCartUrl") %>' class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left js-ks-cart-link" aria-label="Aggiungi al carrello">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Aggiungi al carrello</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href='<%# Eval("WishlistUrl") %>' class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link" aria-label="Aggiungi a wishlist">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal" class="box-icon quickview btn-icon-action hover-tooltip tooltip-left js-ks-quickview" <%# Eval("QuickViewAttrs") %> aria-label="Vista rapida">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Vista rapida</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare" <%# Eval("CompareAttrs") %> aria-label="Confronta">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Confronta</span>
                                            </a>
                                        </li>
                                    </ul>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %></p>
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>

                                    <div class="card-product-btn">
                                        <a class="tf-btn btn-line w-100" href='<%# Eval("Url") %>'>
                                            <span>Vedi prodotto</span>
                                            <i class="icon-view"></i>
                                        </a>
                                    </div>
                                </div>
                            </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                    </div>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
        <section class="tf-sp-2 pt-0 ks-product-relation-section">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Prodotti correlati a questo articolo</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>

                <div class="swiper tf-sw-products ks-product-relation-swiper" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                    <asp:Repeater ID="rptRelated" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                            <div class="card-product style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                        <img class="lazyload img-hover"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("ImgHover") %>'
                                             src='<%# Eval("ImgHover") %>' />
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href='<%# Eval("AddToCartUrl") %>' class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left js-ks-cart-link" aria-label="Aggiungi al carrello">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Aggiungi al carrello</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href='<%# Eval("WishlistUrl") %>' class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link" aria-label="Aggiungi a wishlist">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal" class="box-icon quickview btn-icon-action hover-tooltip tooltip-left js-ks-quickview" <%# Eval("QuickViewAttrs") %> aria-label="Vista rapida">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Vista rapida</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare" <%# Eval("CompareAttrs") %> aria-label="Confronta">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Confronta</span>
                                            </a>
                                        </li>
                                    </ul>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %></p>
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>

                                    <div class="card-product-btn">
                                        <a class="tf-btn btn-line w-100" href='<%# Eval("Url") %>'>
                                            <span>Vedi prodotto</span>
                                            <i class="icon-view"></i>
                                        </a>
                                    </div>
                                </div>
                            </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                    </div>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phBrands" runat="server" Visible="false">
        <div class="themesFlat ks-brand-strip">
            <div class="container">
                <div class="line-bt line-tp">
                    <div class="infiniteslide tf-brand">
                        <asp:Repeater ID="rptBrands" runat="server">
                            <ItemTemplate>
                                <div class="brand-item">
                                    <a href='<%# Eval("Url") %>' class="link">
                                        <%# Eval("LogoHtml") %>
                                    </a>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>
            </div>
        </div>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phRecentlyViewed" runat="server" Visible="false">
        <section class="tf-sp-2 ks-product-relation-section ks-product-recent-section">
            <div class="container">
                <div class="flat-title">
                    <h5 class="fw-semibold">Visti di recente</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>

                <div class="swiper tf-sw-products ks-product-relation-swiper" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                    <div class="swiper-wrapper">
                    <asp:Repeater ID="rptRecentlyViewed" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                            <div class="card-product style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                        <img class="lazyload img-hover"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("ImgHover") %>'
                                             src='<%# Eval("ImgHover") %>' />
                                    </a>
                                    <ul class="list-product-btn">
                                        <li>
                                            <a href='<%# Eval("AddToCartUrl") %>' class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left js-ks-cart-link" aria-label="Aggiungi al carrello">
                                                <span class="icon icon-cart2"></span>
                                                <span class="tooltip">Aggiungi al carrello</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block wishlist">
                                            <a href='<%# Eval("WishlistUrl") %>' class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link" aria-label="Aggiungi a wishlist">
                                                <span class="icon icon-heart2"></span>
                                                <span class="tooltip">Wishlist</span>
                                            </a>
                                        </li>
                                        <li>
                                            <a href="#quickView" data-bs-toggle="modal" class="box-icon quickview btn-icon-action hover-tooltip tooltip-left js-ks-quickview" <%# Eval("QuickViewAttrs") %> aria-label="Vista rapida">
                                                <span class="icon icon-view"></span>
                                                <span class="tooltip">Vista rapida</span>
                                            </a>
                                        </li>
                                        <li class="d-none d-sm-block">
                                            <a href="#compare" data-bs-toggle="offcanvas" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare" <%# Eval("CompareAttrs") %> aria-label="Confronta">
                                                <span class="icon icon-compare1"></span>
                                                <span class="tooltip">Confronta</span>
                                            </a>
                                        </li>
                                    </ul>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(Convert.ToString(Eval("CategoryName"))) %></p>
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                    </div>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <section class="tf-sp-2 pt-0 ks-product-iconbox-section">
        <div class="container">
            <div class="swiper tf-sw-iconbox" data-preview="5" data-tablet="3.5" data-mobile-sm="2.5" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="15" data-pagination="1" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="4">
                <div class="swiper-wrapper">
                    <div class="swiper-slide">
                        <div class="tf-icon-box">
                            <div class="icon-box"><i class="icon icon-delivery"></i></div>
                            <div class="content">
                                <p class="body-text fw-semibold">Spedizione</p>
                                <p class="body-text-3">Consegna e ritiro secondo disponibilita.</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box">
                            <div class="icon-box"><i class="icon icon-check-2"></i></div>
                            <div class="content">
                                <p class="body-text fw-semibold">Supporto clienti</p>
                                <p class="body-text-3">Assistenza prima e dopo l'acquisto.</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box">
                            <div class="icon-box"><i class="icon icon-money-bag"></i></div>
                            <div class="content">
                                <p class="body-text fw-semibold">Pagamenti</p>
                                <p class="body-text-3">Flusso ecommerce KeepStore sicuro.</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box">
                            <div class="icon-box"><i class="icon icon-shield"></i></div>
                            <div class="content">
                                <p class="body-text fw-semibold">Affidabilita</p>
                                <p class="body-text-3">Disponibilita e listini aggiornati.</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box">
                            <div class="icon-box"><i class="icon icon-accept"></i></div>
                            <div class="content">
                                <p class="body-text fw-semibold">Garanzia</p>
                                <p class="body-text-3">Prodotti gestiti dal flusso negozio.</p>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="sw-pagination-iconbox sw-dot-default justify-content-center"></div>
            </div>
        </div>
    </section>

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/product-ui.js") %>" defer></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-recently-viewed.js") %>"></script>
    <asp:Literal ID="litRecentlyViewedScript" runat="server" EnableViewState="false" />
</asp:Content>
