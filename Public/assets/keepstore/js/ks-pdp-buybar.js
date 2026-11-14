/* KeepStore - barra fissa di acquisto sulla scheda articolo (telefono e tablet).
   La barra mostra il prezzo (copiato da quello gia mostrato nel riquadro di acquisto, con la sua dicitura, solo visualizzazione)
   e un pulsante "Acquista" che NON costruisce nessuna azione di carrello: preme il pulsante principale della pagina, quindi
   payload, quantita corrente, identificativo di idempotenza e gestori restano quelli del pulsante principale.
   Compare solo quando il pulsante principale non e nel viewport. Senza JavaScript non c'e nessuna barra.
   Il blocco del doppio tocco e della barra stessa (1,5 s); la protezione del server e l'idempotenza della richiesta. */
(function () {
  'use strict';

  var main = document.getElementById('MainContent_btnAddToCart');
  if (!main || !window.matchMedia) { return; }

  var narrow = window.matchMedia('(max-width: 1199.98px)');
  var bar = null;
  var cta = null;
  var priceEl = null;
  var noteEl = null;
  var cooldown = 0;
  var lastHeight = -1;

  function clean(node) {
    return node ? node.textContent.replace(/\s+/g, ' ').trim() : '';
  }

  function priceInfo() {
    var box = document.querySelector('.ks-pdp-buybox-sticky .product-delivery');
    if (!box) { return { price: '', note: '' }; }
    var price = box.querySelector('.new-price') || box.querySelector('.price-text');
    var note = box.querySelector('.price-text + p.body-text-3');
    return { price: clean(price), note: clean(note) };
  }

  function setText(el, text) {
    if (el.textContent !== text) { el.textContent = text; }
    el.hidden = text === '';
  }

  function mainUsable() {
    return !main.disabled && main.getAttribute('aria-disabled') !== 'true' && !main.classList.contains('disabled');
  }

  function release() {
    cooldown = 0;
    if (cta) {
      cta.disabled = false;
      cta.removeAttribute('aria-busy');
    }
  }

  function build() {
    bar = document.createElement('div');
    bar.id = 'ksPdpBuyBar';
    bar.className = 'ks-pdp-buybar';
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', 'Acquisto rapido');
    bar.hidden = true;

    var summary = document.createElement('div');
    summary.className = 'ks-pdp-buybar__summary';
    priceEl = document.createElement('span');
    priceEl.className = 'ks-pdp-buybar__price';
    noteEl = document.createElement('span');
    noteEl.className = 'ks-pdp-buybar__note';
    summary.appendChild(priceEl);
    summary.appendChild(noteEl);

    cta = document.createElement('button');
    cta.type = 'button';
    cta.className = 'ks-pdp-buybar__cta';
    cta.textContent = 'Acquista';
    cta.setAttribute('aria-label', 'Acquista: aggiungi al carrello');

    bar.appendChild(summary);
    bar.appendChild(cta);
    document.body.appendChild(bar);

    cta.addEventListener('click', function () {
      if (cooldown) { return; }
      // ricontrollo subito prima di agire: il pulsante principale puo essere cambiato dopo l'ultimo aggiornamento
      if (!narrow.matches || !mainUsable()) { update(); return; }
      cta.disabled = true;
      cta.setAttribute('aria-busy', 'true');
      cooldown = window.setTimeout(release, 1500);
      main.click();
    });
  }

  function mainInView() {
    var r = main.getBoundingClientRect();
    var vh = window.innerHeight || document.documentElement.clientHeight;
    return r.bottom > 0 && r.top < vh;
  }

  // l'altezza reale della barra guida lo spazio in fondo pagina e la posizione del messaggio di conferma del carrello
  function syncHeight() {
    var h = bar.offsetHeight;
    if (h !== lastHeight) {
      lastHeight = h;
      document.documentElement.style.setProperty('--ks-pdp-buybar-h', h + 'px');
    }
  }

  function update() {
    var show = narrow.matches && mainUsable() && main.getClientRects().length > 0 && !mainInView();
    if (show && !bar) { build(); }
    if (!bar) { return; }
    if (show) {
      var info = priceInfo();
      setText(priceEl, info.price);
      setText(noteEl, info.note);
    }
    if (show === !bar.hidden) {
      if (show) { syncHeight(); }
      return;
    }
    if (!show && bar.contains(document.activeElement)) {
      if (mainUsable()) { main.focus({ preventScroll: true }); } else { document.activeElement.blur(); }
    }
    bar.hidden = !show;
    document.body.classList.toggle('ks-pdp-buybar-on', show);
    if (show) { syncHeight(); }
  }

  window.addEventListener('scroll', update, { passive: true });
  window.addEventListener('resize', update);
  window.addEventListener('orientationchange', update);
  window.addEventListener('load', update);
  window.addEventListener('pageshow', function () { release(); update(); });
  if (window.visualViewport) { window.visualViewport.addEventListener('resize', update); }
  if (narrow.addEventListener) { narrow.addEventListener('change', update); }
  if (window.MutationObserver) {
    new window.MutationObserver(update).observe(main, { attributes: true, attributeFilter: ['disabled', 'aria-disabled', 'class'] });
  }
  update();
})();
