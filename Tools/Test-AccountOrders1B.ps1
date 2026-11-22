[CmdletBinding()]
param([switch]$SkipLab)

# KS-DASHBOARD-ORDERS-1B. «La tua Dashboard» = riquadri senza elenchi doppi; «I miei ordini» (documenti.aspx) = pagina a se con i difetti corretti:
# la paginazione perdeva i filtri (il postback tornava alla query del markup, senza stato/date e con Session("AziendaID")), l'etichetta di stato univa due testi
# in un badge che si sovrapponeva a Totale e Pagamento, i filtri erano due pannelli con calendari server. Tre parti: (A) contratto dei sorgenti,
# (B) comportamento del modulo puro compilato, (C) mutazioni. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    dashAspx = Read-Repo 'myaccount.aspx'
    dashVb   = Read-Repo 'myaccount.aspx.vb'
    listAspx = Read-Repo 'documenti.aspx'
    listVb   = Read-Repo 'documenti.aspx.vb'
    css      = Read-Repo 'Public/assets/keepstore/css/account-hub-ui.css'
    module   = $(if (Test-Path -LiteralPath (Join-Path $root 'App_Code/KeepStoreAccountOrderFilters.vb')) { Read-Repo 'App_Code/KeepStoreAccountOrderFilters.vb' } else { '' })
}

function Get-Between([string]$text, [string]$from, [string]$to) {
    $i = $text.IndexOf($from); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($to, $i + $from.Length); if ($j -lt 0) { return $text.Substring($i) }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $da = $f.dashAspx; $dv = $f.dashVb; $la = $f.listAspx; $lv = $f.listVb; $css = $f.css
    # A1 la Dashboard non ha elenchi di ordini (niente elenco doppio con «I miei ordini»)
    if ($da -match 'sdsRecentOrders|rptRecentOrders|pRecentEmpty|ks-account-recent|Vedi tutti gli ordini|ks-doc-card') { $fail.Add('A1 elenco di ordini sulla Dashboard') }
    if ($dv -match 'rptRecentOrders|RecentStateId|FormatOrderStatus|GetPaymentStatus') { $fail.Add('A1 codice dell elenco sulla Dashboard') }
    if ($da -notmatch '<a href="documenti\.aspx" class="tf-btn btn-fill">I miei ordini</a>') { $fail.Add('A1 pulsante I miei ordini') }
    if ($da -notmatch '<%= TilesHtml\(True\) %>' -or $da -notmatch 'id="pnlPayNotice"') { $fail.Add('A1 riquadri o avviso da pagare') }
    # A2 la paginazione conserva i filtri: comando e parametri a OGNI richiesta (il comando non e nel ViewState), dopo le guardie e il redirect di t, dall identita verificata
    $load = Get-Between $lv 'Protected Sub Page_Load' 'End Sub'
    $callMatch = [regex]::Match($load, '(?m)^        ConfigureSelectFromRequest\(\)\s*$')
    if (-not $callMatch.Success) { $fail.Add('A2 select non configurata a ogni richiesta (livello della Sub, anche postback)') }
    else {
        $gI = $load.IndexOf('If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then'); $rI = $load.LastIndexOf('Response.Redirect("documenti.aspx?t="')
        if ($gI -lt 0 -or $rI -lt 0 -or $callMatch.Index -lt $gI -or $callMatch.Index -lt $rI) { $fail.Add('A2 la configurazione precede guardie o redirect di t') }
    }
    if ($lv -notmatch 'Private Sub ConfigureSelectFromRequest') { $fail.Add('A2 metodo ConfigureSelectFromRequest assente') }
    $cfg = Get-Between $lv 'Private Sub ConfigureDocumentSelect' 'End Sub'
    if ($cfg -notmatch 'sdsDocumenti\.SelectCommand = KeepStoreAccountOrderFilters\.BuildListSql\(idStato > -1, hasDal, hasAl\)' -or $cfg -notmatch 'sdsDocumenti\.SelectParameters\.Clear\(\)' -or $cfg -notmatch '_listReady = True') { $fail.Add('A2 configurazione della select') }
    $sel = Get-Between $lv 'Protected Sub sdsDocumenti_Selecting' 'End Sub'
    if ($sel -notmatch 'Dim identity As OrderStorefrontIdentity = CurrentOrderIdentity' -or $sel -notmatch 'If Not _listReady OrElse identity Is Nothing OrElse Not identity\.IsComplete Then\s+e\.Cancel = True' ) { $fail.Add('A2 lettura annullata senza identita o configurazione') }
    if ($sel -notmatch '"\?UtentiId", MySqlDbType\.Int64\) With \{\.Value = identity\.UtentiId\}' -or $sel -notmatch '"\?AziendaId", MySqlDbType\.Int32\) With \{\.Value = identity\.CompanyId\}' -or $sel -notmatch '"\?TipoDocumentiId", MySqlDbType\.Int32\) With \{\.Value = _listTipo\}') { $fail.Add('A2 parametri di utente, azienda e tipo non dall identita') }
    if ($sel -notmatch 'If _listStato > -1 Then parameters\.Add\(New MySqlParameter\("\?Stato"' -or $sel -notmatch 'If _listHasDal Then parameters\.Add\(New MySqlParameter\("\?Dal", MySqlDbType\.Date\)' -or $sel -notmatch 'If _listHasAl Then parameters\.Add\(New MySqlParameter\("\?Al", MySqlDbType\.Date\)') { $fail.Add('A2 parametri dei filtri') }
    if (($la + $lv) -match 'Session\("AziendaID"\)|SessionField="AziendaID"|Session\("filtroDocumento') { $fail.Add('A2 azienda o filtri dalla sessione') }
    $sds = Get-Between $la '<asp:SqlDataSource ID="sdsDocumenti"' '</asp:SqlDataSource>'
    if ($sds -match 'SessionParameter|QueryStringParameter|\?UtentiId|\?AziendaId' -or $sds -notmatch 'SelectCommand="SELECT `vdocumenti`\.`Id` FROM `vdocumenti` WHERE 1=0"' -or $sds -notmatch 'EnableViewState="false"') { $fail.Add('A2 ripiego del markup non chiuso (deve restituire zero righe, senza parametri)') }
    if ($lv -match 'TryParseDDMMYYYY|filtroDataRapido|dataInizio_PreRender|dataFine_PreRender|ApplyFiltersFromRequest|Rows\.Count') { $fail.Add('A2 percorsi vecchi dei filtri rimasti') }
    $ap = Get-Between $lv 'Sub applicaFiltri' 'End Sub'
    if ($ap -notmatch 'Response\.Redirect\(KeepStoreAccountOrderFilters\.BuildListUrl\(SafeTipoDocumentoId, idStato, tempo, dataInizio\.Text, dataFine\.Text\)\)' -or $ap -match 'DataBind') { $fail.Add('A2 applicaFiltri senza javascript: redirect canonico') }
    $mdl = $f.module
    foreach ($ph in @('?UtentiId', '?AziendaId', '?TipoDocumentiId', '?Stato', '?Dal', '?Al')) { if ($mdl -notmatch [regex]::Escape($ph)) { $fail.Add('A2 segnaposto mancante ' + $ph) } }
    $named = @([regex]::Matches($sel, '"(\?[A-Za-z]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $holders = @([regex]::Matches($mdl, '\?(UtentiId|AziendaId|TipoDocumentiId|Stato|Dal|Al)\b') | ForEach-Object { '?' + $_.Groups[1].Value } | Sort-Object -Unique)
    if (($named -join ',') -ne ($holders -join ',')) { $fail.Add('A2 parametri aggiunti diversi dai segnaposto (' + ($named -join ',') + ' / ' + ($holders -join ',') + ')') }
    # A3 stato: titolo nel badge, nota fuori dal badge (a capo)
    if ($la -match 'FormatOrderStatus' -or $lv -match 'Function FormatOrderStatus') { $fail.Add('A3 etichetta unita di stato') }
    if ($la -notmatch '<span class="ks-status-badge ks-status-badge-order"><%#: OrderStatusTitle\(Eval\("StatiDescrizione1"\), Eval\("StatiDescrizione2"\)\) %></span>') { $fail.Add('A3 titolo di stato nel badge') }
    if ($la -notmatch '<span class="ks-doc-card__status-note body-small text-main-2"><%#: OrderStatusNote\(Eval\("StatiDescrizione1"\), Eval\("StatiDescrizione2"\)\) %></span>') { $fail.Add('A3 nota di stato sotto il badge') }
    if ($lv -notmatch 'Return KeepStoreAccountOrderFilters\.StatusTitle\(' -or $lv -notmatch 'Return KeepStoreAccountOrderFilters\.StatusNote\(') { $fail.Add('A3 helper non dal modulo') }
    # A4 filtri compatti: niente calendari server, date native, «Altre date» in un details
    if ($la -match '<asp:Calendar|<asp:ImageButton|ib_calendarInizio|ImageButton1|Ricerca rapida|Ricerca dettagliata') { $fail.Add('A4 calendari o pannelli doppi') }
    if ($lv -match 'Calendar1|Calendar2|ib_calendarInizio|ImageButton1') { $fail.Add('A4 handler dei calendari') }
    if (([regex]::Matches($la, 'TextMode="Date"')).Count -ne 2) { $fail.Add('A4 date native') }
    if ($la -notmatch '<details class="ks-doc-more-dates"') { $fail.Add('A4 altre date in un details') }
    if ($la -notmatch 'role="group" aria-label="Filtra i documenti"|aria-label="Filtra i documenti"') { $fail.Add('A4 etichetta del gruppo filtri') }
    # A5 titolo e percorso
    if ($la -notmatch '<h1 class="fw-semibold mb-0 ks-page-title">I miei ordini</h1>' -or $la -notmatch '<span class="text">I miei ordini</span>') { $fail.Add('A5 titolo I miei ordini') }
    # A6 stile: la griglia della scheda segue la larghezza della scheda, non della finestra
    if ($css -notmatch '\.ks-doc-card\s*\{[^}]*container-type:\s*inline-size') { $fail.Add('A6 scheda non e un contenitore') }
    if ($css -notmatch '@container\s*\(min-width:\s*\d+px\)\s*\{\s*\.ks-doc-card__body') { $fail.Add('A6 colonne non da @container') }
    if ($css -match '@media \(min-width: (768|1200)px\)\s*\{[^@]*grid-template-columns') { $fail.Add('A6 colonne ancora dalla finestra') }
    if ($css -match 'ks-account-recent|ks-doc-card--compact') { $fail.Add('A6 stile dell elenco recente rimasto') }
    if ($la -notmatch 'account-hub-ui\.css"\) %>\?v=20261118-orders-1b' -or $da -notmatch 'account-hub-ui\.css"\) %>\?v=20261118-orders-1b') { $fail.Add('A6 buster') }
    # A8 ogni colonna calcolata che la scheda legge (Lista*, Link_Tracking) esce dalla query del modulo
    foreach ($m in ([regex]::Matches($la, 'Eval\("(Lista\w+|Link_Tracking)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)) {
        if ($f.module -notmatch ('(AS ' + [regex]::Escape($m) + '\b|\.' + [regex]::Escape($m) + '\b)')) { $fail.Add('A8 colonna della scheda assente dalla query: ' + $m) }
    }
    if ($f.module -notmatch 'CASE WHEN ltd\.Web=1 AND ltd\.Abilitato=1 AND ltd\.ImpegnaQnt=1 THEN 1 ELSE 0 END AS ListaOrdineWeb') { $fail.Add('A8 tipo ordine web nella query') }
    # A7 il modulo esiste ed e puro
    if ($f.module -eq '') { $fail.Add('A7 modulo assente') }
    elseif ($f.module -match 'HttpContext|Session\(|MySql|Request\.') { $fail.Add('A7 modulo non puro') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Collections.Generic
Imports Microsoft.VisualBasic
Public Module OrderFilterProbe
    Public Function Run() As String
        Dim r As New List(Of String)()
        Dim d As DateTime
        r.Add("B01=" & (KeepStoreAccountOrderFilters.ParseFilterDate("2026-11-18", d) AndAlso d = New DateTime(2026, 11, 18)).ToString())
        r.Add("B02=" & (KeepStoreAccountOrderFilters.ParseFilterDate("18-11-2026", d) AndAlso d = New DateTime(2026, 11, 18)).ToString())
        r.Add("B03=" & (KeepStoreAccountOrderFilters.ParseFilterDate(" 2026-11-18 ", d) AndAlso d = New DateTime(2026, 11, 18)).ToString())
        Dim bad As String() = {"2026-13-40", "", " ", "abc", "99999-01-01", "18/11/2026", "2026/11/18", "1899-01-01", "2101-01-01", "31-02-2026"}
        Dim allBad As Boolean = KeepStoreAccountOrderFilters.ParseFilterDate(Nothing, d) = False
        For Each b As String In bad
            If KeepStoreAccountOrderFilters.ParseFilterDate(b, d) Then allBad = False
        Next
        r.Add("B04=" & allBad.ToString())
        r.Add("B05=" & (KeepStoreAccountOrderFilters.SafeStato("5") = 5 AndAlso KeepStoreAccountOrderFilters.SafeStato("0") = 0 AndAlso KeepStoreAccountOrderFilters.SafeStato("-1") = -1).ToString())
        r.Add("B06=" & (KeepStoreAccountOrderFilters.SafeStato("-5") = -1 AndAlso KeepStoreAccountOrderFilters.SafeStato("abc") = -1 AndAlso KeepStoreAccountOrderFilters.SafeStato("") = -1 AndAlso KeepStoreAccountOrderFilters.SafeStato(Nothing) = -1 AndAlso KeepStoreAccountOrderFilters.SafeStato("99999999999") = -1).ToString())
        r.Add("B07=" & (KeepStoreAccountOrderFilters.SafeTempo("7") = 7 AndAlso KeepStoreAccountOrderFilters.SafeTempo("30") = 30 AndAlso KeepStoreAccountOrderFilters.SafeTempo("60") = 60 AndAlso KeepStoreAccountOrderFilters.SafeTempo("90") = 90 AndAlso KeepStoreAccountOrderFilters.SafeTempo("-1") = -1).ToString())
        r.Add("B08=" & (KeepStoreAccountOrderFilters.SafeTempo("45") = -1 AndAlso KeepStoreAccountOrderFilters.SafeTempo("0") = -1 AndAlso KeepStoreAccountOrderFilters.SafeTempo("abc") = -1 AndAlso KeepStoreAccountOrderFilters.SafeTempo(Nothing) = -1 AndAlso KeepStoreAccountOrderFilters.SafeTempo("365") = -1).ToString())
        Dim t2 As String = "Il tuo ordine e stato memorizzato e sara processato al piu presto"
        r.Add("B09=" & (KeepStoreAccountOrderFilters.StatusTitle("Inviato", t2) = "Inviato" AndAlso KeepStoreAccountOrderFilters.StatusNote("Inviato", t2) = t2).ToString())
        r.Add("B10=" & (KeepStoreAccountOrderFilters.StatusTitle("", "Solo secondo") = "Solo secondo" AndAlso KeepStoreAccountOrderFilters.StatusNote("", "Solo secondo") = "").ToString())
        r.Add("B11=" & (KeepStoreAccountOrderFilters.StatusTitle("Solo primo", Nothing) = "Solo primo" AndAlso KeepStoreAccountOrderFilters.StatusNote("Solo primo", DBNull.Value) = "").ToString())
        r.Add("B12=" & (KeepStoreAccountOrderFilters.StatusTitle("", "") = "Non disponibile" AndAlso KeepStoreAccountOrderFilters.StatusTitle(Nothing, DBNull.Value) = "Non disponibile" AndAlso KeepStoreAccountOrderFilters.StatusNote(Nothing, Nothing) = "").ToString())
        r.Add("B13=" & (KeepStoreAccountOrderFilters.StatusTitle("  In" & vbCrLf & "lavorazione ", "x") = "In lavorazione" AndAlso KeepStoreAccountOrderFilters.StatusNote("Spedito", "Uguale") = "Uguale" AndAlso KeepStoreAccountOrderFilters.StatusNote("Uguale", "Uguale") = "").ToString())
        r.Add("B14=" & (KeepStoreAccountOrderFilters.StatusNote("A", "B" & vbTab & vbTab & "C  D") = "B C D").ToString())
        r.Add("B15=" & (KeepStoreAccountOrderFilters.FormatFilterDate(New DateTime(2026, 1, 5)) = "2026-01-05").ToString())
        r.Add("B16=" & (KeepStoreAccountOrderFilters.ParseFilterDate("2024-02-29", d) AndAlso Not KeepStoreAccountOrderFilters.ParseFilterDate("2026-02-29", d)).ToString())
        Dim dal As DateTime, al As DateTime, hasDal As Boolean, hasAl As Boolean
        Dim today As New DateTime(2026, 11, 18, 15, 30, 0)
        ' il periodo rapido vince sulle date
        KeepStoreAccountOrderFilters.ResolveRange(7, "2026-01-01", "2026-01-02", today, dal, al, hasDal, hasAl)
        r.Add("B17=" & (hasDal AndAlso hasAl AndAlso dal = New DateTime(2026, 11, 11) AndAlso al = New DateTime(2026, 11, 18)).ToString())
        ' solo "dal"
        KeepStoreAccountOrderFilters.ResolveRange(-1, "2026-05-01", "", today, dal, al, hasDal, hasAl)
        r.Add("B18=" & (hasDal AndAlso Not hasAl AndAlso dal = New DateTime(2026, 5, 1)).ToString())
        ' solo "al" (vecchio formato)
        KeepStoreAccountOrderFilters.ResolveRange(-1, "", "18-11-2026", today, dal, al, hasDal, hasAl)
        r.Add("B19=" & (Not hasDal AndAlso hasAl AndAlso al = New DateTime(2026, 11, 18)).ToString())
        ' intervallo invertito: si scambiano gli estremi
        KeepStoreAccountOrderFilters.ResolveRange(-1, "2026-05-10", "2026-05-01", today, dal, al, hasDal, hasAl)
        r.Add("B20=" & (hasDal AndAlso hasAl AndAlso dal = New DateTime(2026, 5, 1) AndAlso al = New DateTime(2026, 5, 10)).ToString())
        ' nessun filtro valido
        KeepStoreAccountOrderFilters.ResolveRange(45, "x", "y", today, dal, al, hasDal, hasAl)
        r.Add("B21=" & (Not hasDal AndAlso Not hasAl).ToString())
        ' query della lista: tutti i valori sono parametri, i filtri compaiono solo se richiesti
        Dim q0 As String = KeepStoreAccountOrderFilters.BuildListSql(False, False, False)
        Dim q3 As String = KeepStoreAccountOrderFilters.BuildListSql(True, True, True)
        Dim scope As String = "(`vdocumenti`.`UtentiId`=?UtentiId) AND (`vdocumenti`.`AziendeId`=?AziendaId) AND (`vdocumenti`.`TipoDocumentiId`=?TipoDocumentiId)"
        r.Add("B22=" & (q0.Contains(scope) AndAlso q3.Contains(scope)).ToString())
        r.Add("B23=" & (Not q0.Contains("?Stato") AndAlso Not q0.Contains("?Dal") AndAlso Not q0.Contains("?Al") AndAlso q3.Contains("`vdocumenti`.`StatiId`=?Stato") AndAlso q3.Contains("`vdocumenti`.`DataDocumento` >= ?Dal") AndAlso q3.Contains("`vdocumenti`.`DataDocumento` <= ?Al")).ToString())
        r.Add("B24=" & (q0.EndsWith("ORDER BY `vdocumenti`.`ID` DESC") AndAlso q3.EndsWith("ORDER BY `vdocumenti`.`ID` DESC")).ToString())
        r.Add("B25=" & (Not System.Text.RegularExpressions.Regex.IsMatch(q3, "(UtentiId|AziendeId|TipoDocumentiId|StatiId)`\s*=\s*\d|DataDocumento`\s*(>=|<=)\s*'")).ToString())
        r.Add("B26=" & (KeepStoreAccountOrderFilters.BuildListSql(False, True, False).Contains("?Dal") AndAlso Not KeepStoreAccountOrderFilters.BuildListSql(False, True, False).Contains("?Al") AndAlso KeepStoreAccountOrderFilters.BuildListSql(False, False, True).Contains("?Al") AndAlso Not KeepStoreAccountOrderFilters.BuildListSql(False, False, True).Contains("?Dal")).ToString())
        r.Add("B27=" & (KeepStoreAccountOrderFilters.BuildListUrl(4, 3, 30, "2026-01-01", "2026-02-01") = "documenti.aspx?t=4&stato=3&tempo=30").ToString())
        r.Add("B28=" & (KeepStoreAccountOrderFilters.BuildListUrl(4, -1, -1, "18-11-2026", "2026-12-01") = "documenti.aspx?t=4&dal=2026-11-18&al=2026-12-01").ToString())
        r.Add("B29=" & (KeepStoreAccountOrderFilters.BuildListUrl(4, -1, 45, "", "") = "documenti.aspx?t=4" AndAlso KeepStoreAccountOrderFilters.BuildListUrl(0, -1, -1, "x", "") = "documenti.aspx?t=1").ToString())
        Return String.Join(";", r.ToArray())
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    if ($moduleText -eq '') { if (-not $Quiet) { Write-Host '  FAIL B modulo assente' }; return $false }
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $out = [string]$c.CompiledAssembly.GetType('OrderFilterProbe').GetMethod('Run').Invoke($null, @())
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.module
if (-not ($okSource -and $okBehaviour)) { Write-Host 'ACCOUNT_ORDERS_1B FAIL'; exit 1 }

# --- (C) mutazioni: riempite dopo l'implementazione (devono tutte fallire) ---
$mutants = @(
    @{ Id = 'M01_CONFIGURE_ONLY_FIRST_LOAD'; File = 'listVb'; Old = "`r`n        ConfigureSelectFromRequest()`r`n"; New = "`r`n            ConfigureSelectFromRequest()`r`n" },
    @{ Id = 'M02_CONFIGURE_BEFORE_GUARDS'; File = 'listVb'; Old = "        If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then`r`n            Response.Redirect"; New = "        ConfigureSelectFromRequest()`r`n        If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then`r`n            Response.Redirect" },
    @{ Id = 'M03_PARAMS_NOT_FROM_IDENTITY'; File = 'listVb'; Old = '{.Value = identity.CompanyId}'; New = '{.Value = 1}' },
    @{ Id = 'M04_USER_PARAMETER_DROPPED'; File = 'listVb'; Old = 'parameters.Add(New MySqlParameter("?UtentiId", MySqlDbType.Int64) With {.Value = identity.UtentiId})'; New = '' },
    @{ Id = 'M05_SELECTING_WITHOUT_CANCEL'; File = 'listVb'; Old = 'e.Cancel = True'; New = '' },
    @{ Id = 'M06_FALLBACK_OPEN'; File = 'listAspx'; Old = 'FROM `vdocumenti` WHERE 1=0"'; New = 'FROM `vdocumenti`"' },
    @{ Id = 'M07_FALLBACK_SESSION_PARAMETER'; File = 'listAspx'; Old = 'FROM `vdocumenti` WHERE 1=0">'; New = 'FROM `vdocumenti` WHERE 1=0"><SelectParameters><asp:SessionParameter Name="AziendaId" SessionField="AziendaID" Type="Int32" /></SelectParameters>' },
    @{ Id = 'M08_SESSION_COMPANY_BACK'; File = 'listVb'; Old = 'Private _listReady As Boolean = False'; New = 'Private _listReady As Boolean = (Session("AziendaID") IsNot Nothing)' },
    @{ Id = 'M09_VIEWSTATE_BACK'; File = 'listAspx'; Old = '<asp:SqlDataSource ID="sdsDocumenti" runat="server" EnableViewState="false"'; New = '<asp:SqlDataSource ID="sdsDocumenti" runat="server"' },
    @{ Id = 'M10_OLD_FILTER_PATH_BACK'; File = 'listVb'; Old = 'Private Sub ApplyFilterControlsFromRequest()'; New = "Private Function TryParseDDMMYYYY(raw As String) As Boolean : Return False : End Function`r`n    Private Sub ApplyFilterControlsFromRequest()" },
    @{ Id = 'M11_NO_JS_DATABIND_NOT_REDIRECT'; File = 'listVb'; Old = 'Response.Redirect(KeepStoreAccountOrderFilters.BuildListUrl(SafeTipoDocumentoId, idStato, tempo, dataInizio.Text, dataFine.Text))'; New = 'GridView1.DataBind()' },
    @{ Id = 'M12_STATUS_JOINED_AGAIN'; File = 'listAspx'; Old = '<span class="ks-status-badge ks-status-badge-order"><%#: OrderStatusTitle(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></span>'; New = '<span class="ks-status-badge ks-status-badge-order"><%#: OrderStatusTitle(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %> <%#: OrderStatusNote(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></span>' },
    @{ Id = 'M13_NOTE_NOT_ENCODED'; File = 'listAspx'; Old = '<%#: OrderStatusNote('; New = '<%# OrderStatusNote(' },
    @{ Id = 'M14_CALENDAR_BACK'; File = 'listAspx'; Old = '<details class="ks-doc-more-dates"<%= MoreDatesOpenAttribute %>>'; New = '<asp:Calendar ID="Calendar1" runat="server" /><details class="ks-doc-more-dates"<%= MoreDatesOpenAttribute %>>' },
    @{ Id = 'M15_DATE_TEXT_INPUT'; File = 'listAspx'; Old = 'ID="dataInizio" TextMode="Date"'; New = 'ID="dataInizio"' },
    @{ Id = 'M16_DATES_NOT_IN_DETAILS'; File = 'listAspx'; Old = '<details class="ks-doc-more-dates"<%= MoreDatesOpenAttribute %>>'; New = '<div class="ks-doc-more-dates"<%= MoreDatesOpenAttribute %>>' },
    @{ Id = 'M17_FILTER_GROUP_LABEL_LOST'; File = 'listAspx'; Old = 'role="group" aria-label="Filtra i documenti"'; New = '' },
    @{ Id = 'M18_OLD_TITLE'; File = 'listAspx'; Old = '<h1 class="fw-semibold mb-0 ks-page-title">I miei ordini</h1>'; New = '<h1 class="fw-semibold mb-0 ks-page-title">I miei documenti</h1>' },
    @{ Id = 'M19_DASHBOARD_LIST_BACK'; File = 'dashAspx'; Old = '<nav class="ks-account-hub" aria-label="Servizi dell''account">'; New = '<asp:Repeater ID="rptRecentOrders" runat="server"></asp:Repeater><nav class="ks-account-hub" aria-label="Servizi dell''account">' },
    @{ Id = 'M20_DASHBOARD_HELPER_BACK'; File = 'dashVb'; Old = 'Protected Function GetDashboardGreeting('; New = "Protected Function GetPaymentStatusLabel() As String : Return `"`" : End Function`r`n`r`n    Protected Function GetDashboardGreeting(" },
    @{ Id = 'M21_DASHBOARD_BUTTON_LOST'; File = 'dashAspx'; Old = '<a href="documenti.aspx" class="tf-btn btn-fill">I miei ordini</a>'; New = '' },
    @{ Id = 'M22_CARD_NOT_CONTAINER'; File = 'css'; Old = "    container-type: inline-size;`r`n"; New = '' },
    @{ Id = 'M23_COLUMNS_FROM_WINDOW'; File = 'css'; Old = '@container (min-width: 520px) {'; New = '@media (min-width: 768px) {' },
    @{ Id = 'M24_RECENT_STYLE_BACK'; File = 'css'; Old = '.ks-account-strip {'; New = ".ks-account-recent { margin: 0; }`r`n`r`n.ks-account-strip {" },
    @{ Id = 'M25_BUSTER_STALE'; File = 'listAspx'; Old = 'account-hub-ui.css") %>?v=20261118-orders-1b'; New = 'account-hub-ui.css") %>?v=20261118-qa-1a' },
    @{ Id = 'M26_MODULE_IMPURE'; File = 'module'; Old = 'Public Module KeepStoreAccountOrderFilters'; New = "Public Module KeepStoreAccountOrderFilters`r`n    Private Function X() As Object : Return HttpContext.Current : End Function" },
    @{ Id = 'M27_NOTE_FROM_MODULE_LOST'; File = 'listVb'; Old = 'Return KeepStoreAccountOrderFilters.StatusNote(stato1Obj, stato2Obj)'; New = 'Return ""' },
    @{ Id = 'M29_ORDER_TYPE_COLUMN_DROPPED'; File = 'module'; Old = 'AS ListaOrdineWeb'; New = 'AS ListaAltro' },
    @{ Id = 'M30_TRACKING_COLUMN_DROPPED'; File = 'module'; Old = 'vettori.Link_Tracking, '; New = '' },
    @{ Id = 'M28_PARAM_NAME_DRIFT'; File = 'listVb'; Old = '"?TipoDocumentiId", MySqlDbType.Int32'; New = '"?TipoDoc", MySqlDbType.Int32' }
)
$behaviourMutants = @(
    @{ Id = 'N01_DATE_ISO_NOT_ACCEPTED'; Old = '{"yyyy-MM-dd", "dd-MM-yyyy"}'; New = '{"dd-MM-yyyy"}' },
    @{ Id = 'N02_DATE_ITALIAN_NOT_ACCEPTED'; Old = '{"yyyy-MM-dd", "dd-MM-yyyy"}'; New = '{"yyyy-MM-dd"}' },
    @{ Id = 'N03_NO_YEAR_GUARD'; Old = 'If parsed.Year < 1990 OrElse parsed.Year > 2100 Then Return False'; New = '' },
    @{ Id = 'N04_STATO_NEGATIVE_ACCEPTED'; Old = 'AndAlso parsed >= -1 Then Return parsed'; New = 'Then Return parsed' },
    @{ Id = 'N05_TEMPO_ALWAYS_30'; Old = 'Select Case parsed'; New = 'Select Case 30' },
    @{ Id = 'N06_TEMPO_RANGE_OFF_BY_ONE'; Old = 'dal = today.Date.AddDays(-tempo)'; New = 'dal = today.Date.AddDays(-tempo - 1)' },
    @{ Id = 'N07_INVERTED_NOT_SWAPPED'; Old = 'If hasDal AndAlso hasAl AndAlso dal > al Then'; New = 'If False Then' },
    @{ Id = 'N08_TITLE_NOTE_JOINED'; Old = 'If first.Length > 0 Then Return first'; New = 'If first.Length > 0 Then Return (first & " " & CleanText(stato2)).Trim()' },
    @{ Id = 'N09_NOTE_WITHOUT_TITLE'; Old = 'If first.Length = 0 Then Return ""'; New = '' },
    @{ Id = 'N10_NOTE_DUPLICATES_TITLE'; Old = 'OrElse String.Equals(first, second, StringComparison.OrdinalIgnoreCase)'; New = '' },
    @{ Id = 'N11_SQL_USER_PREDICATE_DROPPED'; Old = '(`vdocumenti`.`UtentiId`=?UtentiId) AND '; New = '' },
    @{ Id = 'N12_SQL_COMPANY_PREDICATE_DROPPED'; Old = ' AND (`vdocumenti`.`AziendeId`=?AziendaId)'; New = '' },
    @{ Id = 'N13_SQL_DAL_EXCLUSIVE'; Old = 'DataDocumento` >= ?Dal'; New = 'DataDocumento` > ?Dal' },
    @{ Id = 'N14_SQL_AL_ALWAYS'; Old = 'If withAl Then sql.Append'; New = 'If True Then sql.Append' },
    @{ Id = 'N15_URL_KEEPS_DATES_WITH_TEMPO'; Old = 'If safeTime > 0 Then'; New = 'If False Then' },
    @{ Id = 'N16_CLEAN_KEEPS_LF'; Old = '.Replace(Convert.ToChar(10), " "c)'; New = '' }
)
$minMutants = 40
if (($mutants.Count + $behaviourMutants.Count) -lt $minMutants) { Write-Host ('ACCOUNT_ORDERS_1B FAIL (pochi mutanti: ' + ($mutants.Count + $behaviourMutants.Count) + ')'); exit 1 }
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.module.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'ACCOUNT_ORDERS_1B FAIL (mutanti)'; exit 1 }

# ---- (D) LAB: la query reale della lista sul connettore del sito, contro query di controllo scritte a mano (isolamento utente e azienda) ----
$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath $credFile) -and (Test-Path -LiteralPath $vbc) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $work = Join-Path $env:TEMP ('ks-accountorders-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
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
            $exe = Join-Path $work 'AccountOrdersLabHarness.exe'
            [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
            $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
            $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll (Join-Path $root 'Tools\AccountOrdersLabHarness.vb') (Join-Path $root 'App_Code\KeepStoreAccountOrderFilters.vb') 2>&1
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { $build | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'ACCOUNT_ORDERS_1B FAIL (harness LAB non compila)'; exit 1 }
            $cred = Import-Clixml -LiteralPath $credFile
            $plain = $cred.GetNetworkCredential().Password
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
            $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
            $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
            $proc = [Diagnostics.Process]::Start($info)
            $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
            if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
            $plain = $null; $cred = $null
            $summary = @($stdout -split "`r?`n" | Where-Object { $_ -match '^ACCOUNT_ORDERS_LAB ' }) | Select-Object -Last 1
            if ($proc.ExitCode -ne 0 -or $summary -notmatch 'FAIL=0$') {
                @($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|ACCOUNT_ORDERS_LAB)' }) | ForEach-Object { Write-Host ('  ' + $_) }
                if ($stderr.Trim()) { Write-Host ('  stderr: ' + $stderr.Trim()) }
                Write-Host 'ACCOUNT_ORDERS_1B FAIL (LAB)'; exit 1
            }
            $labNote = $summary
        } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host ('ACCOUNT_ORDERS_1B PASS (' + ($mutants.Count + $behaviourMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
