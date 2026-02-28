/* ============================================================
   KeepStore 3.0 - Page flags + progressive UI enhancement
   - Aggiunge classi al <body> in base alla pagina corrente
   - Applica piccoli "upgrade" UI (solo lato client) senza cambiare controlli WebForms
   - Riduce duplicazioni breadcrumb nelle pagine legacy
   ============================================================ */

(function () {
  function safeSlug(s) {
    return (s || '')
      .toLowerCase()
      .replace(/\.aspx$/i, '')
      .replace(/[^a-z0-9\-_]+/g, '-');
  }

  function addBodyClass(cls) {
    if (!cls || !document.body) return;
    document.body.classList.add(cls);
  }

  function getFileName() {
    var path = (window.location.pathname || '').toLowerCase();
    var file = path.split('/').pop() || '';
    if (!file) file = 'default.aspx';
    return file;
  }

  // Body classes (immediate; script è in fondo pagina, quindi body esiste)
  var file = getFileName();
  addBodyClass('ks-page');
  addBodyClass('ks-page-' + safeSlug(file));

  var accountPages = {
    'myaccount.aspx': true,
    'datiutente.aspx': true,
    'documenti.aspx': true,
    'documentidettaglio.aspx': true,
    'wishlist.aspx': true,
    'cambiapassword.aspx': true,
    'password.aspx': true,
    'indirizzi.aspx': true,
    'ordini.aspx': true
  };

  var authPages = {
    'login.aspx': true,
    'registrazione.aspx': true,
    'registrati.aspx': true,
    'recuperoaccesso.aspx': true,
    'passwordpersa.aspx': true,
    'remind.aspx': true
  };

  if (accountPages[file]) addBodyClass('ks-page-account');

  var documentsPages = {
    'documenti.aspx': true,
    'documentidettaglio.aspx': true
  };

  if (documentsPages[file]) addBodyClass('ks-page-documents');
  if (authPages[file]) addBodyClass('ks-page-auth');
  if (file === 'wishlist.aspx') addBodyClass('ks-page-wishlist');

  function enhanceTables(root) {
    var tables = root.querySelectorAll('table');
    for (var i = 0; i < tables.length; i++) {
      var t = tables[i];

      // Evita di "rompere" eventuali tabelle già custom
      if (!t.classList.contains('table')) {
        t.classList.add('table', 'table-sm', 'align-middle');
      }

      // Wrapper responsive: se già presente non fa nulla
      var parent = t.parentElement;
      if (parent && !parent.classList.contains('table-responsive')) {
        var wrap = document.createElement('div');
        wrap.className = 'table-responsive';
        parent.insertBefore(wrap, t);
        wrap.appendChild(t);
      }
    }
  }

  function enhanceForms(root) {
    var inputs = root.querySelectorAll('input, select, textarea');
    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      var tag = (el.tagName || '').toLowerCase();
      var type = (el.getAttribute('type') || '').toLowerCase();

      // Skip hidden
      if (type === 'hidden') continue;

      // Text-like
      if (tag === 'textarea' || tag === 'select' ||
          (tag === 'input' && (type === 'text' || type === 'email' || type === 'password' || type === 'tel' || type === 'number' || type === 'date' || type === 'search'))) {
        if (!el.classList.contains('form-control') && !el.classList.contains('form-select')) {
          if (tag === 'select') el.classList.add('form-select');
          else el.classList.add('form-control');
        }
      }

      // Buttons
      if (tag === 'input' && (type === 'submit' || type === 'button')) {
        if (!el.classList.contains('btn')) {
          el.classList.add('btn', 'btn-primary');
        }
      }

      if (tag === 'button') {
        if (!el.classList.contains('btn')) {
          el.classList.add('btn', 'btn-primary');
        }
      }
    }
  }

  function tryMarkAccountNav(root) {
    // Prima UL "grande" con link -> probabile menu account
    var uls = root.querySelectorAll('ul');
    for (var i = 0; i < uls.length; i++) {
      var ul = uls[i];
      if (ul.classList.contains('ks-account-nav')) continue;

      var links = ul.querySelectorAll('li a');
      if (links.length >= 5) {
        ul.classList.add('ks-account-nav');
        break;
      }
    }
  }

function hideLegacyAccountNav(root) {
  try {
    var nav = root.querySelector('.ks-account-nav');
    var aside = document.querySelector('.ks-account-aside');
    if (nav && aside) {
      nav.style.display = 'none';
    }
  } catch (e) { }
}

  function dedupeBreadcrumb(root) {
    // Se esiste il breadcrumb del tema, nasconde breadcrumb legacy più comuni
    if (!root.querySelector('.ks-breadcrumb')) return;

    var candidates = root.querySelectorAll(
      'nav[aria-label="breadcrumb"], .breadcrumb, .breadcrumbs, .woocommerce-breadcrumb, .breadcrumb-area, .tf-breadcrumb'
    );

    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      if (el.closest('.ks-breadcrumb')) continue;

      var text = (el.textContent || '').toLowerCase();
      // euristica molto conservativa: deve contenere "home"
      if (text.indexOf('home') !== -1) {
        el.style.display = 'none';
      }
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    var main = document.querySelector('main') || document.body;

    // Patches solo su pagine account/auth
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth')) {
      enhanceTables(main);
      enhanceForms(main);
    }

    if (document.body.classList.contains('ks-page-account')) {
      tryMarkAccountNav(main);
      hideLegacyAccountNav(main);
    }

    // Dedupe breadcrumb (principalmente per pagine legacy migrate a Site.master)
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth')) {
      dedupeBreadcrumb(main);
    }
  });
})();
