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
      url: validUrl(input.url),
      viewedAt: cleanText(input.viewedAt, nowIso())
    };

    if (!item.id || !item.url) return null;
    if (!item.name) item.name = 'Prodotto';
    return item;
  }

  function readHistory() {
    return readList().map(normalizeProduct).filter(Boolean);
  }

  function scrubStoredHistory() {
    writeList(readHistory());
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
    var list = readHistory();
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
        '</div>' +
        '<div class="card-product-info">' +
          '<p class="product-tag caption text-main-2 ks-card-category">' + escapeHtml(meta) + '</p>' +
          '<a class="name-product body-md-2 fw-semibold text-secondary link ks-card-title" href="' + attr(item.url) + '">' + escapeHtml(item.name) + '</a>' +
          (sub ? '<p class="caption text-main-2 ks-card-brand-code">' + escapeHtml(sub) + '</p>' : '') +
          '<a href="' + attr(item.url) + '" class="tf-btn btn-line w-100 mt-2 ks-recent-history-link">Vedi prodotto</a>' +
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

    // Le card server-side contengono prezzi e promozioni live: la cronologia
    // locale non deve sostituire una sorgente commerciale piu autorevole.
    if (block.getAttribute('data-ks-server-fallback') === '1' && target.children.length) {
      block.classList.remove('d-none');
      initSwiper(block);
      return;
    }

    var limit = parseInt(block.getAttribute('data-ks-limit') || DEFAULT_RENDER, 10);
    if (!isFinite(limit) || limit <= 0) limit = DEFAULT_RENDER;

    var currentKey = block.getAttribute('data-ks-current-key') || '';
    var list = readHistory();
    list = list.filter(function (x) { return productKey(x) !== currentKey; });
    list.sort(sortByViewedAt);
    list = list.slice(0, limit);

    if (!list.length) {
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
    list: readHistory,
    render: render
  };

  document.addEventListener('DOMContentLoaded', function () {
    scrubStoredHistory();
    render('ksRecentlyViewedBlock');
    render('HomeRecentlyViewedSection');
  });
})();
