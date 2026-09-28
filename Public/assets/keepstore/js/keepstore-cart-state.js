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

  function findExactCartItem(items, id, tcid) {
    var key = itemKey(id, tcid);
    for (var i = 0; i < items.length; i += 1) {
      if (items[i].key === key) return items[i];
    }
    return null;
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

  function validatedCartResponse(data) {
    if (!data || data.ok !== true || !data.cart || !Array.isArray(data.cart.items) ||
        typeof data.cart.count !== 'number' || !isFinite(data.cart.count) ||
        data.cart.count < 0 || Math.floor(data.cart.count) !== data.cart.count ||
        typeof data.miniCartHtml !== 'string' || !data.miniCartHtml) return null;

    var items = data.cart.items;
    if (items.length > 10000) return null;
    var total = 0;
    for (var i = 0; i < items.length; i += 1) {
      var item = items[i];
      if (!item || !/^\d+$/.test(String(item.id)) || Number(item.id) <= 0 ||
          !/^(?:-1|[1-9]\d*)$/.test(String(item.tcid)) ||
          typeof item.qty !== 'number' || !isFinite(item.qty) || item.qty <= 0) return null;
      total += item.qty;
    }
    if (Math.floor(total + 0.0000001) !== data.cart.count) return null;

    var holder = document.createElement('div');
    holder.innerHTML = data.miniCartHtml;
    var source = holder.querySelector('#ksMiniCartCanvas .ks-mini-cart-content');
    var targetCanvas = document.getElementById('ksMiniCartCanvas');
    var target = targetCanvas ? targetCanvas.querySelector('.ks-mini-cart-content') : null;
    if (!source || !target || !source.querySelector('.offcanvas-body')) return null;
    if (data.cart.count > 0 && !source.querySelector('.ks-mini-cart-footer')) return null;

    return { items: normalizeItems(items), count: data.cart.count, html: source.innerHTML, target: target };
  }

  function reconcileCardQuantities(items) {
    Array.prototype.slice.call(document.querySelectorAll('.card-product')).forEach(function (card) {
      var product = productFromNode(card);
      if (!product) return;
      var purchaseLinks = card.querySelectorAll('.js-ks-cart-link');
      var inputs = card.querySelectorAll('input.ks-qty');
      if (!purchaseLinks.length && !inputs.length) return;

      var exact = findExactCartItem(items, product.id, product.tcid);
      var quantity = exact ? exact.qty : 0;
      var quantityText = quantity > 0 ? formatQuantity(quantity) : '';
      card.classList.toggle('ks-card-in-cart', quantity > 0);

      Array.prototype.slice.call(purchaseLinks).forEach(function (link) {
        if (quantity > 0) link.setAttribute('data-ks-existing-cart-qty', quantityText);
        else link.removeAttribute('data-ks-existing-cart-qty');
      });
      Array.prototype.slice.call(inputs).forEach(function (input) {
        if (input.disabled) return;
        input.value = quantity > 0 ? quantityText : '1';
        if (quantity > 0) input.setAttribute('data-ks-existing-cart-qty', quantityText);
        else input.removeAttribute('data-ks-existing-cart-qty');
        input.classList.toggle('ks-cart-qty-input-present', quantity > 0);

        var wrapper = input.closest ? input.closest('.ks-qty-wrap,.ks-catalog-card-actions,.ks-card-purchase-actions') : null;
        if (!wrapper) wrapper = input.parentElement;
        if (!wrapper) return;
        wrapper.classList.toggle('ks-cart-qty-present', quantity > 0);
        if (quantity > 0) {
          wrapper.setAttribute('title', 'Nel carrello: ' + quantityText);
          wrapper.setAttribute('aria-label', 'Nel carrello: ' + quantityText);
        } else {
          wrapper.removeAttribute('title');
          wrapper.removeAttribute('aria-label');
        }
      });
    });
  }

  function reconcilePdp(items) {
    var panel = document.querySelector('[data-ks-pdp-cart-state]');
    if (!panel) return;
    var id = panel.getAttribute('data-ks-id');
    var tcid = panel.getAttribute('data-ks-tcid') || '-1';
    var item = findExactCartItem(items, id, tcid);
    var quantity = item ? Math.min(9999, Math.floor(item.qty)) : 0;
    var quantityNode = panel.querySelector('[data-ks-pdp-cart-qty]');
    if (!quantityNode) return;
    var input = document.querySelector('.product-quantity input.quantity-product');
    if (quantity > 0) {
      var quantityText = formatQuantity(quantity);
      var label = 'Nel carrello attivo: ' + quantityText + ' pz.';
      quantityNode.textContent = quantityText;
      panel.hidden = false;
      panel.style.display = '';
      panel.setAttribute('title', label);
      panel.setAttribute('aria-label', label);
      if (input) input.value = String(quantity);
    } else {
      quantityNode.textContent = '';
      panel.hidden = true;
      panel.style.display = 'none';
      panel.removeAttribute('title');
      panel.removeAttribute('aria-label');
      if (input) input.value = '1';
    }
  }

  function applyCartResponse(validated) {
    validated.target.innerHTML = validated.html;
    window.KeepStoreCartState = { items: validated.items };
    Array.prototype.slice.call(document.querySelectorAll('[data-ks-cart-count]')).forEach(function (node) {
      node.textContent = String(validated.count);
    });
    Array.prototype.slice.call(document.querySelectorAll('[data-bs-target="#ksMiniCartCanvas"]')).forEach(function (link) {
      link.setAttribute('aria-label', 'Apri carrello, ' + validated.count + ' articoli');
    });
    reconcileCardQuantities(validated.items);
    reconcilePdp(validated.items);
    refreshBadges();
  }

  var reconcileGeneration = 0;
  var reconcileController = null;
  var reconcilePending = false;

  function reloadGuardKey() {
    return 'KeepStore:cart-history-reload:' + window.location.pathname + window.location.search;
  }

  function clearReloadGuard() {
    try { window.sessionStorage.removeItem(reloadGuardKey()); } catch (ignore) {}
  }

  function reloadOnce() {
    try {
      if (window.sessionStorage.getItem(reloadGuardKey()) === window.location.href) return;
      window.sessionStorage.setItem(reloadGuardKey(), window.location.href);
    } catch (ignore) {}
    window.location.reload();
  }

  function historyRestored(event) {
    if (event && event.persisted) return true;
    try {
      var entries = window.performance && window.performance.getEntriesByType ?
        window.performance.getEntriesByType('navigation') : [];
      return !!(entries && entries[0] && entries[0].type === 'back_forward');
    } catch (ignore) {
      return false;
    }
  }

  function reconcileHistory(event) {
    if (!historyRestored(event) || document.querySelector('.ks-cart-page') || reconcilePending) return;
    var config = document.getElementById('ksCartStateReconcile');
    var endpoint = config ? config.getAttribute('data-ks-cart-state-endpoint') : '';
    if (!endpoint || typeof window.fetch !== 'function') {
      reloadOnce();
      return;
    }

    var startingState = window.KeepStoreCartState;
    var generation = ++reconcileGeneration;
    reconcilePending = true;
    reconcileController = typeof window.AbortController === 'function' ? new window.AbortController() : null;
    var timedOut = false;
    var timeoutId = window.setTimeout(function () {
      if (generation !== reconcileGeneration || !reconcilePending) return;
      timedOut = true;
      if (reconcileController) {
        reconcileController.abort();
      } else {
        reconcileGeneration += 1;
        reconcilePending = false;
        if (window.KeepStoreCartState === startingState) reloadOnce();
      }
    }, 10000);
    var options = { method: 'GET', credentials: 'same-origin', cache: 'no-store', headers: { Accept: 'application/json' } };
    if (reconcileController) options.signal = reconcileController.signal;

    window.fetch(endpoint, options).then(function (response) {
      if (!response.ok) throw new Error('Cart state unavailable');
      return response.json();
    }).then(function (data) {
      if (generation !== reconcileGeneration) return;
      if (window.KeepStoreCartState !== startingState) {
        clearReloadGuard();
        return;
      }
      var validated = validatedCartResponse(data);
      if (!validated) throw new Error('Invalid cart state');
      applyCartResponse(validated);
      clearReloadGuard();
    }).catch(function (error) {
      if (generation !== reconcileGeneration || (error && error.name === 'AbortError' && !timedOut)) return;
      if (window.KeepStoreCartState !== startingState) {
        clearReloadGuard();
        return;
      }
      reloadOnce();
    }).then(function () {
      if (window.clearTimeout) window.clearTimeout(timeoutId);
      if (generation !== reconcileGeneration) return;
      reconcilePending = false;
      reconcileController = null;
    });
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

    var returnPath = currentPathAndQuery();
    try {
      window.sessionStorage.setItem(scrollStorageKey, JSON.stringify({
        path: returnPath,
        y: Math.max(0, Math.round(window.scrollY || window.pageYOffset || 0))
      }));
    } catch (e) {}

    if (trigger.hasAttribute('data-ks-cart-full-link')) {
      trigger.setAttribute('href', '/carrello.aspx?ReturnUrl=' + encodeURIComponent(returnPath));
    }
  }

  function removeCartReturnScroll() {
    try {
      window.sessionStorage.removeItem(scrollStorageKey);
    } catch (e) {}
  }

  function restoreCartReturnScroll() {
    var stored = null;
    try {
      stored = window.sessionStorage.getItem(scrollStorageKey);
    } catch (e) {
      return;
    }
    if (!stored) return;

    try {
      var state = JSON.parse(stored);
      var path = state && state.path;
      var y = Number(state && state.y);
      if (typeof path !== 'string' || path.charAt(0) !== '/' || path.indexOf('//') === 0 ||
          /[\\\r\n\0]/.test(path) || !isFinite(y) || y < 0) {
        removeCartReturnScroll();
        return;
      }
      if (path !== currentPathAndQuery()) return;

      window.setTimeout(function () {
        window.requestAnimationFrame(function () {
          if (path !== currentPathAndQuery()) return;
          window.scrollTo(0, y);
          removeCartReturnScroll();
        });
      }, 60);
    } catch (e) {
      removeCartReturnScroll();
    }
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
  window.addEventListener('pageshow', function (event) {
    if (historyRestored(event)) {
      reconcileHistory(event);
    } else {
      clearReloadGuard();
      refreshBadges();
    }
  });
  window.addEventListener('pagehide', function () {
    reconcileGeneration += 1;
    reconcilePending = false;
    if (reconcileController) reconcileController.abort();
    reconcileController = null;
  });
  window.addEventListener('load', function () {
    refreshBadges();
    restoreCartReturnScroll();
  });
  window.KeepStoreCartBadges = { refresh: refreshBadges };
})();
