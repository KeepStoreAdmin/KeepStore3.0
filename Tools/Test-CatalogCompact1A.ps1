[CmdletBinding()]
param([switch]$SkipSmoke, [switch]$BaseOnly)

# KS-CATALOG-COMPACT-1A + PDP-PRINT-A4-1A. (A) contratto dei sorgenti; (B) browser reale (Edge) su una pagina di prova con i VERI fogli di stile e il foglio del cliente iniettato:
# nessun h1 con sfondo, titolo sans-serif, categoria a una riga, prezzi di una riga alla stessa quota; (C) stampa: il PDF vero della scheda sul sito di prova locale e
# A4 (595x842 pt) e un prodotto breve sta in una pagina; (D) mutazioni sui fogli (copie temporanee). Senza Edge: NON ESEGUITO (uscita 2). Solo ASCII.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$cssDir = Join-Path $root 'Public/assets/keepstore/css'
$utf8 = New-Object Text.UTF8Encoding($false)
function Norm([string]$t) { return ($t -replace "`r`n", "`n") }
function Read-Repo([string]$rel) { return (Norm ([IO.File]::ReadAllText((Join-Path $root $rel), $utf8))) }
function Get-Between([string]$text, [string]$from, [string]$to) {
    $i = $text.IndexOf($from); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($to, $i + $from.Length); if ($j -lt 0) { return $text.Substring($i) }
    return $text.Substring($i, $j - $i)
}

$files = @{
    master  = Read-Repo 'Page.master'
    catAspx = Read-Repo 'articoli.aspx'
    pdpAspx = Read-Repo 'articolo.aspx'
    ks      = Read-Repo 'Public/assets/keepstore/css/ks-ui.css'
    compact = $(if (Test-Path -LiteralPath (Join-Path $cssDir 'catalog-compact.css')) { Read-Repo 'Public/assets/keepstore/css/catalog-compact.css' } else { '' })
    product = Read-Repo 'Public/assets/keepstore/css/product-ui.css'
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    # A1 il foglio del cliente non puo colorare gli h1: regola globale con specificita (0,0,2), fogli versionati
    if ($f.ks -notmatch '(?m)^body h1,\s*\nbody \.h1 \{\s*\n\s*background-color: transparent;\s*\n\}') { $fail.Add('A1 regola h1 senza sfondo in ks-ui.css') }
    if ($f.master -notmatch 'css/ks-ui\.css"\) & "\?v=20261118-h1-legacy1a"') { $fail.Add('A1 buster di ks-ui.css') }
    # A2 catalogo: foglio, classi, buster
    if ($f.catAspx -notmatch 'css/catalog-compact\.css"\) %>\?v=20261118-compact1a"') { $fail.Add('A2 link del foglio compatto') }
    if ($f.catAspx -notmatch '<asp:Panel ID="ksPageTitle" runat="server" CssClass="py-3 ks-catalog-titlebar">' -or $f.catAspx -notmatch '<h1 class="title h4 mb-0 text-break ks-catalog-heading">') { $fail.Add('A2 classi del titolo') }
    $c = $f.compact
    if ($c -eq '') { $fail.Add('A2 foglio compatto assente') }
    else {
        if ($c -notmatch '\.ks-catalog-heading\s*\{[^}]*font-family:\s*Arial[^}]*font-weight:\s*700') { $fail.Add('A2 titolo sans-serif e in grassetto') }
        if ($c -notmatch '#ksCatalogPage \.ks-card-category\s*\{[^}]*max-height:\s*1lh !important[^}]*-webkit-line-clamp:\s*1 !important') { $fail.Add('A2 categoria a una riga') }
        if ($c -notmatch '#ksCatalogPage \.ks-card-title\s*\{[^}]*min-height:\s*2lh !important[^}]*max-height:\s*3lh !important') { $fail.Add('A2 nome da due a tre righe') }
        if ($c -notmatch '\.price-wrap\s*\{\s*margin-top:\s*auto !important' -or $c -notmatch '\.box-title\s*\{[^}]*display:\s*flex !important' -or $c -notmatch 'grid-template-rows:\s*minmax\(0, 1fr\) auto') { $fail.Add('A2 prezzi allineati in basso') }
        if ($c -notmatch 'div\.ks-recent-card \.card-product-info\s*\{[^}]*gap:\s*4px !important' -or $c -notmatch 'div\.ks-recent-card \.price-wrap\s*\{\s*margin-top:\s*0 !important') { $fail.Add('A2 recenti compatti') }
        foreach ($m in [regex]::Matches($c, '(?m)^([^\s/@}][^{]*)\{')) { if (-not ($m.Groups[1].Value -match '#ksCatalogPage|\.ks-catalog-titlebar')) { $fail.Add('A2 selettore fuori dal catalogo: ' + $m.Groups[1].Value.Trim()) } }
    }
    # A3 scheda: titolo e stampa
    if ($f.pdpAspx -notmatch 'css/product-ui\.css"\) %>\?v=20261119-compact-1b"') { $fail.Add('A3 buster di product-ui.css') }
    if ($f.product -notmatch '\.ks-product-page h1\.product-info-name\s*\{[^}]*background:\s*none[^}]*color:\s*#181818[^}]*font-family:\s*Arial') { $fail.Add('A3 titolo della scheda') }
    $pr = $f.product.Substring([Math]::Max(0, $f.product.LastIndexOf('@page')))
    if ($pr -notmatch '@page\s*\{\s*size:\s*A4 portrait;\s*margin:\s*11mm 12mm;') { $fail.Add('A3 @page A4') }
    if ($pr -notmatch 'grid-template-columns:\s*56mm minmax\(0, 1fr\)') { $fail.Add('A3 foto e dati affiancati') }
    if ($pr -notmatch '\.ks-pdp-info-group\s*\{[^}]*break-inside:\s*avoid' -or $pr -notmatch '\.tf-product-info-choose-option\s*\{[^}]*break-inside:\s*avoid' -or $pr -notmatch '\.ks-pdp-print-head\s*\{[^}]*break-after:\s*avoid') { $fail.Add('A3 blocchi interi') }
    if ($pr -notmatch '\.ks-pdp-section__head\s*\{[^}]*break-after:\s*avoid') { $fail.Add('A3 titoli attaccati al testo') }
    if ($pr -notmatch '\.ks-pdp-section\s*\{[^}]*break-inside:\s*auto' -or $pr -notmatch 'orphans:\s*3' -or $pr -notmatch 'widows:\s*3') { $fail.Add('A3 descrizione a righe intere') }
    if ($pr -notmatch '\.ks-pdp-info\s*\{[^}]*repeat\(2, minmax\(0, 1fr\)\)') { $fail.Add('A3 informazioni a due colonne') }
    if ($pr -notmatch 'ks-pdp-info-group\[data-ks-info-group="prezzi"\]') { $fail.Add('A3 gruppo prezzi (doppione) nascosto in stampa') }
    if ($pr -match '(?m)^\s*header\s*[,{]') { $fail.Add('A3 selettore header nudo in stampa') }
    if ($pr -notmatch 'transform:\s*none !important') { $fail.Add('A3 reset del transform di Swiper') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not (Test-Source $files)) { Write-Host 'CATALOG_COMPACT_1A FAIL (sorgenti)'; exit 1 }

# ---------------- (B) browser: pagina di prova con i veri fogli e il foglio del cliente iniettato ----------------
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$names = @('bootstrap.min.css', 'styles.css', 'keepstore.css', 'ks-ui.css', 'theme-overrides.css', 'catalog-ui.css', 'catalog-filters-ui.css', 'catalog-product-flow.css', 'catalog-compact.css')
function New-Card([string]$id, [string]$title, [string]$extra) {
    return @"
<article class="card-product ks-catalog-card $extra">
  <div class="card-product-wrapper"><a href="#" class="product-img"><img class="img-product" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" alt="" style="width:100%;height:160px;display:block" /></a></div>
  <div class="card-product-info">
    <div class="box-title">
      <div>
        <p class="product-tag caption text-main-2 ks-card-category">Distruggidocumenti</p>
        <a id="t$id" href="#" class="name-product body-md-2 fw-semibold text-secondary link ks-card-title">$title</a>
      </div>
      <div class="price-wrap fw-medium mt-1"><span class="new-price price-text fw-medium">13,72</span></div>
    </div>
    <div class="box-infor-detail"><ul class="list-computer-memory"><li><p class="caption">Cod. 123</p></li></ul></div>
  </div>
</article>
"@
}
function New-Recent([string]$tag, [string]$id, [string]$title) {
    return @"
<$tag class="card-product ks-catalog-card ks-recent-card">
  <div class="card-product-wrapper"><a href="#" class="product-img"><img class="img-product" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" alt="" style="width:100%;height:120px;display:block" /></a></div>
  <div class="card-product-info">
    <p class="product-tag caption text-main-2 ks-card-category">Cavi HDMI / DVI</p>
    <a id="t$id" href="#" class="name-product body-md-2 fw-semibold text-secondary link ks-card-title">$title</a>
    <p class="caption text-main-2 ks-card-brand-code">EWENT - Cod. EC1330</p>
    <div class="price-wrap fw-medium mt-1"><span class="new-price price-text fw-medium">1,69</span></div>
  </div>
</$tag>
"@
}
function Write-Fixture([string]$dir, [hashtable]$cssText) {
    $css = Join-Path $dir 'css'; New-Item -ItemType Directory -Force -Path $css | Out-Null
    foreach ($n in $names) {
        $target = Join-Path $css $n
        if ($cssText.ContainsKey($n)) { [IO.File]::WriteAllText($target, $cssText[$n], $utf8) } else { Copy-Item -LiteralPath (Join-Path $cssDir $n) -Destination $target -Force }
    }
    $links = ($names | ForEach-Object { '<link rel="stylesheet" href="css/' + $_ + '" />' }) -join "`n"
    $legacy = '<style>:root{--main-color-1:#e02020;} h1{background-color:var(--main-color-1);}</style>'
    $html = @"
<!doctype html><html lang="it"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
$links
$legacy
</head><body>
<div class="py-3 ks-catalog-titlebar"><div class="container"><h1 class="title h4 mb-0 text-break ks-catalog-heading">Distruggidocumenti</h1></div></div>
<h1 id="pdpTitle" class="product-info-name fw-semibold">DISTRUGGI DOCUMENTI FELLOWES</h1>
<section id="ksCatalogPage"><div class="content-area">
  <div class="gridLayout-wrapper"><div id="gridLayout" class="tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">
$(New-Card 'a' 'DISTRUGGI DOCUMENTI FELLOWES 6C A FRAMMENTO 35mm (P-4) 11LT CON CESTINO DA 11 LITRI E TAGLIO A MICROFRAMMENTO PER USO PROFESSIONALE' '')
$(New-Card 'b' 'DISTRUGGI DOCUMENTI GEHA S5' '')
$(New-Card 'c' 'CAVO HDMI' '')
$(New-Card 'd' 'DISTRUGGI DOCUMENTI GEHA HOME & OFFICE X7 CD CONFORT 18LT A4 EXTRA LARGE CON PORTA CD INTEGRATO E CESTINO' '')
  </div></div>
  <div class="ks-recently-viewed-block"><div class="ks-recent-row" style="display:grid;grid-template-columns:repeat(4,1fr);gap:16px">
$(New-Recent 'article' 'e' 'CAVO HDMI EWENT')
$(New-Recent 'div' 'f' 'CASE PER PC ITEK PRIME DARK 500W 20/24pin SATA E CAVO SATA INCLUSO NELLA CONFEZIONE')
  </div></div>
</div></section></body></html>
"@
    $p = Join-Path $dir 'fixture.html'; [IO.File]::WriteAllText($p, $html, $utf8); return $p
}
$measure = @'
(function(){
  var out={fails:[]};
  Array.prototype.forEach.call(document.querySelectorAll('h1'),function(h){var c=getComputedStyle(h); if(c.backgroundColor!=='rgba(0, 0, 0, 0)') out.fails.push('H1_HAS_BACKGROUND '+h.className+' '+c.backgroundColor); if(c.fontFamily.indexOf('Arial')<0) out.fails.push('H1_NOT_SANS '+h.className+' '+c.fontFamily);});
  function y(card){var p=card.querySelector('.price-wrap').getBoundingClientRect(); return Math.round(p.top-card.getBoundingClientRect().top);}
  var cards=Array.prototype.slice.call(document.querySelectorAll('#gridLayout article.card-product'));
  if(cards.length!==4) out.fails.push('CARDS '+cards.length);
  cards.forEach(function(c,i){var cat=c.querySelector('.ks-card-category').getBoundingClientRect().height; if(cat>24) out.fails.push('CATEGORY_TALL '+i+' '+Math.round(cat)); var nm=c.querySelector('.ks-card-title').getBoundingClientRect().height; if(nm>70) out.fails.push('NAME_TALL '+i+' '+Math.round(nm));});
  if(cards.length===4){ if(Math.max.apply(null,cards.map(y))-Math.min.apply(null,cards.map(y))>1) out.fails.push('PRICES_NOT_ALIGNED '+cards.map(y).join(',')); var short=cards[2].querySelector('.ks-card-title').getBoundingClientRect().height; if(short>46) out.fails.push('SHORT_NAME_RESERVES_THREE_LINES '+Math.round(short)); }
  Array.prototype.forEach.call(document.querySelectorAll('.ks-recent-card'),function(c,i){var cr=c.querySelector('.ks-card-category').getBoundingClientRect(),nr=c.querySelector('.ks-card-title').getBoundingClientRect(),pr=c.querySelector('.price-wrap').getBoundingClientRect(),br=c.querySelector('.ks-card-brand-code').getBoundingClientRect(); if(cr.height>24) out.fails.push('RECENT_CATEGORY_TALL '+i+' '+Math.round(cr.height)); if(nr.top-cr.bottom>8) out.fails.push('RECENT_GAP_CATEGORY_NAME '+i+' '+Math.round(nr.top-cr.bottom)); if(pr.top-br.bottom>12) out.fails.push('RECENT_GAP_CODE_PRICE '+i+' '+Math.round(pr.top-br.bottom));});
  Array.prototype.forEach.call(document.querySelectorAll('#gridLayout article.card-product, .ks-recent-card'),function(c,i){c.querySelectorAll('*').forEach(function(a){ if(a.closest('.product-img')) return; });});
  out.prices=cards.map(y).join(',')+' names='+cards.map(function(c){return Math.round(c.querySelector('.ks-card-title').getBoundingClientRect().height)}).join(',')+' hs='+cards.map(function(c){return Math.round(c.getBoundingClientRect().height)}).join(',');
  return JSON.stringify(out);
})()
'@
function Invoke-Browser([string]$html) {
    $b = $null
    try {
        try { $b = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1366 -Height 900 } catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }
        Open-KsUrl $b ('file:///' + ($html -replace '\\', '/')); Start-Sleep -Milliseconds 500
        return ((Invoke-KsJs $b $measure) | ConvertFrom-Json)
    } finally { if ($b) { Stop-KsBrowser $b } }
}
function Run-Case([hashtable]$cssText) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('ks-compact-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    try { $p = Write-Fixture $dir $cssText; return (Invoke-Browser $p) } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
$base = Run-Case @{}
if (@($base.fails).Count -gt 0) { @($base.fails | Select-Object -Unique) | ForEach-Object { Write-Host ('  FAIL ' + $_) }; Write-Host 'CATALOG_COMPACT_1A FAIL (browser)'; exit 1 }

if ($BaseOnly) { Write-Host 'CATALOG_COMPACT_1A BASE_OK'; exit 0 }
# ---------------- (D) mutazioni sui fogli: ognuna deve far fallire il browser ----------------
$cssMutants = @(
    @{ Id = 'B01_H1_RULE_GONE'; File = 'ks-ui.css'; Old = "body h1,`nbody .h1 {`n  background-color: transparent;`n}"; New = '' },
    @{ Id = 'B02_H1_RULE_WEAK_SPECIFICITY'; File = 'ks-ui.css'; Old = "body h1,`nbody .h1 {"; New = "h1,`n.h1x {" },
    @{ Id = 'B03_CATEGORY_TWO_LINES'; File = 'catalog-compact.css'; Old = 'max-height: 1lh !important;'; New = 'max-height: 2lh !important; min-height: 2lh !important;' },
    @{ Id = 'B04_NAME_ALWAYS_THREE_LINES'; File = 'catalog-compact.css'; Old = 'min-height: 2lh !important;'; New = 'min-height: 3lh !important;' },
    @{ Id = 'B05_PRICE_NOT_PUSHED_DOWN'; File = 'catalog-compact.css'; Old = '  margin-top: auto !important;'; New = '  margin-top: 0 !important;' },
    @{ Id = 'B09_INFO_ROWS_NOT_STRETCHED'; File = 'catalog-compact.css'; Old = 'grid-template-rows: minmax(0, 1fr) auto;'; New = '' },
    @{ Id = 'B06_INFO_NOT_GROWING'; File = 'catalog-compact.css'; Old = '  flex: 1 1 auto !important;'; New = '  flex: 0 0 auto !important;' },
    @{ Id = 'B07_HEADING_SERIF'; File = 'catalog-compact.css'; Old = 'font-family: Arial, Helvetica, sans-serif;'; New = 'font-family: "Inter", serif;' },
    @{ Id = 'B10_PRICE_AUTO_WITHOUT_IMPORTANT'; File = 'catalog-compact.css'; Old = 'margin-top: auto !important;'; New = 'margin-top: auto;' },
    @{ Id = 'B11_RECENT_OLD_GAP'; File = 'catalog-compact.css'; Old = 'gap: 4px !important;'; New = 'gap: 20px !important;' },
    @{ Id = 'B12_RECENT_PRICE_PUSHED_DOWN'; File = 'catalog-compact.css'; Old = 'margin-top: 0 !important;'; New = 'margin-top: 80px !important;' }
    # B08 (regola della categoria non limitata al catalogo) ritirato con UX-COMPACT-SPACING-SITEWIDE-1A: la regola condivisa e gia di una riga, il mutante non cambia piu la geometria.
)
$orig = @{ 'ks-ui.css' = Norm ([IO.File]::ReadAllText((Join-Path $cssDir 'ks-ui.css'), $utf8)); 'catalog-compact.css' = $files.compact }
$bad = 0
foreach ($m in $cssMutants) {
    $o = Norm $m.Old; $n = Norm $m.New
    if (-not $orig[$m.File].Contains($o)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $m.Id); $bad++; continue }
    $res = Run-Case @{ $m.File = $orig[$m.File].Replace($o, $n) }
    if (@($res.fails).Count -eq 0) { Write-Host ('  MUTANT_SURVIVED ' + $m.Id); $bad++ }
}
$srcMutants = @(
    @{ Id = 'S01_NO_PAGE_RULE'; File = 'product'; Old = "@page {`n  size: A4 portrait;`n  margin: 11mm 12mm;`n}"; New = '' },
    @{ Id = 'S02_INFO_ONE_COLUMN'; File = 'product'; Old = 'grid-template-columns: repeat(2, minmax(0, 1fr));' + "`n" + '    gap: 2.5mm 5mm;'; New = 'grid-template-columns: 1fr;' },
    @{ Id = 'S03_GROUP_CAN_SPLIT'; File = 'product'; Old = "    border: 0.5pt solid #ccc;`n    break-inside: avoid;"; New = '    border: 0.5pt solid #ccc;' },
    @{ Id = 'S04_PRICE_BOX_CAN_SPLIT'; File = 'product'; Old = "    border-left: 3pt solid var(--primary, #D80027);`n    break-inside: avoid;"; New = '    border-left: 3pt solid var(--primary, #D80027);' },
    @{ Id = 'S15_SECTIONS_NEVER_SPLIT'; File = 'product'; Old = "    border: 0;`n    break-inside: auto;"; New = "    border: 0;`n    break-inside: avoid;" },
    @{ Id = 'S05_DESCRIPTION_NO_WIDOWS'; File = 'product'; Old = 'widows: 3;'; New = '' },
    @{ Id = 'S06_PHOTO_FULL_WIDTH'; File = 'product'; Old = 'grid-template-columns: 56mm minmax(0, 1fr);'; New = 'grid-template-columns: 1fr;' },
    @{ Id = 'S07_TITLE_AFTER_BREAK'; File = 'product'; Old = "    border-bottom: 0.75pt solid #111;`n    break-after: avoid;"; New = '    border-bottom: 0.75pt solid #111;' },
    @{ Id = 'S08_SWIPER_NOT_RESET'; File = 'product'; Old = "    display: block !important;`n    transform: none !important;"; New = '    display: block !important;' },
    @{ Id = 'S09_H1_RED_AGAIN'; File = 'product'; Old = "  background: none;`n  color: #181818;"; New = '  color: #181818;' },
    @{ Id = 'S10_MASTER_BUSTER_OLD'; File = 'master'; Old = '?v=20261118-h1-legacy1a"'; New = '?v=20261118-pdp-tools1a"' },
    @{ Id = 'S11_LINK_REMOVED'; File = 'catAspx'; Old = '    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/catalog-compact.css") %>?v=20261118-compact1a" />'; New = '' },
    @{ Id = 'S12_TITLE_CLASS_REMOVED'; File = 'catAspx'; Old = ' text-break ks-catalog-heading">'; New = ' text-break">' },
    @{ Id = 'S14_PRICE_GROUP_PRINTED_TWICE'; File = 'product'; Old = '  .ks-pdp-info-group[data-ks-info-group="prezzi"],'; New = '' },
    @{ Id = 'S13_PDP_BUSTER_OLD'; File = 'pdpAspx'; Old = 'product-ui.css") %>?v=20261119-compact-1b'; New = 'product-ui.css") %>?v=20261118-pdp-tools1a' }
)
foreach ($m in $srcMutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    $o = Norm $m.Old
    if (-not $copy[$m.File].Contains($o)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $m.Id); $bad++; continue }
    $copy[$m.File] = $copy[$m.File].Replace($o, (Norm $m.New))
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $m.Id); $bad++ }
}
$totalMutants = $cssMutants.Count + $srcMutants.Count
if ($totalMutants -lt 20) { Write-Host 'CATALOG_COMPACT_1A FAIL (pochi mutanti)'; exit 1 }
if ($bad -gt 0) { Write-Host 'CATALOG_COMPACT_1A FAIL (mutanti)'; exit 1 }

# ---------------- (C) stampa: PDF reale sul sito di prova locale (se acceso) ----------------
$smokeNote = 'sito di prova saltato'
if (-not $SkipSmoke) {
    $up = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 8443); $up = $t.Connected; $t.Close() } catch { $up = $false }
    if (-not $up) { $smokeNote = 'sito di prova non acceso: parte (C) NON ESEGUITA' }
    else {
        $b = $null
        try {
            $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width 1366 -Height 900
            $report = @()
            foreach ($case in @(@{ Id = 20799; Max = 1 }, @{ Id = 14488; Max = 2 })) {
                Open-KsUrl $b ('https://www.taikun.it:8443/articolo.aspx?id=' + $case.Id); Start-Sleep -Milliseconds 2500
                $null = Invoke-KsJs $b "window.dispatchEvent(new Event('beforeprint')); 'ok'"
                # completezza: il limite di pagine non deve essere raggiunto perdendo contenuto (prezzo, informazioni, descrizione) e nulla di cio che non va stampato
                $null = Invoke-KsCdp $b 'Emulation.setEmulatedMedia' @{ media = 'print' }
                Start-Sleep -Milliseconds 500
                $chk = Invoke-KsJs $b "(function(){function vis(s){var e=document.querySelector(s);if(!e)return 'absent';var r=e.getBoundingClientRect();return (getComputedStyle(e).display!=='none'&&r.height>0&&r.width>0)?'ok':'hidden';}var groups=document.querySelectorAll('.ks-pdp-info-group');var lastOk=groups.length>0&&groups[groups.length-1].getBoundingClientRect().height>0;var h1=document.querySelector('h1.product-info-name');return JSON.stringify({head:vis('.ks-pdp-print-head'),title:vis('h1.product-info-name'),h1bg:h1?getComputedStyle(h1).backgroundColor:'none',price:vis('.tf-product-info-choose-option .price-text'),vatText:(document.querySelector('.tf-product-info-choose-option .product-delivery .body-text-3')||{innerText:''}).innerText.trim().length>0,priceText:(document.querySelector('.tf-product-info-choose-option .price-text')||{innerText:''}).innerText.trim().length>0,desc:vis('#prd-des'),info:vis('.ks-pdp-info'),lastGroup:lastOk,header:vis('.tf-header'),footer:vis('.tf-footer'),tools:vis('.ks-pdp-tools'),carousel:vis('.ks-product-list-section')})})()"
                $null = Invoke-KsCdp $b 'Emulation.setEmulatedMedia' @{ media = '' }
                $cj = $chk | ConvertFrom-Json
                if ($cj.head -ne 'ok' -or $cj.title -ne 'ok' -or $cj.price -ne 'ok' -or -not $cj.priceText -or -not $cj.vatText -or $cj.info -ne 'ok' -or -not $cj.lastGroup -or $cj.h1bg -ne 'rgba(0, 0, 0, 0)') { Write-Host ('  FAIL PRINT_CONTENT_MISSING id=' + $case.Id + ' ' + $chk); Write-Host 'CATALOG_COMPACT_1A FAIL (stampa)'; exit 1 }
                if ($cj.desc -eq 'hidden' -or $cj.header -eq 'ok' -or $cj.footer -eq 'ok' -or $cj.tools -eq 'ok' -or $cj.carousel -eq 'ok') { Write-Host ('  FAIL PRINT_SHOWS_WRONG_BLOCKS id=' + $case.Id + ' ' + $chk); Write-Host 'CATALOG_COMPACT_1A FAIL (stampa)'; exit 1 }
                $pdf = Invoke-KsCdp $b 'Page.printToPDF' @{ printBackground = $true; preferCSSPageSize = $true }
                $data = $pdf.data; if (-not $data -and $pdf.result) { $data = $pdf.result.data }
                $txt = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($data))
                $pages = [regex]::Matches($txt, '/Type\s*/Page[^s]').Count
                $box = [regex]::Match($txt, '/MediaBox\s*\[\s*0\s+0\s+([0-9.]+)\s+([0-9.]+)')
                if (-not $box.Success -or [Math]::Abs([double]$box.Groups[1].Value - 595.0) -gt 1.5 -or [Math]::Abs([double]$box.Groups[2].Value - 842.0) -gt 1.5) { Write-Host ('  FAIL PDF_NOT_A4 id=' + $case.Id + ' ' + $box.Value); Write-Host 'CATALOG_COMPACT_1A FAIL (stampa)'; exit 1 }
                if ($pages -lt 1 -or $pages -gt $case.Max) { Write-Host ('  FAIL PDF_PAGES id=' + $case.Id + ' pages=' + $pages + ' max=' + $case.Max); Write-Host 'CATALOG_COMPACT_1A FAIL (stampa)'; exit 1 }
                $report += ('id' + $case.Id + '=' + $pages + 'p')
            }
            $smokeNote = 'PDF A4 ' + ($report -join ' ')
        } catch { Write-Host ('  FAIL SMOKE ' + $_.Exception.Message); Write-Host 'CATALOG_COMPACT_1A FAIL (stampa)'; exit 1 } finally { if ($b) { Stop-KsBrowser $b } }
    }
}
Write-Host ('CATALOG_COMPACT_1A PASS (' + $totalMutants + ' mutanti; ' + $smokeNote + ')')
exit 0
