(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];

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
  function mergeRecentLists(primary, secondary) { var seen=new Set(), merged=[]; [primary||[],secondary||[]].forEach(function(list){ list.forEach(function(id){ if(!Number.isFinite(id)||id<=0||seen.has(id)) return; seen.add(id); merged.push(id); }); }); return merged.slice(0,MAX_RECENT); }
  function readMergedRecent() { return mergeRecentLists(readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))); }
  function persistRecentList(list) { var next=(list||[]).filter(function(id){ return Number.isFinite(id)&&id>0; }).slice(0,MAX_RECENT); writeCookie(COOKIE_NAME,next.join(','),365); writeSessionRecent(next); }
  function updateRecentList(id) { var merged=readMergedRecent(); var next=[id].concat(merged.filter(function(item){ return item!==id; })).slice(0,MAX_RECENT); persistRecentList(next); return next; }
  function parseArticleIdFromHref(href) { if (!href) return 0; var match = String(href).match(/[?&]id=(\d+)/i); return match ? parseInt(match[1], 10) : 0; }
  function detectArticleId() { var direct=parseInt(getQueryParam('id'),10); if(Number.isFinite(direct)&&direct>0) return direct; var canonical=document.querySelector('link[rel="canonical"]'); var fromCanonical=canonical?parseArticleIdFromHref(canonical.getAttribute('href')||''):0; if(fromCanonical>0) return fromCanonical; if(document.body){ var bodyId=parseInt(document.body.getAttribute('data-article-id')||document.body.getAttribute('data-id')||'',10); if(Number.isFinite(bodyId)&&bodyId>0) return bodyId; } return 0; }
  function trackArticleRecent() { if (!isArticlePage()) return; var id=detectArticleId(); if (Number.isFinite(id) && id>0) updateRecentList(id); }

  function normalizeText(value) { var text=String(value||'').toLowerCase(); try { text=text.normalize('NFD').replace(/[\u0300-\u036f]/g,''); } catch(err) {} return text.replace(/[^a-z0-9]+/g,' ').replace(/\s+/g,' ').trim(); }
  function containsToken(raw) { var value=normalizeText(raw); return BLOCKED_TOKENS.some(function(token){ return value.indexOf(token)!==-1; }); }
  function rectOf(node) { if(!node||typeof node.getBoundingClientRect!=='function') return null; var rect=node.getBoundingClientRect(); if(!rect||(!rect.width&&!rect.height)) return null; return rect; }
  function styleOf(node) { try { return node ? window.getComputedStyle(node) : null; } catch (err) { return null; } }
  function textOf(node) { return String(node && node.textContent || '').replace(/\s+/g,' ').trim(); }
  function hideNode(node, flag) { if(!node||!node.style) return; node.style.setProperty('display','none','important'); node.style.setProperty('visibility','hidden','important'); node.style.setProperty('opacity','0','important'); node.style.setProperty('pointer-events','none','important'); if(flag) node.setAttribute(flag,'1'); }

  function suppressNewsletterPopup() {
    Array.prototype.slice.call(document.querySelectorAll('.auto-popup, .modal-newleter, [class*="modal-newleter"]')).forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); });
    Array.prototype.slice.call(document.querySelectorAll('.modal-backdrop, .offcanvas-backdrop')).forEach(function(node){ hideNode(node,'data-ks-hidden-popup'); if(node.parentNode) node.parentNode.removeChild(node); });
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
    return !!(node && node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-departments, .ks-home-hero-shell, .card-product, .product-list-wrap, .tf-grid-product-item, .swiper'));
  }

  function hideWelcomeFranchisingAnywhere() {
    Array.prototype.slice.call(document.querySelectorAll('div,section,aside,span,p,a,img')).forEach(function(node){
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
    Array.prototype.slice.call(document.querySelectorAll('header, div, section')).forEach(function(node){
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
      [350, 1400, 4200].forEach(function(delay){ window.setTimeout(runHomeCleanup, delay); });
      window.addEventListener('load', runHomeCleanup, { once: true });
      window.addEventListener('resize', runHomeCleanup);
    }
  });
})();
