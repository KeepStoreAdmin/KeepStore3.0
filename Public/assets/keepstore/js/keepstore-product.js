/* KeepStore – Product Detail helpers
 * Obiettivi:
 *  - gallery Swiper (main + thumbs) compatibile con markup template
 *  - normalizzazione immagini prodotto (UI):
 *      * gestiamo 4 immagini "logiche" (thumbs + main)
 *      * se c'è 1 sola immagine, la duplichiamo fino a 4
 *      * se non ci sono immagini, usiamo un placeholder di default
 *      * se ci sono 2/3 immagini, ripetiamo ciclicamente fino a 4
 *  - qty +/- (mantiene txtQty come input server)
 *
 * Nota: questa logica è volutamente client-side per evitare impatti su VB/DB
 * e per prevenire errori di precompile (Web Site).
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

  function isTransparentGif(url) {
    if (!url) return true;
    // 1x1 transparent gif (usato in fallback server-side in alcune pagine)
    return url.indexOf('data:image/gif;base64,R0lGODlhAQABA') === 0;
  }

  var _cachedPlaceholderUrl = null;
  function getDefaultPlaceholderUrl() {
    if (_cachedPlaceholderUrl) return _cachedPlaceholderUrl;

    // SVG inline: niente file aggiuntivi (e niente dipendenze sul template)
    var svg = ''
      + '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800">'
      + '<rect width="800" height="800" fill="#f3f4f6"/>'
      + '<path d="M240 520h320" stroke="#cbd5e1" stroke-width="14" stroke-linecap="round"/>'
      + '<rect x="220" y="240" width="360" height="240" rx="18" fill="#ffffff" stroke="#cbd5e1" stroke-width="12"/>'
      + '<circle cx="320" cy="320" r="26" fill="#cbd5e1"/>'
      + '<path d="M250 450l95-95 70 70 60-60 75 75" fill="none" stroke="#cbd5e1" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>'
      + '<text x="400" y="610" text-anchor="middle" font-family="Arial, sans-serif" font-size="34" fill="#94a3b8">Immagine non disponibile</text>'
      + '</svg>';

    _cachedPlaceholderUrl = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    return _cachedPlaceholderUrl;
  }

  function collectUniqueUrls(mainWrap) {
    var urls = [];
    if (!mainWrap) return urls;

    var slides = Array.prototype.slice.call(mainWrap.querySelectorAll('.swiper-wrapper .swiper-slide'));
    if (!slides || slides.length === 0) return urls;

    var seen = {};
    for (var i = 0; i < slides.length; i++) {
      var img = slides[i].querySelector('img');
      var key = getImgKey(img);
      if (!key) continue;
      if (isTransparentGif(key)) continue;
      if (seen[key]) continue;
      seen[key] = true;
      urls.push(key);
    }

    return urls;
  }

  function expandUrlsToFour(urls) {
    var out = [];
    var src = (urls && urls.length) ? urls.slice(0) : [];

    if (!src.length) {
      var ph = getDefaultPlaceholderUrl();
      src = [ph];
    }

    // riempi ciclicamente fino a 4
    for (var i = 0; i < 4; i++) {
      out.push(src[i % src.length]);
    }

    return out;
  }

  function ensureWrapper(mainWrap, thumbsWrap) {
    if (!mainWrap || !thumbsWrap) return null;

    var mainWrapper = mainWrap.querySelector('.swiper-wrapper');
    var thumbsWrapper = thumbsWrap.querySelector('.swiper-wrapper');
    if (!mainWrapper || !thumbsWrapper) return null;

    return {
      mainWrapper: mainWrapper,
      thumbsWrapper: thumbsWrapper
    };
  }

  function buildSlideFromTemplate(templateSlide, url, isMain) {
    var slide = templateSlide.cloneNode(true);

    // anchor (main slide)
    var a = slide.querySelector('a');
    if (a) {
      a.setAttribute('href', url);
      if (a.getAttribute('data-pswp-src') !== null) a.setAttribute('data-pswp-src', url);

      // se manca width/height (placeholder), settiamo dimensioni ragionevoli
      if (!a.getAttribute('data-pswp-width')) a.setAttribute('data-pswp-width', '800');
      if (!a.getAttribute('data-pswp-height')) a.setAttribute('data-pswp-height', '800');
    }

    // img
    var img = slide.querySelector('img');
    if (img) {
      img.setAttribute('src', url);
      img.setAttribute('data-src', url);
      // manteniamo classi esistenti (lazyload) e attributi di accessibilità
      if (!img.getAttribute('alt')) img.setAttribute('alt', isMain ? 'Immagine prodotto' : 'Anteprima prodotto');
    }

    return slide;
  }

  function normalizeGalleryToFour(mainWrap, thumbsWrap) {
    try {
      var wrappers = ensureWrapper(mainWrap, thumbsWrap);
      if (!wrappers) return;

      var urls = collectUniqueUrls(mainWrap);
      var normalized = expandUrlsToFour(urls);

      // template slide: se non esiste, lo creiamo minimal
      var mainSlides = wrappers.mainWrapper.querySelectorAll('.swiper-slide');
      var thumbSlides = wrappers.thumbsWrapper.querySelectorAll('.swiper-slide');

      var mainTemplate = (mainSlides && mainSlides.length) ? mainSlides[0] : null;
      var thumbTemplate = (thumbSlides && thumbSlides.length) ? thumbSlides[0] : null;

      if (!mainTemplate) {
        mainTemplate = document.createElement('div');
        mainTemplate.className = 'swiper-slide';
        var a = document.createElement('a');
        a.className = 'product-img';
        a.setAttribute('data-pswp-width', '800');
        a.setAttribute('data-pswp-height', '800');
        var img = document.createElement('img');
        img.className = 'lazyload';
        img.setAttribute('alt', 'Immagine prodotto');
        a.appendChild(img);
        mainTemplate.appendChild(a);
      }

      if (!thumbTemplate) {
        thumbTemplate = document.createElement('div');
        thumbTemplate.className = 'swiper-slide';
        var ti = document.createElement('img');
        ti.className = 'lazyload';
        ti.setAttribute('alt', 'Anteprima prodotto');
        thumbTemplate.appendChild(ti);
      }

      // rebuild wrappers
      while (wrappers.mainWrapper.firstChild) wrappers.mainWrapper.removeChild(wrappers.mainWrapper.firstChild);
      while (wrappers.thumbsWrapper.firstChild) wrappers.thumbsWrapper.removeChild(wrappers.thumbsWrapper.firstChild);

      for (var i = 0; i < normalized.length; i++) {
        wrappers.mainWrapper.appendChild(buildSlideFromTemplate(mainTemplate, normalized[i], true));
        wrappers.thumbsWrapper.appendChild(buildSlideFromTemplate(thumbTemplate, normalized[i], false));
      }

      // assicura che i thumbs siano visibili (la UX del template li prevede)
      var thumbsContainer = document.getElementById('ks-product-thumbs-wrap');
      if (thumbsContainer) thumbsContainer.style.display = '';

    } catch (e) {
      // fail-safe: non bloccare la pagina
      if (window.console && console.warn) console.warn('keepstore-product normalizeGallery error', e);
    }
  }

  function initQtyButtons() {
    document.addEventListener('click', function (ev) {
      var btn = ev.target && ev.target.closest ? ev.target.closest('[data-ks-qty]') : null;
      if (!btn) return;

      var wrap = btn.closest ? btn.closest('.wg-quantity') : null;
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

    // Prima di inizializzare Swiper, normalizziamo a 4 immagini
    normalizeGalleryToFour(main, thumbs);

    if (typeof window.Swiper === 'undefined') return;

    // Thumbs: 4 thumbs in linea (template-style)
    var thumbsSwiper = new window.Swiper('#thumbs-swiper-started', {
      slidesPerView: 4,
      spaceBetween: 10,
      freeMode: true,
      watchSlidesProgress: true,
      breakpoints: {
        0: { slidesPerView: 4 },
        768: { slidesPerView: 4 },
        1200: { slidesPerView: 4 }
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
      if (window.console && console.warn) console.warn('PhotoSwipe init error', e);
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
