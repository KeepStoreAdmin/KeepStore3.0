[CmdletBinding()]
param(
    [string]$Runner,
    [string]$OnlyScenario,
    [int]$HoldSeconds = 10,
    [int]$Rounds = 1
)

# KS-C01 prove di concorrenza a due sessioni sul LAB LOCALE (127.0.0.1:13317, schema sintetico), alla stessa isolazione
# SERIALIZABLE del checkout reale (ordine.aspx.vb). La sessione A esegue la routine reale e trattiene la transazione
# (SLEEP) prima del ROLLBACK (o del COMMIT negli scenari P5/P6); la sessione B parte dopo e misura quanto aspetta e come
# finisce. Scenari: P0 coerenza del numero; P1 numerazione; P2 ultima giacenza; P3 ultima unita con commit di A;
# P4 come P1 con la riga triggerstatus presente (mutex del trigger come nel dump di riferimento); P5/P6 commit reale di A
# (senza/con la riga triggerstatus); P7 partenza simultanea (barriera su orologio UTC comune) con scarti da -4 a +8 ms,
# profilo ripetuto -Rounds volte (default 1); P8 ultima disponibilita attraverso la routine reale con commit di A (B deve\n# essere rifiutata con ORDER_INVENTORY_UNAVAILABLE, nessuna vendita oltre giacenza).
# Dati committati dallo strumento: righe carrello di prova, una riga di giacenza sintetica (TC 777, P3), la riga
# triggerstatus (P4/P6) e i documenti creati da A in P5/P6. Tutto viene rimosso a fine scenario con DELETE mirate
# (solo id oltre la baseline; la pulizia si ferma se esistono piu di 4 documenti oltre la baseline) e lo stato
# finale e confrontato con la baseline.
# Richiede Windows PowerShell 5.1 e l'account dedicato del LAB. Mai su produzione.
$ErrorActionPreference = 'Stop'
if (-not $Runner) { $Runner = Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$work = Join-Path ([IO.Path]::GetTempPath()) ('ks-concurrency-' + $PID)
New-Item -ItemType Directory -Path $work -Force | Out-Null

$guard = @'
SET @ks_ok=(@@server_uuid='1167ebae-d0c0-11f1-b348-9c7bef540c10' AND @@port=13317 AND DATABASE()='keepstore_regorder_lab_20261025' AND (SELECT COUNT(*) FROM iva)=3 AND (SELECT iva FROM articoli WHERE id=1)=1 AND (SELECT COUNT(*) FROM articoli_giacenze WHERE ArticoliId=1 AND TCId IN(-1,18))=2);
SET @ks_guard=IF(@ks_ok,'SELECT ''CONC_TARGET_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_WRONG_CONC_TARGET');
PREPARE ks_g FROM @ks_guard;EXECUTE ks_g;DEALLOCATE PREPARE ks_g;
'@

# Guardia leggera per le sessioni concorrenti: solo variabili di server e tabelle non toccate dall'altra sessione.
# Anche un SET @v=(SELECT ...) e una lettura con blocco: una guardia che legge righe trattenute dall'altra sessione
# resterebbe in attesa PRIMA di iniziare la misura (verificato nella prima versione di questo strumento).
$guardLight = @'
SET @ks_ok=(@@server_uuid='1167ebae-d0c0-11f1-b348-9c7bef540c10' AND @@port=13317 AND DATABASE()='keepstore_regorder_lab_20261025' AND (SELECT COUNT(*) FROM iva)=3);
SET @ks_guard=IF(@ks_ok,'SELECT ''CONC_TARGET_LIGHT''','SELECT * FROM information_schema.KEEPSTORE_STOP_WRONG_CONC_TARGET');
PREPARE ks_g FROM @ks_guard;EXECUTE ks_g;DEALLOCATE PREPARE ks_g;
'@

function Run-Sql([string]$name, [string]$sql, [switch]$Write) {
    $file = Join-Path $work ($name + '.sql')
    [IO.File]::WriteAllText($file, $sql, (New-Object Text.UTF8Encoding($false)))
    $argsList = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $Runner, '-SqlFile', $file)
    if ($Write) { $argsList += '-Write' }
    $out = & powershell.exe @argsList 2>&1 | ForEach-Object { "$_" }
    return @{ Code = $LASTEXITCODE; Lines = @($out) }
}
function Start-Session([string]$name, [string]$sql) {
    $file = Join-Path $work ($name + '.sql')
    $outFile = Join-Path $work ($name + '.out')
    [IO.File]::WriteAllText($file, $sql, (New-Object Text.UTF8Encoding($false)))
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', $Runner, '-SqlFile', $file, '-Write') -RedirectStandardOutput $outFile -WindowStyle Hidden -PassThru
    return @{ Proc = $p; Out = $outFile }
}
function Read-Json([string[]]$lines, [string]$tag) {
    $l = @($lines) | Where-Object { $_ -match ('^' + $tag + '\t\{') } | Select-Object -First 1
    if (-not $l) { return $null }
    return ($l.Substring($tag.Length + 1) | ConvertFrom-Json)
}
function Get-State {
    $sql = @'
SELECT 'STATE',JSON_OBJECT('docs',(SELECT COUNT(*) FROM documenti),'maxId',(SELECT MAX(id) FROM documenti),'r1',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),'r18',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18),'cart',(SELECT COUNT(*) FROM carrello),'iva',(SELECT COUNT(*) FROM iva),'tc777',(SELECT COUNT(*) FROM articoli_giacenze WHERE TCId=777),'righe',(SELECT COUNT(*) FROM documentirighe),'pie',(SELECT COUNT(*) FROM documentipie),'dag',(SELECT COUNT(*) FROM documentiagenti),'dpl',(SELECT COUNT(*) FROM documentiplus),'cao',(SELECT COUNT(*) FROM controllaarrotondamento),'dde',(SELECT COUNT(*) FROM documentidestinazioni),'ts',(SELECT COUNT(*) FROM triggerstatus));
'@
    $r = Run-Sql 'state' $sql
    $j = Read-Json $r.Lines 'STATE'
    if (-not $j) { throw ('STATE_READ_FAILED: ' + ($r.Lines -join ' | ')) }
    return $j
}
function Same-State($a, $b) { foreach ($k in @('docs', 'maxId', 'r1', 'r18', 'cart', 'iva', 'tc777', 'righe', 'pie', 'dag', 'dpl', 'cao', 'dde', 'ts')) { if ([decimal]$a.$k -ne [decimal]$b.$k) { return $false } }; return $true }

function Cart-Insert([int]$login, [int]$tc, $qnt, [int]$listino, $net) {
    $gross = [decimal]$net * 1.22
    return ("INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) VALUES({0},1,{1},'KS-LAB-ARTICLE','KS CONC',{2},{3},{4},{5},-1,-1,'KS',-1,-1,'KS');" -f $login, $tc, ([decimal]$qnt).ToString($inv), $listino, ([decimal]$net).ToString($inv), $gross.ToString($inv))
}
function Order-Session([string]$tag, [int]$login, [int]$user, [int]$company, [int]$hold, [string]$lockName = '', [string]$barrierUtc = '', [switch]$Commit) {
    $call = "CALL Carrello_Documento($login,4,1,1,@addr,0,0,0,0,'KS CONC $tag',0,22,1,'','',0,1,22,@doc_number);"
    # Barriera di partenza simultanea (P7): attesa fino a un istante comune su orologio UTC del server, prima di aprire la transazione.
    $barrier = if ($barrierUtc) { "DO SLEEP(GREATEST(0,TIMESTAMPDIFF(MICROSECOND,UTC_TIMESTAMP(6),'$barrierUtc')/1000000));" } else { '' }
    $finish = if ($Commit) { 'COMMIT;' } else { 'ROLLBACK;' }
    # Segnale di sincronizzazione: la sessione A prende un lock utente (non tocca i dati) dopo la CALL; il chiamante parte con B solo allora.
    $signal = if ($lockName) { "SELECT GET_LOCK('$lockName',0) AS signal_taken;" } else { '' }
    return ($guardLight + "`n" + @"
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SET SESSION innodb_lock_wait_timeout=25;
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=$login);
$barrier
SET @t0=NOW(6);
START TRANSACTION;
$call
SET @created=(SELECT id FROM documenti WHERE UtentiId=$user AND AziendeId=$company AND TipoDocumentiId=4 AND NDocumento=@doc_number AND YEAR(DataDocumento)=YEAR(CURDATE()) LIMIT 1);
SELECT '${tag}_CALL',JSON_OBJECT('elapsedMs',TIMESTAMPDIFF(MICROSECOND,@t0,NOW(6))/1000,'t0',CAST(@t0 AS CHAR),'docNumber',@doc_number,'stored',(SELECT NDocumento FROM documenti WHERE id=@created),'resolved',(SELECT COUNT(*) FROM documenti WHERE UtentiId=$user AND AziendeId=$company AND TipoDocumentiId=4 AND NDocumento=@doc_number AND YEAR(DataDocumento)=YEAR(CURDATE())),'azienda',(SELECT AziendeId FROM documenti WHERE id=@created));
$signal
SELECT SLEEP($hold);
$finish
SELECT '${tag}_END',JSON_OBJECT('totalMs',TIMESTAMPDIFF(MICROSECOND,@t0,NOW(6))/1000);
"@)
}

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$scenario, [string]$check, [string]$verdict, [string]$detail) {
    $results.Add(@{ S = $scenario; C = $check; V = $verdict; D = $detail })
    '{0,-4} [{1,-4}] {2}: {3}' -f $scenario, $verdict, $check, $detail
}
function Want([string]$id) { return ((-not $OnlyScenario) -or ($id -match $OnlyScenario)) }
function Wait-Both($a, $b, [int]$timeoutSeconds, $timing = $null) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline -and -not ($a.Proc.HasExited -and $b.Proc.HasExited)) {
        if ($timing -and $b.Proc.HasExited -and -not $timing.BDone) { $timing.BDone = Get-Date }
        Start-Sleep -Milliseconds 100
    }
    if ($timing -and $b.Proc.HasExited -and -not $timing.BDone) { $timing.BDone = Get-Date }
    if (-not ($a.Proc.HasExited -and $b.Proc.HasExited)) { foreach ($x in @($a, $b)) { if (-not $x.Proc.HasExited) { Stop-Process -Id $x.Proc.Id -Force } }; throw 'SESSION_TIMEOUT' }
}
function Read-Out($s) { return @(Get-Content -LiteralPath $s.Out -ErrorAction SilentlyContinue) }
function Err-Of($lines) { $e = @($lines) | Where-Object { $_ -like 'stderr:*' } | Select-Object -First 1; return $e }

$baseline = Get-State
'BASELINE ' + ($baseline | ConvertTo-Json -Compress)

# ---------- P0: coerenza del numero tra routine, trigger e ricerca dell'applicazione ----------
if (Want 'P0') {
    $sql = $guard + @'
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=19832);
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) VALUES(19832,1,-1,'KS-LAB-ARTICLE','KS CONC',1,1,10,12.2,-1,-1,'KS',-1,-1,'KS');
CALL Carrello_Documento(19832,4,1,1,@addr,0,0,0,0,'KS CONC P0a',0,22,1,'','',0,1,22,@n_a);
SET @id_a=(SELECT MAX(id) FROM documenti);
SELECT 'P0A',JSON_OBJECT('out',@n_a,'stored',(SELECT NDocumento FROM documenti WHERE id=@id_a),'resolved',(SELECT COUNT(*) FROM documenti WHERE UtentiId=1 AND AziendeId=1 AND TipoDocumentiId=4 AND NDocumento=@n_a AND YEAR(DataDocumento)=YEAR(CURDATE())));
ROLLBACK;
START TRANSACTION;
INSERT INTO documenti(TipoDocumentiId,DataDocumento,AziendeId,UtentiId) VALUES(1,CURDATE(),1,1);
SET @neighbor=(SELECT NDocumento FROM documenti WHERE id=LAST_INSERT_ID());
INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) VALUES(19832,1,-1,'KS-LAB-ARTICLE','KS CONC',1,1,10,12.2,-1,-1,'KS',-1,-1,'KS');
CALL Carrello_Documento(19832,4,1,1,@addr,0,0,0,0,'KS CONC P0b',0,22,1,'','',0,1,22,@n_b);
SET @id_b=(SELECT MAX(id) FROM documenti WHERE TipoDocumentiId=4);
SELECT 'P0B',JSON_OBJECT('neighborNumber',@neighbor,'out',@n_b,'stored',(SELECT NDocumento FROM documenti WHERE id=@id_b),'resolved',(SELECT COUNT(*) FROM documenti WHERE UtentiId=1 AND AziendeId=1 AND TipoDocumentiId=4 AND NDocumento=@n_b AND YEAR(DataDocumento)=YEAR(CURDATE())));
ROLLBACK;
'@
    $r = Run-Sql 'p0' $sql -Write
    $a = Read-Json $r.Lines 'P0A'; $b = Read-Json $r.Lines 'P0B'
    if (-not $a) { Add-Result 'P0a' 'esecuzione' 'FAIL' ('nessuna osservazione: ' + (Err-Of $r.Lines)) }
    else { Add-Result 'P0a' 'numero OUT = numero memorizzato e ricerca applicativa trova 1 documento' $(if (([int]$a.out -eq [int]$a.stored) -and ([int]$a.resolved -eq 1)) { 'OK' } else { 'FAIL' }) ("out=$($a.out) stored=$($a.stored) resolved=$($a.resolved)") }
    if (-not $b) { Add-Result 'P0b' 'esecuzione' 'OSS' ('nessuna osservazione: ' + (Err-Of $r.Lines)) }
    else { Add-Result 'P0b' 'contatore condiviso con altro tipo (tipo 1 e 4 nel LAB): numero OUT contro memorizzato (FAIL atteso = difetto candidato noto, vedi Masterplan KS-C01-LAB-ORDER-CONCURRENCY-1A)' $(if (([int]$b.out -eq [int]$b.stored) -and ([int]$b.resolved -eq 1)) { 'OK' } else { 'FAIL' }) ("documento vicino n.$($b.neighborNumber); out=$($b.out) stored=$($b.stored) ricerca applicativa=$($b.resolved) documento/i") }
}

# ---------- Setup carrelli committati per gli scenari a due sessioni (rimossi a fine scenario) ----------
function Setup-Carts([string]$extraA, [string]$extraB) {
    $sql = $guard + "`n" + (Cart-Insert 19832 -1 1 1 10) + "`n" + (Cart-Insert 19833 18 1 10 12) + "`n" + $extraA + $extraB
    $r = Run-Sql 'setup' $sql -Write
    if ($r.Code -ne 0) { throw ('SETUP_FAILED: ' + ($r.Lines -join ' | ')) }
}
function Clear-Carts {
    $r = Run-Sql 'clear' ($guard + "`nDELETE FROM carrello WHERE LoginId IN(19832,19833);`n") -Write
    if ($r.Code -ne 0) { throw ('CLEAR_FAILED: ' + ($r.Lines -join ' | ')) }
}

function Wait-ForLock([string]$lockName, [int]$timeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    $t0 = Get-Date
    while ((Get-Date) -lt $deadline) {
        $r = Run-Sql 'poll' ("SELECT 'LOCKSTATE',IFNULL(IS_USED_LOCK('$lockName'),0) AS held;`n")
        $hit = @($r.Lines) | Where-Object { $_ -match '^LOCKSTATE\t[1-9][0-9]*\s*$' } | Select-Object -First 1
        if ($VerbosePreference -eq 'Continue') { Write-Host ('   poll +{0:N1}s code={1} line=[{2}]' -f ((Get-Date) - $t0).TotalSeconds, $r.Code, $hit) }
        if ($hit) { return }
        Start-Sleep -Milliseconds 200
    }
    throw 'SESSION_A_NEVER_SIGNALLED'
}
function Run-Pair([string]$label, [string]$sqlA, [string]$sqlB, [string]$lockName) {
    $a = Start-Session ($label + 'A') $sqlA
    Wait-ForLock $lockName 40
    $timing = @{ BStart = (Get-Date); BDone = $null }
    $b = Start-Session ($label + 'B') $sqlB
    Wait-Both $a $b 150 $timing
    $bMs = -1; if ($timing.BDone) { $bMs = [Math]::Round(($timing.BDone - $timing.BStart).TotalMilliseconds) }
    return @{ A = (Read-Out $a); B = (Read-Out $b); BMs = $bMs }
}
function Judge-Pair([string]$id, $pair, [string]$what) {
    $aCall = Read-Json $pair.A 'A_CALL'; $bCall = Read-Json $pair.B 'B_CALL'
    $bErr = Err-Of $pair.B; $aErr = Err-Of $pair.A
    if (-not $aCall) { Add-Result $id 'sessione A' 'FAIL' ('nessun esito: ' + $aErr); return }
    $aEnd = Read-Json $pair.A 'A_END'
    $minWaitMs = [Math]::Max(1500, 0.3 * $HoldSeconds * 1000)
    if ($bCall) {
        $waited = [double]$bCall.elapsedMs
        $blocked = $waited -ge $minWaitMs
        Add-Result $id "$what - B atteso la fine di A" $(if ($blocked) { 'OK' } else { 'FAIL' }) ("attesa B {0} ms (minimo atteso {1} ms; A ha trattenuto la transazione per {2} ms in tutto)" -f [Math]::Round($waited), [Math]::Round($minWaitMs), $(if ($aEnd) { [Math]::Round([double]$aEnd.totalMs) } else { 'n.d.' }))
        Add-Result $id "$what - B ha completato dopo il rollback di A" 'OK' ("B: numero OUT=$($bCall.docNumber) memorizzato=$($bCall.stored) azienda=$($bCall.azienda); A: numero OUT=$($aCall.docNumber)")
        Add-Result $id "$what - nessun numero duplicato visibile" $(if ([int]$bCall.docNumber -eq [int]$bCall.stored) { 'OK' } else { 'FAIL' }) ("A=$($aCall.docNumber) B=$($bCall.docNumber)")
    } else {
        Add-Result $id "$what - esito di B" 'OSS' ("B terminata con errore: " + $bErr)
    }
}

function Err-Code($lines) {
    foreach ($l in @($lines)) { if (("$l" -like 'stderr:*') -and ("$l" -match 'ERROR (\d+)')) { return [int]$Matches[1] } }
    return 0
}
# La riga triggerstatus (id=1) e il mutex del trigger di numerazione nel dump di riferimento: il LAB ha la tabella vuota.
function Add-Mutex {
    $r = Run-Sql 'mutex-add' ($guard + "`nINSERT INTO triggerstatus(id,DisableTrigger) VALUES(1,0);`n") -Write
    if ($r.Code -ne 0) { throw ('MUTEX_ADD_FAILED: ' + ($r.Lines -join ' | ')) }
}
function Remove-Mutex {
    $r = Run-Sql 'mutex-del' ($guard + "`nDELETE FROM triggerstatus WHERE id=1;`n") -Write
    if ($r.Code -ne 0) { Write-Warning ('MUTEX_REMOVE_FAILED: ' + ($r.Lines -join ' | ')) }
}
# Rimozione dei soli documenti creati dopo la baseline (id oltre il massimo registrato) e dei loro figli, ripristino delle
# due righe di giacenza e dei carrelli di prova. Guardia: piu di 4 documenti oltre la baseline fermano la pulizia.
function Cleanup-Committed($base) {
    $mx = [int]$base.maxId
    $v1 = ([decimal]$base.r1).ToString($inv); $v18 = ([decimal]$base.r18).ToString($inv)
    $sql = $guard + @"

SET @ks_n=(SELECT COUNT(*) FROM documenti WHERE id>$mx);
SET @ks_g2=IF(@ks_n<=4,'SELECT ''CLEANUP_SCOPE_OK''','SELECT * FROM information_schema.KEEPSTORE_STOP_TOO_MANY_DOCS');
PREPARE ks_g2 FROM @ks_g2;EXECUTE ks_g2;DEALLOCATE PREPARE ks_g2;
START TRANSACTION;
DELETE FROM documentirighe_fepa WHERE DocumentirigheId IN (SELECT id FROM documentirighe WHERE DocumentiId>$mx);
DELETE FROM documentiagenti WHERE DocumentiId>$mx;
DELETE FROM documentiplus WHERE DocumentiId>$mx;
DELETE FROM documentipie WHERE DocumentiId>$mx;
DELETE FROM controllaarrotondamento WHERE DocumentiId>$mx;
DELETE FROM documentidestinazioni WHERE DocumentiId>$mx;
DELETE FROM documentirighe WHERE DocumentiId>$mx;
DELETE FROM documenti WHERE id>$mx;
UPDATE articoli_giacenze SET Impegnata=$v1 WHERE ArticoliId=1 AND TCId=-1;
UPDATE articoli_giacenze SET Impegnata=$v18 WHERE ArticoliId=1 AND TCId=18;
DELETE FROM carrello WHERE LoginId IN(19832,19833);
COMMIT;
"@
    $r = Run-Sql 'cleanup-committed' $sql -Write
    if ($r.Code -ne 0) { Write-Warning ('CLEANUP_COMMITTED_FAILED: ' + ($r.Lines -join ' | ')) }
}
function Judge-CommitPair([string]$id, $pair, [string]$what) {
    $aCall = Read-Json $pair.A 'A_CALL'; $bCall = Read-Json $pair.B 'B_CALL'
    if (-not $aCall) { Add-Result $id "$what - sessione A" 'FAIL' ('nessun esito: ' + (Err-Of $pair.A)); return }
    Add-Result $id "$what - A: numero OUT = memorizzato e ricerca applicativa trova 1 documento" $(if (([int]$aCall.docNumber -eq [int]$aCall.stored) -and ([int]$aCall.resolved -eq 1)) { 'OK' } else { 'FAIL' }) ("out=$($aCall.docNumber) stored=$($aCall.stored) resolved=$($aCall.resolved)")
    if (-not $bCall) { Add-Result $id "$what - B dopo il commit di A" 'FAIL' ('B terminata con errore (codice ' + (Err-Code $pair.B) + '): ' + (Err-Of $pair.B)); return }
    $minWaitMs = [Math]::Max(1500, 0.3 * $HoldSeconds * 1000)
    $waited = [double]$bCall.elapsedMs
    Add-Result $id "$what - B atteso il commit di A" $(if ($waited -ge $minWaitMs) { 'OK' } else { 'FAIL' }) ("attesa B {0} ms (minimo atteso {1} ms)" -f [Math]::Round($waited), [Math]::Round($minWaitMs))
    Add-Result $id "$what - B: numero OUT = memorizzato e ricerca applicativa trova 1 documento" $(if (([int]$bCall.docNumber -eq [int]$bCall.stored) -and ([int]$bCall.resolved -eq 1)) { 'OK' } else { 'FAIL' }) ("out=$($bCall.docNumber) stored=$($bCall.stored) resolved=$($bCall.resolved)")
    Add-Result $id "$what - nessun numero duplicato e nessun salto (B = A + 1)" $(if ([int]$bCall.docNumber -eq ([int]$aCall.docNumber + 1)) { 'OK' } else { 'FAIL' }) ("A=$($aCall.docNumber) B=$($bCall.docNumber)")
}
function Run-CommitCase([string]$id, [bool]$withMutex) {
    $tag = $id.ToLower(); $lock = 'ks_conc_' + $tag
    $what = $(if ($withMutex) { 'commit di A, con riga triggerstatus' } else { 'commit di A, LAB senza riga triggerstatus' })
    $mutexOn = $false; $dirty = $false
    try {
        Setup-Carts '' ''
        if ($withMutex) { Add-Mutex; $mutexOn = $true }
        $dirty = $true
        $pair = Run-Pair $tag (Order-Session 'A' 19832 1 1 $HoldSeconds $lock '' -Commit) (Order-Session 'B' 19833 2 2 0) $lock
        Judge-CommitPair $id $pair $what
        $mid = Get-State
        $dDocs = [int]$mid.docs - [int]$baseline.docs; $dRighe = [int]$mid.righe - [int]$baseline.righe; $dPie = [int]$mid.pie - [int]$baseline.pie
        Add-Result $id "$what - effetti visibili: solo il documento di A (B ha fatto rollback)" $(if (($dDocs -eq 1) -and ($dRighe -eq 1) -and ($dPie -eq 1)) { 'OK' } else { 'FAIL' }) ("documenti +$dDocs, righe +$dRighe, piedi +$dPie")
    } finally {
        if ($dirty) { Cleanup-Committed $baseline }
        if ($mutexOn) { Remove-Mutex }
        Clear-Carts
    }
}

# ---------- P1: numerazione, righe di giacenza diverse (TC -1 contro TC 18) ----------
if (Want 'P1') {
    Setup-Carts '' ''
    try {
        $pair = Run-Pair 'p1' (Order-Session 'A' 19832 1 1 $HoldSeconds 'ks_conc_p1') (Order-Session 'B' 19833 2 2 0) 'ks_conc_p1'
        Judge-Pair 'P1' $pair 'numerazione (giacenze diverse)'
    } finally { Clear-Carts }
}

# ---------- P2: stessa riga di giacenza (TC 18, quantita 9 = ultima disponibile) ----------
if (Want 'P2') {
    $cartA = (Cart-Insert 19832 18 9 1 10); $cartB = (Cart-Insert 19833 18 9 10 12)
    $sql = $guard + "`n" + $cartA + "`n" + $cartB + "`n"
    $r = Run-Sql 'setup2' $sql -Write
    if ($r.Code -ne 0) { throw ('SETUP2_FAILED: ' + ($r.Lines -join ' | ')) }
    try {
        $pair = Run-Pair 'p2' (Order-Session 'A' 19832 1 1 $HoldSeconds 'ks_conc_p2') (Order-Session 'B' 19833 2 2 0) 'ks_conc_p2'
        Judge-Pair 'P2' $pair 'ultima giacenza (stessa riga)'
    } finally { Clear-Carts }
}

# ---------- P3: ultima unita con commit di A (riga di giacenza sintetica TC 777; istruzione di prenotazione della routine) ----------
if (Want 'P3') {
    $upd = "UPDATE articoli_giacenze SET Impegnata=COALESCE(Impegnata,0)+1 WHERE MagazziniId=1 AND ArticoliId=1 AND TCId=777 AND COALESCE(Giacenza,0)-COALESCE(Impegnata,0)>=1;"
    $r = Run-Sql 'setup3' ($guard + "`nINSERT INTO articoli_giacenze(MagazziniId,ArticoliId,TCId,Giacenza,Impegnata) VALUES(1,1,777,1,0);`n") -Write
    if ($r.Code -ne 0) { throw ('SETUP3_FAILED: ' + ($r.Lines -join ' | ')) }
    try {
        $sa = $guardLight + "`nSET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;`nSTART TRANSACTION;`n$upd`nSELECT 'A_CALL',JSON_OBJECT('rows',ROW_COUNT(),'at',CAST(NOW(6) AS CHAR));`nSELECT GET_LOCK('ks_conc_p3',0) AS signal_taken;`nSELECT SLEEP($HoldSeconds);`nCOMMIT;`nSELECT 'A_END',JSON_OBJECT('at',CAST(NOW(6) AS CHAR));`n"
        $sb = $guardLight + "`nSET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;`nSET SESSION innodb_lock_wait_timeout=25;`nSELECT 'B_START',JSON_OBJECT('at',CAST(NOW(6) AS CHAR));`nSET @t0=NOW(6);`nSTART TRANSACTION;`n$upd`nSELECT 'B_CALL',JSON_OBJECT('rows',ROW_COUNT(),'elapsedMs',TIMESTAMPDIFF(MICROSECOND,@t0,NOW(6))/1000,'at',CAST(NOW(6) AS CHAR));`nROLLBACK;`n"
        $pair = Run-Pair 'p3' $sa $sb 'ks_conc_p3'
        $aCall = Read-Json $pair.A 'A_CALL'; $bCall = Read-Json $pair.B 'B_CALL'
        if ($aCall -and $bCall) {
            Add-Result 'P3' 'A prenota l''ultima unita' $(if ([int]$aCall.rows -eq 1) { 'OK' } else { 'FAIL' }) ("righe aggiornate da A=$($aCall.rows)")
            $bStart = Read-Json $pair.B 'B_START'; $aEnd3 = Read-Json $pair.A 'A_END'
            Add-Result 'P3' 'B attende il commit di A e non prenota (nessuna vendita oltre giacenza)' $(if (([int]$bCall.rows -eq 0) -and ([double]$bCall.elapsedMs -ge 1000)) { 'OK' } else { 'FAIL' }) ("righe aggiornate da B=$($bCall.rows); attesa B $([Math]::Round([double]$bCall.elapsedMs)) ms; A prenota alle $($aCall.at), B parte alle $($bStart.at) e finisce alle $($bCall.at), A termina alle $($aEnd3.at)")
        } else { Add-Result 'P3' 'esecuzione' 'FAIL' ('A: ' + (Err-Of $pair.A) + ' B: ' + (Err-Of $pair.B)) }
        $chk = Run-Sql 'chk3' ($guard + "`nSELECT 'ROW777',JSON_OBJECT('impegnata',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=777),'giacenza',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=777));`n")
        $row = Read-Json $chk.Lines 'ROW777'
        Add-Result 'P3' 'stato finale della riga sintetica' $(if ($row -and ([decimal]$row.impegnata -eq 1) -and ([decimal]$row.giacenza -eq 1)) { 'OK' } else { 'FAIL' }) ($(if ($row) { "impegnata=$($row.impegnata) giacenza=$($row.giacenza)" } else { 'non letta' }))
    } finally {
        $c = Run-Sql 'clean3' ($guard + "`nDELETE FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=777;`n") -Write
        if ($c.Code -ne 0) { Write-Warning ('CLEANUP_P3_FAILED: ' + ($c.Lines -join ' | ')) }
    }
}

# ---------- P4: come P1 con la riga triggerstatus presente (mutex del trigger di numerazione, come nel dump di riferimento) ----------
if (Want 'P4') {
    $mutexOn = $false
    try {
        Setup-Carts '' ''
        Add-Mutex; $mutexOn = $true
        $pair = Run-Pair 'p4' (Order-Session 'A' 19832 1 1 $HoldSeconds 'ks_conc_p4') (Order-Session 'B' 19833 2 2 0) 'ks_conc_p4'
        Judge-Pair 'P4' $pair 'con riga triggerstatus'
    } finally {
        if ($mutexOn) { Remove-Mutex }
        Clear-Carts
    }
}

# ---------- P5 / P6: A COMMITTA l'ordine, B (SERIALIZABLE) attende e poi crea il successivo; senza e con riga triggerstatus ----------
if (Want 'P5') { Run-CommitCase 'P5' $false }
if (Want 'P6') { Run-CommitCase 'P6' $true }

# ---------- P7: partenza simultanea delle due sessioni (barriera su orologio UTC comune), ripetuta; entrambe fanno rollback ----------
if (Want 'P7') {
    $tally = @{ both = 0; deadlock = 0; other = 0 }
    try {
        Setup-Carts '' ''
        # Profilo di scarto di partenza in millisecondi (negativo = parte prima B, positivo = parte dopo B), ripetuto -Rounds volte.
        $delays = @(0, -4, -2, -1, 1, 2, 4, 8)
        $plan = @(); for ($rep = 1; $rep -le $Rounds; $rep++) { $plan += $delays }
        $i = 0
        foreach ($d in $plan) {
            $i++
            $base = (Get-Date).ToUniversalTime().AddSeconds(9)
            $fmtU = 'yyyy-MM-dd HH:mm:ss.ffffff'
            $targetA = $base.AddMilliseconds([Math]::Max(0, $d)).ToString($fmtU, $inv)
            $target = $targetA
            $targetB = $base.AddMilliseconds([Math]::Max(0, -$d)).ToString($fmtU, $inv)
            $a = Start-Session ("p7a$i") (Order-Session 'A' 19832 1 1 0 '' $targetA)
            $b = Start-Session ("p7b$i") (Order-Session 'B' 19833 2 2 0 '' $targetB)
            Wait-Both $a $b 150
            $oa = Read-Out $a; $ob = Read-Out $b
            $ca = Read-Json $oa 'A_CALL'; $cb = Read-Json $ob 'B_CALL'
            $ea = Err-Code $oa; $eb = Err-Code $ob
            if ($VerbosePreference -eq 'Continue') { foreach ($l in (@($oa) + @($ob))) { if ($l -match '_CALL|stderr') { Write-Host ('   raw: ' + $l) } }; Write-Host ('   barrier target UTC: ' + $target) }
            $da = $(if ($ca) { "ok n.$($ca.docNumber) (attesa $([Math]::Round([double]$ca.elapsedMs)) ms)" } else { "errore $ea" })
            $db = $(if ($cb) { "ok n.$($cb.docNumber) (attesa $([Math]::Round([double]$cb.elapsedMs)) ms)" } else { "errore $eb" })
            $skew = 'n/d'
            if ($ca -and $cb) {
                try {
                    $fmt = 'yyyy-MM-dd HH:mm:ss.ffffff'
                    $ta = [datetime]::ParseExact([string]$ca.t0, $fmt, $inv); $tb = [datetime]::ParseExact([string]$cb.t0, $fmt, $inv)
                    $skew = ('{0:N1} ms' -f [Math]::Abs(($ta - $tb).TotalMilliseconds))
                } catch { $skew = 'n/d' }
            }
            $coherent = (-not $ca -or ([int]$ca.docNumber -eq [int]$ca.stored)) -and (-not $cb -or ([int]$cb.docNumber -eq [int]$cb.stored))
            $known = (($ca) -or ($ea -eq 1213)) -and (($cb) -or ($eb -eq 1213))
            if ($ca -and $cb) { $tally.both++ } elseif ($ea -eq 1213 -or $eb -eq 1213) { $tally.deadlock++ } else { $tally.other++ }
            Add-Result 'P7' "round $i (A parte $d ms dopo B)" $(if ($known -and $coherent) { 'OK' } else { 'OSS' }) ("A: $da | B: $db | scarto misurato $skew")
        }
        Add-Result 'P7' 'riepilogo (esiti ammessi: ordine riuscito oppure deadlock 1213 su una sessione)' 'OSS' ("{0} round: entrambe riuscite {1}, deadlock {2}, altri esiti {3}" -f $plan.Count, $tally.both, $tally.deadlock, $tally.other)
    } finally { Clear-Carts }
}

# ---------- P8: ultima disponibilita (9 su 9) attraverso la routine reale: A COMMITTA, B deve essere rifiutata ----------
if (Want 'P8') {
    $dirty8 = $false
    try {
        $r = Run-Sql 'setup8' ($guard + "`n" + (Cart-Insert 19832 18 9 1 10) + "`n" + (Cart-Insert 19833 18 9 10 12) + "`n") -Write
        if ($r.Code -ne 0) { throw ('SETUP8_FAILED: ' + ($r.Lines -join ' | ')) }
        $dirty8 = $true
        $pair = Run-Pair 'p8' (Order-Session 'A' 19832 1 1 $HoldSeconds 'ks_conc_p8' '' -Commit) (Order-Session 'B' 19833 2 2 0) 'ks_conc_p8'
        $aCall = Read-Json $pair.A 'A_CALL'; $bCall = Read-Json $pair.B 'B_CALL'; $bErr = Err-Of $pair.B
        Add-Result 'P8' 'A prenota le 9 unita disponibili e committa' $(if ($aCall -and ([int]$aCall.docNumber -eq [int]$aCall.stored)) { 'OK' } else { 'FAIL' }) $(if ($aCall) { "numero OUT=$($aCall.docNumber) memorizzato=$($aCall.stored)" } else { 'nessun esito: ' + (Err-Of $pair.A) })
        $minMs = [Math]::Max(3000, 0.5 * $HoldSeconds * 1000)
        Add-Result 'P8' 'B rifiutata con ORDER_INVENTORY_UNAVAILABLE e nessun documento creato da B' $(if ((-not $bCall) -and ("$bErr" -match 'ORDER_INVENTORY_UNAVAILABLE')) { 'OK' } else { 'FAIL' }) $(if ($bCall) { "B ha creato il documento n.$($bCall.docNumber)" } else { "$bErr" })
        Add-Result 'P8' 'B ha atteso il commit di A prima di essere rifiutata' $(if ($pair.BMs -ge $minMs) { 'OK' } else { 'FAIL' }) ("durata processo B {0} ms (minimo atteso {1} ms; comprende l'avvio del client)" -f $pair.BMs, [Math]::Round($minMs))
        $mid = Get-State
        $okStock = ([decimal]$mid.r18 -eq ([decimal]$baseline.r18 + 9)) -and (([int]$mid.docs - [int]$baseline.docs) -eq 1)
        Add-Result 'P8' 'nessuna vendita oltre giacenza: impegnata = baseline + 9 (giacenza 10) e un solo documento in piu' $(if ($okStock) { 'OK' } else { 'FAIL' }) ("impegnata TC 18 = $($mid.r18) (baseline $($baseline.r18)); documenti +$([int]$mid.docs - [int]$baseline.docs)")
    } finally {
        if ($dirty8) { Cleanup-Committed $baseline }
        Clear-Carts
    }
}

$final = Get-State
$same = Same-State $final $baseline
'FINAL_STATE_EQUALS_BASELINE=' + $same + ' ' + ($final | ConvertTo-Json -Compress)
Add-Result 'ALL' 'stato finale uguale alla baseline' $(if ($same) { 'OK' } else { 'FAIL' }) ($final | ConvertTo-Json -Compress)
$count = @{ OK = 0; FAIL = 0; OSS = 0 }
foreach ($x in $results) { $count[$x.V]++ }
'CONCURRENCY_CHECKS=' + $results.Count + ' OK=' + $count.OK + ' FAIL=' + $count.FAIL + ' OSS=' + $count.OSS
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
