/* Progressive shopping guide: explicit preferences, server-owned commercial facts.
   Memory only. No telemetry, storage, cookies or automatic search. */
(function (host, factory) {
  'use strict';
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else host.KeepStoreShoppingGuide = { init: api.init };
}(typeof window !== 'undefined' ? window : this, function () {
  'use strict';
  var MAX_TEXT = 80, MAX_BODY = 65536, MAX_RESULTS = 6, MAX_HISTORY = 8;
  var instances = typeof WeakSet !== 'undefined' ? new WeakSet() : null;
  function clean(value) { return String(value || '').replace(/[\u0000-\u001f\u007f\s]+/g, ' ').trim(); }
  function blank() { return { q: '', st: 0, pmin: '0', pmax: '0', disponibile: false, ordinamento: '' }; }
  function copy(b) { return Object.assign({}, b); }
  function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
  function decimal(raw) {
    if (!/^(?:0|[1-9][0-9]{0,7})(?:[.,][0-9]{1,2})?$/.test(raw)) return null;
    var parts = raw.replace(',', '.').split('.');
    return parts[0] + (parts[1] && /[1-9]/.test(parts[1]) ? '.' + parts[1].replace(/0+$/, '') : '');
  }
  function parseCommand(raw) {
    var text = clean(raw), lower = text.toLocaleLowerCase('it-IT'), commands = {
      'solo disponibili': { disponibile: true }, 'includi non disponibili': { disponibile: false },
      'senza limite di prezzo': { pmin: '0', pmax: '0' },
      'prima i meno costosi': { ordinamento: 'p_basso' }, 'ordina per pertinenza': { ordinamento: '' }
    };
    if (!text || text.length > MAX_TEXT) return { kind: 'clarify', message: 'Scrivi una preferenza di massimo 80 caratteri.' };
    if (lower === 'annulla' || lower === 'ricomincia') return { kind: lower };
    if (Object.prototype.hasOwnProperty.call(commands, lower)) return { kind: 'patch', patch: commands[lower] };
    var match = /^(?:massimo|fino a) (.+?)(?: euro| €)?$/.exec(lower);
    if (match) {
      var amount = decimal(match[1]);
      if (amount && amount !== '0') return { kind: 'patch', patch: { pmax: amount } };
      return { kind: 'clarify', message: 'Indica un importo senza separatori delle migliaia, ad esempio “massimo 1000 euro” oppure “massimo 500,50 euro”.' };
    }
    return { kind: 'unknown', text: text };
  }
  function queryText(product, detail) {
    var primary = clean(product), combined = clean(primary + ' ' + clean(detail));
    if (primary.length < 2 || combined.length > MAX_TEXT) throw new Error('query');
    return combined;
  }
  function urls(base, endpoint) {
    var directory = new URL(base), target = new URL(endpoint, directory);
    if (!/^https?:$/.test(directory.protocol) || directory.username || directory.password || directory.search || directory.hash ||
        !directory.pathname.endsWith('/') || target.origin !== directory.origin || target.pathname !== directory.pathname + 'search_suggest.aspx' ||
        target.search || target.hash || target.username || target.password) throw new Error('configuration');
    return { base: directory, endpoint: target, catalog: new URL('articoli.aspx', directory), product: new URL('articolo.aspx', directory) };
  }
  function catalogURL(b, paths) {
    var target = new URL(paths.catalog.href);
    if (b.q) target.searchParams.set('q', b.q);
    if (b.st) target.searchParams.set('st', String(b.st));
    if (b.pmin !== '0') target.searchParams.set('pmin', b.pmin);
    if (b.pmax !== '0') target.searchParams.set('pmax', b.pmax);
    if (b.disponibile) target.searchParams.set('disponibile', '1');
    if (b.ordinamento) target.searchParams.set('ordinamento', b.ordinamento);
    return target;
  }
  function requestURL(b, paths) {
    var target = catalogURL(b, paths);
    target.pathname = paths.endpoint.pathname;
    target.searchParams.set('mode', 'guided');
    target.searchParams.set('limit', String(MAX_RESULTS));
    return target.href;
  }
  function text(value, max, optional) {
    if (optional && (value === null || typeof value === 'undefined')) return '';
    if (typeof value !== 'string' || value.length > max || (!optional && !value.trim())) throw new Error('payload');
    return value;
  }
  function object(value) { return value && typeof value === 'object' && !Array.isArray(value); }
  function keys(value, allowed) {
    if (!object(value) || Object.keys(value).length !== allowed.length || Object.keys(value).some(function (key) { return allowed.indexOf(key) < 0; })) throw new Error('payload');
  }
  function localURL(raw, target) {
    text(raw, 2048, false);
    var parsed = new URL(raw, target);
    if (parsed.origin !== target.origin || parsed.pathname !== target.pathname || parsed.username || parsed.password || parsed.hash) throw new Error('payload');
    var seen = new Set();
    parsed.searchParams.forEach(function (_, key) { if (seen.has(key)) throw new Error('payload'); seen.add(key); });
    return parsed;
  }
  function imageURL(raw, paths) {
    if (!raw) return '';
    text(raw, 2048, true);
    try {
      // Check the original spelling before URL removes dot segments or controls.
      if (raw !== raw.trim() || /[\u0000-\u001f\u007f\\?#]/.test(raw) || /%(?:2f|5c)/i.test(raw) ||
          /^(?:[a-z][a-z0-9+.-]*:)?\/\/[^/]*@/i.test(raw) ||
          (/^[a-z][a-z0-9+.-]*:/i.test(raw) && !/^https?:\/\/[^/]/i.test(raw))) return '';
      var decoded = decodeURIComponent(raw);
      if (/[\u0000-\u001f\u007f\\]/.test(decoded) || decoded.indexOf('..') >= 0 ||
          /(?:^|\/)\.(?:\/|$)/.test(decoded) || /%[0-9a-f]{2}/i.test(decoded)) return '';
      // ThemeManager emits this root-relative product prefix even under a virtual directory.
      // Only that canonical form is rebased; already scoped URLs keep their original path.
      var productRoot = '/Public/assets/images/articoli/';
      var source = raw.indexOf(productRoot) === 0 ? paths.base.pathname + raw.slice(1) : raw;
      var parsed = new URL(source, paths.base);
      // Unrecognised/external media use a neutral placeholder, never a remote probe.
      if (parsed.origin !== paths.base.origin || parsed.username || parsed.password || parsed.hash || parsed.search ||
          parsed.pathname.toLowerCase().indexOf((paths.base.pathname + 'Public/assets/images/').toLowerCase()) !== 0 ||
          !/\.(?:png|jpe?g|webp|gif)$/i.test(parsed.pathname)) return '';
      var localPath = parsed.pathname.slice(paths.base.pathname.length), segments = decodeURIComponent(localPath).split('/');
      if (segments.some(function (part) { return !part || /[<>:"|?*\\]/.test(part) || /[ .]$/.test(part); }) ||
          (localPath.toLowerCase().indexOf(productRoot.slice(1).toLowerCase()) === 0 && segments.length !== 5)) return '';
      return parsed.href;
    } catch (_) { return ''; }
  }
  function validate(payload, brief, paths) {
    if (!object(payload) || payload.ok !== true || payload.mode !== 'guided' || payload.recent !== false || payload.query !== brief.q ||
        !Array.isArray(payload.suggestions) || payload.suggestions.length > MAX_RESULTS || payload.total !== payload.suggestions.length) throw new Error('payload');
    var meta = payload.guided;
    keys(meta, ['version', 'criteria', 'displayLabel', 'returnedCount', 'selectionLimited', 'limit']);
    keys(meta.criteria, ['q', 'st', 'pmin', 'pmax', 'disponibile', 'ordinamento']);
    if (meta.version !== 1 || meta.selectionLimited !== true || meta.limit !== MAX_RESULTS ||
        meta.returnedCount !== payload.suggestions.length || Object.keys(brief).some(function (key) { return meta.criteria[key] !== brief[key]; })) throw new Error('payload');
    var label = text(meta.displayLabel, 100, false);
    if (['Prezzi visualizzati IVA inclusa', 'Prezzi visualizzati IVA esclusa'].indexOf(label) < 0) throw new Error('payload');
    var actual = localURL(payload.catalogUrl, paths.catalog), expected = catalogURL(brief, paths);
    if (Array.from(actual.searchParams).length !== Array.from(expected.searchParams).length ||
        Array.from(expected.searchParams).some(function (entry) { return actual.searchParams.get(entry[0]) !== entry[1]; })) throw new Error('payload');
    var seen = new Set();
    var items = payload.suggestions.map(function (row) {
      if (!object(row) || !Number.isSafeInteger(row.id) || row.id < 1 || row.id > 2147483647 ||
          !Number.isSafeInteger(row.TCId) || (row.TCId !== -1 && (row.TCId < 1 || row.TCId > 2147483647))) throw new Error('payload');
      var key = row.id + ':' + row.TCId;
      if (seen.has(key)) throw new Error('payload');
      seen.add(key);
      var link = localURL(row.url, paths.product);
      if (link.searchParams.get('id') !== String(row.id) || (row.TCId > 0 ? link.searchParams.get('TCId') !== String(row.TCId) : link.searchParams.has('TCId')) ||
          Array.from(link.searchParams.keys()).some(function (name) { return name !== 'id' && name !== 'TCId'; })) throw new Error('payload');
      if (typeof row.priceValue !== 'number' || !Number.isFinite(row.priceValue) || row.priceValue <= 0 ||
          typeof row.isOffer !== 'boolean' || typeof row.isRefurbished !== 'boolean' ||
          (row.availability !== null && (typeof row.availability !== 'number' || !Number.isFinite(row.availability)))) throw new Error('payload');
      return { key: key, id: row.id, tc: row.TCId, url: link.href, title: text(row.title, 500, false),
        price: text(row.price, 80, false), brand: text(row.brand, 180, true), category: text(row.category, 180, true),
        code: text(row.code, 120, true), ean: text(row.ean, 120, true),
        image: imageURL(row.image, paths), fallback: imageURL(row.image_fallback, paths),
        availability: row.availability, offer: row.isOffer, refurbished: row.isRefurbished };
    });
    return { items: items, label: label, catalog: actual.href };
  }
  function stock(item) { return item.availability === null ? 'Disponibilità: dato non disponibile' : item.availability > 0 ? 'Disponibile' : 'Non disponibile'; }
  function reason(item, b) {
    var q = b.q.toLocaleLowerCase('it-IT');
    if ((item.code && item.code.toLocaleLowerCase('it-IT') === q) || (item.ean && item.ean.toLocaleLowerCase('it-IT') === q)) return 'Corrispondenza esatta del codice cercato.';
    if (item.offer) return 'Offerta applicabile dichiarata dal negozio.';
    if (b.disponibile && item.availability > 0) return 'Disponibilità dichiarata, con il filtro “Solo disponibili” attivo.';
    if (item.brand) return 'Marca indicata nel catalogo: ' + item.brand + '.';
    if (item.category) return 'Categoria indicata nel catalogo: ' + item.category + '.';
    return 'Articolo restituito per la tua ricerca. Verifica i dettagli nella scheda.';
  }
  function init(root) {
    if (!root || !instances || instances.has(root)) return;
    var win = root.ownerDocument.defaultView, doc = root.ownerDocument;
    var find = function (selector) { return root.querySelector(selector); };
    var fields = find('[data-ks-guide-fields]'), input = find('#ksGuideQuery'), detail = find('#ksGuideDetail'),
      prepare = find('[data-ks-guide-prepare]'), reset = find('[data-ks-guide-reset]'), undo = find('[data-ks-guide-undo]'),
      summary = find('[data-ks-guide-summary]'), idle = find('[data-ks-guide-idle]'), chips = find('[data-ks-guide-chips]'),
      refine = find('[data-ks-guide-refine]'), command = find('#ksGuideCommand'), apply = find('[data-ks-guide-apply]'),
      newQuery = find('[data-ks-guide-new-query]'), output = find('[data-ks-guide-output]'), status = find('[data-ks-guide-status]'),
      recovery = find('[data-ks-guide-recovery]'), results = find('[data-ks-guide-results]'), comparison = find('[data-ks-guide-comparison]');
    if (![fields, input, detail, prepare, reset, undo, summary, idle, chips, refine, command, apply, newQuery, output, status, recovery, results, comparison].every(Boolean) ||
        !win.fetch || !win.AbortController || !win.URL || !win.Promise) return;
    var paths;
    try {
      paths = urls(new URL(root.getAttribute('data-ks-guide-base'), win.location.href).href, root.getAttribute('data-ks-guide-endpoint'));
      if (paths.base.origin !== win.location.origin) return;
    } catch (_) { return; }
    var choices = Array.from(root.querySelectorAll('[data-ks-guide-department]')), departments = new Map();
    departments.set(0, 'Tutti i reparti');
    choices.forEach(function (button) {
      var raw = button.getAttribute('data-ks-guide-department'), id = 0;
      try {
        if (raw) {
          var link = localURL(raw, paths.catalog), value = link.searchParams.get('st');
          if (!/^[1-9][0-9]{0,9}$/.test(value || '') || Number(value) > 2147483647 || Array.from(link.searchParams).length !== 1) throw new Error('department');
          id = Number(value);
          departments.set(id, clean(button.textContent).slice(0, 180));
        }
        button.setAttribute('data-ks-guide-sector', String(id));
      } catch (_) { button.disabled = true; button.hidden = true; }
    });
    var state = { phase: 'idle', confirmed: null, draftSector: 0, history: [], request: null, result: null, selected: [], generation: 0, unknown: '' };
    function node(tag, label, className) {
      var element = doc.createElement(tag);
      if (label !== undefined) element.textContent = label;
      if (className) element.className = className;
      return element;
    }
    function button(label, action, className) {
      var element = node('button', label, className || 'ks-guide-edit');
      element.type = 'button'; element.addEventListener('click', action); return element;
    }
    function link(label, href, className) {
      var element = node('a', label, className || 'ks-guide-primary'); element.href = href; return element;
    }
    function phase(value) { state.phase = value; root.setAttribute('data-ks-guide-state', value); }
    function announce(message) { output.hidden = false; status.textContent = message; }
    function invalidate(next) {
      state.generation++;
      if (state.request) { win.clearTimeout(state.request.timer); state.request.controller.abort(); state.request = null; }
      state.result = null; state.selected = [];
      results.replaceChildren(); comparison.replaceChildren(); recovery.replaceChildren();
      root.removeAttribute('aria-busy'); prepare.removeAttribute('aria-disabled');
      phase(next);
    }
    function syncFields(b) {
      input.value = b.q; detail.value = ''; state.draftSector = b.st;
      choices.forEach(function (choice) { choice.setAttribute('aria-pressed', Number(choice.getAttribute('data-ks-guide-sector')) === b.st ? 'true' : 'false'); });
    }
    function canRefineConfirmed() {
      // syncFields stores the confirmed query in the product field and clears detail.
      // Even redistributing the same words between those fields is an unconfirmed edit.
      if (!state.confirmed || (clean(input.value) === state.confirmed.q && !clean(detail.value) && state.draftSector === state.confirmed.st)) return true;
      announce('La richiesta è in modifica. Premi “Mostra i prodotti” per confermarla.');
      return false;
    }
    function summaryView() {
      var b = state.confirmed;
      summary.hidden = !b || !b.q; idle.hidden = !summary.hidden;
      refine.hidden = summary.hidden; refine.disabled = summary.hidden;
      undo.disabled = !state.history.length;
      chips.replaceChildren();
      if (!b || !b.q) return;
      var entries = [['q', 'Ricerca: ' + b.q], ['st', 'Reparto: ' + departments.get(b.st)],
        ['pmax', b.pmax === '0' ? 'Budget: senza limite' : 'Massimo: ' + b.pmax.replace('.', ',') + ' €'],
        ['disponibile', b.disponibile ? 'Solo disponibili' : 'Disponibili e non disponibili'],
        ['ordinamento', b.ordinamento ? 'Prezzo crescente' : 'Pertinenza']];
      entries.forEach(function (entry) {
        if (b[entry[0]] === blank()[entry[0]]) { chips.appendChild(node('span', entry[1], 'ks-guide-chip ks-guide-chip-default')); return; }
        var chip = button(entry[1] + ' ×', function () {
          if (!canRefineConfirmed()) return;
          var next = copy(state.confirmed); next[entry[0]] = blank()[entry[0]];
          if (entry[0] === 'pmax') next.pmin = '0';
          if (!next.q) input.focus(); else prepare.focus();
          accept(next, true);
          announce('Preferenza rimossa: ' + entry[1] + (next.q ? '. Caricamento della selezione.' : '. Indica il prodotto da cercare.'));
        }, 'ks-guide-chip');
        chip.setAttribute('aria-label', 'Rimuovi ' + entry[1]); chips.appendChild(chip);
      });
    }
    function remember(b) { if (b) { state.history.push(copy(b)); if (state.history.length > MAX_HISTORY) state.history.shift(); } }
    function accept(b, record) {
      if (state.request && same(state.request.brief, b)) return;
      if (record && !same(state.confirmed, b)) remember(state.confirmed);
      state.confirmed = copy(b); state.unknown = ''; newQuery.hidden = true; command.value = '';
      syncFields(b); summaryView();
      if (!b.q) { invalidate('editing'); announce('Indica il prodotto da cercare.'); return; }
      search(b);
    }
    function resetGuide() {
      remember(state.confirmed); state.confirmed = null; state.unknown = '';
      syncFields(blank()); command.value = ''; newQuery.hidden = true;
      invalidate('idle'); summaryView(); announce('La guida è pronta per una nuova ricerca.'); input.focus();
    }
    function undoGuide() {
      if (!state.history.length) { announce('Non ci sono modifiche da annullare.'); return; }
      accept(state.history.pop(), false);
    }
    function prepareSearch() {
      try {
        var b = copy(state.confirmed || blank());
        b.q = queryText(input.value, detail.value); b.st = state.draftSector;
        input.removeAttribute('aria-invalid'); detail.removeAttribute('aria-invalid');
        accept(b, true);
      } catch (_) {
        invalidate('editing'); announce('Scrivi almeno 2 caratteri. Prodotto e dettaglio possono contenere al massimo 80 caratteri in tutto.');
        input.setAttribute('aria-invalid', 'true'); detail.setAttribute('aria-invalid', 'true');
        input.focus();
      }
    }
    function runCommand(raw) {
      var parsed = parseCommand(raw);
      if (parsed.kind === 'ricomincia') { resetGuide(); return; }
      if (parsed.kind === 'annulla') { undoGuide(); return; }
      if (!state.confirmed || !state.confirmed.q) { announce('Prima indica il prodotto da cercare.'); return; }
      if (!canRefineConfirmed()) return;
      state.unknown = ''; newQuery.hidden = true;
      if (parsed.kind === 'patch') { accept(Object.assign(copy(state.confirmed), parsed.patch), true); return; }
      invalidate('editing');
      if (parsed.kind === 'unknown') {
        state.unknown = parsed.text; newQuery.hidden = false;
        announce('Preferenza non riconosciuta. Puoi usare questo testo come nuova ricerca, solo confermando il pulsante.');
      } else announce(parsed.message);
    }
    function productCard(item) {
      var article = node('article', undefined, 'ks-guide-card');
      var media = node('div', 'Immagine non disponibile', 'ks-guide-media');
      if (item.image || item.fallback) {
        var image = doc.createElement('img'), fallback = item.fallback;
        image.alt = ''; image.loading = 'lazy'; image.decoding = 'async'; image.width = 180; image.height = 140;
        image.src = item.image || fallback;
        image.addEventListener('error', function () {
          if (fallback && image.src !== fallback) { image.src = fallback; fallback = ''; }
          else { media.replaceChildren(doc.createTextNode('Immagine non disponibile')); }
        });
        media.replaceChildren(image);
      }
      article.appendChild(media);
      var heading = node('h4'); heading.appendChild(link(item.title, item.url, 'ks-guide-product-link')); article.appendChild(heading);
      var category = node('p', [item.brand, item.category].filter(Boolean).join(' · '), 'ks-guide-hint');
      if (!category.textContent) category.setAttribute('aria-hidden', 'true');
      article.appendChild(category);
      article.appendChild(node('p', item.price, 'ks-guide-price'));
      article.appendChild(node('p', stock(item), 'ks-guide-stock'));
      if (item.offer || item.refurbished) article.appendChild(node('p', [item.offer ? 'Offerta applicabile' : '', item.refurbished ? 'Ricondizionato' : ''].filter(Boolean).join(' · '), 'ks-guide-badge'));
      article.appendChild(node('p', 'Perché compare: ' + reason(item, state.confirmed), 'ks-guide-reason'));
      article.appendChild(link('Vedi prodotto', item.url, 'ks-guide-product-cta'));
      var label = node('label', undefined, 'ks-guide-check'), check = doc.createElement('input');
      check.type = 'checkbox'; check.setAttribute('data-ks-guide-compare-key', item.key);
      check.addEventListener('change', function () {
        if (check.checked && state.selected.length === 3) { check.checked = false; announce('Puoi confrontare al massimo tre prodotti.'); return; }
        state.selected = check.checked ? state.selected.concat([item.key]) : state.selected.filter(function (key) { return key !== item.key; });
        renderCompare();
      });
      label.append(check, doc.createTextNode('Confronta ' + item.title)); article.appendChild(label);
      return article;
    }
    function renderCompare() {
      comparison.replaceChildren();
      if (!state.result || !state.selected.length) return;
      var items = state.result.items.filter(function (item) { return state.selected.indexOf(item.key) >= 0; });
      if (items.length < 2) { comparison.appendChild(node('p', 'Seleziona ancora un prodotto per confrontare i dati.')); return; }
      comparison.appendChild(node('h3', 'Differenze a colpo d’occhio'));
      comparison.appendChild(node('p', 'Solo i prodotti della selezione corrente. ' + state.result.label, 'ks-guide-hint'));
      var grid = node('div', undefined, 'ks-guide-compare-grid');
      grid.setAttribute('role', 'region'); grid.setAttribute('aria-label', 'Confronto prodotti, scorri orizzontalmente se necessario'); grid.tabIndex = 0;
      grid.style.setProperty('--ks-guide-columns', String(items.length));
      var table = node('table'), head = node('thead'), titles = node('tr'), data = node('tbody');
      var first = node('th', 'Dato'); first.scope = 'col'; titles.appendChild(first);
      items.forEach(function (item) {
        var column = node('th', undefined, 'ks-guide-compare-item'); column.scope = 'col';
        var title = node('h4'); title.appendChild(link(item.title, item.url, 'ks-guide-product-link')); column.appendChild(title);
        titles.appendChild(column);
      });
      [['Prezzo', function (item) { return item.price; }], ['Disponibilità', stock],
        ['Marca', function (item) { return item.brand; }], ['Categoria', function (item) { return item.category; }],
        ['Codice', function (item) { return item.code; }], ['Condizione', function (item) { return item.refurbished ? 'Ricondizionato' : ''; }],
        ['Offerta', function (item) { return item.offer ? 'Applicabile' : 'Non indicata'; }]].forEach(function (field) {
          var row = node('tr'), label = node('th', field[0]); label.scope = 'row'; row.appendChild(label);
          items.forEach(function (item) { row.appendChild(node('td', field[1](item) || 'Dato non disponibile')); });
          data.appendChild(row);
        });
      head.appendChild(titles); table.append(head, data); grid.appendChild(table);
      comparison.appendChild(grid);
      comparison.appendChild(button('Svuota confronto', function () {
        (find('[data-ks-guide-compare-key]') || prepare).focus();
        state.selected = []; root.querySelectorAll('[data-ks-guide-compare-key]').forEach(function (check) { check.checked = false; }); renderCompare();
        announce('Confronto svuotato. Puoi selezionare altri prodotti.');
      }));
      announce('Confronto aggiornato: ' + items.length + ' prodotti.');
    }
    function nextQuestion(container) {
      var b = state.confirmed, question = node('div', undefined, 'ks-guide-question'), message, action;
      if (b.pmax === '0') { message = 'Vuoi indicare un prezzo massimo?'; action = function () { command.value = 'massimo '; command.focus(); }; }
      else if (!b.st && departments.size > 1) { message = 'Vuoi scegliere un reparto?'; action = function () { var choice = choices.find(function (x) { return !x.disabled && Number(x.getAttribute('data-ks-guide-sector')) > 0; }); if (choice) choice.focus(); }; }
      else if (!b.disponibile) { message = 'Vuoi limitarti ai prodotti disponibili?'; action = function () { command.focus(); runCommand('solo disponibili'); }; }
      else return;
      question.append(node('p', message), button('Scegli questa preferenza', action), button('Salta', function () { command.focus(); question.remove(); }));
      container.appendChild(question);
    }
    function renderResult() {
      var data = state.result, b = state.confirmed;
      results.appendChild(node('h3', data.items.length ? 'Una selezione per la tua ricerca' : 'Nessun risultato in questa selezione'));
      results.appendChild(node('p', data.items.length + ' risultati restituiti, fino a 6. Non è il totale del catalogo.', 'ks-guide-hint'));
      results.appendChild(node('p', data.label, 'ks-guide-fiscal'));
      if (data.items.length) {
        var grid = node('div', undefined, 'ks-guide-grid');
        data.items.forEach(function (item) { grid.appendChild(productCard(item)); });
        results.appendChild(grid); nextQuestion(results);
      } else {
        var patch, message;
        if (b.disponibile) { patch = { disponibile: false }; message = 'Includi anche i non disponibili; gli altri criteri restano uguali.'; }
        else if (b.pmax !== '0') { patch = { pmax: '0' }; message = 'Rimuovi solo il prezzo massimo; gli altri criteri restano uguali.'; }
        else if (b.st) { patch = { st: 0 }; message = 'Cerca in tutti i reparti; gli altri criteri restano uguali.'; }
        if (patch) {
          recovery.append(node('p', message), button('Applica questa modifica', function () {
            if (!canRefineConfirmed()) return;
            prepare.focus(); accept(Object.assign(copy(b), patch), true);
          }));
        } else recovery.appendChild(button('Modifica le parole della ricerca', function () { input.focus(); }));
      }
      results.appendChild(link('Continua nel catalogo con queste preferenze', data.catalog));
    }
    function recover(message, invalid) {
      invalidate(invalid ? 'context-invalid' : 'error'); announce(message);
      if (state.confirmed && state.confirmed.q) {
        recovery.appendChild(button(invalid ? 'Aggiorna la selezione' : 'Riprova', function () {
          if (!canRefineConfirmed()) return;
          prepare.focus(); accept(copy(state.confirmed), false);
        }));
        recovery.appendChild(link('Continua nel catalogo', catalogURL(state.confirmed, paths).href, 'ks-guide-catalog-fallback'));
      }
    }
    function contextInvalid() {
      if (state.result || state.request) recover('Il contesto del negozio potrebbe essere cambiato. Aggiorna esplicitamente la selezione per vedere prezzi e disponibilità.', true);
    }
    async function search(b) {
      invalidate('loading'); root.setAttribute('aria-busy', 'true');
      prepare.setAttribute('aria-disabled', 'true'); announce('Caricamento della selezione in corso.');
      var generation = state.generation, controller = new win.AbortController();
      var request = { brief: copy(b), controller: controller, timer: null }; state.request = request;
      try {
        var timeout = new win.Promise(function (_, reject) {
          request.timer = win.setTimeout(function () { controller.abort(); reject(new Error('timeout')); }, 8000);
        });
        var operation = (async function () {
          var response = await win.fetch(requestURL(b, paths), { method: 'GET', credentials: 'same-origin', cache: 'no-store', redirect: 'error',
            headers: { Accept: 'application/json' }, signal: controller.signal });
          if (!response.ok) throw new Error('http-' + response.status);
          if (!/^application\/json(?:;|$)/i.test(response.headers.get('content-type') || '') ||
              Number(response.headers.get('content-length')) > MAX_BODY) throw new Error('payload');
          var raw = await response.text();
          if (raw.length > MAX_BODY) throw new Error('payload');
          return validate(JSON.parse(raw), b, paths);
        }());
        var result = await win.Promise.race([operation, timeout]);
        if (generation !== state.generation || state.request !== request) return;
        state.result = result; phase(result.items.length ? 'results' : 'empty');
        renderResult(); announce(result.items.length ? 'Selezione aggiornata: ' + result.items.length + ' prodotti.' : 'La ricerca non ha restituito risultati con queste preferenze.');
      } catch (error) {
        if (generation !== state.generation || state.request !== request) return;
        var code = error.message, invalid = code === 'http-403' || code === 'http-421';
        var message = invalid ? 'Contesto commerciale non disponibile. Aggiorna la selezione o continua nel catalogo.' :
          code === 'http-400' ? 'La richiesta non è valida. Controlla prodotto e preferenze.' :
          code === 'http-429' ? 'Troppe richieste. Attendi prima di riprovare.' :
          code === 'http-503' ? 'Il servizio è temporaneamente non disponibile.' :
          code === 'timeout' ? 'La richiesta sta impiegando troppo tempo. Puoi riprovare.' :
          'Non è stato possibile verificare la selezione. Controlla la connessione o riprova.';
        recover(message, invalid);
      } finally {
        win.clearTimeout(request.timer);
        if (state.request === request) { state.request = null; root.removeAttribute('aria-busy'); prepare.removeAttribute('aria-disabled'); }
      }
    }
    try {
      choices.forEach(function (choice) {
        if (choice.disabled) return;
        choice.addEventListener('click', function () {
          state.draftSector = Number(choice.getAttribute('data-ks-guide-sector'));
          choices.forEach(function (other) { other.setAttribute('aria-pressed', other === choice ? 'true' : 'false'); });
          invalidate('editing'); announce('Reparto modificato. Premi “Mostra i prodotti” per confermare.');
        });
      });
      prepare.addEventListener('click', prepareSearch); reset.addEventListener('click', resetGuide); undo.addEventListener('click', undoGuide);
      apply.addEventListener('click', function () { runCommand(command.value); });
      root.querySelectorAll('[data-ks-guide-command]').forEach(function (quick) { quick.addEventListener('click', function () { runCommand(quick.getAttribute('data-ks-guide-command')); }); });
      newQuery.addEventListener('click', function () {
        if (!state.unknown || state.unknown.length < 2) return;
        if (!canRefineConfirmed()) return;
        var b = blank(); b.q = state.unknown; prepare.focus(); accept(b, true);
      });
      [input, detail, command].forEach(function (field) {
        field.addEventListener('input', function () {
          invalidate('editing'); state.unknown = ''; newQuery.hidden = true;
          announce(field === command ? 'Preferenza in modifica. Premi “Applica preferenza” per confermare.' : 'Richiesta in modifica. Premi “Mostra i prodotti” per confermare.');
        });
        field.addEventListener('keydown', function (event) {
          if (event.key === 'Enter') {
            event.preventDefault();
            if (!event.isComposing && event.keyCode !== 229) { if (field === command) runCommand(command.value); else prepareSearch(); }
          }
        });
      });
      win.addEventListener('pagehide', contextInvalid);
      win.addEventListener('pageshow', function (event) { if (event.persisted) contextInvalid(); });
      win.addEventListener('blur', contextInvalid);
      doc.addEventListener('visibilitychange', function () { if (doc.hidden) contextInvalid(); });
      phase('idle'); summaryView();
      instances.add(root); root.setAttribute('data-ks-guide-bound', '1');
      fields.hidden = false; fields.disabled = false; output.hidden = false;
      var fallback = find('.ks-guide-fallback-departments'); if (fallback) fallback.hidden = true;
    } catch (_) {
      fields.hidden = true; fields.disabled = true; refine.hidden = true; refine.disabled = true;
      output.hidden = true; summary.hidden = true; idle.hidden = false;
    }
  }
  return { init: init, parseCommand: parseCommand, queryText: queryText, blank: blank, urls: urls,
    requestURL: requestURL, catalogURL: catalogURL, validate: validate, reason: reason };
}));
