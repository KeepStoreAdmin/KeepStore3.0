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

  function initPhotoSwipe() {
    if (typeof window.PhotoSwipeLightbox === 'undefined' || typeof window.PhotoSwipe === 'undefined') return;

    try {
      if (window._ksProductLightbox && typeof window._ksProductLightbox.destroy === 'function') {
        window._ksProductLightbox.destroy();
      }

      window._ksProductLightbox = new window.PhotoSwipeLightbox({
        gallery: '#gallery-swiper-started',
        children: 'a',
        pswpModule: window.PhotoSwipe
      });
      window._ksProductLightbox.init();
    } catch (e) {
      if (window.console && console.warn) console.warn('keepstore-product PhotoSwipe init error', e);
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

  domReady(function () {
    initQtyButtons();
    initRefurbBadge();
    initSwiperGallery();
    initPhotoSwipe();

    window.addEventListener('resize', debounce(function () {
      setZoomMode();
      syncThumbsVisibility(document.getElementById('gallery-swiper-started'));
    }, 150));
  });

})();
