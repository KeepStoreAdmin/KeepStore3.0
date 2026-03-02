(function () {
  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function isCatalogPage() {
    return /articoli\.aspx$/i.test(location.pathname || '');
  }

  // ----------------------------------------------------------
  // Query helpers (no URLSearchParams dependency)
  // ----------------------------------------------------------
  function parseQuery() {
    var out = {};
    var q = (location.search || '').replace(/^\?/, '');
    if (!q) return out;
    var parts = q.split('&');
    for (var i = 0; i < parts.length; i++) {
      var kv = parts[i].split('=');
      var k = decodeURIComponent((kv[0] || '').replace(/\+/g, ' ')).trim();
      if (!k) continue;
      var v = decodeURIComponent((kv[1] || '').replace(/\+/g, ' '));
      out[k] = v;
    }
    return out;
  }

  function buildQuery(obj) {
    var parts = [];
    for (var k in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, k)) continue;
      if (obj[k] === null || typeof obj[k] === 'undefined' || obj[k] === '') continue;
      parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(String(obj[k])));
    }
    return parts.join('&');
  }

  function buildResetUrl() {
    // Manteniamo solo i parametri "categoria" osservati sui menu:
    // es: ?ct=35&st=2&tp=249
    var q = parseQuery();
    var keep = {};
    var keys = ['ct', 'st', 'tp'];
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (q[key]) keep[key] = q[key];
    }
    var qs = buildQuery(keep);
    return (location.pathname || 'articoli.aspx') + (qs ? ('?' + qs) : '');
  }

  function ensureCss(href) {
    try {
      var links = document.querySelectorAll('link[rel="stylesheet"]');
      for (var i = 0; i < links.length; i++) {
        var h = links[i].getAttribute('href') || '';
        if (h.toLowerCase().indexOf(href.toLowerCase()) !== -1) return;
      }
      var link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = href;
      document.head.appendChild(link);
    } catch (e) { }
  }

  function addClassIf(el, cls) {
    if (!el || !el.classList) return;
    el.classList.add(cls);
  }

  function removeInlineStyle(el) {
    if (!el) return;
    try {
      if (el.hasAttribute('style')) el.removeAttribute('style');
    } catch (e) { }
  }

  function makeTitle(text) {
    var h = document.createElement('div');
    h.className = 'ks-filter-title';
    h.textContent = text;
    return h;
  }

  function wrapFilterBox(el, title) {
    if (!el || el.dataset.ksWrapped === '1') return;
    el.dataset.ksWrapped = '1';

    addClassIf(el, 'ks-filter-box');
    removeInlineStyle(el);

    if (title) {
      el.insertBefore(makeTitle(title), el.firstChild);
    }

    // normalize common input UI
    var selects = el.querySelectorAll('select');
    for (var s = 0; s < selects.length; s++) addClassIf(selects[s], 'form-select');

    var cbs = el.querySelectorAll('input[type=checkbox]');
    for (var i = 0; i < cbs.length; i++) addClassIf(cbs[i], 'form-check-input');

    // if lots of children -> add scroll wrapper (best-effort)
    var elementChildren = [];
    for (var k = 0; k < el.childNodes.length; k++) {
      var n = el.childNodes[k];
      if (n.nodeType === 1 && n.classList && n.classList.contains('ks-filter-title')) continue;
      elementChildren.push(n);
    }
    if (elementChildren.length > 10 && !el.querySelector('.ks-filter-scroll')) {
      var scroll = document.createElement('div');
      scroll.className = 'ks-filter-scroll';
      for (var j = 0; j < elementChildren.length; j++) scroll.appendChild(elementChildren[j]);
      el.appendChild(scroll);
    }
  }

  // ==========================================================
  // Active filters (chips)
  // ==========================================================
  function ensureActiveFiltersHost() {
    var host = document.getElementById('ksActiveFilters');
    if (host) return host;

    host = document.createElement('div');
    host.id = 'ksActiveFilters';
    host.className = 'ks-active-filters';

    // Insert after toolbar when possible; otherwise before the products grid.
    var toolbar = document.querySelector('.ks-catalog-toolbar');
    if (toolbar && toolbar.parentNode) {
      toolbar.insertAdjacentElement('afterend', host);
      return host;
    }

    var grid = document.getElementById('GridView1');
    if (grid && grid.parentNode) {
      grid.parentNode.insertBefore(host, grid);
      return host;
    }

    var main = document.querySelector('main') || document.body;
    if (main.firstChild) main.insertBefore(host, main.firstChild);
    else main.appendChild(host);
    return host;
  }

  function getLabelForInput(input) {
    if (!input) return '';

    // Try explicit label[for]
    var id = input.getAttribute('id');
    if (id) {
      var lbl = document.querySelector('label[for="' + id.replace(/"/g, '') + '"]');
      if (lbl && lbl.textContent) return lbl.textContent.trim();
    }

    // Try parent label
    var p = input.parentElement;
    if (p && p.tagName && p.tagName.toLowerCase() === 'label') {
      return (p.textContent || '').trim();
    }

    // Try closest label
    if (input.closest) {
      var cl = input.closest('label');
      if (cl && cl.textContent) return cl.textContent.trim();
    }

    // Fallback: sibling text
    if (input.nextSibling && input.nextSibling.nodeType === 3) {
      var t = (input.nextSibling.nodeValue || '').trim();
      if (t) return t;
    }
    return '';
  }

  function addChip(host, text, removeFn) {
    if (!text) return;

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ks-chip';
    btn.setAttribute('aria-label', 'Rimuovi filtro: ' + text);
    btn.innerHTML = '<span class="ks-chip-label"></span><span class="ks-chip-x" aria-hidden="true">×</span>';
    btn.querySelector('.ks-chip-label').textContent = text;

    btn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      try { if (typeof removeFn === 'function') removeFn(); } catch (e) { }
    });

    host.appendChild(btn);
  }

  function normalizeSelectValue(sel) {
    if (!sel) return '';
    var v = sel.value;
    if (v === null || typeof v === 'undefined') return '';
    v = String(v);
    if (v === '' || v === '0' || v === '-1') return '';
    // Some legacy selects use "" for default
    if (sel.selectedIndex <= 0) return '';
    return v;
  }

  function setSelectToDefault(sel) {
    if (!sel) return;
    try {
      sel.selectedIndex = 0;
      if (typeof sel.onchange === 'function') sel.onchange();
      else triggerChange(sel);
    } catch (e) {
      try { sel.selectedIndex = 0; } catch (e2) { }
    }
  }

  function triggerChange(el) {
    if (!el) return;
    try {
      if (document.createEvent) {
        var evt = document.createEvent('HTMLEvents');
        evt.initEvent('change', true, false);
        el.dispatchEvent(evt);
        return;
      }
    } catch (e) { }

    try {
      if (el.fireEvent) {
        el.fireEvent('onchange');
      }
    } catch (e2) { }
  }

  function renderActiveFilters() {
    if (!isCatalogPage()) return;
    var host = ensureActiveFiltersHost();
    if (!host) return;

    // Reset content
    host.innerHTML = '';

    // Left group: chips
    var chipsWrap = document.createElement('div');
    chipsWrap.className = 'ks-active-filters-chips';
    host.appendChild(chipsWrap);

    // Right group: actions
    var actions = document.createElement('div');
    actions.className = 'ks-active-filters-actions';
    host.appendChild(actions);

    // Build chips from known controls
    var cbDisp = document.querySelector('#CheckBox_Disponibile, input[type=checkbox][id*="CheckBox_Disponibile"]');
    if (cbDisp && cbDisp.checked) {
      addChip(chipsWrap, 'Disponibili', function () { try { cbDisp.click(); } catch (e) { } });
    }

    var selTaglia = document.querySelector('#Drop_Filtra_Taglia, select[id*="Drop_Filtra_Taglia"]');
    if (selTaglia && normalizeSelectValue(selTaglia)) {
      var txtT = (selTaglia.options[selTaglia.selectedIndex] && selTaglia.options[selTaglia.selectedIndex].text) ? selTaglia.options[selTaglia.selectedIndex].text.trim() : 'Selezionato';
      addChip(chipsWrap, 'Taglia: ' + txtT, function () { setSelectToDefault(selTaglia); });
    }

    var selColore = document.querySelector('#Drop_Filtra_Colore, select[id*="Drop_Filtra_Colore"]');
    if (selColore && normalizeSelectValue(selColore)) {
      var txtC = (selColore.options[selColore.selectedIndex] && selColore.options[selColore.selectedIndex].text) ? selColore.options[selColore.selectedIndex].text.trim() : 'Selezionato';
      addChip(chipsWrap, 'Colore: ' + txtC, function () { setSelectToDefault(selColore); });
    }

    // Advanced filters: checked checkboxes within filter boxes
    var boxes = ['filtersMr', 'filtersTp', 'filtersGr', 'filtersSg', 'filtritagliaecolore'];
    for (var b = 0; b < boxes.length; b++) {
      var box = document.getElementById(boxes[b]);
      if (!box) continue;

      var titleEl = box.querySelector('.ks-filter-title');
      var title = titleEl ? (titleEl.textContent || '').trim() : '';

      var checks = box.querySelectorAll('input[type=checkbox]:checked');
      for (var c = 0; c < checks.length; c++) {
        var chk = checks[c];
        // Skip the main "solo disponibili" (it's outside these blocks usually, but just in case)
        if (chk.id && chk.id.indexOf('CheckBox_Disponibile') !== -1) continue;

        var lbl = getLabelForInput(chk);
        if (!lbl) continue;
        // Remove common noise from label text
        lbl = lbl.replace(/\s{2,}/g, ' ').trim();
        var chipText = title ? (title + ': ' + lbl) : lbl;

        addChip(chipsWrap, chipText, (function (x) {
          return function () { try { x.click(); } catch (e) { } };
        })(chk));
      }
    }

    // If no chips, hide the host entirely (but keep in DOM for updates)
    var hasAny = chipsWrap.children && chipsWrap.children.length > 0;
    host.style.display = hasAny ? '' : 'none';

    // Actions: Reset filters
    var reset = document.createElement('a');
    reset.className = 'ks-filter-reset';
    reset.href = buildResetUrl();
    reset.textContent = 'Reset filtri';
    actions.appendChild(reset);

    // Optional: show results label if present
    var lblRes = document.getElementById('lblRisultati');
    if (lblRes && lblRes.textContent) {
      var small = document.createElement('div');
      small.className = 'ks-active-filters-meta';
      small.textContent = lblRes.textContent.trim();
      actions.appendChild(small);
    }
  }

  function addSearchToFilter(el, placeholder) {
    if (!el || el.dataset.ksSearch === '1') return;
    el.dataset.ksSearch = '1';

    // Prefer searching inside scroll container if present
    var container = el.querySelector('.ks-filter-scroll') || el;

    var items = container.querySelectorAll('label, .form-check, span');
    if (!items || items.length < 14) return; // only for longer lists

    var input = document.createElement('input');
    input.type = 'search';
    input.className = 'ks-filter-search';
    input.autocomplete = 'off';
    input.placeholder = placeholder || 'Cerca…';

    // Insert after title if present
    var title = el.querySelector('.ks-filter-title');
    if (title && title.parentNode === el) {
      title.insertAdjacentElement('afterend', input);
    } else {
      el.insertBefore(input, el.firstChild);
    }

    input.addEventListener('input', function () {
      var q = (input.value || '').toLowerCase().trim();
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var t = (it.textContent || '').toLowerCase();
        if (!q || t.indexOf(q) !== -1) {
          it.style.display = '';
        } else {
          it.style.display = 'none';
        }
      }
    });
  }

  function normalizePager() {
    var candidates = document.querySelectorAll('.pagination-ys, .Pager, .pager, .pagination, .nav');
    for (var i = 0; i < candidates.length; i++) addClassIf(candidates[i], 'ks-pager');
  }

  function normalizeToolbar() {
    var ord = document.querySelector('select[id*="Drop_Ordinamento"], #Drop_Ordinamento');
    if (ord) addClassIf(ord, 'form-select');

    var righe = document.querySelector('select[id*="Drop_Righe"], #Drop_Righe');
    if (righe) addClassIf(righe, 'form-select');

    var taglia = document.querySelector('select[id*="Drop_Filtra_Taglia"], #Drop_Filtra_Taglia');
    if (taglia) addClassIf(taglia, 'form-select');

    var colore = document.querySelector('select[id*="Drop_Filtra_Colore"], #Drop_Filtra_Colore');
    if (colore) addClassIf(colore, 'form-select');

    // try to tag the closest container as toolbar (best effort)
    var toolbar = null;
    if (ord) toolbar = ord.closest('.ks-catalog-toolbar') || ord.parentElement;
    if (toolbar) addClassIf(toolbar, 'ks-catalog-toolbar');
  }

  // ==========================================================
  // Mobile offcanvas filters (no clone, no duplicate IDs)
  // ==========================================================
  function bindFilterTriggers() {
    var openFn = window.__ksFilterPanelOpen;
    if (typeof openFn !== 'function') return;

    // Prefer toolbar button if present
    var tb = document.getElementById('ksToolbarFiltersBtn');
    if (tb && tb.dataset && tb.dataset.ksBound !== '1') {
      tb.dataset.ksBound = '1';
      tb.addEventListener('click', function (ev) {
        try { ev.preventDefault(); } catch (e) { }
        openFn();
      });
    }

    // Fallback floating FAB (created only if toolbar trigger is missing)
    var fab = document.getElementById('ksFiltersFab');
    if (fab && fab.dataset && fab.dataset.ksBound !== '1') {
      fab.dataset.ksBound = '1';
      fab.addEventListener('click', function (ev) {
        try { ev.preventDefault(); } catch (e) { }
        openFn();
      });
    }
  }

  function setupMobileOffcanvasFilters() {
    if (!isCatalogPage()) return;

    var filterEls = [];
    // Include also the main "Disponibili" checkbox block (mobile)
    var ids = ['filtersDisp', 'filtersMr', 'filtersTp', 'filtersGr', 'filtersSg', 'filtritagliaecolore'];
    for (var i = 0; i < ids.length; i++) {
      var el = document.getElementById(ids[i]);
      if (el) filterEls.push(el);
    }
    if (filterEls.length === 0) return;

    // Already created: just ensure triggers are wired
    if (document.getElementById('ksFilterPanel')) {
      bindFilterTriggers();
      return;
    }

    // If a toolbar trigger exists, don't render floating FAB
    var toolbarBtn = document.getElementById('ksToolbarFiltersBtn');
    var useFab = !toolbarBtn;

    // Floating button (fallback)
    if (useFab) {
      var fab = document.createElement('button');
      fab.type = 'button';
      fab.className = 'ks-filter-fab';
      fab.id = 'ksFiltersFab';
      fab.innerHTML = '<span aria-hidden="true">☰</span><span>Filtri</span>';
      document.body.appendChild(fab);
    }

    // Overlay + panel
    var overlay = document.createElement('div');
    overlay.className = 'ks-filter-overlay';
    overlay.id = 'ksFilterOverlay';
    document.body.appendChild(overlay);

    var panel = document.createElement('div');
    panel.className = 'ks-filter-panel';
    panel.id = 'ksFilterPanel';
    panel.setAttribute('role', 'dialog');
    panel.setAttribute('aria-modal', 'true');
    panel.setAttribute('aria-label', 'Filtri');
    panel.innerHTML =
      '<div class="ks-filter-panel-header">' +
      '  <div class="ks-filter-panel-title">Filtri</div>' +
      '  <button type="button" class="ks-filter-panel-close" id="ksFilterClose">Chiudi</button>' +
      '</div>' +
      '<div class="ks-filter-panel-body" id="ksFilterBody"></div>' +
      '<div class="ks-filter-panel-footer">' +
      '  <a class="ks-filter-panel-btn ks-filter-panel-btn-link" id="ksFilterReset" href="#">Reset</a>' +
      '  <button type="button" class="ks-filter-panel-btn" id="ksFilterClose2">Chiudi</button>' +
      '  <button type="button" class="ks-filter-panel-btn ks-filter-panel-btn-primary" id="ksFilterApply">Applica</button>' +
      '</div>';
    document.body.appendChild(panel);

    var body = panel.querySelector('#ksFilterBody');

    // Placeholders for restoring original DOM positions
    var placeholders = [];
    for (var p = 0; p < filterEls.length; p++) {
      placeholders.push(document.createComment('ks-filter-placeholder'));
    }

    function open() {
      // move filters into offcanvas on mobile only
      if (window.matchMedia && window.matchMedia('(max-width: 991px)').matches) {
        for (var k = 0; k < filterEls.length; k++) {
          var el = filterEls[k];
          if (!el || el.parentNode === body) continue;
          // Insert placeholder where element was
          if (placeholders[k] && el.parentNode) {
            try { el.parentNode.insertBefore(placeholders[k], el); } catch (e) { }
          }
          body.appendChild(el);
        }
      }
      document.body.classList.add('ks-offcanvas-open');
    }

    function close() {
      document.body.classList.remove('ks-offcanvas-open');
      // restore filters back on desktop OR when closing
      for (var k = 0; k < filterEls.length; k++) {
        var el = filterEls[k];
        var ph = placeholders[k];
        if (!el || !ph || !ph.parentNode) continue;
        try {
          ph.parentNode.insertBefore(el, ph);
          ph.parentNode.removeChild(ph);
          // recreate placeholder for next open (we removed it)
          placeholders[k] = document.createComment('ks-filter-placeholder');
        } catch (e) { }
      }
    }

    function apply() {
      // In WebForms, many filter controls have AutoPostBack.
      // "Applica" just closes; eventual postback already happened.
      close();
    }

    // Reset goes to base catalog URL preserving category params
    try {
      var r = panel.querySelector('#ksFilterReset');
      if (r) r.href = buildResetUrl();
    } catch (e) { }

    // Persist handlers
    overlay.addEventListener('click', close);
    panel.querySelector('#ksFilterClose').addEventListener('click', close);
    panel.querySelector('#ksFilterClose2').addEventListener('click', close);
    panel.querySelector('#ksFilterApply').addEventListener('click', apply);

    // Expose for re-binding after UpdatePanel partial postback
    window.__ksFilterPanelOpen = open;
    window.__ksFilterPanelClose = close;

    // Bind triggers now (toolbar button or FAB)
    bindFilterTriggers();

    // Restore if switching to desktop while open
    window.addEventListener('resize', function () {
      if (!document.body.classList.contains('ks-offcanvas-open')) return;
      if (window.matchMedia && window.matchMedia('(min-width: 992px)').matches) {
        close();
      }
    });
  }

  // ==========================================================
  // Reset links already in markup (desktop sidebar)
  // ==========================================================
  function bindResetLinks() {
    var links = document.querySelectorAll('.js-ks-reset-filters');
    if (!links || links.length === 0) return;

    var url = buildResetUrl();
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (!a) continue;

      // ensure correct href (preserve ct/st/tp)
      try { a.setAttribute('href', url); } catch (e) { }

      if (a.dataset && a.dataset.ksResetBound === '1') continue;
      if (a.dataset) a.dataset.ksResetBound = '1';

      a.addEventListener('click', function (ev) {
        try { ev.preventDefault(); } catch (e) { }
        location.href = buildResetUrl();
      });
    }
  }

  function initCatalogUi() {
    if (!isCatalogPage()) return;

    ensureCss('/Public/assets/keepstore/css/catalog-filters-ui.css');

    // Reset link in sidebar (preserve ct/st/tp)
    bindResetLinks();

    // wrap & normalize known filter blocks (if present)
    wrapFilterBox(document.getElementById('filtersMr'), 'Marche');
    wrapFilterBox(document.getElementById('filtersTp'), 'Tipologie');
    wrapFilterBox(document.getElementById('filtersGr'), 'Gruppi');
    wrapFilterBox(document.getElementById('filtersSg'), 'Sottogruppi');

    // size/color block (if present)
    wrapFilterBox(document.getElementById('filtritagliaecolore'), 'Taglia & Colore');

    addSearchToFilter(document.getElementById('filtersMr'), 'Cerca marca…');

    normalizeToolbar();
    normalizePager();
    setupMobileOffcanvasFilters();
    renderActiveFilters();
  }

  function initAll() {
    initCatalogUi();
  }

  onReady(initAll);

  // Re-apply after UpdatePanel partial postback if present
  onReady(function () {
    try {
      if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
        var prm = Sys.WebForms.PageRequestManager.getInstance();
        if (prm && !window.__ksCatalogUiPrmHooked) {
          window.__ksCatalogUiPrmHooked = true;
          prm.add_endRequest(function () { initAll(); });
        }
      }
    } catch (e) { }
  });

})();