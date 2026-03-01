/* KeepStore 3.0 — Dati utente UI (Step 19)
   - Gestione tab Dettagli/Indirizzi via querystring ?tab=addr
   - Evidenzia tab attivo
   - Nessuna logica VB/DB */

(function () {
  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  ready(function () {
    // Esegui solo sulla pagina datiutente
    if (!document.body.classList.contains('ks-page-datiutente')) return;

    var root = document.querySelector('.js-ks-userdata');
    if (!root) return;


    function isVisible(el) {
      if (!el) return false;
      return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
    }

    // Costruisce un picker “a schede” a partire dalla DropDownList delle destinazioni
    function buildDestinationPicker() {
      var activeFv = root.querySelector('.js-ks-userdata-fv.is-active') || root.querySelector('.js-ks-userdata-fv') || root;
      if (!activeFv) return;

      // Solo se siamo in tab indirizzi e la sezione edit è presente/visibile
      var paneAddr = activeFv.querySelector('.ks-userdata-pane-addresses');
      if (!paneAddr) return;

      var edit = paneAddr.querySelector('#addrEdit') || paneAddr.querySelector('[id$="addrEdit"]');
      if (!edit || !isVisible(edit)) return;

      var ddl = paneAddr.querySelector('select[id$="ddlDestinazione"]');
      if (!ddl) return;
      if (ddl.dataset && ddl.dataset.ksPickerBuilt === '1') return;

      // Evita duplicati
      var existing = paneAddr.querySelector('.ks-dest-picker');
      if (existing) {
        ddl.dataset.ksPickerBuilt = '1';
        return;
      }

      var picker = document.createElement('div');
      picker.className = 'ks-dest-picker';

      var opts = ddl.querySelectorAll('option');
      for (var i = 0; i < opts.length; i++) {
        var opt = opts[i];
        if (!opt || opt.disabled) continue;

        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'ks-dest-picker__btn';
        if (opt.selected) btn.classList.add('is-active');

        btn.innerHTML =
          '<span class="ks-dest-picker__icon">' +
            '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
              '<path d="M20 10c0 6-8 13-8 13S4 16 4 10a8 8 0 0 1 16 0Z"/>' +
              '<circle cx="12" cy="10" r="3"/>' +
            '</svg>' +
          '</span>' +
          '<span class="ks-dest-picker__text">' + (opt.textContent || '').trim() + '</span>';

        (function(value) {
          btn.addEventListener('click', function () {
            if (ddl.value === value) return;

            ddl.value = value;
            // Trigger AutoPostBack (ASP.NET)
            try {
              var evt = document.createEvent('HTMLEvents');
              evt.initEvent('change', true, false);
              ddl.dispatchEvent(evt);
            } catch (e) {
              if (typeof ddl.onchange === 'function') ddl.onchange();
            }
          });
        })(opt.value);

        picker.appendChild(btn);
      }

      // Inserisci picker subito dopo la select
      ddl.parentNode.insertBefore(picker, ddl.nextSibling);
      ddl.dataset.ksPickerBuilt = '1';
    }

    function applyUI(options) {
      options = options || {};

      // Seleziona il FormView effettivamente popolato (compatibilità ID variabili)
      (function selectPopulatedFormView() {
        var fvs = root.querySelectorAll('.js-ks-userdata-fv');
        if (!fvs || !fvs.length) return;

        for (var k = 0; k < fvs.length; k++) {
          fvs[k].classList.remove('is-active');
        }

        var chosen = null;
        for (var i = 0; i < fvs.length; i++) {
          // Se il FormView ha renderizzato un template con contenuto, troveremo le pane
          if (fvs[i].querySelector('.ks-userdata-pane') || fvs[i].querySelector('input,select,textarea,button')) {
            // Preferiamo quello che contiene effettivamente le pane
            if (fvs[i].querySelector('.ks-userdata-pane')) {
              chosen = fvs[i];
              break;
            }
            // fallback: qualche input (es: in EditItemTemplate) -> potenzialmente valido
            if (!chosen) chosen = fvs[i];
          }
        }

        if (chosen) {
          chosen.classList.add('is-active');
        }
        // fallback: lascia visibile il primo via CSS
      })();

      // UI avanzata indirizzi (picker)
      buildDestinationPicker();

      var params = new URLSearchParams(window.location.search || '');
      var tab = (params.get('tab') || '').toLowerCase();

      var isAddr = (tab === 'addr' || tab === 'addresses' || tab === 'indirizzi');
      root.classList.remove('is-tab-details', 'is-tab-addr');
      root.classList.add(isAddr ? 'is-tab-addr' : 'is-tab-details');

      // Tabs active state
      var tabsWrap = root.querySelector('.js-ks-userdata-tabs');
      if (tabsWrap) {
        var links = tabsWrap.querySelectorAll('a.nav-link');
        for (var a = 0; a < links.length; a++) {
          links[a].classList.remove('active');
          links[a].setAttribute('aria-selected', 'false');
        }

        for (var b = 0; b < links.length; b++) {
          var href = links[b].getAttribute('href') || '';
          var isAddrLink = href.indexOf('tab=addr') !== -1;
          if ((isAddr && isAddrLink) || (!isAddr && !isAddrLink)) {
            links[b].classList.add('active');
            links[b].setAttribute('aria-selected', 'true');
          }
        }
      }

      // Se siamo su indirizzi, porta il focus alla sezione (solo on load)
      if (isAddr && !options.skipScroll) {
        var anchor = document.getElementById('addr');
        if (anchor) {
          // Evita scroll jump aggressivo in caso di postback
          try {
            anchor.scrollIntoView({ block: 'start', behavior: 'smooth' });
          } catch (e) {
            anchor.scrollIntoView(true);
          }
        }
      }
    }

    // Prima applicazione (load)
    applyUI({ skipScroll: false });

    // Re-applica dopo postback AJAX (UpdatePanel)
    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
      try {
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
          applyUI({ skipScroll: true });
        });
      } catch (e) {
        // ignore
      }
    }
  });
})();
