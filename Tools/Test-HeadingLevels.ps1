[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$Cases = '', [string]$ShotDir = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# A11Y-HEADING-LEVELS-1A. Carrello e area cliente hanno un solo titolo principale (h1 nativo) per pagina e per stato:
# esposto alle tecnologie assistive, visibile, primo titolo del contenuto. Carrello, carrello vuoto e Dashboard conservano
# l'aspetto; "I miei ordini", dati utente, password e dettagli account prendono la scala del titolo di pagina (22 / 26 px, peso 700).
# Prova sul sito LAB (https, 127.0.0.1, porta 18843) a 1280 / 390 / 320 px, piu stampa emulata e lo stato "carrello non consultabile"
# forzato sulla sola copia LAB. Wishlist: sul LAB la pagina e in errore (dati del LAB), si controlla il sorgente.
# A11Y-HEADING-LEVELS-1B: stesso contratto per registrazione, recupero accesso, contatti, FAQ, privacy, condizioni di vendita, chi siamo,
# confronto, traccia ordine e 404; il testo delle condizioni scritto dall'azienda non puo portare un secondo titolo principale.
# Mutazioni sulla copia LAB, file rimessi alla fine. Sola lettura sul database. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$css = 'Public\assets\keepstore\css\type-scale.css'
$files = @('Page.master', 'carrello.aspx', 'carrello.aspx.vb', 'myaccount.aspx', 'documenti.aspx', 'datiutente.aspx', 'password.aspx', 'my-account-edit.aspx', 'wishlist.aspx', $css,
    'registrazione.aspx', 'remind.aspx', 'Contattaci.aspx', 'faq.aspx', 'privacy.aspx', 'condizioni-vendita.aspx', 'condizioni-vendita.aspx.vb', 'about.aspx', 'compare.aspx', 'track-your-order.aspx', '404.aspx')
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
function exposed(e){for(var n=e;n&&n.nodeType===1;n=n.parentElement){if(n.hidden||n.getAttribute('aria-hidden')==='true'||n.hasAttribute('inert'))return false;var s=getComputedStyle(n);if(s.display==='none'||s.visibility==='hidden'||parseFloat(s.opacity)<0.05)return false;}return true;}
var hs=[].slice.call(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).filter(content).filter(exposed);
var h1=[].slice.call(document.querySelectorAll('h1,[role="heading"][aria-level="1"]')).filter(exposed);
var al=document.querySelector('[id$="CartReadUnavailablePanel"]');var acc=document.querySelector('[id$="lnkAccount"]');
var o={path:location.pathname.split('/').pop(),h1:h1.length,first:hs.length?hs[0].tagName:'',alert:!!al&&al.getClientRects().length>0,logged:!!acc&&!/login\.aspx/i.test(acc.getAttribute('href')||'')};
if(h1.length){var e=h1[0],c=getComputedStyle(e),r=e.getBoundingClientRect();o.t=(e.textContent||'').replace(/\s+/g,' ').trim();o.seen=r.width>1&&r.height>1;o.size=parseFloat(c.fontSize);o.weight=c.fontWeight;o.lh=parseFloat(c.lineHeight);o.color=c.color;o.bg=c.backgroundColor;o.mb=parseFloat(c.marginBottom);o.mt=parseFloat(c.marginTop);o.align=c.textAlign;o.family=c.fontFamily;o.cut=e.scrollWidth>e.clientWidth+1;o.right=Math.round(r.right);o.left=Math.round(r.left);o.vw=window.innerWidth;
 o.native=e.tagName==='H1'&&(!e.hasAttribute('role')||e.getAttribute('role')==='heading')&&(!e.hasAttribute('aria-level')||e.getAttribute('aria-level')==='1');}
var sub=document.querySelector('h3.ks-register-subtitle, .ks-register-card .tf-section-title + h3');o.sub=sub&&sub.getClientRects().length?parseFloat(getComputedStyle(sub).fontSize):0;
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
    @{ Id = 'REGISTRAZIONE'; User = $false; Rel = 'registrazione.aspx'; Path = 'registrazione.aspx'; Text = '^Crea il tuo account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'RECUPERO'; User = $false; Rel = 'remind.aspx'; Path = 'remind.aspx'; Text = '^Recupero accesso$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'RECUPEROINVIATO'; User = $false; Rel = 'remind.aspx?sent=1'; Path = 'remind.aspx'; Text = '^Recupero accesso$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'CONTATTI'; User = $false; Rel = 'Contattaci.aspx'; Path = 'Contattaci.aspx'; Text = '^Contattaci$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'FAQ'; User = $false; Rel = 'faq.aspx'; Path = 'faq.aspx'; Text = '^Domande frequenti$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'PRIVACY'; User = $false; Rel = 'privacy.aspx'; Path = 'privacy.aspx'; Text = '^Privacy Policy$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'CONDIZIONI'; User = $false; Rel = 'condizioni-vendita.aspx'; Path = 'condizioni-vendita.aspx'; Text = '^Condizioni Generali di Vendita$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'CHISIAMO'; User = $false; Rel = 'about.aspx'; Path = 'about.aspx'; Text = '^Il nostro negozio$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'CONFRONTO'; User = $false; Rel = 'compare.aspx'; Path = 'compare.aspx'; Text = '^Confronta prodotti$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'TRACCIA'; User = $false; Rel = 'track-your-order.aspx'; Path = 'track-your-order.aspx'; Text = '^Traccia il tuo ordine$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'NONTROVATA'; User = $false; Rel = '404.aspx'; Path = '404.aspx'; Text = '^Ops! Pagina non trovata$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'center' },
    @{ Id = 'VUOTO'; User = $false; Rel = 'carrello.aspx'; Path = 'carrello.aspx'; Text = '^Il carrello .{1,2} vuoto$'; Big = 28; Small = 24; SmallBelow = 768; Weight = '500'; Lh = 1.25; Color = 'rgb(17, 24, 39)'; Mb = 5.6; Align = 'center' },
    @{ Id = 'CARRELLO'; User = $true; Rel = 'carrello.aspx'; Path = 'carrello.aspx'; Text = '^Il tuo carrello$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.2; Color = $ink; Mb = 6.4; Align = 'start' },
    @{ Id = 'AREA'; User = $true; Rel = 'myaccount.aspx'; Path = 'myaccount.aspx'; Text = '^(Ciao, .+|Benvenuto nella tua Dashboard)$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'ORDINI'; User = $true; Rel = 'documenti.aspx?t=4'; Path = 'documenti.aspx'; Text = '^I miei ordini$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'DATI'; User = $true; Rel = 'datiutente.aspx'; Path = 'datiutente.aspx'; Text = '^Gestione dati account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 8; Align = 'start' },
    @{ Id = 'PASSWORD'; User = $true; Rel = 'password.aspx'; Path = 'password.aspx'; Text = '^Cambia password$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 12; Align = 'start' },
    @{ Id = 'DETTAGLI'; User = $true; Rel = 'my-account-edit.aspx'; Path = 'my-account-edit.aspx'; Text = '^Dettagli account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' },
    @{ Id = 'REGISTRAZIONEUTENTE'; User = $true; Rel = 'registrazione.aspx'; Path = 'registrazione.aspx'; Text = '^Crea il tuo account$'; Big = 26; Small = 22; SmallBelow = 992; Weight = '700'; Lh = 1.25; Color = $ink; Mb = 0; Align = 'start' }
)
function Test-One($c, $o, [int]$w, [string]$tag) {
    $bad = New-Object Collections.Generic.List[string]
    $id = [string]$c.Id + $tag
    if ([string]$o.path -ne [string]$c.Path) { $bad.Add($id + ' NON PROVATO: pagina finale ' + [string]$o.path); return $bad }
    if ([bool]$o.logged -ne [bool]$c.User) { $bad.Add($id + ' NON PROVATO: sessione ' + $(if ($o.logged) { 'collegata' } else { 'anonima' }) + ' invece di ' + $(if ($c.User) { 'collegata' } else { 'anonima' })); return $bad }
    if ([int]$o.h1 -ne 1) { $bad.Add($id + ' titoli principali esposti: ' + [string]$o.h1 + ' invece di 1'); return $bad }
    if (-not [bool]$o.native) { $bad.Add($id + ' titoli principali: ruolo o livello alterato (role / aria-level)') }
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
    if ([bool]$o.cut -or [int]$o.right -gt [int]$o.vw -or [int]$o.left -lt 0) { $bad.Add($id + ' titolo tagliato o fuori dallo schermo') }
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
    $sec = if ($w -ge 992) { 24 } else { 20 }
    if ($bad.Count -eq 0 -and ([string]$c.Id).StartsWith('REGISTRAZIONE')) {
        if ([double]$o.sub -le 0) { $bad.Add([string]$c.Id + ' sottotitolo NON PROVATO: non trovato') }
        elseif ([Math]::Abs([double]$o.sub - $sec) -gt 0.2) { $bad.Add([string]$c.Id + ' sottotitolo: corpo ' + [string]$o.sub + ' invece di ' + $sec + ' (il titolo e ' + [string]$o.size + ')') }
    }
    if ($bad.Count -eq 0 -and [string]$c.Id -eq 'CONDIZIONI') {
        # il LAB non ha titoli nel testo dell'azienda: se ne inserisce uno nel contenitore e si legge la misura
        $r = [string](Invoke-KsJs $browser "(function(){var a=document.querySelector('article.tf-privacy');if(!a)return 'ASSENTE';var h=document.createElement('h2');h.textContent='Titolo di prova';a.appendChild(h);var c=getComputedStyle(h);return parseFloat(c.fontSize)+'|'+c.fontWeight;})()")
        if ($r -ne ([string]$sec + '|700')) { $bad.Add('CONDIZIONI titolo del testo dell''azienda: ' + $r + ' invece di ' + $sec + '|700') }
    }
    return $bad
}
function Invoke-Print($browser) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($id in @('CARRELLO', 'AREA', 'PASSWORD', 'FAQ')) {
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
$script:legalProbe = 0
# La funzione che ripulisce il testo delle condizioni, estratta dal sorgente e compilata in memoria.
function Test-Legal([string]$vbText) {
    $bad = New-Object Collections.Generic.List[string]
    $m = [regex]::Match($vbText, '(?s)Private Shared Function SanitizeLegalHtml\(.*?End Function')
    if (-not $m.Success) { $bad.Add('LEGALE NON PROVATO: funzione non trovata'); return $bad }
    $script:legalProbe++
    $name = 'KsLegalProbe' + [string]$PID + 'x' + [string]$script:legalProbe
    $code = "Imports System`r`nImports System.Text.RegularExpressions`r`nPublic Class " + $name + "`r`n" + ($m.Value -replace '^Private Shared', 'Public Shared') + "`r`nEnd Class"
    try { Add-Type -TypeDefinition $code -Language VisualBasic } catch { $bad.Add('LEGALE NON PROVATO: la funzione non compila'); return $bad }
    $in = '<H1 class="a">Uno</H1><p>t</p><div role="heading" aria-level="1">Due</div><h3>Tre</h3><h1>Quattro</h1>'
    $out = [string]([type]$name)::SanitizeLegalHtml($in)
    if ($out -match '(?i)<h1') { $bad.Add('LEGALE il testo dell''azienda conserva un titolo principale: ' + $out) }
    elseif ($out -match '(?i)role\s*=|aria-level') { $bad.Add('LEGALE il testo dell''azienda conserva ruolo o livello: ' + $out) }
    elseif ($out -ne '<h2 class="a">Uno</h2><p>t</p><div>Due</div><h3>Tre</h3><h2>Quattro</h2>') { $bad.Add('LEGALE risultato inatteso: ' + $out) }
    return $bad
}
function Test-Source {
    $bad = New-Object Collections.Generic.List[string]
    $wl = Get-Text $repoBytes['wishlist.aspx']
    if ($wl -notmatch '<h1 class="heading mb-1 ks-page-title">Wishlist</h1>') { $bad.Add('SORGENTE wishlist: titolo principale assente') }
    if ([regex]::Matches($wl, '<h1[\s>]').Count -ne 1) { $bad.Add('SORGENTE wishlist: numero di h1 diverso da 1') }
    foreach ($f in @('myaccount.aspx', 'documenti.aspx', 'datiutente.aspx', 'password.aspx', 'my-account-edit.aspx')) { if ([regex]::Matches((Get-Text $repoBytes[$f]), '<h1[\s>]').Count -ne 1) { $bad.Add('SORGENTE ' + $f + ': numero di h1 diverso da 1') } }
    foreach ($f in @('registrazione.aspx', 'remind.aspx', 'Contattaci.aspx', 'faq.aspx', 'privacy.aspx', 'condizioni-vendita.aspx', 'about.aspx', 'compare.aspx', 'track-your-order.aspx', '404.aspx')) { if ([regex]::Matches((Get-Text $repoBytes[$f]), '<h1[\s>]').Count -ne 1) { $bad.Add('SORGENTE ' + $f + ': numero di h1 diverso da 1') } }
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
$wanted = if ($Cases -ne '') { @($Cases.Split(',') | ForEach-Object { $_.Trim().ToUpper() }) } else { $allIds + @('STAMPA', 'NONCONSULTABILE', 'SORGENTE', 'LEGALE') }
try {
    Sync-Site
    if ($wanted -contains 'SORGENTE') { $bad = @(Test-Source); if ($bad.Count -eq 0) { Write-Host '  ok   sorgente' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } } }
    if ($wanted -contains 'LEGALE') { $bad = @(Test-Legal (Get-Text $repoBytes['condizioni-vendita.aspx.vb'])); if ($bad.Count -eq 0) { Write-Host '  ok   testo delle condizioni (funzione)' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } } }
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
            @{ Id = 'M12_ACCOUNT_DETAILS_BACK_TO_H4'; File = 'my-account-edit.aspx'; W = 1280; Case = 'DETTAGLI'; Expect = '1280 DETTAGLI titoli principali'; Old = '<h1 class="fw-semibold mb-0 ks-page-title">Dettagli account</h1>'; New = '<h4 class="fw-semibold mb-0 ks-page-title">Dettagli account</h4>' },
            @{ Id = 'M13_FAQ_TITLE_BACK_TO_H2'; File = 'faq.aspx'; W = 390; Case = 'FAQ'; Expect = '390 FAQ titoli principali'; Old = '<h1 class="title ks-page-title">Domande frequenti</h1>'; New = '<h2 class="title ks-page-title">Domande frequenti</h2>' },
            @{ Id = 'M14_PRIVACY_CLASS_REMOVED'; File = 'privacy.aspx'; W = 1280; Case = 'PRIVACY'; Expect = '1280 PRIVACY stile'; Old = '<h1 class="title ks-page-title">Privacy Policy</h1>'; New = '<h1 class="title">Privacy Policy</h1>' },
            @{ Id = 'M15_NOT_FOUND_BACK_TO_DIV'; File = '404.aspx'; W = 390; Case = 'NONTROVATA'; Expect = '390 NONTROVATA titoli principali'; Old = '<h1 class="heading text-center ks-page-title">Ops! Pagina non trovata</h1>'; New = '<div class="heading text-center ks-page-title">Ops! Pagina non trovata</div>' },
            @{ Id = 'M16_SECOND_TITLE_IN_CONTACTS'; File = 'Contattaci.aspx'; W = 390; Case = 'CONTATTI'; Expect = '390 CONTATTI titoli principali'; Old = '<h5 class="fw-semibold mb-10">Informazioni</h5>'; New = '<h1 class="fw-semibold mb-10">Informazioni</h1>' },
            @{ Id = 'M17_TITLE_LEVEL_OVERRIDDEN'; File = 'about.aspx'; W = 390; Case = 'CHISIAMO'; Expect = '390 CHISIAMO titoli principali'; Old = '<h1 class="title ks-page-title">Il nostro negozio</h1>'; New = '<h1 class="title ks-page-title" aria-level="2">Il nostro negozio</h1>' },
            @{ Id = 'M18_TITLE_TRANSPARENT'; File = 'track-your-order.aspx'; W = 390; Case = 'TRACCIA'; Expect = '390 TRACCIA titoli principali'; Old = '<h1 class="title ks-page-title">Traccia il tuo ordine</h1>'; New = '<h1 class="title ks-page-title" style="opacity:0">Traccia il tuo ordine</h1>' },
            @{ Id = 'M19_REGISTRATION_SUBTITLE_WITHOUT_RULE'; File = 'registrazione.aspx'; W = 1280; Case = 'REGISTRAZIONE'; Expect = '1280 REGISTRAZIONE sottotitolo'; Old = '<h3 class="fw-semibold mb_20 ks-register-subtitle">'; New = '<h3 class="fw-semibold mb_20">' },
            @{ Id = 'M20_COMPANY_H1_NOT_LOWERED'; File = 'condizioni-vendita.aspx.vb'; W = 0; Case = 'LEGALE'; Expect = 'LEGALE il testo dell''azienda conserva un titolo'; Old = 'value = Regex.Replace(value, "(?i)<(/?)h1\b", "<$1h2")'; New = '' },
            @{ Id = 'M21_COMPANY_ROLE_NOT_REMOVED'; File = 'condizioni-vendita.aspx.vb'; W = 0; Case = 'LEGALE'; Expect = 'LEGALE il testo dell''azienda conserva ruolo'; Old = 'value = Regex.Replace(value, "(?i)\s+(role|aria-level)\s*='; New = 'value = Regex.Replace(value, "(?i)\s+(role-off|aria-level-off)\s*=' },
            @{ Id = 'M22_COMPANY_HEADING_WITHOUT_SCALE'; File = $css; W = 1280; Case = 'CONDIZIONI'; Expect = '1280 CONDIZIONI titolo del testo'; Old = "  article.tf-privacy h2,`n  article.tf-privacy h3 {`n    font-size: var(--ks-title-section-size)"; New = "  article.tf-privacy-off h2,`n  article.tf-privacy-off h3 {`n    font-size: var(--ks-title-section-size)" }
        )
        foreach ($mu in $mutants) {
            if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
            $src = (Get-Text $repoBytes[$mu.File]).Replace("`r`n", "`n")
            $i0 = $src.IndexOf($mu.Old, [StringComparison]::Ordinal)
            if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($mu.Old, [StringComparison]::Ordinal)) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non unico'); $exit = 1; continue }
            $mut = $src.Replace($mu.Old, $mu.New)
            if ($mu.ContainsKey('Old2')) { $j0 = $mut.IndexOf($mu.Old2, [StringComparison]::Ordinal); if ($j0 -lt 0) { Write-Host ('  FAIL ' + $mu.Id + ': secondo punto non trovato'); $exit = 1; continue }; $mut = $mut.Substring(0, $j0) + $mu.New2 + $mut.Substring($j0 + $mu.Old2.Length) }
            if ($mu.Case -ne 'LEGALE') { Write-SiteText $mu.File $mut }
            try {
                $mb = if ($mu.Case -eq 'LEGALE') { @(Test-Legal $mut) } elseif ($mu.Case -eq 'NONCONSULTABILE') { @(Invoke-Unavailable) } else { @(Invoke-Width $mu.W @($mu.Case)) }
                if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' ; ')); $exit = 1 }
            } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
            finally { Write-Site $mu.File $repoBytes[$mu.File] }
        }
    }
} finally {
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('HEADING_LEVELS PASS' + $(if ($SkipMutants -or $Cases -ne '') { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (22 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'HEADING_LEVELS FAIL' }
exit $exit
