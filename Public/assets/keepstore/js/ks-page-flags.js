(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themesflat', 'themeforest', 'mediacom'];

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function normalizePath(path) {
    return String(path || '')
      .toLowerCase()
      .replace(/\/+?/g, '/')
      .replace(/\/default\.aspx$/i, '/')
      .replace(/\/$/, '/');
  }

  function isHomePage() {
    var pathname = window.location.pathname || '/';
    var path = normalizePath(pathname);
    return path === '/' || /\/default\.aspx$/i.test(pathname);
  }

  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
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
    try {
      return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || '');
    } catch (err) {
      return [];
    }
  }

  function writeSessionRecent(list) {
    try {
      window.sessionStorage.setItem(SESSION_KEY, (list || []).join(','));
    } catch (err) {
      return;
    }
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

    if (document.body) {
      var dataId = parseInt(document.body.getAttribute('data-article-id') || document.body.getAttribute('data-id') || '', 10);
      if (Number.isFinite(dataId) && dataId > 0) return dataId;
    }

    return 0;
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (!Number.isFinite(id) || id <= 0) return;
    updateRecentList(id);
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

  function textContentOf(node) {
    return String(node && node.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function rectOf(node) {
    if (!node || typeof node.getBoundingClientRect !== 'function') return null;
    var rect = node.getBoundingClientRect();
    if (!rect || (!rect.width && !rect.height)) return null;
    return rect;
  }

  function computedStyleOf(node) {
    if (!node || typeof window.getComputedStyle !== 'function') return null;
    try {
      return window.getComputedStyle(node);
    } catch (err) {
      return null;
    }
  }

  function backgroundImageOf(node) {
    var style = computedStyleOf(node);
    return style && style.backgroundImage && style.backgroundImage !== 'none' ? style.backgroundImage : '';
  }

  function hideNode(node, attrName) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (attrName) node.setAttribute(attrName, '1');
  }

  function usefulRect(rect) {
    return !!(rect && rect.width >= 8 && rect.height >= 8);
  }

  function homeHeaderBottom() {
    var header = document.querySelector('.tf-header, header, .header-bottom, .header');
    var rect = rectOf(header);
    return rect ? Math.max(0, Math.round(rect.bottom)) : 0;
  }

  function primaryLaneRect() {
    var candidates = [
      '.ks-home-hero-shell',
      '.s-banner-wrapper',
      '.tf-sp-5 .container',
      '.tf-sp-2 .container',
      '#wrapper > .container',
      'main .container',
      '.container'
    ];

    for (var i = 0; i < candidates.length; i += 1) {
      var node = document.querySelector(candidates[i]);
      var rect = rectOf(node);
      if (usefulRect(rect) && rect.width >= 600) return rect;
    }
    return null;
  }

  function setGutterVars() {
    if (!isHomePage() || !document.body) return;
    var lane = primaryLaneRect();
    var headerBottom = homeHeaderBottom();
    if (!lane) {
      document.body.style.setProperty('--ks-mask-top', headerBottom + 'px');
      document.body.style.setProperty('--ks-left-gutter', '0px');
      document.body.style.setProperty('--ks-right-gutter', '0px');
      return;
    }

    var left = Math.max(0, Math.floor(lane.left - 18));
    var right = Math.max(0, Math.floor(window.innerWidth - lane.right - 18));
    document.body.style.setProperty('--ks-mask-top', headerBottom + 'px');
    document.body.style.setProperty('--ks-left-gutter', left + 'px');
    document.body.style.setProperty('--ks-right-gutter', right + 'px');
  }

  function suppressNewsletterPopup() {
    if (!isHomePage()) return;
    Array.prototype.slice.call(document.querySelectorAll('.auto-popup, .modal-newleter, [class*="modal-newleter"]')).forEach(function (node) {
      hideNode(node, 'data-ks-hidden-popup');
    });

    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function (node) {
      if (node.parentNode) node.parentNode.removeChild(node);
    });

    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function hasBlockedToken(raw) {
    var text = normalizeText(raw);
    if (!text) return false;
    return BLOCKED_TOKENS.some(function (token) { return text.indexOf(token) !== -1; });
  }

  function shouldProtect(node) {
    if (!node || !node.closest) return false;
    return !!node.closest([
      'header', 'footer', '.tf-header', '.tf-footer', '.footer',
      '.ks-home-departments', '.ks-home-hero-shell', '.wrap-item-1', '.wrap-item-2', '.wrap-item-3',
      '.tf-icon-box', '.card-product', '.ks-card-product', '.ks-grid-card', '.ks-row-card', '.ks-big-card', '.ks-deal-card',
      '.ks-home-brands', '.tf-grid-product-item', '.modal.show', '.offcanvas.show'
    ].join(','));
  }

  function artifactRoot(node) {
    var current = node;
    var best = node;
    for (var i = 0; current && current.parentElement && i < 7; i += 1) {
      var parent = current.parentElement;
      if (shouldProtect(parent)) break;
      var rect = rectOf(parent);
      if (!usefulRect(rect)) break;
      if (rect.width > 260 || rect.height > window.innerHeight * 1.8) break;
      best = parent;
      current = parent;
    }
    return best;
  }

  function outsideLane(rect, lane) {
    if (!rect || !lane) return false;
    return rect.right <= (lane.left - 12) || rect.left >= (lane.right + 12);
  }

  function sweepTokenizedArtifacts() {
    if (!isHomePage()) return;
    var lane = primaryLaneRect();
    if (!lane) return;

    Array.prototype.slice.call(document.querySelectorAll('img,div,span,p,a,section,aside')).forEach(function (node) {
      if (!node || shouldProtect(node)) return;
      var rect = rectOf(node);
      if (!usefulRect(rect)) return;
      if (!outsideLane(rect, lane)) return;
      if (rect.width > 260 || rect.height > 1400) return;

      var raw = [
        node.id || '',
        node.className || '',
        node.getAttribute && node.getAttribute('src') || '',
        node.getAttribute && node.getAttribute('data-src') || '',
        node.getAttribute && node.getAttribute('alt') || '',
        backgroundImageOf(node),
        textContentOf(node).slice(0, 200)
      ].join(' ');

      if (!hasBlockedToken(raw)) return;
      hideNode(artifactRoot(node), 'data-ks-edge-creative');
    });
  }

  function normalizeSrc(src) {
    return String(src || '').replace(/^https?:/i, '').replace(/[?#].*$/, '').trim();
  }

  function sweepRepeatedDevices() {
    if (!isHomePage()) return;
    var lane = primaryLaneRect();
    if (!lane) return;
    var buckets = Object.create(null);

    Array.prototype.slice.call(document.querySelectorAll('img')).forEach(function (img) {
      if (!img || shouldProtect(img)) return;
      var rect = rectOf(img);
      if (!usefulRect(rect) || !outsideLane(rect, lane)) return;
      if (rect.width > 180 || rect.height > 260) return;
      var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
      if (!src || src.indexOf('data:image') === 0) return;
      if (!buckets[src]) buckets[src] = [];
      buckets[src].push(img);
    });

    Object.keys(buckets).forEach(function (src) {
      if (buckets[src].length < 2) return;
      buckets[src].forEach(function (img) {
        hideNode(artifactRoot(img), 'data-ks-edge-creative');
      });
    });
  }

  function hideHeaderClones() {
    if (!isHomePage()) return;
    var lane = primaryLaneRect();
    if (!lane) return;

    Array.prototype.slice.call(document.querySelectorAll('body > div, body > section, #wrapper > div, #wrapper > section')).forEach(function (node) {
      if (!node || shouldProtect(node)) return;
      var rect = rectOf(node);
      if (!usefulRect(rect)) return;
      if (rect.width < Math.min(window.innerWidth * 0.75, 720)) return;
      if (rect.top < homeHeaderBottom() - 4) return;
      var raw = normalizeText([node.id || '', node.className || '', textContentOf(node).slice(0, 300)].join(' '));
      var looksHeader = raw.indexOf('tutti i settori') !== -1 && raw.indexOf('cerca prodotti') !== -1;
      if (!looksHeader) return;
      hideNode(node, 'data-ks-header-clone');
    });
  }

  function hideOrphanFragments() {
    if (!isHomePage()) return;
    var lane = primaryLaneRect();
    if (!lane) return;

    Array.prototype.slice.call(document.querySelectorAll('span,p,small,div')).forEach(function (node) {
      if (!node || shouldProtect(node)) return;
      var rect = rectOf(node);
      if (!usefulRect(rect) || !outsideLane(rect, lane)) return;
      if (rect.width > 180 || rect.height > 80) return;
      var txt = textContentOf(node);
      if (!txt || txt.length > 22) return;
      if (!/(€|eur|promo|offerta|sconto|venduti|disponibili|welcome|franchis)/i.test(txt)) return;
      hideNode(artifactRoot(node), 'data-ks-orphan');
    });
  }

  function syncHomeShell() {
    if (!isHomePage()) return;
    var shell = document.querySelector('.ks-home-hero-shell');
    var sideWrap = shell ? shell.querySelector('.wrap-item-3') : null;
    if (!shell || !sideWrap || window.innerWidth < 1200) return;

    var visibleChildren = Array.prototype.slice.call(sideWrap.children).filter(function (node) {
      var rect = rectOf(node);
      return usefulRect(rect) && node.getAttribute('data-ks-edge-creative') !== '1' && node.offsetParent !== null;
    });

    if (visibleChildren.length < 2) {
      shell.classList.add('ks-home-force-compact');
      sideWrap.style.setProperty('display', 'none', 'important');
    } else {
      shell.classList.remove('ks-home-force-compact');
      sideWrap.style.removeProperty('display');
    }
  }

  function runHomePass() {
    if (!isHomePage()) return;
    setGutterVars();
    suppressNewsletterPopup();
    hideHeaderClones();
    sweepTokenizedArtifacts();
    sweepRepeatedDevices();
    hideOrphanFragments();
    syncHomeShell();
  }

  function applyHomeFlags() {
    if (!isHomePage()) return;
    addBodyClass('ks-page-home');
    if (readMergedRecent().length >= 2) addBodyClass('ks-has-recent-history');
  }

  window.KSRecent = {
    read: readMergedRecent,
    add: updateRecentList
  };

  onReady(function () {
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }

    applyHomeFlags();
    runHomePass();
    window.addEventListener('load', runHomePass, { once: true });
    window.addEventListener('resize', runHomePass);
    [300, 1200, 2500].forEach(function (delay) {
      window.setTimeout(runHomePass, delay);
    });
  });
})();
