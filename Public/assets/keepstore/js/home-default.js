(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function q(sel, root) { return (root || document).querySelector(sel); }
  function isHome() { var p = (window.location.pathname || '/').toLowerCase(); return p === '/' || /\/default\.aspx$/i.test(p); }
  function isArticle() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
  function hide(node) { if (!node) return; node.setAttribute('data-ks-hidden', '1'); node.style.setProperty('display', 'none', 'important'); }
  function show(node) { if (!node) return; node.removeAttribute('data-ks-hidden'); node.style.removeProperty('display'); }

  function buildSwiper(root, options) {
    if (!root || root.swiper || typeof Swiper === 'undefined') return null;
    return new Swiper(root, options);
  }
  function updateAllSwipers() {
    qa('.swiper').forEach(function (el) { if (el.swiper && typeof el.swiper.update === 'function') el.swiper.update(); });
  }
  function initHero() {
    var hero = q('.ks-home-hero-slider');
    if (!hero) return;
    var slides = qa('.swiper-slide', hero).filter(function (slide) { return q('img[src],img[data-src]', slide); });
    var allowLoop = slides.length > 1;
    var prev = q('.ks-hero-prev', hero);
    var next = q('.ks-hero-next', hero);
    var pag = q('.ks-hero-pagination', hero);
    buildSwiper(hero, { loop: allowLoop, effect: 'slide', speed: 700, autoplay: allowLoop ? { delay: 5000, disableOnInteraction: false, pauseOnMouseEnter: true } : false, pagination: { el: pag, clickable: true }, navigation: { nextEl: next, prevEl: prev } });
    if (!allowLoop) { hide(prev); hide(next); hide(pag); }
  }
  function initBrandSlider() {
    var brand = q('.ks-home-brands');
    if (!brand) return;
    buildSwiper(brand, { loop: qa('.swiper-slide', brand).filter(function (s) { return s.offsetParent !== null; }).length > 6, slidesPerView: 2, spaceBetween: 15, breakpoints: { 576: { slidesPerView: 3, spaceBetween: 15 }, 768: { slidesPerView: 4, spaceBetween: 20 }, 1200: { slidesPerView: 6, spaceBetween: 30 } }, pagination: { el: q('.ks-home-brands-pagination', brand), clickable: true }, autoplay: { delay: 3500, disableOnInteraction: false } });
  }
  function initCollectionSlider() {
    var slider = q('.ks-home-collection-swiper');
    if (!slider) return;
    buildSwiper(slider, { loop: qa('.swiper-slide', slider).length > 4, slidesPerView: 1, spaceBetween: 15, breakpoints: { 576: { slidesPerView: 2, spaceBetween: 15 }, 768: { slidesPerView: 3, spaceBetween: 20 }, 1200: { slidesPerView: 4, spaceBetween: 30 } }, pagination: { el: q('.ks-home-collection-pagination', slider), clickable: true }, autoplay: { delay: 4000, disableOnInteraction: false } });
  }
  function initColumnSwipers() {
    qa('.ks-column-swiper').forEach(function (el) {
      if (!el || el.swiper || typeof Swiper === 'undefined') return;
      var wrapper = el.closest('.box-btn-slide-item') || el.parentElement;
      var prev = wrapper ? q('.ks-col-prev', wrapper) : null;
      var next = wrapper ? q('.ks-col-next', wrapper) : null;
      var pag = q('.ks-col-pagination', el);
      var slides = qa('.swiper-slide', el).filter(function (s) { return s.offsetParent !== null; }).length;
      buildSwiper(el, { loop: slides > 1, slidesPerView: 1, spaceBetween: 20, pagination: { el: pag, clickable: true }, navigation: { nextEl: next, prevEl: prev }, autoplay: slides > 1 ? { delay: 4500, disableOnInteraction: false } : false });
      if (slides <= 1) { hide(prev); hide(next); hide(pag); }
    });
  }
  function normalizeCardHeights() {
    ['.ks-grid-card .card-product-info', '.ks-row-card .card-product-info', '.ks-deal-card .card-product-info'].forEach(function (selector) {
      var nodes = qa(selector); if (!nodes.length) return;
      nodes.forEach(function (n) { n.style.minHeight = '0px'; });
      var max = 0; nodes.forEach(function (n) { max = Math.max(max, n.offsetHeight || 0); });
      if (window.innerWidth >= 992) nodes.forEach(function (n) { n.style.minHeight = max + 'px'; });
    });
  }
  function syncHeroLayout() {
    var shell = q('.ks-home-hero-shell');
    var menu = q('.ks-home-departments .menu-category-list');
    if (!shell || !menu) return;
    var sliderWrap = q('.wrap-item-2', shell);
    if (window.innerWidth < 1200) { menu.style.minHeight = ''; menu.style.maxHeight = ''; return; }
    var target = sliderWrap && sliderWrap.offsetParent !== null ? (sliderWrap.offsetHeight || 0) : 0;
    if (target > 0) { menu.style.minHeight = target + 'px'; menu.style.maxHeight = Math.max(420, target) + 'px'; }
  }
  function refreshSwipersInTabs() {
    qa('[data-bs-toggle="tab"]').forEach(function (trigger) { trigger.addEventListener('shown.bs.tab', function () { updateAllSwipers(); window.setTimeout(normalizeCardHeights, 80); }); });
  }
  function bindImageDrivenRefresh() {
    qa('.ks-page-home img').forEach(function (img) { if (!img || img.complete) return; img.addEventListener('load', function () { window.setTimeout(function () { updateAllSwipers(); normalizeCardHeights(); syncHeroLayout(); }, 60); }, { once: true }); });
  }
  function normalizeImages() {
    qa('.ks-grid-card img,.ks-big-card img,.ks-deal-card img,.ksh-grid-card img,.ksh-big img,.ksh-deal img').forEach(function (img) { img.setAttribute('loading', 'lazy'); img.setAttribute('decoding', 'async'); });
  }

  function readCookie(name) {
    var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }
  function writeCookie(name, value, days) {
    var d = new Date();
    d.setTime(d.getTime() + (days || 365) * 86400000);
    document.cookie = String(name || '') + '=' + encodeURIComponent(String(value || '')) + '; expires=' + d.toUTCString() + '; path=/; SameSite=Lax';
  }
  function parseIds(raw) {
    return String(raw || '').split(',').map(function (x) { return parseInt(x, 10); }).filter(function (n) { return Number.isFinite(n) && n > 0; });
  }
  function mergedRecent() {
    var out = [], seen = {};
    var session = [];
    try { session = parseIds(window.sessionStorage.getItem('ks_recent_session') || ''); } catch (e) {}
    [session, parseIds(readCookie('ks_recent'))].forEach(function (list) {
      list.forEach(function (id) { if (!seen[id]) { seen[id] = 1; out.push(id); } });
    });
    return out.slice(0, 100);
  }
  function storeRecent(id) {
    if (!id) return;
    var next = [id].concat(mergedRecent().filter(function (x) { return x !== id; })).slice(0, 100);
    try { window.sessionStorage.setItem('ks_recent_session', next.join(',')); } catch (e) {}
    writeCookie('ks_recent', next.join(','), 365);
  }
  function trackArticleRecent() {
    if (!isArticle()) return;
    var id = 0;
    try { id = parseInt(new URLSearchParams(window.location.search || '').get('id'), 10) || 0; } catch (e) {}
    if (!id) {
      var can = q('link[rel="canonical"]');
      var href = can ? can.getAttribute('href') || '' : '';
      var m = href.match(/[?&]id=(\d+)/i);
      id = m ? parseInt(m[1], 10) : 0;
    }
    storeRecent(id);
  }

  function norm(s) { return String(s || '').toLowerCase().replace(/[àáâãäå]/g, 'a').replace(/[èéêë]/g, 'e').replace(/[ìíîï]/g, 'i').replace(/[òóôõö]/g, 'o').replace(/[ùúûü]/g, 'u').replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim(); }
  function displayKey(text) {
    var block = { black:1, white:1, red:1, blue:1, green:1, yellow:1, pink:1, gold:1, silver:1, grey:1, gray:1, nero:1, bianco:1, rosso:1, blu:1, verde:1, giallo:1, rosa:1, oro:1, argento:1, grigio:1, clear:1, case:1, cover:1, custodia:1, shell:1, glass:1, tempered:1, protector:1, protezione:1, trasparente:1, mm:1, cm:1, gb:1, tb:1, xl:1, xxl:1, taglia:1, colore:1, con:1, per:1, the:1, for:1 };
    return norm(text).split(' ').filter(function (t) { return t && !block[t] && !/^\d+$/.test(t) && !/^\d+(mm|cm|gb|tb)$/.test(t); }).slice(0, 8).join(' ');
  }
  function cardId(node) {
    var a = node && (node.matches('a[href*="articolo.aspx?id="]') ? node : q('a[href*="articolo.aspx?id="]', node));
    var href = a ? a.getAttribute('href') || '' : '';
    var m = href.match(/[?&]id=(\d+)/i);
    return m ? parseInt(m[1], 10) : 0;
  }
  function cardTitle(node) {
    var n = q('.title,.product-title,.name-product,h5,h6,a[href*="articolo.aspx?id="]', node) || node;
    return (n.textContent || '').replace(/\s+/g, ' ').trim();
  }
  function dedupeBlock(root) {
    if (!root) return;
    var seenIds = {}, seenKeys = {};
    qa('.swiper-slide,.card-product,.ks-row-card,.ks-grid-card,.ksh-side,.ksh-grid-card,.ksh-deal', root).forEach(function (card) {
      var id = cardId(card);
      var key = displayKey(cardTitle(card));
      if ((id && seenIds[id]) || (key && seenKeys[key])) hide(card);
      else { if (id) seenIds[id] = 1; if (key) seenKeys[key] = 1; }
    });
  }
  function countVisibleProducts(root) {
    if (!root) return 0;
    var ids = {};
    qa('a[href*="articolo.aspx?id="],.card-product,.ks-row-card,.ks-grid-card,.ksh-side,.ksh-grid-card,.ksh-deal', root).forEach(function (node) {
      if (node.closest('[data-ks-hidden="1"]')) return;
      var id = cardId(node) || (node.textContent || '').length;
      if (id) ids[id] = 1;
    });
    return Object.keys(ids).length;
  }
  function hideBelowThresholds() {
    var lowerRules = [
      ['#Top20Block', 3], ['#LowerFeaturedBlock', 3], ['#TopSellingBlock', 3], ['#OnSaleBlock', 3], ['#HomeRecentlyViewedSection', 2]
    ];
    lowerRules.forEach(function (rule) { var node = q(rule[0]); if (node) { dedupeBlock(node); if (countVisibleProducts(node) < rule[1]) hide(node); } });
    var lower = q('#HomeLowerColumnsSection');
    if (lower && !qa('#Top20Block,#LowerFeaturedBlock,#TopSellingBlock,#OnSaleBlock', lower).some(function (n) { return n.offsetParent !== null && n.getAttribute('data-ks-hidden') !== '1'; })) hide(lower);
  }
  function pruneRuntimeSections() {
    ['.flat-animate-tab', '.ks-home-v6-block', '.ks-home-v6-lower-col', '.ks-home-v6-viewed', '.ks-home-v6-deals'].forEach(function (sel) { qa(sel).forEach(dedupeBlock); });
  }
  function forceHeroMode() {
    var section = q('#HomeHeroSection');
    var shell = q('#HomeHeroShell');
    var slider = q('#HeroSliderWrap');
    var side = q('#HeroSideWrap');
    hide(side);
    if (!section || !shell) return;
    var hasHero = qa("#HeroSliderWrap img").some(function (img) { var src = (img.getAttribute("src") || img.getAttribute("data-src") || "").trim(); return src && src !== "#"; });
    [section, shell].forEach(function (n) {
      n.className = String(n.className || '').replace(/\bks-home-hero-mode-[^\s]+\b/g, '').replace(/\s+/g, ' ').trim();
      n.classList.add(hasHero ? 'ks-home-hero-mode-compact-single' : 'ks-home-hero-mode-none');
    });
    shell.classList.add('ks-home-force-compact');
    if (hasHero) { show(section); show(slider); } else { hide(section); hide(slider); }
  }
  function cleanArtifacts() {
    var bad = /welcome|franchis|themeforest|themesflat|onsus-package|home-[0-9]+\.html|mediacom/i;
    qa('body > * , form > * , #wrapper > *').forEach(function (node) {
      if (!node || node.matches('form,#wrapper,script,style,link,input,header,main,footer')) return;
      if (node.closest && node.closest('#wrapper header,#wrapper footer,#HomeHeroSection,#HomeBrandsSection,.container')) return;
      var text = (node.textContent || '') + ' ' + (node.getAttribute ? ((node.getAttribute('src') || '') + ' ' + (node.getAttribute('href') || '') + ' ' + (node.getAttribute('class') || '')) : '');
      if (bad.test(text)) hide(node);
    });
    qa('img').forEach(function (img) {
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      var alt = img.getAttribute('alt') || '';
      if (bad.test(src + ' ' + alt) && !img.closest('#HomeHeroSection,#HomeBrandsSection,.container')) hide(img.closest('a,div,section,li') || img);
    });
  }
  function plausibleLogo(img) {
    if (!img) return false;
    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    var alt = img.getAttribute('alt') || '';
    if (!src) return false;
    if (/(banner|hero|promo|slider|product|articolo|phone|tablet|demo|themeforest|franchis|welcome|home-[0-9]+\.html)/i.test(src + ' ' + alt)) return false;
    return true;
  }
  function fixBrands() {
    var section = q('#HomeBrandsSection');
    if (!section) return;
    var valid = 0;
    qa('.swiper-slide', section).forEach(function (slide) {
      var img = q('img', slide);
      if (!plausibleLogo(img)) { hide(slide); return; }
      valid += 1;
    });
    if (valid < 1) hide(section);
  }
  function repair() {
    if (!isHome()) return;
    forceHeroMode();
    cleanArtifacts();
    hideBelowThresholds();
    pruneRuntimeSections();
    fixBrands();
    normalizeImages();
    syncHeroLayout();
    updateAllSwipers();
  }
  function boot() {
    if (isArticle()) trackArticleRecent();
    if (!isHome()) return;
    initHero(); initBrandSlider(); initCollectionSlider(); initColumnSwipers(); normalizeImages(); normalizeCardHeights(); syncHeroLayout(); refreshSwipersInTabs(); bindImageDrivenRefresh(); repair();
    [250, 800, 1600, 3200, 6400].forEach(function (ms) { window.setTimeout(repair, ms); });
    window.addEventListener('resize', function () { normalizeCardHeights(); syncHeroLayout(); updateAllSwipers(); });
    if (window.MutationObserver) {
      var t;
      new MutationObserver(function () { clearTimeout(t); t = setTimeout(repair, 120); }).observe(document.body, { childList: true, subtree: true });
    }
  }
  onReady(boot);
})();

;(function(){
  'use strict';
  function ready(fn){ if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',fn); else fn(); }
  function qa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function q(sel,root){ return (root||document).querySelector(sel); }
  function isHome(){ var p=(window.location.pathname||'/').toLowerCase(); return p==='/' || /\/default\.aspx$/i.test(p); }
  function hide(node,kind){ if(!node) return; node.setAttribute('data-ks-artifact',kind||'edge'); node.setAttribute('data-ks-hidden','1'); node.style.setProperty('display','none','important'); node.style.setProperty('visibility','hidden','important'); node.style.setProperty('opacity','0','important'); node.style.setProperty('pointer-events','none','important'); }
  function rect(node){ try{return node&&node.getBoundingClientRect?node.getBoundingClientRect():null;}catch(e){return null;} }
  function lane(){
    var rs=qa('#HomeHeroSection > .container, main .container, #wrapper .container').map(rect).filter(function(r){return r&&r.width>420&&r.height>20;});
    if(!rs.length) return {left:Math.max(0,(window.innerWidth-1200)/2),right:Math.min(window.innerWidth,(window.innerWidth+1200)/2)};
    rs.sort(function(a,b){return b.width-a.width;});
    return rs[0];
  }
  function outside(r,l){ if(!r||!l) return false; var c=r.left+r.width/2; return c<l.left-10 || c>l.right+10 || r.right<l.left-10 || r.left>l.right+10; }
  function safe(node){
    return !!(node&&node.closest&&node.closest('header,footer,#HomeHeroSection .wrap-item-1,#HeroSliderWrap,.ks-home-departments,.tf-icon-box,.card-product,.ks-row-card,.ks-grid-card,.ks-deal-card,.ksh-side,.ksh-grid-card,.ksh-deal,.ksh-big,#HomeBrandsSection,.ks-home-brand-item,.ks-home-v6'));
  }
  function root(node){
    var cur=node,h=0;
    while(cur&&cur.parentElement&&h<7){
      var p=cur.parentElement;
      if(!p||/^(body|form|main|header|footer)$/i.test(p.tagName)) break;
      if(p.id==='wrapper'||p.classList.contains('ks-account-main')) break;
      if(p.matches&&p.matches('.container,.swiper-wrapper,.tab-pane,.tf-grid-product,.product-list-wrap')) break;
      var r=rect(p); if(r&&r.width>Math.min(window.innerWidth*.45,560)) break;
      cur=p; h++;
    }
    return cur||node;
  }
  function killText(){
    var bad=/welcome|franchis|themeforest|themesflat|onsus|mediacom|home-[0-9]+\.html/i;
    qa('body *').forEach(function(n){
      if(!n||n.nodeType!==1||n.matches('script,style,link,meta,head,title,input,select,textarea')) return;
      var txt=(n.textContent||'')+' '+(n.getAttribute('src')||'')+' '+(n.getAttribute('data-src')||'')+' '+(n.getAttribute('href')||'')+' '+(n.getAttribute('class')||'')+' '+(n.getAttribute('alt')||'');
      if(!bad.test(txt)) return;
      if(safe(n)&&!/welcome|franchis/i.test(txt)) return;
      var r=rect(n); if(r&&(r.width>window.innerWidth*.75||r.height<14)) return;
      hide(root(n),/welcome|franchis/i.test(txt)?'franchising':'demo');
    });
  }
  function killMedia(){
    var l=lane(), groups={};
    qa('img').forEach(function(img){
      if(!img||safe(img)) return;
      var r=rect(img); if(!r||r.width<24||r.height<24) return;
      var src=(img.getAttribute('src')||img.getAttribute('data-src')||'').split('?')[0];
      var probe=src+' '+(img.getAttribute('alt')||'')+' '+(img.getAttribute('class')||'');
      if(/welcome|franchis|themeforest|themesflat|onsus|mediacom|demo|home-[0-9]+\.webp|phone|tablet|mobile/i.test(probe)){ hide(root(img),/welcome|franchis/i.test(probe)?'franchising':'side-media'); return; }
      if(!outside(r,l)) return;
      var key=src||('pos-'+Math.round(r.left)+'-'+Math.round(r.top));
      (groups[key]=groups[key]||[]).push(img);
    });
    Object.keys(groups).forEach(function(k){ if(groups[k].length<2) return; groups[k].forEach(function(img){hide(root(img),'side-media');}); });
  }
  function killFloating(){
    var l=lane();
    qa('body *').forEach(function(n){
      if(!n||n.nodeType!==1||safe(n)||n.matches('script,style,link,meta,input,select,textarea,#wrapper,form,main,header,footer')) return;
      var r=rect(n); if(!r||r.width<24||r.height<36) return;
      var cs; try{cs=window.getComputedStyle(n);}catch(e){cs=null;}
      var floating=cs&&/fixed|absolute|sticky/i.test(cs.position||'');
      var txt=(n.textContent||'')+' '+(n.getAttribute('class')||'')+' '+(n.getAttribute('id')||'');
      var media=qa('img,svg,video,picture',n).length;
      if((floating||media>=1)&&outside(r,l)) hide(root(n),'edge');
      else if(/welcome|franchis|themeforest|themesflat|onsus|mediacom/i.test(txt)) hide(root(n),'franchising');
    });
  }
  function killClones(){
    var h=q('#wrapper header,header.tf-header,header');
    var b=h?((rect(h)||{bottom:100}).bottom+window.pageYOffset):100;
    qa('header,.tf-header,.tf-topbar,.header-bottom,.inner-header,.tf-footer,footer').forEach(function(n,i){
      var r=rect(n); if(!r) return;
      var top=r.top+window.pageYOffset;
      if(i>0&&top>b+220&&r.width>window.innerWidth*.45) hide(n,'header-clone');
    });
  }
  function run(){ if(!isHome()) return; killText(); killMedia(); killFloating(); killClones(); }
  ready(function(){ run(); [50,150,400,900,1800,3600,7200,12000,18000].forEach(function(ms){window.setTimeout(run,ms);}); if(window.MutationObserver){var t; new MutationObserver(function(){clearTimeout(t); t=setTimeout(run,80);}).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['src','data-src','style','class']});} });
})();

;(function(){
  'use strict';
  function ready(fn){ if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',fn); else fn(); }
  function qa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function q(sel,root){ return (root||document).querySelector(sel); }
  function isHome(){ var p=(location.pathname||'/').toLowerCase(); return p==='/' || /\/default\.aspx$/i.test(p); }
  function hide(n){ if(!n) return; n.setAttribute('data-ks-artifact','post-brand-legacy'); n.setAttribute('data-ks-hidden','1'); n.style.setProperty('display','none','important'); }
  function rect(n){ try{return n&&n.getBoundingClientRect?n.getBoundingClientRect():null;}catch(e){return null;} }
  function killPostBrandLegacyCommercials(){
    if(!isHome()) return;
    var brand=q('#HomeBrandsSection,.ks-home-brands-block');
    var br=rect(brand); if(!brand||!br) return;
    var brandBottom=br.bottom+pageYOffset;
    qa('main section,#wrapper section').forEach(function(sec){
      if(sec===brand||sec.id==='HomeRecentlyViewedSection'||sec.closest('#HomeRecentlyViewedSection')) return;
      var sr=rect(sec); if(!sr) return;
      var top=sr.top+pageYOffset;
      if(top<=brandBottom+20) return;
      var title=((q('h1,h2,h3,h4,h5,h6',sec)||{}).textContent||'').replace(/\s+/g,' ').trim().toLowerCase();
      if(/^(best seller|in evidenza|top 20|i pi[uù]'? venduti|in offerta|offerte|nuovi arrivi)$/.test(title)) hide(sec);
    });
  }
  ready(function(){ killPostBrandLegacyCommercials(); [250,900,2400,6000,12000].forEach(function(ms){setTimeout(killPostBrandLegacyCommercials,ms);}); });
})();
