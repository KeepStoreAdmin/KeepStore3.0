(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];
  var TEMPLATE_DEMO_TOKENS = ['home 2', 'home 3', 'home 4', 'home 5', 'home 6', 'home 7', 'home 8', 'home 9', 'home 10', 'home 11', 'view all demos', 'shop right sidebar', 'shop full width', 'track your order'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
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
    try { return new URLSearchParams(window.location.search || '').get(name); } catch (err) { return null; }
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

  function readMergedRecent() { return mergeRecentLists(readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))); }

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

  function containsToken(raw) {
    var value = normalizeText(raw);
    return BLOCKED_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
  }

  function containsTemplateDemo(raw) {
    var value = normalizeText(raw);
    if (!value) return false;
    if (/\bhome\s*(2|3|4|5|6|7|8|9|10|11)\b/.test(value)) return true;
    if (value.indexOf('images demo home') !== -1) return true;
    return TEMPLATE_DEMO_TOKENS.some(function (token) { return value.indexOf(token) !== -1; });
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

  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }

  function hideNode(node, flag) {
    if (!node || !node.style) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (flag) node.setAttribute(flag, '1');
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

  function compactHero() {
    var shell = document.querySelector('.ks-home-hero-shell');
    var sideWrap = document.getElementById('HeroSideWrap');
    var menuList = document.querySelector('.ks-home-departments .menu-category-list');
    var sliderWrap = document.getElementById('HeroSliderWrap') || (shell ? shell.querySelector('.wrap-item-2') : null);
    if (!shell || !sliderWrap) return;
    if (window.innerWidth < 1200) {
      shell.classList.remove('ks-home-force-compact');
      if (menuList) {
        menuList.style.maxHeight = '';
        menuList.style.height = '';
      }
      return;
    }
    shell.classList.add('ks-home-force-compact');
    shell.classList.remove('ks-home-hero-mode-full');
    if (sideWrap) hideNode(sideWrap, 'data-ks-home-artifact');
    if (menuList) {
      var rr = rectOf(sliderWrap);
      if (rr && rr.height > 220) {
        var h = Math.max(180, Math.floor(rr.height - 12));
        menuList.style.maxHeight = h + 'px';
        menuList.style.height = h + 'px';
        menuList.setAttribute('data-ks-menu-synced', '1');
      }
    }
  }

  function artifactRoot(node) {
    var current = node;
    var hops = 0;
    while (current && current.parentElement && hops < 12) {
      var parent = current.parentElement;
      if (!parent || parent.tagName === 'BODY' || parent.tagName === 'FORM' || parent.tagName === 'MAIN' || parent.tagName === 'HEADER' || parent.tagName === 'FOOTER') break;
      var rect = rectOf(parent);
      if (!rect) break;
      if (rect.width > Math.min(420, window.innerWidth * 0.34) || rect.height > window.innerHeight * 2.2) break;
      current = parent;
      hops += 1;
    }
    return current || node;
  }

  function bodyLevelRoot(node) {
    var current = node;
    var hops = 0;
    while (current && current.parentElement && hops < 10) {
      var parent = current.parentElement;
      if (!parent || parent.tagName === 'BODY' || parent.tagName === 'FORM' || parent.tagName === 'MAIN') break;
      var rect = rectOf(parent);
      if (!rect) break;
      if (rect.width > Math.max(window.innerWidth * 0.82, 760) || rect.height > window.innerHeight * 3.5) break;
      current = parent;
      hops += 1;
    }
    return current || node;
  }

  function primaryLaneRect() {
    var sliderWrap = document.getElementById('HeroSliderWrap');
    var rr = rectOf(sliderWrap);
    if (rr && rr.width > 320) return rr;
    var shell = document.querySelector('.ks-home-hero-shell') || document.querySelector('.s-banner-wrapper');
    var sr = rectOf(shell);
    if (sr) return { left: sr.left + 250, right: sr.right, width: Math.max(320, sr.right - (sr.left + 250)) };
    return { left: 280, right: Math.max(860, window.innerWidth - 120), width: Math.max(580, window.innerWidth - 400) };
  }

  function hideWelcomeFranchising() {
    Array.prototype.slice.call(document.querySelectorAll('div,section,aside,span,p,a,img')).forEach(function (node) {
      if (!node) return;
      if (node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-hero-shell, .ks-home-departments, .card-product, .product-list-wrap, .tf-grid-product-item')) return;
      var raw = [node.id || '', node.className || '', textOf(node).slice(0, 300), node.getAttribute ? (node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('alt') || '') : ''].join(' ');
      if (!containsToken(raw)) return;
      hideNode(artifactRoot(node), 'data-ks-home-artifact');
    });
  }

  function hideTemplateDemoMenus() {
    Array.prototype.slice.call(document.querySelectorAll('.mega-home, .row-demo, .demo-item, a, img, div, section')).forEach(function (node) {
      if (!node) return;
      var raw = [
        node.id || '',
        node.className || '',
        textOf(node).slice(0, 260),
        node.getAttribute ? (node.getAttribute('href') || node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('alt') || '') : ''
      ].join(' ');
      if (!containsTemplateDemo(raw)) return;
      hideNode(bodyLevelRoot(node), 'data-ks-template-demo');
    });
  }

  function hideDirectBodySiblings() {
    if (!document.body) return;
    Array.prototype.slice.call(document.body.children).forEach(function (node) {
      if (!node || /^(script|style|form|main|header|footer)$/i.test(node.tagName)) return;
      var rect = rectOf(node);
      if (!rect) return;
      var raw = [node.id || '', node.className || '', textOf(node).slice(0, 320)].join(' ');
      if (containsToken(raw) || containsTemplateDemo(raw)) {
        hideNode(node, 'data-ks-body-artifact');
      }
    });
  }

  function hideBodyHeaderClones() {
    var header = document.querySelector('header');
    var headerBottom = header ? (rectOf(header) || { bottom: 0 }).bottom : 0;
    Array.prototype.slice.call(document.querySelectorAll('header, div, section')).forEach(function (node) {
      if (!node || node === header) return;
      if (header && header.contains(node)) return;
      var rect = rectOf(node);
      if (!rect || rect.top < headerBottom + 120) return;
      if (rect.width < window.innerWidth * 0.55 || rect.height < 24 || rect.height > 260) return;
      var raw = normalizeText([node.className || '', textOf(node).slice(0, 300)].join(' '));
      var hasHeaderText = /cerca prodotti|tutti i settori|il mio account|assistenza|spedizione gratuita|chiamaci gratis|catalogo|carrello/.test(raw);
      if (hasHeaderText || containsTemplateDemo(raw)) hideNode(node, 'data-ks-header-clone');
    });
  }

  function hideFixedArtifactsOutsideLane() {
    var lane = primaryLaneRect();
    Array.prototype.slice.call(document.querySelectorAll('div,section,aside,a,span,p,img')).forEach(function (node) {
      if (!node) return;
      if (node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-hero-shell, .ks-home-departments, .card-product, .product-list-wrap, .tf-grid-product-item')) return;
      var st = styleOf(node);
      var rect = rectOf(node);
      if (!st || !rect) return;
      var pos = st.position || '';
      if (pos !== 'fixed' && pos !== 'absolute' && pos !== 'sticky') return;
      var outsideLane = rect.right <= lane.left + 20 || rect.left >= lane.right - 20;
      if (!outsideLane) return;
      if (rect.width > 320 || rect.height < 18) return;
      hideNode(artifactRoot(node), 'data-ks-fixed-artifact');
    });
  }

  function hideEdgeMediaRails() {
    var lane = primaryLaneRect();
    var buckets = {};
    Array.prototype.slice.call(document.querySelectorAll('img')).forEach(function (img) {
      if (!img) return;
      if (img.closest && img.closest('header, footer, .ks-home-hero-shell, .ks-home-departments, .card-product, .product-list-wrap, .tf-grid-product-item, .modal.show, .offcanvas.show, .ks-top-catalog-mega')) return;
      var rect = rectOf(img);
      if (!rect || rect.width < 20 || rect.height < 24 || rect.width > 180 || rect.height > 220) return;
      var outsideLane = rect.right <= lane.left + 20 || rect.left >= lane.right - 20;
      if (!outsideLane) return;
      var key = (rect.left < lane.left ? 'L' : 'R') + ':' + Math.round(rect.left / 40) + ':' + Math.round(rect.width / 15);
      (buckets[key] = buckets[key] || []).push(img);
    });
    Object.keys(buckets).forEach(function (key) {
      if (buckets[key].length < 3) return;
      buckets[key].forEach(function (img) { hideNode(artifactRoot(img), 'data-ks-home-artifact'); });
    });
  }

  function runHomeCleanup() {
    if (!isHomePage()) return;
    suppressNewsletterPopup();
    compactHero();
    hideTemplateDemoMenus();
    hideDirectBodySiblings();
    hideWelcomeFranchising();
    hideBodyHeaderClones();
    hideFixedArtifactsOutsideLane();
    hideEdgeMediaRails();
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
      [300, 900, 2200, 5000].forEach(function (delay) { window.setTimeout(runHomeCleanup, delay); });
      window.addEventListener('load', runHomeCleanup, { once: true });
      window.addEventListener('resize', runHomeCleanup);
    }
  });
})();
