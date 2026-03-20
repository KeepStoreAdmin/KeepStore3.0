(function () {
    function initHero() {
        var hero = document.querySelector('.ks-home-hero-slider');
        if (!hero || hero.swiper || typeof Swiper === 'undefined') return;
        var slides = hero.querySelectorAll('.swiper-slide');
        var allowLoop = slides.length > 1;
        var swiper = new Swiper(hero, {
            loop: allowLoop,
            effect: 'slide',
            speed: 700,
            autoplay: allowLoop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false,
            pagination: {
                el: hero.querySelector('.ks-hero-pagination'),
                clickable: true
            },
            navigation: {
                nextEl: hero.querySelector('.ks-hero-next'),
                prevEl: hero.querySelector('.ks-hero-prev')
            }
        });
        if (!allowLoop) {
            var prev = hero.querySelector('.ks-hero-prev');
            var next = hero.querySelector('.ks-hero-next');
            var pag = hero.querySelector('.ks-hero-pagination');
            if (prev) prev.style.display = 'none';
            if (next) next.style.display = 'none';
            if (pag) pag.style.display = 'none';
        }
    }

    function initBrandSlider() {
        var brand = document.querySelector('.ks-home-brands');
        if (!brand || brand.swiper || typeof Swiper === 'undefined') return;
        new Swiper(brand, {
            loop: brand.querySelectorAll('.swiper-slide').length > 2,
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

    document.addEventListener('DOMContentLoaded', function () {
        initHero();
        initBrandSlider();
    });
})();
