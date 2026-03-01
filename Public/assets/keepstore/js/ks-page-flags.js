/*
  KeepStore - page flags & account sidebar helpers
  ------------------------------------------------
  - Adds body classes based on current path
  - Marks active item in the account sidebar
  - Hides legacy in-page account navigation when the new sidebar is present

  NOTE:
  Previous version could incorrectly mark the sidebar UL as the "legacy" nav,
  because it searched within <main> (which contains both aside + content).
  This revision targets ONLY the content column (.ks-account-content),
  so we never hide the sidebar menu.
*/

(function () {
  'use strict';

  function normalizePath(p) {
    try {
      return (p || '')
        .toLowerCase()
        .replace(/\/+$/, '')
        .replace(/\.aspx(\?.*)?$/, '.aspx');
    } catch (e) {
      return (p || '').toLowerCase();
    }
  }

  function addClass(el, cls) {
    if (!el || !cls) return;
    if (el.classList) el.classList.add(cls);
  }

  function qs(name) {
    try {
      var u = new URL(window.location.href);
      return u.searchParams.get(name);
    } catch (e) {
      return null;
    }
  }

  function isAccountPath(path) {
    // Paths that should visually be considered "account" area.
    // (Keep aligned with the sidebar entries.)
    var p = normalizePath(path);
    return (
      p.endsWith('/myaccount.aspx') ||
      p.endsWith('/datiutente.aspx') ||
      p.endsWith('/indirizzi.aspx') ||
      p.endsWith('/password.aspx') ||
      p.endsWith('/wishlist.aspx') ||
      p.endsWith('/documenti.aspx') ||
      p.endsWith('/ordini.aspx') ||
      p.endsWith('/ordine.aspx') ||
      p.endsWith('/logout.aspx')
    );
  }

  function setBodyFlags() {
    var body = document.body;
    if (!body) return;

    var path = normalizePath(window.location.pathname);

    // Generic flags
    addClass(body, 'ks-ready');

    // Account
    if (isAccountPath(path)) {
      addClass(body, 'ks-page-account');

      // Special cases
      if (path.endsWith('/documenti.aspx')) {
        var t = qs('t');
        if (t) body.setAttribute('data-doc-type', t);
      }
      if (path.endsWith('/ordine.aspx')) {
        var oid = qs('id');
        if (oid) body.setAttribute('data-order-id', oid);
      }
    }
  }

  function setActiveSidebar() {
    var aside = document.querySelector('.ks-account-aside');
    if (!aside) return;

    var path = normalizePath(window.location.pathname);
    var docType = qs('t');

    var links = Array.prototype.slice.call(aside.querySelectorAll('a[href]'));
    if (!links.length) return;

    function normalizeHref(href) {
      try {
        var u = new URL(href, window.location.origin);
        return {
          path: normalizePath(u.pathname),
          docType: u.searchParams.get('t')
        };
      } catch (e) {
        return { path: normalizePath(href), docType: null };
      }
    }

    var best = null;

    links.forEach(function (a) {
      var n = normalizeHref(a.getAttribute('href'));
      if (!n.path) return;

      // Exact path match
      if (n.path === path) {
        // For documenti.aspx we prefer matching t=...
        if (path.endsWith('/documenti.aspx')) {
          if (n.docType && docType && n.docType === docType) best = a;
          else if (!best && !n.docType) best = a;
        } else {
          best = a;
        }
      }
    });

    // Fallback: if nothing exact, try partial match (rare)
    if (!best) {
      links.forEach(function (a) {
        var n = normalizeHref(a.getAttribute('href'));
        if (n.path && path.indexOf(n.path) !== -1) best = a;
      });
    }

    if (best) {
      // Remove existing active
      links.forEach(function (a) {
        a.classList.remove('active');
        if (a.parentElement) a.parentElement.classList.remove('active');
      });

      best.classList.add('active');
      if (best.parentElement) best.parentElement.classList.add('active');
    }
  }

  function tryMarkLegacyAccountNav() {
    // Mark the old "link list" nav only within the content column.
    // This avoids accidentally selecting the new sidebar UL.
    var content = document.querySelector('.ks-account-content');
    if (!content) return;

    // Find the first UL in content that looks like an account nav list.
    var uls = Array.prototype.slice.call(content.querySelectorAll('ul'));
    for (var i = 0; i < uls.length; i++) {
      var ul = uls[i];
      if (ul.classList.contains('ks-account-nav')) continue;

      var links = ul.querySelectorAll('a[href]');
      if (!links || links.length < 4) continue;

      // Heuristic: the legacy menu usually contains multiple .aspx links.
      var score = 0;
      for (var j = 0; j < links.length; j++) {
        var href = (links[j].getAttribute('href') || '').toLowerCase();
        if (href.indexOf('.aspx') !== -1) score++;
      }

      if (score >= 3) {
        ul.classList.add('ks-account-nav');
        break;
      }
    }
  }

  function hideLegacyAccountNavIfSidebarPresent() {
    var aside = document.querySelector('.ks-account-aside');
    if (!aside) return;

    var content = document.querySelector('.ks-account-content');
    if (!content) return;

    // Hide only nav lists inside content (never the sidebar menu)
    var legacyNavs = Array.prototype.slice.call(content.querySelectorAll('ul.ks-account-nav'));
    legacyNavs.forEach(function (ul) {
      ul.style.display = 'none';
    });
  }

  // Boot
  try {
    setBodyFlags();
    setActiveSidebar();
    tryMarkLegacyAccountNav();
    hideLegacyAccountNavIfSidebarPresent();
  } catch (e) {
    // Silent
  }
})();
