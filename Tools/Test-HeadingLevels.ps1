[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$Cases = '', [string]$ShotDir = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# A11Y-HEADING-LEVELS-1A. Carrello e area cliente hanno un solo titolo principale (h1 nativo) per pagina e per stato:
# esposto alle tecnologie assistive, visibile, primo titolo del contenuto. Carrello, carrello vuoto e Dashboard conservano
# l'aspetto; "I miei ordini", dati utente, password e dettagli account prendono la scala del titolo di pagina (22 / 26 px, peso 700).
# Prova sul sito LAB (https, 127.0.0.1, porta 18843) a 1280 / 390 / 320 px, piu stampa emulata e lo stato "carrello non consultabile"
# forzato sulla sola copia LAB. Wishlist: sul LAB la pagina e in errore (dati del LAB), si controlla il sorgente.
# Mutazioni sulla copia LAB, file rimessi alla fine. Sola lettura sul database. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$css = 'Public\assets\keepstore\css\type-scale.css'
$files = @('Page.master', 'carrello.aspx', 'carrello.aspx.vb', 'myaccount.aspx', 'documenti.aspx', 'datiutente.aspx', 'password.aspx', 'my-account-edit.aspx', 'wishlist.aspx', $css)
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('HEADING_LEVELS FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('HEADING_LEVELS FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))) }
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath (Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'))
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$readJs = @'
(function(){
function content(e){return !e.closest('header,footer,.modal,.offcanvas,[role=dialog]');}
function exposed(e){for(var n=e;n&&n.nodeType===1;n=n.parentElement){if(n.hidden||n.getAttribute('aria-hidden')==='true'||n.hasAttribute('inert'))return false;var s=getComputedStyle(n);if(s.display==='none'||s.visibility==='hidden')return false;}return true;}
var hs=[].slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).filter(content).filter(exposed);
var h1=hs.filter(function(e){return e.tagName==='H1';});
var al=document.querySelector('[id$="CartReadUnavailablePanel"]');
var o={path:location.pathname.split('/').pop(),h1:h1.length,first:hs.length?hs[0].tagName:'',alert:!!al&&al.getClientRects().length>0};
if(h1.length){var e=h1[0],c=getComputedStyle(e),r=e.getBoundingClientRect();o.t=(e.textContent||'').replace(/\s+/g,' ').trim();o.seen=r.width>1&&r.height>1;o.size=parseFloat(c.fontSize);o.weight=c.fontWeight;o.lh=parseFloat(c.lineHeight);o.color=c.color;o.bg=c.backgroundColor;o.mb=parseFloat(c.marginBottom);o.mt=parseFloat(c.marginTop);o.align=c.textAlign;o.family=c.fontFamily;o.cut=e.scrollWidth>e.clientWidth+1;o.right=Math.round(r.right);o.vw=window.innerWidth;}
return JSON.stringify(o);})()
'@
function Open-Page($browser, [string]$rel) {
    for ($a = 1; $a -le 3; $a++) {
        try { Open-KsUrl $browser ($base + '/' + $rel) 300 } catch { if ($a -eq 3) { throw } }
        try { if ([string](Invoke-KsJs $browser 'location.origin') -eq $base -and [bool](Invoke-KsJs $browser '!!document.querySelector("footer")')) { Start-Sleep -Milliseconds 700; return } } catch { }
        Start-Sleep -Seconds 4
    }
    throw 'ORIGINE_INATTESA'
}
function Enter-User($browser) {
    Open-Page $browser 'login.aspx'
    if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_tbPassword")')) {
        Set-KsValue $browser '#MainContent_tbUsername' 'PROVA'; Set-KsValue $browser '#MainContent_tbPassword' (Get-Secret); Invoke-KsClick $browser '#MainContent_btnLogin'
        Start-Sleep -Milliseconds 1500
    }
}
function Read-Title($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $readJs))) }

# Casi: nome, utente, pagina, pagina finale attesa, testo (regex), stile atteso. Size = @(>=992, <992) salvo dove indicato.
$ink = 'rgb(51, 62, 72)'
$caseTable = @(
    @{ Id = 'VUOTO'; User = $false; Rel = 'carrello.aspx'; Path = 'carrello.aspx'; Text = '^Il carrello .{1,2} vuoto$'; Big = 28; Small = 24; SmallBelow = 768; Weight = '500'; Lh = 1.25; Color = 'rgb(17, 24, 39)'; Mb = 5.6; Align = 'center' },
    @{ Id = 'CARRELLO'; User = $true; Rel = 'carrello.aspx'; Path = 'carrello.aspx'; Text = '^Il tuo carrello$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.2; Color = $ink; Mb = 6.4; Align = 'start' },
    @{ Id = 'AREA'; User = $true; Rel = 'myaccount.aspx'; Path = 'myaccount.aspx'; Text = '^(Ciao, .+|Benvenuto nella tua Dashboard)$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'ORDINI'; User = $true; Rel = 'documenti.aspx?t=4'; Path = 'documenti.aspx'; Text = '^I miei ordini$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'DATI'; User = $true; Rel = 'datiutente.aspx'; Path = 'datiutente.aspx'; Text = '^Gestione dati account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'PASSWORD'; User = $true; Rel = 'password.aspx'; Path = 'password.aspx'; Text = '^Cambia password$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 12; Align = 'start' },
    @{ Id = 'DETTAGLI'; User = $true; Rel = 'my-account-edit.aspx'; Path = 'my-account-edit.aspx'; Text = '^Dettagli account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' }
)
function Test-One($c, $o, [int]$w, [string]$tag) {
    $bad = New-Object Collections.Generic.List[string]
    $id = [string]$c.Id + $tag
    if ([string]$o.path -ne [string]$c.Path) { $bad.Add($id + ' NON PROVATO: pagina finale ' + [string]$o.path); return $bad }
    if ([int]$o.h1 -ne 1) { $bad.Add($id + ' titoli principali esposti: ' + [string]$o.h1 + ' invece di 1'); return $bad }
    if (-not [bool]$o.seen) { $bad.Add($id + ' titolo principale non visibile') }
    if ([string]$o.first -ne 'H1') { $bad.Add($id + ' il primo titolo del contenuto e ' + [string]$o.first) }
    if ([string]$o.t -notmatch [string]$c.Text) { $bad.Add($id + ' testo del titolo [' + [string]$o.t + ']') }
    $size = if ($w -ge [int]$c.SmallBelow) { [double]$c.Big } else { [double]$c.Small }
    if ([Math]::Abs([double]$o.size - $size) -gt 0.2) { $bad.Add($id + ' stile: corpo ' + [string]$o.size + ' invece di ' + $size) }
    if ([string]$o.weight -ne [string]$c.Weight) { $bad.Add($id + ' stile: peso ' + [string]$o.weight + ' invece di ' + [string]$c.Weight) }
    if ([Math]::Abs([double]$o.lh - $size * [double]$c.Lh) -gt 0.6) { $bad.Add($id + ' stile: interlinea ' + [string]$o.lh + ' invece di ' + ($size * [double]$c.Lh)) }
    if ([string]$o.color -ne [string]$c.Color) { $bad.Add($id + ' colore ' + [string]$o.color + ' invece di ' + [string]$c.Color) }
    if ([string]$o.bg -ne 'rgba(0, 0, 0, 0)') { $bad.Add($id + ' colore: sfondo ' + [string]$o.bg) }
    if ([Math]::Abs([double]$o.mb - [double]$c.Mb) -gt 0.3 -or [Math]::Abs([double]$o.mt) -gt 0.3) { $bad.Add($id + ' stile: margini ' + [string]$o.mt + ' / ' + [string]$o.mb + ' invece di 0 / ' + [string]$c.Mb) }
    if ([string]$o.align -ne [string]$c.Align) { $bad.Add($id + ' stile: allineamento ' + [string]$o.align) }
    if ([string]$o.family -notmatch '^Arial') { $bad.Add($id + ' stile: carattere ' + [string]$o.family) }
    if ([bool]$o.cut -or [int]$o.right -gt [int]$o.vw) { $bad.Add($id + ' titolo tagliato o fuori dallo schermo') }
    return $bad
}
# Un caso a una larghezza. Oltre alla lettura normale: una regola h1 "del cliente" (per tag, aggiunta dopo tutti i fogli) non deve cambiare colore ne sfondo.
function Invoke-Case($browser, $c, [int]$w) {
    $bad = New-Object Collections.Generic.List[string]
    Open-Page $browser ([string]$c.Rel)
    $o = Read-Title $browser
    foreach ($b in (Test-One $c $o $w '')) { $bad.Add($b) }
    if ($ShotDir -ne '') { Save-KsScreenshot $browser (Join-Path $ShotDir (([string]$c.Id).ToLower() + '-' + $w + '.png')) }
    if ($bad.Count -eq 0) {
        $null = Invoke-KsJs $browser "(function(){var st=document.createElement('style');st.textContent='h1{color:rgb(1,2,3);background-color:rgb(200,0,0)}';document.head.appendChild(st);return 1;})()"
        $o2 = Read-Title $browser
        if ([string]$o2.color -ne [string]$c.Color) { $bad.Add([string]$c.Id + ' colore: una regola h1 del cliente lo cambia in ' + [string]$o2.color) }
        if ([string]$o2.bg -ne 'rgba(0, 0, 0, 0)') { $bad.Add([string]$c.Id + ' colore: una regola h1 del cliente mette lo sfondo ' + [string]$o2.bg) }
    }
    return $bad
}
function Invoke-Print($browser) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($id in @('CARRELLO', 'AREA', 'PASSWORD')) {
        $c = @($caseTable | Where-Object { $_.Id -eq $id })[0]
        Open-Page $browser ([string]$c.Rel)
        $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = 'print' }
        try { $o = Read-Title $browser } finally { $null = Invoke-KsCdp $browser 'Emulation.setEmulatedMedia' @{ media = '' } }
        if ([int]$o.h1 -ne 1) { $bad.Add('STAMPA ' + $id + ' NON PROVATO: titoli principali ' + [string]$o.h1); continue }
        if ([Math]::Abs([double]$o.size - 22) -gt 0.2 -or [string]$o.weight -ne '700') { $bad.Add('STAMPA ' + $id + ': corpo ' + [string]$o.size + ' peso ' + [string]$o.weight + ' invece di 22 / 700') }
    }
    return $bad
}
# Stato "carrello non consultabile": forzato sulla sola copia LAB del code-behind.
function Invoke-Unavailable {
    $bad = New-Object Collections.Generic.List[string]
    $old = 'Dim readUnavailable As Boolean = cartRead Is Nothing OrElse Not cartRead.HasOwner OrElse Not cartRead.LoadSucceeded'
    $src = (Get-Text $repoBytes['carrello.aspx.vb'])
    if ($src.IndexOf($old, [StringComparison]::Ordinal) -lt 0 -or $src.IndexOf($old, [StringComparison]::Ordinal) -ne $src.LastIndexOf($old, [StringComparison]::Ordinal)) { $bad.Add('NON CONSULTABILE NON PROVATO: punto del code-behind non trovato'); return $bad }
    $b = $null
    try {
        Write-SiteText 'carrello.aspx.vb' $src.Replace($old, 'Dim readUnavailable As Boolean = True')
        $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 390 -Height 844 -Mobile
        Open-Page $b 'carrello.aspx'
        $o = Read-Title $b
        if ($ShotDir -ne '') { Save-KsScreenshot $b (Join-Path $ShotDir 'non-consultabile-390.png') }
        if (-not [bool]$o.alert) { $bad.Add('NON CONSULTABILE NON PROVATO: avviso non visibile') }
        elseif ([int]$o.h1 -ne 1 -or -not [bool]$o.seen -or [string]$o.first -ne 'H1') { $bad.Add('NON CONSULTABILE titoli principali esposti: ' + [string]$o.h1 + ' (primo titolo ' + [string]$o.first + ')') }
    } catch { $bad.Add('NON CONSULTABILE errore: ' + $_.Exception.Message) }
    finally { if ($b) { Stop-KsBrowser $b }; Write-Site 'carrello.aspx.vb' $repoBytes['carrello.aspx.vb'] }
    return $bad
}
function Test-Source {
    $bad = New-Object Collections.Generic.List[string]
    $wl = Get-Text $repoBytes['wishlist.aspx']
    if ($wl -notmatch '<h1 class="heading mb-1 ks-page-title">Wishlist</h1>') { $bad.Add('SORGENTE wishlist: titolo principale assente') }
    if ([regex]::Matches($wl, '<h1[\s>]').Count -ne 1) { $bad.Add('SORGENTE wishlist: numero di h1 diverso da 1') }
    foreach ($f in @('myaccount.aspx', 'documenti.aspx', 'datiutente.aspx', 'password.aspx', 'my-account-edit.aspx')) { if ([regex]::Matches((Get-Text $repoBytes[$f]), '<h1[\s>]').Count -ne 1) { $bad.Add('SORGENTE ' + $f + ': numero di h1 diverso da 1') } }
    if ([regex]::Matches((Get-Text $repoBytes['carrello.aspx']), '<h1[\s>]').Count -ne 2) { $bad.Add('SORGENTE carrello.aspx: attesi due h1 alternativi (titolo e carrello vuoto)') }
    return $bad
}
# Esegue i casi richiesti a una larghezza con un solo browser; riprova una volta se il browser si blocca.
function Invoke-Width([int]$w, [string[]]$ids) {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $bad = New-Object Collections.Generic.List[string]; $b = $null
        try {
            $b = if ($w -lt 800) { Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $w -Height 844 -Mobile } else { Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width $w -Height 900 }
            try { $null = Invoke-KsCdp $b 'Network.enable' @{}; $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
            $logged = $false
            foreach ($c in $caseTable) {
                if ($ids -notcontains [string]$c.Id -and $ids -notcontains 'STAMPA') { continue }
                if ($ids -notcontains [string]$c.Id) { continue }
                if ([bool]$c.User -and -not $logged) { Enter-User $b; $logged = $true }
                foreach ($x in (Invoke-Case $b $c $w)) { $bad.Add([string]$w + ' ' + $x) }
            }
            if ($ids -contains 'STAMPA') { if (-not $logged) { Enter-User $b }; foreach ($x in (Invoke-Print $b)) { $bad.Add($x) } }
            return $bad
        } catch { if ($attempt -eq 2) { $bad.Add([string]$w + ' errore del browser: ' + $_.Exception.Message); return $bad } }
        finally { if ($b) { Stop-KsBrowser $b } }
    }
}

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
$allIds = @($caseTable | ForEach-Object { [string]$_.Id })
$wanted = if ($Cases -ne '') { @($Cases.Split(',') | ForEach-Object { $_.Trim().ToUpper() }) } else { $allIds + @('STAMPA', 'NONCONSULTABILE', 'SORGENTE') }
try {
    Sync-Site
    if ($wanted -contains 'SORGENTE') { $bad = @(Test-Source); if ($bad.Count -eq 0) { Write-Host '  ok   sorgente' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } } }
    foreach ($w in @(1280, 390, 320)) {
        $ids = @($wanted | Where-Object { $allIds -contains $_ })
        if ($ids.Count -eq 0) { continue }
        $bad = @(Invoke-Width $w $ids)
        if ($bad.Count -eq 0) { Write-Host ('  ok   ' + $w + ' px (' + ($ids -join ', ') + ')') } else { $exit = 1; foreach ($x in ($bad | Select-Object -First 14)) { Write-Host ('  FAIL ' + $x) } }
    }
    if ($wanted -contains 'STAMPA') { $bad = @(Invoke-Width 794 @('STAMPA')); if ($bad.Count -eq 0) { Write-Host '  ok   stampa (794 px)' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } } }
    if ($wanted -contains 'NONCONSULTABILE') { $bad = @(Invoke-Unavailable); if ($bad.Count -eq 0) { Write-Host '  ok   carrello non consultabile (390 px)' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } } }

    if (-not $SkipMutants -and $exit -eq 0 -and $Cases -eq '') {
        $mutants = @(
            @{ Id = 'M01_PASSWORD_TITLE_BACK_TO_H3'; File = 'password.aspx'; W = 390; Case = 'PASSWORD'; Expect = '390 PASSWORD titoli principali'; Old = '<h1 class="heading ks-page-title">Cambia password</h1>'; New = '<h3 class="heading ks-page-title">Cambia password</h3>' },
            @{ Id = 'M02_CART_TITLE_BACK_TO_H3'; File = 'carrello.aspx'; W = 390; Case = 'CARRELLO'; Expect = '390 CARRELLO titoli principali'; Old = '<h1 class="heading">'; New = '<h3 class="heading">'; Old2 = 'End If %></h1>'; New2 = 'End If %></h3>' },
            @{ Id = 'M03_PAGE_TITLE_CLASS_REMOVED'; File = 'password.aspx'; W = 1280; Case = 'PASSWORD'; Expect = '1280 PASSWORD stile'; Old = '<h1 class="heading ks-page-title">Cambia password</h1>'; New = '<h1 class="heading">Cambia password</h1>' },
            @{ Id = 'M04_DASHBOARD_SELECTOR_REMOVED'; File = $css; W = 390; Case = 'AREA'; Expect = '390 AREA stile'; Old = "  .ks-account-dashboard .ks-dashboard-hero h1,`n  h1.ks-page-title {`n    font-family"; New = "  h1.ks-page-title {`n    font-family" },
            @{ Id = 'M05_EMPTY_CART_RULE_REMOVED'; File = $css; W = 1280; Case = 'VUOTO'; Expect = '1280 VUOTO'; Old = ".ks-cart-page .ks-cart-empty-card h1 {`n  margin"; New = ".ks-cart-page .ks-cart-empty-card h1-off {`n  margin" },
            @{ Id = 'M06_EMPTY_CART_PHONE_RULE_REMOVED'; File = $css; W = 390; Case = 'VUOTO'; Expect = '390 VUOTO stile: corpo'; Old = "  .ks-cart-page .ks-cart-empty-card h1 {`n    font-size: 24px;"; New = "  .ks-cart-page .ks-cart-empty-card h1-off {`n    font-size: 24px;" },
            @{ Id = 'M07_SECOND_TITLE_HIDDEN_ONLY_TO_SIGHT'; File = 'documenti.aspx'; W = 390; Case = 'ORDINI'; Expect = '390 ORDINI titoli principali'; Old = '<h1 class="fw-semibold mb-0 ks-page-title">I miei ordini</h1>'; New = '<h1 class="visually-hidden">Ordini</h1><h1 class="fw-semibold mb-0 ks-page-title">I miei ordini</h1>' },
            @{ Id = 'M08_TITLE_HIDDEN_FROM_ASSISTIVE_TECH'; File = 'myaccount.aspx'; W = 390; Case = 'AREA'; Expect = '390 AREA titoli principali'; Old = '<h1 class="fw-semibold mb-2">'; New = '<h1 class="fw-semibold mb-2" aria-hidden="true">' },
            @{ Id = 'M09_PRINT_RULE_REMOVED'; File = $css; W = 794; Case = 'STAMPA'; Expect = 'STAMPA '; Old = '@media print {'; New = '@media not all {' },
            @{ Id = 'M10_COLOUR_NOT_FIXED'; File = $css; W = 390; Case = 'DATI'; Expect = '390 DATI colore: una regola'; Old = '  color: var(--grey-1, #333E48);'; New = '  color-off: var(--grey-1, #333E48);' },
            @{ Id = 'M11_UNAVAILABLE_STATE_WITHOUT_TITLE'; File = 'carrello.aspx'; W = 0; Case = 'NONCONSULTABILE'; Expect = 'NON CONSULTABILE titoli principali'; Old = '" ks-cart-read-unavailable"'; New = '""' },
            @{ Id = 'M12_ACCOUNT_DETAILS_BACK_TO_H4'; File = 'my-account-edit.aspx'; W = 1280; Case = 'DETTAGLI'; Expect = '1280 DETTAGLI titoli principali'; Old = '<h1 class="fw-semibold mb-0 ks-page-title">Dettagli account</h1>'; New = '<h4 class="fw-semibold mb-0 ks-page-title">Dettagli account</h4>' }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            $mut = $src.Replace($mu.Old, $mu.New)
            if ($mu.ContainsKey('Old2')) { $j0 = $mut.IndexOf($mu.Old2, [StringComparison]::Ordinal); if ($j0 -lt 0) { Write-Host ('  FAIL ' + $mu.Id + ': secondo punto non trovato'); $exit = 1; continue }; $mut = $mut.Substring(0, $j0) + $mu.New2 + $mut.Substring($j0 + $mu.Old2.Length) }
            Write-SiteText $mu.File $mut
            try {
                $mb = if ($mu.Case -eq 'NONCONSULTABILE') { @(Invoke-Unavailable) } else { @(Invoke-Width $mu.W @($mu.Case)) }
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('HEADING_LEVELS PASS' + $(if ($SkipMutants -or $Cases -ne '') { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (12 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'HEADING_LEVELS FAIL' }
exit $exit
