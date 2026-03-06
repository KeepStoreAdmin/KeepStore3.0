<%@ Page Language="VB" AutoEventWireup="false" MasterPageFile="~/Page.master" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="uc" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagPrefix="uc" TagName="HomeHeroSlider" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanners.ascx" TagPrefix="uc" TagName="HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="uc" TagName="HomeIconBoxes" %>

<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
    <%-- SEO head (canonical, meta robots, etc) injected from code-behind if needed --%>
    <asp:Literal ID="litSeoHead" runat="server" />
</asp:Content>

<asp:Content ID="ContentBreadcrumb" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <%-- Home: breadcrumb hidden by design --%>
</asp:Content>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Hero / Departments + Slider + Side banners -->
    <div class="tf-slideshow slider-effect-fade position-relative">
        <div class="container">
            <div class="row">
                <div class="col-xl-3 col-md-4 col-12">
                    <uc:HomeDepartmentsMenu runat="server" ID="HomeDepartmentsMenu" />
                </div>
                <div class="col-xl-6 col-md-8 col-12">
                    <uc:HomeHeroSlider runat="server" ID="HomeHeroSlider" />
                </div>
                <div class="col-xl-3 col-md-12 col-12">
                    <uc:HomeSideBanners runat="server" ID="HomeSideBanners" />
                </div>
            </div>
        </div>
    </div>

    <!-- Icon Boxes -->
    <uc:HomeIconBoxes runat="server" ID="HomeIconBoxes" />

    <!-- Deal Of The Day (Occasione Imperdibile) -->
    <section class="tf-sp-2">
        <div class="container">
            <div class="flat-title style1">
                <h4 class="fl-title"><span class="icon"><i class="icon-fire tf-md text_primary"></i></span><span>Occasione Imperdibile</span></h4>
                <div class="swiper tf-sw-products-2 sw-wrapper" data-preview="4" data-tablet="3" data-mobile-sm="2" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="15" data-loop="false" data-auto-play="false" data-delay="0" data-speed="1000">
                    <div class="swiper-wrapper">

                        <asp:Repeater ID="rptDealOfDay" runat="server" DataSourceID="sdsDealOfDay">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <div class="card-product style-border">

                                        <div class="card-product-wrapper">

                                            <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                <img class="lazyload img-product"
                                                     alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                                     src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                <img class="lazyload img-hover"
                                                     alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                                     src='<%# GetProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                            </a>

                                            <div class="on-sale-wrap">
                                                <asp:Literal ID="litDealDiscount" runat="server"
                                                    Text='<%# RenderDiscountBadge(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta")) %>' />
                                            </div>

                                            <div class="list-product-btn absolute-2">
                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="box-icon bg_white compare tooltip">
                                                    <span class="icon icon-eye"></span>
                                                    <span class="tooltip">Vedi</span>
                                                </a>
                                            </div>

                                        </div>

                                        <div class="card-product-info">

                                            <div class="inner-info">
                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product link">
                                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                                </a>
                                                <div class="price-wrap fw-medium mt-1">
                                                    <%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %>
                                                </div>
                                            </div>

                                            <div class="box-count-down">
                                                <div class="js-countdown"
                                                     data-timer='<%# GetCountdownSeconds(Eval("OfferteDataFine")) %>'
                                                     data-labels="Giorni,Ore,Min,Sec">
                                                </div>
                                            </div>

                                            <div class="box-progress-stock">
                                                <div class="stock-status d-flex justify-content-between align-items-center">
                                                    <div class="stock-item text-caption-1 text-secondary">
                                                        Venduti: <span class="fw-semibold text-black"><%# GetSoldQty(Eval("Impegnata")) %></span>
                                                    </div>
                                                    <div class="stock-item text-caption-1 text-secondary">
                                                        Disponibili: <span class="fw-semibold text-black"><%# GetAvailableQty(Eval("Disponibilita")) %></span>
                                                    </div>
                                                </div>
                                                <div class="progress" role="progressbar" aria-label="Sold" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">
                                                    <div class="progress-bar bg_primary" style='<%# "width:" & GetSoldPercent(Eval("Impegnata"), Eval("Disponibilita")) & "%;" %>'></div>
                                                </div>
                                            </div>

                                            <ul class="list-image-product">
                                                <li class="list-image-item">
                                                    <img alt="thumb" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                </li>
                                                <li class="list-image-item">
                                                    <img alt="thumb" src='<%# GetProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                </li>
                                                <li class="list-image-item">
                                                    <img alt="thumb" src='<%# GetProductImage(Eval("Img3"), Eval("Img1")) %>' />
                                                </li>
                                                <li class="list-image-item">
                                                    <img alt="thumb" src='<%# GetProductImage(Eval("Img4"), Eval("Img1")) %>' />
                                                </li>
                                            </ul>

                                        </div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>

                    </div>
                </div>
                <div class="box-sw-navigation">
                    <div class="sw-dots sw-pagination-products justify-content-center"></div>
                </div>
                <div class="nav-sw nav-next-products"><span class="icon icon-arrow1-right"></span></div>
                <div class="nav-sw nav-prev-products"><span class="icon icon-arrow1-left"></span></div>
            </div>
        </div>
    </section>

    <!-- Banner centrale -->
    <section class="tf-sp-2 pt-0">
        <div class="container">
            <div class="banner-image-product bg-image" data-bg-img="<%= ThemeManager.Asset("images/banner/banner-1.jpg") %>">
                <div class="item">
                    <div class="content text-center">
                        <h5>Offerte della settimana</h5>
                        <p class="body-text">Selezione di prodotti in promozione</p>
                        <a href="articoli.aspx" class="tf-btn btn-line-primary">Scopri ora <i class="icon icon-arrow1-top-left"></i></a>
                    </div>
                    <div class="box-price">
                        <p>Da</p>
                        <h3>€<span>9</span></h3>
                    </div>
                </div>
                <div class="item">
                    <div class="image">
                        <img class="lazyload" alt="banner" src="<%= ThemeManager.Asset("images/banner/tivi.webp") %>">
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Feature / Toprate / On Sale tabs (template area) -->
    <section class="tf-sp-2 pt-0">
        <div class="container">
            <div class="grid-collection">
                <div class="grid-cls grid-cls-v2">
                    <div class="grid-item1">
                        <div class="tab-product">
                            <ul class="nav-tab justify-content-start" role="tablist">
                                <li class="nav-tab-item" role="presentation">
                                    <a href="#homeTabFeature" class="active" data-bs-toggle="tab">Feature</a>
                                </li>
                                <li class="nav-tab-item" role="presentation">
                                    <a href="#homeTabToprate" data-bs-toggle="tab">Toprate</a>
                                </li>
                                <li class="nav-tab-item" role="presentation">
                                    <a href="#homeTabOnSale" data-bs-toggle="tab">On Sale</a>
                                </li>
                            </ul>
                            <div class="tab-content">
                                <!-- Feature -->
                                <div class="tab-pane active show" id="homeTabFeature" role="tabpanel">
                                    <div class="grid-cls grid-cls-v2">
                                        <div class="grid-item1">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptFeatureLeft" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                                    <img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>

                                        <div class="grid-item2">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptFeatureCenter" runat="server">
                                                    <ItemTemplate>
                                                        <div class="card-product style-row style-row-v2">
                                                            <div class="thumb-image">
                                                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                                <div class="on-sale-wrap">
                                                                    <asp:Literal ID="litCenterDiscount" runat="server"
                                                                        Text='<%# RenderDiscountBadge(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta")) %>' />
                                                                </div>
                                                                <div class="list-product-btn absolute-2">
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="box-icon bg_white compare tooltip">
                                                                        <span class="icon icon-eye"></span>
                                                                        <span class="tooltip">Vedi</span>
                                                                    </a>
                                                                </div>
                                                            </div>
                                                            <div class="card-product-info">
                                                                <div class="box-title">
                                                                    <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                                </div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                                <div class="box-count-down">
                                                                    <div class="js-countdown" data-timer='<%# GetCountdownSeconds(Eval("OfferteDataFine")) %>' data-labels="Giorni,Ore,Min,Sec"></div>
                                                                </div>
                                                                <div class="box-progress-stock">
                                                                    <div class="stock-status d-flex justify-content-between align-items-center">
                                                                        <div class="stock-item text-caption-1 text-secondary">Venduti: <span class="fw-semibold text-black"><%# GetSoldQty(Eval("Impegnata")) %></span></div>
                                                                        <div class="stock-item text-caption-1 text-secondary">Disponibili: <span class="fw-semibold text-black"><%# GetAvailableQty(Eval("Disponibilita")) %></span></div>
                                                                    </div>
                                                                    <div class="progress" role="progressbar" aria-label="Sold" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">
                                                                        <div class="progress-bar bg_primary" style='<%# "width:" & GetSoldPercent(Eval("Impegnata"), Eval("Disponibilita")) & "%;" %>'></div>
                                                                    </div>
                                                                </div>
                                                                <div class="button-link">
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="tf-btn btn-gray"><span class="text">Scopri</span><i class="icon icon-arrow1-top-left"></i></a>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>

                                        <div class="grid-item3">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptFeatureRight" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                                    <img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Toprate -->
                                <div class="tab-pane" id="homeTabToprate" role="tabpanel">
                                    <div class="grid-cls grid-cls-v2">
                                        <div class="grid-item1">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptToprateLeft" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                        <div class="grid-item2">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptToprateCenter" runat="server">
                                                    <ItemTemplate>
                                                        <div class="card-product style-row style-row-v2">
                                                            <div class="thumb-image">
                                                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="card-product-info">
                                                                <div class="box-title">
                                                                    <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                                </div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                                <div class="button-link">
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="tf-btn btn-gray"><span class="text">Scopri</span><i class="icon icon-arrow1-top-left"></i></a>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                        <div class="grid-item3">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptToprateRight" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- On Sale -->
                                <div class="tab-pane" id="homeTabOnSale" role="tabpanel">
                                    <div class="grid-cls grid-cls-v2">
                                        <div class="grid-item1">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptOnSaleLeft" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                        <div class="grid-item2">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptOnSaleCenter" runat="server">
                                                    <ItemTemplate>
                                                        <div class="card-product style-row style-row-v2">
                                                            <div class="thumb-image">
                                                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                                <div class="on-sale-wrap">
                                                                    <asp:Literal ID="litCenterDiscount2" runat="server"
                                                                        Text='<%# RenderDiscountBadge(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta")) %>' />
                                                                </div>
                                                            </div>
                                                            <div class="card-product-info">
                                                                <div class="box-title">
                                                                    <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                                </div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                                                <div class="button-link">
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="tf-btn btn-gray"><span class="text">Scopri</span><i class="icon icon-arrow1-top-left"></i></a>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </div>
                                        </div>
                                        <div class="grid-item3">
                                            <div class="list-product">
                                                <asp:Repeater ID="rptOnSaleRight" runat="server">
                                                    <ItemTemplate>
                                                        <div class="list-product-item">
                                                            <div class="image">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                                            </div>
                                                            <div class="content">
                                                                <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                                                <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a></div>
                                                                <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
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
                    </div>

                    <!-- Banners small (3) -->
                    <div class="grid-item2">
                        <div class="banner-image-product-2">
                            <a href="articoli.aspx" class="image">
                                <img class="lazyload" alt="banner" src="<%= ThemeManager.Asset("images/banner/banner-5.jpg") %>">
                            </a>
                            <div class="content">
                                <div class="text-caption-1 text-primary fw-semibold">Promo</div>
                                <h6><a href="articoli.aspx" class="link">Offerte Selezionate</a></h6>
                                <a href="articoli.aspx" class="tf-btn btn-line-primary">Shop now<i class="icon icon-arrow1-top-left"></i></a>
                            </div>
                        </div>
                        <div class="banner-image-product-2">
                            <a href="articoli.aspx" class="image">
                                <img class="lazyload" alt="banner" src="<%= ThemeManager.Asset("images/banner/banner-6.jpg") %>">
                            </a>
                            <div class="content">
                                <div class="text-caption-1 text-primary fw-semibold">Nuovi</div>
                                <h6><a href="articoli.aspx" class="link">Nuovi Arrivi</a></h6>
                                <a href="articoli.aspx" class="tf-btn btn-line-primary">Shop now<i class="icon icon-arrow1-top-left"></i></a>
                            </div>
                        </div>
                        <div class="banner-image-product-2">
                            <a href="articoli.aspx" class="image">
                                <img class="lazyload" alt="banner" src="<%= ThemeManager.Asset("images/banner/banner-7.jpg") %>">
                            </a>
                            <div class="content">
                                <div class="text-caption-1 text-primary fw-semibold">Top</div>
                                <h6><a href="articoli.aspx" class="link">I più venduti</a></h6>
                                <a href="articoli.aspx" class="tf-btn btn-line-primary">Shop now<i class="icon icon-arrow1-top-left"></i></a>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </div>
    </section>

    <!-- Best Seller (replace 'Novità') -->
    <section class="tf-sp-2 pb-0">
        <div class="container">
            <div class="flat-title">
                <h4 class="title">Best Seller</h4>
                <div class="box-sw-navigation">
                    <div class="nav-sw nav-next-products"><span class="icon icon-arrow1-right"></span></div>
                    <div class="nav-sw nav-prev-products"><span class="icon icon-arrow1-left"></span></div>
                </div>
            </div>
            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="20" data-space-md="20" data-space="15" data-loop="false" data-auto-play="false" data-delay="0" data-speed="1000" data-grid="grid-2">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptBestSeller" runat="server" DataSourceID="sdsBestSeller">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <div class="card-product">
                                    <div class="card-product-wrapper">
                                        <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                            <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                            <img class="lazyload img-hover" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                        </a>
                                        <div class="on-sale-wrap">
                                            <asp:Literal ID="litBestDiscount" runat="server"
                                                Text='<%# RenderDiscountBadge(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta")) %>' />
                                        </div>
                                        <div class="list-product-btn absolute-2">
                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="box-icon bg_white compare tooltip">
                                                <span class="icon icon-eye"></span>
                                                <span class="tooltip">Vedi</span>
                                            </a>
                                        </div>
                                    </div>
                                    <div class="card-product-info">
                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="title link">
                                            <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 55)) %>
                                        </a>
                                        <div class="price-wrap"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </div>
    </section>

    <!-- Top 20 / Featured / Top Selling / On-sale (template grid) -->
    <section class="tf-sp-2">
        <div class="container">
            <div class="grid-product-trend">
                <div class="item">
                    <div class="title-box">
                        <h5 class="title">Top 20</h5>
                        <a href="articoli.aspx" class="view-all link text-caption-1">Vedi tutto<i class="icon icon-arrow1-top-left"></i></a>
                    </div>
                    <div class="list-product">
                        <asp:Repeater ID="rptTop20" runat="server" DataSourceID="sdsTop20">
                            <ItemTemplate>
                                <div class="list-product-item">
                                    <div class="image">
                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                    </div>
                                    <div class="content">
                                        <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                        <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 44)) %></a></div>
                                        <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>

                <div class="item">
                    <div class="title-box">
                        <h5 class="title">Featured Products</h5>
                        <a href="articoli.aspx" class="view-all link text-caption-1">Vedi tutto<i class="icon icon-arrow1-top-left"></i></a>
                    </div>
                    <div class="list-product">
                        <asp:Repeater ID="rptFeaturedMini" runat="server" DataSourceID="sdsFeaturedMini">
                            <ItemTemplate>
                                <div class="list-product-item">
                                    <div class="image">
                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                    </div>
                                    <div class="content">
                                        <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                        <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 44)) %></a></div>
                                        <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>

                <div class="item">
                    <div class="title-box">
                        <h5 class="title">Top Selling Product</h5>
                        <a href="articoli.aspx" class="view-all link text-caption-1">Vedi tutto<i class="icon icon-arrow1-top-left"></i></a>
                    </div>
                    <div class="list-product">
                        <asp:Repeater ID="rptTopSellingMini" runat="server" DataSourceID="sdsTopSellingMini">
                            <ItemTemplate>
                                <div class="list-product-item">
                                    <div class="image">
                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                    </div>
                                    <div class="content">
                                        <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                        <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 44)) %></a></div>
                                        <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>

                <div class="item">
                    <div class="title-box">
                        <h5 class="title">On-sale Product</h5>
                        <a href="articoli.aspx" class="view-all link text-caption-1">Vedi tutto<i class="icon icon-arrow1-top-left"></i></a>
                    </div>
                    <div class="list-product">
                        <asp:Repeater ID="rptOnSaleMini" runat="server" DataSourceID="sdsOnSaleMini">
                            <ItemTemplate>
                                <div class="list-product-item">
                                    <div class="image">
                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><img alt="product" src='<%# GetProductImage(Eval("Img1"), Nothing) %>' /></a>
                                    </div>
                                    <div class="content">
                                        <div class="text-caption-1 text-secondary"><%# Server.HtmlEncode(GetCaption(Eval("Codice"))) %></div>
                                        <div class="name"><a class="link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 44)) %></a></div>
                                        <div class="price"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>

            </div>
        </div>
    </section>

    <!-- Recently Viewed -->
    <asp:PlaceHolder ID="phRecentlyViewed" runat="server" Visible="false">
        <section class="tf-sp-2 pt-0">
            <div class="container">
                <div class="flat-title">
                    <h4 class="title">Prodotti visualizzati di recente</h4>
                    <div class="box-sw-navigation">
                        <div class="nav-sw nav-next-products"><span class="icon icon-arrow1-right"></span></div>
                        <div class="nav-sw nav-prev-products"><span class="icon icon-arrow1-left"></span></div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="20" data-space-md="20" data-space="15" data-loop="false" data-auto-play="false" data-delay="0" data-speed="1000">
                    <div class="swiper-wrapper">
                        <asp:Repeater ID="rptRecentlyViewed" runat="server" DataSourceID="sdsRecentlyViewed">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <div class="card-product">
                                        <div class="card-product-wrapper">
                                            <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                                <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img1"), Nothing) %>' />
                                                <img class="lazyload img-hover" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                            </a>
                                            <div class="on-sale-wrap">
                                                <asp:Literal ID="litRecentDiscount" runat="server"
                                                    Text='<%# RenderDiscountBadge(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta")) %>' />
                                            </div>
                                        </div>
                                        <div class="card-product-info">
                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="title link">
                                                <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 55)) %>
                                            </a>
                                            <div class="price-wrap"><%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %></div>
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

    <!-- legacy/debug label (kept for compatibility with existing code) -->
    <asp:Label ID="lblPrezzi" runat="server" Visible="false" />

    <!-- DataSources -->
    <asp:SqlDataSource ID="sdsDealOfDay" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsBestSeller" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />

    <asp:SqlDataSource ID="sdsTabFeature" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsTabToprate" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsTabOnSale" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />

    <asp:SqlDataSource ID="sdsTop20" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsFeaturedMini" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsTopSellingMini" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />
    <asp:SqlDataSource ID="sdsOnSaleMini" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />

    <asp:SqlDataSource ID="sdsRecentlyViewed" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" />

</asp:Content>
