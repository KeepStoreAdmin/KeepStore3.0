(function () {
    'use strict';

    // Home page legacy slideshow (database-driven) integrated into the new UI.
    // NOTE: kept isolated to avoid global functions / inline handlers.

    function initHomeSlideshow() {
        var root = document.getElementById('Slide_Show');
        if (!root) return;

        var container = root.querySelector('.slideshow-container');
        if (!container) return;

        var slides = container.getElementsByClassName('mySlides');
        var dots = root.getElementsByClassName('dot');

        var prevBtn = container.querySelector('[data-slide-action="prev"]');
        var nextBtn = container.querySelector('[data-slide-action="next"]');

        var slideIndex = 1;

        function showSlides(n) {
            if (!slides || slides.length === 0) return;

            if (n > slides.length) slideIndex = 1;
            if (n < 1) slideIndex = slides.length;

            for (var i = 0; i < slides.length; i++) {
                slides[i].style.display = 'none';
            }

            for (var j = 0; j < dots.length; j++) {
                dots[j].className = dots[j].className.replace(' active', '');
            }

            slides[slideIndex - 1].style.display = 'block';

            if (dots.length >= slideIndex) {
                dots[slideIndex - 1].className += ' active';
            }
        }

        function plusSlides(delta) {
            showSlides(slideIndex += delta);
        }

        function goToSlide(n) {
            var parsed = parseInt(n, 10);
            if (isNaN(parsed)) return;
            showSlides(slideIndex = parsed);
        }

        if (prevBtn) {
            prevBtn.addEventListener('click', function (e) {
                e.preventDefault();
                plusSlides(-1);
            });
        }

        if (nextBtn) {
            nextBtn.addEventListener('click', function (e) {
                e.preventDefault();
                plusSlides(1);
            });
        }

        if (dots && dots.length > 0) {
            for (var k = 0; k < dots.length; k++) {
                (function (dot) {
                    dot.addEventListener('click', function (e) {
                        e.preventDefault();
                        goToSlide(dot.getAttribute('data-slide'));
                    });
                })(dots[k]);
            }
        }

        showSlides(slideIndex);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initHomeSlideshow);
    } else {
        initHomeSlideshow();
    }
})();