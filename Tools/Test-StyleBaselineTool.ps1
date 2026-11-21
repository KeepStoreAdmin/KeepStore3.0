[CmdletBinding()]
param([switch]$SkipMutants)

# STYLE-BASELINE-1A. Prova dello strumento Tools/Get-KeepStoreStyleBaseline.ps1 (fotografia dello stile).
# Il test scrive una pagina di prova locale con markup uguale a quello dei produttori reali (scheda delle occasioni, scheda della
# griglia, prezzo dell'anteprima rapida, riquadro del prezzo a quantita) e stili noti, la apre in Edge e la fa leggere dallo STESSO
# raccoglitore dello strumento (caricato con -Library). Le attese sono scritte a mano qui sotto.
# Prova anche il confronto fra due fotografie (uno scambio di colore fra prezzo normale e prezzo scontato dello stesso produttore
# deve essere un ERRORE) e il controllo dell'origine (solo sito LAB). Mutazioni: copia dello strumento alterata, stesse attese.
# Nessun sito, nessun database, nessuna rete. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'Get-KeepStoreStyleBaseline.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ks-stylebase-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$css = @'
body{font-family:Arial,sans-serif;font-size:16px;color:#1F2933;background:#F5F5F5;margin:0}
h1{font-size:26px;font-weight:700}
h2{font-size:24px;font-weight:700}
.card-product{background:#FFFFFF;border:1px solid #E7EBF0;border-radius:8px;padding:8px;width:300px}
.ks-grid-card{border-radius:6px}
.name-product{font-size:14px;font-weight:600;color:#004EC3;text-decoration:none;display:block}
.ks-card-category{font-size:12px;color:#666666;margin:0}
.ks-home-price-value--current{font-size:22px;font-weight:700;color:__NORMAL__}
.is-sale .ks-home-price-value--current{color:__SALE__}
.ks-home-price-value--old{font-size:14px;color:#666666}
.old-price{position:relative;display:inline-flex}
.old-price::before{content:"";position:absolute;left:0;top:50%;width:100%;height:1px;background:#666666}
.ks-home-promo-tier{font-size:12px;color:#333E48}
.ks-home-promo-tier strong{color:#D80027;font-weight:700}
.box-sale-tag{background:#D80027;color:#FFFFFF;border-radius:999px;font-size:12px;font-weight:700;display:inline-block;padding:4px 8px}
.tf-btn{display:inline-block;font-size:15px;font-weight:600;padding:10px 16px;text-decoration:none}
.btn-fill{background:#D80027;color:#FFFFFF;border-radius:8px}
.btn-line{background:transparent;color:#333E48;border:1px solid #E1E1E1;border-radius:6px}
.btn-side{background:#FFFFFF;color:#333E48;border-radius:8px;border-left:3px solid #D80027}
.btn-shadow-a{background:#FFFFFF;color:#333E48;border-radius:8px;box-shadow:0 1px 2px rgba(0,0,0,.2)}
.btn-shadow-b{background:#FFFFFF;color:#333E48;border-radius:8px;box-shadow:0 8px 24px rgba(0,0,0,.4)}
.veil{background:rgba(0,0,0,.5);padding:8px}
.veil p{color:#FFFFFF;font-size:14px;margin:0}
.struck{text-decoration:line-through}
.gone{opacity:0}
.tot{font-size:18px;font-weight:700}
input[type=text]{font-size:16px;border:1px solid #CCCCCC;border-radius:8px;height:44px;padding:0 12px}
'@
$body = @'
<h1>Titolo pagina</h1>
<h2>Titolo sezione</h2>
<h2 class="gone">Titolo sezione nascosto</h2>
<div class="card-product style-border ks-deal-card is-sale">
  <div class="box-sale-tag">-17%</div>
  <p class="caption ks-card-category">Categoria</p>
  <h6><a class="name-product ks-card-title" href="#">Articolo A</a></h6>
  <p class="price-wrap ks-home-price-slot"><span class="new-price ks-home-price-value ks-home-price-value--current" style="font-size:28px">5,00</span><span class="old-price ks-home-price-value ks-home-price-value--old">6,00</span></p>
</div>
<div class="card-product style-img-border ks-grid-card">
  <p class="caption ks-card-category">Categoria</p>
  <a class="name-product ks-card-title" href="#">Articolo B</a>
  <p class="price-wrap ks-home-price-slot"><span class="new-price ks-home-price-value ks-home-price-value--current">1.000,00</span></p>
</div>
<div class="card-product style-img-border ks-grid-card is-sale">
  <a class="name-product ks-card-title" href="#">Articolo B2</a>
  <p class="price-wrap ks-home-price-slot"><span class="new-price ks-home-price-value ks-home-price-value--current">9,00</span><span class="old-price ks-home-price-value ks-home-price-value--old">10,00</span></p>
</div>
<div class="card-product style-img-border ks-grid-card">
  <a class="name-product ks-card-title" href="#">Articolo C</a>
  <p class="price-wrap ks-home-price-slot"><span class="new-price ks-home-price-value ks-home-price-value--current" style="font-size:21px">8,00</span></p>
  <p class="caption ks-home-promo-tier">Da <strong>7,00</strong> - Minimo 5 pz.</p>
</div>
<div class="card-product style-img-border ks-grid-card">
  <a class="name-product ks-card-title" href="#">Articolo D</a>
  <p class="price-wrap ks-home-price-slot"><span class="new-price ks-home-price-value ks-home-price-value--current" style="font-size:20px">Prezzo su richiesta</span></p>
</div>
<div class="price-text fw-medium text-primary"><span class="new-price price-text fw-medium mb-0">4,00</span> <span class="old-price body-md-2">4,50</span></div>
<h4 class="text-primary" id="ksQuickViewPrice">12,34</h4>
<p class="struck"><span><b>9,99</b></span></p>
<div class="tot">1000,<span>50</span></div>
<div class="veil"><p>3,00</p></div>
<a class="tf-btn btn-fill" href="#">Compra</a>
<a class="tf-btn btn-line" href="#">Dettagli</a>
<a class="tf-btn btn-side" href="#">Bordo laterale</a>
<a class="tf-btn btn-shadow-a" href="#">Ombra A</a>
<a class="tf-btn btn-shadow-b" href="#">Ombra B</a>
<a class="tf-btn btn-fill" href="#" style="display:none;border-radius:3px">Nascosto</a>
<input type="text" value="">
'@
function Write-Fixture([string]$name, [string]$normal, [string]$sale) {
    $p = Join-Path $tmp $name
    $html = '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8"><title>prova</title><style>' + $css.Replace('__NORMAL__', $normal).Replace('__SALE__', $sale) + '</style></head><body>' + $body + '</body></html>'
    [IO.File]::WriteAllText($p, $html, $utf8)
    return ('file:///' + $p.Replace('\', '/'))
}
$urlA = Write-Fixture 'a.html' '#000000' '#D80027'
$urlB = Write-Fixture 'b.html' '#D80027' '#000000'   # scambio di colore fra prezzo normale e prezzo scontato

# Esegue tutte le attese con lo strumento indicato (originale o copia mutata). Restituisce l'elenco dei difetti.
function Invoke-Checks([string]$toolPath, $browser) {
    . $toolPath -Library
    $bad = New-Object Collections.Generic.List[string]
    Open-KsUrl $browser $urlA 60
    $a = Read-KsbPage $browser 'prova' 1280 $true ''
    $items = @($a.items)
    function Find([string]$role, [string]$text) { return @($items | Where-Object { [string]$_.role -eq $role -and [string]$_.text -eq $text }) }
    function Expect([string]$id, [string]$text, [string]$prod, [string]$state, [string]$sigPattern) {
        $f = @(Find 'prezzo' $text)
        if ($f.Count -ne 1) { $bad.Add($id + ' prezzo ' + $text + ': trovato ' + $f.Count + ' volte'); return }
        if ([string]$f[0].prod -ne $prod) { $bad.Add($id + ' produttore ' + [string]$f[0].prod + ' invece di ' + $prod) }
        if ([string]$f[0].state -ne $state) { $bad.Add($id + ' stato ' + [string]$f[0].state + ' invece di ' + $state) }
        if ([string]$f[0].vis -ne 'si') { $bad.Add($id + ' non visibile') }
        if ($sigPattern -ne '' -and [string]$f[0].sig -notmatch $sigPattern) { $bad.Add($id + ' firma inattesa: ' + [string]$f[0].sig) }
    }
    Expect 'P01' '5,00' 'scheda-occasioni' 'sconto-immediato' '^Arial \| 28px \| 700 \| .*#D80027 \| su #FFFFFF$'
    Expect 'P02' '6,00' 'scheda-occasioni' 'barrato' '#666666'
    Expect 'P03' '1.000,00' 'scheda-griglia-home' 'normale' '^Arial \| 22px \| 700 \| .*#000000 \| su #FFFFFF$'
    Expect 'P04' '9,00' 'scheda-griglia-home' 'sconto-immediato' '22px \| 700 \| .*#D80027'
    Expect 'P05' '10,00' 'scheda-griglia-home' 'barrato' ''
    Expect 'P06' '8,00' 'scheda-griglia-home' 'normale+quantita' '21px'
    Expect 'P07' '7,00' 'scheda-griglia-home' 'prezzo-quantita' '#D80027'
    Expect 'P08' 'Prezzo su richiesta' 'scheda-griglia-home' 'su-richiesta' '20px'
    Expect 'P09' '12,34' 'anteprima-rapida' 'importo' ''
    Expect 'P10' '9,99' 'pagina' 'barrato' 'line-through'
    Expect 'P11' '1000,50' 'pagina' 'importo' '18px \| 700'
    Expect 'P13' '4,00' 'pagina' 'sconto-immediato' ''   # scheda prodotto: il prezzo corrente ha esso stesso la classe del contenitore
    Expect 'P12' '3,00' 'pagina' 'importo' '#FFFFFF \| su #7[9A-C]7[9A-C]7[9A-C]$'
    if (@($items | Where-Object { [string]$_.role -eq 'sottotitolo' -and [string]$_.prod -eq 'anteprima-rapida' }).Count -ne 1) { $bad.Add('R01 il prezzo dentro il titolo resta anche fra i sottotitoli') }
    $h2 = @($items | Where-Object { [string]$_.role -eq 'titolo-sezione' })
    if (@($h2 | Where-Object { [string]$_.vis -eq 'si' }).Count -ne 1 -or @($h2 | Where-Object { [string]$_.vis -eq 'no' }).Count -ne 1) { $bad.Add('V01 titolo con opacita zero contato come non visibile') }
    $btn = @($items | Where-Object { [string]$_.role -eq 'pulsante' })
    if (@($btn | Where-Object { [string]$_.vis -eq 'si' }).Count -ne 5) { $bad.Add('B01 cinque pulsanti visibili = cinque firme (trovate ' + @($btn | Where-Object { [string]$_.vis -eq 'si' }).Count + ')') }
    if (@($btn | Where-Object { [string]$_.vis -eq 'no' -and [string]$_.sig -match 'raggio 3 ' }).Count -ne 1) { $bad.Add('V02 pulsante nascosto contato come non visibile') }
    if (@($btn | Where-Object { [string]$_.sig -match 'bordo 0/0/0/3 #D80027' }).Count -ne 1) { $bad.Add('B02 bordo solo a sinistra nella firma') }
    if (@($btn | Where-Object { [string]$_.sig -match 'ombra ' }).Count -ne 2) { $bad.Add('B03 due ombre diverse = due firme') }
    $cards = @($items | Where-Object { [string]$_.role -eq 'scheda' })
    if (@($cards | Where-Object { [string]$_.prod -eq 'scheda-occasioni' -and [string]$_.sig -match 'raggio 8 \| bordo 1 #E7EBF0' }).Count -ne 1 -or @($cards | Where-Object { [string]$_.prod -eq 'scheda-griglia-home' -and [string]$_.sig -match 'raggio 6 ' }).Count -ne 1) { $bad.Add('S01 superficie delle schede per produttore') }
    if (@($a.radii | Where-Object { [string]$_.r -eq 'tondo o pillola' }).Count -ne 1) { $bad.Add('S02 raggi: il bollino e una pillola') }
    # testi: solo prezzi e bollini
    if (@($items | Where-Object { [string]$_.text -ne '' -and @('prezzo', 'bollino') -notcontains [string]$_.role }).Count -ne 0) { $bad.Add('T01 testo raccolto fuori da prezzi e bollini') }
    Open-KsUrl $browser $urlA 60
    $noText = Read-KsbPage $browser 'prova' 1280 $false ''
    if (@($noText.items | Where-Object { [string]$_.text -ne '' }).Count -ne 0) { $bad.Add('T02 senza testi non si raccoglie nessun testo') }
    # confronto
    $same = Compare-KsbBaseline @($a) @($noText)
    if ($same.Errors.Count -ne 0 -or $same.Warnings.Count -ne 0) { $bad.Add('C01 due letture della stessa pagina: nessuna differenza (errori ' + $same.Errors.Count + ', avvisi ' + $same.Warnings.Count + ')') }
    Open-KsUrl $browser $urlB 60
    $b = Read-KsbPage $browser 'prova' 1280 $true ''
    $swap = Compare-KsbBaseline @($a) @($b)
    if (@($swap.Errors | Where-Object { $_ -match '\|scheda-griglia-home\|normale\|si ' }).Count -ne 1 -or @($swap.Errors | Where-Object { $_ -match '\|scheda-griglia-home\|sconto-immediato\|si ' }).Count -ne 1) { $bad.Add('C02 scambio di colore fra prezzo normale e scontato = ERRORE su entrambe le chiavi (errori: ' + $swap.Errors.Count + ')') }
    $less = [pscustomobject]@{ name = 'prova'; width = 1280; items = @($items | Where-Object { [string]$_.role -ne 'bollino' }) }
    $gone = Compare-KsbBaseline @($a) @($less)
    if ($gone.Errors.Count -ne 0 -or @($gone.Warnings | Where-Object { $_ -match '^scomparsa: .*\|bollino\|' }).Count -ne 1) { $bad.Add('C03 chiave scomparsa = AVVISO, non errore') }
    # unione delle letture della HOME
    $m = Merge-KsbReads @($a, $b)
    if (@($m.items | Where-Object { $_.rotation }).Count -lt 2 -or @($m.items | Where-Object { [string]$_.role -eq 'titolo-pagina' -and $_.rotation }).Count -ne 0) { $bad.Add('U01 unione: firma non presente in tutte le letture marcata come dipendente dalla rotazione') }
    # copertura
    $cov = Get-KsbCoverage @($a)
    if (-not $cov.ContainsKey('scheda-griglia-home') -or -not $cov['scheda-griglia-home'].ContainsKey('su-richiesta') -or $cov['scheda-occasioni'].ContainsKey('normale')) { $bad.Add('K01 copertura produttore x stato') }
    # origine: solo sito LAB
    if (-not (Test-KsbAllowedBase 'https://www.taikun.it:18843/')) { $bad.Add('O01 sito LAB ammesso') }
    foreach ($x in @('https://www.taikun.it:8443/', 'https://www.taikun.it/', 'http://www.taikun.it:18843/', 'https://example.com:18843/', 'https://www.taikun.it.example.com:18843/')) { if (Test-KsbAllowedBase $x) { $bad.Add('O02 origine non ammessa accettata: ' + $x) } }
    return $bad
}

$exit = 0
$browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900 -ExtraArgs '--allow-file-access-from-files'
try {
    $bad = @(Invoke-Checks $tool $browser)
    foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) }
    if ($bad.Count -gt 0) { $exit = 1 }
    if (-not $SkipMutants -and $exit -eq 0) {
        $src = [IO.File]::ReadAllText($tool, [Text.Encoding]::ASCII)
        $mutants = @(
            @{ Id = 'M1_STATE_NOT_IN_KEY'; Expect = 'C02'; Old = 'function state(e,ask){'; New = "function state(e,ask){return 'x';" },
            @{ Id = 'M2_STRUCK_BY_CLASS_IGNORED'; Expect = 'P02'; Old = "if(e.closest(OLD)||struck(e))return 'barrato';"; New = "if(struck(e))return 'barrato';" },
            @{ Id = 'M3_VISIBILITY_IGNORED'; Expect = 'V01'; Old = 'function vis(e){'; New = 'function vis(e){return true;' },
            @{ Id = 'M4_ORIGIN_NOT_CHECKED'; Expect = 'O02'; Old = '$u.Port -eq $KsbPort'; New = '$true' }
        )
        foreach ($mu in $mutants) {
            if ($src.IndexOf($mu.Old, [StringComparison]::Ordinal) -lt 0 -or $src.IndexOf($mu.Old, [StringComparison]::Ordinal) -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            $mp = Join-Path $tmp ($mu.Id + '.ps1')
            [IO.File]::WriteAllText($mp, $src.Replace($mu.Old, $mu.New), [Text.Encoding]::ASCII)
            $mb = @(Invoke-Checks $mp $browser)
            if (@($mb | Where-Object { $_ -match ('^' + $mu.Expect + ' ') }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id); $exit = 1 }
        }
    }
} finally {
    Stop-KsBrowser $browser
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($exit -eq 0) { Write-Host ('STYLE_BASELINE_TOOL PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } else { ' (4 mutazioni uccise)' })) } else { Write-Host 'STYLE_BASELINE_TOOL FAIL' }
exit $exit
