(function () {
  function byId(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function qsEncode(s) {
    try { return encodeURIComponent(s); } catch (e) { return ''; }
  }

  function httpGetJson(url, cb) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          cb(null, JSON.parse(xhr.responseText));
        } catch (e) {
          cb(e, null);
        }
      } else {
        cb(new Error('HTTP ' + xhr.status), null);
      }
    };
    xhr.send(null);
  }

  function initSuggest(inputId, menuId) {
    var input = byId(inputId);
    var menu = byId(menuId);
    if (!input || !menu) return;

    var timer = null;
    var lastQ = '';

    function hide() {
      menu.className = menu.className.replace(/\bshow\b/g, '');
      menu.style.display = 'none';
      menu.innerHTML = '';
    }

    function show() {
      if (menu.className.indexOf('show') === -1) menu.className += ' show';
      menu.style.display = 'block';
    }

    function render(items) {
      if (!items || !items.length) { hide(); return; }

      var html = '';
      for (var i = 0; i < items.length; i++) {
        var it = items[i] || {};
        var text = escapeHtml(it.t || '');
        var url = escapeHtml(it.url || '#');
        var type = escapeHtml(it.type || '');

        html += '<a class="dropdown-item d-flex align-items-center justify-content-between" href="' + url + '">'
              +   '<span class="me-2">' + text + '</span>'
              +   '<small class="text-muted">' + type + '</small>'
              + '</a>';
      }

      menu.innerHTML = html;
      show();
    }

    function request() {
      var q = (input.value || '').replace(/^\s+|\s+$/g, '');
      if (q.length < 2) { hide(); return; }
      if (q === lastQ) return;
      lastQ = q;

      var url = '/search-suggest.ashx?q=' + qsEncode(q) + '&limit=10';
      httpGetJson(url, function (err, data) {
        if (err) { hide(); return; }
        render(data);
      });
    }

    input.addEventListener('input', function () {
      if (timer) window.clearTimeout(timer);
      timer = window.setTimeout(request, 180);
    });

    input.addEventListener('focus', function () {
      if ((input.value || '').replace(/^\s+|\s+$/g, '').length >= 2) {
        request();
      }
    });

    document.addEventListener('click', function (e) {
      var t = e.target;
      if (t === input || menu.contains(t)) return;
      hide();
    });

    input.addEventListener('keydown', function (e) {
      // ESC closes
      if (e.keyCode === 27) { hide(); }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      initSuggest('tbCerca', 'ksSuggest');
    });
  } else {
    initSuggest('tbCerca', 'ksSuggest');
  }
})();
