/* PDP-TOOLS-1A - strumenti della scheda prodotto: stampa, condivisione, copia dell'indirizzo.
   Senza questo script restano i collegamenti normali (il pannello "Condividi" e un details che si apre da solo).
   Nessuna chiamata di rete: lo script usa solo funzioni del browser. */
(function () {
  'use strict';

  var page = document.querySelector('.ks-product-page');
  if (!page) return;

  // ---- Stampa: i dettagli chiusi della scheda (garanzia, altre tariffe) si aprono per la stampa e poi tornano com'erano ----
  var openedForPrint = [];

  function openDetails() {
    var closed = page.querySelectorAll('details:not([open]):not([data-ks-pdp-share])');
    for (var i = 0; i < closed.length; i++) {
      closed[i].setAttribute('open', '');
      openedForPrint.push(closed[i]);
    }
    var share = page.querySelector('[data-ks-pdp-share][open]');
    if (share) share.removeAttribute('open');
  }

  function restoreDetails() {
    for (var i = 0; i < openedForPrint.length; i++) {
      openedForPrint[i].removeAttribute('open');
    }
    openedForPrint = [];
  }

  window.addEventListener('beforeprint', openDetails);
  window.addEventListener('afterprint', restoreDetails);

  var printButton = page.querySelector('[data-ks-pdp-print]');
  if (printButton) {
    printButton.addEventListener('click', function () {
      window.print();
    });
  }

  // ---- Condividi ----
  var share = page.querySelector('[data-ks-pdp-share]');
  if (!share) return;

  var summary = share.querySelector('summary');
  var urlField = share.querySelector('[data-ks-pdp-share-url]');
  var status = share.querySelector('[data-ks-pdp-share-status]');
  var copyButton = share.querySelector('[data-ks-pdp-copy]');
  var shareUrl = urlField ? urlField.value : '';
  var shareTitle = urlField ? (urlField.getAttribute('data-ks-share-title') || '') : '';

  function say(text) {
    if (status) status.textContent = text;
  }

  // Foglio di condivisione del dispositivo quando esiste; se l'utente lo chiude non succede nulla, se fallisce si apre l'elenco dei collegamenti.
  if (summary && shareUrl && typeof navigator.share === 'function') {
    summary.addEventListener('click', function (event) {
      if (share.hasAttribute('open')) return;
      event.preventDefault();
      navigator.share({ title: shareTitle, text: shareTitle, url: shareUrl }).catch(function (error) {
        if (error && error.name === 'AbortError') { return; }
        share.setAttribute('open', '');
      });
    });
  }

  // Copia riuscita = messaggio; copia non riuscita = il campo con l'indirizzo, gia selezionato, da copiare a mano. Mai un falso "copiato".
  function showManualCopy() {
    if (!urlField) return;
    urlField.hidden = false;
    urlField.removeAttribute('hidden');
    urlField.focus();
    urlField.select();
    say('Copia non riuscita: l\'indirizzo \u00e8 selezionato qui sopra, copialo dalla tastiera.');
  }

  function legacyCopy() {
    if (!urlField) return false;
    var wasHidden = urlField.hasAttribute('hidden');
    urlField.removeAttribute('hidden');
    urlField.select();
    var done = false;
    try { done = document.execCommand('copy'); } catch (e) { done = false; }
    if (done && wasHidden) urlField.setAttribute('hidden', 'hidden');
    return done;
  }

  if (copyButton) {
    copyButton.addEventListener('click', function () {
      if (!shareUrl) return;
      if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
        navigator.clipboard.writeText(shareUrl).then(function () {
          say('Link copiato.');
        }, function () {
          if (legacyCopy()) { say('Link copiato.'); } else { showManualCopy(); }
        });
        return;
      }
      if (legacyCopy()) { say('Link copiato.'); } else { showManualCopy(); }
    });
  }
}());
