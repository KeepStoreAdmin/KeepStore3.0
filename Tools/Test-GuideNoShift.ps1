[CmdletBinding()]
param([switch]$SkipMutations, [int[]]$Widths = @(360, 390, 430, 768, 800, 1440), [string]$Host1 = 'www.taikun.it', [int]$Port = 8443)

# KS-A04-GUIDE-CLS-1A - la sezione "guida agli acquisti" della HOME (#KsLocalAiSearch130) non cambia altezza quando parte il JavaScript.
# Difetto riprodotto: prima del bind la sezione era alta 589 px a 390 px (427 a 768, 424 a 1440) per il testo e i collegamenti di riserva, dopo 235 (225, 162): tutto cio che sta
# sotto saliva di 354 px (spostamento di layout a freddo 0,30 a 390 px, soglia "buono" 0,10).
# Oracolo (Edge su Smoke, sola lettura, Windows PowerShell 5.1 con Tools\KeepStoreBrowserDriver.ps1):
#  1. PRIMA/DOPO: con `ks-shopping-guide.js` bloccato (Network.setBlockedURLs) la sezione resta nello stato "non collegato"; senza blocco arriva a `data-ks-guide-bound`. Le due altezze
#     devono essere uguali entro 1 px a ogni larghezza (360/390/430/768/1440).
#  2. SPOSTAMENTO A FREDDO: somma di TUTTE le `layout-shift` (anche con hadRecentInput: in emulazione mobile arrivano tutte cosi) a 390 e 1440 px, cache disattivata, <= 0,02.
#  3. SENZA JAVASCRIPT (Emulation.setScriptExecutionDisabled): il modulo non si vede e restano visibili il testo di riserva, il collegamento al catalogo e "Contattaci".
#  4. PRIMA DEL BIND: nessun elemento del modulo e raggiungibile con la tastiera ne esposto a un lettore di schermo (visibility/inert/disabled, anche per `summary`).
#  5. DOPO IL BIND: l'altezza resta quella della stable (235/225/162 con modulo di 98 px) e il modulo e visibile e attivo.
# Mutazioni: le prime sul CSS sono applicate DENTRO la pagina (si riscrive il <style> marcato KS-A04-GUIDE-CLS-1A con lo script bloccato) e si rimisura lo stato prima del bind;
# le altre sono sul testo di Default.aspx (blocco <noscript>). Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$url = 'https://' + $Host1 + ':' + $Port + '/Default.aspx'
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$observer = @'
window.__ksLs = [];
try { new PerformanceObserver(function(list){ list.getEntries().forEach(function(e){ window.__ksLs.push(e.value); }); }).observe({ type: 'layout-shift', buffered: true }); } catch (x) {}
'@
$stateJs = @'
(function(){
  var r = document.getElementById('KsLocalAiSearch130'); if (!r) { return JSON.stringify({ missing: true }); }
  function box(sel){ var e = r.querySelector(sel); if (!e) { return null; } var b = e.getBoundingClientRect(); var s = getComputedStyle(e); return { h: Math.round(b.height), display: s.display, visibility: s.visibility }; }
  var f = r.querySelector('[data-ks-guide-fields]');
  var reach = [];
  if (f) { Array.prototype.forEach.call(f.querySelectorAll('input,button,select,textarea,summary,a[href],[tabindex]'), function(e){ var s = getComputedStyle(e); var hiddenByCss = (s.visibility === 'hidden') || (s.display === 'none'); var off = e.disabled === true || hiddenByCss || !!(e.closest && e.closest('[inert]')) || e.closest('fieldset:disabled') !== null && e.tagName !== 'SUMMARY'; reach.push(off ? 0 : 1); }); }
  return JSON.stringify({ iw: innerWidth, grid: matchMedia('(min-width:768px)').matches, h: Math.round(r.getBoundingClientRect().height * 10) / 10, bound: r.hasAttribute('data-ks-guide-bound'), failed: r.hasAttribute('data-ks-guide-failed'),
    fields: f ? box('[data-ks-guide-fields]') : null, idle: box('[data-ks-guide-idle]'), next: box('.ks-guide-next'), fallback: box('.ks-guide-fallback-departments'),
    catalog: box('a.ks-guide-catalog-fallback'), contact: box('[data-ks-guide-contact]'), reachableInsideFields: reach.reduce(function(a, b){ return a + b; }, 0) });
})()
'@

function Open-Guide([int]$width, [hashtable]$opt) {
    $h = 900; if ($width -lt 768) { $h = 844 }
    $b = Start-KsBrowser -LoopbackHosts @($Host1) -Width $width -Height $h -Mobile:($width -lt 768)
    $null = Invoke-KsCdp $b 'Network.enable' @{}
    $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true }
    # block = stato "prima del bind": ne lo script della guida ne home-default.js (che segna il guasto) girano; blockGuide = solo la guida (script assente con JavaScript acceso)
    if ($opt.ContainsKey('block') -and $opt.block) { $null = Invoke-KsCdp $b 'Network.setBlockedURLs' @{ urls = @('*ks-shopping-guide.js*', '*home-default.js*') } }
    if ($opt.ContainsKey('blockGuide') -and $opt.blockGuide) { $null = Invoke-KsCdp $b 'Network.setBlockedURLs' @{ urls = @('*ks-shopping-guide.js*') } }
    if ($opt.ContainsKey('noscript') -and $opt.noscript) { $null = Invoke-KsCdp $b 'Emulation.setScriptExecutionDisabled' @{ value = $true } }
    if ($opt.ContainsKey('observe') -and $opt.observe) { $null = Invoke-KsCdp $b 'Page.addScriptToEvaluateOnNewDocument' @{ source = $observer } }
    Open-KsUrl $b $url 180
    return $b
}
function Get-State($b) { return (ConvertFrom-Json (Invoke-KsJs $b $stateJs)) }
# dopo il bind la riserva sta nel <details> "Preferenze" (chiuso): aperto, deve essere visibile
function Get-StateWithPreferencesOpen($b) {
    $null = Invoke-KsJs $b "(function(){ var d = document.querySelector('#KsLocalAiSearch130 details[data-ks-guide-advanced]'); if (d) { d.open = true; } })()"
    return (Get-State $b)
}
function Wait-Bound($b) {
    for ($i = 0; $i -lt 120; $i++) {
        if ((Invoke-KsJs $b "!!document.querySelector('#KsLocalAiSearch130[data-ks-guide-bound]')") -eq $true) { return }
        Start-Sleep -Milliseconds 500
    }
    throw 'GUIDE_NEVER_BOUND'
}
function Wait-Settled($b) {
    $null = Invoke-KsJs $b 'new Promise(function(r){ setTimeout(r, 1500); })'
}
function Sum-Shifts($b) { return [double](Invoke-KsJs $b '(window.__ksLs || []).reduce(function(a, v){ return a + v; }, 0)') }

# --- 1 e 5: prima e dopo il bind, a ogni larghezza -------------------------------------------------------------------------------------------
$results = @{}
foreach ($w in $Widths) {
    $b = Open-Guide $w @{ block = $true }
    try { Wait-Settled $b; $pre = Get-State $b } finally { Stop-KsBrowser $b }
    $b = Open-Guide $w @{}
    try { Wait-Bound $b; Wait-Settled $b; $post = Get-State $b; $postOpen = Get-StateWithPreferencesOpen $b } finally { Stop-KsBrowser $b }
    $results[$w] = @{ pre = $pre; post = $post }
    # precondizione dei dati: il pannello dei reparti di riserva e renderizzato (altrimenti le mutazioni sui reparti non provano nulla)
    Assert-Source ($null -ne $pre.fallback) ('PRECONDITION_DEPARTMENTS_PANEL_RENDERED_' + $w)
    Assert-Source ((-not $post.failed) -and $post.bound) ('POST_STATE_NOT_MARKED_FAILED_' + $w)
    Assert-Source (($null -ne $postOpen.next) -and ($postOpen.next.h -gt 0) -and ($null -ne $postOpen.catalog) -and ($postOpen.catalog.h -gt 0)) ('POST_STATE_NEXT_PANEL_VISIBLE_IN_OPEN_PREFERENCES_' + $w)
    Write-Output ('INFO width=' + $w + ' innerWidth=' + $pre.iw + ' gridBreakpoint=' + $pre.grid + ' pre=' + $pre.h + ' post=' + $post.h + ' preBound=' + $pre.bound + ' postBound=' + $post.bound)
    Assert-Source (-not $pre.bound) ('PRE_STATE_IS_UNBOUND_' + $w)
    Assert-Source ($post.bound) ('POST_STATE_IS_BOUND_' + $w)
    Assert-Source ([math]::Abs($pre.h - $post.h) -le 1) ('SAME_HEIGHT_BEFORE_AND_AFTER_BIND_' + $w)
    Assert-Source (($null -ne $post.fields) -and ($post.fields.display -ne 'none') -and ($post.fields.visibility -eq 'visible') -and ($post.fields.h -ge 90)) ('BOUND_FORM_VISIBLE_' + $w)
    Assert-Source ($post.reachableInsideFields -ge 1) ('BOUND_FORM_HAS_REACHABLE_CONTROLS_' + $w)
    Assert-Source (($null -ne $pre.fields) -and ($pre.reachableInsideFields -eq 0)) ('PRE_STATE_NOTHING_REACHABLE_IN_FORM_' + $w)
    Assert-Source ((-not $pre.next) -or ($pre.next.display -eq 'none') -or ($pre.next.h -eq 0)) ('PRE_STATE_NO_FALLBACK_BLOCK_IN_FLOW_' + $w)
}
# i valori della stable dopo il bind (il layout a regime non cambia)
$expectPost = @{ 360 = 235; 390 = 235; 430 = 235; 768 = 225; 800 = 162; 1440 = 162 }
foreach ($w in $expectPost.Keys) { if ($results.ContainsKey($w)) { Assert-Source ([math]::Abs($results[$w].post.h - $expectPost[$w]) -le 2) ('BOUND_HEIGHT_UNCHANGED_FROM_STABLE_' + $w) } }

# --- 2: spostamento cumulativo a freddo -----------------------------------------------------------------------------------------------------
foreach ($w in @(390, 1440)) {
    if ($Widths -notcontains $w) { continue }
    $b = Open-Guide $w @{ observe = $true }
    try { Wait-Bound $b; Wait-Settled $b; $sum = Sum-Shifts $b } finally { Stop-KsBrowser $b }
    Write-Output ('INFO cold layout shift width=' + $w + ' total=' + [math]::Round($sum, 4))
    Assert-Source ($sum -le 0.02) ('COLD_LAYOUT_SHIFT_AT_MOST_0_02_' + $w)
}

# --- 3: senza JavaScript --------------------------------------------------------------------------------------------------------------------
foreach ($w in @(390, 1440)) {
    if ($Widths -notcontains $w) { continue }
    $b = Open-Guide $w @{ noscript = $true }
    try { $ns = Get-State $b } finally { Stop-KsBrowser $b }
    Assert-Source (($null -ne $ns.fields) -and (($ns.fields.display -eq 'none') -or ($ns.fields.h -eq 0))) ('NOSCRIPT_FORM_NOT_SHOWN_' + $w)
    Assert-Source (($null -ne $ns.idle) -and ($ns.idle.h -gt 0)) ('NOSCRIPT_IDLE_TEXT_VISIBLE_' + $w)
    Assert-Source (($null -ne $ns.catalog) -and ($ns.catalog.h -gt 0)) ('NOSCRIPT_CATALOG_LINK_VISIBLE_' + $w)
    Assert-Source (($null -ne $ns.contact) -and ($ns.contact.h -gt 0)) ('NOSCRIPT_CONTACT_LINK_VISIBLE_' + $w)
    Assert-Source (($null -ne $ns.fallback) -and ($ns.fallback.h -gt 0)) ('NOSCRIPT_DEPARTMENTS_VISIBLE_' + $w)
}
# --- 4: guasti (segnale data-ks-guide-failed) -----------------------------------------------------------------------------------------------
# 4a script della guida assente con JavaScript acceso (richiesta bloccata, home-default.js gira): la riserva torna visibile e il modulo sparisce
$b = Open-Guide 390 @{ blockGuide = $true }
try { Wait-Settled $b; $wd = Get-State $b } finally { Stop-KsBrowser $b }
Assert-Source ($wd.failed -and (-not $wd.bound)) 'MISSING_GUIDE_SCRIPT_MARKS_GUIDE_FAILED'
Assert-Source (($wd.fields.display -eq 'none') -and ($wd.next.h -gt 0) -and ($wd.idle.h -gt 0) -and ($wd.catalog.h -gt 0) -and ($wd.fallback.h -gt 0)) 'MISSING_GUIDE_SCRIPT_RESTORES_FALLBACK_AND_HIDES_FORM'
# 4b init lancia PRIMA del bind (eccezione vera nel codice reale: si toglie #ksGuideQuery appena inserito): il catch segna il guasto e ripristina la riserva
$tamper = @'
new MutationObserver(function(){ var e = document.getElementById('ksGuideQuery'); if (e && e.parentNode) { e.parentNode.removeChild(e); } }).observe(document, { childList: true, subtree: true });
'@
$h = 844
$b = Start-KsBrowser -LoopbackHosts @($Host1) -Width 390 -Height $h -Mobile
try {
    $null = Invoke-KsCdp $b 'Network.enable' @{}
    $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true }
    $null = Invoke-KsCdp $b 'Page.addScriptToEvaluateOnNewDocument' @{ source = $tamper }
    Open-KsUrl $b $url 180
    for ($i = 0; $i -lt 60; $i++) { if ((Invoke-KsJs $b "!!document.querySelector('#KsLocalAiSearch130[data-ks-guide-failed],#KsLocalAiSearch130[data-ks-guide-bound]')") -eq $true) { break }; Start-Sleep -Milliseconds 500 }
    Wait-Settled $b
    $ex = Get-State $b
    $nextInShell = [bool](Invoke-KsJs $b "!!document.querySelector('#KsLocalAiSearch130 .ks-ai130-shell > .ks-guide-next, #KsLocalAiSearch130 .ks-ai130-shell > * > .ks-guide-next')")
    $nextInDetails = [bool](Invoke-KsJs $b "!!document.querySelector('#KsLocalAiSearch130 [data-ks-guide-advanced-extra] .ks-guide-next')")
} finally { Stop-KsBrowser $b }
Assert-Source ($ex.failed -and (-not $ex.bound)) 'INIT_EXCEPTION_BEFORE_BIND_MARKS_FAILED_NOT_BOUND'
Assert-Source (($ex.fields.display -eq 'none') -and ($ex.next.h -gt 0) -and ($ex.idle.h -gt 0)) 'INIT_EXCEPTION_RESTORES_FALLBACK_AND_HIDES_FORM'
Assert-Source (($nextInShell) -and (-not $nextInDetails)) 'INIT_EXCEPTION_KEEPS_NEXT_PANEL_IN_THE_SHELL'
# 4c stato dopo il bind con modulo di nuovo nascosto (come lascia il catch dopo la riga 949): la regola del modulo non deve rimostrarlo
$b = Open-Guide 390 @{ block = $true }
try {
    $null = Invoke-KsJs $b "(function(){ var r = document.getElementById('KsLocalAiSearch130'); r.setAttribute('data-ks-guide-bound', '1'); var f = r.querySelector('[data-ks-guide-fields]'); f.hidden = true; f.disabled = true; })()"
    $bf = Get-State $b
} finally { Stop-KsBrowser $b }
Assert-Source (($bf.bound) -and ($bf.fields.display -eq 'none')) 'BOUND_THEN_HIDDEN_FORM_STAYS_HIDDEN'

# --- 5: mutazioni del CSS dentro la pagina (script bloccato: lo stato prima del bind riflette il CSS riscritto) ---------------------------------
function New-EditJs([string]$old, [string]$new) {
    return "(function(){ var ss = document.querySelectorAll('style'); for (var i = 0; i < ss.length; i++) { var t = ss[i].textContent; if (t.indexOf('KS-A04-GUIDE-CLS-1A') >= 0) { var o = " + (ConvertTo-Json $old -Compress) + "; if (t.indexOf(o) < 0) { return 'PATTERN_NOT_FOUND'; } ss[i].textContent = t.split(o).join(" + (ConvertTo-Json $new -Compress) + "); return 'OK'; } } return 'NO_MARKED_STYLE'; })()"
}
# dopo il bind, con "Preferenze" aperta: la riserva spostata nel <details> deve restare visibile anche con il CSS riscritto
function Get-PostStateWithEdit([int]$width, [string]$old, [string]$new) {
    $b = Open-Guide $width @{}
    try {
        Wait-Bound $b
        $r = Invoke-KsJs $b (New-EditJs $old $new)
        if ($r -ne 'OK') { throw ('MUTATION_NOT_APPLIED ' + $r) }
        Wait-Settled $b
        return (Get-StateWithPreferencesOpen $b)
    } finally { Stop-KsBrowser $b }
}
function Get-PreStateWithEdit([int]$width, [string]$old, [string]$new, [string]$pageScript) {
    $b = Open-Guide $width @{ block = $true }
    try {
        $r = Invoke-KsJs $b (New-EditJs $old $new)
        if ($r -ne 'OK') { throw ('MUTATION_NOT_APPLIED ' + $r) }
        if ($pageScript) { $null = Invoke-KsJs $b $pageScript }
        Wait-Settled $b
        return (Get-State $b)
    } finally { Stop-KsBrowser $b }
}
function Test-PreStateOk($s, $postHeight) {
    if ($null -eq $s.fields) { return $false }
    if ([math]::Abs($s.h - $postHeight) -gt 1) { return $false }
    if ($s.reachableInsideFields -ne 0) { return $false }
    if ($s.next -and $s.next.display -ne 'none' -and $s.next.h -gt 0) { return $false }
    if ($s.fallback -and $s.fallback.display -ne 'none' -and $s.fallback.h -gt 0) { return $false }
    return $true
}
if (-not $SkipMutations) {
    $w = 390
    $post = $results[$w].post.h
    $sel = '#KsLocalAiSearch130:not([data-ks-guide-bound]):not([data-ks-guide-failed])'
    # il punto di partenza (nessuna mutazione) deve passare, altrimenti le mutazioni non provano nulla
    $base = Get-PreStateWithEdit $w 'KS-A04-GUIDE-CLS-1A' 'KS-A04-GUIDE-CLS-1A' $null
    Assert-Source (Test-PreStateOk $base $post) 'MUTATION_BASELINE_PRE_STATE_OK'
    $m1 = Get-PreStateWithEdit $w 'display: block !important; visibility: hidden;' 'visibility: hidden;' $null
    Assert-Detected (Test-PreStateOk $m1 $post) 'M1_FORM_NOT_RESERVED'
    $m2 = Get-PreStateWithEdit $w 'display: block !important; visibility: hidden;' 'display: block !important;' $null
    Assert-Detected (Test-PreStateOk $m2 $post) 'M2_FORM_VISIBLE_AND_REACHABLE_BEFORE_BIND'
    $m3 = Get-PreStateWithEdit $w ($sel + ' .ks-guide-next { display: none; }') ($sel + ' .ks-guide-next { display: block; }') $null
    Assert-Detected (Test-PreStateOk $m3 $post) 'M3_NEXT_PANEL_IN_FLOW'
    $m4 = Get-PreStateWithEdit $w ($sel + ' .ks-guide-fallback-departments,') ($sel + ' .ks-guide-fallback-departments-x,') $null
    Assert-Detected (Test-PreStateOk $m4 $post) 'M4_DEPARTMENTS_IN_FLOW'
    $m5 = Get-PreStateWithEdit $w 'display: block !important; visibility: hidden;' 'display: block; visibility: hidden;' $null
    Assert-Detected (Test-PreStateOk $m5 $post) 'M5_NO_IMPORTANT_LOSES_TO_HIDDEN_RULE'
    # M6: senza l'esclusione :not([data-ks-guide-failed]) la riserva non torna dopo un guasto
    $m6 = Get-PreStateWithEdit $w ':not([data-ks-guide-failed])' '' "document.getElementById('KsLocalAiSearch130').setAttribute('data-ks-guide-failed','1')"
    Assert-Detected (($m6.next.h -gt 0) -and ($m6.fields.display -eq 'none')) 'M6_FAILED_DOES_NOT_RESTORE_FALLBACK'
    # M7: senza :not([data-ks-guide-bound]) il modulo che il catch ha rinascosto dopo il bind verrebbe rimostrato
    $m7 = Get-PreStateWithEdit $w ':not([data-ks-guide-bound])' '' "(function(){ var r = document.getElementById('KsLocalAiSearch130'); r.setAttribute('data-ks-guide-bound','1'); var f = r.querySelector('[data-ks-guide-fields]'); f.hidden = true; })()"
    Assert-Detected ($m7.fields.display -eq 'none') 'M7_BOUND_GUARD_MISSING_FORM_RESHOWN'
    # M8: senza :not([data-ks-guide-bound]) la riserva nascosta prima del bind resterebbe nascosta anche dentro "Preferenze" dopo il bind
    $m8 = Get-PostStateWithEdit $w ':not([data-ks-guide-bound])' ''
    Assert-Detected (($m8.next.h -gt 0) -and ($m8.catalog.h -gt 0)) 'M8_BOUND_GUARD_MISSING_NEXT_PANEL_STAYS_HIDDEN'
}

# --- 6: collegamento del segnale di guasto in home-default.js e blocco <noscript> (testo; la prova di comportamento sono i test 3 e 4) -------------
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace((Norm $old), (Norm $new))
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Test-JsWiring([string]$js) {
    $m = [regex]::Match($js, '(?s)function initShoppingGuide\(\) \{(.*?)\n  \}\n')
    if (-not $m.Success) { return $false }
    $body = $m.Groups[1].Value
    if ($body -notmatch "root\.setAttribute\('data-ks-guide-failed', '1'\)") { return $false }
    if ($body -notmatch "root\.removeAttribute\('data-ks-guide-failed'\)") { return $false }
    if ($body -notmatch "root\.hasAttribute\('data-ks-guide-bound'\)") { return $false }
    if ($body -notmatch '(?s)try \{.*KeepStoreShoppingGuide\.init\(root\);.*\} catch \(err\)') { return $false }
    # il segnale gira anche se i carosello o il menu lanciano
    if ($js -notmatch '(?s)try \{\s*initHomeSwipers\(\);\s*initDepartmentsMenu\(\);\s*\} finally \{\s*initShoppingGuide\(\);\s*\}') { return $false }
    return $true
}
function Test-NoscriptBlock([string]$aspx) {
    $m = [regex]::Match($aspx, '(?s)<noscript><style>(.*?)</style></noscript>\s*</asp:Content>')
    if (-not $m.Success) { return $false }
    $css = $m.Groups[1].Value
    $sel = '#KsLocalAiSearch130:not([data-ks-guide-bound]):not([data-ks-guide-failed])'
    if (-not $css.Contains($sel + ' [data-ks-guide-fields][hidden] { display: none !important; }')) { return $false }
    if (-not $css.Contains($sel + ' .ks-guide-fallback-departments,')) { return $false }
    if (-not $css.Contains($sel + ' .ks-guide-next { display: block; }')) { return $false }
    # sta nel capo (HeadContent), dopo il <style> principale
    $head = [regex]::Match($aspx, '(?s)<asp:Content ID="cntDiscoveryHead" ContentPlaceHolderID="HeadContent" runat="server">(.*?)</asp:Content>')
    if (-not $head.Success) { return $false }
    $h = $head.Groups[1].Value
    if ($h.IndexOf('<noscript><style>') -lt $h.IndexOf('</style>')) { return $false }
    return $true
}
$js = Read-Repo 'Public/assets/keepstore/js/home-default.js'
$aspx = Read-Repo 'Default.aspx'
Assert-Source (Test-JsWiring $js) 'HOME_DEFAULT_JS_MARKS_GUIDE_FAILED_IN_FINALLY'
Assert-Source (Test-NoscriptBlock $aspx) 'DEFAULT_ASPX_NOSCRIPT_BLOCK_RESTORES_FALLBACK'
Assert-Source ($aspx -match 'js/home-default\.js"\) & "\?v=20261116-guide-cls1a"') 'HOME_DEFAULT_JS_BUSTER_BUMPED'
Assert-Source (-not $js.Contains('window.setTimeout(function () { var r = document.getElementById(''KsLocalAiSearch130'')')) 'NO_TIME_BASED_WATCHDOG'
if (-not $SkipMutations) {
    Assert-Detected (Test-JsWiring (Mutate-Text $js "      else root.setAttribute('data-ks-guide-failed', '1');" '      else { }' 'J1')) 'J1_FAILED_NEVER_SET'
    Assert-Detected (Test-JsWiring (Mutate-Text $js "      if (root.hasAttribute('data-ks-guide-bound')) root.removeAttribute('data-ks-guide-failed');" "      if (false) root.removeAttribute('data-ks-guide-failed');" 'J2')) 'J2_FAILED_NEVER_CLEARED_BY_A_BIND'
    Assert-Detected (Test-JsWiring (Mutate-Text $js '    } finally {
      initShoppingGuide();
    }' '    } finally {
    }
    initShoppingGuide();' 'J3')) 'J3_GUIDE_INIT_NOT_IN_FINALLY'
    Assert-Detected (Test-JsWiring (Mutate-Text $js '    } catch (err) {
      if (window.console && console.warn) console.warn(''[KeepStore home] guide init error'', err);
    }' '    } finally { }' 'J4')) 'J4_INIT_EXCEPTION_NOT_CAUGHT'
    Assert-Detected (Test-NoscriptBlock (Mutate-Text $aspx '<noscript><style>' '<noscript><style data-x>' 'N1')) 'N1_NOSCRIPT_BLOCK_SHAPE_CHANGED'
    $sel = '#KsLocalAiSearch130:not([data-ks-guide-bound]):not([data-ks-guide-failed])'
    Assert-Detected (Test-NoscriptBlock (Mutate-Text $aspx ($sel + ' .ks-guide-next { display: block; }') ($sel + ' .ks-guide-next { display: none; }') 'N2')) 'N2_NOSCRIPT_DOES_NOT_RESTORE_NEXT_PANEL'
    Assert-Detected (Test-NoscriptBlock (Mutate-Text $aspx ($sel + ' [data-ks-guide-fields][hidden] { display: none !important; }') ($sel + ' [data-ks-guide-fields][hidden] { display: none; }') 'N3')) 'N3_NOSCRIPT_FORM_RULE_LOSES_THE_CASCADE'
}
Write-Output 'RESULT: ALL PASS'
