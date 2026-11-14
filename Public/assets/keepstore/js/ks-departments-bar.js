/* KeepStore - barra dei reparti (desktop).
   Il CSS mostra una sola riga: i reparti che non entrano restano nascosti (sono nel menu "Catalogo" e dietro "Tutti i reparti").
   Qui si tolgono dalla tastiera e dagli screen reader gli elementi nascosti e si rimettono se la finestra si allarga.
   Se il focus e proprio su un elemento che sta per essere nascosto, passa a "Tutti i reparti" (sempre visibile).
   Senza JavaScript la barra funziona lo stesso: tutti i link restano raggiungibili e un link nascosto che riceve il focus scorre in vista. */
(function () {
  'use strict';

  var bar = document.getElementById('ksDepartmentsBar');
  if (!bar || !bar.querySelectorAll) { return; }
  var list = bar.querySelector('.ks-dept-list');
  var all = bar.querySelector('.ks-dept-all');
  var items = bar.querySelectorAll('.ks-dept-item');
  if (!list || !items.length) { return; }
  var timer = 0;

  function update() {
    var box = list.getBoundingClientRect();
    var active = document.activeElement;
    var lostFocus = false;
    for (var i = 0; i < items.length; i++) {
      var r = items[i].getBoundingClientRect();
      // nascosto se non sta per intero nella riga visibile (sotto o oltre il bordo)
      var clipped = r.bottom > box.bottom + 1 || r.right > box.right + 1;
      var link = items[i].querySelector('a');
      items[i].classList.toggle('is-clipped', clipped);
      if (clipped) {
        if (active && items[i].contains(active)) { lostFocus = true; }
        items[i].setAttribute('aria-hidden', 'true');
        if (link) { link.setAttribute('tabindex', '-1'); }
      } else {
        items[i].removeAttribute('aria-hidden');
        if (link) { link.removeAttribute('tabindex'); }
      }
    }
    if (lostFocus && all) { all.focus(); }
  }

  function schedule() {
    window.clearTimeout(timer);
    timer = window.setTimeout(update, 120);
  }

  update();
  window.addEventListener('resize', schedule);
  window.addEventListener('load', update);
  // la lista cambia larghezza anche senza un evento resize (zoom, font, layout): la si osserva direttamente
  if (window.ResizeObserver) { new window.ResizeObserver(schedule).observe(list); }
  if (document.fonts && document.fonts.ready) { document.fonts.ready.then(update); }
})();
