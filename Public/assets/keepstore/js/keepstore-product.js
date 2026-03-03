/* KeepStore – Product Detail helpers
 * Obiettivi:
 *  - gallery Swiper (main + thumbs) compatibile con markup template
 *  - rimozione immagini duplicate/vuote (se nel DB è presente solo img1 non deve duplicare 6 volte)
 *  - qty +/- (mantiene txtQty come input server)
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

  function getImgKey(imgEl) {
    if (!imgEl) return '';
    var src = imgEl.getAttribute('data-src') || imgEl.getAttribute('src') || '';
    return (src || '').trim();
  }

  function dedupeGallery(mainWrap, thumbsWrap) {
    try {
      if (!mainWrap || !thumbsWrap) return;

      var mainSlides = Array.prototype.slice.call(mainWrap.querySelectorAll('.swiper-slide'));
      var thumbSlides = Array.prototype.slice.call(thumbsWrap.querySelectorAll('.swiper-slide'));
      if (mainSlides.length === 0 || thumbSlides.length === 0) return;

      var seen = {};
      var keepMain = [];
      var keepThumb = [];

      for (var i = 0; i < Math.min(mainSlides.length, thumbSlides.length); i++) {
        var mainImg = mainSlides[i].querySelector('img');
        var key = getImgKey(mainImg);

        // Rimuovi se vuoto o già visto
        if (!key || seen[key]) continue;
        seen[key] = true;

        keepMain.push(mainSlides[i]);
        keepThumb.push(thumbSlides[i]);
      }

      // Ripulisci DOM (manteniamo l'ordine originale)
      if (keepMain.length > 0) {
        var mainWrapper = mainWrap.querySelector('.swiper-wrapper');
        var thumbsWrapper = thumbsWrap.querySelector('.swiper-wrapper');

        if (mainWrapper) {
          while (mainWrapper.firstChild) mainWrapper.removeChild(mainWrapper.firstChild);
          keepMain.forEach(function (el) { mainWrapper.appendChild(el); });
        }

        if (thumbsWrapper) {
          while (thumbsWrapper.firstChild) thumbsWrapper.removeChild(thumbsWrapper.firstChild);
          keepThumb.forEach(function (el) { thumbsWrapper.appendChild(el); });
        }
      }

      // Se rimane 1 sola immagine, nascondi thumbs
      if (keepThumb.length <= 1) {
        var thumbsContainer = document.getElementById('ks-product-thumbs-wrap');
        if (thumbsContainer) thumbsContainer.style.display = 'none';
      }

    } catch (e) {
      // fail-safe: non bloccare la pagina
      console && console.warn && console.warn('keepstore-product dedupe error', e);
    }
  }

  function initQtyButtons() {
    document.addEventListener('click', function (ev) {
      var btn = ev.target.closest('[data-ks-qty]');
      if (!btn) return;

      var wrap = btn.closest('.wg-quantity');
      if (!wrap) return;

      var input = wrap.querySelector('input');
      if (!input) return;

      var v = parseInt((input.value || '1').toString().replace(/\D/g, ''), 10);
      if (!isFinite(v) || v <= 0) v = 1;

      var mode = btn.getAttribute('data-ks-qty');
      if (mode === 'plus') v += 1;
      if (mode === 'minus') v = Math.max(1, v - 1);

      input.value = String(v);
    });
  }

  function initSwiperGallery() {
    var main = document.getElementById('gallery-swiper-started');
    var thumbs = document.getElementById('thumbs-swiper-started');

    if (!main || !thumbs) return;

    dedupeGallery(main, thumbs);

    if (typeof window.Swiper === 'undefined') return;

    // Thumbs
    var thumbsSwiper = new window.Swiper('#thumbs-swiper-started', {
      slidesPerView: 5,
      spaceBetween: 10,
      freeMode: true,
      watchSlidesProgress: true,
      breakpoints: {
        0: { slidesPerView: 4 },
        768: { slidesPerView: 5 },
        1200: { slidesPerView: 6 }
      }
    });

    // Main
    new window.Swiper('#gallery-swiper-started', {
      spaceBetween: 10,
      navigation: false,
      thumbs: {
        swiper: thumbsSwiper
      }
    });
  }

  function initPhotoSwipe() {
    // photoswipe.umd.min.js espone PhotoSwipeLightbox (UMD)
    if (typeof window.PhotoSwipeLightbox === 'undefined') return;

    try {
      var lightbox = new window.PhotoSwipeLightbox({
        gallery: '#gallery-swiper-started',
        children: 'a',
        pswpModule: window.PhotoSwipe
      });
      lightbox.init();
    } catch (e) {
      console && console.warn && console.warn('PhotoSwipe init error', e);
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

      // Fallback: se la pagina contiene già riferimenti a ricondizionato
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

  domReady(function () {
    initQtyButtons();
    initRefurbBadge();
    initSwiperGallery();
    initPhotoSwipe();
  });

})();
