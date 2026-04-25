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
      img.style.setProperty('object-fit', 'cover', 'important');
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
    document.body.classList.add('ks-page-home', 'ks-home-final-onsus', 'ks-home-step110-webforms-fixed', 'ks-home-step111-onsus-stabilized', 'ks-home-step112-hero-fill', 'ks-home-step113-onsus-hard');
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

    var anchor = buildDepartmentsShowcase(findIconBoxes() || first(['.ks-home-hero-section','[id$=\"HomeHeroSection\"]']));
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

/* KeepStore HOME - Step 113 ONSUS hard hero pass: standalone to avoid touching server logic. */
(function () {
  'use strict';
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function q(s, r) { return (r || document).querySelector(s); }
  function txt(n) { return (n && (n.textContent || '') || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { n.style.removeProperty('display'); n.style.removeProperty('visibility'); n.style.removeProperty('opacity'); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-final-source-hidden', why || 'step113'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function run() {
    if (!document.body) return;
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    document.body.classList.add('ks-page-home', 'ks-home-step113-onsus-hard');
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var menu = shell ? q('.wrap-item-1', shell) : null;
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    [section, shell, menu, hero].forEach(show);
    if (shell) {
      shell.style.setProperty('display', 'grid', 'important');
      shell.style.setProperty('grid-template-columns', window.innerWidth >= 992 ? '250px minmax(0,1fr)' : '1fr', 'important');
      shell.style.setProperty('gap', '18px', 'important');
      shell.style.setProperty('min-height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
    }
    if (menu && window.innerWidth >= 992) {
      menu.style.setProperty('display', 'block', 'important');
      menu.style.setProperty('width', '250px', 'important');
      menu.style.setProperty('min-width', '250px', 'important');
      menu.style.setProperty('height', '340px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    qa('.ks-home-side-banners-legacy-off,.wrap-item-3,[id$="HeroSideWrap"]', section).forEach(function (n) { hide(n, 'side-off'); });
    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media--only,.ks-home-hero-slider a,[id$="Slide_Show_Container"]', section).forEach(function (n) {
      show(n);
      n.style.setProperty('height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
      n.style.setProperty('min-height', window.innerWidth >= 992 ? '340px' : '240px', 'important');
      n.style.setProperty('width', '100%', 'important');
      n.style.setProperty('background', '#050505', 'important');
      n.style.setProperty('overflow', 'hidden', 'important');
    });
    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner a', section) || q('.ks-home-hero-slider a', section);
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section);
    if (media && img) {
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src) {
        if (!img.getAttribute('src')) img.setAttribute('src', src);
        media.style.setProperty('background-image', 'url("' + src.replace(/"/g, '%22') + '")', 'important');
      }
      var apply = function () {
        var nw = img.naturalWidth || 0, nh = img.naturalHeight || 0, ratio = nw && nh ? nw / nh : 0;
        media.classList.remove('ks-hero-artwork-square');
        if (!ratio || ratio < 1.45) {
          media.classList.add('ks-hero-artwork-square');
          media.style.setProperty('background-size', '150% auto', 'important');
          media.style.setProperty('background-position', 'center center', 'important');
          img.style.setProperty('opacity', '0', 'important');
          img.style.setProperty('visibility', 'hidden', 'important');
        } else {
          media.style.setProperty('background-size', 'cover', 'important');
          media.style.setProperty('background-position', 'center center', 'important');
          img.style.setProperty('opacity', '1', 'important');
          img.style.setProperty('visibility', 'visible', 'important');
          img.style.setProperty('object-fit', 'cover', 'important');
          img.style.setProperty('object-position', 'center center', 'important');
        }
      };
      if (img.complete) apply(); else img.addEventListener('load', apply, { once: true });
    }
    var brands = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (brands) {
      var n = brands.nextElementSibling, guard = 0;
      while (n && guard < 8) {
        guard += 1;
        if (n.id === 'KsHomeClosingLayer' || (n.classList && n.classList.contains('ks-home-final-rendered'))) { n = n.nextElementSibling; continue; }
        var t = txt(n).toLowerCase();
        if ((t.indexOf('in evidenza') >= 0 || t.indexOf('top 20') >= 0 || t.indexOf('i piu') >= 0 || t.indexOf('offerta') >= 0) && qa('a[href*="articolo.aspx"]', n).length > 0) {
          n.classList.add('ks-native-vertical-source-off');
          hide(n, 'stray-native');
        }
        n = n.nextElementSibling;
      }
    }
  }
  function boot() { run(); [120, 350, 850, 1800, 3000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 114/4 Onsus index mix foundation.
   Applies the real Onsus index structure as a visual contract while preserving KeepStore server data. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function visible(n) { return !!(n && n.offsetParent !== null && getComputedStyle(n).display !== 'none' && getComputedStyle(n).visibility !== 'hidden'); }
  function show(n) {
    if (!n) return;
    n.removeAttribute('hidden');
    n.removeAttribute('aria-hidden');
    if (n.style) {
      n.style.removeProperty('display');
      n.style.removeProperty('visibility');
      n.style.removeProperty('opacity');
      n.style.removeProperty('height');
      n.style.removeProperty('min-height');
      n.style.removeProperty('max-height');
      n.style.removeProperty('overflow');
    }
  }
  function hardHide(n, why) {
    if (!n) return;
    n.setAttribute('data-ks-onsus-mix-hidden', why || 'mix');
    if (n.style) n.style.setProperty('display', 'none', 'important');
  }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }

  function normalizeHeroLikeIndex() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    if (!shell) return;
    var menu = q('.wrap-item-1', shell);
    var hero = q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell);
    if (!hero) return;

    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v1');
    section.classList.add('ks-onsus-top-section');
    shell.classList.add('s-banner-wrapper', 'ks-onsus-top-wrapper');
    hero.classList.add('ks-onsus-hero-panel');
    if (menu) menu.classList.add('ks-onsus-dept-panel');

    show(section); show(shell); show(menu); show(hero);
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { hardHide(n, 'legacy-side'); });

    var desk = window.innerWidth >= 992;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', desk ? '258px minmax(0, 1fr)' : '1fr', 'important');
    shell.style.setProperty('gap', desk ? '20px' : '0', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    shell.style.setProperty('min-height', desk ? '345px' : '245px', 'important');
    shell.style.setProperty('overflow', 'visible', 'important');

    if (menu) {
      if (desk) {
        menu.style.setProperty('display', 'block', 'important');
        menu.style.setProperty('width', '258px', 'important');
        menu.style.setProperty('min-width', '258px', 'important');
        menu.style.setProperty('max-width', '258px', 'important');
        menu.style.setProperty('height', '345px', 'important');
        menu.style.setProperty('max-height', '345px', 'important');
        menu.style.setProperty('overflow', 'hidden', 'important');
      } else {
        hardHide(menu, 'mobile-menu-column');
      }
    }

    qa('.ks-home-hero-slider,.ks-home-hero-slider .swiper-wrapper,.ks-home-hero-slider .swiper-slide,.ks-home-hero-banner,.ks-home-hero-media,.ks-home-hero-media--only,.ks-home-hero-slider a,[id$="Slide_Show_Container"]', section).forEach(function (n) {
      show(n);
      n.style.setProperty('display', 'block', 'important');
      n.style.setProperty('width', '100%', 'important');
      n.style.setProperty('height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('min-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('max-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('overflow', 'hidden', 'important');
      n.style.setProperty('background-color', '#050505', 'important');
      n.style.setProperty('border-radius', '8px', 'important');
      n.style.setProperty('position', 'relative', 'important');
    });

    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section) || hero;
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero);
    if (media && img) {
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (src && !img.getAttribute('src')) img.setAttribute('src', src);
      if (src) media.style.setProperty('background-image', 'url("' + src.replace(/"/g, '%22') + '")', 'important');
      media.classList.remove('ks-hero-artwork-square');
      media.classList.add('ks-onsus-hero-artwork-zoom');
      media.style.setProperty('background-repeat', 'no-repeat', 'important');
      media.style.setProperty('background-position', 'center center', 'important');
      media.style.setProperty('background-size', desk ? '178% auto' : '210% auto', 'important');
      img.style.setProperty('opacity', '0', 'important');
      img.style.setProperty('visibility', 'hidden', 'important');
      img.style.setProperty('display', 'block', 'important');
      img.style.setProperty('width', '100%', 'important');
      img.style.setProperty('height', '100%', 'important');
      img.style.setProperty('object-fit', 'cover', 'important');
    }

    qa('.ks-home-departments,.menu-category-list', section).forEach(function (n) {
      n.style.setProperty('height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('max-height', desk ? '345px' : '245px', 'important');
      n.style.setProperty('overflow-y', 'auto', 'important');
    });
  }

  function normalizeSectionsToIndexCadence() {
    var order = ['KsHomeDepartmentShowcase', 'KsHomeDealFinal', 'KsHomeEditorialFinal', 'KsHomeBestSellerFinal', 'KsHomeRecentFinal', 'KsHomeLowerFinal'];
    order.forEach(function (id) {
      var n = q('#' + id);
      if (n) n.classList.add('ks-onsus-index-section');
    });
    var deal = q('#KsHomeDealFinal');
    if (deal) {
      deal.classList.add('ks-onsus-deal-today');
      var title = q('h5', deal);
      if (title && /Occasione/i.test(text(title))) title.innerHTML = '<span class="ks-onsus-fire">●</span> Occasione Imperdibile';
    }
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial) editorial.classList.add('ks-onsus-feature-grid');
    var best = q('#KsHomeBestSellerFinal');
    if (best) best.classList.add('ks-onsus-best-seller');
    var lower = q('#KsHomeLowerFinal');
    if (lower) lower.classList.add('ks-onsus-top-trend');

    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('card-product', 'style-img-border');
      var media = q('.ks-final-product-media', card);
      if (media) media.classList.add('product-img');
      var img = q('img', card);
      if (img) img.classList.add('img-product');
      var link = q('h6 a', card);
      if (link) link.classList.add('name-product', 'body-md-2', 'fw-semibold', 'text-secondary', 'link');
    });
  }

  function removeNativeColumnsAfterBrand() {
    var brand = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var n = brand.nextElementSibling;
    var guard = 0;
    while (n && guard < 14) {
      guard += 1;
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *')) { n = next; continue; }
      if (n.getAttribute('data-ks-final-home') === '1' || n.classList.contains('ks-home-final-rendered')) { n = next; continue; }
      var hasProducts = qa('a[href*="articolo.aspx"]', n).length > 0;
      var t = text(n).toLowerCase();
      if (hasProducts && /(in evidenza|top 20|più venduti|piu venduti|offerta|scelti|best seller)/i.test(t)) hardHide(n, 'native-after-brand');
      n = next;
    }
  }

  function run() {
    if (!document.body || !q('.ks-home-hero-section,[id$="HomeHeroSection"]')) return;
    normalizeHeroLikeIndex();
    normalizeSectionsToIndexCadence();
    removeNativeColumnsAfterBrand();
  }
  function boot() { run(); [100, 300, 800, 1600, 2600, 4200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 115/4 Onsus index mix 2.
   Builds the missing Onsus top mechanics with real KeepStore data: right promo tiles + composed hero. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { n.style.removeProperty('display'); n.style.removeProperty('visibility'); n.style.removeProperty('opacity'); n.style.removeProperty('height'); n.style.removeProperty('min-height'); n.style.removeProperty('max-height'); n.style.removeProperty('overflow'); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step115-hidden', why || 'hidden'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function readImg(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }
  function readPrice(root) { var m = text(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var candidates = [q('h6 a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < candidates.length; i++) {
      var t = text(candidates[i]);
      if (t && t.length > 4 && !/^(scopri|compra|categoria)$/i.test(t)) return t;
    }
    return '';
  }
  function productFromCard(card) {
    if (!card) return null;
    var a = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(a && a.getAttribute('href'));
    var img = readImg(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: readPrice(card) };
  }
  function productPool(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeDealFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 2)) return;
      var p = productFromCard(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function sidePromoHtml(p, idx) {
    return '<a class="ks-onsus-side-promo" href="' + esc(p.href) + '">' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '<span class="ks-side-text"><span class="ks-side-kicker">' + (idx === 0 ? 'Offerta' : 'Promo') + '</span><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<em>' + esc(p.price) + '</em>' : '') + '</span></a>';
  }
  function ensureTopSidePromos(shell, hero) {
    if (!shell || !hero) return;
    var box = q('#KsOnsusTopSidePromos', shell);
    var pool = productPool(2);
    if (pool.length < 2) { if (box) hide(box, 'not-enough-products'); return; }
    if (!box) {
      box = document.createElement('div');
      box.id = 'KsOnsusTopSidePromos';
      box.className = 'ks-onsus-side-promos';
      if (hero.nextSibling) shell.insertBefore(box, hero.nextSibling); else shell.appendChild(box);
    }
    box.innerHTML = sidePromoHtml(pool[0], 0) + sidePromoHtml(pool[1], 1);
    show(box);
  }
  function composeHero(section, hero) {
    var media = q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section) || hero;
    var img = q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero);
    if (!media || !img) return;
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.98) 0%, rgba(5,5,5,.92) 38%, rgba(5,5,5,.18) 62%, rgba(5,5,5,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 108%', 'important');
    media.style.setProperty('background-position', 'center center, right center', 'important');
    media.classList.add('ks-onsus-hero-composed');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');
    if (!q('.ks-onsus-hero-caption', media)) {
      var cap = document.createElement('div');
      cap.className = 'ks-onsus-hero-caption';
      cap.innerHTML = '<span class="ks-hero-brand">Samsung</span><span class="ks-hero-sub">Odyssey Gaming Monitor G40B</span><span class="ks-hero-title">Uniti verso la nuova era del gioco</span><span class="ks-hero-specs"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span>';
      media.appendChild(cap);
    }
  }
  function normalizeTop() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    var menu = shell ? q('.wrap-item-1', shell) : null;
    if (!shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v1', 'ks-home-template-mix-v2');
    [section, shell, hero, menu].forEach(show);
    composeHero(section, hero);
    ensureTopSidePromos(shell, hero);
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { hide(n, 'replaced-by-real-side-promos'); });
  }
  function killNativeAfterBrand() {
    var brand = q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var n = brand.nextElementSibling, guard = 0;
    while (n && guard < 14) {
      guard += 1;
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *')) { n = next; continue; }
      if (n.getAttribute('data-ks-final-home') === '1' || n.classList.contains('ks-home-final-rendered')) { n = next; continue; }
      var hasProducts = qa('a[href*="articolo.aspx"]', n).length > 0;
      var t = text(n).toLowerCase();
      if (hasProducts && /(in evidenza|top 20|più venduti|piu venduti|offerta|scelti|best seller)/i.test(t)) hide(n, 'native-after-brand');
      n = next;
    }
  }
  function run() { if (!document.body) return; normalizeTop(); killNativeAfterBrand(); }
  function boot() { run(); [100, 300, 700, 1300, 2400, 4200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 116/4 Onsus index mix 3.
   Structural top banner: real 3-column Onsus layout without changing VB/DB. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { ['display','visibility','opacity','height','min-height','max-height','overflow'].forEach(function (p) { n.style.removeProperty(p); }); } }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step116-hidden', why || 'hidden'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function readImg(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      if (!img.getAttribute('src')) img.setAttribute('src', src);
      return src;
    }
    return '';
  }
  function readPrice(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFromCard(card) {
    if (!card) return null;
    var a = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(a && a.getAttribute('href'));
    var img = readImg(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: readPrice(card) };
  }
  function productPool(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeDealFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,#KsHomeLowerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 2)) return;
      var p = productFromCard(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function promoHtml(p, i) {
    return '<a class="ks-onsus-side-promo ks-onsus-side-promo-v3" href="' + esc(p.href) + '">' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '<span class="ks-side-text"><span class="ks-side-kicker">' + (i === 0 ? 'Offerta' : 'Consigliato') + '</span><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<em>' + esc(p.price) + '</em>' : '') + '</span></a>';
  }
  function ensureRightPromos(shell, hero) {
    var box = q('#KsOnsusTopSidePromos', shell);
    var pool = productPool(2);
    if (pool.length < 2) { if (box) hide(box, 'not-enough-products'); return null; }
    if (!box) { box = document.createElement('div'); box.id = 'KsOnsusTopSidePromos'; box.className = 'ks-onsus-side-promos'; }
    box.innerHTML = promoHtml(pool[0], 0) + promoHtml(pool[1], 1);
    if (hero.nextElementSibling !== box) shell.insertBefore(box, hero.nextSibling);
    box.style.removeProperty('display');
    return box;
  }
  function topGrid() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    if (!section) return;
    var shell = q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section);
    var menu = shell ? q('.wrap-item-1', shell) : null;
    var hero = shell ? (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell)) : null;
    if (!shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v3');
    section.classList.add('ks-onsus-top-section-v3'); shell.classList.add('ks-onsus-top-wrapper-v3'); hero.classList.add('ks-onsus-hero-panel-v3');
    [section, shell, menu, hero].forEach(show);
    var promos = ensureRightPromos(shell, hero);
    var wide = !window.matchMedia || window.matchMedia('(min-width: 1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('gap', '18px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '252px minmax(0,1fr) 228px' : '252px minmax(0,1fr)', 'important');
    shell.style.setProperty('height', '356px', 'important');
    shell.style.setProperty('min-height', '356px', 'important');
    if (menu) { menu.style.setProperty('grid-column', '1', 'important'); menu.style.setProperty('grid-row', '1', 'important'); menu.style.setProperty('width', '252px', 'important'); menu.style.setProperty('min-width', '252px', 'important'); menu.style.setProperty('height', '356px', 'important'); menu.style.setProperty('max-height', '356px', 'important'); menu.style.setProperty('overflow', 'hidden', 'important'); }
    hero.style.setProperty('grid-column', '2', 'important'); hero.style.setProperty('grid-row', '1', 'important'); hero.style.setProperty('height', '356px', 'important'); hero.style.setProperty('min-height', '356px', 'important'); hero.style.setProperty('min-width', '0', 'important');
    if (promos) { if (wide) { promos.style.setProperty('display', 'grid', 'important'); promos.style.setProperty('grid-column', '3', 'important'); promos.style.setProperty('grid-row', '1', 'important'); promos.style.setProperty('height', '356px', 'important'); } else { promos.style.setProperty('display', 'none', 'important'); } }
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { if (n !== promos) hide(n, 'legacy-side'); });
  }
  function heroArtwork() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = section && (q('.ks-home-hero-media', section) || q('.ks-home-hero-banner', section) || q('.ks-home-hero-slider a', section));
    var img = section && (q('.ks-home-hero-slider img', section) || q('[id$="Slide_Show_Container"] img', section) || q('img', hero));
    if (!media || !img) return;
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(4,4,4,.98) 0%, rgba(4,4,4,.94) 34%, rgba(4,4,4,.58) 52%, rgba(4,4,4,.08) 76%, rgba(4,4,4,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 162%', 'important');
    media.style.setProperty('background-position', 'center center, right center', 'important');
    media.style.setProperty('height', '356px', 'important'); media.style.setProperty('min-height', '356px', 'important');
    media.classList.add('ks-onsus-hero-composed-v3');
    img.style.setProperty('opacity', '0', 'important'); img.style.setProperty('visibility', 'hidden', 'important');
    var cap = q('.ks-onsus-hero-caption', media);
    if (cap) { cap.style.setProperty('left', '44px', 'important'); cap.style.setProperty('width', '50%', 'important'); cap.style.setProperty('max-width', '360px', 'important'); }
  }
  function polishSections() {
    ['KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeLowerFinal','KsHomeDealFinal'].forEach(function (id) { var s = q('#' + id); if (s) s.classList.add('ks-onsus-polished-section'); });
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial && !q('.ks-onsus-tabline', editorial)) { var title = q('.ks-final-title', editorial); if (title) { var tabs = document.createElement('div'); tabs.className = 'ks-onsus-tabline'; tabs.innerHTML = '<span class="is-active">In Evidenza</span><span>Top prodotti</span><span>Scelti da te</span>'; title.appendChild(tabs); } }
  }
  function run() { topGrid(); heroArtwork(); polishSections(); }
  function boot() { run(); [80,180,360,800,1600,3000,5000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 100); });
})();

/* KeepStore HOME - Step 117/4 Onsus index mix final.
   Last pass: preserve KeepStore server data, enforce ONSUS visual contract, remove native leaks. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function t(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) ['display','visibility','opacity','height','min-height','max-height','overflow','width','min-width','max-width'].forEach(function (p) { n.style.removeProperty(p); }); }
  function hide(n, why) { if (!n) return; n.setAttribute('data-ks-onsus-step117-hidden', why || 'final'); if (n.style) n.style.setProperty('display', 'none', 'important'); }
  function imgSrc(img) { return img && (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || (img.getAttribute('srcset') || '').split(',')[0].trim().split(' ')[0]) || ''; }
  function homeHero() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-template-mix-v4');
    section.classList.add('ks-onsus-top-section-v3'); shell.classList.add('ks-onsus-top-wrapper-v3'); hero.classList.add('ks-onsus-hero-panel-v3');
    [section, shell, menu, hero, promos].forEach(show);
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '252px minmax(0,1fr) 230px' : '252px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '364px', 'important');
    shell.style.setProperty('min-height', '364px', 'important');
    shell.style.setProperty('max-height', '364px', 'important');
    if (menu) { menu.style.setProperty('grid-column', '1', 'important'); menu.style.setProperty('height', '364px', 'important'); menu.style.setProperty('min-height', '364px', 'important'); menu.style.setProperty('max-height', '364px', 'important'); menu.style.setProperty('width', '252px', 'important'); menu.style.setProperty('min-width', '252px', 'important'); menu.style.setProperty('max-width', '252px', 'important'); menu.style.setProperty('overflow', 'hidden', 'important'); }
    hero.style.setProperty('grid-column', '2', 'important'); hero.style.setProperty('height', '364px', 'important'); hero.style.setProperty('min-height', '364px', 'important'); hero.style.setProperty('max-height', '364px', 'important'); hero.style.setProperty('min-width', '0', 'important');
    if (promos) { promos.style.setProperty('grid-column', '3', 'important'); promos.style.setProperty('height', '364px', 'important'); promos.style.setProperty('min-height', '364px', 'important'); promos.style.setProperty('max-height', '364px', 'important'); promos.style.setProperty('display', wide ? 'grid' : 'none', 'important'); }
    qa('.wrap-item-3,[id$="HeroSideWrap"],.ks-home-side-banners,.ks-home-side-banners-legacy-off', shell).forEach(function (n) { if (n !== promos) hide(n, 'legacy-side'); });
  }
  function heroArtwork() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.98) 0%, rgba(5,5,5,.92) 31%, rgba(5,5,5,.50) 50%, rgba(5,5,5,.08) 74%, rgba(5,5,5,0) 100%), url("' + src.replace(/"/g, '%22') + '")', 'important');
    media.classList.add('ks-onsus-hero-composed-v4');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 176%', 'important');
    media.style.setProperty('background-position', 'center center, center center', 'important');
    media.style.setProperty('height', '364px', 'important'); media.style.setProperty('min-height', '364px', 'important'); media.style.setProperty('max-height', '364px', 'important');
    img.style.setProperty('opacity', '0', 'important'); img.style.setProperty('visibility', 'hidden', 'important');
  }
  function normalizeSections() {
    ['KsHomeDealFinal','KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeRecentFinal','KsHomeLowerFinal','KsHomeClosingLayer'].forEach(function (id) {
      var node = q('#' + id);
      if (node) { node.classList.add('ks-onsus-final-v4'); node.setAttribute('data-ks-final-home', '1'); }
    });
    var editorial = q('#KsHomeEditorialFinal');
    if (editorial && !q('.ks-onsus-tabline', editorial)) {
      var title = q('.ks-final-title', editorial);
      if (title) {
        var tabs = document.createElement('div');
        tabs.className = 'ks-onsus-tabline';
        tabs.innerHTML = '<span class="is-active">In Evidenza</span><span>Top prodotti</span><span>Scelti da te</span>';
        title.appendChild(tabs);
      }
    }
    qa('.ks-final-product-grid').forEach(function (grid) {
      grid.classList.add('ks-onsus-grid-v4');
      qa('.ks-final-product-card', grid).forEach(function (card, i) { card.setAttribute('data-ks-card-index', String(i + 1)); });
    });
    qa('.ks-final-lower-column').forEach(function (col) {
      var count = qa('.ks-final-product-card', col).length;
      col.setAttribute('data-ks-items', String(count));
      if (count < 2) col.classList.add('ks-lower-column-sparse');
    });
  }
  function hideNativeLeaks() {
    var brand = q('[id$="HomeBrandsSection"],.ks-home-brands-block,.ks-final-brands');
    if (!brand) return;
    var n = brand.nextElementSibling;
    var guard = 0;
    while (n && guard++ < 14) {
      var next = n.nextElementSibling;
      if (n.id === 'KsHomeClosingLayer' || n.matches('footer,footer *') || n.classList.contains('ks-home-final-rendered') || n.getAttribute('data-ks-final-home') === '1') { n = next; continue; }
      var text = t(n);
      var products = qa('a[href*="articolo.aspx"]', n).length;
      if (products || /In Evidenza|Top 20|I Più Venduti|I Piu Venduti|In Offerta|Scelti Da Te|Best Seller|Occasione/i.test(text)) hide(n, 'native-after-brand');
      n = next;
    }
  }
  function run() { if (!document.body) return; homeHero(); heroArtwork(); normalizeSections(); hideNativeLeaks(); }
  function boot() { run(); [120, 260, 520, 1000, 2000, 3800, 6000].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 118 ONSUS container/proportion pass.
   Goal: stop looking like a compressed clone by matching ONSUS index proportions: wider container, true 3-lane hero, cleaner section titles. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function show(n) { if (!n) return; n.removeAttribute('hidden'); n.removeAttribute('aria-hidden'); if (n.style) { ['display','visibility','opacity','width','min-width','max-width','height','min-height','max-height','overflow','grid-column'].forEach(function (p) { n.style.removeProperty(p); }); } }
  function imgSrc(img) { return img && (img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || (img.getAttribute('srcset') || '').split(',')[0].trim().split(' ')[0]) || ''; }
  function escCssUrl(src) { return String(src || '').replace(/"/g, '%22'); }
  function homeTop() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-118');
    section.classList.add('ks-onsus-top-section-118');
    shell.classList.add('ks-onsus-top-wrapper-118');
    hero.classList.add('ks-onsus-hero-panel-118');
    [section, shell, menu, hero, promos].forEach(show);
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && promos);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    if (menu) {
      menu.style.setProperty('grid-column', '1', 'important');
      menu.style.setProperty('width', '285px', 'important');
      menu.style.setProperty('min-width', '285px', 'important');
      menu.style.setProperty('max-width', '285px', 'important');
      menu.style.setProperty('height', '390px', 'important');
      menu.style.setProperty('min-height', '390px', 'important');
      menu.style.setProperty('max-height', '390px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    hero.style.setProperty('grid-column', '2', 'important');
    hero.style.setProperty('height', '390px', 'important');
    hero.style.setProperty('min-height', '390px', 'important');
    hero.style.setProperty('max-height', '390px', 'important');
    hero.style.setProperty('min-width', '0', 'important');
    if (promos) {
      promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      promos.style.setProperty('height', '390px', 'important');
      promos.style.setProperty('min-height', '390px', 'important');
      promos.style.setProperty('max-height', '390px', 'important');
      promos.style.setProperty('width', '300px', 'important');
      promos.style.setProperty('min-width', '300px', 'important');
      promos.style.setProperty('max-width', '300px', 'important');
    }
  }
  function heroArt() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    media.classList.add('ks-onsus-hero-art-118');
    if (src) media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(7,7,7,.98) 0%, rgba(7,7,7,.90) 34%, rgba(7,7,7,.42) 57%, rgba(7,7,7,.06) 82%, rgba(7,7,7,0) 100%), url("' + escCssUrl(src) + '")', 'important');
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, cover', 'important');
    media.style.setProperty('background-position', 'center center, center center', 'important');
    media.style.setProperty('height', '390px', 'important');
    media.style.setProperty('min-height', '390px', 'important');
    media.style.setProperty('max-height', '390px', 'important');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');
    var cap = q('.ks-onsus-hero-caption', media);
    if (cap) {
      cap.style.setProperty('left', '54px', 'important');
      cap.style.setProperty('max-width', '420px', 'important');
      cap.style.setProperty('width', '48%', 'important');
    }
  }
  function titleRows() {
    qa('.ks-final-title').forEach(function (row) {
      row.classList.add('ks-onsus-title-118');
      var tabs = q('.ks-onsus-tabline', row);
      var links = qa('.ks-home-section-link', row);
      links.forEach(function (a, i) { if (i > 0) a.setAttribute('data-ks-onsus-step118-hidden', 'duplicate-link'); });
      if (tabs) row.appendChild(tabs);
      if (links[0]) row.appendChild(links[0]);
    });
  }
  function sectionRhythm() {
    ['KsHomeDealFinal','KsHomeEditorialFinal','KsHomeBestSellerFinal','KsHomeLowerFinal','KsHomeClosingLayer'].forEach(function (id) {
      var n = q('#' + id);
      if (n) n.classList.add('ks-onsus-section-118');
    });
    qa('.ks-final-product-grid').forEach(function (g) { g.classList.add('ks-onsus-product-grid-118'); });
  }
  function run() { if (!document.body) return; homeTop(); heroArt(); titleRows(); sectionRhythm(); }
  function boot() { run(); [90, 240, 520, 1100, 2400, 4800, 7200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 140); });
})();

/* KeepStore HOME - Step 119 ONSUS final alignment pass.
   Keeps KeepStore server data intact; only normalizes visual composition to the uploaded ONSUS index rhythm. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function show(n) {
    if (!n) return;
    n.removeAttribute('hidden');
    n.removeAttribute('aria-hidden');
    if (n.style) ['display','visibility','opacity'].forEach(function (p) { n.style.removeProperty(p); });
  }
  function imgSrc(img) {
    if (!img) return '';
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    return src;
  }
  function escUrl(src) { return String(src || '').replace(/"/g, '%22'); }

  function forceTopGrid() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    if (!section || !shell || !hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-119');
    section.classList.add('ks-onsus-top-section-119');
    shell.classList.add('ks-onsus-top-wrapper-119');
    hero.classList.add('ks-onsus-hero-panel-119');
    [section, shell, menu, hero, promos].forEach(show);

    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && promos);
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    shell.style.setProperty('align-items', 'stretch', 'important');

    if (menu) {
      menu.style.setProperty('grid-column', '1', 'important');
      menu.style.setProperty('height', '390px', 'important');
      menu.style.setProperty('min-height', '390px', 'important');
      menu.style.setProperty('max-height', '390px', 'important');
      menu.style.setProperty('width', '285px', 'important');
      menu.style.setProperty('min-width', '285px', 'important');
      menu.style.setProperty('max-width', '285px', 'important');
      menu.style.setProperty('overflow', 'hidden', 'important');
    }
    hero.style.setProperty('grid-column', '2', 'important');
    hero.style.setProperty('height', '390px', 'important');
    hero.style.setProperty('min-height', '390px', 'important');
    hero.style.setProperty('max-height', '390px', 'important');
    hero.style.setProperty('min-width', '0', 'important');
    hero.style.setProperty('overflow', 'hidden', 'important');
    if (promos) {
      promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      promos.style.setProperty('grid-template-rows', '1fr 1fr', 'important');
      promos.style.setProperty('gap', '20px', 'important');
      promos.style.setProperty('height', '390px', 'important');
      promos.style.setProperty('width', '300px', 'important');
      promos.style.setProperty('min-width', '300px', 'important');
      promos.style.setProperty('max-width', '300px', 'important');
    }
  }

  function strengthenHero() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var hero = section && (q('.wrap-item-2', section) || q('[id$="HeroSliderWrap"]', section));
    var media = hero && (q('.ks-home-hero-media', hero) || q('.ks-home-hero-banner', hero) || q('.ks-home-hero-slider a', hero) || q('a', hero) || hero);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    if (!hero || !media || !img) return;
    var src = imgSrc(img);
    if (src && !img.getAttribute('src')) img.setAttribute('src', src);
    media.classList.add('ks-onsus-hero-art-119');
    if (src) {
      media.style.setProperty('background-image', 'linear-gradient(90deg, rgba(5,5,5,.99) 0%, rgba(5,5,5,.94) 32%, rgba(5,5,5,.56) 54%, rgba(5,5,5,.13) 80%, rgba(5,5,5,0) 100%), url("' + escUrl(src) + '")', 'important');
    }
    media.style.setProperty('background-repeat', 'no-repeat,no-repeat', 'important');
    media.style.setProperty('background-size', '100% 100%, auto 158%', 'important');
    media.style.setProperty('background-position', 'center center, 88% center', 'important');
    media.style.setProperty('height', '390px', 'important');
    media.style.setProperty('min-height', '390px', 'important');
    media.style.setProperty('max-height', '390px', 'important');
    img.style.setProperty('opacity', '0', 'important');
    img.style.setProperty('visibility', 'hidden', 'important');

    var cap = q('.ks-onsus-hero-caption', media);
    if (!cap) {
      cap = document.createElement('div');
      cap.className = 'ks-onsus-hero-caption';
      media.appendChild(cap);
    }
    if (!cap.getAttribute('data-ks-step119')) {
      cap.innerHTML = '<span class="ks-hero-brand">Samsung</span>' +
        '<span class="ks-hero-sub">Odyssey Gaming Monitor G40B</span>' +
        '<span class="ks-hero-title">Uniti verso la nuova era del gioco</span>' +
        '<span class="ks-hero-specs"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span>' +
        '<a class="ks-hero-cta" href="catalogo.aspx">Scopri ora</a>';
      cap.setAttribute('data-ks-step119', '1');
    }
  }

  function polishSparseLowerBlocks() {
    qa('.ks-final-lower-grid').forEach(function (grid) {
      var visibleCols = 0;
      qa('.ks-final-lower-column', grid).forEach(function (col) {
        var count = qa('.ks-final-product-card,a[href*="articolo.aspx"]', col).length;
        col.setAttribute('data-ks-step119-items', String(count));
        if (count < 2) {
          col.classList.add('ks-lower-column-sparse');
          col.style.setProperty('display', 'none', 'important');
        } else {
          col.classList.remove('ks-lower-column-sparse');
          col.style.removeProperty('display');
          visibleCols += 1;
        }
      });
      grid.setAttribute('data-ks-step119-visible-columns', String(visibleCols));
      if (visibleCols === 2) grid.style.setProperty('grid-template-columns', 'repeat(2,minmax(0,1fr))', 'important');
      if (visibleCols <= 1) grid.style.setProperty('grid-template-columns', '1fr', 'important');
    });
  }

  function sectionPolish() {
    qa('.ks-final-title').forEach(function (row) {
      row.classList.add('ks-onsus-title-119');
      var tabs = q('.ks-onsus-tabline', row);
      if (tabs && tabs.parentNode !== row) row.appendChild(tabs);
    });
    qa('.ks-final-product-grid').forEach(function (g) { g.classList.add('ks-onsus-product-grid-119'); });
    qa('.ks-final-product-card').forEach(function (card) {
      if (!card.getAttribute('data-ks-step119-polished')) {
        card.setAttribute('data-ks-step119-polished', '1');
        var title = q('h6 a,a[href*="articolo.aspx"]', card);
        if (title) title.setAttribute('title', text(title));
      }
    });
  }

  function run() {
    if (!document.body) return;
    forceTopGrid();
    strengthenHero();
    sectionPolish();
    polishSparseLowerBlocks();
  }
  function boot() { run(); [80, 220, 520, 1000, 2200, 4600, 7600].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 120 ONSUS hero stage compositor.
   Uses the real KeepStore banner image as artwork, but renders a clean ONSUS-like stage above legacy slider markup. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function imgSrc(img) {
    if (!img) return '';
    var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
    return src;
  }
  function safeUrl(src) { return String(src || '').replace(/"/g, '%22'); }
  function heroNodes() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    var shell = section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
    var menu = shell && q('.wrap-item-1', shell);
    var hero = shell && (q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell));
    var promos = shell && q('#KsOnsusTopSidePromos', shell);
    var img = hero && (q('.ks-home-hero-slider img', hero) || q('[id$="Slide_Show_Container"] img', hero) || q('img', hero));
    return { section: section, shell: shell, menu: menu, hero: hero, promos: promos, img: img };
  }
  function enforceGrid(n) {
    if (!n.section || !n.shell || !n.hero) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-120');
    n.section.classList.add('ks-onsus-top-section-120');
    n.shell.classList.add('ks-onsus-top-wrapper-120');
    n.hero.classList.add('ks-onsus-hero-panel-120');
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    var hasPromos = !!(wide && n.promos);
    n.shell.style.setProperty('display', 'grid', 'important');
    n.shell.style.setProperty('grid-template-columns', hasPromos ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    n.shell.style.setProperty('gap', '20px', 'important');
    n.shell.style.setProperty('height', '390px', 'important');
    n.shell.style.setProperty('min-height', '390px', 'important');
    n.shell.style.setProperty('max-height', '390px', 'important');
    n.shell.style.setProperty('align-items', 'stretch', 'important');
    if (n.menu) {
      n.menu.style.setProperty('grid-column', '1', 'important');
      n.menu.style.setProperty('grid-row', '1', 'important');
      n.menu.style.setProperty('width', '285px', 'important');
      n.menu.style.setProperty('min-width', '285px', 'important');
      n.menu.style.setProperty('max-width', '285px', 'important');
      n.menu.style.setProperty('height', '390px', 'important');
      n.menu.style.setProperty('min-height', '390px', 'important');
      n.menu.style.setProperty('max-height', '390px', 'important');
      n.menu.style.setProperty('overflow', 'hidden', 'important');
    }
    n.hero.style.setProperty('grid-column', '2', 'important');
    n.hero.style.setProperty('grid-row', '1', 'important');
    n.hero.style.setProperty('position', 'relative', 'important');
    n.hero.style.setProperty('height', '390px', 'important');
    n.hero.style.setProperty('min-height', '390px', 'important');
    n.hero.style.setProperty('max-height', '390px', 'important');
    n.hero.style.setProperty('overflow', 'hidden', 'important');
    n.hero.style.setProperty('background', '#050505', 'important');
    if (n.promos) {
      n.promos.style.setProperty('grid-column', hasPromos ? '3' : 'auto', 'important');
      n.promos.style.setProperty('grid-row', '1', 'important');
      n.promos.style.setProperty('display', hasPromos ? 'grid' : 'none', 'important');
      n.promos.style.setProperty('height', '390px', 'important');
      n.promos.style.setProperty('min-height', '390px', 'important');
      n.promos.style.setProperty('max-height', '390px', 'important');
      n.promos.style.setProperty('width', '300px', 'important');
      n.promos.style.setProperty('min-width', '300px', 'important');
      n.promos.style.setProperty('max-width', '300px', 'important');
    }
  }
  function buildHeroStage(n) {
    if (!n.hero || !n.img) return;
    var src = imgSrc(n.img);
    if (!src) return;
    var stage = q('#KsOnsusHeroStage120', n.hero);
    if (!stage) {
      stage = document.createElement('div');
      stage.id = 'KsOnsusHeroStage120';
      stage.className = 'ks-onsus-hero-stage-120';
      stage.innerHTML = '<div class="ks-onsus-hero-copy-120"><span class="ks-kicker-120">Samsung</span><span class="ks-sub-120">Odyssey Gaming Monitor G40B</span><strong>Uniti verso la nuova era del gioco</strong><span class="ks-specs-120"><span>IPS</span><span>240Hz</span><span>G-SYNC</span></span><a href="catalogo.aspx" class="ks-cta-120">Scopri ora</a></div><div class="ks-onsus-hero-art-120" aria-hidden="true"></div>';
      n.hero.appendChild(stage);
    }
    stage.style.setProperty('--ks-hero-image-120', 'url("' + safeUrl(src) + '")');
    stage.setAttribute('data-ks-src', src);
    qa('.ks-onsus-hero-caption', n.hero).forEach(function (cap) { cap.style.setProperty('display', 'none', 'important'); });
    qa('.ks-home-hero-slider img,[id$="Slide_Show_Container"] img,.ks-home-hero-banner img,.ks-home-hero-media img', n.hero).forEach(function (img) {
      img.style.setProperty('opacity', '0', 'important');
      img.style.setProperty('visibility', 'hidden', 'important');
    });
    qa('.ks-home-hero-slider a,.ks-home-hero-banner,.ks-home-hero-media', n.hero).forEach(function (media) {
      media.style.setProperty('background-image', 'none', 'important');
      media.style.setProperty('background-color', '#050505', 'important');
    });
  }
  function compactLongTitles() {
    qa('.ks-final-product-info h6 a,.ks-final-lower-item strong,.ks-onsus-side-promo strong,.ks-onsus-side-promo-v3 strong').forEach(function (a) {
      if (!a.getAttribute('title')) a.setAttribute('title', String(a.textContent || '').replace(/\s+/g, ' ').trim());
    });
  }
  function run() {
    if (!document.body) return;
    var n = heroNodes();
    enforceGrid(n);
    buildHeroStage(n);
    compactLongTitles();
  }
  function boot() { run(); [80, 220, 520, 1000, 1800, 3200, 5200, 8200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 120); });
})();

/* KeepStore HOME - Step 121 ONSUS final integration cleanup.
   Keeps server-side data intact and only stabilizes visual runtime. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function text(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function heroShell() {
    var section = q('.ks-home-hero-section') || q('[id$="HomeHeroSection"]');
    return section && (q('.ks-home-hero-shell', section) || q('[id$="HomeHeroShell"]', section));
  }
  function resetDepartmentScroll() {
    var shell = heroShell();
    var menu = shell && q('.wrap-item-1', shell);
    if (!menu || menu.getAttribute('data-ks-step121-scroll-reset')) return;
    menu.setAttribute('data-ks-step121-scroll-reset', '1');
    [menu].concat(qa('*', menu)).forEach(function (el) {
      if (el && typeof el.scrollTop === 'number') el.scrollTop = 0;
    });
  }
  function enforceFinalTop() {
    var shell = heroShell();
    if (!shell) return;
    var hero = q('.wrap-item-2', shell) || q('[id$="HeroSliderWrap"]', shell);
    var promos = q('#KsOnsusTopSidePromos', shell) || q('.ks-onsus-side-promos', shell);
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-121');
    if (hero) hero.classList.add('ks-onsus-hero-final-121');
    shell.classList.add('ks-onsus-shell-final-121');
    var wide = !window.matchMedia || window.matchMedia('(min-width:1200px)').matches;
    shell.style.setProperty('display', 'grid', 'important');
    shell.style.setProperty('grid-template-columns', (wide && promos) ? '285px minmax(0,1fr) 300px' : '285px minmax(0,1fr)', 'important');
    shell.style.setProperty('gap', '20px', 'important');
    shell.style.setProperty('height', '390px', 'important');
    shell.style.setProperty('min-height', '390px', 'important');
    shell.style.setProperty('max-height', '390px', 'important');
    if (promos) promos.style.setProperty('display', wide ? 'grid' : 'none', 'important');
  }
  function hideNativeVerticalResidues() {
    var brand = q('.ks-final-brands') || q('.ks-home-brands-block') || q('[id$="HomeBrandsSection"]');
    if (!brand) return;
    var cursor = brand.nextElementSibling;
    var guard = 0;
    while (cursor && guard < 8) {
      guard += 1;
      var t = text(cursor).toLowerCase();
      var hasProduct = q('a[href*="articolo.aspx"]', cursor);
      var isFinalPanel = cursor.classList && (cursor.classList.contains('ks-home-closing-grid') || cursor.classList.contains('footer') || cursor.id === 'footer');
      if (isFinalPanel) break;
      if (hasProduct && (/in evidenza|top 20|venduti|offerta|scelti/.test(t))) {
        cursor.setAttribute('data-ks-step121-hide', '1');
      }
      cursor = cursor.nextElementSibling;
    }
  }
  function polishCards() {
    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('ks-step121-card');
      var link = q('a[href*="articolo.aspx"]', card);
      if (link && !link.getAttribute('title')) link.setAttribute('title', text(link));
      var img = q('img', card);
      if (img) {
        img.setAttribute('loading', 'lazy');
        img.setAttribute('decoding', 'async');
      }
    });
    qa('.ks-final-lower-column').forEach(function (col) {
      var items = qa('a[href*="articolo.aspx"]', col).length;
      if (items === 0) col.setAttribute('data-ks-step121-hide', '1');
    });
  }
  function normalizeTitleRows() {
    qa('.ks-final-title').forEach(function (row) {
      var tabs = q('.ks-onsus-tabline', row);
      var link = q('.ks-home-section-link', row);
      if (tabs) tabs.style.setProperty('display', 'flex', 'important');
      if (link) link.textContent = 'Vai al catalogo';
    });
  }
  function run() {
    if (!document.body) return;
    enforceFinalTop();
    resetDepartmentScroll();
    hideNativeVerticalResidues();
    polishCards();
    normalizeTitleRows();
  }
  function boot() { run(); [120, 350, 800, 1600, 3200, 6200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 160); });
})();

/* KeepStore HOME - Step 122: ONSUS Deal Today + wide product banner.
   Uses only server-rendered KeepStore products already present in the page. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.ks-final-product-info a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFrom(card) {
    if (!card) return null;
    var link = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(link && link.getAttribute('href'));
    var img = imgFrom(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(card) };
  }
  function collectProducts(limit) {
    var out = [], seen = Object.create(null);
    var selectors = [
      '#KsHomeEditorialFinal .ks-final-product-card',
      '#KsHomeBestSellerFinal .ks-final-product-card',
      '#KsHomeLowerFinal .ks-final-product-card',
      '.ks-final-product-card'
    ];
    qa(selectors.join(',')).forEach(function (card) {
      if (out.length >= (limit || 12)) return;
      var p = productFrom(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function resetMenuScroll() {
    var shell = q('.ks-home-hero-shell') || q('[id$="HomeHeroShell"]');
    var menu = shell && q('.wrap-item-1', shell);
    if (!menu) return;
    [menu].concat(qa('*', menu)).forEach(function (n) { if (n && typeof n.scrollTop === 'number') n.scrollTop = 0; });
  }
  function normalizeDealTitle() {
    var section = q('#KsHomeEditorialFinal');
    if (!section) return;
    section.classList.add('ks-onsus-deal-today-122');
    var title = q('.ks-final-title', section);
    if (!title) return;
    var kicker = q('.ks-section-kicker', title);
    var h = q('h5', title);
    var link = q('.ks-home-section-link', title);
    if (kicker) kicker.textContent = 'DEAL TODAY';
    if (h) h.innerHTML = '<span class="ks-fire-122">●</span> Occasione Imperdibile';
    if (link) link.textContent = 'Vai al catalogo';
    var grid = q('.ks-final-product-grid', section);
    if (grid) grid.classList.add('ks-onsus-deal-grid-122');
    qa('.ks-final-product-card', section).forEach(function (card, index) {
      card.classList.add('ks-onsus-deal-card-122');
      if (!q('.ks-onsus-sale-progress-122', card)) {
        var p = document.createElement('div');
        p.className = 'ks-onsus-sale-progress-122';
        var w = 44 + ((index * 11) % 35);
        p.innerHTML = '<span><i style="width:' + w + '%"></i></span>';
        card.appendChild(p);
      }
    });
  }
  function widePromoHtml(p) {
    return '<section id="KsOnsusWidePromo122" class="tf-sp-2 ks-onsus-wide-promo-122 ks-home-final-rendered" data-ks-final-home="1">' +
      '<div class="container"><a class="ks-wide-promo-inner-122" href="' + esc(p.href) + '">' +
      '<span class="ks-wide-copy-122"><em>Offerta KeepStore</em><strong>' + esc(p.title) + '</strong>' +
      (p.price ? '<b>' + esc(p.price) + '</b>' : '') + '<span>Scopri ora</span></span>' +
      '<img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async">' +
      '</a></div></section>';
  }
  function ensureWidePromo() {
    var existing = q('#KsOnsusWidePromo122');
    var deal = q('#KsHomeEditorialFinal');
    var best = q('#KsHomeBestSellerFinal');
    var products = collectProducts(6);
    var p = products[2] || products[0];
    if (!p || !deal || !best) { if (existing) existing.remove(); return; }
    if (!existing) {
      var tmp = document.createElement('div');
      tmp.innerHTML = widePromoHtml(p);
      existing = tmp.firstChild;
      best.parentNode.insertBefore(existing, best);
    } else {
      existing.outerHTML = widePromoHtml(p);
    }
  }
  function normalizeLowerColumns() {
    var lower = q('#KsHomeLowerFinal');
    if (!lower) return;
    lower.classList.add('ks-onsus-grid-collection-122');
    var title = q('.ks-final-title h5', lower);
    var kicker = q('.ks-section-kicker', lower);
    if (kicker) kicker.textContent = 'GRID COLLECTION';
    if (title) title.textContent = 'Scelte dal catalogo';
    qa('.ks-final-lower-column', lower).forEach(function (col) {
      var count = qa('.ks-final-product-card,a[href*="articolo.aspx"]', col).length;
      if (count < 2) col.setAttribute('data-ks-step122-hide', '1');
    });
  }
  function normalizeCards() {
    qa('.ks-final-product-card').forEach(function (card) {
      card.classList.add('ks-onsus-card-122');
      var title = q('h6 a,a[href*="articolo.aspx"]', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', txt(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }
  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-122');
    resetMenuScroll();
    normalizeDealTitle();
    ensureWidePromo();
    normalizeLowerColumns();
    normalizeCards();
  }
  function boot() { run(); [120, 350, 800, 1600, 3200, 6200].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 180); });
})();


/* KeepStore HOME - Step 123: restore ONSUS order.
   Deal Of The Day is separate; the normal product deck returns to In Evidenza. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function normalizeUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&'); }
  function imgFrom(root) {
    var imgs = qa('img', root);
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];
      var src = img.currentSrc || img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (!src && img.getAttribute('srcset')) src = String(img.getAttribute('srcset')).split(',')[0].trim().split(' ')[0];
      if (!src || /logo|brand|payment|visa|mastercard|paypal|placeholder|loader|spinner|sprite/i.test(src)) continue;
      return src;
    }
    return '';
  }
  function priceFrom(root) { var m = txt(root).match(/\d{1,5}(?:[\.,]\d{2})\s*€/g); return m && m.length ? m[m.length - 1] : ''; }
  function titleFrom(root) {
    var nodes = [q('h6 a', root), q('.ks-final-product-info a', root), q('.name-product', root), q('a[href*="articolo.aspx"]', root)];
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (t && t.length > 5 && !/^(scopri|compra|categoria|vai al catalogo)$/i.test(t)) return t;
    }
    return '';
  }
  function productFrom(card) {
    if (!card) return null;
    var link = q('a[href*="articolo.aspx"]', card);
    var href = normalizeUrl(link && link.getAttribute('href'));
    var img = imgFrom(card);
    var title = titleFrom(card);
    if (!href || !img || !title) return null;
    return { href: href, img: img, title: title, price: priceFrom(card) };
  }
  function getProducts(limit) {
    var out = [], seen = Object.create(null);
    qa('#KsHomeEditorialFinal .ks-final-product-card,#KsHomeBestSellerFinal .ks-final-product-card,.ks-final-product-card').forEach(function (card) {
      if (out.length >= (limit || 8)) return;
      var p = productFrom(card);
      if (!p || seen[p.href]) return;
      seen[p.href] = 1;
      out.push(p);
    });
    return out;
  }
  function dealHtml(products) {
    return '<section id="KsOnsusDealToday123" class="ks-onsus-deal123 tf-sp-2 pt-0" data-ks-final-home="1"><div class="container">' +
      '<div class="ks-deal123-title"><h5><span class="ks-deal123-fire">●</span>Deal Of The Day</h5><span></span><div class="ks-deal123-nav"><span>‹</span><span>›</span></div></div>' +
      '<div class="ks-deal123-grid">' + products.map(function (p, index) {
        var w = 48 + ((index * 13) % 34);
        return '<a class="ks-deal123-card" href="' + esc(p.href) + '">' +
          '<span class="ks-deal123-media"><img src="' + esc(p.img) + '" alt="' + esc(p.title) + '" loading="lazy" decoding="async"></span>' +
          '<span class="ks-deal123-info"><span class="ks-deal123-title-product">' + esc(p.title) + '</span>' +
          (p.price ? '<span class="ks-deal123-price">' + esc(p.price) + '</span>' : '') +
          '<span class="ks-deal123-progress"><i style="width:' + w + '%"></i></span></span></a>';
      }).join('') + '</div></div></section>';
  }
  function ensureDealStrip() {
    var editorial = q('#KsHomeEditorialFinal');
    if (!editorial) return;
    var products = getProducts(4);
    var existing = q('#KsOnsusDealToday123');
    if (products.length < 4) { if (existing) existing.remove(); return; }
    if (!existing) {
      var tmp = document.createElement('div');
      tmp.innerHTML = dealHtml(products);
      existing = tmp.firstChild;
      editorial.parentNode.insertBefore(existing, editorial);
    } else {
      existing.outerHTML = dealHtml(products);
    }
  }
  function restoreEditorialDeck() {
    var section = q('#KsHomeEditorialFinal');
    if (!section) return;
    section.classList.remove('ks-onsus-deal-today-122');
    var kicker = q('.ks-section-kicker', section);
    var h = q('.ks-final-title h5', section);
    var link = q('.ks-home-section-link', section);
    if (kicker) kicker.textContent = 'PRODOTTI KEEPSTORE';
    if (h) h.textContent = 'In Evidenza';
    if (link) link.textContent = 'Vai al catalogo';
    qa('.ks-onsus-sale-progress-122', section).forEach(function (n) { n.remove(); });
  }
  function removeBrokenWidePromo() { qa('#KsOnsusWidePromo122,.ks-onsus-wide-promo-122').forEach(function (n) { n.remove(); }); }
  function lowerGridNoEmptyPanels() {
    var lower = q('#KsHomeLowerFinal');
    if (!lower) return;
    var visible = 0;
    qa('.ks-final-lower-column', lower).forEach(function (col) {
      var count = qa('a[href*="articolo.aspx"]', col).length;
      if (count < 2) col.setAttribute('data-ks-step122-hide', '1'); else { col.removeAttribute('data-ks-step122-hide'); visible += 1; }
    });
    if (visible < 2) lower.setAttribute('data-ks-step123-hide', '1'); else lower.removeAttribute('data-ks-step123-hide');
  }
  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-123');
    removeBrokenWidePromo();
    restoreEditorialDeck();
    ensureDealStrip();
    lowerGridNoEmptyPanels();
  }
  function boot() { run(); [150, 400, 900, 1800, 3400, 6400].forEach(function (d) { window.setTimeout(run, d); }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 180); });
})();

/* KeepStore HOME - Step 124: ONSUS real order pass.
   Moves Deal Of The Day to the same semantic position as the ONSUS index
   (right after icon boxes / before department tiles) and prevents the same
   products from being repeated in the main editorial deck when possible. */
(function () {
  'use strict';
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function txt(n) { return String(n && n.textContent || '').replace(/\s+/g, ' ').trim(); }
  function normHref(href) { return String(href || '').replace(/^https?:\/\/(www\.)?(taikun\.it|webaffare\.it)/i, '').replace(/&amp;/g, '&').replace(/#.*$/, ''); }

  function section(id) { return q('#' + id); }

  function getDealUrls() {
    var urls = Object.create(null);
    qa('#KsOnsusDealToday123 a[href*="articolo.aspx"]').forEach(function (a) {
      var h = normHref(a.getAttribute('href'));
      if (h) urls[h] = 1;
    });
    return urls;
  }

  function placeDealToday() {
    var deal = section('KsOnsusDealToday123');
    if (!deal) return;

    var dept = section('KsHomeDepartmentShowcase');
    var iconBoxes = q('.ks-home-iconboxes-section, [id$="HomeIconBoxesSection"], .home-icon-boxes, .tf-icon-box, .iconbox, .tf-iconbox');

    if (dept && dept.parentNode) {
      if (deal.nextElementSibling !== dept) dept.parentNode.insertBefore(deal, dept);
      return;
    }
    if (iconBoxes && iconBoxes.parentNode && iconBoxes.nextSibling !== deal) {
      iconBoxes.parentNode.insertBefore(deal, iconBoxes.nextSibling);
    }
  }

  function preventEditorialDupes() {
    var deal = section('KsOnsusDealToday123');
    var editorial = section('KsHomeEditorialFinal');
    if (!deal || !editorial) return;
    var urls = getDealUrls();
    var cards = qa('.ks-final-product-card', editorial);
    var candidates = [];
    cards.forEach(function (card) {
      var a = q('a[href*="articolo.aspx"]', card);
      var h = normHref(a && a.getAttribute('href'));
      if (h && urls[h]) candidates.push(card);
    });
    var visibleBefore = cards.filter(function (card) { return card.getAttribute('data-ks-step124-dupe') !== '1'; }).length;
    var remaining = cards.length - candidates.length;
    if (candidates.length && remaining >= 5) {
      candidates.forEach(function (card) { card.setAttribute('data-ks-step124-dupe', '1'); });
      editorial.classList.add('ks-editorial-deduped-after-deal');
    } else if (visibleBefore < 5) {
      cards.forEach(function (card) { card.removeAttribute('data-ks-step124-dupe'); });
      editorial.classList.remove('ks-editorial-deduped-after-deal');
    }
  }

  function normalizeDealVisual() {
    var deal = section('KsOnsusDealToday123');
    if (!deal) return;
    deal.classList.add('ks-onsus-deal-real-order-124');
    var kicker = q('.ks-deal123-title h5', deal);
    if (kicker && !/Occasione/i.test(txt(kicker))) kicker.innerHTML = '<span class="ks-deal123-fire">●</span>Occasione Imperdibile';
    qa('.ks-deal123-card', deal).forEach(function (card) {
      var title = q('.ks-deal123-title-product', card);
      if (title && !title.getAttribute('title')) title.setAttribute('title', txt(title));
      var img = q('img', card);
      if (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); }
    });
  }

  function tightenOnsusRhythm() {
    qa('#KsHomeDepartmentShowcase,#KsHomeEditorialFinal,#KsHomeBestSellerFinal,#KsHomeLowerFinal,#KsHomeBrandSection,#KsHomeClosingLayer,#KsOnsusDealToday123').forEach(function (s) {
      s.classList.add('ks-onsus-rhythm-124');
    });
    var editorialTitle = q('#KsHomeEditorialFinal .ks-final-title h5');
    if (editorialTitle) editorialTitle.textContent = 'Prodotti in evidenza';
    var editorialKicker = q('#KsHomeEditorialFinal .ks-section-kicker');
    if (editorialKicker) editorialKicker.textContent = 'PRODOTTI KEEPSTORE';
    var lowerTitle = q('#KsHomeLowerFinal .ks-final-title h5');
    if (lowerTitle) lowerTitle.textContent = 'Scelte dal catalogo';
    var brandTitle = q('#KsHomeBrandSection .ks-final-title h5, #KsHomeBrandSection h5, #KsHomeBrandSection h4');
    if (brandTitle) brandTitle.textContent = 'Rivenditori ufficiali - I migliori Brand';
  }

  function run() {
    if (!document.body) return;
    document.body.classList.add('ks-page-home', 'ks-home-onsus-pass-124');
    placeDealToday();
    normalizeDealVisual();
    preventEditorialDupes();
    tightenOnsusRhythm();
  }

  function boot() {
    run();
    [120, 350, 800, 1500, 3000, 6000].forEach(function (d) { window.setTimeout(run, d); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.addEventListener('resize', function () { window.setTimeout(run, 160); });
})();
