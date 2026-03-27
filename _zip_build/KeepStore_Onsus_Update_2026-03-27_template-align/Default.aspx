<%@ Page Language="VB" AutoEventWireup="false" MasterPageFile="~/Page.master" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="uc" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="uc" TagName="HomeIconBoxes" %>

<asp:Content ID="cntTitle" ContentPlaceHolderID="TitleContent" runat="server">
    KeepStore - Home
</asp:Content>

<asp:Content ID="cntMain" ContentPlaceHolderID="MainContent" runat="server">

    <section class="tf-sp-5">
        <div class="container">
            <div class="s-banner-wrapper ks-home-hero-shell">
                <div class="wrap-item-1 d-none d-lg-block">
                    <uc:HomeDepartmentsMenu ID="HomeDepartmentsMenu1" runat="server" />
                </div>

                <div class="wrap-item-2">
                    <div id="Slide_Show_Container" runat="server" class="swiper ks-home-hero-slider wow fadeInUp" data-wow-delay="0s">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptHeroSlides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <div class="banner-image-product-4 style-2 hover-img has-bg-img ks-home-hero-banner" style="background-image:url('/Public/assets/images/banner/banner-1.jpg');">
                                            <div class="content">
                                                <div class="box-title">
                                                    <div class="d-grid gap-10">
                                                        <p class="title-sidebar-2 font-5 text-white text-uppercase"><%# SafeText(Eval("Eyebrow")) %></p>
                                                        <h2 class="fw-normal">
                                                            <a href='<%# ResolveLink(Eval("LinkUrl"), ProductUrl(Eval("ProductId"))) %>' class="link font-5 text-white"><%# SafeText(Eval("Caption")) %></a>
                                                        </h2>
                                                        <p class="title-sidebar-2 font-5 text-white"><%# SafeText(Eval("Description")) %></p>
                                                    </div>
                                                </div>
                                                <div class="box-btn">
                                                    <a href='<%# ResolveLink(Eval("LinkUrl"), ProductUrl(Eval("ProductId"))) %>' class="tf-btn-icon type-2 style-white">
                                                        <i class="icon-circle-chevron-right"></i>
                                                        <span>Scopri ora</span>
                                                    </a>
                                                </div>
                                            </div>
                                            <a href='<%# ResolveLink(Eval("LinkUrl"), ProductUrl(Eval("ProductId"))) %>' class="img-style img-item overflow-visible">
                                                <img width="800" height="794" class="lazyload" src='<%# ResolveHeroSlideImage(Eval("Image"), "/Public/assets/images/item/tivi.webp") %>' data-src='<%# ResolveHeroSlideImage(Eval("Image"), "/Public/assets/images/item/tivi.webp") %>' alt='<%# SafeText(Eval("Caption")) %>' />
                                            </a>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="swiper-button-prev nav-swiper ks-hero-prev"><i class="icon-arrow-left-lg"></i></div>
                        <div class="swiper-button-next nav-swiper ks-hero-next"><i class="icon-arrow-right-lg"></i></div>
                        <div class="sw-dot-default ks-hero-pagination"></div>
                    </div>
                </div>

                <div class="wrap-item-3">
                    <div class="ks-home-side-banners d-grid gap-3">
                        <asp:Repeater ID="rptSideBanners" runat="server">
                            <ItemTemplate>
                                <div class="cls-category style-abs hover-img ks-side-promo-card wow fadeInRight" data-wow-delay="0s">
                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="img-box img-style d-block">
                                        <img class="lazyload" src='<%# ResolveAdvertisingImage(Eval("Image"), "/Public/assets/images/banner/banner-4.jpg") %>' data-src='<%# ResolveAdvertisingImage(Eval("Image"), "/Public/assets/images/banner/banner-4.jpg") %>' alt='<%# SafeText(Eval("Title")) %>' />
                                    </a>
                                    <div class="content">
                                        <div class="box-title">
                                            <p class="text-white product-title-2 text-uppercase"><%# SafeText(Eval("Badge")) %></p>
                                            <p class="text-white main-title-2 text-uppercase fw-bold"><%# SafeText(Eval("Title")) %></p>
                                            <p class="text-white product-title-2"><%# SafeText(Eval("Description")) %></p>
                                        </div>
                                        <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="tf-btn-icon style-white">
                                            <i class="icon-circle-chevron-right"></i>
                                            <span>Scopri ora</span>
                                        </a>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <uc:HomeIconBoxes ID="HomeIconBoxes1" runat="server" />

    <section class="tf-sp-2 pt-0">
        <div class="container">
            <div class="flat-title pb-8 wow fadeInUp" data-wow-delay="0s">
                <h5 class="fw-semibold text-primary flat-title-has-icon">
                    <span class="icon"><i class="icon-fire tf-ani-tada"></i></span><span data-ks-i18n="home.deal">Occasione Imperdibile</span>
                </h5>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <div class="box-btn-slide-2 sw-nav-effect">
                <div class="swiper tf-sw-products slider-thumb-deal" data-preview="4" data-tablet="3" data-mobile-sm="2" data-mobile="1" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="1" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="4">
                    <div class="swiper-wrapper">
                        <asp:Repeater ID="rptDealOfDay" runat="server">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <%# RenderDealCard(Container.DataItem) %>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                </div>
            </div>
        </div>
    </section>

    
    <section class="has-bg-img ks-home-wide-promo" style="background-image:url('/Public/assets/images/banner/banner-1.jpg'); background-size:cover; background-repeat:no-repeat;">
        <div class="container">
            <div class="banner-image-product hover-img">
                <a href="articoli.aspx" class="image img-2 img-style overflow-visible relative">
                    <img width="994" height="986" src="/Public/assets/images/item/tivi.webp" data-src="/Public/assets/images/item/tivi.webp" alt="" class="lazyload" />
                    <div class="box-sale-wrap position1">
                        <p class="small-text">Promo</p>
                        <p class="title-sidebar-2">25%</p>
                    </div>
                </a>
                <div class="content">
                    <div class="box-title">
                        <h1 class="fw-normal">
                            <a href="articoli.aspx" class="link text-white">
                                Promo Tech <br class="d-none d-xl-block" />
                                Selezione KeepStore
                            </a>
                        </h1>
                        <div class="box-price">
                            <p class="old-price style-white main-title-2 fw-light">&euro;80,00</p>
                            <h3 class="fw-semibold text-third">&euro;60,00</h3>
                        </div>
                    </div>
                    <div class="box-btn">
                        <a href="articoli.aspx" class="tf-btn-icon type-2 style-white">
                            <i class="icon-circle-chevron-right"></i>
                            <span>Scopri ora</span>
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="tf-sp-2 ks-home-collection-block">
        <div class="container">
            <div class="swiper ks-home-collection-swiper">
                <div class="swiper-wrapper">
                    <div class="swiper-slide">
                        <div class="cls-category style-abs hover-img wow fadeInLeft" data-wow-delay="0s">
                            <a href="articoli.aspx" class="img-box img-style d-block">
                                <img src="/Public/assets/images/collection/cls-category-1.webp" data-src="/Public/assets/images/collection/cls-category-1.webp" alt="" class="lazyload" />
                            </a>
                            <div class="content">
                                <div class="box-title font-2 text-white text-uppercase">
                                    <p class="product-title-2">selezione</p>
                                    <p class="main-title-2 fw-bold">audio</p>
                                    <p class="product-title-2">cuffie e accessori</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Scopri ora</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Promo</p>
                                <p class="title-sidebar-2">20%</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="cls-category style-abs hover-img wow fadeInLeft" data-wow-delay="0.1s">
                            <a href="articoli.aspx" class="img-box img-style d-block">
                                <img src="/Public/assets/images/collection/cls-category-2.webp" data-src="/Public/assets/images/collection/cls-category-2.webp" alt="" class="lazyload" />
                            </a>
                            <div class="content">
                                <div class="box-title font-2 text-white text-uppercase">
                                    <p class="product-title-2">selezione</p>
                                    <p class="main-title-2 fw-bold">foto</p>
                                    <p class="product-title-2">camere e video</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Scopri ora</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Promo</p>
                                <p class="title-sidebar-2">15%</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="cls-category style-abs hover-img wow fadeInLeft" data-wow-delay="0.2s">
                            <a href="articoli.aspx" class="img-box img-style d-block">
                                <img src="/Public/assets/images/collection/cls-category-3.jpg" data-src="/Public/assets/images/collection/cls-category-3.jpg" alt="" class="lazyload" />
                            </a>
                            <div class="content">
                                <div class="box-title font-2 text-white text-uppercase">
                                    <p class="product-title-2">selezione</p>
                                    <p class="main-title-2 fw-bold">notebook</p>
                                    <p class="product-title-2">mobilita e lavoro</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Scopri ora</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Promo</p>
                                <p class="title-sidebar-2">10%</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="cls-category style-abs hover-img wow fadeInLeft" data-wow-delay="0.3s">
                            <a href="articoli.aspx" class="img-box img-style d-block">
                                <img src="/Public/assets/images/collection/cls-category-4.webp" data-src="/Public/assets/images/collection/cls-category-4.webp" alt="" class="lazyload" />
                            </a>
                            <div class="content">
                                <div class="box-title font-2 text-white text-uppercase">
                                    <p class="product-title-2">selezione</p>
                                    <p class="main-title-2 fw-bold">gaming</p>
                                    <p class="product-title-2">console e accessori</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Scopri ora</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Promo</p>
                                <p class="title-sidebar-2">18%</p>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="sw-dot-default ks-home-collection-pagination justify-content-center"></div>
            </div>
        </div>
    </section>

    <section class="tf-sp-2 flat-animate-tab">
        <div class="container">
            <div class="flat-title">
                <div class="flat-title-tab-default">
                    <ul class="menu-tab-line" role="tablist">
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#feature" class="tab-link main-title link fw-semibold active" data-bs-toggle="tab" data-ks-i18n="home.offers">Offerte</a></li>
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#toprate" class="tab-link main-title link fw-semibold" data-bs-toggle="tab" data-ks-i18n="home.featured">In Evidenza</a></li>
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#on-sale" class="tab-link main-title link fw-semibold" data-bs-toggle="tab" data-ks-i18n="home.newArrivals">Nuovi Arrivi</a></li>
                    </ul>
                </div>
            </div>
            <div class="tab-content">
                <div class="tab-pane active show" id="feature" role="tabpanel">
                    <div class="grid-cls grid-cls-v1">
                        <div class="grid-item1"><ul class="product-list-wrap"><asp:Repeater ID="rptFeatureLeft" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                        <div class="grid-item2"><asp:Repeater ID="rptFeatureCenter" runat="server"><ItemTemplate><%# RenderBigCard(Container.DataItem) %></ItemTemplate></asp:Repeater></div>
                        <div class="grid-item3"><ul class="product-list-wrap"><asp:Repeater ID="rptFeatureRight" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                    </div>
                </div>
                <div class="tab-pane" id="toprate" role="tabpanel">
                    <div class="grid-cls grid-cls-v1">
                        <div class="grid-item1"><ul class="product-list-wrap"><asp:Repeater ID="rptToprateLeft" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                        <div class="grid-item2"><asp:Repeater ID="rptToprateCenter" runat="server"><ItemTemplate><%# RenderBigCard(Container.DataItem) %></ItemTemplate></asp:Repeater></div>
                        <div class="grid-item3"><ul class="product-list-wrap"><asp:Repeater ID="rptToprateRight" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                    </div>
                </div>
                <div class="tab-pane" id="on-sale" role="tabpanel">
                    <div class="grid-cls grid-cls-v1">
                        <div class="grid-item1"><ul class="product-list-wrap"><asp:Repeater ID="rptOnSaleLeft" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                        <div class="grid-item2"><asp:Repeater ID="rptOnSaleCenter" runat="server"><ItemTemplate><%# RenderBigCard(Container.DataItem) %></ItemTemplate></asp:Repeater></div>
                        <div class="grid-item3"><ul class="product-list-wrap"><asp:Repeater ID="rptOnSaleRight" runat="server"><ItemTemplate><li><%# RenderRowCard(Container.DataItem) %></li></ItemTemplate></asp:Repeater></ul></div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="tf-sp-2">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <h5 class="fw-semibold">Best Seller</h5>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="15" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5" data-grid="2">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptBestSeller" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <%# RenderGridCard(Container.DataItem) %>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
            </div>
        </div>
    </section>

    
    <section class="ks-home-banner-product">
        <div class="container">
            <a href="articoli.aspx" class="banner-image-product-2 hover-img d-block">
                <div class="item-image item-1 img-style overflow-visible">
                    <img src="/Public/assets/images/item/camera-2.webp" data-src="/Public/assets/images/item/camera-2.webp" alt="" class="lazyload" />
                </div>
                <div class="item-image item-2 img-style overflow-visible d-none d-lg-block">
                    <img src="/Public/assets/images/item/camera-3.webp" data-src="/Public/assets/images/item/camera-3.webp" alt="" class="lazyload" />
                </div>
                <div class="item-banner" style="background-image:url('/Public/assets/images/banner/banner-2.jpg'); background-size:cover; background-repeat:no-repeat; background-position:center;">
                    <div class="inner">
                        <h3 class="fw-normal text-white lh-lg-50 font-2">Scopri e <span class="fw-bold">risparmia</span><br />sui prodotti piu richiesti</h3>
                        <div class="box-sale-wrap type-3 relative">
                            <p class="small-text">Risparmia</p>
                            <p class="price-text-2">&euro;68,99</p>
                        </div>
                    </div>
                </div>
            </a>
        </div>
    </section>

    <section class="tf-sp-2">
        <div class="container">
            <div class="tf-grid-product">
                <div class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold">Top 20</h5>
                        <div class="box-btn-slide relative">
                            <div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div>
                            <div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div>
                        </div>
                    </div>
                    <div class="swiper ks-column-swiper">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptTop20Slides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <asp:Literal ID="litTop20SlideHtml" runat="server" Text='<%# Eval("Html") %>' />
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div>
                    </div>
                </div>

                <div class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.featured">In Evidenza</h5>
                        <div class="box-btn-slide relative">
                            <div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div>
                            <div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div>
                        </div>
                    </div>
                    <div class="swiper ks-column-swiper">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptFeaturedProductsSlides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <asp:Literal ID="litFeaturedProductsSlideHtml" runat="server" Text='<%# Eval("Html") %>' />
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div>
                    </div>
                </div>

                <div class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.topSelling">I Piu' Venduti</h5>
                        <div class="box-btn-slide relative">
                            <div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div>
                            <div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div>
                        </div>
                    </div>
                    <div class="swiper ks-column-swiper">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptTopSellingProductSlides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <asp:Literal ID="litTopSellingProductSlideHtml" runat="server" Text='<%# Eval("Html") %>' />
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div>
                    </div>
                </div>

                <div class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.onSale">In Offerta</h5>
                        <div class="box-btn-slide relative">
                            <div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div>
                            <div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div>
                        </div>
                    </div>
                    <div class="swiper ks-column-swiper">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptOnSaleProductSlides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <asp:Literal ID="litOnSaleProductSlideHtml" runat="server" Text='<%# Eval("Html") %>' />
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="tf-sp-2 ks-home-brands-block">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s"><h5>Rivenditori Ufficiali - I migliori Brand</h5></div>
            <div class="swiper ks-home-brands" data-preview="6" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptBrands" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <a href='<%# BrandLink(Eval("id"), Eval("link")) %>' class="ks-home-brand-item" title='<%# SafeText(Eval("Descrizione")) %>'>
                                    <img class="lazyload" src='<%# BrandImage(Eval("img")) %>' data-src='<%# BrandImage(Eval("img")) %>' alt='<%# SafeText(Eval("Descrizione")) %>' />
                                </a>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <div class="sw-dot-default ks-home-brands-pagination"></div>
            </div>
        </div>
    </section>

    <section class="tf-sp-2">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <h5 class="fw-semibold" data-ks-i18n="home.chosenByYou">Scelti Da Te</h5>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptRecentlyViewed" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <%# RenderGridCard(Container.DataItem) %>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
            </div>
        </div>
    </section>

</asp:Content>

<asp:Content ID="cntScripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/home-default.js") %>"></script>
</asp:Content>

