(function () {
    'use strict';

    // Home hero slider (database-driven) - switched to Swiper for full theme alignment.
    // NOTE: kept isolated to Default.aspx (no globals, no inline handlers).

    function initHomeHeroSwiper() {
        var root = document.getElementById('Slide_Show');
        if (!root) return;

        // Swiper is loaded globally by Page.master (swiper-bundle.min.js)
        if (typeof window.Swiper === 'undefined') return;

        // NOTE: Slide_Show_Container is runat="server" and may have a generated ClientID.
        // We rely on a stable class selector instead of the raw id.
        var container = root.querySelector('.ks-home-hero-slider');
        if (!container) return;

        // Avoid double-init (can happen with partial postbacks or repeated script injection)
        if (container.swiper) return;

        var slides = container.querySelectorAll('.swiper-slide');
        if (!slides || slides.length === 0) return;

        var prevEl = container.querySelector('.ks-hero-prev');
        var nextEl = container.querySelector('.ks-hero-next');
        var paginationEl = container.querySelector('.ks-hero-pagination');

        var hasMultipleSlides = slides.length > 1;

        // Hide controls if there is only one slide
        if (!hasMultipleSlides) {
            if (prevEl) prevEl.style.display = 'none';
            if (nextEl) nextEl.style.display = 'none';
            if (paginationEl) paginationEl.style.display = 'none';
        }

        // eslint-disable-next-line no-new
        new window.Swiper(container, {
            slidesPerView: 1,
            spaceBetween: 0,
            speed: 800,
            loop: hasMultipleSlides,
            observer: true,
            observeParents: true,
            watchOverflow: true,
            autoplay: hasMultipleSlides
                ? {
                    delay: 6500,
                    disableOnInteraction: false,
                    pauseOnMouseEnter: true
                }
                : false,
            navigation: prevEl && nextEl
                ? {
                    prevEl: prevEl,
                    nextEl: nextEl
                }
                : undefined,
            pagination: paginationEl
                ? {
                    el: paginationEl,
                    clickable: true
                }
                : undefined,
            a11y: {
                enabled: true
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initHomeHeroSwiper);
    } else {
        initHomeHeroSwiper();
    }
})();