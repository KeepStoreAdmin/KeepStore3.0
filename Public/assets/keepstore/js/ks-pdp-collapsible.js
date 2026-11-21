/* KeepStore - sezioni lunghe della scheda prodotto a scomparsa su telefono (PDP-LAYOUT-ORDER-1A, linea di stile 3.6).
   Sotto i 768 px Descrizione, Informazioni prodotto e Recensioni (id prd-des, prd-infor, prd-review) ricevono DENTRO il titolo un
   <button type="button"> (aria-expanded, aria-controls) e il corpo chiuso prende l'attributo hidden. La prima sezione presente e aperta.
   Una sezione si apre anche da: collegamenti della pagina verso il suo id (indice, stelle in alto), frammento dell'indirizzo, esito di una recensione.
   Sopra i 768 px il documento torna identico a quello del server. Senza JavaScript e in stampa tutto resta aperto. */
(function () {
  'use strict';

  if (window.__ksPdpCollapsible || !window.matchMedia || !document.querySelector) { return; }
  var IDS = ['prd-des', 'prd-infor', 'prd-review'];
  var mq = window.matchMedia('(max-width: 767.98px)'); // stessa soglia di ks-pdp-collapsible.css
  var list = [];
  for (var n = 0; n < IDS.length; n++) {
    var section = document.getElementById(IDS[n]);
    var head = section ? section.querySelector('.ks-pdp-section__head') : null;
    var title = head ? head.querySelector('.ks-pdp-section__title') : null;
    var body = section ? section.querySelector('.ks-pdp-section__body') : null;
    if (section && head && title && body) { list.push({ id: IDS[n], section: section, title: title, body: body }); }
  }
  if (!list.length) { return; }
  window.__ksPdpCollapsible = true;

  var enhanced = false;
  var wasWide = false; // dopo un passaggio a schermo largo le sezioni non si richiudono da sole

  function toggleOf(p) { return p.title.querySelector('.ks-pdp-section__toggle'); }
  function byId(id) { for (var i = 0; i < list.length; i++) { if (list[i].id === id) { return list[i]; } } return null; }
  function hashId() { return String(window.location.hash || '').replace(/^#/, ''); }
  function isOpen(p) { return !p.body.hasAttribute('hidden'); }

  // L'indice della pagina (ks-pdp-sections.js) ricalcola posizioni e voce corrente quando arriva un resize.
  function notifyLayout() {
    try { window.dispatchEvent(new Event('resize')); } catch (e) { /* ricalcolo non essenziale */ }
  }

  function setOpen(p, open) {
    var button = toggleOf(p);
    if (!button) { return; }
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) { p.body.removeAttribute('hidden'); } else { p.body.setAttribute('hidden', ''); }
    p.section.classList.toggle('ks-pdp-section--closed', !open);
  }

  function open(p) {
    if (!p || !enhanced || isOpen(p)) { return; }
    setOpen(p, true);
    notifyLayout();
  }

  // Esito dell'invio di una recensione (successo, errore, duplicato): il server lo scrive in .ks-review-message.
  function outcomeOf(p) {
    var message = p.section.querySelector('.ks-review-message');
    return (message && String(message.textContent || '').replace(/\s+/g, '')) ? message : null;
  }

  function enhance() {
    if (enhanced) { return; }
    enhanced = true;
    var wanted = hashId();
    for (var i = 0; i < list.length; i++) {
      var p = list[i];
      var button = document.createElement('button');
      button.setAttribute('type', 'button'); // la scheda sta dentro il <form> della master: senza type sarebbe un invio
      button.className = 'ks-pdp-section__toggle';
      while (p.title.firstChild) { button.appendChild(p.title.firstChild); }
      var arrow = document.createElement('span');
      arrow.className = 'ks-pdp-section__arrow';
      arrow.setAttribute('aria-hidden', 'true');
      button.appendChild(arrow);
      p.title.appendChild(button);
      if (!p.body.id) { p.body.id = p.id + '-body'; p.body.setAttribute('data-ks-pdp-body-id', '1'); }
      button.setAttribute('aria-controls', p.body.id);
      p.section.classList.add('ks-pdp-section--collapsible');
      var startOpen = wasWide || i === 0 || p.id === wanted || !!outcomeOf(p) || p.body.contains(document.activeElement);
      setOpen(p, startOpen);
    }
  }

  function restore() {
    if (!enhanced) { return; }
    enhanced = false;
    wasWide = true;
    for (var i = 0; i < list.length; i++) {
      var p = list[i];
      var button = toggleOf(p);
      p.body.removeAttribute('hidden');
      p.section.classList.remove('ks-pdp-section--closed');
      p.section.classList.remove('ks-pdp-section--collapsible');
      if (p.body.getAttribute('data-ks-pdp-body-id')) { p.body.removeAttribute('id'); p.body.removeAttribute('data-ks-pdp-body-id'); }
      if (!button) { continue; }
      var hadFocus = (document.activeElement === button);
      var arrow = button.querySelector('.ks-pdp-section__arrow');
      if (arrow) { button.removeChild(arrow); }
      while (button.firstChild) { p.title.insertBefore(button.firstChild, button); }
      p.title.removeChild(button);
      if (hadFocus) { try { p.section.focus({ preventScroll: true }); } catch (e) { /* fuoco non essenziale */ } }
    }
  }

  function apply() {
    var active = document.activeElement;
    if (mq.matches) { enhance(); } else { restore(); }
    notifyLayout();
    // chi stava scrivendo (per esempio la recensione) non deve perdere di vista il campo quando la pagina cambia altezza
    if (active && active !== document.body && active.scrollIntoView && /^(INPUT|TEXTAREA|SELECT)$/.test(active.tagName)) {
      try { active.scrollIntoView({ block: 'center', behavior: 'instant' }); } catch (e) { /* non essenziale */ }
    }
  }

  // Pulsante del titolo: apre e chiude. Invio e Spazio sono quelli nativi del button.
  document.addEventListener('click', function (event) {
    if (!enhanced) { return; }
    var node = event.target;
    while (node && node !== document) {
      if (node.nodeType === 1 && node.classList && node.classList.contains('ks-pdp-section__toggle')) { break; }
      node = node.parentNode;
    }
    if (!node || node === document) { return; }
    for (var i = 0; i < list.length; i++) {
      if (toggleOf(list[i]) === node) { setOpen(list[i], !isOpen(list[i])); notifyLayout(); return; }
    }
  });

  // Collegamenti della pagina verso una sezione (indice, stelle in alto): la sezione si apre PRIMA che parta il salto.
  document.addEventListener('click', function (event) {
    if (!enhanced) { return; }
    var node = event.target;
    while (node && node !== document && !(node.nodeType === 1 && node.tagName === 'A')) { node = node.parentNode; }
    if (!node || node === document) { return; }
    var href = String(node.getAttribute('href') || '');
    if (href.charAt(0) !== '#') { return; }
    open(byId(href.slice(1)));
  }, true);

  window.addEventListener('hashchange', function () { open(byId(hashId())); });

  // Dopo l'invio di una recensione la pagina torna con l'esito: va portato in vista (la posizione salvata non conta le sezioni chiuse).
  function showOutcome() {
    var review = byId('prd-review');
    var message = review ? outcomeOf(review) : null;
    if (!message) { return; }
    open(review);
    if (!message.hasAttribute('tabindex')) { message.setAttribute('tabindex', '-1'); }
    // salto immediato: lo scorrimento animato del tema puo fermarsi a meta
    try { message.scrollIntoView({ block: 'center', behavior: 'instant' }); } catch (e) { /* non essenziale */ }
    try { message.focus({ preventScroll: true }); } catch (e2) { /* non essenziale */ }
  }
  // WebForms ripristina la posizione salvata dopo il caricamento: l'esito si porta in vista dopo quel ripristino.
  window.addEventListener('load', function () {
    window.setTimeout(showOutcome, 60);
    window.setTimeout(showOutcome, 450);
  });

  if (mq.addEventListener) { mq.addEventListener('change', apply); } else if (mq.addListener) { mq.addListener(apply); }
  if (mq.matches) { enhance(); notifyLayout(); }
}());
