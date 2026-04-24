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
          forceHeroFill();
          syncHeroLayout();
        }, 60);
      }, { once: true });
    });
  }



  function hasProductContent(root) {
    if (!root) return false;
    if (q('a[href*="articolo.aspx?id="]', root)) return true;
    if (q('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.ksh-side,.ksh-grid-card,.ksh-big,.ksh-deal', root)) return true;
    return false;
  }

  function hideRuntimeNode(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-empty-section', reason || '1');
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
  }


  function forceHeroFill() {
    if (!isHome()) return;
    var section = q('#HomeHeroSection') || q('.ks-home-hero-section');
    var hero = q('.ks-home-hero-slider', section || document);
    var wrap = q('#HeroSliderWrap', section || document);
    var img = q('.ks-home-hero-slider img[src],.ks-home-hero-slider img[data-src]', section || document);
    if (!section || !hero || !wrap || !img) return;

    showNode(section);
    showNode(wrap);
    showNode(hero);

    section.classList.remove('ks-home-hero-mode-none');
    section.classList.add('ks-home-hero-mode-compact-single');
    var shell = q('.ks-home-hero-shell', section);
    if (shell) {
      shell.classList.remove('ks-home-hero-mode-none', 'ks-home-hero-mode-full');
      shell.classList.add('ks-home-hero-mode-compact-single');
    }

    var fillNodes = qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media.img-style,.ks-home-hero-media.img-item,.ks-home-hero-banner > a,.ks-home-hero-slider a', section);
    fillNodes.forEach(function (node) {
      node.style.setProperty('display', 'block', 'important');
      node.style.setProperty('width', '100%', 'important');
      node.style.setProperty('max-width', 'none', 'important');
      node.style.setProperty('height', '100%', 'important');
      node.style.setProperty('min-height', '420px', 'important');
      node.style.setProperty('box-sizing', 'border-box', 'important');
    });

    qa('.ks-home-hero-slider img', section).forEach(function (image) {
      image.style.setProperty('display', 'block', 'important');
      image.style.setProperty('width', '100%', 'important');
      image.style.setProperty('max-width', 'none', 'important');
      image.style.setProperty('height', '100%', 'important');
      image.style.setProperty('min-height', '420px', 'important');
      image.style.setProperty('object-fit', 'cover', 'important');
      image.style.setProperty('object-position', 'center center', 'important');
    });

    if (hero.swiper && typeof hero.swiper.update === 'function') hero.swiper.update();
  }

  function countDistinctProductLinks(root) {
    var seen = {};
    qa('a[href*="articolo.aspx?id="]', root).forEach(function (a) {
      var href = a.getAttribute('href') || '';
      var m = href.match(/[?&]id=(\d+)/i);
      var id = m ? m[1] : href;
      if (id) seen[id] = 1;
    });
    return Object.keys(seen).length;
  }

  function removeDuplicateChrome() {
    if (!isHome()) return;

    var firstHeader = q('#wrapper > header[data-ks-header], #wrapper > header.tf-header, header[data-ks-header], header.tf-header');

    qa('main header, main .tf-header, main .ks-header-ui, main .tf-topbar, main .inner-header, main .header-bottom').forEach(function (node) {
      node.setAttribute('data-ks-duplicate-chrome', 'main-chrome');
      hideNode(node);
    });

    qa('header.tf-header, header.ks-header-ui, header[data-ks-header]').forEach(function (header) {
      if (header === firstHeader) return;
      header.setAttribute('data-ks-duplicate-chrome', 'header-clone');
      hideNode(header);
    });

    qa('.tf-topbar, .inner-header, .header-bottom').forEach(function (node) {
      var parentHeader = node.closest('header');
      if (parentHeader && parentHeader === firstHeader) return;
      if (node.closest('main') || (parentHeader && parentHeader !== firstHeader)) {
        node.setAttribute('data-ks-duplicate-chrome', 'chrome-piece');
        hideNode(node);
      }
    });

    var firstFooter = q('#wrapper > footer.tf-footer, footer.tf-footer');
    qa('footer.tf-footer').forEach(function (footer) {
      if (footer === firstFooter) return;
      footer.setAttribute('data-ks-duplicate-chrome', 'footer-clone');
      hideNode(footer);
    });
  }


  function closeEmptyHomeSections() {
    if (!isHome()) return;

    qa('section.tf-sp-2.pt-0').forEach(function (section) {
      var title = (section.textContent || '').toLowerCase();
      if (title.indexOf('occasione') >= 0 && countDistinctProductLinks(section) < 1) {
        hideRuntimeNode(section, 'deal-empty');
      }
    });

    qa('.flat-animate-tab').forEach(function (section) {
      if (countDistinctProductLinks(section) < 1) hideRuntimeNode(section, 'tabs-empty');
    });

    var recent = q('#HomeRecentlyViewedSection');
    if (recent) {
      var recentCount = countDistinctProductLinks(recent);
      if (recentCount > 0 && recentCount < 2) hideRuntimeNode(recent, 'recent-under-threshold');
    }

    var lower = q('#HomeLowerColumnsSection');
    if (lower) {
      var visibleBlocks = 0;
      qa('.tf-grid-product-item', lower).forEach(function (block) {
        var count = countDistinctProductLinks(block);
        if (count < 3) {
          hideRuntimeNode(block, 'lower-block-under-threshold');
          block.setAttribute('data-ks-lower-valid', '0');
          return;
        }
        block.setAttribute('data-ks-lower-valid', '1');
        visibleBlocks += 1;
      });
      lower.setAttribute('data-ks-visible-blocks', String(visibleBlocks));
      if (visibleBlocks === 0) hideRuntimeNode(lower, 'lower-empty');
      if (visibleBlocks === 1) lower.classList.add('ks-lower-single');
      else lower.classList.remove('ks-lower-single');
    }
  }


  function stabilizeHomeRuntime() {
    removeDuplicateChrome();
    closeEmptyHomeSections();
    forceHeroFill();
    syncHeroLayout();
    updateAllSwipers();
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
    removeDuplicateChrome();
    initHero();
    forceHeroFill();
    initBrandSlider();
    initCollectionSlider();
    initColumnSwipers();
    normalizeImages();
    normalizeCardHeights();
    closeEmptyHomeSections();
    forceHeroFill();
    syncHeroLayout();
    refreshSwipersInTabs();
    bindImageDrivenRefresh();

    [120, 250, 900, 2500, 6000].forEach(function (delay) {
      window.setTimeout(function () {
        quarantineForeignDirectChildren();
        stabilizeHomeRuntime();
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
