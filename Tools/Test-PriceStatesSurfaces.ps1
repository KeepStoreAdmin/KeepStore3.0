[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$Query = 'carta', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# STYLE-PRICE-STATES-1B e 1C. Prezzo dell'articolo nelle superfici condivise che la prova di 1A esclude per costruzione (modale e testata).
#  - Suggerimenti della ricerca in testata: solo il prezzo corrente -> nero (1B).
#  - Anteprima rapida (1C): mostra lo STESSO stato della scheda da cui si apre. Da scheda in sconto: prezzo rosso prezzo e prezzo
#    precedente barrato con lo stesso testo del barrato della scheda. Da scheda normale: nero, nessun prezzo precedente, anche subito
#    dopo un'anteprima in sconto. "Prezzo su richiesta": nero, nessun precedente. Il browser non calcola importi: legge data-ks-old-price,
#    scritto dal server solo quando la scheda mostra lo sconto. Tre produttori: HOME, elenco, correlati della scheda prodotto.
#    Scheda prodotto: si apre quella del primo articolo in sconto della HOME; la scheda dell'articolo stesso ("self") e obbligatoria,
#    un altro correlato in sconto ("other?") si prova se c'e (dipende dalla rotazione della HOME).
# Colori attesi ESATTI; un bersaglio assente o invisibile fa fallire la prova (NON PROVATO).
# Sito LAB (https, 127.0.0.1, porta 18843), due aziende; mutazioni sulla copia LAB, file rimessi alla fine. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$flags = 'Public\assets\keepstore\js\ks-page-flags.js'
$prodJs = 'Public\assets\keepstore\js\keepstore-product.js'
$pages4 = @('Default.aspx', 'articoli.aspx', 'articolo.aspx', 'compare.aspx')
$files = @('Page.master', $flags, $prodJs, 'Default.aspx.vb', 'articoli.aspx.vb', 'articolo.aspx.vb', 'App_Code\UiPriceFormatter.vb', 'Public\assets\keepstore\css\price-states.css') + $pages4
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PRICE_STATES_SURFACES FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$src = @{}; foreach ($f in $files) { $src[$f] = (Get-Text $repoBytes[$f]).Replace("`r`n", "`n") }
$black = 'rgb(0, 0, 0)'
$red = 'rgb(216, 0, 39)'
$ver = '20261122-price-states-1c'

function Test-Source($t) {
    $bad = New-Object Collections.Generic.List[string]
    $master = $t['Page.master']; $js = $t[$flags]; $pj = $t[$prodJs]
    if ($master -notmatch '<h4 class="ks-price-state--normal" id="ksQuickViewPrice">') { $bad.Add('S1 il prezzo dell''anteprima non parte con la sola classe di stato normale') }
    if ($master -notmatch '<span class="old-price text-main-2" id="ksQuickViewOldPriceWrap" hidden><span class="visually-hidden">Prezzo precedente: </span><span id="ksQuickViewOldPrice"></span></span>') { $bad.Add('S1 manca il prezzo precedente dell''anteprima (nascosto, con etichetta)') }
    if ($js -notmatch '\.ks-suggest-price\{[^}]*color:var\(--ks-price-normal,#000\)') { $bad.Add('S2 il prezzo dei suggerimenti non usa il colore del prezzo normale') }
    if ($js -match '\.ks-suggest-price\{[^}]*#b0001f') { $bad.Add('S2 rosso fisso nel prezzo dei suggerimenti') }
    if ($master -notmatch 'js/ks-page-flags\.js"\) %>\?v=20261122-price-states-1b') { $bad.Add('S3 versione dello script dei suggerimenti non aggiornata') }
    if (-not $pj.Contains("price.className = 'ks-price-state--' + state;")) { $bad.Add('S4 lo script non assegna per intero la classe di stato del prezzo') }
    $i = $pj.IndexOf('function setQuickViewPrice'); $body = $(if ($i -ge 0) { $pj.Substring($i, [Math]::Min(900, $pj.Length - $i)) } else { '' })
    if ($body -match 'text-primary|parseFloat|toFixed|Number\(') { $bad.Add('S4 lo script usa una classe generica o calcola importi nel browser') }
    if (-not $pj.Contains("oldPrice: link.getAttribute('data-ks-old-price') || ''")) { $bad.Add('S4 lo script non legge data-ks-old-price') }
    foreach ($p in $pages4) { if (-not $t[$p].Contains('js/keepstore-product.js") %>?v=' + $ver + '"')) { $bad.Add('S5 versione dello script dell''anteprima non aggiornata in ' + $p) } }
    if ($t['Public\assets\keepstore\css\price-states.css'] -notmatch '\.ks-price-state--sale\s*\{\s*color:\s*var\(--ks-price-accent, #D80027\) !important;') { $bad.Add('S6 il rosso dello sconto non usa il rosso prezzo') }
    if (-not $t['articolo.aspx.vb'].Contains('            .OldPriceValue = price.OldPrice,') -or -not $t['articolo.aspx.vb'].Contains('                item.OldPriceValue = price.OldPrice')) { $bad.Add('S8 la scheda prodotto non porta il prezzo precedente in entrambe le costruzioni degli articoli') }
    foreach ($p in @('Default.aspx.vb', 'articoli.aspx.vb', 'articolo.aspx.vb')) { if (([regex]::Matches($t[$p], 'data-ks-old-price')).Count -ne 1) { $bad.Add('S7 ' + $p + ' non scrive data-ks-old-price in un solo punto') } }
    return $bad
}

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }
$scanJs = @'
(function(){function t(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
var L=[].slice.call(document.querySelectorAll('.js-ks-quickview'));var rows=[];
L.forEach(function(a,i){var c=a.closest('.card-product')||a.closest('.swiper-slide,li,article')||a.parentElement;
var np=c.querySelector('.new-price');var op=c.querySelector('.old-price');if(!np)return;
var m=np.className.match(/ks-price-state--(\w+)/);rows.push({i:i,id:a.getAttribute('data-ks-id')||'',state:m?m[1]:'',price:t(np),old:t(op)});});
return JSON.stringify(rows);})()
'@
$openJs = "(function(i){var a=document.querySelectorAll('.js-ks-quickview')[i];if(!a)return 0;a.click();return 1;})"
$injectJs = @'
(function(){var a=document.getElementById('ksTestAsk');if(!a){a=document.createElement('a');a.id='ksTestAsk';a.className='js-ks-quickview';a.href='#quickView';
a.setAttribute('data-ks-id','1');a.setAttribute('data-ks-title','Prova');a.setAttribute('data-ks-url',location.pathname);
a.setAttribute('data-ks-price','Prezzo su richiesta');a.setAttribute('data-ks-old-price','9,99');document.body.appendChild(a);}a.click();return 1;})()
'@
$readJs = @'
(function(){function t(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
var e=document.getElementById('ksQuickViewPrice');if(!e)return JSON.stringify({found:false});var r=e.getBoundingClientRect();var m=document.getElementById('quickView');
var w=document.getElementById('ksQuickViewOldPriceWrap');var o=document.getElementById('ksQuickViewOldPrice');var wr=w?w.getBoundingClientRect():null;
var box=e.parentElement.getBoundingClientRect();var line=w?getComputedStyle(w,'::before'):null;
return JSON.stringify({found:true,shown:!!(m&&m.classList.contains('show')),visible:r.width>1&&r.height>1,text:t(e),cls:e.className,color:getComputedStyle(e).color,
hasOld:!!(w&&o),oldHidden:!!(w&&w.hidden),oldVisible:!!(wr&&wr.width>1&&wr.height>1),oldText:t(o),oldColor:w?getComputedStyle(w).color:'',
oldLine:!!(line&&line.content!=='none'&&parseFloat(line.height)>=1),inside:!wr||(wr.right<=box.right+1&&r.right<=box.right+1&&box.right<=document.documentElement.clientWidth+1)});})()
'@
$closeJs = "(function(){var x=document.querySelector('#quickView .btn-close,#quickView [data-bs-dismiss=""modal""]');if(x)x.click();return 1;})()"
$typeJs = "(function(q){var i=document.querySelector('[data-ks-search-form=""desktop""] input[type=text],[data-ks-search-form=""desktop""] input[type=search]');if(!i)return 0;i.focus();i.value=q;i.dispatchEvent(new Event('input',{bubbles:true}));i.dispatchEvent(new KeyboardEvent('keyup',{bubbles:true,key:'a'}));return 1;})"
$suggestJs = @'
(function(){var p=document.getElementById('ksSearchSuggestDesktop');var a=p?[].slice.call(p.querySelectorAll('.ks-suggest-price')):[];
var v=a.filter(function(e){var r=e.getBoundingClientRect();return r.width>1&&r.height>1&&/\d,\d{2}/.test(e.textContent||'');});
var colors={};v.forEach(function(e){colors[getComputedStyle(e).color]=1;});return JSON.stringify({all:a.length,visible:v.length,colors:Object.keys(colors)});})()
'@
function Get-Amount([string]$s) { $m = [regex]::Match($s, '\d[\d\.]*,\d{2}'); if (-not $m.Success) { return -1 }; return [decimal]::Parse($m.Value.Replace('.', '').Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture) }
function Open-Page($b, [string]$url) { try { Open-KsUrl $b $url 300 } catch { Start-Sleep -Seconds 4; Open-KsUrl $b $url 300 } }
function Read-Preview($b, $bad, [string]$tag) {
    $s = $null
    foreach ($i in 1..8) { Start-Sleep -Milliseconds 600; $s = ConvertFrom-Json ([string](Invoke-KsJs $b $readJs)); if ([bool]$s.found -and [bool]$s.shown -and [bool]$s.visible) { break } }
    Start-Sleep -Milliseconds 700
    $s = ConvertFrom-Json ([string](Invoke-KsJs $b $readJs))
    if (-not [bool]$s.found -or -not [bool]$s.shown -or -not [bool]$s.visible) { $bad.Add('NON PROVATO ' + $tag + ': anteprima non aperta o prezzo non visibile'); return $null }
    return $s
}
function Close-Preview($b) {
    # Attende la fine della chiusura (animazione compresa): un'apertura durante la transizione verrebbe ignorata.
    $null = Invoke-KsJs $b $closeJs
    foreach ($i in 1..20) { Start-Sleep -Milliseconds 300; if ([int](Invoke-KsJs $b "(function(){var m=document.getElementById('quickView');return (m&&(m.classList.contains('show')||m.style.display==='block'))||document.querySelector('.modal-backdrop')?1:0;})()") -eq 0) { break } }
    Start-Sleep -Milliseconds 400
}
function Test-Sale($b, $bad, [string]$tag, $row, [string]$shot) {
    if ([int](Invoke-KsJs $b ($openJs + '(' + [int]$row.i + ')')) -ne 1) { $bad.Add('NON PROVATO ' + $tag + ': comando non trovato'); return }
    # Un'apertura puo andare persa se il browser di prova e ancora occupato: si riprova una volta, poi vale la lettura.
    $up = 0; foreach ($i in 1..8) { Start-Sleep -Milliseconds 500; $up = [int](Invoke-KsJs $b "(function(){var m=document.getElementById('quickView');return m&&m.classList.contains('show')?1:0;})()"); if ($up -eq 1) { break } }
    if ($up -ne 1) { Close-Preview $b; $null = Invoke-KsJs $b ($openJs + '(' + [int]$row.i + ')') }
    $s = Read-Preview $b $bad $tag
    if ($null -ne $s) {
        if ([string]$s.text -ne [string]$row.price) { $bad.Add('C testo ' + $tag + ': anteprima "' + [string]$s.text + '", scheda "' + [string]$row.price + '"') }
        if ([string]$s.color -ne $red -or [string]$s.cls -ne 'ks-price-state--sale') { $bad.Add('C sconto non mostrato ' + $tag + ': colore ' + [string]$s.color + ', classe "' + [string]$s.cls + '"') }
        if (-not [bool]$s.oldVisible -or [string]$s.oldText -ne [string]$row.old) { $bad.Add('C prezzo precedente ' + $tag + ': visibile=' + [string]$s.oldVisible + ' testo "' + [string]$s.oldText + '", scheda "' + [string]$row.old + '"') }
        elseif ((Get-Amount ([string]$s.oldText)) -le (Get-Amount ([string]$s.text))) { $bad.Add('C prezzo precedente non maggiore ' + $tag) }
        elseif (-not [bool]$s.oldLine -or [string]$s.oldColor -eq $black -or [string]$s.oldColor -eq $red) { $bad.Add('C prezzo precedente non barrato o non grigio ' + $tag + ': ' + [string]$s.oldColor) }
        if (-not [bool]$s.inside) { $bad.Add('C traboccamento del prezzo ' + $tag) }
        if ($shot -ne '') { Save-KsScreenshot $b $shot }
    }
    Close-Preview $b
}
function Test-Plain($b, $bad, [string]$tag, [string]$expectText, [string]$expectClass) {
    $s = Read-Preview $b $bad $tag
    if ($null -ne $s) {
        if ($expectText -ne '' -and [string]$s.text -ne $expectText) { $bad.Add('A testo ' + $tag + ': anteprima "' + [string]$s.text + '", atteso "' + $expectText + '"') }
        if ([string]$s.color -ne $black) { $bad.Add('A colore anteprima ' + $tag + ': ' + [string]$s.color + ' (atteso ' + $black + ')') }
        if ([string]$s.cls -ne $expectClass) { $bad.Add('A classe ' + $tag + ': "' + [string]$s.cls + '" (attesa ' + $expectClass + ')') }
        if (-not [bool]$s.hasOld) { $bad.Add('A manca l''elemento del prezzo precedente ' + $tag) }
        if ([bool]$s.oldVisible -or -not [bool]$s.oldHidden -or [string]$s.oldText -ne '') { $bad.Add('A prezzo precedente rimasto ' + $tag + ': visibile=' + [string]$s.oldVisible + ' testo "' + [string]$s.oldText + '"') }
    }
    Close-Preview $b
}
# Una pagina: sconto A -> normale -> richiesta (comando iniettato) -> sconto B. $Need: quali schede in sconto servono ('any','self','other').
function Test-Page($b, $bad, [string]$tag, [string]$selfId, [string[]]$Need, [bool]$needNormal, [string]$shot) {
    Start-Sleep -Milliseconds 2000
    $null = Invoke-KsJs $b 'window.scrollTo(0,document.body.scrollHeight)'; Start-Sleep -Milliseconds 1500
    $j = ConvertFrom-Json ([string](Invoke-KsJs $b $scanJs)); $rows = @($j | ForEach-Object { $_ })
    $sale = @($rows | Where-Object { $_.state -eq 'sale' -and [string]$_.old -ne '' })
    $normal = @($rows | Where-Object { $_.state -eq 'normal' })
    $picks = New-Object Collections.Generic.List[object]
    foreach ($n in $Need) {
        $p = $null
        if ($n -eq 'any') { $p = $sale | Select-Object -First 1 }
        elseif ($n -eq 'self') { $p = $sale | Where-Object { [string]$_.id -eq $selfId } | Select-Object -First 1 }
        elseif ($n -like 'other*') { $p = $sale | Where-Object { [string]$_.id -ne $selfId } | Select-Object -Last 1 }
        if ($null -eq $p -and $n -eq 'other?') { continue }
        if ($null -eq $p) { $bad.Add('NON PROVATO ' + $tag + ' sconto(' + $n + '): nessuna scheda in sconto adatta (' + $sale.Count + ' in sconto su ' + $rows.Count + ')') } else { $picks.Add(@{ n = $n; row = $p }) }
    }
    $first = $true
    foreach ($p in $picks) {
        Test-Sale $b $bad ($tag + ' sconto(' + $p.n + ')') $p.row $(if ($first) { $shot } else { '' })
        if ($first) {
            $first = $false
            if ($normal.Count -gt 0) {
                $nr = $normal[0]
                if ([int](Invoke-KsJs $b ($openJs + '(' + [int]$nr.i + ')')) -eq 1) { Test-Plain $b $bad ($tag + ' normale dopo sconto') ([string]$nr.price) 'ks-price-state--normal' }
            } elseif ($needNormal) { $bad.Add('NON PROVATO ' + $tag + ': nessuna scheda a prezzo normale') }
            $null = Invoke-KsJs $b $injectJs
            Test-Plain $b $bad ($tag + ' richiesta dopo sconto') 'Prezzo su richiesta' 'ks-price-state--ask'
        }
    }
    if ($picks.Count -eq 0 -and $normal.Count -gt 0) {
        if ([int](Invoke-KsJs $b ($openJs + '(' + [int]$normal[0].i + ')')) -eq 1) { Test-Plain $b $bad ($tag + ' normale') ([string]$normal[0].price) 'ks-price-state--normal' }
    }
    return $sale
}
# Un browser per blocco di pagine; se il browser di prova si blocca (operazione annullata) il blocco si ripete con un browser nuovo.
function Use-Browser([int]$bw, [int]$bh, $bad, [scriptblock]$body) {
    foreach ($attempt in 1..3) {
        $local = New-Object Collections.Generic.List[string]
        $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $bw -Height $bh
        try {
            try { $null = Invoke-KsCdp $b 'Network.enable' @{}; $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
            & $body $b $local
            foreach ($x in $local) { $bad.Add($x) }
            return
        } catch { if ($attempt -eq 3 -or ([string]$_.Exception.Message) -match 'ORIGINE_INATTESA') { throw } }
        finally { Stop-KsBrowser $b }
        Start-Sleep -Seconds 3
    }
}
function Open-Checked($b, [string]$origin, [string]$path) { Open-Page $b ($origin + $path); if ([string](Invoke-KsJs $b 'location.origin') -ne $origin) { throw 'ORIGINE_INATTESA' } }
function Invoke-Lab([string[]]$Scope) {
    $bad = New-Object Collections.Generic.List[string]
    $ctx = @{ id = '' }
    foreach ($h in @('www.taikun.it', 'www.webaffare.it')) {
        $origin = 'https://' + $h + ':18843'
        $main = ($h -eq 'www.taikun.it')
        if ($main -and ($Scope -contains 'home' -or $Scope -contains 'scheda')) {
            Use-Browser 1280 900 $bad {
                param($b, $l)
                Open-Checked $b $origin '/'
                $homeSale = @()
                if ($Scope -contains 'home') { $homeSale = @(Test-Page $b $l ($h + ' HOME') '' @('any', 'other') $true $(if ($ShotDir -ne '') { Join-Path $ShotDir 'anteprima-home-sconto.png' } else { '' })) }
                else { Start-Sleep -Milliseconds 2500; $j = ConvertFrom-Json ([string](Invoke-KsJs $b $scanJs)); $homeSale = @($j | ForEach-Object { $_ } | Where-Object { $_.state -eq 'sale' }) }
                $ctx.id = [string]($homeSale | Where-Object { [string]$_.id -match '^\d+$' } | Select-Object -First 1 | ForEach-Object { $_.id })
            }
        }
        if ($Scope -contains 'elenco') {
            Use-Browser 1280 900 $bad {
                param($b, $l)
                Open-Checked $b $origin ('/articoli.aspx?q=' + $Query)
                $null = Test-Page $b $l ($h + ' elenco') '' $(if ($main) { @('any') } else { @() }) $true $(if ($ShotDir -ne '' -and $main) { Join-Path $ShotDir 'anteprima-elenco-sconto.png' } else { '' })
            }
        }
        if ($Scope -contains 'sugg') {
            Use-Browser 1280 900 $bad {
                param($b, $l)
                Open-Checked $b $origin ('/articoli.aspx?q=' + $Query)
                Start-Sleep -Milliseconds 1500
                $tag = $h + ' suggerimenti'
                if ([int](Invoke-KsJs $b ($typeJs + "('" + $Query + "')")) -ne 1) { $l.Add('B NON PROVATO ' + $tag + ': campo di ricerca della testata non trovato') }
                else {
                    $g = $null
                    foreach ($i in 1..10) { Start-Sleep -Milliseconds 800; $g = ConvertFrom-Json ([string](Invoke-KsJs $b $suggestJs)); if ([int]$g.visible -gt 0) { break } }
                    if ([int]$g.visible -lt 1) { $l.Add('B NON PROVATO ' + $tag + ': nessun prezzo visibile nei suggerimenti') }
                    elseif (@($g.colors).Count -ne 1 -or [string]@($g.colors)[0] -ne $black) { $l.Add('B colore suggerimenti ' + $tag + ': ' + (@($g.colors) -join ' / ') + ' (atteso ' + $black + ')') }
                    if ($ShotDir -ne '') { Save-KsScreenshot $b (Join-Path $ShotDir ('suggerimenti-' + $h + '.png')) }
                }
            }
        }
        if ($main -and $Scope -contains 'scheda') {
            if ($ctx.id -eq '') { $bad.Add('NON PROVATO ' + $h + ' scheda: nessun articolo in sconto in HOME da cui aprire la scheda') }
            else {
                Use-Browser 1280 900 $bad {
                    param($b, $l)
                    Open-Checked $b $origin ('/articolo.aspx?id=' + $ctx.id)
                    $null = Test-Page $b $l ($h + ' scheda') $ctx.id @('self', 'other?') $false $(if ($ShotDir -ne '') { Join-Path $ShotDir 'anteprima-scheda-sconto.png' } else { '' })
                }
            }
        }
    }
    if ($Scope -contains 'stretto') {
        $origin = 'https://www.taikun.it:18843'; $h = 'www.taikun.it'
        Use-Browser 390 844 $bad {
            param($b, $l)
            Open-Checked $b $origin ('/articoli.aspx?q=' + $Query)
            $null = Test-Page $b $l 'www.taikun.it elenco 390' '' @('any') $false $(if ($ShotDir -ne '') { Join-Path $ShotDir 'anteprima-elenco-sconto-390.png' } else { '' })
        }
    }
    return $bad
}

$exit = 0
$all = @('home', 'elenco', 'sugg', 'scheda', 'stretto')
$sb0 = @(Test-Source $src)
if ($sb0.Count -gt 0) { $exit = 1; foreach ($b in $sb0) { Write-Host ('  FAIL ' + $b) } } else { Write-Host '  ok   sorgente: stato e prezzo precedente nell''anteprima, suggerimenti, versioni degli script' }
$h4 = '<h4 class="ks-price-state--normal" id="ksQuickViewPrice">'
$rule = 'color:var(--ks-price-normal,#000);'
$mutants = @(
    @{ Id = 'M01_GENERIC_RED_CLASS_BACK'; File = 'Page.master'; Scope = @(); ExpectSrc = 'S1'; Old = $h4; New = '<h4 class="text-primary" id="ksQuickViewPrice">' },
    @{ Id = 'M02_OLD_PRICE_ELEMENT_REMOVED'; File = 'Page.master'; Scope = @('elenco'); Expect = 'C sconto non mostrato'; ExpectSrc = 'S1'; Old = '<span class="old-price text-main-2" id="ksQuickViewOldPriceWrap" hidden><span class="visually-hidden">Prezzo precedente: </span><span id="ksQuickViewOldPrice"></span></span>'; New = '' },
    @{ Id = 'M03_SUGGEST_FIXED_RED_BACK'; File = $flags; Scope = @('sugg'); Expect = 'B colore suggerimenti'; ExpectSrc = 'S2'; Old = $rule; New = 'color:#b0001f;' },
    @{ Id = 'M04_SUGGEST_FOLLOWS_SHOP_ACCENT'; File = $flags; Scope = @('sugg'); Expect = 'B colore suggerimenti'; ExpectSrc = 'S2'; Old = $rule; New = 'color:var(--ks-accent);' },
    @{ Id = 'M05_HOME_OLD_PRICE_NOT_SENT'; File = 'Default.aspx.vb'; Scope = @('home'); Expect = 'C sconto non mostrato www.taikun.it HOME'; Old = 'If oldPriceText.Length > 0 Then sb.Append(" data-ks-old-price='; New = 'If False Then sb.Append(" data-ks-old-price=' },
    @{ Id = 'M06_LIST_OLD_PRICE_NOT_SENT'; File = 'articoli.aspx.vb'; Scope = @('elenco'); Expect = 'C sconto non mostrato www.taikun.it elenco'; Old = 'If Not String.IsNullOrEmpty(oldPriceText) Then attrs.Append(" data-ks-old-price='; New = 'If False Then attrs.Append(" data-ks-old-price=' },
    @{ Id = 'M07_PDP_CURRENT_ITEM_OLD_PRICE_LOST'; File = 'articolo.aspx.vb'; Scope = @(); ExpectSrc = 'S8'; Old = '            .OldPriceValue = price.OldPrice,' + "`n"; New = '' },
    @{ Id = 'M08_PDP_RELATED_OLD_PRICE_LOST'; File = 'articolo.aspx.vb'; Scope = @('scheda'); Expect = 'C sconto non mostrato www.taikun.it scheda sconto(self)'; ExpectSrc = 'S8'; Old = '                item.OldPriceValue = price.OldPrice' + "`n"; New = '' },
    @{ Id = 'M09_JS_OLD_PRICE_NOT_RESET'; File = $prodJs; Scope = @('elenco'); Expect = 'A prezzo precedente rimasto'; Old = "if (wrap) wrap.hidden = state !== 'sale';"; New = "if (wrap && state === 'sale') wrap.hidden = false;" },
    @{ Id = 'M10_JS_STATE_CLASS_ADDED_NOT_REPLACED'; File = $prodJs; Scope = @('elenco'); Expect = 'A colore anteprima'; ExpectSrc = 'S4'; Old = "price.className = 'ks-price-state--' + state;"; New = "price.classList.add('ks-price-state--' + state);" },
    @{ Id = 'M11_JS_ON_REQUEST_TREATED_AS_SALE'; File = $prodJs; Scope = @('elenco'); Expect = 'A colore anteprima www.taikun.it elenco richiesta'; Old = "if (text === PRICE_ON_REQUEST) state = 'ask';"; New = "if (false) state = 'ask';" },
    @{ Id = 'M12_JS_OLD_PRICE_NOT_READ'; File = $prodJs; Scope = @('home'); Expect = 'C sconto non mostrato'; ExpectSrc = 'S4'; Old = "oldPrice: link.getAttribute('data-ks-old-price') || ''"; New = "oldPrice: ''" }
)
function Get-Mutated($mu) {
    $text = $src[$mu.File]
    $i0 = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
    if ($i0 -lt 0 -or $i0 -ne $text.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { return $null }
    return $text.Replace($mu.Old, $mu.New)
}
if (-not $SkipMutants -and $exit -eq 0) {
    foreach ($mu in $mutants) {
        $t = Get-Mutated $mu
        if ($null -eq $t) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
        if (-not $mu.ContainsKey('ExpectSrc')) { continue }
        $c = @{}; foreach ($k in $src.Keys) { $c[$k] = $src[$k] }; $c[$mu.File] = $t
        if (@(Test-Source $c | Where-Object { ([string]$_).StartsWith($mu.ExpectSrc) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa (sorgente) ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta (sorgente) ' + $mu.Id); $exit = 1 }
    }
}
if (-not $SkipLab) {
    if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('PRICE_STATES_SURFACES FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
    if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
    try {
        Sync-Site
        try { $bad = @(Invoke-Lab $all) } catch { $bad = @('NON PROVATO browser di prova: ' + $_.Exception.Message + ' @ ' + (($_.ScriptStackTrace -split "`n" | Select-Object -First 4) -join ' < ')) }
        if ($bad.Count -eq 0) { Write-Host '  ok   sito LAB: anteprima con lo stato della scheda (HOME, elenco, scheda prodotto, 390 px) e suggerimenti neri' } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 16)) { Write-Host ('  FAIL ' + $b) } }
        if (-not $SkipMutants -and $exit -eq 0) {
            $keep = $ShotDir; $ShotDir = ''
            foreach ($mu in $mutants) {
                if (@($mu.Scope).Count -eq 0) { continue }
                if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
                Write-SiteText $mu.File (Get-Mutated $mu)
                try {
                    $mb = @(Invoke-Lab $mu.Scope)
                    if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa (sito LAB) ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta (sito LAB) ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' | ')); $exit = 1 }
                } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
                finally { Write-Site $mu.File $repoBytes[$mu.File] }
            }
            $ShotDir = $keep
        }
    } finally {
        Sync-Site
        foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
    }
}
if ($exit -eq 0) { Write-Host ('PRICE_STATES_SURFACES PASS' + $(if ($SkipLab) { ' (senza sito LAB)' } elseif ($SkipMutants) { ' (senza mutazioni)' } else { ' (' + $mutants.Count + ' mutazioni uccise)' })) } else { Write-Host 'PRICE_STATES_SURFACES FAIL' }
exit $exit
