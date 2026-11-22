[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$MutantFilter = '', [string]$ShotDir = '', [string]$Query = 'carta', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# STYLE-PRICE-STATES-1B. Il prezzo di un articolo non e rosso per una classe generica (linea di stile 3.2).
# Due superfici condivise che la prova di STYLE-PRICE-STATES-1A esclude per costruzione (modale e testata):
#  - anteprima rapida: mostra solo il prezzo corrente, senza prezzo precedente -> nero, qualunque sia la scheda da cui si apre;
#  - suggerimenti della ricerca in testata: solo il prezzo corrente -> nero.
# Il colore atteso e ESATTO (nero), non "diverso dal rosso"; un bersaglio assente o invisibile fa fallire la prova.
# Sito LAB (https, 127.0.0.1, porta 18843), due aziende con accenti diversi; mutazioni sulla copia LAB, file rimessi alla fine. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$flags = 'Public\assets\keepstore\js\ks-page-flags.js'
$files = @('Page.master', $flags)
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PRICE_STATES_SURFACES FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$black = 'rgb(0, 0, 0)'

function Test-Source([string]$master, [string]$js) {
    $bad = New-Object Collections.Generic.List[string]
    if ($master -notmatch '<h4 class="ks-price-state--normal" id="ksQuickViewPrice">') { $bad.Add('S1 il prezzo dell''anteprima non ha la sola classe di stato normale') }
    if ($js -notmatch '\.ks-suggest-price\{[^}]*color:var\(--ks-price-normal,#000\)') { $bad.Add('S2 il prezzo dei suggerimenti non usa il colore del prezzo normale') }
    if ($js -match '\.ks-suggest-price\{[^}]*#b0001f') { $bad.Add('S2 rosso fisso nel prezzo dei suggerimenti') }
    if ($master -notmatch 'js/ks-page-flags\.js"\) %>\?v=20261122-price-states-1b') { $bad.Add('S3 versione dello script dei suggerimenti non aggiornata') }
    return $bad
}

. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }
$openJs = @'
(function(state){
function txt(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
var sel='[data-bs-target="#quickView"],[href="#quickView"]';
var c=[].slice.call(document.querySelectorAll('.card-product')).filter(function(x){return x.querySelector('.new-price.'+state)&&x.querySelector(sel);})[0];
if(!c)return '';
var p=txt(c.querySelector('.new-price.'+state));c.querySelector(sel).click();return p;})
'@
$readJs = @'
(function(){var e=document.getElementById('ksQuickViewPrice');if(!e)return JSON.stringify({found:false});var r=e.getBoundingClientRect();var m=document.getElementById('quickView');
return JSON.stringify({found:true,shown:!!(m&&m.classList.contains('show')),visible:r.width>1&&r.height>1,text:(e.textContent||'').replace(/\s+/g,' ').trim(),color:getComputedStyle(e).color});})()
'@
$closeJs = "(function(){var x=document.querySelector('#quickView .btn-close,#quickView [data-bs-dismiss=""modal""]');if(x)x.click();return 1;})()"
$typeJs = "(function(q){var i=document.querySelector('[data-ks-search-form=""desktop""] input[type=text],[data-ks-search-form=""desktop""] input[type=search]');if(!i)return 0;i.focus();i.value=q;i.dispatchEvent(new Event('input',{bubbles:true}));i.dispatchEvent(new KeyboardEvent('keyup',{bubbles:true,key:'a'}));return 1;})"
$suggestJs = @'
(function(){var p=document.getElementById('ksSearchSuggestDesktop');var a=p?[].slice.call(p.querySelectorAll('.ks-suggest-price')):[];
var v=a.filter(function(e){var r=e.getBoundingClientRect();return r.width>1&&r.height>1&&/\d,\d{2}/.test(e.textContent||'');});
var colors={};v.forEach(function(e){colors[getComputedStyle(e).color]=1;});return JSON.stringify({all:a.length,visible:v.length,colors:Object.keys(colors)});})()
'@
function Invoke-Lab {
    $bad = New-Object Collections.Generic.List[string]
    $saleSeen = 0
    foreach ($h in @('www.taikun.it', 'www.webaffare.it')) {
        $origin = 'https://' + $h + ':18843'
        $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
        try {
            try { $null = Invoke-KsCdp $b 'Network.enable' @{}; $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
            Open-KsUrl $b ($origin + '/articoli.aspx?q=' + $Query) 300
            if ([string](Invoke-KsJs $b 'location.origin') -ne $origin) { throw 'ORIGINE_INATTESA' }
            Start-Sleep -Milliseconds 1500
            foreach ($state in @('ks-price-state--normal', 'ks-price-state--sale')) {
                $tag = $h + ' da scheda ' + $state.Replace('ks-price-state--', '')
                $cardPrice = [string](Invoke-KsJs $b ($openJs + "('" + $state + "')"))
                if ($cardPrice -eq '') { if ($state -eq 'ks-price-state--normal') { $bad.Add('A NON PROVATO ' + $tag + ': nessuna scheda a prezzo normale con anteprima nella ricerca "' + $Query + '"') }; continue }
                if ($state -eq 'ks-price-state--sale') { $saleSeen++ }
                Start-Sleep -Milliseconds 1800
                $s = ConvertFrom-Json ([string](Invoke-KsJs $b $readJs))
                if (-not [bool]$s.found -or -not [bool]$s.shown -or -not [bool]$s.visible) { $bad.Add('A NON PROVATO ' + $tag + ': anteprima non aperta o prezzo non visibile') }
                else {
                    if ([string]$s.text -ne $cardPrice) { $bad.Add('A testo ' + $tag + ': anteprima "' + [string]$s.text + '", scheda "' + $cardPrice + '"') }
                    if ([string]$s.color -ne $black) { $bad.Add('A colore anteprima ' + $tag + ': ' + [string]$s.color + ' (atteso ' + $black + ')') }
                    if ($ShotDir -ne '') { Save-KsScreenshot $b (Join-Path $ShotDir ('anteprima-' + $h + '-' + $state.Replace('ks-price-state--', '') + '.png')) }
                }
                $null = Invoke-KsJs $b $closeJs; Start-Sleep -Milliseconds 900
            }
            $tag = $h + ' suggerimenti'
            if ([int](Invoke-KsJs $b ($typeJs + "('" + $Query + "')")) -ne 1) { $bad.Add('B NON PROVATO ' + $tag + ': campo di ricerca della testata non trovato') }
            else {
                $g = $null
                foreach ($i in 1..10) { Start-Sleep -Milliseconds 800; $g = ConvertFrom-Json ([string](Invoke-KsJs $b $suggestJs)); if ([int]$g.visible -gt 0) { break } }
                if ([int]$g.visible -lt 1) { $bad.Add('B NON PROVATO ' + $tag + ': nessun prezzo visibile nei suggerimenti') }
                elseif (@($g.colors).Count -ne 1 -or [string]@($g.colors)[0] -ne $black) { $bad.Add('B colore suggerimenti ' + $tag + ': ' + (@($g.colors) -join ' / ') + ' (atteso ' + $black + ')') }
                if ($ShotDir -ne '') { Save-KsScreenshot $b (Join-Path $ShotDir ('suggerimenti-' + $h + '.png')) }
            }
        } finally { Stop-KsBrowser $b }
    }
    if ($saleSeen -lt 1) { $bad.Add('A NON PROVATO: nessuna scheda in sconto con anteprima in nessuna delle due aziende') }
    return $bad
}

$exit = 0
$masterText = (Get-Text $repoBytes['Page.master']).Replace("`r`n", "`n"); $jsText = (Get-Text $repoBytes[$flags]).Replace("`r`n", "`n")
$src = @(Test-Source $masterText $jsText)
if ($src.Count -gt 0) { $exit = 1; foreach ($b in $src) { Write-Host ('  FAIL ' + $b) } } else { Write-Host '  ok   sorgente: classe di stato nell''anteprima, colore del prezzo normale nei suggerimenti, versione dello script' }
$h4 = '<h4 class="ks-price-state--normal" id="ksQuickViewPrice">'
$rule = 'color:var(--ks-price-normal,#000);'
$mutants = @(
    @{ Id = 'M01_GENERIC_RED_CLASS_BACK'; File = 'Page.master'; Expect = 'A colore anteprima'; ExpectSrc = 'S1'; Old = $h4; New = '<h4 class="text-primary" id="ksQuickViewPrice">' },
    @{ Id = 'M02_STATE_CLASS_NEXT_TO_GENERIC_CLASS'; File = 'Page.master'; Expect = 'A colore anteprima'; ExpectSrc = 'S1'; Old = $h4; New = '<h4 class="text-primary ks-price-state--normal" id="ksQuickViewPrice">' },
    @{ Id = 'M03_SUGGEST_FIXED_RED_BACK'; File = $flags; Expect = 'B colore suggerimenti'; ExpectSrc = 'S2'; Old = $rule; New = 'color:#b0001f;' },
    @{ Id = 'M04_SUGGEST_FOLLOWS_SHOP_ACCENT'; File = $flags; Expect = 'B colore suggerimenti'; ExpectSrc = 'S2'; Old = $rule; New = 'color:var(--ks-accent);' }
)
function Get-Mutated($mu) {
    $text = $(if ($mu.File -eq 'Page.master') { $masterText } else { $jsText })
    $i0 = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
    if ($i0 -lt 0 -or $i0 -ne $text.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { return $null }
    return $text.Replace($mu.Old, $mu.New)
}
if (-not $SkipMutants -and $exit -eq 0) {
    foreach ($mu in $mutants) {
        $t = Get-Mutated $mu
        if ($null -eq $t) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
        $sb = @(if ($mu.File -eq 'Page.master') { Test-Source $t $jsText } else { Test-Source $masterText $t })
        if (@($sb | Where-Object { ([string]$_).StartsWith($mu.ExpectSrc) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa (sorgente) ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta (sorgente) ' + $mu.Id); $exit = 1 }
    }
}
if (-not $SkipLab) {
    if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('PRICE_STATES_SURFACES FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
    if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
    try {
        Sync-Site
        $bad = @(Invoke-Lab)
        if ($bad.Count -eq 0) { Write-Host '  ok   sito LAB: prezzo nero nell''anteprima (scheda normale e in sconto) e nei suggerimenti, due aziende' } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 14)) { Write-Host ('  FAIL ' + $b) } }
        if (-not $SkipMutants -and $exit -eq 0) {
            $keep = $ShotDir; $ShotDir = ''
            foreach ($mu in $mutants) {
                if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
                Write-SiteText $mu.File (Get-Mutated $mu)
                try {
                    $mb = @(Invoke-Lab)
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
if ($exit -eq 0) { Write-Host ('PRICE_STATES_SURFACES PASS' + $(if ($SkipLab) { ' (senza sito LAB)' } elseif ($SkipMutants) { ' (senza mutazioni)' } else { ' (4 mutazioni uccise)' })) } else { Write-Host 'PRICE_STATES_SURFACES FAIL' }
exit $exit
