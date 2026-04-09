(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var HOME_GUARD_ATTR = 'data-ks-home-guard';
  var HOME_STYLE_ID = 'ks-home-runtime-step10';
  var HOME_SWEEP_TIMERS = [0, 120, 350, 900, 1800, 3200, 5500, 9000, 15000, 22000];
  var BLOCKED_CREATIVE_TOKENS = ['welcome', 'franchis', 'themeforest', 'onsus', 'themesflat', 'demo', 'template'];
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
      '.ks-home-hero-shell', '.wrap-item-2', '.wrap-item-3',
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
    var count = allNodes(node, 'img, picture, video, canvas, svg').length;
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
    if (!node || hardProtectedAncestor(node) || isLikelyUiUtility(node)) return false;
    var style = computedStyleOf(node);
    if (!isFixedLikePosition(style)) return false;
    var rect = rectOf(node);
    if (!rect || !floatingSideZone(rect)) return false;
    if (rect.width > 340 || rect.height > Math.max(window.innerHeight * 1.8, 1500)) return false;
    if (rect.width < 40 || rect.height < 40) return false;
    if (firstNode(node, 'input, textarea, select, iframe, form')) return false;
    var mediaCount = mediaCountOf(node);
    var textLen = normalizeText(textContentOf(node)).length;
    if (nodeContainsBlockedCreative(node)) return true;
    if (mediaCount >= 1 && textLen <= 48) return true;
    if (mediaCount >= 2) return true;
    return false;
  }

  function sweepFloatingEdgeArtifacts() {
    if (!isHomePage() || !document.body) return;

    allNodes(document.body, '*').forEach(function (node) {
      if (!isSuspiciousFloatingEdgeNode(node)) return;
      hideNode(fixedLikeRoot(node), 'data-ks-floating-edge');
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
      "html[data-ks-home-guard='1'] [data-ks-hidden-popup='1'],html[data-ks-home-guard='1'] [data-ks-edge-creative='1'],html[data-ks-home-guard='1'] [data-ks-floating-edge='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "html[data-ks-home-guard='1'] body,html[data-ks-home-guard='1'] .ks-page-home{overflow-x:hidden!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-category-list{overflow-x:hidden!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][aria-hidden='true']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments [data-ks-submenu='1'][data-ks-inline-state='open']{display:flex!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-submenu-mode='list'] > [data-ks-submenu='1'][data-ks-inline-state='open']{display:block!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-has-children='0'] > [data-ks-submenu='1']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-item[data-ks-has-children='0'] .ks-menu-toggle{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .ks-home-sector-promo[data-ks-hidden='1']{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-departments .menu-category-list[data-ks-menu-synced='1']{overflow-y:auto!important;overscroll-behavior:contain;}",
      "@media (min-width:1200px){",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact{display:grid!important;grid-template-columns:minmax(250px,270px) minmax(0,1fr)!important;column-gap:24px!important;align-items:start!important;}",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact .wrap-item-3{display:none!important;}",
      "html[data-ks-home-guard='1'] .ks-home-hero-shell.ks-home-force-compact .wrap-item-2{width:auto!important;max-width:none!important;min-width:0!important;flex:1 1 auto!important;}",
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
    submenu.style.display = open ? (mode === 'list' ? 'block' : 'flex') : 'none';
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
        submenu.style.setProperty('display', 'none', 'important');
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

  function usefulSideItems(sideWrap) {
    if (!sideWrap) return [];
    return Array.prototype.slice.call(sideWrap.children).filter(function (node) {
      if (!node || node.getAttribute('data-ks-edge-creative') === '1') return false;
      var rect = rectOf(node);
      if (!rect || node.offsetParent === null) return false;
      if (rect.width < 40 || rect.height < 40) return false;
      var imgs = Array.prototype.slice.call(node.querySelectorAll('img')).filter(function (img) {
        var imgRect = rectOf(img);
        var src = normalizeSrc(img.getAttribute('src') || img.getAttribute('data-src') || '');
        return !!(src && imgRect && imgRect.width >= 70 && imgRect.height >= 70 && img.offsetParent !== null);
      });
      return imgs.length > 0;
    });
  }

  function syncHomeShell() {
    if (!isHomePage()) return;

    var shell = document.querySelector('.ks-home-hero-shell');
    var sliderWrap = shell ? shell.querySelector('.wrap-item-2') : null;
    var sideWrap = shell ? shell.querySelector('.wrap-item-3') : null;
    var menuRoot = document.querySelector('.ks-home-departments .main-nav');
    var menuTitle = menuRoot ? menuRoot.querySelector('.title') : null;
    var menuList = document.querySelector('.ks-home-departments .menu-category-list');

    if (!shell || !sliderWrap || !menuList) return;

    if (!isDesktop()) {
      shell.classList.remove('ks-home-force-compact');
      if (sideWrap) sideWrap.style.display = '';
      menuList.style.maxHeight = '';
      menuList.style.height = '';
      menuList.removeAttribute('data-ks-menu-synced');
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

    var targetNode = sliderWrap.querySelector('.banner-image-product-4') || sliderWrap.querySelector('.ks-home-hero-slider') || sliderWrap;
    var sliderRect = rectOf(targetNode);
    var titleRect = rectOf(menuTitle);
    if (!sliderRect || sliderRect.height < 220) return;

    var titleHeight = titleRect ? Math.ceil(titleRect.height) : 0;
    var listHeight = Math.max(220, Math.floor(sliderRect.height - titleHeight - 10));
    menuList.style.maxHeight = listHeight + 'px';
    menuList.style.height = listHeight + 'px';
    menuList.setAttribute('data-ks-menu-synced', '1');
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
    var candidates = allNodes(document, 'form, .form-search-product, .header-center, .search-product, [data-ks-site-search], .search-wrap, .search-form, .header-search, .search-area, .box-search');
    var out = [];

    candidates.forEach(function (node) {
      if (!node) return;
      var input = allNodes(node, 'input[type="search"], input[type="text"], input:not([type])').filter(looksLikeSearchTextInput)[0] || null;
      if (!input) return;
      var buttons = allNodes(node, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon');
      var select = firstNode(node, 'select');
      var root = closestElement(input, '.form-search-product, .header-center, .search-product, [data-ks-site-search], .search-wrap, form, .search-form, .header-search, .search-area, .box-search') || node;
      if (!root || out.indexOf(root) !== -1) return;
      var rect = rectOf(root);
      var nearTop = !rect || rect.top <= 260;
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
    return firstNode(root, 'select, [role="listbox"] select');
  }

  function searchButtonsFromRoot(root) {
    var buttons = allNodes(root, 'button, [type="submit"], .btn-submit-form, .icon-search, .search-button, .tf-btn-icon');
    return buttons.filter(function (btn) {
      var raw = [btn.name || '', btn.id || '', btn.className || '', textContentOf(btn)].join(' ');
      var text = normalizeText(raw);
      return text.indexOf('search') !== -1 || text.indexOf('cerca') !== -1 || text.indexOf('icon search') !== -1 || text.indexOf('btn submit form') !== -1 || closestElement(btn, '.form-search-product');
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

  function readSelectTarget(select) {
    var result = { url: '', params: {} };
    if (!select) return result;

    var option = select.options && select.selectedIndex >= 0 ? select.options[select.selectedIndex] : null;
    var rawValue = option ? (option.value || option.getAttribute('data-url') || option.getAttribute('data-query') || option.getAttribute('data-value') || '') : '';
    var label = option ? (option.text || option.textContent || '') : '';
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
      if (/cat|cate/i.test((select.name || '') + ' ' + (select.id || ''))) {
        result.params.ct = digits[1];
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
    var target = readSelectTarget(select);
    var base = target.url || 'articoli.aspx';
    var url;

    try {
      url = new URL(base, window.location.href);
    } catch (err) {
      url = new URL('articoli.aspx', window.location.href);
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
        try { root.setAttribute('action', 'articoli.aspx'); root.setAttribute('method', 'get'); } catch (err) {}
        root.addEventListener('submit', function (evt) {
          evt.preventDefault();
          executeMarketplaceSearch(root);
        });
      }

      if (input) {
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

    if (!isHomePage()) return;

    disableTemplatePopupStorage();
    suppressNewsletterPopup();
    sanitizeHomeMenu();
    bindHomeMenu();
    sweepTokenizedEdgeCreatives();
    sweepRepeatedEdgeDevices();
    sweepFloatingEdgeArtifacts();
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
    }, 26000);
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
    runHomeRuntimeSweep();
    armHomeRuntimeSweep();
    window.addEventListener('load', runHomeRuntimeSweep, { once: true });
    window.addEventListener('resize', runHomeRuntimeSweep);
  });
})();
