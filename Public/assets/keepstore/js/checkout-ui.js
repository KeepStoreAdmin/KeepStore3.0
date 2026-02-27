(function () {
  'use strict';

  function qs(sel, root) { return (root || document).querySelector(sel); }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function ensureAccordion() {
    qsa('.ks-checkout .wrap').forEach(function (panel) {
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

      function toggle() {
        panel.classList.toggle('is-collapsed');
        setIcon();
      }

      h.addEventListener('click', function () { toggle(); });
      h.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggle();
        }
      });

      setIcon();
    });
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
        // pulizia hard, poi verrà ripopolata via postback quando necessario
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
      if (btnElim) btnElim.style.display = 'none'; // coerente con vecchio script

      if (insOmod) insOmod.value = (mode === 'mod') ? 'mod' : 'ins';

      disableConfirm();
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

  // Funzione richiamata da OnClientClick nel markup: deve essere globale.
  window.visualizza_spinner_caricamento = function () {
    var sp = document.getElementById('spinner_caricamento');
    if (sp) sp.style.display = '';

    var invia = qs('[id$="_btInviaOrdine"]');
    if (invia) invia.style.display = 'none';

    var prev = qs('[id$="_btSalvaPreventivo"]');
    if (prev) prev.style.display = 'none';
  };

  document.addEventListener('DOMContentLoaded', function () {
    ensureAccordion();
    enhanceGridRowSelection();
    setupDestinationToggles();
  });
})();