(function () {
  'use strict';

  var COOKIE_NAME = 'ks_recent';
  var SESSION_KEY = 'ks_recent_session';
  var MAX_RECENT = 100;

  function onReady(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function q(selector, root) { return (root || document).querySelector(selector); }
  function isHome() {
    var path = (window.location.pathname || '/').toLowerCase();
    return path === '/' || /\/default\.aspx$/i.test(path);
  }
  function isArticle() { return /\/articolo\.aspx$/i.test(window.location.pathname || ''); }
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
  function boot() {
    if (isArticle()) updateRecent(detectArticleId());
    if (isHome() && document.body) document.body.classList.add('ks-page-home');
  }
  onReady(boot);
})();
