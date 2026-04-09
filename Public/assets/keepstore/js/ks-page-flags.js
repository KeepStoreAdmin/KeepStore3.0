(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var HOME_GUARD_ATTR = 'data-ks-home-guard';
  var HOME_STYLE_ID = 'ks-home-runtime-step14';
  var HOME_SWEEP_TIMERS = [0, 60, 180, 420, 900, 1600, 2600, 4200, 6800, 10000, 15000, 22000, 30000, 42000, 60000];
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
    var count = allNodes(node, 'img, picture, video, canvas, svg, iframe').length;
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
    if (firstNode(node, 'input, textarea, select, form')) return false;
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
      "html[data-ks-home-guard='1'] .ks-home-hero-shell .wrap-item-3[data-ks-home-artifact='1'],html[data-ks-home-guard='1'] .s-banner-wrapper .wrap-item-3[data-ks-home-artifact='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][hidden],html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][inert]{max-height:0!important;overflow:hidden!important;}",
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

  function sideWrapDirectChildren(sideWrap) {
    if (!sideWrap) return [];
    return Array.prototype.slice.call(sideWrap.children || []).filter(function (node) {
      if (!node || node.nodeType !== 1) return false;
      if (node.getAttribute('data-ks-home-artifact') === '1' || node.getAttribute('data-ks-edge-creative') === '1') return false;
      var rect = rectOf(node);
      return !!(rect && rect.width >= 24 && rect.height >= 24 && node.offsetParent !== null);
    });
  }

  function usefulSideItems(sideWrap) {
    if (!sideWrap) return [];
    return sideWrapDirectChildren(sideWrap).filter(function (node) {
      var rect = rectOf(node);
      if (!rect || rect.width < 150 || rect.height < 90) return false;
      var imgs = Array.prototype.slice.call(node.querySelectorAll('img, picture img, iframe')).filter(function (img) {
        var imgRect = rectOf(img);
        var src = normalizeSrc((img.getAttribute && (img.getAttribute('src') || img.getAttribute('data-src'))) || '');
        return !!((src || img.tagName === 'IFRAME') && imgRect && imgRect.width >= 70 && imgRect.height >= 70 && img.offsetParent !== null);
      });
      return imgs.length > 0;
    });
  }

  function isValidSidePromoCard(node, shellRect) {
    if (!node) return false;
    var rect = rectOf(node);
    if (!rect || node.offsetParent === null) return false;
    if (rect.width < 165 || rect.width > 360) return false;
    if (rect.height < 96 || rect.height > 340) return false;
    var ratio = rect.width / Math.max(rect.height, 1);
    if (ratio < 0.55 || ratio > 2.6) return false;
    if (shellRect) {
      if (rect.left < (shellRect.left - 16) || rect.right > (shellRect.right + 16)) return false;
      if (rect.top < (shellRect.top - 12) || rect.bottom > (shellRect.bottom + 24)) return false;
    }
    if (nodeContainsBlockedCreative(node)) return false;
    var style = computedStyleOf(node);
    if (isVerticalWritingStyle(style)) return false;
    var raw = normalizeText([textContentOf(node).slice(0, 220), backgroundImageOf(node), node.className || ''].join(' '));
    if (raw.indexOf('welcome') !== -1 || raw.indexOf('franchis') !== -1) return false;
    var media = mediaCountOf(node);
    if (media < 1 || media > 4) return false;
    return true;
  }

  function sanitizeSideWrap(sideWrap, shell) {
    if (!sideWrap) return false;
    var shellRect = rectOf(shell);
    var directChildren = sideWrapDirectChildren(sideWrap);
    directChildren.forEach(function (node) {
      if (!isValidSidePromoCard(node, shellRect)) {
        hideNode(node, 'data-ks-home-artifact');
      }
    });
    var valid = usefulSideItems(sideWrap).filter(function (node) {
      return isValidSidePromoCard(node, shellRect) && node.getAttribute('data-ks-home-artifact') !== '1';
    });
    if (valid.length != 2) {
      hideNode(sideWrap, 'data-ks-home-artifact');
      return false;
    }
    sideWrap.removeAttribute('data-ks-home-artifact');
    sideWrap.style.removeProperty('display');
    sideWrap.style.removeProperty('visibility');
    sideWrap.style.removeProperty('opacity');
    sideWrap.style.removeProperty('pointer-events');
    return true;
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

    var shellRect = rectOf(shell);
    var sideIsValid = false;

    if (sideWrap) {
      sideIsValid = sanitizeSideWrap(sideWrap, shell);
      if (!sideIsValid) {
        shell.classList.add('ks-home-force-compact');
        hideNode(sideWrap, 'data-ks-home-artifact');
      } else {
        shell.classList.remove('ks-home-force-compact');
      }
    } else {
      shell.classList.add('ks-home-force-compact');
    }

    var targetNode = sliderWrap.querySelector('.banner-image-product-4') || sliderWrap.querySelector('.ks-home-hero-slider') || sliderWrap;
    var sliderRect = rectOf(targetNode);
    var titleRect = rectOf(menuTitle);
    if (!sliderRect || sliderRect.height < 220) return;

    if (shellRect && sliderRect.bottom > (shellRect.bottom + 40)) {
      shell.classList.add('ks-home-force-compact');
      if (sideWrap) hideNode(sideWrap, 'data-ks-home-artifact');
    }

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
      if (firstNode(node, 'input, textarea, select, form')) return;
      var media = mediaCountOf(node);
      var vertical = isVerticalWritingStyle(style);
      var token = nodeContainsBlockedCreative(node);
      var rail = (rect.width <= 120 && rect.height >= 120) || (rect.width <= 220 && (rect.height / Math.max(rect.width, 1)) >= 1.25);
      if (!token && !vertical && media < 1 && !rail) return;
      hideNode(pos === 'absolute' ? edgeCreativeRoot(node) : fixedLikeRoot(node), 'data-ks-home-artifact');
    });
  }

  function sweepStaticEdgeReplicas() {
    if (!isHomePage() || !document.body) return;

    allNodes(document.body, 'img, picture, a, div, span, section, aside, iframe').forEach(function (node) {
      if (!node || node === document.body || hardProtectedAncestor(node)) return;
      if (isLikelyUiUtility(node) || isRealHeaderNode(node) || isHeaderFooterShell(node)) return;
      var rect = rectOf(node);
      if (!rect) return;
      if (!isNarrowEdgeRect(rect) && !floatingSideZone(rect)) return;
      if (rect.width > 220 || rect.height > 1600 || rect.width < 18 || rect.height < 48) return;
      var style = computedStyleOf(node);
      if (!style) return;
      var pos = String(style.position || '').toLowerCase();
      if (pos === 'relative' || pos === 'static' || pos === 'absolute' || pos === 'fixed' || pos === 'sticky') {
        var media = mediaCountOf(node);
        var text = normalizeText(textContentOf(node));
        var tall = rect.height / Math.max(rect.width, 1) >= 1.2;
        if (nodeContainsBlockedCreative(node) || isVerticalWritingStyle(style) || (media >= 1 && tall) || (media >= 1 && text.length <= 72)) {
          hideNode(edgeCreativeRoot(node), 'data-ks-home-artifact');
        }
      }
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
    sweepStaticEdgeReplicas();
    hideStickyHeaderReplicas();
    hideDuplicateHeaderClones();
    syncHomeShell();
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
