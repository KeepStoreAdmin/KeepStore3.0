[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# AUTH-EMAIL-CHANGE-PASSWORD-1B. L'e-mail di accesso (che insieme a codice fiscale o partita IVA serve a recuperare la password) si cambiava
# senza password da un browser collegato. Ora: in "Dati account" (my-account-edit) il cambio dell'e-mail chiede la password attuale, verificata
# nella stessa istruzione che scrive; la vecchia pagina datiutente non scrive piu l'e-mail. Indirizzo e telefoni si salvano come prima.
# (A) sorgenti, (B) mutazioni, (C) prova reale sul SITO LAB (https, 127.0.0.1, porta 18843, database LAB). Solo ASCII.
# Il comportamento compilato di my-account-edit.aspx.vb e provato da Tools/Test-AccountProfileTenantScope.ps1 (serve node.exe).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    editUi = Read-Repo 'my-account-edit.aspx'
    edit   = Read-Repo 'my-account-edit.aspx.vb'
    datiUi = Read-Repo 'datiutente.aspx'
    dati   = Read-Repo 'datiutente.aspx.vb'
}
$wrongMessage = 'La password attuale non e corretta'

function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $c = $f.edit; $d = $f.dati
    $save = Get-Block $c 'Protected Sub btnSave_Click(' 'End Sub'
    # S01 la password attuale si legge grezza e il campo si svuota subito
    if ($save -notmatch 'Dim currentPassword As String = If\(txtCurrentPassword\.Text, String\.Empty\)\s+txtCurrentPassword\.Text = String\.Empty') { $fail.Add('S01 password attuale letta grezza e campo svuotato') }
    if ($save -match '(?i)(CleanText|Trim|ToLower|ToUpper)\w*\(\s*txtCurrentPassword|txtCurrentPassword\.Text\.(Trim|ToLower|ToUpper)|currentPassword\.(Trim|ToLower|ToUpper)') { $fail.Add('S01 password attuale trasformata') }
    # S02 "e-mail cambiata" si decide sul dato letto sotto blocco, non sulla sessione
    if ($save -notmatch 'Dim emailChanged As Boolean = Not String\.Equals\(If\(updated\.Email, String\.Empty\)\.Trim\(\), If\(current\.Email, String\.Empty\)\.Trim\(\), StringComparison\.OrdinalIgnoreCase\)') { $fail.Add('S02 confronto con il dato letto sotto blocco') }
    if ($save -match 'Session\("LoginEmail"\)[^\r\n]*(Equals|<>|=\s*updated)' -and $save -notmatch 'If emailChanged Then Session\("LoginEmail"\) = updated\.Email') { $fail.Add('S02 uso della sessione nel confronto') }
    if ($save -match 'restoredFromDevice|KeepStore:StaySignedIn:Restored') { $fail.Add('S02 rifiuto delle sessioni ripristinate ancora presente') }
    # S03 ordine: validazione dei dati, poi password vuota = nessuna scrittura
    $iValid = $save.IndexOf('If Not ValidateProfileInput(updated, validationMessage) Then'); $iEmpty = $save.IndexOf('If emailChanged AndAlso currentPassword.Length = 0 Then'); $iSql = $save.IndexOf('"UPDATE utenti u " &')
    if ($iValid -lt 0 -or $iEmpty -lt 0 -or $iSql -lt 0 -or -not ($iValid -lt $iEmpty -and $iEmpty -lt $iSql)) { $fail.Add('S03 ordine: validazione, password vuota, scrittura') }
    # S04 verifica nella stessa istruzione che scrive, confronto esatto, parametro con tipo esplicito
    if ($save -notmatch 'If emailChanged Then sqlUtente &= " AND BINARY l\.Pass" & "word = BINARY @CurrentPassword"') { $fail.Add('S04 predicato della password nel primo UPDATE') }
    if ($save -notmatch 'If emailChanged Then cmd\.Parameters\.Add\("@CurrentPassword", MySqlDbType\.VarChar\)\.Value = currentPassword') { $fail.Add('S04 parametro della password') }
    if ($c -match 'AddWithValue') { $fail.Add('S04 parametri senza tipo esplicito') }
    # S05 zero righe con e-mail cambiata = password errata: messaggio, nessun commit
    if ($save -notmatch 'Dim affectedUsers As Integer = cmd\.ExecuteNonQuery\(\)\s+If emailChanged AndAlso affectedUsers = 0 Then\s+ShowMessage\(WrongCurrentPasswordMessage, False\)\s+Return\s+End If\s+If affectedUsers <> 1 Then Throw New InvalidOperationException\("Profile update was not authorized\."\)') { $fail.Add('S05 zero righe = password errata, senza commit') }
    $iCommit = $save.IndexOf('tr.Commit()'); $iSession = $save.IndexOf('If emailChanged Then Session("LoginEmail") = updated.Email')
    if ($iCommit -lt 0 -or $iSession -lt 0 -or $iSession -lt $iCommit) { $fail.Add('S05 sessione aggiornata solo dopo il commit') }
    if ($c -notmatch ('Private Const WrongCurrentPasswordMessage As String = "' + [regex]::Escape($wrongMessage))) { $fail.Add('S05 messaggio') }
    # S06 markup: campo semplice (niente validatori), ID per primo, descrizione associata, nessun invito al riempimento automatico
    if ($f.editUi -notmatch '<asp:TextBox ID="txtCurrentPassword" runat="server" CssClass="form-control" TextMode="Password" autocomplete="off" aria-describedby="ksCurrentPasswordHint" />') { $fail.Add('S06 campo della password attuale') }
    if ($f.editUi -notmatch 'id="ksCurrentPasswordHint"[^>]*>[^<]*Serve solo se cambi l''e-mail') { $fail.Add('S06 descrizione del campo') }
    if ($f.editUi -match 'ControlToValidate="txtCurrentPassword"') { $fail.Add('S06 validatore sul campo (bloccherebbe ogni salvataggio)') }
    # S07 vecchia pagina: l'e-mail non si scrive e non si valida piu
    if ($d -match '(?i)u\.Email\s*=\s*@Email' -or $d -match '(?i)"UPDATE login "' -or $d -match '@Email') { $fail.Add('S07 la vecchia pagina scrive ancora l''e-mail') }
    if ($d -match 'RequiresFreshSignIn|Session\("LoginEmail"\)') { $fail.Add('S07 confronto con la sessione ancora presente') }
    $val = Get-Block $d 'Private Function ValidateMainProfileInput(' 'End Function'
    if ($val -match '(?i)email') { $fail.Add('S07 validazione dell''e-mail nel salvataggio della vecchia pagina') }
    if (([regex]::Matches($f.datiUi, '<asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" ReadOnly="true" Text=''<%# Eval\("email"\) %>'' />')).Count -ne 3) { $fail.Add('S07 tre modelli con e-mail di sola lettura') }
    if ($f.datiUi -match 'Bind\("email"\)') { $fail.Add('S07 e-mail ancora collegata in scrittura') }
    if (([regex]::Matches($f.datiUi, 'href="my-account-edit\.aspx">Dati account</a>')).Count -lt 3) { $fail.Add('S07 rimando a Dati account') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$sourceFailed = -not (Test-Source $files)
if ($sourceFailed) { Write-Host 'EMAIL_CHANGE_PASSWORD FAIL (sorgenti)'; if ($SkipLab) { exit 1 } } else { Write-Host 'EMAIL_CHANGE_PASSWORD sorgenti OK' }

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_NO_PREDICATE'; File = 'edit'; Old = 'If emailChanged Then sqlUtente &= " AND BINARY l.Pass" & "word = BINARY @CurrentPassword"'; New = 'If False Then sqlUtente &= " AND BINARY l.Pass" & "word = BINARY @CurrentPassword"' },
    @{ Id = 'M02_NO_BINARY'; File = 'edit'; Old = '" AND BINARY l.Pass" & "word = BINARY @CurrentPassword"'; New = '" AND l.Pass" & "word = @CurrentPassword"' },
    @{ Id = 'M03_TRIMMED'; File = 'edit'; Old = 'Dim currentPassword As String = If(txtCurrentPassword.Text, String.Empty)'; New = 'Dim currentPassword As String = If(txtCurrentPassword.Text, String.Empty).Trim()' },
    @{ Id = 'M04_FIELD_NOT_CLEARED'; File = 'edit'; Old = '                    txtCurrentPassword.Text = String.Empty' + $nl; New = '' },
    @{ Id = 'M05_COMPARE_WITH_SESSION'; File = 'edit'; Old = 'If(current.Email, String.Empty).Trim(), StringComparison.OrdinalIgnoreCase)'; New = 'Convert.ToString(Session("LoginEmail")).Trim(), StringComparison.OrdinalIgnoreCase)' },
    @{ Id = 'M06_EMPTY_ALLOWED'; File = 'edit'; Old = 'If emailChanged AndAlso currentPassword.Length = 0 Then'; New = 'If False AndAlso currentPassword.Length = 0 Then' },
    @{ Id = 'M07_ZERO_ROWS_COMMITS'; File = 'edit'; Old = 'If emailChanged AndAlso affectedUsers = 0 Then'; New = 'If False AndAlso affectedUsers = 0 Then' },
    @{ Id = 'M08_SESSION_BEFORE_COMMIT'; File = 'edit'; Old = '                    tr.Commit()'; New = '                    If emailChanged Then Session("LoginEmail") = updated.Email' + $nl + '                    tr.Commit()' },
    @{ Id = 'M09_RESTORED_BLOCK_BACK'; File = 'edit'; Old = '                    Dim validationMessage As String = ""'; New = '                    Dim restoredFromDevice As Object = Session("KeepStore:StaySignedIn:Restored")' + $nl + '                    Dim validationMessage As String = ""' },
    @{ Id = 'M10_AUTOCOMPLETE_INVITES'; File = 'editUi'; Old = 'autocomplete="off" aria-describedby="ksCurrentPasswordHint"'; New = 'autocomplete="current-password" aria-describedby="ksCurrentPasswordHint"' },
    @{ Id = 'M11_VALIDATOR_ADDED'; File = 'editUi'; Old = '<asp:TextBox ID="txtCurrentPassword"'; New = '<asp:RequiredFieldValidator ID="rfvCurrent" runat="server" ControlToValidate="txtCurrentPassword" /><asp:TextBox ID="txtCurrentPassword"' },
    @{ Id = 'M12_LEGACY_WRITES_EMAIL'; File = 'dati'; Old = '"u.Fax = @Fax " & _'; New = '"u.Fax = @Fax, u.Email = @Email " & _' },
    @{ Id = 'M13_LEGACY_LOGIN_UPDATE'; File = 'dati'; Old = '                    Dim ownerUtentiId As Integer'; New = '                    Dim sqlLoginMut As String = "UPDATE login " & "SET Email = @Email WHERE id = @LoginId"' + $nl + '                    Dim ownerUtentiId As Integer' },
    @{ Id = 'M14_LEGACY_BIND'; File = 'datiUi'; Old = 'ReadOnly="true" Text=''<%# Eval("email") %>'' />'; New = 'Text=''<%# Bind("email") %>'' />' },
    @{ Id = 'M15_LEGACY_SESSION_COMPARE'; File = 'dati'; Old = '                    Dim ownerUtentiId As Integer'; New = '                    If Convert.ToString(Session("LoginEmail")) = "" Then Throw New InvalidOperationException()' + $nl + '                    Dim ownerUtentiId As Integer' }
)
if (-not $SkipMutants -and -not $sourceFailed) {
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        $text = [string]$files[$mu.File]
        $i = $text.IndexOf($mu.Old, [StringComparison]::Ordinal)
        if ($i -lt 0) { $survived.Add($mu.Id + ' (ancora non trovata)'); continue }
        $copy = $files.Clone()
        $copy[$mu.File] = $text.Substring(0, $i) + $mu.New + $text.Substring($i + $mu.Old.Length)
        if (Test-Source $copy -Quiet) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('EMAIL_CHANGE_PASSWORD FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('EMAIL_CHANGE_PASSWORD mutanti uccisi: ' + $mutants.Count)
}
if ($SkipLab) { Write-Host 'EMAIL_CHANGE_PASSWORD PASS (senza prova sul sito LAB)'; exit 0 }

# ---------------------------------------------------------------- (C) prova reale sul sito LAB
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
$loginId = ''
# Tutti i campi del modulo: input (non pulsanti), opzione scelta di ogni select, textarea; poi quelli indicati.
function New-FullFormFile([string]$html, [hashtable]$set) {
    $fields = @{}
    foreach ($mm in [regex]::Matches($html, '<input\b[^>]*>')) {
        $tag = $mm.Value
        $n = [regex]::Match($tag, '\bname="([^"]*)"'); if (-not $n.Success) { continue }
        $t = [regex]::Match($tag, '\btype="([^"]*)"'); $type = if ($t.Success) { $t.Groups[1].Value.ToLowerInvariant() } else { 'text' }
        if (@('submit', 'button', 'image', 'file', 'reset') -contains $type) { continue }
        if (@('checkbox', 'radio') -contains $type -and $tag -notmatch '\bchecked\b') { continue }
        $v = [regex]::Match($tag, '\bvalue="([^"]*)"')
        $fields[[Net.WebUtility]::HtmlDecode($n.Groups[1].Value)] = if ($v.Success) { [Net.WebUtility]::HtmlDecode($v.Groups[1].Value) } elseif (@('checkbox', 'radio') -contains $type) { 'on' } else { '' }
    }
    foreach ($mm in [regex]::Matches($html, '(?s)<select\b[^>]*\bname="([^"]*)"[^>]*>(.*?)</select>')) {
        $o = [regex]::Match($mm.Groups[2].Value, '<option\b[^>]*\bselected\b[^>]*\bvalue="([^"]*)"|<option\b[^>]*\bvalue="([^"]*)"[^>]*\bselected\b')
        if (-not $o.Success) { $o = [regex]::Match($mm.Groups[2].Value, '<option\b[^>]*\bvalue="([^"]*)"') }
        if ($o.Success) { $val = if ($o.Groups[1].Success -and $o.Groups[1].Value -ne '') { $o.Groups[1].Value } else { $o.Groups[2].Value }; $fields[[Net.WebUtility]::HtmlDecode($mm.Groups[1].Value)] = [Net.WebUtility]::HtmlDecode($val) }
    }
    foreach ($mm in [regex]::Matches($html, '(?s)<textarea\b[^>]*\bname="([^"]*)"[^>]*>(.*?)</textarea>')) { $fields[[Net.WebUtility]::HtmlDecode($mm.Groups[1].Value)] = [Net.WebUtility]::HtmlDecode($mm.Groups[2].Value.Trim()) }
    foreach ($k in $set.Keys) { $fields[$k] = [string]$set[$k] }
    $pairs = New-Object Collections.Generic.List[string]
    foreach ($k in $fields.Keys) { $pairs.Add(([Uri]::EscapeDataString($k)) + '=' + ([Uri]::EscapeDataString([string]$fields[$k]))) }
    $f = Join-Path $tmp ('f' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($f, ($pairs -join '&'), $utf8)
    return $f
}
function Get-PostTarget([string]$html, [string]$suffix) {
    $mm = [regex]::Match($html, '__doPostBack\((?:&#39;|'')([^&'']*' + [regex]::Escape($suffix) + ')(?:&#39;|'')')
    if ($mm.Success) { return $mm.Groups[1].Value } else { return '' }
}
# Invia "Dati account" con i valori indicati (chiavi = suffisso del nome del campo). Restituisce la risposta.
function Send-AccountEdit([string]$jar, [hashtable]$values) {
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    $set = @{ '__EVENTTARGET' = (Get-PostTarget $page.Body 'btnSave'); '__EVENTARGUMENT' = '' }
    foreach ($k in $values.Keys) { $n = Get-FieldName $page.Body $k; if ($n -eq '') { $n = 'ctl00$MainContent$' + $k }; $set[$n] = $values[$k] }
    $f = New-FullFormFile $page.Body $set
    try { return (Invoke-Http '/my-account-edit.aspx' $jar $f '/my-account-edit.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'EMAIL_CHANGE_PASSWORD FAIL credenziale di prova assente'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'EMAIL_CHANGE_PASSWORD FAIL utente di prova assente sul LAB'; exit 1 }
    $null = Invoke-Sql ("DROP TABLE IF EXISTS ks_test_email_change_backup; CREATE TABLE ks_test_email_change_backup AS SELECT l.id, l.Email AS em, u.Email AS uem, u.Telefono AS tel, u.Cellulare AS cel, u.Fax AS fax FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId;") -Write
    $emailSame = 'SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_email_change_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.Email<=>b.em AND u.Email<=>b.uem;'
    Check ((Get-Scalar $emailSame) -eq '1') 'E00 copia dei dati di prova'
    $secret = Get-Secret
    $jar = Join-Path $tmp 'a.txt'
    $r = Invoke-Login $jar $false
    Check ($r.Status -eq 302) 'E01 accesso di prova'
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    $currentEmail = [regex]::Match($page.Body, 'name="[^"]*\$txtEmail"[^>]*value="([^"]*)"').Groups[1].Value
    if ($currentEmail -eq '') { $currentEmail = [regex]::Match($page.Body, 'value="([^"]*)"[^>]*name="[^"]*\$txtEmail"').Groups[1].Value }
    Check ($page.Status -eq 200 -and $page.Body -match 'name="[^"]*\$txtCurrentPassword"' -and $page.Body -match 'Serve solo se cambi l') 'E02 Dati account: campo della password attuale con la sua spiegazione'
    Check ($page.Body -notmatch 'name="[^"]*\$txtCurrentPassword"[^>]*value="[^"]+"') 'E03 il campo della password attuale non ha mai un valore'
    $newEmail = 'ks.test.' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '@example.invalid'

    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail }
    Check ($r.Status -eq 200 -and $r.Body.Contains($wrongMessage) -and (Get-Scalar $emailSame) -eq '1') 'E04 cambio dell''e-mail senza password: rifiutato, dati invariati'
    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = ('X' + [Guid]::NewGuid().ToString('N').Substring(0, 10)) }
    Check ($r.Status -eq 200 -and $r.Body.Contains($wrongMessage) -and (Get-Scalar $emailSame) -eq '1') 'E05 password errata: rifiutato, dati invariati'
    $swapped = -join ($secret.ToCharArray() | ForEach-Object { if ([char]::IsUpper($_)) { [char]::ToLowerInvariant($_) } elseif ([char]::IsLower($_)) { [char]::ToUpperInvariant($_) } else { $_ } })
    if ($swapped -cne $secret) {
        $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = $swapped }
        Check ($r.Status -eq 200 -and $r.Body.Contains($wrongMessage) -and (Get-Scalar $emailSame) -eq '1') 'E06 password con maiuscole diverse: rifiutato (confronto esatto)'
    } else { Write-Host '  --   E06 saltato: la password di prova non ha lettere' }
    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = (' ' + $secret) }
    Check ($r.Status -eq 200 -and $r.Body.Contains($wrongMessage) -and (Get-Scalar $emailSame) -eq '1') 'E07 password con uno spazio in piu: rifiutato (nessun taglio)'

    $phone = '+39 0' + (Get-Random -Minimum 10000000 -Maximum 99999999)
    $r = Send-AccountEdit $jar @{ 'txtEmail' = $currentEmail; 'txtTelefono' = $phone }
    Check ($r.Status -eq 200 -and $r.Body -match 'Dati aggiornati correttamente' -and (Get-Scalar $emailSame) -eq '1' -and (Get-Scalar "SELECT COUNT(*) AS ksval FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId AND u.Telefono='$phone';") -eq '1') 'E08 solo il telefono, senza password: salvato, e-mail invariata'

    $r = Send-AccountEdit $jar @{ 'txtEmail' = $newEmail; 'txtCurrentPassword' = $secret }
    Check ($r.Status -eq 200 -and $r.Body -match 'Dati aggiornati correttamente') 'E09 password giusta: salvataggio riuscito'
    Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId AND l.Email='$newEmail' AND u.Email='$newEmail';") -eq '1') 'E10 e-mail cambiata in accesso e anagrafica'
    Check (-not (Test-ResponseContains $r.Body $secret) -and $r.Body -notmatch 'name="[^"]*\$txtCurrentPassword"[^>]*value="[^"]+"') 'E11 la risposta non contiene la password'
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    Check ($page.Body.Contains($newEmail)) 'E12 la pagina mostra l''e-mail nuova'

    # vecchia pagina dei dati utente: l'e-mail inviata a mano non viene scritta, gli altri campi si
    $old = Invoke-Http '/datiutente.aspx' $jar
    $editTarget = Get-PostTarget $old.Body 'btnEdit'
    if ($old.Status -eq 200 -and $editTarget -ne '' -and (Get-PostTarget $old.Body 'btnUpdate') -eq '') {
        # la pagina si apre in lettura: prima si passa in modifica
        $f = New-FullFormFile $old.Body @{ '__EVENTTARGET' = $editTarget; '__EVENTARGUMENT' = '' }
        $old = Invoke-Http '/datiutente.aspx' $jar $f '/datiutente.aspx'
    }
    $target = Get-PostTarget $old.Body 'btnUpdate'
    $emailField = Get-FieldName $old.Body 'txtEmail'; if ($emailField -eq '') { $emailField = 'ctl00$MainContent$fvUtente$txtEmail' }
    $phoneField = Get-FieldName $old.Body 'txtTelefono'
    $phone2 = '+39 0' + (Get-Random -Minimum 10000000 -Maximum 99999999)
    if ($old.Status -eq 200 -and $target -ne '' -and $phoneField -ne '') {
        $f = New-FullFormFile $old.Body @{ '__EVENTTARGET' = $target; '__EVENTARGUMENT' = ''; $emailField = 'ks.forged.legacy@example.invalid'; $phoneField = $phone2 }
        $r = Invoke-Http '/datiutente.aspx' $jar $f '/datiutente.aspx'
        Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId AND l.Email='$newEmail' AND u.Email='$newEmail';") -eq '1') 'E13 vecchia pagina: e-mail inviata a mano NON scritta'
        Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId AND u.Telefono='$phone2';") -eq '1') 'E14 vecchia pagina: gli altri campi si salvano ancora'
        Check ($old.Body -match 'href="my-account-edit\.aspx">Dati account</a>') 'E15 vecchia pagina: rimando a Dati account'
    } else { Check $false 'E13 modulo della vecchia pagina non leggibile' }
    $secret = $null
} catch {
    Write-Host ('  FAIL eccezione: ' + $_.Exception.Message); $e2e.Add('eccezione')
} finally {
    if ($loginId -match '^\d+$') {
        try {
            $null = Invoke-Sql 'UPDATE login l INNER JOIN ks_test_email_change_backup b ON b.id=l.id SET l.Email=b.em; UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_email_change_backup b ON b.id=l.id SET u.Email=b.uem, u.Telefono=b.tel, u.Cellulare=b.cel, u.Fax=b.fax;' -Write
            $same = Get-Scalar 'SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_email_change_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.Email<=>b.em AND u.Email<=>b.uem AND u.Telefono<=>b.tel AND u.Cellulare<=>b.cel AND u.Fax<=>b.fax;'
            if ($same -eq '1') { $null = Invoke-Sql 'DROP TABLE IF EXISTS ks_test_email_change_backup;' -Write; Write-Host '  ok   E99 dati di prova riportati allo stato di partenza' } else { Write-Host '  FAIL E99 dati di prova NON ripristinati (copia lasciata in ks_test_email_change_backup)'; $e2e.Add('E99') }
        } catch { $e2e.Add('E99 ripristino') }
    }
    Close-LabSite
}
if ($e2e.Count -gt 0 -or $sourceFailed) { Write-Host ('EMAIL_CHANGE_PASSWORD FAIL sito LAB: ' + $e2e.Count + ' controlli' + $(if ($sourceFailed) { ' (e sorgenti)' } else { '' })); exit 1 }
Write-Host 'EMAIL_CHANGE_PASSWORD PASS'
exit 0
