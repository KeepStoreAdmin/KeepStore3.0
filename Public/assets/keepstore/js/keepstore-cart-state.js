/* KeepStore server-backed cart awareness badges */
(function () {
  'use strict';

  function normalizeId(value) {
    var text = String(value || '').replace(/[^\d-]/g, '').trim();
    return text || '';
  }

  function normalizeTcid(value) {
    var parsed = parseInt(normalizeId(value || '-1') || '-1', 10);
    return (!isFinite(parsed) || parsed <= 0) ? '-1' : String(parsed);
  }

  function itemKey(id, tcid) {
    return normalizeId(id) + ':' + normalizeTcid(tcid);
  }

  function normalizeItems(items) {
    var map = {};
    (items || []).forEach(function (item) {
      if (!item) return;
      var id = normalizeId(item.id);
      if (!id || id === '0') return;

      var tcid = normalizeTcid(item.tcid);
      var qty = parseFloat(String(item.qty || '0').replace(',', '.'));
      if (!isFinite(qty) || qty <= 0) return;

      var key = itemKey(id, tcid);
      if (!map[key]) map[key] = { id: id, tcid: tcid, qty: 0, key: key };
      map[key].qty += qty;
    });
    return Object.keys(map).map(function (key) { return map[key]; });
  }

  function currentItems() {
    if (!window.KeepStoreCartState || !Array.isArray(window.KeepStoreCartState.items)) return [];
    return normalizeItems(window.KeepStoreCartState.items);
  }

  function findCartItem(items, id, tcid) {
    var idValue = normalizeId(id);
    var tcidValue = normalizeTcid(tcid);
    if (!idValue) return null;

    if (tcidValue !== '-1') {
      var exactKey = itemKey(idValue, tcidValue);
      for (var i = 0; i < items.length; i += 1) {
        if (items[i].key === exactKey) return items[i];
      }
      return null;
    }

    var articleQuantity = 0;
    for (var j = 0; j < items.length; j += 1) {
      if (items[j].id === idValue) articleQuantity += items[j].qty;
    }
    return articleQuantity > 0 ? { id: idValue, tcid: '-1', qty: articleQuantity, key: idValue + ':*' } : null;
  }

  function parseUrlParams(url) {
    var result = {};
    if (!url) return result;
    try {
      var anchor = document.createElement('a');
      anchor.href = url;
      (anchor.search || '').replace(/^\?/, '').split('&').forEach(function (part) {
        if (!part) return;
        var separator = part.indexOf('=');
        var key = decodeURIComponent(separator >= 0 ? part.substring(0, separator) : part);
        var value = decodeURIComponent(separator >= 0 ? part.substring(separator + 1) : '');
        result[key.toLowerCase()] = value;
      });
    } catch (e) {}
    return result;
  }

  function productFromNode(node) {
    if (!node) return null;
    var dataNode = node.matches && node.matches('[data-ks-id]') ? node : (node.querySelector ? node.querySelector('[data-ks-id]') : null);
    if (dataNode) {
      return {
        id: dataNode.getAttribute('data-ks-id'),
        tcid: dataNode.getAttribute('data-ks-tcid') || '-1'
      };
    }

    var productLink = node.querySelector ? node.querySelector('a[href*="articolo.aspx?id="]') : null;
    if (!productLink) return null;
    var query = parseUrlParams(productLink.getAttribute('href'));
    return { id: query.id, tcid: query.tcid || '-1' };
  }

  function formatQuantity(quantity) {
    if (Math.floor(quantity) === quantity) return String(quantity);
    return String(Math.round(quantity * 100) / 100).replace('.', ',');
  }

  function directChildContaining(parent, node) {
    var current = node;
    while (current && current.parentNode !== parent) current = current.parentNode;
    return current && current.parentNode === parent ? current : null;
  }

  function insertBeforeCardControls(target, awareness) {
    var control = target.querySelector('.ks-card-buy-cta,.ks-mobile-card-buy-cta,.ks-home-buy-cta,.ks-qty,input[type="checkbox"]');
    var directControl = control ? directChildContaining(target, control) : null;
    if (directControl) {
      target.insertBefore(awareness, directControl);
      return;
    }
    target.appendChild(awareness);
  }

  function ensureAwareness(target, item) {
    if (!target || !item || target.querySelector('.ks-cart-awareness')) return;
    var label = 'Nel carrello attivo: ' + formatQuantity(item.qty) + ' pz.';
    var awareness = document.createElement('span');
    awareness.className = 'ks-cart-awareness ks-cart-awareness--generated';
    awareness.setAttribute('title', label);
    awareness.setAttribute('aria-label', label);

    var icon = document.createElement('span');
    icon.className = 'ks-cart-awareness__icon icon-cart-2';
    icon.setAttribute('aria-hidden', 'true');

    var text = document.createElement('span');
    text.className = 'ks-cart-awareness__text';
    text.textContent = label;

    awareness.appendChild(icon);
    awareness.appendChild(text);
    insertBeforeCardControls(target, awareness);
  }

  function clearBadges() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-cart-awareness--generated,.ks-cart-state-badge,.ks-product-cart-state-badge')).forEach(function (badge) {
      if (badge && badge.parentNode) badge.parentNode.removeChild(badge);
    });
  }

  function decorateCards(items) {
    Array.prototype.slice.call(document.querySelectorAll('.card-product')).forEach(function (card) {
      var product = productFromNode(card);
      var item = product ? findCartItem(items, product.id, product.tcid) : null;
      if (!item) return;
      var target = card.querySelector('.box-infor-detail') || card.querySelector('.card-product-info') || card;
      ensureAwareness(target, item);
    });
  }

  function decorateBundle(items) {
    Array.prototype.slice.call(document.querySelectorAll('.card-usually')).forEach(function (card) {
      var product = productFromNode(card);
      var item = product ? findCartItem(items, product.id, product.tcid) : null;
      if (!item) return;
      var target = card.querySelector('.content .box-name') || card.querySelector('.content') || card;
      ensureAwareness(target, item);
    });
  }

  function decorate() {
    clearBadges();
    var items = currentItems();
    if (!items.length) return;
    decorateCards(items);
    decorateBundle(items);
  }

  function refreshBadges() {
    decorate();
    window.setTimeout(decorate, 50);
    window.setTimeout(decorate, 300);
  }

  function dismissToast(toast) {
    if (!toast || toast.classList.contains('is-dismissed')) return;
    toast.classList.add('is-dismissed');
    window.setTimeout(function () {
      toast.hidden = true;
    }, 220);
  }

  function initCartFeedbackToast() {
    var toast = document.querySelector('[data-ks-cart-feedback]');
    if (!toast) return;

    var close = toast.querySelector('[data-ks-cart-feedback-close]');
    if (close) {
      close.addEventListener('click', function () {
        dismissToast(toast);
      });
    }
    window.setTimeout(function () {
      dismissToast(toast);
    }, 5800);
  }

  var scrollStorageKey = 'KeepStore:CartReturnScroll';

  function currentPathAndQuery() {
    return window.location.pathname + window.location.search;
  }

  function saveCartReturnScroll(event) {
    if (event.button && event.button !== 0) return;
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    var trigger = event.target && event.target.closest ? event.target.closest('.js-ks-cart-link,.js-ks-cart-context') : null;
    if (!trigger) return;

    try {
      window.sessionStorage.setItem(scrollStorageKey, JSON.stringify({
        path: currentPathAndQuery(),
        y: Math.max(0, Math.round(window.scrollY || window.pageYOffset || 0)),
        created: Date.now()
      }));
    } catch (e) {}
  }

  function restoreCartReturnScroll() {
    var stored = null;
    try {
      stored = window.sessionStorage.getItem(scrollStorageKey);
      window.sessionStorage.removeItem(scrollStorageKey);
    } catch (e) {
      return;
    }
    if (!stored) return;

    try {
      var state = JSON.parse(stored);
      var age = Date.now() - Number(state.created || 0);
      var y = Number(state.y || 0);
      if (state.path !== currentPathAndQuery() || age < 0 || age > 120000 || !isFinite(y) || y < 0) return;

      window.setTimeout(function () {
        window.requestAnimationFrame(function () {
          window.scrollTo(0, y);
        });
      }, 60);
    } catch (e) {}
  }

  function initialize() {
    refreshBadges();
    initCartFeedbackToast();
  }

  document.addEventListener('click', saveCartReturnScroll, true);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
  } else {
    initialize();
  }
  window.addEventListener('pageshow', refreshBadges);
  window.addEventListener('load', function () {
    refreshBadges();
    restoreCartReturnScroll();
  });
  window.KeepStoreCartBadges = { refresh: refreshBadges };
})();
