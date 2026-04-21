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
  function q(sel, root) { return (root || document).querySelector(sel); }
  function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function isHome() {
    var p = (window.location.pathname || '/').toLowerCase();
    return p === '/' || /\/default\.aspx$/i.test(p);
  }
  function isArticle() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
  function esc(v) { return String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
  function norm(v) {
    return String(v || '')
      .toLowerCase()
      .replace(/[àáâãäå]/g, 'a').replace(/[èéêë]/g, 'e').replace(/[ìíîï]/g, 'i').replace(/[òóôõö]/g, 'o').replace(/[ùúûü]/g, 'u')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }
  function currentLang() {
    var html = document.documentElement.getAttribute('lang') || '';
    return /^en/i.test(html) ? 'en' : 'it';
  }
  function t() {
    return currentLang() === 'en'
      ? { deals: 'Deal Of The Day', offers: 'On Sale', featured: 'Featured', arrivals: 'New Arrivals', best: 'Best Seller', viewed: 'Most Viewed', top20: 'Top 20', topSelling: 'Top Selling', onSale: 'On Sale', brands: 'Official Resellers - Best Brands', chosen: 'Chosen For You' }
      : { deals: 'Occasione Imperdibile', offers: 'Offerte', featured: 'In Evidenza', arrivals: 'Nuovi Arrivi', best: 'Best Seller', viewed: 'I più visti', top20: 'Top 20', topSelling: 'I Più Venduti', onSale: 'In Offerta', brands: 'Rivenditori Ufficiali - I migliori Brand', chosen: 'Scelti Da Te' };
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
      d.setTime(d.getTime() + days * 86400000);
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = String(name || '') + '=' + encodeURIComponent(String(value || '')) + expires + '; path=/; SameSite=Lax';
  }
  function parseRecentList(raw) {
    return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) { return Number.isFinite(id) && id > 0; });
  }
  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }
  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
  }
  function readMergedRecent() {
    var seen = {}, out = [];
    [readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))].forEach(function (list) {
      (list || []).forEach(function (id) {
        if (!id || seen[id]) return;
        seen[id] = 1; out.push(id);
      });
    });
    return out.slice(0, MAX_RECENT);
  }
  function updateRecent(id) {
    var next = [id].concat(readMergedRecent().filter(function (n) { return n !== id; })).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }
  function detectArticleId() {
    try {
      var direct = parseInt((new URLSearchParams(window.location.search || '')).get('id'), 10);
      if (Number.isFinite(direct) && direct > 0) return direct;
    } catch (err) {}
    var link = q('link[rel="canonical"]');
    var href = link ? (link.getAttribute('href') || '') : '';
    var m = href.match(/[?&]id=(\d+)/i);
    return m ? parseInt(m[1], 10) : 0;
  }

  function hide(node) {
    if (!node) return;
    node.setAttribute('data-ks-hidden', '1');
    node.style.setProperty('display', 'none', 'important');
  }
  function show(node) {
    if (!node) return;
    node.removeAttribute('data-ks-hidden');
    node.style.removeProperty('display');
  }
  function rect(node) {
    try { return node && node.getBoundingClientRect ? node.getBoundingClientRect() : null; } catch (err) { return null; }
  }
  function laneRect() {
    var node = q('#HomeHeroSection > .container') || q('.page-content > .container') || q('#wrapper .container');
    var r = rect(node);
    return (r && r.width > 640) ? r : { left: 72, right: Math.max(window.innerWidth - 72, 980) };
  }
  function outsideLane(r, lane) {
    if (!r || !lane) return false;
    return r.right <= lane.left - 12 || r.left >= lane.right + 12;
  }
  function artifactRoot(node) {
    var current = node, hops = 0;
    while (current && current.parentElement && hops < 8) {
      var parent = current.parentElement;
      if (!parent || /^(body|main|form|header|footer)$/i.test(parent.tagName)) break;
      if (parent.matches && parent.matches('.container,.ks-home-departments,.ks-home-hero-shell,.s-banner-wrapper,.flat-animate-tab,.tf-grid-product,.ks-home-v6')) break;
      var r = rect(parent);
      if (!r || r.width > Math.min(window.innerWidth * 0.5, 620)) break;
      current = parent; hops += 1;
    }
    return current || node;
  }
  function hideFranchisingRails() {
    var lane = laneRect();
    qa('div,section,aside,a,span,p,img').forEach(function (node) {
      if (!node || node.closest('#wrapper header,#wrapper footer,.container,.ks-home-v6,.ks-home-departments,.menu-category-list')) return;
      var r = rect(node);
      if (!r || !outsideLane(r, lane) || r.height < 60) return;
      var txt = (node.textContent || '') + ' ' + (node.getAttribute && (node.getAttribute('alt') || node.getAttribute('src') || node.getAttribute('data-src')) || '');
      if (/welcome|franchis|mediacom|themeforest|onsus/i.test(txt)) hide(artifactRoot(node));
    });
  }
  function hideRepeatedMarginMedia() {
    var lane = laneRect(), groups = {};
    qa('img').forEach(function (img) {
      if (!img || img.closest('#wrapper header,#wrapper footer,.container,.ks-home-v6')) return;
      var r = rect(img);
      if (!r || !outsideLane(r, lane) || r.width < 40 || r.height < 60 || r.width > 240 || r.height > 340) return;
      var src = (img.getAttribute('src') || img.getAttribute('data-src') || '').split('?')[0];
      if (!src) return;
      groups[src] = groups[src] || [];
      groups[src].push(img);
    });
    Object.keys(groups).forEach(function (src) {
      if (groups[src].length < 2) return;
      groups[src].forEach(function (img) { hide(artifactRoot(img)); });
    });
  }
  function hideMidPageHeaderClones() {
    var header = q('header.tf-header') || q('header');
    var threshold = (rect(header) ? rect(header).bottom + window.pageYOffset : 120) + 240;
    qa('header,.tf-header,.tf-topbar,.header,.header-bottom,.header-top,.inner-header').forEach(function (node, idx) {
      if (idx === 0) return;
      var r = rect(node); if (!r) return;
      var top = r.top + window.pageYOffset;
      if (top > threshold && r.width > window.innerWidth * 0.55 && r.height > 36) hide(node);
    });
  }

  function uniqById(list) {
    var seen = {}, out = [];
    (list || []).forEach(function (item) {
      var id = parseInt(item && item.id, 10) || 0;
      if (!id || seen[id]) return;
      seen[id] = 1; out.push(item);
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
  function mergeLists() {
    var out = [];
    for (var i = 0; i < arguments.length; i++) out = out.concat(arguments[i] || []);
    return uniqById(out);
  }
  function displayKey(text) {
    var blocked = ['black','white','red','blue','green','yellow','pink','gold','silver','grey','gray','nero','bianco','rosso','blu','verde','giallo','rosa','oro','argento','grigio','clear','case','cover','custodia','shell','glass','tempered','protector','mm','cm','gb','tb','xl','xxl','taglia','colore','con','per','the','for'];
    var tokens = norm(text).split(' ').filter(function (token) {
      return token && blocked.indexOf(token) === -1 && !/^\d+$/.test(token) && !/^\d+(mm|cm|gb|tb)$/.test(token);
    });
    return tokens.slice(0, 8).join(' ');
  }
  function fillDistinct(primary, fallback, count) {
    var out = [], seenId = {}, seenDisplay = {};
    function add(list) {
      (list || []).forEach(function (item) {
        if (out.length >= count) return;
        var id = parseInt(item && item.id, 10) || 0;
        var dsp = displayKey(item && item.title);
        if (!id || seenId[id]) return;
        if (dsp && seenDisplay[dsp]) return;
        seenId[id] = 1;
        if (dsp) seenDisplay[dsp] = 1;
        out.push(item);
      });
    }
    add(primary); add(fallback);
    return out.slice(0, count);
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
    var recent = readMergedRecent().slice(0, 32);
    if (recent.length) u.searchParams.set('recent', recent.join(','));
    return fetchJson(u.toString());
  }
  function normalizeSections(payload) {
    var sections = (payload && payload.sections) || {};
    var deals = (payload && payload.deals) || sections.deals || [];
    sections.deals = uniqById(deals);
    sections.offerte = uniqById(sections.offerte || []);
    sections.evidenza = uniqById(sections.evidenza || []);
    sections.nuovi = uniqById(sections.nuovi || []);
    sections.best = uniqById(sections.best || []);
    sections.top20 = uniqById(sections.top20 || []);
    sections.topselling = uniqById(sections.topselling || []);
    sections.recent = uniqById(sections.recent || []);
    sections.viewed = uniqById(sections.viewed || []);
    sections.combined = uniqById(mergeLists(sections.combined, sections.deals, sections.offerte, sections.evidenza, sections.nuovi, sections.best, sections.top20, sections.topselling, sections.recent, sections.viewed));
    if (!sections.viewed.length) sections.viewed = uniqById(mergeLists(sections.recent, sections.top20, sections.best, sections.combined));
    if (!sections.recent.length) sections.recent = uniqById(mergeLists(sections.viewed, sections.top20, sections.best, sections.combined));
    return sections;
  }

  function articleLinkFrom(node) {
    return (node && (node.matches('a[href*="articolo.aspx?id="]') ? node : q('a[href*="articolo.aspx?id="]', node))) || null;
  }
  function scrapeDomCards() {
    var seen = {}, items = [];
    qa('.card-product,.swiper-slide,.box-product,.ksh-grid-card,.ksh-side,.ksh-deal').forEach(function (node) {
      var a = articleLinkFrom(node);
      if (!a) return;
      var href = a.getAttribute('href') || '#';
      var m = href.match(/[?&]id=(\d+)/i);
      var id = m ? parseInt(m[1], 10) : 0;
      if (!id || seen[id]) return;
      var titleNode = q('.title,.name-product,h6 a,h5 a,.product-title a', node) || a;
      var title = (titleNode.textContent || '').replace(/\s+/g, ' ').trim();
      if (!title) return;
      var image = q('img', node);
      var src = image ? (image.getAttribute('src') || image.getAttribute('data-src') || '') : '';
      if (!src) return;
      var priceNode = q('.new-price,.price-text,.new,.ksh-price .new', node);
      var oldNode = q('.old-price,.old,.ksh-price .old', node);
      seen[id] = 1;
      items.push({
        id: id,
        url: href,
        title: title,
        image: src,
        preview: src,
        images: [src],
        price: priceNode ? (priceNode.textContent || '').replace(/[^0-9,\.]/g, '').trim() : '',
        oldPrice: oldNode ? (oldNode.textContent || '').replace(/[^0-9,\.]/g, '').trim() : '',
        brand: '',
        category: ''
      });
    });
    return items;
  }
  function hydrateFromDom(sections) {
    var dom = scrapeDomCards();
    if (!dom.length) return sections;
    sections.combined = uniqById(mergeLists(sections.combined, dom));
    ['offerte','evidenza','nuovi','best','top20','topselling','recent','viewed','deals'].forEach(function (key) {
      if (!sections[key] || !sections[key].length) sections[key] = uniqById(dom.slice());
      else sections[key] = uniqById(mergeLists(sections[key], dom));
    });
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
    return '<div class="ksh-big">' + badge(item) + '<div class="main"><a class="media" href="' + esc(item.url || '#') + '">' + (main ? '<img src="' + esc(main) + '" alt="' + esc(item.title || '') + '">' : '') + '</a><div class="body">' + meta(item) + '<a class="title title-big" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a><div class="bottom">' + price(item) + '</div></div></div><div class="thumbs">' + thumbs.map(function (src) { return '<span class="thumb-btn">' + (src ? '<img src="' + esc(src) + '" alt="">' : '') + '</span>'; }).join('') + '</div></div>';
  }
  function dealCard(item) {
    var end = String(item && item.dealEnds || '');
    return '<article class="ksh-deal">' + badge(item) + '<a class="media" href="' + esc(item.url || '#') + '">' + (img(item) ? '<img src="' + esc(img(item)) + '" alt="' + esc(item.title || '') + '">' : '') + '</a><div class="body">' + meta(item) + '<a class="title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' + price(item) + '<div class="save">' + (item && item.oldPrice ? ('Risparmi ' + esc(item.oldPrice) + ' €') : 'Promo') + '</div><div class="timer" data-end="' + esc(end) + '"><span><b>00</b><small>Giorni</small></span><span><b>00</b><small>Ore</small></span><span><b>00</b><small>Min</small></span><span><b>00</b><small>Sec</small></span></div><div class="avail"><span>Venduti: ' + esc(item && item.sold || 0) + '</span><span>Disponibili: ' + esc(item && item.available || 0) + '</span></div></div></article>';
  }

  function ensureCss() {
    if (document.getElementById('ks-home-v6-css')) return;
    var s = document.createElement('style');
    s.id = 'ks-home-v6-css';
    s.textContent = [
      'body.ks-page-home.ks-home-v6-mounted #HomeBottomPromoSection,body.ks-page-home.ks-home-v6-mounted #HomeRecentlyViewedSection,body.ks-page-home.ks-home-v6-mounted #HomeLowerColumnsSection,body.ks-page-home.ks-home-v6-mounted #HomeBrandsSection,body.ks-page-home.ks-home-v6-mounted .flat-animate-tab,body.ks-page-home.ks-home-v6-mounted section.tf-sp-2.pt-0{display:none!important;}',
      'body.ks-page-home .ks-home-v6{padding:18px 0 12px;position:relative;z-index:6;}',
      '.ks-home-v6-block{padding:22px 0 8px;}',
      '.ks-home-v6-title{display:flex;align-items:center;justify-content:space-between;margin:0 0 16px;gap:16px;}',
      '.ks-home-v6-title h5{margin:0;font-size:22px;line-height:1.2;font-weight:700;color:#111827;font-family:var(--ks-font-secondary);}',
      '.ks-home-v6-deals{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:24px;}',
      '.ks-home-v6-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(0,1fr) minmax(220px,280px);gap:24px;align-items:start;}',
      '.ks-home-v6-col{display:grid;gap:16px;align-content:start;}',
      '.ks-home-v6-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:20px;}',
      '.ks-home-v6-viewed .ks-home-v6-grid{grid-template-columns:repeat(4,minmax(0,1fr));}',
      '.ks-home-v6-lower{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:22px;align-items:start;}',
      '.ks-home-v6-lower-col h5{margin:0 0 14px;font-size:20px;line-height:1.2;font-weight:700;color:#111827;font-family:var(--ks-font-secondary);}',
      '.ks-home-v6-lower-list{display:grid;gap:16px;}',
      '.ks-home-v6-brands{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:18px;}',
      '.ks-home-v6-brand{display:flex;align-items:center;justify-content:center;min-height:120px;padding:16px;border:1px solid #edf1f5;border-radius:18px;background:#fff;}',
      '.ksh-deal,.ksh-side,.ksh-grid-card{position:relative;display:grid;background:#fff;border:1px solid #edf1f5;border-radius:18px;padding:14px;box-shadow:0 8px 26px rgba(15,23,42,.04);text-decoration:none;color:#111827;min-width:0;}',
      '.ksh-side{grid-template-columns:94px minmax(0,1fr);gap:14px;align-items:center;}.ksh-grid-card{grid-template-columns:1fr;gap:12px;align-items:start;padding:16px;}',
      '.ksh-deal .media,.ksh-grid-card .thumb,.ksh-side .thumb,.ksh-big .media{background:#f5f7fb;border-radius:14px;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
      '.ksh-deal .media{height:220px;margin-bottom:14px;}.ksh-grid-card .thumb{height:170px;}.ksh-side .thumb{height:94px;}',
      '.ksh-deal img,.ksh-grid-card img,.ksh-side img,.ksh-big img,.ks-home-v6-brand img{max-width:100%;max-height:100%;object-fit:contain;display:block;}',
      '.ksh-deal .body,.ksh-grid-card .body,.ksh-side .body,.ksh-big .body{display:grid;gap:8px;min-width:0;}',
      '.ksh-meta{font-size:11px;line-height:1.2;color:#6b7280;display:flex;gap:8px;flex-wrap:wrap;}.ksh-meta .dot{opacity:.5;}',
      '.ksh-side .title,.ksh-grid-card .title,.ksh-deal .title,.ksh-big .title{font-size:14px;line-height:1.35;font-weight:700;color:#0f172a;text-decoration:none;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}',
      '.ksh-big .title-big{font-size:18px;-webkit-line-clamp:3;}',
      '.ksh-price{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;font-weight:700;}.ksh-price .new{font-size:16px;color:#ef4444;}.ksh-price .old{font-size:13px;color:#6b7280;text-decoration:line-through;}',
      '.ksh-big{background:#fff;border:1px solid #edf1f5;border-radius:22px;padding:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);display:grid;grid-template-columns:minmax(0,1fr) 64px;gap:16px;align-items:start;}',
      '.ksh-big .main{display:grid;gap:16px;min-width:0;}.ksh-big .media{height:420px;border-radius:18px;}.ksh-big .thumbs{display:grid;gap:10px;align-content:start;}.ksh-big .thumb-btn{border:1px solid #d7dde6;background:#fff;border-radius:14px;height:64px;padding:6px;display:flex;align-items:center;justify-content:center;}',
      '.ksh-big .bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;}',
      '.ksh-badge{position:absolute;top:14px;left:14px;display:inline-flex;align-items:center;justify-content:center;min-width:48px;height:48px;padding:0 10px;border-radius:999px;background:#ff4444;color:#fff;font-size:13px;font-weight:700;z-index:3;}',
      '.ksh-deal .save{padding:4px 10px;border-radius:999px;background:#ffe000;color:#111827;font-size:12px;font-weight:700;display:inline-flex;justify-self:start;}.ksh-deal .timer{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;}.ksh-deal .timer span{padding:8px 4px;border-radius:999px;background:#f3f4f6;text-align:center;}.ksh-deal .timer b{display:block;font-size:18px;line-height:1.1;color:#111827;}.ksh-deal .timer small{display:block;font-size:11px;color:#6b7280;margin-top:4px;}.ksh-deal .avail{display:flex;align-items:center;justify-content:space-between;gap:12px;font-size:12px;color:#4b5563;}',
      '.ks-runtime-tabs-head{display:flex;gap:24px;flex-wrap:wrap;border-bottom:1px solid #edf1f5;margin-bottom:20px;}.ks-runtime-tab-btn{appearance:none;background:none;border:0;padding:0 0 12px;font-weight:700;color:#6b7280;cursor:pointer;}.ks-runtime-tab-btn.is-active{color:#ff3d3d;}.ks-runtime-panel{display:none;}.ks-runtime-panel.is-active{display:block;}',
      '@media (max-width:1199.98px){.ks-home-v6-deals,.ks-home-v6-grid,.ks-home-v6-brands{grid-template-columns:repeat(3,minmax(0,1fr));}.ks-home-v6-layout{grid-template-columns:1fr;}.ks-home-v6-col{grid-template-columns:repeat(2,minmax(0,1fr));}.ksh-big{grid-template-columns:1fr;}.ks-home-v6-lower{grid-template-columns:repeat(2,minmax(0,1fr));}}',
      '@media (max-width:767.98px){.ks-home-v6-deals,.ks-home-v6-col,.ks-home-v6-grid,.ks-home-v6-viewed .ks-home-v6-grid,.ks-home-v6-lower,.ks-home-v6-brands{grid-template-columns:1fr;}.ksh-big .media{height:260px;}.ksh-grid-card .thumb{height:140px;}}'
    ].join('');
    (document.head || document.documentElement).appendChild(s);
  }

  function findHeroSection() {
    return q('.ks-home-hero-section') || q('.ks-home-hero-shell') || q('.s-banner-wrapper') || q('main section');
  }
  function findIconBoxesSection() {
    var box = q('.tf-icon-box');
    return box ? (box.closest('section, .flat-spacing, .tf-sp-2, .tf-sp-5, .container') || box.parentNode) : null;
  }
  function sectionOf(node) {
    return node ? (node.closest('section, .flat-spacing, .tf-sp-2, .tf-sp-5, .container, .row') || node.parentNode) : null;
  }
  function originalBrandSection() {
    return q('#HomeBrandsSection') || sectionOf(q('.ks-home-brands')) || sectionOf(titleNode([t().brands, 'Rivenditori Ufficiali - I migliori Brand', 'Rivenditori Ufficiali']));
  }
  function titleNode(texts) {
    var wanted = (texts || []).map(norm);
    var nodes = qa('h1,h2,h3,h4,h5,h6,button,a,span');
    for (var i = 0; i < nodes.length; i++) {
      var txt = norm(nodes[i].textContent || '');
      if (wanted.indexOf(txt) !== -1) return nodes[i];
    }
    return null;
  }
  function cloneIconBoxes() {
    var sec = findIconBoxesSection();
    if (!sec) return '';
    var boxes = qa('.tf-icon-box', sec).slice(0, 5);
    if (boxes.length < 3) return '';
    return '<section class="ks-home-v6-block"><div class="container"><div class="ks-home-v6-icons">' + boxes.map(function (n) { return n.outerHTML; }).join('') + '</div></div></section>';
  }
  function scrapeBrands() {
    var sec = originalBrandSection();
    if (!sec) return [];
    var out = [];
    qa('a,img', sec).forEach(function (node) {
      var image = node.tagName === 'IMG' ? node : q('img', node);
      if (!image) return;
      var src = image.getAttribute('src') || image.getAttribute('data-src') || '';
      if (!src || out.some(function (it) { return it.image === src; })) return;
      out.push({ url: node.tagName === 'A' ? (node.getAttribute('href') || '#') : '#', image: src, title: image.getAttribute('alt') || image.getAttribute('title') || '' });
    });
    return out.slice(0, 12);
  }

  function buildDeals(sections) {
    var items = fillDistinct(shuffle(sections.deals || []), shuffle(mergeLists(sections.offerte, sections.combined)), 4);
    if (items.length < 4) return '';
    return '<section class="ks-home-v6-block"><div class="container"><div class="ks-home-v6-title"><h5>' + esc(t().deals) + '</h5></div><div class="ks-home-v6-deals">' + items.map(dealCard).join('') + '</div></div></section>';
  }
  function buildTabbed(sections) {
    var tabs = [
      { key: 'offerte', label: t().offers },
      { key: 'evidenza', label: t().featured },
      { key: 'nuovi', label: t().arrivals }
    ].map(function (cfg) {
      var items = fillDistinct(shuffle(sections[cfg.key] || []), shuffle(sections.combined || []), 7);
      return { cfg: cfg, items: items };
    }).filter(function (entry) { return entry.items.length >= 5; });
    if (!tabs.length) return '';
    return '<section class="ks-home-v6-block"><div class="container"><div class="ks-runtime-tabs-head">' + tabs.map(function (entry, idx) { return '<button type="button" class="ks-runtime-tab-btn' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + entry.cfg.key + '">' + esc(entry.cfg.label) + '</button>'; }).join('') + '</div>' + tabs.map(function (entry, idx) {
      var big = entry.items[0] || null;
      var left = entry.items.slice(1, 4);
      var right = entry.items.slice(4, 7);
      return '<div class="ks-runtime-panel' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + entry.cfg.key + '"><div class="ks-home-v6-layout"><div class="ks-home-v6-col">' + left.map(cardSmall).join('') + '</div><div>' + (big ? cardBig(big) : '') + '</div><div class="ks-home-v6-col">' + right.map(cardSmall).join('') + '</div></div></div>';
    }).join('') + '</div></section>';
  }
  function buildGrid(title, items, cls) {
    if (!items || items.length < 4) return '';
    return '<section class="ks-home-v6-block ' + esc(cls || '') + '"><div class="container"><div class="ks-home-v6-title"><h5>' + esc(title) + '</h5></div><div class="ks-home-v6-grid">' + items.map(cardGrid).join('') + '</div></div></section>';
  }
  function buildBest(sections) { return buildGrid(t().best, fillDistinct(shuffle(sections.best || []), shuffle(sections.combined), 10), 'ks-home-v6-best'); }
  function buildViewed(sections) { return buildGrid(t().viewed, fillDistinct(shuffle(mergeLists(sections.recent, sections.viewed, sections.top20, sections.best)), shuffle(sections.combined), 8), 'ks-home-v6-viewed'); }
  function buildLower(sections) {
    var groups = [
      { title: t().top20, items: fillDistinct(shuffle(sections.top20 || []), shuffle(sections.combined), 5) },
      { title: t().featured, items: fillDistinct(shuffle(sections.evidenza || []), shuffle(sections.combined), 5) },
      { title: t().topSelling, items: fillDistinct(shuffle(sections.topselling || []), shuffle(sections.combined), 5) },
      { title: t().onSale, items: fillDistinct(shuffle(sections.offerte || []), shuffle(sections.combined), 5) }
    ].filter(function (g) { return g.items.length >= 3; });
    if (!groups.length) return '';
    return '<section class="ks-home-v6-block"><div class="container"><div class="ks-home-v6-lower">' + groups.map(function (g) { return '<div class="ks-home-v6-lower-col"><h5>' + esc(g.title) + '</h5><div class="ks-home-v6-lower-list">' + g.items.map(cardSmall).join('') + '</div></div>'; }).join('') + '</div></div></section>';
  }
  function buildBrands() {
    var items = scrapeBrands();
    if (items.length < 4) return '';
    return '<section class="ks-home-v6-block"><div class="container"><div class="ks-home-v6-title"><h5>' + esc(t().brands) + '</h5></div><div class="ks-home-v6-brands">' + items.slice(0, 6).map(function (it) { return '<a class="ks-home-v6-brand" href="' + esc(it.url || '#') + '">' + (it.image ? '<img src="' + esc(it.image) + '" alt="' + esc(it.title || '') + '">' : '') + '</a>'; }).join('') + '</div></div></section>';
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
  function startTimers(root) {
    function tick() {
      qa('.timer', root).forEach(function (timer) {
        var end = timer.getAttribute('data-end') || '';
        var target = end ? new Date(end) : null;
        var ms = target && !isNaN(target.getTime()) ? Math.max(0, target.getTime() - Date.now()) : 0;
        var s = Math.floor(ms / 1000), d = Math.floor(s / 86400); s -= d * 86400;
        var h = Math.floor(s / 3600); s -= h * 3600; var m = Math.floor(s / 60); s -= m * 60;
        [d,h,m,s].forEach(function (n, idx) {
          var b = qa('b', timer)[idx];
          if (b) b.textContent = (n < 10 ? '0' : '') + n;
        });
      });
    }
    tick();
    window.clearInterval(root._timer || 0);
    root._timer = window.setInterval(tick, 1000);
  }

  function hideOriginalSections() {
    var nodes = [
      q('section.tf-sp-2.pt-0'),
      q('.flat-animate-tab'),
      q('#HomeBottomPromoSection'),
      q('#HomeRecentlyViewedSection'),
      q('#HomeLowerColumnsSection'),
      q('#HomeBrandsSection')
    ];
    nodes.forEach(hide);
  }
  function removeExistingRuntime() { qa('.ks-home-v6').forEach(function (n) { if (n.parentNode) n.parentNode.removeChild(n); }); }

  function mountRuntime(payload) {
    if (!isHome()) return;
    ensureCss();
    removeExistingRuntime();
    var sections = hydrateFromDom(normalizeSections(payload || {}));
    var anchor = findIconBoxesSection() || findHeroSection();
    if (!anchor || !anchor.parentNode) return;
    var html = buildDeals(sections) + buildTabbed(sections) + buildBest(sections) + buildViewed(sections) + buildLower(sections) + buildBrands();
    if (!html || html.replace(/\s+/g, '').length < 200) return;
    var root = document.createElement('div');
    root.className = 'ks-home-v6';
    root.innerHTML = html;
    anchor.parentNode.insertBefore(root, anchor.nextSibling);
    bindTabs(root);
    startTimers(root);
    document.body.classList.add('ks-home-v6-mounted');
    hideOriginalSections();
    hideMidPageHeaderClones();
    hideFranchisingRails();
    hideRepeatedMarginMedia();
  }

  function runHome() {
    if (!isHome()) return;
    feedAll().then(function (payload) {
      mountRuntime(payload || { sections: {} });
    }).catch(function () {
      mountRuntime({ sections: {} });
    });
  }

  function applyHomeCleanup() {
    if (!isHome()) return;
    hideMidPageHeaderClones();
    hideFranchisingRails();
    hideRepeatedMarginMedia();
  }

  onReady(function () {
    if (isArticle()) {
      var id = detectArticleId();
      if (id > 0) updateRecent(id);
    }
    if (isHome()) {
      runHome();
      [800, 1800, 3200, 5200].forEach(function (ms) { window.setTimeout(applyHomeCleanup, ms); });
      window.addEventListener('load', applyHomeCleanup, { once: true });
    }
  });
})();
