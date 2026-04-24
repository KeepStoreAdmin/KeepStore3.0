(function(){
  'use strict';
  var COOKIE_NAME='ks_recent';
  var SESSION_KEY='ks_recent_session';
  var MAX_RECENT=100;
  function ready(fn){ if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',fn); else fn(); }
  function qa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function q(sel,root){ return (root||document).querySelector(sel); }
  function isHome(){ var p=(window.location.pathname||'/').toLowerCase(); return p==='/' || /\/default\.aspx$/i.test(p); }
  function isArticle(){ return /\/articolo\.aspx$/i.test(window.location.pathname||''); }
  function readCookie(name){ var m=document.cookie.match(new RegExp('(?:^|; )'+String(name).replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'=([^;]*)')); return m?decodeURIComponent(m[1]):''; }
  function writeCookie(name,value,days){ var d=new Date(); d.setTime(d.getTime()+(days||365)*86400000); document.cookie=name+'='+encodeURIComponent(String(value||''))+'; expires='+d.toUTCString()+'; path=/; SameSite=Lax'; }
  function parseIds(raw){ return String(raw||'').split(',').map(function(x){return parseInt(x,10);}).filter(function(n){return Number.isFinite(n)&&n>0;}); }
  function mergedRecent(){ var out=[], seen={}; var s=[]; try{s=parseIds(sessionStorage.getItem(SESSION_KEY)||'');}catch(e){} [s,parseIds(readCookie(COOKIE_NAME))].forEach(function(list){list.forEach(function(id){ if(!seen[id]){seen[id]=1; out.push(id);} });}); return out.slice(0,MAX_RECENT); }
  function storeRecent(id){ if(!id) return; var next=[id].concat(mergedRecent().filter(function(x){return x!==id;})).slice(0,MAX_RECENT); try{sessionStorage.setItem(SESSION_KEY,next.join(','));}catch(e){} writeCookie(COOKIE_NAME,next.join(','),365); }
  function detectArticleId(){ var id=0; try{id=parseInt(new URLSearchParams(location.search||'').get('id'),10)||0;}catch(e){} if(id) return id; var can=q('link[rel="canonical"]'); var href=can?can.getAttribute('href')||'':''; var m=href.match(/[?&]id=(\d+)/i); return m?parseInt(m[1],10):0; }
  function hide(node,kind){ if(!node) return; node.setAttribute('data-ks-hidden','1'); node.setAttribute('data-ks-artifact',kind||'edge'); node.style.setProperty('display','none','important'); node.style.setProperty('visibility','hidden','important'); node.style.setProperty('opacity','0','important'); node.style.setProperty('pointer-events','none','important'); }
  function rect(node){ try{return node&&node.getBoundingClientRect?node.getBoundingClientRect():null;}catch(e){return null;} }
  function lane(){ var rs=qa('#HomeHeroSection > .container, main .container, #wrapper .container').map(rect).filter(function(r){return r&&r.width>420&&r.height>20;}); if(!rs.length) return {left:Math.max(0,(innerWidth-1200)/2),right:Math.min(innerWidth,(innerWidth+1200)/2)}; rs.sort(function(a,b){return b.width-a.width;}); return rs[0]; }
  function outside(r,l){ if(!r||!l) return false; var c=r.left+r.width/2; return c<l.left-10 || c>l.right+10 || r.right<l.left-10 || r.left>l.right+10; }
  function safe(node){ return !!(node&&node.closest&&node.closest('header,footer,#HomeHeroSection .wrap-item-1,#HeroSliderWrap,.ks-home-departments,.tf-icon-box,.card-product,.ks-row-card,.ks-grid-card,.ks-deal-card,.ksh-side,.ksh-grid-card,.ksh-deal,.ksh-big,#HomeBrandsSection,.ks-home-brand-item,.ks-home-v6')); }
  function root(node){ var cur=node,h=0; while(cur&&cur.parentElement&&h<7){ var p=cur.parentElement; if(!p||/^(body|form|main|header|footer)$/i.test(p.tagName)) break; if(p.id==='wrapper'||p.classList.contains('ks-account-main')) break; if(p.matches&&p.matches('.container,.swiper-wrapper,.tab-pane,.tf-grid-product,.product-list-wrap')) break; var r=rect(p); if(r&&r.width>Math.min(innerWidth*.45,560)) break; cur=p; h++; } return cur||node; }
  function killPopups(){ qa('.auto-popup,.modal-newleter,[class*="modal-newleter"],#HeroSideWrap,.ks-home-side-banners,.wrap-item-3').forEach(function(n){hide(n,'legacy');}); }
  function killText(){ var bad=/welcome|franchis|themeforest|themesflat|onsus|mediacom|home-[0-9]+\.html/i; qa('body *').forEach(function(n){ if(!n||n.nodeType!==1||n.matches('script,style,link,meta,head,title,input,select,textarea')) return; var txt=(n.textContent||'')+' '+(n.getAttribute('src')||'')+' '+(n.getAttribute('data-src')||'')+' '+(n.getAttribute('href')||'')+' '+(n.getAttribute('class')||'')+' '+(n.getAttribute('alt')||''); if(!bad.test(txt)) return; if(safe(n)&&!/welcome|franchis/i.test(txt)) return; var r=rect(n); if(r&&(r.width>innerWidth*.75||r.height<14)) return; hide(root(n),/welcome|franchis/i.test(txt)?'franchising':'demo'); }); }
  function killMedia(){ var l=lane(), groups={}; qa('img').forEach(function(img){ if(!img||safe(img)) return; var r=rect(img); if(!r||r.width<24||r.height<24) return; var src=(img.getAttribute('src')||img.getAttribute('data-src')||'').split('?')[0]; var probe=src+' '+(img.getAttribute('alt')||'')+' '+(img.getAttribute('class')||''); if(/welcome|franchis|themeforest|themesflat|onsus|mediacom|demo|home-[0-9]+\.webp|phone|tablet|mobile/i.test(probe)){ hide(root(img),/welcome|franchis/i.test(probe)?'franchising':'side-media'); return; } if(!outside(r,l)) return; var key=src||('pos-'+Math.round(r.left)+'-'+Math.round(r.top)); (groups[key]=groups[key]||[]).push(img); }); Object.keys(groups).forEach(function(k){ if(groups[k].length<2) return; groups[k].forEach(function(img){hide(root(img),'side-media');}); }); }
  function killFloating(){ var l=lane(); qa('body *').forEach(function(n){ if(!n||n.nodeType!==1||safe(n)||n.matches('script,style,link,meta,input,select,textarea,#wrapper,form,main,header,footer')) return; var r=rect(n); if(!r||r.width<24||r.height<36) return; var cs; try{cs=getComputedStyle(n);}catch(e){cs=null;} var floating=cs&&/fixed|absolute|sticky/i.test(cs.position||''); var txt=(n.textContent||'')+' '+(n.getAttribute('class')||'')+' '+(n.getAttribute('id')||''); var media=qa('img,svg,video,picture',n).length; if((floating||media>=1)&&outside(r,l)) hide(root(n),'edge'); else if(/welcome|franchis|themeforest|themesflat|onsus|mediacom/i.test(txt)) hide(root(n),'franchising'); }); }
  function killClones(){ var h=q('#wrapper header,header.tf-header,header'); var b=h?((rect(h)||{bottom:100}).bottom+pageYOffset):100; qa('header,.tf-header,.tf-topbar,.header-bottom,.inner-header,.tf-footer,footer').forEach(function(n,i){ var r=rect(n); if(!r) return; var top=r.top+pageYOffset; if(i>0&&top>b+220&&r.width>innerWidth*.45) hide(n,'header-clone'); }); }
  function compactHero(){ var side=q('#HeroSideWrap'); hide(side,'legacy'); var section=q('#HomeHeroSection'); var shell=q('#HomeHeroShell'); var slider=q('#HeroSliderWrap'); if(!section||!shell) return; var hasHero=qa('#HeroSliderWrap img').some(function(img){var src=(img.getAttribute('src')||img.getAttribute('data-src')||'').trim(); return src&&src!=='#';}); [section,shell].forEach(function(n){n.className=String(n.className||'').replace(/\bks-home-hero-mode-[^\s]+\b/g,'').replace(/\s+/g,' ').trim(); n.classList.add(hasHero?'ks-home-hero-mode-compact-single':'ks-home-hero-mode-none');}); shell.classList.add('ks-home-force-compact'); if(!hasHero){hide(section,'no-hero'); hide(slider,'no-hero');} }
  function run(){ if(!isHome()) return; killPopups(); compactHero(); killText(); killMedia(); killFloating(); killClones(); }
  ready(function(){ if(isArticle()) storeRecent(detectArticleId()); if(!isHome()) return; run(); [30,100,250,600,1200,2400,4800,9000,15000,22000].forEach(function(ms){setTimeout(run,ms);}); if(window.MutationObserver){var t; new MutationObserver(function(){clearTimeout(t); t=setTimeout(run,80);}).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['src','data-src','style','class']});} });
})();

;(function(){
  'use strict';
  function ready(fn){ if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',fn); else fn(); }
  function qa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function q(sel,root){ return (root||document).querySelector(sel); }
  function isHome(){ var p=(location.pathname||'/').toLowerCase(); return p==='/' || /\/default\.aspx$/i.test(p); }
  function hide(n){ if(!n) return; n.setAttribute('data-ks-artifact','post-brand-legacy'); n.setAttribute('data-ks-hidden','1'); n.style.setProperty('display','none','important'); }
  function rect(n){ try{return n&&n.getBoundingClientRect?n.getBoundingClientRect():null;}catch(e){return null;} }
  function run(){
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
  ready(function(){ run(); [250,900,2400,6000,12000].forEach(function(ms){setTimeout(run,ms);}); });
})();
