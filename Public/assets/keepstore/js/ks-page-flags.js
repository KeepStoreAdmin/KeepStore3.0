(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;
  var FEED_ENDPOINT = '/home_runtime_feed.aspx';
  var BLOCKED_TOKENS = ['welcome', 'franchis', 'onsus', 'themeforest', 'themesflat', 'mediacom', 'demo'];

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function qsa(sel, root) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
    catch (err) { return []; }
  }
  function qs(sel, root) {
    try { return (root || document).querySelector(sel); }
    catch (err) { return null; }
  }
  function text(node) { return String(node && node.textContent || '').replace(/\s+/g, ' ').trim(); }
  function norm(value) {
    var s = String(value || '').toLowerCase();
    try { s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (err) {}
    return s.replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function rect(node) {
    try {
      if (!node || typeof node.getBoundingClientRect !== 'function') return null;
      var r = node.getBoundingClientRect();
      if (!r || (!r.width && !r.height)) return null;
      return r;
    } catch (err) { return null; }
  }
  function isHomePage() {
    var pathname = window.location.pathname || '/';
    return pathname === '/' || /\/default\.aspx$/i.test(pathname);
  }
  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
  }
  function isVisible(node) {
    var r = rect(node);
    return !!(node && node.offsetParent !== null && r && r.width > 0 && r.height > 0);
  }
  function hideNode(node, flag) {
    if (!node || !node.style) return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    if (flag) node.setAttribute(flag, '1');
  }
  function parseArticleIdFromHref(href) {
    if (!href) return 0;
    var match = String(href).match(/[?&]id=(\d+)/i);
    return match ? parseInt(match[1], 10) : 0;
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
  function parseRecentList(raw) {
    return String(raw || '').split(',').map(function (item) { return parseInt(item, 10); }).filter(function (id) { return isFinite(id) && id > 0; });
  }
  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); }
    catch (err) { return []; }
  }
  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); }
    catch (err) {}
  }
  function mergedRecent() {
    var seen = {};
    var out = [];
    [readSessionRecent(), parseRecentList(readCookie(COOKIE_NAME))].forEach(function (list) {
      (list || []).forEach(function (id) {
        if (!id || seen[id]) return;
        seen[id] = 1;
        out.push(id);
      });
    });
    return out.slice(0, MAX_RECENT);
  }
  function persistRecent(list) {
    var next = (list || []).filter(function (id) { return isFinite(id) && id > 0; }).slice(0, MAX_RECENT);
    writeCookie(COOKIE_NAME, next.join(','), 365);
    writeSessionRecent(next);
  }
  function updateRecent(id) {
    var merged = mergedRecent();
    var next = [id].concat(merged.filter(function (v) { return v !== id; })).slice(0, MAX_RECENT);
    persistRecent(next);
  }
  function detectArticleId() {
    var direct = parseInt((new URLSearchParams(window.location.search || '')).get('id'), 10);
    if (isFinite(direct) && direct > 0) return direct;
    var canonical = qs('link[rel="canonical"]');
    return canonical ? parseArticleIdFromHref(canonical.getAttribute('href') || '') : 0;
  }
  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = detectArticleId();
    if (isFinite(id) && id > 0) updateRecent(id);
  }

  function suppressNewsletterPopup() {
    qsa('.auto-popup, .modal-newleter, [class*="modal-newleter"], .modal-backdrop, .offcanvas-backdrop').forEach(function (node) {
      hideNode(node, 'data-ks-hidden-popup');
      if ((node.classList && (node.classList.contains('modal-backdrop') || node.classList.contains('offcanvas-backdrop'))) && node.parentNode) {
        try { node.parentNode.removeChild(node); } catch (err) {}
      }
    });
    if (document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }
  }

  function compactHero() {
    var shell = qs('.ks-home-hero-shell') || qs('.s-banner-wrapper');
    var sideWrap = document.getElementById('HeroSideWrap') || qs('.wrap-item-3', shell || document);
    var menu = qs('.ks-home-departments .menu-category-list');
    var sliderWrap = document.getElementById('HeroSliderWrap') || (shell ? qs('.wrap-item-2', shell) : null);
    if (!shell || !sliderWrap) return;
    if (window.innerWidth < 1200) {
      shell.classList.remove('ks-home-force-compact');
      if (menu) {
        menu.style.maxHeight = '';
        menu.style.height = '';
      }
      return;
    }
    shell.classList.add('ks-home-force-compact');
    if (sideWrap) hideNode(sideWrap, 'data-ks-home-artifact');
    if (menu) {
      var rr = rect(sliderWrap);
      if (rr && rr.height > 220) {
        var h = Math.max(520, Math.floor(rr.height));
        menu.style.maxHeight = h + 'px';
        menu.style.height = h + 'px';
      }
    }
  }

  function insideProtected(node) {
    return !!(node && node.closest && node.closest('header, footer, .modal.show, .offcanvas.show, .ks-top-catalog-mega, .ks-home-departments, .ks-home-hero-shell, .card-product, .product-list-wrap, .tf-grid-product-item, .swiper, .ks-runtime-tabbed-section, .ks-runtime-lower-grid-section'));
  }

  function hideWelcomeArtifacts() {
    qsa('div,section,aside,span,p,a,img').forEach(function (node) {
      if (!node || insideProtected(node)) return;
      var raw = [node.id || '', node.className || '', text(node).slice(0, 300), node.getAttribute ? (node.getAttribute('src') || node.getAttribute('data-src') || node.getAttribute('alt') || '') : ''].join(' ');
      var normalized = norm(raw);
      var hit = BLOCKED_TOKENS.some(function (token) { return normalized.indexOf(token) !== -1; });
      if (hit) hideNode(node, 'data-ks-franchising-artifact');
    });
  }

  function hideBodyArtifacts() {
    var wrapper = document.getElementById('wrapper');
    var form = document.querySelector('body > form') || document.querySelector('form');
    if (!wrapper || !form) return;
    Array.prototype.slice.call(form.children || []).forEach(function (node) {
      if (!node || node.id === 'wrapper') return;
      if (/^(SCRIPT|STYLE|LINK)$/i.test(node.tagName)) return;
      if (node.tagName === 'INPUT' && String(node.type || '').toLowerCase() === 'hidden') return;
      hideNode(node, 'data-ks-body-artifact');
    });
  }

  function hideHeaderClones() {
    var header = document.querySelector('header') || document.querySelector('.tf-header');
    var headerBottom = header ? ((rect(header) || {}).bottom || 0) : 0;
    qsa('header, div, section').forEach(function (node) {
      if (!node || node === header) return;
      if (header && header.contains(node)) return;
      if (insideProtected(node)) return;
      var r = rect(node);
      if (!r || r.top < headerBottom + 120) return;
      if (r.width < window.innerWidth * 0.55 || r.height < 24 || r.height > 220) return;
      var raw = norm([node.className || '', text(node).slice(0, 220)].join(' '));
      if (/cerca prodotti|tutti i settori|il mio account|assistenza|spedizione gratuita|chiamaci gratis/.test(raw)) {
        hideNode(node, 'data-ks-header-clone');
      }
    });
  }

  function fetchJson(url) {
    return fetch(url, { credentials: 'same-origin' }).then(function (response) {
      return response.ok ? response.json() : Promise.reject(new Error('HTTP ' + response.status));
    });
  }
  function feed(mode, extra) {
    var url = new URL(FEED_ENDPOINT, window.location.href);
    url.searchParams.set('mode', mode);
    extra = extra || {};
    Object.keys(extra).forEach(function (key) {
      if (extra[key] != null && extra[key] !== '') url.searchParams.set(key, extra[key]);
    });
    return fetchJson(url.toString()).catch(function () { return { ok: false }; });
  }

  function itemImages(item) {
    var seen = {};
    var out = [];
    [item && item.preview, item && item.image].concat((item && item.images) || []).forEach(function (img) {
      img = String(img || '').trim();
      if (!img || seen[img]) return;
      seen[img] = 1;
      out.push(img);
    });
    return out.slice(0, 5);
  }
  function imageOf(item) {
    var imgs = itemImages(item);
    return imgs.length ? imgs[0] : '';
  }
  function esc(value) {
    return String(value == null ? '' : value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
  function priceHtml(item) {
    return '<span class="ks-runtime-price">' +
      (item && item.price ? ('<span class="new">€' + esc(item.price) + '</span>') : '') +
      (item && item.oldPrice ? ('<span class="old">€' + esc(item.oldPrice) + '</span>') : '') +
      '</span>';
  }
  function buildMeta(item) {
    return '<span class="ks-runtime-meta"><span>' + esc(item.brand || '') + '</span><span>' + esc(item.category || '') + '</span></span>';
  }
  function buildSideCard(item) {
    var img = imageOf(item);
    return '<a class="ks-runtime-side-card" href="' + esc(item.url || '#') + '">' +
      '<span class="ks-runtime-side-thumb"><img src="' + esc(img) + '" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '" /></span>' +
      '<span class="ks-runtime-side-body">' + buildMeta(item) + '<span class="ks-runtime-title">' + esc(item.title || '') + '</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }
  function buildLowerCard(item) {
    var img = imageOf(item);
    return '<a class="ks-runtime-lower-card" href="' + esc(item.url || '#') + '">' +
      '<span class="ks-runtime-lower-thumb"><img src="' + esc(img) + '" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '" /></span>' +
      '<span class="ks-runtime-lower-body">' + buildMeta(item) + '<span class="ks-runtime-title">' + esc(item.title || '') + '</span>' + priceHtml(item) + '</span>' +
      '</a>';
  }
  function buildBigCard(item) {
    var imgs = itemImages(item);
    var main = imgs[0] || '';
    return '<div class="ks-runtime-big-card">' +
      '<div class="ks-runtime-big-main">' +
        '<a class="ks-runtime-big-media" href="' + esc(item.url || '#') + '"><img src="' + esc(main) + '" data-main="1" data-fallback="' + esc(item.image || '') + '" alt="' + esc(item.title || '') + '" /></a>' +
        '<div class="ks-runtime-big-body">' + buildMeta(item) + '<a class="ks-runtime-title" href="' + esc(item.url || '#') + '">' + esc(item.title || '') + '</a>' + priceHtml(item) + '</div>' +
      '</div>' +
      '<div class="ks-runtime-big-thumbs">' + imgs.slice(0, 4).map(function (img, idx) {
        return '<button type="button" class="ks-runtime-big-thumb' + (idx === 0 ? ' is-active' : '') + '" data-img="' + esc(img) + '"><img src="' + esc(img) + '" alt="" /></button>';
      }).join('') + '</div>' +
      '</div>';
  }
  function bindFallbackImages(root) {
    qsa('img[data-fallback]', root).forEach(function (img) {
      img.addEventListener('error', function onErr() {
        img.removeEventListener('error', onErr);
        var fb = img.getAttribute('data-fallback') || '';
        if (fb && img.src !== fb) img.src = fb;
      });
    });
  }
  function bindBigThumbs(root) {
    qsa('.ks-runtime-big-card', root).forEach(function (card) {
      var main = qs('img[data-main="1"]', card);
      if (!main) return;
      qsa('.ks-runtime-big-thumb', card).forEach(function (btn) {
        btn.addEventListener('click', function () {
          qsa('.ks-runtime-big-thumb', card).forEach(function (b) { b.classList.remove('is-active'); });
          btn.classList.add('is-active');
          main.src = btn.getAttribute('data-img') || main.src;
        });
      });
    });
  }

  function countProductCards(root) {
    if (!root) return 0;
    return qsa('a[href*="articolo.aspx?id="], .card-product, .product-list-wrap > li', root).filter(function (node) {
      return isVisible(node);
    }).length;
  }
  function hideSection(node) {
    if (!node) return;
    node.setAttribute('data-ks-hidden-section', '1');
    hideNode(node, 'data-ks-hidden-section');
  }
  function findTabbedSection() {
    return qsa('section, .tf-sp-2, .container').find(function (sec) {
      if (sec.getAttribute && sec.getAttribute('data-ks-hidden-section') === '1') return false;
      var labels = qsa('a,button,h1,h2,h3,h4,h5,h6', sec).map(function (n) { return norm(text(n)); });
      return labels.some(function (t) { return t === 'offerte' || t === 'on sale'; }) && labels.some(function (t) { return t.indexOf('evidenza') !== -1 || t.indexOf('featured') !== -1; }) && labels.some(function (t) { return t.indexOf('nuovi arrivi') !== -1 || t.indexOf('new arrivals') !== -1; });
    }) || qs('.flat-animate-tab');
  }
  function findLowerSection() {
    return document.getElementById('HomeLowerColumnsSection') || qsa('section, .tf-sp-2, .container').find(function (sec) {
      if (sec.getAttribute && sec.getAttribute('data-ks-hidden-section') === '1') return false;
      if (!qsa('.tf-grid-product-item, .box-btn-slide-item', sec).length) return false;
      var labels = qsa('h1,h2,h3,h4,h5,h6,a,button', sec).map(function (n) { return norm(text(n)); });
      return labels.some(function (t) { return t.indexOf('top 20') !== -1 || t.indexOf('evidenza') !== -1 || t.indexOf('venduti') !== -1 || t.indexOf('offerta') !== -1; });
    }) || qs('.tf-grid-product');
  }
  function needsRuntimeTabbed(host) {
    if (!host) return false;
    return countProductCards(host) < 6;
  }
  function visibleLowerColumns(host) {
    return qsa('.tf-grid-product-item, .box-btn-slide-item', host).filter(function (col) {
      return isVisible(col) && countProductCards(col) >= 2;
    }).length;
  }
  function needsRuntimeLower(host) {
    if (!host) return false;
    return visibleLowerColumns(host) < 3;
  }
  function shuffled(list) {
    var out = (list || []).slice();
    for (var i = out.length - 1; i > 0; i -= 1) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }
  function uniqueById(list) {
    var seen = {};
    var out = [];
    (list || []).forEach(function (item) {
      var id = item && item.id;
      if (!id || seen[id]) return;
      seen[id] = 1;
      out.push(item);
    });
    return out;
  }
  var sectionsPromise = null;
  function loadSections() {
    if (!sectionsPromise) {
      sectionsPromise = feed('sections', { _: Date.now() }).then(function (data) {
        return data && data.sections ? data.sections : {};
      });
    }
    return sectionsPromise;
  }
  function renderRuntimeTabbedSection(sections) {
    if (!isHomePage()) return;
    if (qs('.ks-runtime-tabbed-section')) return;
    var host = findTabbedSection();
    if (!host || !host.parentNode || !needsRuntimeTabbed(host)) return;
    var mapping = [
      { key: 'offerte', label: 'Offerte' },
      { key: 'evidenza', label: 'In Evidenza' },
      { key: 'nuovi', label: 'Nuovi Arrivi' }
    ];
    var usable = mapping.filter(function (m) { return ((sections[m.key] || []).length >= 4); });
    if (!usable.length) return;

    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-tabbed-section';
    wrapper.innerHTML = '<div class="container">' +
      '<div class="ks-runtime-tabs-head">' + usable.map(function (m, idx) {
        return '<button type="button" class="ks-runtime-tab-btn' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '">' + esc(m.label) + '</button>';
      }).join('') + '</div>' +
      '<div class="ks-runtime-tabs-panels">' + usable.map(function (m, idx) {
        var items = shuffled(uniqueById((sections[m.key] || []).slice())).slice(0, 7);
        var big = items[0] || null;
        var left = items.slice(1, 4);
        var right = items.slice(4, 7);
        if (!big) return '';
        return '<div class="ks-runtime-panel' + (idx === 0 ? ' is-active' : '') + '" data-panel="' + esc(m.key) + '">' +
          '<div class="ks-runtime-tab-layout">' +
            '<div class="ks-runtime-side-col">' + left.map(buildSideCard).join('') + '</div>' +
            '<div class="ks-runtime-big-wrap">' + buildBigCard(big) + '</div>' +
            '<div class="ks-runtime-side-col">' + right.map(buildSideCard).join('') + '</div>' +
          '</div>' +
        '</div>';
      }).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    qsa('.ks-runtime-tab-btn', wrapper).forEach(function (btn) {
      btn.addEventListener('click', function () {
        var panel = btn.getAttribute('data-panel') || '';
        qsa('.ks-runtime-tab-btn', wrapper).forEach(function (b) { b.classList.toggle('is-active', b === btn); });
        qsa('.ks-runtime-panel', wrapper).forEach(function (p) { p.classList.toggle('is-active', p.getAttribute('data-panel') === panel); });
      });
    });
    bindFallbackImages(wrapper);
    bindBigThumbs(wrapper);
  }
  function renderRuntimeLowerSection(sections) {
    if (!isHomePage()) return;
    if (qs('.ks-runtime-lower-grid-section')) return;
    var host = findLowerSection();
    if (!host || !host.parentNode || !needsRuntimeLower(host)) return;

    var best = uniqueById((sections.best || []).slice());
    var featured = uniqueById((sections.evidenza || []).slice());
    var sale = uniqueById((sections.offerte || []).slice());
    var top20 = best.slice(0, 5);
    var topSelling = best.slice(5, 10).length >= 3 ? best.slice(5, 10) : best.slice(0, 5);
    var cols = [
      { title: 'Top 20', items: top20 },
      { title: 'In Evidenza', items: featured.slice(0, 5) },
      { title: "I Piu' Venduti", items: topSelling },
      { title: 'In Offerta', items: sale.slice(0, 5) }
    ].filter(function (col) { return (col.items || []).length >= 3; });

    if (cols.length < 3) return;

    var wrapper = document.createElement('section');
    wrapper.className = 'ks-runtime-lower-grid-section tf-sp-2';
    wrapper.innerHTML = '<div class="container"><div class="ks-runtime-lower-grid">' + cols.map(function (col) {
      return '<div class="ks-runtime-lower-col"><div class="flat-title"><h5 class="fw-semibold">' + esc(col.title) + '</h5></div><div class="ks-runtime-lower-list">' + col.items.map(buildLowerCard).join('') + '</div></div>';
    }).join('') + '</div></div>';
    host.parentNode.insertBefore(wrapper, host.nextSibling);
    hideSection(host);
    bindFallbackImages(wrapper);
  }
  function renderRuntimeCommercialSections() {
    if (!isHomePage()) return;
    loadSections().then(function (sections) {
      renderRuntimeTabbedSection(sections || {});
      renderRuntimeLowerSection(sections || {});
    }).catch(function () {});
  }

  function runHomeCleanup() {
    if (!isHomePage()) return;
    suppressNewsletterPopup();
    compactHero();
    hideBodyArtifacts();
    hideHeaderClones();
    hideWelcomeArtifacts();
    renderRuntimeCommercialSections();
  }

  onReady(function () {
    if (isArticlePage()) trackArticleRecent();
    if (isHomePage()) {
      if (document.body) document.body.classList.add('ks-page-home');
      runHomeCleanup();
      [500, 1600, 3800].forEach(function (delay) { window.setTimeout(runHomeCleanup, delay); });
      window.addEventListener('load', runHomeCleanup, { once: true });
      window.addEventListener('resize', runHomeCleanup);
      if (typeof MutationObserver !== 'undefined' && document.body) {
        var timer = 0;
        var observer = new MutationObserver(function () {
          clearTimeout(timer);
          timer = setTimeout(runHomeCleanup, 180);
        });
        observer.observe(document.body, { childList: true, subtree: true });
        setTimeout(function () { try { observer.disconnect(); } catch (err) {} }, 15000);
      }
    }
  });
})();
