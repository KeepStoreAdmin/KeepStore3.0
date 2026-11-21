[CmdletBinding()]
param()

# KS-A04-NAV-ACTIVE-1A - la voce attiva del menu principale segue la pagina corrente (prima «Home» era scritta fissa come attiva su ogni pagina).
# Oracolo COMPORTAMENTALE: i veri metodi ResolveMainNavCurrent, NavActiveClass e NavCurrentAttr di SiteHeader.ascx.vb sono compilati in memoria ed eseguiti su percorsi reali
# (Home, Offerte = articoli.aspx?inpromo=1, Contatti, pagine senza voce); poi si controlla il markup del menu (nessun active scritto a mano, aria-current, «Guida agli acquisti» mai attiva,
# menu mobile con aria-current). Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

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

$ascx = Read-Repo 'Public/ui/controls/SiteHeader.ascx'
$vb = Read-Repo 'Public/ui/controls/SiteHeader.ascx.vb'

# --- I veri metodi, estratti dal sorgente e compilati --------------------------------------------------------------------------------------
function Get-Methods([string]$vbText) {
    $names = @('ResolveMainNavCurrent', 'NavActiveClass', 'NavCurrentAttr')
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($n in $names) {
        $m = [regex]::Match($vbText, ('(?s)    Friend Shared Function ' + $n + '\(.*?\n    End Function'))
        if (-not $m.Success) { return $null }
        $out.Add($m.Value)
    }
    return ($out -join "`n`n")
}
function Compile-Nav([string]$methods) {
    $code = "Imports System`nPublic Class NavProbe`n" + $methods + "`n    Public Function Cur(ByVal p As String, ByVal q As String) As String`n        Return ResolveMainNavCurrent(p, q)`n    End Function`n    Public Function Act(ByVal c As String, ByVal k As String) As String`n        Return NavActiveClass(c, k)`n    End Function`n    Public Function Att(ByVal c As String, ByVal k As String) As String`n        Return NavCurrentAttr(c, k)`n    End Function`nEnd Class`n"
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($code))
    if ($c.Errors.HasErrors) { throw ('NAV_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('NavProbe', $true))
}
function Test-Behaviour([string]$vbText) {
    $methods = Get-Methods $vbText
    if ($null -eq $methods) { throw 'NAV_METHODS_NOT_FOUND' }
    $p = Compile-Nav $methods
    $cases = @(
        @('~/Default.aspx', '', 'home'), @('~/default.aspx', '', 'home'), @('~/DEFAULT.ASPX', '1', 'home'),
        @('~/articoli.aspx', '1', 'offers'), @('~/ARTICOLI.aspx', '1', 'offers'),
        @('~/articoli.aspx', '', ''), @('~/articoli.aspx', '0', ''), @('~/articoli.aspx', '1 ', ''), @('~/articoli.aspx', 'true', ''),
        @('~/Contattaci.aspx', '', 'contact'), @('~/contattaci.aspx', '', 'contact'),
        @('~/articolo.aspx', '1', ''), @('~/login.aspx', '', ''), @('~/carrello.aspx', '', ''), @('~/myaccount.aspx', '', ''), @('', '', ''), @($null, $null, ''))
    foreach ($c in $cases) { if ($p.Cur($c[0], $c[1]) -ne $c[2]) { return $false } }
    if ($p.Act('home', 'home') -ne ' active') { return $false }
    foreach ($pair in @(@('home', 'offers'), @('offers', 'home'), @('contact', 'home'), @('', 'home'), @('home', ''), @('', ''))) { if ($p.Act($pair[0], $pair[1]) -ne '') { return $false } }
    if ($p.Att('offers', 'offers') -ne ' aria-current="page"') { return $false }
    foreach ($pair in @(@('home', 'offers'), @('', 'home'), @('contact', ''))) { if ($p.Att($pair[0], $pair[1]) -ne '') { return $false } }
    return $true
}

# --- Markup del menu principale e del menu mobile -------------------------------------------------------------------------------------------
function Get-DesktopNav([string]$text) {
    $m = [regex]::Match($text, '(?s)<nav class="main-nav-menu">.*?</nav>')
    if ($m.Success) { return $m.Value } else { return '' }
}
function Test-Markup([string]$text) {
    $nav = Get-DesktopNav $text
    if ($nav -eq '') { return $false }
    if ([regex]::Matches($nav, '<li class="nav-item').Count -ne 4) { return $false }
    # nessuna classe active scritta a mano: solo l'espressione del server (tolte le espressioni, "active" non deve comparire)
    $plain = [regex]::Replace($nav, '<%=.*?%>', '')
    if ($plain -match '<li class="nav-item[^"]*\bactive\b') { return $false }
    if (-not ($nav.Contains('<li class="nav-item<%= MainNavActive("home") %> pst-unset"><a href="Default.aspx" class="item-link link body-md-2"<%= MainNavCurrent("home") %>><span>Home</span></a></li>') -and
              $nav.Contains('<li class="nav-item<%= MainNavActive("offers") %>"><a href="articoli.aspx?inpromo=1" class="item-link body-md-2"<%= MainNavCurrent("offers") %>><span>Offerte</span></a></li>') -and
              $nav.Contains('<li class="nav-item<%= MainNavActive("contact") %>"><a href="Contattaci.aspx" class="item-link body-md-2"<%= MainNavCurrent("contact") %>><span>Contatti</span></a></li>'))) { return $false }
    # «Guida agli acquisti» e un'ancora della HOME: non e mai la pagina corrente
    if (-not $nav.Contains('<li class="nav-item"><a href="Default.aspx#KsLocalAiSearch130" class="item-link body-md-2 ks-guide-entry">Guida agli acquisti</a></li>')) { return $false }
    # menu mobile: stesso segnale per la tecnologia assistiva
    return ($text.Contains('<li class="nav-mb-item"><a href="Default.aspx" class="mb-menu-link"<%= MainNavCurrent("home") %>><span>Home</span></a></li>') -and
            $text.Contains('<li class="nav-mb-item"><a href="articoli.aspx?inpromo=1" class="mb-menu-link"<%= MainNavCurrent("offers") %>><i class="icon-fire" aria-hidden="true"></i><span>Offerte</span></a></li>') -and
            $text.Contains('<li class="nav-mb-item"><a href="Contattaci.aspx" class="mb-menu-link"<%= MainNavCurrent("contact") %>><span>Contatti</span></a></li>'))
}
function Test-Wrappers([string]$vbText) {
    return ($vbText -match '(?s)Protected Function MainNavActive\(ByVal key As String\) As String\s+Return NavActiveClass\(MainNavKey\(\), key\)\s+End Function' -and
            $vbText -match '(?s)Protected Function MainNavCurrent\(ByVal key As String\) As String\s+Return NavCurrentAttr\(MainNavKey\(\), key\)\s+End Function' -and
            $vbText -match 'ResolveMainNavCurrent\(Request\.AppRelativeCurrentExecutionFilePath, Request\.QueryString\("inpromo"\)\)')
}

Assert-Source (Test-Behaviour $vb) 'S01_THE_REAL_RESOLVER_MARKS_HOME_OFFERS_AND_CONTACTS_ONLY_ON_THEIR_OWN_PAGES'
Assert-Source (Test-Markup $ascx) 'S02_MENU_MARKUP_HAS_NO_HARDCODED_ACTIVE_AND_SETS_ARIA_CURRENT_DESKTOP_AND_MOBILE'
Assert-Source (Test-Wrappers $vb) 'S03_WRAPPERS_READ_THE_CURRENT_PAGE_AND_THE_INPROMO_QUERY_FROM_THE_REQUEST'
Assert-Source ($ascx -notmatch '(?i)onsus' -and $vb -notmatch '(?i)onsus') 'S04_NO_TEMPLATE_NAME_IN_THE_HEADER_SOURCES'

# --- Mutazioni (copie in memoria) -----------------------------------------------------------------------------------------------------------
$m = Mutate-Text $ascx 'nav-item<%= MainNavActive("home") %> pst-unset' 'nav-item active pst-unset' 'M01'
Assert-Detected (Test-Markup $m) 'M01_HOME_ACTIVE_WRITTEN_BY_HAND_AGAIN'
$m = Mutate-Text $vb 'Return "contact"' 'Return "home"' 'M02'
Assert-Detected (Test-Behaviour $m) 'M02_CONTACT_PAGE_MARKS_HOME'
$m = Mutate-Text $vb ' AndAlso String.Equals(inPromo, "1", StringComparison.Ordinal)' '' 'M03'
Assert-Detected (Test-Behaviour $m) 'M03_CATALOG_WITHOUT_INPROMO_MARKS_OFFERS'
$m = Mutate-Text $vb '"~/Default.aspx", StringComparison.OrdinalIgnoreCase' '"~/Default.aspx", StringComparison.Ordinal' 'M04'
Assert-Detected (Test-Behaviour $m) 'M04_HOME_MATCH_BECOMES_CASE_SENSITIVE'
$m = Mutate-Text $ascx 'class="item-link link body-md-2"<%= MainNavCurrent("home") %>' 'class="item-link link body-md-2"' 'M05'
Assert-Detected (Test-Markup $m) 'M05_HOME_LINK_LOSES_ARIA_CURRENT'
$m = Mutate-Text $ascx '<li class="nav-item"><a href="Default.aspx#KsLocalAiSearch130"' '<li class="nav-item<%= MainNavActive("guide") %>"><a href="Default.aspx#KsLocalAiSearch130"' 'M06'
Assert-Detected (Test-Markup $m) 'M06_GUIDE_ANCHOR_BECOMES_CURRENT_AWARE'
$m = Mutate-Text $vb 'If Not String.IsNullOrEmpty(key) AndAlso current = key Then Return " active"' 'Return " active"' 'M07'
Assert-Detected (Test-Behaviour $m) 'M07_EVERY_ITEM_IS_ACTIVE'
$m = Mutate-Text $ascx 'class="mb-menu-link"<%= MainNavCurrent("offers") %>' 'class="mb-menu-link"' 'M08'
Assert-Detected (Test-Markup $m) 'M08_MOBILE_OFFERS_LOSES_ARIA_CURRENT'
$m = Mutate-Text $vb 'ResolveMainNavCurrent(Request.AppRelativeCurrentExecutionFilePath, Request.QueryString("inpromo"))' 'ResolveMainNavCurrent(Request.AppRelativeCurrentExecutionFilePath, String.Empty)' 'M09'
Assert-Detected (Test-Wrappers $m) 'M09_INPROMO_QUERY_IS_IGNORED'

Write-Output 'HEADER_NAV_ACTIVE_ALL_PASS'
