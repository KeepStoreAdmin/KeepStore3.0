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

  function isHome() {
    return !!document.body && (document.body.classList.contains('ks-page-home') || !!qs('.ks-home-hero-section'));
  }

  function initSwiper(el, options) {
    if (!el || typeof window.Swiper === 'undefined') return null;
    if (el.swiper) {
      try { el.swiper.update(); } catch (ignore) {}
      return el.swiper;
    }
    try {
      return new window.Swiper(el, options || {});
    } catch (err) {
      if (window.console && console.warn) console.warn('[KeepStore home] Swiper init error', err);
      return null;
    }
  }

  function initHomeSwipers() {
    qsa('.ks-home-hero-slider').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 1,
        loop: qsa('.swiper-slide', el).length > 1,
        speed: 650,
        autoplay: qsa('.swiper-slide', el).length > 1 ? { delay: 5200, disableOnInteraction: false } : false,
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

    qsa('.ks-home-deal-section .tf-sw-products').forEach(function (el) {
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

    qsa('.ks-home-best-section .tf-sw-products,.ks-home-recent-section .tf-sw-products,.ks-home-brands').forEach(function (el) {
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
        pagination: { el: qs('.sw-pagination-products,.ks-home-brands-pagination', el), clickable: true },
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
    if (!root || root.getAttribute('data-ks-final-menu-bound') === '1') return;
    root.setAttribute('data-ks-final-menu-bound', '1');

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

  function storageJson(key) {
    try {
      var raw = window.localStorage ? window.localStorage.getItem(key) : '';
      return raw ? JSON.parse(raw) : null;
    } catch (err) {
      return null;
    }
  }

  function rememberSearch(value) {
    var query = String(value || '').replace(/\s+/g, ' ').trim();
    if (query.length < 2) return;
    try {
      var list = storageJson('ks_ai_recent_searches') || [];
      if (!Array.isArray(list)) list = [];
      list = list.filter(function (item) { return String(item || '').toLowerCase() !== query.toLowerCase(); });
      list.unshift(query);
      window.localStorage.setItem('ks_ai_recent_searches', JSON.stringify(list.slice(0, 12)));
    } catch (ignore) {}
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }

  function searchEndpoint(query) {
    var url = new URL('/search_suggest.aspx', window.location.href);
    url.searchParams.set('mode', 'ai');
    url.searchParams.set('limit', '8');
    url.searchParams.set('q', query || '');
    return url.toString();
  }

  function renderAiCard(item, index) {
    var image = item.image || item.image_fallback || '';
    var meta = [item.brand, item.category, item.code ? 'Cod. ' + item.code : ''].filter(Boolean).join(' - ');
    return '<a class="ks-ai130-card" href="' + escapeHtml(item.url || '#') + '">' +
      '<span class="ks-ai130-rank">' + (index + 1) + '</span>' +
      '<span class="ks-ai130-img">' + (image ? '<img src="' + escapeHtml(image) + '" alt="' + escapeHtml(item.title || '') + '" loading="lazy" decoding="async">' : '') + '</span>' +
      '<span class="ks-ai130-copy">' +
        '<em>' + escapeHtml(meta || 'Catalogo KeepStore') + '</em>' +
        '<strong>' + escapeHtml(item.title || 'Prodotto KeepStore') + '</strong>' +
        '<small>' + escapeHtml(item.reason || 'Risultato ordinato per pertinenza.') + '</small>' +
        (item.price ? '<b>' + escapeHtml(item.price) + '</b>' : '') +
      '</span>' +
    '</a>';
  }

  function initLocalAiSearch() {
    var root = document.getElementById('KsLocalAiSearch130');
    if (!root || root.getAttribute('data-ks-ai-bound') === '1') return;
    root.setAttribute('data-ks-ai-bound', '1');

    var input = qs('.ks-ai130-form input', root);
    var button = qs('.ks-ai130-form button', root);
    var results = qs('.ks-ai130-results', root);
    var answer = qs('.ks-ai130-answer p', root);
    var count = qs('[data-ks-ai-count]', root);
    var timer = 0;
    var controller = null;

    function catalogLink(query) {
      return '<a class="ks-ai130-catalog-link" href="articoli.aspx?q=' + encodeURIComponent(query || '') + '">Vedi risultati nel catalogo</a>';
    }

    function renderEmpty(message, query) {
      if (results) {
        results.innerHTML = '<div class="ks-ai130-empty">' + escapeHtml(message) + '<br>' + catalogLink(query || '') + '</div>';
      }
    }

    function runSearch(raw) {
      var query = String(raw || '').replace(/\s+/g, ' ').trim();
      if (query.length < 2) {
        if (answer) answer.textContent = 'Scrivi una richiesta: cerco nel catalogo reale per codice, EAN, marca, descrizione e categoria.';
        renderEmpty('Inserisci almeno 2 caratteri per cercare nel catalogo.', query);
        return;
      }

      rememberSearch(query);
      if (controller && controller.abort) {
        try { controller.abort(); } catch (ignore) {}
      }
      controller = window.AbortController ? new AbortController() : null;
      if (answer) answer.textContent = 'Sto confrontando la richiesta con i dati reali del catalogo KeepStore.';
      if (count) count.textContent = 'Ricerca catalogo...';
      if (results) results.innerHTML = '<div class="ks-ai130-empty">Analisi catalogo in corso...</div>';

      fetch(searchEndpoint(query), {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' },
        signal: controller ? controller.signal : undefined
      }).then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      }).then(function (data) {
        var items = data && data.suggestions ? data.suggestions : [];
        if (answer) answer.textContent = data && data.intelligence && data.intelligence.summary ? data.intelligence.summary : 'Risultati ordinati per compatibilita con la richiesta.';
        if (count) count.textContent = items.length ? items.length + ' risultati dal catalogo' : 'Nessun articolo compatibile';
        if (items.length) {
          results.innerHTML = items.map(renderAiCard).join('') + '<div class="ks-ai130-catalog-row">' + catalogLink(query) + '</div>';
        } else {
          renderEmpty('Nessun articolo supera la soglia di pertinenza per questa richiesta.', query);
        }
      }).catch(function (err) {
        if (err && err.name === 'AbortError') return;
        if (window.console && console.warn) console.warn('[KeepStore AI]', err);
        if (count) count.textContent = 'Catalogo non disponibile';
        renderEmpty('Errore temporaneo durante la ricerca catalogo.', query);
      });
    }

    if (button) {
      button.addEventListener('click', function (ev) {
        ev.preventDefault();
        runSearch(input ? input.value : '');
      });
    }
    if (input) {
      input.addEventListener('input', function () {
        if (timer) window.clearTimeout(timer);
        timer = window.setTimeout(function () { runSearch(input.value); }, 360);
      });
      input.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter') {
          ev.preventDefault();
          if (timer) window.clearTimeout(timer);
          runSearch(input.value);
        }
      });
    }
    qsa('.ks-ai130-examples button', root).forEach(function (example) {
      example.addEventListener('click', function () {
        var value = String(example.textContent || '').replace(/\s+/g, ' ').trim();
        if (input) input.value = value;
        runSearch(value);
      });
    });
  }

  function initHome() {
    if (!isHome()) return;
    if (document.body) {
      document.body.classList.add('ks-home-onsus-final');
    }
    initHomeSwipers();
    initDepartmentsMenu();
    initLocalAiSearch();
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
