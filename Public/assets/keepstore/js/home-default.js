(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    return new Swiper(root, options);
  }

  function hideNode(node) {
    if (!node) return;
    node.style.display = 'none';
    node.setAttribute('data-ks-hidden', '1');
  }

  function showNode(node, value) {
    if (!node) return;
    node.style.display = value || '';
    node.removeAttribute('data-ks-hidden');
  }

  function removeNode(node) {
    if (!node) return;
    if (node.parentNode) {
      node.parentNode.removeChild(node);
    }
  }

  function textContentOf(node) {
    return normalizeText(node ? node.textContent : '');
  }

  var _scopeUidSeed = 0;

  function ensureNodeUid(node) {
    if (!node) return 'ks-scope-missing';
    if (!node.__ksScopeUid) {
      _scopeUidSeed += 1;
      node.__ksScopeUid = 'ks-scope-' + _scopeUidSeed;
    }
    return node.__ksScopeUid;
  }

  function styleTextOf(node) {
    if (!node || !node.getAttribute) return '';
    return node.getAttribute('style') || '';
  }

  function isSafeUiContainer(node) {
    if (!node || !node.closest) return false;
    return !!node.closest('#goTop, header, .tf-header, .tf-topbar, footer, .modal, .offcanvas, .toast, .popover, .tooltip, .grecaptcha-badge, .grecaptcha, .cc-window, .cc-banner, .cc-revoke, .swal2-container, [role="dialog"], [aria-live], [data-ks-floating-safe="1"], .chat, .whatsapp, .messenger');
  }

  function firstPositionedAncestor(node) {
    var current = node;
    var absoluteCandidate = null;
    while (current && current !== document.body) {
      var style = window.getComputedStyle(current);
      var position = style ? style.position : '';
      if (position === 'fixed' || position === 'sticky') {
        return current;
      }
      if (!absoluteCandidate && position === 'absolute') {
        absoluteCandidate = current;
      }
      current = current.parentElement;
    }
    return absoluteCandidate;
  }

  function floatingSeedNodes() {
    return Array.prototype.slice.call(document.querySelectorAll('img, [style*="position:fixed"], [style*="position:sticky"], [style*="position:absolute"]'));
  }

  function hasAllowedFloatingToken(text) {
    return /(cookie|consent|recaptcha|chat|messenger|whatsapp|support|help|assistant|account|cart|wishlist|compare|search|language|currency|login|close|menu|toggle|top)/i.test(text || '');
  }

  function looksImageHeavy(node) {
    if (!node) return false;
    var imgs = node.tagName === 'IMG' ? [node] : Array.prototype.slice.call(node.querySelectorAll('img'));
    if (!imgs.length) return false;
    var rawText = normalizeText(node.textContent || '');
    return imgs.length >= 2 || rawText.length <= 30;
  }

  function edgePinned(rect) {
    if (!rect) return false;
    return rect.left <= 24 || (window.innerWidth - rect.right) <= 24;
  }

  function suspiciousFloatingCreative(node) {
    if (!node || node === document.body || isSafeUiContainer(node)) return false;

    var rect = node.getBoundingClientRect();
    if (!rect || rect.width < 36 || rect.height < 36) return false;
    if (rect.bottom < 0 || rect.top > window.innerHeight) return false;

    var computed = window.getComputedStyle(node);
    var position = computed ? computed.position : '';
    if (position !== 'fixed' && position !== 'sticky' && position !== 'absolute') return false;

    var imgs = node.tagName === 'IMG' ? [node] : Array.prototype.slice.call(node.querySelectorAll('img'));
    if (!imgs.length) return false;

    var raw = [
      node.id || '',
      node.className || '',
      styleTextOf(node),
      textContentOf(node)
    ].concat(imgs.slice(0, 8).map(function (img) {
      return [img.getAttribute('src') || '', img.getAttribute('data-src') || '', img.getAttribute('alt') || '', styleTextOf(img)].join(' ');
    })).join(' ');

    if (hasAllowedFloatingToken(raw)) return false;
    if (!edgePinned(rect)) return false;
    if (rect.width < 72 && rect.height < 92) return false;
    if (!looksImageHeavy(node)) return false;

    if (position === 'absolute') {
      return containsBlockedCreativeToken(raw);
    }

    return containsBlockedCreativeToken(raw) || position === 'fixed' || rect.height >= 92 || imgs.length >= 2;
  }

  function hideFloatingCreative(node) {
    if (!node) return;
    node.setAttribute('data-ks-floating-creative', '1');
    hideNode(node);
  }

  function pruneFloatingCreatives() {
    var seen = [];
    floatingSeedNodes().forEach(function (seed) {
      if (!seed || isSafeUiContainer(seed)) return;

      var candidate = firstPositionedAncestor(seed) || seed;
      if (!candidate || candidate === document.body || seen.indexOf(candidate) !== -1) return;
      seen.push(candidate);

      if (suspiciousFloatingCreative(candidate)) {
        hideFloatingCreative(candidate);
      }
    });
  }

  function backgroundImageValue(node) {
    if (!node) return '';
    var style = window.getComputedStyle(node);
    return style ? (style.backgroundImage || '') : '';
  }

  function auditBlockedBackgrounds() {
    Array.prototype.slice.call(document.querySelectorAll('.cls-category, .ks-side-promo-card, .ks-home-sector-promo, .banner-image-product, .banner-image-product-2, .banner-image-product-4, [style*="background-image"]')).forEach(function (node) {
      var bg = backgroundImageValue(node);
      if (!bg || bg === 'none') return;
      var raw = [node.id || '', node.className || '', bg, textContentOf(node)].join(' ');
      if (containsBlockedCreativeToken(raw)) {
        hideBlockedCreativeRoot(blockedCreativeRoot(node));
      }
    });
  }

  function sweepRogueCreatives() {
    auditBlockedCreatives();
    auditBlockedBackgrounds();
    pruneFloatingCreatives();
  }

  function isNewsletterPopup(node) {
    if (!node) return false;
    var raw = [node.id || '', node.className || '', node.getAttribute && node.getAttribute('data-bs-target') || '', node.getAttribute && node.getAttribute('aria-label') || '', textContentOf(node)].join(' ');
    var value = normalizeText(raw);
    return value.indexOf('auto popup') !== -1 ||
      value.indexOf('modal newleter') !== -1 ||
      value.indexOf('newsletter') !== -1 ||
      value.indexOf('subscribe') !== -1 ||
      value.indexOf('sib form') !== -1 ||
      value.indexOf('email address') !== -1;
  }

  function disableTemplatePopupStorage() {
    try {
      window.sessionStorage.setItem('showPopup', 'true');
      window.localStorage.setItem('showPopup', 'true');
    } catch (err) {
      return;
    }
  }

  function clearStaleUiLock() {
    if (document.querySelector('.modal.show, .offcanvas.show')) return;
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function suppressTemplatePopupOnce() {
    disableTemplatePopupStorage();

    if (document.body) {
      document.body.classList.add('ks-home-popup-disabled');
    }

    Array.prototype.slice.call(document.querySelectorAll('.auto-popup, .modal-newleter')).forEach(function (modal) {
      if (isNewsletterPopup(modal)) {
        removeNode(modal);
      }
    });

    Array.prototype.slice.call(document.querySelectorAll('.sib-form, .sib-form-container, #sib-form-container')).forEach(function (node) {
      var modal = node.closest ? node.closest('.auto-popup, .modal-newleter') : null;
      if (modal && isNewsletterPopup(modal)) {
        removeNode(modal);
      }
    });

    var keepBackdrop = document.querySelector('.modal.show:not(.auto-popup):not(.modal-newleter), .offcanvas.show');
    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function (backdrop) {
      if (!keepBackdrop) {
        backdrop.classList.add('ks-orphan-overlay');
        removeNode(backdrop);
      }
    });

    clearStaleUiLock();
  }

  function armPopupWatchdog() {
    var ticks = 0;
    suppressTemplatePopupOnce();

    var timer = window.setInterval(function () {
      ticks += 1;
      suppressTemplatePopupOnce();
      if (ticks >= 24) {
        window.clearInterval(timer);
      }
    }, 500);

    if (!document.body || typeof MutationObserver === 'undefined') return;
    var observer = new MutationObserver(function (mutations) {
      var shouldSweep = mutations.some(function (mutation) {
        return Array.prototype.slice.call(mutation.addedNodes || []).some(function (node) {
          if (!node || node.nodeType !== 1) return false;
          if (isNewsletterPopup(node)) return true;
          return !!(node.querySelector && node.querySelector('.auto-popup, .modal-newleter, .sib-form-container, .modal-backdrop, .offcanvas-backdrop'));
        });
      });
      if (shouldSweep) {
        suppressTemplatePopupOnce();
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
    window.setTimeout(function () { observer.disconnect(); }, 15000);
  }

  function hideBlockedCreativeRoot(node) {
    if (!node) return;
    node.setAttribute('data-ks-blocked-creative', '1');
    hideNode(node);
  }

  function blockedCreativeRoot(node) {
    if (!node || !node.closest) return node;
    return node.closest('.cls-category, .ks-home-sector-promo, .ks-side-promo-card, .banner-image-product, .banner-image-product-2, .banner-image-product-4, .swiper-slide') || node;
  }

  function auditBlockedCreatives() {
    Array.prototype.slice.call(document.querySelectorAll('img')).forEach(function (img) {
      var contextText = [img.getAttribute('src') || img.getAttribute('data-src') || '', img.getAttribute('alt') || '', textContentOf(img.parentElement), textContentOf(img.closest ? img.closest('.cls-category, .ks-home-sector-promo, .ks-side-promo-card, .banner-image-product, .banner-image-product-2, .banner-image-product-4, .swiper-slide') : null)].join(' ');
      if (!containsBlockedCreativeToken(contextText)) return;
      hideBlockedCreativeRoot(blockedCreativeRoot(img));
    });
  }

  function bindDesktopHomeMenuIsolation() {
    var root = document.querySelector('.ks-home-departments');
    if (!root) return;

    function closeAll() {
      eachHomeMenuItem(function (item) {
        var submenu = submenuOf(item);
        var toggle = toggleOf(item);
        if (!submenu) return;
        if (window.innerWidth >= 1200) {
          submenu.style.display = 'none';
        }
        submenu.setAttribute('aria-hidden', 'true');
        item.classList.remove('is-open');
        if (toggle) toggle.setAttribute('aria-expanded', 'false');
      });
    }

    if (!root.getAttribute('data-ks-desktop-bound')) {
      root.setAttribute('data-ks-desktop-bound', '1');
      root.addEventListener('mouseleave', function () {
        if (window.innerWidth >= 1200) {
          closeAll();
        }
      });
      eachHomeMenuItem(function (item) {
        if (item.getAttribute('data-ks-desktop-listener') === '1') return;
        item.setAttribute('data-ks-desktop-listener', '1');
        item.addEventListener('mouseenter', function () {
          if (window.innerWidth < 1200) return;
          closeAll();
          var submenu = submenuOf(item);
          if (!submenu || item.getAttribute('data-ks-has-children') === '0') return;
          submenu.style.display = 'flex';
          submenu.setAttribute('aria-hidden', 'false');
        });
      });
    }

    if (window.innerWidth >= 1200) {
      closeAll();
    }
  }

  function updateAllSwipers() {
    Array.prototype.slice.call(document.querySelectorAll('.swiper')).forEach(function (swiperEl) {
      if (swiperEl.swiper && typeof swiperEl.swiper.update === 'function') {
        swiperEl.swiper.update();
      }
    });
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

  function stripEditorialNoise(value) {
    var normalized = normalizeText(value);
    if (!normalized) return '';

    var phraseBlocked = [
      'tempered glass', 'ultra clear', 'clear case', 'cover case', 'flip case', 'back cover', 'full glue',
      'ricondizionato grado', 'ricondizionato grade', 'confezione bulk', 'pack da', 'set da', 'pezzi per'
    ];

    phraseBlocked.forEach(function (phrase) {
      normalized = normalized.replace(new RegExp(phrase.replace(/ /g, '\\s+'), 'g'), ' ');
    });

    return normalized
      .replace(/\b(colore|color|colours?)\b/g, ' ')
      .replace(/\b(black|white|red|blue|green|yellow|pink|gold|silver|grey|gray)\b/g, ' ')
      .replace(/\b(nero|bianco|rosso|blu|verde|giallo|rosa|oro|argento|grigio|trasparente|clear)\b/g, ' ')
      .replace(/\b(case|cover|custodia|shell|glass|tempered|protector|silicone|vetro|pellicola|covering)\b/g, ' ')
      .replace(/\b(ricondizionato|refurbished|bulk|blister|pack|pezzi|pz|piece|pcs)\b/g, ' ')
      .replace(/\b(xl|xxl|mini|max|plus|pro|lite|ultra)\b/g, ' $1 ')
      .replace(/\b\d+(mm|cm|gb|tb|mah|w|hz|inch|in|pollici?)\b/g, ' ')
      .replace(/\b\d+\b/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function displayKey(value) {
    var normalized = stripEditorialNoise(value);
    if (!normalized) return '';

    var blocked = ['mm', 'cm', 'gb', 'tb', 'taglia', 'colore', 'edition', 'versione', 'modello'];
    var tokens = normalized.split(' ').filter(function (token) {
      if (!token) return false;
      return blocked.indexOf(token) === -1;
    });

    return tokens.slice(0, 10).join(' ');
  }

  function containsBlockedCreativeToken(text) {
    var value = normalizeText(text);
    var blocked = ['welcome', 'franchis', 'onsus', 'themesflat', 'themeforest', 'demo', 'placeholder', 'sample', 'template'];
    return blocked.some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function isValidCreativeImage(img, kind) {
    if (!img) return false;

    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    var alt = img.getAttribute('alt') || '';
    if (!src) return false;
    if (containsBlockedCreativeToken(src) || containsBlockedCreativeToken(alt)) return false;

    var width = Number(img.naturalWidth || 0);
    var height = Number(img.naturalHeight || 0);
    if (width <= 0 || height <= 0) return false;
    if (width < 220 || height < 110) return false;

    var ratio = width / height;
    if (kind === 'hero') {
      return ratio >= 1.2 && ratio <= 5.2;
    }

    return ratio >= 0.75 && ratio <= 4.8;
  }

  function isPlausibleLogo(img) {
    if (!img) return false;
    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    var alt = img.getAttribute('alt') || '';
    if (!src) return false;
    if (containsBlockedCreativeToken(src) || containsBlockedCreativeToken(alt)) return false;
    if (/(banner|hero|promo|slider|product|articolo|phone|tablet|monitor|welcome|franchis)/i.test(src + ' ' + alt)) return false;
    var width = Number(img.naturalWidth || 0);
    var height = Number(img.naturalHeight || 0);
    if (width <= 0 || height <= 0) return false;
    if (width < 60 || height < 18) return false;
    var ratio = width / height;
    return ratio >= 0.6 && ratio <= 9;
  }

  function markInvalidCreative(node) {
    if (!node) return;
    node.setAttribute('data-ks-invalid', '1');
    hideNode(node);
  }

  function countValidNodes(nodes) {
    return nodes.filter(function (node) {
      return node && node.getAttribute('data-ks-invalid') !== '1' && node.getAttribute('data-ks-hidden') !== '1';
    }).length;
  }

  function applyHeroMode(mode) {
    var section = document.getElementById('HomeHeroSection');
    var shell = document.getElementById('HomeHeroShell');
    var sliderWrap = document.getElementById('HeroSliderWrap');
    var sideWrap = document.getElementById('HeroSideWrap');
    var normalized = (mode || 'none').toLowerCase();

    function replaceModeClass(node) {
      if (!node) return;
      node.className = String(node.className || '')
        .replace(/\bks-home-hero-mode-[^\s]+\b/g, '')
        .replace(/\s+/g, ' ')
        .trim();
      node.className = (node.className + ' ks-home-hero-mode-' + normalized)
        .replace(/\s+/g, ' ')
        .trim();
    }

    replaceModeClass(section);
    replaceModeClass(shell);

    if (normalized === 'none') {
      hideNode(section);
      hideNode(sliderWrap);
      hideNode(sideWrap);
      return;
    }

    showNode(section);
    showNode(sliderWrap);

    if (normalized === 'full') {
      showNode(sideWrap, 'flex');
    } else {
      hideNode(sideWrap);
    }
  }

  function auditHeroAssets(done) {
    var heroSlides = Array.prototype.slice.call(document.querySelectorAll('.ks-home-hero-slider .swiper-slide'));
    var sideCards = Array.prototype.slice.call(document.querySelectorAll('.ks-home-side-banners .ks-side-promo-card, #HeroSideWrap .cls-category, #HeroSideWrap .ks-side-banner'));
    var auditTargets = [];
    var pending = 0;
    var completed = false;

    function finalize() {
      if (completed) return;
      completed = true;

      var validHeroSlides = countValidNodes(heroSlides);
      var validSideCards = countValidNodes(sideCards);

      if (validHeroSlides <= 0) {
        applyHeroMode('none');
      } else if (validSideCards >= 2) {
        applyHeroMode('full');
      } else {
        applyHeroMode('compact-single');
      }

      if (typeof done === 'function') {
        done();
      }
    }

    function inspect(entry) {
      if (!isValidCreativeImage(entry.img, entry.kind)) {
        markInvalidCreative(entry.node);
      }
    }

    function attachAudit(entry) {
      var img = entry.img;
      if (!img) {
        markInvalidCreative(entry.node);
        return;
      }

      if (img.complete) {
        inspect(entry);
        return;
      }

      pending += 1;
      var handled = false;

      function finish(success) {
        if (handled) return;
        handled = true;
        if (!success) {
          markInvalidCreative(entry.node);
        } else {
          inspect(entry);
        }
        pending -= 1;
        if (pending <= 0) {
          finalize();
        }
      }

      img.addEventListener('load', function () { finish(true); }, { once: true });
      img.addEventListener('error', function () { finish(false); }, { once: true });
    }

    heroSlides.forEach(function (slide) {
      var img = slide.querySelector('img');
      if (!img) {
        markInvalidCreative(slide);
        return;
      }
      auditTargets.push({ kind: 'hero', node: slide, img: img });
    });

    sideCards.forEach(function (card) {
      var img = card.querySelector('img');
      if (!img) {
        markInvalidCreative(card);
        return;
      }
      auditTargets.push({ kind: 'side', node: card, img: img });
    });

    if (!auditTargets.length) {
      finalize();
      return;
    }

    auditTargets.forEach(attachAudit);

    if (pending <= 0) {
      finalize();
    }
  }

  function visibleSlideCount(root) {
    return Array.prototype.slice.call((root || document).querySelectorAll('.swiper-slide')).filter(function (slide) {
      return slide.offsetParent !== null && slide.getAttribute('data-ks-hidden') !== '1' && slide.getAttribute('data-ks-invalid') !== '1';
    }).length;
  }

  function initHero() {
    var hero = document.querySelector('.ks-home-hero-slider');
    if (!hero) return;

    var slides = Array.prototype.slice.call(hero.querySelectorAll('.swiper-slide')).filter(function (slide) {
      return slide.getAttribute('data-ks-invalid') !== '1';
    });
    var allowLoop = slides.length > 1;
    var prev = hero.querySelector('.ks-hero-prev');
    var next = hero.querySelector('.ks-hero-next');
    var pag = hero.querySelector('.ks-hero-pagination');

    buildSwiper(hero, {
      loop: allowLoop,
      effect: 'slide',
      speed: 700,
      autoplay: allowLoop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false,
      pagination: { el: pag, clickable: true },
      navigation: { nextEl: next, prevEl: prev }
    });

    if (!allowLoop) {
      hideNode(prev);
      hideNode(next);
      hideNode(pag);
    }
  }

  function initBrandSlider() {
    var brand = document.querySelector('.ks-home-brands');
    if (!brand) return;
    buildSwiper(brand, {
      loop: visibleSlideCount(brand) > 6,
      slidesPerView: 2,
      spaceBetween: 15,
      breakpoints: {
        576: { slidesPerView: 3, spaceBetween: 15 },
        768: { slidesPerView: 4, spaceBetween: 20 },
        1200: { slidesPerView: 6, spaceBetween: 30 }
      },
      pagination: {
        el: brand.querySelector('.ks-home-brands-pagination'),
        clickable: true
      },
      autoplay: { delay: 3500, disableOnInteraction: false }
    });
  }

  function initCollectionSlider() {
    var slider = document.querySelector('.ks-home-collection-swiper');
    if (!slider) return;
    buildSwiper(slider, {
      loop: visibleSlideCount(slider) > 4,
      slidesPerView: 1,
      spaceBetween: 15,
      breakpoints: {
        576: { slidesPerView: 2, spaceBetween: 15 },
        768: { slidesPerView: 3, spaceBetween: 20 },
        1200: { slidesPerView: 4, spaceBetween: 30 }
      },
      pagination: {
        el: slider.querySelector('.ks-home-collection-pagination'),
        clickable: true
      },
      autoplay: { delay: 4000, disableOnInteraction: false }
    });
  }

  function initColumnSwipers() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-column-swiper')).forEach(function (el) {
      if (!el || el.swiper || typeof Swiper === 'undefined') return;

      var wrapper = el.closest('.box-btn-slide-item') || el.parentElement;
      var prev = wrapper ? wrapper.querySelector('.ks-col-prev') : null;
      var next = wrapper ? wrapper.querySelector('.ks-col-next') : null;
      var pag = el.querySelector('.ks-col-pagination');
      var slides = visibleSlideCount(el);

      buildSwiper(el, {
        loop: slides > 1,
        slidesPerView: 1,
        spaceBetween: 20,
        pagination: { el: pag, clickable: true },
        navigation: { nextEl: next, prevEl: prev },
        autoplay: slides > 1 ? { delay: 4500, disableOnInteraction: false } : false
      });

      if (slides <= 1) {
        hideNode(prev);
        hideNode(next);
        hideNode(pag);
      }
    });
  }

function cardTypeOf(infoNode) {
  var card = infoNode ? infoNode.closest('.card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card') : null;
  if (!card) return 'base';
  var classes = String(card.className || '');
  if (card.classList.contains('ks-big-card') || /\bstyle-thums-2\b/i.test(classes)) return 'big';
  if (card.classList.contains('ks-row-card') || /\bstyle-row\b/i.test(classes)) return 'row';
  if (card.classList.contains('ks-grid-card') || /\bstyle-img-border\b/i.test(classes)) return 'grid';
  if (card.classList.contains('ks-deal-card')) return 'deal';
  if (/\bstyle-border\b/i.test(classes)) return 'border';
  return 'base';
}

function cardScopeOf(infoNode) {
  var card = infoNode ? infoNode.closest('.card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card') : null;
  if (!card) return document.body;
  return card.closest('.product-list-wrap, .swiper-wrapper, .tab-pane, .tf-grid-product-item, .grid-cls, section, .container') || document.body;
}

function normalizeCardHeights() {
  var nodes = Array.prototype.slice.call(document.querySelectorAll('.card-product .card-product-info, .ks-grid-card .card-product-info, .ks-row-card .card-product-info, .ks-big-card .card-product-info, .ks-deal-card .card-product-info')).filter(function (node) {
    return node && node.offsetParent !== null;
  });

  nodes.forEach(function (node) {
    node.style.minHeight = '0px';
  });

  if (window.innerWidth < 992 || !nodes.length) return;

  var groups = {};
  nodes.forEach(function (node) {
    var scope = cardScopeOf(node);
    var key = ensureNodeUid(scope) + '|' + cardTypeOf(node);
    if (!groups[key]) groups[key] = [];
    groups[key].push(node);
  });

  Object.keys(groups).forEach(function (key) {
    var group = groups[key];
    if (!group || group.length < 2) return;

    var heights = group.map(function (node) {
      return node.offsetHeight || 0;
    }).filter(function (height) {
      return height > 0;
    }).sort(function (a, b) {
      return a - b;
    });

    if (!heights.length) return;

    var median = heights[Math.floor(heights.length / 2)];
    var max = heights[heights.length - 1];
    var spread = max - heights[0];

    if (spread > 140 && group.length <= 3) {
      return;
    }

    var target = Math.min(max, median + 80);
    if (target < median) target = median;

    group.forEach(function (node) {
      node.style.minHeight = target + 'px';
    });
  });
}

function syncHeroLayout() {

    var shell = document.querySelector('.ks-home-hero-shell');
    var menu = document.querySelector('.ks-home-departments .menu-category-list');
    if (!shell || !menu) return;

    var sliderWrap = shell.querySelector('.wrap-item-2');
    var sideWrap = shell.querySelector('.wrap-item-3');

    if (window.innerWidth < 1200) {
      menu.style.minHeight = '';
      menu.style.height = '';
      menu.style.maxHeight = '';
      return;
    }

    var target = 0;
    if (sliderWrap && sliderWrap.offsetParent !== null) {
      target = Math.max(target, sliderWrap.offsetHeight || 0);
    }
    if (sideWrap && sideWrap.offsetParent !== null) {
      target = Math.max(target, sideWrap.offsetHeight || 0);
    }

    if (target > 0) {
      menu.style.minHeight = '';
      menu.style.height = target + 'px';
      menu.style.maxHeight = target + 'px';
    } else {
      menu.style.minHeight = '';
      menu.style.height = '';
      menu.style.maxHeight = '';
    }
  }

  function refreshSwipersInTabs() {
    Array.prototype.slice.call(document.querySelectorAll('[data-bs-toggle="tab"]')).forEach(function (trigger) {
      trigger.addEventListener('shown.bs.tab', function () {
        updateAllSwipers();
        window.setTimeout(function () {
          normalizeCardHeights();
          dedupeEditorialContent();
          pruneSingleItemSwipers();
        }, 80);
      });
    });
  }

  function bindImageDrivenRefresh() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-page-home img')).forEach(function (img) {
      if (!img || img.complete) return;
      img.addEventListener('load', function () {
        window.setTimeout(function () {
          updateAllSwipers();
          normalizeCardHeights();
          syncHeroLayout();
          auditBrandLogos();
          auditMenuPromos();
          bindDesktopHomeMenuIsolation();
          sweepRogueCreatives();
          pruneSingleItemSwipers();
        }, 60);
      }, { once: true });
    });
  }

  function normalizeImages() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-grid-card img, .ks-big-card img, .ks-deal-card img, .card-product img')).forEach(function (img) {
      img.setAttribute('loading', 'lazy');
    });
  }

  function cardNodeList(root) {
    return Array.prototype.slice.call((root || document).querySelectorAll('.card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card'));
  }

  function titleNode(card) {
    return card.querySelector('.name-product') || card.querySelector('h6 a') || card.querySelector('h5 a') || card.querySelector('a.title');
  }

  function cardTitle(card) {
    var node = titleNode(card);
    return node ? node.textContent : '';
  }

  function cardHref(card) {
    var node = titleNode(card) || card.querySelector('a[href*="articolo.aspx?id="]') || card.querySelector('a[href]');
    return node ? node.getAttribute('href') || '' : '';
  }

  function cardExactKey(card) {
    var href = cardHref(card);
    if (href) {
      var match = href.match(/[?&]id=(\d+)/i);
      if (match) return 'id:' + match[1];
      return 'url:' + href
        .replace(/([?&])(tcid|ref|utm_[^=]+|fbclid|gclid)=[^&#]*/ig, '$1')
        .replace(/[?&]+$/, '')
        .replace(/#.*$/, '');
    }
    return 'title:' + normalizeText(cardTitle(card));
  }

  function visibleCardCount(root) {
    return cardNodeList(root).filter(function (card) {
      return card.offsetParent !== null && card.getAttribute('data-ks-hidden') !== '1';
    }).length;
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

  function editorialHeadingNodes() {
    var wanted = Object.keys(sectionTitleMap());
    return Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).filter(function (node) {
      var text = headingText(node);
      if (wanted.indexOf(text) === -1) return false;
      if (node.closest('.menu-tab-line') || node.closest('.flat-title-tab-default')) return false;
      return true;
    });
  }

  function sectionBlockFromHeading(heading) {
    return heading.closest('.tf-grid-product-item') ||
      heading.closest('[id$="Section"]') ||
      heading.closest('[id*="Section"]') ||
      heading.closest('section') ||
      heading.parentElement;
  }

  function dedupeEditorialContent() {
    var thresholds = sectionTitleMap();
    var headings = editorialHeadingNodes();
    if (!headings.length) return;

    var orderedLabels = ['scelti da te', 'top 20', 'in evidenza', 'i piu venduti', 'in offerta'];
    var orderedEntries = [];

    orderedLabels.forEach(function (label) {
      headings.forEach(function (heading) {
        if (headingText(heading) === label) {
          orderedEntries.push({
            label: label,
            heading: heading,
            block: sectionBlockFromHeading(heading)
          });
        }
      });
    });

    var seenExact = new Set();

    orderedEntries.forEach(function (entry) {
      if (!entry.block) return;
      var seenFamily = new Set();

      cardNodeList(entry.block).forEach(function (card) {
        if (!card || card.offsetParent === null) return;
        var exact = cardExactKey(card);
        var family = displayKey(cardTitle(card));
        var hide = false;

        if (exact && seenExact.has(exact)) {
          hide = true;
        }
        if (!hide && family && seenFamily.has(family)) {
          hide = true;
        }

        if (hide) {
          hideNode(card);
          var slide = card.closest('.swiper-slide');
          if (slide && slide.parentNode && cardNodeList(slide).length <= 1) {
            hideNode(slide);
          }
          return;
        }

        if (exact) seenExact.add(exact);
        if (family) seenFamily.add(family);
      });

      if (visibleCardCount(entry.block) < (thresholds[entry.label] || 1)) {
        hideNode(entry.block);
      } else {
        showNode(entry.block);
      }
    });
  }

  function eachHomeMenuItem(fn) {
    Array.prototype.slice.call(document.querySelectorAll('.ks-home-departments .menu-item')).forEach(fn);
  }

  function submenuOf(item) {
    return item ? item.querySelector('.sub-menu-container') : null;
  }

  function toggleOf(item) {
    return item ? item.querySelector('.ks-menu-toggle') : null;
  }

  function arrowOf(item) {
    return item ? item.querySelector('.ks-menu-arrow') : null;
  }

  function setMenuItemLeafState(item, isLeaf) {
    if (!item) return;
    var toggle = toggleOf(item);
    var arrow = arrowOf(item);
    item.classList.toggle('ks-home-menu-item--leaf', !!isLeaf);
    item.classList.toggle('ks-home-menu-item--branch', !isLeaf);
    item.setAttribute('data-ks-has-children', isLeaf ? '0' : '1');
    if (toggle) toggle.style.display = isLeaf ? 'none' : '';
    if (arrow) arrow.style.display = isLeaf ? 'none' : '';
    if (isLeaf) {
      item.classList.remove('is-open');
      if (toggle) toggle.setAttribute('aria-expanded', 'false');
      var submenu = submenuOf(item);
      if (submenu) submenu.setAttribute('aria-hidden', 'true');
    }
  }

  function applyMenuViewportState() {
    var isMobile = window.innerWidth < 1200;
    eachHomeMenuItem(function (item) {
      var submenu = submenuOf(item);
      var toggle = toggleOf(item);
      if (!submenu || !toggle) return;
      if (!isMobile) {
        item.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
        submenu.setAttribute('aria-hidden', 'true');
      } else {
        submenu.setAttribute('aria-hidden', item.classList.contains('is-open') ? 'false' : 'true');
      }
    });
  }

  function initHomeMenu() {
    eachHomeMenuItem(function (item) {
      var toggle = toggleOf(item);
      var submenu = submenuOf(item);
      if (!toggle || !submenu) return;

      toggle.addEventListener('click', function (evt) {
        if (window.innerWidth >= 1200) return;
        evt.preventDefault();
        evt.stopPropagation();

        var willOpen = !item.classList.contains('is-open');
        eachHomeMenuItem(function (other) {
          if (other === item) return;
          other.classList.remove('is-open');
          var otherToggle = toggleOf(other);
          var otherSub = submenuOf(other);
          if (otherToggle) otherToggle.setAttribute('aria-expanded', 'false');
          if (otherSub) otherSub.setAttribute('aria-hidden', 'true');
        });

        item.classList.toggle('is-open', willOpen);
        toggle.setAttribute('aria-expanded', willOpen ? 'true' : 'false');
        submenu.setAttribute('aria-hidden', willOpen ? 'false' : 'true');
      });
    });

    applyMenuViewportState();
  }

  function auditMenuPromos() {
    eachHomeMenuItem(function (item) {
      var submenu = submenuOf(item);
      var promo = item.querySelector('.ks-home-sector-promo');
      var groups = item.querySelectorAll('.ks-home-submenu-list .sub-menu-item');
      var hasGroups = groups.length > 0;

      if (promo) {
        var img = promo.querySelector('img');
        if (!img) {
          hideNode(promo);
        } else if (img.complete) {
          if (!isValidCreativeImage(img, 'side')) {
            hideNode(promo);
          }
        }
      }

      var hasVisiblePromo = promo && promo.getAttribute('data-ks-hidden') !== '1' && promo.offsetParent !== null;
      if (!hasGroups && !hasVisiblePromo) {
        if (submenu) hideNode(submenu);
        setMenuItemLeafState(item, true);
      } else {
        if (submenu && submenu.getAttribute('data-ks-hidden') === '1') showNode(submenu, window.innerWidth >= 1200 ? 'flex' : '');
        setMenuItemLeafState(item, false);
      }
    });
  }

  function auditBrandLogos() {
    var sections = Array.prototype.slice.call(document.querySelectorAll('.ks-home-brands, [data-ks-brand-block="1"]'));
    if (!sections.length) {
      var brandHeading = Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).filter(function (node) {
        return headingText(node) === normalizeText('rivenditori ufficiali i migliori brand');
      })[0];
      if (brandHeading) {
        var container = sectionBlockFromHeading(brandHeading);
        if (container) sections.push(container);
      }
    }

    sections.forEach(function (section) {
      var slides = Array.prototype.slice.call(section.querySelectorAll('.swiper-slide'));
      var visible = 0;
      slides.forEach(function (slide) {
        var img = slide.querySelector('img');
        if (!img) {
          hideNode(slide);
          return;
        }
        if (img.complete) {
          if (!isPlausibleLogo(img)) {
            hideNode(slide);
          } else {
            visible += 1;
          }
          return;
        }
        img.addEventListener('load', function () {
          if (!isPlausibleLogo(img)) {
            hideNode(slide);
          }
        }, { once: true });
        img.addEventListener('error', function () {
          hideNode(slide);
        }, { once: true });
        visible += 1;
      });
      if (visible === 0) {
        hideNode(section);
      }
    });
  }

  function pruneSingleItemSwipers() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-column-swiper, .ks-home-hero-slider, .ks-home-brands, .ks-home-collection-swiper')).forEach(function (root) {
      var visible = visibleSlideCount(root);
      var pagination = root.querySelector('.swiper-pagination, .ks-col-pagination, .ks-hero-pagination, .ks-home-brands-pagination, .ks-home-collection-pagination');
      if (pagination) {
        if (visible <= 1) {
          hideNode(pagination);
        } else {
          showNode(pagination);
        }
      }

      if (root.classList.contains('ks-column-swiper')) {
        var wrap = root.closest('.box-btn-slide-item') || root.parentElement;
        var prev = wrap ? wrap.querySelector('.ks-col-prev') : null;
        var next = wrap ? wrap.querySelector('.ks-col-next') : null;
        if (visible <= 1) {
          hideNode(prev);
          hideNode(next);
        } else {
          showNode(prev, '');
          showNode(next, '');
        }
      }

      if (root.classList.contains('ks-home-hero-slider')) {
        var heroPrev = root.querySelector('.ks-hero-prev');
        var heroNext = root.querySelector('.ks-hero-next');
        if (visible <= 1) {
          hideNode(heroPrev);
          hideNode(heroNext);
        } else {
          showNode(heroPrev);
          showNode(heroNext);
        }
      }
    });
  }

  function armCreativeWatchdog() {
    var ticks = 0;
    var timer = window.setInterval(function () {
      ticks += 1;
      sweepRogueCreatives();
      if (ticks >= 16) {
        window.clearInterval(timer);
      }
    }, 700);
  }

  function boot() {
    armPopupWatchdog();
    sweepRogueCreatives();
    auditHeroAssets(function () {
      initHero();
      initBrandSlider();
      initCollectionSlider();
      initColumnSwipers();
      initHomeMenu();
      bindDesktopHomeMenuIsolation();
      normalizeImages();
      auditMenuPromos();
      sweepRogueCreatives();
      dedupeEditorialContent();
      auditBrandLogos();
      pruneSingleItemSwipers();
      normalizeCardHeights();
      syncHeroLayout();
      refreshSwipersInTabs();
      bindImageDrivenRefresh();
      armCreativeWatchdog();

      window.addEventListener('resize', function () {
        applyMenuViewportState();
        auditMenuPromos();
        bindDesktopHomeMenuIsolation();
        sweepRogueCreatives();
        normalizeCardHeights();
        syncHeroLayout();
        pruneSingleItemSwipers();
        updateAllSwipers();
      });
    });
  }

  onReady(boot);
})();
