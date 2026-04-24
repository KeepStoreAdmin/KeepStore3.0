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
  function runSafe(name, fn) {
    try { if (typeof fn === 'function') return fn(); } catch (err) {
      try { if (window.console && console.warn) console.warn('[KeepStore HOME]', name, err); } catch (ignore) {}
    }
    return null;
  }

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

  function normalizeDesktopCatalogMegaMenu() {
    var item = q('.ks-header-catalog-item');
    var mega = q('.ks-header-catalog-mega', item || document);
    var wrapper = q('.ks-header-catalog-wrapper', mega || document);
    if (!item || !mega || !wrapper) return;
    item.classList.add('ks-header-catalog-normalized');
    mega.classList.add('ks-header-catalog-mega-normalized');
    wrapper.classList.add('ks-header-catalog-wrapper-normalized');
    mega.removeAttribute('style');
    wrapper.removeAttribute('style');
    qa('.ks-header-catalog-column', wrapper).forEach(function (col) { col.removeAttribute('style'); });
    var link = q('a.item-link,a[href]', item);
    if (link) {
      link.setAttribute('aria-haspopup', 'true');
      link.setAttribute('aria-expanded', item.classList.contains('ks-menu-open') ? 'true' : 'false');
    }
    function open() {
      item.classList.add('ks-menu-open');
      if (link) link.setAttribute('aria-expanded', 'true');
    }
    function close() {
      item.classList.remove('ks-menu-open');
      if (link) link.setAttribute('aria-expanded', 'false');
    }
    if (!item.getAttribute('data-ks-mega-bound')) {
      item.setAttribute('data-ks-mega-bound', '1');
      item.addEventListener('mouseenter', open);
      item.addEventListener('mouseleave', close);
      item.addEventListener('focusin', open);
      item.addEventListener('focusout', function () {
        window.setTimeout(function () { if (!item.contains(document.activeElement)) close(); }, 80);
      });
      document.addEventListener('keydown', function (ev) { if (ev.key === 'Escape') close(); });
      document.addEventListener('click', function (ev) { if (!item.contains(ev.target)) close(); });
    }
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


  function collapseDormantOverlayArtifacts() {
    var form = q('form#form1') || q('form');
    if (!form) return;
    qa('.modal,.offcanvas,.modal-backdrop', form).forEach(function (node) {
      if (!node || node.classList.contains('show') || node.classList.contains('showing')) return;
      node.setAttribute('data-ks-dormant-overlay', '1');
      node.style.setProperty('display', 'none', 'important');
      node.style.setProperty('visibility', 'hidden', 'important');
      node.style.setProperty('opacity', '0', 'important');
      node.style.setProperty('pointer-events', 'none', 'important');
      node.style.setProperty('position', 'fixed', 'important');
      node.style.setProperty('width', '0', 'important');
      node.style.setProperty('height', '0', 'important');
      node.style.setProperty('min-height', '0', 'important');
      node.style.setProperty('max-height', '0', 'important');
      node.style.setProperty('margin', '0', 'important');
      node.style.setProperty('padding', '0', 'important');
      node.style.setProperty('overflow', 'hidden', 'important');
    });
    [document.documentElement, document.body].forEach(function (node) {
      if (!node || !node.style) return;
      node.style.setProperty('height', 'auto', 'important');
      node.style.setProperty('min-height', '0', 'important');
      node.style.setProperty('max-height', 'none', 'important');
    });
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

  function enforceFooterScrollClosure() {
    if (!isHome() || document.body.classList.contains('modal-open')) return;
    var footer = q('footer.tf-footer');
    if (!footer) return;
    var bottom = Math.ceil((footer.getBoundingClientRect ? footer.getBoundingClientRect().bottom : 0) + (window.pageYOffset || document.documentElement.scrollTop || 0));
    if (!bottom || bottom < 600) return;
    var finalHeight = bottom + 12;
    [document.documentElement, document.body, q('form#form1'), q('#wrapper')].forEach(function (node) {
      if (!node || !node.style) return;
      node.style.setProperty('height', finalHeight + 'px', 'important');
      node.style.setProperty('min-height', '0', 'important');
      node.style.setProperty('max-height', finalHeight + 'px', 'important');
    });
    [document.body, q('form#form1'), q('#wrapper')].forEach(function (node) {
      if (!node || !node.style) return;
      node.style.setProperty('overflow-x', 'hidden', 'important');
      node.style.setProperty('overflow-y', 'hidden', 'important');
    });
    document.documentElement.style.setProperty('overflow-x', 'hidden', 'important');
    document.documentElement.style.setProperty('overflow-y', 'auto', 'important');
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


  function normalizeHomeText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function collectDepartmentItems() {
    var seen = {}, out = [];
    function add(title, url, image) {
      title = normalizeHomeText(title);
      url = normalizeHomeText(url || '');
      image = normalizeProductImageUrl(image || '');
      if (!url || !title || title.length < 3) return;
      if (/javascript:|^#$/i.test(url)) return;
      if (!/articoli\.aspx/i.test(url) && out.length >= 8) return;
      var key = title.toLowerCase();
      if (seen[key]) return;
      seen[key] = 1;
      out.push({ title: title, url: url, image: image });
    }

    qa('.ks-home-departments .menu-item').forEach(function (item) {
      var link = q('.ks-home-menu-row a[href],a.item-link[href],a[href*="articoli.aspx"]', item);
      var titleNode = q('.ks-menu-label', item) || link;
      var img = q('.ks-menu-media img[src],.ks-menu-media img[data-src]', item);
      add(titleNode ? titleNode.textContent : '', link ? link.getAttribute('href') : '', img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '') : '');
    });

    qa('#ksDesktopCategoryMenu .ks-header-catalog-column,.ks-mobile-catalog-list .ks-mobile-sector-item').forEach(function (item) {
      var link = q('a[href*="articoli.aspx"]', item);
      var titleNode = q('.ks-header-catalog-sector-link span:last-child,.ks-mobile-nav-label', item) || link;
      var img = q('.ks-header-catalog-media img[src],.ks-mobile-nav-media img[src],img[src],img[data-src]', item);
      add(titleNode ? titleNode.textContent : '', link ? link.getAttribute('href') : '', img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '') : '');
    });

    if (out.length < 8) {
      qa('footer.tf-footer .ft-menu-list a[href],footer.tf-footer a[href*="articoli.aspx"]').forEach(function (link) {
        if (out.length >= 12) return;
        add(link.textContent || '', link.getAttribute('href') || '', '');
      });
    }

    return out.slice(0, 12);
  }

  function escHtml(value) {
    return String(value == null ? '' : value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function initialFor(value) {
    var text = normalizeHomeText(value);
    for (var i = 0; i < text.length; i++) {
      if (/[A-Za-z0-9À-ÿ]/.test(text.charAt(i))) return text.charAt(i).toUpperCase();
    }
    return '•';
  }

  function findInsertAfterIconBoxes() {
    var boxes = q('.tf-icon-box');
    if (!boxes) return q('#HomeHeroSection') || q('main');
    return boxes.closest('section,.tf-sp-2,.tf-sp-3,.tf-sp-4,.tf-sp-5') || boxes.closest('.container') || q('#HomeHeroSection') || q('main');
  }

  function buildDepartmentShowcase() {
    if (!isHome()) return;
    var existing = q('#KsHomeDepartmentShowcase');
    if (existing) { removeHardHide(existing); return; }
    var items = collectDepartmentItems();
    if (items.length < 3) return;
    var section = document.createElement('section');
    section.id = 'KsHomeDepartmentShowcase';
    section.className = 'tf-sp-2 ks-home-department-showcase';
    section.setAttribute('data-ks-generated', 'catalog-showcase');
    section.innerHTML = '<div class="container">' +
      '<div class="flat-title ks-home-section-title"><div><p class="caption text-primary fw-semibold">Catalogo KeepStore</p><h5 class="fw-semibold">Reparti in evidenza</h5></div><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div>' +
      '<div class="ks-home-department-grid">' +
      items.map(function (item) {
        var media = item.image ? '<span class="ks-home-department-media"><img src="' + escHtml(item.image) + '" alt="' + escHtml(item.title) + '" loading="lazy" decoding="async" onerror="this.style.display=\'none\';this.parentNode.classList.add(\'is-empty\');var b=document.createElement(\'b\');b.textContent=\'' + escHtml(initialFor(item.title)) + '\';this.parentNode.appendChild(b);" /></span>' : '<span class="ks-home-department-media is-empty"><b>' + escHtml(initialFor(item.title)) + '</b></span>';
        return '<a class="ks-home-department-card" href="' + escHtml(item.url) + '">' + media + '<span class="ks-home-department-title">' + escHtml(item.title) + '</span><span class="ks-home-department-cta">Scopri</span></a>';
      }).join('') +
      '</div></div>';
    var bridge = q('#KsHomeOnsusBridge');
    if (bridge && bridge.parentNode) bridge.parentNode.insertBefore(section, bridge);
    else insertAfterIconBoxesSection(section);
    if (document.body) document.body.classList.add('ks-department-showcase-mounted');
  }


  function isBadProductImageUrl(src) {
    src = String(src || '').trim();
    if (!src) return true;
    if (/logo|brand|pagamenti|payment|mail\.svg|headphone|spinner|favicon|blank|spacer|pixel|loading/i.test(src)) return true;
    if (/^data:/i.test(src) && !/^data:image\/(png|jpe?g|webp|gif);base64,/i.test(src)) return true;
    return false;
  }

  function normalizeProductImageUrl(src) {
    src = String(src || '').trim().replace(/\\/g, '/');
    if (!src || isBadProductImageUrl(src)) return '';
    if (/^(https?:)?\/\//i.test(src) || /^data:/i.test(src) || src.charAt(0) === '/') return src;
    if (src.indexOf('~/') === 0) return '/' + src.substring(2);
    if (/^(Public|public|images|upload|uploads|foto|articoli)\//.test(src)) return '/' + src.replace(/^\/+/, '');
    return src;
  }

  function addImageCandidate(out, seen, src) {
    var normalized = normalizeProductImageUrl(src);
    if (!normalized || seen[normalized]) return;
    seen[normalized] = 1;
    out.push(normalized);
    var qIndex = normalized.indexOf('?');
    var noQuery = qIndex >= 0 ? normalized.substring(0, qIndex) : normalized;
    var suffix = qIndex >= 0 ? normalized.substring(qIndex) : '';
    var unPreview = noQuery.replace(/_\.(webp|jpe?g|png|gif)$/i, '.$1') + suffix;
    if (unPreview !== normalized && !seen[unPreview] && !isBadProductImageUrl(unPreview)) {
      seen[unPreview] = 1;
      out.push(unPreview);
    }
  }

  function imageCandidatesFrom(img) {
    var out = [], seen = {};
    if (!img) return out;
    addImageCandidate(out, seen, img.currentSrc || '');
    addImageCandidate(out, seen, img.getAttribute('src') || '');
    addImageCandidate(out, seen, img.getAttribute('data-src') || '');
    addImageCandidate(out, seen, img.getAttribute('data-original') || '');
    addImageCandidate(out, seen, img.getAttribute('data-lazy-src') || '');
    addImageCandidate(out, seen, img.getAttribute('data-ks-src') || '');
    addImageCandidate(out, seen, img.getAttribute('data-preview') || '');
    [img.getAttribute('srcset') || '', img.getAttribute('data-srcset') || ''].forEach(function (srcset) {
      String(srcset || '').split(',').forEach(function (entry) { addImageCandidate(out, seen, entry.trim().split(/\s+/)[0] || ''); });
    });
    return out;
  }

  function productDataFromCard(root) {
    if (!root || root.nodeType !== 1) return null;
    var link = q('a[href*="articolo.aspx?id="]', root) || (root.matches && root.matches('a[href*="articolo.aspx?id="]') ? root : null);
    if (!link) return null;
    var imageCandidates = [];
    qa('img[src],img[data-src],img[srcset],img[data-srcset]', root).some(function (candidate) {
      imageCandidates = imageCandidatesFrom(candidate);
      return imageCandidates.length > 0;
    });
    if (!imageCandidates.length) return null;
    var titleNode = q('.product-title,.name-product,.title,.card-product-info a,h6 a,h5 a', root) || link;
    var title = normalizeHomeText(titleNode.textContent || link.textContent || '');
    if (title.length < 6) return null;
    var priceNode = q('.new-price,.price-text,.price,.new,.card-product-info .price-new,.product-price,.text-primary', root);
    var oldNode = q('.old-price,.old,.price-old', root);
    var metaNode = q('.category,.caption,.ksh-meta,.card-product-info .caption', root);
    return { id: productIdFromUrl(link.getAttribute('href') || ''), url: link.getAttribute('href') || '#', image: imageCandidates[0], imageCandidates: imageCandidates, title: title, price: normalizeHomeText(priceNode ? priceNode.textContent : ''), oldPrice: normalizeHomeText(oldNode ? oldNode.textContent : ''), meta: normalizeHomeText(metaNode ? metaNode.textContent : '') };
  }

  function productSourceSectionTitle(node) {
    var section = node && node.closest ? node.closest('section,.tf-sp-1,.tf-sp-2,.tf-sp-3,.tf-sp-4,.tf-sp-5,.flat-spacing') : null;
    if (!section) return '';
    var titleNode = q('h1,h2,h3,h4,h5,.flat-title,.heading-section,.title-sidebar,.main-title', section);
    return normalizeHomeText(titleNode ? titleNode.textContent : section.getAttribute('aria-label') || '');
  }

  function productBridgeFamilyKey(data) {
    var title = normalizeHomeText(data && data.title || '').toLowerCase();
    var compactTitle = title.replace(/[^a-z0-9àèéìòù]+/g, ' ').replace(/\s+/g, ' ').trim();
    if (/\b(custodia|cover|case)\b/.test(compactTitle)) return 'accessori-custodia';
    if (/\b(pellicola|vetro|glass|protezione|temperato|screen|schermo)\b/.test(compactTitle)) return 'accessori-protezione-schermo';
    if (/\b(stampante|printer)\b/.test(compactTitle)) return 'stampanti';
    if (/\b(adattatore|adapter|cavo|cable)\b/.test(compactTitle)) {
      if (/\b(usb|type c|typec|lightning)\b/.test(compactTitle)) return 'cavi-adattatori-usb';
      if (/\b(hdmi|vga|displayport|dp)\b/.test(compactTitle)) return 'cavi-video';
      return 'cavi-adattatori';
    }
    var key = editorialFamilyKey({ title: data && data.title || '', brand: data && data.meta || '', category: data && data.meta || '' });
    if (key) return key;
    return compactTitle;
  }

  function collectVisibleProductData(limit) {
    var wanted = Math.max(0, limit || 16);
    var seenId = {}, seenUrl = {}, seenFamily = {}, primary = [], fallback = [];
    qa('main .card-product,main .ks-grid-card,main .ks-row-card,main .swiper-slide,main li,main a[href*="articolo.aspx?id="]').forEach(function (node) {
      if (!node || node.closest('header,footer,.modal,.offcanvas,#HomeBrandsSection,.ks-home-brands-block,.ks-onsus-bridge,#KsHomeOnsusBridge')) return;
      var data = productDataFromCard(node);
      if (!data) return;
      var id = parseInt(data.id, 10) || productIdFromUrl(data.url || '');
      var urlKey = normalizeHomeText(data.url || '').toLowerCase();
      var familyKey = productBridgeFamilyKey(data);
      if (id > 0 && seenId[id]) return;
      if (urlKey && seenUrl[urlKey]) return;
      if (familyKey && seenFamily[familyKey]) return;
      if (id > 0) seenId[id] = 1;
      if (urlKey) seenUrl[urlKey] = 1;
      if (familyKey) seenFamily[familyKey] = 1;
      data.sourceTitle = productSourceSectionTitle(node);
      if (/best\s*seller|rivenditori|brand/i.test(data.sourceTitle || '')) fallback.push(data);
      else primary.push(data);
    });
    var primaryMinimum = Math.min(12, wanted);
    if (primary.length >= primaryMinimum) {
      return primary.slice(0, wanted);
    }
    return primary.concat(fallback.slice(0, Math.max(0, primaryMinimum - primary.length))).slice(0, wanted);
  }

  function bridgePriceHtml(item) {
    var p = normalizeHomeText(item && item.price || '').replace(/\s*€\s*$/, '');
    var o = normalizeHomeText(item && item.oldPrice || '').replace(/\s*€\s*$/, '');
    if (!p && !o) return '';
    return '<span class="ks-onsus-price">' + (p ? '<b>' + escHtml(p) + (p.indexOf('€') >= 0 ? '' : ' €') + '</b>' : '') + (o ? '<del>' + escHtml(o) + (o.indexOf('€') >= 0 ? '' : ' €') + '</del>' : '') + '</span>';
  }

  function bridgeImgHtml(item) {
    var candidates = (item && item.imageCandidates || []).filter(function (src) { return !isBadProductImageUrl(src); });
    if (!candidates.length && item && item.image) candidates = [item.image];
    var primary = candidates[0] || '';
    var fallbacks = candidates.join('||');
    return '<img src="' + escHtml(primary) + '" data-ks-img-fallbacks="' + escHtml(fallbacks) + '" data-ks-img-index="0" alt="' + escHtml(item && item.title || '') + '" loading="lazy" decoding="async">';
  }

  function bridgeSmallCard(item) {
    return '<a class="ks-onsus-side-card" href="' + escHtml(item.url || '#') + '"><span class="ks-onsus-side-media">' + bridgeImgHtml(item) + '</span><span class="ks-onsus-side-body"><span class="ks-onsus-meta">' + escHtml(item.meta || 'Prodotto') + '</span><span class="ks-onsus-title">' + escHtml(item.title || '') + '</span>' + bridgePriceHtml(item) + '</span></a>';
  }

  function bridgeGridCard(item) {
    return '<a class="ks-onsus-grid-card" href="' + escHtml(item.url || '#') + '"><span class="ks-onsus-grid-media">' + bridgeImgHtml(item) + '</span><span class="ks-onsus-meta">' + escHtml(item.meta || 'Prodotto') + '</span><span class="ks-onsus-title">' + escHtml(item.title || '') + '</span>' + bridgePriceHtml(item) + '</a>';
  }

  function bindGeneratedImageFallbacks(root) {
    qa('img[data-ks-img-fallbacks]', root || document).forEach(function (img) {
      if (img.getAttribute('data-ks-fallback-bound') === '1') return;
      img.setAttribute('data-ks-fallback-bound', '1');
      img.addEventListener('error', function () {
        var list = String(img.getAttribute('data-ks-img-fallbacks') || '').split('||').filter(Boolean);
        var idx = parseInt(img.getAttribute('data-ks-img-index') || '0', 10) || 0;
        while (idx + 1 < list.length) {
          idx += 1;
          var next = list[idx];
          if (next && next !== img.getAttribute('src')) {
            img.setAttribute('data-ks-img-index', String(idx));
            img.setAttribute('src', next);
            return;
          }
        }
        var card = img.closest ? img.closest('.ks-onsus-grid-card,.ks-onsus-side-card,.ks-feed-card') : null;
        if (card) card.classList.add('ks-image-missing');
      });
      if (img.complete && img.naturalWidth === 0) {
        try { img.dispatchEvent(new Event('error')); } catch (err) {}
      }
    });
  }

  function mountOnsusBridgeFromServerProducts() {
    if (!isHome() || q('#KsHomeOnsusBridge')) return;
    var items = collectVisibleProductData(28);
    if (items.length < 5) return;
    var section = document.createElement('section');
    section.id = 'KsHomeOnsusBridge';
    section.className = 'tf-sp-2 ks-onsus-bridge';
    section.setAttribute('data-ks-generated', 'server-products-onsus-bridge');
    var left = items.slice(0, 2).map(bridgeSmallCard).join('');
    var center = bridgeGridCard(items[2]);
    var right = items.slice(3, 5).map(bridgeSmallCard).join('');
    var lower = items.slice(5, 15).map(bridgeGridCard).join('');
    var extra = items.slice(15, 25).map(bridgeGridCard).join('');
    section.innerHTML = '<div class="container"><div class="flat-title ks-home-section-title"><div class="flat-title-tab-default"><ul class="menu-tab-line"><li class="nav-tab-item d-flex"><span class="tab-link main-title link fw-semibold active">In Evidenza</span></li><li class="nav-tab-item d-flex"><span class="tab-link main-title link fw-semibold">Top prodotti</span></li><li class="nav-tab-item d-flex"><span class="tab-link main-title link fw-semibold">Scelti Da Te</span></li></ul></div><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div><div class="ks-onsus-feature-grid"><div class="ks-onsus-side-col">' + left + '</div><div class="ks-onsus-center">' + center + '</div><div class="ks-onsus-side-col">' + right + '</div></div>' + (lower ? '<div class="ks-onsus-product-strip">' + lower + '</div>' : '') + (extra ? '<div class="ks-onsus-extra-grid">' + extra + '</div>' : '') + '</div>';
    var best = qa('main section').filter(function (sec) { return sec && /best seller/i.test(textOf(sec)) && validProductCardCount(sec) >= 3; })[0];
    if (best && best.parentNode) best.parentNode.insertBefore(section, best);
    else insertAfterIconBoxesSection(section);
    bindGeneratedImageFallbacks(section);
    pruneDuplicateBridgeCards(section);
    pruneBridgeAgainstBestSeller();
    normalizeOnsusBridgeDensity();
    if (document.body) document.body.classList.add('ks-onsus-bridge-mounted', 'ks-onsus-bridge-deduped', 'ks-onsus-cross-deduped');
  }

  function pruneDuplicateBridgeCards(root) {
    var seenUrl = {}, seenTitle = {};
    qa('.ks-onsus-grid-card,.ks-onsus-side-card', root || document).forEach(function (card) {
      var href = normalizeHomeText(card.getAttribute('href') || '').toLowerCase();
      var titleNode = q('.ks-onsus-title', card);
      var family = normalizeHomeText(titleNode ? titleNode.textContent : card.textContent).toLowerCase()
        .replace(/\b(nero|bianco|rosso|blu|verde|giallo|rosa|oro|argento|grigio|black|white|red|blue|green|yellow|pink|gold|silver|grey|gray|case|cover|custodia|vetro|glass|temperato|tempered|protezione|protector|clear|trasparente|mm|cm|gb|tb|xl|xxl|per|con|the|for)\b/g, ' ')
        .replace(/\b\d+[a-z]*\b/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
      if ((href && seenUrl[href]) || (family && seenTitle[family])) {
        card.classList.add('ks-onsus-duplicate-removed');
        card.setAttribute('hidden', 'hidden');
        card.style.display = 'none';
        return;
      }
      if (href) seenUrl[href] = 1;
      if (family) seenTitle[family] = 1;
    });
  }


  var ksFeedMounted = false;
  var ksFeedInFlight = false;

  function productIdFromUrl(url) {
    var m = String(url || '').match(/[?&]id=(\d+)/i);
    return m ? parseInt(m[1], 10) || 0 : 0;
  }

  function visibleProductIds() {
    var seen = {};
    qa('main a[href*="articolo.aspx?id="]').forEach(function (a) {
      var id = productIdFromUrl(a.getAttribute('href') || '');
      if (id > 0) seen[id] = 1;
    });
    return seen;
  }

  function itemKeyText(item) {
    return normalizeHomeText([item && item.brand, item && item.title, item && item.category].join(' '));
  }

  function editorialFamilyKey(item) {
    var blocked = {'nero':1,'bianco':1,'rosso':1,'blu':1,'verde':1,'giallo':1,'rosa':1,'oro':1,'argento':1,'grigio':1,'black':1,'white':1,'red':1,'blue':1,'green':1,'yellow':1,'pink':1,'gold':1,'silver':1,'grey':1,'gray':1,'case':1,'cover':1,'custodia':1,'vetro':1,'glass':1,'temperato':1,'tempered':1,'protezione':1,'protector':1,'clear':1,'trasparente':1,'mm':1,'cm':1,'gb':1,'tb':1,'xl':1,'xxl':1,'per':1,'con':1,'the':1,'for':1};
    return itemKeyText(item).split(' ').filter(function (token) {
      if (!token || blocked[token]) return false;
      if (/^\d+$/.test(token)) return false;
      if (/^\d+(mm|cm|gb|tb|m|w|v)$/i.test(token)) return false;
      return true;
    }).slice(0, 8).join(' ');
  }

  function dedupeFeedItems(list, excludeIds, limit) {
    var out = [], seenId = {}, seenFamily = {};
    (list || []).forEach(function (item) {
      if (!item) return;
      var id = parseInt(item.id, 10) || productIdFromUrl(item.url);
      if (!id || (excludeIds && excludeIds[id]) || seenId[id]) return;
      var title = normalizeHomeText(item.title || '');
      var image = item.preview || item.image || (item.images && item.images[0]) || '';
      if (!title || !image) return;
      var family = editorialFamilyKey(item);
      if (family && seenFamily[family]) return;
      seenId[id] = 1;
      if (family) seenFamily[family] = 1;
      out.push(item);
    });
    return out.slice(0, Math.max(0, limit || 0));
  }

  function priceHtml(item) {
    var price = String(item && item.price || '').trim();
    var oldPrice = String(item && item.oldPrice || '').trim();
    var html = '<div class="ks-feed-price">';
    if (price) html += '<span class="new">' + escHtml(price) + ' €</span>';
    if (oldPrice) html += '<span class="old">' + escHtml(oldPrice) + ' €</span>';
    html += '</div>';
    return html;
  }

  function feedImageCandidates(item) {
    var out = [], seen = {};
    addImageCandidate(out, seen, item && item.image || '');
    addImageCandidate(out, seen, item && item.preview || '');
    (item && item.images || []).forEach(function (src) { addImageCandidate(out, seen, src); });
    return out;
  }

  function feedCard(item, variant) {
    var candidates = feedImageCandidates(item);
    var img = candidates[0] || '';
    var pct = parseInt(item.salePercent, 10) || 0;
    var badge = pct > 0 ? '<span class="ks-feed-badge">-' + pct + '%</span>' : '';
    var meta = normalizeHomeText(item.brand || item.category || '') ? '<div class="ks-feed-meta">' + escHtml(item.brand || item.category || '') + '</div>' : '';
    return '<a class="ks-feed-card ks-feed-card--' + escHtml(variant || 'grid') + '" href="' + escHtml(item.url || '#') + '">' + badge + '<span class="ks-feed-media"><img src="' + escHtml(img) + '" data-ks-img-fallbacks="' + escHtml(candidates.join('||')) + '" data-ks-img-index="0" alt="' + escHtml(item.title || '') + '" loading="lazy" decoding="async"></span><span class="ks-feed-body">' + meta + '<span class="ks-feed-title">' + escHtml(item.title || '') + '</span>' + priceHtml(item) + '</span></a>';
  }

  function mergedFeedSections(sections, keys) {
    var out = [], seen = {};
    (keys || []).forEach(function (key) {
      (sections[key] || []).forEach(function (item) {
        var id = parseInt(item && item.id, 10) || productIdFromUrl(item && item.url);
        if (!id || seen[id]) return;
        seen[id] = 1;
        out.push(item);
      });
    });
    return out;
  }

  function buildFeedBand(id, title, items, variant, minItems) {
    if (q('#' + id) || !items || items.length < (minItems || 3)) return null;
    var section = document.createElement('section');
    section.id = id;
    section.className = 'tf-sp-2 ks-home-feed-section ks-home-feed-section--' + (variant || 'grid');
    section.setAttribute('data-ks-generated', 'feed-products');
    section.innerHTML = '<div class="container"><div class="flat-title ks-home-section-title"><h5 class="fw-semibold">' + escHtml(title) + '</h5><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div><div class="ks-feed-grid">' + items.map(function (item) { return feedCard(item, variant); }).join('') + '</div></div>';
    bindGeneratedImageFallbacks(section);
    return section;
  }

  function insertBeforeBrandOrFooter(section) {
    if (!section) return;
    var brand = q('#HomeBrandsSection');
    var footer = q('footer.tf-footer');
    var anchor = brand || footer;
    if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(section, anchor);
    else (q('main') || document.body).appendChild(section);
  }

  function insertAfterIconBoxesSection(section) {
    if (!section) return;
    var anchor = findInsertAfterIconBoxes();
    if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(section, anchor.nextSibling);
    else (q('main') || document.body).appendChild(section);
  }

  function readRecentParam() {
    var raw = [];
    try { raw = raw.concat(String(sessionStorage.getItem('ks_recent_session') || '').split(',')); } catch (err) {}
    try { var m = document.cookie.match(/(?:^|; )ks_recent=([^;]*)/); if (m) raw = raw.concat(decodeURIComponent(m[1]).split(',')); } catch (err) {}
    var seen = {}, out = [];
    raw.forEach(function (token) { var id = parseInt(token, 10) || 0; if (id > 0 && !seen[id]) { seen[id] = 1; out.push(id); } });
    return out.slice(0, 100).join(',');
  }

  function mountFeedProducts(payload) {
    if (!payload || !payload.ok || ksFeedMounted) return;
    var sections = payload.sections || {};
    if (!sections || !Object.keys(sections).length) return;
    var exclude = visibleProductIds();
    var showcase = dedupeFeedItems(mergedFeedSections(sections, ['offerte', 'evidenza', 'nuovi', 'best', 'top20']), exclude, 10);
    var top = dedupeFeedItems(mergedFeedSections(sections, ['top20', 'topselling', 'best']), exclude, 10);
    var recent = dedupeFeedItems(sections.recent || [], exclude, 6);
    var first = buildFeedBand('KsHomeFeedShowcase', 'Offerte e novità', showcase, 'grid', 5);
    insertAfterIconBoxesSection(first);
    if (first) { showcase.forEach(function (item) { var id = parseInt(item.id, 10) || productIdFromUrl(item.url); if (id) exclude[id] = 1; }); }
    var second = buildFeedBand('KsHomeFeedTop', 'Top prodotti', top, 'compact', 5);
    insertBeforeBrandOrFooter(second);
    if (recent.length >= 2) insertBeforeBrandOrFooter(buildFeedBand('KsHomeFeedRecent', 'Scelti Da Te', recent, 'compact', 2));
    ksFeedMounted = !!(first || second || recent.length >= 2);
    if (ksFeedMounted) { document.body.classList.add('ks-home-feed-mounted'); updateAllSwipers(); }
  }

  function fetchAndMountFeedProducts() {
    if (!isHome() || ksFeedMounted || ksFeedInFlight || typeof fetch !== 'function') return;
    ksFeedInFlight = true;
    var url = '/home_runtime_feed.aspx?mode=sections&_=' + encodeURIComponent(String(Date.now()));
    var recent = readRecentParam();
    if (recent) url += '&recent=' + encodeURIComponent(recent);
    fetch(url, { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } })
      .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .then(mountFeedProducts)
      .catch(function () {})
      .then(function () { ksFeedInFlight = false; });
  }
  function normalizeProductGridDensity() {
    var bestSection = qa('main section').filter(function (sec) { return /best seller/i.test(textOf(sec)) && validProductCardCount(sec) >= 3; })[0];
    if (!bestSection) return;
    bestSection.setAttribute('data-ks-home-primary-products', '1');
    removeHardHide(bestSection);
    setProductImagesSafe(bestSection);
    var title = q('.flat-title h5,h5', bestSection);
    if (title) title.textContent = 'Best Seller';
    var swiper = q('.tf-sw-products', bestSection);
    if (swiper) {
      swiper.setAttribute('data-preview', '5');
      swiper.setAttribute('data-tablet', '4');
      swiper.setAttribute('data-mobile-sm', '2');
      swiper.setAttribute('data-mobile', '1');
    }
  }

  function moveBrandsAfterProducts() {
    var brand = q('#HomeBrandsSection');
    var main = q('main');
    if (!brand || !main) return;
    var bestSection = qa('main section').filter(function (sec) { return sec !== brand && /best seller/i.test(textOf(sec)) && validProductCardCount(sec) >= 3; })[0];
    if (bestSection && bestSection.parentNode && bestSection.nextElementSibling !== brand) {
      bestSection.parentNode.insertBefore(brand, bestSection.nextSibling);
    }
    var layer = q('#KsHomeClosingLayer');
    if (layer && brand.parentNode) {
      if (brand.nextSibling) brand.parentNode.insertBefore(layer, brand.nextSibling);
      else brand.parentNode.appendChild(layer);
      removeHardHide(layer);
    }
  }


  function normalizeClosingItemText(value) {
    return String(value || '').replace(/\s+/g, ' ').replace(/^[\s:;,\.\-]+|[\s:;,\.\-]+$/g, '').trim();
  }

  function addUniqueClosingItem(list, seen, title, url, meta) {
    title = normalizeClosingItemText(title);
    url = normalizeClosingItemText(url || '');
    if (!title || title.length < 3) return;
    if (!url || /^#|javascript:/i.test(url)) url = 'articoli.aspx';
    var key = title.toLowerCase();
    if (seen[key]) return;
    seen[key] = 1;
    list.push({ title: title, url: url, meta: normalizeClosingItemText(meta || '') });
  }

  function collectClosingCategories() {
    var out = [], seen = {};
    qa('footer.tf-footer .ft-menu-list a[href*="articoli.aspx"], footer.tf-footer .ft-menu-list a[href]').forEach(function (a) {
      if (out.length >= 12) return;
      var title = textOf(a);
      if (/privacy|condizioni|resi|rimbor|domande|consegna|account|ordine|clienti|faq|supporto/i.test(title)) return;
      addUniqueClosingItem(out, seen, title, a.getAttribute('href') || 'articoli.aspx', 'Categoria');
    });
    if (out.length < 8) {
      collectDepartmentItems().forEach(function (item) {
        if (out.length >= 12) return;
        addUniqueClosingItem(out, seen, item.title, item.url, 'Reparto');
      });
    }
    return out.slice(0, 10);
  }

  function collectClosingServices() {
    var out = [], seen = {};
    qa('.tf-icon-box').forEach(function (box) {
      if (out.length >= 5) return;
      var titleNode = q('h6,h5,.title,.box-title,strong,b', box);
      var bodyNode = q('p,.content,.text,.body-text-3', box);
      var title = titleNode ? textOf(titleNode) : textOf(box).split('.')[0];
      var desc = bodyNode ? textOf(bodyNode) : textOf(box).replace(title, '');
      addUniqueClosingItem(out, seen, title, 'Contattaci.aspx', desc);
    });
    if (out.length < 4) {
      [
        ['Pagamenti sicuri', 'Checkout protetto e metodi di pagamento tracciabili'],
        ['Supporto dedicato', 'Assistenza prima e dopo l\'acquisto'],
        ['Catalogo aggiornato', 'Prodotti e reparti reali KeepStore'],
        ['Garanzia e resi', 'Procedure chiare per acquisti sicuri']
      ].forEach(function (row) { addUniqueClosingItem(out, seen, row[0], 'Contattaci.aspx', row[1]); });
    }
    return out.slice(0, 4);
  }

  function insertClosingLayer(section) {
    if (!section) return;
    var footer = q('footer.tf-footer');
    var brand = q('#HomeBrandsSection');
    var main = q('main') || document.body;
    if (brand && brand.parentNode) {
      if (brand.nextSibling) brand.parentNode.insertBefore(section, brand.nextSibling);
      else brand.parentNode.appendChild(section);
      return;
    }
    if (footer && footer.parentNode) { footer.parentNode.insertBefore(section, footer); return; }
    main.appendChild(section);
  }

  function ensureClosingLayerOrder() {
    if (!isHome()) return;
    var layer = q('#KsHomeClosingLayer');
    if (!layer) {
      buildHomeClosingLayer();
      layer = q('#KsHomeClosingLayer');
    }
    if (!layer) return;
    removeHardHide(layer);
    layer.removeAttribute('data-ks-hidden-reason');
    layer.style.removeProperty('display');
    layer.style.removeProperty('visibility');
    layer.style.removeProperty('opacity');
    layer.style.removeProperty('height');
    layer.style.removeProperty('min-height');
    layer.style.removeProperty('max-height');
    var footer = q('footer.tf-footer');
    var brand = q('#HomeBrandsSection');
    if (brand && brand.parentNode) {
      var parent = brand.parentNode;
      if (layer.parentNode !== parent || brand.nextElementSibling !== layer) {
        if (brand.nextSibling) parent.insertBefore(layer, brand.nextSibling);
        else parent.appendChild(layer);
      }
    } else if (footer && footer.parentNode && layer.nextElementSibling !== footer) {
      footer.parentNode.insertBefore(layer, footer);
    }
    if (footer && layer.parentNode === footer.parentNode && layer.compareDocumentPosition(footer) & Node.DOCUMENT_POSITION_PRECEDING) {
      footer.parentNode.insertBefore(layer, footer);
    }
    document.body.classList.add('ks-home-closing-mounted', 'ks-home-closing-ordered');
  }

  function buildHomeClosingLayer() {
    if (!isHome()) return;
    var existing = q('#KsHomeClosingLayer');
    if (existing) { removeHardHide(existing); return; }
    var categories = collectClosingCategories();
    var services = collectClosingServices();
    if (categories.length < 4) {
      [
        ['Notebook e computer','articoli.aspx','Categoria'],
        ['Fotografia e video','articoli.aspx','Categoria'],
        ['Smartphone e tablet','articoli.aspx','Categoria'],
        ['Gaming e console','articoli.aspx','Categoria'],
        ['TV e audio','articoli.aspx','Categoria'],
        ['Accessori tech','articoli.aspx','Categoria'],
        ['Audio e cuffie','articoli.aspx','Categoria'],
        ['Offerte','articoli.aspx?inpromo=1','Promo']
      ].forEach(function (row) { addUniqueClosingItem(categories, {}, row[0], row[1], row[2]); });
    }
    if (services.length < 3) {
      [
        ['Spedizione veloce','Consegna gestita sugli ordini idonei'],
        ['Pagamenti sicuri','Checkout protetto e metodi tracciabili'],
        ['Supporto dedicato','Assistenza prima e dopo l\'acquisto'],
        ['Garanzia e resi','Procedure chiare per acquisti sicuri']
      ].forEach(function (row) { services.push({ title: row[0], url: 'Contattaci.aspx', meta: row[1] }); });
    }
    categories = categories.slice(0, 10);
    services = services.slice(0, 4);
    var section = document.createElement('section');
    section.id = 'KsHomeClosingLayer';
    section.className = 'tf-sp-2 ks-home-closing-layer';
    section.setAttribute('data-ks-generated', 'closing-layer');
    section.innerHTML = '<div class="container"><div class="ks-home-closing-grid">' +
      '<div class="ks-home-closing-panel ks-home-closing-categories"><div class="ks-home-closing-head"><div><p class="caption text-primary fw-semibold">Catalogo</p><h5 class="fw-semibold">Categorie popolari</h5></div></div><div class="ks-home-closing-chips">' +
      categories.map(function (item) { return '<a class="ks-home-closing-chip" href="' + escHtml(item.url) + '"><span>' + escHtml(item.title) + '</span><small>' + escHtml(item.meta || 'Scopri') + '</small></a>'; }).join('') +
      '</div></div><div class="ks-home-closing-panel ks-home-closing-services"><div class="ks-home-closing-head"><div><p class="caption text-primary fw-semibold">Acquisto sicuro</p><h5 class="fw-semibold">Servizi KeepStore</h5></div></div><div class="ks-home-service-grid">' +
      services.map(function (item) { return '<a class="ks-home-service-card" href="' + escHtml(item.url) + '"><b>' + escHtml(initialFor(item.title)) + '</b><span>' + escHtml(item.title) + '</span><small>' + escHtml(item.meta || 'Scopri di piu') + '</small></a>'; }).join('') +
      '</div></div></div></div>';
    insertClosingLayer(section);
    document.body.classList.add('ks-home-closing-mounted');
  }


  function pruneBridgeAgainstBestSeller() {
    if (!isHome()) return;
    var bridge = q('#KsHomeOnsusBridge');
    if (!bridge) return;
    var seen = {};
    qa('main section').forEach(function (sec) {
      if (!sec || sec === bridge || sec.closest('#KsHomeOnsusBridge')) return;
      if (!/best\s*seller/i.test(textOf(sec))) return;
      qa('a[href*="articolo.aspx?id="]', sec).forEach(function (a) {
        var card = a.closest && a.closest('.card-product,.ks-grid-card,.ks-row-card,.swiper-slide,li,div');
        var data = productDataFromCard(card || a);
        if (!data) return;
        var href = normalizeHomeText(data.url || a.getAttribute('href') || '').toLowerCase();
        var family = productBridgeFamilyKey(data);
        if (href) seen['u:' + href] = 1;
        if (family) seen['f:' + family] = 1;
      });
    });
    qa('.ks-onsus-grid-card,.ks-onsus-side-card', bridge).forEach(function (card) {
      if (!card || card.hasAttribute('hidden')) return;
      var href = normalizeHomeText(card.getAttribute('href') || '').toLowerCase();
      var titleNode = q('.ks-onsus-title', card);
      var family = productBridgeFamilyKey({ title: titleNode ? titleNode.textContent : card.textContent, meta: '' });
      if ((href && seen['u:' + href]) || (family && seen['f:' + family])) {
        card.classList.add('ks-onsus-duplicate-removed', 'ks-onsus-best-duplicate');
        card.setAttribute('hidden', 'hidden');
        card.style.display = 'none';
      }
    });
    if (document.body) document.body.classList.add('ks-onsus-cross-deduped');
  }

  function normalizeOnsusBridgeDensity() {
    var bridge = q('#KsHomeOnsusBridge');
    if (!bridge) return;
    pruneDuplicateBridgeCards(bridge);
    pruneBridgeAgainstBestSeller();
    ['.ks-onsus-product-strip', '.ks-onsus-extra-grid', '.ks-onsus-side-col'].forEach(function (sel) {
      qa(sel, bridge).forEach(function (group) {
        var visible = qa('.ks-onsus-grid-card:not([hidden]),.ks-onsus-side-card:not([hidden])', group);
        if (!visible.length) group.setAttribute('hidden', 'hidden');
        else group.removeAttribute('hidden');
      });
    });
  }



  function applyFinalDesktopPolish() {
    if (!isHome() || !document.body) return;
    document.body.classList.add('ks-home-step95-polish');
    var bridge = q('#KsHomeOnsusBridge');
    if (bridge) {
      var visibleCards = qa('.ks-onsus-grid-card:not([hidden]),.ks-onsus-side-card:not([hidden])', bridge);
      bridge.setAttribute('data-ks-visible-cards', String(visibleCards.length));
      if (visibleCards.length >= 12) document.body.classList.add('ks-home-has-rich-editorial');
      else document.body.classList.remove('ks-home-has-rich-editorial');
    }
    var brand = q('#HomeBrandsSection');
    var closing = q('#KsHomeClosingLayer');
    if (brand && closing && brand.parentNode && closing.parentNode === brand.parentNode && brand.nextElementSibling !== closing) {
      if (brand.nextSibling) brand.parentNode.insertBefore(closing, brand.nextSibling);
      else brand.parentNode.appendChild(closing);
    }
    var footer = q('footer.tf-footer');
    if (footer) {
      var next = footer.nextElementSibling;
      while (next) {
        var after = next.nextElementSibling;
        if (!next.matches || !next.matches('#goTop,.modal,.offcanvas,.modal-backdrop,script,style')) {
          hide(next, 'after-footer-polish');
        }
        next = after;
      }
    }
  }


  function applyStep96OnsusFinal() {
    if (!isHome() || !document.body) return;
    document.body.classList.add("ks-home-step96-onsus-final");
    ensureClosingLayerOrder();
    var closing = q("#KsHomeClosingLayer");
    var brand = q("#HomeBrandsSection");
    var footer = q("footer.tf-footer");
    if (closing) {
      removeHardHide(closing);
      closing.removeAttribute("hidden");
      closing.style.removeProperty("display");
      closing.style.removeProperty("height");
      closing.style.removeProperty("min-height");
      closing.style.removeProperty("max-height");
    }
    if (brand && closing && brand.parentNode && closing.parentNode === brand.parentNode && brand.nextElementSibling !== closing) {
      if (brand.nextSibling) brand.parentNode.insertBefore(closing, brand.nextSibling);
      else brand.parentNode.appendChild(closing);
    }
    if (footer) {
      var n = footer.nextElementSibling;
      while (n) {
        var next = n.nextElementSibling;
        if (!n.matches || !n.matches("#goTop,.modal,.offcanvas,.modal-backdrop,script,style")) {
          hide(n, "after-footer-step96");
        }
        n = next;
      }
    }
  }


  function applyStep97OnsusFinalSeal() {
    if (!isHome() || !document.body) return;
    document.body.classList.add('ks-home-step97-final-seal');

    var bridge = q('#KsHomeOnsusBridge');
    if (bridge) {
      var tabs = qa('.menu-tab-line .tab-link', bridge);
      if (tabs[2]) tabs[2].textContent = 'Scelti Da Te';
      var visibleCards = qa('.ks-onsus-grid-card:not([hidden]),.ks-onsus-side-card:not([hidden])', bridge);
      bridge.setAttribute('data-ks-visible-cards', String(visibleCards.length));

      var maxEditorialCards = 18;
      visibleCards.forEach(function (card, index) {
        if (index >= maxEditorialCards) {
          card.classList.add('ks-onsus-overflow-removed');
          card.setAttribute('hidden', 'hidden');
          card.style.setProperty('display', 'none', 'important');
        }
      });
      ['.ks-onsus-product-strip', '.ks-onsus-extra-grid', '.ks-onsus-side-col'].forEach(function (sel) {
        qa(sel, bridge).forEach(function (group) {
          if (!qa('.ks-onsus-grid-card:not([hidden]),.ks-onsus-side-card:not([hidden])', group).length) group.setAttribute('hidden', 'hidden');
        });
      });
    }

    var brand = q('#HomeBrandsSection');
    var closing = q('#KsHomeClosingLayer');
    if (brand && closing && brand.parentNode) {
      removeHardHide(closing);
      if (closing.parentNode !== brand.parentNode || brand.nextElementSibling !== closing) {
        if (brand.nextSibling) brand.parentNode.insertBefore(closing, brand.nextSibling);
        else brand.parentNode.appendChild(closing);
      }
    }
  }

  function buildHomeCompositionLayer() {
    runSafe('buildDepartmentShowcase', buildDepartmentShowcase);
    runSafe('normalizeProductGridDensity', normalizeProductGridDensity);
    runSafe('mountOnsusBridgeFromServerProducts', mountOnsusBridgeFromServerProducts);
    runSafe('fetchAndMountFeedProducts', fetchAndMountFeedProducts);
    runSafe('normalizeOnsusBridgeDensity', normalizeOnsusBridgeDensity);
    runSafe('moveBrandsAfterProducts', moveBrandsAfterProducts);
    runSafe('buildHomeClosingLayer', buildHomeClosingLayer);
    runSafe('ensureClosingLayerOrder', ensureClosingLayerOrder);
  }

  function stabilize() {
    if (!isHome()) return;
    runSafe('ensureChromeOrder', ensureChromeOrder);
    runSafe('normalizeDesktopCatalogMegaMenu', normalizeDesktopCatalogMegaMenu);
    runSafe('forceHeroLayout', forceHeroLayout);
    runSafe('restoreCommercialSections', restoreCommercialSections);
    runSafe('buildHomeCompositionLayer', buildHomeCompositionLayer);
    runSafe('normalizeOnsusBridgeDensity', normalizeOnsusBridgeDensity);
    runSafe('compactBeforeBrands', compactBeforeBrands);
    runSafe('finalPruneMalformedCommercialGroups', finalPruneMalformedCommercialGroups);
    runSafe('compactEmptyTailBeforeFooter', compactEmptyTailBeforeFooter);
    runSafe('hideAfterFooterArtifacts', hideAfterFooterArtifacts);
    runSafe('releaseHomePageHeight', releaseHomePageHeight);
    runSafe('collapseDormantOverlayArtifacts', collapseDormantOverlayArtifacts);
    runSafe('buildHomeClosingLayerFinal', buildHomeClosingLayer);
    runSafe('ensureClosingLayerOrder', ensureClosingLayerOrder);
    runSafe('enforceFooterScrollClosure', enforceFooterScrollClosure);
    runSafe('applyFinalDesktopPolish', applyFinalDesktopPolish);
    runSafe('applyStep96OnsusFinal', applyStep96OnsusFinal);
    runSafe('applyStep97OnsusFinalSeal', applyStep97OnsusFinalSeal);
    runSafe('bindGeneratedImageFallbacks', function () { bindGeneratedImageFallbacks(document); });
    runSafe('updateAllSwipers', updateAllSwipers);
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
    [650, 1600, 3200].forEach(function (delay) { window.setTimeout(fetchAndMountFeedProducts, delay); });
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
