[CmdletBinding()]
param([switch]$SkipMutations)

# KS-B02F-FOOTER-PAYPAL-1A - la parte "della richiesta" della politica PayPal LIVE (HTTPS, non locale, non loopback, host consentito dell'azienda) diventa una funzione
# per AZIENDA, CanUseLiveCheckoutForCompany(context, companyId), richiamata anche dal piede; CanUseLiveCheckout(context, cfg) resta con lo stesso comportamento e delega.
# Oracolo 1 (differenziale vecchio contro nuovo): il CORPO ORIGINALE di CanUseLiveCheckout (copia verbatim, LegacyPolicy) e la politica NUOVA, compilata dal file reale,
# su una matrice di richieste (HttpContext finto con un HttpWorkerRequest proprio: schema, connessione sicura, host, indirizzo remoto e locale), tenant (assente, stessa
# azienda, altra azienda, alias, azienda 0) e configurazioni (assente, non pronta, pronta della stessa o di un'altra azienda): lo stesso verdetto in ogni cella.
# Oracolo 2: la nuova funzione per azienda coincide con il vecchio corpo applicato a una configurazione pronta di quell'azienda, e ha verdetti attesi nominati.
# Oracolo 3 (testo): CanUseLiveCheckout usa della configurazione SOLO IsConfigured e AziendeId e delega alla funzione per azienda.
# Mutazioni sulle copie in memoria. Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI. Si esegue con Windows PowerShell 5.1 (VBCodeProvider).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$relativePath) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)))) }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = Norm $old; $new = Norm $new
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}

$policyText = Read-Repo 'App_Code/PayPalCheckoutSafetyPolicy.vb'
$hostPolicy = Read-Repo 'App_Code/StorefrontCanonicalHostPolicy.vb'
$configText = Read-Repo 'App_Code/PayPalCheckoutConfig.vb'

$support = @"
Imports System
Imports System.Web

' Repository finto: la configurazione vera non si carica in questo test.
Public Module PayPalCheckoutRepository
    Public Function LoadConfigForDocument(ByVal documentId As Integer) As PayPalCheckoutConfig
        Return Nothing
    End Function
    Public Function LoadConfigForCompanyPayment(ByVal companyId As Integer, ByVal paymentMethodId As Integer) As PayPalCheckoutConfig
        Return Nothing
    End Function
End Module

' Risoluzione del tenant finta: restituisce il tenant impostato dal test, come farebbe la cache per la richiesta.
Public NotInheritable Class StorefrontSeoTenantContext
    Public Shared Current As StorefrontSeoTenantIdentity
    Public Shared Function Resolve(ByVal context As HttpContext) As StorefrontSeoTenantIdentity
        Return Current
    End Function
End Class

' CORPO ORIGINALE di CanUseLiveCheckout (copia verbatim prima del task): l'oracolo del differenziale.
Public NotInheritable Class LegacyPolicy
    Public Shared Function CanUseLiveCheckout(ByVal context As HttpContext, ByVal cfg As PayPalCheckoutConfig) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return False
        If cfg Is Nothing OrElse Not cfg.IsConfigured Then Return False
        If Not HasSafeLiveIngress(context) Then Return False

        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        If tenant Is Nothing OrElse tenant.CompanyId <> cfg.AziendeId Then Return False
        Return StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, context.Request.Url.Host, False)
    End Function
    Private Shared Function HasSafeLiveIngress(ByVal context As HttpContext) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return False
        Return PayPalCheckoutSafetyPolicy.IsLiveIngressAllowed(context.Request.Url.Scheme, context.Request.IsSecureConnection,
            context.Request.IsLocal, context.Request.Url.Host, context.Request.UserHostAddress,
            context.Request.ServerVariables("LOCAL_ADDR"))
    End Function
End Class

Public Class FakeWorker
    Inherits HttpWorkerRequest
    Public Secure As Boolean = True
    Public ServerName As String = "www.example.test"
    Public Remote As String = "203.0.113.9"
    Public LocalAddr As String = "198.51.100.5"
    Public Overrides Function GetUriPath() As String
        Return "/carrello.aspx"
    End Function
    Public Overrides Function GetQueryString() As String
        Return ""
    End Function
    Public Overrides Function GetRawUrl() As String
        Return "/carrello.aspx"
    End Function
    Public Overrides Function GetHttpVerbName() As String
        Return "GET"
    End Function
    Public Overrides Function GetHttpVersion() As String
        Return "HTTP/1.1"
    End Function
    Public Overrides Function GetRemoteAddress() As String
        Return Remote
    End Function
    Public Overrides Function GetRemotePort() As Integer
        Return 50000
    End Function
    Public Overrides Function GetLocalAddress() As String
        Return LocalAddr
    End Function
    Public Overrides Function GetLocalPort() As Integer
        Return 443
    End Function
    Public Overrides Function GetServerName() As String
        Return ServerName
    End Function
    Public Overrides Function IsSecure() As Boolean
        Return Secure
    End Function
    Public Overrides Function GetServerVariable(ByVal name As String) As String
        If name = "LOCAL_ADDR" Then Return LocalAddr
        If name = "SERVER_NAME" Then Return ServerName
        Return Nothing
    End Function
    Public Overrides Sub EndOfRequest()
    End Sub
    Public Overrides Sub FlushResponse(ByVal finalFlush As Boolean)
    End Sub
    Public Overrides Sub SendStatus(ByVal statusCode As Integer, ByVal statusDescription As String)
    End Sub
    Public Overrides Sub SendKnownResponseHeader(ByVal index As Integer, ByVal value As String)
    End Sub
    Public Overrides Sub SendUnknownResponseHeader(ByVal name As String, ByVal value As String)
    End Sub
    Public Overrides Sub SendResponseFromMemory(ByVal data As Byte(), ByVal length As Integer)
    End Sub
    Public Overrides Sub SendResponseFromFile(ByVal filename As String, ByVal offset As Long, ByVal length As Long)
    End Sub
    Public Overrides Sub SendResponseFromFile(ByVal handle As IntPtr, ByVal offset As Long, ByVal length As Long)
    End Sub
End Class

Public Class Drv
    Public Shared Function Ctx(ByVal secure As Boolean, ByVal host As String, ByVal remote As String, ByVal localAddr As String) As HttpContext
        Dim w As New FakeWorker()
        w.Secure = secure : w.ServerName = host : w.Remote = remote : w.LocalAddr = localAddr
        Return New HttpContext(w)
    End Function
    Public Shared Sub SetTenant(ByVal companyId As Integer, ByVal url1 As String, ByVal url2 As String)
        StorefrontSeoTenantContext.Current = StorefrontCanonicalHostPolicy.CreateTenant(companyId, "Alfa", "d", url1, url2, "l.png", 1)
    End Sub
    Public Shared Sub ClearTenant()
        StorefrontSeoTenantContext.Current = Nothing
    End Sub
    Public Shared Function Cfg(ByVal mode As Integer, ByVal company As Integer) As PayPalCheckoutConfig
        If mode = 0 Then Return Nothing
        Dim c As New PayPalCheckoutConfig()
        c.AccountId = 1 : c.CompanyConfigId = 1 : c.AziendeId = company : c.PagamentiTipoId = 2
        c.CredentialKey = "PAYPAL_LIVE" : c.MerchantId = "MID" : c.PayeeEmail = "pay@example.test" : c.BrandName = "B" : c.CurrencyCode = "EUR"
        c.ClientId = "cid" : c.ClientSecret = If(mode = 1, "", "sec") : c.AccountActive = True : c.CompanyActive = True
        Return c
    End Function
    Public Shared Function Old(ByVal context As HttpContext, ByVal cfg As PayPalCheckoutConfig) As Boolean
        Return LegacyPolicy.CanUseLiveCheckout(context, cfg)
    End Function
    Public Shared Function NewOne(ByVal context As HttpContext, ByVal cfg As PayPalCheckoutConfig) As Boolean
        Return PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(context, cfg)
    End Function
    Public Shared Function ForCompany(ByVal context As HttpContext, ByVal companyId As Integer) As Boolean
        Return PayPalCheckoutSafetyPolicy.CanUseLiveCheckoutForCompany(context, companyId)
    End Function
End Class
"@

function Compile-Probe([string]$policy) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($hostPolicy, $configText, $policy, $support))
    if ($c.Errors.HasErrors) { return ('COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 3 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join ' | ')) }
    return $c.CompiledAssembly.GetType('Drv', $true)
}

# richieste: nome, sicura, host, remoto, locale
$requests = @(
    @('ok_canonical', $true, 'www.shop-a.test', '203.0.113.9', '198.51.100.5'),
    @('ok_alias', $true, 'shop-a.test', '203.0.113.9', '198.51.100.5'),
    @('ok_canonical_upper', $true, 'WWW.SHOP-A.TEST', '203.0.113.9', '198.51.100.5'),
    @('not_secure', $false, 'www.shop-a.test', '203.0.113.9', '198.51.100.5'),
    @('unknown_host', $true, 'www.shop-z.test', '203.0.113.9', '198.51.100.5'),
    @('other_company_host', $true, 'www.shop-b.test', '203.0.113.9', '198.51.100.5'),
    @('localhost_host', $true, 'localhost', '203.0.113.9', '198.51.100.5'),
    @('loopback_remote', $true, 'www.shop-a.test', '127.0.0.1', '198.51.100.5'),
    @('loopback_local_addr', $true, 'www.shop-a.test', '203.0.113.9', '127.0.0.1'),
    @('islocal_same_addr', $true, 'www.shop-a.test', '198.51.100.5', '198.51.100.5')
)
# tenant: nome, azienda, url1, url2 (azienda -1 = nessun tenant)
$tenants = @(
    @('none', -1, '', ''),
    @('company1', 1, 'https://www.shop-a.test', 'https://shop-a.test'),
    @('company2', 2, 'https://www.shop-b.test', ''),
    @('company1_only_canonical', 1, 'https://www.shop-a.test', ''),
    @('company0', 0, 'https://www.shop-a.test', 'https://shop-a.test')
)
# configurazioni: nome, modo (0 = Nothing, 1 = non pronta, 2 = pronta), azienda
$cfgs = @(
    @('nothing', 0, 1), @('not_ready_c1', 1, 1), @('ready_c1', 2, 1), @('ready_c2', 2, 2), @('ready_c0', 2, 0)
)

function Test-Matrix($drv) {
    $bad = New-Object System.Collections.Generic.List[string]
    $total = 0; $trueCount = 0
    foreach ($t in $tenants) {
        if ($t[1] -lt 0) { [void]$drv.GetMethod('ClearTenant').Invoke($null, @()) } else { [void]$drv.GetMethod('SetTenant').Invoke($null, @([int]$t[1], [string]$t[2], [string]$t[3])) }
        foreach ($r in $requests) {
            $ctx = $drv.GetMethod('Ctx').Invoke($null, @([bool]$r[1], [string]$r[2], [string]$r[3], [string]$r[4]))
            foreach ($c in $cfgs) {
                $cfg = $drv.GetMethod('Cfg').Invoke($null, @([int]$c[1], [int]$c[2]))
                $old = [bool]$drv.GetMethod('Old').Invoke($null, @($ctx, $cfg))
                $new = [bool]$drv.GetMethod('NewOne').Invoke($null, @($ctx, $cfg))
                $total++
                if ($old) { $trueCount++ }
                if ($old -ne $new) { $bad.Add('DIFF ' + $t[0] + '/' + $r[0] + '/' + $c[0] + ' old=' + $old + ' new=' + $new) }
            }
            # la funzione per azienda coincide con il vecchio corpo applicato a una configurazione pronta di quell'azienda
            foreach ($company in @(0, 1, 2, 3, -1)) {
                $ready = $drv.GetMethod('Cfg').Invoke($null, @(2, [int]$company))
                $old = [bool]$drv.GetMethod('Old').Invoke($null, @($ctx, $ready))
                $fc = [bool]$drv.GetMethod('ForCompany').Invoke($null, @($ctx, [int]$company))
                $total++
                if ($company -le 0) {
                    # una configurazione con azienda 0 o negativa non e mai pronta: il vecchio corpo e falso; la funzione per azienda deve essere falsa comunque
                    if ($fc) { $bad.Add('FORCOMPANY_NONPOSITIVE ' + $t[0] + '/' + $r[0] + '/' + $company) }
                } elseif ($old -ne $fc) { $bad.Add('FORCOMPANY_DIFF ' + $t[0] + '/' + $r[0] + '/' + $company + ' old=' + $old + ' forCompany=' + $fc) }
            }
        }
    }
    if ($trueCount -lt 4) { $bad.Add('MATRIX_TOO_FEW_POSITIVES=' + $trueCount) }
    return @{ bad = $bad; total = $total; positives = $trueCount }
}

function Test-Named($drv) {
    $bad = New-Object System.Collections.Generic.List[string]
    function Verdict([string]$tenantName, [string]$requestName, [int]$company) {
        $t = $tenants | Where-Object { $_[0] -eq $tenantName }
        if ($t[1] -lt 0) { [void]$drv.GetMethod('ClearTenant').Invoke($null, @()) } else { [void]$drv.GetMethod('SetTenant').Invoke($null, @([int]$t[1], [string]$t[2], [string]$t[3])) }
        $r = $requests | Where-Object { $_[0] -eq $requestName }
        $ctx = $drv.GetMethod('Ctx').Invoke($null, @([bool]$r[1], [string]$r[2], [string]$r[3], [string]$r[4]))
        return [bool]$drv.GetMethod('ForCompany').Invoke($null, @($ctx, $company))
    }
    $expect = @(
        @('company1', 'ok_canonical', 1, $true), @('company1', 'ok_alias', 1, $true), @('company1', 'ok_canonical_upper', 1, $true),
        @('company1', 'not_secure', 1, $false), @('company1', 'unknown_host', 1, $false), @('company1', 'other_company_host', 1, $false),
        @('company1', 'localhost_host', 1, $false), @('company1', 'loopback_remote', 1, $false), @('company1', 'loopback_local_addr', 1, $false),
        @('company1', 'islocal_same_addr', 1, $false),
        @('company1', 'ok_canonical', 2, $false), @('company2', 'ok_canonical', 1, $false), @('none', 'ok_canonical', 1, $false),
        @('company1_only_canonical', 'ok_alias', 1, $false), @('company1_only_canonical', 'ok_canonical', 1, $true),
        @('company0', 'ok_canonical', 0, $false)
    )
    foreach ($e in $expect) {
        $got = Verdict $e[0] $e[1] $e[2]
        if ($got -ne $e[3]) { $bad.Add('NAMED ' + $e[0] + '/' + $e[1] + '/company=' + $e[2] + ' expected=' + $e[3] + ' got=' + $got) }
    }
    # contesto assente
    if ([bool]$drv.GetMethod('ForCompany').Invoke($null, @($null, 1))) { $bad.Add('NAMED null_context') }
    return $bad
}

function Test-BodyText([string]$text) {
    $m = [regex]::Match($text, '(?ms)Public Shared Function CanUseLiveCheckout\(.*?^    End Function')
    if (-not $m.Success) { return 'BODY_MISSING' }
    $body = $m.Value
    $members = [regex]::Matches($body, '\bcfg\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($member in $members) { if ($member -ne 'IsConfigured' -and $member -ne 'AziendeId') { return ('CFG_MEMBER=' + $member) } }
    if ($body -notmatch 'CanUseLiveCheckoutForCompany\(context, cfg\.AziendeId\)') { return 'NO_DELEGATION' }
    if ($body -notmatch 'cfg Is Nothing OrElse Not cfg\.IsConfigured') { return 'NO_READY_CHECK' }
    $f = [regex]::Match($text, '(?ms)Public Shared Function CanUseLiveCheckoutForCompany\(.*?^    End Function')
    if (-not $f.Success) { return 'FOR_COMPANY_MISSING' }
    if ($f.Value -match '\bcfg\b') { return 'FOR_COMPANY_USES_CFG' }
    foreach ($needle in @('HasSafeLiveIngress(context)', 'StorefrontSeoTenantContext.Resolve(context)', 'tenant.CompanyId <> companyId', 'StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, context.Request.Url.Host, False)', 'companyId <= 0')) {
        if ($f.Value.IndexOf($needle, [StringComparison]::Ordinal) -lt 0) { return ('FOR_COMPANY_LACKS=' + $needle) }
    }
    return ''
}

function Test-All([string]$text) {
    try {
        $drv = Compile-Probe $text
        if ($drv -is [string]) { return $drv }
        $matrix = Test-Matrix $drv
        if ($matrix.bad.Count -gt 0) { return ($matrix.bad | Select-Object -First 3) -join ' | ' }
        $named = @(Test-Named $drv)
        if ($named.Count -gt 0) { return ($named | Select-Object -First 3) -join ' | ' }
        $body = Test-BodyText $text
        if ($body -ne '') { return $body }
        return ('OK cells=' + $matrix.total + ' positives=' + $matrix.positives)
    } catch {
        # un'eccezione dentro la politica (per esempio un riferimento nullo) e un esito diverso dal verdetto atteso: la mutazione e rilevata
        return ('EXC ' + $_.Exception.Message)
    }
}

$result = Test-All $policyText
if (-not $result.StartsWith('OK')) { throw ('POLICY_FOR_COMPANY=' + $result) }
Assert-Source $true ('POLICY_DIFFERENTIAL_AND_NAMED_CASES ' + $result)

if (-not $SkipMutations) {
    function Mut([string]$old, [string]$new, [string]$code) {
        $x = Mutate-Text $policyText $old $new $code
        Assert-Detected ((Test-All $x) -eq $result) $code
    }
    Mut 'If Not HasSafeLiveIngress(context) Then Return False' 'If False Then Return False' 'P1_NO_INGRESS_CHECK'
    Mut 'tenant.CompanyId <> companyId' 'tenant.CompanyId < 0' 'P2_NO_COMPANY_MATCH'
    Mut 'Return StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, context.Request.Url.Host, False)' 'Return True' 'P3_NO_HOST_CHECK'
    Mut 'cfg Is Nothing OrElse Not cfg.IsConfigured' 'cfg Is Nothing' 'P4_NO_READY_CHECK'
    Mut 'CanUseLiveCheckoutForCompany(context, cfg.AziendeId)' 'True' 'P5_NO_DELEGATION'
    Mut 'companyId <= 0' 'companyId < -5' 'P6_NO_COMPANY_GUARD'
    Mut 'If tenant Is Nothing OrElse' 'If False OrElse' 'P7_NO_TENANT_NULL_GUARD'
    Mut 'Not isLocal AndAlso' 'True AndAlso' 'P8_ISLOCAL_IGNORED'
}
Write-Output 'PAYPAL_LIVE_FOR_COMPANY_OK'
