[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# AUTH-PRIVATE-PAGES-NO-STORE-1A. Le pagine private (account, reimpostazione password, tracciamento ordine, pagamento, listino personale, conferme)
# rispondono con Cache-Control no-store e X-Robots-Tag noindex, anche con PathInfo, %2F, maiuscole e query; le pagine pubbliche NON hanno no-store.
# Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843, utente di prova): si leggono solo intestazioni e un marcatore nel corpo; nessun dato
# personale in output. Mutazioni sulla copia LAB di tre file; i byte ORIGINALI del sito sono rimessi alla fine. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'PRIVATE_NO_STORE FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $SitePath 'Page.master'))) { Write-Host ('PRIVATE_NO_STORE FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 }
$files = @('App_Code\StorefrontCanonicalHostPolicy.vb', 'Page.master.vb', 'Global.asax')
$repoBytes = @{}; $origBytes = @{}
foreach ($f in $files) {
    $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f))
    $sp = Join-Path $SitePath $f
    $origBytes[$f] = if (Test-Path -LiteralPath $sp) { [IO.File]::ReadAllBytes($sp) } else { $null }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
function Same-Bytes($a, $b) { if ($null -eq $a -or $null -eq $b) { return $false }; return ([Convert]::ToBase64String($a) -eq [Convert]::ToBase64String($b)) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-nostore-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')   # ridefinisce $base, $tmp, Invoke-Http, Invoke-Login, Invoke-Sql, Get-FieldName, New-FormFile, Check, $e2e
$jar = Join-Path $tmp 'auth.txt'; $anon = Join-Path $tmp 'anon.txt'
function Get-Hdr([string]$headers, [string]$name) { return [regex]::Match($headers, '(?im)^' + $name + ':\s*(.+)$').Groups[1].Value.Trim() }

# Scrive i byte indicati e aspetta che il sito risponda di nuovo (due risposte 200 di fila su una pagina pubblica).
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Http '/privacy.aspx' (Join-Path $tmp 'wait.txt')).Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Set-SiteBytes([string]$rel, $bytes) {
    $p = Join-Path $SitePath $rel
    if ($null -eq $bytes) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Start-Sleep -Seconds 3; Wait-Site }; return }
    if (Same-Bytes ([IO.File]::ReadAllBytes($p)) $bytes) { return }
    [IO.File]::WriteAllBytes($p, $bytes); Start-Sleep -Seconds 3; Wait-Site
}
function Set-SiteText([string]$rel, [string]$text) {
    $b = $repoBytes[$rel]; $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF)
    [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site
}
function Sync-Repo { foreach ($f in $files) { Set-SiteBytes $f $repoBytes[$f] } }
function Restore-Original { foreach ($f in $files) { Set-SiteBytes $f $origBytes[$f] } }

# percorso, collegato?, privata (no-store + noindex) oppure pubblica (niente no-store)
$cases = @(
    @('/track-your-order.aspx', $false, $true), @('/resetpassword.aspx?token=prova', $false, $true), @('/registrazioneok.aspx', $false, $true),
    @('/registrazione.aspx', $false, $true), @('/accessonegato.aspx', $false, $true), @('/bancasella.aspx', $false, $true),
    @('/Setup_Listino_Personalizzato.aspx', $true, $true),
    @('/myaccount.aspx', $true, $true), @('/datiutente.aspx', $true, $true), @('/my-account-edit.aspx', $true, $true),
    @('/documenti.aspx?t=4', $true, $true), @('/password.aspx', $true, $true),
    @('/REGISTRAZIONE.ASPX', $false, $true), @('/track-your-order.aspx?r=1', $false, $true),
    @('/registrazione.aspx/x', $false, $true), @('/registrazione.aspx%2Fx', $false, $true), @('/registrazione.aspx/x/y.aspx', $false, $true),
    @('/track-your-order.aspx/x', $false, $true),
    @('/Default.aspx', $false, $false), @('/articoli.aspx', $false, $false), @('/privacy.aspx', $false, $false), @('/faq.aspx', $false, $false), @('/about.aspx', $false, $false)
)
# Risultato: una riga per pagina con Loss (200 senza no-store o senza noindex su pagina privata; 200 con no-store su pagina pubblica) e Error (stato diverso da 200).
function Test-Pages([string]$tag) {
    $rows = New-Object Collections.Generic.List[object]
    $null = Invoke-Login $jar $false
    foreach ($c in $cases) {
        $j = if ($c[1]) { $jar } else { $anon }
        $x = Invoke-Http $c[0] $j
        $cc = Get-Hdr $x.Headers 'Cache-Control'; $rb = Get-Hdr $x.Headers 'X-Robots-Tag'
        $noStore = ($cc -match '(?i)no-store'); $noIndex = ($rb -match '(?i)noindex')
        $err = ($x.Status -ne 200)
        $loss = $false
        if (-not $err) { if ($c[2]) { $loss = (-not $noStore) -or (-not $noIndex) } else { $loss = $noStore } }
        $rows.Add([pscustomobject]@{ Path = $c[0]; Private = $c[2]; Status = $x.Status; Error = $err; Loss = $loss; NoStore = $noStore; NoIndex = $noIndex })
    }
    return $rows.ToArray()
}

# POST del tracciamento con l'evento del bottone: ordine reale del LAB (letto in sola lettura, mai stampato) e ordine inesistente.
function Test-TrackingPost {
    $res = @{ Real = 'NONE'; Bogus = $false }
    $sql = "SELECT CONCAT(vdocumenti.NDocumento, '|', utenti.Email) AS ksval FROM vdocumenti JOIN utenti ON vdocumenti.UtentiId = utenti.Id WHERE vdocumenti.TipoDocumentiId = 4 AND utenti.AziendeId = vdocumenti.AziendeId AND utenti.Email <> '' ORDER BY vdocumenti.id DESC LIMIT 12;"
    $rows = @(Invoke-Sql $sql | Where-Object { $_ -match '^[0-9A-Za-z/\-]+\|.+@.+' })
    $tj = Join-Path $tmp 'track.txt'
    foreach ($r in $rows) {
        $p = ([string]$r).Split('|', 2)
        $page = Invoke-Http '/track-your-order.aspx' $tj
        $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnTrack'); '__EVENTARGUMENT' = '' }
        $set[(Get-FieldName $page.Body 'txtOrderNumber')] = $p[0].Trim(); $set[(Get-FieldName $page.Body 'txtEmail')] = $p[1].Trim()
        $f = New-FormFile $page.Body $set
        try { $post = Invoke-Http '/track-your-order.aspx' $tj $f '/track-your-order.aspx' } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
        if ($post.Status -eq 200 -and $post.Body.Contains('documentidettaglio.aspx?id=')) {
            $res.Real = if ((Get-Hdr $post.Headers 'Cache-Control') -match '(?i)no-store' -and (Get-Hdr $post.Headers 'X-Robots-Tag') -match '(?i)noindex') { 'OK' } else { 'LOSS' }
            break
        }
    }
    $page = Invoke-Http '/track-your-order.aspx' $tj
    $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnTrack'); '__EVENTARGUMENT' = '' }
    $set[(Get-FieldName $page.Body 'txtOrderNumber')] = '999999999'; $set[(Get-FieldName $page.Body 'txtEmail')] = 'nessuno@example.invalid'
    $f = New-FormFile $page.Body $set
    try { $post = Invoke-Http '/track-your-order.aspx' $tj $f '/track-your-order.aspx' } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    $res.Bogus = ($post.Status -eq 200 -and -not $post.Body.Contains('documentidettaglio.aspx?id=') -and (Get-Hdr $post.Headers 'Cache-Control') -match '(?i)no-store')
    return $res
}

$exit = 0
try {
    Sync-Repo
    $rows = @(Test-Pages 'BASE')
    foreach ($r in $rows) {
        $bad = $r.Error -or $r.Loss
        if ($bad) { Write-Host ('  FAIL ' + $r.Path + ' status=' + $r.Status + ' noStore=' + $r.NoStore + ' noIndex=' + $r.NoIndex + $(if ($r.Private) { ' (privata)' } else { ' (pubblica)' })); $exit = 1 }
    }
    if ($exit -eq 0) { Write-Host ('  ok   ' + $rows.Count + ' pagine: private con no-store e noindex (anche PathInfo, %2F, maiuscole), pubbliche senza no-store') }
    $tp = Test-TrackingPost
    if ($tp.Real -eq 'OK') { Write-Host '  ok   POST di tracciamento con ordine reale: risultato mostrato, no-store e noindex' }
    elseif ($tp.Real -eq 'NONE') { Write-Host '  FAIL POST di tracciamento: nessun ordine del LAB ha mostrato il risultato (caso non provato)'; $exit = 1 }
    else { Write-Host '  FAIL POST di tracciamento con ordine reale: intestazioni mancanti'; $exit = 1 }
    if ($tp.Bogus) { Write-Host '  ok   POST di tracciamento con ordine inesistente: no-store' } else { Write-Host '  FAIL POST di tracciamento con ordine inesistente'; $exit = 1 }

    if (-not $SkipMutants -and $exit -eq 0) {
        $pol = 'App_Code\StorefrontCanonicalHostPolicy.vb'; $mas = 'Page.master.vb'
        $polText = Get-Text $repoBytes[$pol]; $masText = Get-Text $repoBytes[$mas]
        $nameMut = {
            param($n) @{ File = $pol; Text = $polText.Replace('"' + $n + '", ', ''); Expect = ('^/' + [regex]::Escape($n).Replace('\-', '-')) }
        }
        $mutants = [ordered]@{
            'M01_NO_TRACK'          = (& $nameMut 'track-your-order.aspx')
            'M02_NO_RESETPASSWORD'  = (& $nameMut 'resetpassword.aspx')
            'M03_NO_REGISTRAZIONEOK' = (& $nameMut 'registrazioneok.aspx')
            'M04_NO_SETUP_LISTINO'  = (& $nameMut 'setup_listino_personalizzato.aspx')
            'M05_NO_BANCASELLA'     = (& $nameMut 'bancasella.aspx')
            'M06_LIST_DISABLED'     = @{ File = $pol; Text = $polText.Replace('If NonIndexablePages.Contains(fileName) Then Return True', 'If NonIndexablePages.Contains(fileName) Then Return False'); Expect = '^/(?!my-account-)' }
            'M07_NO_FILEPATH'       = @{ File = $mas; Text = [regex]::Replace($masText, '\r?\n\s+StorefrontCanonicalHostPolicy\.IsNoIndexPath\(Request\.FilePath\) OrElse', ''); Expect = '(\.aspx/|%2F)' }
            'M08_NO_SETNOSTORE'     = @{ File = $mas; Text = [regex]::Replace($masText, '(?<=SetCacheability\(HttpCacheability\.NoCache\)\r?\n)\s+Response\.Cache\.SetNoStore\(\)\r?\n(?=\s+Response\.Cache\.SetRevalidation)', ''); Expect = '.' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++
            $mu = $mutants[$id]
            if ($mu.Text -ceq (Get-Text $repoBytes[$mu.File])) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-SiteText $mu.File $mu.Text
                $res = @(Test-Pages $id)
                $errors = @($res | Where-Object { $_.Error })
                $privateRows = @($res | Where-Object { $_.Private })
                $lossPaths = @($privateRows | Where-Object { $_.Loss } | ForEach-Object { $_.Path })
                $expectPaths = @($privateRows | Where-Object { $_.Path -match $mu.Expect } | ForEach-Object { $_.Path })
                $publicBad = @($res | Where-Object { (-not $_.Private) -and $_.Loss })
                $same = (($lossPaths | Sort-Object) -join '|') -ceq (($expectPaths | Sort-Object) -join '|')
                if ($errors.Count -eq 0 -and $publicBad.Count -eq 0 -and $lossPaths.Count -gt 0 -and $same) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $lossPaths.Count + ' pagine perdono la protezione, solo quelle attese)') }
                else { Write-Host ('  FAIL mutante ' + $id + ' non ucciso come atteso: perdite=' + $lossPaths.Count + ' attese=' + $expectPaths.Count + ' errori=' + $errors.Count); $exit = 1 }
            } finally { Sync-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
} finally {
    try { Restore-Original } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($exit -eq 0) { Write-Host ('PRIVATE_NO_STORE PASS' + $(if ($SkipMutants -or $MutantFilter -ne '') { ' (senza tutte le mutazioni)' } else { ' (8 mutanti)' })) } else { Write-Host 'PRIVATE_NO_STORE FAIL' }
exit $exit
