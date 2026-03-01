(function () {
  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function isCatalogPage() {
    return /articoli\.aspx$/i.test(location.pathname || '');
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
  function setupMobileOffcanvasFilters() {
    if (!isCatalogPage()) return;

    var filterEls = [];
    var ids = ['filtersMr', 'filtersTp', 'filtersGr', 'filtersSg', 'filtritagliaecolore'];
    for (var i = 0; i < ids.length; i++) {
      var el = document.getElementById(ids[i]);
      if (el) filterEls.push(el);
    }
    if (filterEls.length === 0) return;

    // Create DOM once
    if (document.getElementById('ksFilterPanel')) return;

    // Floating button
    var fab = document.createElement('button');
    fab.type = 'button';
    fab.className = 'ks-filter-fab';
    fab.id = 'ksFiltersFab';
    fab.innerHTML = '<span aria-hidden="true">☰</span><span>Filtri</span>';
    document.body.appendChild(fab);

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

    fab.addEventListener('click', open);
    overlay.addEventListener('click', close);
    panel.querySelector('#ksFilterClose').addEventListener('click', close);
    panel.querySelector('#ksFilterClose2').addEventListener('click', close);
    panel.querySelector('#ksFilterApply').addEventListener('click', apply);

    // Restore if switching to desktop
    window.addEventListener('resize', function () {
      if (!document.body.classList.contains('ks-offcanvas-open')) return;
      if (window.matchMedia && window.matchMedia('(min-width: 992px)').matches) {
        close();
      }
    });
  }

  function initCatalogUi() {
    if (!isCatalogPage()) return;

    ensureCss('/Public/assets/keepstore/css/catalog-filters-ui.css');

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