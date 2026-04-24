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
  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }

  function hide(node, reason) {
    if (!node || node.nodeType !== 1) return;
    if (reason) node.setAttribute('data-ks-hidden-reason', reason);
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.style.setProperty('height', '0', 'important');
    node.style.setProperty('min-height', '0', 'important');
    node.style.setProperty('max-height', '0', 'important');
    node.style.setProperty('margin', '0', 'important');
    node.style.setProperty('padding', '0', 'important');
    node.style.setProperty('overflow', 'hidden', 'important');
  }

  function show(node) {
    if (!node || node.nodeType !== 1) return;
    node.style.removeProperty('display');
    node.style.removeProperty('visibility');
    node.style.removeProperty('opacity');
    node.style.removeProperty('pointer-events');
    node.style.removeProperty('height');
    node.style.removeProperty('min-height');
    node.style.removeProperty('max-height');
    node.style.removeProperty('margin');
    node.style.removeProperty('padding');
    node.style.removeProperty('overflow');
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
  }

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    return new Swiper(root, options);
  }

  function updateAllSwipers() {
    qa('.swiper').forEach(function (el) {
      if (el.swiper && typeof el.swiper.update === 'function') el.swiper.update();
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

  function forceHeroLayout() {
    var section = q('#HomeHeroSection') || q('.ks-home-hero-section');
    if (!section) return;
    var shell = q('.ks-home-hero-shell,.s-banner-wrapper', section);
    var sliderWrap = q('#HeroSliderWrap,.wrap-item-2', section);
    var hero = q('.ks-home-hero-slider', section);
    var img = q('.ks-home-hero-slider img[src],.ks-home-hero-slider img[data-src]', section);
    var menuList = q('.ks-home-departments .menu-category-list', section);

    if (!hero || !sliderWrap || !img) {
      hide(section, 'hero-without-image');
      return;
    }

    show(section); show(sliderWrap); show(hero);
    section.classList.remove('ks-home-hero-mode-none', 'ks-home-hero-mode-full');
    section.classList.add('ks-home-hero-mode-compact-single');
    if (shell) {
      shell.classList.remove('ks-home-hero-mode-none', 'ks-home-hero-mode-full');
      shell.classList.add('ks-home-hero-mode-compact-single');
    }

    var heroHeight = window.innerWidth >= 1200 ? 420 : 320;
    if (window.innerWidth >= 1200 && menuList) {
      heroHeight = Math.max(400, Math.min(470, Math.max(menuList.scrollHeight || 0, menuList.offsetHeight || 0, 420)));
    }

    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media.img-style,.ks-home-hero-media.img-item,.ks-home-hero-banner > a,.ks-home-hero-slider a', section).forEach(function (node) {
      node.style.setProperty('display', 'block', 'important');
      node.style.setProperty('width', '100%', 'important');
      node.style.setProperty('max-width', 'none', 'important');
      node.style.setProperty('height', heroHeight + 'px', 'important');
      node.style.setProperty('min-height', heroHeight + 'px', 'important');
      node.style.setProperty('overflow', 'hidden', 'important');
      node.style.setProperty('box-sizing', 'border-box', 'important');
    });

    qa('.ks-home-hero-slider img', section).forEach(function (image) {
      image.style.setProperty('display', 'block', 'important');
      image.style.setProperty('width', '100%', 'important');
      image.style.setProperty('height', heroHeight + 'px', 'important');
      image.style.setProperty('max-width', 'none', 'important');
      image.style.setProperty('object-fit', 'cover', 'important');
      image.style.setProperty('object-position', 'center center', 'important');
    });

    if (menuList && window.innerWidth >= 1200) {
      menuList.style.setProperty('min-height', heroHeight + 'px', 'important');
      menuList.style.setProperty('max-height', heroHeight + 'px', 'important');
    }
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

  function isVisible(node) {
    if (!node || node.nodeType !== 1) return false;
    var st = window.getComputedStyle ? window.getComputedStyle(node) : null;
    if (st && (st.display === 'none' || st.visibility === 'hidden' || parseFloat(st.opacity || '1') === 0)) return false;
    var r = node.getBoundingClientRect ? node.getBoundingClientRect() : null;
    return !!(r && r.width > 20 && r.height > 20);
  }

  function countArticleLinks(root) {
    var seen = {};
    qa('a[href*="articolo.aspx?id="]', root).forEach(function (a) {
      if (a.closest('[data-ks-hidden-reason]')) return;
      var href = a.getAttribute('href') || '';
      var m = href.match(/[?&]id=(\d+)/i);
      seen[m ? m[1] : href] = 1;
    });
    return Object.keys(seen).length;
  }

  function countVisibleProductImages(root) {
    var seen = {}, n = 0;
    qa('a[href*="articolo.aspx?id="] img,.card-product img,.ks-grid-card img,.ks-row-card img,.ks-big-card img,.ks-deal-card img', root).forEach(function (img) {
      if (!isVisible(img)) return;
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src || /logo|brand|pagamenti|payment|mail\.svg|headphone|spinner|favicon/i.test(src)) return;
      if (seen[src]) return;
      seen[src] = 1;
      n += 1;
    });
    return n;
  }

  function normalizeCommercialSections() {
    qa('section.tf-sp-2.pt-0').forEach(function (section) {
      if (/occasione|deal/i.test(textOf(section)) && countVisibleProductImages(section) < 1) hide(section, 'deal-empty');
    });

    qa('.flat-animate-tab').forEach(function (section) {
      if (countVisibleProductImages(section) < 3) hide(section, 'tabs-empty');
    });

    var recent = q('#HomeRecentlyViewedSection');
    if (recent && countArticleLinks(recent) > 0 && countVisibleProductImages(recent) < 2) hide(recent, 'recent-under-threshold');

    var lower = q('#HomeLowerColumnsSection');
    if (lower) {
      var visible = 0;
      qa('.tf-grid-product-item', lower).forEach(function (block) {
        if (countVisibleProductImages(block) < 3) {
          block.setAttribute('data-ks-lower-valid', '0');
          hide(block, 'lower-under-threshold');
        } else {
          block.setAttribute('data-ks-lower-valid', '1');
          visible += 1;
          show(block);
        }
      });
      lower.setAttribute('data-ks-visible-blocks', String(visible));
      lower.classList.toggle('ks-lower-single', visible === 1);
      lower.classList.toggle('ks-lower-two', visible === 2);
      lower.classList.toggle('ks-lower-three', visible === 3);
      if (visible === 0) hide(lower, 'lower-empty');
      else show(lower);
    }

    qa('main .text-primary, main .new-price, main .old-price, main [class*="price"]').forEach(function (node) {
      if (!node || node.closest('#HomeHeroSection') || node.closest('#HomeBrandsSection') || node.closest('header') || node.closest('footer')) return;
      var txt = textOf(node);
      if (!/\d+[\d.,]*\s*€/.test(txt)) return;
      var host = node.closest('section,.tf-grid-product-item,.product-list-wrap,li,.card-product,.ks-row-card,.ks-grid-card') || node;
      if (host && countVisibleProductImages(host) === 0) hide(host, 'orphan-price');
    });
  }

  function chromeRoot(node) {
    if (!node) return null;
    return node.closest('header,.ks-header-ui') || node;
  }

  function isBefore(a, b) {
    if (!a || !b || a === b) return false;
    return !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING);
  }

  function isHeaderCandidate(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.closest('.modal,.offcanvas,footer')) return false;
    return !!(node.matches('header.tf-header,header.ks-header-ui,header[data-ks-header],[data-ks-header]'));
  }

  function scoreHeader(node) {
    if (!isHeaderCandidate(node)) return -1000;
    var score = 0;
    if (node.matches('header')) score += 20;
    if (node.matches('.ks-header-ui')) score += 20;
    if (node.hasAttribute('data-ks-header')) score += 20;
    if (q('.logo-site', node)) score += 15;
    if (q('.inner-header', node)) score += 15;
    if (q('.header-bottom', node)) score += 10;
    if (q('.ks-search-shell,.form-search-product', node)) score += 10;
    if (q('.nav-icon,.nav-shop-cart', node)) score += 5;
    return score;
  }

  function pickPrimaryHeader(headers) {
    var best = null, bestScore = -1000;
    (headers || []).forEach(function (node) {
      var score = scoreHeader(node);
      if (score > bestScore) { best = node; bestScore = score; }
    });
    return bestScore > 0 ? best : null;
  }

  function restoreNode(node) {
    if (!node || node.nodeType !== 1) return;
    node.removeAttribute('data-ks-hidden-reason');
    node.removeAttribute('data-ks-duplicate-chrome');
    node.removeAttribute('hidden');
    node.style.removeProperty('display');
    node.style.removeProperty('visibility');
    node.style.removeProperty('opacity');
    node.style.removeProperty('pointer-events');
    node.style.removeProperty('height');
    node.style.removeProperty('min-height');
    node.style.removeProperty('max-height');
    node.style.removeProperty('margin');
    node.style.removeProperty('padding');
    node.style.removeProperty('overflow');
  }

  function ensurePrimaryChromeOrder() {
    var wrapper = q('#wrapper');
    var main = null;
    if (wrapper) {
      for (var i = 0; i < wrapper.children.length; i++) {
        if ((wrapper.children[i].tagName || '').toLowerCase() === 'main') { main = wrapper.children[i]; break; }
      }
    }
    if (!main) main = q('main');
    if (!wrapper || !main) return;

    var headers = qa('header.tf-header,header.ks-header-ui,header[data-ks-header],[data-ks-header]').filter(isHeaderCandidate);
    var primary = pickPrimaryHeader(headers);
    if (!primary) return;

    if (primary.parentNode !== wrapper || !isBefore(primary, main)) {
      wrapper.insertBefore(primary, main);
    }
    primary.setAttribute('data-ks-primary-chrome', '1');
    restoreNode(primary);

    headers.forEach(function (node) {
      if (!node || node === primary || primary.contains(node)) return;
      node.setAttribute('data-ks-duplicate-chrome', '1');
      hide(chromeRoot(node), 'chrome-duplicate');
    });

    qa('.tf-topbar,.inner-header,.header-bottom,.main-nav-menu').forEach(function (node) {
      if (!node || primary.contains(node) || node.closest('footer,.modal,.offcanvas')) return;
      var root = chromeRoot(node);
      if (root && root !== primary) {
        root.setAttribute('data-ks-duplicate-chrome', '1');
        hide(root, 'chrome-fragment');
      }
    });

    var footer = q('footer.tf-footer', wrapper) || q('footer.tf-footer');
    if (footer && footer.parentNode !== wrapper) {
      wrapper.appendChild(footer);
    }
    if (footer && isBefore(footer, main)) {
      wrapper.appendChild(footer);
    }
  }

  function hideChromeAfterFooter() {
    var footer = q('footer.tf-footer');
    if (!footer) return;
    qa('header,.ks-header-ui,.tf-topbar,.inner-header,.header-bottom,.main-nav-menu').forEach(function (node) {
      if (!node || footer.contains(node) || node.getAttribute('data-ks-primary-chrome') === '1') return;
      var relation = footer.compareDocumentPosition(node);
      if (relation & Node.DOCUMENT_POSITION_FOLLOWING) {
        var root = chromeRoot(node);
        if (root) root.setAttribute('data-ks-duplicate-chrome', '1');
        hide(root, 'chrome-after-footer');
      }
    });
  }

  function normalizeImages() {
    qa('.ks-grid-card img,.ks-row-card img,.ks-big-card img,.ks-deal-card img,.card-product img').forEach(function (img) {
      img.setAttribute('loading', 'lazy');
      img.setAttribute('decoding', 'async');
    });
  }

  function stabilize() {
    if (!isHome()) return;
    ensurePrimaryChromeOrder();
    hideChromeAfterFooter();
    forceHeroLayout();
    normalizeCommercialSections();
    updateAllSwipers();
  }

  function boot() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home', 'ks-home-server-rendered');
    initHeroSwiper();
    initBrandSlider();
    initColumnSwipers();
    normalizeImages();
    stabilize();
    [80, 180, 420, 900, 1800, 3600].forEach(function (delay) { window.setTimeout(stabilize, delay); });
    try {
      var observer = new MutationObserver(function () { window.clearTimeout(observer._ksTimer); observer._ksTimer = window.setTimeout(stabilize, 80); });
      observer.observe(document.body, { childList: true, subtree: true });
    } catch (err) {}
    window.addEventListener('resize', function () { window.setTimeout(stabilize, 120); });
  }

  onReady(boot);
})();
