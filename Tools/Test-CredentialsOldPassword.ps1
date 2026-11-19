[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# AUTH-CREDENTIALS-OLD-PASSWORD-1A. La pagina registrazione.aspx, per un cliente gia collegato, scriveva la password attuale nel sorgente
# (campo e ViewState) e cambiava nome utente, password ed e-mail senza chiedere la password attuale. Ora: mai la password verso il browser;
# da collegati il riquadro "DATI ACCESSO" e di sola lettura e rimanda a password.aspx (che chiede la password attuale) e a "Dati account";
# la pagina non scrive piu nome utente, password o e-mail. La registrazione di un cliente nuovo non cambia.
# (A) sorgenti, (B) mutazioni, (C) prova reale sul SITO LAB (https, 127.0.0.1, porta 18843, database LAB). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    page = Read-Repo 'registrazione.aspx'
    code = Read-Repo 'registrazione.aspx.vb'
}

function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $c = $f.code; $p = $f.page
    # S01 la password non viene mai messa in un attributo del campo
    if ($c -match '(?i)\.Attributes\(\s*"value"\s*\)\s*=') { $fail.Add('S01 valore scritto in un attributo del campo') }
    if ($c -match '(?i)(tbPassword|tbPasswordConferma|Password|PasswordConferma)\.Text\s*=\s*dr\.Item') { $fail.Add('S01 password del database copiata nel campo') }
    # S02 prima del rendering l'attributo viene tolto comunque (pagine aperte prima del rilascio lo hanno nel ViewState)
    if ($c -notmatch 'Me\.tbPassword\.Attributes\.Remove\("value"\)\s+Me\.tbPasswordConferma\.Attributes\.Remove\("value"\)') { $fail.Add('S02 attributo non tolto prima del rendering') }
    $pre = Get-Block $c 'Protected Sub Page_PreRender(' 'End Sub'
    if ($pre -notmatch 'ApplySignedInAccessPanel\(\)') { $fail.Add('S02 il riquadro non viene sistemato a ogni rendering') }
    # S03 il gestore del riquadro non scrive piu nulla
    $click = Get-Block $c 'Protected Sub imgModAccesso_Click(' 'End Sub'
    if ($click -eq '') { $fail.Add('S03 gestore assente') }
    if ($click -match '(?i)UPDATE|ExecuteNonQuery|ExecuteScalar|conn\.Open|enable_mod_panel|enable_Accesso\(True\)') { $fail.Add('S03 il gestore del riquadro scrive o riapre la modifica') }
    if ($c -match '(?i)UPDATE\s+LOGIN\s+SET\s*"\s*\r?\n[^\r\n]*username') { $fail.Add('S03 scrittura del nome utente ancora presente') }
    if ($c -match '(?i)"\s*password\s*=\s*\?password') { $fail.Add('S03 scrittura della password ancora presente') }
    if ($c -match 'Case Panel\.Accesso\s+BindLstDestinazione\(\)\s+enable_Accesso\(True\)') { $fail.Add('S03 il riquadro si puo ancora aprire in modifica') }
    # S07 il pulsante di registrazione, per chi e gia collegato, non aggiorna nulla (prima riscriveva anche l'e-mail)
    if ($c -match '(?<!Sub )AggiornaDati\(\)') { $fail.Add('S07 REGISTRATI da collegati aggiorna ancora i dati') }
    if ($c -notmatch 'If Not Me\.Session\("LoginId"\) Is Nothing Then\s+''[^\r\n]*\s+''[^\r\n]*\s+Else\s+''Caso di Registrazione\s+Registrazione\(\)') { $fail.Add('S07 ramo della registrazione nuova cambiato') }
    # S04 da collegati: pulsante spento, righe della password nascoste, collegamenti accesi; da anonimi il contrario
    $apply = Get-Block $c 'Private Sub ApplySignedInAccessPanel(' 'End Sub'
    foreach ($need in 'Me.imgModAccesso.Visible = False', 'Me.rowAccessoPassword.Visible = Not signedIn', 'Me.rowAccessoPasswordConferma.Visible = Not signedIn', 'Me.rowAccessoEmailConferma.Visible = Not signedIn', 'Me.rowAccessoLinks.Visible = signedIn') {
        if (-not $apply.Contains($need)) { $fail.Add('S04 riquadro: manca ' + $need) }
    }
    if ($apply -notmatch 'If signedIn Then\s+Me\.tbUsername\.Enabled = False\s+Me\.tbEmail\.Enabled = False') { $fail.Add('S04 nome utente ed e-mail di sola lettura da collegati') }
    if ($c -match 'Me\.imgModAccesso\.Visible = True') { $fail.Add('S04 pulsante di modifica ancora acceso') }
    # S05 markup: righe governate dal server e collegamenti alle pagine giuste
    foreach ($id in 'rowAccessoPassword', 'rowAccessoPasswordConferma', 'rowAccessoEmailConferma', 'rowAccessoLinks') {
        if ($p -notmatch ('<tr id="' + $id + '" runat="server"')) { $fail.Add('S05 riga non governata dal server: ' + $id) }
    }
    $links = Get-Block $p '<tr id="rowAccessoLinks" runat="server"' '</tr>'
    if ($links -notmatch 'href="password\.aspx"' -or $links -notmatch 'href="my-account-edit\.aspx"' -or $links -notmatch 'Visible="false"|visible="false"') { $fail.Add('S05 collegamenti a cambio password e dati account, spenti per default') }
    # S06 la registrazione di un cliente nuovo non cambia: campi e validatori al loro posto
    foreach ($need in 'ID="tbPassword" runat="server"', 'ID="tbPasswordConferma" runat="server"', 'ID="RequiredFieldValidator2"', 'ID="RequiredFieldValidator3"', 'ID="tbEmailConferma" runat="server"', 'ID="btRegistrati"') {
        if (-not $p.Contains($need)) { $fail.Add('S06 registrazione nuova: manca ' + $need) }
    }
    if ($c -notmatch 'cmd\.Parameters\.AddWithValue\("\?parPassword", Me\.tbPassword\.Text\.ToString\.Trim\)') { $fail.Add('S06 inserimento del cliente nuovo cambiato') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not (Test-Source $files)) {
    Write-Host 'CREDENTIALS_OLD_PASSWORD FAIL (sorgenti)'
    if ($SkipLab) { exit 1 }
    $sourceFailed = $true
} else { Write-Host 'CREDENTIALS_OLD_PASSWORD sorgenti OK'; $sourceFailed = $false }

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_VALUE_ATTRIBUTE_BACK'; File = 'code'; Old = '                Email.Text = dr.Item("email").ToString'; New = '                Password.Attributes("value") = dr.Item("password").ToString' + $nl + '                Email.Text = dr.Item("email").ToString' },
    @{ Id = 'M02_NO_REMOVE_PASSWORD'; File = 'code'; Old = '        Me.tbPassword.Attributes.Remove("value")' + $nl; New = '' },
    @{ Id = 'M03_NO_REMOVE_CONFIRM'; File = 'code'; Old = '        Me.tbPasswordConferma.Attributes.Remove("value")' + $nl; New = '' },
    @{ Id = 'M04_PANEL_NOT_APPLIED'; File = 'code'; Old = '        ApplySignedInAccessPanel()' + $nl; New = '' },
    @{ Id = 'M05_BUTTON_VISIBLE'; File = 'code'; Old = 'Me.imgModAccesso.Visible = False' + $nl + '        Me.rowAccessoPassword'; New = 'Me.imgModAccesso.Visible = signedIn' + $nl + '        Me.rowAccessoPassword' },
    @{ Id = 'M06_PASSWORD_ROW_VISIBLE'; File = 'code'; Old = 'Me.rowAccessoPassword.Visible = Not signedIn'; New = 'Me.rowAccessoPassword.Visible = True' },
    @{ Id = 'M07_CONFIRM_ROW_VISIBLE'; File = 'code'; Old = 'Me.rowAccessoPasswordConferma.Visible = Not signedIn'; New = 'Me.rowAccessoPasswordConferma.Visible = True' },
    @{ Id = 'M08_LINKS_HIDDEN'; File = 'code'; Old = 'Me.rowAccessoLinks.Visible = signedIn'; New = 'Me.rowAccessoLinks.Visible = False' },
    @{ Id = 'M09_EMAIL_EDITABLE'; File = 'code'; Old = '            Me.tbEmail.Enabled = False' + $nl; New = '' },
    @{ Id = 'M10_HANDLER_REOPENS'; File = 'code'; Old = "        ' Il riquadro dei dati di accesso e di sola lettura"; New = "        enable_mod_panel(Panel.Accesso)" + $nl + "        ' Il riquadro dei dati di accesso e di sola lettura" },
    @{ Id = 'M11_HANDLER_WRITES'; File = 'code'; Old = "        ' Il riquadro dei dati di accesso e di sola lettura"; New = '        cmd.CommandText = " UPDATE LOGIN SET Email = ?email WHERE ID=?LoginID" : cmd.ExecuteNonQuery()' + $nl + "        ' Il riquadro dei dati di accesso e di sola lettura" },
    @{ Id = 'M12_PANEL_CASE_BACK'; File = 'code'; Old = '			Case Panel.Accesso' + $nl + '				BindLstDestinazione()' + $nl; New = '			Case Panel.Accesso' + $nl + '				BindLstDestinazione()' + $nl + '				enable_Accesso(True)' + $nl },
    @{ Id = 'M16_REGISTER_BUTTON_UPDATES'; File = 'code'; Old = "				Else" + $nl + "				" + $nl + "					'Caso di Registrazione"; New = "					AggiornaDati()" + $nl + "				Else" + $nl + "				" + $nl + "					'Caso di Registrazione" },
    @{ Id = 'M13_LINK_WRONG_PAGE'; File = 'page'; Old = 'href="password.aspx"'; New = 'href="registrazione.aspx"' },
    @{ Id = 'M14_ROW_NOT_SERVER'; File = 'page'; Old = '<tr id="rowAccessoPassword" runat="server"'; New = '<tr id="rowAccessoPassword"' },
    @{ Id = 'M15_LINKS_ON_BY_DEFAULT'; File = 'page'; Old = '<tr id="rowAccessoLinks" runat="server" visible="false"'; New = '<tr id="rowAccessoLinks" runat="server"' }
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
    if ($survived.Count -gt 0) { Write-Host ('CREDENTIALS_OLD_PASSWORD FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('CREDENTIALS_OLD_PASSWORD mutanti uccisi: ' + $mutants.Count)
}
if ($SkipLab) { Write-Host 'CREDENTIALS_OLD_PASSWORD PASS (senza prova sul sito LAB)'; exit 0 }

# ---------------------------------------------------------------- (C) prova reale sul sito LAB
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
$loginId = ''
function Get-PasswordFieldStats([string]$html) {
    $n = 0; $filled = 0
    foreach ($t in [regex]::Matches($html, '<input\b[^>]*type="password"[^>]*>')) { $n++; $v = [regex]::Match($t.Value, '\bvalue="([^"]*)"'); if ($v.Success -and $v.Groups[1].Value.Length -gt 0) { $filled++ } }
    return [pscustomobject]@{ Count = $n; Filled = $filled }
}
try {
    if (-not (Test-Path -LiteralPath $secretFile)) { Write-Host 'CREDENTIALS_OLD_PASSWORD FAIL credenziale di prova assente'; exit 1 }
    $loginId = Get-Scalar ("SELECT DISTINCT id AS ksval FROM vlogin WHERE AziendeId=1 AND UPPER(UserName)='" + $testUser + "' AND Abilitato=1 AND UtentiAbilitato=1;")
    if ($loginId -notmatch '^\d+$') { Write-Host 'CREDENTIALS_OLD_PASSWORD FAIL utente di prova assente sul LAB'; exit 1 }
    $null = Invoke-Sql ("DROP TABLE IF EXISTS ks_test_credentials_backup; CREATE TABLE ks_test_credentials_backup AS SELECT l.id, l.UserName AS un, l.$col AS w, l.DataPassword AS d, l.Email AS em, u.Email AS uem FROM login l INNER JOIN utenti u ON u.id=l.UtentiId WHERE l.id=$loginId;") -Write
    $unchanged = "SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_credentials_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE BINARY l.UserName<=>BINARY b.un AND BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d AND l.Email<=>b.em AND u.Email<=>b.uem;"
    Check ((Get-Scalar $unchanged) -eq '1') 'E00 copia dei dati di prova'
    $secret = Get-Secret

    # da anonimi: la registrazione di un cliente nuovo ha ancora i campi della password, vuoti
    $jarAnon = Join-Path $tmp 'anon.txt'
    $r = Invoke-Http '/registrazione.aspx' $jarAnon
    $st = Get-PasswordFieldStats $r.Body
    Check ($r.Status -eq 200 -and $st.Count -eq 2 -and $st.Filled -eq 0 -and $r.Body -match 'btRegistrati' -and $r.Body -match 'tbEmailConferma') 'E01 anonimo: registrazione con due campi password vuoti e pulsante REGISTRATI'
    Check ($r.Body -notmatch 'href="password\.aspx"[^>]*>\s*Cambia password') 'E02 anonimo: nessun collegamento riservato ai collegati'

    # da collegati: mai la password verso il browser
    $jar = Join-Path $tmp 'a.txt'
    $r = Invoke-Login $jar $false
    Check ($r.Status -eq 302) 'E03 accesso di prova'
    $page = Invoke-Http '/registrazione.aspx' $jar
    $st = Get-PasswordFieldStats $page.Body
    Check ($page.Status -eq 200 -and $st.Filled -eq 0) 'E04 collegato: nessun campo password con un valore nel sorgente'
    Check (-not (Test-ResponseContains $page.Body $secret)) 'E05 collegato: la password non compare nella pagina ne nel ViewState'
    Check ($st.Count -eq 0) 'E06 collegato: i campi della password non sono nella pagina'
    Check ($page.Body -match 'href="password\.aspx"' -and $page.Body -match 'href="my-account-edit\.aspx"') 'E07 collegato: collegamenti a cambio password e dati account'
    Check ($page.Body -notmatch 'name="[^"]*\$imgModAccesso"') 'E08 collegato: nessun pulsante di modifica dei dati di accesso'

    # un altro riquadro aperto in modifica: la password continua a non arrivare
    $prefix = (Get-FieldName $page.Body 'tbEmail'); if ($prefix -ne '') { $prefix = $prefix.Substring(0, $prefix.Length - 'tbEmail'.Length) } else { $prefix = 'ctl00$MainContent$' }
    $f = New-FormFile $page.Body @{ ($prefix + 'imgModIndirizzoP') = 'MODIFICA' }
    $r2 = Invoke-Http '/registrazione.aspx' $jar $f '/registrazione.aspx'
    $st2 = Get-PasswordFieldStats $r2.Body
    Check ($r2.Status -eq 200 -and $st2.Filled -eq 0 -and -not (Test-ResponseContains $r2.Body $secret)) 'E09 collegato, altro riquadro in modifica: password assente da pagina e ViewState'

    # richieste costruite a mano: MODIFICA e poi SALVA dei dati di accesso con valori nuovi
    $forged = @{ ($prefix + 'imgModAccesso') = 'MODIFICA' }
    $f = New-FormFile $page.Body $forged
    $r3 = Invoke-Http '/registrazione.aspx' $jar $f '/registrazione.aspx'
    $newWord = 'Kx' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $basis = if ($r3.Status -eq 200 -and $r3.Body -match '__VIEWSTATE') { $r3.Body } else { $page.Body }
    $forged = @{ ($prefix + 'imgModAccesso') = 'SALVA'; ($prefix + 'tbUsername') = 'ksforgeduser1'; ($prefix + 'tbPassword') = $newWord; ($prefix + 'tbPasswordConferma') = $newWord; ($prefix + 'tbEmail') = 'ks.forged@example.invalid'; ($prefix + 'tbEmailConferma') = 'ks.forged@example.invalid' }
    $f = New-FormFile $basis $forged
    $r4 = Invoke-Http '/registrazione.aspx' $jar $f '/registrazione.aspx'
    Check ((Get-Scalar $unchanged) -eq '1') 'E10 richiesta costruita a mano: nome utente, password ed e-mail invariati nel database'
    Check (-not (Test-ResponseContains $r4.Body $secret) -and -not (Test-ResponseContains $r3.Body $secret)) 'E11 risposte alle richieste costruite a mano: password assente'
    $f = New-FormFile $page.Body $forged
    $null = Invoke-Http '/registrazione.aspx' $jar $f '/registrazione.aspx'
    Check ((Get-Scalar $unchanged) -eq '1') 'E12 SALVA diretto senza MODIFICA: dati invariati'
    # pulsante REGISTRATI inviato a mano da un cliente collegato, con un'e-mail nuova
    $f = New-FormFile $page.Body @{ ($prefix + 'btRegistrati') = 'REGISTRATI'; ($prefix + 'tbEmail') = 'ks.forged2@example.invalid'; ($prefix + 'tbEmailConferma') = 'ks.forged2@example.invalid' }
    $null = Invoke-Http '/registrazione.aspx' $jar $f '/registrazione.aspx'
    Check ((Get-Scalar $unchanged) -eq '1') 'E13 REGISTRATI inviato a mano da collegato: e-mail invariata'
    $secret = $null
} catch {
    Write-Host ('  FAIL eccezione: ' + $_.Exception.Message); $e2e.Add('eccezione')
} finally {
    if ($loginId -match '^\d+$') {
        try {
            $null = Invoke-Sql ("UPDATE login l INNER JOIN ks_test_credentials_backup b ON b.id=l.id SET l.UserName=b.un, l.$col" + "=b.w, l.DataPassword=b.d, l.Email=b.em; UPDATE utenti u INNER JOIN login l ON l.UtentiId=u.id INNER JOIN ks_test_credentials_backup b ON b.id=l.id SET u.Email=b.uem;") -Write
            $same = Get-Scalar ("SELECT COUNT(*) AS ksval FROM login l INNER JOIN ks_test_credentials_backup b ON b.id=l.id INNER JOIN utenti u ON u.id=l.UtentiId WHERE BINARY l.UserName<=>BINARY b.un AND BINARY l.$col<=>BINARY b.w AND l.DataPassword<=>b.d AND l.Email<=>b.em AND u.Email<=>b.uem;")
            if ($same -eq '1') { $null = Invoke-Sql 'DROP TABLE IF EXISTS ks_test_credentials_backup;' -Write; Write-Host '  ok   E99 dati di prova riportati allo stato di partenza' } else { Write-Host '  FAIL E99 dati di prova NON ripristinati (copia lasciata in ks_test_credentials_backup)'; $e2e.Add('E99') }
        } catch { $e2e.Add('E99 ripristino') }
    }
    Close-LabSite
}
if ($e2e.Count -gt 0 -or $sourceFailed) { Write-Host ('CREDENTIALS_OLD_PASSWORD FAIL sito LAB: ' + $e2e.Count + ' controlli' + $(if ($sourceFailed) { ' (e sorgenti)' } else { '' })); exit 1 }
Write-Host 'CREDENTIALS_OLD_PASSWORD PASS'
exit 0
