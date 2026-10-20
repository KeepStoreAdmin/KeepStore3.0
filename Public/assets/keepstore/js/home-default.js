(function () {
  'use strict';

  window.KS_HOME_SERVER_RENDERED = true;

  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn, { once: true });
    } else {
      fn();
    }
  }

  function qs(sel, root) {
    return (root || document).querySelector(sel);
  }

  function qsa(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function isElement(value) {
    return !!value && value.nodeType === 1;
  }

  function hasSwiperStructure(el) {
    return isElement(el) && !!qs('.swiper-wrapper', el) && qsa('.swiper-slide', el).length > 0;
  }

  function removeEmptySwiperControls(options) {
    if (!options) return {};

    if (options.navigation) {
      if (!isElement(options.navigation.nextEl) || !isElement(options.navigation.prevEl)) {
        delete options.navigation;
      }
    }

    if (options.pagination && !isElement(options.pagination.el)) {
      delete options.pagination;
    }

    if (options.scrollbar && !isElement(options.scrollbar.el)) {
      delete options.scrollbar;
    }

    if (options.thumbs && !options.thumbs.swiper) {
      delete options.thumbs;
    }

    return options;
  }

  function isHome() {
    return !!document.body && (document.body.classList.contains('ks-page-home') || !!qs('.ks-home-hero-section'));
  }

  function initSwiper(el, options) {
    if (!hasSwiperStructure(el) || typeof window.Swiper === 'undefined') return null;
    if (el.swiper) {
      try { el.swiper.update(); } catch (ignore) {}
      return el.swiper;
    }
    try {
      return new window.Swiper(el, removeEmptySwiperControls(options || {}));
    } catch (err) {
      if (window.console && console.warn) console.warn('[KeepStore home] Swiper init error', err);
      return null;
    }
  }

  function initHomeSwipers() {
    qsa('.ks-home-hero-slider').forEach(function (el) {
      var hasMultipleSlides = qsa('.swiper-slide', el).length > 1;
      initSwiper(el, {
        slidesPerView: 1,
        loop: hasMultipleSlides,
        speed: 650,
        autoplay: hasMultipleSlides ? { delay: 5200, disableOnInteraction: false } : false,
        navigation: {
          nextEl: qs('.ks-hero-next', el),
          prevEl: qs('.ks-hero-prev', el)
        },
        pagination: {
          el: qs('.ks-hero-pagination', el),
          clickable: true
        }
      });
    });

    qsa('.tf-sw-iconbox').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 15,
        watchOverflow: true,
        pagination: { el: qs('.sw-pagination-iconbox', el), clickable: true },
        breakpoints: {
          576: { slidesPerView: 2, spaceBetween: 15 },
          992: { slidesPerView: 4, spaceBetween: 20 }
        }
      });
    });

    qsa('.ks-home-deals .tf-sw-products').forEach(function (el) {
      var section = el.closest('section');
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 15,
        watchOverflow: true,
        navigation: {
          nextEl: section ? qs('.nav-next-products', section) : null,
          prevEl: section ? qs('.nav-prev-products', section) : null
        },
        pagination: { el: qs('.sw-pagination-products', el), clickable: true },
        breakpoints: {
          576: { slidesPerView: 2, spaceBetween: 15 },
          992: { slidesPerView: 3, spaceBetween: 20 },
          1200: { slidesPerView: 4, spaceBetween: 30 }
        }
      });
    });

    qsa('.ks-home-best-section .tf-sw-products,.ks-home-recent-section .tf-sw-products,.ks-home-brands.swiper').forEach(function (el) {
      var section = el.closest('section') || document;
      var isBrand = el.classList.contains('ks-home-brands');
      initSwiper(el, {
        slidesPerView: isBrand ? 2 : 2,
        spaceBetween: 15,
        watchOverflow: true,
        navigation: {
          nextEl: qs('.nav-next-products', section),
          prevEl: qs('.nav-prev-products', section)
        },
        pagination: { el: qs('.sw-pagination-products,.ks-home-brands-pagination', section), clickable: true },
        breakpoints: {
          576: { slidesPerView: isBrand ? 3 : 3, spaceBetween: 15 },
          992: { slidesPerView: isBrand ? 4 : 4, spaceBetween: 20 },
          1200: { slidesPerView: isBrand ? 6 : 5, spaceBetween: 30 }
        }
      });
    });
  }

  function initDepartmentsMenu() {
    var root = qs('.ks-home-departments');
    if (!root || root.getAttribute('data-ks-home-menu-bound') === '1') return;
    root.setAttribute('data-ks-home-menu-bound', '1');

    function isDesktop() {
      return !window.matchMedia || window.matchMedia('(min-width: 1200px)').matches;
    }

    function closeItem(item) {
      if (!item) return;
      item.classList.remove('is-open', 'is-hover');
      item.setAttribute('data-ks-open', '0');
      var btn = qs('[data-ks-toggle="1"]', item);
      var sub = qs('[data-ks-submenu="1"]', item);
      if (btn) btn.setAttribute('aria-expanded', 'false');
      if (sub) {
        sub.setAttribute('aria-hidden', 'true');
        sub.setAttribute('data-ks-inline-state', 'closed');
      }
    }

    function openItem(item) {
      if (!item) return;
      qsa('[data-ks-menu-item="1"]', root).forEach(function (other) {
        if (other !== item) closeItem(other);
      });
      item.classList.add('is-open', 'is-hover');
      item.setAttribute('data-ks-open', '1');
      var btn = qs('[data-ks-toggle="1"]', item);
      var sub = qs('[data-ks-submenu="1"]', item);
      if (btn) btn.setAttribute('aria-expanded', 'true');
      if (sub) {
        sub.hidden = false;
        sub.setAttribute('aria-hidden', 'false');
        sub.setAttribute('data-ks-inline-state', 'open');
      }
    }

    qsa('[data-ks-menu-item="1"]', root).forEach(function (item) {
      item.addEventListener('mouseenter', function () {
        if (isDesktop()) openItem(item);
      });
      item.addEventListener('mouseleave', function () {
        if (isDesktop()) closeItem(item);
      });
      var btn = qs('[data-ks-toggle="1"]', item);
      if (btn) {
        btn.addEventListener('click', function (ev) {
          ev.preventDefault();
          if (item.classList.contains('is-open')) closeItem(item);
          else openItem(item);
        });
      }
    });

    document.addEventListener('click', function (ev) {
      if (!root.contains(ev.target)) {
        qsa('[data-ks-menu-item="1"]', root).forEach(closeItem);
      }
    });
  }

  // This guide prepares catalog navigation only; it never retrieves offers or stores queries.
  function initShoppingGuide() {
    var root = document.getElementById('KsLocalAiSearch130');
    if (!root || root.getAttribute('data-ks-guide-bound') === '1') return;

    var fields = qs('[data-ks-guide-fields]', root);
    var input = qs('#ksGuideQuery', root);
    var detail = qs('#ksGuideDetail', root);
    var summary = qs('[data-ks-guide-summary]', root);
    var idle = qs('[data-ks-guide-idle]', root);
    var status = qs('[data-ks-guide-status]', root);
    var catalog = qs('[data-ks-guide-catalog]', root);
    var prepare = qs('[data-ks-guide-prepare]', root);
    var reset = qs('[data-ks-guide-reset]', root);
    var edit = qs('[data-ks-guide-edit]', root);
    if (!fields || !input || !detail || !summary || !idle || !status || !catalog || !prepare || !reset || !edit || !window.URL) return;

    var base = new URL('articoli.aspx', window.location.href);
    if (base.origin !== window.location.origin) return;
    var choices = qsa('[data-ks-guide-department]', root);
    var department = null;

    function clean(value) {
      return String(value || '').replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
    }

    function readDepartment(button) {
      var raw = button.getAttribute('data-ks-guide-department');
      if (raw === '') return null;
      // Only exact server-rendered sector links may provide the optional st filter.
      if (!/^articoli\.aspx\?st=[1-9][0-9]{0,9}$/.test(raw || '')) return false;
      var url = new URL(raw, window.location.href);
      if (url.origin !== base.origin || url.pathname !== base.pathname || Number(url.searchParams.get('st')) > 2147483647) return false;
      return { id: url.searchParams.get('st'), label: clean(button.textContent) };
    }

    function invalidate() {
      summary.hidden = true;
      idle.hidden = false;
      catalog.setAttribute('href', base.pathname);
      status.textContent = '';
      qs('[data-ks-guide-request]', root).textContent = '';
      qs('[data-ks-guide-scope]', root).textContent = '';
      qs('[data-ks-guide-question]', root).textContent = '';
      input.setAttribute('aria-describedby', 'ksGuideLimit');
      input.removeAttribute('aria-invalid');
      detail.removeAttribute('aria-invalid');
    }

    function prepareSearch() {
      invalidate();
      var request = clean(input.value);
      var extra = clean(detail.value);
      var query = clean(request + ' ' + extra);
      if (request.length < 2 || query.length > 80) {
        status.textContent = request.length < 2 ? 'Scrivi almeno 2 caratteri per indicare il prodotto.' : 'Accorcia la richiesta: prodotto e dettaglio possono contenere al massimo 80 caratteri in tutto.';
        input.setAttribute('aria-invalid', 'true');
        input.setAttribute('aria-describedby', 'ksGuideLimit ksGuideStatus');
        if (query.length > 80) detail.setAttribute('aria-invalid', 'true');
        input.focus();
        return;
      }
      var url = new URL(base.href);
      url.searchParams.set('q', query);
      if (department) url.searchParams.set('st', department.id);
      catalog.setAttribute('href', url.pathname + url.search);
      qs('[data-ks-guide-request]', root).textContent = query;
      qs('[data-ks-guide-scope]', root).textContent = department ? 'Reparto: ' + department.label : 'Tutti i reparti del negozio';
      qs('[data-ks-guide-question]', root).textContent = query.split(' ').length < 3 && !extra ?
        'Vuoi precisare un utilizzo o una caratteristica? Puoi modificare la richiesta oppure cercare così.' :
        'Puoi modificare la richiesta o cercare nel catalogo. I risultati saranno verificati lì.';
      idle.hidden = true;
      summary.hidden = false;
      qs('[data-ks-guide-summary-title]', root).focus();
    }

    choices.forEach(function (button) {
      var candidate = readDepartment(button);
      if (candidate === false) {
        button.disabled = true;
        button.hidden = true;
        return;
      }
      button.addEventListener('click', function () {
        department = candidate;
        choices.forEach(function (other) { other.setAttribute('aria-pressed', other === button ? 'true' : 'false'); });
        invalidate();
      });
    });
    prepare.addEventListener('click', prepareSearch);
    edit.addEventListener('click', function () { invalidate(); input.focus(); });
    reset.addEventListener('click', function () {
      input.value = '';
      detail.value = '';
      department = null;
      choices.forEach(function (button) {
        button.setAttribute('aria-pressed', button.getAttribute('data-ks-guide-department') === '' ? 'true' : 'false');
      });
      invalidate();
      input.focus();
    });
    [input, detail].forEach(function (field) {
      field.addEventListener('input', invalidate);
      field.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter' && !ev.isComposing && ev.keyCode !== 229) {
          ev.preventDefault();
          prepareSearch();
        }
      });
    });
    // Do not reuse rememberSearch or the legacy mode=ai endpoint.
    root.setAttribute('data-ks-guide-bound', '1');
    status.id = 'ksGuideStatus';
    fields.disabled = false;
    fields.hidden = false;
    var fallbackDepartments = qs('.ks-guide-fallback-departments', root);
    if (fallbackDepartments) fallbackDepartments.hidden = true;
  }

  function initHome() {
    if (!isHome()) return;
    if (document.body) {
      document.body.classList.add('ks-home-main');
    }
    initHomeSwipers();
    initDepartmentsMenu();
    initShoppingGuide();
    try {
      if (window.KeepStoreRecentlyViewed && typeof window.KeepStoreRecentlyViewed.render === 'function') {
        window.KeepStoreRecentlyViewed.render('HomeRecentlyViewedSection');
      }
    } catch (ignore) {}
  }

  ready(initHome);
  window.addEventListener('resize', function () {
    window.clearTimeout(window.__ksHomeResizeTimer);
    window.__ksHomeResizeTimer = window.setTimeout(initHome, 180);
  });
})();
