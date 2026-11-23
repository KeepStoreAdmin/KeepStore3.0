[CmdletBinding()]
param([switch]$SkipLab)

# AUTH-STAY-SIGNED-IN-2A, fase 1. Servizio di "Resta collegato" (App_Code/KeepStoreStaySignedIn.vb) e tabella login_remembered_devices
# (docs/STAY_SIGNED_IN_DEVICES_TABLE.md), SENZA chiamanti: il sito non cambia comportamento.
# (A) comportamento del modulo compilato (formato del cookie, impronte, decisione), (B) sorgenti (inerte, nessun chiamante, nessun segreto nei
# registri, script della pagina docs), (C) mutazioni, (D) LAB locale: servizio reale su tabella creata dallo script della pagina docs, piu
# mutazioni del livello dati. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    module = Read-Repo 'App_Code/KeepStoreStaySignedIn.vb'
    doc    = Read-Repo 'docs/STAY_SIGNED_IN_DEVICES_TABLE.md'
}

function Get-Ddl([string]$doc) {
    $m = [regex]::Match($doc, 'CREATE TABLE IF NOT EXISTS login_remembered_devices \([\s\S]*?\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;')
    if ($m.Success) { return $m.Value } else { return '' }
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $m = $f.module; $d = $f.doc
    if ($m -eq '') { $fail.Add('B0 modulo assente') }
    else {
        # B1 chiamanti: solo quelli previsti dalla fase 2 (AUTH-STAY-SIGNED-IN-2B, Tools/Test-StaySignedInPages.ps1)
        $expectedCallers = @('KeepStoreStaySignedInWeb.vb', 'Page.master.vb', 'login.aspx.vb', 'logout.aspx.vb', 'password.aspx.vb', 'registrazione.aspx.vb', 'my-account-edit.aspx.vb', 'datiutente.aspx.vb', 'privacy.aspx', 'KeepStoreSignInSessionRenew.vb')
        $callers = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { @('.vb', '.aspx', '.ascx', '.master', '.asax') -contains $_.Extension.ToLowerInvariant() } |
            Where-Object { $_.FullName -notmatch '\\(\.claude|\.ai-review|\.git|Tools|obj|Bin|Public|App_Data|Database Taikun)\\' -and $_.Name -ne 'KeepStoreStaySignedIn.vb' } |
            Where-Object { (Select-String -LiteralPath $_.FullName -Pattern 'KeepStoreStaySignedIn|StaySignedInOutcome|__Host-KeepStoreStay' -SimpleMatch:$false -Quiet) })
        $unexpected = @($callers | Where-Object { $expectedCallers -notcontains $_.Name })
        if ($unexpected.Count -gt 0) { $fail.Add('B1 chiamanti non previsti: ' + (($unexpected | ForEach-Object { $_.Name }) -join ', ')) }
        # B2 modulo autonomo e silenzioso
        if ($m -match 'HttpContext|Session\(|ConfigurationManager|Response\.|Request\.') { $fail.Add('B2 modulo non autonomo') }
        if ($m -match 'KeepStoreLog|Trace\.|Console\.|Debug\.') { $fail.Add('B2 il modulo scrive registri') }
        if ($m -match '(?i)\bMD5\b|\bSHA1\b|DESCrypto|RijndaelManaged|New Random\(') { $fail.Add('B2 primitive non ammesse') }
        if ($m -notmatch 'Using generator As New RNGCryptoServiceProvider\(\)') { $fail.Add('B2 codice non casuale crittografico') }
        # B3 il tempo e quello del database
        if ($m -match 'DateTime\.(Now|UtcNow)' -and ([regex]::Matches($m, 'DateTime\.UtcNow')).Count -ne 4) { $fail.Add('B3 orologio del sito usato fuori dalla sospensione e dalla sonda della tabella') }
        if ($m -match 'DateTime\.Now') { $fail.Add('B3 ora locale') }
        if ($m -notmatch 'ExpiresUtc > UTC_TIMESTAMP\(\)' -or $m -notmatch 'UTC_TIMESTAMP\(\) \+ INTERVAL \?giorni DAY') { $fail.Add('B3 scadenza non calcolata dal database') }
        # B4 mai il codice in chiaro nel database, sempre parametri
        if ($m -match '(?i)(INSERT|UPDATE|SELECT|DELETE)[^"]*" *& *(cookieValue|secret|account\.StoredSecret)') { $fail.Add('B4 valori concatenati nello SQL') }
        if ($m -notmatch '"VALUES \(\?loginId, \?aziendaId, \?hash, \?stamp, UTC_TIMESTAMP\(\), UTC_TIMESTAMP\(\), UTC_TIMESTAMP\(\) \+ INTERVAL \?giorni DAY\)"') { $fail.Add('B4 inserimento') }
        # B5 ogni operazione sul database e protetta: errore = sospensione, mai eccezione
        if (([regex]::Matches($m, '(?m)^        Catch\r?\n            Suspend\(\)')).Count -ne 5) { $fail.Add('B5 le cinque operazioni devono sospendere su errore') }
        if ($m -notmatch 'Public Const LifetimeDays As Integer = 30' -or $m -notmatch 'Public Const RenewAfterHours As Integer = 24' -or $m -notmatch 'Public Const MaxDevicesPerLogin As Integer = 10') { $fail.Add('B5 costanti della decisione del PO') }
        if ($m -notmatch 'Public Const CookieName As String = "__Host-KeepStoreStay"') { $fail.Add('B5 nome del cookie') }
    }
    # B6 pagina docs: script completo, nomi ASCII, stesso nome di tabella del modulo
    $ddl = Get-Ddl $d
    if ($ddl -eq '') { $fail.Add('B6 script di creazione assente nella pagina docs') }
    else {
        if ($ddl -match '[^\x20-\x7E\r\n]') { $fail.Add('B6 caratteri non ASCII nello script') }
        foreach ($need in 'TokenHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL', 'CredentialStamp CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL', 'UNIQUE KEY uq_login_remembered_devices_tokenhash (TokenHash)', 'KEY idx_login_remembered_devices_login (LoginId, RevokedUtc)', 'KEY idx_login_remembered_devices_expires (ExpiresUtc)', 'PRIMARY KEY (id)') {
            if (-not $ddl.Contains($need)) { $fail.Add('B6 script senza: ' + $need) }
        }
        if ($ddl -match '(?i)FOREIGN KEY|DEFINER|\bUSE\b') { $fail.Add('B6 script con chiavi esterne, DEFINER o USE') }
    }
    if ($d -notmatch 'DROP TABLE IF EXISTS login_remembered_devices;' -or $d -notmatch 'NON applicato a nessun database reale') { $fail.Add('B6 pagina docs senza ritorno indietro o stato') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Collections.Generic
Imports System.Text
Public Module StaySignedInProbe
    Private sb As New StringBuilder()
    Private Sub T(ByVal name As String, ByVal ok As Boolean)
        If sb.Length > 0 Then sb.Append(";")
        sb.Append(name).Append("=").Append(ok.ToString())
    End Sub
    Private Function Acc(Optional ByVal login As Integer = 7, Optional ByVal user As Integer = 70, Optional ByVal company As Integer = 1, Optional ByVal name As String = "Mario", Optional ByVal word As String = "Segreta1", Optional ByVal wordDate As String = "2026-01-02 00:00:00", Optional ByVal enabled As Boolean = True) As StaySignedInAccount
        Dim created As New StaySignedInAccount() With {.LoginId = login, .UtentiId = user, .AziendeId = company, .UserName = name, .PasswordDate = wordDate, .Enabled = enabled}
        created.GetType().GetProperty("StoredSecret").SetValue(created, word, Nothing)
        Return created
    End Function
    Private Function Row(Optional ByVal stamp As String = "S", Optional ByVal revoked As Boolean = False, Optional ByVal notExpired As Boolean = True, Optional ByVal login As Integer = 7, Optional ByVal company As Integer = 1) As StaySignedInRow
        Return New StaySignedInRow() With {.Found = True, .Id = 1, .LoginId = login, .AziendeId = company, .CredentialStamp = stamp, .Revoked = revoked, .NotExpired = notExpired}
    End Function
    Private Function D(ByVal row As StaySignedInRow, ByVal account As StaySignedInAccount, ByVal company As Integer, ByVal stamp As String, ByVal expected As StaySignedInOutcome, ByVal expectedReason As String) As Boolean
        Dim reason As String = "x"
        Return KeepStoreStaySignedIn.Decide(row, account, company, stamp, reason) = expected AndAlso reason = expectedReason
    End Function
    Private Function Bad(ByVal value As String) As Boolean
        Dim s As Byte() = New Byte() {1}
        Return Not KeepStoreStaySignedIn.TryParseCookieValue(value, s) AndAlso s Is Nothing
    End Function
    Public Function Run() As String
        Dim k(31) As Byte
        For i As Integer = 0 To 31
            k(i) = CByte(i * 7 + 3)
        Next
        Dim k2 As Byte() = CType(k.Clone(), Byte())
        k2(31) = CByte(k2(31) Xor 1)
        ' Cookie
        Dim a As Byte() = KeepStoreStaySignedIn.CreateSecret(), b As Byte() = KeepStoreStaySignedIn.CreateSecret()
        T("C01_codice_32_byte_casuale", a.Length = 32 AndAlso b.Length = 32 AndAlso Convert.ToBase64String(a) <> Convert.ToBase64String(b))
        Dim v As String = KeepStoreStaySignedIn.FormatCookieValue(k)
        Dim parsed As Byte() = Nothing
        T("C02_formato", v.StartsWith("v1.") AndAlso v.Length = 46 AndAlso v.IndexOf("="c) < 0 AndAlso v.IndexOf("+"c) < 0 AndAlso v.IndexOf("/"c) < 0)
        T("C03_andata_e_ritorno", KeepStoreStaySignedIn.TryParseCookieValue(v, parsed) AndAlso Convert.ToBase64String(parsed) = Convert.ToBase64String(k))
        T("C04_malformati", Bad(Nothing) AndAlso Bad("") AndAlso Bad("v1.") AndAlso Bad(v.Substring(3)) AndAlso Bad("v2." & v.Substring(3)) AndAlso Bad(v & "A") AndAlso Bad(v.Substring(0, 45)) AndAlso Bad(v.Substring(0, 45) & "=") AndAlso Bad(v.Substring(0, 45) & " ") AndAlso Bad(v.Substring(0, 40) & "+/+/+/"))
        Dim aliasFound As Integer = 0, aliasAccepted As Integer = 0
        For Each candidate As Char In "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
            If candidate = v.Chars(45) Then Continue For
            Dim alias1 As String = v.Substring(0, 45) & candidate
            Dim same As Boolean = False
            Try
                same = Convert.ToBase64String(Convert.FromBase64String(alias1.Substring(3).Replace("-"c, "+"c).Replace("_"c, "/"c) & "=")) = Convert.ToBase64String(k)
            Catch
                same = False
            End Try
            If same Then
                aliasFound += 1
                Dim forged As Byte() = Nothing
                If KeepStoreStaySignedIn.TryParseCookieValue(alias1, forged) Then aliasAccepted += 1
            End If
        Next
        T("C05_una_sola_scrittura_per_codice", aliasFound > 0 AndAlso aliasAccepted = 0)
        Dim threw As Boolean = False
        Try
            KeepStoreStaySignedIn.FormatCookieValue(New Byte() {1, 2, 3})
        Catch ex As ArgumentException
            threw = True
        End Try
        T("C06_codice_corto_rifiutato", threw)
        ' Impronta del token
        Dim h As String = KeepStoreStaySignedIn.ComputeTokenHash("Db-A ", 1, k)
        T("H01_forma", h.Length = 64 AndAlso h = h.ToLowerInvariant() AndAlso h = KeepStoreStaySignedIn.ComputeTokenHash("db-a", 1, k))
        T("H02_sensibile_a_database_azienda_codice", h <> KeepStoreStaySignedIn.ComputeTokenHash("db-b", 1, k) AndAlso h <> KeepStoreStaySignedIn.ComputeTokenHash("db-a", 2, k) AndAlso h <> KeepStoreStaySignedIn.ComputeTokenHash("db-a", 1, k2))
        T("H03_non_ambigua", KeepStoreStaySignedIn.ComputeTokenHash("db1", 2, k) <> KeepStoreStaySignedIn.ComputeTokenHash("db", 12, k))
        threw = False
        Try
            KeepStoreStaySignedIn.ComputeTokenHash("", 1, k)
        Catch ex As ArgumentException
            threw = True
        End Try
        Dim threw2 As Boolean = False
        Try
            KeepStoreStaySignedIn.ComputeTokenHash("db", 0, k)
        Catch ex As ArgumentException
            threw2 = True
        End Try
        T("H04_ingressi_non_validi", threw AndAlso threw2)
        ' Impronta delle credenziali
        Dim s0 As String = KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc())
        T("S01_forma_e_stabilita", s0.Length = 64 AndAlso s0 = KeepStoreStaySignedIn.ComputeCredentialStamp(k, "DB-A", Acc()) AndAlso s0 <> h)
        T("S02_chiave_del_codice", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k2, "db-a", Acc()))
        T("S03_database", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-b", Acc()))
        T("S04_azienda", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(company:=2)))
        T("S05_accesso", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(login:=8)))
        T("S06_utente", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(user:=71)))
        T("S07_nome_utente_senza_maiuscole", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(name:="Maria")) AndAlso s0 = KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(name:="MARIO")))
        T("S08_password_esatta", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(word:="Segreta2")) AndAlso s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(word:="segreta1")))
        T("S09_data_della_password", s0 <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(wordDate:="2026-01-02 00:00:01")))
        T("S10_campi_non_scambiabili", KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(name:="AB", word:="C")) <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(name:="A", word:="BC")) AndAlso KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(login:=1, user:=23)) <> KeepStoreStaySignedIn.ComputeCredentialStamp(k, "db-a", Acc(login:=12, user:=3)))
        T("S11_confronto", KeepStoreStaySignedIn.ConstantTimeEquals("abc", "abc") AndAlso Not KeepStoreStaySignedIn.ConstantTimeEquals("abc", "abd") AndAlso Not KeepStoreStaySignedIn.ConstantTimeEquals("abc", "ab") AndAlso Not KeepStoreStaySignedIn.ConstantTimeEquals(Nothing, Nothing) AndAlso Not KeepStoreStaySignedIn.ConstantTimeEquals("", Nothing) AndAlso Not KeepStoreStaySignedIn.ConstantTimeEquals("abc", "ABC"))
        ' Decisione
        T("D01_riconosciuto", D(Row(), Acc(), 1, "S", StaySignedInOutcome.Restored, ""))
        T("D02_sconosciuto", D(Nothing, Acc(), 1, "S", StaySignedInOutcome.Unknown, "") AndAlso D(New StaySignedInRow(), Acc(), 1, "S", StaySignedInOutcome.Unknown, ""))
        T("D03_revocato", D(Row(revoked:=True), Acc(), 1, "S", StaySignedInOutcome.Refused, ""))
        T("D04_scaduto", D(Row(notExpired:=False), Acc(), 1, "S", StaySignedInOutcome.Refused, ""))
        T("D05_altra_azienda", D(Row(company:=2), Acc(), 1, "S", StaySignedInOutcome.Refused, "account") AndAlso D(Row(), Acc(), 0, "S", StaySignedInOutcome.Refused, "account"))
        T("D06_accesso_assente", D(Row(), Nothing, 1, "S", StaySignedInOutcome.Refused, "account"))
        T("D07_accesso_disabilitato", D(Row(), Acc(enabled:=False), 1, "S", StaySignedInOutcome.Refused, "account"))
        T("D08_accesso_diverso_dalla_riga", D(Row(), Acc(login:=8), 1, "S", StaySignedInOutcome.Refused, "account"))
        T("D09_accesso_di_altra_azienda", D(Row(), Acc(company:=2), 1, "S", StaySignedInOutcome.Refused, "account"))
        T("D10_senza_utente", D(Row(), Acc(user:=0), 1, "S", StaySignedInOutcome.Refused, "account") AndAlso D(Row(), Acc(user:=-1), 1, "S", StaySignedInOutcome.Refused, "account"))
        T("D11_impronta_diversa", D(Row(), Acc(), 1, "T", StaySignedInOutcome.Refused, "credentials") AndAlso D(Row(), Acc(), 1, "", StaySignedInOutcome.Refused, "credentials") AndAlso D(Row(stamp:=""), Acc(), 1, "", StaySignedInOutcome.Refused, "credentials"))
        ' Senza database: nessuna eccezione
        KeepStoreStaySignedIn.ResetSuspension()
        Dim account As StaySignedInAccount = Acc()
        Dim renewed As Boolean = True
        T("N01_senza_cookie", KeepStoreStaySignedIn.TryRestore("x", "db", 1, "", account, renewed) = StaySignedInOutcome.NoToken AndAlso account Is Nothing AndAlso Not renewed)
        T("N02_senza_connessione", KeepStoreStaySignedIn.TryRestore("", "db", 1, v, account, renewed) = StaySignedInOutcome.Unavailable AndAlso KeepStoreStaySignedIn.Issue("", "db", 1, 7) = "" AndAlso Not KeepStoreStaySignedIn.Revoke("", "db", 1, v, "logout") AndAlso KeepStoreStaySignedIn.RevokeAllForLogin("", 7, "password") = 0 AndAlso Not KeepStoreStaySignedIn.Touch("", "db", 1, 7, v))
        T("N03_non_sospeso_senza_errori", Not KeepStoreStaySignedIn.IsSuspended())
        T("N04_errore_di_connessione_sospende", KeepStoreStaySignedIn.TryRestore("Server=127.0.0.1;Port=1;Connection Timeout=1", "db", 1, v, account, renewed) = StaySignedInOutcome.Unavailable AndAlso account Is Nothing AndAlso KeepStoreStaySignedIn.IsSuspended())
        KeepStoreStaySignedIn.ResetSuspension()
        T("N05_ripresa", Not KeepStoreStaySignedIn.IsSuspended())
        Return sb.ToString()
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    if ($moduleText -eq '') { if (-not $Quiet) { Write-Host '  FAIL A modulo assente' }; return $false }
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    foreach ($ref in 'System.dll', 'System.Data.dll', 'System.Core.dll') { [void]$p.ReferencedAssemblies.Add($ref) }
    [void]$p.ReferencedAssemblies.Add((Join-Path $root 'Bin\MySql.Data.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Bin\MySql.Data.dll'))
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    try { $out = [string]$c.CompiledAssembly.GetType('StaySignedInProbe').GetMethod('Run').Invoke($null, @()) } catch { if (-not $Quiet) { Write-Host ('  FAIL A eccezione: ' + $_.Exception.InnerException.Message) }; return $false }
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$labMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
function Invoke-Lab([string]$moduleText, [string]$ddlText) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $work = Join-Path $env:TEMP ('ks-staysigned-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $held = $false
    try {
        foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll') {
            if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $work -Force }
        }
        $cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
            '<dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>' +
            '</assemblyBinding></runtime></configuration>'
        $exe = Join-Path $work 'StaySignedInLabHarness.exe'
        $modFile = Join-Path $work 'KeepStoreStaySignedIn.vb'
        $ddlFile = Join-Path $work 'ddl.sql'
        [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
        [IO.File]::WriteAllText($modFile, $moduleText, $utf8)
        [IO.File]::WriteAllText($ddlFile, $ddlText, $utf8)
        $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
        $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\StaySignedInLabHarness.vb') $modFile 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { return ('COMPILE_ERROR ' + (($build | Select-Object -First 3) -join ' | ')) }
        try { $held = $labMutex.WaitOne(600000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return 'LAB_BUSY' }
        $cred = Import-Clixml -LiteralPath $credFile
        $plain = $cred.GetNetworkCredential().Password
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
        $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
        $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
        $info.EnvironmentVariables['KS_STAY_DDL'] = $ddlFile
        $proc = [Diagnostics.Process]::Start($info)
        $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
        if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>') }
        $plain = $null; $cred = $null
        return ((@($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|STAY_SIGNED_IN_LAB)' })) -join "`n")
    } finally {
        if ($held) { try { $labMutex.ReleaseMutex() } catch { } }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.module
if (-not ($okSource -and $okBehaviour)) { Write-Host 'STAY_SIGNED_IN FAIL'; exit 1 }

$nl = "`r`n"
$sourceMutants = @(
    @{ Id = 'M01_LOG_IN_MODULE'; File = 'module'; Old = 'Private Shared Sub Suspend()'; New = "Private Shared Sub LogMut(ByVal s As String) : KeepStoreLog.Error(`"stay`", s, Nothing, Nothing) : End Sub$nl    Private Shared Sub Suspend()" },
    @{ Id = 'M02_WEB_CONTEXT_IN_MODULE'; File = 'module'; Old = 'Private Shared Sub Suspend()'; New = "Private Shared Function CtxMut() As Object : Return System.Web.HttpContext.Current : End Function$nl    Private Shared Sub Suspend()" },
    @{ Id = 'M03_WEAK_RANDOM'; File = 'module'; Old = "Using generator As New RNGCryptoServiceProvider()$nl            generator.GetBytes(secret)$nl        End Using"; New = "Dim weak As New Random()$nl        weak.NextBytes(secret)" },
    @{ Id = 'M04_APP_CLOCK_FOR_EXPIRY'; File = 'module'; Old = 'If row.NeedsRenew Then renewed = RenewRow(connection, row.Id) = 1'; New = 'If row.NeedsRenew AndAlso DateTime.UtcNow.Year > 2000 Then renewed = RenewRow(connection, row.Id) = 1' },
    @{ Id = 'M05_ERROR_NOT_SUSPENDING'; File = 'module'; Old = "        Catch$nl            Suspend()$nl            Return 0$nl        End Try"; New = "        Catch$nl            Return 0$nl        End Try" },
    @{ Id = 'M06_LIFETIME_CHANGED'; File = 'module'; Old = 'Public Const LifetimeDays As Integer = 30'; New = 'Public Const LifetimeDays As Integer = 365' },
    @{ Id = 'M07_DOC_HASH_CASE_INSENSITIVE'; File = 'doc'; Old = 'TokenHash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL'; New = 'TokenHash CHAR(64) NOT NULL' },
    @{ Id = 'M08_DOC_TOKEN_NOT_UNIQUE'; File = 'doc'; Old = 'UNIQUE KEY uq_login_remembered_devices_tokenhash (TokenHash)'; New = 'KEY uq_login_remembered_devices_tokenhash (TokenHash)' },
    @{ Id = 'M09_DOC_ROLLBACK_LOST'; File = 'doc'; Old = 'DROP TABLE IF EXISTS login_remembered_devices;'; New = '' },
    @{ Id = 'M10_DOC_FOREIGN_KEY'; File = 'doc'; Old = '  PRIMARY KEY (id),'; New = '  PRIMARY KEY (id), FOREIGN KEY (LoginId) REFERENCES login (id),' }
)
$behaviourMutants = @(
    @{ Id = 'N01_COOKIE_LENGTH_ONLY_MINIMUM_AND_NO_ROUNDTRIP'; Old = 'If Not String.Equals(FormatCookieValue(decoded), value, StringComparison.Ordinal) Then Return False'; New = 'If decoded.Length = 0 Then Return False' },
    @{ Id = 'N04_COOKIE_ALIAS_ACCEPTED'; Old = 'If Not String.Equals(FormatCookieValue(decoded), value, StringComparison.Ordinal) Then Return False'; New = '' },
    @{ Id = 'N05_SHORT_SECRET_ACCEPTED'; Old = 'If secret Is Nothing OrElse secret.Length <> SecretLength Then Throw New ArgumentException("Invalid stay-signed-in secret")'; New = 'If secret Is Nothing Then Throw New ArgumentException("Invalid stay-signed-in secret")' },
    @{ Id = 'N06_HASH_WITHOUT_DATABASE'; Old = "WriteText(stream, TokenTag)$nl            WriteText(stream, NormalizeScope(databaseScope))"; New = "WriteText(stream, TokenTag)" },
    @{ Id = 'N07_HASH_WITHOUT_COMPANY'; Old = "WriteText(stream, companyId.ToString(CultureInfo.InvariantCulture))$nl            WriteField(stream, secret)"; New = "WriteField(stream, secret)" },
    @{ Id = 'N08_HASH_INPUT_NOT_VALIDATED'; Old = 'If NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse secret Is Nothing OrElse secret.Length <> SecretLength Then'; New = 'If secret Is Nothing OrElse secret.Length <> SecretLength Then' },
    @{ Id = 'N09_FIELDS_NOT_LENGTH_PREFIXED'; Old = "        stream.WriteByte(CByte((length >> 24) And &HFF))$nl        stream.WriteByte(CByte((length >> 16) And &HFF))$nl        stream.WriteByte(CByte((length >> 8) And &HFF))$nl        stream.WriteByte(CByte(length And &HFF))$nl"; New = '' },
    @{ Id = 'N10_STAMP_WITHOUT_SECRET_KEY'; Old = 'Using hmac As New HMACSHA256(secret)'; New = 'Using hmac As New HMACSHA256(New Byte() {1, 2, 3})' },
    @{ Id = 'N11_STAMP_WITHOUT_DATABASE'; Old = "WriteText(stream, StampTag)$nl            WriteText(stream, NormalizeScope(databaseScope))"; New = "WriteText(stream, StampTag)" },
    @{ Id = 'N12_STAMP_WITHOUT_COMPANY'; Old = "            WriteText(stream, account.AziendeId.ToString(CultureInfo.InvariantCulture))$nl"; New = '' },
    @{ Id = 'N13_STAMP_WITHOUT_LOGIN'; Old = "            WriteText(stream, account.LoginId.ToString(CultureInfo.InvariantCulture))$nl"; New = '' },
    @{ Id = 'N14_STAMP_WITHOUT_USER'; Old = "            WriteText(stream, account.UtentiId.ToString(CultureInfo.InvariantCulture))$nl"; New = '' },
    @{ Id = 'N15_STAMP_WITHOUT_USERNAME'; Old = "            WriteText(stream, If(account.UserName, String.Empty).ToUpperInvariant())$nl"; New = '' },
    @{ Id = 'N16_STAMP_PASSWORD_CASE_FOLDED'; Old = 'WriteText(stream, If(account.StoredSecret, String.Empty))'; New = 'WriteText(stream, If(account.StoredSecret, String.Empty).ToLowerInvariant())' },
    @{ Id = 'N17_STAMP_WITHOUT_PASSWORD'; Old = "            WriteText(stream, If(account.StoredSecret, String.Empty))$nl"; New = '' },
    @{ Id = 'N18_STAMP_WITHOUT_PASSWORD_DATE'; Old = "            WriteText(stream, If(account.PasswordDate, String.Empty))$nl"; New = '' },
    @{ Id = 'N19_EQUALS_IGNORES_LENGTH'; Old = 'If first Is Nothing OrElse second Is Nothing OrElse first.Length <> second.Length Then Return False'; New = 'If first Is Nothing OrElse second Is Nothing Then Return False' + $nl + '        If first.Length > second.Length Then first = first.Substring(0, second.Length)' + $nl + '        If second.Length > first.Length Then second = second.Substring(0, first.Length)' },
    @{ Id = 'N20_EQUALS_ALWAYS_TRUE'; Old = 'Return difference = 0'; New = 'Return True' },
    @{ Id = 'N21_REVOKED_ACCEPTED'; Old = 'If row.Revoked OrElse Not row.NotExpired Then Return StaySignedInOutcome.Refused'; New = 'If Not row.NotExpired Then Return StaySignedInOutcome.Refused' },
    @{ Id = 'N22_EXPIRED_ACCEPTED'; Old = 'If row.Revoked OrElse Not row.NotExpired Then Return StaySignedInOutcome.Refused'; New = 'If row.Revoked Then Return StaySignedInOutcome.Refused' },
    @{ Id = 'N23_COMPANY_NOT_CHECKED'; Old = 'If companyId <= 0 OrElse row.AziendeId <> companyId Then'; New = 'If False Then' },
    @{ Id = 'N24_DISABLED_ACCEPTED'; Old = 'If account Is Nothing OrElse Not account.Enabled OrElse'; New = 'If account Is Nothing OrElse' },
    @{ Id = 'N25_OTHER_LOGIN_ACCEPTED'; Old = ' OrElse account.LoginId <> row.LoginId OrElse'; New = ' OrElse' },
    @{ Id = 'N26_ACCOUNT_COMPANY_NOT_CHECKED'; Old = ' OrElse account.AziendeId <> companyId OrElse account.UtentiId <= 0 Then'; New = ' OrElse account.UtentiId <= 0 Then' },
    @{ Id = 'N27_NO_USER_ACCEPTED'; Old = ' OrElse account.AziendeId <> companyId OrElse account.UtentiId <= 0 Then'; New = ' OrElse account.AziendeId <> companyId Then' },
    @{ Id = 'N28_STAMP_NOT_CHECKED'; Old = 'If String.IsNullOrEmpty(expectedStamp) OrElse Not ConstantTimeEquals(row.CredentialStamp, expectedStamp) Then'; New = 'If False Then' },
    @{ Id = 'N32_EMPTY_STAMP_MATCHES'; Old = 'If String.IsNullOrEmpty(expectedStamp) OrElse Not ConstantTimeEquals(row.CredentialStamp, expectedStamp) Then'; New = 'If Not ConstantTimeEquals(row.CredentialStamp, expectedStamp) Then' },
    @{ Id = 'N29_WRONG_REVOKE_REASON'; Old = "            revokeReason = `"credentials`""; New = "            revokeReason = `"`"" },
    @{ Id = 'N30_SUSPENSION_NEVER'; Old = '_suspendedUntilUtc = DateTime.UtcNow.AddMinutes(SuspendMinutes)'; New = '_suspendedUntilUtc = DateTime.MinValue' },
    @{ Id = 'N31_RESTORE_WITHOUT_CONNECTION_STRING_CHECK'; Old = 'If String.IsNullOrWhiteSpace(connectionString) OrElse NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse IsSuspended() Then Return StaySignedInOutcome.Unavailable'; New = 'If NormalizeScope(databaseScope).Length = 0 OrElse companyId <= 0 OrElse IsSuspended() Then Return StaySignedInOutcome.Unavailable' }
)
$labMutants = @(
    @{ Id = 'D01_RESTORE_IGNORES_STAMP_FROM_DB'; Old = 'If found IsNot Nothing Then expectedStamp = ComputeCredentialStamp(secret, databaseScope, found)'; New = 'If found IsNot Nothing Then expectedStamp = row.CredentialStamp' },
    @{ Id = 'D02_NO_REVOKE_ON_MISMATCH'; Old = 'If revokeReason.Length > 0 Then RevokeRow(connection, row.Id, revokeReason)'; New = '' },
    @{ Id = 'D03_ACCOUNT_WITHOUT_COMPANY'; Old = 'FROM vlogin WHERE id=?loginId AND AziendeId=?aziendaId LIMIT 2"'; New = 'FROM vlogin WHERE id=?loginId AND ?aziendaId>0 LIMIT 2"' },
    @{ Id = 'D04_RENEW_AFTER_ONE_HOUR'; Old = 'Public Const RenewAfterHours As Integer = 24'; New = 'Public Const RenewAfterHours As Integer = 1' },
    @{ Id = 'D05_RENEW_NEVER'; Old = 'If row.NeedsRenew Then renewed = RenewRow(connection, row.Id) = 1'; New = '' },
    @{ Id = 'D06_TOUCH_ANY_LOGIN'; Old = ' OrElse row.LoginId <> loginId OrElse row.AziendeId <> companyId OrElse Not row.NeedsRenew Then Return False'; New = ' OrElse row.AziendeId <> companyId OrElse Not row.NeedsRenew Then Return False' },
    @{ Id = 'D07_EXPIRY_NOT_CHECKED_IN_SQL'; Old = '(RevokedUtc IS NOT NULL), (ExpiresUtc > UTC_TIMESTAMP()), '; New = '(RevokedUtc IS NOT NULL), (1=1), ' },
    @{ Id = 'D08_REVOKE_ALL_LOGINS'; Old = 'RevokeReason=?motivo WHERE LoginId=?loginId AND RevokedUtc IS NULL", connection)'; New = 'RevokeReason=?motivo WHERE ?loginId>0 AND RevokedUtc IS NULL", connection)' },
    @{ Id = 'D09_NO_DEVICE_LIMIT'; Old = 'If active >= MaxDevicesPerLogin Then'; New = 'If False Then' },
    @{ Id = 'D10_LIMIT_REVOKES_NEWEST'; Old = 'ORDER BY LastUsedUtc ASC, id ASC LIMIT ?quanti'; New = 'ORDER BY LastUsedUtc DESC, id DESC LIMIT ?quanti' },
    @{ Id = 'D11_NO_CLEANUP'; Old = 'DELETE FROM login_remembered_devices WHERE LoginId=?loginId AND ExpiresUtc <= UTC_TIMESTAMP()'; New = 'DELETE FROM login_remembered_devices WHERE LoginId=?loginId AND 1=0' },
    @{ Id = 'D12_CLEANUP_ALL_LOGINS'; Old = 'DELETE FROM login_remembered_devices WHERE LoginId=?loginId AND ExpiresUtc <= UTC_TIMESTAMP()'; New = 'DELETE FROM login_remembered_devices WHERE ?loginId>0' },
    @{ Id = 'D13_ISSUE_FOR_DISABLED'; Old = 'If account Is Nothing OrElse Not account.Enabled OrElse account.UtentiId <= 0 Then Return String.Empty'; New = 'If account Is Nothing Then Return String.Empty' },
    @{ Id = 'D14_TOKEN_STORED_IN_CLEAR'; Old = 'insert.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = tokenHash'; New = 'insert.Parameters.Add("?hash", MySqlDbType.VarChar, 64).Value = FormatCookieValue(secret)' },
    @{ Id = 'D15_ERROR_THROWS'; Old = "        Catch$nl            Suspend()$nl            account = Nothing$nl            renewed = False$nl            Return StaySignedInOutcome.Unavailable$nl        End Try"; New = "        Catch$nl            Throw$nl        End Try" },
    @{ Id = 'D16_REVOKE_REASON_LOST'; Old = 'Return RevokeRow(connection, row.Id, reason) = 1'; New = 'Return RevokeRow(connection, row.Id, "x") = 1' }
)
$minMutants = 50
if (($sourceMutants.Count + $behaviourMutants.Count + $labMutants.Count) -lt $minMutants) { Write-Host 'STAY_SIGNED_IN FAIL (pochi mutanti)'; exit 1 }
$bad = 0
foreach ($mu in $sourceMutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.module.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'STAY_SIGNED_IN FAIL (mutanti)'; exit 1 }

$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml')) -and (Test-Path -LiteralPath (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe')) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $ddl = Get-Ddl $files.doc
        $result = Invoke-Lab $files.module $ddl
        $summary = @($result -split "`n" | Where-Object { $_ -match '^STAY_SIGNED_IN_LAB ' }) | Select-Object -Last 1
        if ($summary -notmatch 'FAIL=0$') { $result -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'STAY_SIGNED_IN FAIL (LAB)'; exit 1 }
        foreach ($mu in $labMutants) {
            if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
            $r = Invoke-Lab ($files.module.Replace($mu.Old, $mu.New)) $ddl
            $s = @($r -split "`n" | Where-Object { $_ -match '^STAY_SIGNED_IN_LAB ' }) | Select-Object -Last 1
            if ($r -match 'COMPILE_ERROR|LAB_BUSY') { Write-Host ('  MUTANT_INVALID ' + $mu.Id + ' ' + $r); $bad++; continue }
            if ($s -match 'FAIL=0$') { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
        }
        if ($bad -gt 0) { Write-Host 'STAY_SIGNED_IN FAIL (mutanti LAB)'; exit 1 }
        $final = Invoke-Lab $files.module $ddl
        if ((@($final -split "`n" | Where-Object { $_ -match '^STAY_SIGNED_IN_LAB ' }) | Select-Object -Last 1) -notmatch 'FAIL=0$') { $final -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'STAY_SIGNED_IN FAIL (LAB dopo le mutazioni)'; exit 1 }
        $labNote = $summary + ', ' + $labMutants.Count + ' mutazioni del livello dati sul LAB'
    }
}
Write-Host ('STAY_SIGNED_IN PASS (' + ($sourceMutants.Count + $behaviourMutants.Count + $labMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
