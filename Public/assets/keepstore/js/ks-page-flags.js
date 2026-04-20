(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';

  function onReady(fn) { if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn); else fn(); }
  function isHomePage() { var pathname = window.location.pathname || '/'; return pathname === '/' || /\/default\.aspx$/i.test(pathname); }
  function isArticlePage() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
  function addBodyClass(name) { if (document.body && name) document.body.classList.add(name); }
  function getQueryParam(name) { try { return new URLSearchParams(window.location.search || '').get(name); } catch (err) { return null; } }
  function readCookie(name) { var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)')); return match ? decodeURIComponent(match[1]) : ''; }
  function writeCookie(name, value, days) { var expires=''; if (typeof days==='number' && days>0) { var d=new Date(); d.setTime(d.getTime()+(days*86400000)); expires='; expires='+d.toUTCString(); } document.cookie=String(name||'')+'='+encodeURIComponent(String(value||''))+expires+'; path=/; SameSite=Lax'; }
  function parseRecentList(raw) { return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) { return Number.isFinite(id) && id > 0; }); }
  function readSessionRecent() { try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; } }
  function writeSessionRecent(list) { try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {} }
  function mergeRecentLists(primary, secondary) { var seen={}, merged=[]; [primary||[],secondary||[]].forEach(function(list){ list.forEach(function(id){ if(!Number.isFinite(id)||id<=0||seen[id]) return; seen[id]=1; merged.push(id); }); }); return merged.slice(0,MAX_RECENT); }
  function readMergedRecent() { return mergeRecentLists(readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))); }
  function persistRecentList(list) { var next=(list||[]).filter(function(id){ return Number.isFinite(id)&&id>0; }).slice(0,MAX_RECENT); writeCookie(COOKIE_NAME,next.join(','),365); writeSessionRecent(next); }
  function updateRecentList(id) { var merged=readMergedRecent(); var next=[id].concat(merged.filter(function(item){ return item!==id; })).slice(0,MAX_RECENT); persistRecentList(next); return next; }
  function parseArticleIdFromHref(href) { if (!href) return 0; var match = String(href).match(/[?&]id=(\d+)/i); return match ? parseInt(match[1], 10) : 0; }
  function detectArticleId() { var direct=parseInt(getQueryParam('id'),10); if(Number.isFinite(direct)&&direct>0) return direct; var canonical=document.querySelector('link[rel="canonical"]'); var fromCanonical=canonical?parseArticleIdFromHref(canonical.getAttribute('href')||''):0; if(fromCanonical>0) return fromCanonical; if(document.body){ var bodyId=parseInt(document.body.getAttribute('data-article-id')||document.body.getAttribute('data-id')||'',10); if(Number.isFinite(bodyId)&&bodyId>0) return bodyId; } return 0; }
  function trackArticleRecent() { if (!isArticlePage()) return; var id=detectArticleId(); if (Number.isFinite(id) && id>0) updateRecentList(id); }

  function normalizeText(value) { var text=String(value||'').toLowerCase(); try { text=text.normalize('NFD').replace(/[\u0300-\u036f]/g,''); } catch(err) {} return text.replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim(); }
  function containsToken(raw) { var value=normalizeText(raw); return BLOCKED_TOKENS.some(function(token){ return value.indexOf(token)!==-1; }); }
  function rectOf(node) { if(!node||typeof node.getBoundingClientRect!=='function') return null; var rect=node.getBoundingClientRect(); if(!rect||(!rect.width&&!rect.height)) return null; return rect; }
  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g,' ').trim(); }
  function hideNode(node, flag) { if(!node||!node.style) return; node.style.setProperty('display','none','important'); node.style.setProperty('visibility','hidden','important'); node.style.setProperty('opacity','0','important'); node.style.setProperty('pointer-events','none','important'); if(flag) node.setAttribute(flag,'1'); }
  function all(root, sel){ return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function first(root, sel){ return (root || document).querySelector(sel); }
  function esc(v){ return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function fetchJson(url){ return fetch(url, { credentials:'same-origin', headers:{ 'X-Requested-With':'XMLHttpRequest' }}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }); }
  function shuffle(list){ var out=(list||[]).slice(); for(var i=out.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var t=out[i]; out[i]=out[j]; out[j]=t; } return out; }
  function currentLang(){ var html = document.documentElement.getAttribute('lang') || ''; return /^en/i.test(html) ? 'en' : 'it'; }
  function itemImages(item){ var out=[]; var seen={}; (item && item.images || []).forEach(function(src){ src=String(src||'').trim(); if(!src||seen[src]) return; seen[src]=1; out.push(src); }); if(item && item.preview && !seen[item.preview]) out.unshift(item.preview); if(item && item.image && !seen[item.image]) out.unshift(item.image); return out.filter(Boolean).slice(0,5); }
  function imageOf(item){ var imgs=itemImages(item); return imgs.length ? imgs[0] : ''; }
  function money(item){ return '<div class="ks-runtime-price">' + (item && item.price ? ('<span class="new">€' + esc(item.price) + '</span>') : '') + (item && item.oldPrice ? ('<span class="old">€' + esc(item.oldPrice) + '</span>') : '') + '</div>'; }
  function meta(item){ var bits=[]; if(item && item.brand) bits.push('<span>'+esc(item.brand)+'</span>'); if(item && item.category) bits.push('<span>'+esc(item.category)+'</span>'); return '<div class="ks-runtime-meta">' + bits.join('') + '</div>'; }
  function sideCard(item){ var img=imageOf(item); return '<a class="ks-runtime-side-card ks-onsus-font" href="'+esc(item.url||'#')+'"><span class="ks-runtime-side-thumb">'+(img?'<img src="'+esc(img)+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '')+'</span><span class="ks-runtime-side-body">'+meta(item)+'<span class="ks-runtime-title">'+esc(item.title||'')+'</span>'+money(item)+'</span></a>'; }
  function gridCard(item){ var img=imageOf(item); return '<a class="ks-runtime-grid-card ks-onsus-font" href="'+esc(item.url||'#')+'"><span class="ks-runtime-grid-thumb">'+(img?'<img src="'+esc(img)+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '')+'</span><span class="ks-runtime-grid-body">'+meta(item)+'<span class="ks-runtime-title">'+esc(item.title||'')+'</span>'+money(item)+'</span></a>'; }
  function bigCard(item){ var imgs=itemImages(item); var main=imgs[0]||''; var thumbs=imgs.slice(0,4); return '<div class="ks-runtime-big-card ks-onsus-font"><div class="ks-runtime-big-main"><a class="ks-runtime-big-media" href="'+esc(item.url||'#')+'">'+(main?'<img src="'+esc(main)+'" data-main="1" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '')+'</a><div class="ks-runtime-big-body">'+meta(item)+'<a class="ks-runtime-title ks-runtime-title-big" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a><div class="ks-runtime-bottom">'+money(item)+'<ul class="ks-runtime-actions"><li><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a></li><li><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a></li><li><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a></li><li><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></li></ul></div></div></div><div class="ks-runtime-big-thumbs">'+thumbs.map(function(src,idx){ return '<button type="button" class="ks-runtime-big-thumb'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">'+(src?'<img src="'+esc(src)+'" alt=""/>' : '')+'</button>'; }).join('')+'</div></div>'; }
  function bindFallbackImages(root){ all(root, 'img[data-fallback]').forEach(function(img){ img.addEventListener('error', function onErr(){ img.removeEventListener('error', onErr); var fb=img.getAttribute('data-fallback')||''; if(fb && img.src !== fb) img.src = fb; }); }); }
  function bindBigThumbs(root){ all(root, '.ks-runtime-big-card').forEach(function(card){ var main=first(card,'.ks-runtime-big-media img[data-main="1"]'); all(card,'.ks-runtime-big-thumb').forEach(function(btn){ btn.addEventListener('click', function(){ all(card,'.ks-runtime-big-thumb').forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); if(main){ main.src = btn.getAttribute('data-img') || main.src; } }); }); }); }

  function suppressNewsletterPopup() {
    all(document, '.auto-popup, .modal-newleter, [class*="modal-newleter"]').forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); });
    all(document, '.modal-backdrop, .offcanvas-backdrop').forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); if(node.parentNode) node.parentNode.removeChild(node); });
    if(document.body){ document.body.classList.remove('modal-open'); document.body.style.removeProperty('overflow'); document.body.style.removeProperty('padding-right'); }
  }

  function compactHero() {
    var shell=document.querySelector('.ks-home-hero-shell');
    var sideWrap=document.getElementById('HeroSideWrap');
    var menuList=document.querySelector('.ks-home-departments .menu-category-list');
    var sliderWrap=document.getElementById('HeroSliderWrap') || (shell ? shell.querySelector('.wrap-item-2') : null);
    if(!shell || !sliderWrap) return;
    if(window.innerWidth<1200){
      shell.classList.remove('ks-home-force-compact');
      if(menuList){ menuList.style.maxHeight=''; menuList.style.height=''; }
      return;
    }
    shell.classList.add('ks-home-force-compact');
    shell.classList.remove('ks-home-hero-mode-full');
    shell.classList.add('ks-home-hero-mode-compact-single');
    if(sideWrap) hideNode(sideWrap, 'data-ks-home-artifact');
    if(menuList){
      var rr=rectOf(sliderWrap);
      if(rr && rr.height>220){
        var h=Math.max(520, Math.floor(rr.height));
        menuList.style.maxHeight=h+'px';
        menuList.style.height=h+'px';
      }
    }
  }

  function insideProtected(node) {
    return !!(node && node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-departments, .ks-home-hero-shell, .card-product, .product-list-wrap, .tf-grid-product-item, .swiper, .ks-runtime-section, .ks-runtime-recent-section'));
  }

  function hideWelcomeFranchisingAnywhere() {
    all(document, 'div,section,aside,span,p,a,img').forEach(function(node){
      if(!node || insideProtected(node)) return;
      var raw=[node.id||'', node.className||'', textOf(node).slice(0,300), node.getAttribute ? (node.getAttribute('src')||node.getAttribute('data-src')||node.getAttribute('alt')||'') : ''].join(' ');
      if(containsToken(raw)) hideNode(node, 'data-ks-franchising-artifact');
    });
  }

  function hideBodyArtifacts() {
    var wrapper=document.getElementById('wrapper');
    if(!wrapper) return;
    var form=document.querySelector('body > form') || document.querySelector('form');
    if(form){
      Array.prototype.slice.call(form.children).forEach(function(node){
        if(!node || node.id==='wrapper') return;
        if(/^(SCRIPT|STYLE|LINK)$/i.test(node.tagName)) return;
        if(node.tagName==='INPUT' && String(node.type||'').toLowerCase()==='hidden') return;
        hideNode(node,'data-ks-body-artifact');
      });
    }
  }

  function hideHeaderClones() {
    var header=document.querySelector('header') || document.querySelector('.tf-header');
    var headerBottom=header ? (rectOf(header)||{bottom:0}).bottom : 0;
    all(document, 'header, div, section').forEach(function(node){
      if(!node || node===header) return;
      if(header && header.contains(node)) return;
      if(insideProtected(node)) return;
      var rect=rectOf(node);
      if(!rect || rect.top<headerBottom+120) return;
      if(rect.width<window.innerWidth*0.55 || rect.height<24 || rect.height>220) return;
      var raw=normalizeText([node.className||'', textOf(node).slice(0,220)].join(' '));
      if(/cerca prodotti|tutti i settori|il mio account|assistenza|spedizione gratuita|chiamaci gratis/.test(raw)) {
        hideNode(node, 'data-ks-header-clone');
      }
    });
  }

  function findHeading(regex){
    var nodes = all(document, 'h1,h2,h3,h4,h5,h6,a,button,span,li');
    for(var i=0;i<nodes.length;i++){
      var t = normalizeText(textOf(nodes[i]));
      if(regex.test(t)) return nodes[i];
    }
    return null;
  }
  function closestSection(node){ return node ? (node.closest('section, .tf-sp-2, .tf-sp-5, .container, .flat-animate-tab') || node.parentNode) : null; }
  function hideSection(node){ if(node) node.setAttribute('data-ks-hidden-section','1'); }
  function countCards(node){ return all(node, '.card-product, .ks-runtime-grid-card, .ks-runtime-side-card, .swiper-slide').length; }
  function feedUrl(){ var url = new URL(FEED_ENDPOINT, location.href); url.searchParams.set('mode','sections'); var ids = readMergedRecent(); if(ids.length) url.searchParams.set('recent', ids.slice(0,12).join(',')); url.searchParams.set('_', String(Date.now())); return url.toString(); }
  function uniqueById(list){ var seen={}, out=[]; (list||[]).forEach(function(item){ var id = parseInt(item && item.id,10) || 0; if(!id || seen[id]) return; seen[id]=1; out.push(item); }); return out; }
  function titleMap(){ return currentLang().indexOf('en')===0 ? { offers:'On Sale', featured:'Featured', arrivals:'New Arrivals', topViewed:'Most Viewed', top20:'Top 20', topSelling:'Top Selling', best:'Best Seller' } : { offers:'Offerte', featured:'In Evidenza', arrivals:'Nuovi Arrivi', topViewed:'I più visti', top20:'Top 20', topSelling:'I Più Venduti', best:'Best Seller' }; }

  function renderRuntimeTabbedSection(sections){
    if(!isHomePage() || first(document, '.ks-runtime-tabbed-section')) return;
    var anchor = findHeading(/^offerte$/) || findHeading(/in evidenza/) || findHeading(/nuovi arrivi/);
    var host = anchor ? closestSection(anchor) : null;
    if(!host || !host.parentNode) return;
    var tm = titleMap();
    var panels = [
      { key:'offerte', title: tm.offers, items: uniqueById(sections.offerte || []).slice(0,7) },
      { key:'evidenza', title: tm.featured, items: uniqueById(sections.evidenza || []).slice(0,7) },
      { key:'nuovi', title: tm.arrivals, items: uniqueById(sections.nuovi || []).slice(0,7) }
    ].filter(function(p){ return p.items.length >= 3; });
    if(!panels.length) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-tabbed-section';
    wrapper.innerHTML = '<div class="container"><div class="ks-runtime-tabs-head">' + panels.map(function(p, idx){ return '<button type="button" class="ks-runtime-tab-btn'+(idx===0?' is-active':'')+'" data-panel="'+esc(p.key)+'">'+esc(p.title)+'</button>'; }).join('') + '</div><div class="ks-runtime-panels">' + panels.map(function(p, idx){ var items=shuffle(p.items).slice(0,7); var big=items[0]; var left=items.slice(1,4); var right=items.slice(4,7); return '<div class="ks-runtime-panel'+(idx===0?' is-active':'')+'" data-panel="'+esc(p.key)+'"><div class="ks-runtime-tab-layout"><div class="ks-runtime-side-col">'+left.map(sideCard).join('')+'</div><div class="ks-runtime-big-wrap">'+bigCard(big)+'</div><div class="ks-runtime-side-col">'+right.map(sideCard).join('')+'</div></div></div>'; }).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    all(wrapper, '.ks-runtime-tab-btn').forEach(function(btn){ btn.addEventListener('click', function(){ var panel=btn.getAttribute('data-panel')||''; all(wrapper,'.ks-runtime-tab-btn').forEach(function(b){ b.classList.toggle('is-active', b===btn); }); all(wrapper,'.ks-runtime-panel').forEach(function(p){ p.classList.toggle('is-active', p.getAttribute('data-panel')===panel); }); }); });
    bindFallbackImages(wrapper); bindBigThumbs(wrapper);
  }

  function renderRuntimeBestSeller(sections){
    if(!isHomePage() || first(document, '.ks-runtime-best-section')) return;
    var anchor = findHeading(/best seller/);
    var host = anchor ? closestSection(anchor) : null;
    if(!host || !host.parentNode) return;
    var items = uniqueById(sections.best || []).slice(0,10);
    if(items.length < 4) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-best-section';
    wrapper.innerHTML = '<div class="container"><div class="flat-title"><h5 class="fw-semibold">'+esc(titleMap().best)+'</h5></div><div class="ks-runtime-grid">'+items.map(gridCard).join('')+'</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host); bindFallbackImages(wrapper);
  }

  function renderRuntimeMostViewed(sections){
    if(!isHomePage() || first(document, '.ks-runtime-recent-section')) return;
    var lowerAnchor = document.getElementById('HomeLowerColumnsSection') || findHeading(/top 20|in evidenza|i piu venduti|in offerta/);
    var host = lowerAnchor ? closestSection(lowerAnchor) : null;
    if(!host || !host.parentNode) return;
    var items = uniqueById((sections.recent || []).concat(sections.top20 || sections.best || [])).slice(0,8);
    if(items.length < 4) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-recent-section';
    wrapper.innerHTML = '<div class="container"><div class="flat-title"><h5 class="fw-semibold">'+esc(titleMap().topViewed)+'</h5></div><div class="ks-runtime-grid">'+items.map(gridCard).join('')+'</div></div>';
    host.parentNode.insertBefore(wrapper, host);
    bindFallbackImages(wrapper);
  }

  function renderRuntimeLowerSections(sections){
    if(!isHomePage() || first(document, '.ks-runtime-lower-section')) return;
    var host = document.getElementById('HomeLowerColumnsSection') || closestSection(findHeading(/top 20|in evidenza|i piu venduti|in offerta/));
    if(!host || !host.parentNode) return;
    var tm = titleMap();
    var cols = [
      {title: tm.top20, items: uniqueById(sections.top20 || []).slice(0,5)},
      {title: tm.featured, items: uniqueById(sections.evidenza || []).slice(0,5)},
      {title: tm.topSelling, items: uniqueById(sections.topselling || sections.best || []).slice(0,5)},
      {title: tm.offers, items: uniqueById(sections.offerte || []).slice(0,5)}
    ].filter(function(c){ return c.items.length >= 3; });
    if(cols.length < 2) return;
    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-section ks-runtime-lower-section';
    wrapper.innerHTML = '<div class="container"><div class="ks-runtime-lower-grid">' + cols.map(function(c){ return '<div class="ks-runtime-lower-col"><h5 class="ks-runtime-col-title">'+esc(c.title)+'</h5><div class="ks-runtime-col-grid">'+c.items.map(gridCard).join('')+'</div></div>'; }).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host); bindFallbackImages(wrapper);
  }

  function renderRuntimeCommercialSections(){
    if(!isHomePage()) return;
    fetchJson(feedUrl()).then(function(data){
      var sections = data && data.sections ? data.sections : {};
      renderRuntimeTabbedSection(sections);
      renderRuntimeBestSeller(sections);
      renderRuntimeMostViewed(sections);
      renderRuntimeLowerSections(sections);
    }).catch(function(){});
  }

  function runHomeCleanup(){
    if(!isHomePage()) return;
    suppressNewsletterPopup();
    compactHero();
    hideBodyArtifacts();
    hideHeaderClones();
    hideWelcomeFranchisingAnywhere();
  }

  function applyHomeFlags(){
    if(!isHomePage()) return;
    addBodyClass('ks-page-home');
    if(readMergedRecent().length>=2) addBodyClass('ks-has-recent-history');
  }

  window.KSRecent = { read: readMergedRecent, add: updateRecentList };

  onReady(function(){
    if(isArticlePage()){
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }
    applyHomeFlags();
    runHomeCleanup();
    if(isHomePage()){
      renderRuntimeCommercialSections();
      [350, 1400, 4200].forEach(function(delay){ window.setTimeout(function(){ runHomeCleanup(); renderRuntimeCommercialSections(); }, delay); });
      window.addEventListener('load', function(){ runHomeCleanup(); renderRuntimeCommercialSections(); }, { once: true });
      window.addEventListener('resize', function(){ runHomeCleanup(); });
    }
  });
})();
