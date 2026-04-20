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
  function norm(v){ var s=String(v||'').toLowerCase(); try{s=s.normalize('NFD').replace(/[\u0300-\u036f]/g,'');}catch(err){} return s.replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim(); }
  function isHome(){ var p=location.pathname||'/'; return p==='/' || /\/default\.aspx$/i.test(p); }
  function parseId(href){ var m=String(href||'').match(/[?&]id=(\d+)/i); return m?parseInt(m[1],10):0; }
  function fetchJson(url){ return fetch(url,{credentials:'same-origin',headers:{'X-Requested-With':'XMLHttpRequest'}}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }); }
  function readRecent(){ try{ if(window.KSRecent&&typeof window.KSRecent.read==='function') return (window.KSRecent.read()||[]).filter(Boolean); }catch(err){} return []; }
  function imageOf(item){ var out=[]; [item&&item.preview,item&&item.image].concat(item&&item.images||[]).forEach(function(s){ s=String(s||'').trim(); if(s&&out.indexOf(s)===-1) out.push(s); }); return out[0]||''; }
  function imgsOf(item){ var out=[]; [item&&item.preview,item&&item.image].concat(item&&item.images||[]).forEach(function(s){ s=String(s||'').trim(); if(s&&out.indexOf(s)===-1) out.push(s); }); return out.slice(0,5); }
  function uniq(list){ var seen={}, out=[]; (list||[]).forEach(function(it){ var id=parseInt(it&&it.id,10)||0; if(!id||seen[id]) return; seen[id]=1; out.push(it); }); return out; }
  function merge(){ var out=[]; for(var i=0;i<arguments.length;i++) out=out.concat(arguments[i]||[]); return uniq(out); }
  function shuffled(list){ var arr=(list||[]).slice(); for(var i=arr.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var t=arr[i]; arr[i]=arr[j]; arr[j]=t; } return arr; }
  function take(list,n){ return (list||[]).slice(0,Math.max(0,n||0)); }
  function fill(primary,fallback,count){ var out=[], seen={}; function add(list){ (list||[]).forEach(function(it){ if(out.length>=count) return; var id=parseInt(it&&it.id,10)||0; if(!id||seen[id]) return; seen[id]=1; out.push(it); }); } add(primary); add(fallback); return out.slice(0,count); }
  function sectionTitle(labels){ var nodes=all(document,'h1,h2,h3,h4,h5,h6,a,button,span'); for(var i=0;i<nodes.length;i++){ var t=norm(txt(nodes[i])); for(var j=0;j<labels.length;j++){ if(t===norm(labels[j])) return nodes[i]; } } return null; }
  function sectionOf(node){ return node ? (node.closest('section, .tf-sp-2, .tf-sp-5, .container, .row') || node.parentNode) : null; }
  function insertAfter(ref,node){ if(ref&&ref.parentNode) ref.parentNode.insertBefore(node, ref.nextSibling); }
  function hide(node){ if(!node) return; node.setAttribute('data-ks-hidden-section','1'); node.style.setProperty('display','none','important'); }
  function priceHtml(item){ var p=String(item&&item.price||''); var o=String(item&&item.oldPrice||''); return '<div class="ksv2-price">'+(p?'<span class="new">'+esc(p)+' €</span>':'')+(o?'<span class="old">'+esc(o)+' €</span>':'')+'</div>'; }
  function metaHtml(item){ var bits=[]; if(item&&item.brand) bits.push('<span>'+esc(item.brand)+'</span>'); if(item&&item.category) bits.push('<span>'+esc(item.category)+'</span>'); return bits.length?'<div class="ksv2-meta">'+bits.join('<span class="dot">•</span>')+'</div>':''; }
  function cardSmall(item){ return '<a class="ksv2-side" href="'+esc(item.url||'#')+'"><span class="thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span><span class="body">'+metaHtml(item)+'<span class="title">'+esc(item.title||'')+'</span>'+priceHtml(item)+'</span></a>'; }
  function cardGrid(item){ return '<a class="ksv2-grid-card" href="'+esc(item.url||'#')+'"><span class="thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span><span class="body">'+metaHtml(item)+'<span class="title">'+esc(item.title||'')+'</span>'+priceHtml(item)+'</span></a>'; }
  function cardBig(item){ var imgs=imgsOf(item), main=imgs[0]||''; return '<div class="ksv2-big"><div class="main"><a class="media" href="'+esc(item.url||'#')+'">'+(main?'<img src="'+esc(main)+'" alt="'+esc(item.title||'')+'">':'')+'</a><div class="body">'+metaHtml(item)+'<a class="title title-big" href="'+esc(item.url||'#')+'">'+esc(item.title||'')+'</a><div class="bottom">'+priceHtml(item)+'<div class="actions"><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></div></div></div></div><div class="thumbs">'+imgs.slice(0,4).map(function(src,idx){ return '<button type="button" class="thumb-btn'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">'+(src?'<img src="'+esc(src)+'" alt="">':'')+'</button>'; }).join('')+'</div></div>'; }
  function bindThumbs(root){ all(root,'.ksv2-big').forEach(function(card){ var main=first(card,'.media img'); if(!main) return; all(card,'.thumb-btn').forEach(function(btn){ btn.addEventListener('click',function(){ all(card,'.thumb-btn').forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); main.src=btn.getAttribute('data-img')||main.src; }); }); }); }
  function ensureCss(){ if(document.getElementById('ks-home-runtime-v2')) return; var s=document.createElement('style'); s.id='ks-home-runtime-v2'; s.textContent=[
    '.ksv2-home-root{padding:26px 0 10px;position:relative;z-index:4;}',
    '.ksv2-home-root .container{position:relative;}',
    '.ksv2-block{padding:26px 0 8px;}',
    '.ksv2-head{display:flex;gap:22px;align-items:center;border-bottom:1px solid #e5e7eb;margin-bottom:18px;flex-wrap:wrap;}',
    '.ksv2-tab{appearance:none;border:0;background:none;padding:0 0 14px;font-size:15px;line-height:1.2;font-weight:700;color:#111827;cursor:pointer;position:relative;}',
    '.ksv2-tab.is-active{color:#ef4444;}',
    '.ksv2-tab.is-active:after{content:"";position:absolute;left:0;right:0;bottom:-1px;height:2px;background:#ef4444;border-radius:2px;}',
    '.ksv2-panel{display:none;}', '.ksv2-panel.is-active{display:block;}',
    '.ksv2-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(0,1fr) minmax(220px,280px);gap:24px;align-items:start;}',
    '.ksv2-col{display:grid;gap:18px;align-content:start;}',
    '.ksv2-side,.ksv2-row{display:grid;grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}',
    '.ksv2-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}',
    '.ksv2-grid-card{display:grid;grid-template-columns:1fr;gap:12px;align-items:start;padding:16px;background:#fff;border:1px solid #edf1f5;border-radius:18px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}',
    '.ksv2-grid-card .thumb,.ksv2-side .thumb,.ksv2-row .thumb,.ksv2-big .media{background:#f5f7fb;border-radius:14px;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
    '.ksv2-grid-card .thumb{height:170px;}.ksv2-side .thumb,.ksv2-row .thumb{height:94px;}.ksv2-big .media{height:420px;border-radius:18px;}',
    '.ksv2-grid-card img,.ksv2-side img,.ksv2-row img,.ksv2-big img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
    '.ksv2-side .body,.ksv2-row .body,.ksv2-grid-card .body{display:grid;gap:6px;min-width:0;}',
    '.ksv2-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}',
    '.ksv2 .title,.ksv2-side .title,.ksv2-row .title,.ksv2-grid-card .title,.ksv2-big .title{font-size:14px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
    '.ksv2-big .title-big{font-size:18px;}',
    '.ksv2-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}.ksv2-price .new{font-size:16px;color:#ef4444;}.ksv2-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}',
    '.ksv2-big{background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}',
    '.ksv2-big .main{display:grid;gap:16px;min-width:0;}.ksv2-big .body{display:grid;gap:12px;min-width:0;}.ksv2-big .bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}.ksv2-big .actions{display:flex;gap:10px;flex-wrap:wrap;}.ksv2-big .actions .box-icon{width:36px;height:36px;border-radius:999px;border:1px solid #e5e7eb;background:#fff;display:inline-flex;align-items:center;justify-content:center;color:#4b5563;text-decoration:none;}',
    '.ksv2-big .thumbs{display:grid;gap:10px;align-content:start;}.ksv2-big .thumb-btn{appearance:none;border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;cursor:pointer;}.ksv2-big .thumb-btn.is-active{border-color:#111827;box-shadow:0 0 0 1px #111827 inset;}',
    '.ksv2-title-row{display:flex;align-items:center;justify-content:space-between;margin:0 0 14px;gap:16px;}.ksv2-title-row h5{margin:0;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}',
    '.ksv2-lower{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;align-items:start;}.ksv2-lower-col{min-width:0;}.ksv2-lower-col h5{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;}.ksv2-lower-list{display:grid;gap:16px;}',
    '.ksv2-viewed .ksv2-grid{grid-template-columns:repeat(4,minmax(0,1fr));}',
    '@media (max-width:1199.98px){.ksv2-layout{grid-template-columns:1fr;}.ksv2-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ksv2-big{grid-template-columns:1fr;}.ksv2-big .thumbs{grid-template-columns:repeat(4,64px);}.ksv2-grid{grid-template-columns:repeat(3,minmax(0,1fr));}.ksv2-lower{grid-template-columns:repeat(2,minmax(0,1fr));}}',
    '@media (max-width:767.98px){.ksv2-col,.ksv2-lower{grid-template-columns:1fr;}.ksv2-grid,.ksv2-viewed .ksv2-grid{grid-template-columns:repeat(2,minmax(0,1fr));}.ksv2-grid-card .thumb{height:140px;}.ksv2-big .media{height:280px;}}'
  ].join(''); (document.head||document.documentElement).appendChild(s); }
  function runtimeRoot(){ return first(document,'.ksv2-home-root'); }
  function removeRuntime(){ all(document,'.ksv2-home-root').forEach(function(n){ if(n.parentNode) n.parentNode.removeChild(n); }); }
  function hideOriginals(){
    ['HomeLowerColumnsSection','HomeRecentlyViewedSection','HomeBottomPromoSection'].forEach(function(id){ var n=document.getElementById(id); if(n) hide(n); });
    var labels=[['Offerte','In Evidenza','Nuovi Arrivi'],['Best Seller'],['I più visti','Scelti per te'],['Top 20'],['I Piu Venduti','I Più Venduti'],['In Offerta']];
    labels.forEach(function(group){ var h=sectionTitle(group); if(h) hide(sectionOf(h)); });
  }
  function findDealSection(){ var h=sectionTitle(['Occasione Imperdibile','Deal Of The Day']); return sectionOf(h); }
  function findBrandSection(){ var h=sectionTitle(['Rivenditori Ufficiali - I migliori Brand','Rivenditori Ufficiali']); return sectionOf(h); }
  function getMountPoint(){ return findDealSection() || first(document,'.ks-home-hero-section') || first(document,'main section') || first(document,'.container'); }
  function getBrandPoint(){ return findBrandSection(); }
  function ensureRoot(){ var root=runtimeRoot(); if(root) return root; var mount=getMountPoint(); if(!mount||!mount.parentNode) return null; root=document.createElement('section'); root.className='ksv2-home-root'; insertAfter(mount,root); return root; }
  function feedSections(){ var recent=readRecent().slice(0,20); var u=new URL(FEED_ENDPOINT, location.href); u.searchParams.set('mode','sections'); u.searchParams.set('_',Date.now().toString()); if(recent.length) u.searchParams.set('recent',recent.join(',')); return fetchJson(u.toString()).then(function(d){ return d&&d.sections?d.sections:{}; }); }
  function scrape(){
    function itemFromCard(node){ if(!node) return null; var link=first(node,'a[href*="articolo.aspx?id="]') || (node.matches&&node.matches('a[href*="articolo.aspx?id="]')?node:null); if(!link) return null; var id=parseId(link.getAttribute('href')||''); if(!id) return null; var title=first(node,'.title,.product-title,.name-product,h6 a,h5 a,.link')||link; var img=first(node,'img'); var np=first(node,'.new-price,.price-text,.new,.price .text-primary'); var op=first(node,'.old-price,del,.old'); return {id:id,url:link.getAttribute('href')||'#',title:txt(title),brand:'',category:'',price:txt(np),oldPrice:txt(op),image:img?(img.getAttribute('src')||img.getAttribute('data-src')||''):'',preview:'',images:[]}; }
    var cards=all(document,'a[href*="articolo.aspx?id="], .card-product, .product-item, .tf-grid-product-item, .swiper-slide').map(itemFromCard).filter(Boolean); var combo=uniq(cards);
    return {offerte:combo,evidenza:combo,nuovi:combo,best:combo,top20:combo,topselling:combo,recent:combo,viewed:combo,combined:combo};
  }
  function normalizeSections(s){ s=s||{}; s.combined=uniq(merge(s.combined,s.offerte,s.evidenza,s.nuovi,s.best,s.top20,s.topselling,s.recent,s.viewed)); s.offerte=uniq(merge(s.offerte,s.combined)); s.evidenza=uniq(merge(s.evidenza,s.combined)); s.nuovi=uniq(merge(s.nuovi,s.combined)); s.best=uniq(merge(s.best,s.combined)); s.top20=uniq(merge(s.top20,s.best,s.combined)); s.topselling=uniq(merge(s.topselling,s.best,s.top20,s.combined)); s.recent=uniq(merge(s.recent,s.viewed,s.top20,s.best,s.combined)); s.viewed=uniq(merge(s.viewed,s.recent,s.top20,s.best,s.combined)); return s; }
  function buildTabbed(sections){ var tabs=[{key:'offerte',label:'Offerte'},{key:'evidenza',label:'In Evidenza'},{key:'nuovi',label:'Nuovi Arrivi'}].map(function(cfg){ var items=fill(shuffled(sections[cfg.key]||[]), shuffled(sections.combined||[]), 7); return {cfg:cfg,items:items}; }).filter(function(x){ return x.items.length>=4; }); if(!tabs.length) return ''; return '<section class="ksv2-block ksv2-tabbed"><div class="container"><div class="ksv2-head">'+tabs.map(function(tab,idx){ return '<button type="button" class="ksv2-tab'+(idx===0?' is-active':'')+'" data-panel="'+tab.cfg.key+'">'+tab.cfg.label+'</button>'; }).join('')+'</div><div class="ksv2-panels">'+tabs.map(function(tab,idx){ var big=tab.items[0]||null,left=tab.items.slice(1,4),right=tab.items.slice(4,7); return '<div class="ksv2-panel'+(idx===0?' is-active':'')+'" data-panel="'+tab.cfg.key+'"><div class="ksv2-layout"><div class="ksv2-col">'+left.map(cardSmall).join('')+'</div><div>'+ (big?cardBig(big):'') +'</div><div class="ksv2-col">'+right.map(cardSmall).join('')+'</div></div></div>'; }).join('')+'</div></div></section>'; }
  function buildBest(sections){ var items=fill(shuffled(sections.best||[]), shuffled(sections.combined||[]), 10); if(items.length<4) return ''; return '<section class="ksv2-block ksv2-best"><div class="container"><div class="ksv2-title-row"><h5>Best Seller</h5></div><div class="ksv2-grid">'+items.map(cardGrid).join('')+'</div></div></section>'; }
  function buildViewed(sections){ var items=fill(shuffled(merge(sections.recent,sections.viewed,sections.top20)||[]), shuffled(sections.combined||[]), 8); if(items.length<4) return ''; return '<section class="ksv2-block ksv2-viewed"><div class="container"><div class="ksv2-title-row"><h5>I più visti</h5></div><div class="ksv2-grid">'+items.map(cardGrid).join('')+'</div></div></section>'; }
  function buildLower(sections){ var groups=[{title:'Top 20',items:fill(shuffled(sections.top20||[]), shuffled(sections.combined||[]), 5)},{title:'In Evidenza',items:fill(shuffled(sections.evidenza||[]), shuffled(sections.combined||[]), 5)},{title:'I Piu\' Venduti',items:fill(shuffled(sections.topselling||[]), shuffled(sections.combined||[]), 5)},{title:'In Offerta',items:fill(shuffled(sections.offerte||[]), shuffled(sections.combined||[]), 5)}].filter(function(g){ return g.items.length>=3; }); if(!groups.length) return ''; return '<section class="ksv2-block ksv2-lower-wrap"><div class="container"><div class="ksv2-lower">'+groups.map(function(g){ return '<div class="ksv2-lower-col"><h5>'+g.title+'</h5><div class="ksv2-lower-list">'+g.items.map(cardSmall).join('')+'</div></div>'; }).join('')+'</div></div></section>'; }
  function moveRootBeforeBrand(root){ var brand=getBrandPoint(); if(brand&&brand.parentNode&&root&&root!==brand&&root.compareDocumentPosition(brand)&Node.DOCUMENT_POSITION_FOLLOWING){ brand.parentNode.insertBefore(root, brand); } }
  function mount(sections){ if(!isHome()) return; ensureCss(); sections=normalizeSections(sections); removeRuntime(); hideOriginals(); var root=ensureRoot(); if(!root) return; root.innerHTML='<div class="ksv2">'+buildTabbed(sections)+buildBest(sections)+buildViewed(sections)+buildLower(sections)+'</div>'; bindThumbs(root); all(root,'img').forEach(function(img){ img.addEventListener('error', function(){ img.style.visibility='hidden'; }); }); all(root,'.ksv2-tab').forEach(function(btn){ btn.addEventListener('click',function(){ var panel=btn.getAttribute('data-panel')||''; var wrap=btn.closest('.ksv2-tabbed'); all(wrap,'.ksv2-tab').forEach(function(b){ b.classList.toggle('is-active', b===btn); }); all(wrap,'.ksv2-panel').forEach(function(p){ p.classList.toggle('is-active', p.getAttribute('data-panel')===panel); }); }); }); moveRootBeforeBrand(root); }
  function hideFooterHeaderClone(){ var headers=all(document,'header, .tf-header, .header'); if(headers.length<2) return; var main=headers[0]; var mainBottom=(main.getBoundingClientRect()||{bottom:0}).bottom; headers.slice(1).forEach(function(h){ var r=h.getBoundingClientRect(); if(r&&r.top>mainBottom+300) hide(h); }); }
  function run(){ if(!isHome()) return; hideFooterHeaderClone(); Promise.resolve().then(feedSections).catch(function(){ return {}; }).then(function(sections){ if(!sections||!Object.keys(sections).length) sections=scrape(); mount(sections); }).catch(function(){ mount(scrape()); }); }
  onReady(function(){ if(!isHome()) return; setTimeout(run,200); window.addEventListener('load', function(){ setTimeout(run,500); }, {once:true}); window.addEventListener('resize', function(){ setTimeout(run,120); }); });
})();
