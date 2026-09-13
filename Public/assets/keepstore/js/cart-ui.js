// KeepStore UI: Qty stepper for cart page (no jQuery dependency)
(function () {
    var cartPage = document.querySelector('.ks-cart-page');
    if (cartPage) {
        var refreshKey = 'KeepStore:cart-bfcache-refresh:' + window.location.pathname;
        window.addEventListener('pageshow', function (event) {
            if (!event.persisted && !(window.performance && window.performance.getEntriesByType &&
                window.performance.getEntriesByType('navigation')[0] &&
                window.performance.getEntriesByType('navigation')[0].type === 'back_forward')) return;
            if (window.sessionStorage && window.sessionStorage.getItem(refreshKey) === window.location.href) {
                window.sessionStorage.removeItem(refreshKey);
                return;
            }
            if (window.sessionStorage) window.sessionStorage.setItem(refreshKey, window.location.href);
            window.location.reload();
        });
    }

    function clamp(n, min, max) {
        if (isNaN(n)) return min;
        return Math.min(max, Math.max(min, n));
    }

    document.addEventListener("click", function (e) {
        if (!e.target || !e.target.closest) return;
        var btn = e.target.closest(".wg-quantity .btn-quantity");
        if (!btn) return;

        var wrap = btn.closest(".wg-quantity");
        if (!wrap) return;
        if (wrap.classList.contains("ks-wg-quantity")) return;
        if (wrap.classList.contains("ks-qty-locked") || wrap.getAttribute("data-ks-qty-locked") === "true" || wrap.getAttribute("aria-disabled") === "true") {
            e.preventDefault();
            e.stopPropagation();
            return;
        }

        var input = wrap.querySelector("input.quantity-product");
        if (!input || input.disabled || input.readOnly) return;

        var val = parseInt(input.value, 10);
        if (isNaN(val) || val <= 0) val = 1;

        if (btn.classList.contains("btn-increase")) {
            val++;
        } else if (btn.classList.contains("btn-decrease")) {
            val--;
        }

        input.value = clamp(val, 1, 9999);
    }, true);
})();
