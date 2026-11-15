[CmdletBinding()]
param()

# KS-A04-SEARCH-COMPLETE-1A - la maschera "Ricerca Avanzata" (search_complete.aspx + codebehind) e stata ritirata: resta soltanto un ingresso di
# compatibilita (301 verso il catalogo, 303 per gli altri metodi). Controllo statico con mutazioni: se la vecchia maschera, la sua classe o un
# collegamento verso la pagina tornano, o se l'ingresso di compatibilita smette di essere minimo e sicuro, il test deve fallire.
# Non dimostra l'assenza di URL costruiti dinamicamente o letti dal database, ne la risposta HTTP reale (provata a mano sul Smoke e registrata nel Masterplan).
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
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

# File runtime (non Tools, non docs, non .github): tracciati o nuovi non ignorati, che esistono davvero sul disco.
$runtimeExt = @('.aspx', '.ascx', '.master', '.ashx', '.asax', '.vb', '.js', '.css', '.html', '.htm', '.config', '.sitemap', '.xml', '.json', '.txt')
$allNames = @(& git -C $repoRoot ls-files -c -o --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'GIT_LS_FILES_FAILED' }
$allNames = @($allNames | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })
$runtimeNames = @($allNames | Where-Object {
        $ext = [IO.Path]::GetExtension($_).ToLowerInvariant()
        ($runtimeExt -contains $ext) -and ($_ -notmatch '^(Tools|docs|\.github|\.ai-review|Database Taikun)/') -and ($_ -notmatch '^Public/assets/images/')
    })
$texts = @{}
foreach ($n in $runtimeNames) { $texts[$n] = Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $n))) }
$page = $texts['search_complete.aspx']
if ($null -eq $page) { throw 'SEARCH_COMPLETE_ASPX_MISSING' }

# Unici punti del runtime che nominano ancora la pagina, riga per riga (chiave = file :: riga senza spazi ai bordi). Tutto il resto e un difetto.
#  - policy dei ritorni: voce difensiva, la pagina non diventa mai un URL di ritorno se tornasse;
#  - master: controllo del Referer (conserva il comportamento preesistente);
#  - catalogo: ponte dei prezzi pendenti in sessione (fissato da Test-CatalogSearchContext, non si tocca qui);
#  - la pagina stessa: soltanto il suo identificativo di task nel commento.
$allowedMentions = @{
    'App_Code/StorefrontReturnUrlPolicy.vb :: "search_complete.aspx",' = 1
    'Page.master.vb :: If (Me.Request.UrlReferrer.AbsolutePath.ToString().IndexOf("search_complete") < 0) Then' = 1
    'articoli.aspx.vb :: '' search_complete resta il bridge one-shot; la listing legge solo la request.' = 1
    'articoli.aspx.vb :: Session("Sto_usando_search_complete") = 0' = 1
    'search_complete.aspx :: '' KS-A04-SEARCH-COMPLETE-1A - la vecchia maschera "Ricerca Avanzata" non esiste piu: il catalogo ha gia tutti i suoi filtri' = 1
}
$mentionPattern = '(?i)search[_\- ]?complete'

function Get-Mentions([hashtable]$fileTexts) {
    $found = @{}
    foreach ($name in $fileTexts.Keys) {
        foreach ($line in ($fileTexts[$name] -split "`n")) {
            if ($line -match $mentionPattern) {
                $key = $name + ' :: ' + $line.Trim()
                if ($found.ContainsKey($key)) { $found[$key] = $found[$key] + 1 } else { $found[$key] = 1 }
            }
        }
    }
    return $found
}
function Test-Mentions([hashtable]$fileTexts) {
    $found = Get-Mentions $fileTexts
    foreach ($k in $found.Keys) { if (-not $allowedMentions.ContainsKey($k) -or $allowedMentions[$k] -ne $found[$k]) { return $false } }
    foreach ($k in $allowedMentions.Keys) { if (-not $found.ContainsKey($k)) { return $false } }
    return $true
}
function Test-NoOldFiles([string[]]$names) {
    foreach ($n in $names) {
        $leaf = [IO.Path]::GetFileName($n)
        if ($leaf -match '(?i)^search[_\- ]?complete') { if ($n -cne 'search_complete.aspx') { return $false } }
    }
    return ($names -contains 'search_complete.aspx')
}
function Test-NoOldClass([hashtable]$fileTexts) {
    foreach ($name in $fileTexts.Keys) {
        if ([IO.Path]::GetExtension($name).ToLowerInvariant() -ne '.vb') { continue }
        if ($fileTexts[$name] -match '(?im)^\s*(Partial\s+)?(Public\s+|Friend\s+)?Class\s+(search_?complete)\b') { return $false }
    }
    return $true
}
function Test-PageContract([string]$t) {
    if ($t.Length -gt 2500) { return $false }
    $lines = @($t -split "`n")
    if ($lines[0] -cne '<%@ Page Language="VB" AutoEventWireup="false" EnableViewState="false" %>') { return $false }
    foreach ($bad in @('MasterPageFile', 'CodeFile', 'CodeBehind', 'Inherits', '<asp:', '<form', 'ConnectionString', 'SqlDataSource', 'DataSource')) {
        if ($t.Contains($bad)) { return $false }
    }
    if ([regex]::Matches($t, 'runat="server"').Count -ne 1) { return $false }
    if ([regex]::Matches($t, '<script runat="server">').Count -ne 1) { return $false }
    # solo il codice, senza le righe di commento: nessun valore della richiesta, della sessione o del referrer viene letto
    $code = ($lines | Where-Object { $_.TrimStart() -notmatch "^'" }) -join "`n"
    if ($code -match '(?i)Request\s*\.\s*(QueryString|Form|Params|Url|RawUrl|UrlReferrer|Cookies|Headers|ServerVariables|Item)') { return $false }
    if ($code -match '(?i)Request\s*\(') { return $false }
    if ($code -match '(?i)\bSession\b|ReturnUrl|Server\.Transfer|Response\.Redirect\s*\(|Response\.Write|Cache\.') { return $false }
    $must = @(
        'Dim target As String = ResolveUrl("~/articoli.aspx")',
        'String.Equals(Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase)',
        'String.Equals(Request.HttpMethod, "HEAD", StringComparison.OrdinalIgnoreCase)',
        'Response.RedirectPermanent(target, True)',
        'Response.StatusCode = 303',
        'Response.AddHeader("Location", target)',
        'Response.End()',
        'Protected Overrides Sub OnPreInit(ByVal e As EventArgs)'
    )
    foreach ($m in $must) { if ([regex]::Matches($code, [regex]::Escape($m)).Count -ne 1) { return $false } }
    # nessun'altra stringa di destinazione oltre al catalogo
    if ([regex]::Matches($code, '"~/[^"]*"').Count -ne 1) { return $false }
    return $true
}

# --- Stato reale --------------------------------------------------------------------------------------------------------------------------
Assert-Source (Test-NoOldFiles $allNames) 'RETIRED_FILES_ONLY_COMPAT_ENTRY_REMAINS'
Assert-Source (Test-PageContract $page) 'COMPAT_ENTRY_CONTRACT_301_GET_HEAD_303_OTHERS_FIXED_TARGET_NO_CLIENT_INPUT'
Assert-Source (Test-NoOldClass $texts) 'NO_CLASS_SEARCH_COMPLETE_IN_ANY_VB'
Assert-Source (Test-Mentions $texts) 'ONLY_DECLARED_MENTIONS_OF_THE_PAGE_IN_RUNTIME'
Assert-Source ($texts.ContainsKey('articoli.aspx')) 'REDIRECT_TARGET_PAGE_EXISTS'

# Il catalogo conserva tutti i filtri della vecchia maschera (equivalenza funzionale, letti dal codice del catalogo).
$catalog = $texts['articoli.aspx.vb']
$filterEvidence = @(
    'Request.QueryString("ct")',                    # categoria
    'SafeIdListFromQuery("mr")',                    # marca
    'SafeIdListFromQuery("tp")',                    # tipologia
    'SafeIdListFromQuery("gr")',                    # gruppo
    'SafeIdListFromQuery("sg")',                    # sottogruppo
    'QS("q", 80)',                                  # testo
    'Request.QueryString("inpromo")',               # in promozione
    'Request.QueryString("spedgratis")',            # spedizione gratis
    'CheckBox_Disponibile, "disponibile"',          # solo disponibile
    'ReadCatalogPriceBound("pmin")',                # prezzo minimo
    'ReadCatalogPriceBound("pmax")'                 # prezzo massimo
)
$missingFilters = @($filterEvidence | Where-Object { -not $catalog.Contains($_) })
Assert-Source ($missingFilters.Count -eq 0) 'CATALOG_KEEPS_EVERY_FILTER_OF_THE_OLD_FORM'

# --- Mutazioni ----------------------------------------------------------------------------------------------------------------------------
function Clone-Texts() { $c = @{}; foreach ($k in $texts.Keys) { $c[$k] = $texts[$k] }; return $c }

Assert-Detected (Test-NoOldFiles ($allNames + 'search_complete.aspx.vb')) 'V01_OLD_CODEBEHIND_RESTORED'
Assert-Detected (Test-NoOldFiles ($allNames + 'SearchComplete.aspx.vb')) 'V02_OLD_CODEBEHIND_OTHER_CASING'
Assert-Detected (Test-NoOldFiles ($allNames | Where-Object { $_ -ne 'search_complete.aspx' })) 'V03_COMPAT_ENTRY_DELETED_NO_REDIRECT'
Assert-Detected (Test-PageContract (Mutate-Text $page '<%@ Page Language="VB" AutoEventWireup="false"' '<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false"' 'M01')) 'V04_MASTER_REINTRODUCED'
Assert-Detected (Test-PageContract (Mutate-Text $page '<%@ Page Language="VB" AutoEventWireup="false"' '<%@ Page Language="VB" CodeFile="search_complete.aspx.vb" AutoEventWireup="false"' 'M02')) 'V05_CODEFILE_REINTRODUCED'
Assert-Detected (Test-PageContract ($page + "`n" + '<asp:SqlDataSource ID="s" runat="server" />')) 'V06_DATA_SOURCE_REINTRODUCED'
Assert-Detected (Test-PageContract ($page + "`n" + '<form id="f" runat="server"></form>')) 'V07_FORM_REINTRODUCED'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Response.RedirectPermanent(target, True)' 'Response.Redirect(target, True)' 'M03')) 'V08_REDIRECT_BECOMES_302'
Assert-Detected (Test-PageContract (Mutate-Text $page '"~/articoli.aspx"' '"~/default.aspx"' 'M04')) 'V09_WRONG_TARGET'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Dim target As String = ResolveUrl("~/articoli.aspx")' 'Dim target As String = ResolveUrl("~/articoli.aspx") & Request.Url.Query' 'M05')) 'V10_QUERY_STRING_FORWARDED'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Dim target As String = ResolveUrl("~/articoli.aspx")' 'Dim target As String = ResolveUrl("~/articoli.aspx") & Request.Form("x")' 'M06')) 'V11_FORM_FIELD_FORWARDED'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Response.StatusCode = 303' 'Response.StatusCode = 200' 'M07')) 'V12_NON_GET_NO_LONGER_303'
Assert-Detected (Test-PageContract (Mutate-Text $page 'String.Equals(Request.HttpMethod, "HEAD", StringComparison.OrdinalIgnoreCase)' 'String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase)' 'M08')) 'V13_HEAD_NOT_REDIRECTED'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Response.End()' 'Response.Flush()' 'M09')) 'V14_RESPONSE_NOT_ENDED'
Assert-Detected (Test-PageContract (Mutate-Text $page 'Dim target As String' ('Session("x") = 1' + "`n" + '        Dim target As String') 'M10')) 'V15_SESSION_TOUCHED'

$m = Clone-Texts; $m['carrello.aspx'] = $m['carrello.aspx'] + "`n" + '<asp:HyperLink NavigateUrl="~/Search_Complete.aspx" runat="server" />'
Assert-Detected (Test-Mentions $m) 'V16_LINK_TO_THE_PAGE_ANY_CASING'
$m = Clone-Texts; $m['carrello.aspx.vb'] = $m['carrello.aspx.vb'] + "`n" + 'Response.Redirect("search_complete.aspx")'
Assert-Detected (Test-Mentions $m) 'V17_REDIRECT_TO_THE_PAGE_IN_CODE'
$m = Clone-Texts; $m['Public/assets/keepstore/js/ks-page-flags.js'] = $m['Public/assets/keepstore/js/ks-page-flags.js'] + "`n" + 'location.href = "/search-complete.aspx";'
Assert-Detected (Test-Mentions $m) 'V18_JS_LINK_WITH_HYPHEN'
$m = Clone-Texts; $m['App_Code/StorefrontReturnUrlPolicy.vb'] = Mutate-Text $m['App_Code/StorefrontReturnUrlPolicy.vb'] '        "search_complete.aspx",' '' 'M11'
Assert-Detected (Test-Mentions $m) 'V19_DEFENSIVE_ENTRY_REMOVED'
$m = Clone-Texts; $m['Page.master.vb'] = Mutate-Text $m['Page.master.vb'] 'IndexOf("search_complete") < 0' 'IndexOf("search_complete") < 1' 'M12'
Assert-Detected (Test-Mentions $m) 'V20_MASTER_REFERRER_CHECK_CHANGED'
$m = Clone-Texts; $m['Default.aspx.vb'] = $m['Default.aspx.vb'] + "`n" + 'Partial Class search_complete'
Assert-Detected (Test-NoOldClass $m) 'V21_OLD_CLASS_IN_ANOTHER_VB'
$m = Clone-Texts; $m['Tools/Dummy.vb'] = 'Public Class SearchComplete'
Assert-Detected (Test-NoOldClass $m) 'V22_OLD_CLASS_OTHER_CASING_AND_PATH'
Assert-Detected ((@($filterEvidence | Where-Object { -not ($catalog.Replace('ReadCatalogPriceBound("pmax")', 'x')).Contains($_) })).Count -eq 0) 'V23_CATALOG_LOSES_A_FILTER'

Write-Output 'SEARCH_COMPLETE_RETIRED_ALL_PASS'
