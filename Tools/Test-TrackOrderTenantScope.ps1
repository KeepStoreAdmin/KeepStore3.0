[CmdletBinding()]
param([string]$BaselineRef = 'fe34148a27339f54a53664e941bd589bd46be050')

# KS-C02-TRACK-ORDER-TENANT-SCOPE-1A: track-your-order.aspx cerca l'ordine solo nell'azienda della vetrina
# richiesta (host esatto url1/url2 -> una sola riga aziende) e fallisce chiuso se l'host non si risolve.
# 1) controlli sorgente contro la base; 2) esecuzione della query reale (estratta meccanicamente) su SQLite di
# sistema in memoria (winsqlite3.dll) con due aziende sintetiche che condividono il database; 3) mutazioni che
# devono far fallire il banco. Nessun MySQL, IIS, sessione ASP.NET, rete o dato reale.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFramework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$taskTemp = Join-Path $taskTempBase ('ks-track-order-tenant-' + [Guid]::NewGuid().ToString('N'))
$taskStatic = 0
function Check-Source([bool]$condition, [string]$name) {
    if (-not $condition) { throw $name }
    $script:taskStatic++
    Write-Output ('PASS ' + $name)
}
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
    if ($process.ExitCode -ne 0) { throw 'TRACK_ORDER_BASE_READ_FAILED' }
    return $text.TrimStart([char]0xFEFF).Replace("`r`n", "`n")
}
function Get-SqlExpression([string]$source) {
    $found = [regex]::Matches($source, '(?m)^[ \t]*Dim sql As String = (.+)$')
    if ($found.Count -ne 1) { throw 'TRACK_ORDER_SQL_EXPRESSION_NOT_UNIQUE' }
    return $found[0].Groups[1].Value
}
function Get-Helper([string]$source) {
    $found = [regex]::Matches($source, '(?ms)^[ \t]*Private Shared Function ResolveTrackingCompanyId\(.*?^[ \t]*End Function')
    if ($found.Count -ne 1) { throw 'TRACK_ORDER_HELPER_NOT_UNIQUE' }
    return $found[0].Value
}
function Replace-Once([string]$text, [string]$old, [string]$new) {
    if (-not $text.Contains($old)) { throw 'MUTATION_NOT_APPLICABLE' }
    return $text.Replace($old, $new)
}

$taskPage = Read-Source 'track-your-order.aspx.vb'
$taskBase = Read-Base 'track-your-order.aspx.vb'
$taskSql = Get-SqlExpression $taskPage
$taskSqlBase = Get-SqlExpression $taskBase
$taskHelper = Get-Helper $taskPage

# --- Diff limitato: ripristinando i quattro inserimenti il candidato torna identico alla base ---
$taskReverted = $taskPage
$taskReverted = [regex]::Replace($taskReverted, '(?ms)^[ \t]*'' Azienda della vetrina:.*?^[ \t]*End Function\n\n', '')
$taskReverted = [regex]::Replace($taskReverted, '(?ms)^[ \t]*'' L''ordine si cerca solo.*?^[ \t]*End If\n\n', '')
$taskReverted = [regex]::Replace($taskReverted, '(?m)^[ \t]*cmd\.Parameters\.Add\("@aziendaId".*\n', '')
$taskReverted = $taskReverted.Replace('"AND vdocumenti.AziendeId = @aziendaId" & vbCrLf & "AND utenti.AziendeId = @aziendaId" & vbCrLf & ', '')
Check-Source ($taskReverted -ceq $taskBase) 'ONLY_TENANT_SCOPE_BLOCKS_CHANGED'
Check-Source ($taskPage -cne $taskBase) 'PAGE_ACTUALLY_CHANGED'

# --- Difetto della base ---
Check-Source ($taskBase -notmatch '(?i)AziendeId|AziendaId|StorefrontSeoTenantContext') 'BASELINE_HAS_NO_TENANT_SCOPE'
Check-Source ($taskSqlBase.Contains('"AND LOWER(utenti.Email) = LOWER(@email)"') -and $taskSqlBase.Contains('"AND vdocumenti.NDocumento = @n"')) 'BASELINE_LOOKUP_BY_NUMBER_AND_EMAIL_ONLY'

# --- Candidato: query ---
Check-Source (([regex]::Matches($taskSql, '"AND vdocumenti\.AziendeId = @aziendaId"')).Count -eq 1) 'SQL_FILTERS_DOCUMENT_COMPANY'
Check-Source (([regex]::Matches($taskSql, '"AND utenti\.AziendeId = @aziendaId"')).Count -eq 1) 'SQL_FILTERS_CUSTOMER_COMPANY'
Check-Source (([regex]::Matches($taskSql, '@aziendaId')).Count -eq 2) 'SQL_COMPANY_PARAMETER_USED_TWICE_ONLY'
Check-Source ($taskSql.Contains('"WHERE vdocumenti.TipoDocumentiId = 4"') -and $taskSql.Contains('"ORDER BY vdocumenti.ID DESC"')) 'SQL_ORDER_TYPE_AND_ORDERING_UNCHANGED'
Check-Source ($taskPage.Contains('cmd.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = companyId')) 'COMPANY_PARAMETER_IS_TYPED_INT32'
Check-Source ($taskPage -notmatch 'AddWithValue') 'NO_ADDWITHVALUE'
Check-Source ($taskPage.Contains('cmd.Parameters.Add("@n", MySqlDbType.VarChar).Value = rawN') -and $taskPage.Contains('cmd.Parameters.Add("@email", MySqlDbType.VarChar).Value = email')) 'EXISTING_PARAMETERS_UNCHANGED'

# --- Candidato: risoluzione e fail-closed ---
$resolveCall = 'ResolveTrackingCompanyId(StorefrontSeoTenantContext.Resolve(Context))'
Check-Source (([regex]::Matches($taskPage, [regex]::Escape($resolveCall))).Count -eq 1) 'TENANT_FROM_HOST_RESOLVER_ONLY'
Check-Source ($taskPage -notmatch 'Session\(|Request\.(Form|QueryString|Params)|Request\(|Cookies') 'COMPANY_NEVER_FROM_SESSION_OR_CLIENT'
$idxResolve = $taskPage.IndexOf($resolveCall, [StringComparison]::Ordinal)
$idxGuard = $taskPage.IndexOf('If companyId <= 0 Then', [StringComparison]::Ordinal)
$idxConnection = $taskPage.IndexOf('New MySqlConnection', [StringComparison]::Ordinal)
$idxConfig = $taskPage.IndexOf('ConfigurationManager.ConnectionStrings', [StringComparison]::Ordinal)
Check-Source ($idxResolve -gt 0 -and $idxResolve -lt $idxGuard -and $idxGuard -lt $idxConfig -and $idxGuard -lt $idxConnection) 'FAIL_CLOSED_BEFORE_ANY_DATABASE_ACCESS'
$guardBlock = $taskPage.Substring($idxGuard, $idxConfig - $idxGuard)
Check-Source ($guardBlock.Contains('ShowMsg(') -and $guardBlock.Contains('Return') -and $guardBlock.Contains('End If')) 'GUARD_SHOWS_MESSAGE_AND_RETURNS'
Check-Source ($taskHelper -notmatch 'Session\(|HttpContext|MySql|Cache|Request|Response|Cookies|Resolve\(') 'HELPER_IS_PURE_NO_SESSION_DB_OR_HTTP'
Check-Source ($taskHelper.Contains('If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return 0') -and $taskHelper.Contains('Return tenant.CompanyId')) 'HELPER_RETURNS_ONLY_POSITIVE_RESOLVED_COMPANY'

# --- Messaggi, uscita e dipendenze invariati ---
$taskTechnical = 'ShowMsg("Errore durante la ricerca dell''ordine. Riprova pi' + [char]0x00F9 + ' tardi.")'
Check-Source ($taskPage.Contains('ShowMsg("Nessun ordine trovato con questi dati. Verifica numero ordine ed email.")') -and (([regex]::Matches($taskPage, [regex]::Escape($taskTechnical))).Count -eq 2) -and (([regex]::Matches($taskBase, [regex]::Escape($taskTechnical))).Count -eq 1)) 'NOT_FOUND_AND_TECHNICAL_MESSAGES_PRESENT'
Check-Source ($taskPage.Contains('hlDetail.NavigateUrl = "documentidettaglio.aspx?id=" & id.ToString()')) 'DETAIL_LINK_UNCHANGED'
Check-Source ($taskPage -notmatch '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind)\b') 'NO_CLIENT_LITERALS'
foreach ($path in @('track-your-order.aspx', 'App_Code/StorefrontSeoTenantContext.vb', 'App_Code/StorefrontCanonicalHostPolicy.vb', 'documentidettaglio.aspx.vb', 'Page.master.vb', 'Page.master')) {
    Check-Source ((Read-Source $path) -ceq (Read-Base $path)) ('UNCHANGED_' + [IO.Path]::GetFileName($path))
}
Check-Source ((Read-Source 'documentidettaglio.aspx.vb').Contains('WHERE d.id=@id AND d.UtentiId=@uid AND d.AziendeId=@aziendaId')) 'DETAIL_PAGE_STILL_OWNER_AND_COMPANY_SCOPED'

if (-not (Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32\winsqlite3.dll'))) { throw 'WINSQLITE3_UNAVAILABLE' }

function Invoke-Behavior([string]$candidateText, [string]$label) {
    $directory = Join-Path $taskTemp $label
    New-Item -ItemType Directory -Path $directory | Out-Null
    $candidateExpression = Get-SqlExpression $candidateText
    $candidateHelper = (Get-Helper $candidateText).Replace('Private Shared Function', 'Public Shared Function')
    $baseExpression = $taskSqlBase
    $fixture = "Option Strict On`nOption Explicit On`nImports System`n" +
        "Public NotInheritable Class SqlCandidate`n    Public Shared Function Text() As String`n        Return $candidateExpression`n    End Function`nEnd Class`n" +
        "Public NotInheritable Class SqlBaseline`n    Public Shared Function Text() As String`n        Return $baseExpression`n    End Function`nEnd Class`n" +
        "Public NotInheritable Class TrackResolverFixture`n$candidateHelper`nEnd Class`n"
    $fixturePath = Join-Path $directory 'ExtractedTrackOrder.vb'
    [IO.File]::WriteAllText($fixturePath, $fixture)
    $executable = Join-Path $directory 'TrackOrderTenantScopeHarness.exe'
    $references = @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { Join-Path $taskFramework $_ }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $compileOutput = & (Join-Path $taskFramework 'vbc.exe') /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$executable" ('/reference:' + ($references -join ',')) $fixturePath (Join-Path $taskRoot 'App_Code\StorefrontCanonicalHostPolicy.vb') (Join-Path $PSScriptRoot 'TrackOrderTenantScopeHarness.vb') 2>&1
        $compileExit = $LASTEXITCODE
        if ($compileExit -ne 0) { throw ('TRACK_ORDER_HARNESS_COMPILE_FAILED ' + (($compileOutput | ForEach-Object { "$_" }) -join ' ')) }
        $runOutput = & $executable 2>&1
        $runExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return @{ ExitCode = $runExit; Output = (($runOutput | ForEach-Object { "$_" }) -join "`n") }
}

New-Item -ItemType Directory -Path $taskTemp | Out-Null
try {
    $main = Invoke-Behavior $taskPage 'candidate'
    Write-Output $main.Output
    if ($main.ExitCode -ne 0) { throw 'TRACK_ORDER_HARNESS_FAILED' }

    # Mutazioni: il banco deve fallire se la barriera azienda viene tolta o indebolita.
    $mutations = [ordered]@{
        'MUTATION_REMOVE_DOCUMENT_COMPANY_PREDICATE' = { param($t) Replace-Once $t '"AND vdocumenti.AziendeId = @aziendaId" & vbCrLf & ' '' }
        'MUTATION_REMOVE_CUSTOMER_COMPANY_PREDICATE' = { param($t) Replace-Once $t '"AND utenti.AziendeId = @aziendaId" & vbCrLf & ' '' }
        'MUTATION_HELPER_FALLBACK_TO_FIRST_COMPANY' = { param($t) Replace-Once $t 'If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return 0' 'If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return 1' }
        'MUTATION_HELPER_ACCEPTS_NON_POSITIVE_COMPANY' = { param($t) Replace-Once $t 'If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return 0' 'If tenant Is Nothing Then Return 0' }
    }
    $mutationIndex = 0
    foreach ($name in $mutations.Keys) {
        $mutationIndex++
        $mutated = & $mutations[$name] $taskPage
        $result = Invoke-Behavior $mutated ('mutation' + $mutationIndex)
        Check-Source ($result.ExitCode -ne 0) ($name + '_DETECTED')
    }
} finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTemp).TrimEnd('\')
    if (-not $taskResolved.StartsWith($taskTempBase + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $taskResolved) -notmatch '^ks-track-order-tenant-[0-9a-f]{32}$') { throw 'TRACK_ORDER_UNSAFE_TEMP_CLEANUP' }
    if (Test-Path -LiteralPath $taskResolved) { Remove-Item -LiteralPath $taskResolved -Recurse -Force }
}
Write-Output ('TRACK_ORDER_TENANT_STATIC_CHECKS=' + $taskStatic)
Write-Output 'TRACK_ORDER_TENANT_RESULT=PASS;DATABASE_ACCESSES=0;ENGINE=SQLITE_SYNTHETIC'
