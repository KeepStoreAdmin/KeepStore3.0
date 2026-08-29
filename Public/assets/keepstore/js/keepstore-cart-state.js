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

  function ensureBadge(target, item) {
    if (!target || !item || target.querySelector('.ks-cart-state-badge')) return;
    var label = 'Nel carrello: ' + formatQuantity(item.qty);
    var badge = document.createElement('span');
    badge.className = 'ks-cart-state-badge';
    badge.textContent = label;
    badge.setAttribute('title', label);
    badge.setAttribute('aria-label', label);
    target.insertBefore(badge, target.firstChild || null);
  }

  function clearBadges() {
    Array.prototype.slice.call(document.querySelectorAll('.ks-cart-state-badge,.ks-product-cart-state-badge')).forEach(function (badge) {
      if (badge && badge.parentNode) badge.parentNode.removeChild(badge);
    });
  }

  function decorateCards(items) {
    Array.prototype.slice.call(document.querySelectorAll('.card-product')).forEach(function (card) {
      if (card.closest('#ksCatalogPage')) return;
      var product = productFromNode(card);
      var item = product ? findCartItem(items, product.id, product.tcid) : null;
      if (!item) return;
      ensureBadge(card.querySelector('.card-product-wrapper') || card, item);
    });
  }

  function decorateBundle(items) {
    Array.prototype.slice.call(document.querySelectorAll('.card-usually')).forEach(function (card) {
      var product = productFromNode(card);
      var item = product ? findCartItem(items, product.id, product.tcid) : null;
      if (!item) return;
      ensureBadge(card.querySelector('.image') || card, item);
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

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', refreshBadges);
  } else {
    refreshBadges();
  }
  window.addEventListener('pageshow', refreshBadges);
  window.addEventListener('load', refreshBadges);
  window.KeepStoreCartBadges = { refresh: refreshBadges };
})();
