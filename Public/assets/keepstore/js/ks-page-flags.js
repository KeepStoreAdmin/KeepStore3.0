(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  var HOME_STYLE_ID = 'ks-home-reset-step2';
  var RUNTIME_STYLE_ID = 'ks-home-runtime-sections-step2';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'themeforest', 'onsus', 'themesflat', 'demo', 'template'];
  var SEARCH_TEXT_HINTS = ['cerca', 'search', 'ean', 'prodot', 'codic', 'articol', 'sku'];
  var SEARCH_ALL_HINTS = ['tutti', 'all', 'tutte', 'all categories', 'all departments', 'tutti i settori'];
  var HOME_PASS_TIMERS = [0, 160, 800, 1800, 3600, 7200];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function qs(root, selector) {
    try { return (root || document).querySelector(selector); } catch (err) { return null; }
  }

  function qsa(root, selector) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); } catch (err) { return []; }
  }

  function first(nodes, predicate) {
    for (var i = 0; i < nodes.length; i += 1) {
      if (predicate(nodes[i])) return nodes[i];
    }
    return null;
  }

  function esc(value) {
    return String(value || '').replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch] || ch;
    });
  }

  function textOf(node) {
    return String(node && node.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function normalizeText(value) {
    return String(value || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function normalizePath(path) {
    return String(path || '').toLowerCase().replace(/\/+/g, '/').replace(/\/default\.aspx$/i, '/').replace(/\/$/, '/');
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
    if (typeof window.matchMedia === 'function') return window.matchMedia('(min-width: 1200px)').matches;
    return (window.innerWidth || 0) >= 1200;
  }

  function addBodyClass(name) {
    if (document.body && name) document.body.classList.add(name);
  }

  function rect(node) {
    try { return node && node.getBoundingClientRect ? node.getBoundingClientRect() : null; } catch (err) { return null; }
  }

  function styleOf(node) {
    try { return node ? window.getComputedStyle(node) : null; } catch (err) { return null; }
  }

  function normalizeSrc(src) {
    return String(src || '').replace(/^https?:/i, '').replace(/[?#].*$/, '').trim();
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
      d.setTime(d.getTime() + (days * 86400000));
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = String(name || '') + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
  }

  function parseRecentList(raw) {
    return String(raw || '').split(',').map(function (v) { return parseInt(v, 10); }).filter(function (v) { return Number.isFinite(v) && v > 0; });
  }

  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }

  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
  }

  function mergeRecentLists(a, b) {
    var seen = new Set();
    var merged = [];
    [a || [], b || []].forEach(function (list) {
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
    var next = (list || []).filter(function (id) { return Number.isFinite(id) && id > 0; }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }

  function updateRecentList(id) {
    var next = [id].concat(readMergedRecent().filter(function (item) { return item !== id; })).slice(0, MAX_RECENT);
    persistRecentList(next);
    return next;
  }

  function getQueryParam(name) {
    try { return new URLSearchParams(window.location.search || '').get(name); } catch (err) { return null; }
  }

  function parseArticleIdFromHref(href) {
    var match = String(href || '').match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
  }

  function detectArticleId() {
    var direct = parseInt(getQueryParam('id'), 10);
    if (Number.isFinite(direct) && direct > 0) return direct;
    var canonical = qs(document, 'link[rel="canonical"]');
    var canonicalId = canonical ? parseArticleIdFromHref(canonical.getAttribute('href')) : 0;
    if (canonicalId > 0) return canonicalId;
    var og = qs(document, 'meta[property="og:url"]');
    var ogId = og ? parseArticleIdFromHref(og.getAttribute('content')) : 0;
    if (ogId > 0) return ogId;
    var bodyId = parseInt(document.body && (document.body.getAttribute('data-article-id') || document.body.getAttribute('data-id') || ''), 10);
    return Number.isFinite(bodyId) && bodyId > 0 ? bodyId : 0;
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (id > 0) updateRecentList(id);
  }

  function injectBaseCss() {
    if (!isHomePage() || qs(document, '#' + HOME_STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = HOME_STYLE_ID;
    style.textContent = [
      "body.ks-page-home{--ks-lane-left:0px;--ks-lane-right:0px;--ks-mask-top:154px;--ks-mask-buffer-left:22px;--ks-mask-buffer-right:38px;}",
      "body.ks-page-home::before,body.ks-page-home::after{content:'';position:fixed;top:var(--ks-mask-top);bottom:0;background:#fff;pointer-events:none;z-index:2147483000;}",
      "body.ks-page-home::before{left:0;width:calc(var(--ks-lane-left) + var(--ks-mask-buffer-left));}",
      "body.ks-page-home::after{right:0;width:calc(var(--ks-lane-right) + var(--ks-mask-buffer-right));}",
      "body.ks-page-home .auto-popup,body.ks-page-home .modal-newleter,body.ks-page-home [class*='modal-newleter']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home [data-ks-hidden='1'],body.ks-page-home [data-ks-rogue='1'],body.ks-page-home [data-ks-orphan='1'],body.ks-page-home [data-ks-hidden-section='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;max-height:0!important;overflow:hidden!important;}",
      "body.ks-page-home .ks-home-departments .ks-home-submenu-container[aria-hidden='true']{display:none!important;}",
      "body.ks-page-home .ks-home-force-compact .wrap-item-3{display:none!important;}",
      "@media (max-width:1199.98px){body.ks-page-home::before,body.ks-page-home::after{display:none!important;}}"
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function injectRuntimeCss() {
    if (!isHomePage() || qs(document, '#' + RUNTIME_STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = RUNTIME_STYLE_ID;
    style.textContent = [
      ".ks-runtime-section{position:relative;z-index:2;margin:28px 0;}",
      ".ks-runtime-section .container{position:relative;}",
      ".ks-runtime-title{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px;}",
      ".ks-runtime-title h5{margin:0;font-size:28px;line-height:1.2;font-weight:700;color:#333E48;}",
      ".ks-runtime-title h5 .ks-runtime-fire{display:inline-flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:999px;background:#ff4d4f;color:#fff;margin-right:12px;font-style:normal;font-size:18px;}",
      ".ks-runtime-deals-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:24px;}",
      ".ks-runtime-deal-card,.ks-runtime-grid-card,.ks-runtime-side-card,.ks-runtime-big-card{background:#fff;border:1px solid #eceff3;border-radius:18px;box-shadow:0 8px 24px rgba(17,24,39,.05);overflow:hidden;}",
      ".ks-runtime-deal-card{padding:18px;display:flex;flex-direction:column;gap:14px;min-height:100%;}",
      ".ks-runtime-image{position:relative;display:flex;align-items:center;justify-content:center;background:#f8fafc;border-radius:14px;overflow:hidden;}",
      ".ks-runtime-image>img{display:block;width:100%;height:auto;max-height:250px;object-fit:contain;}",
      ".ks-runtime-sale-badge{position:absolute;top:10px;left:10px;display:inline-flex;align-items:center;justify-content:center;width:54px;height:54px;border-radius:999px;background:#ff4d4f;color:#fff;font-weight:700;font-size:15px;z-index:2;}",
      ".ks-runtime-thumbs{display:flex;gap:8px;align-items:center;flex-wrap:wrap;}",
      ".ks-runtime-thumb{display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;border:1px solid #d6dde6;border-radius:10px;background:#fff;padding:4px;cursor:pointer;}",
      ".ks-runtime-thumb img{max-width:100%;max-height:100%;object-fit:contain;}",
      ".ks-runtime-thumb.is-active{border-color:#ff4d4f;box-shadow:0 0 0 2px rgba(255,77,79,.14) inset;}",
      ".ks-runtime-meta{display:flex;flex-direction:column;gap:8px;min-width:0;}",
      ".ks-runtime-brand{font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:.04em;}",
      ".ks-runtime-name{font-size:18px;line-height:1.45;font-weight:700;color:#1f2937;text-decoration:none;display:block;min-height:3em;}",
      ".ks-runtime-price-line{display:flex;align-items:flex-end;gap:10px;flex-wrap:wrap;}",
      ".ks-runtime-price{font-size:20px;line-height:1;font-weight:700;color:#ff4d4f;}",
      ".ks-runtime-old-price{font-size:14px;color:#6b7280;text-decoration:line-through;}",
      ".ks-runtime-save{display:inline-flex;align-items:center;justify-content:center;min-height:26px;padding:0 10px;border-radius:999px;background:#ff4d4f;color:#fff;font-size:12px;font-weight:700;}",
      ".ks-runtime-countdown{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;}",
      ".ks-runtime-count{display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:72px;border-radius:999px;background:#f3f4f6;color:#374151;padding:8px;}",
      ".ks-runtime-count strong{font-size:24px;line-height:1;font-weight:700;}",
      ".ks-runtime-count span{font-size:11px;margin-top:6px;text-transform:capitalize;}",
      ".ks-runtime-progress{height:10px;border-radius:999px;background:#f1d0d3;overflow:hidden;}",
      ".ks-runtime-progress-bar{height:100%;background:#ff4d4f;border-radius:999px;width:0%;}",
      ".ks-runtime-stock-line{display:flex;justify-content:space-between;gap:12px;font-size:13px;color:#4b5563;}",
      ".ks-runtime-tabs-head{display:flex;gap:20px;align-items:center;flex-wrap:wrap;margin-bottom:18px;}",
      ".ks-runtime-tab-btn{border:0;background:none;padding:0;font-size:18px;font-weight:700;color:#111827;cursor:pointer;}",
      ".ks-runtime-tab-btn.is-active{color:#ff4d4f;}",
      ".ks-runtime-panel{display:none;}",
      ".ks-runtime-panel.is-active{display:block;}",
      ".ks-runtime-tab-layout{display:grid;grid-template-columns:minmax(220px,1fr) minmax(0,1.75fr) minmax(220px,1fr);gap:24px;align-items:start;}",
      ".ks-runtime-side-col{display:grid;gap:18px;}",
      ".ks-runtime-side-card{display:grid;grid-template-columns:72px minmax(0,1fr);gap:14px;padding:14px;align-items:start;}",
      ".ks-runtime-side-card img{width:72px;height:72px;object-fit:contain;border-radius:10px;background:#fff;}",
      ".ks-runtime-side-card-title{display:block;font-size:14px;line-height:1.45;font-weight:700;color:#1f2937;text-decoration:none;}",
      ".ks-runtime-big-card{padding:18px;display:grid;grid-template-columns:minmax(0,1fr) 74px;gap:18px;align-items:start;}",
      ".ks-runtime-big-main{display:flex;align-items:center;justify-content:center;background:#f8fafc;border-radius:16px;min-height:380px;padding:18px;overflow:hidden;}",
      ".ks-runtime-big-main img{display:block;max-width:100%;max-height:340px;object-fit:contain;}",
      ".ks-runtime-big-thumbs{display:grid;gap:10px;}",
      ".ks-runtime-big-thumb{display:flex;align-items:center;justify-content:center;width:74px;height:74px;padding:8px;border:1px solid #d6dde6;border-radius:12px;background:#fff;cursor:pointer;}",
      ".ks-runtime-big-thumb.is-active{border-color:#111827;}",
      ".ks-runtime-big-thumb img{max-width:100%;max-height:100%;object-fit:contain;}",
      ".ks-runtime-big-meta{grid-column:1 / span 2;display:flex;justify-content:space-between;align-items:flex-end;gap:18px;flex-wrap:wrap;}",
      ".ks-runtime-actions{display:flex;gap:10px;align-items:center;flex-wrap:wrap;}",
      ".ks-runtime-action{display:inline-flex;align-items:center;justify-content:center;width:38px;height:38px;border-radius:999px;border:1px solid #d6dde6;background:#fff;color:#111827;text-decoration:none;font-size:18px;}",
      ".ks-runtime-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:22px;}",
      ".ks-runtime-grid-card{padding:16px;display:flex;flex-direction:column;gap:12px;min-height:100%;}",
      ".ks-runtime-grid-card .ks-runtime-image{min-height:170px;}",
      ".ks-runtime-grid-card .ks-runtime-name{font-size:15px;min-height:2.8em;}",
      ".ks-runtime-two-col{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:28px;}",
      ".ks-runtime-col-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;}",
      ".ks-runtime-col-title{margin:0 0 16px;font-size:26px;line-height:1.2;font-weight:700;color:#111827;}",
      ".ks-runtime-recent-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:22px;}",
      "@media (max-width:1199.98px){.ks-runtime-deals-grid{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-runtime-tab-layout{grid-template-columns:1fr;}.ks-runtime-side-col{grid-template-columns:1fr 1fr;}.ks-runtime-big-card{grid-template-columns:1fr;}.ks-runtime-big-meta{grid-column:auto;}.ks-runtime-grid,.ks-runtime-recent-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-runtime-two-col{grid-template-columns:1fr;}.ks-runtime-col-grid{grid-template-columns:repeat(2,minmax(0,1fr));}}",
      "@media (max-width:767.98px){.ks-runtime-deals-grid,.ks-runtime-grid,.ks-runtime-recent-grid,.ks-runtime-col-grid,.ks-runtime-side-col{grid-template-columns:1fr 1fr;gap:14px;}.ks-runtime-title h5,.ks-runtime-col-title{font-size:22px;}.ks-runtime-name{font-size:15px;}.ks-runtime-count strong{font-size:18px;}.ks-runtime-grid-card .ks-runtime-image{min-height:130px;}}",
      "@media (max-width:575.98px){.ks-runtime-deals-grid,.ks-runtime-grid,.ks-runtime-recent-grid,.ks-runtime-col-grid,.ks-runtime-side-col{grid-template-columns:1fr;}.ks-runtime-side-card{grid-template-columns:60px minmax(0,1fr);}.ks-runtime-side-card img{width:60px;height:60px;}}"
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function setBodyFlags() {
    if (isHomePage()) addBodyClass('ks-page-home');
    if (isArticlePage()) addBodyClass('ks-page-article');
  }

  function disablePopupStorage() {
    try {
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
    } catch (err) {}
  }

  function suppressNewsletterPopup() {
    if (!isHomePage()) return;
    qsa(document, '.auto-popup,.modal-newleter,[class*="modal-newleter"],.modal-backdrop,.offcanvas-backdrop').forEach(function (node) {
      if (/backdrop/i.test(node.className || '')) {
        if (node.parentNode) node.parentNode.removeChild(node);
      } else {
        node.setAttribute('data-ks-hidden', '1');
      }
    });
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function inProtectedArea(node) {
    return !!(node && node.closest && node.closest([
      'header','footer','.tf-header','.tf-footer','.footer','.modal','.offcanvas',
      '.ks-home-departments','.ks-home-hero-shell','.s-banner-wrapper',
      '.wrap-item-1','.wrap-item-2','.wrap-item-3','.ks-runtime-section'
    ].join(',')));
  }

  function blockedToken(text) {
    var n = normalizeText(text);
    return BLOCKED_TOKENS.some(function (t) { return n.indexOf(normalizeText(t)) !== -1; });
  }

  function markRogue(node) {
    if (!node || inProtectedArea(node)) return;
    node.setAttribute('data-ks-rogue', '1');
    var parent = node.parentElement;
    var hops = 0;
    while (parent && hops < 4 && !inProtectedArea(parent)) {
      var r = rect(parent);
      if (!r || r.width > 320 || r.height > 1600) break;
      parent.setAttribute('data-ks-rogue', '1');
      node = parent;
      parent = parent.parentElement;
      hops += 1;
    }
  }

  function hasUsefulMedia(node) {
    if (!node) return false;
    if (qs(node, 'img,video,canvas,iframe,object,embed')) return true;
    var st = styleOf(node);
    return !!(st && st.backgroundImage && st.backgroundImage !== 'none');
  }

  function looksLikePriceText(text) {
    var t = normalizeText(text);
    if (!t) return false;
    return /(^| )\d+[\.,]?\d* ?(euro|eur|€)($| )/.test(t) || /^€ ?\d+/.test(t);
  }

  function computeLaneBounds() {
    if (!isHomePage() || !document.body) return;
    var laneNode = qs(document, '.ks-home-hero-shell') || qs(document, '.s-banner-wrapper') || qs(document, '.tf-sp-5 .container') || qs(document, '.container');
    var laneRect = rect(laneNode);
    if (!laneRect) return;
    var left = Math.max(0, Math.floor(laneRect.left) - 18);
    var right = Math.max(0, Math.floor(window.innerWidth - laneRect.right) - 26);
    document.body.style.setProperty('--ks-lane-left', left + 'px');
    document.body.style.setProperty('--ks-lane-right', right + 'px');
    var header = qs(document, 'header') || qs(document, '.tf-header') || qs(document, '.header');
    var headerRect = rect(header);
    document.body.style.setProperty('--ks-mask-top', ((headerRect && headerRect.bottom) ? Math.ceil(headerRect.bottom) : 150) + 'px');
  }

  function hideRogueRails() {
    if (!isHomePage() || !document.body) return;

    var imagesBySrc = Object.create(null);
    qsa(document, 'img').forEach(function (img) {
      if (inProtectedArea(img)) return;
      var r = rect(img);
      if (!r) return;
      var nearEdge = (r.left < 150 || r.right > window.innerWidth - 150);
      if (!nearEdge) return;
      if (r.width > 260 || r.height > 380) return;
      var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
      if (!src) return;
      if (!imagesBySrc[src]) imagesBySrc[src] = [];
      imagesBySrc[src].push(img);
    });

    Object.keys(imagesBySrc).forEach(function (src) {
      if (imagesBySrc[src].length < 2) return;
      imagesBySrc[src].forEach(function (img) {
        markRogue(img.closest('a,div,li,span,section,aside') || img);
      });
    });

    qsa(document.body, 'img,div,span,p,a,section,aside').forEach(function (node) {
      if (!node || inProtectedArea(node)) return;
      var r = rect(node);
      if (!r || r.width < 10 || r.height < 10) return;
      var edge = r.left < 160 || r.right > window.innerWidth - 160;
      var narrow = r.width <= 260 && r.height >= 40;
      var vertical = r.height > (r.width * 2.1) && r.width < 300;
      var st = styleOf(node);
      var pos = st ? st.position : '';
      var info = [node.id || '', node.className || '', textOf(node).slice(0, 240), st && st.backgroundImage || ''].join(' ');
      var tinyMediaRail = edge && hasUsefulMedia(node) && r.width <= 220 && r.height <= 340;
      var peripheralBlock = edge && narrow && (pos === 'fixed' || pos === 'sticky' || pos === 'absolute' || pos === 'relative');
      if (peripheralBlock || (edge && vertical) || tinyMediaRail || blockedToken(info)) {
        markRogue(node.closest('a,div,li,span,section,aside') || node);
      }
    });

    qsa(document.body, '*').forEach(function (node) {
      if (!node || inProtectedArea(node)) return;
      var txt = normalizeText(textOf(node));
      if (!txt) return;
      var r = rect(node);
      if (!r) return;
      if ((txt === 'franchising' || txt === 'welcome' || blockedToken(txt)) && (r.left < 260 || r.right > window.innerWidth - 260)) {
        markRogue(node);
      }
      if (!hasUsefulMedia(node) && looksLikePriceText(txt) && (r.left < 220 || r.right > window.innerWidth - 220) && r.width < 220 && r.height < 80) {
        node.setAttribute('data-ks-orphan', '1');
      }
    });
  }

  function ensureCompactHero() {
    if (!isHomePage() || !isDesktop()) return;
    var shell = qs(document, '.ks-home-hero-shell') || qs(document, '.s-banner-wrapper');
    var side = shell && qs(shell, '.wrap-item-3');
    if (!shell || !side) return;
    var validCards = qsa(side, 'a,.cls-category,.ks-side-runtime-banner,div').filter(function (node) {
      if (node.getAttribute && node.getAttribute('data-ks-rogue') === '1') return false;
      var r = rect(node);
      return r && r.width >= 180 && r.height >= 120 && r.width < 600 && r.height < 700 && (hasUsefulMedia(node) || qs(node, 'img,video,canvas,iframe,object,embed'));
    });
    if (validCards.length < 2) {
      side.style.setProperty('display', 'none', 'important');
      shell.classList.add('ks-home-force-compact');
    }
  }

  function parseFilterValue(raw) {
    var value = String(raw || '').trim();
    if (!value) return null;
    if (SEARCH_ALL_HINTS.some(function (hint) { return normalizeText(value) === normalizeText(hint); })) return null;
    var m = value.match(/(?:^|[?&])(st|ct|tp|gr|sg|mr|pid)=([0-9]+)/i);
    if (m) return { key: m[1].toLowerCase(), value: m[2] };
    m = value.match(/^(st|ct|tp|gr|sg|mr|pid)[:=]([0-9]+)$/i);
    if (m) return { key: m[1].toLowerCase(), value: m[2] };
    if (/^\d+$/.test(value)) return { key: 'st', value: value };
    return null;
  }

  function findSearchRoots() {
    var roots = [];
    qsa(document, 'form,.form-search-product,.search-box,.search-form,.search-header,.header-search,.box-search').forEach(function (node) {
      var input = qs(node, 'input[type="search"],input[type="text"]');
      if (!input) return;
      var txt = normalizeText(input.getAttribute('placeholder') || '') + ' ' + normalizeText(textOf(node));
      if (SEARCH_TEXT_HINTS.some(function (hint) { return txt.indexOf(normalizeText(hint)) !== -1; })) roots.push(node);
    });
    return roots.filter(function (node, idx) { return roots.indexOf(node) === idx; });
  }

  function itemPriceHtml(item) {
    return item && item.price ? '<span class="ks-sg-price" style="white-space:nowrap;font-size:12px;font-weight:700;color:#ff4d4f">' + esc(item.price) + '</span>' : '';
  }

  function bindSearch() {
    findSearchRoots().forEach(function (root) {
      if (root.getAttribute('data-ks-search-bound') === '1') return;
      root.setAttribute('data-ks-search-bound', '1');
      var input = qs(root, 'input[type="search"],input[type="text"]');
      if (!input) return;
      var submitBtn = qs(root, 'button[type="submit"],.btn-submit-form,.icon-search,.search-submit,.btn-search');
      var select = qs(root, 'select') || qs(root, '.select-options .link.active') || qs(root, '.select-options .link[rel]');
      var box = document.createElement('div');
      box.className = 'ks-search-suggest';
      box.style.cssText = 'position:absolute;left:0;right:0;top:100%;z-index:9999;background:#fff;border:1px solid #e5e7eb;border-radius:12px;box-shadow:0 12px 36px rgba(0,0,0,.12);display:none;max-height:420px;overflow:auto;margin-top:8px';
      root.style.position = root.style.position || 'relative';
      root.appendChild(box);

      var state = { timer: 0, items: [], active: -1, lastQuery: '' };

      function currentFilter() {
        var raw = '';
        if (select && select.tagName === 'SELECT') raw = select.value || ((select.options[select.selectedIndex] || {}).text) || '';
        else if (select) raw = select.getAttribute('rel') || textOf(select);
        return parseFilterValue(raw);
      }

      function render(items, isRecent) {
        state.items = items || [];
        state.active = -1;
        if (!items || !items.length) { box.style.display = 'none'; box.innerHTML = ''; return; }
        box.innerHTML = (isRecent ? '<div class="ks-sg-head" style="padding:10px 12px;font-size:12px;font-weight:700;text-transform:uppercase;color:#6b7280">Recenti</div>' : '') + items.map(function (item, idx) {
          return '<a class="ks-sg-item" href="' + esc(item.url || '#') + '" data-index="' + idx + '" style="display:flex;gap:12px;align-items:center;padding:10px 12px;text-decoration:none;color:#111827;border-top:' + (idx ? '1px solid #f0f0f0' : '0') + '">' +
            '<span style="width:48px;height:48px;border:1px solid #eee;border-radius:10px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#fff"><img src="' + esc(item.image || item.imageFallback || '') + '" alt="" style="max-width:100%;max-height:100%"></span>' +
            '<span style="min-width:0;flex:1 1 auto"><span style="display:block;font-size:13px;font-weight:600;line-height:1.35">' + esc(item.title || '') + '</span><span style="display:block;font-size:12px;color:#6b7280">' + esc((item.brand || '') + ((item.brand && item.category) ? ' · ' : '') + (item.category || '')) + '</span></span>' +
            itemPriceHtml(item) + '</a>';
        }).join('');
        box.style.display = 'block';
        qsa(box, '.ks-sg-item').forEach(function (a) {
          a.addEventListener('mouseenter', function () { setActive(parseInt(a.getAttribute('data-index'), 10)); });
        });
      }

      function setActive(index) {
        state.active = index;
        qsa(box, '.ks-sg-item').forEach(function (node, idx) {
          node.style.background = idx === index ? '#f7f7f7' : '#fff';
        });
      }

      function structuredResultsUrl(q) {
        var url = new URL(window.location.origin + '/articoli.aspx');
        if (q) url.searchParams.set('q', q);
        var filter = currentFilter();
        if (filter) url.searchParams.set(filter.key, filter.value);
        return url.pathname + url.search;
      }

      function fetchSuggest(query, submitting) {
        query = String(query || '').trim();
        state.lastQuery = query;
        if (query.length < 2) {
          var recent = readMergedRecent();
          if (!recent.length) { render([], true); return; }
          var urlRecent = SEARCH_ENDPOINT + '?recent=' + encodeURIComponent(recent.join(',')) + '&limit=8';
          var filter = currentFilter();
          if (filter) urlRecent += '&' + encodeURIComponent(filter.key) + '=' + encodeURIComponent(filter.value);
          fetch(urlRecent, { credentials: 'same-origin' }).then(function (r) { return r.json(); }).then(function (data) {
            render((data && data.suggestions) || [], true);
          }).catch(function () { render([], true); });
          return;
        }
        var url = SEARCH_ENDPOINT + '?q=' + encodeURIComponent(query) + '&limit=8';
        var filter2 = currentFilter();
        if (filter2) url += '&' + encodeURIComponent(filter2.key) + '=' + encodeURIComponent(filter2.value);
        fetch(url, { credentials: 'same-origin' }).then(function (r) { return r.json(); }).then(function (data) {
          if (query !== state.lastQuery) return;
          var suggestions = (data && data.suggestions) || [];
          if (submitting) {
            if (data && data.strong && data.strong.canRedirect && data.strong.redirectUrl) window.location.href = data.strong.redirectUrl;
            else window.location.href = structuredResultsUrl(query);
            return;
          }
          render(suggestions, false);
        }).catch(function () {
          if (submitting) window.location.href = structuredResultsUrl(query);
          else render([], false);
        });
      }

      function submitSearch() {
        var q = String(input.value || '').trim();
        if (!q) {
          window.location.href = structuredResultsUrl('');
          return;
        }
        fetchSuggest(q, true);
      }

      input.addEventListener('input', function () {
        clearTimeout(state.timer);
        state.timer = setTimeout(function () { fetchSuggest(input.value, false); }, 220);
      });
      input.addEventListener('focus', function () { fetchSuggest(input.value, false); });
      input.addEventListener('keydown', function (e) {
        if (box.style.display !== 'block' && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) fetchSuggest(input.value, false);
        if (e.key === 'ArrowDown') { e.preventDefault(); setActive(Math.min(state.items.length - 1, state.active + 1)); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(Math.max(0, state.active - 1)); }
        else if (e.key === 'Escape') { box.style.display = 'none'; }
        else if (e.key === 'Enter') {
          e.preventDefault();
          if (state.active >= 0 && state.items[state.active] && state.items[state.active].url) window.location.href = state.items[state.active].url;
          else submitSearch();
        }
      });
      if (submitBtn) submitBtn.addEventListener('click', function (e) { e.preventDefault(); submitSearch(); });
      var form = root.tagName === 'FORM' ? root : root.closest('form');
      if (form) form.addEventListener('submit', function (e) { e.preventDefault(); submitSearch(); });
      document.addEventListener('click', function (e) { if (!root.contains(e.target)) box.style.display = 'none'; });
    });
  }

  var feedCache = Object.create(null);
  function fetchJson(mode, extra) {
    var params = new URLSearchParams();
    params.set('mode', mode);
    params.set('_', Date.now().toString());
    Object.keys(extra || {}).forEach(function (key) {
      if (extra[key] == null || extra[key] === '') return;
      params.set(key, String(extra[key]));
    });
    var url = FEED_ENDPOINT + '?' + params.toString();
    return fetch(url, { credentials: 'same-origin' }).then(function (r) { return r.json(); });
  }

  function cachedFeed(mode, extra) {
    var key = mode + '::' + JSON.stringify(extra || {});
    if (!feedCache[key]) feedCache[key] = fetchJson(mode, extra);
    return feedCache[key];
  }

  function formatPrice(value) {
    return value ? String(value) + ' €' : '';
  }

  function buildActionButtons(url) {
    return '<div class="ks-runtime-actions">' +
      '<a class="ks-runtime-action" href="' + esc(url) + '" title="Aggiungi al carrello">🛒</a>' +
      '<a class="ks-runtime-action" href="' + esc(url) + '" title="Wishlist">♡</a>' +
      '<a class="ks-runtime-action" href="' + esc(url) + '" title="Vedi prodotto">👁</a>' +
      '<a class="ks-runtime-action" href="' + esc(url) + '" title="Confronta">⇄</a>' +
      '</div>';
  }

  function buildThumbButtons(images, activeClass) {
    return (images || []).slice(0, 5).map(function (img, idx) {
      return '<button type="button" class="ks-runtime-thumb' + (idx === 0 ? ' ' + (activeClass || 'is-active') : '') + '" data-img="' + esc(img) + '"><img src="' + esc(img) + '" alt=""></button>';
    }).join('');
  }

  function buildDealCard(item) {
    var images = (item.images || []).slice(0, 5);
    var main = item.image || images[0] || '';
    var available = Math.max(0, parseInt(item.available, 10) || 0);
    var sold = Math.max(0, parseInt(item.sold, 10) || 0);
    var total = sold + available;
    var pct = total > 0 ? Math.max(0, Math.min(100, Math.round((sold / total) * 100))) : 0;
    return '<article class="ks-runtime-deal-card" data-deal-end="' + esc(item.dealEnds || '') + '">' +
      '<div class="ks-runtime-image">' +
      (item.salePercent ? '<span class="ks-runtime-sale-badge">-' + esc(item.salePercent) + '%</span>' : '') +
      '<img src="' + esc(main) + '" data-main="1" alt="' + esc(item.title || '') + '">' +
      '</div>' +
      '<div class="ks-runtime-thumbs">' + buildThumbButtons(images, 'is-active') + '</div>' +
      '<div class="ks-runtime-meta">' +
      '<div class="ks-runtime-brand">' + esc(item.brand || '') + '</div>' +
      '<a class="ks-runtime-name" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' +
      '<div class="ks-runtime-price-line"><span class="ks-runtime-price">' + esc(formatPrice(item.price)) + '</span>' + (item.oldPrice ? '<span class="ks-runtime-old-price">' + esc(formatPrice(item.oldPrice)) + '</span>' : '') + '</div>' +
      '</div>' +
      '<div class="ks-runtime-countdown">' +
      '<div class="ks-runtime-count"><strong data-ks-dd="1">00</strong><span>Giorni</span></div>' +
      '<div class="ks-runtime-count"><strong data-ks-hh="1">00</strong><span>Ore</span></div>' +
      '<div class="ks-runtime-count"><strong data-ks-mm="1">00</strong><span>Min</span></div>' +
      '<div class="ks-runtime-count"><strong data-ks-ss="1">00</strong><span>Sec</span></div>' +
      '</div>' +
      '<div class="ks-runtime-progress"><div class="ks-runtime-progress-bar" style="width:' + pct + '%"></div></div>' +
      '<div class="ks-runtime-stock-line"><span>Venduti: ' + sold + '</span><span>Disponibili: ' + available + '</span></div>' +
      '</article>';
  }

  function buildGridCard(item) {
    return '<article class="ks-runtime-grid-card">' +
      '<a class="ks-runtime-image" href="' + esc(item.url || '#') + '"><img src="' + esc(item.image || item.preview || '') + '" alt="' + esc(item.title || '') + '"></a>' +
      '<div class="ks-runtime-meta">' +
      '<div class="ks-runtime-brand">' + esc(item.brand || item.category || '') + '</div>' +
      '<a class="ks-runtime-name" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' +
      '<div class="ks-runtime-price-line"><span class="ks-runtime-price">' + esc(formatPrice(item.price)) + '</span>' + (item.oldPrice ? '<span class="ks-runtime-old-price">' + esc(formatPrice(item.oldPrice)) + '</span>' : '') + '</div>' +
      '</div>' +
      '</article>';
  }

  function buildSideCard(item) {
    return '<article class="ks-runtime-side-card">' +
      '<a href="' + esc(item.url || '#') + '"><img src="' + esc(item.image || item.preview || '') + '" alt="' + esc(item.title || '') + '"></a>' +
      '<div class="ks-runtime-meta">' +
      '<div class="ks-runtime-brand">' + esc(item.brand || item.category || '') + '</div>' +
      '<a class="ks-runtime-side-card-title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' +
      '<div class="ks-runtime-price-line"><span class="ks-runtime-price">' + esc(formatPrice(item.price)) + '</span>' + (item.oldPrice ? '<span class="ks-runtime-old-price">' + esc(formatPrice(item.oldPrice)) + '</span>' : '') + '</div>' +
      '</div>' +
      '</article>';
  }

  function buildBigCard(item) {
    var images = (item.images || []).slice(0, 4);
    var main = item.image || images[0] || '';
    return '<article class="ks-runtime-big-card">' +
      '<div class="ks-runtime-big-main"><img src="' + esc(main) + '" data-main="1" alt="' + esc(item.title || '') + '"></div>' +
      '<div class="ks-runtime-big-thumbs">' + images.map(function (img, idx) { return '<button type="button" class="ks-runtime-big-thumb' + (idx === 0 ? ' is-active' : '') + '" data-img="' + esc(img) + '"><img src="' + esc(img) + '" alt=""></button>'; }).join('') + '</div>' +
      '<div class="ks-runtime-big-meta">' +
      '<div class="ks-runtime-meta"><div class="ks-runtime-brand">' + esc(item.brand || item.category || '') + '</div><a class="ks-runtime-name" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a><div class="ks-runtime-price-line"><span class="ks-runtime-price">' + esc(formatPrice(item.price)) + '</span>' + (item.oldPrice ? '<span class="ks-runtime-old-price">' + esc(formatPrice(item.oldPrice)) + '</span>' : '') + '</div></div>' +
      buildActionButtons(item.url || '#') +
      '</div>' +
      '</article>';
  }

  function bindThumbs(root) {
    qsa(root, '.ks-runtime-thumb,.ks-runtime-big-thumb').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var card = btn.closest('.ks-runtime-deal-card,.ks-runtime-big-card');
        if (!card) return;
        qsa(card, '.ks-runtime-thumb,.ks-runtime-big-thumb').forEach(function (node) { node.classList.remove('is-active'); });
        btn.classList.add('is-active');
        var main = qs(card, 'img[data-main="1"]');
        if (main) main.src = btn.getAttribute('data-img') || main.src;
      });
    });
  }

  function bindCountdowns(root) {
    qsa(root, '.ks-runtime-deal-card[data-deal-end]').forEach(function (card) {
      var end = card.getAttribute('data-deal-end') || '';
      if (!end) return;
      function tick() {
        var target = new Date(end + 'T23:59:59');
        if (String(target) === 'Invalid Date') target = new Date(end);
        var diff = Math.max(0, target.getTime() - Date.now());
        var totalSec = Math.floor(diff / 1000);
        var days = Math.floor(totalSec / 86400);
        var hours = Math.floor((totalSec % 86400) / 3600);
        var mins = Math.floor((totalSec % 3600) / 60);
        var secs = totalSec % 60;
        var dd = qs(card, '[data-ks-dd="1"]');
        var hh = qs(card, '[data-ks-hh="1"]');
        var mm = qs(card, '[data-ks-mm="1"]');
        var ss = qs(card, '[data-ks-ss="1"]');
        if (dd) dd.textContent = String(days).padStart(2, '0');
        if (hh) hh.textContent = String(hours).padStart(2, '0');
        if (mm) mm.textContent = String(mins).padStart(2, '0');
        if (ss) ss.textContent = String(secs).padStart(2, '0');
      }
      tick();
      setInterval(tick, 1000);
    });
  }

  function hideSection(section) {
    if (!section) return;
    section.setAttribute('data-ks-hidden-section', '1');
    section.style.setProperty('display', 'none', 'important');
  }

  function findSectionByHeading(check) {
    var headings = qsa(document, 'h1,h2,h3,h4,h5,h6');
    var heading = first(headings, function (node) { return check(normalizeText(textOf(node))); });
    return heading ? (heading.closest('section, .tf-sp-2, .themesFlat, .container') || heading.parentNode) : null;
  }

  function findTabbedHost() {
    return first(qsa(document, 'section,.tf-sp-2,.container,div'), function (node) {
      if (node.getAttribute && node.getAttribute('data-ks-runtime-section') === '1') return false;
      var labels = qsa(node, 'a,button,h1,h2,h3,h4,h5,h6').map(function (n) { return normalizeText(textOf(n)); });
      return labels.some(function (t) { return t === 'offerte'; }) && labels.some(function (t) { return t.indexOf('evidenza') !== -1; }) && labels.some(function (t) { return t.indexOf('nuovi arrivi') !== -1; });
    });
  }

  function findBestSellerHost() {
    return findSectionByHeading(function (t) { return t.indexOf('best seller') !== -1; });
  }

  function findLowerHost() {
    return first(qsa(document, 'section,.tf-sp-2,.container,div'), function (node) {
      if (node.getAttribute && node.getAttribute('data-ks-runtime-section') === '1') return false;
      var labels = qsa(node, 'a,button,h1,h2,h3,h4,h5,h6').map(function (n) { return normalizeText(textOf(n)); });
      return labels.some(function (t) { return t.indexOf('in evidenza') !== -1; }) && labels.some(function (t) { return t.indexOf('in offerta') !== -1; });
    });
  }

  function findDealHost() {
    return findSectionByHeading(function (t) { return t.indexOf('occasione imperdibile') !== -1 || t.indexOf('deal of the day') !== -1; });
  }

  function findRecentHost() {
    return findSectionByHeading(function (t) { return t.indexOf('scelti da te') !== -1 || t.indexOf('scelti per te') !== -1 || t.indexOf('chosen for you') !== -1; });
  }

  function insertAfter(newNode, referenceNode) {
    if (!referenceNode || !referenceNode.parentNode) return;
    referenceNode.parentNode.insertBefore(newNode, referenceNode.nextSibling);
  }

  function shuffle(items) {
    var arr = (items || []).slice();
    for (var i = arr.length - 1; i > 0; i -= 1) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
    }
    return arr;
  }

  function renderDeals() {
    if (!isHomePage() || qs(document, '.ks-runtime-deals-section')) return;
    var host = findDealHost();
    if (!host || !host.parentNode) return;
    cachedFeed('deals', { limit: 8 }).then(function (data) {
      var items = shuffle((data && data.deals) || []).slice(0, 4);
      if (items.length < 2) return;
      var wrapper = document.createElement('section');
      wrapper.className = 'ks-runtime-section ks-runtime-deals-section';
      wrapper.setAttribute('data-ks-runtime-section', '1');
      wrapper.innerHTML = '<div class="container"><div class="ks-runtime-title"><h5><span class="ks-runtime-fire">🔥</span>Occasione Imperdibile</h5></div><div class="ks-runtime-deals-grid">' + items.map(buildDealCard).join('') + '</div></div>';
      insertAfter(wrapper, host);
      hideSection(host);
      bindThumbs(wrapper);
      bindCountdowns(wrapper);
    }).catch(function () {});
  }

  function renderTabbedSection() {
    if (!isHomePage() || qs(document, '.ks-runtime-tabbed-section')) return;
    var host = findTabbedHost();
    if (!host || !host.parentNode) return;
    cachedFeed('sections').then(function (data) {
      var sections = (data && data.sections) || {};
      var mapping = [
        { key: 'offerte', label: 'Offerte' },
        { key: 'evidenza', label: 'In Evidenza' },
        { key: 'nuovi', label: 'Nuovi Arrivi' }
      ];
      var usable = mapping.filter(function (m) { return (sections[m.key] || []).length >= 4; });
      if (!usable.length) return;
      var wrapper = document.createElement('section');
      wrapper.className = 'ks-runtime-section ks-runtime-tabbed-section';
      wrapper.setAttribute('data-ks-runtime-section', '1');
      wrapper.innerHTML = '<div class="container"><div class="ks-runtime-tabs-head">' + usable.map(function (m, idx) { return '<button type="button" class="ks-runtime-tab-btn' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '">' + esc(m.label) + '</button>'; }).join('') + '</div><div class="ks-runtime-tabs-panels">' + usable.map(function (m, idx) {
        var pool = shuffle((sections[m.key] || []).slice()).slice(0, 7);
        var big = pool[0] || null;
        var left = pool.slice(1, 4);
        var right = pool.slice(4, 7);
        if (!big) return '';
        return '<div class="ks-runtime-panel' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '"><div class="ks-runtime-tab-layout"><div class="ks-runtime-side-col">' + left.map(buildSideCard).join('') + '</div><div class="ks-runtime-big-wrap">' + buildBigCard(big) + '</div><div class="ks-runtime-side-col">' + right.map(buildSideCard).join('') + '</div></div></div>';
      }).join('') + '</div></div>';
      insertAfter(wrapper, host);
      hideSection(host);
      qsa(wrapper, '.ks-runtime-tab-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
          var panel = btn.getAttribute('data-panel') || '';
          qsa(wrapper, '.ks-runtime-tab-btn').forEach(function (node) { node.classList.toggle('is-active', node === btn); });
          qsa(wrapper, '.ks-runtime-panel').forEach(function (node) { node.classList.toggle('is-active', node.getAttribute('data-panel') === panel); });
        });
      });
      bindThumbs(wrapper);
    }).catch(function () {});
  }

  function renderBestSeller() {
    if (!isHomePage() || qs(document, '.ks-runtime-best-section')) return;
    var host = findBestSellerHost();
    if (!host || !host.parentNode) return;
    cachedFeed('sections').then(function (data) {
      var items = shuffle((((data || {}).sections || {}).best || []).slice()).slice(0, 10);
      if (items.length < 4) return;
      var wrapper = document.createElement('section');
      wrapper.className = 'ks-runtime-section ks-runtime-best-section';
      wrapper.setAttribute('data-ks-runtime-section', '1');
      wrapper.innerHTML = '<div class="container"><div class="ks-runtime-title"><h5>Best Seller</h5></div><div class="ks-runtime-grid">' + items.map(buildGridCard).join('') + '</div></div>';
      insertAfter(wrapper, host);
      hideSection(host);
    }).catch(function () {});
  }

  function renderLowerSections() {
    if (!isHomePage() || qs(document, '.ks-runtime-lower-section')) return;
    var host = findLowerHost();
    if (!host || !host.parentNode) return;
    cachedFeed('sections').then(function (data) {
      var sections = (data && data.sections) || {};
      var leftItems = shuffle((sections.evidenza || []).slice()).slice(0, 6);
      var rightItems = shuffle((sections.offerte || []).slice()).slice(0, 6);
      if (leftItems.length < 2 && rightItems.length < 2) return;
      var wrapper = document.createElement('section');
      wrapper.className = 'ks-runtime-section ks-runtime-lower-section';
      wrapper.setAttribute('data-ks-runtime-section', '1');
      wrapper.innerHTML = '<div class="container"><div class="ks-runtime-two-col"><div><h5 class="ks-runtime-col-title">In Evidenza</h5><div class="ks-runtime-col-grid">' + leftItems.map(buildGridCard).join('') + '</div></div><div><h5 class="ks-runtime-col-title">In Offerta</h5><div class="ks-runtime-col-grid">' + rightItems.map(buildGridCard).join('') + '</div></div></div></div>';
      insertAfter(wrapper, host);
      hideSection(host);
    }).catch(function () {});
  }

  function renderRecentlyViewed() {
    if (!isHomePage() || qs(document, '.ks-runtime-recent-section')) return;
    var host = findRecentHost();
    var ids = readMergedRecent().slice(0, 10);
    if (!host || !host.parentNode || ids.length < 2) return;
    cachedFeed('products', { ids: ids.join(',') }).then(function (data) {
      var items = ((data && data.products) || []).slice(0, 10);
      if (items.length < 2) return;
      var wrapper = document.createElement('section');
      wrapper.className = 'ks-runtime-section ks-runtime-recent-section';
      wrapper.setAttribute('data-ks-runtime-section', '1');
      wrapper.innerHTML = '<div class="container"><div class="ks-runtime-title"><h5>Scelti per te</h5></div><div class="ks-runtime-recent-grid">' + items.map(buildGridCard).join('') + '</div></div>';
      insertAfter(wrapper, host);
      hideSection(host);
    }).catch(function () {});
  }

  function renderRuntimeHomeBlocks() {
    if (!isHomePage()) return;
    injectRuntimeCss();
    renderDeals();
    renderTabbedSection();
    renderBestSeller();
    renderLowerSections();
    renderRecentlyViewed();
  }

  function runStableHomePass() {
    if (!isHomePage()) return;
    injectBaseCss();
    disablePopupStorage();
    suppressNewsletterPopup();
    computeLaneBounds();
    hideRogueRails();
    ensureCompactHero();
    hideRogueRails();
  }

  function armStableHomePass() {
    if (!isHomePage()) return;
    HOME_PASS_TIMERS.forEach(function (delay) { setTimeout(runStableHomePass, delay); });
    window.addEventListener('resize', runStableHomePass);
    window.addEventListener('load', runStableHomePass, { once: true });
  }

  window.KSRecent = { read: readMergedRecent, add: updateRecentList };

  onReady(function () {
    if (!document.body) return;
    setBodyFlags();
    if (isArticlePage()) trackArticleRecent();
    bindSearch();
    runStableHomePass();
    armStableHomePass();
    renderRuntimeHomeBlocks();
    window.addEventListener('load', renderRuntimeHomeBlocks, { once: true });
  });
})();
