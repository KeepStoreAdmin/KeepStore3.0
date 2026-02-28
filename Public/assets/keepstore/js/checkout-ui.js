(function () {
  'use strict';

  function qs(sel, root) { return (root || document).querySelector(sel); }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function isVisible(el) {
    if (!el) return false;
    if (el.offsetParent !== null) return true;
    // fallback: some elements may be position:fixed
    var cs = window.getComputedStyle(el);
    return cs && cs.display !== 'none' && cs.visibility !== 'hidden' && cs.opacity !== '0';
  }

  function getCheckoutTable() {
    return document.getElementById('tOrdine') || qs('[id$="_tOrdine"]');
  }

  function setCheckoutStatus() {
    var tbl = getCheckoutTable();
    var inCheckout = !!tbl && isVisible(tbl);

    if (!document.body) return;
    document.body.classList.toggle('ks-mode-checkout', inCheckout);

    var items = qsa('.checkout-status-item');
    if (!items.length) return;

    // Stato: 0=carrello, 1=checkout
    if (inCheckout) {
      if (items[0]) items[0].classList.remove('active');
      if (items[1]) items[1].classList.add('active');
      if (items[2]) items[2].classList.remove('active');
    } else {
      if (items[0]) items[0].classList.add('active');
      if (items[1]) items[1].classList.remove('active');
      if (items[2]) items[2].classList.remove('active');
    }
  }

  function panelKey(panel) {
    // usa il ClientID come chiave stabile nella singola request
    return (panel && panel.id) ? panel.id : '';
  }

  function getPanelTitle(panel) {
    var h = panel ? panel.querySelector('h5') : null;
    if (!h) return '';
    // rimuove eventuale icona accordion già appesa
    var txt = h.textContent || '';
    return txt.replace(/[▾▸]/g, '').trim();
  }

  function sectionIsDone(panel) {
    if (!panel) return false;
    // euristica “light”: se esiste un input selezionato, consideriamo la sezione completata
    var checked = panel.querySelector('input[type="radio"]:checked, input[type="checkbox"]:checked');
    if (checked) return true;

    // per sezioni form: se c'è almeno un campo valorizzato
    var tb = panel.querySelector('input[type="text"], input[type="email"], textarea');
    if (tb && tb.value && String(tb.value).trim().length > 0) return true;

    return false;
  }

  function ensureAccordion() {
    var panels = qsa('.ks-checkout .wrap');
    if (!panels.length) return;

    var lastOpenKey = null;
    try { lastOpenKey = sessionStorage.getItem('ksCheckoutOpen'); } catch (e) { /* ignore */ }

    // init handlers
    panels.forEach(function (panel) {
      var h = panel.querySelector('h5');
      if (!h || h.dataset.ksAcc === '1') return;
      h.dataset.ksAcc = '1';

      if (!h.querySelector('.ks-acc-icon')) {
        var icon = document.createElement('span');
        icon.className = 'ks-acc-icon';
        icon.setAttribute('aria-hidden', 'true');
        icon.textContent = '▾';
        h.appendChild(icon);
      }

      h.setAttribute('role', 'button');
      h.setAttribute('tabindex', '0');

      function setIcon() {
        var ic = h.querySelector('.ks-acc-icon');
        if (!ic) return;
        ic.textContent = panel.classList.contains('is-collapsed') ? '▸' : '▾';
      }

      function collapseOthers() {
        if (!document.body.classList.contains('ks-mode-checkout')) return;
        panels.forEach(function (p2) {
          if (p2 !== panel) p2.classList.add('is-collapsed');
        });
      }

      function openPanel() {
        panel.classList.remove('is-collapsed');
        collapseOthers();
        setIcon();

        var k = panelKey(panel);
        if (k) {
          try { sessionStorage.setItem('ksCheckoutOpen', k); } catch (e) { /* ignore */ }
        }
      }

      function toggle() {
        var isCollapsed = panel.classList.contains('is-collapsed');
        if (isCollapsed) openPanel();
        else {
          panel.classList.add('is-collapsed');
          setIcon();
        }
        refreshCheckoutNav();
      }

      h.addEventListener('click', function () { toggle(); });
      h.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggle();
        }
      });

      // expose helper for nav click
      panel.__ksOpen = openPanel;

      setIcon();
    });

    // initial open: prefer lastOpenKey
    var opened = false;
    if (lastOpenKey) {
      panels.forEach(function (p) {
        if (panelKey(p) === lastOpenKey && typeof p.__ksOpen === 'function') {
          p.__ksOpen();
          opened = true;
        }
      });
    }
    if (!opened && panels[0] && typeof panels[0].__ksOpen === 'function') {
      panels[0].__ksOpen();
    }
  }

  function enhanceGridRowSelection() {
    qsa('table.ks-checkout-grid').forEach(function (tbl) {
      qsa('tr', tbl).forEach(function (tr) {
        // salta header
        if (tr.querySelector('th')) return;

        tr.addEventListener('click', function (ev) {
          var t = ev.target;
          if (!t) return;

          // non intercettare click su controlli interattivi
          if (t.tagName === 'INPUT' || t.tagName === 'A' || t.closest('a') || t.closest('button') || t.closest('input')) {
            return;
          }

          var radio = tr.querySelector('input[type="radio"]');
          if (radio && !radio.disabled) {
            radio.click(); // AutoPostBack -> postback
          }
        });
      });
    });

    function refreshSelected() {
      qsa('table.ks-checkout-grid').forEach(function (tbl) {
        qsa('tr', tbl).forEach(function (tr) { tr.classList.remove('is-selected'); });

        qsa('input[type="radio"]:checked', tbl).forEach(function (r) {
          var row = r.closest('tr');
          if (row) row.classList.add('is-selected');
        });
      });
    }

    document.addEventListener('change', function (e) {
      if (e.target && e.target.matches('input[type="radio"]')) {
        refreshSelected();
        refreshCheckoutNav();
      }
      if (e.target && e.target.matches('input[type="checkbox"], input[type="text"], textarea')) {
        refreshCheckoutNav();
      }
    });

    refreshSelected();
  }

  // Replacement per vecchia logica jQuery con ID hardcodati (cph_*).
  function setupDestinationToggles() {
    var open1 = document.getElementById('open1') || qs('[id$="_open1"]');
    var open2 = document.getElementById('open2') || qs('[id$="_open2"]');
    var panel = document.getElementById('panel') || qs('[id$="_panel"]');
    if (!open1 || !open2 || !panel) return;

    var insOmod = document.getElementById('insOmod') || qs('[id$="_insOmod"]');
    var btnMod = qs('[id$="_btnModDest"]');
    var btnElim = qs('[id$="_btnElimDest"]');
    var btnSalva = qs('[id$="_btnSalvaDest"]');

    var confirmLink = qs('[id$="_btInviaOrdine"]');
    var confirmBox = document.getElementById('confermaOrdinde');

    function disableConfirm() {
      if (confirmLink) {
        confirmLink.style.pointerEvents = 'none';
        confirmLink.style.opacity = '0.6';
      }
      if (confirmBox) {
        confirmBox.style.pointerEvents = 'none';
        confirmBox.style.opacity = '0.6';
      }
    }

    function clearDestinationForm() {
      var ids = ['tbRagioneSocialeA', 'tbNomeA', 'tbIndirizzo2', 'tbCap2', 'tbProvincia2', 'tbZona', 'tbTelefono2', 'tbNote'];
      ids.forEach(function (id) {
        var el = qs('[id$="_' + id + '"]') || document.getElementById(id);
        if (el) el.value = '';
      });

      var ddlCitta2 = qs('[id$="_ddlCitta2"]');
      if (ddlCitta2 && ddlCitta2.options) {
        while (ddlCitta2.options.length > 0) ddlCitta2.remove(0);
      }

      var chk = qs('[id$="_CHKPREDEFINITO"]');
      if (chk) chk.checked = true;
    }

    function showPanel(mode) {
      panel.style.display = '';
      open1.style.display = 'none';
      open2.style.display = 'none';

      if (btnMod) btnMod.style.display = (mode === 'mod') ? '' : 'none';
      if (btnSalva) btnSalva.style.display = (mode === 'ins') ? '' : 'none';
      if (btnElim) btnElim.style.display = 'none';

      if (insOmod) insOmod.value = (mode === 'mod') ? 'mod' : 'ins';

      disableConfirm();

      // Se la sezione che contiene il form è in accordion collassato, aprila e scrolla.
      var wrap = panel.closest('.wrap');
      if (wrap && typeof wrap.__ksOpen === 'function') wrap.__ksOpen();
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
    var confirmLink = qs('[id$="_btInviaOrdine"]');
    if (!confirmLink || confirmLink.dataset.ksOnce === '1') return;
    confirmLink.dataset.ksOnce = '1';

    var submitted = false;
    confirmLink.addEventListener('click', function (e) {
      if (submitted) {
        e.preventDefault();
        e.stopPropagation();
        return false;
      }
      submitted = true;
      // OnClientClick già gestisce spinner; qui impediamo doppio click
      setTimeout(function(){ submitted = false; }, 6000);
      return true;
    }, true);
  }

  // Navigazione step (creata dinamicamente)
  function buildCheckoutNav() {
    // solo se siamo davvero in checkout
    if (!document.body.classList.contains('ks-mode-checkout')) return;

    var tbl = getCheckoutTable();
    if (!tbl) return;

    // evita duplicati
    if (qs('.ks-checkout-nav')) return;

    var panels = qsa('.ks-checkout .wrap');
    if (!panels.length) return;

    var host = qs('.checkout-status');
    if (!host) return;

    var nav = document.createElement('div');
    nav.className = 'ks-checkout-nav';
    nav.setAttribute('role', 'navigation');
    nav.setAttribute('aria-label', 'Navigazione checkout');

    panels.forEach(function (panel, idx) {
      var title = getPanelTitle(panel);
      if (!title) return;

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ks-checkout-nav__btn';
      btn.dataset.target = panelKey(panel) || String(idx);

      var dot = document.createElement('span');
      dot.className = 'ks-checkout-nav__dot';
      dot.setAttribute('aria-hidden', 'true');

      var lbl = document.createElement('span');
      lbl.textContent = title;

      btn.appendChild(dot);
      btn.appendChild(lbl);

      btn.addEventListener('click', function () {
        if (typeof panel.__ksOpen === 'function') panel.__ksOpen();
        setTimeout(function () {
          try { panel.scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) { /* ignore */ }
          refreshCheckoutNav();
        }, 10);
      });

      nav.appendChild(btn);
    });

    // inserisci dopo lo status
    host.parentNode.insertBefore(nav, host.nextSibling);

    refreshCheckoutNav();
  }

  function refreshCheckoutNav() {
    var nav = qs('.ks-checkout-nav');
    if (!nav) return;

    var panels = qsa('.ks-checkout .wrap');
    var buttons = qsa('.ks-checkout-nav__btn', nav);

    buttons.forEach(function (btn, idx) {
      btn.classList.remove('is-active');
      btn.classList.remove('is-done');

      var panel = panels[idx];
      if (!panel) return;

      if (!panel.classList.contains('is-collapsed')) btn.classList.add('is-active');
      if (sectionIsDone(panel)) btn.classList.add('is-done');
    });
  }

  // Funzione richiamata da OnClientClick nel markup: deve essere globale.
  window.visualizza_spinner_caricamento = function () {
    var sp = document.getElementById('spinner_caricamento');
    if (sp) sp.style.display = '';

    var invia = qs('[id$="_btInviaOrdine"]');
    if (invia) invia.style.display = 'none';

    var prev = qs('[id$="_btSalvaPreventivo"]');
    if (prev) prev.style.display = 'none';
  };

  function boot() {
    setCheckoutStatus();
    ensureAccordion();
    enhanceGridRowSelection();
    setupDestinationToggles();
    preventDoubleSubmit();
    buildCheckoutNav();
  }

  document.addEventListener('DOMContentLoaded', function () {
    boot();
  });

  // se la pagina usa UpdatePanel, riapplica su endRequest
  if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
    try {
      Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
        // re-init in modo idempotente
        boot();
      });
    } catch (e) { /* ignore */ }
  }
})();