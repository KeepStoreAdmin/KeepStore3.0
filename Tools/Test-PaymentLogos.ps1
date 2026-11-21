[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$ShotDir = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# PAYMENT-LOGOS-1A. Marchi dei pagamenti nel piede di pagina, solo per i metodi davvero nominati per l'azienda dell'host.
# I marchi nascono dalla STESSA selezione finale del testo "Metodi di pagamento" (azienda dell'host, sessione compatibile, regola dei
# gateway, pulizia, deduplica, limite): carta nominata -> marchi delle carte; portafoglio nominato -> il suo marchio; altrimenti nulla.
# I nomi dei marchi e dei file stanno solo nel catalogo App_Code/KeepStorePaymentBrands.vb, mai nel codice o nel markup del piede.
# (a) parte compilata, senza database; (b) sorgente; (c) sito LAB (https, 127.0.0.1, porta 18843), due aziende, 320 / 390 / 1280 px.
# Senza -SkipLab i file del piede, il catalogo e i file dei marchi vengono copiati sul sito LAB (alla fine uguali al repository). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Norm([string]$t) { return ($t -replace "`r`n", "`n") }
function Read-Repo([string]$rel) { return (Norm ([IO.File]::ReadAllText((Join-Path $root $rel)))) }
$relAscx = 'Public\ui\controls\SiteFooter.ascx'; $relVb = 'Public\ui\controls\SiteFooter.ascx.vb'; $relBrands = 'App_Code\KeepStorePaymentBrands.vb'
$imgDir = 'Public\assets\images\pagamenti'
foreach ($f in @($relAscx, $relVb, $relBrands)) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('PAYMENT_LOGOS FAIL: file mancante ' + $f); exit 1 } }
$ascx = Read-Repo $relAscx; $vb = Read-Repo $relVb; $brands = Read-Repo $relBrands
$policy = Read-Repo 'App_Code\StorefrontCanonicalHostPolicy.vb'; $links = Read-Repo 'App_Code\KeepStoreContactLinks.vb'

function Get-PureRegion([string]$vbText) { $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "FooterPure"\n(.*?)\n[ \t]*#End Region'); if ($m.Success) { return $m.Groups[1].Value } else { return $null } }

# ---- (a) parte compilata ----
function New-Probe([string]$vbText, [string]$brandsText) {
    $region = Get-PureRegion $vbText
    if ($null -eq $region) { return 'REGIONE_PURA_ASSENTE' }
    $code = @"
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Public Class LogoProbe
$region
    Private Shared Function Build(ByVal c As Integer(), ByVal n As String(), ByVal ol As Integer(), ByVal ready As Boolean()) As IList(Of StorefrontPaymentMethod)
        If c Is Nothing Then Return Nothing
        Dim list As New List(Of StorefrontPaymentMethod)()
        For k As Integer = 0 To c.Length - 1
            list.Add(New StorefrontPaymentMethod(c(k), 100 + k, n(k), k, ol(k), ready(k)))
        Next
        Return list
    End Function
    Public Function Flags(ByVal host As Integer, ByVal sess As Integer, ByVal c As Integer(), ByVal n As String(), ByVal ol As Integer(), ByVal ready As Boolean(), ByVal live As Boolean) As Integer
        Return BuildFooterData(host, sess, "Alfa", "", "", "", "", Nothing, Build(c, n, ol, ready), live, 2026).PaymentBrands
    End Function
    Public Function Text(ByVal host As Integer, ByVal sess As Integer, ByVal c As Integer(), ByVal n As String(), ByVal ol As Integer(), ByVal ready As Boolean(), ByVal live As Boolean) As String
        Return BuildFooterData(host, sess, "Alfa", "", "", "", "", Nothing, Build(c, n, ol, ready), live, 2026).PaymentsHtml
    End Function
    Public Function CardsFlag() As Integer
        Return BrandCards
    End Function
    Public Function WalletFlag() As Integer
        Return BrandWallet
    End Function
    Public Function Logos(ByVal cards As Boolean, ByVal wallet As Boolean) As String
        Return KeepStorePaymentBrands.LogosHtml(cards, wallet)
    End Function
End Class
"@
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($policy, $links, $brandsText, $code))
    if ($c.Errors.HasErrors) { return ('COMPILAZIONE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'riga ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('LogoProbe', $true))
}
function Get-FileRatio([string]$name) {
    $p = Join-Path (Join-Path $root $imgDir) $name
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    if ($name -like '*.svg') {
        $m = [regex]::Match([IO.File]::ReadAllText($p), 'viewBox="\s*[\d.]+[\s,]+[\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)\s*"')
        if (-not $m.Success) { return 0 }
        return ([double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) / [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture))
    }
    $b = [IO.File]::ReadAllBytes($p)
    if ($b.Length -lt 24 -or $b[1] -ne 0x50 -or $b[2] -ne 0x4E -or $b[3] -ne 0x47) { return 0 }
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]; $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    if ($h -le 0) { return 0 }
    return ($w / [double]$h)
}
function Get-Images([string]$html) {
    $out = @()
    foreach ($m in [regex]::Matches($html, '<img\b[^>]*>')) {
        $t = $m.Value; $g = @{}
        foreach ($a in @('src', 'alt', 'width', 'height', 'loading', 'decoding')) { $x = [regex]::Match($t, '\b' + $a + '="([^"]*)"'); $g[$a] = $(if ($x.Success) { $x.Groups[1].Value } else { $null }) }
        $out += , $g
    }
    return , $out
}
function Test-Compiled([string]$vbText, [string]$brandsText) {
    $bad = New-Object Collections.Generic.List[string]
    $p = New-Probe $vbText $brandsText
    if ($p -is [string]) { $bad.Add('C00 ' + $p); return $bad }
    $K = [int]$p.CardsFlag(); $W = [int]$p.WalletFlag()
    if ($K -le 0 -or $W -le 0 -or $K -eq $W -or ($K -band $W) -ne 0) { $bad.Add('C00 valori dei due marchi non distinti'); return $bad }
    function F([int]$hostId, [int]$sess, [int[]]$c, [string[]]$n, [int[]]$ol, [bool[]]$r, [bool]$live) { return [int]$p.Flags($hostId, $sess, $c, $n, $ol, $r, $live) }
    function T([int]$hostId, [int]$sess, [int[]]$c, [string[]]$n, [int[]]$ol, [bool[]]$r, [bool]$live) { return [string]$p.Text($hostId, $sess, $c, $n, $ol, $r, $live) }
    $f = $false; $t = $true
    if ((F 1 0 @(1, 1) @('Carta', 'Bonifico') @(3, 0) @($f, $f) $f) -ne $K) { $bad.Add('C01 carta dell''azienda dell''host: marchi delle carte assenti') }
    if ((T 1 0 @(1, 1) @('Carta', 'Bonifico') @(3, 0) @($f, $f) $f) -cne 'Carta, Bonifico') { $bad.Add('C01 testo dei metodi cambiato') }
    if ((F 1 0 @(2, 1) @('Carta', 'Bonifico') @(3, 0) @($f, $f) $f) -ne 0) { $bad.Add('C02 carta di un''altra azienda: marchi mostrati') }
    if ((F 1 2 @(1, 1) @('Carta', 'Bonifico') @(3, 0) @($f, $f) $f) -ne 0) { $bad.Add('C03 sessione di un''altra azienda: marchi mostrati') }
    if ((F 0 0 @(1) @('Carta') @(3) @($f) $f) -ne 0) { $bad.Add('C03 host senza azienda: marchi mostrati') }
    foreach ($combo in @(@($f, $f), @($t, $f), @($f, $t), @($t, $t))) {
        $want = $(if ($combo[0] -and $combo[1]) { $W } else { 0 })
        if ((F 1 0 @(1) @('Portafoglio') @(2) @([bool]$combo[0]) ([bool]$combo[1])) -ne $want) { $bad.Add('C04 portafoglio con pronto=' + $combo[0] + ' consentito=' + $combo[1] + ': marchio ' + $(if ($want -eq 0) { 'mostrato' } else { 'assente' })) }
    }
    if ((F 1 0 @(1) @('Altro gateway') @(7) @($t) $t) -ne 0) { $bad.Add('C05 tipo di gateway sconosciuto: marchi mostrati') }
    if ((F 1 0 @(1, 1) @('carta@esempio', 'Bonifico') @(3, 0) @($f, $f) $f) -ne 0) { $bad.Add('C06 carta scartata dal testo (nome non mostrabile): marchi mostrati') }
    $names = @('A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'Carta'); $kinds = @(0, 0, 0, 0, 0, 0, 0, 0, 3); $cs = @(1, 1, 1, 1, 1, 1, 1, 1, 1); $rs = @($f, $f, $f, $f, $f, $f, $f, $f, $f)
    if ((F 1 0 $cs $names $kinds $rs $f) -ne 0) { $bad.Add('C07 carta oltre il limite delle voci: marchi mostrati') }
    if ((F 1 0 @(1, 1) @('Carta', 'carta') @(0, 3) @($f, $f) $f) -ne 0) { $bad.Add('C08 carta con un nome gia usato da un metodo senza gateway: marchi mostrati') }
    if ((F 1 0 @(1, 1) @('Carta', 'carta') @(3, 0) @($f, $f) $f) -ne $K) { $bad.Add('C08 carta nominata per prima: marchi assenti') }
    if ((F 1 0 @(1, 1) @('Contanti', 'Bonifico') @(0, 0) @($f, $f) $t) -ne 0) { $bad.Add('C09 soli metodi senza gateway: marchi mostrati') }
    if ((T 1 0 @(1, 1) @('Contanti', 'Bonifico') @(0, 0) @($f, $f) $t) -cne 'Contanti, Bonifico') { $bad.Add('C09 testo dei metodi cambiato') }
    if ([int]$p.Flags(1, 0, $null, $null, $null, $null, $true) -ne 0) { $bad.Add('C10 nessun metodo: marchi mostrati') }
    if ((F 1 0 @(1, 1) @('Carta', 'Portafoglio') @(3, 2) @($f, $t) $t) -ne ($K -bor $W)) { $bad.Add('C11 carta e portafoglio: attesi entrambi') }
    # catalogo
    if ([string]$p.Logos($false, $false) -cne '') { $bad.Add('K01 senza marchi il catalogo non e vuoto') }
    foreach ($case in @(@($true, $false, 2), @($false, $true, 1), @($true, $true, 3))) {
        $html = [string]$p.Logos([bool]$case[0], [bool]$case[1]); $imgs = Get-Images $html; $tag = 'K02 carte=' + $case[0] + ' portafoglio=' + $case[1]
        if (@($imgs).Count -ne [int]$case[2]) { $bad.Add($tag + ': immagini ' + @($imgs).Count + ', attese ' + $case[2]); continue }
        if ($html -notmatch '^<ul\b[^>]*\baria-label="[^"]{8,}"' -or ([regex]::Matches($html, '<li>')).Count -ne [int]$case[2] -or $html -notmatch '</ul>$') { $bad.Add($tag + ': elenco senza nome accessibile o con voci diverse dalle immagini') }
        foreach ($g in $imgs) {
            $file = [string]$g['src']; $name = [IO.Path]::GetFileName($file)
            if (-not $file.StartsWith('/Public/assets/images/pagamenti/') -or $name -notmatch '^[a-z0-9.-]+$') { $bad.Add($tag + ': indirizzo del file ' + $file); continue }
            $ratio = Get-FileRatio $name
            if ($ratio -le 0) { $bad.Add($tag + ': file del marchio inesistente o illeggibile ' + $name); continue }
            if ([string]::IsNullOrWhiteSpace([string]$g['alt'])) { $bad.Add($tag + ': testo alternativo vuoto per ' + $name) }
            $w = 0; $h = 0
            if (-not [int]::TryParse([string]$g['width'], [ref]$w) -or -not [int]::TryParse([string]$g['height'], [ref]$h) -or $w -le 0 -or $h -le 0) { $bad.Add($tag + ': misure non dichiarate per ' + $name); continue }
            if ([Math]::Abs(($w / [double]$h) - $ratio) / $ratio -gt 0.02) { $bad.Add($tag + ': proporzioni dichiarate ' + $w + 'x' + $h + ' diverse dal file ' + $name) }
        }
        if (@($imgs | ForEach-Object { [string]$_['alt'] } | Sort-Object -Unique).Count -ne @($imgs).Count) { $bad.Add($tag + ': testi alternativi ripetuti') }
    }
    return $bad
}

# ---- (b) sorgente ----
function Test-Source([string]$ascxText, [string]$vbText) {
    $bad = New-Object Collections.Generic.List[string]
    if (($ascxText + $vbText) -match '(?i)\b(Visa|Mastercard|Maestro|Discover)\b') { $bad.Add('S1 nome di un marchio scritto nel piede') }
    if ($vbText -match '(?i)"[^"\r\n]*\bPayPal\b[^"\r\n]*"' -or $ascxText -match '(?i)\bPayPal\b') { $bad.Add('S1 nome del portafoglio scritto nel piede') }
    if ($ascxText -notmatch '(?s)<asp:PlaceHolder ID="phFooterPayments" runat="server" Visible="false">\s*<p class="caption text-center text-break ft-payments">Metodi di pagamento: <asp:Literal ID="litFooterPayments" runat="server" EnableViewState="False" /></p>\s*<asp:Literal ID="litFooterPaymentLogos" runat="server" EnableViewState="False" />\s*</asp:PlaceHolder>') { $bad.Add('S2 il segnaposto dei marchi non e dentro il blocco dei pagamenti, dopo il testo') }
    $m = [regex]::Match($vbText, '(?s)If IsFooterTenantAllowed\(hostCompanyId, sessionCompanyId\) Then(.*?)Else')
    if (-not $m.Success -or $m.Groups[1].Value.IndexOf('data.PaymentBrands = FooterPaymentBrands(payments, hostCompanyId, payPalLive)', [StringComparison]::Ordinal) -lt 0 -or [regex]::Matches($vbText, 'data\.PaymentBrands = ').Count -ne 1) { $bad.Add('S3 i marchi non sono decisi (una volta) nel ramo dell''azienda consentita') }
    $pure = Get-PureRegion $vbText
    if ($null -eq $pure -or $pure -match 'KeepStorePaymentBrands') { $bad.Add('S4 la regione pura conosce il catalogo dei marchi') }
    if ([regex]::Matches($vbText, 'KeepStorePaymentBrands\.LogosHtml\(').Count -ne 1) { $bad.Add('S5 il catalogo non e chiamato una sola volta dal collegamento') }
    return $bad
}

# ---- (c) sito LAB ----
$labFiles = @($relAscx, $relVb, $relBrands)
$labImages = @(Get-ChildItem -LiteralPath (Join-Path $root $imgDir) -File | Where-Object { $_.Name -match '^(visa\.svg|mastercard\.svg|paypal-logo-2024\.png)$' } | ForEach-Object { Join-Path $imgDir $_.Name })
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $SitePath $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in ($labFiles + $labImages)) { Write-Site $f ([IO.File]::ReadAllBytes((Join-Path $root $f))) } }
$labJs = @'
(async function(){
function txt(e){return e?(e.textContent||'').replace(/\s+/g,' ').trim():'';}
window.scrollTo({top:document.documentElement.scrollHeight,behavior:'instant'});
var p=document.querySelector('.ft-payments');var o={text:txt(p),vw:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth+1,list:false,label:'',afterText:false,imgs:[]};
var ul=p?p.nextElementSibling:null; if(ul&&ul.tagName!=='UL')ul=null; o.afterText=!!ul;
var any=document.querySelector('.ft-bottom ul[aria-label] img'); if(!ul&&any){ul=any.closest('ul');}
if(!ul)return JSON.stringify(o);
o.list=true;o.label=ul.getAttribute('aria-label')||'';o.items=ul.querySelectorAll('li').length;
for (const im of ul.querySelectorAll('img')) {
  var g={alt:im.getAttribute('alt')||'',src:im.getAttribute('src')||'',ok:false,h:0,w:0,vis:0,attrs:!!(im.getAttribute('width')&&im.getAttribute('height'))};
  try { await im.decode(); } catch(e) {}
  g.ok=im.complete&&im.naturalWidth>0; var r=im.getBoundingClientRect(); g.h=r.height; g.w=r.width;
  if(g.ok){ var W=300,H=Math.max(1,Math.round(300*r.height/r.width)); var c=document.createElement('canvas'); c.width=W;c.height=H; var x=c.getContext('2d'); x.drawImage(im,0,0,W,H);
    try { var d=x.getImageData(0,0,W,H).data; var t=H,b=-1; for(var y=0;y<H;y++){ for(var i=0;i<W;i++){ if(d[(y*W+i)*4+3]>8){ if(y<t)t=y; if(y>b)b=y; break; } } } g.vis=(b>=t)?r.height*(b-t+1)/H:0; } catch(e) { g.vis=-1; } }
  o.imgs.push(g);
}
return JSON.stringify(o);})()
'@
function Invoke-Lab {
    $bad = New-Object Collections.Generic.List[string]
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
    try {
        try { $null = Invoke-KsCdp $b 'Network.enable' @{}; $null = Invoke-KsCdp $b 'Network.setCacheDisabled' @{ cacheDisabled = $true } } catch { }
        foreach ($h in @('www.taikun.it', 'www.webaffare.it')) {
            foreach ($w in @(320, 390, 1280)) {
                $tag = 'L ' + $h + ' ' + $w + ' px'
                $null = Invoke-KsCdp $b 'Emulation.setDeviceMetricsOverride' @{ width = $w; height = 800; deviceScaleFactor = 1; mobile = ($w -lt 700) }
                Open-KsUrl $b ('https://' + $h + ':18843/Contattaci.aspx') 300
                if ([string](Invoke-KsJs $b 'location.host') -ne ($h + ':18843')) { $bad.Add($tag + ': ORIGINE_INATTESA'); continue }
                Start-Sleep -Milliseconds 900
                $r = Invoke-KsCdp $b 'Runtime.evaluate' @{ expression = $labJs; awaitPromise = $true; returnByValue = $true } 60
                $s = ConvertFrom-Json ([string]$r['result']['value'])
                if ($ShotDir -ne '' -and $h -eq 'www.taikun.it') { Save-KsScreenshot $b (Join-Path $ShotDir ('piede-' + $w + '.png')) }
                $hasCard = ([string]$s.text -match '(?i)\bcarta\b')
                if ([string]$s.text -eq '') { $bad.Add($tag + ' NON PROVATO: il piede non nomina alcun metodo'); continue }
                $alts = @($s.imgs | ForEach-Object { [string]$_.alt })
                if ($hasCard) {
                    if (-not [bool]$s.list -or $alts.Count -ne 2) { $bad.Add($tag + ': carta nominata nel testo, marchi mostrati ' + $alts.Count + ' (attesi i due delle carte)'); continue }
                    if (-not [bool]$s.afterText) { $bad.Add($tag + ': l''elenco dei marchi non segue il testo dei metodi') }
                    if ([string]$s.label -eq '' -or [int]$s.items -ne $alts.Count) { $bad.Add($tag + ': elenco senza nome accessibile') }
                    foreach ($g in @($s.imgs)) {
                        if (-not [bool]$g.ok) { $bad.Add($tag + ': immagine non caricata ' + [string]$g.src) }
                        if (-not [bool]$g.attrs) { $bad.Add($tag + ': misure non dichiarate ' + [string]$g.src) }
                        if ([string]$g.alt -eq '') { $bad.Add($tag + ': testo alternativo vuoto ' + [string]$g.src) }
                    }
                    $vis = @($s.imgs | Where-Object { [bool]$_.ok } | ForEach-Object { [double]$_.vis })
                    if ($vis.Count -eq 2 -and (@($vis | Where-Object { $_ -le 0 }).Count -gt 0 -or [Math]::Abs($vis[0] - $vis[1]) -gt 1.5)) { $bad.Add($tag + ': altezza visibile dei marchi diversa (' + ([Math]::Round($vis[0], 1)) + ' e ' + ([Math]::Round($vis[1], 1)) + ' px)') }
                } elseif ($alts.Count -ne 0) { $bad.Add($tag + ': nessuna carta nel testo ma marchi mostrati') }
                if ([string]$s.text -notmatch '(?i)paypal' -and @($s.imgs | Where-Object { [string]$_.src -match '(?i)paypal' }).Count -gt 0) { $bad.Add($tag + ': marchio del portafoglio mostrato senza il metodo') }
                if ([bool]$s.overflow) { $bad.Add($tag + ': la pagina scorre in orizzontale') }
            }
        }
    } finally { Stop-KsBrowser $b }
    return $bad
}

$exit = 0
$all = New-Object Collections.Generic.List[string]
foreach ($x in (Test-Source $ascx $vb)) { $all.Add($x) }
foreach ($x in (Test-Compiled $vb $brands)) { $all.Add($x) }
if ($all.Count -eq 0) { Write-Host '  ok   regola dei marchi e catalogo (parte compilata e sorgente)' } else { $exit = 1; foreach ($x in ($all | Select-Object -First 14)) { Write-Host ('  FAIL ' + $x) } }

if (-not $SkipMutants -and $exit -eq 0) {
    $mutants = @(
        @{ Id = 'M01_BRANDS_BEFORE_THE_TEXT_FILTERS'; In = 'vb'; Expect = 'C06'; Old = '            If kinds IsNot Nothing Then kinds.Add(method.OnLine)' + "`n"; New = ''; Old2 = '            If Not IsFooterMethodShown(method, payPalLive) Then Continue For' + "`n"; New2 = '            If Not IsFooterMethodShown(method, payPalLive) Then Continue For' + "`n" + '            If kinds IsNot Nothing Then kinds.Add(method.OnLine)' + "`n" },
        @{ Id = 'M02_BRANDS_OUTSIDE_THE_COMPANY_GATE'; In = 'vb'; Expect = 'C03'; Old = '            data.PaymentBrands = FooterPaymentBrands(payments, hostCompanyId, payPalLive)' + "`n"; New = ''; Old2 = '        data.CopyrightHtml = BuildCopyrightHtml(year, data.CompanyName)'; New2 = '        data.PaymentBrands = FooterPaymentBrands(payments, If(hostCompanyId > 0, hostCompanyId, 1), payPalLive)' + "`n" + '        data.CopyrightHtml = BuildCopyrightHtml(year, data.CompanyName)' },
        @{ Id = 'M03_WALLET_WITH_ONE_CONSENT'; In = 'vb'; Expect = 'C04'; Old = 'Return payPalLive AndAlso method.GatewayReady'; New = 'Return method.GatewayReady' },
        @{ Id = 'M04_CARDS_ALWAYS'; In = 'vb'; Expect = 'C0'; Old = 'If kinds.Contains(CardOnLine) Then flags = flags Or BrandCards'; New = 'flags = flags Or BrandCards' },
        @{ Id = 'M05_OTHER_COMPANY_COUNTS'; In = 'vb'; Expect = 'C02'; Old = 'If method.CompanyId <> hostCompanyId Then Continue For'; New = 'If method.CompanyId < 0 Then Continue For' },
        @{ Id = 'M06_ONE_CARD_BRAND_ONLY'; In = 'brands'; Expect = 'K02 carte=True portafoglio=False: immagini'; Old = '            AppendLogo(sb, CardBrandB'; New = '            If False Then AppendLogo(sb, CardBrandB' },
        @{ Id = 'M07_SAME_BOX_FOR_EVERY_BRAND'; In = 'brands'; Expect = 'K02'; Old = '51, 36)'; New = '33, 24)' },
        @{ Id = 'M08_MISSING_FILE'; In = 'brands'; Expect = 'K02'; Old = '"mastercard.svg"'; New = '"mastercard-nuovo.svg"' },
        @{ Id = 'M09_EMPTY_ALT'; In = 'brands'; Expect = 'K02'; Old = 'sb.Append(""" alt=""").Append(alt)'; New = 'sb.Append(""" alt=""")' },
        @{ Id = 'M10_EMPTY_LIST_RENDERED'; In = 'brands'; Expect = 'K01'; Old = 'If Not showCards AndAlso Not showWallet Then Return String.Empty'; New = 'If showCards AndAlso Not showCards Then Return String.Empty' }
    )
    foreach ($mu in $mutants) {
        $src = $(if ($mu.In -eq 'vb') { $vb } else { $brands })
        $o1 = Norm $mu.Old
        if ($src.IndexOf($o1, [StringComparison]::Ordinal) -lt 0) { Write-Host ('  FAIL ' + $mu.Id + ': punto della mutazione non trovato'); $exit = 1; continue }
        $mut = $src.Replace($o1, (Norm $mu.New))
        if ($mu.ContainsKey('Old2')) { $o2 = Norm $mu.Old2; if ($mut.IndexOf($o2, [StringComparison]::Ordinal) -lt 0) { Write-Host ('  FAIL ' + $mu.Id + ': secondo punto non trovato'); $exit = 1; continue }; $mut = $mut.Replace($o2, (Norm $mu.New2)) }
        $mb = $(if ($mu.In -eq 'vb') { @(Test-Compiled $mut $brands) } else { @(Test-Compiled $vb $mut) })
        if (@($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 2) -join ' | ')); $exit = 1 }
    }
}

if ($SkipLab) { Write-Host '  NON ESEGUITO: sito LAB (-SkipLab)' }
elseif ($exit -eq 0) {
    if (-not (Test-Path -LiteralPath (Join-Path $SitePath $relAscx))) { Write-Host ('  FAIL cartella del sito LAB non trovata: ' + $SitePath); $exit = 1 }
    else {
        Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
        if ($ShotDir -ne '') { New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }
        try {
            Sync-Site
            $lab = @(Invoke-Lab)
            if ($lab.Count -eq 0) { Write-Host '  ok   sito LAB: marchi delle carte per le due aziende a 320, 390 e 1280 px' } else { $exit = 1; foreach ($x in ($lab | Select-Object -First 12)) { Write-Host ('  FAIL ' + $x) } }
            if (-not $SkipMutants -and $exit -eq 0) {
                $line = '        If litFooterPaymentLogos IsNot Nothing Then'
                $t = [IO.File]::ReadAllText((Join-Path $root $relVb))
                if ($t.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { Write-Host '  FAIL M11: punto della mutazione non trovato'; $exit = 1 }
                else {
                    [IO.File]::WriteAllText((Join-Path $SitePath $relVb), $t.Replace($line, '        If False Then'), (New-Object Text.UTF8Encoding($true)))
                    try { $mb = @(Invoke-Lab); if (@($mb | Where-Object { $_ -match 'marchi mostrati 0' }).Count -gt 0) { Write-Host '  ok   mutazione uccisa M11_LOGOS_NOT_BOUND (sito LAB)' } else { Write-Host ('  FAIL mutazione sopravvissuta M11_LOGOS_NOT_BOUND :: ' + (($mb | Select-Object -First 2) -join ' | ')); $exit = 1 } }
                    finally { Sync-Site }
                }
            }
        } finally {
            Sync-Site
            foreach ($f in $labFiles) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SitePath $f))) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root $f)))) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
        }
    }
}
if ($exit -eq 0) { Write-Host ('PAYMENT_LOGOS PASS' + $(if ($SkipLab) { ' (senza sito LAB)' } elseif ($SkipMutants) { ' (senza mutazioni)' } else { ' (11 mutazioni uccise)' })) } else { Write-Host 'PAYMENT_LOGOS FAIL' }
exit $exit
