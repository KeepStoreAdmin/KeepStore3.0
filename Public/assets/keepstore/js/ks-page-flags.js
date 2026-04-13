(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var STYLE_ID = 'ks-home-stable-step23';
  var MASK_WRAP_ID = 'ks-home-gutter-masks';
  var LANG_KEY = 'ks_ui_lang';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'demo', 'template'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function all(root, sel) { try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); } catch (err) { return []; } }
  function first(root, sel) { try { return (root || document).querySelector(sel); } catch (err) { return null; } }
  function closest(node, sel) { try { return node && node.closest ? node.closest(sel) : null; } catch (err) { return null; } }
  function txt(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function rect(node) { try { return node && node.getBoundingClientRect ? node.getBoundingClientRect() : null; } catch (err) { return null; } }
  function styleOf(node) { try { return node ? window.getComputedStyle(node) : null; } catch (err) { return null; } }
  function norm(v) {
    var s = String(v || '').toLowerCase();
    try { s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (err) {}
    return s.replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function normalizeSrc(v) { return String(v || '').replace(/^https?:/i, '').replace(/[?#].*$/, '').trim(); }
  function isHomePage() {
    var path = String(location.pathname || '/').toLowerCase().replace(/\/+$/, '/');
    return path === '/' || /\/default\.aspx$/i.test(location.pathname || '');
  }
  function isArticlePage() { return /\/articolo\.aspx$/i.test(location.pathname || ''); }
  function isDesktop() { return (window.innerWidth || document.documentElement.clientWidth || 0) >= 1200; }
  function readCookie(name) {
    var escName = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escName + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }
  function writeCookie(name, value, days) {
    var expires = '';
    if (days) {
      var d = new Date();
      d.setTime(d.getTime() + days * 24 * 60 * 60 * 1000);
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = name + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
  }
  function parseIds(raw) {
    return String(raw || '').split(',').map(function (v) { return parseInt(v, 10); }).filter(function (v) { return v > 0; });
  }
  function mergedRecent() {
    var seen = Object.create(null);
    var out = [];
    var lists = [];
    try { lists.push(parseIds(window.sessionStorage.getItem(SESSION_KEY) || '')); } catch (err) { lists.push([]); }
    lists.push(parseIds(readCookie(COOKIE_NAME)));
    lists.forEach(function (list) {
      list.forEach(function (id) {
        if (!id || seen[id]) return;
        seen[id] = true;
        out.push(id);
      });
    });
    return out.slice(0, MAX_RECENT);
  }
  function persistRecent(list) {
    var next = (list || []).filter(function (v) { return v > 0; }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    try { window.sessionStorage.setItem(SESSION_KEY, next.join(',')); } catch (err) {}
  }
  function addRecent(id) {
    if (!(id > 0)) return;
    var merged = mergedRecent();
    var next = [id].concat(merged.filter(function (v) { return v !== id; })).slice(0, MAX_RECENT);
    persistRecent(next);
  }
  function detectArticleId() {
    var q = new URLSearchParams(location.search || '').get('id');
    var direct = parseInt(q, 10);
    if (direct > 0) return direct;
    var canonical = first(document, 'link[rel="canonical"]');
    var match = canonical && String(canonical.getAttribute('href') || '').match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
  }

  function ensureCss() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      'body.ks-page-home{position:relative;}',
      '.auto-popup,.modal-newleter,[class*="modal-newleter"]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}',
      'body.ks-page-home .ks-home-submenu-container[aria-hidden="true"]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}',
      '@media (min-width:1200px){body.ks-page-home .menu-item:hover>.ks-home-submenu-container,body.ks-page-home .menu-item:focus-within>.ks-home-submenu-container,body.ks-page-home .menu-item.is-open>.ks-home-submenu-container{display:flex!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;}}',
      'body.ks-page-home .ks-home-gutter-mask{position:fixed;pointer-events:none;z-index:2147483640;background:#f7f7f7;top:0;bottom:0;width:0;display:none;}',
      'body.ks-page-home .ks-home-gutter-mask--left{left:0;}',
      'body.ks-page-home .ks-home-gutter-mask--right{right:0;}',
      'body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-3{display:none!important;}',
      'body.ks-page-home .ks-home-hero-shell.ks-home-force-compact{display:grid!important;grid-template-columns:minmax(250px,270px) minmax(0,1fr)!important;column-gap:24px!important;align-items:start!important;}',
      'body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-2{min-width:0!important;width:auto!important;max-width:none!important;}',
      '.ks-search-host{position:relative!important;}',
      '.ks-suggest{position:absolute;left:0;right:0;top:calc(100% + 10px);z-index:220;background:#fff;border:1px solid #edf1f5;border-radius:18px;box-shadow:0 18px 48px rgba(15,23,42,.14);padding:8px;display:none;max-height:460px;overflow:auto;}',
      '.ks-suggest.is-open{display:block;}',
      '.ks-suggest-list{list-style:none;margin:0;padding:0;display:grid;gap:4px;}',
      '.ks-suggest-item{display:grid;grid-template-columns:56px minmax(0,1fr) auto;gap:12px;align-items:center;padding:10px 12px;border-radius:14px;text-decoration:none;color:#1f2937;}',
      '.ks-suggest-item.is-active,.ks-suggest-item:hover{background:#f8fafc;}',
      '.ks-suggest-thumb{width:56px;height:56px;border-radius:12px;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#f3f4f6;}',
      '.ks-suggest-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-suggest-meta{min-width:0;display:grid;gap:4px;}',
      '.ks-suggest-title{font-size:14px;line-height:1.3;font-weight:600;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
      '.ks-suggest-sub{font-size:12px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}',
      '.ks-suggest-price{font-size:14px;font-weight:700;color:#ef4444;white-space:nowrap;}',
      '.ks-suggest-empty,.ks-suggest-head{padding:10px 12px;font-size:12px;letter-spacing:.04em;text-transform:uppercase;font-weight:700;color:#ef4444;}',
      '.ks-suggest-empty{color:#6b7280;text-transform:none;letter-spacing:0;font-size:13px;font-weight:400;}',
      '.ks-top-catalog-mega{position:absolute;left:0;top:calc(100% + 12px);z-index:250;width:min(1180px,calc(100vw - 32px));padding:22px 24px;background:#fff;border:1px solid #edf1f5;border-radius:20px;box-shadow:0 18px 48px rgba(15,23,42,.14);display:none;}',
      '.ks-top-catalog-mega.is-open{display:block;}',
      '.ks-top-catalog-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px 24px;max-height:72vh;overflow:auto;padding-right:6px;}',
      '.ks-top-catalog-sector{display:grid;gap:12px;min-width:0;}',
      '.ks-top-catalog-sector-head{display:flex;align-items:center;gap:10px;min-width:0;}',
      '.ks-top-catalog-sector-media{width:44px;height:44px;border-radius:12px;background:#f3f4f6;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ks-top-catalog-sector-media img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-top-catalog-sector-title{font-size:18px;line-height:1.2;font-weight:700;color:#111827;text-decoration:none;}',
      '.ks-top-catalog-category{display:grid;gap:8px;}',
      '.ks-top-catalog-category-link{display:block;font-size:13px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#ef4444;padding-bottom:8px;border-bottom:1px solid #edf1f5;text-decoration:none;}',
      '.ks-top-catalog-tips{list-style:none;margin:0;padding:0;display:grid;gap:8px;}',
      '.ks-top-catalog-tips a{text-decoration:none;color:#1f2937;font-size:14px;line-height:1.35;}',
      '@media (max-width:1199.98px){.ks-top-catalog-mega{display:none!important;}}'
    ].join('');
    document.head.appendChild(style);
  }

  function homeHeroShell() {
    var shell = first(document, '.ks-home-hero-shell') || first(document, '.s-banner-wrapper');
    if (shell && shell.classList && !shell.classList.contains('ks-home-hero-shell')) shell.classList.add('ks-home-hero-shell');
    return shell;
  }
  function primaryContentRect() {
    var shell = homeHeroShell();
    var r = rect(shell);
    if (r && r.width > 500) return r;
    var c = first(document, '.tf-sp-5 .container') || first(document, '.container');
    return rect(c);
  }
  function hardProtected(node) {
    if (!node) return false;
    return !!closest(node, 'header,footer,.ks-home-departments,.ks-home-hero-shell,.card-product,.product-list-wrap,.tf-icon-box,.swiper,.flat-title,.ks-top-catalog-mega,.modal:not(.auto-popup):not(.modal-newleter),.offcanvas.show');
  }
  function nodeRaw(node) {
    return [node.id || '', node.className || '', txt(node).slice(0, 180), normalizeSrc(node.getAttribute && (node.getAttribute('src') || node.getAttribute('data-src')) || '')].join(' ');
  }
  function hasBlockedToken(node) {
    var value = norm(nodeRaw(node));
    return BLOCKED_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
  }
  function mediaCount(node) { return all(node, 'img,picture,svg,video,iframe,canvas').length; }
  function isVertical(node) {
    var st = styleOf(node);
    if (!st) return false;
    var wm = String(st.writingMode || '').toLowerCase();
    var tr = String(st.transform || '').toLowerCase();
    return wm.indexOf('vertical') !== -1 || tr.indexOf('matrix') !== -1 || tr.indexOf('rotate(90') !== -1 || tr.indexOf('rotate(-90') !== -1;
  }
  function isArtifact(node) {
    if (!node || node === document.body || hardProtected(node)) return false;
    var r = rect(node);
    if (!r || r.width < 12 || r.height < 28) return false;
    var lane = primaryContentRect();
    var outsideLane = lane ? (r.right <= lane.left - 6 || r.left >= lane.right + 6) : (r.left < 40 || r.right > window.innerWidth - 40);
    if (!outsideLane) return false;
    if (r.width > 260 || r.height > 2600) return false;
    if (hasBlockedToken(node)) return true;
    if (isVertical(node) && r.height > r.width * 1.1) return true;
    if (mediaCount(node) >= 2 && r.width <= 220) return true;
    var st = styleOf(node);
    if (st) {
      if ((st.position === 'fixed' || st.position === 'sticky') && r.width <= 220) return true;
      if (st.backgroundImage && st.backgroundImage !== 'none' && r.width <= 220 && r.height > 120) return true;
    }
    return false;
  }
  function hideNode(node) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-ks-hidden-artifact', '1');
  }
  function sweepArtifacts() {
    if (!isHomePage() || !document.body) return;
    all(document.body, 'div,aside,section,a,span,p,small,strong,em,label,img,picture').forEach(function (node) {
      if (isArtifact(node)) { hideNode(node); return; }
      if (hardProtected(node)) return;
      var r = rect(node);
      if (!r || r.width < 12 || r.height < 12) return;
      var lane = primaryContentRect();
      var outsideLane = lane ? (r.right <= lane.left - 6 || r.left >= lane.right + 6) : false;
      if (!outsideLane) return;
      if (r.width > 220 || r.height > 90) return;
      if (mediaCount(node) > 0) return;
      var value = txt(node);
      if (!value) return;
      if (/^€?\s*\d+[\d\.,]*$/.test(value) || /^[A-Za-z]{1,10}$/.test(value) || value.length < 28) hideNode(node);
    });
  }
  function ensureMasks() {
    if (!isHomePage()) return;
    var root = document.documentElement;
    if (!root) return;
    var lane = primaryContentRect();
    if (!lane || !isDesktop()) {
      root.style.setProperty('--ks-home-mask-left', '0px');
      root.style.setProperty('--ks-home-mask-right', '0px');
      root.style.setProperty('--ks-home-mask-top', '0px');
      return;
    }
    var header = first(document, 'header.tf-header') || first(document, 'header') || first(document, '.header-bottom');
    var top = 0;
    var hr = rect(header);
    if (hr) top = Math.max(0, Math.floor(hr.bottom));
    var leftWidth = Math.max(0, Math.floor(lane.left) - 4);
    var rightWidth = Math.max(0, Math.floor(window.innerWidth - lane.right) + 54);
    root.style.setProperty('--ks-home-mask-left', leftWidth + 'px');
    root.style.setProperty('--ks-home-mask-right', rightWidth + 'px');
    root.style.setProperty('--ks-home-mask-top', top + 'px');
  }

  function suppressPopup() {
    if (!isHomePage()) return;
    try { sessionStorage.setItem('showPopup', 'true'); localStorage.setItem('showPopup', 'true'); } catch (err) {}
    all(document, '.auto-popup,.modal-newleter,[class*="modal-newleter"],.modal-backdrop,.offcanvas-backdrop').forEach(hideNode);
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }
  function syncHero() {
    if (!isHomePage()) return;
    var shell = homeHeroShell();
    var slider = shell && first(shell, '.wrap-item-2');
    var side = shell && first(shell, '.wrap-item-3');
    var menuList = first(document, '.ks-home-departments .menu-category-list');
    var title = first(document, '.ks-home-departments .title');
    if (!shell || !slider) return;
    if (!isDesktop()) {
      shell.classList.remove('ks-home-force-compact');
      if (side) side.style.display = '';
      if (menuList) { menuList.style.maxHeight = ''; menuList.style.height = ''; }
      return;
    }
    var validSides = 0;
    if (side) {
      all(side, 'a,div').forEach(function (node) {
        var r = rect(node);
        if (!r || r.width < 80 || r.height < 80) return;
        if (!first(node, 'img')) return;
        validSides += 1;
      });
      if (validSides < 2) {
        shell.classList.add('ks-home-force-compact');
        side.style.display = 'none';
      } else {
        shell.classList.remove('ks-home-force-compact');
        side.style.display = '';
      }
    }
    var sliderTarget = first(slider, '.banner-image-product-4') || slider;
    var sr = rect(sliderTarget);
    var tr = rect(title);
    if (menuList && sr) {
      var h = Math.max(180, Math.floor(sr.height - (tr ? tr.height : 0) - 10));
      menuList.style.maxHeight = h + 'px';
      menuList.style.height = h + 'px';
      menuList.style.overflowY = 'auto';
    }
  }

  function findSearchRoot() {
    var candidates = all(document, 'form,.form-search-product,.header-center,.search-box,.search-form,.search-area,.main-search');
    for (var i = 0; i < candidates.length; i += 1) {
      var root = candidates[i];
      var input = first(root, 'input[type="search"],input[type="text"]');
      if (!input) continue;
      var placeholder = norm(input.getAttribute('placeholder') || '');
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
    if (/^\d+$/.test(raw)) { out.st = raw; }
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
      var ids = mergedRecent();
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
    return fetch(url, { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } }).then(function (r) {
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
  function showSuggest(root) { var b = ensureSuggest(root); b.classList.add('is-open'); b.setAttribute('aria-hidden', 'false'); }
  function hideSuggest(root) { var s = searchState(root); if (s.box) { s.box.classList.remove('is-open'); s.box.setAttribute('aria-hidden', 'true'); } s.active = -1; }
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
    if (idx < 0) idx = items.length - 1; if (idx >= items.length) idx = 0;
    s.active = idx;
    items.forEach(function (n, i) { n.classList.toggle('is-active', i === idx); });
  }
  function openActive(root) {
    var s = searchState(root);
    var item = s.items[s.active];
    if (item && item.url) { location.href = item.url; return true; }
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
    }).catch(function () { hideSuggest(root); });
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
    }).catch(function () { location.href = fallback; });
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
      var t = norm(txt(a));
      if (t === 'catalogo' || t.indexOf('catalog') !== -1) { navLink = a; return true; }
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
      var media = first(item, '.ks-menu-media').innerHTML || '';
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
          tips.slice(0, 10).forEach(function (tip) { html.push('<li><a href="' + esc(tip.href || '#') + '">' + esc(txt(tip)) + '</a></li>'); });
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

  function applyLanguage() {
    var lang = 'it';
    try { lang = (localStorage.getItem(LANG_KEY) || 'it').toLowerCase(); } catch (err) {}
    var isEn = lang.indexOf('en') === 0;
    var map = {
      'Tutti i settori': isEn ? 'All departments' : 'Tutti i settori',
      'Scopri ora': isEn ? 'Shop now' : 'Scopri ora',
      'Collezione reparto': isEn ? 'Department collection' : 'Collezione reparto',
      'Cerca prodotti, codici o EAN': isEn ? 'Search products, codes or EAN' : 'Cerca prodotti, codici o EAN'
    };
    Object.keys(map).forEach(function (src) {
      all(document, '*').forEach(function (node) {
        if (!node.children.length && txt(node) === src) node.textContent = map[src];
      });
    });
    var input = first(document, 'input[type="search"],input[type="text"]');
    if (input && /cerca|search|ean|codic|prodot/i.test(input.getAttribute('placeholder') || '')) input.setAttribute('placeholder', map['Cerca prodotti, codici o EAN']);
  }
  function bindLanguageSwitch() {
    all(document, 'select').forEach(function (select) {
      var options = all(select, 'option');
      var labels = options.map(function (o) { return norm(txt(o) || o.value); }).join(' ');
      if (labels.indexOf('italiano') === -1 && labels.indexOf('english') === -1 && labels.indexOf('italian') === -1) return;
      if (!options.some(function (o) { return norm(txt(o)).indexOf('english') !== -1; })) {
        var opt = document.createElement('option'); opt.textContent = 'English'; opt.value = 'English'; select.appendChild(opt);
      }
      if (!options.some(function (o) { return norm(txt(o)).indexOf('ital') !== -1; })) {
        var opt2 = document.createElement('option'); opt2.textContent = 'Italiano'; opt2.value = 'Italiano'; select.appendChild(opt2);
      }
      select.addEventListener('change', function () {
        var value = norm(select.value || txt(select.options[select.selectedIndex]));
        try { localStorage.setItem(LANG_KEY, value.indexOf('english') !== -1 ? 'en' : 'it'); } catch (err) {}
        applyLanguage();
      });
    });
  }

  function bootHome() {
    ensureCss();
    if (document.body && isHomePage()) document.body.classList.add('ks-page-home');
    if (isArticlePage()) addRecent(detectArticleId());
    suppressPopup();
    sweepArtifacts();
    ensureMasks();
    syncHero();
    bindSearch();
    buildCatalogMega();
    bindLanguageSwitch();
    applyLanguage();
  }

  var raf = 0;
  function rerun() {
    if (raf) return;
    raf = window.requestAnimationFrame(function () {
      raf = 0;
      suppressPopup();
      sweepArtifacts();
      ensureMasks();
      syncHero();
    });
  }

  function scheduleHomePasses() {
    if (!isHomePage()) return;
    [180, 900, 2400].forEach(function (delay) {
      window.setTimeout(rerun, delay);
    });
  }

  onReady(function () {
    bootHome();
    scheduleHomePasses();
    window.addEventListener('load', function () {
      bootHome();
      scheduleHomePasses();
    }, { once: true });
    window.addEventListener('resize', rerun, { passive: true });
  });
})();
