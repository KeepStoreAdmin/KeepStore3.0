(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var HOME_GUARD_ATTR = 'data-ks-home-guard';
  var HOME_STYLE_ID = 'ks-home-runtime-final';
  var HOME_RANDOM_SEED_ATTR = 'data-ks-home-seed';
  var HOME_SWEEP_TIMERS = [0, 60, 180, 420, 900, 1600, 2600, 4200, 6800, 10000, 15000, 22000, 30000, 42000, 52000];
  var BLOCKED_CREATIVE_TOKENS = ['welcome', 'franchis', 'themeforest', 'onsus', 'themesflat', 'demo', 'template', 'campaign', 'adv', 'promo'];
  var SEARCH_TEXT_HINTS = ['cerca', 'search', 'ean', 'prodot', 'codic', 'articol', 'sku', 'marketplace'];
  var SEARCH_ALL_HINTS = ['tutti', 'all', 'tutte', 'all categories', 'all departments', 'tutti i settori'];

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
      .replace(/\/+/g, '/')
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

  function homeHeroShell() {
    var shell = firstNode(document, '.ks-home-hero-shell') || firstNode(document, '.s-banner-wrapper');
    if (shell && shell.classList && !shell.classList.contains('ks-home-hero-shell')) {
      shell.classList.add('ks-home-hero-shell');
    }
    return shell;
  }

  function isDesktop() {
    if (typeof window.matchMedia === 'function') {
      return window.matchMedia('(min-width: 1200px)').matches;
    }
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
    } catch (err) {
      // ignore
    }

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

    var anchors = Array.prototype.slice.call(document.querySelectorAll('a[href*="articolo.aspx?id="]'));
    for (var i = 0; i < anchors.length; i += 1) {
      var found = parseArticleIdFromHref(anchors[i].getAttribute('href') || '');
      if (found > 0) return found;
    }

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

  function normalizeSrc(src) {
    return String(src || '')
      .replace(/^https?:/i, '')
      .replace(/[?#].*$/, '')
      .trim();
  }

  function backgroundImageOf(node) {
    var style = computedStyleOf(node);
    return style && style.backgroundImage && style.backgroundImage !== 'none' ? style.backgroundImage : '';
  }

  function firstNode(root, selector) {
    if (!root || !selector) return null;
    try {
      return root.querySelector(selector);
    } catch (err) {
      return null;
    }
  }

  function allNodes(root, selector) {
    if (!root || !selector) return [];
    try {
      return Array.prototype.slice.call(root.querySelectorAll(selector));
    } catch (err) {
      return [];
    }
  }

  function closestElement(node, selector) {
    if (!node || !selector) return null;
    if (typeof node.closest === 'function') {
      try {
        return node.closest(selector);
      } catch (err) {
        return null;
      }
    }
    var current = node;
    while (current && current.nodeType === 1) {
      if (typeof current.matches === 'function' && current.matches(selector)) return current;
      current = current.parentElement;
    }
    return null;
  }

  function isEdgeRect(rect, padding) {
    if (!rect) return false;
    var edgePadding = typeof padding === 'number' ? padding : 60;
    if (rect.width < 12 || rect.height < 12) return false;
    return rect.left <= edgePadding || rect.right >= (window.innerWidth - edgePadding);
  }

  function isNarrowEdgeRect(rect) {
    return !!(rect && isEdgeRect(rect, 90) && rect.width <= 240 && rect.height >= 80 && rect.height <= 1400);
  }

  function hideNode(node, attrName) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (attrName) node.setAttribute(attrName, '1');
  }

  function removeNode(node, attrName) {
    if (!node) return;
    hideNode(node, attrName);
    if (node.parentNode) {
      node.parentNode.removeChild(node);
    }
  }

  function nodeContainsBlockedCreative(node) {
    if (!node) return false;
    var raw = [
      node.id || '',
      node.className || '',
      node.getAttribute && node.getAttribute('src') || '',
      node.getAttribute && node.getAttribute('data-src') || '',
      node.getAttribute && node.getAttribute('alt') || '',
      backgroundImageOf(node),
      textContentOf(node).slice(0, 260)
    ].join(' ');
    var value = normalizeText(raw);
    if (!value) return false;
    return BLOCKED_CREATIVE_TOKENS.some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function hardProtectedAncestor(node) {
    if (!node || !node.closest) return false;
    if (node.closest('.ks-home-departments .ks-home-menu-row, .ks-home-departments .title')) {
      return true;
    }
    if (node.closest('.ks-home-departments [data-ks-submenu="1"][aria-hidden="false"]')) {
      return true;
    }
    return !!node.closest([
      'header', 'footer', '.tf-header', '.tf-footer', '.footer',
      '.wrap-item-1', '.wrap-item-2',
      '.tf-icon-box', '.card-product', '.ks-card-product', '.ks-grid-card', '.ks-row-card', '.ks-big-card', '.ks-deal-card',
      '.ks-home-brands', '.tf-grid-product-item', '.ks-home-brand-logo', '.modal:not(.auto-popup):not(.modal-newleter)', '.offcanvas.show'
    ].join(','));
  }

  function edgeCreativeRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;

    while (current && current.parentElement && hops < 8) {
      var parent = current.parentElement;
      if (hardProtectedAncestor(parent)) break;
      var rect = rectOf(parent);
      if (!rect || !isNarrowEdgeRect(rect)) break;
      best = parent;
      current = parent;
      hops += 1;
    }

    return best;
  }


  function isFixedLikePosition(style) {
    var pos = style && style.position ? String(style.position).toLowerCase() : '';
    return pos === 'fixed' || pos === 'sticky';
  }


  function isAbsoluteLikePosition(style) {
    var pos = style && style.position ? String(style.position).toLowerCase() : '';
    return pos === 'absolute';
  }

  function isVerticalWritingStyle(style) {
    if (!style) return false;
    var writingMode = String(style.writingMode || style.webkitWritingMode || '').toLowerCase();
    var transform = String(style.transform || '').toLowerCase();
    return writingMode.indexOf('vertical') !== -1 || transform.indexOf('rotate') !== -1;
  }

  function isHeaderFooterShell(node) {
    return !!closestElement(node, 'header, footer, .tf-header, .tf-footer, .footer');
  }

  function isCoreHeaderFooterChrome(node) {
    if (!node) return false;
    if (node.matches && node.matches('header, footer, .tf-header, .tf-footer, .footer')) return true;
    if (firstNode(node, '.logo-site, .main-nav-menu, nav, .nav-list, .header-center, .header-right, .support-wrap, .inner-header, .tf-topbar, .tf-cur, .nav-icon, .footer-heading, .footer-col-block, .footer-newsletter, .widget-logo')) return true;
    var rect = rectOf(node);
    if (!rect) return false;
    return rect.width >= Math.max((window.innerWidth || 0) * 0.55, 520) && rect.height >= 44;
  }


  function isRealHeaderNode(node) {
    if (!node) return false;
    if (node.matches && node.matches('header, .tf-header, .inner-header, .header-bottom, .tf-topbar')) return true;
    if (closestElement(node, 'header, .tf-header') && firstNode(node, '.logo-site, .main-nav-menu, .nav-list, .header-center, .header-right, .support-wrap')) return true;
    return false;
  }

  function isHeroShellChild(node) {
    return !!closestElement(node, '.ks-home-hero-shell, .s-banner-wrapper');
  }

  function fixedLikeRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;

    while (current && current.parentElement && hops < 8) {
      var parent = current.parentElement;
      if (hardProtectedAncestor(parent)) break;
      var style = computedStyleOf(parent);
      if (!isFixedLikePosition(style)) break;
      best = parent;
      current = parent;
      hops += 1;
    }

    return best;
  }

  function isLikelyUiUtility(node) {
    if (!node) return false;
    var raw = [node.id || '', node.className || '', node.getAttribute && node.getAttribute('aria-label') || '', textContentOf(node).slice(0, 120)].join(' ');
    var value = normalizeText(raw);
    if (!value) return false;
    return ['gotop', 'scroll top', 'cookie', 'consent', 'privacy', 'chat', 'whatsapp', 'messenger', 'intercom', 'tawk', 'captcha', 'recaptcha', 'translate'].some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function mediaCountOf(node) {
    if (!node) return 0;
    var count = allNodes(node, 'img, picture, video, canvas, svg, iframe, object, embed').length;
    if (backgroundImageOf(node)) count += 1;
    return count;
  }

  function floatingSideZone(rect) {
    if (!rect || rect.width < 20 || rect.height < 20) return false;
    var viewportWidth = Math.max(window.innerWidth || 0, document.documentElement ? document.documentElement.clientWidth : 0, 1);
    var leftZone = rect.left <= 140;
    var rightEdgeZone = rect.right >= (viewportWidth - 220);
    var rightRailZone = rect.left >= Math.floor(viewportWidth * 0.55);
    return leftZone || rightEdgeZone || rightRailZone;
  }

  function isSuspiciousFloatingEdgeNode(node) {
    if (!node || isLikelyUiUtility(node)) return false;
    if (hardProtectedAncestor(node) && !isHeaderFooterShell(node)) return false;

    var style = computedStyleOf(node);
    if (!isFixedLikePosition(style)) return false;
    var rect = rectOf(node);
    if (!rect || !floatingSideZone(rect)) return false;
    if (rect.width > 420 || rect.height > Math.max(window.innerHeight * 1.9, 1600)) return false;
    if (rect.width < 26 || rect.height < 26) return false;
    if (firstNode(node, 'input, textarea, select, iframe, form')) return false;
    if (isCoreHeaderFooterChrome(node)) return false;

    var mediaCount = mediaCountOf(node);
    var textLen = normalizeText(textContentOf(node)).length;
    var tallRail = rect.height >= 120 && (rect.height / Math.max(rect.width, 1)) >= 1.35;
    var visualToken = nodeContainsBlockedCreative(node);
    var verticalText = isVerticalWritingStyle(style);

    if (visualToken) return true;
    if (verticalText && floatingSideZone(rect)) return true;
    if (mediaCount >= 2) return true;
    if (mediaCount >= 1 && tallRail) return true;
    if (mediaCount >= 1 && textLen <= 96) return true;
    if (backgroundImageOf(node) && tallRail) return true;
    return false;
  }

  function isSuspiciousAbsoluteEdgeToken(node) {
    if (!node || hardProtectedAncestor(node) || isLikelyUiUtility(node)) return false;
    var style = computedStyleOf(node);
    if (!isAbsoluteLikePosition(style)) return false;
    var rect = rectOf(node);
    if (!rect || !isNarrowEdgeRect(rect)) return false;
    if (rect.width > 320 || rect.height > 1200) return false;
    if (!nodeContainsBlockedCreative(node) && !isVerticalWritingStyle(style)) return false;
    return true;
  }

  function sweepFloatingEdgeArtifacts() {
    if (!isHomePage() || !document.body) return;

    allNodes(document.body, '*').forEach(function (node) {
      if (isSuspiciousFloatingEdgeNode(node)) {
        hideNode(fixedLikeRoot(node), 'data-ks-floating-edge');
        return;
      }
      if (isSuspiciousAbsoluteEdgeToken(node)) {
        hideNode(edgeCreativeRoot(node), 'data-ks-edge-creative');
      }
    });
  }

  function ensureHomeGuardCss() {
    if (!isHomePage()) return;
    document.documentElement.setAttribute(HOME_GUARD_ATTR, '1');
    if (document.getElementById(HOME_STYLE_ID)) return;

    var style = document.createElement('style');
    style.id = HOME_STYLE_ID;
    style.type = 'text/css';
    style.appendChild(document.createTextNode([
      "html[data-ks-home-guard='1'] .auto-popup,",
      "html[data-ks-home-guard='1'] .modal-newleter,",
      "html[data-ks-home-guard='1'] [class*='modal-newleter'],",
      "html[data-ks-home-guard='1'] .sib-form-container{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] [data-ks-hidden-popup='1'],html[data-ks-home-guard='1'] [data-ks-edge-creative='1'],html[data-ks-home-guard='1'] [data-ks-floating-edge='1'],html[data-ks-home-guard='1'] [data-ks-home-artifact='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] body,html[data-ks-home-guard='1'] .ks-page-home{overflow-x:hidden!important;}",
      "html[data-ks-home-guard='1'] header,html[data-ks-home-guard='1'] .tf-header,html[data-ks-home-guard='1'] .tf-topbar,html[data-ks-home-guard='1'] .inner-header,html[data-ks-home-guard='1'] .header-bottom{position:static!important;top:auto!important;left:auto!important;right:auto!important;bottom:auto!important;inset:auto auto auto auto!important;transform:none!important;will-change:auto!important;z-index:auto!important;}",
      "html[data-ks-home-guard='1'] .header-sticky,html[data-ks-home-guard='1'] .sticky-header,html[data-ks-home-guard='1'] .header-fixed,html[data-ks-home-guard='1'] .header-clone,html[data-ks-home-guard='1'] .is-sticky,html[data-ks-home-guard='1'] .sticked{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] #goTop,html[data-ks-home-guard='1'] .goTop,html[data-ks-home-guard='1'] .scroll-top,html[data-ks-home-guard='1'] .back-to-top{display:none!important;}",
      "html[data-ks-home-guard='1'] .main-nav-menu .nav-item>.sub-menu-container{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] .main-nav-menu .nav-item:hover>.sub-menu-container,html[data-ks-home-guard='1'] .main-nav-menu .nav-item:focus-within>.sub-menu-container,html[data-ks-home-guard='1'] .main-nav-menu .nav-item.is-open>.sub-menu-container{display:block!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-category-list{overflow-x:hidden!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][aria-hidden='true']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][hidden]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .ks-home-sector-promo{position:relative!important;inset:auto!important;left:auto!important;right:auto!important;top:auto!important;bottom:auto!important;transform:none!important;flex:0 0 260px!important;max-width:260px!important;margin-left:20px!important;overflow:hidden!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][data-ks-inline-state='open']{display:flex!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list'] > [data-ks-submenu='1'][data-ks-inline-state='open']{display:block!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-has-children='0'] > [data-ks-submenu='1']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-has-children='0'] .ks-menu-toggle{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .ks-home-sector-promo[data-ks-hidden='1']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-category-list[data-ks-menu-synced='1']{overflow-y:auto!important;overscroll-behavior:contain;}",
      "@media (min-width:1200px){",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact,html[data-ks-home-guard='1'] .s-banner-wrapper.ks-home-force-compact{display:grid!important;grid-template-columns:minmax(250px,270px) minmax(0,1fr)!important;column-gap:24px!important;align-items:start!important;}",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact .wrap-item-3,html[data-ks-home-guard='1'] .s-banner-wrapper.ks-home-force-compact .wrap-item-3{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact .wrap-item-2,html[data-ks-home-guard='1'] .s-banner-wrapper.ks-home-force-compact .wrap-item-2{width:auto!important;max-width:none!important;min-width:0!important;flex:1 1 auto!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item.is-hover > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item.is-open > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item:focus-within > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item:hover > [data-ks-submenu='1']{display:flex!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list'].is-hover > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list'].is-open > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list']:focus-within > [data-ks-submenu='1'],",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list']:hover > [data-ks-submenu='1']{display:block!important;}",
      "html[data-ks-home-guard='1'] .ks-home-main-tabs .group-btn,html[data-ks-home-guard='1'] .flat-animate-tab .group-btn{display:flex!important;align-items:center!important;justify-content:space-between!important;gap:12px!important;flex-wrap:nowrap!important;margin-top:10px!important;}",
      "html[data-ks-home-guard='1'] .ks-home-main-tabs .group-btn .price-wrap,html[data-ks-home-guard='1'] .flat-animate-tab .group-btn .price-wrap{margin:0!important;flex:1 1 auto!important;}",
      "html[data-ks-home-guard='1'] .ks-home-main-tabs .group-btn .list-product-btn,html[data-ks-home-guard='1'] .flat-animate-tab .group-btn .list-product-btn{position:static!important;inset:auto!important;display:inline-flex!important;flex-direction:row!important;align-items:center!important;justify-content:flex-end!important;gap:8px!important;margin:0 0 0 auto!important;padding:0!important;transform:none!important;list-style:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-main-tabs .group-btn .list-product-btn li,html[data-ks-home-guard='1'] .flat-animate-tab .group-btn .list-product-btn li{margin:0!important;padding:0!important;}",
      "html[data-ks-home-guard='1'] .ks-home-main-tabs .group-btn .list-product-btn .box-icon,html[data-ks-home-guard='1'] .flat-animate-tab .group-btn .list-product-btn .box-icon{width:36px!important;height:36px!important;display:inline-flex!important;align-items:center!important;justify-content:center!important;border-radius:999px!important;}",
      "html[data-ks-home-guard='1'] .product-progress-sale .progress-sold,html[data-ks-home-guard='1'] .progress-sold.progress{display:flex!important;height:8px!important;border-radius:999px!important;overflow:hidden!important;background:#f5d8dc!important;}",
      "html[data-ks-home-guard='1'] .product-progress-sale .progress-sold .progress-bar,html[data-ks-home-guard='1'] .progress-sold.progress .progress-bar{display:block!important;height:100%!important;background:#ff434f!important;border-radius:999px!important;min-width:0!important;transition:width .2s ease;}",
      "html[data-ks-home-guard='1'] .ks-home-randomized{contain:layout style paint;}",
      "}"
    ].join('')));
    (document.head || document.documentElement).appendChild(style);
  }

  function disableTemplatePopupStorage() {
    if (!isHomePage()) return;
    try {
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
      window.sessionStorage.setItem('hidePopup', '1');
      window.localStorage.setItem('hidePopup', '1');
    } catch (err) {
      return;
    }
  }

  function clearStaleUiLock() {
    if (!isHomePage()) return;
    var visibleDialog = document.querySelector('.modal.show:not([data-ks-hidden-popup="1"]), .offcanvas.show');
    if (visibleDialog) return;

    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function (backdrop) {
      removeNode(backdrop, 'data-ks-hidden-popup');
    });

    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function newsletterPopupCandidates() {
    return allNodes(document, [
      '.auto-popup',
      '.modal-newleter',
      '[class*="modal-newleter"]',
      '.modal.auto-popup',
      '.sib-form-container',
      '.modal .form-newsletter',
      '.modal [type="email"]',
      '.modal .modal-content',
      '.modal .modal-dialog'
    ].join(','));
  }

  function looksLikeNewsletterPopup(node) {
    if (!node) return false;
    if (nodeContainsBlockedCreative(node) && closestElement(node, '.modal, .auto-popup, .modal-newleter')) return true;

    var raw = [node.id || '', node.className || '', textContentOf(node).slice(0, 320)].join(' ');
    var text = normalizeText(raw);
    if (/auto popup|modal newleter|sibform|sib form/.test(text)) return true;
    if (text.indexOf('join our newsletter') !== -1) return true;
    if (text.indexOf('newsletter') !== -1 && text.indexOf('subscribe') !== -1) return true;

    var emailInput = node.querySelector ? node.querySelector('input[type="email"], input[name*="mail"], input[name*="email"]') : null;
    var subscribeBtn = node.querySelector ? node.querySelector('button, .subscribe-button, .btn-hide-popup, .btn-submit-form') : null;
    if (emailInput && subscribeBtn) {
      var btnText = normalizeText(textContentOf(subscribeBtn));
      if (!btnText || btnText.indexOf('subscribe') !== -1 || btnText.indexOf('close') !== -1) return true;
    }

    return false;
  }

  function popupRoot(node) {
    if (!node) return null;
    return closestElement(node, '.auto-popup, .modal-newleter, [class*="modal-newleter"], .modal, .sib-form-container') || node;
  }

  function suppressNewsletterPopup() {
    if (!isHomePage()) return;

    newsletterPopupCandidates().forEach(function (node) {
      if (!looksLikeNewsletterPopup(node)) return;
      var root = popupRoot(node);
      if (!root) return;
      root.classList.remove('show', 'fade', 'in', 'active');
      root.setAttribute('aria-hidden', 'true');
      hideNode(root, 'data-ks-hidden-popup');
    });

    clearStaleUiLock();
  }

  function homeMenuRoot() {
    return document.querySelector('[data-ks-home-menu="1"], .ks-home-departments');
  }

  function menuItems(root) {
    return allNodes(root || homeMenuRoot(), '[data-ks-menu-item="1"], .menu-category-list > .menu-item');
  }

  function submenuModeForItem(item) {
    if (!item) return 'list';
    return item.getAttribute('data-ks-submenu-mode') || (item.getAttribute('data-ks-has-promo') === '1' ? 'promo' : 'list');
  }

  function setSubmenuState(item, open) {
    if (!item) return;
    var submenu = firstNode(item, '[data-ks-submenu="1"], .ks-home-submenu-container, .sub-menu-container');
    var toggle = firstNode(item, '[data-ks-toggle="1"], .ks-menu-toggle');
    var mode = submenuModeForItem(item);

    item.classList.toggle('is-open', !!open && !isDesktop());
    item.classList.toggle('is-hover', !!open && isDesktop());
    item.setAttribute('data-ks-open', open ? '1' : '0');

    if (toggle) {
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    }

    if (!submenu) return;

    submenu.setAttribute('aria-hidden', open ? 'false' : 'true');
    submenu.setAttribute('data-ks-inline-state', open ? 'open' : 'closed');
    if (open) {
      submenu.removeAttribute('hidden');
      submenu.removeAttribute('inert');
      submenu.style.display = mode === 'list' ? 'block' : 'flex';
      submenu.style.visibility = 'visible';
      submenu.style.opacity = '1';
      submenu.style.pointerEvents = 'auto';
    } else {
      submenu.setAttribute('hidden', 'hidden');
      submenu.setAttribute('inert', '');
      submenu.style.display = 'none';
      submenu.style.visibility = 'hidden';
      submenu.style.opacity = '0';
      submenu.style.pointerEvents = 'none';
    }
  }

  function closeSiblingMenuItems(item) {
    var parent = item && item.parentElement;
    if (!parent) return;
    Array.prototype.slice.call(parent.children).forEach(function (sibling) {
      if (sibling === item) return;
      setSubmenuState(sibling, false);
    });
  }

  function submenuHasContent(item) {
    if (!item) return false;
    var submenu = firstNode(item, '[data-ks-submenu="1"], .ks-home-submenu-container, .sub-menu-container');
    if (!submenu) return false;

    var links = allNodes(submenu, '.ks-home-submenu-list a[href], .sub-menu-list a[href], .menu-list a[href]').filter(function (link) {
      return !!normalizeText(textContentOf(link));
    });

    var promo = firstNode(submenu, '[data-ks-sector-promo="1"], .ks-home-sector-promo');
    var promoVisible = !!(promo && promo.getAttribute('data-ks-hidden') !== '1' && promo.getAttribute('data-ks-edge-creative') !== '1');
    return links.length > 0 || promoVisible;
  }

  function sanitizeHomeMenu() {
    var root = homeMenuRoot();
    if (!root) return;

    menuItems(root).forEach(function (item) {
      var submenu = firstNode(item, '[data-ks-submenu="1"], .ks-home-submenu-container, .sub-menu-container');
      var toggle = firstNode(item, '[data-ks-toggle="1"], .ks-menu-toggle');
      var arrow = firstNode(item, '.ks-menu-arrow');
      var promo = firstNode(item, '[data-ks-sector-promo="1"], .ks-home-sector-promo');

      if (promo) {
        var promoImg = firstNode(promo, 'img');
        var promoSrc = normalizeSrc((promoImg && (promoImg.getAttribute('src') || promoImg.getAttribute('data-src'))) || '');
        if (!promoSrc || nodeContainsBlockedCreative(promo) || nodeContainsBlockedCreative(promoImg)) {
          promo.setAttribute('data-ks-hidden', '1');
          hideNode(promo, 'data-ks-edge-creative');
        }
      }

      if (submenu) {
        submenu.classList.remove('d-flex');
        submenu.setAttribute('hidden', 'hidden');
        submenu.setAttribute('inert', '');
        submenu.style.setProperty('display', 'none', 'important');
        submenu.style.setProperty('visibility', 'hidden', 'important');
        submenu.style.setProperty('opacity', '0', 'important');
        submenu.style.setProperty('pointer-events', 'none', 'important');
        submenu.setAttribute('aria-hidden', 'true');
        submenu.setAttribute('data-ks-inline-state', 'closed');
      }

      if (!submenuHasContent(item)) {
        item.setAttribute('data-ks-has-children', '0');
        item.setAttribute('data-ks-submenu-mode', 'list');
        setSubmenuState(item, false);
        if (toggle) toggle.style.display = 'none';
        if (arrow) arrow.style.display = 'none';
        if (submenu) hideNode(submenu);
      } else {
        item.setAttribute('data-ks-submenu-mode', promo && promo.getAttribute('data-ks-hidden') !== '1' ? 'promo' : 'list');
      }
    });
  }

  function bindHomeMenu() {
    var root = homeMenuRoot();
    if (!root || root.getAttribute('data-ks-bound') === '1') return;
    root.setAttribute('data-ks-bound', '1');

    sanitizeHomeMenu();

    menuItems(root).forEach(function (item) {
      var toggle = firstNode(item, '[data-ks-toggle="1"], .ks-menu-toggle');

      item.addEventListener('mouseenter', function () {
        if (!isDesktop()) return;
        if (item.getAttribute('data-ks-has-children') !== '1') return;
        closeSiblingMenuItems(item);
        setSubmenuState(item, true);
      });

      item.addEventListener('mouseleave', function () {
        if (!isDesktop()) return;
        setSubmenuState(item, false);
      });

      item.addEventListener('focusin', function () {
        if (!isDesktop()) return;
        if (item.getAttribute('data-ks-has-children') !== '1') return;
        closeSiblingMenuItems(item);
        setSubmenuState(item, true);
      });

      item.addEventListener('focusout', function () {
        if (!isDesktop()) return;
        window.setTimeout(function () {
          if (!item.contains(document.activeElement) && !item.matches(':hover')) {
            setSubmenuState(item, false);
          }
        }, 20);
      });

      if (toggle) {
        toggle.addEventListener('click', function (evt) {
          if (item.getAttribute('data-ks-has-children') !== '1') return;
          evt.preventDefault();
          evt.stopPropagation();

          var willOpen = item.getAttribute('data-ks-open') !== '1';
          closeSiblingMenuItems(item);
          setSubmenuState(item, willOpen);
        });
      }
    });

    menuItems(root).forEach(function (item) { setSubmenuState(item, false); });

    document.addEventListener('click', function (evt) {
      if (!root.contains(evt.target)) {
        menuItems(root).forEach(function (item) { setSubmenuState(item, false); });
      }
    });
  }

  function sweepTokenizedEdgeCreatives() {
    if (!isHomePage() || !document.body) return;

    Array.prototype.slice.call(document.body.querySelectorAll('img,a,div,span,p,section,aside')).forEach(function (node) {
      if (!node || hardProtectedAncestor(node)) return;
      var rect = rectOf(node);
      if (!rect || !isNarrowEdgeRect(rect)) return;
      if (!nodeContainsBlockedCreative(node)) return;
      hideNode(edgeCreativeRoot(node), 'data-ks-edge-creative');
    });
  }

  function sweepRepeatedEdgeDevices() {
    if (!isHomePage()) return;

    var bySrc = Object.create(null);
    Array.prototype.slice.call(document.querySelectorAll('img')).forEach(function (img) {
      if (!img || hardProtectedAncestor(img)) return;
      var rect = rectOf(img);
      if (!rect || !isNarrowEdgeRect(rect)) return;
      if (rect.width > 220 || rect.height > 320) return;

      var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
      if (!src || src.indexOf('data:image') === 0) return;
      if (!bySrc[src]) bySrc[src] = [];
      bySrc[src].push(img);
    });

    Object.keys(bySrc).forEach(function (src) {
      if (bySrc[src].length < 2) return;
      bySrc[src].forEach(function (img) {
        hideNode(edgeCreativeRoot(img), 'data-ks-edge-creative');
      });
    });
  }

  function isUsableSidePromo(node) {
    if (!node || node.getAttribute('data-ks-edge-creative') === '1' || node.getAttribute('data-ks-home-artifact') === '1') return false;
    var rect = rectOf(node);
    if (!rect || node.offsetParent === null) return false;
    if (rect.width < 120 || rect.height < 90) return false;
    if ((rect.height / Math.max(rect.width, 1)) > 2.15) return false;
    if (nodeContainsBlockedCreative(node)) return false;
    var style = computedStyleOf(node);
    if (isVerticalWritingStyle(style)) return false;
    var visualCount = mediaCountOf(node);
    if (visualCount < 1) return false;
    var hrefNode = firstNode(node, 'a[href]');
    var href = hrefNode ? String(hrefNode.getAttribute('href') || '').trim() : '';
    if (href === '#' || href.toLowerCase().indexOf('javascript:') === 0) return false;
    return true;
  }

  function auditHeroSideAssets(sideWrap) {
    if (!sideWrap) return [];
    Array.prototype.slice.call(sideWrap.children).forEach(function (node) {
      if (!node) return;
      if (!isUsableSidePromo(node)) {
        hideNode(node, 'data-ks-edge-creative');
      }
    });

    return Array.prototype.slice.call(sideWrap.children).filter(function (node) {
      return isUsableSidePromo(node);
    });
  }

  function usefulSideItems(sideWrap) {
    return auditHeroSideAssets(sideWrap);
  }


  function sweepHeroShellArtifacts() {
    if (!isHomePage()) return;
    var shell = homeHeroShell();
    if (!shell) return;

    Array.prototype.slice.call(shell.children).forEach(function (child) {
      if (!child || child.classList && (child.classList.contains('wrap-item-1') || child.classList.contains('wrap-item-2') || child.classList.contains('wrap-item-3'))) return;
      var rect = rectOf(child);
      if (!rect || rect.width < 10 || rect.height < 10) return;
      hideNode(child, 'data-ks-home-artifact');
    });

    allNodes(shell, '*').forEach(function (node) {
      if (!node || node === shell) return;
      if (closestElement(node, '.wrap-item-1, .wrap-item-2, .wrap-item-3, .banner-image-product-4, .ks-home-hero-slider, .swiper, .swiper-wrapper, .swiper-slide')) return;
      var rect = rectOf(node);
      var style = computedStyleOf(node);
      if (!rect || !style) return;
      var pos = String(style.position || '').toLowerCase();
      var suspicious = false;
      if ((pos === 'absolute' || pos === 'fixed' || pos === 'sticky') && (nodeContainsBlockedCreative(node) || mediaCountOf(node) >= 1 || isVerticalWritingStyle(style))) suspicious = true;
      if (rect.width <= 80 && rect.height >= 80 && isEdgeRect(rect, 120)) suspicious = true;
      if (rect.width <= 50 && rect.height >= 160) suspicious = true;
      if (suspicious) {
        hideNode(node, 'data-ks-home-artifact');
      }
    });
  }

  function sweepEdgeLaneVisuals() {
    if (!isHomePage() || !document.body) return;
    allNodes(document.body, 'img, a, div, span, aside, section').forEach(function (node) {
      if (!node || node === document.body) return;
      if (node.getAttribute && (node.getAttribute('data-ks-edge-creative') === '1' || node.getAttribute('data-ks-home-artifact') === '1' || node.getAttribute('data-ks-floating-edge') === '1')) return;
      if (hardProtectedAncestor(node)) return;
      if (isLikelyUiUtility(node)) return;
      if (isRealHeaderNode(node) || isHeaderFooterShell(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.width < 18 || rect.height < 18) return;
      if (!floatingSideZone(rect) && !isNarrowEdgeRect(rect)) return;
      if (rect.width > 260 || rect.height > 1800) return;
      var style = computedStyleOf(node);
      var pos = String((style && style.position) || '').toLowerCase();
      var visual = nodeContainsBlockedCreative(node) || mediaCountOf(node) >= 1 || isVerticalWritingStyle(style);
      var rail = (rect.width <= 90 && rect.height >= 150) || (rect.width <= 180 && (rect.height / Math.max(rect.width,1)) >= 1.35);
      if (!visual && pos !== 'fixed' && pos !== 'sticky' && pos !== 'absolute' && !rail) return;
      hideNode(edgeCreativeRoot(node), 'data-ks-home-artifact');
    });
  }

  function hideStickyHeaderReplicas() {
    if (!isHomePage()) return;
    allNodes(document.body, 'header, .tf-header, .tf-topbar, .inner-header, .header-bottom, .header-sticky, .sticky-header, .header-fixed, .header-clone, .is-sticky, .sticked').forEach(function (node) {
      if (!node) return;
      if (isCoreHeaderFooterChrome(node) && (node.matches && (node.matches('header, .tf-header') || closestElement(node, 'header, .tf-header')))) {
        var style = computedStyleOf(node);
        if (style && (String(style.position || '').toLowerCase() === 'fixed' || String(style.position || '').toLowerCase() === 'sticky')) {
          node.style.setProperty('position', 'static', 'important');
          node.style.setProperty('transform', 'none', 'important');
          node.style.setProperty('top', 'auto', 'important');
          node.style.setProperty('left', 'auto', 'important');
          node.style.setProperty('right', 'auto', 'important');
        }
      }
    });
  }

  function hideDuplicateHeaderClones() {
    if (!isHomePage()) return;
    var primaryHeader = firstNode(document, 'header, .tf-header');
    var primaryBottom = 0;
    if (primaryHeader) {
      var primaryRect = rectOf(primaryHeader);
      primaryBottom = primaryRect ? primaryRect.bottom : 0;
    }

    allNodes(document.body, 'header, .tf-header, .tf-topbar, .inner-header, .header-bottom').forEach(function (node) {
      if (!node) return;
      if (primaryHeader && (node === primaryHeader || primaryHeader.contains(node) || node.contains(primaryHeader))) return;
      var rect = rectOf(node);
      if (!rect || rect.width < Math.max((window.innerWidth || 0) * 0.55, 520) || rect.height < 36) return;
      var absTop = rect.top + (window.scrollY || window.pageYOffset || 0);
      if (absTop <= Math.max(primaryBottom + 24, 240)) return;
      var raw = normalizeText(textContentOf(node));
      var headerish = raw.indexOf('home') !== -1 && (raw.indexOf('catalogo') !== -1 || raw.indexOf('shop') !== -1) && (raw.indexOf('contatti') !== -1 || raw.indexOf('contact') !== -1 || raw.indexOf('email') !== -1 || raw.indexOf('assistenza') !== -1);
      if (!headerish) return;
      hideNode(node, 'data-ks-home-artifact');
    });
  }

  function syncHomeShell() {
    if (!isHomePage()) return;

    var shell = homeHeroShell();
    var sliderWrap = shell ? shell.querySelector('.wrap-item-2') : null;
    var sideWrap = shell ? shell.querySelector('.wrap-item-3') : null;
    var menuRoot = document.querySelector('.ks-home-departments .main-nav');
    var menuTitle = menuRoot ? menuRoot.querySelector('.title') : null;
    var menuList = document.querySelector('.ks-home-departments .menu-category-list');

    if (!shell || !sliderWrap || !menuList) return;

    if (!isDesktop()) {
      shell.classList.remove('ks-home-force-compact');
      if (sideWrap) {
        sideWrap.removeAttribute('data-ks-home-artifact');
        sideWrap.style.removeProperty('display');
        sideWrap.style.removeProperty('visibility');
        sideWrap.style.removeProperty('opacity');
        sideWrap.style.removeProperty('pointer-events');
      }
      menuList.style.maxHeight = '';
      menuList.style.height = '';
      menuList.removeAttribute('data-ks-menu-synced');
      return;
    }

    if (sideWrap) {
      var sideItems = usefulSideItems(sideWrap);
      var sideRect = rectOf(sideWrap);
      var sideLikelyBroken = !sideRect || sideRect.width < 80 || sideRect.height < 80 || nodeContainsBlockedCreative(sideWrap);
      if (sideItems.length < 2 || sideLikelyBroken) {
        shell.classList.add('ks-home-force-compact');
        hideNode(sideWrap, 'data-ks-home-artifact');
      } else {
        shell.classList.remove('ks-home-force-compact');
        sideWrap.removeAttribute('data-ks-home-artifact');
        sideWrap.style.removeProperty('display');
        sideWrap.style.removeProperty('visibility');
        sideWrap.style.removeProperty('opacity');
        sideWrap.style.removeProperty('pointer-events');
      }
    }

    var targetNode = sliderWrap.querySelector('.banner-image-product-4') || sliderWrap.querySelector('.ks-home-hero-slider') || sliderWrap;
    var sliderRect = rectOf(targetNode);
    var titleRect = rectOf(menuTitle);
    if (!sliderRect || sliderRect.height < 220) return;

    var titleHeight = titleRect ? Math.ceil(titleRect.height) : 0;
    var listHeight = Math.max(180, Math.floor(sliderRect.height - titleHeight - 8));
    menuList.style.maxHeight = listHeight + 'px';
    menuList.style.height = listHeight + 'px';
    menuList.setAttribute('data-ks-menu-synced', '1');
  }


  function textLooksLikePlaceholderPhone(text) {
    var digits = String(text || '').replace(/\D+/g, '');
    if (!digits) return false;
    return /^0+$/.test(digits) || digits.indexOf('000000') !== -1;
  }

  function textLooksLikePlaceholderEmail(text) {
    var value = normalizeText(text);
    return value.indexOf('www taikun it') !== -1 || value.indexOf('example com') !== -1;
  }

  function firstMeaningful(nodes, predicate) {
    for (var i = 0; i < nodes.length; i += 1) {
      if (predicate(nodes[i])) return nodes[i];
    }
    return null;
  }

  function readHeaderContactInfo() {
    var info = { phone: '', phoneHref: '', email: '', emailHref: '', logoSrc: '', logoSrcset: '', logoAlt: '' };
    var phoneLink = firstMeaningful(allNodes(document, 'header a[href^="tel:"], .tf-topbar a[href^="tel:"], .support-wrap a[href^="tel:"]'), function (node) {
      return !!textContentOf(node);
    });
    var emailLink = firstMeaningful(allNodes(document, 'header a[href^="mailto:"], .support-wrap a[href^="mailto:"]'), function (node) {
      return !!textContentOf(node);
    });
    var logoImg = firstMeaningful(allNodes(document, 'header .logo-site img, .tf-header .logo-site img, .logo-site img'), function (node) {
      return !!normalizeSrc(node.getAttribute('src') || node.getAttribute('data-src') || '');
    });

    if (phoneLink) {
      info.phone = textContentOf(phoneLink);
      info.phoneHref = phoneLink.getAttribute('href') || '';
    }
    if (emailLink) {
      info.email = textContentOf(emailLink);
      info.emailHref = emailLink.getAttribute('href') || '';
    }
    if (logoImg) {
      info.logoSrc = logoImg.getAttribute('src') || logoImg.getAttribute('data-src') || '';
      info.logoSrcset = logoImg.getAttribute('srcset') || '';
      info.logoAlt = logoImg.getAttribute('alt') || 'Taikun';
    }

    return info;
  }

  function repairFooterBranding() {
    var footer = firstNode(document, 'footer, .tf-footer, .footer');
    if (!footer) return;

    var info = readHeaderContactInfo();
    var logoImg = firstNode(footer, '.logo-site img, .footer-logo img, .widget-logo img, img[alt="Logo"], img[alt="logo"]');
    if (logoImg && info.logoSrc) {
      var currentSrc = normalizeSrc(logoImg.getAttribute('src') || logoImg.getAttribute('data-src') || '');
      var altText = normalizeText(logoImg.getAttribute('alt') || '');
      if (!currentSrc || altText === 'logo' || altText === '' || currentSrc.indexOf('placeholder') !== -1) {
        logoImg.setAttribute('src', info.logoSrc);
        if (info.logoSrcset) logoImg.setAttribute('srcset', info.logoSrcset);
        logoImg.setAttribute('alt', info.logoAlt || 'Taikun');
      }
    }

    if (info.phone) {
      allNodes(footer, 'a[href^="tel:"], p, span, div, li').forEach(function (node) {
        if (!node || node.children.length > 0 && node.tagName !== 'A') return;
        var rawText = textContentOf(node);
        if (!rawText) return;
        if (!textLooksLikePlaceholderPhone(rawText)) return;
        if (node.tagName === 'A') {
          node.textContent = info.phone;
          if (info.phoneHref) node.setAttribute('href', info.phoneHref);
        } else {
          node.textContent = rawText.replace(/\+?[0-9][0-9\s\.-]{5,}/, info.phone);
        }
      });
    }

    if (info.email) {
      allNodes(footer, 'a[href^="mailto:"], p, span, div, li').forEach(function (node) {
        if (!node || node.children.length > 0 && node.tagName !== 'A') return;
        var rawText = textContentOf(node);
        if (!rawText) return;
        if (!(textLooksLikePlaceholderEmail(rawText) || /@/.test(rawText) && rawText.toLowerCase().indexOf('www.taikun.it') !== -1)) return;
        if (node.tagName === 'A') {
          node.textContent = info.email;
          node.setAttribute('href', info.emailHref || ('mailto:' + info.email));
        } else {
          node.textContent = rawText.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/ig, info.email);
        }
      });
    }
  }

  function selectedPseudoOption(root) {
    var selectors = [
      '.select-options li.active',
      '.select-options li.selected',
      '.select-options li[aria-selected="true"]',
      '.nice-select .option.selected',
      '.nice-select .current',
      '.select-selected',
      '[data-ks-selected="1"]'
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var node = firstNode(root, selectors[i]);
      if (node) return node;
    }
    return null;
  }

  function looksLikeSearchTextInput(input) {
    if (!input || input.type === 'hidden' || input.type === 'email' || input.type === 'password') return false;
    var raw = [
      input.name || '',
      input.id || '',
      input.className || '',
      input.getAttribute('placeholder') || '',
      input.getAttribute('aria-label') || ''
    ].join(' ');
    var text = normalizeText(raw);
    if (!text) return false;
    return SEARCH_TEXT_HINTS.some(function (token) { return text.indexOf(token) !== -1; });
  }

  function looksLikeAllDepartments(text) {
    var value = normalizeText(text);
    if (!value) return true;
    return SEARCH_ALL_HINTS.some(function (token) { return value.indexOf(normalizeText(token)) !== -1; });
  }

  function searchRoots() {
    var header = document.querySelector('header, .tf-header, .ks-site-header, .site-header') || document.body;
    var candidates = allNodes(document, 'form, .form-search-product, .header-center, .search-product, [data-ks-site-search], .search-wrap, .search-form, .header-search, .search-area, .box-search, .header-search-box');
    var out = [];

    candidates.forEach(function (node) {
      if (!node) return;
      var input = allNodes(node, 'input[type="search"], input[type="text"], input:not([type])').filter(looksLikeSearchTextInput)[0] || null;
      if (!input) return;
      var buttons = allNodes(node, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon, a[href="#"][class*="search"], a.btn-submit-form');
      var select = firstNode(node, 'select') || selectedPseudoOption(node);
      var root = closestElement(input, '.form-search-product, .header-center, .search-product, [data-ks-site-search], .search-wrap, form, .search-form, .header-search, .search-area, .box-search, .header-search-box') || node;
      if (!root || out.indexOf(root) !== -1) return;
      var rect = rectOf(root);
      var nearTop = !rect || rect.top <= 320;
      if (!nearTop && !header.contains(root)) return;
      if (!buttons.length && !select) return;
      out.push(root);
    });

    return out;
  }

  function searchInputFromRoot(root) {
    return allNodes(root, 'input[type="search"], input[type="text"], input:not([type])').filter(looksLikeSearchTextInput)[0] || null;
  }

  function searchSelectFromRoot(root) {
    return firstNode(root, 'select, [role="listbox"] select, .dropdown_product_cat') || selectedPseudoOption(root);
  }

  function searchButtonsFromRoot(root) {
    var buttons = allNodes(root, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon, a[href="#"][class*="search"], a.btn-submit-form');
    return buttons.filter(function (btn) {
      var raw = [btn.name || '', btn.id || '', btn.className || '', btn.getAttribute('aria-label') || '', textContentOf(btn)].join(' ');
      var text = normalizeText(raw);
      return text.indexOf('search') !== -1 || text.indexOf('cerca') !== -1 || text.indexOf('icon search') !== -1 || text.indexOf('btn submit form') !== -1 || !!closestElement(btn, '.form-search-product, .header-search, .search-wrap');
    });
  }

  function parseQueryStringParams(raw, params) {
    if (!raw) return;
    var cleaned = String(raw).replace(/^.*\?/, '');
    if (!cleaned) return;
    var qs = new URLSearchParams(cleaned);
    ['st', 'ct', 'tp', 'gr', 'sg', 'mr', 'pid', 'inpromo', 'q'].forEach(function (key) {
      var value = qs.get(key);
      if (value) params[key] = value;
    });
  }

  function readSelectTarget(select, root) {
    var result = { url: '', params: {} };
    var rawValue = '';
    var label = '';
    var selectName = '';

    if (select && select.options) {
      var option = select.selectedIndex >= 0 ? select.options[select.selectedIndex] : null;
      rawValue = option ? (option.value || option.getAttribute('data-url') || option.getAttribute('data-query') || option.getAttribute('data-value') || option.getAttribute('rel') || '') : '';
      label = option ? (option.text || option.textContent || '') : '';
      selectName = (select.name || '') + ' ' + (select.id || '');
    } else if (select) {
      rawValue = select.getAttribute('data-url') || select.getAttribute('data-query') || select.getAttribute('data-value') || select.getAttribute('data-id') || select.getAttribute('rel') || '';
      label = textContentOf(select);
      selectName = (select.getAttribute('name') || '') + ' ' + (select.id || '');
    }

    if ((!rawValue || rawValue === '0') && root) {
      var pseudo = selectedPseudoOption(root);
      if (pseudo) {
        rawValue = rawValue || pseudo.getAttribute('data-url') || pseudo.getAttribute('data-query') || pseudo.getAttribute('data-value') || pseudo.getAttribute('data-id') || pseudo.getAttribute('rel') || '';
        label = label || textContentOf(pseudo);
      }
    }

    var normalizedValue = String(rawValue || '').trim();
    if (!normalizedValue || normalizedValue === '0' || looksLikeAllDepartments(label) || looksLikeAllDepartments(normalizedValue)) {
      return result;
    }

    if (/^(https?:)?\/\//i.test(normalizedValue) || /\.aspx(\?|$)/i.test(normalizedValue) || normalizedValue.charAt(0) === '/') {
      result.url = normalizedValue;
      parseQueryStringParams(normalizedValue, result.params);
      return result;
    }

    parseQueryStringParams(normalizedValue, result.params);
    if (Object.keys(result.params).length > 0) return result;

    var kv = normalizedValue.match(/^(st|ct|tp|gr|sg|mr|pid)[:=|-](.+)$/i);
    if (kv) {
      result.params[kv[1].toLowerCase()] = kv[2];
      return result;
    }

    var digits = normalizedValue.match(/^(\d+)$/);
    if (digits) {
      if (/cat|cate|repart|settor/i.test(selectName)) {
        result.params.st = digits[1];
      } else {
        result.params.st = digits[1];
      }
      return result;
    }

    var anyDigits = normalizedValue.match(/(\d+)/);
    if (anyDigits) {
      result.params.st = anyDigits[1];
    }

    return result;
  }

  function buildMarketplaceSearchUrl(root) {
    var input = searchInputFromRoot(root);
    if (!input) return '';
    var query = String(input.value || '').replace(/\s+/g, ' ').trim();
    var select = searchSelectFromRoot(root);
    var target = readSelectTarget(select, root);
    var base = target.url || '/articoli.aspx';
    var url;

    try {
      url = new URL(base, window.location.href);
    } catch (err) {
      url = new URL('/articoli.aspx', window.location.href);
    }

    Object.keys(target.params || {}).forEach(function (key) {
      if (target.params[key]) {
        url.searchParams.set(key, target.params[key]);
      }
    });

    if (query) {
      url.searchParams.set('q', query);
    } else {
      url.searchParams.delete('q');
    }

    ['page', 'pageindex', 'Pagina', 'p', 'rimuovi'].forEach(function (key) {
      url.searchParams.delete(key);
    });

    if (!query && Object.keys(target.params || {}).length === 0 && !target.url) {
      return '';
    }

    return url.toString();
  }

  function executeMarketplaceSearch(root) {
    var url = buildMarketplaceSearchUrl(root);
    if (!url) {
      var input = searchInputFromRoot(root);
      if (input && typeof input.focus === 'function') input.focus();
      return;
    }
    window.location.href = url;
  }

  function bindMarketplaceSearch() {
    searchRoots().forEach(function (root) {
      if (!root || root.getAttribute('data-ks-marketplace-bound') === '1') return;
      root.setAttribute('data-ks-marketplace-bound', '1');

      var input = searchInputFromRoot(root);
      var buttons = searchButtonsFromRoot(root);
      var isSearchForm = !!(root.tagName && root.tagName.toLowerCase() === 'form');

      if (isSearchForm) {
        try { root.setAttribute('action', '/articoli.aspx'); root.setAttribute('method', 'get'); } catch (err) {}
        root.addEventListener('submit', function (evt) {
          evt.preventDefault();
          executeMarketplaceSearch(root);
        });
      }

      if (input) {
        input.setAttribute('autocomplete', 'off');
        input.addEventListener('keydown', function (evt) {
          if (evt.key === 'Enter') {
            evt.preventDefault();
            executeMarketplaceSearch(root);
          }
        });
      }

      buttons.forEach(function (button) {
        button.addEventListener('click', function (evt) {
          evt.preventDefault();
          evt.stopPropagation();
          executeMarketplaceSearch(root);
        });
      });
    });

    if (document.documentElement.getAttribute('data-ks-marketplace-global-bound') === '1') return;
    document.documentElement.setAttribute('data-ks-marketplace-global-bound', '1');

    document.addEventListener('submit', function (evt) {
      var form = evt.target;
      if (!form || !form.querySelector) return;
      var input = searchInputFromRoot(form);
      if (!input) return;
      var rect = rectOf(form);
      if (rect && rect.top > 420 && !closestElement(form, 'header, .tf-header, .site-header, .header-center, .search-wrap, .form-search-product')) return;
      evt.preventDefault();
      executeMarketplaceSearch(form);
    }, true);

    document.addEventListener('click', function (evt) {
      var button = closestElement(evt.target, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon, a[href="#"][class*="search"], a.btn-submit-form');
      if (!button) return;
      var root = closestElement(button, '.form-search-product, .header-search, .search-wrap, form, .header-center, .search-product, .box-search, .header-search-box');
      if (!root || !searchInputFromRoot(root)) return;
      evt.preventDefault();
      evt.stopPropagation();
      executeMarketplaceSearch(root);
    }, true);
  }


  function sweepViewportArtifacts() {
    if (!isHomePage() || !document.body) return;

    allNodes(document.body, '*').forEach(function (node) {
      if (!node || node.getAttribute('data-ks-home-artifact') === '1') return;
      if (hardProtectedAncestor(node)) return;
      var style = computedStyleOf(node);
      var rect = rectOf(node);
      if (!style || !rect) return;
      var pos = String(style.position || '').toLowerCase();
      if (pos !== 'fixed' && pos !== 'sticky' && pos !== 'absolute') return;
      if (!floatingSideZone(rect) && !isNarrowEdgeRect(rect)) return;
      if (rect.width > 420 || rect.height > 1600 || rect.width < 16 || rect.height < 16) return;
      if (isCoreHeaderFooterChrome(node) || isLikelyUiUtility(node)) return;
      if (nodeContainsBlockedCreative(node) || isVerticalWritingStyle(style) || mediaCountOf(node) >= 1) {
        hideNode(pos === 'absolute' ? edgeCreativeRoot(node) : fixedLikeRoot(node), 'data-ks-home-artifact');
      }
    });
  }

  function sweepGenericFixedRails() {
    if (!isHomePage()) return;
    allNodes(document.body, 'img, picture, div, a, span, section, aside').forEach(function (node) {
      if (!node || node === document.body) return;
      if (isLikelyUiUtility(node) || isRealHeaderNode(node) || isHeaderFooterShell(node)) return;
      var style = computedStyleOf(node);
      var rect = rectOf(node);
      if (!style || !rect) return;
      var pos = String(style.position || '').toLowerCase();
      if (pos !== 'fixed' && pos !== 'sticky' && pos !== 'absolute') return;
      if (!floatingSideZone(rect) && !isNarrowEdgeRect(rect)) return;
      if (rect.width > 260 || rect.height > 1800 || rect.width < 18 || rect.height < 18) return;
      if (firstNode(node, 'input, textarea, select, form, iframe')) return;
      var media = mediaCountOf(node);
      var vertical = isVerticalWritingStyle(style);
      var token = nodeContainsBlockedCreative(node);
      var rail = (rect.width <= 120 && rect.height >= 120) || (rect.width <= 220 && (rect.height / Math.max(rect.width, 1)) >= 1.25);
      if (!token && !vertical && media < 1 && !rail) return;
      hideNode(pos === 'absolute' ? edgeCreativeRoot(node) : fixedLikeRoot(node), 'data-ks-home-artifact');
    });
  }

  function pruneOrphanHomeFragments() {
    if (!isHomePage()) return;

    Array.prototype.slice.call(document.querySelectorAll('.ks-page-home .swiper-slide, .ks-page-home li')).forEach(function (node) {
      if (!node || node.getAttribute('data-ks-pruned') === '1') return;
      if (closestElement(node, '.card-product, .ks-card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card')) return;
      var text = normalizeText(textContentOf(node));
      var hasProductLink = !!firstNode(node, 'a[href*="articolo.aspx?id="], a[href*="articoli.aspx"], a[href*="default.aspx?id="]');
      var hasMedia = !!firstNode(node, 'img, picture, video');
      if (hasProductLink || hasMedia) return;
      if (!/\d+[\.,]?\d*\s*€/.test(textContentOf(node))) return;
      node.setAttribute('data-ks-pruned', '1');
      hideNode(node);
    });
  }



  function hashString(value) {
    var str = String(value || '');
    var hash = 2166136261;
    for (var i = 0; i < str.length; i += 1) {
      hash ^= str.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  function ensureHomeSeed() {
    var current = parseInt(document.documentElement.getAttribute(HOME_RANDOM_SEED_ATTR) || '', 10);
    if (Number.isFinite(current) && current > 0) return current >>> 0;
    var seed = Date.now() >>> 0;
    try {
      if (window.crypto && typeof window.crypto.getRandomValues === 'function') {
        var buf = new Uint32Array(1);
        window.crypto.getRandomValues(buf);
        seed = (buf[0] ^ Date.now()) >>> 0;
      }
    } catch (err) {
      seed = Date.now() >>> 0;
    }
    document.documentElement.setAttribute(HOME_RANDOM_SEED_ATTR, String(seed));
    return seed >>> 0;
  }

  function rngFor(label) {
    var seed = (ensureHomeSeed() ^ hashString(label)) >>> 0;
    return function () {
      seed += 0x6D2B79F5;
      var t = seed;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function shuffleArray(items, randomFn) {
    var arr = (items || []).slice();
    for (var i = arr.length - 1; i > 0; i -= 1) {
      var j = Math.floor((randomFn ? randomFn() : Math.random()) * (i + 1));
      var tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  function directChildren(node, selector) {
    if (!node) return [];
    var children = Array.prototype.slice.call(node.children || []);
    if (!selector) return children;
    return children.filter(function (child) {
      return !!(child && child.matches && child.matches(selector));
    });
  }

  function numericFromText(value) {
    var text = String(value || '').replace(/\./g, '').replace(/,/g, '.');
    var matches = text.match(/-?\d+(?:\.\d+)?/g);
    if (!matches || !matches.length) return 0;
    var num = parseFloat(matches[matches.length - 1]);
    return Number.isFinite(num) ? num : 0;
  }

  function metricsFromDealCard(card) {
    var sold = 0;
    var available = 0;
    allNodes(card, 'p,span,div,li,strong,b').forEach(function (node) {
      var text = textContentOf(node);
      var normalized = normalizeText(text);
      if (!text) return;
      if (normalized.indexOf('vendut') !== -1 || normalized.indexOf('sold') !== -1) {
        sold = Math.max(sold, numericFromText(text));
      }
      if (normalized.indexOf('disponibil') !== -1 || normalized.indexOf('available') !== -1) {
        available = Math.max(available, numericFromText(text));
      }
    });
    return { sold: sold, available: available };
  }

  function ensureDealProgressBars() {
    if (!isHomePage()) return;
    allNodes(document.body, '.card-product, .ks-deal-card').forEach(function (card) {
      if (!card || card.getAttribute('data-ks-deal-progress') === '1') return;
      var metrics = metricsFromDealCard(card);
      if ((metrics.sold + metrics.available) <= 0) {
        if (!firstNode(card, '.progress-sold, .progress')) return;
      }
      var total = metrics.sold + metrics.available;
      var percent = total > 0 ? Math.max(0, Math.min(100, Math.round((metrics.sold / total) * 100))) : 0;
      var progressWrap = firstNode(card, '.product-progress-sale, .box-quantity') || card;
      var progress = firstNode(card, '.progress-sold, .progress');
      if (!progress) {
        progress = document.createElement('div');
        progress.className = 'progress-sold progress';
        progress.setAttribute('role', 'progressbar');
        progress.setAttribute('aria-valuemin', '0');
        progress.setAttribute('aria-valuemax', '100');
        progressWrap.insertBefore(progress, progressWrap.firstChild || null);
      }
      var bar = firstNode(progress, '.progress-bar');
      if (!bar) {
        bar = document.createElement('div');
        bar.className = 'progress-bar bg-primary';
        progress.appendChild(bar);
      }
      progress.setAttribute('aria-valuenow', String(percent));
      bar.style.width = percent + '%';
      bar.setAttribute('data-ks-progress', String(percent));
      card.setAttribute('data-ks-deal-progress', '1');
    });
  }

  function primaryContentRect() {
    var shell = homeHeroShell();
    var shellRect = rectOf(shell);
    if (shellRect && shellRect.width >= Math.max((window.innerWidth || 0) * 0.45, 420)) {
      return shellRect;
    }

    var shellContainer = shell ? closestElement(shell, '.container, .container-fluid, .row') : null;
    var shellContainerRect = rectOf(shellContainer);
    if (shellContainerRect && shellContainerRect.width >= Math.max((window.innerWidth || 0) * 0.45, 420)) {
      return shellContainerRect;
    }

    var candidates = allNodes(document, 'main .container, section .container, .tf-sp-5 .container, .tf-sp-2 .container, .container');
    for (var i = 0; i < candidates.length; i += 1) {
      var node = candidates[i];
      var rect = rectOf(node);
      if (!rect || rect.width < Math.max((window.innerWidth || 0) * 0.45, 420)) continue;
      if (firstNode(node, '.s-banner-wrapper, .ks-home-hero-shell, .card-product, .product-list-wrap, .menu-category-list, .swiper')) {
        return rect;
      }
    }

    return rectOf(firstNode(document, '.container'));
  }

  function isMarginRailCandidate(node) {
    if (!node || node === document.body) return false;
    if (hardProtectedAncestor(node) || isLikelyUiUtility(node) || isCoreHeaderFooterChrome(node)) return false;
    var rect = rectOf(node);
    if (!rect || rect.width < 20 || rect.height < 40) return false;
    if (rect.width > 260 || rect.height > 2400) return false;
    var lane = primaryContentRect();
    var outsideLane = lane ? (rect.right <= (lane.left - 8) || rect.left >= (lane.right + 8)) : false;
    if (!outsideLane && !isNarrowEdgeRect(rect) && !floatingSideZone(rect)) return false;
    var style = computedStyleOf(node);
    var text = normalizeText(textContentOf(node));
    var media = mediaCountOf(node);
    var tall = (rect.height / Math.max(rect.width, 1)) >= 1.2;
    if (!tall) return false;
    if (firstNode(node, 'input, textarea, select, form')) return false;
    if (nodeContainsBlockedCreative(node)) return true;
    if (isVerticalWritingStyle(style)) return true;
    if (media >= 1 && rect.width <= 220) return true;
    if (text.length > 0 && text.length <= 140) return true;
    return false;
  }

  function sweepMarginRails() {
    if (!isHomePage() || !document.body) return;
    allNodes(document.body, 'div, aside, section, a, span, p, img, picture').forEach(function (node) {
      if (!isMarginRailCandidate(node)) return;
      hideNode(edgeCreativeRoot(node), 'data-ks-home-artifact');
    });
  }

  function sideRailColumnRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;
    var lane = primaryContentRect();

    while (current && current.parentElement && hops < 10) {
      var parent = current.parentElement;
      if (hardProtectedAncestor(parent) || isLikelyUiUtility(parent) || isCoreHeaderFooterChrome(parent)) break;
      var rect = rectOf(parent);
      if (!rect) break;
      var outsideLane = lane ? (rect.right <= (lane.left - 4) || rect.left >= (lane.right + 4)) : (isNarrowEdgeRect(rect) || floatingSideZone(rect));
      if (!outsideLane) break;
      if (rect.width > 260 || rect.height > 3200) break;
      best = parent;
      current = parent;
      hops += 1;
    }

    return best;
  }

  function isAggressiveRailCandidate(node) {
    if (!node || node === document.body) return false;
    if (hardProtectedAncestor(node) || isLikelyUiUtility(node) || isCoreHeaderFooterChrome(node)) return false;
    var rect = rectOf(node);
    if (!rect || rect.width < 18 || rect.height < 40) return false;
    if (rect.width > 260 || rect.height > 3200) return false;

    var lane = primaryContentRect();
    var outsideLane = lane ? (rect.right <= (lane.left - 4) || rect.left >= (lane.right + 4)) : (isNarrowEdgeRect(rect) || floatingSideZone(rect));
    if (!outsideLane) return false;

    var style = computedStyleOf(node);
    if (firstNode(node, 'input, textarea, select, button, form, iframe[src*="youtube"], iframe[src*="vimeo"]')) return false;

    var media = mediaCountOf(node);
    var text = normalizeText(textContentOf(node));
    var tall = (rect.height / Math.max(rect.width, 1)) >= 1.05;
    var narrow = rect.width <= 220;
    var blocked = nodeContainsBlockedCreative(node);
    var vertical = isVerticalWritingStyle(style);
    var linkCount = allNodes(node, 'a[href]').length;

    if (blocked || vertical) return true;
    if (media >= 3 && narrow) return true;
    if (media >= 2 && tall) return true;
    if (media >= 1 && narrow && text.length <= 48) return true;
    if (backgroundImageOf(node) && tall && narrow) return true;
    if (linkCount >= 3 && media >= 2 && narrow) return true;
    return false;
  }

  function sweepSideRailColumns() {
    if (!isHomePage() || !document.body) return;
    var seen = [];
    allNodes(document.body, 'div, aside, section, ul, li, a, picture, img, span, p').forEach(function (node) {
      if (!isAggressiveRailCandidate(node)) return;
      var root = sideRailColumnRoot(node);
      if (!root || seen.indexOf(root) !== -1) return;
      seen.push(root);
      hideNode(root, 'data-ks-home-artifact');
    });
  }

  function swiperWrapperLooksProductive(wrapper) {
    if (!wrapper) return false;
    if (firstNode(wrapper, '.card-product, .ks-card-product, .ks-row-card, .ks-grid-card, .ks-big-card, .ks-deal-card')) return true;
    return !!firstNode(wrapper, 'a[href*="articolo.aspx"], a[href*="/articolo.aspx"], a[href*="articoli.aspx"]');
  }

  function shuffleChildrenOnce(container, selector, seedLabel) {
    if (!container) return;
    var seed = String(ensureHomeSeed());
    if (container.getAttribute('data-ks-shuffle-seed') === seed) return;
    var items = directChildren(container, selector);
    if (items.length < 2) {
      container.setAttribute('data-ks-shuffle-seed', seed);
      return;
    }
    var shuffled = shuffleArray(items, rngFor(seedLabel));
    shuffled.forEach(function (item) { container.appendChild(item); });
    container.setAttribute('data-ks-shuffle-seed', seed);
  }

  function randomizeSwipers() {
    if (!isHomePage()) return;
    allNodes(document.body, '.swiper-wrapper').forEach(function (wrapper, index) {
      if (!swiperWrapperLooksProductive(wrapper)) return;
      var slides = directChildren(wrapper, '.swiper-slide');
      if (slides.length < 2) return;
      var hostSwiper = closestElement(wrapper, '.swiper');
      var hasDuplicates = slides.some(function (slide) {
        return slide.classList && slide.classList.contains('swiper-slide-duplicate');
      });
      if (!hasDuplicates) {
        shuffleChildrenOnce(wrapper, '.swiper-slide', 'swiper-' + index);
      }
      if (hostSwiper && hostSwiper.swiper) {
        try {
          hostSwiper.swiper.update();
          var realCount = directChildren(wrapper, '.swiper-slide:not(.swiper-slide-duplicate)').length || slides.length;
          if (realCount > 1) {
            var target = Math.floor(rngFor('swiper-target-' + index)() * realCount);
            if (hostSwiper.swiper.params && hostSwiper.swiper.params.loop && typeof hostSwiper.swiper.slideToLoop === 'function') {
              hostSwiper.swiper.slideToLoop(target, 0, false);
            } else if (typeof hostSwiper.swiper.slideTo === 'function') {
              hostSwiper.swiper.slideTo(target, 0, false);
            }
          }
        } catch (err) {}
      }
    });
  }

  function randomizeProductLists() {
    if (!isHomePage()) return;
    allNodes(document.body, '.product-list-wrap').forEach(function (list, index) {
      if (closestElement(list, '.ks-home-departments')) return;
      shuffleChildrenOnce(list, 'li', 'plist-' + index);
    });
  }

  function activateTabLink(link, pane, links, panes) {
    links.forEach(function (node) {
      node.classList.remove('active', 'show');
      node.setAttribute('aria-selected', node === link ? 'true' : 'false');
    });
    panes.forEach(function (node) {
      node.classList.remove('active', 'show');
    });
    if (link) link.classList.add('active', 'show');
    if (pane) pane.classList.add('active', 'show');
  }

  function randomizeMainTabs() {
    if (!isHomePage()) return;
    allNodes(document.body, '.flat-animate-tab').forEach(function (section, index) {
      var seed = String(ensureHomeSeed());
      if (section.getAttribute('data-ks-tab-seed') === seed) return;
      var links = allNodes(section, '.menu-tab-line [data-bs-toggle="tab"], .menu-tab-line .tab-link');
      var panes = allNodes(section, '.tab-content > .tab-pane');
      if (links.length < 2 || panes.length < 2) {
        section.setAttribute('data-ks-tab-seed', seed);
        return;
      }
      var eligible = [];
      links.forEach(function (link) {
        var href = link.getAttribute('href') || link.getAttribute('data-bs-target') || '';
        var pane = href ? firstNode(section, href) : null;
        if (pane && allNodes(pane, '.card-product, .ks-card-product, .product-list-wrap li').length > 0) {
          eligible.push({ link: link, pane: pane });
        }
      });
      if (!eligible.length) {
        section.setAttribute('data-ks-tab-seed', seed);
        return;
      }
      var choice = eligible[Math.floor(rngFor('tabs-' + index)() * eligible.length)];
      activateTabLink(choice.link, choice.pane, links, panes);
      section.setAttribute('data-ks-tab-seed', seed);
    });
  }

  function selectRandomBigCardImage() {
    if (!isHomePage()) return;
    allNodes(document.body, '.card-product.style-thums-2').forEach(function (card, index) {
      var seed = String(ensureHomeSeed());
      if (card.getAttribute('data-ks-gallery-seed') === seed) return;
      var thumbsSwiper = firstNode(card, '.tf-product-view-thumbs');
      var mainSwiper = firstNode(card, '.tf-product-view-main');
      var thumbs = allNodes(card, '.tf-product-view-thumbs .swiper-slide, .list-image-product .image-swap');
      if (!thumbs.length) {
        card.setAttribute('data-ks-gallery-seed', seed);
        return;
      }
      var target = Math.floor(rngFor('big-gallery-' + index)() * thumbs.length);
      if (mainSwiper && mainSwiper.swiper && typeof mainSwiper.swiper.slideTo === 'function') {
        try { mainSwiper.swiper.slideTo(target, 0, false); } catch (err) {}
      }
      if (thumbsSwiper && thumbsSwiper.swiper && typeof thumbsSwiper.swiper.slideTo === 'function') {
        try { thumbsSwiper.swiper.slideTo(target, 0, false); } catch (err) {}
      }
      card.setAttribute('data-ks-gallery-seed', seed);
    });
  }

  function alignCollectionActionButtons() {
    if (!isHomePage()) return;
    allNodes(document.body, '.flat-animate-tab .card-product').forEach(function (card) {
      if (!card || card.getAttribute('data-ks-actions-aligned') === '1') return;
      var info = firstNode(card, '.card-product-info');
      var actionList = firstNode(card, '.list-product-btn');
      var price = firstNode(info, '.price-wrap');
      if (!info || !actionList || !price) return;
      var group = firstNode(info, '.group-btn');
      if (!group) {
        group = document.createElement('div');
        group.className = 'group-btn';
        price.parentNode.insertBefore(group, price);
      }
      if (price.parentNode !== group) {
        group.insertBefore(price, group.firstChild || null);
      }
      if (actionList.parentNode !== group) {
        group.appendChild(actionList);
      }
      actionList.classList.add('ks-actions-inline');
      card.setAttribute('data-ks-actions-aligned', '1');
    });
  }

  function randomizeHomeContent() {
    if (!isHomePage()) return;
    ensureHomeSeed();
    randomizeProductLists();
    randomizeSwipers();
    randomizeMainTabs();
    selectRandomBigCardImage();
  }

  function runHomeRuntimeSweep() {
    ensureHomeGuardCss();
    bindMarketplaceSearch();
    repairFooterBranding();

    if (!isHomePage()) return;

    disableTemplatePopupStorage();
    suppressNewsletterPopup();
    sanitizeHomeMenu();
    bindHomeMenu();
    sweepHeroShellArtifacts();
    sweepTokenizedEdgeCreatives();
    sweepRepeatedEdgeDevices();
    sweepFloatingEdgeArtifacts();
    sweepEdgeLaneVisuals();
    sweepViewportArtifacts();
    sweepGenericFixedRails();
    sweepMarginRails();
    sweepSideRailColumns();
    hideStickyHeaderReplicas();
    hideDuplicateHeaderClones();
    syncHomeShell();
    ensureDealProgressBars();
    alignCollectionActionButtons();
    randomizeHomeContent();
    pruneOrphanHomeFragments();
    clearStaleUiLock();
  }

  function armHomeRuntimeSweep() {
    bindMarketplaceSearch();
    if (!isHomePage()) return;

    HOME_SWEEP_TIMERS.forEach(function (delay) {
      window.setTimeout(runHomeRuntimeSweep, delay);
    });

    if (!document.body || typeof MutationObserver === 'undefined') return;

    var ticking = false;
    var observer = new MutationObserver(function () {
      if (ticking) return;
      ticking = true;
      window.setTimeout(function () {
        ticking = false;
        runHomeRuntimeSweep();
      }, 80);
    });

    observer.observe(document.body, { childList: true, subtree: true });
    window.setTimeout(function () {
      observer.disconnect();
    }, 42000);
  }

  function applyHomeFlags() {
    if (!isHomePage()) return;
    addBodyClass('ks-page-home');
    if (readMergedRecent().length >= 2) {
      addBodyClass('ks-has-recent-history');
    }
  }

  window.KSRecent = {
    read: readMergedRecent,
    add: updateRecentList
  };

  ensureHomeGuardCss();
  disableTemplatePopupStorage();

  onReady(function () {
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }

    applyHomeFlags();
    bindMarketplaceSearch();
    repairFooterBranding();
    runHomeRuntimeSweep();
    armHomeRuntimeSweep();
    window.addEventListener('load', function () { repairFooterBranding(); runHomeRuntimeSweep(); }, { once: true });
    window.addEventListener('resize', runHomeRuntimeSweep);
  });
})();


(function () {
  'use strict';

  var SEARCH_ENDPOINT = '/search_suggest.aspx';
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  var STYLE_ID = 'ks-marketplace-step16';
  var UI_LANG_KEY = 'ks_ui_lang';
  var SEARCH_HINTS = ['cerca', 'search', 'ean', 'codic', 'prodot', 'articol', 'sku'];
  var ALL_HINTS = ['tutti', 'all', 'all departments', 'all categories', 'tutti i settori'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function all(root, sel) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function first(root, sel) { return (root || document).querySelector(sel); }
  function text(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function norm(v) {
    var s = String(v || '').toLowerCase();
    try { s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (err) {}
    return s.replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function rect(node) { try { return node && node.getBoundingClientRect ? node.getBoundingClientRect() : null; } catch (err) { return null; } }
  function isHome() { return /(^|\/)default\.aspx$/i.test(location.pathname || '') || location.pathname === '/' || location.pathname === ''; }
  function isArticle() { return /\/articolo\.aspx$/i.test(location.pathname || ''); }
  function currentLang() {
    var q = new URLSearchParams(location.search || '').get('lang');
    if (q) return q.toLowerCase();
    try { return (localStorage.getItem(UI_LANG_KEY) || 'it').toLowerCase(); } catch (err) { return 'it'; }
  }
  function setLang(code) { try { localStorage.setItem(UI_LANG_KEY, code); } catch (err) {} applyUiLanguage(code); }
  function fetchJson(url) {
    return fetch(url, { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function readRecentIds() {
    if (window.KSRecent && typeof window.KSRecent.read === 'function') return window.KSRecent.read() || [];
    var m = document.cookie.match(/(?:^|; )ks_recent=([^;]*)/);
    if (!m) return [];
    return decodeURIComponent(m[1]).split(',').map(function (v) { return parseInt(v, 10); }).filter(function (v) { return v > 0; });
  }
  function parseArticleId(href) {
    var m = String(href || '').match(/[?&]id=(\d+)/i);
    return m ? parseInt(m[1], 10) : 0;
  }
  function ensureCss() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      '.ks-suggest{position:absolute;left:0;right:0;top:calc(100% + 10px);z-index:140;background:#fff;border:1px solid #edf1f5;border-radius:18px;box-shadow:0 18px 48px rgba(15,23,42,.14);padding:8px;display:none;max-height:460px;overflow:auto;}',
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
      '.ks-search-host{position:relative!important;}',
      '.ks-top-catalog-mega{position:absolute;left:0;top:calc(100% + 12px);z-index:220;width:min(1180px,calc(100vw - 32px));padding:22px 24px;background:#fff;border:1px solid #edf1f5;border-radius:20px;box-shadow:0 18px 48px rgba(15,23,42,.14);display:none;}',
      '.ks-top-catalog-mega.is-open{display:block;}',
      '.ks-top-catalog-open .ks-home-departments,.ks-top-catalog-open .wrap-item-2,.ks-top-catalog-open .wrap-item-3{position:relative;z-index:0;}',
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
      '.ks-mobile-catalog-block{margin-top:18px;padding-top:14px;border-top:1px solid #edf1f5;}',
      '.ks-mobile-catalog-block details{border:1px solid #edf1f5;border-radius:14px;padding:0 14px;margin-bottom:10px;background:#fff;}',
      '.ks-mobile-catalog-block summary{list-style:none;cursor:pointer;padding:14px 0;font-size:15px;font-weight:700;color:#111827;display:flex;align-items:center;justify-content:space-between;gap:10px;}',
      '.ks-mobile-catalog-block summary::-webkit-details-marker{display:none;}',
      '.ks-mobile-catalog-block .ks-mobile-catalog-body{padding:0 0 14px;display:grid;gap:12px;}',
      '.ks-mobile-catalog-block .ks-mobile-catalog-cat{display:grid;gap:6px;}',
      '.ks-mobile-catalog-block .ks-mobile-catalog-cat>a{font-size:13px;font-weight:700;text-transform:uppercase;color:#ef4444;text-decoration:none;}',
      '.ks-mobile-catalog-block .ks-mobile-catalog-tips{list-style:none;margin:0;padding:0 0 0 10px;display:grid;gap:6px;}',
      '.ks-mobile-catalog-block .ks-mobile-catalog-tips a{font-size:14px;color:#1f2937;text-decoration:none;}',
      '.ks-onsus-font .card-product-info,.ks-onsus-font .card-product-info *,.ks-onsus-font .product-progress-sale,.ks-onsus-font .product-progress-sale *{font-family:"UTM Banque","MADE Outer",inherit!important;}',
      '.ks-onsus-tabs .card-product{position:relative;}',
      '.ks-onsus-tabs .card-product-info{display:flex;flex-direction:column;gap:12px;min-height:0;}',
      '.ks-onsus-tabs .group-btn{display:flex!important;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-top:8px;}',
      '.ks-onsus-tabs .group-btn .list-product-btn{display:flex!important;align-items:center;gap:10px;justify-content:flex-end;margin:0!important;padding:0!important;position:static!important;}',
      '.ks-onsus-tabs .group-btn .list-product-btn li{margin:0!important;}',
      '.ks-onsus-tabs .group-btn .box-icon{display:inline-flex!important;align-items:center;justify-content:center;}',
      '.ks-onsus-tabs .card-product.style-thums-2 .box-title{gap:14px!important;}',
      '.ks-onsus-tabs .card-product.style-thums-2 .name-product{display:block;position:relative;z-index:2;}',
      '.ks-onsus-tabs .card-product.style-thums-2 .card-product-info{padding-top:18px;}',
      '.ks-onsus-tabs .card-product.style-row .name-product,.ks-onsus-tabs .card-product.style-row .caption{display:block;position:relative;z-index:2;background:#fff;}',
      '.ks-chosen-section{margin:36px 0 22px;}',
      '.ks-chosen-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;}',
      '.ks-chosen-card{border:1px solid #edf1f5;border-radius:18px;background:#fff;padding:18px;display:grid;gap:12px;}',
      '.ks-chosen-thumb{height:180px;border-radius:14px;background:#f7f8fa;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ks-chosen-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-chosen-card h4{font-size:16px;line-height:1.35;margin:0;}',
      '.ks-chosen-meta{font-size:12px;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}',
      '.ks-chosen-price{font-size:18px;font-weight:700;color:#ef4444;}',
      '.ks-deal-runtime{margin-top:18px;}',
      '.ks-deal-runtime-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px;}',
      '.ks-deal-runtime-card{border:1px solid #e5e7eb;border-radius:18px;background:#fff;padding:18px;display:flex;flex-direction:column;gap:14px;min-width:0;}',
      '.ks-deal-runtime-media{border:1px solid #f0f2f5;border-radius:12px;background:#f8fafc;display:flex;align-items:center;justify-content:center;min-height:220px;overflow:hidden;}',
      '.ks-deal-runtime-media img{max-width:100%;max-height:220px;object-fit:contain;display:block;}',
      '.ks-deal-runtime-thumbs{display:flex;gap:8px;flex-wrap:nowrap;overflow:auto;padding-bottom:2px;}',
      '.ks-deal-runtime-thumb{width:48px;height:48px;min-width:48px;border:1px solid #e5e7eb;border-radius:10px;background:#fff;display:flex;align-items:center;justify-content:center;overflow:hidden;cursor:pointer;}',
      '.ks-deal-runtime-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ks-deal-runtime-thumb.is-active{border-color:#ef4444;box-shadow:0 0 0 1px #ef4444 inset;}',
      '.ks-deal-runtime-title{font-size:15px;line-height:1.45;font-weight:600;color:#17325c;text-decoration:none;display:block;min-height:44px;}',
      '.ks-deal-runtime-brand{font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:.04em;}',
      '.ks-deal-runtime-price{display:flex;align-items:flex-end;gap:10px;flex-wrap:wrap;}',
      '.ks-deal-runtime-price .new{font-size:18px;font-weight:700;color:#ef4444;}',
      '.ks-deal-runtime-price .old{font-size:14px;color:#6b7280;text-decoration:line-through;}',
      '.ks-deal-runtime-saving{display:block;height:10px;border-radius:999px;background:#fde2e2;overflow:hidden;}',
      '.ks-deal-runtime-saving > span{display:block;height:100%;background:#ff4a4a;border-radius:999px;width:0;}',
      '.ks-deal-runtime-stock{display:flex;justify-content:space-between;font-size:12px;color:#475569;gap:10px;}',
      '.ks-deal-runtime-count{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;}',
      '.ks-deal-runtime-count .b{display:grid;gap:4px;justify-items:center;padding:8px 4px;border-radius:999px;background:#f3f4f6;}',
      '.ks-deal-runtime-count .n{font-size:14px;font-weight:700;color:#374151;}',
      '.ks-deal-runtime-count .l{font-size:11px;color:#6b7280;}',
      '.ks-side-runtime-banners{display:flex;flex-direction:column;gap:18px;}',
      '.ks-side-runtime-banner{position:relative;display:block;border-radius:18px;overflow:hidden;background:#fff;min-height:160px;border:1px solid #edf1f5;}',
      '.ks-side-runtime-banner img{width:100%;height:100%;object-fit:cover;display:block;}',
      '.ks-side-runtime-banner .cap{position:absolute;inset:auto 16px 16px 16px;color:#fff;text-shadow:0 2px 12px rgba(0,0,0,.4);font-size:14px;font-weight:700;}',
      '.ks-hidden-rail{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}',
      '@media (max-width:1199.98px){.ks-top-catalog-mega{display:none!important;}.ks-suggest{left:-8px;right:-8px;}.ks-chosen-grid,.ks-deal-runtime-grid{grid-template-columns:repeat(2,minmax(0,1fr));}}',
      '@media (max-width:640px){.ks-chosen-grid,.ks-deal-runtime-grid,.ks-top-catalog-grid{grid-template-columns:1fr;}}'
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function looksLikeTextInput(input) {
    if (!input || input.type === 'hidden' || input.type === 'email' || input.type === 'password') return false;
    var raw = [input.name || '', input.id || '', input.className || '', input.getAttribute('placeholder') || '', input.getAttribute('aria-label') || ''].join(' ');
    var n = norm(raw);
    return SEARCH_HINTS.some(function (t) { return n.indexOf(t) !== -1; });
  }
  function searchRoots() {
    var header = first(document, 'header, .tf-header, .site-header') || document.body;
    var out = [];
    all(document, 'form, .form-search-product, .header-center, .search-wrap, .header-search, .search-area, .box-search').forEach(function (node) {
      var input = all(node, 'input[type="search"], input[type="text"], input:not([type])').filter(looksLikeTextInput)[0] || null;
      if (!input) return;
      var root = input.closest('.form-search-product, .search-wrap, .header-search, .search-area, .box-search, form') || node;
      if (!root || out.indexOf(root) !== -1) return;
      var rr = rect(root);
      if (rr && rr.top > 420 && !header.contains(root)) return;
      out.push(root);
    });
    return out;
  }
  function inputFromRoot(root) { return all(root, 'input[type="search"], input[type="text"], input:not([type])').filter(looksLikeTextInput)[0] || null; }
  function buttonsFromRoot(root) { return all(root, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon, a[href="#"][class*="search"], a.btn-submit-form'); }
  function selectedPseudoOption(root) {
    var sels = ['.select-options li.active', '.select-options li.selected', '.nice-select .option.selected', '.nice-select .current', '.select-selected', '[data-ks-selected="1"]'];
    for (var i = 0; i < sels.length; i += 1) { var n = first(root, sels[i]); if (n) return n; }
    return null;
  }
  function selectFromRoot(root) { return first(root, 'select, .dropdown_product_cat') || selectedPseudoOption(root); }
  function looksLikeAll(textv) { var n = norm(textv); return !n || ALL_HINTS.some(function (t) { return n.indexOf(norm(t)) !== -1; }); }
  function parseQueryParams(raw, params) {
    if (!raw) return;
    var cleaned = String(raw).replace(/^.*\?/, '');
    if (!cleaned) return;
    var qs = new URLSearchParams(cleaned);
    ['st', 'ct', 'tp', 'gr', 'sg', 'mr', 'pid', 'inpromo', 'q'].forEach(function (k) { var v = qs.get(k); if (v) params[k] = v; });
  }
  function readSelectTarget(root) {
    var result = { url: '', params: {} };
    var select = selectFromRoot(root);
    if (!select) return result;
    var rawValue = '';
    var label = '';
    if (select.options) {
      var option = select.selectedIndex >= 0 ? select.options[select.selectedIndex] : null;
      rawValue = option ? (option.value || option.getAttribute('data-url') || option.getAttribute('data-query') || option.getAttribute('rel') || '') : '';
      label = option ? (option.text || option.textContent || '') : '';
    } else {
      rawValue = select.getAttribute('data-url') || select.getAttribute('data-query') || select.getAttribute('data-value') || select.getAttribute('rel') || '';
      label = text(select);
    }
    if ((!rawValue || rawValue === '0') && root) {
      var pseudo = selectedPseudoOption(root);
      if (pseudo) {
        rawValue = rawValue || pseudo.getAttribute('data-url') || pseudo.getAttribute('data-query') || pseudo.getAttribute('data-value') || pseudo.getAttribute('rel') || '';
        label = label || text(pseudo);
      }
    }
    if (!rawValue || rawValue === '0' || looksLikeAll(label) || looksLikeAll(rawValue)) return result;
    if (/^(https?:)?\/\//i.test(rawValue) || /\.aspx(\?|$)/i.test(rawValue) || rawValue.charAt(0) === '/') {
      result.url = rawValue;
      parseQueryParams(rawValue, result.params);
      return result;
    }
    parseQueryParams(rawValue, result.params);
    if (Object.keys(result.params).length) return result;
    var kv = String(rawValue).match(/^(st|ct|tp|gr|sg|mr|pid)[:=|-](.+)$/i);
    if (kv) { result.params[kv[1].toLowerCase()] = kv[2]; return result; }
    var digits = String(rawValue).match(/(\d+)/);
    if (digits) result.params.st = digits[1];
    return result;
  }
  function searchValue(root) { var inp = inputFromRoot(root); return String(inp && inp.value || '').replace(/\s+/g, ' ').trim(); }
  function buildSearchUrl(root) {
    var q = searchValue(root);
    var target = readSelectTarget(root);
    var url;
    try { url = new URL(target.url || '/articoli.aspx', location.href); } catch (err) { url = new URL('/articoli.aspx', location.href); }
    Object.keys(target.params || {}).forEach(function (k) { if (target.params[k]) url.searchParams.set(k, target.params[k]); });
    if (q) url.searchParams.set('q', q); else url.searchParams.delete('q');
    ['page','pageindex','Pagina','p','rimuovi'].forEach(function (k) { url.searchParams.delete(k); });
    return (!q && !Object.keys(target.params || {}).length && !target.url) ? '' : url.toString();
  }
  function rankKey(url) {
    var txt = String(url || ''); var hash = 2166136261;
    for (var i = 0; i < txt.length; i += 1) { hash ^= txt.charCodeAt(i); hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24); }
    return 'ksrk:' + (hash >>> 0).toString(16);
  }
  function saveRank(key, data) { try { sessionStorage.setItem(key, JSON.stringify({ ids: data.rank_ids || [], query: data.query || '', at: Date.now() })); } catch (err) {} }
  function readRank(key) { try { var raw = sessionStorage.getItem(key); return raw ? JSON.parse(raw) : null; } catch (err) { return null; } }
  function buildSuggestUrl(root, query, limit, preferRecent) {
    var url = new URL(SEARCH_ENDPOINT, location.href);
    var target = readSelectTarget(root);
    Object.keys(target.params || {}).forEach(function (k) { if (target.params[k]) url.searchParams.set(k, target.params[k]); });
    if (query) url.searchParams.set('q', query);
    if (preferRecent) {
      var ids = readRecentIds();
      if (ids.length) url.searchParams.set('recent', ids.join(','));
    }
    url.searchParams.set('limit', String(limit || 8));
    return url.toString();
  }
  function state(root) {
    if (!root.__ksState) root.__ksState = { box: null, items: [], active: -1, hideTimer: 0, lastUrl: '' };
    return root.__ksState;
  }
  function ensureSuggestBox(root) {
    var s = state(root);
    if (s.box && s.box.parentNode) return s.box;
    root.classList.add('ks-search-host');
    var box = document.createElement('div');
    box.className = 'ks-suggest';
    box.setAttribute('aria-hidden', 'true');
    box.innerHTML = '<div class="ks-suggest-empty">Caricamento…</div>';
    box.addEventListener('mousedown', function (e) { e.preventDefault(); });
    root.appendChild(box);
    s.box = box;
    return box;
  }
  function hideSuggest(root) { var s = state(root); if (s.box) { s.box.classList.remove('is-open'); s.box.setAttribute('aria-hidden', 'true'); } s.active = -1; }
  function showSuggest(root) { var box = ensureSuggestBox(root); box.classList.add('is-open'); box.setAttribute('aria-hidden', 'false'); }
  function setActive(root, index) {
    var s = state(root), nodes = all(s.box, '.ks-suggest-item');
    if (!nodes.length) { s.active = -1; return; }
    if (index < 0) index = nodes.length - 1; if (index >= nodes.length) index = 0;
    s.active = index;
    nodes.forEach(function (n, i) { n.classList.toggle('is-active', i === index); });
    try { nodes[index].scrollIntoView({ block: 'nearest' }); } catch (err) {}
  }
  function openActive(root, idx) { var s = state(root), item = s.items[(idx >= 0 ? idx : s.active)]; if (!item || !item.url) return false; location.href = item.url; return true; }
  function renderSuggest(root, data) {
    var s = state(root), box = ensureSuggestBox(root); s.items = (data && data.suggestions) ? data.suggestions.slice() : []; s.active = -1;
    if (!s.items.length) { box.innerHTML = '<div class="ks-suggest-empty">Nessun suggerimento disponibile.</div>'; hideSuggest(root); return; }
    var html = [];
    if (data.recent) html.push('<div class="ks-suggest-head">Recenti</div>');
    html.push('<ul class="ks-suggest-list">');
    s.items.forEach(function (item, i) {
      var meta = [];
      if (item.brand) meta.push('<span>' + esc(item.brand) + '</span>');
      if (item.category) meta.push('<span>' + esc(item.category) + '</span>');
      html.push('<li><a href="' + esc(item.url || '#') + '" class="ks-suggest-item" data-ks-idx="' + i + '">');
      html.push('<span class="ks-suggest-thumb">' + ((item.image || item.image_fallback) ? ('<img src="' + esc(item.image || item.image_fallback || '') + '" data-fallback="' + esc(item.image_fallback || '') + '" alt="' + esc(item.title || '') + '"/>') : '') + '</span>');
      html.push('<span class="ks-suggest-meta"><span class="ks-suggest-title">' + esc(item.title || '') + '</span><span class="ks-suggest-sub">' + meta.join('') + '</span></span>');
      html.push('<span class="ks-suggest-price">' + (item.price ? ('€' + esc(item.price)) : '') + '</span>');
      html.push('</a></li>');
    });
    html.push('</ul>');
    box.innerHTML = html.join('');
    all(box, '.ks-suggest-thumb img').forEach(function (img) {
      img.addEventListener('error', function onErr() { img.removeEventListener('error', onErr); var fb = img.getAttribute('data-fallback') || ''; if (fb && img.src !== fb) img.src = fb; });
    });
    all(box, '.ks-suggest-item').forEach(function (link) {
      link.addEventListener('mouseenter', function () { setActive(root, parseInt(link.getAttribute('data-ks-idx') || '-1', 10)); });
      link.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); openActive(root, parseInt(link.getAttribute('data-ks-idx') || '-1', 10)); });
    });
    showSuggest(root);
  }
  function requestSuggest(root, forceRecent) {
    var q = searchValue(root); var preferRecent = !!forceRecent || q.length < 2; var url = buildSuggestUrl(root, q, preferRecent ? 8 : 10, preferRecent); var s = state(root); s.lastUrl = url;
    return fetchJson(url).then(function (data) { if (s.lastUrl !== url) return; if (!data || data.ok === false) { hideSuggest(root); return; } renderSuggest(root, data); }).catch(function () { hideSuggest(root); });
  }
  function resolveSearch(root) {
    var input = inputFromRoot(root); var fallback = buildSearchUrl(root); if (!fallback) { if (input && input.focus) input.focus(); return; }
    var q = searchValue(root); var url = buildSuggestUrl(root, q, 60, !q || q.length < 2);
    fetchJson(url).then(function (data) {
      if (data && data.strong && data.strong.canRedirect && data.strong.redirectUrl) { location.href = data.strong.redirectUrl; return; }
      var out = new URL(fallback, location.href);
      if (data && data.rank_ids && data.rank_ids.length) {
        var key = rankKey(out.pathname + '?' + out.searchParams.toString());
        saveRank(key, data); out.searchParams.set('ksrk', key);
      }
      location.href = out.toString();
    }).catch(function () { location.href = fallback; });
  }

  function ensureRuntimeSectionsCss() {
    if (document.getElementById('ks-runtime-sections-step18')) return;
    var style = document.createElement('style');
    style.id = 'ks-runtime-sections-step18';
    style.textContent = [
      "[data-ks-hidden-section='1']{display:none!important;}",
      ".ks-runtime-section{position:relative;z-index:4;}",
      ".ks-runtime-section .container{position:relative;}",
      ".ks-runtime-tabbed-section,.ks-runtime-best-section,.ks-runtime-lower-section{padding-top:24px;padding-bottom:8px;}",
      ".ks-runtime-tabs-head{display:flex;gap:22px;align-items:center;border-bottom:1px solid #e5e7eb;margin-bottom:18px;flex-wrap:wrap;}",
      ".ks-runtime-tab-btn{appearance:none;border:0;background:none;padding:0 0 14px;font-size:15px;line-height:1.2;font-weight:700;color:#111827;cursor:pointer;position:relative;}",
      ".ks-runtime-tab-btn.is-active{color:#ef4444;}",
      ".ks-runtime-tab-btn.is-active:after{content:'';position:absolute;left:0;right:0;bottom:-1px;height:2px;background:#ef4444;border-radius:2px;}",
      ".ks-runtime-panel{display:none;}",
      ".ks-runtime-panel.is-active{display:block;}",
      ".ks-runtime-tab-layout{display:grid;grid-template-columns:minmax(180px,250px) minmax(0,1fr) minmax(180px,320px);gap:24px;align-items:start;}",
      ".ks-runtime-side-col{display:grid;gap:18px;align-content:start;}",
      ".ks-runtime-side-card,.ks-runtime-grid-card{display:grid;grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}",
      ".ks-runtime-grid-card{grid-template-columns:1fr;gap:12px;padding:16px;align-items:start;}",
      ".ks-runtime-side-thumb,.ks-runtime-grid-thumb{height:94px;border-radius:14px;background:#f5f7fb;display:flex;align-items:center;justify-content:center;overflow:hidden;}",
      ".ks-runtime-grid-thumb{height:170px;}",
      ".ks-runtime-side-thumb img,.ks-runtime-grid-thumb img,.ks-runtime-big-media img,.ks-runtime-big-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}",
      ".ks-runtime-side-body,.ks-runtime-grid-body{display:grid;gap:6px;min-width:0;}",
      ".ks-runtime-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}",
      ".ks-runtime-title{font-size:15px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}",
      ".ks-runtime-side-card .ks-runtime-title{font-size:14px;}",
      ".ks-runtime-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}",
      ".ks-runtime-price .new{font-size:16px;color:#ef4444;}",
      ".ks-runtime-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}",
      ".ks-runtime-big-card{background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}",
      ".ks-runtime-big-main{display:grid;gap:16px;min-width:0;}",
      ".ks-runtime-big-media{height:420px;border-radius:18px;background:#f5f7fb;display:flex;align-items:center;justify-content:center;overflow:hidden;}",
      ".ks-runtime-big-thumbs{display:grid;gap:10px;align-content:start;}",
      ".ks-runtime-big-thumb{appearance:none;border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;cursor:pointer;}",
      ".ks-runtime-big-thumb.is-active{border-color:#111827;box-shadow:0 0 0 1px #111827 inset;}",
      ".ks-runtime-big-body{display:grid;gap:12px;min-width:0;}",
      ".ks-runtime-actions{display:flex;align-items:center;gap:10px;justify-content:flex-end;flex-wrap:wrap;margin:0;padding:0;list-style:none;}",
      ".ks-runtime-actions .box-icon{width:36px;height:36px;border-radius:999px;border:1px solid #e5e7eb;background:#fff;display:inline-flex;align-items:center;justify-content:center;color:#4b5563;text-decoration:none;}",
      ".ks-runtime-bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}",
      ".ks-runtime-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}",
      ".ks-runtime-two-col{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:28px;align-items:start;}",
      ".ks-runtime-two-col .ks-runtime-col-title{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}",
      ".ks-runtime-two-col .ks-runtime-col-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;}",
      ".ks-runtime-best-section .flat-title,.ks-runtime-lower-section .flat-title{margin-bottom:18px;}",
      ".ks-runtime-empty{display:none!important;}",
      "@media (max-width: 1199.98px){.ks-runtime-tab-layout{grid-template-columns:1fr;}.ks-runtime-side-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-runtime-big-card{grid-template-columns:1fr;}.ks-runtime-big-thumbs{grid-template-columns:repeat(4,64px);}.ks-runtime-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-runtime-two-col{grid-template-columns:1fr;}}",
      "@media (max-width: 767.98px){.ks-runtime-side-col,.ks-runtime-two-col .ks-runtime-col-grid{grid-template-columns:1fr;}.ks-runtime-grid{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-runtime-grid-thumb{height:140px;}.ks-runtime-big-media{height:280px;}.ks-runtime-tabs-head{gap:16px;}}"
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function bindSearch() {
    ensureCss();
    searchRoots().forEach(function (root) {
      if (!root || root.getAttribute('data-ks-suggest-bound') === '1') return;
      root.setAttribute('data-ks-suggest-bound', '1');
      ensureSuggestBox(root);
      var input = inputFromRoot(root);
      var buttons = buttonsFromRoot(root);
      var timer = 0;
      function queue(forceRecent) { clearTimeout(timer); timer = setTimeout(function () { requestSuggest(root, !!forceRecent); }, 170); }
      if (input) {
        input.setAttribute('autocomplete', 'off');
        input.addEventListener('input', function () { queue(false); });
        input.addEventListener('focus', function () { queue(true); });
        input.addEventListener('blur', function () { var s = state(root); clearTimeout(s.hideTimer); s.hideTimer = setTimeout(function () { hideSuggest(root); }, 180); });
        input.addEventListener('keydown', function (evt) {
          var s = state(root), open = !!(s.box && s.box.classList.contains('is-open'));
          if (evt.key === 'ArrowDown' && open) { evt.preventDefault(); setActive(root, s.active + 1); return; }
          if (evt.key === 'ArrowUp' && open) { evt.preventDefault(); setActive(root, s.active - 1); return; }
          if (evt.key === 'Escape') { hideSuggest(root); return; }
          if (evt.key === 'Enter') { evt.preventDefault(); evt.stopPropagation(); if (!(open && s.active >= 0 && openActive(root, s.active))) resolveSearch(root); }
        }, true);
      }
      if (root.tagName && root.tagName.toLowerCase() === 'form') {
        root.addEventListener('submit', function (evt) { evt.preventDefault(); evt.stopPropagation(); if (evt.stopImmediatePropagation) evt.stopImmediatePropagation(); resolveSearch(root); }, true);
      }
      buttons.forEach(function (b) { b.addEventListener('click', function (evt) { evt.preventDefault(); evt.stopPropagation(); if (evt.stopImmediatePropagation) evt.stopImmediatePropagation(); resolveSearch(root); }, true); });
    });
    if (document.documentElement.getAttribute('data-ks-suggest-doc') === '1') return;
    document.documentElement.setAttribute('data-ks-suggest-doc', '1');
    document.addEventListener('click', function (evt) { searchRoots().forEach(function (root) { if (!root.contains(evt.target)) hideSuggest(root); }); });
  }
  function applyRankingOnResults() {
    if (!/\/articoli\.aspx$/i.test(location.pathname || '')) return;
    var q = String(new URLSearchParams(location.search || '').get('q') || '').trim();
    if (!q) return;
    var key = String(new URLSearchParams(location.search || '').get('ksrk') || '');
    var cached = readRank(key);
    var ids = cached && cached.ids && cached.ids.length ? cached.ids : null;
    function cards() {
      var links = all(document, 'a[href*="articolo.aspx?id="]');
      var out = [], seen = {};
      links.forEach(function (link) {
        if (link.closest('header, footer, .ks-suggest, .ks-home-departments')) return;
        var id = parseArticleId(link.getAttribute('href') || ''); if (!id || seen[id]) return;
        seen[id] = 1; var node = link.closest('.card-product, .product-item, li, .col, .swiper-slide, .item, .grid-item, .box-product') || link;
        if (node && node.parentElement) out.push({ id: id, node: node, parent: node.parentElement });
      });
      return out;
    }
    function reorder(rankIds) {
      var c = cards(); if (!c.length) return;
      var counts = {}; c.forEach(function (item) { var k = item.parent; counts[k] = (counts[k] || 0) + 1; });
      var container = c[0].parent; var best = 0; c.forEach(function (item) { var cnt = 0; c.forEach(function (x) { if (x.parent === item.parent) cnt++; }); if (cnt > best) { best = cnt; container = item.parent; } });
      var map = {}; c.forEach(function (item) { if (item.parent === container) map[item.id] = item.node; });
      rankIds.forEach(function (id) { id = parseInt(id, 10); if (id && map[id]) container.appendChild(map[id]); });
    }
    if (ids) { reorder(ids); return; }
    var url = new URL(SEARCH_ENDPOINT, location.href); ['q','st','ct','tp','gr','sg','mr','pid','inpromo'].forEach(function (n) { var v = new URLSearchParams(location.search || '').get(n); if (v) url.searchParams.set(n, v); }); url.searchParams.set('limit','60');
    fetchJson(url.toString()).then(function (data) { if (data && data.rank_ids && data.rank_ids.length) reorder(data.rank_ids); }).catch(function () {});
  }
  function feed(mode, extra) {
    var url = new URL(FEED_ENDPOINT, location.href); url.searchParams.set('mode', mode); extra = extra || {}; Object.keys(extra).forEach(function (k) { if (extra[k] != null && extra[k] !== '') url.searchParams.set(k, extra[k]); });
    return fetchJson(url.toString()).catch(function () { return { ok: false }; });
  }
  function buildCatalogSectorHtml(sector) {
    var html = ['<div class="ks-top-catalog-sector"><div class="ks-top-catalog-sector-head"><span class="ks-top-catalog-sector-media">'];
    if (sector.image) html.push('<img src="' + esc(sector.image) + '" alt="' + esc(sector.title || '') + '"/>');
    html.push('</span><a class="ks-top-catalog-sector-title" href="' + esc(sector.url || 'articoli.aspx') + '">' + esc(sector.title || '') + '</a></div>');
    (sector.categories || []).slice(0, 4).forEach(function (category) {
      html.push('<div class="ks-top-catalog-category"><a class="ks-top-catalog-category-link" href="' + esc(category.url || sector.url || 'articoli.aspx') + '">' + esc(category.title || '') + '</a><ul class="ks-top-catalog-tips">');
      (category.tipologies || []).slice(0, 8).forEach(function (tip) { html.push('<li><a href="' + esc(tip.url || category.url || sector.url || 'articoli.aspx') + '">' + esc(tip.title || '') + '</a></li>'); });
      html.push('</ul></div>');
    });
    html.push('</div>'); return html.join('');
  }
  function findCatalogNavItem() {
    var candidates = all(document, 'header .nav-item, header li, .main-nav-menu li');
    for (var i = 0; i < candidates.length; i += 1) { var link = first(candidates[i], 'a, button'); if (!link) continue; var t = norm(text(link)); if (t === 'catalogo' || t.indexOf('catalog') !== -1) return candidates[i]; }
    return null;
  }
  function ensureCatalogMega() {
    if (window.innerWidth < 1200) return;
    var item = findCatalogNavItem(); if (!item || item.getAttribute('data-ks-catalog-mega') === '1') return;
    feed('menu').then(function (data) {
      if (!data || data.ok === false || !data.menu || !data.menu.length || item.getAttribute('data-ks-catalog-mega') === '1') return;
      item.style.position = 'relative';
      var panel = document.createElement('div'); panel.className = 'ks-top-catalog-mega'; panel.innerHTML = '<div class="ks-top-catalog-grid">' + data.menu.slice(0,8).map(buildCatalogSectorHtml).join('') + '</div>'; item.appendChild(panel); item.setAttribute('data-ks-catalog-mega','1');
      function position() {
        var container = first(document, 'header .container') || first(document, '.header-bottom .container') || first(document, '.container');
        if (!container) return;
        var cr = rect(container); var ir = rect(item); if (!cr || !ir) return;
        panel.style.left = Math.round(cr.left - ir.left) + 'px';
        panel.style.width = Math.round(cr.width) + 'px';
        panel.style.maxWidth = Math.round(cr.width) + 'px';
      }
      function open() { position(); panel.classList.add('is-open'); document.body && document.body.classList.add('ks-top-catalog-open'); }
      function close() { panel.classList.remove('is-open'); document.body && document.body.classList.remove('ks-top-catalog-open'); }
      item.addEventListener('mouseenter', open); item.addEventListener('mouseleave', close); item.addEventListener('focusin', open); item.addEventListener('focusout', function () { setTimeout(function () { if (!item.contains(document.activeElement)) close(); }, 40); }); document.addEventListener('click', function (evt) { if (!item.contains(evt.target)) close(); }); window.addEventListener('resize', position); window.addEventListener('scroll', function(){ if(panel.classList.contains('is-open')) position(); }, { passive:true });
    });
  }
  function ensureMobileCatalog() {
    var host = first(document, '#mobileMenu .offcanvas-body, .mobile-menu .offcanvas-body, .mobileMenu .offcanvas-body, .mobile-menu-body, .menu-mobile-content');
    if (!host || host.getAttribute('data-ks-mobile-catalog') === '1') return;
    feed('menu').then(function (data) {
      if (!data || data.ok === false || !data.menu || !data.menu.length || host.getAttribute('data-ks-mobile-catalog') === '1') return;
      var wrapper = document.createElement('div');
      wrapper.className = 'ks-mobile-catalog-block';
      wrapper.innerHTML = '<h6>Catalogo</h6>' + data.menu.slice(0, 12).map(function (sector) {
        var body = [];
        (sector.categories || []).slice(0, 5).forEach(function (category) {
          body.push('<div class="ks-mobile-catalog-cat"><a href="' + esc(category.url || sector.url || 'articoli.aspx') + '">' + esc(category.title || '') + '</a><ul class="ks-mobile-catalog-tips">' + (category.tipologies || []).slice(0, 8).map(function (tip) { return '<li><a href="' + esc(tip.url || category.url || sector.url || 'articoli.aspx') + '">' + esc(tip.title || '') + '</a></li>'; }).join('') + '</ul></div>');
        });
        return '<details><summary><span>' + esc(sector.title || '') + '</span><span>›</span></summary><div class="ks-mobile-catalog-body">' + body.join('') + '</div></details>';
      }).join('');
      host.appendChild(wrapper); host.setAttribute('data-ks-mobile-catalog','1');
    });
  }
  function applyUiLanguage(code) {
    code = (code || 'it').toLowerCase();
    var map = code.indexOf('en') === 0 ? {
      'Tutti i settori':'All departments','Catalogo':'Catalog','Contatti':'Contact','Offerte':'On Sale','In Evidenza':'Featured','Nuovi Arrivi':'New Arrivals','Occasione Imperdibile':'Deal Of The Day','Rivenditori Ufficiali - I migliori Brand':'Official Resellers - Best Brands','Scelti per te':'Chosen for you','Scopri ora':'Shop now','Collezione reparto':'Department collection','Cerca prodotti, codici o EAN':'Search products, codes or EAN','Assistenza':'Support','Il mio account':'My account','Italiano':'English','Spedizione veloce':'Fast delivery','Supporto dedicato':'Dedicated support','Pagamenti sicuri':'Secure payments','Affidabilità reale':'Trusted availability','Garanzia e resi':'Warranty and returns'
    } : {};
    all(document, '[data-ks-i18n]').forEach(function (node) {
      var key = String(node.getAttribute('data-ks-i18n') || '');
      if (code.indexOf('en') === 0) {
        var source = text(node); if (map[source]) node.textContent = map[source];
      }
    });
    if (code.indexOf('en') === 0) {
      all(document, '.title, h1, h2, h3, h4, h5, h6, a, p, span').forEach(function (node) {
        var t = text(node); if (map[t]) node.textContent = map[t];
      });
      var input = first(document, '.form-search-product input[type="text"], .form-search-product input[type="search"]');
      if (input) input.setAttribute('placeholder', 'Search products, codes or EAN');
      document.documentElement.setAttribute('lang', 'en');
    } else {
      document.documentElement.setAttribute('lang', 'it');
    }
  }
  function restoreLanguageSelector() {
    feed('languages').then(function (data) {
      var langs = (data && data.languages) ? data.languages : [{code:'it',title:'Italiano'},{code:'en',title:'English'}];
      var selects = all(document, 'select.type-lan, .tf-languages select, .bar-lang select');
      selects.forEach(function (select) {
        if (!select || select.getAttribute('data-ks-lang-ready') === '1') return;
        select.innerHTML = langs.map(function (lang) { return '<option value="' + esc(lang.code) + '">' + esc(lang.title) + '</option>'; }).join('');
        select.value = currentLang();
        select.addEventListener('change', function () { setLang(select.value || 'it'); });
        select.setAttribute('data-ks-lang-ready', '1');
      });
      applyUiLanguage(currentLang());
    });
  }
  function validSideBannerCount() {
    var wrap = first(document, '.wrap-item-3'); if (!wrap) return 0;
    return all(wrap, 'a img, img').filter(function (img) { var r = rect(img); return img.offsetParent !== null && r && r.width >= 120 && r.height >= 80; }).length;
  }
  function ensureSideBanners() {
    if (!isHome()) return;
    var wrap = first(document, '.wrap-item-3'); if (!wrap) return;
    if (validSideBannerCount() >= 2) return;
    feed('banners').then(function (data) {
      var banners = (data && data.banners) ? data.banners.filter(function (b) { return b && b.image; }) : [];
      if (!banners.length) return;
      wrap.innerHTML = '<div class="ks-side-runtime-banners">' + banners.slice(0,2).map(function (b) {
        return '<a class="ks-side-runtime-banner" href="' + esc(b.url || '#') + '" target="' + esc(b.target || '') + '"><img src="' + esc(b.image) + '" alt="' + esc(b.title || '') + '"/><span class="cap">' + esc(b.title || '') + '</span></a>';
      }).join('') + '</div>';
      wrap.style.display = '';
    });
  }
  function renderChosenForYou() {
    if (!isHome()) return;
    if (first(document, '.ks-chosen-section')) return;
    var ids = readRecentIds(); if (!ids || ids.length < 2) return;
    var anchor = first(document, 'h5, h4, h3');
    var bestTitle = all(document, 'h1,h2,h3,h4,h5,h6').find(function (n) { var t = norm(text(n)); return t.indexOf('best seller') !== -1 || t.indexOf('top 20') !== -1; }) || null;
    var mount = bestTitle ? bestTitle.closest('section, .tf-sp-2, .container') : null;
    if (!mount || !mount.parentNode) return;
    feed('products', { ids: ids.slice(0, 6).join(',') }).then(function (data) {
      var items = (data && data.products) ? data.products : [];
      if (items.length < 2) return;
      var section = document.createElement('section');
      section.className = 'ks-chosen-section ks-onsus-font';
      section.innerHTML = '<div class="container"><div class="flat-title"><h5 class="fw-semibold">Scelti per te</h5></div><div class="ks-chosen-grid">' + items.slice(0,4).map(function (item) {
        return '<a class="ks-chosen-card" href="' + esc(item.url || '#') + '"><span class="ks-chosen-thumb"><img src="' + esc(item.preview || item.image || '') + '" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '"/></span><span class="ks-chosen-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></span><h4>' + esc(item.title || '') + '</h4><span class="ks-chosen-price">' + (item.price ? ('€' + esc(item.price)) : '') + '</span></a>';
      }).join('') + '</div></div>';
      mount.parentNode.insertBefore(section, mount);
      all(section, 'img[data-fallback]').forEach(function (img) { img.addEventListener('error', function onErr() { img.removeEventListener('error', onErr); var fb = img.getAttribute('data-fallback') || ''; if (fb && img.src !== fb) img.src = fb; }); });
      if (currentLang().indexOf('en') === 0) applyUiLanguage('en');
    });
  }
  function renderCountdown(target, endDate) {
    if (!target) return;
    var end = endDate ? new Date(endDate + 'T23:59:59') : null;
    function tick() {
      var diff = end ? Math.max(0, end.getTime() - Date.now()) : 0;
      var d = Math.floor(diff / 86400000); diff -= d * 86400000;
      var h = Math.floor(diff / 3600000); diff -= h * 3600000;
      var m = Math.floor(diff / 60000); diff -= m * 60000;
      var s = Math.floor(diff / 1000);
      var values = [d,h,m,s];
      all(target, '.n').forEach(function (n, i) { if (values[i] != null) n.textContent = String(values[i]).padStart(2,'0'); });
    }
    tick(); if (end) setInterval(tick, 1000);
  }
  function buildDealCard(item, idx) {
    var images = Array.isArray(item.images) ? item.images : [];
    var preview = item.preview || item.image || images[0] || '';
    if (images.length && preview && images[0] !== preview) images = [preview].concat(images);
    var thumbs = (images.length ? images : [preview]).slice(0,5);
    var sold = parseInt(item.sold || 0, 10) || 0; var avail = parseInt(item.available || 0, 10) || 0; var pct = (sold + avail) > 0 ? Math.round((sold / (sold + avail)) * 100) : 0;
    return '<div class="ks-deal-runtime-card" data-idx="' + idx + '">' +
      '<a class="ks-deal-runtime-media" href="' + esc(item.url || '#') + '"><img src="' + esc(preview || '') + '" alt="' + esc(item.title || '') + '" data-main="1" data-fallback="' + esc(item.image || '') + '"/></a>' +
      '<div class="ks-deal-runtime-thumbs">' + thumbs.map(function (img, i) { return '<button type="button" class="ks-deal-runtime-thumb' + (i === 0 ? ' is-active' : '') + '" data-img="' + esc(img) + '"><img src="' + esc(img) + '" alt=""/></button>'; }).join('') + '</div>' +
      '<div class="ks-deal-runtime-brand">' + esc(item.brand || '') + '</div>' +
      '<a class="ks-deal-runtime-title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' +
      '<div class="ks-deal-runtime-price"><span class="new">' + (item.price ? ('€' + esc(item.price)) : '') + '</span>' + (item.oldPrice ? ('<span class="old">€' + esc(item.oldPrice) + '</span>') : '') + '</div>' +
      '<span class="ks-deal-runtime-saving"><span style="width:' + pct + '%"></span></span>' +
      '<div class="ks-deal-runtime-count"><span class="b"><span class="n">00</span><span class="l">Giorni</span></span><span class="b"><span class="n">00</span><span class="l">Ore</span></span><span class="b"><span class="n">00</span><span class="l">Min</span></span><span class="b"><span class="n">00</span><span class="l">Sec</span></span></div>' +
      '<div class="ks-deal-runtime-stock"><span>Venduti: ' + sold + '</span><span>Disponibili: ' + avail + '</span></div>' +
      '</div>';
  }
  function renderDeals() {
    if (!isHome()) return;
    var title = all(document, 'h1,h2,h3,h4,h5,h6').find(function (n) { var t = norm(text(n)); return t.indexOf('occasione imperdibile') !== -1 || t.indexOf('deal of the day') !== -1; });
    if (!title) return;
    var section = title.closest('section, .tf-sp-2, .container') || title.parentNode;
    if (!section || section.getAttribute('data-ks-deals-rendered') === '1') return;
    feed('deals', { limit: 4, _: Date.now() }).then(function (data) {
      var deals = (data && data.deals) ? data.deals : [];
      if (deals.length < 2) return;
      var oldGrid = all(section, '.swiper, .swiper-wrapper, .swiper-slide, .card-product, .product-list-wrap').map(function (n) { return n; });
      var mount = document.createElement('div');
      mount.className = 'ks-deal-runtime ks-onsus-font';
      mount.innerHTML = '<div class="ks-deal-runtime-grid">' + deals.slice(0,4).map(buildDealCard).join('') + '</div>';
      var existing = first(section, '.ks-deal-runtime'); if (existing) existing.parentNode.removeChild(existing);
      var host = first(section, '.box-btn-slide-2, .swiper, .swiper-wrapper') || title.parentNode;
      if (host && host.parentNode) {
        if (host.parentNode === section) { host.style.display = 'none'; section.appendChild(mount); }
        else { section.appendChild(mount); }
      } else section.appendChild(mount);
      all(mount, 'img[data-fallback]').forEach(function (img) { img.addEventListener('error', function onErr() { img.removeEventListener('error', onErr); var fb = img.getAttribute('data-fallback') || ''; if (fb && img.src !== fb) img.src = fb; }); });
      all(mount, '.ks-deal-runtime-card').forEach(function (card) {
        var main = first(card, 'img[data-main="1"]');
        all(card, '.ks-deal-runtime-thumb').forEach(function (btn) { btn.addEventListener('click', function () { all(card, '.ks-deal-runtime-thumb').forEach(function (b) { b.classList.remove('is-active'); }); btn.classList.add('is-active'); if (main) main.src = btn.getAttribute('data-img') || main.src; }); });
        renderCountdown(first(card, '.ks-deal-runtime-count'), deals[parseInt(card.getAttribute('data-idx') || '0', 10)].dealEnds || '');
      });
      section.setAttribute('data-ks-deals-rendered', '1');
      if (currentLang().indexOf('en') === 0) applyUiLanguage('en');
    });
  }
  function alignTabsAndFonts() {
    all(document, '.flat-animate-tab, .flat-title-tab-default, .menu-tab-line').forEach(function (n) { n.classList.add('ks-onsus-tabs', 'ks-onsus-font'); });
    all(document, '.flat-animate-tab .card-product').forEach(function (card) {
      var info = first(card, '.card-product-info');
      var actionList = first(card, '.list-product-btn');
      var price = info ? first(info, '.price-wrap') : null;
      if (!info || !actionList || !price) return;
      var group = first(info, '.group-btn');
      if (!group) { group = document.createElement('div'); group.className = 'group-btn'; info.appendChild(group); }
      if (price.parentNode !== group) group.insertBefore(price, group.firstChild || null);
      if (actionList.parentNode !== group) group.appendChild(actionList);
    });
  }

  function shuffled(list) {
    var out = (list || []).slice();
    for (var i = out.length - 1; i > 0; i -= 1) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }
  function itemImages(item) {
    var seen = Object.create(null);
    var out = [];
    var firsts = [item && item.preview, item && item.image];
    (firsts.concat((item && item.images) || [])).forEach(function (img) {
      img = String(img || '').trim(); if (!img || seen[img]) return; seen[img] = 1; out.push(img);
    });
    return out.slice(0, 5);
  }
  function imageOf(item) {
    var imgs = itemImages(item);
    return imgs.length ? imgs[0] : '';
  }
  function actionButtons(url) {
    return '<ul class="ks-runtime-actions">' +
      '<li><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a></li>' +
      '<li><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a></li>' +
      '<li><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a></li>' +
      '<li><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></li>' +
      '</ul>';
  }
  function priceHtml(item) {
    return '<div class="ks-runtime-price">' +
      (item && item.price ? ('<span class="new">€' + esc(item.price) + '</span>') : '') +
      (item && item.oldPrice ? ('<span class="old">€' + esc(item.oldPrice) + '</span>') : '') +
      '</div>';
  }
  function buildSideCard(item) {
    var img = imageOf(item);
    return '<a class="ks-runtime-side-card ks-onsus-font" href="' + esc(item.url || '#') + '">' +
      '<span class="ks-runtime-side-thumb"><img src="' + esc(img) + '" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '"/></span>' +
      '<span class="ks-runtime-side-body"><span class="ks-runtime-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></span><span class="ks-runtime-title">' + esc(item.title || '') + '</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }
  function buildGridCard(item) {
    var img = imageOf(item);
    return '<a class="ks-runtime-grid-card ks-onsus-font" href="' + esc(item.url || '#') + '">' +
      '<span class="ks-runtime-grid-thumb"><img src="' + esc(img) + '" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '"/></span>' +
      '<span class="ks-runtime-grid-body"><span class="ks-runtime-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></span><span class="ks-runtime-title">' + esc(item.title || '') + '</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }
  function buildBigCard(item) {
    var imgs = itemImages(item);
    var main = imgs[0] || '';
    return '<div class="ks-runtime-big-card ks-onsus-font">' +
      '<div class="ks-runtime-big-main"><a class="ks-runtime-big-media" href="' + esc(item.url || '#') + '"><img src="' + esc(main) + '" data-main="1" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '"/></a>' +
      '<div class="ks-runtime-big-body"><div class="ks-runtime-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></div><a class="ks-runtime-title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a><div class="ks-runtime-bottom">' + priceHtml(item) + actionButtons(item.url || '#') + '</div></div></div>' +
      '<div class="ks-runtime-big-thumbs">' + imgs.slice(0,4).map(function (img, idx) { return '<button type="button" class="ks-runtime-big-thumb' + (idx === 0 ? ' is-active' : '') + '" data-img="' + esc(img) + '"><img src="' + esc(img) + '" alt=""/></button>'; }).join('') + '</div>' +
      '</div>';
  }
  function bindFallbackImages(root) {
    all(root, 'img[data-fallback]').forEach(function (img) {
      img.addEventListener('error', function onErr() {
        img.removeEventListener('error', onErr);
        var fb = img.getAttribute('data-fallback') || '';
        if (fb && img.src !== fb) img.src = fb;
      });
    });
  }
  function bindBigThumbs(root) {
    all(root, '.ks-runtime-big-card').forEach(function (card) {
      var main = first(card, 'img[data-main="1"]');
      if (!main) return;
      all(card, '.ks-runtime-big-thumb').forEach(function (btn) {
        btn.addEventListener('click', function () {
          all(card, '.ks-runtime-big-thumb').forEach(function (b) { b.classList.remove('is-active'); });
          btn.classList.add('is-active');
          main.src = btn.getAttribute('data-img') || main.src;
        });
      });
    });
  }
  function hideSection(section) {
    if (!section) return;
    section.setAttribute('data-ks-hidden-section', '1');
    section.style.setProperty('display', 'none', 'important');
  }
  function findTabbedSection() {
    return all(document, 'section, .tf-sp-2, .container').find(function (sec) {
      var labels = all(sec, 'a,button,h1,h2,h3,h4,h5,h6').map(function (n) { return norm(text(n)); });
      return labels.some(function (t) { return t === 'offerte' || t === 'on sale'; }) && labels.some(function (t) { return t.indexOf('evidenza') !== -1 || t.indexOf('featured') !== -1; }) && labels.some(function (t) { return t.indexOf('nuovi arrivi') !== -1 || t.indexOf('new arrivals') !== -1; });
    }) || first(document, '.flat-animate-tab');
  }
  function findBestSellerSection() {
    var title = all(document, 'h1,h2,h3,h4,h5,h6').find(function (n) { return norm(text(n)).indexOf('best seller') !== -1; });
    return title ? (title.closest('section, .tf-sp-2, .container') || title.parentNode) : null;
  }
  function findLowerSection() {
    return all(document, 'section, .tf-sp-2, .container').find(function (sec) {
      if (sec.getAttribute && sec.getAttribute('data-ks-hidden-section') === '1') return false;
      var labels = all(sec, 'h1,h2,h3,h4,h5,h6,a,button').map(function (n) { return norm(text(n)); });
      return labels.some(function (t) { return t.indexOf('in evidenza') !== -1 || t.indexOf('featured') !== -1; }) && labels.some(function (t) { return t.indexOf('in offerta') !== -1 || t.indexOf('on sale') !== -1; });
    });
  }
  var sectionsPromise = null;
  function loadSectionsData() {
    if (!sectionsPromise) sectionsPromise = feed('sections', { _: Date.now() }).then(function (data) { return data && data.sections ? data.sections : {}; });
    return sectionsPromise;
  }
  function renderRuntimeTabbedSection(sections) {
    if (!isHome()) return;
    if (first(document, '.ks-runtime-tabbed-section')) return;
    var host = findTabbedSection();
    if (!host || !host.parentNode) return;
    var mapping = [
      { key: 'offerte', label: currentLang().indexOf('en') === 0 ? 'On Sale' : 'Offerte' },
      { key: 'evidenza', label: currentLang().indexOf('en') === 0 ? 'Featured' : 'In Evidenza' },
      { key: 'nuovi', label: currentLang().indexOf('en') === 0 ? 'New Arrivals' : 'Nuovi Arrivi' }
    ];
    var usable = mapping.filter(function (m) { return (sections[m.key] || []).length >= 3; });
    if (!usable.length) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-tabbed-section';
    wrapper.innerHTML = '<div class="container"><div class="ks-runtime-tabs-head">' + usable.map(function (m, idx) { return '<button type="button" class="ks-runtime-tab-btn' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '">' + esc(m.label) + '</button>'; }).join('') + '</div><div class="ks-runtime-tabs-panels">' + usable.map(function (m, idx) {
      var items = shuffled((sections[m.key] || []).slice()).slice(0, 7);
      var big = items[0] || null;
      var left = items.slice(1, 4);
      var right = items.slice(4, 7);
      if (!big) return '';
      return '<div class="ks-runtime-panel' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '"><div class="ks-runtime-tab-layout"><div class="ks-runtime-side-col">' + left.map(buildSideCard).join('') + '</div><div class="ks-runtime-big-wrap">' + buildBigCard(big) + '</div><div class="ks-runtime-side-col">' + right.map(buildSideCard).join('') + '</div></div></div>';
    }).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    all(wrapper, '.ks-runtime-tab-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var panel = btn.getAttribute('data-panel') || '';
        all(wrapper, '.ks-runtime-tab-btn').forEach(function (b) { b.classList.toggle('is-active', b === btn); });
        all(wrapper, '.ks-runtime-panel').forEach(function (p) { p.classList.toggle('is-active', p.getAttribute('data-panel') === panel); });
      });
    });
    bindFallbackImages(wrapper); bindBigThumbs(wrapper);
  }
  function renderRuntimeBestSeller(sections) {
    if (!isHome()) return;
    if (first(document, '.ks-runtime-best-section')) return;
    var host = findBestSellerSection();
    if (!host || !host.parentNode) return;
    var items = shuffled((sections.best || []).slice()).slice(0, 10);
    if (items.length < 4) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-best-section';
    wrapper.innerHTML = '<div class="container"><div class="flat-title"><h5 class="fw-semibold">Best Seller</h5></div><div class="ks-runtime-grid">' + items.map(buildGridCard).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    bindFallbackImages(wrapper);
  }
  function renderRuntimeLowerSections(sections) {
    if (!isHome()) return;
    if (first(document, '.ks-runtime-lower-section')) return;
    var host = findLowerSection();
    if (!host || !host.parentNode) return;
    var leftItems = shuffled((sections.evidenza || []).slice()).slice(0, 6);
    var rightItems = shuffled((sections.offerte || []).slice()).slice(0, 6);
    if (leftItems.length < 2 && rightItems.length < 2) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-lower-section';
    wrapper.innerHTML = '<div class="container"><div class="ks-runtime-two-col"><div><h5 class="ks-runtime-col-title">' + esc(currentLang().indexOf('en') === 0 ? 'Featured' : 'In Evidenza') + '</h5><div class="ks-runtime-col-grid">' + leftItems.map(buildGridCard).join('') + '</div></div><div><h5 class="ks-runtime-col-title">' + esc(currentLang().indexOf('en') === 0 ? 'On Sale' : 'In Offerta') + '</h5><div class="ks-runtime-col-grid">' + rightItems.map(buildGridCard).join('') + '</div></div></div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    bindFallbackImages(wrapper);
  }
  function renderRuntimeCommercialSections() {
    if (!isHome()) return;
    ensureRuntimeSectionsCss();
    loadSectionsData().then(function (sections) {
      renderRuntimeTabbedSection(sections || {});
      renderRuntimeBestSeller(sections || {});
      renderRuntimeLowerSections(sections || {});
    }).catch(function () {});
  }
  function killBrokenSidebarWrap() {
    if (!isHome()) return;
    var wrap = first(document, '.wrap-item-3');
    if (!wrap) return;
    var promos = all(wrap, 'a, .cls-category, .ks-side-runtime-banner').filter(function (node) {
      var r = rect(node); if (!r || node.offsetParent === null) return false;
      return r.width >= 180 && r.height >= 120 && (r.width / Math.max(r.height, 1)) > 0.75;
    });
    if (promos.length < 2) {
      wrap.classList.add('ks-runtime-empty');
      var shell = first(document, '.ks-home-hero-shell, .s-banner-wrapper');
      if (shell) shell.classList.add('ks-home-force-compact');
    }
  }
  function sweepMarginRails() {
    if (!isHome()) return;
    var laneNode = first(document, '.tf-sp-5 .container') || first(document, '.header-bottom .container') || first(document, '.container');
    var lane = rect(laneNode);
    all(document.body, '*').forEach(function (node) {
      if (!node || node === document.body || protectedRailRoot(node)) return;
      var r = rect(node); if (!r) return;
      if (r.width < 24 || r.height < 24) return;
      var cs = window.getComputedStyle ? getComputedStyle(node) : null;
      var pos = cs ? String(cs.position || '').toLowerCase() : '';
      var outside = lane ? (r.right < lane.left - 6 || r.left > lane.right + 6) : (r.left <= 24 || r.right >= window.innerWidth - 24);
      if (!outside) return;
      var media = all(node, 'img,iframe,object,embed').length;
      var txt = norm(text(node));
      var vertical = cs && ((cs.writingMode && cs.writingMode !== 'horizontal-tb') || /rotate\(/i.test(cs.transform || ''));
      if ((pos === 'fixed' || pos === 'sticky') && r.width <= 260 && r.height >= 90) { node.classList.add('ks-hidden-rail'); return; }
      if (vertical && r.width <= 260) { railRoot(node).classList.add('ks-hidden-rail'); return; }
      if (media >= 1 && r.width <= 220 && r.height >= 90) { railRoot(node).classList.add('ks-hidden-rail'); return; }
      if ((txt.indexOf('welcome') !== -1 || txt.indexOf('franchis') !== -1 || txt.indexOf('onsus') !== -1) && r.width <= 320) { railRoot(node).classList.add('ks-hidden-rail'); }
    });
    killBrokenSidebarWrap();
  }

  function protectedRailRoot(node) {
    return !!(node && node.closest('header, footer, .ks-home-departments, .menu-category-list, .menu-item, .ks-top-catalog-mega, .ks-mobile-catalog-block, .card-product, .ks-deal-runtime, .ks-chosen-section, .ks-side-runtime-banners, .list-image-product, .product-thumb-slider, .product-thumb-image, .brand-item, .tf-sw-products, .swiper-pagination, .swiper-button-next, .swiper-button-prev'));
  }
  function railRoot(node) {
    var current = node; var best = node; var hops = 0;
    while (current && current.parentElement && hops < 6) {
      var parent = current.parentElement;
      if (!parent || parent === document.body || protectedRailRoot(parent)) break;
      var pr = rect(parent); if (!pr || pr.width > 320 || pr.height > 1600) break;
      best = parent; current = parent; hops += 1;
    }
    return best;
  }
  function mediaKey(node) {
    if (!node) return '';
    var src = node.getAttribute && (node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('data-img') || '');
    return String(src || '').replace(/^https?:/i,'').replace(/[?#].*$/,'').trim().toLowerCase();
  }
  function sweepBlockedTextRails() {
    all(document.body, '*').forEach(function (node) {
      if (!node || node === document.body || protectedRailRoot(node)) return;
      var t = norm(text(node)); if (!t) return;
      var hit = t.indexOf('welcome') !== -1 || t.indexOf('franchis') !== -1 || t.indexOf('onsus') !== -1 || t.indexOf('themesflat') !== -1;
      if (!hit) return;
      var r = rect(node); if (!r) return;
      var cs = window.getComputedStyle ? getComputedStyle(node) : null;
      var vertical = (r.height > r.width * 2) || (cs && ((cs.writingMode && cs.writingMode !== 'horizontal-tb') || /rotate\(/i.test(cs.transform || '')));
      if (!vertical && r.width > 340) return;
      railRoot(node).classList.add('ks-hidden-rail');
    });
  }
  function sweepRepeatedPeripheralMedia() {
    var groups = Object.create(null);
    all(document.body, 'img, iframe, object, embed').forEach(function (node) {
      if (!node || protectedRailRoot(node)) return;
      var r = rect(node); if (!r) return;
      if (r.width < 28 || r.width > 220 || r.height < 40 || r.height > 320) return;
      var key = mediaKey(node); if (!key || key.indexOf('data:image') === 0) return;
      if (!groups[key]) groups[key] = [];
      groups[key].push(node);
    });
    Object.keys(groups).forEach(function (key) {
      var nodes = groups[key]; if (!nodes || nodes.length < 3) return;
      nodes.forEach(function (node) { railRoot(node).classList.add('ks-hidden-rail'); });
    });
  }
  function sweepOutOfLaneArtifacts() {
    var lane = rect(first(document, '.header-bottom .container')) || rect(first(document, '.tf-sp-5 .container')) || rect(first(document, '.container'));
    all(document.body, 'div,section,aside,a,span,p').forEach(function (node) {
      if (!node || node === document.body || protectedRailRoot(node)) return;
      var r = rect(node); if (!r) return;
      if (r.width < 24 || r.width > 280 || r.height < 80) return;
      var outside = lane ? (r.right < lane.left + 8 || r.left > lane.right - 8) : (r.left <= 40 || r.right >= window.innerWidth - 40);
      if (!outside) return;
      var t = norm(text(node));
      var hasMedia = !!first(node, 'img, iframe, object, embed');
      var tall = r.height / Math.max(r.width, 1) >= 1.4;
      if ((tall && hasMedia) || (tall && t && t.length <= 160) || (hasMedia && !t && r.height > 110)) railRoot(node).classList.add('ks-hidden-rail');
    });
  }
  function stripRogueRails() {
    if (!isHome()) return;
    sweepBlockedTextRails();
    sweepRepeatedPeripheralMedia();
    sweepOutOfLaneArtifacts();
  }
  function init() {
    ensureCss();
    ensureRuntimeSectionsCss();
    bindSearch();
    applyRankingOnResults();
    ensureCatalogMega();
    ensureMobileCatalog();
    restoreLanguageSelector();
    ensureSideBanners();
    renderChosenForYou();
    renderDeals();
    renderRuntimeCommercialSections();
    alignTabsAndFonts();
    stripRogueRails();
    sweepMarginRails();
    window.addEventListener('resize', function () { ensureCatalogMega(); ensureMobileCatalog(); stripRogueRails(); sweepMarginRails(); });
    window.addEventListener('load', function(){ stripRogueRails(); sweepMarginRails(); }, { once: true });
    window.addEventListener('scroll', function(){ stripRogueRails(); sweepMarginRails(); }, { passive:true });
    if (typeof MutationObserver !== 'undefined' && document.body) {
      var t = 0;
      var mo = new MutationObserver(function(){ clearTimeout(t); t = setTimeout(function(){ stripRogueRails(); sweepMarginRails(); renderRuntimeCommercialSections(); }, 120); });
      mo.observe(document.body, { childList:true, subtree:true });
      setTimeout(function(){ try{ mo.disconnect(); }catch(err){} }, 30000);
    }
  }
  onReady(init);
})();
