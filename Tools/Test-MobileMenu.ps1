[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# HOME-MOBILE-MENU-1A. Menu su telefono (#mobileMenu): pannello stretto con la pagina visibile dietro, testata "Menu" nel flusso,
# catalogo per primo con righe compatte e freccia, barra dei servizi (Offerte, Account, Wishlist, Confronta) sempre visibile,
# "Tutto in <nome>" in cima a ogni livello. La logica dei livelli (ks-page-flags.js) non cambia.
# Prova sul sito LAB (https, 127.0.0.1, porta 18843) a 360 / 390 / 430 px con il menu aperto davvero; a 1280 px le regole non valgono.
# Mutazioni sulla copia LAB, file rimessi alla fine. Sola lettura sul database. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('Page.master', 'Public\ui\controls\SiteHeader.ascx', 'Public\assets\keepstore\css\mobile-menu.css')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('MOBILE_MENU FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('MOBILE_MENU FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

$stateJs = @'
(function(){
var m=document.getElementById('mobileMenu');var W=window.innerWidth,H=window.innerHeight;
function vis(e){if(!e||!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden')return false;var b=e.getBoundingClientRect();return b.width>1&&b.height>1;}
function R(e){if(!e)return null;var r=e.getBoundingClientRect();return {l:Math.round(r.left),t:Math.round(r.top),w:Math.round(r.width),h:Math.round(r.height),b:Math.round(r.bottom)};}
function hit(e){var r=e.getBoundingClientRect();var p=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return !!p&&(p===e||e.contains(p));}
var o={open:m.classList.contains('show'),W:W,H:H,drawer:R(m)};
var bd=document.elementFromPoint(W-4,Math.round(H/2));o.backdropAtRight=!!bd&&bd.classList.contains('offcanvas-backdrop');
var head=m.querySelector('.ks-mobile-menu-head');o.head=head&&vis(head)?R(head):null;o.headPosition=head?getComputedStyle(head).position:'';
var title=document.getElementById('mobileMenuLabel');o.titleVisible=vis(title)&&title.getBoundingClientRect().width>20;o.titleText=title?title.textContent.trim():'';
o.close=R(m.querySelector('.btn-close-mb'));var logo=m.querySelector('.logo-site');o.logoVisible=vis(logo);
var tb=m.querySelector('.ks-mobile-catalog-toolbar');var tt=m.querySelector('.ks-mobile-catalog-title');var back=m.querySelector('.ks-mobile-catalog-back');
o.level=tt?tt.textContent.trim():'';o.backVisible=vis(back);
var rows=[];m.querySelectorAll('.ks-mobile-catalog-stage .collapse:not([hidden]) > ul > li > .sub-nav-link, #ks-mobile-catalog-root:not([hidden]) > ul > li > .sub-nav-link').forEach(function(e){if(!vis(e))return;var r=e.getBoundingClientRect();var sb=(m.querySelector('.mb-body')||m).getBoundingClientRect();if(r.bottom>Math.min(H,sb.bottom)||r.top<Math.max(0,sb.top))return;var lab=e.querySelector('.ks-mobile-nav-label')||e.querySelector('span')||e;var sub=e.querySelector('.btn-open-sub');var bf=sub?getComputedStyle(sub,'::before'):null,af=sub?getComputedStyle(sub,'::after'):null;
rows.push({t:(e.textContent||'').replace(/\s+/g,' ').trim().substring(0,40),h:Math.round(r.height),top:Math.round(r.top),labelLeft:Math.round(lab.getBoundingClientRect().left-m.getBoundingClientRect().left),cut:(e.scrollWidth>e.clientWidth+1),isButton:e.tagName==='BUTTON',href:e.getAttribute('href')||'',plus:!!sub&&bf.content!=='none'&&bf.content!=='normal',arrow:!!sub&&parseFloat(af.borderTopWidth)>=1.5,hit:hit(e)});});
o.rows=rows;
var bar=m.querySelector('.ks-mobile-utility-nav');o.barInScroll=!!(bar&&bar.closest('.mb-body'));var links=[];
if(bar)bar.querySelectorAll('a').forEach(function(a){if(!vis(a))return;var r=a.getBoundingClientRect();links.push({t:(a.textContent||'').replace(/\s+/g,' ').trim(),h:Math.round(r.height),top:Math.round(r.top),b:Math.round(r.bottom),cut:(a.scrollWidth>a.clientWidth+1),hit:hit(a),href:a.getAttribute('href')||'',icon:!!a.querySelector('i')});});
o.bar=links;o.active=document.activeElement?((document.activeElement.className&&document.activeElement.className.toString?document.activeElement.className.toString():'')+'#'+(document.activeElement.id||'')):'';
return JSON.stringify(o);})()
'@
function Read-Menu($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs))) }
function Open-Home($browser) {
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + '/Default.aspx') 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    $null = Invoke-KsJs $browser "(function(){var st=document.createElement('style');st.textContent='*,*::before,*::after{animation:none!important;transition:none!important}';document.head.appendChild(st);return 1;})()"
    Start-Sleep -Milliseconds 1200
}
function Open-Menu($browser) {
    Invoke-KsClick $browser 'button.mobile-button' -NoWait
    for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 250; if ([bool](Invoke-KsJs $browser "document.getElementById('mobileMenu').classList.contains('show')&&!document.getElementById('mobileMenu').classList.contains('showing')")) { break } }
    Start-Sleep -Milliseconds 500
}
# Tocca la prima riga-pulsante visibile del livello corrente e attende che il titolo cambi.
function Enter-First($browser) {
    $before = [string](Invoke-KsJs $browser "document.querySelector('#mobileMenu .ks-mobile-catalog-title').textContent.trim()")
    $name = [string](Invoke-KsJs $browser "(function(){var m=document.getElementById('mobileMenu');var l=[].slice.call(m.querySelectorAll('.ks-mobile-catalog-stage .collapse:not([hidden]) > ul > li > button.sub-nav-link')).filter(function(e){return e.getClientRects().length;});if(!l.length)return '';var lab=l[0].querySelector('.ks-mobile-nav-label')||l[0].querySelector('span');var t=(lab?lab.textContent:l[0].textContent).replace(/\s+/g,' ').trim();l[0].click();return t;})()")
    if ($name -eq '') { return '' }
    for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Milliseconds 250; if ([string](Invoke-KsJs $browser "document.querySelector('#mobileMenu .ks-mobile-catalog-title').textContent.trim()") -ne $before) { break } }
    Start-Sleep -Milliseconds 400
    return $name
}
function Go-Back($browser) {
    $before = [string](Invoke-KsJs $browser "document.querySelector('#mobileMenu .ks-mobile-catalog-title').textContent.trim()")
    $null = Invoke-KsJs $browser "document.querySelector('#mobileMenu .ks-mobile-catalog-back').click();1"
    for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Milliseconds 250; if ([string](Invoke-KsJs $browser "document.querySelector('#mobileMenu .ks-mobile-catalog-title').textContent.trim()") -ne $before) { break } }
    Start-Sleep -Milliseconds 400
}
function Test-Bar([string]$tag, $s) {
    $bad = New-Object Collections.Generic.List[string]
    $names = (@($s.bar) | ForEach-Object { [string]$_.t }) -join ', '
    if ($names -ne 'Offerte, Account, Wishlist, Confronta') { $bad.Add($tag + ' barra dei servizi: voci [' + $names + '] invece di Offerte, Account, Wishlist, Confronta') }
    if ([bool]$s.barInScroll) { $bad.Add($tag + ' barra dei servizi dentro l''area che scorre') }
    foreach ($l in @($s.bar)) {
        if ([int]$l.b -gt [int]$s.H -or [int]$l.top -lt 0) { $bad.Add($tag + ' barra dei servizi: ' + [string]$l.t + ' fuori dallo schermo') }
        if ([int]$l.h -lt 44) { $bad.Add($tag + ' barra dei servizi: ' + [string]$l.t + ' alta ' + [string]$l.h + ' px') }
        if ([bool]$l.cut) { $bad.Add($tag + ' barra dei servizi: ' + [string]$l.t + ' tagliata') }
        if (-not [bool]$l.hit) { $bad.Add($tag + ' barra dei servizi: ' + [string]$l.t + ' non risponde al tocco') }
        if (-not [bool]$l.icon) { $bad.Add($tag + ' barra dei servizi: ' + [string]$l.t + ' senza icona') }
    }
    return $bad
}
function Test-Rows([string]$tag, $s) {
    $bad = New-Object Collections.Generic.List[string]
    $rows = @($s.rows)
    if ($rows.Count -lt 3) { $bad.Add($tag + ' righe NON PROVATO: righe visibili ' + $rows.Count); return $bad }
    foreach ($r in $rows) {
        if ([int]$r.h -lt 44) { $bad.Add($tag + ' riga [' + [string]$r.t + '] alta ' + [string]$r.h + ' px'); break }
        if ([bool]$r.cut) { $bad.Add($tag + ' riga [' + [string]$r.t + '] tagliata'); break }
        if (-not [bool]$r.hit) { $bad.Add($tag + ' riga [' + [string]$r.t + '] non risponde al tocco'); break }
        if ([int]$r.labelLeft -gt 20) { $bad.Add($tag + ' riga [' + [string]$r.t + ']: rientro vuoto di ' + [string]$r.labelLeft + ' px'); break }
        if ([bool]$r.isButton -and ([bool]$r.plus -or -not [bool]$r.arrow)) { $bad.Add($tag + ' riga [' + [string]$r.t + ']: segno ' + $(if ($r.plus) { 'piu' } else { 'assente' }) + ' invece della freccia'); break }
    }
    return $bad
}

function Invoke-Width($browser, [int]$w) {
    $bad = New-Object Collections.Generic.List[string]
    $tag = [string]$w
    Open-Home $browser; Open-Menu $browser
    $s = Read-Menu $browser
    if (-not [bool]$s.open) { $bad.Add($tag + ' il menu non si apre'); return $bad }
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir ('menu-' + $w + '-1.png')) }
    $expect = [Math]::Round([Math]::Min(0.86 * $w, 360))
    if ([Math]::Abs([int]$s.drawer.w - $expect) -gt 2) { $bad.Add($tag + ' pannello largo ' + [string]$s.drawer.w + ' px invece di ' + $expect) }
    if (-not [bool]$s.backdropAtRight) { $bad.Add($tag + ' la pagina scurita non e visibile a destra del pannello') }
    if ($null -eq $s.head) { $bad.Add($tag + ' testata del menu assente') }
    else {
        if ([int]$s.head.h -lt 50 -or [int]$s.head.h -gt 64 -or [int]$s.head.t -ne 0) { $bad.Add($tag + ' testata alta ' + [string]$s.head.h + ' px a ' + [string]$s.head.t + ' px (attesi 50-64 px in cima)') }
        if ([string]$s.headPosition -ne 'static' -and [string]$s.headPosition -ne 'relative') { $bad.Add($tag + ' testata fuori dal flusso (' + [string]$s.headPosition + ')') }
    }
    if (-not [bool]$s.titleVisible -or [string]$s.titleText -ne 'Menu') { $bad.Add($tag + ' titolo "Menu" non visibile') }
    if ($null -eq $s.close -or [int]$s.close.w -lt 44 -or [int]$s.close.h -lt 44) { $bad.Add($tag + ' chiusura piu piccola di 44 x 44 px') }
    if ([bool]$s.logoVisible) { $bad.Add($tag + ' logo ancora visibile nel pannello') }
    if (@($s.rows).Count -gt 0 -and [int]@($s.rows)[0].top -gt 130) { $bad.Add($tag + ' primo settore a ' + [string]@($s.rows)[0].top + ' px dall''alto') }
    foreach ($b in (Test-Rows ($tag + ' settori') $s)) { $bad.Add($b) }
    foreach ($b in (Test-Bar ($tag + ' apertura') $s)) { $bad.Add($b) }
    # settore -> categorie
    $sector = Enter-First $browser
    $s2 = Read-Menu $browser
    if ($sector -eq '' -or [string]$s2.level -ne $sector) { $bad.Add($tag + ' livello: titolo [' + [string]$s2.level + '] invece di [' + $sector + ']') }
    if (-not [bool]$s2.backVisible) { $bad.Add($tag + ' livello: pulsante Indietro non visibile') }
    $all = @($s2.rows | Where-Object { -not [bool]$_.isButton })
    if ($all.Count -lt 1 -or [string]$all[0].t -ne ('Tutto in ' + $sector) -or [string]$all[0].href -eq '') { $bad.Add($tag + ' livello: prima voce [' + $(if ($all.Count) { [string]$all[0].t } else { '' }) + '] invece di [Tutto in ' + $sector + ']') }
    foreach ($b in (Test-Rows ($tag + ' categorie') $s2)) { $bad.Add($b) }
    foreach ($b in (Test-Bar ($tag + ' dentro un settore') $s2)) { $bad.Add($b) }
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir ('menu-' + $w + '-2.png')) }
    # categoria -> tipologie (se esiste nei dati) e ritorni
    $cat = Enter-First $browser
    $s3 = Read-Menu $browser
    if ($cat -eq '') { $bad.Add($tag + ' terzo livello NON PROVATO: nessuna categoria con tipologie nel primo settore') }
    else {
        if ([string]$s3.level -notlike ('*' + $cat)) { $bad.Add($tag + ' terzo livello: titolo [' + [string]$s3.level + ']') }
        $all3 = @($s3.rows | Where-Object { -not [bool]$_.isButton })
        if ($all3.Count -lt 1 -or [string]$all3[0].t -ne ('Tutto in ' + $cat)) { $bad.Add($tag + ' terzo livello: prima voce [' + $(if ($all3.Count) { [string]$all3[0].t } else { '' }) + ']') }
        Go-Back $browser
        if ([string](Read-Menu $browser).level -ne $sector) { $bad.Add($tag + ' Indietro dal terzo livello non torna al settore') }
    }
    Go-Back $browser
    $s4 = Read-Menu $browser
    if ([string]$s4.level -ne 'Catalogo' -or [bool]$s4.backVisible) { $bad.Add($tag + ' Indietro non torna all''elenco dei settori') }
    # Esc chiude e il fuoco torna al pulsante del menu
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'keyDown'; key = 'Escape'; code = 'Escape'; windowsVirtualKeyCode = 27 }
    $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = 'Escape'; code = 'Escape'; windowsVirtualKeyCode = 27 }
    Start-Sleep -Milliseconds 900
    $s5 = Read-Menu $browser
    if ([bool]$s5.open) { $bad.Add($tag + ' Esc non chiude il menu') } elseif ([string]$s5.active -notmatch 'mobile-button') { $bad.Add($tag + ' dopo Esc il fuoco non torna al pulsante del menu (' + [string]$s5.active + ')') }
    # il tocco sulla pagina scurita chiude
    Open-Menu $browser
    foreach ($t in @('mousePressed', 'mouseReleased')) { $null = Invoke-KsCdp $browser 'Input.dispatchMouseEvent' @{ type = $t; x = ($w - 6); y = 420; button = 'left'; clickCount = 1 } }
    Start-Sleep -Milliseconds 900
    if ([bool](Read-Menu $browser).open) { $bad.Add($tag + ' il tocco sulla pagina scurita non chiude il menu') }
    return $bad
}
function Invoke-Desktop($browser) {
    $bad = New-Object Collections.Generic.List[string]
    Open-Home $browser
    $r = ConvertFrom-Json ([string](Invoke-KsJs $browser "(function(){var m=document.getElementById('mobileMenu');var h=m.querySelector('.ks-mobile-menu-head');var b=m.querySelector('.ks-mobile-utility-nav');return JSON.stringify({w:getComputedStyle(m).width,head:h?getComputedStyle(h).minHeight:'',bar:b?getComputedStyle(b).display:''});})()"))
    if ([string]$r.head -eq '56px' -or [string]$r.bar -eq 'grid') { $bad.Add('1280 le regole del menu su telefono valgono anche su schermo grande (testata ' + [string]$r.head + ', barra ' + [string]$r.bar + ')') }
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
        if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $w + ' px') } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 10)) { Write-Host ('  FAIL ' + $b) } }
        Stop-KsBrowser $browser; $browser = $null
    }
    $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    $bad = @(Invoke-Desktop $browser)
    if ($bad.Count -eq 0) { Write-Host '  ok   1280 px' } else { $exit = 1; foreach ($b in $bad) { Write-Host ('  FAIL ' + $b) } }
    Stop-KsBrowser $browser; $browser = $null

    if (-not $SkipMutants -and $exit -eq 0) {
        $css = 'Public\assets\keepstore\css\mobile-menu.css'; $ascx = 'Public\ui\controls\SiteHeader.ascx'
        $mutants = @(
            @{ Id = 'M01_SHEET_NOT_LINKED'; File = 'Page.master'; W = 390; Expect = '390 pannello largo'; Old = 'css/mobile-menu.css'; New = 'css/mobile-menu-off.css' },
            @{ Id = 'M02_DRAWER_FULL_WIDTH'; File = $css; W = 390; Expect = '390 pannello largo'; Old = '    width: min(86vw, 360px);'; New = '    width: 100vw;' },
            @{ Id = 'M03_SERVICE_BAR_INSIDE_SCROLL'; File = $ascx; W = 390; Expect = '390 apertura barra dei servizi dentro'; Old = '<!-- ks-mobile-services -->'; New = '<div class="mb-body">' ; Wrap = $true },
            @{ Id = 'M04_OFFERS_NOT_IN_BAR'; File = $ascx; W = 390; Expect = '390 apertura barra dei servizi: voci'; Old = '<i class="icon-fire" aria-hidden="true"></i><span>Offerte</span>'; New = '<i class="icon-fire" aria-hidden="true"></i><span>Promo</span>' },
            @{ Id = 'M05_ROW_TOO_SHORT'; File = $css; W = 390; Expect = '390 settori riga'; Old = "  #mobileMenu .ks-mobile-primary-nav .sub-nav-link {`n    min-height: 48px;"; New = "  #mobileMenu .ks-mobile-primary-nav .sub-nav-link {`n    min-height: 0 !important; height: 30px !important; padding: 0 !important; overflow: hidden;" },
            @{ Id = 'M06_ARROW_RULE_REMOVED'; File = $css; W = 390; Expect = '390 settori riga'; Old = '.sub-nav-link > .btn-open-sub::before {'; New = '.sub-nav-link > .btn-open-sub-off::before {' },
            @{ Id = 'M07_NO_BREAKPOINT'; File = $css; W = 1280; Expect = '1280 le regole'; Old = '@media (max-width: 1199.98px) {'; New = '@media (min-width: 1px) {' },
            @{ Id = 'M08_VIEW_ALL_WITHOUT_NAME'; File = $ascx; W = 390; Expect = '390 livello: prima voce'; Old = "'>Tutto in <%# Server.HtmlEncode(Convert.ToString(Eval(""Descrizione""))) %></a></li><asp:Repeater ID=""rptNavCategorieMobile"""; New = "'>Vedi tutto il settore</a></li><asp:Repeater ID=""rptNavCategorieMobile""" },
            @{ Id = 'M09_EMPTY_IMAGE_SLOT_KEPT'; File = $css; W = 390; Expect = '390 settori riga'; Old = '  #mobileMenu .ks-mobile-nav-media.is-empty {'; New = '  #mobileMenu .ks-mobile-nav-media.is-empty-off {' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            if ($mu.ContainsKey('Wrap')) {
                # la lista dei servizi torna dentro l'area che scorre: si avvolge in un secondo contenitore .mb-body
                $mut = $src.Replace('<!-- ks-mobile-services -->', '<div class="mb-body">').Replace('<!-- /ks-mobile-services -->', '</div>')
            } else { $mut = $src.Replace($mu.Old, $mu.New) }
            Write-SiteText $mu.File $mut
            try {
                if ($mu.W -eq 1280) { $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900; $mb = @(Invoke-Desktop $browser) }
                else { $browser = Start-Phone $mu.W; $mb = @(Invoke-Width $browser $mu.W) }
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
if ($exit -eq 0) { Write-Host ('MOBILE_MENU PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (9 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'MOBILE_MENU FAIL' }
exit $exit
