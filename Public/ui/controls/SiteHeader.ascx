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
                                <select name="product_cat" id="product_cat" class="dropdown_product_cat">
                                    <option value="">Tutte le categorie</option>
                                </select>
                            </div>
                            <span class="br-line type-vertical bg-line"></span>
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" CssClass="" placeholder="Cerca prodotti, codici, marchi..." AutoCompleteType="Disabled" />
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
                            <a id="lnkAccount" runat="server" class="link nav-icon-item" href="myaccount.aspx" aria-label="Account">
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
                    <select name="product_cat_mobile" id="product_cat_mobile" class="dropdown_product_cat">
                        <option value="">Tutte le categorie</option>
                    </select>
                </div>
                <span class="br-line type-vertical bg-line d-none d-sm-block"></span>
                <fieldset>
                    <asp:TextBox ID="tbCercaMobile" runat="server" CssClass="" placeholder="Cerca prodotti, codici, marchi..." AutoPostBack="true" AutoCompleteType="Disabled" />
                    <div id="ksSearchSuggestMobile" class="ks-search-suggest"></div>
                </fieldset>
                <button id="btnSearchMobile" runat="server" type="submit" class="btn-submit-form" aria-label="Cerca">
                    <i class="icon-search"></i>
                </button>
            </div>
        </div>

        <div class="mb-3">
            <a id="lnkAccountMobile" runat="server" class="tf-btn btn-line w-100" href="myaccount.aspx">Area personale</a>
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
    function normalize(value) {
        return (value || '').toString().toLowerCase().trim().replace(/\s+/g, ' ');
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
        if (!select || select.nextElementSibling && select.nextElementSibling.classList.contains('tf-select-custom')) return;
        select.classList.add('hide-select');
        var custom = document.createElement('div');
        custom.className = 'tf-select-custom';
        custom.textContent = select.options[0] ? select.options[0].text : 'Tutte le categorie';
        select.insertAdjacentElement('afterend', custom);

        var list = document.createElement('ul');
        list.className = 'select-options';
        Array.from(select.options).forEach(function (option) {
            var li = document.createElement('li');
            li.className = 'link';
            li.setAttribute('rel', option.value);
            li.setAttribute('data-url', option.getAttribute('data-url') || '');
            li.innerHTML = '<span>' + option.text + '</span>';
            list.appendChild(li);
        });
        custom.insertAdjacentElement('afterend', list);

        custom.addEventListener('click', function (ev) {
            ev.stopPropagation();
            document.querySelectorAll('.tf-select-custom.active').forEach(function (item) {
                if (item !== custom) { item.classList.remove('active'); if (item.nextElementSibling) item.nextElementSibling.style.display = 'none'; }
            });
            custom.classList.toggle('active');
            list.style.display = custom.classList.contains('active') ? 'block' : 'none';
        });

        list.querySelectorAll('li').forEach(function (li, idx) {
            li.addEventListener('click', function (ev) {
                ev.stopPropagation();
                if (select.options[idx]) {
                    select.selectedIndex = idx;
                }
                custom.textContent = li.textContent.trim();
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
            var link = card.querySelector('a[href*="articolo.aspx?id="]');
            var titleEl = card.querySelector('.name-product');
            if (!link || !titleEl) return;
            var href = link.getAttribute('href') || '';
            var idMatch = href.match(/id=(\d+)/i);
            var id = idMatch ? idMatch[1] : '';
            var title = (titleEl.textContent || '').trim();
            var caption = (card.querySelector('.caption') || {}).textContent || '';
            var price = (card.querySelector('.new-price') || {}).textContent || '';
            var img = (card.querySelector('img.img-product, .card-image img, .tf-image-view img') || {}).getAttribute ? (card.querySelector('img.img-product, .card-image img, .tf-image-view img').getAttribute('src') || '') : '';
            if (!id || !title) return;
            items.push({ type: 'product', key: 'p-' + id, id: id, title: title, subtitle: caption.trim() || 'Prodotto', price: price.trim(), url: href, image: img, search: normalize(title + ' ' + caption + ' ' + id) });
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

    function recentSearches() {
        try {
            var arr = JSON.parse(localStorage.getItem('ks_recent_searches') || '[]');
            return Array.isArray(arr) ? arr : [];
        } catch (e) {
            return [];
        }
    }

    function storeRecentSearch(query) {
        var q = (query || '').trim();
        if (!q) return;
        var arr = recentSearches().filter(function (item) { return normalize(item) !== normalize(q); });
        arr.unshift(q);
        localStorage.setItem('ks_recent_searches', JSON.stringify(arr.slice(0, 8)));
    }

    function scoreItem(item, query) {
        if (!item || !query) return 0;
        var q = normalize(query);
        var text = normalize(item.search || item.title || '');
        if (!text) return 0;
        if (text === q) return 120;
        if ((item.id || '') === q) return 115;
        if (text.indexOf(q + ' ') === 0 || text.startsWith(q)) return 100;
        var tokens = text.split(' ');
        if (tokens.some(function (token) { return token.startsWith(q); })) return 85;
        if (text.indexOf(q) >= 0) return 65;
        return 0;
    }

    function buildSuggestions(query) {
        var q = (query || '').trim();
        if (!q) {
            return { products: [], categories: [], recents: recentSearches().map(function (value, idx) { return { type: 'recent', key: 'r-' + idx, title: value, subtitle: 'Ricerca recente', url: '', image: '', price: '', search: normalize(value) }; }).slice(0, 5) };
        }
        var products = collectProducts().map(function (item) { item._score = scoreItem(item, q); return item; }).filter(function (item) { return item._score > 0; }).sort(function (a, b) { return b._score - a._score; }).slice(0, 6);
        var categories = collectCategories().map(function (item) { item._score = scoreItem(item, q); return item; }).filter(function (item) { return item._score > 0; }).sort(function (a, b) { return b._score - a._score; }).slice(0, 5);
        var recents = recentSearches().filter(function (item) { return normalize(item).indexOf(normalize(q)) >= 0; }).slice(0, 4).map(function (value, idx) { return { type: 'recent', key: 'r-' + idx, title: value, subtitle: 'Ricerca recente', url: '', image: '', price: '', search: normalize(value) }; });
        return { products: products, categories: categories, recents: recents };
    }

    function renderGroup(label, items) {
        if (!items || !items.length) return '';
        return '<div class="ks-search-group"><span class="ks-search-label">' + label + '</span>' + items.map(function (item) {
            var image = item.image ? '<img src="' + item.image + '" alt="">' : '<span class="box-icon btn-icon-action"><i class="icon ' + (item.type === 'category' ? 'icon-menu' : 'icon-search') + '"></i></span>';
            var sub = [item.subtitle || '', item.price || ''].filter(Boolean).join(' • ');
            return '<button type="button" class="ks-search-item" data-ks-type="' + item.type + '" data-ks-title="' + item.title.replace(/"/g, '&quot;') + '" data-ks-url="' + (item.url || '').replace(/"/g, '&quot;') + '">' + image + '<span class="ks-search-meta"><span class="ks-search-title">' + item.title + '</span><span class="ks-search-sub">' + sub + '</span></span></button>';
        }).join('') + '</div>';
    }

    function selectedCategoryUrl(select) {
        if (!select) return '';
        var option = select.options[select.selectedIndex];
        return option ? (option.getAttribute('data-url') || '') : '';
    }

    function buildSearchUrl(query, select) {
        var q = (query || '').trim();
        var categoryUrl = selectedCategoryUrl(select);
        if (categoryUrl) {
            if (!q) return categoryUrl;
            var glue = categoryUrl.indexOf('?') >= 0 ? '&' : '?';
            return categoryUrl + glue + 'q=' + encodeURIComponent(q);
        }
        return 'articoli.aspx?q=' + encodeURIComponent(q);
    }

    function wireForm(opts) {
        var input = document.getElementById(opts.inputId);
        var suggest = document.getElementById(opts.suggestId);
        var button = document.getElementById(opts.buttonId);
        var select = document.getElementById(opts.selectId);
        if (!input || !suggest || !button) return;

        function closeSuggest() { suggest.classList.remove('show'); }

        function openSuggest() { suggest.classList.add('show'); }

        function render() {
            var groups = buildSuggestions(input.value);
            suggest.innerHTML = renderGroup('Prodotti', groups.products) + renderGroup('Categorie', groups.categories) + renderGroup('Ricerche recenti', groups.recents);
            if (suggest.innerHTML.trim()) openSuggest(); else closeSuggest();
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
        input.addEventListener('focus', render);
        input.addEventListener('keydown', function (ev) {
            if (ev.key === 'Enter') {
                ev.preventDefault();
                submitSearch();
            }
        });
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

    document.addEventListener('DOMContentLoaded', function () {
        var desktopSelect = document.getElementById('product_cat');
        var mobileSelect = document.getElementById('product_cat_mobile');
        buildSelectOptions(desktopSelect);
        buildSelectOptions(mobileSelect);
        buildCustomSelect(desktopSelect);
        buildCustomSelect(mobileSelect);

        wireForm({ formName: 'desktop', inputId: '<%= tbCerca.ClientID %>', suggestId: 'ksSearchSuggestDesktop', buttonId: '<%= btnSearch.ClientID %>', selectId: 'product_cat' });
        wireForm({ formName: 'mobile', inputId: '<%= tbCercaMobile.ClientID %>', suggestId: 'ksSearchSuggestMobile', buttonId: '<%= btnSearchMobile.ClientID %>', selectId: 'product_cat_mobile' });
    });
})();
</script>
