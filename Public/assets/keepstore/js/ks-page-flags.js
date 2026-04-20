(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function isHome() {
    var p = window.location.pathname || '/';
    return p === '/' || /\/default\.aspx$/i.test(p);
  }
  function isArticle() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function esc(v) { return String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
  function uniqById(list) {
    var seen = {};
    var out = [];
    (list || []).forEach(function (it) {
      var id = parseInt(it && it.id, 10) || 0;
      if (!id || seen[id]) return;
      seen[id] = 1;
      out.push(it);
    });
    return out;
  }
  function shuffle(list) {
    var out = (list || []).slice();
    for (var i = out.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }
  function merge() {
    var out = [];
    for (var i = 0; i < arguments.length; i++) out = out.concat(arguments[i] || []);
    return uniqById(out);
  }
  function fill(primary, fallback, count) {
    var out = [];
    var seen = {};
    function add(list) {
      (list || []).forEach(function (it) {
        if (out.length >= count) return;
        var id = parseInt(it && it.id, 10) || 0;
        if (!id || seen[id]) return;
        seen[id] = 1;
        out.push(it);
      });
    }
    add(primary); add(fallback);
    return out.slice(0, count);
  }
  function parseRecentList(raw) {
    return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) { return Number.isFinite(id) && id > 0; });
  }
  function readCookie(name) {
    var escaped = String(name || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }
  function writeCookie(name, value, days) {
    var expires = '';
    if (typeof days === 'number' && days > 0) {
      var d = new Date();
      d.setTime(d.getTime() + (days * 86400000));
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = String(name || '') + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
  }
  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }
  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
  }
  function mergeRecentLists(primary, secondary) {
    var seen = {}, merged = [];
    [primary || [], secondary || []].forEach(function (list) {
      list.forEach(function (id) {
        if (!Number.isFinite(id) || id <= 0 || seen[id]) return;
        seen[id] = 1;
        merged.push(id);
      });
    });
    return merged.slice(0, MAX_RECENT);
  }
  function readMergedRecent() { return mergeRecentLists(readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))); }
  function persistRecentList(list) {
    var next = (list || []).filter(function (id) { return Number.isFinite(id) && id > 0; }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }
  function updateRecentList(id) {
    var merged = readMergedRecent();
    var next = [id].concat(merged.filter(function (item) { return item !== id; })).slice(0, MAX_RECENT);
    persistRecentList(next);
  }
  function parseIdFromHref(href) {
    var m = String(href || '').match(/[?&]id=(\d+)/i);
    return m ? parseInt(m[1], 10) : 0;
  }
  function detectArticleId() {
    var direct = parseInt((new URLSearchParams(window.location.search || '')).get('id'), 10);
    if (Number.isFinite(direct) && direct > 0) return direct;
    var canonical = q('link[rel="canonical"]');
    var c = canonical ? parseIdFromHref(canonical.getAttribute('href') || '') : 0;
    if (c > 0) return c;
    return 0;
  }
  function trackArticleRecent() { if (isArticle()) { var id = detectArticleId(); if (id > 0) updateRecentList(id); } }

  function currentLang() {
    var html = document.documentElement.getAttribute('lang') || '';
    return /^en/i.test(html) ? 'en' : 'it';
  }
  function t() {
    return currentLang() === 'en'
      ? { deals: 'Deal Of The Day', offers: 'On Sale', featured: 'Featured', arrivals: 'New Arrivals', best: 'Best Seller', viewed: 'Most Viewed', top20: 'Top 20', topSelling: 'Top Selling', onSale: 'On Sale', brands: 'Official Resellers - Best Brands' }
      : { deals: 'Occasione Imperdibile', offers: 'Offerte', featured: 'In Evidenza', arrivals: 'Nuovi Arrivi', best: 'Best Seller', viewed: 'I più visti', top20: 'Top 20', topSelling: "I Più Venduti", onSale: 'In Offerta', brands: 'Rivenditori Ufficiali - I migliori Brand' };
  }
  function fetchJson(url) {
    return fetch(url, { credentials: 'same-origin', headers: { 'X-Requested-With': 'XMLHttpRequest' } }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function feedAll() {
    var u = new URL(FEED_ENDPOINT, location.href);
    u.searchParams.set('mode', 'all');
    u.searchParams.set('_', Date.now().toString());
    var recent = readMergedRecent().slice(0, 24);
    if (recent.length) u.searchParams.set('recent', recent.join(','));
    return fetchJson(u.toString());
  }
  function normalizeSections(payload) {
    var sections = (payload && payload.sections) || {};
    sections.deals = uniqById((payload && payload.deals) || sections.deals || []);
    sections.offerte = uniqById(sections.offerte || []);
    sections.evidenza = uniqById(sections.evidenza || []);
    sections.nuovi = uniqById(sections.nuovi || []);
    sections.best = uniqById(sections.best || []);
    sections.top20 = uniqById(sections.top20 || []);
    sections.topselling = uniqById(sections.topselling || []);
    sections.recent = uniqById(sections.recent || []);
    sections.viewed = uniqById(sections.viewed || []);
    sections.combined = uniqById(merge(sections.combined, sections.deals, sections.offerte, sections.evidenza, sections.nuovi, sections.best, sections.top20, sections.topselling, sections.recent, sections.viewed));
    if (!sections.viewed.length) sections.viewed = uniqById(merge(sections.recent, sections.top20, sections.best, sections.combined));
    if (!sections.recent.length) sections.recent = uniqById(merge(sections.viewed, sections.top20, sections.best, sections.combined));
    return sections;
  }
  function imgs(item) {
    var out = [];
    [item && item.preview, item && item.image].concat(item && item.images || []).forEach(function (src) {
      src = String(src || '').trim();
      if (src && out.indexOf(src) === -1) out.push(src);
    });
    return out.slice(0, 5);
  }
  function img(item) { var arr = imgs(item); return arr[0] || ''; }
  function meta(item) {
    var bits = [];
    if (item && item.brand) bits.push('<span>' + esc(item.brand) + '</span>');
    if (item && item.category) bits.push('<span>' + esc(item.category) + '</span>');
    return bits.length ? '<div class="ksh-meta">' + bits.join('<span class="dot">•</span>') + '</div>' : '';
  }
  function price(item) {
    var p = String(item && item.price || '');
    var o = String(item && item.oldPrice || '');
    return '<div class="ksh-price">' + (p ? '<span class="new">' + esc(p) + ' €</span>' : '') + (o ? '<span class="old">' + esc(o) + ' €</span>' : '') + '</div>';
  }
  function badge(item) {
    var pct = parseInt(item && item.salePercent, 10) || 0;
    return pct > 0 ? '<span class="ksh-badge">-' + pct + '%</span>' : '';
  }
  function cardSmall(item) {
    return '<a class="ksh-side" href="' + esc(item.url || '#') + '">' + badge(item) + '<span class="thumb">' + (img(item) ? '<img src="' + esc(img(item)) + '" alt="' + esc(item.title || '') + '">' : '') + '</span><span class="body">' + meta(item) + '<span class="title">' + esc(item.title || '') + '</span>' + price(item) + '</span></a>';
  }
  function cardGrid(item) {
    return '<a class="ksh-grid-card" href="' + esc(item.url || '#') + '">' + badge(item) + '<span class="thumb">' + (img(item) ? '<img src="' + esc(img(item)) + '" alt="' + esc(item.title || '') + '">' : '') + '</span><span class="body">' + meta(item) + '<span class="title">' + esc(item.title || '') + '</span>' + price(item) + '</span></a>';
  }
  function cardBig(item) {
    var list = imgs(item), main = list[0] || '', thumbs = list.slice(0, 4);
    return '<div class="ksh-big">' + badge(item) + '<div class="main"><a class="media" href="' + esc(item.url || '#') + '">' + (main ? '<img src="' + esc(main) + '" alt="' + esc(item.title || '') + '">' : '') + '</a><div class="body">' + meta(item) + '<a class="title title-big" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' + '<div class="bottom">' + price(item) + '<div class="actions"><a href="#shoppingCart" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-cart2"></i></a><a href="#;" class="box-icon"><i class="icon icon-heart2"></i></a><a href="#quickView" data-bs-toggle="modal" class="box-icon"><i class="icon icon-view"></i></a><a href="#compare" data-bs-toggle="offcanvas" class="box-icon"><i class="icon icon-compare1"></i></a></div></div></div></div><div class="thumbs">' + thumbs.map(function (src, idx) { return '<button type="button" class="thumb-btn' + (idx === 0 ? ' is-active' : '') + '" data-img="' + esc(src) + '">' + (src ? '<img src="' + esc(src) + '" alt="">' : '') + '</button>'; }).join('') + '</div></div>';
  }
  function dealCard(item) {
    var end = String(item && item.dealEnds || '');
    return '<article class="ksh-deal">' + badge(item) + '<a class="media" href="' + esc(item.url || '#') + '">' + (img(item) ? '<img src="' + esc(img(item)) + '" alt="' + esc(item.title || '') + '">' : '') + '</a><div class="body">' + meta(item) + '<a class="title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' + price(item) + '<div class="save">' + (item && item.oldPrice ? ('Risparmi ' + esc(item.oldPrice) + ' €') : 'Promo') + '</div><div class="timer" data-end="' + esc(end) + '"><span><b>00</b><small>Giorni</small></span><span><b>00</b><small>Ore</small></span><span><b>00</b><small>Min</small></span><span><b>00</b><small>Sec</small></span></div><div class="avail"><span>Venduti: ' + esc(item && item.sold || 0) + '</span><span>Disponibili: ' + esc(item && item.available || 0) + '</span></div></div></article>';
  }
  function bindThumbs(root) {
    qa('.ksh-big', root).forEach(function (card) {
      var main = q('.media img', card);
      if (!main) return;
      qa('.thumb-btn', card).forEach(function (btn) {
        btn.addEventListener('click', function () {
          qa('.thumb-btn', card).forEach(function (b) { b.classList.remove('is-active'); });
          btn.classList.add('is-active');
          main.src = btn.getAttribute('data-img') || main.src;
        });
      });
    });
  }
  function startTimers(root) {
    function tick() {
      qa('.timer', root).forEach(function (timer) {
        var end = timer.getAttribute('data-end') || '';
        var target = end ? new Date(end) : null;
        var ms = target && !isNaN(target.getTime()) ? Math.max(0, target.getTime() - Date.now()) : 0;
        var s = Math.floor(ms / 1000);
        var d = Math.floor(s / 86400); s -= d * 86400;
        var h = Math.floor(s / 3600); s -= h * 3600;
        var m = Math.floor(s / 60); s -= m * 60;
        var parts = [d, h, m, s].map(function (n) { return (n < 10 ? '0' : '') + n; });
        qa('b', timer).forEach(function (b, idx) { b.textContent = parts[idx] || '00'; });
      });
    }
    tick();
    window.clearInterval(root._ksTimer || 0);
    root._ksTimer = window.setInterval(tick, 1000);
  }
  function ensureCss() {
    if (document.getElementById('ks-home-v4-css')) return;
    var s = document.createElement('style');
    s.id = 'ks-home-v4-css';
    s.textContent = [
      'body.ks-page-home.ks-home-v4-mounted #HomeBottomPromoSection,body.ks-page-home.ks-home-v4-mounted #HomeRecentlyViewedSection,body.ks-page-home.ks-home-v4-mounted #HomeLowerColumnsSection,body.ks-page-home.ks-home-v4-mounted .ks-home-bottom-promo-original,body.ks-page-home.ks-home-v4-mounted .ks-home-best-original,body.ks-page-home.ks-home-v4-mounted .ks-home-viewed-original,body.ks-page-home.ks-home-v4-mounted .ks-home-lower-original,body.ks-page-home.ks-home-v4-mounted .ks-home-brand-original{display:none!important;}',
      'body.ks-page-home .ks-home-v4{padding:22px 0 8px;position:relative;z-index:5;}',
      '.ks-home-v4-block{padding:24px 0 10px;}',
      '.ks-home-v4-title{display:flex;align-items:center;justify-content:space-between;margin:0 0 16px;gap:16px;}',
      '.ks-home-v4-title h5{margin:0;font-size:22px;line-height:1.2;font-weight:700;color:#111827;font-family:var(--ks-font-secondary);}',
      '.ks-home-v4-icons{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:18px;}',
      '.ks-home-v4-icons .tf-icon-box{display:flex;align-items:center;gap:14px;min-height:88px;padding:0 18px;border:1px solid #ebebeb;border-radius:14px;background:#fff;}',
      '.ks-home-v4-deals{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:24px;}',
      '.ks-home-v4-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(0,1fr) minmax(220px,280px);gap:24px;align-items:start;}',
      '.ks-home-v4-col{display:grid;gap:16px;align-content:start;}',
      '.ks-home-v4-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}',
      '.ks-home-v4-viewed .ks-home-v4-grid{grid-template-columns:repeat(4,minmax(0,1fr));}',
      '.ks-home-v4-lower{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;align-items:start;}',
      '.ks-home-v4-lower-col h5{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;font-family:var(--ks-font-secondary);}',
      '.ks-home-v4-lower-list{display:grid;gap:16px;}',
      '.ks-home-v4-brands{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:18px;}',
      '.ks-home-v4-brand{display:flex;align-items:center;justify-content:center;min-height:120px;padding:16px;border:1px solid #edf1f5;border-radius:18px;background:#fff;}',
      '.ksh-deal,.ksh-side,.ksh-grid-card{position:relative;display:grid;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}',
      '.ksh-side{grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;}.ksh-grid-card{grid-template-columns:1fr;gap:12px;align-items:start;padding:16px;}',
      '.ksh-deal .media,.ksh-grid-card .thumb,.ksh-side .thumb,.ksh-big .media{background:#f5f7fb;border-radius:14px;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ksh-deal .media{height:220px;margin-bottom:14px;}.ksh-grid-card .thumb,.ksh-side .thumb{height:170px;}.ksh-side .thumb{height:94px;}',
      '.ksh-deal img,.ksh-grid-card img,.ksh-side img,.ksh-big img,.ks-home-v4-brand img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ksh-deal .body,.ksh-grid-card .body,.ksh-side .body,.ksh-big .body{display:grid;gap:8px;min-width:0;}',
      '.ksh-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}.ksh-meta .dot{opacity:.5;}',
      '.ksh-title,.ksh-side .title,.ksh-grid-card .title,.ksh-deal .title,.ksh-big .title{font-family:var(--ks-font-secondary);font-size:14px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
      '.ksh-big .title-big{font-size:18px;-webkit-line-clamp:3;}',
      '.ksh-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}.ksh-price .new{font-size:16px;color:#ef4444;}.ksh-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}',
      '.ksh-big{background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}',
      '.ksh-big .main{display:grid;gap:16px;min-width:0;}.ksh-big .media{height:420px;border-radius:18px;}.ksh-big .thumbs{display:grid;gap:10px;align-content:start;}.ksh-big .thumb-btn{appearance:none;border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;cursor:pointer;}.ksh-big .thumb-btn.is-active{border-color:#111827;box-shadow:0 0 0 1px #111827 inset;}.ksh-big .bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}.ksh-big .actions{display:flex;align-items:center;gap:10px;justify-content:flex-end;flex-wrap:wrap;}.ksh-big .actions .box-icon{width:36px;height:36px;border-radius:999px;border:1px solid #e5e7eb;background:#fff;display:inline-flex;align-items:center;justify-content:center;color:#4b5563;text-decoration:none;}',
      '.ksh-badge{position:absolute;top:14px;left:14px;display:inline-flex;align-items:center;justify-content:center;min-width:48px;height:48px;padding:0 10px;border-radius:999px;background:#ff4444;color:#fff;font-size:13px;font-weight:700;z-index:3;}',
      '.ksh-deal .save{padding:4px 10px;border-radius:999px;background:#ffe000;color:#111827;font-size:12px;font-weight:700;display:inline-flex;justify-self:start;}.ksh-deal .timer{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;}.ksh-deal .timer span{padding:8px 4px;border-radius:999px;background:#f3f4f6;text-align:center;}.ksh-deal .timer b{display:block;font-size:18px;line-height:1.1;color:#111827;}.ksh-deal .timer small{display:block;font-size:11px;color:#6b7280;margin-top:4px;}.ksh-deal .avail{display:flex;align-items:center;justify-content:space-between;gap:12px;font-size:12px;color:#4b5563;}',
      'body.ks-page-home .ks-home-v4 .container{overflow:visible!important;}',
      '@media (max-width:1199.98px){.ks-home-v4-icons{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-home-v4-deals,.ks-home-v4-grid,.ks-home-v4-brands{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-home-v4-layout{grid-template-columns:1fr;}.ks-home-v4-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ksh-big{grid-template-columns:1fr;}.ksh-big .thumbs{grid-template-columns:repeat(4,64px);}.ks-home-v4-lower{grid-template-columns:repeat(2,minmax(0,1fr));}}',
      '@media (max-width:767.98px){.ks-home-v4-icons,.ks-home-v4-deals,.ks-home-v4-col,.ks-home-v4-grid,.ks-home-v4-viewed .ks-home-v4-grid,.ks-home-v4-lower,.ks-home-v4-brands{grid-template-columns:1fr;}.ksh-big .media{height:260px;}.ksh-grid-card .thumb{height:140px;}}'
    ].join('');
    (document.head || document.documentElement).appendChild(s);
  }
  function findHeroSection() {
    return q('.ks-home-hero-section') || q('.ks-home-hero-shell') || q('main section') || q('.s-banner-wrapper');
  }
  function findIconBoxesSection() {
    var box = q('.tf-icon-box');
    return box ? (box.closest('section, .flat-spacing, .tf-sp-2, .tf-sp-5, .container') || box.parentNode) : null;
  }
  function titleNode(texts) {
    var nodes = qa('h1,h2,h3,h4,h5,h6,button,a,span');
    for (var i = 0; i < nodes.length; i++) {
      var txt = String(nodes[i].textContent || '').replace(/\s+/g, ' ').trim().toLowerCase();
      for (var j = 0; j < texts.length; j++) {
        if (txt === String(texts[j] || '').toLowerCase()) return nodes[i];
      }
    }
    return null;
  }
  function sectionOf(node) {
    return node ? (node.closest('section, .flat-spacing, .tf-sp-2, .tf-sp-5, .container, .row') || node.parentNode) : null;
  }
  function originalBrandSection() {
    return sectionOf(titleNode([t().brands, 'Rivenditori Ufficiali - I migliori Brand', 'Rivenditori Ufficiali'])) || q('#HomeBrandsSection');
  }
  function cloneIconBoxes() {
    var sec = findIconBoxesSection();
    if (!sec) return '';
    var boxes = qa('.tf-icon-box', sec).slice(0, 5);
    if (boxes.length < 3) return '';
    return '<section class="ks-home-v4-block"><div class="container"><div class="ks-home-v4-icons">' + boxes.map(function (n) { return n.outerHTML; }).join('') + '</div></div></section>';
  }
  function scrapeBrands() {
    var sec = originalBrandSection();
    if (!sec) return [];
    var out = [];
    qa('a,img', sec).forEach(function (node) {
      var image = node.tagName === 'IMG' ? node : q('img', node);
      if (!image) return;
      var src = image.getAttribute('src') || image.getAttribute('data-src') || '';
      if (!src) return;
      if (out.some(function (it) { return it.image === src; })) return;
      out.push({ url: node.tagName === 'A' ? (node.getAttribute('href') || '#') : '#', image: src, title: image.getAttribute('alt') || image.getAttribute('title') || '' });
    });
    return out.slice(0, 12);
  }
  function buildDeals(sections) {
    var items = fill(shuffle(sections.deals || []), shuffle(merge(sections.offerte, sections.combined)), 4);
    if (items.length < 4) return '';
    return '<section class="ks-home-v4-block"><div class="container"><div class="ks-home-v4-title"><h5>' + esc(t().deals) + '</h5></div><div class="ks-home-v4-deals">' + items.map(dealCard).join('') + '</div></div></section>';
  }
  function buildTabbed(sections) {
    var tabs = [
      { key: 'offerte', label: t().offers },
      { key: 'evidenza', label: t().featured },
      { key: 'nuovi', label: t().arrivals }
    ].map(function (cfg) {
      var items = fill(shuffle(sections[cfg.key] || []), shuffle(sections.combined || []), 7);
      return { cfg: cfg, items: items };
    }).filter(function (entry) { return entry.items.length >= 5; });
    if (!tabs.length) return '';
    return '<section class="ks-home-v4-block"><div class="container"><div class="ks-runtime-tabs-head">' + tabs.map(function (entry, idx) { return '<button type="button" class="ks-runtime-tab-btn' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + entry.cfg.key + '">' + esc(entry.cfg.label) + '</button>'; }).join('') + '</div>' + tabs.map(function (entry, idx) {
      var big = entry.items[0] || null;
      var left = entry.items.slice(1, 4);
      var right = entry.items.slice(4, 7);
      return '<div class="ks-runtime-panel' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + entry.cfg.key + '"><div class="ks-home-v4-layout"><div class="ks-home-v4-col">' + left.map(cardSmall).join('') + '</div><div>' + (big ? cardBig(big) : '') + '</div><div class="ks-home-v4-col">' + right.map(cardSmall).join('') + '</div></div></div>';
    }).join('') + '</div></section>';
  }
  function buildGrid(title, items, cls) {
    if (!items || items.length < 4) return '';
    return '<section class="ks-home-v4-block ' + esc(cls || '') + '"><div class="container"><div class="ks-home-v4-title"><h5>' + esc(title) + '</h5></div><div class="ks-home-v4-grid">' + items.map(cardGrid).join('') + '</div></div></section>';
  }
  function buildViewed(sections) {
    var items = fill(shuffle(merge(sections.recent, sections.viewed, sections.top20, sections.best)), shuffle(sections.combined), 8);
    return buildGrid(t().viewed, items, 'ks-home-v4-viewed');
  }
  function buildBest(sections) {
    var items = fill(shuffle(sections.best || []), shuffle(sections.combined), 10);
    return buildGrid(t().best, items, 'ks-home-v4-best');
  }
  function buildLower(sections) {
    var groups = [
      { title: t().top20, items: fill(shuffle(sections.top20 || []), shuffle(sections.combined), 5) },
      { title: t().featured, items: fill(shuffle(sections.evidenza || []), shuffle(sections.combined), 5) },
      { title: t().topSelling, items: fill(shuffle(sections.topselling || []), shuffle(sections.combined), 5) },
      { title: t().onSale, items: fill(shuffle(sections.offerte || []), shuffle(sections.combined), 5) }
    ].filter(function (g) { return g.items.length >= 3; });
    if (!groups.length) return '';
    return '<section class="ks-home-v4-block"><div class="container"><div class="ks-home-v4-lower">' + groups.map(function (g) { return '<div class="ks-home-v4-lower-col"><h5>' + esc(g.title) + '</h5><div class="ks-home-v4-lower-list">' + g.items.map(cardSmall).join('') + '</div></div>'; }).join('') + '</div></div></section>';
  }
  function buildBrands() {
    var items = scrapeBrands();
    if (items.length < 4) return '';
    return '<section class="ks-home-v4-block"><div class="container"><div class="ks-home-v4-title"><h5>' + esc(t().brands) + '</h5></div><div class="ks-home-v4-brands">' + items.slice(0, 6).map(function (it) { return '<a class="ks-home-v4-brand" href="' + esc(it.url || '#') + '">' + (it.image ? '<img src="' + esc(it.image) + '" alt="' + esc(it.title || '') + '">' : '') + '</a>'; }).join('') + '</div></div></section>';
  }
  function bindTabs(root) {
    qa('.ks-runtime-tab-btn', root).forEach(function (btn) {
      btn.addEventListener('click', function () {
        var panel = btn.getAttribute('data-panel') || '';
        qa('.ks-runtime-tab-btn', root).forEach(function (b) { b.classList.toggle('is-active', b === btn); });
        qa('.ks-runtime-panel', root).forEach(function (p) { p.classList.toggle('is-active', p.getAttribute('data-panel') === panel); });
      });
    });
  }
  function hideOriginalSections() {
    ['HomeBottomPromoSection', 'HomeRecentlyViewedSection', 'HomeLowerColumnsSection'].forEach(function (id) {
      var node = document.getElementById(id);
      if (node) node.style.setProperty('display', 'none', 'important');
    });
    var brand = originalBrandSection();
    if (brand) brand.style.setProperty('display', 'none', 'important');
    var titles = [
      [t().deals, 'Occasione Imperdibile'],
      [t().offers, t().featured, t().arrivals],
      [t().best, 'Best Seller'],
      [t().viewed, 'I più visti', 'Scelti da te', 'Scelti per te'],
      [t().top20],
      [t().topSelling],
      [t().onSale]
    ];
    titles.forEach(function (group) {
      var node = titleNode(group);
      var sec = sectionOf(node);
      if (sec) sec.style.setProperty('display', 'none', 'important');
    });
  }
  function hideMidPageClones() {
    var pageCut = (findHeroSection() && findHeroSection().getBoundingClientRect ? findHeroSection().getBoundingClientRect().bottom + window.pageYOffset + 350 : 600);
    qa('header,.tf-header,.tf-topbar,.header,.header-bottom,.header-top,footer').forEach(function (node, idx) {
      if (idx === 0) return;
      var top = (node.getBoundingClientRect ? node.getBoundingClientRect().top + window.pageYOffset : 0);
      if (top > pageCut) node.style.setProperty('display', 'none', 'important');
    });
  }
  function removeExistingRuntime() {
    qa('.ks-home-v4').forEach(function (n) { if (n.parentNode) n.parentNode.removeChild(n); });
  }
  function mountRuntime(payload) {
    if (!isHome()) return;
    ensureCss();
    removeExistingRuntime();
    var sections = normalizeSections(payload || {});
    var hero = findHeroSection();
    if (!hero || !hero.parentNode) return;
    var root = document.createElement('div');
    root.className = 'ks-home-v4';
    root.innerHTML = cloneIconBoxes() + buildDeals(sections) + buildTabbed(sections) + buildBest(sections) + buildViewed(sections) + buildLower(sections) + buildBrands();
    if (!root.innerHTML.replace(/\s+/g, '')) return;
    hero.parentNode.insertBefore(root, hero.nextSibling);
    bindThumbs(root);
    bindTabs(root);
    startTimers(root);
    hideOriginalSections();
    hideMidPageClones();
    document.body.classList.add('ks-home-v4-mounted');
  }
  function runHomeRuntime() {
    if (!isHome()) return;
    feedAll().then(function (payload) {
      mountRuntime(payload && payload.sections ? payload : { sections: {} });
    }).catch(function () {
      // leave original server home visible on failure
    });
  }

  onReady(function () {
    trackArticleRecent();
    if (!isHome()) return;
    runHomeRuntime();
    window.addEventListener('load', function () { setTimeout(runHomeRuntime, 250); }, { once: true });
  });
})();
