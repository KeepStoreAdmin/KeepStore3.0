(function () {
    function buildSwiper(root, options) {
        if (!root || root.swiper || typeof Swiper === 'undefined') return null;
        return new Swiper(root, options);
    }

    function hideNode(node) {
        if (node) node.style.display = 'none';
    }

    function initHero() {
        var hero = document.querySelector('.ks-home-hero-slider');
        if (!hero) return;
        var slides = hero.querySelectorAll('.swiper-slide');
        var allowLoop = slides.length > 1;
        var prev = hero.querySelector('.ks-hero-prev');
        var next = hero.querySelector('.ks-hero-next');
        var pag = hero.querySelector('.ks-hero-pagination');
        buildSwiper(hero, {
            loop: allowLoop,
            effect: 'slide',
            speed: 700,
            autoplay: allowLoop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false,
            pagination: { el: pag, clickable: true },
            navigation: { nextEl: next, prevEl: prev }
        });
        if (!allowLoop) {
            hideNode(prev);
            hideNode(next);
            hideNode(pag);
        }
    }

    function initBrandSlider() {
        var brand = document.querySelector('.ks-home-brands');
        if (!brand) return;
        buildSwiper(brand, {
            loop: brand.querySelectorAll('.swiper-slide').length > 6,
            slidesPerView: 2,
            spaceBetween: 15,
            breakpoints: {
                576: { slidesPerView: 3, spaceBetween: 15 },
                768: { slidesPerView: 4, spaceBetween: 20 },
                1200: { slidesPerView: 6, spaceBetween: 30 }
            },
            pagination: {
                el: brand.querySelector('.ks-home-brands-pagination'),
                clickable: true
            },
            autoplay: { delay: 3500, disableOnInteraction: false }
        });
    }

    function initCollectionSlider() {
        var slider = document.querySelector('.ks-home-collection-swiper');
        if (!slider) return;
        buildSwiper(slider, {
            loop: slider.querySelectorAll('.swiper-slide').length > 4,
            slidesPerView: 1,
            spaceBetween: 15,
            breakpoints: {
                576: { slidesPerView: 2, spaceBetween: 15 },
                768: { slidesPerView: 3, spaceBetween: 20 },
                1200: { slidesPerView: 4, spaceBetween: 30 }
            },
            pagination: {
                el: slider.querySelector('.ks-home-collection-pagination'),
                clickable: true
            },
            autoplay: { delay: 4000, disableOnInteraction: false }
        });
    }

    function initColumnSwipers() {
        var swipers = document.querySelectorAll('.ks-column-swiper');
        swipers.forEach(function (el) {
            if (!el || el.swiper || typeof Swiper === 'undefined') return;
            var wrapper = el.closest('.box-btn-slide-item') || el.parentElement;
            var prev = wrapper ? wrapper.querySelector('.ks-col-prev') : null;
            var next = wrapper ? wrapper.querySelector('.ks-col-next') : null;
            var pag = el.querySelector('.ks-col-pagination');
            var slides = el.querySelectorAll('.swiper-slide').length;
            buildSwiper(el, {
                loop: slides > 1,
                slidesPerView: 1,
                spaceBetween: 20,
                pagination: { el: pag, clickable: true },
                navigation: { nextEl: next, prevEl: prev },
                autoplay: slides > 1 ? { delay: 4500, disableOnInteraction: false } : false
            });
            if (slides <= 1) {
                hideNode(prev);
                hideNode(next);
                hideNode(pag);
            }
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        initHero();
        initBrandSlider();
        initCollectionSlider();
        initColumnSwipers();
    });
})();
