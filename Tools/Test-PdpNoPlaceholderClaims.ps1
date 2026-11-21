[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$ShotDir = '', [string]$Article = '21906', [string]$MissingArticle = '999999999', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# PAYMENT-LOGOS-1B. In fondo alla scheda prodotto non resta alcuna promessa senza dato.
# La fascia dei cinque riquadri a testo fisso (spedizione, supporto, pagamenti, affidabilita, garanzia) con il suo carosello e tolta:
# era uguale per ogni azienda, usciva anche sulle pagine 404 e ripeteva male cio che il piede dice con i dati veri (metodi e marchi).
# Prova: sorgente; sito LAB (https, 127.0.0.1, porta 18843) con due aziende a 390 e 1280 px, scheda trovata e articolo inesistente.
# Mutazioni sulla copia LAB e sul testo del sorgente; file del LAB rimessi alla fine. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$css = 'Public\assets\keepstore\css\product-ui.css'
$files = @('articolo.aspx', $css)
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PDP_NO_PLACEHOLDER_CLAIMS FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$claims = @('Consegna e ritiro secondo disponibilit', 'Assistenza prima e dopo l', 'Flusso ecommerce KeepStore sicuro', 'Disponibilita e listini aggiornati', 'Prodotti gestiti dal flusso negozio')

# ---- parte sorgente ----
function Test-Source([string]$aspx, [string]$cssText) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($c in $claims) { if ($aspx.IndexOf($c, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $bad.Add('S1 testo fisso senza dato nella scheda: ' + $c) } }
    if ($aspx -match 'tf-icon-box|tf-sw-iconbox|sw-pagination-iconbox|ks-product-iconbox-section') { $bad.Add('S2 riquadri o carosello dei riquadri ancora nella scheda') }
    if ($cssText -match 'ks-product-iconbox-section') { $bad.Add('S3 selettore della fascia tolta ancora nel foglio di stile') }
    return $bad
}

# ---- parte sito LAB ----
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }
$claimsJs = '[' + (($claims | ForEach-Object { "'" + $_.ToLowerInvariant() + "'" }) -join ',') + ']'
$stateJs = @'
(function(){
function txt(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
var nav=performance.getEntriesByType('navigation')[0];
var o={status:nav&&nav.responseStatus?nav.responseStatus:0,vw:innerWidth};
o.boxes=document.querySelectorAll('.tf-icon-box,.tf-sw-iconbox,.sw-pagination-iconbox,.ks-product-iconbox-section').length;
var body=txt(document.body).toLowerCase();o.claims=CLAIMS.filter(function(c){return body.indexOf(c)>=0;});
o.product=!!document.querySelector('.tf-product-info-choose-option');
var p=document.querySelector('.ft-payments');o.footerText=txt(p);o.footerLogos=document.querySelectorAll('footer .ks-payment-logos img').length;
o.overflow=document.documentElement.scrollWidth>innerWidth+1;
return JSON.stringify(o);})()
'@.Replace('CLAIMS', $claimsJs)
function Read-Page($browser, [string]$url, [string]$origin) {
    Open-KsUrl $browser $url 300
    if ([string](Invoke-KsJs $browser 'location.origin') -ne $origin) { throw 'ORIGINE_INATTESA' }
    Start-Sleep -Milliseconds 1200
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs)))
}
function Invoke-Lab {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($w in @(390, 1280)) {
        if ($w -eq 390) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 390 -Height 844 -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900 }
        try {
            try { $null = Invoke-KsCdp $b 'Network.enable' @{}; $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
            foreach ($h in @('www.taikun.it', 'www.webaffare.it')) {
                $origin = 'https://' + $h + ':18843'; $tag = $h + ' ' + $w + ' px'
                $s = Read-Page $b ($origin + '/articolo.aspx?id=' + $Article) $origin
                if (-not [bool]$s.product) { $bad.Add('A NON PROVATO ' + $tag + ': la scheda dell''articolo ' + $Article + ' non e mostrata') }
                else {
                    if ([int]$s.boxes -ne 0) { $bad.Add('A riquadri ' + $tag + ': ' + [int]$s.boxes + ' elementi dei riquadri fissi nella scheda') }
                    if (@($s.claims).Count -ne 0) { $bad.Add('A testo ' + $tag + ': testo fisso senza dato: ' + (@($s.claims) -join ' | ')) }
                    if ([string]$s.footerText -notmatch '^Metodi di pagamento: \S') { $bad.Add('A piede NON PROVATO ' + $tag + ': il piede non nomina alcun metodo di pagamento') }
                    elseif ([string]$s.footerText -match '(?i)\bcarta\b' -and [int]$s.footerLogos -lt 2) { $bad.Add('A piede ' + $tag + ': carta nominata ma marchi assenti nel piede') }
                    if ([bool]$s.overflow) { $bad.Add('A larghezza ' + $tag + ': la pagina scorre in orizzontale') }
                    if ($ShotDir -ne '' -and $h -eq 'www.taikun.it') {
                        foreach ($i in 1..3) { $null = Invoke-KsJs $b "window.scrollTo({top:document.documentElement.scrollHeight,behavior:'instant'});1"; Start-Sleep -Milliseconds 600 }
                        Save-KsScreenshot $b (Join-Path $ShotDir ('fondo-scheda-' + $w + '.png'))
                    }
                }
                $n = Read-Page $b ($origin + '/articolo.aspx?id=' + $MissingArticle) $origin
                if ([bool]$n.product -or [int]$n.status -ne 404) { $bad.Add('B NON PROVATO ' + $tag + ': l''articolo ' + $MissingArticle + ' non risponde 404 (stato ' + [int]$n.status + ')') }
                else {
                    if ([int]$n.boxes -ne 0) { $bad.Add('B riquadri ' + $tag + ': riquadri fissi sulla pagina 404') }
                    if (@($n.claims).Count -ne 0) { $bad.Add('B testo ' + $tag + ': testo fisso senza dato sulla pagina 404') }
                }
            }
        } finally { Stop-KsBrowser $b }
    }
    return $bad
}

$exit = 0
$aspxText = Get-Text $repoBytes['articolo.aspx']; $cssText = Get-Text $repoBytes[$css]
$src = @(Test-Source $aspxText $cssText)
if ($src.Count -gt 0) { $exit = 1; foreach ($b in $src) { Write-Host ('  FAIL ' + $b) } } else { Write-Host '  ok   sorgente: nessun testo fisso, nessun riquadro, nessun selettore morto' }

$snippetFull = '    <section class="tf-sp-2 pt-0 ks-product-iconbox-section"><div class="container"><div class="swiper tf-sw-iconbox"><div class="swiper-wrapper"><div class="swiper-slide"><div class="tf-icon-box"><div class="content"><p class="body-text fw-semibold">Spedizione</p></div></div></div></div></div></div></section>' + "`n"
$snippetText = '    <p>Pagamenti: Flusso ecommerce KeepStore sicuro.</p>' + "`n"
$anchor = '<asp:Content ID="ScriptsContent1"'
$endContent = "</asp:Content>`n`n" + $anchor
$mutants = @(
    @{ Id = 'M01_FIXED_BOXES_BACK'; File = 'articolo.aspx'; Expect = 'A riquadri'; ExpectSrc = 'S2'; Old = $endContent; New = $snippetFull + $endContent },
    @{ Id = 'M02_PLACEHOLDER_TEXT_BACK'; File = 'articolo.aspx'; Expect = 'A testo'; ExpectSrc = 'S1'; Old = $endContent; New = $snippetText + $endContent },
    @{ Id = 'M03_BOXES_ON_NOT_FOUND_ONLY'; File = 'articolo.aspx'; Expect = 'B riquadri'; ExpectSrc = 'S2'; Old = '<asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">'; New = '<asp:PlaceHolder ID="phNotFound" runat="server" Visible="false"><div class="tf-icon-box"></div>' },
    @{ Id = 'M04_DEAD_PRINT_SELECTOR_BACK'; File = $css; Expect = ''; ExpectSrc = 'S3'; Old = '  .ks-brand-strip,' + "`n"; New = '  .ks-brand-strip,' + "`n" + '  .ks-product-iconbox-section,' + "`n" }
)
function Get-Mutated($mu) {
    $text = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
    $i0 = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
    if ($i0 -lt 0 -or $i0 -ne $text.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { return $null }
    return $text.Replace($mu.Old, $mu.New)
}
if (-not $SkipMutants -and $exit -eq 0) {
    foreach ($mu in $mutants) {
        $t = Get-Mutated $mu
        if ($null -eq $t) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
        $sb = @(if ($mu.File -eq 'articolo.aspx') { Test-Source $t $cssText } else { Test-Source $aspxText $t })
        if (@($sb | Where-Object { ([string]$_).StartsWith($mu.ExpectSrc) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa (sorgente) ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta (sorgente) ' + $mu.Id); $exit = 1 }
    }
}

if (-not $SkipLab) {
    if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'articolo.aspx'))) { Write-Host ('PDP_NO_PLACEHOLDER_CLAIMS FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
    if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
    try {
        Sync-Site
        $bad = @(Invoke-Lab)
        if ($bad.Count -eq 0) { Write-Host '  ok   sito LAB: scheda e pagina 404 senza riquadri fissi, piede con i metodi (due aziende, 390 e 1280 px)' } else { $exit = 1; foreach ($b in ($bad | Select-Object -First 14)) { Write-Host ('  FAIL ' + $b) } }
        if (-not $SkipMutants -and $exit -eq 0) {
            foreach ($mu in ($mutants | Where-Object { $_.Expect -ne '' })) {
                Write-SiteText $mu.File (Get-Mutated $mu)
                $ShotKeep = $ShotDir; $ShotDir = ''
                try {
                    $mb = @(Invoke-Lab)
                    if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa (sito LAB) ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta (sito LAB) ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' | ')); $exit = 1 }
                } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
                finally { $ShotDir = $ShotKeep; Write-Site $mu.File $repoBytes[$mu.File] }
            }
        }
    } finally {
        Sync-Site
        foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
    }
}
if ($exit -eq 0) { Write-Host ('PDP_NO_PLACEHOLDER_CLAIMS PASS' + $(if ($SkipLab) { ' (senza sito LAB)' } elseif ($SkipMutants) { ' (senza mutazioni)' } else { ' (4 mutazioni uccise)' })) } else { Write-Host 'PDP_NO_PLACEHOLDER_CLAIMS FAIL' }
exit $exit
