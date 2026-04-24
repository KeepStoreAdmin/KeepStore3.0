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

  function directChildren(parent) {
    if (!parent || !parent.children) return [];
    return Array.prototype.slice.call(parent.children);
  }
  function directChild(parent, test) {
    var children = directChildren(parent);
    for (var i = 0; i < children.length; i++) {
      try { if (test(children[i])) return children[i]; } catch (err) {}
    }
    return null;
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

  function normalizeChromeOrder() {
    if (!isHome()) return;
    var wrapper = document.getElementById('wrapper');
    if (!wrapper) return;

    var main = directChild(wrapper, function (node) { return String(node.tagName || '').toLowerCase() === 'main'; }) || q('main', wrapper) || q('main');
    var footer = directChild(wrapper, function (node) { return String(node.tagName || '').toLowerCase() === 'footer' && node.classList && node.classList.contains('tf-footer'); }) || q('footer.tf-footer');
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
    var firstFooter = directChild(wrapper, function (node) { return String(node.tagName || '').toLowerCase() === 'footer' && node.classList && node.classList.contains('tf-footer'); }) || footer;
    qa('footer.tf-footer').forEach(function (f) {
      if (f !== firstFooter) {
        f.setAttribute('data-ks-duplicate-chrome', 'footer-clone');
        hide(f, 'footer-clone');
      }
    });

    qa('.tf-footer .tf-topbar, .tf-footer .inner-header, .tf-footer .header-bottom, .tf-footer .ks-header-ui, .tf-footer header.tf-header').forEach(function (node) {
      if (header && header.contains(node)) return;
      node.setAttribute('data-ks-duplicate-chrome', 'footer-header-fragment');
      hide(node, 'footer-header-fragment');
    });
  }

  function quarantineForeignDirectChildren() {
    if (!isHome()) return;
    var form = document.getElementById('form1') || q('body > form');
    if (!form) return;
    directChildren(form).forEach(function (node) {
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


  var ksRuntimeEditorialState = { requested: false, mounted: false, failed: false };

  function readCookieValue(name) {
    var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }

  function parseIdList(raw) {
    var seen = {}, out = [];
    String(raw || '').split(',').forEach(function (part) {
      var id = parseInt(part, 10);
      if (Number.isFinite(id) && id > 0 && !seen[id]) { seen[id] = 1; out.push(id); }
    });
    return out;
  }

  function mergedRecentIds() {
    var list = [];
    try { list = list.concat(parseIdList(window.sessionStorage.getItem('ks_recent_session') || '')); } catch (err) {}
    list = list.concat(parseIdList(readCookieValue('ks_recent')));
    var seen = {}, out = [];
    list.forEach(function (id) { if (id && !seen[id]) { seen[id] = 1; out.push(id); } });
    return out.slice(0, 100);
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function normalizeText(value) {
    return String(value || '')
      .toLowerCase()
      .replace(/[àáâãäå]/g, 'a').replace(/[èéêë]/g, 'e').replace(/[ìíîï]/g, 'i')
      .replace(/[òóôõö]/g, 'o').replace(/[ùúûü]/g, 'u')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function displayFamilyKey(item) {
    var blocked = {
      black:1, white:1, red:1, blue:1, green:1, yellow:1, pink:1, gold:1, silver:1, grey:1, gray:1,
      nero:1, bianco:1, rossa:1, rosso:1, blu:1, verde:1, giallo:1, rosa:1, oro:1, argento:1, grigio:1,
      clear:1, case:1, cover:1, custodia:1, shell:1, glass:1, tempered:1, protector:1, protezione:1,
      mm:1, cm:1, gb:1, tb:1, xl:1, xxl:1, taglia:1, colore:1, con:1, per:1, the:1, for:1
    };
    var text = normalizeText([item && item.brand, item && item.title, item && item.category].join(' '));
    var tokens = text.split(' ').filter(function (token) {
      if (!token || blocked[token]) return false;
      if (/^\d+$/.test(token)) return false;
      if (/^\d+(mm|cm|gb|tb|mah|w|v|hz)$/.test(token)) return false;
      return true;
    });
    return tokens.slice(0, 9).join(' ');
  }

  function itemImage(item) {
    var out = [];
    function add(src) {
      src = String(src || '').trim();
      if (!src || out.indexOf(src) >= 0) return;
      out.push(src);
    }
    add(item && item.preview);
    add(item && item.image);
    (item && item.images || []).forEach(add);
    return out[0] || '';
  }

  function itemPriceHtml(item) {
    var p = String(item && item.price || '').trim();
    var o = String(item && item.oldPrice || '').trim();
    var current = p ? '<span class="ks-home-runtime-price-new">' + escapeHtml(p) + (/[€$£]/.test(p) ? '' : ' €') + '</span>' : '';
    var old = o ? '<span class="ks-home-runtime-price-old">' + escapeHtml(o) + (/[€$£]/.test(o) ? '' : ' €') + '</span>' : '';
    return '<div class="ks-home-runtime-price">' + current + old + '</div>';
  }

  function validRuntimeItem(item) {
    return !!(item && parseInt(item.id, 10) > 0 && item.url && item.title && itemImage(item));
  }

  function takeRuntimeItems(lists, count, used, options) {
    var out = [];
    var seenId = {};
    var seenFamily = {};
    options = options || {};
    (lists || []).forEach(function (list) {
      (list || []).forEach(function (item) {
        if (out.length >= count) return;
        if (!validRuntimeItem(item)) return;
        var id = parseInt(item.id, 10) || 0;
        var family = displayFamilyKey(item) || String(id);
        if (seenId[id] || (used && used.id && used.id[id])) return;
        if (!options.allowFamilyRepeat && (seenFamily[family] || (used && used.family && used.family[family]))) return;
        seenId[id] = 1;
        seenFamily[family] = 1;
        out.push(item);
      });
    });
    if (used) {
      out.forEach(function (item) {
        var id = parseInt(item.id, 10) || 0;
        var family = displayFamilyKey(item) || String(id);
        used.id[id] = 1;
        used.family[family] = 1;
      });
    }
    return out;
  }

  function runtimeCard(item) {
    var image = itemImage(item);
    var title = String(item && item.title || '');
    var meta = [];
    if (item && item.brand) meta.push(escapeHtml(item.brand));
    if (item && item.category) meta.push(escapeHtml(item.category));
    var pct = parseInt(item && item.salePercent, 10) || 0;
    return '<article class="ks-home-runtime-card">' +
      (pct > 0 ? '<span class="ks-home-runtime-badge">-' + pct + '%</span>' : '') +
      '<a class="ks-home-runtime-image" href="' + escapeHtml(item.url || '#') + '"><img src="' + escapeHtml(image) + '" alt="' + escapeHtml(title) + '" loading="lazy" decoding="async"></a>' +
      (meta.length ? '<div class="ks-home-runtime-meta">' + meta.join('<span>•</span>') + '</div>' : '') +
      '<a class="ks-home-runtime-title" href="' + escapeHtml(item.url || '#') + '">' + escapeHtml(title) + '</a>' +
      itemPriceHtml(item) +
      '</article>';
  }

  function runtimeSection(title, items, className) {
    if (!items || !items.length) return '';
    return '<section class="ks-home-runtime-section ' + escapeHtml(className || '') + '">' +
      '<div class="container"><div class="ks-home-runtime-title"><h5>' + escapeHtml(title) + '</h5></div>' +
      '<div class="ks-home-runtime-grid">' + items.map(runtimeCard).join('') + '</div></div></section>';
  }

  function getSections(payload) {
    var sections = payload && payload.sections || {};
    if (!sections.deals && payload && payload.deals) sections.deals = payload.deals;
    function arr(key) { return Array.isArray(sections[key]) ? sections[key] : []; }
    return {
      deals: arr('deals'), offerte: arr('offerte'), evidenza: arr('evidenza'), nuovi: arr('nuovi'), best: arr('best'),
      top20: arr('top20'), topselling: arr('topselling'), recent: arr('recent'), viewed: arr('viewed'), combined: arr('combined')
    };
  }

  function mountRuntimeEditorial(payload) {
    if (ksRuntimeEditorialState.mounted || !payload || payload.ok === false) return;
    var s = getSections(payload);
    var used = { id: {}, family: {} };
    var html = [];
    var deals = takeRuntimeItems([s.deals, s.offerte, s.combined], 4, used, { allowFamilyRepeat: true });
    if (deals.length >= 2) html.push(runtimeSection('Occasione Imperdibile', deals, 'ks-home-runtime-deals'));
    var best = takeRuntimeItems([s.best, s.top20, s.topselling, s.combined], 8, used);
    if (best.length >= 4) html.push(runtimeSection('Best Seller', best, 'ks-home-runtime-best'));
    var featured = takeRuntimeItems([s.evidenza, s.nuovi, s.offerte, s.combined], 8, used);
    if (featured.length >= 4) html.push(runtimeSection('In Evidenza', featured, 'ks-home-runtime-featured'));
    var recent = takeRuntimeItems([s.recent, s.viewed], 6, used);
    if (recent.length >= 2) html.push(runtimeSection('Scelti Da Te', recent, 'ks-home-runtime-recent'));
    var lowerA = takeRuntimeItems([s.top20, s.best, s.combined], 5, used);
    var lowerB = takeRuntimeItems([s.topselling, s.best, s.combined], 5, used);
    var lowerC = takeRuntimeItems([s.offerte, s.deals, s.combined], 5, used, { allowFamilyRepeat: true });
    var lowerHtml = [];
    if (lowerA.length >= 3) lowerHtml.push('<div class="ks-home-runtime-lower-col"><h5>Top 20</h5><div class="ks-home-runtime-list">' + lowerA.map(runtimeCard).join('') + '</div></div>');
    if (lowerB.length >= 3) lowerHtml.push('<div class="ks-home-runtime-lower-col"><h5>I Più Venduti</h5><div class="ks-home-runtime-list">' + lowerB.map(runtimeCard).join('') + '</div></div>');
    if (lowerC.length >= 3) lowerHtml.push('<div class="ks-home-runtime-lower-col"><h5>In Offerta</h5><div class="ks-home-runtime-list">' + lowerC.map(runtimeCard).join('') + '</div></div>');
    if (lowerHtml.length) html.push('<section class="ks-home-runtime-section ks-home-runtime-lower"><div class="container"><div class="ks-home-runtime-lower-grid">' + lowerHtml.join('') + '</div></div></section>');

    if (!html.length) return;
    var mount = document.getElementById('ksHomeRuntimeEditorial');
    if (!mount) {
      mount = document.createElement('div');
      mount.id = 'ksHomeRuntimeEditorial';
      mount.className = 'ks-home-runtime-editorial';
      var brands = q('#HomeBrandsSection');
      var main = q('#wrapper main') || q('main') || document.body;
      if (brands && brands.parentNode) brands.parentNode.insertBefore(mount, brands);
      else main.appendChild(mount);
    }
    mount.innerHTML = html.join('');
    document.body.classList.add('ks-home-runtime-mounted');
    ksRuntimeEditorialState.mounted = true;
    hideOriginalCommercialSections('runtime-mounted');
  }

  function requestRuntimeEditorial() {
    if (!isHome() || ksRuntimeEditorialState.requested || ksRuntimeEditorialState.mounted) return;
    if (!window.fetch) return;
    ksRuntimeEditorialState.requested = true;
    var url = new URL('/home_runtime_feed.aspx', window.location.href);
    url.searchParams.set('mode', 'all');
    url.searchParams.set('_', Date.now().toString());
    var recent = mergedRecentIds().slice(0, 32);
    if (recent.length) url.searchParams.set('recent', recent.join(','));
    fetch(url.toString(), { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } })
      .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .then(mountRuntimeEditorial)
      .catch(function () { ksRuntimeEditorialState.failed = true; });
  }

  function isElementVisible(node) {
    if (!node || node.nodeType !== 1) return false;
    var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    if (style && (style.display === 'none' || style.visibility === 'hidden' || parseFloat(style.opacity || '1') === 0)) return false;
    var rect = node.getBoundingClientRect ? node.getBoundingClientRect() : null;
    return !!(rect && rect.width > 24 && rect.height > 24);
  }

  function visibleProductImageCount(root) {
    if (!root) return 0;
    var seen = {}, count = 0;
    qa('a[href*="articolo.aspx?id="] img, .card-product img, .ks-grid-card img, .ks-row-card img, .ks-big-card img, .ks-deal-card img', root).forEach(function (img) {
      if (!isElementVisible(img)) return;
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src || /logo|brand|pagamenti|payment|mail\.svg|headphone|spinner/i.test(src)) return;
      if (seen[src]) return;
      seen[src] = 1;
      count++;
    });
    return count;
  }

  function hideOriginalCommercialSections(reason) {
    var selectors = [
      '.flat-animate-tab',
      '#HomeLowerColumnsSection',
      '#HomeRecentlyViewedSection',
      '#HomeWidePromoSection',
      '#HomeCollectionSection',
      '#HomeBottomPromoSection'
    ];
    selectors.forEach(function (selector) { qa(selector).forEach(function (node) { hide(node, reason || 'original-commercial-replaced'); }); });
    qa('main section').forEach(function (section) {
      if (!section || section.id === 'HomeHeroSection' || section.id === 'HomeBrandsSection' || section.id === 'ksHomeRuntimeEditorial') return;
      if (section.closest('#ksHomeRuntimeEditorial')) return;
      if (q('.tf-icon-box', section)) return;
      var text = normalizeText(textOf(section));
      var hasProductLink = !!q('a[href*="articolo.aspx?id="]', section);
      var commercialTitle = /occasione imperdibile|best seller|in evidenza|top 20|venduti|offerta|offerte|nuovi arrivi|scelti da te/.test(text);
      if (hasProductLink || commercialTitle) hide(section, reason || 'original-commercial-replaced');
    });
  }

  function hideMalformedOriginalCommercialSections() {
    qa('.flat-animate-tab').forEach(function (section) {
      if (visibleProductImageCount(section) < 3) hide(section, 'tabs-malformed-no-visible-products');
    });
    qa('main section').forEach(function (section) {
      if (!section || section.id === 'HomeHeroSection' || section.id === 'HomeBrandsSection' || section.id === 'ksHomeRuntimeEditorial') return;
      if (section.closest('#ksHomeRuntimeEditorial')) return;
      if (q('.tf-icon-box', section)) return;
      var text = normalizeText(textOf(section));
      if (/occasione imperdibile|best seller|in evidenza|top 20|venduti|offerta|offerte|nuovi arrivi|scelti da te/.test(text)) {
        if (visibleProductImageCount(section) === 0 && countProductLinks(section) > 0) hide(section, 'commercial-malformed-no-visible-images');
      }
    });
  }

  function hideOrphanPrices() {
    if (ksRuntimeEditorialState.mounted) {
      qa('main .text-primary, main .new-price, main .old-price, main .price, main [class*="price"]').forEach(function (node) {
        if (!node || node.closest('#ksHomeRuntimeEditorial') || node.closest('#HomeHeroSection') || node.closest('#HomeBrandsSection') || node.closest('footer') || node.closest('header')) return;
        var block = node.closest('section,.tf-grid-product-item,.card-product,.ks-row-card,.ks-grid-card,.ks-deal-card,.product-list-wrap,li,div');
        var txt = textOf(node);
        if (/^€?\s*\d+[\d.,]*\s*€?$/.test(txt) || /\d+[\d.,]*\s*€/.test(txt)) hide(block || node, 'orphan-price-after-runtime-mount');
      });
    }
  }

  function finalizeCommercialRuntime() {
    hideMalformedOriginalCommercialSections();
    requestRuntimeEditorial();
    if (ksRuntimeEditorialState.mounted) {
      hideOriginalCommercialSections('runtime-mounted');
      hideOrphanPrices();
    }
  }

  function runSafe(name, fn) {
    try { fn(); } catch (err) {
      try { document.body.setAttribute('data-ks-last-home-error', name); } catch (e) {}
    }
  }

  function stabilizeHome() {
    if (!isHome()) return;
    runSafe('chrome', normalizeChromeOrder);
    runSafe('foreign', quarantineForeignDirectChildren);
    runSafe('hero', forceHeroLayout);
    runSafe('empty-sections', closeEmptySections);
    runSafe('commercial-runtime', finalizeCommercialRuntime);
    runSafe('swipers', updateAllSwipers);
  }

  function boot() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home');
    runSafe('chrome', normalizeChromeOrder);
    runSafe('foreign', quarantineForeignDirectChildren);
    runSafe('hero-swiper', initHeroSwiper);
    runSafe('brand-swiper', initBrandSlider);
    runSafe('collection-swiper', initCollectionSlider);
    runSafe('column-swipers', initColumnSwipers);
    runSafe('images', normalizeImages);
    runSafe('image-refresh', bindImageRefresh);
    stabilizeHome();
    runSafe('commercial-runtime', finalizeCommercialRuntime);

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
