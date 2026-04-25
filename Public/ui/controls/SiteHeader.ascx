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
                                <a href="carrello.aspx" class="link nav-icon-item">
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
                    <div class="header-bt-left">
                        <nav class="main-nav-menu">
                            <ul class="nav-list">
                                <li class="nav-item active pst-unset"><a href="Default.aspx" class="item-link link body-md-2"><span data-ks-i18n="nav.home">Home</span></a></li>
                                <li class="nav-item ks-header-catalog-item">
                                    <a href="articoli.aspx" class="item-link body-md-2">
                                        <span data-ks-i18n="nav.catalog">Catalogo</span>
                                        <i class="icon icon-arrow-down"></i>
                                    </a>
                                    <div class="sub-menu-container mega-menu text-nowrap ks-header-catalog-mega" aria-label="Catalogo completo">
                                        <div id="ksDesktopCategoryMenu" class="wrapper-sub-menu ks-header-catalog-wrapper">
                                            <asp:Literal ID="litDesktopCatalogMegaMenu" runat="server" />
                                        </div>
                                    </div>
                                </li>
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
                                <a href="carrello.aspx" class="link link-fill nav-icon-item relative">
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
                    <li class="nav-mb-item"><a href="articoli.aspx" class="mb-menu-link"><span data-ks-i18n="nav.catalog">Catalogo</span></a></li>
                    <li class="nav-mb-item"><a href="articoli.aspx?inpromo=1" class="mb-menu-link"><span data-ks-i18n="nav.offers">Offerte</span></a></li>
                    <li class="nav-mb-item"><a href="Contattaci.aspx" class="mb-menu-link"><span data-ks-i18n="nav.contact">Contatti</span></a></li>
                </ul>

                <div id="ksMobileNavMount" class="ks-mobile-catalog-nav" data-ks-mounted="1">
                    <div class="ks-mobile-catalog-head">
                        <h6 class="mb-0" data-ks-i18n="nav.departments">Tutti i settori</h6>
                    </div>
                    <ul class="nav-ul-mb ks-mobile-catalog-list">
                        <asp:Repeater ID="rptNavSettoriMobile" runat="server" OnItemDataBound="rptNavSettoriMobile_ItemDataBound">
                            <ItemTemplate>
                                <li class="nav-mb-item ks-mobile-sector-item">
                                    <a href="#" class="collapsed mb-menu-link" role="button" data-bs-toggle="collapse" data-bs-target='#ks-mobile-sector-<%# Eval("Id") %>' aria-expanded="false" aria-controls='ks-mobile-sector-<%# Eval("Id") %>'>
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
