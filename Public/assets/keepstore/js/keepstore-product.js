/* KeepStore – Product Detail helpers
 * Obiettivi:
 *  - gallery Swiper coerente con il markup del frontend KeepStore
 *  - zoom prodotto stabile (Drift già caricato dal master)
 *  - niente duplicazione artificiale delle immagini
 *  - qty +/- compatibile con input server WebForms
 */

(function () {
  'use strict';

  function domReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function qsa(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function isDesktopZoom() {
    if (window.matchMedia) {
      return window.matchMedia('(min-width: 1200px)').matches;
    }
    return window.innerWidth >= 1200;
  }

  function initQtyButtons() {
    qsa('.wg-quantity input').forEach(function (input) {
      input.setAttribute('inputmode', 'numeric');
      input.setAttribute('pattern', '[0-9]*');
      input.addEventListener('blur', function () {
        var value = parseInt((input.value || '1').toString().replace(/\D/g, ''), 10);
        if (!isFinite(value) || value <= 0) value = 1;
        if (value > 9999) value = 9999;
        input.value = String(value);
      });
    });

    document.addEventListener('click', function (ev) {
      var btn = ev.target && ev.target.closest ? ev.target.closest('[data-ks-qty]') : null;
      if (!btn) return;

      var wrap = btn.closest ? btn.closest('.wg-quantity') : null;
      if (!wrap) return;

      var input = wrap.querySelector('input');
      if (!input) return;

      var value = parseInt((input.value || '1').toString().replace(/\D/g, ''), 10);
      if (!isFinite(value) || value <= 0) value = 1;

      var mode = btn.getAttribute('data-ks-qty');
      if (mode === 'plus') value += 1;
      if (mode === 'minus') value = Math.max(1, value - 1);
      if (value > 9999) value = 9999;

      input.value = String(value);
    });
  }

  function getGallerySlideCount(main) {
    return qsa('.swiper-wrapper .swiper-slide', main).length;
  }

  function syncThumbsVisibility(main) {
    var thumbsWrap = document.getElementById('ks-product-thumbs-wrap');
    if (!thumbsWrap || !main) return;

    var count = getGallerySlideCount(main);
    thumbsWrap.style.display = count > 1 ? '' : 'none';
  }

  function setupDriftForImage(img, pane) {
    if (!img || !pane || typeof window.Drift === 'undefined') return;

    var zoomUrl = img.getAttribute('data-zoom') || img.getAttribute('data-src') || img.getAttribute('src') || '';
    if (!zoomUrl) return;

    img.setAttribute('data-zoom', zoomUrl);

    if (img._ksDrift) {
      try {
        if (typeof img._ksDrift.enable === 'function') img._ksDrift.enable();
      } catch (e) {
        // ignore
      }
      return;
    }

    try {
      img._ksDrift = new window.Drift(img, {
        paneContainer: pane,
        inlinePane: false,
        hoverBoundingBox: true,
        handleTouch: false,
        sourceAttribute: 'data-zoom'
      });
    } catch (e) {
      if (window.console && console.warn) console.warn('keepstore-product zoom init error', e);
    }
  }

  function setZoomMode() {
    var gallery = document.getElementById('gallery-swiper-started');
    var pane = document.querySelector('.tf-zoom-main');
    if (!gallery || !pane) return;

    var enabled = typeof window.Drift !== 'undefined' && isDesktopZoom();
    pane.style.display = enabled ? '' : 'none';

    qsa('.tf-image-zoom', gallery).forEach(function (img) {
      if (enabled) {
        setupDriftForImage(img, pane);
      } else if (img._ksDrift) {
        try {
          if (typeof img._ksDrift.disable === 'function') img._ksDrift.disable();
        } catch (e) {
          // ignore
        }
      }
    });
  }

  function initSwiperGallery() {
    var main = document.getElementById('gallery-swiper-started');
    var thumbs = document.getElementById('thumbs-swiper-started');
    if (!main) return;

    syncThumbsVisibility(main);
    setZoomMode();

    if (typeof window.Swiper === 'undefined') return;

    try {
      if (main.swiper && typeof main.swiper.destroy === 'function') {
        main.swiper.destroy(true, true);
      }
    } catch (e) {
      // ignore
    }

    try {
      if (thumbs && thumbs.swiper && typeof thumbs.swiper.destroy === 'function') {
        thumbs.swiper.destroy(true, true);
      }
    } catch (e2) {
      // ignore
    }

    var slideCount = getGallerySlideCount(main);
    var thumbsSwiper = null;

    if (thumbs && slideCount > 1) {
      thumbsSwiper = new window.Swiper('#thumbs-swiper-started', {
        slidesPerView: Math.min(4, slideCount),
        spaceBetween: 12,
        freeMode: true,
        watchSlidesProgress: true,
        watchOverflow: true,
        observer: true,
        observeParents: true,
        breakpoints: {
          0: { slidesPerView: Math.min(4, slideCount) },
          768: { slidesPerView: Math.min(5, slideCount) },
          1200: { slidesPerView: Math.min(6, slideCount) }
        }
      });
    }

    new window.Swiper('#gallery-swiper-started', {
      slidesPerView: 1,
      spaceBetween: 10,
      watchOverflow: true,
      observer: true,
      observeParents: true,
      thumbs: thumbsSwiper ? { swiper: thumbsSwiper } : undefined,
      on: {
        init: function () {
          syncThumbsVisibility(main);
          setZoomMode();
        },
        slideChangeTransitionEnd: function () {
          setZoomMode();
        }
      }
    });
  }

  function setupPhotoSwipe(LightboxCtor, PhotoSwipeModule) {
    if (typeof LightboxCtor === 'undefined' || typeof PhotoSwipeModule === 'undefined') return;
    try {
      if (window._ksProductLightbox && typeof window._ksProductLightbox.destroy === 'function') {
        window._ksProductLightbox.destroy();
      }

      window._ksProductLightbox = new LightboxCtor({
        gallery: '#gallery-swiper-started',
        children: 'a',
        pswpModule: PhotoSwipeModule
      });
      window._ksProductLightbox.init();
    } catch (e) {
      if (window.console && console.warn) console.warn('keepstore-product PhotoSwipe init error', e);
    }
  }

  function initPhotoSwipe() {
    if (typeof window.PhotoSwipeLightbox !== 'undefined' && typeof window.PhotoSwipe !== 'undefined') {
      setupPhotoSwipe(window.PhotoSwipeLightbox, window.PhotoSwipe);
      return;
    }

    if (typeof window.Promise === 'undefined') return;

    try {
      if (!window._ksPhotoSwipeModulesPromise) {
        window._ksPhotoSwipeModulesPromise = Promise.all([
          import('./photoswipe-lightbox.esm.min.js'),
          import('./photoswipe.esm.min.js')
        ]);
      }

      window._ksPhotoSwipeModulesPromise.then(function (mods) {
        var LightboxCtor = mods && mods[0] ? (mods[0].default || mods[0].PhotoSwipeLightbox) : null;
        var PhotoSwipeModule = mods && mods[1] ? (mods[1].default || mods[1].PhotoSwipe) : null;
        setupPhotoSwipe(LightboxCtor, PhotoSwipeModule);
      }).catch(function (e) {
        if (window.console && console.warn) console.warn('keepstore-product PhotoSwipe module load error', e);
      });
    } catch (e2) {
      if (window.console && console.warn) console.warn('keepstore-product PhotoSwipe import error', e2);
    }
  }

  function initRefurbBadge() {
    try {
      var isRefurb = false;
      if (typeof window.URLSearchParams !== 'undefined') {
        var params = new URLSearchParams(window.location.search || '');
        var st = params.get('st');
        if (st === '34') isRefurb = true;
      }

      if (!isRefurb) {
        var bodyText = (document.body && document.body.innerText ? document.body.innerText : '').toLowerCase();
        if (bodyText.indexOf('ricondiz') !== -1) isRefurb = true;
      }

      if (!isRefurb) return;

      var name = document.querySelector('.tf-product-info-name');
      if (!name) return;
      if (document.querySelector('.ks-badge-refurb-main')) return;

      var badge = document.createElement('span');
      badge.className = 'ks-badge-refurb-main';
      badge.textContent = 'Ricondizionato';
      name.insertAdjacentElement('afterend', badge);
    } catch (e) {
      // ignore
    }
  }

  function readActionItem(link) {
    if (!link) return null;
    return {
      id: link.getAttribute('data-ks-id') || '',
      tcid: link.getAttribute('data-ks-tcid') || '',
      title: link.getAttribute('data-ks-title') || '',
      brand: link.getAttribute('data-ks-brand') || '',
      category: link.getAttribute('data-ks-category') || '',
      code: link.getAttribute('data-ks-code') || '',
      url: link.getAttribute('data-ks-url') || link.getAttribute('href') || '',
      image: link.getAttribute('data-ks-img') || '',
      price: link.getAttribute('data-ks-price') || '',
      available: link.getAttribute('data-ks-available') || '',
      cartUrl: link.getAttribute('data-ks-cart-url') || '',
      description: link.getAttribute('data-ks-description') || ''
    };
  }

  function stopTemplateDemoHandlers(ev) {
    if (!ev) return;
    ev.preventDefault();
    ev.stopPropagation();
    if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
  }

  function navigateKeepStore(url) {
    if (!url || url === '#') return;
    window.location.assign(url);
  }

  function normalizeQty(value) {
    var qty = parseInt(String(value || '1').replace(/\D/g, ''), 10);
    if (!isFinite(qty) || qty <= 0) qty = 1;
    if (qty > 9999) qty = 9999;
    return qty;
  }

  function findCardQty(link) {
    var card = link && link.closest ? link.closest('.card-product') : null;
    var input = card ? card.querySelector('input.ks-qty') : null;
    if (!input) return 1;
    var qty = normalizeQty(input.value);
    input.value = String(qty);
    return qty;
  }

  function setUrlParam(url, key, value) {
    if (!url || url === '#') return url;
    var hash = '';
    var hashIdx = url.indexOf('#');
    if (hashIdx >= 0) {
      hash = url.substring(hashIdx);
      url = url.substring(0, hashIdx);
    }

    var re = new RegExp('([?&])' + key + '=[^&]*', 'i');
    if (re.test(url)) {
      url = url.replace(re, '$1' + key + '=' + encodeURIComponent(value));
    } else {
      url += (url.indexOf('?') >= 0 ? '&' : '?') + key + '=' + encodeURIComponent(value);
    }

    return url + hash;
  }

  function initCardActionLinks() {
    document.addEventListener('click', function (ev) {
      var cartLink = ev.target && ev.target.closest ? ev.target.closest('.js-ks-cart-link') : null;
      if (cartLink) {
        stopTemplateDemoHandlers(ev);
        navigateKeepStore(setUrlParam(cartLink.getAttribute('href'), 'qty', findCardQty(cartLink)));
        return;
      }

      var wishlistLink = ev.target && ev.target.closest ? ev.target.closest('.js-ks-wishlist-link') : null;
      if (wishlistLink) {
        stopTemplateDemoHandlers(ev);
        navigateKeepStore(wishlistLink.getAttribute('href'));
      }
    }, true);
  }

  function setText(id, value) {
    var el = document.getElementById(id);
    if (el) el.textContent = value || '';
  }

  function setHref(id, value) {
    var el = document.getElementById(id);
    if (el && value) el.setAttribute('href', value);
  }

  function setQuickViewImage(item) {
    var img = document.getElementById('ksQuickViewMainImage');
    if (!img || !item || !item.image) return;
    img.setAttribute('src', item.image);
    img.setAttribute('data-src', item.image);
    img.setAttribute('alt', item.title || 'Prodotto');
  }

  function initQuickViewActions() {
    document.addEventListener('click', function (ev) {
      var link = ev.target && ev.target.closest ? ev.target.closest('.js-ks-quickview') : null;
      if (!link) return;

      stopTemplateDemoHandlers(ev);
      var item = readActionItem(link);
      if (!item) return;
      item.cartUrl = setUrlParam(item.cartUrl || item.url, 'qty', findCardQty(link));

      setText('ksQuickViewMeta', item.category || item.brand || 'Prodotto');
      var title = document.getElementById('ksQuickViewTitle');
      if (title) {
        title.textContent = item.title || 'Prodotto';
        if (item.url) title.setAttribute('href', item.url);
      }
      setText('ksQuickViewSold', item.brand ? 'Marca: ' + item.brand : 'Scheda prodotto');
      setText('ksQuickViewAvailable', item.available || '');
      setText('ksQuickViewPrice', item.price || 'Prezzo su richiesta');
      setText('ksQuickViewDescription', item.description || item.category || '');
      setQuickViewImage(item);
      setHref('ksQuickViewImageLink', item.url);
      setHref('ksQuickViewOpenLink', item.url);
      setHref('ksQuickViewCartLink', item.cartUrl || item.url);
      showQuickViewModal();
    }, true);
  }

  function showQuickViewModal() {
    var modal = document.getElementById('quickView');
    if (!modal) return;

    if (window.bootstrap && bootstrap.Modal) {
      bootstrap.Modal.getOrCreateInstance(modal).show();
      return;
    }

    modal.classList.add('show');
    modal.style.display = 'block';
    modal.removeAttribute('aria-hidden');
    modal.setAttribute('aria-modal', 'true');
    document.body.classList.add('modal-open');
  }

  function compareList() {
    try { return JSON.parse(localStorage.getItem('ks_compare_products') || '[]') || []; } catch (err) { return []; }
  }

  function saveCompare(list) {
    try { localStorage.setItem('ks_compare_products', JSON.stringify((list || []).slice(0, 12))); } catch (err) {}
    var count = document.getElementById('ksCompareCount');
    if (count) count.textContent = String((list || []).length);
    renderComparePage();
  }

  function renderCompareDrawer() {
    var wrap = document.getElementById('ksCompareDrawerWrap');
    if (!wrap) return;

    var list = compareList();
    var empty = document.querySelector('.mini-compare-empty');
    wrap.innerHTML = list.map(function (item, idx) {
      return '<div class="tf-compare-item" data-idx="' + idx + '">' +
        '<a class="image" href="' + escapeHtml(item.url || '#') + '">' +
        (item.image ? '<img src="' + escapeHtml(item.image) + '" alt="' + escapeHtml(item.title || '') + '">' : '') +
        '</a>' +
        '<div class="content">' +
        '<a class="link text-secondary body-md-2 fw-semibold" href="' + escapeHtml(item.url || '#') + '">' + escapeHtml(item.title || '') + '</a>' +
        '<p class="price-wrap fw-medium">' + escapeHtml(item.price || '') + '</p>' +
        '</div>' +
        '<button type="button" class="remove link" data-ks-remove-compare="' + idx + '"><i class="icon icon-close"></i></button>' +
        '</div>';
    }).join('');

    if (empty) empty.style.display = list.length ? 'none' : '';
    wrap.style.display = list.length ? '' : 'none';
  }

  function renderComparePage() {
    var grid = document.getElementById('ksCompareGrid');
    if (!grid) return;

    var shell = document.getElementById('ksCompareShell');
    var empty = document.getElementById('ksCompareEmptyState');
    var list = compareList().filter(function (item) { return item && item.id; }).slice(0, 12);

    if (!list.length) {
      grid.innerHTML = '';
      if (shell) shell.classList.add('d-none');
      if (empty) empty.classList.remove('d-none');
      return;
    }

    if (empty) empty.classList.add('d-none');
    if (shell) shell.classList.remove('d-none');

    grid.innerHTML = list.map(function (item, idx) {
      var title = item.title || item.name || 'Prodotto';
      var meta = [item.brand, item.code ? 'Cod. ' + item.code : ''].filter(Boolean).join(' - ');
      var availability = item.available || item.availability || '';
      var cartUrl = item.cartUrl || ('cart_add.aspx?id=' + encodeURIComponent(item.id) + '&TCid=' + encodeURIComponent(item.tcid || '-1') + '&qty=1');
      return '<div class="tf-compare-item ks-compare-page-card" data-idx="' + idx + '">' +
        '<a class="image" href="' + escapeHtml(item.url || '#') + '">' +
          (item.image ? '<img src="' + escapeHtml(item.image) + '" alt="' + escapeHtml(title) + '">' : '') +
        '</a>' +
        '<div class="content">' +
          '<p class="caption text-main-2 mb-1">' + escapeHtml(item.category || 'Prodotto') + '</p>' +
          '<a class="link text-secondary body-md-2 fw-semibold" href="' + escapeHtml(item.url || '#') + '">' + escapeHtml(title) + '</a>' +
          (meta ? '<p class="caption text-main-2 mt-1">' + escapeHtml(meta) + '</p>' : '') +
          '<p class="price-wrap fw-medium mt-2">' + escapeHtml(item.price || 'Prezzo su richiesta') + '</p>' +
          (availability ? '<p class="caption text-main-2">' + escapeHtml(availability) + '</p>' : '') +
          '<div class="d-flex gap-2 mt-3 flex-wrap">' +
            '<a class="tf-btn btn-line" href="' + escapeHtml(item.url || '#') + '"><span>Vedi prodotto</span></a>' +
            '<a class="tf-btn btn-fill js-ks-cart-link" href="' + escapeHtml(cartUrl) + '" data-ks-id="' + escapeHtml(item.id) + '" data-ks-tcid="' + escapeHtml(item.tcid || '-1') + '"><span>Aggiungi</span></a>' +
          '</div>' +
        '</div>' +
        '<button type="button" class="remove link" data-ks-remove-compare="' + idx + '" aria-label="Rimuovi"><i class="icon icon-close"></i></button>' +
      '</div>';
    }).join('');
  }

  function escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }

  function addCompareItem(item) {
    if (!item || !item.id) return;
    var list = compareList();
    var key = String(item.id) + ':' + String(item.tcid || '');
    var exists = list.some(function (x) { return String(x.key || (String(x.id) + ':' + String(x.tcid || ''))) === key; });
    if (!exists) {
      list.unshift({
        key: key,
        id: item.id,
        tcid: item.tcid,
        title: item.title,
        brand: item.brand,
        category: item.category,
        code: item.code,
        available: item.available,
        cartUrl: item.cartUrl,
        url: item.url,
        image: item.image,
        price: item.price
      });
    }
    saveCompare(list);
    renderCompareDrawer();
    renderComparePage();
  }

  function initCompareActions() {
    renderCompareDrawer();
    renderComparePage();

    document.addEventListener('click', function (ev) {
      var compareLink = ev.target && ev.target.closest ? ev.target.closest('.js-ks-compare') : null;
      if (compareLink) {
        stopTemplateDemoHandlers(ev);
        var item = readActionItem(compareLink);
        addCompareItem(item);
        openCompareDrawer();
        return;
      }

      var removeBtn = ev.target && ev.target.closest ? ev.target.closest('[data-ks-remove-compare]') : null;
      if (removeBtn) {
        ev.preventDefault();
        var idx = parseInt(removeBtn.getAttribute('data-ks-remove-compare') || '-1', 10);
        var list = compareList();
        if (idx >= 0 && idx < list.length) {
          list.splice(idx, 1);
          saveCompare(list);
          renderCompareDrawer();
          renderComparePage();
        }
      }
    }, true);

    qsa('#ksCompareClearDrawer,.tf-compapre-button-clear-all').forEach(function (btn) {
      if (btn.getAttribute('data-ks-compare-clear-bound') === '1') return;
      btn.setAttribute('data-ks-compare-clear-bound', '1');
      btn.addEventListener('click', function () {
        saveCompare([]);
        renderCompareDrawer();
        renderComparePage();
      }, true);
    });
  }

  function openCompareDrawer() {
    var canvas = document.getElementById('compare');
    if (!canvas) return;

    if (window.bootstrap && bootstrap.Offcanvas) {
      try {
        bootstrap.Offcanvas.getOrCreateInstance(canvas).show();
        return;
      } catch (err) {
        // Fallback to the theme's CSS-driven drawer if Bootstrap cannot own this element.
      }
    }

    canvas.classList.add('show');
    canvas.style.visibility = 'visible';
    canvas.removeAttribute('aria-hidden');
    canvas.setAttribute('aria-modal', 'true');
    canvas.setAttribute('role', 'dialog');
    document.body.classList.add('offcanvas-open');
  }

  function debounce(fn, wait) {
    var timer = null;
    return function () {
      var args = arguments;
      clearTimeout(timer);
      timer = setTimeout(function () {
        fn.apply(null, args);
      }, wait || 120);
    };
  }

  function initLocalReviews() {
    // Le recensioni prodotto sono persistite lato KeepStore/MySQL tramite WebForms.
    // Questa funzione resta no-op per compatibilita con vecchie pagine cacheate.
  }

  domReady(function () {
    initQtyButtons();
    initRefurbBadge();
    initCardActionLinks();
    initQuickViewActions();
    initCompareActions();
    initLocalReviews();
    initSwiperGallery();
    initPhotoSwipe();

    window.addEventListener('resize', debounce(function () {
      setZoomMode();
      syncThumbsVisibility(document.getElementById('gallery-swiper-started'));
    }, 150));
  });

})();
