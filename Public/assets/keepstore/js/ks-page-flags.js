(function(){
  'use strict';

  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;

  function onReady(fn){ if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', fn); } else { fn(); } }
  function q(sel,root){ return (root||document).querySelector(sel); }
  function qa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function isHome(){ var p=(window.location.pathname||'/').toLowerCase(); return p==='/' || /\/default\.aspx$/.test(p); }
  function isArticle(){ return /\/articolo\.aspx$/i.test(window.location.pathname||''); }
  function esc(v){ return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function txt(node){ return String(node&&node.textContent||'').replace(/\s+/g,' ').trim(); }
  function norm(v){ return String(v||'').toLowerCase().replace(/\s+/g,' ').trim(); }
  function currentLang(){ var html=(document.documentElement.getAttribute('lang')||'').toLowerCase(); return html.indexOf('en')===0 ? 'en':'it'; }
  function labels(){
    return currentLang()==='en'
      ? {offers:'On Sale', featured:'Featured', arrivals:'New Arrivals', best:'Best Seller', viewed:'Most Viewed', top20:'Top 20', selling:'Top Selling', offsale:'On Sale'}
      : {offers:'Offerte', featured:'In Evidenza', arrivals:'Nuovi Arrivi', best:'Best Seller', viewed:'I più visti', top20:'Top 20', selling:'I Più Venduti', offsale:'In Offerta'};
  }

  function readCookie(name){ var m=document.cookie.match(new RegExp('(?:^|; )'+String(name||'').replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'=([^;]*)')); return m?decodeURIComponent(m[1]):''; }
  function writeCookie(name,value,days){ var expires=''; if(days){ var d=new Date(); d.setTime(d.getTime()+days*86400000); expires='; expires='+d.toUTCString(); } document.cookie=name+'='+encodeURIComponent(value||'')+expires+'; path=/; SameSite=Lax'; }
  function parseIds(raw){ return String(raw||'').split(',').map(function(x){ return parseInt(x,10); }).filter(function(n){ return Number.isFinite(n)&&n>0; }); }
  function readSessionRecent(){ try { return parseIds(sessionStorage.getItem(SESSION_KEY)||''); } catch(err){ return []; } }
  function writeSessionRecent(list){ try { sessionStorage.setItem(SESSION_KEY,(list||[]).join(',')); } catch(err){} }
  function mergedRecent(){
    var seen={}, out=[];
    [readSessionRecent(), parseIds(readCookie(COOKIE_NAME))].forEach(function(list){
      (list||[]).forEach(function(id){ if(!id||seen[id]) return; seen[id]=1; out.push(id); });
    });
    return out.slice(0,MAX_RECENT);
  }
  function persistRecent(id){
    if(!id||id<1) return;
    var list=[id].concat(mergedRecent().filter(function(x){ return x!==id; })).slice(0,MAX_RECENT);
    writeCookie(COOKIE_NAME,list.join(','),365);
    writeSessionRecent(list);
  }
  function detectArticleId(){
    try {
      var sp=new URLSearchParams(window.location.search||'');
      var id=parseInt(sp.get('id'),10);
      if(id>0) return id;
    } catch(err){}
    return 0;
  }
  function trackRecent(){ if(isArticle()){ var id=detectArticleId(); if(id>0) persistRecent(id); } }

  function uniqById(list){
    var seen={}, out=[];
    (list||[]).forEach(function(item){ var id=parseInt(item&&item.id,10)||0; if(!id||seen[id]) return; seen[id]=1; out.push(item); });
    return out;
  }
  function mergeLists(){ var all=[]; for(var i=0;i<arguments.length;i++) all=all.concat(arguments[i]||[]); return uniqById(all); }
  function shuffle(list){ var out=(list||[]).slice(); for(var i=out.length-1;i>0;i--){ var j=Math.floor(Math.random()*(i+1)); var t=out[i]; out[i]=out[j]; out[j]=t; } return out; }
  function fill(primary, fallback, n){ return uniqById((primary||[]).concat(fallback||[])).slice(0,n); }
  function imageOf(item){ var imgs=[]; [item&&item.preview,item&&item.image].concat(item&&item.images||[]).forEach(function(src){ src=String(src||'').trim(); if(src && imgs.indexOf(src)===-1) imgs.push(src); }); return imgs[0]||''; }
  function thumbsOf(item){ var imgs=[]; [item&&item.preview,item&&item.image].concat(item&&item.images||[]).forEach(function(src){ src=String(src||'').trim(); if(src && imgs.indexOf(src)===-1) imgs.push(src); }); return imgs.slice(0,5); }
  function priceOf(item){ return String(item&&item.price||''); }
  function oldPriceOf(item){ return String(item&&item.oldPrice||''); }
  function hrefOf(item){ return String(item&&item.url||'#'); }

  function findHeading(values){
    var wanted=(Array.isArray(values)?values:[values]).map(norm);
    var nodes=qa('h1,h2,h3,h4,h5,h6,a,button,span,strong');
    for(var i=0;i<nodes.length;i++){
      var t=norm(txt(nodes[i]));
      if(wanted.indexOf(t)!==-1) return nodes[i];
    }
    return null;
  }
  function sectionOf(node){ return node ? (node.closest('section,.tf-sp-2,.tf-sp-5,.container,.row,.flat-animate-tab,.tab-product,.fl-control-sw2') || node.parentNode) : null; }
  function hideSection(node){ if(node){ node.setAttribute('data-ks-hide','1'); node.style.setProperty('display','none','important'); } }
  function insertAfter(ref,node){ if(ref&&ref.parentNode) ref.parentNode.insertBefore(node, ref.nextSibling); }

  function suppressPopup(){
    qa('.auto-popup,.modal-newleter,[class*="modal-newleter"]').forEach(function(n){ n.style.setProperty('display','none','important'); });
    qa('.modal-backdrop,.offcanvas-backdrop').forEach(function(n){ if(n.parentNode) n.parentNode.removeChild(n); });
    if(document.body){ document.body.classList.remove('modal-open'); document.body.style.overflow=''; document.body.style.paddingRight=''; }
  }
  function compactHero(){
    var side=q('#HeroSideWrap'); if(side) side.style.setProperty('display','none','important');
    var shell=q('.ks-home-hero-shell'); if(shell){ shell.classList.add('ks-home-force-compact'); shell.classList.remove('ks-home-hero-mode-full'); }
  }
  function removeArtifacts(){
    var badTokens=['welcome','franchis','onsus','themeforest','themesflat','mediacom','demo'];
    qa('div,section,aside,span,p,a,img').forEach(function(n){
      if(!n || n.closest('.ks-home-departments,.ks-home-hero-shell,.ks-home-runtime-root,.brand-item,header,footer,.swiper')) return;
      var raw=(n.id||'')+' '+(n.className||'')+' '+txt(n).slice(0,120)+' '+(n.getAttribute?n.getAttribute('src')||'':'');
      raw=norm(raw);
      for(var i=0;i<badTokens.length;i++){
        if(raw.indexOf(badTokens[i])!==-1){ n.style.setProperty('display','none','important'); n.setAttribute('data-ks-artifact','1'); break; }
      }
    });
  }

  function sideCard(item){
    return '<a class="ks-home-card ks-home-card-side" href="'+esc(hrefOf(item))+'">'+
      '<span class="ks-home-card-thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span>'+
      '<span class="ks-home-card-body">'+
      '<span class="ks-home-card-meta">'+esc(item.brand||item.category||'')+'</span>'+
      '<span class="ks-home-card-title">'+esc(item.title||'')+'</span>'+
      '<span class="ks-home-card-price"><span class="new">'+esc(priceOf(item))+' €</span>'+(oldPriceOf(item)?'<span class="old">'+esc(oldPriceOf(item))+' €</span>':'')+'</span>'+
      '</span></a>';
  }
  function gridCard(item){
    return '<a class="ks-home-card ks-home-card-grid" href="'+esc(hrefOf(item))+'">'+
      '<span class="ks-home-card-grid-thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span>'+
      '<span class="ks-home-card-body">'+
      '<span class="ks-home-card-meta">'+esc(item.brand||item.category||'')+'</span>'+
      '<span class="ks-home-card-title">'+esc(item.title||'')+'</span>'+
      '<span class="ks-home-card-price"><span class="new">'+esc(priceOf(item))+' €</span>'+(oldPriceOf(item)?'<span class="old">'+esc(oldPriceOf(item))+' €</span>':'')+'</span>'+
      '</span></a>';
  }
  function rowCard(item){
    return '<a class="ks-home-card ks-home-card-row" href="'+esc(hrefOf(item))+'">'+
      '<span class="ks-home-card-thumb">'+(imageOf(item)?'<img src="'+esc(imageOf(item))+'" alt="'+esc(item.title||'')+'">':'')+'</span>'+
      '<span class="ks-home-card-body">'+
      '<span class="ks-home-card-meta">'+esc(item.brand||item.category||'')+'</span>'+
      '<span class="ks-home-card-title">'+esc(item.title||'')+'</span>'+
      '<span class="ks-home-card-price"><span class="new">'+esc(priceOf(item))+' €</span>'+(oldPriceOf(item)?'<span class="old">'+esc(oldPriceOf(item))+' €</span>':'')+'</span>'+
      '</span></a>';
  }
  function bigCard(item){
    var thumbs=thumbsOf(item), main=thumbs[0]||'';
    return '<div class="ks-home-big-card">'+
      '<div class="ks-home-big-main">'+
        '<a class="ks-home-big-media" href="'+esc(hrefOf(item))+'">'+(main?'<img src="'+esc(main)+'" alt="'+esc(item.title||'')+'">':'')+'</a>'+
        '<div class="ks-home-big-body">'+
          '<span class="ks-home-card-meta">'+esc(item.brand||item.category||'')+'</span>'+
          '<a class="ks-home-card-title ks-home-card-title-big" href="'+esc(hrefOf(item))+'">'+esc(item.title||'')+'</a>'+
          '<div class="ks-home-big-bottom"><span class="ks-home-card-price"><span class="new">'+esc(priceOf(item))+' €</span>'+(oldPriceOf(item)?'<span class="old">'+esc(oldPriceOf(item))+' €</span>':'')+'</span></div>'+
        '</div>'+
      '</div>'+
      '<div class="ks-home-big-thumbs">'+thumbs.map(function(src,idx){ return '<button type="button" class="ks-home-big-thumb'+(idx===0?' is-active':'')+'" data-img="'+esc(src)+'">'+(src?'<img src="'+esc(src)+'" alt="">':'')+'</button>'; }).join('')+'</div>'+
    '</div>';
  }
  function bindThumbs(root){
    qa('.ks-home-big-card',root).forEach(function(card){
      var main=q('.ks-home-big-media img',card); if(!main) return;
      qa('.ks-home-big-thumb',card).forEach(function(btn){ btn.addEventListener('click', function(){ qa('.ks-home-big-thumb',card).forEach(function(b){ b.classList.remove('is-active'); }); btn.classList.add('is-active'); main.src=btn.getAttribute('data-img')||main.src; }); });
    });
  }

  function buildTabbed(host, sections){
    var L=labels();
    var defs=[
      {key:'offerte', title:L.offers},
      {key:'evidenza', title:L.featured},
      {key:'nuovi', title:L.arrivals}
    ];
    var usable=defs.map(function(def){ return { key:def.key, title:def.title, items:fill(shuffle(sections[def.key]), shuffle(sections.combined), 7) }; }).filter(function(x){ return x.items.length>=5; });
    if(!usable.length) return null;
    var node=document.createElement('section');
    node.className='ks-home-runtime-root ks-home-runtime-tabbed';
    node.innerHTML='<div class="container">'+
      '<div class="ks-home-tabs-head">'+usable.map(function(u,i){ return '<button type="button" class="ks-home-tab-btn'+(i===0?' is-active':'')+'" data-panel="'+esc(u.key)+'">'+esc(u.title)+'</button>'; }).join('')+'</div>'+
      '<div class="ks-home-tabs-body">'+usable.map(function(u,i){ var center=u.items[0], left=u.items.slice(1,4), right=u.items.slice(4,7); return '<div class="ks-home-tab-panel'+(i===0?' is-active':'')+'" data-panel="'+esc(u.key)+'"><div class="ks-home-tab-layout"><div class="ks-home-side-col">'+left.map(sideCard).join('')+'</div><div class="ks-home-big-wrap">'+bigCard(center)+'</div><div class="ks-home-side-col">'+right.map(sideCard).join('')+'</div></div></div>'; }).join('')+'</div>'+
      '</div>';
    insertAfter(host,node);
    qa('.ks-home-tab-btn',node).forEach(function(btn){ btn.addEventListener('click', function(){ var panel=btn.getAttribute('data-panel')||''; qa('.ks-home-tab-btn',node).forEach(function(b){ b.classList.toggle('is-active', b===btn); }); qa('.ks-home-tab-panel',node).forEach(function(p){ p.classList.toggle('is-active', p.getAttribute('data-panel')===panel); }); }); });
    bindThumbs(node);
    return node;
  }

  function buildGridSection(afterNode, title, items, cls, count){
    items=fill(shuffle(items), [], count||items.length);
    if(!items.length) return null;
    var node=document.createElement('section');
    node.className='ks-home-runtime-root '+(cls||'');
    node.innerHTML='<div class="container"><div class="flat-title"><h5>'+esc(title)+'</h5></div><div class="ks-home-grid">'+items.map(gridCard).join('')+'</div></div>';
    insertAfter(afterNode,node);
    return node;
  }

  function buildLower(afterNode, sections){
    var L=labels();
    var groups=[
      {title:L.top20, items:fill(shuffle(sections.top20), shuffle(sections.combined), 5)},
      {title:L.featured, items:fill(shuffle(sections.evidenza), shuffle(sections.combined), 5)},
      {title:L.selling, items:fill(shuffle(sections.topselling), shuffle(sections.combined), 5)},
      {title:L.offsale, items:fill(shuffle(sections.offerte), shuffle(sections.combined), 5)}
    ].filter(function(g){ return g.items.length>=3; });
    if(!groups.length) return null;
    var node=document.createElement('section');
    node.className='ks-home-runtime-root ks-home-runtime-lower';
    node.innerHTML='<div class="container"><div class="ks-home-lower-grid">'+groups.map(function(g){ return '<div class="ks-home-lower-col"><h5 class="ks-home-col-title">'+esc(g.title)+'</h5><div class="ks-home-col-list">'+g.items.map(rowCard).join('')+'</div></div>'; }).join('')+'</div></div>';
    insertAfter(afterNode,node);
    return node;
  }

  function cleanupOriginals(){
    var L=labels();
    [ [L.offers,L.featured,L.arrivals], [L.best], [L.viewed,'Scelti da te','Chosen for you'], [L.top20], [L.selling], ['In Offerta','On Sale'] ].forEach(function(arr){
      var h=findHeading(arr); if(h) hideSection(sectionOf(h));
    });
    var lower=q('#HomeLowerColumnsSection'); if(lower) hideSection(lower);
    var recent=q('#HomeRecentlyViewedSection'); if(recent) hideSection(recent);
  }

  function removeRuntimeBlocks(){ qa('.ks-home-runtime-root').forEach(function(n){ if(n.parentNode) n.parentNode.removeChild(n); }); }

  function loadSections(){
    var recent=mergedRecent().slice(0,20);
    var url=FEED_ENDPOINT+'?mode=sections&_=' + Date.now();
    if(recent.length) url+='&recent='+encodeURIComponent(recent.join(','));
    return fetch(url,{credentials:'same-origin', headers:{'X-Requested-With':'XMLHttpRequest'}}).then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); }).then(function(data){ return data&&data.sections?data.sections:{}; });
  }

  function mountHome(){
    if(!isHome()) return;
    suppressPopup(); compactHero(); removeArtifacts(); removeRuntimeBlocks();
    loadSections().then(function(sections){
      sections=sections||{};
      sections.offerte=uniqById(sections.offerte||[]);
      sections.evidenza=uniqById(sections.evidenza||[]);
      sections.nuovi=uniqById(sections.nuovi||[]);
      sections.best=uniqById(sections.best||[]);
      sections.top20=uniqById(sections.top20||[]);
      sections.topselling=uniqById(sections.topselling||[]);
      sections.recent=uniqById((sections.recent||[]).concat(sections.viewed||[]));
      sections.combined=uniqById(sections.combined||mergeLists(sections.offerte,sections.evidenza,sections.nuovi,sections.best,sections.top20,sections.topselling,sections.recent));

      var dealHeading=findHeading(['Occasione Imperdibile','Deal of the Day']);
      var dealSection=sectionOf(dealHeading);
      var tabAnchor=dealSection || q('.ks-home-hero-section') || q('#HomeHeroSection');
      var tabbed=buildTabbed(tabAnchor, sections);
      var best=buildGridSection(tabbed||tabAnchor, labels().best, fill(shuffle(sections.best), shuffle(sections.combined), 10), 'ks-home-runtime-best', 10);
      var recent=buildGridSection(best||tabbed||tabAnchor, labels().viewed, fill(shuffle(sections.recent), shuffle(sections.combined), 8), 'ks-home-runtime-viewed', 8);
      var lower=buildLower(recent||best||tabbed||tabAnchor, sections);
      if(tabbed||best||recent||lower) cleanupOriginals();
    }).catch(function(){});
  }

  onReady(function(){
    trackRecent();
    if(isHome()){
      mountHome();
      window.addEventListener('load', mountHome, { once:true });
      setTimeout(mountHome, 1200);
      setTimeout(mountHome, 3200);
    }
  });
})();
