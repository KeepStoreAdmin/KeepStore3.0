/* KeepStore recently viewed products
 * Local, non-tracking history for product discovery.
 */
(function () {
  'use strict';

  var KEY = 'ks_recently_viewed_products';
  var MAX_STORE = 12;
  var DEFAULT_RENDER = 8;

  function nowIso() {
    try { return new Date().toISOString(); } catch (e) { return ''; }
  }

  function storageAvailable() {
    try {
      if (!window.localStorage) return false;
      var k = '__ks_rv_test__';
      localStorage.setItem(k, '1');
      localStorage.removeItem(k);
      return true;
    } catch (e) {
      return false;
    }
  }

  function readList() {
    if (!storageAvailable()) return [];
    try {
      var parsed = JSON.parse(localStorage.getItem(KEY) || '[]');
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      try { localStorage.removeItem(KEY); } catch (ignore) {}
      return [];
    }
  }

  function writeList(list) {
    if (!storageAvailable()) return;
    try {
      localStorage.setItem(KEY, JSON.stringify((list || []).slice(0, MAX_STORE)));
    } catch (e) {
      // localStorage full or blocked: fail silently.
    }
  }

  function cleanText(value, fallback) {
    var s = String(value || '').replace(/\s+/g, ' ').trim();
    return s || (fallback || '');
  }

  function validUrl(url) {
    var s = cleanText(url, '');
    if (!s || s === '#') return '';
    if (/^\s*javascript:/i.test(s)) return '';
    return s;
  }

  function productKey(item) {
    return String(item.id || '') + ':' + String(item.tcid || '');
  }

  function normalizedTcid(value) {
    var n = parseInt(String(value || '-1').replace(/[^\d-]/g, ''), 10);
    return (!isFinite(n) || n <= 0) ? '-1' : String(n);
  }

  function normalizeAvailabilityPresentation(input) {
    if (!input || typeof input !== 'object') return null;

    var mode = parseInt(input.mode, 10) === 2 ? 2 : 1;
    var tones = {
      'is-ok': true,
      'is-low': true,
      'is-incoming': true,
      'is-unavailable': true
    };
    var tone = cleanText(input.tone, '');
    if (!tones[tone]) return null;

    var statusText = cleanText(input.statusText, '').slice(0, 80);
    if (!statusText) return null;

    return {
      mode: mode,
      statusText: statusText,
      tone: tone,
      availableQtyText: cleanText(input.availableQtyText, '0').slice(0, 24),
      committedQtyText: cleanText(input.committedQtyText, '0').slice(0, 24),
      incomingQtyText: cleanText(input.incomingQtyText, '0').slice(0, 24),
      availableMetricClass: cleanText(input.availableMetricClass, '') === 'has-value' ? 'has-value' : '',
      incomingMetricClass: cleanText(input.incomingMetricClass, '') === 'has-value' ? 'has-value' : '',
      incomingTooltip: cleanText(input.incomingTooltip, '').slice(0, 600)
    };
  }

  function normalizeProduct(input) {
    if (!input) return null;

    var item = {
      id: cleanText(input.id, ''),
      tcid: normalizedTcid(input.tcid),
      name: cleanText(input.name || input.title, ''),
      code: cleanText(input.code, ''),
      brand: cleanText(input.brand, ''),
      category: cleanText(input.category, ''),
      image: validUrl(input.image),
      price: cleanText(input.price, 'Prezzo su richiesta'),
      availability: cleanText(input.availability || input.available, ''),
      availabilityPresentation: normalizeAvailabilityPresentation(input.availabilityPresentation),
      url: validUrl(input.url),
      cartUrl: validUrl(input.cartUrl),
      wishlistUrl: validUrl(input.wishlistUrl),
      viewedAt: cleanText(input.viewedAt, nowIso())
    };

    if (!item.id || !item.url) return null;
    if (!item.name) item.name = 'Prodotto';
    return item;
  }

  function sortByViewedAt(a, b) {
    var ad = Date.parse(a.viewedAt || '') || 0;
    var bd = Date.parse(b.viewedAt || '') || 0;
    return bd - ad;
  }

  function add(input) {
    var item = normalizeProduct(input);
    if (!item) return;

    item.viewedAt = nowIso();
    var key = productKey(item);
    var list = readList().map(normalizeProduct).filter(Boolean);
    list = list.filter(function (x) { return productKey(x) !== key; });
    list.unshift(item);
    writeList(list.slice(0, MAX_STORE));
  }

  function escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }

  function attr(value) {
    return escapeHtml(value).replace(/`/g, '&#96;');
  }

  function fallbackImage(container) {
    return container.getAttribute('data-ks-placeholder') || '/Public/assets/images/img/placeholder.svg';
  }

  function deriveCartUrl(item) {
    if (item.cartUrl) return item.cartUrl;
    return '/cart_add.aspx?id=' + encodeURIComponent(item.id) + '&TCid=' + encodeURIComponent(normalizedTcid(item.tcid)) + '&qty=1';
  }

  function deriveWishlistUrl(item) {
    if (item.wishlistUrl) return item.wishlistUrl;
    return '/wishlist_add.aspx?id=' + encodeURIComponent(item.id) + (item.tcid ? '&TCid=' + encodeURIComponent(item.tcid) : '');
  }

  function actionAttrs(item, img) {
    return ' data-ks-id="' + attr(item.id) + '"' +
      ' data-ks-tcid="' + attr(item.tcid) + '"' +
      ' data-ks-title="' + attr(item.name) + '"' +
      ' data-ks-brand="' + attr(item.brand) + '"' +
      ' data-ks-category="' + attr(item.category) + '"' +
      ' data-ks-code="' + attr(item.code) + '"' +
      ' data-ks-url="' + attr(item.url) + '"' +
      ' data-ks-img="' + attr(img) + '"' +
      ' data-ks-price="' + attr(item.price) + '"' +
      ' data-ks-available="' + attr(item.availability) + '"' +
      ' data-ks-cart-url="' + attr(deriveCartUrl(item)) + '"' +
      ' data-ks-description="' + attr(item.category || item.brand || item.availability || 'Prodotto') + '"';
  }

  function renderAvailabilityStatus(presentation) {
    return '<span class="ks-availability__status ' + attr(presentation.tone) + '">' +
      '<span class="ks-availability__dot" aria-hidden="true"></span>' +
      '<span class="ks-availability__status-text">' + escapeHtml(presentation.statusText) + '</span>' +
    '</span>';
  }

  function renderAvailabilityMetric(label, value, modifier, infoText) {
    var info = infoText ? '<button type="button" class="ks-availability__info" title="' + attr(infoText) + '" aria-label="Informazioni sugli articoli in arrivo: ' + attr(infoText) + '"><span aria-hidden="true">i</span></button>' : '';
    return '<span class="ks-availability__metric ' + attr(modifier) + '">' +
      '<span class="ks-availability__label">' + escapeHtml(label) + '</span>' +
      '<strong class="ks-availability__value">' + escapeHtml(value) + '</strong>' + info +
    '</span>';
  }

  function renderAvailability(item) {
    var presentation = item.availabilityPresentation;
    if (!presentation) {
      return item.availability ? '<p class="caption text-main-2 mt-1">' + escapeHtml(item.availability) + '</p>' : '';
    }

    if (presentation.mode === 1) {
      return '<span class="ks-availability ks-availability--synthetic" role="status" aria-label="Disponibilita: ' + attr(presentation.statusText) + '">' +
        renderAvailabilityStatus(presentation) +
      '</span>';
    }

    var ariaText = 'Disponibili: ' + presentation.availableQtyText + '. Impegnati: ' + presentation.committedQtyText + '. In arrivo: ' + presentation.incomingQtyText + '. ' + presentation.statusText;
    return '<span class="ks-availability ks-availability--numeric" role="status" aria-label="' + attr(ariaText) + '">' +
      '<span class="ks-availability__metrics">' +
        renderAvailabilityMetric('Disponibili', presentation.availableQtyText, 'is-available ' + presentation.availableMetricClass, '') +
        renderAvailabilityMetric('Impegnati', presentation.committedQtyText, 'is-committed', '') +
        renderAvailabilityMetric('In arrivo', presentation.incomingQtyText, 'is-incoming ' + presentation.incomingMetricClass, presentation.incomingTooltip) +
      '</span>' +
      renderAvailabilityStatus(presentation) +
    '</span>';
  }

  function renderCard(item, container) {
    var img = item.image || fallbackImage(container);
    var meta = item.category || '';
    var sub = [item.brand, item.code ? 'Cod. ' + item.code : ''].filter(Boolean).join(' - ');

    return '<div class="swiper-slide">' +
      '<div class="card-product ks-catalog-card ks-recent-card">' +
        '<div class="card-product-wrapper">' +
          '<a class="product-img" href="' + attr(item.url) + '">' +
            '<img class="lazyload img-product" src="' + attr(img) + '" data-src="' + attr(img) + '" alt="' + attr(item.name) + '">' +
            '<img class="img-hover" src="' + attr(img) + '" alt="" aria-hidden="true">' +
          '</a>' +
          '<ul class="list-product-btn top-0 end-0">' +
            '<li class="ks-rv-cart-action d-none d-lg-block"><a href="' + attr(deriveCartUrl(item)) + '" class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left js-ks-cart-link" aria-label="Acquista: aggiungi al carrello" title="Acquista: aggiungi al carrello"' + actionAttrs(item, img) + '><span class="icon icon-cart-2" aria-hidden="true"></span><span class="tooltip d-none d-lg-block">Acquista</span></a></li>' +
            '<li class="wishlist"><a href="' + attr(deriveWishlistUrl(item)) + '" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link" aria-label="Aggiungi a wishlist"' + actionAttrs(item, img) + '><span class="icon icon-heart2"></span><span class="tooltip d-none d-lg-block">Wishlist</span></a></li>' +
            '<li><a href="#quickView" data-bs-toggle="modal" class="box-icon quickview btn-icon-action hover-tooltip tooltip-left js-ks-quickview" aria-label="Vista rapida"' + actionAttrs(item, img) + '><span class="icon icon-view"></span><span class="tooltip d-none d-lg-block">Vista rapida</span></a></li>' +
            '<li><a href="#compare" data-bs-toggle="offcanvas" data-bs-target="#compare" aria-controls="compare" class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare" aria-label="Confronta articolo"' + actionAttrs(item, img) + '><span class="icon icon-compare1"></span><span class="tooltip d-none d-lg-block">Confronta</span></a></li>' +
          '</ul>' +
        '</div>' +
        '<div class="card-product-info">' +
          '<p class="product-tag caption text-main-2 ks-card-category">' + escapeHtml(meta) + '</p>' +
          '<a class="name-product body-md-2 fw-semibold text-secondary link ks-card-title" href="' + attr(item.url) + '">' + escapeHtml(item.name) + '</a>' +
          (sub ? '<p class="caption text-main-2 ks-card-brand-code">' + escapeHtml(sub) + '</p>' : '') +
          '<div class="price-wrap fw-medium mt-1"><span class="ks-price"><span class="ks-price-now">' + escapeHtml(item.price || 'Prezzo su richiesta') + '</span></span></div>' +
          renderAvailability(item) +
          '<a href="' + attr(deriveCartUrl(item)) + '" class="tf-btn text-white w-100 d-lg-none ks-mobile-card-buy-cta ks-home-buy-cta js-ks-cart-link" aria-label="Acquista: aggiungi al carrello" title="Acquista: aggiungi al carrello"' + actionAttrs(item, img) + '><span class="ks-card-buy-cta__icon icon-cart-2" aria-hidden="true"></span><span class="ks-home-buy-cta__text">Acquista</span></a>' +
        '</div>' +
      '</div>' +
    '</div>';
  }

  function initSwiper(block) {
    var swiperEl = block.querySelector('.ks-recently-viewed-swiper');
    if (!swiperEl || typeof window.Swiper === 'undefined') return;
    try {
      if (swiperEl.swiper && typeof swiperEl.swiper.destroy === 'function') {
        swiperEl.swiper.destroy(true, true);
      }
      new window.Swiper(swiperEl, {
        slidesPerView: 2,
        spaceBetween: 15,
        watchOverflow: true,
        observer: true,
        observeParents: true,
        navigation: {
          nextEl: block.querySelector('.ks-rv-next'),
          prevEl: block.querySelector('.ks-rv-prev')
        },
        breakpoints: {
          576: { slidesPerView: 3, spaceBetween: 15 },
          768: { slidesPerView: 4, spaceBetween: 20 },
          1200: { slidesPerView: 5, spaceBetween: 30 }
        }
      });
    } catch (e) {
      // Swiper is progressive enhancement.
    }
  }

  function render(containerId, options) {
    var block = document.getElementById(containerId || 'ksRecentlyViewedBlock');
    if (!block) return;

    var target = block.querySelector('[data-ks-recent-items]');
    if (!target) return;

    var limit = parseInt(block.getAttribute('data-ks-limit') || DEFAULT_RENDER, 10);
    if (!isFinite(limit) || limit <= 0) limit = DEFAULT_RENDER;

    var currentKey = block.getAttribute('data-ks-current-key') || '';
    var list = readList().map(normalizeProduct).filter(Boolean);
    list = list.filter(function (x) { return productKey(x) !== currentKey; });
    list.sort(sortByViewedAt);
    list = list.slice(0, limit);

    if (!list.length) {
      if (block.getAttribute('data-ks-server-fallback') === '1' && target.children.length) {
        block.classList.remove('d-none');
        initSwiper(block);
        return;
      }
      block.classList.add('d-none');
      target.innerHTML = '';
      return;
    }

    target.innerHTML = list.map(function (item) { return renderCard(item, block); }).join('');
    block.classList.remove('d-none');
    initSwiper(block);
    try {
      if (window.KeepStoreCartBadges && typeof window.KeepStoreCartBadges.refresh === 'function') {
        window.KeepStoreCartBadges.refresh();
      }
    } catch (e) {}
  }

  window.KeepStoreRecentlyViewed = {
    add: add,
    list: readList,
    render: render
  };

  document.addEventListener('DOMContentLoaded', function () {
    render('ksRecentlyViewedBlock');
    render('HomeRecentlyViewedSection');
  });
})();
