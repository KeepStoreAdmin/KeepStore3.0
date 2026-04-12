(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var HOME_STYLE_ID = 'ks-home-reset-step1';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'themeforest', 'onsus', 'themesflat', 'demo template'];
  var SEARCH_TEXT_HINTS = ['cerca', 'search', 'ean', 'prodot', 'codic', 'articol', 'sku'];
  var SEARCH_ALL_HINTS = ['tutti', 'all', 'tutte', 'all categories', 'all departments', 'tutti i settori'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
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

  function qsa(root, selector) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); } catch (err) { return []; }
  }

  function qs(root, selector) {
    try { return (root || document).querySelector(selector); } catch (err) { return null; }
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
    document.cookie = name + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
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
    var params = new URLSearchParams(window.location.search || '');
    return params.get(name);
  }

  function parseArticleIdFromHref(href) {
    var match = String(href || '').match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
  }

  function detectArticleId() {
    var direct = parseInt(getQueryParam('id'), 10);
    if (Number.isFinite(direct) && direct > 0) return direct;
    var canonical = qs(document, 'link[rel="canonical"]');
    var c = canonical ? parseArticleIdFromHref(canonical.getAttribute('href')) : 0;
    if (c > 0) return c;
    var og = qs(document, 'meta[property="og:url"]');
    var o = og ? parseArticleIdFromHref(og.getAttribute('content')) : 0;
    if (o > 0) return o;
    var bodyId = parseInt(document.body && (document.body.getAttribute('data-article-id') || document.body.getAttribute('data-id') || ''), 10);
    return Number.isFinite(bodyId) && bodyId > 0 ? bodyId : 0;
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (id > 0) updateRecentList(id);
  }

  function injectHomeCss() {
    if (!isHomePage() || qs(document, '#' + HOME_STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = HOME_STYLE_ID;
    style.textContent = [
      "body.ks-page-home{--ks-lane-left:0px;--ks-lane-right:0px;--ks-mask-top:160px;}",
      "body.ks-page-home::before,body.ks-page-home::after{content:'';position:fixed;top:var(--ks-mask-top);bottom:0;z-index:2147483643;background:#fff;pointer-events:none;}",
      "body.ks-page-home::before{left:0;width:var(--ks-lane-left);}",
      "body.ks-page-home::after{right:0;width:var(--ks-lane-right);}",
      "body.ks-page-home .auto-popup,body.ks-page-home .modal-newleter,body.ks-page-home [class*='modal-newleter']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home [data-ks-hidden='1'],body.ks-page-home [data-ks-rogue='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home .ks-home-departments .ks-home-submenu-container[aria-hidden='true']{display:none!important;}",
      "@media (max-width:1199px){body.ks-page-home::before,body.ks-page-home::after{display:none!important;}}"
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function setBodyFlags() {
    if (isHomePage()) document.body.classList.add('ks-page-home');
    if (isArticlePage()) document.body.classList.add('ks-page-article');
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
      node.setAttribute('data-ks-hidden', '1');
      if (node.parentNode && /backdrop/i.test(node.className || '')) node.parentNode.removeChild(node);
    });
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function rect(node) {
    try { return node && node.getBoundingClientRect ? node.getBoundingClientRect() : null; } catch (err) { return null; }
  }

  function styleOf(node) {
    try { return node ? window.getComputedStyle(node) : null; } catch (err) { return null; }
  }

  function inProtectedArea(node) {
    return !!(node && node.closest && node.closest([
      'header','footer','.container','.ks-home-departments','.ks-home-hero-shell','.s-banner-wrapper',
      '.wrap-item-1','.wrap-item-2','.wrap-item-3','.card-product','.product-list-wrap','.swiper','.modal','.offcanvas'
    ].join(',')));
  }

  function blockedToken(text) {
    var n = normalizeText(text);
    return BLOCKED_TOKENS.some(function (t) { return n.indexOf(normalizeText(t)) !== -1; });
  }

  function computeLaneBounds() {
    var container = qs(document, '.ks-home-hero-shell') || qs(document, '.s-banner-wrapper') || qs(document, '.container');
    var r = rect(container);
    if (!r) return;
    var left = Math.max(0, Math.floor(r.left) - 8);
    var right = Math.max(0, Math.floor(window.innerWidth - r.right) - 8);
    document.body.style.setProperty('--ks-lane-left', left + 'px');
    document.body.style.setProperty('--ks-lane-right', right + 'px');
    var header = qs(document, 'header') || qs(document, '.tf-header') || qs(document, '.header');
    var hr = rect(header);
    document.body.style.setProperty('--ks-mask-top', ((hr && hr.bottom) ? Math.ceil(hr.bottom) : 150) + 'px');
  }

  function hideRogueRails() {
    if (!isHomePage()) return;

    var seenBySrc = {};
    qsa(document, 'img').forEach(function (img) {
      var r = rect(img);
      if (!r || inProtectedArea(img)) return;
      var src = String(img.getAttribute('src') || img.getAttribute('data-src') || '').replace(/[?#].*$/, '');
      if (!src) return;
      if (r.width <= 200 && r.height <= 300 && (r.left < 120 || r.right > window.innerWidth - 120)) {
        seenBySrc[src] = seenBySrc[src] || [];
        seenBySrc[src].push(img);
      }
    });

    Object.keys(seenBySrc).forEach(function (src) {
      if (seenBySrc[src].length < 2) return;
      seenBySrc[src].forEach(function (img) {
        var root = img.closest('a,div,li,span') || img;
        if (!inProtectedArea(root)) root.setAttribute('data-ks-rogue', '1');
      });
    });

    qsa(document.body, 'img,div,span,p,a,section,aside').forEach(function (node) {
      if (!node || inProtectedArea(node)) return;
      var r = rect(node);
      if (!r || r.width < 12 || r.height < 12) return;
      var st = styleOf(node);
      var pos = st ? st.position : '';
      var txt = [node.id || '', node.className || '', textOf(node).slice(0, 200), st && st.backgroundImage || ''].join(' ');
      var edge = r.left < 120 || r.right > window.innerWidth - 120;
      var narrow = r.width <= 240 && r.height >= 60;
      var vertical = r.height > (r.width * 2.3) && r.width < 260;
      if ((edge && narrow && (pos === 'fixed' || pos === 'sticky' || pos === 'absolute')) || (edge && vertical) || blockedToken(txt)) {
        node.setAttribute('data-ks-rogue', '1');
      }
    });

    qsa(document.body, '*').forEach(function (node) {
      if (!node || inProtectedArea(node)) return;
      var t = normalizeText(textOf(node));
      if (!t) return;
      var r = rect(node);
      if (!r) return;
      if ((t === 'franchising' || t === 'welcome' || blockedToken(t)) && (r.left < 220 || r.right > window.innerWidth - 220)) {
        node.setAttribute('data-ks-rogue', '1');
      }
    });
  }

  function ensureCompactHero() {
    if (!isHomePage() || !window.matchMedia('(min-width:1200px)').matches) return;
    var shell = qs(document, '.ks-home-hero-shell') || qs(document, '.s-banner-wrapper');
    var side = shell && qs(shell, '.wrap-item-3');
    if (!shell || !side) return;
    var validCards = qsa(side, 'a,img,div').filter(function (node) {
      if (node.getAttribute && node.getAttribute('data-ks-rogue') === '1') return false;
      var r = rect(node);
      return r && r.width > 80 && r.height > 80 && r.width < 500 && r.height < 700;
    });
    if (validCards.length < 2) {
      side.style.setProperty('display', 'none', 'important');
      shell.classList.add('ks-home-force-compact');
    }
  }

  function esc(s) {
    return String(s || '').replace(/[&<>"]/g, function (ch) { return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[ch]; });
  }

  function parseFilterValue(raw) {
    var value = String(raw || '').trim();
    if (!value) return null;
    if (SEARCH_ALL_HINTS.some(function (hint) { return normalizeText(value) === normalizeText(hint); })) return null;
    var m;
    m = value.match(/(?:^|[?&])(st|ct|tp|gr|sg|mr|pid)=([0-9]+)/i);
    if (m) return { key: m[1].toLowerCase(), value: m[2] };
    m = value.match(/^(st|ct|tp|gr|sg|mr|pid)[:=]([0-9]+)$/i);
    if (m) return { key: m[1].toLowerCase(), value: m[2] };
    if (/^\d+$/.test(value)) return { key: 'st', value: value };
    return null;
  }

  function findSearchRoots() {
    var roots = [];
    qsa(document, 'form, .form-search-product, .search-box, .search-form, .search-header, .header-search, .box-search').forEach(function (node) {
      var input = qs(node, 'input[type="search"],input[type="text"]');
      if (!input) return;
      var txt = normalizeText(input.getAttribute('placeholder') || '') + ' ' + normalizeText(textOf(node));
      if (SEARCH_TEXT_HINTS.some(function (hint) { return txt.indexOf(normalizeText(hint)) !== -1; })) roots.push(node);
    });
    return roots.filter(function (node, idx) { return roots.indexOf(node) === idx; });
  }

  function itemPriceHtml(item) {
    return item && item.price ? '<span class="ks-sg-price">' + esc(item.price) + '</span>' : '';
  }

  function bindSearch() {
    findSearchRoots().forEach(function (root) {
      if (root.getAttribute('data-ks-search-bound') === '1') return;
      root.setAttribute('data-ks-search-bound', '1');

      var input = qs(root, 'input[type="search"],input[type="text"]');
      if (!input) return;
      var submitBtn = qs(root, 'button[type="submit"], .btn-submit-form, .icon-search, .search-submit, .btn-search');
      var select = qs(root, 'select') || qs(root, '.select-options .link[rel].active') || qs(root, '.select-options .link[rel]');
      var box = document.createElement('div');
      box.className = 'ks-search-suggest';
      box.style.cssText = 'position:absolute;left:0;right:0;top:100%;z-index:9999;background:#fff;border:1px solid #e5e7eb;border-radius:12px;box-shadow:0 12px 36px rgba(0,0,0,.12);display:none;max-height:420px;overflow:auto;margin-top:8px';
      root.style.position = root.style.position || 'relative';
      root.appendChild(box);

      var state = { timer: 0, items: [], active: -1, lastQuery: '' };

      function currentFilter() {
        var raw = '';
        if (select && select.tagName === 'SELECT') raw = select.value || (select.options[select.selectedIndex] && select.options[select.selectedIndex].text) || '';
        else if (select) raw = select.getAttribute('rel') || textOf(select);
        return parseFilterValue(raw);
      }

      function render(items, isRecent) {
        state.items = items || [];
        state.active = -1;
        if (!items || !items.length) { box.style.display = 'none'; box.innerHTML = ''; return; }
        box.innerHTML = (isRecent ? '<div class="ks-sg-head">Recenti</div>' : '') + items.map(function (item, idx) {
          return '<a class="ks-sg-item" href="' + esc(item.url || '#') + '" data-index="' + idx + '" style="display:flex;gap:12px;align-items:center;padding:10px 12px;text-decoration:none;color:#111827;border-top:' + (idx ? '1px solid #f0f0f0' : '0') + '">' +
            '<span style="width:48px;height:48px;border:1px solid #eee;border-radius:10px;flex:0 0 auto;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#fff"><img src="' + esc(item.image || item.imageFallback || '') + '" alt="" style="max-width:100%;max-height:100%"></span>' +
            '<span style="min-width:0;flex:1 1 auto"><span style="display:block;font-size:13px;font-weight:600;line-height:1.3">' + esc(item.title || '') + '</span><span style="display:block;font-size:12px;color:#6b7280">' + esc((item.brand || '') + ((item.brand && item.category) ? ' · ' : '') + (item.category || '')) + '</span></span>' +
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

      function performSubmit() {
        var q = String(input.value || '').trim();
        if (!q) {
          window.location.href = structuredResultsUrl('');
          return;
        }
        fetchSuggest(q, true);
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
          else performSubmit();
        }
      });
      if (submitBtn) submitBtn.addEventListener('click', function (e) { e.preventDefault(); performSubmit(); });
      var form = root.tagName === 'FORM' ? root : root.closest('form');
      if (form) form.addEventListener('submit', function (e) { e.preventDefault(); performSubmit(); });
      document.addEventListener('click', function (e) { if (!root.contains(e.target)) box.style.display = 'none'; });
    });
  }

  function runStableHomePass() {
    if (!isHomePage()) return;
    injectHomeCss();
    disablePopupStorage();
    suppressNewsletterPopup();
    computeLaneBounds();
    hideRogueRails();
    ensureCompactHero();
  }

  function armStableHomePass() {
    if (!isHomePage()) return;
    [0, 200, 900, 2200, 5000, 9000].forEach(function (delay) { setTimeout(runStableHomePass, delay); });
    var t = 0;
    if (typeof MutationObserver !== 'undefined' && document.body) {
      var mo = new MutationObserver(function () {
        clearTimeout(t);
        t = setTimeout(runStableHomePass, 120);
      });
      mo.observe(document.body, { childList: true, subtree: true });
      setTimeout(function () { mo.disconnect(); }, 12000);
    }
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
  });
})();
