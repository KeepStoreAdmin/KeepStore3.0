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
