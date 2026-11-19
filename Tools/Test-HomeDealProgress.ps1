[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipBrowser, [switch]$SkipMutants, [string]$CodeBehindPath = '', [string]$PagePath = '')

# HOME-DEAL-PROGRESS-1A. Barra delle vendite nelle schede di "Occasione Imperdibile" (decisione del PO del 2026-11-19: "tutte le vendite").
# Regole provate:
#  - i venduti vengono SOLO dalla misura commerciale dichiarata (BuildHomeCommercialActivitySql: azienda dell'host, ultimi 12 mesi,
#    uscite non annullate, senza contare due volte ordine e scarico) e solo per le schede delle occasioni;
#  - zero venduti, dato assente o errore = nessuna barra, e la HOME non si ferma;
#  - le occasioni con vendite vengono prima;
#  - chi non puo vedere i numeri di giacenza vede la barra a gradini di 10 punti e nessun numero di disponibilita.
# (A) sorgenti, (B) funzioni compilate, (C) mutazioni, (D) SITO LAB reale (https, 127.0.0.1, porta 18843, database LAB),
# (E) browser a 390 e 1280 px (barra e scheda compatta: nessuno spazio riservato vuoto, richiesta del PO del 2026-11-19). Sostituisce Tools/Test-HomeSalesPublicClaims.ps1 (confronto con una fotografia storica). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($CodeBehindPath -eq '') { $CodeBehindPath = Join-Path $root 'Default.aspx.vb' }
if ($PagePath -eq '') { $PagePath = Join-Path $root 'Default.aspx' }
$files = @{ vb = [IO.File]::ReadAllText($CodeBehindPath, $utf8); page = [IO.File]::ReadAllText($PagePath, $utf8) }

function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i + $end.Length)
}
function Count-Of([string]$text, [string]$needle) { return ([regex]::Matches($text, [regex]::Escape($needle))).Count }

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $vb = $f.vb
    $apply = Get-Block $vb 'Private Function ApplyDealSoldUnits(' 'End Function'
    $render = Get-Block $vb 'Private Function RenderDealProgress(' 'End Function'
    $card = Get-Block $vb 'Protected Function RenderDealCard(' 'End Function'
    $index = Get-Block $vb 'Private Function BuildHomeCommercialActivitySql(' 'End Function'
    # S01 una sola fonte dei venduti: la misura commerciale gia usata dalla HOME, filtrata sugli articoli candidati
    if (-not $apply.Contains('BuildHomeCommercialActivitySql(idList)')) { $fail.Add('S01 venduti dalla misura commerciale filtrata per articoli') }
    if (-not $apply.Contains('cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = GetCurrentAziendaId()')) { $fail.Add('S01 azienda dell''host') }
    if (-not $apply.Contains('cmd.Parameters.Add("@commercialStart", MySqlDbType.Date).Value = Date.Today.AddMonths(-12)')) { $fail.Add('S01 ultimi 12 mesi') }
    if (-not $apply.Contains('ids.ConvertAll(Function(value As Integer) value.ToString(CultureInfo.InvariantCulture))')) { $fail.Add('S01 elenco di soli numeri interi') }
    if ($apply -notmatch 'Catch ex As Exception\s+KeepStoreLog\.Error\("home-deal-progress", "Deal sold units unavailable\. Error type: " & ex\.GetType\(\)\.Name & "\.", Nothing, HttpContext\.Current\)\s+Return False\s+End Try') { $fail.Add('S01 un errore lascia la HOME in piedi e non scrive dati nel registro') }
    # S02 il filtro per articoli sta dentro la query dell'indice e nessun altro lo usa
    if (-not $index.Contains('If(String.IsNullOrEmpty(articleIdList), String.Empty, "AND dr.ArticoliId IN (" & articleIdList & ") ") &')) { $fail.Add('S02 filtro per articoli nella query') }
    if (([regex]::Matches($vb, 'BuildHomeCommercialActivitySql\((?!\)|Optional)')).Count -ne 1) { $fail.Add('S02 un solo chiamante con il filtro') }
    # S03 lettura prima della rotazione, poi "prima chi vende"
    $iApply = $vb.IndexOf('ApplyDealSoldUnits(dealPool)'); $iOrder = $vb.IndexOf('dealPool = RotateHomePool("deals", dealPool, 6, usedBusinessKeys, usedDisplayKeys)' + "`r`n" + '        dealPool = PrioritizeSoldDeals(dealPool)' + "`r`n")
    if ($iApply -lt 0 -or $iOrder -lt 0 -or $iApply -gt $iOrder) { $fail.Add('S03 venduti letti e occasioni ordinate') }
    # S04 la barra: mai a zero, numeri di disponibilita e percentuale esatta solo con DisplayMode = 2, disponibilita netta
    if (-not $render.Contains('If sold <= 0D Then Return String.Empty')) { $fail.Add('S04 nessuna barra senza venduti') }
    if (-not $render.Contains('Dim exact As Boolean = model.DisplayMode = 2')) { $fail.Add('S04 numeri solo a chi puo vederli') }
    if (-not $render.Contains('Dim available As Decimal = Math.Max(0D, model.AvailableQty)')) { $fail.Add('S04 disponibilita netta della scheda') }
    if ($render -match '(?i)Giacenza|InOrdine|Impegnat') { $fail.Add('S04 nessuna giacenza lorda nella barra') }
    if (-not $render.Contains('If exact Then sb.Append("<p class=''text-avaiable caption''>Disponibili: ')) { $fail.Add('S04 "Disponibili" solo a chi puo vedere i numeri') }
    if ((Count-Of $render 'Disponibili') -ne 1 -or (Count-Of $render ' disponibili"') -ne 1) { $fail.Add('S04 una sola riga con la disponibilita') }
    if (-not $render.Contains('If exact Then sb.Append("<strong>").Append(percentText).Append("%</strong>")')) { $fail.Add('S04 percentuale scritta solo a chi puo vedere i numeri') }
    if (-not $render.Contains("aria-label='"").Append(EncodeAttr(""Vendite di "" & productName))")) { $fail.Add('S04 nome accessibile con il prodotto') }
    if (-not $render.Contains("role='progressbar' aria-valuemin='0' aria-valuemax='100' aria-valuenow='"").Append(percentText)") -or -not $render.Contains("aria-valuetext='"").Append(EncodeAttr(valueText))")) { $fail.Add('S04 ruolo, valore e testo') }
    if ($render.Contains('data-ks-')) { $fail.Add('S04 nessun attributo data-ks') }
    # S05 la barra solo nella scheda dell'occasione
    if ((Count-Of $vb 'RenderDealProgress(') -ne 2 -or (Count-Of $card 'RenderDealProgress(row)') -ne 1) { $fail.Add('S05 barra solo nella scheda dell''occasione') }
    if (-not $card.Contains('If Not String.IsNullOrEmpty(countdownHtml) OrElse Not String.IsNullOrEmpty(progressHtml) Then')) { $fail.Add('S05 piede con conto alla rovescia oppure barra') }
    # S06 nessun numero di vendita da altre fonti: la query generale resta a zero, la colonna si scrive in un solo punto
    if ((Count-Of $vb '0 AS QtaVenduta, 0 AS VendutiAnno') -ne 2) { $fail.Add('S06 query generale senza numeri di vendita') }
    if ((Count-Of $vb 'row("QtaVenduta") =') -ne 2 -or (Count-Of $apply 'row("QtaVenduta") =') -ne 2) { $fail.Add('S06 venduti scritti solo dalla lettura dichiarata') }
    if ((Count-Of $vb 'VendutiAnno') -ne 3) { $fail.Add('S06 la vecchia colonna non si usa') }
    # S07 stile nella HOME, colore del tema, contrasto forzato
    $css = Get-Block $f.page '<style id="ksHomeDealProgressStyles">' '</style>'
    if ($css -eq '' -or -not $css.Contains('.ks-deal-progress__bar {') -or -not $css.Contains('background: var(--primary, #D80027);') -or -not $css.Contains('@media (forced-colors: active)')) { $fail.Add('S07 stile della barra') }
    if (-not $css.Contains('body.ks-page-home .ks-home-deals .swiper-slide > .ks-deal-card { flex: 1 1 auto; height: auto; }')) { $fail.Add('S07 schede della stessa altezza') }
    # S08 scheda compatta: nessuno spazio riservato vuoto fra categoria, titolo, prezzo e disponibilita
    $compact = Get-Block $f.page '/* Scheda compatta' '/* Fine scheda compatta */'
    $prefix = 'body.ks-page-home #ksHomePage .ks-home-deals .ks-deal-card '
    foreach ($rule in @(
        '.card-product-info { gap: 8px !important; }',
        '.box-infor-detail { gap: 12px !important; padding-top: 4px; }',
        '.ks-deal-slot--category .ks-card-category { height: auto !important; min-height: 0 !important; margin: 0; }',
        '.name-product { margin-bottom: 0; }',
        '.price-wrap.ks-home-price-slot { height: auto; min-height: 0; }',
        '.ks-deal-slot--availability .ks-availability { margin-top: 0; }')) {
        if (-not $compact.Contains($prefix + $rule)) { $fail.Add('S08 scheda compatta: ' + $rule) }
    }
    foreach ($slot in @('.ks-deal-slot--category', '.ks-deal-slot--price .ks-home-price-stack', '.ks-deal-slot--price .ks-deal-price-amount-slot', '.ks-deal-slot--price .ks-deal-price-tier-slot', '.ks-deal-slot--availability')) {
        if (-not $compact.Contains($prefix + $slot + ' { min-height: 0; }')) { $fail.Add('S08 spazio riservato tolto: ' + $slot) }
    }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

# (B) Funzioni pure e ordine "prima chi vende", compilati dal sorgente reale.
function Test-Compiled([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $pure = Get-Block $f.vb '#Region "DealProgressPure"' '#End Region'
    $order = Get-Block $f.vb 'Private Function PrioritizeSoldDeals(' 'End Function'
    if ($pure -eq '' -or $order -eq '') { if (-not $Quiet) { Write-Host '  FAIL C00 funzioni non trovate' }; return $false }
    $ns = 'KsDeal' + [Guid]::NewGuid().ToString('N')
    $code = "Imports System`r`nImports System.Data`r`nNamespace $ns`r`nPublic Class Probe`r`n" +
        "Private Shared Function IsTableEmpty(ByVal t As DataTable) As Boolean`r`nReturn t Is Nothing OrElse t.Rows.Count = 0`r`nEnd Function`r`n" +
        "Private Shared Function ToDecimal(ByVal v As Object) As Decimal`r`nIf v Is Nothing OrElse v Is DBNull.Value Then Return 0D`r`nReturn Convert.ToDecimal(v)`r`nEnd Function`r`n" +
        $pure + "`r`n" + $order.Replace('Private Function PrioritizeSoldDeals(', 'Public Shared Function Order(') + "`r`n" +
        "Public Shared Function Pct(ByVal s As Decimal, ByVal a As Decimal, ByVal e As Boolean) As Integer`r`nReturn DealProgressPercent(s, a, e)`r`nEnd Function`r`n" +
        "Public Shared Function Units(ByVal v As Decimal) As String`r`nReturn DealProgressUnits(v)`r`nEnd Function`r`n" +
        "End Class`r`nEnd Namespace`r`n"
    try { $types = Add-Type -TypeDefinition $code -Language VisualBasic -ReferencedAssemblies 'System.Data', 'System.Xml' -PassThru -ErrorAction Stop }
    catch { if (-not $Quiet) { Write-Host ('  FAIL C00 compilazione: ' + $_.Exception.Message) }; return $false }
    $t = @($types | Where-Object { $_.Name -eq 'Probe' })[0]
    # sold, available, exact, expected
    $cases = @(
        @(0, 10, $true, 0), @(0, 10, $false, 0), @(-3, 10, $true, 0), @(0, 0, $false, 0),
        @(1, 99, $true, 1), @(1, 1000, $true, 1), @(50, 50, $true, 50), @(2, 1, $true, 66), @(99, 1, $true, 99), @(1000, 1, $true, 99), @(5, 0, $true, 100), @(5, -4, $true, 100),
        @(1, 1000, $false, 10), @(50, 50, $false, 50), @(2, 1, $false, 70), @(1, 3, $false, 30), @(45, 55, $false, 50), @(44, 56, $false, 40), @(1000, 1, $false, 90), @(5, 0, $false, 90), @(1, 2, $false, 30)
    )
    foreach ($c in $cases) {
        try { $got = $t::Pct([decimal]$c[0], [decimal]$c[1], [bool]$c[2]) } catch { $got = 'errore' }
        if ($got -ne $c[3]) { $fail.Add(('C01 percentuale venduti={0} disponibili={1} esatta={2}: atteso {3}, ottenuto {4}' -f $c[0], $c[1], $c[2], $c[3], $got)) }
    }
    if ($t::Units([decimal]1234.9) -ne '1.234' -or $t::Units([decimal]0) -ne '0' -or $t::Units([decimal]-3) -ne '0' -or $t::Units([decimal]7) -ne '7') { $fail.Add('C02 quantita intere con separatore italiano') }
    $dt = New-Object Data.DataTable
    $null = $dt.Columns.Add('id', [int]); $null = $dt.Columns.Add('QtaVenduta', [decimal])
    foreach ($r in @(@(1, 0), @(2, 5), @(3, 0), @(4, 2), @(5, 0.4))) { $null = $dt.Rows.Add($r[0], [decimal]$r[1]) }
    $out = $t::Order($dt)
    $seq = (@($out.Rows | ForEach-Object { [string]$_['id'] }) -join ',')
    if ($seq -ne '2,4,5,1,3') { $fail.Add('C03 prima le occasioni con vendite, ordine interno invariato: ' + $seq) }
    if ($dt.Rows.Count -ne 5) { $fail.Add('C03 la tabella di partenza non cambia') }
    $plain = New-Object Data.DataTable; $null = $plain.Columns.Add('id', [int]); $null = $plain.Rows.Add(1)
    if (-not [object]::ReferenceEquals($t::Order($plain), $plain)) { $fail.Add('C03 senza la colonna dei venduti nulla cambia') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$sourceOk = Test-Source $files
$compiledOk = Test-Compiled $files
if (-not ($sourceOk -and $compiledOk)) { Write-Host 'HOME_DEAL_PROGRESS FAIL (sorgenti o funzioni)'; exit 1 }
Write-Host 'HOME_DEAL_PROGRESS sorgenti e funzioni OK'

$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_GUEST_EXACT'; Old = 'Dim exact As Boolean = model.DisplayMode = 2'; New = 'Dim exact As Boolean = True' },
    @{ Id = 'M02_GUEST_SEES_STOCK'; Old = 'If exact Then sb.Append("<p class=''text-avaiable caption''>Disponibili: '; New = 'sb.Append("<p class=''text-avaiable caption''>Disponibili: ' },
    @{ Id = 'M03_BAR_AT_ZERO'; Old = 'If sold <= 0D Then Return String.Empty'; New = 'If sold < 0D Then Return String.Empty' },
    @{ Id = 'M04_PERCENT_AT_ZERO'; Old = 'If sold <= 0D Then Return 0'; New = 'If sold < 0D Then Return 0' },
    @{ Id = 'M05_GROSS_STOCK'; Old = 'Math.Max(0D, model.AvailableQty)'; New = 'Math.Max(0D, ToDecimal(row("Giacenza")))' },
    @{ Id = 'M06_ORDER_NOT_APPLIED'; Old = '        dealPool = PrioritizeSoldDeals(dealPool)' + $nl; New = '' },
    @{ Id = 'M07_ORDER_INVERTED'; Old = 'New Boolean() {True, False}'; New = 'New Boolean() {False, True}' },
    @{ Id = 'M08_NO_ACCESSIBLE_NAME'; Old = "sb.Append(""' aria-valuetext='"").Append(EncodeAttr(valueText)).Append(""' aria-label='"").Append(EncodeAttr(""Vendite di "" & productName)).Append(""'>"")"; New = "sb.Append(""' aria-valuetext='"").Append(EncodeAttr(valueText)).Append(""'>"")" },
    @{ Id = 'M09_BAR_ON_OTHER_CARDS'; Old = '        Dim progressHtml As String = RenderDealProgress(row)'; New = '        Dim progressHtml As String = RenderDealProgress(row)' + $nl + '        Dim extraHtml As String = RenderDealProgress(row)' },
    @{ Id = 'M10_NO_STEPS_LIMIT'; Old = 'Return Math.Max(10, Math.Min(90, stepped))'; New = 'Return stepped' },
    @{ Id = 'M11_GUEST_GETS_EXACT_VALUE'; Old = '        If exact Then' + $nl + '            If stock <= 0D Then Return 100'; New = '        If True Then' + $nl + '            If stock <= 0D Then Return 100' },
    @{ Id = 'M12_EXACT_ZERO_PERCENT'; Old = 'Return CInt(Math.Max(1D, Math.Min(99D, Math.Floor(raw))))'; New = 'Return CInt(Math.Min(99D, Math.Floor(raw)))' },
    @{ Id = 'M13_ROUND_UP'; Old = 'Math.Min(99D, Math.Floor(raw))'; New = 'Math.Min(99D, Math.Ceiling(raw))' },
    @{ Id = 'M14_OTHER_COMPANY'; Old = '") x", conn)' + $nl + '                    cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = GetCurrentAziendaId()'; New = '") x", conn)' + $nl + '                    cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = 1' },
    @{ Id = 'M15_ALL_TIME'; Old = 'Date.Today.AddMonths(-12)' + $nl + '                    cmd.Parameters.Add("@commercialEnd"'; New = 'Date.Today.AddYears(-20)' + $nl + '                    cmd.Parameters.Add("@commercialEnd"' },
    @{ Id = 'M16_ERROR_STOPS_HOME'; Old = 'Nothing, HttpContext.Current)' + $nl + '            Return False' + $nl + '        End Try' + $nl + '        pool.Columns("QtaVenduta")'; New = 'Nothing, HttpContext.Current)' + $nl + '            Throw' + $nl + '        End Try' + $nl + '        pool.Columns("QtaVenduta")' },
    @{ Id = 'M17_NO_ARTICLE_FILTER'; Old = 'BuildHomeCommercialActivitySql(idList)'; New = 'BuildHomeCommercialActivitySql()' },
    @{ Id = 'M18_SALES_IN_GENERAL_QUERY'; Old = 'sql.Append("0 AS QtaVenduta, 0 AS VendutiAnno, ")'; New = 'sql.Append("a.QtaVenduta AS QtaVenduta, 0 AS VendutiAnno, ")' },
    @{ Id = 'M19_THOUSANDS_INVARIANT'; Old = 'System.Globalization.CultureInfo.GetCultureInfo("it-IT")'; New = 'System.Globalization.CultureInfo.InvariantCulture' },
    @{ Id = 'M20_STEP_ROUNDING_DOWN'; Old = 'CInt(Math.Round(raw / 10D, MidpointRounding.AwayFromZero)) * 10'; New = 'CInt(Math.Floor(raw / 10D)) * 10' },
    @{ Id = 'M21_FOOTER_ONLY_WITH_COUNTDOWN'; Old = 'If Not String.IsNullOrEmpty(countdownHtml) OrElse Not String.IsNullOrEmpty(progressHtml) Then'; New = 'If Not String.IsNullOrEmpty(countdownHtml) Then' }
)
if (-not $SkipMutants) {
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        if ((Count-Of $files.vb $mu.Old) -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
        $m = @{ vb = $files.vb.Replace($mu.Old, $mu.New); page = $files.page }
        $killed = -not (Test-Source $m -Quiet)
        if (-not $killed) { $killed = -not (Test-Compiled $m -Quiet) }
        if (-not $killed) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('HOME_DEAL_PROGRESS FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('HOME_DEAL_PROGRESS mutanti rilevati: ' + $mutants.Count)
}

# ---------------------------------------------------------------- (D) sito LAB reale
function Get-DealCards([string]$html) {
    $cards = New-Object Collections.Generic.List[object]
    $marker = "<div class='card-product style-border ks-deal-card"
    $parts = $html -split [regex]::Escape($marker)
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        $end = $p.IndexOf('<div class="swiper-slide">'); if ($end -gt 0) { $p = $p.Substring(0, $end) }
        $end = $p.IndexOf('</section>'); if ($end -gt 0) { $p = $p.Substring(0, $end) }
        $id = [regex]::Match($p, "href='articolo\.aspx\?id=(\d+)'")
        $sold = [regex]::Match($p, "Venduti: <span class='fw-bold'>([0-9.]+)</span>")
        $avail = [regex]::Match($p, "Disponibili: <span class='fw-bold'>([0-9.]+)</span>")
        $now = [regex]::Match($p, "aria-valuenow='(\d+)'")
        $label = [regex]::Match($p, "aria-label='Vendite di ([^']+)'")
        $cards.Add([pscustomobject]@{
            Id = if ($id.Success) { [int]$id.Groups[1].Value } else { 0 }
            HasBar = $p.Contains("class='progress-sold progress ks-deal-progress__track'")
            Sold = if ($sold.Success) { [int]($sold.Groups[1].Value -replace '\.', '') } else { -1 }
            Available = if ($avail.Success) { [int]($avail.Groups[1].Value -replace '\.', '') } else { -1 }
            Now = if ($now.Success) { [int]$now.Groups[1].Value } else { -1 }
            Label = $label.Success
            ShowsPercent = ($p -match "<strong>\d+%</strong>")
        })
    }
    return $cards
}

if (-not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')
    try {
        $jar = Join-Path $tmp 'guest.txt'
        $home1 = Invoke-Http '/Default.aspx' $jar
        Check ($home1.Status -eq 200) 'L01 HOME del sito LAB risponde'
        $cards = @(Get-DealCards $home1.Body)
        Check ($cards.Count -ge 1 -and @($cards | Where-Object { $_.Id -le 0 }).Count -eq 0) ('L01 schede delle occasioni lette: ' + $cards.Count)
        $withBar = @($cards | Where-Object { $_.HasBar })
        Check ($withBar.Count -ge 1) ('L02 almeno una occasione mostra la barra: ' + $withBar.Count)
        # Calcolo indipendente: stessa definizione, scritta di nuovo qui (azienda dell'host e aziende con la stessa partita IVA).
        $company = Get-Scalar "SELECT id AS ksval FROM aziende WHERE LOWER(TRIM(COALESCE(url1,''))) LIKE '%www.taikun.it%' OR LOWER(TRIM(COALESCE(url2,''))) LIKE '%www.taikun.it%' ORDER BY id LIMIT 1;"
        Check ($company -match '^\d+$') 'L03 azienda dell''host trovata nel database LAB'
        $in = (@($cards | ForEach-Object { $_.Id }) -join ',')
        $sql = "SELECT CONCAT('ksrow|', t.ArticoliId, '|', FLOOR(GREATEST(SUM(t.o), SUM(t.s)))) AS r FROM (" +
               "SELECT dr.ArticoliId, IF(td.ImpegnaQnt = 1, dr.Qnt, 0) AS o, IF(td.Segno < 0, dr.Qnt, 0) AS s " +
               "FROM documenti d JOIN documentirighe dr ON dr.DocumentiId = d.id JOIN tipodocumenti td ON td.id = d.TipoDocumentiId JOIN movimentitipo mt ON mt.id = td.MovimentiTipoId " +
               "LEFT JOIN documentistati ds ON ds.id = d.StatiId " +
               "WHERE d.AziendeId IN (SELECT x.id FROM (SELECT a2.id FROM aziende a1 JOIN aziende a2 ON a2.id = a1.id OR (CHAR_LENGTH(TRIM(a1.Piva)) >= 11 AND REPLACE(UPPER(TRIM(a2.Piva)), 'IT', '') = REPLACE(UPPER(TRIM(a1.Piva)), 'IT', '')) WHERE a1.id = $company) x) " +
               "AND UPPER(TRIM(mt.Descrizione)) = 'USCITA' AND dr.ArticoliId IN ($in) AND dr.Qnt > 0 AND COALESCE(dr.TipoRiga, 'A') = 'A' " +
               "AND d.DataDocumento >= CURDATE() - INTERVAL 12 MONTH AND d.DataDocumento < CURDATE() + INTERVAL 1 DAY " +
               "AND (td.ImpegnaQnt = 1 OR td.Segno < 0) " +
               "AND ((COALESCE(td.GestioneStato, 0) = 0 AND ds.id IS NULL) OR (ds.id IS NOT NULL AND ds.Abilitato = 1 AND LOWER(TRIM(ds.Descrizione1)) NOT LIKE 'annull%')) " +
               "AND td.id NOT IN (SELECT tc.TipoDocumentiId FROM tipodocumenticontabili tc WHERE tc.NotaCreditoClienti = 1 OR tc.NotaCreditoFornitori = 1)" +
               ") t GROUP BY t.ArticoliId;"
        $expected = @{}
        foreach ($line in @(Invoke-Sql $sql)) { $mm = [regex]::Match([string]$line, '^ksrow\|(\d+)\|(\d+)'); if ($mm.Success) { $expected[[int]$mm.Groups[1].Value] = [int]$mm.Groups[2].Value } }
        $wrong = New-Object Collections.Generic.List[string]
        foreach ($c in $cards) {
            $exp = if ($expected.ContainsKey($c.Id)) { $expected[$c.Id] } else { 0 }
            if ($exp -gt 0) { if (-not $c.HasBar -or $c.Sold -ne $exp) { $wrong.Add(('{0}: atteso {1}, mostrato {2}' -f $c.Id, $exp, $c.Sold)) } }
            elseif ($c.HasBar) { $wrong.Add(('{0}: barra senza vendite' -f $c.Id)) }
        }
        Check ($wrong.Count -eq 0) ('L04 "Venduti" uguale al calcolo indipendente per ogni scheda' + $(if ($wrong.Count) { ' -> ' + ($wrong -join '; ') } else { '' }))
        $seenNoBar = $false; $orderOk = $true
        foreach ($c in $cards) { if (-not $c.HasBar) { $seenNoBar = $true } elseif ($seenNoBar) { $orderOk = $false } }
        Check $orderOk 'L05 le occasioni con vendite vengono prima'
        $guestBad = @($withBar | Where-Object { $_.Available -ge 0 -or $_.ShowsPercent -or $_.Now -lt 10 -or $_.Now -gt 90 -or ($_.Now % 10) -ne 0 -or -not $_.Label })
        Check ($guestBad.Count -eq 0) 'L06 ospite: gradini di 10 punti, nessun numero di disponibilita, nome accessibile'
        $section = Get-Block $home1.Body 'class="ks-home-section ks-home-deals"' '</section>'
        Check ((Count-Of $home1.Body "ks-deal-progress__track'") -eq $withBar.Count -and (Count-Of $section "ks-deal-progress__track'") -eq $withBar.Count) 'L07 nessuna barra fuori dalle schede delle occasioni'
        # Utente di prova collegato: se puo vedere i numeri, percentuale esatta e coerente con i numeri mostrati.
        $jar2 = Join-Path $tmp 'user.txt'
        $null = Invoke-Login $jar2 $false
        $home2 = Invoke-Http '/Default.aspx' $jar2
        $cards2 = @(Get-DealCards $home2.Body | Where-Object { $_.HasBar })
        $numeric = @($cards2 | Where-Object { $_.Available -ge 0 })
        if ($home2.Status -ne 200) { Check $false 'L08 HOME con utente collegato' }
        elseif ($numeric.Count -eq 0) { Write-Host '  NON ESEGUITO L08: l''utente di prova non vede i numeri di giacenza in queste schede (resta la prova sui sorgenti e sulle funzioni)' }
        else {
            $bad = @($numeric | Where-Object {
                $exp = if ($_.Available -le 0) { 100 } else { [Math]::Max(1, [Math]::Min(99, [int][Math]::Floor(100.0 * $_.Sold / ($_.Sold + $_.Available)))) }
                $_.Now -ne $exp -or -not $_.ShowsPercent })
            Check ($bad.Count -eq 0) ('L08 collegato con numeri: percentuale esatta coerente con venduti e disponibili (' + $numeric.Count + ' schede)')
        }
    } finally { Close-LabSite }
    if ($e2e.Count -gt 0) { Write-Host ('HOME_DEAL_PROGRESS FAIL (sito LAB): ' + $e2e.Count); exit 1 }
    Write-Host 'HOME_DEAL_PROGRESS sito LAB OK'
}

# ---------------------------------------------------------------- (E) browser reale a 390 e 1280 px
if (-not $SkipBrowser -and -not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    $measure = "(function(){var s=document.querySelector('.ks-home-deals');if(!s){return JSON.stringify({section:false});}" +
        "var out={section:true,scroll:document.documentElement.scrollWidth-window.innerWidth,bars:[],heights:[]};" +
        "var cards=s.querySelectorAll('.swiper-slide > .ks-deal-card');out.cards=[];for(var i=0;i<cards.length;i++){var cd=cards[i];out.heights.push(Math.round(cd.getBoundingClientRect().height));" +
        "var q=function(x){var e=cd.querySelector(x);return e?e.getBoundingClientRect():null;};var cat=q('.ks-card-category'),ti=q('.name-product'),pw=q('.price-wrap'),np=q('.new-price'),tier=q('.ks-home-promo-tier'),av=q('.ks-availability'),sv=q('.box-sale-tag');" +
        "if(cat&&ti&&pw&&np&&av){var ce=cd.querySelector('.ks-card-category');var lh=parseFloat(getComputedStyle(ce).lineHeight)||14;var above=tier?tier.bottom:pw.bottom;" +
        "out.cards.push({catLines:Math.round(cat.height/lh),catText:Math.max(1,Math.round((function(){var g=document.createRange();g.selectNodeContents(ce);return g.getBoundingClientRect().height;})()/lh)),catTitle:Math.round(ti.top-cat.bottom),titlePrice:Math.round(pw.top-ti.bottom),priceExtra:Math.round(pw.height-(function(){var g=document.createRange();g.selectNodeContents(cd.querySelector('.price-wrap'));var q=g.getClientRects(),a=1e9,z=-1e9;for(var k=0;k<q.length;k++){if(q[k].height>0){a=Math.min(a,q[k].top);z=Math.max(z,q[k].bottom);}}return z-a;})()),priceAvail:Math.round(av.top-above),availSave:sv?Math.round(sv.top-av.bottom):0});}}" +
        "var tr=s.querySelectorAll('.ks-deal-progress__track');for(var j=0;j<tr.length;j++){var t=tr[j],b=t.querySelector('.ks-deal-progress__bar'),c=t.closest('.ks-deal-card');" +
        "var rt=t.getBoundingClientRect(),rb=b.getBoundingClientRect(),rc=c.getBoundingClientRect(),box=t.closest('.ks-deal-progress').getBoundingClientRect();" +
        "out.bars.push({now:parseInt(t.getAttribute('aria-valuenow'),10),track:rt.width,bar:rb.width,th:rt.height,inside:(box.left>=rc.left-1&&box.right<=rc.right+1&&box.top>=rc.top-1&&box.bottom<=rc.bottom+1)," +
        "label:(t.getAttribute('aria-label')||'').length,color:getComputedStyle(b).backgroundColor,bg:getComputedStyle(t).backgroundColor});}" +
        "return JSON.stringify(out);})()"
    $browserFail = New-Object Collections.Generic.List[string]
    foreach ($vp in @(@{ W = 390; H = 844; M = $true }, @{ W = 1280; H = 900; M = $false })) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            Open-KsUrl $b 'https://www.taikun.it:18843/Default.aspx' 240
            $null = Invoke-KsJs $b "(function(){var s=document.querySelector('.ks-home-deals');if(s){s.scrollIntoView({block:'center'});}return 'ok';})()"
            Start-Sleep -Milliseconds 2500
            $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
            $tag = 'E' + $vp.W
            if (-not $r.section) { $browserFail.Add($tag + ' sezione delle occasioni assente'); continue }
            $bars = @($r.bars)
            if ($bars.Count -lt 1) { $browserFail.Add($tag + ' nessuna barra') }
            if ($r.scroll -gt 1) { $browserFail.Add($tag + ' scorrimento orizzontale di ' + $r.scroll + ' px') }
            foreach ($x in $bars) {
                if (-not $x.inside) { $browserFail.Add($tag + ' barra fuori dalla scheda') }
                if ($x.track -lt 80 -or $x.th -lt 6) { $browserFail.Add($tag + ' barra troppo piccola: ' + [int]$x.track + 'x' + [int]$x.th) }
                elseif ([Math]::Abs((100.0 * $x.bar / $x.track) - $x.now) -gt 2) { $browserFail.Add($tag + ' larghezza della barra diversa dal valore: ' + [int](100.0 * $x.bar / $x.track) + ' / ' + $x.now) }
                if ($x.label -lt 12) { $browserFail.Add($tag + ' nome accessibile assente') }
                if ($x.color -eq $x.bg -or $x.color -match 'rgba\(0, 0, 0, 0\)') { $browserFail.Add($tag + ' barra senza colore') }
            }
            $gaps = @($r.cards)
            if ($gaps.Count -lt 1 -or $gaps.Count -ne @($r.heights).Count) { $browserFail.Add($tag + ' schede senza un elemento atteso: misurate ' + $gaps.Count + ' su ' + @($r.heights).Count) }
            foreach ($g in $gaps) {
                if ($g.catLines -gt $g.catText) { $browserFail.Add($tag + ' riga della categoria con spazio vuoto: ' + $g.catLines + ' righe per ' + $g.catText) }
                if ($g.catTitle -lt 2 -or $g.catTitle -gt 12) { $browserFail.Add($tag + ' spazio fra categoria e titolo: ' + $g.catTitle + ' px') }
                if ($g.titlePrice -lt 2 -or $g.titlePrice -gt 14) { $browserFail.Add($tag + ' spazio fra titolo e prezzo: ' + $g.titlePrice + ' px') }
                if ($g.priceExtra -gt 6) { $browserFail.Add($tag + ' vuoto attorno al prezzo: ' + $g.priceExtra + ' px') }
                if ($g.priceAvail -lt 2 -or $g.priceAvail -gt 16) { $browserFail.Add($tag + ' spazio fra prezzo e disponibilita: ' + $g.priceAvail + ' px') }
                if ($g.availSave -gt 14) { $browserFail.Add($tag + ' spazio fra disponibilita e risparmio: ' + $g.availSave + ' px') }
            }
            $hs = @($r.heights | Where-Object { $_ -gt 0 })
            if ($hs.Count -ge 2 -and (($hs | Measure-Object -Maximum).Maximum - ($hs | Measure-Object -Minimum).Minimum) -gt 1) { $browserFail.Add($tag + ' schede di altezza diversa: ' + ($hs -join ',')) }
            Write-Host ('  ' + $tag + ': barre ' + $bars.Count + ', altezze ' + (($hs | Select-Object -Unique) -join ',') + ', scorrimento ' + $r.scroll)
        } catch { $browserFail.Add('E' + $vp.W + ' ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($browserFail.Count -gt 0) { foreach ($x in ($browserFail | Select-Object -Unique)) { Write-Host ('  FAIL ' + $x) }; Write-Host 'HOME_DEAL_PROGRESS FAIL (browser)'; exit 1 }
    Write-Host 'HOME_DEAL_PROGRESS browser OK'
}

Write-Host 'HOME_DEAL_PROGRESS OK'
exit 0
