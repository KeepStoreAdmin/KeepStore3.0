(function () {
  'use strict';

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }

  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function bySuffix(id, root) { return q('[id$=\"' + id + '\"]', root || document); }
  function first(selectors, root) {
    for (var i = 0; i < selectors.length; i++) {
      var n = q(selectors[i], root || document);
      if (n) return n;
    }
    return null;
  }
  function hasIdSuffix(node, suffix) { return !!node && String(node.id || '').slice(-suffix.length) === suffix; }
  function txt(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function home() { return !!document.body && (document.body.classList.contains('ks-page-home') || !!first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]'])); }
  function safe(name, fn) { try { return fn(); } catch (e) { try { console.warn('[KeepStore HOME]', name, e); } catch (_) {} return null; } }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }

  function normalizeUrl(url) {
    url = String(url || '').trim();
    if (!url) return '';
    url = url.replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '');
    return url.replace(/&amp;/g, '&');
  }

  function productId(url) {
    var m = String(url || '').match(/[?&]id=(\d+)/i);
    return m ? m[1] : normalizeUrl(url);
  }

  function cleanTitle(value) {
    return String(value || '')
      .replace(/\s+/g, ' ')
      .replace(/^(categoria|catalogo|supporto|spedizione|pagamenti|garanzia|home)\s*/i, '')
      .trim();
  }

  function familyKey(title) {
    return String(title || '').toLowerCase()
      .replace(/\b(nero|black|bianco|white|rosso|red|blu|blue|verde|green|rosa|pink|grigio|grey|silver|oro|gold|trasparente|clear)\b/g, ' ')
      .replace(/\b(custodia|cover|case|pellicola|vetro|glass|protezione|protettiva|magnetico|magnetica|silicone|tpu|gel|bordo|bordi)\b/g, ' ')
      .replace(/\b(compatibile|specifico|universale|originale|premium|professionale|ricondizionato|ricondizionata|completo|completa)\b/g, ' ')
      .replace(/\b\d+(?:[\.,]\d+)?\s?(gb|tb|mb|mm|cm|m|w|v|a|mah|hz|inch|pollici|usb|type c|tipo c)\b/g, ' ')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .split(' ')
      .slice(0, 8)
      .join(' ');
  }

  function readImage(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src) continue;
      if (/logo|brand|payment|visa|mastercard|paypal|nofoto|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }

  function readPrice(root) {
    var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g);
    return m && m.length ? m[m.length - 1] : '';
  }

  function readCategory(root) {
    var n = q('.category,.caption,.font-2,.text-main-2,.type,.brand', root);
    var t = txt(n);
    return t && t.length < 38 && !/€/.test(t) ? t : '';
  }

  function productRoot(link) {
    return link.closest('.card-product,.ks-grid-card,.ks-row-card,.ks-big-card,.ks-deal-card,.product-item,.product-card,li,.swiper-slide,.box-product') || link.parentElement;
  }

  function linkTitle(link, root) {
    var candidates = [
      q('.name-product a', root), q('.product-title a', root), q('h6 a', root), q('h5 a', root), q('.title a', root), link
    ];
    for (var i = 0; i < candidates.length; i++) {
      var t = cleanTitle(txt(candidates[i]));
      if (t.length >= 4 && !/^(scopri|vai al catalogo|categoria|compra)$/i.test(t)) return t;
    }
    return '';
  }

  function productLinks(root) {
    return qa('a[href*="articolo.aspx?id="],a[href*="articolo.aspx?Id="],a[href*="articolo.aspx?ID="]', root || document).filter(function (a) {
      return !!a && !a.closest('header,footer,.ks-home-brands-block,[id$=\"HomeBrandsSection\"],#KsHomeDepartmentShowcase,#KsHomeClosingLayer,.ks-home-final-rendered');
    });
  }

  function newState() { return { ids: Object.create(null), urls: Object.create(null), families: Object.create(null) }; }
  function markProduct(state, p) {
    if (!state || !p) return;
    if (p.id) state.ids[p.id] = 1;
    if (p.href) state.urls[p.href] = 1;
    if (p.family) state.families[p.family] = 1;
  }
  function isUsed(state, p) {
    return !!(state && p && ((p.id && state.ids[p.id]) || (p.href && state.urls[p.href]) || (p.family && state.families[p.family])));
  }

  function collectFrom(root, state, limit) {
    var out = [];
    if (!root) return out;
    productLinks(root).forEach(function (link) {
      if (limit && out.length >= limit) return;
      var href = normalizeUrl(link.getAttribute('href'));
      var id = productId(href);
      var card = productRoot(link);
      if (!href || !card) return;
      var title = linkTitle(link, card);
      var img = readImage(card);
      if (!title || !img) return;
      var p = { id: id, href: href, img: img, title: title, category: readCategory(card), price: readPrice(card), family: familyKey(title) };
      if (isUsed(state, p)) return;
      markProduct(state, p);
      out.push(p);
    });
    return out;
  }

  function collectMany(roots, state, limit) {
    var out = [];
    (roots || []).forEach(function (root) {
      if (limit && out.length >= limit) return;
      collectFrom(root, state, limit ? limit - out.length : 0).forEach(function (p) { out.push(p); });
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

  function sectionTitle(kicker, title, linkText) {
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

  function show(node) {
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

  function hide(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-final-source-hidden', reason || 'final');
    if (node.style) node.style.setProperty('display', 'none', 'important');
  }

  function forceHeroLayout() {
    var section = first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']);
    var shell = first(['.ks-home-hero-shell','[id$=\"HomeHeroShell\"]'], section);
    if (!section || !shell) return;
    show(section); show(shell);
    section.classList.add('ks-final-hero-section');
    shell.classList.add('ks-final-hero-shell');
    var menu = q('.wrap-item-1', shell);
    var hero = first(['.wrap-item-2','[id$=\"HeroSliderWrap\"]'], shell);
    [menu, hero].forEach(show);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', '250px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '18px', 'important');
    shell.style.setProperty('min-height', '340px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    if (menu) {
      menu.style.setProperty('width', '250px', 'important');
      menu.style.setProperty('min-width', '250px', 'important');
      menu.style.setProperty('height', '340px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
      menu.style.setProperty('display', 'block', 'important');
    }
    if (hero) {
      hero.style.setProperty('height', '340px', 'important');
      hero.style.setProperty('min-height', '340px', 'important');
      hero.style.setProperty('width', '100%', 'important');
    }
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,[id$=\"HeroSideWrap\"]', shell).forEach(function (n) { hide(n, 'side-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-slider a', section).forEach(function (n) {
      show(n);
      if (n.style) {
        n.style.setProperty('height', '340px', 'important');
        n.style.setProperty('min-height', '340px', 'important');
        n.style.setProperty('width', '100%', 'important');
      }
    });
    qa('.ks-home-hero-slider img', section).forEach(function (img) {
      show(img);
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'contain', 'important');
      img.style.setProperty('object-position', 'center center', 'important');
      img.style.setProperty('background', '#050505', 'important');
    });
    qa('.ks-home-departments,.menu-category-list', shell).forEach(function (n) {
      n.style.setProperty('height', '340px', 'important');
      n.style.setProperty('max-height', '340px', 'important');
      n.style.setProperty('overflow-y', 'auto', 'important');
    });
  }

  function findIconBoxes() {
    var all = qa('main section, main .tf-sp-2, main .tf-sp-3, main .tf-sp-4');
    for (var i = 0; i < all.length; i++) {
      var t = txt(all[i]).toLowerCase();
      if (t.indexOf('spedizione veloce') >= 0 || t.indexOf('pagamenti sicuri') >= 0 || t.indexOf('supporto dedicato') >= 0) return all[i];
    }
    var hero = first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']);
    return hero ? hero.nextElementSibling : null;
  }

  function initials(title) { title = String(title || '').trim(); return (title ? title.charAt(0) : 'K').toUpperCase(); }

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
      add(txt(a), a.getAttribute('href'), img ? (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src')) : '');
    });
    qa('#ksDesktopCategoryMenu a[href], .ks-mobile-catalog-list a[href], footer.tf-footer a[href]').forEach(function (a) {
      if (out.length >= 12) return;
      add(txt(a), a.getAttribute('href'), '');
    });
    return out.slice(0, 12);
  }

  function buildDepartmentsShowcase(anchor) {
    var items = collectDepartments();
    if (items.length < 4) return anchor;
    var section = ensureSection('KsHomeDepartmentShowcase', 'tf-sp-2 ks-home-department-showcase ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle('Catalogo KeepStore', 'Reparti in evidenza') +
      '<div class="ks-department-grid">' + items.map(function (item) {
        var media = item.img ? '<img src="' + esc(item.img) + '" alt="' + esc(item.title) + '">' : '<span>' + esc(initials(item.title)) + '</span>';
        return '<a class="ks-department-card" href="' + esc(item.url) + '"><span class="ks-department-media">' + media + '</span><b>' + esc(item.title) + '</b><small>Scopri</small></a>';
      }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
    return section;
  }

  function buildProductDeck(id, products, kicker, title, anchor, max) {
    products = (products || []).slice(0, max || 10);
    if (products.length < 4) return anchor;
    var section = ensureSection(id, 'tf-sp-2 ks-final-product-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle(kicker, title) +
      '<div class="ks-final-product-grid">' + products.map(function (p) { return cardHtml(p, false); }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
    return section;
  }

  function buildLowerMatrix(products, anchor) {
    products = (products || []).slice(0, 12);
    if (products.length < 9) return anchor;
    var labels = ['Top 20', 'I Più Venduti', 'In Offerta'];
    var section = ensureSection('KsHomeLowerFinal', 'tf-sp-2 ks-final-lower-section ks-home-final-rendered');
    section.innerHTML = '<div class="container">' + sectionTitle('Proposte KeepStore', 'Altre proposte per te') +
      '<div class="ks-final-lower-grid">' + labels.map(function (label, index) {
        return '<div class="ks-final-lower-column"><h5>' + esc(label) + '</h5><div class="ks-final-lower-list">' + products.slice(index * 4, index * 4 + 4).map(function (p) { return cardHtml(p, true); }).join('') + '</div></div>';
      }).join('') + '</div></div>';
    insertAfter(anchor, section);
    show(section);
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
    else insertAfter(anchor, section);
    show(section);
    return section;
  }

  function roots() {
    return {
      deal: first(['.ks-home-deal-section','[id$="HomeDealSection"]']),
      editorial: first(['.ks-home-editorial-section','.flat-animate-tab']),
      best: first(['.ks-home-best-section']),
      recent: first(['[id$="HomeRecentlyViewedSection"]','.ks-home-recent-section','.ks-home-chosen-section']),
      lower: first(['[id$="HomeLowerColumnsSection"]','.ks-home-lower-columns-section']),
      brands: first(['[id$="HomeBrandsSection"]','.ks-home-brands-block'])
    };
  }


  function isFinalOrProtectedSection(sec) {
    if (!sec) return true;
    if (sec.classList && (sec.classList.contains('ks-home-final-rendered') || sec.classList.contains('ks-home-hero-section') || sec.classList.contains('ks-home-brands-block'))) return true;
    if (hasIdSuffix(sec, 'HomeHeroSection') || hasIdSuffix(sec, 'HomeBrandsSection')) return true;
    if (/^(KsHomeDepartmentShowcase|KsHomeDealFinal|KsHomeEditorialFinal|KsHomeBestSellerFinal|KsHomeRecentFinal|KsHomeLowerFinal|KsHomeClosingLayer)$/.test(sec.id || '')) return true;
    return false;
  }

  function hideNative(r) {
    ['deal', 'editorial', 'best', 'recent', 'lower'].forEach(function (key) { hide(r[key], 'final-rendered'); });
    qa('main > section').forEach(function (sec) {
      if (isFinalOrProtectedSection(sec)) return;
      if (/Top 20|I Piu|I Più|In Offerta|In Evidenza|Nuovi Arrivi|Best Seller|Occasione|Scelti Da Te/i.test(txt(sec))) hide(sec, 'stray-native');
    });
  }


  function placeBrands(anchor, brandSection) {
    if (!brandSection) return anchor;
    show(brandSection);
    brandSection.classList.add('ks-final-brands');
    insertAfter(anchor, brandSection);
    return brandSection;
  }

  function suppressNewsletter() {
    try { localStorage.setItem('ks_newsletter_shown', '1'); sessionStorage.setItem('ks_newsletter_shown', '1'); } catch (_) {}
    qa('.modal.show,.modal-backdrop.show').forEach(function (n) { if (/newsletter|subscribe/i.test(String(n.id || '') + ' ' + txt(n))) hide(n, 'newsletter-disabled'); });
    document.body.classList.remove('modal-open');
  }

  function normalizeCatalogMenu() {
    var menu = q('#ksDesktopCategoryMenu') || q('.ks-header-catalog-menu') || q('.header-catalog-menu') || q('.menu-catalog');
    if (!menu) return;
    menu.classList.add('ks-catalog-mega-normalized');
    qa('[style]', menu).forEach(function (n) { n.removeAttribute('style'); });
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

  function render() {
    if (!home()) return;
    document.body.classList.add('ks-page-home', 'ks-home-final-onsus', 'ks-home-step110-webforms-fixed', 'ks-home-step111-onsus-stabilized');
    suppressNewsletter();
    normalizeCatalogMenu();
    forceHeroLayout();

    var r = roots();

    // Read server-side pools first, then render ONSUS sections without letting Best Seller consume deal/editorial stock.
    var deal = collectMany([r.deal], newState(), 5);
    var bestRaw = collectMany([r.best], newState(), 5);
    var used = newState();
    deal.forEach(function (p) { markProduct(used, p); });
    bestRaw.forEach(function (p) { markProduct(used, p); });

    var editorial = collectMany([r.editorial, r.lower], used, 10);
    var recent = collectMany([r.recent], used, 5);
    var lower = collectMany([r.lower, r.editorial], used, 12);

    hideNative(r);

    var anchor = buildDepartmentsShowcase(findIconBoxes() || first(['.ks-home-hero-section','[id60\"HomeHeroSection\"]']));
    if (deal.length >= 3) anchor = buildProductDeck('KsHomeDealFinal', deal, 'Offerte reali', 'Occasione Imperdibile', anchor, 5);
    anchor = buildProductDeck('KsHomeEditorialFinal', editorial, 'Prodotti KeepStore', 'In Evidenza', anchor, 10);
    anchor = buildProductDeck('KsHomeBestSellerFinal', bestRaw, 'Best Seller', 'Best Seller', anchor, 5);
    if (recent.length >= 2) anchor = buildProductDeck('KsHomeRecentFinal', recent, 'Recenti', 'Scelti Da Te', anchor, 5);
    anchor = buildLowerMatrix(lower, anchor);
    anchor = placeBrands(anchor, r.brands);
    buildClosingLayer(anchor);
    initSliders();
  }

  function boot() {
    safe('render', render);
    [150, 450, 1000, 2200].forEach(function (delay) { window.setTimeout(function () { safe('render-retry', render); }, delay); });
    window.addEventListener('resize', function () { window.setTimeout(function () { safe('hero-resize', forceHeroLayout); }, 120); });
  }

  ready(boot);
})();
