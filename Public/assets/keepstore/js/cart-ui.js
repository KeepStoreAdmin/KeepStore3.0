// KeepStore UI: Qty stepper for cart page (no jQuery dependency)
(function () {
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
