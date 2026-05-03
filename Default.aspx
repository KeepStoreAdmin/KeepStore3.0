<%@ Page Language="VB" AutoEventWireup="false" MasterPageFile="~/Page.master" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="uc" TagName="HomeIconBoxes" %>

<asp:Content ID="cntTitle" ContentPlaceHolderID="TitleContent" runat="server">
    KeepStore - Informatica, telefonia, assistenza e accessori
</asp:Content>

<asp:Content ID="cntMain" ContentPlaceHolderID="MainContent" runat="server">

    <section class="ks-home-main">

    <section id="HomeHeroSection" runat="server" class="ks-home-hero-area ks-home-hero-mode-full">
        <div class="container">
            <div id="HomeHeroShell" runat="server" class="ks-home-hero-grid ks-home-hero-mode-full ks-home-has-promos">
                <div class="wrap-item-1 ks-home-departments-panel">
                    <asp:Panel ID="HomeHeroDepartmentsPanel" runat="server" CssClass="nav-category-wrap tf-nav-menu ks-home-departments-list">
                        <div class="main-nav category-menu active-item">
                            <h6 class="fw-semibold title nav-title btn-active">
                                <i class="icon-menu-dots"></i>
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
                                                    <span class="ks-home-menu-arrow"><i class="icon-arrow-right-lg"></i></span>
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
                                            <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx?inpromo=1") %>' class="img-style img-item ks-home-hero-media" aria-label='<%# SafeText(Eval("Caption")) %>'>
                                                <img width="800" height="794" class="lazyload" src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' data-src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' alt='<%# SafeText(Eval("Caption")) %>' />
                                            </a>
                                            <div class="content ks-home-hero-content">
                                                <p class="caption fw-semibold ks-home-hero-eyebrow"><%# SafeText(Eval("Eyebrow")) %></p>
                                                <h1 class="fw-semibold ks-home-hero-title"><%# SafeText(Eval("Caption")) %></h1>
                                                <p class="body-text ks-home-hero-copy"><%# SafeText(Eval("Description")) %></p>
                                                <div class="ks-home-hero-actions">
                                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx?inpromo=1") %>' class="tf-btn btn-large animate-btn bg-primary text-white">
                                                        <span>Scopri le offerte</span>
                                                    </a>
                                                    <a href="Contattaci.aspx" class="tf-btn btn-line-white btn-large">
                                                        <span>Richiedi assistenza</span>
                                                    </a>
                                                </div>
                                            </div>
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

                <asp:Panel ID="HeroSideWrap" runat="server" CssClass="wrap-item-3 ks-home-side-promos" Visible="false">
                    <asp:Repeater ID="rptSideBanners" runat="server">
                        <ItemTemplate>
                            <div class="cls-category style-abs hover-img ks-home-side-banner">
                                <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="img-box img-style d-block" aria-label='<%# SafeText(Eval("Title")) %>'>
                                    <img width="540" height="398" class="lazyload" src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' data-src='<%# ResolveHeroSlideImage(Eval("Image"), String.Empty) %>' alt='<%# SafeText(Eval("Title")) %>' />
                                </a>
                                <div class="content">
                                    <span class="box-sale-wrap"><span class="small-text"><%# SafeText(Eval("Badge")) %></span></span>
                                    <div class="box-title">
                                        <p class="caption text-white"><%# SafeText(Eval("Description")) %></p>
                                        <h6 class="text-white"><%# SafeText(Eval("Title")) %></h6>
                                    </div>
                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="tf-btn btn-line-white"><span>Scopri ora</span></a>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </asp:Panel>
            </div>
        </div>
    </section>

    <uc:HomeIconBoxes ID="HomeIconBoxes1" runat="server" />

    <section id="HomeMainCategoriesSection" runat="server" class="ks-home-section ks-home-categories">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <div>
                    <h5 class="fw-semibold">Categorie principali</h5>
                    <p class="body-text-3 text-main-2 mb-0">Naviga i reparti KeepStore e trova rapidamente prodotti, ricambi e accessori tech.</p>
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
                    <span class="ks-ai130-kicker">AI locale KeepStore</span>
                    <h5>Chiedimi cosa stai cercando</h5>
                    <p>Interpreta la richiesta e interroga il catalogo articoli KeepStore usando descrizioni, codice, EAN, marca, reparto e categoria.</p>
                    <div class="ks-ai130-form" role="search">
                        <input type="search" autocomplete="off" placeholder="Es. Cerco un toner compatibile sotto 50 euro" aria-label="Cerca con AI locale KeepStore" />
                        <button type="button">Ragiona</button>
                    </div>
                    <div class="ks-ai130-examples">
                        <button type="button">smartphone samsung</button>
                        <button type="button">monitor 27 pollici gaming</button>
                        <button type="button">Cerco toner compatibile Pantum</button>
                        <button type="button">Voglio un notebook ricondizionato</button>
                        <button type="button">Mi serve un adattatore USB-C</button>
                    </div>
                    <div class="ks-ai130-answer"><i></i><p>Scrivi cosa stai cercando: usero il catalogo articoli reale per proporti prodotti pertinenti.</p></div>
                    <div class="ks-ai130-tools">
                        <a href="articoli.aspx?q=toner%20compatibile">Toner</a>
                        <a href="articoli.aspx?q=custodia%20samsung">Custodie</a>
                        <a href="articoli.aspx?q=notebook%20ricondizionato">Notebook</a>
                        <a href="articoli.aspx?q=hub%20usb">USB</a>
                    </div>
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
                    <p class="body-text-3 text-main-2 mb-0">Articoli selezionati disponibili a catalogo, con immagini e schede pronte per l'acquisto.</p>
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
                    <p class="body-text-3 text-main-2 mb-0">Promozioni e occasioni caricate dal catalogo KeepStore.</p>
                </div>
                <div class="box-btn-slide relative">
                    <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                    <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                </div>
            </div>
            <asp:Panel ID="HomeOffersFallback" runat="server" CssClass="ks-home-offers-fallback" Visible="false">
                <div class="ks-home-promo-institutional">
                    <div>
                        <p class="caption text-primary fw-semibold mb-2">Promozioni KeepStore</p>
                        <h5 class="fw-semibold mb-2">Tecnologia, accessori e assistenza in un unico negozio</h5>
                        <p class="body-text-3 text-main-2 mb-0">Le offerte reali vengono mostrate quando disponibili a catalogo. Nel frattempo puoi consultare i reparti o richiedere supporto tecnico.</p>
                    </div>
                    <div class="ks-home-promo-actions">
                        <a href="articoli.aspx" class="tf-btn btn-line"><span>Vai al catalogo</span></a>
                        <a href="Contattaci.aspx" class="tf-btn btn-line"><span>Richiedi assistenza</span></a>
                    </div>
                </div>
            </asp:Panel>
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
                    <p class="caption text-primary fw-semibold mb-2">Catalogo e assistenza</p>
                    <h5 class="fw-semibold mb-2">Computer, telefonia, stampanti e assistenza specializzata</h5>
                    <p class="body-text-3 text-main-2 mb-0">Una fascia promozionale pulita per guidare l'utente verso catalogo e supporto, senza prezzi o sconti inventati.</p>
                </div>
                <div class="ks-home-wide-promo-actions">
                    <a href="articoli.aspx" class="tf-btn btn-line"><span>Vai al catalogo</span></a>
                    <a href="Contattaci.aspx" class="tf-btn btn-line"><span>Richiedi assistenza</span></a>
                </div>
            </div>
        </div>
    </section>
    <section id="HomeCollectionSection" runat="server" visible="false" class="ks-home-section ks-home-collection-block">
        <div class="container">
            <div class="ks-home-collection-grid">
                <a href="articoli.aspx?q=computer%20notebook" class="ks-home-collection-card">
                    <span>Informatica</span>
                    <strong>PC, notebook, monitor e periferiche</strong>
                    <em>Scopri prodotti per lavoro e casa</em>
                </a>
                <a href="articoli.aspx?q=smartphone%20accessori" class="ks-home-collection-card">
                    <span>Telefonia</span>
                    <strong>Smartphone, accessori e supporto</strong>
                    <em>Trova ricambi, cover e dispositivi</em>
                </a>
                <a href="articoli.aspx?q=toner%20stampante" class="ks-home-collection-card">
                    <span>Stampa</span>
                    <strong>Toner, cartucce e consumabili</strong>
                    <em>Rifornisci casa e ufficio</em>
                </a>
                <a href="Contattaci.aspx" class="ks-home-collection-card ks-home-collection-card--service">
                    <span>Assistenza</span>
                    <strong>Riparazioni, reti e configurazioni</strong>
                    <em>Parla con un tecnico KeepStore</em>
                </a>
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

    <section id="HomeRecentlyViewedSection" runat="server" visible="false" class="ks-home-section ks-home-recent-section ks-home-chosen-section d-none"
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
                <a href="articoli.aspx?q=ricondizionato" class="ks-home-bottom-promo-card">
                    <span>Ricondizionati</span>
                    <strong>Soluzioni controllate per spendere meglio</strong>
                    <em>Consulta gli articoli disponibili a catalogo</em>
                </a>
                <a href="Contattaci.aspx" class="ks-home-bottom-promo-card ks-home-bottom-promo-card--service">
                    <span>Supporto tecnico</span>
                    <strong>Hai dubbi su compatibilita o configurazione?</strong>
                    <em>Parla con KeepStore prima dell'acquisto</em>
                </a>
                <a href="articoli.aspx?q=toner%20cartuccia%20stampante" class="ks-home-bottom-promo-card ks-home-bottom-promo-card--print">
                    <span>Stampa e consumabili</span>
                    <strong>Toner, cartucce e prodotti per ufficio</strong>
                    <em>Apri il catalogo e filtra gli articoli reali</em>
                </a>
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

    <section id="HomeServicesSection" runat="server" class="ks-home-section ks-home-services-section">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                <div>
                    <h5 class="fw-semibold">Servizi KeepStore</h5>
                    <p class="body-text-3 text-main-2 mb-0">Tecnici e consulenti per gestire dispositivi, software, reti e acquisti senza complicazioni.</p>
                </div>
                <a href="Contattaci.aspx" class="tf-btn btn-line">
                    <span>Parla con noi</span>
                </a>
            </div>
            <div class="ks-home-services-grid">
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-computer"></i></span>
                    <h6>Riparazione PC e notebook</h6>
                    <p>Diagnosi, upgrade, sostituzione componenti e ottimizzazione dei tuoi dispositivi.</p>
                </article>
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-phone"></i></span>
                    <h6>Assistenza smartphone</h6>
                    <p>Supporto per configurazione, trasferimento dati e problemi ricorrenti.</p>
                </article>
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-tool"></i></span>
                    <h6>Installazione software</h6>
                    <p>Setup sistemi, applicativi, sicurezza e strumenti per lavoro o casa.</p>
                </article>
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-computer-wifi"></i></span>
                    <h6>Configurazione reti e periferiche</h6>
                    <p>Router, stampanti, periferiche e postazioni pronte all'uso.</p>
                </article>
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-shield"></i></span>
                    <h6>Recupero dati</h6>
                    <p>Valutazione e supporto per recuperare file importanti quando possibile.</p>
                </article>
                <article class="ks-home-service-item">
                    <span class="ks-home-service-icon"><i class="icon-headphone-2"></i></span>
                    <h6>Consulenza acquisto</h6>
                    <p>Scelta guidata di computer, telefonia, consumabili e accessori compatibili.</p>
                </article>
            </div>
        </div>
    </section>

    <section id="HomeTrustSection" runat="server" class="ks-home-section ks-home-trust-section">
        <div class="container">
            <div class="ks-home-trust-panel">
                <div class="ks-home-trust-copy">
                    <p class="caption text-primary fw-semibold mb-2">Fiducia e conversione</p>
                    <h5 class="fw-semibold">Un negozio tech con assistenza reale prima e dopo l'acquisto</h5>
                    <p class="body-text-3 text-main-2 mb-0">KeepStore unisce catalogo ecommerce, disponibilita controllate e contatto diretto con il negozio per aiutarti a scegliere meglio.</p>
                </div>
                <div class="ks-home-trust-list">
                    <div><i class="icon-check-3"></i><span>Esperienza tecnica su informatica e periferiche</span></div>
                    <div><i class="icon-support-2"></i><span>Assistenza diretta e supporto post-vendita</span></div>
                    <div><i class="icon-payment"></i><span>Pagamenti e checkout tramite flusso ecommerce esistente</span></div>
                    <div><i class="icon-phone"></i><span>Contatto rapido con il negozio</span></div>
                </div>
            </div>
        </div>
    </section>

    <section id="HomeBrandsSection" runat="server" class="ks-home-section ks-home-brands">
        <div class="container">
            <div class="flat-title wow fadeInUp" data-wow-delay="0s"><h5>Rivenditori Ufficiali - I migliori Brand</h5></div>
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
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-recently-viewed.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/home-default.js") %>"></script>
</asp:Content>
