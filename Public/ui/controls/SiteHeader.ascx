<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
<header class="tf-header style-2 ks-header-ui" data-ks-header>
    <div class="tf-topbar line-bt d-none d-xl-block">
        <div class="container">
            <div class="row">
                <div class="col-xl-6 col-12">
                    <div class="topbar-left justify-content-xl-start h-100">
                        <p class="body-small text-main-2">
                            <i class="icon-headphone"></i>
                            <span data-ks-i18n="header.callUsFree">Chiamaci gratis:</span>
                            <asp:HyperLink ID="hlSupportPhoneTop" runat="server" NavigateUrl="tel:+390000000000" CssClass="text-primary link-secondary fw-semibold">
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
                                    <option value="en">English</option>
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
                            <asp:Image ID="imgLogo" runat="server" AlternateText="KeepStore" CssClass="lazyload d-none d-md-inline-block" ImageUrl="" />
                            <asp:Image ID="imgLogoMobile" runat="server" AlternateText="KeepStore" CssClass="lazyload d-inline-block d-md-none" ImageUrl="" />
                        </a>
                    </div>
                </div>
                <div class="col-md-6 d-none d-md-block">
                    <div class="header-center justify-content-end">
                        <div class="form-search-product style-2 ks-search-shell" data-ks-search-form="desktop">
                            <div class="select-category">
                                <asp:DropDownList ID="product_cat" runat="server" ClientIDMode="Static" CssClass="dropdown_product_cat" />
                            </div>
                            <span class="br-line type-vertical bg-line"></span>
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" ClientIDMode="Static" placeholder="Cerca prodotti, codici o EAN" AutoCompleteType="Disabled" />
                            </fieldset>
                            <button id="btnSearch" type="button" class="btn-submit-form" aria-label="Cerca">
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
                                    <asp:HyperLink ID="hlSupportPhoneHeader" runat="server" NavigateUrl="tel:+390000000000" CssClass="text-primary link-main body-md-2">
                                        <asp:Literal ID="litSupportPhoneHeader" runat="server" />
                                    </asp:HyperLink>
                                </p>
                                <p class="mail-us body-text-3">
                                    Email:
                                    <asp:HyperLink ID="hlSupportEmailHeader" runat="server" NavigateUrl="mailto:support@example.com" CssClass="text-secondary link-main">
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
                                <a href="carrello.aspx" class="link nav-icon-item">
                                    <span><i class="icon icon-cart"></i></span>
                                    <p class="body-small" data-ks-i18n="header.cart">Carrello</p>
                                </a>
                            </li>
                            <li class="d-flex align-items-center d-xl-none">
                                <a href="#mobileMenu" class="mobile-button" data-bs-toggle="offcanvas" aria-controls="mobileMenu"><span></span></a>
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
                    <div class="header-bt-left">
                        <nav class="main-nav-menu">
                            <ul class="nav-list">
                                <li class="nav-item active pst-unset"><a href="Default.aspx" class="item-link link body-md-2 fw-semibold"><span data-ks-i18n="nav.home">Home</span></a></li>
                                <li class="nav-item"><a href="articoli.aspx" class="item-link body-md-2 fw-semibold"><span data-ks-i18n="nav.catalog">Catalogo</span></a></li>
                                <li class="nav-item"><a href="articoli.aspx?inpromo=1" class="item-link body-md-2 fw-semibold"><span data-ks-i18n="nav.offers">Offerte</span></a></li>
                                <li class="nav-item"><a href="Contattaci.aspx" class="item-link body-md-2 fw-semibold"><span data-ks-i18n="nav.contact">Contatti</span></a></li>
                            </ul>
                        </nav>
                    </div>
                </div>
                <div class="col-xl-3 d-none d-xl-flex align-items-center justify-content-end">
                    <div class="header-bt-right">
                        <ul class="nav-icon style-2">
                            <li>
                                <a href="compare.aspx" class="d-flex" id="ksCompareHeaderLink">
                                    <i class="icon-compare1 text-main fs-26 link"></i>
                                    <span class="count-box" id="ksCompareCount">0</span>
                                </a>
                            </li>
                            <li>
                                <a href="wishlist.aspx" class="d-flex">
                                    <i class="icon-hearth text-main fs-26 link"></i>
                                    <span class="count-box"><asp:Label ID="lblWishlistCount" runat="server" Text="0" Visible="true" /></span>
                                </a>
                            </li>
                            <li class="nav-shop-cart">
                                <a href="carrello.aspx" class="d-flex">
                                    <i class="icon-cart text-main fs-26 link"></i>
                                    <span class="count-box"><asp:Label ID="lblCarrelloCount" runat="server" Text="0" /></span>
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
    <div class="canvas-header">
        <h5 class="offcanvas-title visually-hidden" id="mobileMenuLabel">Menu</h5>
        <div class="d-flex align-items-center justify-content-between w-100">
            <a href="Default.aspx" class="logo-site d-inline-block" aria-label="Home">
                <asp:Image ID="imgLogoDrawer" runat="server" AlternateText="KeepStore" CssClass="lazyload" ImageUrl="" />
            </a>
            <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>
        </div>
    </div>
    <div class="offcanvas-body canvas-body">
        <div class="mb-3">
            <div class="form-search-product style-2 ks-search-shell" data-ks-search-form="mobile">
                <div class="select-category d-none d-sm-block">
                    <asp:DropDownList ID="product_cat_mobile" runat="server" ClientIDMode="Static" CssClass="dropdown_product_cat" />
                </div>
                <span class="br-line type-vertical bg-line d-none d-sm-block"></span>
                <fieldset>
                    <asp:TextBox ID="tbCercaMobile" runat="server" ClientIDMode="Static" placeholder="Cerca prodotti, codici o EAN" AutoCompleteType="Disabled" />
                </fieldset>
                <button id="btnSearchMobile" type="button" class="btn-submit-form" aria-label="Cerca"><i class="icon-search"></i></button>
                <div class="ks-search-suggest" id="ksSearchSuggestMobile" aria-live="polite"></div>
            </div>
        </div>
        <div class="ks-mobile-shortcuts mb-3">
            <a id="lnkAccountMobileButton" href="myaccount.aspx" runat="server" class="tf-btn btn-line w-100" data-ks-i18n="header.accountArea">Area personale</a>
            <a class="tf-btn btn-line w-100" href="carrello.aspx" data-ks-i18n="header.cart">Carrello</a>
            <a class="tf-btn btn-line w-100" href="wishlist.aspx" data-ks-i18n="header.wishlist">Wishlist</a>
            <a class="tf-btn btn-line w-100" href="compare.aspx" data-ks-i18n="header.compare">Confronta prodotti</a>
        </div>
        <div class="wrap-sidebar-account">
            <ul class="myaccount-nav content-append">
                <li><a href="Default.aspx" class="myaccount-nav-item" data-ks-i18n="nav.home">Home</a></li>
                <li><a href="articoli.aspx" class="myaccount-nav-item" data-ks-i18n="nav.catalog">Catalogo</a></li>
                <li><a href="articoli.aspx?inpromo=1" class="myaccount-nav-item" data-ks-i18n="nav.offers">Offerte</a></li>
                <li><a href="Contattaci.aspx" class="myaccount-nav-item" data-ks-i18n="nav.contact">Contatti</a></li>
            </ul>
        </div>
        <div class="mt-4" id="ksMobileNavMount" data-ks-mounted="1">
            <div class="wrap-sidebar-account ks-mobile-catalog-nav">
                <div class="ks-mobile-catalog-head">
                    <h6 class="mb-0" data-ks-i18n="nav.departments">Tutti i reparti</h6>
                </div>
                <ul class="myaccount-nav content-append">
                    <asp:Repeater ID="rptNavSettoriMobile" runat="server" OnItemDataBound="rptNavSettoriMobile_ItemDataBound">
                        <ItemTemplate>
                            <li class="ks-mobile-menu-item">
                                <button type="button" class="ks-mobile-nav-toggle" data-ks-nav-toggle="sector">
                                    <span><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>
                                    <i class="icon-arrow-right"></i>
                                </button>
                                <div class="ks-mobile-nav-panel">
                                    <a class="ks-mobile-view-all" href='<%# Eval("DefaultUrl") %>' data-ks-i18n="nav.viewSector">Vedi tutto il reparto</a>
                                    <asp:Repeater ID="rptNavCategorieMobile" runat="server" OnItemDataBound="rptNavCategorieMobile_ItemDataBound">
                                        <ItemTemplate>
                                            <div class="ks-mobile-subgroup">
                                                <button type="button" class="ks-mobile-nav-toggle is-sublevel" data-ks-nav-toggle="category">
                                                    <span><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></span>
                                                    <i class="icon-arrow-right"></i>
                                                </button>
                                                <div class="ks-mobile-nav-panel">
                                                    <a class="ks-mobile-view-all" href='<%# Eval("DefaultUrl") %>' data-ks-i18n="nav.viewCategory">Vedi tutta la categoria</a>
                                                    <ul class="ks-mobile-leaf-list">
                                                        <asp:Repeater ID="rptNavTipologieMobile" runat="server">
                                                            <ItemTemplate>
                                                                <li><a href='<%# Eval("DefaultUrl") %>'><%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %></a></li>
                                                            </ItemTemplate>
                                                        </asp:Repeater>
                                                    </ul>
                                                </div>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </li>
                        </ItemTemplate>
                    </asp:Repeater>
                </ul>
            </div>
        </div>
    </div>
</div>
