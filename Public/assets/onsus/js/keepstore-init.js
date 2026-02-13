/*!
 * keepstore-init.js
 * Tiny bootstrapper that re-triggers template behaviours when pages are rendered by ASP.NET MasterPages.
 * Must be safe to call multiple times.
 */
(function (w, d) {
  'use strict';

  function oncePerEl(el, key) {
    if (!el) return false;
    var k = '__ks_' + key;
    if (el[k]) return false;
    el[k] = true;
    return true;
  }

  function initWow() {
    try {
      if (w.WOW && oncePerEl(d.documentElement, 'wow')) {
        new w.WOW().init();
      }
    } catch (e) {}
  }

  function initNiceSelect() {
    try {
      if (!w.jQuery) return;
      var $ = w.jQuery;
      if ($.fn && $.fn.niceSelect) {
        $('select').each(function () {
          var $s = $(this);
          if ($s.data('ks-nice')) return;
          $s.data('ks-nice', 1);
          try { $s.niceSelect(); } catch (e) {}
        });
      }
    } catch (e) {}
  }

  function initGoTop() {
    try {
      // Template main.js usually handles this; this is a fallback.
      var btn = d.querySelector('.go-top, .scroll-top, #back-to-top');
      if (!btn) return;
      if (!oncePerEl(btn, 'gotop')) return;

      btn.addEventListener('click', function (ev) {
        ev.preventDefault();
        try { w.scrollTo({ top: 0, behavior: 'smooth' }); }
        catch (e) { w.scrollTo(0, 0); }
      });
    } catch (e) {}
  }

  function initPreloader() {
    try {
      var pre = d.querySelector('.preload, .preloader, #preloader');
      if (!pre) return;
      // If template already removed it, ignore.
      setTimeout(function () {
        if (pre && pre.parentNode) pre.parentNode.removeChild(pre);
      }, 600);
    } catch (e) {}
  }

  // Public init entrypoint
  w.keepStoreInit = function () {
    initWow();
    initNiceSelect();
    initGoTop();
    initPreloader();
  };

  // Optional page-level hooks
  w.keepStoreShopInit = function () {
    // If the template uses shop.js, it already binds filters.
    // Place future Shop-specific rebind logic here (idempotent).
  };

  w.keepStoreProductInit = function () {
    // drift.js is already loaded in the master; this is only a safe hook.
    // Place future product gallery/zoom rebind logic here (idempotent).
  };

  // Auto-run
  if (d.readyState === 'loading') {
    d.addEventListener('DOMContentLoaded', function () { w.keepStoreInit(); });
  } else {
    w.keepStoreInit();
  }
})(window, document);
