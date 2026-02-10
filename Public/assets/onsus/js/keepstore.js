(function () {
  function qs(id) { return document.getElementById(id); }
  function escHtml(s) {
    return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
      .replace(/"/g,"&quot;").replace(/'/g,"&#39;");
  }

  var input = qs("tbCerca");
  var box = qs("ksSuggest");
  if (!input || !box) return;

  var timer = null;
  var lastQ = "";

  function hide() {
    box.classList.remove("show");
    box.innerHTML = "";
  }

  function show(items) {
    if (!items || items.length === 0) { hide(); return; }
    var html = "";
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      var url = it.url || "";
      var text = escHtml(it.t || "");
      var meta = it.type ? ("<span class=\"ms-2 text-muted small\">" + escHtml(it.type) + "</span>") : "";
      html += "<a class=\"dropdown-item d-flex justify-content-between align-items-center\" href=\"" + url + "\">"
           + "<span>" + text + "</span>" + meta + "</a>";
    }
    box.innerHTML = html;
    box.classList.add("show");
  }

  function fetchSuggest(q) {
    if (!q || q.length < 2) { hide(); return; }
    if (q === lastQ) return;
    lastQ = q;

    var url = "/search-suggest.ashx?q=" + encodeURIComponent(q) + "&limit=10";
    try {
      fetch(url, { credentials: "same-origin" })
        .then(function (r) { return r.json(); })
        .then(function (data) { show(data); })
        .catch(function () { hide(); });
    } catch (e) {
      hide();
    }
  }

  input.addEventListener("keyup", function () {
    var q = input.value || "";
    if (timer) window.clearTimeout(timer);
    timer = window.setTimeout(function () { fetchSuggest(q.trim()); }, 180);
  });

  input.addEventListener("blur", function () {
    window.setTimeout(hide, 180);
  });

  input.addEventListener("focus", function () {
    var q = (input.value || "").trim();
    if (q.length >= 2) fetchSuggest(q);
  });

})();
