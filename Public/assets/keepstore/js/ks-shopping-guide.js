/* Progressive shopping guide: explicit preferences, server-owned commercial facts.
   Memory only. No telemetry, storage, cookies or automatic search. */
(function (host, factory) {
  'use strict';
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else host.KeepStoreShoppingGuide = { init: api.init };
}(typeof window !== 'undefined' ? window : this, function () {
  'use strict';
  var MAX_TEXT = 80, MAX_GOAL = 160, MAX_BODY = 65536, MAX_RESULTS = 6, MAX_HISTORY = 8;
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
  function budgetValue(raw) {
    var value = clean(raw);
    if (!value) return '0';
    var amount = decimal(value);
    if (!amount || amount === '0') throw new Error('budget');
    return amount;
  }
  function interpretNeed(raw) {
    var original = clean(raw), remaining = original, patch = {}, limits = [], conflicts = [];
    if (!original || original.length > MAX_GOAL) return { query: '', patch: patch, limits: limits, conflicts: ['Descrivi un bisogno in massimo 160 caratteri.'] };
    // Delimited commercial clauses only. Product numbers and negations remain literal.
    var parts = original.split(/\s*;\s*/), first = parts.shift();
    parts.forEach(function (part) {
      var controlled = { 'spendere meno': 'prima i meno costosi', 'escludere indisponibili': 'solo disponibili' };
      var command = parseCommand(controlled[part.toLocaleLowerCase('it-IT')] || part);
      if (command.kind === 'patch') {
        Object.keys(command.patch).forEach(function (key) {
          if (Object.prototype.hasOwnProperty.call(patch, key) && patch[key] !== command.patch[key]) conflicts.push('Preferenze in conflitto: ' + part);
          patch[key] = command.patch[key];
        });
      } else limits.push('Non verificabile con i dati disponibili: «' + part + '». Mancano attributi certificati per applicare questo requisito; puoi continuare sui soli criteri supportati o contattare il negozio.');
    });
    var match = /^(?:cerco|vorrei|mi serve|ho bisogno di)\s+(.+)$/i.exec(first);
    remaining = match ? match[1] : '';
    if (/^(?:spendere meno|escludere indisponibili)$/i.test(remaining)) remaining = '';
    if (remaining.length > MAX_TEXT) { limits.push('Le parole da cercare superano 80 caratteri: precisale senza troncarle.'); remaining = ''; }
    // These requirements have no certified attributes in guided v1; never turn them into product facts.
    if (/\b(?:compatib\w*|allergen\w*|ingredient\w*|consumabil\w*|resa|pagine\s*\/\s*mese|costo d['’]uso)\b/i.test(remaining)) {
      limits.push('Per «' + remaining + '» mancano attributi certificati di compatibilità, composizione o costo d’uso. Specifica il prodotto oppure consulta il negozio.'); remaining = '';
    }
    return { query: remaining, patch: patch, limits: limits, conflicts: conflicts, source: original };
  }
  function chooseQuestion(items, brief, skipped) {
    skipped = skipped || [];
    if (items.length < 2) return null;
    if (!brief.disponibile && skipped.indexOf('stock') < 0 && items.some(function (x) { return x.availability > 0; }) && items.some(function (x) { return x.availability !== null && x.availability <= 0; }))
      return { key: 'stock', message: 'Alcuni di questi candidati non sono disponibili. Vuoi escluderli?', patch: { disponibile: true } };
    var prices = Array.from(new Set(items.map(function (x) { return x.priceValue; }))).sort(function (a, b) { return a - b; });
    if (prices.length > 1 && decimal(String(prices[0])) && brief.pmax === '0' && skipped.indexOf('budget') < 0)
      return { key: 'budget', message: 'Questi candidati hanno prezzi diversi. Vuoi fissare il massimo a ' + items.find(function (x) { return x.priceValue === prices[0]; }).price + '?', patch: { pmax: String(prices[0]) } };
    if (prices.length > 1 && !brief.ordinamento && skipped.indexOf('sort') < 0)
      return { key: 'sort', message: 'Vuoi vedere prima i meno costosi, mantenendo gli altri criteri?', patch: { ordinamento: 'p_basso' } };
    return null;
  }
  function catalogHandoff(search, departments) {
    var params = new URLSearchParams(search), names = ['guide', 'guide_q', 'guide_st'];
    if (!names.some(function (name) { return params.has(name); })) return { kind: 'none' };
    var invalid = { kind: 'invalid' };
    if (/%(?![0-9a-f]{2})/i.test(search) || Array.from(params.keys()).some(function (name) { return names.indexOf(name) < 0; }) ||
        params.getAll('guide').length !== 1 || params.get('guide') !== 'catalog-v1' || params.getAll('guide_q').length !== 1 ||
        params.getAll('guide_st').length > 1) return invalid;
    var q = params.get('guide_q');
    if (q.length > 1024 || /[\u0000-\u001f\u007f\ufffd]/.test(q) ||
        /[\ud800-\udbff](?![\udc00-\udfff])|(?:^|[^\ud800-\udbff])[\udc00-\udfff]/.test(q)) return invalid;
    q = q.normalize('NFC').replace(/\s+/g, ' ').trim();
    if (q.length < 2 || q.length > MAX_TEXT) return invalid;
    var sector = params.get('guide_st'), id = 0;
    if (sector !== null) {
      if (!/^[1-9][0-9]{0,9}$/.test(sector) || Number(sector) > 2147483647) return invalid;
      id = Number(sector);
    }
    return { kind: 'draft', q: q, st: id, sectorUnavailable: id > 0 && !departments.has(id) };
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
  function requestAdvisorURL(b, paths, criteria, skipped) {
    var target = new URL(requestURL(b, paths));
    target.searchParams.set('mode', 'guided2');
    target.searchParams.set('criteria', JSON.stringify(criteria));
    target.searchParams.set('skipped', JSON.stringify(skipped));
    return target.href;
  }
  function validateAdvisor(payload, b, paths, criteria, skipped) {
    var meta = payload && payload.guided;
    if (!object(payload) || payload.mode !== 'guided2' || !object(meta) || meta.version !== 2 ||
        !object(meta.criteria) || !Array.isArray(meta.attributes) || meta.attributes.length > 32 ||
        !Array.isArray(meta.actions) || meta.actions.length > 8 || meta.poolLimit !== 96 ||
        meta.selectionScope !== 'bounded-catalog-candidates' || typeof meta.exhaustive !== 'boolean' ||
        !Number.isSafeInteger(meta.analyzedCount) || meta.analyzedCount < 0 || meta.analyzedCount > 96 ||
        !Number.isSafeInteger(meta.eligibleCount) || meta.eligibleCount < 0 || meta.eligibleCount > meta.analyzedCount || typeof meta.knowledgeLimited!=='boolean' || meta.knowledgeLimited&&meta.exhaustive) throw new Error('payload');
    keys(meta,['version','policyVersion','scope','selectionScope','exhaustive','poolLimit','knowledgeLimited','taxonomyRequired','analyzedCount','eligibleCount','returnedCount','selectionLimited','limit','displayLabel','summary','criteria','attributes','question','actions']);
    if(typeof meta.taxonomyRequired!=='boolean'||meta.taxonomyRequired&&(meta.question!==null||criteria.length&&payload.suggestions.length))throw new Error('payload');
    keys(meta.criteria,['q','st','ct','tp','pmin','pmax','disponibile','ordinamento','attributes','skipped']);
    text(meta.scope, 200, false); text(meta.policyVersion, 80, false); text(meta.summary, 1000, true);
    if (Object.keys(b).some(function (key) { return meta.criteria[key] !== b[key]; }) || meta.criteria.ct !== 0 || meta.criteria.tp !== 0) throw new Error('payload');
    function signature(list) {
      if (!Array.isArray(list) || list.length > 8) throw new Error('payload');
      return list.map(function (c) {
        keys(c, ['attributeId', 'operator', 'value', 'priority']);
        text(c.attributeId, 200, false); text(c.value, 120, false);
        if (['eq','gte','lte'].indexOf(c.operator) < 0 || ['hard','soft'].indexOf(c.priority) < 0) throw new Error('payload');
        return JSON.stringify([c.attributeId,c.operator,c.value,c.priority]);
      }).sort().join('|');
    }
    if (signature(meta.criteria.attributes) !== signature(criteria) || !Array.isArray(meta.criteria.skipped) ||
        meta.criteria.skipped.length > 24 || meta.criteria.skipped.some(function (id) { return typeof id !== 'string'; }) ||
        meta.criteria.skipped.slice().sort().join('|') !== skipped.slice().sort().join('|')) throw new Error('payload');
    var definitions = new Map();
    meta.attributes.forEach(function (a) {
      if (!object(a) || definitions.has(a.id) || typeof a.canAsk !== 'boolean' || typeof a.canHardFilter !== 'boolean' ||
          typeof a.coverage !== 'number' || !Number.isFinite(a.coverage) || a.coverage < 0 || a.coverage > 1 ||
          !Array.isArray(a.operators) || a.operators.length > 3 || a.operators.some(function (op) { return ['eq','gte','lte'].indexOf(op) < 0; }) ||
          !Array.isArray(a.observedValues) || a.observedValues.length > 16) throw new Error('payload');
      text(a.id,200,false);text(a.label,100,false);text(a.type,40,false);text(a.unit,30,true);text(a.scope,200,false);text(a.origin,100,false);text(a.risk,40,false);
      if(typeof a.available!=='boolean'||!a.available&&(a.canAsk||a.canHardFilter||a.coverage!==0||a.observedValues.length)||meta.taxonomyRequired&&(a.canAsk||a.canHardFilter))throw new Error('payload');
      text(a.receipt,1024,true);if(a.receipt&&!/^[A-Za-z0-9_-]+$/.test(a.receipt))throw new Error('payload');
      a.observedValues.forEach(function (v) { text(v,120,false); }); definitions.set(a.id,a);
    });
    if (meta.question !== null) {
      var q=meta.question, definition=object(q)&&definitions.get(q.attributeId);
      if (!definition || !definition.canAsk || typeof q.allowSkip !== 'boolean' || typeof q.allowIndifferent !== 'boolean' ||
          typeof q.allowUnknown !== 'boolean' || q.operator !== 'eq' || !Array.isArray(q.options) || q.options.length < 2 || q.options.length > 16) throw new Error('payload');
      text(q.id,200,false);text(q.label,300,false);
      text(q.reason,500,true);
      var seenOptions=new Set();q.options.forEach(function (o) { if(!object(o)||seenOptions.has(o.value)||definition.observedValues.indexOf(o.value)<0)throw new Error('payload');text(o.value,120,false);text(o.label,180,false);seenOptions.add(o.value); });
    }
    meta.actions.forEach(function (a) {
      if (!object(a) || a.kind!=='relax' || a.requiresConfirmation!==true || !Array.isArray(a.attributeIds) || !a.attributeIds.length ||
          a.attributeIds.length>8 || a.attributeIds.some(function(id){return !criteria.some(function(c){return c.attributeId===id;});}))throw new Error('payload');
      text(a.id,200,false);text(a.label,300,false);
      text(a.reason,500,true);
    });
    // Reuse the unchanged v1 commercial URL, identity, price and stock guards.
    var old = Object.assign({},payload,{mode:'guided',guided:{version:1,criteria:b,displayLabel:meta.displayLabel,returnedCount:meta.returnedCount,selectionLimited:true,limit:6}});
    var result=validate(old,b,paths);
    result.items.forEach(function(item,i){
      var source=payload.suggestions[i];
      if(source.productKey!==item.key || typeof source.family!=='string'||source.family.length>54||!/^\d+\/\d+\/\d+\/\d+\/\d+$/.test(source.family)||!Array.isArray(source.values)||source.values.length>32||!Array.isArray(source.evaluations)||source.evaluations.length>8||['complete','partial','unconstrained'].indexOf(source.match)<0)throw new Error('payload');
      var ids=new Set();source.values.forEach(function(v){
        if(!object(v)||!definitions.has(v.attributeId)||ids.has(v.attributeId)||['known','missing','ambiguous','conflicting'].indexOf(v.evidenceStatus)<0)throw new Error('payload');
        if(definitions.get(v.attributeId).scope!==source.family||!definitions.get(v.attributeId).available&&v.evidenceStatus==='known')throw new Error('payload');
        ids.add(v.attributeId);if(v.value!==null)text(v.value,120,false);text(v.sourceField,80,true);text(v.evidenceRef,200,true);text(v.evidenceText,180,true);
        if(v.sourceField && v.sourceField.split(',').some(function(field){return ['Descrizione1','Descrizione2','DescrizioneLunga','DescrizioneHTML','MarcheDescrizione','Codice','Ean','SettoriDescrizione','CategorieDescrizione'].indexOf(field)<0;}))throw new Error('payload');
        if(v.evidenceStatus==='known' && (v.value===null||!v.evidenceRef||!v.sourceField))throw new Error('payload');
      });
      var evaluated=new Set();source.evaluations.forEach(function(e){
        var requested=criteria.find(function(c){return c.attributeId===e.attributeId;});
        if(!requested||!definitions.has(e.attributeId)||evaluated.has(e.attributeId)||e.priority!==requested.priority||['SATISFIED','VIOLATED','UNKNOWN'].indexOf(e.status)<0||e.priority==='hard'&&e.status!=='SATISFIED')throw new Error('payload');
        evaluated.add(e.attributeId);text(e.evidenceRef,200,true);
        var fact=source.values.find(function(v){return v.attributeId===e.attributeId;});if(e.status!=='UNKNOWN'&&(!fact||fact.evidenceStatus!=='known'||e.evidenceRef!==fact.evidenceRef))throw new Error('payload');
      });
      if(evaluated.size!==criteria.length || source.match==='complete'&&(!criteria.length||source.evaluations.some(function(e){return e.status!=='SATISFIED';})) || source.match==='unconstrained'&&criteria.length)throw new Error('payload');
      if(!Array.isArray(source.textEvidence)||source.textEvidence.length>3)throw new Error('payload');source.textEvidence.forEach(function(e){keys(e,['text','sourceField','evidenceRef']);text(e.text,180,false);text(e.evidenceRef,200,false);if(['Descrizione1','Descrizione2','DescrizioneLunga','DescrizioneHTML'].indexOf(e.sourceField)<0)throw new Error('payload');});
      item.facts=source.values;item.evaluations=source.evaluations;item.match=source.match;item.advisorReason=text(source.reason,1000,true);item.textEvidence=source.textEvidence;
    });
    if(meta.eligibleCount<result.items.length||!meta.taxonomyRequired&&new Set(payload.suggestions.map(function(p){return p.family;})).size>1||meta.question&&payload.suggestions.some(function(p){return p.family!==definitions.get(meta.question.attributeId).scope;}))throw new Error('payload');
    result.advisor=meta;return result;
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
      // A malformed response must never turn an essential filter into a recommendation.
      if ((brief.pmax !== '0' && row.priceValue > Number(brief.pmax)) ||
          (brief.pmin !== '0' && row.priceValue < Number(brief.pmin)) ||
          (brief.disponibile && !(row.availability > 0))) throw new Error('criteria');
      return { key: key, id: row.id, tc: row.TCId, url: link.href, title: text(row.title, 500, false),
        price: text(row.price, 80, false), priceValue: row.priceValue, brand: text(row.brand, 180, true), category: text(row.category, 180, true),
        department: text(row.department, 180, true),
        code: text(row.code, 120, true), ean: text(row.ean, 120, true),
        image: imageURL(row.image, paths), fallback: imageURL(row.image_fallback, paths),
        availability: row.availability, offer: row.isOffer, refurbished: row.isRefurbished };
    });
    return { items: items, label: label, catalog: actual.href };
  }
  function stock(item) { return item.availability === null ? 'Disponibilità: dato non disponibile' : item.availability > 0 ? 'Disponibile' : 'Non disponibile'; }
  function words(value) {
    // Literal, whole tokens only: never expand synonyms or interpret an intended use.
    return clean(value).normalize('NFC').toLocaleLowerCase('it-IT').match(/[\p{L}\p{N}]+(?:[-.,/+][\p{L}\p{N}]+)*/gu) || [];
  }
  function evidence(item, b) {
    var fields = [['title', 'titolo'], ['code', 'codice'], ['ean', 'EAN'], ['brand', 'marca'], ['category', 'categoria'], ['department', 'reparto']];
    var tokens = Array.from(new Set(words(b.q))), matched = [], unverified = [];
    tokens.forEach(function (term) {
      var found = fields.find(function (field) { return words(item[field[0]]).indexOf(term) >= 0; });
      if (found) matched.push({ term: term, field: found[1] }); else unverified.push(term);
    });
    var q = clean(b.q).toLocaleLowerCase('it-IT');
    return { matched: matched, unverified: unverified,
      exactCode: [item.code, item.ean].some(function (value) { return value && clean(value).toLocaleLowerCase('it-IT') === q; }) };
  }
  function reason(item, b) {
    var proof = evidence(item, b);
    if (proof.exactCode) return 'Corrispondenza esatta del codice cercato.';
    if (proof.matched.length) return 'Termini presenti nei dati: ' + proof.matched.map(function (match) { return '“' + match.term + '” (' + match.field + ')'; }).join(', ') + '.';
    return 'Nessuna corrispondenza testuale verificabile nei dati mostrati.';
  }
  function decision(items) {
    if (!items.length) return { minimum: null, lowest: [], differences: [] };
    var minimum = Math.min.apply(null, items.map(function (item) { return item.priceValue; }));
    var cheapest = items.find(function (item) { return item.priceValue === minimum; });
    // Equal formatted prices are tied for the customer, even if source decimals differ below a cent.
    var lowest = items.filter(function (item) { return item.priceValue === minimum || item.price === cheapest.price; }).map(function (item) { return item.key; });
    var fields = [['Prezzo', function (item) { return item.price; }], ['Disponibilità', stock],
      ['Marca', function (item) { return item.brand || ''; }], ['Categoria', function (item) { return item.category || ''; }],
      ['Condizione', function (item) { return item.refurbished; }], ['Offerta', function (item) { return item.offer; }]];
    return { minimum: minimum, lowest: lowest, differences: fields.filter(function (field) {
      return new Set(items.map(field[1])).size > 1;
    }).map(function (field) { return field[0]; }) };
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
    var goal = find('#ksGuideGoal'), budget = find('#ksGuideBudget'), draftReview = find('[data-ks-guide-draft-review]');
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
    var state = { phase: 'idle', confirmed: null, confirmedGoal: '', draftSector: 0, history: [], request: null, result: null, selected: [], generation: 0, unknown: '', handoffSectorPending: false };
    var skippedQuestions = [], proposedNeed = null, needPatch = null;
    var advisor = { enabled:false, criteria:[], skipped:[], attributes:[], receipts:{}, confirmedReceipts:{}, draft:false, confirmedCriteria:[], confirmedSkipped:[] };
    var advisorPanel=find('[data-ks-advisor-panel]'), advisorControls=find('[data-ks-advisor-controls]'),
      advisorCriteria=find('[data-ks-advisor-criteria]'), advisorAttribute=find('#ksAdvisorAttribute'), advisorOperator=find('#ksAdvisorOperator'),
      advisorValue=find('#ksAdvisorValue'), advisorPriority=find('#ksAdvisorPriority'),advisorNumber=find('#ksAdvisorNumber');
    function advisorSignature(){return JSON.stringify([advisor.criteria,advisor.skipped]);}
    function advisorOption(select,value,label){var option=node('option',label);option.value=value;select.appendChild(option);return option;}
    function clearAdvisorInputs(){
      advisor.attributes=[];advisor.draft=false;if(advisorAttribute){advisorAttribute.replaceChildren();advisorOption(advisorAttribute,'','Scegli una caratteristica');advisorOperator.replaceChildren();advisorValue.replaceChildren();}
      if(advisorNumber){advisorNumber.value='';advisorNumber.hidden=true;var label=find('label[for="ksAdvisorNumber"]');if(label)label.hidden=true;}if(advisorControls)advisorControls.disabled=true;
    }
    function advisorInputs(){
      if(!advisorAttribute)return;
      advisorOperator.replaceChildren();advisorValue.replaceChildren();
      var a=advisor.attributes.find(function(x){return x.id===advisorAttribute.value;});
      var numeric=!!a&&a.type==='number';if(advisorNumber){advisorNumber.hidden=!numeric;var numberLabel=find('label[for="ksAdvisorNumber"]');numberLabel.hidden=!numeric;numberLabel.textContent='Valore numerico richiesto'+(a&&a.unit?' ('+a.unit+')':'');}
      advisorValue.hidden=numeric;var valueLabel=find('label[for="ksAdvisorValue"]');if(valueLabel)valueLabel.hidden=numeric;
      if(!a)return;
      a.operators.forEach(function(op){advisorOption(advisorOperator,op,{eq:'Uguale a',gte:'Almeno',lte:'Al massimo'}[op]);});
      a.observedValues.forEach(function(value){advisorOption(advisorValue,value,value+(a.unit?' '+a.unit:''));});
      if(advisorNumber)advisorNumber.value=numeric&&a.observedValues.length?a.observedValues[0]:'';
      advisorPriority.querySelector('[value="hard"]').disabled=!a.canHardFilter;
      if(!a.canHardFilter)advisorPriority.value='soft';
    }
    function renderAdvisorCriteria(){
      if(!advisorCriteria)return;advisorCriteria.replaceChildren();
      advisor.criteria.forEach(function(c){var a=advisor.attributes.find(function(x){return x.id===c.attributeId;});
        var control=button((c.priority==='hard'?'Obbligatorio: ':'Preferenza: ')+(a?a.label:'Caratteristica')+' '+{eq:'=',gte:'≥',lte:'≤'}[c.operator]+' '+c.value+(a&&a.unit?' '+a.unit:'')+' ×',function(){
          if(!canRefineConfirmed())return;prepare.focus();advisor.criteria=advisor.criteria.filter(function(x){return x!==c;});accept(copy(state.confirmed),true);
        },'ks-guide-chip');control.setAttribute('aria-label','Rimuovi criterio '+(a?a.label:c.attributeId));advisorCriteria.appendChild(control);
      });
    }
    function renderAdvisor(data){
      advisor.attributes=data.attributes;advisor.draft=false;
      data.attributes.forEach(function(a){if(a.receipt&&!advisor.criteria.some(function(c){return c.attributeId===a.id;}))advisor.receipts[a.id]=a.receipt;});
      if(advisorControls){advisorControls.disabled=data.taxonomyRequired;advisorAttribute.replaceChildren();advisorOption(advisorAttribute,'','Scegli una caratteristica');
        data.attributes.filter(function(a){return a.canAsk||a.canHardFilter;}).forEach(function(a){advisorOption(advisorAttribute,a.id,a.label+(a.unit?' ('+a.unit+')':''));});advisorInputs();}
      renderAdvisorCriteria();
      results.appendChild(node('p',data.summary||'Selezione analizzata nel contesto corrente.','ks-guide-hint'));
      if(data.taxonomyRequired){var choose=button('Scegli il reparto nei controlli della guida',function(){var choice=choices.find(function(x){return !x.disabled&&!x.hidden&&Number(x.getAttribute('data-ks-guide-sector'))>0;});(choice||input).focus();});choose.setAttribute('data-ks-advisor-taxonomy','');results.appendChild(choose);}
      results.appendChild(node('p',(data.exhaustive?'Analisi completa dei candidati del contesto dichiarato.':data.knowledgeLimited?'Alcune descrizioni superano i limiti di analisi: le caratteristiche non sono tutte verificabili.':'Analisi limitata ai primi 96 candidati: altri prodotti potrebbero essere pertinenti.')+' Analizzati: '+data.analyzedCount+'. Ammissibili nella selezione: '+data.eligibleCount+'.','ks-guide-hint'));
      if(data.question){var q=data.question,block=node('div',undefined,'ks-guide-question');block.appendChild(node('h3',q.label));
        q.options.forEach(function(option){var choice=button(option.label,function(){
          if(!canRefineConfirmed())return;command.focus();var attribute=advisor.attributes.find(function(a){return a.id===q.attributeId;});
          advisor.receipts[q.attributeId]=attribute.receipt;
          advisor.criteria=advisor.criteria.filter(function(c){return c.attributeId!==q.attributeId;}).concat([{attributeId:q.attributeId,operator:q.operator,value:option.value,priority:'soft'}]);accept(copy(state.confirmed),true);
        });choice.setAttribute('data-ks-advisor-option',option.value);choice.setAttribute('data-ks-advisor-attribute',q.attributeId);block.appendChild(choice);});
        [['allowSkip','Salta','skip'],['allowIndifferent','Indifferente','indifferent'],['allowUnknown','Non lo so','unknown']].forEach(function(kind){if(q[kind[0]]){var skip=button(kind[1],function(){
          if(!canRefineConfirmed())return;command.focus();advisor.skipped=Array.from(new Set(advisor.skipped.concat([q.attributeId])));accept(copy(state.confirmed),false);
        });skip.setAttribute('data-ks-advisor-'+kind[2],'');block.appendChild(skip);}});results.appendChild(block);
      }
      data.actions.forEach(function(action){var control=button('Confermo: '+action.label,function(){
        if(!canRefineConfirmed())return;prepare.focus();advisor.criteria=advisor.criteria.filter(function(c){return action.attributeIds.indexOf(c.attributeId)<0;});accept(copy(state.confirmed),true);
      });control.setAttribute('data-ks-advisor-relax',action.id);recovery.appendChild(control);});
    }
    var handoffNotice = find('[data-ks-guide-handoff]');
    function handoffMessage(message) { if (handoffNotice) { handoffNotice.textContent = message; handoffNotice.hidden = !message; } }
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
      if(advisorControls && advisor.enabled && ['loading','context-invalid','error'].indexOf(next)>=0)advisorControls.disabled=true;
      if(advisor.enabled && next==='context-invalid')clearAdvisorInputs();
    }
    function reviewDraft() {
      if (!draftReview) return;
      var query = clean(input.value + ' ' + detail.value), purpose = goal ? clean(goal.value) : '', maximum = budget ? clean(budget.value) : '';
      var scopeReset=advisor.enabled&&advisor.criteria.length&&state.confirmed&&query!==state.confirmed.q;
      prepare.textContent=scopeReset?'Conferma nuova ricerca senza i requisiti precedenti':'Mostra i prodotti';
      var confirmed = !pendingNeedChange() && state.confirmed && clean(input.value) === state.confirmed.q && !clean(detail.value) &&
        purpose === state.confirmedGoal && state.draftSector === state.confirmed.st;
      try { confirmed = confirmed && (!budget || budgetValue(maximum) === state.confirmed.pmax); } catch (_) { confirmed = false; }
      draftReview.setAttribute('aria-label', confirmed ? 'Brief confermato' : 'Brief da confermare');
      draftReview.replaceChildren(node('strong', confirmed ? 'Il tuo brief confermato' : 'Il tuo brief, da confermare'),
        node('p', purpose ? 'Obiettivo: ' + purpose : 'Obiettivo facoltativo: puoi iniziare da un prodotto o un codice.'),
        node('p', query ? 'Parole da cercare: ' + query : 'Indica il prodotto, la marca o il codice: non deduciamo prodotti dall’obiettivo.'),
        node('p', 'Reparto: ' + (departments.get(state.draftSector) || 'Da scegliere') + ' · ' + (maximum ? 'Budget massimo: ' + maximum + ' €' : 'Nessun limite di prezzo')));
      if(scopeReset)draftReview.appendChild(node('p','La nuova ricerca non riutilizzerà le caratteristiche precedenti. Conferma esplicitamente oppure ripristina le parole della ricerca corrente.'));
    }
    function syncFields(b) {
      input.value = b.q; detail.value = ''; state.draftSector = b.st;
      if (goal) goal.value = state.confirmedGoal;
      if (budget) budget.value = b.pmax === '0' ? '' : b.pmax.replace('.', ',');
      choices.forEach(function (choice) { choice.setAttribute('aria-pressed', Number(choice.getAttribute('data-ks-guide-sector')) === b.st ? 'true' : 'false'); });
      reviewDraft();
    }
    function canRefineConfirmed() {
      if(advisor.enabled&&advisor.draft){announce('Conferma il criterio sulle caratteristiche oppure seleziona la voce vuota per scartare la bozza.');return false;}
      if (pendingNeedChange()) { announce('La proposta contiene criteri da confermare. Premi “Mostra i prodotti” prima di applicare altre preferenze.'); return false; }
      // syncFields stores the confirmed query in the product field and clears detail.
      // Even redistributing the same words between those fields is an unconfirmed edit.
      var currentBudget;
      try { currentBudget = budget ? budgetValue(budget.value) : state.confirmed && state.confirmed.pmax; } catch (_) { currentBudget = null; }
      if (!state.confirmed || (clean(input.value) === state.confirmed.q && !clean(detail.value) && state.draftSector === state.confirmed.st &&
          (!goal || clean(goal.value) === state.confirmedGoal) && currentBudget === state.confirmed.pmax)) return true;
      announce('La richiesta è in modifica. Premi “Mostra i prodotti” per confermarla.');
      return false;
    }
    function pendingNeedChange() {
      return needPatch && (!state.confirmed || Object.keys(needPatch).some(function (key) { return needPatch[key] !== state.confirmed[key]; }));
    }
    function summaryView() {
      var b = state.confirmed;
      summary.hidden = !b || (!b.q && !(advisor.enabled&&b.st>0)); idle.hidden = !summary.hidden;
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
    function remember(b) { if (b) { state.history.push({ brief: copy(b), goal: state.confirmedGoal, advisor:advisor.enabled?{criteria:JSON.parse(JSON.stringify(advisor.confirmedCriteria)),skipped:advisor.confirmedSkipped.slice(),receipts:Object.assign({},advisor.confirmedReceipts)}:null }); if (state.history.length > MAX_HISTORY) state.history.shift(); } }
    function accept(b, record, nextGoal, restoreAdvisor) {
      var purpose = typeof nextGoal === 'string' ? nextGoal : state.confirmedGoal;
      if (state.request && same(state.request.brief, b) && purpose === state.confirmedGoal && (!advisor.enabled||state.request.advisorSignature===advisorSignature())) return;
      if (record && (!same(state.confirmed, b) || purpose !== state.confirmedGoal || advisor.enabled&&advisorSignature()!==JSON.stringify([advisor.confirmedCriteria,advisor.confirmedSkipped]))) remember(state.confirmed);
      if(advisor.enabled&&!restoreAdvisor&&state.confirmed&&(b.q!==state.confirmed.q||b.st!==state.confirmed.st)){advisor.criteria=[];advisor.skipped=[];advisor.receipts={};clearAdvisorInputs();renderAdvisorCriteria();}
      if(advisor.enabled){advisor.confirmedCriteria=JSON.parse(JSON.stringify(advisor.criteria));advisor.confirmedSkipped=advisor.skipped.slice();advisor.confirmedReceipts=Object.assign({},advisor.receipts);}
      if (!same(state.confirmed, b) || purpose !== state.confirmedGoal) skippedQuestions = [];
      state.confirmedGoal = purpose;
      needPatch = null;
      state.confirmed = copy(b); state.unknown = ''; newQuery.hidden = true; command.value = '';
      syncFields(b); summaryView();
      if (!b.q && !(advisor.enabled&&b.st>0)) { invalidate('editing'); announce('Indica il prodotto da cercare.'); return; }
      search(b);
    }
    function resetGuide() {
      advisor.criteria=[];advisor.skipped=[];advisor.attributes=[];advisor.receipts={};advisor.confirmedReceipts={};advisor.draft=false;renderAdvisorCriteria();if(advisorControls)advisorControls.disabled=true;
      clearAdvisorInputs();
      needPatch = null; proposedNeed = null; skippedQuestions = [];
      var proposedView = find('[data-ks-guide-interpretation]'); if (proposedView) proposedView.replaceChildren();
      remember(state.confirmed); state.confirmed = null; state.confirmedGoal = ''; state.unknown = '';
      advisor.confirmedCriteria=[];advisor.confirmedSkipped=[];
      state.handoffSectorPending = false; handoffMessage('');
      syncFields(blank()); command.value = ''; newQuery.hidden = true;
      invalidate('idle'); summaryView(); announce('La guida è pronta per una nuova ricerca.'); input.focus();
    }
    function undoGuide() {
      if (!state.history.length) { announce('Non ci sono modifiche da annullare.'); return; }
      if (!state.confirmed && (clean(input.value) || clean(detail.value) || (goal && clean(goal.value)) || (budget && clean(budget.value)) || state.draftSector)) {
        announce('La richiesta è in modifica. Premi “Mostra i prodotti” per confermarla oppure “Ricomincia” per scartare la bozza.'); return;
      }
      if (!canRefineConfirmed()) return;
      var previous = state.history.pop();if(advisor.enabled){advisor.criteria=previous.advisor?previous.advisor.criteria:[];advisor.skipped=previous.advisor?previous.advisor.skipped:[];advisor.receipts=previous.advisor?Object.assign({},previous.advisor.receipts):{};} accept(previous.brief, false, previous.goal, true);
    }
    function prepareSearch() {
      if(advisor.enabled&&advisor.draft){announce('Usa Conferma criterio per applicare il requisito in bozza, oppure scegli la voce vuota per scartarlo.');return;}
      if (state.handoffSectorPending) {
        announce('Il reparto importato non è disponibile. Scegli un reparto proposto oppure “Tutti i reparti”, poi conferma la ricerca.');
        var choice = choices.find(function (item) { return !item.disabled && !item.hidden; });
        if (choice) choice.focus();
        return;
      }
      if (goal && clean(goal.value).length > MAX_GOAL) {
        invalidate('editing'); goal.setAttribute('aria-invalid', 'true');
        announce('Descrivi l’obiettivo in massimo 160 caratteri.'); goal.focus(); return;
      }
      if (goal) goal.removeAttribute('aria-invalid');
      var maximum;
      try { maximum = budget ? budgetValue(budget.value) : null; }
      catch (_) {
        invalidate('editing'); budget.setAttribute('aria-invalid', 'true');
        announce('Indica un budget maggiore di zero, senza separatori delle migliaia, ad esempio 500,50. Lascia vuoto per non fissare un limite.'); budget.focus(); return;
      }
      if (budget) budget.removeAttribute('aria-invalid');
      try {
        var b = copy(state.confirmed || blank());
        if (needPatch) b = Object.assign(b, needPatch);
        b.q = advisor.enabled&&!clean(input.value)&&!clean(detail.value)&&state.draftSector>0?'':queryText(input.value, detail.value); b.st = state.draftSector;
        if (maximum !== null) b.pmax = maximum;
        input.removeAttribute('aria-invalid'); detail.removeAttribute('aria-invalid');
        accept(b, true, goal ? clean(goal.value) : '');
      } catch (_) {
        invalidate('editing'); announce(goal && clean(goal.value) && !clean(input.value) ?
          'Per chiarire l’obiettivo, indica un prodotto, una marca o un codice da cercare. Puoi anche esplorare il catalogo o contattare il negozio.' :
          'Scrivi almeno 2 caratteri. Prodotto e dettaglio possono contenere al massimo 80 caratteri in tutto.');
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
        newQuery.textContent=advisor.enabled&&advisor.criteria.length?'Usa il testo come nuova ricerca senza i requisiti precedenti':'Usa il testo come nuova ricerca';
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
      if(state.result.advisor){
        article.appendChild(node('p',item.match==='complete'?'Rispetta tutti i criteri verificati':item.match==='partial'?'Requisiti obbligatori rispettati; preferenze da valutare':'Candidato senza requisiti sulle caratteristiche','ks-guide-match'));
        if(item.advisorReason)article.appendChild(node('p',item.advisorReason,'ks-guide-reason'));
        var sourceDetails=node('details'),sourceSummary=node('summary','Caratteristiche e fonti','ks-guide-edit');sourceDetails.appendChild(sourceSummary);
        item.facts.filter(function(f){var a=advisor.attributes.find(function(x){return x.id===f.attributeId;});return a&&(a.canAsk||a.canHardFilter)&&f.evidenceStatus==='known';}).slice(0,3).forEach(function(f){var a=advisor.attributes.find(function(x){return x.id===f.attributeId;});article.appendChild(node('p',a.label+': '+f.value+(a.unit?' '+a.unit:''),'ks-guide-evidence'));});
        var facts=node('dl',undefined,'ks-advisor-facts');
        item.facts.forEach(function(f){var a=advisor.attributes.find(function(x){return x.id===f.attributeId;});if(!a)return;
          facts.appendChild(node('dt',a.label));var value=f.evidenceStatus==='known'?f.value+(a.unit?' '+a.unit:''):{missing:'Dato non disponibile',ambiguous:'Dato ambiguo',conflicting:'Fonti discordanti'}[f.evidenceStatus];facts.appendChild(node('dd',value));
          if(f.evidenceText)facts.appendChild(node('dd',f.sourceField.split(',').map(function(field){return {'Descrizione1':'Titolo','Descrizione2':'Descrizione breve','DescrizioneLunga':'Descrizione lunga','DescrizioneHTML':'Scheda descrittiva','MarcheDescrizione':'Marca nel catalogo','Codice':'Codice','Ean':'EAN','SettoriDescrizione':'Reparto','CategorieDescrizione':'Categoria'}[field]||field;}).join(', ')+': «'+f.evidenceText+'»'));
        });sourceDetails.appendChild(facts);
        item.evaluations.forEach(function(e){var a=advisor.attributes.find(function(x){return x.id===e.attributeId;});article.appendChild(node('p',(a?a.label:'Criterio')+': '+{SATISFIED:'rispettato',VIOLATED:'non rispettato',UNKNOWN:'non verificabile'}[e.status]+(e.priority==='hard'?' (obbligatorio)':' (preferenza)'),'ks-guide-evidence'));});
        (item.textEvidence||[]).forEach(function(e){sourceDetails.appendChild(node('p','Nella '+({Descrizione2:'descrizione breve',DescrizioneLunga:'descrizione lunga',DescrizioneHTML:'scheda descrittiva',Descrizione1:'descrizione del prodotto'}[e.sourceField])+' viene indicato: «'+e.text+'». Corrispondenza testuale, non certificazione di idoneità.','ks-guide-evidence'));});article.appendChild(sourceDetails);
      } else {
      var proof = evidence(item, state.confirmed);
      article.appendChild(node('p', proof.matched.length && !proof.unverified.length ? 'Termini presenti nei dati' : 'Corrispondenza da verificare', 'ks-guide-match'));
      article.appendChild(node('p', reason(item, state.confirmed), 'ks-guide-reason ks-guide-evidence'));
      if (proof.unverified.length) article.appendChild(node('p', 'Non verificati nei dati mostrati: ' + proof.unverified.join(', ') + '.', 'ks-guide-unverified'));
      if (state.confirmed.pmax !== '0') article.appendChild(node('p', 'Rispetta il massimo confermato di ' + state.confirmed.pmax.replace('.', ',') + ' € nel contesto IVA indicato.', 'ks-guide-evidence'));
      if (state.confirmed.disponibile) article.appendChild(node('p', 'Rispetta il filtro disponibilità. Non è una promessa di consegna o prenotazione.', 'ks-guide-evidence'));
      if (state.confirmed.ordinamento === 'p_basso' && decision(state.result.items).lowest.indexOf(item.key) >= 0) article.appendChild(node('p', 'Da approfondire se la priorità è il prezzo: minimo fra i candidati restituiti, non dell’intero catalogo.', 'ks-guide-evidence'));
      var requirements = interpretNeed(state.confirmedGoal).limits;
      if (requirements.length) article.appendChild(node('p', requirements.join(' '), 'ks-guide-unverified'));
      }
      article.appendChild(link(item.availability > 0 ? 'Vai alla scheda e acquista' : 'Scopri questo prodotto', item.url, 'ks-guide-product-cta'));
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
      var insight = decision(items), lowest = items.filter(function (item) { return insight.lowest.indexOf(item.key) >= 0; });
      var comparedAttributes=state.result.advisor?advisor.attributes.filter(function(a){return advisor.criteria.some(function(c){return c.attributeId===a.id;})||items.some(function(item){return item.facts.some(function(f){return f.attributeId===a.id&&f.evidenceStatus==='known';});})&&(a.canAsk||a.canHardFilter);}).sort(function(a,b){return Number(advisor.criteria.some(function(c){return c.attributeId===b.id;}))-Number(advisor.criteria.some(function(c){return c.attributeId===a.id;}));}).slice(0,8):[];
      function comparedFact(item,a){var f=item.facts.find(function(value){return value.attributeId===a.id;});return !f||f.evidenceStatus==='missing'?'Dato non disponibile':f.evidenceStatus!=='known'?'Dato non verificabile':f.value+(a.unit?' '+a.unit:'');}
      comparedAttributes.forEach(function(a){if(new Set(items.map(function(item){return comparedFact(item,a);})).size>1)insight.differences.push(a.label);});
      var overview = node('div', undefined, 'ks-guide-decision-summary');
      overview.appendChild(node('p', 'Prezzo visualizzato più basso fra questi ' + items.length + ' prodotti: ' +
        lowest.map(function (item) { return item.title; }).join(' · ') + ' (' + lowest[0].price + ').' + (lowest.length > 1 ? ' Più prodotti hanno lo stesso prezzo visualizzato.' : '')));
      overview.appendChild(node('p', insight.differences.length ? 'Dati che differiscono: ' + insight.differences.join(', ').toLocaleLowerCase('it-IT') + '.' : 'I dati commerciali confrontabili non mostrano differenze.'));
      overview.appendChild(node('p', 'Il prezzo minimo riguarda solo questo confronto. Un dato mancante non prova una differenza del prodotto; idoneità e compatibilità restano da verificare nella scheda.'));
      comparison.appendChild(overview);
      var grid = node('div', undefined, 'ks-guide-compare-grid');
      grid.setAttribute('role', 'region'); grid.setAttribute('aria-label', 'Confronto prodotti, scorri orizzontalmente se necessario'); grid.tabIndex = 0;
      grid.style.setProperty('--ks-guide-columns', String(items.length));
      var table = node('table'), head = node('thead'), titles = node('tr'), data = node('tbody');
      var first = node('th', 'Dato'); first.scope = 'col'; titles.appendChild(first);
      items.forEach(function (item) {
        var column = node('th', undefined, 'ks-guide-compare-item'); column.scope = 'col';
        var title = node('h4'); title.appendChild(link(item.title, item.url, 'ks-guide-product-link')); column.appendChild(title);
        column.appendChild(link('Scopri questo prodotto', item.url, 'ks-guide-product-cta'));
        var remove = button('Rimuovi dal confronto', function () {
          var check = Array.from(root.querySelectorAll('[data-ks-guide-compare-key]')).find(function (control) { return control.getAttribute('data-ks-guide-compare-key') === item.key; });
          (check || prepare).focus(); if (check) check.checked = false;
          state.selected = state.selected.filter(function (key) { return key !== item.key; }); renderCompare();
          announce('Prodotto rimosso dal confronto.');
        });
        remove.setAttribute('aria-label', 'Rimuovi dal confronto ' + item.title); column.appendChild(remove);
        titles.appendChild(column);
      });
      var compareFields=[['Prezzo', function (item) { return item.price; }], ['Disponibilità', stock],
        ['Marca', function (item) { return item.brand; }], ['Categoria', function (item) { return item.category; }],
        ['Codice', function (item) { return item.code; }], ['Condizione', function (item) { return item.refurbished ? 'Ricondizionato' : ''; }],
        ['Offerta', function (item) { return item.offer ? 'Applicabile' : 'Non indicata'; }],
        ['Corrispondenze verificate', function (item) { return reason(item, state.confirmed); }],
        ['Da verificare', function (item) { var missing = evidence(item, state.confirmed).unverified; return missing.length ? missing.join(', ') : 'Idoneità all’obiettivo e caratteristiche nella scheda'; }]];
      if(state.result.advisor){compareFields=compareFields.slice(0,7).concat(comparedAttributes.map(function(a){return [a.label,function(item){return comparedFact(item,a);}];}));comparison.appendChild(node('p','Confronto delle caratteristiche documentate: fino a otto, con priorità ai criteri confermati. Le fonti complete sono nelle card.','ks-guide-hint'));}
      compareFields.forEach(function (field) {
          var row = node('tr', undefined, insight.differences.indexOf(field[0]) >= 0 ? 'ks-guide-difference' : ''), label = node('th', field[0]); label.scope = 'row'; row.appendChild(label);
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
      comparison.appendChild(button('Correggi una preferenza', function () {
        invalidate('editing'); (budget || command).focus(); announce('Modifica il brief e premi “Mostra i prodotti”. Il confronto verrà ricostruito con la nuova selezione.');
      }));
      announce('Confronto aggiornato: ' + items.length + ' prodotti.');
    }
    function nextQuestion(container) {
      if(advisor.enabled)return;
      var b = state.confirmed, proposal = chooseQuestion(state.result.items, b, skippedQuestions);
      if (!proposal) return;
      var question = node('div', undefined, 'ks-guide-question');
      question.append(node('p', proposal.message), node('p', 'La domanda riguarda soltanto i candidati attuali, non l’intero catalogo.', 'ks-guide-hint'), button('Scegli questa preferenza', function () {
        if (!canRefineConfirmed()) return;
        command.focus(); accept(Object.assign(copy(b), proposal.patch), true);
      }), button('Salta', function () { skippedQuestions.push(proposal.key); command.focus(); question.remove(); nextQuestion(container); }));
      container.appendChild(question);
    }
    function renderResult() {
      var data = state.result, b = state.confirmed;
      if(data.advisor){renderAdvisor(data.advisor);results.appendChild(node('h3',data.items.length?'Candidati autorizzati':'Nessun conforme nella selezione analizzata'));results.appendChild(node('p',data.label,'ks-guide-fiscal'));if(data.items.length){var cards=node('div',undefined,'ks-guide-grid');data.items.forEach(function(item){cards.appendChild(productCard(item));});results.appendChild(cards);}results.appendChild(link('Esplora il catalogo con i filtri commerciali',data.catalog));return;}
      results.appendChild(node('h3', data.items.length ? 'Una selezione per la tua ricerca' : 'Nessun risultato in questa selezione'));
      results.appendChild(node('p', data.items.length + ' risultati restituiti, fino a 6. Non è il totale del catalogo.', 'ks-guide-hint'));
      results.appendChild(node('p', data.label, 'ks-guide-fiscal'));
      var filters = [];
      if (b.st) filters.push('reparto ' + departments.get(b.st));
      if (b.pmax !== '0') filters.push('massimo ' + b.pmax.replace('.', ',') + ' €');
      if (b.disponibile) filters.push('solo disponibili');
      if (filters.length) results.appendChild(node('p', 'Filtri applicati: ' + filters.join(' · ') + '.', 'ks-guide-evidence'));
      if (state.confirmedGoal) results.appendChild(node('p', 'L’idoneità al tuo obiettivo non è verificata dalla ricerca.', 'ks-guide-unverified'));
      results.appendChild(node('p', 'Le corrispondenze sono testuali. Caratteristiche, compatibilità e idoneità all’uso vanno verificate nella scheda o con il negozio.', 'ks-guide-hint'));
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
    function recover(message, invalid, criterionScopeChanged) {
      invalidate(invalid ? 'context-invalid' : 'error'); announce(message);
      if (state.confirmed && (state.confirmed.q || advisor.enabled&&state.confirmed.st>0)) {
        if(criterionScopeChanged){var reconfirm=button('Conferma la ricerca senza le caratteristiche del contesto precedente',function(){
          if(!canRefineConfirmed())return;prepare.focus();advisor.criteria=[];advisor.skipped=[];advisor.receipts={};renderAdvisorCriteria();accept(copy(state.confirmed),true);
        });reconfirm.setAttribute('data-ks-advisor-reconfirm','');recovery.appendChild(reconfirm);}
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
      var snapshot=advisor.enabled?{criteria:JSON.parse(JSON.stringify(advisor.criteria)),skipped:advisor.skipped.slice(),receipts:advisor.criteria.filter(function(c){return !!advisor.receipts[c.attributeId];}).map(function(c){return {attributeId:c.attributeId,receipt:advisor.receipts[c.attributeId]};})}:null;
      var request = { brief: copy(b), controller: controller, timer: null, advisorSignature:advisorSignature() }; state.request = request;
      try {
        var timeout = new win.Promise(function (_, reject) {
          request.timer = win.setTimeout(function () { controller.abort(); reject(new Error('timeout')); }, 8000);
        });
        var operation = (async function () {
          var headers={Accept:'application/json'};
          if(snapshot&&snapshot.receipts.length)headers['X-KeepStore-Advisor-Criteria']=JSON.stringify(snapshot.receipts);
          var response = await win.fetch(snapshot?requestAdvisorURL(b,paths,snapshot.criteria,snapshot.skipped):requestURL(b, paths), { method: 'GET', credentials: 'same-origin', cache: 'no-store', redirect: 'error',
            headers: headers, signal: controller.signal });
          if (!response.ok) throw new Error('http-' + response.status);
          if (!/^application\/json(?:;|$)/i.test(response.headers.get('content-type') || '') ||
              Number(response.headers.get('content-length')) > (snapshot?196608:MAX_BODY)) throw new Error('payload');
          var raw = await response.text();
          if (raw.length > (snapshot?196608:MAX_BODY)) throw new Error('payload');
          return snapshot?validateAdvisor(JSON.parse(raw),b,paths,snapshot.criteria,snapshot.skipped):validate(JSON.parse(raw), b, paths);
        }());
        var result = await win.Promise.race([operation, timeout]);
        if (generation !== state.generation || state.request !== request) return;
        state.result = result; phase(result.items.length ? 'results' : 'empty');
        renderResult(); announce(result.items.length ? 'Selezione aggiornata: ' + result.items.length + ' prodotti.' : 'La ricerca non ha restituito risultati con queste preferenze.');
      } catch (error) {
        if (generation !== state.generation || state.request !== request) return;
        var code = error.message, criterionScopeChanged=!!snapshot&&code==='http-409',invalid = code === 'http-403' || code === 'http-421'||criterionScopeChanged;
        var message = criterionScopeChanged ? 'Il contesto delle caratteristiche è cambiato. Conferma una nuova selezione; i requisiti precedenti non vengono rimossi automaticamente.' : invalid ? 'Contesto commerciale non disponibile. Aggiorna la selezione o continua nel catalogo.' :
          code === 'http-400' ? 'La richiesta non è valida. Controlla prodotto e preferenze.' :
          code === 'http-429' ? 'Troppe richieste. Attendi prima di riprovare.' :
          code === 'http-503' ? 'Il servizio è temporaneamente non disponibile.' :
          code === 'criteria' ? 'La risposta contiene prodotti fuori dai vincoli confermati. La selezione non è stata mostrata: riprova o continua nel catalogo.' :
          code === 'timeout' ? 'La richiesta sta impiegando troppo tempo. Puoi riprovare.' :
          'Non è stato possibile verificare la selezione. Controlla la connessione o riprova.';
        recover(message, invalid, criterionScopeChanged);
      } finally {
        win.clearTimeout(request.timer);
        if (state.request === request) { state.request = null; root.removeAttribute('aria-busy'); prepare.removeAttribute('aria-disabled'); }
      }
    }
    try {
      root.querySelectorAll('[data-ks-guide-mode]').forEach(function(control){control.addEventListener('click',function(){
        var enabled=control.getAttribute('data-ks-guide-mode')==='guided2';if(enabled===advisor.enabled)return;
        invalidate('editing');advisor.enabled=enabled;advisor.criteria=[];advisor.skipped=[];advisor.attributes=[];advisor.draft=false;advisor.confirmedCriteria=[];advisor.confirmedSkipped=[];
        state.confirmed=null;state.history=[];state.confirmedGoal='';needPatch=null;summaryView();renderAdvisorCriteria();clearAdvisorInputs();if(advisorPanel)advisorPanel.hidden=!enabled;
        root.querySelectorAll('[data-ks-guide-mode]').forEach(function(x){x.setAttribute('aria-pressed',x===control?'true':'false');});
        announce(enabled?'Scelta per caratteristiche attiva. Conferma la ricerca o scegli un reparto; nessuna richiesta è stata inviata.':'Ricerca guidata attiva. Conferma di nuovo i criteri per vedere una selezione aggiornata.');
      });});
      if(advisorAttribute){advisorAttribute.addEventListener('change',function(){advisorInputs();advisor.draft=!!advisorAttribute.value;invalidate('editing');announce(advisor.draft?'Caratteristica in bozza: scegli valore e importanza, poi Conferma criterio.':'Bozza scartata. Conferma la ricerca per aggiornare la selezione.');});
        [advisorOperator,advisorValue,advisorPriority].forEach(function(control){control.addEventListener('change',function(){advisor.draft=!!advisorAttribute.value;invalidate('editing');});});
        var add=find('[data-ks-advisor-add]');if(add)add.addEventListener('click',function(){
          var a=advisor.attributes.find(function(x){return x.id===advisorAttribute.value;});
          var value=a&&a.type==='number'&&advisorNumber?clean(advisorNumber.value).replace(',','.'):advisorValue.value;
          if(!a||a.operators.indexOf(advisorOperator.value)<0||(a.type==='number'?!/^(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,6})?$/.test(value)||Number(value)>1000000000:a.observedValues.indexOf(value)<0)||advisorPriority.value==='hard'&&!a.canHardFilter){announce('Scegli un criterio consentito. Per i numeri usa da 0 a un miliardo e al massimo sei decimali, senza separatori delle migliaia.');return;}
          var draft=advisor.draft;advisor.draft=false;if(!canRefineConfirmed()){advisor.draft=draft;return;}
          var next=advisor.criteria.filter(function(c){return c.attributeId!==a.id;});if(next.length>=8){advisor.draft=draft;announce('Puoi confermare al massimo otto criteri.');return;}
          next.push({attributeId:a.id,operator:advisorOperator.value,value:value,priority:advisorPriority.value});advisor.receipts[a.id]=a.receipt;command.focus();advisor.criteria=next;accept(copy(state.confirmed),true);
        });
        if(advisorNumber){advisorNumber.addEventListener('input',function(){advisor.draft=!!advisorAttribute.value;invalidate('editing');});advisorNumber.addEventListener('keydown',function(event){if(event.key==='Enter'){event.preventDefault();if(!event.isComposing&&event.keyCode!==229&&add)add.click();}});}
      }
      var understand = find('[data-ks-guide-understand]'), interpretation = find('[data-ks-guide-interpretation]');
      if (understand && interpretation && goal) understand.addEventListener('click', function () {
        invalidate('editing'); proposedNeed = interpretNeed(goal.value); interpretation.replaceChildren();
        interpretation.appendChild(node('p', 'Interpretazione proposta: conferma o correggi, senza ricerca automatica.'));
        proposedNeed.limits.concat(proposedNeed.conflicts).forEach(function (message) { interpretation.appendChild(node('p', message, 'ks-guide-unverified')); });
        if (proposedNeed.query && !proposedNeed.conflicts.length) {
          interpretation.appendChild(node('p', 'Parole espresse nel bisogno: ' + proposedNeed.query));
          Object.keys(proposedNeed.patch).forEach(function (key) {
            var value = proposedNeed.patch[key];
            var label = key === 'disponibile' ? (value ? 'Solo disponibili' : 'Includi anche i non disponibili') : key === 'ordinamento' ? (value ? 'Prima i meno costosi' : 'Ordina per pertinenza') : (key === 'pmax' ? 'Prezzo massimo: ' : 'Prezzo minimo: ') + String(value).replace('.', ',') + ' €';
            interpretation.appendChild(node('p', 'Preferenza espressa: ' + label));
          });
          interpretation.appendChild(button(proposedNeed.limits.length ? 'Continua sui soli criteri supportati' : 'Usa questa proposta nel brief', function () {
            if (clean(goal.value) !== proposedNeed.source) { announce('Il bisogno è cambiato. Rileggilo prima di confermare la proposta.'); return; }
            var max = proposedNeed.patch.pmax;
            var currentMaximum; try { currentMaximum = budget && clean(budget.value) ? budgetValue(budget.value) : null; } catch (_) { announce('Correggi il budget nel campo prima di usare la proposta.'); budget.focus(); return; }
            if (max && currentMaximum && currentMaximum !== max) { announce('Il budget del bisogno e quello nel campo sono diversi. Correggi uno dei due prima di confermare.'); budget.focus(); return; }
            input.value = proposedNeed.query; detail.value = '';
            needPatch = copy(proposedNeed.patch);
            if (max && budget) budget.value = max === '0' ? '' : max.replace('.', ',');
            // Non-price criteria are shown for a second, explicit commercial confirmation.
            interpretation.appendChild(node('p', 'Controlla il brief e premi Mostra i prodotti.'));
            reviewDraft(); prepare.focus();
          }));
        } else {
          interpretation.appendChild(node('p', 'Quale famiglia di prodotti intendi? Scegli un reparto reale oppure precisa con «Cerco …». Nessun prodotto è stato dedotto.'));
          choices.filter(function (choice) { return !choice.disabled && Number(choice.getAttribute('data-ks-guide-sector')) > 0; }).forEach(function (choice) {
            interpretation.appendChild(button(clean(choice.textContent), function () {
              choice.click(); var name = clean(choice.textContent);
              if (name.length <= MAX_TEXT) { input.value = name; detail.value = ''; reviewDraft(); }
              input.focus(); announce('Famiglia scelta dalla tassonomia del negozio. Controlla le parole proposte e conferma con Mostra i prodotti.');
            }));
          });
        }
      });
      choices.forEach(function (choice) {
        if (choice.disabled) return;
        choice.addEventListener('click', function () {
          if (state.handoffSectorPending) { state.handoffSectorPending = false; handoffMessage('Reparto scelto. Controlla la bozza e premi “Mostra i prodotti”.'); }
          state.draftSector = Number(choice.getAttribute('data-ks-guide-sector'));
          if(advisor.enabled){advisor.criteria=[];advisor.skipped=[];advisor.attributes=[];advisor.draft=false;renderAdvisorCriteria();clearAdvisorInputs();}
          choices.forEach(function (other) { other.setAttribute('aria-pressed', other === choice ? 'true' : 'false'); });
          invalidate('editing'); reviewDraft(); announce('Reparto modificato. Premi “Mostra i prodotti” per confermare.');
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
      [input, detail, command, goal, budget].filter(Boolean).forEach(function (field) {
        field.addEventListener('input', function () {
          if (field === goal) needPatch = null;
          invalidate('editing'); state.unknown = ''; newQuery.hidden = true;
          field.removeAttribute('aria-invalid'); reviewDraft();
          announce(field === command ? 'Preferenza in modifica. Premi “Applica preferenza” per confermare.' : 'Richiesta in modifica. Premi “Mostra i prodotti” per confermare.');
        });
        field.addEventListener('keydown', function (event) {
          if (event.key === 'Enter' && field !== goal) {
            event.preventDefault();
            if (!event.isComposing && event.keyCode !== 229) { if (field === command) runCommand(command.value); else prepareSearch(); }
          }
        });
      });
      win.addEventListener('pagehide', contextInvalid);
      win.addEventListener('pageshow', function (event) { if (event.persisted) contextInvalid(); });
      win.addEventListener('blur', contextInvalid);
      doc.addEventListener('visibilitychange', function () { if (doc.hidden) contextInvalid(); });
      phase('idle'); summaryView(); reviewDraft();
      instances.add(root); root.setAttribute('data-ks-guide-bound', '1');
      fields.hidden = false; fields.disabled = false; output.hidden = false;
      var fallback = find('.ks-guide-fallback-departments'); if (fallback) fallback.hidden = true;
      var handoff = catalogHandoff(win.location.search, departments);
      if (handoff.kind === 'invalid') {
        handoffMessage('La ricerca del catalogo non è stata importata. Scrivi cosa cerchi e scegli se limitare a un reparto.');
      } else if (handoff.kind === 'draft') {
        var draft = blank(); draft.q = handoff.q; draft.st = handoff.sectorUnavailable ? 0 : handoff.st;
        syncFields(draft); phase('editing'); state.handoffSectorPending = handoff.sectorUnavailable;
        if (handoff.sectorUnavailable) choices.forEach(function (choice) { choice.setAttribute('aria-pressed', 'false'); });
        handoffMessage(handoff.sectorUnavailable ?
          'Il reparto del catalogo non è disponibile nella guida. Scegli un reparto proposto oppure “Tutti i reparti”, poi premi “Mostra i prodotti”.' :
          'Ricerca importata dal catalogo come bozza. Controllala e premi “Mostra i prodotti” per confermarla.');
        if (handoff.sectorUnavailable && handoffNotice && !choices.some(function (choice) { return !choice.disabled && !choice.hidden; })) {
          handoffNotice.appendChild(button('Usa tutti i reparti', function () {
            state.handoffSectorPending = false; state.draftSector = 0; prepare.focus();
            handoffMessage('Hai scelto tutti i reparti. Controlla la bozza e premi “Mostra i prodotti”.');
          }));
        }
      }
    } catch (_) {
      fields.hidden = true; fields.disabled = true; refine.hidden = true; refine.disabled = true;
      output.hidden = true; summary.hidden = true; idle.hidden = false;
    }
  }
  return { init: init, parseCommand: parseCommand, queryText: queryText, blank: blank, urls: urls,
    requestURL: requestURL, catalogURL: catalogURL, validate: validate, reason: reason, evidence: evidence, decision: decision,
    budgetValue: budgetValue, interpretNeed: interpretNeed, chooseQuestion: chooseQuestion, catalogHandoff: catalogHandoff,
    requestAdvisorURL:requestAdvisorURL,validateAdvisor:validateAdvisor };
}));
