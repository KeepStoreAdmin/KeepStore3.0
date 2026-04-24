(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function qa(selector, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(selector));
  }

  function q(selector, root) {
    return (root || document).querySelector(selector);
  }

  function isHome() {
    var path = (window.location.pathname || '/').toLowerCase();
    return path === '/' || /\/default\.aspx$/i.test(path);
  }

  function isArticle() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
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
    return String(raw || '').split(',').map(function (item) {
      return parseInt(item, 10);
    }).filter(function (id) {
      return Number.isFinite(id) && id > 0;
    });
  }

  function readSessionRecent() {
    try { return parseRecentList(window.sessionStorage.getItem(SESSION_KEY) || ''); } catch (err) { return []; }
  }

  function writeSessionRecent(list) {
    try { window.sessionStorage.setItem(SESSION_KEY, (list || []).join(',')); } catch (err) {}
  }

  function readMergedRecent() {
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

  function updateRecent(id) {
    if (!id || id <= 0) return;
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
    var match = href.match(/[?&]id=(\d+)/i);
    if (match) return parseInt(match[1], 10) || 0;

    var articleLink = q('a[href*="articolo.aspx?id="]');
    href = articleLink ? (articleLink.getAttribute('href') || '') : '';
    match = href.match(/[?&]id=(\d+)/i);
    return match ? (parseInt(match[1], 10) || 0) : 0;
  }

  function trackArticleRecent() {
    if (!isArticle()) return;
    updateRecent(detectArticleId());
  }

  function hide(node, reason) {
    if (!node) return;
    node.setAttribute('data-ks-artifact', reason || 'foreign-direct-child');
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
  }

  function isProtectedDirectChild(node) {
    if (!node || node.nodeType !== 1) return true;
    var tag = String(node.tagName || '').toLowerCase();
    if (/^(script|style|link|input|select|textarea)$/.test(tag)) return true;
    if (node.id === 'wrapper' || node.id === 'goTop' || node.id === 'preload') return true;
    if (node.classList && (node.classList.contains('modal') || node.classList.contains('offcanvas'))) return true;
    if (node.getAttribute && node.getAttribute('role') === 'dialog') return true;
    return false;
  }

  function quarantineForeignDirectChildren() {
    if (!isHome()) return;
    if (document.body) document.body.classList.add('ks-page-home');

    var form = document.getElementById('form1') || q('body > form');
    if (form) {
      qa(':scope > *', form).forEach(function (node) {
        if (isProtectedDirectChild(node)) return;
        hide(node, 'foreign-direct-child');
      });
    }

    var wrapper = document.getElementById('wrapper');
    if (wrapper) {
      qa(':scope > *', wrapper).forEach(function (node) {
        var tag = String(node.tagName || '').toLowerCase();
        if (/^(header|main|footer)$/.test(tag)) return;
        hide(node, 'wrapper-extra-child');
      });
    }
  }

  function boot() {
    trackArticleRecent();
    if (!isHome()) return;
    quarantineForeignDirectChildren();
    [80, 250, 900, 2500, 6000].forEach(function (delay) {
      window.setTimeout(quarantineForeignDirectChildren, delay);
    });
  }

  onReady(boot);
})();
