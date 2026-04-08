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
    var path = normalizePath(window.location.pathname || '/');
    return path === '/' || /\/default\.aspx$/i.test(window.location.pathname || '');
  }

  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
  }

  function disableTemplatePopupStorage() {
    try {
      if (!isHomePage()) return;
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
    } catch (err) {
      return;
    }
  }

  function clearStaleUiLock() {
    if (!isHomePage()) return;
    if (document.querySelector('.modal.show, .offcanvas.show')) return;
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
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
    var escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
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
    document.cookie = name + '=' + encodeURIComponent(value) + expires + '; path=/; SameSite=Lax';
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
      window.sessionStorage.setItem(SESSION_KEY, list.join(','));
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

    var body = document.body;
    if (body) {
      var dataId = parseInt(body.getAttribute('data-article-id') || body.getAttribute('data-id') || '', 10);
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



  function injectHomeRuntimeCss() {
    if (!isHomePage()) return;
    if (document.getElementById('ks-home-runtime-step5')) return;

    var style = document.createElement('style');
    style.id = 'ks-home-runtime-step5';
    style.type = 'text/css';
    style.appendChild(document.createTextNode([
      "body.ks-page-home .ks-home-submenu-container[aria-hidden='true']{display:none!important;}",
      "body.ks-page-home [data-ks-edge-creative='1'],body.ks-page-home [data-ks-blocked-home-node='1'],body.ks-page-home [data-ks-hidden-block='1']{display:none!important;}",
      "@media (min-width:1200px){",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2,",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2>.ks-home-hero-slider,",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2 .swiper,",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2 .swiper-wrapper,",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2 .swiper-slide,",
      "body.ks-page-home .ks-home-hero-shell.ks-home-hero-mode-compact-single .wrap-item-2 .banner-image-product-4{height:100%!important;min-height:100%!important;}",
      "}"
    ].join('')));
    (document.head || document.documentElement).appendChild(style);
  }

  function normalizeText(value) {
    return String(value || '')
      .toLowerCase()
      .replace(/[àáâãäå]/g, 'a')
      .replace(/[èéêë]/g, 'e')
      .replace(/[ìíîï]/g, 'i')
      .replace(/[òóôõö]/g, 'o')
      .replace(/[ùúûü]/g, 'u')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function containsBlockedCreativeToken(text) {
    var value = normalizeText(text);
    var blocked = ['welcome', 'franchis', 'onsus', 'themesflat', 'themeforest', 'demo', 'placeholder', 'sample', 'template'];
    return blocked.some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function hideNode(node, attrName) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
    if (attrName) {
      node.setAttribute(attrName, '1');
    }
  }

  function textContentOf(node) {
    return String(node && node.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function hasProtectedAncestor(node) {
    if (!node || !node.closest) return false;
    return !!node.closest([
      '.tf-header', '.tf-footer', 'header', 'footer',
      '.ks-home-departments', '.tf-icon-box', '.ks-home-brands',
      '.card-product', '.ks-card-product', '.ks-grid-card', '.ks-row-card', '.ks-big-card', '.ks-deal-card',
      '.wrap-item-2', '.wrap-item-3', '.box-btn-slide-item', '.tf-grid-product-item',
      '.container .row', '.swiper', '.sw-dot-default'
    ].join(','));
  }

  function rectOf(node) {
    if (!node || typeof node.getBoundingClientRect !== 'function') return null;
    var rect = node.getBoundingClientRect();
    if (!rect || (!rect.width && !rect.height)) return null;
    return rect;
  }

  function isEdgeRect(rect) {
    if (!rect) return false;
    if (rect.width < 28 || rect.height < 28) return false;
    if (rect.width > 220 || rect.height > 720) return false;
    return rect.left <= 48 || rect.right >= (window.innerWidth - 48);
  }

  function normalizeSrc(src) {
    return String(src || '')
      .replace(/^https?:/i, '')
      .replace(/[?#].*$/, '')
      .trim();
  }

  function edgeCreativeRoot(node) {
    var current = node;
    var best = node;
    var hops = 0;

    while (current && current.parentElement && hops < 4) {
      var parent = current.parentElement;
      if (hasProtectedAncestor(parent)) break;
      var rect = rectOf(parent);
      if (!rect || !isEdgeRect(rect)) break;
      if (rect.width <= 260 && rect.height <= 900) {
        best = parent;
      }
      current = parent;
      hops += 1;
    }

    return best;
  }

  function elementLooksBlocked(node) {
    if (!node) return false;
    var raw = [
      node.id || '',
      node.className || '',
      node.getAttribute && node.getAttribute('src') || '',
      node.getAttribute && node.getAttribute('data-src') || '',
      node.getAttribute && node.getAttribute('alt') || '',
      textContentOf(node).slice(0, 160)
    ].join(' ');
    return containsBlockedCreativeToken(raw);
  }

  function sweepBlockedEdgeCreatives() {
    if (!isHomePage()) return;

    Array.prototype.slice.call(document.querySelectorAll('img, a, div, span, p')).forEach(function (node) {
      if (!node || hasProtectedAncestor(node)) return;
      if (!elementLooksBlocked(node)) return;
      var rect = rectOf(node);
      if (!isEdgeRect(rect)) return;
      hideNode(edgeCreativeRoot(node), 'data-ks-blocked-home-node');
    });
  }

  function sweepRepeatedEdgeDevices() {
    if (!isHomePage()) return;

    var bySrc = Object.create(null);
    Array.prototype.slice.call(document.querySelectorAll('img')).forEach(function (img) {
      if (!img || hasProtectedAncestor(img)) return;
      var rect = rectOf(img);
      if (!isEdgeRect(rect)) return;
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

  function setHeroHeight(node, value) {
    if (!node) return;
    node.style.minHeight = value;
    node.style.height = value;
  }

  function fixCompactHeroHeight() {
    if (!isHomePage()) return;

    var shell = document.querySelector('.ks-home-hero-shell');
    var sliderWrap = shell ? shell.querySelector('.wrap-item-2') : null;
    var sideWrap = shell ? shell.querySelector('.wrap-item-3') : null;
    var menuList = document.querySelector('.ks-home-departments .menu-category-list');

    if (!shell || !sliderWrap) return;

    if (window.innerWidth < 1200) {
      [sliderWrap, sliderWrap.querySelector('.ks-home-hero-slider'), sliderWrap.querySelector('.banner-image-product-4'), sliderWrap.querySelector('.swiper'), sliderWrap.querySelector('.swiper-wrapper')].forEach(function (node) {
        if (!node) return;
        node.style.minHeight = '';
        node.style.height = '';
      });
      Array.prototype.slice.call(sliderWrap.querySelectorAll('.swiper-slide')).forEach(function (slide) {
        slide.style.minHeight = '';
        slide.style.height = '';
      });
      return;
    }

    var sideVisible = !!(sideWrap && sideWrap.offsetParent !== null && sideWrap.getBoundingClientRect().width > 40 && sideWrap.getBoundingClientRect().height > 80);
    if (sideVisible) return;

    var shellRect = rectOf(shell);
    var menuRect = rectOf(menuList);
    var sliderRect = rectOf(sliderWrap);
    var target = Math.max(shellRect ? shellRect.height : 0, menuRect ? menuRect.height : 0);

    if (!target || !sliderRect || target <= sliderRect.height + 40) return;

    var value = Math.ceil(target) + 'px';
    setHeroHeight(sliderWrap, value);
    setHeroHeight(sliderWrap.querySelector('.ks-home-hero-slider'), value);
    setHeroHeight(sliderWrap.querySelector('.banner-image-product-4'), value);
    setHeroHeight(sliderWrap.querySelector('.swiper'), value);
    setHeroHeight(sliderWrap.querySelector('.swiper-wrapper'), value);
    Array.prototype.slice.call(sliderWrap.querySelectorAll('.swiper-slide')).forEach(function (slide) {
      setHeroHeight(slide, value);
    });
  }

  function cardList(root) {
    return Array.prototype.slice.call((root || document).querySelectorAll('.card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card'));
  }

  function validCard(card) {
    if (!card || card.offsetParent === null) return false;
    if (card.getAttribute('data-ks-hidden-block') === '1') return false;

    var title = card.querySelector('.name-product, h6 a, h5 a, a.title');
    var image = card.querySelector('img');
    var src = image ? (image.getAttribute('src') || image.getAttribute('data-src') || '') : '';
    var titleText = normalizeText(title ? title.textContent : '');

    if (!titleText || titleText.length < 3) return false;
    if (!src) return false;
    return true;
  }

  function headingText(node) {
    return normalizeText(node ? node.textContent : '');
  }

  function sectionTitleMap() {
    return {
      'scelti da te': 2,
      'top 20': 3,
      'in evidenza': 3,
      'i piu venduti': 3,
      'in offerta': 3
    };
  }

  function sectionBlockFromHeading(heading) {
    return heading.closest('.tf-grid-product-item') ||
      heading.closest('[id$="Section"]') ||
      heading.closest('[id*="Section"]') ||
      heading.closest('section') ||
      heading.parentElement;
  }

  function collapseBrokenEditorialBlocks() {
    if (!isHomePage()) return;

    var thresholds = sectionTitleMap();
    Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).forEach(function (heading) {
      var label = headingText(heading);
      if (!thresholds[label]) return;
      if (heading.closest('.menu-tab-line') || heading.closest('.flat-title-tab-default')) return;

      var block = sectionBlockFromHeading(heading);
      if (!block) return;

      var cards = cardList(block);
      if (!cards.length) return;

      var valid = 0;
      cards.forEach(function (card) {
        if (validCard(card)) {
          valid += 1;
          return;
        }
        hideNode(card, 'data-ks-hidden-block');
        var slide = card.closest('.swiper-slide');
        if (slide && cardList(slide).length <= 1) {
          hideNode(slide, 'data-ks-hidden-block');
        }
      });

      if (valid < thresholds[label]) {
        hideNode(block, 'data-ks-hidden-block');
      }
    });
  }

  function runHomeRuntimeSweep() {
    if (!isHomePage()) return;
    injectHomeRuntimeCss();
    clearStaleUiLock();
    sweepBlockedEdgeCreatives();
    sweepRepeatedEdgeDevices();
    collapseBrokenEditorialBlocks();
    fixCompactHeroHeight();
  }

  function armHomeRuntimeSweep() {
    if (!isHomePage()) return;

    [0, 250, 900, 2200].forEach(function (delay) {
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
    var recent = readMergedRecent();
    if (recent.length >= 2) {
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
    injectHomeRuntimeCss();
    runHomeRuntimeSweep();
    armHomeRuntimeSweep();
    clearStaleUiLock();
    window.addEventListener('load', runHomeRuntimeSweep, { once: true });
    window.addEventListener('resize', runHomeRuntimeSweep);
  });
})();
