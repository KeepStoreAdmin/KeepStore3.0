[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$Article = '21906', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# PDP-LAYOUT-ORDER-1A. Scheda prodotto su telefono: Descrizione, Informazioni prodotto e Recensioni a scomparsa (linea di stile 3.6).
# Pulsante type=button dentro il titolo, aria-expanded, corpo hidden quando chiuso; prima sezione aperta; indice, stelle in alto,
# frammento dell'indirizzo ed esito della recensione aprono la sezione; in stampa, su schermo grande e senza JavaScript tutto aperto.
# Prova sul sito LAB (https, 127.0.0.1, porta 18843). L'invio della recensione e fatto a campi vuoti: il server lo rifiuta e non scrive.
# Mutazioni sulla copia LAB, file rimessi alla fine. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('articolo.aspx', 'Public\assets\keepstore\js\ks-pdp-collapsible.js', 'Public\assets\keepstore\css\ks-pdp-collapsible.css')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PDP_COLLAPSIBLE FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'articolo.aspx'))) { Write-Host ('PDP_COLLAPSIBLE FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
$page = '/articolo.aspx?id=' + $Article
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

$stateJs = @'
(function(){
function vis(e){if(!e||!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden'||s.display==='none')return false;var b=e.getBoundingClientRect();return b.width>1&&b.height>1;}
var o={H:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight),vh:innerHeight,path:location.pathname+location.search,hash:location.hash,marker:window.__ksTestMarker||0,sections:[]};
['prd-des','prd-infor','prd-review'].forEach(function(id){var s=document.getElementById(id);if(!s)return;var h=s.querySelector('.ks-pdp-section__title');var b=h?h.querySelector('button'):null;var body=s.querySelector('.ks-pdp-section__body');var hs=h?getComputedStyle(h):null,bs=b?getComputedStyle(b):null;var r=h?h.getBoundingClientRect():null;
o.sections.push({id:id,button:!!b,type:b?b.getAttribute('type'):'',expanded:b?b.getAttribute('aria-expanded'):'',controls:b?(!!b.getAttribute('aria-controls')&&document.getElementById(b.getAttribute('aria-controls'))===body):false,bodyVisible:vis(body),bodyHidden:body?body.hasAttribute('hidden'):false,bodyDisplay:body?getComputedStyle(body).display:'',text:body?(body.textContent||'').replace(/\s+/g,' ').trim().length:0,hSize:hs?hs.fontSize:'',hWeight:hs?hs.fontWeight:'',bSize:bs?bs.fontSize:'',bWeight:bs?bs.fontWeight:'',bFamily:bs?bs.fontFamily.split(',')[0].replace(/["']/g,'').trim():'',titleTop:r?Math.round(r.top):-1,headH:s.querySelector('.ks-pdp-section__head')?Math.round(s.querySelector('.ks-pdp-section__head').getBoundingClientRect().height):0});});
var m=document.querySelector('#prd-review .ks-review-message');o.message=m?{text:(m.textContent||'').replace(/\s+/g,' ').trim().substring(0,60),top:Math.round(m.getBoundingClientRect().top),visible:vis(m)}:null;
o.toggles=document.querySelectorAll('.ks-pdp-section__toggle').length;
return JSON.stringify(o);})()
'@
function Read-State($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs))) }
function Open-Page($browser, [string]$path) {
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + $path) 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    $null = Invoke-KsJs $browser "(function(){var st=document.createElement('style');st.textContent='*,*::before,*::after{animation:none!important;transition:none!important;scroll-behavior:auto!important}';document.head.appendChild(st);window.__ksTestMarker=1;return 1;})()"
    Start-Sleep -Milliseconds 1200
}
function Sec($s, [string]$id) { return @($s.sections | Where-Object { [string]$_.id -eq $id })[0] }
function Click-Toggle($browser, [string]$id) { $null = Invoke-KsJs $browser ("(function(){var b=document.querySelector('#" + $id + " .ks-pdp-section__title button');if(b){b.scrollIntoView({block:'center'});b.click();}return 1;})()"); Start-Sleep -Milliseconds 400 }
function Close-All($browser) { $null = Invoke-KsJs $browser "(function(){document.querySelectorAll('.ks-pdp-section__toggle[aria-expanded=true]').forEach(function(b){b.click();});return 1;})()"; Start-Sleep -Milliseconds 400 }

function Invoke-Phone($browser) {
    $bad = New-Object Collections.Generic.List[string]
    # A: stato iniziale
    Open-Page $browser $page
    $s = Read-State $browser
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir 'pdp-390-nuova.png') -FullPage }
    if (@($s.sections).Count -ne 3) { $bad.Add('A NON PROVATO: sezioni trovate ' + @($s.sections).Count + ' (serve un articolo con descrizione)'); return $bad }
    $i = 0
    foreach ($x in @($s.sections)) {
        if (-not [bool]$x.button -or [string]$x.type -ne 'button') { $bad.Add('A ' + [string]$x.id + ': pulsante type=button assente nel titolo'); $i++; continue }
        if (-not [bool]$x.controls) { $bad.Add('A ' + [string]$x.id + ': aria-controls non punta al corpo') }
        if ([string]$x.bSize -ne [string]$x.hSize -or [string]$x.bWeight -ne [string]$x.hWeight -or [string]$x.bFamily -ne 'Arial') { $bad.Add('A ' + [string]$x.id + ': stile del pulsante ' + [string]$x.bSize + ' / ' + [string]$x.bWeight + ' / ' + [string]$x.bFamily + ' diverso dal titolo ' + [string]$x.hSize + ' / ' + [string]$x.hWeight) }
        $wantOpen = ($i -eq 0)
        if (([string]$x.expanded -eq 'true') -ne $wantOpen -or [bool]$x.bodyVisible -ne $wantOpen) { $bad.Add('A ' + [string]$x.id + ': stato iniziale ' + $(if ($wantOpen) { 'chiuso invece di aperto' } else { 'aperto invece di chiuso' }) + ' (aria-expanded ' + [string]$x.expanded + ', corpo visibile ' + [string]$x.bodyVisible + ')') }
        if ([int]$x.text -lt 20) { $bad.Add('A ' + [string]$x.id + ': contenuto del corpo perso') }
        if ([int]$x.headH -lt 44) { $bad.Add('A ' + [string]$x.id + ': testata alta ' + [string]$x.headH + ' px') }
        $i++
    }
    if ($bad.Count -gt 0) { return $bad }
    $closedH = [int]$s.H
    # B: apertura e chiusura senza navigazione, col tocco e con Invio
    Click-Toggle $browser 'prd-infor'
    $b1 = Read-State $browser; $inf = Sec $b1 'prd-infor'
    if ([string]$inf.expanded -ne 'true' -or -not [bool]$inf.bodyVisible) { $bad.Add('B il tocco sul titolo non apre Informazioni') }
    if ([int]$b1.marker -ne 1 -or [string]$b1.path -ne $page) { $bad.Add('B il tocco sul titolo ha inviato o ricaricato la pagina') }
    $null = Invoke-KsJs $browser "document.querySelector('#prd-infor .ks-pdp-section__title button').focus();1"
    foreach ($t in @('keyDown', 'keyUp')) { $null = Invoke-KsCdp $browser 'Input.dispatchKeyEvent' @{ type = $t; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; text = $(if ($t -eq 'keyDown') { "`r" } else { '' }) } }
    Start-Sleep -Milliseconds 400
    $b2 = Read-State $browser
    if ([string](Sec $b2 'prd-infor').expanded -ne 'false' -or [bool](Sec $b2 'prd-infor').bodyVisible) { $bad.Add('B Invio sul pulsante non chiude Informazioni') }
    if ([int]$b2.marker -ne 1) { $bad.Add('B Invio sul pulsante ha inviato la pagina') }
    # tutte aperte: la pagina chiusa deve essere molto piu corta
    Click-Toggle $browser 'prd-infor'; Click-Toggle $browser 'prd-review'
    $openH = [int](Read-State $browser).H
    if ($openH - $closedH -lt 1500) { $bad.Add('B la pagina con le sezioni chiuse e piu corta di soli ' + ($openH - $closedH) + ' px (attesi almeno 1500)') }
    Close-All $browser
    # C: il tocco sulla riga di aiuto apre
    $hit = [string](Invoke-KsJs $browser "(function(){var l=document.querySelector('#prd-infor .ks-pdp-section__lead');if(!l)return 'assente';l.scrollIntoView({block:'center'});var r=l.getBoundingClientRect();var e=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);if(e){e.click();}return e?e.tagName:'';})()"); Start-Sleep -Milliseconds 400
    if ([string](Sec (Read-State $browser) 'prd-infor').expanded -ne 'true') { $bad.Add('C il tocco sulla riga di aiuto non apre la sezione (bersaglio ' + $hit + ')') }
    Close-All $browser
    # D: indice e stelle in alto aprono Recensioni e il titolo e in vista
    $null = Invoke-KsJs $browser "(function(){var a=document.querySelector('.ks-pdp-toc__link[href=`"#prd-review`"]');if(a){a.click();}return 1;})()"; Start-Sleep -Milliseconds 900
    $d1 = Read-State $browser; $rv = Sec $d1 'prd-review'
    if ([string]$rv.expanded -ne 'true' -or -not [bool]$rv.bodyVisible) { $bad.Add('D indice: Recensioni non aperta') }
    elseif ([int]$rv.titleTop -lt 0 -or [int]$rv.titleTop -gt [int]$d1.vh - 60) { $bad.Add('D indice: titolo di Recensioni fuori vista (' + [string]$rv.titleTop + ' px)') }
    Close-All $browser
    $top = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('a.ks-pdp-review-link, a[href=`"#prd-review`"]:not(.ks-pdp-toc__link)');if(!a)return 'assente';a.click();return 'ok';})()"); Start-Sleep -Milliseconds 900
    if ($top -eq 'assente') { $bad.Add('D stelle in alto NON PROVATO: collegamento alle recensioni assente') }
    elseif ([string](Sec (Read-State $browser) 'prd-review').expanded -ne 'true') { $bad.Add('D stelle in alto: Recensioni non aperta') }
    Close-All $browser
    # E: cambio del frammento
    $null = Invoke-KsJs $browser "location.hash='#prd-infor';1"; Start-Sleep -Milliseconds 700
    if ([string](Sec (Read-State $browser) 'prd-infor').expanded -ne 'true') { $bad.Add('E cambio del frammento: Informazioni non aperta') }
    # F: caricamento con il frammento
    # da una pagina vuota: dalla stessa scheda sarebbe solo un cambio di frammento (hashchange), non un caricamento
    Open-KsUrl $browser 'about:blank' 200
    Open-Page $browser ($page + '#prd-review')
    $f1 = Read-State $browser
    if ([string](Sec $f1 'prd-review').expanded -ne 'true') { $bad.Add('F caricamento con #prd-review: Recensioni non aperta') }
    # H: stampa
    Open-Page $browser $page
    $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = 'print' }
    try { Start-Sleep -Milliseconds 400; $h1 = Read-State $browser } finally { $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = '' } }
    $pi = Sec $h1 'prd-infor'
    if (-not [bool]$pi.bodyHidden) { $bad.Add('H stampa NON PROVATO: Informazioni non era chiusa') } elseif ([string]$pi.bodyDisplay -eq 'none') { $bad.Add('H stampa: il corpo di Informazioni resta nascosto') }
    # K: vero invio della recensione a campi vuoti (rifiutato dal server, nessuna scrittura): Recensioni aperta e messaggio in vista
    Open-Page $browser $page
    $sub = [string](Invoke-KsJs $browser "(function(){var b=document.querySelector('[id`$=btnReviewSubmit]');if(!b)return 'assente';['txtReviewName','txtReviewEmail','txtReviewTitle','txtReviewText'].forEach(function(n){var e=document.querySelector('[id`$='+n+']');if(e)e.value='';});b.click();return 'ok';})()")
    if ($sub -eq 'assente') { $bad.Add('K NON PROVATO: pulsante di invio della recensione assente') }
    else {
        Start-Sleep -Milliseconds 800; try { Wait-KsLoad $browser 120 } catch { }; Start-Sleep -Milliseconds 1800
        $k = Read-State $browser
        if ($null -eq $k.message) { $bad.Add('K NON PROVATO: dopo l''invio a campi vuoti il server non ha scritto un esito') }
        else {
            if ([string](Sec $k 'prd-review').expanded -ne 'true' -or -not [bool]$k.message.visible) { $bad.Add('K dopo l''invio: Recensioni chiusa, esito non visibile') }
            elseif ([int]$k.message.top -lt 0 -or [int]$k.message.top -gt [int]$k.vh - 30) { $bad.Add('K dopo l''invio: esito fuori vista (' + [string]$k.message.top + ' px)') }
        }
    }
    return $bad
}
function Invoke-Resize($browser) {
    $bad = New-Object Collections.Generic.List[string]
    # L: 390 -> 1280 -> 390
    Open-Page $browser $page
    $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = 1280; height = 900; deviceScaleFactor = 1; mobile = $false }; Start-Sleep -Milliseconds 1500
    $l1 = Read-State $browser
    if ([int]$l1.toggles -ne 0 -or @($l1.sections | Where-Object { -not [bool]$_.bodyVisible }).Count -ne 0) { $bad.Add('L a 1280 px restano pulsanti o sezioni chiuse (pulsanti ' + [string]$l1.toggles + ', corpi: ' + ((@($l1.sections) | ForEach-Object { [string]$_.id + '=' + [string]$_.bodyVisible + '/' + [string]$_.bodyDisplay }) -join ' ') + ')') }
    $null = Invoke-KsCdp $browser 'Emulation.setDeviceMetricsOverride' @{ width = 390; height = 844; deviceScaleFactor = 2; mobile = $true }; Start-Sleep -Milliseconds 1500
    $l2 = Read-State $browser
    if ([int]$l2.toggles -ne 3 -or @($l2.sections | Where-Object { [string]$_.expanded -ne 'true' }).Count -ne 0) { $bad.Add('L tornando a 390 px: pulsanti ' + [string]$l2.toggles + ', sezioni non tutte aperte') }
    return $bad
}
function Invoke-Desktop($browser) {
    $bad = New-Object Collections.Generic.List[string]
    Open-Page $browser $page
    $s = Read-State $browser
    if ([int]$s.toggles -ne 0) { $bad.Add('I 1280 px: pulsanti di sezione presenti') }
    if (@($s.sections | Where-Object { -not [bool]$_.bodyVisible }).Count -ne 0) { $bad.Add('I 1280 px: sezioni chiuse') }
    return $bad
}
function Invoke-NoScript($browser) {
    $bad = New-Object Collections.Generic.List[string]
    $null = Invoke-KsCdp $browser 'Emulation.setScriptExecutionDisabled' @{ value = $true }
    try {
        Open-KsUrl $browser ($base + $page) 300; Start-Sleep -Milliseconds 800
        $s = ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs))
        if ([int]$s.toggles -ne 0 -or @($s.sections | Where-Object { -not [bool]$_.bodyVisible }).Count -ne 0) { $bad.Add('J senza JavaScript: pulsanti presenti o sezioni chiuse') }
        if (@($s.sections).Count -lt 2) { $bad.Add('J senza JavaScript NON PROVATO') }
    } finally { $null = Invoke-KsCdp $browser 'Emulation.setScriptExecutionDisabled' @{ value = $false } }
    return $bad
}
function Start-Phone { return (Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 390 -Height 844 -Mobile) }
function Invoke-All {
    $out = New-Object Collections.Generic.List[string]
    $b = Start-Phone
    try { foreach ($x in (Invoke-Phone $b)) { $out.Add($x) }; foreach ($x in (Invoke-NoScript $b)) { $out.Add($x) } } finally { Stop-KsBrowser $b }
    $b = Start-Phone
    try { foreach ($x in (Invoke-Resize $b)) { $out.Add($x) } } finally { Stop-KsBrowser $b }
    $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    try { foreach ($x in (Invoke-Desktop $b)) { $out.Add($x) } } finally { Stop-KsBrowser $b }
    return $out
}

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
try {
    Sync-Site
    $bad = @(Invoke-All)
    if ($bad.Count -eq 0) { Write-Host '  ok   scheda prodotto: sezioni a scomparsa (390 px, senza JavaScript, 1280 px)' } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 14)) { Write-Host ('  FAIL ' + $b) } }
    if (-not $SkipMutants -and $exit -eq 0) {
        $js = 'Public\assets\keepstore\js\ks-pdp-collapsible.js'; $css = 'Public\assets\keepstore\css\ks-pdp-collapsible.css'
        $mutants = @(
            @{ Id = 'M01_BUTTON_SUBMITS_THE_FORM'; File = $js; Expect = 'A '; Old = "button.setAttribute('type', 'button');"; New = "button.setAttribute('type', 'submit');" },
            @{ Id = 'M02_ALL_CLOSED_AT_START'; File = $js; Expect = 'A prd-des: stato iniziale'; Old = 'var startOpen = wasWide || i === 0 || '; New = 'var startOpen = wasWide || ' },
            @{ Id = 'M03_LINKS_DO_NOT_OPEN'; File = $js; Expect = 'D indice'; Old = "    open(byId(href.slice(1)));"; New = "    void href;" },
            @{ Id = 'M04_HASHCHANGE_IGNORED'; File = $js; Expect = 'E cambio del frammento'; Old = "window.addEventListener('hashchange', function () { open(byId(hashId())); });"; New = "window.addEventListener('hashchange', function () { });" },
            @{ Id = 'M05_OUTCOME_FROM_GENERIC_ALERT'; File = $js; Expect = 'A prd-review: stato iniziale'; Old = "p.section.querySelector('.ks-review-message')"; New = "p.section.querySelector('.alert')" },
            @{ Id = 'M06_PRINT_RULE_REMOVED'; File = $css; Expect = 'H stampa: il corpo'; Old = '  .ks-pdp-section__body[hidden] {'; New = '  .ks-pdp-section__body-off[hidden] {' },
            @{ Id = 'M07_THRESHOLD_IGNORED'; File = $js; Expect = 'I 1280 px'; Old = "window.matchMedia('(max-width: 767.98px)')"; New = "window.matchMedia('(min-width: 1px)')" },
            @{ Id = 'M08_ARIA_EXPANDED_NOT_UPDATED'; File = $js; Expect = 'B il tocco sul titolo non apre'; Old = "    button.setAttribute('aria-expanded', open ? 'true' : 'false');"; New = "    if (!button.hasAttribute('aria-expanded')) { button.setAttribute('aria-expanded', open ? 'true' : 'false'); }" },
            @{ Id = 'M09_BUTTON_STYLE_NOT_INHERITED'; File = $css; Expect = 'A prd-des: stile del pulsante'; Old = '    font: inherit;'; New = '    font-off: inherit;' },
            @{ Id = 'M10_SCRIPT_NOT_INCLUDED'; File = 'articolo.aspx'; Expect = 'A prd-des: pulsante'; Old = 'js/ks-pdp-collapsible.js'; New = 'js/ks-pdp-collapsible-off.js' },
            @{ Id = 'M11_OUTCOME_NOT_BROUGHT_INTO_VIEW'; File = $js; Expect = 'K dopo l''invio'; Old = "    try { message.scrollIntoView({ block: 'center', behavior: 'instant' }); } catch (e) { /* non essenziale */ }"; New = "    void message;" },
            @{ Id = 'M12_FRAGMENT_AT_LOAD_IGNORED'; File = $js; Expect = 'F caricamento'; Old = 'i === 0 || p.id === wanted || '; New = 'i === 0 || ' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $src.Replace($mu.Old, $mu.New)
            try {
                $mb = @(Invoke-All)
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('PDP_COLLAPSIBLE PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (12 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'PDP_COLLAPSIBLE FAIL' }
exit $exit
