<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
<header class="tf-header style-2 ks-header-ui">
    <div class="tf-topbar line-bt d-none d-xl-block">
        <div class="container">
            <div class="row">
                <div class="col-xl-6 col-12">
                    <div class="topbar-left justify-content-xl-start h-100">
                        <p class="body-small text-main-2">
                            <i class="icon-headphone"></i>
                            Call us for free:
                            <a href="tel:+390000000000" class="text-primary link-secondary fw-semibold">+39 000 000 0000</a>
                        </p>
                        <p class="body-small text-main-2">Free Shipping on Orders <span class="fw-semibold text-main">$50+</span></p>
                    </div>
                </div>
                <div class="col-xl-6 d-none d-xl-block">
                    <div class="tf-cur justify-content-end bar-lang">
                        <div class="tf-cur-item tf-currencies gap-0">
                            <i class="icon icon-budget"></i>
                            <div class="tf-curs">
                                <select class="image-select center style-default type-cur" aria-label="Valuta">
                                    <option selected>EUR | Italia (€)</option>
                                    <option>USD | United States ($)</option>
                                    <option>GBP | United Kingdom (£)</option>
                                </select>
                            </div>
                        </div>
                        <div class="tf-cur-item tf-languages gap-0">
                            <i class="icon icon-global"></i>
                            <div class="tf-lans">
                                <select class="image-select center style-default type-lan" aria-label="Lingua">
                                    <option selected>Italiano</option>
                                    <option>English</option>
                                </select>
                            </div>
                        </div>
                        <a id="lnkAccount" runat="server" href="/login.aspx" class="tf-cur-item link">
                            <i class="icon-user-3"></i>
                            <span class="body-small">
                                <asp:MultiView ID="mvLogin" runat="server">
                                    <asp:View ID="vwLoginOff" runat="server">
                                        <span id="lblLogin" runat="server">My account:</span>
                                    </asp:View>
                                    <asp:View ID="vwLoginOn" runat="server">
                                        <span>Ciao, <asp:Label ID="lblUtente" runat="server" /></span>
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
            <div class="row">
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
                        <div class="form-search-product style-2" data-ks-search-form="desktop">
                            <div class="select-category">
                                <select name="product_cat" id="ks_product_cat" class="dropdown_product_cat">
                                    <option value="" selected="selected">All categories</option>
                                </select>
                            </div>
                            <span class="br-line type-vertical bg-line"></span>
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" CssClass="" placeholder="Search for products" AutoCompleteType="Disabled" />
                            </fieldset>
                            <button id="btnSearch" runat="server" type="submit" class="btn-submit-form" aria-label="Search">
                                <i class="icon-search"></i>
                            </button>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-5 d-flex align-items-center justify-content-end">
                    <div class="header-right">
                        <div class="support-wrap d-none d-xl-flex">
                            <img src="/Public/assets/images/headphone-2.svg" alt="" class="flex-shrink-0" style="height:44px;width:44px;" />
                            <div class="content">
                                <p class="call-us body-text-3">Call us now: <a href="tel:+390000000000" class="text-primary link-main body-md-2">+39 000 000 0000</a></p>
                                <p class="mail-us body-text-3">Email: <a href="mailto:support@taikun.it" class="text-secondary link-main">support@taikun.it</a></p>
                            </div>
                        </div>
                        <ul class="nav-icon justify-content-xl-center d-xl-none">
                            <li class="nav-account">
                                <a id="lnkAccountMobile" runat="server" href="/login.aspx" class="link nav-icon-item">
                                    <span><i class="icon icon-user"></i></span>
                                    <p class="body-small">Account</p>
                                </a>
                            </li>
                            <li class="nav-cart">
                                <a href="carrello.aspx" class="link nav-icon-item">
                                    <span><i class="icon icon-cart"></i></span>
                                    <p class="body-small">Cart</p>
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
                    <div class="header-bt-left d-flex align-items-center gap-4">
                        <div class="nav-category-wrap active-container">
                            <div class="nav-title btn-active">
                                <span class="icon icon-menu"></span>
                                <span class="body-text fw-semibold">Tutte le categorie</span>
                            </div>
                            <nav class="category-menu active-item">
                                <ul class="category-menu-list" id="ksDesktopCategoriesMenu">
                                    <asp:Repeater ID="rptNavSettori" runat="server">
                                        <ItemTemplate>
                                            <li class="item">
                                                <a class='ks-root-sector-link' href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                <div class="sub-menu">
                                                    <div class="wrapper-sub-menu">
                                                        <div class="grid-sub-menu">
                                                            <asp:Repeater ID="rptNavCategorie" runat="server">
                                                                <ItemTemplate>
                                                                    <div class="sub-nav-link">
                                                                        <a class="sub-menu-link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                                        <ul class="list-unstyled">
                                                                            <asp:Repeater ID="rptNavTipologie" runat="server">
                                                                                <ItemTemplate>
                                                                                    <li><a class="sub-menu-link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a></li>
                                                                                </ItemTemplate>
                                                                            </asp:Repeater>
                                                                        </ul>
                                                                    </div>
                                                                </ItemTemplate>
                                                            </asp:Repeater>
                                                        </div>
                                                    </div>
                                                </div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </nav>
                        </div>
                        <nav class="main-nav-menu">
                            <ul class="nav-list">
                                <li class="nav-item active pst-unset"><a href="Default.aspx" class="item-link link body-md-2 fw-semibold"><span>Home</span></a></li>
                                <li class="nav-item"><a href="articoli.aspx" class="item-link body-md-2 fw-semibold"><span>Shop</span></a></li>
                                <li class="nav-item"><a href="articoli.aspx" class="item-link body-md-2 fw-semibold"><span>Product</span></a></li>
                                <li class="nav-item"><a href="Contattaci.aspx" class="item-link body-md-2 fw-semibold"><span>Contact</span></a></li>
                            </ul>
                        </nav>
                    </div>
                </div>
                <div class="col-xl-3 d-none d-xl-flex align-items-center justify-content-end">
                    <div class="header-bt-right">
                        <ul class="nav-icon style-2">
                            <li><a href="compare.aspx"><i class="icon-compare1 text-main fs-26 link"></i><span class="count-box">0</span></a></li>
                            <li><a href="wishlist.aspx" class="d-flex"><i class="icon-hearth text-main fs-26 link"></i><span class="count-box"><asp:Label ID="lblWishlistCount" runat="server" Text="0" Visible="true" /></span></a></li>
                            <li class="nav-shop-cart"><a href="carrello.aspx" class="d-flex"><i class="icon-cart text-main fs-26 link"></i><span class="count-box"><asp:Label ID="lblCarrelloCount" runat="server" Text="0" /></span></a></li>
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
            <div class="form-search-product style-2" data-ks-search-form="mobile">
                <div class="select-category d-none d-sm-block">
                    <select name="product_cat_mobile" id="ks_product_cat_mobile" class="dropdown_product_cat">
                        <option value="">All categories</option>
                    </select>
                </div>
                <span class="br-line type-vertical bg-line d-none d-sm-block"></span>
                <fieldset>
                    <asp:TextBox ID="tbCercaMobile" runat="server" CssClass="" placeholder="Search for products" AutoCompleteType="Disabled" />
                </fieldset>
                <button id="btnSearchMobile" runat="server" type="submit" class="btn-submit-form" aria-label="Search"><i class="icon-search"></i></button>
            </div>
        </div>
        <div class="mb-3"><a id="lnkAccountMobileButton" href="myaccount.aspx" runat="server" class="tf-btn btn-line w-100">Area personale</a></div>
        <div class="mb-3"><a class="tf-btn btn-line w-100" href="carrello.aspx">Carrello</a></div>
        <div class="wrap-sidebar-account">
            <ul class="myaccount-nav content-append">
                <li><a href="Default.aspx" class="myaccount-nav-item">Home</a></li>
                <li><a href="articoli.aspx" class="myaccount-nav-item">Catalogo</a></li>
                <li><a href="Contattaci.aspx" class="myaccount-nav-item">Contatti</a></li>
            </ul>
        </div>
        <div class="mt-4" id="ksMobileNavMount">
            <div class="wrap-sidebar-account">
                <ul class="myaccount-nav content-append">
                    <asp:Repeater ID="rptNavSettoriMobile" runat="server">
                        <ItemTemplate>
                            <li class="myaccount-nav-item fw-semibold ks-mobile-sector">
                                <a class="myaccount-nav-item" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                <asp:Repeater ID="rptNavCategorieMobile" runat="server">
                                    <ItemTemplate>
                                        <div class="ms-3 mt-2">
                                            <a class="link text-secondary fw-semibold" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                            <ul class="list-unstyled ms-3 mt-2">
                                                <asp:Repeater ID="rptNavTipologieMobile" runat="server">
                                                    <ItemTemplate>
                                                        <li class="mb-1"><a class="link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a></li>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </ul>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </li>
                        </ItemTemplate>
                    </asp:Repeater>
                </ul>
            </div>
        </div>
    </div>
</div>

<script type="text/javascript">
(function () {
    function collectCategoryLinks() {
        var links = Array.prototype.slice.call(document.querySelectorAll('.ks-root-sector-link'));
        var seen = {};
        return links.map(function (link) {
            return { label: (link.textContent || '').trim(), url: link.getAttribute('href') || '' };
        }).filter(function (item) {
            var key = item.label + '|' + item.url;
            if (!item.label || !item.url || seen[key]) return false;
            seen[key] = true;
            return true;
        });
    }

    function fillSelect(select, items) {
        if (!select) return;
        select.innerHTML = '<option value="">All categories</option>';
        items.forEach(function (item) {
            var opt = document.createElement('option');
            opt.value = item.url;
            opt.textContent = item.label;
            select.appendChild(opt);
        });
    }

    function bindSearch(inputId, buttonId, selectId) {
        var input = document.getElementById(inputId);
        var button = document.getElementById(buttonId);
        var select = document.getElementById(selectId);
        if (!input || !button) return;
        function submitSearch(ev) {
            if (ev) ev.preventDefault();
            var q = (input.value || '').trim();
            var categoryUrl = select && select.value ? select.value : '';
            if (categoryUrl) {
                window.location.href = q ? (categoryUrl + (categoryUrl.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(q)) : categoryUrl;
                return false;
            }
            if (q) {
                window.location.href = 'articoli.aspx?q=' + encodeURIComponent(q);
            }
            return false;
        }
        button.addEventListener('click', submitSearch);
        input.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') submitSearch(e);
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var categories = collectCategoryLinks();
        fillSelect(document.getElementById('ks_product_cat'), categories);
        fillSelect(document.getElementById('ks_product_cat_mobile'), categories);
        bindSearch('<%= tbCerca.ClientID %>', '<%= btnSearch.ClientID %>', 'ks_product_cat');
        bindSearch('<%= tbCercaMobile.ClientID %>', '<%= btnSearchMobile.ClientID %>', 'ks_product_cat_mobile');

        var navTitle = document.querySelector('.nav-category-wrap .nav-title');
        var navMenu = document.querySelector('.nav-category-wrap .category-menu');
        if (navTitle && navMenu) {
            navTitle.addEventListener('click', function (e) {
                e.preventDefault();
                navMenu.classList.toggle('active-item');
            });
        }
        document.querySelectorAll('.ks-home-departments .menu-item, #ksDesktopCategoriesMenu > .item').forEach(function (item) {
            var sub = item.querySelector(':scope > .sub-menu, :scope > .sub-menu-container');
            var link = item.querySelector(':scope > a, :scope > .item-link');
            if (!sub || !link) return;
            link.addEventListener('click', function (e) {
                if (window.innerWidth <= 1199) {
                    e.preventDefault();
                    item.classList.toggle('open');
                }
            });
        });
    });
})();
</script>
