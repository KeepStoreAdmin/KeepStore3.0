[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Red, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# AUTH-PASSWORD-CHANGE-REVOKES-CODES-1A. Quando il cliente cambia la password in "Password" (password.aspx), i codici di recupero gia inviati
# smettono di valere NELLA STESSA transazione del cambio; restano intatti i codici usati, quelli gia revocati (timestamp invariato) e quelli di
# altri accessi; con password attuale errata o con 0 righe modificate non si revoca nulla; se la revoca fallisce la password NON cambia.
# Prova HTTP sul sito LAB (https, 127.0.0.1, porta 18843, cliente di prova) con codici veri. Mutazioni sulla copia LAB di password.aspx.vb.
# -Red usa la versione HEAD di password.aspx.vb (prima della correzione) per mostrare la prova rossa.
# Il LAB si ripristina da tabelle di copia che NON si cancellano ne si sovrascrivono: se esistono (prova interrotta) la prova si ferma.
# Mai password o valori di cookie in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'PASSWORD_CHANGE_CODES FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$rel = 'password.aspx.vb'
$sitePage = Join-Path $SitePath $rel
if (-not (Test-Path -LiteralPath $sitePage)) { Write-Host ('PASSWORD_CHANGE_CODES FAIL: pagina non trovata nel sito LAB: ' + $sitePage); exit 1 }
$repoBytes = [IO.File]::ReadAllBytes((Join-Path $root $rel)); $origBytes = [IO.File]::ReadAllBytes($sitePage)
if ($Red) {
    $tmpHead = Join-Path $env:TEMP ('ks-pwhead-' + [Guid]::NewGuid().ToString('N') + '.vb')
    & cmd.exe /c ('git -C "' + $root + '" show HEAD:' + $rel + ' > "' + $tmpHead + '"')   # cmd scrive i byte grezzi (il redirect di PowerShell 5.1 scrive UTF-16)
    $testBytes = [IO.File]::ReadAllBytes($tmpHead); Remove-Item -LiteralPath $tmpHead -Force
} else { $testBytes = $repoBytes }
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
function Same-Bytes($a, $b) { return ([Convert]::ToBase64String($a) -eq [Convert]::ToBase64String($b)) }

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-pwchange-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')   # ridefinisce $base, $tmp, $col, Invoke-Http, Invoke-Login, Invoke-Sql, Get-Scalar, Get-Secret, Get-FieldName, New-FormFile, Get-Sha256Hex, Check, $e2e

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
function Set-SiteText([string]$text) { $bom = ($testBytes.Length -ge 3 -and $testBytes[0] -eq 0xEF); [IO.File]::WriteAllText($sitePage, $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

$tag = 'ks_test_pwchg'
$loginId = ''; $backupMade = $false
$nl = "`r`n"

function Add-Fixtures {
    $script:hA1 = Get-Sha256Hex ('KsA1' + [Guid]::NewGuid().ToString('N')); $script:hA2 = Get-Sha256Hex ('KsA2' + [Guid]::NewGuid().ToString('N'))
    $script:hU = Get-Sha256Hex ('KsU' + [Guid]::NewGuid().ToString('N')); $script:hR = Get-Sha256Hex ('KsR' + [Guid]::NewGuid().ToString('N'))
    $script:hX = Get-Sha256Hex ('KsX' + [Guid]::NewGuid().ToString('N')); $script:hS = Get-Sha256Hex ('KsS' + [Guid]::NewGuid().ToString('N'))
    $ins = 'INSERT INTO login_password_reset_tokens (LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, RevokedAt, RequestIpHash, UserAgentHash, CreatedBy) VALUES '
    $fut = 'DATE_ADD(NOW(), INTERVAL 30 MINUTE)'
    $rows = @("($loginId, '$hA1', NOW(), $fut, NULL, NULL, NULL, NULL, '$tag')", "($loginId, '$hA2', NOW(), $fut, NULL, NULL, NULL, NULL, '$tag')",
              "($loginId, '$hU', NOW(), $fut, NOW(), NULL, NULL, NULL, '$tag')", "($loginId, '$hR', NOW(), $fut, NULL, '2020-01-01 00:00:00', NULL, NULL, '$tag')",
              "($otherLogin, '$hX', NOW(), $fut, NULL, NULL, NULL, NULL, '$tag')")
    if ($siblingLogin -match '^\d+$') { $rows += "($siblingLogin, '$hS', NOW(), $fut, NULL, NULL, NULL, NULL, '$tag')" }
    $null = Invoke-Sql ("DELETE FROM login_password_reset_tokens WHERE CreatedBy='$tag'; " + $ins + ($rows -join ', ') + ';') -Write
}
# Stato: A1 e A2 attivi (1/0), U usato e non revocato, R revocato con timestamp invariato, X e S attivi.
function Get-State {
    $q = "SELECT CONCAT(" +
        "(SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash IN ('$hA1','$hA2') AND UsedAt IS NULL AND RevokedAt IS NULL), '-'," +
        "(SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='$hU' AND UsedAt IS NOT NULL AND RevokedAt IS NULL), '-'," +
        "(SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='$hR' AND RevokedAt='2020-01-01 00:00:00'), '-'," +
        "(SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash IN ('$hX','$hS') AND UsedAt IS NULL AND RevokedAt IS NULL)) AS ksval;"
    return (Get-Scalar $q)
}
function Get-PwHash { return (Get-Scalar "SELECT SHA2(l.$col, 256) AS ksval FROM login l WHERE l.id=$loginId;") }
function Restore-Login { $null = Invoke-Sql ("UPDATE login l INNER JOIN ks_test_pwchg_backup b ON b.id=l.id SET l.$col" + '=b.w, l.DataPassword=b.d;') -Write }
function Prepare-Change {
    $jar = Join-Path $tmp ('c' + [Guid]::NewGuid().ToString('N') + '.txt')
    $page = $null; $diag = ''
    for ($try = 0; $try -lt 8; $try++) {
        $lr = Invoke-Login $jar $false
        $page = Invoke-Http '/password.aspx' $jar
        $diag = ('login=' + $lr.Status + ' pagina=' + $page.Status + ' ' + $page.Location)
        if ((Get-FieldName $page.Body 'tbPasswordAttuale') -ne '') { break }
        Start-Sleep -Seconds 6
    }
    if ((Get-FieldName $page.Body 'tbPasswordAttuale') -eq '') { throw ('PAGINA_PASSWORD_NON_RAGGIUNGIBILE ' + $diag) }
    return @{ Jar = $jar; Page = $page }
}
function Send-Change($ctx, [string]$current, [string]$newWord) {
    $page = $ctx.Page
    $set = @{ (Get-FieldName $page.Body 'tbPasswordAttuale') = $current; (Get-FieldName $page.Body 'tbPasswordNuova') = $newWord; (Get-FieldName $page.Body 'tbPasswordConferma') = $newWord }
    $btn = Get-FieldName $page.Body 'btnSalva'; if ($btn -ne '') { $set[$btn] = 'Aggiorna password' }
    $f = New-FormFile $page.Body $set
    try { return (Invoke-Http '/password.aspx' $ctx.Jar $f '/password.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Submit-Change([string]$current, [string]$newWord) { return (Send-Change (Prepare-Change) $current $newWord) }
$wrongWord = 'KsWrong' + [Guid]::NewGuid().ToString('N').Substring(0, 8)

# Casi. Ogni caso parte da dati di prova nuovi e dalla password di partenza.
function Run-Case([string]$id) {
    Restore-Login; Add-Fixtures
    $secret = Get-Secret
    $newWord = 'Kp' + [Guid]::NewGuid().ToString('N').Substring(0, 14)
    $before = Get-PwHash
    switch ($id) {
        'E01' {
            $r = Submit-Change $wrongWord $newWord
            Check ($r.Status -eq 200 -and $r.Body -match 'password attuale non' -and (Get-State) -eq ('2-1-1-' + $otherCount) -and (Get-PwHash) -eq $before) 'E01 password attuale errata: nessuna revoca, password invariata'
        }
        'E02' {
            $r = Submit-Change $secret $newWord
            Check ($r.Status -eq 200 -and $r.Body -match 'Password aggiornata correttamente' -and (Get-PwHash) -ne $before) 'E02a cambio riuscito'
            Check ((Get-State) -eq ('0-1-1-' + $otherCount)) 'E02b i due codici attivi annullati; usato, gia revocato (timestamp invariato) e codici di altri accessi intatti'
        }
        'E04' {
            $r = Submit-Change $secret $newWord
            Check ($r.Body -notmatch 'Password aggiornata correttamente' -and (Get-PwHash) -eq $before -and (Get-State) -eq ('2-1-1-' + $otherCount)) 'E04 revoca che fallisce: password INVARIATA, nessun successo, codici intatti'
        }
        'E05' {
            # una sessione SQL tiene il lock dell'accesso e cambia la password mentre la pagina attende: 0 righe -> nessuna revoca.
            # La finestra (il timeout dei lock del LAB e di circa 5 s) non e sempre centrata al primo colpo: fino a 3 tentativi.
            $ok = $false; $waited = 0.0; $r = $null
            for ($attempt = 1; $attempt -le 3 -and -not $ok; $attempt++) {
                if ($attempt -gt 1) { Restore-Login; Add-Fixtures }
                $ctx = Prepare-Change
                $holderWord = 'Kh' + [Guid]::NewGuid().ToString('N').Substring(0, 14)
                $hf = Join-Path $tmp 'holder.sql'
                [IO.File]::WriteAllText($hf, ("START TRANSACTION; SELECT id FROM login WHERE id=$loginId FOR UPDATE; DO SLEEP(5); UPDATE login SET $col='$holderWord' WHERE id=$loginId; COMMIT;"), $utf8)
                $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $labSql, '-SqlFile', $hf, '-Write') -PassThru -WindowStyle Hidden
                Start-Sleep -Milliseconds 2500
                $t0 = Get-Date
                $r = Send-Change $ctx $secret $newWord
                $waited = ((Get-Date) - $t0).TotalSeconds
                $null = $p.WaitForExit(60000)
                Remove-Item -LiteralPath $hf -Force -ErrorAction SilentlyContinue
                $ok = ($r.Status -eq 200 -and $r.Body -match 'Nessuna modifica eseguita' -and (Get-State) -eq ('2-1-1-' + $otherCount) -and $waited -ge 1)
            }
            Check $ok 'E05 0 righe modificate (password cambiata altrove mentre la pagina attende il lock): "Nessuna modifica eseguita" e nessun codice revocato'
        }
    }
}

$exit = 0
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { throw 'CREDENZIALE_DI_PROVA_ASSENTE' }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { throw 'UTENTE_DI_PROVA_ASSENTE' }
    $otherLogin = Get-Scalar "SELECT MIN(id) AS ksval FROM login WHERE id<>$loginId AND Abilitato=1;"
    $siblingLogin = Get-Scalar "SELECT COALESCE(MIN(l2.id), '') AS ksval FROM login l1 INNER JOIN login l2 ON l2.UtentiId=l1.UtentiId AND l2.id<>l1.id WHERE l1.id=$loginId;"
    $otherCount = if ($siblingLogin -match '^\d+$') { '2' } else { '1' }
    # le copie di ripristino non si cancellano ne si sovrascrivono: se esistono la prova precedente e stata interrotta
    $exists = Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name IN ('ks_test_pwchg_backup','ks_test_pwchg_tokens');"
    if ($exists -ne '0') { throw 'COPIA_DI_RIPRISTINO_PRESENTE_(recuperare_prima_i_dati_del_LAB)' }
    $null = Invoke-Sql ("CREATE TABLE ks_test_pwchg_backup AS SELECT l.id, l.$col AS w, l.DataPassword AS d FROM login l WHERE l.id=$loginId; " +
        "CREATE TABLE ks_test_pwchg_tokens AS SELECT t.id, t.UsedAt, t.RevokedAt FROM login_password_reset_tokens t WHERE t.LoginId IN ($loginId, $otherLogin" + $(if ($siblingLogin -match '^\d+$') { ", $siblingLogin" } else { '' }) + ');') -Write
    $backupMade = $true
    Check ((Get-Scalar 'SELECT COUNT(*) AS ksval FROM ks_test_pwchg_backup;') -eq '1') 'E00 copia dei dati di prova'
    Set-SiteBytes $testBytes
    foreach ($c in @('E01', 'E02', 'E04', 'E05')) {
        if ($c -eq 'E04') {
            # la revoca fallisce (tabella inesistente nella copia LAB): tutto il cambio si annulla
            Set-SiteText ((Get-Text $testBytes).Replace('UPDATE login_password_reset_tokens SET', 'UPDATE login_password_reset_tokens_inesistente SET'))
        }
        Run-Case $c
        if ($c -eq 'E04') { Set-SiteBytes $testBytes }
    }
    if ($e2e.Count -gt 0) { $exit = 1 }

    if (-not $SkipMutants -and $exit -eq 0) {
        $t = Get-Text $testBytes
        $revokeStmt = 'UPDATE login_password_reset_tokens SET RevokedAt = CURRENT_TIMESTAMP WHERE LoginId = @LoginId AND UsedAt IS NULL AND RevokedAt IS NULL'
        $mutants = [ordered]@{
            'M01_NO_REVOKE'      = @{ Text = $t.Replace('                cmdCodes.ExecuteNonQuery()' + $nl, ''); Cases = @('E02') }
            'M02_COMMIT_FIRST'   = @{ Text = $t.Replace('            tx.Commit()' + $nl + '            Return True', '            Return True').Replace('            Using cmdCodes As New MySqlCommand(', '            tx.Commit()' + $nl + '            Using cmdCodes As New MySqlCommand('); Cases = @('E04') }
            'M03_ERRORS_SWALLOWED' = @{ Text = $t.Replace('                cmdCodes.ExecuteNonQuery()', '                Try : cmdCodes.ExecuteNonQuery() : Catch : End Try'); Cases = @('E04') }
            'M04_NO_LOGIN_FILTER' = @{ Text = $t.Replace('WHERE LoginId = @LoginId AND UsedAt IS NULL', 'WHERE UsedAt IS NULL'); Cases = @('E02') }
            'M05_TOUCHES_USED'   = @{ Text = $t.Replace('AND UsedAt IS NULL AND RevokedAt IS NULL"', '"'); Cases = @('E02') }
            'M06_REVOKE_ON_ZERO' = @{ Text = $t.Replace('            If Not changed Then' + $nl + '                tx.Rollback()' + $nl + '                Return False' + $nl + '            End If' + $nl, ''); Cases = @('E05') }
            'M07_WRONG_PW_REVOKES' = @{ Text = $t.Replace('If Not ValidatePasswordChange(oldPwd, newPwd, newPwd2, currentPassword, validationMessage) Then', 'If False Then'); Cases = @('E01') }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            if ($mu.Text -ceq $t) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            $before = $e2e.Count
            try {
                Set-SiteText $mu.Text
                foreach ($c in $mu.Cases) {
                    if ($c -eq 'E04') { Set-SiteText ($mu.Text.Replace('UPDATE login_password_reset_tokens SET', 'UPDATE login_password_reset_tokens_inesistente SET')) }
                    Run-Case $c
                }
                if ($e2e.Count -gt $before) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (' + ($mu.Cases -join ',') + ')'); while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) } }
                else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Set-SiteBytes $testBytes }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total)
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    if ($backupMade) {
        try {
            $null = Invoke-Sql ("DELETE FROM login_password_reset_tokens WHERE CreatedBy='$tag'; UPDATE login l INNER JOIN ks_test_pwchg_backup b ON b.id=l.id SET l.$col" + '=b.w, l.DataPassword=b.d; UPDATE login_password_reset_tokens t INNER JOIN ks_test_pwchg_tokens k ON k.id=t.id SET t.UsedAt=k.UsedAt, t.RevokedAt=k.RevokedAt;') -Write
            $okPw = Get-Scalar "SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_pwchg_backup b ON b.id=l.id WHERE BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d;"
            $badTok = Get-Scalar 'SELECT COUNT(*) AS ksval FROM login_password_reset_tokens t INNER JOIN ks_test_pwchg_tokens k ON k.id=t.id WHERE NOT (t.UsedAt<=>k.UsedAt AND t.RevokedAt<=>k.RevokedAt);'
            $left = Get-Scalar "SELECT COUNT(*) AS ksval FROM login_password_reset_tokens WHERE CreatedBy='$tag';"
            if ($okPw -eq '1' -and $badTok -eq '0' -and $left -eq '0') { $null = Invoke-Sql 'DROP TABLE ks_test_pwchg_backup; DROP TABLE ks_test_pwchg_tokens;' -Write; Write-Host '  ok   E99 password e codici del cliente di prova riportati allo stato di partenza' }
            else { Write-Host '  FAIL E99 dati di prova NON ripristinati: le tabelle ks_test_pwchg_backup e ks_test_pwchg_tokens restano per il recupero'; $exit = 1 }
        } catch { Write-Host '  FAIL E99 ripristino non riuscito: le tabelle di copia restano per il recupero'; $exit = 1 }
    }
    try { Set-SiteBytes $origBytes } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host ('PASSWORD_CHANGE_CODES PASS' + $(if ($SkipMutants -or $MutantFilter -ne '') { ' (senza tutte le mutazioni)' } else { ' (7 mutanti)' })) } else { Write-Host 'PASSWORD_CHANGE_CODES FAIL' }
exit $exit
