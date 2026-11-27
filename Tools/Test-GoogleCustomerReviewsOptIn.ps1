[CmdletBinding()]
param([switch]$SkipMutants)

# GCR-OPTIN-1A - attivazione di Recensioni dei clienti su Google (opt-in) sulla conferma ordine.
# (A) prova unitaria: App_Code\KeepStoreContentSecurityPolicy.vb + App_Code\KeepStoreGoogleCustomerReviews.vb + Tools\GoogleCustomerReviewsHarness.vb (compilati insieme).
# (B) controlli sul sorgente di ordine.aspx(.vb), documentidettaglio.aspx.vb, KeepStoreSecurity.vb. (C) mutanti su A e B: ognuno deve far fallire il collaudo.
# Nessuna rete, nessun database. Solo ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $PSScriptRoot
$vbc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\vbc.exe'
$mysql = Join-Path $repo 'Bin\MySql.Data.dll'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return ([IO.File]::ReadAllText((Join-Path $repo $rel), $utf8)).Replace("`r`n", "`n") }

$cspSrc = Read-Repo 'App_Code\KeepStoreContentSecurityPolicy.vb'
$gcrSrc = Read-Repo 'App_Code\KeepStoreGoogleCustomerReviews.vb'
$secSrc = Read-Repo 'App_Code\KeepStoreSecurity.vb'
$ordVb = Read-Repo 'ordine.aspx.vb'
$ordAspx = Read-Repo 'ordine.aspx'
$detVb = Read-Repo 'documentidettaglio.aspx.vb'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('KsGcr-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$failures = New-Object System.Collections.Generic.List[string]
function Add-Failure([string]$m) { $failures.Add($m); Write-Host ('  FAIL ' + $m) }

function Run-Unit([string]$csp, [string]$gcr) {
    $dir = Join-Path $tmp ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $a = Join-Path $dir 'KeepStoreContentSecurityPolicy.vb'; $b = Join-Path $dir 'KeepStoreGoogleCustomerReviews.vb'
    [IO.File]::WriteAllText($a, $csp, $utf8); [IO.File]::WriteAllText($b, $gcr, $utf8)
    $exe = Join-Path $dir 'h.exe'
    $out = & $vbc /nologo /target:exe /optionstrict+ /optionexplicit+ ('/out:' + $exe) /reference:System.dll /reference:System.Core.dll /reference:System.Web.dll ('/reference:' + $mysql) $a $b (Join-Path $PSScriptRoot 'GoogleCustomerReviewsHarness.vb') 2>&1
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Compiled = $false; Fails = @(); Text = ($out -join "`n") } }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $lines = @(& $exe 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
    $fails = @($lines | Where-Object { $_ -like 'FAIL *' })
    return [pscustomobject]@{ Compiled = $true; Fails = $fails; Code = $code; Lines = $lines }
}

# --- (B) controlli sul sorgente: restituisce l'elenco dei fallimenti ---
function Get-SourceFailures([string]$csp, [string]$gcr, [string]$sec, [string]$ord, [string]$aspx, [string]$det) {
    $f = New-Object System.Collections.Generic.List[string]
    if ($sec -notmatch 'KeepStoreContentSecurityPolicy\.Strict\(\)') { $f.Add('S1 AddSecurityHeaders usa la CSP stretta condivisa') }
    if ($sec -notmatch 'Public Sub AllowGoogleCustomerReviews\(resp As HttpResponse\)[\s\S]{0,200}SafeSetHeader\(resp, "Content-Security-Policy", KeepStoreContentSecurityPolicy\.WithGoogleCustomerReviews\(\)\)') { $f.Add('S2 la CSP allargata si imposta con SafeSetHeader (una sola intestazione)') }
    if ($sec -match 'apis\.google\.com|default-src') { $f.Add('S3 KeepStoreSecurity non contiene testi di policy ne host Google') }
    if ($ord -notmatch 'commitCompleted = True[\s\S]{0,700}If TipoDoc = KeepStoreGoogleCustomerReviews\.OrderDocumentType Then[\s\S]{0,200}KeepStoreGoogleCustomerReviews\.MarkPending\(Me\.Session, orderIdentity\.CompanyId, orderIdentity\.UtentiId, id\)') { $f.Add('S4 il marcatore si scrive dopo il commit e solo per un ordine (tipo 4)') }
    if ($ord -notmatch 'AndAlso documentType = KeepStoreGoogleCustomerReviews\.OrderDocumentType Then[\s\S]{0,600}KeepStoreGoogleCustomerReviews\.TryBuildForDocument\(conn, Me\.Session, documentId, ownerUtentiId, identity\.CompanyId\)[\s\S]{0,300}If gcr\.Length > 0 Then[\s\S]{0,300}litGoogleCustomerReviews\.Text = gcr[\s\S]{0,300}KeepStoreSecurity\.AllowGoogleCustomerReviews\(Response\)') { $f.Add('S5 la ricevuta emette lo snippet solo per un ordine e allarga la CSP solo se lo snippet c e') }
    if (([regex]::Matches($ord, 'AllowGoogleCustomerReviews')).Count -ne 1) { $f.Add('S6 ordine.aspx.vb allarga la CSP in un solo punto') }
    if ($ord -match 'GCR_ShowOptIn_DocId' -or $det -match 'GCR_ShowOptIn_DocId') { $f.Add('S7 la chiave di sessione mai scritta non esiste piu') }
    if ($aspx -notmatch '<asp:Panel ID="Panel1"[\s\S]*?<asp:Literal ID="litGoogleCustomerReviews"[\s\S]*?</asp:Panel>') { $f.Add('S8 il segnaposto sta dentro la ricevuta (Panel1)') }
    if ($det -notmatch 'String\.Equals\(Convert\.ToString\(Request\.QueryString\("payreturn"\)\), "ok", StringComparison\.OrdinalIgnoreCase\)') { $f.Add('S9 documentidettaglio emette solo con payreturn=ok') }
    if ($det -notmatch 'KeepStoreGoogleCustomerReviews\.TryBuildForDocument\(c, Session, idDocumento, _authorizedIdentity\.UtentiId, _authorizedIdentity\.CompanyId\)[\s\S]{0,200}If script\.Length = 0 Then Return[\s\S]{0,400}KeepStoreSecurity\.AllowGoogleCustomerReviews\(Response\)') { $f.Add('S10 documentidettaglio allarga la CSP solo con uno snippet costruito per il documento autorizzato') }
    if ($det -notmatch 'AllowGoogleCustomerReviews\(Response\)[\s\S]{0,200}Response\.Cache\.SetNoStore\(\)') { $f.Add('S11 documentidettaglio con lo snippet non si memorizza (no-store)') }
    if (([regex]::Matches($det, 'AllowGoogleCustomerReviews')).Count -ne 1 -or $det -match 'apis\.google\.com') { $f.Add('S12 documentidettaglio: un solo punto, nessun host Google nella pagina') }
    if ($gcr -notmatch 'Dim key As String = PendingKey\([^\r\n]*\)[\s\S]{0,200}If Not IsPending\(session, companyId, utentiId, documentId\) Then Return String\.Empty') { $f.Add('S13 senza marcatore non si emette') }
    if ($gcr -notmatch 'd\.id=\?id AND d\.UtentiId=\?uid AND d\.AziendeId=\?aziendaId') { $f.Add('S14 il documento si legge per id, utente e azienda') }
    if ($gcr -notmatch 'KeepStoreGoogleCustomerReviews' -or $gcr -notmatch 'If tipo <> OrderDocumentType Then Return String\.Empty') { $f.Add('S15 solo gli ordini (tipo 4)') }
    if ($gcr -notmatch 'If script\.Length = 0 Then Return String\.Empty[\s\S]{0,200}ClearPending\(session, companyId, utentiId, documentId\)[\s\S]{0,100}Return script') { $f.Add('S16 il marcatore si toglie solo dopo aver costruito lo snippet') }
    if ($gcr -match '"IT"' -or $gcr -match 'HtmlEncode') { $f.Add('S17 nessun paese inventato, nessun HtmlEncode dentro lo script') }
    if ($gcr -notmatch 'JavaScriptStringEncode') { $f.Add('S18 i valori si codificano per JavaScript') }
    if (($gcr + $csp + $sec) -match '(?i)taikun|webaffare|onsus') { $f.Add('S19 nessun cliente nel codice condiviso') }
    foreach ($rel in @('Page.master.vb', 'ordine.aspx.vb', 'documentidettaglio.aspx.vb')) { }
    return $f
}

try {
    Write-Host '(A) prova unitaria'
    $r = Run-Unit $cspSrc $gcrSrc
    if (-not $r.Compiled) { Add-Failure ('A0 il codice compila con il collaudo: ' + $r.Text) }
    elseif ($r.Fails.Count -gt 0 -or $r.Code -ne 0) { foreach ($x in $r.Fails) { Add-Failure ('A1 ' + $x) } }
    else { Write-Host ('  ok   A1 casi unitari: ' + (@($r.Lines | Where-Object { $_ -like 'ok *' }).Count)) }

    Write-Host '(B) sorgente'
    $sf = @(Get-SourceFailures $cspSrc $gcrSrc $secSrc $ordVb $ordAspx $detVb)
    foreach ($x in $sf) { Add-Failure $x }
    if ($sf.Count -eq 0) { Write-Host '  ok   B controlli sul sorgente' }
    # gli unici punti che allargano la CSP in tutto il repository
    $callers = @(Get-ChildItem -LiteralPath $repo -Recurse -Include *.vb -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.claude|\.ai-review|Tools|\.git)\\' } | Where-Object { ([IO.File]::ReadAllText($_.FullName, $utf8)) -match 'AllowGoogleCustomerReviews' } | ForEach-Object { $_.Name })
    $expectedCallers = @('KeepStoreSecurity.vb', 'documentidettaglio.aspx.vb', 'ordine.aspx.vb')
    if ($callers.Count -ne 3 -or @($callers | Where-Object { $expectedCallers -notcontains $_ }).Count -ne 0) { Add-Failure ('B20 chi allarga la CSP: ' + ($callers -join ',')) } else { Write-Host '  ok   B20 la CSP si allarga solo da ordine e documentidettaglio' }

    # (C) mutanti
    $mutants = @(
        @('merchant-fino-a-9-cifre', 'gcr', '[0-9]{1,20}', '[0-9]{1,9}'),
        @('paese-anche-minuscolo', 'gcr', '"^[A-Z]{2}$"', '"^[A-Za-z]{2}$"'),
        @('paese-zz-accettato', 'gcr', ' OrElse country = "ZZ"', ''),
        @('marcatore-50-invece-di-20', 'gcr', 'MaxPending As Integer = 20', 'MaxPending As Integer = 50'),
        @('consegna-4-giorni', 'gcr', 'DefaultDeliveryDays As Integer = 5', 'DefaultDeliveryDays As Integer = 4'),
        @('email-con-tag-accettata', 'gcr', '^[^@\s<>""]+@[^@\s<>""]+\.[^@\s<>""]+$', '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
        @('email-codificata-html', 'gcr', 'HttpUtility.JavaScriptStringEncode(email)', 'HttpUtility.HtmlEncode(email)'),
        @('data-con-cultura-del-server', 'gcr', 'estimatedDelivery.ToString("yyyy-MM-dd", inv)', 'estimatedDelivery.ToString("yyyy-MM-dd")'),
        @('chiave-con-pezzi-mancanti', 'gcr', 'If companyId <= 0 OrElse utentiId <= 0 OrElse documentId <= 0 Then Return String.Empty', 'If documentId <= 0 Then Return String.Empty'),
        @('marcatore-oltre-il-limite', 'gcr', 'While list.Count > MaxPending', 'While list.Count > MaxPending + 1'),
        @('marcatore-corrispondenza-parziale', 'gcr', 'Return PendingList(current).Contains(key)', 'Return Not String.IsNullOrEmpty(current) AndAlso current.Contains(key)'),
        @('senza-marcatore-si-emette', 'gcr', 'If Not IsPending(session, companyId, utentiId, documentId) Then Return String.Empty', ''),
        @('preventivi-ammessi', 'gcr', 'If tipo <> OrderDocumentType Then Return String.Empty', ''),
        @('marcatore-non-consumato', 'gcr', '            ClearPending(session, companyId, utentiId, documentId)'+[char]10+'', ''),
        @('documento-senza-utente', 'gcr', 'd.UtentiId=?uid AND ', ''),
        @('paese-di-ripiego-it', 'gcr', 'Dim script As String = BuildOptInScript(merchantId, documentId, email, country,', 'Dim script As String = BuildOptInScript(merchantId, documentId, email, If(country.Length <> 2, "IT", country),'),
        @('csp-stretta-cambiata', 'csp', '"font-src ''self'' data:; "', '"font-src ''self'' data: https:; "'),
        @('host-script-sbagliato', 'csp', 'GoogleScriptHost As String = "https://apis.google.com"', 'GoogleScriptHost As String = "https://www.google.com"'),
        @('host-frame-con-jolly', 'csp', 'GoogleFrameHost As String = "https://www.google.com"', 'GoogleFrameHost As String = "https://*.google.com"'),
        @('script-src-senza-fonti-di-default', 'csp', '" script-src " & DefaultSources & " "', '" script-src ''self'' "'),
        @('frame-src-senza-self', 'csp', 'FrameSources As String = "''self'' data: blob:"', 'FrameSources As String = "data: blob:"'),
        @('csp-allargata-perde-direttive', 'csp', 'Return Strict() & " script-src "', 'Return Strict().Replace("frame-ancestors ''self'';", "") & " script-src "'),
        @('csp-di-default-allargata', 'sec', 'SafeSetHeader(resp, "Content-Security-Policy", KeepStoreContentSecurityPolicy.Strict())', 'SafeSetHeader(resp, "Content-Security-Policy", KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews())'),
        @('csp-doppia-intestazione', 'sec', 'SafeSetHeader(resp, "Content-Security-Policy", KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews())', 'resp.AppendHeader("Content-Security-Policy", KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews())'),
        @('marcatore-per-ogni-documento', 'ord', 'If TipoDoc = KeepStoreGoogleCustomerReviews.OrderDocumentType Then', 'If True Then'),
        @('marcatore-non-scritto', 'ord', 'KeepStoreGoogleCustomerReviews.MarkPending(Me.Session, orderIdentity.CompanyId, orderIdentity.UtentiId, id)', ''),
        @('ricevuta-anche-per-preventivi', 'ord', 'AndAlso documentType = KeepStoreGoogleCustomerReviews.OrderDocumentType Then', 'Then'),
        @('csp-allargata-senza-snippet', 'ord', 'If gcr.Length > 0 Then', 'If True Then'),
        @('ricevuta-utente-sbagliato', 'ord', 'documentId, ownerUtentiId, identity.CompanyId)', 'documentId, 1, identity.CompanyId)'),
        @('segnaposto-tolto', 'aspx', '<asp:Literal ID="litGoogleCustomerReviews" runat="server"></asp:Literal>', ''),
        @('payreturn-ko-invece-di-ok', 'det', 'Request.QueryString("payreturn")), "ok", StringComparison.OrdinalIgnoreCase)', 'Request.QueryString("payreturn")), "ko", StringComparison.OrdinalIgnoreCase)'),
        @('snippet-vuoto-allarga-la-csp', 'det', 'If script.Length = 0 Then Return', ''),
        @('documento-con-lo-snippet-in-cache', 'det', 'Response.Cache.SetNoStore()'+[char]10+'        Catch'+[char]10+'            '' Fail-closed: nessun impatto sulla pagina del documento.', 'Catch'+[char]10+'            '' Fail-closed: nessun impatto sulla pagina del documento.'),
        @('documento-utente-sbagliato', 'det', '_authorizedIdentity.UtentiId, _authorizedIdentity.CompanyId)'+[char]10+'            End Using', '0, _authorizedIdentity.CompanyId)'+[char]10+'            End Using'),
        @('chiave-morta-ritornata', 'det', 'Fail-closed: nessun impatto sulla pagina del documento.', 'GCR_ShowOptIn_DocId')
    )
    if (-not $SkipMutants -and $failures.Count -eq 0) {
        Write-Host '(C) mutanti'
        $killed = 0
        foreach ($m in $mutants) {
            $name = $m[0]; $file = $m[1]; $find = $m[2]; $rep = $m[3]
            $src = @{ csp = $cspSrc; gcr = $gcrSrc; sec = $secSrc; ord = $ordVb; aspx = $ordAspx; det = $detVb }
            if (-not $src[$file].Contains($find)) { Add-Failure ('mutante ' + $name + ': testo da mutare non trovato'); continue }
            $src[$file] = $src[$file].Replace($find, $rep)
            $dead = $false
            if ($file -eq 'csp' -or $file -eq 'gcr') {
                $mr = Run-Unit $src['csp'] $src['gcr']
                if (-not $mr.Compiled) { Add-Failure ('mutante ' + $name + ' non compila (uccisione falsa)'); continue }
                if ($mr.Fails.Count -gt 0 -or $mr.Code -ne 0) { $dead = $true }
            }
            if (-not $dead) {
                $sf2 = @(Get-SourceFailures $src['csp'] $src['gcr'] $src['sec'] $src['ord'] $src['aspx'] $src['det'])
                if ($sf2.Count -gt 0) { $dead = $true }
            }
            if ($dead) { $killed++; Write-Host ('  ok   mutante ' + $name + ' ucciso') } else { Add-Failure ('mutante ' + $name + ' SOPRAVVISSUTO') }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $mutants.Count)
    }
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($failures.Count -gt 0) { Write-Host ('GOOGLE_CUSTOMER_REVIEWS_OPTIN FAIL (' + $failures.Count + ')'); exit 1 }
Write-Host 'GOOGLE_CUSTOMER_REVIEWS_OPTIN PASS'
