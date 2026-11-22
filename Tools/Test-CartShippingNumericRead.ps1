[CmdletBinding()]
param([switch]$SkipMutants, [string]$Cases = '', [string]$MutantFilter = '', [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

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
# CHECKOUT-SEND-RESEAL-DIVERGENCE-1A (casi S1-S3): un ordine non parte con condizioni diverse da quelle della conferma che il cliente
# ha davanti; se qualcosa e cambiato si mostra la conferma aggiornata e si chiede un nuovo invio. Nessun ordine viene creato dalla prova.
# CHECKOUT-PAYMENT-FALLBACK-ORDER-1A (casi F1-F3): quando il pagamento scelto non e piu disponibile, la scelta automatica cade sul primo
# pagamento DISPONIBILE, non sul contrassegno appena disattivato, nemmeno se e la prima riga dell'elenco; se non ne resta nessuno
# non c'e nessun pagamento scelto e l'ordine non puo partire; una scelta valida del cliente resta quella.
# CHECKOUT-COD-CARRIER-SERVER-CHECK-1A (casi G1-G4): seconda difesa lato server. Il sigillo della bozza e la validazione usata alla
# creazione dell'ordine rifiutano il contrassegno se il vettore non lo offre (percentuale non maggiore di zero), leggendo dal database.
# La pagina di prova al posto di ordine.aspx chiama la stessa validazione del servizio sulla bozza sigillata e stampa l'esito.
# CHECKOUT-COD-REFUSAL-MESSAGE-1A (casi G1, G2*, G5): il rifiuto ha un motivo e un messaggio suoi ("Il contrassegno non e disponibile
# con questa spedizione..."), mostrato come errore al passaggio verso la conferma e, dopo un rifiuto alla creazione dell'ordine,
# sul passo "spedizione e pagamento" (una volta sola).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$it = [Globalization.CultureInfo]::GetCultureInfo('it-IT')
$svcRel = 'App_Code\CheckoutDraftService.vb'
$recRel = 'App_Code\CheckoutFailureRecoveryService.vb'
$files = @('carrello.aspx.vb', 'carrello.aspx', $svcRel, $recRel)
$repoBytes = @{}; foreach ($f in $files) { $repoBytes[$f] = [IO.File]::ReadAllBytes((Join-Path $root $f)) }
$fail = New-Object Collections.Generic.List[string]

function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }
$vbBom = ($repoBytes['carrello.aspx.vb'][0] -eq 0xEF)
$source = Get-Text $repoBytes['carrello.aspx.vb']
$markup = Get-Text $repoBytes['carrello.aspx']
$svcSource = Get-Text $repoBytes[$svcRel]

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
function Write-SiteFile([string]$rel, [string]$text) { $b = $repoBytes[$rel]; [IO.File]::WriteAllText((Join-Path $SitePath $rel), $text, (New-Object Text.UTF8Encoding(($b.Length -ge 3 -and $b[0] -eq 0xEF)))) }
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

# ---------- invio dell'ordine senza creare ordini (casi S1-S3) ----------
# Nella SOLA copia del sito LAB ordine.aspx viene sostituita da questa pagina di prova, che scrive la bozza sigillata in sessione e non fa altro.
$orderProbe = @'
<%@ Page Language="VB" EnableViewState="false" %>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs)
        Dim d As CheckoutDraftState = TryCast(Session("KeepStore:CheckoutDraft:Current"), CheckoutDraftState)
        Dim inv As System.Globalization.CultureInfo = System.Globalization.CultureInfo.InvariantCulture
        Response.ContentType = "text/plain"
        If d IsNot Nothing Then
            ' stessa validazione che ordine.aspx esegue prima di creare il documento, sulla bozza letta dal servizio
            Dim verdict As String = "valid=unknown reason=NotRun"
            Try
                Dim identity As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
                Dim sealed As CheckoutDraftState = Nothing
                If CheckoutDraftService.TryRead(HttpContext.Current, identity, d.RequestId, d.Fingerprint, sealed) Then
                    Using conn As New MySql.Data.MySqlClient.MySqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                        conn.Open()
                        Dim reason As CheckoutFailureReason = CheckoutFailureReason.CartInvalid
                        Dim ok As Boolean = CheckoutDraftService.ValidateAuthoritativeSelections(conn, Nothing, identity, sealed, reason)
                        verdict = "valid=" & ok.ToString() & " reason=" & If(ok, "none", reason.ToString())
                        ' come ordine.aspx quando la validazione fallisce: ritiro della richiesta, messaggio in sessione, ritorno al carrello
                        If Not ok AndAlso Request.QueryString("ksdispatch") = "1" AndAlso reason <> CheckoutFailureReason.ShippingAddressInvalid Then
                            If CheckoutFailureRecoveryService.RetireAndDispatch(HttpContext.Current, sealed.RequestId, reason, "ValidateDraft") Then Return
                            verdict = "valid=False reason=DispatchFailed"
                        End If
                    End Using
                Else
                    verdict = "valid=unknown reason=DraftNotReadable"
                End If
            Catch ex As Exception
                verdict = "valid=unknown reason=Exception"
            End Try
            Response.Write("KSPROBE " & verdict & " delivery=" & d.DeliveryMethodId.ToString(inv) & " payment=" & d.PaymentMethodId.ToString(inv) & " total=" & d.Total.ToString("0.00", inv) & " end")
        Else
            Response.Write("KSPROBE nodraft end")
        End If
        Response.End()
    End Sub
</script>
'@
$orderPageBytes = [IO.File]::ReadAllBytes((Join-Path $root 'ordine.aspx'))
function Install-OrderProbe { [IO.File]::WriteAllText((Join-Path $SitePath 'ordine.aspx'), $orderProbe, $utf8) }
function Restore-OrderPage {
    $p = Join-Path $SitePath 'ordine.aspx'
    [IO.File]::WriteAllBytes($p, $orderPageBytes)
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ne [Convert]::ToBase64String($orderPageBytes)) { throw 'ATTENZIONE: ordine.aspx della copia LAB non ripristinata' }
}
# Apre la pagina di prova e legge l'esito della validazione del servizio sulla bozza sigillata.
function Read-ServiceVerdict($browser) {
    Open-KsUrl $browser ($base + '/ordine.aspx') 300
    $b = [string](Invoke-KsJs $browser "document.body?document.body.innerText.replace(/\s+/g,' '):''")
    $m = [regex]::Match($b, 'KSPROBE valid=(\S+) reason=(\S+) delivery=(-?\d+) payment=(-?\d+)')
    if (-not $m.Success) { throw ('PAGINA_NON_VALIDA: pagina di prova senza esito (' + $b.Substring(0, [Math]::Min(80, $b.Length)) + ')') }
    return [pscustomobject]@{ valid = $m.Groups[1].Value; reason = $m.Groups[2].Value; payment = $m.Groups[4].Value }
}
$confirmJs = "(function(){var b=document.body.innerText.replace(/\s+/g,' ');var k=b.lastIndexOf('Riepilogo ordine');var s=k>=0?b.substring(k):b;var m=s.match(/\bTotale (-?[0-9.]+,[0-9]{2})/);var c=document.getElementById('chkTermsConsent');var a=document.getElementById('pnlCheckoutSubmitError');return JSON.stringify({confirm:!!document.querySelector('#MainContent_btInviaOrdine'),totalText:m?m[1]:'',cod:(!!window.__ksCod&&b.toLowerCase().indexOf(window.__ksCod)>=0),terms:c?c.checked:false,alert:(a&&a.getClientRects().length)?a.textContent.replace(/\s+/g,' ').trim():'',path:location.pathname.toLowerCase(),body:b.substring(0,120)});})()"
function Read-Confirm($browser) {
    $null = Invoke-KsJs $browser ('window.__ksCod=' + (ConvertTo-Json $script:codText) + ';1')
    $o = ConvertFrom-Json ([string](Invoke-KsJs $browser $confirmJs))
    $t = ''; if ([string]$o.totalText -ne '') { $t = (Num ([string]$o.totalText)).ToString('0.00', $inv) }
    return [pscustomobject]@{ confirm = [bool]$o.confirm; total = $t; cod = [bool]$o.cod; terms = [bool]$o.terms; alert = [string]$o.alert; path = [string]$o.path; body = [string]$o.body }
}
# Vettore con contrassegno, contrassegno scelto, conferma aperta: restituisce cio che la conferma mostra.
function Open-CodConfirm($browser) {
    Set-Carrier 1.5 4.5 1.6 0 3.5; $null = Read-Step2 $browser
    $o = Select-Option $browser 'gvPagamento' ([string]$payId)
    if ([string]$o.tbP -ne [string]$payId) { throw 'PAGINA_NON_VALIDA: contrassegno non selezionabile' }
    Go-Confirm $browser 'conferma col contrassegno'
    $c = Read-Confirm $browser
    if (-not $c.confirm -or $c.total -eq '' -or -not $c.cod) { throw 'PAGINA_NON_VALIDA: la conferma non mostra contrassegno e totale' }
    return $c
}
# Spunta le condizioni e invia. sent = il browser e arrivato alla pagina dell'ordine (qui: la pagina di prova).
function Send-Order($browser) {
    Start-Sleep -Milliseconds 1500
    $null = Invoke-KsJs $browser "(function(){var c=document.getElementById('chkTermsConsent');if(c&&!c.checked){c.click();}return 1;})()"
    Start-Sleep -Milliseconds 500
    $null = Invoke-KsJs $browser "(function(){var a=document.getElementById('pnlCheckoutSubmitError');if(a){a.setAttribute('data-ks-old','1');}return 1;})()"
    Invoke-KsClick $browser '#MainContent_btInviaOrdine' -NoWait
    for ($w = 0; $w -lt 30; $w++) {
        Start-Sleep -Milliseconds 500
        $o = $null; try { $o = ConvertFrom-Json ([string](Invoke-KsJs $browser "(function(){var b=document.body?document.body.innerText.replace(/\s+/g,' '):'';var a=document.getElementById('pnlCheckoutSubmitError');return JSON.stringify({path:location.pathname.toLowerCase(),ready:document.readyState,probe:(b.indexOf('KSPROBE')>=0&&b.indexOf(' end')>=0)?b:'',alert:(a&&!a.hasAttribute('data-ks-old')&&a.getClientRects().length)?a.textContent.replace(/\s+/g,' ').trim():'',confirm:!!document.querySelector('#MainContent_btInviaOrdine')});})()")) } catch { $o = $null }
        if ($null -eq $o) { continue }
        if ([string]$o.probe -ne '') {
            $mp = [regex]::Match([string]$o.probe, 'payment=(\d+) total=(-?[0-9.]+) end')
            if (-not $mp.Success) { throw ('PAGINA_NON_VALIDA: pagina di prova senza bozza (' + [string]$o.probe + ')') }
            return [pscustomobject]@{ sent = $true; payment = $mp.Groups[1].Value; total = $mp.Groups[2].Value; alert = '' }
        }
        if ([string]$o.path -match 'ordine\.aspx' -and [string]$o.ready -eq 'complete' -and $w -ge 6) { throw 'PAGINA_NON_VALIDA: arrivato a ordine.aspx ma non alla pagina di prova' }
        if ([string]$o.alert -ne '' -and $o.confirm -and [string]$o.ready -eq 'complete') { return [pscustomobject]@{ sent = $false; payment = ''; total = ''; alert = [string]$o.alert } }
    }
    $last = Read-Confirm $browser
    if ($last.path -notmatch 'carrello\.aspx') { throw ('PAGINA_NON_VALIDA: dopo l''invio pagina inattesa ' + $last.path) }
    return [pscustomobject]@{ sent = $false; payment = ''; total = ''; alert = $last.alert }
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
        'S1' {   # invio normale: nulla cambia tra conferma e invio -> l'ordine parte con cio che e stato mostrato
            Reset-Browser; $browser = $script:browser
            Install-OrderProbe
            try {
                $c = Open-CodConfirm $browser
                $r = Send-Order $browser
                if (-not $r.sent) { $bad.Add('S1 invio normale fermato: ' + $r.alert) }
                elseif ($r.payment -ne [string]$payId -or $r.total -ne $c.total) { $bad.Add('S1 ordine inviato con pagamento ' + $r.payment + ' e totale ' + $r.total + ', mostrati ' + [string]$payId + ' e ' + $c.total) }
            } finally { Restore-OrderPage; Reset-Browser }
        }
        'S2' {   # tra conferma e invio il vettore non accetta piu il contrassegno: nuova conferma obbligatoria
            Reset-Browser; $browser = $script:browser
            Install-OrderProbe
            try {
                $c = Open-CodConfirm $browser
                Set-Carrier 1.5 4.5 0 0 0
                $r = Send-Order $browser
                if ($r.sent) { $bad.Add('S2 ordine inviato senza nuova conferma: pagamento ' + $r.payment + ' e totale ' + $r.total + ', mostrati ' + [string]$payId + ' e ' + $c.total) }
                else {
                    $c2 = Read-Confirm $browser
                    if (-not $c2.confirm) { throw 'PAGINA_NON_VALIDA: S2 dopo il blocco non c''e la conferma' }
                    if ($r.alert -eq '') { $bad.Add('S2 nessun messaggio dopo il blocco dell''invio') }
                    if ($c2.total -eq $c.total -or $c2.cod) { $bad.Add('S2 la conferma dopo il blocco mostra ancora totale ' + $c2.total + ' e contrassegno ' + $c2.cod) }
                    if ($c2.terms) { $bad.Add('S2 casella delle condizioni ancora spuntata dopo il blocco') }
                    if ($bad.Count -eq 0) {
                        $r2 = Send-Order $browser
                        if (-not $r2.sent) { $bad.Add('S2 secondo invio fermato: ' + $r2.alert) }
                        elseif ($r2.payment -eq [string]$payId -or $r2.total -ne $c2.total) { $bad.Add('S2 secondo invio con pagamento ' + $r2.payment + ' e totale ' + $r2.total + ', mostrato totale ' + $c2.total) }
                    }
                }
            } finally { Restore-OrderPage; Reset-Browser }
        }
        'S3' {   # doppio invio dalla stessa conferma dopo un cambiamento: il secondo non deve passare senza che il cliente veda la conferma nuova
            Reset-Browser; $browser = $script:browser
            Install-OrderProbe
            try {
                $c = Open-CodConfirm $browser
                Set-Carrier 1.5 4.5 0 0 0
                Start-Sleep -Milliseconds 1500
                # primo invio fatto dalla pagina senza sostituirla (la risposta viene scartata): la pagina mostra ancora la conferma vecchia
                $first = [string](Invoke-KsJs $browser "(function(){var c=document.getElementById('chkTermsConsent');if(c&&!c.checked){c.click();}var f=document.forms[0];var b=document.querySelector('#MainContent_btInviaOrdine');if(!f||!b)return 'noform';var fd=new FormData(f);fd.append(b.name,b.value);var x=new XMLHttpRequest();x.open('POST',f.action,false);x.send(fd);return String(x.status);})()")
                if ($first -ne '200') { throw ('PAGINA_NON_VALIDA: S3 primo invio non riuscito (' + $first + ')') }
                $still = Read-Confirm $browser
                if (-not $still.confirm -or -not $still.cod -or $still.total -ne $c.total) { throw 'PAGINA_NON_VALIDA: S3 la pagina non mostra piu la conferma vecchia' }
                $r = Send-Order $browser
                if ($r.sent) { $bad.Add('S3 ordine inviato dalla conferma superata: pagamento ' + $r.payment + ' e totale ' + $r.total + ', la pagina mostrava ' + [string]$payId + ' e ' + $c.total) }
                else {
                    $c2 = Read-Confirm $browser
                    if (-not $c2.confirm) { throw 'PAGINA_NON_VALIDA: S3 dopo il blocco non c''e la conferma' }
                    if ($c2.cod -or $c2.total -eq $c.total) { $bad.Add('S3 la conferma dopo il blocco mostra ancora il contrassegno o il totale vecchio') }
                    if ($bad.Count -eq 0) {
                        $r2 = Send-Order $browser
                        if (-not $r2.sent) { $bad.Add('S3 invio dopo la nuova conferma fermato: ' + $r2.alert) }
                        elseif ($r2.payment -eq [string]$payId -or $r2.total -ne $c2.total) { $bad.Add('S3 invio dopo la nuova conferma con pagamento ' + $r2.payment + ' e totale ' + $r2.total + ', mostrato totale ' + $c2.total) }
                    }
                }
            } finally { Restore-OrderPage; Reset-Browser }
        }
        { $_ -in @('F1', 'F2', 'F2B', 'F3', 'G1') } {
            # F1: contrassegno PRIMA riga, scelto, poi non piu disponibile col vettore (percentuale 0 = ritiro), altre righe disponibili:
            #     la conferma mostra il primo pagamento disponibile e l'ordine parte con quello.
            # F2: contrassegno UNICO pagamento, poi non piu disponibile: non si arriva alla conferma e nessun ordine puo partire.
            # F2B: come F2, ma il vettore di ritiro ha una spesa fissa di contrassegno maggiore di zero.
            # F3: contrassegno prima riga e disponibile: senza scelta e senza pagamento predefinito la scelta automatica e la prima riga;
            #     la scelta del cliente su un'altra riga viene conservata fino all'invio.
            # G1: come F2, ma con la difesa della pagina spenta nella SOLA copia LAB: deve fermare il sigillo lato server, col suo messaggio.
            # L'ordine dei pagamenti (e in F2 l'elenco) viene cambiato sul LAB per la durata del caso e rimesso. Nessun ordine creato.
            $ordOrig = Get-Scalar "SELECT IFNULL(Ordinamento,'NULL') AS ksval FROM pagamentitipo WHERE id=$payId;"
            $ordMin = Get-Scalar "SELECT COALESCE(MIN(Ordinamento),0)-1 AS ksval FROM pagamentitipo WHERE AziendeID=$script:company AND Abilitato=1;"
            if ($ordOrig -notmatch '^(-?\d+|NULL)$' -or $ordMin -notmatch '^-?\d+$') { throw 'PAGINA_NON_VALIDA: ordinamento dei pagamenti non leggibile' }
            $others = ''
            if ($id -like 'F2*' -or $id -eq 'G1') {
                $others = Get-Scalar "SELECT COALESCE(GROUP_CONCAT(id ORDER BY id),'') AS ksval FROM pagamentitipo WHERE AziendeID=$script:company AND Abilitato=1 AND id<>$payId;"
                if ($others -notmatch '^-?\d+(,-?\d+)*$') { throw 'PAGINA_NON_VALIDA: nessun altro pagamento da disattivare' }
            }
            $seen = ''
            $installedVb = $null
            try {
                if ($id -eq 'G1') {
                    # si spegne la difesa della pagina sul testo GIA installato (una mutazione in corso resta al suo posto)
                    $installedVb = [IO.File]::ReadAllBytes((Join-Path $SitePath 'carrello.aspx.vb'))
                    $tv = Get-Text $installedVb; $key = 'ElseIf sel = False AndAlso gvPagamento.Rows.Count > 0 Then'
                    if ($tv.IndexOf($key, [StringComparison]::Ordinal) -lt 0) { throw 'PAGINA_NON_VALIDA: G1 punto della difesa della pagina non trovato' }
                    Write-SiteVb ($tv.Replace($key, 'ElseIf False Then'))
                }
                $null = Invoke-Sql "UPDATE pagamentitipo SET Ordinamento=$ordMin WHERE id=$payId;" -Write
                if ($others -ne '') { $null = Invoke-Sql "UPDATE pagamentitipo SET Abilitato=0 WHERE AziendeID=$script:company AND id IN ($others);" -Write }
                Reset-Browser
                Set-Carrier 1.5 4.5 1.6 0 3.5; $null = Read-Step2 $script:browser
                $o = Read-Options $script:browser
                $pays = @($o.pays)
                if ($pays.Count -lt 1 -or -not [bool]$pays[0].cod -or [bool]$pays[0].disabled) { throw 'PAGINA_NON_VALIDA: il contrassegno non e la prima riga disponibile dei pagamenti' }
                $alts = @($pays | Where-Object { -not $_.cod -and -not $_.disabled })
                if ($id -like 'F2*' -or $id -eq 'G1') { if ($pays.Count -ne 1) { throw ('PAGINA_NON_VALIDA: F2 attende il solo contrassegno, righe ' + $pays.Count) } }
                elseif ($alts.Count -lt 2) { throw ('PAGINA_NON_VALIDA: servono almeno due pagamenti oltre al contrassegno, trovati ' + $alts.Count) }
                $want = if ($id -eq 'F3') { [string]$alts[1].v } elseif ($id -eq 'F1') { [string]$alts[0].v } else { '' }
                $wantText = if ($want -ne '') { Get-Scalar "SELECT LOWER(TRIM(Descrizione)) AS ksval FROM pagamentitipo WHERE id=$want;" } else { '' }
                if ($id -eq 'F3') {
                    # scelta automatica iniziale: una sola riga disponibile spuntata, uguale al pagamento scelto; senza predefinito e la prima riga
                    $first = @($pays | Where-Object { $_.checked -and -not $_.disabled })
                    if ($first.Count -ne 1 -or [string]$first[0].v -ne [string]$o.tbP) { $bad.Add('scelta automatica iniziale incoerente (' + (Format-Options $o) + ')') }
                    elseif ((Get-Scalar "SELECT COUNT(*) AS ksval FROM pagamentitipo WHERE AziendeID=$script:company AND Abilitato=1 AND COALESCE(Predefinito,0)=1;") -eq '0' -and [string]$o.tbP -ne [string]$payId) { $bad.Add('senza pagamento predefinito la scelta automatica non e la prima riga disponibile (' + [string]$o.tbP + ')') }
                    $o = Select-Option $script:browser 'gvPagamento' $want
                    if ([string]$o.tbP -ne $want) { $bad.Add('la scelta del cliente non viene conservata: pagamento scelto [' + [string]$o.tbP + '] invece di ' + $want) }
                } else {
                    $o = Select-Option $script:browser 'gvPagamento' ([string]$payId)
                    if ([string]$o.tbP -ne [string]$payId) { throw 'PAGINA_NON_VALIDA: contrassegno non selezionabile' }
                    # il contrassegno smette di essere disponibile DOPO che la pagina e stata mostrata (percentuale 0 = ritiro)
                    if ($id -eq 'F2B') { Set-Carrier $null $null 0 2 0 } else { Set-Carrier $null $null $null $null $null }
                }
                Start-Sleep -Milliseconds 1500
                Invoke-KsClick $script:browser '#MainContent_btnVaiConfermaOrdine'; Start-Sleep -Milliseconds 3500
                $cf = Read-Confirm $script:browser
                if ($cf.path -notmatch 'carrello\.aspx') { throw ('PAGINA_NON_VALIDA: dopo il clic pagina inattesa ' + $cf.path) }
                $body = [string](Invoke-KsJs $script:browser "document.body.innerText.replace(/\s+/g,' ').toLowerCase()")
                $seen = 'conferma=' + [string]$cf.confirm + ' contrassegno=' + [string]$cf.cod + ' totale=' + [string]$cf.total
                if ($id -eq 'G1') {
                    if ($cf.confirm) { $bad.Add('con la difesa della pagina spenta il sigillo accetta il contrassegno su un vettore che non lo offre') }
                    else {
                        $note = ConvertFrom-Json ([string](Invoke-KsJs $script:browser "(function(){var e=document.querySelector('[id`$=lblAddressSelectionMessage]');if(!e||!e.getClientRects().length)return JSON.stringify({t:'',c:'',r:''});return JSON.stringify({t:e.textContent.replace(/\s+/g,' ').trim().toLowerCase(),c:e.className,r:e.getAttribute('role')||''});})()"))
                        $seen += ' avviso=[' + ([string]$note.t).Substring(0, [Math]::Min(60, ([string]$note.t).Length)) + '] classe=[' + [string]$note.c + '] ruolo=[' + [string]$note.r + ']'
                        if (([string]$note.t).IndexOf('disponibile con questa spedizione') -lt 0) { $bad.Add('il sigillo ferma la conferma ma senza il messaggio del contrassegno: [' + [string]$note.t + ']') }
                        elseif (([string]$note.c) -notmatch 'ks-alert-danger' -or [string]$note.r -ne 'alert') { $bad.Add('il messaggio del contrassegno non e mostrato come errore (classe [' + [string]$note.c + '], ruolo [' + [string]$note.r + '])') }
                        if ($body.IndexOf('non accetta ordini dal sito') -ge 0) { $bad.Add('compare ancora il messaggio generico del pagamento') }
                    }
                } elseif ($id -like 'F2*') {
                    if ($cf.confirm) {
                        $bad.Add('si arriva alla conferma senza un pagamento disponibile')
                        Install-OrderProbe
                        try { $r = Send-Order $script:browser; $seen += ' invio=' + [string]$r.sent + ' pagamento=' + [string]$r.payment; if ($r.sent) { $bad.Add('l''ordine partirebbe col pagamento ' + [string]$r.payment + ' (contrassegno ' + [string]$payId + ') che il vettore non offre') } } finally { Restore-OrderPage }
                    } else {
                        $o2 = Read-Options $script:browser
                        $seen += ' pagamento scelto=[' + [string]$o2.tbP + ']'
                        if ([string]$o2.tbP -ne '') { $bad.Add('senza pagamenti disponibili resta scelto il pagamento ' + [string]$o2.tbP) }
                        if ($body.IndexOf('seleziona un metodo di pagamento') -lt 0) { $bad.Add('manca l''invito a scegliere un metodo di pagamento') }
                        if (@($o2.pays | Where-Object { $_.checked }).Count -ne 0) { $bad.Add('una riga non disponibile resta spuntata') }
                    }
                } else {
                    if (-not $cf.confirm) { $bad.Add('la conferma non viene raggiunta') }
                    else {
                        if ($cf.cod -and $id -eq 'F1') { $bad.Add('la conferma mostra il contrassegno, che non e piu disponibile') }
                        $shown = [string](Invoke-KsJs $script:browser "(function(){var e=document.querySelector('[id`$=lblConfirmPaymentMethod]');return e?e.textContent.replace(/\s+/g,' ').trim().toLowerCase():'';})()")
                        $seen += ' pagamento mostrato=[' + $shown + ']'
                        if ($wantText -eq '' -or $shown.IndexOf($wantText) -lt 0 -or $shown.IndexOf('non disponibile') -ge 0) { $bad.Add('la conferma non mostra il pagamento atteso [' + $wantText + ']: [' + $shown + ']') }
                        Install-OrderProbe
                        try {
                            $r = Send-Order $script:browser
                            $seen += ' invio=' + [string]$r.sent + ' pagamento=' + [string]$r.payment + ' totale=' + [string]$r.total + ' atteso=' + $want
                            if (-not $r.sent) { $bad.Add('l''invio dalla conferma mostrata viene fermato: ' + [string]$r.alert) }
                            else {
                                if ($r.payment -ne $want) { $bad.Add('l''ordine partirebbe col pagamento ' + [string]$r.payment + ' invece di ' + $want) }
                                if ($r.total -ne $cf.total) { $bad.Add('l''ordine partirebbe con totale ' + $r.total + ', la conferma mostra ' + $cf.total) }
                            }
                        } finally { Restore-OrderPage }
                    }
                }
                Write-Host ('       ' + $id + ' visto: ' + $seen)
            } finally {
                if ($null -ne $installedVb) { [IO.File]::WriteAllBytes((Join-Path $SitePath 'carrello.aspx.vb'), $installedVb) }
                $null = Invoke-Sql "UPDATE pagamentitipo SET Ordinamento=$ordOrig WHERE id=$payId;" -Write
                if ($others -ne '') { $null = Invoke-Sql "UPDATE pagamentitipo SET Abilitato=1 WHERE AziendeID=$script:company AND id IN ($others);" -Write }
                if ((Get-Scalar "SELECT IFNULL(Ordinamento,'NULL') AS ksval FROM pagamentitipo WHERE id=$payId;") -ne $ordOrig) { Write-Host '  ATTENZIONE: ordinamento del pagamento non ripristinato sul LAB' }
                if ($others -ne '' -and (Get-Scalar "SELECT COALESCE(GROUP_CONCAT(id ORDER BY id),'') AS ksval FROM pagamentitipo WHERE AziendeID=$script:company AND Abilitato=1 AND id<>$payId;") -ne $others) { Write-Host '  ATTENZIONE: pagamenti non riabilitati sul LAB' }
                Reset-Browser
            }
        }
        { $_ -in @('G2', 'G2N', 'G2M', 'G3', 'G3P', 'G4', 'G5') } {
            # Bozza sigillata con un vettore che offre il contrassegno; poi (G2*) la percentuale del vettore diventa 0 / NULL / negativa.
            # G3: nessun cambiamento; G3P: percentuale minima positiva; G4: pagamento normale e percentuale 0. Nessun ordine creato.
            # Dopo molte ricompilazioni il sito LAB si riavvia e la sessione (con la bozza) si perde: in quel caso il caso si ripete una volta.
            for ($attempt = 1; $attempt -le 2; $attempt++) {
            try {
                Reset-Browser
                if ($id -eq 'G3P') { Set-Carrier 1.5 4.5 0.004 0.125 0 } else { Set-Carrier 1.5 4.5 1.6 0 3.5 }
                $null = Read-Step2 $script:browser
                $o = Read-Options $script:browser
                $chosen = [string]$payId
                if ($id -eq 'G4') {
                    $alts = @($o.pays | Where-Object { -not $_.cod -and -not $_.disabled })
                    if ($alts.Count -lt 1) { throw 'PAGINA_NON_VALIDA: nessun pagamento normale disponibile' }
                    $chosen = [string]$alts[0].v
                }
                $o = Select-Option $script:browser 'gvPagamento' $chosen
                if ([string]$o.tbP -ne $chosen) { if ($attempt -eq 1) { continue }; throw 'PAGINA_NON_VALIDA: pagamento non selezionabile' }
                # in questo momento il vettore offre il contrassegno: la conferma deve essere raggiunta
                $reached = $true
                try { Go-Confirm $script:browser ('conferma del caso ' + $id) } catch { if (([string]$_.Exception.Message) -match 'conferma non raggiunta') { $reached = $false } else { throw } }
                if (-not $reached) { $bad.Add('un ordine valido non arriva alla conferma (pagamento ' + $chosen + ')'); break }
                if ($id -eq 'G2' -or $id -eq 'G4' -or $id -eq 'G5') { Set-Carrier 1.5 4.5 0 0 0 }
                elseif ($id -eq 'G2N') { Set-Carrier 1.5 4.5 $null 0 0 }
                elseif ($id -eq 'G2M') { Set-Carrier 1.5 4.5 -1 0 0 }
                Install-OrderProbe
                if ($id -eq 'G5') {
                    # ritorno al carrello dopo il rifiuto alla creazione dell'ordine: passo, messaggio, uso unico
                    $g5 = $null
                    try {
                        Open-KsUrl $script:browser ($base + '/ordine.aspx?ksdispatch=1') 300; Start-Sleep -Milliseconds 2500
                        $g5js = "(function(){var a=document.getElementById('pnlCheckoutSubmitError');var b=document.body?document.body.innerText.replace(/\s+/g,' '):'';return JSON.stringify({path:location.pathname.toLowerCase(),q:location.search,send:!!document.querySelector('#MainContent_btInviaOrdine'),review:!!document.querySelector('#MainContent_btnVaiConfermaOrdine'),alert:(a&&a.getClientRects().length)?a.textContent.replace(/\s+/g,' ').trim().toLowerCase():'',probe:b.indexOf('KSPROBE')>=0?b.substring(0,90):''});})()"
                        $g5 = ConvertFrom-Json ([string](Invoke-KsJs $script:browser $g5js))
                    } finally { Restore-OrderPage }
                    if ([string]$g5.probe -match 'nodraft' -and $attempt -eq 1) { continue }
                    Write-Host ('       G5 visto: pagina=' + [string]$g5.path + [string]$g5.q + ' invia=' + [string]$g5.send + ' rivedi=' + [string]$g5.review + ' avviso=[' + ([string]$g5.alert).Substring(0, [Math]::Min(70, ([string]$g5.alert).Length)) + ']')
                    if ([string]$g5.probe -ne '') { $bad.Add('dopo il rifiuto non si torna al carrello: ' + [string]$g5.probe) }
                    elseif ([string]$g5.path -notmatch 'carrello\.aspx') { $bad.Add('dopo il rifiuto pagina inattesa ' + [string]$g5.path) }
                    else {
                        if ([bool]$g5.send -or -not [bool]$g5.review) { $bad.Add('dopo il rifiuto il cliente non e sul passo spedizione e pagamento (invia=' + [string]$g5.send + ' rivedi=' + [string]$g5.review + ')') }
                        if (([string]$g5.alert).IndexOf('disponibile con questa spedizione') -lt 0) { $bad.Add('dopo il rifiuto manca il messaggio del contrassegno: [' + [string]$g5.alert + ']') }
                        Open-KsUrl $script:browser ($base + '/carrello.aspx?checkoutfailed=1') 300; Start-Sleep -Milliseconds 1500
                        $again = ConvertFrom-Json ([string](Invoke-KsJs $script:browser $g5js))
                        if (([string]$again.alert).IndexOf('disponibile con questa spedizione') -ge 0) { $bad.Add('il messaggio del rifiuto ricompare ricaricando la pagina') }
                    }
                    break
                }
                $v = $null
                try { $v = Read-ServiceVerdict $script:browser } catch { if ($attempt -eq 2 -or ([string]$_.Exception.Message) -notmatch 'nodraft') { throw } } finally { Restore-OrderPage }
                if ($null -eq $v) { continue }
                Write-Host ('       ' + $id + ' visto: valid=' + $v.valid + ' reason=' + $v.reason + ' pagamento=' + $v.payment)
                if ($v.payment -ne $chosen) { throw 'PAGINA_NON_VALIDA: la bozza non contiene il pagamento scelto' }
                if ($id -in @('G2', 'G2N', 'G2M')) {
                    if ($v.valid -ne 'False' -or $v.reason -ne 'CashOnDeliveryNotOffered') { $bad.Add('la validazione del servizio accetta il contrassegno con un vettore che non lo offre (valid=' + $v.valid + ' reason=' + $v.reason + ')') }
                } elseif ($v.valid -ne 'True') { $bad.Add('la validazione del servizio rifiuta un ordine valido (valid=' + $v.valid + ' reason=' + $v.reason + ')') }
                break
            } finally { Reset-Browser }
            }
        }
        'C5' {   # valori di oggi a due decimali: stessi importi di prima
            Set-Carrier 1.5 4.5 1.6 0 3.5; $s = Read-Step2 $browser
            $ei = Money ([Math]::Max($script:imp * 1.5D / 100D, 4.5D)); $ec = Money ([Math]::Max($script:baseAmount * 1.6D / 100D, 3.5D))
            if ($s.ins -ne $ei) { $bad.Add('assicurazione "' + $s.ins + '", attesa "' + $ei + '"') }
            if ((CodCost $s) -ne $ec) { $bad.Add('contrassegno "' + (CodCost $s) + '", atteso "' + $ec + '"') }
        }
        default { throw ('PAGINA_NON_VALIDA: caso sconosciuto ' + $id) }
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
        $caseList = @('V1', 'C1', 'C2', 'C2B', 'C4', 'C5', 'C3', 'I1', 'I2', 'I3', 'D1', 'S1', 'S2', 'S3', 'F1', 'F2', 'F2B', 'F3', 'G1', 'G2', 'G2N', 'G2M', 'G3', 'G3P', 'G4', 'G5')
        if ($Cases -ne '') { $caseList = @($Cases.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }); $SkipMutants = ($MutantFilter -eq '') }   # esecuzione parziale (messa a punto, o mutazioni in piu passate con -MutantFilter)
        foreach ($c in $caseList) {
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
            @{ Id = 'M20_PAYMENT_ALWAYS_RESTORED'; Case = 'D1'; Expect = 'D1 pagamento scelto dal cliente'; Old = 'If Not IsCheckoutOptionGroupPosted("pagamento") Then'; New = 'If True Then' },
            @{ Id = 'M21_SEND_WITHOUT_RECONFIRM'; Case = 'S2'; Expect = 'S2 ordine inviato senza nuova conferma'; Old = 'If Not shownIsCurrent OrElse Not HasSameCheckoutConditions(shownDraft, draft) Then'; New = 'If False Then' },
            @{ Id = 'M22_SEND_ALWAYS_BLOCKED'; Case = 'S1'; Expect = 'S1 invio normale fermato'; Old = 'If Not shownIsCurrent OrElse Not HasSameCheckoutConditions(shownDraft, draft) Then'; New = 'If True Then' },
            @{ Id = 'M23_SHOWN_PAGE_NOT_BOUND'; Case = 'S3'; Expect = 'S3 ordine inviato dalla conferma superata'; Old = 'String.Equals(shownDraft.Fingerprint, shownKey, StringComparison.Ordinal)'; New = 'True' },
            @{ Id = 'M24_COD_ALWAYS_CANDIDATE'; Case = 'F1'; Old = 'If firstSelectableIndex = -1 AndAlso rb IsNot Nothing AndAlso RbGetEnabled(rb) Then'; New = 'If firstSelectableIndex = -1 AndAlso rb IsNot Nothing AndAlso (RbGetEnabled(rb) OrElse (lblContrassegno IsNot Nothing AndAlso Val(lblContrassegno.Text) = 1)) Then' },
            @{ Id = 'M25_LAST_CANDIDATE_WINS'; Case = 'F1'; Old = 'If firstSelectableIndex = -1 AndAlso rb IsNot Nothing AndAlso RbGetEnabled(rb) Then'; New = 'If rb IsNot Nothing AndAlso RbGetEnabled(rb) Then' },
            @{ Id = 'M26_STALE_PAYMENT_KEPT'; Case = 'F2'; Old = 'ElseIf sel = False AndAlso gvPagamento.Rows.Count > 0 Then'; New = 'ElseIf False Then' },
            @{ Id = 'M27_ONLY_COST_CLEARED'; Case = 'F2B'; Old = '        Me.tbPagamenti.Text = String.Empty'; New = '        Me.tbPagamenti.Text = Me.tbPagamenti.Text' },
            @{ Id = 'M28_VALID_CHOICE_CLEARED'; Case = 'F3'; Old = 'ElseIf sel = False AndAlso gvPagamento.Rows.Count > 0 Then'; New = 'ElseIf gvPagamento.Rows.Count > 0 Then' },
            @{ Id = 'M29_SERVICE_ALWAYS_COMPATIBLE'; Case = 'G2'; File = $svcRel; Old = 'Return offerRows = 1'; New = 'Return True' },
            @{ Id = 'M30_ORDER_TIME_CHECK_REMOVED'; Case = 'G2N'; File = $svcRel; Old = 'If Not IsCashOnDeliveryCompatible(connection, transaction, identity.CompanyId, draft.PaymentMethodId, draft.DeliveryMethodId) Then'; New = 'If False Then' },
            @{ Id = 'M31_SEALING_CHECK_REMOVED'; Case = 'G1'; Old = 'If Not CheckoutDraftService.IsCashOnDeliveryCompatible(connection, Nothing, identity.CompanyId, paymentId, deliveryId) Then'; New = 'If False Then' },
            @{ Id = 'M32_NULL_PERCENT_ACCEPTED'; Case = 'G2N'; File = $svcRel; Old = 'v.ContrassegnoPercentuale > 0'; New = 'COALESCE(v.ContrassegnoPercentuale, 1) > 0' },
            @{ Id = 'M33_NEGATIVE_PERCENT_ACCEPTED'; Case = 'G2M'; File = $svcRel; Old = 'v.ContrassegnoPercentuale > 0'; New = 'v.ContrassegnoPercentuale <> 0' },
            @{ Id = 'M34_ORDINARY_PAYMENT_REJECTED'; Case = 'G4'; File = $svcRel; Old = 'If codRows = 0 Then Return True'; New = 'If codRows = 0 Then Return False' },
            @{ Id = 'M35_SEALING_GENERIC_REASON'; Case = 'G1'; Expect = 'il sigillo ferma la conferma ma senza il messaggio del contrassegno'; Old = "identity.CompanyId, paymentId, deliveryId) Then`r`n            failureReason = CheckoutFailureReason.CashOnDeliveryNotOffered"; New = "identity.CompanyId, paymentId, deliveryId) Then`r`n            failureReason = CheckoutFailureReason.PaymentMethodNotAllowed" },
            @{ Id = 'M36_SERVICE_GENERIC_REASON'; Case = 'G2'; File = $svcRel; Old = 'failureReason = CheckoutFailureReason.CashOnDeliveryNotOffered'; New = 'failureReason = CheckoutFailureReason.PaymentMethodNotAllowed' },
            @{ Id = 'M37_MESSAGE_BRANCH_REMOVED'; Case = 'G5'; Expect = 'dopo il rifiuto manca il messaggio del contrassegno'; File = $recRel; Old = 'Case CheckoutFailureReason.CashOnDeliveryNotOffered'; New = 'Case CType(99, CheckoutFailureReason)' },
            @{ Id = 'M38_RETURN_TO_CONFIRM_STEP'; Case = 'G5'; Expect = 'dopo il rifiuto il cliente non e sul passo spedizione e pagamento'; Old = "                 CheckoutFailureReason.CashOnDeliveryNotOffered,`r`n"; New = '' },
            @{ Id = 'M39_SEALING_NOTICE_NOT_AN_ERROR'; Case = 'G1'; Expect = 'il messaggio del contrassegno non e mostrato come errore'; Old = 'draftFailure = CheckoutFailureReason.CashOnDeliveryNotOffered)'; New = 'False)' }
        )
        foreach ($m in $mutants) {
            if ($MutantFilter -ne '' -and $m.Id -notmatch $MutantFilter) { continue }
            $isSvc = $m.ContainsKey('File')
            $srcText = if ($isSvc) { Get-Text $repoBytes[$m.File] } else { $source }
            if (([regex]::Matches($srcText, [regex]::Escape($m.Old))).Count -ne 1) { $mutantFail.Add($m.Id + ' ancora non unica'); continue }
            $mutated = $srcText.Replace($m.Old, $m.New)
            if ($m.ContainsKey('Old2')) { if (([regex]::Matches($source, [regex]::Escape($m.Old2))).Count -ne 1) { $mutantFail.Add($m.Id + ' seconda parte ancora non unica'); continue }; $mutated = $mutated.Replace($m.Old2, $m.New2) }
            if ($isSvc) { Write-SiteFile $m.File $mutated } else { Write-SiteVb $mutated }
            # un file di App_Code riavvia il sito: lo si lascia ripartire prima del caso, altrimenti i primi clic vanno persi
            if ($isSvc) { try { Open-KsUrl $script:browser ($base + '/Default.aspx') 300 } catch { }; Start-Sleep -Seconds 10 }
            try {
                $mb = @(Test-Case $m.Case $script:browser)
                if ($mb.Count -eq 0) { $mutantFail.Add($m.Id + ' sopravvive al caso ' + $m.Case) }
                elseif ($m.ContainsKey('Expect') -and -not ($mb[0]).StartsWith($m.Expect)) { $mutantFail.Add($m.Id + ' fallisce per un altro motivo: ' + $mb[0]) } else { Write-Host ('  ucciso ' + $m.Id + ' (' + $m.Case + '): ' + $mb[0]) }
            } catch { $mutantFail.Add($m.Id + ' errore: ' + $_.Exception.Message) }
            if ($isSvc) { Sync-Site }   # il servizio torna com'era prima della mutazione successiva
        }
        Sync-Site
        $after = @(Test-Case 'C1' $script:browser)
        if ($after.Count -ne 0) { $mutantFail.Add('dopo il ripristino il sito non torna verde: ' + $after[0]) }
    }
} finally {
    if ($browser) { Stop-KsBrowser $browser }
    try { Restore-OrderPage } catch { Write-Host '  ATTENZIONE: ordine.aspx della copia LAB non ripristinata' }
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
if ($Cases -ne '' -or $MutantFilter -ne '') { Write-Host ('CART_SHIPPING_NUMERIC PARZIALE OK (casi: ' + $(if ($Cases -ne '') { $Cases } else { 'tutti' }) + '; mutazioni: ' + $(if ($SkipMutants) { 'nessuna' } elseif ($MutantFilter -ne '') { $MutantFilter } else { 'tutte' }) + ')') } elseif ($SkipMutants) { Write-Host 'CART_SHIPPING_NUMERIC OK (mutazioni saltate)' } else { Write-Host 'CART_SHIPPING_NUMERIC OK (23 mutazioni uccise sul sito LAB)' }
exit 0
