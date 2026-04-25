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
  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }
  function runSafe(name, fn) {
    try { return fn(); }
    catch (err) { try { console.warn('[KeepStore home]', name, err); } catch (_) {} return null; }
  }

  function productIdFromUrl(url) {
    var match = String(url || '').match(/[?&]id=(\d+)/i);
    return match ? match[1] : String(url || '').trim();
  }

  function normalizeUrl(url) {
    url = String(url || '').trim();
    if (!url) return '';
    return url.replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '');
  }

  function cleanTitle(value) {
    return String(value || '')
      .replace(/\s+/g, ' ')
      .replace(/^(categoria|supporto|spedizione|pagamenti|garanzia)\s*/i, '')
      .trim();
  }

  function familyKey(title) {
    return String(title || '').toLowerCase()
      .replace(/\b(nero|black|bianco|white|rosso|red|blu|blue|verde|green|rosa|pink|grigio|grey|silver|oro|gold|trasparente|clear)\b/g, ' ')
      .replace(/\b(custodia|cover|case|pellicola|vetro|glass|protezione|magnetico|magnetica|silicone|tpu|gel)\b/g, ' ')
      .replace(/\b(compatibile|specifico|universale|originale|premium|professionale|ricondizionato|ricondizionata)\b/g, ' ')
      .replace(/\b\d+(?:[\.,]\d+)?\s?(gb|tb|mb|mm|cm|m|w|v|a|mah|hz|inch|pollici|usb|type c|tipo c)\b/g, ' ')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .split(' ')
      .slice(0, 8)
      .join(' ');
  }

  function resolveImg(root) {
    var node = null;
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src) continue;
      if (/logo|brand|payment|visa|mastercard|paypal|nofoto|placeholder|loader|spinner/i.test(src)) continue;
      node = img;
      break;
    }
    if (!node) return '';
    var s = node.currentSrc || node.getAttribute('src') || node.getAttribute('data-src') || '';
    if (!s && node.getAttribute('srcset')) s = String(node.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    if (s && !node.getAttribute('src')) node.setAttribute('src', s);
    return s;
  }

  function readPrice(root) {
    var nodes = qa('.price,.product-price,.price-sale,.text-primary,.new-price,.old-price', root);
    for (var i = nodes.length - 1; i >= 0; i--) {
      var t = textOf(nodes[i]);
      if (/\d/.test(t) && /€/.test(t)) return t.match(/\d{1,5}(?:[\.,]\d{2})\s*€/) ? t.match(/\d{1,5}(?:[\.,]\d{2})\s*€/)[0] : t;
    }
    var all = textOf(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
    return all && all.length ? all[all.length - 1] : '';
  }

  function readCategory(root) {
    var n = q('.category,.caption,.font-2,.text-main-2,.type,.brand', root);
    var t = textOf(n);
    return t.length < 40 ? t : '';
  }

  function linkTitle(link, card) {
    var candidates = [
      q('.name-product a', card), q('.product-title a', card), q('h6 a', card), q('h5 a', card), q('.title a', card), link
    ];
    for (var i = 0; i < candidates.length; i++) {
      var t = cleanTitle(textOf(candidates[i]));
      if (t.length >= 4 && !/^(scopri|vai al catalogo|categoria)$/i.test(t)) return t;
    }
    return '';
  }

  function productCardRoot(link) {
    return link.closest('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.product-item,.product-card,li,.swiper-slide') || link.parentElement;
  }

  function productLinks(root) {
    return qa('a[href*="articolo.aspx?id="],a[href*="articolo.aspx?Id="],a[href*="articolo.aspx?ID="]', root || document).filter(function (a) {
      return !!a && !a.closest('header,footer,#HomeBrandsSection,.ks-home-brands-block,#KsHomeDepartmentShowcase,#KsHomeClosingLayer,.ks-home-final-rendered');
    });
  }

  function collectProductsFrom(root, options) {
    options = options || {};
    var seen = options.seen || Object.create(null);
    var families = options.families || Object.create(null);
    var out = [];
    if (!root) return out;
    productLinks(root).forEach(function (link) {
      var href = normalizeUrl(link.getAttribute('href'));
      var id = productIdFromUrl(href);
      var card = productCardRoot(link);
      if (!href || !card || seen[id] || seen[href]) return;
      var img = resolveImg(card);
      var title = linkTitle(link, card);
      if (!img || !title) return;
      var fam = familyKey(title);
      if (fam && families[fam]) return;
      seen[id] = 1;
      seen[href] = 1;
      if (fam) families[fam] = 1;
      out.push({ id: id, href: href, img: img, title: title, category: readCategory(card), price: readPrice(card), family: fam });
    });
    return out;
  }

  function mergeProducts(sources, limit) {
    var seen = Object.create(null), families = Object.create(null), out = [];
    sources.forEach(function (root) {
      collectProductsFrom(root, { seen: seen, families: families }).forEach(function (p) {
        if (!limit || out.length < limit) out.push(p);
      });
    });
    return out;
  }

  function cardHtml(p, compact) {
    return '<article class="ks-final-product-card' + (compact ? ' ks-final-product-card--compact' : '') + '">' +
      '<a class="ks-final-product-media" href="' + esc(p.href) + '"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></a>' +
      '<div class="ks-final-product-info">' +
      (p.category ? '<p class="ks-final-product-cat">' + esc(p.category) + '</p>' : '') +
      '<h6><a href="' + esc(p.href) + '">' + esc(p.title) + '</a></h6>' +
      (p.price ? '<p class="ks-final-product-price">' + esc(p.price) + '</p>' : '') +
      '</div></article>';
  }

  function titleHtml(kicker, title, linkText) {
    return '<div class="flat-title ks-final-title"><div><span class="ks-section-kicker">' + esc(kicker) + '</span><h5 class="fw-semibold">' + esc(title) + '</h5></div>' +
      '<a class="ks-home-section-link" href="articoli.aspx">' + esc(linkText || 'Vai al catalogo') + '</a></div>';
  }

  function ensureSection(id, className) {
    var node = q('#' + id) || document.createElement('section');
    node.id = id;
    node.className = className;
    node.setAttribute('data-ks-final-home', '1');
    return node;
  }

  function insertAfter(ref, node) {
    if (!ref || !node || !ref.parentNode) return;
    if (ref.nextElementSibling !== node) ref.parentNode.insertBefore(node, ref.nextSibling);
  }

  function insertBefore(ref, node) {
    if (!ref || !node || !ref.parentNode) return;
    if (ref.previousElementSibling !== node) ref.parentNode.insertBefore(node, ref);
  }

  function hideSource(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-final-source-hidden', reason || 'normalized');
    if (node.style) node.style.setProperty('display', 'none', 'important');
  }

  function showNode(node) {
    if (!node) return;
    node.removeAttribute('hidden');
    node.removeAttribute('aria-hidden');
    if (node.style) {
      node.style.removeProperty('display');
      node.style.removeProperty('visibility');
      node.style.removeProperty('opacity');
      node.style.removeProperty('height');
      node.style.removeProperty('min-height');
      node.style.removeProperty('max-height');
      node.style.removeProperty('overflow');
    }
  }

  function forceHeroLayout() {
    var section = q('#HomeHeroSection');
    var shell = q('.ks-home-hero-shell', section);
    if (!section || !shell) return;
    showNode(section);
    showNode(shell);
    section.classList.add('ks-final-hero-section');
    shell.classList.add('ks-final-hero-shell');
    var menu = q('.wrap-item-1', shell);
    var hero = q('.wrap-item-2,#HeroSliderWrap', shell);
    [shell, menu, hero].forEach(showNode);
    if (shell.style) {
      shell.style.setProperty('display', 'grid', 'important');
      shell.style.setProperty('grid-template-columns', '250px minmax(0,1fr)', 'important');
      shell.style.setProperty('gap', '18px', 'important');
      shell.style.setProperty('min-height', '340px', 'important');
      shell.style.setProperty('align-items', 'stretch', 'important');
    }
    if (menu && menu.style) {
      menu.style.setProperty('display', 'block', 'important');
      menu.style.setProperty('width', '250px', 'important');
      menu.style.setProperty('min-width', '250px', 'important');
      menu.style.setProperty('height', '340px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    if (hero && hero.style) {
      hero.style.setProperty('height', '340px', 'important');
      hero.style.setProperty('min-height', '340px', 'important');
      hero.style.setProperty('width', '100%', 'important');
    }
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,#HeroSideWrap', shell).forEach(function (n) { hideSource(n, 'side-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-slider a', section).forEach(function (n) {
      showNode(n);
      if (n.style) {
        n.style.setProperty('height', '340px', 'important');
        n.style.setProperty('min-height', '340px', 'important');
        n.style.setProperty('width', '100%', 'important');
      }
    });
    qa('.ks-home-hero-slider img', section).forEach(function (img) {
      showNode(img);
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'contain', 'important');
      img.style.setProperty('background', '#050505', 'important');
    });
    qa('.ks-home-departments,.menu-category-list', shell).forEach(function (n) {
      n.style.setProperty('height', '340px', 'important');
      n.style.setProperty('max-height', '340px', 'important');
      n.style.setProperty('overflow-y', 'auto', 'important');
    });
  }

  function initSwiper(el, options) {
    if (!el || typeof window.Swiper === 'undefined') return null;
    if (el.swiper) { try { el.swiper.update(); } catch (_) {} return el.swiper; }
    try { return new window.Swiper(el, options || {}); } catch (_) { return null; }
  }

  function initSliders() {
    var hero = q('.ks-home-hero-slider');
    if (hero) initSwiper(hero, {
      slidesPerView: 1,
      loop: qa('.swiper-slide', hero).length > 1,
      observer: true,
      observeParents: true,
      navigation: { nextEl: '.ks-hero-next', prevEl: '.ks-hero-prev' },
      pagination: { el: '.ks-hero-pagination', clickable: true }
    });
    var brands = q('.ks-home-brands');
    if (brands) initSwiper(brands, {
      slidesPerView: 2,
      spaceBetween: 15,
      observer: true,
      observeParents: true,
      pagination: { el: '.ks-home-brands-pagination', clickable: true },
      breakpoints: { 576: { slidesPerView: 3 }, 768: { slidesPerView: 4 }, 1200: { slidesPerView: 6 } }
    });
  }

  function findIconBoxes() {
    var candidates = qa('main section, main .tf-sp-2, main .tf-sp-3, main .tf-sp-4');
    for (var i = 0; i < candidates.length; i++) {
      var t = textOf(candidates[i]).toLowerCase();
      if (t.indexOf('spedizione veloce') >= 0 || t.indexOf('pagamenti sicuri') >= 0 || t.indexOf('supporto dedicato') >= 0) return candidates[i];
    }
    var hero = q('#HomeHeroSection');
    return hero ? hero.nextElementSibling : null;
  }

  function collectDepartments() {
    var out = [], seen = Object.create(null);
    function add(title, url, img) {
      title = cleanTitle(title);
      if (!title || title.length < 2 || /^tutti i settori$/i.test(title)) return;
      var key = title.toLowerCase();
      if (seen[key]) return;
      seen[key] = 1;
      out.push({ title: title, url: normalizeUrl(url) || 'articoli.aspx', img: img || '' });
    }
    qa('.ks-home-departments a[href], .menu-category-list a[href]').forEach(function (a) {
      var img = q('img', a);
      add(textOf(a), a.getAttribute('href'), img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src')) : '');
    });
    qa('#ksDesktopCategoryMenu a[href], .ks-mobile-catalog-list a[href], footer.tf-footer a[href]').forEach(function (a) {
      if (out.length >= 12) return;
      add(textOf(a), a.getAttribute('href'), '');
    });
    return out.slice(0, 12);
  }

  function initials(title) { title = String(title || '').trim(); return (title ? title.charAt(0) : 'K').toUpperCase(); }

  function buildDepartmentsShowcase() {
    var items = collectDepartments();
    if (items.length < 4) return null;
    var section = ensureSection('KsHomeDepartmentShowcase', 'tf-sp-2 ks-home-department-showcase ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + titleHtml('Catalogo KeepStore', 'Reparti in evidenza') +
      '<div class="ks-department-grid">' + items.map(function (item) {
        var media = item.img ? '<img src="' + esc(item.img) + '" alt="' + esc(item.title) + '">' : '<span>' + esc(initials(item.title)) + '</span>';
        return '<a class="ks-department-card" href="' + esc(item.url) + '"><span class="ks-department-media">' + media + '</span><b>' + esc(item.title) + '</b><small>Scopri</small></a>';
      }).join('') + '</div></div>';
    var anchor = findIconBoxes() || q('#HomeHeroSection');
    if (anchor) insertAfter(anchor, section);
    showNode(section);
    return section;
  }

  function buildProductDeck(id, products, kicker, title, anchor, max) {
    products = (products || []).slice(0, max || 10);
    if (products.length < 4) return null;
    var section = ensureSection(id, 'tf-sp-2 ks-final-product-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + titleHtml(kicker, title) +
      '<div class="ks-final-product-grid">' + products.map(function (p) { return cardHtml(p, false); }).join('') + '</div></div>';
    if (anchor) insertAfter(anchor, section);
    showNode(section);
    return section;
  }

  function buildBestSeller(products, anchor) {
    products = (products || []).slice(0, 5);
    if (products.length < 4) return null;
    var section = ensureSection('KsHomeBestSellerFinal', 'tf-sp-2 ks-final-product-section ks-home-best-final ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + titleHtml('Best Seller', 'Best Seller') +
      '<div class="ks-final-product-grid ks-final-product-grid--best">' + products.map(function (p) { return cardHtml(p, false); }).join('') + '</div></div>';
    if (anchor) insertAfter(anchor, section);
    showNode(section);
    return section;
  }

  function buildLowerMatrix(products, anchor) {
    products = (products || []).slice(0, 12);
    if (products.length < 6) return null;
    var labels = ['Top 20', 'I Più Venduti', 'In Offerta'];
    var section = ensureSection('KsHomeLowerFinal', 'tf-sp-2 ks-final-lower-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + titleHtml('Proposte KeepStore', 'Altre proposte per te') +
      '<div class="ks-final-lower-grid">' + labels.map(function (label, index) {
        return '<div class="ks-final-lower-column"><h5>' + esc(label) + '</h5><div>' + products.slice(index * 4, index * 4 + 4).map(function (p) { return cardHtml(p, true); }).join('') + '</div></div>';
      }).join('') + '</div></div>';
    if (anchor) insertAfter(anchor, section);
    showNode(section);
    return section;
  }

  function buildClosingLayer(anchor) {
    var cats = collectDepartments().slice(0, 8);
    if (cats.length < 4) cats = [
      { title: 'Notebook e computer', url: 'articoli.aspx' }, { title: 'Fotografia e video', url: 'articoli.aspx' },
      { title: 'Smartphone e tablet', url: 'articoli.aspx' }, { title: 'Gaming e console', url: 'articoli.aspx' },
      { title: 'TV e audio', url: 'articoli.aspx' }, { title: 'Accessori tech', url: 'articoli.aspx' },
      { title: 'Audio e cuffie', url: 'articoli.aspx' }, { title: 'Materiale elettrico', url: 'articoli.aspx' }
    ];
    var services = ['Spedizione veloce', 'Supporto dedicato', 'Pagamenti sicuri', 'Affidabilità reale'];
    var section = ensureSection('KsHomeClosingLayer', 'tf-sp-2 ks-home-closing-layer ks-home-final-rendered');
    section.innerHTML = '<div class="container"><div class="ks-home-closing-grid"><div class="ks-home-closing-card"><span class="ks-section-kicker">Catalogo</span><h5>Categorie popolari</h5><div class="ks-home-closing-tags">' +
      cats.map(function (c) { return '<a href="' + esc(c.url) + '"><b>' + esc(c.title) + '</b><small>Categoria</small></a>'; }).join('') +
      '</div></div><div class="ks-home-closing-card"><span class="ks-section-kicker">Acquisto sicuro</span><h5>Servizi KeepStore</h5><div class="ks-home-service-grid">' +
      services.map(function (s) { return '<div><b>' + esc(initials(s)) + '</b><strong>' + esc(s) + '</strong><small>Servizio reale KeepStore</small></div>'; }).join('') +
      '</div></div></div></div>';
    var footer = q('footer.tf-footer') || q('footer');
    if (footer && footer.parentNode) footer.parentNode.insertBefore(section, footer);
    else if (anchor) insertAfter(anchor, section);
    showNode(section);
    return section;
  }

  function nativeRoots() {
    return {
      deal: q('.ks-home-deal-section'),
      editorial: q('.ks-home-editorial-section'),
      best: q('.ks-home-best-section'),
      recent: q('#HomeRecentlyViewedSection'),
      lower: q('#HomeLowerColumnsSection'),
      brands: q('#HomeBrandsSection') || q('.ks-home-brands-block')
    };
  }

  function hideNativeProductBlocks(roots) {
    ['deal', 'editorial', 'best', 'recent', 'lower'].forEach(function (key) { hideSource(roots[key], 'final-normalized'); });
  }

  function placeBrandsAfter(anchor, brands) {
    if (!brands) return null;
    showNode(brands);
    brands.classList.add('ks-final-brands');
    if (anchor) insertAfter(anchor, brands);
    return brands;
  }

  function suppressNewsletterPopup() {
    try {
      window.localStorage.setItem('ks_newsletter_shown', '1');
      window.sessionStorage.setItem('ks_newsletter_shown', '1');
    } catch (_) {}
    qa('.modal.show,.modal-backdrop.show').forEach(function (node) {
      if (/newsletter|subscribe/i.test(String(node.id || '') + ' ' + String(node.className || '') + ' ' + textOf(node))) hideSource(node, 'newsletter-disabled');
    });
    if (document.body) document.body.classList.remove('modal-open');
  }

  function normalizeCatalogMenu() {
    var menu = q('#ksDesktopCategoryMenu') || q('.ks-header-catalog-menu') || q('.header-catalog-menu') || q('.menu-catalog');
    if (!menu) return;
    menu.classList.add('ks-catalog-mega-normalized');
    qa('[style]', menu).forEach(function (node) { node.removeAttribute('style'); });
  }

  function renderFinalHome() {
    if (!isHome()) return;
    document.body.classList.add('ks-page-home', 'ks-home-final-onsus');

    suppressNewsletterPopup();
    forceHeroLayout();
    normalizeCatalogMenu();

    var iconBoxes = findIconBoxes();
    var deps = buildDepartmentsShowcase();
    var roots = nativeRoots();

    var editorialProducts = mergeProducts([roots.editorial, roots.deal, roots.lower, roots.best], 10);
    var bestProducts = mergeProducts([roots.best, roots.editorial], 5);
    var recentProducts = mergeProducts([roots.recent], 5);
    var lowerProducts = mergeProducts([roots.lower, roots.editorial, roots.deal, roots.best], 12);

    hideNativeProductBlocks(roots);

    var anchor = deps || iconBoxes || q('#HomeHeroSection');
    var dealProducts = mergeProducts([roots.deal, roots.editorial], 5);
    var dealSection = buildProductDeck('KsHomeDealFinal', dealProducts, 'Offerte reali', 'Occasione Imperdibile', anchor, 5) || anchor;
    var editorial = buildProductDeck('KsHomeEditorialFinal', editorialProducts, 'Prodotti KeepStore', 'In Evidenza', dealSection, 10) || dealSection;
    var best = buildBestSeller(bestProducts, editorial) || editorial;
    var recent = recentProducts.length >= 2 ? (buildProductDeck('KsHomeRecentFinal', recentProducts, 'Recenti', 'Scelti Da Te', best, 5) || best) : best;
    var lower = buildLowerMatrix(lowerProducts, recent) || recent;
    var brands = placeBrandsAfter(lower, roots.brands) || lower;
    buildClosingLayer(brands);

    initSliders();
  }

  function boot() {
    runSafe('renderFinalHome', renderFinalHome);
    [150, 450, 1000, 2200].forEach(function (delay) {
      window.setTimeout(function () { runSafe('renderFinalHomeRetry', renderFinalHome); }, delay);
    });
    window.addEventListener('resize', function () { window.setTimeout(function () { runSafe('heroResize', forceHeroLayout); }, 120); });
  }

  onReady(boot);
})();
