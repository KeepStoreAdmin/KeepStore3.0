[CmdletBinding()]
param([switch]$SkipLab, [switch]$RequireLab, [switch]$SkipLive, [switch]$SkipMutations, [string]$Host1 = 'www.taikun.it', [int]$Port = 8443)

# KS-B02D-FOOTER-PAYMENTS-1A - il piede dice quali metodi di pagamento accetta davvero l'azienda dell'host, e solo quelli che puo dire in modo veritiero.
# Regola: pagamentitipo con Abilitato=1, Web=1 (pubblico), CostoMassimo>0, OnLine=0 (nessun gateway: PayPal, IwBank e Banca Sella dipendono da configurazione e controlli
# di sicurezza che il piede non puo verificare), Contrassegno=0 (il carrello lo disabilita secondo il vettore), costi non nulli e NESSUNA configurazione attiva in
# vbancasella_azienda (piu stretta del carrello, mai piu larga). Si legge solo AziendeID, id, Descrizione, Ordinamento: mai Informazioni (IBAN e dati di persone) ne img.
# Oracolo 1 (regione FooterPure di SiteFooter.ascx.vb compilata ed eseguita): pulizia del testo, scarti, deduplica, limite, isolamento tra aziende, gate della sessione.
# Oracolo 2 (StorefrontCanonicalHostPolicy.vb compilata): creazione e aggancio per Id azienda che compare UNA volta, elenco di sola lettura, ordine deterministico.
# Oracolo 3 (testo): il caricatore (terza lettura facoltativa, propria Try, timeout 3 s, dopo i dati societari e prima della cache, SELECT senza Informazioni),
# il collegamento nel piede e il markup (segnaposto nascosto dentro .ft-bottom, etichetta fissa una volta sola, nessuna marca di pagamento nel markup).
# Oracolo 4 (differenziale sul LAB locale, transazione annullata): la SELECT REALE del carrello (estratta da carrello.aspx) contro la SELECT REALE del piede (estratta dal
# caricatore) su righe sintetiche per ogni esclusione: il piede deve essere CONTENUTO nel carrello e coincidere con l'insieme atteso, per due aziende. Senza LAB = NON ESEGUITO.
# Oracolo 5 (Smoke, sola lettura): il piede reale ha il blocco ben formato e senza PayPal, cifre lunghe o indirizzi. Mutazioni sulle copie in memoria e sul LAB.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

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

$ascx = Read-Repo 'Public/ui/controls/SiteFooter.ascx'
$vb = Read-Repo 'Public/ui/controls/SiteFooter.ascx.vb'
$policy = Read-Repo 'App_Code/StorefrontCanonicalHostPolicy.vb'
$ctx = Read-Repo 'App_Code/StorefrontSeoTenantContext.vb'
$links = Read-Repo 'App_Code/KeepStoreContactLinks.vb'
$cartAspx = Read-Repo 'carrello.aspx'

function New-Params {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    return $p
}
function Get-PureRegion([string]$vbText) {
    $m = [regex]::Match($vbText, '(?ms)^[ \t]*#Region "FooterPure"\n(.*?)\n[ \t]*#End Region')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

# --- Oracolo 1: la regione pura del piede compilata ed eseguita -------------------------------------------------------------------------------
function Compile-Footer([string]$vbText, [string]$policyText, [string]$linksText) {
    $region = Get-PureRegion $vbText
    if ($null -eq $region) { return 'REGION_MISSING' }
    $code = @"
Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Public Class PayProbe
$region
    Private Shared Function Build(ByVal c As Integer(), ByVal i As Integer(), ByVal o As Integer(), ByVal n As String()) As IList(Of StorefrontPaymentMethod)
        Dim list As New List(Of StorefrontPaymentMethod)()
        For k As Integer = 0 To c.Length - 1
            list.Add(New StorefrontPaymentMethod(c(k), i(k), n(k), o(k)))
        Next
        Return list
    End Function
    Public Function Html(ByVal host As Integer, ByVal c As Integer(), ByVal i As Integer(), ByVal o As Integer(), ByVal n As String()) As String
        Return BuildFooterPaymentsHtml(Build(c, i, o, n), host)
    End Function
    Public Function HtmlNothing(ByVal host As Integer) As String
        Return BuildFooterPaymentsHtml(Nothing, host)
    End Function
    Public Function Gate(ByVal host As Integer, ByVal sess As Integer, ByVal c As Integer(), ByVal i As Integer(), ByVal o As Integer(), ByVal n As String()) As String
        Return BuildFooterData(host, sess, "Alfa", "", "", "", "", Nothing, Build(c, i, o, n), 2026).PaymentsHtml
    End Function
    Public Function GateNothing(ByVal host As Integer, ByVal sess As Integer) As String
        Return BuildFooterData(host, sess, "Alfa", "", "", "", "", Nothing, Nothing, 2026).PaymentsHtml
    End Function
End Class
"@
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource((New-Params), [string[]]@($policyText, $linksText, $code))
    if ($c.Errors.HasErrors) { return ('COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('PayProbe', $true))
}
function M([int[]]$c, [int[]]$i, [int[]]$o, [string[]]$n) { return @{ c = $c; i = $i; o = $o; n = $n } }
function Run-Html($p, [int]$hostId, $m) { return [string]$p.Html($hostId, [int[]]$m.c, [int[]]$m.i, [int[]]$m.o, [string[]]$m.n) }
function Run-Gate($p, [int]$hostId, [int]$sess, $m) { return [string]$p.Gate($hostId, $sess, [int[]]$m.c, [int[]]$m.i, [int[]]$m.o, [string[]]$m.n) }
function Names([string[]]$n, [int]$company = 1) { $c = @(); $i = @(); $o = @(); for ($k = 0; $k -lt $n.Count; $k++) { $c += $company; $i += (100 + $k); $o += $k }; return (M $c $i $o $n) }

function Test-FooterBehaviour([string]$vbText, [string]$policyText, [string]$linksText) {
    $p = Compile-Footer $vbText $policyText $linksText
    if ($p -is [string]) { return $p }
    $dash = [string][char]0x2013; $emdash = [string][char]0x2014; $rlo = [string][char]0x202E
    $cases = New-Object System.Collections.Generic.List[object]
    function Add-Case([string]$name, $got, [string]$expected) { $cases.Add(@{ n = $name; got = $got; exp = $expected }) }
    # positivo: l'azienda dell'host, nell'ordine dato
    Add-Case 'two_methods' (Run-Html $p 1 (Names @('Contanti', 'Bonifico Bancario'))) 'Contanti, Bonifico Bancario'
    # isolamento: le righe di un'altra azienda non compaiono mai, e compaiono per la propria
    $mix = M @(1, 2, 1) @(1, 2, 3) @(1, 1, 2) @('Contanti', 'Altra Azienda Pay', 'Bonifico Bancario')
    Add-Case 'other_company_rows_ignored' (Run-Html $p 1 $mix) 'Contanti, Bonifico Bancario'
    Add-Case 'own_rows_for_company_2' (Run-Html $p 2 $mix) 'Altra Azienda Pay'
    Add-Case 'host_without_rows' (Run-Html $p 3 $mix) ''
    Add-Case 'nothing_list' ([string]$p.HtmlNothing(1)) ''
    Add-Case 'empty_list' (Run-Html $p 1 (M @() @() @() @())) ''
    # pulizia: trattino iniziale o finale (la convenzione dell'azienda 2), anche en e em dash; quelli interni restano
    Add-Case 'leading_hyphen' (Run-Html $p 1 (Names @('-Bonifico Bancario'))) 'Bonifico Bancario'
    Add-Case 'leading_en_dash_and_trailing' (Run-Html $p 1 (Names @(($dash + ' Contanti ' + $emdash)))) 'Contanti'
    Add-Case 'inner_hyphen_kept' (Run-Html $p 1 (Names @('Pre-pagato'))) 'Pre-pagato'
    Add-Case 'other_punctuation_kept' (Run-Html $p 1 (Names @('Contanti.'))) 'Contanti.'
    Add-Case 'spaces_collapsed' (Run-Html $p 1 (Names @("Carta   di`tcredito"))) 'Carta di credito'
    Add-Case 'bidi_and_format_removed' (Run-Html $p 1 (Names @(('Con' + $rlo + 'tanti')))) 'Contanti'
    # codifica: il testo e del cliente, mai markup
    Add-Case 'html_encoded' (Run-Html $p 1 (Names @('A<script>b'))) 'A&lt;script&gt;b'
    Add-Case 'ampersand_encoded' (Run-Html $p 1 (Names @('A & B'))) 'A &amp; B'
    # scarti (mai troncamenti): ogni scarto con il suo positivo accanto
    Add-Case 'iban_like_dropped_next_kept' (Run-Html $p 1 (Names @('IT97T0103040160000000772505', 'Contanti'))) 'Contanti'
    Add-Case 'six_digits_with_separators_dropped' (Run-Html $p 1 (Names @('Pagamento 12 34-56', 'Contanti'))) 'Contanti'
    Add-Case 'five_digits_kept' (Run-Html $p 1 (Names @('Pagamento 12345'))) 'Pagamento 12345'
    Add-Case 'rimessa_30gg_kept' (Run-Html $p 1 (Names @('Rimessa Diretta 30gg'))) 'Rimessa Diretta 30gg'
    Add-Case 'at_sign_dropped' (Run-Html $p 1 (Names @('pay@x.it', 'Contanti'))) 'Contanti'
    Add-Case 'url_dropped' (Run-Html $p 1 (Names @('http://x.it', 'WWW.x.it', 'Contanti'))) 'Contanti'
    $forty = ('A' * 40); $fortyOne = ('A' * 41)
    Add-Case 'forty_chars_kept' (Run-Html $p 1 (Names @($forty))) $forty
    Add-Case 'forty_one_chars_dropped_not_truncated' (Run-Html $p 1 (Names @($fortyOne, 'Contanti'))) 'Contanti'
    Add-Case 'blank_names_skipped' (Run-Html $p 1 (Names @('   ', $null, '-', 'Contanti'))) 'Contanti'
    Add-Case 'all_invalid_gives_empty' (Run-Html $p 1 (Names @('pay@x.it', '   '))) ''
    # duplicati dopo la pulizia (senza maiuscole) e limite di 8 dopo scarti e duplicati
    Add-Case 'duplicates_case_insensitive' (Run-Html $p 1 (Names @('Contanti', 'contanti', '-CONTANTI'))) 'Contanti'
    Add-Case 'cap_of_eight' (Run-Html $p 1 (Names @('A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1', 'I1'))) 'A1, B1, C1, D1, E1, F1, G1, H1'
    Add-Case 'cap_counts_after_dropping_and_dedupe' (Run-Html $p 1 (Names @('x@y', 'A1', 'a1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1', 'I1'))) 'A1, B1, C1, D1, E1, F1, G1, H1'
    # gate dell'azienda: sessione di un'altra azienda o host sconosciuto = nessun dato; sessione assente = vale l'host
    $own = Names @('Contanti')
    Add-Case 'gate_allowed_same_session' (Run-Gate $p 1 1 $own) 'Contanti'
    Add-Case 'gate_allowed_session_not_set' (Run-Gate $p 1 0 $own) 'Contanti'
    Add-Case 'gate_other_company_session_blocks' (Run-Gate $p 1 2 $own) ''
    Add-Case 'gate_unknown_host_blocks' (Run-Gate $p 0 0 $own) ''
    Add-Case 'gate_nothing_list' ([string]$p.GateNothing(1, 1)) ''
    foreach ($c in $cases) { if (-not ($c.got -ceq $c.exp)) { return ('CASE ' + $c.n + ' got=[' + $c.got + '] expected=[' + $c.exp + ']') } }
    return 'OK'
}
$r = Test-FooterBehaviour $vb $policy $links
Assert-Source ($r -ceq 'OK') ('FP01_FOOTER_PAYMENTS_BEHAVIOUR_' + $r)

# --- Oracolo 2: la policy (creazione e aggancio) compilata ed eseguita ----------------------------------------------------------------------
function Compile-Policy([string]$policyText) {
    $code = @"
Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Linq
Public Class PolProbe
    Private Shared Function Build(ByVal c As Integer(), ByVal i As Integer(), ByVal o As Integer(), ByVal n As String()) As List(Of StorefrontPaymentMethod)
        Dim rows As New List(Of StorefrontPaymentMethod)()
        For k As Integer = 0 To c.Length - 1
            If n(k) Is Nothing AndAlso c(k) = -99 Then
                rows.Add(Nothing)
            Else
                rows.Add(New StorefrontPaymentMethod(c(k), i(k), n(k), o(k)))
            End If
        Next
        Return rows
    End Function
    Private Shared Function Idents(ByVal ids As Integer()) As List(Of StorefrontSeoTenantIdentity)
        Dim list As New List(Of StorefrontSeoTenantIdentity)()
        Dim seq As Integer = 0
        For Each id As Integer In ids
            seq += 1
            list.Add(StorefrontCanonicalHostPolicy.CreateTenant(id, "N" & id.ToString(), "", "https://h" & seq.ToString() & ".example.test", "", "", 1))
        Next
        Return list
    End Function
    Public Function Run(ByVal ids As Integer(), ByVal rowsNothing As Boolean, ByVal c As Integer(), ByVal i As Integer(), ByVal o As Integer(), ByVal n As String()) As String
        Dim list As List(Of StorefrontSeoTenantIdentity) = Idents(ids)
        Dim rows As List(Of StorefrontPaymentMethod) = Nothing
        If Not rowsNothing Then rows = Build(c, i, o, n)
        StorefrontCanonicalHostPolicy.ApplyPaymentMethods(list, rows)
        Dim parts As New List(Of String)()
        For Each identity As StorefrontSeoTenantIdentity In list
            If identity.PaymentMethods Is Nothing Then
                parts.Add(identity.CompanyId.ToString() & "=NONE")
            Else
                parts.Add(identity.CompanyId.ToString() & "=" & String.Join("|", identity.PaymentMethods.Select(Function(m) m.Name).ToArray()))
            End If
        Next
        Return String.Join(";", parts.ToArray())
    End Function
    Public Function ReadOnlyCheck() As String
        Dim list As List(Of StorefrontSeoTenantIdentity) = Idents(New Integer() {1})
        StorefrontCanonicalHostPolicy.ApplyPaymentMethods(list, Build(New Integer() {1}, New Integer() {1}, New Integer() {1}, New String() {"A"}))
        Dim shared1 As IList(Of StorefrontPaymentMethod) = list(0).PaymentMethods
        Try
            shared1.Add(New StorefrontPaymentMethod(1, 9, "Z", 1))
            Return "MODIFIABLE"
        Catch ex As NotSupportedException
            Return "READONLY"
        End Try
    End Function
    Public Function NullListIsSafe() As String
        StorefrontCanonicalHostPolicy.ApplyPaymentMethods(Nothing, New List(Of StorefrontPaymentMethod)())
        Return "OK"
    End Function
    Public Function Create(ByVal company As String, ByVal id As String, ByVal name As String, ByVal ord As String) As String
        Dim m As StorefrontPaymentMethod = StorefrontCanonicalHostPolicy.CreatePaymentMethod(Function(col As String) If(col = "AziendeID", company, If(col = "id", id, If(col = "Descrizione", name, If(col = "Ordinamento", ord, Nothing)))))
        If m Is Nothing Then Return "NOTHING"
        Return m.CompanyId.ToString() & "|" & m.MethodId.ToString() & "|" & m.Name & "|" & m.Order.ToString()
    End Function
End Class
"@
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource((New-Params), [string[]]@($policyText, $code))
    if ($c.Errors.HasErrors) { return ('COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('PolProbe', $true))
}
function Run-Policy($p, [int[]]$ids, [bool]$rowsNothing, $m) {
    if ($null -eq $m) { $m = (M @() @() @() @()) }
    return [string]$p.Run($ids, $rowsNothing, [int[]]$m.c, [int[]]$m.i, [int[]]$m.o, [string[]]$m.n)
}
function Test-PolicyBehaviour([string]$policyText) {
    $p = Compile-Policy $policyText
    if ($p -is [string]) { return $p }
    $cases = New-Object System.Collections.Generic.List[object]
    function Add-Case([string]$name, [string]$got, [string]$expected) { $cases.Add(@{ n = $name; got = $got; exp = $expected }) }
    $two = M @(1, 2) @(10, 20) @(1, 1) @('Contanti', 'Bonifico')
    Add-Case 'attach_by_company' (Run-Policy $p @(1, 2) $false $two) '1=Contanti;2=Bonifico'
    Add-Case 'no_cross_company' (Run-Policy $p @(1, 2) $false (M @(1) @(10) @(1) @('A'))) '1=A;2='
    Add-Case 'rows_nothing_means_none' (Run-Policy $p @(1, 2) $true $null) '1=NONE;2=NONE'
    Add-Case 'duplicate_identity_id_none' (Run-Policy $p @(1, 1, 2) $false (M @(1, 2) @(10, 20) @(1, 1) @('A', 'B'))) '1=NONE;1=NONE;2=B'
    Add-Case 'company_not_in_rows_gets_empty' (Run-Policy $p @(3) $false (M @(1) @(10) @(1) @('A'))) '3='
    Add-Case 'deterministic_order' (Run-Policy $p @(1) $false (M @(1, 1, 1, 1) @(3, 4, 2, 1) @(1, 2, 2, 2) @('Zeta', 'beta', 'alfa', 'Beta'))) '1=Zeta|alfa|Beta|beta'
    Add-Case 'invalid_rows_ignored' (Run-Policy $p @(1) $false (M @(-99, 0, 1) @(1, 2, 3) @(1, 1, 1) @($null, 'Zero', 'Ok'))) '1=Ok'
    Add-Case 'create_maps_columns' ([string]$p.Create('1', '10', ' Contanti ', '3')) '1|10|Contanti|3'
    Add-Case 'create_rejects_bad_company' ([string]$p.Create('0', '10', 'A', '1')) 'NOTHING'
    Add-Case 'create_rejects_bad_id' ([string]$p.Create('1', '0', 'A', '1')) 'NOTHING'
    Add-Case 'create_rejects_blank_name' ([string]$p.Create('1', '10', '   ', '1')) 'NOTHING'
    Add-Case 'create_order_defaults_to_zero' ([string]$p.Create('1', '10', 'A', 'x')) '1|10|A|0'
    Add-Case 'list_is_readonly' ([string]$p.ReadOnlyCheck()) 'READONLY'
    Add-Case 'null_identities_safe' ([string]$p.NullListIsSafe()) 'OK'
    foreach ($c in $cases) { if (-not ($c.got -ceq $c.exp)) { return ('CASE ' + $c.n + ' got=[' + $c.got + '] expected=[' + $c.exp + ']') } }
    return 'OK'
}
$r = Test-PolicyBehaviour $policy
Assert-Source ($r -ceq 'OK') ('FP02_POLICY_ATTACH_AND_MAPPING_' + $r)

# --- Oracolo 3: testo (caricatore, collegamento, markup) ---------------------------------------------------------------------------------------
function Get-FooterSql([string]$c) {
    $m = [regex]::Match($c, '(?m)^\s*Private Const PaymentMethodsSql As String = "([^"\r\n]*)"\s*$')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Test-Context([string]$c) {
    $sql = Get-FooterSql $c
    if ($null -eq $sql) { return 'NO_SQL_CONSTANT' }
    # ogni predicato della regola, una volta sola, e le sole colonne lette
    foreach ($frag in @('FROM pagamentitipo p', 'p.Abilitato=1', 'p.Web=1', 'p.CostoMassimo>0', 'p.OnLine=0', 'COALESCE(p.Contrassegno,0)=0', 'p.CostoPercentuale IS NOT NULL', 'p.CostoFisso IS NOT NULL',
                        'NOT EXISTS (SELECT 1 FROM vbancasella_azienda b WHERE b.AziendeId=p.AziendeID AND b.PagamentiTipoId=p.id)', 'ORDER BY p.AziendeID, p.Ordinamento, p.Descrizione, p.id')) {
        if (([regex]::Matches($sql, [regex]::Escape($frag))).Count -ne 1) { return ('FRAGMENT_' + $frag) }
    }
    if ($sql -notmatch '^SELECT p\.AziendeID, p\.id, p\.Descrizione, p\.Ordinamento FROM ') { return 'COLUMNS' }
    if ($sql -match '(?i)Informazioni|\bimg\b|\bSELECT \*|p\.\*') { return 'SENSITIVE_OR_STAR' }
    if (([regex]::Matches($c, 'SELECT ')).Count -ne 5) { return 'SELECT_COUNT' }
    # dopo i dati societari, prima della cache, dentro la stessa connessione e con il primo reader gia chiuso
    if ($c -cnotmatch '(?s)End While\s+End Using\s+End Using\s+AttachLegalProfiles\(connection, result\)\s+AttachPaymentMethods\(connection, result\)\s+End Using\s+HttpRuntime\.Cache\.Insert') { return 'ORDER' }
    $a = [regex]::Match($c, '(?ms)^    Private Shared Sub AttachPaymentMethods\(.*?^    End Sub')
    if (-not $a.Success) { return 'NO_ATTACH' }
    if ($a.Value -cnotmatch '(?s)Try\s+Dim methods As List\(Of StorefrontPaymentMethod\) = ReadPaymentMethods\(connection\)\s+StorefrontCanonicalHostPolicy\.ApplyPaymentMethods\(identities, methods\)\s+Catch') { return 'ATTACH_TRY' }
    if ($a.Value -match 'Clear\(|Throw') { return 'ATTACH_CLEARS_OR_THROWS' }
    $r = [regex]::Match($c, '(?ms)^    Private Shared Function ReadPaymentMethods\(.*?^    End Function')
    if (-not $r.Success) { return 'NO_READ' }
    $b = $r.Value
    $iTry = $b.IndexOf("        Try`n"); $iWhile = $b.IndexOf('While reader.Read()'); $iReturn = $b.IndexOf("            Return methods`n"); $iCatch = $b.IndexOf("        Catch`n")
    if ($iTry -lt 0 -or $iWhile -lt $iTry -or $iReturn -lt $iWhile -or $iCatch -lt $iReturn) { return 'READ_SHAPE' }
    if ($b -cnotmatch '(?m)^\s*command\.CommandTimeout = 3\s*$') { return 'TIMEOUT_NOT_EXACTLY_3' }
    foreach ($line in @('New MySqlCommand(PaymentMethodsSql, connection)', 'StorefrontCanonicalHostPolicy.CreatePaymentMethod(Function(name As String) SafeReaderString(reader, name))', 'If method IsNot Nothing Then methods.Add(method)')) {
        if ($b.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return ('READ_LINE_' + $line) }
    }
    if ($b -cnotmatch '(?s)Catch\s+Return Nothing\s+End Try') { return 'READ_CATCH' }
    if ($b.Contains('ApplyPaymentMethods')) { return 'READ_APPLIES' }
    if ($c -match '(?is)Session\(|CodiceFiscale') { return 'SESSION_OR_PII' }
    if ($c -match '[^\x00-\x7F]') { return 'NON_ASCII' }
    return 'OK'
}
$r = Test-Context $ctx
Assert-Source ($r -ceq 'OK') ('FP03_LOADER_THIRD_OPTIONAL_READ_SAFE_SELECT_' + $r)

function Test-Glue([string]$v) {
    foreach ($line in @('payments = tenant.PaymentMethods', 'BindFooterPayments(data)', 'phFooterPayments.Visible = data.PaymentsHtml.Length > 0', 'litFooterPayments.Text = data.PaymentsHtml',
                        'Dim payments As IList(Of StorefrontPaymentMethod) = Nothing')) {
        if ($v.IndexOf($line, [StringComparison]::Ordinal) -lt 0) { return ('LINE_' + $line) }
    }
    if ($v -notmatch 'Dim data As FooterData = BuildFooterData\(hostCompanyId, SessionCompanyId\(\), companyName, logoFileName, phone, email, facebookRaw, legalProfile, payments, DateTime\.Now\.Year\)') { return 'CALL' }
    # i metodi si costruiscono SOLO nel ramo consentito (host valido e sessione non di un'altra azienda)
    $m = [regex]::Match($v, '(?s)If IsFooterTenantAllowed\(hostCompanyId, sessionCompanyId\) Then(.*?)Else')
    if (-not $m.Success -or $m.Groups[1].Value.IndexOf('data.PaymentsHtml = BuildFooterPaymentsHtml(payments, hostCompanyId)', [StringComparison]::Ordinal) -lt 0) { return 'NOT_INSIDE_GATE' }
    if ([regex]::Matches($v, 'data\.PaymentsHtml = ').Count -ne 1) { return 'ASSIGNED_TWICE' }
    if ($v -match '(?i)\b(Visa|PayPal|Mastercard|Maestro|Discover|Satispay)\b|Pagamenti accettati') { return 'BRAND_WORD' }
    if ($v -match '[^\x00-\x7F]') { return 'NON_ASCII' }
    return 'OK'
}
$r = Test-Glue $vb
Assert-Source ($r -ceq 'OK') ('FP04_FOOTER_LINKS_PAYMENTS_ONLY_INSIDE_THE_HOST_GATE_' + $r)

function Test-Markup([string]$a) {
    $one = '<asp:PlaceHolder ID="phFooterPayments" runat="server" Visible="false">\s*<p class="caption text-center text-break ft-payments">Metodi di pagamento: <asp:Literal ID="litFooterPayments" runat="server" EnableViewState="False" /></p>\s*</asp:PlaceHolder>'
    if ([regex]::Matches($a, 'phFooterPayments').Count -ne 1 -or [regex]::Matches($a, 'litFooterPayments').Count -ne 1 -or [regex]::Matches($a, 'Metodi di pagamento').Count -ne 1) { return 'COUNT' }
    # dentro .ft-bottom, dopo il menu e PRIMA del blocco dei dati societari
    if ($a -cnotmatch ('(?s)<div class="ft-bottom">.*?<ul class="ft-menu-list-2.*?</ul>\s*' + $one + '\s*<asp:PlaceHolder ID="phFooterLegal"')) { return 'POSITION' }
    if ($a -match '(?i)\b(Visa|PayPal|Mastercard|Maestro|Discover|Satispay|IBAN)\b') { return 'BRAND_WORD' }
    return 'OK'
}
$r = Test-Markup $ascx
Assert-Source ($r -ceq 'OK') ('FP05_MARKUP_HIDDEN_PLACEHOLDER_INSIDE_BOTTOM_ROW_BEFORE_LEGAL_' + $r)

# il collegamento con l'identita: la proprieta esiste, e la policy e il caricatore la chiamano
Assert-Source ($policy -match 'Public Property PaymentMethods As IList\(Of StorefrontPaymentMethod\)') 'FP06_IDENTITY_CARRIES_THE_PAYMENT_METHODS'
Assert-Source (($policy + $ctx + $vb + $ascx) -notmatch '(?i)onsus') 'FP07_NO_TEMPLATE_NAME'

function Safe([scriptblock]$s) { try { return [bool](& $s) } catch { return $false } }
function Dm([string]$code, [bool]$passes) { Assert-Detected $passes $code }

# --- Mutazioni sulle copie in memoria (comportamento compilato e testo) -------------------------------------------------------------------
if (-not $SkipMutations) {
    # piede (regione compilata)
    $x = Mutate-Text $vb 'If method.CompanyId <> hostCompanyId Then Continue For' 'If False Then Continue For' 'V1'
    Dm 'V1_OTHER_COMPANY_ROWS_SHOWN' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'data.PaymentsHtml = BuildFooterPaymentsHtml(payments, hostCompanyId)' 'data.PaymentsHtml = String.Empty' 'V2'
    Dm 'V2_RESULT_NEVER_SET' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Const PaymentNameMax As Integer = 40' 'Const PaymentNameMax As Integer = 60' 'V3'
    Dm 'V3_LENGTH_LIMIT_CHANGED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Const PaymentMax As Integer = 8' 'Const PaymentMax As Integer = 9' 'V4'
    Dm 'V4_COUNT_LIMIT_CHANGED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Const PaymentDigitsMax As Integer = 5' 'Const PaymentDigitsMax As Integer = 99' 'V5'
    Dm 'V5_DIGIT_RULE_OFF' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'names.Add(HttpUtility.HtmlEncode(name))' 'names.Add(name)' 'V6'
    Dm 'V6_TEXT_NOT_ENCODED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)' 'Dim seen As New HashSet(Of String)(StringComparer.Ordinal)' 'V7'
    Dm 'V7_DUPLICATES_CASE_SENSITIVE' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'If sessionCompanyId > 0 AndAlso sessionCompanyId <> tenantCompanyId Then Return False' 'If False Then Return False' 'V8'
    Dm 'V8_SESSION_OF_OTHER_COMPANY_ALLOWED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'name.IndexOf("@"c) >= 0 OrElse ' '' 'V9'
    Dm 'V9_AT_SIGN_NOT_DROPPED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'OrElse name.IndexOf("://", StringComparison.Ordinal) >= 0' '' 'V10'
    Dm 'V10_URL_NOT_DROPPED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Dim name As String = CleanLegalText(value).Trim(trimChars)' 'Dim name As String = value.Trim(trimChars)' 'V11'
    Dm 'V11_TEXT_NOT_CLEANED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Dim trimChars As Char() = New Char() {" "c, "-"c, ChrW(8211), ChrW(8212)}' 'Dim trimChars As Char() = New Char() {" "c}' 'V12'
    Dm 'V12_DASH_NOT_TRIMMED' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'Dim trimChars As Char() = New Char() {" "c, "-"c, ChrW(8211), ChrW(8212)}' 'Dim trimChars As Char() = New Char() {" "c, "-"c, "."c, ChrW(8211), ChrW(8212)}' 'V13'
    Dm 'V13_TRIMS_OTHER_PUNCTUATION' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'If name.Length = 0 OrElse Not seen.Add(name) Then Continue For' 'If name.Length = 0 Then Continue For' 'V14'
    Dm 'V14_NO_DEDUPE' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    $x = Mutate-Text $vb 'If names.Count >= PaymentMax Then Exit For' 'If names.Count >= 99 Then Exit For' 'V15'
    Dm 'V15_NO_CAP_AFTER_CLEANING' (Safe { (Test-FooterBehaviour $x $policy $links) -ceq 'OK' })
    # collegamento e markup
    $x = Mutate-Text $vb 'phFooterPayments.Visible = data.PaymentsHtml.Length > 0' 'phFooterPayments.Visible = False' 'G1'
    Dm 'G1_PLACEHOLDER_NEVER_SHOWN' (Safe { (Test-Glue $x) -ceq 'OK' })
    $x = Mutate-Text $vb 'payments = tenant.PaymentMethods' 'payments = Nothing' 'G2'
    Dm 'G2_IDENTITY_NEVER_READ' (Safe { (Test-Glue $x) -ceq 'OK' })
    $x = Mutate-Text $vb 'litFooterPayments.Text = data.PaymentsHtml' 'litFooterPayments.Text = String.Empty' 'G3'
    Dm 'G3_LITERAL_NEVER_FILLED' (Safe { (Test-Glue $x) -ceq 'OK' })
    $x = Mutate-Text $vb "        Else`n            data.ContactsHtml = BuildFooterContactsHtml(String.Empty, String.Empty, String.Empty)" "        Else`n            data.PaymentsHtml = BuildFooterPaymentsHtml(payments, hostCompanyId)`n            data.ContactsHtml = BuildFooterContactsHtml(String.Empty, String.Empty, String.Empty)" 'G4'
    Dm 'G4_PAYMENTS_ALSO_OUTSIDE_THE_GATE' (Safe { ((Test-Glue $x) -ceq 'OK') -and ((Test-FooterBehaviour $x $policy $links) -ceq 'OK') })
    $x = Mutate-Text $ascx '<asp:PlaceHolder ID="phFooterPayments" runat="server" Visible="false">' '<asp:PlaceHolder ID="phFooterPayments" runat="server" Visible="true">' 'A1'
    Dm 'A1_LABEL_ALWAYS_VISIBLE' (Safe { (Test-Markup $x) -ceq 'OK' })
    $x = Mutate-Text $ascx 'Metodi di pagamento: ' 'Pagamenti accettati: ' 'A2'
    Dm 'A2_LABEL_CHANGED' (Safe { (Test-Markup $x) -ceq 'OK' })
    # policy (compilata)
    $x = Mutate-Text $policy ' AndAlso identityCounts(companyId) = 1 Then' ' Then' 'P1'
    Dm 'P1_DUPLICATE_IDENTITY_GETS_THE_LIST' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'bucket.OrderBy(Function(m) m.Order).ThenBy(Function(m) m.Name, StringComparer.OrdinalIgnoreCase).ThenBy(Function(m) m.MethodId)' 'bucket' 'P2'
    Dm 'P2_NO_SORT' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'bucket.OrderBy(Function(m) m.Order).ThenBy(Function(m) m.Name, StringComparer.OrdinalIgnoreCase)' 'bucket.OrderBy(Function(m) m.Order).ThenBy(Function(m) m.Name, StringComparer.Ordinal)' 'P3'
    Dm 'P3_SORT_CASE_SENSITIVE' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy '.ThenBy(Function(m) m.MethodId)' '' 'P4'
    Dm 'P4_NO_ID_TIEBREAK' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'bucket.OrderBy(Function(m) m.Order).ThenBy' 'bucket.OrderBy(Function(m) 0).ThenBy' 'P5'
    Dm 'P5_ORDER_COLUMN_IGNORED' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'New ReadOnlyCollection(Of StorefrontPaymentMethod)(ordered)' 'ordered' 'P6'
    Dm 'P6_LIST_MODIFIABLE' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'OrElse methodId <= 0 ' '' 'P7'
    Dm 'P7_BAD_METHOD_ID_ACCEPTED' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'If methods IsNot Nothing Then' 'If True Then' 'P8'
    Dm 'P8_FAILED_READ_NOT_DISTINGUISHED' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    $x = Mutate-Text $policy 'If byCompany.TryGetValue(companyId, bucket) Then' 'If byCompany.Count > 0 Then bucket = byCompany.Values.First()' 'P9'
    Dm 'P9_ATTACH_NOT_BY_COMPANY' (Safe { (Test-PolicyBehaviour $x) -ceq 'OK' })
    # caricatore (testo)
    $x = Mutate-Text $ctx 'command.CommandTimeout = 3' 'command.CommandTimeout = 30' 'C1'
    Dm 'C1_LONG_TIMEOUT' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'p.Descrizione, p.Ordinamento FROM pagamentitipo p' 'p.Descrizione, p.Informazioni, p.Ordinamento FROM pagamentitipo p' 'C2'
    Dm 'C2_READS_INFORMAZIONI' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'AND p.OnLine=0 AND' 'AND p.OnLine IN (0,3) AND' 'C3'
    Dm 'C3_GATEWAY_METHODS_LISTED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'AND p.Web=1 AND' 'AND' 'C4'
    Dm 'C4_NON_PUBLIC_LISTED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'WHERE p.Abilitato=1 AND' 'WHERE' 'C5'
    Dm 'C5_DISABLED_LISTED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx ' AND COALESCE(p.Contrassegno,0)=0' '' 'C6'
    Dm 'C6_CASH_ON_DELIVERY_LISTED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'b.PagamentiTipoId=p.id)' 'b.PagamentiTipoId=b.PagamentiTipoId)' 'C7'
    Dm 'C7_BANK_RULE_NOT_CORRELATED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx "AttachLegalProfiles(connection, result)`n                AttachPaymentMethods(connection, result)" "AttachPaymentMethods(connection, result)`n                AttachLegalProfiles(connection, result)" 'C8'
    Dm 'C8_READ_ORDER_SWAPPED' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx "        Try`n            Dim methods As List(Of StorefrontPaymentMethod) = ReadPaymentMethods(connection)" "        Dim methods As List(Of StorefrontPaymentMethod) = ReadPaymentMethods(connection)`n        Try" 'C9'
    Dm 'C9_READ_OUTSIDE_THE_TRY' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx "            Return methods`n        Catch`n            Return Nothing" "            Return methods`n        Catch`n            Return New List(Of StorefrontPaymentMethod)()" 'C10'
    Dm 'C10_FAILED_READ_GIVES_AN_EMPTY_LIST' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx "' lettura facoltativa: un guasto qui non toglie nulla alle altre informazioni dell'identita" 'identities.Clear()' 'C11'
    Dm 'C11_FAILURE_CLEARS_THE_IDENTITIES' (Safe { (Test-Context $x) -ceq 'OK' })
    $x = Mutate-Text $ctx 'ORDER BY p.AziendeID, p.Ordinamento, p.Descrizione, p.id' 'ORDER BY p.AziendeID, p.Descrizione, p.id' 'C12'
    Dm 'C12_ORDER_BY_CHANGED' (Safe { (Test-Context $x) -ceq 'OK' })
}

# --- Oracolo 4: differenziale sul LAB (carrello REALE contro piede REALE) ------------------------------------------------------------------------
function Get-CartSql([string]$aspx) {
    $m = [regex]::Match($aspx, '(?s)ID="sdsPagamento".*?SelectCommand="([^"]*)"')
    if (-not $m.Success) { return $null }
    $s = $m.Groups[1].Value.Replace('&gt;', '>').Replace('&lt;', '<').Replace('&quot;', '"').Replace('&amp;', '&')
    return $s.Replace('?UtenteID', '@UtenteID').Replace('?CostoMassimo', '@CostoMassimo').Replace('?AziendaID', '@AziendaID')
}
function Test-LabAvailable {
    if (-not (Test-Path -LiteralPath (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'))) { return $false }
    try {
        $c = New-Object Net.Sockets.TcpClient
        $iar = $c.BeginConnect('127.0.0.1', 13317, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(1500) -and $c.Connected
        $c.Close()
        return $ok
    } catch { return $false }
}
function Invoke-Lab([string]$sql, [bool]$write) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('ks-footer-pay-' + [Guid]::NewGuid().ToString('N') + '.sql')
    try {
        [IO.File]::WriteAllText($tmp, $sql, (New-Object Text.UTF8Encoding($false)))
        $args1 = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', (Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1'), '-SqlFile', $tmp)
        if ($write) { $args1 += '-Write' }
        $out = & powershell.exe @args1 2>&1 | Out-String
        return $out
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
# righe sintetiche: ogni esclusione del piede ha la sua riga; cart/footer sono le attese per un cliente anonimo (nessuna riga utentirapporto, totale 0,01)
$fx = @(
    @{ id = 9001; az = 1; d = 'Contanti';                       ab = 1; web = 1; ord = 1;  cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $true;  foot = $true  },
    @{ id = 9002; az = 1; d = '-Bonifico Bancario';             ab = 1; web = 1; ord = 2;  cp = '0';    cf = '0';    cm = '999999'; co = 0; ol = 0; cart = $true;  foot = $true  },
    @{ id = 9003; az = 1; d = 'PayPal fixture';                 ab = 1; web = 1; ord = 3;  cp = '0';    cf = '0';    cm = '1000';   co = 0; ol = 2; cart = $true;  foot = $false },
    @{ id = 9004; az = 1; d = 'Solo clienti collegati';         ab = 1; web = 0; ord = 4;  cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9005; az = 1; d = 'Disabilitato';                   ab = 0; web = 1; ord = 5;  cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9006; az = 1; d = 'Tetto zero';                     ab = 1; web = 1; ord = 6;  cp = '0';    cf = '0';    cm = '0';      co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9007; az = 1; d = 'Carta online configurata';       ab = 1; web = 1; ord = 7;  cp = '0';    cf = '0';    cm = '5000';   co = 0; ol = 3; cart = $true;  foot = $false },
    @{ id = 9008; az = 1; d = 'Carta online senza config';      ab = 1; web = 1; ord = 8;  cp = '0';    cf = '0';    cm = '5000';   co = 0; ol = 3; cart = $true;  foot = $false },
    @{ id = 9009; az = 1; d = 'Offline con config valida';      ab = 1; web = 1; ord = 9;  cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $true;  foot = $false },
    @{ id = 9010; az = 1; d = 'Offline con config senza login'; ab = 1; web = 1; ord = 10; cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9011; az = 1; d = 'IwBank fixture';                 ab = 1; web = 1; ord = 11; cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 1; cart = $true;  foot = $false },
    @{ id = 9012; az = 1; d = 'Contrassegno fixture';           ab = 1; web = 1; ord = 12; cp = '0';    cf = '0';    cm = '999';    co = 1; ol = 0; cart = $true;  foot = $false },
    @{ id = 9013; az = 1; d = 'Costo fisso nullo';              ab = 1; web = 1; ord = 13; cp = '0';    cf = 'NULL'; cm = '999';    co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9014; az = 1; d = 'Percentuale nulla';              ab = 1; web = 1; ord = 14; cp = 'NULL'; cf = '0';    cm = '999';    co = 0; ol = 0; cart = $false; foot = $false },
    @{ id = 9015; az = 2; d = 'Bonifico azienda due';           ab = 1; web = 1; ord = 1;  cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $true;  foot = $true  },
    @{ id = 9016; az = 1; d = 'Offline con due config';         ab = 1; web = 1; ord = 16; cp = '0';    cf = '0';    cm = '999';    co = 0; ol = 0; cart = $false; foot = $false }
)
$bankRows = @( @(1, 9007, 'S1'), @(1, 9009, 'S2'), @(1, 9010, ''), @(1, 9016, 'A'), @(1, 9016, 'B') )
function Build-LabSql([string]$cartSql, [string]$footerSql) {
    $values = ($fx | ForEach-Object { '(' + $_.id + ', ' + $_.az + ", '" + $_.d.Replace("'", "''") + "', 'LAB fixture', " + $_.ab + ', ' + $_.web + ', ' + $_.ord + ', 0, ' + $_.cp + ', ' + $_.cf + ', ' + $_.cm + ', 0, ' + $_.co + ', ' + $_.ol + ')' }) -join ",`n"
    $bank = ($bankRows | ForEach-Object { '(' + $_[0] + ', ' + $_[1] + ", '" + $_[2] + "', 1)" }) -join ', '
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('START TRANSACTION;')
    [void]$sb.AppendLine('INSERT INTO pagamentitipo (id, AziendeID, Descrizione, Informazioni, Abilitato, Web, Ordinamento, Predefinito, CostoPercentuale, CostoFisso, CostoMassimo, NumeroOrdini, Contrassegno, OnLine) VALUES')
    [void]$sb.AppendLine($values + ';')
    [void]$sb.AppendLine('INSERT INTO bancasella_impostazioni_azienda (AziendeId, PagamentiTipoId, shopLogin, Attivo) VALUES ' + $bank + ';')
    [void]$sb.AppendLine('SET @UtenteID = 0, @CostoMassimo = 0.01;')
    foreach ($az in 1, 2) {
        [void]$sb.AppendLine('SET @AziendaID = ' + $az + ';')
        [void]$sb.AppendLine("SELECT 'cart' AS side, c.AziendeID AS az, c.id AS pid FROM (" + $cartSql + ') c WHERE c.id >= 9000 ORDER BY c.id;')
    }
    [void]$sb.AppendLine("SELECT 'MARK_FOOTER_BEGIN' AS mark;")
    [void]$sb.AppendLine($footerSql + ';')
    [void]$sb.AppendLine("SELECT 'MARK_FOOTER_END' AS mark;")
    [void]$sb.AppendLine('ROLLBACK;')
    [void]$sb.AppendLine("SELECT 'after_rollback' AS side, COUNT(*) AS n FROM pagamentitipo WHERE id >= 9000;")
    [void]$sb.AppendLine("SELECT 'bank_after_rollback' AS side, COUNT(*) AS n FROM bancasella_impostazioni_azienda WHERE PagamentiTipoId >= 9000;")
    return $sb.ToString()
}
function Parse-Lab([string]$out) {
    $r = @{ ok = $false; cart = @{ 1 = @(); 2 = @() }; footer = @(); after = -1; bankAfter = -1; raw = $out }
    if ($out -notmatch 'client exit=0') { return $r }
    $inFooter = $false; $cartSeen = 0
    foreach ($line in ($out -split "`r?`n")) {
        $f = $line -split "`t"
        if ($f[0] -ceq 'MARK_FOOTER_BEGIN') { $inFooter = $true; continue }
        if ($f[0] -ceq 'MARK_FOOTER_END') { $inFooter = $false; continue }
        if ($f[0] -ceq 'cart' -and $f.Count -ge 3) { $az = [int]$f[1]; $r.cart[$az] += [int]$f[2]; continue }
        if ($f[0] -ceq 'after_rollback' -and $f.Count -ge 2) { $r.after = [int]$f[1]; continue }
        if ($f[0] -ceq 'bank_after_rollback' -and $f.Count -ge 2) { $r.bankAfter = [int]$f[1]; continue }
        if ($inFooter -and $f.Count -ge 2 -and $f[0] -match '^\d+$' -and $f[1] -match '^\d+$' -and [int]$f[1] -ge 9000) { $r.footer += ,@([int]$f[0], [int]$f[1]) }
    }
    $r.ok = ($r.after -eq 0 -and $r.bankAfter -eq 0)
    return $r
}
function Test-Differential($res) {
    if (-not $res.ok) { return 'RUN_FAILED_OR_NOT_ROLLED_BACK' }
    foreach ($az in 1, 2) {
        $expectCart = @($fx | Where-Object { $_.az -eq $az -and $_.cart } | ForEach-Object { [int]$_.id } | Sort-Object)
        $gotCart = @($res.cart[$az] | Sort-Object)
        if (($expectCart -join ',') -cne ($gotCart -join ',')) { return ('CART_SET_' + $az + ' got=' + ($gotCart -join ',') + ' expected=' + ($expectCart -join ',')) }
    }
    $expectFooter = @($fx | Where-Object { $_.foot } | Sort-Object { $_.az }, { $_.ord } | ForEach-Object { [string]$_.az + ':' + [string]$_.id })
    $gotFooter = @($res.footer | ForEach-Object { [string]$_[0] + ':' + [string]$_[1] })
    if (($expectFooter -join ',') -cne ($gotFooter -join ',')) { return ('FOOTER_ROWS got=' + ($gotFooter -join ',') + ' expected=' + ($expectFooter -join ',')) }
    foreach ($row in $res.footer) {
        if (@($res.cart[[int]$row[0]]) -notcontains [int]$row[1]) { return ('FOOTER_NOT_IN_CART ' + $row[0] + ':' + $row[1]) }
    }
    return 'OK'
}
$labRan = $false
if ($SkipLab) {
    Write-Output 'NOT_EXECUTED lab differential (-SkipLab)'
} elseif (-not (Test-LabAvailable)) {
    if ($RequireLab) { throw 'LAB_REQUIRED_BUT_UNAVAILABLE' }
    Write-Output 'NOT_EXECUTED lab differential (LAB non raggiungibile o credenziale assente): il piede NON e provato contro il carrello'
} else {
    $idOut = Invoke-Lab "SELECT @@server_uuid AS uuid, DATABASE() AS db;`nSELECT TABLE_NAME, ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('pagamentitipo','bancasella_impostazioni_azienda') ORDER BY TABLE_NAME;`n" $false
    Assert-Source ($idOut -match '1167ebae-d0c0-11f1-b348-9c7bef540c10\s+keepstore_regorder_lab_20261025') 'FP10_LAB_IDENTITY_IS_THE_ISOLATED_LAB'
    Assert-Source (([regex]::Matches($idOut, 'InnoDB')).Count -eq 2) 'FP11_BOTH_TABLES_ARE_TRANSACTIONAL'
    $cartSql = Get-CartSql $cartAspx
    Assert-Source (($null -ne $cartSql) -and $cartSql.Contains('WITH eligible_payment AS') -and $cartSql.Contains('@UtenteID') -and $cartSql.Contains('@AziendaID') -and $cartSql.Contains('@CostoMassimo')) 'FP12_THE_REAL_CART_SELECT_WAS_EXTRACTED'
    $footerSql = Get-FooterSql $ctx
    $res = Parse-Lab (Invoke-Lab (Build-LabSql $cartSql $footerSql) $true)
    $d = Test-Differential $res
    Assert-Source ($d -ceq 'OK') ('FP13_LAB_DIFFERENTIAL_FOOTER_IS_INSIDE_THE_CART_AND_EQUALS_THE_EXPECTED_SET_' + $d)
    $labRan = $true
    if (-not $SkipMutations) {
        $lab = @(
            @('L1_DISABLED_LISTED', 'p.Abilitato=1 AND ', ''),
            @('L2_NON_PUBLIC_LISTED', 'p.Web=1 AND ', ''),
            @('L3_ZERO_CAP_LISTED', 'p.CostoMassimo>0 AND ', ''),
            @('L4_GATEWAY_METHODS_LISTED', 'p.OnLine=0 AND ', 'p.OnLine>=0 AND '),
            @('L5_CASH_ON_DELIVERY_LISTED', 'COALESCE(p.Contrassegno,0)=0 AND ', ''),
            @('L6_NULL_COSTS_LISTED', 'p.CostoPercentuale IS NOT NULL AND p.CostoFisso IS NOT NULL AND ', ''),
            @('L7_BANK_CONFIG_IGNORED', ' AND NOT EXISTS (SELECT 1 FROM vbancasella_azienda b WHERE b.AziendeId=p.AziendeID AND b.PagamentiTipoId=p.id)', ''),
            @('L8_BANK_RULE_NOT_CORRELATED_TO_THE_METHOD', 'b.PagamentiTipoId=p.id', '1=1'),
            @('L9_ORDER_IGNORES_ORDINAMENTO', 'p.Ordinamento, ', ''),
            @('L10_COMPANY_COLUMN_FORGED', 'SELECT p.AziendeID, p.id,', 'SELECT 1 AS AziendeID, p.id,')
        )
        foreach ($mut in $lab) {
            $mSql = $footerSql.Replace($mut[1], $mut[2])
            if ($mSql -ceq $footerSql) { throw ('MUTATION_NOT_APPLIED=' + $mut[0]) }
            $mres = Parse-Lab (Invoke-Lab (Build-LabSql $cartSql $mSql) $true)
            if (-not $mres.ok) { throw ('MUTANT_NOT_EXECUTABLE=' + $mut[0]) }
            Dm $mut[0] ((Test-Differential $mres) -ceq 'OK')
        }
    }
    $clean = Invoke-Lab "SELECT COUNT(*) AS leftovers FROM pagamentitipo WHERE id >= 9000;`nSELECT COUNT(*) AS bank_leftovers FROM bancasella_impostazioni_azienda WHERE PagamentiTipoId >= 9000;`n" $false
    Assert-Source ($clean -match "leftovers\s+0\s+bank_leftovers\s+0") 'FP14_LAB_LEFT_CLEAN_AFTER_ALL_RUNS'
}

# --- Oracolo 5: il piede reale su Smoke (sola lettura) ---------------------------------------------------------------------------------------
if ($SkipLive) {
    Write-Output 'NOT_EXECUTED live Smoke footer check (-SkipLive)'
} else {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        $url = 'https://' + $Host1 + ':' + $Port + '/Default.aspx'
        $args1 = @('--noproxy', '*', '--resolve', ($Host1 + ':' + $Port + ':127.0.0.1'), '-s', '--max-time', '170', '-o', $tmp, '-w', '%{http_code}', $url)
        $code = (& curl.exe @args1)
        Assert-Source ($code -eq '200') 'FP15_SMOKE_HOME_FETCHED'
        $html = [IO.File]::ReadAllText($tmp)
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    $blocks = [regex]::Matches($html, '<p class="caption text-center text-break ft-payments">Metodi di pagamento: ([^<]*)</p>')
    Assert-Source ($blocks.Count -le 1) 'FP16_AT_MOST_ONE_PAYMENTS_BLOCK_IN_THE_FOOTER'
    if ($blocks.Count -eq 1) {
        $text = [Net.WebUtility]::HtmlDecode($blocks[0].Groups[1].Value)
        Write-Output ('INFO footer payments on Smoke: ' + $text)
        $items = @($text -split ', ' | Where-Object { $_ -ne '' })
        Assert-Source (($items.Count -ge 1) -and ($items.Count -le 8)) 'FP17_LIVE_BLOCK_HAS_BETWEEN_1_AND_8_METHODS'
        Assert-Source ((@($items | Where-Object { $_.Length -gt 40 }).Count -eq 0) -and ($text -notmatch '@|://|www\.') -and (([regex]::Matches($text, '[0-9]')).Count -le (5 * $items.Count))) 'FP18_LIVE_BLOCK_HAS_NO_ADDRESSES_OR_LONG_NUMBERS'
        Assert-Source ((@($items | Sort-Object -Unique).Count) -eq $items.Count) 'FP19_LIVE_BLOCK_HAS_NO_DUPLICATES'
        Assert-Source ($html -notmatch 'ft-payments">Metodi di pagamento: </p>') 'FP20_LIVE_BLOCK_IS_NEVER_AN_EMPTY_LABEL'
    } else {
        Write-Output 'INFO footer payments on Smoke: nessun blocco (nessun metodo pubblico e senza gateway per l'' azienda dell''host, o lettura non riuscita)'
        Assert-Source ($html -notmatch 'Metodi di pagamento') 'FP17_LIVE_NO_METHODS_MEANS_NO_LABEL_AT_ALL'
    }
}
if ($labRan) { Write-Output 'RESULT: ALL PASS (LAB differential executed)' } else { Write-Output 'RESULT: PASS WITHOUT THE LAB DIFFERENTIAL (NOT EXECUTED: do not count it as proven)' }
