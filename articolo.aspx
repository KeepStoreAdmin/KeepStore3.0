<%@ Page Title="Prodotto" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    <%= If(litNome IsNot Nothing AndAlso Not String.IsNullOrEmpty(litNome.Text), Server.HtmlEncode(litNome.Text), "Prodotto") %>
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />

    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/drift-basic.min.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/photoswipe.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/product-ui.css") %>" />

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

    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="alert alert-warning">Prodotto non trovato o non disponibile.</div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:Panel ID="pnlProduct" runat="server" CssClass="ks-product-page">
        <section class="tf-sp-2">
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
                                                <a href="/articoli.aspx" class="link text-secondary">Catalogo</a>
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
                                            </ul>
                                        </div>

                                        <div class="infor-center">
                                            <div class="product-info-price ks-product-price">
                                                <asp:Literal ID="litPriceHtml" runat="server" />
                                            </div>

                                            <ul class="product-fearture-list">
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
                                            <div class="product-about-list">
                                                <asp:Literal ID="litShortDesc" runat="server" />
                                            </div>
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
                                            <div class="wg-quantity">
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
                                            <asp:Button ID="btnAddToCart" runat="server" CssClass="tf-btn text-white" Text="Aggiungi al carrello" OnClick="btnAddToCart_Click" />
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
                                <a href="#prd-des" class="tab-link product-title fw-semibold active" data-bs-toggle="tab" role="tab">Descrizione</a>
                            </li>
                            <li class="nav-tab-item" role="presentation">
                                <a href="#prd-infor" class="tab-link product-title fw-semibold" data-bs-toggle="tab" role="tab">Informazioni</a>
                            </li>
                        </ul>
                    </div>

                    <div class="tab-content">
                        <div class="tab-pane active show" id="prd-des" role="tabpanel">
                            <div class="tab-main tab-des ks-product-description">
                                <asp:Literal ID="litLongDesc" runat="server" />
                            </div>
                        </div>

                        <div class="tab-pane" id="prd-infor" role="tabpanel">
                            <div class="tab-main tab-info">
                                <ul class="list-feature">
                                    <li>
                                        <p class="name-feature">Codice</p>
                                        <p class="property"><asp:Literal ID="litCodice4" runat="server" /></p>
                                    </li>
                                    <li>
                                        <p class="name-feature">EAN</p>
                                        <p class="property"><asp:Literal ID="litEan4" runat="server" /></p>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </asp:Panel>

    <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
        <section class="flat-spacing-2 ks-product-relation-section">
            <div class="container">
                <div class="tf-section-heading">
                    <h3 class="heading">Prodotti correlati</h3>
                </div>

                <div class="tf-grid-layout md-col-4 sm-col-2">
                    <asp:Repeater ID="rptRelated" runat="server">
                        <ItemTemplate>
                            <div class="card-product style-1 style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                    </a>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>

                                    <div class="box-infor-detail">
                                        <ul class="list-infor-fearture">
                                            <li>
                                                <p class="caption name-feature">Codice:</p>
                                                <p class="caption property"><%# If(String.IsNullOrEmpty(Convert.ToString(Eval("Codice"))), "-", Server.HtmlEncode(Convert.ToString(Eval("Codice")))) %></p>
                                            </li>
                                            <li>
                                                <p class="caption name-feature">Disponibilita:</p>
                                                <p class="caption property text-secondary"><%# Server.HtmlEncode(Convert.ToString(Eval("AvailabilityText"))) %></p>
                                            </li>
                                        </ul>
                                    </div>

                                    <div class="card-product-btn">
                                        <a class="tf-btn btn-line w-100" href='<%# Eval("Url") %>'>
                                            <span>Vedi prodotto</span>
                                            <i class="icon-view"></i>
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phCompatible" runat="server" Visible="false">
        <section class="flat-spacing-2 ks-product-relation-section">
            <div class="container">
                <div class="tf-section-heading">
                    <h3 class="heading">Compatibili con questo articolo</h3>
                </div>

                <div class="tf-grid-layout md-col-4 sm-col-2">
                    <asp:Repeater ID="rptCompatible" runat="server">
                        <ItemTemplate>
                            <div class="card-product style-1 style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                    </a>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>

                                    <div class="box-infor-detail">
                                        <ul class="list-infor-fearture">
                                            <li>
                                                <p class="caption name-feature">Codice:</p>
                                                <p class="caption property"><%# If(String.IsNullOrEmpty(Convert.ToString(Eval("Codice"))), "-", Server.HtmlEncode(Convert.ToString(Eval("Codice")))) %></p>
                                            </li>
                                            <li>
                                                <p class="caption name-feature">Disponibilita:</p>
                                                <p class="caption property text-secondary"><%# Server.HtmlEncode(Convert.ToString(Eval("AvailabilityText"))) %></p>
                                            </li>
                                        </ul>
                                    </div>

                                    <div class="card-product-btn">
                                        <a class="tf-btn btn-line w-100" href='<%# Eval("Url") %>'>
                                            <span>Vedi prodotto</span>
                                            <i class="icon-view"></i>
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <asp:PlaceHolder ID="phLinked" runat="server" Visible="false">
        <section class="flat-spacing-2 ks-product-relation-section">
            <div class="container">
                <div class="tf-section-heading">
                    <h3 class="heading">Articoli collegati</h3>
                </div>

                <div class="tf-grid-layout md-col-4 sm-col-2">
                    <asp:Repeater ID="rptLinked" runat="server">
                        <ItemTemplate>
                            <div class="card-product style-1 style-img-border">
                                <div class="card-product-wrapper">
                                    <a class="product-img ks-product-card-image" href='<%# Eval("Url") %>'>
                                        <img class="lazyload img-product"
                                             alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>'
                                             data-src='<%# Eval("Img") %>'
                                             src='<%# Eval("Img") %>' />
                                    </a>

                                    <%# If(Convert.ToBoolean(Eval("InOfferta")), "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", String.Empty) %>
                                </div>

                                <div class="card-product-info">
                                    <div class="box-title">
                                        <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Nome")), 70)) %>
                                        </a>

                                        <div class="price-wrap fw-medium">
                                            <%# Eval("PrezzoHtml") %>
                                        </div>
                                    </div>

                                    <div class="box-infor-detail">
                                        <ul class="list-infor-fearture">
                                            <li>
                                                <p class="caption name-feature">Codice:</p>
                                                <p class="caption property"><%# If(String.IsNullOrEmpty(Convert.ToString(Eval("Codice"))), "-", Server.HtmlEncode(Convert.ToString(Eval("Codice")))) %></p>
                                            </li>
                                            <li>
                                                <p class="caption name-feature">Disponibilita:</p>
                                                <p class="caption property text-secondary"><%# Server.HtmlEncode(Convert.ToString(Eval("AvailabilityText"))) %></p>
                                            </li>
                                        </ul>
                                    </div>

                                    <div class="card-product-btn">
                                        <a class="tf-btn btn-line w-100" href='<%# Eval("Url") %>'>
                                            <span>Vedi prodotto</span>
                                            <i class="icon-view"></i>
                                        </a>
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
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>"></script>
</asp:Content>
