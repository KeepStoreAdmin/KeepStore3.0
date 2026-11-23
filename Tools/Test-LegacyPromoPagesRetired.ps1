[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# LEGACY-PROMO-PAGES-RETIRE-1A. promo.aspx e promo_in_scadenza.aspx sono ponti di compatibilita come promozioni.aspx: GET/HEAD 301 e altri metodi 303
# verso /articoli.aspx?inpromo=1, corpo vuoto, nessun cookie di sessione, nessun accesso a DB o master. promo_in_scadenza.aspx con QUALSIASI query
# string va alla destinazione "invalid" (fail chiuso, ct non e mai inoltrato); promo.aspx ignora sempre la query (la pagina non la usava).
# Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843): client SENZA redirect e SENZA cookie. Mutazioni sulla copia LAB; i byte originali sono rimessi.
# Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'LEGACY_PROMO FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$files = @('promo.aspx', 'promo.aspx.vb', 'promo_in_scadenza.aspx', 'promo_in_scadenza.aspx.vb')
$repoBytes = @{}; $origBytes = @{}
foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)); $origBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $SitePath $f)) }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$tmp = Join-Path $env:TEMP ('ks-legacypromo-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$e2e = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) } }

# Una richiesta senza cookie e senza redirect: stato, Location, Set-Cookie, dimensione del corpo.
function Invoke-Raw([string]$method, [string]$path, [string]$postData = '') {
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.html')
    $a = @('--noproxy', '*', '-s', '--max-time', '120', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}')
    if ($method -eq 'HEAD') { $a += @('-I') }
    elseif ($method -eq 'POST') { $a += @('-X', 'POST', '--data', $postData, '-H', 'Content-Type: application/x-www-form-urlencoded') }
    $a += ($base + $path)
    $code = (& curl.exe @a) -join ''
    $h = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $loc = ''; $m = [regex]::Match($h, '(?im)^Location:\s*(\S+)'); if ($m.Success) { $loc = $m.Groups[1].Value }
    $len = if (Test-Path -LiteralPath $out) { (Get-Item -LiteralPath $out).Length } else { 0 }
    return @{ Status = [int]$code; Location = $loc; Cookie = ($h -match '(?im)^Set-Cookie:'); BodyLen = $len }
}
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Raw 'GET' '/privacy.aspx').Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Deploy-Repo { foreach ($f in $files) { [IO.File]::WriteAllBytes((Join-Path $SitePath $f), $repoBytes[$f]) }; Start-Sleep -Seconds 3; Wait-Site }
function Restore-Site { foreach ($f in $files) { [IO.File]::WriteAllBytes((Join-Path $SitePath $f), $origBytes[$f]) }; Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$f, [string]$text) { $bom = ($repoBytes[$f].Length -ge 3 -and $repoBytes[$f][0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $f), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

$dest = '/articoli.aspx?inpromo=1'
$invalid = '/articoli.aspx?inpromo=1&pid=invalid'
# (pagina, metodo, query, corpo POST, stato atteso, Location attesa)
$cases = @(
    @('promo.aspx', 'GET', '', '', 301, $dest),
    @('promo.aspx', 'HEAD', '', '', 301, $dest),
    @('promo.aspx', 'POST', '', '__EVENTTARGET=legacy', 303, $dest),
    @('promo.aspx', 'POST', '', '__VIEWSTATE=ZmFsc28%3D&__EVENTTARGET=legacy', 303, $dest),
    @('promo.aspx', 'GET', '?pid=5&x=1', '', 301, $dest),
    @('promo_in_scadenza.aspx', 'GET', '', '', 301, $dest),
    @('promo_in_scadenza.aspx', 'HEAD', '', '', 301, $dest),
    @('promo_in_scadenza.aspx', 'POST', '', '__EVENTTARGET=legacy', 303, $dest),
    @('promo_in_scadenza.aspx', 'POST', '', '__VIEWSTATE=ZmFsc28%3D&__EVENTTARGET=legacy', 303, $dest),
    @('promo_in_scadenza.aspx', 'GET', '?ct=5', '', 301, $invalid),
    @('promo_in_scadenza.aspx', 'GET', '?ct=30000', '', 301, $invalid),
    @('promo_in_scadenza.aspx', 'GET', '?utm_source=x', '', 301, $invalid),
    @('promo_in_scadenza.aspx', 'GET', '?ct', '', 301, $invalid)
)
function Run-Cases {
    $bad = 0
    foreach ($c in $cases) {
        $r = Invoke-Raw $c[1] ('/' + $c[0] + $c[2]) $c[3]
        $ok = ($r.Status -eq $c[4]) -and ($r.Location -ceq $c[5]) -and (-not $r.Cookie) -and ($c[1] -eq 'HEAD' -or $r.BodyLen -eq 0)
        if (-not $ok) { $bad++ }
        Check $ok ($c[0] + ' ' + $c[1] + ' ' + $c[2] + ' -> ' + $c[4] + ' ' + $c[5] + ' (visto ' + $r.Status + ' ' + $r.Location + $(if ($r.Cookie) { ' COOKIE' } else { '' }) + ' corpo=' + $r.BodyLen + ')')
    }
    return $bad
}

$exit = 0
try {
    Deploy-Repo
    $null = Run-Cases
    foreach ($f in @('promo.aspx', 'promo_in_scadenza.aspx')) {
        $t = (Get-Text $repoBytes[$f]).Trim()
        Check ($t -match '^<%@ Page [^>]*%>$' -and $t -notmatch 'MasterPageFile' -and $t -notmatch '<asp:') ($f + ': markup = sola direttiva senza master ne controlli')
    }
    if ($e2e.Count -gt 0) { $exit = 1 }
    if (-not $SkipMutants -and $exit -eq 0) {
        $inSc = Get-Text $repoBytes['promo_in_scadenza.aspx.vb']
        $pr = Get-Text $repoBytes['promo.aspx']
        $mutants = [ordered]@{
            'M01_MASTER_KEPT'   = @{ File = 'promo.aspx'; From = 'AutoEventWireup="false"'; To = 'MasterPageFile="~/Page.master" AutoEventWireup="false"' }
            'M02_QUERY_IGNORED' = @{ File = 'promo_in_scadenza.aspx.vb'; From = 'Request.QueryString.Count > 0'; To = 'False' }
            'M03_POST_302'      = @{ File = 'promo_in_scadenza.aspx.vb'; From = '303'; To = '302' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            $src = if ($mu.File -eq 'promo.aspx') { $pr } else { $inSc }
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            $before = $e2e.Count
            try {
                Set-Mutant $mu.File ($src.Replace($mu.From, $mu.To))
                $saveOut = $e2e.Count
                $bad = 0
                foreach ($c in $cases) {
                    $r = Invoke-Raw $c[1] ('/' + $c[0] + $c[2]) $c[3]
                    $ok = ($r.Status -eq $c[4]) -and ($r.Location -ceq $c[5]) -and (-not $r.Cookie) -and ($c[1] -eq 'HEAD' -or $r.BodyLen -eq 0)
                    if (-not $ok) { $bad++ }
                }
                if ($bad -gt 0) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $bad + ' casi diversi)') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'LEGACY_PROMO PASS' } else { Write-Host 'LEGACY_PROMO FAIL' }
exit $exit
