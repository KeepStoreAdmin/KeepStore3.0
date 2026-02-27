(function(){
  function onReady(fn){
    if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function makeTitle(text){
    var h = document.createElement('div');
    h.className = 'ks-filter-title';
    h.textContent = text;
    return h;
  }

  function wrapFilterBox(el, title){
    if(!el || el.dataset.ksWrapped === '1') return;
    el.dataset.ksWrapped = '1';
    el.classList.add('ks-filter-box');

    // ripulisci inline style (non tocca controlli/ID)
    if(el.hasAttribute('style')) el.removeAttribute('style');

    // titolo neutro
    if(title){
      el.insertBefore(makeTitle(title), el.firstChild);
    }

    // normalizza checkbox (best effort)
    var cbs = el.querySelectorAll('input[type=checkbox], .filterCheckbox');
    for(var i=0;i<cbs.length;i++){
      var cb = cbs[i];
      if(cb.classList) cb.classList.add('ks-filter-checkbox');
    }

    // wrapper scroll se molto lungo
    // (non modifica i controlli: sposta solo nodi DOM già renderizzati)
    var kids = [];
    for(var k=0;k<el.childNodes.length;k++){
      var n = el.childNodes[k];
      if(n.nodeType === 1 && n.classList && n.classList.contains('ks-filter-title')) continue;
      kids.push(n);
    }

    if(kids.length > 8){
      var scroll = document.createElement('div');
      scroll.className = 'ks-filter-scroll';
      for(var j=0;j<kids.length;j++) scroll.appendChild(kids[j]);
      el.appendChild(scroll);
    }
  }

  function normalizePager(){
    // pattern comuni di pager ASP.NET / custom
    var candidates = document.querySelectorAll('.pagination-ys, .Pager, .pager, .pagination, .nav');
    for(var i=0;i<candidates.length;i++){
      candidates[i].classList.add('ks-pager');
    }
  }

  function normalizeToolbar(){
    var ord = document.querySelector('select[id*="Drop_Ordinamento"], select[name*="Drop_Ordinamento"], #Drop_Ordinamento');
    if(ord && ord.classList) ord.classList.add('form-select');
  }

  onReady(function(){
    // Esegui solo su catalogo
    var isCatalog = /articoli\.aspx/i.test(location.pathname);
    if(!isCatalog) return;

    wrapFilterBox(document.getElementById('filtersMr'), 'Marche');
    wrapFilterBox(document.getElementById('filtersTp'), 'Tipologie');
    wrapFilterBox(document.getElementById('filtersGr'), 'Gruppi');
    wrapFilterBox(document.getElementById('filtersSg'), 'Sottogruppi');

    normalizeToolbar();
    normalizePager();
  });
})();
