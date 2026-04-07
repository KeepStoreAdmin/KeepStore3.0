(function () {
  'use strict';

  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function normalizePath(path) {
    return String(path || '')
      .toLowerCase()
      .replace(/\/+/g, '/')
      .replace(/\/default\.aspx$/i, '/')
      .replace(/\/$/, '/');
  }

  function isHomePage() {
    var path = normalizePath(window.location.pathname || '/');
    return path === '/' || /\/default\.aspx$/i.test(window.location.pathname || '');
  }

  function isArticlePage() {
    return /\/articolo\.aspx$/i.test(window.location.pathname || '');
  }

  function addBodyClass(name) {
    if (!name || !document.body) return;
    document.body.classList.add(name);
  }

  function getQueryParam(name) {
    var params = new URLSearchParams(window.location.search || '');
    return params.get(name);
  }

  function readCookie(name) {
    var escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var match = document.cookie.match(new RegExp('(?:^|; )' + escaped + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }

  function writeCookie(name, value, days) {
    var expires = '';
    if (typeof days === 'number' && days > 0) {
      var d = new Date();
      d.setTime(d.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = '; expires=' + d.toUTCString();
    }
    document.cookie = name + '=' + encodeURIComponent(value) + expires + '; path=/; SameSite=Lax';
  }

  function parseRecentList(raw) {
    return String(raw || '')
      .split(',')
      .map(function (item) { return parseInt(item, 10); })
      .filter(function (item) { return Number.isFinite(item) && item > 0; });
  }

  function updateRecentCookie(id) {
    var existing = parseRecentList(readCookie('ks_recent'));
    var next = [id].concat(existing.filter(function (item) { return item !== id; })).slice(0, 100);
    writeCookie('ks_recent', next.join(','), 365);
  }

  function trackArticleRecent() {
    if (!isArticlePage()) return;
    var id = parseInt(getQueryParam('id'), 10);
    if (!Number.isFinite(id) || id <= 0) return;
    updateRecentCookie(id);
  }

  onReady(function () {
    if (isHomePage()) {
      addBodyClass('ks-page-home');
    }
    if (isArticlePage()) {
      addBodyClass('ks-page-article');
      trackArticleRecent();
    }
  });
})();
