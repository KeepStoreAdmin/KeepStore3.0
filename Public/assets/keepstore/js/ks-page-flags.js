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
    renderComparePage();
  }

  function buildCompareCard(item) {
    return [
      '<article class="ks-compare-card">',
      '<button type="button" class="ks-compare-remove" data-ks-compare-remove="', item.id, '">&times;</button>',
      '<a href="', item.url || '#', '" class="ks-compare-image">',
      '<img src="', item.img || '/Public/assets/images/item/laptop.webp', '" alt="', item.title || '', '">',
      '</a>',
      '<h3><a href="', item.url || '#', '">', item.title || 'Prodotto', '</a></h3>',
      item.price ? '<p class="ks-compare-price">' + item.price + '</p>' : '',
      '<div class="ks-compare-actions">',
      '<a class="tf-btn btn-line" href="cart_add.aspx?id=', item.id, '">Aggiungi al carrello</a>',
      '<a class="tf-btn btn-fill" href="', item.url || '#', '">Vedi prodotto</a>',
      '</div>',
      '</article>'
    ].join('');
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

    Array.prototype.slice.call(grid.querySelectorAll('[data-ks-compare-remove]')).forEach(function (btn) {
      btn.addEventListener('click', function () {
        removeCompareItem(btn.getAttribute('data-ks-compare-remove'));
      });
    });
  }

  function initCompareButtons() {
    Array.prototype.slice.call(document.querySelectorAll('.js-ks-compare')).forEach(function (link) {
      link.addEventListener('click', function (event) {
        event.preventDefault();
        addCompareItem({
          id: link.getAttribute('data-ks-id') || '',
          title: link.getAttribute('data-ks-title') || '',
          url: link.getAttribute('data-ks-url') || link.getAttribute('href') || '#',
          img: link.getAttribute('data-ks-img') || '',
          price: link.getAttribute('data-ks-price') || ''
        });
        window.location.href = 'compare.aspx';
      });
    });

    var clearBtn = document.getElementById('ksCompareClear');
    if (clearBtn) {
      clearBtn.addEventListener('click', function () {
        saveCompareItems([]);
        updateCompareCount();
        renderComparePage();
      });
    }

    updateCompareCount();
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
    var url = 'search_suggest.aspx?term=' + encodeURIComponent(term) + '&limit=8';
    if (sectorId) {
      url += '&st=' + encodeURIComponent(sectorId);
    }
    return window.fetch(url, { credentials: 'same-origin' })
      .then(function (response) { return response.json(); })
      .catch(function () { return []; });
  }

  function buildSuggestMarkup(items, recent, currentValue) {
    var html = [];

    if (recent && recent.length) {
      html.push('<div class="ks-search-section"><p class="ks-search-section-title">Ricerche recenti</p>');
      recent.forEach(function (entry) {
        html.push('<button type="button" class="ks-search-item is-recent" data-ks-recent-value="', escapeHtml(entry), '">', escapeHtml(entry), '</button>');
      });
      html.push('</div>');
    }

    if (items && items.length) {
      html.push('<div class="ks-search-section"><p class="ks-search-section-title">Suggerimenti</p>');
      items.forEach(function (item) {
        html.push('<a class="ks-search-item" href="', escapeHtml(item.url || '#'), '">');
        html.push('<span class="ks-search-item-main">', escapeHtml(item.label || item.t || currentValue), '</span>');
        if (item.meta) {
          html.push('<span class="ks-search-item-meta">', escapeHtml(item.meta), '</span>');
        } else if (item.type) {
          html.push('<span class="ks-search-item-meta">', escapeHtml(item.type), '</span>');
        }
        html.push('</a>');
      });
      html.push('</div>');
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
          input.value = btn.getAttribute('data-ks-recent-value') || '';
          submitSearch();
        });
      });
    }

    function submitSearch(forceUrl) {
      var query = (input && input.value ? input.value : '').trim();
      var selectedUrl = select && select.value ? select.value : '';
      var exactItem = null;

      if (!forceUrl && query) {
        saveRecentSearch(query);
      }

      lastItems.forEach(function (item) {
        var label = String(item.label || item.t || '').toLowerCase();
        if (!exactItem && label === query.toLowerCase() && item.type === 'Reparto') {
          exactItem = item;
        }
      });

      if (forceUrl) {
        window.location.href = forceUrl;
        return;
      }

      if (selectedUrl) {
        window.location.href = query ? selectedUrl + (selectedUrl.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(query) : selectedUrl;
        return;
      }

      if (exactItem && exactItem.url) {
        window.location.href = exactItem.url;
        return;
      }

      if (query) {
        window.location.href = 'articoli.aspx?q=' + encodeURIComponent(query);
      }
    }

    function handleInput() {
      if (!input || !suggest) return;
      var value = (input.value || '').trim();
      var recent = getRecentSearches().filter(function (entry) {
        return !value || entry.toLowerCase().indexOf(value.toLowerCase()) !== -1;
      }).slice(0, 4);

      window.clearTimeout(lastTimer);

      if (value.length < 2) {
        openSuggest(buildSuggestMarkup([], recent, value));
        return;
      }

      lastTimer = window.setTimeout(function () {
        fetchSuggestions(value, parseSelectedSector(select)).then(function (items) {
          lastItems = Array.isArray(items) ? items : [];
          openSuggest(buildSuggestMarkup(lastItems, recent, value));
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
    Array.prototype.slice.call(document.querySelectorAll('[data-ks-nav-toggle]')).forEach(function (button) {
      button.addEventListener('click', function () {
        var panel = button.nextElementSibling;
        if (!panel) return;
        var open = button.classList.contains('is-open');
        button.classList.toggle('is-open', !open);
        panel.classList.toggle('is-open', !open);
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
      'nav.departments': 'All departments',
      'nav.viewSector': 'View all in this department',
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

    var selector = document.getElementById('ksLanguageSelect');
    if (selector) {
      selector.value = lang;
    }
  }

  function initLanguageSwitcher() {
    var selector = document.getElementById('ksLanguageSelect');
    if (!selector) return;

    selector.addEventListener('change', function () {
      setLanguage(selector.value || 'it');
      applyTranslations();
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
    initLanguageSwitcher();
  });
})();
