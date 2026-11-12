[CmdletBinding()]
param(
    [string]$Runner,
    [string]$ReportPath,
    [string]$OnlyCase,
    [switch]$ListOnly,
    # Nome della procedura sotto prova. Il default e la routine reale; un altro nome serve a provare una variante
    # (per esempio una copia ombra creata dall'account del LAB) con gli stessi casi, senza toccare la routine reale.
    [ValidatePattern('^[A-Za-z0-9_]+$')][string]$Procedure = 'Carrello_Documento'
)

# KS-C01 matrice SQL ordine sul LAB LOCALE (127.0.0.1:13317, schema sintetico). Per ogni caso uno script separato:
# guardia (UUID, porta, schema, carrello vuoto, dizionario iva atteso), START TRANSACTION, fixture sintetiche,
# CALL Carrello_Documento reale, SELECT che OSSERVA (JSON), ROLLBACK, SELECT di ripristino.
# L'oracolo e calcolato qui con aritmetica decimal (arrotondamento half-away-from-zero) e confrontato con le osservazioni.
# Nessun commit: ogni modifica (anche righe iva, articoli.iva, carrello) e annullata dal ROLLBACK o dalla chiusura sessione.
# Esito per controllo: OK (uguale all'oracolo entro 0.0005), DEV (differenza fino a 0.011), FAIL (oltre), OSS (osservazione senza oracolo).
# Richiede Windows PowerShell 5.1 e l'account dedicato del LAB (vedi AGENTS). Mai su produzione.
$ErrorActionPreference = 'Stop'
if (-not $Runner) { $Runner = Join-Path $PSScriptRoot 'Invoke-KeepStoreLabSql.ps1' }
$inv = [Globalization.CultureInfo]::InvariantCulture
function Num($v) { if ($null -eq $v) { return 'NULL' } return ([decimal]$v).ToString($inv) }
function Round2([decimal]$v) { return [Math]::Round($v, 2, [MidpointRounding]::AwayFromZero) }

$company = @{ 1 = 1; 2 = 2 }
$tenant = @{
    1 = @{ User = 1; Login = 19832; Company = 1; Listino = 1; UnitNet = 10 }
    2 = @{ User = 2; Login = 19833; Company = 2; Listino = 10; UnitNet = 12 }
}

function Row([int]$Tc, $Qnt, $Net, [int]$RcId = -1, $RcVal = -1, $ExId = -1, $ExVal = -1, $Nl = 0) {
    return @{ Tc = $Tc; Qnt = [decimal]$Qnt; Net = [decimal]$Net; RcId = $RcId; RcVal = $RcVal; ExId = $ExId; ExVal = $ExVal; Nl = $Nl }
}
function Case([string]$Id, [string]$Title, [int]$T, $Rows, [hashtable]$O = @{}) {
    $c = @{
        Id = $Id; Title = $Title; T = $T; Rows = @($Rows)
        Rc = 0; ArticleIvaId = 1; ArticleRate = 22; Synth = @()
        Ship = 0; Ins = 0; Pay = 0; Round = 0; ShipVat = 22
        BDesc = ''; BCode = ''; BTot = 0; BIdIva = 1; BVal = 22
        TipoDoc = 4; PayType = 1; Login = $null; Expect = 'ok'; SyncListiniIva = $true; Discord = $false
    }
    foreach ($k in $O.Keys) { $c[$k] = $O[$k] }
    return $c
}

$cases = New-Object System.Collections.Generic.List[object]
# A - aliquote
$cases.Add((Case 'A01' 'ordinario 22% q2 (regressione)' 1 @(Row -1 2 10)))
$cases.Add((Case 'A02' 'ordinario 22% q2, tenant 2 listino 10' 2 @(Row -1 2 12)))
$cases.Add((Case 'A03' 'aliquota 10% q3 a 9.99' 1 @(Row -1 3 9.99) @{ ArticleIvaId = 9010; ArticleRate = 10; Synth = @(@{ Id = 9010; Rate = 10 }) }))
$cases.Add((Case 'A04' 'aliquota 10% q3 a 9.99, tenant 2' 2 @(Row -1 3 9.99) @{ ArticleIvaId = 9010; ArticleRate = 10; Synth = @(@{ Id = 9010; Rate = 10 }) }))
$cases.Add((Case 'A05' 'aliquota 5% q1 a 0.50 (mezzo centesimo 0.025)' 1 @(Row -1 1 0.5) @{ ArticleIvaId = 9005; ArticleRate = 5; Synth = @(@{ Id = 9005; Rate = 5 }) }))
$cases.Add((Case 'A06' 'aliquota 4% q7 a 19.99' 1 @(Row -1 7 19.99) @{ ArticleIvaId = 9004; ArticleRate = 4; Synth = @(@{ Id = 9004; Rate = 4 }) }))
$cases.Add((Case 'A07' 'aliquota 4% q7 a 19.99, tenant 2' 2 @(Row -1 7 19.99) @{ ArticleIvaId = 9004; ArticleRate = 4; Synth = @(@{ Id = 9004; Rate = 4 }) }))
# B - regimi
$cases.Add((Case 'B01' 'reverse charge (regressione)' 1 @(Row -1 2 10 701 0) @{ Rc = 1 }))
$cases.Add((Case 'B02' 'esenzione tenant 2 (regressione)' 2 @(Row -1 2 12 -1 -1 702 0)))
$cases.Add((Case 'B03' 'RC prima di esenzione (regressione)' 1 @(Row -1 2 10 701 0 702 0) @{ Rc = 1 }))
$cases.Add((Case 'B04' 'reverse charge tenant 2' 2 @(Row -1 2 12 701 0) @{ Rc = 1 }))
$cases.Add((Case 'B05' 'esenzione tenant 1' 1 @(Row -1 2 10 -1 -1 702 0)))
$cases.Add((Case 'B06' 'sentinella idEsenzioneIva = 0 (id non nel dizionario)' 1 @(Row -1 1 10 -1 -1 0 0) @{ Expect = 'observe' }))
$cases.Add((Case 'B07' 'sentinella idEsenzioneIva NULL' 1 @(Row -1 1 10 -1 -1 $null $null)))
$cases.Add((Case 'B08' 'flag RC=1 ma riga senza IdIvaRC' 1 @(Row -1 1 10) @{ Rc = 1 }))
$cases.Add((Case 'B09' 'flag RC=0 con IdIvaRC sulla riga (ignorato)' 1 @(Row -1 1 10 701 0)))
$cases.Add((Case 'B10' 'id esenzione 9999 inesistente nel dizionario, snapshot 0' 1 @(Row -1 1 10 -1 -1 9999 0) @{ Expect = 'observe' }))
# C - composizione
$cases.Add((Case 'C01' 'due righe: ordinaria + esente' 1 @((Row -1 1 10), (Row 18 1 10 -1 -1 702 0))))
$cases.Add((Case 'C02' 'due righe con 3 decimali, tenant 2' 2 @((Row -1 2 0.333), (Row 18 3 0.667))))
$cases.Add((Case 'C03' 'tre righe, stesso TC su due righe' 1 @((Row -1 1 4.1), (Row -1 2 4.1), (Row 18 1 7.77))))
$cases.Add((Case 'C04' 'listini misti 1 e 10 nello stesso carrello (listino di testata dalla prima riga del cursore)' 1 @((Row -1 1 10 -1 -1 -1 -1 1), (Row 18 1 12 -1 -1 -1 -1 10)) @{ Expect = 'observe' }))
# D - arrotondamento al 22%
$cases.Add((Case 'D01' 'netto 0.01 q1' 1 @(Row -1 1 0.01)))
$cases.Add((Case 'D02' 'netto 0.333 q3' 1 @(Row -1 3 0.333)))
$cases.Add((Case 'D03' 'netto 1.15 q1' 1 @(Row -1 1 1.15)))
$cases.Add((Case 'D04' 'netto 0.115 q9' 1 @(Row -1 9 0.115)))
$cases.Add((Case 'D05' 'tre righe da 0.45 con quantita distinte' 1 @((Row -1 1 0.45), (Row 18 2 0.45), (Row -1 3 0.45))))
# E - costi
$cases.Add((Case 'E01' 'spedizione 5 e pagamento 1.65 (parita browser)' 1 @(Row -1 1 10) @{ Ship = 5; Pay = 1.65 }))
$cases.Add((Case 'E02' 'assicurazione 2 e spedizione 5' 1 @(Row -1 1 10) @{ Ins = 2; Ship = 5 }))
$cases.Add((Case 'E03' 'arrotondamento -0.02 e pagamento 0.71' 1 @(Row -1 1 10) @{ Round = -0.02; Pay = 0.71 }))
$cases.Add((Case 'E04' 'spedizione 7 e pagamento 0.71, tenant 2' 2 @(Row -1 1 12) @{ Ship = 7; Pay = 0.71 }))
# F - buono sconto
$cases.Add((Case 'F01' 'buono sconto -5 con IVA 22' 1 @(Row -1 2 10) @{ BDesc = 'KS BUONO'; BCode = 'KSB'; BTot = -5; BIdIva = 1; BVal = 22 }))
$cases.Add((Case 'F02' 'buono POSITIVO +5 (nessuna riga sconto, totale modificato)' 1 @(Row -1 2 10) @{ BDesc = 'KS BUONO POS'; BCode = 'KSP'; BTot = 5; BIdIva = 1; BVal = 22 }))
# G - snapshot diverso dal dizionario
$cases.Add((Case 'G01' 'snapshot esenzione 5% ma id 702 (dizionario 0%)' 1 @(Row -1 1 10 -1 -1 702 5) @{ Discord = $true }))
$cases.Add((Case 'G03' 'id IVA da articoli_listini (22%) diverso dall''aliquota dell''articolo (10%)' 1 @(Row -1 3 9.99) @{ ArticleIvaId = 9010; ArticleRate = 10; Synth = @(@{ Id = 9010; Rate = 10 }); SyncListiniIva = $false; Expect = 'observe' }))
$cases.Add((Case 'G02' 'snapshot esenzione NULL con id 702' 1 @(Row -1 1 10 -1 -1 702 $null) @{ Expect = 'observe' }))
# H - giacenza, quantita e negativi
$cases.Add((Case 'N01' 'giacenza insufficiente (TC 18 q10, disponibili 9)' 1 @(Row 18 10 10) @{ Expect = 'error:ORDER_INVENTORY_UNAVAILABLE' }))
$cases.Add((Case 'N02' 'limite giacenza (TC 18 q9)' 1 @(Row 18 9 10)))
$cases.Add((Case 'N03' 'carrello vuoto' 1 @() @{ Expect = 'error:ORDER_INVENTORY_EMPTY_CART' }))
$cases.Add((Case 'N04' 'quantita con 6 decimali' 1 @(Row -1 1.123456 10) @{ Expect = 'error:ORDER_INVENTORY_INVALID' }))
$cases.Add((Case 'N05' 'quantita frazionaria 1.5' 1 @(Row -1 1.5 10)))
$cases.Add((Case 'N06' 'tipo documento senza Web/Impegna (999)' 1 @(Row -1 1 10) @{ TipoDoc = 999; Expect = 'error:ORDER_INVENTORY_INVALID' }))
$cases.Add((Case 'N07' 'login inesistente 99999 con riga carrello' 1 @(Row -1 1 10) @{ Login = 99999; Expect = 'observe' }))
$cases.Add((Case 'N08' 'quantita zero' 1 @(Row -1 0 10) @{ Expect = 'error:ORDER_INVENTORY_INVALID' }))
$cases.Add((Case 'N09' 'riga con listino 77 senza prezzo in vCarrello' 1 @(Row -1 1 10 -1 -1 -1 -1 77) @{ Expect = 'observe' }))
$cases.Add((Case 'N10' 'tipo pagamento inesistente 999' 1 @(Row -1 1 10) @{ PayType = 999; Expect = 'observe' }))
$cases.Add((Case 'N11' 'prenotazione parziale: TC -1 riesce, TC 18 q10 fallisce' 1 @((Row -1 1 10), (Row 18 10 10)) @{ Expect = 'error:ORDER_INVENTORY_UNAVAILABLE' }))
$cases.Add((Case 'N12' 'quantita negativa compensata da positiva sullo stesso TC' 1 @((Row -1 -1 10), (Row -1 2 10)) @{ Expect = 'observe' }))
$cases.Add((Case 'N13' 'costo spedizione NULL' 1 @(Row -1 1 10) @{ Ship = $null; Expect = 'observe' }))
$cases.Add((Case 'N14' 'due righe carrello identiche (indice unico UniqueIDX di documentirighe)' 1 @((Row -1 1 10), (Row -1 1 10)) @{ Expect = 'observe' }))

$selected = @($cases | Where-Object { (-not $OnlyCase) -or ($_.Id -match $OnlyCase) })
if ($ListOnly) { foreach ($c in $selected) { '{0}  {1}  [{2}]' -f $c.Id, $c.Title, $c.Expect }; "cases=" + $selected.Count; return }

function Build-Sql($c) {
    $t = $tenant[$c.T]
    $login = if ($c.Login) { $c.Login } else { $t.Login }
    $fx = New-Object System.Collections.Generic.List[string]
    foreach ($s in $c.Synth) { $fx.Add(("INSERT INTO iva(id,Valore,Descrizione) VALUES({0},{1},'KS MATRIX {1}');" -f $s.Id, (Num $s.Rate))) }
    # L'id IVA della riga documento viene da articoli_listini.iva (via varticolilistini), l'aliquota del piede da articoli.iva (via varticoli_iva).
    if ($c.ArticleIvaId -ne 1) {
        $fx.Add(("UPDATE articoli SET iva={0} WHERE id=1;" -f $c.ArticleIvaId))
        if ($c.SyncListiniIva) { $fx.Add(("UPDATE articoli_listini SET iva={0} WHERE ArticoliId=1;" -f $c.ArticleIvaId)) }
    }
    $articleRate = [decimal]$c.ArticleRate
    foreach ($r in $c.Rows) {
        $nl = if ($r.Nl -ne 0) { $r.Nl } else { $t.Listino }
        $gross = $r.Net * (1 + $articleRate / 100)
        $fx.Add(("INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) VALUES({0},1,{1},'KS-LAB-ARTICLE','KS MATRIX {2}',{3},{4},{5},{6},{7},{8},'KS MATRIX RC',{9},{10},'KS MATRIX EX');" -f `
            $login, $r.Tc, $c.Id, (Num $r.Qnt), $nl, (Num $r.Net), (Num $gross), (Num $r.RcId), (Num $r.RcVal), (Num $r.ExId), (Num $r.ExVal)))
    }
    $head = @'
SET @ks_ok=(@@server_uuid='1167ebae-d0c0-11f1-b348-9c7bef540c10' AND @@port=13317 AND DATABASE()='keepstore_regorder_lab_20261025' AND (SELECT COUNT(*) FROM carrello)=0 AND (SELECT COUNT(*) FROM iva)=3 AND (SELECT COUNT(*) FROM iva WHERE (id=1 AND Valore=22) OR (id IN(701,702) AND Valore=0))=3 AND (SELECT iva FROM articoli WHERE id=1)=1 AND (SELECT COUNT(*) FROM articoli_listini WHERE ArticoliId=1 AND iva<>1)=0);
SET @ks_guard=IF(@ks_ok,'SELECT ''MATRIX_TARGET_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_WRONG_MATRIX_TARGET');
PREPARE ks_g FROM @ks_guard;EXECUTE ks_g;DEALLOCATE PREPARE ks_g;
START TRANSACTION;
SET @b_docs=(SELECT COUNT(*) FROM documenti),@b_num=(SELECT COALESCE(MAX(NDocumento),0) FROM documenti WHERE TipoDocumentiId=4 AND YEAR(DataDocumento)=YEAR(CURDATE())),@b_r1=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@b_r18=(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18),@b_g1=(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),@b_g18=(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18);
SET @addr=(SELECT UtentiIndirizziId FROM vlogin WHERE id=__LOGIN__);
'@
    $call = "CALL Carrello_Documento($login,$($c.TipoDoc),$($c.PayType),1,@addr,$(Num $c.Ins),$(Num $c.Ship),$(Num $c.Round),$(Num $c.Pay),'KS MATRIX $($c.Id)',$($c.Rc),$(Num $c.ShipVat),1,'$($c.BDesc)','$($c.BCode)',$(Num $c.BTot),$($c.BIdIva),$(Num $c.BVal),@doc_number);"
    $obs = @'
SET @created=(SELECT MAX(id) FROM documenti);
SELECT 'OBS',JSON_OBJECT('docNumber',@doc_number,'docsDelta',(SELECT COUNT(*) FROM documenti)-@b_docs,'numDelta',@doc_number-@b_num,
 'doc',(SELECT JSON_OBJECT('azienda',AziendeId,'listino',Listino,'utente',UtentiId,'pay',PagamentiTipoId,'web',Ordine_Web) FROM documenti WHERE id=@created),
 'rows',(SELECT JSON_ARRAYAGG(JSON_OBJECT('tc',q.TCId,'qnt',q.Qnt,'prezzo',q.prezzo,'importo',q.importo,'iva',q.iva,'rate',q.rate,'gross',q.gross,'tipo',q.tiporiga)) FROM (SELECT r.id AS rid,r.TCId,r.Qnt,r.prezzo,r.importo,r.iva,i.Valore AS rate,v.ImportoIvato AS gross,r.tiporiga FROM documentirighe r LEFT JOIN iva i ON i.id=r.iva LEFT JOIN vdocumentirighe v ON v.id=r.id WHERE r.DocumentiId=@created ORDER BY r.id LIMIT 1000) q),
 'foot',(SELECT JSON_OBJECT('totImponibile',TotImponibile,'totMerce',TotMerce,'totIva',TotIva,'totale',TotaleDocumento,'ass',costoassicurazione,'sped',costospedizione,'pag',costopagamento) FROM documentipie WHERE DocumentiId=@created),
 'res1',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)-@b_r1,'res18',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18)-@b_r18,
 'phys1',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)-@b_g1,'phys18',(SELECT Giacenza FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18)-@b_g18,
 'cartLeft',(SELECT COUNT(*) FROM carrello));
ROLLBACK;
SELECT 'RESTORED',JSON_OBJECT('docs',(SELECT COUNT(*) FROM documenti)=@b_docs,'res1',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1)=@b_r1,'res18',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18)=@b_r18,'cart',(SELECT COUNT(*) FROM carrello)=0,'iva',(SELECT COUNT(*) FROM iva)=3,'artIva',(SELECT iva FROM articoli WHERE id=1)=1,'listIva',(SELECT COUNT(*) FROM articoli_listini WHERE ArticoliId=1 AND iva<>1)=0);
'@
    return ($head.Replace('__LOGIN__', [string]$login) + ($fx -join "`n") + "`n" + $call + "`n" + $obs)
}

function Get-Expected($c) {
    $t = $tenant[$c.T]
    $dict = @{ 1 = [decimal]22; 701 = [decimal]0; 702 = [decimal]0 }
    foreach ($s in $c.Synth) { $dict[[int]$s.Id] = [decimal]$s.Rate }
    $imp = [decimal]0; $vatRaw = [decimal]0; $rows = @(); $res = @{ -1 = [decimal]0; 18 = [decimal]0 }
    foreach ($r in $c.Rows) {
        $net = $r.Qnt * $r.Net
        if (($c.Rc -eq 1) -and ($null -ne $r.RcId) -and ($r.RcId -gt -1)) { $id = $r.RcId; $snap = [decimal]$r.RcVal }
        elseif (($null -ne $r.ExId) -and ($r.ExId -gt -1)) { $id = $r.ExId; $snap = [decimal]$r.ExVal }
        else { $id = $c.ArticleIvaId; $snap = [decimal]$c.ArticleRate }
        $imp += $net
        $vatRaw += $net * $snap / 100
        $dictRate = $null; if ($dict.ContainsKey([int]$id)) { $dictRate = $dict[[int]$id] }
        $rows += @{ Tc = $r.Tc; Qnt = $r.Qnt; Prezzo = $r.Net; Importo = $net; Iva = [int]$id; Rate = $dictRate }
        $res[[int]$r.Tc] += $r.Qnt
    }
    $vatRaw += ([decimal]$c.Ship * [decimal]$c.ShipVat / 100) + ([decimal]$c.Ins * [decimal]$c.ShipVat / 100)
    $b = [decimal]$c.BTot
    $total = (Round2 $imp) + (Round2 $vatRaw) + [decimal]$c.Ship + [decimal]$c.Ins + [decimal]$c.Pay + [decimal]$c.Round + $b + ($b / 100 * [decimal]$c.BVal)
    return @{ Rows = $rows; TotMerce = (Round2 $imp); TotIvaRaw = $vatRaw; TotImponibile = $imp + [decimal]$c.Ship; Totale = $total; Res = $res; Company = $t.Company; Listino = $t.Listino; Imp = $imp }
}

$script:findings = New-Object System.Collections.Generic.List[string]
function Judge([string]$name, $obs, [decimal]$exp, $res) {
    if ($null -eq $obs) { $res.Add(@{ N = $name; V = 'FAIL'; D = "assente (atteso $exp)" }); return }
    $d = [Math]::Abs([decimal]$obs - $exp)
    $v = if ($d -le 0.0005) { 'OK' } elseif ($d -le 0.011) { 'DEV' } else { 'FAIL' }
    $res.Add(@{ N = $name; V = $v; D = ("osservato {0} atteso {1}" -f ([decimal]$obs).ToString($inv), $exp.ToString($inv)) })
}

function Get-State {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('ks-matrix-' + $PID)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $file = Join-Path $dir 'state.sql'
    $sql = @'
SELECT 'STATE',JSON_OBJECT('docs',(SELECT COUNT(*) FROM documenti),'maxId',(SELECT MAX(id) FROM documenti),'r1',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=-1),'r18',(SELECT Impegnata FROM articoli_giacenze WHERE ArticoliId=1 AND TCId=18),'cart',(SELECT COUNT(*) FROM carrello),'iva',(SELECT COUNT(*) FROM iva),'artIva',(SELECT iva FROM articoli WHERE id=1),'listIva',(SELECT COUNT(*) FROM articoli_listini WHERE ArticoliId=1 AND iva<>1),'righe',(SELECT COUNT(*) FROM documentirighe),'pie',(SELECT COUNT(*) FROM documentipie));
'@
    [IO.File]::WriteAllText($file, $sql, (New-Object Text.UTF8Encoding($false)))
    $out = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $Runner -SqlFile $file 2>&1 | ForEach-Object { "$_" }
    $line = @($out) | Where-Object { $_ -match '^STATE\t\{' } | Select-Object -First 1
    if (-not $line) { throw ('STATE_READ_FAILED: ' + ($out -join ' | ')) }
    return ($line.Substring(6) | ConvertFrom-Json)
}
function Same-State($a, $b) {
    foreach ($k in @('docs', 'maxId', 'r1', 'r18', 'cart', 'iva', 'artIva', 'listIva', 'righe', 'pie')) { if ([decimal]$a.$k -ne [decimal]$b.$k) { return $false } }
    return $true
}

function Invoke-Case($c) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('ks-matrix-' + $PID)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $file = Join-Path $dir ($c.Id + '.sql')
    [IO.File]::WriteAllText($file, (Build-Sql $c).Replace('CALL Carrello_Documento(', 'CALL ' + $Procedure + '('), (New-Object Text.UTF8Encoding($false)))
    $out = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $Runner -SqlFile $file -Write 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    Remove-Item -LiteralPath $file -Force
    $text = @($out)
    $obsLine = $text | Where-Object { $_ -match '^OBS\t\{' } | Select-Object -First 1
    $resLine = $text | Where-Object { $_ -match '^RESTORED\t\{' } | Select-Object -First 1
    $errLine = ($text | Where-Object { $_ -like 'stderr:*' } | Select-Object -First 1)
    $res = New-Object System.Collections.Generic.List[object]
    if ($code -ne 0) {
        # La sessione e terminata con un errore: l'annullamento dipende dalla chiusura della connessione. Lo verifica una seconda sessione.
        $post = Get-State
        $res.Add(@{ N = 'stato dopo errore (seconda sessione)'; V = $(if (Same-State $post $script:baseline) { 'OK' } else { 'FAIL' }); D = ($post | ConvertTo-Json -Compress) })
    }
    $o = $null; if ($obsLine) { $o = ($obsLine.Substring(4)) | ConvertFrom-Json }
    $restored = $null; if ($resLine) { $restored = ($resLine.Substring(9)) | ConvertFrom-Json }
    if ($c.Expect -like 'error:*') {
        $want = $c.Expect.Substring(6)
        if ($code -ne 0 -and $errLine -and $errLine.Contains($want)) { $res.Add(@{ N = 'errore atteso'; V = 'OK'; D = $want }) }
        else { $res.Add(@{ N = 'errore atteso'; V = 'FAIL'; D = ("atteso $want; exit=$code; " + $errLine + $(if ($o) { ' (documento creato)' } else { '' })) }) }
        return @{ Case = $c; Res = $res; Obs = $o; Err = $errLine }
    }
    if (-not $o) {
        if ($c.Expect -eq 'observe') { $res.Add(@{ N = 'esito'; V = 'OSS'; D = ("errore: " + $errLine) }) }
        else { $res.Add(@{ N = 'esecuzione'; V = 'FAIL'; D = ("nessuna osservazione; exit=$code; " + $errLine) }) }
        return @{ Case = $c; Res = $res; Obs = $null; Err = $errLine }
    }
    $rows = @($o.rows)
    if ($c.Expect -eq 'observe') {
        $res.Add(@{ N = 'esito'; V = 'OSS'; D = ("documento creato: azienda={0} utente={1} listino={2} righe={3} qnt=[{4}] importo=[{5}] iva=[{6}] gross=[{7}] impegno1={8} impegno18={9} | piede imponibile={10} merce={11} iva={12} totale={13}" -f `
            $o.doc.azienda, $o.doc.utente, $o.doc.listino, $rows.Count, (($rows | ForEach-Object { $_.qnt }) -join ','), (($rows | ForEach-Object { $_.importo }) -join ','), (($rows | ForEach-Object { $_.iva }) -join ','), (($rows | ForEach-Object { $_.gross }) -join ','), $o.res1, $o.res18, $o.foot.totImponibile, $o.foot.totMerce, $o.foot.totIva, $o.foot.totale) })
    } else {
        $e = Get-Expected $c
        $res.Add(@{ N = 'documenti creati'; V = $(if ($o.docsDelta -eq 1) { 'OK' } else { 'FAIL' }); D = "delta=$($o.docsDelta)" })
        $res.Add(@{ N = 'numerazione +1'; V = $(if ($o.numDelta -eq 1) { 'OK' } else { 'FAIL' }); D = "delta=$($o.numDelta)" })
        $res.Add(@{ N = 'azienda del login'; V = $(if ([int]$o.doc.azienda -eq $e.Company) { 'OK' } else { 'FAIL' }); D = "azienda=$($o.doc.azienda) atteso $($e.Company)" })
        $res.Add(@{ N = 'listino dalla riga carrello'; V = $(if ([int]$o.doc.listino -eq $e.Listino) { 'OK' } else { 'FAIL' }); D = "listino=$($o.doc.listino) atteso $($e.Listino)" })
        $rowsA = @($rows | Where-Object { $_.tipo -eq 'A' })
        $rowsD = @($rows | Where-Object { $_.tipo -eq 'D' })
        $wantD = $(if ([decimal]$c.BTot -lt 0) { 1 } else { 0 })
        $res.Add(@{ N = 'righe merce'; V = $(if ($rowsA.Count -eq $c.Rows.Count) { 'OK' } else { 'FAIL' }); D = "righe=$($rowsA.Count) attese $($c.Rows.Count)" })
        $res.Add(@{ N = 'riga sconto (solo buono negativo)'; V = $(if ($rowsD.Count -eq $wantD) { 'OK' } else { 'FAIL' }); D = "righe sconto=$($rowsD.Count) attese $wantD" })
        if (($wantD -eq 1) -and ($rowsD.Count -eq 1)) {
            Judge 'riga sconto importo' $rowsD[0].importo ([decimal]$c.BTot) $res
            $res.Add(@{ N = 'riga sconto id IVA'; V = $(if ([int]$rowsD[0].iva -eq [int]$c.BIdIva) { 'OK' } else { 'FAIL' }); D = "iva=$($rowsD[0].iva) atteso $($c.BIdIva)" })
        }
        $used = @{}
        $matched = @()
        for ($i = 0; $i -lt $e.Rows.Count; $i++) {
            $er = $e.Rows[$i]; $or = $null
            for ($j = 0; $j -lt $rowsA.Count; $j++) {
                if ($used.ContainsKey($j)) { continue }
                if (([int]$rowsA[$j].tc -eq $er.Tc) -and ([Math]::Abs([decimal]$rowsA[$j].qnt - $er.Qnt) -le 0.0005)) { $or = $rowsA[$j]; $used[$j] = $true; break }
            }
            if ($null -eq $or) { $res.Add(@{ N = "riga$($i+1) presente"; V = 'FAIL'; D = "nessuna riga documento con TC $($er.Tc) e quantita $($er.Qnt)" }); continue }
            $matched += $or
            $res.Add(@{ N = "riga$($i+1) id IVA"; V = $(if ([int]$or.iva -eq $er.Iva) { 'OK' } else { 'FAIL' }); D = "iva=$($or.iva) atteso $($er.Iva)" })
            Judge "riga$($i+1) importo netto" $or.importo $er.Importo $res
            if ($null -ne $er.Rate) {
                Judge "riga$($i+1) aliquota da dizionario" $or.rate $er.Rate $res
                Judge "riga$($i+1) lordo da vista" $or.gross ($er.Importo * (1 + $er.Rate / 100)) $res
            }
        }
        Judge 'TotMerce' $o.foot.totMerce $e.TotMerce $res
        Judge 'TotIva (somma grezza)' $o.foot.totIva $e.TotIvaRaw $res
        Judge 'TotaleDocumento' $o.foot.totale $e.Totale $res
        $ti = [decimal]$o.foot.totImponibile
        if ($c.Ins -gt 0) {
            $res.Add(@{ N = 'TotImponibile con assicurazione'; V = $(if ([Math]::Abs($ti - $e.TotImponibile) -le 0.0005) { 'OSS' } else { 'DEV' }); D = ("TotImponibile={0}; imponibile+spedizione={1}; assicurazione={2} tassata nel TotIva ma {3} in TotImponibile" -f $ti.ToString($inv), $e.TotImponibile.ToString($inv), $c.Ins, $(if ([Math]::Abs($ti - $e.TotImponibile) -le 0.0005) { 'non inclusa' } else { 'inclusa' })) })
        } else { Judge 'TotImponibile' $ti $e.TotImponibile $res }
        # Coerenza con quanto il cliente vede: somma dei lordi di riga arrotondati al centesimo (vista) contro il totale merce+IVA del piede.
        $sumGrossRounded = [decimal]0; $grossMissing = $false
        foreach ($r in $matched) { if ($null -ne $r.gross) { $sumGrossRounded += (Round2 ([decimal]$r.gross)) } else { $grossMissing = $true } }
        $footGoods = [decimal]$o.foot.totale - [decimal]$c.Ship - [decimal]$c.Ins - [decimal]$c.Pay - [decimal]$c.Round - [decimal]$c.BTot - ([decimal]$c.BTot / 100 * [decimal]$c.BVal) - (Round2 (([decimal]$c.Ship + [decimal]$c.Ins) * [decimal]$c.ShipVat / 100))
        if ($c.Discord) {
            $res.Add(@{ N = 'snapshot carrello diverso dal dizionario'; V = 'OSS'; D = ("merce+IVA del piede={0}; somma lordi di riga dalla vista={1}: il piede usa lo snapshot del carrello, la vista usa il dizionario iva" -f $footGoods.ToString($inv), $sumGrossRounded.ToString($inv)) })
        } elseif ($grossMissing) {
            $res.Add(@{ N = 'coerenza piede vs lordi di riga'; V = 'OSS'; D = 'lordo di riga non calcolabile dalla vista (id IVA assente nel dizionario)' })
        } else {
            $cents = [Math]::Abs($footGoods - $sumGrossRounded)
            $res.Add(@{ N = 'coerenza piede vs somma lordi di riga arrotondati'; V = $(if ($cents -le 0.0005) { 'OK' } elseif ($cents -le 0.011) { 'DEV' } else { 'FAIL' }); D = ("merce+IVA del piede={0}; somma lordi di riga arrotondati={1}; differenza={2}" -f $footGoods.ToString($inv), $sumGrossRounded.ToString($inv), $cents.ToString($inv)) })
        }
        $res.Add(@{ N = 'impegno TC -1'; V = $(if ([Math]::Abs([decimal]$o.res1 - $e.Res[-1]) -le 0.0005) { 'OK' } else { 'FAIL' }); D = "delta=$($o.res1) atteso $($e.Res[-1])" })
        $res.Add(@{ N = 'impegno TC 18'; V = $(if ([Math]::Abs([decimal]$o.res18 - $e.Res[18]) -le 0.0005) { 'OK' } else { 'FAIL' }); D = "delta=$($o.res18) atteso $($e.Res[18])" })
        $res.Add(@{ N = 'giacenza fisica invariata'; V = $(if (([decimal]$o.phys1 -eq 0) -and ([decimal]$o.phys18 -eq 0)) { 'OK' } else { 'FAIL' }); D = "phys1=$($o.phys1) phys18=$($o.phys18)" })
        $res.Add(@{ N = 'carrello svuotato'; V = $(if ([int]$o.cartLeft -eq 0) { 'OK' } else { 'FAIL' }); D = "righe rimaste=$($o.cartLeft)" })
    }
    $okRestore = $restored -and ($restored.docs -eq 1) -and ($restored.res1 -eq 1) -and ($restored.res18 -eq 1) -and ($restored.cart -eq 1) -and ($restored.iva -eq 1) -and ($restored.artIva -eq 1) -and ($restored.listIva -eq 1)
    $res.Add(@{ N = 'ripristino dopo ROLLBACK'; V = $(if ($okRestore) { 'OK' } else { 'FAIL' }); D = $(if ($restored) { ($restored | ConvertTo-Json -Compress) } else { 'nessuna lettura' }) })
    return @{ Case = $c; Res = $res; Obs = $o; Err = $errLine }
}

$script:baseline = Get-State
'BASELINE ' + ($script:baseline | ConvertTo-Json -Compress)
$results = New-Object System.Collections.Generic.List[object]
foreach ($c in $selected) {
    $r = Invoke-Case $c
    $results.Add($r)
    $counts = @{ OK = 0; DEV = 0; FAIL = 0; OSS = 0 }
    foreach ($x in $r.Res) { $counts[$x.V]++ }
    $verdict = if ($counts.FAIL -gt 0) { 'FAIL' } elseif ($counts.DEV -gt 0) { 'DEV' } elseif ($counts.OSS -gt 0) { 'OSS' } else { 'OK' }
    ('{0,-4} {1,-5} ok={2} dev={3} fail={4} oss={5}  {6}' -f $c.Id, $verdict, $counts.OK, $counts.DEV, $counts.FAIL, $counts.OSS, $c.Title)
    foreach ($x in $r.Res) { if ($x.V -ne 'OK') { '       [{0}] {1}: {2}' -f $x.V, $x.N, $x.D } }
}
$final = Get-State
'FINAL_STATE_EQUALS_BASELINE=' + (Same-State $final $script:baseline) + ' ' + ($final | ConvertTo-Json -Compress)
$all = @($results | ForEach-Object { $_.Res } | ForEach-Object { $_ })
'MATRIX_CASES=' + $results.Count + ' CHECKS=' + $all.Count + ' OK=' + @($all | Where-Object { $_.V -eq 'OK' }).Count + ' DEV=' + @($all | Where-Object { $_.V -eq 'DEV' }).Count + ' FAIL=' + @($all | Where-Object { $_.V -eq 'FAIL' }).Count + ' OSS=' + @($all | Where-Object { $_.V -eq 'OSS' }).Count
if ($ReportPath) {
    $lines = foreach ($r in $results) { '## ' + $r.Case.Id + ' ' + $r.Case.Title; foreach ($x in $r.Res) { '- [' + $x.V + '] ' + $x.N + ': ' + $x.D }; '' }
    [IO.File]::WriteAllText($ReportPath, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))
}
$dir = Join-Path ([IO.Path]::GetTempPath()) ('ks-matrix-' + $PID)
if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
