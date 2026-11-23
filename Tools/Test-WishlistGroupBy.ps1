[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# WISHLIST-MYSQL8-GROUPBY-1A. La pagina Preferiti (wishlist.aspx) si apre con MySQL 8 e ONLY_FULL_GROUP_BY: una card per articolo, in ordine
# per id, anche se lo stesso articolo e in wishlist piu volte e un altro utente ha lo stesso articolo. Prova HTTP sul sito LAB (https, 127.0.0.1,
# porta 18843, utente di prova). Fixture inserita DIRETTAMENTE in wishlist (solo gli id creati, cancellati nel finally). Mutazioni sulla copia LAB
# di wishlist.aspx.vb; i byte originali del sito sono rimessi alla fine. Nessun dato personale in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'WISHLIST_GROUPBY FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$rel = 'wishlist.aspx.vb'
$sitePage = Join-Path $SitePath $rel
if (-not (Test-Path -LiteralPath $sitePage)) { Write-Host ('WISHLIST_GROUPBY FAIL: pagina non trovata nel sito LAB: ' + $sitePage); exit 1 }
$repoBytes = [IO.File]::ReadAllBytes((Join-Path $root $rel)); $origBytes = [IO.File]::ReadAllBytes($sitePage)
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
function Same-Bytes($a, $b) { return ([Convert]::ToBase64String($a) -eq [Convert]::ToBase64String($b)) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-wishlist-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')   # ridefinisce $base, $tmp, Invoke-Http, Invoke-Login, Invoke-Sql, Get-Scalar, Check, $e2e
$jar = Join-Path $tmp 'auth.txt'; $anon = Join-Path $tmp 'anon.txt'

function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Http '/privacy.aspx' (Join-Path $tmp 'wait.txt')).Status } catch { $st = 0 }
        if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
function Set-SiteBytes($bytes) { if (Same-Bytes ([IO.File]::ReadAllBytes($sitePage)) $bytes) { return }; [IO.File]::WriteAllBytes($sitePage, $bytes); Start-Sleep -Seconds 3; Wait-Site }
function Set-SiteText([string]$text) { $bom = ($repoBytes.Length -ge 3 -and $repoBytes[0] -eq 0xEF); [IO.File]::WriteAllText($sitePage, $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

# Esegue le richieste e restituisce l'esito dei controlli: Status200, Cards (numero di card), Order (id in ordine crescente), Links (link A e B presenti),
# Empty (messaggio con wishlist vuota), Anon (rinvio ad accessonegato).
function Get-Results([int]$idA, [int]$idB) {
    $r = @{}
    $x = Invoke-Http '/wishlist.aspx' $jar
    $r.Status200 = ($x.Status -eq 200)
    $ids = @([regex]::Matches($x.Body, 'id="[^"]*_BT_Rimuovi_wishlist_\d+"') | ForEach-Object { $_.Value })
    $r.Cards = $ids.Count
    # per ogni card (da un bottone Rimuovi al successivo) si prende il primo link di dettaglio: ignora pager e griglie annidate
    $chunks = @([regex]::Split($x.Body, 'id="[^"]*_BT_Rimuovi_wishlist_\d+"') | Select-Object -Skip 1)
    $links = @($chunks | ForEach-Object { $m = [regex]::Match($_, 'articolo\.aspx\?id=(\d+)'); if ($m.Success) { [int]$m.Groups[1].Value } })
    $r.Order = ($links -join ',')
    $r.Links = ($r.Order -eq ($idA.ToString() + ',' + $idB.ToString()))
    $r.Anon = $false
    $a = Invoke-Http '/wishlist.aspx' $anon
    $r.Anon = ($a.Status -eq 302 -and $a.Location -match '(?i)accessonegato')
    return $r
}

$exit = 0
$uid = 0; $other = 0; $before = 0; $saved = ''
try {
    $uid = [int](Get-Scalar "SELECT UtentiId AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $listino = [int](Get-Scalar "SELECT Listino AS ksval FROM vlogin WHERE UserName = 'PROVA' LIMIT 1;")
    $other = [int](Get-Scalar "SELECT id AS ksval FROM utenti WHERE id <> $uid ORDER BY id LIMIT 1;")
    $idA = [int](Get-Scalar "SELECT MIN(id) AS ksval FROM vsuperarticoli WHERE NListino = $listino;")
    $idB = [int](Get-Scalar "SELECT MIN(id) AS ksval FROM vsuperarticoli WHERE NListino = $listino AND id > $idA;")
    if ($uid -le 0 -or $other -le 0 -or $idA -le 0 -or $idB -le 0) { throw 'FIXTURE_NOT_FOUND' }
    $before = [int](Get-Scalar 'SELECT COALESCE(MAX(id_wishlist), 0) AS ksval FROM wishlist;')
    # le righe che il cliente di prova ha gia nel LAB si salvano, si tolgono per la prova e si rimettono con gli stessi id alla fine
    $saved = Get-Scalar "SELECT COALESCE(GROUP_CONCAT(CONCAT('(', id_wishlist, ',', id_utente, ',', id_articolo, ')') SEPARATOR ','), '') AS ksval FROM wishlist WHERE id_utente = $uid;"
    if ($saved -ne '') { $null = Invoke-Sql "DELETE FROM wishlist WHERE id_utente = $uid;" -Write }
    $null = Invoke-Sql ("INSERT INTO wishlist (id_utente, id_articolo) VALUES ($other, $idA), ($uid, $idA), ($uid, $idA), ($uid, $idB);") -Write
    Set-SiteBytes $repoBytes
    $null = Invoke-Login $jar $false

    $res = Get-Results $idA $idB
    Check $res.Status200 'collegato: la pagina Preferiti risponde 200 (non InternalError)'
    Check ($res.Cards -eq 2) ('una card per articolo (attese 2, trovate ' + $res.Cards + ')')
    Check $res.Links ('gli articoli A e B compaiono in ordine per id (attesi ' + $idA + ',' + $idB + '; trovati ' + $res.Order + ')')
    Check $res.Anon 'anonimo: rinvio ad accessonegato'
    $null = Invoke-Sql ("DELETE FROM wishlist WHERE id_wishlist > $before AND id_utente = $uid;") -Write
    $x = Invoke-Http '/wishlist.aspx' $jar
    $empty = ($x.Status -eq 200) -and ([regex]::IsMatch($x.Body, '(?i)wishlist\s+(\S|&[a-z#0-9]+;)\s*vuota')) -and (-not [regex]::IsMatch($x.Body, '_BT_Rimuovi_wishlist_\d+'))
    Check $empty 'wishlist vuota: messaggio e nessuna card'
    if ($e2e.Count -gt 0) { $exit = 1 }

    if (-not $SkipMutants -and $exit -eq 0) {
        $null = Invoke-Sql ("INSERT INTO wishlist (id_utente, id_articolo) VALUES ($uid, $idA), ($uid, $idA), ($uid, $idB);") -Write
        $text = Get-Text $repoBytes
        $tail = ') ks_w WHERE ks_w.WishlistRowRank=1 ORDER BY ks_w.id"'
        $mutants = [ordered]@{
            'M01_GROUP_BY_ID'    = @{ Text = $text.Replace($tail, ') ks_w WHERE ks_w.WishlistRowRank=1 GROUP BY ks_w.id"'); Fail = 'Status200' }
            'M02_NO_RANK_FILTER' = @{ Text = $text.Replace($tail, ') ks_w ORDER BY ks_w.id"'); Fail = 'Cards' }
            'M03_PARTITION_ROW'  = @{ Text = $text.Replace('PARTITION BY vsuperarticoli.id', 'PARTITION BY wishlist.id_wishlist'); Fail = 'Cards' }
            'M04_USER_OUTSIDE'   = @{ Text = $text.Replace('WHERE (wishlist.id_utente=@id) AND (vsuperarticoli.NListino=@listino)) ks_w WHERE ks_w.WishlistRowRank=1', 'WHERE (vsuperarticoli.NListino=@listino)) ks_w WHERE ks_w.WishlistRowRank=1 AND ks_w.id_utente=@id'); Fail = 'Links' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++
            $mu = $mutants[$id]
            if ($mu.Text -ceq $text) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-SiteText $mu.Text
                $m = Get-Results $idA $idB
                $failed = switch ($mu.Fail) { 'Status200' { -not $m.Status200 } 'Cards' { $m.Status200 -and $m.Cards -ne 2 } 'Links' { $m.Status200 -and -not $m.Links } }
                if ($failed) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + $mu.Fail + ')') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Set-SiteBytes $repoBytes }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
        Write-Host '  nota: il mutante "ORDER BY esterno tolto" non e uccidibile via HTTP (la finestra restituisce gia per id): dichiarato'
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { if ($before -gt 0 -and $uid -gt 0) { $null = Invoke-Sql ("DELETE FROM wishlist WHERE id_wishlist > $before AND id_utente IN ($uid, $other);") -Write } } catch { Write-Host '  ATTENZIONE: pulizia della wishlist non riuscita'; $exit = 1 }
    try { if ($saved -ne '') { $null = Invoke-Sql ("INSERT INTO wishlist (id_wishlist, id_utente, id_articolo) VALUES " + $saved + ";") -Write } } catch { Write-Host '  ATTENZIONE: ripristino delle righe del cliente di prova non riuscito'; $exit = 1 }
    try { Set-SiteBytes $origBytes } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host ('WISHLIST_GROUPBY PASS' + $(if ($SkipMutants -or $MutantFilter -ne '') { ' (senza tutte le mutazioni)' } else { ' (4 mutanti)' })) } else { Write-Host 'WISHLIST_GROUPBY FAIL' }
exit $exit
