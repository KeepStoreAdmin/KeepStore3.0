(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function normalizePath(path) {
    return String(path || '').toLowerCase().replace(/\/+$/g, '').replace(/\/default\.aspx$/i, '/default.aspx');
  }

  function isHomePage() {
    var pathname = window.location.pathname || '/';
    return pathname === '/' || /\/default\.aspx$/i.test(pathname);
  }

  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
  }

  function addBodyClass(name) {
    if (document.body && name) document.body.classList.add(name);
  }

  function getQueryParam(name) {
    try {
      return new URLSearchParams(window.location.search || '').get(name);
    } catch (err) {
      return null;
    }
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
    return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) { return Number.isFinite(id) && id > 0; });
  }

  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }

  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
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
    var next = (list || []).filter(function (id) { return Number.isFinite(id) && id > 0; }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }

  function updateRecentList(id) {
    var merged = readMergedRecent();
    var next = [id].concat(merged.filter(function (item) { return item !== id; })).slice(0, MAX_RECENT);
    persistRecentList(next);
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
    if (document.body) {
      var bodyId = parseInt(document.body.getAttribute('data-article-id') || document.body.getAttribute('data-id') || '', 10);
      if (Number.isFinite(bodyId) && bodyId > 0) return bodyId;
    }
    return 0;
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (Number.isFinite(id) && id > 0) updateRecentList(id);
  }

  function normalizeText(value) {
    var text = String(value || '').toLowerCase();
    try { text = text.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (err) {}
    return text.replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
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

  function styleOf(node) {
    try { return node ? window.getComputedStyle(node) : null; } catch (err) { return null; }
  }

  function normalizeSrc(src) {
    return String(src || '').replace(/^https?:/i, '').replace(/[?#].*$/, '').trim();
  }

  function hideNode(node, flag) {
    if (!node || !node.style) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (flag) node.setAttribute(flag, '1');
  }

  function isProtected(node) {
    if (!node || !node.closest) return false;
    return !!node.closest([
      'header', 'footer', '.footer', '.tf-header', '.tf-footer',
      '.ks-home-departments', '.ks-home-hero-shell', '.s-banner-wrapper',
      '.wrap-item-1', '.wrap-item-2', '.tf-icon-box',
      '.card-product', '.ks-home-brands', '.tf-grid-product-item',
      '.product-list-wrap', '.ks-top-catalog-mega', '.modal.show', '.offcanvas.show'
    ].join(','));
  }

  function containsToken(raw) {
    var value = normalizeText(raw);
    return BLOCKED_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
  }

  function firstHeaderBottom() {
    var header = document.querySelector('header') || document.querySelector('.tf-header');
    var topbar = document.querySelector('.tf-topbar');
    var bottom = 0;
    var hr = rectOf(header);
    var tr = rectOf(topbar);
    if (hr) bottom = Math.max(bottom, hr.bottom);
    if (tr) bottom = Math.max(bottom, tr.bottom);
    return Math.max(0, Math.round(bottom));
  }

  function primaryLaneRect() {
    var candidates = [
      '.ks-home-hero-shell', '.s-banner-wrapper', '.tf-sp-5 > .container', '.page-content > .container', '.main-content > .container', 'main .container'
    ];
    for (var i = 0; i < candidates.length; i += 1) {
      var nodes = Array.prototype.slice.call(document.querySelectorAll(candidates[i]));
      for (var j = 0; j < nodes.length; j += 1) {
        var rect = rectOf(nodes[j]);
        if (!rect) continue;
        if (rect.width < Math.min(620, window.innerWidth * 0.45)) continue;
        if (rect.top > window.innerHeight * 1.5) continue;
        return rect;
      }
    }
    return { left: 120, right: Math.max(900, window.innerWidth - 320), width: Math.max(900, window.innerWidth - 440) };
  }

  function setGutterVars() {
    if (!document.body) return;
    var lane = primaryLaneRect();
    var top = Math.max(0, firstHeaderBottom());
    var left = Math.max(96, Math.floor(Math.max(0, lane.left) - 20));
    var right = Math.max(320, Math.floor(Math.max(0, window.innerWidth - lane.right) + 80));
    var bg = '#f4f4f4';
    try {
      var computedBg = window.getComputedStyle(document.body).backgroundColor;
      if (computedBg && computedBg !== 'rgba(0, 0, 0, 0)' && computedBg !== 'transparent') bg = computedBg;
    } catch (err) {}
    document.body.style.setProperty('--ks-mask-top', top + 'px');
    document.body.style.setProperty('--ks-left-gutter', left + 'px');
    document.body.style.setProperty('--ks-right-gutter', right + 'px');
    document.body.style.setProperty('--ks-mask-bg', bg);
  }

  function suppressNewsletterPopup() {
    Array.prototype.slice.call(document.querySelectorAll('.auto-popup, .modal-newleter, [class*="modal-newleter"]')).forEach(function (node) {
      hideNode(node, 'data-ks-hidden-popup');
    });
    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function (node) {
      hideNode(node, 'data-ks-hidden-popup');
      if (node.parentNode) node.parentNode.removeChild(node);
    });
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function usefulSideItems(sideWrap) {
    if (!sideWrap) return [];
    return Array.prototype.slice.call(sideWrap.children).filter(function (node) {
      if (!node || node.offsetParent === null) return false;
      var rect = rectOf(node);
      if (!rect || rect.width < 40 || rect.height < 40) return false;
      var img = node.querySelector('img');
      var ir = rectOf(img);
      return !!(img && ir && ir.width >= 70 && ir.height >= 70);
    });
  }

  function compactHero() {
    var shell = document.querySelector('.ks-home-hero-shell');
    var sideWrap = document.getElementById('HeroSideWrap') || (shell ? shell.querySelector('.wrap-item-3') : null);
    var menuList = document.querySelector('.ks-home-departments .menu-category-list');
    var sliderWrap = document.getElementById('HeroSliderWrap') || (shell ? shell.querySelector('.wrap-item-2') : null);
    if (!shell || !sliderWrap) return;
    if (window.innerWidth < 1200) {
      shell.classList.remove('ks-home-force-compact');
      if (sideWrap) sideWrap.style.removeProperty('display');
      if (menuList) {
        menuList.style.maxHeight = '';
        menuList.style.height = '';
        menuList.removeAttribute('data-ks-menu-synced');
      }
      return;
    }
    if (sideWrap && usefulSideItems(sideWrap).length < 2) {
      shell.classList.add('ks-home-force-compact');
      sideWrap.style.setProperty('display', 'none', 'important');
    } else {
      shell.classList.remove('ks-home-force-compact');
    }
    if (menuList) {
      var rr = rectOf(sliderWrap);
      if (rr && rr.height > 220) {
        var listHeight = Math.max(180, Math.floor(rr.height - 20));
        menuList.style.maxHeight = listHeight + 'px';
        menuList.style.height = listHeight + 'px';
        menuList.setAttribute('data-ks-menu-synced', '1');
      }
    }
  }

  function artifactRoot(node) {
    var current = node;
    var hops = 0;
    while (current && current.parentElement && hops < 18) {
      var parent = current.parentElement;
      if (!parent || parent.tagName === 'BODY' || parent.tagName === 'MAIN' || parent.tagName === 'FORM') break;
      if (isProtected(parent)) break;
      var rect = rectOf(parent);
      if (!rect) break;
      if (rect.width > Math.min(720, window.innerWidth * 0.58) || rect.height > window.innerHeight * 4) break;
      current = parent;
      hops += 1;
    }
    return current || node;
  }

  function headerCloneRoot(node) {
    var current = node;
    var hops = 0;
    while (current && current.parentElement && hops < 8) {
      var parent = current.parentElement;
      if (!parent || parent.tagName === 'BODY' || parent.tagName === 'MAIN' || parent.tagName === 'FORM') break;
      var rect = rectOf(parent);
      if (!rect || rect.width < 400 || rect.width > window.innerWidth * 0.99) break;
      current = parent;
      hops += 1;
    }
    return current || node;
  }

  function hideHeaderClones() {
    var mainHeader = document.querySelector('header');
    var mainBottom = firstHeaderBottom();
    Array.prototype.slice.call(document.querySelectorAll('div,section,header')).forEach(function (node) {
      if (!node || node === mainHeader) return;
      if (mainHeader && mainHeader.contains(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.top < mainBottom + 60) return;
      if (rect.width < Math.max(420, window.innerWidth * 0.45) || rect.height < 24 || rect.height > 260) return;
      var raw = [node.className || '', textContentOf(node).slice(0, 300)].join(' ');
      var text = normalizeText(raw);
      var hasSearch = !!node.querySelector('input[type="search"], input[name*="search" i], input[placeholder*="cerca" i], input[placeholder*="ean" i], .icon-search, .tf-btn-search, button[type="submit"]');
      var hasLogo = !!node.querySelector('img[src*="logo" i], a[href*="default.aspx" i] img, .logo-site, .site-logo');
      var hasHeaderText = (
        text.indexOf('chiamaci gratis') !== -1 ||
        text.indexOf('spedizione gratuita') !== -1 ||
        text.indexOf('tutti i settori') !== -1 ||
        text.indexOf('cerca prodotti') !== -1 ||
        text.indexOf('il mio account') !== -1 ||
        text.indexOf('assistenza') !== -1
      );
      if (!(hasHeaderText || (hasSearch && (hasLogo || rect.width > window.innerWidth * 0.6)))) return;
      hideNode(headerCloneRoot(node), 'data-ks-header-clone');
    });
  }

  function hideDuplicateMediaBySource() {
    var lane = primaryLaneRect();
    var buckets = {};
    function getBg(node) {
      var st = styleOf(node);
      var bg = st && st.backgroundImage && st.backgroundImage !== 'none' ? String(st.backgroundImage) : '';
      var match = bg.match(/url\(["']?([^\)"']+)/i);
      return match ? normalizeSrc(match[1]) : '';
    }
    function srcOf(node) {
      if (node.tagName === 'IMG') return normalizeSrc(node.getAttribute('src') || node.getAttribute('data-src') || '');
      return getBg(node);
    }
    Array.prototype.slice.call(document.querySelectorAll('img,div,section,aside')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.width < 28 || rect.height < 36 || rect.width > 260 || rect.height > 340) return;
      var outsideLane = rect.right <= lane.left - 2 || rect.left >= lane.right + 2;
      if (!outsideLane) return;
      var src = srcOf(node);
      if (!src || src.length < 8) return;
      (buckets[src] = buckets[src] || []).push(node);
    });
    Object.keys(buckets).forEach(function (src) {
      if (buckets[src].length < 2) return;
      buckets[src].forEach(function (node) { hideNode(artifactRoot(node), 'data-ks-edge-creative'); });
    });
  }

  function hideTokenArtifacts() {
    var lane = primaryLaneRect();
    Array.prototype.slice.call(document.querySelectorAll('div,span,p,section,aside,img,a')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var rect = rectOf(node);
      if (!rect) return;
      var st = styleOf(node);
      var bg = st && st.backgroundImage && st.backgroundImage !== 'none' ? st.backgroundImage : '';
      var raw = [node.id || '', node.className || '', textContentOf(node).slice(0, 260), node.getAttribute ? (node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('alt') || '') : '', bg].join(' ');
      if (!containsToken(raw)) return;
      var outsideLane = rect.right <= lane.left + 20 || rect.left >= lane.right - 20;
      var tallLike = rect.height > Math.max(120, rect.width * 1.2);
      if (outsideLane || tallLike || rect.width < 320) hideNode(artifactRoot(node), 'data-ks-edge-creative');
    });
  }

  function hideRepeatedDeviceRails() {
    var lane = primaryLaneRect();
    var buckets = {};
    Array.prototype.slice.call(document.querySelectorAll('img,div,section,aside')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.width < 28 || rect.height < 36 || rect.width > 260 || rect.height > 320) return;
      var outsideLane = rect.right <= lane.left + 12 || rect.left >= lane.right - 12;
      if (!outsideLane) return;
      var st = styleOf(node);
      var hasMedia = node.tagName === 'IMG' || (st && st.backgroundImage && st.backgroundImage !== 'none');
      if (!hasMedia) return;
      var bucket = (rect.left < lane.left ? 'L:' : 'R:') + Math.round(rect.left / 30) + ':' + Math.round(rect.width / 20);
      (buckets[bucket] = buckets[bucket] || []).push(node);
    });
    Object.keys(buckets).forEach(function (key) {
      if (buckets[key].length < 3) return;
      buckets[key].forEach(function (node) { hideNode(artifactRoot(node), 'data-ks-edge-creative'); });
    });
  }

  function hideFixedEdgeArtifacts() {
    var lane = primaryLaneRect();
    Array.prototype.slice.call(document.querySelectorAll('div,section,aside,a,span,p')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var st = styleOf(node);
      var rect = rectOf(node);
      if (!st || !rect) return;
      var outsideLane = rect.right <= lane.left + 8 || rect.left >= lane.right - 8;
      if (!outsideLane) return;
      var z = parseInt(st.zIndex || '0', 10);
      var fixedLike = st.position === 'fixed' || st.position === 'sticky' || (st.position === 'absolute' && z >= 10);
      if (!fixedLike) return;
      if (rect.width > 320 || rect.height < 20) return;
      hideNode(artifactRoot(node), 'data-ks-edge-creative');
    });
  }

  function hideBodyLevelArtifacts() {
    if (!document.body) return;
    var lane = primaryLaneRect();
    Array.prototype.slice.call(document.body.children).forEach(function (node) {
      if (!node || /^(script|style|form)$/i.test(node.tagName)) return;
      if (node.tagName === 'HEADER' || node.tagName === 'FOOTER' || node.tagName === 'MAIN') return;
      var rect = rectOf(node);
      if (!rect) return;
      var raw = [node.id || '', node.className || '', textContentOf(node).slice(0, 300)].join(' ');
      var st = styleOf(node);
      var bg = st && st.backgroundImage && st.backgroundImage !== 'none' ? st.backgroundImage : '';
      raw += ' ' + bg;
      var outsideLane = rect.right <= lane.left + 16 || rect.left >= lane.right - 16;
      var headerLike = normalizeText(raw).indexOf('cerca prodotti') !== -1 || normalizeText(raw).indexOf('tutti i settori') !== -1;
      var fixedLike = st && (st.position === 'fixed' || st.position === 'sticky' || st.position === 'absolute');
      if (containsToken(raw) || (outsideLane && fixedLike) || (headerLike && rect.top > firstHeaderBottom() + 80)) {
        hideNode(node, 'data-ks-edge-creative');
      }
    });
  }

  function hideOrphanFragments() {
    var lane = primaryLaneRect();
    Array.prototype.slice.call(document.querySelectorAll('p,span,small,div')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.width > 240 || rect.height > 100) return;
      var outsideLane = rect.right <= lane.left + 12 || rect.left >= lane.right - 12;
      if (!outsideLane) return;
      var text = normalizeText(textContentOf(node));
      if (!text) return;
      var priceLike = /^\d+[\.,]?\d* ?e$/.test(text) || /^\d+[\.,]?\d*$/.test(text);
      var headerLike = text.indexOf('cerca prodotti') !== -1 || text.indexOf('tutti i settori') !== -1 || text.indexOf('il mio account') !== -1 || text.indexOf('assistenza') !== -1;
      if (priceLike || text.length < 3 || containsToken(text) || headerLike) hideNode(artifactRoot(node), 'data-ks-orphan');
    });
  }

  function hideDirectFranchising() {
    Array.prototype.slice.call(document.querySelectorAll('div,span,p,section,aside,a,img')).forEach(function (node) {
      if (!node || isProtected(node)) return;
      var raw = [node.id || '', node.className || '', textContentOf(node).slice(0, 160), node.getAttribute ? (node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('alt') || '') : ''].join(' ');
      if (containsToken(raw)) hideNode(artifactRoot(node), 'data-ks-edge-creative');
    });
  }

  function runHomeCleanup() {
    if (!isHomePage()) return;
    suppressNewsletterPopup();
    compactHero();
    setGutterVars();
    hideHeaderClones();
    hideBodyLevelArtifacts();
    hideDirectFranchising();
    hideTokenArtifacts();
    hideRepeatedDeviceRails();
    hideDuplicateMediaBySource();
    hideFixedEdgeArtifacts();
    hideOrphanFragments();
  }

  function applyHomeFlags() {
    if (!isHomePage()) return;
    addBodyClass('ks-page-home');
    if (readMergedRecent().length >= 2) addBodyClass('ks-has-recent-history');
  }

  window.KSRecent = { read: readMergedRecent, add: updateRecentList };

  onReady(function () {
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }
    applyHomeFlags();
    runHomeCleanup();
    if (isHomePage()) {
      [300, 1400, 3400, 6200, 9000].forEach(function (delay) {
        window.setTimeout(runHomeCleanup, delay);
      });
      window.addEventListener('load', runHomeCleanup, { once: true });
      window.addEventListener('resize', runHomeCleanup);
    }
  });
})();
