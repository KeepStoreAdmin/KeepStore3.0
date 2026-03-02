/*
  KeepStore 3.0 - Product gallery bootstrap
  Inizializza Swiper per gallery prodotto solo se non gia' inizializzata dal tema.
  Naming neutro.
*/
(function () {
  try {
    if (!window.Swiper) return;

    var mainEl = document.querySelector('.tf-product-view-main');
    var thumbsEl = document.querySelector('.tf-product-view-thumbs');
    if (!mainEl || !thumbsEl) return;

    // Evita doppia init
    if (mainEl.swiper || thumbsEl.swiper) return;

    var thumbs = new Swiper(thumbsEl, {
      slidesPerView: 5,
      spaceBetween: 10,
      watchSlidesProgress: true,
      freeMode: true,
      breakpoints: {
        0: { slidesPerView: 4 },
        576: { slidesPerView: 5 }
      }
    });

    new Swiper(mainEl, {
      spaceBetween: 10,
      navigation: {
        nextEl: '.single-slide-next',
        prevEl: '.single-slide-prev'
      },
      thumbs: { swiper: thumbs }
    });
  } catch (e) {
    // Silenzioso: non bloccare la pagina
  }
})();
