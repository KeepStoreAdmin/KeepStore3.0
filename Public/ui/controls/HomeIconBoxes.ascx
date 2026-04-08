<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeIconBoxes.ascx.vb" Inherits="UI_HomeIconBoxes" %>
<style type="text/css">
/* Home runtime patch: layout, menu, hero, brands */
.ks-page-home .ks-home-hero-section,
body.ks-page-home .ks-home-hero-section {
    padding-bottom: 0 !important;
}

.ks-home-hero-shell {
    display: flex;
    align-items: stretch;
    gap: 20px;
}

.ks-home-hero-shell > .wrap-item-1,
.ks-home-hero-shell > .wrap-item-2,
.ks-home-hero-shell > .wrap-item-3 {
    min-width: 0;
}

.ks-home-hero-shell > .wrap-item-1 {
    flex: 0 0 280px;
    max-width: 280px;
}

.ks-home-hero-shell > .wrap-item-2 {
    flex: 1 1 auto;
}

.ks-home-hero-shell > .wrap-item-3 {
    flex: 0 0 280px;
    max-width: 280px;
    display: flex;
    flex-direction: column;
    gap: 20px;
}

.ks-home-hero-mode-compact-single > .wrap-item-2 {
    flex-basis: 100%;
}

.ks-home-hero-mode-compact-single > .wrap-item-3,
.ks-home-hero-mode-none > .wrap-item-1,
.ks-home-hero-mode-none > .wrap-item-2,
.ks-home-hero-mode-none > .wrap-item-3 {
    display: none !important;
}

.ks-home-departments {
    height: 100%;
}

.ks-home-departments .main-nav {
    height: 100%;
    border: 1px solid rgba(0,0,0,.08);
    border-radius: 14px;
    overflow: visible;
    background: #fff;
}

.ks-home-departments .title {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    color: #fff;
    background: #ff4b4b;
    font-weight: 700;
}

.ks-home-departments .menu-category-list {
    position: relative;
    margin: 0;
    padding: 6px 0;
    list-style: none;
    overflow: auto;
    max-height: 100%;
}

.ks-home-departments .menu-item {
    position: relative;
    list-style: none;
}

.ks-home-menu-row {
    display: flex;
    align-items: stretch;
}

.ks-home-departments .item-link {
    flex: 1 1 auto;
    display: block;
    padding: 0;
    text-decoration: none;
}

.ks-home-menu-link {
    display: flex;
    align-items: center;
    gap: 12px;
    min-height: 48px;
    padding: 10px 14px;
}

.ks-menu-media {
    width: 34px;
    height: 34px;
    border-radius: 10px;
    overflow: hidden;
    flex: 0 0 34px;
    background: #f5f6f8;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}

.ks-menu-media img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.ks-menu-media.is-empty,
.ks-menu-media-placeholder {
    background: #f5f6f8;
}

.ks-menu-media-placeholder::before {
    content: "";
    width: 14px;
    height: 14px;
    border-radius: 999px;
    background: rgba(0,0,0,.12);
    display: block;
}

.ks-menu-label {
    flex: 1 1 auto;
    min-width: 0;
    white-space: normal;
    line-height: 1.25;
    color: #333e48;
}

.ks-menu-arrow {
    flex: 0 0 auto;
    color: rgba(51,62,72,.65);
}

.ks-menu-toggle {
    display: none;
    width: 48px;
    min-width: 48px;
    border: 0;
    border-left: 1px solid rgba(0,0,0,.06);
    background: transparent;
    color: rgba(51,62,72,.72);
    align-items: center;
    justify-content: center;
    cursor: pointer;
}

.ks-menu-toggle i {
    transition: transform .18s ease;
}

.ks-home-departments .menu-item.is-open > .ks-home-menu-row .ks-menu-toggle i {
    transform: rotate(90deg);
}

.ks-home-departments .menu-item:hover > .ks-home-menu-row,
.ks-home-departments .menu-item:focus-within > .ks-home-menu-row {
    background: #fafafa;
}

.ks-page-home .ks-home-departments .menu-item > .sub-menu-container {
    display: none;
    position: absolute;
    top: 0;
    left: 100%;
    min-width: 560px;
    max-width: 760px;
    min-height: 100%;
    padding: 16px;
    border: 1px solid rgba(0,0,0,.08);
    border-radius: 14px;
    background: #fff;
    box-shadow: 0 18px 45px rgba(0,0,0,.12);
    z-index: 80;
}

.ks-page-home .ks-home-departments .menu-item:hover > .sub-menu-container,
.ks-page-home .ks-home-departments .menu-item:focus-within > .sub-menu-container {
    display: flex;
}

.ks-page-home .ks-home-departments .ks-home-menu-item--leaf > .sub-menu-container,
.ks-page-home .ks-home-departments .menu-item[data-ks-has-children="0"] > .sub-menu-container {
    display: none !important;
}

.ks-home-submenu-list {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
    width: 100%;
    margin: 0;
    padding: 0;
    list-style: none;
}

.ks-home-submenu-card {
    height: 100%;
    padding: 12px 14px;
    border-radius: 12px;
    background: #fafafa;
}

.ks-home-submenu-category {
    display: inline-flex;
    margin-bottom: 8px;
    font-weight: 700;
    text-decoration: none;
}

.ks-home-submenu-tipology-list {
    margin: 0;
    padding: 0;
    list-style: none;
}

.ks-home-submenu-tipology {
    margin-bottom: 4px;
}

.ks-home-submenu-tipology-link {
    color: #667085;
    text-decoration: none;
}

.ks-home-sector-promo {
    position: relative !important;
    flex: 0 0 220px;
    width: 220px;
    min-width: 220px;
    overflow: hidden;
}

.ks-home-sector-promo .img-box,
.ks-home-sector-promo img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.ks-page-home .header-bottom .nav-item > .sub-menu-container {
    opacity: 0;
    visibility: hidden;
    pointer-events: none;
}

.ks-page-home .header-bottom .nav-item:hover > .sub-menu-container,
.ks-page-home .header-bottom .nav-item:focus-within > .sub-menu-container {
    opacity: 1;
    visibility: visible;
    pointer-events: auto;
}

.ks-page-home [data-ks-invalid="1"] {
    display: none !important;
}

.ks-home-iconboxes {
    margin-top: 18px;
}

.ks-home-iconboxes .tf-icon-box {
    height: 100%;
    min-height: 94px;
    padding: 16px 18px;
    border: 1px solid rgba(0,0,0,.08);
    border-radius: 14px;
    background: #fff;
}

.ks-home-iconboxes .content p:last-child {
    margin-bottom: 0;
    color: #667085;
}

.ks-page-home .ks-home-brands .swiper-slide,
.ks-page-home [data-ks-brand-block="1"] .swiper-slide {
    height: auto;
}

.ks-page-home .ks-home-brands .swiper-slide > a,
.ks-page-home .ks-home-brands .swiper-slide > div,
.ks-page-home [data-ks-brand-block="1"] .swiper-slide > a,
.ks-page-home [data-ks-brand-block="1"] .swiper-slide > div {
    min-height: 86px;
    height: 86px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
}

.ks-page-home .ks-home-brands img,
.ks-page-home [data-ks-brand-block="1"] img {
    max-width: 100%;
    max-height: 54px;
    width: auto;
    height: auto;
    object-fit: contain;
}

@media (max-width: 1199.98px) {
    .ks-home-hero-shell {
        flex-wrap: wrap;
    }

    .ks-home-hero-shell > .wrap-item-1,
    .ks-home-hero-shell > .wrap-item-2,
    .ks-home-hero-shell > .wrap-item-3 {
        flex: 1 1 100%;
        max-width: 100%;
    }

    .ks-menu-arrow {
        display: none;
    }

    .ks-menu-toggle {
        display: inline-flex;
    }

    .ks-page-home .ks-home-departments .menu-item > .sub-menu-container {
        position: static;
        min-width: 0;
        max-width: none;
        min-height: 0;
        padding: 0 12px 12px;
        border: 0;
        border-top: 1px solid rgba(0,0,0,.06);
        box-shadow: none;
        border-radius: 0;
    }

    .ks-page-home .ks-home-departments .menu-item:hover > .sub-menu-container,
    .ks-page-home .ks-home-departments .menu-item:focus-within > .sub-menu-container {
        display: none;
    }

    .ks-page-home .ks-home-departments .menu-item.is-open > .sub-menu-container {
        display: block;
    }

    .ks-home-submenu-list {
        grid-template-columns: 1fr;
        margin-top: 12px;
    }

    .ks-home-sector-promo {
        display: none !important;
    }
}
</style>
<div class="tf-sp-2 pt-0 ks-home-iconboxes">
    <div class="container">
        <div class="swiper tf-sw-iconbox" data-preview="5" data-tablet="3" data-mobile-sm="2" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="15">
            <div class="swiper-wrapper">
                <div class="swiper-slide">
                    <div class="tf-icon-box">
                        <div class="icon-box"><i class="icon icon-delivery-2"></i></div>
                        <div class="content">
                            <p class="body-text fw-semibold">Spedizione veloce</p>
                            <p class="body-text-3">Consegna rapida sugli ordini idonei</p>
                        </div>
                    </div>
                </div>
                <div class="swiper-slide">
                    <div class="tf-icon-box">
                        <div class="icon-box"><i class="icon icon-support-2"></i></div>
                        <div class="content">
                            <p class="body-text fw-semibold">Supporto dedicato</p>
                            <p class="body-text-3">Assistenza prima, durante e dopo l'acquisto</p>
                        </div>
                    </div>
                </div>
                <div class="swiper-slide">
                    <div class="tf-icon-box">
                        <div class="icon-box"><i class="icon icon-payment"></i></div>
                        <div class="content">
                            <p class="body-text fw-semibold">Pagamenti sicuri</p>
                            <p class="body-text-3">Circuiti protetti e checkout affidabile</p>
                        </div>
                    </div>
                </div>
                <div class="swiper-slide">
                    <div class="tf-icon-box">
                        <div class="icon-box"><i class="icon icon-reliable"></i></div>
                        <div class="content">
                            <p class="body-text fw-semibold">Affidabilità reale</p>
                            <p class="body-text-3">Catalogo aggiornato e disponibilità verificate</p>
                        </div>
                    </div>
                </div>
                <div class="swiper-slide">
                    <div class="tf-icon-box">
                        <div class="icon-box"><i class="icon icon-check-3"></i></div>
                        <div class="content">
                            <p class="body-text fw-semibold">Garanzia e resi</p>
                            <p class="body-text-3">Procedure chiare e supporto post vendita</p>
                        </div>
                    </div>
                </div>
            </div>
            <div class="sw-pagination-iconbox sw-dot-default justify-content-center"></div>
        </div>
    </div>
</div>
