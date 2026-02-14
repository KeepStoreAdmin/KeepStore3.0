/*!
 * keepstore-init.js
 * Init "safe" per il template (non rompe se alcune librerie non sono presenti su certe pagine).
 */
(function () {
  "use strict";

  function callIfFn(fnName) {
    try {
      var fn = window[fnName];
      if (typeof fn === "function") fn();
    } catch (e) { /* noop */ }
  }

  // Base init: chiamalo sempre
  window.keepStoreInit = function () {
    // WOW.js
    try { if (window.WOW) new WOW().init(); } catch (e) {}

    // nice-select (jQuery plugin)
    try {
      if (window.jQuery && jQuery.fn && typeof jQuery.fn.niceSelect === "function") {
        jQuery("select").niceSelect();
      }
    } catch (e) {}

    // bootstrap-select (jQuery plugin)
    try {
      if (window.jQuery && jQuery.fn && typeof jQuery.fn.selectpicker === "function") {
        jQuery(".selectpicker").selectpicker();
      }
    } catch (e) {}
  };

  // Init pagina shop (filtri, listing)
  window.keepStoreShopInit = function () {
    // Se esiste la funzione del template shop.js, lasciala fare.
    callIfFn("shopInit");
  };

  // Init pagina prodotto (zoom/drift ecc.)
  window.keepStoreProductInit = function () {
    // Drift
    try {
      if (window.Drift) {
        // drift.min.js del template inizializza spesso via data-attributes
      }
    } catch (e) {}
  };
})();
