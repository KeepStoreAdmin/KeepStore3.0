<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
<!-- ============================================================
                 HEADER
                 - Mantiene ID/handler esistenti (imgLogo/imgLogoMobile, tbCerca, btnSearch, mvLogin, rptNavSettori, lblCarrelloCount/lblCarrelloTotale)
                 ============================================================ -->
<style type="text/css">
@import url("https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap");
.ks-header-ui,
.ks-header-ui * {
    font-family: "Poppins", serif;
}
.ks-header-ui .form-search-product.style-2 {
    position: relative;
}
.ks-header-ui .form-search-product.style-2 fieldset {
    position: relative;
    flex: 1 1 auto;
}
.ks-header-ui .ks-search-suggest {
    position: absolute;
    top: calc(100% + 10px);
    left: 0;
    right: 0;
    z-index: 1060;
    display: none;
    padding: 10px;
    border-radius: 18px;
    background: #fff;
    border: 1px solid rgba(0,0,0,.08);
    box-shadow: 0 18px 40px rgba(0,0,0,.12);
    max-height: 420px;
    overflow: auto;
}
.ks-header-ui .ks-search-suggest.show {
    display: block;
}
.ks-header-ui .ks-search-suggest .ks-search-group + .ks-search-group {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid rgba(0,0,0,.06);
}
.ks-header-ui .ks-search-suggest .ks-search-label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .04em;
    color: #6b7280;
    margin-bottom: 8px;
}
.ks-header-ui .ks-search-suggest a,
.ks-header-ui .ks-search-suggest button {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    text-align: left;
    padding: 10px 12px;
    border: 0;
    background: transparent;
    border-radius: 12px;
}
.ks-header-ui .ks-search-suggest a:hover,
.ks-header-ui .ks-search-suggest button:hover,
.ks-header-ui .ks-search-suggest .active {
    background: rgba(0,0,0,.04);
}
.ks-header-ui .ks-search-suggest img {
    width: 44px;
    height: 44px;
    object-fit: contain;
    background: #fff;
    border-radius: 10px;
    border: 1px solid rgba(0,0,0,.06);
}
.ks-header-ui .ks-search-suggest .ks-search-meta {
    display: flex;
    flex-direction: column;
    min-width: 0;
    gap: 2px;
}
.ks-header-ui .ks-search-suggest .ks-search-title {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.ks-header-ui .ks-search-suggest .ks-search-sub {
    font-size: 12px;
    color: #6b7280;
}
.ks-header-ui .tf-select-custom {
    min-width: 190px;
    min-height: 54px;
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
}
.ks-header-ui .tf-select-custom .current {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.ks-header-ui select.hide-select {
    display: none !important;
}
.ks-header-ui .select-options {
    display: none !important;
}
.ks-header-ui .select-category {
    position: relative;
    flex: 0 0 auto;
}
.ks-header-ui .select-options {
    z-index: 1061;
}
.ks-header-ui .tf-nav-menu .title.btn-active {
    cursor: pointer;
}
.ks-header-ui .nav-category-wrap.active-container .category-menu.active-item,
.ks-header-ui .tf-nav-menu.active-container .menu-category-list.active-item {
    display: block;
}
@media (max-width: 1199px) {
    .ks-header-ui .tf-select-custom,
    .ks-header-ui .select-category,
    .ks-header-ui .br-line.type-vertical {
        display: none !important;
    }
}
@media (max-width: 767px) {
    .ks-header-ui .ks-search-suggest {
        max-height: 300px;
    }
}
</style>

            <header class="tf-header style-2 ks-header-ui">
    <div class="inner-header">
        <div class="container">
            <div class="row align-items-center">
                <!-- Logo -->
                <div class="col-xl-3 col-md-3 col-7 d-flex align-items-center">
                    <div class="logo-site">
                        <a href="Default.aspx" class="d-inline-block">
                            <asp:Image ID="imgLogo" runat="server" AlternateText="KeepStore" CssClass="lazyload d-none d-md-inline-block" ImageUrl="" />
                            <asp:Image ID="imgLogoMobile" runat="server" AlternateText="KeepStore" CssClass="lazyload d-inline-block d-md-none" ImageUrl="" />
                        </a>
                    </div>
                </div>

                <!-- Search (desktop) -->
                <div class="col-xl-6 col-md-6 d-none d-md-block">
                    <div class="header-center">
                        <div class="form-search-product style-2 active-container" data-ks-search-form="desktop">
                            <div class="select-category">
                                <select name="product_cat" id="product_cat" class="ks-category-native hide-select" style="display:none !important;">
                                    <option value="">Tutte le categorie</option>
                                </select>
                            </div>
                            <span class="br-line type-vertical bg-line"></span>
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" CssClass="" placeholder="Cerca prodotti, codici, EAN, marchi..." AutoCompleteType="Disabled" />
                                <div id="ksSearchSuggestDesktop" class="ks-search-suggest"></div>
                            </fieldset>
                            <button id="btnSearch" runat="server" type="submit" class="btn-submit-form" aria-label="Cerca">
                                <i class="icon-search"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Icons -->
                <div class="col-xl-3 col-md-3 col-5 d-flex align-items-center justify-content-end">
                    <ul class="nav-icon justify-content-end">
                        <li class="nav-account">
                            <a id="lnkAccount" runat="server" class="link nav-icon-item" href="/login.aspx" aria-label="Account">
                                <span class="icon">
                                    <i class="icon icon-user"></i>
                                </span>
                                <span class="body-small">
                                    <asp:MultiView ID="mvLogin" runat="server">
                                        <asp:View ID="vwLoginOff" runat="server">
                                            <span id="lblLogin" runat="server">Accedi</span>
                                        </asp:View>
                                        <asp:View ID="vwLoginOn" runat="server">
                                            <span>Ciao, <asp:Label ID="lblUtente" runat="server" /></span>
                                            <span class="d-none"><asp:Label ID="lblAccesso" runat="server" /></span>
                                        </asp:View>
                                    </asp:MultiView>
                                </span>
                            </a>
                        </li>

                        <li class="nav-cart">
                            <a class="link nav-icon-item position-relative" href="carrello.aspx" aria-label="Carrello">
                                <span class="icon">
                                    <i class="icon icon-cart"></i>
                                </span>
                                <span class="body-small d-none d-xl-inline">
                                    <span class="text-secondary">Carrello:</span>
                                    <strong class="text-secondary"><asp:Label ID="lblCarrelloTotale" runat="server" Text="0,00" /></strong>
                                </span>
                                <span class="badge bg-primary position-absolute" style="top:-6px; right:-6px;">
                                    <asp:Label ID="lblCarrelloCount" runat="server" Text="0" />
                                </span>
                            </a>
                        </li>

                        <li class="d-none"><asp:Label ID="lblWishlistCount" runat="server" Text="0" Visible="false" /></li>

                        <li class="d-flex align-items-center d-xl-none">
                            <a class="mobile-button" data-bs-toggle="offcanvas" href="#mobileMenu" aria-controls="mobileMenu" aria-label="Menu">
                                <span></span>
                            </a>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
    </div>

    <!-- NAV (desktop) -->
    <div class="header-bottom bg_white d-none d-xl-block">
        <div class="container">
            <div class="header-bottom_wrap">
                <!-- Category mega menu (settori -> categorie -> tipologie) -->
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
                                        <a href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
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
                                                                            <li>
                                                                                <a class="sub-menu-link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                                            </li>
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

                <!-- Main navigation -->
                <nav class="box-navigation text-center">
                    <ul class="box-nav-ul d-flex align-items-center justify-content-center">
                        <li class="menu-item">
                            <a href="Default.aspx" class="item-link">Home</a>
                        </li>
                        <li class="menu-item">
                            <a href="articoli.aspx" class="item-link">Catalogo</a>
                        </li>
                        <li class="menu-item">
                            <a href="Contattaci.aspx" class="item-link">Contatti</a>
                        </li>
                    </ul>
                </nav>
            </div>
        </div>
    </div>
</header>

<!-- Mobile Menu -->
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
            <div class="form-search-product style-2 active-container" data-ks-search-form="mobile">
                <div class="select-category d-none d-sm-block">
                    <select name="product_cat_mobile" id="product_cat_mobile" class="ks-category-native hide-select" style="display:none !important;">
                        <option value="">Tutte le categorie</option>
                    </select>
                </div>
                <span class="br-line type-vertical bg-line d-none d-sm-block"></span>
                <fieldset>
                    <asp:TextBox ID="tbCercaMobile" runat="server" CssClass="" placeholder="Cerca prodotti, codici, EAN, marchi..." AutoPostBack="true" AutoCompleteType="Disabled" />
                    <div id="ksSearchSuggestMobile" class="ks-search-suggest"></div>
                </fieldset>
                <button id="btnSearchMobile" runat="server" type="submit" class="btn-submit-form" aria-label="Cerca">
                    <i class="icon-search"></i>
                </button>
            </div>
        </div>

        <div class="mb-3">
            <a id="lnkAccountMobile" runat="server" class="tf-btn btn-line w-100" href="/login.aspx">Area personale</a>
        </div>

        <div class="mb-3">
            <a class="tf-btn btn-line w-100" href="carrello.aspx">Carrello</a>
        </div>

        <div class="wrap-sidebar-account">
            <ul class="myaccount-nav content-append">
                <li><a href="Default.aspx" class="myaccount-nav-item">Home</a></li>
                <li><a href="articoli.aspx" class="myaccount-nav-item">Catalogo</a></li>
            </ul>
        </div>

        <!-- Mobile catalog menu mount:
             - se i repeater mobile sono già bindati lato server, renderizzano qui.
             - altrimenti, JS clona dal menu desktop (ks-page-flags.js) per mantenere coerenza 1:1 col template.
        -->
        <div class="mt-4" id="ksMobileNavMount">
            <div class="wrap-sidebar-account">
                <ul class="myaccount-nav content-append">
                    <asp:Repeater ID="rptNavSettoriMobile" runat="server">
                        <ItemTemplate>
                            <li class="myaccount-nav-item fw-semibold">
                                <a class="myaccount-nav-item" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                <asp:Repeater ID="rptNavCategorieMobile" runat="server">
                                    <ItemTemplate>
                                        <div class="ms-3 mt-2">
                                            <a class="link text-secondary fw-semibold" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                            <ul class="list-unstyled ms-3 mt-2">
                                                <asp:Repeater ID="rptNavTipologieMobile" runat="server">
                                                    <ItemTemplate>
                                                        <li class="mb-1">
                                                            <a class="link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                        </li>
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
    var RECENT_SEARCH_KEY = 'ks_recent_searches';
    var RECENT_SEARCH_COOKIE = 'ks_recent_searches';

    function normalize(value) {
        return (value || '').toString().toLowerCase().trim().replace(/\s+/g, ' ');
    }

    function escapeHtml(value) {
        return (value || '').toString().replace(/[&<>"]/g, function (ch) {
            return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[ch] || ch;
        });
    }

    function uniqBy(items, keyFn) {
        var seen = new Set();
        return (items || []).filter(function (item) {
            var key = keyFn(item);
            if (!key || seen.has(key)) return false;
            seen.add(key);
            return true;
        });
    }

    function readCookie(name) {
        var match = document.cookie.match(new RegExp('(?:^|; )' + name.replace(/[.$?*|{}()\[\]\/+^]/g, '\$&') + '=([^;]*)'));
        return match ? decodeURIComponent(match[1]) : '';
    }

    function writeCookie(name, value, days) {
        var expires = '';
        if (typeof days === 'number') {
            var dt = new Date();
            dt.setTime(dt.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = '; expires=' + dt.toUTCString();
        }
        document.cookie = name + '=' + encodeURIComponent(value || '') + expires + '; path=/; SameSite=Lax';
    }

    function readRecentSearches() {
        var local = [];
        try {
            var raw = JSON.parse(localStorage.getItem(RECENT_SEARCH_KEY) || '[]');
            local = Array.isArray(raw) ? raw : [];
        } catch (e) { }
        var cookie = (readCookie(RECENT_SEARCH_COOKIE) || '').split('|').filter(Boolean);
        return uniqBy(local.concat(cookie), function (item) { return normalize(item); }).slice(0, 8);
    }

    function storeRecentSearch(query) {
        var q = (query || '').trim();
        if (!q) return;
        var arr = readRecentSearches().filter(function (item) { return normalize(item) !== normalize(q); });
        arr.unshift(q);
        arr = arr.slice(0, 8);
        try {
            localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(arr));
        } catch (e) { }
        writeCookie(RECENT_SEARCH_COOKIE, arr.join('|'), 60);
    }

    function clearAdjacentCustomSelect(select) {
        if (!select) return;
        while (select.nextElementSibling && (select.nextElementSibling.classList.contains('tf-select-custom') || select.nextElementSibling.classList.contains('select-options') || select.nextElementSibling.hasAttribute('data-ks-generated'))) {
            select.nextElementSibling.remove();
        }
    }

    function buildSelectOptions(select) {
        if (!select) return [];
        var links = Array.from(document.querySelectorAll('#ksDesktopCategoriesMenu a, .ks-home-departments .menu-category-list a'));
        var items = [{ label: 'Tutte le categorie', value: '', url: '' }];
        links.forEach(function (link) {
            var text = (link.textContent || '').trim();
            var href = link.getAttribute('href') || '';
            if (!text || !href || href === '#' || href.indexOf('javascript:') === 0) return;
            items.push({ label: text, value: text, url: href });
        });
        items = uniqBy(items, function (x) { return normalize(x.label) + '|' + normalize(x.url); });
        select.innerHTML = '';
        items.forEach(function (item, index) {
            var option = document.createElement('option');
            option.value = item.value;
            option.textContent = item.label;
            option.setAttribute('data-url', item.url);
            if (index === 0) option.selected = true;
            select.appendChild(option);
        });
        return items;
    }

    function buildCustomSelect(select) {
        if (!select) return;
        clearAdjacentCustomSelect(select);
        select.classList.add('hide-select');

        var custom = document.createElement('div');
        custom.className = 'tf-select-custom';
        custom.setAttribute('data-ks-generated','1');
        custom.innerHTML = '<span class="current">' + escapeHtml(select.options[select.selectedIndex] ? select.options[select.selectedIndex].text : 'Tutte le categorie') + '</span><i class="icon icon-chevron-down"></i>' ;
        select.insertAdjacentElement('afterend', custom);

        var list = document.createElement('ul');
        list.className = 'select-options';
        list.setAttribute('data-ks-generated','1');
        Array.from(select.options).forEach(function (option) {
            var li = document.createElement('li');
            li.className = 'link';
            li.setAttribute('rel', option.value);
            li.setAttribute('data-url', option.getAttribute('data-url') || '');
            li.innerHTML = '<span>' + escapeHtml(option.text) + '</span>';
            list.appendChild(li);
        });
        custom.insertAdjacentElement('afterend', list);

        custom.addEventListener('click', function (ev) {
            ev.stopPropagation();
            document.querySelectorAll('.tf-select-custom.active').forEach(function (item) {
                if (item !== custom) {
                    item.classList.remove('active');
                    if (item.nextElementSibling) item.nextElementSibling.style.display = 'none';
                }
            });
            custom.classList.toggle('active');
            list.style.display = custom.classList.contains('active') ? 'block' : 'none';
        });

        list.querySelectorAll('li').forEach(function (li, idx) {
            li.addEventListener('click', function (ev) {
                ev.stopPropagation();
                if (select.options[idx]) {
                    select.selectedIndex = idx;
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                }
                var current = custom.querySelector('.current'); if (current) { current.textContent = li.textContent.trim(); } else { custom.textContent = li.textContent.trim(); }
                custom.classList.remove('active');
                list.style.display = 'none';
            });
        });

        document.addEventListener('click', function () {
            custom.classList.remove('active');
            list.style.display = 'none';
        });
    }

    function collectProducts() {
        var items = [];
        document.querySelectorAll('.card-product').forEach(function (card) {
            var action = card.querySelector('.js-ks-compare');
            var link = card.querySelector('a[href*="articolo.aspx?id="]');
            var titleEl = card.querySelector('.name-product');
            if (!link || !titleEl) return;
            var href = (action && action.getAttribute('data-ks-url')) || link.getAttribute('href') || '';
            var id = (action && action.getAttribute('data-ks-id')) || ((href.match(/id=(\d+)/i) || [])[1] || '');
            var title = (action && action.getAttribute('data-ks-title')) || (titleEl.textContent || '').trim();
            var caption = (card.querySelector('.caption') || {}).textContent || '';
            var price = (action && action.getAttribute('data-ks-price')) || ((card.querySelector('.new-price') || {}).textContent || '');
            var img = (action && action.getAttribute('data-ks-img')) || '';
            if (!img) {
                var imgNode = card.querySelector('img.img-product, .card-image img, .tf-image-view img');
                img = imgNode ? (imgNode.getAttribute('src') || imgNode.getAttribute('data-src') || '') : '';
            }
            var ean = action ? (action.getAttribute('data-ks-ean') || '') : '';
            var brand = action ? (action.getAttribute('data-ks-brand') || '') : '';
            var desc = action ? (action.getAttribute('data-ks-desc') || '') : '';
            var longDesc = action ? (action.getAttribute('data-ks-desc-long') || action.getAttribute('data-ks-desc') || '') : '';
            var refurbished = action ? (action.getAttribute('data-ks-refurbished') || '0') : '0';
            var code = action ? (action.getAttribute('data-ks-code') || '') : '';
            if (!id || !title) return;
            items.push({
                type: 'product',
                key: 'p-' + id,
                id: id,
                code: code,
                ean: ean,
                brand: brand,
                desc: desc,
                title: title,
                subtitle: [brand, caption.trim() || 'Prodotto'].filter(Boolean).join(' • '),
                price: (price || '').trim(),
                url: href,
                image: img,
                search: normalize([title, caption, brand, desc, longDesc, code, ean, id, brand + ' ' + title, brand + ' ' + desc].join(' ')),
                refurbished: refurbished
            });
        });
        return uniqBy(items, function (x) { return x.key; });
    }

    function collectCategories() {
        var items = [];
        document.querySelectorAll('#ksDesktopCategoriesMenu a, .ks-home-departments .menu-category-list a').forEach(function (link, index) {
            var title = (link.textContent || '').trim();
            var url = link.getAttribute('href') || '';
            if (!title || !url) return;
            items.push({ type: 'category', key: 'c-' + index + '-' + normalize(title), title: title, subtitle: 'Categoria', price: '', url: url, image: '', search: normalize(title) });
        });
        return uniqBy(items, function (x) { return x.url + '|' + x.title; });
    }

    function scoreItem(item, query) {
        if (!item || !query) return 0;
        var q = normalize(query);
        var text = normalize(item.search || item.title || '');
        if (!text) return 0;
        var ean = normalize(item.ean || '');
        var code = normalize(item.code || '');
        var brand = normalize(item.brand || '');
        var desc = normalize(item.desc || '');
        var title = normalize(item.title || '');
        var longDesc = normalize(item.longDesc || '');
        var brandTitle = normalize([brand, title].join(' '));
        var brandDesc = normalize([brand, desc, longDesc].join(' '));
        if (ean && ean === q) return 220;
        if (code && code === q) return 210;
        if (title === q) return 195;
        if (brandTitle === q) return 190;
        if (brand && desc && brandDesc.indexOf(q) >= 0) return 175;
        if (brand && title && brandTitle.indexOf(q) >= 0) return 170;
        if (title.indexOf(q) === 0) return 160;
        if (desc.indexOf(q) >= 0 || longDesc.indexOf(q) >= 0) return 145;
        if (text.indexOf(q + ' ') === 0 || text.startsWith(q)) return 135;
        if (text.indexOf(q) >= 0) return 120;
        return 0;
    }

    function buildSuggestions(query) {
        var q = (query || '').trim();
        if (!q) {
            return {
                products: [],
                categories: [],
                recents: readRecentSearches().map(function (value, idx) {
                    return { type: 'recent', key: 'r-' + idx, title: value, subtitle: 'Ricerca recente', url: '', image: '', price: '', search: normalize(value) };
                }).slice(0, 5)
            };
        }
        var products = collectProducts().map(function (item) { item._score = scoreItem(item, q); return item; }).filter(function (item) { return item._score > 0; }).sort(function (a, b) { return b._score - a._score; }).slice(0, 8);
        var categories = collectCategories().map(function (item) { item._score = scoreItem(item, q); return item; }).filter(function (item) { return item._score > 0; }).sort(function (a, b) { return b._score - a._score; }).slice(0, 5);
        var recents = readRecentSearches().filter(function (item) { return normalize(item).indexOf(normalize(q)) >= 0; }).slice(0, 4).map(function (value, idx) {
            return { type: 'recent', key: 'r-' + idx, title: value, subtitle: 'Ricerca recente', url: '', image: '', price: '', search: normalize(value) };
        });
        return { products: products, categories: categories, recents: recents };
    }

    function renderGroup(label, items) {
        if (!items || !items.length) return '';
        return '<div class="ks-search-group"><span class="ks-search-label">' + escapeHtml(label) + '</span>' + items.map(function (item) {
            var image = item.image ? '<img src="' + escapeHtml(item.image) + '" alt="">' : '<span class="box-icon btn-icon-action"><i class="icon ' + (item.type === 'category' ? 'icon-menu' : 'icon-search') + '"></i></span>';
            var sub = [item.subtitle || '', item.price || ''].filter(Boolean).join(' • ');
            return '<button type="button" class="ks-search-item" data-ks-type="' + escapeHtml(item.type) + '" data-ks-title="' + escapeHtml(item.title) + '" data-ks-url="' + escapeHtml(item.url || '') + '">' + image + '<span class="ks-search-meta"><span class="ks-search-title">' + escapeHtml(item.title) + '</span><span class="ks-search-sub">' + escapeHtml(sub) + '</span></span></button>';
        }).join('') + '</div>';
    }

    function selectedCategoryUrl(select) {
        if (!select) return '';
        var option = select.options[select.selectedIndex];
        return option ? (option.getAttribute('data-url') || '') : '';
    }

    function findDirectProductMatch(query) {
        var q = normalize(query);
        if (!q) return null;
        var matches = collectProducts().map(function (item) {
            item._score = scoreItem(item, q);
            return item;
        }).filter(function (item) {
            return item && item.url && item._score >= 170;
        }).sort(function (a, b) {
            return b._score - a._score;
        });
        return matches.length ? matches[0] : null;
    }

    function buildSearchUrl(query, select) {
        var q = (query || '').trim();
        var direct = findDirectProductMatch(q);
        if (direct && direct.url) return direct.url;
        var categoryUrl = selectedCategoryUrl(select);
        if (categoryUrl) {
            if (!q) return categoryUrl;
            var glue = categoryUrl.indexOf('?') >= 0 ? '&' : '?';
            return categoryUrl + glue + 'q=' + encodeURIComponent(q);
        }
        return 'articoli.aspx?q=' + encodeURIComponent(q);
    }

    function buildProductImageCandidates(rawUrl) {
        var src = (rawUrl || '').toString().trim();
        if (!src) return [];
        src = src.replace(/\\/g, '/');
        var fileName = src.split('/').pop().split('?')[0].split('#')[0];
        if (!fileName) return [];
        var lowFile = fileName.charAt(0) === '_' ? fileName : '_' + fileName;
        var pathName = (window.location.pathname || '').toLowerCase();
        var preferLow = !pathName || pathName === '/' || pathName.indexOf('/default.aspx') >= 0 || pathName.indexOf('/carrello.aspx') >= 0;
        var candidates = preferLow
            ? ['/Public/assets/images/articoli/' + lowFile, '/Public/assets/images/articoli/' + fileName]
            : ['/Public/assets/images/articoli/' + fileName, '/Public/assets/images/articoli/' + lowFile];
        return uniqBy(candidates, function (item) { return item; });
    }

    function probeImage(url, onOk, onFail) {
        var probe = new Image();
        probe.onload = function () { onOk(); };
        probe.onerror = function () { onFail(); };
        probe.src = url;
    }

    function normalizeLegacyProductImages() {
        var selector = [
            'img[src*="/Public/images/articoli/"]',
            'img[src*="/Images/articoli/"]',
            'img[data-src*="/Public/images/articoli/"]',
            'img[data-src*="/Images/articoli/"]'
        ].join(',');

        document.querySelectorAll(selector).forEach(function (img) {
            if (!img || img.getAttribute('data-ks-normalized') === '1') return;
            var current = img.getAttribute('data-src') || img.getAttribute('src') || '';
            var candidates = buildProductImageCandidates(current);
            if (!candidates.length) return;
            img.setAttribute('data-ks-normalized', '1');
            (function tryNext(index) {
                if (index >= candidates.length) return;
                probeImage(candidates[index], function () {
                    if (img.hasAttribute('src')) img.setAttribute('src', candidates[index]);
                    if (img.hasAttribute('data-src')) img.setAttribute('data-src', candidates[index]);
                }, function () {
                    tryNext(index + 1);
                });
            })(0);
        });
    }

    function wireForm(opts) {
        var input = document.getElementById(opts.inputId);
        var suggest = document.getElementById(opts.suggestId);
        var button = document.getElementById(opts.buttonId);
        var select = document.getElementById(opts.selectId);
        if (!input || !suggest || !button) return;
        var timer = 0;

        function closeSuggest() { suggest.classList.remove('show'); }
        function openSuggest() { suggest.classList.add('show'); }
        function renderNow() {
            var groups = buildSuggestions(input.value);
            suggest.innerHTML = renderGroup('Prodotti', groups.products) + renderGroup('Categorie', groups.categories) + renderGroup('Ricerche recenti', groups.recents);
            if (suggest.innerHTML.trim()) openSuggest(); else closeSuggest();
        }
        function render() {
            clearTimeout(timer);
            timer = setTimeout(renderNow, 120);
        }
        function submitSearch(forceValue, forceUrl) {
            var value = typeof forceValue === 'string' ? forceValue : input.value;
            var url = forceUrl || buildSearchUrl(value, select);
            if (!(value || '').trim() && !forceUrl && !selectedCategoryUrl(select)) {
                closeSuggest();
                return;
            }
            if ((value || '').trim()) storeRecentSearch(value);
            window.location.href = url;
        }

        input.addEventListener('input', render);
        input.addEventListener('focus', renderNow);
        input.addEventListener('keydown', function (ev) {
            if (ev.key === 'Enter') {
                ev.preventDefault();
                submitSearch();
            }
        });
        if (select) {
            select.addEventListener('change', function () {
                if ((input.value || '').trim()) renderNow();
            });
        }
        button.addEventListener('click', function (ev) {
            ev.preventDefault();
            submitSearch();
        });
        suggest.addEventListener('click', function (ev) {
            var item = ev.target.closest('.ks-search-item');
            if (!item) return;
            ev.preventDefault();
            var type = item.getAttribute('data-ks-type');
            var title = item.getAttribute('data-ks-title') || '';
            var url = item.getAttribute('data-ks-url') || '';
            if (type === 'product' || type === 'category') {
                submitSearch(title, url || buildSearchUrl(title, select));
                return;
            }
            input.value = title;
            submitSearch(title);
        });
        document.addEventListener('click', function (ev) {
            if (!ev.target.closest('[data-ks-search-form="' + opts.formName + '"]')) closeSuggest();
        });
    }


    function enforceAccountLinks() {
        var accountUrl = '<%= ResolveUrl("~/login.aspx") %>';
        var account = document.getElementById('<%= lnkAccount.ClientID %>');
        var accountMobile = document.getElementById('<%= lnkAccountMobile.ClientID %>');
        if (account && account.getAttribute('href') !== accountUrl && account.getAttribute('href') !== '<%= ResolveUrl("~/myaccount.aspx") %>') {
            account.setAttribute('href', accountUrl);
        }
        if (accountMobile && accountMobile.getAttribute('href') !== accountUrl && accountMobile.getAttribute('href') !== '<%= ResolveUrl("~/myaccount.aspx") %>') {
            accountMobile.setAttribute('href', accountUrl);
        }
    }

    function wireDesktopCategories() {
        var wrap = document.querySelector('.ks-header-ui .nav-category-wrap');
        if (!wrap) return;
        var title = wrap.querySelector('.nav-title.btn-active');
        var menu = wrap.querySelector('.category-menu');
        if (title && menu) {
            title.addEventListener('click', function (ev) {
                ev.preventDefault();
                title.classList.toggle('active');
                menu.classList.toggle('active-item');
            });
        }
        var items = wrap.querySelectorAll('#ksDesktopCategoriesMenu > .item');
        items.forEach(function (item) {
            var link = item.querySelector(':scope > a');
            var sub = item.querySelector(':scope > .sub-menu');
            if (!link || !sub) return;
            item.addEventListener('mouseenter', function () {
                items.forEach(function (other) { if (other !== item) other.classList.remove('open'); });
                item.classList.add('open');
            });
            link.addEventListener('click', function (ev) {
                if (!item.classList.contains('open')) {
                    ev.preventDefault();
                    items.forEach(function (other) { if (other !== item) other.classList.remove('open'); });
                    item.classList.add('open');
                }
            });
        });
        document.addEventListener('click', function (ev) {
            if (!ev.target.closest('.ks-header-ui .nav-category-wrap')) {
                items.forEach(function (item) { item.classList.remove('open'); });
            }
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var desktopSelect = document.getElementById('product_cat');
        var mobileSelect = document.getElementById('product_cat_mobile');
        buildSelectOptions(desktopSelect);
        buildSelectOptions(mobileSelect);
        buildCustomSelect(desktopSelect);
        buildCustomSelect(mobileSelect);
        wireForm({ formName: 'desktop', inputId: '<%= tbCerca.ClientID %>', suggestId: 'ksSearchSuggestDesktop', buttonId: '<%= btnSearch.ClientID %>', selectId: 'product_cat' });
        wireForm({ formName: 'mobile', inputId: '<%= tbCercaMobile.ClientID %>', suggestId: 'ksSearchSuggestMobile', buttonId: '<%= btnSearchMobile.ClientID %>', selectId: 'product_cat_mobile' });
        wireDesktopCategories();
        enforceAccountLinks();
        normalizeLegacyProductImages();
    });
})();
</script>
