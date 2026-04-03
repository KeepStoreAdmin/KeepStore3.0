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
    if (node) node.style.display = 'none';
  }

  function updateAllSwipers() {
    Array.prototype.slice.call(document.querySelectorAll('.swiper')).forEach(function (swiperEl) {
      if (swiperEl.swiper && typeof swiperEl.swiper.update === 'function') {
        swiperEl.swiper.update();
      }
    });
  }

  function initHero() {
    var hero = document.querySelector('.ks-home-hero-slider');
    if (!hero) return;

    var slides = hero.querySelectorAll('.swiper-slide');
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
      loop: brand.querySelectorAll('.swiper-slide').length > 6,
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
      loop: slider.querySelectorAll('.swiper-slide').length > 4,
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
      var slides = el.querySelectorAll('.swiper-slide').length;

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

  function normalizeCardHeights() {
    var groups = [
      '.ks-grid-card .card-product-info',
      '.ks-row-card .card-product-info',
      '.ks-deal-card .card-product-info'
    ];

    groups.forEach(function (selector) {
      var nodes = Array.prototype.slice.call(document.querySelectorAll(selector));
      if (!nodes.length) return;

      nodes.forEach(function (node) { node.style.minHeight = '0px'; });
      var max = 0;
      nodes.forEach(function (node) {
        max = Math.max(max, node.offsetHeight || 0);
      });
      if (window.innerWidth >= 992) {
        nodes.forEach(function (node) { node.style.minHeight = max + 'px'; });
      }
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
      menu.style.maxHeight = '';
      return;
    }

    menu.style.maxHeight = 'none';

    var target = 0;
    if (sliderWrap && sliderWrap.offsetParent !== null) {
      target = Math.max(target, sliderWrap.offsetHeight || 0);
    }
    if (sideWrap && sideWrap.offsetParent !== null) {
      target = Math.max(target, sideWrap.offsetHeight || 0);
    }

    if (target > 0) {
      menu.style.minHeight = target + 'px';
    } else {
      menu.style.minHeight = '';
    }
  }

  function refreshSwipersInTabs() {
    Array.prototype.slice.call(document.querySelectorAll('[data-bs-toggle="tab"]')).forEach(function (trigger) {
      trigger.addEventListener('shown.bs.tab', function () {
        updateAllSwipers();
        window.setTimeout(normalizeCardHeights, 80);
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
        }, 60);
      }, { once: true });
    });
  }

  function normalizeImages() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-grid-card img, .ks-big-card img, .ks-deal-card img')).forEach(function (img) {
      img.setAttribute('loading', 'lazy');
    });
  }

  function boot() {
    initHero();
    initBrandSlider();
    initCollectionSlider();
    initColumnSwipers();
    normalizeImages();
    normalizeCardHeights();
    syncHeroLayout();
    refreshSwipersInTabs();
    bindImageDrivenRefresh();

    window.addEventListener('resize', function () {
      normalizeCardHeights();
      syncHeroLayout();
      updateAllSwipers();
    });
  }

  onReady(boot);
})();
