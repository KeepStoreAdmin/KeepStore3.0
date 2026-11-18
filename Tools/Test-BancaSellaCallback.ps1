[CmdletBinding()]
param([switch]$SkipLab)

# BANCASELLA-CALLBACK-AUTH-1A. La conferma di pagamento della carta (server-to-server e ritorno del cliente) deve provare chi parla e non tornare
# indietro: negozio configurato e dell'azienda del documento, un pagamento segnato una volta sola, mai un KO sopra un OK, una riga per incasso,
# ritorno del cliente solo verso un host dell'azienda. (A) comportamento del modulo compilato, (B) sorgenti, (C) mutazioni, (D) percorso
# produttivo sul LAB locale (transazioni vere, trigger veri, quattro conferme concorrenti) e mutazioni del livello dati sul LAB. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { $p = Join-Path $root $rel; if (Test-Path -LiteralPath $p) { return [IO.File]::ReadAllText($p, $utf8) } else { return '' } }

$files = @{
    module = Read-Repo 'App_Code/BancaSellaCallback.vb'
    s2s    = Read-Repo 'BancaSella/comunication.aspx.vb'
    client = Read-Repo 'BancaSella/responseClient.aspx.vb'
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $m = $f.module; $s = $f.s2s; $c = $f.client
    # B1 le pagine non hanno SQL proprio: tutto passa dal modulo
    foreach ($pair in @(@('comunication', $s), @('responseClient', $c))) {
        if ($pair[1] -match '(?i)\b(UPDATE|INSERT INTO|DELETE FROM|SELECT )\b' -or $pair[1] -match 'MySqlCommand|MySqlConnection') { $fail.Add('B1 SQL nella pagina ' + $pair[0]) }
        if ($pair[1] -match 'StackTrace') { $fail.Add('B1 stack nel registro di ' + $pair[0]) }
    }
    # B2 server-to-server: negozio configurato PRIMA di Decrypt, Decrypt PRIMA della transazione del modulo
    $iKnown = $s.IndexOf('If Not BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then'); $iDec = $s.IndexOf('objCrypt.Decrypt(shopLogin, encrypted)'); $iProc = $s.IndexOf('BancaSellaCallback.ProcessServerCallback(connectionString, shopLogin, fields)')
    if (-not ($iKnown -gt 0 -and $iDec -gt $iKnown -and $iProc -gt $iDec)) { $fail.Add('B2 ordine controllo negozio, Decrypt, transazione') }
    if ($s -notmatch 'If Not BancaSellaCallback\.IsKnownLogin\(connectionString, shopLogin\) Then\s+BancaSellaCallback\.WriteLog\([^\r\n]+\)\s+Exit Sub') { $fail.Add('B2 negozio non configurato non esce') }
    if ($m -match 'Decrypt\(' -or $m -match 'it\.sella') { $fail.Add('B2 il modulo chiama la banca') }
    # B3 ritorno del cliente: nessuna scrittura di stato, negozio configurato prima di Decrypt, destinazione solo dal modulo
    if ($c -match 'ProcessServerCallback') { $fail.Add('B3 il ritorno del cliente scrive lo stato') }
    $jKnown = $c.IndexOf('If BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then'); $jDec = $c.IndexOf('objCrypt.Decrypt(shopLogin, encrypted)')
    if (-not ($jKnown -gt 0 -and $jDec -gt $jKnown)) { $fail.Add('B3 Decrypt senza controllo del negozio') }
    if ($c -match '"http://' -or $c -match 'sitoWeb') { $fail.Add('B3 destinazione costruita nella pagina') }
    if ($c -notmatch 'Dim host As String = BancaSellaCallback\.ChooseReturnHost\(site, BancaSellaCallback\.LoadCompanyHosts\(connectionString, documentId\)\)\s+Response\.Redirect\(BancaSellaCallback\.BuildReturnUrl\(host, documentId, paid\), False\)') { $fail.Add('B3 ritorno non scelto dal modulo') }
    if ($c -notmatch 'Response\.Redirect\("~/pagamento\.aspx\?cod_controllo=" & HttpUtility\.UrlEncode\(controlCode\) & "&bancasella=true", False\)') { $fail.Add('B3 ritorno coupon non relativo') }
    if ($c -notmatch 'If Not parsed Then Return') { $fail.Add('B3 redirect senza riferimento valido') }
    # B4 livello dati: blocco della riga, stato solo da Pagato = 0 e stessa azienda, riga per coppia, una transazione
    if ($m -notmatch 'FROM documenti WHERE id=\?id FOR UPDATE"') { $fail.Add('B4 documento non bloccato') }
    if ($m -notmatch '"WHERE id=\?id AND AziendeId=\?aziendaId AND COALESCE\(Pagato,0\)=0"') { $fail.Add('B4 aggiornamento senza azienda o senza Pagato = 0') }
    if ($m -notmatch 'FROM bancasella_ordini_pagati WHERE DocumentiId=\?id AND codiceAutorizzazione=\?codice"') { $fail.Add('B4 riga non per coppia documento-codice') }
    if (([regex]::Matches($m, 'UPDATE documenti')).Count -ne 1) { $fail.Add('B4 piu di un aggiornamento del documento') }
    if (([regex]::Matches($m, 'BeginTransaction\(\)')).Count -ne 1 -or ([regex]::Matches($m, 'transaction\.Commit\(\)')).Count -ne 1) { $fail.Add('B4 transazione unica') }
    $iLock = $m.IndexOf('LoadFactsForUpdate(connection, transaction, documentId)'); $iDecide = $m.IndexOf('Decide(known, ofCompany, fields, facts)'); $iCommit = $m.IndexOf('transaction.Commit()')
    if (-not ($iLock -gt 0 -and $iDecide -gt $iLock -and $iCommit -gt $iDecide)) { $fail.Add('B4 decisione fuori dal blocco') }
    if ($m -match 'HttpContext|Session\(|ConfigurationManager') { $fail.Add('B4 modulo non autonomo') }
    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

$probe = @'
Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Xml
Public Module BancaSellaProbe
    Private sb As New StringBuilder()
    Private Sub T(ByVal name As String, ByVal ok As Boolean)
        If sb.Length > 0 Then sb.Append(";")
        sb.Append(name).Append("=").Append(ok.ToString())
    End Sub
    Private Function F(ByVal result As String, ByVal code As String, Optional ByVal shopTx As String = "339/2026", Optional ByVal currency As String = "242", Optional ByVal amount As String = "57.90") As BancaSellaDecrypted
        Return New BancaSellaDecrypted() With {.TransactionResult = result, .AuthorizationCode = code, .ShopTransactionId = shopTx, .Currency = currency, .Amount = amount, .CustomInfo = "iddocumento=7*P1*sito=www.a.test"}
    End Function
    Private Function D(ByVal pagato As Integer, Optional ByVal onLine As Integer = 3) As BancaSellaDocumentFacts
        Return New BancaSellaDocumentFacts() With {.Exists = True, .DocumentId = 7, .AziendeId = 1, .Pagato = pagato, .PaymentOnline = onLine, .DocumentNumber = 339, .DocumentYear = 2026, .TotalDocument = 57.9D}
    End Function
    Private Function A(ByVal known As Boolean, ByVal own As Boolean, ByVal fields As BancaSellaDecrypted, ByVal facts As BancaSellaDocumentFacts) As BancaSellaCallbackAction
        Return BancaSellaCallback.Decide(known, own, fields, facts).Action
    End Function
    Private Function W(ByVal fields As BancaSellaDecrypted, ByVal facts As BancaSellaDocumentFacts) As String
        Return String.Join("|", BancaSellaCallback.Decide(True, True, fields, facts).Warnings)
    End Function
    Private Function P(ByVal text As String, ByVal expectedId As Integer, ByVal expectedSite As String, ByVal expectedCoupon As Boolean, ByVal expectedOk As Boolean) As Boolean
        Dim id As Integer, site As String = Nothing, coupon As Boolean
        Dim ok As Boolean = BancaSellaCallback.TryParseCustomInfo(text, id, site, coupon)
        If ok <> expectedOk Then Return False
        If Not ok Then Return id = 0
        Return id = expectedId AndAlso site = expectedSite AndAlso coupon = expectedCoupon
    End Function
    Public Function Run() As String
        ' Decisione: chi parla
        T("A01_negozio_sconosciuto", A(False, True, F("OK", "c"), D(0)) = BancaSellaCallbackAction.Rejected)
        T("A02_negozio_di_altra_azienda", A(True, False, F("OK", "c"), D(0)) = BancaSellaCallbackAction.Rejected)
        T("A03_documento_assente", A(True, True, F("OK", "c"), New BancaSellaDocumentFacts()) = BancaSellaCallbackAction.Rejected AndAlso A(True, True, F("OK", "c"), Nothing) = BancaSellaCallbackAction.Rejected)
        T("A04_risposta_assente", A(True, True, Nothing, D(0)) = BancaSellaCallbackAction.Rejected)
        ' Decisione: esiti
        T("A10_OK_in_attesa", A(True, True, F("OK", "c"), D(0)) = BancaSellaCallbackAction.MarkPaid)
        T("A11_ok_minuscolo", A(True, True, F(" ok ", "c"), D(0)) = BancaSellaCallbackAction.MarkPaid)
        T("A12_OK_senza_codice", A(True, True, F("OK", "  "), D(0)) = BancaSellaCallbackAction.NoChange)
        T("A13_OK_gia_pagato", A(True, True, F("OK", "c"), D(1)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid)
        T("A14_OK_pagato_2", A(True, True, F("OK", "c"), D(2)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid)
        T("A15_OK_interno", A(True, True, F("OK", "c"), D(-1)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid)
        T("A16_KO_in_attesa", A(True, True, F("KO", ""), D(0)) = BancaSellaCallbackAction.MarkFailed)
        T("A17_KO_gia_pagato", A(True, True, F("KO", ""), D(1)) = BancaSellaCallbackAction.NoChange)
        T("A18_XX", A(True, True, F("XX", "c"), D(0)) = BancaSellaCallbackAction.NoChange)
        T("A19_vuoto", A(True, True, F("", "c"), D(0)) = BancaSellaCallbackAction.NoChange)
        T("A20_sconosciuto", A(True, True, F("OKK", "c"), D(0)) = BancaSellaCallbackAction.NoChange)
        ' Avvisi: mai un rifiuto
        T("A30_nessun_avviso", W(F("OK", "c"), D(0)) = "")
        T("A31_metodo_non_carta_paga_lo_stesso", A(True, True, F("OK", "c"), D(0, 2)) = BancaSellaCallbackAction.MarkPaid AndAlso W(F("OK", "c"), D(0, 2)).Contains("metodo"))
        T("A32_numero_diverso_paga_lo_stesso", A(True, True, F("OK", "c", "340/2026"), D(0)) = BancaSellaCallbackAction.MarkPaid AndAlso W(F("OK", "c", "340/2026"), D(0)).Contains("numero ordine"))
        T("A33_valuta_diversa_paga_lo_stesso", A(True, True, F("OK", "c", "339/2026", "1"), D(0)) = BancaSellaCallbackAction.MarkPaid AndAlso W(F("OK", "c", "339/2026", "1"), D(0)).Contains("valuta"))
        T("A34_importo_diverso_paga_lo_stesso", A(True, True, F("OK", "c", "339/2026", "242", "50.00"), D(0)) = BancaSellaCallbackAction.MarkPaid AndAlso W(F("OK", "c", "339/2026", "242", "50.00"), D(0)).Contains("importo"))
        T("A35_valuta_e_importo_assenti_senza_avviso", W(F("OK", "c", "339/2026", "", ""), D(0)) = "")
        T("A36_gia_pagato_avvisa", W(F("OK", "c"), D(1)).Contains("gia pagato"))
        ' CustomInfo
        T("P01_forma_attesa", P("iddocumento=169299*P1*sito=www.a.test", 169299, "www.a.test", False, True))
        T("P02_chiavi_maiuscole", P("IdDocumento=5*P1*SITO=www.a.test", 5, "www.a.test", False, True))
        T("P03_senza_sito", P("iddocumento=5", 5, "", False, True))
        T("P04_coupon", P("iddocumento=coupon-12*P1*sito=x", 12, "x", True, True))
        T("P05_vuoto", P("", 0, "", False, False) AndAlso P(Nothing, 0, "", False, False))
        T("P06_non_numerico", P("iddocumento=12a*P1*sito=x", 0, "", False, False))
        T("P07_iniezione", P("iddocumento=12 OR 1=1*P1*sito=x", 0, "", False, False))
        T("P08_negativo", P("iddocumento=-5*P1*sito=x", 0, "", False, False))
        T("P09_zero", P("iddocumento=0*P1*sito=x", 0, "", False, False) AndAlso P("iddocumento=007*P1*sito=x", 0, "", False, False))
        T("P10_troppo_lungo", P("iddocumento=12345678901*P1*sito=x", 0, "", False, False))
        T("P11_chiave_sbagliata", P("documento=5*P1*sito=x", 0, "", False, False))
        T("P12_tre_parti", P("iddocumento=5*P1*sito=x*P1*iddocumento=9", 0, "", False, False))
        T("P13_secondo_id_nel_sito_ignorato", P("iddocumento=5*P1*iddocumento=9", 5, "", False, True))
        ' Negozi
        T("L01_stesso_negozio", BancaSellaCallback.SameLogin(" GESPAY1 ", "gespay1") AndAlso Not BancaSellaCallback.SameLogin("GESPAY1", "GESPAY2") AndAlso Not BancaSellaCallback.SameLogin("", "") AndAlso Not BancaSellaCallback.SameLogin(Nothing, Nothing))
        T("L02_elenco", BancaSellaCallback.ContainsLogin(New String() {"A1", "B2"}, "b2") AndAlso Not BancaSellaCallback.ContainsLogin(New String() {"A1", "B2"}, "C3") AndAlso Not BancaSellaCallback.ContainsLogin(Nothing, "A1") AndAlso Not BancaSellaCallback.ContainsLogin(New String() {"", Nothing}, ""))
        ' Ritorno del cliente
        Dim hosts As String() = New String() {"www.a.test", "alias.a.test"}
        T("H01_host_dell_azienda", BancaSellaCallback.ChooseReturnHost("WWW.A.TEST", hosts) = "www.a.test" AndAlso BancaSellaCallback.ChooseReturnHost("alias.a.test/", hosts) = "alias.a.test")
        T("H02_host_estraneo", BancaSellaCallback.ChooseReturnHost("www.evil.test", hosts) = "" AndAlso BancaSellaCallback.ChooseReturnHost("www.a.test.evil.test", hosts) = "")
        T("H03_host_con_percorso_o_credenziali", BancaSellaCallback.ChooseReturnHost("www.a.test/x", hosts) = "" AndAlso BancaSellaCallback.ChooseReturnHost("user@www.a.test", hosts) = "" AndAlso BancaSellaCallback.ChooseReturnHost("www.a.test?x", hosts) = "")
        T("H04_vuoto_o_senza_elenco", BancaSellaCallback.ChooseReturnHost("", hosts) = "" AndAlso BancaSellaCallback.ChooseReturnHost("www.a.test", Nothing) = "" AndAlso BancaSellaCallback.ChooseReturnHost("www.a.test", New String() {}) = "")
        T("H05_schema_tolto", BancaSellaCallback.ChooseReturnHost("http://www.a.test", hosts) = "www.a.test")
        T("H06_url_assoluto_https", BancaSellaCallback.BuildReturnUrl("www.a.test", 7, True) = "https://www.a.test/documentidettaglio.aspx?id=7&payreturn=ok")
        T("H08_host_normalizzato", BancaSellaCallback.NormalizeHost("www.a.test/x") = "" AndAlso BancaSellaCallback.NormalizeHost("u@www.a.test") = "" AndAlso BancaSellaCallback.NormalizeHost("www.a.test?x=1") = "" AndAlso BancaSellaCallback.NormalizeHost("HTTPS://WWW.A.TEST/") = "www.a.test" AndAlso BancaSellaCallback.NormalizeHost("localhost:8443") = "localhost:8443")
        T("H07_url_relativo", BancaSellaCallback.BuildReturnUrl("", 7, False) = "~/documentidettaglio.aspx?id=7&payreturn=ko")
        ' Lettura dei campi e registro
        Dim doc As New XmlDocument()
        doc.LoadXml("<GestPayCryptDecrypt><TransactionResult> OK </TransactionResult><ShopTransactionID>339/2026</ShopTransactionID><AuthorizationCode>A1</AuthorizationCode><Currency>242</Currency><Amount>57.90</Amount><CustomInfo>iddocumento=7*P1*sito=www.a.test</CustomInfo><BuyerName>Mario Rossi</BuyerName><BuyerEmail>m@x.test</BuyerEmail></GestPayCryptDecrypt>")
        Dim r As BancaSellaDecrypted = BancaSellaCallback.ReadFields(doc.DocumentElement)
        T("R01_campi_letti", r.TransactionResult = "OK" AndAlso r.ShopTransactionId = "339/2026" AndAlso r.AuthorizationCode = "A1" AndAlso r.Currency = "242" AndAlso r.Amount = "57.90" AndAlso r.CustomInfo.StartsWith("iddocumento=7"))
        T("R02_senza_nodo", BancaSellaCallback.ReadFields(Nothing).TransactionResult = "" AndAlso BancaSellaCallback.ReadFields(Nothing).CustomInfo = "")
        Dim logText As String = BancaSellaCallback.DescribeForLog("S2S", BancaSellaCallback.Decide(True, True, r, D(0)), r)
        T("R03_registro_senza_dati_del_cliente", logText.Contains("azione=MarkPaid") AndAlso logText.Contains("documento=7") AndAlso logText.Contains("codice=presente") AndAlso Not logText.Contains("Mario") AndAlso Not logText.Contains("m@x.test") AndAlso Not logText.Contains("A1 "))
        T("R04_esito_fallito", BancaSellaCallback.BuildFailedOutcome("1143", "Autorizzazione" & Convert.ToChar(10) & "negata") = "BancaSella pagamento non autorizzato - Codice 1143 - Autorizzazione negata")
        T("R05_esito_troncato", BancaSellaCallback.SanitizeOutcome(New String("x"c, 400)).Length = 255)
        T("R06_senza_connessione", Not BancaSellaCallback.IsKnownLogin("", "A1") AndAlso Not BancaSellaCallback.IsKnownLogin("Server=127.0.0.1;Port=1;Connection Timeout=1", "") AndAlso Not BancaSellaCallback.IsKnownLogin("Server=127.0.0.1;Port=1;Connection Timeout=1", "A1") AndAlso BancaSellaCallback.LoadCompanyHosts("", 7).Count = 0)
        T("R07_riferimento_non_valido_senza_database", BancaSellaCallback.ProcessServerCallback("", "A1", New BancaSellaDecrypted() With {.CustomInfo = "iddocumento=coupon-5*P1*sito=x", .TransactionResult = "OK", .AuthorizationCode = "c"}).Action = BancaSellaCallbackAction.Rejected AndAlso BancaSellaCallback.ProcessServerCallback("", "A1", Nothing).Action = BancaSellaCallbackAction.Rejected)
        Return sb.ToString()
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    if ($moduleText -eq '') { if (-not $Quiet) { Write-Host '  FAIL A modulo assente' }; return $false }
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    foreach ($ref in 'System.dll', 'System.Data.dll', 'System.Xml.dll', 'System.Core.dll') { [void]$p.ReferencedAssemblies.Add($ref) }
    [void]$p.ReferencedAssemblies.Add((Join-Path $root 'Bin\MySql.Data.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Bin\MySql.Data.dll'))
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    try { $out = [string]$c.CompiledAssembly.GetType('BancaSellaProbe').GetMethod('Run').Invoke($null, @()) } catch { if (-not $Quiet) { Write-Host ('  FAIL A eccezione: ' + $_.Exception.InnerException.Message) }; return $false }
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

# ---- LAB: compila ed esegue l'harness con il modulo dato; restituisce la riga di riepilogo (o un testo di errore) ----
$labMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLocalLabSql')
function Invoke-Lab([string]$moduleText) {
    $credFile = Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml'
    $vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
    $bin = Join-Path $root 'Bin'
    $work = Join-Path $env:TEMP ('ks-bancasella-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $held = $false
    try {
        foreach ($dep in 'MySql.Data.dll', 'Google.Protobuf.dll', 'BouncyCastle.Cryptography.dll', 'System.Buffers.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll', 'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll') {
            if (Test-Path -LiteralPath (Join-Path $bin $dep)) { Copy-Item -LiteralPath (Join-Path $bin $dep) -Destination $work -Force }
        }
        $cfg = '<?xml version="1.0" encoding="utf-8"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup><runtime><assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">' +
            '<dependentAssembly><assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.2.4.0" newVersion="4.2.4.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.0.5.0" newVersion="4.0.5.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-6.0.3.0" newVersion="6.0.3.0"/></dependentAssembly>' +
            '<dependentAssembly><assemblyIdentity name="System.Numerics.Vectors" publicKeyToken="b03f5f7f11d50a3a" culture="neutral"/><bindingRedirect oldVersion="0.0.0.0-4.1.6.0" newVersion="4.1.6.0"/></dependentAssembly>' +
            '</assemblyBinding></runtime></configuration>'
        $exe = Join-Path $work 'BancaSellaCallbackLabHarness.exe'
        $modFile = Join-Path $work 'BancaSellaCallback.vb'
        [IO.File]::WriteAllText($exe + '.config', $cfg, $utf8)
        [IO.File]::WriteAllText($modFile, $moduleText, $utf8)
        $ref = '/reference:' + (Join-Path $bin 'MySql.Data.dll')
        $build = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ /out:$exe $ref /reference:System.dll /reference:System.Data.dll /reference:System.Core.dll /reference:System.Xml.dll (Join-Path $root 'Tools\BancaSellaCallbackLabHarness.vb') $modFile 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { return ('COMPILE_ERROR ' + (($build | Select-Object -First 3) -join ' | ')) }
        try { $held = $labMutex.WaitOne(600000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return 'LAB_BUSY' }
        $cred = Import-Clixml -LiteralPath $credFile
        $plain = $cred.GetNetworkCredential().Password
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $exe; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.CreateNoWindow = $true
        $info.EnvironmentVariables['KS_LAB_USER'] = $cred.UserName
        $info.EnvironmentVariables['KS_LAB_PWD'] = $plain
        $proc = [Diagnostics.Process]::Start($info)
        $stdout = $proc.StandardOutput.ReadToEnd(); $stderr = $proc.StandardError.ReadToEnd(); $proc.WaitForExit()
        if ($plain) { $stdout = $stdout.Replace($plain, '<hidden>'); $stderr = $stderr.Replace($plain, '<hidden>') }
        $plain = $null; $cred = $null
        $lines = @($stdout -split "`r?`n" | Where-Object { $_ -match '^(FAIL|HARNESS_ERROR|BANCASELLA_CALLBACK_LAB)' })
        return ($lines -join "`n")
    } finally {
        if ($held) { try { $labMutex.ReleaseMutex() } catch { } }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.module
if (-not ($okSource -and $okBehaviour)) { Write-Host 'BANCASELLA_CALLBACK FAIL'; exit 1 }

# --- (C) mutazioni (devono tutte fallire) ---
$nl = "`r`n"
$mutants = @(
    @{ Id = 'M01_S2S_DECRYPT_UNKNOWN_SHOP'; File = 's2s'; Old = 'If Not BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then'; New = 'If False Then' },
    @{ Id = 'M02_S2S_NO_EXIT_ON_UNKNOWN'; File = 's2s'; Old = "`"BancaSella S2S rifiutato: negozio non configurato`")$nl                Exit Sub"; New = "`"BancaSella S2S rifiutato: negozio non configurato`")" },
    @{ Id = 'M03_S2S_STACK_IN_LOG'; File = 's2s'; Old = 'BancaSellaCallback.SanitizeOutcome(ex.Message))'; New = 'BancaSellaCallback.SanitizeOutcome(ex.Message) & ex.StackTrace)' },
    @{ Id = 'M04_S2S_DIRECT_SQL'; File = 's2s'; Old = 'Dim objCrypt As New WSCryptDecrypt()'; New = 'Dim sqlMut As String = "UPDATE documenti SET pagato=1" : Dim objCrypt As New WSCryptDecrypt()' },
    @{ Id = 'M05_CLIENT_WRITES_STATE'; File = 'client'; Old = 'parsed = BancaSellaCallback.TryParseCustomInfo('; New = 'BancaSellaCallback.ProcessServerCallback(connectionString, shopLogin, fields) : parsed = BancaSellaCallback.TryParseCustomInfo(' },
    @{ Id = 'M06_CLIENT_DECRYPT_UNKNOWN_SHOP'; File = 'client'; Old = 'If BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then'; New = 'If True Then' },
    @{ Id = 'M07_CLIENT_HOST_FROM_CUSTOMINFO'; File = 'client'; Old = 'BancaSellaCallback.ChooseReturnHost(site, BancaSellaCallback.LoadCompanyHosts(connectionString, documentId))'; New = 'BancaSellaCallback.NormalizeHost(site)' },
    @{ Id = 'M08_CLIENT_HTTP_ABSOLUTE'; File = 'client'; Old = 'Response.Redirect(BancaSellaCallback.BuildReturnUrl(host, documentId, paid), False)'; New = 'Response.Redirect("http://" & site & "/documentidettaglio.aspx?id=" & documentId, False)' },
    @{ Id = 'M09_CLIENT_COUPON_ABSOLUTE'; File = 'client'; Old = 'Response.Redirect("~/pagamento.aspx?cod_controllo="'; New = 'Response.Redirect("https://" & site & "/pagamento.aspx?cod_controllo="' },
    @{ Id = 'M10_CLIENT_REDIRECT_WITHOUT_REFERENCE'; File = 'client'; Old = 'If Not parsed Then Return'; New = '' },
    @{ Id = 'M11_MODULE_NO_ROW_LOCK'; File = 'module'; Old = 'FROM documenti WHERE id=?id FOR UPDATE"'; New = 'FROM documenti WHERE id=?id"' },
    @{ Id = 'M12_MODULE_UPDATE_WITHOUT_PAGATO'; File = 'module'; Old = '"WHERE id=?id AND AziendeId=?aziendaId AND COALESCE(Pagato,0)=0"'; New = '"WHERE id=?id AND AziendeId=?aziendaId"' },
    @{ Id = 'M13_MODULE_UPDATE_WITHOUT_COMPANY'; File = 'module'; Old = '"WHERE id=?id AND AziendeId=?aziendaId AND COALESCE(Pagato,0)=0"'; New = '"WHERE id=?id AND COALESCE(Pagato,0)=0 AND ?aziendaId>=0"' },
    @{ Id = 'M14_MODULE_CALLS_BANK'; File = 'module'; Old = 'Public Const CardOnlineValue As Integer = 3'; New = "Public Const CardOnlineValue As Integer = 3$nl    Private Shared Function X(ByVal o As Object) As Object : Return CallByName(o, `"Decrypt(`", CallType.Method) : End Function" },
    @{ Id = 'M15_MODULE_SECOND_UPDATE'; File = 'module'; Old = '        transaction.Commit()'; New = '        Using extra As New MySqlCommand("UPDATE documenti SET pagato=1 WHERE id=0", connection, transaction) : extra.ExecuteNonQuery() : End Using : transaction.Commit()' }
)
$behaviourMutants = @(
    @{ Id = 'N01_UNKNOWN_SHOP_ACCEPTED'; Old = 'If Not loginKnown Then decision.Reason = "negozio non configurato" : Return decision'; New = '' },
    @{ Id = 'N02_OTHER_COMPANY_ACCEPTED'; Old = 'If Not loginOfDocumentCompany Then decision.Reason = "negozio di un''altra azienda" : Return decision'; New = '' },
    @{ Id = 'N03_OK_WITHOUT_CODE_PAYS'; Old = 'If If(fields.AuthorizationCode, String.Empty).Trim().Length = 0 Then'; New = 'If False Then' },
    @{ Id = 'N04_OK_REPAYS_PAID'; Old = 'ElseIf facts.Pagato = 0 Then'; New = 'ElseIf True Then' },
    @{ Id = 'N05_OK_ONLY_NOT_ONE'; Old = 'ElseIf facts.Pagato = 0 Then'; New = 'ElseIf facts.Pagato <> 1 Then' },
    @{ Id = 'N06_KO_OVERWRITES_PAID'; Old = "Case `"KO`"$nl                If facts.Pagato = 0 Then"; New = "Case `"KO`"$nl                If True Then" },
    @{ Id = 'N07_PENDING_AS_FAILED'; Old = "Case Else$nl                decision.Action = BancaSellaCallbackAction.NoChange$nl                decision.Reason = `"esito non definitivo`""; New = "Case Else$nl                decision.Action = BancaSellaCallbackAction.MarkFailed" },
    @{ Id = 'N08_METHOD_REJECTS'; Old = 'If facts.PaymentOnline <> CardOnlineValue Then decision.Warnings.Add("metodo del documento non carta")'; New = 'If facts.PaymentOnline <> CardOnlineValue Then decision.Reason = "metodo" : Return decision' },
    @{ Id = 'N09_AMOUNT_REJECTS'; Old = 'Then decision.Warnings.Add("importo diverso dal totale del documento")'; New = 'Then decision.Reason = "importo" : Return decision' },
    @{ Id = 'N10_NUMBER_REJECTS'; Old = 'Then decision.Warnings.Add("numero ordine diverso dal documento")'; New = 'Then decision.Reason = "numero" : Return decision' },
    @{ Id = 'N11_CURRENCY_REJECTS'; Old = 'Then decision.Warnings.Add("valuta diversa da euro")'; New = 'Then decision.Reason = "valuta" : Return decision' },
    @{ Id = 'N12_WARNINGS_DROPPED'; Old = 'decision.Warnings.Add("incasso su documento gia pagato")'; New = '' },
    @{ Id = 'N13_ID_NOT_DIGITS_ONLY'; Old = 'If ch < "0"c OrElse ch > "9"c Then Return False'; New = 'If ch = "x"c Then Return False' },
    @{ Id = 'N14_ID_LEADING_ZERO'; Old = ' OrElse idValue.Chars(0) = "0"c Then Return False'; New = ' Then Return False' },
    @{ Id = 'N15_ID_KEY_NOT_CHECKED'; Old = 'If Not String.Equals(text.Substring(0, index).Trim(), key, StringComparison.OrdinalIgnoreCase) Then Return False'; New = '' },
    @{ Id = 'N16_EXTRA_PARTS_ACCEPTED'; Old = 'If parts.Length < 1 OrElse parts.Length > 2 Then Return False'; New = 'If parts.Length < 1 Then Return False' },
    @{ Id = 'N17_COUPON_NOT_FLAGGED'; Old = 'isCoupon = True' + $nl + '            idValue = idValue.Substring(7)'; New = 'idValue = idValue.Substring(7)' },
    @{ Id = 'N18_COUPON_WRITES'; Old = ' OrElse isCoupon Then' + $nl + '            Return New BancaSellaCallbackDecision() With {.Reason = "riferimento del documento non valido"}'; New = ' Then' + $nl + '            Return New BancaSellaCallbackDecision() With {.Reason = "riferimento del documento non valido"}' },
    @{ Id = 'N19_EMPTY_LOGIN_MATCHES'; Old = 'Return a.Length > 0 AndAlso String.Equals(a, b, StringComparison.OrdinalIgnoreCase)'; New = 'Return String.Equals(a, b, StringComparison.OrdinalIgnoreCase)' },
    @{ Id = 'N20_ANY_LOGIN_MATCHES'; Old = 'If SameLogin(current, login) Then Return True'; New = 'Return True' },
    @{ Id = 'N21_HOST_NOT_COMPARED'; Old = 'If String.Equals(NormalizeHost(host), wanted, StringComparison.Ordinal) Then Return wanted'; New = 'Return wanted' },
    @{ Id = 'N22_HOST_CHARS_NOT_CHECKED'; Old = 'ch = "."c OrElse ch = "-"c OrElse ch = ":"c) Then Return String.Empty'; New = 'ch = "."c OrElse ch = "-"c OrElse ch = ":"c OrElse ch = "/"c OrElse ch = "@"c OrElse ch = "?"c) Then Return String.Empty' },
    @{ Id = 'N23_RETURN_HTTP'; Old = 'Return "https://" & host & "/" & path'; New = 'Return "http://" & host & "/" & path' },
    @{ Id = 'N24_RETURN_ALWAYS_OK'; Old = '& "&payreturn=" & If(paid, "ok", "ko")'; New = '& "&payreturn=ok"' },
    @{ Id = 'N25_LOG_WITH_CODE_VALUE'; Old = 'If(If(fields.AuthorizationCode, String.Empty).Trim().Length > 0, "presente", "assente")'; New = 'fields.AuthorizationCode & " "' },
    @{ Id = 'N26_OUTCOME_NOT_TRUNCATED'; Old = 'If sanitized.Length > 255 Then sanitized = sanitized.Substring(0, 255)'; New = '' },
    @{ Id = 'N27_KNOWN_LOGIN_ON_ERROR_TRUE'; Old = "        Catch$nl            Return False$nl        End Try$nl    End Function$nl$nl    ' Blocca la riga"; New = "        Catch$nl            Return True$nl        End Try$nl    End Function$nl$nl    ' Blocca la riga" }
)
# Mutazioni del livello dati provate sul percorso reale del LAB (il test statico non basta a dimostrarle)
$labMutants = @(
    @{ Id = 'D01_COMPANY_CHECK_USES_ALL_SHOPS'; Old = 'facts.Exists AndAlso ContainsLogin(LoadLogins(connection, transaction, facts.AziendeId), receivedLogin)'; New = 'facts.Exists AndAlso ContainsLogin(LoadLogins(connection, transaction, 0), receivedLogin)' },
    @{ Id = 'D02_ROW_BY_DOCUMENT_ONLY'; Old = 'FROM bancasella_ordini_pagati WHERE DocumentiId=?id AND codiceAutorizzazione=?codice"'; New = 'FROM bancasella_ordini_pagati WHERE DocumentiId=?id AND ?codice IS NOT NULL"' },
    @{ Id = 'D03_ROW_BY_CODE_ONLY'; Old = 'FROM bancasella_ordini_pagati WHERE DocumentiId=?id AND codiceAutorizzazione=?codice"'; New = 'FROM bancasella_ordini_pagati WHERE ?id>0 AND codiceAutorizzazione=?codice"' },
    @{ Id = 'D04_NO_ROW_LOCK_CONCURRENT'; Old = 'FROM documenti WHERE id=?id FOR UPDATE"'; New = 'FROM documenti WHERE id=?id"' },
    @{ Id = 'D05_FAILED_STATE_NOT_WRITTEN'; Old = 'UpdateDocument(connection, transaction, facts, "StatoPagamentoWeb=3", BuildFailedOutcome(fields.ErrorCode, fields.ErrorDescription))'; New = 'Dim unusedMut As Integer = 0' },
    @{ Id = 'D06_NO_COMMIT'; Old = '                transaction.Commit()'; New = '                transaction.Rollback()' }
)
$minMutants = 40
if (($mutants.Count + $behaviourMutants.Count + $labMutants.Count) -lt $minMutants) { Write-Host 'BANCASELLA_CALLBACK FAIL (pochi mutanti)'; exit 1 }
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.module.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'BANCASELLA_CALLBACK FAIL (mutanti)'; exit 1 }

# ---- (D) LAB ----
$labNote = 'LAB saltato'
if (-not $SkipLab) {
    $labUp = $false
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 13317); $labUp = $t.Connected; $t.Close() } catch { $labUp = $false }
    if (-not ((Test-Path -LiteralPath (Join-Path $env:APPDATA 'KeepStore\lab-13317-claude.clixml')) -and (Test-Path -LiteralPath (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe')) -and $labUp)) {
        $labNote = 'LAB non disponibile su questa macchina: parte (D) NON ESEGUITA'
    } else {
        $result = Invoke-Lab $files.module
        $summary = @($result -split "`n" | Where-Object { $_ -match '^BANCASELLA_CALLBACK_LAB ' }) | Select-Object -Last 1
        if ($summary -notmatch 'FAIL=0$') { $result -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'BANCASELLA_CALLBACK FAIL (LAB)'; exit 1 }
        foreach ($mu in $labMutants) {
            if (-not $files.module.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
            $r = Invoke-Lab ($files.module.Replace($mu.Old, $mu.New))
            $s = @($r -split "`n" | Where-Object { $_ -match '^BANCASELLA_CALLBACK_LAB ' }) | Select-Object -Last 1
            if ($r -match 'COMPILE_ERROR|LAB_BUSY') { Write-Host ('  MUTANT_INVALID ' + $mu.Id + ' ' + $r); $bad++; continue }
            if ($s -match 'FAIL=0$') { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
            elseif ($r -notmatch 'ripristino' -and $r -match 'HARNESS_ERROR') { Write-Host ('  NOTE ' + $mu.Id + ' ucciso da errore: ' + (@($r -split "`n" | Where-Object { $_ -match 'HARNESS_ERROR' })[0])) }
        }
        if ($bad -gt 0) { Write-Host 'BANCASELLA_CALLBACK FAIL (mutanti LAB)'; exit 1 }
        # dopo le mutazioni il LAB deve essere tornato pulito: una esecuzione finale del modulo vero lo dimostra
        $final = Invoke-Lab $files.module
        if ((@($final -split "`n" | Where-Object { $_ -match '^BANCASELLA_CALLBACK_LAB ' }) | Select-Object -Last 1) -notmatch 'FAIL=0$') { $final -split "`n" | ForEach-Object { Write-Host ('  ' + $_) }; Write-Host 'BANCASELLA_CALLBACK FAIL (LAB dopo le mutazioni)'; exit 1 }
        $labNote = $summary + ', ' + $labMutants.Count + ' mutazioni del livello dati sul LAB'
    }
}
Write-Host ('BANCASELLA_CALLBACK PASS (' + ($mutants.Count + $behaviourMutants.Count + $labMutants.Count) + ' mutanti; ' + $labNote + ')')
exit 0
