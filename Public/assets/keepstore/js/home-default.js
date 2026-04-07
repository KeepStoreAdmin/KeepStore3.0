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
    if (!node) return;
    node.style.display = 'none';
    node.setAttribute('data-ks-hidden', '1');
  }

  function showNode(node, value) {
    if (!node) return;
    node.style.display = value || '';
    node.removeAttribute('data-ks-hidden');
  }

  function updateAllSwipers() {
    Array.prototype.slice.call(document.querySelectorAll('.swiper')).forEach(function (swiperEl) {
      if (swiperEl.swiper && typeof swiperEl.swiper.update === 'function') {
        swiperEl.swiper.update();
      }
    });
  }

  function normalizeText(value) {
    return String(value || '')
      .toLowerCase()
      .replace(/[àáâãäå]/g, 'a')
      .replace(/[èéêë]/g, 'e')
      .replace(/[ìíîï]/g, 'i')
      .replace(/[òóôõö]/g, 'o')
      .replace(/[ùúûü]/g, 'u')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function displayKey(value) {
    var normalized = normalizeText(value);
    if (!normalized) return '';
    var blocked = [
      'black', 'white', 'red', 'blue', 'green', 'yellow', 'pink', 'gold', 'silver', 'grey', 'gray',
      'nero', 'bianco', 'rosso', 'blu', 'verde', 'giallo', 'rosa', 'oro', 'argento', 'grigio',
      'clear', 'trasparente', 'cover', 'case', 'custodia', 'shell', 'glass', 'tempered', 'protector',
      'mm', 'cm', 'gb', 'tb', 'xl', 'xxl', 'taglia', 'colore'
    ];
    var tokens = normalized.split(' ').filter(function (token) {
      if (!token) return false;
      if (/^\d+$/.test(token)) return false;
      if (/^\d+(mm|cm|gb|tb)$/.test(token)) return false;
      return blocked.indexOf(token) === -1;
    });
    return tokens.slice(0, 8).join(' ');
  }

  function containsBlockedCreativeToken(text) {
    var value = normalizeText(text);
    var blocked = ['welcome', 'franchis', 'onsus', 'themesflat', 'themeforest', 'demo', 'placeholder', 'sample'];
    return blocked.some(function (token) {
      return value.indexOf(token) !== -1;
    });
  }

  function isValidCreativeImage(img, kind) {
    if (!img) return false;

    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    var alt = img.getAttribute('alt') || '';
    if (!src) return false;
    if (containsBlockedCreativeToken(src) || containsBlockedCreativeToken(alt)) return false;

    var width = Number(img.naturalWidth || 0);
    var height = Number(img.naturalHeight || 0);
    if (width <= 0 || height <= 0) return false;
    if (width < 240 || height < 120) return false;

    var ratio = width / height;
    if (kind === 'hero') {
      return ratio >= 1.2 && ratio <= 4.8;
    }

    return ratio >= 0.9 && ratio <= 4.5;
  }

  function isPlausibleLogo(img) {
    if (!img) return false;
    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    var alt = img.getAttribute('alt') || '';
    if (!src) return false;
    if (containsBlockedCreativeToken(src) || containsBlockedCreativeToken(alt)) return false;
    if (/(banner|hero|promo|slider|product|articolo|phone|tablet)/i.test(src + ' ' + alt)) return false;
    var width = Number(img.naturalWidth || 0);
    var height = Number(img.naturalHeight || 0);
    if (width <= 0 || height <= 0) return false;
    if (width < 60 || height < 20) return false;
    var ratio = width / height;
    return ratio >= 0.6 && ratio <= 8;
  }

  function markInvalidCreative(node) {
    if (!node) return;
    node.setAttribute('data-ks-invalid', '1');
    hideNode(node);
  }

  function countValidNodes(nodes) {
    return nodes.filter(function (node) {
      return node && node.getAttribute('data-ks-invalid') !== '1';
    }).length;
  }

  function applyHeroMode(mode) {
    var section = document.getElementById('HomeHeroSection');
    var shell = document.getElementById('HomeHeroShell');
    var sliderWrap = document.getElementById('HeroSliderWrap');
    var sideWrap = document.getElementById('HeroSideWrap');
    var normalized = (mode || 'none').toLowerCase();

    function replaceModeClass(node) {
      if (!node) return;
      node.className = String(node.className || '')
        .replace(/\bks-home-hero-mode-[^\s]+\b/g, '')
        .replace(/\s+/g, ' ')
        .trim();
      node.className = (node.className + ' ks-home-hero-mode-' + normalized)
        .replace(/\s+/g, ' ')
        .trim();
    }

    replaceModeClass(section);
    replaceModeClass(shell);

    if (normalized === 'none') {
      hideNode(section);
      hideNode(sliderWrap);
      hideNode(sideWrap);
      return;
    }

    showNode(section);
    showNode(sliderWrap);

    if (normalized === 'full') {
      showNode(sideWrap, 'flex');
    } else {
      hideNode(sideWrap);
    }
  }

  function auditHeroAssets(done) {
    var heroSlides = Array.prototype.slice.call(document.querySelectorAll('.ks-home-hero-slider .swiper-slide'));
    var sideCards = Array.prototype.slice.call(document.querySelectorAll('.ks-home-side-banners .ks-side-promo-card, #HeroSideWrap .cls-category, #HeroSideWrap .ks-side-banner'));
    var auditTargets = [];
    var pending = 0;
    var completed = false;

    function finalize() {
      if (completed) return;
      completed = true;

      var validHeroSlides = countValidNodes(heroSlides);
      var validSideCards = countValidNodes(sideCards);

      if (validHeroSlides <= 0) {
        applyHeroMode('none');
      } else if (validSideCards >= 2) {
        applyHeroMode('full');
      } else {
        applyHeroMode('compact-single');
      }

      if (typeof done === 'function') {
        done();
      }
    }

    function inspect(entry) {
      if (!isValidCreativeImage(entry.img, entry.kind)) {
        markInvalidCreative(entry.node);
      }
    }

    function attachAudit(entry) {
      var img = entry.img;
      if (!img) {
        markInvalidCreative(entry.node);
        return;
      }

      if (img.complete) {
        inspect(entry);
        return;
      }

      pending += 1;
      var handled = false;

      function finish(success) {
        if (handled) return;
        handled = true;
        if (!success) {
          markInvalidCreative(entry.node);
        } else {
          inspect(entry);
        }
        pending -= 1;
        if (pending <= 0) {
          finalize();
        }
      }

      img.addEventListener('load', function () { finish(true); }, { once: true });
      img.addEventListener('error', function () { finish(false); }, { once: true });
    }

    heroSlides.forEach(function (slide) {
      var img = slide.querySelector('img');
      if (!img) {
        markInvalidCreative(slide);
        return;
      }
      auditTargets.push({ kind: 'hero', node: slide, img: img });
    });

    sideCards.forEach(function (card) {
      var img = card.querySelector('img');
      if (!img) {
        markInvalidCreative(card);
        return;
      }
      auditTargets.push({ kind: 'side', node: card, img: img });
    });

    if (!auditTargets.length) {
      finalize();
      return;
    }

    auditTargets.forEach(attachAudit);

    if (pending <= 0) {
      finalize();
    }
  }

  function initHero() {
    var hero = document.querySelector('.ks-home-hero-slider');
    if (!hero) return;

    var slides = Array.prototype.slice.call(hero.querySelectorAll('.swiper-slide')).filter(function (slide) {
      return slide.getAttribute('data-ks-invalid') !== '1';
    });
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
      loop: brand.querySelectorAll('.swiper-slide:not([data-ks-invalid="1"])').length > 6,
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
      '.ks-deal-card .card-product-info',
      '.card-product .card-product-info'
    ];

    groups.forEach(function (selector) {
      var nodes = Array.prototype.slice.call(document.querySelectorAll(selector)).filter(function (node) {
        return node.offsetParent !== null;
      });
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
      menu.style.height = '';
      menu.style.maxHeight = '';
      return;
    }

    var target = 0;
    if (sliderWrap && sliderWrap.offsetParent !== null) {
      target = Math.max(target, sliderWrap.offsetHeight || 0);
    }
    if (sideWrap && sideWrap.offsetParent !== null) {
      target = Math.max(target, sideWrap.offsetHeight || 0);
    }

    if (target > 0) {
      menu.style.minHeight = '';
      menu.style.height = target + 'px';
      menu.style.maxHeight = target + 'px';
    } else {
      menu.style.minHeight = '';
      menu.style.height = '';
      menu.style.maxHeight = '';
    }
  }

  function refreshSwipersInTabs() {
    Array.prototype.slice.call(document.querySelectorAll('[data-bs-toggle="tab"]')).forEach(function (trigger) {
      trigger.addEventListener('shown.bs.tab', function () {
        updateAllSwipers();
        window.setTimeout(function () {
          normalizeCardHeights();
          dedupeEditorialContent();
        }, 80);
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
          auditBrandLogos();
        }, 60);
      }, { once: true });
    });
  }

  function normalizeImages() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-grid-card img, .ks-big-card img, .ks-deal-card img, .card-product img')).forEach(function (img) {
      img.setAttribute('loading', 'lazy');
    });
  }

  function cardNodeList(root) {
    return Array.prototype.slice.call((root || document).querySelectorAll('.card-product, .ks-grid-card, .ks-row-card, .ks-big-card, .ks-deal-card'));
  }

  function titleNode(card) {
    return card.querySelector('.name-product') || card.querySelector('h6 a') || card.querySelector('h5 a') || card.querySelector('a.title');
  }

  function cardTitle(card) {
    var node = titleNode(card);
    return node ? node.textContent : '';
  }

  function cardHref(card) {
    var node = titleNode(card) || card.querySelector('a[href*="articolo.aspx?id="]') || card.querySelector('a[href]');
    return node ? node.getAttribute('href') || '' : '';
  }

  function cardExactKey(card) {
    var href = cardHref(card);
    if (href) {
      var match = href.match(/[?&]id=(\d+)/i);
      if (match) return 'id:' + match[1];
      return 'url:' + href.replace(/#.*$/, '');
    }
    return 'title:' + normalizeText(cardTitle(card));
  }

  function visibleCardCount(root) {
    return cardNodeList(root).filter(function (card) {
      return card.offsetParent !== null && card.getAttribute('data-ks-hidden') !== '1';
    }).length;
  }

  function headingText(node) {
    return normalizeText(node ? node.textContent : '');
  }

  function sectionTitleMap() {
    return {
      'scelti da te': 2,
      'top 20': 3,
      'in evidenza': 3,
      'i piu venduti': 3,
      'in offerta': 3
    };
  }

  function editorialHeadingNodes() {
    var wanted = Object.keys(sectionTitleMap());
    return Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6,a.tab-link,button.tab-link')).filter(function (node) {
      var text = headingText(node);
      return wanted.indexOf(text) !== -1;
    });
  }

  function sectionContainerFromHeading(heading) {
    return heading.closest('.tf-grid-product-item') || heading.closest('section') || heading.closest('.themesFlat') || heading.closest('.container') || heading.parentElement;
  }

  function dedupeEditorialContent() {
    var thresholds = sectionTitleMap();
    var headings = editorialHeadingNodes();
    if (!headings.length) return;

    var orderedLabels = ['scelti da te', 'top 20', 'in evidenza', 'i piu venduti', 'in offerta'];
    var orderedContainers = [];

    orderedLabels.forEach(function (label) {
      headings.forEach(function (heading) {
        if (headingText(heading) === label) {
          orderedContainers.push({
            label: label,
            heading: heading,
            container: sectionContainerFromHeading(heading)
          });
        }
      });
    });

    var seenExact = new Set();

    orderedContainers.forEach(function (entry) {
      if (!entry.container) return;
      var seenFamily = new Set();
      cardNodeList(entry.container).forEach(function (card) {
        if (!card || card.offsetParent === null) return;
        var exact = cardExactKey(card);
        var family = displayKey(cardTitle(card));
        var hide = false;

        if (exact && seenExact.has(exact)) {
          hide = true;
        }
        if (!hide && family && seenFamily.has(family)) {
          hide = true;
        }

        if (hide) {
          hideNode(card);
          var slide = card.closest('.swiper-slide');
          if (slide && slide.parentNode && cardNodeList(slide).length <= 1) {
            hideNode(slide);
          }
          return;
        }

        if (exact) seenExact.add(exact);
        if (family) seenFamily.add(family);
      });

      if (visibleCardCount(entry.container) < (thresholds[entry.label] || 1)) {
        hideNode(entry.container);
      } else {
        showNode(entry.container);
      }
    });
  }

  function auditBrandLogos() {
    var sections = Array.prototype.slice.call(document.querySelectorAll('.ks-home-brands, [data-ks-brand-block="1"]'));
    if (!sections.length) {
      var brandHeading = Array.prototype.slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).filter(function (node) {
        return headingText(node) === normalizeText('rivenditori ufficiali i migliori brand');
      })[0];
      if (brandHeading) {
        var container = sectionContainerFromHeading(brandHeading);
        if (container) sections.push(container);
      }
    }

    sections.forEach(function (section) {
      var slides = Array.prototype.slice.call(section.querySelectorAll('.swiper-slide'));
      var visible = 0;
      slides.forEach(function (slide) {
        var img = slide.querySelector('img');
        if (!img) {
          hideNode(slide);
          return;
        }
        if (img.complete) {
          if (!isPlausibleLogo(img)) {
            hideNode(slide);
          } else {
            visible += 1;
          }
          return;
        }
        img.addEventListener('load', function () {
          if (!isPlausibleLogo(img)) {
            hideNode(slide);
          }
        }, { once: true });
        img.addEventListener('error', function () {
          hideNode(slide);
        }, { once: true });
        visible += 1;
      });
      if (visible === 0) {
        hideNode(section);
      }
    });
  }

  function boot() {
    auditHeroAssets(function () {
      initHero();
      initBrandSlider();
      initCollectionSlider();
      initColumnSwipers();
      normalizeImages();
      dedupeEditorialContent();
      auditBrandLogos();
      normalizeCardHeights();
      syncHeroLayout();
      refreshSwipersInTabs();
      bindImageDrivenRefresh();

      window.addEventListener('resize', function () {
        normalizeCardHeights();
        syncHeroLayout();
        updateAllSwipers();
      });
    });
  }

  onReady(boot);
})();
