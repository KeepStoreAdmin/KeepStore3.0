/* KeepStore - sezioni del piede a fisarmonica (solo sotto i 768 px).
   Il CSS nasconde i pannelli (.tf-collapse-content) a <=767 px. Qui ogni titolo (h6.footer-heading-mobile) riceve DENTRO un <button type="button">
   (pattern Accordion del W3C APG: heading con un button, aria-expanded, aria-controls). Invio e Spazio sono quelli nativi del button e risalgono
   all'h6 come un clic: un solo ascoltatore delegato sul piede alterna la sezione, con il mouse o con la tastiera.
   A >=768 px (o se la finestra si allarga) il DOM torna IDENTICO a quello del server: nessun button, classe, stile, id o attributo ARIA aggiunto.
   Senza JavaScript il piede non cambia. Il vecchio gestore jQuery di main.js e stato tolto: un solo meccanismo. */
(function () {
  'use strict';

  if (window.__ksFooterAccordion) { return; } // script incluso due volte: un solo ascoltatore
  var footer = document.querySelector('footer.tf-footer');
  if (!footer || !footer.querySelectorAll || !window.matchMedia) { return; }
  window.__ksFooterAccordion = true;
  var mq = window.matchMedia('(max-width: 767px)'); // stesso limite del CSS (@media (max-width: 767px))
  var SLIDE_MS = 250;
  var lostFocus = null; // ultimo elemento del piede che ha perso il focus senza passarlo ad un altro: { el, at }

  footer.addEventListener('focusout', function (event) {
    lostFocus = event.relatedTarget ? null : { el: event.target, at: new Date().getTime() };
  });

  function sections() {
    var out = [];
    var blocks = footer.querySelectorAll('.footer-col-block');
    for (var i = 0; i < blocks.length; i++) {
      var heading = blocks[i].querySelector('.footer-heading-mobile');
      var panel = heading ? heading.nextElementSibling : null;
      if (heading && panel && panel.classList.contains('tf-collapse-content')) {
        out.push({ block: blocks[i], heading: heading, panel: panel, n: out.length + 1 });
      }
    }
    return out;
  }

  function toggleOf(heading) { return heading.querySelector('.ft-heading-toggle'); }

  function stopSlide(panel) {
    if (window.jQuery) { window.jQuery(panel).stop(true, true); }
  }

  function enhance(s) {
    if (toggleOf(s.heading)) { return; } // idempotente
    var button = document.createElement('button');
    button.setAttribute('type', 'button'); // il piede sta dentro il <form> della master: senza type sarebbe un submit
    button.className = 'ft-heading-toggle';
    while (s.heading.firstChild) { button.appendChild(s.heading.firstChild); }
    s.heading.appendChild(button);
    if (!s.panel.id) { s.panel.id = 'ks-footer-panel-' + s.n; s.panel.setAttribute('data-ks-footer-id', '1'); }
    button.setAttribute('aria-controls', s.panel.id);
    // il focus era dentro il pannello (finestra ristretta o zoom oltre il limite): la sezione resta aperta, senza animazione, e il focus non va perso.
    // Il browser puo avere gia tolto il focus al link (display:none) prima di avvisarci del cambio: lo si riconosce dal focusout di pochi ms prima.
    var lost = (lostFocus && (new Date().getTime() - lostFocus.at) < 300 && s.panel.contains(lostFocus.el)) ? lostFocus.el : null;
    var keepOpen = s.panel.contains(document.activeElement) || !!lost;
    if (keepOpen) { s.block.classList.add('open'); s.panel.style.display = 'block'; }
    button.setAttribute('aria-expanded', keepOpen ? 'true' : 'false');
    if (lost) { lostFocus = null; if (lost.focus) { lost.focus(); } }
  }

  function restore(s) {
    var button = toggleOf(s.heading);
    stopSlide(s.panel);
    s.block.classList.remove('open');
    s.panel.removeAttribute('style');
    if (s.panel.getAttribute('data-ks-footer-id')) { s.panel.removeAttribute('id'); s.panel.removeAttribute('data-ks-footer-id'); }
    if (!button) { return; }
    var hadFocus = (document.activeElement === button);
    while (button.firstChild) { s.heading.insertBefore(button.firstChild, button); }
    s.heading.removeChild(button);
    if (hadFocus) { // il button sparisce: il focus passa al primo link della sezione, ora sempre visibile, e non a body
      var first = s.panel.querySelector('a[href], button, input, select, textarea');
      if (first && first.focus) { first.focus(); }
    }
  }

  function apply() {
    var list = sections();
    for (var i = 0; i < list.length; i++) { if (mq.matches) { enhance(list[i]); } else { restore(list[i]); } }
  }

  footer.addEventListener('click', function (event) {
    if (!mq.matches) { return; }
    // il clic sull'icona (pseudo-elemento) ha come bersaglio l'h6: si risale fino al titolo, poi si cerca il button
    var node = event.target;
    var heading = null;
    while (node && node !== footer) {
      if (node.nodeType === 1 && node.classList.contains('footer-heading-mobile')) { heading = node; break; }
      node = node.parentNode;
    }
    if (!heading) { return; }
    var button = toggleOf(heading);
    var panel = heading.nextElementSibling;
    if (!button || !panel) { return; }
    var block = heading.parentNode;
    var open = !block.classList.contains('open');
    block.classList.toggle('open', open);
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (window.jQuery) {
      var $panel = window.jQuery(panel).stop(true, true);
      if (open) { $panel.slideDown(SLIDE_MS); } else { $panel.slideUp(SLIDE_MS); }
    } else {
      panel.style.display = open ? 'block' : 'none';
    }
  });

  if (mq.addEventListener) { mq.addEventListener('change', apply); } else if (mq.addListener) { mq.addListener(apply); }
  apply();
})();
