(function () {
  'use strict';

  var RECENT_SEARCH_KEY = 'ks_recent_searches';
  var COMPARE_KEY = 'ks_compare_items';

  function normalizePath(p) {
    try {
      return (p || '')
        .toLowerCase()
        .replace(/\/+$/, '')
        .replace(/\.aspx(\?.*)?$/, '.aspx');
    } catch (e) {
      return (p || '').toLowerCase();
    }
  }

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function qs(name) {
    try {
      var u = new URL(window.location.href);
      return u.searchParams.get(name);
    } catch (e) {
      return null;
    }
  }

  function addClass(el, cls) {
    if (!el || !cls) return;
    if (el.classList) el.classList.add(cls);
  }

  function isAccountPath(path) {
    var p = normalizePath(path);
    return (
      p.endsWith('/myaccount.aspx') ||
      p.endsWith('/datiutente.aspx') ||
      p.endsWith('/indirizzi.aspx') ||
      p.endsWith('/password.aspx') ||
      p.endsWith('/wishlist.aspx') ||
      p.endsWith('/documenti.aspx') ||
      p.endsWith('/ordini.aspx') ||
      p.endsWith('/ordine.aspx') ||
      p.endsWith('/logout.aspx')
    );
  }

  function setBodyFlags() {
    var body = document.body;
    if (!body) return;

    var path = normalizePath(window.location.pathname);
    addClass(body, 'ks-ready');

    if (isAccountPath(path)) {
      addClass(body, 'ks-page-account');

      if (path.endsWith('/documenti.aspx')) {
        var docType = qs('t');
        if (docType) body.setAttribute('data-doc-type', docType);
      }
      if (path.endsWith('/ordine.aspx')) {
        var orderId = qs('id');
        if (orderId) body.setAttribute('data-order-id', orderId);
      }
    }
  }

  function setActiveSidebar() {
    var aside = document.querySelector('.ks-account-aside');
    if (!aside) return;

    var path = normalizePath(window.location.pathname);
    var docType = qs('t');
    var links = Array.prototype.slice.call(aside.querySelectorAll('a[href]'));
    if (!links.length) return;

    function normalizeHref(href) {
      try {
        var u = new URL(href, window.location.origin);
        return {
          path: normalizePath(u.pathname),
          docType: u.searchParams.get('t')
        };
      } catch (e) {
        return { path: normalizePath(href), docType: null };
      }
    }

    var best = null;
    links.forEach(function (a) {
      var n = normalizeHref(a.getAttribute('href'));
      if (!n.path) return;
      if (n.path === path) {
        if (path.endsWith('/documenti.aspx')) {
          if (n.docType && docType && n.docType === docType) best = a;
          else if (!best && !n.docType) best = a;
        } else {
          best = a;
        }
      }
    });

    if (!best) {
      links.forEach(function (a) {
        var n = normalizeHref(a.getAttribute('href'));
        if (n.path && path.indexOf(n.path) !== -1) best = a;
      });
    }

    if (!best) return;

    links.forEach(function (a) {
      a.classList.remove('active');
      if (a.parentElement) a.parentElement.classList.remove('active');
    });

    best.classList.add('active');
    if (best.parentElement) best.parentElement.classList.add('active');
  }

  function tryMarkLegacyAccountNav() {
    var content = document.querySelector('.ks-account-content');
    if (!content) return;

    var uls = Array.prototype.slice.call(content.querySelectorAll('ul'));
    for (var i = 0; i < uls.length; i++) {
      var ul = uls[i];
      if (ul.classList.contains('ks-account-nav')) continue;

      var links = ul.querySelectorAll('a[href]');
      if (!links || links.length < 4) continue;

      var score = 0;
      for (var j = 0; j < links.length; j++) {
        var href = (links[j].getAttribute('href') || '').toLowerCase();
        if (href.indexOf('.aspx') !== -1) score++;
      }

      if (score >= 3) {
        ul.classList.add('ks-account-nav');
        break;
      }
    }
  }

  function hideLegacyAccountNavIfSidebarPresent() {
    var aside = document.querySelector('.ks-account-aside');
    var content = document.querySelector('.ks-account-content');
    if (!aside || !content) return;

    Array.prototype.slice.call(content.querySelectorAll('ul.ks-account-nav')).forEach(function (ul) {
      ul.style.display = 'none';
    });
  }

  function safeStorageGet(key, fallback) {
    try {
      var value = window.localStorage.getItem(key);
      if (!value) return fallback;
      return JSON.parse(value);
    } catch (e) {
      return fallback;
    }
  }

  function safeStorageSet(key, value) {
    try {
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {}
  }

  function getCompareItems() {
    var items = safeStorageGet(COMPARE_KEY, []);
    return Array.isArray(items) ? items : [];
  }

  function saveCompareItems(items) {
    safeStorageSet(COMPARE_KEY, items);
  }

  function updateCompareCount() {
    var countNode = document.getElementById('ksCompareCount');
    if (!countNode) return;
    countNode.textContent = String(getCompareItems().length);
  }

  function addCompareItem(item) {
    if (!item || !item.id) return;
    var items = getCompareItems();
    var exists = false;

    items = items.filter(function (entry) {
      if (String(entry.id) === String(item.id)) {
        exists = true;
      }
      return String(entry.id) !== String(item.id);
    });

    items.unshift(item);
    if (items.length > 8) {
      items = items.slice(0, 8);
    }

    saveCompareItems(items);
    updateCompareCount();
  }

  function removeCompareItem(id) {
    var items = getCompareItems().filter(function (entry) {
      return String(entry.id) !== String(id);
    });
    saveCompareItems(items);
    updateCompareCount();
    renderCompareDrawer();
    renderComparePage();
  }

  function buildCompareCard(item) {
    return [
      '<article class="ks-compare-card">',
      '<button type="button" class="ks-compare-remove" data-ks-compare-remove="', item.id, '">&times;</button>',
      '<a href="', item.url || '#', '" class="ks-compare-image">',
      '<img src="', item.img || '/Public/assets/images/item/laptop.webp', '" alt="', item.title || '', '">',
      '</a>',
      '<h3><a href="', item.url || '#', '">', escapeHtml(item.title || 'Prodotto'), '</a></h3>',
      item.price ? '<p class="ks-compare-price">' + item.price + '</p>' : '',
      '<div class="ks-compare-actions">',
      '<a class="tf-btn btn-line" href="aggiungi.aspx?id=', item.id, '">Aggiungi al carrello</a>',
      '<a class="tf-btn btn-fill" href="', item.url || '#', '">Vedi prodotto</a>',
      '</div>',
      '</article>'
    ].join('');
  }

  function buildCompareDrawerItem(item) {
    return [
      '<div class="tf-compare-item">',
      '<span class="btns-repeat"><i class="icon icon-compare1"></i></span>',
      '<span class="icon-close remove" data-ks-compare-remove="', item.id, '"></span>',
      '<a href="', item.url || '#', '" class="image">',
      '<img class="lazyload" src="', item.img || '/Public/assets/images/item/laptop.webp', '" alt="', escapeHtml(item.title || ''), '">',
      '</a>',
      '<div class="content">',
      '<a class="text-line-clamp-2 body-md-2 fw-semibold text-secondary link" href="', item.url || '#', '">', escapeHtml(item.title || 'Prodotto'), '</a>',
      item.price ? '<p class="price-wrap fw-medium"><span class="new-price price-text fw-medium">' + escapeHtml(item.price) + '</span></p>' : '',
      '</div>',
      '</div>'
    ].join('');
  }

  function bindCompareRemoveButtons(root) {
    if (!root) return;
    Array.prototype.slice.call(root.querySelectorAll('[data-ks-compare-remove]')).forEach(function (btn) {
      btn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        removeCompareItem(btn.getAttribute('data-ks-compare-remove'));
      });
    });
  }

  function renderCompareDrawer() {
    var drawer = document.getElementById('compare');
    if (!drawer) return;

    var empty = drawer.querySelector('.mini-compare-empty');
    var wrap = drawer.querySelector('.tf-compare-wrap');
    var buttons = drawer.querySelector('.tf-compare-buttons');
    if (!empty || !wrap || !buttons) return;

    var items = getCompareItems().slice(0, 4);
    if (!items.length) {
      wrap.innerHTML = '';
      empty.style.display = '';
      wrap.style.display = 'none';
      buttons.style.display = 'none';
      return;
    }

    empty.style.display = 'none';
    wrap.style.display = '';
    buttons.style.display = '';
    wrap.innerHTML = items.map(buildCompareDrawerItem).join('');
    bindCompareRemoveButtons(wrap);
  }

  function renderComparePage() {
    var shell = document.getElementById('ksCompareShell');
    var empty = document.getElementById('ksCompareEmptyState');
    var grid = document.getElementById('ksCompareGrid');
    if (!shell || !empty || !grid) return;

    var items = getCompareItems();
    if (!items.length) {
      shell.classList.add('d-none');
      empty.classList.remove('d-none');
      grid.innerHTML = '';
      return;
    }

    empty.classList.add('d-none');
    shell.classList.remove('d-none');
    grid.innerHTML = items.map(buildCompareCard).join('');
    bindCompareRemoveButtons(grid);
  }

  function openCompareDrawer() {
    var drawer = document.getElementById('compare');
    if (!drawer) return;
    try {
      if (window.bootstrap && bootstrap.Offcanvas) {
        bootstrap.Offcanvas.getOrCreateInstance(drawer).show();
        return;
      }
    } catch (e) {}
    try {
      if (window.jQuery && jQuery.fn && jQuery.fn.offcanvas) {
        jQuery(drawer).offcanvas('show');
      }
    } catch (e) {}
  }

  function parseCompareItem(link) {
    if (!link) return null;
    return {
      id: link.getAttribute('data-ks-id') || '',
      title: link.getAttribute('data-ks-title') || '',
      url: link.getAttribute('data-ks-url') || link.getAttribute('href') || '#',
      img: link.getAttribute('data-ks-img') || '',
      price: link.getAttribute('data-ks-price') || ''
    };
  }

  function initCompareButtons() {
    Array.prototype.slice.call(document.querySelectorAll('.js-ks-compare')).forEach(function (link) {
      link.addEventListener('click', function (event) {
        event.preventDefault();
        addCompareItem(parseCompareItem(link));
        renderCompareDrawer();
        openCompareDrawer();
      });
    });

    Array.prototype.slice.call(document.querySelectorAll('#ksCompareClear, #ksCompareClearDrawer, .tf-compapre-button-clear-all')).forEach(function (clearBtn) {
      clearBtn.addEventListener('click', function (event) {
        event.preventDefault();
        saveCompareItems([]);
        updateCompareCount();
        renderCompareDrawer();
        renderComparePage();
      });
    });

    updateCompareCount();
    renderCompareDrawer();
    renderComparePage();
  }

  function getRecentSearches() {
    var items = safeStorageGet(RECENT_SEARCH_KEY, []);
    return Array.isArray(items) ? items : [];
  }

  function escapeHtml(value) {
    return String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function saveRecentSearch(term) {
    var value = (term || '').trim();
    if (!value) return;
    var items = getRecentSearches().filter(function (entry) {
      return String(entry).toLowerCase() !== value.toLowerCase();
    });
    items.unshift(value);
    if (items.length > 8) {
      items = items.slice(0, 8);
    }
    safeStorageSet(RECENT_SEARCH_KEY, items);
  }

  function measureSelectWidth(select) {
    if (!select || !select.options || !select.options.length) return;

    var canvas = document.createElement('canvas');
    var ctx = canvas.getContext('2d');
    if (!ctx) return;

    var style = window.getComputedStyle(select);
    ctx.font = [style.fontWeight, style.fontSize, style.fontFamily].join(' ');

    var max = 0;
    for (var i = 0; i < select.options.length; i++) {
      max = Math.max(max, ctx.measureText(select.options[i].text || '').width);
    }

    var width = Math.ceil(max + 54) + 'px';
    select.style.width = width;

    var custom = select.nextElementSibling;
    if (custom && custom.classList && custom.classList.contains('tf-select-custom')) {
      custom.style.width = width;
      custom.style.minWidth = width;
    }
  }

  function parseSelectedSector(select) {
    if (!select || !select.value) return '';
    try {
      var url = new URL(select.value, window.location.origin);
      return url.searchParams.get('st') || '';
    } catch (e) {
      return '';
    }
  }

  function fetchSuggestions(term, sectorId) {
    var url = 'search_suggest.aspx?term=' + encodeURIComponent(term) + '&limit=10';
    if (sectorId) {
      url += '&st=' + encodeURIComponent(sectorId);
    }
    return window.fetch(url, { credentials: 'same-origin' })
      .then(function (response) { return response.json(); })
      .catch(function () { return []; });
  }

  function buildSearchResultsUrl(query, select) {
    var value = (query || '').trim();
    var selectedUrl = select && select.value ? String(select.value) : '';
    if (!value && selectedUrl) {
      return selectedUrl;
    }
    if (!value) {
      return 'articoli.aspx';
    }
    if (selectedUrl) {
      return selectedUrl + (selectedUrl.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(value);
    }
    var sectorId = parseSelectedSector(select);
    if (sectorId) {
      return 'articoli.aspx?st=' + encodeURIComponent(sectorId) + '&q=' + encodeURIComponent(value);
    }
    return 'articoli.aspx?q=' + encodeURIComponent(value);
  }

  function buildSuggestMarkup(items, recent, currentValue, resultsUrl) {
    var html = [];

    if (recent && recent.length) {
      html.push('<div class="ks-search-section"><p class="ks-search-section-title">Ricerche recenti</p>');
      recent.forEach(function (entry) {
        html.push('<button type="button" class="ks-search-item is-recent" data-ks-recent-value="', escapeHtml(entry), '">', escapeHtml(entry), '</button>');
      });
      html.push('</div>');
    }

    if (items && items.length) {
      html.push('<div class="ks-search-section"><p class="ks-search-section-title">Suggerimenti live</p>');
      items.forEach(function (item) {
        html.push('<a class="ks-search-item" href="', escapeHtml(item.url || '#'), '">');
        if (item.img) {
          html.push('<span class="ks-search-item-image"><img src="', escapeHtml(item.img), '" alt="', escapeHtml(item.label || item.t || currentValue), '"></span>');
        }
        html.push('<span class="ks-search-item-content">');
        html.push('<span class="ks-search-item-main">', escapeHtml(item.label || item.t || currentValue), '</span>');
        html.push('<span class="ks-search-item-meta">');
        if (item.meta) {
          html.push(escapeHtml(item.meta));
          if (item.type) {
            html.push(' &middot; ');
          }
        }
        if (item.type) {
          html.push(escapeHtml(item.type));
        }
        html.push('</span>');
        html.push('</span>');
        html.push('</a>');
      });
      html.push('</div>');
    }

    if (resultsUrl && currentValue) {
      html.push('<div class="ks-search-section"><a class="ks-search-item is-results-link" href="', escapeHtml(resultsUrl), '"><span class="ks-search-item-content"><span class="ks-search-item-main">Vedi tutti i risultati per "', escapeHtml(currentValue), '"</span><span class="ks-search-item-meta">Ricerca generale o filtrata per reparto</span></span></a></div>');
    }

    if (!html.length) {
      html.push('<div class="ks-search-section"><p class="ks-search-item is-empty">Nessun suggerimento disponibile</p></div>');
    }

    return html.join('');
  }

  function initSearchForm(root) {
    if (!root) return;

    var input = root.querySelector('input[type="text"]');
    var button = root.querySelector('.btn-submit-form');
    var select = root.querySelector('select');
    var suggest = root.querySelector('.ks-search-suggest');
    var lastItems = [];
    var lastTimer = 0;
    var fetchToken = 0;

    if (select) {
      measureSelectWidth(select);
      select.addEventListener('change', function () {
        measureSelectWidth(select);
      });
    }

    function closeSuggest() {
      if (!suggest) return;
      suggest.classList.remove('is-open');
      suggest.innerHTML = '';
    }

    function openSuggest(html) {
      if (!suggest) return;
      suggest.innerHTML = html;
      suggest.classList.add('is-open');

      Array.prototype.slice.call(suggest.querySelectorAll('[data-ks-recent-value]')).forEach(function (btn) {
        btn.addEventListener('click', function () {
          var recentValue = btn.getAttribute('data-ks-recent-value') || '';
          input.value = recentValue;
          lastItems = [];
          submitSearch(buildSearchResultsUrl(recentValue, select));
        });
      });
    }

    function submitSearch(forceUrl) {
      var query = (input && input.value ? input.value : '').trim();
      var exactTaxonomy = null;
      var exactProduct = null;

      if (!forceUrl && query) {
        saveRecentSearch(query);
      }

      lastItems.forEach(function (item) {
        var label = String(item.label || item.t || '').toLowerCase();
        var meta = String(item.meta || '').toLowerCase();
        var normalizedQuery = query.toLowerCase();

        if (!exactTaxonomy && label === normalizedQuery && (item.type === 'Reparto' || item.type === 'Categoria')) {
          exactTaxonomy = item;
        }

        if (!exactProduct && item.type === 'Prodotto') {
          if (meta === normalizedQuery || label === normalizedQuery || Number(item.score || 0) >= 1400) {
            exactProduct = item;
          }
        }
      });

      if (forceUrl) {
        window.location.href = forceUrl;
        return;
      }

      if (!query) {
        window.location.href = buildSearchResultsUrl('', select);
        return;
      }

      if (!(select && select.value) && exactProduct && exactProduct.url) {
        window.location.href = exactProduct.url;
        return;
      }

      if (exactTaxonomy && exactTaxonomy.url) {
        window.location.href = exactTaxonomy.url;
        return;
      }

      window.location.href = buildSearchResultsUrl(query, select);
    }

    function handleInput() {
      if (!input || !suggest) return;
      var value = (input.value || '').trim();
      var recent = getRecentSearches().filter(function (entry) {
        return !value || entry.toLowerCase().indexOf(value.toLowerCase()) !== -1;
      }).slice(0, 4);

      window.clearTimeout(lastTimer);

      if (value.length < 2) {
        lastItems = [];
        openSuggest(buildSuggestMarkup([], recent, value, buildSearchResultsUrl(value, select)));
        return;
      }

      lastTimer = window.setTimeout(function () {
        var currentToken = ++fetchToken;
        fetchSuggestions(value, parseSelectedSector(select)).then(function (items) {
          if (currentToken !== fetchToken) {
            return;
          }
          lastItems = Array.isArray(items) ? items : [];
          openSuggest(buildSuggestMarkup(lastItems, recent, value, buildSearchResultsUrl(value, select)));
        });
      }, 180);
    }

    if (button) {
      button.addEventListener('click', function (event) {
        event.preventDefault();
        submitSearch();
      });
    }

    if (input) {
      input.setAttribute('autocomplete', 'off');
      input.addEventListener('focus', handleInput);
      input.addEventListener('input', handleInput);
      input.addEventListener('keydown', function (event) {
        if (event.key === 'Enter') {
          event.preventDefault();
          submitSearch();
        }
      });
    }

    document.addEventListener('click', function (event) {
      if (!root.contains(event.target)) {
        closeSuggest();
      }
    });
  }

  function initSearchForms() {
    Array.prototype.slice.call(document.querySelectorAll('[data-ks-search-form]')).forEach(initSearchForm);
  }

  function initMobileCatalogMenu() {
    var mount = document.getElementById('ksMobileNavMount');
    var mobileList = mount ? mount.querySelector('.ks-mobile-catalog-list') : null;
    var desktopList = document.getElementById('ksDesktopCategoryMenu');
    var cloneSeed = 0;

    function nextId(prefix) {
      cloneSeed += 1;
      return prefix + cloneSeed;
    }

    function findDirectChild(node, tagName, className) {
      if (!node || !node.children) return null;
      for (var i = 0; i < node.children.length; i++) {
        var child = node.children[i];
        if (tagName && child.tagName !== tagName) continue;
        if (className && (!child.classList || !child.classList.contains(className))) continue;
        return child;
      }
      return null;
    }

    function textOf(node) {
      return (node && node.textContent ? node.textContent : '').replace(/\s+/g, ' ').trim();
    }

    function buildMobileCategoryHtml(column, sectorId) {
      var headingLink = column.querySelector('.ks-desktop-category-heading, .ks-header-catalog-category-link');
      var categoryLabel = textOf(headingLink);
      var categoryUrl = headingLink ? (headingLink.getAttribute('href') || '#') : '#';
      var tipologyLinks = Array.prototype.slice.call(column.querySelectorAll('.ks-desktop-tipology-link, .ks-header-catalog-tipology-link'));

      if (!categoryLabel) {
        return '';
      }

      if (!tipologyLinks.length) {
        return [
          '<li class="nav-mb-item ks-mobile-category-item">',
          '<a class="sub-nav-link body-md-2" href="', escapeHtml(categoryUrl), '">',
          '<span>', escapeHtml(categoryLabel), '</span>',
          '</a>',
          '</li>'
        ].join('');
      }

      var collapseId = nextId('ks-mobile-cloned-category-' + sectorId + '-');
      var html = [
        '<li class="nav-mb-item ks-mobile-category-item">',
        '<a href="#" class="sub-nav-link collapsed" role="button" data-bs-toggle="collapse" data-bs-target="#', escapeHtml(collapseId), '" aria-expanded="false" aria-controls="', escapeHtml(collapseId), '">',
        '<span>', escapeHtml(categoryLabel), '</span>',
        '<span class="btn-open-sub"></span>',
        '</a>',
        '<div id="', escapeHtml(collapseId), '" class="collapse">',
        '<ul class="sub-nav-menu sub-menu-level-2">',
        '<li><a class="sub-nav-link body-md-2" href="', escapeHtml(categoryUrl), '">Vedi tutta la categoria</a></li>'
      ];

      tipologyLinks.forEach(function (tipologyLink) {
        var tipologyLabel = textOf(tipologyLink);
        if (!tipologyLabel) return;
        html.push('<li class="nav-mb-item ks-mobile-tipology-item"><a class="sub-nav-link body-md-2" href="' + escapeHtml(tipologyLink.getAttribute('href') || '#') + '"><span>' + escapeHtml(tipologyLabel) + '</span></a></li>');
      });

      html.push('</ul></div></li>');
      return html.join('');
    }

    function buildMobileSectorHtml(sectorItem) {
      var sectorLink = sectorItem.querySelector('.ks-header-catalog-sector-link') || findDirectChild(sectorItem, 'A', 'item-link');
      if (!sectorLink) return '';

      var sectorId = sectorItem.getAttribute('data-sector-id') || nextId('ks-mobile-cloned-sector-key-');
      var sectorLabel = textOf(sectorLink.querySelector('.ks-desktop-sector-label')) || textOf(sectorLink);
      var sectorUrl = sectorLink.getAttribute('href') || '#';
      var sectorImage = sectorLink.querySelector('img');
      var categoryColumns = [];

      if (sectorItem.classList && sectorItem.classList.contains('ks-header-catalog-column')) {
        categoryColumns = Array.prototype.slice.call(sectorItem.querySelectorAll('.ks-header-catalog-category-block, .ks-header-catalog-category'));
      } else {
        var panel = findDirectChild(sectorItem, 'DIV', 'sub-menu-container');
        categoryColumns = panel ? Array.prototype.slice.call(panel.querySelectorAll('.ks-desktop-category-column')) : [];
      }

      if (!categoryColumns.length) {
        return [
          '<li class="nav-mb-item ks-mobile-sector-item">',
          '<a href="', escapeHtml(sectorUrl), '" class="mb-menu-link">',
          '<span class="ks-mobile-nav-entry">',
          '<span class="ks-mobile-nav-media', sectorImage ? '' : ' is-empty', '">',
          sectorImage ? '<img src="' + escapeHtml(sectorImage.getAttribute('src') || '') + '" alt="' + escapeHtml(sectorLabel) + '" />' : '',
          '</span>',
          '<span class="ks-mobile-nav-label">', escapeHtml(sectorLabel), '</span>',
          '</span>',
          '</a>',
          '</li>'
        ].join('');
      }

      var collapseId = nextId('ks-mobile-cloned-sector-' + sectorId + '-');
      var html = [
        '<li class="nav-mb-item ks-mobile-sector-item">',
        '<a href="#" class="collapsed mb-menu-link" role="button" data-bs-toggle="collapse" data-bs-target="#', escapeHtml(collapseId), '" aria-expanded="false" aria-controls="', escapeHtml(collapseId), '">',
        '<span class="ks-mobile-nav-entry">',
        '<span class="ks-mobile-nav-media', sectorImage ? '' : ' is-empty', '">',
        sectorImage ? '<img src="' + escapeHtml(sectorImage.getAttribute('src') || '') + '" alt="' + escapeHtml(sectorLabel) + '" />' : '',
        '</span>',
        '<span class="ks-mobile-nav-label">', escapeHtml(sectorLabel), '</span>',
        '</span>',
        '<span class="btn-open-sub"></span>',
        '</a>',
        '<div id="', escapeHtml(collapseId), '" class="collapse">',
        '<ul class="sub-nav-menu">',
        '<li><a class="sub-nav-link active" href="', escapeHtml(sectorUrl), '">Vedi tutto il settore</a></li>'
      ];

      categoryColumns.forEach(function (column) {
        html.push(buildMobileCategoryHtml(column, sectorId));
      });

      html.push('</ul></div></li>');
      return html.join('');
    }

    if (!mobileList || !desktopList) {
      return;
    }

    if (!mobileList.querySelector('.nav-mb-item')) {
      var html = Array.prototype.slice.call(desktopList.children).map(buildMobileSectorHtml).join('');
      if (html) {
        mobileList.innerHTML = html;
        if (mount) {
          mount.setAttribute('data-ks-mounted', 'cloned');
        }
      }
    } else if (mount) {
      mount.setAttribute('data-ks-mounted', 'server');
    }
  }

  function initMobileDrawerInteractions() {
    var drawer = document.getElementById('mobileMenu');
    if (!drawer) return;

    function syncBackdropAndDrawer() {
      var backdrop = document.querySelector('.offcanvas-backdrop.show:last-of-type');
      if (backdrop) {
        backdrop.style.zIndex = '1075';
      }
      drawer.style.zIndex = '1085';
      drawer.classList.add('ks-drawer-ready');
    }

    function updateTriggerState(target, expanded) {
      if (!target || !target.id) return;

      var selector = '[data-bs-target="#' + target.id + '"], [aria-controls="' + target.id + '"]';
      Array.prototype.slice.call(drawer.querySelectorAll(selector)).forEach(function (trigger) {
        trigger.classList.toggle('is-open', !!expanded);
        trigger.setAttribute('aria-expanded', expanded ? 'true' : 'false');
        trigger.classList.toggle('collapsed', !expanded);
      });
    }

    drawer.addEventListener('show.bs.offcanvas', function () {
      window.requestAnimationFrame(syncBackdropAndDrawer);
    });

    drawer.addEventListener('shown.bs.offcanvas', function () {
      syncBackdropAndDrawer();
    });

    drawer.addEventListener('hidden.bs.offcanvas', function () {
      drawer.classList.remove('ks-drawer-ready');
    });

    drawer.addEventListener('click', function (event) {
      var trigger = event.target.closest('[data-bs-toggle="collapse"]');
      if (!trigger || !drawer.contains(trigger)) return;

      var selector = trigger.getAttribute('data-bs-target') || trigger.getAttribute('href');
      if (!selector || selector.charAt(0) !== '#') return;

      var target = drawer.querySelector(selector);
      if (!target) return;

      event.preventDefault();
      event.stopPropagation();

      if (window.bootstrap && bootstrap.Collapse) {
        bootstrap.Collapse.getOrCreateInstance(target, { toggle: false }).toggle();
      } else {
        var shouldOpen = !target.classList.contains('show');
        target.classList.toggle('show', shouldOpen);
        updateTriggerState(target, shouldOpen);
      }
    });

    drawer.addEventListener('shown.bs.collapse', function (event) {
      updateTriggerState(event.target, true);
    });

    drawer.addEventListener('hidden.bs.collapse', function (event) {
      updateTriggerState(event.target, false);
    });
  }

  function setQuickViewText(id, value) {
    var node = document.getElementById(id);
    if (!node) return;
    node.textContent = value || '';
  }

  function setQuickViewLink(id, url) {
    var node = document.getElementById(id);
    if (!node) return;
    node.setAttribute('href', url || 'articoli.aspx');
  }

  function initQuickView() {
    Array.prototype.slice.call(document.querySelectorAll('.js-ks-quickview')).forEach(function (button) {
      button.addEventListener('click', function () {
        var title = button.getAttribute('data-ks-title') || 'Prodotto';
        var brand = button.getAttribute('data-ks-brand') || '';
        var url = button.getAttribute('data-ks-url') || 'articoli.aspx';
        var img = button.getAttribute('data-ks-img') || '/Public/assets/images/item/laptop.webp';
        var price = button.getAttribute('data-ks-price') || '';
        var sold = button.getAttribute('data-ks-sold') || '0';
        var available = button.getAttribute('data-ks-available') || '0';
        var description = button.getAttribute('data-ks-description') || title;
        var progress = button.getAttribute('data-ks-progress') || '0';
        var meta = brand ? ('Brand: ' + brand) : 'Prodotto';

        setQuickViewText('ksQuickViewMeta', meta);
        setQuickViewText('ksQuickViewTitle', title);
        setQuickViewText('ksQuickViewPrice', price);
        setQuickViewText('ksQuickViewSold', 'Venduti: ' + sold);
        setQuickViewText('ksQuickViewAvailable', 'Disponibili: ' + available);
        setQuickViewText('ksQuickViewDescription', description);
        setQuickViewLink('ksQuickViewTitle', url);
        setQuickViewLink('ksQuickViewImageLink', url);
        setQuickViewLink('ksQuickViewOpenLink', url);
        setQuickViewLink('ksQuickViewCartLink', 'aggiungi.aspx?id=' + encodeURIComponent(button.getAttribute('data-ks-id') || ''));

        var image = document.getElementById('ksQuickViewMainImage');
        if (image) {
          image.setAttribute('src', img);
          image.setAttribute('alt', title);
        }

        var progressBar = document.getElementById('ksQuickViewProgress');
        if (progressBar) {
          progressBar.style.width = (parseInt(progress, 10) || 0) + '%';
        }
      });
    });
  }

  function getLanguage() {
    try {
      return window.localStorage.getItem('ks_lang') || 'it';
    } catch (e) {
      return 'it';
    }
  }

  function setLanguage(lang) {
    try {
      window.localStorage.setItem('ks_lang', lang);
    } catch (e) {}
  }

  var i18n = {
    en: {
      'header.callUsFree': 'Call us for free:',
      'header.account': 'My account',
      'header.hello': 'Hi',
      'header.callNow': 'Call us now:',
      'header.accountShort': 'Account',
      'header.cart': 'Cart',
      'header.accountArea': 'My account',
      'header.wishlist': 'Wishlist',
      'header.compare': 'Compare products',
      'nav.home': 'Home',
      'nav.catalog': 'Catalog',
      'nav.offers': 'Offers',
      'nav.contact': 'Contact',
      'nav.departments': 'All sectors',
      'nav.viewSector': 'View all in this sector',
      'nav.viewCategory': 'View all in this category',
      'nav.departmentCollection': 'Department collection',
      'nav.shopNow': 'Shop now',
      'home.deal': 'Deal Of The Day',
      'home.offers': 'Offers',
      'home.featured': 'Featured',
      'home.newArrivals': 'New arrivals',
      'home.topSelling': 'Top Selling',
      'home.onSale': 'On Sale',
      'home.chosenByYou': 'Chosen By You',
      'icon.freeDelivery': 'Fast delivery',
      'icon.freeDeliveryText': 'Free shipping on eligible orders',
      'icon.support': 'Dedicated support',
      'icon.supportText': 'Fast assistance before and after purchase',
      'icon.payment': 'Secure payments',
      'icon.paymentText': 'Protected checkout and trusted methods',
      'icon.reliable': 'Real reliability',
      'icon.reliableText': 'Curated catalog and updated availability',
      'icon.guarantee': 'Warranty and returns',
      'icon.guaranteeText': 'Clear procedures and post-sale support'
    }
  };

  function applyTranslations() {
    var lang = getLanguage();
    var dict = i18n[lang];
    if (!dict) return;

    Array.prototype.slice.call(document.querySelectorAll('[data-ks-i18n]')).forEach(function (node) {
      var key = node.getAttribute('data-ks-i18n');
      if (key && dict[key]) {
        node.textContent = dict[key];
      }
    });

    Array.prototype.slice.call(document.querySelectorAll('[data-ks-language]')).forEach(function (selector) {
      selector.value = lang;
    });
  }

  function initLanguageSwitcher() {
    Array.prototype.slice.call(document.querySelectorAll('[data-ks-language]')).forEach(function (selector) {
      selector.addEventListener('change', function () {
        setLanguage(selector.value || 'it');
        applyTranslations();
      });
    });

    applyTranslations();
  }

  onReady(function () {
    setBodyFlags();
    setActiveSidebar();
    tryMarkLegacyAccountNav();
    hideLegacyAccountNavIfSidebarPresent();
    initCompareButtons();
    initSearchForms();
    initMobileCatalogMenu();
    initMobileDrawerInteractions();
    initQuickView();
    initLanguageSwitcher();
  });
})();
