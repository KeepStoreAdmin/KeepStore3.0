<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
<style>
@media (min-width: 1200px) {
  .ks-header-ui .ks-header-nav-shell { display: flex; align-items: center; gap: 28px; min-width: 0; }
  .ks-header-ui .ks-header-all-categories { position: relative; flex: 0 0 270px; z-index: 120; }
  .ks-header-ui .ks-header-catalog-trigger { min-height: 50px; display: flex; align-items: center; gap: 9px; padding: 0 18px; border-radius: 8px 8px 0 0; color: #111827; background: #fff; box-shadow: inset 0 0 0 1px #eceff3; }
  .ks-header-ui .ks-header-catalog-trigger .title { margin: 0; line-height: 50px; color: inherit; }
  .ks-header-ui .ks-header-catalog-trigger .icon-arrow-down { margin-left: auto; transition: transform .2s ease, color .2s ease; }
  .ks-header-ui .ks-header-catalog-item.is-open > .ks-header-catalog-trigger,
  .ks-header-ui .ks-header-catalog-item:focus-within > .ks-header-catalog-trigger,
  .ks-header-ui .ks-header-catalog-trigger:hover { color: var(--primary); }
  .ks-header-ui .ks-header-catalog-item.is-open > .ks-header-catalog-trigger .icon-arrow-down,
  .ks-header-ui .ks-header-catalog-item:focus-within > .ks-header-catalog-trigger .icon-arrow-down { transform: rotate(180deg); }
  .ks-header-ui .ks-header-catalog-menu { width: 760px; min-width: 270px; max-height: 620px; overflow: hidden; border-radius: 0 0 10px 10px; box-shadow: 0 22px 45px rgba(15, 23, 42, .14); }
  .ks-header-ui .ks-header-catalog-menu .menu-category-menu-container { max-height: 620px; overflow-y: auto; overflow-x: hidden; }
  .ks-header-ui .ks-header-catalog-list { padding: 8px 0; }
  .ks-header-ui .ks-header-catalog-sector { position: static; box-shadow: inset 0 -1px 0 #eef1f5; }
  .ks-header-ui .ks-header-catalog-sector-link { min-height: 48px; gap: 10px; padding: 8px 14px; color: #111827; }
  .ks-header-ui .ks-header-catalog-sector-title { min-width: 0; flex: 1 1 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .ks-header-ui .ks-header-catalog-media { width: 30px; height: 30px; flex: 0 0 30px; display: inline-flex; align-items: center; justify-content: center; overflow: hidden; border-radius: 8px; background: #f4f6f8; color: #6b7280; font-size: 10px; font-weight: 800; line-height: 1; }
  .ks-header-ui .ks-header-catalog-media img { display: block; max-width: 100%; max-height: 100%; object-fit: contain; }
  .ks-header-ui .ks-header-catalog-media.is-empty { background: #eef2f7; }
  .ks-header-ui .ks-header-sector-panel { display: none; padding: 14px 16px 18px 54px; background: #fbfcfe; border-top: 1px solid #eef1f5; }
  .ks-header-ui .ks-header-catalog-sector:hover > .ks-header-sector-panel,
  .ks-header-ui .ks-header-catalog-sector:focus-within > .ks-header-sector-panel { display: block; }
  .ks-header-ui .ks-header-sector-panel-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; margin-bottom: 14px; padding-bottom: 12px; border-bottom: 1px solid #eef1f5; }
  .ks-header-ui .ks-header-sector-kicker { font-size: 11px; font-weight: 800; text-transform: uppercase; color: #8a94a6; letter-spacing: .04em; }
  .ks-header-ui .ks-header-sector-title { color: #111827; font-size: 18px; font-weight: 800; line-height: 1.2; }
  .ks-header-ui .ks-header-catalog-menu-list { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px 18px; }
  .ks-header-ui .ks-header-catalog-category-block { min-width: 0; }
  .ks-header-ui .ks-header-catalog-category-link { height: auto; display: inline-flex; padding: 0 0 6px; color: #111827; font-weight: 800; line-height: 1.25; }
  .ks-header-ui .ks-header-catalog-tipology-list { display: grid; gap: 3px; padding: 0; margin: 0; }
  .ks-header-ui .ks-header-catalog-tipology { box-shadow: none; }
  .ks-header-ui .ks-header-catalog-tipology-link,
  .ks-header-ui .ks-header-catalog-empty-link { height: auto; padding: 2px 0; color: #5f6b7a; font-size: 13px; line-height: 1.32; }
  .ks-header-ui .ks-header-catalog-tipology-link:hover,
  .ks-header-ui .ks-header-catalog-empty-link:hover,
  .ks-header-ui .ks-header-catalog-category-link:hover,
  .ks-header-ui .ks-header-sector-title:hover { color: var(--primary); padding-left: 0; }
}
</style>
<header class="tf-header style-2 ks-header-ui" data-ks-header>
    <div class="tf-topbar line-bt d-none d-xl-block">
        <div class="container">
            <div class="row">
                <div class="col-xl-6 col-12">
                    <div class="topbar-left justify-content-xl-start h-100">
                        <p class="body-small text-main-2">
                            <i class="icon-headphone"></i>
                            <span data-ks-i18n="header.callUsFree">Chiamaci gratis:</span>
                            <asp:HyperLink ID="hlSupportPhoneTop" runat="server" NavigateUrl="" CssClass="text-primary link-secondary fw-semibold">
                                <asp:Literal ID="litSupportPhoneTop" runat="server" />
                            </asp:HyperLink>
                        </p>
                        <asp:PlaceHolder ID="phFreeShippingTop" runat="server" Visible="false">
                            <p class="body-small text-main-2">
                                <asp:Literal ID="litFreeShippingTop" runat="server" />
                            </p>
                        </asp:PlaceHolder>
                    </div>
                </div>
                <div class="col-xl-6 d-none d-xl-block">
                    <div class="tf-cur justify-content-end bar-lang">
                        <div class="tf-cur-item tf-currencies gap-0">
                            <i class="icon icon-budget"></i>
                            <div class="tf-curs">
                                <select class="image-select center style-default type-cur" aria-label="Valuta" disabled="disabled">
                                    <option selected>EUR (&euro;)</option>
                                </select>
                            </div>
                        </div>
                        <div class="tf-cur-item tf-languages gap-0">
                            <i class="icon icon-global"></i>
                            <div class="tf-lans">
                                <select class="image-select center style-default type-lan" aria-label="Lingua" id="ksLanguageSelect" data-ks-language>
                                    <option value="it" selected>Italiano</option>
                                </select>
                            </div>
                        </div>
                        <a id="lnkAccount" runat="server" href="/login.aspx" class="tf-cur-item link">
                            <i class="icon-user-3"></i>
                            <span class="body-small">
                                <asp:MultiView ID="mvLogin" runat="server">
                                    <asp:View ID="vwLoginOff" runat="server">
                                        <span id="lblLogin" runat="server" data-ks-i18n="header.account">Il mio account</span>
                                    </asp:View>
                                    <asp:View ID="vwLoginOn" runat="server">
                                        <span><span data-ks-i18n="header.hello">Ciao</span>, <asp:Label ID="lblUtente" runat="server" /></span>
                                        <span class="d-none"><asp:Label ID="lblAccesso" runat="server" /></span>
                                    </asp:View>
                                </asp:MultiView>
                            </span>
                            <i class="icon-arrow-down"></i>
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="inner-header">
        <div class="container">
            <div class="row align-items-center g-3">
                <div class="col-md-3 col-7 d-flex align-items-center">
                    <div class="logo-site">
                        <a href="Default.aspx">
                            <asp:Image ID="imgLogo" runat="server" AlternateText="KeepStore" CssClass="d-none d-md-inline-block" ImageUrl="" />
                            <asp:Image ID="imgLogoMobile" runat="server" AlternateText="KeepStore" CssClass="d-inline-block d-md-none" ImageUrl="" />
                        </a>
                    </div>
                </div>
                <div class="col-md-6 d-none d-md-block">
                    <div class="header-center">
                        <div class="form-search-product m-auto ks-search-shell" data-ks-search-form="desktop">
                            <div class="select-category">
                                <asp:DropDownList ID="product_cat" runat="server" ClientIDMode="Static" CssClass="dropdown_product_cat" />
                            </div>
                            <span class="br-line type-vertical bg-line"></span>
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" ClientIDMode="Static" placeholder="Cerca prodotti, codici o EAN" AutoCompleteType="Disabled" />
                            </fieldset>
                            <button id="btnSearch" runat="server" ClientIDMode="Static" type="submit" class="btn-submit-form" aria-label="Cerca">
                                <i class="icon-search"></i>
                            </button>
                            <div class="ks-search-suggest" id="ksSearchSuggestDesktop" aria-live="polite"></div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-5 d-flex align-items-center justify-content-end">
                    <div class="header-right">
                        <div class="support-wrap d-none d-xl-flex">
                            <img src="/Public/assets/images/headphone-2.svg" alt="" class="flex-shrink-0" style="height:44px;width:44px;" />
                            <div class="content">
                                <p class="call-us body-text-3">
                                    <span data-ks-i18n="header.callNow">Assistenza:</span>
                                    <asp:HyperLink ID="hlSupportPhoneHeader" runat="server" NavigateUrl="" CssClass="text-primary link-main body-md-2">
                                        <asp:Literal ID="litSupportPhoneHeader" runat="server" />
                                    </asp:HyperLink>
                                </p>
                                <p class="mail-us body-text-3">
                                    Email:
                                    <asp:HyperLink ID="hlSupportEmailHeader" runat="server" NavigateUrl="" CssClass="text-secondary link-main">
                                        <asp:Literal ID="litSupportEmailHeader" runat="server" />
                                    </asp:HyperLink>
                                </p>
                            </div>
                        </div>
                        <ul class="nav-icon justify-content-xl-center d-xl-none">
                            <li class="nav-account">
                                <a id="lnkAccountMobile" runat="server" href="/login.aspx" class="link nav-icon-item">
                                    <span><i class="icon icon-user"></i></span>
                                    <p class="body-small" data-ks-i18n="header.accountShort">Account</p>
                                </a>
                            </li>
                            <li class="nav-cart">
                                <a href="carrello.aspx" class="link nav-icon-item" data-bs-toggle="offcanvas" data-bs-target="#ksMiniCartCanvas" aria-controls="ksMiniCartCanvas">
                                    <span><i class="icon icon-cart"></i></span>
                                    <p class="body-small" data-ks-i18n="header.cart">Carrello</p>
                                </a>
                            </li>
                            <li class="d-flex align-items-center d-xl-none">
                    <a href="#" class="mobile-button" role="button" data-bs-toggle="offcanvas" data-bs-target="#mobileMenu" aria-controls="mobileMenu"><span></span></a>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="header-bottom bg-gray-5 d-none d-xl-block">
        <div class="container relative">
            <div class="row">
                <div class="col-xl-9 col-12">
                    <div class="header-bt-left ks-header-nav-shell">
                        <div class="nav-category-wrap ks-header-catalog-item ks-header-all-categories">
                            <a href="articoli.aspx" class="item-link nav-title btn-active ks-header-catalog-trigger" aria-label="Apri catalogo prodotti">
                                <i class="icon-menu-dots fs-20"></i>
                                <h6 class="title fw-semibold" data-ks-i18n="nav.catalog">Catalogo</h6>
                                <i class="icon icon-arrow-down"></i>
                            </a>
                            <nav class="category-menu sub-menu-container ks-header-catalog-menu" aria-label="Catalogo completo">
                                <div id="ksDesktopCategoryMenu" class="menu-category-menu-container ks-header-catalog-wrapper">
                                    <ul class="megamenu ks-header-catalog-list">
                                        <asp:Literal ID="litDesktopCatalogMegaMenu" runat="server" />
                                    </ul>
                                </div>
                            </nav>
                        </div>
                        <nav class="main-nav-menu">
                            <ul class="nav-list">
                                <li class="nav-item active pst-unset"><a href="Default.aspx" class="item-link link body-md-2"><span data-ks-i18n="nav.home">Home</span></a></li>
                                <li class="nav-item"><a href="articoli.aspx?inpromo=1" class="item-link body-md-2"><span data-ks-i18n="nav.offers">Offerte</span></a></li>
                                <li class="nav-item"><a href="Contattaci.aspx" class="item-link body-md-2"><span data-ks-i18n="nav.contact">Contatti</span></a></li>
                            </ul>
                        </nav>
                    </div>
                </div>
                <div class="col-xl-3 d-none d-xl-flex align-items-center justify-content-end">
                    <div class="header-bt-right">
                        <ul class="nav-icon style-2">
                            <li>
                                <a href="#compare" class="link link-fill nav-icon-item relative" id="ksCompareHeaderLink" data-bs-toggle="offcanvas" aria-controls="compare">
                                    <i class="icon-compare1 text-main fs-26 link"></i>
                                    <span class="count-box style-pst-2 d-none d-xxl-flex" id="ksCompareCount">0</span>
                                </a>
                            </li>
                            <li>
                                <a href="wishlist.aspx" class="link link-fill nav-icon-item relative">
                                    <i class="icon-hearth text-main fs-26 link"></i>
                                    <span class="count-box style-pst-2 d-none d-xxl-flex"><asp:Label ID="lblWishlistCount" runat="server" Text="0" Visible="true" /></span>
                                </a>
                            </li>
                            <li class="nav-shop-cart">
                                <a href="carrello.aspx" class="link link-fill nav-icon-item relative" data-bs-toggle="offcanvas" data-bs-target="#ksMiniCartCanvas" aria-controls="ksMiniCartCanvas" aria-label="Apri carrello">
                                    <i class="icon-cart text-main fs-26 link"></i>
                                    <span class="count-box style-pst-2 d-none d-xxl-flex"><asp:Label ID="lblCarrelloCount" runat="server" Text="0" /></span>
                                </a>
                            </li>
                            <li class="d-none"><asp:Label ID="lblCarrelloTotale" runat="server" Text="0,00" /></li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>
</header>

<div class="offcanvas offcanvas-start canvas-mb" tabindex="-1" id="mobileMenu" aria-labelledby="mobileMenuLabel">
    <h5 class="offcanvas-title visually-hidden" id="mobileMenuLabel">Menu</h5>
    <span class="icon-close btn-close-mb link" data-bs-dismiss="offcanvas" aria-label="Chiudi"></span>
    <div class="logo-site">
        <a href="Default.aspx" aria-label="Home">
            <asp:Image ID="imgLogoDrawer" runat="server" AlternateText="KeepStore" CssClass="d-block" ImageUrl="" />
        </a>
    </div>
    <div class="mb-canvas-content">
        <div class="mb-body">
            <div class="mb-content-top">
                <div class="form-search-product style-3 ks-search-shell" data-ks-search-form="mobile">
                    <div class="select-category d-none d-sm-block">
                        <asp:DropDownList ID="product_cat_mobile" runat="server" ClientIDMode="Static" CssClass="dropdown_product_cat" />
                    </div>
                    <span class="br-line type-vertical bg-line d-none d-sm-block"></span>
                    <fieldset>
                        <asp:TextBox ID="tbCercaMobile" runat="server" ClientIDMode="Static" placeholder="Cerca prodotti, codici o EAN" AutoCompleteType="Disabled" />
                    </fieldset>
                    <button id="btnSearchMobile" runat="server" ClientIDMode="Static" type="submit" class="btn-submit-form" aria-label="Cerca">
                        <i class="icon-search"></i>
                    </button>
                    <div class="ks-search-suggest" id="ksSearchSuggestMobile" aria-live="polite"></div>
                </div>

                <ul class="nav-ul-mb content-append ks-mobile-primary-nav">
                    <li class="nav-mb-item"><a href="Default.aspx" class="mb-menu-link"><span data-ks-i18n="nav.home">Home</span></a></li>
                    <li class="nav-mb-item ks-mobile-catalog-root">
                        <a href="#ks-mobile-catalog-root" class="collapsed mb-menu-link" role="button" data-bs-toggle="collapse" aria-expanded="false" aria-controls="ks-mobile-catalog-root">
                            <span data-ks-i18n="nav.catalog">Catalogo</span>
                            <span class="btn-open-sub"></span>
                        </a>
                        <div id="ks-mobile-catalog-root" class="collapse">
                            <ul class="sub-nav-menu ks-mobile-catalog-list">
                                <asp:Repeater ID="rptNavSettoriMobile" runat="server" OnItemDataBound="rptNavSettoriMobile_ItemDataBound">
                                    <ItemTemplate>
                                        <li class="nav-mb-item ks-mobile-sector-item">
                                            <a href="#" class="sub-nav-link collapsed" role="button" data-bs-toggle="collapse" data-bs-target='#ks-mobile-sector-<%# Eval("Id") %>' aria-expanded="false" aria-controls='ks-mobile-sector-<%# Eval("Id") %>'>
                                                <span class="ks-mobile-nav-entry">
                                                    <span class='<%# MobileSectorMediaClass(Eval("ImgUrl")) %>'><%# RenderMobileSectorImage(Eval("ImgUrl"), Eval("Descrizione")) %></span>
                                                    <span class="ks-mobile-nav-label"><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>
                                                </span>
                                                <span class="btn-open-sub"></span>
                                            </a>
                                            <div id='ks-mobile-sector-<%# Eval("Id") %>' class="collapse">
                                                <ul class="sub-nav-menu">
                                                    <li><a class="sub-nav-link active" href='<%# Eval("DefaultUrl") %>' data-ks-i18n="nav.viewSector">Vedi tutto il settore</a></li>
                                                    <asp:Repeater ID="rptNavCategorieMobile" runat="server" OnItemDataBound="rptNavCategorieMobile_ItemDataBound">
                                                        <ItemTemplate>
                                                            <li class="nav-mb-item ks-mobile-category-item">
                                                                <a href="#" class="sub-nav-link collapsed" role="button" data-bs-toggle="collapse" data-bs-target='#ks-mobile-category-<%# Eval("Id") %>' aria-expanded="false" aria-controls='ks-mobile-category-<%# Eval("Id") %>'>
                                                                    <span><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>
                                                                    <span class="btn-open-sub"></span>
                                                                </a>
                                                                <div id='ks-mobile-category-<%# Eval("Id") %>' class="collapse">
                                                                    <ul class="sub-nav-menu sub-menu-level-2">
                                                                        <li><a class="sub-nav-link body-md-2" href='<%# Eval("DefaultUrl") %>' data-ks-i18n="nav.viewCategory">Vedi tutta la categoria</a></li>
                                                                        <asp:Repeater ID="rptNavTipologieMobile" runat="server">
                                                                            <ItemTemplate>
                                                                                <li class="nav-mb-item ks-mobile-tipology-item">
                                                                                    <a class="sub-nav-link body-md-2" href='<%# Eval("DefaultUrl") %>'>
                                                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>
                                                                                    </a>
                                                                                </li>
                                                                            </ItemTemplate>
                                                                        </asp:Repeater>
                                                                    </ul>
                                                                </div>
                                                            </li>
                                                        </ItemTemplate>
                                                    </asp:Repeater>
                                                </ul>
                                            </div>
                                        </li>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </ul>
                        </div>
                    </li>
                    <li class="nav-mb-item"><a href="articoli.aspx?inpromo=1" class="mb-menu-link"><span data-ks-i18n="nav.offers">Offerte</span></a></li>
                    <li class="nav-mb-item"><a href="Contattaci.aspx" class="mb-menu-link"><span data-ks-i18n="nav.contact">Contatti</span></a></li>
                </ul>
            </div>
        </div>
        <div class="mb-bottom">
            <ul class="nav-ul-mb ks-mobile-utility-nav">
                <li class="nav-mb-item"><a id="lnkAccountMobileButton" href="myaccount.aspx" runat="server" class="mb-menu-link"><span data-ks-i18n="header.accountArea">Area personale</span></a></li>
                <li class="nav-mb-item"><a href="wishlist.aspx" class="mb-menu-link"><span data-ks-i18n="header.wishlist">Wishlist</span></a></li>
                <li class="nav-mb-item"><a href="#compare" data-bs-toggle="offcanvas" aria-controls="compare" class="mb-menu-link"><span data-ks-i18n="header.compare">Confronta prodotti</span></a></li>
            </ul>
            <div class="bottom-bar-language bar-lang">
                <div class="tf-curs">
                    <select class="image-select center style-default type-cur" aria-label="Valuta" disabled="disabled">
                        <option selected>EUR (&euro;)</option>
                    </select>
                </div>
                <div class="tf-lans">
                    <select class="image-select center style-default type-lan" aria-label="Lingua" id="ksLanguageSelectMobile" data-ks-language>
                        <option value="it" selected>Italiano</option>
                    </select>
                </div>
            </div>
        </div>
    </div>
</div>
