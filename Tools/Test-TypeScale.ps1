[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# STYLE-TYPE-TITLES-1A. Un carattere e una scala dei titoli su tutto il sito (linea di stile 3.1):
# titolo di pagina 22 px (26 px da 992 px), titolo di sezione 20 px (24 px), peso 700; titolo della scheda delle occasioni 16 px;
# titolo delle schede blu anche in "spesso acquistati insieme"; un solo carattere, carrello e classi di titolo del tema compresi.
# Prova sul sito LAB (https, 127.0.0.1, porta 18843) con i file di lavoro, a 390 e 1280 px. Gli elementi attesi sono scelti per
# identita (tag visibile, id, posizione) e non con i selettori del foglio; un titolo atteso che manca e un fallimento.
# In stampa il titolo della scheda prodotto deve restare quello del foglio di pagina. Mutazioni sulla copia LAB, file rimessi alla fine.
# Sola lettura sul database (accesso dell'utente di prova per carrello e area cliente). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('Page.master', 'articolo.aspx', 'Public\assets\keepstore\css\type-scale.css')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('TYPE_SCALE FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('TYPE_SCALE FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }

# Legge gruppi di elementi scelti dal test. Ogni gruppo: nome -> elenco di {size, weight, color, fam, cut, minh, lh}.
$readJs = @'
(function(groups){
var cv=document.createElement('canvas');cv.width=cv.height=1;var cx=cv.getContext('2d',{willReadFrequently:true});
function hex(c){cx.clearRect(0,0,1,1);cx.fillStyle=c;cx.fillRect(0,0,1,1);var d=cx.getImageData(0,0,1,1).data;return ('#'+[d[0],d[1],d[2]].map(function(v){return ('0'+v.toString(16)).slice(-2);}).join('')).toUpperCase();}
function vis(e){if(!e.getClientRects().length)return false;var s=getComputedStyle(e);if(s.visibility==='hidden')return false;var b=e.getBoundingClientRect();if(!(b.width>1&&b.height>1))return false;var op=1,p=e;while(p&&p.nodeType===1){op*=parseFloat(getComputedStyle(p).opacity);p=p.parentElement;}return op>0.05;}
function fam(s){return s.fontFamily.split(',')[0].replace(/["']/g,'').trim();}
var out={};
Object.keys(groups).forEach(function(k){out[k]=[];var list;try{list=document.querySelectorAll(groups[k]);}catch(x){list=[];}
list.forEach(function(e){if(!vis(e))return;var s=getComputedStyle(e);out[k].push({size:Math.round(parseFloat(s.fontSize)*10)/10,weight:s.fontWeight,color:hex(s.color),fam:fam(s),cut:(e.scrollWidth>e.clientWidth+1),minh:Math.round(parseFloat(s.minHeight)||0),lh:Math.round((parseFloat(s.lineHeight)||0)*10)/10,t:(e.textContent||'').replace(/\s+/g,' ').trim().length});});});
var bad={};document.querySelectorAll('body *').forEach(function(e){if(!vis(e))return;var own='';e.childNodes.forEach(function(n){if(n.nodeType===3)own+=n.nodeValue;});if(!own.replace(/\s+/g,''))return;var f=fam(getComputedStyle(e));if(f!=='Arial'){bad[f]=(bad[f]||0)+1;}});
out.__fonts=Object.keys(bad).map(function(k){return k+' x'+bad[k];}).join(', ');
return JSON.stringify(out);})
'@
function Read-Groups($browser, [string]$path, [hashtable]$groups) {
    try { $null = Invoke-KsCdp $browser 'Network.enable' @{}; $null = Invoke-KsCdp $browser 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
    Open-KsUrl $browser ($base + $path) 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    # animazioni ferme: gli elementi rivelati dallo scorrimento non devono essere letti a meta dissolvenza
    $null = Invoke-KsJs $browser "(function(){var st=document.createElement('style');st.textContent='*,*::before,*::after{animation:none!important;transition:none!important}';document.head.appendChild(st);return 1;})()"
    $h = [int](Invoke-KsJs $browser 'Math.max(document.body.scrollHeight,document.documentElement.scrollHeight)')
    # Le sezioni con la classe wow restano nascoste finche lo script che le rivela non parte e non vede uno scorrimento:
    # si scorre tutta la pagina e si ripete finche nessuna e piu nascosta (al massimo cinque volte).
    for ($round = 0; $round -lt 5; $round++) {
        Start-Sleep -Milliseconds 500
        for ($y = 0; $y -lt $h; $y += 700) { $null = Invoke-KsJs $browser ('window.scrollTo({top:' + $y + ',behavior:"instant"});1'); Start-Sleep -Milliseconds 80 }
        $hidden = [int](Invoke-KsJs $browser "(function(){var n=0;document.querySelectorAll('.wow').forEach(function(e){if(e.getClientRects().length&&getComputedStyle(e).visibility==='hidden')n++;});return n;})()")
        if ($hidden -eq 0) { break }
    }
    $null = Invoke-KsJs $browser 'window.scrollTo({top:0,behavior:"instant"});1'; Start-Sleep -Milliseconds 900
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser ($readJs + '(' + (ConvertTo-Json $groups -Compress) + ')'))))
}
# Controlla un gruppo: numero di elementi e scala. $exact = numero esatto (0 = almeno $min).
function Test-Group([string]$case, $o, [string]$name, [int]$min, [int]$exact, [double]$size, [string]$weight) {
    $bad = New-Object Collections.Generic.List[string]
    $list = @($o.$name)
    if ($exact -gt 0 -and $list.Count -ne $exact) { $bad.Add($case + ' ' + $name + ': trovati ' + $list.Count + ', attesi ' + $exact); return $bad }
    if ($list.Count -lt $min) { $bad.Add($case + ' ' + $name + ' NON PROVATO: trovati ' + $list.Count + ', attesi almeno ' + $min); return $bad }
    foreach ($x in $list) {
        if ([Math]::Abs([double]$x.size - $size) -gt 0.2) { $bad.Add($case + ' ' + $name + ': corpo ' + [string]$x.size + ' invece di ' + $size) }
        if ($weight -ne '' -and [string]$x.weight -ne $weight) { $bad.Add($case + ' ' + $name + ': peso ' + [string]$x.weight + ' invece di ' + $weight) }
        if ([bool]$x.cut) { $bad.Add($case + ' ' + $name + ': titolo tagliato') }
        if ([double]$x.lh -gt 0 -and ([double]$x.lh -gt [double]$x.size * 1.6 -or [double]$x.lh -lt [double]$x.size * 1.1)) { $bad.Add($case + ' ' + $name + ': interlinea ' + [string]$x.lh + ' px per un corpo di ' + [string]$x.size + ' px') }
    }
    return $bad
}
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath (Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'))
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
function Enter-User($browser) {
    Open-KsUrl $browser ($base + '/login.aspx') 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { throw 'ORIGINE_INATTESA' }
    if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_tbPassword")')) {
        Set-KsValue $browser '#MainContent_tbUsername' 'PROVA'; Set-KsValue $browser '#MainContent_tbPassword' (Get-Secret); Invoke-KsClick $browser '#MainContent_btnLogin'
    }
}

$script:pdp = ''
# Un caso = una pagina. Restituisce i difetti con il prefisso del caso. $w = larghezza del browser.
function Invoke-Case([string]$case, $browser, [int]$w) {
    $bad = New-Object Collections.Generic.List[string]
    $page = if ($w -ge 992) { 26 } else { 22 }; $sec = if ($w -ge 992) { 24 } else { 20 }
    switch ($case) {
        'ELENCO' {
            $o = Read-Groups $browser '/articoli.aspx?inpromo=1' @{ pagina = 'main h1, h1'; link = '.card-product a.name-product' }
            foreach ($b in (Test-Group 'ELENCO' $o 'pagina' 1 1 $page '700')) { $bad.Add($b) }
            if ([string]$o.__fonts -ne '') { $bad.Add('ELENCO carattere diverso da quello del sito: ' + [string]$o.__fonts) }
            $script:pdp = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('.card-product a.name-product');return a?(a.getAttribute('href')||''):'';})()")
            if ($script:pdp -ne '' -and $script:pdp -notmatch '^/') { $script:pdp = '/' + $script:pdp }
        }
        'SCHEDA' {
            if ($script:pdp -eq '') { $script:pdp = '/articolo.aspx?id=21906' }
            $o = Read-Groups $browser $script:pdp @{ pagina = 'h1'; sezione = 'main h2, .ks-product-page h2'; insieme = '#prd-usually a.prd-name'; correlati = '#prd-similar a.name-product, #prd-related a.name-product' }
            foreach ($b in (Test-Group 'SCHEDA' $o 'pagina' 1 1 $page '700')) { $bad.Add($b) }
            foreach ($b in (Test-Group 'SCHEDA' $o 'sezione' 4 0 $sec '700')) { $bad.Add($b) }
            $ins = @($o.insieme)
            if ($ins.Count -lt 1) { $bad.Add('SCHEDA insieme NON PROVATO: nessun titolo in "spesso acquistati insieme"') }
            foreach ($x in $ins) { if ([string]$x.color -ne '#004EC3') { $bad.Add('SCHEDA insieme: titolo della scheda ' + [string]$x.color + ' invece del blu #004EC3') }; if ([double]$x.size -ne 14 -or [string]$x.weight -ne '600') { $bad.Add('SCHEDA insieme: titolo ' + [string]$x.size + ' / ' + [string]$x.weight + ' invece di 14 / 600') } }
            if ([string]$o.__fonts -ne '') { $bad.Add('SCHEDA carattere diverso da quello del sito: ' + [string]$o.__fonts) }
            # stampa: il titolo resta quello del foglio di pagina (15 pt = 20 px), non la scala dello schermo
            $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = 'print' }
            try { $pr = [double](Invoke-KsJs $browser "(function(){var e=document.querySelector('h1.product-info-name');return e?parseFloat(getComputedStyle(e).fontSize):0;})()") } finally { $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = '' } }
            if ([Math]::Abs($pr - 20) -gt 0.3) { $bad.Add('SCHEDA stampa: titolo ' + $pr + ' px invece dei 15 pt del foglio di pagina') }
        }
        'ACCESSO' {
            $o = Read-Groups $browser '/login.aspx' @{ pagina = 'h1'; sezione = 'main h2, .ks-login h2, h2.ks-login__title' }
            foreach ($b in (Test-Group 'ACCESSO' $o 'pagina' 1 1 $page '700')) { $bad.Add($b) }
            foreach ($b in (Test-Group 'ACCESSO' $o 'sezione' 1 0 $sec '700')) { $bad.Add($b) }
            if ([string]$o.__fonts -ne '') { $bad.Add('ACCESSO carattere diverso da quello del sito: ' + [string]$o.__fonts) }
        }
        'NEGATO' {   # pagina con le classi di titolo del tema (.h4): niente carattere con grazie
            $o = Read-Groups $browser '/accessonegato.aspx' @{ titolo = '#ksAccessDeniedTitle' }
            if (@($o.titolo).Count -ne 1) { $bad.Add('NEGATO NON PROVATO: titolo della pagina di accesso negato non trovato') } elseif ([string]@($o.titolo)[0].fam -ne 'Arial') { $bad.Add('NEGATO titolo con carattere ' + [string]@($o.titolo)[0].fam) }
            if ([string]$o.__fonts -ne '') { $bad.Add('NEGATO carattere diverso da quello del sito: ' + [string]$o.__fonts) }
        }
        'HOME' {
            $homeGroups = @{ sezione = '.ks-home-main h5:not(#ksHomeDirectCategoriesTitle)'; categorie = '#ksHomeDirectCategoriesTitle'; guida = '#ksGuideTitle'; occasioni = '.ks-deal-card a.name-product'; griglia = '.ks-grid-card a.name-product' }
            $o = Read-Groups $browser '/Default.aspx' $homeGroups
            # la HOME a volte arriva senza le sezioni dei prodotti (prima richiesta dopo un riavvio del sito): una seconda lettura
            if (@($o.occasioni).Count -lt 1 -or @($o.sezione).Count -lt 3) { Start-Sleep -Seconds 4; $o = Read-Groups $browser '/Default.aspx' $homeGroups }
            $list = @($o.sezione)
            if ($list.Count -lt 3) { $bad.Add('HOME sezione NON PROVATO: titoli di sezione trovati ' + $list.Count) }
            $okCount = @($list | Where-Object { [Math]::Abs([double]$_.size - $sec) -le 0.2 -and [string]$_.weight -eq '700' }).Count
            foreach ($x in $list) { if ([double]$x.lh -gt 0 -and ([double]$x.lh -gt [double]$x.size * 1.6 -or [double]$x.lh -lt [double]$x.size * 1.1)) { $bad.Add('HOME sezione: interlinea ' + [string]$x.lh + ' px per un corpo di ' + [string]$x.size + ' px'); break } }
            if ($okCount -ne $list.Count) { $bad.Add('HOME sezione: ' + ($list.Count - $okCount) + ' titoli di sezione fuori scala (' + (($list | ForEach-Object { [string]$_.size + '/' + [string]$_.weight } | Select-Object -Unique) -join ', ') + ')') }
            foreach ($b in (Test-Group 'HOME' $o 'guida' 1 1 $sec '700')) { $bad.Add($b) }
            $deal = @($o.occasioni)
            if ($deal.Count -lt 1) { $bad.Add('HOME occasioni NON PROVATO: ' + [string](Invoke-KsJs $browser "(function(){var l=document.querySelectorAll('.ks-deal-card a.name-product');var e=l[0];if(!e)return 'nessuna scheda delle occasioni nel documento; h5='+document.querySelectorAll('.ks-home-main h5').length+' stato='+document.readyState+' titolo='+document.title.substring(0,30)+' lunghezza='+document.body.innerHTML.length;var why='';var p=e;while(p&&p.nodeType===1){var cs=getComputedStyle(p);if(cs.display==='none'||cs.visibility==='hidden'||parseFloat(cs.opacity)<0.06){why=p.tagName+'.'+String(p.className).substring(0,50)+' display='+cs.display+' visibility='+cs.visibility+' opacity='+cs.opacity;break;}p=p.parentElement;}var r=e.getBoundingClientRect();return 'schede '+l.length+', prima '+Math.round(r.width)+'x'+Math.round(r.height)+' '+why;})()")) }
            foreach ($x in $deal) {
                if ([double]$x.size -ne 16 -or [string]$x.weight -ne '600' -or [string]$x.color -ne '#004EC3') { $bad.Add('HOME occasioni: titolo ' + [string]$x.size + ' / ' + [string]$x.weight + ' / ' + [string]$x.color + ' invece di 16 / 600 / #004EC3'); break }
                if ([double]$x.minh -gt [Math]::Ceiling(3 * [double]$x.lh) + 1) { $bad.Add('HOME occasioni: riserva di ' + [string]$x.minh + ' px per tre righe da ' + [string]$x.lh + ' px'); break }
            }
            foreach ($x in @($o.griglia)) { if ([double]$x.size -ne 14 -or [string]$x.weight -ne '600' -or [string]$x.color -ne '#004EC3') { $bad.Add('HOME griglia: titolo ' + [string]$x.size + ' / ' + [string]$x.weight + ' / ' + [string]$x.color); break } }
            if ([string]$o.__fonts -ne '') { $bad.Add('HOME carattere diverso da quello del sito: ' + [string]$o.__fonts) }
        }
        'CARRELLO' {
            $o = Read-Groups $browser '/carrello.aspx' @{ pagina = '.heading-section .heading'; consigli = '#ks-rv-title'; riepilogo = '.ks-summary-card .title' }
            foreach ($b in (Test-Group 'CARRELLO' $o 'pagina' 1 1 $page '700')) { $bad.Add($b) }
            foreach ($b in (Test-Group 'CARRELLO' $o 'riepilogo' 1 0 $sec '700')) { $bad.Add($b) }
            foreach ($b in (Test-Group 'CARRELLO' $o 'consigli' 1 1 $sec '700')) { $bad.Add($b) }
            if ([string]$o.__fonts -ne '') { $bad.Add('CARRELLO carattere diverso da quello del sito: ' + [string]$o.__fonts) }
        }
        'AREA' {
            $o = Read-Groups $browser '/myaccount.aspx' @{ pagina = '.ks-dashboard-hero h1' }
            foreach ($b in (Test-Group 'AREA' $o 'pagina' 1 1 $page '700')) { $bad.Add($b) }
            if ([string]$o.__fonts -ne '') { $bad.Add('AREA carattere diverso da quello del sito: ' + [string]$o.__fonts) }
        }
    }
    return $bad
}
function Start-Sized([int]$w) { if ($w -lt 700) { return (Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $w -Height 844 -Mobile) } else { return (Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $w -Height 900) } }
$anon = @('ELENCO', 'SCHEDA', 'ACCESSO', 'NEGATO', 'HOME'); $user = @('CARRELLO', 'AREA')

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
$browser = $null
try {
    Sync-Site
    foreach ($w in @(1280, 390)) {
        $browser = Start-Sized $w
        foreach ($case in $anon) {
            $bad = @(Invoke-Case $case $browser $w)
            if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $case + ' ' + $w) } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 8)) { Write-Host ('  FAIL ' + $w + ' ' + $b) } }
        }
        Enter-User $browser
        foreach ($case in $user) {
            $bad = @(Invoke-Case $case $browser $w)
            if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $case + ' ' + $w) } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 8)) { Write-Host ('  FAIL ' + $w + ' ' + $b) } }
        }
        Stop-KsBrowser $browser; $browser = $null
    }
    if (-not $SkipMutants -and $exit -eq 0) {
        $css = 'Public\assets\keepstore\css\type-scale.css'
        $mutants = @(
            @{ Id = 'M01_SHEET_NOT_LINKED'; File = 'Page.master'; Case = 'ELENCO'; W = 390; User = $false; Expect = 'ELENCO pagina'; Old = 'css/type-scale.css'; New = 'css/type-scale-off.css' },
            @{ Id = 'M02_BREAKPOINT_MOVED'; File = $css; Case = 'ACCESSO'; W = 1280; User = $false; Expect = 'ACCESSO pagina'; Old = '@media screen and (min-width: 992px) {'; New = '@media screen and (min-width: 1400px) {' },
            @{ Id = 'M03_LIST_TITLE_NOT_MAPPED'; File = $css; Case = 'ELENCO'; W = 390; User = $false; Expect = 'ELENCO pagina'; Old = '.ks-catalog-titlebar h1.ks-catalog-heading,'; New = '.ks-catalog-titlebar-off h1.ks-catalog-heading,' },
            @{ Id = 'M04_PRODUCT_SECTIONS_NOT_MAPPED'; File = $css; Case = 'SCHEDA'; W = 390; User = $false; Expect = 'SCHEDA sezione'; Old = '  .ks-pdp-section__title,'; New = '  .ks-pdp-section__title-off,' },
            @{ Id = 'M05_WEIGHT_WITHOUT_IMPORTANT'; File = $css; Case = 'SCHEDA'; W = 390; User = $false; Expect = 'SCHEDA pagina'; Old = "    font-size: var(--ks-title-page-size) !important;`n    font-weight: var(--ks-title-weight) !important;"; New = "    font-size: var(--ks-title-page-size) !important;`n    font-weight: var(--ks-title-weight);" },
            @{ Id = 'M06_RULES_ALSO_IN_PRINT'; File = $css; Case = 'SCHEDA'; W = 390; User = $false; Expect = 'SCHEDA stampa'; Old = "@media screen {`n  /* un solo carattere"; New = "@media all {`n  /* un solo carattere" },
            @{ Id = 'M07_CART_FONT_RULE_REMOVED'; File = $css; Case = 'CARRELLO'; W = 390; User = $true; Expect = 'CARRELLO carattere'; Old = "  .ks-cart-page {`n    font-family"; New = "  .ks-cart-page-off {`n    font-family" },
            @{ Id = 'M08_BUNDLE_TITLE_GREY_AGAIN'; File = 'articolo.aspx'; Case = 'SCHEDA'; W = 390; User = $false; Expect = 'SCHEDA insieme'; Old = 'class="prd-name body-md-2 text-secondary link fw-semibold'; New = 'class="prd-name body-md-2 text-main link-secondary fw-semibold' },
            @{ Id = 'M09_DEAL_TITLE_19_AGAIN'; File = $css; Case = 'HOME'; W = 1280; User = $false; Expect = 'HOME occasioni'; Old = '    font-size: var(--ks-card-title-large-size) !important;'; New = '    font-size-off: 16px;' },
            @{ Id = 'M10_THEME_TITLE_CLASSES_SERIF'; File = $css; Case = 'NEGATO'; W = 1280; User = $false; Expect = 'NEGATO'; Old = '  .h1, .h2, .h3, .h4, .h5, .h6,'; New = '  .h1-off,' },
            @{ Id = 'M12_FIXED_LINE_HEIGHT_AGAIN'; File = $css; Case = 'AREA'; W = 1280; User = $true; Expect = 'AREA pagina: interlinea'; Old = '    line-height: 1.25 !important;'; New = '    line-height-off: 1.25;' },
            @{ Id = 'M11_DEAL_RESERVE_76_AGAIN'; File = $css; Case = 'HOME'; W = 1280; User = $false; Expect = 'HOME occasioni: riserva'; Old = '    min-height: 64px !important;'; New = '    min-height: 76px !important;' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            Write-SiteText $mu.File $src.Replace($mu.Old, $mu.New)
            $browser = Start-Sized $mu.W
            try {
                if ($mu.User) { Enter-User $browser }
                if ($mu.Case -eq 'SCHEDA') { $null = Invoke-Case 'ELENCO' $browser $mu.W }
                $mb = @(Invoke-Case $mu.Case $browser $mu.W)
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Stop-KsBrowser $browser; $browser = $null; Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('TYPE_SCALE PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (12 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'TYPE_SCALE FAIL' }
exit $exit
