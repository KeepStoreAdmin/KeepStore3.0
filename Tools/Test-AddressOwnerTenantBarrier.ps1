[CmdletBinding()]
param([string]$BaselineRef = '768907fe447896dc7310854034218080fd4ddc3e')

# KS-C02-ADDRESS-OWNER-TENANT-BARRIER-1A: la pagina indirizzi dell'account usa solo lo scope gia validato dal master
# (login + utente + azienda della vetrina, stesso contratto di my-account-edit), legge con la tupla completa nello
# stesso statement e scrive solo dopo aver bloccato e verificato il proprietario come prima istruzione della transazione.
# 1) controlli sorgente contro la base; 2) esecuzione su SQLite di sistema in memoria (winsqlite3.dll) delle query di
# lettura e dei metodi di scrittura REALI estratti meccanicamente; 3) mutazioni che devono far fallire il banco.
# Nessun MySQL, IIS, sessione ASP.NET, rete o dato reale.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTemp = Join-Path $taskTempBase ('ks-address-owner-' + [Guid]::NewGuid().ToString('N'))
$taskPage = 'my-account-address.aspx.vb'

function Read-Source([string]$path) {
    return [IO.File]::ReadAllText((Join-Path $taskRoot $path)).TrimStart([char]0xFEFF).Replace("`r`n", "`n")
}
function Read-Base([string]$path) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = 'git'
    $info.Arguments = '-C "' + $taskRoot + '" show ' + $BaselineRef + ':' + $path
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.UseShellExecute = $false
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $process = [Diagnostics.Process]::Start($info)
    $text = $process.StandardOutput.ReadToEnd()
    [void]$process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw 'ADDRESS_BASE_READ_FAILED' }
    return $text.TrimStart([char]0xFEFF).Replace("`r`n", "`n")
}
function Get-Method([string]$source, [string]$name) {
    $found = [regex]::Matches($source, '(?ms)^[ \t]*(?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) ' + [regex]::Escape($name) + '\b.*?^[ \t]*End (?:Function|Sub)')
    if ($found.Count -ne 1) { throw ('ADDRESS_METHOD_NOT_UNIQUE_' + $name) }
    return $found[0].Value
}
function Get-MethodNames([string]$source) {
    return @([regex]::Matches($source, '(?m)^[ \t]*(?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b') | ForEach-Object { $_.Groups[1].Value })
}
function Get-SqlExpression([string]$method) {
    $found = [regex]::Matches($method, '(?ms)Dim sql As String =\s*(.*?)\n[ \t]*\n')
    if ($found.Count -ne 1) { throw 'ADDRESS_SQL_EXPRESSION_NOT_UNIQUE' }
    return $found[0].Groups[1].Value
}
function Normalize([string]$text) { return ($text -replace '\s+', ' ').Trim() }
function Strip-Comments([string]$text) { return [regex]::Replace($text, "(?m)^[ \t]*'.*$", '') }
function Replace-Once([string]$text, [string]$old, [string]$new) {
    if (-not $text.Contains($old)) { throw ('MUTATION_NOT_APPLICABLE: ' + $old) }
    $index = $text.IndexOf($old, [StringComparison]::Ordinal)
    return $text.Substring(0, $index) + $new + $text.Substring($index + $old.Length)
}

$taskReadMethods = @('BindMainAddress', 'LoadAlternativeAddresses', 'LoadAlternativeAddressById')
$taskWriteMethods = @('SetDefaultAlternativeAddress', 'SaveAlternativeAddress')
$taskUnchanged = @('Page_Load', 'CurrentLoginId', 'btnShowAddAddress_Click', 'ShowAddAddressForm', 'HideAddressForm', 'ClearAddressForm', 'CurrentAddressFormId', 'ValidateAddressForm', 'InsertAlternativeAddress', 'CleanInput', 'SafeField', 'IsDefaultAddress', 'IsDefaultValue', 'SafeRowViewValue', 'SafeRowValue', 'SafeText', 'ClearMessage', 'ShowMessage', 'ShowValidationMessage')

# Esegue i controlli sorgente su un candidato e restituisce l'elenco degli esiti falliti (vuoto = tutti PASS).
function Invoke-StaticChecks([string]$candidate, [string]$base, [bool]$quiet) {
    $failed = New-Object 'Collections.Generic.List[string]'
    $script:staticPassed = 0
    function Check([bool]$condition, [string]$name) {
        if ($condition) { $script:staticPassed++; if (-not $quiet) { Write-Host ('PASS ' + $name) } } else { $failed.Add($name) }
    }
    $profileSource = Read-Source 'my-account-edit.aspx.vb'

    # --- Base: il difetto e riprodotto sul sorgente ---
    Check ($base -notmatch '(?i)AziendeId|AziendaId') 'BASELINE_PAGE_HAS_NO_TENANT_SCOPE'
    Check ($base.Contains('ResolveUtentiId') -and $base.Contains('FROM vlogin v INNER JOIN utenti u') -and $base.Contains('Session("UtentiId") = utentiId')) 'BASELINE_FALLBACK_REBUILDS_OWNER_FROM_VLOGIN_AND_WRITES_SESSION'

    # --- Candidato: proprietario solo dallo scope validato ---
    Check ((Strip-Comments $candidate) -notmatch 'ResolveUtentiId|vlogin') 'FALLBACK_AND_VLOGIN_REMOVED'
    Check ((Strip-Comments $candidate) -notmatch '(?i)Session\("UtentiId"\)\s*=[^=]') 'OWNER_NEVER_WRITTEN_TO_SESSION'
    $scopeMethodNew = Normalize (Strip-Comments ((Get-Method $candidate 'CurrentAddressScope').Replace('AccountAddressScope', 'AccountProfileScope').Replace('CurrentAddressScope', 'CurrentProfileScope')))
    $scopeMethodProfile = Normalize (Strip-Comments (Get-Method $profileSource 'CurrentProfileScope'))
    Check ($scopeMethodNew -ceq $scopeMethodProfile) 'SCOPE_METHOD_EQUALS_PROFILE_CONTRACT'
    Check ((Normalize (Get-Method $candidate 'SafeInt')) -ceq (Normalize (Get-Method $profileSource 'SafeInt'))) 'SAFEINT_EQUALS_PROFILE'
    Check ((Normalize (Get-Method $candidate 'AddAddressScopeParameters')).Replace('AddAddressScopeParameters', 'AddProfileScopeParameters').Replace('AccountAddressScope', 'AccountProfileScope') -ceq (Normalize (Get-Method $profileSource 'AddProfileScopeParameters'))) 'SCOPE_PARAMETERS_EQUAL_PROFILE_AND_TYPED_INT32'
    $isCurrent = Get-Method $candidate 'IsAddressScopeCurrent'
    Check ($isCurrent.Contains('If expected Is Nothing Then Return False') -and $isCurrent.Contains('String.Equals(current.Marker, expected.Marker, StringComparison.Ordinal)')) 'SCOPE_CURRENT_COMPARES_MARKER_FAIL_CLOSED'

    # --- Guardia di scrittura ---
    $lock = Get-Method $candidate 'LockAddressOwner'
    Check ($lock.Contains('If Not IsAddressScopeCurrent(scope) Then Return False') -and $lock.IndexOf('IsAddressScopeCurrent') -lt $lock.IndexOf('New MySqlCommand')) 'LOCK_CHECKS_SCOPE_BEFORE_ANY_SQL'
    Check ($lock.Contains('SELECT 1 FROM login l INNER JOIN utenti u ON l.UtentiId = u.Id WHERE l.id = @LoginId AND u.Id = @UtentiId AND u.AziendeId = @AziendaId AND u.Abilitato = 1 AND l.Abilitato = 1 LIMIT 1 FOR UPDATE')) 'LOCK_SQL_FULL_TUPLE_WITH_FOR_UPDATE'
    Check ($lock.Contains('AddAddressScopeParameters(cmd, scope)') -and $lock.Contains('Return raw IsNot Nothing AndAlso raw IsNot DBNull.Value')) 'LOCK_USES_SCOPE_PARAMETERS_AND_REQUIRES_A_ROW'
    foreach ($name in $taskWriteMethods) {
        $m = Get-Method $candidate $name
        $firstTry = $m.IndexOf('Try', [StringComparison]::Ordinal)
        $lockIndex = $m.IndexOf('LockAddressOwner(conn, tr, scope)', [StringComparison]::Ordinal)
        $firstSql = @('New MySqlCommand', 'AddressBelongsToUser(', 'CountAlternativeAddresses(', 'ResetDefaultAddresses(', 'UpdateAlternativeAddress(', 'InsertAlternativeAddress(') | ForEach-Object { $i = $m.IndexOf($_, [StringComparison]::Ordinal); if ($i -ge 0) { $i } } | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        Check ($firstTry -ge 0 -and $lockIndex -gt $firstTry -and $lockIndex -lt $firstSql) ($name + '_LOCKS_OWNER_FIRST_INSIDE_TRANSACTION')
        $lockBlock = $m.Substring($lockIndex, [Math]::Min(170, $m.Length - $lockIndex))
        Check ($lockBlock.Contains('tr.Rollback()') -and $lockBlock.Contains('Return False')) ($name + '_DENIAL_ROLLS_BACK_AND_RETURNS_FALSE')
        $guardBeforeCommit = $m.LastIndexOf('IsAddressScopeCurrent(scope)', [StringComparison]::Ordinal)
        Check ($guardBeforeCommit -gt 0 -and $guardBeforeCommit -lt $m.IndexOf('tr.Commit()', [StringComparison]::Ordinal)) ($name + '_RECHECKS_SCOPE_BEFORE_COMMIT')
        Check ($m -notmatch 'AddWithValue') ($name + '_NO_ADDWITHVALUE_ON_OWNER_OR_ADDRESS_ID')
    }

    # --- Letture con tupla completa nello stesso statement ---
    foreach ($name in $taskReadMethods) {
        $m = Get-Method $candidate $name
        $sql = Get-SqlExpression $m
        $checkIndex = $m.IndexOf('IsAddressScopeCurrent(scope)', [StringComparison]::Ordinal)
        Check ($checkIndex -ge 0 -and $checkIndex -lt $m.IndexOf('New MySqlConnection', [StringComparison]::Ordinal)) ($name + '_CHECKS_SCOPE_BEFORE_OPENING_CONNECTION')
        Check ($sql.Contains('l.id = @LoginId') -and $sql.Contains('u.AziendeId = @AziendaId') -and $sql.Contains('u.Abilitato = 1') -and $sql.Contains('l.Abilitato = 1') -and $sql.Contains('INNER JOIN login l ON l.UtentiId = u.Id')) ($name + '_SQL_CARRIES_FULL_TUPLE')
        Check ($m.Contains('AddAddressScopeParameters(cmd, scope)') -and $m -notmatch 'AddWithValue') ($name + '_USES_TYPED_SCOPE_PARAMETERS')
    }
    Check ((Get-Method $candidate 'LoadAlternativeAddressById').Contains('cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId')) 'BY_ID_PARAMETER_TYPED_INT32'

    # --- Gestori: ottengono lo scope prima di qualunque lettura o scrittura ---
    foreach ($handler in @(@('BindAddressPage', 'BindMainAddress(scope)'), @('rptAlternativeAddresses_ItemCommand', 'ShowEditAddressForm(scope'), @('btnCancelAddress_Click', 'BindAlternativeAddresses(scope)'), @('btnSaveAddress_Click', 'SaveAlternativeAddress(scope'))) {
        $m = Get-Method $candidate $handler[0]
        $scopeIndex = $m.IndexOf('CurrentAddressScope()', [StringComparison]::Ordinal)
        $useIndex = $m.IndexOf($handler[1], [StringComparison]::Ordinal)
        Check ($scopeIndex -ge 0 -and $useIndex -gt $scopeIndex) ($handler[0] + '_READS_SCOPE_BEFORE_DATA_ACCESS')
    }
    Check ((Get-Method $candidate 'BindAddressPage').Contains('Response.Redirect("accessonegato.aspx", True)') -and (Get-Method $candidate 'btnSaveAddress_Click').Contains('Response.Redirect("accessonegato.aspx", True)')) 'ACCESS_DENIED_REDIRECT_PRESERVED'
    Check ((Get-Method $candidate 'rptAlternativeAddresses_ItemCommand').Contains('Non e stato possibile aprire la sede richiesta.') -and (Get-Method $candidate 'rptAlternativeAddresses_ItemCommand').Contains('Non e stato possibile aggiornare la sede predefinita.')) 'GENERIC_DENIAL_MESSAGES_PRESERVED'

    # --- Perimetro: metodi non toccati identici, istruzioni di scrittura invariate ---
    foreach ($name in $taskUnchanged) {
        Check ((Normalize (Get-Method $candidate $name)) -ceq (Normalize (Get-Method $base $name))) ('UNCHANGED_' + $name)
    }
    $baseNames = Get-MethodNames $base
    $candidateNames = Get-MethodNames $candidate
    $added = @($candidateNames | Where-Object { $_ -notin $baseNames } | Sort-Object)
    $removed = @($baseNames | Where-Object { $_ -notin $candidateNames } | Sort-Object)
    Check (($added -join ',') -ceq 'AddAddressScopeParameters,CurrentAddressScope,IsAddressScopeCurrent,LockAddressOwner,SafeInt') 'ADDED_METHODS_ARE_EXACTLY_THE_SCOPE_HELPERS'
    Check (($removed -join ',') -ceq 'ResolveUtentiId') 'REMOVED_METHOD_IS_ONLY_RESOLVE_UTENTI_ID'
    foreach ($sqlText in @(
        '"SELECT COUNT(*) FROM utentiindirizzi WHERE Id = @Id AND UtenteId = @UtentiId"',
        '"SELECT COUNT(*) FROM utentiindirizzi WHERE UtenteId = @UtentiId"',
        '"UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId"',
        '"UPDATE utentiindirizzi SET Predefinito = 1 WHERE Id = @Id AND UtenteId = @UtentiId"',
        '" WHERE Id = @Id AND UtenteId = @UtentiId"',
        '"(@UtentiId, @RagioneSocialeA, @NomeA, @IndirizzoA, @CapA, @CittaA, @ProvinciaA, @Zona, @TelefonoA, @CellulareA, @FaxA, @Note, @NazioneA, @Predefinito)"')) {
        Check ($base.Contains($sqlText) -and $candidate.Contains($sqlText)) ('WRITE_SQL_TEXT_UNCHANGED ' + $sqlText.Substring(0, [Math]::Min(48, $sqlText.Length)))
    }
    Check ($candidate -notmatch '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') 'NO_CLIENT_LITERALS'
    foreach ($path in @('my-account-address.aspx', 'Page.master.vb', 'my-account-edit.aspx.vb', 'login.aspx.vb', 'App_Code/StorefrontCommercialIsolationPolicy.vb', 'App_Code/StorefrontSeoTenantContext.vb')) {
        Check ((Read-Source $path) -ceq (Read-Base $path)) ('UNCHANGED_FILE_' + [IO.Path]::GetFileName($path))
    }
    return , $failed
}

function Convert-Type([string]$text) {
    return [regex]::Replace($text, '\bMySql(Connection|Transaction|Command)\b', { param($m) 'Fixture' + $m.Groups[1].Value })
}

# Compila ed esegue il banco su un testo candidato; restituisce codice di uscita e output.
function Invoke-Behavior([string]$candidate, [string]$base, [string]$label) {
    $directory = Join-Path $taskTemp $label
    New-Item -ItemType Directory -Path $directory | Out-Null
    $reads = @{}
    foreach ($pair in @(@('MainAddress', 'BindMainAddress'), @('AlternativeList', 'LoadAlternativeAddresses'), @('AlternativeById', 'LoadAlternativeAddressById'))) {
        $reads[$pair[0]] = @{ New = (Get-SqlExpression (Get-Method $candidate $pair[1])); Old = (Get-SqlExpression (Get-Method $base $pair[1])) }
    }
    $fixture = "Option Strict Off`nOption Explicit On`nImports System`nImports System.Collections.Generic`nImports MySql.Data.MySqlClient`n"
    foreach ($kind in @('Candidate', 'Baseline')) {
        $fixture += "Public NotInheritable Class ReadSql$kind`n"
        foreach ($key in @('MainAddress', 'AlternativeList', 'AlternativeById')) {
            $expression = if ($kind -eq 'Candidate') { $reads[$key].New } else { $reads[$key].Old }
            $fixture += "    Public Shared Function $key() As String`n        Return $expression`n    End Function`n"
        }
        $fixture += "End Class`n"
    }
    $writeNames = @('SetDefaultAlternativeAddress', 'SaveAlternativeAddress', 'AddressBelongsToUser', 'CountAlternativeAddresses', 'ResetDefaultAddresses', 'InsertAlternativeAddress', 'UpdateAlternativeAddress', 'AddAddressParameters', 'CleanInput', 'LockAddressOwner', 'AddAddressScopeParameters')
    $controls = @('tbRagioneSocialeA', 'tbNomeA', 'tbIndirizzoA', 'tbCapA', 'tbCittaA', 'tbProvinciaA', 'tbZona', 'tbTelefonoA', 'tbCellulareA', 'tbFaxA', 'tbNote', 'tbNazioneA')
    $fixture += "Public Class AddressWriteFixture`n"
    $fixture += "    Public Class AccountAddressScope`n        Public LoginId As Integer`n        Public UserId As Integer`n        Public CompanyId As Integer`n        Public Marker As String`n    End Class`n"
    foreach ($control in $controls) { $fixture += "    Public $control As New FakeText()`n" }
    $fixture += "    Public chkSetDefault As New FakeCheck()`n"
    $fixture += "    Private ReadOnly Property ConnString As String`n        Get`n            Return `"fixture`"`n        End Get`n    End Property`n"
    $fixture += "    Private Function IsAddressScopeCurrent(ByVal expected As AccountAddressScope) As Boolean`n        Return AddressFixture.ScopeCurrent()`n    End Function`n"
    foreach ($name in $writeNames) {
        $method = Get-Method $candidate $name
        $method = $method -replace '^([ \t]*)Private ', '$1Public '
        $fixture += (Convert-Type $method) + "`n"
    }
    $fixture += "End Class`n"
    $fixturePath = Join-Path $directory 'ExtractedAddressPage.vb'
    [IO.File]::WriteAllText($fixturePath, $fixture)
    $executable = Join-Path $directory 'AddressOwnerTenantBarrierHarness.exe'
    $references = @('System.dll', 'System.Core.dll', 'System.Data.dll') | ForEach-Object { Join-Path $taskFramework $_ }
    $references += (Join-Path $taskRoot 'Bin\MySql.Data.dll')
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # Il banco e compilato con Option Strict On; il frammento estratto con Strict Off come il codice originale.
        $compileOutput = & (Join-Path $taskFramework 'vbc.exe') /nologo /optionexplicit+ /target:exe "/out:$executable" ('/reference:' + ($references -join ',')) $fixturePath (Join-Path $PSScriptRoot 'AddressOwnerTenantBarrierHarness.vb') 2>&1
        $compileExit = $LASTEXITCODE
        if ($compileExit -ne 0) { throw ('ADDRESS_HARNESS_COMPILE_FAILED ' + (($compileOutput | ForEach-Object { "$_" }) -join ' ')) }
        Copy-Item -LiteralPath (Join-Path $taskRoot 'Bin\MySql.Data.dll') -Destination $directory
        $runOutput = & $executable 2>&1
        $runExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return @{ ExitCode = $runExit; Output = (($runOutput | ForEach-Object { "$_" }) -join "`n") }
}

if (-not (Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32\winsqlite3.dll'))) { throw 'WINSQLITE3_UNAVAILABLE' }
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'Bin\MySql.Data.dll'))) { throw 'MYSQL_DATA_DLL_UNAVAILABLE' }

$taskCandidate = Read-Source $taskPage
$taskBase = Read-Base $taskPage
$failed = Invoke-StaticChecks $taskCandidate $taskBase $false
if ($failed.Count -gt 0) { throw ('STATIC_CHECKS_FAILED: ' + ($failed -join '; ')) }
$taskStaticCount = $script:staticPassed

New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
    $main = Invoke-Behavior $taskCandidate $taskBase 'candidate'
    Write-Output $main.Output
    if ($main.ExitCode -ne 0) { throw 'ADDRESS_HARNESS_FAILED' }

    # Mutazioni: ciascuna deve essere rilevata dai controlli sorgente o dal banco comportamentale.
    $mutations = [ordered]@{
        'MUTATION_LIST_COMPANY_PREDICATE_REMOVED'      = { param($t) Replace-Once $t '"WHERE a.UtenteId = @UtentiId AND l.id = @LoginId AND u.AziendeId = @AziendaId " &' '"WHERE a.UtenteId = @UtentiId AND l.id = @LoginId " &' }
        'MUTATION_BY_ID_LOGIN_PREDICATE_REMOVED'       = { param($t) Replace-Once $t 'AND a.UtenteId = @UtentiId AND l.id = @LoginId AND u.AziendeId = @AziendaId' 'AND a.UtenteId = @UtentiId AND u.AziendeId = @AziendaId' }
        'MUTATION_MAIN_USER_ENABLED_PREDICATE_REMOVED' = { param($t) Replace-Once $t '"AND u.Abilitato = 1 AND l.Abilitato = 1 LIMIT 1"' '"AND l.Abilitato = 1 LIMIT 1"' }
        'MUTATION_LOCK_ALWAYS_SUCCEEDS'                = { param($t) Replace-Once $t 'Return raw IsNot Nothing AndAlso raw IsNot DBNull.Value' 'Return True' }
        'MUTATION_LOCK_COMPANY_PREDICATE_REMOVED'      = { param($t) Replace-Once $t 'WHERE l.id = @LoginId AND u.Id = @UtentiId AND u.AziendeId = @AziendaId AND u.Abilitato = 1' 'WHERE l.id = @LoginId AND u.Id = @UtentiId AND u.Abilitato = 1' }
        'MUTATION_LOCK_WITHOUT_FOR_UPDATE'             = { param($t) Replace-Once $t ' LIMIT 1 FOR UPDATE"' ' LIMIT 1"' }
        'MUTATION_SAVE_SKIPS_OWNER_LOCK'               = { param($t) $i = $t.IndexOf('Private Function SaveAlternativeAddress', [StringComparison]::Ordinal); $head = $t.Substring(0, $i); $tail = $t.Substring($i); $head + (Replace-Once $tail 'If Not LockAddressOwner(conn, tr, scope) Then' 'If False Then') }
        'MUTATION_SET_DEFAULT_SKIPS_FINAL_RECHECK'     = { param($t) $i = $t.IndexOf('Private Function SetDefaultAlternativeAddress', [StringComparison]::Ordinal); $head = $t.Substring(0, $i); $tail = $t.Substring($i); $head + (Replace-Once $tail 'If Not IsAddressScopeCurrent(scope) Then' 'If False Then') }
        'MUTATION_FALLBACK_RESTORED'                   = { param($t) Replace-Once $t 'Private Function SafeInt(' "Private Function ResolveUtentiId(ByVal loginId As Integer) As Integer`n        Return 0`n    End Function`n`n    Private Function SafeInt(" }
        'MUTATION_OWNER_WRITTEN_TO_SESSION'            = { param($t) Replace-Once $t 'Return New AccountAddressScope() With' "Session(`"UtentiId`") = userId`n        Return New AccountAddressScope() With" }
    }
    $mutationIndex = 0
    $mutationPassed = 0
    foreach ($name in $mutations.Keys) {
        $mutationIndex++
        $mutated = & $mutations[$name] $taskCandidate
        if ($mutated -ceq $taskCandidate) { throw ('MUTATION_NO_CHANGE ' + $name) }
        $staticFailed = $null
        try { $staticFailed = Invoke-StaticChecks $mutated $taskBase $true } catch { $staticFailed = @('exception') }
        $staticDetected = ($staticFailed.Count -gt 0)
        $behaviorDetected = $false
        try {
            $result = Invoke-Behavior $mutated $taskBase ('mutation' + $mutationIndex)
            if ($result.ExitCode -ne 0) { $behaviorDetected = $true }
        } catch { $behaviorDetected = $true }
        # Le mutazioni semantiche devono essere rilevate dal banco comportamentale da sole; quelle sul sorgente dai controlli statici.
        $needsBehavior = $name -notin @('MUTATION_FALLBACK_RESTORED', 'MUTATION_OWNER_WRITTEN_TO_SESSION')
        if ($needsBehavior -and -not $behaviorDetected) { throw ($name + '_NOT_DETECTED_BY_BEHAVIOR_HARNESS') }
        if (-not $staticDetected -and -not $behaviorDetected) { throw ($name + '_NOT_DETECTED') }
        $mutationPassed++
        Write-Output ('PASS ' + $name + '_DETECTED static=' + $staticDetected + ' behavior=' + $behaviorDetected)
    }
} finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTemp).TrimEnd('\')
    if (-not $taskResolved.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolved) -notmatch '^ks-address-owner-[0-9a-f]{32}$') { throw 'ADDRESS_UNSAFE_TEMP_CLEANUP' }
    if (Test-Path -LiteralPath $taskResolved) { Remove-Item -LiteralPath $taskResolved -Recurse -Force }
}
Write-Output ('ADDRESS_OWNER_STATIC_CHECKS=' + $taskStaticCount)
Write-Output ('ADDRESS_OWNER_MUTATIONS_DETECTED=' + $mutationPassed)
Write-Output 'ADDRESS_OWNER_RESULT=PASS;DATABASE_ACCESSES=0;ENGINE=SQLITE_SYNTHETIC'
