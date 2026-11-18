/* PDP-SECTIONS-RESTYLE-1A - indice delle sezioni della scheda prodotto.
   Senza questo script i link dell'indice restano normali ancore: lo script aggiunge solo (1) lo scarto giusto del salto quando
   l'intestazione del sito ricompare risalendo, (2) la voce corrente evidenziata, (3) la posizione dell'indice sotto l'intestazione. */
(function () {
  'use strict';

  var toc = document.querySelector('[data-ks-pdp-toc]');
  if (!toc) return;

  var header = document.querySelector('header');
  var list = toc.querySelector('.ks-pdp-toc__list');
  var links = Array.prototype.slice.call(toc.querySelectorAll('a[href^="#"]'));
  var entries = [];
  links.forEach(function (link) {
    var target = document.getElementById(link.getAttribute('href').slice(1));
    if (target) entries.push({ link: link, target: target });
  });
  if (!entries.length) return;

  var GAP = 12;

  function headerBottom() {
    if (!header) return 0;
    return Math.max(0, Math.round(header.getBoundingClientRect().bottom));
  }

  function headerHeight() {
    return header ? Math.round(header.offsetHeight) : 0;
  }

  function tocHeight() {
    return Math.round(toc.getBoundingClientRect().height);
  }

  function publishOffsets() {
    var root = document.documentElement;
    root.style.setProperty('--ks-pdp-header-offset', headerBottom() + 'px');
    root.style.setProperty('--ks-pdp-toc-height', tocHeight() + 'px');
  }

  function markCurrent() {
    // Corrente = l'ultima sezione il cui inizio ha superato la parte alta dello schermo (sotto intestazione e indice, o il 40% dell'altezza).
    var line = Math.max(headerBottom() + tocHeight() + GAP + 4, Math.round(window.innerHeight * 0.4));
    var current = null;
    entries.forEach(function (entry) {
      if (entry.target.getBoundingClientRect().top <= line) current = entry;
    });
    entries.forEach(function (entry) {
      if (entry === current) {
        if (entry.link.getAttribute('aria-current') !== 'true') {
          entry.link.setAttribute('aria-current', 'true');
          keepLinkVisible(entry.link);
        }
      } else {
        entry.link.removeAttribute('aria-current');
      }
    });
  }

  // L'indice scorre in orizzontale su telefono: la voce corrente resta visibile senza muovere la pagina.
  function keepLinkVisible(link) {
    if (!list || list.scrollWidth <= list.clientWidth) return;
    var left = link.offsetLeft - 16;
    var right = link.offsetLeft + link.offsetWidth + 16;
    if (left < list.scrollLeft) list.scrollLeft = left;
    else if (right > list.scrollLeft + list.clientWidth) list.scrollLeft = right - list.clientWidth;
  }

  // Salendo, l'intestazione del sito ricompare sopra l'indice: lo scarto del salto ne tiene conto, scendendo no.
  function jumpTo(entry) {
    var absoluteTop = entry.target.getBoundingClientRect().top + window.pageYOffset;
    var goingUp = absoluteTop < window.pageYOffset;
    var offset = tocHeight() + GAP + (goingUp ? headerHeight() : 0);
    var top = Math.max(0, Math.round(absoluteTop - offset));
    // Salto immediato: lo scorrimento animato del tema puo fermarsi a meta e lasciare il titolo fuori vista.
    try { window.scrollTo({ top: top, left: 0, behavior: 'instant' }); } catch (e) { window.scrollTo(0, top); }
    try { entry.target.focus({ preventScroll: true }); } catch (e) { /* focus non essenziale */ }
    if (window.history && typeof window.history.replaceState === 'function') {
      window.history.replaceState(null, '', '#' + entry.target.id);
    }
  }

  entries.forEach(function (entry) {
    entry.link.addEventListener('click', function (event) {
      if (event.defaultPrevented || event.button > 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      jumpTo(entry);
    });
  });

  var ticking = false;
  var settleUntil = 0;

  function refresh() {
    ticking = false;
    publishOffsets();
    markCurrent();
    if (Date.now() < settleUntil) schedule();
  }

  function schedule() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(refresh);
  }

  // L'intestazione cambia posizione con una transizione di 0,3 s decisa ogni 250 ms: si continua a misurare per poco dopo l'ultimo scorrimento.
  function onMove() {
    settleUntil = Date.now() + 700;
    schedule();
  }

  window.addEventListener('scroll', onMove, { passive: true });
  window.addEventListener('resize', onMove);
  if (header) header.addEventListener('transitionend', onMove);
  onMove();
}());
