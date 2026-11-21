[CmdletBinding()]
param(
    [string]$HostName = 'www.taikun.it',
    [string]$Out = '',
    [int[]]$Widths = @(390, 1280),
    [int]$HomeReads = 3,
    [switch]$WithUser,
    [switch]$Shots,
    [string]$Compare = '',
    [string]$Summary = '',
    [switch]$Library
)

# STYLE-BASELINE-1A. Fotografia riproducibile dello stile del negozio: stili CALCOLATI nel browser, per ruolo, produttore e stato.
# Serve da riferimento prima dei task che unificano lo stile (docs/KEEPSTORE_STYLE_DIRECTION_2026_11_19.md, sezione 4).
# SOLA LETTURA: apre pagine del solo sito LAB (https, porta 18843, domini forzati a 127.0.0.1), non fa clic che inviano moduli
# (l'unico invio e l'accesso dell'utente di prova con -WithUser), non scrive su database ne sui file del sito.
# Privacy: nel browser con l'utente collegato non raccoglie testi e non fa schermate. Nelle pagine anonime tiene il testo dei soli
# prezzi e bollini. Uscita: cartella locale non versionata (.ai-review/style-baseline/<data>) con baseline.json e schermate.
# -Compare <baseline.json precedente>: per ogni chiave (pagina, larghezza, ruolo, produttore, stato, visibile) presente in entrambe
#   le fotografie l'insieme delle firme deve coincidere (ERRORE se diverso); una chiave presente in una sola e un AVVISO.
# -Summary <file.md>: riepilogo corto da versionare. -Library: carica solo le funzioni (usato da Tools/Test-StyleBaselineTool.ps1).
# Limiti: stati interattivi (hover, fuoco, errore, pannelli aperti) non fotografati; lo stato del prezzo e letto dal markup.
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$KsbVersion = '1'
$KsbPort = 18843
$KsbHosts = @('www.taikun.it', 'www.webaffare.it')
$KsbStates = @('normale', 'normale+quantita', 'sconto-immediato', 'barrato', 'prezzo-quantita', 'promo-immediata-riquadro', 'su-richiesta', 'importo')

function Test-KsbAllowedBase([string]$base) {
    $u = $null
    if (-not [Uri]::TryCreate($base, [UriKind]::Absolute, [ref]$u)) { return $false }
    return ($u.Scheme -eq 'https' -and $u.Port -eq $KsbPort -and ($KsbHosts -contains $u.Host.ToLowerInvariant()) -and $u.AbsolutePath -eq '/')
}

$KsbPrepJs = @'
(function(){
if(!document.getElementById('ksb-still')){var st=document.createElement('style');st.id='ksb-still';st.textContent='*,*::before,*::after{animation:none!important;transition:none!important;scroll-behavior:auto!important}';document.head.appendChild(st);}
document.querySelectorAll('.swiper').forEach(function(el){try{if(el.swiper){if(el.swiper.autoplay&&el.swiper.autoplay.stop){el.swiper.autoplay.stop();}if(el.swiper.slideToLoop){el.swiper.slideToLoop(0,0);}else{el.swiper.slideTo(0,0);}}}catch(x){}});
return Math.max(document.body.scrollHeight,document.documentElement.scrollHeight);})()
'@

$KsbCollectJs = @'
(function(opt){
var cv=document.createElement('canvas');cv.width=cv.height=1;var cx=cv.getContext('2d',{willReadFrequently:true});var cache={};
function ch(c){if(cache[c])return cache[c];cx.clearRect(0,0,1,1);cx.fillStyle='rgba(0,0,0,0)';cx.fillStyle=c;cx.fillRect(0,0,1,1);var d=cx.getImageData(0,0,1,1).data;return cache[c]=[d[0],d[1],d[2],d[3]];}
function h2(v){return ('0'+Math.round(v).toString(16)).slice(-2);}
function hex3(a){return ('#'+h2(a[0])+h2(a[1])+h2(a[2])).toUpperCase();}
function hx(c){var a=ch(c);if(a[3]===0)return '-';var s=hex3(a);return a[3]<250?s+'@'+Math.round(a[3]/2.55):s;}
function comp(e){var layers=[];var p=e;while(p&&p.nodeType===1){var a=ch(getComputedStyle(p).backgroundColor);if(a[3]>0){layers.push(a);if(a[3]>=250)break;}p=p.parentElement;}var o=[255,255,255];for(var i=layers.length-1;i>=0;i--){var l=layers[i],k=l[3]/255;o=[l[0]*k+o[0]*(1-k),l[1]*k+o[1]*(1-k),l[2]*k+o[2]*(1-k)];}return hex3(o);}
function vis(e){if(!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden')return false;var b=e.getBoundingClientRect();if(!(b.width>1&&b.height>1))return false;var op=1,p=e;while(p&&p.nodeType===1){op*=parseFloat(getComputedStyle(p).opacity);p=p.parentElement;}return op>0.05;}
function cls(e){var c=(typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||'').trim().split(/\s+/).filter(Boolean).filter(function(x){return !/^(wow|fadeIn|animated|lazy|swiper-slide-)/.test(x);}).slice(0,4).join('.');return e.tagName.toLowerCase()+(c?'.'+c:'');}
function desc(e){var p=e.parentElement;return cls(e)+(p&&p!==document.body?' < '+cls(p):'');}
function fam(s){return s.fontFamily.split(',')[0].replace(/["']/g,'').trim();}
function px(v){return String(Math.round(parseFloat(v)*10)/10);}
function four(a){if(a[0]===a[1]&&a[1]===a[2]&&a[2]===a[3])return a[0];return a.join('/');}
function struck(e){var p=e;while(p&&p.nodeType===1){if((getComputedStyle(p).textDecorationLine||'').indexOf('line-through')>=0)return true;p=p.parentElement;}return false;}
function tsig(e){var s=getComputedStyle(e);var d=struck(e)?'line-through':(s.textDecorationLine&&s.textDecorationLine!=='none'?s.textDecorationLine:'');return [fam(s),px(s.fontSize)+'px',s.fontWeight,'interlinea '+(s.lineHeight==='normal'?'normale':px(s.lineHeight)),hx(s.color),'su '+comp(e),d,(s.textTransform!=='none'?s.textTransform:'')].filter(Boolean).join(' | ');}
function bsig(e){var s=getComputedStyle(e);var r=four([px(s.borderTopLeftRadius),px(s.borderTopRightRadius),px(s.borderBottomRightRadius),px(s.borderBottomLeftRadius)]);
function side(n){var w=parseFloat(s['border'+n+'Width'])||0;return (w>0&&s['border'+n+'Style']!=='none')?px(w)+' '+hx(s['border'+n+'Color']):'0';}
var b=four([side('Top'),side('Right'),side('Bottom'),side('Left')]);return ['fondo '+hx(s.backgroundColor),'raggio '+r,(b==='0'?'senza bordo':'bordo '+b),(s.boxShadow&&s.boxShadow!=='none'?'ombra '+s.boxShadow.replace(/\s+/g,' '):'')].filter(Boolean).join(' | ');}
function csig(e){var s=getComputedStyle(e);return [fam(s),px(s.fontSize)+'px',s.fontWeight,'testo '+hx(s.color),bsig(e),'alto '+Math.round(e.getBoundingClientRect().height)].join(' | ');}
var CUR='.new-price, .ks-price-now, .ks-home-price-value--current';
var OLD='.old-price, .ks-price-old, .ks-home-price-value--old, del, s';
var TIER='.ks-home-promo-tier, .ks-catalog-promos__tier-block, .ks-catalog-promos__price, .ks-product-promos__item--tier';
var money=/^(?:\u20AC\s*)?-?(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}(?:\s*\u20AC)?$/;
function txt(e){return (e.textContent||'').replace(/\s+/g,' ').trim();}
function isMoney(e){return money.test(txt(e));}
function producer(e){
if(e.closest('.ks-pdp-buybar'))return 'barra-acquisto';
if(e.closest('[id*="QuickView"], [id*="quickView"]'))return 'anteprima-rapida';
if(e.closest('[class*="ks-suggest"]'))return 'suggerimenti';
if(e.closest('.ks-rv-card'))return 'consigli-carrello';
if(e.closest('[class*="minicart"], [class*="mini-cart"], [id*="MiniCart"]'))return 'mini-carrello';
var card=e.closest('.card-product');
if(card){if(card.classList.contains('ks-deal-card'))return 'scheda-occasioni';if(card.classList.contains('ks-grid-card'))return 'scheda-griglia-home';if(card.classList.contains('ks-recent-card'))return 'visti-di-recente';
var sec=card.closest('#prd-usually, #prd-similar, #prd-related, #prd-recent');if(sec)return 'scheda-prodotto:'+sec.id;
return card.querySelector('.ks-price')?'scheda-elenco-in-linea':'scheda-elenco';}
var s2=e.closest('#prd-usually, #prd-similar, #prd-related, #prd-recent');if(s2)return 'scheda-prodotto:'+s2.id;
if(e.closest('.ks-price'))return 'elenco-in-linea';
if(/articolo\.aspx/i.test(location.pathname)&&e.closest('.price-text, .ks-product-promos'))return 'scheda-prodotto-principale';
return 'pagina';}
function state(e,ask){
if(ask)return 'su-richiesta';
if(e.closest(TIER))return 'prezzo-quantita';
if(e.closest('.ks-product-promos__item--immediate'))return 'promo-immediata-riquadro';
if(e.closest(OLD)||struck(e))return 'barrato';
var cur=e.closest(CUR);if(!cur)return 'importo';
var up=cur.parentElement||cur;var wrap=up.closest('.price-wrap, .ks-price, .price-text, .ks-home-price-slot')||up;
var hasOld=false;wrap.querySelectorAll(OLD).forEach(function(o){if(money.test(txt(o)))hasOld=true;});
if(hasOld)return 'sconto-immediato';
var scope=cur.closest('.card-product')||(producer(e)==='scheda-prodotto-principale'?document.body:wrap.parentElement);
return (scope&&scope.querySelector(TIER))?'normale+quantita':'normale';}
var roles=[
['titolo-pagina','h1',tsig],['titolo-sezione','h2, .heading-section .title',tsig],['sottotitolo','h3, h4, h5, h6',tsig],
['scheda','.card-product',bsig],['scheda-titolo','.card-product .name-product, .ks-card-title',tsig],['scheda-categoria','.ks-card-category, .card-product .product-tag',tsig],
['bollino','.box-sale-tag, .ks-card-tag, .box-sale-wrap > *',csig],
['pulsante','a.tf-btn, button.tf-btn, input.tf-btn, .btn, button[class*="btn"], input[type=submit], .ks-card-buy-cta',csig],
['campo','input[type=text], input[type=search], input[type=email], input[type=password], input[type=number], input[type=tel], select, textarea',csig]];
var groups={},order=[],mark=0,taken=new Set();
function add(role,e,sig,st,text){var v=vis(e);var pr=producer(e);var key=[role,pr,st,v?'si':'no',sig].join('\u0001');var g=groups[key];
if(!g){g=groups[key]={role:role,prod:pr,state:st,vis:(v?'si':'no'),sig:sig,n:0,where:{},text:'',mark:-1};order.push(key);}
g.n++;var d=desc(e);g.where[d]=(g.where[d]||0)+1;if(v&&g.mark<0){g.mark=mark;e.setAttribute('data-ksb',String(mark));mark++;if(opt.texts&&(role==='prezzo'||role==='bollino'))g.text=(text||'').substring(0,24);}}
roles.forEach(function(r){var list;try{list=document.querySelectorAll(r[1]);}catch(x){list=[];}list.forEach(function(e){if(taken.has(e))return;taken.add(e);add(r[0],e,r[2](e),'',txt(e));});});
document.querySelectorAll('body *').forEach(function(e){if(e.tagName==='SCRIPT'||e.tagName==='STYLE'||e.tagName==='OPTION')return;var t=txt(e);if(!t||t.length>40)return;
var ask=(t==='Prezzo su richiesta');if(!ask&&!money.test(t))return;
var inner=false;for(var i=0;i<e.children.length;i++){var ct=txt(e.children[i]);if(ct===t||(!ask&&money.test(ct))){inner=true;break;}}if(inner)return;
add('prezzo',e,tsig(e),state(e,ask),t);});
var bs=getComputedStyle(document.body);add('testo-pagina',document.body,[fam(bs),px(bs.fontSize)+'px',bs.fontWeight,hx(bs.color),'fondo '+comp(document.body)].join(' | '),'','');
var radii={},fonts={};
document.querySelectorAll('body *').forEach(function(e){if(!vis(e))return;var s=getComputedStyle(e);var r=px(s.borderTopLeftRadius);
if(r!=='0'&&(ch(s.backgroundColor)[3]>0||(parseFloat(s.borderTopWidth)||0)>0)){var k=(parseFloat(r)>=100||s.borderTopLeftRadius.indexOf('%')>=0)?'tondo o pillola':r+'px';radii[k]=(radii[k]||0)+1;}
var own='';e.childNodes.forEach(function(n){if(n.nodeType===3)own+=n.nodeValue;});if(own.replace(/\s+/g,'')){var f=fam(s);fonts[f]=(fonts[f]||0)+1;}});
function top(m,k){return Object.keys(m).sort(function(a,b){return m[b]-m[a]||(a<b?-1:1);}).slice(0,k).map(function(x){return x+(m[x]>1?' x'+m[x]:'');});}
var items=order.map(function(k){var g=groups[k];return {role:g.role,prod:g.prod,state:g.state,vis:g.vis,sig:g.sig,n:g.n,where:top(g.where,3),text:g.text,mark:g.mark};});
return JSON.stringify({origin:location.origin,path:location.pathname,height:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight),items:items,
radii:Object.keys(radii).sort().map(function(k){return {r:k,n:radii[k]};}),fonts:Object.keys(fonts).sort().map(function(k){return {f:k,n:fonts[k]};})});
})(__KSB_OPT__)
'@

$KsbPickJs = @'
(function(){var o={sconto:'',quantita:'',normale:''};var money=/\d,\d{2}/;
document.querySelectorAll('.card-product').forEach(function(c){if(c.classList.contains('ks-recent-card'))return;var a=c.querySelector('a.name-product, a.ks-card-title');if(!a)return;var h=a.getAttribute('href')||'';if(!h||h.charAt(0)==='#')return;
var old=false;c.querySelectorAll('.old-price, .ks-price-old, del').forEach(function(x){if(money.test(x.textContent))old=true;});
var tier=!!c.querySelector('.ks-catalog-promos__tier-block, .ks-home-promo-tier');
var k=old?'sconto':(tier?'quantita':'normale');if(!o[k])o[k]=h;});return JSON.stringify(o);})()
'@

function Get-KsbCollectJs([bool]$texts) {
    $opt = '{texts:' + $texts.ToString().ToLowerInvariant() + '}'
    return $KsbCollectJs.Replace('__KSB_OPT__', $opt)
}

# Ferma i caroselli, scorre tutta la pagina (immagini ritardate, elementi rivelati dallo scorrimento) e torna in cima.
function Initialize-KsbPage($browser) {
    $h = [int](Invoke-KsJs $browser $KsbPrepJs)
    for ($round = 0; $round -lt 3; $round++) {
        for ($y = 0; $y -lt $h; $y += 600) { $null = Invoke-KsJs $browser ('window.scrollTo(0,' + $y + ');1'); Start-Sleep -Milliseconds 100 }
        $h2 = [int](Invoke-KsJs $browser $KsbPrepJs)
        if ($h2 -le $h) { break }
        $h = $h2
    }
    $null = Invoke-KsJs $browser 'window.scrollTo(0,0);1'
    Start-Sleep -Milliseconds 900
}

# Legge la pagina aperta. Restituisce l'oggetto della fotografia (items, radii, fonts) con nome e larghezza.
function Read-KsbPage($browser, [string]$name, [int]$width, [bool]$texts, [string]$shotDir = '') {
    Initialize-KsbPage $browser
    $o = ConvertFrom-Json ([string](Invoke-KsJs $browser (Get-KsbCollectJs $texts)))
    $o | Add-Member -NotePropertyName name -NotePropertyValue $name
    $o | Add-Member -NotePropertyName width -NotePropertyValue $width
    $o | Add-Member -NotePropertyName shotErrors -NotePropertyValue 0
    foreach ($it in @($o.items)) { $it | Add-Member -NotePropertyName shot -NotePropertyValue '' }
    if ($shotDir -ne '') {
        $k = 0
        foreach ($it in @($o.items)) {
            if ([int]$it.mark -lt 0) { continue }
            $k++
            try {
                $rect = ConvertFrom-Json ([string](Invoke-KsJs $browser ("(function(){var e=document.querySelector('[data-ksb=`"" + $it.mark + "`"]');if(!e)return '{`"w`":0}';var r=e.getBoundingClientRect();return JSON.stringify({x:r.left+window.scrollX,y:r.top+window.scrollY,w:r.width,h:r.height});})()")))
                if ([double]$rect.w -le 0) { throw 'elemento non trovato' }
                $file = ($name + '-' + $width + '-' + ('{0:000}' -f $k) + '-' + $it.role + '.png')
                $clip = @{ x = [Math]::Max(0, [double]$rect.x - 8); y = [Math]::Max(0, [double]$rect.y - 8); width = [Math]::Min(1300, [double]$rect.w + 16); height = [Math]::Min(900, [double]$rect.h + 16); scale = 1 }
                $r = Invoke-KsCdp $browser 'Page.captureScreenshot' @{ format = 'png'; clip = $clip; captureBeyondViewport = $true } 60
                [IO.File]::WriteAllBytes((Join-Path $shotDir $file), [Convert]::FromBase64String($r['data']))
                $it.shot = $file
            } catch { $it.shot = 'ERRORE'; $o.shotErrors = [int]$o.shotErrors + 1 }
        }
    }
    return $o
}

function Get-KsbKey($page, $it) { return ([string]$page.name + '|' + [string]$page.width + '|' + [string]$it.role + '|' + [string]$it.prod + '|' + [string]$it.state + '|' + [string]$it.vis) }

# Unisce piu letture della stessa pagina (la HOME ruota gli articoli): firma non presente in tutte = dipende dalla rotazione.
function Merge-KsbReads($reads) {
    $first = @($reads)[0]
    $map = @{}; $order = New-Object Collections.Generic.List[string]
    foreach ($r in @($reads)) {
        foreach ($it in @($r.items)) {
            $k = (Get-KsbKey $r $it) + '|' + [string]$it.sig
            if (-not $map.ContainsKey($k)) { $it | Add-Member -NotePropertyName reads -NotePropertyValue 0 -Force; $map[$k] = $it; $order.Add($k) }
            $map[$k].reads = [int]$map[$k].reads + 1
            if ([int]$it.n -gt [int]$map[$k].n) { $map[$k].n = $it.n }
        }
    }
    $total = @($reads).Count
    $items = foreach ($k in $order) { $x = $map[$k]; $x | Add-Member -NotePropertyName rotation -NotePropertyValue ([int]$x.reads -lt $total) -Force; $x }
    $first.items = @($items)
    $first | Add-Member -NotePropertyName readCount -NotePropertyValue $total -Force
    return $first
}

function ConvertTo-KsbIndex($pages) {
    $ix = @{}
    foreach ($p in @($pages)) { foreach ($it in @($p.items)) { $k = Get-KsbKey $p $it; if (-not $ix.ContainsKey($k)) { $ix[$k] = New-Object Collections.Generic.HashSet[string] }; $null = $ix[$k].Add([string]$it.sig) } }
    return $ix
}

# Confronto fra due fotografie: errori = stessa chiave, firme diverse; avvisi = chiave presente in una sola.
function Compare-KsbBaseline($oldPages, $newPages) {
    $a = ConvertTo-KsbIndex $oldPages; $b = ConvertTo-KsbIndex $newPages
    $errors = New-Object Collections.Generic.List[string]; $warnings = New-Object Collections.Generic.List[string]
    foreach ($k in ($a.Keys | Sort-Object)) {
        if (-not $b.ContainsKey($k)) { $warnings.Add('scomparsa: ' + $k); continue }
        if (-not $a[$k].SetEquals($b[$k])) {
            $gone = @($a[$k] | Where-Object { -not $b[$k].Contains($_) } | Sort-Object); $come = @($b[$k] | Where-Object { -not $a[$k].Contains($_) } | Sort-Object)
            $errors.Add($k + ' :: prima [' + ($gone -join ' ; ') + '] dopo [' + ($come -join ' ; ') + ']')
        }
    }
    foreach ($k in ($b.Keys | Sort-Object)) { if (-not $a.ContainsKey($k)) { $warnings.Add('comparsa: ' + $k) } }
    return [pscustomobject]@{ Errors = $errors.ToArray(); Warnings = $warnings.ToArray() }
}

# Copertura dei prezzi: per ogni produttore incontrato, quali stati sono stati visti (visibili) e quali no.
function Get-KsbCoverage($pages) {
    $seen = @{}
    foreach ($p in @($pages)) { foreach ($it in @($p.items)) { if ([string]$it.role -ne 'prezzo' -or [string]$it.vis -ne 'si') { continue }; if (-not $seen.ContainsKey([string]$it.prod)) { $seen[[string]$it.prod] = @{} }; $seen[[string]$it.prod][[string]$it.state] = $true } }
    return $seen
}

function Write-KsbSummary($doc, [string]$path) {
    $sb = New-Object Text.StringBuilder
    $pages = @($doc.pages)
    $null = $sb.AppendLine('# KeepStore - fotografia dello stile (' + $doc.date + ')')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('Generato da `Tools/Get-KeepStoreStyleBaseline.ps1` (raccoglitore v' + $doc.version + '), task `STYLE-BASELINE-1A`. **Non modificare a mano**: si rigenera con `-Summary`. Riferimento per i task della [linea di stile](KEEPSTORE_STYLE_DIRECTION_2026_11_19.md): ogni task rifa la fotografia e la confronta con `-Compare`.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('**Provenienza.** Repository `' + $doc.sha + '`; origine ' + $doc.origin + ' (sito LAB, database LAB); larghezze ' + (@($doc.widths) -join ' e ') + ' px; HOME letta ' + $doc.homeReads + ' volte (ruota gli articoli); utente collegato: ' + $(if ($doc.withUser) { 'si (carrello e area cliente, senza testi ne schermate)' } else { 'no' }) + '. Stili calcolati dal browser (Edge), animazioni ferme, pagina scorsa per intero.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('**Non fotografato (limiti).** Stati interattivi (passaggio del mouse, fuoco, errore, disattivato), pannelli e menu aperti, seconda azienda, documenti, ricerca, pagine di servizio, conferma dell''ordine; il LAB non ha le immagini dei prodotti. Lo stato del prezzo e letto dal markup, non dal modello commerciale. Una variante rara della HOME puo non uscire nelle letture fatte.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## 1. Pagine')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Pagina | Larghezza | Altezza | Varianti | Caratteri | Raggi |')
    $null = $sb.AppendLine('| --- | --- | --- | --- | --- | --- |')
    foreach ($p in $pages) {
        $null = $sb.AppendLine('| ' + $p.name + ' | ' + $p.width + ' | ' + $p.height + ' | ' + @($p.items).Count + ' | ' + ((@($p.fonts) | ForEach-Object { $_.f + ' ' + $_.n }) -join ', ') + ' | ' + ((@($p.radii) | ForEach-Object { $_.r + ' ' + $_.n }) -join ', ') + ' |')
    }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## 2. Prezzi: stati incontrati per produttore')
    $null = $sb.AppendLine('')
    $cov = Get-KsbCoverage $pages
    $null = $sb.AppendLine('| Produttore | ' + ($KsbStates -join ' | ') + ' |')
    $null = $sb.AppendLine('| --- | ' + (($KsbStates | ForEach-Object { '---' }) -join ' | ') + ' |')
    foreach ($prod in ($cov.Keys | Sort-Object)) { $null = $sb.AppendLine('| ' + $prod + ' | ' + (($KsbStates | ForEach-Object { if ($cov[$prod].ContainsKey($_)) { 'visto' } else { 'non incontrato' } }) -join ' | ') + ' |') }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## 3. Prezzi visibili: firma per produttore e stato')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Produttore | Stato | Firma (carattere, corpo, peso, interlinea, colore, fondo) | Dove |')
    $null = $sb.AppendLine('| --- | --- | --- | --- |')
    $rows = @{}
    foreach ($p in $pages) { foreach ($it in @($p.items)) { if ([string]$it.role -ne 'prezzo' -or [string]$it.vis -ne 'si') { continue }; $k = [string]$it.prod + ' | ' + [string]$it.state + ' | ' + ([string]$it.sig).Replace('|', '/'); if (-not $rows.ContainsKey($k)) { $rows[$k] = New-Object Collections.Generic.List[string] }; $rows[$k].Add([string]$p.name + ' ' + $p.width) } }
    foreach ($k in ($rows.Keys | Sort-Object)) { $null = $sb.AppendLine('| ' + $k + ' | ' + ((@($rows[$k]) | Select-Object -Unique) -join ', ') + ' |') }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## 4. Varianti visibili distinte per ruolo (tutto il sito)')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Ruolo | ' + ((@($doc.widths) | ForEach-Object { [string]$_ + ' px' }) -join ' | ') + ' |')
    $null = $sb.AppendLine('| --- | ' + ((@($doc.widths) | ForEach-Object { '---' }) -join ' | ') + ' |')
    $roleNames = @($pages | ForEach-Object { @($_.items) | ForEach-Object { [string]$_.role } } | Sort-Object -Unique)
    foreach ($role in $roleNames) {
        $cells = foreach ($w in @($doc.widths)) { $set = New-Object Collections.Generic.HashSet[string]; foreach ($p in $pages) { if ([int]$p.width -ne [int]$w) { continue }; foreach ($it in @($p.items)) { if ([string]$it.role -eq $role -and [string]$it.vis -eq 'si') { $null = $set.Add([string]$it.sig) } } }; $set.Count }
        $null = $sb.AppendLine('| ' + $role + ' | ' + ($cells -join ' | ') + ' |')
    }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## 5. Titolo della scheda e superficie della scheda, per produttore')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Ruolo | Produttore | Firma | Dove |')
    $null = $sb.AppendLine('| --- | --- | --- | --- |')
    $rows = @{}
    foreach ($p in $pages) { foreach ($it in @($p.items)) { if (@('scheda', 'scheda-titolo') -notcontains [string]$it.role -or [string]$it.vis -ne 'si') { continue }; $k = [string]$it.role + ' | ' + [string]$it.prod + ' | ' + ([string]$it.sig).Replace('|', '/'); if (-not $rows.ContainsKey($k)) { $rows[$k] = New-Object Collections.Generic.List[string] }; $rows[$k].Add([string]$p.name + ' ' + $p.width) } }
    foreach ($k in ($rows.Keys | Sort-Object)) { $null = $sb.AppendLine('| ' + $k + ' | ' + ((@($rows[$k]) | Select-Object -Unique) -join ', ') + ' |') }
    [IO.File]::WriteAllText($path, $sb.ToString().Replace("`r`n", "`n").Replace("`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
}

if ($Library) { return }

# ---------- esecuzione ----------
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$base = 'https://' + $HostName + ':' + $KsbPort
if (-not (Test-KsbAllowedBase ($base + '/'))) { Write-Host ('STYLE_BASELINE FAIL: origine non ammessa: ' + $base + ' (solo sito LAB, porta ' + $KsbPort + ')'); exit 1 }
if ($Out -eq '') { $Out = Join-Path $root ('.ai-review\style-baseline\' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
function Assert-KsbOrigin($browser) { $o = [string](Invoke-KsJs $browser 'location.origin'); if ($o -ne $base) { throw ('ORIGINE_INATTESA: ' + $o) } }
function Open-KsbPage($browser, [string]$path) { Open-KsUrl $browser ($base + $path) 300; Assert-KsbOrigin $browser }
function Start-KsbBrowser([int]$w) { if ($w -lt 700) { return (Start-KsBrowser -LoopbackHosts $KsbHosts -Width $w -Height 844 -Mobile) } else { return (Start-KsBrowser -LoopbackHosts $KsbHosts -Width $w -Height 900) } }
$pages = New-Object Collections.Generic.List[object]
$shotDir = if ($Shots) { $Out } else { '' }
foreach ($w in $Widths) {
    $b = Start-KsbBrowser $w
    try {
        $reads = New-Object Collections.Generic.List[object]
        for ($i = 0; $i -lt [Math]::Max(1, $HomeReads); $i++) { Open-KsbPage $b '/Default.aspx'; $reads.Add((Read-KsbPage $b 'home' $w $true $(if ($i -eq 0) { $shotDir } else { '' }))) }
        $pages.Add((Merge-KsbReads $reads.ToArray())); Write-Host ('  home ' + $w)
        Open-KsbPage $b '/articoli.aspx'
        $pick = ConvertFrom-Json ([string](Invoke-KsJs $b $KsbPickJs))
        $pages.Add((Read-KsbPage $b 'elenco' $w $true $shotDir)); Write-Host ('  elenco ' + $w)
        foreach ($kind in @('sconto', 'quantita', 'normale')) {
            $href = [string]$pick.$kind
            if ($href -eq '') { Write-Host ('  scheda-' + $kind + ' ' + $w + ': nessun articolo di questo tipo nella prima pagina dell''elenco'); continue }
            if ($href -match '^https?://') { $href = ([Uri]$href).PathAndQuery } elseif ($href -notmatch '^/') { $href = '/' + $href }
            Open-KsbPage $b $href
            $pages.Add((Read-KsbPage $b ('scheda-' + $kind) $w $true $shotDir)); Write-Host ('  scheda-' + $kind + ' ' + $w)
        }
        Open-KsbPage $b '/login.aspx'
        $pages.Add((Read-KsbPage $b 'accesso' $w $true $shotDir)); Write-Host ('  accesso ' + $w)
    } finally { Stop-KsBrowser $b }
    if ($WithUser) {
        # Browser separato: da qui in poi la sessione e collegata, quindi nessun testo e nessuna schermata.
        $b = Start-KsbBrowser $w
        try {
            Open-KsbPage $b '/login.aspx'
            $secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
            $sec = ConvertTo-SecureString (Get-Content -LiteralPath $secretFile)
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            try {
                Assert-KsbOrigin $b
                Set-KsValue $b '#MainContent_tbUsername' 'PROVA'
                Set-KsValue $b '#MainContent_tbPassword' ([Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr))
            } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            Invoke-KsClick $b '#MainContent_btnLogin'
            Assert-KsbOrigin $b
            if ([string](Invoke-KsJs $b 'location.pathname') -match 'login\.aspx') { throw 'ACCESSO_NON_RIUSCITO' }
            foreach ($p in @(@('carrello', '/carrello.aspx'), @('area-cliente', '/myaccount.aspx'))) {
                Open-KsbPage $b $p[1]
                $pages.Add((Read-KsbPage $b $p[0] $w $false '')); Write-Host ('  ' + $p[0] + ' ' + $w)
            }
        } finally { Stop-KsBrowser $b }
    }
}
$sha = ''; try { $sha = ((& git -C $root rev-parse --short HEAD) -join '').Trim() } catch { }
$doc = [pscustomobject]@{ version = $KsbVersion; date = (Get-Date -Format 'yyyy-MM-dd'); sha = $sha; origin = $base; widths = $Widths; homeReads = [Math]::Max(1, $HomeReads); withUser = [bool]$WithUser; pages = $pages.ToArray() }
[IO.File]::WriteAllText((Join-Path $Out 'baseline.json'), (ConvertTo-Json $doc -Depth 8), $utf8)
$shotErrors = 0; foreach ($p in $pages) { $shotErrors += [int]$p.shotErrors }
Write-Host ('STYLE_BASELINE: ' + $pages.Count + ' pagine, ' + (@($pages | ForEach-Object { @($_.items).Count }) | Measure-Object -Sum).Sum + ' varianti, schermate fallite ' + $shotErrors + ', cartella ' + $Out)
if ($Summary -ne '') { Write-KsbSummary $doc $Summary; Write-Host ('  riepilogo: ' + $Summary) }
$exit = 0
if ($Compare -ne '') {
    $old = ConvertFrom-Json ([IO.File]::ReadAllText($Compare, [Text.Encoding]::UTF8))
    $cmp = Compare-KsbBaseline @($old.pages) $pages.ToArray()
    foreach ($x in $cmp.Warnings) { Write-Host ('  AVVISO ' + $x) }
    foreach ($x in $cmp.Errors) { Write-Host ('  ERRORE ' + $x) }
    Write-Host ('STYLE_BASELINE CONFRONTO: errori ' + $cmp.Errors.Count + ', avvisi ' + $cmp.Warnings.Count)
    if ($cmp.Errors.Count -gt 0) { $exit = 1 }
}
if ($shotErrors -gt 0) { $exit = 1 }
exit $exit
