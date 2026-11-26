param([switch]$OnlySite, [switch]$SkipMutants, [string]$MutantFilter = '', [switch]$SkipSite, [switch]$Cleanup, [string]$DocPath = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# FEED-EXAMPLES-1A. Prova dei tre feed di esempio come dati (docs\EXPORT_FEED_ESEMPI.md: blocchi esempi, verify, rollback) sul database LAB.
#  (A) controlli sul testo dei blocchi (nessun DEFINER, nessun USE, nessun nome di cliente o database, solo ASCII);
#  (B) batteria comportamentale sul LAB con aziende sintetiche (id 9101-9107): struttura mancante = arresto senza scrivere, creazione dei feed attesi (campi di export, opzioni e colonne
#      uguali a una definizione INDIPENDENTE scritta qui sotto), IvaTipo sempre 2, aziende saltate (id doppio, URL1 doppio fra URL1/URL2, listino 0, URL1 vuoto), ripetibilita, omonimo mai adottato,
#      atomicita (errore a meta e controllo prima del COMMIT), rollback che toglie SOLO gli esempi intatti, verify;
#  (C) mutazioni dei blocchi: ognuna deve far fallire la batteria;
#  (D) prova HTTP sul sito LAB (porta 18843, 127.0.0.1 forzato): il motore genera i tre file dagli esempi abilitati e il file letto con un parser ha intestazione esatta,
#      lo stesso numero di campi in ogni riga, l'insieme esatto degli id attesi e i valori per colonna; un esempio disabilitato risponde 404.
# Scrive sul LAB: aziende 9101-9107, feed con descrizione 'ESEMPIO ...' (e il feed omonimo di prova): tutto ripristinato alla fine (-Cleanup se la prova viene interrotta).
# Un solo uso del sito LAB alla volta: mutex Global\KeepStoreLabSite18843. Mai password in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $utf8 } catch { }
$inv = [Globalization.CultureInfo]::InvariantCulture
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
if (-not $DocPath) { $DocPath = Join-Path $root 'docs\EXPORT_FEED_ESEMPI.md' }
$prefix = '20261126_EXPORT_FEED_ESEMPI_'
$fails = New-Object Collections.Generic.List[string]
$script:quiet = $false
function Check([bool]$ok, [string]$name) {
    if ($ok) { if (-not $script:quiet) { Write-Host ('  ok   ' + $name) } } else { if (-not $script:quiet) { Write-Host ('  FAIL ' + $name) }; $script:cur.Add($name) }
}
$script:cur = New-Object Collections.Generic.List[string]
$tmp = Join-Path $env:TEMP ('ks-exportexamples-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write -MaxChars 400000 2>&1 }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -MaxChars 400000 2>&1 }
        return @($o | ForEach-Object { [string]$_ })
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Sql-Failed([string[]]$out) { return (($out -join "`n") -match '(?m)^stderr:|ERROR \d+') }
function Get-Rows([string]$sql, [switch]$Write) {
    $raw = if ($Write) { Invoke-Sql $sql -Write } else { Invoke-Sql $sql }
    $o = @(@($raw) | Where-Object { $_ -notmatch '^mode=' -and $_ -notmatch '^stderr' -and $_.Trim() -ne '' })
    if ($o.Count -lt 1) { return @() }
    $h = $o[0].Split("`t"); $res = New-Object Collections.Generic.List[object]
    for ($i = 1; $i -lt $o.Count; $i++) { $c = $o[$i].Split("`t"); $r = @{}; for ($k = 0; $k -lt $h.Count; $k++) { $r[$h[$k]] = if ($k -lt $c.Count) { $c[$k] } else { '' } }; $res.Add($r) }
    return $res.ToArray()
}
function Dec([string]$s) { if ($s -eq '' -or $s -eq 'NULL') { return [decimal]0 }; return [decimal]::Parse($s, [Globalization.NumberStyles]::Float, $inv) }
function Money([decimal]$d) { return ([Math]::Round($d, 2, [MidpointRounding]::AwayFromZero)).ToString('0.00', $inv) }
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql ($sql))
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ($o[$i].Trim() -eq 'ksval') { return $o[$i + 1].Trim() } }
    return ''
}

# ---------------------------------------------------------------------------------------------------------------------
# definizione INDIPENDENTE attesa (non letta dal generatore): tipo, opzioni e colonne (titolo|campo|prefisso|suffisso|valore fisso|massimo)
# ---------------------------------------------------------------------------------------------------------------------
$model = '#Descrizione1#. #DescrizioneLunga#'
$exp = @{
    'ESEMPIO Google Merchant' = @{ Tipo = 'tsv'; Opt = 'sep=|;delim=;enc=utf-8;dec=.;head=1;html=1;cache=60;w1=in_stock;w2=out_of_stock;w3=out_of_stock;img=1;ean=0;zero=1'; Cols = @(
        'id|Id|||', 'title|Descrizione1||||150', ('description||||' + $model + '|5000'), 'link|Link|||', 'image_link|UrlImgBig|||', 'availability|Disponibilita|||', ('price|Prezzo||' + ' EUR' + '||'),
        'brand|Marca||||70', 'gtin|Ean|||', 'product_type|CategoriaPercorso||||750', 'shipping|CostoSpedizioneProdo|IT::Standard:| EUR||') }
    'ESEMPIO Trovaprezzi 7Pixel' = @{ Tipo = 'txt'; Opt = 'sep=|;delim=;enc=utf-8;dec=.;head=1;html=1;cache=60;w1=Disponibile;w2=In arrivo;w3=Non disponibile;img=1;ean=0;zero=1'; Cols = @(
        'Nome|Descrizione1|||', 'Marca|Marca|||', ('Descrizione||||' + $model + '|'), 'Prezzo|Prezzo|||', 'Codice interno|Id|||', 'Link|Link|||', 'Disponibilita|Disponibilita|||', 'Categoria|CategoriaPercorso|||',
        'Immagine|UrlImgBig|||', 'Codice produttore|Codice|||', 'EAN|Ean|||', 'Spese di spedizione|CostoSpedizioneProdo|||', 'Peso|Peso|||') }
    'ESEMPIO idealo' = @{ Tipo = 'csv'; Opt = 'sep=,;delim=";enc=utf-8;dec=.;head=1;html=1;cache=60;w1=Disponibile;w2=In arrivo;w3=Non disponibile;img=1;ean=0;zero=1'; Cols = @(
        'sku|Id|||', 'brand|Marca|||', 'title|Descrizione1|||', 'categoryPath|CategoriaPercorso|||', 'url|Link|||', 'eans|Ean|||', 'hans|Codice|||', ('description||||' + $model + '|'), 'price|Prezzo|||',
        'deliveryCosts_dhl|CostoSpedizioneProdo|||', ('delivery|GiorniSpedizione||' + ' giorni lavorativi' + '||'), 'imageUrl|UrlImgBig|||') }
}
# Le righe delle colonne sono: titolo|campo|prefisso|suffisso|valorefisso|max  (i campi vuoti restano vuoti)
function Col-Line([string]$c) { $p = $c.Split('|'); while ($p.Count -lt 6) { $p += '' }; return $p }

# ---------------------------------------------------------------------------------------------------------------------
# testo dei blocchi
# ---------------------------------------------------------------------------------------------------------------------
Write-Host '(A) testo dei blocchi'
$docText = ''
if (Test-Path -LiteralPath $DocPath) { $docText = [IO.File]::ReadAllText($DocPath, $utf8) }
$blocks = @{}
foreach ($k in @('esempi', 'verify', 'rollback')) {
    $mm = [regex]::Match($docText, '(?s)## ' + [regex]::Escape($prefix + $k) + '\.sql\r?\n\r?\n```sql\r?\n(.*?)\r?\n```')
    if ($mm.Success) { $blocks[$k] = ($mm.Groups[1].Value -replace '\r\n', "`n") }
    Check $mm.Success ('A1 blocco ' + $k + ' presente nel documento')
}
if ($blocks.Count -ne 3) { Write-Host ('EXPORT_FEED_EXAMPLES FAIL: ' + (($script:cur.ToArray()) -join '; ')); Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
foreach ($k in $blocks.Keys) {
    $b = $blocks[$k]
    Check ($b -notmatch '(?i)DEFINER\s*=') ('A2 ' + $k + ': nessun DEFINER')
    Check ($b -notmatch '(?im)^\s*USE\s') ('A3 ' + $k + ': nessuna istruzione USE')
    Check ($b -notmatch '(?i)taikun|webaffare|entropic|ks_taikun|localhost|\.it\b') ('A4 ' + $k + ': nessun nome di cliente, dominio o database')
    Check ($b -cmatch '^[\x09\x0A\x20-\x7E]*$') ('A5 ' + $k + ': solo caratteri ASCII')
    Check ($b -notmatch '(?i)(^|[^A-Za-z_])(password|pwd)\s*=') ('A6 ' + $k + ': nessuna password nel testo')
}
Check ($blocks['rollback'] -match 'KeepStoreConfirmDeleteExamples') 'A7 il rollback richiede la conferma esplicita'
foreach ($x in $script:cur) { $fails.Add($x) }
$script:cur = New-Object Collections.Generic.List[string]

# ---------------------------------------------------------------------------------------------------------------------
# LAB: identita, fixture, utilita
# ---------------------------------------------------------------------------------------------------------------------
Write-Host '(B) LAB'
$uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { Write-Host 'EXPORT_FEED_EXAMPLES FAIL: NOT_THE_LAB'; exit 1 }
$siteMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLabSite18843'); $siteHeld = $false
$cleanExamplesSql = @'
DROP TRIGGER IF EXISTS ks_ex_test_trg_abil;
DROP TRIGGER IF EXISTS ks_ex_test_trg_err;
DELETE FROM export_filtri WHERE ExportId IN (SELECT ID FROM `export` WHERE Descrizione LIKE 'ESEMPIO %(azienda %)');
DELETE FROM `export` WHERE Descrizione LIKE 'ESEMPIO %(azienda %)';
'@
function Clean-Examples { $o = Invoke-Sql $cleanExamplesSql -Write; if (Sql-Failed $o) { throw ('CLEAN_FAILED ' + ($o -join ' ')) } }
function Clean-Lab { Clean-Examples; $o = Invoke-Sql 'DELETE FROM aziende WHERE id BETWEEN 9101 AND 9107;' -Write; if (Sql-Failed $o) { throw ('CLEAN_FAILED ' + ($o -join ' ')) } }
$fixtureSql = @'
CREATE TEMPORARY TABLE ks_fx AS SELECT * FROM aziende WHERE id = 2 LIMIT 1;
UPDATE ks_fx SET id = 9101, IvaTipo = 2, URL1 = 'ks-esempi-a.example.test', URL2 = NULL, ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9102, IvaTipo = 2, URL1 = 'ks-esempi-b.example.test', URL2 = ' KS-ESEMPI-A.EXAMPLE.TEST', ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9103, IvaTipo = 2, URL1 = 'ks-esempi-c.example.test', URL2 = NULL, ListinoDefault = 0;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9104, IvaTipo = 1, URL1 = 'ks-esempi-d1.example.test', URL2 = NULL, ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9104, IvaTipo = 2, URL1 = 'ks-esempi-d2.example.test', URL2 = NULL, ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9106, IvaTipo = 1, URL1 = 'ks-esempi-f.example.test', URL2 = NULL, ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
UPDATE ks_fx SET id = 9107, IvaTipo = 2, URL1 = '', URL2 = NULL, ListinoDefault = 10;
INSERT INTO aziende SELECT * FROM ks_fx;
DROP TEMPORARY TABLE ks_fx;
'@

function Eligible-Companies {
    $rows = @(Get-Rows 'SELECT id, IvaTipo, URL1, IFNULL(URL2, '''') AS URL2, ListinoDefault FROM aziende ORDER BY id, IvaTipo;')
    $res = New-Object Collections.Generic.List[object]
    foreach ($a in $rows) {
        $u1 = $a['URL1'].Trim()
        if ($u1 -eq '' -or $u1.Length -gt 100) { continue }
        if ([int]$a['ListinoDefault'] -le 0) { continue }
        if (@($rows | Where-Object { $_['id'] -eq $a['id'] }).Count -ne 1) { continue }
        $n = @($rows | Where-Object { $_['URL1'].Trim().ToLowerInvariant() -eq $u1.ToLowerInvariant() -or $_['URL2'].Trim().ToLowerInvariant() -eq $u1.ToLowerInvariant() }).Count
        if ($n -ne 1) { continue }
        $res.Add(@{ Id = [int]$a['id']; Dominio = $u1; Listino = [int]$a['ListinoDefault'] })
    }
    return $res.ToArray()
}
function Example-Rows {
    return @(Get-Rows 'SELECT e.ID, e.Descrizione, e.Password, e.FormatString, e.NListino, e.NListino2, e.IvaTipo, e.Giacenza, e.SpeseSpedizione, e.GiorniSpedizione, e.Azienda, e.Tipo, e.IdVettore, e.Tutto_in_minuscolo, e.Google, e.Amazon, e.NoVettoreSuGratis, e.Abilitato, o.TokenAccesso, o.Separatore, o.DelimitatoreTesto, o.Codifica, o.SeparatoreDecimale, o.Intestazione, o.XmlRadice, o.XmlElemento, o.TogliHtml, o.MinutiCache, o.ParolaDisponibile, o.ParolaInArrivo, o.ParolaNonDisponibile, o.SenzaImmagine, o.SenzaEan, o.PrezzoZero, (SELECT COUNT(*) FROM export_colonne k WHERE k.ExportId = e.ID) AS NCol FROM `export` e LEFT JOIN export_opzioni o ON o.ExportId = e.ID WHERE e.Descrizione LIKE ''ESEMPIO %(azienda %)'' ORDER BY e.ID;')
}
function Others-Crc {
    # impronta di tutti i feed che NON sono esempi ne omonimi di prova (devono restare identici)
    return (Get-Scalar "SELECT CONCAT(COUNT(*), '-', BIT_XOR(CRC32(CONCAT_WS('|', e.ID, e.Descrizione, e.FormatString, e.NListino, e.IvaTipo, e.Giacenza, e.Azienda, e.Tipo, e.IdVettore, e.Abilitato)))) AS ksval FROM export e WHERE NOT (e.Descrizione LIKE 'ESEMPIO %(azienda %)');")
}

function Def-Matches($rowsEx, $companies) {
    # ogni esempio atteso: una riga per (azienda idonea, tipo); campi, opzioni e colonne uguali alla definizione indipendente
    $ok = $true; $why = @()
    foreach ($c in $companies) {
        foreach ($d in $exp.Keys) {
            $name = $d + ' (azienda ' + $c.Id + ')'
            $r = @($rowsEx | Where-Object { $_['Descrizione'] -eq $name })
            if ($r.Count -ne 1) { $ok = $false; $why += ('manca ' + $name); continue }
            $r = $r[0]; $e = $exp[$d]
            $o = 'sep=' + $r['Separatore'] + ';delim=' + $r['DelimitatoreTesto'] + ';enc=' + $r['Codifica'] + ';dec=' + $r['SeparatoreDecimale'] + ';head=' + $r['Intestazione'] + ';html=' + $r['TogliHtml'] + ';cache=' + $r['MinutiCache'] + ';w1=' + $r['ParolaDisponibile'] + ';w2=' + $r['ParolaInArrivo'] + ';w3=' + $r['ParolaNonDisponibile'] + ';img=' + $r['SenzaImmagine'] + ';ean=' + $r['SenzaEan'] + ';zero=' + $r['PrezzoZero']
            $eo = $e.Opt
            if ($o -ne $eo) { $ok = $false; $why += ($name + ' opzioni ' + $o + ' <> ' + $eo) }
            if ($r['Tipo'] -ne $e.Tipo) { $ok = $false; $why += ($name + ' tipo') }
            if ($r['Abilitato'] -ne '0') { $ok = $false; $why += ($name + ' abilitato') }
            if ($r['IvaTipo'] -ne '2') { $ok = $false; $why += ($name + ' IvaTipo ' + $r['IvaTipo']) }
            if ([decimal]::Parse($r['Giacenza'], $inv) -ne 1) { $ok = $false; $why += ($name + ' giacenza') }
            if ($r['NListino'] -ne [string]$c.Listino) { $ok = $false; $why += ($name + ' listino') }
            if ($r['Azienda'] -ne $c.Dominio) { $ok = $false; $why += ($name + ' dominio') }
            if ($r['NListino2'] -ne '0' -or $r['GiorniSpedizione'] -ne '0' -or [decimal]::Parse($r['SpeseSpedizione'], $inv) -ne 0) { $ok = $false; $why += ($name + ' campi da completare non a zero') }
            if ($r['TokenAccesso'] -notmatch '^[0-9A-F]{48}$') { $ok = $false; $why += ($name + ' codice') }
            if ($r['NCol'] -ne [string]$e.Cols.Count) { $ok = $false; $why += ($name + ' numero colonne ' + $r['NCol']) }
        }
    }
    $tokens = @($rowsEx | ForEach-Object { $_['TokenAccesso'] }); if (@($tokens | Select-Object -Unique).Count -ne $tokens.Count) { $ok = $false; $why += 'codici non distinti' }
    return @{ Ok = $ok; Why = ($why -join ' | ') }
}
function Cols-Match([int]$exportId, [string]$desc) {
    $key = ($exp.Keys | Where-Object { $desc.StartsWith($_) } | Select-Object -First 1)
    $rows = @(Get-Rows ('SELECT Posizione, TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, IFNULL(MassimoCaratteri, '''') AS Max FROM export_colonne WHERE ExportId = ' + $exportId + ' ORDER BY Posizione;'))
    $e = $exp[$key].Cols
    if ($rows.Count -ne $e.Count) { return ('colonne ' + $rows.Count + ' <> ' + $e.Count) }
    for ($i = 0; $i -lt $e.Count; $i++) {
        $p = Col-Line $e[$i]
        $r = $rows[$i]
        $line = $r['TitoloColonna'] + '|' + $r['Campo'] + '|' + $r['Prefisso'] + '|' + $r['Suffisso'] + '|' + $r['ValoreFisso'] + '|' + $r['Max']
        $want = ($p[0] + '|' + $p[1] + '|' + $p[2] + '|' + $p[3] + '|' + $p[4] + '|' + $p[5])
        if ([int]$r['Posizione'] -ne ($i + 1) -or $line -ne $want) { return ('colonna ' + ($i + 1) + ': ' + $line + ' <> ' + $want) }
    }
    return ''
}

# ---------------------------------------------------------------------------------------------------------------------
# batteria comportamentale
# ---------------------------------------------------------------------------------------------------------------------
function Run-Battery([hashtable]$b, [bool]$full) {
    $script:cur = New-Object Collections.Generic.List[string]
    Clean-Examples
    $companies = @(Eligible-Companies)
    $nExpected = $companies.Count * 3
    $crc0 = Others-Crc

    # B1 struttura mancante: nessuna scrittura
    $null = Invoke-Sql 'RENAME TABLE export_stato TO ks_tmp_export_stato;' -Write
    try {
        $o = Invoke-Sql $b['esempi'] -Write
        Check (Sql-Failed $o) 'B1 struttura mancante: lo script si ferma con un errore'
        Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM export WHERE Descrizione LIKE 'ESEMPIO %(azienda %)';") -eq '0') 'B1 struttura mancante: nessun feed scritto'
    } finally { $null = Invoke-Sql 'RENAME TABLE ks_tmp_export_stato TO export_stato;' -Write }
    Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export_stato';") -eq '1') 'B1 la tabella export_stato e tornata al suo posto'

    # B2 creazione
    $o = Invoke-Sql $b['esempi'] -Write
    $txt = $o -join "`n"
    Check ($txt -match 'EXPORT_FEED_ESEMPI_OK\s+' + $nExpected + '\s+0\s+' + $companies.Count + '\s') ('B2 esito atteso: ' + $nExpected + ' creati, 0 presenti, ' + $companies.Count + ' aziende idonee')
    $rowsEx = @(Example-Rows)
    Check ($rowsEx.Count -eq $nExpected) ('B2 feed di esempio presenti: ' + $rowsEx.Count + ' di ' + $nExpected)
    $dm = Def-Matches $rowsEx $companies
    Check $dm.Ok ('B2 campi, opzioni, codici e azienda come la definizione ' + $dm.Why)
    $colErr = ''
    foreach ($r in $rowsEx) { $ce = Cols-Match ([int]$r['ID']) $r['Descrizione']; if ($ce -ne '') { $colErr = ($r['Descrizione'] + ': ' + $ce); break } }
    Check ($colErr -eq '') ('B2 colonne uguali alla definizione, in ordine ' + $colErr)
    $fs = @(Get-Rows "SELECT e.ID, e.FormatString FROM export e WHERE e.Descrizione LIKE 'ESEMPIO %(azienda %)' ORDER BY e.ID;")
    Check (@($fs | Where-Object { $_['FormatString'] -eq '' }).Count -eq 0) 'B2 FormatString mai vuota (il gestionale vecchio la vuole)'
    Check ((Others-Crc) -eq $crc0) 'B2 i feed esistenti sono identici a prima'
    $skipIds = @(9101, 9103, 9104, 9107)
    Check (@($rowsEx | Where-Object { $skipIds -contains [int]($_['Descrizione'] -replace '^.*\(azienda (\d+)\)$', '$1') }).Count -eq 0) 'B2 aziende con id doppio, URL1 doppio fra URL1/URL2, listino 0 o URL1 vuoto saltate'
    $iv1 = @($rowsEx | Where-Object { $_['Descrizione'] -match '\(azienda 9106\)$' })
    Check ($iv1.Count -eq 3 -and @($iv1 | Where-Object { $_['IvaTipo'] -ne '2' }).Count -eq 0) 'B2 azienda con IvaTipo 1: gli esempi sono comunque con IVA (IvaTipo 2)'
    $tok0 = (@($rowsEx | ForEach-Object { $_['TokenAccesso'] }) -join ',')

    # B3 ripetibilita
    $o = Invoke-Sql $b['esempi'] -Write
    Check (($o -join "`n") -match ('EXPORT_FEED_ESEMPI_OK\s+0\s+' + $nExpected + '\s')) 'B3 secondo lancio: 0 creati, tutti presenti'
    $rowsEx2 = @(Example-Rows)
    Check ($rowsEx2.Count -eq $nExpected -and ((@($rowsEx2 | ForEach-Object { $_['TokenAccesso'] }) -join ',') -eq $tok0)) 'B3 nessun doppione e codici invariati'

    # B4 rollback senza conferma: arresto
    $o = Invoke-Sql $b['rollback'] -Write
    Check (Sql-Failed $o) 'B4 rollback senza conferma: arresto'
    Check (@(Example-Rows).Count -eq $nExpected) 'B4 rollback senza conferma: niente cancellato'

    if ($full) {
        # B5 atomicita: errore a meta (trigger che fa fallire la terza colonna del primo feed) e controllo prima del COMMIT (trigger che abilita il feed)
        $null = Invoke-Sql ('DELETE FROM export WHERE Descrizione LIKE ''ESEMPIO %(azienda %)'';') -Write
        $trgErr = "CREATE TRIGGER ks_ex_test_trg_err BEFORE INSERT ON export_colonne FOR EACH ROW SET NEW.Posizione = IF(NEW.Posizione = 3, (SELECT 1 UNION SELECT 2), NEW.Posizione);"
        $o = Invoke-Sql $trgErr -Write
        try {
            $o = Invoke-Sql $b['esempi'] -Write
            Check (Sql-Failed $o) 'B5 errore a meta: lo script si ferma'
            Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM export WHERE Descrizione LIKE 'ESEMPIO %(azienda %)';") -eq '0') 'B5 errore a meta: niente scritto (transazione annullata)'
        } finally { $null = Invoke-Sql 'DROP TRIGGER IF EXISTS ks_ex_test_trg_err;' -Write }
        $trgAb = "CREATE TRIGGER ks_ex_test_trg_abil AFTER INSERT ON export_colonne FOR EACH ROW UPDATE export SET Abilitato = 1 WHERE ID = NEW.ExportId;"
        $o = Invoke-Sql $trgAb -Write
        try {
            $o = Invoke-Sql $b['esempi'] -Write
            Check (Sql-Failed $o) 'B5 controllo prima del COMMIT: un feed nuovo abilitato ferma lo script'
            Check ((Get-Scalar "SELECT COUNT(*) AS ksval FROM export WHERE Descrizione LIKE 'ESEMPIO %(azienda %)';") -eq '0') 'B5 controllo prima del COMMIT: niente scritto'
        } finally { $null = Invoke-Sql 'DROP TRIGGER IF EXISTS ks_ex_test_trg_abil;' -Write }

        # B6 omonimo di un cliente: mai adottato ne cancellato
        $hom = 'ESEMPIO idealo (azienda ' + $companies[0].Id + ')'
        $null = Invoke-Sql ("INSERT INTO export (Descrizione, Password, FormatString, NListino, IvaTipo, Giacenza, Azienda, Tipo, IdVettore, Abilitato) VALUES ('" + $hom + "', 'x', '#Id#', " + $companies[0].Listino + ", 1, -1, '" + $companies[0].Dominio + "', 'csv', 0, 1);") -Write
        $homId = Get-Scalar ("SELECT ID AS ksval FROM export WHERE Descrizione = '" + $hom + "';")
        $homCrc = Get-Scalar ("SELECT CRC32(CONCAT_WS('|', ID, Descrizione, Password, FormatString, NListino, IvaTipo, Giacenza, Azienda, Tipo, IdVettore, Abilitato)) AS ksval FROM export WHERE ID = " + $homId + ";")
        $o = Invoke-Sql $b['esempi'] -Write
        Check (($o -join "`n") -match ('EXPORT_FEED_ESEMPI_OK\s+' + ($nExpected - 1) + '\s+1\s')) 'B6 omonimo: saltato, gli altri creati'
        Check ((Get-Scalar ("SELECT CRC32(CONCAT_WS('|', ID, Descrizione, Password, FormatString, NListino, IvaTipo, Giacenza, Azienda, Tipo, IdVettore, Abilitato)) AS ksval FROM export WHERE ID = " + $homId + ";")) -eq $homCrc) 'B6 omonimo: invariato'
        Check ((Get-Scalar ("SELECT COUNT(*) AS ksval FROM export_opzioni WHERE ExportId = " + $homId + ";")) -eq '0') 'B6 omonimo: nessuna opzione o colonna aggiunta'
        $o = Invoke-Sql ('SET @KeepStoreConfirmDeleteExamples = 1;' + "`n" + $b['rollback']) -Write
        Check ((Get-Scalar ("SELECT COUNT(*) AS ksval FROM export WHERE ID = " + $homId + ";")) -eq '1') 'B6 rollback: l omonimo del cliente resta'
        Check (@(Example-Rows).Count -eq 1) 'B6 rollback: cancellati gli altri esempi intatti'
        $null = Invoke-Sql ('DELETE FROM export WHERE ID = ' + $homId + ';') -Write
        Check ((Others-Crc) -eq $crc0) 'B6 i feed esistenti sono identici a prima'

        # B7 rollback selettivo
        $o = Invoke-Sql $b['esempi'] -Write
        $rowsEx = @(Example-Rows)
        function Id-Of([string]$d, [int]$az) { return [int](@($rowsEx | Where-Object { $_['Descrizione'] -eq ($d + ' (azienda ' + $az + ')') })[0]['ID']) }
        $c1 = $companies[0].Id; $c2 = $companies[1].Id
        $idMod = Id-Of 'ESEMPIO Google Merchant' $c1
        $idAbil = Id-Of 'ESEMPIO Trovaprezzi 7Pixel' $c1
        $idStato = Id-Of 'ESEMPIO idealo' $c1
        $idFiltri = Id-Of 'ESEMPIO Google Merchant' $c2
        $idCol = Id-Of 'ESEMPIO Trovaprezzi 7Pixel' $c2
        $null = Invoke-Sql ("UPDATE export SET GiorniSpedizione = 2 WHERE ID = " + $idMod + "; UPDATE export SET Abilitato = 1 WHERE ID = " + $idAbil + "; INSERT INTO export_stato (ExportId, UltimaRichiestaUtc) VALUES (" + $idStato + ", UTC_TIMESTAMP()); INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (" + $idFiltri + ", -1, -1, -1, -1, -1, -1, -1); UPDATE export_colonne SET TitoloColonna = 'Nome2' WHERE ExportId = " + $idCol + " AND Posizione = 1;") -Write
        $keep = @($idMod, $idAbil, $idStato, $idFiltri, $idCol)
        $o = Invoke-Sql ('SET @KeepStoreConfirmDeleteExamples = 1;' + "`n" + $b['rollback']) -Write
        Check (-not (Sql-Failed $o) -and ($o -join "`n") -match 'EXPORT_FEED_ESEMPI_ROLLBACK_OK') 'B7 rollback con conferma: esito OK'
        $left = @(Example-Rows | ForEach-Object { [int]$_['ID'] } | Sort-Object)
        Check ((($left -join ',') -eq (($keep | Sort-Object) -join ','))) ('B7 rollback: restano SOLO i cinque esempi modificati, abilitato, letto, con filtri e con colonna cambiata (restano ' + ($left -join ',') + ')')
        $null = Invoke-Sql ('DELETE FROM export_filtri WHERE ExportId = ' + $idFiltri + '; DELETE FROM export_stato WHERE ExportId = ' + $idStato + '; DELETE FROM export WHERE ID IN (' + ($keep -join ',') + ');') -Write
        Check (@(Example-Rows).Count -eq 0) 'B7 pulizia: nessun esempio rimasto'
        Check ((Others-Crc) -eq $crc0) 'B7 i feed esistenti sono identici a prima'
    }
    return ,($script:cur.ToArray())
}

if ($Cleanup) { Clean-Lab; Write-Host 'EXPORT_FEED_EXAMPLES CLEANUP DONE'; Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 0 }

try {
    Clean-Lab
    $o = Invoke-Sql $fixtureSql -Write
    if (Sql-Failed $o) { throw ('FIXTURE_FAILED ' + ($o -join ' ')) }
    $crcStart = Others-Crc
    $scale = @(Get-Rows 'SELECT COUNT(*) AS N FROM aziende WHERE id BETWEEN 9101 AND 9107;')
    Write-Host ('  fixture aziende: ' + $scale[0]['N'])

    if (-not $OnlySite) {
    $r = Run-Battery $blocks $true
    foreach ($x in $r) { $fails.Add($x) }

    # (V) verify sullo stato reale
    $o = Invoke-Sql $blocks['esempi'] -Write
    $script:cur = New-Object Collections.Generic.List[string]
    $v = Invoke-Sql $blocks['verify'] -Write
    $vt = $v -join "`n"
    Check ($vt -match 'EXPORT_FEED_ESEMPI_VERIFY_OK') 'V1 verify: verdetto OK dopo la creazione'
    Check (-not ($vt -match 'ATTENZIONE')) 'V1 verify: nessuna attenzione sugli esempi appena creati'
    $gid = [int](Get-Scalar "SELECT MIN(ID) AS ksval FROM export WHERE Descrizione LIKE 'ESEMPIO Google Merchant (azienda %)';")
    $iid = [int](Get-Scalar "SELECT MIN(ID) AS ksval FROM export WHERE Descrizione LIKE 'ESEMPIO idealo (azienda %)';")
    $null = Invoke-Sql ('UPDATE export SET Abilitato = 1, IdVettore = 0 WHERE ID IN (' + $gid + ',' + $iid + ');') -Write
    $v = Invoke-Sql $blocks['verify'] -Write
    $vt = $v -join "`n"
    Check ($vt -match 'google_abilitato\s+ATTENZIONE') 'V2 verify segnala l esempio Google abilitato'
    Check ($vt -match 'abilitati_senza_vettore_con_fasce\s+ATTENZIONE') 'V2 verify segnala un esempio abilitato senza vettore con fasce'
    Check ($vt -match 'abilitati_con_giorni_zero\s+ATTENZIONE') 'V2 verify segnala idealo abilitato con 0 giorni'
    Check ($vt -match 'esempi_non_modificati\s+INFO') 'V2 verify segnala gli esempi modificati (abilitati)'
    $null = Invoke-Sql ('UPDATE export SET Abilitato = 0 WHERE ID IN (' + $gid + ',' + $iid + ');') -Write
    foreach ($x in $script:cur) { $fails.Add($x) }
    }

    # (C) mutazioni
    if (-not $SkipMutants -and -not $OnlySite) {
        Write-Host '(C) mutazioni dei blocchi'
        $mut = @(
            @('guardia-di-struttura-tolta', 'esempi', 'SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_STRUTTURA', 'SELECT 1'),
            @('ripetibilita-tolta', 'esempi', 'WHERE @ks_go = 1 AND x.Presente = 0 ORDER BY x.AziendaId', 'WHERE @ks_go = 1 ORDER BY x.AziendaId'),
            @('omonimo-adottato-nelle-opzioni', 'esempi', 'FROM `export` e JOIN ks_ex_atteso x ON x.Descrizione = e.Descrizione WHERE @ks_go = 1 AND x.Presente = 0 AND e.ID > @ks_max', 'FROM `export` e JOIN ks_ex_atteso x ON x.Descrizione = e.Descrizione WHERE @ks_go = 1 AND e.ID > 0'),
            @('iva-copiata-dall-azienda', 'esempi', "x.Listino, 0, 2, 1, 0, 0, x.Dominio", "x.Listino, 0, (SELECT a.IvaTipo FROM aziende a WHERE a.id = x.AziendaId), 1, 0, 0, x.Dominio"),
            @('esempio-abilitato', 'esempi', 'x.IdVettore, 0, 0, 0, 0, 0 FROM ks_ex_atteso x', 'x.IdVettore, 0, 0, 0, 0, 1 FROM ks_ex_atteso x'),
            @('giacenza-zero', 'esempi', "x.Listino, 0, 2, 1, 0, 0, x.Dominio", "x.Listino, 0, 2, 0, 0, 0, x.Dominio"),
            @('controllo-prima-del-commit-tolto', 'esempi', "SELECT * FROM information_schema.KEEPSTORE_STOP_EXPORT_FEED_ESEMPI_CONTROLLO", "SELECT 1"),
            @('transazione-tolta', 'esempi', "START TRANSACTION;`nSET @ks_max", "SET @ks_max"),
            @('suffisso-azienda-tolto', 'esempi', "CONCAT(t.Descrizione, ' (azienda ', a.AziendaId, ')'), t.Tipo", "t.Descrizione, t.Tipo"),
            @('azienda-con-id-doppio-accettata', 'esempi', "AND (SELECT COUNT(*) FROM aziende b WHERE b.id = a.id) = 1", ''),
            @('azienda-con-url-doppio-accettata', 'esempi', "AND (SELECT COUNT(*) FROM aziende b WHERE LOWER(TRIM(b.URL1)) = LOWER(TRIM(a.URL1)) OR LOWER(TRIM(b.URL2)) = LOWER(TRIM(a.URL1))) = 1;", ';'),
            @('azienda-senza-listino-accettata', 'esempi', "AND COALESCE(a.ListinoDefault, 0) > 0", ''),
            @('colonne-riordinate', 'esempi', "('G', 1, 'id', 'Id'", "('G', 12, 'id', 'Id'"),
            @('descrizione-senza-titolo', 'esempi', "'#Descrizione1#. #DescrizioneLunga#'", "'#DescrizioneLunga#'"),
            @('rollback-senza-impronta', 'rollback', 't.Identico = 1 AND ', ''),
            @('rollback-ignora-uso-del-sito', 'rollback', ' AND t.ConStato = 0', ''),
            @('rollback-ignora-filtri', 'rollback', ' AND t.ConFiltri = 0', ''),
            @('rollback-senza-conferma', 'rollback', 'SET @ks_ok = IF(@KeepStoreConfirmDeleteExamples = 1, 1, 0);', 'SET @ks_ok = 1;')
        )
        if ($MutantFilter) { $mut = @($mut | Where-Object { $_[0] -like $MutantFilter }) }
        $killed = 0
        foreach ($m in $mut) {
            $bm = @{}; foreach ($k in $blocks.Keys) { $bm[$k] = $blocks[$k] }
            if (-not $bm[$m[1]].Contains($m[2])) { Write-Host ('  FAIL mutante non applicabile: ' + $m[0]); $fails.Add('mutante ' + $m[0] + ' non applicabile'); continue }
            $bm[$m[1]] = $bm[$m[1]].Replace($m[2], $m[3])
            $script:quiet = $true
            try { $res = @(Run-Battery $bm $true) } catch { $res = @($script:cur.ToArray()) + @('ECCEZIONE ' + $_.Exception.Message) } finally { $script:quiet = $false }
            if ($res.Count -gt 0) { $killed++; Write-Host ('  ucciso ' + $m[0] + ' (primo fallimento: ' + $res[0] + ')') } else { Write-Host ('  FAIL SOPRAVVISSUTO ' + $m[0]); $fails.Add('mutante sopravvissuto ' + $m[0]) }
            Clean-Examples
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $mut.Count)
    }

    # (D) sito LAB
    if (-not $SkipSite) {
        Write-Host '(D) sito LAB'
        . (Join-Path $root 'Tools\Test-ExportFeedExamples.Site.ps1')
    }
} finally {
    try { Clean-Lab } catch { Write-Host ('  pulizia non riuscita: ' + $_.Exception.Message) }
    $script:quiet = $false
    try { $crcEnd = Others-Crc; if ($crcEnd -ne $crcStart) { Write-Host ('  FAIL i feed esistenti non sono tornati identici (' + $crcStart + ' <> ' + $crcEnd + ')'); $fails.Add('feed esistenti alterati') } } catch { }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($fails.Count -gt 0) { Write-Host ('EXPORT_FEED_EXAMPLES FAIL: ' + (($fails.ToArray()) -join '; ')); exit 1 }
Write-Host 'EXPORT_FEED_EXAMPLES PASS'
exit 0
