[CmdletBinding()]
param()

# KS-A04-CATALOG-GREY-AA-1A - riquadro bianco e testo AA nelle card del catalogo.
# Oracolo COMPORTAMENTALE: i veri fogli di stile del sito (nello stesso ordine di Page.master e articoli.aspx) sono caricati in Edge su una pagina di prova che replica
# il markup reale di ProductCard.ascx, della nota IVA e dell'etichetta dei settori; il test legge i colori COMPUTATI (cascata, specificita e variabili del tema inclusi) in
# tutte e quattro le viste e ne calcola il contrasto WCAG. Una regola presente nel foglio ma che perde nella cascata viene quindi rilevata (un cercatore di testo no).
# Ogni bersaglio deve esistere: zero elementi trovati = FALLIMENTO, mai PASS. Senza Edge il risultato e NON ESEGUITO (codice di uscita 2), mai PASS.
# Non misura foto reali ne altre pagine; il badge "Promo" (bianco su rosso) e il rosso di marca restano fuori da questo task e non sono controllati qui.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI. Le mutazioni lavorano su copie temporanee dei fogli, mai sulla copia di lavoro.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:ThemeOldGrey = $false
$repoRoot = Split-Path -Parent $PSScriptRoot
$cssDir = Join-Path $repoRoot 'Public/assets/keepstore/css'
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

# --- Contrasto WCAG (formula del W3C, double, senza arrotondare prima del confronto) -----------------------------------------------------
function Lin([double]$c) { $c = $c / 255.0; if ($c -le 0.04045) { return $c / 12.92 }; return [Math]::Pow(($c + 0.055) / 1.055, 2.4) }
function Lum([double[]]$rgb) { return (0.2126 * (Lin $rgb[0]) + 0.7152 * (Lin $rgb[1]) + 0.0722 * (Lin $rgb[2])) }
function Parse-Rgb([string]$s) {
    $m = [regex]::Match($s, 'rgba?\(\s*([0-9.]+)[ ,]+([0-9.]+)[ ,]+([0-9.]+)')
    if (-not $m.Success) { throw ('COLOR_NOT_PARSED=' + $s) }
    return [double[]]@([double]$m.Groups[1].Value, [double]$m.Groups[2].Value, [double]$m.Groups[3].Value)
}
function Contrast([string]$fg, [string]$bg) {
    $l1 = Lum (Parse-Rgb $fg); $l2 = Lum (Parse-Rgb $bg)
    return ((([Math]::Max($l1, $l2)) + 0.05) / (([Math]::Min($l1, $l2)) + 0.05))
}
Assert-Source (((Contrast 'rgb(102, 102, 102)' 'rgb(255, 255, 255)') -ge 4.5) -and ((Contrast 'rgb(115, 120, 125)' 'rgb(255, 255, 255)') -lt 4.5) -and ((Contrast 'rgb(216, 0, 39)' 'rgb(255, 255, 255)') -ge 4.5) -and ((Contrast 'rgb(255, 61, 61)' 'rgb(255, 255, 255)') -lt 4.5)) 'CONTRAST_HELPER_KNOWS_THE_OLD_GREY_AND_RED_FAIL_AND_THE_NEW_PASS'

# --- La pagina di prova replica il markup reale: lo ancoriamo al sorgente -----------------------------------------------------------------
$aspx = Read-Repo 'articoli.aspx'
$aspxVb = Read-Repo 'articoli.aspx.vb'
$card = Read-Repo 'Public/ui/controls/ProductCard.ascx'
$cssOriginal = Read-Repo 'Public/assets/keepstore/css/catalog-ui.css'
function Test-MarkupAnchors([string]$aspxText) {
    if ($aspxText -notmatch 'css/catalog-ui\.css"\) %>\?v=(?:20261115-grey-aa1a|20261115-palette-aa1a|20261119-compact-1a)') { return $false }
    if (-not $aspxText.Contains('<p class="body-text-3 text-main-2 mb-2 ks-price-basis-note"><asp:Label ID="lblPrezzi" runat="server" /></p>')) { return $false }
    return $true
}
Assert-Source (Test-MarkupAnchors $aspx) 'ASPX_HAS_THE_NOTE_CLASS_AND_THE_NEW_CSS_BUSTER'
Assert-Source ($aspxVb.Contains('<span class=""ks-taxonomy-disclosure-label-closed"">') -and $aspxVb.Contains('<summary class=""ks-taxonomy-disclosure-summary"">') -and $aspxVb.Contains('ks-taxonomy-disclosure-label-open"">Mostra meno</span>')) 'DISCLOSURE_MARKUP_MATCHES_THE_FIXTURE'
Assert-Source ($card.Contains('<p class="product-tag caption text-main-2 ks-card-category">') -and $card.Contains('<li><p class="caption"><%= SafeProductCodeText %></p></li>') -and $card.Contains('<span class="old-price body-md-2 text-main-2">') -and $card.Contains('<div class="card-product-wrapper">')) 'CARD_MARKUP_MATCHES_THE_FIXTURE'
$styleNames = @('bootstrap.min.css', 'keepstore.css', 'keepstore-overrides.css', 'account-ui.css', 'documents-ui.css', 'auth-ui.css', 'ks-ui.css', 'nice-select.css', 'swiper-bundle.min.css', 'animate.css', 'styles.css', 'minicart-ui.css', 'theme-overrides.css', 'catalog-ui.css', 'catalog-filters-ui.css', 'catalog-product-flow.css')
foreach ($n in $styleNames) { if (-not (Test-Path -LiteralPath (Join-Path $cssDir $n))) { throw ('STYLESHEET_MISSING=' + $n) } }

function New-CardHtml([string]$tag, [string]$extraClass) {
    # Le card dei "Visti di recente" hanno anche la riga marca/codice (articoli.aspx riga ~560 e keepstore-recently-viewed.js riga ~145).
    $brandLine = ''
    if ($extraClass -like '*ks-recent-card*') { $brandLine = '<p class="caption text-main-2 ks-card-brand-code">Marca - Cod. AD4IN1</p>' }
    return @"
<$tag class="card-product $extraClass" aria-labelledby="t-$tag-title">
  <div class="card-product-wrapper">
    <a href="#" class="product-img" aria-label="Prodotto"><img class="img-product" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" alt="Prodotto" /><img class="img-hover" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" alt="" aria-hidden="true" /></a>
  </div>
  <div class="card-product-info">
    <div class="box-title">
      <div>
        <p class="product-tag caption text-main-2 ks-card-category">Adattatori SIM</p>
        <a id="t-$tag-title" href="#" class="name-product body-md-2 fw-semibold text-secondary link ks-card-title">ADATTATORE SIM 4 IN 1 NERO NOOSY</a>
        $brandLine
      </div>
      <p class="price-wrap fw-medium" role="group" aria-label="Prezzo prodotto"><span class="new-price price-text fw-medium">5,00</span><span class="old-price body-md-2 text-main-2">6,00</span></p>
    </div>
    <div class="box-infor-detail">
      <ul class="list-computer-memory">
        <li><span class="ks-availability ks-availability--synthetic" role="status" aria-label="Disponibilita: Disponibile"><span class="ks-availability__status is-ok"><span class="ks-availability__dot" aria-hidden="true"></span><span class="ks-availability__status-text">Disponibile</span></span></span></li>
        <li><p class="caption">Cod. AD4IN1</p></li>
      </ul>
    </div>
  </div>
</$tag>
"@
}

function Write-Fixture([string]$directory, [string]$catalogCss) {
    $cssCopy = Join-Path $directory 'css'
    New-Item -ItemType Directory -Force -Path $cssCopy | Out-Null
    foreach ($n in $styleNames) {
        $target = Join-Path $cssCopy $n
        if ($n -eq 'catalog-ui.css') { [IO.File]::WriteAllText($target, $catalogCss, (New-Object Text.UTF8Encoding($false))) }
        elseif ($n -eq 'styles.css' -and $script:ThemeOldGrey) {
            # Simula un tema (o il CSS di un cliente) con il vecchio grigio: dal task KS-A04-PALETTE-AA-1A il token --gray-2 vale #666 e da solo rende AA categoria, codice e nota,
            # quindi le regole esplicite del catalogo sono ridondanti e togliere una di esse e un mutante equivalente: si prova insieme al vecchio token.
            $oldTheme = ([IO.File]::ReadAllText((Join-Path $cssDir 'styles.css'))).Replace('--gray-2: #666666;', '--gray-2: #73787d;')
            if ($oldTheme -eq [IO.File]::ReadAllText((Join-Path $cssDir 'styles.css'))) { throw 'OLD_THEME_GREY_NOT_APPLIED' }
            [IO.File]::WriteAllText($target, $oldTheme, (New-Object Text.UTF8Encoding($false)))
        }
        else { Copy-Item -LiteralPath (Join-Path $cssDir $n) -Destination $target -Force }
    }
    $links = ($styleNames | ForEach-Object { '<link rel="stylesheet" href="css/' + $_ + '" />' }) -join "`n"
    $html = @"
<!doctype html>
<html lang="it"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
$links
</head><body>
<section id="ksCatalogPage">
  <div class="content-area">
    <p class="body-text-3 text-main-2 mb-2 ks-price-basis-note"><span id="lblPrezzi">Prezzi visualizzati IVA inclusa</span></p>
    <nav class="ks-catalog-category-nav"><ul><li class="ks-category-nav-disclosure-item"><details id="disc" class="ks-taxonomy-disclosure ks-taxonomy-disclosure-sectors"><summary class="ks-taxonomy-disclosure-summary"><span class="ks-taxonomy-disclosure-label-closed">Mostra altri 6 settori</span><span class="ks-taxonomy-disclosure-label-open">Mostra meno</span><i class="icon-arrow-down" aria-hidden="true"></i></summary><ul class="ks-category-nav-more-list"><li><a href="#">Altro</a></li></ul></details></li></ul></nav>
    <div class="gridLayout-wrapper"><div id="gridLayout" class="tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">
$(New-CardHtml 'article' 'c-article')
    </div></div>
    <div class="ks-recently-viewed-block">
$(New-CardHtml 'article' 'ks-catalog-card ks-recent-card r-article')
$(New-CardHtml 'div' 'ks-catalog-card ks-recent-card r-div')
    </div>
  </div>
</section>
</body></html>
"@
    $path = Join-Path $directory 'fixture.html'
    [IO.File]::WriteAllText($path, $html, (New-Object Text.UTF8Encoding($false)))
    return $path
}

$measureJs = @'
(function(){
  function parse(c){var m=c.match(/rgba?\(([^)]+)\)/); if(!m) return null; var p=m[1].split(',').map(function(x){return parseFloat(x)}); return {r:p[0],g:p[1],b:p[2],a:(p.length>3?p[3]:1)};}
  function bgOf(el){var n=el; while(n && n.nodeType===1){var c=parse(getComputedStyle(n).backgroundColor); if(c && c.a>0.99) return 'rgb('+c.r+', '+c.g+', '+c.b+')'; n=n.parentElement;} return 'NO_OPAQUE_BACKGROUND';}
  function one(name, sel){ var el=document.querySelector(sel); if(!el) return {name:name,found:false}; var cs=getComputedStyle(el); var r=el.getBoundingClientRect();
    return {name:name,found:true,color:cs.color,bg:bgOf(el),own:cs.backgroundColor,visible:(cs.display!=='none'&&cs.visibility!=='hidden'&&r.width>0&&r.height>0),size:cs.fontSize}; }
  var g=document.getElementById('gridLayout'), out={};
  ['layout-tabgrid-1','layout-tabgrid-2','layout-tablist-1','layout-tablist-2'].forEach(function(layout){
    g.className=g.className.replace(/layout-[a-z0-9-]+/,layout);
    var rows=[];
    rows.push(one('cat','#gridLayout .c-article .ks-card-category'));
    rows.push(one('code','#gridLayout .c-article .list-computer-memory li + li .caption'));
    rows.push(one('avail','#gridLayout .c-article .ks-availability__status-text'));
    rows.push(one('old','#gridLayout .c-article .old-price'));
    rows.push(one('tileArticle','#gridLayout .c-article .card-product-wrapper'));
    rows.push(one('rCatA','.ks-recently-viewed-block .r-article .ks-card-category'));
    rows.push(one('rBrandA','.ks-recently-viewed-block .r-article .ks-card-brand-code'));
    rows.push(one('rTileA','.ks-recently-viewed-block .r-article .card-product-wrapper'));
    rows.push(one('rCatD','.ks-recently-viewed-block .r-div .ks-card-category'));
    rows.push(one('rBrandD','.ks-recently-viewed-block .r-div .ks-card-brand-code'));
    rows.push(one('rTileD','.ks-recently-viewed-block .r-div .card-product-wrapper'));
    out[layout]=rows;
  });
  var d=document.getElementById('disc'); d.open=false;
  var notes=[one('note','#lblPrezzi'), one('disclosureClosed','.ks-taxonomy-disclosure-label-closed')];
  d.open=true; notes.push(one('disclosureOpen','.ks-taxonomy-disclosure-label-open'));
  out.page=notes;
  return JSON.stringify(out);
})()
'@

# Valore pinnato del colore dello stato "Disponibile": non e un grigio e non deve cambiare con questo task (preservazione).
$expectedAvail = 'rgb(23, 113, 61)'

function Evaluate([object]$m) {
    $fails = New-Object System.Collections.Generic.List[string]
    function Need($rows, [string]$name, [string]$layout) { if (-not $rows.ContainsKey($name) -or -not $rows[$name].found) { $fails.Add($layout + ':' + $name + ':TARGET_NOT_FOUND'); return $false }; return $true }
    foreach ($layout in @('layout-tabgrid-1', 'layout-tabgrid-2', 'layout-tablist-1', 'layout-tablist-2')) {
        $rows = @{}; foreach ($r in $m.$layout) { $rows[$r.name] = $r }
        foreach ($name in @('cat', 'old', 'rCatA', 'rBrandA', 'rCatD', 'rBrandD')) {
            if (Need $rows $name $layout) {
                if ($rows[$name].bg -eq 'NO_OPAQUE_BACKGROUND') { $fails.Add($layout + ':' + $name + ':BACKGROUND_NOT_RESOLVED') }
                elseif ((Contrast $rows[$name].color $rows[$name].bg) -lt 4.5) { $fails.Add($layout + ':' + $name + ':CONTRAST_BELOW_AA ' + $rows[$name].color + ' on ' + $rows[$name].bg) }
            }
        }
        if (Need $rows 'code' $layout) {
            if ($layout -eq 'layout-tabgrid-1' -and -not $rows['code'].visible) { $fails.Add($layout + ':code:NOT_VISIBLE_IN_THE_ONLY_VIEW_THAT_SHOWS_IT') }
            if ($rows['code'].visible -and (Contrast $rows['code'].color $rows['code'].bg) -lt 4.5) { $fails.Add($layout + ':code:CONTRAST_BELOW_AA ' + $rows['code'].color + ' on ' + $rows['code'].bg) }
        }
        if (Need $rows 'avail' $layout) { if ($rows['avail'].color -ne $expectedAvail) { $fails.Add($layout + ':avail:COLOR_CHANGED ' + $rows['avail'].color) } }
        foreach ($name in @('tileArticle', 'rTileA', 'rTileD')) {
            if (Need $rows $name $layout) { if ($rows[$name].own -ne 'rgb(255, 255, 255)') { $fails.Add($layout + ':' + $name + ':TILE_NOT_WHITE ' + $rows[$name].own) } }
        }
    }
    $pageRows = @{}; foreach ($r in $m.page) { $pageRows[$r.name] = $r }
    foreach ($name in @('note', 'disclosureClosed', 'disclosureOpen')) {
        if (Need $pageRows $name 'page') {
            if (-not $pageRows[$name].visible) { $fails.Add('page:' + $name + ':NOT_VISIBLE') }
            elseif ($pageRows[$name].bg -eq 'NO_OPAQUE_BACKGROUND') { $fails.Add('page:' + $name + ':BACKGROUND_NOT_RESOLVED') }
            elseif ((Contrast $pageRows[$name].color $pageRows[$name].bg) -lt 4.5) { $fails.Add('page:' + $name + ':CONTRAST_BELOW_AA ' + $pageRows[$name].color + ' on ' + $pageRows[$name].bg) }
        }
    }
    return $fails.ToArray()
}

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-grey-aa-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$browser = $null
try {
    try { $browser = Start-KsBrowser -LoopbackHosts @('localhost') -Width 1440 -Height 900 }
    catch { Write-Output ('BROWSER_NON_ESEGUITO: ' + $_.Exception.Message); exit 2 }

    function Run-Fixture([string]$name, [string]$catalogCss) {
        $dir = Join-Path $work $name
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $path = Write-Fixture $dir $catalogCss
        Open-KsUrl $browser ('file:///' + ($path -replace '\\', '/'))
        Start-Sleep -Milliseconds 1500
        $json = Invoke-KsJs $browser $measureJs
        return (Evaluate ($json | ConvertFrom-Json))
    }
    function Assert-Fails([string]$name, [string]$catalogCss, [string]$mustContain, [switch]$ThemeOldGrey) {
        $script:ThemeOldGrey = $ThemeOldGrey.IsPresent
        $f = @(Run-Fixture $name $catalogCss)
        $script:ThemeOldGrey = $false
        if ($f.Count -eq 0) { throw ('MUTATION_NOT_DETECTED=' + $name) }
        if (-not (@($f | Where-Object { $_ -like ('*' + $mustContain + '*') }).Count)) { throw ('MUTATION_DETECTED_FOR_THE_WRONG_REASON=' + $name + ' wanted ' + $mustContain + ' got ' + ($f -join ' | ')) }
        Write-Output ('PASS MUTATION_DETECTED ' + $name + ' (' + $f.Count + ' findings)')
    }

    # --- Stato reale ----------------------------------------------------------------------------------------------------------------------
    $real = @(Run-Fixture 'real' ([IO.File]::ReadAllText((Join-Path $cssDir 'catalog-ui.css'))))
    if ($real.Count -gt 0) { $real | ForEach-Object { Write-Output ('FINDING ' + $_) }; throw 'REAL_CSS_FAILS_THE_BEHAVIOURAL_ORACLE' }
    Write-Output 'PASS REAL_CSS_PASSES_ALL_VIEWS_CATEGORY_CODE_NOTE_DISCLOSURE_TILE_AVAILABILITY_PRESERVED'

    # --- Mutazioni (su copie temporanee del foglio) -----------------------------------------------------------------------------------------
    $css = Norm $cssOriginal
    $tile1 = "  /* Riquadro bianco come nella HOME: con una foto non quadrata su fondo bianco il grigio mostrava due fasce (KS-A04-CATALOG-GREY-AA-1A). */`n  background: #fff;`n  border-radius: 3px;"
    $tile1Bad = "  /* Riquadro bianco come nella HOME: con una foto non quadrata su fondo bianco il grigio mostrava due fasce (KS-A04-CATALOG-GREY-AA-1A). */`n  background: #f4f4f4;`n  border-radius: 3px;"
    Assert-Fails 'M01_tile_rule_1_grey_again' (Mutate-Text $css $tile1 $tile1Bad 'M01') 'TILE_NOT_WHITE'
    Assert-Fails 'M02_tile_rule_2_grey_again_div_recent_card' (Mutate-Text $css "  background: #fff;`n  border-radius: 4px;" "  background: #f4f4f4;`n  border-radius: 4px;" 'M02') 'rTileD:TILE_NOT_WHITE'
    $codeGood = "  color: #666;`n}"
    $codeRule = "#ksCatalogPage #gridLayout.layout-tabgrid-1 article.card-product .list-computer-memory li + li .caption {"
    $codeBlock = [regex]::Match($css, [regex]::Escape($codeRule) + '[^}]*}').Value
    if ($codeBlock -eq '') { throw 'CODE_RULE_NOT_FOUND' }
    $codeBlockBad = $codeBlock.Replace('color: #666;', 'color: #73787d;')
    if ($codeBlockBad -eq $codeBlock) { throw 'MUTATION_NOT_APPLIED=M03' }
    Assert-Fails 'M03_code_back_to_the_theme_grey' $css.Replace($codeBlock, $codeBlockBad) 'code:CONTRAST_BELOW_AA'
    $lowOverride = "`n#ksCatalogPage article.card-product .list-computer-memory li + li .caption { color: #666; }`n"
    Assert-Fails 'M04_code_override_with_fewer_ids_loses_the_cascade' ($css.Replace($codeBlock, $codeBlockBad) + $lowOverride) 'code:CONTRAST_BELOW_AA'
    $catRule = '#ksCatalogPage article.card-product .product-tag {'
    $catStart = $css.IndexOf($catRule); if ($catStart -lt 0) { throw 'CATEGORY_RULE_NOT_FOUND' }
    $catBlock = [regex]::Match($css.Substring($catStart), '^[^}]*}').Value
    $catNoColor = $catBlock.Replace('  color: #666;' + "`n", '')
    if ($catNoColor -eq $catBlock) { throw 'MUTATION_NOT_APPLIED=M05' }
    Assert-Fails 'M05_category_colour_removed_with_the_old_theme_grey' $css.Replace($catBlock, $catNoColor) 'cat:CONTRAST_BELOW_AA' -ThemeOldGrey
    Assert-Fails 'M06_category_selector_no_longer_matches_with_the_old_theme_grey' $css.Replace($catRule, '#ksCatalogPage article.card-product .product-tag-x {') 'cat:CONTRAST_BELOW_AA' -ThemeOldGrey
    $noteRule = "#ksCatalogPage .ks-price-basis-note {`n  color: #666;`n}"
    Assert-Fails 'M07_note_rule_removed_with_the_old_theme_grey' (Mutate-Text $css $noteRule '' 'M07') 'note:CONTRAST_BELOW_AA' -ThemeOldGrey
    Assert-Fails 'M08_disclosure_red_back_to_the_theme' (Mutate-Text $css "  color: #d80027;`n  background: var(--white, #fff);" "  color: #ff3d3d;`n  background: var(--white, #fff);" 'M08') 'disclosureClosed:CONTRAST_BELOW_AA'
    Assert-Fails 'M09_widened_to_the_availability_text' ($css + "`n#ksCatalogPage article.card-product .ks-availability__status-text { color: #666; }`n") 'avail:COLOR_CHANGED'
    Assert-Fails 'M10_recent_card_category_overridden_back_to_grey' ($css + "`n#ksCatalogPage .ks-recently-viewed-block .ks-recent-card .ks-card-category { color: #73787d; }`n") 'rCatA:CONTRAST_BELOW_AA'
    Assert-Fails 'M13_recent_div_card_category_rule_loses_its_colour_with_the_old_theme_grey' (Mutate-Text $css "  color: #666;`n  min-height: 18px;" "  min-height: 18px;" 'M13') 'rCatD:CONTRAST_BELOW_AA' -ThemeOldGrey
    Assert-Fails 'M14_recent_brand_code_rule_removed_with_the_old_theme_grey' (Mutate-Text $css "#ksCatalogPage .ks-catalog-card .ks-card-brand-code {`n  color: #666;`n}" '' 'M14') 'rBrandD:CONTRAST_BELOW_AA' -ThemeOldGrey

    # Mutazione sul markup ancorato: la classe della nota o il buster spariscono dalla pagina.
    if (Test-MarkupAnchors (Mutate-Text $aspx 'ks-price-basis-note' 'ks-price-note' 'M11')) { throw 'MUTATION_NOT_DETECTED=M11_note_class_removed_from_the_page' }
    Write-Output 'PASS MUTATION_DETECTED M11_note_class_removed_from_the_page'
    if (Test-MarkupAnchors (Mutate-Text $aspx '?v=20261119-compact-1a' '?v=20261114-deadcode-c1a' 'M12')) { throw 'MUTATION_NOT_DETECTED=M12_css_buster_not_bumped' }
    Write-Output 'PASS MUTATION_DETECTED M12_css_buster_not_bumped'

    Write-Output 'CATALOG_GREY_AA_ALL_PASS'
}
finally {
    if ($browser) { Stop-KsBrowser $browser }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
