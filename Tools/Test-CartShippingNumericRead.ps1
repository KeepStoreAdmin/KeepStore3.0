[CmdletBinding()]
param([switch]$SkipMutants, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CART-SHIPPING-NUMERIC-READ-1A. Assicurazione e contrassegno del vettore nel carrello.
# Difetto: i cinque numeri del vettore (percentuale e minimo dell'assicurazione; percentuale, fisso e minimo del contrassegno)
# passavano da testo e da una regola pensata per il testo scritto a mano (un separatore seguito da tre cifre = migliaia):
# un minimo di 4,125 diventava 4.125,00. Le percentuali erano inoltre arrotondate a due decimali prima del calcolo.
# Prova COMPORTAMENTALE sul percorso reale (sito LAB, https, 127.0.0.1, porta 18843, browser vero, utente di prova collegato):
# i valori del vettore scelto vengono cambiati sul LAB per la durata del test e rimessi alla fine.
# (A) sorgente, (B) sito LAB con i file di lavoro, (C) mutazioni eseguite sul sito LAB (file rimessi alla fine). Solo ASCII.
# CART-INSURANCE-UNCHECK-ORDER-1A (casi I1-I3): un vettore che non offre l'assicurazione (percentuale 0) non deve mai produrre un importo,
# nemmeno con un minimo impostato e con la casella mandata spuntata dal browser; la casella resta disattivata.
# CART-SUMMARY-AFTER-INVALID-DELIVERY-1A (caso V1): se il vettore scelto non e piu valido, il riepilogo non mostra piu i suoi importi
# e l'assicurazione va scelta di nuovo.
# CART-DRAFT-RESTORE-OVERRIDES-CARRIER-1A (caso D1): dopo un passaggio dalla conferma il cliente deve poter cambiare vettore e pagamento;
# se non cambia nulla (ritorno con Modifica, ricaricamento della pagina) restano le scelte sigillate nella bozza.

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

# ---------- scelte di vettore e pagamento (caso D1) ----------
$optionsJs = "(function(){function L(sel){var o=[];document.querySelectorAll(sel).forEach(function(r){var tr=r.closest('tr');var t=tr?tr.textContent.replace(/\s+/g,' ').toLowerCase():'';o.push({v:r.value,checked:r.checked,disabled:r.disabled,cod:(window.__ksCod&&t.indexOf(window.__ksCod)>=0)});});return o;}var tv=document.querySelector('[id`$=tbVettoriId]'),tp=document.querySelector('[id`$=tbPagamenti]');return JSON.stringify({tbV:tv?tv.value:'',tbP:tp?tp.value:'',carriers:L('[id*=gvVettori] input[type=radio]'),pays:L('[id*=gvPagamento] input[type=radio]')});})()"
function Read-Options($browser) {
    $null = Invoke-KsJs $browser ('window.__ksCod=' + (ConvertTo-Json $script:codText) + ';1')
    return (ConvertFrom-Json ([string](Invoke-KsJs $browser $optionsJs)))
}
function Format-Options($o) {
    $cv = @($o.carriers | Where-Object { $_.checked } | ForEach-Object { [string]$_.v }) -join ','
    $cp = @($o.pays | Where-Object { $_.checked } | ForEach-Object { [string]$_.v }) -join ','
    return ([string]$o.tbV + '/' + [string]$o.tbP + ' spunte ' + $cv + '/' + $cp)
}
# Clic sul radio con quel valore; attende che la pagina tornata mostri il valore nella casella nascosta (o 8 secondi) e restituisce lo stato.
function Select-Option($browser, [string]$grid, [string]$value) {
    Start-Sleep -Milliseconds 2000   # la pagina appena tornata deve finire di caricarsi, altrimenti il clic va perso
    $done = [string](Invoke-KsJs $browser ("(function(){var r=[].slice.call(document.querySelectorAll('[id*=" + $grid + "] input[type=radio]')).filter(function(x){return x.value==='" + $value + "'&&!x.disabled;});if(!r.length)return '';if(r[0].checked)return 'gia';r[0].click();return '1';})()"))
    if ($done -eq '') { throw ('PAGINA_NON_VALIDA: opzione ' + $value + ' non trovata in ' + $grid) }
    $o = $null
    for ($w = 0; $w -lt 16; $w++) {
        Start-Sleep -Milliseconds 500
        try { $o = Read-Options $browser } catch { $o = $null }
        if ($null -eq $o) { continue }
        $now = if ($grid -eq 'gvPagamento') { [string]$o.tbP } else { [string]$o.tbV }
        if ($done -eq 'gia' -or ($now -eq $value -and $w -ge 3)) { break }
    }
    if ($null -eq $o) { throw 'PAGINA_NON_VALIDA: pagina non leggibile dopo la scelta di una opzione' }
    return $o
}
function Go-Confirm($browser, [string]$what) {
    Start-Sleep -Milliseconds 1500
    Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 3500
    if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { throw ('PAGINA_NON_VALIDA: conferma non raggiunta (' + $what + ')') }
}
# Browser nuovo = sessione nuova, senza bozza d'ordine: stato di partenza per i casi successivi.
function Reset-Browser {
    if ($script:browser) { Stop-KsBrowser $script:browser; $script:browser = $null }
    $script:browser = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width 1280 -Height 900
    Enter-Site $script:browser
}

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
        'C4' {   # cinque NULL: zero, niente contrassegno, casella dell'assicurazione spenta, ma il vettore resta valido fino alla conferma
            Set-Carrier $null $null $null $null $null; $s = Read-Step2 $browser
            if ($s.carrier -ne [string]$script:carrier) { $bad.Add('vettore scelto ' + $s.carrier) }
            if ($s.ins -ne '0,00') { $bad.Add('assicurazione "' + $s.ins + '", attesa "0,00"') }
            if ($s.insDisabled -ne $true) { $bad.Add('casella dell''assicurazione attiva con valori NULL') }
            if ($null -eq $s.cod -or $s.cod.disabled -ne $true) { $bad.Add('contrassegno ancora selezionabile') }
            if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btnVaiConfermaOrdine")')) {
                Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 1500
                if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { $bad.Add('con valori NULL non si arriva alla conferma') }
            } else { $bad.Add('pulsante verso la conferma assente') }
        }
        'I1' {   # vettore SENZA assicurazione (percentuale 0) ma con un minimo: casella spenta, nessun importo
            Set-Carrier 0 4.125 1.6 0 3.5; $s = Read-Step2 $browser
            $sa = if ($s.sum.PSObject.Properties['Assicurazione']) { [string]$s.sum.Assicurazione } else { '' }
            $script:totalNoInsurance = if ($s.sum.PSObject.Properties['Totale']) { [string]$s.sum.Totale } else { '' }
            if ($s.insDisabled -ne $true) { $bad.Add('I1 casella dell''assicurazione attiva con un vettore che non la offre') }
            if ($s.ins -ne '0,00') { $bad.Add('I1 importo offerto "' + $s.ins + '", atteso "0,00"') }
            if ($sa -ne '0,00') { $bad.Add('I1 riepilogo Assicurazione "' + $sa + '", atteso "0,00"') }
        }
        'I2' {   # stesso vettore: casella forzata attiva e spuntata nel browser, poi verso la conferma
            Set-Carrier 0 4.125 1.6 0 3.5; $s = Read-Step2 $browser
            $t0 = if ($s.sum.PSObject.Properties['Totale']) { [string]$s.sum.Totale } else { '' }
            if ($s.insChecked -eq $true) { throw 'PAGINA_NON_VALIDA: casella gia spuntata prima della prova' }
            $null = Invoke-KsJs $browser "(function(){var c=document.querySelector('[id`$=cbAssicurazione]');if(!c)return 0;c.disabled=false;c.removeAttribute('disabled');var p=c.parentElement;if(p&&p.hasAttribute('disabled')){p.removeAttribute('disabled');}c.onclick=null;c.checked=true;return 1;})()"
            Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 3000
            if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { throw 'PAGINA_NON_VALIDA: conferma non raggiunta nel caso I2' }
            $s2 = Read-State $browser
            $sa = if ($s2.sum.PSObject.Properties['Assicurazione']) { [string]$s2.sum.Assicurazione } else { '' }
            $t1 = if ($s2.sum.PSObject.Properties['Totale']) { [string]$s2.sum.Totale } else { '' }
            if ($sa -ne '0,00') { $bad.Add('I2 alla conferma Assicurazione "' + $sa + '" con un vettore che non la offre, atteso "0,00"') }
            if ($t0 -eq '' -or $t1 -ne $t0) { $bad.Add('I2 alla conferma Totale "' + $t1 + '", atteso "' + $t0 + '"') }
        }
        'I3' {   # vettore CON assicurazione: la scelta legittima resta fino alla conferma
            Set-Carrier 1.5 4.5 1.6 0 3.5; $s = Read-Step2 $browser
            $ei = Money ([Math]::Max($script:imp * 1.5D / 100D, 4.5D))
            if ($s.insDisabled -ne $false) { $bad.Add('I3 casella dell''assicurazione spenta con un vettore che la offre') }
            elseif ($s.ins -ne $ei) { $bad.Add('I3 importo offerto "' + $s.ins + '", atteso "' + $ei + '"') }
            else {
                if ($s.insChecked -ne $true) { Invoke-KsClick $browser '[id$=cbAssicurazione]'; Start-Sleep -Milliseconds 2000 }
                $s2 = Read-State $browser
                if (-not $s2.step2) { throw 'PAGINA_NON_VALIDA: dopo la spunta dell''assicurazione nel caso I3' }
                $sa = if ($s2.sum.PSObject.Properties['Assicurazione']) { [string]$s2.sum.Assicurazione } else { '' }
                if ($s2.insChecked -ne $true -or $sa -ne $ei) { $bad.Add('I3 dopo la spunta riepilogo Assicurazione "' + $sa + '", atteso "' + $ei + '"') }
                Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 3000
                if (-not [bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { $bad.Add('I3 conferma non raggiunta con l''assicurazione scelta') }
                else {
                    $s3 = Read-State $browser
                    $sc = if ($s3.sum.PSObject.Properties['Assicurazione']) { [string]$s3.sum.Assicurazione } else { '' }
                    if ($sc -ne $ei) { $bad.Add('I3 alla conferma Assicurazione "' + $sc + '", atteso "' + $ei + '"') }
                }
                $s4 = Read-Step2 $browser
                if ($s4.insChecked -eq $true) { Invoke-KsClick $browser '[id$=cbAssicurazione]'; Start-Sleep -Milliseconds 2000 }
            }
        }
        'V1' {   # il vettore scelto (con assicurazione spuntata) viene tolto dal Web: riepilogo senza i suoi importi
            Set-Carrier 1.5 4.5 1.6 0 3.5; $s = Read-Step2 $browser
            if ($s.insDisabled -ne $false) { throw 'PAGINA_NON_VALIDA: V1 richiede un vettore con assicurazione' }
            if ($s.insChecked -ne $true) { Invoke-KsClick $browser '[id$=cbAssicurazione]'; Start-Sleep -Milliseconds 2000 }
            $s1 = Read-State $browser
            if ($s1.insChecked -ne $true -or -not $s1.sum.PSObject.Properties['IVA']) { throw 'PAGINA_NON_VALIDA: V1 assicurazione non spuntata prima della prova' }
            $ivaBefore = Num ([string]$s1.sum.IVA)
            $null = Invoke-Sql ("UPDATE vettori SET Web=0 WHERE id=$script:carrier AND AziendeId=$script:company;") -Write
            try {
                Invoke-KsClick $browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 3500
                if ([bool](Invoke-KsJs $browser '!!document.querySelector("#MainContent_btInviaOrdine")')) { $bad.Add('V1 conferma raggiunta con un vettore non piu valido') }
                else {
                    $s2 = Read-State $browser
                    if (-not $s2.step2) { throw 'PAGINA_NON_VALIDA: V1 passo spedizione e pagamento non mostrato dopo il fallimento' }
                    foreach ($n in @('Imponibile', 'Spedizione', 'Assicurazione', 'IVA', 'Pagamento', 'Totale')) { if (-not $s2.sum.PSObject.Properties[$n]) { throw ('PAGINA_NON_VALIDA: V1 riepilogo senza ' + $n) } }
                    if ([string]$s2.sum.Spedizione -ne '0,00') { $bad.Add('V1 riepilogo Spedizione "' + [string]$s2.sum.Spedizione + '" senza un vettore scelto, atteso "0,00"') }
                    if ([string]$s2.sum.Assicurazione -ne '0,00') { $bad.Add('V1 riepilogo Assicurazione "' + [string]$s2.sum.Assicurazione + '" senza un vettore scelto, atteso "0,00"') }
                    if ($s2.ins -ne '0,00') { $bad.Add('V1 importo offerto "' + $s2.ins + '" senza un vettore scelto, atteso "0,00"') }
                    if ($s2.insChecked -ne $false) { $bad.Add('V1 casella dell''assicurazione ancora spuntata dopo il fallimento') }
                    if ($s2.insDisabled -ne $true) { $bad.Add('V1 casella dell''assicurazione attiva senza un vettore scelto') }
                    if ($bad.Count -eq 0) {
                        $sumParts = (Num ([string]$s2.sum.Imponibile)) + (Num ([string]$s2.sum.IVA)) + (Num ([string]$s2.sum.Pagamento))
                        if ((Num ([string]$s2.sum.IVA)) -ge $ivaBefore) { $bad.Add('V1 IVA "' + [string]$s2.sum.IVA + '" non scesa senza spedizione e assicurazione') }
                        if ((Num ([string]$s2.sum.Totale)) -ne $sumParts) { $bad.Add('V1 Totale "' + [string]$s2.sum.Totale + '", atteso imponibile + IVA + pagamento = ' + $sumParts.ToString($inv)) }
                        # richiesta successiva: un altro vettore che offre l'assicurazione non deve addebitarla senza un nuovo gesto
                        $offered = $false
                        $prevCarrier = '0'; $trace = ''
                        for ($k = 0; $k -lt 4 -and -not $offered; $k++) {
                            Start-Sleep -Milliseconds 2000   # la pagina appena tornata deve finire di caricarsi, altrimenti il clic va perso
                            $clicked = [string](Invoke-KsJs $browser ("(function(){var r=[].slice.call(document.querySelectorAll('[id*=gvVettori] input[type=radio]')).filter(function(x){return !x.disabled;});if(r.length<=" + $k + ")return '';r[" + $k + "].click();return '1';})()"))
                            if ($clicked -eq '') { break }
                            $s3 = $null
                            for ($w = 0; $w -lt 16; $w++) { Start-Sleep -Milliseconds 500; try { $s3 = Read-State $browser } catch { $s3 = $null }; if ($null -ne $s3 -and $s3.step2 -and ([string]$s3.carrier) -match '^[1-9]\d*$' -and ([string]$s3.carrier) -ne $prevCarrier -and $s3.sum.PSObject.Properties['Spedizione']) { break } }
                            if ($null -ne $s3) { $prevCarrier = [string]$s3.carrier; $trace += ' [clic ' + $k + ': vettore ' + [string]$s3.carrier + ', casella spenta ' + [string]$s3.insDisabled + ', passo ' + [string]$s3.step2 + ']' } else { $trace += ' [clic ' + $k + ': pagina non letta]' }
                            if ($null -eq $s3) { throw 'PAGINA_NON_VALIDA: V1 pagina non leggibile dopo la scelta di un altro vettore' }
                            if ($s3.step2 -and $s3.insDisabled -eq $false) { $offered = $true }
                        }
                        if (-not $offered) { throw ('PAGINA_NON_VALIDA: V1 nessun altro vettore con assicurazione per la richiesta successiva' + $trace) }
                        $sa3 = if ($s3.sum.PSObject.Properties['Assicurazione']) { [string]$s3.sum.Assicurazione } else { '' }
                        if ($s3.insChecked -ne $false -or $sa3 -ne '0,00') { $bad.Add('V1 dopo la scelta di un altro vettore Assicurazione "' + $sa3 + '" senza un nuovo gesto del cliente') }
                    }
                }
            } finally { $null = Invoke-Sql ("UPDATE vettori SET Web=1 WHERE id=$script:carrier AND AziendeId=$script:company;") -Write }
            $webNow = Get-Scalar "SELECT Web AS ksval FROM vettori WHERE id=$script:carrier AND AziendeId=$script:company;"
            if ($webNow -ne '1') { throw 'ATTENZIONE: vettore di prova non rimesso sul Web' }
        }
        'D1' {   # dopo la conferma il cliente deve poter cambiare vettore e pagamento; senza cambi restano le scelte sigillate
            Reset-Browser; $browser = $script:browser   # sessione nuova: nessuna bozza dei casi precedenti
            Set-Carrier 1.5 4.5 1.6 0 3.5; $null = Read-Step2 $browser
            $o0 = Read-Options $browser
            $v0 = [string]$o0.tbV; $p0 = [string]$o0.tbP
            $vs = @($o0.carriers | Where-Object { -not $_.disabled } | ForEach-Object { [string]$_.v })
            $ps = @($o0.pays | Where-Object { -not $_.disabled -and -not $_.cod } | ForEach-Object { [string]$_.v })
            if ($vs.Count -lt 2 -or $ps.Count -lt 2) { throw ('PAGINA_NON_VALIDA: D1 richiede almeno due vettori e due pagamenti attivi (' + $vs.Count + ', ' + $ps.Count + ')') }
            $va = $vs[$vs.Count - 1]; $vc = $vs[0]            # A = ultimo vettore, C = primo (piu in alto di A)
            $pb = $ps[$ps.Count - 1]; $pd = $ps[0]            # B = ultimo pagamento, D = primo
            try {
                $o = Select-Option $browser 'gvVettori' $va; $o = Select-Option $browser 'gvPagamento' $pb
                if ([string]$o.tbV -ne $va -or [string]$o.tbP -ne $pb) { throw ('PAGINA_NON_VALIDA: D1 scelte iniziali non applicate (' + (Format-Options $o) + ')') }
                Go-Confirm $browser 'D1 prima conferma'
                Invoke-KsClick $browser '#MainContent_btnModificaCheckout'; Start-Sleep -Milliseconds 3500
                $o = Read-Options $browser
                if ((Format-Options $o) -ne ($va + '/' + $pb + ' spunte ' + $va + '/' + $pb)) { $bad.Add('D1 dopo Modifica senza cambi: ' + (Format-Options $o) + ', atteso ' + $va + '/' + $pb) }
                $null = Read-Step2 $browser
                $o = Read-Options $browser
                if ((Format-Options $o) -ne ($va + '/' + $pb + ' spunte ' + $va + '/' + $pb)) { $bad.Add('D1 dopo il ricaricamento con la bozza valida: ' + (Format-Options $o) + ', atteso ' + $va + '/' + $pb) }
                if ($bad.Count -eq 0) {
                    $o = Select-Option $browser 'gvVettori' $vc
                    if ((Format-Options $o) -ne ($vc + '/' + $pb + ' spunte ' + $vc + '/' + $pb)) { $bad.Add('D1 vettore scelto dal cliente dopo la conferma: ' + (Format-Options $o) + ', atteso ' + $vc + '/' + $pb) }
                }
                if ($bad.Count -eq 0) {
                    $o = Select-Option $browser 'gvPagamento' $pd
                    if ((Format-Options $o) -ne ($vc + '/' + $pd + ' spunte ' + $vc + '/' + $pd)) { $bad.Add('D1 pagamento scelto dal cliente dopo la conferma: ' + (Format-Options $o) + ', atteso ' + $vc + '/' + $pd) }
                }
                if ($bad.Count -eq 0) {
                    Go-Confirm $browser 'D1 seconda conferma'
                    Invoke-KsClick $browser '#MainContent_btnModificaCheckout'; Start-Sleep -Milliseconds 3500
                    $o = Read-Options $browser
                    if ((Format-Options $o) -ne ($vc + '/' + $pd + ' spunte ' + $vc + '/' + $pd)) { $bad.Add('D1 dopo la seconda conferma e Modifica: ' + (Format-Options $o) + ', atteso ' + $vc + '/' + $pd) }
                    $null = Read-Step2 $browser
                    $o = Read-Options $browser
                    if ((Format-Options $o) -ne ($vc + '/' + $pd + ' spunte ' + $vc + '/' + $pd)) { $bad.Add('D1 dopo il ricaricamento con la bozza nuova: ' + (Format-Options $o) + ', atteso ' + $vc + '/' + $pd) }
                }
            } finally {
                # stato di partenza per i casi successivi: nuovo browser = nuova sessione, senza bozza
                Reset-Browser
            }
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
        # V1 per primo: dopo un passaggio dalla conferma la bozza valida rimette il vettore di prima a ogni richiesta (difetto noto, in coda
        # come CART-DRAFT-RESTORE-OVERRIDES-CARRIER-1A) e la parte finale di V1 non potrebbe scegliere un altro vettore.
        foreach ($c in @('V1', 'C1', 'C2', 'C2B', 'C4', 'C5', 'C3', 'I1', 'I2', 'I3', 'D1')) {
            $bad = @(Test-Case $c $script:browser)
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
            @{ Id = 'M08_COD_SWITCH_ROUNDED'; Case = 'C2B'; Old = 'RitiroSede = (charges.CodPercent = 0D)'; New = 'RitiroSede = (Math.Round(charges.CodPercent, 2, MidpointRounding.AwayFromZero) = 0D)' },
            @{ Id = 'M09_UNAVAILABLE_INSURANCE_KEEPS_AMOUNT'; Case = 'I1'; Expect = 'I1 importo offerto'; Old = 'If Not _insuranceAvailable Then insurance = 0'; New = 'If False Then insurance = 0' },
            @{ Id = 'M10_LOCK_IGNORES_AVAILABILITY'; Case = 'I1'; Expect = 'I1 casella'; Old = 'unlocked AndAlso (Not _insuranceKnown OrElse _insuranceAvailable)'; New = 'unlocked' },
            @{ Id = 'M11_CODE_BEFORE_THE_FIX'; Case = 'I2'; Expect = 'I2 alla conferma Assicurazione "4,13"'; Old = 'If Not _insuranceAvailable Then insurance = 0'; New = 'If False Then insurance = 0'; Old2 = 'unlocked AndAlso (Not _insuranceKnown OrElse _insuranceAvailable)'; New2 = 'unlocked' },
            @{ Id = 'M12_INSURANCE_NEVER_AVAILABLE'; Case = 'I3'; Expect = 'I3 casella'; Old = '_insuranceAvailable = readOk AndAlso charges.InsurancePercent <> 0D'; New = '_insuranceAvailable = False' },
            @{ Id = 'M13_FAILED_DELIVERY_KEEPS_SHIPPING'; Case = 'V1'; Expect = 'V1 riepilogo Spedizione'; Old = 'If lblSpeseSped IsNot Nothing Then lblSpeseSped.Text = FormatCurrencyIt(0D) '' consegna non valida'; New = '' },
            @{ Id = 'M14_FAILED_DELIVERY_KEEPS_INSURANCE_COST'; Case = 'V1'; Expect = 'V1 riepilogo Assicurazione'; Old = 'If lblSpeseAss IsNot Nothing Then lblSpeseAss.Text = FormatCurrencyIt(0D) '' consegna non valida'; New = '' },
            @{ Id = 'M15_FAILED_DELIVERY_KEEPS_OFFER'; Case = 'V1'; Expect = 'V1 importo offerto'; Old = 'If lblAssicurazione IsNot Nothing Then lblAssicurazione.Text = FormatCurrencyIt(0D) '' consegna non valida'; New = '' },
            @{ Id = 'M16_FAILED_DELIVERY_KEEPS_TICK'; Case = 'V1'; Expect = 'V1 casella dell''assicurazione ancora spuntata'; Old = 'If cbAssicurazione IsNot Nothing Then cbAssicurazione.Checked = False '' consegna non valida'; New = '' },
            @{ Id = 'M17_FAILED_DELIVERY_KEEPS_BOX_ENABLED'; Case = 'V1'; Expect = 'V1 casella dell''assicurazione attiva'; Old = '_insuranceKnown = True '' consegna non valida'; New = '' },
            @{ Id = 'M18_DRAFT_ALWAYS_RESTORED'; Case = 'D1'; Expect = 'D1 vettore scelto dal cliente'; Old = 'If Not IsCheckoutOptionGroupPosted("spedizione") Then'; New = 'If True Then' },
            @{ Id = 'M19_DRAFT_NEVER_RESTORED'; Case = 'D1'; Expect = 'D1 dopo il ricaricamento con la bozza valida'; Old = 'If Not IsCheckoutOptionGroupPosted("spedizione") Then'; New = 'If False Then' },
            @{ Id = 'M20_PAYMENT_ALWAYS_RESTORED'; Case = 'D1'; Expect = 'D1 pagamento scelto dal cliente'; Old = 'If Not IsCheckoutOptionGroupPosted("pagamento") Then'; New = 'If True Then' }
        )
        foreach ($m in $mutants) {
            if (([regex]::Matches($source, [regex]::Escape($m.Old))).Count -ne 1) { $mutantFail.Add($m.Id + ' ancora non unica'); continue }
            $mutated = $source.Replace($m.Old, $m.New)
            if ($m.ContainsKey('Old2')) { if (([regex]::Matches($source, [regex]::Escape($m.Old2))).Count -ne 1) { $mutantFail.Add($m.Id + ' seconda parte ancora non unica'); continue }; $mutated = $mutated.Replace($m.Old2, $m.New2) }
            Write-SiteVb $mutated
            try {
                $mb = @(Test-Case $m.Case $script:browser)
                if ($mb.Count -eq 0) { $mutantFail.Add($m.Id + ' sopravvive al caso ' + $m.Case) }
                elseif ($m.ContainsKey('Expect') -and -not ($mb[0]).StartsWith($m.Expect)) { $mutantFail.Add($m.Id + ' fallisce per un altro motivo: ' + $mb[0]) } else { Write-Host ('  ucciso ' + $m.Id + ' (' + $m.Case + '): ' + $mb[0]) }
            } catch { $mutantFail.Add($m.Id + ' errore: ' + $_.Exception.Message) }
        }
        Sync-Site
        $after = @(Test-Case 'C1' $script:browser)
        if ($after.Count -ne 0) { $mutantFail.Add('dopo il ripristino il sito non torna verde: ' + $after[0]) }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    try { Sync-Site } catch { Write-Host '  ATTENZIONE: file del sito LAB non ripristinati' }
    if ((Get-Variable -Scope Script -Name carrier -ErrorAction SilentlyContinue) -and $script:carrier -gt 0) { try { $null = Invoke-Sql ("UPDATE vettori SET Web=1 WHERE id=$script:carrier AND AziendeId=$script:company AND Web=0;") -Write } catch { Write-Host '  ATTENZIONE: vettore di prova non rimesso sul Web' } }
    if ($restoreCarrier -ne '') { try { $null = Invoke-Sql $restoreCarrier -Write } catch { Write-Host '  ATTENZIONE: valori del vettore non ripristinati sul LAB' } }
    if ($restorePayment -ne '') { try { $null = Invoke-Sql $restorePayment -Write } catch { Write-Host '  ATTENZIONE: pagamento in contrassegno non ripristinato sul LAB' } }
    Close-LabSite
}

if ($sourceFailed) { Write-Host 'CART_SHIPPING_NUMERIC FAIL (sorgente)' }
if ($e2e.Count -gt 0) { Write-Host ('CART_SHIPPING_NUMERIC FAIL (sito LAB): ' + $e2e.Count) }
foreach ($x in $mutantFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFailed -or $e2e.Count -gt 0 -or $mutantFail.Count -gt 0) { exit 1 }
if ($SkipMutants) { Write-Host 'CART_SHIPPING_NUMERIC OK (mutazioni saltate)' } else { Write-Host 'CART_SHIPPING_NUMERIC OK (20 mutazioni uccise sul sito LAB)' }
exit 0
