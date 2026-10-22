/* KeepStore MiniCart: native cart-set plus a verified, server-backed snapshot. */
(function () {
  'use strict';

  var canvas;
  var nativeForm;
  var status;
  var busy = false;
  var blocked = false;
  var generation = 0;
  var controller = null;
  var lockedControls = [];

  function quantity(value) {
    var text = String(value == null ? '' : value).trim();
    if (!/^[0-9]{1,4}$/.test(text)) return null;
    var number = Number(text);
    return number >= 1 && number <= 9999 ? number : null;
  }

  function identity(value, variant) {
    var text = String(value == null ? '' : value);
    if (variant && text === '-1') return text;
    if (!/^[1-9][0-9]*$/.test(text) || Number(text) > 2147483647) return null;
    return String(Number(text));
  }

  function showStatus(state, message) {
    if (!status) return;
    status.hidden = false;
    status.setAttribute('data-state', state);
    status.setAttribute('role', state === 'error' ? 'alert' : 'status');
    status.setAttribute('aria-live', state === 'error' ? 'assertive' : 'polite');
    status.textContent = message;
  }

  function lockControls() {
    var controls = canvas.querySelectorAll('button[form="ksNativeCartForm"],[data-ks-mini-quantity-input]');
    Array.prototype.forEach.call(controls, function (control) {
      lockedControls.push({ node: control, disabled: control.disabled });
      control.disabled = true;
    });
    canvas.setAttribute('aria-busy', 'true');
  }

  function unlockControls() {
    lockedControls.forEach(function (original) {
      if (original.node.isConnected) original.node.disabled = original.disabled;
    });
    lockedControls = [];
    canvas.removeAttribute('aria-busy');
    if (blocked) {
      Array.prototype.forEach.call(canvas.querySelectorAll('button[form="ksNativeCartForm"],[data-ks-mini-quantity-input]'), function (control) {
        control.disabled = true;
      });
    }
  }

  function sameOriginEndpoint(raw, filename) {
    try {
      var endpoint = new window.URL(raw, window.location.href);
      if (endpoint.origin !== window.location.origin || endpoint.search || endpoint.hash ||
          endpoint.username || endpoint.password ||
          endpoint.pathname.substring(endpoint.pathname.lastIndexOf('/') + 1).toLowerCase() !== filename) return null;
      return endpoint.href;
    } catch (ignore) { return null; }
  }

  function configuration() {
    var reconcile = document.getElementById('ksCartStateReconcile');
    var post = sameOriginEndpoint(nativeForm.getAttribute('action'), 'cart_add.aspx');
    var get = reconcile && sameOriginEndpoint(reconcile.getAttribute('data-ks-cart-state-endpoint'), 'cart_state_async.aspx');
    var csrfFields = nativeForm.querySelectorAll('input[name="csrfToken"]');
    if (!post || !get || nativeForm.method.toLowerCase() !== 'post' ||
        csrfFields.length !== 1 || !csrfFields[0].value) return null;
    var returnField = nativeForm.querySelector('input[name="ReturnUrl"]');
    return { post: post, get: get, csrf: csrfFields[0].value, returnUrl: returnField ? returnField.value : '' };
  }

  function targetFor(button) {
    var wrapper = button.closest('[data-ks-mini-quantity]');
    var input = wrapper && wrapper.querySelector('[data-ks-mini-quantity-input]');
    if (!wrapper || !input || input.form !== nativeForm || button.form !== nativeForm ||
        button.name !== 'ksCartAction' || !input.name ||
        !/^[A-Za-z0-9_$:-]{1,128}$/.test(input.name)) return null;
    var action = new window.URLSearchParams(button.value);
    var keys = ['id', 'tcid', 'qtyField', 'requestId', 'operation'];
    var keyCount = 0;
    action.forEach(function () { keyCount += 1; });
    if (keyCount !== keys.length || keys.some(function (key) { return action.getAll(key).length !== 1; }) ||
        action.get('operation') !== 'cart-set' || action.get('qtyField') !== input.name ||
        !/^(?:[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i.test(action.get('requestId'))) return null;
    var id = identity(action.get('id'), false);
    var tcid = identity(action.get('tcid'), true);
    var current = quantity(wrapper.getAttribute('data-ks-quantity'));
    if (!id || !tcid || current === null ||
        id !== identity(wrapper.getAttribute('data-ks-id'), false) ||
        tcid !== identity(wrapper.getAttribute('data-ks-tcid'), true)) return null;
    return { wrapper: wrapper, input: input, button: button, id: id, tcid: tcid,
      current: current, desired: quantity(input.value), action: button.value };
  }

  function viewState(target) {
    var body = canvas.querySelector('.offcanvas-body');
    var active = document.activeElement;
    return { scrollTop: body ? body.scrollTop : 0, scrollLeft: body ? body.scrollLeft : 0,
      active: active, inputFocused: active === target.input, buttonFocused: active === target.button };
  }

  function restoreView(view, target, restoreFocus) {
    var body = canvas.querySelector('.offcanvas-body');
    if (restoreFocus && canvas.classList.contains('show')) {
      var wrappers = canvas.querySelectorAll('[data-ks-mini-quantity]');
      var focus = null;
      for (var i = 0; i < wrappers.length; i += 1) {
        if (identity(wrappers[i].getAttribute('data-ks-id'), false) !== target.id ||
            identity(wrappers[i].getAttribute('data-ks-tcid'), true) !== target.tcid) continue;
        focus = wrappers[i].querySelector(view.inputFocused ? '[data-ks-mini-quantity-input]' : '[data-ks-mini-update]');
        break;
      }
      if (!focus || focus.disabled) focus = canvas.querySelector('[data-ks-cart-full-link]') || canvas.querySelector('[data-bs-dismiss="offcanvas"]');
      if (focus) {
        try { focus.focus({ preventScroll: true }); } catch (ignore) { focus.focus(); }
      }
    }
    if (body) { body.scrollTop = view.scrollTop; body.scrollLeft = view.scrollLeft; }
  }

  function requestedQuantityPresent(data, target) {
    if (!data || data.ok !== true || !data.cart || !Array.isArray(data.cart.items)) return false;
    var matches = data.cart.items.filter(function (item) {
      return item && identity(item.id, false) === target.id && identity(item.tcid, true) === target.tcid;
    });
    return matches.length === 1 && typeof matches[0].qty === 'number' && matches[0].qty === target.desired;
  }

  function request(endpoint, options, token, readBody) {
    controller = new window.AbortController();
    options.signal = controller.signal;
    var thisController = controller;
    var timer = window.setTimeout(function () { thisController.abort(); }, 10000);
    return window.fetch(endpoint, options).then(function (response) {
      if (token !== generation) throw new Error('Obsolete MiniCart request');
      return readBody ? readBody(response) : response;
    }).then(function (result) {
      window.clearTimeout(timer);
      return result;
    }, function (error) {
      window.clearTimeout(timer);
      throw error;
    });
  }

  function submit(button) {
    if (busy || blocked) return;
    var config = configuration();
    var target = targetFor(button);
    if (!config || !target) {
      blocked = true;
      showStatus('error', 'Aggiornamento non disponibile. Apri il carrello completo per verificare le quantità.');
      unlockControls();
      return;
    }
    if (target.desired === null) {
      target.input.setAttribute('aria-invalid', 'true');
      showStatus('error', 'Inserisci una quantità intera da 1 a 9999. Per eliminare l’articolo usa Rimuovi.');
      target.input.focus();
      return;
    }
    target.input.removeAttribute('aria-invalid');
    if (target.desired === target.current) {
      showStatus('idle', 'La quantità è già presente nel carrello.');
      return;
    }

    var view = viewState(target);
    var body = new window.URLSearchParams();
    body.set('csrfToken', config.csrf);
    body.set('ReturnUrl', config.returnUrl);
    body.set('ksCartAction', target.action);
    body.set(target.input.name, String(target.desired));
    var token = ++generation;
    busy = true;
    lockControls();
    showStatus('saving', 'Verifica della quantità in corso…');

    request(config.post, { method: 'POST', credentials: 'same-origin', cache: 'no-store', redirect: 'manual',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' }, body: body.toString() }, token)
      .then(function (response) {
        return { accepted: response.type === 'opaqueredirect' || response.status === 303,
          denied: response.status >= 400 && response.status < 500 };
      }, function () { return { accepted: false, denied: false }; })
      .then(function (outcome) {
        if (token !== generation) return;
        return request(config.get, { method: 'GET', credentials: 'same-origin', cache: 'no-store', redirect: 'error',
          headers: { Accept: 'application/json' } }, token, function (response) {
          if (!response.ok) throw new Error('MiniCart snapshot unavailable');
          return response.json();
        }).then(function (data) {
          if (token !== generation) return;
          var matches = requestedQuantityPresent(data, target);
          var active = document.activeElement;
          var restoreFocus = (view.inputFocused || view.buttonFocused) &&
            (active === view.active || active === document.body || active === canvas);
          if (!window.KeepStoreCartStateApi.applyAuthoritativeResponse(data)) throw new Error('Invalid MiniCart snapshot');
          // The snapshot supplies fresh native action IDs. No POST is retried here.
          blocked = !outcome.accepted || outcome.denied;
          busy = false;
          unlockControls();
          restoreView(view, target, restoreFocus);
          if (outcome.accepted && !outcome.denied && matches) {
            showStatus('saved', 'Quantità verificata nel carrello.');
          } else if (outcome.denied) {
            showStatus('error', 'Aggiornamento rifiutato. Apri il carrello completo per verificare prima di riprovare.');
          } else if (!outcome.accepted) {
            showStatus('error', 'Esito dell’aggiornamento non confermato. Apri il carrello completo per verificare prima di riprovare.');
          } else {
            showStatus('error', 'Quantità non aggiornata. Controlla la quantità mostrata o apri il carrello completo.');
          }
        });
      }).catch(function () {
        if (token !== generation) return;
        var active = document.activeElement;
        var restoreFocus = (view.inputFocused || view.buttonFocused) &&
          (active === view.active || active === document.body || active === canvas);
        blocked = true;
        busy = false;
        unlockControls();
        restoreView(view, target, restoreFocus);
        showStatus('error', 'Non è possibile confermare il carrello. Apri il carrello completo per verificare prima di riprovare.');
      });
  }

  function initialize() {
    canvas = document.getElementById('ksMiniCartCanvas');
    nativeForm = document.getElementById('ksNativeCartForm');
    status = canvas && canvas.querySelector('[data-ks-mini-quantity-status]');
    if (!canvas || !nativeForm || !status || typeof window.fetch !== 'function' ||
        typeof window.URL !== 'function' || typeof window.URLSearchParams !== 'function' ||
        typeof window.AbortController !== 'function' || !window.KeepStoreCartStateApi ||
        typeof window.KeepStoreCartStateApi.applyAuthoritativeResponse !== 'function') return;

    canvas.addEventListener('click', function (event) {
      var button = event.target && event.target.closest ? event.target.closest('[data-ks-mini-update]') : null;
      if (!button || !canvas.contains(button)) return;
      event.preventDefault();
      submit(button);
    });
    canvas.addEventListener('keydown', function (event) {
      if (event.key !== 'Enter' || !event.target.matches('[data-ks-mini-quantity-input]')) return;
      var wrapper = event.target.closest('[data-ks-mini-quantity]');
      var button = wrapper && wrapper.querySelector('[data-ks-mini-update]');
      if (!button) return;
      event.preventDefault();
      submit(button);
    });
    nativeForm.addEventListener('submit', function (event) {
      var button = event.submitter;
      if (button && canvas.contains(button) && button.matches('[data-ks-mini-update]')) {
        event.preventDefault();
        submit(button);
      } else if ((busy || blocked) && button && canvas.contains(button)) {
        event.preventDefault();
      }
    });
    window.addEventListener('pagehide', function () {
      generation += 1;
      if (controller) controller.abort();
      controller = null;
      if (busy) {
        busy = false;
        blocked = true;
        unlockControls();
        showStatus('error', 'Esito dell’aggiornamento non confermato. Apri il carrello completo per verificare prima di riprovare.');
      }
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
