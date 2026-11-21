[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# HOME-MOBILE-HEADER-1A. Intestazione su telefono piu bassa, senza togliere funzioni: riga del logo 56 px con comandi da 44 x 44
# e nome accessibile, ricerca sempre visibile, tendina dell'ambito mostrata quando il riquadro ha il fuoco o un ambito e scelto,
# riga "Guida agli acquisti" conservata. Prova sul sito LAB (https, 127.0.0.1, porta 18843) a 360 / 390 / 430 px; a 1280 px nulla cambia.
# Mutazioni sulla copia LAB, file rimessi alla fine. Sola lettura sul database. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('Page.master', 'Public\ui\controls\SiteHeader.ascx', 'Public\assets\keepstore\css\mobile-menu.css')
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('MOBILE_HEADER FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

$stateJs = @'
(function(){
function vis(e){if(!e||!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden')return false;var b=e.getBoundingClientRect();return b.width>3&&b.height>3;}
function R(e){if(!e)return null;var r=e.getBoundingClientRect();return {l:Math.round(r.left),t:Math.round(r.top),r:Math.round(r.right),b:Math.round(r.bottom),w:Math.round(r.width),h:Math.round(r.height)};}
function hit(e){var r=e.getBoundingClientRect();var p=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return !!p&&(p===e||e.contains(p));}
function name(e){var a=e.getAttribute('aria-label');if(a&&a.trim())return a.trim();var t='';(function walk(n){n.childNodes.forEach(function(c){if(c.nodeType===3){t+=c.nodeValue;}else if(c.nodeType===1&&getComputedStyle(c).display!=='none'&&c.getAttribute('aria-hidden')!=='true'){walk(c);}});})(e);return t.replace(/\s+/g,' ').trim();}
var h=document.querySelector('header');var inner=document.querySelector('header .inner-header');var o={W:innerWidth,header:R(h),inner:R(inner),sx:document.documentElement.scrollWidth>document.documentElement.clientWidth+1};
var logo=[].slice.call(document.querySelectorAll('header .inner-header .logo-site img')).filter(vis)[0];o.logo=R(logo);
var acc=document.querySelector('header .nav-icon .nav-account a');var cart=document.querySelector('header .nav-icon .nav-cart a');var menu=document.querySelector('header button.mobile-button');
o.controls=[['area personale',acc],['carrello',cart],['menu',menu]].map(function(p){var e=p[1];return {id:p[0],ok:vis(e),rect:R(e),hit:e?hit(e):false,name:e?name(e):''};});
var cnt=cart?cart.querySelector('[data-ks-cart-count]'):null;o.counterInside=!!(cnt&&cart&&(function(){var a=cnt.getBoundingClientRect(),b=cart.getBoundingClientRect();return a.left>=b.left-1&&a.right<=b.right+1&&a.top>=b.top-1&&a.bottom<=b.bottom+1;})());
var area=document.querySelector('.ks-mobile-search-area');o.area=vis(area)?R(area):null;
var input=document.getElementById('tbCercaMobile');var sel=document.getElementById('product_cat_mobile');
o.input=vis(input)?R(input):null;var box=sel?(sel.closest('.select-category')||sel):null;o.selectVisible=vis(box)&&box.getBoundingClientRect().height>=30&&box.getBoundingClientRect().width>=100;o.selectRect=R(box);o.selectFont=sel?parseFloat(getComputedStyle(sel).fontSize):0;o.selectIndex=sel?sel.selectedIndex:-1;o.selectTab=sel?sel.tabIndex:-2;o.selectDisplay=sel?getComputedStyle(sel.closest('.select-category')||sel).display:'';
var g=document.querySelector('.ks-guide-mobile-entry a');o.guide=vis(g)?R(g):null;o.guideHref=g?g.getAttribute('href'):'';
return JSON.stringify(o);})()
'@
function Read-Header($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs))) }
function Open-Page($browser, [string]$path) {
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + $path) 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    Start-Sleep -Milliseconds 1500   # lo script della pagina aggiunge i suoi stili dopo il caricamento
}
function Test-Overlap($a, $b) { return -not ($a.r -le $b.l -or $b.r -le $a.l -or $a.b -le $b.t -or $b.b -le $a.t) }

function Invoke-Width($browser, [int]$w) {
    $bad = New-Object Collections.Generic.List[string]
    $tag = [string]$w
    $first = $true
    foreach ($p in @(@('home', '/Default.aspx'), @('elenco', '/articoli.aspx'), @('scheda', '/articolo.aspx?id=21906'), @('accesso', '/login.aspx'))) {
        Open-Page $browser $p[1]
        $s = Read-Header $browser
        if ($ShotDir -ne '' -and $first) { Save-KsScreenshot $browser (Join-Path $ShotDir ('header-' + $w + '.png')) }
        $t = $tag + ' ' + $p[0]
        if ([int]$s.header.h -gt 165) { $bad.Add($t + ': intestazione alta ' + [string]$s.header.h + ' px (attesi al massimo 165)') }
        if ([Math]::Abs([int]$s.inner.h - 56) -gt 2) { $bad.Add($t + ': riga del logo alta ' + [string]$s.inner.h + ' px invece di 56') }
        if ([bool]$s.sx) { $bad.Add($t + ': scorrimento orizzontale') }
        if ($null -eq $s.input -or [int]$s.input.h -lt 44 -or [int]$s.input.w -lt [int](0.65 * $w)) { $bad.Add($t + ': campo di ricerca non visibile o piccolo') }
        if ($null -eq $s.guide -or [int]$s.guide.h -lt 44 -or [string]$s.guideHref -notmatch 'KsLocalAiSearch130') { $bad.Add($t + ': riga della guida assente o bassa') }
        if ($first) {
            $first = $false
            if ($null -eq $s.logo) { $bad.Add($tag + ' logo non visibile') }
            $rects = @(); if ($null -ne $s.logo) { $rects += ,@('logo', $s.logo) }
            foreach ($c in @($s.controls)) {
                if (-not [bool]$c.ok) { $bad.Add($tag + ' comando ' + [string]$c.id + ' non visibile'); continue }
                if ([int]$c.rect.w -lt 44 -or [int]$c.rect.h -lt 44) { $bad.Add($tag + ' comando ' + [string]$c.id + ': area toccabile ' + [string]$c.rect.w + ' x ' + [string]$c.rect.h + ' px') }
                if (-not [bool]$c.hit) { $bad.Add($tag + ' comando ' + [string]$c.id + ' non risponde al tocco') }
                if ([string]$c.name -eq '' -or [string]$c.name -match '^\d+$') { $bad.Add($tag + ' comando ' + [string]$c.id + ' senza nome accessibile (' + [string]$c.name + ')') }
                $rects += ,@([string]$c.id, $c.rect)
            }
            for ($i = 0; $i -lt $rects.Count; $i++) { for ($j = $i + 1; $j -lt $rects.Count; $j++) { if (Test-Overlap $rects[$i][1] $rects[$j][1]) { $bad.Add($tag + ' ' + $rects[$i][0] + ' e ' + $rects[$j][0] + ' si sovrappongono') } } }
            if (-not [bool]$s.counterInside) { $bad.Add($tag + ' contatore del carrello fuori dal suo collegamento') }
            if ($null -ne $s.logo -and [int]$s.logo.h -gt 44) { $bad.Add($tag + ' logo alto ' + [string]$s.logo.h + ' px') }
            # tendina dell'ambito: a riposo nascosta ma nel documento e raggiungibile con Tab
            if ([bool]$s.selectVisible) { $bad.Add($tag + ' tendina dell''ambito visibile a riposo') }
            if ([string]$s.selectDisplay -eq 'none' -or [int]$s.selectTab -lt 0) { $bad.Add($tag + ' tendina dell''ambito tolta dalla tabulazione') }
            if ([Math]::Abs([double]$s.selectFont - 16) -gt 0.2) { $bad.Add($tag + ' tendina dell''ambito con corpo ' + [string]$s.selectFont + ' px invece di 16') }
            # fuoco nel campo: la tendina compare
            $null = Invoke-KsJs $browser "document.getElementById('tbCercaMobile').focus();1"; Start-Sleep -Milliseconds 400
            $f = Read-Header $browser
            if (-not [bool]$f.selectVisible) { $bad.Add($tag + ' tendina dell''ambito non visibile col fuoco nel campo') }
            elseif ([int]$f.selectRect.r -gt $w -or [int]$f.selectRect.l -lt 0) { $bad.Add($tag + ' tendina dell''ambito fuori dallo schermo') }
            # ambito scelto da script, fuoco tolto: resta visibile
            $null = Invoke-KsJs $browser "(function(){var s=document.getElementById('product_cat_mobile');s.selectedIndex=1;s.dispatchEvent(new Event('change',{bubbles:true}));document.activeElement.blur();return 1;})()"; Start-Sleep -Milliseconds 400
            $c1 = Read-Header $browser
            if (-not [bool]$c1.selectVisible) { $bad.Add($tag + ' tendina dell''ambito nascosta con un ambito scelto') }
            # ritorno alla prima voce: di nuovo nascosta
            $null = Invoke-KsJs $browser "(function(){var s=document.getElementById('product_cat_mobile');s.selectedIndex=0;s.dispatchEvent(new Event('change',{bubbles:true}));return 1;})()"; Start-Sleep -Milliseconds 400
            if ([bool](Read-Header $browser).selectVisible) { $bad.Add($tag + ' tendina dell''ambito visibile dopo il ritorno a tutti i settori') }
            # un negozio con un logo piu alto (quadrato): la riga del logo non deve crescere
            $null = Invoke-KsJs $browser "(function(){var i=[].slice.call(document.querySelectorAll('header .inner-header .logo-site img')).filter(function(e){return e.getClientRects().length;})[0];if(i){i.style.height='200px';i.style.width='200px';}return 1;})()"; Start-Sleep -Milliseconds 500
            $tall = Read-Header $browser
            if ([int]$tall.inner.h -gt 58) { $bad.Add($tag + ' logo alto: la riga del logo cresce a ' + [string]$tall.inner.h + ' px') }
            if ($ShotDir -ne '') { $null = Invoke-KsJs $browser "document.getElementById('tbCercaMobile').focus();1"; Start-Sleep -Milliseconds 400; Save-KsScreenshot $browser (Join-Path $ShotDir ('header-' + $w + '-fuoco.png')) }
        }
    }
    # elenco con un settore gia scelto dal server: la tendina resta visibile
    Open-Page $browser '/Default.aspx'
    $st = [string](Invoke-KsJs $browser "(function(){var s=document.getElementById('product_cat_mobile');return s&&s.options.length>1?s.options[1].value:'';})()")
    if ($st -eq '') { $bad.Add($tag + ' ambito NON PROVATO: la tendina ha una sola voce') }
    else {
        if ($st -notmatch '^/') { $st = '/' + $st }
        Open-Page $browser $st
        $e = Read-Header $browser
        if ([int]$e.selectIndex -gt 0 -and -not [bool]$e.selectVisible) { $bad.Add($tag + ' elenco con settore scelto: tendina nascosta') }
        if ([int]$e.selectIndex -le 0) { $bad.Add($tag + ' elenco con settore NON PROVATO: il server non ha scelto l''ambito (st=' + $st + ')') }
    }
    return $bad
}
function Invoke-Desktop($browser) {
    $bad = New-Object Collections.Generic.List[string]
    Open-Page $browser '/Default.aspx'
    $r = ConvertFrom-Json ([string](Invoke-KsJs $browser "(function(){var i=document.querySelector('header .inner-header');var s=getComputedStyle(i);var c=document.querySelector('.ks-header-ui .ks-search-shell .ks-search-category-select');return JSON.stringify({pad:s.paddingTop,font:c?getComputedStyle(c).fontSize:''});})()"))
    if ([string]$r.pad -eq '6px') { $bad.Add('1280 le regole dell''intestazione su telefono valgono anche su schermo grande (padding ' + [string]$r.pad + ')') }
    return $bad
}
function Start-Phone([int]$w) { return (Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $w -Height 844 -Mobile) }

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
$browser = $null
try {
    Sync-Site
    foreach ($w in @(360, 390, 430)) {
        $browser = Start-Phone $w
        $bad = @(Invoke-Width $browser $w)
        if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $w + ' px') } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 12)) { Write-Host ('  FAIL ' + $b) } }
        Stop-KsBrowser $browser; $browser = $null
    }
    $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    $bad = @(Invoke-Desktop $browser)
    if ($bad.Count -eq 0) { Write-Host '  ok   1280 px' } else { $exit = 1; foreach ($b in $bad) { Write-Host ('  FAIL ' + $b) } }
    Stop-KsBrowser $browser; $browser = $null

    if (-not $SkipMutants -and $exit -eq 0) {
        $css = 'Public\assets\keepstore\css\mobile-menu.css'; $ascx = 'Public\ui\controls\SiteHeader.ascx'
        $mutants = @(
            @{ Id = 'M01_LOGO_ROW_TALL_AGAIN'; File = $css; W = 390; Expect = '390 home: riga del logo'; Old = '    padding: 6px 0;'; New = '    padding: 15px 0;' },
            @{ Id = 'M02_TOUCH_TARGETS_REMOVED'; File = $css; W = 390; Expect = '390 comando area personale: area'; Old = "    min-width: 44px;`n    min-height: 44px;"; New = "    min-width: 0;`n    min-height: 0;" },
            @{ Id = 'M03_ACCESSIBLE_NAME_REMOVED'; File = $ascx; W = 390; Expect = '390 comando carrello senza nome'; Old = ' aria-label="Apri carrello" data-ks-mobile-cart'; New = ' data-ks-mobile-cart' },
            @{ Id = 'M04_COLUMNS_NOT_ADAPTED'; File = $css; W = 360; Expect = '360 '; Old = "    flex: 1 1 0;`n    width: auto;`n    min-width: 0;"; New = "    flex-off: 1;" },
            @{ Id = 'M05_LOGO_54_AGAIN'; File = $css; W = 390; Expect = '390 logo alto'; Old = '    max-height: 44px;'; New = '    max-height: 54px;' },
            @{ Id = 'M06_SCOPE_ALWAYS_HIDDEN'; File = $css; W = 390; Expect = '390 tendina dell''ambito non visibile col fuoco'; Old = '.ks-search-shell:not(:focus-within) .select-category:not(:has(option:checked:not(:first-child)))'; New = '.ks-search-shell .select-category:not(:has(option:checked:not(:first-child)))' },
            @{ Id = 'M07_SCOPE_STATE_FROM_INITIAL_ATTRIBUTE'; File = $css; W = 390; Expect = '390 tendina dell''ambito nascosta con un ambito scelto'; Old = ':has(option:checked:not(:first-child))'; New = ':has(option[selected]:not(:first-child))' },
            @{ Id = 'M08_SCOPE_FONT_13'; File = $css; W = 390; Expect = '390 tendina dell''ambito con corpo'; Old = '    font-size: 16px;   /* sotto i 16 px iOS ingrandisce la pagina */'; New = '    font-size: 13px;' },
            @{ Id = 'M09_SCOPE_REMOVED_FROM_TAB_ORDER'; File = $css; W = 390; Expect = '390 tendina dell''ambito tolta dalla tabulazione'; Old = '      clip-path: inset(50%);'; New = '      display: none;' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $src.Replace($mu.Old, $mu.New)
            try {
                $browser = Start-Phone $mu.W; $mb = @(Invoke-Width $browser $mu.W)
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { if ($browser) { Stop-KsBrowser $browser; $browser = $null }; Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('MOBILE_HEADER PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (9 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'MOBILE_HEADER FAIL' }
exit $exit
