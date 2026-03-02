(function () {
  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function toInt(v, def) {
    var n = parseInt(v, 10);
    return isNaN(n) ? def : n;
  }

  function ensureQtyEnhancement(scope) {
    scope = scope || document;

    var inputs = scope.querySelectorAll('input.ks-qty');
    for (var i = 0; i < inputs.length; i++) {
      var input = inputs[i];
      if (!input || input.getAttribute('data-ks-qty') === '1') continue;

      input.setAttribute('data-ks-qty', '1');
      input.setAttribute('inputmode', 'numeric');
      input.setAttribute('pattern', '[0-9]*');

      // Avoid double-wrapping
      if (input.parentElement && input.parentElement.classList.contains('ks-qty-wrap')) continue;

      var wrap = document.createElement('div');
      wrap.className = 'ks-qty-wrap';

      var btnMinus = document.createElement('button');
      btnMinus.type = 'button';
      btnMinus.className = 'ks-qty-btn ks-qty-minus';
      btnMinus.setAttribute('aria-label', 'Diminuisci quantità');
      btnMinus.innerHTML = '&minus;';

      var btnPlus = document.createElement('button');
      btnPlus.type = 'button';
      btnPlus.className = 'ks-qty-btn ks-qty-plus';
      btnPlus.setAttribute('aria-label', 'Aumenta quantità');
      btnPlus.innerHTML = '+';

      // Insert wrapper at input position
      var parent = input.parentNode;
      var next = input.nextSibling;
      parent.insertBefore(wrap, next);

      // Move input into wrapper
      wrap.appendChild(btnMinus);
      wrap.appendChild(input);
      wrap.appendChild(btnPlus);

      // Normalize initial value
      var start = toInt(input.value, 1);
      if (start <= 0) start = 1;
      input.value = String(start);

      function setQty(delta) {
        var cur = toInt(input.value, 1);
        cur = cur + delta;
        if (cur < 1) cur = 1;
        if (cur > 999) cur = 999;
        input.value = String(cur);

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
        var v = toInt(input.value, 1);
        if (v < 1) v = 1;
        if (v > 999) v = 999;
        input.value = String(v);
      });
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