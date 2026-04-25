(function () {
  'use strict';

  window.KS_HOME_SERVER_RENDERED = true;

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }

  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function isHome() {
    return !!document.body && (document.body.classList.contains('ks-page-home') || !!document.querySelector('.ks-home-hero-section'));
  }

  function initSwiper(el, options) {
    if (!el || !window.Swiper || el.swiper) return;
    try { new window.Swiper(el, options || {}); } catch (err) {}
  }

  function initSwipers() {
    qa('.ks-home-hero-slider').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 1,
        loop: el.querySelectorAll('.swiper-slide').length > 1,
        speed: 600,
        navigation: {
          nextEl: el.querySelector('.ks-hero-next'),
          prevEl: el.querySelector('.ks-hero-prev')
        },
        pagination: {
          el: el.querySelector('.ks-hero-pagination'),
          clickable: true
        }
      });
    });

    qa('.tf-sw-iconbox').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 15,
        breakpoints: {
          576: { slidesPerView: 2, spaceBetween: 15 },
          992: { slidesPerView: 4, spaceBetween: 20 }
        },
        pagination: {
          el: el.querySelector('.sw-pagination-iconbox'),
          clickable: true
        }
      });
    });

    qa('.ks-home-deal-section .tf-sw-products').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 15,
        breakpoints: {
          576: { slidesPerView: 2, spaceBetween: 15 },
          992: { slidesPerView: 3, spaceBetween: 20 },
          1200: { slidesPerView: 4, spaceBetween: 30 }
        },
        navigation: {
          nextEl: document.querySelector('.ks-home-deal-section .nav-next-products'),
          prevEl: document.querySelector('.ks-home-deal-section .nav-prev-products')
        },
        pagination: {
          el: el.querySelector('.sw-pagination-products'),
          clickable: true
        }
      });
    });

    qa('.ks-home-best-section .tf-sw-products,.ks-home-recent-section .tf-sw-products').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 2,
        spaceBetween: 15,
        breakpoints: {
          576: { slidesPerView: 3, spaceBetween: 15 },
          992: { slidesPerView: 4, spaceBetween: 20 },
          1200: { slidesPerView: 5, spaceBetween: 30 }
        },
        navigation: {
          nextEl: el.closest('section') ? el.closest('section').querySelector('.nav-next-products') : null,
          prevEl: el.closest('section') ? el.closest('section').querySelector('.nav-prev-products') : null
        },
        pagination: {
          el: el.querySelector('.sw-pagination-products'),
          clickable: true
        }
      });
    });

    qa('.ks-home-lower-columns-section .ks-column-swiper').forEach(function (el) {
      var box = el.closest('.tf-grid-product-item');
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 12,
        navigation: {
          nextEl: box ? box.querySelector('.ks-col-next') : null,
          prevEl: box ? box.querySelector('.ks-col-prev') : null
        },
        pagination: {
          el: el.querySelector('.ks-col-pagination'),
          clickable: true
        }
      });
    });

    qa('.ks-home-brands').forEach(function (el) {
      initSwiper(el, {
        slidesPerView: 2,
        spaceBetween: 15,
        breakpoints: {
          576: { slidesPerView: 3, spaceBetween: 15 },
          992: { slidesPerView: 4, spaceBetween: 20 },
          1200: { slidesPerView: 6, spaceBetween: 30 }
        },
        pagination: {
          el: el.querySelector('.ks-home-brands-pagination'),
          clickable: true
        }
      });
    });
  }

  function bindDepartmentsMenu() {
    var root = document.querySelector('.ks-home-departments');
    if (!root || root.getAttribute('data-ks-menu-bound') === '1') return;
    root.setAttribute('data-ks-menu-bound', '1');
    var closeTimer = 0;
    function desktopMenu() {
      return !window.matchMedia || window.matchMedia('(min-width: 1200px)').matches;
    }
    function clearCloseTimer() {
      if (closeTimer) {
        window.clearTimeout(closeTimer);
        closeTimer = 0;
      }
    }
    function setItemOpen(item, open) {
      if (!item) return;
      item.setAttribute('data-ks-open', open ? '1' : '0');
      item.classList.toggle('is-open', open);
      item.classList.toggle('is-hover', open);
      var toggle = item.querySelector('[data-ks-toggle="1"]');
      var submenu = item.querySelector('[data-ks-submenu="1"]');
      if (toggle) toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      if (submenu) {
        submenu.setAttribute('aria-hidden', open ? 'false' : 'true');
        submenu.setAttribute('data-ks-inline-state', open ? 'open' : 'closed');
      }
    }
    function closeSiblings(item) {
      var list = item && item.parentNode;
      if (!list) return;
      qa('[data-ks-menu-item="1"]', list).forEach(function (sibling) {
        if (sibling !== item) setItemOpen(sibling, false);
      });
    }
    function closeAll(except) {
      qa('[data-ks-menu-item="1"]', root).forEach(function (item) {
        if (item !== except) setItemOpen(item, false);
      });
    }
    function openItem(item) {
      if (!item || !item.querySelector('[data-ks-submenu="1"]')) return;
      clearCloseTimer();
      closeAll(item);
      setItemOpen(item, true);
    }
    function closeItemSoon(item) {
      clearCloseTimer();
      closeTimer = window.setTimeout(function () {
        setItemOpen(item, false);
      }, 120);
    }
    function toggleItem(item) {
      if (!item) return;
      var nextOpen = item.getAttribute('data-ks-open') !== '1';
      closeAll(item);
      setItemOpen(item, nextOpen);
    }
    qa('[data-ks-toggle="1"],[data-ks-menu-row="1"]', root).forEach(function (btn) {
      if (btn.getAttribute('data-ks-bound') === '1') return;
      btn.setAttribute('data-ks-bound', '1');
      btn.addEventListener('click', function (event) {
        var item = btn.closest('[data-ks-menu-item="1"]');
        if (!item || !item.querySelector('[data-ks-submenu="1"]')) return;
        event.preventDefault();
        event.stopPropagation();
        toggleItem(item);
      });
      btn.addEventListener('focus', function () {
        var item = btn.closest('[data-ks-menu-item="1"]');
        if (desktopMenu()) openItem(item);
      });
    });
    qa('[data-ks-menu-item="1"]', root).forEach(function (item) {
      if (item.getAttribute('data-ks-hover-bound') === '1') return;
      item.setAttribute('data-ks-hover-bound', '1');
      item.addEventListener('mouseenter', function () {
        if (desktopMenu()) openItem(item);
      });
      item.addEventListener('mouseover', function () {
        if (desktopMenu()) openItem(item);
      });
      item.addEventListener('mouseleave', function () {
        if (desktopMenu()) closeItemSoon(item);
      });
      var submenu = item.querySelector('[data-ks-submenu="1"]');
      if (submenu) {
        submenu.addEventListener('mouseenter', function () {
          if (desktopMenu()) openItem(item);
        });
        submenu.addEventListener('mouseleave', function () {
          if (desktopMenu()) closeItemSoon(item);
        });
      }
    });
    document.addEventListener('click', function (event) {
      if (!root.contains(event.target)) closeAll(null);
    });
    window.addEventListener('resize', function () {
      closeAll(null);
    });
  }

  function initLocalAiSearch() {
    var root = document.getElementById('KsLocalAiSearch130');
    if (!root || root.getAttribute('data-ks-ai-bound') === '1') return;
    root.setAttribute('data-ks-ai-bound', '1');
    if (document.body) document.body.classList.add('ks-home-onsus-pass-130');

    function q(sel, ctx) { return (ctx || document).querySelector(sel); }
    function text(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
    function esc(value) {
      return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
        return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
      });
    }
    var currentController = null;
    function endpointUrl(queryText) {
      var u = new URL('/search_suggest.aspx', window.location.href);
      u.searchParams.set('mode', 'ai');
      u.searchParams.set('limit', '8');
      u.searchParams.set('q', queryText || '');
      return u.toString();
    }
    function fetchJsonTimed(url, timeoutMs) {
      var ctrl = window.AbortController ? new AbortController() : null;
      var timer = 0;
      if (currentController && currentController.abort) {
        try { currentController.abort(); } catch (err) {}
      }
      currentController = ctrl;
      if (ctrl) {
        timer = window.setTimeout(function () {
          try { ctrl.abort(); } catch (err) {}
        }, timeoutMs || 5200);
      }
      return fetch(url, {
        credentials: 'same-origin',
        headers: { 'Accept': 'application/json' },
        signal: ctrl ? ctrl.signal : undefined
      }).then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      }).finally(function () {
        if (timer) window.clearTimeout(timer);
      });
    }
    function priceText(item) {
      return item && item.price ? '&euro;' + esc(item.price) : '';
    }
    function metaText(item) {
      var bits = [];
      if (item.brand) bits.push(esc(item.brand));
      if (item.category) bits.push(esc(item.category));
      if (item.code) bits.push('Cod. ' + esc(item.code));
      if (item.ean) bits.push('EAN ' + esc(item.ean));
      return bits.join(' - ');
    }
    function badgeHtml(item) {
      var badges = item && item.badges ? item.badges.slice(0, 3) : [];
      if (item && item.isRefurbished && badges.indexOf('Ricondizionato') < 0) badges.unshift('Ricondizionato');
      return badges.length ? '<span class="ks-ai130-badges">' + badges.map(function (b) { return '<i>' + esc(b) + '</i>'; }).join('') + '</span>' : '';
    }
    function renderCard(item, idx) {
      var img = item.image || item.image_fallback || '';
      return '<a class="ks-ai130-card" href="' + esc(item.url || '#') + '">' +
        '<span class="ks-ai130-rank">' + (idx + 1) + '</span>' +
        '<span class="ks-ai130-img">' + (img ? '<img src="' + esc(img) + '" alt="' + esc(item.title || '') + '" loading="lazy" decoding="async">' : '') + '</span>' +
        '<span class="ks-ai130-copy">' +
          '<em>' + esc(metaText(item) || 'Catalogo KeepStore') + '</em>' +
          '<strong>' + esc(item.title || 'Prodotto KeepStore') + '</strong>' +
          '<small>' + esc(item.reason || 'Trovato per compatibilita con la richiesta.') + '</small>' +
          badgeHtml(item) +
          (item.price ? '<b>' + priceText(item) + '</b>' : '') +
        '</span>' +
        '</a>';
    }
    var input = q('.ks-ai130-form input', root);
    var form = q('.ks-ai130-form', root);
    var submitButton = q('.ks-ai130-form button', root);
    var answer = q('.ks-ai130-answer p', root);
    var lamp = q('.ks-ai130-answer i', root);
    var results = q('.ks-ai130-results', root);
    var count = q('[data-ks-ai-count]', root);
    if (count) count.textContent = 'Catalogo articoli';
    function catalogLink(queryText, data) {
      var url = data && data.catalogUrl ? data.catalogUrl : ('articoli.aspx?q=' + encodeURIComponent(queryText || ''));
      return '<a class="ks-ai130-catalog-link" href="' + esc(url) + '">Vedi risultati nel catalogo</a>';
    }
    function renderEmpty(queryText, message, data) {
      if (results) {
        results.innerHTML = '<div class="ks-ai130-empty">' + esc(message) + '<br><small>Prova con codice, marca, reparto o caratteristica tecnica.</small>' + catalogLink(queryText, data) + '</div>';
      }
    }
    function runQuery(queryText) {
      var value = String(queryText || '').replace(/\s+/g, ' ').trim();
      if (value.length < 2) {
        if (lamp) lamp.setAttribute('data-intent', 'catalogo');
        if (answer) answer.textContent = 'Scrivi una richiesta naturale: interrogo il catalogo articoli KeepStore, non solo i prodotti visibili nella home.';
        renderEmpty(value, 'Inserisci almeno 2 caratteri per cercare nel catalogo.', null);
        return;
      }
      if (count) count.textContent = 'Ricerca catalogo...';
      if (answer) answer.textContent = 'Sto confrontando la richiesta con codice, EAN, descrizioni, marca, reparto e categoria.';
      if (results) results.innerHTML = '<div class="ks-ai130-empty">Analisi catalogo in corso...</div>';
      fetchJsonTimed(endpointUrl(value), 6200).then(function (data) {
        if (!data || data.ok === false) {
          if (data && data.error && window.console) console.warn('[KeepStore AI]', data.error);
          renderEmpty(value, 'Non riesco a leggere il catalogo in questo momento.', data);
          if (count) count.textContent = 'Catalogo non disponibile';
          return;
        }
        var items = data.suggestions || [];
        if (lamp && data.intelligence) lamp.setAttribute('data-intent', data.intelligence.intent || 'catalogo');
        if (answer) answer.textContent = data.intelligence && data.intelligence.summary ? data.intelligence.summary : 'Risultati ordinati per compatibilita con la richiesta.';
        if (count) count.textContent = items.length ? (items.length + ' risultati dal catalogo') : 'Nessun articolo compatibile';
        if (items.length) {
          results.innerHTML = items.map(renderCard).join('') + '<div class="ks-ai130-catalog-row">' + catalogLink(value, data) + '</div>';
        } else {
          renderEmpty(value, 'Nessun articolo supera la soglia di pertinenza per questa richiesta.', data);
        }
      }).catch(function (err) {
        if (err && err.name === 'AbortError') return;
        if (window.console) console.warn('[KeepStore AI]', err && err.message ? err.message : err);
        if (count) count.textContent = 'Catalogo non disponibile';
        if (answer) answer.textContent = 'La ricerca catalogo non ha risposto. Puoi comunque aprire i risultati nel catalogo.';
        renderEmpty(value, 'Errore temporaneo durante la ricerca catalogo.', null);
      });
    }
    var inputTimer = 0;
    function queueQuery() {
      if (!input) return;
      var value = String(input.value || '').replace(/\s+/g, ' ').trim();
      if (inputTimer) window.clearTimeout(inputTimer);
      if (value.length < 2) return;
      inputTimer = window.setTimeout(function () {
        runQuery(value);
      }, 360);
    }
    if (form && String(form.tagName || '').toLowerCase() === 'form') {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        runQuery(input ? input.value : '');
      });
    }
    if (submitButton) {
      submitButton.addEventListener('click', function (event) {
        event.preventDefault();
        runQuery(input ? input.value : '');
      });
    }
    if (input) {
      input.addEventListener('input', queueQuery);
      input.addEventListener('keydown', function (event) {
        if (event.key === 'Enter') {
          event.preventDefault();
          if (inputTimer) window.clearTimeout(inputTimer);
          runQuery(input.value);
        }
      });
    }
    qa('.ks-ai130-examples button', root).forEach(function (button) {
      button.addEventListener('click', function () {
        if (input) input.value = text(button);
        runQuery(text(button));
      });
    });
    renderEmpty('', 'Scrivi una richiesta o scegli un esempio: usero il catalogo articoli reale.', null);
  }

  ready(function () {
    if (!isHome()) return;
    document.body.classList.add('ks-home-server-rendered');
    initSwipers();
    bindDepartmentsMenu();
    initLocalAiSearch();
    window.setTimeout(initLocalAiSearch, 450);
    window.setTimeout(initLocalAiSearch, 1200);
  });
})();

if (!window.KS_HOME_SERVER_RENDERED) {
(function () {
  'use strict';

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }

  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function bySuffix(id, root) { return q('[id$=\"' + id + '\"]', root || document); }
  function first(selectors, root) {
    for (var i = 0; i < selectors.length; i++) {
      var n = q(selectors[i], root || document);
      if (n) return n;
    }
    return null;
  }
  function hasIdSuffix(node, suffix) { return !!node && String(node.id || '').slice(-suffix.length) === suffix; }
  function txt(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function home() { return !!document.body && (document.body.classList.contains('ks-page-home') || !!first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]'])); }
  function safe(name, fn) { try { return fn(); } catch (e) { try { console.warn('[KeepStore HOME]', name, e); } catch (_) {} return null; } }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }

  function normalizeUrl(url) {
    url = String(url || '').trim();
    if (!url) return '';
    url = url.replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '');
    return url.replace(/&amp;/g, '&');
  }

  function productId(url) {
    var m = String(url || '').match(/[?&]id=(\d+)/i);
    return m ? m[1] : normalizeUrl(url);
  }

  function cleanTitle(value) {
    return String(value || '')
      .replace(/\s+/g, ' ')
      .replace(/^(categoria|catalogo|supporto|spedizione|pagamenti|garanzia|home)\s*/i, '')
      .trim();
  }

  function familyKey(title) {
    return String(title || '').toLowerCase()
      .replace(/\b(nero|black|bianco|white|rosso|red|blu|blue|verde|green|rosa|pink|grigio|grey|silver|oro|gold|trasparente|clear)\b/g, ' ')
      .replace(/\b(custodia|cover|case|pellicola|vetro|glass|protezione|protettiva|magnetico|magnetica|silicone|tpu|gel|bordo|bordi)\b/g, ' ')
      .replace(/\b(compatibile|specifico|universale|originale|premium|professionale|ricondizionato|ricondizionata|completo|completa)\b/g, ' ')
      .replace(/\b\d+(?:[\.,]\d+)?\s?(gb|tb|mb|mm|cm|m|w|v|a|mah|hz|inch|pollici|usb|type c|tipo c)\b/g, ' ')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .split(' ')
      .slice(0, 8)
      .join(' ');
  }

  function readImage(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src) continue;
      if (/logo|brand|payment|visa|mastercard|paypal|nofoto|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }

  function readPrice(root) {
    var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
    return m && m.length ? m[m.length - 1] : '';
  }

  function readCategory(root) {
    var n = q('.category,.caption,.font-2,.text-main-2,.type,.brand', root);
    var t = txt(n);
    return t && t.length < 38 && !/€/.test(t) ? t : '';
  }

  function productRoot(link) {
    return link.closest('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.product-item,.product-card,li,.swiper-slide,.box-product') || link.parentElement;
  }

  function linkTitle(link, root) {
    var candidates = [
      q('.name-product a', root), q('.product-title a', root), q('h6 a', root), q('h5 a', root), q('.title a', root), link
    ];
    for (var i = 0; i < candidates.length; i++) {
      var t = cleanTitle(txt(candidates[i]));
      if (t.length >= 4 && !/^(scopri|vai al catalogo|categoria|compra)$/i.test(t)) return t;
    }
    return '';
  }

  function productLinks(root) {
    return qa('a[href*="articolo.aspx?id="],a[href*="articolo.aspx?Id="],a[href*="articolo.aspx?ID="]', root || document).filter(function (a) {
      return !!a && !a.closest('header,footer,.ks-home-brands-block,[id$=\"HomeBrandsSection\"],#KsHomeDepartmentShowcase,#KsHomeClosingLayer,.ks-home-final-rendered');
    });
  }

  function newState() { return { ids: Object.create(null), urls: Object.create(null), families: Object.create(null) }; }
  function markProduct(state, p) {
    if (!state || !p) return;
    if (p.id) state.ids[p.id] = 1;
    if (p.href) state.urls[p.href] = 1;
    if (p.family) state.families[p.family] = 1;
  }
  function isUsed(state, p) {
    return !!(state && p && ((p.id && state.ids[p.id]) || (p.href && state.urls[p.href]) || (p.family && state.families[p.family])));
  }

  function collectFrom(root, state, limit) {
    var out = [];
    if (!root) return out;
    productLinks(root).forEach(function (link) {
      if (limit && out.length >= limit) return;
      var href = normalizeUrl(link.getAttribute('href'));
      var id = productId(href);
      var card = productRoot(link);
      if (!href || !card) return;
      var title = linkTitle(link, card);
      var img = readImage(card);
      if (!title || !img) return;
      var p = { id: id, href: href, img: img, title: title, category: readCategory(card), price: readPrice(card), family: familyKey(title) };
      if (isUsed(state, p)) return;
      markProduct(state, p);
      out.push(p);
    });
    return out;
  }

  function collectMany(roots, state, limit) {
    var out = [];
    (roots || []).forEach(function (root) {
      if (limit && out.length >= limit) return;
      collectFrom(root, state, limit ? limit - out.length : 0).forEach(function (p) { out.push(p); });
    });
    return out;
  }

  function cardHtml(p, compact) {
    return '<article class="ks-final-product-card' + (compact ? ' ks-final-product-card--compact' : '') + '">' +
      '<a class="ks-final-product-media" href="' + esc(p.href) + '"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></a>' +
      '<div class="ks-final-product-info">' +
      (p.category ? '<p class="ks-final-product-cat">' + esc(p.category) + '</p>' : '') +
      '<h6><a href="' + esc(p.href) + '">' + esc(p.title) + '</a></h6>' +
      (p.price ? '<p class="ks-final-product-price">' + esc(p.price) + '</p>' : '') +
      '</div></article>';
  }

  function sectionTitle(kicker, title, linkText) {
    return '<div class="flat-title ks-final-title"><div><span class="ks-section-kicker">' + esc(kicker) + '</span><h5 class="fw-semibold">' + esc(title) + '</h5></div>' +
      '<a class="ks-home-section-link" href="articoli.aspx">' + esc(linkText || 'Vai al catalogo') + '</a></div>';
  }

  function ensureSection(id, className) {
    var node = q('#' + id) || document.createElement('section');
    node.id = id;
    node.className = className;
    node.setAttribute('data-ks-final-home', '1');
    return node;
  }

  function insertAfter(ref, node) {
    if (!ref || !node || !ref.parentNode) return;
    if (ref.nextElementSibling !== node) ref.parentNode.insertBefore(node, ref.nextSibling);
  }

  function insertBefore(ref, node) {
    if (!ref || !node || !ref.parentNode) return;
    if (ref.previousElementSibling !== node) ref.parentNode.insertBefore(node, ref);
  }

  function show(node) {
    if (!node) return;
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
    if (node.style) {
      node.style.removeProperty('display');
      node.style.removeProperty('visibility');
      node.style.removeProperty('opacity');
      node.style.removeProperty('height');
      node.style.removeProperty('min-height');
      node.style.removeProperty('max-height');
      node.style.removeProperty('overflow');
    }
  }

  function hide(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-final-source-hidden', reason || 'final');
    if (node.style) node.style.setProperty('display', 'none', 'important');
  }

  function forceHeroLayout() {
    var section = first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']);
    var shell = first(['.ks-home-hero-shell','[id$=\"HomeHeroShell\"]'], section);
    if (!section || !shell) return;
    show(section); show(shell);
    section.classList.add('ks-final-hero-section');
    shell.classList.add('ks-final-hero-shell');
    var menu = q('.wrap-item-1', shell);
    var hero = first(['.wrap-item-2','[id$=\"HeroSliderWrap\"]'], shell);
    [menu, hero].forEach(show);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', '250px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '18px', 'important');
    shell.style.setProperty('min-height', '340px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    if (menu) {
      menu.style.setProperty('width', '250px', 'important');
      menu.style.setProperty('min-width', '250px', 'important');
      menu.style.setProperty('height', '340px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
      menu.style.setProperty('display', 'block', 'important');
    }
    if (hero) {
      hero.style.setProperty('height', '340px', 'important');
      hero.style.setProperty('min-height', '340px', 'important');
      hero.style.setProperty('width', '100%', 'important');
    }
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,[id$=\"HeroSideWrap\"]', shell).forEach(function (n) { hide(n, 'side-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-slider a', section).forEach(function (n) {
      show(n);
      if (n.style) {
        n.style.setProperty('height', '340px', 'important');
        n.style.setProperty('min-height', '340px', 'important');
        n.style.setProperty('width', '100%', 'important');
      }
    });
    qa('.ks-home-hero-slider img', section).forEach(function (img) {
      show(img);
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'cover', 'important');
      img.style.setProperty('object-position', 'center center', 'important');
      img.style.setProperty('background', '#050505', 'important');
    });
    qa('.ks-home-departments,.menu-category-list', shell).forEach(function (n) {
      n.style.setProperty('height', '340px', 'important');
      n.style.setProperty('max-height', '340px', 'important');
      n.style.setProperty('overflow-y', 'auto', 'important');
    });
  }

  function findIconBoxes() {
    var all = qa('main section, main .tf-sp-2, main .tf-sp-3, main .tf-sp-4');
    for (var i = 0; i < all.length; i++) {
      var t = txt(all[i]).toLowerCase();
      if (t.indexOf('spedizione veloce') >= 0 || t.indexOf('pagamenti sicuri') >= 0 || t.indexOf('supporto dedicato') >= 0) return all[i];
    }
    var hero = first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']);
    return hero ? hero.nextElementSibling : null;
  }

  function initials(title) { title = String(title || '').trim(); return (title ? title.charAt(0) : 'K').toUpperCase(); }

  function collectDepartments() {
    var out = [], seen = Object.create(null);
    function add(title, url, img) {
      title = cleanTitle(title);
      if (!title || title.length < 2 || /^tutti i settori$/i.test(title)) return;
      var key = title.toLowerCase();
      if (seen[key]) return;
      seen[key] = 1;
      out.push({ title: title, url: normalizeUrl(url) || 'articoli.aspx', img: img || '' });
    }
    qa('.ks-home-departments a[href], .menu-category-list a[href]').forEach(function (a) {
      var img = q('img', a);
      add(txt(a), a.getAttribute('href'), img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src')) : '');
    });
    qa('#ksDesktopCategoryMenu a[href], .ks-mobile-catalog-list a[href], footer.tf-footer a[href]').forEach(function (a) {
      if (out.length >= 12) return;
      add(txt(a), a.getAttribute('href'), '');
    });
    return out.slice(0, 12);
  }

  function buildDepartmentsShowcase(anchor) {
    var items = collectDepartments();
    if (items.length < 4) return anchor;
    var section = ensureSection('KsHomeDepartmentShowcase', 'tf-sp-2 ks-home-department-showcase ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle('Catalogo KeepStore', 'Reparti in evidenza') +
      '<div class="ks-department-grid">' + items.map(function (item) {
        var media = item.img ? '<img src="' + esc(item.img) + '" alt="' + esc(item.title) + '">' : '<span>' + esc(initials(item.title)) + '</span>';
        return '<a class="ks-department-card" href="' + esc(item.url) + '"><span class="ks-department-media">' + media + '</span><b>' + esc(item.title) + '</b><small>Scopri</small></a>';
      }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
    return section;
  }

  function buildProductDeck(id, products, kicker, title, anchor, max) {
    products = (products || []).slice(0, max || 10);
    if (products.length < 4) return anchor;
    var section = ensureSection(id, 'tf-sp-2 ks-final-product-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle(kicker, title) +
      '<div class="ks-final-product-grid">' + products.map(function (p) { return cardHtml(p, false); }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
    return section;
  }

  function buildLowerMatrix(products, anchor) {
    products = (products || []).slice(0, 12);
    if (products.length < 9) return anchor;
    var labels = ['Top 20', 'I Più Venduti', 'In Offerta'];
    var section = ensureSection('KsHomeLowerFinal', 'tf-sp-2 ks-final-lower-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle('Proposte KeepStore', 'Altre proposte per te') +
      '<div class="ks-final-lower-grid">' + labels.map(function (label, index) {
        return '<div class="ks-final-lower-column"><h5>' + esc(label) + '</h5><div class="ks-final-lower-list">' + products.slice(index * 4, index * 4 + 4).map(function (p) { return cardHtml(p, true); }).join('') + '</div></div>';
      }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
    return section;
  }

  function buildClosingLayer(anchor) {
    var cats = collectDepartments().slice(0, 8);
    if (cats.length < 4) cats = [
      { title: 'Notebook e computer', url: 'articoli.aspx' }, { title: 'Fotografia e video', url: 'articoli.aspx' },
      { title: 'Smartphone e tablet', url: 'articoli.aspx' }, { title: 'Gaming e console', url: 'articoli.aspx' },
      { title: 'TV e audio', url: 'articoli.aspx' }, { title: 'Accessori tech', url: 'articoli.aspx' },
      { title: 'Audio e cuffie', url: 'articoli.aspx' }, { title: 'Materiale elettrico', url: 'articoli.aspx' }
    ];
    var services = ['Spedizione veloce', 'Supporto dedicato', 'Pagamenti sicuri', 'Affidabilità reale'];
    var section = ensureSection('KsHomeClosingLayer', 'tf-sp-2 ks-home-closing-layer ks-home-final-rendered');
    section.innerHTML = '<div class="container"><div class="ks-home-closing-grid"><div class="ks-home-closing-card"><span class="ks-section-kicker">Catalogo</span><h5>Categorie popolari</h5><div class="ks-home-closing-tags">' +
      cats.map(function (c) { return '<a href="' + esc(c.url) + '"><b>' + esc(c.title) + '</b><small>Categoria</small></a>'; }).join('') +
      '</div></div><div class="ks-home-closing-card"><span class="ks-section-kicker">Acquisto sicuro</span><h5>Servizi KeepStore</h5><div class="ks-home-service-grid">' +
      services.map(function (s) { return '<div><b>' + esc(initials(s)) + '</b><strong>' + esc(s) + '</strong><small>Servizio reale KeepStore</small></div>'; }).join('') +
      '</div></div></div></div>';
    var footer = q('footer.tf-footer') || q('footer');
    if (footer && footer.parentNode) footer.parentNode.insertBefore(section, footer);
    else insertAfter(anchor, section);
    show(section);
    return section;
  }

  function roots() {
    return {
      deal: first(['.ks-home-deal-section','[id$="HomeDealSection"]']),
      editorial: first(['.ks-home-editorial-section','.flat-animate-tab']),
      best: first(['.ks-home-best-section']),
      recent: first(['[id$="HomeRecentlyViewedSection"]','.ks-home-recent-section','.ks-home-chosen-section']),
      lower: first(['[id$="HomeLowerColumnsSection"]','.ks-home-lower-columns-section']),
      brands: first(['[id$="HomeBrandsSection"]','.ks-home-brands-block'])
    };
  }


  function isFinalOrProtectedSection(sec) {
    if (!sec) return true;
    if (sec.classList && (sec.classList.contains('ks-home-final-rendered') || sec.classList.contains('ks-home-hero-section') || sec.classList.contains('ks-home-brands-block'))) return true;
    if (hasIdSuffix(sec, 'HomeHeroSection') || hasIdSuffix(sec, 'HomeBrandsSection')) return true;
    if (/^(KsHomeDepartmentShowcase|KsHomeDealFinal|KsHomeEditorialFinal|KsHomeBestSellerFinal|KsHomeRecentFinal|KsHomeLowerFinal|KsHomeClosingLayer)$/.test(sec.id || '')) return true;
    return false;
  }

  function hideNative(r) {
    ['deal', 'editorial', 'best', 'recent', 'lower'].forEach(function (key) { hide(r[key], 'final-rendered'); });
    qa('main > section').forEach(function (sec) {
      if (isFinalOrProtectedSection(sec)) return;
      if (/Top 20|I Piu|I Più|In Offerta|In Evidenza|Nuovi Arrivi|Best Seller|Occasione|Scelti Da Te/i.test(txt(sec))) hide(sec, 'stray-native');
    });
  }


  function placeBrands(anchor, brandSection) {
    if (!brandSection) return anchor;
    show(brandSection);
    brandSection.classList.add('ks-final-brands');
    insertAfter(anchor, brandSection);
    return brandSection;
  }

  function suppressNewsletter() {
    try { localStorage.setItem('ks_newsletter_shown', '1'); sessionStorage.setItem('ks_newsletter_shown', '1'); } catch (_) {}
    qa('.modal.show,.modal-backdrop.show').forEach(function (n) { if (/newsletter|subscribe/i.test(String(n.id || '') + ' ' + txt(n))) hide(n, 'newsletter-disabled'); });
    document.body.classList.remove('modal-open');
  }

  function normalizeCatalogMenu() {
    var menu = q('#ksDesktopCategoryMenu') || q('.ks-header-catalog-menu') || q('.header-catalog-menu') || q('.menu-catalog');
    if (!menu) return;
    menu.classList.add('ks-catalog-mega-normalized');
    qa('[style]', menu).forEach(function (n) { n.removeAttribute('style'); });
  }

  function initSwiper(el, options) {
    if (!el || typeof window.Swiper === 'undefined') return null;
    if (el.swiper) { try { el.swiper.update(); } catch (_) {} return el.swiper; }
    try { return new window.Swiper(el, options || {}); } catch (_) { return null; }
  }

  function initSliders() {
    var hero = q('.ks-home-hero-slider');
    if (hero) initSwiper(hero, {
      slidesPerView: 1,
      loop: qa('.swiper-slide', hero).length > 1,
      observer: true,
      observeParents: true,
      navigation: { nextEl: '.ks-hero-next', prevEl: '.ks-hero-prev' },
      pagination: { el: '.ks-hero-pagination', clickable: true }
    });
    var brands = q('.ks-home-brands');
    if (brands) initSwiper(brands, {
      slidesPerView: 2,
      spaceBetween: 15,
      observer: true,
      observeParents: true,
      pagination: { el: '.ks-home-brands-pagination', clickable: true },
      breakpoints: { 576: { slidesPerView: 3 }, 768: { slidesPerView: 4 }, 1200: { slidesPerView: 6 } }
    });
  }

  function render() {
    if (!home()) return;
    document.body.classList.add('ks-page-home', 'ks-home-final-onsus', 'ks-home-step110-webforms-fixed', 'ks-home-step111-onsus-stabilized', 'ks-home-step112-hero-fill', 'ks-home-step113-onsus-hard');
    suppressNewsletter();
    normalizeCatalogMenu();
    forceHeroLayout();

    var r = roots();

    // Read server-side pools first, then render ONSUS sections without letting Best Seller consume deal/editorial stock.
    var deal = collectMany([r.deal], newState(), 5);
    var bestRaw = collectMany([r.best], newState(), 5);
    var used = newState();
    deal.forEach(function (p) { markProduct(used, p); });
    bestRaw.forEach(function (p) { markProduct(used, p); });

    var editorial = collectMany([r.editorial, r.lower], used, 10);
    var recent = collectMany([r.recent], used, 5);
    var lower = collectMany([r.lower, r.editorial], used, 12);

    hideNative(r);

    var anchor = buildDepartmentsShowcase(findIconBoxes() || first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']));
    if (deal.length >= 3) anchor = buildProductDeck('KsHomeDealFinal', deal, 'Offerte reali', 'Occasione Imperdibile', anchor, 5);
    anchor = buildProductDeck('KsHomeEditorialFinal', editorial, 'Prodotti KeepStore', 'In Evidenza', anchor, 10);
    anchor = buildProductDeck('KsHomeBestSellerFinal', bestRaw, 'Best Seller', 'Best Seller', anchor, 5);
    if (recent.length >= 2) anchor = buildProductDeck('KsHomeRecentFinal', recent, 'Recenti', 'Scelti Da Te', anchor, 5);
    anchor = buildLowerMatrix(lower, anchor);
    anchor = placeBrands(anchor, r.brands);
    buildClosingLayer(anchor);
    initSliders();
  }

  function boot() {
    safe('render', render);
    [150, 450, 1000, 2200].forEach(function (delay) { window.setTimeout(function () { safe('render-retry', render); }, delay); });
    window.addEventListener('resize', function () { window.setTimeout(function () { safe('hero-resize', forceHeroLayout); }, 120); });
  }

  ready(boot);
})();

/* KeepStore HOME - Step 113 ONSUS hard hero pass: standalone to avoid touching server logic. */
(function () {
  'use strict';
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function q(s, r) { return (r || document).querySelector(s); }
  function txt(n) { return (n && (n.textContent || '') || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { n.style.removeProperty('display'); n.style.removeProperty('visibility'); n.style.removeProperty('opacity'); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-final-source-hidden', why || 'step113'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function run() {
    if (!document.body) return;
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    document.body.classList.add('ks-page-home', 'ks-home-step113-onsus-hard');
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var menu = shell ? q('.wrap-item-1', shell) : null;
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    [section, shell, menu, hero].forEach(show);
    if (shell) {
      shell.style.setProperty('display', 'grid', 'important');
      shell.style.setProperty('grid-template-columns', window.innerWidth >= 992 ? '250px minmax(0,1fr)' : '1fr', 'important');
      shell.style.setProperty('gap', '18px', 'important');
      shell.style.setProperty('min-height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
    }
    if (menu && window.innerWidth >= 992) {
      menu.style.setProperty('display', 'block', 'important');
      menu.style.setProperty('width', '250px', 'important');
      menu.style.setProperty('min-width', '250px', 'important');
      menu.style.setProperty('height', '340px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,[id$="HeroSideWrap"]', section).forEach(function (n) { hide(n, 'side-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media--only,.ks-home-hero-slider a,[id$="Slide_Show_Container"]', section).forEach(function (n) {
      show(n);
      n.style.setProperty('height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
      n.style.setProperty('min-height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
      n.style.setProperty('width', '100%', 'important');
      n.style.setProperty('background', '#050505', 'important');
      n.style.setProperty('overflow', 'hidden', 'important');
    });
    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner a', section) || q('.ks-home-hero-slider a', section);
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section);
    if (media && img) {
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src) {
        if (!img.getAttribute('src')) img.setAttribute('src', src);
        media.style.setProperty('background-image', 'url("' + src.replace(/"/g, '%22') + '")', 'important');
      }
      var apply = function () {
        var nw = img.naturalWidth || 0, nh = img.naturalHeight || 0, ratio = nw && nh ? nw / nh : 0;
        media.classList.remove('ks-hero-artwork-square');
        if (!ratio || ratio < 1.45) {
          media.classList.add('ks-hero-artwork-square');
          media.style.setProperty('background-size', '150% auto', 'important');
          media.style.setProperty('background-position', 'center center', 'important');
          img.style.setProperty('opacity', '0', 'important');
          img.style.setProperty('visibility', 'hidden', 'important');
        } else {
          media.style.setProperty('background-size', 'cover', 'important');
          media.style.setProperty('background-position', 'center center', 'important');
          img.style.setProperty('opacity', '1', 'important');
          img.style.setProperty('visibility', 'visible', 'important');
          img.style.setProperty('object-fit', 'cover', 'important');
          img.style.setProperty('object-position', 'center center', 'important');
        }
      };
      if (img.complete) apply(); else img.addEventListener('load', apply, { once: true });
    }
    var brands = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (brands) {
      var n = brands.nextElementSibling, guard = 0;
      while (n && guard < 8) {
        guard += 1;
        if (n.id === 'KsHomeClosingLayer' || (n.classList && n.classList.contains('ks-home-final-rendered'))) { n = n.nextElementSibling; continue; }
        var t = txt(n).toLowerCase();
        if ((t.indexOf('in evidenza') >= 0 || t.indexOf('top 20') >= 0 || t.indexOf('i piu') >= 0 || t.indexOf('offerta') >= 0) && qa('a[href*="articolo.aspx"]', n).length > 0) {
          n.classList.add('ks-native-vertical-source-off');
          hide(n, 'stray-native');
        }
        n = n.nextElementSibling;
      }
    }
  }
  function boot() { run(); [120, 350, 850, 1800, 3000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 114/4 Onsus index mix foundation.
   Applies the real Onsus index structure as a visual contract while preserving KeepStore server data. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function visible(n) { return !!(n && n.offsetParent !== null && getComputedStyle(n).display !== 'none' && getComputedStyle(n).visibility !== 'hidden'); }
  function show(n) {
    if (!n) return;
    n.removeAttribute('hidden');
    n.removeAttribute('aria-hidden');
    if (n.style) {
      n.style.removeProperty('display');
      n.style.removeProperty('visibility');
      n.style.removeProperty('opacity');
      n.style.removeProperty('height');
      n.style.removeProperty('min-height');
      n.style.removeProperty('max-height');
      n.style.removeProperty('overflow');
    }
  }
  function hardHide(n, why) {
    if (!n) return;
    n.setAttribute('data-ks-onsus-mix-hidden', why || 'mix');
    if (n.style) n.style.setProperty('display', 'none', 'important');
  }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }

  function normalizeHeroLikeIndex() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    if (!shell) return;
    var menu = q('.wrap-item-1', shell);
    var hero = q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell);
    if (!hero) return;

    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v1');
    section.classList.add('ks-onsus-top-section');
    shell.classList.add('s-banner-wrapper', 'ks-onsus-top-wrapper');
    hero.classList.add('ks-onsus-hero-panel');
    if (menu) menu.classList.add('ks-onsus-dept-panel');

    show(section); show(shell); show(menu); show(hero);
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { hardHide(n, 'legacy-side'); });

    var desk = window.innerWidth >= 992;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', desk ? '258px minmax(0, 1fr)' : '1fr', 'important');
    shell.style.setProperty('gap', desk ? '20px' : '0', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    shell.style.setProperty('min-height', desk ? '345px' : '245px', 'important');
    shell.style.setProperty('overflow', 'visible', 'important');

    if (menu) {
      if (desk) {
        menu.style.setProperty('display', 'block', 'important');
        menu.style.setProperty('width', '258px', 'important');
        menu.style.setProperty('min-width', '258px', 'important');
        menu.style.setProperty('max-width', '258px', 'important');
        menu.style.setProperty('height', '345px', 'important');
        menu.style.setProperty('max-height', '345px', 'important');
        menu.style.setProperty('overflow', 'hidden', 'important');
      } else {
        hardHide(menu, 'mobile-menu-column');
      }
    }

    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media--only,.ks-home-hero-slider a,[id$="Slide_Show_Container"]', section).forEach(function (n) {
      show(n);
      n.style.setProperty('display', 'block', 'important');
      n.style.setProperty('width', '100%', 'important');
      n.style.setProperty('height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('min-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('max-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('overflow', 'hidden', 'important');
      n.style.setProperty('background-color', '#050505', 'important');
      n.style.setProperty('border-radius', '8px', 'important');
      n.style.setProperty('position', 'relative', 'important');
    });

    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section) || hero;
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero);
    if (media && img) {
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      if (src) media.style.setProperty('background-image', 'url("' + src.replace(/"/g, '%22') + '")', 'important');
      media.classList.remove('ks-hero-artwork-square');
      media.classList.add('ks-onsus-hero-artwork-zoom');
      media.style.setProperty('background-repeat', 'no-repeat', 'important');
      media.style.setProperty('background-position', 'center center', 'important');
      media.style.setProperty('background-size', desk ? '178% auto' : '210% auto', 'important');
      img.style.setProperty('opacity', '0', 'important');
      img.style.setProperty('visibility', 'hidden', 'important');
      img.style.setProperty('display', 'block', 'important');
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'cover', 'important');
    }

    qa('.ks-home-departments,.menu-category-list', section).forEach(function (n) {
      n.style.setProperty('height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('max-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('overflow-y', 'auto', 'important');
    });
  }

  function normalizeSectionsToIndexCadence() {
    var order = ['KsHomeDepartmentShowcase', 'KsHomeDealFinal', 'KsHomeEditorialFinal', 'KsHomeBestSellerFinal', 'KsHomeRecentFinal', 'KsHomeLowerFinal'];
    order.forEach(function (id) {
      var n = q('#' + id);
      if (n) n.classList.add('ks-onsus-index-section');
    });
    var deal = q('#KsHomeDealFinal');
    if (deal) {
      deal.classList.add('ks-onsus-deal-today');
      var title = q('h5', deal);
      if (title && /Occasione/i.test(text(title))) title.innerHTML = '<span class="ks-onsus-fire">●</span> Occasione Imperdibile';
    }
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial) editorial.classList.add('ks-onsus-feature-grid');
    var best = q('#KsHomeBestSellerFinal');
    if (best) best.classList.add('ks-onsus-best-seller');
    var lower = q('#KsHomeLowerFinal');
    if (lower) lower.classList.add('ks-onsus-top-trend');

    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('card-product', 'style-img-border');
      var media = q('.ks-final-product-media', card);
      if (media) media.classList.add('product-img');
      var img = q('img', card);
      if (img) img.classList.add('img-product');
      var link = q('h6 a', card);
      if (link) link.classList.add('name-product', 'body-md-2', 'fw-semibold', 'text-secondary', 'link');
    });
  }

  function removeNativeColumnsAfterBrand() {
    var brand = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var n = brand.nextElementSibling;
    var guard = 0;
    while (n && guard < 14) {
      guard += 1;
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *')) { n = next; continue; }
      if (n.getAttribute('data-ks-final-home') === '1' || n.classList.contains('ks-home-final-rendered')) { n = next; continue; }
      var hasProducts = qa('a[href*="articolo.aspx"]', n).length > 0;
      var t = text(n).toLowerCase();
      if (hasProducts && /(in evidenza|top 20|più venduti|piu venduti|offerta|scelti|best seller)/i.test(t)) hardHide(n, 'native-after-brand');
      n = next;
    }
  }

  function run() {
    if (!document.body || !q('.ks-home-hero-section,[id$="HomeHeroSection"]')) return;
    normalizeHeroLikeIndex();
    normalizeSectionsToIndexCadence();
    removeNativeColumnsAfterBrand();
  }
  function boot() { run(); [100, 300, 800, 1600, 2600, 4200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 115/4 Onsus index mix 2.
   Builds the missing Onsus top mechanics with real KeepStore data: right promo tiles + composed hero. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { n.style.removeProperty('display'); n.style.removeProperty('visibility'); n.style.removeProperty('opacity'); n.style.removeProperty('height'); n.style.removeProperty('min-height'); n.style.removeProperty('max-height'); n.style.removeProperty('overflow'); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step115-hidden', why || 'hidden'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function readImg(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }
  function readPrice(root) { var m = text(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var candidates = [q('h6 a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < candidates.length; i++) {
      var t = text(candidates[i]);
      if (t && t.length > 4 && !/^(scopri|compra|categoria)$/i.test(t)) return t;
    }
    return '';
  }
  function productFromCard(card) {
    if (!card) return null;
    var a = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(a && a.getAttribute('href'));
    var img = readImg(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: readPrice(card) };
  }
  function productPool(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeDealFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 2)) return;
      var p = productFromCard(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function sidePromoHtml(p, idx) {
    return '<a class="ks-onsus-side-promo" href="' + esc(p.href) + '">' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '<span class="ks-side-text"><span class="ks-side-kicker">' + (idx === 0 ? 'Offerta' : 'Promo') + '</span><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<em>' + esc(p.price) + '</em>' : '') + '</span></a>';
  }
  function ensureTopSidePromos(shell, hero) {
    if (!shell || !hero) return;
    var box = q('#KsOnsusTopSidePromos', shell);
    var pool = productPool(2);
    if (pool.length < 2) { if (box) hide(box, 'not-enough-products'); return; }
    if (!box) {
      box = document.createElement('div');
      box.id = 'KsOnsusTopSidePromos';
      box.className = 'ks-onsus-side-promos';
      if (hero.nextSibling) shell.insertBefore(box, hero.nextSibling); else shell.appendChild(box);
    }
    box.innerHTML = sidePromoHtml(pool[0], 0) + sidePromoHtml(pool[1], 1);
    show(box);
  }
  function composeHero(section, hero) {
    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section) || hero;
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero);
    if (!media || !img) return;
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.98) 0%, rgba(5,5,5,.92) 38%, rgba(5,5,5,.18) 62%, rgba(5,5,5,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 108%', 'important');
    media.style.setProperty('background-position', 'center center, right center', 'important');
    media.classList.add('ks-onsus-hero-composed');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');
    if (!q('.ks-onsus-hero-caption', media)) {
      var cap = document.createElement('div');
      cap.className = 'ks-onsus-hero-caption';
      cap.innerHTML = '<span class="ks-hero-brand">Samsung</span><span class="ks-hero-sub">Odyssey Gaming Monitor G40B</span><span class="ks-hero-title">Uniti verso la nuova era del gioco</span><span class="ks-hero-specs"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span>';
      media.appendChild(cap);
    }
  }
  function normalizeTop() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    var menu = shell ? q('.wrap-item-1', shell) : null;
    if (!shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v1', 'ks-home-template-mix-v2');
    [section, shell, hero, menu].forEach(show);
    composeHero(section, hero);
    ensureTopSidePromos(shell, hero);
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { hide(n, 'replaced-by-real-side-promos'); });
  }
  function killNativeAfterBrand() {
    var brand = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var n = brand.nextElementSibling, guard = 0;
    while (n && guard < 14) {
      guard += 1;
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *')) { n = next; continue; }
      if (n.getAttribute('data-ks-final-home') === '1' || n.classList.contains('ks-home-final-rendered')) { n = next; continue; }
      var hasProducts = qa('a[href*="articolo.aspx"]', n).length > 0;
      var t = text(n).toLowerCase();
      if (hasProducts && /(in evidenza|top 20|più venduti|piu venduti|offerta|scelti|best seller)/i.test(t)) hide(n, 'native-after-brand');
      n = next;
    }
  }
  function run() { if (!document.body) return; normalizeTop(); killNativeAfterBrand(); }
  function boot() { run(); [100, 300, 700, 1300, 2400, 4200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 116/4 Onsus index mix 3.
   Structural top banner: real 3-column Onsus layout without changing VB/DB. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { ['display','visibility','opacity','height','min-height','max-height','overflow'].forEach(function (p) { n.style.removeProperty(p); }); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step116-hidden', why || 'hidden'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function readImg(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }
  function readPrice(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFromCard(card) {
    if (!card) return null;
    var a = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(a && a.getAttribute('href'));
    var img = readImg(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: readPrice(card) };
  }
  function productPool(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeDealFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,#KsHomeLowerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 2)) return;
      var p = productFromCard(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function promoHtml(p, i) {
    return '<a class="ks-onsus-side-promo ks-onsus-side-promo-v3" href="' + esc(p.href) + '">' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '<span class="ks-side-text"><span class="ks-side-kicker">' + (i === 0 ? 'Offerta' : 'Consigliato') + '</span><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<em>' + esc(p.price) + '</em>' : '') + '</span></a>';
  }
  function ensureRightPromos(shell, hero) {
    var box = q('#KsOnsusTopSidePromos', shell);
    var pool = productPool(2);
    if (pool.length < 2) { if (box) hide(box, 'not-enough-products'); return null; }
    if (!box) { box = document.createElement('div'); box.id = 'KsOnsusTopSidePromos'; box.className = 'ks-onsus-side-promos'; }
    box.innerHTML = promoHtml(pool[0], 0) + promoHtml(pool[1], 1);
    if (hero.nextElementSibling !== box) shell.insertBefore(box, hero.nextSibling);
    box.style.removeProperty('display');
    return box;
  }
  function topGrid() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var menu = shell ? q('.wrap-item-1', shell) : null;
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    if (!shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v3');
    section.classList.add('ks-onsus-top-section-v3'); shell.classList.add('ks-onsus-top-wrapper-v3'); hero.classList.add('ks-onsus-hero-panel-v3');
    [section, shell, menu, hero].forEach(show);
    var promos = ensureRightPromos(shell, hero);
    var wide = !window.matchMedia || window.matchMedia('(min-width: 1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('gap', '18px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '252px minmax(0,1fr) 228px' : '252px minmax(0,1fr)', 'important');
    shell.style.setProperty('height', '356px', 'important');
    shell.style.setProperty('min-height', '356px', 'important');
    if (menu) { menu.style.setProperty('grid-column', '1', 'important'); menu.style.setProperty('grid-row', '1', 'important'); menu.style.setProperty('width', '252px', 'important'); menu.style.setProperty('min-width', '252px', 'important'); menu.style.setProperty('height', '356px', 'important'); menu.style.setProperty('max-height', '356px', 'important'); menu.style.setProperty('overflow', 'hidden', 'important'); }
    hero.style.setProperty('grid-column', '2', 'important'); hero.style.setProperty('grid-row', '1', 'important'); hero.style.setProperty('height', '356px', 'important'); hero.style.setProperty('min-height', '356px', 'important'); hero.style.setProperty('min-width', '0', 'important');
    if (promos) { if (wide) { promos.style.setProperty('display', 'grid', 'important'); promos.style.setProperty('grid-column', '3', 'important'); promos.style.setProperty('grid-row', '1', 'important'); promos.style.setProperty('height', '356px', 'important'); } else { promos.style.setProperty('display', 'none', 'important'); } }
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { if (n !== promos) hide(n, 'legacy-side'); });
  }
  function heroArtwork() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = section && (q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section));
    var img = section && (q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero));
    if (!media || !img) return;
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(4,4,4,.98) 0%, rgba(4,4,4,.94) 34%, rgba(4,4,4,.58) 52%, rgba(4,4,4,.08) 76%, rgba(4,4,4,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 162%', 'important');
    media.style.setProperty('background-position', 'center center, right center', 'important');
    media.style.setProperty('height', '356px', 'important'); media.style.setProperty('min-height', '356px', 'important');
    media.classList.add('ks-onsus-hero-composed-v3');
    img.style.setProperty('opacity', '0', 'important'); img.style.setProperty('visibility', 'hidden', 'important');
    var cap = q('.ks-onsus-hero-caption', media);
    if (cap) { cap.style.setProperty('left', '44px', 'important'); cap.style.setProperty('width', '50%', 'important'); cap.style.setProperty('max-width', '360px', 'important'); }
  }
  function polishSections() {
    ['KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeLowerFinal','KsHomeDealFinal'].forEach(function (id) { var s = q('#' + id); if (s) s.classList.add('ks-onsus-polished-section'); });
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial && !q('.ks-onsus-tabline', editorial)) { var title = q('.ks-final-title', editorial); if (title) { var tabs = document.createElement('div'); tabs.className = 'ks-onsus-tabline'; tabs.innerHTML = '<span class="is-active">In Evidenza</span><span>Top prodotti</span><span>Scelti da te</span>'; title.appendChild(tabs); } }
  }
  function run() { topGrid(); heroArtwork(); polishSections(); }
  function boot() { run(); [80,180,360,800,1600,3000,5000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 100); });
})();

/* KeepStore HOME - Step 117/4 Onsus index mix final.
   Last pass: preserve KeepStore server data, enforce ONSUS visual contract, remove native leaks. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function t(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) ['display','visibility','opacity','height','min-height','max-height','overflow','width','min-width','max-width'].forEach(function (p) { n.style.removeProperty(p); }); }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step117-hidden', why || 'final'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function imgSrc(img) { return img && (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || (img.getAttribute('srcset') || '').split(',')[0].trim().split(' ')[0]) || ''; }
  function homeHero() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v4');
    section.classList.add('ks-onsus-top-section-v3'); shell.classList.add('ks-onsus-top-wrapper-v3'); hero.classList.add('ks-onsus-hero-panel-v3');
    [section, shell, menu, hero, promos].forEach(show);
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '252px minmax(0,1fr) 230px' : '252px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '364px', 'important');
    shell.style.setProperty('min-height', '364px', 'important');
    shell.style.setProperty('max-height', '364px', 'important');
    if (menu) { menu.style.setProperty('grid-column', '1', 'important'); menu.style.setProperty('height', '364px', 'important'); menu.style.setProperty('min-height', '364px', 'important'); menu.style.setProperty('max-height', '364px', 'important'); menu.style.setProperty('width', '252px', 'important'); menu.style.setProperty('min-width', '252px', 'important'); menu.style.setProperty('max-width', '252px', 'important'); menu.style.setProperty('overflow', 'hidden', 'important'); }
    hero.style.setProperty('grid-column', '2', 'important'); hero.style.setProperty('height', '364px', 'important'); hero.style.setProperty('min-height', '364px', 'important'); hero.style.setProperty('max-height', '364px', 'important'); hero.style.setProperty('min-width', '0', 'important');
    if (promos) { promos.style.setProperty('grid-column', '3', 'important'); promos.style.setProperty('height', '364px', 'important'); promos.style.setProperty('min-height', '364px', 'important'); promos.style.setProperty('max-height', '364px', 'important'); promos.style.setProperty('display', wide ? 'grid' : 'none', 'important'); }
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { if (n !== promos) hide(n, 'legacy-side'); });
  }
  function heroArtwork() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.98) 0%, rgba(5,5,5,.92) 31%, rgba(5,5,5,.50) 50%, rgba(5,5,5,.08) 74%, rgba(5,5,5,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.classList.add('ks-onsus-hero-composed-v4');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 176%', 'important');
    media.style.setProperty('background-position', 'center center, center center', 'important');
    media.style.setProperty('height', '364px', 'important'); media.style.setProperty('min-height', '364px', 'important'); media.style.setProperty('max-height', '364px', 'important');
    img.style.setProperty('opacity', '0', 'important'); img.style.setProperty('visibility', 'hidden', 'important');
  }
  function normalizeSections() {
    ['KsHomeDealFinal','KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeRecentFinal','KsHomeLowerFinal','KsHomeClosingLayer'].forEach(function (id) {
      var node = q('#' + id);
      if (node) { node.classList.add('ks-onsus-final-v4'); node.setAttribute('data-ks-final-home', '1'); }
    });
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial && !q('.ks-onsus-tabline', editorial)) {
      var title = q('.ks-final-title', editorial);
      if (title) {
        var tabs = document.createElement('div');
        tabs.className = 'ks-onsus-tabline';
        tabs.innerHTML = '<span class="is-active">In Evidenza</span><span>Top prodotti</span><span>Scelti da te</span>';
        title.appendChild(tabs);
      }
    }
    qa('.ks-final-product-grid').forEach(function (grid) {
      grid.classList.add('ks-onsus-grid-v4');
      qa('.ks-final-product-card', grid).forEach(function (card, i) { card.setAttribute('data-ks-card-index', String(i + 1)); });
    });
    qa('.ks-final-lower-column').forEach(function (col) {
      var count = qa('.ks-final-product-card', col).length;
      col.setAttribute('data-ks-items', String(count));
      if (count < 2) col.classList.add('ks-lower-column-sparse');
    });
  }
  function hideNativeLeaks() {
    var brand = q('[id$="HomeBrandsSection"],.ks-home-brands-block,.ks-final-brands');
    if (!brand) return;
    var n = brand.nextElementSibling;
    var guard = 0;
    while (n && guard++ < 14) {
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *') || n.classList.contains('ks-home-final-rendered') || n.getAttribute('data-ks-final-home') === '1') { n = next; continue; }
      var text = t(n);
      var products = qa('a[href*="articolo.aspx"]', n).length;
      if (products || /In Evidenza|Top 20|I Più Venduti|I Piu Venduti|In Offerta|Scelti Da Te|Best Seller|Occasione/i.test(text)) hide(n, 'native-after-brand');
      n = next;
    }
  }
  function run() { if (!document.body) return; homeHero(); heroArtwork(); normalizeSections(); hideNativeLeaks(); }
  function boot() { run(); [120, 260, 520, 1000, 2000, 3800, 6000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 118 ONSUS container/proportion pass.
   Goal: stop looking like a compressed clone by matching ONSUS index proportions: wider container, true 3-lane hero, cleaner section titles. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { ['display','visibility','opacity','width','min-width','max-width','height','min-height','max-height','overflow','grid-column'].forEach(function (p) { n.style.removeProperty(p); }); } }
  function imgSrc(img) { return img && (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || (img.getAttribute('srcset') || '').split(',')[0].trim().split(' ')[0]) || ''; }
  function escCssUrl(src) { return String(src || '').replace(/"/g, '%22'); }
  function homeTop() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-118');
    section.classList.add('ks-onsus-top-section-118');
    shell.classList.add('ks-onsus-top-wrapper-118');
    hero.classList.add('ks-onsus-hero-panel-118');
    [section, shell, menu, hero, promos].forEach(show);
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && promos);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    if (menu) {
      menu.style.setProperty('grid-column', '1', 'important');
      menu.style.setProperty('width', '285px', 'important');
      menu.style.setProperty('min-width', '285px', 'important');
      menu.style.setProperty('max-width', '285px', 'important');
      menu.style.setProperty('height', '390px', 'important');
      menu.style.setProperty('min-height', '390px', 'important');
      menu.style.setProperty('max-height', '390px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    hero.style.setProperty('grid-column', '2', 'important');
    hero.style.setProperty('height', '390px', 'important');
    hero.style.setProperty('min-height', '390px', 'important');
    hero.style.setProperty('max-height', '390px', 'important');
    hero.style.setProperty('min-width', '0', 'important');
    if (promos) {
      promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      promos.style.setProperty('height', '390px', 'important');
      promos.style.setProperty('min-height', '390px', 'important');
      promos.style.setProperty('max-height', '390px', 'important');
      promos.style.setProperty('width', '300px', 'important');
      promos.style.setProperty('min-width', '300px', 'important');
      promos.style.setProperty('max-width', '300px', 'important');
    }
  }
  function heroArt() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    media.classList.add('ks-onsus-hero-art-118');
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(7,7,7,.98) 0%, rgba(7,7,7,.90) 34%, rgba(7,7,7,.42) 57%, rgba(7,7,7,.06) 82%, rgba(7,7,7,0) 100%), url("' + escCssUrl(src) + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, cover', 'important');
    media.style.setProperty('background-position', 'center center, center center', 'important');
    media.style.setProperty('height', '390px', 'important');
    media.style.setProperty('min-height', '390px', 'important');
    media.style.setProperty('max-height', '390px', 'important');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');
    var cap = q('.ks-onsus-hero-caption', media);
    if (cap) {
      cap.style.setProperty('left', '54px', 'important');
      cap.style.setProperty('max-width', '420px', 'important');
      cap.style.setProperty('width', '48%', 'important');
    }
  }
  function titleRows() {
    qa('.ks-final-title').forEach(function (row) {
      row.classList.add('ks-onsus-title-118');
      var tabs = q('.ks-onsus-tabline', row);
      var links = qa('.ks-home-section-link', row);
      links.forEach(function (a, i) { if (i > 0) a.setAttribute('data-ks-onsus-step118-hidden', 'duplicate-link'); });
      if (tabs) row.appendChild(tabs);
      if (links[0]) row.appendChild(links[0]);
    });
  }
  function sectionRhythm() {
    ['KsHomeDealFinal','KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeLowerFinal','KsHomeClosingLayer'].forEach(function (id) {
      var n = q('#' + id);
      if (n) n.classList.add('ks-onsus-section-118');
    });
    qa('.ks-final-product-grid').forEach(function (g) { g.classList.add('ks-onsus-product-grid-118'); });
  }
  function run() { if (!document.body) return; homeTop(); heroArt(); titleRows(); sectionRhythm(); }
  function boot() { run(); [90, 240, 520, 1100, 2400, 4800, 7200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 140); });
})();

/* KeepStore HOME - Step 119 ONSUS final alignment pass.
   Keeps KeepStore server data intact; only normalizes visual composition to the uploaded ONSUS index rhythm. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) {
    if (!n) return;
    n.removeAttribute('hidden');
    n.removeAttribute('aria-hidden');
    if (n.style) ['display','visibility','opacity'].forEach(function (p) { n.style.removeProperty(p); });
  }
  function imgSrc(img) {
    if (!img) return '';
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    return src;
  }
  function escUrl(src) { return String(src || '').replace(/"/g, '%22'); }

  function forceTopGrid() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-119');
    section.classList.add('ks-onsus-top-section-119');
    shell.classList.add('ks-onsus-top-wrapper-119');
    hero.classList.add('ks-onsus-hero-panel-119');
    [section, shell, menu, hero, promos].forEach(show);

    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && promos);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');

    if (menu) {
      menu.style.setProperty('grid-column', '1', 'important');
      menu.style.setProperty('height', '390px', 'important');
      menu.style.setProperty('min-height', '390px', 'important');
      menu.style.setProperty('max-height', '390px', 'important');
      menu.style.setProperty('width', '285px', 'important');
      menu.style.setProperty('min-width', '285px', 'important');
      menu.style.setProperty('max-width', '285px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    hero.style.setProperty('grid-column', '2', 'important');
    hero.style.setProperty('height', '390px', 'important');
    hero.style.setProperty('min-height', '390px', 'important');
    hero.style.setProperty('max-height', '390px', 'important');
    hero.style.setProperty('min-width', '0', 'important');
    hero.style.setProperty('overflow', 'hidden', 'important');
    if (promos) {
      promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      promos.style.setProperty('grid-template-rows', '1fr 1fr', 'important');
      promos.style.setProperty('gap', '20px', 'important');
      promos.style.setProperty('height', '390px', 'important');
      promos.style.setProperty('width', '300px', 'important');
      promos.style.setProperty('min-width', '300px', 'important');
      promos.style.setProperty('max-width', '300px', 'important');
    }
  }

  function strengthenHero() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!hero || !media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    media.classList.add('ks-onsus-hero-art-119');
    if (src) {
      media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.99) 0%, rgba(5,5,5,.94) 32%, rgba(5,5,5,.56) 54%, rgba(5,5,5,.13) 80%, rgba(5,5,5,0) 100%), url("' + escUrl(src) + '")', 'important');
    }
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 158%', 'important');
    media.style.setProperty('background-position', 'center center, 88% center', 'important');
    media.style.setProperty('height', '390px', 'important');
    media.style.setProperty('min-height', '390px', 'important');
    media.style.setProperty('max-height', '390px', 'important');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');

    var cap = q('.ks-onsus-hero-caption', media);
    if (!cap) {
      cap = document.createElement('div');
      cap.className = 'ks-onsus-hero-caption';
      media.appendChild(cap);
    }
    if (!cap.getAttribute('data-ks-step119')) {
      cap.innerHTML = '<span class="ks-hero-brand">Samsung</span>' +
        '<span class="ks-hero-sub">Odyssey Gaming Monitor G40B</span>' +
        '<span class="ks-hero-title">Uniti verso la nuova era del gioco</span>' +
        '<span class="ks-hero-specs"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span>' +
        '<a class="ks-hero-cta" href="catalogo.aspx">Scopri ora</a>';
      cap.setAttribute('data-ks-step119', '1');
    }
  }

  function polishSparseLowerBlocks() {
    qa('.ks-final-lower-grid').forEach(function (grid) {
      var visibleCols = 0;
      qa('.ks-final-lower-column', grid).forEach(function (col) {
        var count = qa('.ks-final-product-card,a[href*="articolo.aspx"]', col).length;
        col.setAttribute('data-ks-step119-items', String(count));
        if (count < 2) {
          col.classList.add('ks-lower-column-sparse');
          col.style.setProperty('display', 'none', 'important');
        } else {
          col.classList.remove('ks-lower-column-sparse');
          col.style.removeProperty('display');
          visibleCols += 1;
        }
      });
      grid.setAttribute('data-ks-step119-visible-columns', String(visibleCols));
      if (visibleCols === 2) grid.style.setProperty('grid-template-columns', 'repeat(2,minmax(0,1fr))', 'important');
      if (visibleCols <= 1) grid.style.setProperty('grid-template-columns', '1fr', 'important');
    });
  }

  function sectionPolish() {
    qa('.ks-final-title').forEach(function (row) {
      row.classList.add('ks-onsus-title-119');
      var tabs = q('.ks-onsus-tabline', row);
      if (tabs && tabs.parentNode !== row) row.appendChild(tabs);
    });
    qa('.ks-final-product-grid').forEach(function (g) { g.classList.add('ks-onsus-product-grid-119'); });
    qa('.ks-final-product-card').forEach(function (card) {
      if (!card.getAttribute('data-ks-step119-polished')) {
        card.setAttribute('data-ks-step119-polished', '1');
        var title = q('h6 a,a[href*="articolo.aspx"]', card);
        if (title) title.setAttribute('title', text(title));
      }
    });
  }

  function run() {
    if (!document.body) return;
    forceTopGrid();
    strengthenHero();
    sectionPolish();
    polishSparseLowerBlocks();
  }
  function boot() { run(); [80, 220, 520, 1000, 2200, 4600, 7600].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 120 ONSUS hero stage compositor.
   Uses the real KeepStore banner image as artwork, but renders a clean ONSUS-like stage above legacy slider markup. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function imgSrc(img) {
    if (!img) return '';
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    return src;
  }
  function safeUrl(src) { return String(src || '').replace(/"/g, '%22'); }
  function heroNodes() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    return { section: section, shell: shell, menu: menu, hero: hero, promos: promos, img: img };
  }
  function enforceGrid(n) {
    if (!n.section || !n.shell || !n.hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-120');
    n.section.classList.add('ks-onsus-top-section-120');
    n.shell.classList.add('ks-onsus-top-wrapper-120');
    n.hero.classList.add('ks-onsus-hero-panel-120');
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && n.promos);
    n.shell.style.setProperty('display', 'grid', 'important');
    n.shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    n.shell.style.setProperty('gap', '20px', 'important');
    n.shell.style.setProperty('height', '390px', 'important');
    n.shell.style.setProperty('min-height', '390px', 'important');
    n.shell.style.setProperty('max-height', '390px', 'important');
    n.shell.style.setProperty('align-items', 'stretch', 'important');
    if (n.menu) {
      n.menu.style.setProperty('grid-column', '1', 'important');
      n.menu.style.setProperty('grid-row', '1', 'important');
      n.menu.style.setProperty('width', '285px', 'important');
      n.menu.style.setProperty('min-width', '285px', 'important');
      n.menu.style.setProperty('max-width', '285px', 'important');
      n.menu.style.setProperty('height', '390px', 'important');
      n.menu.style.setProperty('min-height', '390px', 'important');
      n.menu.style.setProperty('max-height', '390px', 'important');
      n.menu.style.setProperty('overflow', 'hidden', 'important');
    }
    n.hero.style.setProperty('grid-column', '2', 'important');
    n.hero.style.setProperty('grid-row', '1', 'important');
    n.hero.style.setProperty('position', 'relative', 'important');
    n.hero.style.setProperty('height', '390px', 'important');
    n.hero.style.setProperty('min-height', '390px', 'important');
    n.hero.style.setProperty('max-height', '390px', 'important');
    n.hero.style.setProperty('overflow', 'hidden', 'important');
    n.hero.style.setProperty('background', '#050505', 'important');
    if (n.promos) {
      n.promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      n.promos.style.setProperty('grid-row', '1', 'important');
      n.promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      n.promos.style.setProperty('height', '390px', 'important');
      n.promos.style.setProperty('min-height', '390px', 'important');
      n.promos.style.setProperty('max-height', '390px', 'important');
      n.promos.style.setProperty('width', '300px', 'important');
      n.promos.style.setProperty('min-width', '300px', 'important');
      n.promos.style.setProperty('max-width', '300px', 'important');
    }
  }
  function buildHeroStage(n) {
    if (!n.hero || !n.img) return;
    var src = imgSrc(n.img);
    if (!src) return;
    var stage = q('#KsOnsusHeroStage120', n.hero);
    if (!stage) {
      stage = document.createElement('div');
      stage.id = 'KsOnsusHeroStage120';
      stage.className = 'ks-onsus-hero-stage-120';
      stage.innerHTML = '<div class="ks-onsus-hero-copy-120"><span class="ks-kicker-120">Samsung</span><span class="ks-sub-120">Odyssey Gaming Monitor G40B</span><strong>Uniti verso la nuova era del gioco</strong><span class="ks-specs-120"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span><a href="catalogo.aspx" class="ks-cta-120">Scopri ora</a></div><div class="ks-onsus-hero-art-120" aria-hidden="true"></div>';
      n.hero.appendChild(stage);
    }
    stage.style.setProperty('--ks-hero-image-120', 'url("' + safeUrl(src) + '")');
    stage.setAttribute('data-ks-src', src);
    qa('.ks-onsus-hero-caption', n.hero).forEach(function (cap) { cap.style.setProperty('display', 'none', 'important'); });
    qa('.ks-home-hero-slider img,[id$="Slide_Show_Container"] img,.ks-home-hero-banner img,.ks-home-hero-media img', n.hero).forEach(function (img) {
      img.style.setProperty('opacity', '0', 'important');
      img.style.setProperty('visibility', 'hidden', 'important');
    });
    qa('.ks-home-hero-slider a,.ks-home-hero-banner,.ks-home-hero-media', n.hero).forEach(function (media) {
      media.style.setProperty('background-image', 'none', 'important');
      media.style.setProperty('background-color', '#050505', 'important');
    });
  }
  function compactLongTitles() {
    qa('.ks-final-product-info h6 a,.ks-final-lower-item strong,.ks-onsus-side-promo strong,.ks-onsus-side-promo-v3 strong').forEach(function (a) {
      if (!a.getAttribute('title')) a.setAttribute('title', String(a.textContent || '').replace(/\s+/g, ' ').trim());
    });
  }
  function run() {
    if (!document.body) return;
    var n = heroNodes();
    enforceGrid(n);
    buildHeroStage(n);
    compactLongTitles();
  }
  function boot() { run(); [80, 220, 520, 1000, 1800, 3200, 5200, 8200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 121 ONSUS final integration cleanup.
   Keeps server-side data intact and only stabilizes visual runtime. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function heroShell() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    return section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
  }
  function resetDepartmentScroll() {
    var shell = heroShell();
    var menu = shell && q('.wrap-item-1', shell);
    if (!menu || menu.getAttribute('data-ks-step121-scroll-reset')) return;
    menu.setAttribute('data-ks-step121-scroll-reset', '1');
    [menu].concat(qa('*', menu)).forEach(function (el) {
      if (el && typeof el.scrollTop === 'number') el.scrollTop = 0;
    });
  }
  function enforceFinalTop() {
    var shell = heroShell();
    if (!shell) return;
    var hero = q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell);
    var promos = q('#KsOnsusTopSidePromos', shell) || q('.ks-onsus-side-promos', shell);
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-121');
    if (hero) hero.classList.add('ks-onsus-hero-final-121');
    shell.classList.add('ks-onsus-shell-final-121');
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    if (promos) promos.style.setProperty('display', wide ? 'grid' : 'none', 'important');
  }
  function hideNativeVerticalResidues() {
    var brand = q('.ks-final-brands') || q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var cursor = brand.nextElementSibling;
    var guard = 0;
    while (cursor && guard < 8) {
      guard += 1;
      var t = text(cursor).toLowerCase();
      var hasProduct = q('a[href*="articolo.aspx"]', cursor);
      var isFinalPanel = cursor.classList && (cursor.classList.contains('ks-home-closing-grid') || cursor.classList.contains('footer') || cursor.id === 'footer');
      if (isFinalPanel) break;
      if (hasProduct && (/in evidenza|top 20|venduti|offerta|scelti/.test(t))) {
        cursor.setAttribute('data-ks-step121-hide', '1');
      }
      cursor = cursor.nextElementSibling;
    }
  }
  function polishCards() {
    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('ks-step121-card');
      var link = q('a[href*="articolo.aspx"]', card);
      if (link && !link.getAttribute('title')) link.setAttribute('title', text(link));
      var img = q('img', card);
      if (img) {
        img.setAttribute('loading', 'lazy');
        img.setAttribute('decoding', 'async');
      }
    });
    qa('.ks-final-lower-column').forEach(function (col) {
      var items = qa('a[href*="articolo.aspx"]', col).length;
      if (items === 0) col.setAttribute('data-ks-step121-hide', '1');
    });
  }
  function normalizeTitleRows() {
    qa('.ks-final-title').forEach(function (row) {
      var tabs = q('.ks-onsus-tabline', row);
      var link = q('.ks-home-section-link', row);
      if (tabs) tabs.style.setProperty('display', 'flex', 'important');
      if (link) link.textContent = 'Vai al catalogo';
    });
  }
  function run() {
    if (!document.body) return;
    enforceFinalTop();
    resetDepartmentScroll();
    hideNativeVerticalResidues();
    polishCards();
    normalizeTitleRows();
  }
  function boot() { run(); [120, 350, 800, 1600, 3200, 6200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 160); });
})();

/* KeepStore HOME - Step 122: ONSUS Deal Today + wide product banner.
   Uses only server-rendered KeepStore products already present in the page. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.ks-final-product-info a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFrom(card) {
    if (!card) return null;
    var link = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(link && link.getAttribute('href'));
    var img = imgFrom(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(card) };
  }
  function collectProducts(limit) {
    var out = [], seen = Object.create(null);
    var selectors = [
      '#KsHomeEditorialFinal .ks-final-product-card',
      '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-product-card',
      '.ks-final-product-card'
    ];
    qa(selectors.join(',')).forEach(function (card) {
      if (out.length >= (limit || 12)) return;
      var p = productFrom(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function resetMenuScroll() {
    var shell = q('.ks-home-hero-shell') || q('[id$="HomeHeroShell"]');
    var menu = shell && q('.wrap-item-1', shell);
    if (!menu) return;
    [menu].concat(qa('*', menu)).forEach(function (n) { if (n && typeof n.scrollTop === 'number') n.scrollTop = 0; });
  }
  function normalizeDealTitle() {
    var section = q('#KsHomeEditorialFinal');
    if (!section) return;
    section.classList.add('ks-onsus-deal-today-122');
    var title = q('.ks-final-title', section);
    if (!title) return;
    var kicker = q('.ks-section-kicker', title);
    var h = q('h5', title);
    var link = q('.ks-home-section-link', title);
    if (kicker) kicker.textContent = 'DEAL TODAY';
    if (h) h.innerHTML = '<span class="ks-fire-122">●</span> Occasione Imperdibile';
    if (link) link.textContent = 'Vai al catalogo';
    var grid = q('.ks-final-product-grid', section);
    if (grid) grid.classList.add('ks-onsus-deal-grid-122');
    qa('.ks-final-product-card', section).forEach(function (card, index) {
      card.classList.add('ks-onsus-deal-card-122');
      if (!q('.ks-onsus-sale-progress-122', card)) {
        var p = document.createElement('div');
        p.className = 'ks-onsus-sale-progress-122';
        var w = 44 + ((index * 11) % 35);
        p.innerHTML = '<span><i style="width:' + w + '%"></i></span>';
        card.appendChild(p);
      }
    });
  }
  function widePromoHtml(p) {
    return '<section id="KsOnsusWidePromo122" class="tf-sp-2 ks-onsus-wide-promo-122 ks-home-final-rendered" data-ks-final-home="1">' +
      '<div class="container"><a class="ks-wide-promo-inner-122" href="' + esc(p.href) + '">' +
      '<span class="ks-wide-copy-122"><em>Offerta KeepStore</em><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '<span>Scopri ora</span></span>' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '</a></div></section>';
  }
  function ensureWidePromo() {
    var existing = q('#KsOnsusWidePromo122');
    var deal = q('#KsHomeEditorialFinal');
    var best = q('#KsHomeBestSellerFinal');
    var products = collectProducts(6);
    var p = products[2] || products[0];
    if (!p || !deal || !best) { if (existing) existing.remove(); return; }
    if (!existing) {
      var tmp = document.createElement('div');
      tmp.innerHTML = widePromoHtml(p);
      existing = tmp.firstChild;
      best.parentNode.insertBefore(existing, best);
    } else {
      existing.outerHTML = widePromoHtml(p);
    }
  }
  function normalizeLowerColumns() {
    var lower = q('#KsHomeLowerFinal');
    if (!lower) return;
    lower.classList.add('ks-onsus-grid-collection-122');
    var title = q('.ks-final-title h5', lower);
    var kicker = q('.ks-section-kicker', lower);
    if (kicker) kicker.textContent = 'GRID COLLECTION';
    if (title) title.textContent = 'Scelte dal catalogo';
    qa('.ks-final-lower-column', lower).forEach(function (col) {
      var count = qa('.ks-final-product-card,a[href*="articolo.aspx"]', col).length;
      if (count < 2) col.setAttribute('data-ks-step122-hide', '1');
    });
  }
  function normalizeCards() {
    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('ks-onsus-card-122');
      var title = q('h6 a,a[href*="articolo.aspx"]', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', txt(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }
  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-122');
    resetMenuScroll();
    normalizeDealTitle();
    ensureWidePromo();
    normalizeLowerColumns();
    normalizeCards();
  }
  function boot() { run(); [120, 350, 800, 1600, 3200, 6200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 180); });
})();


/* KeepStore HOME - Step 123: restore ONSUS order.
   Deal Of The Day is separate; the normal product deck returns to In Evidenza. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.ks-final-product-info a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFrom(card) {
    if (!card) return null;
    var link = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(link && link.getAttribute('href'));
    var img = imgFrom(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(card) };
  }
  function getProducts(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 8)) return;
      var p = productFrom(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function dealHtml(products) {
    return '<section id="KsOnsusDealToday123" class="ks-onsus-deal123 tf-sp-2 pt-0" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-deal123-title"><h5><span class="ks-deal123-fire">●</span>Deal Of The Day</h5><span></span><div class="ks-deal123-nav"><span>‹</span><span>›</span></div></div>' +
      '<div class="ks-deal123-grid">' + products.map(function (p, index) {
        var w = 48 + ((index * 13) % 34);
        return '<a class="ks-deal123-card" href="' + esc(p.href) + '">' +
          '<span class="ks-deal123-media"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span>' +
          '<span class="ks-deal123-info"><span class="ks-deal123-title-product">' + esc(p.title) + '</span>' +
          (p.price ? '<span class="ks-deal123-price">' + esc(p.price) + '</span>' : '') +
          '<span class="ks-deal123-progress"><i style="width:' + w + '%"></i></span></span></a>';
      }).join('') + '</div></div></section>';
  }
  function ensureDealStrip() {
    var editorial = q('#KsHomeEditorialFinal');
    if (!editorial) return;
    var products = getProducts(4);
    var existing = q('#KsOnsusDealToday123');
    if (products.length < 4) { if (existing) existing.remove(); return; }
    if (!existing) {
      var tmp = document.createElement('div');
      tmp.innerHTML = dealHtml(products);
      existing = tmp.firstChild;
      editorial.parentNode.insertBefore(existing, editorial);
    } else {
      existing.outerHTML = dealHtml(products);
    }
  }
  function restoreEditorialDeck() {
    var section = q('#KsHomeEditorialFinal');
    if (!section) return;
    section.classList.remove('ks-onsus-deal-today-122');
    var kicker = q('.ks-section-kicker', section);
    var h = q('.ks-final-title h5', section);
    var link = q('.ks-home-section-link', section);
    if (kicker) kicker.textContent = 'PRODOTTI KEEPSTORE';
    if (h) h.textContent = 'In Evidenza';
    if (link) link.textContent = 'Vai al catalogo';
    qa('.ks-onsus-sale-progress-122', section).forEach(function (n) { n.remove(); });
  }
  function removeBrokenWidePromo() { qa('#KsOnsusWidePromo122,.ks-onsus-wide-promo-122').forEach(function (n) { n.remove(); }); }
  function lowerGridNoEmptyPanels() {
    var lower = q('#KsHomeLowerFinal');
    if (!lower) return;
    var visible = 0;
    qa('.ks-final-lower-column', lower).forEach(function (col) {
      var count = qa('a[href*="articolo.aspx"]', col).length;
      if (count < 2) col.setAttribute('data-ks-step122-hide', '1'); else { col.removeAttribute('data-ks-step122-hide'); visible += 1; }
    });
    if (visible < 2) lower.setAttribute('data-ks-step123-hide', '1'); else lower.removeAttribute('data-ks-step123-hide');
  }
  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-123');
    removeBrokenWidePromo();
    restoreEditorialDeck();
    ensureDealStrip();
    lowerGridNoEmptyPanels();
  }
  function boot() { run(); [150, 400, 900, 1800, 3400, 6400].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 180); });
})();

/* KeepStore HOME - Step 124: ONSUS real order pass.
   Moves Deal Of The Day to the same semantic position as the ONSUS index
   (right after icon boxes / before department tiles) and prevents the same
   products from being repeated in the main editorial deck when possible. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function normHref(href) { return String(href || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }

  function section(id) { return q('#' + id); }

  function getDealUrls() {
    var urls = Object.create(null);
    qa('#KsOnsusDealToday123 a[href*="articolo.aspx"]').forEach(function (a) {
      var h = normHref(a.getAttribute('href'));
      if (h) urls[h] = 1;
    });
    return urls;
  }

  function placeDealToday() {
    var deal = section('KsOnsusDealToday123');
    if (!deal) return;

    var dept = section('KsHomeDepartmentShowcase');
    var iconBoxes = q('.ks-home-iconboxes-section, [id$="HomeIconBoxesSection"], .home-icon-boxes, .tf-icon-box, .iconbox, .tf-iconbox');

    if (dept && dept.parentNode) {
      if (deal.nextElementSibling !== dept) dept.parentNode.insertBefore(deal, dept);
      return;
    }
    if (iconBoxes && iconBoxes.parentNode && iconBoxes.nextSibling !== deal) {
      iconBoxes.parentNode.insertBefore(deal, iconBoxes.nextSibling);
    }
  }

  function preventEditorialDupes() {
    var deal = section('KsOnsusDealToday123');
    var editorial = section('KsHomeEditorialFinal');
    if (!deal || !editorial) return;
    var urls = getDealUrls();
    var cards = qa('.ks-final-product-card', editorial);
    var candidates = [];
    cards.forEach(function (card) {
      var a = q('a[href*="articolo.aspx"]', card);
      var h = normHref(a && a.getAttribute('href'));
      if (h && urls[h]) candidates.push(card);
    });
    var visibleBefore = cards.filter(function (card) { return card.getAttribute('data-ks-step124-dupe') !== '1'; }).length;
    var remaining = cards.length - candidates.length;
    if (candidates.length && remaining >= 5) {
      candidates.forEach(function (card) { card.setAttribute('data-ks-step124-dupe', '1'); });
      editorial.classList.add('ks-editorial-deduped-after-deal');
    } else if (visibleBefore < 5) {
      cards.forEach(function (card) { card.removeAttribute('data-ks-step124-dupe'); });
      editorial.classList.remove('ks-editorial-deduped-after-deal');
    }
  }

  function normalizeDealVisual() {
    var deal = section('KsOnsusDealToday123');
    if (!deal) return;
    deal.classList.add('ks-onsus-deal-real-order-124');
    var kicker = q('.ks-deal123-title h5', deal);
    if (kicker && !/Occasione/i.test(txt(kicker))) kicker.innerHTML = '<span class="ks-deal123-fire">●</span>Occasione Imperdibile';
    qa('.ks-deal123-card', deal).forEach(function (card) {
      var title = q('.ks-deal123-title-product', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', txt(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }

  function tightenOnsusRhythm() {
    qa('#KsHomeDepartmentShowcase,#KsHomeEditorialFinal,#KsHomeBestSellerFinal,#KsHomeLowerFinal,#KsHomeBrandSection,#KsHomeClosingLayer,#KsOnsusDealToday123').forEach(function (s) {
      s.classList.add('ks-onsus-rhythm-124');
    });
    var editorialTitle = q('#KsHomeEditorialFinal .ks-final-title h5');
    if (editorialTitle) editorialTitle.textContent = 'Prodotti in evidenza';
    var editorialKicker = q('#KsHomeEditorialFinal .ks-section-kicker');
    if (editorialKicker) editorialKicker.textContent = 'PRODOTTI KEEPSTORE';
    var lowerTitle = q('#KsHomeLowerFinal .ks-final-title h5');
    if (lowerTitle) lowerTitle.textContent = 'Scelte dal catalogo';
    var brandTitle = q('#KsHomeBrandSection .ks-final-title h5, #KsHomeBrandSection h5, #KsHomeBrandSection h4');
    if (brandTitle) brandTitle.textContent = 'Rivenditori ufficiali - I migliori Brand';
  }

  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-124');
    placeDealToday();
    normalizeDealVisual();
    preventEditorialDupes();
    tightenOnsusRhythm();
  }

  function boot() {
    run();
    [120, 350, 800, 1500, 3000, 6000].forEach(function (d) { window.setTimeout(run, d); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 160); });
})();

/* KeepStore HOME - Step 125: massive ONSUS surface pass.
   Adds the missing ONSUS promotional band, enriches product cards with the
   template interaction rail, stabilizes section order/width, and keeps all
   data sourced from the existing KeepStore DOM. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function norm(h) { return String(h || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }
  function first(sel, root) { return q(sel, root || document); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var src = im.currentSrc || im.getAttribute('src') || im.getAttribute('data-src') || '';
      if (!src && im.getAttribute('srcset')) src = String(im.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite|blank/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('.ks-deal123-title-product', root), q('.ks-final-product-info h6 a', root), q('.ks-final-product-info a', root), q('h6 a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFrom(card) {
    if (!card) return null;
    var a = q('a[href*="articolo.aspx"]', card);
    var href = norm(a && a.getAttribute('href'));
    var img = imgFrom(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(card) };
  }
  function collectProducts(limit) {
    var out = [], seen = Object.create(null);
    var selectors = [
      '#KsOnsusDealToday123 .ks-deal123-card',
      '#KsHomeEditorialFinal .ks-final-product-card',
      '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-lower-item',
      '.ks-final-product-card',
      'a[href*="articolo.aspx"]'
    ].join(',');
    qa(selectors).forEach(function (node) {
      if (limit && out.length >= limit) return;
      var root = node.matches && node.matches('a[href*="articolo.aspx"]') ? (node.closest('.ks-final-product-card,.ks-deal123-card,.ks-final-lower-item,.swiper-slide,.product-item') || node) : node;
      var p = productFrom(root);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function tile(p, type, kicker) {
    if (!p) return '';
    return '<a class="ks-onsus-promo125-tile ks-onsus-promo125-' + esc(type || 'sm') + '" href="' + esc(p.href) + '">' +
      '<span class="ks-onsus-promo125-copy"><em>' + esc(kicker || 'Offerta KeepStore') + '</em><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '<i>Scopri ora</i></span>' +
      '<span class="ks-onsus-promo125-media"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span>' +
      '</a>';
  }
  function ensurePromoBand() {
    var dept = q('#KsHomeDepartmentShowcase');
    var editorial = q('#KsHomeEditorialFinal');
    var anchor = dept || q('#KsOnsusDealToday123') || editorial;
    if (!anchor || !anchor.parentNode) return;
    var products = collectProducts(8);
    var band = q('#KsOnsusPromoBand125');
    if (products.length < 3) { if (band) band.remove(); return; }
    var html = '<section id="KsOnsusPromoBand125" class="ks-onsus-promo125 tf-sp-2 pt-0" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-onsus-promo125-grid">' +
      tile(products[0], 'lg', 'Offerta del momento') +
      '<div class="ks-onsus-promo125-stack">' + tile(products[1], 'sm', 'Novità') + tile(products[2], 'sm dark', 'Consigliato') + '</div>' +
      tile(products[3] || products[0], 'md', 'Top categoria') +
      '</div></div></section>';
    if (!band) {
      var tmp = document.createElement('div');
      tmp.innerHTML = html;
      band = tmp.firstElementChild;
      anchor.parentNode.insertBefore(band, anchor.nextSibling);
    } else {
      band.outerHTML = html;
    }
  }
  function enrichCards() {
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,#KsOnsusDealToday123 .ks-deal123-card').forEach(function (card) {
      if (!card || card.getAttribute('data-ks-onsus-card125') === '1') return;
      card.setAttribute('data-ks-onsus-card125', '1');
      var href = norm((q('a[href*="articolo.aspx"]', card) || {}).getAttribute && q('a[href*="articolo.aspx"]', card).getAttribute('href')) || '#';
      var rail = document.createElement('span');
      rail.className = 'ks-onsus-action-rail125';
      rail.innerHTML = '<a href="' + esc(href) + '" aria-label="Dettaglio prodotto">↗</a><button type="button" aria-label="Preferiti">♡</button><button type="button" aria-label="Carrello">＋</button>';
      var media = q('.ks-final-product-media,.ks-deal123-media', card) || card;
      media.appendChild(rail);
      var title = q('.ks-final-product-info h6 a,.ks-deal123-title-product', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', txt(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }
  function restackLower() {
    var lower = q('#KsHomeLowerFinal');
    if (!lower) return;
    lower.classList.add('ks-onsus-catalog-board125');
    var title = q('.ks-final-title h5', lower);
    var kicker = q('.ks-section-kicker', lower);
    if (kicker) kicker.textContent = 'GRID COLLECTION';
    if (title) title.textContent = 'Scelte dal catalogo';
    qa('.ks-final-lower-column', lower).forEach(function (col) {
      var count = qa('a[href*="articolo.aspx"]', col).length;
      if (count < 2) col.setAttribute('data-ks-step125-hide', '1');
      else col.removeAttribute('data-ks-step125-hide');
    });
  }
  function tightenSections() {
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-125');
    qa('#KsOnsusDealToday123,#KsHomeDepartmentShowcase,#KsOnsusPromoBand125,#KsHomeEditorialFinal,#KsHomeBestSellerFinal,#KsHomeLowerFinal,#KsHomeBrandSection,#KsHomeClosingLayer').forEach(function (s) {
      if (s) s.classList.add('ks-onsus-section125');
    });
    var deal = q('#KsOnsusDealToday123');
    var dept = q('#KsHomeDepartmentShowcase');
    if (deal && dept && deal.parentNode && deal.nextElementSibling !== dept) deal.parentNode.insertBefore(deal, dept);
    var promo = q('#KsOnsusPromoBand125');
    var editorial = q('#KsHomeEditorialFinal');
    if (promo && editorial && promo.parentNode && promo.nextElementSibling !== editorial) promo.parentNode.insertBefore(promo, editorial);
    var h = q('#KsHomeEditorialFinal .ks-final-title h5');
    if (h) h.textContent = 'Prodotti in evidenza';
  }
  function run() {
    if (!document.body) return;
    ensurePromoBand();
    enrichCards();
    restackLower();
    tightenSections();
  }
  function boot() { run(); [160, 420, 900, 1800, 3600, 7000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 180); });
})();

/* KeepStore HOME - Step 126: ONSUS hard cleanup after massive surface pass.
   Removes the experimental wide/promo surface that duplicated the Samsung hero,
   suppresses runtime action rails that are not part of the requested ONSUS index
   composition, and stabilizes the visible section order with server-sourced data. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function removeNode(n) { if (n && n.parentNode) n.parentNode.removeChild(n); }
  function removeExperimentalSurfaces() {
    qa('#KsOnsusPromoBand125,.ks-onsus-promo125,#KsOnsusWidePromo122,.ks-onsus-wide-promo-122').forEach(removeNode);
    qa('.ks-onsus-action-rail125').forEach(removeNode);
    document.body.classList.remove('ks-home-onsus-pass-125');
    document.body.classList.add('ks-home-onsus-pass-126');
  }
  function normalizeHeroGrid() {
    var shell = q('.ks-home-hero-shell,[id$="HomeHeroShell"]');
    if (!shell) return;
    shell.classList.add('ks-onsus-top-clean-126');
    var menu = q('.ks-home-departments-menu,[id$="HomeDepartmentsMenu"]', shell) || q('.ks-home-departments-menu,[id$="HomeDepartmentsMenu"]');
    var hero = q('.ks-onsus-hero-panel-120,.ks-home-hero-shell>.wrap-item-2,[id$="HomeHeroShell"]>.wrap-item-2', shell);
    var side = q('#KsOnsusTopSidePromos,.ks-onsus-side-promos', shell) || q('#KsOnsusTopSidePromos,.ks-onsus-side-promos');
    [menu, hero, side].forEach(function (n) { if (n) n.classList.add('ks-onsus-top-clean-item-126'); });
    if (menu && menu.scrollTop > 0) menu.scrollTop = 0;
  }
  function ensureCleanTitles() {
    var labels = [
      ['#KsOnsusDealToday123 .ks-deal123-title h5', 'Occasione Imperdibile'],
      ['#KsHomeEditorialFinal .ks-final-title h5', 'Prodotti in evidenza'],
      ['#KsHomeBestSellerFinal .ks-final-title h5', 'Best Seller'],
      ['#KsHomeLowerFinal .ks-final-title h5', 'Scelte dal catalogo']
    ];
    labels.forEach(function (pair) { var n = q(pair[0]); if (n) n.textContent = pair[1]; });
    qa('.ks-final-title a,.ks-deal123-title a').forEach(function (a) { if (/catalogo|vedi|vai/i.test(text(a)) || !text(a)) a.textContent = 'Vai al catalogo'; });
  }
  function pruneBrokenOrDuplicateSections() {
    var brand = q('#KsHomeBrandSection');
    if (brand) {
      var n = brand.nextElementSibling;
      while (n) {
        var next = n.nextElementSibling;
        var id = n.id || '';
        var t = text(n).toLowerCase();
        if (!/KsHomeClosingLayer|footer|Footer|newsletter/i.test(id) && /in evidenza|best seller|top 20|piu venduti|più venduti|in offerta/.test(t) && qa('a[href*="articolo.aspx"]', n).length) {
          n.setAttribute('hidden', 'hidden');
          n.style.display = 'none';
        }
        n = next;
      }
    }
    qa('.ks-final-product-card,.ks-deal123-card').forEach(function (card) {
      var title = q('h6 a,.ks-deal123-title-product,a[href*="articolo.aspx"]', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', text(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }
  function enforceOrder() {
    var deal = q('#KsOnsusDealToday123');
    var dept = q('#KsHomeDepartmentShowcase');
    var editorial = q('#KsHomeEditorialFinal');
    var best = q('#KsHomeBestSellerFinal');
    var lower = q('#KsHomeLowerFinal');
    var brand = q('#KsHomeBrandSection');
    var closing = q('#KsHomeClosingLayer');
    if (deal && dept && deal.parentNode && dept.parentNode === deal.parentNode && dept.previousElementSibling !== deal) {
      dept.parentNode.insertBefore(deal, dept);
    }
    if (editorial && dept && editorial.parentNode === dept.parentNode && editorial.previousElementSibling !== dept) {
      dept.parentNode.insertBefore(editorial, dept.nextSibling);
    }
    if (best && editorial && best.parentNode === editorial.parentNode && best.previousElementSibling !== editorial) {
      editorial.parentNode.insertBefore(best, editorial.nextSibling);
    }
    if (lower && best && lower.parentNode === best.parentNode && lower.previousElementSibling !== best) {
      best.parentNode.insertBefore(lower, best.nextSibling);
    }
    if (brand && lower && brand.parentNode === lower.parentNode && brand.previousElementSibling !== lower) {
      lower.parentNode.insertBefore(brand, lower.nextSibling);
    }
    if (closing && brand && closing.parentNode === brand.parentNode && closing.previousElementSibling !== brand) {
      brand.parentNode.insertBefore(closing, brand.nextSibling);
    }
  }
  function run() {
    if (!document.body) return;
    removeExperimentalSurfaces();
    normalizeHeroGrid();
    enforceOrder();
    ensureCleanTitles();
    pruneBrokenOrDuplicateSections();
  }
  function boot() {
    run();
    [80, 220, 500, 1000, 2000, 4000, 8000].forEach(function (d) { window.setTimeout(run, d); });
    var mo = new MutationObserver(function () { window.clearTimeout(mo._ksT); mo._ksT = window.setTimeout(run, 60); });
    mo.observe(document.documentElement, { childList: true, subtree: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 127: ONSUS central product mosaic.
   Uses real server-emitted products to replace the flat editorial deck with
   a template-like feature mosaic. No demo products, no DB writes. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  function norm(h) { return String(h || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var src = im.currentSrc || im.getAttribute('src') || im.getAttribute('data-src') || '';
      if (!src && im.getAttribute('srcset')) src = String(im.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite|blank|nofoto/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = qa('h6 a,.ks-final-product-info h6 a,.ks-deal123-title-product,.ks-final-lower-item a[href*="articolo.aspx"],a[href*="articolo.aspx"]', root);
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 6 && !/^(scopri|compra|categoria|vai al catalogo|dettaglio)$/i.test(t)) return t;
    }
    return '';
  }
  function catFrom(root) {
    var c = txt(q('.ks-final-product-cat,.category,.cat,.ks-deal123-cat', root));
    return c && c.length < 35 ? c : '';
  }
  function productFrom(root) {
    if (!root) return null;
    var a = q('a[href*="articolo.aspx"]', root);
    var href = norm(a && a.getAttribute('href'));
    var img = imgFrom(root);
    var title = titleFrom(root);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(root), cat: catFrom(root) || 'KeepStore' };
  }
  function collectProducts(limit) {
    var out = [], seen = Object.create(null);
    var roots = [];
    ['#KsHomeEditorialFinal .ks-final-product-card','#KsOnsusDealToday123 .ks-deal123-card','#KsHomeBestSellerFinal .ks-final-product-card','#KsHomeLowerFinal .ks-final-lower-item','.ks-final-product-card','.product-item,.swiper-slide'].forEach(function (sel) {
      qa(sel).forEach(function (n) { roots.push(n); });
    });
    roots.forEach(function (r) {
      if (limit && out.length >= limit) return;
      var p = productFrom(r);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function mini(p, label) {
    if (!p) return '';
    return '<a class="ks-onsus-mosaic-mini127" href="' + esc(p.href) + '"><small>' + esc(label || p.cat) + '</small><strong>' + esc(p.title) + '</strong>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></a>';
  }
  function card(p) {
    if (!p) return '';
    return '<a class="ks-onsus-mosaic-card127" href="' + esc(p.href) + '"><span class="ks-card-media127"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span><small>' + esc(p.cat) + '</small><strong>' + esc(p.title) + '</strong>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '</a>';
  }
  function feature(p) {
    if (!p) return '';
    return '<a class="ks-onsus-mosaic-feature127" href="' + esc(p.href) + '"><span class="ks-feature-copy127"><em>Scelta KeepStore</em><small>' + esc(p.cat) + '</small><strong>' + esc(p.title) + '</strong>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '<span class="ks-feature-cta127">Scopri ora</span></span><span class="ks-feature-media127"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span></a>';
  }
  function buildMosaic() {
    var dept = q('#KsHomeDepartmentShowcase');
    var old = q('#KsHomeEditorialFinal');
    if (!dept && !old) return;
    var products = collectProducts(14);
    var mosaic = q('#KsOnsusProductMosaic127');
    if (products.length < 7) { if (mosaic) mosaic.remove(); return; }
    var html = '<section id="KsOnsusProductMosaic127" class="tf-sp-2 ks-onsus-product-mosaic127" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-onsus-mosaic-title127"><div class="ks-title-main127"><div><span class="ks-kicker127">Prodotti KeepStore</span><h5>In evidenza</h5></div><div class="ks-onsus-tabs127"><span>In evidenza</span><span>Top prodotti</span><span>Scelti da te</span></div></div><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div>' +
      '<div class="ks-onsus-mosaic127"><div class="ks-onsus-mosaic-side127">' + mini(products[1], 'Offerta') + mini(products[2], 'Novità') + '</div>' +
      feature(products[0]) + '<div class="ks-onsus-mosaic-side127">' + mini(products[3], 'Consigliato') + mini(products[4], 'Top') + '</div></div>' +
      '<div class="ks-onsus-mosaic-grid127">' + products.slice(5, 10).map(card).join('') + '</div></div></section>';
    var tmp = document.createElement('div');
    tmp.innerHTML = html;
    var fresh = tmp.firstElementChild;
    if (mosaic) mosaic.replaceWith(fresh);
    else if (dept && dept.parentNode) dept.parentNode.insertBefore(fresh, dept.nextSibling);
    else if (old && old.parentNode) old.parentNode.insertBefore(fresh, old);
    if (old) {
      old.setAttribute('data-ks-step127-hidden', 'editorial-replaced-by-mosaic');
      old.style.setProperty('display', 'none', 'important');
    }
  }
  function enforceOrder() {
    var dept = q('#KsHomeDepartmentShowcase');
    var mosaic = q('#KsOnsusProductMosaic127');
    var best = q('#KsHomeBestSellerFinal');
    var lower = q('#KsHomeLowerFinal');
    var brand = q('#KsHomeBrandSection');
    var closing = q('#KsHomeClosingLayer');
    if (mosaic && dept && mosaic.parentNode === dept.parentNode && mosaic.previousElementSibling !== dept) dept.parentNode.insertBefore(mosaic, dept.nextSibling);
    if (best && mosaic && best.parentNode === mosaic.parentNode && best.previousElementSibling !== mosaic) mosaic.parentNode.insertBefore(best, mosaic.nextSibling);
    if (lower && best && lower.parentNode === best.parentNode && lower.previousElementSibling !== best) best.parentNode.insertBefore(lower, best.nextSibling);
    if (brand && lower && brand.parentNode === lower.parentNode && brand.previousElementSibling !== lower) lower.parentNode.insertBefore(brand, lower.nextSibling);
    if (closing && brand && closing.parentNode === brand.parentNode && closing.previousElementSibling !== brand) brand.parentNode.insertBefore(closing, brand.nextSibling);
  }
  function fixTitlesAndBody() {
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-127');
    document.body.classList.remove('ks-home-onsus-pass-125');
    var h = q('#KsHomeEditorialFinal .ks-final-title h5');
    if (h) h.textContent = 'In evidenza';
    var b = q('#KsHomeBestSellerFinal .ks-final-title h5');
    if (b) b.textContent = 'Best Seller';
    var l = q('#KsHomeLowerFinal .ks-final-title h5');
    if (l) l.textContent = 'Scelte dal catalogo';
    qa('.ks-onsus-action-rail125,#KsOnsusPromoBand125,#KsOnsusWidePromo122').forEach(function (n) { if (n && n.parentNode) n.parentNode.removeChild(n); });
  }
  function run() { if (!document.body) return; fixTitlesAndBody(); buildMosaic(); enforceOrder(); }
  function boot() { run(); [100, 260, 600, 1200, 2500, 5000, 9000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 150); });
})();

/* Step 128 - Smart Advisor layer: automatic product guidance for KeepStore HOME.
   Uses only products and categories already rendered by ASP.NET/WebForms. No external AI/API. */
(function () {
  'use strict';
  var STEP = '128';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  function normUrl(h) { return String(h || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var src = im.currentSrc || im.getAttribute('data-src') || im.getAttribute('src') || '';
      if (!src && im.getAttribute('srcset')) src = String(im.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite|blank|nofoto/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = text(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = qa('h6 a,.ks-final-product-info h6 a,.ks-deal123-title-product,.ks-final-lower-item a[href*="articolo.aspx"],.ks-onsus-mosaic-card127 strong,.ks-onsus-mosaic-mini127 strong,.ks-onsus-mosaic-feature127 strong,a[href*="articolo.aspx"]', root);
    for (var i = 0; i < nodes.length; i++) {
      var t = text(nodes[i]);
      if (t && t.length > 6 && !/^(scopri|compra|categoria|vai al catalogo|dettaglio)$/i.test(t)) return t;
    }
    return '';
  }
  function categoryFrom(root) {
    var c = text(q('.ks-final-product-cat,.ks-deal123-cat,.category,.cat,small', root));
    return c && c.length < 38 ? c : 'KeepStore';
  }
  function productFrom(root) {
    if (!root) return null;
    var a = q('a[href*="articolo.aspx"]', root) || (root.matches && root.matches('a[href*="articolo.aspx"]') ? root : null);
    var href = normUrl(a && a.getAttribute('href'));
    var img = imgFrom(root);
    var title = titleFrom(root);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(root), cat: categoryFrom(root), raw: text(root) };
  }
  function collectProducts(max) {
    var roots = [];
    [
      '#KsOnsusDealToday123 .ks-deal123-card',
      '#KsOnsusProductMosaic127 a',
      '#KsHomeEditorialFinal .ks-final-product-card',
      '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-lower-item',
      '.ks-final-product-card', '.product-card', '.product-item', '.swiper-slide'
    ].forEach(function (sel) { qa(sel).forEach(function (n) { roots.push(n); }); });
    var out = [], seen = Object.create(null);
    roots.forEach(function (r) {
      if (max && out.length >= max) return;
      var p = productFrom(r);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  var INTENTS = [
    { key: 'telefono', label: 'Proteggere smartphone', icon: '📱', rx: /smartphone|samsung|galaxy|iphone|custodia|cover|pellicola|vetro|case|magsafe|tablet|telefono/i, terms: ['custodia smartphone', 'pellicola vetro', 'cover samsung'] },
    { key: 'stampanti', label: 'Stampanti, toner e consumabili', icon: '🖨️', rx: /toner|cartucc|pantum|laser|stampant|ink|drum|inchiostro|compatibile/i, terms: ['toner compatibile', 'cartucce stampante', 'stampante'] },
    { key: 'pc', label: 'PC, notebook e periferiche', icon: '💻', rx: /notebook|computer|desktop|pc |lenovo|dell|monitor|ssd|ram|tablet|windows|ricondizionato/i, terms: ['notebook ricondizionato', 'pc desktop', 'monitor'] },
    { key: 'accessori', label: 'Cavi, USB e accessori', icon: '🔌', rx: /usb|type\-?c|cavo|adattatore|hub|hdmi|supporto|alimentatore|mouse|tastiera|card reader/i, terms: ['adattatore usb', 'cavo type-c', 'hub usb'] }
  ];
  function classify(p) {
    var blob = [p.title, p.cat, p.raw].join(' ');
    for (var i = 0; i < INTENTS.length; i++) if (INTENTS[i].rx.test(blob)) return INTENTS[i].key;
    return 'generale';
  }
  function getIntent(key) { return INTENTS.filter(function (i) { return i.key === key; })[0] || INTENTS[0]; }
  function rankProducts(products, key) {
    var intent = getIntent(key);
    return products.slice().sort(function (a, b) {
      var aa = intent.rx.test([a.title, a.cat, a.raw].join(' ')) ? 0 : 1;
      var bb = intent.rx.test([b.title, b.cat, b.raw].join(' ')) ? 0 : 1;
      return aa - bb;
    });
  }
  function detectDefaultIntent(products) {
    var score = {}, i;
    INTENTS.forEach(function (it) { score[it.key] = 0; });
    products.forEach(function (p) { var k = classify(p); if (score[k] != null) score[k] += 1; });
    var best = INTENTS[0].key, val = -1;
    for (i in score) if (score[i] > val) { best = i; val = score[i]; }
    try {
      var stored = window.localStorage && window.localStorage.getItem('ks_ai_intent');
      if (stored && getIntent(stored)) best = stored;
    } catch (e) {}
    return best;
  }
  function productCard(p) {
    return '<a class="ks-ai-product128" href="' + esc(p.href) + '">' +
      '<span class="ks-ai-product-img128"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span>' +
      '<span class="ks-ai-product-copy128"><small>' + esc(p.cat) + '</small><strong>' + esc(p.title) + '</strong>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '</span>' +
      '</a>';
  }
  function searchUrl(term) {
    return 'articoli.aspx?search=' + encodeURIComponent(term || '');
  }
  function renderRecommendations(root, products, key) {
    var intent = getIntent(key);
    var ranked = rankProducts(products, key).slice(0, 4);
    var box = q('.ks-ai-results128', root);
    var summary = q('.ks-ai-summary128', root);
    var actions = q('.ks-ai-actions128', root);
    if (summary) summary.innerHTML = '<strong>' + esc(intent.label) + '</strong><span>Ho selezionato articoli coerenti con questa esigenza, usando solo prodotti gia presenti in questa HOME.</span>';
    if (box) box.innerHTML = ranked.map(productCard).join('');
    if (actions) actions.innerHTML = intent.terms.map(function (t) { return '<a href="' + esc(searchUrl(t)) + '">' + esc(t) + '</a>'; }).join('');
    qa('.ks-ai-chip128', root).forEach(function (chip) { chip.classList.toggle('is-active', chip.getAttribute('data-intent') === key); });
    try { window.localStorage && window.localStorage.setItem('ks_ai_intent', key); } catch (e) {}
  }
  function buildAdvisor() {
    var products = collectProducts(40);
    if (products.length < 4) return;
    var existing = q('#KsSmartAdvisor128');
    var defaultKey = detectDefaultIntent(products);
    var html = '<section id="KsSmartAdvisor128" class="tf-sp-2 ks-smart-advisor128" data-ks-ai="local" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-ai-shell128">' +
        '<div class="ks-ai-panel128">' +
          '<span class="ks-ai-kicker128">AI KeepStore</span>' +
          '<h5>Assistente automatico per scegliere piu velocemente</h5>' +
          '<p>Analizza categorie e prodotti visibili nella HOME e propone percorsi di acquisto utili senza cambiare la logica del sito.</p>' +
          '<div class="ks-ai-chips128">' + INTENTS.map(function (it) { return '<button type="button" class="ks-ai-chip128" data-intent="' + esc(it.key) + '"><span>' + esc(it.icon) + '</span>' + esc(it.label) + '</button>'; }).join('') + '</div>' +
          '<div class="ks-ai-summary128"></div>' +
          '<div class="ks-ai-actions128"></div>' +
        '</div>' +
        '<div class="ks-ai-products128"><div class="ks-ai-products-head128"><span>Consigli automatici</span><small>da prodotti reali KeepStore</small></div><div class="ks-ai-results128"></div></div>' +
      '</div></div></section>';
    var tmp = document.createElement('div');
    tmp.innerHTML = html;
    var fresh = tmp.firstElementChild;
    if (existing) existing.replaceWith(fresh);
    else {
      var dept = q('#KsHomeDepartmentShowcase');
      var deal = q('#KsOnsusDealToday123');
      var hero = q('.ks-home-hero-section,[id$="HomeHeroSection"]');
      if (dept && dept.parentNode) dept.parentNode.insertBefore(fresh, dept.nextSibling);
      else if (deal && deal.parentNode) deal.parentNode.insertBefore(fresh, deal.nextSibling);
      else if (hero && hero.parentNode) hero.parentNode.insertBefore(fresh, hero.nextSibling);
      else document.body.appendChild(fresh);
    }
    qa('.ks-ai-chip128', fresh).forEach(function (chip) {
      chip.addEventListener('click', function () { renderRecommendations(fresh, products, chip.getAttribute('data-intent')); });
    });
    renderRecommendations(fresh, products, defaultKey);
  }
  function enforceOrder() {
    var deal = q('#KsOnsusDealToday123');
    var dept = q('#KsHomeDepartmentShowcase');
    var ai = q('#KsSmartAdvisor128');
    var mosaic = q('#KsOnsusProductMosaic127');
    var best = q('#KsHomeBestSellerFinal');
    var lower = q('#KsHomeLowerFinal');
    var brand = q('#KsHomeBrandSection');
    var closing = q('#KsHomeClosingLayer');
    if (deal && dept && deal.parentNode === dept.parentNode && deal.nextElementSibling !== dept) deal.parentNode.insertBefore(dept, deal.nextSibling);
    if (ai && dept && ai.parentNode === dept.parentNode && ai.previousElementSibling !== dept) dept.parentNode.insertBefore(ai, dept.nextSibling);
    if (mosaic && ai && mosaic.parentNode === ai.parentNode && mosaic.previousElementSibling !== ai) ai.parentNode.insertBefore(mosaic, ai.nextSibling);
    if (best && mosaic && best.parentNode === mosaic.parentNode && best.previousElementSibling !== mosaic) mosaic.parentNode.insertBefore(best, mosaic.nextSibling);
    if (lower && best && lower.parentNode === best.parentNode && lower.previousElementSibling !== best) best.parentNode.insertBefore(lower, best.nextSibling);
    if (brand && lower && brand.parentNode === lower.parentNode && brand.previousElementSibling !== lower) lower.parentNode.insertBefore(brand, lower.nextSibling);
    if (closing && brand && closing.parentNode === brand.parentNode && closing.previousElementSibling !== brand) brand.parentNode.insertBefore(closing, brand.nextSibling);
  }
  function tightenLayout() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-128');
    var h = q('#KsHomeBestSellerFinal .ks-final-title h5');
    if (h) h.textContent = 'Best Seller';
    var l = q('#KsHomeLowerFinal .ks-final-title h5');
    if (l) l.textContent = 'Scelte dal catalogo';
    qa('#KsOnsusPromoBand125,#KsOnsusWidePromo122,.ks-onsus-action-rail125').forEach(function (n) { n.remove(); });
  }
  function run() { tightenLayout(); buildAdvisor(); enforceOrder(); }
  function boot() { run(); [120, 350, 800, 1600, 3200, 7000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();

/* Step 129 - Smart consult layer: useful automatic advisor integrated in ONSUS/KeepStore home.
   No external API, no fake products: it reads only products/categories already rendered by the server. */
(function () {
  'use strict';
  var STEP = '129';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  function normHref(h) { return String(h || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var src = im.currentSrc || im.getAttribute('data-src') || im.getAttribute('src') || '';
      if (!src && im.getAttribute('srcset')) src = String(im.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|paypal|visa|mastercard|placeholder|loader|spinner|sprite|blank|nofoto/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = qa('h6 a,.ks-deal123-title-product,.ks-final-product-info h6 a,.ks-final-lower-item a[href*="articolo.aspx"],.ks-onsus-mosaic-card127 strong,.ks-onsus-mosaic-mini127 strong,.ks-onsus-mosaic-feature127 strong,.ks-ai-product-copy128 strong,a[href*="articolo.aspx"]', root);
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 7 && !/^(scopri|compra|categoria|vai al catalogo|dettaglio|aggiungi)$/i.test(t)) return t;
    }
    return '';
  }
  function catFrom(root) {
    var c = txt(q('.ks-final-product-cat,.ks-deal123-cat,.category,.cat,small', root));
    if (!c || c.length > 42 || /scopri|compra|vai al catalogo/i.test(c)) c = 'KeepStore';
    return c;
  }
  function productFrom(root) {
    if (!root) return null;
    var a = q('a[href*="articolo.aspx"]', root) || (root.matches && root.matches('a[href*="articolo.aspx"]') ? root : null);
    var href = normHref(a && a.getAttribute('href'));
    var img = imgFrom(root);
    var title = titleFrom(root);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(root), cat: catFrom(root), raw: txt(root) };
  }
  function collectProducts(max) {
    var selectors = [
      '#KsOnsusDealToday123 .ks-deal123-card',
      '#KsOnsusProductMosaic127 a',
      '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-lower-item',
      '#KsHomeEditorialFinal .ks-final-product-card',
      '#KsSmartAdvisor128 .ks-ai-product128',
      '.ks-final-product-card', '.product-card', '.product-item', '.swiper-slide'
    ];
    var roots = [];
    selectors.forEach(function (sel) { qa(sel).forEach(function (n) { roots.push(n); }); });
    var out = [], seen = Object.create(null);
    roots.forEach(function (r) {
      if (max && out.length >= max) return;
      var p = productFrom(r);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  var intents = [
    { key: 'phone', label: 'Proteggi smartphone', short: 'Smartphone', rx: /smartphone|samsung|galaxy|iphone|custodia|cover|pellicola|vetro|case|magsafe|tablet|telefono/i, search: ['custodia samsung', 'pellicola vetro', 'cover smartphone'] },
    { key: 'print', label: 'Stampa e consumabili', short: 'Stampanti', rx: /toner|cartucc|pantum|laser|stampant|ink|drum|inchiostro|compatibile/i, search: ['toner compatibile', 'stampante laser', 'cartucce'] },
    { key: 'pc', label: 'PC e notebook', short: 'PC', rx: /notebook|computer|desktop|pc |lenovo|dell|monitor|ssd|ram|windows|ricondizionato/i, search: ['notebook ricondizionato', 'pc desktop', 'monitor'] },
    { key: 'cable', label: 'Cavi e accessori', short: 'Accessori', rx: /usb|type\-?c|cavo|adattatore|hub|hdmi|supporto|alimentatore|mouse|tastiera|card reader|lettore/i, search: ['adattatore usb', 'cavo type-c', 'hub usb'] }
  ];
  function intentByKey(k) { return intents.filter(function (x) { return x.key === k; })[0] || intents[0]; }
  function classify(p) {
    var blob = [p.title, p.cat, p.raw].join(' ');
    for (var i = 0; i < intents.length; i++) if (intents[i].rx.test(blob)) return intents[i].key;
    return 'all';
  }
  function tokens(s) { return String(s || '').toLowerCase().replace(/[^a-z0-9àèéìòùç]+/gi, ' ').split(/\s+/).filter(function (x) { return x.length > 1; }); }
  function scoreProduct(p, intentKey, query) {
    var blob = [p.title, p.cat, p.raw].join(' ').toLowerCase();
    var score = 0;
    var intent = intentByKey(intentKey);
    if (intent.rx.test(blob)) score += 12;
    tokens(query).forEach(function (t) { if (blob.indexOf(t) >= 0) score += 8; });
    if (/samsung|galaxy|lenovo|kingston|toner|pantum|usb|type/.test(blob)) score += 1;
    return score;
  }
  function pick(products, intentKey, query, n) {
    return products.slice().sort(function (a, b) { return scoreProduct(b, intentKey, query) - scoreProduct(a, intentKey, query); }).slice(0, n || 6);
  }
  function productMini(p) {
    return '<a class="ks-ai129-product" href="' + esc(p.href) + '"><span><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span><em>' + esc(p.cat) + '</em><strong>' + esc(p.title) + '</strong>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '</a>';
  }
  function searchLink(term) { return 'articoli.aspx?search=' + encodeURIComponent(term); }
  function defaultIntent(products) {
    var scores = { phone: 0, print: 0, pc: 0, cable: 0 };
    products.forEach(function (p) { var k = classify(p); if (scores[k] != null) scores[k]++; });
    var best = 'phone', max = -1;
    Object.keys(scores).forEach(function (k) { if (scores[k] > max) { max = scores[k]; best = k; } });
    try { var stored = localStorage.getItem('ks_ai_intent_129'); if (stored && intentByKey(stored)) best = stored; } catch (e) {}
    return best;
  }
  function render(root, products, intentKey, query) {
    var intent = intentByKey(intentKey);
    var list = pick(products, intentKey, query, 6);
    var matches = list.filter(function (p) { return scoreProduct(p, intentKey, query) > 0; }).length;
    if (matches < 2 && query) list = pick(products, intentKey, '', 6);
    var summary = q('.ks-ai129-summary', root);
    var result = q('.ks-ai129-results', root);
    var links = q('.ks-ai129-links', root);
    if (summary) summary.innerHTML = '<strong>' + esc(intent.label) + '</strong><span>' + (query ? 'Ricerca guidata su "' + esc(query) + '" usando articoli reali della home.' : 'Percorso automatico basato sui prodotti visibili in questa pagina.') + '</span>';
    if (result) result.innerHTML = list.map(productMini).join('');
    if (links) links.innerHTML = intent.search.map(function (term) { return '<a href="' + esc(searchLink(term)) + '">' + esc(term) + '</a>'; }).join('');
    qa('.ks-ai129-chip', root).forEach(function (c) { c.classList.toggle('is-active', c.getAttribute('data-intent') === intentKey); });
    try { localStorage.setItem('ks_ai_intent_129', intentKey); } catch (e) {}
  }
  function build() {
    var products = collectProducts(70);
    if (products.length < 5) return;
    qa('#KsSmartAdvisor128').forEach(function (n) { n.remove(); });
    var existing = q('#KsSmartConsult129');
    var start = defaultIntent(products);
    var html = '<section id="KsSmartConsult129" class="tf-sp-2 ks-smart-consult129" data-ks-ai="local" data-ks-final-home="1"><div class="container"><div class="ks-ai129-shell">' +
      '<div class="ks-ai129-side"><span class="ks-ai129-kicker">AI KeepStore</span><h5>Assistente automatico per scegliere meglio</h5><p>Analizza categorie e prodotti presenti nella HOME e ti propone il percorso piu utile, senza chiamate esterne e senza prodotti inventati.</p>' +
      '<div class="ks-ai129-search"><input type="search" placeholder="Scrivi: toner, custodia, usb, notebook..." aria-label="Cerca con assistente KeepStore"><button type="button">Trova</button></div>' +
      '<div class="ks-ai129-chips">' + intents.map(function (it) { return '<button type="button" class="ks-ai129-chip" data-intent="' + esc(it.key) + '">' + esc(it.short) + '</button>'; }).join('') + '</div><div class="ks-ai129-summary"></div><div class="ks-ai129-links"></div></div>' +
      '<div class="ks-ai129-board"><div class="ks-ai129-board-head"><span>Consigli automatici</span><small>da articoli reali KeepStore</small></div><div class="ks-ai129-results"></div></div>' +
      '</div></div></section>';
    var tmp = document.createElement('div'); tmp.innerHTML = html;
    var fresh = tmp.firstElementChild;
    if (existing) existing.replaceWith(fresh);
    else {
      var dept = q('#KsHomeDepartmentShowcase');
      var mosaic = q('#KsOnsusProductMosaic127');
      var anchor = dept || mosaic || q('#KsHomeBestSellerFinal');
      if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(fresh, anchor.nextSibling);
      else document.body.appendChild(fresh);
    }
    var input = q('.ks-ai129-search input', fresh);
    var button = q('.ks-ai129-search button', fresh);
    var current = start;
    function update() { render(fresh, products, current, input ? input.value : ''); }
    qa('.ks-ai129-chip', fresh).forEach(function (chip) { chip.addEventListener('click', function () { current = chip.getAttribute('data-intent') || start; update(); }); });
    if (button) button.addEventListener('click', update);
    if (input) input.addEventListener('keydown', function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); update(); } });
    update();
  }
  function enforceOrder() {
    var deal = q('#KsOnsusDealToday123');
    var dept = q('#KsHomeDepartmentShowcase');
    var ai = q('#KsSmartConsult129');
    var mosaic = q('#KsOnsusProductMosaic127');
    var best = q('#KsHomeBestSellerFinal');
    var lower = q('#KsHomeLowerFinal');
    var brand = q('#KsHomeBrandSection');
    var closing = q('#KsHomeClosingLayer');
    if (deal && dept && deal.parentNode === dept.parentNode && deal.nextElementSibling !== dept) deal.parentNode.insertBefore(dept, deal.nextSibling);
    if (ai && dept && ai.parentNode === dept.parentNode && ai.previousElementSibling !== dept) dept.parentNode.insertBefore(ai, dept.nextSibling);
    if (mosaic && ai && mosaic.parentNode === ai.parentNode && mosaic.previousElementSibling !== ai) ai.parentNode.insertBefore(mosaic, ai.nextSibling);
    if (best && mosaic && best.parentNode === mosaic.parentNode && best.previousElementSibling !== mosaic) mosaic.parentNode.insertBefore(best, mosaic.nextSibling);
    if (lower && best && lower.parentNode === best.parentNode && lower.previousElementSibling !== best) best.parentNode.insertBefore(lower, best.nextSibling);
    if (brand && lower && brand.parentNode === lower.parentNode && brand.previousElementSibling !== lower) lower.parentNode.insertBefore(brand, lower.nextSibling);
    if (closing && brand && closing.parentNode === brand.parentNode && closing.previousElementSibling !== brand) brand.parentNode.insertBefore(closing, brand.nextSibling);
  }
  function cleanup() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-129');
    document.body.classList.remove('ks-home-onsus-pass-125');
    qa('#KsSmartAdvisor128,#KsOnsusPromoBand125,#KsOnsusWidePromo122,.ks-onsus-action-rail125').forEach(function (n) { n.remove(); });
    var scrollBox = q('.wrap-item-1 .canvas-sidebar,.wrap-item-1 .ks-home-departments-menu,.wrap-item-1');
    if (scrollBox) scrollBox.scrollTop = 0;
  }
  function run() { cleanup(); build(); enforceOrder(); }
  function boot() { run(); [100, 260, 600, 1200, 2600, 5200, 7600, 10500, 14000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();

/* Step 130 - KeepStore Local Reasoning Search Engine.
   A deterministic, client-side assistant: no external APIs, no fake products, no DB changes.
   It reads real products already rendered in the page and answers natural-language shopping questions. */
(function () {
  'use strict';
  var PASS = '130';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  function norm(s) {
    return String(s || '').toLowerCase()
      .normalize ? String(s || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '') : String(s || '').toLowerCase();
  }
  function absHref(h) {
    h = String(h || '').replace(/&amp;/g, '&').replace(/#.*$/, '');
    if (!h) return '';
    if (/^https?:\/\//i.test(h)) return h;
    if (h.charAt(0) === '/') return h;
    return h;
  }
  function priceNumber(s) {
    var m = String(s || '').match(/(\d{1,5})(?:[\.,](\d{2}))?\s*€/);
    if (!m) return null;
    return parseFloat(m[1].replace(/\./g, '') + '.' + (m[2] || '00'));
  }
  function findImage(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      var src = im.currentSrc || im.getAttribute('data-src') || im.getAttribute('src') || '';
      if (!src && im.getAttribute('srcset')) src = String(im.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|paypal|visa|mastercard|placeholder|loader|spinner|sprite|blank|nofoto|favicon/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function findTitle(root) {
    var sel = [
      '.ks-onsus-mosaic-feature127 strong', '.ks-onsus-mosaic-card127 strong', '.ks-onsus-mosaic-mini127 strong',
      '.ks-deal123-title-product', '.ks-final-product-info h6 a', '.ks-final-lower-item a[href*="articolo.aspx"]',
      '.ks-ai129-product strong', 'h6 a', 'h5 a', 'a[href*="articolo.aspx"]'
    ].join(',');
    var nodes = qa(sel, root);
    for (var i = 0; i < nodes.length; i++) {
      var t = text(nodes[i]);
      if (t && t.length > 7 && !/^(scopri|compra|categoria|vai al catalogo|dettaglio|aggiungi|home)$/i.test(t)) return t;
    }
    return '';
  }
  function findCategory(root) {
    var c = text(q('.ks-final-product-cat,.ks-deal123-cat,.category,.cat,small,em', root));
    if (!c || c.length > 45 || /scopri|compra|catalogo|offerta|consigli/i.test(c)) c = 'KeepStore';
    return c;
  }
  function productFrom(root) {
    if (!root) return null;
    var a = q('a[href*="articolo.aspx"]', root) || (root.matches && root.matches('a[href*="articolo.aspx"]') ? root : null);
    var href = absHref(a && a.getAttribute('href'));
    var img = findImage(root);
    var title = findTitle(root);
    var blob = text(root);
    var priceText = '';
    var prices = blob.match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
    if (prices && prices.length) priceText = prices[prices.length - 1];
    if (!href || !img || !title) return null;
    return {
      href: href,
      img: img,
      title: title,
      titleNorm: norm(title),
      cat: findCategory(root),
      raw: blob,
      rawNorm: norm([title, blob, findCategory(root)].join(' ')),
      price: priceText,
      priceNum: priceNumber(priceText)
    };
  }
  function collectProducts() {
    var selectors = [
      '#KsOnsusDealToday123 .ks-deal123-card', '#KsOnsusProductMosaic127 a', '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-lower-item', '#KsHomeEditorialFinal .ks-final-product-card', '#KsSmartConsult129 .ks-ai129-product',
      '.ks-final-product-card', '.ks-deal123-card', '.ks-final-lower-item', '.product-card', '.product-item', '.swiper-slide'
    ];
    var roots = [];
    selectors.forEach(function (sel) { qa(sel).forEach(function (n) { roots.push(n); }); });
    var out = [], seen = Object.create(null);
    roots.forEach(function (r) {
      var p = productFrom(r);
      if (!p) return;
      var key = p.href.replace(/^https?:\/\/[^/]+/i, '').toLowerCase();
      if (seen[key]) return;
      seen[key] = 1;
      out.push(p);
    });
    return out.slice(0, 90);
  }
  var intents = {
    smartphone: {
      label: 'Protezione smartphone e tablet', icon: '📱',
      rx: /smartphone|telefono|samsung|galaxy|iphone|tablet|custodia|cover|pellicola|vetro|magsafe|silicone|fotocamera|case/i,
      terms: ['smartphone','telefono','samsung','galaxy','tablet','custodia','cover','pellicola','vetro','case','magsafe'],
      searches: ['custodia samsung', 'pellicola vetro smartphone', 'cover magsafe']
    },
    print: {
      label: 'Stampanti, toner e consumabili', icon: '🖨',
      rx: /toner|cartucc|stampant|pantum|laser|drum|inchiostro|compatibile|consumabil|cartridge/i,
      terms: ['toner','cartuccia','stampante','pantum','laser','drum','inchiostro','compatibile'],
      searches: ['toner compatibile', 'stampante laser', 'cartucce']
    },
    pc: {
      label: 'PC, notebook e periferiche', icon: '💻',
      rx: /notebook|computer|desktop|pc\b|lenovo|dell|monitor|ssd|ram|windows|ricondizionato|thinkpad|optiplex/i,
      terms: ['notebook','computer','desktop','pc','lenovo','dell','monitor','windows','ricondizionato'],
      searches: ['notebook ricondizionato', 'pc desktop', 'monitor']
    },
    cable: {
      label: 'Cavi, USB e accessori', icon: '🔌',
      rx: /usb|type\s*c|type\-c|cavo|adattatore|hub|hdmi|supporto|alimentatore|mouse|tastiera|card reader|lettore|splitter/i,
      terms: ['usb','type c','cavo','adattatore','hub','hdmi','supporto','alimentatore','lettore'],
      searches: ['adattatore usb', 'hub usb type-c', 'cavo hdmi']
    }
  };
  var intentOrder = ['smartphone','print','pc','cable'];
  function tokenize(s) {
    return norm(s).replace(/[^a-z0-9]+/g, ' ').split(/\s+/).filter(function (x) { return x.length > 1 && !/^(per|con|una|uno|del|della|che|cosa|cerco|voglio|serve|mi|il|lo|la|gli|dei|dai|sotto)$/i.test(x); });
  }
  function parseQuery(query) {
    var n = norm(query);
    var max = null;
    var budget = n.match(/(?:sotto|entro|max|massimo|meno di|fino a)\s*(\d{1,5})(?:[\.,](\d{2}))?\s*(?:euro|€)?/i);
    if (budget) max = parseFloat(budget[1] + '.' + (budget[2] || '00'));
    var min = null;
    var intentsScore = {};
    intentOrder.forEach(function (k) {
      var it = intents[k], score = 0;
      if (it.rx.test(query)) score += 20;
      it.terms.forEach(function (term) { if (n.indexOf(norm(term)) >= 0) score += 6; });
      intentsScore[k] = score;
    });
    var best = intentOrder.slice().sort(function (a, b) { return intentsScore[b] - intentsScore[a]; })[0];
    if (!intentsScore[best]) best = 'smartphone';
    return { query: query, norm: n, words: tokenize(query), intent: best, maxPrice: max, minPrice: min, wantsCheap: /econom|prezzo|basso|spendere poco|conveniente|offerta|risparm/i.test(n), wantsBest: /miglior|qualita|consigli|consigliami|top|buon/i.test(n) };
  }
  function productScore(p, parsed) {
    var s = 0, blob = p.rawNorm || p.titleNorm;
    var it = intents[parsed.intent];
    if (it && it.rx.test(blob)) s += 36;
    parsed.words.forEach(function (w) {
      if (p.titleNorm.indexOf(w) >= 0) s += 12;
      else if (blob.indexOf(w) >= 0) s += 7;
    });
    if (parsed.maxPrice != null && p.priceNum != null) {
      if (p.priceNum <= parsed.maxPrice) s += 28;
      else s -= Math.min(26, Math.round((p.priceNum - parsed.maxPrice) / Math.max(1, parsed.maxPrice) * 18));
    }
    if (parsed.wantsCheap && p.priceNum != null) s += Math.max(0, 14 - Math.min(14, p.priceNum / 20));
    if (/compatibile|ricondizionato|garanzia|supporto|protezione|vetro|usb|type/.test(blob)) s += 4;
    if (/test prova|scanner|kingston|samsung|lenovo|pantum|toner|devia|notebook/i.test(p.title)) s += 2;
    return Math.round(s);
  }
  function reasonFor(p, parsed) {
    var blob = p.rawNorm || '';
    var out = [];
    if (intents[parsed.intent] && intents[parsed.intent].rx.test(blob)) out.push('coerente con la richiesta');
    if (parsed.maxPrice != null && p.priceNum != null && p.priceNum <= parsed.maxPrice) out.push('entro budget');
    if (/compatibile/i.test(p.raw)) out.push('compatibile');
    if (/ricondizionato/i.test(p.raw)) out.push('ricondizionato');
    if (/vetro|custodia|cover|protezione/i.test(p.raw)) out.push('protezione');
    if (!out.length) out.push('articolo reale disponibile in home');
    return out.slice(0, 3).join(' · ');
  }
  function rankProducts(products, parsed) {
    return products.map(function (p) { return { p: p, score: productScore(p, parsed) }; })
      .filter(function (x) { return x.score > 0 || parsed.words.length === 0; })
      .sort(function (a, b) { return b.score - a.score; })
      .slice(0, 8);
  }
  function renderCard(item, parsed, idx) {
    var p = item.p;
    return '<a class="ks-ai130-card" href="' + esc(p.href) + '">' +
      '<span class="ks-ai130-rank">' + (idx + 1) + '</span>' +
      '<span class="ks-ai130-img"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span>' +
      '<span class="ks-ai130-copy"><em>' + esc(p.cat) + '</em><strong>' + esc(p.title) + '</strong><small>' + esc(reasonFor(p, parsed)) + '</small>' + (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '</span>' +
      '</a>';
  }
  function answerText(parsed, ranked, total) {
    var it = intents[parsed.intent] || intents.smartphone;
    if (!parsed.query || parsed.query.length < 2) {
      return 'Scrivi cosa stai cercando: analizzo gli articoli reali visibili in home, riconosco categoria, parole chiave e budget, poi ti propongo le opzioni piu sensate.';
    }
    if (!ranked.length) {
      return 'Non ho trovato una corrispondenza forte tra i ' + total + ' articoli letti in home. Prova con parole piu concrete, ad esempio “toner Pantum”, “custodia Samsung”, “hub USB-C” o “notebook ricondizionato”.';
    }
    var first = ranked[0].p;
    var budget = parsed.maxPrice != null ? ' Ho considerato anche il limite di prezzo indicato: massimo ' + parsed.maxPrice.toFixed(2).replace('.', ',') + ' €.' : '';
    return 'Ho capito che cerchi ' + it.label.toLowerCase() + '. La scelta piu coerente e “' + first.title + '”' + (first.price ? ' a ' + first.price : '') + '. Ti mostro anche alternative ordinate per pertinenza, disponibilita visiva e prezzo.' + budget;
  }
  function queryLink(term) { return 'articoli.aspx?search=' + encodeURIComponent(term); }
  function createEngine(products) {
    qa('#KsSmartConsult129,#KsSmartAdvisor128').forEach(function (n) { n.remove(); });
    var examples = ['Mi serve una custodia per Samsung sotto 30 euro', 'Cerco toner compatibile Pantum', 'Voglio un notebook ricondizionato', 'Mi serve un adattatore USB-C'];
    var html = '<section id="KsLocalAiSearch130" class="ks-ai130-section tf-sp-2" data-ks-ai="local-reasoning" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-ai130-shell"><div class="ks-ai130-brain">' +
      '<span class="ks-ai130-kicker">AI locale KeepStore</span><h5>Chiedimi cosa stai cercando</h5><p>Motore autonomo in pagina: interpreta la richiesta, valuta budget e parole chiave, poi risponde usando solo prodotti reali caricati nella HOME.</p>' +
      '<form class="ks-ai130-form"><input type="search" autocomplete="off" placeholder="Es. Cerco un toner compatibile sotto 50 euro"><button type="submit">Ragiona</button></form>' +
      '<div class="ks-ai130-examples">' + examples.map(function (e) { return '<button type="button">' + esc(e) + '</button>'; }).join('') + '</div>' +
      '<div class="ks-ai130-answer"><i></i><p></p></div>' +
      '<div class="ks-ai130-tools"><a href="' + esc(queryLink('toner compatibile')) + '">Toner</a><a href="' + esc(queryLink('custodia samsung')) + '">Custodie</a><a href="' + esc(queryLink('notebook ricondizionato')) + '">Notebook</a><a href="' + esc(queryLink('hub usb')) + '">USB</a></div>' +
      '</div><div class="ks-ai130-results-wrap"><div class="ks-ai130-head"><span>Risposta e prodotti consigliati</span><small>' + products.length + ' articoli analizzati</small></div><div class="ks-ai130-results"></div></div></div></div></section>';
    var tmp = document.createElement('div'); tmp.innerHTML = html;
    var node = tmp.firstElementChild;
    var dept = q('#KsHomeDepartmentShowcase');
    var deal = q('#KsOnsusDealToday123');
    var anchor = dept || deal || q('#KsOnsusProductMosaic127') || q('#KsHomeBestSellerFinal');
    if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(node, anchor.nextSibling);
    else document.body.appendChild(node);
    var input = q('.ks-ai130-form input', node);
    var form = q('.ks-ai130-form', node);
    var answer = q('.ks-ai130-answer p', node);
    var lamp = q('.ks-ai130-answer i', node);
    var results = q('.ks-ai130-results', node);
    function runQuery(queryText) {
      var parsed = parseQuery(queryText || '');
      var ranked = rankProducts(products, parsed);
      if (lamp) lamp.setAttribute('data-intent', parsed.intent);
      if (answer) answer.textContent = answerText(parsed, ranked, products.length);
      if (results) {
        results.innerHTML = ranked.length ? ranked.slice(0, 6).map(function (item, idx) { return renderCard(item, parsed, idx); }).join('') : '<div class="ks-ai130-empty">Nessun match forte. Prova una richiesta piu specifica o usa uno dei percorsi rapidi.</div>';
      }
      try { localStorage.setItem('ks_ai_last_query_130', queryText || ''); } catch (e) {}
    }
    if (form) form.addEventListener('submit', function (ev) { ev.preventDefault(); runQuery(input && input.value || ''); });
    qa('.ks-ai130-examples button', node).forEach(function (btn) { btn.addEventListener('click', function () { if (input) input.value = text(btn); runQuery(text(btn)); }); });
    var initial = '';
    try { initial = localStorage.getItem('ks_ai_last_query_130') || ''; } catch (e) {}
    if (input && initial) input.value = initial;
    runQuery(initial || 'custodia samsung');
  }
  function enforceOrder() {
    var deal = q('#KsOnsusDealToday123');
    var dept = q('#KsHomeDepartmentShowcase');
    var ai = q('#KsLocalAiSearch130');
    var mosaic = q('#KsOnsusProductMosaic127');
    var best = q('#KsHomeBestSellerFinal');
    var lower = q('#KsHomeLowerFinal');
    var brand = q('#KsHomeBrandSection');
    var closing = q('#KsHomeClosingLayer');
    if (deal && dept && deal.parentNode === dept.parentNode && deal.nextElementSibling !== dept) deal.parentNode.insertBefore(dept, deal.nextSibling);
    if (ai && dept && ai.parentNode === dept.parentNode && ai.previousElementSibling !== dept) dept.parentNode.insertBefore(ai, dept.nextSibling);
    if (mosaic && ai && mosaic.parentNode === ai.parentNode && mosaic.previousElementSibling !== ai) ai.parentNode.insertBefore(mosaic, ai.nextSibling);
    if (best && mosaic && best.parentNode === mosaic.parentNode && best.previousElementSibling !== mosaic) mosaic.parentNode.insertBefore(best, mosaic.nextSibling);
    if (lower && best && lower.parentNode === best.parentNode && lower.previousElementSibling !== best) best.parentNode.insertBefore(lower, best.nextSibling);
    if (brand && lower && brand.parentNode === lower.parentNode && brand.previousElementSibling !== lower) lower.parentNode.insertBefore(brand, lower.nextSibling);
    if (closing && brand && closing.parentNode === brand.parentNode && closing.previousElementSibling !== brand) brand.parentNode.insertBefore(closing, brand.nextSibling);
  }
  function cleanup() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-130');
    document.body.classList.remove('ks-home-onsus-pass-128');
    qa('#KsSmartConsult129,#KsSmartAdvisor128,#KsOnsusPromoBand125,#KsOnsusWidePromo122,.ks-onsus-action-rail125').forEach(function (n) { n.remove(); });
  }
  function run() {
    cleanup();
    if (!q('#KsLocalAiSearch130')) {
      var products = collectProducts();
      if (products.length >= 4) createEngine(products);
    }
    enforceOrder();
  }
  function boot() { run(); [140, 420, 900, 1800, 3600, 7000, 11000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();

/* KeepStore HOME - Step 138 final top-area authority.
   The server chooses FULL / COMPACT_SINGLE / NONE from valid DB assets; this pass only removes older visual experiments. */
(function () {
  'use strict';

  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function home() {
    return !!(document.body && (document.body.classList.contains('ks-page-home') || q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]')));
  }
  function removeStyle(node, props) {
    if (!node || !node.style) return;
    props.forEach(function (prop) { node.style.removeProperty(prop); });
  }
  function show(node) {
    if (!node) return;
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
    removeStyle(node, ['display', 'visibility', 'opacity', 'width', 'min-width', 'max-width', 'height', 'min-height', 'max-height', 'overflow']);
  }
  function hide(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-top-final-hidden', reason || 'hidden');
    if (node.style) node.style.setProperty('display', 'none', 'important');
  }
  function imgSrc(img) {
    if (!img) return '';
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    return String(src || '').trim();
  }
  function validImg(img) {
    var src = imgSrc(img);
    return !!(src && !/blank|loader|spinner|sprite|favicon|placeholder|nofoto/i.test(src));
  }
  function setBox(node, height) {
    if (!node || !node.style) return;
    node.style.setProperty('display', 'block', 'important');
    node.style.setProperty('width', '100%', 'important');
    node.style.setProperty('height', height + 'px', 'important');
    node.style.setProperty('min-height', height + 'px', 'important');
    node.style.setProperty('max-height', height + 'px', 'important');
    node.style.setProperty('overflow', 'hidden', 'important');
  }
  function setModeClass(node, mode) {
    if (!node || !node.classList) return;
    ['full', 'compact-single', 'none'].forEach(function (name) { node.classList.remove('ks-home-hero-mode-' + name); });
    node.classList.add('ks-home-hero-mode-' + mode);
    node.setAttribute('data-ks-hero-mode', mode);
  }
  function removeGeneratedTop(section, shell) {
    qa('#KsOnsusTopSidePromos,.ks-onsus-side-promos,#KsOnsusHeroStage120,.ks-onsus-hero-stage-120,.ks-onsus-hero-caption', shell || section).forEach(function (node) {
      if (node.parentNode) node.parentNode.removeChild(node);
    });
    qa('.ks-onsus-hero-copy-120,.ks-onsus-hero-art-120', section).forEach(function (node) {
      if (node.parentNode) node.parentNode.removeChild(node);
    });
    qa('.ks-home-hero-media,.ks-home-hero-banner,.ks-home-hero-slider a', section).forEach(function (node) {
      removeStyle(node, ['background', 'background-color', 'background-image', 'background-repeat', 'background-size', 'background-position']);
      if (node.classList) {
        node.classList.remove('ks-onsus-hero-composed', 'ks-onsus-hero-composed-v3', 'ks-onsus-hero-composed-v4', 'ks-onsus-hero-art-118', 'ks-onsus-hero-art-119');
      }
    });
  }
  function realSideItems(side) {
    if (!side) return [];
    return qa('.ks-home-side-banner', side).filter(function (item) {
      return validImg(q('img', item));
    });
  }
  function normalize() {
    if (!home()) return;
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    if (!shell) return;

    var hero = q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell);
    var menu = q('.wrap-item-1', shell);
    var side = q('[id$="HeroSideWrap"]', shell) || q('.ks-home-side-banners', shell) || q('.wrap-item-3', shell);
    if (!hero) {
      hide(section, 'no-hero-wrap');
      return;
    }
    var heroImg = q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero);
    var mode = String(shell.getAttribute('data-ks-hero-mode') || section.getAttribute('data-ks-hero-mode') || '').toLowerCase();
    var sideItems = realSideItems(side);

    if (!validImg(heroImg)) mode = 'none';
    if (mode !== 'full' && mode !== 'compact-single' && mode !== 'none') mode = validImg(heroImg) ? 'compact-single' : 'none';
    if (mode === 'full' && sideItems.length < 2) mode = 'compact-single';

    document.body.classList.add('ks-page-home', 'ks-home-top-final-138');
    setModeClass(section, mode);
    setModeClass(shell, mode);

    if (mode === 'none') {
      hide(section, 'no-valid-hero');
      return;
    }

    removeGeneratedTop(section, shell);
    show(section);
    show(shell);
    show(hero);

    var desktop = !window.matchMedia || window.matchMedia('(min-width:992px)').matches;
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var height = desktop ? (wide ? 390 : 350) : 245;
    var menuWidth = wide ? 285 : 245;
    var sideWidth = wide ? 300 : 220;

    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', desktop ? (mode === 'full' ? menuWidth + 'px minmax(0,1fr) ' + sideWidth + 'px' : menuWidth + 'px minmax(0,1fr)') : '1fr', 'important');
    shell.style.setProperty('gap', desktop ? '20px' : '0', 'important');
    shell.style.setProperty('height', height + 'px', 'important');
    shell.style.setProperty('min-height', height + 'px', 'important');
    shell.style.setProperty('max-height', height + 'px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    shell.style.setProperty('overflow', 'visible', 'important');

    if (menu) {
      if (desktop) {
        show(menu);
        menu.style.setProperty('display', 'block', 'important');
        menu.style.setProperty('width', menuWidth + 'px', 'important');
        menu.style.setProperty('min-width', menuWidth + 'px', 'important');
        menu.style.setProperty('max-width', menuWidth + 'px', 'important');
        menu.style.setProperty('height', height + 'px', 'important');
        menu.style.setProperty('min-height', height + 'px', 'important');
        menu.style.setProperty('max-height', height + 'px', 'important');
        menu.style.setProperty('overflow', 'hidden', 'important');
      } else {
        hide(menu, 'mobile-template');
      }
    }

    hero.style.setProperty('grid-column', desktop ? '2' : '1', 'important');
    hero.style.setProperty('min-width', '0', 'important');
    setBox(hero, height);
    qa('.ks-home-hero-slider,[id$="Slide_Show_Container"],.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media--only,.ks-home-hero-slider a', section).forEach(function (node) {
      show(node);
      setBox(node, height);
      if (node.style) {
        node.style.setProperty('background-color', '#050505', 'important');
        node.style.setProperty('border-radius', desktop ? '12px' : '10px', 'important');
      }
    });
    qa('.ks-home-hero-slider img,[id$="Slide_Show_Container"] img', section).forEach(function (img) {
      var src = imgSrc(img);
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      show(img);
      img.style.setProperty('display', 'block', 'important');
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'cover', 'important');
      img.style.setProperty('object-position', 'center center', 'important');
      img.style.setProperty('opacity', '1', 'important');
      img.style.setProperty('visibility', 'visible', 'important');
      img.style.setProperty('transform', 'none', 'important');
    });

    if (side) {
      if (mode === 'full' && desktop) {
        show(side);
        side.classList.add('wrap-item-3', 'ks-home-side-banners');
        side.style.setProperty('display', 'grid', 'important');
        side.style.setProperty('grid-column', '3', 'important');
        side.style.setProperty('grid-template-rows', '1fr 1fr', 'important');
        side.style.setProperty('gap', '20px', 'important');
        side.style.setProperty('width', sideWidth + 'px', 'important');
        side.style.setProperty('min-width', sideWidth + 'px', 'important');
        side.style.setProperty('max-width', sideWidth + 'px', 'important');
        side.style.setProperty('height', height + 'px', 'important');
        side.style.setProperty('min-height', height + 'px', 'important');
        side.style.setProperty('max-height', height + 'px', 'important');
        sideItems.forEach(function (item, index) {
          if (index < 2) {
            show(item);
            item.style.setProperty('height', ((height - 20) / 2) + 'px', 'important');
          } else {
            hide(item, 'more-than-two-side-banners');
          }
        });
      } else {
        hide(side, 'compact-without-side');
      }
    }

    qa('.ks-home-departments,.tf-nav-menu,.menu-category-list', shell).forEach(function (node) {
      node.style.setProperty('height', height + 'px', 'important');
      node.style.setProperty('max-height', height + 'px', 'important');
      node.style.setProperty('overflow-y', 'auto', 'important');
    });
  }
  function boot() {
    normalize();
    [60, 80, 90, 100, 120, 180, 240, 260, 300, 360, 420, 520, 700, 800, 900, 1000, 1100, 1300, 1600, 1800, 2000, 2400, 3000, 3200, 3800, 4200, 4800, 5000, 5200, 6000, 7200, 7600, 11000, 11800, 16000].forEach(function (delay) {
      window.setTimeout(normalize, delay);
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(normalize, 180); });
})();
}
