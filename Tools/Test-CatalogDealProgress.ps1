[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipBrowser, [switch]$SkipMutants)

# CATALOG-DEAL-PROGRESS-1B. Barra delle vendite nelle schede IN OFFERTA dell'elenco (richiesta del PO del 2026-11-19: "stessa tipologia
# anche nella sezione OFFERTE"). Regole provate:
#  - UNA definizione dei venduti (modulo puro App_Code/StorefrontSoldUnits.vb, usato da HOME ed elenco; la HOME tiene solo adattatori);
#  - una sola lettura per legame della lista, mai con elenco vuoto, mai un errore che ferma la pagina;
#  - barra solo sulle schede con un'offerta attiva e a livello di articolo (venduti per articolo e disponibilita della riga parlano
#    della stessa cosa), solo con almeno un pezzo venduto, prima del prezzo (i prezzi della fila restano allineati);
#  - chi non puo vedere i numeri di giacenza vede gradini di 10 punti; nessun numero di disponibilita nella barra.
# (A) sorgenti, (B) modulo compilato, (C) mutazioni, (D) sito LAB reale (https, 127.0.0.1, porta 18843), (E) browser a 390 e 1280 px.
# Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }
function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i + $end.Length)
}
function Count-Of([string]$text, [string]$needle) { return ([regex]::Matches($text, [regex]::Escape($needle))).Count }

$files = @{
    pure = Read-Repo 'App_Code\StorefrontSoldUnits.vb'
    reader = Read-Repo 'App_Code\StorefrontSoldUnitsReader.vb'
    homeVb = Read-Repo 'Default.aspx.vb'
    catAspx = Read-Repo 'articoli.aspx'
    catVb = Read-Repo 'articoli.aspx.vb'
    card = Read-Repo 'Public\ui\controls\ProductCard.ascx'
    cardVb = Read-Repo 'Public\ui\controls\ProductCard.ascx.vb'
    css = Read-Repo 'Public\assets\keepstore\css\catalog-compact.css'
}
$signature = 'GREATEST(SUM(q.QtaOrdini),SUM(q.QtaScarichi)) AS CommercialScore'

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    # S01 una sola definizione della misura, in un modulo senza accesso al database
    if ($f.pure -eq '' -or $f.reader -eq '') { $fail.Add('S01 moduli condivisi assenti') }
    if ((Count-Of $f.pure $signature) -ne 1 -or (Count-Of $f.homeVb $signature) -ne 0 -or (Count-Of $f.catVb $signature) -ne 0 -or (Count-Of $f.reader $signature) -ne 0) { $fail.Add('S01 la query della misura commerciale ha una sola definizione') }
    if ($f.pure -match '(?i)MySql|ConfigurationManager') { $fail.Add('S01 il modulo puro non tocca il database') }
    if (-not $f.homeVb.Contains('Return StorefrontSoldUnits.BuildCommercialActivitySql(articleIdList)') -or -not $f.homeVb.Contains('Return StorefrontSoldUnits.BuildFiscalCompanyScopeSql()')) { $fail.Add('S01 la HOME usa il modulo con due adattatori') }
    # S02 lettore: niente query con elenco vuoto o azienda assente, tempo massimo, errore = vuoto
    $load = Get-Block $f.reader 'Public Shared Function Load(' 'End Function'
    $iGuard = $load.IndexOf('If companyId <= 0 OrElse String.IsNullOrEmpty(idList) OrElse String.IsNullOrEmpty(connectionString) Then Return result'); $iConn = $load.IndexOf('New MySqlConnection(')
    if ($iGuard -lt 0 -or $iConn -lt 0 -or $iGuard -gt $iConn) { $fail.Add('S02 nessuna lettura con elenco vuoto o azienda assente') }
    if (-not $load.Contains('cmd.CommandTimeout = 3')) { $fail.Add('S02 tempo massimo della lettura') }
    if ($load -notmatch 'Catch ex As Exception\s+KeepStoreLog\.Error\("storefront-sold-units", "Sold units unavailable\. Error type: " & ex\.GetType\(\)\.Name & "\.", Nothing, context\)\s+Return New Dictionary\(Of Integer, Decimal\)\(\)\s+End Try') { $fail.Add('S02 un errore restituisce un risultato vuoto e non scrive dati nel registro') }
    if (-not $load.Contains('cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = companyId') -or -not $load.Contains('Date.Today.AddMonths(-12)')) { $fail.Add('S02 azienda e periodo di 12 mesi') }
    # S03 elenco: raccolta svuotata a ogni legame, una lettura in DataBound, azienda dal contesto validato
    if ($f.catAspx -notmatch '<asp:ListView ID="lvProdotti"[^>]*OnDataBinding="lvProdotti_DataBinding"[^>]*OnDataBound="lvProdotti_DataBound"') { $fail.Add('S03 eventi dichiarati sulla lista') }
    $binding = Get-Block $f.catVb 'Protected Sub lvProdotti_DataBinding(' 'End Sub'
    if (-not $binding.Contains('catalogSalesCandidates.Clear()')) { $fail.Add('S03 raccolta svuotata a ogni legame') }
    $apply = Get-Block $f.catVb 'Private Sub ApplyCatalogSalesProgress()' 'End Sub'
    if ((Count-Of $f.catVb 'StorefrontSoldUnitsReader.Load(') -ne 1 -or (Count-Of $apply 'StorefrontSoldUnitsReader.Load(') -ne 1) { $fail.Add('S03 una sola lettura, nel gestore della lista') }
    if (-not $apply.Contains('If catalogSalesCandidates.Count = 0 OrElse catalogPromotionTechnicalError Then Exit Sub')) { $fail.Add('S03 nessuna lettura senza schede o con promozioni in errore') }
    if (-not $apply.Contains('_priceDisplayContext.CompanyId')) { $fail.Add('S03 azienda dal contesto gia confrontato con l''host') }
    if (-not $apply.Contains('candidate.Card.Parent IsNot Nothing')) { $fail.Add('S03 solo schede ancora nella pagina') }
    if (-not $apply.Contains('candidate.Availability.DisplayMode = 2')) { $fail.Add('S03 percentuale esatta solo a chi puo vedere i numeri') }
    if ($apply -match '(?i)\.StockQty|Giacenza') { $fail.Add('S03 nessuna giacenza lorda') }
    # S04 solo schede in offerta e a livello di articolo
    $item = Get-Block $f.catVb 'Private Sub lvProdotti_ItemDataBound(' 'End Sub'
    if (-not $item.Contains('If model.IsOnSale AndAlso model.IsArticleLevelRow AndAlso model.ProductId > 0 AndAlso model.Availability IsNot Nothing Then')) { $fail.Add('S04 barra solo con offerta attiva e riga di articolo') }
    if (-not $f.catVb.Contains('model.IsArticleLevelRow = (CatalogTcId(dataItem, False) <= 0)')) { $fail.Add('S04 riga di articolo dalla variante risolta') }
    if ((Count-Of $f.catVb 'catalogSalesCandidates.Add(') -ne 1 -or (Count-Of $item 'catalogSalesCandidates.Add(') -ne 1) { $fail.Add('S04 un solo punto di raccolta') }
    # S05 scheda: barra prima del prezzo, vuota per difetto
    $iBar = $f.card.IndexOf('<%= SalesProgressHtml %>'); $iPrice = $f.card.IndexOf('<p class="price-wrap fw-medium"'); $iTitle = $f.card.IndexOf('<%= SafeProductName %>')
    if ($iBar -lt 0 -or $iPrice -lt 0 -or $iTitle -lt 0 -or -not ($iTitle -lt $iBar -and $iBar -lt $iPrice)) { $fail.Add('S05 barra dopo il titolo e PRIMA del prezzo') }
    if ((Count-Of $f.card 'SalesProgressHtml') -ne 1 -or -not $f.cardVb.Contains('Public Property SalesProgressHtml As String')) { $fail.Add('S05 proprieta della scheda') }
    if (-not $f.cardVb.Contains('Return Not String.IsNullOrWhiteSpace(SalesProgressHtml)')) { $fail.Add('S05 nessuna barra se la proprieta e vuota') }
    # S06 stile nel foglio compatto del catalogo
    if (-not $f.css.Contains('#ksCatalogPage .ks-card-sales__bar {') -or -not $f.css.Contains('background: var(--primary, #D80027);') -or $f.catAspx -notmatch 'css/catalog-compact\.css"\) %>\?v=20261119-sales-1b"') { $fail.Add('S06 stile della barra e sigla del foglio') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

# (B) Modulo puro compilato dal sorgente reale.
function Test-Compiled([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    if ($f.pure -eq '') { if (-not $Quiet) { Write-Host '  FAIL C00 modulo assente' }; return $false }
    $ns = 'KsSold' + [Guid]::NewGuid().ToString('N')
    $code = $f.pure -replace 'Public NotInheritable Class StorefrontSoldUnits', ("Namespace $ns`r`nPublic NotInheritable Class StorefrontSoldUnits")
    $code = $code + "`r`nEnd Namespace`r`n"
    try { $types = Add-Type -TypeDefinition $code -Language VisualBasic -ReferencedAssemblies 'System.Web' -PassThru -ErrorAction Stop }
    catch { if (-not $Quiet) { Write-Host ('  FAIL C00 compilazione: ' + $_.Exception.Message) }; return $false }
    $t = @($types | Where-Object { $_.Name -eq 'StorefrontSoldUnits' })[0]
    $cases = @(
        @(0, 10, $true, 0), @(0, 10, $false, 0), @(-3, 10, $true, 0), @(0, 0, $false, 0),
        @(1, 99, $true, 1), @(1, 1000, $true, 1), @(50, 50, $true, 50), @(2, 1, $true, 66), @(1000, 1, $true, 99), @(5, 0, $true, 100),
        @(1, 1000, $false, 10), @(50, 50, $false, 50), @(2, 1, $false, 70), @(1, 3, $false, 30), @(45, 55, $false, 50), @(44, 56, $false, 40), @(1000, 1, $false, 90), @(5, 0, $false, 90)
    )
    foreach ($c in $cases) {
        try { $got = $t::Percent([decimal]$c[0], [decimal]$c[1], [bool]$c[2]) } catch { $got = 'errore' }
        if ($got -ne $c[3]) { $fail.Add(('C01 percentuale venduti={0} disponibili={1} esatta={2}: atteso {3}, ottenuto {4}' -f $c[0], $c[1], $c[2], $c[3], $got)) }
    }
    if ($t::Units([decimal]1234.9) -ne '1.234' -or $t::Units([decimal]-3) -ne '0') { $fail.Add('C02 quantita intere con separatore italiano') }
    $ids = New-Object 'Collections.Generic.List[int]'; foreach ($i in @(3, -1, 0, 3, 5)) { $ids.Add($i) }
    if ($t::FormatIdList($ids) -ne '3,5' -or $t::FormatIdList((New-Object 'Collections.Generic.List[int]')) -ne '' -or $t::FormatIdList($null) -ne '') { $fail.Add('C03 elenco di soli interi positivi e distinti') }
    $many = New-Object 'Collections.Generic.List[int]'; for ($i = 1; $i -le 450; $i++) { $many.Add($i) }
    if (($t::FormatIdList($many) -split ',').Count -ne 400) { $fail.Add('C03 al massimo 400 articoli per lettura') }
    # resa compatta
    if ($t::RenderCompact([decimal]0, [decimal]5, $false, 'x') -ne '' -or $t::RenderCompact([decimal]0.4, [decimal]5, $true, 'x') -ne '') { $fail.Add('C04 nessuna barra sotto un pezzo venduto') }
    $guest = $t::RenderCompact([decimal]2.9, [decimal]1, $false, 'Cavo HDMI')
    if (-not $guest.Contains("aria-valuenow='70'") -or -not $guest.Contains("style='width:70%'") -or -not $guest.Contains('<strong>2</strong>') -or $guest -match '(?i)disponibil' -or $guest -notmatch "aria-label='Vendite di Cavo HDMI'" -or -not $guest.Contains("role='progressbar'")) { $fail.Add('C05 ospite: gradini di 10, numero dei venduti, nessuna disponibilita, nome accessibile') }
    $exact = $t::RenderCompact([decimal]2, [decimal]1, $true, 'Cavo')
    if (-not $exact.Contains("aria-valuenow='66'") -or $exact -match '(?i)disponibil') { $fail.Add('C06 con numeri: percentuale esatta, nessuna disponibilita ripetuta') }
    $hostile = $t::RenderCompact([decimal]3, [decimal]1, $false, "A'><script>alert(1)</script> &quot;B&quot;")
    if ($hostile -match '(?i)<script' -or $hostile -match "A'>" -or -not $hostile.Contains('&lt;script&gt;')) { $fail.Add('C07 titolo del prodotto codificato') }
    $sql = $t::BuildCommercialActivitySql('7,9'); $sqlAll = $t::BuildCommercialActivitySql('')
    if (-not $sql.Contains('AND dr.ArticoliId IN (7,9) ') -or $sqlAll -match 'ArticoliId IN' -or -not $sql.Contains('@commercialCompany') -or -not $sql.Contains("NOT LIKE 'annull%'")) { $fail.Add('C08 query con e senza filtro per articoli') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$sourceOk = Test-Source $files
$compiledOk = Test-Compiled $files
if (-not ($sourceOk -and $compiledOk)) { Write-Host 'CATALOG_DEAL_PROGRESS FAIL (sorgenti o modulo)'; exit 1 }
Write-Host 'CATALOG_DEAL_PROGRESS sorgenti e modulo OK'

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_BAR_WITHOUT_OFFER'; F = 'catVb'; Old = 'If model.IsOnSale AndAlso model.IsArticleLevelRow AndAlso'; New = 'If model.IsArticleLevelRow AndAlso' },
    @{ Id = 'M02_BAR_ON_VARIANT_ROW'; F = 'catVb'; Old = 'If model.IsOnSale AndAlso model.IsArticleLevelRow AndAlso'; New = 'If model.IsOnSale AndAlso' },
    @{ Id = 'M03_VARIANT_FROM_FALLBACK'; F = 'catVb'; Old = 'model.IsArticleLevelRow = (CatalogTcId(dataItem, False) <= 0)'; New = 'model.IsArticleLevelRow = (CatalogTcId(dataItem, True) <= 0)' },
    @{ Id = 'M04_NO_RESET_PER_BINDING'; F = 'catVb'; Old = '        catalogSalesCandidates.Clear()' + $nl + '    End Sub' + $nl + $nl + '    Protected Sub lvProdotti_DataBound('; New = '    End Sub' + $nl + $nl + '    Protected Sub lvProdotti_DataBound(' },
    @{ Id = 'M05_QUERY_ON_PROMO_ERROR'; F = 'catVb'; Old = 'If catalogSalesCandidates.Count = 0 OrElse catalogPromotionTechnicalError Then Exit Sub'; New = 'If catalogSalesCandidates.Count = 0 Then Exit Sub' },
    @{ Id = 'M06_GUEST_EXACT'; F = 'catVb'; Old = 'candidate.Availability.DisplayMode = 2'; New = 'True' },
    @{ Id = 'M07_DETACHED_CARDS'; F = 'catVb'; Old = 'candidate.Card.Parent IsNot Nothing'; New = 'True' },
    @{ Id = 'M08_COMPANY_FROM_SESSION'; F = 'catVb'; Old = '_priceDisplayContext.CompanyId, ids'; New = 'CInt(Session("AziendaID")), ids' },
    @{ Id = 'M09_EMPTY_LIST_QUERIED'; F = 'reader'; Old = 'If companyId <= 0 OrElse String.IsNullOrEmpty(idList) OrElse String.IsNullOrEmpty(connectionString) Then Return result'; New = 'If companyId <= 0 OrElse String.IsNullOrEmpty(connectionString) Then Return result' },
    @{ Id = 'M10_ERROR_PROPAGATES'; F = 'reader'; Old = '            Return New Dictionary(Of Integer, Decimal)()' + $nl + '        End Try'; New = '            Throw' + $nl + '        End Try' },
    @{ Id = 'M11_NO_TIMEOUT'; F = 'reader'; Old = 'cmd.CommandTimeout = 3'; New = 'cmd.CommandTimeout = 0' },
    @{ Id = 'M12_BAR_AFTER_PRICE'; F = 'card'; Special = 'MoveAfterPrice' },
    @{ Id = 'M13_TITLE_NOT_ENCODED'; F = 'pure'; Old = 'HttpUtility.HtmlEncode("Vendite di " & HttpUtility.HtmlDecode(productName))'; New = '"Vendite di " & productName' },
    @{ Id = 'M14_BAR_BELOW_ONE'; F = 'pure'; Old = '        Dim whole As Decimal = Math.Floor(sold)' + $nl + '        If whole <= 0D Then Return String.Empty'; New = '        Dim whole As Decimal = Math.Ceiling(sold)' + $nl + '        If whole <= 0D Then Return String.Empty' },
    @{ Id = 'M15_STOCK_NUMBER_IN_BAR'; F = 'pure'; Old = '        sb.Append("</div></div>")' + $nl + '        Return sb.ToString()'; New = '        sb.Append("</div><span>Disponibili: ").Append(Units(available)).Append("</span></div>")' + $nl + '        Return sb.ToString()' },
    @{ Id = 'M16_NEGATIVE_IDS'; F = 'pure'; Old = 'If id > 0 AndAlso seen.Add(id) Then'; New = 'If seen.Add(id) Then' },
    @{ Id = 'M17_SECOND_DEFINITION_IN_HOME'; F = 'homeVb'; Old = 'Return StorefrontSoldUnits.BuildCommercialActivitySql(articleIdList)'; New = 'Return "SELECT q.ArticoliId, ' + $signature + ' FROM x q"' },
    @{ Id = 'M18_STEPS_REMOVED'; F = 'pure'; Old = 'Return Math.Max(10, Math.Min(90, stepped))'; New = 'Return stepped' }
)
if (-not $SkipMutants) {
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        $m = @{}; foreach ($k in $files.Keys) { $m[$k] = $files[$k] }
        if ($mu.ContainsKey('Special')) {
            $line = [regex]::Match($m.card, '(?m)^[ \t]*<% If RenderSalesProgress Then %>\r?\n[ \t]*<%= SalesProgressHtml %>\r?\n[ \t]*<% End If %>\r?\n')
            if (-not $line.Success) { $survived.Add($mu.Id + ' (blocco non trovato)'); continue }
            $without = $m.card.Remove($line.Index, $line.Length)
            $anchor = '            <% If RenderPromoSummary Then %>'
            if ((Count-Of $without $anchor) -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
            $m.card = $without.Replace($anchor, $line.Value + $anchor)
        } else {
            if ((Count-Of $files[$mu.F] $mu.Old) -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
            $m[$mu.F] = $files[$mu.F].Replace($mu.Old, $mu.New)
        }
        $killed = -not (Test-Source $m -Quiet)
        if (-not $killed) { $killed = -not (Test-Compiled $m -Quiet) }
        if (-not $killed) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('CATALOG_DEAL_PROGRESS FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('CATALOG_DEAL_PROGRESS mutanti rilevati: ' + $mutants.Count)
}

# ---------------------------------------------------------------- (D) sito LAB reale
function Get-CatalogCards([string]$html) {
    $cards = New-Object Collections.Generic.List[object]
    $parts = $html -split '<article class="card-product '
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]; $end = $p.IndexOf('</article>'); if ($end -gt 0) { $p = $p.Substring(0, $end) }
        $id = [regex]::Match($p, 'href="[^"]*articolo\.aspx\?id=(\d+)')
        $tc = [regex]::Match($p, 'hfTCId"[^>]*value="(-?\d+)"')
        $sold = [regex]::Match($p, "class='ks-card-sales__head'><span>[^<]*</span><strong>([0-9.]+)</strong>")
        $now = [regex]::Match($p, "aria-valuenow='(\d+)'")
        $iBar = $p.IndexOf("class='ks-card-sales'"); $iPrice = $p.IndexOf('class="price-wrap fw-medium"')
        $cards.Add([pscustomobject]@{
            Id = if ($id.Success) { [int]$id.Groups[1].Value } else { 0 }
            Tc = if ($tc.Success) { [int]$tc.Groups[1].Value } else { -1 }
            HasBar = ($iBar -ge 0)
            BeforePrice = ($iBar -ge 0 -and $iPrice -gt $iBar)
            Sold = if ($sold.Success) { [int]($sold.Groups[1].Value -replace '\.', '') } else { -1 }
            Now = if ($now.Success) { [int]$now.Groups[1].Value } else { -1 }
            Promo = $p.Contains('<p class="small-text">Promo</p>')
            Stock = ($p.Substring([Math]::Max(0, $iBar), $(if ($iBar -ge 0 -and $iPrice -gt $iBar) { $iPrice - $iBar } else { 0 })) -match '(?i)disponibil')
        })
    }
    return $cards
}

if (-not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
    try {
        # ambito fiscale corretto, calcolato qui: l'azienda dell'host e le aziende con la stessa partita IVA valida (11 cifre, non tutta zeri, cifra di controllo)
        $company = Get-Scalar "SELECT id AS ksval FROM aziende WHERE LOWER(TRIM(COALESCE(url1,''))) LIKE '%www.taikun.it%' OR LOWER(TRIM(COALESCE(url2,''))) LIKE '%www.taikun.it%' ORDER BY id LIMIT 1;"
        Check ($company -match '^\d+$') 'L01 azienda dell''host trovata nel database LAB'
        function Get-Vat([string]$raw) { $v = $raw.Trim(); if ($v.Length -ge 2 -and $v.Substring(0, 2).ToUpperInvariant() -eq 'IT') { $v = $v.Substring(2) }; return $v }
        function Test-Vat([string]$v) {
            if ($v -notmatch '^\d{11}$' -or $v -eq '00000000000') { return $false }
            $sum = 0; for ($k = 0; $k -lt 10; $k++) { $d = [int]$v.Substring($k, 1); if (($k % 2) -eq 1) { $sum += [int]('0246813579'.Substring($d, 1)) } else { $sum += $d } }
            return (((10 - ($sum % 10)) % 10) -eq [int]$v.Substring(10, 1))
        }
        $vats = @{}
        foreach ($line in @(Invoke-Sql "SELECT CONCAT('ksvat|', id, '|', TRIM(COALESCE(Piva,''))) AS r FROM aziende;")) { $mm = [regex]::Match([string]$line, '^ksvat\|(\d+)\|(.*)$'); if ($mm.Success) { $vats[[int]$mm.Groups[1].Value] = (Get-Vat $mm.Groups[2].Value) } }
        $scope = New-Object Collections.Generic.List[int]; $scope.Add([int]$company)
        $own = if ($vats.ContainsKey([int]$company)) { $vats[[int]$company] } else { '' }
        if (Test-Vat $own) { foreach ($k in $vats.Keys) { if ($k -gt 0 -and $k -ne [int]$company -and $vats[$k] -eq $own) { $scope.Add($k) } } }

        function Get-Expected([int[]]$ids) {
            $expected = @{}
            if ($ids.Count -eq 0) { return $expected }
            $sql = "SELECT CONCAT('ksrow|', t.ArticoliId, '|', FLOOR(GREATEST(SUM(t.o), SUM(t.s)))) AS r FROM (" +
                   "SELECT dr.ArticoliId, IF(td.ImpegnaQnt = 1, dr.Qnt, 0) AS o, IF(td.Segno < 0, dr.Qnt, 0) AS s " +
                   "FROM documenti d JOIN documentirighe dr ON dr.DocumentiId = d.id JOIN tipodocumenti td ON td.id = d.TipoDocumentiId JOIN movimentitipo mt ON mt.id = td.MovimentiTipoId " +
                   "LEFT JOIN documentistati ds ON ds.id = d.StatiId " +
                   "WHERE d.AziendeId IN (" + ($scope -join ',') + ") AND UPPER(TRIM(mt.Descrizione)) = 'USCITA' AND dr.ArticoliId IN (" + ($ids -join ',') + ") AND dr.Qnt > 0 AND COALESCE(dr.TipoRiga, 'A') = 'A' " +
                   "AND d.DataDocumento >= CURDATE() - INTERVAL 12 MONTH AND d.DataDocumento < CURDATE() + INTERVAL 1 DAY AND (td.ImpegnaQnt = 1 OR td.Segno < 0) " +
                   "AND ((COALESCE(td.GestioneStato, 0) = 0 AND ds.id IS NULL) OR (ds.id IS NOT NULL AND ds.Abilitato = 1 AND LOWER(TRIM(ds.Descrizione1)) NOT LIKE 'annull%')) " +
                   "AND td.id NOT IN (SELECT tc.TipoDocumentiId FROM tipodocumenticontabili tc WHERE tc.NotaCreditoClienti = 1 OR tc.NotaCreditoFornitori = 1)) t GROUP BY t.ArticoliId;"
            foreach ($line in @(Invoke-Sql $sql)) { $mm = [regex]::Match([string]$line, '^ksrow\|(\d+)\|(\d+)'); if ($mm.Success) { $expected[[int]$mm.Groups[1].Value] = [int]$mm.Groups[2].Value } }
            return $expected
        }
        function Test-Page([string]$path, [string]$jar, [string]$tag, [bool]$guest, [int]$minBars) {
            $page = Invoke-Http $path $jar
            Check ($page.Status -eq 200) ($tag + ' la pagina risponde')
            $cards = @(Get-CatalogCards $page.Body)
            Check ($cards.Count -ge 1 -and @($cards | Where-Object { $_.Id -le 0 }).Count -eq 0) ($tag + ' schede lette: ' + $cards.Count)
            $expected = Get-Expected (@($cards | ForEach-Object { $_.Id }))
            $wrong = New-Object Collections.Generic.List[string]
            foreach ($c in $cards) {
                $exp = if ($expected.ContainsKey($c.Id)) { $expected[$c.Id] } else { 0 }
                $should = ($c.Promo -and $c.Tc -le 0 -and $exp -gt 0)
                if ($should -and (-not $c.HasBar -or $c.Sold -ne $exp)) { $wrong.Add(('{0}: atteso {1}, mostrato {2}' -f $c.Id, $exp, $c.Sold)) }
                if (-not $should -and $c.HasBar) { $wrong.Add(('{0}: barra non prevista (offerta={1}, variante={2}, venduti={3})' -f $c.Id, $c.Promo, $c.Tc, $exp)) }
            }
            Check ($wrong.Count -eq 0) ($tag + ' barra e "Venduti" uguali al calcolo indipendente per ogni scheda' + $(if ($wrong.Count) { ' -> ' + ($wrong -join '; ') } else { '' }))
            $bars = @($cards | Where-Object { $_.HasBar })
            Check ($bars.Count -ge $minBars) ($tag + ' schede con la barra: ' + $bars.Count + ' (minimo ' + $minBars + ')')
            Check (@($bars | Where-Object { -not $_.BeforePrice -or $_.Stock -or $_.Now -lt 1 -or $_.Now -gt 100 }).Count -eq 0) ($tag + ' barra prima del prezzo, senza numeri di disponibilita')
            if ($guest) { Check (@($bars | Where-Object { $_.Now -lt 10 -or $_.Now -gt 90 -or ($_.Now % 10) -ne 0 }).Count -eq 0) ($tag + ' ospite: gradini di 10 punti') }
            Check ((Count-Of $page.Body "class='ks-card-sales'") -eq $bars.Count) ($tag + ' nessuna barra fuori dalle schede dell''elenco')
        }
        $jar = Join-Path $tmp 'guest.txt'
        Test-Page '/articoli.aspx?inpromo=1' $jar 'L02 offerte (ospite):' $true 1
        Test-Page '/articoli.aspx' $jar 'L03 catalogo (ospite):' $true 0
        $jar2 = Join-Path $tmp 'user.txt'
        $null = Invoke-Login $jar2 $false
        Test-Page '/articoli.aspx?inpromo=1' $jar2 'L04 offerte (utente collegato):' $false 1
    } finally { Close-LabSite }
    if ($e2e.Count -gt 0) { Write-Host ('CATALOG_DEAL_PROGRESS FAIL (sito LAB): ' + $e2e.Count); exit 1 }
    Write-Host 'CATALOG_DEAL_PROGRESS sito LAB OK'
}

# ---------------------------------------------------------------- (E) browser reale a 390 e 1280 px
if (-not $SkipBrowser -and -not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    $measure = "(function(){var out={cards:[],scroll:document.documentElement.scrollWidth-window.innerWidth};var cards=document.querySelectorAll('#gridLayout article.card-product');" +
        "for(var i=0;i<cards.length;i++){var c=cards[i],rc=c.getBoundingClientRect();if(rc.width<=0){continue;}var pw=c.querySelector('.price-wrap'),bt=c.querySelector('.card-product-btn'),bar=c.querySelector('.ks-card-sales'),tr=c.querySelector('.ks-card-sales__track'),fill=c.querySelector('.ks-card-sales__bar');" +
        "var o={top:Math.round(rc.top),h:Math.round(rc.height),price:pw?Math.round(pw.getBoundingClientRect().top-rc.top):-1,btn:(bt&&bt.getBoundingClientRect().height>0)?Math.round(bt.getBoundingClientRect().top-rc.top):-1,bar:!!bar,promos:!!c.querySelector('.ks-catalog-promos')};" +
        "if(bar){var rb=bar.getBoundingClientRect(),rt=tr.getBoundingClientRect(),rf=fill.getBoundingClientRect();o.inside=(rb.left>=rc.left-1&&rb.right<=rc.right+1&&rb.bottom<=rc.bottom+1);o.track=rt.width;o.th=rt.height;o.fill=rf.width;o.now=parseInt(tr.getAttribute('aria-valuenow'),10);o.abovePrice=pw?(rb.bottom<=pw.getBoundingClientRect().top+1):false;o.label=(tr.getAttribute('aria-label')||'').length;o.color=getComputedStyle(fill).backgroundColor;o.bg=getComputedStyle(tr).backgroundColor;}" +
        "out.cards.push(o);}return JSON.stringify(out);})()"
    $browserFail = New-Object Collections.Generic.List[string]
    foreach ($vp in @(@{ W = 390; H = 844; M = $true }, @{ W = 1280; H = 900; M = $false })) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            Open-KsUrl $b 'https://www.taikun.it:18843/articoli.aspx?inpromo=1' 240
            Start-Sleep -Milliseconds 1500
            $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
            $tag = 'E' + $vp.W
            $cards = @($r.cards); $bars = @($cards | Where-Object { $_.bar })
            if ($cards.Count -lt 4) { $browserFail.Add($tag + ' schede misurate: ' + $cards.Count) }
            if ($bars.Count -lt 1) { $browserFail.Add($tag + ' nessuna barra') }
            if ($r.scroll -gt 1) { $browserFail.Add($tag + ' scorrimento orizzontale di ' + $r.scroll + ' px') }
            foreach ($x in $bars) {
                if (-not $x.inside) { $browserFail.Add($tag + ' barra fuori dalla scheda') }
                if (-not $x.abovePrice) { $browserFail.Add($tag + ' barra non sopra il prezzo') }
                if ($x.track -lt 80 -or $x.th -lt 5) { $browserFail.Add($tag + ' barra troppo piccola: ' + [int]$x.track + 'x' + [int]$x.th) }
                elseif ([Math]::Abs((100.0 * $x.fill / $x.track) - $x.now) -gt 2) { $browserFail.Add($tag + ' larghezza della barra diversa dal valore: ' + [int](100.0 * $x.fill / $x.track) + ' / ' + $x.now) }
                if ($x.label -lt 12) { $browserFail.Add($tag + ' nome accessibile assente') }
                if ($x.color -eq $x.bg -or $x.color -match 'rgba\(0, 0, 0, 0\)') { $browserFail.Add($tag + ' barra senza colore') }
            }
            $mixedRows = 0
            foreach ($grp in ($cards | Group-Object top)) {
                $g = @($grp.Group); if ($g.Count -lt 2) { continue }
                if (@($g | Where-Object { $_.bar }).Count -gt 0 -and @($g | Where-Object { -not $_.bar }).Count -gt 0) { $mixedRows++ }
                foreach ($prop in @('h', 'price', 'btn')) {
                    # il riquadro "prezzo a quantita" sta sotto il prezzo e lo alza (comportamento precedente al task): i prezzi si confrontano fra schede senza quel riquadro
                    $vals = @($g | Where-Object { $prop -ne 'price' -or -not $_.promos } | ForEach-Object { $_.$prop } | Where-Object { $_ -ge 0 })
                    if ($vals.Count -ge 2 -and (($vals | Measure-Object -Maximum).Maximum - ($vals | Measure-Object -Minimum).Minimum) -gt 1) { $browserFail.Add($tag + ' fila a ' + $grp.Name + ' px non allineata (' + $prop + '): ' + ($vals -join ',')) }
                }
            }
            Write-Host ('  ' + $tag + ': schede ' + $cards.Count + ', con barra ' + $bars.Count + ', file miste (con e senza barra) ' + $mixedRows + ', scorrimento ' + $r.scroll)
        } catch { $browserFail.Add('E' + $vp.W + ' ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($browserFail.Count -gt 0) { foreach ($x in ($browserFail | Select-Object -Unique)) { Write-Host ('  FAIL ' + $x) }; Write-Host 'CATALOG_DEAL_PROGRESS FAIL (browser)'; exit 1 }
    Write-Host 'CATALOG_DEAL_PROGRESS browser OK'
}

Write-Host 'CATALOG_DEAL_PROGRESS OK'
exit 0
