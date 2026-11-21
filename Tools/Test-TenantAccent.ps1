[CmdletBinding()]
param([switch]$SkipMutants, [switch]$Report, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# STYLE-TENANT-ACCENT-1A. Un solo colore di accento per vetrina (richiesta del PO del 2026-11-20): variabile --ks-accent, un valore per azienda,
# in Public/assets/keepstore/css/tenant-accent.css. Prezzi (anche dove rossi) ed errori restano del colore di prima.
# Prova COMPORTAMENTALE sul sito LAB (https, 127.0.0.1, porta 18843, browser vero), sui due host delle due aziende.
# Metodo: nello stesso DOM si fotografano i colori calcolati di TUTTI gli elementi con il foglio nuovo spento e acceso (canali sRGB).
#   Azienda con il rosso storico: le due foto sono identiche.  Altra azienda: prezzi/offerte/errori identici, accenti del perimetro cambiati,
#   nessun rosso d'accento residuo nel perimetro, testo leggibile sopra e con il colore d'accento, anello di focus visibile.
# (A) sorgente, (B) sito LAB con i file di lavoro, (C) mutazioni sul sito LAB (file rimessi alla fine). Solo ASCII.
# STYLE-TENANT-ACCENT-1B: carrello, area cliente e documenti con l'utente di prova. L'azienda 2 non ha un utente di prova: nella sola copia del sito LAB
#   l'azienda dell'utente di prova riceve per prova l'accento chiaro (stesso foglio, cambia solo il valore), poi il file torna com'era.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('Page.master', 'Page.master.vb', 'Public\assets\keepstore\css\tenant-accent.css')
$fail = New-Object Collections.Generic.List[string]
$repoBytes = @{}
foreach ($f in $files) { $p = Join-Path $root $f; if (Test-Path -LiteralPath $p) { $repoBytes[$f] = [IO.File]::ReadAllBytes($p) } else { $repoBytes[$f] = $null } }
function Get-Text($bytes) { if ($null -eq $bytes) { return '' }; $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$master = Get-Text $repoBytes['Page.master']
$masterVb = Get-Text $repoBytes['Page.master.vb']
$css = Get-Text $repoBytes['Public\assets\keepstore\css\tenant-accent.css']

# ---------- (A) sorgente ----------
if ($css -eq '') { $fail.Add('S01 Public/assets/keepstore/css/tenant-accent.css esiste') }
$links = [regex]::Matches($master, '<link rel="stylesheet" href="<%= ThemeManager\.Asset\("css/([a-z\-\.]+)"\)')
if ($links.Count -eq 0 -or $links[$links.Count - 1].Groups[1].Value -ne 'tenant-accent.css') { $fail.Add('S02 tenant-accent.css e l''ultimo foglio del punto comune (Page.master)') }
if ($masterVb -notmatch 'PageBody\.Attributes\("data-ks-company"\)') { $fail.Add('S03 il body porta l''azienda risolta per host (data-ks-company)') }
$line1 = [regex]::Matches($css, '(?m)^body\[data-ks-company="1"\]\s*\{\s*--ks-accent:\s*(#[0-9A-Fa-f]{6});\s*\}')
$line2 = [regex]::Matches($css, '(?m)^body\[data-ks-company="2"\]\s*\{\s*--ks-accent:\s*(#[0-9A-Fa-f]{6});\s*\}')
if ($line1.Count -ne 1 -or $line1[0].Groups[1].Value -ne '#D80027') { $fail.Add('S04 una riga per Azienda 1 con il rosso attuale #D80027') }
if ($line2.Count -ne 1 -or $line2[0].Groups[1].Value -ne '#FF8C00') { $fail.Add('S05 una riga per Azienda 2 con #FF8C00') }
if (([regex]::Matches($css, '--ks-accent\s*:')).Count -ne 3) { $fail.Add('S06 --ks-accent e assegnata solo nel ripiego e nelle due righe delle aziende') }
if ($css -match '(?i)taikun|webaffare|onsus') { $fail.Add('S07 nessun nome di cliente o di template nel foglio') }
foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }
$sourceFailed = ($fail.Count -gt 0)

# ---------- (B) sito LAB ----------
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('TENANT_ACCENT FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
function Sync-Site {
    foreach ($f in $files) {
        $p = Join-Path $SitePath $f
        if ($null -eq $repoBytes[$f]) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }; continue }
        if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($repoBytes[$f])) { [IO.File]::WriteAllBytes($p, $repoBytes[$f]) }
    }
}
function Write-Site([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($null -ne $b -and $b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

# Foto dei colori e analisi, tutto nella pagina. Restituisce JSON.
$scanJs = @'
(function(){
var link=document.querySelector('link[href*="tenant-accent.css"]');
var cv=document.createElement('canvas');cv.width=cv.height=1;var cx=cv.getContext('2d',{willReadFrequently:true});var cache={};
function ch(c){if(cache[c])return cache[c];cx.clearRect(0,0,1,1);cx.fillStyle='rgba(0,0,0,0)';cx.fillStyle=c;cx.fillRect(0,0,1,1);var d=cx.getImageData(0,0,1,1).data;return cache[c]=[d[0],d[1],d[2],d[3]];}
var st=document.createElement('style');st.textContent='*,*::before,*::after{transition:none!important;animation:none!important}';document.head.appendChild(st);
var els=Array.prototype.slice.call(document.querySelectorAll('body *')).filter(function(e){return !/^(SCRIPT|STYLE|LINK|META|NOSCRIPT|TEMPLATE|BR)$/.test(e.tagName);});
var P=['color','backgroundColor','borderTopColor','borderRightColor','borderBottomColor','borderLeftColor','outlineColor','fill','stroke'];
function snapOne(e){var s=getComputedStyle(e);var o={};
 o.color=ch(s.color);o.backgroundColor=ch(s.backgroundColor);
 if(parseFloat(s.borderTopWidth)>0)o.borderTopColor=ch(s.borderTopColor);if(parseFloat(s.borderRightWidth)>0)o.borderRightColor=ch(s.borderRightColor);
 if(parseFloat(s.borderBottomWidth)>0)o.borderBottomColor=ch(s.borderBottomColor);if(parseFloat(s.borderLeftWidth)>0)o.borderLeftColor=ch(s.borderLeftColor);
 if(s.outlineStyle!=='none'&&parseFloat(s.outlineWidth)>0)o.outlineColor=ch(s.outlineColor);
 if(e.tagName==='INPUT'&&/checkbox|radio/.test(e.type)&&s.accentColor&&s.accentColor!=='auto')o.accentColor=ch(s.accentColor);
 if(e instanceof SVGElement){if(s.fill&&s.fill!=='none'&&s.fill.indexOf('url(')<0)o.fill=ch(s.fill);if(s.stroke&&s.stroke!=='none'&&s.stroke.indexOf('url(')<0)o.stroke=ch(s.stroke);}
 ['::before','::after'].forEach(function(ps){var q=getComputedStyle(e,ps);if(q.content&&q.content!=='none'&&q.content!=='normal'){o[ps+'color']=ch(q.color);o[ps+'bg']=ch(q.backgroundColor);if(parseFloat(q.borderTopWidth)>0)o[ps+'bt']=ch(q.borderTopColor);if(parseFloat(q.borderLeftWidth)>0)o[ps+'bl']=ch(q.borderLeftColor);}});
 return o;}
function snap(){return els.map(snapOne);}
function cls(e){var c=(typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||'').trim().split(/\s+/).filter(Boolean).slice(0,3).join('.');return e.tagName.toLowerCase()+(e.id?'#'+e.id:'')+(c?'.'+c:'');}
function desc(e){var p=e.parentElement;return cls(e)+(p&&p!==document.body?' < '+cls(p):'');}
var PR=/price|prezz|promo|sale|sconto|discount|risparm|saving|total|deal|venduti|sold|sales|offert|percent|assicur/i, ER=/error|invalid|danger|alert|validat|required|inventory/i;
var NOTP=/tf-btn|price-apply|rate-percent|nav-title|ks-card-buy-cta|btn-submit/i;function fam(e,re){var own=(typeof e.className==='string'?e.className:(e.className&&e.className.baseVal)||'');if(NOTP.test(own)||e.tagName==='BUTTON'||(e.tagName==='INPUT'&&/submit|button/.test(e.type)))return false;for(var i=0,x=e;x&&x!==document.body&&i<4;i++,x=x.parentElement){var c=(typeof x.className==='string'?x.className:(x.className&&x.className.baseVal)||'')+' '+(x.id||'');if(NOTP.test(c))return false;if(re.test(c))return true;}return false;}
function vis(e){if(!e.getClientRects().length)return false;var s=getComputedStyle(e);return s.visibility!=='hidden'&&parseFloat(s.opacity)>0.05;}
function red(c){return c&&c[3]>40&&c[0]>150&&c[1]<75&&c[2]<95&&c[0]-c[1]>110;}
function lum(c){var a=[c[0],c[1],c[2]].map(function(v){v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4)});return 0.2126*a[0]+0.7152*a[1]+0.0722*a[2];}
function cr(x,y){var a=lum(x),b=lum(y);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);}
function near(a,b,t){return Math.abs(a[0]-b[0])<=t&&Math.abs(a[1]-b[1])<=t&&Math.abs(a[2]-b[2])<=t;}
function eq(a,b){if(!a&&!b)return true;if(!a||!b)return false;return a[0]===b[0]&&a[1]===b[1]&&a[2]===b[2]&&a[3]===b[3];}
function group(list){var m={},o=[];list.forEach(function(k){if(!m[k]){m[k]=1;o.push(k);}else m[k]++;});return o.slice(0,60).map(function(k){return k+(m[k]>1?' x'+m[k]:'');});}
var out={sheet:!!link,company:document.body.getAttribute('data-ks-company')||'',elements:els.length};
if(!link){out.changed=[];out.changedPrice=[];out.residual=[];out.low=[];out.accent='';return JSON.stringify(out);}
if(!link.sheet){out.sheet=false;out.changed=[];out.changedPrice=[];out.residual=[];out.low=[];out.accent='';return JSON.stringify(out);}link.sheet.disabled=true;var A=snap();link.sheet.disabled=false;var B=snap();
var bs=getComputedStyle(document.body);var t=document.createElement('i');document.body.appendChild(t);
function v(n){t.style.color='var('+n+')';return ch(getComputedStyle(t).color);}
var acc=v('--ks-accent'),hov=v('--ks-accent-hover'),txt=v('--ks-accent-text'),on=v('--ks-on-accent'),htx=v('--ks-accent-hover-text');t.remove();
out.accent=acc.slice(0,3).join(',');out.hover=hov.slice(0,3).join(',');out.text=txt.slice(0,3).join(',');out.on=on.slice(0,3).join(',');
var changed=[],changedPrice=[],residual=[],low=[],accentUse=0;
for(var i=0;i<els.length;i++){var e=els[i],a=A[i],b=B[i];var keys={};Object.keys(a).forEach(function(k){keys[k]=1});Object.keys(b).forEach(function(k){keys[k]=1});
 var v0=vis(e);
 Object.keys(keys).forEach(function(k){
  if(!eq(a[k],b[k])){var line=desc(e)+' ['+k+'] '+(a[k]?a[k].join(','):'-')+' -> '+(b[k]?b[k].join(','):'-');changed.push(line);if(fam(e,PR)||fam(e,ER))changedPrice.push(line);}
  if(v0&&red(b[k])&&!fam(e,PR)&&!fam(e,ER)){if(k==='backgroundColor'||k==='color'&&e.childNodes.length&&Array.prototype.some.call(e.childNodes,function(n){return n.nodeType===3&&n.nodeValue.trim();})||k.indexOf('border')===0||k==='fill'||k==='stroke'||k==='accentColor'||k.indexOf('::')===0)residual.push(desc(e)+' ['+k+'] '+b[k].slice(0,3).join(','));}
  if(b[k]&&near(b[k],acc,2)&&b[k][3]>200)accentUse++;
 });
 if(v0&&(e.textContent.trim()||e.querySelector('i,svg'))&&b.backgroundColor[3]>200&&(near(b.backgroundColor,acc,3)||near(b.backgroundColor,hov,3))&&b.color[3]>200&&cr(b.color,b.backgroundColor)<3)low.push(desc(e)+' icona o testo '+b.color.slice(0,3).join(',')+' su fondo di accento = '+cr(b.color,b.backgroundColor).toFixed(2));
 if(v0&&(Array.prototype.some.call(e.childNodes,function(n){return n.nodeType===3&&n.nodeValue.trim().length>0;})||(e.tagName==='INPUT'&&/submit|button/.test(e.type)&&e.value))){
  var fg=b.color;var bg=null;for(var x=e;x;x=x.parentElement){var c=ch(getComputedStyle(x).backgroundColor);if(c[3]>=230){bg=c;break;}if(getComputedStyle(x).backgroundImage!=='none'){bg=null;break;}if(x===document.documentElement){bg=[255,255,255,255];}}
  if(bg&&fg[3]>200){var isA=function(c){return near(c,acc,3)||near(c,hov,3)||near(c,txt,3)||near(c,htx,3);};
   if(isA(fg)||isA(bg)||!eq(a.color,b.color)){var s=getComputedStyle(e);var px=parseFloat(s.fontSize);var big=px>=24||(px>=18.66&&parseInt(s.fontWeight,10)>=700);var r=cr(fg,bg);if(r<(big?3:4.5))low.push(desc(e)+' testo '+fg.slice(0,3).join(',')+' su '+bg.slice(0,3).join(',')+' = '+r.toFixed(2));}}
 }
}
out.changedCount=changed.length;out.changed=group(changed);out.changedPrice=group(changedPrice);out.residual=group(residual);out.low=group(low);out.accentUse=accentUse;
return JSON.stringify(out);
})()
'@
$scanJs = ($scanJs -replace "`r?`n", ' ')
$colorFn = "var cv=document.createElement('canvas');cv.width=cv.height=1;var cx=cv.getContext('2d',{willReadFrequently:true});function ch(c){cx.clearRect(0,0,1,1);cx.fillStyle='rgba(0,0,0,0)';cx.fillStyle=c;cx.fillRect(0,0,1,1);var d=cx.getImageData(0,0,1,1).data;return [d[0],d[1],d[2],d[3]];}function lum(c){var a=[c[0],c[1],c[2]].map(function(v){v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4)});return 0.2126*a[0]+0.7152*a[1]+0.0722*a[2];}function cr(x,y){var a=lum(x),b=lum(y);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);}function nr(a,b){return Math.abs(a[0]-b[0])<=2&&Math.abs(a[1]-b[1])<=2&&Math.abs(a[2]-b[2])<=2;}function vv(n){var t=document.createElement('i');document.body.appendChild(t);t.style.color='var('+n+')';var c=ch(getComputedStyle(t).color);t.remove();return c;}"
$ddJs = "(function(){" + $colorFn + "var a=document.querySelector('.ks-suggest .ks-suggest-all');if(!a||!a.getClientRects().length)return '';var s=getComputedStyle(a);var bg=ch(s.backgroundColor),fg=ch(s.color);if(!nr(bg,vv('--ks-accent')))return 'fondo '+bg.slice(0,3).join(',');if(cr(fg,bg)<4.5)return 'contrasto '+cr(fg,bg).toFixed(2);var p=document.querySelector('.ks-suggest .ks-suggest-price');if(p){var pc=ch(getComputedStyle(p).color);if(!(pc[0]===176&&pc[1]===0&&pc[2]===31))return 'prezzo '+pc.slice(0,3).join(',');}return 'ok';})()"
$focusJs = "(function(){" + $colorFn + "var e=document.activeElement;if(!e||e===document.body)return 'none';var s=getComputedStyle(e);if(s.outlineStyle==='none'||parseFloat(s.outlineWidth)<2)return 'none';var oc=ch(s.outlineColor);if(oc[0]>150&&oc[1]<75&&oc[2]<95)return 'anello rosso '+oc.slice(0,3).join(',')+' su '+e.tagName+'.'+e.className;var r=cr(oc,[255,255,255]);return r>=3?'ok':'contrasto '+r.toFixed(2)+' su '+e.tagName+'.'+e.className;})()"
function Scan($browser, [string]$url) {
    Open-KsUrl $browser $url 300; Start-Sleep -Milliseconds 2500
    $null = Invoke-KsJs $browser 'window.scrollTo(0, document.body.scrollHeight); 1'; Start-Sleep -Milliseconds 800
    $null = Invoke-KsJs $browser 'window.scrollTo(0, 0); 1'; Start-Sleep -Milliseconds 400
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser $scanJs)))
}
function Show-List([string]$title, $list) { if ($Report -and @($list).Count -gt 0) { Write-Host ('    ' + $title + ':'); foreach ($x in @($list)) { Write-Host ('      ' + $x) } } }

# Restituisce l'elenco dei difetti del sito (vuoto = giusto).
function Test-Site($browser) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($site in $script:sites) {
        foreach ($path in $site.Paths) {
            $s = Scan $browser ('https://' + $site.Host + ':18843' + $path)
            $tag = 'azienda ' + $site.Company + ' ' + $path
            if (-not $s.sheet) { $bad.Add($tag + ': foglio non collegato'); continue }
            if ($s.company -ne [string]$site.Company) { $bad.Add($tag + ': data-ks-company="' + $s.company + '"') }
            if ($s.accent -ne $site.Accent) { $bad.Add($tag + ': accento ' + $s.accent + ', atteso ' + $site.Accent) }
            if ($site.Legacy) {
                if ($s.changedCount -ne 0) { $bad.Add($tag + ': ' + $s.changedCount + ' colori cambiati con il rosso storico, per esempio ' + @($s.changed)[0]) }
                if ($s.on -ne '255,255,255' -or $s.text -ne $site.Accent) { $bad.Add($tag + ': derivati ' + $s.on + ' / ' + $s.text) }
            } else {
                if (@($s.changedPrice).Count -ne 0) { $bad.Add($tag + ': prezzo, offerta o errore cambiato: ' + @($s.changedPrice)[0]) }
                if ($s.changedCount -lt 5 -or $s.accentUse -lt 3) { $bad.Add($tag + ': accenti non applicati (cambiati ' + $s.changedCount + ', usi ' + $s.accentUse + ')') }
                if (@($s.residual).Count -ne 0) { $bad.Add($tag + ': rosso d''accento residuo: ' + @($s.residual)[0]) }
                if (@($s.low).Count -ne 0) { $bad.Add($tag + ': testo poco leggibile: ' + @($s.low)[0]) }
                if ($s.on -ne '0,0,0') { $bad.Add($tag + ': testo sopra l''accento ' + $s.on + ', atteso nero') }
            }
            if ($Report) { Write-Host ('  ' + $tag + ': elementi ' + $s.elements + ', cambiati ' + $s.changedCount + ', accento ' + $s.accent + ', hover ' + $s.hover + ', testo ' + $s.text + ', sopra ' + $s.on) }
            Show-List 'cambiati' $s.changed; Show-List 'PREZZI/ERRORI cambiati' $s.changedPrice; Show-List 'rosso residuo' $s.residual; Show-List 'poco leggibile' $s.low
        }
    }
    return $bad.ToArray()
}

# ---------- STYLE-TENANT-ACCENT-1B: pagine dell'utente di prova ----------
$cssRelPath = 'Public\assets\keepstore\css\tenant-accent.css'
$userLine = 'body[data-ks-company="1"] { --ks-accent: #D80027; }'
$userLineLight = 'body[data-ks-company="1"] { --ks-accent: #FF8C00; }'
$namedJs = "(function(){" + $colorFn + "function c(q,p){var e=document.querySelector(q);return e?ch(getComputedStyle(e)[p]).slice(0,3).join(','):'';}var o={};o.total=c('.ks-checkout-grand-total span:last-child','color');o.insurance=c('[id`$=lblAssicurazione]','color');o.go=c('#MainContent_btCompleta','backgroundColor');o.accent=vv('--ks-accent').slice(0,3).join(',');o.hover=vv('--ks-accent-hover').slice(0,3).join(',');o.x=0;o.y=0;o.goCr='0';var b=document.querySelector('#MainContent_btCompleta');if(b){b.scrollIntoView({block:'center',behavior:'instant'});o.hov=b.matches(':hover');var r=b.getBoundingClientRect();o.x=Math.round(r.left+r.width/2);o.y=Math.round(r.top+r.height/2);var s=getComputedStyle(b);o.goCr=cr(ch(s.color),ch(s.backgroundColor)).toFixed(2);}return JSON.stringify(o);})()"
function Enter-User($browser) {
    Open-KsUrl $browser ($base + '/login.aspx') 300
    if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_tbPassword")')) {
        Set-KsValue $browser '#MainContent_tbUsername' $testUser
        Set-KsValue $browser '#MainContent_tbPassword' (Get-Secret)
        Invoke-KsClick $browser '#MainContent_btnLogin'
        Start-Sleep -Milliseconds 1500
    }
    Open-KsUrl $browser ($base + '/carrello.aspx') 300
    if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btCompleta")')) {
        Open-KsUrl $browser ($base + '/articoli.aspx') 300; Start-Sleep -Seconds 2
        Invoke-KsClick $browser 'button.js-ks-cart-link' -NoWait; Start-Sleep -Seconds 6
        Open-KsUrl $browser ($base + '/carrello.aspx') 300
    }
    if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btCompleta")')) { throw 'PAGINA_NON_VALIDA: carrello dell''utente di prova senza il pulsante per proseguire' }
}
function Scan-Here($browser) {
    Start-Sleep -Milliseconds 1500
    $null = Invoke-KsJs $browser 'window.scrollTo(0, document.body.scrollHeight); 1'; Start-Sleep -Milliseconds 600
    $null = Invoke-KsJs $browser 'window.scrollTo(0, 0); 1'; Start-Sleep -Milliseconds 300
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser $scanJs)))
}
function Add-UserScan($bad, [string]$tag, $s, [bool]$light) {
    if (-not $s.sheet) { $bad.Add($tag + ': foglio non collegato'); return }
    if ($light) {
        if ($s.accent -ne '255,140,0') { $bad.Add($tag + ': accento ' + $s.accent + ', atteso 255,140,0') }
        if (@($s.residual).Count -ne 0) { $bad.Add($tag + ': rosso d''accento residuo: ' + @($s.residual)[0]) }
        if (@($s.low).Count -ne 0) { $bad.Add($tag + ': testo poco leggibile: ' + @($s.low)[0]) }
    } else {
        if ($s.changedCount -ne 0) { $bad.Add($tag + ': ' + $s.changedCount + ' colori cambiati con il rosso storico, per esempio ' + @($s.changed)[0]) }
    }
    if ($Report) { Write-Host ('  ' + $tag + ': elementi ' + $s.elements + ', cambiati ' + $s.changedCount + ', accento ' + $s.accent) }
    if (-not $light) { Show-List 'cambiati' $s.changed }
    Show-List 'rosso residuo' $s.residual; Show-List 'poco leggibile' $s.low
}
function Get-Ratio($text) { return [double]::Parse([string]$text, [Globalization.CultureInfo]::InvariantCulture) }
# Una passata sulle pagine dell'utente di prova. Restituisce l'elenco dei difetti (vuoto = giusto).
function Test-UserPass($browser, [bool]$light) {
    $bad = New-Object Collections.Generic.List[string]
    $tagBase = $(if ($light) { 'accento chiaro, ' } else { 'rosso storico, ' })
    Enter-User $browser
    $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + 'carrello') $s $light
    if ($light) {
        $n = ConvertFrom-Json ([string](Invoke-KsJs $browser $namedJs))
        if ($n.go -ne $n.accent) { $bad.Add($tagBase + 'carrello: fondo del pulsante per proseguire ' + $n.go + ', atteso l''accento ' + $n.accent) }
        if ((Get-Ratio $n.goCr) -lt 4.5) { $bad.Add($tagBase + 'carrello: testo del pulsante per proseguire a ' + $n.goCr) }
        $null = Invoke-KsCdp $browser 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = [int]$n.x; y = [int]$n.y }
        Start-Sleep -Milliseconds 400
        $h = ConvertFrom-Json ([string](Invoke-KsJs $browser $namedJs))
        if ($h.go -ne $h.hover) { $bad.Add($tagBase + 'carrello: in hover il fondo del pulsante e ' + $h.go + ', atteso l''accento scuro ' + $h.hover + ' (hover reale: ' + $h.hov + ')') }
        if ((Get-Ratio $h.goCr) -lt 4.5) { $bad.Add($tagBase + 'carrello: in hover il testo del pulsante e a ' + $h.goCr) }
        $null = Invoke-KsCdp $browser 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = 2; y = 2 }
    }
    for ($try = 0; $try -lt 3; $try++) {
        if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btCompleta")')) { Invoke-KsClick $browser '#MainContent_btCompleta' }
        for ($w = 0; $w -lt 12; $w++) { Start-Sleep -Milliseconds 500; if ([bool](Invoke-KsJs $browser '!!document.querySelector(".ks-checkout-grand-total")')) { break } }
        if ([bool](Invoke-KsJs $browser '!!document.querySelector(".ks-checkout-grand-total")')) { break }
        Enter-User $browser
    }
    $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + 'spedizione e pagamento') $s $light
    $n = ConvertFrom-Json ([string](Invoke-KsJs $browser $namedJs))
    if ($n.total -eq '') { throw 'PAGINA_NON_VALIDA: totale del riepilogo non trovato' }
    if ($n.total -ne '216,0,39') { $bad.Add($tagBase + 'spedizione e pagamento: Totale ' + $n.total + ', atteso il rosso dei prezzi 216,0,39') }
    if ($n.insurance -ne '216,0,39') { $bad.Add($tagBase + 'spedizione e pagamento: importo dell''assicurazione ' + $n.insurance + ', atteso 216,0,39') }
    Open-KsUrl $browser ($base + '/myaccount.aspx') 300
    $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + 'area cliente') $s $light
    $docs = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('a[href*=""documenti.aspx?t=""]');return a?a.getAttribute('href'):'';})()")
    if ($docs -eq '') { throw 'PAGINA_NON_VALIDA: area cliente senza il collegamento ai documenti' }
    Open-KsUrl $browser ($base + '/' + $docs.TrimStart('/')) 300
    $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + 'documenti') $s $light
    $det = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('a[href*=""documentidettaglio.aspx?id=""]');return a?a.getAttribute('href'):'';})()")
    if ($det -ne '') { Open-KsUrl $browser ($base + '/' + $det.TrimStart('/')) 300; $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + 'dettaglio documento') $s $light }
    foreach ($p in @('/datiutente.aspx', '/my-account-edit.aspx', '/track-your-order.aspx')) { Open-KsUrl $browser ($base + $p) 300; $s = Scan-Here $browser; Add-UserScan $bad ($tagBase + $p) $s $light }
    return $bad.ToArray()
}
# Le due passate (rosso storico, poi accento chiaro di prova) con il testo del foglio dato; alla fine il file del sito torna quello dato.
function Test-User($browser, [string]$sheetText) {
    $all = New-Object Collections.Generic.List[string]
    if (-not $sheetText.Contains($userLine)) { $all.Add('riga dell''azienda dell''utente di prova non trovata nel foglio'); return $all.ToArray() }
    try {
        Write-Site $cssRelPath $sheetText
        foreach ($x in @(Test-UserPass $browser $false)) { $all.Add($x) }
        Write-Site $cssRelPath ($sheetText.Replace($userLine, $userLineLight))
        foreach ($x in @(Test-UserPass $browser $true)) { $all.Add($x) }
    } finally { Write-Site $cssRelPath $sheetText }
    return $all.ToArray()
}

$browser = $null
$mutantFail = New-Object Collections.Generic.List[string]
$siteFailed = $false
try {
    Sync-Site
    $rows = @(Invoke-Sql "SELECT CONCAT('ksrow|', id, '|', LOWER(TRIM(url1))) AS r FROM aziende WHERE id IN (1,2) ORDER BY id;")
    $hosts = @{}; foreach ($l in $rows) { $mm = [regex]::Match([string]$l, '^ksrow\|(\d)\|([a-z0-9\.\-]+)$'); if ($mm.Success) { $hosts[[int]$mm.Groups[1].Value] = $mm.Groups[2].Value } }
    Check ($hosts.ContainsKey(1) -and $hosts.ContainsKey(2)) 'L01 host delle due aziende letti dal database LAB'
    $browser = Start-KsBrowser -LoopbackHosts @($hosts[1], $hosts[2]) -Width 1280 -Height 900
    $pdp = @{}
    foreach ($c in @(1, 2)) {
        Open-KsUrl $browser ('https://' + $hosts[$c] + ':18843/articoli.aspx') 300; Start-Sleep -Milliseconds 1500
        $href = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('a[href*=""articolo.aspx?id=""]');return a?a.getAttribute('href'):'';})()")
        $mm = [regex]::Match($href, 'articolo\.aspx\?id=\d+[^#]*'); $pdp[$c] = if ($mm.Success) { '/' + $mm.Value } else { '' }
    }
    Check ($pdp[1] -ne '' -and $pdp[2] -ne '') 'L02 una scheda articolo trovata per ciascuna azienda'
    $script:sites = @(
        @{ Company = 1; Host = $hosts[1]; Accent = '216,0,39'; Legacy = $true; Paths = @('/Default.aspx', '/articoli.aspx', $pdp[1], '/carrello.aspx', '/login.aspx') },
        @{ Company = 2; Host = $hosts[2]; Accent = '255,140,0'; Legacy = $false; Paths = @('/Default.aspx', '/articoli.aspx', $pdp[2]) }
    )
    if ($e2e.Count -eq 0) {
        $bad = @(Test-Site $browser)
        Check ($bad.Count -eq 0) ('L03 colori delle due vetrine' + $(if ($bad.Count) { ' -> ' + (($bad | Select-Object -First 8) -join ' || ') } else { '' }))
    }
    if ($e2e.Count -eq 0) {
        # tendina della ricerca (stili iniettati da script dopo il foglio) e anello di focus con Tab vero, sull'azienda con l'accento chiaro
        Open-KsUrl $browser ('https://' + $hosts[2] + ':18843' + $pdp[2]) 300; Start-Sleep -Milliseconds 2000
        $null = Invoke-KsJs $browser "(function(){var i=document.querySelector('.ks-search-host input[type=text], .form-search-product input[type=text]');if(!i)return 0;i.focus();i.value='cavo';i.dispatchEvent(new Event('input',{bubbles:true}));i.dispatchEvent(new KeyboardEvent('keyup',{bubbles:true,key:'o'}));return 1;})()"
        $dd = ''
        for ($w = 0; $w -lt 16 -and $dd -eq ''; $w++) { Start-Sleep -Milliseconds 500; $dd = [string](Invoke-KsJs $browser $ddJs) }
        Check ($dd -eq 'ok') ('L04 tendina della ricerca: pulsante con l''accento e testo leggibile, prezzo nel suo rosso' + $(if ($dd -ne 'ok') { ' -> ' + $dd } else { '' }))
        $null = Invoke-KsJs $browser "(function(){var i=document.querySelector('.ks-search-host input[type=text], .form-search-product input[type=text]');if(i){i.value='';i.blur();}document.body.focus();return 1;})()"
        $fx = ''
        for ($k = 0; $k -lt 6; $k++) {
            foreach ($t in @('rawKeyDown', 'keyUp')) { $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = $t; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9 } }
            Start-Sleep -Milliseconds 250
            $fx = [string](Invoke-KsJs $browser $focusJs)
            if ($fx -ne 'none') { break }
        }
        Check ($fx -eq 'ok') ('L05 anello di focus da tastiera non rosso e ad almeno 3:1 sul bianco' + $(if ($fx -ne 'ok') { ' -> ' + $fx } else { '' }))
    }
    if ($e2e.Count -eq 0) {
        $ub = @(Test-User $browser $css)
        Check ($ub.Count -eq 0) ('L06 carrello, area cliente e documenti: rosso storico identico, accento chiaro completo e leggibile, prezzi fermi' + $(if ($ub.Count) { ' -> ' + (($ub | Select-Object -First 12) -join ' || ') } else { '' }))
    }
    $siteFailed = ($e2e.Count -gt 0)

    # ---------- (C) mutazioni sul sito LAB ----------
    if (-not $siteFailed -and -not $sourceFailed -and -not $SkipMutants) {
        $cssRel = 'Public\assets\keepstore\css\tenant-accent.css'
        $mutants = @(
            @{ Id = 'M01_COMPANIES_SWAPPED'; File = $cssRel; Old = 'body[data-ks-company="2"] { --ks-accent: #FF8C00; }'; New = 'body[data-ks-company="1"] { --ks-accent: #FF8C00; }' },
            @{ Id = 'M02_SHEET_NOT_LINKED'; File = 'Page.master'; Old = 'ThemeManager.Asset("css/tenant-accent.css")'; New = 'ThemeManager.Asset("css/tenant-accent-missing.css")' },
            @{ Id = 'M03_PRICE_FOLLOWS_ACCENT'; File = $cssRel; Old = '--ks-price-accent: #D80027;'; New = '--ks-price-accent: var(--ks-accent);' },
            @{ Id = 'M04_WHITE_TEXT_ON_ACCENT'; File = $cssRel; Old = 'color: var(--ks-on-accent) !important;'; New = 'color: #fff !important;' },
            @{ Id = 'M05_NO_BODY_COMPANY'; File = 'Page.master.vb'; Old = 'PageBody.Attributes("data-ks-company")'; New = 'PageBody.Attributes("data-ks-company-off")' },
            @{ Id = 'M06_ACCENT_TEXT_NOT_DARKENED'; File = $cssRel; Old = '--ks-accent-text: oklch(from var(--ks-accent) min(l, 0.555) c h);'; New = '--ks-accent-text: var(--ks-accent);' },
            @{ Id = 'M07_TOTAL_ALIAS_FOLLOWS_ACCENT'; User = $true; File = $cssRel; Old = '--ks-checkout-primary: var(--ks-price-accent);'; New = '--ks-checkout-primary-off: var(--ks-price-accent);' },
            @{ Id = 'M08_INSURANCE_FOLLOWS_ACCENT'; User = $true; File = $cssRel; Old = '[id$="lblAssicurazione"]'; New = '[id$="lblAssicurazioneOff"]' },
            @{ Id = 'M09_INLINE_RED_NOT_OVERRIDDEN'; User = $true; File = $cssRel; Old = 'color: var(--ks-accent-alt-text) !important;'; New = 'color: var(--ks-accent-alt-text);' },
            @{ Id = 'M10_HISTORIC_TINT_LOST'; User = $true; File = $cssRel; Old = '--ks-accent-custom: clamp(0, '; New = '--ks-accent-custom: clamp(1, ' },
            @{ Id = 'M11_CART_BUTTON_BACKGROUND_RED'; User = $true; File = $cssRel; Old = 'background-color: var(--ks-accent-alt);'; New = 'background-color: #e12825;' },
            @{ Id = 'M12_FILL_BUTTON_TEXT_WHITE'; User = $true; File = $cssRel; Old = '.tf-btn.btn-fill:not(.btn-gray)'; New = '.tf-btn.btn-fill-off:not(.btn-gray)' }
        )
        foreach ($m in $mutants) {
            $src = Get-Text $repoBytes[$m.File]
            if (([regex]::Matches($src, [regex]::Escape($m.Old))).Count -lt 1) { $mutantFail.Add($m.Id + ' ancora assente'); continue }
            Write-Site $m.File ($src.Replace($m.Old, $m.New))
            try {
                if ($m.ContainsKey('User')) { $mb = @(Test-User $browser ($src.Replace($m.Old, $m.New))) } else { $mb = @(Test-Site $browser) }
                if ($mb.Count -eq 0) { $mutantFail.Add($m.Id + ' sopravvive') } else { Write-Host ('  ucciso ' + $m.Id + ': ' + $mb[0]) }
            } catch { $mutantFail.Add($m.Id + ' errore: ' + $_.Exception.Message) }
            Sync-Site
        }
        $after = @(Test-Site $browser) + @(Test-User $browser $css)
        if ($after.Count -ne 0) { $mutantFail.Add('dopo il ripristino il sito non torna verde: ' + $after[0]) }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    try { Sync-Site } catch { Write-Host '  ATTENZIONE: file del sito LAB non ripristinati' }
    Close-LabSite
}

if ($sourceFailed) { Write-Host 'TENANT_ACCENT FAIL (sorgente)' }
if ($e2e.Count -gt 0) { Write-Host ('TENANT_ACCENT FAIL (sito LAB): ' + $e2e.Count) }
foreach ($x in $mutantFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFailed -or $e2e.Count -gt 0 -or $mutantFail.Count -gt 0) { exit 1 }
if ($SkipMutants) { Write-Host 'TENANT_ACCENT OK (mutazioni saltate)' } else { Write-Host 'TENANT_ACCENT OK (12 mutazioni uccise sul sito LAB)' }
exit 0
