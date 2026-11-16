[CmdletBinding()]
param([switch]$SkipMutations)

# KS-A04-FOOTER-ACCORDION-KBD-1A - le quattro sezioni del piede (sotto i 768 px) si aprono e si chiudono anche da tastiera e con lo screen reader.
# Oracolo COMPORTAMENTALE: il VERO SiteFooter.ascx (controlli del server sostituiti da segnaposto), i veri fogli di stile nell'ordine di Page.master, il vero jquery.min.js, il vero
# main.js e il vero ks-footer-accordion.js sono caricati in Edge headless dentro un <form> (come in Page.master). Il test usa la TASTIERA VERA (Tab, Maiusc+Tab, Invio, Spazio via CDP),
# il mouse vero (clic sull'area dell'icona) e il cambio reale della larghezza (390 / 767 / 768 / 1024 px). Legge DOM, stili computati e l'albero di accessibilita del browser.
# Regole: a <=767 px ogni titolo e un heading (h6) con UN SOLO button type=button dentro, aria-expanded coerente con la visibilita reale del pannello, aria-controls che punta al pannello
# fratello; Tab raggiunge i 4 button e nessun link di un pannello chiuso; Invio e Spazio alternano UNA volta (nessun doppio gestore, nessun submit del form); il focus ha un anello
# visibile non tagliato; a >=768 px il DOM torna identico a quello del server (nessun button, classe, stile, id o attributo ARIA aggiunto) e tutti i link sono raggiungibili; se il focus
# stava sul button che sparisce non finisce su body; in colori forzati l'indicatore +/- resta visibile. Mutazioni: copie temporanee dei file, mai la copia di lavoro.
# Senza Edge: NON ESEGUITO (uscita 2), mai PASS. Limiti dichiarati: Edge headless (non Firefox/Safari), nessuno screen reader reale (si legge l'albero di accessibilita di Chromium),
# nessun tema ad alto contrasto reale (emulazione forced-colors), nessun dispositivo touch reale.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'RUN_WITH_WINDOWS_POWERSHELL_5_1' }
$repoRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $repoRoot 'Public/assets/keepstore'
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -ceq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

# --- Sorgenti reali ---------------------------------------------------------------------------------------------------------------------
$ascx = Read-Repo 'Public/ui/controls/SiteFooter.ascx'
$master = Read-Repo 'Page.master'
$mainJs = Read-Repo 'Public/assets/keepstore/js/main.js'
$uiCss = Read-Repo 'Public/assets/keepstore/css/ks-ui.css'
$accPath = Join-Path $assets 'js/ks-footer-accordion.js'
$accExists = Test-Path -LiteralPath $accPath
$accJs = ''
if ($accExists) { $accJs = Norm ([IO.File]::ReadAllText($accPath)) }

$sheetOrder = @('bootstrap.min.css', 'keepstore.css', 'keepstore-overrides.css', 'account-ui.css', 'documents-ui.css', 'auth-ui.css', 'ks-ui.css', 'nice-select.css', 'swiper-bundle.min.css', 'animate.css', 'styles.css', 'minicart-ui.css', 'theme-overrides.css')
foreach ($n in $sheetOrder) { if (-not (Test-Path -LiteralPath (Join-Path $assets ('css/' + $n)))) { throw ('STYLESHEET_MISSING=' + $n) } }

# CSS che ks-page-flags.js aggiunge a runtime in coda al <head> (stesso estratto di Test-FocusVisible.ps1).
$flagsJs = Read-Repo 'Public/assets/keepstore/js/ks-page-flags.js'
$flagsBlock = [regex]::Match($flagsJs, "(?s)st\.textContent = \[(.*?)\]\.join\(''\);")
if (-not $flagsBlock.Success) { throw 'JS_INJECTED_CSS_BLOCK_NOT_FOUND' }
$injectedCss = (([regex]::Matches($flagsBlock.Groups[1].Value, "'((?:[^'\\]|\\.)*)'") | ForEach-Object { $_.Groups[1].Value }) -join '')

# --- Il piede REALE: i controlli del server diventano segnaposto, il resto del markup resta quello di SiteFooter.ascx -------------------------
$pixel = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
function Render-Footer([string]$source) {
    $t = Norm $source
    $t = [regex]::Replace($t, '(?m)^<%@[^\n]*\n', '')
    $t = $t.Replace(' runat="server"', '').Replace(' visible="false"', '').Replace(' Visible="false"', '')
    $t = [regex]::Replace($t, '</?asp:PlaceHolder[^>]*>', '')
    $t = [regex]::Replace($t, '<asp:Image [^>]*/>', ('<img alt="KeepStore" src="' + $pixel + '" width="120" height="30" />'))
    $cats = ((1..7) | ForEach-Object { '<li><a class="link" href="catalogo-' + $_ + '.html">Categoria ' + $_ + '</a></li>' }) -join ''
    $contacts = '<li><span class="icon icon-phone" aria-hidden="true"></span><a class="link" href="tel:+390000000000">+39 000 000000</a></li><li><a class="link" href="mailto:info@example.invalid">info@example.invalid</a></li><li><span>Via di prova 1, 00000 Citta</span></li>'
    $t = [regex]::Replace($t, '<asp:Literal ID="litFooterCategories"[^>]*/>', $cats)
    $t = [regex]::Replace($t, '<asp:Literal ID="litFooterContacts"[^>]*/>', $contacts)
    $t = [regex]::Replace($t, '<asp:Literal ID="litFooterLegal"[^>]*/>', 'Ragione sociale di prova - P.IVA 00000000000')
    $t = [regex]::Replace($t, '<asp:Literal ID="litFooterCopyright"[^>]*/>', 'Copyright di prova')
    if ($t.Contains('<asp:') -or $t.Contains('<%')) { throw 'FOOTER_RENDER_LEFT_SERVER_MARKUP' }
    return $t
}
$footerHtml = Render-Footer $ascx

# --- Controlli sul sorgente (funzione, cosi le mutazioni li riusano) -------------------------------------------------------------------------
function Get-GitFile([string]$rev, [string]$path) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'git'
        $psi.Arguments = 'show ' + $rev + ':' + $path
        $psi.WorkingDirectory = $repoRoot
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $proc = [System.Diagnostics.Process]::Start($psi)
        $out = $proc.StandardOutput.ReadToEnd()
        $null = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) { return $null }
        return $out
    } catch { return $null }
}
# main.js e minificato: il taglio deve essere ESATTAMENTE la definizione di handleFooter e la sua chiamata (base: stable eaf66184, prima di questo task).
$baseMain = Get-GitFile 'eaf66184' 'Public/assets/keepstore/js/main.js'
function Eval-Static([string]$master, [string]$mainJs, [string]$uiCss, [string]$accJs, [bool]$accExists) {
    $list = New-Object 'System.Collections.Generic.List[string]'
    function Chk([bool]$condition, [string]$code) { if (-not $condition) { $list.Add($code) } }
    $headings = [regex]::Matches($ascx, '(?s)<h6 class="ft-heading footer-heading-mobile[^"]*">([^<]+)</h6>\s*<div class="tf-collapse-content">')
    Chk ($headings.Count -eq 4) 'ASCX_FOUR_HEADINGS_WITH_A_SIBLING_PANEL'
    Chk ($accExists) 'SCRIPT_ks-footer-accordion.js_EXISTS'
    Chk (-not $mainJs.Contains('handleFooter') -and -not $mainJs.Contains('footer-heading-mobile')) 'MAIN_JS_HAS_NO_OLD_FOOTER_ACCORDION'
    Chk ($master -match '<script src="<%= ThemeManager\.Asset\("js/ks-footer-accordion\.js"\) %>\?v=20261116-footer-accordion1a"></script>') 'MASTER_LOADS_THE_SCRIPT_WITH_A_VERSION'
    Chk (($master.IndexOf('js/ks-footer-accordion.js') -gt $master.IndexOf('js/main.js')) -and ($master.IndexOf('js/main.js') -gt 0)) 'MASTER_LOADS_THE_SCRIPT_AFTER_MAIN_JS'
    Chk (-not $master.Contains('main.js") %>?v=20260929-cart-authoritative-guard-1b-rev1"')) 'MASTER_BUMPED_THE_MAIN_JS_VERSION'
    Chk ($master -match 'css/ks-ui\.css"\) & "\?v=20261116-footer-touch44a"') 'MASTER_VERSIONS_THE_KS_UI_CSS_LINK'
    Chk ($uiCss -match '(?s)@media \(max-width: 767px\)\s*\{\s*\.ft-link-wrap \.footer-heading-mobile\s*\{[^}]*min-height: 44px') 'KS_UI_CSS_HAS_THE_44_PX_ROW_UNDER_768'
    Chk ($uiCss.Contains('.footer-heading-mobile .ft-heading-toggle') -and $uiCss.Contains('@media (forced-colors: active)')) 'KS_UI_CSS_HAS_THE_BUTTON_RESET_AND_THE_FORCED_COLORS_RULE'
    if ($null -eq $baseMain) { Chk $false 'MAIN_JS_BASE_COMMIT_NOT_AVAILABLE_THE_CUT_CANNOT_BE_PROVED' }
    else {
        $b = Norm $baseMain
        $startMark = 'var handleFooter=function(){'
        $endMark = 'handleAccordion()})};'
        $si = $b.IndexOf($startMark)
        $ei = -1
        if ($si -ge 0) { $ei = $b.IndexOf($endMark, $si) }
        if ($si -lt 0 -or $ei -lt 0) { Chk $false 'MAIN_JS_BASE_HAS_THE_OLD_FOOTER_ACCORDION' }
        else {
            $expected = $b.Remove($si, $ei + $endMark.Length - $si).Replace('handleFooter();', '')
            Chk ($mainJs -ceq $expected) 'MAIN_JS_DIFF_IS_EXACTLY_THE_DEFINITION_AND_THE_CALL_OF_handleFooter'
        }
    }
    return @($list.ToArray())
}
$staticReal = @(Eval-Static $master $mainJs $uiCss $accJs $accExists)
foreach ($c in $staticReal) { Write-Output ('FINDING static:' + $c) }

# --- Pagina di prova ---------------------------------------------------------------------------------------------------------------------
function Write-Doc([string]$directory, [hashtable]$override, [string]$extraScript, [string]$mode) {
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $directory 'css'), (Join-Path $directory 'js')
    foreach ($n in $sheetOrder) {
        $target = Join-Path $directory ('css/' + $n)
        if ($override.ContainsKey('css/' + $n)) { [IO.File]::WriteAllText($target, $override['css/' + $n], (New-Object Text.UTF8Encoding($false))) }
        else { Copy-Item -LiteralPath (Join-Path $assets ('css/' + $n)) -Destination $target -Force }
    }
    $scripts = @('jquery.min.js', 'main.js')
    if ($accExists -and $mode -cne 'noscript') { $scripts += 'ks-footer-accordion.js' }
    foreach ($n in $scripts) {
        $target = Join-Path $directory ('js/' + $n)
        if ($override.ContainsKey('js/' + $n)) { [IO.File]::WriteAllText($target, $override['js/' + $n], (New-Object Text.UTF8Encoding($false))) }
        else { Copy-Item -LiteralPath (Join-Path $assets ('js/' + $n)) -Destination $target -Force }
    }
    $links = ($sheetOrder | Where-Object { $_ -ne 'theme-overrides.css' } | ForEach-Object { '<link rel="stylesheet" href="css/' + $_ + '" />' }) -join "`n"
    $tagList = @($scripts)
    if ($mode -ceq 'twice') { $tagList += 'ks-footer-accordion.js' }
    $tags = ($tagList | ForEach-Object { '<script src="js/' + $_ + '"></script>' }) -join "`n"
    $html = "<!doctype html><html lang=`"it`"><head><meta charset=`"utf-8`" /><meta name=`"viewport`" content=`"width=device-width, initial-scale=1`" />`n$links`n<link rel=`"stylesheet`" href=`"css/theme-overrides.css`" />`n<style id=`"ks-page-flags-injected`">$injectedCss</style>`n<style id=`"test-instant-scroll`">html{scroll-behavior:auto !important}</style>`n</head><body class=`"ks-page-home`"><form id=`"form1`">`n<div style=`"height:900px`">riempimento</div><button type=`"button`" id=`"ks-before`">prima</button>`n$footerHtml`n<button type=`"button`" id=`"ks-after`">dopo</button>`n<div style=`"height:200px`">fine</div></form>`n$tags`n$extraScript`n</body></html>"
    $path = Join-Path $directory 'index.html'
    [IO.File]::WriteAllText($path, $html, (New-Object Text.UTF8Encoding($false)))
    return $path
}

$setupJs = @'
(function(){
  window.__ksRaf = 0; (function f(){ window.__ksRaf++; requestAnimationFrame(f); })();
  window.__ksMq = 0; window.matchMedia('(max-width: 767px)').addEventListener('change', function(){ window.__ksMq++; });
  window.__ksSubmits = 0;
  document.getElementById('form1').addEventListener('submit', function(e){ window.__ksSubmits++; e.preventDefault(); });
  function parse(c){var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)};}
  function lin(v){v/=255; return v<=0.04045? v/12.92 : Math.pow((v+0.055)/1.055,2.4);}
  function lum(c){return 0.2126*lin(c.r)+0.7152*lin(c.g)+0.0722*lin(c.b);}
  function ratio(a,b){var x=lum(a),y=lum(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05);}
  function bgOf(el){var n=el; while(n && n.nodeType===1){var c=parse(getComputedStyle(n).backgroundColor); if(c && c.a>0.99) return c; n=n.parentElement;} return {r:255,g:255,b:255,a:1};}
  window.__ksFt = {
    snap: function(){
      var out=[]; var blocks=document.querySelectorAll('.footer-col-block');
      for(var i=0;i<blocks.length;i++){
        var b=blocks[i], h=b.querySelector('.footer-heading-mobile'), p=b.querySelector('.tf-collapse-content'), btn=h.querySelector('.ft-heading-toggle');
        var cs=getComputedStyle(p), r=p.getBoundingClientRect(), hr=h.getBoundingClientRect(), br=btn?btn.getBoundingClientRect():null, bcs=btn?getComputedStyle(btn):null, hcs=getComputedStyle(h);
        var parity=btn?['fontWeight','fontSize','fontFamily','lineHeight','letterSpacing','textTransform','textAlign','color'].filter(function(k){return bcs[k]!==hcs[k];}).join(','):'';
        var ctl=btn?btn.getAttribute('aria-controls'):null; var rg=document.createRange(); rg.selectNodeContents(btn||h); var tr=rg.getBoundingClientRect(); var ty=Math.round((tr.top+tr.height/2)-(hr.top+hr.height/2));
        out.push({text:h.textContent.replace(/\s+/g,' ').trim(), htag:h.tagName, hkids:h.children.length, hhtml:h.innerHTML, nbtn:h.querySelectorAll('button').length,
          btn:!!btn, btag:btn?btn.tagName:'', btype:btn?btn.getAttribute('type'):null, bexp:btn?btn.getAttribute('aria-expanded'):null, bctl:ctl,
          ctlOk:!!(ctl && document.getElementById(ctl)===p), bw:br?Math.round(br.width):0, bh:br?Math.round(br.height):0, hw:Math.round(hr.width), hh:Math.round(hr.height), ty:ty, parity:parity,
          bgBg:bcs?bcs.backgroundColor:'', bBorder:bcs?bcs.borderTopWidth:'', bDisplay:bcs?bcs.display:'', bAlign:bcs?bcs.textAlign:'',
          open:b.classList.contains('open'), disp:cs.display, shown:(cs.display!=='none' && r.height>0), pid:p.id, pstyle:p.getAttribute('style'), pnext:(h.nextElementSibling===p),
          links:p.querySelectorAll('a').length});
      }
      return JSON.stringify(out);
    },
    extra: function(){
      var f=document.querySelector('footer.tf-footer');
      return JSON.stringify({ariaAttrs:f.querySelectorAll('[aria-expanded],[aria-controls],[role],[tabindex]').length, toggles:f.querySelectorAll('.ft-heading-toggle').length,
        submits:window.__ksSubmits, scrollY:Math.round(window.scrollY), width:window.innerWidth, html:f.outerHTML});
    },
    active: function(){
      var a=document.activeElement; if(!a||a===document.body||a===document.documentElement) return JSON.stringify({body:true,id:'',tag:'',cls:'',href:'',text:'',inFooter:false,toggle:false,fv:false,oStyle:'',oWidth:0,ratio:0,clip:''});
      var f=document.querySelector('footer.tf-footer'), cs=getComputedStyle(a), r=a.getBoundingClientRect();
      var w=parseFloat(cs.outlineWidth)||0, off=parseFloat(cs.outlineOffset)||0, ext=off>=0? w+off : Math.max(0,w+off);
      var oc=parse(cs.outlineColor)||{r:0,g:0,b:0,a:0}, bg=bgOf(a.parentElement||a);
      var comp={r:oc.r*oc.a+bg.r*(1-oc.a),g:oc.g*oc.a+bg.g*(1-oc.a),b:oc.b*oc.a+bg.b*(1-oc.a)};
      var clip=''; var p=a.parentElement;
      while(p && p!==document.body && p!==document.documentElement){var pcs=getComputedStyle(p);
        if(/hidden|clip/.test(pcs.overflowX+pcs.overflowY)){var pr=p.getBoundingClientRect();
          if(r.left-ext<pr.left-0.5||r.top-ext<pr.top-0.5||r.right+ext>pr.right+0.5||r.bottom+ext>pr.bottom+0.5){clip=p.tagName.toLowerCase()+'.'+(typeof p.className==='string'?p.className:''); break;}}
        p=p.parentElement;}
      return JSON.stringify({body:false, id:a.id||'', tag:a.tagName.toLowerCase(), cls:(typeof a.className==='string'?a.className:''), href:a.getAttribute('href')||'', text:(a.textContent||'').replace(/\s+/g,' ').trim().slice(0,40),
        inFooter:!!(f&&f.contains(a)), toggle:a.classList.contains('ft-heading-toggle'), fv:a.matches(':focus-visible'), oStyle:cs.outlineStyle, oWidth:w, ratio:Math.round(ratio(comp,bg)*100)/100, clip:clip});
    },
    focusToggle: function(i){var t=document.querySelectorAll('.ft-heading-toggle')[i]; if(!t) return 'NONE'; t.scrollIntoView({block:'center',behavior:'instant'}); t.focus(); return 'OK';},
    focusBefore: function(){var b=document.getElementById('ks-before'); b.scrollIntoView({block:'center',behavior:'instant'}); b.focus(); return 'OK';},
    focusPanelLink: function(){var a=document.querySelector('footer.tf-footer .tf-collapse-content a[href^="condizioni-vendita.aspx"]'); if(!a) return 'NONE'; a.scrollIntoView({block:'center',behavior:'instant'}); a.focus(); return document.activeElement===a?'OK':'NOFOCUS';},
    iconPoint: function(i){var h=document.querySelectorAll('.footer-heading-mobile')[i]; h.scrollIntoView({block:'center',behavior:'instant'}); var r=h.getBoundingClientRect(); var ix=r.right-15.5, iy=r.top+r.height/2; var e=document.elementFromPoint(ix,iy); var hit=!e?'none':(e.classList.contains('footer-heading-mobile')?'footer-heading-mobile':e.tagName+'.'+(typeof e.className==='string'?e.className:'')); return JSON.stringify({ix:ix, iy:iy, rx:r.right-4, hit:hit});},
    errors: function(){return JSON.stringify((window.__ksErrors||[]).filter(function(e){return /ks-footer-accordion/.test(e)||/SyntaxError|Unexpected (token|end)/.test(e)||/handleFooter/.test(e);}));},
    indicator: function(){var h=document.querySelector('.footer-heading-mobile'); var bg=bgOf(document.body); var out={body:getComputedStyle(document.body).backgroundColor};
      ['::after','::before'].forEach(function(k){var c=parse(getComputedStyle(h,k).backgroundColor)||{r:0,g:0,b:0,a:0}; out[k]={bg:getComputedStyle(h,k).backgroundColor, alpha:c.a, ratio:Math.round(ratio(c,bg)*100)/100};});
      return JSON.stringify(out);}
  };
  return 1;
})()
'@

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-footer-acc-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$browser = $null

function Key([string]$name, [bool]$shift) {
    $null = Invoke-KsCdp $browser 'Page.bringToFront' @{}
    $mod = 0; if ($shift) { $mod = 8 }
    switch ($name) {
        'Tab' { $d = @{ type = 'rawKeyDown'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9; modifiers = $mod }; $u = @{ type = 'keyUp'; key = 'Tab'; code = 'Tab'; windowsVirtualKeyCode = 9; nativeVirtualKeyCode = 9; modifiers = $mod } }
        'Enter' { $d = @{ type = 'keyDown'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; nativeVirtualKeyCode = 13; text = "`r" }; $u = @{ type = 'keyUp'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; nativeVirtualKeyCode = 13 } }
        'Space' { $d = @{ type = 'keyDown'; key = ' '; code = 'Space'; windowsVirtualKeyCode = 32; nativeVirtualKeyCode = 32; text = ' ' }; $u = @{ type = 'keyUp'; key = ' '; code = 'Space'; windowsVirtualKeyCode = 32; nativeVirtualKeyCode = 32 } }
    }
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' $d
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' $u
}
function Js([string]$expr) { return (Invoke-KsJs $browser $expr) }
function JsJson([string]$expr) { return ((Invoke-KsJs $browser $expr) | ConvertFrom-Json) }
function Set-Width([int]$w, [int]$expectToggles = -1) {
    $null = Invoke-KsCdp $browser 'Page.bringToFront' @{}
    $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = $w; height = 844; deviceScaleFactor = 1; mobile = $false }
    Start-Sleep -Milliseconds 350
    # Il browser di prova puo rallentare i fotogrammi (pagina "hidden"): non si conta sul tempo, si aspetta l'effetto atteso (numero di button nel piede), al massimo 5 s.
    if ($expectToggles -ge 0) {
        $deadline = (Get-Date).AddSeconds(5)
        while ((Get-Date) -lt $deadline) {
            if ((Extra).toggles -eq $expectToggles) { break }
            Start-Sleep -Milliseconds 100
        }
    }
}
function Open-Fixture([string]$path, [int]$w) {
    Set-Width $w
    Open-KsUrl $browser ('file:///' + $path.Replace([string][char]92, '/'))
    $null = Js $setupJs
    $null = Invoke-KsCdp $browser 'Page.bringToFront' @{}
    Start-Sleep -Milliseconds 500
}
function Snap() {
    $r = @(JsJson 'window.__ksFt.snap()')
    if ($env:KS_FOOTER_TRACE) {
        $w = (Invoke-KsJs $browser 'window.innerWidth + "|" + (document.activeElement ? (document.activeElement.className || document.activeElement.tagName) : "none") + "|vis=" + document.visibilityState + "|raf=" + window.__ksRaf + "|mq=" + window.__ksMq')
        Write-Host ('TRACE w|active=' + $w + ' ' + (($r | ForEach-Object { $_.text.Substring(0, 3) + ':o' + [int]$_.open + 's' + [int]$_.shown + 'b' + [int]$_.btn + 'e' + $_.bexp }) -join ' '))
    }
    return $r
}
function Extra() { return (JsJson 'window.__ksFt.extra()') }
function Active() { return (JsJson 'window.__ksFt.active()') }
function Wait-Anim() {
    # Aspetta che jQuery abbia finito le animazioni (slideDown/slideUp), al massimo 5 s: non dipende dalla velocita dei fotogrammi del browser di prova.
    $null = Invoke-KsCdp $browser 'Page.bringToFront' @{}
    Start-Sleep -Milliseconds 150
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if ([int](Js 'window.jQuery ? window.jQuery(":animated").length : 0') -eq 0) { break }
        Start-Sleep -Milliseconds 80
    }
    Start-Sleep -Milliseconds 100
}

function Walk-Footer() {
    # Parte da #ks-before e preme Tab finche non arriva a #ks-after (o dopo 40 passi): elenco dei bersagli del piede.
    $null = Js 'window.__ksFt.focusBefore()'
    $rows = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt 40; $i++) {
        Key 'Tab' $false
        Start-Sleep -Milliseconds 70
        $a = Active
        if ($a.body) { continue }
        if ($a.id -ceq 'ks-after') { break }
        $rows.Add($a)
    }
    return @($rows.ToArray())
}

function Tree-Names() {
    # Albero di accessibilita di Chromium: heading e button del piede, e i link non ignorati.
    $res = Invoke-KsCdp $browser 'Accessibility.getFullAXTree' @{}
    $out = @{ headings = New-Object 'System.Collections.Generic.List[string]'; buttons = New-Object 'System.Collections.Generic.List[string]'; links = New-Object 'System.Collections.Generic.List[string]' }
    foreach ($n in $res['nodes']) {
        if ($n.ContainsKey('ignored') -and $n['ignored']) { continue }
        if (-not $n.ContainsKey('role')) { continue }
        $role = [string]$n['role']['value']
        $name = ''
        if ($n.ContainsKey('name') -and $n['name'].ContainsKey('value')) { $name = [string]$n['name']['value'] }
        $expanded = ''
        if ($n.ContainsKey('properties')) { foreach ($p in $n['properties']) { if ($p['name'] -ceq 'expanded') { $expanded = ([string]$p['value']['value']).ToLowerInvariant() } } }
        $level = ''
        if ($n.ContainsKey('properties')) { foreach ($p in $n['properties']) { if ($p['name'] -ceq 'level') { $level = [string]$p['value']['value'] } } }
        if ($role -ceq 'heading') { $out.headings.Add($name + '|' + $level) }
        elseif ($role -ceq 'button') { $out.buttons.Add($name + '|' + $expanded) }
        elseif ($role -ceq 'link') { $out.links.Add($name) }
    }
    return $out
}

$sectionNames = @('Supporto', 'Catalogo', 'Area cliente', 'Contatti')

# Esegue tutti gli scenari su una copia (eventualmente mutata) e restituisce l'elenco dei fallimenti. $fast = si ferma al primo.
$script:BaseH = $null
$script:BaseTy = $null
$script:BaseHtml = ''
function Run-Scenarios([string]$tag, [hashtable]$override, [string]$extraScript, [bool]$fast, [string]$mode = '') {
    $fails = New-Object 'System.Collections.Generic.List[string]'
    $dir = Join-Path $work $tag
    $path = Write-Doc $dir $override $extraScript $mode
    function Fail([string]$code) { $fails.Add($code); if ($fast) { throw 'FAST_STOP' } }
    try {
        if ($mode -ceq 'twice') {
            # Script incluso due volte: un solo ascoltatore (un Invio = una sola alternanza).
            Open-Fixture $path 390
            $null = Js 'window.__ksFt.focusToggle(0)'
            Key 'Enter' $false
            Wait-Anim
            $s = @(Snap)
            if (-not ($s[0].shown -and $s[0].open -and $s[0].bexp -ceq 'true' -and $s[0].nbtn -eq 1)) { Fail ('T_SCRIPT_INCLUDED_TWICE_STILL_TOGGLES_ONCE shown=' + $s[0].shown + ' exp=' + $s[0].bexp + ' buttons=' + $s[0].nbtn) }
            return @($fails.ToArray())
        }
        # Altezza e centratura dei titoli senza lo script (baseline per l'assenza di salti di layout): una volta sola sui file reali; con un ks-ui.css mutato, sul CSS mutato
        # (altrimenti una mutazione del CSS non potrebbe mai cambiare la baseline e resterebbe invisibile nello stato senza script).
        $ownBase = $override.ContainsKey('css/ks-ui.css')
        if ($ownBase -or $null -eq $script:BaseH) {
            $basePath = Write-Doc (Join-Path $work ('baseline-' + $tag)) $(if ($ownBase) { $override } else { @{} }) '' 'noscript'
            Open-Fixture $basePath 390
            $bh = @(Snap | ForEach-Object { $_.hh })
            $bty = @(Snap | ForEach-Object { $_.ty })
            Open-Fixture $basePath 1024
            $bhtml = (Extra).html
            if (-not $ownBase) { $script:BaseH = $bh; $script:BaseTy = $bty; $script:BaseHtml = $bhtml }
        }
        else { $bh = $script:BaseH; $bty = $script:BaseTy; $bhtml = $script:BaseHtml }
        # C. Caricamento a 1024 px: nulla modificato (DOM del server) - serve anche da riferimento per il ritorno a desktop.
        Open-Fixture $path 1024
        $d = @(Snap)
        $ex = Extra
        $serverHtml = $ex.html
        if ($serverHtml -cne $bhtml) { Fail 'C_DESKTOP_FOOTER_IDENTICAL_TO_THE_PAGE_WITHOUT_THE_SCRIPT' }
        if ($d.Count -ne 4) { Fail 'C_FOUR_SECTIONS' }
        $server = @{}
        foreach ($s in $d) {
            $server[$s.text] = $s.hhtml
            if ($s.hh -ge 40) { Fail ('C_DESKTOP_HEADING_KEEPS_ITS_HEIGHT:' + $s.text + ' ' + $s.hh) }
            if ($s.btn -or $s.hkids -ne 0) { Fail ('C_DESKTOP_HEADING_UNTOUCHED:' + $s.text) }
            if (-not $s.shown) { Fail ('C_DESKTOP_PANEL_VISIBLE:' + $s.text) }
            if ($s.open -or $s.pstyle -or $s.pid) { Fail ('C_DESKTOP_NO_RESIDUE:' + $s.text) }
        }
        if ($ex.ariaAttrs -ne 0) { Fail 'C_DESKTOP_NO_ARIA_OR_TABINDEX_IN_FOOTER' }
        $walk = @(Walk-Footer)
        $linkStops = @($walk | Where-Object { $_.tag -ceq 'a' })
        if (@($walk | Where-Object { $_.toggle }).Count -ne 0) { Fail 'C_DESKTOP_NO_TOGGLE_STOP' }
        $panelHrefs = @($walk | Where-Object { $_.href -like 'condizioni-vendita.aspx*' -or $_.href -like 'catalogo-*' -or $_.href -like 'myaccount.aspx' -or $_.href -like 'tel:*' })
        if ($panelHrefs.Count -lt 10) { Fail ('C_DESKTOP_ALL_PANEL_LINKS_REACHABLE:' + $panelHrefs.Count) }

        # A. Caricamento a 390 px
        Open-Fixture $path 390
        $m = @(Snap)
        if ($m.Count -ne 4) { Fail 'A_FOUR_SECTIONS' }
        for ($i = 0; $i -lt $m.Count; $i++) {
            $s = $m[$i]
            if ($s.htag -cne 'H6') { Fail ('A1_HEADING_STAYS_H6:' + $s.text) }
            if (-not $s.btn -or $s.nbtn -ne 1 -or $s.hkids -ne 1) { Fail ('A1_ONE_BUTTON_INSIDE_THE_HEADING:' + $s.text); continue }
            if ($s.btag -cne 'BUTTON' -or $s.btype -cne 'button') { Fail ('A1_BUTTON_TYPE_BUTTON:' + $s.text) }
            if ($s.bexp -cne 'false') { Fail ('A1_ARIA_EXPANDED_FALSE_WHEN_CLOSED:' + $s.text) }
            if (-not $s.ctlOk -or -not $s.pnext) { Fail ('A1_ARIA_CONTROLS_POINTS_TO_THE_SIBLING_PANEL:' + $s.text) }
            if ($s.shown -or $s.open) { Fail ('A1_PANEL_CLOSED_AT_START:' + $s.text) }
            if ($s.text -cne $sectionNames[$i]) { Fail ('A1_NAME_IS_THE_HEADING_TEXT:' + $s.text) }
            if ($s.bDisplay -cne 'flex' -or $s.bBorder -cne '0px' -or $s.bgBg -cne 'rgba(0, 0, 0, 0)') { Fail ('A1_BUTTON_RESET:' + $s.text) }
            if ([Math]::Abs($s.bw - $s.hw) -gt 2) { Fail ('A1_BUTTON_COVERS_THE_WHOLE_ROW_INCLUDING_THE_ICON:' + $s.text + ' bw=' + $s.bw + ' hw=' + $s.hw) }
            if ($s.parity) { Fail ('A1_BUTTON_TYPOGRAPHY_EQUALS_THE_HEADING:' + $s.text + ' differs=' + $s.parity) }
            if ($s.hh -ne $bh[$i]) { Fail ('A1_HEADING_HEIGHT_UNCHANGED_NO_LAYOUT_SHIFT:' + $s.text + ' ' + $s.hh + ' vs ' + $bh[$i]) }
            if ($s.hh -lt 44 -or $s.bh -lt 44 -or $s.bw -lt 44) { Fail ('A9_TOUCH_TARGET_AT_LEAST_44_PX:' + $s.text + ' row=' + $s.hw + 'x' + $s.hh + ' button=' + $s.bw + 'x' + $s.bh) }
            if ([Math]::Abs($s.bh - $s.hh) -gt 1) { Fail ('A9_BUTTON_FILLS_THE_ROW_HEIGHT:' + $s.text + ' button=' + $s.bh + ' row=' + $s.hh) }
            if ([Math]::Abs($s.ty) -gt 3) { Fail ('A9_TITLE_VERTICALLY_CENTERED_IN_THE_ROW:' + $s.text + ' offset=' + $s.ty) }
            if ([Math]::Abs($bty[$i]) -gt 3) { Fail ('A9_TITLE_CENTERED_EVEN_BEFORE_THE_SCRIPT_RUNS:' + $s.text + ' offset=' + $bty[$i]) }        }
        $errs = @(JsJson 'window.__ksFt.errors()')
        if ($errs.Count -gt 0) { Fail ('A_JS_ERRORS:' + ($errs -join ' ; ')) }
        $tree = Tree-Names
        $wantH = @($sectionNames | ForEach-Object { $_ + '|6' })
        $wantB = @($sectionNames | ForEach-Object { $_ + '|false' })
        if ((@($tree.headings | Where-Object { $wantH -contains $_ }).Count) -ne 4) { Fail ('A1_AX_FOUR_HEADINGS_LEVEL_6:' + ($tree.headings -join ',')) }
        if ((@($tree.buttons | Where-Object { $wantB -contains $_ }).Count) -ne 4) { Fail ('A1_AX_FOUR_BUTTONS_EXPANDED_FALSE:' + ($tree.buttons -join ',')) }
        if (@($tree.links | Where-Object { $_ -ceq 'Condizioni di vendita' }).Count -ne 0) { Fail 'A1_AX_CLOSED_PANEL_LINKS_HIDDEN' }

        # A2. Tab reale: logo, i 4 button, poi la barra bassa; mai un link di un pannello chiuso; anello visibile e non tagliato.
        $walk = @(Walk-Footer)
        $toggles = @($walk | Where-Object { $_.toggle })
        if ($toggles.Count -ne 4) { Fail ('A2_TAB_REACHES_THE_FOUR_BUTTONS:' + $toggles.Count) }
        else {
            for ($i = 0; $i -lt 4; $i++) { if ($toggles[$i].text -cne $sectionNames[$i]) { Fail ('A2_TAB_ORDER:' + $toggles[$i].text) } }
        }
        if (@($walk | Where-Object { $_.href -like 'catalogo-*' -or $_.href -like 'condizioni-vendita.aspx*' -or $_.href -like 'myaccount.aspx' -or $_.href -like 'tel:*' }).Count -ne 0) { Fail 'A2_TAB_NEVER_ENTERS_A_CLOSED_PANEL' }
        foreach ($t in $toggles) {
            if (-not $t.fv) { Fail ('A2_FOCUS_VISIBLE:' + $t.text) }
            if ($t.oStyle -ceq 'none' -or $t.oWidth -lt 2) { Fail ('A2_RING_PRESENT:' + $t.text + ' style=' + $t.oStyle + ' width=' + $t.oWidth) }
            if ($t.ratio -lt 3.0) { Fail ('A2_RING_CONTRAST:' + $t.text + ' ' + $t.ratio) }
            if ($t.clip) { Fail ('A2_RING_NOT_CLIPPED:' + $t.text + ' ' + $t.clip) }
        }

        # A3. Invio apre UNA volta; Tab entra nel pannello; Maiusc+Tab torna al button.
        $null = Js 'window.__ksFt.focusToggle(0)'
        Key 'Enter' $false
        Wait-Anim
        $s = @(Snap)
        $ex = Extra
        if (-not ($s[0].shown -and $s[0].open -and $s[0].bexp -ceq 'true')) { Fail ('A3_ENTER_OPENS_ONCE shown=' + $s[0].shown + ' open=' + $s[0].open + ' exp=' + $s[0].bexp) }
        if (@($s | Where-Object { $_.shown }).Count -ne 1) { Fail 'A3_ONLY_THE_ACTIVATED_SECTION_OPENS' }
        if ($ex.submits -ne 0) { Fail ('A3_NO_FORM_SUBMIT:' + $ex.submits) }
        $tree = Tree-Names
        if (@($tree.links | Where-Object { $_ -ceq 'Condizioni di vendita' }).Count -ne 1) { Fail 'A3_AX_OPEN_PANEL_LINKS_EXPOSED' }
        if (@($tree.buttons | Where-Object { $_ -ceq 'Supporto|true' }).Count -ne 1) { Fail 'A3_AX_BUTTON_EXPANDED_TRUE' }
        Key 'Tab' $false; Start-Sleep -Milliseconds 80
        $a = Active
        if (-not ($a.tag -ceq 'a' -and $a.href -like 'condizioni-vendita.aspx*')) { Fail ('A3_TAB_ENTERS_THE_OPEN_PANEL:' + $a.tag + ' ' + $a.href) }
        Key 'Tab' $true; Start-Sleep -Milliseconds 80
        $a = Active
        if (-not ($a.toggle -and $a.text -ceq 'Supporto')) { Fail 'A3_SHIFT_TAB_BACK_TO_THE_BUTTON' }

        # A4. Spazio chiude, senza scorrere la pagina.
        $before = Extra
        Key 'Space' $false
        Wait-Anim
        $s = @(Snap)
        $after = Extra
        if ($s[0].shown -or $s[0].open -or $s[0].bexp -cne 'false') { Fail ('A4_SPACE_CLOSES shown=' + $s[0].shown + ' exp=' + $s[0].bexp) }
        if ([Math]::Abs($after.scrollY - $before.scrollY) -gt 2) { Fail ('A4_SPACE_DOES_NOT_SCROLL:' + $before.scrollY + '->' + $after.scrollY) }
        Key 'Space' $false
        Wait-Anim
        $s = @(Snap)
        if (-not ($s[0].shown -and $s[0].bexp -ceq 'true')) { Fail 'A4_SPACE_OPENS' }
        Key 'Enter' $false
        Wait-Anim
        $s = @(Snap)
        if ($s[0].shown -or $s[0].bexp -cne 'false') { Fail 'A4_ENTER_CLOSES' }

        # A5. Due Invio ravvicinati: stato finale coerente (richiuso) e aria-expanded uguale alla visibilita reale.
        Key 'Enter' $false; Start-Sleep -Milliseconds 40; Key 'Enter' $false
        Start-Sleep -Milliseconds 900
        $s = @(Snap)
        foreach ($x in $s) { if (($x.bexp -ceq 'true') -ne $x.shown) { Fail ('A5_ARIA_MATCHES_VISIBILITY_AFTER_DOUBLE_ENTER:' + $x.text + ' exp=' + $x.bexp + ' shown=' + $x.shown) } }
        if ($s[0].shown) { Fail 'A5_TWO_TOGGLES_END_CLOSED' }

        # A6. Clic del mouse sull'area dell'icona (padding dell'h6): alterna UNA volta.
        # Due punti: il centro dell'icona (una linea di 1 px: il bersaglio e l'h6 stesso, non il button) e il bordo destro della riga (il button, che copre anche il padding).
        $pts = JsJson 'window.__ksFt.iconPoint(1)'
        if ($pts.hit -cne 'footer-heading-mobile') { Fail ('A6_SETUP_THE_ICON_POINT_TARGETS_THE_HEADING_ITSELF:' + $pts.hit) }
        foreach ($pt in @(@{ x = $pts.ix; y = $pts.iy }, @{ x = $pts.rx; y = $pts.iy })) {
            foreach ($state in @($true, $false)) {
                $null = Invoke-KsCdp $browser 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $pt.x; y = $pt.y; button = 'left'; clickCount = 1 }
                $null = Invoke-KsCdp $browser 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $pt.x; y = $pt.y; button = 'left'; clickCount = 1 }
                Wait-Anim
                $s = @(Snap)
                if ($s[1].shown -ne $state -or (($s[1].bexp -ceq 'true') -ne $state)) { Fail ('A6_MOUSE_CLICK_TOGGLES_ONCE x=' + $pt.x + ' want=' + $state + ' shown=' + $s[1].shown + ' exp=' + $s[1].bexp) }
            }
        }

        # A6b. Larghezza 390 -> 400 (resta sotto i 768 px): la sezione aperta resta aperta e il titolo non viene rifatto.
        $null = Js 'window.__ksFt.focusToggle(0)'
        Key 'Enter' $false
        Wait-Anim
        Set-Width 400 4
        Start-Sleep -Milliseconds 450
        $s = @(Snap)
        if (-not ($s[0].shown -and $s[0].open -and $s[0].bexp -ceq 'true' -and $s[0].nbtn -eq 1)) { Fail ('A6b_OPEN_SECTION_SURVIVES_A_RESIZE_INSIDE_THE_MOBILE_RANGE shown=' + $s[0].shown + ' exp=' + $s[0].bexp + ' buttons=' + $s[0].nbtn) }
        Key 'Enter' $false
        Wait-Anim
        Set-Width 390 4
        Start-Sleep -Milliseconds 300

        # A7. Focus sul button di una sezione aperta e allargamento a 1024 px: il DOM torna quello del server e il focus non va su body.
        $null = Js 'window.__ksFt.focusToggle(1)'
        Key 'Enter' $false
        Wait-Anim
        if (-not (@(Snap)[1].shown)) { Fail 'A7_SETUP_SECTION_OPEN' }
        Set-Width 1024 0
        Start-Sleep -Milliseconds 500
        $d = @(Snap)
        $ex = Extra
        foreach ($s in $d) {
            if ($s.btn -or $s.hkids -ne 0 -or $s.hhtml -cne $server[$s.text]) { Fail ('A7_HEADING_BACK_TO_THE_SERVER_DOM:' + $s.text) }
            if ($s.open -or $s.pstyle -or $s.pid) { Fail ('A7_NO_RESIDUE_AFTER_WIDENING:' + $s.text + ' open=' + $s.open + ' style=' + $s.pstyle + ' id=' + $s.pid) }
            if (-not $s.shown) { Fail ('A7_PANEL_VISIBLE_AT_DESKTOP:' + $s.text) }
        }
        if ($ex.ariaAttrs -ne 0) { Fail ('A7_NO_ARIA_RESIDUE_IN_FOOTER:' + $ex.ariaAttrs) }
        if ($ex.html -cne $serverHtml) { Fail 'A7_FOOTER_OUTERHTML_IDENTICAL_TO_THE_SERVER_AFTER_THE_CYCLE' }
        $a = Active
        if ($a.body -or -not $a.inFooter) { Fail 'A7_FOCUS_NOT_LOST_TO_BODY_WHEN_THE_BUTTON_DISAPPEARS' }

        # A8. Ritorno a 390 px: di nuovo chiuso e funzionante (il focus, che A7 ha lasciato su un link del pannello, si toglie prima: ristretta con il focus li dentro la sezione resta aperta, vedi A7c).
        $null = Js 'if (document.activeElement && document.activeElement.blur) { document.activeElement.blur(); } 1'
        Start-Sleep -Milliseconds 500
        Set-Width 390 4
        Start-Sleep -Milliseconds 500
        $s = @(Snap)
        foreach ($x in $s) { if (-not $x.btn -or $x.nbtn -ne 1 -or $x.shown -or $x.open -or $x.bexp -cne 'false') { Fail ('A8_RE_ENHANCED_CLOSED_AFTER_NARROWING:' + $x.text) } }
        $null = Js 'window.__ksFt.focusToggle(2)'
        Key 'Enter' $false
        Wait-Anim
        $s = @(Snap)
        if (-not ($s[2].shown -and $s[2].bexp -ceq 'true')) { Fail 'A8_WORKS_AGAIN_AFTER_NARROWING' }
        Key 'Enter' $false
        Wait-Anim

        # A7b. Allargamento MENTRE l'animazione e in corso (apertura, poi chiusura): nessuno stile residuo.
        $null = Js 'window.__ksFt.focusToggle(2)'
        Key 'Enter' $false
        Set-Width 1024 0
        Start-Sleep -Milliseconds 700
        if ((Extra).html -cne $serverHtml) { Fail 'A7b_WIDENING_DURING_THE_OPEN_ANIMATION_LEAVES_NO_RESIDUE' }
        Set-Width 390 4
        Start-Sleep -Milliseconds 450
        $null = Js 'window.__ksFt.focusToggle(2)'
        Key 'Enter' $false
        Wait-Anim
        Key 'Enter' $false
        Set-Width 1024 0
        Start-Sleep -Milliseconds 700
        if ((Extra).html -cne $serverHtml) { Fail 'A7b_WIDENING_DURING_THE_CLOSE_ANIMATION_LEAVES_NO_RESIDUE' }

        # A7c. Il focus e su un link di un pannello (desktop) e la finestra si restringe (zoom): la sezione resta aperta e il focus non va perso.
        if ((Js 'window.__ksFt.focusPanelLink()') -cne 'OK') { Fail 'A7c_SETUP_FOCUS_ON_A_PANEL_LINK' }
        Set-Width 390 4
        Start-Sleep -Milliseconds 600
        $a = Active
        $s = @(Snap)
        if ($a.body -or $a.href -notlike 'condizioni-vendita.aspx*') { Fail ('A7c_FOCUS_KEPT_ON_THE_PANEL_LINK_WHEN_NARROWING body=' + $a.body + ' href=' + $a.href) }
        if (-not ($s[0].shown -and $s[0].open -and $s[0].bexp -ceq 'true')) { Fail 'A7c_THE_SECTION_WITH_THE_FOCUS_IS_OPEN' }
        Set-Width 1024 0
        Start-Sleep -Milliseconds 500
        if ((Extra).html -cne $serverHtml) { Fail 'A7c_BACK_TO_THE_SERVER_DOM' }

        # A7c2. Come A7c, ma il focus e GIA stato tolto (focusout senza destinazione, come fa il browser) pochi ms prima dell'avviso del cambio: lo si riconosce e si rimette.
        if ((Js 'window.__ksFt.focusPanelLink()') -cne 'OK') { Fail 'A7c2_SETUP_FOCUS_ON_A_PANEL_LINK' }
        $null = Js 'document.activeElement.blur(); 1'
        Set-Width 390 4
        Start-Sleep -Milliseconds 600
        $a = Active
        $s = @(Snap)
        if ($a.body -or $a.href -notlike 'condizioni-vendita.aspx*') { Fail ('A7c2_FOCUS_RESTORED_ON_THE_LINK_THE_BROWSER_BLURRED body=' + $a.body + ' href=' + $a.href) }
        if (-not ($s[0].shown -and $s[0].open -and $s[0].bexp -ceq 'true')) { Fail 'A7c2_THE_SECTION_IS_REOPENED' }
        Set-Width 1024 0
        Start-Sleep -Milliseconds 500
        if ((Extra).html -cne $serverHtml) { Fail 'A7c2_BACK_TO_THE_SERVER_DOM' }

        # B. Limite 767 / 768.
        Set-Width 767 4
        Start-Sleep -Milliseconds 400
        if ((Extra).toggles -ne 4) { Fail 'B_AT_767_ENHANCED' }
        foreach ($x in @(Snap)) { if ($x.hh -lt 44) { Fail ('B_AT_767_TOUCH_TARGET:' + $x.text + ' ' + $x.hh) } }
        Set-Width 768 0
        Start-Sleep -Milliseconds 400
        if ((Extra).toggles -ne 0) { Fail 'B_AT_768_NOT_ENHANCED' }
        foreach ($x in @(Snap)) { if ($x.hh -ge 40) { Fail ('B_AT_768_HEADING_HEIGHT_UNCHANGED:' + $x.text + ' ' + $x.hh) } }
        if ((Extra).html -cne $serverHtml) { Fail 'B_AT_768_FOOTER_OUTERHTML_IDENTICAL_TO_THE_SERVER' }

        # D. Colori forzati: l'indicatore +/- non sparisce nello sfondo.
        Set-Width 390 4
        Start-Sleep -Milliseconds 300
        $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ features = @(@{ name = 'forced-colors'; value = 'active' }) }
        Start-Sleep -Milliseconds 400
        $ind = JsJson 'window.__ksFt.indicator()'
        $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ features = @(@{ name = 'forced-colors'; value = 'none' }) }
        foreach ($k in @('::after', '::before')) {
            $i2 = $ind.$k
            if ($i2.alpha -lt 0.99 -or $i2.ratio -lt 3.0) { Fail ('D_FORCED_COLORS_INDICATOR_VISIBLE ' + $k + ' bg=' + $i2.bg + ' alpha=' + $i2.alpha + ' ratio=' + $i2.ratio + ' page=' + $ind.body) }
        }
        $errs = @(JsJson 'window.__ksFt.errors()')
        if ($errs.Count -gt 0) { Fail ('Z_JS_ERRORS:' + ($errs -join ' ; ')) }
    }
    catch { if ($_.Exception.Message -cne 'FAST_STOP') { throw } }
    return @($fails.ToArray())
}

try {
    # Il browser non deve considerare la pagina nascosta o in background a meta prova (senza fotogrammi le animazioni e gli avvisi di cambio larghezza si fermano).
    try { $browser = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1024 -Height 844 -ExtraArgs '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling' }
    catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }
    $null = Invoke-KsCdp $browser 'Accessibility.enable' @{}
    # Errori JavaScript della pagina (si guardano solo quelli del nuovo script, i SyntaxError e un handleFooter non definito).
    $null = Invoke-KsCdp $browser 'Page.addScriptToEvaluateOnNewDocument' @{ source = "window.__ksErrors=[];window.addEventListener('error',function(e){window.__ksErrors.push((e.filename||'')+'|'+(e.message||''));});" }

    $real = @(Run-Scenarios 'real' @{} '' $false)
    foreach ($c in $staticReal) { $real += ('static:' + $c) }
    if ($real.Count -gt 0) {
        $real | ForEach-Object { Write-Output ('FINDING ' + $_) }
        throw ('FOOTER_ACCORDION_FAILS_THE_KEYBOARD_ORACLE findings=' + $real.Count)
    }
    Write-Output 'PASS REAL_FOOTER_ACCORDION_IS_OPERABLE_FROM_THE_KEYBOARD_AND_RESTORES_THE_SERVER_DOM_ON_DESKTOP'
    $twice = @(Run-Scenarios 'twice' @{} '' $false 'twice')
    if ($twice.Count -gt 0) { $twice | ForEach-Object { Write-Output ('FINDING ' + $_) }; throw 'SCRIPT_INCLUDED_TWICE_BREAKS_THE_ACCORDION' }
    Write-Output 'PASS SCRIPT_INCLUDED_TWICE_STILL_TOGGLES_ONCE'

    if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED_BY_SWITCH'; Write-Output 'FOOTER_ACCORDION_ALL_PASS_WITHOUT_MUTATIONS'; return }

    # --- Mutazioni: copie temporanee dei file reali (mai la copia di lavoro); ogni mutante deve essere rilevato, per il motivo giusto ---------------
    function Assert-Mut([string]$id, [hashtable]$override, [string]$extra, [string]$mode, [string]$mustContain) {
        $f = @(Run-Scenarios $id $override $extra $true $mode)
        if ($f.Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $id) }
        if ($mustContain -and -not (@($f | Where-Object { $_ -like ('*' + $mustContain + '*') }).Count)) { throw ('MUTATION_DETECTED_FOR_THE_WRONG_REASON=' + $id + ' wanted ' + $mustContain + ' got ' + ($f -join ' | ')) }
        Write-Output ('PASS MUTATION_DETECTED ' + $id + ' (' + $f[0].Substring(0, [Math]::Min(70, $f[0].Length)) + ')')
    }
    function Assert-StaticMut([string]$id, [string]$m, [string]$mainText, [string]$css, [string]$mustContain) {
        $f = @(Eval-Static $m $mainText $css $accJs $accExists)
        if ($f.Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $id) }
        if (-not (@($f | Where-Object { $_ -like ('*' + $mustContain + '*') }).Count)) { throw ('MUTATION_DETECTED_FOR_THE_WRONG_REASON=' + $id + ' wanted ' + $mustContain + ' got ' + ($f -join ' | ')) }
        Write-Output ('PASS MUTATION_DETECTED ' + $id + ' (' + $f[0] + ')')
    }
    $jsKey = 'js/ks-footer-accordion.js'
    $cssKey = 'css/ks-ui.css'
    Assert-Mut 'M01_aria_expanded_not_updated_on_toggle' @{ $jsKey = (Mutate-Text $accJs "    button.setAttribute('aria-expanded', open ? 'true' : 'false');`n    if (window.jQuery) {" "    if (window.jQuery) {" 'M01') } '' '' 'A3_ENTER_OPENS_ONCE'
    Assert-Mut 'M02_aria_controls_missing' @{ $jsKey = (Mutate-Text $accJs "    button.setAttribute('aria-controls', s.panel.id);`n" '' 'M02') } '' '' 'A1_ARIA_CONTROLS'
    Assert-Mut 'M03_button_without_type_button_would_submit_the_form' @{ $jsKey = (Mutate-Text $accJs "    button.setAttribute('type', 'button');" '' 'M03') } '' '' 'A1_BUTTON_TYPE_BUTTON'
    Assert-Mut 'M04_restore_does_not_unwrap_the_button' @{ $jsKey = (Mutate-Text $accJs "    while (button.firstChild) { s.heading.insertBefore(button.firstChild, button); }`n    s.heading.removeChild(button);`n" '' 'M04') } '' '' 'A7_'
    Assert-Mut 'M05_restore_keeps_the_open_class' @{ $jsKey = (Mutate-Text $accJs "    s.block.classList.remove('open');`n" '' 'M05') } '' '' 'A7_'
    Assert-Mut 'M06_restore_keeps_the_inline_style' @{ $jsKey = (Mutate-Text $accJs "    s.panel.removeAttribute('style');`n" '' 'M06') } '' '' 'A7_'
    Assert-Mut 'M07_breakpoint_768_instead_of_767' @{ $jsKey = (Mutate-Text $accJs "'(max-width: 767px)'" "'(max-width: 768px)'" 'M07') } '' '' 'B_AT_768'
    Assert-Mut 'M08_no_focus_rescue_when_the_button_disappears' @{ $jsKey = (Mutate-Text $accJs "      if (first && first.focus) { first.focus(); }`n" '' 'M08') } '' '' 'A7_FOCUS_NOT_LOST'
    $oldHandler = '<script>$(".footer-heading-mobile").on("click",function(){$(this).parent(".footer-col-block").toggleClass("open");if(!$(this).parent(".footer-col-block").is(".open")){$(this).next().slideUp({duration:250})}else{$(this).next().slideDown({duration:250})}});</script>'
    Assert-Mut 'M09_old_jquery_handler_back_two_mechanisms_toggle_twice' @{} $oldHandler '' 'A3_ENTER_OPENS_ONCE'
    Assert-Mut 'M11_forced_colors_rule_disabled' @{ $cssKey = (Mutate-Text $uiCss '@media (forced-colors: active){' '@media (forced-colors: none){' 'M11') } '' '' 'D_FORCED_COLORS'
    # border/border-radius/background del reset sono GIA dati dal tema (form button, button, Bootstrap): restano come difesa e la loro rimozione e equivalente (provato: non rilevabile). Si mutano le dichiarazioni efficaci.
    Assert-Mut 'M12a_button_display_block_removed' @{ $cssKey = (Mutate-Text $uiCss "  display: flex;`n  align-items: center;`n  align-self: stretch;`n  box-sizing: border-box;" "  box-sizing: border-box;" 'M12a') } '' '' 'A1_BUTTON_RESET'
    Assert-Mut 'M12b_button_text_align_inherit_removed' @{ $cssKey = (Mutate-Text $uiCss "  text-align: inherit;`n" '' 'M12b') } '' '' 'A1_BUTTON_TYPOGRAPHY'
    Assert-Mut 'M12c_button_color_inherit_removed' @{ $cssKey = (Mutate-Text $uiCss "  color: inherit;`n" '' 'M12c') } '' '' 'A1_BUTTON_TYPOGRAPHY'
    Assert-Mut 'M24_row_min_height_removed' @{ $cssKey = (Mutate-Text $uiCss "    min-height: 44px;`n" '' 'M24') } '' '' 'A9_TOUCH_TARGET'
    Assert-Mut 'M25_row_min_height_40_instead_of_44' @{ $cssKey = (Mutate-Text $uiCss 'min-height: 44px;' 'min-height: 40px;' 'M25') } '' '' 'A9_TOUCH_TARGET'
    Assert-Mut 'M26_44_px_row_also_at_768_to_991' @{ $cssKey = (Mutate-Text $uiCss "@media (max-width: 767px){`n  .ft-link-wrap .footer-heading-mobile{" "@media (max-width: 991px){`n  .ft-link-wrap .footer-heading-mobile{" 'M26') } '' '' 'B_AT_768_HEADING_HEIGHT_UNCHANGED'
    Assert-Mut 'M27_row_title_not_centered_without_the_script' @{ $cssKey = (Mutate-Text $uiCss "    align-items: center;`n    min-height: 44px;" "    min-height: 44px;" 'M27') } '' '' 'A9_TITLE_CENTERED_EVEN_BEFORE'
    Assert-Mut 'M28_button_does_not_stretch_to_the_row' @{ $cssKey = (Mutate-Text $uiCss "  align-self: stretch;`n" '' 'M28') } '' '' 'A9_TOUCH_TARGET'
    Assert-Mut 'M29_button_title_not_centered_in_the_row' @{ $cssKey = (Mutate-Text $uiCss "  display: flex;`n  align-items: center;`n  align-self: stretch;" "  display: flex;`n  align-self: stretch;" 'M29') } '' '' 'A9_TITLE_VERTICALLY_CENTERED'
    Assert-Mut 'M30_44_px_row_without_the_media_query_also_on_desktop' @{ $cssKey = (Mutate-Text $uiCss "@media (max-width: 767px){`n  .ft-link-wrap .footer-heading-mobile{" "@media (min-width: 1px){`n  .ft-link-wrap .footer-heading-mobile{" 'M30') } '' '' 'C_DESKTOP_HEADING_KEEPS_ITS_HEIGHT'
    Assert-Mut 'M31_row_is_block_not_flex' @{ $cssKey = (Mutate-Text $uiCss "    display: flex;`n    align-items: center;`n    min-height: 44px;" "    display: block;`n    align-items: center;`n    min-height: 44px;" 'M31') } '' '' 'A9_TOUCH_TARGET'
    Assert-Mut 'M13_double_load_guard_removed' @{ $jsKey = (Mutate-Text $accJs "  if (window.__ksFooterAccordion) { return; } // script incluso due volte: un solo ascoltatore`n" '' 'M13') } '' 'twice' 'T_SCRIPT_INCLUDED_TWICE'
    Assert-Mut 'M14_font_inherit_removed' @{ $cssKey = (Mutate-Text $uiCss "  font: inherit;`n" '' 'M14') } '' '' 'A1_BUTTON_TYPOGRAPHY'
    Assert-Mut 'M15_button_does_not_cover_the_icon_area' @{ $cssKey = (Mutate-Text $uiCss 'width: calc(100% + 20px);' 'width: 100%;' 'M15') } '' '' 'A1_BUTTON_COVERS'
    Assert-Mut 'M16_listener_only_on_the_button_icon_click_dead' @{ $jsKey = (Mutate-Text $accJs "node.classList.contains('footer-heading-mobile')) { heading = node; break; }" "node.classList.contains('ft-heading-toggle')) { heading = node.parentNode; break; }" 'M16') } '' '' 'A6_MOUSE'
    Assert-Mut 'M17_extra_keydown_handler_double_toggles' @{ $jsKey = (Mutate-Text $accJs "  if (mq.addEventListener) {" "  footer.addEventListener('keydown', function (e) { if ((e.key === 'Enter' || e.key === ' ') && e.target.classList && e.target.classList.contains('ft-heading-toggle')) { e.target.click(); } });`n  if (mq.addEventListener) {" 'M17') } '' '' 'A3_ENTER_OPENS_ONCE'
    Assert-Mut 'M18_resize_instead_of_change_and_not_idempotent' @{ $jsKey = (Mutate-Text (Mutate-Text $accJs "  if (mq.addEventListener) { mq.addEventListener('change', apply); } else if (mq.addListener) { mq.addListener(apply); }" "  window.addEventListener('resize', apply);" 'M18a') "    if (toggleOf(s.heading)) { return; } // idempotente`n" '' 'M18b') } '' '' 'A6b'
    Assert-Mut 'M19_restore_without_stopping_the_animation' @{ $jsKey = (Mutate-Text $accJs "    stopSlide(s.panel);`n    s.block" "    s.block" 'M19') } '' '' 'A7b'
    Assert-Mut 'M20_marker_attribute_left_on_the_panel' @{ $jsKey = (Mutate-Text $accJs "s.panel.removeAttribute('id'); s.panel.removeAttribute('data-ks-footer-id');" "s.panel.removeAttribute('id');" 'M20') } '' '' 'A7_FOOTER_OUTERHTML'
    Assert-Mut 'M21_no_keep_open_when_the_focus_was_lost_by_the_browser' @{ $jsKey = (Mutate-Text $accJs 's.panel.contains(document.activeElement) || !!lost' 's.panel.contains(document.activeElement)' 'M21') } '' '' 'A7c'
    Assert-Mut 'M23_restore_touches_the_desktop_dom_on_load' @{ $jsKey = (Mutate-Text $accJs "    var button = toggleOf(s.heading);`n    stopSlide(s.panel);" "    var button = toggleOf(s.heading);`n    s.panel.setAttribute('data-ks-touched', '1');`n    stopSlide(s.panel);" 'M23') } '' '' 'C_DESKTOP_FOOTER_IDENTICAL'
    $tag = 'ThemeManager.Asset("js/ks-footer-accordion.js") %>?v=20261116-footer-accordion1a"></script>'
    Assert-StaticMut 'S1_master_without_the_script_tag' (Mutate-Text $master ('<script src="<%= ' + $tag) '' 'S1') $mainJs $uiCss 'MASTER_LOADS_THE_SCRIPT'
    Assert-StaticMut 'S2_main_js_version_not_bumped' (Mutate-Text $master 'js/main.js") %>?v=20261116-footer-accordion1a"' 'js/main.js") %>?v=20260929-cart-authoritative-guard-1b-rev1"' 'S2') $mainJs $uiCss 'MASTER_BUMPED_THE_MAIN_JS_VERSION'
    Assert-StaticMut 'S3_ks_ui_link_without_a_version' (Mutate-Text $master 'ThemeManager.Asset("css/ks-ui.css") & "?v=20261116-footer-touch44a" %>' 'ThemeManager.Asset("css/ks-ui.css") %>' 'S3') $mainJs $uiCss 'MASTER_VERSIONS_THE_KS_UI_CSS_LINK'
    Assert-StaticMut 'S4_main_js_cut_removes_one_call_too_many' $master (Mutate-Text $mainJs 'infiniteSlide();' '' 'S4') $uiCss 'MAIN_JS_DIFF_IS_EXACTLY'
    Assert-StaticMut 'S5_main_js_still_calls_handleFooter' $master (Mutate-Text $mainJs 'totalPriceVariant();' 'totalPriceVariant();handleFooter();' 'S5') $uiCss 'MAIN_JS_HAS_NO_OLD_FOOTER_ACCORDION'
    Assert-StaticMut 'S6_ks_ui_without_the_forced_colors_block' $master $mainJs (Mutate-Text $uiCss '@media (forced-colors: active){' '@media (min-width: 1px){' 'S6') 'KS_UI_CSS_HAS_THE_BUTTON_RESET'

    Write-Output 'FOOTER_ACCORDION_ALL_PASS'
}
finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
