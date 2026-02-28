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

function injectCssOnce(href, key) {
  try {
    if (!href) return;
    key = key || href;
    if (document.querySelector('link[data-ks-css="' + key.replace(/"/g, '') + '"]')) return;

    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.setAttribute('data-ks-css', key);
    document.head.appendChild(link);
  } catch (e) {
    // noop
  }
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

  var successPages = {
    'coupon_esito_acquisto.aspx': true,
    'esito_acquisto.aspx': true,
    'ordine_esito_acquisto.aspx': true,
    'checkout_success.aspx': true,
    'checkoutsuccess.aspx': true,
    'success.aspx': true
  };

  function isLikelySuccessPage(fn) {
    fn = (fn || '').toLowerCase();
    if (!fn) return false;
    // euristica: esito/success/conferma sono quasi sempre pagine transazionali
    if (fn.indexOf('esito') !== -1) return true;
    if (fn.indexOf('success') !== -1) return true;
    if (fn.indexOf('conferma') !== -1) return true;
    return false;
  }


  if (accountPages[file]) addBodyClass('ks-page-account');
  if (documentsPages[file]) addBodyClass('ks-page-documents');
  if (authPages[file]) addBodyClass('ks-page-auth');
  if (successPages[file] || isLikelySuccessPage(file)) addBodyClass('ks-page-success');

// Extra flags
if (file === 'documentidettaglio.aspx') addBodyClass('ks-page-order-detail');

// Orders/Documents UI stylesheet (scoped)
if (documentsPages[file]) {
  injectCssOnce('/Public/assets/keepstore/css/order-ui.css', 'order-ui');
}


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
      // 1) Mobile cards + data-label (già in uso)
      enhanceDocumentsTableCards(root);

      // 2) Lista documenti: toolbar + ricerca client-side + righe cliccabili
      if (file === 'documenti.aspx') {
        enhanceDocumentList(root);
      }

      // 3) Dettaglio documento: header azioni + summary meta
      if (file === 'documentidettaglio.aspx') {
        enhanceDocumentDetail(root);
      }
    }

    function enhanceDocumentsTableCards(root) {
      var tables = root.querySelectorAll('table.table');
      for (var i = 0; i < tables.length; i++) {
        var t = tables[i];

        // Evita tabelle layout senza thead
        if (!t.querySelector('thead')) continue;

        t.classList.add('ks-table-cards');
        addDataLabels(t);
      }
    }

    function enhanceDocumentList(root) {
      var table = findPrimaryDocumentsTable(root);
      if (!table) return;

      // Toolbar: crea una sola volta
      if (!root.querySelector('.ks-doc-toolbar')) {
        var tb = document.createElement('div');
        tb.className = 'ks-doc-toolbar';

        var left = document.createElement('div');
        left.className = 'ks-doc-toolbar-left';

        var search = document.createElement('input');
        search.type = 'search';
        search.className = 'form-control form-control-sm ks-doc-search';
        search.placeholder = 'Cerca documenti…';
        search.setAttribute('aria-label', 'Cerca documenti');
        search.autocomplete = 'off';

        left.appendChild(search);

        var right = document.createElement('div');
        right.className = 'ks-doc-toolbar-right';

        var count = document.createElement('div');
        count.className = 'ks-doc-count';
        count.textContent = '';
        right.appendChild(count);

        tb.appendChild(left);
        tb.appendChild(right);

        // Inserisci toolbar subito prima della tabella (o wrapper responsive)
        var insertBefore = table;
        if (table.parentElement && table.parentElement.classList.contains('table-responsive')) {
          insertBefore = table.parentElement;
        }
        insertBefore.parentElement.insertBefore(tb, insertBefore);

        // Bind ricerca (una sola volta)
        if (!search.dataset.ksBound) {
          search.dataset.ksBound = '1';
          search.addEventListener('input', function () {
            filterDocumentsTable(table, search.value || '', count);
          });
        }

        // Prima applicazione conteggio
        filterDocumentsTable(table, '', count);
      }

      // Righe cliccabili + icone azioni
      makeRowsClickable(table);
      upgradeActionLinks(table);

      // Aggiorna conteggio (se toolbar già esiste)
      var c = root.querySelector('.ks-doc-toolbar .ks-doc-count');
      if (c) filterDocumentsTable(table, (root.querySelector('.ks-doc-toolbar input[type=search]') || {}).value || '', c);
    }

    function enhanceDocumentDetail(root) {
      // Header con azioni (stampa / indietro) - una sola volta
      if (!root.querySelector('.ks-doc-header')) {
        var header = document.createElement('div');
        header.className = 'ks-doc-header';

        var title = document.createElement('div');
        title.className = 'ks-doc-title';
        title.textContent = extractDocTitle(root) || 'Dettaglio documento';

        var actions = document.createElement('div');
        actions.className = 'ks-doc-actions';

        var btnBack = document.createElement('button');
        btnBack.type = 'button';
        btnBack.className = 'btn btn-outline-secondary btn-sm';
        btnBack.textContent = 'Indietro';
        btnBack.addEventListener('click', function () {
          // Se troviamo un link a documenti.aspx, usalo; altrimenti history.back()
          var backLink = root.querySelector('a[href*="documenti.aspx"]');
          if (backLink && backLink.href) window.location.href = backLink.href;
          else window.history.back();
        });

        var btnPrint = document.createElement('button');
        btnPrint.type = 'button';
        btnPrint.className = 'btn btn-outline-secondary btn-sm';
        btnPrint.textContent = 'Stampa';
        btnPrint.addEventListener('click', function () {
          window.print();
        });

        actions.appendChild(btnBack);
        actions.appendChild(btnPrint);

        header.appendChild(title);
        header.appendChild(actions);

        // Inserisci sopra il primo contenuto visibile
        var anchor = root.firstElementChild;
        if (anchor) root.insertBefore(header, anchor);
        else root.appendChild(header);
      }

      // Summary meta: wrap del primo UL "semplice"
      var ul = findSimpleMetaList(root);
      if (ul && !ul.dataset.ksWrapped) {
        ul.dataset.ksWrapped = '1';
        ul.classList.add('ks-doc-meta-list');

        var wrap = document.createElement('div');
        wrap.className = 'ks-doc-summary';

        ul.parentElement.insertBefore(wrap, ul);
        wrap.appendChild(ul);

        // Split label/value solo se LI ha testo semplice
        var lis = ul.querySelectorAll('li');
        for (var i = 0; i < lis.length; i++) {
          var li = lis[i];
          if (li.dataset.ksSplit === '1') continue;
          if (li.children && li.children.length > 0) continue;

          var txt = (li.textContent || '').trim();
          var idx = txt.indexOf(':');
          if (idx > 0) {
            var label = txt.substring(0, idx).trim();
            var value = txt.substring(idx + 1).trim();

            li.textContent = '';
            var s1 = document.createElement('span');
            s1.className = 'ks-doc-meta-label';
            s1.textContent = label;

            var s2 = document.createElement('span');
            s2.className = 'ks-doc-meta-value';
            s2.textContent = value;

            li.appendChild(s1);
            li.appendChild(s2);
            li.dataset.ksSplit = '1';
          }
        }
      }

      // Tabelle dettaglio: card mobile + data-label
      enhanceDocumentsTableCards(root);
      enhanceDocumentDetailDeep(root);
    }


function wrapSectionByHeadingText(root, containsText, sectionClass) {
  try {
    containsText = (containsText || '').toLowerCase();
    if (!containsText) return;

    var headings = root.querySelectorAll('h1,h2,h3,h4,h5,h6');
    for (var i = 0; i < headings.length; i++) {
      var h = headings[i];
      if (!h || !h.parentElement) continue;
      if (h.dataset.ksSectionWrapped === '1') continue;

      var ht = (h.textContent || '').toLowerCase().trim();
      if (ht.indexOf(containsText) === -1) continue;

      // Create wrapper section
      var sec = document.createElement('section');
      sec.className = sectionClass || 'ks-doc-section';
      sec.dataset.ksDocSection = '1';

      // Insert section before heading
      h.parentElement.insertBefore(sec, h);

      // Move heading and following nodes until next heading of same/higher level
      var level = parseInt((h.tagName || 'H6').replace('H', ''), 10);
      var node = h;

      while (node) {
        var next = node.nextSibling;
        sec.appendChild(node);

        if (next && next.nodeType === 1) {
          var tag = (next.tagName || '').toUpperCase();
          if (tag.length === 2 && tag[0] === 'H') {
            var nextLevel = parseInt(tag[1], 10);
            if (!isNaN(nextLevel) && nextLevel <= level) break;
          }
        }

        node = next;
      }

      h.dataset.ksSectionWrapped = '1';
      // Wrap only the first matching section (avoid double wrap on repeated headings)
      break;
    }
  } catch (e) {
    // noop
  }
}

function enhanceDocumentDetailDeep(root) {
  try {
    if (file !== 'documentidettaglio.aspx') return;

    // Wrap key blocks into themed cards (NO control changes)
    wrapSectionByHeadingText(root, 'spedizione, pagamento e tracking', 'ks-doc-section ks-doc-section-shipping');
    wrapSectionByHeadingText(root, 'indirizzo di fatturazione', 'ks-doc-section ks-doc-section-billing');
    wrapSectionByHeadingText(root, 'indirizzo di spedizione', 'ks-doc-section ks-doc-section-delivery');
    wrapSectionByHeadingText(root, 'paga adesso', 'ks-doc-section ks-doc-section-paynow');
    wrapSectionByHeadingText(root, 'articoli', 'ks-doc-section ks-doc-section-items');
    wrapSectionByHeadingText(root, 'riepilogo importi', 'ks-doc-section ks-doc-section-summary');

    // Make sure tables inside the wrapped sections are still card-enabled
    var sections = root.querySelectorAll('section[data-ks-doc-section="1"]');
    for (var i = 0; i < sections.length; i++) {
      var tbl = sections[i].querySelector('table.table');
      if (tbl) {
        tbl.classList.add('ks-table-cards');
        addDataLabels(tbl);
      }
    }
  } catch (e) {
    // noop
  }
}

    function findPrimaryDocumentsTable(root) {
      // Cerca la prima tabella "seria": thead + almeno una riga nel tbody
      var tables = root.querySelectorAll('table.table');
      for (var i = 0; i < tables.length; i++) {
        var t = tables[i];
        if (!t.querySelector('thead')) continue;
        var rows = t.querySelectorAll('tbody tr');
        if (rows && rows.length > 0) return t;
      }
      return null;
    }

    function filterDocumentsTable(table, term, countEl) {
      if (!table) return;

      var q = (term || '').toLowerCase().trim();
      var rows = table.querySelectorAll('tbody tr');

      var visible = 0;
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        var txt = (r.textContent || '').toLowerCase();

        var ok = !q || txt.indexOf(q) !== -1;
        r.style.display = ok ? '' : 'none';
        if (ok) visible++;
      }

      if (countEl) {
        countEl.textContent = visible + (visible === 1 ? ' documento' : ' documenti');
      }
    }

    function makeRowsClickable(table) {
      if (!table) return;

      var rows = table.querySelectorAll('tbody tr');
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (r.dataset.ksRowBound === '1') continue;

        // Link preferito: dettaglio documento
        var a = r.querySelector('a[href*="documentidettaglio.aspx"], a[href*="documentidettaglio"]') || r.querySelector('a[href]');
        if (!a || !a.href) continue;

        r.dataset.ksHref = a.href;
        r.classList.add('ks-row-link');

        r.addEventListener('click', function (ev) {
          var t = ev.target;
          // Se click su elemento interattivo, lascia comportamento originale
          if (t && (t.closest('a') || t.closest('button') || t.closest('input') || t.closest('select') || t.closest('textarea'))) return;

          var href = this.dataset.ksHref;
          if (href) window.location.href = href;
        });

        r.dataset.ksRowBound = '1';
      }
    }

    function upgradeActionLinks(table) {
      if (!table) return;

      var links = table.querySelectorAll('a[href]');
      for (var i = 0; i < links.length; i++) {
        var a = links[i];
        if (a.dataset.ksUpgraded === '1') continue;

        // Heuristic: link con icona/immagine o testo molto corto -> bottone icona
        var hasIcon = !!a.querySelector('i, img');
        var txt = (a.textContent || '').trim();

        if (hasIcon || (txt.length > 0 && txt.length <= 3)) {
          a.classList.add('ks-icon-btn');
          a.dataset.ksUpgraded = '1';
        }
      }
    }

    function extractDocTitle(root) {
      var h = root.querySelector('h1, h2, h3');
      if (h && (h.textContent || '').trim().length > 0) return (h.textContent || '').trim();

      var bc = document.querySelector('.ks-breadcrumb h1, .ks-breadcrumb .h5, .ks-breadcrumb .h6');
      if (bc && (bc.textContent || '').trim().length > 0) return (bc.textContent || '').trim();

      return '';
    }

    function findSimpleMetaList(root) {
      // Primo UL "semplice": pochi elementi, contenuto con ':' (label: value)
      var uls = root.querySelectorAll('ul');
      for (var i = 0; i < uls.length; i++) {
        var ul = uls[i];
        if (ul.closest('nav')) continue;
        if (ul.classList.contains('breadcrumb') || ul.classList.contains('tf-breadcrumb-list')) continue;

        var lis = ul.querySelectorAll('li');
        if (!lis || lis.length < 2 || lis.length > 12) continue;

        // deve contenere almeno 2 item con ":" e nessun elemento complesso
        var score = 0;
        for (var j = 0; j < lis.length; j++) {
          var li = lis[j];
          if (li.children && li.children.length > 0) continue;
          if (((li.textContent || '').indexOf(':')) > 0) score++;
        }
        if (score >= 2) return ul;
      }
      return null;
    }

  function activateAccountSidebar() {
    var sidebar = document.querySelector('.ks-account-sidebar');
    if (!sidebar) return;

    var links = sidebar.querySelectorAll('a[href]');
    if (!links || links.length === 0) return;

    var current = normalizePath(window.location.href);
    var currentFile = (current.split('/').pop() || '').toLowerCase();

    // Alias: alcune pagine dettaglio devono evidenziare la voce "Documenti"
    var currentKey = currentFile;
    if (currentKey === 'documentidettaglio.aspx') currentKey = 'documenti.aspx';

    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var href = a.getAttribute('href');
      if (!href) continue;

      var path = normalizePath(href);
      var file = (path.split('/').pop() || '').toLowerCase();

      if (file && file === currentKey) {
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
    body.className = 'card-body ks-auth-body';

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

  function getAuthTitleFallback() {
    switch (file) {
      case 'login.aspx': return 'Accedi';
      case 'registrazione.aspx': return 'Crea account';
      case 'remind.aspx':
      case 'recuperoaccesso.aspx':
      case 'passwordpersa.aspx': return 'Recupero accesso';
      case 'accessonegato.aspx': return 'Accesso negato';
      default: return 'Account';
    }
  }

  function extractAndRemoveFirstHeading(scope) {
    if (!scope) return '';
    var h = scope.querySelector('h1, h2, h3, h4, h5');
    if (!h) return '';

    // evita heading dentro nav/breadcrumb o elementi di layout
    if (h.closest('nav') || h.closest('.breadcrumb') || h.closest('.ks-breadcrumb')) return '';

    var t = (h.textContent || '').trim();
    if (t.length === 0) return '';

    // rimuovi per evitare doppio titolo (verrà riposizionato in header)
    try { h.parentNode.removeChild(h); } catch (e) { }
    return t;
  }

  function buildAuthLinksFooter(scope) {
    if (!scope) return;
    if (scope.querySelector('.ks-auth-links')) return;

    var anchors = scope.querySelectorAll('a[href]');
    if (!anchors || anchors.length === 0) return;

    var wanted = [];
    var seen = {};

    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (!a || !a.getAttribute) continue;
      var href = (a.getAttribute('href') || '').toLowerCase();
      if (!href) continue;

      var isAuthLink = (
        href.indexOf('login.aspx') !== -1 ||
        href.indexOf('registrazione') !== -1 ||
        href.indexOf('register') !== -1 ||
        href.indexOf('remind') !== -1 ||
        href.indexOf('recupero') !== -1 ||
        href.indexOf('passwordpersa') !== -1 ||
        href.indexOf('cambiapassword') !== -1
      );

      if (!isAuthLink) continue;

      // evita duplicati
      if (seen[href]) continue;
      seen[href] = true;

      var txt = (a.textContent || '').trim();
      if (!txt) txt = a.getAttribute('title') || '';
      if (!txt) continue;

      wanted.push({ href: a.href || a.getAttribute('href'), text: txt, original: a });
    }

    if (wanted.length === 0) return;

    // nascondi originali (evita doppioni)
    for (var k = 0; k < wanted.length; k++) {
      try { wanted[k].original.classList.add('ks-auth-link-original'); } catch (e) { }
    }

    var wrap = document.createElement('div');
    wrap.className = 'ks-auth-links';

    for (var j = 0; j < wanted.length; j++) {
      var l = document.createElement('a');
      l.href = wanted[j].href;
      l.textContent = wanted[j].text;
      l.className = 'ks-auth-link';
      wrap.appendChild(l);
    }

    scope.appendChild(wrap);
  }

  function addPasswordToggles(scope) {
    if (!scope) return;
    var pwds = scope.querySelectorAll('input[type="password"]');
    for (var i = 0; i < pwds.length; i++) {
      var inp = pwds[i];
      if (!inp || inp.dataset.ksPwToggle === '1') continue;

      // Preferisci aggiungere il bottone in una input-group, se possibile
      var parent = inp.parentElement;
      var group = null;

      if (parent && parent.classList && parent.classList.contains('input-group')) {
        group = parent;
      } else {
        group = document.createElement('div');
        group.className = 'input-group ks-password-group';
        if (parent) parent.insertBefore(group, inp);
        group.appendChild(inp);
      }

      // Evita doppio toggle
      if (group.querySelector('.ks-password-toggle')) {
        inp.dataset.ksPwToggle = '1';
        continue;
      }

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn btn-outline-secondary ks-password-toggle';
      btn.textContent = 'Mostra';

      btn.addEventListener('click', function () {
        var input = this.parentElement ? this.parentElement.querySelector('input[type="password"], input[type="text"]') : null;
        if (!input) return;
        var isPwd = (input.getAttribute('type') || '').toLowerCase() === 'password';
        input.setAttribute('type', isPwd ? 'text' : 'password');
        this.textContent = isPwd ? 'Nascondi' : 'Mostra';
      });

      group.appendChild(btn);
      inp.dataset.ksPwToggle = '1';
    }
  }

  function applyInputHints(scope) {
    if (!scope) return;
    var inputs = scope.querySelectorAll('input');
    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      if (!el) continue;

      var type = (el.getAttribute('type') || '').toLowerCase();
      if (type === 'hidden') continue;

      var id = (el.getAttribute('id') || '').toLowerCase();
      var name = (el.getAttribute('name') || '').toLowerCase();
      var key = id + ' ' + name;

      // Email
      if (key.indexOf('mail') !== -1) {
        if (!el.getAttribute('autocomplete')) el.setAttribute('autocomplete', 'email');
        el.setAttribute('inputmode', 'email');
        el.setAttribute('autocapitalize', 'none');
        el.setAttribute('spellcheck', 'false');
      }

      // Username
      if (key.indexOf('user') !== -1 || key.indexOf('login') !== -1) {
        if (!el.getAttribute('autocomplete')) el.setAttribute('autocomplete', 'username');
        el.setAttribute('autocapitalize', 'none');
        el.setAttribute('spellcheck', 'false');
      }

      // Password
      if (type === 'password') {
        if (!el.getAttribute('autocomplete')) {
          var ac = (file === 'registrazione.aspx') ? 'new-password' : 'current-password';
          el.setAttribute('autocomplete', ac);
        }
      }

      // Telefono
      if (key.indexOf('tel') !== -1 || key.indexOf('telefono') !== -1 || key.indexOf('cell') !== -1) {
        if (!el.getAttribute('inputmode')) el.setAttribute('inputmode', 'tel');
        if (!el.getAttribute('autocomplete')) el.setAttribute('autocomplete', 'tel');
      }
    }
  }

  function markPrimaryAuthButton(scope) {
    if (!scope) return;

    // Preferisci submit, fallback button/input
    var btn = scope.querySelector('button[type="submit"], input[type="submit"], input[type="button"]');
    if (!btn) return;

    btn.classList.add('ks-auth-primary');
    // assicurati stile base
    if (!btn.classList.contains('btn')) btn.classList.add('btn');
    if (!btn.classList.contains('btn-primary')) btn.classList.add('btn-primary');
    btn.classList.add('btn-lg');
  }

  function enhanceAuthDeep(root) {
    if (!root) return;
    var card = root.querySelector('.ks-auth-card');
    if (!card) return;

    var body = card.querySelector('.ks-auth-body') || card.querySelector('.card-body');
    if (!body) return;

    // Header (solo una volta)
    if (!card.querySelector('.ks-auth-header')) {
      var header = document.createElement('div');
      header.className = 'card-header ks-auth-header';

      var wrap = document.createElement('div');
      var title = extractAndRemoveFirstHeading(body) || getAuthTitleFallback();

      var h = document.createElement('h1');
      h.className = 'h5 ks-auth-title';
      h.textContent = title;

      wrap.appendChild(h);
      header.appendChild(wrap);

      card.insertBefore(header, body);
    }

    // ValidationSummary -> alert bootstrap
    var vs = body.querySelector('.validation-summary-errors, .ValidationSummary');
    if (vs && !vs.classList.contains('ks-auth-alert')) {
      vs.classList.add('alert', 'alert-danger', 'ks-auth-alert');
      vs.setAttribute('role', 'alert');
    }

    applyInputHints(body);
    addPasswordToggles(body);
    markPrimaryAuthButton(body);
    buildAuthLinksFooter(body);
  }

  function enhanceSuccessLayout(root) {
    if (!root) return;
    if (root.querySelector('.ks-success-shell')) return;

    var shell = document.createElement('div');
    shell.className = 'ks-success-shell';

    var card = document.createElement('div');
    card.className = 'card ks-success-card';

    var body = document.createElement('div');
    body.className = 'card-body';

    // Move children into card body
    var nodes = [];
    for (var i = 0; i < root.childNodes.length; i++) nodes.push(root.childNodes[i]);
    for (var n = 0; n < nodes.length; n++) body.appendChild(nodes[n]);

    // Hero (icon + title)
    var hero = document.createElement('div');
    hero.className = 'ks-success-hero';

    var icon = document.createElement('div');
    icon.className = 'ks-success-icon';
    icon.textContent = '✓';

    var txt = document.createElement('div');
    var title = extractAndRemoveFirstHeading(body) || 'Operazione completata';

    var h = document.createElement('h1');
    h.className = 'h5 ks-success-title';
    h.textContent = title;

    txt.appendChild(h);

    hero.appendChild(icon);
    hero.appendChild(txt);

    // Inserisci hero in cima al body
    body.insertBefore(hero, body.firstChild);

    // Actions
    if (!body.querySelector('.ks-success-actions')) {
      var acts = document.createElement('div');
      acts.className = 'ks-success-actions';

      var aHome = document.createElement('a');
      aHome.href = 'Default.aspx';
      aHome.className = 'btn btn-primary';
      aHome.textContent = 'Torna alla home';

      var aAcc = document.createElement('a');
      aAcc.href = 'myaccount.aspx';
      aAcc.className = 'btn btn-outline-secondary';
      aAcc.textContent = 'Vai al tuo account';

      acts.appendChild(aHome);
      acts.appendChild(aAcc);
      body.appendChild(acts);
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
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth') || document.body.classList.contains('ks-page-success')) {
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
      enhanceAuthDeep(root);
    }

    if (document.body.classList.contains('ks-page-success')) {
      enhanceSuccessLayout(root);
    }

    // Dedupe breadcrumb (principalmente per pagine legacy migrate a Site.master)
    if (document.body.classList.contains('ks-page-account') || document.body.classList.contains('ks-page-auth') || document.body.classList.contains('ks-page-success')) {
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
