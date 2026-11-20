[CmdletBinding()]
param([switch]$SkipMutants, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CART-SHIPPING-NUMERIC-READ-1A. Assicurazione e contrassegno del vettore nel carrello.
# Difetto: i cinque numeri del vettore (percentuale e minimo dell'assicurazione; percentuale, fisso e minimo del contrassegno)
# passavano da testo e da una regola pensata per il testo scritto a mano (un separatore seguito da tre cifre = migliaia):
# un minimo di 4,125 diventava 4.125,00. Le percentuali erano inoltre arrotondate a due decimali prima del calcolo.
# Prova COMPORTAMENTALE sul percorso reale (sito LAB, https, 127.0.0.1, porta 18843, browser vero, utente di prova collegato):
# i valori del vettore scelto vengono cambiati sul LAB per la durata del test e rimessi alla fine.
# (A) sorgente, (B) sito LAB con i file di lavoro, (C) mutazioni eseguite sul sito LAB (file rimessi alla fine). Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$it = [Globalization.CultureInfo]::GetCultureInfo('it-IT')
$files = @('carrello.aspx.vb', 'carrello.aspx')
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
$fail = New-Object Collections.Generic.List[string]

function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$vbBom = ($repoBytes['carrello.aspx.vb'][0] -eq 0xEF)
$source = Get-Text $repoBytes['carrello.aspx.vb']
$markup = Get-Text $repoBytes['carrello.aspx']

# ---------- (A) sorgente ----------
$names = 'id,AssicurazionePercentuale,AssicurazioneMinimo,ContrassegnoPercentuale,ContrassegnoFisso,ContrassegnoMinimo'
foreach ($g in @('gvVettoriPromo', 'gvVettori')) {
    $mm = [regex]::Match($markup, '<asp:GridView ID="' + $g + '"[^>]*>', 'Singleline')
    if (-not $mm.Success -or $mm.Value -notmatch ('DataKeyNames="' + [regex]::Escape($names) + '"')) { $fail.Add('S01 ' + $g + ': i cinque numeri del vettore sono chiavi tipizzate della griglia, id per primo') }
}
function Get-Block([string]$start, [string]$end) { $i0 = $source.IndexOf($start, [StringComparison]::Ordinal); if ($i0 -lt 0) { return '' }; $i1 = $source.IndexOf($end, $i0, [StringComparison]::Ordinal); if ($i1 -lt 0) { return '' }; return $source.Substring($i0, $i1 - $i0) }
$bVettori = Get-Block 'Public Sub LeggiVettori(' 'End Sub'
$bPagamenti = Get-Block 'Public Sub LeggiPagamenti(' 'End Sub'
$bSpecial = Get-Block 'Private Function ApplySpecialFreeShippingSelection(' 'End Function'
$bApply = Get-Block 'Private Function ApplyCarrierCharges(' 'End Function'
if ($bVettori -eq '' -or $bPagamenti -eq '' -or $bSpecial -eq '') { $fail.Add('S00 funzioni del vettore non trovate') }
if ($bVettori -match 'lblAssPerc|lblAssicurazioneMinimo|lblContrPerc|lblContrFisso|lblContrMinimo|tbContrPerc\.Text, 0') { $fail.Add('S02 LeggiVettori non legge piu i numeri del vettore dal testo delle etichette') }
if ($bPagamenti -match 'tbContrPerc|tbContrFisso|tbContrMinimo') { $fail.Add('S03 LeggiPagamenti non legge le caselle nascoste tornate dal browser') }
if ($bSpecial -match 'SafeDbl\(reader|Convert\.ToString\(reader') { $fail.Add('S04 spedizione gratuita speciale: numeri letti come numeri') }
if ($bSpecial -notmatch 'TryReadCarrierCharge\(reader\("AssicurazionePercentuale"\)' -or $bSpecial -notmatch 'ApplyCarrierCharges\(') { $fail.Add('S05 spedizione gratuita speciale: stessa lettura e stesso calcolo delle griglie') }
if ($bApply -eq '' -or $bApply -match 'SafeDbl\(|SafeDblFromText\(|ParseDecimalForDb\(|Math\.Round\(') { $fail.Add('S06 calcolo del vettore senza conversioni di testo e senza arrotondamenti anticipati') }
if ($source -notmatch '(?s)LeggiVettori\(False\)\s+End If\s+If _carrierChargesInvalid Then\s+ClearCurrentDeliverySelection\(\)\s+Return False') { $fail.Add('S07 valore del vettore illeggibile: la consegna non viene convalidata') }
foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }
$sourceFailed = ($fail.Count -gt 0)

# ---------- (B) sito LAB ----------
foreach ($f in $files) { if (-not (Test-Path -LiteralPath (Join-Path $SitePath $f))) { Write-Host ('CART_SHIPPING_NUMERIC FAIL: cartella del sito LAB non trovata: ' + $SitePath); exit 1 } }
. (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
. (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')

function Sync-Site { foreach ($f in $files) { $p = Join-Path $SitePath $f; if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($repoBytes[$f])) { [IO.File]::WriteAllBytes($p, $repoBytes[$f]) } } }
function Write-SiteVb([string]$text) { [IO.File]::WriteAllText((Join-Path $SitePath 'carrello.aspx.vb'), $text, (New-Object Text.UTF8Encoding($vbBom))) }
function R2([decimal]$v) { return [Math]::Round($v, 2, [MidpointRounding]::AwayFromZero) }
function Money([decimal]$v) { return (R2 $v).ToString('N2', $it) }
function Num([string]$t) { return [decimal]::Parse(($t -replace '\.', '' -replace ',', '.'), $inv) }
function Sql-Num($v) { if ($null -eq $v) { return 'NULL' } else { return ([decimal]$v).ToString($inv) } }
function Set-Carrier($ap, $am, $cp, $cf, $cm) {
    $null = Invoke-Sql ("UPDATE vettori SET AssicurazionePercentuale=" + (Sql-Num $ap) + ", AssicurazioneMinimo=" + (Sql-Num $am) + ", ContrassegnoPercentuale=" + (Sql-Num $cp) +
        ", ContrassegnoFisso=" + (Sql-Num $cf) + ", ContrassegnoMinimo=" + (Sql-Num $cm) + " WHERE id=$script:carrier AND AziendeId=$script:company;") -Write
}
# percentuale con tre decimali per cui l'importo esatto e quello con la percentuale arrotondata a due decimali cadono su centesimi diversi
function Find-Percent([decimal]$amount) {
    for ($k = 1001; $k -lt 900000; $k++) {
        if ($k % 10 -eq 0) { continue }
        $p = [decimal]$k / 1000D
        $a = $amount * $p / 100D; $b = $amount * (R2 $p) / 100D
        if ((R2 $a) -eq (R2 $b)) { continue }
        $ok = $true
        foreach ($x in @($a, $b)) { $fr = ($x * 100D) - [Math]::Floor($x * 100D); if ([Math]::Abs($fr - 0.5D) -lt 0.0002D) { $ok = $false } }
        if ($ok) { return $p }
    }
    return 0D
}
$stateJs = "(function(){function t(e){return e?(e.tagName==='INPUT'?e.value:e.textContent.replace(/\s+/g,' ').trim()):null;}var o={};o.step2=!!document.querySelector('[id`$=gvVettori]');o.carrier=t(document.querySelector('[id`$=tbVettoriId]'));o.ins=t(document.querySelector('[id`$=lblAssicurazione]'));var c=document.querySelector('[id`$=cbAssicurazione]');o.insChecked=c?c.checked:null;o.insDisabled=c?c.disabled:null;o.cod=null;var g=document.querySelector('[id`$=gvPagamento]');if(g){var rs=g.querySelectorAll('tr');for(var i=0;i<rs.length;i++){var r=rs[i];if(r.querySelector('tr'))continue;if(r.textContent.replace(/\s+/g,' ').toLowerCase().indexOf(window.__ksCod)>=0){var rb=r.querySelector('input[type=radio]');var l=r.querySelector('[id*=lblCosto]');o.cod={cost:t(l),disabled:rb?rb.disabled:null,checked:rb?rb.checked:null};}}}var b=document.body.innerText.replace(/\s+/g,' ');var k=b.lastIndexOf('Riepilogo ordine');o.sum={};if(k>=0){var s=b.substring(k);['Imponibile','Spedizione','Assicurazione','IVA','Pagamento','Totale'].forEach(function(n){var m=s.match(new RegExp('\\b'+n+' (-?[0-9.]+,[0-9]{2}|n/d)'));if(m)o.sum[n]=m[1];});}return JSON.stringify(o);})()"
function Enter-Site($browser) {
    Open-KsUrl $browser ($base + '/login.aspx') 300
    if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_tbPassword")')) {
        Set-KsValue $browser '#MainContent_tbUsername' $testUser
        Set-KsValue $browser '#MainContent_tbPassword' (Get-Secret)
        Invoke-KsClick $browser '#MainContent_btnLogin'
    }
}
function Read-State($browser) {
    $null = Invoke-KsJs $browser ('window.__ksCod=' + (ConvertTo-Json $script:codText) + ';1')
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser $stateJs)))
}
# Il sito LAB si riavvia dopo molte ricompilazioni e la sessione si perde: in quel caso si rientra e si riprova una volta.
function Read-Step2($browser) {
    for ($try = 0; $try -lt 2; $try++) {
        Open-KsUrl $browser ($base + '/carrello.aspx') 300
        if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btCompleta")')) { Invoke-KsClick $browser '#MainContent_btCompleta'; Start-Sleep -Milliseconds 1500 }
        $st = Read-State $browser
        if ($st.step2) { return $st }
        Enter-Site $browser
    }
    throw 'PAGINA_NON_VALIDA: passo spedizione e pagamento non raggiunto'
}
function CodCost($s) { if ($null -ne $s.cod) { return [string]$s.cod.cost } else { return '(riga assente)' } }

# Ogni caso restituisce l'elenco dei difetti (vuoto = giusto).
function Test-Case([string]$id, $browser) {
    $bad = New-Object Collections.Generic.List[string]
    switch ($id) {
        'C1' {   # minimi dominanti con tre decimali
            Set-Carrier 0.004 4.125 0.004 0.125 3.125; $s = Read-Step2 $browser
            if ($s.carrier -ne [string]$script:carrier) { $bad.Add('vettore scelto ' + $s.carrier) }
            if ($s.ins -ne '4,13') { $bad.Add('assicurazione "' + $s.ins + '", attesa "4,13"') }
            if ((CodCost $s) -ne '3,13') { $bad.Add('contrassegno "' + (CodCost $s) + '", atteso "3,13"') }
        }
        'C2' {   # percentuali con tre decimali che decidono il centesimo
            Set-Carrier $script:pIns 0 $script:pCod 0 0; $s = Read-Step2 $browser
            $ei = Money ($script:imp * $script:pIns / 100D); $ec = Money ($script:baseAmount * $script:pCod / 100D)
            if ($s.ins -ne $ei) { $bad.Add('assicurazione "' + $s.ins + '", attesa "' + $ei + '" (percentuale ' + $script:pIns.ToString($inv) + ')') }
            if ((CodCost $s) -ne $ec) { $bad.Add('contrassegno "' + (CodCost $s) + '", atteso "' + $ec + '" (percentuale ' + $script:pCod.ToString($inv) + ')') }
        }
        'C2B' {  # percentuali sotto il centesimo e fisso con tre decimali
            Set-Carrier 0.004 0 0.004 0.125 0; $s = Read-Step2 $browser
            $ec = Money (($script:baseAmount * 0.004D / 100D) + 0.125D)
            if ($null -eq $s.cod -or $s.cod.disabled -ne $false) { $bad.Add('contrassegno non selezionabile con percentuale 0,004') }
            if ((CodCost $s) -ne $ec) { $bad.Add('contrassegno "' + (CodCost $s) + '", atteso "' + $ec + '" (fisso 0,125)') }
        }
        'C3' {   # postback senza rilegatura delle griglie: spunta dell'assicurazione
            Set-Carrier 0.004 4.125 0.004 0.125 3.125; $s = Read-Step2 $browser
            if ($s.insChecked -ne $false -or $s.insDisabled -ne $false) { $bad.Add('casella dell''assicurazione non disponibile') }
            else {
                Invoke-KsClick $browser '[id$=cbAssicurazione]'; Start-Sleep -Milliseconds 1500
                $s2 = Read-State $browser
                if (-not $s2.step2) { throw 'PAGINA_NON_VALIDA: dopo la spunta dell''assicurazione' }
                $sa = if ($s2.sum.PSObject.Properties['Assicurazione']) { [string]$s2.sum.Assicurazione } else { '' }
                if ($s2.insChecked -ne $true) { $bad.Add('assicurazione non spuntata dopo il clic') }
                if ($sa -ne '4,13') { $bad.Add('riepilogo Assicurazione "' + $sa + '", atteso "4,13"') }
                if ((CodCost $s2) -ne '3,13') { $bad.Add('contrassegno dopo il postback "' + (CodCost $s2) + '", atteso "3,13"') }
                if ($s2.insChecked -eq $true) { Invoke-KsClick $browser '[id$=cbAssicurazione]'; Start-Sleep -Milliseconds 1500 }
            }
        }
        'C4' {   # cinque NULL: zero, niente contrassegno, ma il vettore resta valido fino alla conferma (la casella dell'assicurazione
                 # viene riattivata dal blocco/sblocco della pagina: comportamento preesistente, fuori da questa prova)
            Set-Carrier $null $null $null $null $null; $s = Read-Step2 $browser
            if ($s.carrier -ne [string]$script:carrier) { $bad.Add('vettore scelto ' + $s.carrier) }
            if ($s.ins -ne '0,00') { $bad.Add('assicurazione "' + $s.ins + '", attesa "0,00"') }
            if ($null -eq $s.cod -or $s.cod.disabled -ne $true) { $bad.Add('contrassegno ancora selezionabile') }
            if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btnVaiConfermaOrdine")')) {
                Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 1500
                if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { $bad.Add('con valori NULL non si arriva alla conferma') }
            } else { $bad.Add('pulsante verso la conferma assente') }
        }
        'C5' {   # valori di oggi a due decimali: stessi importi di prima
            Set-Carrier 1.5 4.5 1.6 0 3.5; $s = Read-Step2 $browser
            $ei = Money ([Math]::Max($script:imp * 1.5D / 100D, 4.5D)); $ec = Money ([Math]::Max($script:baseAmount * 1.6D / 100D, 3.5D))
            if ($s.ins -ne $ei) { $bad.Add('assicurazione "' + $s.ins + '", attesa "' + $ei + '"') }
            if ((CodCost $s) -ne $ec) { $bad.Add('contrassegno "' + (CodCost $s) + '", atteso "' + $ec + '"') }
        }
    }
    return $bad.ToArray()
}

$browser = $null
$mutantFail = New-Object Collections.Generic.List[string]
$siteFailed = $false
$restoreCarrier = ''; $restorePayment = ''
try {
    Sync-Site
    $script:company = Get-Scalar "SELECT id AS ksval FROM aziende WHERE LOWER(TRIM(COALESCE(url1,''))) LIKE '%www.taikun.it%' OR LOWER(TRIM(COALESCE(url2,''))) LIKE '%www.taikun.it%' ORDER BY id LIMIT 1;"
    Check ($script:company -match '^\d+$') 'L01 azienda dell''host trovata nel database LAB'
    $payId = Get-Scalar "SELECT id AS ksval FROM pagamentitipo WHERE AziendeID=$script:company AND Abilitato=1 AND Contrassegno=1 AND COALESCE(OnLine,0)=0 AND CostoPercentuale IS NOT NULL AND CostoFisso IS NOT NULL ORDER BY CostoMassimo DESC, id LIMIT 1;"
    Check ($payId -match '^\d+$') 'L02 esiste un pagamento in contrassegno per l''azienda'
    $payWeb = Get-Scalar "SELECT COALESCE(Web,0) AS ksval FROM pagamentitipo WHERE id=$payId;"
    $script:codText = (Get-Scalar "SELECT LOWER(TRIM(Descrizione)) AS ksval FROM pagamentitipo WHERE id=$payId;")
    if ($payWeb -ne '1') { $null = Invoke-Sql "UPDATE pagamentitipo SET Web=1 WHERE id=$payId;" -Write; $restorePayment = "UPDATE pagamentitipo SET Web=$payWeb WHERE id=$payId;" }

    $browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width 1280 -Height 900
    Enter-Site $browser
    Check (([string](Invoke-KsJs $browser 'location.pathname')) -notmatch 'login\.aspx') 'L03 utente di prova collegato'
    Open-KsUrl $browser ($base + '/carrello.aspx') 300
    if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btCompleta")')) {
        Open-KsUrl $browser ($base + '/articoli.aspx') 300; Start-Sleep -Seconds 2
        Invoke-KsClick $browser 'button.js-ks-cart-link' -NoWait; Start-Sleep -Seconds 6
    }
    $script:carrier = 0
    $s0 = Read-Step2 $browser
    Check ($s0.step2 -and ([string]$s0.carrier) -match '^[1-9]\d*$') 'L04 passo spedizione e pagamento con un vettore scelto'
    $script:carrier = [int]$s0.carrier
    $orig = Get-Scalar ("SELECT CONCAT_WS(',', CONCAT('AssicurazionePercentuale=', IFNULL(AssicurazionePercentuale,'NULL')), CONCAT('AssicurazioneMinimo=', IFNULL(AssicurazioneMinimo,'NULL')), CONCAT('ContrassegnoPercentuale=', IFNULL(ContrassegnoPercentuale,'NULL')), CONCAT('ContrassegnoFisso=', IFNULL(ContrassegnoFisso,'NULL')), CONCAT('ContrassegnoMinimo=', IFNULL(ContrassegnoMinimo,'NULL'))) AS ksval FROM vettori WHERE id=$script:carrier AND AziendeId=$script:company;")
    Check ($orig -match '^AssicurazionePercentuale=') 'L05 valori originali del vettore letti'
    $restoreCarrier = "UPDATE vettori SET $orig WHERE id=$script:carrier AND AziendeId=$script:company;"
    Check ($null -ne $s0.cod) 'L06 la riga del contrassegno e visibile'
    Check ($s0.insChecked -eq $false) 'L07 assicurazione non spuntata all''inizio'

    # base del costo del pagamento misurata con percentuale 100, fisso 0, minimo 0 (neutra rispetto ai difetti in prova)
    Set-Carrier 0 0 100 0 0
    $sb = Read-Step2 $browser
    $script:imp = if ($sb.sum.PSObject.Properties['Imponibile']) { Num ([string]$sb.sum.Imponibile) } else { 0D }
    $script:baseAmount = if ($null -ne $sb.cod -and ([string]$sb.cod.cost) -match '^[0-9.]+,[0-9]{2}$') { Num ([string]$sb.cod.cost) } else { 0D }
    $sumBase = 0D; foreach ($n in @('Imponibile', 'Spedizione', 'Assicurazione', 'IVA')) { if ($sb.sum.PSObject.Properties[$n]) { $sumBase += Num ([string]$sb.sum.$n) } }
    Check ($script:imp -gt 0 -and $script:baseAmount -gt 0 -and $script:baseAmount -eq $sumBase) ('L08 base del pagamento = imponibile + spedizione + assicurazione + IVA del riepilogo (' + $script:baseAmount.ToString($inv) + ')')
    $script:pIns = Find-Percent $script:imp; $script:pCod = Find-Percent $script:baseAmount
    Check ($script:pIns -gt 0 -and $script:pCod -gt 0) ('L09 percentuali di prova trovate (' + $script:pIns.ToString($inv) + ' e ' + $script:pCod.ToString($inv) + ')')

    if ($e2e.Count -eq 0) {
        foreach ($c in @('C1', 'C2', 'C2B', 'C4', 'C5', 'C3')) {
            $bad = @(Test-Case $c $browser)
            Check ($bad.Count -eq 0) ('L10 caso ' + $c + $(if ($bad.Count) { ' -> ' + ($bad -join '; ') } else { '' }))
        }
    }
    $siteFailed = ($e2e.Count -gt 0)

    # ---------- (C) mutazioni sul sito LAB ----------
    if (-not $siteFailed -and -not $sourceFailed -and -not $SkipMutants) {
        $mutants = @(
            @{ Id = 'M01_INS_MIN_FROM_TEXT'; Case = 'C1'; Old = 'Dim minimum As Double = CDbl(charges.InsuranceMinimum)'; New = 'Dim minimum As Double = SafeMoney(Convert.ToString(charges.InsuranceMinimum, CultureInfo.CurrentCulture), 0)' },
            @{ Id = 'M02_INS_PERCENT_ROUNDED'; Case = 'C2'; Old = 'Dim insurance As Double = (CDbl(charges.InsurancePercent) *'; New = 'Dim insurance As Double = (CDbl(Math.Round(charges.InsurancePercent, 2, MidpointRounding.AwayFromZero)) *' },
            @{ Id = 'M03_COD_MIN_FROM_TEXT'; Case = 'C1'; Old = '_carrierCodMinimum = charges.CodMinimum'; New = '_carrierCodMinimum = ParseDecimalForDb(Convert.ToString(charges.CodMinimum, CultureInfo.CurrentCulture), 0D)' },
            @{ Id = 'M04_COD_PERCENT_ROUNDED'; Case = 'C2'; Old = '_carrierCodPercent = charges.CodPercent'; New = '_carrierCodPercent = Math.Round(charges.CodPercent, 2, MidpointRounding.AwayFromZero)' },
            @{ Id = 'M05_COD_FIXED_FROM_TEXT'; Case = 'C2B'; Old = '_carrierCodFixed = charges.CodFixed'; New = '_carrierCodFixed = ParseDecimalForDb(Convert.ToString(charges.CodFixed, CultureInfo.CurrentCulture), 0D)' },
            @{ Id = 'M06_PAYMENT_READS_HIDDEN_BOX'; Case = 'C1'; Old = 'Minimo = CDbl(_carrierCodMinimum)'; New = 'Minimo = SafeMoney(Me.tbContrMinimo.Text, 0)' },
            @{ Id = 'M07_NULL_IS_FAILURE'; Case = 'C4'; Old = 'If raw Is DBNull.Value Then Return True'; New = 'If raw Is DBNull.Value Then Return False' },
            @{ Id = 'M08_COD_SWITCH_ROUNDED'; Case = 'C2B'; Old = 'RitiroSede = (charges.CodPercent = 0D)'; New = 'RitiroSede = (Math.Round(charges.CodPercent, 2, MidpointRounding.AwayFromZero) = 0D)' }
        )
        foreach ($m in $mutants) {
            if (([regex]::Matches($source, [regex]::Escape($m.Old))).Count -ne 1) { $mutantFail.Add($m.Id + ' ancora non unica'); continue }
            Write-SiteVb ($source.Replace($m.Old, $m.New))
            try {
                $mb = @(Test-Case $m.Case $browser)
                if ($mb.Count -eq 0) { $mutantFail.Add($m.Id + ' sopravvive al caso ' + $m.Case) } else { Write-Host ('  ucciso ' + $m.Id + ' (' + $m.Case + '): ' + $mb[0]) }
            } catch { $mutantFail.Add($m.Id + ' errore: ' + $_.Exception.Message) }
        }
        Sync-Site
        $after = @(Test-Case 'C1' $browser)
        if ($after.Count -ne 0) { $mutantFail.Add('dopo il ripristino il sito non torna verde: ' + $after[0]) }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    try { Sync-Site } catch { Write-Host '  ATTENZIONE: file del sito LAB non ripristinati' }
    if ($restoreCarrier -ne '') { try { $null = Invoke-Sql $restoreCarrier -Write } catch { Write-Host '  ATTENZIONE: valori del vettore non ripristinati sul LAB' } }
    if ($restorePayment -ne '') { try { $null = Invoke-Sql $restorePayment -Write } catch { Write-Host '  ATTENZIONE: pagamento in contrassegno non ripristinato sul LAB' } }
    Close-LabSite
}

if ($sourceFailed) { Write-Host 'CART_SHIPPING_NUMERIC FAIL (sorgente)' }
if ($e2e.Count -gt 0) { Write-Host ('CART_SHIPPING_NUMERIC FAIL (sito LAB): ' + $e2e.Count) }
foreach ($x in $mutantFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFailed -or $e2e.Count -gt 0 -or $mutantFail.Count -gt 0) { exit 1 }
if ($SkipMutants) { Write-Host 'CART_SHIPPING_NUMERIC OK (mutazioni saltate)' } else { Write-Host 'CART_SHIPPING_NUMERIC OK (8 mutazioni uccise sul sito LAB)' }
exit 0
