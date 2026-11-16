[CmdletBinding()]
param([switch]$SkipLive, [string]$Host1 = 'www.taikun.it', [int]$Port = 8443)

# KS-A04-HOME-BODY-CLASS-1A - il server scrive nel <body> della HOME le classi `ks-page-home` e `ks-home-main`.
# Difetto riprodotto: nell'HTML servito il body NON le aveva (le aggiungeva solo il JavaScript a pagina caricata), cosi gli stili `body.ks-page-home ...`
# (larghezza del contenitore, altezza del hero da 410 px) scattavano dopo il primo disegno e la HOME si spostava (layout shift a freddo, hero 327 -> 410 px).
# Causa: `Convert.ToString(body.Attributes("class"))` con un argomento String restituisce Nothing quando l'attributo non c'e ancora (il body del master non ha
# `class` finche il master non esegue ApplyThemeTagging, DOPO il Page_Load della pagina); `current.IndexOf(...)` lanciava NullReferenceException e il `Catch` vuoto
# la nascondeva: MarkBodyAsHome non ha mai scritto nulla.
# Oracolo 1 (regione BodyClassPure di Default.aspx.vb compilata in memoria): l'aggiunta di una classe e a prova di Nothing, confronta per token (non per sottostringa:
# `ks-home-main-hero` non e `ks-home-main`), senza maiuscole, e non duplica. Oracolo 2 (testo): MarkBodyAsHome usa la funzione per entrambe le classi e non chiama IndexOf
# sull'attributo grezzo. Oracolo 3 (Smoke reale, sola lettura): l'HTML servito per la HOME ha le due classi e conserva quelle del master; una pagina che non e la HOME no.
# Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$vb = Read-Repo 'Default.aspx.vb'

# --- Oracolo 1: la regione pura, compilata ---------------------------------------------------------------------------------------------------
function Get-Region([string]$text) {
    $m = [regex]::Match($text, '(?ms)^[ \t]*#Region "BodyClassPure"\n(.*?)\n[ \t]*#End Region')
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}
function Compile-Region([string]$region) {
    if ($null -eq $region) { return $null }
    $code = "Imports System`nImports Microsoft.VisualBasic`nPublic Class BodyClassProbe`n" + $region + "`nEnd Class`n"
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.TreatWarningsAsErrors = $false
    @('System.dll', 'System.Core.dll', 'Microsoft.VisualBasic.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($code))
    if ($c.Errors.HasErrors) { throw ('COMPILE_FAILED ' + (($c.Errors | ForEach-Object { $_.ErrorText }) -join ' | ')) }
    return $c.CompiledAssembly.GetType('BodyClassProbe')
}
function Invoke-Append($type, $current, $token) {
    $flags = [Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::NonPublic
    $m = $type.GetMethod('AppendBodyClass', $flags)
    if ($null -eq $m) { throw 'AppendBodyClass_NOT_FOUND' }
    return $m.Invoke($null, @($current, $token))
}
# Tutti i casi con risposta attesa; ogni caso negativo ha il suo positivo (stessa funzione, dati vicini).
function Test-AppendCases($type) {
    $cases = @(
        @{ n = 'null_current';          cur = $null;                              tok = 'ks-page-home'; exp = 'ks-page-home' },
        @{ n = 'empty_current';         cur = '';                                 tok = 'ks-page-home'; exp = 'ks-page-home' },
        @{ n = 'blank_current';         cur = '   ';                              tok = 'ks-page-home'; exp = 'ks-page-home' },
        @{ n = 'keeps_existing';        cur = 'preload-wrapper popup-loader';     tok = 'ks-page-home'; exp = 'preload-wrapper popup-loader ks-page-home' },
        @{ n = 'idempotent';            cur = 'a ks-page-home b';                 tok = 'ks-page-home'; exp = 'a ks-page-home b' },
        @{ n = 'case_insensitive';      cur = 'a KS-PAGE-HOME';                   tok = 'ks-page-home'; exp = 'a KS-PAGE-HOME' },
        @{ n = 'tab_separator';         cur = "a`tks-page-home";                  tok = 'ks-page-home'; exp = "a`tks-page-home" },
        @{ n = 'token_not_substring';   cur = 'ks-home-main-hero';                tok = 'ks-home-main'; exp = 'ks-home-main-hero ks-home-main' },
        @{ n = 'token_is_whole_word';   cur = 'x ks-home-main';                   tok = 'ks-home-main'; exp = 'x ks-home-main' },
        @{ n = 'prefix_is_not_token';   cur = 'my-ks-page-home';                  tok = 'ks-page-home'; exp = 'my-ks-page-home ks-page-home' },
        @{ n = 'token_spaces_present';  cur = 'a ks-page-home';                   tok = ' ks-page-home '; exp = 'a ks-page-home' },
        @{ n = 'token_spaces_absent';   cur = 'a';                                tok = ' ks-page-home '; exp = 'a ks-page-home' },
        @{ n = 'null_token';            cur = ' a b ';                            tok = $null;          exp = 'a b' },
        @{ n = 'blank_token';           cur = 'a';                                tok = '  ';           exp = 'a' }
    )
    foreach ($c in $cases) {
        $got = Invoke-Append $type $c.cur $c.tok
        if (-not ($got -ceq $c.exp)) { return ('CASE_FAILED ' + $c.n + ' got=[' + $got + '] expected=[' + $c.exp + ']') }
    }
    $chain = Invoke-Append $type (Invoke-Append $type $null 'ks-page-home') 'ks-home-main'
    if (-not ($chain -ceq 'ks-page-home ks-home-main')) { return ('CASE_FAILED chain got=[' + $chain + ']') }
    return 'OK'
}
function Test-Region([string]$text) {
    $region = Get-Region $text
    if ($null -eq $region) { return 'REGION_MISSING' }
    try { $type = Compile-Region $region } catch { return [string]$_.Exception.Message }
    try { return (Test-AppendCases $type) } catch { return ('EXCEPTION ' + $_.Exception.GetBaseException().GetType().Name) }
}

$r = Test-Region $vb
Assert-Source ($r -ceq 'OK') ('BODYCLASS_PURE_REGION_CASES_' + $r)

# --- Oracolo 2: il collegamento nel codice reale ---------------------------------------------------------------------------------------------
function Get-MarkBody([string]$text) {
    $m = [regex]::Match($text, '(?ms)Private Sub MarkBodyAsHome\(\)\n(.*?)\n[ \t]*End Sub')
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}
function Test-Wiring([string]$text) {
    $body = Get-MarkBody $text
    if ($null -eq $body) { return $false }
    if ($body -notmatch 'AppendBodyClass\([^\n]*"ks-page-home"') { return $false }
    if ($body -notmatch 'AppendBodyClass\([^\n]*"ks-home-main"') { return $false }
    if ($body -notmatch 'Master\.FindControl\("PageBody"\)') { return $false }
    # nessuna lettura grezza dell'attributo seguita da IndexOf: e proprio il difetto
    if ($body -match '\.IndexOf\(') { return $false }
    if ($body -match 'Convert\.ToString\(body\.Attributes\("class"\)\)') { return $false }
    return $true
}
Assert-Source (Test-Wiring $vb) 'MARKBODYASHOME_USES_NULL_SAFE_HELPER'
Assert-Source ($vb -cmatch 'MarkBodyAsHome\(\)\r?\n') 'MARKBODYASHOME_STILL_CALLED_IN_PAGE_LOAD'

# --- Mutazioni (copie in memoria) ------------------------------------------------------------------------------------------------------------
# M1: il confronto torna ad accettare una sottostringa invece del token
$m1 = Mutate-Text $vb 'If String.Equals(part, token.Trim(), StringComparison.OrdinalIgnoreCase) Then Return existing' 'If part.IndexOf(token.Trim(), StringComparison.OrdinalIgnoreCase) >= 0 Then Return existing' 'M1_SUBSTRING_MATCH'
Assert-Detected ((Test-Region $m1) -ceq 'OK') 'M1_SUBSTRING_MATCH'
# M2: il confronto diventa sensibile alle maiuscole
$m2 = Mutate-Text $vb 'If String.Equals(part, token.Trim(), StringComparison.OrdinalIgnoreCase) Then Return existing' 'If String.Equals(part, token.Trim(), StringComparison.Ordinal) Then Return existing' 'M2_CASE_SENSITIVE'
Assert-Detected ((Test-Region $m2) -ceq 'OK') 'M2_CASE_SENSITIVE'
# M3: la funzione non e piu a prova di Nothing (il difetto originale)
$m3 = Mutate-Text $vb 'Dim existing As String = If(current, String.Empty).Trim()' 'Dim existing As String = current.Trim()' 'M3_NULL_UNSAFE'
Assert-Detected ((Test-Region $m3) -ceq 'OK') 'M3_NULL_UNSAFE'
# M4: la classe viene aggiunta anche se c'e gia (niente idempotenza)
$m4 = Mutate-Text $vb 'If String.Equals(part, token.Trim(), StringComparison.OrdinalIgnoreCase) Then Return existing' 'If False Then Return existing' 'M4_NOT_IDEMPOTENT'
Assert-Detected ((Test-Region $m4) -ceq 'OK') 'M4_NOT_IDEMPOTENT'
# M5: la separazione ignora le tabulazioni
$m5 = Mutate-Text $vb 'New Char() {" "c, ControlChars.Tab, ControlChars.Cr, ControlChars.Lf}' 'New Char() {" "c}' 'M5_ONLY_SPACE_SEPARATOR'
Assert-Detected ((Test-Region $m5) -ceq 'OK') 'M5_ONLY_SPACE_SEPARATOR'
# M6: un token vuoto aggiunge uno spazio o una classe vuota
$m6 = Mutate-Text $vb 'If String.IsNullOrWhiteSpace(token) Then Return existing' 'If token Is Nothing Then Return existing' 'M6_BLANK_TOKEN_ADDED'
Assert-Detected ((Test-Region $m6) -ceq 'OK') 'M6_BLANK_TOKEN_ADDED'
# M9: il confronto usa il token senza ripulirlo dagli spazi (una classe con spazi attorno verrebbe aggiunta due volte)
$m9 = Mutate-Text $vb 'If String.Equals(part, token.Trim(), StringComparison.OrdinalIgnoreCase) Then Return existing' 'If String.Equals(part, token, StringComparison.OrdinalIgnoreCase) Then Return existing' 'M9_UNTRIMMED_TOKEN'
Assert-Detected ((Test-Region $m9) -ceq 'OK') 'M9_UNTRIMMED_TOKEN'
# M7: MarkBodyAsHome torna alla lettura grezza (il difetto originale, nel collegamento)
$m7 = Mutate-Text $vb 'body.Attributes("class") = AppendBodyClass(AppendBodyClass(body.Attributes("class"), "ks-page-home"), "ks-home-main")' 'Dim current = Convert.ToString(body.Attributes("class")) : If current.IndexOf("ks-page-home", StringComparison.OrdinalIgnoreCase) < 0 Then body.Attributes("class") = (current & " ks-page-home").Trim()' 'M7_RAW_ATTRIBUTE'
Assert-Detected (Test-Wiring $m7) 'M7_RAW_ATTRIBUTE'
# M8: manca una delle due classi nel collegamento
$m8 = Mutate-Text $vb 'AppendBodyClass(AppendBodyClass(body.Attributes("class"), "ks-page-home"), "ks-home-main")' 'AppendBodyClass(body.Attributes("class"), "ks-page-home")' 'M8_MISSING_HOME_MAIN'
Assert-Detected (Test-Wiring $m8) 'M8_MISSING_HOME_MAIN'

# --- Oracolo 3: l'HTML realmente servito da Smoke (sola lettura) -----------------------------------------------------------------------------
function Get-BodyClasses([string]$path) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        $url = 'https://' + $Host1 + ':' + $Port + $path
        $args1 = @('--noproxy', '*', '--resolve', ($Host1 + ':' + $Port + ':127.0.0.1'), '-s', '--max-time', '170', '-o', $tmp, '-w', '%{http_code}', $url)
        $code = (& curl.exe @args1)
        if ($LASTEXITCODE -ne 0 -or $code -ne '200') { return @{ ok = $false; why = ('HTTP_' + $code + '_EXIT_' + $LASTEXITCODE); tokens = @() } }
        $html = [IO.File]::ReadAllText($tmp)
        $m = [regex]::Match($html, '<body\b[^>]*>')
        if (-not $m.Success) { return @{ ok = $false; why = 'NO_BODY_TAG'; tokens = @() } }
        $c = [regex]::Match($m.Value, '\sclass="([^"]*)"')
        if (-not $c.Success) { return @{ ok = $true; why = ''; tokens = @() } }
        return @{ ok = $true; why = ''; tokens = @($c.Groups[1].Value -split '\s+' | Where-Object { $_ -ne '' }) }
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
if ($SkipLive) {
    Write-Output 'NOT_EXECUTED live Smoke check (parametro -SkipLive)'
} else {
    $home1 = Get-BodyClasses '/Default.aspx'
    Assert-Source ($home1.ok) ('LIVE_HOME_FETCHED_' + $home1.why)
    Assert-Source (($home1.tokens -ccontains 'ks-page-home') -and ($home1.tokens -ccontains 'ks-home-main')) 'LIVE_HOME_BODY_HAS_ks-page-home_AND_ks-home-main_FROM_SERVER'
    # le classi del master restano (il merge del master non deve perderle)
    Assert-Source (($home1.tokens -ccontains 'preload-wrapper') -and ($home1.tokens -ccontains 'ks-theme-keepstore')) 'LIVE_HOME_BODY_KEEPS_MASTER_CLASSES'
    Assert-Source ((@($home1.tokens | Where-Object { $_ -ceq 'ks-page-home' }).Count) -eq 1) 'LIVE_HOME_BODY_NO_DUPLICATE_ks-page-home'
    # negativo: una pagina che non e la HOME non riceve le classi della HOME
    $other = Get-BodyClasses '/faq.aspx'
    Assert-Source ($other.ok) ('LIVE_OTHER_PAGE_FETCHED_' + $other.why)
    Assert-Source ((-not ($other.tokens -ccontains 'ks-page-home')) -and (-not ($other.tokens -ccontains 'ks-home-main'))) 'LIVE_OTHER_PAGE_BODY_HAS_NO_HOME_CLASSES'
    Assert-Source ($other.tokens -ccontains 'ks-theme-keepstore') 'LIVE_OTHER_PAGE_BODY_STILL_HAS_MASTER_CLASSES'
}
Write-Output 'RESULT: ALL PASS'
