<%@ Page Language="VB" AutoEventWireup="false" MasterPageFile="~/Page.master" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<asp:Content ID="cntTitle" ContentPlaceHolderID="TitleContent" runat="server">
    <asp:Literal ID="litHomePageTitle" runat="server" Mode="Encode" />
</asp:Content>

<asp:Content ID="cntMain" ContentPlaceHolderID="MainContent" runat="server">

    <section id="ksHomePage"
             class="ks-home-main"
             data-ks-async-cart-endpoint="<%= ResolveUrl("~/catalog_cart_async.aspx") %>"
             data-ks-async-cart-token="<%= System.Web.HttpUtility.HtmlAttributeEncode(HomeAsyncCartToken) %>">
        <div id="ksHomeCartStatus"
             class="visually-hidden"
             role="status"
             aria-live="polite"
             aria-atomic="true"
             data-ks-async-cart-status></div>

    <section id="HomeHeroSection" runat="server" class="ks-home-hero-area ks-home-hero-mode-full">
        <div class="container">
            <div id="HomeHeroShell" runat="server" class="ks-home-hero-grid ks-home-hero-mode-full ks-home-has-promos">
                <div class="wrap-item-1 ks-home-departments-panel">
                    <asp:Panel ID="HomeHeroDepartmentsPanel" runat="server" CssClass="nav-category-wrap tf-nav-menu ks-home-departments-list">
                        <div class="main-nav category-menu active-item">
                            <h6 class="fw-semibold title nav-title btn-active d-flex align-items-center gap-2 mb-0">
                                <i class="icon-menu-dots" aria-hidden="true"></i>
                                <span>Tutti i settori</span>
                            </h6>
                            <ul class="menu-category-list" role="menu">
                                <asp:Repeater ID="rptHeroDepartments" runat="server">
                                    <ItemTemplate>
                                        <li class="menu-item" role="none">
                                            <a href='<%# Eval("DefaultUrl") %>' class="item-link body-text-3" role="menuitem">
                                                <span class="ks-home-menu-link">
                                                    <span class="ks-home-menu-thumb">
                                                        <%# RenderHomeSectorMedia(Eval("ImgUrl"), Eval("Descrizione")) %>
                                                    </span>
                                                    <span class="ks-home-menu-title"><%# SafeText(Eval("Descrizione")) %></span>
                                                    <span class="ks-home-menu-arrow"><i class="icon-arrow-right-lg" aria-hidden="true"></i></span>
                                                </span>
                                            </a>
                                        </li>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </ul>
                        </div>
                    </asp:Panel>
                </div>

                <div id="HeroSliderWrap" runat="server" class="wrap-item-2 ks-home-main-hero">
                    <div id="Slide_Show_Container" runat="server" class="swiper ks-home-hero-slider wow fadeInUp" data-wow-delay="0s">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptHeroSlides" runat="server">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <div class="banner-image-product-4 style-2 hover-img ks-home-hero-banner ks-home-hero-panel">
                                            <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="img-style ks-home-hero-media position-absolute top-0 start-0 w-100" aria-label='<%# SafeText(Eval("Caption")) %>'>
                                                <img width="800" height="794" class="lazyload" src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' data-src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' alt='<%# SafeText(Eval("Caption")) %>' />
                                            </a>
                                            <div class="content ks-home-hero-content d-flex flex-column gap-2">
                                                <p class="caption fw-semibold ks-home-hero-eyebrow mb-0"><%# SafeText(Eval("Eyebrow")) %></p>
                                                <h1 class="fw-semibold ks-home-hero-title mb-0"><%# SafeText(Eval("Caption")) %></h1>
                                                <asp:PlaceHolder runat="server" Visible='<%# Not String.IsNullOrWhiteSpace(Convert.ToString(Eval("Description"))) %>'>
                                                    <p class="body-text ks-home-hero-copy mb-0"><%# SafeText(Eval("Description")) %></p>
                                                </asp:PlaceHolder>
                                                <div class="ks-home-hero-actions d-flex align-items-center gap-2 mt-2">
                                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="tf-btn btn-large animate-btn bg-primary text-white">
                                                        <span><%# HomeHeroCtaText(Eval("LinkUrl")) %></span>
                                                    </a>
                                                    <a href="Contattaci.aspx" class="tf-btn btn-line-white btn-large">
                                                        <span>Contattaci</span>
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

                <asp:Panel ID="HeroSideWrap" runat="server" CssClass="wrap-item-3 ks-home-side-promos" Visible="false">
                    <asp:Repeater ID="rptSideBanners" runat="server">
                        <ItemTemplate>
                            <div class="cls-category style-abs hover-img ks-home-side-banner">
                                <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="img-box img-style d-block" aria-label='<%# SafeText(Eval("Title")) %>'>
                                    <img width="540" height="398" class="lazyload" src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' data-src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' alt='<%# SafeText(Eval("Title")) %>' />
                                </a>
                                <div class="content d-flex flex-column gap-2">
                                    <span class="box-sale-wrap"><span class="small-text"><%# SafeText(Eval("Badge")) %></span></span>
                                    <div class="box-title mb-1">
                                        <asp:PlaceHolder runat="server" Visible='<%# Not String.IsNullOrWhiteSpace(Convert.ToString(Eval("Description"))) %>'>
                                            <p class="caption text-white mb-1"><%# SafeText(Eval("Description")) %></p>
                                        </asp:PlaceHolder>
                                        <h6 class="text-white mb-0"><%# SafeText(Eval("Title")) %></h6>
                                    </div>
                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="tf-btn btn-line-white mt-1"><span>Scopri ora</span></a>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </asp:Panel>
            </div>
        </div>
    </section>

    <section id="HomeMainCategoriesSection" runat="server" class="ks-home-section ks-home-categories">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <div>
                    <h5 class="fw-semibold">Categorie principali</h5>
                    <p class="body-text-3 text-main-2 mb-0">Esplora i settori del catalogo e trova rapidamente ciò che cerchi.</p>
                </div>
                <a href="articoli.aspx" class="tf-btn btn-line">
                    <span>Vai al catalogo</span>
                </a>
            </div>
            <div class="ks-home-category-grid">
                <asp:Repeater ID="rptHomeMainCategories" runat="server">
                    <ItemTemplate>
                        <a href='<%# Eval("DefaultUrl") %>' class="ks-home-category-card">
                            <span class="ks-home-category-media">
                                <%# RenderHomeSectorMedia(Eval("ImgUrl"), Eval("Descrizione")) %>
                            </span>
                            <span class="ks-home-category-title"><%# SafeText(Eval("Descrizione")) %></span>
                            <span class="ks-home-category-link">Scopri reparto</span>
                        </a>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <section id="KsLocalAiSearch130" class="ks-ai130-section ks-home-section ks-home-ai-search" data-ks-ai="local-reasoning">
        <div class="container">
            <div class="ks-ai130-shell">
                <div class="ks-ai130-brain">
                    <span class="ks-ai130-kicker">Ricerca nel catalogo</span>
                    <h5>Chiedimi cosa stai cercando</h5>
                    <p>Interpreta la richiesta e cerca tra i prodotti usando descrizioni, codice, EAN/GTIN, marca, reparto e categoria.</p>
                    <div class="ks-ai130-form" role="search">
                        <input type="search" autocomplete="off" placeholder="Descrivi ciò che cerchi nel catalogo" aria-label="Cerca nel catalogo" />
                        <button type="button">Ragiona</button>
                    </div>
                    <asp:Panel ID="HomeAiExamplesPanel" runat="server" CssClass="ks-ai130-examples" Visible="false">
                        <asp:Repeater ID="rptHomeAiExamples" runat="server">
                            <ItemTemplate><button type="button"><%# SafeText(Eval("Descrizione")) %></button></ItemTemplate>
                        </asp:Repeater>
                    </asp:Panel>
                    <div class="ks-ai130-answer"><i></i><p>Scrivi cosa stai cercando: usero il catalogo articoli reale per proporti prodotti pertinenti.</p></div>
                    <asp:Panel ID="HomeAiQuickLinksPanel" runat="server" CssClass="ks-ai130-tools" Visible="false">
                        <asp:Repeater ID="rptHomeAiQuickLinks" runat="server">
                            <ItemTemplate><a href='<%# SafeText(Eval("DefaultUrl")) %>'><%# SafeText(Eval("Descrizione")) %></a></ItemTemplate>
                        </asp:Repeater>
                    </asp:Panel>
                </div>
                <div class="ks-ai130-results-wrap">
                    <div class="ks-ai130-head"><span>Risposta e prodotti consigliati</span><small data-ks-ai-count>Catalogo articoli</small></div>
                    <div class="ks-ai130-results">
                        <div class="ks-ai130-empty">Scrivi una richiesta o scegli un esempio: cerchero nel catalogo reale.</div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section id="HomeFeaturedProductsSection" runat="server" class="ks-home-section ks-home-featured">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <div>
                    <h5 class="fw-semibold" data-ks-i18n="home.featured">In Evidenza</h5>
                    <p class="body-text-3 text-main-2 mb-0">Scopri gli articoli disponibili nel catalogo.</p>
                </div>
                <a href="articoli.aspx" class="tf-btn btn-line">
                    <span>Vedi tutti</span>
                </a>
            </div>
            <div class="ks-home-product-grid">
                <asp:Repeater ID="rptHomeFeaturedProducts" runat="server">
                    <ItemTemplate>
                        <%# RenderGridCard(Container.DataItem) %>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <section id="HomeOffersSection" runat="server" class="ks-home-section ks-home-deals">
        <div class="container">
            <div class="flat-title pb-8 wow fadeInUp" data-wow-delay="0s">
                <div>
                    <h5 class="fw-semibold text-primary flat-title-has-icon">
                        <span class="icon"><i class="icon-fire tf-ani-tada"></i></span><span data-ks-i18n="home.deal">Occasione Imperdibile</span>
                    </h5>
                    <p class="body-text-3 text-main-2 mb-0">Promozioni e occasioni disponibili nel catalogo.</p>
                </div>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <asp:Panel ID="HomeOffersSliderWrap" runat="server" CssClass="box-btn-slide-2 sw-nav-effect">
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
            </asp:Panel>
        </div>
    </section>

    <section id="HomeWidePromoSection" runat="server" visible="false" class="ks-home-section ks-home-wide-promo">
        <div class="container">
            <div class="ks-home-wide-promo-inner">
                <div class="ks-home-wide-promo-copy">
                    <p class="caption text-primary fw-semibold mb-2">Esplora il catalogo</p>
                    <div class="mb-0">
                        <h5 class="fw-semibold mb-2">Scopri gli articoli disponibili nel catalogo</h5>
                        <p class="body-text-3 text-main-2 mb-0">Esplora i prodotti oppure contattaci per maggiori informazioni.</p>
                    </div>
                </div>
                <div class="ks-home-wide-promo-actions d-flex align-items-center gap-2">
                    <a href="articoli.aspx" class="tf-btn btn-line"><span>Vai al catalogo</span></a>
                    <a href="Contattaci.aspx" class="tf-btn btn-line"><span>Contattaci</span></a>
                </div>
            </div>
        </div>
    </section>
    <section id="HomeCollectionSection" runat="server" visible="false" class="ks-home-section ks-home-collection-block">
        <div class="container">
            <div class="ks-home-collection-grid">
                <asp:Repeater ID="rptHomeCollection" runat="server">
                    <ItemTemplate>
                        <a href='<%# SafeText(Eval("DefaultUrl")) %>' class="ks-home-collection-card d-flex flex-column gap-2">
                            <span class="mb-0"><%# SafeText(Eval("Descrizione")) %></span>
                            <div class="mb-0">
                                <strong><%# SafeText(HomeSectorMicrocopy(Eval("Categories"))) %></strong>
                                <em>Scopri il reparto</em>
                            </div>
                        </a>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <section id="HomeLegacyEditorialSection" runat="server" visible="false" class="tf-sp-2 flat-animate-tab ks-home-editorial-section">
        <div class="container">
            <div class="flat-title">
                <div class="flat-title-tab-default">
                    <ul class="menu-tab-line" role="tablist">
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#feature" class="tab-link main-title link fw-semibold active" data-bs-toggle="tab" data-ks-i18n="home.offers">Offerte</a></li>
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#toprate" class="tab-link main-title link fw-semibold" data-bs-toggle="tab" data-ks-i18n="home.topRated">Top Rated</a></li>
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

    <section id="HomeLegacyBestSection" runat="server" visible="false" class="ks-home-section ks-home-best-section">
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

    <section id="HomeRecentlyViewedSection" runat="server" ClientIDMode="Static" visible="false" class="ks-home-section ks-home-recent-section ks-home-chosen-section d-none"
             data-ks-limit="10"
             data-ks-server-fallback="1"
             data-ks-placeholder="<%= ThemeManager.PlaceholderProductImageUrl() %>">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <h5 class="fw-semibold" data-ks-i18n="home.recentlyViewed">Visti di recente</h5>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products ks-rv-prev"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products ks-rv-next"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <div class="swiper tf-sw-products ks-recently-viewed-swiper" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                <div class="swiper-wrapper" data-ks-recent-items>
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

    <section id="HomeBottomPromoSection" runat="server" visible="false" class="ks-home-section ks-home-banner-product">
        <div class="container">
            <div class="ks-home-bottom-promo-grid">
                <asp:Repeater ID="rptHomeBottomPromo" runat="server">
                    <ItemTemplate>
                        <a href='<%# SafeText(Eval("DefaultUrl")) %>' class="ks-home-bottom-promo-card d-flex flex-column gap-2">
                            <span class="mb-0"><%# SafeText(Eval("Descrizione")) %></span>
                            <div class="mb-0">
                                <strong><%# SafeText(HomeSectorMicrocopy(Eval("Categories"))) %></strong>
                                <em>Scopri il reparto</em>
                            </div>
                        </a>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <section id="HomeLowerColumnsSection" runat="server" visible="false" class="tf-sp-2 ks-home-lower-columns-section">
        <div class="container">
            <div class="tf-grid-product">
                <div id="Top20Block" runat="server" class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold">Top 20</h5>
                        <div class="box-btn-slide relative"><div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div><div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div></div>
                    </div>
                    <div class="swiper ks-column-swiper"><div class="swiper-wrapper"><asp:Repeater ID="rptTop20Slides" runat="server"><ItemTemplate><div class="swiper-slide"><asp:Literal ID="litTop20SlideHtml" runat="server" Text='<%# Eval("Html") %>' /></div></ItemTemplate></asp:Repeater></div><div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div></div>
                </div>

                <div id="LowerFeaturedBlock" runat="server" class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.featured">In Evidenza</h5>
                        <div class="box-btn-slide relative"><div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div><div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div></div>
                    </div>
                    <div class="swiper ks-column-swiper"><div class="swiper-wrapper"><asp:Repeater ID="rptFeaturedProductsSlides" runat="server"><ItemTemplate><div class="swiper-slide"><asp:Literal ID="litFeaturedProductsSlideHtml" runat="server" Text='<%# Eval("Html") %>' /></div></ItemTemplate></asp:Repeater></div><div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div></div>
                </div>

                <div id="TopSellingBlock" runat="server" class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.topSelling">I Piu' Venduti</h5>
                        <div class="box-btn-slide relative"><div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div><div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div></div>
                    </div>
                    <div class="swiper ks-column-swiper"><div class="swiper-wrapper"><asp:Repeater ID="rptTopSellingProductSlides" runat="server"><ItemTemplate><div class="swiper-slide"><asp:Literal ID="litTopSellingProductSlideHtml" runat="server" Text='<%# Eval("Html") %>' /></div></ItemTemplate></asp:Repeater></div><div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div></div>
                </div>

                <div id="OnSaleBlock" runat="server" class="tf-grid-product-item box-btn-slide-item">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold" data-ks-i18n="home.onSale">In Offerta</h5>
                        <div class="box-btn-slide relative"><div class="swiper-button-prev nav-swiper ks-col-prev"><i class="icon-arrow-left-lg"></i></div><div class="swiper-button-next nav-swiper ks-col-next"><i class="icon-arrow-right-lg"></i></div></div>
                    </div>
                    <div class="swiper ks-column-swiper"><div class="swiper-wrapper"><asp:Repeater ID="rptOnSaleProductSlides" runat="server"><ItemTemplate><div class="swiper-slide"><asp:Literal ID="litOnSaleProductSlideHtml" runat="server" Text='<%# Eval("Html") %>' /></div></ItemTemplate></asp:Repeater></div><div class="d-flex d-lg-none sw-dot-default ks-col-pagination justify-content-center"></div></div>
                </div>
            </div>
        </div>
    </section>

    <section id="HomeTrustSection" runat="server" class="ks-home-section ks-home-trust-section">
        <div class="container">
            <div class="ks-home-trust-panel">
                <div class="ks-home-trust-copy">
                    <p class="caption text-primary fw-semibold mb-2">Chi siamo</p>
                    <div class="mb-0">
                        <h5 class="fw-semibold mb-2"><asp:Literal ID="litHomeCompanyName" runat="server" Mode="Encode" /></h5>
                        <p class="body-text-3 text-main-2 mb-0"><asp:Literal ID="litHomeCompanyDescription" runat="server" Mode="Encode" /></p>
                    </div>
                    <div class="d-flex flex-wrap gap-2 mt-3">
                        <a href="articoli.aspx" class="tf-btn btn-line"><span>Esplora il catalogo</span></a>
                        <a href="Contattaci.aspx" class="tf-btn btn-line"><span>Contattaci</span></a>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section id="HomeBrandsSection" runat="server" class="ks-home-section ks-home-brands">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s"><h5>Marche del catalogo</h5></div>
            <div class="swiper ks-home-brands" data-preview="6" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptBrands" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <a href='<%# BrandLink(Eval("id"), Eval("link")) %>' class="brand-item ks-home-brand-item" title='<%# SafeText(Eval("Descrizione")) %>'>
                                    <span class="ks-home-brand-media"><img class="lazyload" src='<%# BrandImage(Eval("img")) %>' data-src='<%# BrandImage(Eval("img")) %>' alt='<%# SafeText(Eval("Descrizione")) %>' /></span>
                                </a>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
                <div class="sw-dot-default ks-home-brands-pagination"></div>
            </div>
        </div>
    </section>

    </section>

</asp:Content>

<asp:Content ID="cntScripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>?v=20260917-home-async-cart1"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-recently-viewed.js") %>?v=20260916-promo-parity-rev1"></script>
    <script src="<%= ThemeManager.Asset("js/home-default.js") & "?v=20260518-home6" %>"></script>
</asp:Content>
