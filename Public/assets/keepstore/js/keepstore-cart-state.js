/* KeepStore cart awareness badges */
(function () {
  'use strict';

  var STORAGE_KEY = 'ks_cart_products';

  function safeJson(value, fallback) {
    try { return JSON.parse(value); } catch (e) { return fallback; }
  }

  function readStorage() {
    try {
      var parsed = safeJson(localStorage.getItem(STORAGE_KEY) || '[]', []);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  function writeStorage(items) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(items || [])); } catch (e) {}
  }

  function normalizeId(value) {
    var s = String(value || '').replace(/[^\d-]/g, '').trim();
    return s || '';
  }

  function normalizeTcid(value) {
    var s = normalizeId(value || '-1') || '-1';
    var n = parseInt(s, 10);
    return (!isFinite(n) || n <= 0) ? '-1' : String(n);
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
      var qty = parseFloat(String(item.qty || '1').replace(',', '.'));
      if (!isFinite(qty) || qty <= 0) qty = 1;
      map[itemKey(id, tcid)] = { id: id, tcid: tcid, qty: qty, key: itemKey(id, tcid) };
    });
    return Object.keys(map).map(function (key) { return map[key]; });
  }

  function serverItems() {
    return normalizeItems(window.KeepStoreCartState && window.KeepStoreCartState.items ? window.KeepStoreCartState.items : []);
  }

  function currentItems() {
    var fromServer = serverItems();
    if (fromServer.length) {
      writeStorage(fromServer);
      return fromServer;
    }
    return normalizeItems(readStorage());
  }

  function findCartItem(id, tcid) {
    var idVal = normalizeId(id);
    var tcVal = normalizeTcid(tcid);
    if (!idVal) return null;
    var items = currentItems();
    var exact = itemKey(idVal, tcVal);
    for (var i = 0; i < items.length; i += 1) {
      if (items[i].key === exact) return items[i];
    }
    for (var j = 0; j < items.length; j += 1) {
      if (items[j].id === idVal) return items[j];
    }
    return null;
  }

  function parseUrlParams(url) {
    var result = {};
    if (!url) return result;
    try {
      var a = document.createElement('a');
      a.href = url;
      var q = (a.search || '').replace(/^\?/, '').split('&');
      q.forEach(function (part) {
        if (!part) return;
        var idx = part.indexOf('=');
        var key = decodeURIComponent(idx >= 0 ? part.substring(0, idx) : part);
        var val = decodeURIComponent(idx >= 0 ? part.substring(idx + 1) : '');
        result[key.toLowerCase()] = val;
      });
    } catch (e) {}
    return result;
  }

  function productFromNode(node) {
    if (!node) return null;
    var data = node.matches && node.matches('[data-ks-id]') ? node : (node.querySelector ? node.querySelector('[data-ks-id]') : null);
    if (data) {
      return { id: data.getAttribute('data-ks-id'), tcid: data.getAttribute('data-ks-tcid') || '-1' };
    }

    var link = node.querySelector ? node.querySelector('a[href*="articolo.aspx?id="]') : null;
    if (!link) return null;
    var qs = parseUrlParams(link.getAttribute('href'));
    return { id: qs.id, tcid: qs.tcid || '-1' };
  }

  function ensureBadge(target, item) {
    if (!target || !item || target.querySelector('.ks-cart-state-badge')) return;
    var badge = document.createElement('span');
    badge.className = 'ks-cart-state-badge';
    badge.textContent = item.qty > 1 ? 'Nel carrello' : 'Nel carrello';
    target.insertBefore(badge, target.firstChild || null);
  }

  function decorateCards() {
    Array.prototype.slice.call(document.querySelectorAll('.card-product')).forEach(function (card) {
      var product = productFromNode(card);
      if (!product) return;
      var item = findCartItem(product.id, product.tcid);
      if (!item) return;
      var wrapper = card.querySelector('.card-product-wrapper') || card;
      ensureBadge(wrapper, item);
    });

    var title = document.querySelector('.tf-product-info-name');
    if (title) {
      var qs = parseUrlParams(window.location.href);
      var current = findCartItem(qs.id, qs.tcid || '-1');
      if (current && !document.querySelector('.ks-product-cart-state-badge')) {
        var b = document.createElement('span');
        b.className = 'ks-product-cart-state-badge';
        b.textContent = 'Nel carrello';
        title.insertAdjacentElement('afterend', b);
      }
    }
  }

  function rememberClickedCart(link) {
    var product = productFromNode(link);
    if (!product || !product.id) {
      var qs = parseUrlParams(link.getAttribute('href'));
      product = { id: qs.id, tcid: qs.tcid || '-1' };
    }
    if (!product.id) return;

    var list = normalizeItems(readStorage());
    var key = itemKey(product.id, product.tcid || '-1');
    var found = false;
    list.forEach(function (item) {
      if (item.key === key) {
        item.qty = Math.max(1, item.qty || 1);
        found = true;
      }
    });
    if (!found) list.unshift({ id: normalizeId(product.id), tcid: normalizeId(product.tcid || '-1') || '-1', qty: 1, key: key });
    writeStorage(list.slice(0, 80));
  }

  document.addEventListener('click', function (ev) {
    var link = ev.target && ev.target.closest ? ev.target.closest('.js-ks-cart-link,a[href*="cart_add.aspx"],a[href*="aggiungi.aspx?id="]') : null;
    if (link) rememberClickedCart(link);
  }, true);

  document.addEventListener('DOMContentLoaded', decorateCards);
  window.KeepStoreCartBadges = { refresh: decorateCards };
})();
