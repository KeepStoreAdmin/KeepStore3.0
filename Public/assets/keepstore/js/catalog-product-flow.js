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

  function initializeCatalogSort() {
    var root = document.getElementById('ksCatalogPage');
    if (!root) return;

    var control = root.querySelector('.ks-sort-control');
    if (!control || control.getAttribute('data-ks-sort-ready') === '1') return;

    var nativeSelect = control.querySelector('select.ks-toolbar-native-select');
    var dropdown = control.querySelector('[data-ks-sort-dropdown]');
    var trigger = control.querySelector('.ks-sort-trigger');
    var triggerIcon = control.querySelector('.ks-sort-trigger-icon');
    var triggerValue = control.querySelector('.ks-sort-trigger-value');
    var menu = control.querySelector('.ks-sort-menu');
    var options = control.querySelectorAll('.ks-sort-option');
    if (!nativeSelect || !dropdown || !trigger || !triggerIcon || !triggerValue || !menu || !options.length) return;

    var nativeValues = [];
    for (var nativeIndex = 0; nativeIndex < nativeSelect.options.length; nativeIndex++) {
      nativeValues.push(nativeSelect.options[nativeIndex].value);
    }
    for (var optionIndex = 0; optionIndex < options.length; optionIndex++) {
      if (nativeValues.indexOf(options[optionIndex].getAttribute('data-ks-sort-value')) === -1) return;
    }
    if (typeof nativeSelect.onchange !== 'function' && typeof window.__doPostBack !== 'function' && !nativeSelect.form) return;

    function selectedVisualOption() {
      for (var i = 0; i < options.length; i++) {
        if (options[i].getAttribute('data-ks-sort-value') === nativeSelect.value) return options[i];
      }
      return options[0];
    }

    function syncVisualState() {
      var selected = selectedVisualOption();
      var text = selected ? String(selected.textContent || '').replace(/\s+/g, ' ').trim() : 'Consigliati';
      var icon = selected ? selected.getAttribute('data-ks-sort-icon') : 'icon-sort';

      triggerIcon.className = 'ks-sort-trigger-icon ' + (icon || 'icon-sort');
      triggerValue.textContent = text;
      trigger.setAttribute('aria-label', 'Ordina prodotti. Selezione attuale: ' + text);

      for (var i = 0; i < options.length; i++) {
        var active = options[i] === selected;
        options[i].classList.toggle('is-selected', active);
        options[i].setAttribute('aria-selected', active ? 'true' : 'false');
      }
    }

    function closeMenu(returnFocus) {
      dropdown.classList.remove('is-open');
      trigger.setAttribute('aria-expanded', 'false');
      if (returnFocus) trigger.focus();
    }

    function openMenu(focusSelected) {
      dropdown.classList.add('is-open');
      trigger.setAttribute('aria-expanded', 'true');
      if (focusSelected) selectedVisualOption().focus();
    }

    function focusOption(current, offset) {
      var index = Array.prototype.indexOf.call(options, current);
      if (index < 0) index = 0;
      index = (index + offset + options.length) % options.length;
      options[index].focus();
    }

    function requestNativeSortPostback() {
      var nativeChangeHandler = nativeSelect.onchange;
      nativeSelect.dispatchEvent(new Event('change', { bubbles: true }));

      if (typeof nativeChangeHandler === 'function') return;

      if (typeof window.__doPostBack === 'function') {
        window.__doPostBack(nativeSelect.name, '');
        return;
      }

      var form = nativeSelect.form;
      if (!form) return;

      var eventTarget = form.elements.namedItem('__EVENTTARGET');
      if (!eventTarget) {
        eventTarget = document.createElement('input');
        eventTarget.type = 'hidden';
        eventTarget.name = '__EVENTTARGET';
        form.appendChild(eventTarget);
      }
      eventTarget.value = nativeSelect.name;

      var eventArgument = form.elements.namedItem('__EVENTARGUMENT');
      if (!eventArgument) {
        eventArgument = document.createElement('input');
        eventArgument.type = 'hidden';
        eventArgument.name = '__EVENTARGUMENT';
        form.appendChild(eventArgument);
      }
      eventArgument.value = '';

      window.HTMLFormElement.prototype.submit.call(form);
    }

    trigger.addEventListener('click', function () {
      if (dropdown.classList.contains('is-open')) closeMenu(false);
      else openMenu(false);
    });

    trigger.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        openMenu(true);
      } else if (event.key === 'Escape') {
        closeMenu(false);
      }
    });

    menu.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeMenu(true);
      } else if (event.key === 'ArrowDown') {
        event.preventDefault();
        focusOption(document.activeElement, 1);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        focusOption(document.activeElement, -1);
      } else if (event.key === 'Home') {
        event.preventDefault();
        options[0].focus();
      } else if (event.key === 'End') {
        event.preventDefault();
        options[options.length - 1].focus();
      }
    });

    for (var i = 0; i < options.length; i++) {
      options[i].addEventListener('click', function () {
        var value = this.getAttribute('data-ks-sort-value');
        if (nativeSelect.value === value) {
          closeMenu(true);
          return;
        }

        nativeSelect.value = value;
        syncVisualState();
        closeMenu(false);
        requestNativeSortPostback();
      });
    }

    document.addEventListener('click', function (event) {
      if (!control.contains(event.target)) closeMenu(false);
    });

    nativeSelect.addEventListener('change', syncVisualState);
    syncVisualState();

    nativeSelect.setAttribute('tabindex', '-1');
    nativeSelect.setAttribute('aria-hidden', 'true');
    control.setAttribute('data-ks-sort-ready', '1');
    control.classList.add('ks-sort-enhanced-ready');
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
            initializeCatalogSort();
          });
        }
      }
    } catch (e) {}
  }

  onReady(function () {
    ensureQtyEnhancement(document);
    initializeCatalogLayout();
    initializeCatalogSort();
    wireUpdatePanel();
  });
})();
