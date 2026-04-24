(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function qa(selector, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(selector));
  }

  function q(selector, root) {
    return (root || document).querySelector(selector);
  }

  function isHome() {
    var path = (window.location.pathname || '/').toLowerCase();
    return path === '/' || /\/default\.aspx$/i.test(path);
  }

  function hideNode(node) {
    if (!node) return;
    node.style.setProperty('display', 'none', 'important');
  }

  function showNode(node) {
    if (!node) return;
    node.style.removeProperty('display');
    node.removeAttribute('hidden');
  }

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    return new Swiper(root, options);
  }

  function updateAllSwipers() {
    qa('.swiper').forEach(function (swiperEl) {
      if (swiperEl.swiper && typeof swiperEl.swiper.update === 'function') {
        swiperEl.swiper.update();
      }
    });
  }

  function isProtectedDirectChild(node) {
    if (!node || node.nodeType !== 1) return true;
    var tag = String(node.tagName || '').toLowerCase();
    if (/^(script|style|link|input|select|textarea)$/.test(tag)) return true;
    if (node.id === 'wrapper' || node.id === 'goTop' || node.id === 'preload') return true;
    if (node.classList && (node.classList.contains('modal') || node.classList.contains('offcanvas'))) return true;
    if (node.getAttribute && node.getAttribute('role') === 'dialog') return true;
    return false;
  }

  function quarantineForeignDirectChildren() {
    if (!isHome()) return;

    var form = document.getElementById('form1') || q('body > form');
    if (form) {
      qa(':scope > *', form).forEach(function (node) {
        if (isProtectedDirectChild(node)) return;
        node.setAttribute('data-ks-artifact', 'foreign-direct-child');
        hideNode(node);
      });
    }

    var wrapper = document.getElementById('wrapper');
    if (wrapper) {
      qa(':scope > *', wrapper).forEach(function (node) {
        var tag = String(node.tagName || '').toLowerCase();
        if (/^(header|main|footer)$/.test(tag)) return;
        node.setAttribute('data-ks-artifact', 'wrapper-extra-child');
        hideNode(node);
      });
    }
  }

  function initHero() {
    var hero = q('.ks-home-hero-slider');
    if (!hero) return;

    var slides = qa('.swiper-slide', hero).filter(function (slide) {
      return !!q('img[src],img[data-src]', slide);
    });
    var allowLoop = slides.length > 1;
    var prev = q('.ks-hero-prev', hero);
    var next = q('.ks-hero-next', hero);
    var pag = q('.ks-hero-pagination', hero);

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
    var brand = q('.ks-home-brands');
    if (!brand) return;
    buildSwiper(brand, {
      loop: qa('.swiper-slide', brand).filter(function (slide) { return slide.offsetParent !== null; }).length > 6,
      slidesPerView: 2,
      spaceBetween: 15,
      breakpoints: {
        576: { slidesPerView: 3, spaceBetween: 15 },
        768: { slidesPerView: 4, spaceBetween: 20 },
        1200: { slidesPerView: 6, spaceBetween: 30 }
      },
      pagination: {
        el: q('.ks-home-brands-pagination', brand),
        clickable: true
      },
      autoplay: { delay: 3500, disableOnInteraction: false }
    });
  }

  function initCollectionSlider() {
    var slider = q('.ks-home-collection-swiper');
    if (!slider) return;
    buildSwiper(slider, {
      loop: qa('.swiper-slide', slider).length > 4,
      slidesPerView: 1,
      spaceBetween: 15,
      breakpoints: {
        576: { slidesPerView: 2, spaceBetween: 15 },
        768: { slidesPerView: 3, spaceBetween: 20 },
        1200: { slidesPerView: 4, spaceBetween: 30 }
      },
      pagination: {
        el: q('.ks-home-collection-pagination', slider),
        clickable: true
      },
      autoplay: { delay: 4000, disableOnInteraction: false }
    });
  }

  function initColumnSwipers() {
    qa('.ks-column-swiper').forEach(function (el) {
      if (!el || el.swiper || typeof Swiper === 'undefined') return;

      var wrapper = el.closest('.box-btn-slide-item') || el.parentElement;
      var prev = wrapper ? q('.ks-col-prev', wrapper) : null;
      var next = wrapper ? q('.ks-col-next', wrapper) : null;
      var pag = q('.ks-col-pagination', el);
      var slides = qa('.swiper-slide', el).filter(function (slide) { return slide.offsetParent !== null; }).length;

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
      var nodes = qa(selector);
      if (!nodes.length) return;

      nodes.forEach(function (node) { node.style.minHeight = '0px'; });
      var max = 0;
      nodes.forEach(function (node) { max = Math.max(max, node.offsetHeight || 0); });
      if (window.innerWidth >= 992) {
        nodes.forEach(function (node) { node.style.minHeight = max + 'px'; });
      }
    });
  }

  function syncHeroLayout() {
    var shell = q('.ks-home-hero-shell');
    var menu = q('.ks-home-departments .menu-category-list');
    if (!shell || !menu) return;

    var sliderWrap = q('.wrap-item-2', shell);

    if (window.innerWidth < 1200) {
      menu.style.minHeight = '';
      menu.style.maxHeight = '';
      return;
    }

    var target = sliderWrap && sliderWrap.offsetParent !== null ? (sliderWrap.offsetHeight || 0) : 0;
    if (target > 0) {
      menu.style.minHeight = target + 'px';
      menu.style.maxHeight = Math.max(420, target) + 'px';
    } else {
      menu.style.minHeight = '';
      menu.style.maxHeight = '';
    }
  }

  function refreshSwipersInTabs() {
    qa('[data-bs-toggle="tab"]').forEach(function (trigger) {
      trigger.addEventListener('shown.bs.tab', function () {
        updateAllSwipers();
        window.setTimeout(normalizeCardHeights, 80);
      });
    });
  }

  function bindImageDrivenRefresh() {
    qa('.ks-page-home img').forEach(function (img) {
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
    qa('.ks-grid-card img,.ks-big-card img,.ks-deal-card img,.ksh-grid-card img,.ksh-big img,.ksh-deal img').forEach(function (img) {
      img.setAttribute('loading', 'lazy');
      img.setAttribute('decoding', 'async');
    });
  }

  function boot() {
    if (!isHome()) return;
    quarantineForeignDirectChildren();
    initHero();
    initBrandSlider();
    initCollectionSlider();
    initColumnSwipers();
    normalizeImages();
    normalizeCardHeights();
    syncHeroLayout();
    refreshSwipersInTabs();
    bindImageDrivenRefresh();

    [250, 900, 2500].forEach(function (delay) {
      window.setTimeout(function () {
        quarantineForeignDirectChildren();
        syncHeroLayout();
        updateAllSwipers();
      }, delay);
    });

    window.addEventListener('resize', function () {
      normalizeCardHeights();
      syncHeroLayout();
      updateAllSwipers();
    });
  }

  onReady(boot);
})();
