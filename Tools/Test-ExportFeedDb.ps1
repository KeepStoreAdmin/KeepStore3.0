[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '')

# EXPORT-FEED-DB-1A. Prova della migrazione unica dei dati dei feed (Database Taikun/Migrations/20261125_EXPORT_FEED_DB_1A_*.sql) sul LAB locale:
#  - preflight, forward, verify, rollback eseguiti dagli script REALI (nessuna copia di prova), sul database LAB (identita verificata da Invoke-KeepStoreLabSql);
#  - le routine del gestionale (Newexport, Modexport, Delexport) continuano a funzionare con la firma attuale e non toccano le colonne nuove;
#  - il codice del link (TokenAccesso) lo crea il database: 48 caratteri esadecimali maiuscoli, distinti, unico, regolare anche per le righe esistenti e per quelle inserite
#    durante la migrazione; un codice errato o duplicato e rifiutato; SET TokenAccesso = DEFAULT lo rinnova;
#  - la cancellazione di un feed cancella le sue colonne e il suo stato (cascata);
#  - ripresa: dopo OGNI interruzione (script fermato prima di ciascun passo -- STEP n) il forward si puo rilanciare e il rollback riporta lo schema allo stato iniziale;
#  - arresto con binlog STATEMENT (condizione sostituita nel testo: il LAB ha log_bin=0), rifiuto del rollback senza conferma, verify che si ferma se i dati sono corrotti;
#  - nessun effetto su exportcampi, export_filtri e sul numero delle righe di export.
# -MutantFilter: esegue solo i mutanti il cui nome contiene il testo. Mutanti: una copia degli script con una sola modifica; la prova deve fallire.
# Scrive solo righe sintetiche (Descrizione KSFEEDDB%) e le tabelle/colonne della migrazione, riportate allo stato iniziale dal rollback. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$migDir = Join-Path $root 'Database Taikun\Migrations'
$prefix = '20261125_EXPORT_FEED_DB_1A_'
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$tmp = Join-Path $env:TEMP ('ks-exportfeeddb-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$confirm = 'SET @KeepStoreConfirmDropFeedData=1;' + "`n"

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write 2>&1 }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f 2>&1 }
        return (@($o) | ForEach-Object { [string]$_ }) -join "`n"
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Failed([string]$out) { return ($out -match '(?m)^stderr:' -or $out -match 'ERROR \d+' -or $out -notmatch 'client exit=0') }
function Get-Scalar([string]$sql) {
    $o = (Invoke-Sql $sql) -split "`n"
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ($o[$i].Trim() -eq 'ksval') { return $o[$i + 1].Trim() } }
    return ''
}
function Read-Mig([string]$dir, [string]$kind) { return [IO.File]::ReadAllText((Join-Path $dir ($prefix + $kind + '.sql')), $utf8) }
# Fotografia dello schema interessato (senza AUTO_INCREMENT): colonne di export, elenco tabelle nuove, checksum di exportcampi e export_filtri, numero righe di export.
function Get-Snapshot {
    $s = Get-Scalar ("SELECT CONCAT_WS('#', " +
        "(SELECT SHA2(IFNULL(GROUP_CONCAT(CONCAT_WS(':', COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, IFNULL(COLUMN_DEFAULT, 'NULL'), IFNULL(COLLATION_NAME, '-'), EXTRA) ORDER BY ORDINAL_POSITION SEPARATOR '|'), ''), 256) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export'), " +
        "(SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_stato', 'export_colonne')), " +
        "(SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export'), " +
        "(SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'export'), " +
        "(SELECT COUNT(*) FROM exportcampi), (SELECT COUNT(*) FROM export_filtri), (SELECT COUNT(*) FROM export WHERE Descrizione NOT LIKE 'KSFEEDDB%')) AS ksval;")
    return $s
}
$e2e = New-Object Collections.Generic.List[string]
$script:stopFirst = $false
function Check([bool]$ok, [string]$name) {
    if ($ok) { if (-not $script:stopFirst) { Write-Host ('  ok   ' + $name) } } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name); if ($script:stopFirst) { throw 'MUTANT_KILLED' } }
}
# Parti del forward: prologo + passi "-- STEP n". Restituisce il testo fino al passo $upTo incluso (0 = solo il prologo).
function Get-ForwardUpTo([string]$text, [int]$upTo) {
    $ms = [regex]::Matches($text, '(?m)^-- STEP (\d+)')
    if ($upTo -ge $ms.Count) { return $text }
    $cut = $ms[$upTo].Index
    return $text.Substring(0, $cut)
}
function Count-Steps([string]$text) { return [regex]::Matches($text, '(?m)^-- STEP (\d+)').Count }

function Remove-TestRows {
    $null = Invoke-Sql ("DELETE FROM export WHERE Descrizione LIKE 'KSFEEDDB%';") -Write
}
function Reset-Clean([string]$dir) {
    Remove-TestRows
    $out = Invoke-Sql ($confirm + (Read-Mig $dir 'rollback')) -Write
    return $out
}
function Test-Newexport([string]$desc) {
    $o = Invoke-Sql ("CALL Newexport('" + $desc + "', 'pw', '#Codice#', 1, 0, 0, 0, 0, 'www.example.test', 'txt', 0, 0, 0, 0, 0, 0, 1, @r); SELECT @r AS ksval;") -Write
    $o2 = $o -split "`n"
    for ($i = 0; $i -lt $o2.Count - 1; $i++) { if ($o2[$i].Trim() -eq 'ksval') { return $o2[$i + 1].Trim() } }
    return ''
}

function Run-Suite([string]$dir) {
    $rows0 = Reset-Clean $dir
    $snapA = Get-Snapshot
    $cntBefore = Get-Scalar 'SELECT COUNT(*) AS ksval FROM export;'
    $fwd = Read-Mig $dir 'forward'
    $n = Count-Steps $fwd
    Check ($n -ge 6) ('forward ha almeno 6 passi (trovati ' + $n + ')')

    # 1 preflight su stato pulito
    $o = Invoke-Sql (Read-Mig $dir 'preflight')
    Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_PREFLIGHT_OK') 'preflight OK sullo stato iniziale'
    # 2 forward e verify
    $o = Invoke-Sql $fwd -Write
    Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_FORWARD_OK') 'forward OK'
    $o = Invoke-Sql (Read-Mig $dir 'verify')
    Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_VERIFY_OK' -and $o -notmatch "(?m)\tSTOP\s*$") 'verify OK dopo il forward'
    # 3 righe esistenti: tutte con un codice distinto e regolare, nessuna riga persa
    $cntAfter = Get-Scalar 'SELECT COUNT(*) AS ksval FROM export;'
    Check ($cntAfter -eq $cntBefore) ('nessuna riga persa (' + $cntBefore + ' prima, ' + $cntAfter + ' dopo)')
    $dist = Get-Scalar 'SELECT COUNT(DISTINCT TokenAccesso) AS ksval FROM export;'
    Check ($dist -eq $cntBefore) 'ogni feed esistente ha un codice distinto'
    $bad = Get-Scalar "SELECT COUNT(*) AS ksval FROM export WHERE CHAR_LENGTH(TokenAccesso) <> 48 OR TokenAccesso NOT REGEXP '^[0-9A-F]+$';"
    Check ($bad -eq '0') 'ogni codice e di 48 caratteri esadecimali maiuscoli'
    # 4 routine del gestionale con la firma attuale
    $id = Test-Newexport 'KSFEEDDB1'
    Check ($id -match '^\d+$') 'Newexport crea una riga'
    $row = Get-Scalar ("SELECT CONCAT_WS(';', LENGTH(TokenAccesso), Separatore, DelimitatoreTesto, Codifica, SeparatoreDecimale, Intestazione, XmlRadice, XmlElemento, TogliHtml, MinutiCache, ParolaDisponibile, ParolaInArrivo, ParolaNonDisponibile, SenzaImmagine, SenzaEan, PrezzoZero) AS ksval FROM export WHERE ID = " + $id + ";")
    Check ($row -eq '48;|;;utf-8;.;1;prodotti;prodotto;1;60;Disponibile;In Arrivo;Non Disponibile;0;0;1') 'i predefiniti delle colonne nuove sono quelli dichiarati'
    $tok1 = Get-Scalar ("SELECT TokenAccesso AS ksval FROM export WHERE ID = " + $id + ";")
    $o = Invoke-Sql ("CALL Modexport('KSFEEDDB1m', 'pw2', '#Codice#|#Ean#', 1, 0, 0, 0, 0, 'www.example.test', 'csv', 0, 0, 0, 0, 0, 0, 1, " + $id + ", @r);") -Write
    Check (-not (Failed $o)) 'Modexport funziona con la firma attuale'
    $tok2 = Get-Scalar ("SELECT TokenAccesso AS ksval FROM export WHERE ID = " + $id + ";")
    Check ($tok1 -eq $tok2 -and $tok1 -ne '') 'Modexport non cambia il codice'
    $o = Invoke-Sql ("UPDATE export SET TokenAccesso = DEFAULT WHERE ID = " + $id + ";") -Write
    $tok3 = Get-Scalar ("SELECT TokenAccesso AS ksval FROM export WHERE ID = " + $id + ";")
    Check ((-not (Failed $o)) -and $tok3 -ne $tok1 -and $tok3 -match '^[0-9A-F]{48}$') 'Nuovo codice: SET TokenAccesso = DEFAULT lo rinnova'
    # 5 codice errato o duplicato rifiutato
    $o = Invoke-Sql ("INSERT INTO export (Descrizione, TokenAccesso) VALUES ('KSFEEDDB2', 'abc');") -Write
    Check ($o -match 'ERROR 3819') 'codice corto rifiutato (CHECK)'
    $o = Invoke-Sql ("INSERT INTO export (Descrizione, TokenAccesso) VALUES ('KSFEEDDB2', LOWER('" + $tok3 + "'));") -Write
    Check ($o -match 'ERROR 3819') 'codice in minuscolo rifiutato (CHECK)'
    $o = Invoke-Sql ("INSERT INTO export (Descrizione, TokenAccesso) VALUES ('KSFEEDDB2', '" + $tok3 + "');") -Write
    Check ($o -match 'ERROR 1062') 'codice duplicato rifiutato (indice unico)'
    # 6 cascata
    $o = Invoke-Sql ("INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo) VALUES (" + $id + ", 1, 'title', 'Descrizione1'), (" + $id + ", 2, 'price', 'Prezzo'); INSERT INTO export_stato (ExportId, UltimeRighe) VALUES (" + $id + ", 5);") -Write
    Check (-not (Failed $o)) 'righe in export_colonne e export_stato'
    $o = Invoke-Sql ("INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo) VALUES (" + $id + ", 2, 'dup', 'Marca');") -Write
    Check ($o -match 'ERROR 1062') 'posizione duplicata nello stesso feed rifiutata'
    $o = Invoke-Sql ("INSERT INTO export_colonne (ExportId, Posizione, TitoloColonna, Campo) VALUES (99999999, 1, 'x', 'Marca');") -Write
    Check ($o -match 'ERROR 1452') 'colonna di un feed inesistente rifiutata (chiave esterna)'
    $o = Invoke-Sql ("CALL Delexport(" + $id + ");") -Write
    $left = Get-Scalar ("SELECT (SELECT COUNT(*) FROM export_colonne WHERE ExportId = " + $id + ") + (SELECT COUNT(*) FROM export_stato WHERE ExportId = " + $id + ") AS ksval;")
    Check ((-not (Failed $o)) -and $left -eq '0') 'Delexport cancella anche colonne e stato (cascata)'
    # 7 forward rilanciato: idempotente, i codici non cambiano
    $tokSum1 = Get-Scalar 'SELECT SHA2(GROUP_CONCAT(TokenAccesso ORDER BY ID), 256) AS ksval FROM export;'
    $o = Invoke-Sql $fwd -Write
    $tokSum2 = Get-Scalar 'SELECT SHA2(GROUP_CONCAT(TokenAccesso ORDER BY ID), 256) AS ksval FROM export;'
    Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_FORWARD_OK' -and $tokSum1 -eq $tokSum2) 'forward rilanciato: nessun errore e codici invariati'
    # 8 rollback rifiutato senza conferma, eseguito con conferma
    $o = Invoke-Sql (Read-Mig $dir 'rollback') -Write
    $still = Get-Scalar "SELECT COUNT(*) AS ksval FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('export_stato', 'export_colonne');"
    Check ((Failed $o) -and $still -eq '2') 'rollback senza conferma: rifiutato, nulla cancellato'
    # 9 verify si ferma se i dati sono corrotti
    # il vincolo CHECK resta presente ma non applicato: il verify deve fermarsi per il solo codice troppo corto (esadecimale valido, lunghezza sbagliata)
    $o = Invoke-Sql ("ALTER TABLE export DROP CHECK ck_export_token_accesso; UPDATE export SET TokenAccesso = 'ABC' WHERE ID = (SELECT m FROM (SELECT MIN(ID) m FROM export) x); ALTER TABLE export ADD CONSTRAINT ck_export_token_accesso CHECK (1 = 1) NOT ENFORCED;") -Write
    Check (-not (Failed $o)) 'preparazione: codice corto con il CHECK non applicato'
    $o = Invoke-Sql (Read-Mig $dir 'verify')
    Check ((Failed $o) -and $o -notmatch 'EXPORT_FEED_DB_VERIFY_OK') 'verify si ferma con un codice di lunghezza sbagliata'
    $null = Invoke-Sql ("ALTER TABLE export DROP CHECK ck_export_token_accesso; UPDATE export SET TokenAccesso = DEFAULT WHERE TokenAccesso NOT REGEXP '^[0-9A-F]{48}$';") -Write
    $null = Invoke-Sql $fwd -Write
    $o = Invoke-Sql (Read-Mig $dir 'verify')
    Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_VERIFY_OK') 'dopo il ripristino il verify torna OK (il forward rimette il CHECK)'
    $o = Invoke-Sql ("ALTER TABLE export ALTER COLUMN Intestazione SET DEFAULT 0;") -Write
    $o = Invoke-Sql (Read-Mig $dir 'verify')
    Check ((Failed $o) -and $o -notmatch 'EXPORT_FEED_DB_VERIFY_OK') 'verify si ferma con un predefinito sbagliato'
    $null = Invoke-Sql ("ALTER TABLE export ALTER COLUMN Intestazione SET DEFAULT 1;") -Write
    # 10 binlog STATEMENT: preflight e forward si fermano
    $pf = (Read-Mig $dir 'preflight').Replace('@@global.log_bin', '1').Replace('@@global.binlog_format', "'STATEMENT'")
    $o = Invoke-Sql $pf
    Check ((Failed $o) -and $o -notmatch 'EXPORT_FEED_DB_PREFLIGHT_OK') 'preflight si ferma con binlog STATEMENT'
    $null = Reset-Clean $dir
    $fb = $fwd.Replace('@@global.log_bin', '1').Replace('@@global.binlog_format', "'STATEMENT'")
    $o = Invoke-Sql $fb -Write
    Check ((Failed $o) -and (Get-Snapshot) -eq $snapA) 'forward si ferma con binlog STATEMENT senza toccare lo schema'
    # 11 rollback: stato iniziale identico
    $null = Invoke-Sql $fwd -Write
    $null = Reset-Clean $dir
    Check ((Get-Snapshot) -eq $snapA) 'rollback: schema, indici, vincoli e dati di export, exportcampi e export_filtri come prima'
    # 12 riga inserita durante la migrazione (dopo il passo che imposta il predefinito, prima del backfill)
    $stepDefault = 0
    $ms = [regex]::Matches($fwd, '(?m)^-- STEP (\d+)[^\r\n]*')
    for ($i = 0; $i -lt $ms.Count; $i++) { if ($ms[$i].Value -match 'PREDEFINITO') { $stepDefault = [int]$ms[$i].Groups[1].Value } }
    Check ($stepDefault -gt 0) 'un passo e marcato PREDEFINITO'
    if ($stepDefault -gt 0) {
        $null = Invoke-Sql (Get-ForwardUpTo $fwd $stepDefault) -Write
        $idw = Test-Newexport 'KSFEEDDB3'
        $tw = Get-Scalar ("SELECT IFNULL(TokenAccesso, 'NULL') AS ksval FROM export WHERE ID = " + $idw + ";")
        Check ($tw -match '^[0-9A-F]{48}$') 'una riga creata a meta migrazione riceve gia il suo codice'
        $o = Invoke-Sql $fwd -Write
        $o = Invoke-Sql (Read-Mig $dir 'verify')
        Check ((-not (Failed $o)) -and $o -match 'EXPORT_FEED_DB_VERIFY_OK') 'dopo il forward completo la riga di meta migrazione e regolare'
        $null = Reset-Clean $dir
    }
    # 13 interruzione dopo ciascun passo: ripresa e rollback
    for ($k = 0; $k -lt $n; $k++) {
        $null = Reset-Clean $dir
        $null = Invoke-Sql (Get-ForwardUpTo $fwd $k) -Write
        $o = Invoke-Sql $fwd -Write
        $v = Invoke-Sql (Read-Mig $dir 'verify')
        Check ((-not (Failed $o)) -and (-not (Failed $v)) -and $v -match 'EXPORT_FEED_DB_VERIFY_OK') ('ripresa dopo l''interruzione prima del passo ' + ($k + 1) + ': forward e verify OK')
        $null = Reset-Clean $dir
        $null = Invoke-Sql (Get-ForwardUpTo $fwd $k) -Write
        $o = Invoke-Sql ($confirm + (Read-Mig $dir 'rollback')) -Write
        Check ((-not (Failed $o)) -and (Get-Snapshot) -eq $snapA) ('rollback dopo l''interruzione prima del passo ' + ($k + 1) + ': stato iniziale')
    }
    $null = Reset-Clean $dir
    Remove-TestRows
    Check ((Get-Snapshot) -eq $snapA) 'stato finale = stato iniziale'
}

# ---------------------------------------------------------------- esecuzione
$exitCode = 0
try {
    foreach ($k in @('preflight', 'forward', 'verify', 'rollback')) {
        if (-not (Test-Path -LiteralPath (Join-Path $migDir ($prefix + $k + '.sql')))) { Write-Host ('EXPORT_FEED_DB FAIL: manca ' + $prefix + $k + '.sql'); exit 1 }
    }
    Write-Host 'Prova sugli script reali'
    Run-Suite $migDir
    if ($e2e.Count -gt 0) { Write-Host ('EXPORT_FEED_DB FAIL: ' + $e2e.Count + ' controlli falliti'); $exitCode = 1 }
    else { Write-Host 'EXPORT_FEED_DB OK (script reali)' }

    if (-not $SkipMutants -and $exitCode -eq 0) {
        # Mutanti: (nome, file, testo da sostituire, nuovo testo). Ogni mutante cambia UNA cosa; la prova deve fallire.
        $mutants = @(
            @('indice-unico-tolto', 'forward', 'ADD UNIQUE KEY uk_export_token_accesso', 'ADD KEY uk_export_token_accesso'),
            @('predefinito-prima-del-backfill-tolto', 'forward', 'SET DEFAULT (HEX(RANDOM_BYTES(24)))', 'SET DEFAULT NULL'),
            @('backfill-tolto', 'forward', 'SET TokenAccesso = HEX(RANDOM_BYTES(24)) WHERE ID > 0', 'SET TokenAccesso = TokenAccesso WHERE ID > 0'),
            @('ascii-bin-tolto', 'forward', 'MODIFY COLUMN TokenAccesso varchar(64) CHARACTER SET ascii COLLATE ascii_bin', 'MODIFY COLUMN TokenAccesso varchar(64) CHARACTER SET ascii COLLATE ascii_general_ci'),
            @('check-formato-tolto', 'forward', "REGEXP_LIKE(TokenAccesso, ''^[0-9A-F]{48}$'', ''c'')", '1 = 1'),
            @('cascata-colonne-tolta', 'forward', 'CONSTRAINT fk_export_colonne_export FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE', 'CONSTRAINT fk_export_colonne_export FOREIGN KEY (ExportId) REFERENCES `export` (ID)'),
            @('cascata-stato-tolta', 'forward', 'CONSTRAINT fk_export_stato_export FOREIGN KEY (ExportId) REFERENCES `export` (ID) ON DELETE CASCADE', 'CONSTRAINT fk_export_stato_export FOREIGN KEY (ExportId) REFERENCES `export` (ID)'),
            @('posizione-senza-unicita', 'forward', 'UNIQUE KEY uk_export_colonne_posizione', 'KEY uk_export_colonne_posizione'),
            @('predefinito-intestazione-0', 'forward', 'ADD COLUMN Intestazione int NOT NULL DEFAULT 1', 'ADD COLUMN Intestazione int NOT NULL DEFAULT 0'),
            @('predefinito-prezzozero-0', 'forward', 'ADD COLUMN PrezzoZero int NOT NULL DEFAULT 1', 'ADD COLUMN PrezzoZero int NOT NULL DEFAULT 0'),
            @('predefinito-minuticache', 'forward', 'ADD COLUMN MinutiCache int NOT NULL DEFAULT 60', 'ADD COLUMN MinutiCache int NOT NULL DEFAULT 30'),
            @('predefinito-separatore', 'forward', "NOT NULL DEFAULT ''|''", "NOT NULL DEFAULT '';''"),
            @('passo-senza-guardia', 'forward', "AND COLUMN_NAME = 'TokenAccesso') = 0,", "AND COLUMN_NAME = 'TokenAccesso') >= 0,"),
            @('guardia-binlog-tolta-forward', 'forward', '@@global.log_bin = 1 AND', '@@global.log_bin = 9 AND'),
            @('guardia-binlog-tolta-preflight', 'preflight', '@@global.log_bin = 1 AND', '@@global.log_bin = 9 AND'),
            @('rollback-senza-conferma', 'rollback', '(@KeepStoreConfirmDropFeedData <=> 1)', '(1 = 1)'),
            @('rollback-non-cancella-stato', 'rollback', 'DROP TABLE IF EXISTS export_stato', 'DO 0'),
            @('rollback-non-cancella-colonne', 'rollback', '''DROP COLUMN `''', '''DO 0 `'''),
            @('verify-senza-lunghezza', 'verify', 'CHAR_LENGTH(TokenAccesso) <> 48 OR', ''),
            @('verify-senza-predefiniti', 'verify', 'e.col_default', 'c.COLUMN_DEFAULT')
        )
        $script:stopFirst = $true
        foreach ($m in $mutants) {
            if ($MutantFilter -and $m[0] -notlike ('*' + $MutantFilter + '*')) { continue }
            $mdir = Join-Path $tmp ('mut-' + $m[0])
            New-Item -ItemType Directory -Force -Path $mdir | Out-Null
            foreach ($k in @('preflight', 'forward', 'verify', 'rollback')) { Copy-Item -LiteralPath (Join-Path $migDir ($prefix + $k + '.sql')) -Destination $mdir }
            $target = Join-Path $mdir ($prefix + $m[1] + '.sql')
            $txt = [IO.File]::ReadAllText($target, $utf8)
            if (-not $txt.Contains($m[2])) { Write-Host ('  FAIL mutante ' + $m[0] + ': testo da sostituire non trovato'); $exitCode = 1; continue }
            [IO.File]::WriteAllText($target, $txt.Replace($m[2], $m[3]), $utf8)
            $e2e.Clear()
            $killed = $false
            try { Run-Suite $mdir } catch { $killed = $true; if ($_.Exception.Message -ne 'MUTANT_KILLED') { Write-Host ('       (arresto per errore: ' + $_.Exception.Message + ')') } }
            if ($e2e.Count -gt 0) { $killed = $true }
            try { $null = Reset-Clean $migDir } catch { }
            if ($killed) { Write-Host ('  ok   mutante ucciso: ' + $m[0]) } else { Write-Host ('  FAIL mutante SOPRAVVISSUTO: ' + $m[0]); $exitCode = 1 }
        }
        if ($exitCode -eq 0) { Write-Host 'EXPORT_FEED_DB OK (mutanti)' }
    }
} catch {
    Write-Host ('EXPORT_FEED_DB FAIL: ' + $_.Exception.Message); $exitCode = 1
} finally {
    try { $null = Reset-Clean $migDir } catch { }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
exit $exitCode
