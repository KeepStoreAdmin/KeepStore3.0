(function () {
  'use strict';

  var ENDPOINT = 'ks_ai_catalog_search.ashx';
  var STORAGE_KEY = 'ks_ai_catalog_engine_131_last_query';
  var DEFAULT_QUERY = 'custodia Samsung sotto 30 euro';
  var QUICK = [
    'custodia Samsung sotto 30 euro',
    'toner compatibile Pantum',
    'notebook ricondizionato',
    'adattatore USB-C',
    'pen drive Kingston',
    'pellicola vetro Samsung'
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
    if (q('link[data-ks-ai131-css]')) return;
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = assetUrl('/Public/assets/keepstore/css/ks-ai-catalog-engine.css');
    link.setAttribute('data-ks-ai131-css', '1');
    document.head.appendChild(link);
  }

  function endpointUrl(query, limit) {
    var base = ENDPOINT;
    try {
      var scripts = qa('script[src]');
      for (var i = 0; i < scripts.length; i += 1) {
        var src = scripts[i].getAttribute('src') || '';
        var pos = src.indexOf('/Public/assets/keepstore/js/');
        if (pos >= 0) {
          base = src.slice(0, pos) + '/' + ENDPOINT;
          break;
        }
      }
    } catch (_) {}
    return base + '?q=' + encodeURIComponent(query || '') + '&limit=' + encodeURIComponent(String(limit || 8));
  }

  function normalizeUrl(url) {
    url = String(url || '').trim().replace(/&amp;/g, '&');
    if (!url) return '';
    url = url.replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '');
    return url;
  }

  function localProducts(limit) {
    var out = [];
    var seen = Object.create(null);
    qa('a[href*="articolo.aspx?id="]').forEach(function (a) {
      if (out.length >= (limit || 8)) return;
      if (a.closest('header,footer,#KsAiCatalogEngine131,.ks-home-brands-block')) return;
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
      seen[id] = 1;
      out.push({
        id: id,
        title: title,
        brand: '',
        category: 'Prodotto in pagina',
        price: priceMatch && priceMatch.length ? priceMatch[priceMatch.length - 1] : '',
        imageUrl: imgSrc,
        url: href,
        reason: 'Fallback locale: articolo gia renderizzato nella pagina.'
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
    var budget = value.match(/(?:sotto|entro|max|massimo|fino a)\s*(\d{1,5})(?:[\.,]\d{1,2})?\s*(?:euro|€)?/i);
    if (budget) tags.push('budget max ' + budget[1] + ' euro');
    return tags;
  }

  function answerText(query, count, mode) {
    var tags = parseIntent(query);
    var parts = [];
    parts.push('<b>Analisi richiesta:</b> ' + esc(query || 'catalogo KeepStore') + '.');
    if (tags.length) parts.push('Ho riconosciuto: ' + tags.map(esc).join(', ') + '.');
    if (mode === 'server') parts.push('Ricerca eseguita sul catalogo database tramite endpoint interno, non solo sui prodotti della HOME.');
    else parts.push('Endpoint non disponibile: risultati provvisori presi dai prodotti gia presenti nella pagina corrente.');
    parts.push(count ? ('Trovati ' + count + ' articoli ordinati per pertinenza commerciale.') : 'Nessun risultato diretto: prova con marca, codice, EAN o esigenza piu specifica.');
    return parts.join(' ');
  }

  function card(item) {
    var url = item.url || ('articolo.aspx?id=' + encodeURIComponent(item.id || ''));
    var title = item.title || item.Descrizione1 || 'Articolo KeepStore';
    var img = item.imageUrl || item.img || item.Img1 || '';
    var price = item.price || item.priceText || '';
    var cat = item.category || item.CategorieDescrizione || item.brand || '';
    return '<article class="ks-ai131-card">' +
      '<a class="ks-ai131-media" href="' + esc(url) + '">' + (img ? '<img src="' + esc(img) + '" alt="' + esc(title) + '" loading="lazy" decoding="async">' : '<span></span>') + '</a>' +
      '<div class="ks-ai131-info">' +
      '<p class="ks-ai131-cat">' + esc(cat) + '</p>' +
      '<h6 class="ks-ai131-name"><a href="' + esc(url) + '">' + esc(title) + '</a></h6>' +
      (price ? '<p class="ks-ai131-price">' + esc(price) + '</p>' : '') +
      (item.reason ? '<p class="ks-ai131-reason">' + esc(item.reason) + '</p>' : '') +
      '</div></article>';
  }

  function findAnchor() {
    return q('#KsHomeDepartmentShowcase') || q('.ks-home-department-showcase') || q('[id$="HomeRecentlyViewedSection"]') || q('.ks-home-best-section') || q('.ks-home-deal-section') || q('.ks-home-hero-section');
  }

  function mount() {
    if (!home()) return null;
    ensureCss();
    var existing = q('#KsAiCatalogEngine131');
    if (existing) return existing;
    var section = document.createElement('section');
    section.id = 'KsAiCatalogEngine131';
    section.className = 'tf-sp-2 ks-ai131-section ks-home-final-rendered';
    section.innerHTML = '<div class="container"><div class="ks-ai131-shell">' +
      '<div class="ks-ai131-panel">' +
        '<span class="ks-ai131-kicker">AI locale + catalogo DB</span>' +
        '<h4 class="ks-ai131-title">Chiedimi cosa stai cercando</h4>' +
        '<p class="ks-ai131-lead">Motore KeepStore step 131: interpreta esigenza, budget, marca, codice o EAN e interroga il catalogo articoli completo.</p>' +
        '<form class="ks-ai131-form"><input class="ks-ai131-input" type="search" autocomplete="off" placeholder="Es. toner Pantum compatibile, custodia Samsung sotto 30 euro"><button class="ks-ai131-submit" type="submit">Ragiona</button></form>' +
        '<div class="ks-ai131-chips">' + QUICK.map(function (v) { return '<button type="button" class="ks-ai131-chip" data-query="' + esc(v) + '">' + esc(v) + '</button>'; }).join('') + '</div>' +
        '<div class="ks-ai131-answer">Scrivi una richiesta libera o usa un esempio rapido. Il sistema usa prima il database articoli e solo in fallback la pagina corrente.</div>' +
        '<div class="ks-ai131-tags"><a href="articoli.aspx">Catalogo</a><a href="articoli.aspx?q=Samsung">Samsung</a><a href="articoli.aspx?q=Pantum">Pantum</a><a href="articoli.aspx?q=USB-C">USB-C</a></div>' +
      '</div>' +
      '<div class="ks-ai131-results">' +
        '<div class="ks-ai131-results-head"><div><span class="ks-ai131-results-kicker">Risposta e prodotti consigliati</span><h5 class="ks-ai131-results-title">Consigli automatici</h5></div><span class="ks-ai131-count">0 articoli analizzati</span></div>' +
        '<div class="ks-ai131-grid"></div>' +
      '</div>' +
    '</div></div>';
    var anchor = findAnchor();
    if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(section, anchor.nextSibling);
    else (q('main') || document.body).appendChild(section);
    bind(section);
    return section;
  }

  function setLoading(root, query) {
    q('.ks-ai131-answer', root).innerHTML = '<b>Sto cercando:</b> ' + esc(query) + '. Interrogo il catalogo articoli KeepStore...';
    q('.ks-ai131-count', root).textContent = 'ricerca in corso';
    q('.ks-ai131-grid', root).innerHTML = '<div class="ks-ai131-empty">Ricerca catalogo in corso...</div>';
  }

  function renderResults(root, query, items, mode) {
    var grid = q('.ks-ai131-grid', root);
    var answer = q('.ks-ai131-answer', root);
    var count = q('.ks-ai131-count', root);
    items = items || [];
    count.textContent = items.length + ' articoli analizzati';
    answer.innerHTML = answerText(query, items.length, mode);
    if (!items.length) {
      grid.innerHTML = '<div class="ks-ai131-empty">Nessun articolo trovato. Prova con codice, EAN, marca o categoria.</div>';
      return;
    }
    grid.innerHTML = items.slice(0, 8).map(card).join('');
  }

  function search(root, query) {
    query = String(query || '').trim();
    if (!query) query = DEFAULT_QUERY;
    try { localStorage.setItem(STORAGE_KEY, query); } catch (_) {}
    q('.ks-ai131-input', root).value = query;
    setLoading(root, query);
    fetch(endpointUrl(query, 8), { credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
      .then(function (res) { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); })
      .then(function (data) {
        if (!data || data.ok === false) throw new Error('endpoint unavailable');
        var items = data && data.items ? data.items : [];
        renderResults(root, query, items, 'server');
      })
      .catch(function () {
        renderResults(root, query, localProducts(8), 'local');
      });
  }

  function bind(root) {
    var form = q('.ks-ai131-form', root);
    var input = q('.ks-ai131-input', root);
    form.addEventListener('submit', function (ev) {
      ev.preventDefault();
      search(root, input.value);
    });
    qa('.ks-ai131-chip', root).forEach(function (btn) {
      btn.addEventListener('click', function () {
        qa('.ks-ai131-chip', root).forEach(function (b) { b.setAttribute('aria-pressed', 'false'); });
        btn.setAttribute('aria-pressed', 'true');
        search(root, btn.getAttribute('data-query') || text(btn));
      });
    });
  }

  function boot() {
    var root = mount();
    if (!root) return;
    var initial = '';
    try { initial = localStorage.getItem(STORAGE_KEY) || ''; } catch (_) {}
    window.setTimeout(function () { search(root, initial || DEFAULT_QUERY); }, 350);
  }

  ready(boot);
})();
