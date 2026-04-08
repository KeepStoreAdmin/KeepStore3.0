(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;

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

  function isEdgeRect(rect, padding) {
    if (!rect) return false;
    var edgePadding = typeof padding === 'number' ? padding : 60;
    if (rect.width < 12 || rect.height < 12) return false;
    return rect.left <= edgePadding || rect.right >= (window.innerWidth - edgePadding);
  }

  function isNarrowEdgeRect(rect) {
    return !!(rect && isEdgeRect(rect, 90) && rect.width <= 220 && rect.height >= 80 && rect.height <= 1200);
  }

  function hideNode(node, attrName) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (attrName) node.setAttribute(attrName, '1');
  }

  function hardProtectedAncestor(node) {
    if (!node || !node.closest) return false;
    return !!node.closest([
      'header', 'footer', '.tf-header', '.tf-footer', '.footer',
      '.ks-home-departments', '.ks-home-hero-shell', '.wrap-item-1', '.wrap-item-2', '.wrap-item-3',
      '.tf-icon-box', '.card-product', '.ks-card-product', '.ks-grid-card', '.ks-row-card', '.ks-big-card', '.ks-deal-card',
      '.ks-home-brands', '.tf-grid-product-item', '.modal:not(.auto-popup):not(.modal-newleter)', '.offcanvas.show'
    ].join(','));
  }

  function edgeCreativeRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;

    while (current && current.parentElement && hops < 6) {
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

  function containsBlockedCreativeToken(text) {
    var value = normalizeText(text);
    if (!value) return false;
    return ['welcome', 'franchis', 'themeforest', 'onsus'].some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function injectHomeRuntimeCss() {
    if (!isHomePage()) return;
    if (document.getElementById('ks-home-runtime-step7')) return;

    var style = document.createElement('style');
    style.id = 'ks-home-runtime-step7';
    style.type = 'text/css';
    style.appendChild(document.createTextNode([
      "body.ks-page-home .ks-home-submenu-container[aria-hidden='true']{display:none!important;}",
      "body.ks-page-home [data-ks-edge-creative='1'],body.ks-page-home [data-ks-hidden-popup='1']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home .auto-popup,body.ks-page-home .modal-newleter,body.ks-page-home [class*='modal-newleter']{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}",
      "body.ks-page-home .ks-home-departments .menu-category-list{overflow-x:hidden!important;}",
      "@media (min-width:1200px){",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact{display:grid!important;grid-template-columns:minmax(250px,270px) minmax(0,1fr)!important;column-gap:24px!important;align-items:start!important;}",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-3{display:none!important;}",
      "body.ks-page-home .ks-home-hero-shell.ks-home-force-compact .wrap-item-2{width:auto!important;max-width:none!important;min-width:0!important;flex:1 1 auto!important;}",
      "body.ks-page-home .ks-home-departments .menu-category-list[data-ks-menu-synced='1']{overflow-y:auto!important;overscroll-behavior:contain;}",
      "}"
    ].join('')));
    (document.head || document.documentElement).appendChild(style);
  }

  function disableTemplatePopupStorage() {
    if (!isHomePage()) return;
    try {
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
    } catch (err) {
      return;
    }
  }

  function clearStaleUiLock() {
    if (!isHomePage()) return;
    var visibleDialog = document.querySelector('.modal.show:not([data-ks-hidden-popup="1"]), .offcanvas.show');
    if (visibleDialog) return;

    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function (backdrop) {
      hideNode(backdrop, 'data-ks-hidden-popup');
      if (backdrop.parentNode) {
        backdrop.parentNode.removeChild(backdrop);
      }
    });

    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function newsletterPopupCandidates() {
    var selectors = [
      '.auto-popup',
      '.modal-newleter',
      '[class*="modal-newleter"]',
      '.modal.auto-popup',
      '.modal .modal-content',
      '.modal .modal-dialog',
      '.modal .form-newsletter',
      '.modal [type="email"]'
    ];

    var out = [];
    selectors.forEach(function (selector) {
      Array.prototype.slice.call(document.querySelectorAll(selector)).forEach(function (node) {
        if (out.indexOf(node) === -1) out.push(node);
      });
    });

    return out;
  }

  function looksLikeNewsletterPopup(node) {
    if (!node) return false;

    var raw = [
      node.id || '',
      node.className || '',
      textContentOf(node).slice(0, 280)
    ].join(' ');
    var text = normalizeText(raw);

    if (/auto popup|modal newleter|sibform|sib form/.test(text)) return true;
    if (text.indexOf('join our newsletter') !== -1) return true;
    if (text.indexOf('subscribe') !== -1 && text.indexOf('newsletter') !== -1) return true;

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
    var root = node.closest('.auto-popup, .modal-newleter, [class*="modal-newleter"], .modal');
    return root || node;
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

  function sweepTokenizedEdgeCreatives() {
    if (!isHomePage() || !document.body) return;

    Array.prototype.slice.call(document.body.querySelectorAll('img,a,div,span,p')).forEach(function (node) {
      if (!node || hardProtectedAncestor(node)) return;
      var rect = rectOf(node);
      if (!rect || !isNarrowEdgeRect(rect)) return;

      var raw = [
        node.id || '',
        node.className || '',
        node.getAttribute && node.getAttribute('src') || '',
        node.getAttribute && node.getAttribute('data-src') || '',
        node.getAttribute && node.getAttribute('alt') || '',
        backgroundImageOf(node),
        textContentOf(node).slice(0, 200)
      ].join(' ');

      if (!containsBlockedCreativeToken(raw)) return;
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
      if (rect.width > 180 || rect.height > 260) return;

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

    if (!shell || !sliderWrap) return;

    if (window.innerWidth < 1200) {
      shell.classList.remove('ks-home-force-compact');
      if (sideWrap) sideWrap.style.display = '';
      if (menuList) {
        menuList.style.maxHeight = '';
        menuList.style.height = '';
        menuList.removeAttribute('data-ks-menu-synced');
      }
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

    if (!menuRoot || !menuList) return;
    var targetNode = sliderWrap.querySelector('.banner-image-product-4') || sliderWrap.querySelector('.ks-home-hero-slider') || sliderWrap;
    var sliderRect = rectOf(targetNode);
    var titleRect = rectOf(menuTitle);
    if (!sliderRect || sliderRect.height < 220) return;

    var titleHeight = titleRect ? Math.ceil(titleRect.height) : 0;
    var listHeight = Math.max(180, Math.floor(sliderRect.height - titleHeight - 10));
    menuList.style.maxHeight = listHeight + 'px';
    menuList.style.height = listHeight + 'px';
    menuList.setAttribute('data-ks-menu-synced', '1');
  }

  function runHomeRuntimeSweep() {
    if (!isHomePage()) return;
    injectHomeRuntimeCss();
    disableTemplatePopupStorage();
    suppressNewsletterPopup();
    sweepTokenizedEdgeCreatives();
    sweepRepeatedEdgeDevices();
    syncHomeShell();
    clearStaleUiLock();
  }

  function armHomeRuntimeSweep() {
    if (!isHomePage()) return;

    [0, 250, 1200, 2500, 5000, 9000].forEach(function (delay) {
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
      }, 120);
    });

    observer.observe(document.body, { childList: true, subtree: true });
    window.setTimeout(function () {
      observer.disconnect();
    }, 12000);
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

  disableTemplatePopupStorage();

  onReady(function () {
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }

    applyHomeFlags();
    runHomeRuntimeSweep();
    armHomeRuntimeSweep();
    window.addEventListener('load', runHomeRuntimeSweep, { once: true });
    window.addEventListener('resize', runHomeRuntimeSweep);
  });
})();
