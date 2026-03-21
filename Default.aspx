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
                                        <div class="ks-home-hero-card">
                                            <div class="ks-home-hero-bg">
                                                <img class="lazyload" src='<%# ResolveBannerImage(Eval("Image"), "/Public/assets/images/banner/banner-1.jpg") %>' data-src='<%# ResolveBannerImage(Eval("Image"), "/Public/assets/images/banner/banner-1.jpg") %>' alt='<%# SafeText(Eval("Caption")) %>' />
                                            </div>
                                            <div class="ks-home-hero-content">
                                                <span class="caption text-uppercase text-primary fw-semibold"><%# SafeText(Eval("Eyebrow")) %></span>
                                                <h2 class="fw-semibold"><%# SafeText(Eval("Caption")) %></h2>
                                                <p class="body-text-2"><%# SafeText(Eval("Description")) %></p>
                                                <a href='<%# ResolveLink(Eval("LinkUrl"), ProductUrl(Eval("ProductId"))) %>' class="tf-btn btn-fill"><span>Shop now</span></a>
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

                    <div class="ks-home-mini-promos tf-grid-layout md-col-2 gap-3 mt-3">
                        <div class="ks-home-mini-promo">
                            <a href="articoli.aspx" class="image d-block">
                                <img class="lazyload" src="/Public/assets/images/banner/banner-2.jpg" data-src="/Public/assets/images/banner/banner-2.jpg" alt="Promo" />
                            </a>
                            <div class="content">
                                <span class="caption text-uppercase">catch big</span>
                                <h5 class="fw-semibold mb-1">deals on the cameras</h5>
                                <a href="articoli.aspx" class="link text-primary fw-semibold">Shop now</a>
                            </div>
                        </div>
                        <div class="ks-home-mini-promo">
                            <a href="articoli.aspx" class="image d-block">
                                <img class="lazyload" src="/Public/assets/images/banner/banner-3.jpg" data-src="/Public/assets/images/banner/banner-3.jpg" alt="Promo" />
                            </a>
                            <div class="content">
                                <span class="caption text-uppercase">Sale</span>
                                <h5 class="fw-semibold mb-1">Top promo tech</h5>
                                <a href="articoli.aspx" class="link text-primary fw-semibold">Shop now</a>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="wrap-item-3">
                    <div class="ks-home-side-banners d-grid gap-3">
                        <asp:Repeater ID="rptSideBanners" runat="server">
                            <ItemTemplate>
                                <div class="banner-image-product style-2 hover-img wow fadeInRight" data-wow-delay="0s">
                                    <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="d-block image">
                                        <img class="lazyload" src='<%# ResolveBannerImage(Eval("Image"), "/Public/assets/images/banner/banner-4.jpg") %>' data-src='<%# ResolveBannerImage(Eval("Image"), "/Public/assets/images/banner/banner-4.jpg") %>' alt='<%# SafeText(Eval("Title")) %>' />
                                    </a>
                                    <div class="content">
                                        <span class="sub-title fw-semibold text-uppercase"><%# SafeText(Eval("Badge")) %></span>
                                        <h5 class="fw-semibold"><%# SafeText(Eval("Title")) %></h5>
                                        <p class="body-text-3"><%# SafeText(Eval("Description")) %></p>
                                        <a href='<%# ResolveLink(Eval("LinkUrl"), "articoli.aspx") %>' class="tf-btn btn-white hover-icon-2"><span>Shop now</span><i class="icon-circle-chevron-right"></i></a>
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
                    <span class="icon"><i class="icon-fire tf-ani-tada"></i></span>Deal Of The Day
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
                                    <div class="card-product style-border wow fadeInLeft" data-wow-delay="0s">
                                        <div class="card-product-wrapper overflow-visible">
                                            <div class="product-thumb-image">
                                                <a href='<%# ProductUrl(Eval("id")) %>' class="card-image">
                                                    <img class="lazyload img-product" src='<%# ProductImageThumb(Eval("Img1")) %>' data-src='<%# ProductImageThumb(Eval("Img1")) %>' alt='<%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %>' />
                                                </a>
                                                <ul class="list-image-product">
                                                    <li class="image-swap active"><img class="lazyload" src='<%# ProductImageFull(Eval("Img1")) %>' alt='<%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %>' /></li>
                                                    <li class="image-swap"><img class="lazyload" src='<%# ProductImageFull(Eval("Img1")) %>' alt='<%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %>' /></li>
                                                    <li class="image-swap"><img class="lazyload" src='<%# ProductImageFull(Eval("Img1")) %>' alt='<%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %>' /></li>
                                                </ul>
                                            </div>
                                            <ul class="list-product-btn top-0 end-0">
                                                <li>
                                                    <a href='<%# ProductUrl(Eval("id")) %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                        <i class="icon icon-cart2"></i><span class="tooltip">Add to Cart</span>
                                                    </a>
                                                </li>
                                                <li>
                                                    <a href='<%# ProductUrl(Eval("id")) %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                        <i class="icon icon-heart2"></i><span class="tooltip">Add to Wishlist</span>
                                                    </a>
                                                </li>
                                                <li>
                                                    <a href='<%# ProductUrl(Eval("id")) %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                        <i class="icon icon-view"></i><span class="tooltip">Quick View</span>
                                                    </a>
                                                </li>
                                                <li>
                                                    <a href='compare.aspx?add=<%# Eval("id") %>' class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare"
                                                       data-ks-id='<%# Eval("id") %>'
                                                       data-ks-title='<%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %>'
                                                       data-ks-url='<%# ProductUrl(Eval("id")) %>'
                                                       data-ks-img='<%# ProductImageFull(Eval("Img1")) %>'
                                                       data-ks-price='<%# CurrentPrice(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta")) %>'>
                                                        <i class="icon icon-compare1"></i><span class="tooltip">Compare</span>
                                                    </a>
                                                </li>
                                            </ul>
                                            <div class="box-sale-wrap top-0 start-0 z-5" runat="server" visible='<%# ShowDiscount(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta")) %>'>
                                                <p class="small-text">Sale</p>
                                                <p class="title-sidebar-2"><%# DiscountPercent(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta")) %>%</p>
                                            </div>
                                        </div>
                                        <div class="card-product-info">
                                            <div class="box-title gap-xl-12">
                                                <div class="d-flex flex-column">
                                                    <h6><a href='<%# ProductUrl(Eval("id")) %>' class="name-product fw-semibold text-secondary link"><%# ProductTitle(Eval("Descrizione1"), Eval("Descrizione2"), Eval("id")) %></a></h6>
                                                </div>
                                                <p class="price-wrap fw-medium">
                                                    <span class="new-price h4 fw-normal text-primary mb-0"><%# FormatMoney(CurrentPrice(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta"))) %></span>
                                                    <span class="box-sale-tag" runat="server" visible='<%# ShowDiscount(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta")) %>'>Save: <%# FormatMoney(SavingsAmount(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato"), Eval("InOfferta"))) %></span>
                                                </p>
                                            </div>
                                            <div class="box-infor-detail gap-xl-20">
                                                <div class="countdown-box"><div class="js-countdown" data-timer='<%# CountdownSeconds(Eval("OfferteDataFine")) %>' data-labels="Days,Hours,Mins,Secs"></div></div>
                                                <div class="product-progress-sale">
                                                    <div class="progress-sold progress" role="progressbar" aria-valuemin="0" aria-valuemax="100">
                                                        <div class="progress-bar bg-primary" style='<%# "width:" & AvailabilityPercent(Eval("Disponibilita"), Eval("QtaVenduta")) & "%" %>'></div>
                                                    </div>
                                                    <div class="box-quantity d-flex justify-content-between">
                                                        <p class="text-avaiable caption">Sold: <span class="fw-bold"><%# SafeInt(Eval("QtaVenduta")) %></span></p>
                                                        <p class="text-avaiable caption">Available: <span class="fw-bold"><%# SafeInt(Eval("Disponibilita")) %></span></p>
                                                    </div>
                                                </div>
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
        </div>
    </section>

    
    <section class="has-bg-img ks-home-wide-promo" style="background-image:url('/Public/assets/images/banner/banner-1.jpg'); background-size:cover; background-repeat:no-repeat;">
        <div class="container">
            <div class="banner-image-product hover-img">
                <a href="articoli.aspx" class="image img-2 img-style overflow-visible relative">
                    <img width="994" height="986" src="/Public/assets/images/item/tivi.webp" data-src="/Public/assets/images/item/tivi.webp" alt="" class="lazyload" />
                    <div class="box-sale-wrap position1">
                        <p class="small-text">Sale</p>
                        <p class="title-sidebar-2">25%</p>
                    </div>
                </a>
                <div class="content">
                    <div class="box-title">
                        <h1 class="fw-normal">
                            <a href="articoli.aspx" class="link text-white">
                                GameConsole <br class="d-none d-xl-block" />
                                Destiny Special Edition
                            </a>
                        </h1>
                        <div class="box-price">
                            <p class="old-price style-white main-title-2 fw-light">€80,00</p>
                            <h3 class="fw-semibold text-third">€60,00</h3>
                        </div>
                    </div>
                    <div class="box-btn">
                        <a href="articoli.aspx" class="tf-btn-icon type-2 style-white">
                            <i class="icon-circle-chevron-right"></i>
                            <span>Shop now</span>
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
                                    <p class="product-title-2">catch big</p>
                                    <p class="main-title-2 fw-bold">deals</p>
                                    <p class="product-title-2">on the headphones</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Shop now</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Sale</p>
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
                                    <p class="product-title-2">catch big</p>
                                    <p class="main-title-2 fw-bold">deals</p>
                                    <p class="product-title-2">on the cameras</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Shop now</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Sale</p>
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
                                    <p class="product-title-2">catch big</p>
                                    <p class="main-title-2 fw-bold">deals</p>
                                    <p class="product-title-2">on the laptops</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Shop now</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Sale</p>
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
                                    <p class="product-title-2">catch big</p>
                                    <p class="main-title-2 fw-bold">deals</p>
                                    <p class="product-title-2">on the gaming</p>
                                </div>
                                <a href="articoli.aspx" class="tf-btn-icon style-white">
                                    <i class="icon-circle-chevron-right"></i>
                                    <span class="font-2">Shop now</span>
                                </a>
                            </div>
                            <div class="box-sale-wrap">
                                <p class="small-text">Sale</p>
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
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#feature" class="tab-link main-title link fw-semibold active" data-bs-toggle="tab">Feature</a></li>
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#toprate" class="tab-link main-title link fw-semibold" data-bs-toggle="tab">Toprate</a></li>
                        <li class="nav-tab-item d-flex" role="presentation"><a href="#on-sale" class="tab-link main-title link fw-semibold" data-bs-toggle="tab">On Sale</a></li>
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
                        <h3 class="fw-normal text-white lh-lg-50 font-2">Shop and <span class="fw-bold">SAVE BIG</span><br />on hottest camera</h3>
                        <div class="box-sale-wrap type-3 relative">
                            <p class="small-text">Save</p>
                            <p class="price-text-2">€68,99</p>
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
                        <h5 class="fw-semibold">Featured Products</h5>
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
                        <h5 class="fw-semibold">Top Selling Product</h5>
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
                        <h5 class="fw-semibold">On-sale Product</h5>
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
            <div class="flat-title wow fadeInUp" data-wow-delay="0s"><h5 class="fw-semibold">Brands</h5></div>
            <div class="swiper ks-home-brands" data-preview="6" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15">
                <div class="swiper-wrapper">
                    <asp:Repeater ID="rptBrands" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <a href='<%# ResolveLink(Eval("link"), "articoli.aspx") %>' class="ks-home-brand-item" title='<%# SafeText(Eval("Descrizione")) %>'>
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
                <h5 class="fw-semibold">Recently Viewed</h5>
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
