<%@ Page Language="VB" AutoEventWireup="false" MasterPageFile="~/Page.master" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="uc" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagPrefix="uc" TagName="HomeHeroSlider" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanners.ascx" TagPrefix="uc" TagName="HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="uc" TagName="HomeIconBoxes" %>

<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
    <%-- SEO head (canonical, meta robots, etc) injected from code-behind if needed --%>
    <asp:Literal ID="litSeoHead" runat="server" />
    <style type="text/css">
        .ks-home-ui .card-product .product-img,
        .ks-home-ui .card-product .card-image,
        .ks-home-ui .card-product .tf-image-view,
        .ks-home-ui .card-product .product-thumb-image,
        .ks-home-ui .banner-image-product .image,
        .ks-home-ui .banner-image-product-2 .item-image {
            display: block;
        }

        .ks-home-ui .card-product .product-img img,
        .ks-home-ui .card-product .card-image img,
        .ks-home-ui .card-product .tf-image-view img,
        .ks-home-ui .banner-image-product .image img,
        .ks-home-ui .banner-image-product-2 .item-image img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            background: #fff;
        }

        .ks-home-ui .slider-thumb-deal .product-thumb-image .card-image {
            aspect-ratio: 1 / 1;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .ks-home-ui .slider-thumb-deal .list-image-product {
            overflow-x: auto;
            overflow-y: hidden;
        }

        .ks-home-ui .slider-thumb-deal .list-image-product .image-swap,
        .ks-home-ui .slider-thumb-deal .list-image-product .list-image-item {
            flex: 0 0 auto;
        }

        .ks-home-ui .slider-thumb-deal .list-image-product img {
            width: 74px;
            height: 74px;
            object-fit: contain;
            background: #fff;
        }

        .ks-home-ui .card-product.style-img-border .card-product-wrapper {
            min-height: 250px;
        }

        .ks-home-ui .card-product.style-img-border .product-img {
            aspect-ratio: 1 / 1;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .ks-home-ui .product-thumb-slider .tf-product-view-main .swiper-slide {
            height: auto;
        }

        .ks-home-ui .product-thumb-slider .tf-product-view-main img {
            width: 100%;
            max-height: 380px;
            object-fit: contain;
            background: #fff;
        }

        .ks-home-ui .product-thumb-slider .tf-product-view-thumbs .item {
            height: 92px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #fff;
        }

        .ks-home-ui .product-thumb-slider .tf-product-view-thumbs img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }

        .ks-home-ui .product-list-wrap .card-product-wrapper .product-img {
            width: 110px;
            min-width: 110px;
            aspect-ratio: 1 / 1;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #fff;
        }

        .ks-home-ui .product-list-wrap .card-product-wrapper .product-img img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }

        .ks-home-ui .product-list-wrap .name-product,
        .ks-home-ui .card-product-info .name-product,
        .ks-home-ui .card-product-info .title,
        .ks-home-ui .card-product-info .link {
            word-break: break-word;
        }

        .ks-home-ui .tf-icon-box {
            height: 100%;
            padding: 24px 20px;
        }

        .ks-home-ui .tf-icon-box .content {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .ks-home-ui .slider-thumb-deal .card-product-wrapper {
            padding: 18px;
        }

        .ks-home-ui .slider-thumb-deal .card-product-info {
            padding-top: 22px;
        }

        .ks-home-ui .slider-thumb-deal .product-thumb-image .card-image {
            padding: 8px;
            background: #fff;
            border-radius: 16px;
        }

        .ks-home-ui .slider-thumb-deal .list-image-product {
            margin-top: 12px;
            gap: 10px;
        }

        .ks-home-ui .card-product.style-img-border .card-product-wrapper {
            padding: 18px;
        }

        .ks-home-ui .product-list-wrap li + li {
            margin-top: 20px;
        }

        .ks-home-ui .card-product.style-row.row-small-2 .card-product-wrapper {
            padding-right: 14px;
        }

        .ks-home-ui .card-product.style-row.row-small-2 .box-title {
            gap: 10px;
        }

        .ks-home-ui .js-countdown {
            min-height: 54px;
        }

        @import url("https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap");

        .ks-home-ui,
        .ks-home-ui * {
            font-family: "Poppins", serif;
        }

        .ks-home-ui .flat-title,
        .ks-home-ui .group-btn,
        .ks-home-ui .box-btn-slide {
            gap: 12px;
        }

        .ks-home-ui .box-btn-slide {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .ks-home-ui .box-btn-slide .nav-swiper {
            position: static;
            inset: auto;
            width: 40px;
            height: 40px;
            margin: 0;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border-radius: 999px;
            border: 1px solid rgba(0,0,0,.08);
            background: #fff;
            box-shadow: 0 10px 30px rgba(0,0,0,.08);
            transform: none;
            opacity: 1;
            visibility: visible;
        }

        .ks-home-ui .box-btn-slide .nav-swiper::after {
            display: none;
        }

        .ks-home-ui .box-btn-slide .nav-swiper i {
            font-size: 18px;
        }

        .ks-home-ui .card-product .price-wrap {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            align-items: center;
        }

        .ks-home-ui .group-btn {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
        }

        .ks-home-ui .list-product-btn {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
            margin: 0;
            padding: 0;
        }

        .ks-home-ui .list-product-btn .box-icon {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 40px;
            height: 40px;
            min-width: 40px;
            padding: 0;
            line-height: 1;
        }

        .ks-home-ui .list-product-btn.flex-row {
            justify-content: flex-start;
            align-items: center;
            margin-left: auto;
        }

        .ks-home-ui .list-product-btn.flex-row li,
        .ks-home-ui .list-product-btn li {
            display: inline-flex;
            align-items: center;
        }

        .ks-home-ui .list-product-btn.flex-row {
            flex-wrap: nowrap;
            gap: 10px;
        }

        .ks-home-ui .list-product-btn.flex-row .box-icon,
        .ks-home-ui .list-product-btn.flex-row .add-to-cart,
        .ks-home-ui .list-product-btn.flex-row .btn-icon-action {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            vertical-align: middle;
        }

        .ks-home-ui .list-product-btn.flex-row .add-to-cart i,
        .ks-home-ui .list-product-btn.flex-row .btn-icon-action i {
            line-height: 1;
        }

        .ks-home-ui .ks-refurbished-badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 34px;
            height: 34px;
            padding: 6px;
            border-radius: 999px;
            background: rgba(255,255,255,.98);
            border: 1px solid rgba(0,0,0,.08);
            box-shadow: 0 10px 20px rgba(0,0,0,.08);
            z-index: 8;
        }

        .ks-home-ui .ks-refurbished-badge img {
            width: 20px;
            height: 20px;
            object-fit: contain;
        }

        .ks-home-ui .ks-refurbished-badge span {
            display: none !important;
        }

        .ks-home-ui .ks-refurbished-badge.position-absolute {
            position: absolute;
            top: 18px;
            right: 12px;
            left: auto;
            bottom: auto;
        }

        .ks-home-ui .progress-sold.progress {
            height: 8px;
            border-radius: 999px;
            background: #ffe6e6;
            overflow: hidden;
        }

        .ks-home-ui .progress-bar.bg-primary {
            background: #ff3d3d !important;
            border-radius: 999px;
        }

        .ks-home-ui .main-title,
        .ks-home-ui .flat-title h5 {
            font-size: 30px;
            line-height: 1.12;
            font-weight: 700;
            letter-spacing: 0;
        }

        .ks-home-ui .name-product {
            font-size: 17px;
            line-height: 1.35;
            font-weight: 600;
        }

        .ks-home-ui .caption,
        .ks-home-ui .text-avaiable.caption {
            font-size: 13px;
            line-height: 1.45;
        }

        .ks-home-ui .card-product .list-product-btn .wishlist.addwishlist .icon {
            color: inherit;
        }

        .ks-home-ui .ks-inline-actions {
            margin-top: 16px;
        }

        .ks-home-ui .ks-inline-actions .list-product-btn {
            justify-content: flex-start;
        }

        .ks-home-ui .flat-title h5,
        .ks-home-ui .flat-title .main-title,
        .ks-home-ui .name-product,
        .ks-home-ui .caption,
        .ks-home-ui .price-text,
        .ks-home-ui .price-text-2,
        .ks-home-ui .text-avaiable {
            letter-spacing: 0;
        }

        .ks-home-ui .box-quantity {
            gap: 12px;
            flex-wrap: wrap;
        }

        .ks-home-ui .tf-grid-product {
            gap: 24px;
        }

        .ks-home-ui .offcanvas .card-product.style-row .product-img {
            width: 88px;
            min-width: 88px;
        }

        .ks-home-ui .ks-compare-empty,
        .ks-home-ui .ks-home-toast {
            font-family: "Poppins", serif;
        }

        .ks-home-ui .ks-home-toast {
            position: fixed;
            right: 18px;
            bottom: 18px;
            z-index: 1081;
            min-width: 240px;
            max-width: 320px;
            padding: 14px 16px;
            border-radius: 16px;
            background: #111;
            color: #fff;
            box-shadow: 0 12px 30px rgba(0,0,0,.18);
            opacity: 0;
            transform: translateY(12px);
            pointer-events: none;
            transition: all .25s ease;
        }

        .ks-home-ui .ks-home-toast.show {
            opacity: 1;
            transform: translateY(0);
        }

        .ks-home-ui .ks-compare-grid {
            display: grid;
            gap: 16px;
        }

        .ks-home-ui .ks-compare-toolbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            margin-bottom: 16px;
        }

        .ks-home-ui .ks-compare-empty {
            padding: 24px;
            border: 1px dashed rgba(0,0,0,.12);
            border-radius: 18px;
            background: #fff;
        }

        .ks-home-ui .offcanvas-compare {
            height: auto !important;
            border: 0;
            background: transparent;
        }

        .ks-home-ui .offcanvas-compare .offcanvas-content {
            background: #fff;
            border-radius: 28px 28px 0 0;
            box-shadow: 0 -20px 60px rgba(0,0,0,.18);
            padding: 18px 0 28px;
        }

        .ks-home-ui .offcanvas-compare .header {
            display: flex;
            justify-content: flex-end;
            padding: 0 18px 6px;
        }

        .ks-home-ui .offcanvas-compare .icon-close-popup {
            cursor: pointer;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-list {
            display: flex;
            align-items: flex-start;
            gap: 24px;
        }

        .ks-home-ui .offcanvas-compare .title {
            min-width: 128px;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-wrap {
            display: flex;
            gap: 18px;
            overflow-x: auto;
            padding-bottom: 8px;
            flex: 1 1 auto;
            min-height: 120px;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item {
            position: relative;
            display: flex;
            align-items: center;
            gap: 14px;
            min-width: 280px;
            max-width: 280px;
            padding: 16px 18px;
            border: 1px solid rgba(0,0,0,.08);
            border-radius: 20px;
            background: #fff;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .image {
            width: 88px;
            min-width: 88px;
            height: 88px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 16px;
            border: 1px solid rgba(0,0,0,.08);
            background: #fff;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .image img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .remove,
        .ks-home-ui .offcanvas-compare .tf-compare-item .btns-repeat {
            position: absolute;
            top: 10px;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .remove {
            right: 10px;
            cursor: pointer;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .btns-repeat {
            right: 42px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 18px;
            height: 18px;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .content {
            min-width: 0;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-item .text-line-clamp-2 {
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }

        .ks-home-ui .offcanvas-compare .mini-compare-empty {
            display: none;
            width: 100%;
            padding: 22px;
            border: 1px dashed rgba(0,0,0,.12);
            border-radius: 20px;
            background: #fff;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-buttons {
            min-width: 250px;
            margin-left: auto;
        }

        .ks-home-ui .offcanvas-compare .tf-compare-btn {
            display: flex;
            flex-direction: column;
            gap: 14px;
        }

        @media (max-width: 1199px) {
            .ks-home-ui .offcanvas-compare .tf-compare-list {
                flex-direction: column;
            }

            .ks-home-ui .offcanvas-compare .title,
            .ks-home-ui .offcanvas-compare .tf-compare-buttons {
                min-width: 0;
                width: 100%;
            }
        }

        @media (max-width: 767px) {
            .ks-home-ui .offcanvas-compare .offcanvas-content {
                padding-bottom: 18px;
            }

            .ks-home-ui .offcanvas-compare .tf-compare-item {
                min-width: 250px;
                max-width: 250px;
            }
        }

        .ks-home-ui .tf-grid-product-item .flat-title,
        .ks-home-ui .flat-title.pb-8 {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
        }

        .ks-home-ui .tf-sw-products .swiper-slide,
        .ks-home-ui .tf-sw-categories .swiper-slide {
            height: auto;
        }

        @media (hover: none), (max-width: 1199px) {
            .ks-home-ui .card-product .list-product-btn {
                opacity: 1;
                visibility: visible;
                transform: none;
            }
        }

        @media (max-width: 991px) {
            .ks-home-ui .tf-grid-product {
                grid-template-columns: 1fr 1fr;
            }

            .ks-home-ui .slider-thumb-deal .card-product-wrapper,
            .ks-home-ui .card-product.style-img-border .card-product-wrapper {
                padding: 16px;
            }
        }

        @media (max-width: 767px) {
            .ks-home-ui .tf-grid-product {
                grid-template-columns: 1fr;
            }

            .ks-home-ui .box-btn-slide {
                width: 100%;
                justify-content: flex-start;
            }

            .ks-home-ui .product-list-wrap .card-product-wrapper .product-img {
                width: 86px;
                min-width: 86px;
            }

            .ks-home-ui .slider-thumb-deal .list-image-product img {
                width: 60px;
                height: 60px;
            }

            .ks-home-ui .banner-image-product .content,
            .ks-home-ui .banner-image-product-2 .inner {
                padding-inline: 18px;
            }

            .ks-home-ui .ks-home-toast {
                left: 16px;
                right: 16px;
                bottom: 16px;
                max-width: none;
            }
        }

    </style>
</asp:Content>

<asp:Content ID="ContentBreadcrumb" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <%-- Home: breadcrumb hidden by design --%>
</asp:Content>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContent" runat="server">
    <div class="ks-home-ui">

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

        <!-- Deal Of The Day -->
        <section class="tf-sp-2 pt-0">
            <div class="container">
                <div class="flat-title pb-8 wow fadeInUp" data-wow-delay="0s">
                    <h5 class="fw-semibold text-primary flat-title-has-icon">
                        <span class="icon"><i class="icon-fire tf-ani-tada"></i></span>Occasione Imperdibile
                    </h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="box-btn-slide-2 sw-nav-effect">
                    <div class="swiper tf-sw-products slider-thumb-deal" data-preview="4" data-tablet="3" data-mobile-sm="2" data-mobile="1" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="1" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="4">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptDealOfDay" runat="server" DataSourceID="sdsDealOfDay">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <div class="card-product style-border wow fadeInLeft" data-wow-delay="0s">
                                            <div class="card-product-wrapper overflow-visible">
                                                <div class="product-thumb-image">
                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="card-image">
                                                        <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                    </a>
                                                    <ul class="list-image-product">
                                                        <li class="image-swap active">
                                                            <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                        </li>
                                                        <li class="image-swap">
                                                            <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </li>
                                                        <li class="image-swap">
                                                            <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' />
                                                        </li>
                                                        <li class="image-swap">
                                                            <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' />
                                                        </li>
                                                    </ul>
                                                </div>
                                                <asp:Literal ID="litDealActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn top-0 end-0", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                <asp:Literal ID="litDealSaleWrap" runat="server" Text='<%# RenderSaleWrap(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "Promo", "title-sidebar-2", "top-0 start-0 z-5") %>' />
                                                <asp:Literal ID="litDealRefurb" runat="server" Text='<%# RenderRefurbishedBadge(Eval("Ricondizionato"), "position-absolute") %>' />
                                            </div>
                                            <div class="card-product-info">
                                                <div class="box-title gap-xl-12">
                                                    <div class="d-flex flex-column">
                                                        <h6>
                                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product fw-semibold text-secondary link">
                                                                <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                                            </a>
                                                        </h6>
                                                    </div>
                                                    <p class="price-wrap fw-medium">
                                                        <%# RenderPriceWithSave(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price h4 fw-normal text-primary mb-0", "box-sale-tag") %>
                                                    </p>
                                                </div>
                                                <div class="box-infor-detail gap-xl-20">
                                                    <div class="countdown-box">
                                                        <div class="js-countdown" data-timer='<%# GetCountdownSeconds(Eval("OfferteDataFine")) %>' data-labels="Giorni,Ore,Min,Sec"></div>
                                                    </div>
                                                    <div class="product-progress-sale">
                                                        <div class="progress-sold progress" role="progressbar" aria-valuemin="0" aria-valuemax="100">
                                                            <div class="progress-bar bg-primary" aria-valuenow='<%# GetSoldPercent(Eval("VendutiAnno"), Eval("Giacenza")) %>' style='<%# "width:" & GetSoldPercent(Eval("VendutiAnno"), Eval("Giacenza")) & "%" %>'></div>
                                                        </div>
                                                        <div class="box-quantity d-flex justify-content-between">
                                                            <p class="text-avaiable caption">Venduti: <span class="fw-bold"><%# GetSoldQty(Eval("VendutiAnno")) %></span></p>
                                                            <p class="text-avaiable caption">Disponibili: <span class="fw-bold"><%# GetAvailableQty(Eval("Giacenza")) %></span></p>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                        <div class="sw-dot-default sw-pagination-products justify-content-center"></div>
                    </div>
                    <div class="d-none d-xl-flex swiper-button-prev nav-swiper nav-prev-products-2">
                        <i class="icon-arrow-left-lg"></i>
                    </div>
                    <div class="d-none d-xl-flex swiper-button-next nav-swiper nav-next-products-2">
                        <i class="icon-arrow-right-lg"></i>
                    </div>
                </div>
            </div>
        </section>

        <!-- Banner Image Product -->
        <section class="has-bg-img" data-bg-img="<%= ResolveUrl("~/Public/assets/images/banner/banner-1.jpg") %>" data-bg-size="cover" data-bg-repeat="no-repeat" style='background-image:url(<%= ResolveUrl("~/Public/assets/images/banner/banner-1.jpg") %>);background-size:cover;background-repeat:no-repeat;'>
            <div class="container">
                <div class="banner-image-product hover-img">
                    <a href="articoli.aspx" class="image img-2 img-style overflow-visible relative">
                        <img class="lazyload" alt="banner" src="<%= ResolveUrl("~/Public/assets/images/item/tivi.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/tivi.webp") %>" />
                        <div class="box-sale-wrap position1">
                            <p class="small-text">Promo</p>
                            <p class="title-sidebar-2">Tech</p>
                        </div>
                    </a>
                    <div class="content">
                        <div class="box-title">
                            <h1 class="fw-normal">
                                <a href="articoli.aspx" class="link text-white">
                                    Offerte Tech <br class="d-none d-xl-block" /> selezionate KeepStore
                                </a>
                            </h1>
                            <div class="box-price">
                                <p class="old-price style-white main-title-2 fw-light">Solo online</p>
                                <h3 class="fw-semibold text-third">Prezzi speciali</h3>
                            </div>
                        </div>
                        <div class="box-btn">
                            <a href="articoli.aspx" class="tf-btn-icon type-2 style-white">
                                <i class="icon-circle-chevron-right"></i>
                                <span>Scopri</span>
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Grid Collection -->
        <section class="tf-sp-2 flat-animate-tab">
            <div class="container">
                <div class="flat-title">
                    <div class="flat-title-tab-default">
                        <ul class="menu-tab-line" role="tablist">
                            <li class="nav-tab-item d-flex" role="presentation">
                                <a href="#feature" class="tab-link main-title link fw-semibold active" data-bs-toggle="tab">Feature</a>
                            </li>
                            <li class="nav-tab-item d-flex" role="presentation">
                                <a href="#toprate" class="tab-link main-title link fw-semibold" data-bs-toggle="tab">Toprate</a>
                            </li>
                            <li class="nav-tab-item d-flex" role="presentation">
                                <a href="#on-sale" class="tab-link main-title link fw-semibold" data-bs-toggle="tab">On Sale</a>
                            </li>
                        </ul>
                    </div>
                </div>
                <div class="tab-content">
                    <!-- Feature -->
                    <div class="tab-pane active show" id="feature" role="tabpanel">
                        <div class="grid-cls grid-cls-v1">
                            <div class="grid-item1">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptFeatureLeft" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                            <div class="grid-item2">
                                <asp:Repeater ID="rptFeatureCenter" runat="server">
                                    <ItemTemplate>
                                        <div class="card-product style-border style-thums-2 p-lg-30">
                                            <div class="card-product-wrapper overflow-visible aspect-ratio-0">
                                                <div class="product-thumb-slider thumbs-right">
                                                    <div class="swiper tf-product-view-main">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view">
                                                                    <img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="swiper-slide">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view">
                                                                    <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="swiper-slide">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view">
                                                                    <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' />
                                                                </a>
                                                            </div>
                                                            <div class="swiper-slide">
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view">
                                                                    <img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' />
                                                                </a>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="swiper tf-product-view-thumbs" data-direction="vertical">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' /></div></div>
                                                        </div>
                                                    </div>
                                                </div>
                                                <asp:Literal ID="litFeatureSave" runat="server" Text='<%# RenderSavedWrap(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "Risparmi", "title-sidebar-2", "style-2 z-5") %>' />
                                            </div>
                                            <div class="card-product-info">
                                                <div class="box-title gap-xl-12">
                                                    <div class="d-flex flex-column">
                                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product fw-semibold text-secondary link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                    </div>
                                                    <p class="price-wrap fw-medium"><%# RenderPriceWithSave(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price h4 fw-normal text-primary mb-0", "box-sale-tag") %></p>
                                                </div>
                                                <div class="box-infor-detail gap-xl-20">
                                                    <div class="countdown-box">
                                                        <div class="js-countdown" data-timer='<%# GetCountdownSeconds(Eval("OfferteDataFine")) %>' data-labels="Giorni,Ore,Min,Sec"></div>
                                                    </div>
                                                    <div class="product-progress-sale">
                                                        <div class="progress-sold progress" role="progressbar" aria-valuemin="0" aria-valuemax="100">
                                                            <div class="progress-bar bg-primary" aria-valuenow='<%# GetSoldPercent(Eval("VendutiAnno"), Eval("Giacenza")) %>' style='<%# "width:" & GetSoldPercent(Eval("VendutiAnno"), Eval("Giacenza")) & "%" %>'></div>
                                                        </div>
                                                        <div class="box-quantity d-flex justify-content-between">
                                                            <p class="text-avaiable caption">Venduti: <span class="fw-bold"><%# GetSoldQty(Eval("VendutiAnno")) %></span></p>
                                                            <p class="text-avaiable caption">Disponibili: <span class="fw-bold"><%# GetAvailableQty(Eval("Giacenza")) %></span></p>
                                                        </div>
                                                    </div>
                                                </div>
                                                <div class="ks-inline-actions">
                                                    <asp:Literal ID="litFeatureCenterActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                </div>
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>
                            <div class="grid-item3">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptFeatureRight" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                        </div>
                    </div>

                    <!-- Toprate -->
                    <div class="tab-pane" id="toprate" role="tabpanel">
                        <div class="grid-cls grid-cls-v1">
                            <div class="grid-item1">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptToprateLeft" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                            <div class="grid-item2">
                                <asp:Repeater ID="rptToprateCenter" runat="server">
                                    <ItemTemplate>
                                        <div class="card-product style-border style-thums-2 p-lg-30">
                                            <div class="card-product-wrapper overflow-visible aspect-ratio-0">
                                                <div class="product-thumb-slider thumbs-right">
                                                    <div class="swiper tf-product-view-main">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' /></a></div>
                                                        </div>
                                                    </div>
                                                    <div class="swiper tf-product-view-thumbs" data-direction="vertical">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' /></div></div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="card-product-info">
                                                <div class="box-title gap-xl-12">
                                                    <div class="d-flex flex-column">
                                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product fw-semibold text-secondary link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                    </div>
                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price h4 fw-normal text-primary mb-0", "old-price body-md-2 text-main-2") %></p>
                                                </div>
                                                <div class="box-btn">
                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="tf-btn-icon type-2">
                                                        <i class="icon-circle-chevron-right"></i>
                                                        <span>Scopri</span>
                                                    </a>
                                                </div>
                                                <div class="ks-inline-actions">
                                                    <asp:Literal ID="litToprateCenterActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                </div>
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>
                            <div class="grid-item3">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptToprateRight" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                        </div>
                    </div>

                    <!-- On Sale -->
                    <div class="tab-pane" id="on-sale" role="tabpanel">
                        <div class="grid-cls grid-cls-v1">
                            <div class="grid-item1">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptOnSaleLeft" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                            <div class="grid-item2">
                                <asp:Repeater ID="rptOnSaleCenter" runat="server">
                                    <ItemTemplate>
                                        <div class="card-product style-border style-thums-2 p-lg-30">
                                            <div class="card-product-wrapper overflow-visible aspect-ratio-0">
                                                <div class="product-thumb-slider thumbs-right">
                                                    <div class="swiper tf-product-view-main">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' /></a></div>
                                                            <div class="swiper-slide"><a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="d-block tf-image-view"><img class="lazyload" alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' /></a></div>
                                                        </div>
                                                    </div>
                                                    <div class="swiper tf-product-view-thumbs" data-direction="vertical">
                                                        <div class="swiper-wrapper">
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img3"), Eval("Img1")) %>' /></div></div>
                                                            <div class="swiper-slide"><div class="item"><img alt="thumb" src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img4"), Eval("Img1")) %>' /></div></div>
                                                        </div>
                                                    </div>
                                                </div>
                                                <asp:Literal ID="litOnSaleSave" runat="server" Text='<%# RenderSaleWrap(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "Promo", "title-sidebar-2", "style-2 z-5") %>' />
                                            </div>
                                            <div class="card-product-info">
                                                <div class="box-title gap-xl-12">
                                                    <div class="d-flex flex-column">
                                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product fw-semibold text-secondary link"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %></a>
                                                    </div>
                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price h4 fw-normal text-primary mb-0", "old-price body-md-2 text-main-2") %></p>
                                                </div>
                                                <div class="box-btn">
                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="tf-btn-icon type-2">
                                                        <i class="icon-circle-chevron-right"></i>
                                                        <span>Scopri</span>
                                                    </a>
                                                </div>
                                                <div class="ks-inline-actions">
                                                    <asp:Literal ID="litOnSaleCenterActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                </div>
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>
                            <div class="grid-item3">
                                <ul class="product-list-wrap">
                                    <asp:Repeater ID="rptOnSaleRight" runat="server">
                                        <ItemTemplate>
                                            <li>
                                                <div class="card-product style-row row-small-2">
                                                    <div class="card-product-wrapper">
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                            <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                            <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                        </a>
                                                    </div>
                                                    <div class="card-product-info">
                                                        <div class="box-title">
                                                            <div class="bg-white relative z-5">
                                                                <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 88)) %></a>
                                                            </div>
                                                            <div class="group-btn">
                                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Nuovi Arrivi -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                    <h5 class="fw-semibold">Nuovi Arrivi</h5>
                    <div class="box-btn-slide relative">
                        <div class="swiper-button-prev nav-swiper nav-prev-products">
                            <i class="icon-arrow-left-lg"></i>
                        </div>
                        <div class="swiper-button-next nav-swiper nav-next-products">
                            <i class="icon-arrow-right-lg"></i>
                        </div>
                    </div>
                </div>
                <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="15" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5" data-grid="2">
                    <div class="swiper-wrapper">
                        <asp:Repeater ID="rptBestSeller" runat="server" DataSourceID="sdsBestSeller">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <div class="card-product style-img-border wow fadeInUp" data-wow-delay="0s">
                                        <div class="card-product-wrapper">
                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                            </a>
                                            <asp:Literal ID="litBestActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                            <asp:Literal ID="litBestSale" runat="server" Text='<%# RenderSaleWrap(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "Promo", "title-sidebar-2") %>' />
                                        </div>
                                        <div class="card-product-info">
                                            <div class="box-title">
                                                <div class="d-flex flex-column">
                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 80)) %></a>
                                                </div>
                                                <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
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

        <!-- Banner Product -->
        <section>
            <div class="container">
                <a href="articoli.aspx" class="banner-image-product-2 hover-img d-block">
                    <div class="item-image item-1 img-style overflow-visible">
                        <img class="lazyload" alt="banner" src="<%= ResolveUrl("~/Public/assets/images/item/camera-2.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/camera-2.webp") %>" />
                    </div>
                    <div class="item-image item-2 img-style overflow-visible d-none d-lg-block">
                        <img class="lazyload" alt="banner" src="<%= ResolveUrl("~/Public/assets/images/item/camera-3.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/camera-3.webp") %>" />
                    </div>
                    <div class="item-banner has-bg-img" data-bg-img="<%= ResolveUrl("~/Public/assets/images/banner/banner-2.jpg") %>" data-bg-size="cover" data-bg-repeat="no-repeat" style='background-image:url(<%= ResolveUrl("~/Public/assets/images/banner/banner-2.jpg") %>);background-size:cover;background-repeat:no-repeat;'>
                        <div class="inner">
                            <h3 class="fw-normal text-white lh-lg-50 font-2">Scopri e <span class="fw-bold">risparmia</span><br />sui prodotti più richiesti</h3>
                            <div class="box-sale-wrap type-3 relative">
                                <p class="small-text">Promo</p>
                                <p class="price-text-2">Online</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
        </section>

        <!-- Top Trend -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="tf-grid-product">
                    <div class="tf-grid-product-item box-btn-slide-item">
                        <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                            <h5 class="fw-semibold">Top 20</h5>
                            <div class="box-btn-slide relative">
                                <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                                <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                            </div>
                        </div>
                        <div class="swiper tf-sw-products" data-preview="1" data-tablet="1" data-mobile-sm="1" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="20" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
                            <div class="swiper-wrapper">
                                <div class="swiper-slide">
                                    <ul class="product-list-wrap">
                                        <asp:Repeater ID="rptTop20" runat="server" DataSourceID="sdsTop20">
                                            <ItemTemplate>
                                                <li>
                                                    <div class="card-product style-row row-small-2">
                                                        <div class="card-product-wrapper">
                                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                                <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                                <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                            </a>
                                                        </div>
                                                        <div class="card-product-info">
                                                            <div class="box-title">
                                                                <div class="bg-white relative z-5">
                                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 70)) %></a>
                                                                </div>
                                                                <div class="group-btn">
                                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                    <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </li>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </ul>
                                </div>
                            </div>
                            <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                        </div>
                    </div>

                    <div class="tf-grid-product-item box-btn-slide-item">
                        <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                            <h5 class="fw-semibold">Featured Products</h5>
                            <div class="box-btn-slide relative">
                                <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                                <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                            </div>
                        </div>
                        <div class="swiper tf-sw-products" data-preview="1" data-tablet="1" data-mobile-sm="1" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="20" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
                            <div class="swiper-wrapper">
                                <div class="swiper-slide">
                                    <ul class="product-list-wrap">
                                        <asp:Repeater ID="rptFeaturedMini" runat="server" DataSourceID="sdsFeaturedMini">
                                            <ItemTemplate>
                                                <li>
                                                    <div class="card-product style-row row-small-2">
                                                        <div class="card-product-wrapper">
                                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                                <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                                <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                            </a>
                                                        </div>
                                                        <div class="card-product-info">
                                                            <div class="box-title">
                                                                <div class="bg-white relative z-5">
                                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 70)) %></a>
                                                                </div>
                                                                <div class="group-btn">
                                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                    <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </li>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </ul>
                                </div>
                            </div>
                            <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                        </div>
                    </div>

                    <div class="tf-grid-product-item box-btn-slide-item">
                        <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                            <h5 class="fw-semibold">Top Selling Product</h5>
                            <div class="box-btn-slide relative">
                                <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                                <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                            </div>
                        </div>
                        <div class="swiper tf-sw-products" data-preview="1" data-tablet="1" data-mobile-sm="1" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="20" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
                            <div class="swiper-wrapper">
                                <div class="swiper-slide">
                                    <ul class="product-list-wrap">
                                        <asp:Repeater ID="rptTopSellingMini" runat="server" DataSourceID="sdsTopSellingMini">
                                            <ItemTemplate>
                                                <li>
                                                    <div class="card-product style-row row-small-2">
                                                        <div class="card-product-wrapper">
                                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                                <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                                <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                            </a>
                                                        </div>
                                                        <div class="card-product-info">
                                                            <div class="box-title">
                                                                <div class="bg-white relative z-5">
                                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 70)) %></a>
                                                                </div>
                                                                <div class="group-btn">
                                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                    <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </li>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </ul>
                                </div>
                            </div>
                            <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                        </div>
                    </div>

                    <div class="tf-grid-product-item box-btn-slide-item">
                        <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                            <h5 class="fw-semibold">On-sale Product</h5>
                            <div class="box-btn-slide relative">
                                <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                                <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                            </div>
                        </div>
                        <div class="swiper tf-sw-products" data-preview="1" data-tablet="1" data-mobile-sm="1" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="20" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
                            <div class="swiper-wrapper">
                                <div class="swiper-slide">
                                    <ul class="product-list-wrap">
                                        <asp:Repeater ID="rptOnSaleMini" runat="server" DataSourceID="sdsOnSaleMini">
                                            <ItemTemplate>
                                                <li>
                                                    <div class="card-product style-row row-small-2">
                                                        <div class="card-product-wrapper">
                                                            <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                                <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                                <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                            </a>
                                                        </div>
                                                        <div class="card-product-info">
                                                            <div class="box-title">
                                                                <div class="bg-white relative z-5">
                                                                    <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                                    <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 70)) %></a>
                                                                </div>
                                                                <div class="group-btn">
                                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
                                                                    <asp:Literal ID="litCardActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn flex-row", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </li>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </ul>
                                </div>
                            </div>
                            <div class="d-flex d-lg-none sw-dot-default sw-pagination-products justify-content-center"></div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Bottom banners (2) -->
        <section>
            <div class="container">
                <div class="swiper tf-sw-categories overflow-xxl-visible" data-preview="2" data-tablet="2" data-mobile-sm="1" data-mobile="1" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="1" data-pagination-sm="2" data-pagination-md="2" data-pagination-lg="2">
                    <div class="swiper-wrapper">
                        <div class="swiper-slide">
                            <a href="articoli.aspx" class="banner-image-product-2 type-sp-2 hover-img d-block">
                                <div class="item-image img-style overflow-visible position2">
                                    <img class="lazyload" alt="banner" src="<%= ResolveUrl("~/Public/assets/images/item/laptop.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/laptop.webp") %>" />
                                </div>
                                <div class="item-banner has-bg-img" data-bg-img="<%= ResolveUrl("~/Public/assets/images/banner/banner-3.jpg") %>" data-bg-size="cover" data-bg-repeat="no-repeat" style='background-image:url(<%= ResolveUrl("~/Public/assets/images/banner/banner-3.jpg") %>);background-size:cover;background-repeat:no-repeat;'>
                                    <div class="inner justify-content-xl-end">
                                        <div class="box-sale-wrap type-3 relative">
                                            <p class="small-text">Da</p>
                                            <p class="main-title-2">Prezzi smart</p>
                                        </div>
                                        <h4 class="name fw-normal text-white lh-lg-38 text-xl-end">Notebook e accessori<br /><span class="fw-bold">per lavoro e casa</span></h4>
                                    </div>
                                </div>
                            </a>
                        </div>
                        <div class="swiper-slide">
                            <a href="articoli.aspx" class="banner-image-product-2 style-2 type-sp-2 hover-img d-block">
                                <div class="item-image img-style overflow-visible position3">
                                    <img class="lazyload" alt="banner" src="<%= ResolveUrl("~/Public/assets/images/item/camera-1.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/camera-1.webp") %>" />
                                </div>
                                <div class="item-banner has-bg-img" data-bg-img="<%= ResolveUrl("~/Public/assets/images/banner/banner-4.jpg") %>" data-bg-size="cover" data-bg-repeat="no-repeat" style='background-image:url(<%= ResolveUrl("~/Public/assets/images/banner/banner-4.jpg") %>);background-size:cover;background-repeat:no-repeat;'>
                                    <div class="inner">
                                        <div class="box-sale-wrap box-price type-3 relative">
                                            <p class="small-text sub-price">Promo</p>
                                            <p class="main-title-2 num-price">KeepStore</p>
                                        </div>
                                        <h4 class="name fw-normal text-white lh-lg-38 text-xxl-center text-line-clamp-2">Imaging, video e accessori<br class="d-none d-sm-block" /><span class="fw-bold">in evidenza</span></h4>
                                    </div>
                                </div>
                            </a>
                        </div>
                    </div>
                    <div class="sw-dot-default sw-pagination-categories justify-content-center"></div>
                </div>
            </div>
        </section>

        <!-- Recently Viewed -->
        <asp:PlaceHolder ID="phRecentlyViewed" runat="server" Visible="false">
            <section class="tf-sp-2">
                <div class="container">
                    <div class="flat-title wow fadeInUp" data-wow-delay="0s">
                        <h5 class="fw-semibold">Prodotti visualizzati di recente</h5>
                        <div class="box-btn-slide relative">
                            <div class="swiper-button-prev nav-swiper nav-prev-products"><i class="icon-arrow-left-lg"></i></div>
                            <div class="swiper-button-next nav-swiper nav-next-products"><i class="icon-arrow-right-lg"></i></div>
                        </div>
                    </div>
                    <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile-sm="3" data-mobile="2" data-space-lg="30" data-space-md="20" data-space="15" data-pagination="2" data-pagination-sm="3" data-pagination-md="4" data-pagination-lg="5">
                        <div class="swiper-wrapper">
                            <asp:Repeater ID="rptRecentlyViewed" runat="server" DataSourceID="sdsRecentlyViewed">
                                <ItemTemplate>
                                    <div class="swiper-slide">
                                        <div class="card-product style-img-border wow fadeInLeft" data-wow-delay="0s">
                                            <div class="card-product-wrapper">
                                                <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="product-img">
                                                    <img class="img-product lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' data-src='<%# GetHomeProductImage(Eval("Img1"), Nothing) %>' />
                                                    <img class="img-hover lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>' src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' data-src='<%# GetHomeProductImage(Eval("Img2"), Eval("Img1")) %>' />
                                                </a>
                                                <asp:Literal ID="litRecentActions" runat="server" Text='<%# RenderProductActions(Eval("Articoliid"), Eval("Descrizione1"), Eval("Img1"), Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "list-product-btn", Eval("Ean"), Eval("MarcheDescrizione"), ComposeSearchDescription(Eval("Descrizione2"), Eval("DescrizioneLunga")), Eval("Codice"), Eval("Ricondizionato")) %>' />
                                                <asp:Literal ID="litRecentSale" runat="server" Text='<%# RenderSaleWrap(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "Promo", "title-sidebar-2") %>' />
                                            </div>
                                            <div class="card-product-info">
                                                <div class="box-title">
                                                    <div class="d-flex flex-column">
                                                        <p class="caption text-main-2 font-2"><%# Server.HtmlEncode(RenderCaptionLabel(Eval("MarcheDescrizione"), Eval("CategorieDescrizione"), Eval("SettoriDescrizione"), Eval("TipologieDescrizione"), Eval("Codice"))) %></p>
                                                        <a href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>' class="name-product body-md-2 fw-semibold text-secondary link"><%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 80)) %></a>
                                                    </div>
                                                    <p class="price-wrap fw-medium"><%# RenderPricePair(Eval("PrezzoMostrato"), Eval("PrezzoPromoMostrato"), Eval("InOfferta"), "new-price price-text fw-medium", "old-price body-md-2 text-main-2") %></p>
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

        <!-- label compatibilità -->
        <asp:Label ID="lblPrezzi" runat="server" Visible="false" />



        <asp:HiddenField ID="hfHomeActionType" runat="server" />
        <asp:HiddenField ID="hfHomeActionProductId" runat="server" />
        <asp:LinkButton ID="btnHomeAction" runat="server" CssClass="d-none" CausesValidation="false" OnClick="btnHomeAction_Click">Azione Home</asp:LinkButton>

        <div class="offcanvas offcanvas-bottom offcanvas-compare" tabindex="-1" id="ksCompareCanvas" aria-labelledby="ksCompareCanvasLabel">
            <div class="offcanvas-content">
                <div class="header">
                    <span class="icon-close icon-close-popup link" data-bs-dismiss="offcanvas" aria-label="Chiudi"></span>
                </div>
                <div class="wrap">
                    <div class="container">
                        <div class="tf-compare-list">
                            <h5 class="title fw-semibold" id="ksCompareCanvasLabel">
                                Confronta <br class="d-none d-md-block" />
                                prodotti
                            </h5>
                            <div class="mini-compare-empty w-100 text-center" id="ksCompareEmptyState">
                                <h6>Nessun prodotto selezionato</h6>
                                <p class="body-text-3 text-main-2 mt-2 mb-0">Usa il tasto Confronta nelle card della HOME per riempire questa barra.</p>
                            </div>
                            <div class="tf-compare-wrap" id="ksCompareList"></div>
                            <div class="tf-compare-buttons">
                                <div class="tf-compare-btn">
                                    <a href="#" class="tf-btn btn-gray btn-large-3" id="ksCompareRun">
                                        <span class="text-white">Compara prodotti</span>
                                    </a>
                                    <a href="#" class="tf-btn btn-primary btn-large-3" id="ksCompareClear">
                                        <span class="text-white">Svuota</span>
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div id="ksHomeToast" class="ks-home-toast" aria-live="polite"></div>

        <script type="text/javascript">
            (function () {
                var WISHLIST_KEY = 'ks_home_wishlist';
                var COMPARE_KEY = 'ks_home_compare';
                var homeActionTarget = '<%= btnHomeAction.UniqueID %>';

                function toInt(value) {
                    var n = parseInt(value, 10);
                    return isNaN(n) ? 0 : n;
                }

                function readJson(key) {
                    try {
                        var raw = localStorage.getItem(key);
                        return raw ? JSON.parse(raw) : [];
                    } catch (e) {
                        return [];
                    }
                }

                function saveJson(key, value) {
                    try {
                        localStorage.setItem(key, JSON.stringify(value || []));
                    } catch (e) { }
                }

                function toast(message) {
                    var box = document.getElementById('ksHomeToast');
                    if (!box) return;
                    box.textContent = message || '';
                    box.classList.add('show');
                    clearTimeout(box._ksTimer);
                    box._ksTimer = setTimeout(function () { box.classList.remove('show'); }, 1800);
                }

                function syncWishlistButtons() {
                    var list = readJson(WISHLIST_KEY).map(toInt);
                    document.querySelectorAll('.js-ks-wishlist').forEach(function (el) {
                        var icon = el.querySelector('.icon');
                        var tooltip = el.querySelector('.tooltip');
                        var active = list.indexOf(toInt(el.getAttribute('data-ks-id'))) >= 0;
                        el.parentElement.classList.toggle('addwishlist', active);
                        if (icon) {
                            icon.classList.remove('icon-heart2', 'icon-trash');
                            icon.classList.add(active ? 'icon-trash' : 'icon-heart2');
                        }
                        if (tooltip) tooltip.textContent = active ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti';
                    });
                }

                function renderCompare() {
                    var host = document.getElementById('ksCompareList');
                    var empty = document.getElementById('ksCompareEmptyState');
                    if (!host) return;
                    var items = readJson(COMPARE_KEY);
                    if (!items.length) {
                        host.innerHTML = '';
                        if (empty) empty.style.display = 'block';
                        return;
                    }
                    if (empty) empty.style.display = 'none';
                    host.innerHTML = items.map(function (item) {
                        return '' +
                            '<div class="tf-compare-item">' +
                            '  <span class="btns-repeat" aria-hidden="true">' +
                            '    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M11.334 1.33301L14.0007 3.99967L11.334 6.66634" stroke="#181818" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path><path d="M2 7.99951V6.66618C2 5.95893 2.28095 5.28066 2.78105 4.78056C3.28115 4.28046 3.95942 3.99951 4.66667 3.99951H14" stroke="#181818" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path><path d="M4.66667 15.9996L2 13.3329L4.66667 10.6663" stroke="#181818" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path><path d="M14 9.33301V10.6663C14 11.3736 13.719 12.0519 13.219 12.552C12.7189 13.0521 12.0406 13.333 11.3333 13.333H2" stroke="#181818" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path></svg>' +
                            '  </span>' +
                            '  <span class="icon-close remove js-ks-compare-remove" data-ks-id="' + item.id + '"></span>' +
                            '  <a href="' + item.url + '" class="image">' +
                            '    <img class="lazyload" src="' + item.img + '" alt="' + item.title.replace(/"/g, '&quot;') + '">' +
                            '  </a>' +
                            '  <div class="content">' +
                            '    <a class="text-line-clamp-2 body-md-2 fw-semibold text-secondary link" href="' + item.url + '">' + item.title + '</a>' +
                            '    <p class="price-wrap fw-medium mb-0"><span class="new-price price-text fw-medium">' + item.price + '</span></p>' +
                            '  </div>' +
                            '</div>';
                    }).join('');
                }

                function openCompareCanvas() {
                    var target = document.getElementById('ksCompareCanvas');
                    if (!target || !window.bootstrap || !window.bootstrap.Offcanvas) return;
                    window.bootstrap.Offcanvas.getOrCreateInstance(target).show();
                }

                function escapeHtml(value) {
                    return (value || '').toString().replace(/[&<>"]/g, function (ch) {
                        return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[ch] || ch;
                    });
                }

                function runCompareWindow(items) {
                    if (!items || items.length < 2) {
                        toast('Seleziona almeno 2 prodotti per il confronto');
                        return false;
                    }
                    var win = window.open('', '_blank');
                    if (!win) {
                        toast("Consenti l'apertura del confronto in una nuova scheda");
                        return false;
                    }
                    var rows = items.map(function (item) {
                        return '<tr>' +
                            '<td style="padding:16px;border-bottom:1px solid #eee;width:120px;"><img src="' + escapeHtml(item.img) + '" alt="' + escapeHtml(item.title) + '" style="width:96px;height:96px;object-fit:contain"></td>' +
                            '<td style="padding:16px;border-bottom:1px solid #eee;"><a href="' + escapeHtml(item.url) + '" style="color:#111827;font-weight:600;text-decoration:none">' + escapeHtml(item.title) + '</a><div style="margin-top:6px;color:#6b7280;font-size:13px">' + escapeHtml([item.brand || '', item.code || '', item.ean || ''].filter(Boolean).join(' • ')) + '</div><div style="margin-top:10px;font-size:24px;color:#ef4444;font-weight:500">' + escapeHtml(item.price) + '</div><div style="margin-top:8px;color:#374151;font-size:14px">' + escapeHtml(item.desc || '') + '</div></td>' +
                            '</tr>';
                    }).join('');
                    win.document.open();
                    win.document.write('<!doctype html><html lang="it"><head><meta charset="utf-8"><title>Confronta prodotti - KeepStore</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font-family:Poppins,Arial,sans-serif;margin:0;padding:24px;background:#f8fafc;color:#111827}h1{margin:0 0 20px;font-size:32px}table{width:100%;border-collapse:collapse;background:#fff;border-radius:18px;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,.08)}.toolbar{margin-bottom:18px;display:flex;gap:12px;justify-content:space-between;align-items:center}.badge{display:inline-flex;padding:8px 12px;border-radius:999px;background:#fee2e2;color:#b91c1c;font-weight:600;font-size:13px}</style></head><body><div class="toolbar"><h1>Confronta prodotti</h1><span class="badge">KeepStore</span></div><table><tbody>' + rows + '</tbody></table></body></html>');
                    win.document.close();
                    return false;
                }

                window.ksHomeClientAction = function (action, el) {
                    if (action !== 'cart') return false;
                    var id = el ? el.getAttribute('data-ks-id') : '';
                    var hfType = document.getElementById('<%= hfHomeActionType.ClientID %>');
                    var hfId = document.getElementById('<%= hfHomeActionProductId.ClientID %>');
                    if (!hfType || !hfId || !id) return false;
                    hfType.value = action;
                    hfId.value = id;
                    if (typeof __doPostBack === 'function') {
                        __doPostBack(homeActionTarget, '');
                    }
                    return false;
                };

                window.ksHomeWishlist = function (el) {
                    var id = toInt(el && el.getAttribute('data-ks-id'));
                    if (!id) return false;
                    var list = readJson(WISHLIST_KEY).map(toInt).filter(Boolean);
                    var index = list.indexOf(id);
                    if (index >= 0) {
                        list.splice(index, 1);
                        toast('Rimosso dai preferiti');
                    } else {
                        list.unshift(id);
                        list = list.filter(function (value, idx, arr) { return value > 0 && arr.indexOf(value) === idx; }).slice(0, 50);
                        toast('Aggiunto ai preferiti');
                    }
                    saveJson(WISHLIST_KEY, list);
                    syncWishlistButtons();
                    return false;
                };

                window.ksHomeCompare = function (el) {
                    if (!el) return false;
                    var item = {
                        id: toInt(el.getAttribute('data-ks-id')),
                        title: el.getAttribute('data-ks-title') || '',
                        url: el.getAttribute('data-ks-url') || '#',
                        img: el.getAttribute('data-ks-img') || '',
                        price: el.getAttribute('data-ks-price') || '',
                        ean: el.getAttribute('data-ks-ean') || '',
                        brand: el.getAttribute('data-ks-brand') || '',
                        desc: el.getAttribute('data-ks-desc') || '',
                        code: el.getAttribute('data-ks-code') || ''
                    };
                    if (!item.id) return false;
                    var list = readJson(COMPARE_KEY).filter(function (x) { return toInt(x.id) !== item.id; });
                    list.unshift(item);
                    list = list.slice(0, 4);
                    saveJson(COMPARE_KEY, list);
                    renderCompare();
                    openCompareCanvas();
                    toast('Prodotto aggiunto al confronto');
                    return false;
                };

                document.addEventListener('click', function (ev) {
                    var removeBtn = ev.target.closest('.js-ks-compare-remove');
                    if (removeBtn) {
                        ev.preventDefault();
                        var id = toInt(removeBtn.getAttribute('data-ks-id'));
                        var list = readJson(COMPARE_KEY).filter(function (x) { return toInt(x.id) !== id; });
                        saveJson(COMPARE_KEY, list);
                        renderCompare();
                        toast('Prodotto rimosso dal confronto');
                        return;
                    }
                    var clearBtn = ev.target.closest('#ksCompareClear');
                    if (clearBtn) {
                        ev.preventDefault();
                        saveJson(COMPARE_KEY, []);
                        renderCompare();
                        toast('Confronto svuotato');
                        return;
                    }
                    var runBtn = ev.target.closest('#ksCompareRun');
                    if (runBtn) {
                        ev.preventDefault();
                        runCompareWindow(readJson(COMPARE_KEY));
                    }
                });

                document.addEventListener('DOMContentLoaded', function () {
                    syncWishlistButtons();
                    renderCompare();
                });
            })();
        </script>

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
    </div>
</asp:Content>
