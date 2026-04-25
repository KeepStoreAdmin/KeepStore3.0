(function () {
  'use strict';

  var ENDPOINT = 'ks_ai_catalog_search.ashx';
  var CSS_PATH = '/Public/assets/keepstore/css/ks-ai-marketplace-engine.css';
  var STORAGE_KEY = 'ks_ai_marketplace_132_last_query';
  var COMPARE_KEY = 'ks_ai_marketplace_132_compare';
  var DEFAULT_QUERY = 'custodia Samsung sotto 30 euro';
  var QUICK = [
    'custodia Samsung sotto 30 euro',
    'toner compatibile Pantum',
    'notebook ricondizionato disponibile',
    'adattatore USB-C economico',
    'pen drive Kingston in offerta',
    'pellicola vetro Samsung Galaxy'
  ];
  var INTENT_CHIPS = [
    { label: 'Proteggi smartphone', query: 'custodia cover pellicola vetro smartphone Samsung' },
    { label: 'Stampa e consumabili', query: 'toner cartuccia compatibile stampante Pantum HP Brother' },
    { label: 'PC e notebook', query: 'notebook pc computer ricondizionato SSD RAM monitor' },
    { label: 'Cavi e accessori', query: 'cavo adattatore hub USB-C HDMI alimentatore' }
  ];

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }
  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function text(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function home() { return !!document.body && (document.body.classList.contains('ks-page-home') || q('.ks-home-hero-section,[id$="HomeHeroSection"]')); }

  function assetUrl(path) {
    var scripts = qa('script[src]');
    for (var i = 0; i < scripts.length; i += 1) {
      var src = scripts[i].getAttribute('src') || '';
      var pos = src.indexOf('/Public/assets/keepstore/js/');
      if (pos >= 0) return src.slice(0, pos) + path;
    }
    return path.charAt(0) === '/' ? path : '/' + path;
  }

  function ensureCss() {
    if (q('link[data-ks-ai132-css]')) return;
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = assetUrl(CSS_PATH);
    link.setAttribute('data-ks-ai132-css', '1');
    document.head.appendChild(link);
  }

  function endpointUrl(params) {
    var base = ENDPOINT;
    var scripts = qa('script[src]');
    for (var i = 0; i < scripts.length; i += 1) {
      var src = scripts[i].getAttribute('src') || '';
      var pos = src.indexOf('/Public/assets/keepstore/js/');
      if (pos >= 0) {
        base = src.slice(0, pos) + '/' + ENDPOINT;
        break;
      }
    }
    var pairs = [];
    Object.keys(params || {}).forEach(function (key) {
      var value = params[key];
      if (value == null || value === '') return;
      pairs.push(encodeURIComponent(key) + '=' + encodeURIComponent(String(value)));
    });
    return base + (pairs.length ? '?' + pairs.join('&') : '');
  }

  function normalizeUrl(url) {
    url = String(url || '').trim().replace(/&amp;/g, '&');
    if (!url) return '';
    url = url.replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '');
    return url;
  }

  function parsePrice(textValue) {
    var m = String(textValue || '').match(/(\d{1,5}(?:[\.,]\d{2}))\s*€/);
    if (!m) return 0;
    return parseFloat(m[1].replace(/\./g, '').replace(',', '.')) || 0;
  }

  function localProducts(limit) {
    var out = [];
    var seen = Object.create(null);
    qa('a[href*="articolo.aspx?id="]').forEach(function (a) {
      if (out.length >= (limit || 12)) return;
      if (a.closest('header,footer,#KsAiMarketplace132,#KsAiCatalogEngine131,#KsLocalAiSearch130,#KsSmartConsult129,.ks-home-brands-block')) return;
      var href = normalizeUrl(a.getAttribute('href'));
      var m = href.match(/[?&]id=(\d+)/i);
      var id = m ? m[1] : href;
      if (!id || seen[id]) return;
      var card = a.closest('.card-product,.ks-final-product-card,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.swiper-slide,li,article') || a.parentElement;
      if (!card) return;
      var img = q('img', card);
      var imgSrc = img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '') : '';
      if (!imgSrc || /logo|brand|payment|placeholder|nofoto|spinner/i.test(imgSrc)) return;
      var title = text(q('.name-product a,.product-title a,h6 a,h5 a,.title a', card)) || text(a);
      if (!title || title.length < 4 || /vai al catalogo|scopri|categoria/i.test(title)) return;
      var priceMatch = text(card).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
      var price = priceMatch && priceMatch.length ? priceMatch[priceMatch.length - 1] : '';
      seen[id] = 1;
      out.push({
        id: id,
        title: title,
        brand: '',
        category: 'Prodotto in pagina',
        price: price,
        priceValue: parsePrice(price),
        imageUrl: imgSrc,
        url: href,
        reason: 'Fallback locale: articolo gia renderizzato nella HOME.',
        badges: ['HOME'],
        score: 0
      });
    });
    return out;
  }

  function parseIntent(query) {
    var value = String(query || '').toLowerCase();
    var tags = [];
    if (/custodia|cover|vetro|pellicola|protegg|protezione|smartphone|samsung|iphone/.test(value)) tags.push('protezione smartphone');
    if (/toner|cartucc|stamp|pantum|hp|brother|canon|epson/.test(value)) tags.push('stampa e consumabili');
    if (/notebook|pc|computer|ricondizionat|monitor|ssd|ram/.test(value)) tags.push('pc e notebook');
    if (/usb|type|tipo c|cavo|adattatore|hub|hdmi|charger|alimentatore/.test(value)) tags.push('cavi e accessori');
    if (/offerta|promo|sconto/.test(value)) tags.push('offerte');
    if (/disponib|pronta consegna|magazzino/.test(value)) tags.push('disponibilita');
    if (/ricondizionat|usato/.test(value)) tags.push('ricondizionato');
    var budget = value.match(/(?:sotto|entro|max|massimo|fino a|meno di|non oltre)\s*(\d{1,5})(?:[\.,]\d{1,2})?\s*(?:euro|€)?/i);
    if (budget) tags.push('budget max ' + budget[1] + ' euro');
    return tags;
  }

  function readCompare() {
    try {
      var parsed = JSON.parse(localStorage.getItem(COMPARE_KEY) || '[]');
      return Array.isArray(parsed) ? parsed.slice(0, 4) : [];
    } catch (_) { return []; }
  }

  function writeCompare(list) {
    try { localStorage.setItem(COMPARE_KEY, JSON.stringify((list || []).slice(0, 4))); } catch (_) {}
  }

  function addCompare(item, root) {
    if (!item || !item.id) return;
    var list = readCompare().filter(function (x) { return String(x.id) !== String(item.id); });
    list.unshift({ id: item.id, title: item.title, price: item.price, url: item.url, imageUrl: item.imageUrl, reason: item.reason });
    writeCompare(list);
    renderCompare(root);
  }

  function removeCompare(id, root) {
    writeCompare(readCompare().filter(function (x) { return String(x.id) !== String(id); }));
    renderCompare(root);
  }

  function renderCompare(root) {
    var box = q('.ks-ai132-compare-list', root);
    if (!box) return;
    var list = readCompare();
    if (!list.length) {
      box.innerHTML = '<span>Nessun confronto. Usa “Confronta” su una card prodotto.</span>';
      return;
    }
    box.innerHTML = list.map(function (item) {
      return '<article class="ks-ai132-compare-item" data-id="' + esc(item.id) + '">' +
        (item.imageUrl ? '<img src="' + esc(item.imageUrl) + '" alt="' + esc(item.title) + '">' : '') +
        '<div><b>' + esc(item.title) + '</b><small>' + esc(item.price || item.reason || '') + '</small></div>' +
        '<button type="button" class="ks-ai132-compare-remove" data-remove="' + esc(item.id) + '" aria-label="Rimuovi confronto">×</button>' +
      '</article>';
    }).join('');
    qa('.ks-ai132-compare-remove', box).forEach(function (btn) {
      btn.addEventListener('click', function () { removeCompare(btn.getAttribute('data-remove'), root); });
    });
  }

  function badgeHtml(item) {
    var badges = [];
    if (Array.isArray(item.badges)) badges = badges.concat(item.badges);
    if (item.promo === true || item.promo === 'true') badges.push('Offerta');
    if (item.availability && parseFloat(item.availability) > 0) badges.push('Disponibile');
    if (item.reconditioned === true || item.reconditioned === 'true') badges.push('Ricondizionato');
    var seen = Object.create(null);
    return badges.filter(function (b) {
      b = String(b || '').trim();
      if (!b || seen[b.toLowerCase()]) return false;
      seen[b.toLowerCase()] = 1;
      return true;
    }).slice(0, 3).map(function (b) { return '<span>' + esc(b) + '</span>'; }).join('');
  }

  function productCard(item, index) {
    var url = item.url || ('articolo.aspx?id=' + encodeURIComponent(item.id || ''));
    var title = item.title || item.Descrizione1 || 'Articolo KeepStore';
    var img = item.imageUrl || item.img || item.Img1 || '';
    var price = item.price || item.priceText || '';
    var cat = item.category || item.CategorieDescrizione || item.brand || '';
    var payload = encodeURIComponent(JSON.stringify({ id: item.id || '', title: title, price: price, url: url, imageUrl: img, reason: item.reason || '' }));
    return '<article class="ks-ai132-card" data-rank="' + esc(index + 1) + '">' +
      '<div class="ks-ai132-rank">' + esc(index + 1) + '</div>' +
      '<a class="ks-ai132-media" href="' + esc(url) + '">' + (img ? '<img src="' + esc(img) + '" alt="' + esc(title) + '" loading="lazy" decoding="async">' : '<span></span>') + '</a>' +
      '<div class="ks-ai132-info">' +
        '<div class="ks-ai132-badges">' + badgeHtml(item) + '</div>' +
        '<p class="ks-ai132-cat">' + esc(cat || 'Catalogo KeepStore') + '</p>' +
        '<h6 class="ks-ai132-name"><a href="' + esc(url) + '">' + esc(title) + '</a></h6>' +
        (price ? '<p class="ks-ai132-price">' + esc(price) + '</p>' : '') +
        (item.reason ? '<p class="ks-ai132-reason">' + esc(item.reason) + '</p>' : '') +
        '<div class="ks-ai132-actions"><a href="' + esc(url) + '">Dettaglio</a><button type="button" class="ks-ai132-compare" data-product="' + payload + '">Confronta</button></div>' +
      '</div></article>';
  }

  function facetButtons(items, key, label) {
    var counts = Object.create(null);
    (items || []).forEach(function (item) {
      var v = String(item[key] || '').trim();
      if (!v) return;
      counts[v] = (counts[v] || 0) + 1;
    });
    var list = Object.keys(counts).sort(function (a, b) { return counts[b] - counts[a]; }).slice(0, 5);
    if (!list.length) return '';
    return '<div class="ks-ai132-facet"><b>' + esc(label) + '</b>' + list.map(function (v) {
      return '<button type="button" data-facet-key="' + esc(key) + '" data-facet-value="' + esc(v) + '">' + esc(v) + ' <small>' + counts[v] + '</small></button>';
    }).join('') + '</div>';
  }

  function answerText(query, data, mode) {
    var count = data && data.items ? data.items.length : 0;
    var tags = (data && data.parsed && data.parsed.intentTags) || parseIntent(query);
    var parts = [];
    parts.push('<b>Ragionamento marketplace:</b> ' + esc(query || 'catalogo KeepStore') + '.');
    if (tags && tags.length) parts.push('Intenti riconosciuti: ' + tags.map(esc).join(', ') + '.');
    if (data && data.summary) parts.push(esc(data.summary));
    else if (mode === 'server') parts.push('Ricerca eseguita sul catalogo database completo con ranking per codice, EAN, marca, categoria, descrizione, prezzo e disponibilita.');
    else parts.push('Endpoint non disponibile: fallback temporaneo sui prodotti gia renderizzati nella HOME.');
    parts.push(count ? ('Ho selezionato ' + count + ' risultati ordinati come un marketplace: pertinenza, prezzo, promo e disponibilita.') : 'Nessun risultato diretto: prova marca, codice, EAN o categoria.');
    return parts.join(' ');
  }

  function purgeOldAiBlocks() {
    qa('#KsSmartConsult129,#KsLocalAiSearch130,#KsAiCatalogEngine131,.ks-smart-consult,.ks-local-ai-search,.ks-ai131-section').forEach(function (node) {
      if (!node || node.id === 'KsAiMarketplace132') return;
      node.setAttribute('data-ks-ai132-removed', 'legacy-ai');
      node.style.setProperty('display', 'none', 'important');
      node.parentNode && node.parentNode.removeChild(node);
    });
  }

  function findAnchor() {
    return q('#KsHomeEditorialFinal') || q('#KsHomeBestSellerFinal') || q('#HomeLowerColumnsSection') || q('#KsHomeDepartmentShowcase') || q('.ks-home-deal-section') || q('.ks-home-hero-section');
  }

  function applyHomeMix() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-marketplace-step132');

    var hero = q('.ks-home-hero-section,[id$="HomeHeroSection"]');
    var shell = q('.ks-home-hero-shell,[id$="HomeHeroShell"]', hero || document);
    if (hero) hero.classList.add('ks-ai132-onsus-hero');
    if (shell) shell.classList.add('ks-ai132-onsus-hero-shell');

    qa('.ks-home-hero-slider img,.ks-home-hero-media img').forEach(function (img) {
      img.setAttribute('loading', 'eager');
      img.setAttribute('decoding', 'async');
    });

    qa('.ks-final-product-section,.ks-home-department-showcase,.ks-home-brands-block,.ks-final-lower-section').forEach(function (sec) {
      sec.classList.add('ks-ai132-onsus-section');
    });

    var iconBox = q('.tf-sw-iconbox,.tf-icon-box');
    if (iconBox) {
      var iconSection = iconBox.closest('.tf-sp-2,.tf-sp-3,section,div');
      if (iconSection) iconSection.classList.add('ks-ai132-onsus-iconbox');
    }
  }

  function mount() {
    if (!home()) return null;
    ensureCss();
    purgeOldAiBlocks();
    applyHomeMix();

    var existing = q('#KsAiMarketplace132');
    if (existing) return existing;

    var section = document.createElement('section');
    section.id = 'KsAiMarketplace132';
    section.className = 'tf-sp-2 ks-ai132-section ks-home-final-rendered';
    section.innerHTML = '<div class="container"><div class="ks-ai132-shell">' +
      '<div class="ks-ai132-panel">' +
        '<span class="ks-ai132-kicker">AI locale + catalogo + marketplace</span>' +
        '<h4 class="ks-ai132-title">Trova il prodotto giusto</h4>' +
        '<p class="ks-ai132-lead">Motore step 132: interpreta esigenza, compatibilita, budget, marca, codice, EAN, disponibilita e offerte. Cerca nel catalogo articoli completo e presenta i risultati come marketplace avanzato.</p>' +
        '<form class="ks-ai132-form"><input class="ks-ai132-input" type="search" autocomplete="off" placeholder="Es. toner Pantum compatibile, custodia Samsung sotto 30 euro"><button class="ks-ai132-submit" type="submit">Ragiona</button></form>' +
        '<div class="ks-ai132-switches">' +
          '<label><input type="checkbox" class="ks-ai132-filter" data-param="inStock" value="1"> Solo disponibili</label>' +
          '<label><input type="checkbox" class="ks-ai132-filter" data-param="promo" value="1"> Offerte</label>' +
          '<label><input type="checkbox" class="ks-ai132-filter" data-param="refurbished" value="1"> Ricondizionati</label>' +
        '</div>' +
        '<div class="ks-ai132-budget"><span>Budget max</span><input class="ks-ai132-max" type="number" min="0" step="1" placeholder="€"><select class="ks-ai132-sort"><option value="relevance">Pertinenza</option><option value="price_asc">Prezzo basso</option><option value="price_desc">Prezzo alto</option><option value="promo">Promo prima</option><option value="available">Disponibili prima</option><option value="newest">Novita</option></select></div>' +
        '<div class="ks-ai132-chips">' + QUICK.map(function (v) { return '<button type="button" class="ks-ai132-chip" data-query="' + esc(v) + '">' + esc(v) + '</button>'; }).join('') + '</div>' +
        '<div class="ks-ai132-intents">' + INTENT_CHIPS.map(function (v) { return '<button type="button" data-query="' + esc(v.query) + '">' + esc(v.label) + '</button>'; }).join('') + '</div>' +
        '<div class="ks-ai132-answer">Scrivi una richiesta libera o usa un esempio rapido. Il motore ragiona prima sul database, poi mostra filtri e confronti utili per decidere.</div>' +
        '<div class="ks-ai132-compare-box"><b>Confronto rapido</b><div class="ks-ai132-compare-list"></div></div>' +
      '</div>' +
      '<div class="ks-ai132-results">' +
        '<div class="ks-ai132-results-head"><div><span class="ks-ai132-results-kicker">Risposta e prodotti consigliati</span><h5 class="ks-ai132-results-title">Marketplace intelligente</h5></div><span class="ks-ai132-count">0 articoli analizzati</span></div>' +
        '<div class="ks-ai132-facets"></div>' +
        '<div class="ks-ai132-grid"></div>' +
      '</div>' +
    '</div></div>';

    var anchor = findAnchor();
    if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(section, anchor.nextSibling);
    else (q('main') || document.body).appendChild(section);
    bind(section);
    renderCompare(section);
    return section;
  }

  function readFilters(root, query) {
    var params = { q: query || '', limit: 12, mode: 'marketplace' };
    qa('.ks-ai132-filter', root).forEach(function (input) {
      if (input.checked) params[input.getAttribute('data-param')] = input.value || '1';
    });
    var max = q('.ks-ai132-max', root);
    if (max && max.value) params.priceMax = max.value;
    var sort = q('.ks-ai132-sort', root);
    if (sort && sort.value) params.sort = sort.value;
    return params;
  }

  function setLoading(root, query) {
    q('.ks-ai132-answer', root).innerHTML = '<b>Sto cercando:</b> ' + esc(query) + '. Analizzo catalogo, prezzo, disponibilita, offerte e compatibilita...';
    q('.ks-ai132-count', root).textContent = 'ricerca in corso';
    q('.ks-ai132-facets', root).innerHTML = '';
    q('.ks-ai132-grid', root).innerHTML = '<div class="ks-ai132-empty">Ricerca marketplace in corso...</div>';
  }

  function bindResultActions(root, items) {
    qa('.ks-ai132-compare', root).forEach(function (btn) {
      btn.addEventListener('click', function () {
        try {
          var item = JSON.parse(decodeURIComponent(btn.getAttribute('data-product') || ''));
          addCompare(item, root);
        } catch (_) {
          var index = parseInt(btn.closest('.ks-ai132-card').getAttribute('data-rank'), 10) - 1;
          addCompare(items[index], root);
        }
      });
    });
  }

  function bindFacets(root) {
    qa('[data-facet-key]', root).forEach(function (btn) {
      btn.addEventListener('click', function () {
        var input = q('.ks-ai132-input', root);
        var value = btn.getAttribute('data-facet-value') || text(btn);
        input.value = (input.value ? input.value + ' ' : '') + value;
        search(root, input.value);
      });
    });
  }

  function renderResults(root, query, data, mode) {
    var items = (data && data.items) || [];
    var grid = q('.ks-ai132-grid', root);
    var answer = q('.ks-ai132-answer', root);
    var count = q('.ks-ai132-count', root);
    var facets = q('.ks-ai132-facets', root);

    count.textContent = items.length + ' articoli analizzati';
    answer.innerHTML = answerText(query, data || { items: items }, mode);
    facets.innerHTML = facetButtons(items, 'brand', 'Brand') + facetButtons(items, 'category', 'Categorie');

    if (!items.length) {
      grid.innerHTML = '<div class="ks-ai132-empty">Nessun articolo trovato. Prova con codice, EAN, marca, compatibilita o categoria.</div>';
      return;
    }

    grid.innerHTML = items.slice(0, 12).map(productCard).join('');
    bindResultActions(root, items);
    bindFacets(root);
  }

  function search(root, query) {
    query = String(query || '').trim() || DEFAULT_QUERY;
    var input = q('.ks-ai132-input', root);
    if (input) input.value = query;
    try { localStorage.setItem(STORAGE_KEY, query); } catch (_) {}
    setLoading(root, query);

    var params = readFilters(root, query);
    fetch(endpointUrl(params), { credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
      .then(function (res) { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); })
      .then(function (data) {
        if (!data || data.ok === false) throw new Error('endpoint unavailable');
        renderResults(root, query, data, 'server');
      })
      .catch(function () {
        renderResults(root, query, { items: localProducts(12), summary: '' }, 'local');
      });
  }

  function bind(root) {
    var form = q('.ks-ai132-form', root);
    var input = q('.ks-ai132-input', root);
    form.addEventListener('submit', function (ev) {
      ev.preventDefault();
      search(root, input.value);
    });
    qa('.ks-ai132-chip,.ks-ai132-intents button', root).forEach(function (btn) {
      btn.addEventListener('click', function () {
        qa('.ks-ai132-chip,.ks-ai132-intents button', root).forEach(function (b) { b.setAttribute('aria-pressed', 'false'); });
        btn.setAttribute('aria-pressed', 'true');
        search(root, btn.getAttribute('data-query') || text(btn));
      });
    });
    qa('.ks-ai132-filter,.ks-ai132-sort,.ks-ai132-max', root).forEach(function (node) {
      node.addEventListener('change', function () { search(root, input.value || DEFAULT_QUERY); });
    });
  }

  function boot() {
    var root = mount();
    if (!root) return;
    var initial = '';
    try { initial = localStorage.getItem(STORAGE_KEY) || ''; } catch (_) {}
    window.setTimeout(function () { search(root, initial || DEFAULT_QUERY); }, 350);
    window.KeepStoreAiMarketplace132 = { search: function (query) { search(root, query); }, root: root };
  }

  ready(boot);
})();
