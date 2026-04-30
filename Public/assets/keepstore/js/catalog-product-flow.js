(function () {
  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function toInt(v, def) {
    var n = parseInt(v, 10);
    return isNaN(n) ? def : n;
  }

  function normalizeQty(input) {
    var v = toInt(input.value, 1);
    if (v < 1) v = 1;
    if (v > 9999) v = 9999;
    input.value = String(v);
    return v;
  }

  function enhanceQtyInput(input) {
    if (!input || input.getAttribute('data-ks-qty') === '1') return;

    input.setAttribute('data-ks-qty', '1');
    input.setAttribute('inputmode', 'numeric');
    input.setAttribute('pattern', '[0-9]*');

    // Avoid double-wrapping
    if (input.parentElement && input.parentElement.classList.contains('ks-qty-wrap')) return;

    var wrap = document.createElement('div');
    wrap.className = 'ks-qty-wrap';

    var btnMinus = document.createElement('button');
    btnMinus.type = 'button';
    btnMinus.className = 'ks-qty-btn ks-qty-minus';
    btnMinus.setAttribute('aria-label', 'Diminuisci quantita');
    btnMinus.innerHTML = '&minus;';

    var btnPlus = document.createElement('button');
    btnPlus.type = 'button';
    btnPlus.className = 'ks-qty-btn ks-qty-plus';
    btnPlus.setAttribute('aria-label', 'Aumenta quantita');
    btnPlus.innerHTML = '+';

    // Insert wrapper at input position
    var parent = input.parentNode;
    var next = input.nextSibling;
    parent.insertBefore(wrap, next);

    // Move input into wrapper
    wrap.appendChild(btnMinus);
    wrap.appendChild(input);
    wrap.appendChild(btnPlus);

    normalizeQty(input);

    function setQty(delta) {
      input.value = String(normalizeQty(input) + delta);
      normalizeQty(input);

      // Trigger change/input (some pages might read it client-side)
      try { input.dispatchEvent(new Event('input', { bubbles: true })); } catch (e) {}
      try { input.dispatchEvent(new Event('change', { bubbles: true })); } catch (e) {}
    }

    btnMinus.addEventListener('click', function (ev) {
      ev.preventDefault();
      setQty(-1);
    });

    btnPlus.addEventListener('click', function (ev) {
      ev.preventDefault();
      setQty(1);
    });

    input.addEventListener('blur', function () {
      normalizeQty(input);
    });
  }

  function ensureQtyEnhancement(scope) {
    scope = scope || document;

    var inputs = scope.querySelectorAll('input.ks-qty');
    for (var i = 0; i < inputs.length; i++) {
      enhanceQtyInput(inputs[i]);
    }
  }

  // Re-run after UpdatePanel async postback (WebForms)
  function wireUpdatePanel() {
    try {
      if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
        var prm = Sys.WebForms.PageRequestManager.getInstance();
        if (prm) {
          prm.add_endRequest(function () { ensureQtyEnhancement(document); });
        }
      }
    } catch (e) {}
  }

  onReady(function () {
    ensureQtyEnhancement(document);
    wireUpdatePanel();
  });
})();
