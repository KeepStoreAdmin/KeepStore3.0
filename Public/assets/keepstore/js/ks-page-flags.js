/* ============================================================
   KeepStore 3.0 - Page flags + progressive UI enhancement
   - Aggiunge classi al <body> in base alla pagina corrente
   - Applica upgrade UI lato client (NO modifica controlli WebForms)
   - Dedupe breadcrumb e menu legacy dove possibile
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

  function normalizePath(href) {
    try {
      var u = new URL(href, window.location.origin);
      return (u.pathname || '').toLowerCase();
    } catch (e) {
      return (href || '').toLowerCase();
    }
  }

  function getActiveFileFromLocation() {
    return getFileName();
  }

  var file = getActiveFileFromLocation();

  // Body classes (script è in fondo pagina, body esiste)
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
    'indirizzi.aspx': true
  };

  var documentsPages = {
    'documenti.aspx': true,
    'documentidettaglio.aspx': true
  };

  var authPages = {
    'login.aspx': true,
    'registrazione.aspx': true,
    'remind.aspx': true,
    'recuperoaccesso.aspx': true,
    'passwordpersa.aspx': true,
    'accessonegato.aspx': true
  };

  if (accountPages[file]) addBodyClass('ks-page-account');
  if (documentsPages[file]) addBodyClass('ks-page-documents');
  if (authPages[file]) addBodyClass('ks-page-auth');

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
    var inputs = root.querySelectorAll('input, select, textarea, button');
    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      var tag = (el.tagName || '').toLowerCase();
      var type = (el.getAttribute('type') || '').toLowerCase();

      // Skip hidden
      if (tag === 'input' && type === 'hidden') continue;

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

  function addDataLabels(table) {
    var thead = table.querySelector('thead');
    if (!thead) return;

    var headers = thead.querySelectorAll('th');
    if (!headers || headers.length === 0) return;

    var headerTexts = [];
    for (var i = 0; i < headers.length; i++) {
      headerTexts.push((headers[i].textContent || '').trim());
    }

    var rows = table.querySelectorAll('tbody tr');
    for (var r = 0; r < rows.length; r++) {
      var cells = rows[r].querySelectorAll('td');
      for (var c = 0; c < cells.length; c++) {
        var label = headerTexts[c] || '';
        if (!cells[c].hasAttribute('data-label')) {
          cells[c].setAttribute('data-label', label);
        }
      }
    }
  }

  function enhanceWishlist(root) {
    var tables = root.querySelectorAll('table');
    for (var i = 0; i < tables.length; i++) {
      var t = tables[i];
      var thead = t.querySelector('thead');
      if (!thead) continue;

      var headers = thead.querySelectorAll('th');
      if (!headers || headers.length < 3) continue;

      // Heuristic: deve avere colonna "Elimina"
      var actionIndex = -1;
      for (var h = 0; h < headers.length; h++) {
        var ht = (headers[h].textContent || '').toLowerCase();
        if (ht.indexOf('elimina') !== -1 || ht.indexOf('delete') !== -1) {
          actionIndex = h;
          break;
        }
      }
      if (actionIndex === -1) continue;

      t.classList.add('ks-table-wishlist');
      addDataLabels(t);

      var rows = t.querySelectorAll('tbody tr');
      for (var r = 0; r < rows.length; r++) {
        var cells = rows[r].querySelectorAll('td');
        if (!cells || cells.length === 0) continue;

        var ac = cells[actionIndex];
        if (ac) {
          ac.classList.add('ks-wl-actions');
          // Prova ad "upgrade" azioni senza toccare i controlli server
          var acts = ac.querySelectorAll('a, button, input');
          for (var k = 0; k < acts.length; k++) {
            var a = acts[k];
            var atag = (a.tagName || '').toLowerCase();
            var atype = (a.getAttribute('type') || '').toLowerCase();

            if (atag === 'input' && atype === 'hidden') continue;

            // ImageButton (input type=image) -> lascia, verrà stilizzato via CSS
            if (atag === 'input' && atype === 'image') {
              a.classList.add('ks-icon-btn');
              continue;
            }

            if (!a.classList.contains('btn')) {
              a.classList.add('btn', 'btn-outline-danger', 'btn-sm');
            }
          }
        }
      }

      // Solo prima tabella rilevante
      break;
    }
  }

  function enhanceDocumentsTables(root) {
    var tables = root.querySelectorAll('table.table');
    for (var i = 0; i < tables.length; i++) {
      var t = tables[i];
      // Evita tabelle layout senza thead
      if (!t.querySelector('thead')) continue;

      t.classList.add('ks-table-cards');
      addDataLabels(t);
    }
  }

  function activateAccountSidebar() {
    var sidebar = document.querySelector('.ks-account-sidebar');
    if (!sidebar) return;

    var links = sidebar.querySelectorAll('a[href]');
    if (!links || links.length === 0) return;

    var current = normalizePath(window.location.href);
    var currentFile = (current.split('/').pop() || '').toLowerCase();

    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var href = a.getAttribute('href');
      if (!href) continue;

      var path = normalizePath(href);
      var file = (path.split('/').pop() || '').toLowerCase();

      if (file && file === currentFile) {
        a.classList.add('is-active');
      }
    }
  }

  function tryMarkAccountNav(root) {
    // Prima UL "grande" con link -> probabile menu account legacy
    var uls = root.querySelectorAll('ul');
    for (var i = 0; i < uls.length; i++) {
      var ul = uls[i];
      if (ul.classList.contains('ks-account-nav')) continue;

      var links = ul.querySelectorAll('li a[href]');
      if (links.length < 5) continue;

      // Heuristic: deve puntare a pagine account
      var hit = 0;
      for (var k = 0; k < links.length; k++) {
        var href = (links[k].getAttribute('href') || '').toLowerCase();
        if (href.indexOf('myaccount') !== -1 ||
            href.indexOf('datiutente') !== -1 ||
            href.indexOf('documenti') !== -1 ||
            href.indexOf('wishlist') !== -1 ||
            href.indexOf('password') !== -1 ||
            href.indexOf('logout') !== -1) {
          hit++;
        }
      }

      if (hit >= 3) {
        ul.classList.add('ks-account-nav');
        // Nasconde menu legacy se esiste già la sidebar moderna
        if (document.querySelector('.ks-account-sidebar')) {
          ul.style.display = 'none';
        }
        break;
      }
    }
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
      // euristica conservativa: deve contenere "home"
      if (text.indexOf('home') !== -1) {
        el.style.display = 'none';
      }
    }
  }

  function enhanceAuthLayout(root) {
    // Sposta il contenuto in una card centrale (solo DOM, non tocca server controls)
    if (root.querySelector('.ks-auth-shell')) return;

    var shell = document.createElement('div');
    shell.className = 'ks-auth-shell';

    var card = document.createElement('div');
    card.className = 'card ks-auth-card';

    var body = document.createElement('div');
    body.className = 'card-body';

    // Move all children into card body
    var nodes = [];
    for (var i = 0; i < root.childNodes.length; i++) {
      nodes.push(root.childNodes[i]);
    }

    for (var n = 0; n < nodes.length; n++) {
      body.appendChild(nodes[n]);
    }

    card.appendChild(body);
    shell.appendChild(card);

    root.appendChild(shell);
  }

    function applyKsEnhancements() {
    try {
    // Preferisci il contenitore interno della shell (evita di wrappare header/footer)
    var root = document.querySelector('.ks-account-main') || document.querySelector('main') || document.body;

    // Patches solo su pagine account/auth
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth')) {
      enhanceTables(root);
      enhanceForms(root);
    }

    if (document.body.classList.contains('ks-page-account')) {
      tryMarkAccountNav(root);
      activateAccountSidebar();
    }

    if (document.body.classList.contains('ks-page-wishlist')) {
      enhanceWishlist(root);
    }

    if (document.body.classList.contains('ks-page-documents')) {
      enhanceDocumentsTables(root);
    }

    if (document.body.classList.contains('ks-page-auth')) {
      enhanceAuthLayout(root);
    }

    // Dedupe breadcrumb (principalmente per pagine legacy migrate a Site.master)
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth')) {
      dedupeBreadcrumb(document.querySelector('main') || document.body);
    }
    } catch (e) {
      // noop
    }
  }

  document.addEventListener('DOMContentLoaded', applyKsEnhancements);

  // Supporto UpdatePanel (postback parziali): ri-applica le enhancement UI
  if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
    try {
      var prm = Sys.WebForms.PageRequestManager.getInstance();
      if (prm && !prm._ksEnhancementsHooked) {
        prm._ksEnhancementsHooked = true;
        prm.add_endRequest(function () {
          applyKsEnhancements();
        });
      }
    } catch (e) {
      // noop
    }
  }
})();
