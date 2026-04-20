(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];

  function onReady(fn) { if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn); else fn(); }
  function isHomePage() { var p = window.location.pathname || '/'; return p === '/' || /\/default\.aspx$/i.test(p); }
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

  function all(root, sel){ return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function first(root, sel){ return (root || document).querySelector(sel); }
  function esc(v){ return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function textOf(node){ return String(node && node.textContent || '').replace(/\s+/g,' ').trim(); }
  function normalizeText(value){ var text=String(value||'').toLowerCase(); try { text=text.normalize('NFD').replace(/[\u0300-\u036f]/g,''); } catch(err) {} return text.replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim(); }
  function containsToken(raw){ var value=normalizeText(raw); return BLOCKED_TOKENS.some(function(token){ return value.indexOf(token)!==-1; }); }
  function rectOf(node){ if(!node||typeof node.getBoundingClientRect!=='function') return null; var r=node.getBoundingClientRect(); return r && (r.width || r.height) ? r : null; }
  function hideNode(node, flag){ if(!node || !node.style) return; node.style.setProperty('display','none','important'); node.style.setProperty('visibility','hidden','important'); node.style.setProperty('opacity','0','important'); node.style.setProperty('pointer-events','none','important'); if(flag) node.setAttribute(flag,'1'); }
  function fetchJson(url){ return fetch(url,{ credentials:'same-origin', headers:{ 'X-Requested-With':'XMLHttpRequest' }}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }); }
  function currentLang(){ var html=document.documentElement.getAttribute('lang')||''; return /^en/i.test(html)?'en':'it'; }
  function titleMap(){ return currentLang()==='en' ? { offers:'On Sale', featured:'Featured', arrivals:'New Arrivals', topViewed:'Most Viewed', top20:'Top 20', topSelling:'Top Selling', best:'Best Seller', chosen:'Chosen for you' } : { offers:'Offerte', featured:'In Evidenza', arrivals:'Nuovi Arrivi', topViewed:'I più visti', top20:'Top 20', topSelling:'I Più Venduti', best:'Best Seller', chosen:'Scelti per te' }; }
  function shuffle(list){ var out=(list||[]).slice(); for(var i=out.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var t=out[i]; out[i]=out[j]; out[j]=t; } return out; }
  function uniqueById(list){ var seen={}, out=[]; (list||[]).forEach(function(item){ var id=parseInt(item && item.id,10) || 0; if(id && seen[id]) return; if(id) seen[id]=1; out.push(item); }); return out; }
  function chunk(list, size){ var out=[]; for(var i=0;i<list.length;i+=size) out.push(list.slice(i,i+size)); return out; }
  function stripHtml(v){ var d=document.createElement('div'); d.innerHTML=String(v||''); return textOf(d); }
  function imageOf(item){ return String(item && (item.preview || item.image || (item.images && item.images[0]) || '') || ''); }
  function imagesOf(item){ var seen={}, out=[]; (item && item.images || []).forEach(function(src){ src=String(src||'').trim(); if(src && !seen[src]){ seen[src]=1; out.push(src); } }); var p=String(item && item.preview || ''); if(p && !seen[p]) out.unshift(p); var i=String(item && item.image || ''); if(i && !seen[i]) out.unshift(i); return out.slice(0,5); }
  function moneyHtml(item){ var price=String(item && item.price || ''); var old=String(item && item.oldPrice || ''); return '<div class="ks-runtime-price"><span class="new">' + (price ? ('€' + esc(price)) : '') + '</span>' + (old ? ('<span class="old">€' + esc(old) + '</span>') : '') + '</div>'; }
  function metaHtml(item){ var bits=[]; if(item && item.brand) bits.push('<span>'+esc(item.brand)+'</span>'); if(item && item.category) bits.push('<span>'+esc(item.category)+'</span>'); return '<div class="ks-runtime-meta">'+bits.join('')+'</div>'; }
  function bindFallbackImages(root){ all(root,'img[data-fallback]').forEach(function(img){ img.addEventListener('error', function onErr(){ img.removeEventListener('error', onErr); var fb=img.getAttribute('data-fallback')||''; if(fb && img.src!==fb) img.src=fb; }); }); }

  function sideCard(item){
    return '<a class="ks-runtime-side-card ks-onsus-font" href="'+esc(item.url||'#')+'">' +
      '<span class="ks-runtime-side-thumb">' + (imageOf(item) ? '<img src="'+esc(imageOf(item))+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</span>' +
      '<span class="ks-runtime-side-body">' + metaHtml(item) + '<span class="ks-runtime-title">'+esc(item.title||'')+'</span>' + moneyHtml(item) + '</span>' +
      '</a>';
  }

  function gridCard(item){
    return '<a class="ks-runtime-grid-card ks-onsus-font" href="'+esc(item.url||'#')+'">' +
      '<span class="ks-runtime-grid-thumb">' + (imageOf(item) ? '<img src="'+esc(imageOf(item))+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</span>' +
      '<span class="ks-runtime-grid-body">' + metaHtml(item) + '<span class="ks-runtime-title">'+esc(item.title||'')+'</span>' + moneyHtml(item) + '</span>' +
      '</a>';
  }

  function bigCard(item){
    var imgs=imagesOf(item); var main=imgs[0]||''; var thumbs=imgs.slice(0,4);
    return '<div class="ks-runtime-big-card ks-onsus-font">' +
      '<div class="ks-runtime-big-main">' +
      '<a class="ks-runtime-big-media" href="'+esc(item.url||'#')+'">' + (main ? '<img src="'+esc(main)+'" data-main="1" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</a>' +
      '<div class="ks-runtime-big-body">' + metaHtml(item) + '<a class="ks-runtime-title ks-runtime-title-big" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a>' +
      '<div class="ks-runtime-bottom">' + moneyHtml(item) + '<ul class="ks-runtime-actions"><li><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a></li><li><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a></li><li><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a></li><li><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></li></ul></div>' +
      '</div></div>' +
      '<div class="ks-runtime-big-thumbs">' + thumbs.map(function(src, idx){ return '<button type="button" class="ks-runtime-big-thumb'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">' + (src ? '<img src="'+esc(src)+'" alt=""/>' : '') + '</button>'; }).join('') + '</div>' +
      '</div>';
  }

  function bindBigThumbs(root){ all(root,'.ks-runtime-big-card').forEach(function(card){ var main=first(card,'.ks-runtime-big-media img[data-main="1"]'); all(card,'.ks-runtime-big-thumb').forEach(function(btn){ btn.addEventListener('click', function(){ all(card,'.ks-runtime-big-thumb').forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); if(main){ main.src = btn.getAttribute('data-img') || main.src; } }); }); }); }

  function compactHero(){
    var shell=first(document,'.ks-home-hero-shell');
    var sideWrap=document.getElementById('HeroSideWrap');
    if(sideWrap) hideNode(sideWrap, 'data-ks-home-artifact');
    if(shell && window.innerWidth >= 1200){ shell.classList.add('ks-home-force-compact'); shell.classList.remove('ks-home-hero-mode-full'); }
  }

  function insideProtected(node){ return !!(node && node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-departments, .ks-home-hero-shell, .card-product, .product-list-wrap, .tf-grid-product-item, .swiper, .ks-runtime-section, .ks-runtime-recent-section')); }

  function hideWelcomeFranchisingAnywhere(){
    all(document,'div,section,aside,span,p,a,img').forEach(function(node){
      if(!node || insideProtected(node)) return;
      var raw=[node.id||'', node.className||'', textOf(node).slice(0,300), node.getAttribute ? (node.getAttribute('src')||node.getAttribute('data-src')||node.getAttribute('alt')||'') : ''].join(' ');
      if(containsToken(raw)) hideNode(node, 'data-ks-franchising-artifact');
    });
  }

  function hideBodyArtifacts(){
    var wrapper=document.getElementById('wrapper'); if(!wrapper) return;
    var form=document.querySelector('body > form') || document.querySelector('form');
    if(form){ Array.prototype.slice.call(form.children).forEach(function(node){ if(!node || node.id==='wrapper') return; if(/^(SCRIPT|STYLE|LINK)$/i.test(node.tagName)) return; if(node.tagName==='INPUT' && String(node.type||'').toLowerCase()==='hidden') return; hideNode(node,'data-ks-body-artifact'); }); }
  }

  function hideHeaderClones(){
    var header=document.querySelector('header') || document.querySelector('.tf-header');
    var headerBottom=header ? (rectOf(header)||{bottom:0}).bottom : 0;
    all(document, 'header, div, section').forEach(function(node){
      if(!node || node===header) return;
      if(header && header.contains(node)) return;
      if(insideProtected(node)) return;
      var r=rectOf(node); if(!r || r.top<headerBottom+120) return;
      if(r.width<window.innerWidth*0.55 || r.height<24 || r.height>220) return;
      var raw=normalizeText([node.className||'', textOf(node).slice(0,220)].join(' '));
      if(/cerca prodotti|tutti i settori|il mio account|assistenza|spedizione gratuita|chiamaci gratis/.test(raw)) hideNode(node, 'data-ks-header-clone');
    });
  }

  function findHeading(regex){
    var nodes = all(document, 'h1,h2,h3,h4,h5,h6,a,button,span,li');
    for(var i=0;i<nodes.length;i++){ var t=normalizeText(textOf(nodes[i])); if(regex.test(t)) return nodes[i]; }
    return null;
  }
  function closestSection(node){ return node ? (node.closest('section, .tf-sp-2, .tf-sp-5, .container, .flat-animate-tab') || node.parentNode) : null; }
  function hideSection(node){ if(node) node.setAttribute('data-ks-hidden-section','1'); }

  function collectDomProducts(){
    var out=[]; var seen={};
    all(document, 'a[href*="articolo.aspx?id="]').forEach(function(link){
      if(link.closest('.ks-runtime-section, header, footer, .ks-home-departments')) return;
      var id=parseArticleIdFromHref(link.getAttribute('href')||''); if(!id || seen[id]) return;
      var card=link.closest('.card-product, .tf-grid-product-item, li, .swiper-slide, .product-item, .box-btn-slide-item') || link;
      var title=textOf(first(card,'.name-product, .product-title, .title, .main-title, .title-product')) || textOf(link);
      if(!title) return;
      var img=first(card,'img');
      var src=img ? (img.getAttribute('src')||img.getAttribute('data-src')||'') : '';
      if(!src) return;
      var price=''; var old='';
      var newEl=first(card,'.new-price, .price-text, .price, .text-primary');
      var oldEl=first(card,'.old-price, .price-old');
      if(newEl) price=textOf(newEl).replace(/[^\d,\.]/g,'');
      if(oldEl) old=textOf(oldEl).replace(/[^\d,\.]/g,'');
      var brand=textOf(first(card,'.brand, .caption, .small-text'));
      out.push({ id:id, url:link.getAttribute('href')||('#'+id), title:title, image:src, preview:src, images:[src], price:price, oldPrice:old, brand:brand, category:'' });
      seen[id]=1;
    });
    return out;
  }

  function mergePools(){
    var lists = Array.prototype.slice.call(arguments);
    var seen={}; var out=[];
    lists.forEach(function(list){ (list||[]).forEach(function(item){ if(!item) return; var id=parseInt(item.id,10)||0; var key=id?('id:'+id):('url:'+String(item.url||item.title||'').trim()); if(!key || seen[key]) return; seen[key]=1; out.push(item); }); });
    return out;
  }

  function padPool(primary, fallbacks, minCount){
    var merged = mergePools(primary, fallbacks);
    return shuffle(merged).slice(0, Math.max(minCount || 0, merged.length));
  }

  function poolView(list, count, fallback){
    return mergePools(list, fallback).slice(0, count);
  }

  function buildSectionData(feed){
    var sections = feed && feed.sections ? feed.sections : {};
    var dom = collectDomProducts();
    var allFeed = mergePools(sections.all, sections.offerte, sections.evidenza, sections.nuovi, sections.best, sections.top20, sections.topselling, sections.recent, dom);
    return {
      offers: poolView(sections.offerte, 18, allFeed),
      featured: poolView(sections.evidenza, 18, mergePools(sections.best, allFeed)),
      arrivals: poolView(sections.nuovi, 18, allFeed),
      best: poolView(sections.best, 16, mergePools(sections.topselling, sections.top20, allFeed)),
      top20: poolView(sections.top20, 16, mergePools(sections.best, allFeed)),
      topSelling: poolView(sections.topselling, 16, mergePools(sections.best, sections.top20, allFeed)),
      recent: poolView(sections.recent, 12, mergePools(sections.top20, sections.best, allFeed)),
      all: allFeed
    };
  }

  function createSection(className, html){ var node=document.createElement('section'); node.className='ks-runtime-section '+className; node.innerHTML=html; return node; }
  function insertAfter(node, anchor){ if(!anchor || !anchor.parentNode) return; anchor.parentNode.insertBefore(node, anchor.nextSibling); }

  function findDealHost(){ return closestSection(findHeading(/occasione imperdibile|deal of the day/)); }
  function findTabbedHost(){ return first(document,'.flat-animate-tab') || closestSection(findHeading(/^offerte$|in evidenza|nuovi arrivi/)); }
  function findBestHost(){ return closestSection(findHeading(/best seller/)); }
  function findLowerHost(){ return document.getElementById('HomeLowerColumnsSection') || closestSection(findHeading(/top 20|i piu venduti|in offerta/)); }
  function findRecentHost(){ return document.getElementById('HomeRecentlyViewedSection') || closestSection(findHeading(/i piu visti|most viewed/)); }
  function findBrandsHost(){ return document.getElementById('HomeBrandsSection') || closestSection(findHeading(/rivenditori ufficiali|i migliori brand/)); }

  function buildTabbedSection(data){
    var tm=titleMap();
    var panels=[
      { key:'offers', title:tm.offers, items:shuffle(data.offers).slice(0,7) },
      { key:'featured', title:tm.featured, items:shuffle(data.featured).slice(0,7) },
      { key:'arrivals', title:tm.arrivals, items:shuffle(data.arrivals).slice(0,7) }
    ].filter(function(p){ return p.items.length>=5; });
    if(!panels.length) return null;
    return createSection('ks-runtime-tabbed-section', '<div class="container"><div class="ks-runtime-tabs-head">'+panels.map(function(p,i){ return '<button type="button" class="ks-runtime-tab-btn'+(i===0?' is-active':'')+'" data-panel="'+esc(p.key)+'">'+esc(p.title)+'</button>'; }).join('')+'</div><div class="ks-runtime-panels">'+panels.map(function(p,i){ var items=p.items; var big=items[0]; var left=items.slice(1,4); var right=items.slice(4,7); return '<div class="ks-runtime-panel'+(i===0?' is-active':'')+'" data-panel="'+esc(p.key)+'"><div class="ks-runtime-tab-layout"><div class="ks-runtime-side-col">'+left.map(sideCard).join('')+'</div><div class="ks-runtime-big-wrap">'+bigCard(big)+'</div><div class="ks-runtime-side-col">'+right.map(sideCard).join('')+'</div></div></div>'; }).join('')+'</div></div>');
  }

  function buildBestSection(data){
    var items=shuffle(data.best).slice(0,10); if(items.length<6) return null;
    return createSection('ks-runtime-best-section', '<div class="container"><div class="flat-title"><h5 class="fw-semibold">'+esc(titleMap().best)+'</h5></div><div class="ks-runtime-grid">'+items.map(gridCard).join('')+'</div></div>');
  }

  function buildRecentSection(data){
    var items=shuffle(mergePools(data.recent, data.top20, data.best)).slice(0,8); if(items.length<4) return null;
    return createSection('ks-runtime-recent-section ks-chosen-section', '<div class="container"><div class="flat-title"><h5 class="fw-semibold">'+esc(titleMap().topViewed)+'</h5></div><div class="ks-runtime-grid ks-chosen-grid">'+items.map(gridCard).join('')+'</div></div>');
  }

  function buildLowerSection(data){
    var tm=titleMap();
    var cols=[
      { title: tm.top20, items: shuffle(mergePools(data.top20, data.best, data.all)).slice(0,5) },
      { title: tm.featured, items: shuffle(mergePools(data.featured, data.offers, data.all)).slice(0,5) },
      { title: tm.topSelling, items: shuffle(mergePools(data.topSelling, data.best, data.all)).slice(0,5) },
      { title: tm.offers, items: shuffle(mergePools(data.offers, data.featured, data.all)).slice(0,5) }
    ].filter(function(col){ return col.items.length>=4; });
    if(cols.length<4) return null;
    return createSection('ks-runtime-lower-section', '<div class="container"><div class="ks-runtime-lower-grid">'+cols.map(function(col){ return '<div class="ks-runtime-lower-col"><h5 class="ks-runtime-col-title">'+esc(col.title)+'</h5><div class="ks-runtime-col-grid">'+col.items.map(gridCard).join('')+'</div></div>'; }).join('')+'</div></div>');
  }

  function buildWeaknessScore(section){ if(!section) return 0; return all(section,'.card-product, a[href*="articolo.aspx?id="], .swiper-slide').length; }

  function installSection(section, host, key){
    if(!section || !host || !host.parentNode) return null;
    var existing=first(document,'.'+key);
    if(existing && existing.parentNode) existing.parentNode.removeChild(existing);
    section.classList.add(key);
    insertAfter(section, host);
    hideSection(host);
    bindFallbackImages(section);
    bindBigThumbs(section);
    if(key==='ks-runtime-tabbed-instance') all(section,'.ks-runtime-tab-btn').forEach(function(btn){ btn.addEventListener('click', function(){ var panel=btn.getAttribute('data-panel')||''; all(section,'.ks-runtime-tab-btn').forEach(function(b){ b.classList.toggle('is-active', b===btn); }); all(section,'.ks-runtime-panel').forEach(function(p){ p.classList.toggle('is-active', p.getAttribute('data-panel')===panel); }); }); });
    return section;
  }

  function renderRuntimeCommercialSections(){
    if(!isHomePage()) return;
    var dealHost=findDealHost();
    var tabHost=findTabbedHost();
    var bestHost=findBestHost();
    var lowerHost=findLowerHost();
    var recentHost=findRecentHost();
    var brandHost=findBrandsHost();

    function mountFromPayload(feed){
      var data=buildSectionData(feed);
      var tabbed=buildTabbedSection(data);
      var best=buildBestSection(data);
      var recent=buildRecentSection(data);
      var lower=buildLowerSection(data);

      var anchor1 = dealHost || tabHost;
      if(tabbed && anchor1) installSection(tabbed, anchor1, 'ks-runtime-tabbed-instance');

      var bestAnchor = first(document,'.ks-runtime-tabbed-instance') || tabHost || bestHost || anchor1;
      if(best && bestAnchor) installSection(best, bestHost || bestAnchor, 'ks-runtime-best-instance');

      var recentAnchor = first(document,'.ks-runtime-best-instance') || bestHost || lowerHost || bestAnchor;
      if(recent && recentAnchor) installSection(recent, recentHost || recentAnchor, 'ks-runtime-recent-instance');

      var lowerAnchor = first(document,'.ks-runtime-recent-instance') || lowerHost || bestHost || recentAnchor;
      if(lower && lowerAnchor) installSection(lower, lowerHost || lowerAnchor, 'ks-runtime-lower-instance');

      if(document.body && (tabbed || best || recent || lower)) document.body.classList.add('ks-runtime-home-built');
    }

    fetchJson(feedUrl()).then(function(data){ mountFromPayload(data || {}); }).catch(function(){ mountFromPayload({ sections:{} }); });
  }

  function feedUrl(){ var url=new URL(FEED_ENDPOINT, location.href); url.searchParams.set('mode','sections'); var ids=readMergedRecent(); if(ids.length) url.searchParams.set('recent', ids.slice(0,12).join(',')); url.searchParams.set('_', String(Date.now())); return url.toString(); }

  function runHomeCleanup(){ if(!isHomePage()) return; suppressNewsletterPopup(); compactHero(); hideBodyArtifacts(); hideHeaderClones(); hideWelcomeFranchisingAnywhere(); }
  function applyHomeFlags(){ if(!isHomePage()) return; addBodyClass('ks-page-home'); if(readMergedRecent().length>=2) addBodyClass('ks-has-recent-history'); }

  window.KSRecent = { read: readMergedRecent, add: updateRecentList };

  onReady(function(){
    if(isArticlePage()){ addBodyClass('ks-page-article'); trackArticleRecent(); }
    applyHomeFlags();
    runHomeCleanup();
    if(isHomePage()){
      renderRuntimeCommercialSections();
      [350, 1400, 4200, 8500].forEach(function(delay){ window.setTimeout(function(){ runHomeCleanup(); renderRuntimeCommercialSections(); }, delay); });
      window.addEventListener('load', function(){ runHomeCleanup(); renderRuntimeCommercialSections(); }, { once:true });
      window.addEventListener('resize', function(){ runHomeCleanup(); });
    }
  });
})();
