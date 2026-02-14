/* KeepStore init - fail-safe
   Non deve lanciare eccezioni se alcune librerie non sono presenti su una pagina.
*/
(function (w) {
  'use strict';

  function safe(fn) {
    try { fn(); } catch (e) { /* no-op */ }
  }

  w.keepStoreInit = function () {
    // hook globale futuro
  };

  w.keepStoreShopInit = function () {
    // hook shop/listing futuro
  };

  w.keepStoreProductInit = function () {
    // hook product future
  };

  // Auto-init base
  safe(function () { w.keepStoreInit && w.keepStoreInit(); });
})(window);
