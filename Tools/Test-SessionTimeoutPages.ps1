[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# SESSION-TIMEOUT-REGISTRATION-1A. La pagina di registrazione / dati non cambia la durata della sessione che riceve
# (prima la portava a 10 minuti per tutto il sito, anche per chi era collegato).
# Prova sul sito LAB (https, 127.0.0.1, porta 18843): una pagina di prova temporanea, creata SOLO nella copia LAB e rimossa alla fine,
# porta la durata a 45 minuti (valore diverso dalla configurazione) e mette un marcatore nella sessione; poi si apre la registrazione,
# si invia il modulo senza premere nulla (invio "nudo": nessun gestore, nessun salvataggio) e si rilegge: stessa sessione, ancora 45.
# Da anonimo e da utente di prova collegato. Mutazioni sulla copia LAB del code-behind, file rimessi alla fine.
# Sola lettura sul database. La pagina di prova risponde solo a richieste locali e stampa solo un numero e 0/1. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @('registrazione.aspx', 'registrazione.aspx.vb')
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $f))) { Write-Host ('SESSION_TIMEOUT FAIL: file mancante ' + $f); exit 1 } }
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
# la cartella deve essere la copia LAB, mai la copia di lavoro
$siteFull = [IO.Path]::GetFullPath($SitePath).TrimEnd('\')
if ($siteFull -notmatch '(?i)\\KeepStoreRegOrderLab-[^\\]+\\site$' -or $siteFull -ieq [IO.Path]::GetFullPath($root).TrimEnd('\') -or -not (Test-Path -LiteralPath (Join-Path $siteFull 'Page.master'))) { Write-Host ('SESSION_TIMEOUT FAIL: cartella del sito LAB non valida: ' + $SitePath); exit 1 }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
$base = 'https://www.taikun.it:18843'
function Write-Site([string]$rel, [byte[]]$bytes) { $p = Join-Path $siteFull $rel; if (-not (Test-Path -LiteralPath $p) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($bytes)) { [IO.File]::WriteAllBytes($p, $bytes) } }
function Sync-Site { foreach ($f in $files) { Write-Site $f $repoBytes[$f] } }
function Write-SiteText([string]$rel, [string]$text) { $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF); $crlf = (Get-Text $b).Contains("`r`n"); if ($crlf) { $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n") }; [IO.File]::WriteAllText((Join-Path $siteFull $rel), $text, (New-Object Text.UTF8Encoding($bom))) }
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath (Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'))
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$probeName = 'ks-probe-' + [Guid]::NewGuid().ToString('N') + '.aspx'
$probePath = Join-Path $siteFull $probeName
$probeCode = @'
<%@ Page Language="VB" EnableSessionState="True" %>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs)
        If Not Request.IsLocal Then
            Response.StatusCode = 404
            Response.End()
        End If
        Dim n As Integer
        If Integer.TryParse(Request.QueryString("set"), n) AndAlso n >= 1 AndAlso n <= 120 Then Session.Timeout = n
        If Request.QueryString("mark") = "1" Then Session("ksProbeMark") = "1"
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Write("TIMEOUT=" & Session.Timeout.ToString() & ";MARK=" & If(Session("ksProbeMark") Is Nothing, "0", "1") & ";")
    End Sub
</script>
'@
function Read-Probe($browser, [string]$query) {
    $js = "fetch('/" + $probeName + $query + "',{credentials:'same-origin',cache:'no-store'}).then(function(r){return r.text();}).then(function(t){var m=t.match(/TIMEOUT=(\d+);MARK=([01]);/);return m?(m[1]+'|'+m[2]):'?';}).catch(function(e){return 'ERR';})"
    $v = ([string](Invoke-KsJs $browser $js)).Split('|')
    if ($v.Count -ne 2) { return @{ T = -1; M = '?' } }
    return @{ T = [int]$v[0]; M = [string]$v[1] }
}
function Open-Page($browser, [string]$rel) {
    for ($a = 1; $a -le 3; $a++) {
        try { Open-KsUrl $browser ($base + '/' + $rel) 300 } catch { if ($a -eq 3) { throw } }
        try { if ([string](Invoke-KsJs $browser 'location.origin') -eq $base -and [bool](Invoke-KsJs $browser '!!document.querySelector("footer")')) { Start-Sleep -Milliseconds 600; return } } catch { }
        Start-Sleep -Seconds 4
    }
    throw 'ORIGINE_INATTESA'
}
$pageJs = "(function(){var a=document.querySelector('[id`$=`"lnkAccount`"]');var h=document.querySelector('h1');var n=performance.getEntriesByType('navigation')[0];return JSON.stringify({path:location.pathname.split('/').pop(),title:h?(h.textContent||'').replace(/\s+/g,' ').trim():'',logged:!!a&&!/login\.aspx/i.test(a.getAttribute('href')||''),redirects:n?n.redirectCount:-1,type:n?n.type:''});})()"
function Read-Page($browser) { return (ConvertFrom-Json ([string](Invoke-KsJs $browser $pageJs))) }
function Test-Registration([string]$tag, $p, [bool]$user, $bad) {
    $want = if ($user) { 'I tuoi dati' } else { 'Crea il tuo account' }
    if ([string]$p.path -ne 'registrazione.aspx') { $bad.Add($tag + ' NON PROVATO: pagina finale ' + [string]$p.path); return $false }
    if ([bool]$p.logged -ne $user) { $bad.Add($tag + ' NON PROVATO: sessione ' + $(if ($p.logged) { 'collegata' } else { 'anonima' })); return $false }
    if ([string]$p.title -ne $want) { $bad.Add($tag + ' NON PROVATO: titolo [' + [string]$p.title + ']'); return $false }
    if ([int]$p.redirects -ne 0) { $bad.Add($tag + ' NON PROVATO: la risposta e arrivata dopo ' + [string]$p.redirects + ' rinvii'); return $false }
    return $true
}
# Una sequenza per uno stato (anonimo / collegato). $set = 0: sessione lasciata com'e.
function Invoke-Sequence($browser, [bool]$user, [int]$set) {
    $bad = New-Object Collections.Generic.List[string]
    $who = if ($user) { 'collegato' } else { 'anonimo' }
    $tag = $who + $(if ($set -gt 0) { '' } else { ' (durata non toccata)' })
    $q = if ($set -gt 0) { '?mark=1&set=' + $set } else { '?mark=1' }
    $s0 = Read-Probe $browser $q
    if ([int]$s0.T -lt 1 -or [string]$s0.M -ne '1') { $bad.Add($tag + ' NON PROVATO: pagina di prova non risponde'); return $bad }
    if ($set -gt 0 -and [int]$s0.T -ne $set) { $bad.Add($tag + ' NON PROVATO: durata iniziale ' + [string]$s0.T + ' invece di ' + $set); return $bad }
    $want = [int]$s0.T
    Open-Page $browser 'registrazione.aspx'
    if (-not (Test-Registration ($tag + ' dopo la pagina') (Read-Page $browser) $user $bad)) { return $bad }
    $s1 = Read-Probe $browser ''
    if ([string]$s1.M -ne '1') { $bad.Add($tag + ' NON PROVATO: sessione sostituita dopo la pagina'); return $bad }
    if ([int]$s1.T -ne $want) { $bad.Add($tag + ' dopo la pagina: durata ' + [string]$s1.T + ' minuti invece di ' + $want) }
    if ($set -gt 0) {
        # invio nudo del modulo: nessun pulsante, nessun gestore
        $null = Invoke-KsJs $browser "(function(){var f=document.forms[0];var t=document.getElementById('__EVENTTARGET');if(t)t.value='';HTMLFormElement.prototype.submit.call(f);return 1;})()"
        Start-Sleep -Milliseconds 800
        for ($i = 0; $i -lt 60; $i++) { try { if ([string](Invoke-KsJs $browser 'document.readyState') -eq 'complete' -and [bool](Invoke-KsJs $browser '!!document.querySelector("footer")')) { break } } catch { }; Start-Sleep -Milliseconds 500 }
        Start-Sleep -Milliseconds 600
        if ([string](Invoke-KsJs $browser 'location.origin') -ne $base) { $bad.Add($tag + ' NON PROVATO: origine inattesa dopo l''invio'); return $bad }
        if (-not (Test-Registration ($tag + ' dopo l''invio') (Read-Page $browser) $user $bad)) { return $bad }
        $s2 = Read-Probe $browser ''
        if ([string]$s2.M -ne '1') { $bad.Add($tag + ' NON PROVATO: sessione sostituita dopo l''invio'); return $bad }
        if ([int]$s2.T -ne $want) { $bad.Add($tag + ' dopo l''invio: durata ' + [string]$s2.T + ' minuti invece di ' + $want) }
    }
    return $bad
}
function Enter-User($browser) {
    Open-Page $browser 'login.aspx'
    if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_tbPassword")')) {
        Set-KsValue $browser '#MainContent_tbUsername' 'PROVA'; Set-KsValue $browser '#MainContent_tbPassword' (Get-Secret); Invoke-KsClick $browser '#MainContent_btnLogin'
        Start-Sleep -Milliseconds 1500
    }
}
# Giro completo: anonimo (durata a 45), sessione anonima non toccata, collegato (durata a 45). Riprova una volta se la sessione viene sostituita
# (dopo piu ricompilazioni il sito puo riavviarsi) o se il browser si blocca.
function Invoke-All {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $bad = New-Object Collections.Generic.List[string]; $b = $null
        try {
            $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
            Open-Page $b 'Default.aspx'
            foreach ($x in (Invoke-Sequence $b $false 45)) { $bad.Add($x) }
            Stop-KsBrowser $b; $b = $null
            $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it', 'www.webaffare.it') -Width 1280 -Height 900
            Open-Page $b 'Default.aspx'
            foreach ($x in (Invoke-Sequence $b $false 0)) { $bad.Add($x) }
            Enter-User $b
            Open-Page $b 'myaccount.aspx'
            foreach ($x in (Invoke-Sequence $b $true 45)) { $bad.Add($x) }
        } catch { $bad.Add('NON PROVATO: errore del browser: ' + $_.Exception.Message) }
        finally { if ($b) { Stop-KsBrowser $b } }
        if (@($bad | Where-Object { $_ -match 'NON PROVATO' }).Count -eq 0 -or $attempt -eq 2) { return $bad }
        Start-Sleep -Seconds 5
    }
}
function Test-Source {
    $bad = New-Object Collections.Generic.List[string]
    if ((Get-Text $repoBytes['registrazione.aspx.vb']) -match '(?im)^[^''\r\n]*Session\.Timeout\s*=') { $bad.Add('SORGENTE registrazione.aspx.vb imposta ancora la durata della sessione') }
    return $bad
}

$exit = 0
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -match 'ks-edge-' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
try {
    if (Test-Path -LiteralPath $probePath) { throw 'la pagina di prova esiste gia' }
    [IO.File]::WriteAllText($probePath, $probeCode, $utf8)
    Sync-Site
    $bad = @(Test-Source); if ($bad.Count -eq 0) { Write-Host '  ok   sorgente' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } }
    $bad = @(Invoke-All)
    if ($bad.Count -eq 0) { Write-Host '  ok   anonimo e collegato: la durata resta quella ricevuta (45), anche dopo l''invio del modulo' } else { $exit = 1; foreach ($x in $bad) { Write-Host ('  FAIL ' + $x) } }

    if (-not $SkipMutants -and $exit -eq 0) {
        $anchor = "        ' SESSION-TIMEOUT-REGISTRATION-1A: questa pagina non cambia la durata della sessione"
        $mutants = @(
            @{ Id = 'M01_TEN_MINUTES_AGAIN'; Expect = 'anonimo dopo la pagina: durata 10'; Line = '        Session.Timeout = 10' },
            @{ Id = 'M02_FIXED_THIRTY'; Expect = 'anonimo dopo la pagina: durata 30'; Line = '        Session.Timeout = 30' },
            @{ Id = 'M03_TEN_ONLY_ON_POSTBACK'; Expect = 'anonimo dopo l''invio: durata 10'; Expect2 = 'collegato dopo l''invio: durata 10'; Line = '        If Page.IsPostBack Then Session.Timeout = 10' },
            @{ Id = 'M04_TEN_ONLY_WHEN_SIGNED_IN'; Expect = 'collegato dopo la pagina: durata 10'; Line = '        If Not Me.Session("LoginId") Is Nothing Then Session.Timeout = 10' }
        )
        $src = (Get-Text $repoBytes['registrazione.aspx.vb']).Replace("`r`n", "`n")
        $i0 = $src.IndexOf($anchor, [StringComparison]::Ordinal)
        if ($i0 -lt 0 -or $i0 -ne $src.LastIndexOf($anchor, [StringComparison]::Ordinal)) { Write-Host '  FAIL mutazioni: punto non unico'; $exit = 1 }
        else {
            $eol = $src.IndexOf("`n", $i0)
            foreach ($mu in $mutants) {
                if ($MutantFilter -ne '' -and $mu.Id -notmatch $MutantFilter) { continue }
                Write-SiteText 'registrazione.aspx.vb' ($src.Substring(0, $eol + 1) + $mu.Line + "`n" + $src.Substring($eol + 1))
                try {
                    $mb = @(Invoke-All)
                    $hit = @($mb | Where-Object { ([string]$_).StartsWith($mu.Expect) }).Count -gt 0
                    if ($hit -and $mu.ContainsKey('Expect2')) { $hit = @($mb | Where-Object { ([string]$_).StartsWith($mu.Expect2) }).Count -gt 0 }
                    if ($hit) { Write-Host ('  ok   mutazione uccisa ' + $mu.Id) } else { Write-Host ('  FAIL mutazione sopravvissuta ' + $mu.Id + ' :: ' + (($mb | Select-Object -First 3) -join ' ; ')); $exit = 1 }
                } catch { Write-Host ('  FAIL ' + $mu.Id + ': ' + $_.Exception.Message); $exit = 1 }
                finally { Write-Site 'registrazione.aspx.vb' $repoBytes['registrazione.aspx.vb'] }
            }
        }
    }
} catch { Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1 }
finally {
    if (Test-Path -LiteralPath $probePath) { Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $probePath) { Write-Host '  ATTENZIONE: pagina di prova non rimossa'; $exit = 1 }
    Sync-Site
    foreach ($f in $files) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $siteFull $f))) -ne [Convert]::ToBase64String($repoBytes[$f])) { Write-Host ('  ATTENZIONE: file del LAB non ripristinato: ' + $f); $exit = 1 } }
}
if ($exit -eq 0) { Write-Host ('SESSION_TIMEOUT PASS' + $(if ($SkipMutants) { ' (senza mutazioni)' } elseif ($MutantFilter -ne '') { ' (mutazioni filtrate)' } else { ' (4 mutazioni uccise sul sito LAB)' })) } else { Write-Host 'SESSION_TIMEOUT FAIL' }
exit $exit
