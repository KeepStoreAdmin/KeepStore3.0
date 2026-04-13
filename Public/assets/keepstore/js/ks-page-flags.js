(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var LANG_KEY = 'ks_ui_lang';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'demo', 'template', 'mediacom'];

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
  function normalizePath(path) {
    return String(path || '').toLowerCase().replace(/\/+$/,'').replace(/\/default\.aspx$/i, '') || '/';
  }
  function isHomePage() {
    var path = normalizePath(location.pathname || '/');
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

  function primaryLaneRect() {
    var shell = first(document, '.ks-home-hero-shell') || first(document, '.s-banner-wrapper');
    var r = rect(shell);
    if (r && r.width > 640) return r;
    var containers = all(document, '.container').map(rect).filter(function (box) { return box && box.width > 640; });
    if (!containers.length) return rect(first(document, '.container'));
    var best = containers[0];
    containers.forEach(function (box) {
      if (box.width > best.width) best = box;
    });
    return best;
  }
  function mediaCount(node) { return all(node, 'img,picture,svg,video,iframe,canvas').length; }
  function backgroundImage(node) { var s = styleOf(node); return s && s.backgroundImage && s.backgroundImage !== 'none' ? s.backgroundImage : ''; }
  function nodeRaw(node) {
    return [node.id || '', node.className || '', txt(node).slice(0, 200), normalizeSrc(node.getAttribute && (node.getAttribute('src') || node.getAttribute('data-src')) || ''), backgroundImage(node)].join(' ');
  }
  function hasBlockedToken(node) {
    var value = norm(nodeRaw(node));
    return BLOCKED_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
  }
  function isVertical(node) {
    var st = styleOf(node);
    if (!st) return false;
    var wm = String(st.writingMode || '').toLowerCase();
    var tr = String(st.transform || '').toLowerCase();
    return wm.indexOf('vertical') !== -1 || tr.indexOf('rotate(90') !== -1 || tr.indexOf('rotate(-90') !== -1;
  }
  function isProtected(node) {
    return !!closest(node, 'header,footer,.ks-home-departments,.ks-top-catalog-mega,.card-product,.tf-icon-box,.flat-title,.swiper,.modal,.offcanvas,.form-search-product');
  }
  function artifactRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;
    while (current && current.parentElement && hops < 6) {
      var parent = current.parentElement;
      if (!parent || parent === document.body || parent === document.documentElement) break;
      if (isProtected(parent)) break;
      var r = rect(parent);
      if (!r) break;
      if (r.width > 320 || r.height > 1600) break;
      best = parent;
      current = parent;
      hops += 1;
    }
    return best;
  }
  function hideNode(node) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-ks-edge-hidden', '1');
  }
  function outsideLane(r, lane) {
    if (!r) return false;
    if (!lane) return r.left < 40 || r.right > window.innerWidth - 40;
    return r.right <= lane.left - 8 || r.left >= lane.right + 8;
  }

  function applyGutterVars() {
    if (!isHomePage()) return;
    var lane = primaryLaneRect();
    if (!lane || !document.documentElement) return;
    var left = Math.max(0, Math.floor(lane.left - 12));
    var right = Math.max(0, Math.floor(window.innerWidth - lane.right - 12));
    var header = first(document, 'header.tf-header') || first(document, 'header');
    var hr = rect(header);
    var top = hr ? Math.max(0, Math.floor(hr.top + hr.height - 2)) : 0;
    document.documentElement.style.setProperty('--ks-left-gutter', left + 'px');
    document.documentElement.style.setProperty('--ks-right-gutter', right + 'px');
    document.documentElement.style.setProperty('--ks-mask-top', top + 'px');
  }

  function hideTokenArtifacts() {
    if (!isHomePage() || !document.body) return;
    all(document.body, 'div,a,span,p,small,strong,em,img,picture').forEach(function (node) {
      if (!node || isProtected(node)) return;
      var r = rect(node);
      if (!r || r.width < 8 || r.height < 12) return;
      if (!hasBlockedToken(node) && !isVertical(node)) return;
      hideNode(artifactRoot(node));
    });
  }
  function sweepEdgeArtifacts() {
    if (!isHomePage() || !document.body || !isDesktop()) return;
    var lane = primaryLaneRect();
    all(document.body, 'div,aside,section,a,span,p,small,strong,em,label,img,picture,li').forEach(function (node) {
      if (!node || node === document.body) return;
      var r = rect(node);
      if (!r || r.width < 12 || r.height < 20) return;
      if (!outsideLane(r, lane)) return;
      if (isProtected(node) && !hasBlockedToken(node) && !isVertical(node)) return;
      var st = styleOf(node);
      var pos = st ? String(st.position || '') : '';
      var narrow = r.width <= 240;
      var suspicious = hasBlockedToken(node) || isVertical(node) || (mediaCount(node) > 0 && narrow) || (backgroundImage(node) && narrow);
      var positioned = pos === 'fixed' || pos === 'sticky' || (pos === 'absolute' && narrow);
      if (suspicious || positioned) hideNode(artifactRoot(node));
    });
    var repeated = Object.create(null);
    all(document.body, 'img').forEach(function (img) {
      var r = rect(img);
      if (!r || !outsideLane(r, lane) || r.width > 180 || r.height > 320) return;
      var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
      if (!src || src.indexOf('data:image') === 0) return;
      repeated[src] = repeated[src] || [];
      repeated[src].push(img);
    });
    Object.keys(repeated).forEach(function (src) {
      if (repeated[src].length < 2) return;
      repeated[src].forEach(function (img) { hideNode(artifactRoot(img)); });
    });
  }
  function hideHeaderClones() {
    if (!isHomePage()) return;
    var mainHeader = first(document, 'header.tf-header') || first(document, 'header');
    if (!mainHeader) return;
    var hr = rect(mainHeader);
    var threshold = hr ? hr.bottom + 140 : 260;
    all(document.body, 'header,.tf-header,.tf-topbar,.header-bottom,.inner-header,.logo-site,.support-wrap,.nav-icon').forEach(function (node) {
      if (!node || node === mainHeader || closest(node, 'header') === mainHeader) return;
      var r = rect(node);
      if (!r || r.top < threshold || r.width < window.innerWidth * 0.45 || r.height < 20) return;
      hideNode(artifactRoot(node));
    });
  }
  function hideOrphanFragments() {
    if (!isHomePage() || !isDesktop()) return;
    var lane = primaryLaneRect();
    all(document.body, 'p,span,small,strong,em,div').forEach(function (node) {
      if (!node || node.children.length) return;
      if (closest(node, 'header,footer,.ks-home-departments,.card-product,.product-list-wrap,.swiper,.flat-title,.modal,.offcanvas,.form-search-product')) return;
      var value = txt(node);
      if (!value) return;
      var r = rect(node);
      if (!r || !outsideLane(r, lane)) return;
      if (/^€?\s*\d+[\d\.,]*$/.test(value) || value.length < 24) hideNode(node);
    });
  }
  function syncHeroCompact() {
    if (!isHomePage()) return;
    var shell = first(document, '.ks-home-hero-shell') || first(document, '.s-banner-wrapper');
    if (!shell) return;
    if (shell.classList && !shell.classList.contains('ks-home-hero-shell')) shell.classList.add('ks-home-hero-shell');
    var slider = first(shell, '.wrap-item-2');
    var side = first(shell, '.wrap-item-3');
    var menuList = first(document, '.ks-home-departments .menu-category-list');
    var title = first(document, '.ks-home-departments .title');
    if (!slider) return;
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
    var sliderRect = rect(first(slider, '.banner-image-product-4') || slider);
    var titleRect = rect(title);
    if (menuList && sliderRect) {
      var height = Math.max(180, Math.floor(sliderRect.height - (titleRect ? titleRect.height : 0) - 10));
      menuList.style.maxHeight = height + 'px';
      menuList.style.height = height + 'px';
      menuList.style.overflowY = 'auto';
    }
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
      var parts = raw.split(/[:=]/); out[parts[0].toLowerCase()] = parts[1]; return out;
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
  function searchState(root) { if (!root.__ksSearch) root.__ksSearch = { box: null, items: [], active: -1, timer: 0, token: '' }; return root.__ksSearch; }
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
    var s = searchState(root), box = ensureSuggest(root);
    s.items = data && data.suggestions ? data.suggestions.slice() : [];
    if (!s.items.length) { box.innerHTML = '<div class="ks-suggest-empty">Nessun suggerimento disponibile.</div>'; showSuggest(root); return; }
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
    var s = searchState(root); var item = s.items[s.active];
    if (item && item.url) { location.href = item.url; return true; }
    return false;
  }
  function requestSuggest(root, recentMode) {
    var q = searchValue(root); var useRecent = recentMode || q.length < 2; var url = buildSuggestUrl(root, q, useRecent ? 8 : 10, useRecent); var s = searchState(root); s.token = url;
    return fetchJson(url).then(function (data) { if (s.token !== url) return; renderSuggest(root, data || {}); }).catch(function () { hideSuggest(root); });
  }
  function submitSearch(root) {
    var q = searchValue(root); var fallback = buildSearchUrl(root); var url = buildSuggestUrl(root, q, 60, !q || q.length < 2);
    fetchJson(url).then(function (data) {
      if (data && data.strong && data.strong.canRedirect && data.strong.redirectUrl) { location.href = data.strong.redirectUrl; return; }
      location.href = fallback;
    }).catch(function () { location.href = fallback; });
  }
  function bindSearch() {
    var root = findSearchRoot(); if (!root || root.getAttribute('data-ks-search-bound') === '1') return;
    var input = searchInput(root); if (!input) return;
    var submit = searchSubmit(root); root.setAttribute('data-ks-search-bound', '1'); input.setAttribute('autocomplete', 'off');
    input.addEventListener('input', function () { var s = searchState(root); clearTimeout(s.timer); s.timer = setTimeout(function () { requestSuggest(root, false); }, 180); });
    input.addEventListener('focus', function () { requestSuggest(root, true); });
    input.addEventListener('keydown', function (e) {
      var s = searchState(root); var count = s.items.length;
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

  function homePass() {
    if (!isHomePage()) return;
    document.body.classList.add('ks-page-home');
    suppressPopup();
    syncHeroCompact();
    applyGutterVars();
    hideHeaderClones();
    hideTokenArtifacts();
    sweepEdgeArtifacts();
    hideOrphanFragments();
  }

  onReady(function () {
    if (isArticlePage()) addRecent(detectArticleId());
    bindSearch();
    buildCatalogMega();
    bindLanguageSwitch();
    applyLanguage();
    homePass();
    if (isHomePage()) {
      [250, 1200, 2600].forEach(function (delay) { window.setTimeout(homePass, delay); });
      window.addEventListener('load', homePass, { once: true });
      var resizeTimer = 0;
      window.addEventListener('resize', function () {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(homePass, 120);
      }, { passive: true });
    }
  });
})();
