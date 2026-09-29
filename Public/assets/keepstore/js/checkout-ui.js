(function () {
  'use strict';

  // KeepStore UI - Checkout enhancements (stabili)
  // Obiettivo: migliorare UX senza alterare markup/ID/server logic.

  function qs(sel, root) { return (root || document).querySelector(sel); }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function isVisible(el) {
    if (!el) return false;
    if (el.offsetParent !== null) return true;
    // fallback: alcuni elementi possono essere position:fixed
    var cs = window.getComputedStyle(el);
    return cs && cs.display !== 'none' && cs.visibility !== 'hidden' && cs.opacity !== '0';
  }

  function triggerAutoPostBack(el) {
    if (!el) return;
    // In WebForms, AutoPostBack uses inline onchange -> el.onchange is usually a function.
    try {
      if (typeof el.onchange === 'function') {
        el.onchange();
        return;
      }
    } catch (e) { /* ignore */ }

    // Fallback: dispatch change event
    try {
      var evt = document.createEvent('HTMLEvents');
      evt.initEvent('change', true, false);
      el.dispatchEvent(evt);
    } catch (e2) {
      // ignore
    }
  }

  function setCheckoutStatus() {
    if (!document.body) return;

    // Determinazione “robusta” dello stato: in checkout se la tabella ordine (tOrdine) è visibile
    // oppure se il pulsante invio ordine è visibile.
    var tOrdine = document.getElementById('tOrdine') || qs('[id$="tOrdine"]');
    var btnInvia = qs('[id$="btInviaOrdine"]') || document.getElementById('btInviaOrdine');
    var inCheckout = (!!tOrdine && isVisible(tOrdine)) || (!!btnInvia && isVisible(btnInvia));

    // Stato finale/conferma: il markup carrello espone .ks-cart-step-confirm.
    var isDone = document.body.classList.contains('ks-mode-order-done') || !!qs('.ks-cart-step-confirm');

    document.body.classList.toggle('ks-mode-checkout', inCheckout);

    // Aggiorna progress bar / stepper (se presente)
    var items = qsa('.checkout-status-item');
    if (!items.length) return;

    // step: 0=carrello, 1=checkout, 2=done
    var step = 0;
    if (isDone) step = 2;
    else if (inCheckout) step = 1;

    // Reset
    items.forEach(function (el) {
      el.classList.remove('active');
      el.classList.remove('completed');
      el.removeAttribute('aria-current');
    });

    // Mark completed
    for (var i = 0; i < step; i++) {
      if (items[i]) items[i].classList.add('completed');
    }

    // Active current
    if (items[step]) {
      items[step].classList.add('active');
      items[step].setAttribute('aria-current', 'step');
    }

    // Expose state for CSS/hooks
    document.body.dataset.ksCheckoutStep = (step === 0 ? 'cart' : (step === 1 ? 'checkout' : 'done'));
  }

  var STEP_SCROLL_KEY = 'ksCartCheckoutStepScroll';

  function getCurrentCheckoutStep() {
    if (qs('.ks-cart-step-confirm')) return 'done';
    if (document.body && document.body.dataset && document.body.dataset.ksCheckoutStep) {
      return document.body.dataset.ksCheckoutStep;
    }
    if (document.body && document.body.classList.contains('ks-cart-step-confirm')) return 'done';
    if (document.body && document.body.classList.contains('ks-cart-step-checkout')) return 'checkout';
    var tOrdine = document.getElementById('tOrdine') || qs('[id$="tOrdine"]');
    return (tOrdine && isVisible(tOrdine)) ? 'checkout' : 'cart';
  }

  function findStepScrollTarget() {
    return qs('.ks-cart-page') || qs('.checkout-status') || qs('.ks-cart-title') || qs('.s-shoping-cart');
  }

  function getElementTop(el) {
    if (!el) return 0;
    var rect = el.getBoundingClientRect();
    var scrollTop = window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
    return Math.max(0, Math.floor(rect.top + scrollTop - 12));
  }

  function markStepScroll(targetStep) {
    try {
      if (!targetStep || !window.sessionStorage) return;
      var current = getCurrentCheckoutStep();
      window.sessionStorage.setItem(STEP_SCROLL_KEY, JSON.stringify({
        from: current,
        target: targetStep,
        ts: Date.now()
      }));
    } catch (e) {
      // storage non disponibile: nessun blocco UX
    }
  }

  function setupStepScrollTriggers() {
    if (document.documentElement.dataset.ksStepScrollBound === '1') return;
    document.documentElement.dataset.ksStepScrollBound = '1';

    document.addEventListener('click', function (ev) {
      var el = ev.target && ev.target.closest ? ev.target.closest('a,input,button') : null;
      if (!el || !el.id) return;

      if (/_?btCompleta$/.test(el.id)) {
        markStepScroll(getCurrentCheckoutStep() === 'cart' ? 'checkout' : 'cart');
      } else if (/_?btnVaiConfermaOrdine$/.test(el.id) || /_?lnkCheckoutStep3$/.test(el.id)) {
        markStepScroll('done');
      } else if (/_?btnModificaCheckout$/.test(el.id) || /_?lnkCheckoutStep2$/.test(el.id)) {
        markStepScroll('checkout');
      } else if (/_?lnkCheckoutStep1$/.test(el.id)) {
        markStepScroll('cart');
      }
    }, true);
  }

  function scrollTopAfterStepChange() {
    var raw = null;
    try {
      if (!window.sessionStorage) return;
      raw = window.sessionStorage.getItem(STEP_SCROLL_KEY);
      if (!raw) return;
      window.sessionStorage.removeItem(STEP_SCROLL_KEY);
    } catch (e) {
      return;
    }

    var pending = null;
    try { pending = JSON.parse(raw); } catch (e2) { return; }
    if (!pending || !pending.target || !pending.from) return;
    if (pending.ts && (Date.now() - pending.ts > 30000)) return;

    var current = getCurrentCheckoutStep();
    if (current === pending.from) return;
    if (pending.target !== current && !(pending.target === 'done' && current === 'checkout')) return;

    function applyScroll() {
      var target = findStepScrollTarget();
      var top = getElementTop(target);
      try {
        window.scrollTo({ top: top, behavior: 'auto' });
      } catch (e3) {
        window.scrollTo(0, top);
      }
    }

    applyScroll();
    window.setTimeout(applyScroll, 80);
    window.setTimeout(applyScroll, 240);
  }

  // Se in passato è stata abilitata una UX “accordion / chips”, la neutralizziamo.
  // Questo rende il comportamento più prevedibile (nessun pannello che si chiude da solo).
  function cleanupLegacyEnhancedUx() {
    // Rimuovi eventuale nav iniettata
    qsa('.ks-checkout-nav').forEach(function (el) {
      if (el && el.parentNode) el.parentNode.removeChild(el);
    });

    // Rimuovi eventuali icone accordion iniettate
    qsa('.ks-acc-icon').forEach(function (el) {
      if (el && el.parentNode) el.parentNode.removeChild(el);
    });

    // Rimuovi eventuali classi di collasso
    qsa('.ks-checkout .wrap.is-collapsed').forEach(function (el) {
      el.classList.remove('is-collapsed');
    });

    // Ripristina header (se era stato reso “button”)
    qsa('.ks-checkout .wrap > h5').forEach(function (h) {
      if (!h) return;
      if (h.dataset && h.dataset.ksAcc) delete h.dataset.ksAcc;
      h.removeAttribute('role');
      h.removeAttribute('tabindex');
    });
  }

  function decorateCheckoutTables() {
    // Aggancia classi ai GridView più importanti (renderizzano come <table>)
    // In questo modo non dipendiamo dal markup già “classato”.
    var ids = ['gvVettori', 'gvVettoriPromo', 'gvPagamento'];
    ids.forEach(function (id) {
      var tbl = document.getElementById(id) || qs('[id$="_' + id + '"]');
      if (tbl && tbl.tagName === 'TABLE') {
        tbl.classList.add('ks-checkout-grid');
      }
    });
  }

  function enhanceGridRowSelection() {
    // Rende l'intera riga cliccabile per selezionare il radio.
    // IMPORTANTE: non deve “intercettare” click su input/link, altrimenti rompe AutoPostBack.

    qsa('table.ks-checkout-grid').forEach(function (tbl) {
      qsa('tr', tbl).forEach(function (tr) {
        // salta header
        if (tr.querySelector('th')) return;

        // Se la riga ha già un onclick (GridView spesso genera __doPostBack),
        // evitare di aggiungere un secondo handler: potrebbe causare doppi postback.
        if (tr.getAttribute && tr.getAttribute('onclick')) return;
        if (typeof tr.onclick === 'function') return;

        // evita doppia bind
        if (tr.dataset && tr.dataset.ksRow === '1') return;
        tr.dataset.ksRow = '1';

        tr.addEventListener('click', function (ev) {
          var t = ev.target;
          if (!t) return;

          // non intercettare click su controlli interattivi
          if (t.closest('a,button,input,select,textarea,label')) return;

          var input = tr.querySelector('input[type="radio"], input[type="checkbox"]');
          if (input && !input.disabled) {
            // click reale -> se c'è AutoPostBack viene eseguito
            input.click();
          }
        });
      });
    });

    function refreshSelected() {
      qsa('table.ks-checkout-grid').forEach(function (tbl) {
        qsa('tr', tbl).forEach(function (tr) {
          tr.classList.remove('is-selected');
        });

        qsa('input[type="radio"]:checked', tbl).forEach(function (r) {
          var row = r.closest('tr');
          if (row) row.classList.add('is-selected');
        });
      });
    }

    // handler globale una sola volta
    if (!document.documentElement.dataset.ksCheckoutChangeBound) {
      document.documentElement.dataset.ksCheckoutChangeBound = '1';
      document.addEventListener('change', function (e) {
        if (!e || !e.target) return;
        if (e.target.matches('table.ks-checkout-grid input[type="radio"], table.ks-checkout-grid input[type="checkbox"]')) {
          refreshSelected();
        }
      });
    }

    refreshSelected();
  }

  // Indirizzi registrati (checkout) -> cards UI sopra la DropDownList
  function enhanceShippingAddressPicker() {
    return;
    // Cerca la DropDownList in carrello/checkout (AutoPostBack=True)
    var ddl = qs('select[id$="LstScegliIndirizzo"]') || document.getElementById('LstScegliIndirizzo');
    if (!ddl) return;

    // Evita duplicati
    if (ddl.dataset && ddl.dataset.ksAddrCards === '1') return;

    // Solo se visibile e se ha almeno 2 scelte significative
    if (!isVisible(ddl)) return;
    var options = ddl.querySelectorAll('option');
    if (!options || options.length < 2) return;

    // Non ricostruire se già presente
    var already = ddl.parentNode && ddl.parentNode.querySelector('.ks-addr-picker');
    if (already) {
      ddl.dataset.ksAddrCards = '1';
      return;
    }

    ddl.classList.add('ks-addr-select');

    function splitText(txt) {
      txt = (txt || '').replace(/\s+/g, ' ').trim();
      if (!txt) return { title: '', meta: '' };
      // separatori tipici: " - ", " | ", " / "
      var parts = txt.split(/\s*[-–|\/]\s*/);
      if (parts.length <= 1) return { title: txt, meta: '' };
      var title = (parts.shift() || '').trim();
      var meta = parts.join(' • ').trim();
      return { title: title || txt, meta: meta };
    }

    var wrap = document.createElement('div');
    wrap.className = 'ks-addr-picker';
    wrap.setAttribute('role', 'list');

    for (var i = 0; i < options.length; i++) {
      var opt = options[i];
      if (!opt || opt.disabled) continue;
      // spesso il primo option è placeholder ("-- seleziona --")
      var label = (opt.textContent || '').trim();
      if (!label) continue;

      // Skip placeholder vuoti (manteniamo la select nativa come fallback)
      if ((opt.value === '' || opt.value === null) && /seleziona/i.test(label)) continue;

      var parts = splitText(label);

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ks-addr-picker__btn';
      btn.setAttribute('role', 'listitem');
      btn.setAttribute('data-value', opt.value);
      if (opt.selected) btn.classList.add('is-active');

      btn.innerHTML =
        '<div class="ks-addr-picker__title">' + parts.title.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>' +
        (parts.meta ? '<div class="ks-addr-picker__meta">' + parts.meta.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>' : '');

      btn.addEventListener('click', function () {
        var val = this.getAttribute('data-value');
        if (!val || ddl.value === val) return;

        ddl.value = val;
        // Aggiorna UI locale subito (prima del postback)
        var all = wrap.querySelectorAll('.ks-addr-picker__btn');
        for (var k = 0; k < all.length; k++) all[k].classList.remove('is-active');
        this.classList.add('is-active');

        triggerAutoPostBack(ddl);
      });

      wrap.appendChild(btn);
    }

    // Inserisci subito dopo la select
    ddl.parentNode.insertBefore(wrap, ddl.nextSibling);

    // Sync in caso di change (es. user usa select nativa)
    if (!ddl.dataset.ksAddrChangeBound) {
      ddl.dataset.ksAddrChangeBound = '1';
      ddl.addEventListener('change', function () {
        var v = ddl.value;
        var btns = wrap.querySelectorAll('.ks-addr-picker__btn');
        for (var b = 0; b < btns.length; b++) {
          btns[b].classList.toggle('is-active', btns[b].getAttribute('data-value') === v);
        }
      });
    }

    ddl.dataset.ksAddrCards = '1';
  }

  // Replacement per vecchia logica jQuery con ID hardcodati (cph_*).
  function setupDestinationToggles() {
    var open1 = document.getElementById('open1') || qs('[id$="_open1"]');
    var open2 = document.getElementById('open2') || qs('[id$="_open2"]');
    var panel = document.getElementById('panel') || qs('[id$="_panel"]');
    if (!open1 || !open2 || !panel) return;

    // evita doppio bind
    if (open1.dataset && open1.dataset.ksToggle === '1') return;
    open1.dataset.ksToggle = '1';

    var insOmod = document.getElementById('insOmod') || qs('[id$="_insOmod"]');
    var btnMod = qs('[id$="_btnModDest"]');
    var btnElim = qs('[id$="_btnElimDest"]');
    var btnSalva = qs('[id$="_btnSalvaDest"]');

    function clearDestinationForm() {
      // pulizia “soft”: svuota i principali campi, ma NON distrugge la DropDownList
      // (evita UX strana se il postback non avviene immediatamente).
      var ids = ['tbRagioneSocialeA', 'tbNomeA', 'tbIndirizzo2', 'tbCap2', 'tbProvincia2', 'tbZona', 'tbTelefono2', 'tbNote'];
      ids.forEach(function (id) {
        var el = qs('[id$="_' + id + '"]') || document.getElementById(id);
        if (el) el.value = '';
      });

      var ddlCitta2 = qs('[id$="_ddlCitta2"]');
      if (ddlCitta2 && ddlCitta2.options && ddlCitta2.options.length) {
        ddlCitta2.selectedIndex = 0;
      }

      var chk = qs('[id$="_CHKPREDEFINITO"]');
      // Non forzare "predefinito". Evita prompt/modali indesiderati.
      if (chk) chk.checked = false;
    }

    function showPanel(mode) {
      panel.style.display = '';
      open1.style.display = 'none';
      open2.style.display = 'none';

      if (btnMod) btnMod.style.display = (mode === 'mod') ? '' : 'none';
      if (btnSalva) btnSalva.style.display = (mode === 'ins') ? '' : 'none';
      if (btnElim) btnElim.style.display = 'none'; // coerente con vecchio script

      if (insOmod) insOmod.value = (mode === 'mod') ? 'mod' : 'ins';

      // scroll: aiuta in mobile
      setTimeout(function () {
        try { panel.scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) { /* ignore */ }
      }, 50);
    }

    open1.addEventListener('click', function (e) {
      e.preventDefault();
      showPanel('mod');
    });

    open2.addEventListener('click', function (e) {
      e.preventDefault();
      clearDestinationForm();
      showPanel('ins');
    });
  }

  function preventDoubleSubmit() {
    var confirmLink = qs('[id$="btInviaOrdine"]');
    if (!confirmLink || confirmLink.dataset.ksOnce === '1') return;
    confirmLink.dataset.ksOnce = '1';

    var locked = false;

    confirmLink.addEventListener('click', function (e) {
      if (locked) {
        e.preventDefault();
        e.stopPropagation();
        return false;
      }

      // Blocca SOLO se parte davvero la UI di invio (spinner).
      // Se la validazione client impedisce il submit, lo spinner non appare e quindi non blocchiamo.
      setTimeout(function () {
        var sp = document.getElementById('spinner_caricamento');
        if (sp && isVisible(sp)) {
          locked = true;
          // fail-safe: sblocco automatico
          setTimeout(function () { locked = false; }, 12000);
        }
      }, 60);

      return true;
    }, true);
  }

  var cartQuantityEngine = null;

  function setupCartQuantityControls() {
    var page = qs('.ks-cart-page.ks-cart-step-cart');
    var config = document.getElementById('ksCartQuantityAsyncConfig');
    if (!page || !config || typeof window.fetch !== 'function' || typeof window.URLSearchParams !== 'function' || !window.crypto ||
        (typeof window.crypto.randomUUID !== 'function' && typeof window.crypto.getRandomValues !== 'function') ||
        !window.KeepStoreCartStateApi || typeof window.KeepStoreCartStateApi.applyAuthoritativeResponse !== 'function') return;
    if (cartQuantityEngine && cartQuantityEngine.page === page && cartQuantityEngine.firstRow.isConnected) return;

    var endpoint;
    try { endpoint = new window.URL(config.getAttribute('data-endpoint'), window.location.href); } catch (ignore) { return; }
    var csrf = config.getAttribute('data-csrf');
    var ivaTipo = config.getAttribute('data-iva-tipo');
    if (endpoint.origin !== window.location.origin || !csrf || !/^[12]$/.test(ivaTipo || '')) return;

    var rowNodes = qsa('.tf-table-page-cart .tf-cart-item[data-ks-cart-row-id]', page);
    var subtotal = qs('.ks-cart-subtotal-value', page);
    var headingCount = qs('.ks-cart-heading-count', page);
    var commercialNotice = document.getElementById('ksCartQuantityCommercialNotice');
    if (!rowNodes.length || !subtotal || !headingCount || !commercialNotice) return;

    var rows = [];
    var byId = {};
    function parseQuantity(value) {
      var text = String(value == null ? '' : value).trim();
      if (!/^[0-9]{1,4}$/.test(text)) return null;
      var number = Number(text);
      return number >= 1 && number <= 9999 ? number : null;
    }
    for (var i = 0; i < rowNodes.length; i += 1) {
      var node = rowNodes[i];
      var id = node.getAttribute('data-ks-cart-row-id');
      var wrap = qs('.ks-wg-quantity', node);
      var input = wrap && qs('.quantity-product', wrap);
      var minus = wrap && qs('.btn-decrease', wrap);
      var plus = wrap && qs('.btn-increase', wrap);
      var status = qs('[data-ks-cart-qty-status]', node);
      var hooks = ['price-net', 'price-gross', 'total-net', 'total-gross'];
      if (!/^[1-9]\d*$/.test(id || '') || byId[id] || !wrap || !input || input.disabled ||
          !minus || !plus || !status || !qs('[data-ks-free-shipping-badge]', node) ||
          hooks.some(function (hook) { return !qs('[data-ks-cart-' + hook + ']', node); })) return;
      var quantity = parseQuantity(input.value);
      if (quantity === null) return;
      var state = { id: id, node: node, input: input, minus: minus, plus: plus, status: status,
                    authoritative: quantity, desired: null, version: 0, rawDirty: false,
                    debounce: null, savedTimer: null };
      rows.push(state);
      byId[id] = state;
    }

    var inFlight = null;
    var fatal = false;
    var reloadStarted = false;
    var reloadKey = 'KeepStore:cart-quantity-failure:' + window.location.pathname;
    var scrollKey = 'KeepStore:cart-quantity-scroll:' + window.location.pathname;
    var checkoutTargets = qsa('[id$="_btCompleta"],[id$="_lnkCheckoutStep2"],[id$="_lnkCheckoutStep3"]', document);
    var waitMessage = qs('[data-ks-cart-checkout-wait]', page);
    var checkoutOriginal = checkoutTargets.map(function (target) {
      return { node: target, disabled: !!target.disabled, aria: target.getAttribute('aria-disabled') };
    });

    function hasPending() {
      return !!inFlight || rows.some(function (row) { return row.desired !== null || row.rawDirty; });
    }
    function protectCheckout() {
      var busy = hasPending() || fatal;
      checkoutOriginal.forEach(function (original) {
        if (original.node.tagName === 'INPUT' || original.node.tagName === 'BUTTON') {
          original.node.disabled = original.disabled || busy;
        } else {
          if (busy) original.node.setAttribute('aria-disabled', 'true');
          else if (original.aria === null) original.node.removeAttribute('aria-disabled');
          else original.node.setAttribute('aria-disabled', original.aria);
        }
        original.node.classList.toggle('ks-cart-checkout-guarded', busy);
      });
      if (waitMessage) waitMessage.hidden = !busy;
    }
    function setStatus(row, state, message) {
      if (row.savedTimer) { window.clearTimeout(row.savedTimer); row.savedTimer = null; }
      row.status.textContent = message || '';
      row.status.setAttribute('data-state', state);
      if (state === 'error') row.status.setAttribute('role', 'alert');
      else row.status.removeAttribute('role');
      row.node.setAttribute('aria-busy', state === 'saving' ? 'true' : 'false');
      if (state === 'saved') row.savedTimer = window.setTimeout(function () {
        if (row.desired === null && !row.rawDirty && (!inFlight || inFlight.row !== row)) setStatus(row, 'idle', '');
      }, 1500);
    }
    function updateMinus(row) {
      var shown = parseQuantity(row.input.value);
      row.minus.disabled = (shown === null ? row.authoritative : shown) <= 1;
    }
    function failClosed(row, message) {
      fatal = true;
      page.classList.remove('ks-cart-quantity-async-ready');
      if (row) setStatus(row, 'error', message || 'Aggiorna il carrello prima di proseguire.');
      protectCheckout();
    }
    function safeReload(row) {
      failClosed(row, 'Verifica il carrello prima di riprovare.');
      if (reloadStarted) return;
      reloadStarted = true;
      try {
        if (window.sessionStorage.getItem(reloadKey) === window.location.href) return;
        window.sessionStorage.setItem(reloadKey, window.location.href);
        window.sessionStorage.setItem(scrollKey, String(Math.max(0, Math.round(window.scrollY || 0))));
      } catch (ignore) {}
      window.location.reload();
    }
    function requestId() {
      if (typeof window.crypto.randomUUID === 'function') return window.crypto.randomUUID().replace(/-/g, '').toLowerCase();
      var bytes = new Uint8Array(16);
      window.crypto.getRandomValues(bytes);
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      var hex = Array.prototype.map.call(bytes, function (byte) { return ('0' + byte.toString(16)).slice(-2); }).join('');
      return hex;
    }
    function validateRows(data, target) {
      if (!data || data.ok !== true || data.requestId !== target.requestId ||
          Number(data.requestedQuantity) !== target.quantity || !data.cart ||
          typeof data.cart.subtotalNetText !== 'string' || !data.cart.subtotalNetText ||
          typeof data.cart.subtotalGrossText !== 'string' || !data.cart.subtotalGrossText ||
          typeof data.cart.count !== 'number' || !isFinite(data.cart.count) ||
          !Array.isArray(data.rows) ||
          data.rows.length !== rows.length) return false;
      var seen = {};
      var totalQuantity = 0;
      for (var j = 0; j < data.rows.length; j += 1) {
        var item = data.rows[j];
        var id = String(item && item.rowId);
        if (!byId[id] || seen[id] || parseQuantity(item.qty) === null ||
            typeof item.priceNetText !== 'string' || !item.priceNetText ||
            typeof item.priceGrossText !== 'string' || !item.priceGrossText ||
            typeof item.rowTotalNetText !== 'string' || !item.rowTotalNetText ||
            typeof item.rowTotalGrossText !== 'string' || !item.rowTotalGrossText ||
            typeof item.freeShipping !== 'boolean') return false;
        seen[id] = true;
        totalQuantity += Number(item.qty);
      }
      return totalQuantity === data.cart.count;
    }
    function applySnapshot(data, target) {
      if (!validateRows(data, target) || !window.KeepStoreCartStateApi.applyAuthoritativeResponse(data)) return false;
      var commercialVisualChange = false;
      data.rows.forEach(function (item) {
        var row = byId[String(item.rowId)];
        row.authoritative = Number(item.qty);
        [['price-net', item.priceNetText], ['price-gross', item.priceGrossText],
         ['total-net', item.rowTotalNetText], ['total-gross', item.rowTotalGrossText]].forEach(function (pair) {
          var display = qs('[data-ks-cart-' + pair[0] + ']', row.node);
          if (pair[0].indexOf('price-') === 0 && display.textContent.trim() !== pair[1].trim()) commercialVisualChange = true;
          display.textContent = pair[1];
        });
        var badge = qs('[data-ks-free-shipping-badge]', row.node);
        if (badge.hidden === item.freeShipping) commercialVisualChange = true;
        badge.hidden = !item.freeShipping;
        if (row.rawDirty) {
          if (row === target.row && row.version === target.version) row.desired = null;
        } else if (row.desired === null || (row === target.row && row.version === target.version)) {
          row.desired = null;
          row.input.value = String(row.authoritative);
        } else if (row.desired === row.authoritative) {
          row.desired = null;
          row.input.value = String(row.authoritative);
        }
        updateMinus(row);
      });
      subtotal.textContent = ivaTipo === '1' ? data.cart.subtotalNetText : data.cart.subtotalGrossText;
      headingCount.textContent = String(data.cart.count);
      if (data.commercialChanges === true || commercialVisualChange) commercialNotice.hidden = false;
      return true;
    }
    function send(target, retry) {
      var body = new window.URLSearchParams();
      body.set('csrfToken', csrf);
      body.set('rowId', target.row.id);
      body.set('quantity', String(target.quantity));
      body.set('requestId', target.requestId);
      window.fetch(endpoint.href, { method: 'POST', credentials: 'same-origin', cache: 'no-store',
        headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                   'X-Requested-With': 'XMLHttpRequest' }, body: body.toString() }).then(function (response) {
        return response.json().then(function (data) { return { response: response, data: data }; });
      }).then(function (result) {
        if (fatal || inFlight !== target) return;
        var response = result.response;
        var data = result.data;
        if (response.status === 503 && data && data.code === 'processing' && !retry && response.headers.get('Retry-After')) {
          var delay = Math.min(2000, Math.max(0, Number(response.headers.get('Retry-After')) * 1000 || 1000));
          window.setTimeout(function () { if (!fatal && inFlight === target) send(target, true); }, delay);
          return;
        }
        if (data && data.reconcile === true) { safeReload(target.row); return; }
        if (response.ok && applySnapshot(data, target)) {
          inFlight = null;
          var unresolved = target.row.desired !== null || target.row.rawDirty;
          setStatus(target.row, unresolved ? 'dirty' : 'saved', unresolved ? '' : 'Salvato');
          try { window.sessionStorage.removeItem(reloadKey); } catch (ignore) {}
          protectCheckout();
          pump();
          return;
        }
        if (response.status === 422 && data && (data.code === 'invalid_quantity' || data.code === 'commercial_unavailable')) {
          target.row.desired = null;
          target.row.rawDirty = false;
          target.row.input.value = String(target.row.authoritative);
          updateMinus(target.row);
          inFlight = null;
          setStatus(target.row, 'error', data.code === 'invalid_quantity' ? 'Inserisci una quantità da 1 a 9999. Per rimuovere usa Rimuovi.' :
                    'Condizioni non disponibili. Aggiorna il carrello prima di proseguire.');
          if (data.code === 'commercial_unavailable') failClosed(target.row, 'Condizioni non disponibili. Aggiorna il carrello prima di proseguire.');
          else { protectCheckout(); pump(); }
          return;
        }
        safeReload(target.row);
      }).catch(function () { if (!fatal && inFlight === target) safeReload(target.row); });
    }
    function pump() {
      if (fatal || inFlight) return;
      for (var j = 0; j < rows.length; j += 1) {
        var row = rows[j];
        if (row.desired === null || row.rawDirty) continue;
        if (row.desired === row.authoritative) {
          row.desired = null;
          setStatus(row, 'idle', '');
          continue;
        }
        inFlight = { row: row, quantity: row.desired, version: row.version, requestId: requestId() };
        setStatus(row, 'saving', 'Salvataggio…');
        protectCheckout();
        send(inFlight, false);
        return;
      }
      protectCheckout();
    }
    function desiredQuantity(row, quantity) {
      if (fatal) return;
      row.rawDirty = false;
      row.desired = quantity;
      row.version += 1;
      row.input.value = String(quantity);
      updateMinus(row);
      setStatus(row, 'dirty', '');
      protectCheckout();
      pump();
    }
    function flushManual(row) {
      if (row.debounce) { window.clearTimeout(row.debounce); row.debounce = null; }
      if (!row.rawDirty) return;
      var quantity = parseQuantity(row.input.value);
      if (quantity === null) {
        var invalidText = String(row.input.value).trim();
        row.rawDirty = false;
        row.input.value = String(row.desired === null ? row.authoritative : row.desired);
        updateMinus(row);
        setStatus(row, 'error', invalidText === '0' ?
                  'Per rimuovere l’articolo usa Rimuovi.' : 'Inserisci una quantità da 1 a 9999.');
        protectCheckout();
        return;
      }
      desiredQuantity(row, quantity);
    }

    rows.forEach(function (row) {
      row.minus.addEventListener('click', function (event) {
        event.preventDefault();
        if (row.minus.disabled) return;
        if (row.rawDirty && parseQuantity(row.input.value) === null) { flushManual(row); return; }
        if (row.debounce) { window.clearTimeout(row.debounce); row.debounce = null; }
        desiredQuantity(row, Math.max(1, (parseQuantity(row.input.value) || row.authoritative) - 1));
      });
      row.plus.addEventListener('click', function (event) {
        event.preventDefault();
        if (row.rawDirty && parseQuantity(row.input.value) === null) { flushManual(row); return; }
        if (row.debounce) { window.clearTimeout(row.debounce); row.debounce = null; }
        desiredQuantity(row, Math.min(9999, (parseQuantity(row.input.value) || row.authoritative) + 1));
      });
      row.input.addEventListener('focus', function () { row.input.select(); });
      row.input.addEventListener('input', function () {
        if (row.debounce) window.clearTimeout(row.debounce);
        row.rawDirty = true;
        updateMinus(row);
        setStatus(row, 'dirty', '');
        protectCheckout();
        row.debounce = window.setTimeout(function () { flushManual(row); }, 250);
      });
      row.input.addEventListener('keydown', function (event) {
        if (event.key === 'Enter') { event.preventDefault(); flushManual(row); }
      });
      updateMinus(row);
    });
    checkoutTargets.forEach(function (target) {
      target.addEventListener('click', function (event) {
        if (!hasPending() && !fatal) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        if (waitMessage) waitMessage.hidden = false;
      }, true);
    });
    try {
      var storedScroll = window.sessionStorage.getItem(scrollKey);
      if (storedScroll !== null) {
        window.sessionStorage.removeItem(scrollKey);
        var y = Number(storedScroll);
        if (isFinite(y) && y >= 0) window.requestAnimationFrame(function () { window.scrollTo(0, y); });
      }
    } catch (ignore) {}
    page.classList.add('ks-cart-quantity-async-ready');
    cartQuantityEngine = { page: page, firstRow: rowNodes[0] };
    protectCheckout();
  }

  function protectServerCartCommands() {
    qsa('.tf-table-page-cart .remove-cart a, .tf-table-page-cart a[id*="LB_Aggiorna"]').forEach(function (link) {
      if (!link || link.dataset.ksServerCommandBound === '1') return;
      link.dataset.ksServerCommandBound = '1';
      link.addEventListener('click', function (ev) {
        ev.stopImmediatePropagation();
        ev.stopPropagation();
      }, true);
    });
  }

  function placeCheckoutCouponPanel() {
    var panel = document.getElementById('Panel_BuoniSconto') || qs('[id$="Panel_BuoniSconto"]') || qs('.ks-cart-discount-panel');
    var slot = document.getElementById('CheckoutCouponSlot');
    if (!panel || !slot) return;
    if (!isVisible(slot)) return;
    if (panel.parentNode !== slot) {
      slot.appendChild(panel);
    }
  }

  function decorateCouponFeedback() {
    qsa('.ks-coupon-feedback').forEach(function (feedback) {
      var text = (feedback.textContent || '').replace(/\s+/g, ' ').trim();
      var ok = feedback.querySelector('img[id$="checkOKBuonoSconto"]');
      var ko = feedback.querySelector('img[id$="checkNOBuonoSconto"]');
      var okVisible = ok && isVisible(ok);
      var koVisible = ko && isVisible(ko);
      feedback.classList.toggle('has-message', !!text || okVisible || koVisible);
      feedback.classList.toggle('is-success', okVisible && !koVisible);
      feedback.classList.toggle('is-error', koVisible);
    });
  }

  function placeFinalConfirmActionsForMobile() {
    var actions = qs('.ks-final-confirm-section .ks-checkout-actions') || qs('#FinalCheckoutActionsMobileSlot .ks-checkout-actions');
    var inlineSlot = document.getElementById('FinalCheckoutActionsInlineSlot');
    var mobileSlot = document.getElementById('FinalCheckoutActionsMobileSlot');
    if (!actions || !inlineSlot || !mobileSlot) return;

    var isConfirm = !!qs('.ks-cart-step-confirm');
    var isMobile = false;
    try {
      isMobile = window.matchMedia && window.matchMedia('(max-width: 767.98px)').matches;
    } catch (e) {
      isMobile = window.innerWidth <= 768;
    }

    if (isConfirm && isMobile) {
      if (actions.parentNode !== mobileSlot) {
        mobileSlot.appendChild(actions);
      }
      mobileSlot.classList.add('has-actions');
      mobileSlot.removeAttribute('aria-hidden');
    } else {
      if (actions.parentNode !== inlineSlot) {
        inlineSlot.appendChild(actions);
      }
      mobileSlot.classList.remove('has-actions');
      mobileSlot.setAttribute('aria-hidden', 'true');
    }
  }

  // Funzione richiamata da OnClientClick nel markup: deve essere globale.
  window.visualizza_spinner_caricamento = function () {
    var sp = document.getElementById('spinner_caricamento');
    if (sp) sp.style.display = '';

    var invia = qs('[id$="btInviaOrdine"]');
    if (invia) invia.style.display = 'none';

    var prev = qs('[id$="_btSalvaPreventivo"]');
    if (prev) prev.style.display = 'none';
  };

  function boot() {
    setCheckoutStatus();
    setupStepScrollTriggers();
    scrollTopAfterStepChange();
    cleanupLegacyEnhancedUx();
    decorateCheckoutTables();
    enhanceGridRowSelection();
    setupDestinationToggles();
    enhanceShippingAddressPicker();
    preventDoubleSubmit();
    placeCheckoutCouponPanel();
    placeFinalConfirmActionsForMobile();
    decorateCouponFeedback();
    setupCartQuantityControls();
    protectServerCartCommands();
  }

  document.addEventListener('DOMContentLoaded', function () {
    boot();
  });

  window.addEventListener('resize', function () {
    placeFinalConfirmActionsForMobile();
  });

  // Se la pagina usa UpdatePanel, riapplica su endRequest
  if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
    try {
      Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
        boot();
      });
    } catch (e) { /* ignore */ }
  }
})();
