[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    # Compila e lancia Tools\CartTotalsLabHarness.vb contro il database LAB LOCALE (127.0.0.1:13317) con l'account dedicato.
    [switch]$Lab,
    [string]$CredentialFile = (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'),
    [string]$LabCa = 'C:\Temp\KeepStoreRegOrderLab-20261025\mysql\data\ca.pem'
)

# WEB-TOTALS-CART-READ-1A: il carrello legge imponibile, IVA e totale dalla routine di database Carrello_Totali (fonte unica).
# Parte statica (nessuna connessione): impone la forma del servizio e dei punti di integrazione, poi la rimette alla prova
# con mutazioni dei sorgenti (ogni mutazione deve far fallire almeno un controllo). Con -Lab compila ed esegue l'harness
# contro la routine reale del LAB. Solo Windows PowerShell 5.1, ASCII. Nessun segreto, nessuna scrittura sul repository.
$ErrorActionPreference = 'Stop'
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$service = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code\CartTotalsService.vb'))
$page = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'carrello.aspx.vb'))
$order = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'ordine.aspx.vb'))
$script:total = 0
$script:failed = 0
function Check([bool]$ok, [string]$name) {
    $script:total++
    if ($ok) { 'PASS ' + $name } else { $script:failed++; 'FAIL ' + $name }
}
function Count([string]$text, [string]$pattern) { return [regex]::Matches($text, $pattern).Count }
function Slice([string]$text, [string]$startPattern, [string]$endPattern) {
    $m = [regex]::Match($text, '(?s)' + $startPattern + '.*?' + $endPattern)
    if ($m.Success) { return $m.Value }
    return ''
}

# Ritorna l'elenco dei controlli falliti sui sorgenti passati (usato anche dalle mutazioni).
function Test-Sources([string]$svc, [string]$pg, [string]$ord) {
    $f = New-Object System.Collections.Generic.List[string]
    function Need([bool]$ok, [string]$name) { if (-not $ok) { $f.Add($name) } }

    # --- Servizio ---
    $names = @('?pLoginId', '?pCostoAssicurazione', '?pCostoSpedizione', '?pArrotondamento', '?pCostoPagamento', '?pUtenteAbilitatoRC', '?pIvaVettore', '?pBuonoScontoTotale', '?pBuonoScontoValoreIva', '?pTotMerce', '?pTotIva', '?pTotale')
    $last = -1; $inOrder = $true
    foreach ($n in $names) { $i = $svc.IndexOf('"' + $n + '"'); if ($i -le $last) { $inOrder = $false }; $last = $i }
    Need $inOrder 'S01 i 12 parametri della routine nell''ordine della firma'
    Need ($svc.Contains('Friend Const ProcedureName As String = "Carrello_Totali"')) 'S02 chiama la routine Carrello_Totali'
    Need ($svc.Contains('command.CommandType = CommandType.StoredProcedure')) 'S03 CommandType.StoredProcedure'
    Need ($svc.Contains('builder.CheckParameters = False')) 'S04 metadati del connettore spenti (parametri completi, tipizzati, in ordine)'
    Need ((Count $svc 'parameter\.Direction = ParameterDirection\.Output') -eq 1) 'S05 tre OUT DECIMAL tramite un solo helper con Direction Output'
    Need ((Count $svc 'AddDecimalOutput\(command, "\?p') -eq 3) 'S06 tre parametri OUT'
    Need ($svc.Contains('If IsNull(outMerce.Value) OrElse IsNull(outIva.Value) OrElse IsNull(outTotale.Value) Then Return False')) 'S07 un OUT NULL = non disponibile (mai zero)'
    Need ($svc.Contains('input.LoginId <= 0 Then Return False')) 'S08 LoginId non valido = non disponibile'
    Need ((Count $svc 'Catch ex As Exception') -ge 2) 'S09 ogni errore del connettore e catturato'
    Need ($svc -match 'Convert\.ToDecimal\(out(Merce|Iva|Totale)\.Value, CultureInfo\.InvariantCulture\)') 'S10 lettura Decimal invariante'
    $logSub = Slice $svc 'Private Shared Sub LogFailure' 'End Sub'
    Need (($logSub -ne '') -and ($logSub -notmatch 'procedureName|input\.|command\.|ex\.Message|ex\.ToString')) 'S11 log sanitizzato: solo tipo di eccezione e numero MySQL'
    Need ($svc -notmatch 'Return New CartTotalsResult\(\) With \{\s*\.Merce = 0') 'S12 nessun risultato predefinito'
    Need (($svc -notmatch 'Math\.Round') -and ($svc -notmatch 'Decimal\.Round')) 'S13 il servizio non arrotonda ne ricalcola'
    Need ($svc.Contains('If(isCouponArticleOrder, 0D, insuranceCost)') -and $svc.Contains('If(isCouponArticleOrder, 0D, shippingCost)') -and $svc.Contains('If(isCouponArticleOrder, 0D, paymentCost)')) 'S14 coupon-articolo: tre costi azzerati come nell''ordine'

    # --- Pagina ---
    $helper = Slice $pg 'Private Function TryReadDbTotals' 'End Function'
    $apply = Slice $pg 'Private Sub ApplyDbTotalsToLabels' 'End Sub'
    $capture = Slice $pg 'Private Function TryCaptureAuthoritativeCheckoutDraft' 'End Function'
    $leggi = Slice $pg 'Public Sub LeggiPagamenti' 'End Sub'
    $pre = Slice $pg 'Protected Sub Page_PreRenderComplete' 'End Sub'
    Need ($pg -notmatch 'calcola_iva') 'P01 calcola_iva rimosso: nessun ricalcolo dell''IVA nel web'
    Need (($pg -notmatch 'totaleTemp') -and ($pg -notmatch 'ivaCalcolata') -and ($pg -notmatch 'ivaNuova') -and ($pg -notmatch 'totaleDoc\b')) 'P02 nessuna somma di etichette per il totale'
    Need ((Count $pg 'lblTotale\.Text =') -eq 3) 'P03 lblTotale scritto solo da: DB, segnaposto, bozza sigillata'
    Need ((Count $pg 'lblIva\.Text =') -eq 2) 'P04 lblIva scritto solo da: DB e segnaposto'
    Need (($apply -ne '') -and $apply.Contains('lblIva.Text = FormatCurrencyIt(CDbl(totals.Iva))') -and $apply.Contains('lblTotale.Text = FormatCurrencyIt(CDbl(totals.Totale))')) 'P05 etichette dal risultato del database'
    Need (($apply -ne '') -and $apply.Contains('_cartTotalsUnavailable = True') -and $apply.Contains('CartTotalsPlaceholder')) 'P06 indisponibilita: stato sul server e segnaposto (mai zero)'
    Need ($pg.Contains('Private Const CartTotalsPlaceholder As String = "n/d"')) 'P07 segnaposto neutro'
    Need (($helper -ne '') -and ($helper -notmatch 'Math\.Round') -and $helper.Contains('CartTotalsService.TryCompute(input, result, HttpContext.Current)')) 'P08 helper: solo servizio, nessun ripiego sul web'
    Need (($helper -ne '') -and $helper.Contains('IsCouponArticleOrder()') -and $helper.Contains('"Coupon_Arrotondamento"') -and $helper.Contains('"AbilitatoIvaReverseCharge"') -and $helper.Contains('"Iva_Vettori"') -and $helper.Contains('lblSpeseAss') -and $helper.Contains('lblSpeseSped') -and $helper.Contains('lblPagamento')) 'P09 gli ingressi sono quelli dell''ordine'
    Need (($helper -ne '') -and $helper.Contains('Not model.IsAuthenticated') -and $helper.Contains('CartTotalsOutcome.NotApplicable') -and $helper.Contains('Not model.LoadSucceeded')) 'P10 anonimo: non applicabile; lettura del carrello fallita: non disponibile'
    Need (($capture -ne '') -and $capture.Contains('If _cartTotalsUnavailable Then') -and $capture.Contains('CheckoutFailureReason.TechnicalTransient')) 'P11 bozza: stato non disponibile blocca il sigillo'
    Need (($capture -ne '') -and $capture.Contains('CartTotalsService.TryCompute(totalsInput, dbTotals, HttpContext.Current)') -and $capture.Contains('If shownTotal <> dbTotals.Totale Then') -and $capture.Contains('CheckoutFailureReason.CartChanged')) 'P12 bozza: ricalcolo dal database e uguaglianza al centesimo del totale mostrato'
    Need (($capture -ne '') -and $capture.Contains('Dim subtotal As Decimal = dbTotals.Merce') -and $capture.Contains('Dim vat As Decimal = dbTotals.Iva') -and $capture.Contains('Dim total As Decimal = dbTotals.Totale') -and $capture.Contains('.Total = total')) 'P13 bozza: merce, IVA e totale dal database'
    Need (($capture -ne '') -and ($capture -notmatch 'calculatedTotal') -and ($capture -notmatch '0\.02D')) 'P14 bozza: il controllo web ''somma +- 0,02'' non c''e piu'
    Need (($capture -ne '') -and $capture.Contains('CartTotalsInput.ForOrder(') -and $capture.Contains('"Ordine_TotaleBuonoScontoImponibile"') -and $capture.Contains('"Ordine_BuonoScontoValoreIva"') -and $capture.Contains('IsCouponArticleOrder()')) 'P15 bozza: stessi ingressi sigillati che l''ordine passera'
    Need (($leggi -ne '') -and $leggi.Contains('TryReadDbTotals(False, False, False, baseTotals)') -and $leggi.Contains('CDbl(baseTotals.Merce) + spedD + assD + CDbl(baseTotals.Iva)') -and $leggi.Contains('ApplyDbTotalsToLabels()')) 'P16 costo del pagamento: base dal database (senza pagamento, buono e arrotondamento); totale dal database'
    Need (($pre -ne '') -and $pre.Contains('If Not IsCheckoutConfirmStep() Then ApplyDbTotalsToLabels()')) 'P17 dopo il sigillo (passo di conferma) il totale non si ricalcola'
    Need ((Count $pg 'ResolveCouponVatValue\(\)') -eq 4) 'P18 una sola aliquota del buono: definizione + scorporo + ingressi del servizio + sessione dell''ordine'
    Need (($pre -ne '') -and ($pre -notmatch 'preleva_ValoreIva\(-1\)') -and ($pre -notmatch 'ivaUtentePerc')) 'P19 lo scorporo del buono non usa un''altra aliquota'
    Need (($pg.Contains('Session("Ordine_BuonoScontoValoreIva") = ResolveCouponVatValue()'))) 'P20 la sessione dell''ordine usa la stessa aliquota'
    Need ($pg.Contains('Return Session("Coupon_idArticolo") IsNot Nothing AndAlso GetSessionInt("Coupon_idArticolo", 0) > 0')) 'P21 condizione coupon-articolo come nell''ordine'

    # --- Ordine: la chiamata mirror non deve essere cambiata (le regole replicate nel carrello restano vere) ---
    Need ($ord.Contains('Dim isCoupon As Boolean = (Not (Session("Coupon_idArticolo") Is Nothing) AndAlso GetSessionInt("Coupon_idArticolo", 0) > 0)')) 'O01 ordine: condizione isCoupon'
    Need ($ord.Contains('AddDecimalParameter(cmd, "?pCostoAssicurazione", If(isCoupon, 0D, SpeseAss))') -and $ord.Contains('AddDecimalParameter(cmd, "?pCostoSpedizione", If(isCoupon, 0D, SpeseSped))') -and $ord.Contains('AddDecimalParameter(cmd, "?pCostoPagamento", If(isCoupon, 0D, SpesePag))')) 'O02 ordine: costi azzerati per il coupon-articolo'
    Need ($ord.Contains('cmd.Parameters.AddWithValue("?pArrotondamento", If(Session("Coupon_Arrotondamento") Is Nothing, 0, DbVal(Session("Coupon_Arrotondamento"))))') -and $ord.Contains('cmd.Parameters.AddWithValue("?pUtenteAbilitatoRC", DbVal(Session("AbilitatoIvaReverseCharge")))') -and $ord.Contains('cmd.Parameters.AddWithValue("?pIvaVettore", DbVal(Session("Iva_Vettori")))')) 'O03 ordine: arrotondamento, reverse charge e IVA vettore dalla sessione'
    Need ($ord.Contains('SpeseSped = checkoutDraft.ShippingCost') -and $ord.Contains('SpeseAss = checkoutDraft.InsuranceCost') -and $ord.Contains('SpesePag = checkoutDraft.PaymentCost') -and $ord.Contains('Session("Ordine_BuonoScontoValoreIva") = checkoutDraft.CouponVatValue')) 'O04 ordine: ingressi dalla bozza sigillata'
    return ,$f
}

$base = Test-Sources $service $page $order
if ($base.Count -eq 0) { Check $true 'sorgenti: tutti i controlli statici (S/P/O) passano' } else { foreach ($n in $base) { Check $false ('sorgenti: ' + $n) } }

# --- Mutazioni: ogni modifica dei sorgenti deve far fallire almeno un controllo ---
function Mutate([string]$text, [string]$old, [string]$new) {
    if (-not $text.Contains($old)) { return $null }
    $i = $text.IndexOf($old)
    return $text.Substring(0, $i) + $new + $text.Substring($i + $old.Length)
}
$mutations = @(
    @{ N = 'ricompare calcola_iva nel web'; T = 'page'; Old = 'Private Function ResolveCouponVatValue() As Double'; New = 'Function calcola_iva() As Double' + "`r`n" + 'Return 0' + "`r`n" + 'End Function' + "`r`n" + 'Private Function ResolveCouponVatValue() As Double' },
    @{ N = 'bozza non blocca piu lo stato non disponibile'; T = 'page'; Old = 'If _cartTotalsUnavailable Then'; New = 'If False Then' },
    @{ N = 'metadati del connettore riaccesi'; T = 'service'; Old = 'builder.CheckParameters = False'; New = 'builder.CheckParameters = True' },
    @{ N = 'parametri scambiati (IVA vettore e IVA buono)'; T = 'service'; Old = '"?pIvaVettore"'; New = '"?pBuonoScontoValoreIva"' },
    @{ N = 'OUT NULL non piu rifiutato'; T = 'service'; Old = 'If IsNull(outMerce.Value) OrElse IsNull(outIva.Value) OrElse IsNull(outTotale.Value) Then Return False'; New = '' },
    @{ N = 'coupon-articolo non azzera la spedizione'; T = 'service'; Old = 'If(isCouponArticleOrder, 0D, shippingCost)'; New = 'shippingCost' },
    @{ N = 'il helper non usa piu la condizione coupon'; T = 'page'; Old = '        couponVatValue,' + "`r`n" + '        IsCouponArticleOrder())'; New = '        couponVatValue,' + "`r`n" + '        False)' },
    @{ N = 'totale scritto da una somma di etichette'; T = 'page'; Old = "        Case CartTotalsOutcome.Unavailable" + "`r`n" + "            _cartTotalsUnavailable = True" + "`r`n" + "            lblIva.Text = CartTotalsPlaceholder"; New = "        Case CartTotalsOutcome.Unavailable" + "`r`n" + "            lblTotale.Text = FormatCurrencyIt(SafeMoney(lblImponibile.Text, 0) + SafeMoney(lblIva.Text, 0))" + "`r`n" + "            _cartTotalsUnavailable = True" + "`r`n" + "            lblIva.Text = CartTotalsPlaceholder" },
    @{ N = 'ricalcolo dopo il sigillo (passo di conferma)'; T = 'page'; Old = 'If Not IsCheckoutConfirmStep() Then ApplyDbTotalsToLabels()'; New = 'ApplyDbTotalsToLabels()' },
    @{ N = 'il servizio registra il nome della routine'; T = 'service'; Old = 'Dim detail As String = "Error type: " & ex.GetType().Name & "."'; New = 'Dim detail As String = "Error type: " & ex.GetType().Name & ". " & ex.Message' },
    @{ N = 'riappare il controllo web somma +- 0,02'; T = 'page'; Old = 'Dim shownTotal As Decimal = ParseDecimalForDb(Session("Ordine_Totale_Documento"), 0D)'; New = 'Dim shownTotal As Decimal = ParseDecimalForDb(Session("Ordine_Totale_Documento"), 0D)' + "`r`n" + 'Dim calculatedTotal As Decimal = 0D' + "`r`n" + 'If Math.Abs(shownTotal - calculatedTotal) > 0.02D Then Return False' },
    @{ N = 'lo scorporo del buono usa un''altra aliquota'; T = 'page'; Old = 'Dim ivaBuonoPerc As Double = ResolveCouponVatValue()'; New = 'Dim ivaBuonoPerc As Double = preleva_ValoreIva(-1)' },
    @{ N = 'OUT senza Direction Output'; T = 'service'; Old = 'parameter.Direction = ParameterDirection.Output'; New = 'parameter.Direction = ParameterDirection.Input' },
    @{ N = 'la base del pagamento non viene piu dal database'; T = 'page'; Old = 'totBase = CDbl(baseTotals.Merce) + spedD + assD + CDbl(baseTotals.Iva)'; New = 'totBase = impD + spedD + assD' },
    @{ N = 'l''ordine non azzera piu i costi del coupon'; T = 'order'; Old = 'AddDecimalParameter(cmd, "?pCostoSpedizione", If(isCoupon, 0D, SpeseSped))'; New = 'AddDecimalParameter(cmd, "?pCostoSpedizione", SpeseSped)' },
    @{ N = 'il servizio arrotonda'; T = 'service'; Old = '.Totale = Convert.ToDecimal(outTotale.Value, CultureInfo.InvariantCulture)'; New = '.Totale = Math.Round(Convert.ToDecimal(outTotale.Value, CultureInfo.InvariantCulture), 2)' }
)
foreach ($m in $mutations) {
    $s = $service; $p = $page; $o = $order
    # Le sorgenti nel working tree possono essere CRLF o LF: le mutazioni con righe multiple provano entrambe le forme.
    $variants = @(@($m.Old, $m.New), @($m.Old.Replace("`r`n", "`n"), $m.New.Replace("`r`n", "`n")))
    $applied = $false
    foreach ($v in $variants) {
        $r = switch ($m.T) { 'service' { Mutate $s $v[0] $v[1] } 'page' { Mutate $p $v[0] $v[1] } 'order' { Mutate $o $v[0] $v[1] } }
        if ($null -ne $r) {
            switch ($m.T) { 'service' { $s = $r } 'page' { $p = $r } 'order' { $o = $r } }
            $applied = $true; break
        }
    }
    if (-not $applied) { Check $false ('mutazione non applicabile (ancora non trovata nei sorgenti): ' + $m.N); continue }
    $res = Test-Sources $s $p $o
    Check ($res.Count -gt 0) ('mutazione rilevata: ' + $m.N)
}

# --- Compilazione del servizio (Option Strict On) ---
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$workRoot = Join-Path $env:TEMP ('ks-carttotals-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workRoot | Out-Null
try {
    $stub = Join-Path $workRoot 'KeepStoreLogStub.vb'
    [IO.File]::WriteAllText($stub, "Imports System`r`nImports System.Web`r`nPublic Module KeepStoreLog`r`n    Public Sub [Error](ByVal category As String, ByVal message As String, ByVal ex As Exception, ByVal context As HttpContext)`r`n    End Sub`r`nEnd Module`r`n")
    $dll = Join-Path $workRoot 'CartTotalsService.dll'
    $mysqlRef = '/reference:' + (Join-Path $RepositoryRoot 'Bin\MySql.Data.dll')
    $out = & $vbc /nologo /target:library /optionstrict+ /optionexplicit+ /out:$dll $mysqlRef /reference:System.dll /reference:System.Data.dll /reference:System.Web.dll /reference:System.Configuration.dll /reference:System.Core.dll (Join-Path $RepositoryRoot 'App_Code\CartTotalsService.vb') $stub 2>&1
    Check (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $dll)) 'compilazione: CartTotalsService.vb (Option Strict On, Option Explicit On) senza errori'
    if ($LASTEXITCODE -ne 0) { $out | ForEach-Object { "  $_" } }

    if ($Lab) {
        # --- Harness contro la routine reale del LAB, con il connettore del sito (MySql.Data 8.0.33) ---
        foreach ($required in @($CredentialFile, $LabCa)) { if (-not (Test-Path -LiteralPath $required)) { throw ('LAB_PREREQUISITE_MISSING ' + $required) } }
        $bin = Join-Path $RepositoryRoot 'Bin'
        foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll') {
            if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $workRoot -Force }
        }
        $cfg = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>
      <dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>
      <dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>
      <dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>
      <dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>
    </assemblyBinding>
  </runtime>
</configuration>
'@
        $exe = Join-Path $workRoot 'CartTotalsLabHarness.exe'
        [IO.File]::WriteAllText($exe + '.config', $cfg, (New-Object Text.UTF8Encoding($false)))
        $mysqlRefExe = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
        $null = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $mysqlRefExe /reference:System.dll /reference:System.Data.dll /reference:System.Web.dll /reference:System.Configuration.dll /reference:System.Core.dll (Join-Path $RepositoryRoot 'Tools\CartTotalsLabHarness.vb') (Join-Path $RepositoryRoot 'App_Code\CartTotalsService.vb') 2>&1
        Check (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $exe)) 'harness: compilazione'
        $cred = Import-Clixml -LiteralPath $CredentialFile
        if ($cred -isnot [pscredential]) { throw 'CREDENTIAL_FILE_NOT_PSCREDENTIAL' }
        $plain = $cred.GetNetworkCredential().Password
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $exe
        $info.UseShellExecute = $false
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.CreateNoWindow = $true
        $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
        $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
        $info.EnvironmentVariables['KS_LAB_CA'] = $LabCa
        $proc = [Diagnostics.Process]::Start($info)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $code = $proc.ExitCode
        if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
        $plain = $null; $cred = $null
        $lines = @($stdout -split "`r?`n" | Where-Object { $_ -ne '' })
        $lines | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|DURATA|CART_TOTALS_CHECKS|  in )' } | ForEach-Object { '  ' + $_ }
        $summary = $lines | Where-Object { $_ -match '^CART_TOTALS_CHECKS=' } | Select-Object -Last 1
        Check (($code -eq 0) -and ($summary -match 'FAIL=0$') -and ($summary -match 'CART_TOTALS_CHECKS=1\d\d ')) ('harness contro la routine reale del LAB: ' + $summary)
        if ($stderr.Trim()) { '  stderr: ' + $stderr.Trim() }
    }
} finally {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}

'CART_TOTALS_STATIC_CHECKS=' + $script:total + ' FAIL=' + $script:failed
if ($script:failed -gt 0) { exit 1 }
