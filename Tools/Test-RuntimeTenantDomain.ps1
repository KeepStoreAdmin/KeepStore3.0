[CmdletBinding()]
param()

# KS-STD-RUNTIME-TENANT-DOMAIN-1A - il codice condiviso non contiene il dominio di un cliente.
# 1) controllo statico dei file runtime tracciati + struttura delle correzioni, con mutazioni;
# 2) harness comportamentale compilato col template e-mail REALE, con due mutazioni sul template.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$templatePath = Join-Path $repoRoot 'App_Code\KeepStoreEmailTemplate.vb'
$harnessPath = Join-Path $PSScriptRoot 'EmailTemplateTenantDomainHarness.vb'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KeepStoreTenantDomain-' + [Guid]::NewGuid().ToString('N'))
$customerDomain = 'taikun' + '.it'

function Read-Repo([string]$relativePath) {
    $full = Join-Path $repoRoot $relativePath
    if (Test-Path -LiteralPath $full) { return [IO.File]::ReadAllText($full) }
    # file tracciato cancellato in locale (eccezione protetta): si legge la versione del commit
    $blob = @(& git -C $repoRoot show ('HEAD:' + $relativePath.Replace('\', '/')))
    if ($LASTEXITCODE -ne 0) { throw ('FILE_NOT_AVAILABLE=' + $relativePath) }
    return ($blob -join "`n")
}

function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}

# Funzioni di controllo (usate sia sul sorgente reale sia sulle versioni mutate).
function Test-NoCustomerDomain([string]$text) { return -not ($text -match ('(?i)' + [regex]::Escape($customerDomain))) }
function Test-LogoBaseFailsClosed([string]$text) {
    $m = [regex]::Match($text, '(?s)Private Shared Function CombineHttpsBaseUrl\(.*?End Function')
    if (-not $m.Success) { return $false }
    return ($m.Value -match 'Return ""|Return String\.Empty') -and ($m.Value -notmatch '"https?://www\.')
}
function Test-RendererOmitsEmptyLogo([string]$text) {
    return $text -match 'If Not String\.IsNullOrWhiteSpace\(logoPath\) Then'
}
function Test-UsesTenantResolver([string]$text) {
    $m = [regex]::Match($text, '(?s)Private Function BuildSiteHomeUrl\(\) As String.*?End Function')
    return $m.Success -and ($m.Value -match 'StorefrontSeoTenantContext\.BuildCanonicalUrl\(HttpContext\.Current, "/"\)')
}
function Test-IcecatTenantImages([string]$text) {
    # L'HTML e esportato nell'XML (descrizione_html): URL assoluto della vetrina risolta, mai un dominio scritto
    # nel codice ne un percorso relativo alla radice; nessuna catena di Replace sul testo gia sostituito.
    return ($text -match 'StorefrontSeoTenantContext\.BuildCanonicalUrl\(HttpContext\.Current, "/Images/icecat/"') -and
           ([regex]::Matches($text, 'IcecatFlagMarkup\(')).Count -ge 3 -and
           -not ($text -match 'src=""(https?:)?/') -and
           -not ($text -match '\.Replace\("Y"')
}
function Get-IcecatHelperText([string]$text) {
    $m = [regex]::Match($text, '(?s)Private Function IcecatFlagMarkup\(.*?End Function')
    if (-not $m.Success) { throw 'ICECAT_HELPER_NOT_FOUND' }
    return $m.Value.Replace('Private Function', 'Public Shared Function')
}
function New-IcecatHostFile([string]$helperText, [string]$path) {
    $src = @(
        'Option Strict On', 'Option Explicit On', 'Imports System', 'Imports System.Web', '',
        'Public Class StorefrontSeoTenantContext',
        '    Public Shared StubBase As String = ""',
        '    Public Shared Function BuildCanonicalUrl(ByVal context As HttpContext, ByVal relativePathAndQuery As String) As String',
        '        If StubBase = "" Then Return ""',
        '        Return StubBase.TrimEnd("/"c) & relativePathAndQuery',
        '    End Function',
        'End Class', '',
        'Public Class IcecatFlagMarkupHost',
        $helperText,
        'End Class') -join "`r`n"
    [IO.File]::WriteAllText($path, $src)
}

function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

function Mutate-Regex([string]$text, [string]$pattern, [string]$replacement, [string]$code) {
    $out = [regex]::Replace($text, $pattern, $replacement)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}

function Assert-Detects([string]$code, [bool]$checkResultOnMutation) {
    if ($checkResultOnMutation) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

foreach ($required in @($compiler, $templatePath, $harnessPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw ('REQUIRED_FILE_MISSING=' + $required) }
}

# ---- 1) controllo statico ----------------------------------------------------
$tracked = @(& git -C $repoRoot ls-files -- '*.vb' '*.aspx' '*.ascx' '*.master' '*.js' '*.css' '*.config' '*.asax' '*.ashx' '*.html' 2>$null) |
    Where-Object { $_ -notmatch '^(docs|Tools|Tests|Database Taikun|\.github|\.vs)/' }
Assert-Source ($tracked.Count -gt 100) 'S00_RUNTIME_FILE_LIST_NOT_EMPTY'

$offenders = @()
foreach ($rel in $tracked) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }   # cancellazione locale protetta: non e un file runtime attivo
    if (-not (Test-NoCustomerDomain ([IO.File]::ReadAllText($full)))) { $offenders += $rel }
}
Assert-Source ($offenders.Count -eq 0) ('S01_NO_CUSTOMER_DOMAIN_IN_RUNTIME_FILES ' + ($offenders -join ','))

$template = Read-Repo 'App_Code\KeepStoreEmailTemplate.vb'
$main = Read-Repo 'main.aspx.vb'
$registration = Read-Repo 'registrazione.aspx.vb'
$icecat = Read-Repo 'icecat_consult.aspx.vb'

Assert-Source (Test-LogoBaseFailsClosed $template) 'S02_EMAIL_LOGO_BASE_FAILS_CLOSED'
Assert-Source (Test-RendererOmitsEmptyLogo $template) 'S03_EMAIL_RENDERER_OMITS_EMPTY_LOGO'
Assert-Source (Test-UsesTenantResolver $main) 'S04_LEGACY_CONTACT_FALLBACK_IS_TENANT_RESOLVER'
Assert-Source (Test-UsesTenantResolver $registration) 'S05_REGISTRATION_FALLBACK_IS_TENANT_RESOLVER'
Assert-Source (Test-IcecatTenantImages $icecat) 'S06_ICECAT_IMAGES_FROM_RESOLVED_TENANT_ABSOLUTE'
Assert-Source ((Get-IcecatHelperText $icecat) -match 'If imageUrl = "" Then') 'S06C_ICECAT_EMPTY_URL_KEEPS_TEXT'
Assert-Source ([regex]::Match($main, '(?s)Private Function BuildSiteHomeUrl\(\) As String.*?End Function').Value -match 'StartsWith\("//"') 'S06D_MAIN_REJECTS_UNSAFE_PREFIXES'
Assert-Source (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'test.aspx.vb'))) 'S07_DEAD_TEST_CODE_BEHIND_REMOVED'
Assert-Source ((Read-Repo 'test.aspx') -notmatch 'CodeFile|Inherits') 'S08_TEST_PAGE_STILL_NOT_WIRED_TO_CODE'

# Mutazioni statiche: ognuna deve essere rilevata dal controllo corrispondente.
Assert-Detects 'M1_LITERAL_IN_MAIN' (Test-NoCustomerDomain ($main + "`n' https://www." + $customerDomain))
$fallbackPattern = '(?s)(Private Shared Function CombineHttpsBaseUrl\(.*?If baseUrl = "" Then\s*\r?\n\s*)Return [^\r\n]+'
$fallbackText = '$1baseUrl = "https://www.' + $customerDomain + '"'
Assert-Detects 'M2_LOGO_FALLBACK_RESTORED' (Test-LogoBaseFailsClosed (Mutate-Regex $template $fallbackPattern $fallbackText 'M2'))
Assert-Detects 'M3_RESOLVER_REMOVED_FROM_REGISTRATION' (Test-UsesTenantResolver (Mutate-Text $registration 'StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/")' '"https://shop.example.test/"' 'M3'))
Assert-Detects 'M4_ICECAT_FIXED_DOMAIN' (Test-IcecatTenantImages (Mutate-Text $icecat 'StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/Images/icecat/"' '"https://shop.example.test/Images/icecat/"' 'M4'))
Assert-Detects 'M5_RENDERER_GUARD_REMOVED' (Test-RendererOmitsEmptyLogo (Mutate-Text $template 'If Not String.IsNullOrWhiteSpace(logoPath) Then' 'If True Then' 'M5'))

# ---- 2) harness comportamentale sul template reale ---------------------------
function Invoke-Harness([string]$templateFile, [string]$hostFile, [string]$name) {
    $exe = Join-Path $tempRoot ($name + '.exe')
    & $compiler /nologo /optionstrict+ /optionexplicit+ /target:exe "/out:$exe" /reference:System.dll /reference:System.Web.dll $templateFile $hostFile $harnessPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw ('HARNESS_COMPILE_FAILED=' + $name) }
    $lines = @(& $exe)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $lines }
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $helperText = Get-IcecatHelperText $icecat
    $hostReal = Join-Path $tempRoot 'icecat-host-real.vb'
    New-IcecatHostFile $helperText $hostReal
    $real = Invoke-Harness $templatePath $hostReal 'real'
    $real.Output | ForEach-Object { Write-Output $_ }
    if ($real.ExitCode -ne 0) { throw 'HARNESS_FAILED_ON_REAL_TEMPLATE' }

    # Mutazione comportamentale 1: ripiego su un dominio fisso rimesso nel template.
    $m1 = Join-Path $tempRoot 'mut1.vb'
    [IO.File]::WriteAllText($m1, (Mutate-Regex $template $fallbackPattern $fallbackText 'B1'))
    $r1 = Invoke-Harness $m1 $hostReal 'mut1'
    if ($r1.ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B1_BEHAVIOR_DOMAIN_FALLBACK' }
    Write-Output 'PASS MUTATION_DETECTED B1_BEHAVIOR_DOMAIN_FALLBACK'

    # Mutazione comportamentale 2: il renderer emette sempre l'immagine, anche con URL vuoto.
    $m2 = Join-Path $tempRoot 'mut2.vb'
    [IO.File]::WriteAllText($m2, (Mutate-Text $template 'If Not String.IsNullOrWhiteSpace(logoPath) Then' 'If True Then' 'B2'))
    $r2 = Invoke-Harness $m2 $hostReal 'mut2'
    if ($r2.ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B2_BEHAVIOR_EMPTY_IMG' }
    Write-Output 'PASS MUTATION_DETECTED B2_BEHAVIOR_EMPTY_IMG'

    # Mutazione comportamentale 3: il helper Icecat emette l'immagine anche con URL vuoto.
    $hostMut = Join-Path $tempRoot 'icecat-host-mut3.vb'
    New-IcecatHostFile (Mutate-Text $helperText 'If imageUrl = "" Then' 'If False Then' 'B3') $hostMut
    $r3 = Invoke-Harness $templatePath $hostMut 'mut3'
    if ($r3.ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B3_BEHAVIOR_ICECAT_EMPTY_URL' }
    Write-Output 'PASS MUTATION_DETECTED B3_BEHAVIOR_ICECAT_EMPTY_URL'

    # Mutazione comportamentale 4: catena di Replace sul testo gia sostituito (host con trattino corrotto).
    $hostMut4 = Join-Path $tempRoot 'icecat-host-mut4.vb'
    New-IcecatHostFile (Mutate-Text $helperText 'Return markup' 'Return markup.Replace("-", "X")' 'B4') $hostMut4
    $r4 = Invoke-Harness $templatePath $hostMut4 'mut4'
    if ($r4.ExitCode -eq 0) { throw 'MUTATION_NOT_DETECTED=B4_BEHAVIOR_ICECAT_DASH_HOST' }
    Write-Output 'PASS MUTATION_DETECTED B4_BEHAVIOR_ICECAT_DASH_HOST'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemp.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'UNSAFE_TEMP_CLEANUP_PATH' }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

Write-Output 'PASS KS_STD_RUNTIME_TENANT_DOMAIN'
