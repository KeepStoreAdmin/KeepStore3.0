(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }

  function q(selector, root) { return (root || document).querySelector(selector); }
  function qa(selector, root) { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); }
  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function isHome() { return !!document.body && (document.body.classList.contains('ks-page-home') || !!q('#HomeHeroSection')); }
  function runSafe(name, fn) { try { return fn(); } catch (err) { try { console.warn('[KeepStore home]', name, err); } catch (_) {} return null; } }

  function cleanInlineHide(node) {
    if (!node || !node.style) return;
    ['display', 'visibility', 'opacity', 'pointer-events', 'height', 'min-height', 'max-height', 'margin', 'margin-top', 'margin-bottom', 'padding', 'padding-top', 'padding-bottom', 'overflow'].forEach(function (prop) {
      node.style.removeProperty(prop);
    });
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
    node.removeAttribute('data-ks-hidden');
    node.removeAttribute('data-ks-source-replaced');
    node.removeAttribute('data-ks-commercial-empty');
    node.classList.remove('ks-best-seller-v4-source-hidden', 'ks-best-seller-original-hidden-v3', 'ks-best-seller-source-wrap-hidden-v3', 'ks-pruned-empty', 'ks-commercial-hidden');
  }

  function showNode(node) {
    cleanInlineHide(node);
    if (node && node.classList) node.classList.add('ks-visible-native-block');
  }

  function hideNode(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-hidden', reason || 'empty');
    if (node.style) {
      node.style.setProperty('display', 'none', 'important');
    }
  }

  function removeGeneratedArtifacts() {
    [
      '#KsHomeDealStrip104', '#KsHomeCommercialMatrix104', '#KsHomeDealOnsusClean', '#KsHomeRecentOnsusClean', '#KsHomeLowerOnsusClean',
      '#KsHomeBestSellerOnsusV4', '#KsHomeFeedShowcase', '#KsHomeFeedTop', '#KsHomeFeedRecent', '#ksHomeRuntimeEditorial', '.ks-runtime-panel'
    ].forEach(function (selector) {
      qa(selector).forEach(function (node) { if (node && node.parentNode) node.parentNode.removeChild(node); });
    });
    qa('[data-ks-generated]').forEach(function (node) {
      if (node && node.id !== 'KsHomeDepartmentShowcase' && node.parentNode) node.parentNode.removeChild(node);
    });
  }

  function productIdFromUrl(url) {
    var match = String(url || '').match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
  }

  function productLinks(root) {
    return qa('a[href*="articolo.aspx?id="],a[href*="articolo.aspx?Id="],a[href*="articolo.aspx?ID="]', root || document).filter(function (link) {
      return !!link && !link.closest('header,footer,#HomeBrandsSection,.ks-home-brands-block,#KsHomeDepartmentShowcase,#KsHomeClosingLayer');
    });
  }

  function countProducts(root) {
    var seen = Object.create(null);
    var count = 0;
    productLinks(root).forEach(function (link) {
      var id = productIdFromUrl(link.getAttribute('href')) || link.getAttribute('href');
      if (!id || seen[id]) return;
      seen[id] = 1;
      count += 1;
    });
    return count;
  }

  function normalizeProductImages(root) {
    qa('main img', root || document).forEach(function (img) {
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src) return;
      if (!img.getAttribute('src') && img.getAttribute('data-src')) img.setAttribute('src', img.getAttribute('data-src'));
      img.loading = img.loading || 'lazy';
      img.decoding = img.decoding || 'async';
    });
  }

  function initSwiper(el, options) {
    if (!el || typeof window.Swiper === 'undefined') return null;
    if (el.swiper) { try { el.swiper.update(); } catch (_) {} return el.swiper; }
    return new window.Swiper(el, options || {});
  }

  function parseNumber(value, fallback) {
    var n = parseInt(value, 10);
    return isNaN(n) ? fallback : n;
  }

  function initHeroSwiper() {
    var hero = q('.ks-home-hero-slider');
    if (!hero || qa('.swiper-slide', hero).length < 1) return;
    initSwiper(hero, {
      slidesPerView: 1,
      loop: qa('.swiper-slide', hero).length > 1,
      speed: 500,
      observer: true,
      observeParents: true,
      navigation: { nextEl: '.ks-hero-next', prevEl: '.ks-hero-prev' },
      pagination: { el: '.ks-hero-pagination', clickable: true }
    });
  }

  function initProductSwipers() {
    qa('.tf-sw-products').forEach(function (el) {
      var slides = qa('.swiper-slide', el).filter(function (slide) { return countProducts(slide) > 0 || q('img', slide); }).length;
      if (!slides) return;
      var preview = parseNumber(el.getAttribute('data-preview'), 5);
      var tablet = parseNumber(el.getAttribute('data-tablet'), Math.min(4, preview));
      var mobileSm = parseNumber(el.getAttribute('data-mobile-sm'), 2);
      var mobile = parseNumber(el.getAttribute('data-mobile'), 1);
      initSwiper(el, {
        slidesPerView: mobile,
        spaceBetween: parseNumber(el.getAttribute('data-space'), 15),
        observer: true,
        observeParents: true,
        navigation: { nextEl: el.closest('section') ? q('.nav-next-products', el.closest('section')) : null, prevEl: el.closest('section') ? q('.nav-prev-products', el.closest('section')) : null },
        pagination: { el: q('.sw-pagination-products', el), clickable: true },
        breakpoints: { 576: { slidesPerView: mobileSm }, 768: { slidesPerView: tablet }, 1200: { slidesPerView: preview } }
      });
    });
  }

  function initColumnSwipers() {
    qa('.ks-column-swiper').forEach(function (el) {
      if (!qa('.swiper-slide', el).length) return;
      var block = el.closest('.tf-grid-product-item') || el.closest('.box-btn-slide-item');
      initSwiper(el, {
        slidesPerView: 1,
        spaceBetween: 12,
        observer: true,
        observeParents: true,
        navigation: { nextEl: block ? q('.ks-col-next', block) : null, prevEl: block ? q('.ks-col-prev', block) : null },
        pagination: { el: block ? q('.ks-col-pagination', block) : null, clickable: true }
      });
    });
  }

  function initBrandSlider() {
    var brands = q('.ks-home-brands');
    if (!brands) return;
    initSwiper(brands, {
      slidesPerView: 2,
      spaceBetween: 15,
      observer: true,
      observeParents: true,
      pagination: { el: '.ks-home-brands-pagination', clickable: true },
      breakpoints: { 576: { slidesPerView: 3 }, 768: { slidesPerView: 4 }, 1200: { slidesPerView: 6 } }
    });
  }

  function updateSwipers() {
    qa('.swiper').forEach(function (el) { if (el.swiper) { try { el.swiper.update(); } catch (_) {} } });
  }

  function forceHeroLayout() {
    var section = q('#HomeHeroSection');
    var shell = q('.ks-home-hero-shell', section);
    var slider = q('.ks-home-hero-slider', section);
    if (!section || !shell || !slider) return;
    showNode(section);
    showNode(shell);
    shell.classList.add('ks-home-hero-mode-compact-single', 'ks-home-force-compact');
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,#HeroSideWrap', shell).forEach(function (node) { hideNode(node, 'side-lane-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-slider a', section).forEach(showNode);
    qa('.ks-home-hero-slider img', section).forEach(function (img) {
      showNode(img);
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'contain', 'important');
      if (!img.getAttribute('src') && img.getAttribute('data-src')) img.setAttribute('src', img.getAttribute('data-src'));
    });
  }

  function collectDepartments() {
    var out = [], seen = Object.create(null);
    function add(title, url, image) {
      title = textOf({ textContent: title });
      if (!title || title.length < 2 || /^tutti i settori$/i.test(title)) return;
      url = url || 'articoli.aspx';
      var key = title.toLowerCase();
      if (seen[key]) return;
      seen[key] = 1;
      out.push({ title: title, url: url, image: image || '' });
    }

    qa('.ks-home-departments a[href], .menu-category-list a[href]').forEach(function (a) {
      var title = textOf(a);
      var img = q('img', a);
      add(title, a.getAttribute('href'), img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src')) : '');
    });
    qa('#ksDesktopCategoryMenu a[href], .ks-mobile-catalog-list a[href], footer.tf-footer a[href]').forEach(function (a) {
      if (out.length >= 12) return;
      add(textOf(a), a.getAttribute('href'), '');
    });
    return out.slice(0, 12);
  }

  function initials(title) {
    var t = String(title || '').trim();
    return (t ? t.charAt(0) : 'K').toUpperCase();
  }

  function buildDepartmentsShowcase() {
    var items = collectDepartments();
    if (items.length < 4) return;
    var section = q('#KsHomeDepartmentShowcase') || document.createElement('section');
    section.id = 'KsHomeDepartmentShowcase';
    section.className = 'tf-sp-2 ks-home-department-showcase';
    section.setAttribute('data-ks-structural', 'departments');
    section.innerHTML = '<div class="container"><div class="flat-title ks-home-section-title"><div><span class="ks-section-kicker">Catalogo KeepStore</span><h5 class="fw-semibold">Reparti in evidenza</h5></div><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div><div class="ks-department-grid">' + items.map(function (item) {
      var media = item.image ? '<img src="' + esc(item.image) + '" alt="' + esc(item.title) + '">' : '<span>' + esc(initials(item.title)) + '</span>';
      return '<a class="ks-department-card" href="' + esc(item.url) + '"><span class="ks-department-media">' + media + '</span><b>' + esc(item.title) + '</b><small>Scopri</small></a>';
    }).join('') + '</div></div>';

    var anchor = findIconBoxes() || q('#HomeHeroSection');
    if (anchor && anchor.parentNode && section.parentNode !== anchor.parentNode) anchor.parentNode.insertBefore(section, anchor.nextSibling);
    else if (anchor && anchor.parentNode && anchor.nextSibling !== section) anchor.parentNode.insertBefore(section, anchor.nextSibling);
    showNode(section);
  }

  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }

  function findIconBoxes() {
    var nodes = qa('main section, main .tf-sp-2, main .tf-sp-3, main .tf-sp-4, main .tf-sp-5');
    for (var i = 0; i < nodes.length; i++) {
      var t = textOf(nodes[i]).toLowerCase();
      if (t.indexOf('spedizione veloce') >= 0 || t.indexOf('pagamenti sicuri') >= 0 || t.indexOf('supporto dedicato') >= 0) return nodes[i];
    }
    return q('#HomeHeroSection') ? q('#HomeHeroSection').nextElementSibling : null;
  }

  function revealNativeSections() {
    [
      '#HomeHeroSection', '.ks-home-deal-section', '.ks-home-editorial-section', '.ks-home-best-section',
      '#HomeRecentlyViewedSection', '#HomeLowerColumnsSection', '#HomeBrandsSection', '.ks-home-brands-block'
    ].forEach(function (selector) { qa(selector).forEach(showNode); });
    qa('.ks-home-best-section .swiper-slide,.ks-home-deal-section .swiper-slide,#HomeRecentlyViewedSection .swiper-slide,.ks-home-editorial-section .tab-pane,#HomeLowerColumnsSection .tf-grid-product-item').forEach(showNode);
  }

  function pruneEmptyServerBlocks() {
    var deal = q('.ks-home-deal-section');
    if (deal) (countProducts(deal) > 0 ? showNode(deal) : hideNode(deal, 'deal-empty'));

    var editorial = q('.ks-home-editorial-section');
    if (editorial) {
      qa('.tab-pane', editorial).forEach(function (pane) {
        if (countProducts(pane) > 0) showNode(pane); else pane.classList.remove('show', 'active');
      });
      var firstPane = qa('.tab-pane', editorial).filter(function (pane) { return countProducts(pane) > 0; })[0];
      if (firstPane) {
        firstPane.classList.add('show', 'active');
        showNode(editorial);
      } else hideNode(editorial, 'editorial-empty');
    }

    var best = q('.ks-home-best-section');
    if (best) (countProducts(best) > 0 ? showNode(best) : hideNode(best, 'best-empty'));

    var recent = q('#HomeRecentlyViewedSection');
    if (recent) (countProducts(recent) >= 2 ? showNode(recent) : hideNode(recent, 'recent-under-threshold'));

    var lower = q('#HomeLowerColumnsSection');
    if (lower) {
      var visibleBlocks = 0;
      qa('.tf-grid-product-item,.box-btn-slide-item', lower).forEach(function (block) {
        if (countProducts(block) >= 3) { visibleBlocks += 1; showNode(block); }
        else hideNode(block, 'lower-block-under-threshold');
      });
      if (visibleBlocks > 0) { lower.setAttribute('data-ks-visible-blocks', String(visibleBlocks)); showNode(lower); }
      else hideNode(lower, 'lower-empty');
    }

    var brands = q('#HomeBrandsSection') || q('.ks-home-brands-block');
    if (brands) (qa('img[src],img[data-src]', brands).length >= 2 ? showNode(brands) : hideNode(brands, 'brands-empty'));
  }

  function placeAfter(reference, node) {
    if (!reference || !node || !reference.parentNode || !node.parentNode || reference === node) return;
    if (reference.nextElementSibling !== node) reference.parentNode.insertBefore(node, reference.nextSibling);
  }

  function orderNativeSections() {
    var hero = q('#HomeHeroSection');
    var icons = findIconBoxes();
    var departments = q('#KsHomeDepartmentShowcase');
    var deal = q('.ks-home-deal-section:not([data-ks-hidden])');
    var editorial = q('.ks-home-editorial-section:not([data-ks-hidden])');
    var best = q('.ks-home-best-section:not([data-ks-hidden])');
    var recent = q('#HomeRecentlyViewedSection:not([data-ks-hidden])');
    var lower = q('#HomeLowerColumnsSection:not([data-ks-hidden])');
    var brands = q('#HomeBrandsSection:not([data-ks-hidden])') || q('.ks-home-brands-block:not([data-ks-hidden])');

    if (hero && icons) placeAfter(hero, icons);
    if (icons && departments) placeAfter(icons, departments);
    if ((departments || icons) && deal) placeAfter(departments || icons, deal);
    if ((deal || departments || icons) && editorial) placeAfter(deal || departments || icons, editorial);
    if ((editorial || deal || departments || icons) && best) placeAfter(editorial || deal || departments || icons, best);
    if ((best || editorial) && recent) placeAfter(best || editorial, recent);
    if ((recent || best || editorial) && lower) placeAfter(recent || best || editorial, lower);
    if ((lower || recent || best || editorial) && brands) placeAfter(lower || recent || best || editorial, brands);
  }

  function normalizeDesktopCatalogMegaMenu() {
    var menu = q('#ksDesktopCategoryMenu') || q('.ks-header-catalog-menu') || q('.header-catalog-menu') || q('.menu-catalog');
    if (!menu) return;
    menu.classList.add('ks-catalog-mega-normalized');
    qa('[style]', menu).forEach(function (node) { node.removeAttribute('style'); });
  }

  function suppressNewsletterPopup() {
    try {
      window.localStorage.setItem('ks_newsletter_shown', '1');
      window.sessionStorage.setItem('ks_newsletter_shown', '1');
    } catch (_) {}
    qa('.modal.show,.modal-backdrop.show').forEach(function (node) {
      if (/newsletter|subscribe|off/i.test(String(node.id || '') + ' ' + String(node.className || '') + ' ' + textOf(node))) {
        node.classList.remove('show');
        hideNode(node, 'newsletter-popup-disabled');
      }
    });
    if (document.body) document.body.classList.remove('modal-open');
  }

  function clearFooterTail() {
    var footer = q('footer.tf-footer') || q('footer');
    if (!footer || !footer.parentNode) return;
    var parent = footer.parentNode;
    var found = false;
    Array.prototype.slice.call(parent.children).forEach(function (child) {
      if (child === footer) { found = true; return; }
      if (!found) return;
      if (/^(SCRIPT|STYLE|LINK)$/i.test(child.tagName)) return;
      if (child.id === 'goTop' || child.classList.contains('progress-wrap')) return;
      if (child.classList.contains('modal') || child.classList.contains('offcanvas') || child.classList.contains('modal-backdrop')) hideNode(child, 'after-footer-overlay');
    });
  }

  function stabilize() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home', 'ks-home-structural-step1');
    structuralStep2();
    document.body.classList.remove('ks-home-runtime-mounted', 'ks-home-v6-mounted');
    removeGeneratedArtifacts();
    revealNativeSections();
    forceHeroLayout();
    buildDepartmentsShowcase();
    normalizeProductImages(document);
    pruneEmptyServerBlocks();
    orderNativeSections();
    normalizeDesktopCatalogMegaMenu();
    suppressNewsletterPopup();
    clearFooterTail();
    updateSwipers();
  }

  function boot() {
    if (!isHome()) return;
    initHeroSwiper();
    initProductSwipers();
    initColumnSwipers();
    initBrandSlider();
    stabilize();
    [150, 450, 1000, 2200].forEach(function (delay) { window.setTimeout(function(){ stabilize(); structuralStep2(); }, delay); });
    window.addEventListener('resize', function () { window.setTimeout(stabilize, 120); });
  }


  function ks2Img(root){var imgs=qa('img',root);for(var i=0;i<imgs.length;i++){var s=imgs[i].currentSrc||imgs[i].getAttribute('src')||imgs[i].getAttribute('data-src')||'';if(s&&!/logo|brand|payment|nofoto|loader|spinner/i.test(s))return s;}return '';}
  function ks2Price(root){var t=textOf(root),m=t.match(/\d{1,4}(?:[\.,]\d{2})\s*€/g);return m&&m.length?m[m.length-1]:'';}
  function ks2Title(root,link){var n=q('.name-product,.product-title,h6 a,h5 a,a[href*="articolo.aspx"]',root);return textOf(n)||textOf(link);}
  function ks2Cat(root){return textOf(q('.caption,.category,.font-2,.text-main-2',root));}
  function ks2Fam(t){return String(t||'').toLowerCase().replace(/\b(nero|black|bianco|white|rosso|blu|blue|verde|rosa|pink|grigio|silver|gold|oro)\b/g,' ').replace(/\b(custodia|cover|case|pellicola|vetro|glass|protezione|clear|trasparente|magnetico|magnetica)\b/g,' ').replace(/\b\d+\s?(gb|tb|mb|mm|cm|w|v|mah|hz)\b/g,' ').replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim().split(' ').slice(0,8).join(' ');}
  function ks2Products(root,limit){var out=[],seen={},fam={};productLinks(root).forEach(function(a){if(limit&&out.length>=limit)return;var card=a.closest('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,li,.swiper-slide')||a.parentNode;if(!card||card.closest('#KsHomeDepartmentShowcase,#KsHomeClosingLayer,.ks-onsus-native-section'))return;var href=a.getAttribute('href')||'',img=ks2Img(card),title=ks2Title(card,a);if(!href||!img||!title||title.length<4)return;var key=productIdFromUrl(href)||href,f=ks2Fam(title);if(seen[key]||(f&&fam[f]))return;seen[key]=1;if(f)fam[f]=1;out.push({href:href,img:img,title:title,cat:ks2Cat(card),price:ks2Price(card)});});return out;}
  function ks2Card(p,mini){return '<article class="ks-onsus-product-card'+(mini?' ks-onsus-product-card--compact':'')+'"><a class="ks-onsus-product-media" href="'+esc(p.href)+'"><img src="'+esc(p.img)+'" alt="'+esc(p.title)+'" loading="lazy" decoding="async"></a><div class="ks-onsus-product-info">'+(p.cat?'<p class="ks-onsus-product-cat">'+esc(p.cat)+'</p>':'')+'<h6><a href="'+esc(p.href)+'">'+esc(p.title)+'</a></h6>'+(p.price?'<p class="ks-onsus-product-price">'+esc(p.price)+'</p>':'')+'</div></article>';}
  function ks2Title(k,t){return '<div class="flat-title ks-home-section-title ks-onsus-section-title"><div><span class="ks-section-kicker">'+esc(k)+'</span><h5 class="fw-semibold">'+esc(t)+'</h5></div><a class="ks-home-section-link" href="articoli.aspx">Vai al catalogo</a></div>';}
  function ks2Before(ref,node){if(ref&&node&&ref.parentNode&&ref.parentNode!==node.parentNode)ref.parentNode.insertBefore(node,ref);else if(ref&&node&&ref.parentNode&&ref.previousElementSibling!==node)ref.parentNode.insertBefore(node,ref);}
  function ks2HideSource(node,why){if(node){node.setAttribute('data-ks-native-source',why||'normalized');if(node.style)node.style.setProperty('display','none','important');}}
  function ks2Deck(id,source,products,kicker,title,before){if(!source||products.length<4)return null;var s=q('#'+id)||document.createElement('section');s.id=id;s.className='tf-sp-2 ks-onsus-native-section';s.innerHTML='<div class="container">'+ks2Title(kicker,title)+'<div class="ks-onsus-product-grid ks-onsus-product-grid--5">'+products.map(function(p){return ks2Card(p,false);}).join('')+'</div></div>';ks2Before(before||source,s);ks2HideSource(source,id);showNode(s);return s;}
  function ks2NormalizeBest(){var best=q('.ks-home-best-section');if(!best)return;best.classList.add('ks-onsus-best-native');showNode(best);qa('.swiper-slide',best).forEach(function(slide,i){showNode(slide);if(i>=5&&slide.style)slide.style.setProperty('display','none','important');});}
  function ks2Closing(){var footer=q('footer.tf-footer')||q('footer'),brands=q('#HomeBrandsSection')||q('.ks-home-brands-block');if(!footer||!brands)return;var cats=collectDepartments().slice(0,8);if(cats.length<4)cats=[{title:'Notebook e computer',url:'articoli.aspx'},{title:'Fotografia e video',url:'articoli.aspx'},{title:'Smartphone e tablet',url:'articoli.aspx'},{title:'Gaming e console',url:'articoli.aspx'},{title:'TV e audio',url:'articoli.aspx'},{title:'Accessori tech',url:'articoli.aspx'}];var srv=['Spedizione veloce','Supporto dedicato','Pagamenti sicuri','Affidabilità reale'];var s=q('#KsHomeClosingLayer')||document.createElement('section');s.id='KsHomeClosingLayer';s.className='tf-sp-2 ks-home-closing-layer';s.innerHTML='<div class="container"><div class="ks-home-closing-grid"><div class="ks-home-closing-card"><span class="ks-section-kicker">Catalogo</span><h5>Categorie popolari</h5><div class="ks-home-closing-tags">'+cats.map(function(c){return '<a href="'+esc(c.url)+'"><b>'+esc(c.title)+'</b><small>Categoria</small></a>';}).join('')+'</div></div><div class="ks-home-closing-card"><span class="ks-section-kicker">Acquisto sicuro</span><h5>Servizi KeepStore</h5><div class="ks-home-service-grid">'+srv.map(function(x){return '<div><b>'+esc(initials(x))+'</b><strong>'+esc(x)+'</strong><small>Servizio reale KeepStore</small></div>';}).join('')+'</div></div></div></div>';if(footer.parentNode)footer.parentNode.insertBefore(s,footer);showNode(s);}
  function structuralStep2(){if(!isHome())return;document.body.classList.add('ks-home-structural-step2');var anchor=q('#KsHomeDepartmentShowcase')||findIconBoxes();var deal=q('.ks-home-deal-section'),editorial=q('.ks-home-editorial-section'),recent=q('#HomeRecentlyViewedSection'),lower=q('#HomeLowerColumnsSection'),brands=q('#HomeBrandsSection')||q('.ks-home-brands-block');var dealDeck=ks2Deck('KsHomeDealNative',deal,ks2Products(deal,5),'Offerte reali','Occasione Imperdibile',editorial||anchor);var editDeck=ks2Deck('KsHomeEditorialNative',editorial,ks2Products(editorial,10),'Prodotti KeepStore','In Evidenza',editorial);ks2NormalizeBest();var best=q('.ks-home-best-section');if(editDeck&&best)placeAfter(editDeck,best);var recentDeck=recent&&ks2Products(recent,5).length>=2?ks2Deck('KsHomeRecentNative',recent,ks2Products(recent,5),'Recenti','Scelti Da Te',recent):null;if(recentDeck&&best)placeAfter(best,recentDeck);var lowerProducts=ks2Products(lower,12);if(lower&&lowerProducts.length>=6){var s=q('#KsHomeLowerNative')||document.createElement('section');s.id='KsHomeLowerNative';s.className='tf-sp-2 ks-onsus-native-section ks-onsus-lower-native';s.innerHTML='<div class="container">'+ks2Title('Proposte KeepStore','Altre proposte per te')+'<div class="ks-onsus-lower-grid">'+['Top 20','I Più Venduti','In Offerta'].map(function(label,i){return '<div class="ks-onsus-lower-column"><h6>'+esc(label)+'</h6><div class="ks-onsus-lower-list">'+lowerProducts.slice(i*4,i*4+4).map(function(p){return ks2Card(p,true);}).join('')+'</div></div>';}).join('')+'</div></div>';ks2Before(lower,s);ks2HideSource(lower,'lower-normalized');showNode(s);if(brands)placeAfter(s,brands);}else if(lower){hideNode(lower,'lower-under-threshold');}if(brands)showNode(brands);ks2Closing();}


  onReady(boot);
})();
