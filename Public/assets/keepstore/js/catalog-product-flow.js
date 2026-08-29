(function () {
  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function toInt(v, def) {
    var n = parseInt(v, 10);
    return isNaN(n) ? def : n;
  }

  function normalizeQty(input) {
    var v = toInt(input.value, 1);
    if (v < 1) v = 1;
    if (v > 9999) v = 9999;
    input.value = String(v);
    return v;
  }

  function enhanceQtyInput(input) {
    if (!input || input.getAttribute('data-ks-qty') === '1') return;

    input.setAttribute('data-ks-qty', '1');
    input.setAttribute('inputmode', 'numeric');
    input.setAttribute('pattern', '[0-9]*');

    // Avoid double-wrapping
    if (input.parentElement && input.parentElement.classList.contains('ks-qty-wrap')) return;

    var wrap = document.createElement('div');
    wrap.className = 'ks-qty-wrap';

    var btnMinus = document.createElement('button');
    btnMinus.type = 'button';
    btnMinus.className = 'ks-qty-btn ks-qty-minus';
    btnMinus.setAttribute('aria-label', 'Diminuisci quantita');
    btnMinus.innerHTML = '&minus;';

    var btnPlus = document.createElement('button');
    btnPlus.type = 'button';
    btnPlus.className = 'ks-qty-btn ks-qty-plus';
    btnPlus.setAttribute('aria-label', 'Aumenta quantita');
    btnPlus.innerHTML = '+';

    // Insert wrapper at input position
    var parent = input.parentNode;
    var next = input.nextSibling;
    parent.insertBefore(wrap, next);

    // Move input into wrapper
    wrap.appendChild(btnMinus);
    wrap.appendChild(input);
    wrap.appendChild(btnPlus);

    normalizeQty(input);

    function setQty(delta) {
      input.value = String(normalizeQty(input) + delta);
      normalizeQty(input);

      // Trigger change/input (some pages might read it client-side)
      try { input.dispatchEvent(new Event('input', { bubbles: true })); } catch (e) {}
      try { input.dispatchEvent(new Event('change', { bubbles: true })); } catch (e) {}
    }

    btnMinus.addEventListener('click', function (ev) {
      ev.preventDefault();
      setQty(-1);
    });

    btnPlus.addEventListener('click', function (ev) {
      ev.preventDefault();
      setQty(1);
    });

    input.addEventListener('blur', function () {
      normalizeQty(input);
    });
  }

  function ensureQtyEnhancement(scope) {
    scope = scope || document;

    var inputs = scope.querySelectorAll('input.ks-qty');
    for (var i = 0; i < inputs.length; i++) {
      enhanceQtyInput(inputs[i]);
    }
  }

  var catalogLayoutStorageKey = 'KeepStore:CatalogLayout';
  var catalogLayouts = ['tabgrid-1', 'tabgrid-2', 'tablist-1', 'tablist-2'];
  var gridLayoutClasses = ['layout-tabgrid-1', 'layout-tabgrid-2', 'layout-tablist-1', 'layout-tablist-2'];
  var cardPresentationClasses = ['style-row', 'type-row-2', 'row-small', 'flex-sm-row'];

  function isCatalogLayout(value) {
    return catalogLayouts.indexOf(value) !== -1;
  }

  function readCatalogLayout() {
    try {
      var stored = window.sessionStorage.getItem(catalogLayoutStorageKey);
      if (isCatalogLayout(stored)) return stored;
    } catch (e) {}
    return 'tabgrid-1';
  }

  function storeCatalogLayout(layout) {
    try { window.sessionStorage.setItem(catalogLayoutStorageKey, layout); } catch (e) {}
  }

  function applyCatalogLayout(root, layout, persist) {
    if (!root || !isCatalogLayout(layout)) layout = 'tabgrid-1';

    var grid = root.querySelector('#gridLayout');
    if (!grid) return;

    for (var i = 0; i < gridLayoutClasses.length; i++) {
      grid.classList.remove(gridLayoutClasses[i]);
    }
    grid.classList.add('layout-' + layout);

    var cards = grid.querySelectorAll('article.card-product');
    for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      var card = cards[cardIndex];
      for (var classIndex = 0; classIndex < cardPresentationClasses.length; classIndex++) {
        card.classList.remove(cardPresentationClasses[classIndex]);
      }

      if (layout === 'tablist-1') {
        card.classList.add('style-row');
      } else if (layout === 'tablist-2') {
        card.classList.add('style-row', 'type-row-2', 'row-small', 'flex-sm-row');
      }
    }

    var switches = root.querySelectorAll('.ks-view-layout-switch');
    for (var switchIndex = 0; switchIndex < switches.length; switchIndex++) {
      var current = switches[switchIndex];
      var active = current.getAttribute('data-ks-layout') === layout;
      current.classList.toggle('active', active);
      current.setAttribute('aria-pressed', active ? 'true' : 'false');
      current.setAttribute('aria-selected', active ? 'true' : 'false');
    }

    if (persist) storeCatalogLayout(layout);
  }

  function initializeCatalogLayout() {
    var root = document.getElementById('ksCatalogPage');
    if (!root) return;

    var switches = root.querySelectorAll('.ks-view-layout-switch');
    for (var i = 0; i < switches.length; i++) {
      if (switches[i].getAttribute('data-ks-layout-ready') === '1') continue;
      switches[i].setAttribute('data-ks-layout-ready', '1');
      switches[i].addEventListener('click', function (event) {
        event.preventDefault();
        applyCatalogLayout(root, this.getAttribute('data-ks-layout'), true);
      });
    }

    applyCatalogLayout(root, readCatalogLayout(), false);
  }

  // Re-run after UpdatePanel async postback (WebForms)
  function wireUpdatePanel() {
    try {
      if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
        var prm = Sys.WebForms.PageRequestManager.getInstance();
        if (prm) {
          prm.add_endRequest(function () {
            ensureQtyEnhancement(document);
            initializeCatalogLayout();
          });
        }
      }
    } catch (e) {}
  }

  onReady(function () {
    ensureQtyEnhancement(document);
    initializeCatalogLayout();
    wireUpdatePanel();
  });
})();
