[CmdletBinding()]
param([switch]$SkipMutations)

# KS-MYACCOUNT-1B - pannello dell'account (riquadri delle utilita, avviso "da pagare") e lista dei documenti a schede.
# Oracolo 1: i VERI moduli App_Code/KeepStoreAccountTiles.vb e App_Code/KeepStoreOrderProgress.vb compilati (Strict) con tabelle scritte a mano: i tipi documento sono DATI (nessun id
#   nel codice), il primo tipo ordine c'e sempre, gli altri tipi solo con almeno un documento, i riquadri "in arrivo" non hanno indirizzo e non sono collegamenti, l'HTML e codificato
#   (etichette e indirizzi ostili), l'avviso va al dettaglio o alla lista; la mini barra c'e solo per ordini con stato noto e non annullato; il tracking della lista e codificato,
#   collegato solo se sicuro e assente per gli annullati.
# Oracolo 2 (testo del codice, senza commenti): myaccount usa l'identita verificata dell'host, nessun tipo documento fisso, conteggio con COUNT(d.id) e filtri nell'ON, avviso deciso
#   dalla stessa regola di "Paga adesso" senza totale; la lista rende una scheda per riga, niente separa_tracking, i pin di ORDER-REMOTE-PAYMENT e i link coupon restano identici.
# Il rendering a 320-1280 px e provato da Test-AccountLayout.ps1. Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'WINDOWS_POWERSHELL_5_1_REQUIRED_FOR_CODEDOM' }
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$rel) {
    $p = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { throw ('FILE_MISSING ' + $rel) }
    return (Norm ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)))
}
function Assert-Source([bool]$condition, [string]$code) { if (-not $condition) { throw $code }; Write-Output ('PASS ' + $code) }
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) { if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }; Write-Output ('PASS MUTATION_DETECTED ' + $code) }
function Strip-VbComments([string]$text) { return (([regex]::Replace($text, "(?m)^[ \t]*'.*$", '')) -replace "(?m)[ \t]+'[^`"\n]*$", '') }
function Show-Failure([string]$id) { if ($env:KS_ACCOUNT_TEST_VERBOSE) { Write-Host ('ACCOUNT_CASE_FAILED ' + $id) } }

$module = Read-Repo 'App_Code/KeepStoreAccountTiles.vb'
$progress = Read-Repo 'App_Code/KeepStoreOrderProgress.vb'
$accAspx = Read-Repo 'myaccount.aspx'
$accVb = Read-Repo 'myaccount.aspx.vb'
$listAspx = Read-Repo 'documenti.aspx'
$listVb = Read-Repo 'documenti.aspx.vb'
$css = Read-Repo 'Public/assets/keepstore/css/account-hub-ui.css'

# --- Oracolo 1: i moduli compilati ---------------------------------------------------------------------------------------------------------------------
$probeSource = @"
Option Strict On
Option Explicit On
Imports System
Imports System.Collections.Generic
Public Class TilesProbe
    ' spec: "id~descrizione~ordine(0/1)~conteggio" separati da "^"
    Private Function Parse(ByVal spec As String) As List(Of AccountDocType)
        Dim types As New List(Of AccountDocType)()
        If Not String.IsNullOrEmpty(spec) Then
            For Each part As String In spec.Split("^"c)
                Dim f As String() = part.Split("~"c)
                Dim t As New AccountDocType()
                t.Id = Integer.Parse(f(0))
                t.Description = If(f(1) = "(null)", Nothing, f(1))
                t.IsOrder = (f(2) = "1")
                t.Count = Integer.Parse(f(3))
                types.Add(t)
            Next
        End If
        Return types
    End Function
    Public Function B(ByVal spec As String) As String
        Dim parts As New List(Of String)()
        For Each tile As AccountTile In KeepStoreAccountTiles.Build(Parse(spec))
            parts.Add(tile.Key & "|" & tile.Label & "|" & tile.Url & "|" & If(tile.Enabled, "1", "0") & "|" & tile.Count.ToString() & "|" & tile.IconKey)
        Next
        Return String.Join(vbLf, parts.ToArray())
    End Function
    Public Function BNothing() As Integer
        Return KeepStoreAccountTiles.Build(Nothing).Count
    End Function
    Public Function R(ByVal spec As String, ByVal enabled As Boolean) As String
        Return KeepStoreAccountTiles.RenderHtml(KeepStoreAccountTiles.Build(Parse(spec)), enabled)
    End Function
    ' Riquadro costruito a mano: prova la codifica di etichetta e indirizzo e il riquadro attivo senza indirizzo.
    Public Function RRaw(ByVal label As String, ByVal url As String, ByVal enabled As Boolean, ByVal wantEnabled As Boolean) As String
        Dim tile As New AccountTile()
        tile.Key = "x" : tile.Label = label : tile.Url = url : tile.IconKey = "document" : tile.Enabled = enabled
        Dim list As New List(Of AccountTile)()
        list.Add(tile)
        list.Add(Nothing)
        Return KeepStoreAccountTiles.RenderHtml(list, wantEnabled)
    End Function
    Public Function RNothing() As String
        Return KeepStoreAccountTiles.RenderHtml(Nothing, True)
    End Function
    Public Function N(ByVal ids As String, ByVal orderTypeId As Integer) As String
        Dim list As New List(Of Integer)()
        If Not String.IsNullOrEmpty(ids) Then
            For Each s As String In ids.Split(","c)
                list.Add(Integer.Parse(s))
            Next
        End If
        Return KeepStoreAccountTiles.PayNoticeUrl(list, orderTypeId)
    End Function
    Public Function NNothing() As String
        Return KeepStoreAccountTiles.PayNoticeUrl(Nothing, 4)
    End Function
    Public Function H(ByVal isOrder As Boolean, ByVal count As Integer) As String
        Return KeepStoreAccountTiles.CountText(isOrder, count)
    End Function
    Public Function M(ByVal isOrder As Boolean, ByVal statiId As Integer) As String
        Return KeepStoreOrderProgress.MiniProgressHtml(isOrder, statiId)
    End Function
    Public Function T(ByVal tracking As String, ByVal template As String, ByVal statiId As Integer) As String
        Return KeepStoreOrderProgress.TrackingLinksHtml(tracking, template, statiId)
    End Function
End Class
"@
function New-TilesProbe([string]$modText, [string]$progText) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($modText, $progText, $probeSource))
    if ($c.Errors.HasErrors) { throw ('TILES_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('TilesProbe', $true))
}
# coda fissa: riquadri attivi e riquadri "in arrivo" (scritti a mano)
$fixedTail = @(
    'profile|Dati account|my-account-edit.aspx|1|-1|user',
    'addresses|Indirizzi|my-account-address.aspx|1|-1|pin',
    'wishlist|Preferiti|wishlist.aspx|1|-1|heart',
    'password|Password|password.aspx|1|-1|lock',
    'help|Assistenza|Contattaci.aspx|1|-1|chat',
    'logout|Esci|logout.aspx|1|-1|exit',
    'returns|Resi e riparazioni||0|-1|returns',
    'tickets|Ticket di assistenza||0|-1|ticket',
    'reviews|Le mie recensioni||0|-1|star',
    'savedcarts|Carrelli salvati||0|-1|cart',
    'points|Raccolta punti||0|-1|gift'
) -join "`n"
$noType = "orders|I miei ordini|documenti.aspx|1|-1|orders`n"
$long = 'D' * 60
$buildCases = @(
    @('', ($noType + $fixedTail)),
    @('4~Ordine~1~0', ("doc4|I miei ordini|documenti.aspx?t=4|1|0|orders`n" + $fixedTail)),
    @('4~Ordine~1~12', ("doc4|I miei ordini|documenti.aspx?t=4|1|12|orders`n" + $fixedTail)),
    @('1~Fattura Immediata~0~0', ($noType + $fixedTail)),
    @('1~Fattura Immediata~0~3', ($noType + "doc1|Fattura Immediata|documenti.aspx?t=1|1|3|document`n" + $fixedTail)),
    @('2~Preventivo~0~3^4~Ordine~1~5^3~D.D.T.~0~0^1~Fattura Immediata~0~7', ("doc2|Preventivo|documenti.aspx?t=2|1|3|document`ndoc4|I miei ordini|documenti.aspx?t=4|1|5|orders`ndoc1|Fattura Immediata|documenti.aspx?t=1|1|7|document`n" + $fixedTail)),
    @('0~Zero~0~5^-3~Negativo~1~5', ($noType + $fixedTail)),
    @('7~<b>x</b>~0~1', ($noType + "doc7|<b>x</b>|documenti.aspx?t=7|1|1|document`n" + $fixedTail)),
    @('7~~0~2', ($noType + "doc7|Documenti|documenti.aspx?t=7|1|2|document`n" + $fixedTail)),
    @('7~(null)~0~2', ($noType + "doc7|Documenti|documenti.aspx?t=7|1|2|document`n" + $fixedTail)),
    @("7~  Nota   di`tCredito  ~0~2", ($noType + "doc7|Nota di Credito|documenti.aspx?t=7|1|2|document`n" + $fixedTail)),
    @(('7~' + $long + '~0~2'), ($noType + 'doc7|' + ('D' * 47) + "...|documenti.aspx?t=7|1|2|document`n" + $fixedTail)),
    @(('7~' + ('E' * 50) + '~0~2'), ($noType + 'doc7|' + ('E' * 50) + "|documenti.aspx?t=7|1|2|document`n" + $fixedTail)),
    @('5~Nota~0~1^5~Nota bis~0~9', ($noType + "doc5|Nota|documenti.aspx?t=5|1|1|document`n" + $fixedTail)),
    @('9~Ordine B~1~-4', ("doc9|I miei ordini|documenti.aspx?t=9|1|0|orders`n" + $fixedTail)),
    @('4~Ordine~1~2^19~Ordine speciale~1~0', ("doc4|I miei ordini|documenti.aspx?t=4|1|2|orders`n" + $fixedTail)),
    @('4~Ordine~1~0^19~Ordine speciale~1~6', ("doc4|I miei ordini|documenti.aspx?t=4|1|0|orders`ndoc19|Ordine speciale|documenti.aspx?t=19|1|6|orders`n" + $fixedTail))
)
$noticeCases = @(@('', 4, ''), @('120', 4, 'documentidettaglio.aspx?id=120#ksPayNow'), @('120,121', 4, 'documenti.aspx?t=4'), @('120,121', 0, 'documenti.aspx'), @('120,121', -2, 'documenti.aspx'), @('0', 4, ''), @('-5', 4, ''), @('0,130', 4, 'documentidettaglio.aspx?id=130#ksPayNow'))
$countCases = @(@($true, 0, 'Nessun ordine'), @($true, 1, '1 ordine'), @($true, 12, '12 ordini'), @($false, 1, '1 documento'), @($false, 7, '7 documenti'), @($false, 0, ''), @($false, -1, ''), @($true, -1, ''))
$bar = { param([int]$on) '<span class="ks-mini-progress"><span class="ks-mini-progress__bar" aria-hidden="true">' + ('<i class="is-on"></i>' * $on) + ('<i></i>' * (4 - $on)) + '</span><span class="ks-mini-progress__text">Passo ' + $on + ' di 4</span></span>' }
# ordine?, stato -> HTML atteso
$miniCases = @(@($true, 1, (& $bar 1)), @($true, 6, (& $bar 1)), @($true, 2, (& $bar 2)), @($true, 5, (& $bar 3)), @($true, 4, (& $bar 4)), @($true, 3, ''), @($true, 0, ''), @($true, -1, ''), @($true, 7, ''), @($true, 99, ''),
    @($false, 1, ''), @($false, 2, ''), @($false, 4, ''), @($false, 3, ''))
$tpl = 'https://corriere.example/t?a=1&n=#ID#'
$link = { param([string]$code) '<li><span class="ks-doc-card__code">' + $code + '</span> <a class="ks-doc-card__track" href="https://corriere.example/t?a=1&amp;n=' + $code + '" target="_blank" rel="noopener noreferrer">Segui la spedizione<span class="ks-mini-progress__sr"> numero ' + $code + '</span></a></li>' }
# tracking, modello, stato -> HTML atteso
$trackCases = @(
    @('', $tpl, 4, ''), @('   ', $tpl, 4, ''),
    @('ABC123', $tpl, 4, ('<ul class="ks-doc-card__tracking">' + (& $link 'ABC123') + '</ul>')),
    @('ABC123;DEF456', $tpl, 5, ('<ul class="ks-doc-card__tracking">' + (& $link 'ABC123') + (& $link 'DEF456') + '</ul>')),
    @('ABC123', $tpl, 1, ('<ul class="ks-doc-card__tracking">' + (& $link 'ABC123') + '</ul>')),
    @('ABC123', $tpl, 3, ''),
    @('ABC123', $tpl, 99, ('<ul class="ks-doc-card__tracking">' + (& $link 'ABC123') + '</ul>')),
    @('ABC123', '', 4, '<ul class="ks-doc-card__tracking"><li><span class="ks-doc-card__code">ABC123</span></li></ul>'),
    @('ABC123', 'javascript:alert(1)//#ID#', 4, '<ul class="ks-doc-card__tracking"><li><span class="ks-doc-card__code">ABC123</span></li></ul>'),
    @('<b>x</b>', $tpl, 4, '<ul class="ks-doc-card__tracking"><li><span class="ks-doc-card__code">&lt;b&gt;x&lt;/b&gt;</span></li></ul>'),
    @('A"B''C', $tpl, 4, '<ul class="ks-doc-card__tracking"><li><span class="ks-doc-card__code">A&quot;B&#39;C</span></li></ul>'),
    @('ABC123', 'https://corriere.example/t/#ID#?x="><script>', 4, ('<ul class="ks-doc-card__tracking"><li><span class="ks-doc-card__code">ABC123</span> <a class="ks-doc-card__track" href="https://corriere.example/t/ABC123?x=&quot;&gt;&lt;script&gt;" target="_blank" rel="noopener noreferrer">Segui la spedizione<span class="ks-mini-progress__sr"> numero ABC123</span></a></li></ul>'))
)
$cache = @{}
function Test-ModuleMatrix([string]$modText, [string]$progText) {
    $key = $modText + '||' + $progText
    if ($cache.ContainsKey($key)) { return $cache[$key] }
    $ok = $true
    try {
        $probe = New-TilesProbe $modText $progText
        foreach ($c in $buildCases) { $got = $probe.B([string]$c[0]); if ($got -cne $c[1]) { Show-Failure ('build [' + $c[0] + '] got [' + ($got -replace "`n", ' // ') + ']'); $ok = $false } }
        if ($probe.BNothing() -ne 12) { Show-Failure 'build nothing'; $ok = $false }
        foreach ($c in $noticeCases) { $got = $probe.N([string]$c[0], [int]$c[1]); if ($got -cne $c[2]) { Show-Failure ('notice [' + $c[0] + '] got [' + $got + ']'); $ok = $false } }
        if ($probe.NNothing() -cne '') { Show-Failure 'notice nothing'; $ok = $false }
        foreach ($c in $countCases) { $got = $probe.H([bool]$c[0], [int]$c[1]); if ($got -cne $c[2]) { Show-Failure ('count ' + $c[0] + ' ' + $c[1] + ' got [' + $got + ']'); $ok = $false } }
        # HTML dei riquadri
        $active = $probe.R('2~Preventivo~0~3^4~Ordine~1~1', $true)
        $soon = $probe.R('2~Preventivo~0~3^4~Ordine~1~1', $false)
        if ([regex]::Matches($active, '<li>').Count -ne 8 -or [regex]::Matches($active, '<li><a class="ks-account-tile" href="').Count -ne 8 -or $active -notmatch '^<ul class="ks-account-tiles">' -or $active.Contains('is-soon') -or $active.Contains('In arrivo')) { Show-Failure 'active html shape'; $ok = $false }
        if ($active -notmatch 'href="documenti\.aspx\?t=2">.*?<span class="ks-account-tile__label">Preventivo</span><span class="ks-account-tile__hint">3 documenti</span></a>' -or $active -notmatch 'href="documenti\.aspx\?t=4">.*?<span class="ks-account-tile__label">I miei ordini</span><span class="ks-account-tile__hint">1 ordine</span></a>') { Show-Failure 'active html counts'; $ok = $false }
        if ($active -notmatch '<span class="ks-account-tile__label">Esci</span></a></li></ul>$') { Show-Failure 'active html no hint for fixed tiles'; $ok = $false }
        if ([regex]::Matches($soon, '<li>').Count -ne 5 -or [regex]::Matches($soon, '<li><span class="ks-account-tile is-soon">').Count -ne 5 -or $soon -notmatch '^<ul class="ks-account-tiles is-soon-group">' -or $soon -match '<a\b|href|tabindex|role=' -or [regex]::Matches($soon, '<span class="ks-account-tile__hint">In arrivo</span>').Count -ne 5) { Show-Failure 'soon html shape'; $ok = $false }
        if ([regex]::Matches(($active + $soon), '<svg class="ks-account-tile__icon"[^>]*aria-hidden="true"').Count -ne 13) { Show-Failure 'icons hidden'; $ok = $false }
        $hostile = $probe.RRaw('<img src=x onerror=1>"', 'documenti.aspx?t=1&x="><script>', $true, $true)
        if ($hostile -notmatch 'href="documenti\.aspx\?t=1&amp;x=&quot;&gt;&lt;script&gt;"' -or $hostile -notmatch '<span class="ks-account-tile__label">&lt;img src=x onerror=1&gt;&quot;</span>' -or $hostile.Contains('<img') -or $hostile.Contains('<script')) { Show-Failure ('hostile html [' + $hostile + ']'); $ok = $false }
        $noUrl = $probe.RRaw('Senza indirizzo', '', $true, $true)
        if ($noUrl -match '<a\b|href' -or $noUrl -notmatch 'ks-account-tile is-soon') { Show-Failure 'enabled tile without url is not a link'; $ok = $false }
        if ($probe.RRaw('X', 'a.aspx', $true, $false) -cne '' -or $probe.RNothing() -cne '') { Show-Failure 'empty render'; $ok = $false }
        foreach ($c in $miniCases) { $got = $probe.M([bool]$c[0], [int]$c[1]); if ($got -cne $c[2]) { Show-Failure ('mini ' + $c[0] + ' ' + $c[1] + ' got [' + $got + ']'); $ok = $false } }
        foreach ($c in $trackCases) { $got = $probe.T([string]$c[0], [string]$c[1], [int]$c[2]); if ($got -cne $c[3]) { Show-Failure ('track [' + $c[0] + '] ' + $c[2] + ' got [' + $got + ']'); $ok = $false } }
        if ($probe.T([NullString]::Value, [NullString]::Value, 4) -cne '') { Show-Failure 'track nothing'; $ok = $false }
    } catch { Show-Failure ('exception ' + $_.Exception.Message); $ok = $false }
    $cache[$key] = $ok
    return $ok
}
function Test-ModuleStructure([string]$text) {
    $code = Strip-VbComments $text
    if ($code -notmatch '(?m)^Public Module KeepStoreAccountTiles\s*$') { return $false }
    foreach ($bad in @('MySqlConnection', 'Session', 'HttpContext', 'ConfigurationManager', 'Request', 'DateTime.Now', 'coupon', 'Coupon')) { if ($code.IndexOf($bad, [StringComparison]::Ordinal) -ge 0) { return $false } }
    if ($code -match 't=\d|TipoDocumentiId') { return $false }
    if ($text -match '(?i)\b(taikun|webaffare|onsus|italcomed|ks_marea|panificiosa|miranda|newnda|tecind|focelda|smartness|stayon|mediaworld)\b') { return $false }
    return $true
}
Assert-Source (Test-ModuleMatrix $module $progress) 'T01_THE_REAL_MODULES_BUILD_DATA_DRIVEN_TILES_ENCODED_HTML_THE_PAY_NOTICE_TARGET_THE_MINI_BAR_AND_SAFE_TRACKING'
Assert-Source (Test-ModuleStructure $module) 'T02_THE_TILES_MODULE_IS_PURE_HAS_NO_FIXED_DOCUMENT_TYPE_AND_NO_CUSTOMER_NAME'

# --- Oracolo 2: pagine -----------------------------------------------------------------------------------------------------------------------------------
function Test-Pages([string]$aAspx, [string]$aVbText, [string]$lAspx, [string]$lVbText, [string]$cssText) {
    $aVb = Strip-VbComments $aVbText; $lVb = Strip-VbComments $lVbText
    # pannello
    if ($aAspx -match 'TipoDocumentiId\s*=\s*\d' -or $aVb -match 'TipoDocumentiId\s*=\s*\d' -or $aAspx -match '[?&]t=\d' -or $aVb -match '[?&]t=\d') { Show-Failure 'fixed document type'; return $false }
    if ($aAspx.Contains('ks-dashboard-quicklinks') -or $aAspx.Contains('Azioni rapide')) { Show-Failure 'old quick links'; return $false }
    if ($aVb -notmatch 'identity = OrderStorefrontContext\.Resolve\(HttpContext\.Current\)' -or $aVb -notmatch 'If identity IsNot Nothing AndAlso identity\.IsComplete Then') { Show-Failure 'verified identity'; return $false }
    if ($aVb -match 'Session\("UtentiID"\)|Session\("AziendaID"\)|Request\.QueryString|Request\.Form') { Show-Failure 'identity from session or client'; return $false }
    $q = [regex]::Match($aVb, '(?s)Private Const DocTypesSql As String =.*?(?=\n\s*\n)').Value
    if ($q -eq '' -or $q -notmatch 'COUNT\(d\.id\) AS N' -or $q -match 'COUNT\(\*\)' -or $q -notmatch 'LEFT JOIN documenti d ON d\.TipoDocumentiId=td\.id AND d\.UtentiId=@uid AND d\.AziendeId=@azienda " &\s*\n\s*"WHERE td\.Web=1 AND td\.Abilitato=1 GROUP BY') { Show-Failure 'doc types query scope'; return $false }
    $c = [regex]::Match($aVb, '(?s)Private Const PayCandidatesSql As String =.*?(?=\n\s*\n)').Value
    if ($c -eq '' -or $c -notmatch 'WHERE d\.UtentiId=@uid AND d\.AziendeId=@azienda AND COALESCE\(d\.Pagato,0\)=0' -or $c -notmatch 'td\.ImpegnaQnt=1' -or $c -notmatch 'ORDER BY d\.id DESC LIMIT 50"') { Show-Failure 'candidates query scope'; return $false }
    if ([regex]::Matches($aVb, 'cmd\.Parameters\.Add\("@uid", MySqlDbType\.Int64\)\.Value = identity\.UtentiId').Count -ne 2 -or [regex]::Matches($aVb, 'cmd\.Parameters\.Add\("@azienda", MySqlDbType\.Int32\)\.Value = identity\.CompanyId').Count -ne 2) { Show-Failure 'parameters from the identity'; return $false }
    if ($aVb -notmatch '(?m)^\s*If KeepStoreRemotePaymentStore\.CanPayNow\(candidate, identity\.UtentiId, identity\.CompanyId\) Then payable\.Add\(candidate\)\s*$') { Show-Failure 'pay notice uses the full decision'; return $false }
    if ([regex]::Matches($aVb, 'payable\.Add\(').Count -ne 1 -or $aVb -notmatch '(?s)Catch\s*\n\s*payable\.Clear\(\)') { Show-Failure 'payable only from the decision'; return $false }
    if ($aVb -notmatch '_tiles = KeepStoreAccountTiles\.Build\(types\)' -or $aVb -notmatch 'KeepStoreAccountTiles\.PayNoticeUrl\(payable, orderTypeId\)' -or $aVb -notmatch 'Return KeepStoreAccountTiles\.RenderHtml\(_tiles, active\)') { Show-Failure 'uses module'; return $false }
    if ($aVb -notmatch 'litPayNotice\.Text = If\(payable\.Count = 1, "Hai un ordine da pagare", "Hai ordini da pagare"\)' -or $aVb -match 'payable\.Count\.ToString|payable\.Count &') { Show-Failure 'notice without a total'; return $false }
    if ($aVb -notmatch 'litGreeting\.Text = HttpUtility\.HtmlEncode\(GetDashboardGreeting\(') { Show-Failure 'greeting encoded'; return $false }
    $iHero = $aAspx.IndexOf('<asp:Literal ID="litGreeting"', [StringComparison]::Ordinal); $iNotice = $aAspx.IndexOf('<div id="pnlPayNotice" runat="server" visible="false" class="ks-account-notice">', [StringComparison]::Ordinal)
    $iTiles = $aAspx.IndexOf('<%= TilesHtml(True) %>', [StringComparison]::Ordinal); $iForm = $aAspx.IndexOf('<asp:FormView ID="fvDashboardProfile"', [StringComparison]::Ordinal); $iSoon = $aAspx.IndexOf('<%= TilesHtml(False) %>', [StringComparison]::Ordinal)
    $iFormEnd = $aAspx.IndexOf('</asp:FormView>', [StringComparison]::Ordinal)
    if ($iHero -lt 0 -or -not ($iHero -lt $iNotice -and $iNotice -lt $iTiles -and $iTiles -lt $iForm -and $iFormEnd -lt $iSoon)) { Show-Failure 'page slots outside the form view'; return $false }
    if ($aAspx -notmatch '<a id="lnkPayNotice" runat="server" class="[^"]*">Paga adesso</a>' -or $aAspx -match 'lnkPayNotice"[^>]*href') { Show-Failure 'notice link set by code'; return $false }
    if ($aAspx -notmatch 'account-hub-ui\.css"\) %>\?v=20261118-orders-1b') { Show-Failure 'account css'; return $false }
    # lista
    if ($lVb -match 'separa_tracking' -or $lAspx -match 'separa_tracking') { Show-Failure 'old tracking helper'; return $false }
    if ($lVb -notmatch 'Return KeepStoreOrderProgress\.MiniProgressHtml\(SafeInt\(isOrderObj, 0\) = 1, SafeInt\(statiIdObj, 0\)\)' -or $lVb -notmatch 'Return KeepStoreOrderProgress\.TrackingLinksHtml\(tracking, template, SafeInt\(statiIdObj, 0\)\)') { Show-Failure 'list uses the safe module'; return $false }
    $listModule = [IO.File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'App_Code\KeepStoreAccountOrderFilters.vb'), [Text.Encoding]::UTF8); if ($listModule -notmatch 'CASE WHEN ltd\.Web=1 AND ltd\.Abilitato=1 AND ltd\.ImpegnaQnt=1 THEN 1 ELSE 0 END AS ListaOrdineWeb') { Show-Failure 'order type in the list query'; return $false }
    if ([regex]::Matches($lAspx, '<asp:TemplateField').Count -ne 1 -or $lAspx -notmatch 'ShowHeader="False"' -or [regex]::Matches($lAspx, '<article class="ks-doc-card">').Count -ne 1 -or $lAspx -match '<RowStyle[^>]*Height=') { Show-Failure 'one card per row'; return $false }
    if ($lAspx -notmatch '<%# ListProgressHtml\(Eval\("ListaOrdineWeb"\), Eval\("StatiId"\)\) %>' -or $lAspx -notmatch '<%# ListTrackingHtml\(Eval\("Tracking"\), Eval\("Link_Tracking"\), Eval\("StatiId"\)\) %>') { Show-Failure 'card helpers'; return $false }
    if ([regex]::Matches($lAspx, 'Eval\("Tracking"\)').Count -ne 1) { Show-Failure 'raw tracking in the list'; return $false }
    if ($lAspx -notmatch '<%#: Eval\("VettoriDescrizione"\) %>' -or $lAspx -notmatch '<%#: Eval\("TipoDocumentiDescrizione"\) %>' -or $lAspx -notmatch '<%#: OrderStatusTitle\(' -or $lAspx -notmatch '<%#: OrderStatusNote\(') { Show-Failure 'db texts encoded'; return $false }
    if ($lAspx -notmatch 'ID="hlListaPagaAdesso" runat="server"[^>]*NavigateUrl=''<%# Eval\("id", "documentidettaglio\.aspx\?id=\{0\}#ksPayNow"\) %>'' Visible=''<%# ListPayNowVisible\(Eval\("id"\)\) %>'' Text="Paga adesso"') { Show-Failure 'pay now button kept'; return $false }
    if ($lAspx -notmatch 'ID="lblListaDaPagare" runat="server" CssClass="ks-pay-now__badge" Text="Da pagare" Visible=''<%# ListPayNowVisible\(Eval\("id"\)\) %>''') { Show-Failure 'badge kept'; return $false }
    if ($lAspx -notmatch 'ID="idcoupon" runat="server"\s*\n\s*Visible=''<%# \(Convert\.ToString\(Request\.QueryString\("t"\)\) = Convert\.ToString\(Session\("IdDocumentoCoupon"\)\)\) %>''' -or $lAspx -notmatch 'ID="iddoc" runat="server"\s*\n\s*Visible=''<%# Not \(Convert\.ToString\(Request\.QueryString\("t"\)\) = Convert\.ToString\(Session\("IdDocumentoCoupon"\)\)\) %>''\s*\n\s*NavigateUrl=''<%# Eval\("id", "documentidettaglio\.aspx\?id=\{0\}"\) %>''') { Show-Failure 'coupon and document links kept'; return $false }
    if ($lAspx -notmatch 'account-hub-ui\.css"\) %>\?v=20261118-orders-1b' -or $lAspx -notmatch 'order-ui\.css"\) %>\?v=20261117-pay-now-1a') { Show-Failure 'list css'; return $false }
    if ($lVb -notmatch 'If _payNowDecisions\.TryGetValue\(documentId, cached\) Then Return cached' -or $lVb -notmatch '_payNowDecisions\(documentId\) = decision') { Show-Failure 'one decision per document'; return $false }
    if ($lVb -notmatch 'Protected Function ListPayNowVisible\(ByVal documentIdObj As Object\) As Boolean\s*\n\s*Return CanShowPayNow\(SafeInt\(documentIdObj, 0\)\)') { Show-Failure 'list helper kept'; return $false }
    # stili
    if ($cssText -notmatch '(?s)\n\.ks-account-tile\s*\{[^}]*min-height:\s*(9[6-9]|1\d\d)px') { Show-Failure 'css tile size'; return $false }
    if ($cssText -notmatch '(?s)\.ks-account-tile\.is-soon\s*\{[^}]*cursor:\s*default') { Show-Failure 'css soon'; return $false }
    if ($cssText -notmatch '(?s)\n\.ks-doc-card\s*\{[^}]*box-shadow:\s*5px 6px 30px 0 rgba\(0, 0, 0, \.1\)') { Show-Failure 'css card shadow'; return $false }
    if ($cssText -match 'border-radius') { Show-Failure 'css rounded corners'; return $false }
    if ($cssText -notmatch '(?s)table\.ks-doc-list\s*\{[^}]*min-width:\s*0') { Show-Failure 'css min-width reset'; return $false }
    if ($cssText -notmatch '\.ks-doc-list > tbody > tr\.td-order-item\s*\{' -or $cssText -match '(?m)^\.ks-doc-list tr\b|(?m)^\.ks-doc-list td\b') { Show-Failure 'css rows scoped'; return $false }
    if ($cssText -notmatch '(?s)\.ks-doc-card__track\s*\{[^}]*min-height:\s*44px') { Show-Failure 'css 44'; return $false }
    return $true
}
Assert-Source (Test-Pages $accAspx $accVb $listAspx $listVb $css) 'T03_THE_DASHBOARD_USES_THE_VERIFIED_IDENTITY_AND_THE_LIST_RENDERS_ONE_SAFE_CARD_PER_ROW'

# --- KS-QA-BROWSER-1A (difetti visti nel browser reale): date del connettore MySQL, pulsanti <input> invisibili, doppione del menu nel pannello -------------------
$dates = Read-Repo 'App_Code/KeepStoreDates.vb'
$accountCss = Read-Repo 'Public/assets/keepstore/css/account-ui.css'
$sidebarVb = Read-Repo 'Public/ui/controls/AccountSidebar.ascx.vb'
$detailAspx = Read-Repo 'documentidettaglio.aspx'
$orderVb = Read-Repo 'ordine.aspx.vb'
$loginAspx = Read-Repo 'login.aspx'
$cartAspx = Read-Repo 'carrello.aspx'
$datesProbe = @"
Option Strict On
Option Explicit On
Imports System
' Finto tipo del connettore: convertibile in data ma con ToString all'americana (mese/giorno), come MySqlDateTime.
Public Class FakeConnectorDate
    Implements IConvertible
    Private ReadOnly _d As DateTime
    Private ReadOnly _valid As Boolean
    Public Sub New(ByVal d As DateTime, ByVal valid As Boolean)
        _d = d : _valid = valid
    End Sub
    Public Overrides Function ToString() As String
        Return _d.ToString("MM/dd/yyyy HH:mm:ss", Globalization.CultureInfo.InvariantCulture)
    End Function
    Public Function ToDateTime(ByVal provider As IFormatProvider) As DateTime Implements IConvertible.ToDateTime
        If Not _valid Then Throw New InvalidCastException("zero date")
        Return _d
    End Function
    Public Function GetTypeCode() As TypeCode Implements IConvertible.GetTypeCode
        Return TypeCode.Object
    End Function
    Public Function ToBoolean(ByVal p As IFormatProvider) As Boolean Implements IConvertible.ToBoolean
        Throw New InvalidCastException()
    End Function
    Public Function ToByte(ByVal p As IFormatProvider) As Byte Implements IConvertible.ToByte
        Throw New InvalidCastException()
    End Function
    Public Function ToChar(ByVal p As IFormatProvider) As Char Implements IConvertible.ToChar
        Throw New InvalidCastException()
    End Function
    Public Function ToDecimal(ByVal p As IFormatProvider) As Decimal Implements IConvertible.ToDecimal
        Throw New InvalidCastException()
    End Function
    Public Function ToDouble(ByVal p As IFormatProvider) As Double Implements IConvertible.ToDouble
        Throw New InvalidCastException()
    End Function
    Public Function ToInt16(ByVal p As IFormatProvider) As Short Implements IConvertible.ToInt16
        Throw New InvalidCastException()
    End Function
    Public Function ToInt32(ByVal p As IFormatProvider) As Integer Implements IConvertible.ToInt32
        Throw New InvalidCastException()
    End Function
    Public Function ToInt64(ByVal p As IFormatProvider) As Long Implements IConvertible.ToInt64
        Throw New InvalidCastException()
    End Function
    Public Function ToSByte(ByVal p As IFormatProvider) As SByte Implements IConvertible.ToSByte
        Throw New InvalidCastException()
    End Function
    Public Function ToSingle(ByVal p As IFormatProvider) As Single Implements IConvertible.ToSingle
        Throw New InvalidCastException()
    End Function
    Public Function ToString1(ByVal p As IFormatProvider) As String Implements IConvertible.ToString
        Return ToString()
    End Function
    Public Function ToType(ByVal t As Type, ByVal p As IFormatProvider) As Object Implements IConvertible.ToType
        Throw New InvalidCastException()
    End Function
    Public Function ToUInt16(ByVal p As IFormatProvider) As UShort Implements IConvertible.ToUInt16
        Throw New InvalidCastException()
    End Function
    Public Function ToUInt32(ByVal p As IFormatProvider) As UInteger Implements IConvertible.ToUInt32
        Throw New InvalidCastException()
    End Function
    Public Function ToUInt64(ByVal p As IFormatProvider) As ULong Implements IConvertible.ToUInt64
        Throw New InvalidCastException()
    End Function
End Class
Public Class DatesProbe
    Public Function Run() As String
        Threading.Thread.CurrentThread.CurrentCulture = Globalization.CultureInfo.GetCultureInfo("it-IT")
        Dim r As New Collections.Generic.List(Of String)()
        r.Add(KeepStoreDates.ShortDate(New FakeConnectorDate(New DateTime(2026, 11, 6), True)))
        r.Add(KeepStoreDates.ShortDate(New FakeConnectorDate(New DateTime(2026, 11, 18, 9, 30, 0), True)))
        r.Add(KeepStoreDates.IsoText(New FakeConnectorDate(New DateTime(2026, 11, 6, 9, 5, 7), True)))
        r.Add("[" & KeepStoreDates.ShortDate(New FakeConnectorDate(New DateTime(2026, 11, 6), False)) & "]")
        r.Add(KeepStoreDates.ShortDate(New DateTime(2026, 3, 4)))
        r.Add("[" & KeepStoreDates.ShortDate(DBNull.Value) & "]")
        r.Add("[" & KeepStoreDates.ShortDate(Nothing) & "]")
        r.Add("[" & KeepStoreDates.ShortDate(DateTime.MinValue) & "]")
        r.Add(KeepStoreDates.ShortDate("2026-11-06 00:00:00"))
        r.Add(KeepStoreDates.ShortDate("11/06/2026 00:00:00"))
        r.Add("[" & KeepStoreDates.ShortDate("non una data") & "]")
        r.Add("[" & KeepStoreDates.IsoText("") & "]")
        Return String.Join("|", r.ToArray())
    End Function
End Class
"@
$datesExpected = '06/11/2026|18/11/2026|2026-11-06 09:05:07|[]|04/03/2026|[]|[]|[]|06/11/2026|06/11/2026|[]|[]'
function Test-Dates([string]$datesText) {
    try {
        $p = New-Object CodeDom.Compiler.CompilerParameters
        $p.GenerateInMemory = $true
        $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
        @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
        $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($datesText, $datesProbe))
        if ($c.Errors.HasErrors) { Show-Failure ('dates compile ' + $c.Errors[0].ErrorText); return $false }
        $got = [Activator]::CreateInstance($c.CompiledAssembly.GetType('DatesProbe', $true)).Run()
        if ($got -cne $datesExpected) { Show-Failure ('dates got ' + $got); return $false }
        return $true
    } catch { Show-Failure ('dates exception ' + $_.Exception.Message); return $false }
}
function Test-BrowserFindings([string]$aAspx, [string]$lAspx, [string]$dAspx, [string]$oVb, [string]$accCss, [string]$sbVb, [string]$lgAspx, [string]$cAspx) {
    $o = Strip-VbComments $oVb
    if ($aAspx -match '\{0:d\}' -or $lAspx -match 'DataDocumento", "\{0:d\}"' -or $dAspx -match 'DataDocumento", "\{0:d\}"') { Show-Failure 'raw date format left'; return $false }
    foreach ($page in @($lAspx, $dAspx)) { if ($page -notmatch 'KeepStoreDates\.ShortDate\(Eval\("DataDocumento"\)\)') { Show-Failure 'page date helper'; return $false } }
    if ([regex]::Matches($o, 'KeepStoreDates\.IsoText\(').Count -ne 4 -or $o -notmatch 'KeepStoreDates\.ShortDate\(drTestata\.Item\("DataDocumento"\)\)' -or $o -match 'DbText\((dr|drTestata), "DataDocumento"\)|dr\("DataDocumento"\)\.ToString\(\)') { Show-Failure 'order page date sources'; return $false }
    if ($o -notmatch 'DateTime\.TryParseExact\(value\.Trim\(\), New String\(\) \{"yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"\}, CultureInfo\.InvariantCulture') { Show-Failure 'order page exact parse'; return $false }
    # pannello: niente tabella, niente schede doppie, menu laterale non mostrato
    if ($aAspx -match '<asp:GridView|<asp:Repeater|ks-dashboard-card|ks-order-table|sdsRecentOrders|rptRecentOrders|ks-doc-card') { Show-Failure 'dashboard without order lists'; return $false }
    $area = [regex]::Match((Strip-VbComments $sbVb), '(?s)Private Function IsAccountArea\(.*?End Function').Value
    if ($area -eq '' -or $area -match '"myaccount\.aspx"') { Show-Failure 'sidebar hidden on the dashboard'; return $false }
    if ($accCss -notmatch 'body\.ks-page-account \.ks-account-aside:not\(:has\(\.ks-account-card\)\)\s*\{\s*display:\s*none') { Show-Failure 'empty aside collapsed'; return $false }
    if ($accCss -notmatch '(?s)\.ks-account-nav-link\s*\{[^}]*min-height:\s*44px') { Show-Failure 'sidebar link target'; return $false }
    # pulsanti <input>: il tema li rendeva trasparenti con spaziatura zero
    if ($accCss -notmatch '(?s)\nform input\.tf-btn\.tf-btn\s*\{[^}]*min-height:\s*44px[^}]*background-color:\s*var\(--primary') { Show-Failure 'input buttons visible'; return $false }
    # accesso: un solo pulsante principale, Invio invia, titolo vero, errore annunciato
    if ($lgAspx -notmatch '<asp:Panel ID="pnlLogin" runat="server"[^>]*DefaultButton="btnLogin"' -or $lgAspx -notmatch '<h1 class="ks-login__title">Accedi</h1>' -or $lgAspx -notmatch 'CssClass="tf-btn ks-login__submit"' -or $lgAspx -match 'text-white') { Show-Failure 'login form'; return $false }
    if ($lgAspx -notmatch '<div class="ks-login__message" role="alert">\s*<asp:Label ID="lblLogin"' -or $lgAspx -notmatch 'autocomplete="current-password"' -or $lgAspx -notmatch 'id="hlRegistrati" href="registrazione\.aspx"') { Show-Failure 'login message and links'; return $false }
    if ($cAspx -notmatch '(?s)<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">\s*Carrello\s*</asp:Content>') { Show-Failure 'cart title'; return $false }
    return $true
}
Assert-Source (Test-Dates $dates) 'T04_CONNECTOR_DATES_BECOME_DAY_MONTH_YEAR_AND_NEVER_SWAP_DAY_AND_MONTH'
Assert-Source (Test-BrowserFindings $accAspx $listAspx $detailAspx $orderVb $accountCss $sidebarVb $loginAspx $cartAspx) 'T05_BROWSER_FINDINGS_STAY_FIXED_DATES_VISIBLE_INPUT_BUTTONS_NO_DUPLICATE_MENU_LOGIN_FORM'

if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED'; exit 0 }

# --- Mutazioni ------------------------------------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'M01_NON_ORDER_TYPE_SHOWN_WITH_ZERO'; T = 'module'; Old = 'ElseIf count <= 0 Then'; New = 'ElseIf count < 0 Then' },
    @{ Id = 'M02_NEGATIVE_ID_ACCEPTED'; T = 'module'; Old = 'If t Is Nothing OrElse t.Id <= 0 Then Continue For'; New = 'If t Is Nothing Then Continue For' },
    @{ Id = 'M03_DUPLICATE_TYPE_SHOWN_TWICE'; T = 'module'; Old = 'If Not seen.Add(t.Id) Then Continue For'; New = 'seen.Add(t.Id)' },
    @{ Id = 'M04_SECOND_ORDER_TYPE_ALWAYS_SHOWN'; T = 'module'; Old = 'If t.IsOrder AndAlso Not hasOrder Then'; New = 'If t.IsOrder Then' },
    @{ Id = 'M05_LABEL_NOT_CUT'; T = 'module'; Old = 'label = label.Substring(0, MaxLabelLength - 3) & "..."'; New = 'label = label' },
    @{ Id = 'M06_EMPTY_LABEL_KEPT'; T = 'module'; Old = 'If label.Length = 0 Then label = "Documenti"'; New = '' },
    @{ Id = 'M07_SOON_TILE_GETS_A_LINK'; T = 'module'; Old = 'result.Add(NewTile("returns", "Resi e riparazioni", "", "returns", False))'; New = 'result.Add(NewTile("returns", "Resi e riparazioni", "resi.aspx", "returns", True))' },
    @{ Id = 'M08_NEGATIVE_COUNT_KEPT'; T = 'module'; Old = 'Math.Max(0, t.Count)'; New = 't.Count' },
    @{ Id = 'M09_NOTICE_ALWAYS_TO_THE_LIST'; T = 'module'; Old = 'If valid.Count = 1 Then'; New = 'If valid.Count = 99 Then' },
    @{ Id = 'M10_NOTICE_ACCEPTS_BAD_IDS'; T = 'module'; Old = 'If id > 0 Then valid.Add(id)'; New = 'valid.Add(id)' },
    @{ Id = 'M11_ORDER_LABEL_FROM_DATA'; T = 'module'; Old = '                    label = "I miei ordini"'; New = '' },
    @{ Id = 'M12_COUNT_TEXT_SINGULAR'; T = 'module'; Old = 'If count = 1 Then Return "1 ordine"'; New = '' },
    @{ Id = 'M13_NO_ORDERS_TILE_WITHOUT_DATA'; T = 'module'; Old = 'If Not hasOrder Then result.Insert(0, NewTile("orders", "I miei ordini", "documenti.aspx", "orders", True))'; New = '' },
    @{ Id = 'M14_LABEL_NOT_ENCODED'; T = 'module'; Old = 'WebUtility.HtmlEncode(If(tile.Label, ""))'; New = 'If(tile.Label, "")' },
    @{ Id = 'M15_URL_NOT_ENCODED'; T = 'module'; Old = 'Append(WebUtility.HtmlEncode(tile.Url))'; New = 'Append(tile.Url)' },
    @{ Id = 'M16_SOON_TILE_RENDERED_AS_LINK'; T = 'module'; Old = 'If tile.Enabled AndAlso Not String.IsNullOrEmpty(tile.Url) Then'; New = 'If True Then' },
    @{ Id = 'M17_ENABLED_TILE_WITHOUT_URL_AS_LINK'; T = 'module'; Old = 'If tile.Enabled AndAlso Not String.IsNullOrEmpty(tile.Url) Then'; New = 'If tile.Enabled Then' },
    @{ Id = 'M18_GROUPS_MIXED'; T = 'module'; Old = 'If tile Is Nothing OrElse tile.Enabled <> enabled Then Continue For'; New = 'If tile Is Nothing Then Continue For' },
    @{ Id = 'M19_ICON_NOT_HIDDEN'; T = 'module'; Old = ' aria-hidden=""true"" focusable=""false"">" & path'; New = ' focusable=""false"">" & path' },
    @{ Id = 'G01_MINI_BAR_FOR_EVERY_DOCUMENT'; T = 'progress'; Old = 'If Not isOrder Then Return ""'; New = '' },
    @{ Id = 'G02_MINI_BAR_FOR_CANCELLED'; T = 'progress'; Old = 'If Not p.Known OrElse p.Cancelled OrElse p.StepNumber < 1 OrElse p.StepNumber > 4 Then Return ""'; New = 'If Not p.Known Then Return ""' },
    @{ Id = 'G03_MINI_BAR_FOR_UNKNOWN_STATE'; T = 'progress'; Old = 'If Not p.Known OrElse p.Cancelled OrElse p.StepNumber < 1 OrElse p.StepNumber > 4 Then Return ""'; New = 'If p.Cancelled Then Return ""' },
    @{ Id = 'G04_MINI_BAR_ONE_STEP_SHORT'; T = 'progress'; Old = 'If(n <= p.StepNumber, "<i class=""is-on""></i>", "<i></i>")'; New = 'If(n < p.StepNumber, "<i class=""is-on""></i>", "<i></i>")' },
    @{ Id = 'G05_TRACKING_FOR_CANCELLED'; T = 'progress'; Old = 'If Resolve(statiId).Cancelled Then Return ""'; New = '' },
    @{ Id = 'G06_TRACKING_TEXT_NOT_ENCODED'; T = 'progress'; Old = 'Dim text As String = System.Net.WebUtility.HtmlEncode(token.Text)'; New = 'Dim text As String = token.Text' },
    @{ Id = 'G07_TRACKING_URL_NOT_ENCODED'; T = 'progress'; Old = 'Append(System.Net.WebUtility.HtmlEncode(url))'; New = 'Append(url)' },
    @{ Id = 'G08_TRACKING_LINK_WITHOUT_REL'; T = 'progress'; Old = '""" target=""_blank"" rel=""noopener noreferrer"">Segui la spedizione'; New = '""" target=""_blank"">Segui la spedizione' },
    @{ Id = 'G09_UNSAFE_CODE_LINKED'; T = 'progress'; Old = 'Dim url As String = If(token.Linkable, BuildTrackingUrl(template, token.Text), "")'; New = 'Dim url As String = template.Replace("#ID#", token.Text)' },
    @{ Id = 'A02_QUICK_LINKS_BACK'; T = 'accaspx'; Old = '<%= TilesHtml(True) %>'; New = '<%= TilesHtml(True) %><div class="ks-dashboard-quicklinks"></div>' },
    @{ Id = 'A03_NOTICE_VISIBLE_BY_DEFAULT'; T = 'accaspx'; Old = '<div id="pnlPayNotice" runat="server" visible="false" class="ks-account-notice">'; New = '<div id="pnlPayNotice" runat="server" class="ks-account-notice">' },
    @{ Id = 'A04_FIXED_LIST_LINK_BACK'; T = 'accaspx'; Old = '<a href="documenti.aspx" class="tf-btn btn-fill">I miei ordini</a>'; New = '<a href="documenti.aspx?t=4" class="tf-btn btn-fill">I miei ordini</a>' },
    @{ Id = 'A05_IDENTITY_FROM_SESSION'; T = 'accvb'; Old = 'identity = OrderStorefrontContext.Resolve(HttpContext.Current)'; New = 'identity = New OrderStorefrontIdentity With {.UtentiId = CLng(Session("UtentiID"))}' },
    @{ Id = 'A06_INCOMPLETE_IDENTITY_ACCEPTED'; T = 'accvb'; Old = 'If identity IsNot Nothing AndAlso identity.IsComplete Then'; New = 'If identity IsNot Nothing Then' },
    @{ Id = 'A07_DOC_COUNT_WITHOUT_COMPANY'; T = 'accvb'; Old = 'AND d.UtentiId=@uid AND d.AziendeId=@azienda " &'; New = 'AND d.UtentiId=@uid " &' },
    @{ Id = 'A08_DOC_COUNT_STAR'; T = 'accvb'; Old = 'COUNT(d.id) AS N'; New = 'COUNT(*) AS N' },
    @{ Id = 'A09_NOTICE_WITHOUT_THE_DECISION'; T = 'accvb'; Old = 'If KeepStoreRemotePaymentStore.CanPayNow(candidate, identity.UtentiId, identity.CompanyId) Then payable.Add(candidate)'; New = 'payable.Add(candidate)' },
    @{ Id = 'A10_NOTICE_DECISION_SHORT_CIRCUITED'; T = 'accvb'; Old = 'If KeepStoreRemotePaymentStore.CanPayNow(candidate, identity.UtentiId, identity.CompanyId) Then payable.Add(candidate)'; New = 'If KeepStoreRemotePaymentStore.CanPayNow(candidate, identity.UtentiId, identity.CompanyId) OrElse True Then payable.Add(candidate)' },
    @{ Id = 'A11_CANDIDATES_OF_ANY_COMPANY'; T = 'accvb'; Old = 'WHERE d.UtentiId=@uid AND d.AziendeId=@azienda AND COALESCE(d.Pagato,0)=0'; New = 'WHERE d.UtentiId=@uid AND COALESCE(d.Pagato,0)=0' },
    @{ Id = 'A12_CANDIDATES_UNBOUNDED'; T = 'accvb'; Old = 'ORDER BY d.id DESC LIMIT 50"'; New = 'ORDER BY d.id DESC"' },
    @{ Id = 'A13_NOTICE_KEPT_AFTER_AN_ERROR'; T = 'accvb'; Old = '                payable.Clear()'; New = '' },
    @{ Id = 'A14_NOTICE_SHOWS_A_TOTAL'; T = 'accvb'; Old = 'If(payable.Count = 1, "Hai un ordine da pagare", "Hai ordini da pagare")'; New = '"Hai " & payable.Count.ToString() & " ordini da pagare"' },
    @{ Id = 'A15_GREETING_NOT_ENCODED'; T = 'accvb'; Old = 'litGreeting.Text = HttpUtility.HtmlEncode(GetDashboardGreeting('; New = 'litGreeting.Text = (GetDashboardGreeting(' },
    @{ Id = 'L01_OLD_TRACKING_HELPER_BACK'; T = 'listaspx'; Old = 'ListTrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId"))'; New = 'separa_tracking(Eval("Tracking"), Eval("Link_Tracking"))' },
    @{ Id = 'L02_RAW_TRACKING_TEXT'; T = 'listaspx'; Old = '<%# ListTrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId")) %>'; New = '<%# ListTrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId")) %><%# Eval("Tracking") %>' },
    @{ Id = 'L03_PROGRESS_FOR_EVERY_DOCUMENT'; T = 'listaspx'; Old = 'ListProgressHtml(Eval("ListaOrdineWeb"), Eval("StatiId"))'; New = 'ListProgressHtml(1, Eval("StatiId"))' },
    @{ Id = 'L04_PAY_BUTTON_ALWAYS_VISIBLE'; T = 'listaspx'; Old = "Visible='<%# ListPayNowVisible(Eval(""id"")) %>' Text=""Paga adesso"""; New = 'Text="Paga adesso"' },
    @{ Id = 'L05_HEADER_BACK'; T = 'listaspx'; Old = 'ShowHeader="False"'; New = 'ShowHeader="True"' },
    @{ Id = 'L06_ROW_HEIGHT_BACK'; T = 'listaspx'; Old = '<RowStyle CssClass="td-order-item" />'; New = '<RowStyle CssClass="td-order-item" Height="25px" />' },
    @{ Id = 'L07_CARRIER_NOT_ENCODED'; T = 'listaspx'; Old = '<%#: Eval("VettoriDescrizione") %>'; New = '<%# Eval("VettoriDescrizione") %>' },
    @{ Id = 'L08_DOCUMENT_LINK_CHANGED'; T = 'listaspx'; Old = "NavigateUrl='<%# Eval(""id"", ""documentidettaglio.aspx?id={0}"") %>'"; New = "NavigateUrl='<%# Eval(""id"", ""documentidettaglio.aspx?doc={0}"") %>'" },
    @{ Id = 'L10_DECISION_NOT_CACHED'; T = 'listvb'; Old = '        _payNowDecisions(documentId) = decision'; New = '' },
    @{ Id = 'L11_TRACKING_IGNORES_THE_STATE'; T = 'listvb'; Old = 'TrackingLinksHtml(tracking, template, SafeInt(statiIdObj, 0))'; New = 'TrackingLinksHtml(tracking, template, 4)' },
    @{ Id = 'C01_TILE_TOO_SMALL'; T = 'css'; Old = '    min-height: 96px;'; New = '    min-height: 40px;' },
    @{ Id = 'C02_ROUNDED_CORNERS'; T = 'css'; Old = '.ks-doc-card {'; New = '.ks-doc-card { border-radius: .5rem;' },
    @{ Id = 'C03_THEME_MIN_WIDTH_BACK'; T = 'css'; Old = '    min-width: 0;' + "`n" + '    width: 100%;'; New = '    width: 100%;' },
    @{ Id = 'C04_ROWS_NOT_SCOPED'; T = 'css'; Old = '.ks-doc-list > tbody > tr.td-order-item {'; New = '.ks-doc-list tr {' }
)
# mutanti di KS-QA-BROWSER-1A
$qaMutants = @(
    @{ Id = 'Q01_DATE_FROM_THE_CONNECTOR_TEXT'; T = 'dates'; Old = 'If convertible IsNot Nothing AndAlso Not TypeOf value Is String Then'; New = 'If False Then' },
    @{ Id = 'Q02_INVALID_DATE_SHOWN'; T = 'dates'; Old = '                result = DateTime.MinValue
                Return False'; New = '                result = New DateTime(2000, 1, 1)
                Return True' },
    @{ Id = 'Q03_AMERICAN_FORMAT_OUTPUT'; T = 'dates'; Old = 'Return d.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture)'; New = 'Return d.ToString("MM/dd/yyyy", CultureInfo.InvariantCulture)' },
    @{ Id = 'Q04_LIST_DATE_RAW_AGAIN'; T = 'list'; Old = '<%#: KeepStoreDates.ShortDate(Eval("DataDocumento")) %>'; New = '<%# Eval("DataDocumento", "{0:d}") %>' },
    @{ Id = 'Q05_ORDER_DATE_SOURCE_AS_TEXT'; T = 'order'; Old = 'DataDoc = KeepStoreDates.IsoText(dr("DataDocumento"))'; New = 'DataDoc = dr("DataDocumento").ToString()' },
    @{ Id = 'Q06_INPUT_BUTTON_RULE_TOO_WEAK'; T = 'acccss'; Old = "`nform input.tf-btn.tf-btn {"; New = "`nform input.tf-btn-x {" },
    @{ Id = 'Q07_SIDEBAR_BACK_ON_THE_DASHBOARD'; T = 'sidebar'; Old = '            Case "datiutente.aspx",
                 "datiutente.aspx",'; New = '            Case "myaccount.aspx",
                 "datiutente.aspx",' },
    @{ Id = 'Q08_LOGIN_WITHOUT_ENTER_KEY'; T = 'login'; Old = ' DefaultButton="btnLogin"'; New = '' },
    @{ Id = 'Q09_LOGIN_BUTTON_WHITE_TEXT_CLASS_BACK'; T = 'login'; Old = 'CssClass="tf-btn ks-login__submit"'; New = 'CssClass="tf-btn w-100 text-white"' },
    @{ Id = 'Q10_DASHBOARD_ORDER_LIST_BACK'; T = 'acc'; Old = '<nav class="ks-account-hub" aria-label="Servizi dell''account">'; New = '<asp:Repeater ID="rptRecentOrders" runat="server"></asp:Repeater><nav class="ks-account-hub" aria-label="Servizi dell''account">' },
    @{ Id = 'Q11_CART_WITHOUT_TITLE'; T = 'cart'; Old = '    Carrello'; New = '    ' }
)
foreach ($mu in $qaMutants) {
    $qd = $dates; $qa = $accAspx; $ql = $listAspx; $qo = $orderVb; $qc = $accountCss; $qs = $sidebarVb; $qg = $loginAspx; $qk = $cartAspx
    switch ($mu.T) {
        'dates' { $qd = Mutate-Text $dates $mu.Old $mu.New $mu.Id }
        'list' { $ql = Mutate-Text $listAspx $mu.Old $mu.New $mu.Id }
        'order' { $qo = Mutate-Text $orderVb $mu.Old $mu.New $mu.Id }
        'acccss' { $qc = Mutate-Text $accountCss $mu.Old $mu.New $mu.Id }
        'sidebar' { $qs = Mutate-Text $sidebarVb $mu.Old $mu.New $mu.Id }
        'login' { $qg = Mutate-Text $loginAspx $mu.Old $mu.New $mu.Id }
        'acc' { $qa = Mutate-Text $accAspx $mu.Old $mu.New $mu.Id }
        'cart' { $qk = Mutate-Text $cartAspx $mu.Old $mu.New $mu.Id }
    }
    if ($mu.T -eq 'dates') { $still = Test-Dates $qd } else { $still = Test-BrowserFindings $qa $ql $detailAspx $qo $qc $qs $qg $qk }
    Assert-Detected $still $mu.Id
}

foreach ($mu in $mutants) {
    $mm = $module; $mp = $progress; $ma = $accAspx; $mav = $accVb; $ml = $listAspx; $mlv = $listVb; $mc = $css
    switch ($mu.T) {
        'module' { $mm = Mutate-Text $module $mu.Old $mu.New $mu.Id }
        'progress' { $mp = Mutate-Text $progress $mu.Old $mu.New $mu.Id }
        'accaspx' { $ma = Mutate-Text $accAspx $mu.Old $mu.New $mu.Id }
        'accvb' { $mav = Mutate-Text $accVb $mu.Old $mu.New $mu.Id }
        'listaspx' { $ml = Mutate-Text $listAspx $mu.Old $mu.New $mu.Id }
        'listvb' { $mlv = Mutate-Text $listVb $mu.Old $mu.New $mu.Id }
        'css' { $mc = Mutate-Text $css $mu.Old $mu.New $mu.Id }
    }
    if ($mu.T -eq 'module' -or $mu.T -eq 'progress') { $still = (Test-ModuleMatrix $mm $mp) -and (Test-ModuleStructure $mm) } else { $still = Test-Pages $ma $mav $ml $mlv $mc }
    Assert-Detected $still $mu.Id
}
Write-Output ('ACCOUNT_TILES_TEST_PASS mutants=' + ($mutants.Count + $qaMutants.Count))
