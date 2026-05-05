/* KeepStore UI contract (product detail)
   - Galleria Swiper (se presente)
   - Stepper quantità (no inline script)
*/

(function () {
  'use strict';

  function toInt(val, fallback) {
    var n = parseInt(val, 10);
    return isNaN(n) ? fallback : n;
  }

  function initQtySteppers() {
    var steppers = document.querySelectorAll('.ks-qty-stepper, .product-quantity .wg-quantity');
    if (!steppers || steppers.length === 0) return;

    for (var i = 0; i < steppers.length; i++) {
      (function (wrap) {
        if (wrap.getAttribute('data-ks-qty-bound') === '1') return;
        wrap.setAttribute('data-ks-qty-bound', '1');

        var input = wrap.querySelector('input');
        if (!input) return;

        var btnMinus = wrap.querySelector('[data-ks-qty="minus"]');
        var btnPlus = wrap.querySelector('[data-ks-qty="plus"]');

        function clampAndSet(next) {
          if (next < 1) next = 1;
          input.value = String(next);
        }

        if (btnMinus) {
          btnMinus.addEventListener('click', function (ev) {
            if (ev) {
              ev.preventDefault();
              ev.stopPropagation();
              if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
            }
            var cur = toInt(input.value, 1);
            clampAndSet(cur - 1);
          }, true);
        }

        if (btnPlus) {
          btnPlus.addEventListener('click', function (ev) {
            if (ev) {
              ev.preventDefault();
              ev.stopPropagation();
              if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
            }
            var cur = toInt(input.value, 1);
            clampAndSet(cur + 1);
          }, true);
        }

        // Hardening: se l'utente digita, normalizza
        input.addEventListener('blur', function () {
          clampAndSet(toInt(input.value, 1));
        });
      })(steppers[i]);
    }
  }

  function initProductGallery() {
    if (typeof window.Swiper === 'undefined') return;

    var mainEl = document.querySelector('.ks-product-gallery-main');
    var thumbsEl = document.querySelector('.ks-product-gallery-thumbs');

    if (!mainEl) return;

    // Thumbs (opzionali)
    var thumbs = null;
    if (thumbsEl) {
      thumbs = new window.Swiper(thumbsEl, {
        slidesPerView: 4,
        spaceBetween: 10,
        watchSlidesProgress: true,
        breakpoints: {
          576: { slidesPerView: 5 },
          992: { slidesPerView: 6 }
        }
      });
    }

    // Main
    new window.Swiper(mainEl, {
      loop: false,
      spaceBetween: 10,
      navigation: {
        nextEl: mainEl.querySelector('.swiper-button-next'),
        prevEl: mainEl.querySelector('.swiper-button-prev')
      },
      pagination: {
        el: mainEl.querySelector('.swiper-pagination'),
        clickable: true
      },
      thumbs: thumbs ? { swiper: thumbs } : undefined
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initQtySteppers();
    initProductGallery();
  });
})();
