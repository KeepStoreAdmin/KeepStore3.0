(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var STYLE_ID = 'ks-home-stable-reset';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'themeforest', 'onsus', 'themesflat'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function all(root, sel) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
    catch (err) { return []; }
  }

  function first(root, sel) {
    try { return (root || document).querySelector(sel); }
    catch (err) { return null; }
  }

  function closest(node, sel) {
    try { return node && node.closest ? node.closest(sel) : null; }
    catch (err) { return null; }
  }

  function txt(node) {
    return String(node && node.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function rectOf(node) {
    if (!node || typeof node.getBoundingClientRect !== 'function') return null;
    try { return node.getBoundingClientRect(); }
    catch (err) { return null; }
  }

  function styleOf(node) {
    if (!node || typeof window.getComputedStyle !== 'function') return null;
    try { return window.getComputedStyle(node); }
    catch (err) { return null; }
  }

  function normalizeText(value) {
    var s = String(value || '').toLowerCase();
    try { s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (err) {}
    return s.replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
  }

  function normalizePath(path) {
    return String(path || '')
      .toLowerCase()
      .replace(/\/+/g, '/')
      .replace(/\/default\.aspx$/i, '/')
      .replace(/\/$/, '/');
  }

  function normalizeSrc(src) {
    return String(src || '')
      .replace(/^https?:/i, '')
      .replace(/[?#].*$/, '')
      .trim();
  }

  function backgroundImageOf(node) {
    var style = styleOf(node);
    return style && style.backgroundImage && style.backgroundImage !== 'none' ? style.backgroundImage : '';
  }

  function isHomePage() {
    var pathname = window.location.pathname || '/';
    var path = normalizePath(pathname);
    return path === '/' || /\/default\.aspx$/i.test(pathname);
  }

  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
  }

  function isDesktop() {
    return (window.innerWidth || document.documentElement.clientWidth || 0) >= 1200;
  }

  function addBodyClass(name) {
    if (!name || !document.body) return;
    document.body.classList.add(name);
  }

  function getQueryParam(name) {
    var params = new URLSearchParams(window.location.search || '');
    return params.get(name);
  }

  function readCookie(name) {
    var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }

  function writeCookie(name, value, days) {
    var expires = '';
    if (typeof days === 'number' && days > 0) {
      var d = new Date();
      d.setTime(d.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = String(name || '') + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
  }

  function parseRecentList(raw) {
    return String(raw || '')
      .split(',')
      .map(function (item) { return parseInt(item, 10); })
      .filter(function (item) { return Number.isFinite(item) && item > 0; });
  }

  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); }
    catch (err) { return []; }
  }

  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); }
    catch (err) {}
  }

  function mergeRecentLists(primary, secondary) {
    var seen = new Set();
    var merged = [];
    [primary || [], secondary || []].forEach(function (list) {
      list.forEach(function (id) {
        if (!Number.isFinite(id) || id <= 0 || seen.has(id)) return;
        seen.add(id);
        merged.push(id);
      });
    });
    return merged.slice(0, MAX_RECENT);
  }

  function readMergedRecent() {
    return mergeRecentLists(readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME)));
  }

  function persistRecentList(list) {
    var next = (list || []).filter(function (id) {
      return Number.isFinite(id) && id > 0;
    }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }

  function updateRecentList(id) {
    var merged = readMergedRecent();
    var next = [id].concat(merged.filter(function (item) { return item !== id; })).slice(0, MAX_RECENT);
    persistRecentList(next);
    try {
      document.dispatchEvent(new CustomEvent('ks:recent-updated', { detail: { ids: next.slice() } }));
    } catch (err) {}
    return next;
  }

  function parseArticleIdFromHref(href) {
    if (!href) return 0;
    var match = String(href).match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
  }

  function detectArticleId() {
    var direct = parseInt(getQueryParam('id'), 10);
    if (Number.isFinite(direct) && direct > 0) return direct;
    var canonical = document.querySelector('link[rel="canonical"]');
    var fromCanonical = canonical ? parseArticleIdFromHref(canonical.getAttribute('href') || '') : 0;
    if (fromCanonical > 0) return fromCanonical;
    var ogUrl = document.querySelector('meta[property="og:url"]');
    var fromOg = ogUrl ? parseArticleIdFromHref(ogUrl.getAttribute('content') || '') : 0;
    if (fromOg > 0) return fromOg;
    return 0;
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (!Number.isFinite(id) || id <= 0) return;
    updateRecentList(id);
  }

  function hideNode(node, attrName) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (attrName) node.setAttribute(attrName, '1');
  }

  function hardProtectedAncestor(node) {
    if (!node || !node.closest) return false;
    return !!node.closest([
      'header', 'footer', '.tf-header', '.tf-footer', '.footer',
      '.ks-home-departments', '.ks-home-hero-shell', '.wrap-item-1', '.wrap-item-2', '.wrap-item-3',
      '.tf-icon-box', '.card-product', '.ks-card-product', '.ks-grid-card', '.ks-row-card', '.ks-big-card', '.ks-deal-card',
      '.ks-home-brands', '.tf-grid-product-item', '.modal:not(.auto-popup):not(.modal-newleter)', '.offcanvas.show'
    ].join(','));
  }

  function isEdgeRect(rect, padding) {
    if (!rect) return false;
    var edgePadding = typeof padding === 'number' ? padding : 60;
    if (rect.width < 12 || rect.height < 12) return false;
    return rect.left <= edgePadding || rect.right >= (window.innerWidth - edgePadding);
  }

  function isNarrowEdgeRect(rect) {
    return !!(rect && isEdgeRect(rect, 90) && rect.width <= 220 && rect.height >= 80 && rect.height <= 1200);
  }

  function edgeCreativeRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;
    while (current && current.parentElement && hops < 6) {
      var parent = current.parentElement;
      if (hardProtectedAncestor(parent)) break;
      var parentRect = rectOf(parent);
      if (!parentRect || !isNarrowEdgeRect(parentRect)) break;
      best = parent;
      current = parent;
      hops += 1;
    }
    return best;
  }

  function containsBlockedCreativeToken(text) {
    var value = normalizeText(text);
    if (!value) return false;
    return BLOCKED_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
  }

  function injectCss() {
    if (!isHomePage() || document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.type = 'text/css';
    style.appendChild(document.createTextNode([
      "body.ks-page-home .ks-home-submenu-container[aria-hidden='true']{display:none!important;}",
      "body.ks-page-home .auto-popup,body.ks-page-home .modal-newleter,body.ks-page-home [class*='modal-newleter']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home [data-ks-edge-creative='1'],body.ks-page-home [data-ks-hidden-popup='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home .ks-home-departments .menu-category-list{overflow-x:hidden!important;}",
      "@media (min-width:1200px){",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact{display:grid!important;grid-template-columns:minmax(250px,270px) minmax(0,1fr)!important;column-gap:24px!important;align-items:start!important;}",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-3{display:none!important;}",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-2{width:auto!important;max-width:none!important;min-width:0!important;flex:1 1 auto!important;}",
      "body.ks-page-home .ks-home-departments .menu-category-list[data-ks-menu-synced='1']{overflow-y:auto!important;overscroll-behavior:contain;}",
      "}",
      ".ks-search-host{position:relative!important;}",
      ".ks-suggest{position:absolute;left:0;right:0;top:calc(100% + 10px);z-index:220;background:#fff;border:1px solid #edf1f5;border-radius:18px;box-shadow:0 18px 48px rgba(15,23,42,.14);padding:8px;display:none;max-height:460px;overflow:auto;}",
      ".ks-suggest.is-open{display:block;}",
      ".ks-suggest-list{list-style:none;margin:0;padding:0;display:grid;gap:4px;}",
      ".ks-suggest-item{display:grid;grid-template-columns:56px minmax(0,1fr) auto;gap:12px;align-items:center;padding:10px 12px;border-radius:14px;text-decoration:none;color:#1f2937;}",
      ".ks-suggest-item.is-active,.ks-suggest-item:hover{background:#f8fafc;}",
      ".ks-suggest-thumb{width:56px;height:56px;border-radius:12px;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#f3f4f6;}",
      ".ks-suggest-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}",
      ".ks-suggest-meta{min-width:0;display:grid;gap:4px;}",
      ".ks-suggest-title{font-size:14px;line-height:1.3;font-weight:600;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}",
      ".ks-suggest-sub{font-size:12px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}",
      ".ks-suggest-price{font-size:14px;font-weight:700;color:#ef4444;white-space:nowrap;}",
      ".ks-suggest-empty,.ks-suggest-head{padding:10px 12px;font-size:12px;letter-spacing:.04em;text-transform:uppercase;font-weight:700;color:#ef4444;}",
      ".ks-suggest-empty{color:#6b7280;text-transform:none;letter-spacing:0;font-size:13px;font-weight:400;}",
      ".ks-top-catalog-mega{position:absolute;left:0;top:calc(100% + 12px);z-index:250;width:min(1180px,calc(100vw - 32px));padding:22px 24px;background:#fff;border:1px solid #edf1f5;border-radius:20px;box-shadow:0 18px 48px rgba(15,23,42,.14);display:none;}",
      ".ks-top-catalog-mega.is-open{display:block;}",
      ".ks-top-catalog-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px 24px;max-height:72vh;overflow:auto;padding-right:6px;}",
      ".ks-top-catalog-sector{display:grid;gap:12px;min-width:0;}",
      ".ks-top-catalog-sector-head{display:flex;align-items:center;gap:10px;min-width:0;}",
      ".ks-top-catalog-sector-media{width:44px;height:44px;border-radius:12px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;overflow:hidden;}",
      ".ks-top-catalog-sector-media img{max-width:100%;max-height:100%;object-fit:contain;display:block;}",
      ".ks-top-catalog-sector-title{font-size:18px;line-height:1.2;font-weight:700;color:#111827;text-decoration:none;}",
      ".ks-top-catalog-category{display:grid;gap:8px;}",
      ".ks-top-catalog-category-link{display:block;font-size:13px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#ef4444;padding-bottom:8px;border-bottom:1px solid #edf1f5;text-decoration:none;}",
      ".ks-top-catalog-tips{list-style:none;margin:0;padding:0;display:grid;gap:8px;}",
      ".ks-top-catalog-tips a{text-decoration:none;color:#1f2937;font-size:14px;line-height:1.35;}",
      "@media (max-width:1199.98px){.ks-top-catalog-mega{display:none!important;}}"
    ].join('')));
    (document.head || document.documentElement).appendChild(style);
  }

  function disableTemplatePopupStorage() {
    if (!isHomePage()) return;
    try {
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
    } catch (err) {}
  }

  function clearStaleUiLock() {
    if (!isHomePage()) return;
    var visibleDialog = document.querySelector('.modal.show:not([data-ks-hidden-popup="1"]), .offcanvas.show');
    if (visibleDialog) return;
    all(document, '.modal-backdrop, .offcanvas-backdrop').forEach(function (backdrop) {
      hideNode(backdrop, 'data-ks-hidden-popup');
      if (backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
    });
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function suppressNewsletterPopup() {
    if (!isHomePage()) return;
    all(document, '.auto-popup,.modal-newleter,[class*="modal-newleter"],.modal.auto-popup').forEach(function (node) {
      hideNode(node, 'data-ks-hidden-popup');
      node.classList.remove('show', 'fade', 'in', 'active');
      node.setAttribute('aria-hidden', 'true');
    });
    clearStaleUiLock();
  }

  function sweepTokenizedEdgeCreatives() {
    if (!isHomePage() || !document.body) return;
    all(document.body, 'img,a,div,span,p').forEach(function (node) {
      if (!node || hardProtectedAncestor(node)) return;
      var r = rectOf(node);
      if (!r || !isNarrowEdgeRect(r)) return;
      var raw = [
        node.id || '',
        node.className || '',
        node.getAttribute && node.getAttribute('src') || '',
        node.getAttribute && node.getAttribute('data-src') || '',
        node.getAttribute && node.getAttribute('alt') || '',
        backgroundImageOf(node),
        txt(node).slice(0, 200)
      ].join(' ');
      if (!containsBlockedCreativeToken(raw)) return;
      hideNode(edgeCreativeRoot(node), 'data-ks-edge-creative');
    });
  }

  function sweepRepeatedEdgeDevices() {
    if (!isHomePage()) return;
    var bySrc = Object.create(null);
    all(document, 'img').forEach(function (img) {
      if (!img || hardProtectedAncestor(img)) return;
      var r = rectOf(img);
      if (!r || !isNarrowEdgeRect(r)) return;
      if (r.width > 180 || r.height > 260) return;
      var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
      if (!src || src.indexOf('data:image') === 0) return;
      if (!bySrc[src]) bySrc[src] = [];
      bySrc[src].push(img);
    });
    Object.keys(bySrc).forEach(function (src) {
      if (bySrc[src].length < 2) return;
      bySrc[src].forEach(function (img) { hideNode(edgeCreativeRoot(img), 'data-ks-edge-creative'); });
    });
  }

  function usefulSideItems(sideWrap) {
    if (!sideWrap) return [];
    return Array.prototype.slice.call(sideWrap.children).filter(function (node) {
      if (!node || node.getAttribute('data-ks-edge-creative') === '1') return false;
      var r = rectOf(node);
      if (!r || node.offsetParent === null) return false;
      if (r.width < 40 || r.height < 40) return false;
      var imgs = all(node, 'img').filter(function (img) {
        var imgRect = rectOf(img);
        var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
        return !!(src && imgRect && imgRect.width >= 70 && imgRect.height >= 70 && img.offsetParent !== null);
      });
      return imgs.length > 0;
    });
  }

  function syncHomeShell() {
    if (!isHomePage()) return;
    var shell = first(document, '.ks-home-hero-shell') || first(document, '.s-banner-wrapper');
    var sliderWrap = shell ? first(shell, '.wrap-item-2') : null;
    var sideWrap = shell ? first(shell, '.wrap-item-3') : null;
    var menuRoot = first(document, '.ks-home-departments .main-nav');
    var menuTitle = menuRoot ? first(menuRoot, '.title') : null;
    var menuList = first(document, '.ks-home-departments .menu-category-list');
    if (!shell || !sliderWrap) return;
    if (window.innerWidth < 1200) {
      shell.classList.remove('ks-home-force-compact');
      if (sideWrap) sideWrap.style.display = '';
      if (menuList) {
        menuList.style.maxHeight = '';
        menuList.style.height = '';
        menuList.removeAttribute('data-ks-menu-synced');
      }
      return;
    }
    if (sideWrap) {
      var sideItems = usefulSideItems(sideWrap);
      if (sideItems.length < 2) {
        shell.classList.add('ks-home-force-compact');
        sideWrap.style.display = 'none';
      } else {
        shell.classList.remove('ks-home-force-compact');
        sideWrap.style.display = '';
      }
    }
    if (!menuRoot || !menuList) return;
    var targetNode = first(sliderWrap, '.banner-image-product-4') || first(sliderWrap, '.ks-home-hero-slider') || sliderWrap;
    var sliderRect = rectOf(targetNode);
    var titleRect = rectOf(menuTitle);
    if (!sliderRect || sliderRect.height < 220) return;
    var titleHeight = titleRect ? Math.ceil(titleRect.height) : 0;
    var listHeight = Math.max(180, Math.floor(sliderRect.height - titleHeight - 10));
    menuList.style.maxHeight = listHeight + 'px';
    menuList.style.height = listHeight + 'px';
    menuList.setAttribute('data-ks-menu-synced', '1');
  }

  function findSearchRoot() {
    var candidates = all(document, 'form,.form-search-product,.header-center,.search-box,.search-form,.search-area,.main-search');
    for (var i = 0; i < candidates.length; i += 1) {
      var root = candidates[i];
      var input = first(root, 'input[type="search"],input[type="text"]');
      if (!input) continue;
      var placeholder = normalizeText(input.getAttribute('placeholder') || '');
      if (placeholder && ['cerca', 'search', 'ean', 'codic', 'prodot'].some(function (t) { return placeholder.indexOf(t) !== -1; })) return root;
    }
    return null;
  }

  function searchInput(root) { return first(root, 'input[type="search"],input[type="text"]'); }
  function searchSubmit(root) { return first(root, 'button[type="submit"],.btn-submit-form,.icon-search,.search-submit'); }
  function searchValue(root) { var i = searchInput(root); return i ? String(i.value || '').trim() : ''; }

  function parseFilterValue(value) {
    var raw = String(value || '').trim();
    var out = {};
    if (!raw) return out;
    if (/^(st|ct|tp|gr|sg|mr|pid)[:=]\d+$/i.test(raw)) {
      var parts = raw.split(/[:=]/);
      out[parts[0].toLowerCase()] = parts[1];
      return out;
    }
    if (/^\d+$/.test(raw)) out.st = raw;
    return out;
  }

  function searchFilters(root) {
    var select = first(root, 'select');
    var params = {};
    if (select) Object.assign(params, parseFilterValue(select.value));
    var custom = first(root, '[data-ks-param][data-ks-value], .dropdown_product_cat');
    if (!select && custom && custom.value) Object.assign(params, parseFilterValue(custom.value));
    return params;
  }

  function buildSuggestUrl(root, q, limit, recentMode) {
    var url = new URL(SEARCH_ENDPOINT, location.href);
    var filters = searchFilters(root);
    Object.keys(filters).forEach(function (k) { if (filters[k]) url.searchParams.set(k, filters[k]); });
    if (q) url.searchParams.set('q', q);
    if (recentMode) {
      var ids = readMergedRecent();
      if (ids.length) url.searchParams.set('recent', ids.join(','));
    }
    url.searchParams.set('limit', String(limit || 8));
    return url.toString();
  }

  function buildSearchUrl(root) {
    var q = searchValue(root);
    var url = new URL('/articoli.aspx', location.href);
    var filters = searchFilters(root);
    Object.keys(filters).forEach(function (k) { if (filters[k]) url.searchParams.set(k, filters[k]); });
    if (q) url.searchParams.set('q', q);
    return url.toString();
  }

  function fetchJson(url) {
    return fetch(url, {
      credentials: 'same-origin',
      headers: { 'X-Requested-With': 'XMLHttpRequest' }
    }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }

  function searchState(root) {
    if (!root.__ksSearch) root.__ksSearch = { box: null, items: [], active: -1, timer: 0, token: '' };
    return root.__ksSearch;
  }

  function ensureSuggest(root) {
    var s = searchState(root);
    if (s.box && s.box.parentNode) return s.box;
    root.classList.add('ks-search-host');
    var box = document.createElement('div');
    box.className = 'ks-suggest';
    box.setAttribute('aria-hidden', 'true');
    box.addEventListener('mousedown', function (e) { e.preventDefault(); });
    root.appendChild(box);
    s.box = box;
    return box;
  }

  function showSuggest(root) {
    var box = ensureSuggest(root);
    box.classList.add('is-open');
    box.setAttribute('aria-hidden', 'false');
  }

  function hideSuggest(root) {
    var s = searchState(root);
    if (s.box) {
      s.box.classList.remove('is-open');
      s.box.setAttribute('aria-hidden', 'true');
    }
    s.active = -1;
  }

  function renderSuggest(root, data) {
    var s = searchState(root);
    var box = ensureSuggest(root);
    s.items = data && data.suggestions ? data.suggestions.slice() : [];
    if (!s.items.length) {
      box.innerHTML = '<div class="ks-suggest-empty">Nessun suggerimento disponibile.</div>';
      showSuggest(root);
      return;
    }
    var html = [];
    if (data.recent) html.push('<div class="ks-suggest-head">Recenti</div>');
    html.push('<ul class="ks-suggest-list">');
    s.items.forEach(function (item, idx) {
      var meta = [];
      if (item.brand) meta.push('<span>' + esc(item.brand) + '</span>');
      if (item.category) meta.push('<span>' + esc(item.category) + '</span>');
      html.push('<li><a href="' + esc(item.url || '#') + '" class="ks-suggest-item" data-idx="' + idx + '">');
      html.push('<span class="ks-suggest-thumb">' + (item.image ? '<img src="' + esc(item.image) + '" alt="' + esc(item.title || '') + '" />' : '') + '</span>');
      html.push('<span class="ks-suggest-meta"><span class="ks-suggest-title">' + esc(item.title || '') + '</span><span class="ks-suggest-sub">' + meta.join('') + '</span></span>');
      html.push('<span class="ks-suggest-price">' + (item.price ? ('€' + esc(item.price)) : '') + '</span>');
      html.push('</a></li>');
    });
    html.push('</ul>');
    box.innerHTML = html.join('');
    all(box, '.ks-suggest-item').forEach(function (a) {
      a.addEventListener('mouseenter', function () { setActive(root, parseInt(a.getAttribute('data-idx') || '-1', 10)); });
      a.addEventListener('click', function (e) { e.preventDefault(); location.href = a.getAttribute('href') || '#'; });
    });
    showSuggest(root);
  }

  function setActive(root, idx) {
    var s = searchState(root);
    var items = all(s.box, '.ks-suggest-item');
    if (!items.length) { s.active = -1; return; }
    if (idx < 0) idx = items.length - 1;
    if (idx >= items.length) idx = 0;
    s.active = idx;
    items.forEach(function (n, i) { n.classList.toggle('is-active', i === idx); });
  }

  function openActive(root) {
    var s = searchState(root);
    var item = s.items[s.active];
    if (item && item.url) {
      location.href = item.url;
      return true;
    }
    return false;
  }

  function requestSuggest(root, recentMode) {
    var q = searchValue(root);
    var useRecent = recentMode || q.length < 2;
    var url = buildSuggestUrl(root, q, useRecent ? 8 : 10, useRecent);
    var s = searchState(root);
    s.token = url;
    return fetchJson(url).then(function (data) {
      if (s.token !== url) return;
      renderSuggest(root, data || {});
    }).catch(function () {
      hideSuggest(root);
    });
  }

  function submitSearch(root) {
    var q = searchValue(root);
    var fallback = buildSearchUrl(root);
    var url = buildSuggestUrl(root, q, 60, !q || q.length < 2);
    fetchJson(url).then(function (data) {
      if (data && data.strong && data.strong.canRedirect && data.strong.redirectUrl) {
        location.href = data.strong.redirectUrl;
        return;
      }
      location.href = fallback;
    }).catch(function () {
      location.href = fallback;
    });
  }

  function bindSearch() {
    var root = findSearchRoot();
    if (!root || root.getAttribute('data-ks-search-bound') === '1') return;
    var input = searchInput(root);
    if (!input) return;
    var submit = searchSubmit(root);
    root.setAttribute('data-ks-search-bound', '1');
    input.setAttribute('autocomplete', 'off');
    input.addEventListener('input', function () {
      var s = searchState(root);
      clearTimeout(s.timer);
      s.timer = setTimeout(function () { requestSuggest(root, false); }, 180);
    });
    input.addEventListener('focus', function () { requestSuggest(root, true); });
    input.addEventListener('keydown', function (e) {
      var s = searchState(root);
      var count = s.items.length;
      if (e.key === 'ArrowDown' && count) { e.preventDefault(); setActive(root, s.active + 1); }
      else if (e.key === 'ArrowUp' && count) { e.preventDefault(); setActive(root, s.active - 1); }
      else if (e.key === 'Enter') { e.preventDefault(); if (!openActive(root)) submitSearch(root); }
      else if (e.key === 'Escape') { hideSuggest(root); }
    });
    if (submit) submit.addEventListener('click', function (e) { e.preventDefault(); submitSearch(root); });
    var form = closest(root, 'form');
    if (form) form.addEventListener('submit', function (e) { e.preventDefault(); submitSearch(root); });
    document.addEventListener('click', function (e) { if (!root.contains(e.target)) hideSuggest(root); });
  }

  function buildCatalogMega() {
    if (!isDesktop()) return;
    var homeMenu = first(document, '.ks-home-departments .menu-category-list');
    if (!homeMenu) return;
    var navLink = null;
    all(document, 'header a, nav a, .nav-list a').some(function (a) {
      var t = normalizeText(txt(a));
      if (t === 'catalogo' || t.indexOf('catalog') !== -1) {
        navLink = a;
        return true;
      }
      return false;
    });
    if (!navLink) return;
    var host = closest(navLink, 'li,.nav-item') || navLink.parentElement;
    if (!host || host.getAttribute('data-ks-catalog-bound') === '1') return;
    host.setAttribute('data-ks-catalog-bound', '1');
    host.style.position = 'relative';
    var panel = document.createElement('div');
    panel.className = 'ks-top-catalog-mega';
    var html = ['<div class="ks-top-catalog-grid">'];
    all(homeMenu, ':scope > li.menu-item').forEach(function (item) {
      var label = txt(first(item, '.ks-menu-label')) || txt(first(item, '.item-link'));
      if (!label) return;
      var href = (first(item, '.item-link') || {}).href || '#';
      var mediaNode = first(item, '.ks-menu-media');
      var media = mediaNode ? mediaNode.innerHTML : '';
      var categories = all(item, '.ks-home-submenu-grouped');
      html.push('<section class="ks-top-catalog-sector">');
      html.push('<div class="ks-top-catalog-sector-head"><span class="ks-top-catalog-sector-media">' + media + '</span><a class="ks-top-catalog-sector-title" href="' + esc(href) + '">' + esc(label) + '</a></div>');
      categories.slice(0, 4).forEach(function (cat) {
        var catLink = first(cat, '.ks-home-submenu-category');
        if (!catLink) return;
        html.push('<div class="ks-top-catalog-category">');
        html.push('<a class="ks-top-catalog-category-link" href="' + esc(catLink.href || '#') + '">' + esc(txt(catLink)) + '</a>');
        var tips = all(cat, '.ks-home-submenu-tipology-link');
        if (tips.length) {
          html.push('<ul class="ks-top-catalog-tips">');
          tips.slice(0, 10).forEach(function (tip) {
            html.push('<li><a href="' + esc(tip.href || '#') + '">' + esc(txt(tip)) + '</a></li>');
          });
          html.push('</ul>');
        }
        html.push('</div>');
      });
      html.push('</section>');
    });
    html.push('</div>');
    panel.innerHTML = html.join('');
    host.appendChild(panel);
    var open = function () { panel.classList.add('is-open'); host.classList.add('is-open'); };
    var close = function () { panel.classList.remove('is-open'); host.classList.remove('is-open'); };
    host.addEventListener('mouseenter', open);
    host.addEventListener('mouseleave', close);
    navLink.addEventListener('focus', open);
    document.addEventListener('click', function (e) { if (!host.contains(e.target)) close(); });
  }

  function applyHomeFlags() {
    if (!isHomePage()) return;
    addBodyClass('ks-page-home');
    if (readMergedRecent().length >= 2) addBodyClass('ks-has-recent-history');
  }

  function runHomeRuntimeSweep() {
    if (!isHomePage()) return;
    injectCss();
    disableTemplatePopupStorage();
    suppressNewsletterPopup();
    sweepTokenizedEdgeCreatives();
    sweepRepeatedEdgeDevices();
    syncHomeShell();
    buildCatalogMega();
    bindSearch();
    clearStaleUiLock();
  }

  function armHomeRuntimeSweep() {
    if (!isHomePage()) return;
    [0, 250, 1200, 2500, 5000].forEach(function (delay) {
      window.setTimeout(runHomeRuntimeSweep, delay);
    });
  }

  window.KSRecent = {
    read: readMergedRecent,
    add: updateRecentList
  };

  disableTemplatePopupStorage();

  onReady(function () {
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }
    applyHomeFlags();
    runHomeRuntimeSweep();
    armHomeRuntimeSweep();
    window.addEventListener('load', runHomeRuntimeSweep, { once: true });
    window.addEventListener('resize', runHomeRuntimeSweep);
  });
})();
