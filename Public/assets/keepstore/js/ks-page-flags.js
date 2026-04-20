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
  function hideNode(node, flag){ if(!node || !node.style) return; node.style.setProperty('display','none','important'); if(flag) node.setAttribute(flag,'1'); }
  function fetchJson(url){ return fetch(url,{ credentials:'same-origin', headers:{ 'X-Requested-With':'XMLHttpRequest' }}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }); }
  function currentLang(){ var html=document.documentElement.getAttribute('lang')||''; return /^en/i.test(html)?'en':'it'; }
  function t(){ return currentLang()==='en' ? { offers:'On Sale', featured:'Featured', arrivals:'New Arrivals', topViewed:'Most Viewed', top20:'Top 20', topSelling:'Top Selling', best:'Best Seller', chosen:'Chosen for you', deal:'Deal of the day' } : { offers:'Offerte', featured:'In Evidenza', arrivals:'Nuovi Arrivi', topViewed:'I più visti', top20:'Top 20', topSelling:'I Più Venduti', best:'Best Seller', chosen:'Scelti da te', deal:'Occasione Imperdibile' }; }
  function shuffle(list){ var out=(list||[]).slice(); for(var i=out.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var tmp=out[i]; out[i]=out[j]; out[j]=tmp; } return out; }
  function uniqById(list){ var seen={}, out=[]; (list||[]).forEach(function(item){ var id=parseInt(item && item.id,10) || 0; if(!id || seen[id]) return; seen[id]=1; out.push(item); }); return out; }
  function mergeLists(){ var merged=[]; for(var i=0;i<arguments.length;i++) merged=merged.concat(arguments[i]||[]); return uniqById(merged); }
  function imageOf(item){ var imgs=imagesOf(item); return imgs[0] || ''; }
  function imagesOf(item){ var seen={}, out=[]; [item && item.preview, item && item.image].concat(item && item.images || []).forEach(function(src){ src=String(src||'').trim(); if(src && !seen[src]){ seen[src]=1; out.push(src); } }); return out.slice(0,5); }
  function priceHtml(item){ var price=String(item && item.price || ''); var old=String(item && item.oldPrice || ''); return '<div class="ks-runtime-price">' + (price ? ('<span class="new">' + esc(price) + ' €</span>') : '') + (old ? ('<span class="old">' + esc(old) + ' €</span>') : '') + '</div>'; }
  function metaHtml(item){ var bits=[]; if(item && item.brand) bits.push('<span>'+esc(item.brand)+'</span>'); if(item && item.category) bits.push('<span>'+esc(item.category)+'</span>'); return '<div class="ks-runtime-meta">'+bits.join('<span class="dot">•</span>')+'</div>'; }
  function bindFallbackImages(root){ all(root,'img[data-fallback]').forEach(function(img){ img.addEventListener('error', function onErr(){ img.removeEventListener('error', onErr); var fb=img.getAttribute('data-fallback')||''; if(fb && img.src!==fb) img.src=fb; }); }); }
  function bindBigThumbs(root){ all(root,'.ks-runtime-big-card').forEach(function(card){ var main=first(card,'img[data-main="1"]'); if(!main) return; all(card,'.ks-runtime-big-thumb').forEach(function(btn){ btn.addEventListener('click', function(){ all(card,'.ks-runtime-big-thumb').forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); main.src = btn.getAttribute('data-img') || main.src; }); }); }); }

  function sideCard(item){
    return '<a class="ks-runtime-side-card ks-onsus-font" href="'+esc(item.url||'#')+'">' +
      '<span class="ks-runtime-side-thumb">' + (imageOf(item) ? '<img src="'+esc(imageOf(item))+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</span>' +
      '<span class="ks-runtime-side-body">' + metaHtml(item) + '<span class="ks-runtime-title">'+esc(item.title||'')+'</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }

  function gridCard(item){
    return '<a class="ks-runtime-grid-card ks-onsus-font" href="'+esc(item.url||'#')+'">' +
      '<span class="ks-runtime-grid-thumb">' + (imageOf(item) ? '<img src="'+esc(imageOf(item))+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</span>' +
      '<span class="ks-runtime-grid-body">' + metaHtml(item) + '<span class="ks-runtime-title">'+esc(item.title||'')+'</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }

  function rowCard(item){
    return '<a class="ks-runtime-row-card ks-onsus-font" href="'+esc(item.url||'#')+'">' +
      '<span class="ks-runtime-row-thumb">' + (imageOf(item) ? '<img src="'+esc(imageOf(item))+'" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</span>' +
      '<span class="ks-runtime-row-body">' + metaHtml(item) + '<span class="ks-runtime-title">'+esc(item.title||'')+'</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }

  function bigCard(item){
    var imgs=imagesOf(item), main=imgs[0]||'', thumbs=imgs.slice(0,4);
    return '<div class="ks-runtime-big-card ks-onsus-font">' +
      '<div class="ks-runtime-big-main">' +
      '<a class="ks-runtime-big-media" href="'+esc(item.url||'#')+'">' + (main ? '<img src="'+esc(main)+'" data-main="1" data-fallback="'+esc(item.image||'')+'" alt="'+esc(item.title||'')+'"/>' : '') + '</a>' +
      '<div class="ks-runtime-big-body">' + metaHtml(item) + '<a class="ks-runtime-title ks-runtime-title-big" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a>' +
      '<div class="ks-runtime-bottom">' + priceHtml(item) + '<ul class="ks-runtime-actions"><li><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a></li><li><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a></li><li><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a></li><li><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></li></ul></div>' +
      '</div></div>' +
      '<div class="ks-runtime-big-thumbs">' + thumbs.map(function(src, idx){ return '<button type="button" class="ks-runtime-big-thumb'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">' + (src ? '<img src="'+esc(src)+'" alt=""/>' : '') + '</button>'; }).join('') + '</div>' +
      '</div>';
  }

  function ensureRuntimeCss(){
    if(document.getElementById('ks-runtime-home-step59')) return;
    var style=document.createElement('style'); style.id='ks-runtime-home-step59';
    style.textContent=[
      "[data-ks-hidden-section='1']{display:none!important;}",
      ".ks-runtime-home-block{padding:26px 0 8px; position:relative; z-index:3;}",
      ".ks-runtime-home-block .flat-title{display:flex; align-items:center; justify-content:space-between; margin-bottom:18px;}",
      ".ks-runtime-home-block .flat-title h5{margin:0; font-size:22px; line-height:1.2; font-weight:700; color:#111827;}",
      ".ks-runtime-tabs-head{display:flex;gap:22px;align-items:center;border-bottom:1px solid #e5e7eb;margin-bottom:18px;flex-wrap:wrap;}",
      ".ks-runtime-tab-btn{appearance:none;border:0;background:none;padding:0 0 14px;font-size:15px;line-height:1.2;font-weight:700;color:#111827;cursor:pointer;position:relative;}",
      ".ks-runtime-tab-btn.is-active{color:#ef4444;}",
      ".ks-runtime-tab-btn.is-active:after{content:'';position:absolute;left:0;right:0;bottom:-1px;height:2px;background:#ef4444;border-radius:2px;}",
      ".ks-runtime-panel{display:none;}",
      ".ks-runtime-panel.is-active{display:block;}",
      ".ks-runtime-tab-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(0,1fr) minmax(220px,280px);gap:24px;align-items:start;}",
      ".ks-runtime-side-col{display:grid;gap:18px;align-content:start;}",
      ".ks-runtime-side-card,.ks-runtime-grid-card,.ks-runtime-row-card{display:grid;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}",
      ".ks-runtime-side-card,.ks-runtime-row-card{grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;}",
      ".ks-runtime-grid-card{grid-template-columns:1fr;gap:12px;align-items:start;padding:16px;}",
      ".ks-runtime-side-thumb,.ks-runtime-grid-thumb,.ks-runtime-row-thumb{height:94px;border-radius:14px;background:#f5f7fb;display:flex;align-items:center;justify-content:center;overflow:hidden;}",
      ".ks-runtime-grid-thumb{height:170px;}",
      ".ks-runtime-side-thumb img,.ks-runtime-grid-thumb img,.ks-runtime-big-media img,.ks-runtime-big-thumb img,.ks-runtime-row-thumb img{max-width:100%;max-height:100%;object-fit:contain;display:block;}",
      ".ks-runtime-side-body,.ks-runtime-grid-body,.ks-runtime-row-body{display:grid;gap:6px;min-width:0;}",
      ".ks-runtime-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}",
      ".ks-runtime-meta .dot{opacity:.5;}",
      ".ks-runtime-title{font-size:14px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}",
      ".ks-runtime-title-big{font-size:18px;}",
      ".ks-runtime-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}",
      ".ks-runtime-price .new{font-size:16px;color:#ef4444;}",
      ".ks-runtime-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}",
      ".ks-runtime-big-card{background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}",
      ".ks-runtime-big-main{display:grid;gap:16px;min-width:0;}",
      ".ks-runtime-big-media{height:420px;border-radius:18px;background:#f5f7fb;display:flex;align-items:center;justify-content:center;overflow:hidden;}",
      ".ks-runtime-big-thumbs{display:grid;gap:10px;align-content:start;}",
      ".ks-runtime-big-thumb{appearance:none;border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;cursor:pointer;}",
      ".ks-runtime-big-thumb.is-active{border-color:#111827;box-shadow:0 0 0 1px #111827 inset;}",
      ".ks-runtime-big-body{display:grid;gap:12px;min-width:0;}",
      ".ks-runtime-actions{display:flex;align-items:center;gap:10px;justify-content:flex-end;flex-wrap:wrap;margin:0;padding:0;list-style:none;}",
      ".ks-runtime-actions .box-icon{width:36px;height:36px;border-radius:999px;border:1px solid #e5e7eb;background:#fff;display:inline-flex;align-items:center;justify-content:center;color:#4b5563;text-decoration:none;}",
      ".ks-runtime-bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}",
      ".ks-runtime-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}",
      ".ks-runtime-lower-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;align-items:start;}",
      ".ks-runtime-col-title{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}",
      ".ks-runtime-col-list{display:grid;gap:16px;}",
      ".ks-runtime-recent-section .ks-runtime-grid{grid-template-columns:repeat(4,minmax(0,1fr));}",
      "@media (max-width: 1199.98px){.ks-runtime-tab-layout{grid-template-columns:1fr;}.ks-runtime-side-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-runtime-big-card{grid-template-columns:1fr;}.ks-runtime-big-thumbs{grid-template-columns:repeat(4,64px);}.ks-runtime-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-runtime-lower-grid{grid-template-columns:repeat(2,minmax(0,1fr));}}",
      "@media (max-width: 767.98px){.ks-runtime-side-col,.ks-runtime-lower-grid{grid-template-columns:1fr;}.ks-runtime-grid,.ks-runtime-recent-section .ks-runtime-grid{grid-template-columns:repeat(2,minmax(0,1fr));}.ks-runtime-grid-thumb{height:140px;}.ks-runtime-big-media{height:280px;}.ks-runtime-tabs-head{gap:16px;}}"
    ].join('');
    (document.head||document.documentElement).appendChild(style);
  }

  function suppressNewsletterPopup(){
    all(document,'.auto-popup, .modal-newleter, [class*="modal-newleter"]').forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); });
    all(document,'.modal-backdrop, .offcanvas-backdrop').forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); if(node.parentNode) node.parentNode.removeChild(node); });
    if(document.body){ document.body.classList.remove('modal-open'); document.body.style.removeProperty('overflow'); document.body.style.removeProperty('padding-right'); }
  }
  function compactHero(){
    var shell=first(document,'.ks-home-hero-shell');
    var sideWrap=document.getElementById('HeroSideWrap');
    if(sideWrap) hideNode(sideWrap,'data-ks-home-artifact');
    if(shell && window.innerWidth>=1200){ shell.classList.add('ks-home-force-compact'); shell.classList.remove('ks-home-hero-mode-full'); }
  }
  function hideWelcomeFranchisingAnywhere(){
    all(document,'div,section,aside,span,p,a,img').forEach(function(node){
      if(!node || node.closest('header,footer,.ks-home-departments,.ks-home-hero-shell,.ks-runtime-home-block,.card-product,.brand-item,.swiper')) return;
      var raw=[node.id||'', node.className||'', textOf(node).slice(0,240), node.getAttribute ? (node.getAttribute('src')||node.getAttribute('data-src')||node.getAttribute('alt')||'') : ''].join(' ');
      if(containsToken(raw)) hideNode(node,'data-ks-franchising-artifact');
    });
  }
  function hideHeaderClones(){
    var header=first(document,'header') || first(document,'.tf-header');
    var headerBottom=header ? (rectOf(header)||{bottom:0}).bottom : 0;
    all(document,'header, div, section').forEach(function(node){
      if(!node || node===header) return;
      if(header && header.contains(node)) return;
      var rect=rectOf(node); if(!rect || rect.top<headerBottom+120) return;
      var raw=normalizeText([node.className||'', textOf(node).slice(0,220)].join(' '));
      if(/cerca prodotti|tutti i settori|il mio account|assistenza|spedizione gratuita|chiamaci gratis/.test(raw) && rect.width > window.innerWidth*0.55){ hideNode(node,'data-ks-header-clone'); }
    });
  }
  function stripRogueRails(){
    var laneNode=first(document,'.tf-sp-5 .container') || first(document,'.container');
    var lane=rectOf(laneNode);
    all(document.body,'*').forEach(function(node){
      if(!node || node.closest('header, footer, .ks-home-departments, .ks-home-hero-shell, .ks-runtime-home-block, .card-product, .swiper, .brand-item')) return;
      var r=rectOf(node); if(!r || r.width < 24 || r.height < 24) return;
      var outside = lane ? (r.right < lane.left - 6 || r.left > lane.right + 6) : false;
      if(!outside) return;
      var raw=normalizeText(textOf(node).slice(0,200) + ' ' + (node.className||''));
      if(containsToken(raw) || all(node,'img,iframe,object,embed').length >= 1) hideNode(node,'data-ks-hidden-rail');
    });
  }

  function loadSectionsData(){
    var recent = readMergedRecent().slice(0, 20);
    var url = FEED_ENDPOINT + '?mode=sections&_=' + Date.now();
    if(recent.length) url += '&recent=' + encodeURIComponent(recent.join(','));
    return fetchJson(url).then(function(data){ return data && data.sections ? data.sections : {}; });
  }

  function fillFromCombined(primary, combined, needed, seen){
    var out=[]; (primary||[]).forEach(function(item){ var id=parseInt(item&&item.id,10)||0; if(!id || seen[id]) return; seen[id]=1; out.push(item); });
    (combined||[]).forEach(function(item){ if(out.length>=needed) return; var id=parseInt(item&&item.id,10)||0; if(!id || seen[id]) return; seen[id]=1; out.push(item); });
    return out.slice(0,needed);
  }
  function pickSection(primary, combined, count){ return fillFromCombined(shuffle(primary||[]), shuffle(combined||[]), count, {}); }
  function uniqueAcross(sections){
    var seen={};
    Object.keys(sections).forEach(function(key){ sections[key]=(sections[key]||[]).filter(function(item){ var id=parseInt(item&&item.id,10)||0; if(!id || seen[id]) return false; seen[id]=1; return true; }); });
    return sections;
  }

  function findHeading(patterns){
    var list = Array.isArray(patterns) ? patterns : [patterns];
    var nodes = all(document,'h1,h2,h3,h4,h5,h6,a,button,span');
    for(var i=0;i<nodes.length;i++){
      var txt=normalizeText(textOf(nodes[i]));
      for(var j=0;j<list.length;j++){
        var pat=normalizeText(list[j]);
        if(pat && txt===pat) return nodes[i];
      }
    }
    return null;
  }
  function sectionOf(node){ return node ? (node.closest('section, .tf-sp-2, .tf-sp-5, .container, .row') || node.parentNode) : null; }
  function insertAfter(ref,node){ if(ref && ref.parentNode){ ref.parentNode.insertBefore(node, ref.nextSibling); } }
  function markHide(section){ if(section) section.setAttribute('data-ks-hidden-section','1'); }

  function hideOriginalCommercialSections(){
    var tabHead=findHeading([t().offers, t().featured, t().arrivals]);
    if(tabHead) markHide(sectionOf(tabHead));
    var bestHead=findHeading([t().best]); if(bestHead) markHide(sectionOf(bestHead));
    var recentHead=findHeading([t().topViewed, t().chosen]); if(recentHead) markHide(sectionOf(recentHead));
    var low1=findHeading([t().top20]), low2=findHeading([t().featured]), low3=findHeading([t().topSelling]), low4=findHeading(['In Offerta','On Sale']);
    [low1,low2,low3,low4].forEach(function(n){ if(n) markHide(sectionOf(n)); });
  }

  function renderTabbed(host, sections){
    var labels=[{key:'offerte', title:t().offers},{key:'evidenza', title:t().featured},{key:'nuovi', title:t().arrivals}];
    var usable=[];
    labels.forEach(function(cfg){ var items=pickSection(sections[cfg.key], sections.combined, 7); if(items.length>=5) usable.push({ cfg:cfg, items:items }); });
    if(!usable.length) return null;
    var node=document.createElement('section'); node.className='ks-runtime-home-block ks-runtime-tabbed-home';
    node.innerHTML='<div class="container"><div class="ks-runtime-tabs-head">'+usable.map(function(u,idx){ return '<button type="button" class="ks-runtime-tab-btn'+(idx===0?' is-active':'')+'" data-panel="'+esc(u.cfg.key)+'">'+esc(u.cfg.title)+'</button>'; }).join('')+'</div><div class="ks-runtime-tabs-panels">'+usable.map(function(u,idx){ var big=u.items[0], left=u.items.slice(1,4), right=u.items.slice(4,7); return '<div class="ks-runtime-panel'+(idx===0?' is-active':'')+'" data-panel="'+esc(u.cfg.key)+'"><div class="ks-runtime-tab-layout"><div class="ks-runtime-side-col">'+left.map(sideCard).join('')+'</div><div class="ks-runtime-big-wrap">'+bigCard(big)+'</div><div class="ks-runtime-side-col">'+right.map(sideCard).join('')+'</div></div></div>'; }).join('')+'</div></div>';
    insertAfter(host,node);
    all(node,'.ks-runtime-tab-btn').forEach(function(btn){ btn.addEventListener('click',function(){ var panel=btn.getAttribute('data-panel')||''; all(node,'.ks-runtime-tab-btn').forEach(function(b){ b.classList.toggle('is-active', b===btn); }); all(node,'.ks-runtime-panel').forEach(function(p){ p.classList.toggle('is-active', p.getAttribute('data-panel')===panel); }); }); });
    bindFallbackImages(node); bindBigThumbs(node); return node;
  }

  function renderGridBlock(afterNode, title, items, cls, cols){
    if(!items || !items.length) return null;
    var node=document.createElement('section'); node.className='ks-runtime-home-block '+(cls||'');
    node.innerHTML='<div class="container"><div class="flat-title"><h5 class="fw-semibold">'+esc(title)+'</h5></div><div class="ks-runtime-grid">'+items.map(gridCard).join('')+'</div></div>';
    insertAfter(afterNode,node); bindFallbackImages(node); return node;
  }

  function renderRecent(afterNode, sections){
    var items = pickSection(mergeLists(sections.recent, sections.top20, sections.best), sections.combined, 8);
    if(items.length < 4) return null;
    return renderGridBlock(afterNode, t().topViewed, items, 'ks-runtime-recent-section');
  }

  function renderBest(afterNode, sections){
    var items = pickSection(sections.best, sections.combined, 10);
    if(items.length < 4) return null;
    return renderGridBlock(afterNode, t().best, items, 'ks-runtime-best-home');
  }

  function renderLower(afterNode, sections){
    var data={};
    data.top20 = pickSection(sections.top20, sections.combined, 5);
    data.featured = pickSection(sections.evidenza, sections.combined, 5);
    data.topselling = pickSection(sections.topselling, sections.combined, 5);
    data.onsale = pickSection(sections.offerte, sections.combined, 5);
    data = uniqueAcross(data);
    var groups=[
      {title:t().top20, items:data.top20},
      {title:t().featured, items:data.featured},
      {title:t().topSelling, items:data.topselling},
      {title:currentLang()==='en'?'On Sale':'In Offerta', items:data.onsale}
    ].filter(function(g){ return (g.items||[]).length >= 3; });
    if(!groups.length) return null;
    var node=document.createElement('section'); node.className='ks-runtime-home-block ks-runtime-lower-home';
    node.innerHTML='<div class="container"><div class="ks-runtime-lower-grid">'+groups.map(function(g){ return '<div class="ks-runtime-lower-col"><h5 class="ks-runtime-col-title">'+esc(g.title)+'</h5><div class="ks-runtime-col-list">'+g.items.map(rowCard).join('')+'</div></div>'; }).join('')+'</div></div>';
    insertAfter(afterNode,node); bindFallbackImages(node); return node;
  }

  function removeRuntimeBlocks(){ all(document,'.ks-runtime-home-block').forEach(function(n){ if(n.parentNode) n.parentNode.removeChild(n); }); }

  function mountRuntimeHome(sections){
    if(!isHomePage()) return;
    ensureRuntimeCss();
    removeRuntimeBlocks();
    hideOriginalCommercialSections();
    var dealHead = findHeading([t().deal, 'Occasione Imperdibile']);
    var brandHead = findHeading(['Rivenditori Ufficiali - I migliori Brand', 'Rivenditori Ufficiali']);
    var host = sectionOf(dealHead) || first(document,'.ks-home-hero-section') || first(document,'main .container');
    if(!host || !host.parentNode) return;
    var current = host;
    var tab = renderTabbed(current, sections); if(tab) current = tab;
    var best = renderBest(current, sections); if(best) current = best;
    var recent = renderRecent(current, sections); if(recent) current = recent;
    var lower = renderLower(current, sections); if(lower) current = lower;
    if(brandHead){ var brandSection = sectionOf(brandHead); if(brandSection && current && current.compareDocumentPosition(brandSection) & Node.DOCUMENT_POSITION_FOLLOWING){ brandSection.parentNode.insertBefore(current, brandSection); } }
  }

  function scrapeExistingSections(){
    function cardToItem(card){
      if(!card) return null;
      var link = first(card,'a[href*="articolo.aspx?id="]');
      var title = first(card,'.title, .product-title, .name-product, h6 a, h5 a, .link') || link;
      var img = first(card,'img');
      var id = link ? parseArticleIdFromHref(link.getAttribute('href')||'') : 0;
      var priceNew = first(card,'.new-price, .price-text, .new, .price .text-primary');
      var priceOld = first(card,'.old-price, del, .old');
      if(!id || !title) return null;
      return { id:id, url:link.getAttribute('href')||('#'), title:textOf(title), brand:'', category:'', price:textOf(priceNew), oldPrice:textOf(priceOld), image:img ? (img.getAttribute('src')||img.getAttribute('data-src')||'') : '', preview:'', images:[] };
    }
    var cards = all(document,'a[href*="articolo.aspx?id="], .card-product, .tf-grid-product-item').map(cardToItem).filter(Boolean);
    return { combined: uniqById(cards), offerte: uniqById(cards), evidenza: uniqById(cards), nuovi: uniqById(cards), best: uniqById(cards), top20: uniqById(cards), topselling: uniqById(cards), recent: uniqById(cards) };
  }

  function runHomeCleanup(){ if(!isHomePage()) return; suppressNewsletterPopup(); compactHero(); hideHeaderClones(); hideWelcomeFranchisingAnywhere(); stripRogueRails(); }

  function initHome(){
    if(!isHomePage()) return;
    addBodyClass('ks-page-home');
    runHomeCleanup();
    loadSectionsData().then(function(sections){ if(!sections || !Object.keys(sections).length) sections = scrapeExistingSections(); mountRuntimeHome(sections); }).catch(function(){ mountRuntimeHome(scrapeExistingSections()); });
    [800, 2200, 5000].forEach(function(delay){ window.setTimeout(function(){ runHomeCleanup(); }, delay); });
    window.addEventListener('load', function(){ runHomeCleanup(); loadSectionsData().then(mountRuntimeHome).catch(function(){}); }, { once:true });
    window.addEventListener('resize', function(){ runHomeCleanup(); });
  }

  window.KSRecent = { read: readMergedRecent, add: updateRecentList };

  onReady(function(){
    if(isArticlePage()){ addBodyClass('ks-page-article'); trackArticleRecent(); }
    initHome();
  });
})();


(function(){
  'use strict';
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  function onReady(fn){ if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', fn); else fn(); }
  function all(root,sel){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function first(root,sel){ return (root||document).querySelector(sel); }
  function esc(v){ return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function txt(n){ return String(n&&n.textContent||'').replace(/\s+/g,' ').trim(); }
  function norm(v){ var s=String(v||'').toLowerCase(); try{s=s.normalize('NFD').replace(/[̀-ͯ]/g,'');}catch(err){} return s.replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim(); }
  function isHome(){ var p=location.pathname||'/'; return p==='/' || /\/default\.aspx$/i.test(p); }
  function fetchJson(url){ return fetch(url,{credentials:'same-origin',headers:{'X-Requested-With':'XMLHttpRequest'}}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }); }
  function parseId(href){ var m=String(href||'').match(/[?&]id=(\d+)/i); return m?parseInt(m[1],10):0; }
  function pageY(node){ if(!node||typeof node.getBoundingClientRect!=='function') return 0; return (node.getBoundingClientRect().top||0) + (window.pageYOffset||document.documentElement.scrollTop||0); }
  function hide(node){ if(!node||!node.style) return; node.setAttribute('data-ks-hidden-section','1'); node.style.setProperty('display','none','important'); }
  function sectionOf(node){ return node ? (node.closest('section, .tf-sp-2, .tf-sp-5, .container, .row, .flat-spacing') || node.parentNode) : null; }
  function insertAfter(ref,node){ if(ref&&ref.parentNode) ref.parentNode.insertBefore(node, ref.nextSibling); }
  function currentLang(){ var html=document.documentElement.getAttribute('lang')||''; return /^en/i.test(html)?'en':'it'; }
  function labels(){ return currentLang()==='en' ? {deal:'Deal Of The Day',offers:'On Sale',featured:'Featured',arrivals:'New Arrivals',best:'Best Seller',viewed:'Most Viewed',top20:'Top 20',topselling:'Top Selling',onsale:'On Sale',brands:'Official Resellers - Best Brands'} : {deal:'Occasione Imperdibile',offers:'Offerte',featured:'In Evidenza',arrivals:'Nuovi Arrivi',best:'Best Seller',viewed:'I più visti',top20:'Top 20',topselling:"I Piu' Venduti",onsale:'In Offerta',brands:'Rivenditori Ufficiali - I migliori Brand'}; }
  function readRecent(){ try{ if(window.KSRecent&&typeof window.KSRecent.read==='function') return (window.KSRecent.read()||[]).filter(Boolean); }catch(err){} return []; }
  function uniqById(list){ var seen={}, out=[]; (list||[]).forEach(function(it){ var id=parseInt(it&&it.id,10)||0; if(!id||seen[id]) return; seen[id]=1; out.push(it); }); return out; }
  function merge(){ var out=[]; for(var i=0;i<arguments.length;i++) out=out.concat(arguments[i]||[]); return uniqById(out); }
  function shuffled(list){ var arr=(list||[]).slice(); for(var i=arr.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var t=arr[i]; arr[i]=arr[j]; arr[j]=t; } return arr; }
  function fill(primary,fallback,count){ var out=[], seen={}; function add(list){ (list||[]).forEach(function(it){ if(out.length>=count) return; var id=parseInt(it&&it.id,10)||0; if(!id||seen[id]) return; seen[id]=1; out.push(it); }); } add(primary); add(fallback); return out.slice(0,count); }
  function imageList(item){ var out=[]; [item&&item.preview,item&&item.image].concat(item&&item.images||[]).forEach(function(s){ s=String(s||'').trim(); if(s&&out.indexOf(s)===-1) out.push(s); }); return out.slice(0,5); }
  function imageOf(item){ var imgs=imageList(item); return imgs[0]||''; }
  function priceHtml(item){ var p=String(item&&item.price||''); var o=String(item&&item.oldPrice||''); return '<div class="ksv3-price">'+(p?'<span class="new">'+esc(p)+' €</span>':'')+(o?'<span class="old">'+esc(o)+' €</span>':'')+'</div>'; }
  function metaHtml(item){ var bits=[]; if(item&&item.brand) bits.push('<span>'+esc(item.brand)+'</span>'); if(item&&item.category) bits.push('<span>'+esc(item.category)+'</span>'); return bits.length?'<div class="ksv3-meta">'+bits.join('<span class="dot">•</span>')+'</div>':''; }
  function saleBadge(item){ var pct=parseInt(item&&item.salePercent,10)||0; return pct>0?'<span class="ksv3-badge">-'+pct+'%</span>':''; }
  function cardSmall(item){ return '<a class="ksv3-side" href="'+esc(item.url||'#')+'">'+saleBadge(item)+'<span class="thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span><span class="body">'+metaHtml(item)+'<span class="title">'+esc(item.title||'')+'</span>'+priceHtml(item)+'</span></a>'; }
  function cardGrid(item){ return '<a class="ksv3-grid-card" href="'+esc(item.url||'#')+'">'+saleBadge(item)+'<span class="thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span><span class="body">'+metaHtml(item)+'<span class="title">'+esc(item.title||'')+'</span>'+priceHtml(item)+'</span></a>'; }
  function cardBig(item){ var imgs=imageList(item), main=imgs[0]||''; return '<div class="ksv3-big">'+saleBadge(item)+'<div class="main"><a class="media" href="'+esc(item.url||'#')+'">'+(main?'<img src="'+esc(main)+'" alt="'+esc(item.title||'')+'">':'')+'</a><div class="body">'+metaHtml(item)+'<a class="title title-big" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a><div class="bottom">'+priceHtml(item)+'<div class="actions"><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></div></div></div></div><div class="thumbs">'+imgs.slice(0,4).map(function(src,idx){ return '<button type="button" class="thumb-btn'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">'+(src?'<img src="'+esc(src)+'" alt="">':'')+'</button>'; }).join('')+'</div></div>'; }
  function dealCard(item){ var end=String(item&&item.dealEnds||''); return '<article class="ksv3-deal">'+saleBadge(item)+'<a class="media" href="'+esc(item.url||'#')+'">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</a><div class="body">'+metaHtml(item)+'<a class="title" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a>'+priceHtml(item)+'<div class="save">'+(item&&item.oldPrice?('Risparmi '+esc(item.oldPrice)+' €'):'Promo')+'</div><div class="timer" data-end="'+esc(end)+'"><span><b>00</b><small>Giorni</small></span><span><b>00</b><small>Ore</small></span><span><b>00</b><small>Min</small></span><span><b>00</b><small>Sec</small></span></div><div class="avail"><span>Venduti: '+esc(item&&item.sold||0)+'</span><span>Disponibili: '+esc(item&&item.available||0)+'</span></div></div></article>'; }
  function bindThumbs(root){ all(root,'.ksv3-big').forEach(function(card){ var main=first(card,'.media img'); if(!main) return; all(card,'.thumb-btn').forEach(function(btn){ btn.addEventListener('click',function(){ all(card,'.thumb-btn').forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); main.src=btn.getAttribute('data-img')||main.src; }); }); }); }
  function startTimers(root){ function tick(){ all(root,'.timer').forEach(function(t){ var end=t.getAttribute('data-end')||''; var target=end?new Date(end):null; var ms=target && !isNaN(target.getTime()) ? Math.max(0,target.getTime()-Date.now()) : 0; var s=Math.floor(ms/1000); var d=Math.floor(s/86400); s-=d*86400; var h=Math.floor(s/3600); s-=h*3600; var m=Math.floor(s/60); s-=m*60; var parts=[d,h,m,s].map(function(n){ return (n<10?'0':'')+n; }); all(t,'b').forEach(function(b,idx){ b.textContent=parts[idx]||'00'; }); }); }
    tick(); window.clearInterval(root._timerInt||0); root._timerInt=window.setInterval(tick,1000);
  }
  function ensureCss(){ if(document.getElementById('ks-home-runtime-v3')) return; var s=document.createElement('style'); s.id='ks-home-runtime-v3'; s.textContent=[
    'body.ks-page-home .ksv2-home-root, body.ks-page-home .ks-runtime-home-block{display:none!important;}',
    '.ksv3-home-root{padding:24px 0 6px;position:relative;z-index:5;}',
    '.ksv3-block{padding:26px 0 10px;}',
    '.ksv3-icons-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:18px;}',
    '.ksv3-icons-grid .tf-icon-box{display:flex;align-items:center;gap:14px;min-height:88px;padding:0 18px;border:1px solid #ebedf0;border-radius:14px;background:#fff;}',
    '.ksv3-title{display:flex;align-items:center;justify-content:space-between;margin:0 0 16px;gap:16px;}',
    '.ksv3-title h5{margin:0;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}',
    '.ksv3-deals-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:24px;}',
    '.ksv3-deal,.ksv3-side,.ksv3-grid-card{position:relative;display:grid;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}',
    '.ksv3-deal .media,.ksv3-grid-card .thumb,.ksv3-side .thumb,.ksv3-row .thumb,.ksv3-big .media{background:#f5f7fb;border-radius:14px;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
    '.ksv3-deal .media{height:220px;margin-bottom:14px;}.ksv3-grid-card .thumb{height:170px;}.ksv3-side,.ksv3-row{grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;}.ksv3-grid-card{grid-template-columns:1fr;gap:12px;align-items:start;padding:16px;}',
    '.ksv3-deal img,.ksv3-grid-card img,.ksv3-side img,.ksv3-row img,.ksv3-big img,.ksv3-brand img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
    '.ksv3-deal .body,.ksv3-grid-card .body,.ksv3-side .body,.ksv3-row .body,.ksv3-big .body{display:grid;gap:8px;min-width:0;}',
    '.ksv3-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}.ksv3-meta .dot{opacity:.5;}',
    '.ksv3-side .title,.ksv3-grid-card .title,.ksv3-row .title,.ksv3-deal .title,.ksv3-big .title{font-size:14px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
    '.ksv3-big .title-big{font-size:18px;}',
    '.ksv3-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}.ksv3-price .new{font-size:16px;color:#ef4444;}.ksv3-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}',
    '.ksv3-badge{position:absolute;left:14px;top:14px;z-index:2;background:#ef4444;color:#fff;border-radius:999px;padding:4px 8px;font-size:11px;font-weight:700;}',
    '.ksv3-save{background:#ffe604;}',
    '.ksv3-deal .save{font-size:12px;font-weight:700;color:#7c2d12;background:#ffe604;border-radius:999px;padding:6px 10px;display:inline-block;justify-self:start;}',
    '.ksv3-deal .timer{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;}',
    '.ksv3-deal .timer span{background:#f5f7fb;border-radius:999px;padding:10px 6px;text-align:center;display:grid;gap:4px;}',
    '.ksv3-deal .timer b{font-size:18px;line-height:1;font-weight:700;color:#111827;}.ksv3-deal .timer small{font-size:11px;color:#6b7280;}',
    '.ksv3-deal .avail{display:flex;justify-content:space-between;gap:12px;font-size:12px;color:#4b5563;}',
    '.ksv3-head{display:flex;gap:22px;align-items:center;border-bottom:1px solid #e5e7eb;margin-bottom:18px;flex-wrap:wrap;}',
    '.ksv3-tab{appearance:none;border:0;background:none;padding:0 0 14px;font-size:15px;line-height:1.2;font-weight:700;color:#111827;cursor:pointer;position:relative;}',
    '.ksv3-tab.is-active{color:#ef4444;}.ksv3-tab.is-active:after{content:"";position:absolute;left:0;right:0;bottom:-1px;height:2px;background:#ef4444;border-radius:2px;}',
    '.ksv3-panel{display:none;}.ksv3-panel.is-active{display:block;}',
    '.ksv3-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(0,1fr) minmax(220px,280px);gap:24px;align-items:start;}',
    '.ksv3-col{display:grid;gap:18px;align-content:start;}',
    '.ksv3-big{position:relative;background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}',
    '.ksv3-big .main{display:grid;gap:16px;min-width:0;}.ksv3-big .media{height:380px;}.ksv3-big .bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}.ksv3-big .actions{display:flex;gap:10px;flex-wrap:wrap;}.ksv3-big .actions .box-icon{width:36px;height:36px;border-radius:999px;border:1px solid #e5e7eb;background:#fff;display:inline-flex;align-items:center;justify-content:center;color:#4b5563;text-decoration:none;}',
    '.ksv3-big .thumbs{display:grid;gap:10px;align-content:start;}.ksv3-big .thumb-btn{appearance:none;border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;cursor:pointer;}.ksv3-big .thumb-btn.is-active{border-color:#111827;box-shadow:0 0 0 1px #111827 inset;}',
    '.ksv3-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}',
    '.ksv3-viewed .ksv3-grid{grid-template-columns:repeat(4,minmax(0,1fr));}',
    '.ksv3-lower{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;align-items:start;}.ksv3-lower-col h5{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}.ksv3-lower-list{display:grid;gap:16px;}',
    '.ksv3-brands-grid{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:18px;}.ksv3-brand{display:flex;align-items:center;justify-content:center;min-height:120px;padding:16px;border:1px solid #edf1f5;border-radius:18px;background:#fff;}',
    '@media (max-width:1199.98px){.ksv3-icons-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ksv3-deals-grid,.ksv3-grid,.ksv3-brands-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ksv3-layout{grid-template-columns:1fr;}.ksv3-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ksv3-big{grid-template-columns:1fr;}.ksv3-big .thumbs{grid-template-columns:repeat(4,64px);}.ksv3-lower{grid-template-columns:repeat(2,minmax(0,1fr));}}',
    '@media (max-width:767.98px){.ksv3-icons-grid,.ksv3-deals-grid,.ksv3-col,.ksv3-grid,.ksv3-viewed .ksv3-grid,.ksv3-lower,.ksv3-brands-grid{grid-template-columns:1fr;}.ksv3-big .media{height:260px;}.ksv3-grid-card .thumb{height:140px;}}'
  ].join(''); (document.head||document.documentElement).appendChild(s); }
  function sectionTitle(labels){ var nodes=all(document,'h1,h2,h3,h4,h5,h6,a,button,span'); for(var i=0;i<nodes.length;i++){ var t=norm(txt(nodes[i])); for(var j=0;j<labels.length;j++){ if(t===norm(labels[j])) return nodes[i]; } } return null; }
  function findHeroSection(){ return first(document,'.ks-home-hero-section') || sectionOf(first(document,'.ks-home-hero-shell')) || first(document,'main section'); }
  function findIconSection(){ var box=first(document,'.tf-icon-box'); return sectionOf(box); }
  function findBrandSection(){ return sectionOf(sectionTitle([labels().brands,'Rivenditori Ufficiali'])); }
  function cloneIconBoxes(){ var sec=findIconSection(); if(!sec) return ''; var boxes=all(sec,'.tf-icon-box').slice(0,5); if(boxes.length<3) return ''; return '<section class="ksv3-block ksv3-icons"><div class="container"><div class="ksv3-icons-grid">'+boxes.map(function(b){ return b.outerHTML; }).join('')+'</div></div></section>'; }
  function scrapeBrands(){ var sec=findBrandSection(); if(!sec) return []; var out=[]; all(sec,'a,img').forEach(function(n){ var img=n.tagName==='IMG'?n:first(n,'img'); if(!img) return; var src=img.getAttribute('src')||img.getAttribute('data-src')||''; if(!src||out.some(function(x){ return x.image===src; })) return; out.push({url:(n.tagName==='A'?(n.getAttribute('href')||'#'):'#'), image:src, title:img.getAttribute('alt')||img.getAttribute('title')||''}); }); return out.slice(0,12); }
  function feedAll(){ var u=new URL(FEED_ENDPOINT, location.href); u.searchParams.set('mode','all'); u.searchParams.set('_',Date.now().toString()); var recent=readRecent().slice(0,24); if(recent.length) u.searchParams.set('recent', recent.join(',')); return fetchJson(u.toString()); }
  function normalizeSections(s){ s=s||{}; s.combined=uniqById(merge(s.combined,s.offerte,s.evidenza,s.nuovi,s.best,s.top20,s.topselling,s.recent,s.viewed,s.deals)); s.offerte=uniqById(merge(s.offerte,s.deals,s.combined)); s.evidenza=uniqById(merge(s.evidenza,s.combined)); s.nuovi=uniqById(merge(s.nuovi,s.combined)); s.best=uniqById(merge(s.best,s.combined)); s.top20=uniqById(merge(s.top20,s.best,s.combined)); s.topselling=uniqById(merge(s.topselling,s.best,s.top20,s.combined)); s.recent=uniqById(merge(s.recent,s.viewed,s.top20,s.best,s.combined)); s.viewed=uniqById(merge(s.viewed,s.recent,s.top20,s.best,s.combined)); s.deals=uniqById(merge(s.deals,s.offerte,s.combined)); return s; }
  function buildDealsBlock(sections){ var items=fill(shuffled(sections.deals||[]), shuffled(sections.offerte||[]), 4); if(items.length<4) return ''; return '<section class="ksv3-block ksv3-deals"><div class="container"><div class="ksv3-title"><h5>'+esc(labels().deal)+'</h5></div><div class="ksv3-deals-grid">'+items.map(dealCard).join('')+'</div></div></section>'; }
  function buildTabbed(sections){ var tabs=[{key:'offerte',label:labels().offers},{key:'evidenza',label:labels().featured},{key:'nuovi',label:labels().arrivals}].map(function(cfg){ var items=fill(shuffled(sections[cfg.key]||[]), shuffled(sections.combined||[]), 7); return {cfg:cfg,items:items}; }).filter(function(x){ return x.items.length>=5; }); if(!tabs.length) return ''; return '<section class="ksv3-block ksv3-tabbed"><div class="container"><div class="ksv3-head">'+tabs.map(function(tab,idx){ return '<button type="button" class="ksv3-tab'+(idx===0?' is-active':'')+'" data-panel="'+tab.cfg.key+'">'+esc(tab.cfg.label)+'</button>'; }).join('')+'</div><div class="ksv3-panels">'+tabs.map(function(tab,idx){ var big=tab.items[0]||null,left=tab.items.slice(1,4),right=tab.items.slice(4,7); return '<div class="ksv3-panel'+(idx===0?' is-active':'')+'" data-panel="'+tab.cfg.key+'"><div class="ksv3-layout"><div class="ksv3-col">'+left.map(cardSmall).join('')+'</div><div>'+(big?cardBig(big):'')+'</div><div class="ksv3-col">'+right.map(cardSmall).join('')+'</div></div></div>'; }).join('')+'</div></div></section>'; }
  function buildGridBlock(title,items,cls){ if(!items||items.length<4) return ''; return '<section class="ksv3-block '+esc(cls||'')+'"><div class="container"><div class="ksv3-title"><h5>'+esc(title)+'</h5></div><div class="ksv3-grid">'+items.map(cardGrid).join('')+'</div></div></section>'; }
  function buildBest(sections){ return buildGridBlock(labels().best, fill(shuffled(sections.best||[]), shuffled(sections.combined||[]), 10), 'ksv3-best'); }
  function buildViewed(sections){ var items=fill(shuffled(merge(sections.recent,sections.viewed,sections.top20)||[]), shuffled(sections.combined||[]), 8); if(items.length<4) return ''; return '<section class="ksv3-block ksv3-viewed"><div class="container"><div class="ksv3-title"><h5>'+esc(labels().viewed)+'</h5></div><div class="ksv3-grid">'+items.map(cardGrid).join('')+'</div></div></section>'; }
  function buildLower(sections){ var groups=[{title:labels().top20,items:fill(shuffled(sections.top20||[]), shuffled(sections.combined||[]), 5)},{title:labels().featured,items:fill(shuffled(sections.evidenza||[]), shuffled(sections.combined||[]), 5)},{title:labels().topselling,items:fill(shuffled(sections.topselling||[]), shuffled(sections.combined||[]), 5)},{title:labels().onsale,items:fill(shuffled(sections.offerte||[]), shuffled(sections.combined||[]), 5)}].filter(function(g){ return g.items.length>=3; }); if(!groups.length) return ''; return '<section class="ksv3-block ksv3-lower-wrap"><div class="container"><div class="ksv3-lower">'+groups.map(function(g){ return '<div class="ksv3-lower-col"><h5>'+esc(g.title)+'</h5><div class="ksv3-lower-list">'+g.items.map(cardSmall).join('')+'</div></div>'; }).join('')+'</div></div></section>'; }
  function buildBrands(){ var items=scrapeBrands(); if(items.length<4) return ''; return '<section class="ksv3-block ksv3-brands"><div class="container"><div class="ksv3-title"><h5>'+esc(labels().brands)+'</h5></div><div class="ksv3-brands-grid">'+items.slice(0,6).map(function(it){ return '<a class="ksv3-brand" href="'+esc(it.url||'#')+'">'+(it.image?'<img src="'+esc(it.image)+'" alt="'+esc(it.title||'')+'">':'')+'</a>'; }).join('')+'</div></div></section>'; }
  function removeRuntime(){ all(document,'.ksv3-home-root').forEach(function(n){ if(n.parentNode) n.parentNode.removeChild(n); }); }
  function hideOriginalCommercial(){ ['HomeBottomPromoSection','HomeRecentlyViewedSection','HomeLowerColumnsSection'].forEach(function(id){ var n=document.getElementById(id); if(n) hide(n); }); var groups=[[labels().deal,'Occasione Imperdibile'],[labels().offers,labels().featured,labels().arrivals],[labels().best],[labels().viewed,'Scelti da te','Scelti per te'],[labels().top20],[labels().topselling],[labels().onsale]]; groups.forEach(function(g){ var h=sectionTitle(g); if(h) hide(sectionOf(h)); }); var icon=findIconSection(); if(icon) hide(icon); var brand=findBrandSection(); if(brand) hide(brand); }
  function hideClones(){ var headers=all(document,'header,.tf-header,.header,.header-top,.header-bottom').filter(function(n){ return n.offsetParent!==null; }); if(headers.length>1){ headers.slice(1).forEach(function(h){ if(pageY(h)>400) hide(sectionOf(h)||h); }); }
    all(document,'form .tf-topbar, form .tf-header, form .header').forEach(function(n){ if(pageY(n)>400) hide(sectionOf(n)||n); });
  }
  function mount(payload){ if(!isHome()) return; ensureCss(); removeRuntime(); hideClones(); var sections=normalizeSections((payload&&payload.sections)||payload||{}); sections.deals=(payload&&payload.deals)||sections.deals||[]; var mount=findHeroSection()||first(document,'main section')||first(document,'.container'); if(!mount||!mount.parentNode) return; var root=document.createElement('section'); root.className='ksv3-home-root'; root.innerHTML='<div class="ksv3">'+cloneIconBoxes()+buildDealsBlock(sections)+buildTabbed(sections)+buildBest(sections)+buildViewed(sections)+buildLower(sections)+buildBrands()+'</div>'; insertAfter(mount,root); bindThumbs(root); startTimers(root); all(root,'.ksv3-tab').forEach(function(btn){ btn.addEventListener('click',function(){ var panel=btn.getAttribute('data-panel')||''; var wrap=btn.closest('.ksv3-tabbed'); all(wrap,'.ksv3-tab').forEach(function(b){ b.classList.toggle('is-active',b===btn); }); all(wrap,'.ksv3-panel').forEach(function(p){ p.classList.toggle('is-active',p.getAttribute('data-panel')===panel); }); }); }); hideOriginalCommercial(); }
  function fallbackPayload(){ return {sections:{}}; }
  function run(){ if(!isHome()) return; feedAll().then(function(payload){ mount(payload||fallbackPayload()); }).catch(function(){ mount(fallbackPayload()); }); }
  onReady(function(){ if(!isHome()) return; run(); window.addEventListener('load', function(){ setTimeout(run,300); }, {once:true}); window.addEventListener('resize', function(){ clearTimeout(window.__ksv3Resize); window.__ksv3Resize=setTimeout(run,180); }); });
})();
