[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# AUTH-RESET-EMAIL-RACE-1C (parte a). Quando il cliente cambia l'e-mail di accesso in "Dati account", i codici di recupero della password
# gia inviati al vecchio indirizzo devono smettere di valere, nella stessa transazione del cambio. Restano intatti i codici gia usati,
# quelli di altri accessi e, se il cambio non avviene (password errata, solo telefono), anche quelli attivi.
# (A) sorgenti, (B) mutazioni, (C) prova reale sul SITO LAB (https, 127.0.0.1, porta 18843, database LAB), con un codice vero:
# la pagina di recupero aperta PRIMA del cambio e inviata DOPO non deve cambiare la password. Solo ASCII.
# Il comportamento compilato (rollback, numero di scritture) e provato da Tools/Test-AccountProfileTenantScope.ps1 (serve node.exe).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }
$files = @{ edit = Read-Repo 'my-account-edit.aspx.vb' }

function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $save = Get-Block $f.edit 'Protected Sub btnSave_Click(' 'End Sub'
    $sql = '"UPDATE login_password_reset_tokens SET RevokedAt = CURRENT_TIMESTAMP WHERE LoginId = @LoginId AND UsedAt IS NULL AND RevokedAt IS NULL"'
    # S01 istruzione esatta: solo i codici attivi dell'accesso autorizzato
    if (-not $save.Contains($sql)) { $fail.Add('S01 istruzione di revoca') }
    if (([regex]::Matches($f.edit, 'login_password_reset_tokens')).Count -ne 1) { $fail.Add('S01 una sola istruzione sui codici di recupero') }
    # S02 solo quando l'e-mail e cambiata, nella transazione del cambio, parametro con tipo esplicito, nessun vincolo sul numero di righe
    if ($save -notmatch 'If emailChanged Then\s+''[^\r\n]*\s+''[^\r\n]*\s+Using cmdCodes As New MySqlCommand\("UPDATE login_password_reset_tokens[^\r\n]*", conn, tr\)\s+cmdCodes\.Parameters\.Add\("@LoginId", MySqlDbType\.Int32\)\.Value = loginId\s+cmdCodes\.ExecuteNonQuery\(\)\s+End Using\s+End If') { $fail.Add('S02 revoca solo a e-mail cambiata, nella transazione, senza vincolo di righe') }
    # S03 ordine: dopo l'aggiornamento dell'accesso, prima del commit
    $iLogin = $save.IndexOf('If cmdLogin.ExecuteNonQuery() <> 1 Then Throw'); $iCodes = $save.IndexOf('Using cmdCodes As New MySqlCommand('); $iCommit = $save.IndexOf('tr.Commit()')
    if ($iLogin -lt 0 -or $iCodes -lt 0 -or $iCommit -lt 0 -or -not ($iLogin -lt $iCodes -and $iCodes -lt $iCommit)) { $fail.Add('S03 ordine: accesso aggiornato, codici annullati, commit') }
    # S04 nessuna tolleranza: un errore della revoca annulla tutto il cambio
    $codesBlock = if ($iCodes -ge 0 -and $iCommit -gt $iCodes) { $save.Substring($iCodes, $iCommit - $iCodes) } else { '' }
    if ($codesBlock -match '(?i)\bTry\b|\bCatch\b|On Error|1146') { $fail.Add('S04 errori della revoca tollerati') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$sourceFailed = -not (Test-Source $files)
if ($sourceFailed) { Write-Host 'EMAIL_CHANGE_REVOKES_CODES FAIL (sorgenti)'; if ($SkipLab) { exit 1 } } else { Write-Host 'EMAIL_CHANGE_REVOKES_CODES sorgenti OK' }

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_NO_REVOKE'; Old = '                            cmdCodes.ExecuteNonQuery()' + $nl; New = '' },
    @{ Id = 'M02_ALWAYS'; Old = 'If emailChanged Then' + $nl + "                        ' AUTH-RESET-EMAIL-RACE-1C"; New = 'If True Then' + $nl + "                        ' AUTH-RESET-EMAIL-RACE-1C" },
    @{ Id = 'M03_NO_LOGIN_FILTER'; Old = 'WHERE LoginId = @LoginId AND UsedAt IS NULL AND RevokedAt IS NULL"'; New = 'WHERE UsedAt IS NULL AND RevokedAt IS NULL"' },
    @{ Id = 'M04_REWRITES_REVOKED'; Old = 'AND UsedAt IS NULL AND RevokedAt IS NULL"'; New = 'AND UsedAt IS NULL"' },
    @{ Id = 'M05_TOUCHES_USED'; Old = 'AND UsedAt IS NULL AND RevokedAt IS NULL"'; New = 'AND RevokedAt IS NULL"' },
    @{ Id = 'M06_OUTSIDE_TRANSACTION'; Old = 'AND RevokedAt IS NULL", conn, tr)'; New = 'AND RevokedAt IS NULL", conn)' },
    @{ Id = 'M07_ROWS_REQUIRED'; Old = '                            cmdCodes.ExecuteNonQuery()'; New = '                            If cmdCodes.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("codes")' },
    @{ Id = 'M08_ERRORS_TOLERATED'; Old = '                            cmdCodes.ExecuteNonQuery()'; New = '                            Try : cmdCodes.ExecuteNonQuery() : Catch : End Try' },
    @{ Id = 'M09_COMMIT_BEFORE_REVOKE'; Old = '                    If emailChanged Then' + $nl + "                        ' AUTH-RESET-EMAIL-RACE-1C"; New = '                    tr.Commit()' + $nl + '                    If emailChanged Then' + $nl + "                        ' AUTH-RESET-EMAIL-RACE-1C" }
)
if (-not $SkipMutants -and -not $sourceFailed) {
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        $text = [string]$files.edit
        $i = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
        if ($i -lt 0) { $survived.Add($mu.Id + ' (ancora non trovata)'); continue }
        $copy = @{ edit = $text.Substring(0, $i) + $mu.New + $text.Substring($i + $mu.Old.Length) }
        if (Test-Source $copy -Quiet) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('EMAIL_CHANGE_REVOKES_CODES FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('EMAIL_CHANGE_REVOKES_CODES mutanti uccisi: ' + $mutants.Count)
}
if ($SkipLab) { Write-Host 'EMAIL_CHANGE_REVOKES_CODES PASS (senza prova sul sito LAB)'; exit 0 }

# ---------------------------------------------------------------- (C) prova reale sul sito LAB
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
$loginId = ''
$tag = 'ks_test_codes'
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'EMAIL_CHANGE_REVOKES_CODES FAIL credenziale di prova assente'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'EMAIL_CHANGE_REVOKES_CODES FAIL utente di prova assente sul LAB'; exit 1 }
    $otherLogin = Get-Scalar "SELECT MIN(id) AS ksval FROM login WHERE id<>$loginId AND Abilitato=1;"
    $clearActive = 'KsA' + [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
    $hashActive = Get-Sha256Hex $clearActive
    $hashUsed = Get-Sha256Hex ('KsU' + [Guid]::NewGuid().ToString('N'))
    $hashOther = Get-Sha256Hex ('KsO' + [Guid]::NewGuid().ToString('N'))
    $ins = "INSERT INTO login_password_reset_tokens (LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, RevokedAt, RequestIpHash, UserAgentHash, CreatedBy) VALUES "
    $setup = "DROP TABLE IF EXISTS ks_test_reset_codes_backup; CREATE TABLE ks_test_reset_codes_backup AS SELECT l.id, l.$col AS w, l.DataPassword AS d, l.Email AS em, u.Email AS uem, u.Telefono AS tel FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId; " +
        "DELETE FROM login_password_reset_tokens WHERE CreatedBy='$tag'; " +
        $ins + "($loginId, '$hashActive', NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL, NULL, NULL, NULL, '$tag'), ($loginId, '$hashUsed', NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NOW(), NULL, NULL, NULL, '$tag'), ($otherLogin, '$hashOther', NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL, NULL, NULL, NULL, '$tag');"
    $null = Invoke-Sql $setup -Write
    $state = "SELECT CONCAT((SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='$hashActive' AND RevokedAt IS NULL AND UsedAt IS NULL), '-', (SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='$hashUsed' AND RevokedAt IS NULL AND UsedAt IS NOT NULL), '-', (SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='$hashOther' AND RevokedAt IS NULL AND UsedAt IS NULL)) AS ksval;"
    $sameWord = "SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_reset_codes_backup b ON b.id=l.id WHERE BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d;"
    Check ((Get-Scalar $state) -eq '1-1-1' -and (Get-Scalar $sameWord) -eq '1') 'E00 dati di prova: codice attivo, codice usato, codice di un altro accesso'
    $secret = Get-Secret

    # la pagina di recupero si apre con il codice attivo (prima del cambio) e resta "aperta"
    $jarReset = Join-Path $tmp 'reset.txt'
    $resetPage = Invoke-Http ('/resetpassword.aspx?token=' + $clearActive) $jarReset
    Check ($resetPage.Status -eq 200 -and $resetPage.Body -match 'name="[^"]*\$tbPasswordNuova"') 'E01 prima del cambio il codice apre la pagina di recupero'

    $jar = Join-Path $tmp 'a.txt'
    $r = Invoke-Login $jar $false
    Check ($r.Status -eq 302) 'E02 accesso di prova'
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    $currentEmail = [regex]::Match($page.Body, 'name="[^"]*\$txtEmail"[^>]*value="([^"]*)"').Groups[1].Value
    if ($currentEmail -eq '') { $currentEmail = [regex]::Match($page.Body, 'value="([^"]*)"[^>]*name="[^"]*\$txtEmail"').Groups[1].Value }
    $newEmail = 'ks.codes.' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '@example.invalid'

    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = ('X' + [Guid]::NewGuid().ToString('N').Substring(0, 10)) }
    Check ((Get-Scalar $state) -eq '1-1-1') 'E03 cambio rifiutato (password errata): i codici restano come prima'
    $phone = '+39 0' + (Get-Random -Minimum 10000000 -Maximum 99999999)
    $r = Send-AccountEdit $jar @{ 'txtEmail' = $currentEmail; 'txtTelefono' = $phone }
    Check ($r.Body -match 'Dati aggiornati correttamente' -and (Get-Scalar $state) -eq '1-1-1') 'E04 solo il telefono: i codici restano come prima'

    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = $secret }
    Check ($r.Status -eq 200 -and $r.Body -match 'Dati aggiornati correttamente') 'E05 cambio dell''e-mail con la password giusta: riuscito'
    Check ((Get-Scalar $state) -eq '0-1-1') 'E06 codice attivo dell''utente annullato; codice usato e codice dell''altro accesso intatti'
    Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM login_password_reset_tokens WHERE TokenHash='$hashActive' AND RevokedAt IS NOT NULL AND UsedAt IS NULL;") -eq '1') 'E07 il codice risulta annullato, non usato'

    # la pagina di recupero aperta prima viene inviata adesso: la password non deve cambiare
    $newWord = 'Kr' + [Guid]::NewGuid().ToString('N').Substring(0, 14)
    $set = @{ (Get-FieldName $resetPage.Body 'tbPasswordNuova') = $newWord; (Get-FieldName $resetPage.Body 'tbPasswordConferma') = $newWord }
    $btn = Get-FieldName $resetPage.Body 'btnReset'; if ($btn -ne '') { $set[$btn] = 'Aggiorna password' }
    $f = New-FullFormFile $resetPage.Body $set
    $r = Invoke-Http ('/resetpassword.aspx?token=' + $clearActive) $jarReset $f ('/resetpassword.aspx?token=' + $clearActive)
    Check ((Get-Scalar $sameWord) -eq '1') 'E08 recupero inviato con il codice annullato: password INVARIATA'
    Check ($r.Body -notmatch 'Password aggiornata correttamente') 'E09 nessun messaggio di riuscita'
    $again = Invoke-Http ('/resetpassword.aspx?token=' + $clearActive) (Join-Path $tmp 'reset2.txt')
    Check ($again.Status -eq 200 -and $again.Body -notmatch 'name="[^"]*\$tbPasswordNuova"') 'E10 dopo il cambio il codice non apre piu la pagina di recupero'
    $secret = $null
} catch {
    Write-Host ('  FAIL eccezione: ' + $_.Exception.Message); $e2e.Add('eccezione')
} finally {
    if ($loginId -match '^\d+$') {
        try {
            $null = Invoke-Sql ("DELETE FROM login_password_reset_tokens WHERE CreatedBy='$tag'; UPDATE login l INNER JOIN ks_test_reset_codes_backup b ON b.id=l.id SET l.$col" + "=b.w, l.DataPassword=b.d, l.Email=b.em; UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_reset_codes_backup b ON b.id=l.id SET u.Email=b.uem, u.Telefono=b.tel;") -Write
            $same = Get-Scalar ("SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_reset_codes_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d AND l.Email<=>b.em AND u.Email<=>b.uem AND u.Telefono<=>b.tel;")
            $left = Get-Scalar "SELECT COUNT(*) AS ksval FROM login_password_reset_tokens WHERE CreatedBy='$tag';"
            if ($same -eq '1' -and $left -eq '0') { $null = Invoke-Sql 'DROP TABLE IF EXISTS ks_test_reset_codes_backup;' -Write; Write-Host '  ok   E99 dati di prova riportati allo stato di partenza' } else { Write-Host '  FAIL E99 dati di prova NON ripristinati (copia lasciata in ks_test_reset_codes_backup)'; $e2e.Add('E99') }
        } catch { $e2e.Add('E99 ripristino') }
    }
    Close-LabSite
}
if ($e2e.Count -gt 0 -or $sourceFailed) { Write-Host ('EMAIL_CHANGE_REVOKES_CODES FAIL sito LAB: ' + $e2e.Count + ' controlli' + $(if ($sourceFailed) { ' (e sorgenti)' } else { '' })); exit 1 }
Write-Host 'EMAIL_CHANGE_REVOKES_CODES PASS'
exit 0
