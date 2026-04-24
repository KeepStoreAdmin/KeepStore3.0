(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function q(selector, root) { return (root || document).querySelector(selector); }
  function qa(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
  function isHome() {
    var path = (window.location.pathname || '/').toLowerCase();
    return path === '/' || /\/default\.aspx$/i.test(path);
  }
  function hide(node, reason) {
    if (!node || node.nodeType !== 1) return;
    if (reason) node.setAttribute('data-ks-hidden-reason', reason);
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
  }
  function show(node) {
    if (!node || node.nodeType !== 1) return;
    node.style.removeProperty('display');
    node.style.removeProperty('visibility');
    node.style.removeProperty('opacity');
    node.style.removeProperty('pointer-events');
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
  }
  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    return new Swiper(root, options);
  }
  function updateAllSwipers() {
    qa('.swiper').forEach(function (el) {
      if (el.swiper && typeof el.swiper.update === 'function') el.swiper.update();
    });
  }

  function normalizeChromeOrder() {
    if (!isHome()) return;
    var wrapper = document.getElementById('wrapper');
    if (!wrapper) return;

    var main = q(':scope > main', wrapper) || q('main', wrapper) || q('main');
    var footer = q(':scope > footer.tf-footer', wrapper) || q('footer.tf-footer');
    var headers = qa('header[data-ks-header], header.ks-header-ui, header.tf-header');
    var header = null;

    headers.forEach(function (h) {
      if (!header && (h.hasAttribute('data-ks-header') || h.classList.contains('ks-header-ui'))) header = h;
    });
    if (!header && headers.length) header = headers[0];

    if (header && main) {
      if (header.parentNode !== wrapper || header.nextElementSibling !== main) {
        wrapper.insertBefore(header, main);
      }
      show(header);
      header.removeAttribute('data-ks-duplicate-chrome');
    }

    qa('header[data-ks-header], header.ks-header-ui, header.tf-header').forEach(function (h) {
      if (h !== header) {
        h.setAttribute('data-ks-duplicate-chrome', 'header-clone');
        hide(h, 'header-clone');
      }
    });

    qa('.tf-topbar,.inner-header,.header-bottom').forEach(function (part) {
      if (header && header.contains(part)) return;
      if (part.closest('main') || part.closest('footer') || part.parentNode === wrapper) {
        part.setAttribute('data-ks-duplicate-chrome', 'header-piece');
        hide(part, 'header-piece');
      }
    });

    if (footer && main && footer.parentNode !== wrapper) {
      wrapper.appendChild(footer);
    }
    var firstFooter = q(':scope > footer.tf-footer', wrapper) || footer;
    qa('footer.tf-footer').forEach(function (f) {
      if (f !== firstFooter) {
        f.setAttribute('data-ks-duplicate-chrome', 'footer-clone');
        hide(f, 'footer-clone');
      }
    });
  }

  function quarantineForeignDirectChildren() {
    if (!isHome()) return;
    var form = document.getElementById('form1') || q('body > form');
    if (!form) return;
    qa(':scope > *', form).forEach(function (node) {
      var tag = String(node.tagName || '').toLowerCase();
      if (node.id === 'wrapper' || node.id === 'goTop' || node.id === 'preload') return;
      if (/^(script|style|link|input|select|textarea)$/.test(tag)) return;
      if (node.classList && (node.classList.contains('modal') || node.classList.contains('offcanvas'))) return;
      if (node.getAttribute && node.getAttribute('role') === 'dialog') return;
      node.setAttribute('data-ks-artifact', 'foreign-direct-child');
      hide(node, 'foreign-direct-child');
    });
  }

  function initHeroSwiper() {
    var hero = q('.ks-home-hero-slider');
    if (!hero) return;
    var slides = qa('.swiper-slide', hero).filter(function (slide) { return !!q('img[src],img[data-src]', slide); });
    var loop = slides.length > 1;
    var prev = q('.ks-hero-prev', hero);
    var next = q('.ks-hero-next', hero);
    var pag = q('.ks-hero-pagination', hero);
    buildSwiper(hero, {
      loop: loop,
      effect: 'slide',
      speed: 700,
      autoplay: loop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false,
      pagination: { el: pag, clickable: true },
      navigation: { nextEl: next, prevEl: prev }
    });
    if (!loop) { hide(prev, 'single-hero'); hide(next, 'single-hero'); hide(pag, 'single-hero'); }
  }

  function markBlankHeroImage(img, section) {
    if (!img || !section || img.getAttribute('data-ks-hero-analysed') === '1') return;
    if (!img.complete || !img.naturalWidth || !img.naturalHeight) return;
    img.setAttribute('data-ks-hero-analysed', '1');
    try {
      var canvas = document.createElement('canvas');
      var w = 96, h = 64;
      canvas.width = w; canvas.height = h;
      var ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(img, 0, 0, w, h);
      var data = ctx.getImageData(0, 0, w, h).data;
      var rightBright = 0, rightTotal = 0, leftDark = 0, leftTotal = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var i = (y * w + x) * 4;
          var r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
          if (a < 20) continue;
          var bright = (r + g + b) / 3;
          if (x > w * 0.56) {
            rightTotal++;
            if (bright > 235 && Math.abs(r - g) < 10 && Math.abs(r - b) < 10) rightBright++;
          } else if (x < w * 0.44) {
            leftTotal++;
            if (bright < 80) leftDark++;
          }
        }
      }
      var rb = rightTotal ? rightBright / rightTotal : 0;
      var ld = leftTotal ? leftDark / leftTotal : 0;
      if (rb > 0.58 && ld > 0.18) section.classList.add('ks-hero-crop-left');
    } catch (err) {
      /* Cross-origin images cannot be sampled. Leave default cover mode. */
    }
  }

  function forceHeroLayout() {
    if (!isHome()) return;
    var section = q('#HomeHeroSection') || q('.ks-home-hero-section');
    if (!section) return;
    var shell = q('.ks-home-hero-shell,.s-banner-wrapper', section);
    var sliderWrap = q('#HeroSliderWrap,.wrap-item-2', section);
    var hero = q('.ks-home-hero-slider', section);
    var menuList = q('.ks-home-departments .menu-category-list', section);
    var img = q('.ks-home-hero-slider img[src],.ks-home-hero-slider img[data-src]', section);

    if (!hero || !sliderWrap || !img) {
      section.classList.add('ks-home-hero-mode-none');
      hide(section, 'hero-without-valid-image');
      return;
    }

    show(section); show(sliderWrap); show(hero);
    section.classList.remove('ks-home-hero-mode-none', 'ks-home-hero-mode-full');
    section.classList.add('ks-home-hero-mode-compact-single');
    if (shell) {
      shell.classList.remove('ks-home-hero-mode-none', 'ks-home-hero-mode-full');
      shell.classList.add('ks-home-hero-mode-compact-single');
    }

    var heroHeight = 420;
    if (window.innerWidth >= 1200) {
      var menuHeight = menuList ? Math.max(menuList.scrollHeight || 0, menuList.offsetHeight || 0) : 0;
      heroHeight = Math.max(420, Math.min(520, menuHeight || 420));
    }

    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media.img-style,.ks-home-hero-media.img-item,.ks-home-hero-banner > a,.ks-home-hero-slider a', section).forEach(function (node) {
      node.style.setProperty('display', 'block', 'important');
      node.style.setProperty('width', '100%', 'important');
      node.style.setProperty('max-width', 'none', 'important');
      node.style.setProperty('height', heroHeight + 'px', 'important');
      node.style.setProperty('min-height', heroHeight + 'px', 'important');
      node.style.setProperty('box-sizing', 'border-box', 'important');
      node.style.setProperty('overflow', 'hidden', 'important');
    });

    qa('.ks-home-hero-slider img', section).forEach(function (image) {
      image.style.setProperty('display', 'block', 'important');
      image.style.setProperty('width', '100%', 'important');
      image.style.setProperty('max-width', 'none', 'important');
      image.style.setProperty('height', heroHeight + 'px', 'important');
      image.style.setProperty('min-height', heroHeight + 'px', 'important');
      image.style.setProperty('object-fit', 'cover', 'important');
      image.style.setProperty('object-position', 'center center', 'important');
    });

    if (menuList && window.innerWidth >= 1200) {
      menuList.style.setProperty('min-height', heroHeight + 'px', 'important');
      menuList.style.setProperty('max-height', heroHeight + 'px', 'important');
    }

    markBlankHeroImage(img, section);
    if (hero.swiper && typeof hero.swiper.update === 'function') hero.swiper.update();
  }

  function countProductLinks(root) {
    if (!root) return 0;
    var seen = {};
    qa('a[href*="articolo.aspx?id="]', root).forEach(function (a) {
      if (a.closest('[data-ks-hidden-reason]')) return;
      var href = a.getAttribute('href') || '';
      var m = href.match(/[?&]id=(\d+)/i);
      var key = m ? m[1] : href;
      if (key) seen[key] = 1;
    });
    return Object.keys(seen).length;
  }

  function sectionHasRealCards(root) {
    return countProductLinks(root) > 0 || !!q('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.ksh-grid-card,.ksh-side,.ksh-big,.ksh-deal', root);
  }

  function normalizeTabbedBlocks() {
    qa('.flat-animate-tab').forEach(function (section) {
      var count = countProductLinks(section);
      if (count < 1) {
        section.setAttribute('data-ks-empty-section', 'tabs-empty');
        hide(section, 'tabs-empty');
        return;
      }
      section.removeAttribute('data-ks-empty-section');
      show(section);
    });
  }

  function normalizeDealBlock() {
    qa('section.tf-sp-2.pt-0').forEach(function (section) {
      if (!/occasione|deal/i.test(textOf(section))) return;
      if (countProductLinks(section) < 1 && !q('.ks-deal-card,.ksh-deal,.card-product', section)) {
        section.setAttribute('data-ks-empty-section', 'deal-empty');
        hide(section, 'deal-empty');
      }
    });
  }

  function normalizeLowerBlocks() {
    var lower = q('#HomeLowerColumnsSection');
    if (!lower) return;
    var visible = 0;
    qa('.tf-grid-product-item', lower).forEach(function (block) {
      var count = countProductLinks(block);
      if (count < 3) {
        block.setAttribute('data-ks-lower-valid', '0');
        hide(block, 'lower-under-threshold');
      } else {
        block.setAttribute('data-ks-lower-valid', '1');
        show(block);
        visible++;
      }
    });
    lower.setAttribute('data-ks-visible-blocks', String(visible));
    lower.classList.toggle('ks-lower-single', visible === 1);
    lower.classList.toggle('ks-lower-two', visible === 2);
    lower.classList.toggle('ks-lower-three', visible === 3);
    if (visible === 0) hide(lower, 'lower-empty');
    else show(lower);
  }

  function normalizeRecentBlock() {
    var recent = q('#HomeRecentlyViewedSection');
    if (!recent) return;
    var count = countProductLinks(recent);
    if (count > 0 && count < 2) hide(recent, 'recent-under-threshold');
  }

  function closeEmptySections() {
    normalizeDealBlock();
    normalizeTabbedBlocks();
    normalizeRecentBlock();
    normalizeLowerBlocks();
  }

  function initBrandSlider() {
    var brand = q('.ks-home-brands');
    if (!brand) return;
    buildSwiper(brand, {
      loop: qa('.swiper-slide', brand).length > 6,
      slidesPerView: 2,
      spaceBetween: 15,
      breakpoints: {
        576: { slidesPerView: 3, spaceBetween: 15 },
        768: { slidesPerView: 4, spaceBetween: 20 },
        1200: { slidesPerView: 6, spaceBetween: 30 }
      },
      pagination: { el: q('.ks-home-brands-pagination', brand), clickable: true },
      autoplay: { delay: 3500, disableOnInteraction: false }
    });
  }

  function initColumnSwipers() {
    qa('.ks-column-swiper').forEach(function (el) {
      if (!el || el.swiper || typeof Swiper === 'undefined') return;
      var block = el.closest('.box-btn-slide-item') || el.parentElement;
      var slides = qa('.swiper-slide', el).length;
      buildSwiper(el, {
        loop: slides > 1,
        slidesPerView: 1,
        spaceBetween: 20,
        pagination: { el: q('.ks-col-pagination', el), clickable: true },
        navigation: { nextEl: block ? q('.ks-col-next', block) : null, prevEl: block ? q('.ks-col-prev', block) : null },
        autoplay: slides > 1 ? { delay: 4500, disableOnInteraction: false } : false
      });
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
      pagination: { el: q('.ks-home-collection-pagination', slider), clickable: true },
      autoplay: { delay: 4000, disableOnInteraction: false }
    });
  }

  function bindImageRefresh() {
    qa('body.ks-page-home img').forEach(function (img) {
      if (!img || img.complete) return;
      img.addEventListener('load', function () {
        window.setTimeout(stabilizeHome, 80);
      }, { once: true });
    });
  }

  function normalizeImages() {
    qa('.ks-grid-card img,.ks-row-card img,.ks-big-card img,.ks-deal-card img,.ksh-grid-card img,.ksh-side img,.ksh-big img,.ksh-deal img').forEach(function (img) {
      img.setAttribute('loading', 'lazy');
      img.setAttribute('decoding', 'async');
    });
  }

  function stabilizeHome() {
    if (!isHome()) return;
    normalizeChromeOrder();
    quarantineForeignDirectChildren();
    forceHeroLayout();
    closeEmptySections();
    updateAllSwipers();
  }

  function boot() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home');
    normalizeChromeOrder();
    quarantineForeignDirectChildren();
    initHeroSwiper();
    initBrandSlider();
    initCollectionSlider();
    initColumnSwipers();
    normalizeImages();
    bindImageRefresh();
    stabilizeHome();

    [80, 180, 420, 900, 1800, 3600].forEach(function (delay) {
      window.setTimeout(stabilizeHome, delay);
    });

    var observer = null;
    try {
      observer = new MutationObserver(function () { window.clearTimeout(observer._ksTimer); observer._ksTimer = window.setTimeout(stabilizeHome, 60); });
      observer.observe(document.getElementById('wrapper') || document.body, { childList: true, subtree: true });
    } catch (err) {}

    window.addEventListener('resize', function () { window.setTimeout(stabilizeHome, 80); });
  }

  onReady(boot);
})();
