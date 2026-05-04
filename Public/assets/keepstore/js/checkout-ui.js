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

    // (opzionale) stato completato: se la pagina imposta una classe dedicata
    var isDone = document.body.classList.contains('ks-mode-order-done');

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

  function parseItMoney(text) {
    var value = (text || '').toString();
    var match = value.match(/\d{1,3}(?:\.\d{3})*(?:,\d{1,4})|\d+(?:,\d{1,4})|\d+(?:\.\d{1,4})/);
    if (!match) return 0;
    var raw = match[0].replace(/\s/g, '');
    if (raw.indexOf(',') >= 0) {
      raw = raw.replace(/\./g, '').replace(',', '.');
    }
    var n = parseFloat(raw);
    return isNaN(n) ? 0 : n;
  }

  function formatItMoney(value) {
    var n = parseFloat(value);
    if (isNaN(n)) n = 0;
    try {
      return n.toLocaleString('it-IT', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
    } catch (e) {
      return n.toFixed(2).replace('.', ',') + ' €';
    }
  }

  function restoreCartServerTotals() {
    qsa('.tf-table-page-cart .tf-cart-item').forEach(function (row) {
      var total = qs('.tf-cart-item_total .cart-total', row);
      if (total) {
        if (!total.dataset.ksServerText) total.dataset.ksServerText = (total.textContent || '').trim();
        if (/\$?NaN/i.test(total.textContent || '')) total.textContent = total.dataset.ksServerText || formatItMoney(0);
      }

      var price = qs('.tf-cart-item_price .cart-price', row);
      if (price) {
        if (!price.dataset.ksServerText) price.dataset.ksServerText = (price.textContent || '').trim();
        if (/\$?NaN/i.test(price.textContent || '')) price.textContent = price.dataset.ksServerText || formatItMoney(0);
      }
    });
  }

  function updateCartRowClientTotal(row) {
    if (!row) return;
    var qtyInput = qs('.quantity-product', row);
    var priceBox = qs('.tf-cart-item_price .cart-price', row);
    var totalBox = qs('.tf-cart-item_total .cart-total', row);
    if (!qtyInput || !priceBox || !totalBox) return;

    var qty = parseInt(qtyInput.value, 10);
    if (isNaN(qty) || qty < 1) qty = 1;
    var price = parseItMoney(priceBox.dataset.ksServerText || priceBox.textContent);
    totalBox.textContent = formatItMoney(price * qty);
  }

  function setupCartQuantityControls() {
    qsa('.tf-table-page-cart .ks-wg-quantity').forEach(function (wrap) {
      if (!wrap || wrap.dataset.ksQtyBound === '1') return;
      wrap.dataset.ksQtyBound = '1';

      var input = qs('.quantity-product', wrap);
      if (!input) return;

      function setQty(delta) {
        var current = parseInt(input.value, 10);
        if (isNaN(current) || current < 1) current = 1;
        var next = Math.max(1, current + delta);
        input.value = String(next);
        updateCartRowClientTotal(wrap.closest('.tf-cart-item'));
      }

      var minus = qs('.btn-decrease', wrap);
      var plus = qs('.btn-increase', wrap);

      if (minus) {
        minus.addEventListener('click', function (ev) {
          ev.preventDefault();
          ev.stopPropagation();
          ev.stopImmediatePropagation();
          setQty(-1);
        }, true);
      }

      if (plus) {
        plus.addEventListener('click', function (ev) {
          ev.preventDefault();
          ev.stopPropagation();
          ev.stopImmediatePropagation();
          setQty(1);
        }, true);
      }

      input.addEventListener('change', function () {
        var value = parseInt(input.value, 10);
        if (isNaN(value) || value < 1) value = 1;
        input.value = String(value);
        updateCartRowClientTotal(wrap.closest('.tf-cart-item'));
      });
    });
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
    cleanupLegacyEnhancedUx();
    decorateCheckoutTables();
    enhanceGridRowSelection();
    setupDestinationToggles();
    enhanceShippingAddressPicker();
    preventDoubleSubmit();
    restoreCartServerTotals();
    setupCartQuantityControls();
    window.setTimeout(restoreCartServerTotals, 120);
  }

  document.addEventListener('DOMContentLoaded', function () {
    boot();
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
