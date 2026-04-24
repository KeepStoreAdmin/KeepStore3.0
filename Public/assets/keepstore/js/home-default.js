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

  function removeHardHide(node) {
    if (!node || node.nodeType !== 1) return;
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
    node.removeAttribute('data-ks-hidden');
    node.removeAttribute('data-ks-hidden-reason');
    node.removeAttribute('data-ks-empty-section');
    node.removeAttribute('data-ks-commercial-empty');
    ['display','visibility','opacity','pointer-events','height','min-height','max-height','margin','padding','overflow'].forEach(function (prop) {
      node.style.removeProperty(prop);
    });
  }

  function hide(node, reason) {
    if (!node || node.nodeType !== 1) return;
    node.setAttribute('data-ks-hidden-reason', reason || 'hidden');
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

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    try { return new Swiper(root, options); } catch (err) { return null; }
  }

  function updateAllSwipers() {
    qa('.swiper').forEach(function (el) {
      if (el.swiper && typeof el.swiper.update === 'function') {
        try { el.swiper.update(); } catch (err) {}
      }
    });
  }

  function countArticleLinks(root) {
    var seen = {};
    qa('a[href*="articolo.aspx?id="]', root).forEach(function (a) {
      var href = a.getAttribute('href') || '';
      var match = href.match(/[?&]id=(\d+)/i);
      seen[match ? match[1] : href] = 1;
    });
    return Object.keys(seen).length;
  }

  function hasProductImage(root) {
    return qa('img[src],img[data-src]', root).some(function (img) {
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      return src && !/logo|brand|pagamenti|payment|mail\.svg|headphone|spinner|favicon/i.test(src);
    });
  }

  function initHeroSwiper() {
    var hero = q('.ks-home-hero-slider');
    if (!hero) return;
    var slides = qa('.swiper-slide', hero).filter(function (slide) { return !!q('img[src],img[data-src]', slide); });
    var loop = slides.length > 1;
    buildSwiper(hero, {
      loop: loop,
      effect: 'slide',
      speed: 700,
      autoplay: loop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false,
      pagination: { el: q('.ks-hero-pagination', hero), clickable: true },
      navigation: { nextEl: q('.ks-hero-next', hero), prevEl: q('.ks-hero-prev', hero) }
    });
    if (!loop) {
      ['.ks-hero-prev','.ks-hero-next','.ks-hero-pagination'].forEach(function (selector) {
        var node = q(selector, hero);
        if (node) node.style.setProperty('display', 'none', 'important');
      });
    }
  }

  function initProductSwipers() {
    qa('.tf-sw-products').forEach(function (el) {
      if (!el || el.closest('#HomeHeroSection') || el.swiper || !q('.swiper-slide', el)) return;
      var slides = qa('.swiper-slide', el).length;
      var preview = parseInt(el.getAttribute('data-preview') || '5', 10) || 5;
      var tablet = parseInt(el.getAttribute('data-tablet') || '4', 10) || 4;
      var mobileSm = parseInt(el.getAttribute('data-mobile-sm') || '2', 10) || 2;
      var mobile = parseInt(el.getAttribute('data-mobile') || '1', 10) || 1;
      var space = parseInt(el.getAttribute('data-space') || '15', 10) || 15;
      var spaceMd = parseInt(el.getAttribute('data-space-md') || String(space), 10) || space;
      var spaceLg = parseInt(el.getAttribute('data-space-lg') || String(spaceMd), 10) || spaceMd;
      buildSwiper(el, {
        loop: false,
        slidesPerView: mobile,
        spaceBetween: space,
        pagination: { el: q('.sw-pagination-products', el), clickable: true },
        navigation: {
          nextEl: q('.nav-next-products', el.closest('section') || document),
          prevEl: q('.nav-prev-products', el.closest('section') || document)
        },
        breakpoints: {
          576: { slidesPerView: mobileSm, spaceBetween: space },
          768: { slidesPerView: tablet, spaceBetween: spaceMd },
          1200: { slidesPerView: preview, spaceBetween: spaceLg }
        }
      });
      if (slides <= preview) {
        var sec = el.closest('section');
        qa('.nav-prev-products,.nav-next-products,.sw-pagination-products', sec || el).forEach(function (n) { n.style.setProperty('display', 'none', 'important'); });
      }
    });
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
        loop: false,
        slidesPerView: 1,
        spaceBetween: 20,
        pagination: { el: q('.ks-col-pagination', el), clickable: true },
        navigation: { nextEl: block ? q('.ks-col-next', block) : null, prevEl: block ? q('.ks-col-prev', block) : null }
      });
      if (slides <= 1) qa('.ks-col-prev,.ks-col-next,.ks-col-pagination', block || el).forEach(function (n) { n.style.setProperty('display', 'none', 'important'); });
    });
  }

  function forceHeroLayout() {
    var section = q('#HomeHeroSection') || q('.ks-home-hero-section');
    if (!section) return;
    var shell = q('.ks-home-hero-shell,.s-banner-wrapper', section);
    var sliderWrap = q('#HeroSliderWrap,.wrap-item-2', section);
    var hero = q('.ks-home-hero-slider', section);
    var img = q('.ks-home-hero-slider img[src],.ks-home-hero-slider img[data-src]', section);
    var menuList = q('.ks-home-departments .menu-category-list', section);
    if (!hero || !sliderWrap || !img) { hide(section, 'hero-without-image'); return; }

    removeHardHide(section); removeHardHide(sliderWrap); removeHardHide(hero);
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
      node.style.setProperty('background-color', '#000', 'important');
    });
    qa('.ks-home-hero-slider img', section).forEach(function (image) {
      image.style.setProperty('display', 'block', 'important');
      image.style.setProperty('width', '100%', 'important');
      image.style.setProperty('height', heroHeight + 'px', 'important');
      image.style.setProperty('max-width', 'none', 'important');
      image.style.setProperty('object-fit', 'contain', 'important');
      image.style.setProperty('object-position', 'center center', 'important');
      image.style.setProperty('background-color', '#000', 'important');
    });
    if (menuList && window.innerWidth >= 1200) {
      menuList.style.setProperty('min-height', heroHeight + 'px', 'important');
      menuList.style.setProperty('max-height', heroHeight + 'px', 'important');
    }
  }

  function isHeaderCandidate(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.closest('.modal,.offcanvas,footer')) return false;
    return !!node.matches('header.tf-header,header.ks-header-ui,header[data-ks-header],[data-ks-header]');
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
    return score;
  }

  function ensureChromeOrder() {
    var wrapper = q('#wrapper');
    var main = wrapper ? q('main', wrapper) : q('main');
    if (!wrapper || !main) return;
    var headers = qa('header.tf-header,header.ks-header-ui,header[data-ks-header],[data-ks-header]').filter(isHeaderCandidate);
    var primary = null;
    var best = -1000;
    headers.forEach(function (h) { var s = scoreHeader(h); if (s > best) { primary = h; best = s; } });
    if (primary && best > 0) {
      if (primary.parentNode !== wrapper || primary.nextElementSibling !== main) wrapper.insertBefore(primary, main);
      primary.setAttribute('data-ks-primary-chrome', '1');
      removeHardHide(primary);
      headers.forEach(function (h) {
        if (!h || h === primary || primary.contains(h)) return;
        h.setAttribute('data-ks-duplicate-chrome', '1');
        hide(h.closest('header,.ks-header-ui') || h, 'chrome-duplicate');
      });
    }
    var footer = q('footer.tf-footer', wrapper) || q('footer.tf-footer');
    if (footer && footer.parentNode !== wrapper) wrapper.appendChild(footer);
    if (footer && footer.compareDocumentPosition(main) & Node.DOCUMENT_POSITION_FOLLOWING) wrapper.appendChild(footer);
  }

  function isCommercialCandidate(section) {
    if (!section || section.nodeType !== 1) return false;
    if (section.id === 'HomeHeroSection' || section.id === 'HomeBrandsSection') return false;
    if (section.closest('header,footer,.modal,.offcanvas')) return false;
    if (section.matches('.ks-home-hero-section,.ks-home-brands-block')) return false;
    if (section.matches('.flat-animate-tab,#HomeRecentlyViewedSection,#HomeLowerColumnsSection')) return true;
    if (section.matches('.tf-sp-2,.tf-sp-3,.tf-sp-4,.tf-sp-5')) {
      var t = textOf(section).toLowerCase();
      return /best seller|occasione|offerte|evidenza|venduti|scelti|top 20|nuovi arrivi/.test(t) || countArticleLinks(section) > 0;
    }
    return false;
  }

  function closestProductRoot(link) {
    if (!link || !link.closest) return null;
    return link.closest('.card-product,.ks-grid-card,.ks-row-card,.ks-deal-card,.box-product,.product-card,.swiper-slide,li') || link.parentElement;
  }

  function isValidProductCardRoot(root) {
    if (!root || root.nodeType !== 1) return false;
    if (root.closest('header,footer,.modal,.offcanvas,#HomeBrandsSection')) return false;
    var link = q('a[href*="articolo.aspx?id="]', root);
    if (!link && root.matches && root.matches('a[href*="articolo.aspx?id="]')) link = root;
    if (!link) return false;
    var image = qa('img[src],img[data-src]', root).filter(function (img) {
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      return src && !/logo|brand|pagamenti|payment|mail\.svg|headphone|spinner|favicon|blank|spacer/i.test(src);
    })[0];
    if (!image) return false;
    var title = textOf(q('.product-title,.name-product,.title,.card-product-info a,h6 a,h5 a', root) || link);
    if (title.length < 6) return false;
    return true;
  }

  function validProductCardCount(root) {
    var seen = {};
    var count = 0;
    qa('a[href*="articolo.aspx?id="]', root).forEach(function (link) {
      var href = link.getAttribute('href') || '';
      var match = href.match(/[?&]id=(\d+)/i);
      var key = match ? match[1] : href;
      if (!key || seen[key]) return;
      var productRoot = closestProductRoot(link);
      if (!isValidProductCardRoot(productRoot)) return;
      seen[key] = 1;
      count += 1;
    });
    return count;
  }

  function commercialMinimum(section) {
    if (!section) return 1;
    if (section.id === 'HomeRecentlyViewedSection') return 2;
    if (section.id === 'HomeLowerColumnsSection') return 3;
    if (section.matches && section.matches('.flat-animate-tab')) return 3;
    var label = textOf(section).toLowerCase();
    if (/best seller/.test(label)) return 3;
    if (/occasione/.test(label)) return 2;
    if (/top 20|venduti|offerta|evidenza|scelti/.test(label)) return 3;
    return 1;
  }

  function setProductImagesSafe(root) {
    qa('img', root).forEach(function (img) {
      img.setAttribute('loading', 'lazy');
      img.setAttribute('decoding', 'async');
      img.style.removeProperty('display');
      img.style.removeProperty('visibility');
      img.style.removeProperty('opacity');
    });
  }

  function showCommercial(section, validCount) {
    section.setAttribute('data-ks-has-products', '1');
    section.setAttribute('data-ks-valid-products', String(validCount || validProductCardCount(section)));
    section.removeAttribute('data-ks-commercial-empty');
    removeHardHide(section);
    setProductImagesSafe(section);
  }

  function hideCommercial(section, reason) {
    section.setAttribute('data-ks-commercial-empty', '1');
    section.removeAttribute('data-ks-has-products');
    hide(section, reason || 'commercial-empty');
  }

  function normalizeTabbedSection(section) {
    var valid = validProductCardCount(section);
    if (valid < commercialMinimum(section)) {
      hideCommercial(section, 'tabs-under-threshold');
      return false;
    }
    showCommercial(section, valid);
    return true;
  }

  function normalizeLowerColumns(section) {
    var visibleBlocks = 0;
    qa('.tf-grid-product-item,.box-btn-slide-item', section).forEach(function (block) {
      var valid = validProductCardCount(block);
      if (valid < 3) {
        hide(block, 'lower-block-under-threshold');
        block.removeAttribute('data-ks-has-products');
      } else {
        block.setAttribute('data-ks-has-products', '1');
        block.setAttribute('data-ks-valid-products', String(valid));
        removeHardHide(block);
        setProductImagesSafe(block);
        visibleBlocks += 1;
      }
    });
    section.setAttribute('data-ks-visible-blocks', String(visibleBlocks));
    if (visibleBlocks < 1) {
      hideCommercial(section, 'lower-empty');
      return false;
    }
    showCommercial(section, validProductCardCount(section));
    return true;
  }

  function restoreCommercialSections() {
    if (document.body) {
      document.body.classList.remove('ks-home-runtime-mounted', 'ks-home-v6-mounted');
      document.body.classList.add('ks-home-server-rendered');
    }
    qa('main section').forEach(function (section) {
      if (!isCommercialCandidate(section)) return;
      if (section.matches('.flat-animate-tab')) {
        normalizeTabbedSection(section);
        return;
      }
      if (section.id === 'HomeLowerColumnsSection') {
        normalizeLowerColumns(section);
        return;
      }
      var valid = validProductCardCount(section);
      var minimum = commercialMinimum(section);
      if (valid >= minimum) {
        showCommercial(section, valid);
      } else {
        hideCommercial(section, 'commercial-under-threshold');
      }
    });
  }

  function compactBeforeBrands() {
    var brand = q('#HomeBrandsSection');
    if (!brand) return;
    var previous = brand.previousElementSibling;
    while (previous && previous.nodeType === 1) {
      if (previous.id === 'HomeHeroSection') break;
      if (previous.getAttribute('data-ks-has-products') === '1') break;
      if (isCommercialCandidate(previous) && countArticleLinks(previous) === 0 && !hasProductImage(previous)) {
        hide(previous, 'commercial-empty-before-brand');
      }
      previous = previous.previousElementSibling;
    }
  }

  function finalPruneMalformedCommercialGroups() {
    if (!isHome()) return;
    qa('.flat-animate-tab').forEach(function (section) {
      if (!section || section.closest('header,footer,.modal,.offcanvas')) return;
      section.setAttribute('data-ks-pruned-commercial', '1');
      hide(section, 'tabbed-group-disabled');
    });
    qa('.tf-grid-product').forEach(function (grid) {
      if (!grid || grid.closest('header,footer,.modal,.offcanvas,#HomeBrandsSection,.ks-home-brands-block')) return;
      grid.setAttribute('data-ks-pruned-commercial', '1');
      var section = grid.closest('section,.tf-sp-2');
      if (section && !section.closest('#HomeBrandsSection,.ks-home-brands-block')) {
        section.setAttribute('data-ks-pruned-commercial', '1');
        hide(section, 'lower-commercial-disabled');
      } else {
        hide(grid, 'lower-commercial-grid-disabled');
      }
    });
  }


  function hideAfterFooterArtifacts() {
    var wrapper = q("#wrapper");
    var footer = q("footer.tf-footer", wrapper || document) || q("footer.tf-footer");
    if (!wrapper || !footer) return;
    if (footer.parentNode !== wrapper) { try { wrapper.appendChild(footer); } catch (err) {} }
    var seenFooter = false;
    Array.prototype.slice.call(wrapper.children).forEach(function (child) {
      if (child === footer) { seenFooter = true; return; }
      if (!seenFooter) return;
      if (!child || child.nodeType !== 1 || /^(script|style)$/i.test(child.tagName)) return;
      hide(child, "after-footer-artifact");
    });
    var form = q("form#form1") || q("form");
    if (form) {
      Array.prototype.slice.call(form.children).forEach(function (child) {
        if (!child || child === wrapper || child.id === "goTop" || child.id === "preload") return;
        if (/^(script|style|input|select|textarea)$/i.test(child.tagName)) return;
        if (child.matches && child.matches(".modal,.offcanvas")) return;
        if (child.compareDocumentPosition && (footer.compareDocumentPosition(child) & Node.DOCUMENT_POSITION_FOLLOWING)) hide(child, "post-wrapper-artifact");
      });
    }
  }

  function releaseHomePageHeight() {
    [document.documentElement, document.body, q("form#form1"), q("#wrapper"), q("main"), q(".ks-account-shell"), q(".ks-account-main")].forEach(function (node) {
      if (!node || !node.style) return;
      ["height","min-height","max-height","padding-bottom","margin-bottom"].forEach(function (prop) { node.style.removeProperty(prop); });
      node.style.setProperty("min-height", "0", "important");
      if (node !== document.documentElement && node !== document.body) {
        node.style.setProperty("height", "auto", "important");
        node.style.setProperty("max-height", "none", "important");
      }
    });
  }

  function compactEmptyTailBeforeFooter() {
    var wrapper = q("#wrapper");
    var footer = q("footer.tf-footer", wrapper || document);
    var main = q("main", wrapper || document);
    if (!wrapper || !footer || !main) return;
    var brand = q("#HomeBrandsSection");
    var lastMeaningful = brand || qa("main section", main).filter(function (sec) {
      return sec && sec.offsetParent !== null && sec.getAttribute("data-ks-hidden-reason") !== "commercial-under-threshold";
    }).pop();
    if (!lastMeaningful) return;
    var cursor = lastMeaningful.nextElementSibling;
    while (cursor && cursor !== footer) {
      var next = cursor.nextElementSibling;
      if (cursor.nodeType === 1 && !cursor.closest("header,footer,.modal,.offcanvas")) {
        var hasProducts = countArticleLinks(cursor) > 0 || hasProductImage(cursor);
        var txt = textOf(cursor);
        if (!hasProducts && txt.length < 20) hide(cursor, "empty-tail-spacer");
      }
      cursor = next;
    }
  }
  function stabilize() {
    if (!isHome()) return;
    ensureChromeOrder();
    forceHeroLayout();
    restoreCommercialSections();
    compactBeforeBrands();
    finalPruneMalformedCommercialGroups();
    compactEmptyTailBeforeFooter();
    hideAfterFooterArtifacts();
    releaseHomePageHeight();
    updateAllSwipers();
  }

  function boot() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home', 'ks-home-server-rendered');
    document.body.classList.remove('ks-home-runtime-mounted', 'ks-home-v6-mounted');
    initHeroSwiper();
    initProductSwipers();
    initBrandSlider();
    initColumnSwipers();
    stabilize();
    [120, 350, 900, 1800, 3600].forEach(function (delay) { window.setTimeout(stabilize, delay); });
    try {
      var observer = new MutationObserver(function () {
        window.clearTimeout(observer._ksTimer);
        observer._ksTimer = window.setTimeout(stabilize, 120);
      });
      observer.observe(document.body, { childList: true, subtree: true });
    } catch (err) {}
    window.addEventListener('resize', function () { window.setTimeout(stabilize, 120); });
  }

  onReady(boot);
})();
