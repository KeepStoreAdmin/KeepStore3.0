[CmdletBinding()]
param()

# KS-A04-RETTIFICA-MAGAZZINO-1A - la pagina rettificaMagazzino.aspx (clone del catalogo con un cancello Session("GestoreId") che nessun codice imposta)
# e il suo codebehind sono stati ritirati. Controllo con mutazioni: se la pagina torna (anche con altra capitalizzazione), se un collegamento o un
# riferimento di runtime la nomina oltre alle righe ammesse, se la voce difensiva dei ritorni sparisce o se il valore predefinito del modulo di analytics
# torna a includerla (o perde le pagine che devono restare incluse), il test fallisce.
# Il valore predefinito di analytics e provato con il VERO metodo IsIncludedPath compilato in memoria; la precedenza dell'appSetting e provata sul testo.
# Non dimostra l'assenza di URL costruiti a runtime ne la risposta HTTP reale (provata a mano sul Smoke e registrata nel Masterplan).
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI. Le mutazioni lavorano sul testo in memoria, mai sulla copia di lavoro.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Configuration
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
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

# File runtime (non Tools, non documenti, non .github, non Doc storico): tracciati o nuovi non ignorati, che esistono davvero sul disco.
$runtimeExt = @('.aspx', '.ascx', '.master', '.ashx', '.asax', '.vb', '.js', '.css', '.html', '.htm', '.config', '.sitemap', '.xml', '.json', '.txt')
$allNames = @(& git -C $repoRoot ls-files -c -o --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'GIT_LS_FILES_FAILED' }
$allNames = @($allNames | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })
$runtimeNames = @($allNames | Where-Object {
        $ext = [IO.Path]::GetExtension($_).ToLowerInvariant()
        ($runtimeExt -contains $ext) -and ($_ -notmatch '^(Tools|docs|Doc|\.github|\.ai-review|Database Taikun)/') -and ($_ -notmatch '^Public/assets/images/')
    })
$texts = @{}
foreach ($n in $runtimeNames) { $texts[$n] = Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $n))) }

# Unico punto del runtime che nomina ancora la pagina: la lista difensiva dei ritorni non ammessi (la pagina non diventa mai un URL di ritorno se tornasse).
$allowedMentions = @{
    'App_Code/StorefrontReturnUrlPolicy.vb :: "rettificamagazzino.aspx",' = 1
}
$mentionPattern = '(?i)rettifica[_\- ]?magazzino'

function Test-NoFiles([string[]]$names) {
    foreach ($n in $names) {
        if ([IO.Path]::GetFileName($n) -match '(?i)^rettifica[_\- ]?magazzino') { return $false }
    }
    return $true
}
function Test-Mentions([hashtable]$fileTexts) {
    $found = @{}
    foreach ($name in $fileTexts.Keys) {
        foreach ($line in ($fileTexts[$name] -split "`n")) {
            if ($line -match $mentionPattern) {
                $key = $name + ' :: ' + $line.Trim()
                if ($found.ContainsKey($key)) { $found[$key] = $found[$key] + 1 } else { $found[$key] = 1 }
            }
        }
    }
    foreach ($k in $found.Keys) { if (-not $allowedMentions.ContainsKey($k) -or $allowedMentions[$k] -ne $found[$k]) { return $false } }
    foreach ($k in $allowedMentions.Keys) { if (-not $found.ContainsKey($k)) { return $false } }
    return $true
}

# --- Il vero metodo IsIncludedPath del modulo di analytics, compilato in memoria -----------------------------------------------------------
$module = $texts['App_Code/KeepStoreAnalyticsGetModule.vb']
if ($null -eq $module) { throw 'ANALYTICS_MODULE_MISSING' }
$methodMatch = [regex]::Match($module, '(?s)    Private Function IsIncludedPath\(ByVal req As HttpRequest\) As Boolean\n.*?\n    End Function')
if (-not $methodMatch.Success) { throw 'IS_INCLUDED_PATH_NOT_FOUND' }
$method = $methodMatch.Value

function Compile-Included([string]$methodText) {
    $m = Mutate-Text $methodText 'Private Function IsIncludedPath(ByVal req As HttpRequest) As Boolean' 'Private Function IsIncludedPath(ByVal reqPath As String) As Boolean' 'HARNESS_SIGNATURE'
    $m = Mutate-Text $m 'Path.GetFileName(req.Path)' 'Path.GetFileName(reqPath)' 'HARNESS_PATH'
    $code = "Imports System`nImports System.Configuration`nImports System.IO`nImports System.Web`nPublic Class IncludedProbe`n" + $m + "`n    Public Function Included(ByVal p As String) As Boolean`n        Return IsIncludedPath(p)`n    End Function`nEnd Class`n"
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll', 'System.Configuration.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($code))
    if ($c.Errors.HasErrors) { throw ('ANALYTICS_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('IncludedProbe', $true))
}
function Test-AnalyticsDefault([string]$methodText) {
    # senza appSetting nel processo di prova: vale il valore predefinito
    if ($null -ne [Configuration.ConfigurationManager]::AppSettings['KeepStore.AnalyticsGet.IncludePaths']) { throw 'HARNESS_APPSETTING_PRESENT' }
    $probe = Compile-Included $methodText
    foreach ($ok in @('/wishlist.aspx', '/articoli.aspx', '/ARTICOLI.ASPX', '/Wishlist.aspx')) { if (-not $probe.Included($ok)) { return $false } }
    foreach ($no in @('/rettificaMagazzino.aspx', '/RettificaMagazzino.ASPX', '/search_complete.aspx', '/default.aspx', '/carrello.aspx', '/articolo.aspx')) { if ($probe.Included($no)) { return $false } }
    return $true
}
function Test-AnalyticsPrecedence([string]$methodText) {
    # l'appSetting resta il primo valore letto e il predefinito vale solo se e vuoto
    $i1 = $methodText.IndexOf('Dim incl As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.IncludePaths")')
    $i2 = $methodText.IndexOf('If String.IsNullOrWhiteSpace(incl) Then')
    $i3 = $methodText.IndexOf('incl = "')
    $i4 = $methodText.IndexOf('Dim parts() As String = incl.Split(";"c)')
    return ($i1 -ge 0 -and $i2 -gt $i1 -and $i3 -gt $i2 -and $i4 -gt $i3)
}
function Test-PolicyEntry([string]$policyText) {
    return ([regex]::Matches($policyText, '(?m)^\s*"rettificamagazzino\.aspx",\s*$').Count -eq 1)
}

# --- Stato reale --------------------------------------------------------------------------------------------------------------------------
Assert-Source (Test-NoFiles $allNames) 'RETIRED_PAGE_AND_CODEBEHIND_ABSENT_ANY_CASING'
Assert-Source (Test-Mentions $texts) 'ONLY_DECLARED_MENTION_OF_THE_PAGE_IN_RUNTIME'
Assert-Source (Test-PolicyEntry $texts['App_Code/StorefrontReturnUrlPolicy.vb']) 'DEFENSIVE_RETURN_POLICY_ENTRY_KEPT'
Assert-Source (Test-AnalyticsDefault $method) 'ANALYTICS_DEFAULT_KEEPS_WISHLIST_AND_CATALOG_ONLY_REAL_METHOD'
Assert-Source (Test-AnalyticsPrecedence $method) 'ANALYTICS_APPSETTING_STILL_WINS_OVER_THE_DEFAULT'
Assert-Source ($texts.ContainsKey('articoli.aspx') -and $texts.ContainsKey('articoli.aspx.vb') -and $texts.ContainsKey('wishlist.aspx')) 'CATALOG_AND_WISHLIST_PAGES_PRESENT'

# --- Mutazioni ----------------------------------------------------------------------------------------------------------------------------
function Clone-Texts() { $c = @{}; foreach ($k in $texts.Keys) { $c[$k] = $texts[$k] }; return $c }

Assert-Detected (Test-NoFiles ($allNames + 'rettificaMagazzino.aspx')) 'V01_PAGE_RESTORED'
Assert-Detected (Test-NoFiles ($allNames + 'rettificaMagazzino.aspx.vb')) 'V02_CODEBEHIND_RESTORED'
Assert-Detected (Test-NoFiles ($allNames + 'Sub/RETTIFICAMAGAZZINO.ASPX')) 'V03_PAGE_OTHER_CASING_AND_PATH'
Assert-Detected (Test-NoFiles ($allNames + 'rettifica-magazzino.aspx')) 'V04_PAGE_WITH_HYPHEN'

$m = Clone-Texts; $m['carrello.aspx'] = $m['carrello.aspx'] + "`n" + '<asp:HyperLink NavigateUrl="~/RettificaMagazzino.aspx" runat="server" />'
Assert-Detected (Test-Mentions $m) 'V05_LINK_TO_THE_PAGE_ANY_CASING'
$m = Clone-Texts; $m['carrello.aspx.vb'] = $m['carrello.aspx.vb'] + "`n" + 'Response.Redirect("rettificaMagazzino.aspx")'
Assert-Detected (Test-Mentions $m) 'V06_REDIRECT_TO_THE_PAGE_IN_CODE'
$m = Clone-Texts; $m['Public/assets/keepstore/js/ks-page-flags.js'] = $m['Public/assets/keepstore/js/ks-page-flags.js'] + "`n" + 'location.href = "/rettifica-magazzino.aspx";'
Assert-Detected (Test-Mentions $m) 'V07_JS_LINK_WITH_HYPHEN'
$m = Clone-Texts; $m['App_Code/KeepStoreAnalyticsGetModule.vb'] = Mutate-Text $m['App_Code/KeepStoreAnalyticsGetModule.vb'] 'incl = "wishlist.aspx;articoli.aspx"' 'incl = "wishlist.aspx;rettificaMagazzino.aspx;articoli.aspx"' 'M01'
Assert-Detected (Test-Mentions $m) 'V08_ANALYTICS_TEXT_NAMES_THE_PAGE_AGAIN'
$m = Clone-Texts; $m['App_Code/StorefrontReturnUrlPolicy.vb'] = Mutate-Text $m['App_Code/StorefrontReturnUrlPolicy.vb'] '        "rettificamagazzino.aspx",' '' 'M02'
Assert-Detected (Test-Mentions $m) 'V09_DEFENSIVE_ENTRY_REMOVED_MENTION_LIST'
Assert-Detected (Test-PolicyEntry (Mutate-Text $texts['App_Code/StorefrontReturnUrlPolicy.vb'] '        "rettificamagazzino.aspx",' '' 'M03')) 'V10_DEFENSIVE_ENTRY_REMOVED_POLICY_CHECK'

Assert-Detected (Test-AnalyticsDefault (Mutate-Text $method 'incl = "wishlist.aspx;articoli.aspx"' 'incl = "wishlist.aspx;rettificaMagazzino.aspx;articoli.aspx"' 'M04')) 'V11_ANALYTICS_DEFAULT_INCLUDES_THE_RETIRED_PAGE_BEHAVIOUR'
Assert-Detected (Test-AnalyticsDefault (Mutate-Text $method 'incl = "wishlist.aspx;articoli.aspx"' 'incl = "articoli.aspx"' 'M05')) 'V12_ANALYTICS_DEFAULT_LOSES_WISHLIST'
Assert-Detected (Test-AnalyticsDefault (Mutate-Text $method 'incl = "wishlist.aspx;articoli.aspx"' 'incl = "wishlist.aspx"' 'M06')) 'V13_ANALYTICS_DEFAULT_LOSES_CATALOG'
Assert-Detected (Test-AnalyticsDefault (Mutate-Text $method 'incl = "wishlist.aspx;articoli.aspx"' 'incl = "wishlist.aspx;articoli.aspx;search_complete.aspx"' 'M07')) 'V14_ANALYTICS_DEFAULT_INCLUDES_THE_OTHER_RETIRED_PAGE'
Assert-Detected (Test-AnalyticsDefault (Mutate-Text $method 'page.Equals(p.Trim(), StringComparison.OrdinalIgnoreCase)' 'page.Equals(p.Trim(), StringComparison.Ordinal)' 'M08')) 'V15_ANALYTICS_MATCH_BECOMES_CASE_SENSITIVE'
Assert-Detected (Test-AnalyticsPrecedence (Mutate-Text $method 'If String.IsNullOrWhiteSpace(incl) Then' 'If True Then' 'M09')) 'V16_ANALYTICS_DEFAULT_ALWAYS_OVERRIDES_THE_APPSETTING'
Assert-Detected (Test-AnalyticsPrecedence (Mutate-Text $method 'Dim incl As String = ConfigurationManager.AppSettings("KeepStore.AnalyticsGet.IncludePaths")' 'Dim incl As String = ""' 'M10')) 'V17_ANALYTICS_APPSETTING_NO_LONGER_READ'

Write-Output 'RETTIFICA_MAGAZZINO_RETIRED_ALL_PASS'
