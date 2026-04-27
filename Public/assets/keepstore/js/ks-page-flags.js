(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var LOCAL_KEY = 'ks_recent_items';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var SUGGEST_TIMEOUT_MS = 4200;
  var SUBMIT_LOOKUP_TIMEOUT_MS = 900;
  var RANK_PREFIX = 'ks_search_rank_';
  var MARKET_KEY = 'ks_ai_marketplace_135_query';
  var COMPARE_KEY = 'ks_compare_products';
  var STYLE_ID = 'ks-page-flags-step135-style';
  var BOUND_ATTR = 'data-ks-suggest-bound';

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function q(root, selector) { return (root || document).querySelector(selector); }
  function all(root, selector) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  }
  function txt(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function readCookie(name) {
    var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }
  function parseIds(raw) {
    return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) {
      return Number.isFinite(id) && id > 0;
    });
  }
  function readSessionRecent() {
    try { return parseIds(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }
  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
  }
  function readLocalRecent() {
    try { return parseIds(window.localStorage.getItem(LOCAL_KEY) || ''); } catch (err) { return []; }
  }
  function writeLocalRecent(list) {
    try { window.localStorage.setItem(LOCAL_KEY, (list || []).join(',')); } catch (err) {}
  }
  function readMergedRecent() {
    var seen = Object.create(null), out = [];
    [readSessionRecent(), readLocalRecent(), parseIds(readCookie(COOKIE_NAME))].forEach(function (list) {
      (list || []).forEach(function (id) {
        if (!id || seen[id]) return;
        seen[id] = 1;
        out.push(id);
      });
    });
    return out.slice(0, MAX_RECENT);
  }
  function updateRecent(id) {
    if (!id || id <= 0) return;
    var next = [id].concat(readMergedRecent().filter(function (n) { return n !== id; })).slice(0, MAX_RECENT);
    writeLocalRecent(next);
    writeSessionRecent(next);
  }
  function pathIsHome() {
    var path = (window.location.pathname || '/').toLowerCase();
    return path === '/' || /\/default\.aspx$/i.test(path);
  }
  function pathIsArticle() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
  function pathIsCatalog() { return /\/articoli\.aspx$/i.test(window.location.pathname || ''); }
  function parseArticleId(href) {
    var match = String(href || '').match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) || 0 : 0;
  }
  function detectArticleId() {
    try {
      var direct = parseInt((new URLSearchParams(window.location.search || '')).get('id'), 10);
      if (Number.isFinite(direct) && direct > 0) return direct;
    } catch (err) {}
    var canonical = q(document, 'link[rel="canonical"]');
    var fromCanonical = canonical ? parseArticleId(canonical.getAttribute('href')) : 0;
    if (fromCanonical) return fromCanonical;
    var link = q(document, 'a[href*="articolo.aspx?id="]');
    return link ? parseArticleId(link.getAttribute('href')) : 0;
  }

  function ensureStepStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var st = document.createElement('style');
    st.id = STYLE_ID;
    st.textContent = [
      'body.ks-page-home.ks-home-step135-onsus-market{background:#f4f4f4!important;}',
      '.tf-header,.tf-header .inner-header,.tf-header .header-center,.ks-header-ui,.ks-header-ui .container{overflow:visible!important;}',
      '.ks-header-ui{position:relative;z-index:1500;}',
      '.ks-search-host{position:relative!important;}',
      '.ks-header-ui .logo-site img,.tf-header .logo-site img{max-height:54px;max-width:176px;object-fit:contain;display:block;}',
      '.ks-header-ui .logo-site{min-width:150px;display:flex;align-items:center;}',
      '.ks-search-host input[type="text"],.ks-search-host input[type="search"]{outline:none;}',
      '.ks-suggest{position:absolute;left:0;right:0;top:calc(100% + 9px);z-index:6000;background:#fff;border:1px solid #edf1f5;border-radius:18px;box-shadow:0 22px 54px rgba(15,23,42,.18);padding:8px;display:none;max-height:520px;overflow:auto;text-align:left;}',
      '.ks-suggest.is-open{display:block;}',
      '.ks-suggest-head{display:flex;justify-content:space-between;gap:12px;padding:9px 12px 8px;font-size:11px;font-weight:900;letter-spacing:.07em;text-transform:uppercase;color:#ef4444;}',
      '.ks-suggest-list{list-style:none;margin:0;padding:0;display:grid;gap:4px;}',
      '.ks-suggest-item{display:grid;grid-template-columns:58px minmax(0,1fr) auto;gap:12px;align-items:center;padding:10px 12px;border-radius:14px;text-decoration:none;color:#111827;}',
      '.ks-suggest-item.is-active,.ks-suggest-item:hover{background:#f8fafc;color:#111827;}',
      '.ks-suggest-thumb{width:58px;height:58px;border-radius:13px;background:#f4f6f8;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ks-suggest-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-suggest-meta{min-width:0;display:grid;gap:4px;}',
      '.ks-suggest-title{font-size:13px;line-height:1.28;font-weight:800;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
      '.ks-suggest-sub{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}',
      '.ks-suggest-sub b{font-weight:900;color:#111827;}',
      '.ks-suggest-price{font-size:14px;font-weight:900;color:#ef4444;white-space:nowrap;}',
      '.ks-suggest-foot{display:flex;justify-content:space-between;gap:10px;padding:9px 12px 5px;border-top:1px solid #edf1f5;margin-top:6px;font-size:12px;color:#64748b;}',
      '.ks-suggest-empty{padding:14px;color:#64748b;font-size:13px;}',
      '.ks-header-catalog-item.is-open>.sub-menu-container,.ks-header-catalog-item:focus-within>.sub-menu-container{transform:translateY(0)!important;opacity:1!important;visibility:visible!important;pointer-events:auto!important;}',
      '.ks-header-catalog-item.is-open>.item-link .icon{transform:rotate(180deg);color:var(--primary);}',
      '.ks-market135{margin:26px 0 34px;}',
      '.ks-market135 .ks-market-wrap{display:grid;grid-template-columns:280px minmax(0,1fr);gap:18px;align-items:stretch;}',
      '.ks-market135-panel{border-radius:18px;padding:18px;color:#fff;background:radial-gradient(circle at 0% 0%,rgba(239,68,68,.55),transparent 35%),linear-gradient(145deg,#111827 0%,#1f2937 55%,#5b1f2e 100%);box-shadow:0 18px 40px rgba(15,23,42,.14);}',
      '.ks-market135-kicker{display:block;margin-bottom:5px;text-transform:uppercase;letter-spacing:.08em;font-size:10px;font-weight:900;color:#fecaca;}',
      '.ks-market135-panel h3{margin:0 0 7px;font-size:22px;line-height:1.08;color:#fff;}',
      '.ks-market135-panel p{margin:0 0 14px;color:rgba(255,255,255,.76);font-size:12px;line-height:1.45;}',
      '.ks-market135-search{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;margin-bottom:10px;}',
      '.ks-market135-search input,.ks-market135-budget input,.ks-market135-sort select{border:0;border-radius:999px;min-height:39px;padding:0 13px;background:rgba(255,255,255,.96);color:#111827;font-size:12px;}',
      '.ks-market135-search button,.ks-market135-card .ks-market135-btn,.ks-market135-open{border:0;border-radius:999px;background:#ef4444;color:#fff;font-weight:900;min-height:38px;padding:0 14px;text-decoration:none;display:inline-flex;align-items:center;justify-content:center;font-size:12px;}',
      '.ks-market135-tools{display:grid;gap:9px;margin:10px 0;}',
      '.ks-market135-row{display:grid;grid-template-columns:1fr 1fr;gap:8px;}',
      '.ks-market135-checks{display:flex;gap:8px;flex-wrap:wrap;}',
      '.ks-market135-check{display:flex;gap:6px;align-items:center;font-size:11px;color:rgba(255,255,255,.86);}',
      '.ks-market135-check input{accent-color:#ef4444;}',
      '.ks-market135-chips{display:flex;gap:6px;flex-wrap:wrap;margin:11px 0;}',
      '.ks-market135-chips button{border:1px solid rgba(255,255,255,.15);background:rgba(255,255,255,.08);color:#fff;border-radius:999px;padding:6px 9px;font-size:11px;}',
      '.ks-market135-ai{margin-top:12px;padding:12px;border-radius:14px;background:rgba(255,255,255,.08);font-size:11px;line-height:1.45;color:rgba(255,255,255,.82);}',
      '.ks-market135-results{border-radius:18px;padding:16px;background:#fff;box-shadow:0 16px 36px rgba(15,23,42,.07);}',
      '.ks-market135-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;margin-bottom:12px;}',
      '.ks-market135-head h4{margin:0;font-size:18px;}',
      '.ks-market135-count{font-size:11px;font-weight:900;color:#ef4444;text-transform:uppercase;white-space:nowrap;}',
      '.ks-market135-facets{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:13px;}',
      '.ks-market135-facets button{border:1px solid #edf1f5;background:#f8fafc;border-radius:999px;padding:5px 9px;font-size:11px;font-weight:800;color:#475569;}',
      '.ks-market135-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;}',
      '.ks-market135-card{position:relative;display:grid;grid-template-rows:118px 18px minmax(44px,auto) 18px 28px;border:1px solid #edf1f5;border-radius:14px;padding:10px;background:#fff;min-width:0;}',
      '.ks-market135-media{height:118px;border-radius:11px;background:#f7f8fb;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ks-market135-media img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-market135-card h5{margin:0;font-size:12px;line-height:1.23;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;text-transform:uppercase;}',
      '.ks-market135-card h5 a{color:#005aa7;text-decoration:none;}',
      '.ks-market135-meta{font-size:10px;color:#64748b;display:flex;gap:5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
      '.ks-market135-price{font-size:13px;font-weight:900;color:#ef4444;}',
      '.ks-market135-badges{position:absolute;top:7px;left:7px;display:flex;gap:4px;flex-wrap:wrap;}',
      '.ks-market135-badges span{background:#ef4444;color:#fff;border-radius:999px;font-size:9px;font-weight:900;padding:3px 5px;}',
      '.ks-market135-card .ks-market135-btn{min-height:28px;padding:0 10px;}',
      '.ks-market135-actions{display:flex;gap:7px;align-items:center;justify-content:space-between;}',
      '.ks-market135-compare{border:1px solid #edf1f5;background:#f8fafc;border-radius:999px;min-height:28px;padding:0 9px;font-size:11px;font-weight:800;color:#475569;}',
      '.ks-market135-reason{display:none;}',
      '@media (max-width:1199.98px){.ks-market135 .ks-market-wrap{grid-template-columns:1fr}.ks-market135-grid{grid-template-columns:repeat(3,minmax(0,1fr));}}',
      '@media (max-width:767.98px){.ks-market135-grid{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-market135-row{grid-template-columns:1fr}.ks-market135-head{display:grid}.ks-suggest{left:-8px;right:-8px;}}',
      '@media (max-width:480px){.ks-market135-grid{grid-template-columns:1fr}.ks-market135-card{grid-template-rows:150px auto auto auto auto}.ks-market135-media{height:150px;}}'
    ].join('');
    (document.head || document.documentElement).appendChild(st);
  }

  function fetchJson(url, signal) {
    var options = { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } };
    if (signal) options.signal = signal;
    return fetch(url, options).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function fetchJsonTimed(url, timeoutMs, ctrl) {
    var done = false, timer = 0, signal = null;
    if (!ctrl && window.AbortController) ctrl = new AbortController();
    if (ctrl && ctrl.signal) signal = ctrl.signal;
    return new Promise(function (resolve, reject) {
      timer = window.setTimeout(function () {
        if (done) return;
        done = true;
        try { if (ctrl && ctrl.abort) ctrl.abort(); } catch (err) {}
        reject(new Error('timeout'));
      }, timeoutMs || SUGGEST_TIMEOUT_MS);
      fetchJson(url, signal).then(function (data) {
        if (done) return;
        done = true;
        window.clearTimeout(timer);
        resolve(data);
      }).catch(function (err) {
        if (done) return;
        done = true;
        window.clearTimeout(timer);
        reject(err);
      });
    });
  }
  function buildQueryUrl(params) {
    var u = new URL(SEARCH_ENDPOINT, window.location.href);
    Object.keys(params || {}).forEach(function (k) {
      var v = params[k];
      if (v !== undefined && v !== null && v !== '') u.searchParams.set(k, String(v));
    });
    return u.toString();
  }
  function isSearchInput(input) {
    if (!input || input.disabled || input.type === 'hidden' || input.type === 'email' || input.type === 'password') return false;
    var raw = [input.id, input.name, input.placeholder, input.getAttribute('aria-label')].join(' ').toLowerCase();
    return /cerca|search|prodot|codic|ean|catalog/.test(raw);
  }
  function searchRoots() {
    var out = [];
    all(document, '.ks-search-shell,.form-search-product,form').forEach(function (node) {
      var input = all(node, 'input[type="text"],input[type="search"],input:not([type])').filter(isSearchInput)[0];
      if (!input) return;
      var root = input.closest('.ks-search-shell,.form-search-product') || node;
      if (root && out.indexOf(root) < 0) out.push(root);
    });
    return out;
  }
  function inputFromRoot(root) { return all(root, 'input[type="text"],input[type="search"],input:not([type])').filter(isSearchInput)[0] || null; }
  function selectFromRoot(root) { return q(root, 'select.dropdown_product_cat,select'); }
  function buttonsFromRoot(root) { return all(root, 'button,.btn-submit-form,[role="button"].btn-submit-form,input[type="submit"]'); }
  function searchValue(root) {
    var input = inputFromRoot(root);
    return String(input && input.value || '').replace(/\s+/g, ' ').trim();
  }
  function selectedUrlParams(root) {
    var sel = selectFromRoot(root), params = {};
    if (!sel) return params;
    var val = String(sel.value || '').trim();
    if (!val) return params;
    try {
      var u = new URL(val, window.location.href);
      u.searchParams.forEach(function (v, k) { if (v) params[k] = v; });
    } catch (err) {}
    return params;
  }
  function selectedCatalogBase(root) {
    var sel = selectFromRoot(root);
    if (!sel || !String(sel.value || '').trim()) return new URL('/articoli.aspx', window.location.href);
    try { return new URL(sel.value, window.location.href); } catch (err) { return new URL('/articoli.aspx', window.location.href); }
  }
  function buildSuggestUrl(root, query, limit, recent) {
    var u = new URL(SEARCH_ENDPOINT, window.location.href);
    var params = selectedUrlParams(root);
    Object.keys(params).forEach(function (k) { u.searchParams.set(k, params[k]); });
    if (query) u.searchParams.set('q', query);
    if (recent) {
      var ids = readMergedRecent();
      if (ids.length) u.searchParams.set('recent', ids.slice(0, 24).join(','));
    }
    u.searchParams.set('limit', String(limit || 10));
    u.searchParams.set('mode', 'marketplace');
    return u.toString();
  }
  function buildCatalogUrl(root) {
    var u = selectedCatalogBase(root);
    var params = selectedUrlParams(root);
    Object.keys(params).forEach(function (k) { u.searchParams.set(k, params[k]); });
    var val = searchValue(root);
    if (val) u.searchParams.set('q', val);
    return u;
  }
  function resizeSearchCategory(root) {
    var sel = selectFromRoot(root);
    if (!root || !sel) return;
    var text = '';
    try {
      text = sel.options && sel.selectedIndex >= 0 ? sel.options[sel.selectedIndex].text : '';
    } catch (err) {}
    text = String(text || 'Tutti i settori').replace(/\s+/g, ' ').trim();
    var px = Math.max(128, Math.min(260, 42 + (text.length * 7.4)));
    root.style.setProperty('--ks-search-category-width', Math.round(px) + 'px');
  }
  function looksLikeDirectCode(query) {
    var value = String(query || '').replace(/\s+/g, ' ').trim();
    if (!value || value.length < 3 || value.length > 48) return false;
    if (/^\d{8,14}$/.test(value)) return true;
    return /^[a-z0-9][a-z0-9._\-\/]{2,47}$/i.test(value);
  }
  function state(root) {
    if (!root.__ksSearch135) root.__ksSearch135 = { box: null, items: [], active: -1, hideTimer: 0, token: '', ctrl: null };
    return root.__ksSearch135;
  }
  function ensureSuggest(root) {
    var s = state(root);
    if (s.box && s.box.parentNode) return s.box;
    root.classList.add('ks-search-host');
    var old = q(root, '.ks-search-suggest');
    var box = old || document.createElement('div');
    box.className = 'ks-suggest ks-search-suggest';
    box.setAttribute('aria-hidden', 'true');
    box.setAttribute('role', 'listbox');
    if (!old) root.appendChild(box);
    box.addEventListener('mousedown', function (e) { e.preventDefault(); });
    s.box = box;
    return box;
  }
  function showSuggest(root) {
    var b = ensureSuggest(root);
    b.classList.add('is-open');
    b.setAttribute('aria-hidden', 'false');
  }
  function hideSuggest(root) {
    var s = state(root);
    if (s.box) {
      s.box.classList.remove('is-open');
      s.box.setAttribute('aria-hidden', 'true');
    }
    s.active = -1;
  }
  function setActive(root, idx) {
    var s = state(root), nodes = all(s.box, '.ks-suggest-item');
    if (!nodes.length) { s.active = -1; return; }
    if (idx < 0) idx = nodes.length - 1;
    if (idx >= nodes.length) idx = 0;
    s.active = idx;
    nodes.forEach(function (n, i) { n.classList.toggle('is-active', i === idx); });
    try { nodes[idx].scrollIntoView({ block: 'nearest' }); } catch (err) {}
  }
  function openActive(root, idx) {
    var s = state(root), item = s.items[idx >= 0 ? idx : s.active];
    if (!item || !item.url) return false;
    window.location.href = item.url;
    return true;
  }
  function priceText(value) { return value ? ('&euro;' + esc(value)) : ''; }
  function renderSuggestMessage(root, message) {
    var box = ensureSuggest(root);
    box.innerHTML = '<div class="ks-suggest-empty">' + esc(message) + '</div>';
    showSuggest(root);
  }
  function renderSuggest(root, data) {
    var s = state(root), box = ensureSuggest(root), items = data && data.suggestions ? data.suggestions.slice(0, 10) : [];
    s.items = items;
    s.active = -1;
    if (!items.length) {
      box.innerHTML = '<div class="ks-suggest-empty">Nessun suggerimento disponibile. Premi Invio per cercare nel catalogo.</div>';
      showSuggest(root);
      return;
    }
    var head = data && data.recent ? 'Articoli recenti' : 'Suggerimenti catalogo';
    var html = ['<div class="ks-suggest-head"><span>' + esc(head) + '</span><span>Invio: catalogo</span></div><ul class="ks-suggest-list">'];
    items.forEach(function (item, i) {
      var img = item.image || item.image_fallback || item.imageUrl || '';
      var meta = [];
      if (item.brand) meta.push('<span><b>' + esc(item.brand) + '</b></span>');
      if (item.category) meta.push('<span>' + esc(item.category) + '</span>');
      if (item.code) meta.push('<span>Cod. ' + esc(item.code) + '</span>');
      if (item.ean) meta.push('<span>EAN ' + esc(item.ean) + '</span>');
      if (item.matchKind) meta.push('<span>' + esc(item.matchKind) + '</span>');
      html.push('<li><a class="ks-suggest-item" href="' + esc(item.url || '#') + '" data-idx="' + i + '">' +
        '<span class="ks-suggest-thumb">' + (img ? '<img src="' + esc(img) + '" alt="' + esc(item.title || '') + '">' : '') + '</span>' +
        '<span class="ks-suggest-meta"><span class="ks-suggest-title">' + esc(item.title || '') + '</span><span class="ks-suggest-sub">' + meta.join('') + '</span></span>' +
        '<span class="ks-suggest-price">' + priceText(item.price) + '</span></a></li>');
    });
    html.push('</ul><div class="ks-suggest-foot"><span>Ricerca per codice, EAN, marca, categoria e compatibilita.</span><span>' + esc(items.length) + ' risultati</span></div>');
    box.innerHTML = html.join('');
    all(box, '.ks-suggest-item').forEach(function (a) {
      a.addEventListener('mouseenter', function () { setActive(root, parseInt(a.getAttribute('data-idx') || '-1', 10)); });
      a.addEventListener('click', function (e) { e.preventDefault(); window.location.href = a.getAttribute('href') || '#'; });
    });
    showSuggest(root);
  }
  function requestSuggest(root, forceRecent) {
    var query = searchValue(root), recent = forceRecent || query.length < 2, url = buildSuggestUrl(root, query, recent ? 8 : 10, recent), s = state(root);
    s.token = url;
    if (s.ctrl && s.ctrl.abort) { try { s.ctrl.abort(); } catch (err) {} }
    if (window.AbortController) s.ctrl = new AbortController();
    return fetchJsonTimed(url, SUGGEST_TIMEOUT_MS, s.ctrl).then(function (data) {
      if (s.token !== url) return;
      if (!data || data.ok === false) {
        if (window.console && data && data.error) console.warn('[KeepStore search]', data.error);
        renderSuggestMessage(root, 'Suggerimenti non disponibili. Premi Invio per cercare nel catalogo.');
        return;
      }
      renderSuggest(root, data);
    }).catch(function (err) {
      if (err && err.name === 'AbortError') return;
      if (window.console) console.warn('[KeepStore search]', err && err.message ? err.message : err);
      renderSuggestMessage(root, 'Errore temporaneo nella suggest. Premi Invio per cercare nel catalogo.');
    });
  }
  function rankKey(seed) {
    var h = 0, i, chr;
    seed = String(seed || '') + '|' + Date.now();
    for (i = 0; i < seed.length; i++) { chr = seed.charCodeAt(i); h = ((h << 5) - h) + chr; h |= 0; }
    return Math.abs(h).toString(36);
  }
  function saveRank(key, data) {
    try { sessionStorage.setItem(RANK_PREFIX + key, JSON.stringify({ ids: data.rank_ids || [], ts: Date.now() })); } catch (err) {}
  }
  function readRank(key) {
    try { return JSON.parse(sessionStorage.getItem(RANK_PREFIX + key) || 'null'); } catch (err) { return null; }
  }
  function resolveSearch(root) {
    var fallback = buildCatalogUrl(root), query = searchValue(root), url = '';
    hideSuggest(root);
    if (!query || !looksLikeDirectCode(query)) {
      window.location.href = fallback.toString();
      return;
    }
    url = buildSuggestUrl(root, query, 3, false);
    fetchJsonTimed(url, SUBMIT_LOOKUP_TIMEOUT_MS).then(function (data) {
      if (data && data.strong && data.strong.canRedirect && data.strong.redirectUrl) {
        window.location.href = data.strong.redirectUrl;
        return;
      }
      if (data && data.catalogUrl) {
        try { fallback = new URL(data.catalogUrl, window.location.href); } catch (err) {}
      }
      window.location.href = fallback.toString();
    }).catch(function () { window.location.href = fallback.toString(); });
  }
  function bindHeaderSearch() {
    ensureStepStyle();
    searchRoots().forEach(function (root) {
      if (root.getAttribute(BOUND_ATTR) === '135') return;
      root.setAttribute(BOUND_ATTR, '135');
      ensureSuggest(root);
      var input = inputFromRoot(root), timer = 0;
      resizeSearchCategory(root);
      var select = selectFromRoot(root);
      if (select) select.addEventListener('change', function () { resizeSearchCategory(root); });
      function queue(recent) {
        clearTimeout(timer);
        timer = setTimeout(function () { requestSuggest(root, recent); }, 220);
      }
      if (input) {
        input.setAttribute('autocomplete', 'off');
        input.setAttribute('aria-autocomplete', 'list');
        input.addEventListener('focus', function () { queue(true); });
        input.addEventListener('input', function () { queue(false); });
        input.addEventListener('blur', function () {
          var s = state(root);
          clearTimeout(s.hideTimer);
          s.hideTimer = setTimeout(function () { hideSuggest(root); }, 190);
        });
        input.addEventListener('keydown', function (e) {
          var s = state(root), open = s.box && s.box.classList.contains('is-open');
          if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (!open) requestSuggest(root, searchValue(root).length < 2).then(function () { setActive(root, 0); });
            else setActive(root, s.active + 1);
            return;
          }
          if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (!open) requestSuggest(root, searchValue(root).length < 2).then(function () { setActive(root, -1); });
            else setActive(root, s.active - 1);
            return;
          }
          if (e.key === 'Escape') { e.preventDefault(); hideSuggest(root); return; }
          if (e.key === 'Enter') {
            e.preventDefault();
            e.stopPropagation();
            if (!(open && s.active >= 0 && openActive(root, s.active))) resolveSearch(root);
          }
        }, true);
      }
      buttonsFromRoot(root).forEach(function (button) {
        button.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          resolveSearch(root);
        }, true);
      });
    });
  }
  function bindGlobalSubmitGuard() {
    if (document.__ksSearchSubmitGuard135) return;
    document.__ksSearchSubmitGuard135 = true;
    document.addEventListener('submit', function (e) {
      var target = e.target;
      var active = document.activeElement;
      var root = active ? active.closest('.ks-search-shell,.form-search-product') : null;
      if (!root && target) root = q(target, '.ks-search-shell,.form-search-product');
      if (!root || !inputFromRoot(root)) return;
      e.preventDefault();
      e.stopPropagation();
      resolveSearch(root);
    }, true);
    document.addEventListener('click', function (e) {
      searchRoots().forEach(function (root) {
        if (!root.contains(e.target)) hideSuggest(root);
      });
    });
  }

  function bindCatalogNavigation() {
    var desktopItems = all(document, '.ks-header-catalog-item');
    desktopItems.forEach(function (item) {
      if (item.getAttribute('data-ks-catalog-bound') === '1') return;
      item.setAttribute('data-ks-catalog-bound', '1');
      var trigger = q(item, ':scope > .item-link') || q(item, '.item-link');
      var panel = q(item, ':scope > .sub-menu-container') || q(item, '.sub-menu-container');
      if (!trigger || !panel) return;
      trigger.setAttribute('aria-haspopup', 'true');
      trigger.setAttribute('aria-expanded', 'false');
      function setOpen(open) {
        item.classList.toggle('is-open', open);
        trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
      }
      item.addEventListener('mouseenter', function () {
        desktopItems.forEach(function (other) { if (other !== item) other.classList.remove('is-open'); });
        setOpen(true);
      });
      trigger.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        desktopItems.forEach(function (other) { if (other !== item) other.classList.remove('is-open'); });
        setOpen(true);
      }, true);
      item.addEventListener('mouseleave', function () { setOpen(false); });
    });

    all(document, '.mobile-button[data-bs-target="#mobileMenu"],.mobile-button[aria-controls="mobileMenu"]').forEach(function (btn) {
      if (btn.getAttribute('data-ks-mobile-menu-bound') === '1') return;
      btn.setAttribute('data-ks-mobile-menu-bound', '1');
      btn.addEventListener('click', function (e) {
        var menu = document.getElementById('mobileMenu');
        if (!menu) return;
        e.preventDefault();
        e.stopPropagation();
        if (window.bootstrap && bootstrap.Offcanvas) {
          bootstrap.Offcanvas.getOrCreateInstance(menu).show();
        } else {
          menu.classList.add('show');
          menu.style.visibility = 'visible';
          document.body.classList.add('offcanvas-open');
        }
      }, true);
    });

    all(document, '#mobileMenu [data-bs-toggle="collapse"][data-bs-target]').forEach(function (trigger) {
      if (trigger.getAttribute('data-ks-collapse-bound') === '1') return;
      trigger.setAttribute('data-ks-collapse-bound', '1');
      trigger.addEventListener('click', function (e) {
        var targetId = trigger.getAttribute('data-bs-target') || '';
        var target = targetId ? document.querySelector(targetId) : null;
        if (!target) return;
        e.preventDefault();
        e.stopPropagation();
        if (window.bootstrap && bootstrap.Collapse) {
          bootstrap.Collapse.getOrCreateInstance(target, { toggle: false }).toggle();
        } else {
          target.classList.toggle('show');
        }
        var expanded = target.classList.contains('show');
        trigger.classList.toggle('collapsed', !expanded);
        trigger.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      }, true);
    });

    if (!document.__ksCatalogCloseBound135) {
      document.__ksCatalogCloseBound135 = true;
      document.addEventListener('click', function (e) {
        if (e.target && e.target.closest && e.target.closest('.ks-header-catalog-item')) return;
        all(document, '.ks-header-catalog-item').forEach(function (item) {
          item.classList.remove('is-open');
          var trigger = q(item, ':scope > .item-link') || q(item, '.item-link');
          if (trigger) trigger.setAttribute('aria-expanded', 'false');
        });
      });
    }
  }
  function applyRankingOnCatalog() {
    if (!pathIsCatalog()) return;
    var params = new URLSearchParams(window.location.search || ''), key = params.get('ksrk') || '', cached = readRank(key);
    if (!cached || !cached.ids || !cached.ids.length) return;
    var links = all(document, 'a[href*="articolo.aspx?id="]'), cards = [], seen = Object.create(null);
    links.forEach(function (a) {
      if (a.closest('header,footer,.ks-suggest')) return;
      var id = parseArticleId(a.getAttribute('href'));
      if (!id || seen[id]) return;
      var node = a.closest('.card-product,.product-item,.col,.grid-item,li,.swiper-slide,article') || a;
      if (node && node.parentNode) { seen[id] = 1; cards.push({ id: id, node: node, parent: node.parentNode }); }
    });
    if (!cards.length) return;
    var container = cards[0].parent, best = 0;
    cards.forEach(function (c) {
      var count = cards.filter(function (x) { return x.parent === c.parent; }).length;
      if (count > best) { best = count; container = c.parent; }
    });
    var map = Object.create(null);
    cards.forEach(function (c) { if (c.parent === container) map[c.id] = c.node; });
    cached.ids.forEach(function (id) { if (map[id]) container.appendChild(map[id]); });
  }

  function localHomeProducts(limit) {
    var out = [], seen = Object.create(null);
    all(document, 'a[href*="articolo.aspx?id="]').forEach(function (a) {
      if (out.length >= (limit || 12)) return;
      if (a.closest('header,footer,#KsAiMarketplace135,#KsAiMarketplace134,#KsAiMarketplace133,#KsAiMarketplace132,#KsAiCatalogEngine131,#KsLocalAiSearch130,#KsSmartConsult129,.ks-home-brands-block')) return;
      var href = a.getAttribute('href') || '', id = parseArticleId(href);
      if (!id || seen[id]) return;
      var card = a.closest('.card-product,.ks-final-product-card,.swiper-slide,article,li') || a.parentElement;
      var img = card ? q(card, 'img') : null;
      var src = img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '') : '';
      if (!src || /logo|brand|payment|placeholder|nofoto/i.test(src)) return;
      var title = txt(q(card, '.name-product a,.product-title a,h6 a,h5 a,.title a') || a);
      if (!title || title.length < 4 || /scopri|catalogo|categoria/i.test(title)) return;
      var priceMatch = txt(card).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
      seen[id] = 1;
      out.push({ id: id, url: href, title: title, image: src, image_fallback: src, price: priceMatch && priceMatch.length ? priceMatch[priceMatch.length - 1].replace('€','').trim() : '', brand: '', category: 'HOME', reason: 'Fallback locale dalla HOME.', badges: ['HOME'] });
    });
    return out;
  }
  function compareList() {
    try { return JSON.parse(localStorage.getItem(COMPARE_KEY) || '[]') || []; } catch (err) { return []; }
  }
  function saveCompare(list) {
    try { localStorage.setItem(COMPARE_KEY, JSON.stringify((list || []).slice(0, 12))); } catch (err) {}
    var count = document.getElementById('ksCompareCount');
    if (count) count.textContent = String((list || []).length);
  }
  function addCompare(item) {
    var list = compareList();
    if (!item || !item.id) return;
    if (!list.some(function (x) { return String(x.id) === String(item.id); })) list.unshift({ id: item.id, title: item.title, url: item.url, image: item.image || item.image_fallback || '', price: item.price || '' });
    saveCompare(list);
  }
  function marketplaceMarkup() {
    return '';
  }
  function itemBadges(item) {
    var badges = item.badges || [];
    if (!badges.length) {
      if (item.isOffer) badges.push('Promo');
      if (item.availability > 0) badges.push('Disp.');
      if (item.isRefurbished) badges.push('Ricond.');
    }
    return badges.slice(0, 3);
  }
  function renderMarketItems(items) {
    var grid = document.getElementById('ksMarket135Grid');
    if (!grid) return;
    if (!items || !items.length) {
      grid.innerHTML = '<div class="ks-suggest-empty">Nessun risultato trovato. Prova una ricerca piu generica.</div>';
      return;
    }
    grid.innerHTML = items.map(function (item, idx) {
      var img = item.image || item.image_fallback || item.imageUrl || '';
      var badges = itemBadges(item).map(function (b) { return '<span>' + esc(b) + '</span>'; }).join('');
      return '<article class="ks-market135-card" data-idx="' + idx + '"><div class="ks-market135-badges">' + badges + '</div>' +
        '<a class="ks-market135-media" href="' + esc(item.url || '#') + '">' + (img ? '<img src="' + esc(img) + '" alt="' + esc(item.title || '') + '">' : '') + '</a>' +
        '<div class="ks-market135-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></div>' +
        '<h5><a href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a></h5><div class="ks-market135-price">' + priceText(item.price) + '</div>' +
        '<div class="ks-market135-actions"><a class="ks-market135-btn" href="' + esc(item.url || '#') + '">Dettagli</a><button type="button" class="ks-market135-compare" data-idx="' + idx + '">Confronta</button></div><div class="ks-market135-reason">' + esc(item.reason || '') + '</div></article>';
    }).join('');
    all(grid, '.ks-market135-compare').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var idx = parseInt(btn.getAttribute('data-idx') || '-1', 10);
        if (items[idx]) { addCompare(items[idx]); btn.textContent = 'Aggiunto'; }
      });
    });
  }
  function renderFacets(data, runQuery) {
    var box = document.getElementById('ksMarket135Facets');
    if (!box) return;
    var chunks = [], facets = data && data.facets ? data.facets : {};
    ['brands', 'categories'].forEach(function (key) {
      (facets[key] || []).slice(0, 5).forEach(function (f) {
        chunks.push('<button type="button" data-q="' + esc(f.value || f.label || '') + '">' + esc(f.label || f.value || '') + ' <small>' + esc(f.count || '') + '</small></button>');
      });
    });
    if (data && data.catalogUrl) chunks.push('<a class="ks-market135-open" href="' + esc(data.catalogUrl) + '">Apri catalogo</a>');
    box.innerHTML = chunks.join('');
    all(box, 'button').forEach(function (b) {
      b.addEventListener('click', function () {
        var input = document.getElementById('ksMarket135Input');
        if (input) input.value = (input.value ? input.value + ' ' : '') + (b.getAttribute('data-q') || '');
        runQuery();
      });
    });
  }
  function initHomeMarketplace() {
    return;
  }

  function boot() {
    if (pathIsArticle()) updateRecent(detectArticleId());
    if (pathIsHome() && document.body) document.body.classList.add('ks-page-home');
    bindHeaderSearch();
    bindGlobalSubmitGuard();
    bindCatalogNavigation();
    applyRankingOnCatalog();
    initHomeMarketplace();
  }

  window.KSRecent = { read: readMergedRecent, push: updateRecent };
  window.KSMarketplaceSearch = { endpoint: SEARCH_ENDPOINT, refresh: function () { bindHeaderSearch(); initHomeMarketplace(); } };
  onReady(boot);
  window.setTimeout(function () { try { bindHeaderSearch(); bindCatalogNavigation(); initHomeMarketplace(); } catch (err) {} }, 700);
})();
