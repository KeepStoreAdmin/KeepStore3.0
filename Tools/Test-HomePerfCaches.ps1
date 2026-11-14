[CmdletBinding()]
param()

# KS-A04-HOME-PERF-1A - meno viaggi al database e meno byte per la HOME.
# Parte 1: il vero helper App_Code/StorefrontTenantScopedCache.vb viene compilato e provato (chiavi, isolamento, guasti non memorizzati).
# Parte 2: controlli statici sui sorgenti (intestazione dall'identita in cache, social eliminati, repeater senza ViewState, pool commerciali
#          mai in cache). Ogni controllo e provato con mutazioni: se la regola viene tolta il test deve fallire.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-Repo([string]$relativePath) { return ([IO.File]::ReadAllText((Join-Path $repoRoot $relativePath)) -replace "`r`n", "`n") }
function Assert-Source([bool]$condition, [string]$code) {
    if (-not $condition) { throw $code }
    Write-Output ('PASS ' + $code)
}
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $old = $old -replace "`r`n", "`n"; $new = $new -replace "`r`n", "`n"
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) {
    if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }
    Write-Output ('PASS MUTATION_DETECTED ' + $code)
}
function Get-Method([string]$source, [string]$name) {
    $m = [regex]::Match($source, '(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) ' + [regex]::Escape($name) + '\b.*?^    End (?:Function|Sub)')
    if (-not $m.Success) { return '' }
    return $m.Value
}

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 1 - comportamento reale dell'helper
# ---------------------------------------------------------------------------------------------------------------------------------
$probeSource = @'
Public Class CacheProbe
    Public Shared Loads As Integer
    Public Shared Function Run(ByVal area As String, ByVal scope As String, ByVal company As Integer, ByVal extra As String, ByVal ttl As Integer, ByVal mode As String, ByVal amount As Decimal) As FreeShippingPromoSnapshot
        Return StorefrontTenantScopedCache.GetOrLoad(Of FreeShippingPromoSnapshot)(area, scope, company, extra, ttl,
            Function() As FreeShippingPromoSnapshot
                Loads += 1
                If mode = "throw" Then Throw New InvalidOperationException("technical")
                If mode = "nothing" Then Return Nothing
                If mode = "empty" Then Return New FreeShippingPromoSnapshot(False, 0D)
                Return New FreeShippingPromoSnapshot(True, amount)
            End Function)
    End Function
    Public Shared Function Key(ByVal area As String, ByVal scope As String, ByVal company As Integer, ByVal extra As String) As String
        Return StorefrontTenantScopedCache.BuildKey(area, scope, company, extra)
    End Function
    Public Shared Function TableCopies() As String
        Dim src As New DataTable("t")
        src.Columns.Add("a", GetType(Integer))
        src.Rows.Add(1)
        Dim holder As New StorefrontCachedTable(src)
        src.Rows.Add(2)
        Dim c1 As DataTable = holder.CopyTable()
        c1.Rows.Add(3)
        c1.Rows(0)("a") = 99
        Dim c2 As DataTable = holder.CopyTable()
        Dim nullThrows As Boolean = False
        Try
            Dim x As New StorefrontCachedTable(Nothing)
        Catch ex As ArgumentNullException
            nullThrows = True
        End Try
        Return c2.Rows.Count.ToString() & "|" & Convert.ToString(c2.Rows(0)("a")) & "|" & nullThrows.ToString()
    End Function
End Class
'@

function Invoke-HelperBehavior([string]$helperText) {
    # Restituisce @{ Failed = <elenco dei controlli falliti>; Compiled = $true/$false }
    $failed = New-Object 'Collections.Generic.List[string]'
    $clean = [regex]::Replace($helperText, '(?m)^(Option .*|Imports .*)\r?\n', '')
    $code = "Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Web`n" + $clean + "`n" + $probeSource
    Add-Type -AssemblyName Microsoft.VisualBasic
    Add-Type -AssemblyName System.Web
    $compiler = New-Object Microsoft.VisualBasic.VBCodeProvider
    try {
        $parameters = New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory = $true
        $parameters.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict-'
        foreach ($a in @('System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Xml.dll', 'System.Web.dll')) { [void]$parameters.ReferencedAssemblies.Add($a) }
        $compiled = $compiler.CompileAssemblyFromSource($parameters, $code)
        if ($compiled.Errors.HasErrors) { return @{ Compiled = $false; Failed = @(($compiled.Errors | ForEach-Object { $_.ErrorText }) -join '; ') } }
        $probe = $compiled.CompiledAssembly.GetType('CacheProbe', $true)
        $loadsField = $probe.GetField('Loads')
        $runMethod = $probe.GetMethod('Run')
        $keyMethod = $probe.GetMethod('Key')
        $uniq = 'perf' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        function Run([string]$area, [string]$scope, [int]$company, [string]$extra, [int]$ttl, [string]$mode, [decimal]$amount) {
            try { return $runMethod.Invoke($null, [object[]]@($area, $scope, $company, $extra, $ttl, $mode, $amount)) }
            catch { $failed.Add('exception while running (' + $mode + '): ' + $_.Exception.Message); return $null }
        }
        function Loads() { return [int]$loadsField.GetValue($null) }
        function Check([bool]$ok, [string]$name) { if (-not $ok) { $failed.Add($name) } }

        # 1) stessa chiave: una sola lettura e lo stesso oggetto
        $loadsField.SetValue($null, 0)
        $a1 = Run $uniq 'dbA' 1 '7.20260101' 60 'ok' 5
        $a2 = Run $uniq 'dbA' 1 '7.20260101' 60 'ok' 5
        Check ((Loads) -eq 1 -and [object]::ReferenceEquals($a1, $a2) -and $a1.HasPromo -and $a1.MinAmount -eq 5) 'same key reads once'
        # 2) isolamento: azienda, listino, database e area diversi non si mescolano
        $loadsField.SetValue($null, 0)
        $b1 = Run $uniq 'dbA' 2 '7.20260101' 60 'ok' 9
        $b2 = Run $uniq 'dbA' 1 '8.20260101' 60 'ok' 11
        $b3 = Run $uniq 'dbB' 1 '7.20260101' 60 'ok' 13
        $b4 = Run ($uniq + 'x') 'dbA' 1 '7.20260101' 60 'ok' 15
        Check ((Loads) -eq 4) 'company, price list, database and area each have their own entry'
        Check ($b1.MinAmount -eq 9 -and $b2.MinAmount -eq 11 -and $b3.MinAmount -eq 13 -and $b4.MinAmount -eq 15) 'no value leaks between companies, price lists, databases or areas'
        $again = Run $uniq 'dbA' 1 '7.20260101' 60 'ok' 99
        Check ($again.MinAmount -eq 5) 'original entry still intact after other keys'
        # 3) senza database, azienda o durata non si usa la cache
        $loadsField.SetValue($null, 0)
        [void](Run $uniq '' 1 'x' 60 'ok' 5); [void](Run $uniq '' 1 'x' 60 'ok' 5)
        [void](Run $uniq 'dbA' 0 'x' 60 'ok' 5); [void](Run $uniq 'dbA' 0 'x' 60 'ok' 5)
        [void](Run $uniq 'dbA' 1 'x' 0 'ok' 5); [void](Run $uniq 'dbA' 1 'x' 0 'ok' 5)
        Check ((Loads) -eq 6) 'missing database, company or duration never caches'
        # 4) un guasto tecnico non diventa "nessuna promozione"
        $loadsField.SetValue($null, 0)
        $t1 = Run $uniq 'dbA' 31 'fail' 60 'throw' 5
        $t2 = Run $uniq 'dbA' 31 'fail' 60 'ok' 6
        $t3 = Run $uniq 'dbA' 31 'fail' 60 'ok' 99
        Check ($null -eq $t1 -and (Loads) -eq 2 -and $t2.HasPromo -and $t2.MinAmount -eq 6 -and [object]::ReferenceEquals($t2, $t3)) 'technical failure is not cached, next request reads again'
        $loadsField.SetValue($null, 0)
        $n1 = Run $uniq 'dbA' 32 'nil' 60 'nothing' 5
        $n2 = Run $uniq 'dbA' 32 'nil' 60 'ok' 7
        Check ($null -eq $n1 -and (Loads) -eq 2 -and $n2.MinAmount -eq 7) 'a missing result is not cached'
        # 5) un risultato valido ma vuoto (nessuna promozione) e un risultato: si memorizza
        $loadsField.SetValue($null, 0)
        $e1 = Run $uniq 'dbA' 33 'none' 60 'empty' 0
        $e2 = Run $uniq 'dbA' 33 'none' 60 'ok' 9
        Check ((Loads) -eq 1 -and -not $e1.HasPromo -and -not $e2.HasPromo) 'valid empty result is cached'
        # 6) la scadenza fa rileggere
        $loadsField.SetValue($null, 0)
        [void](Run $uniq 'dbA' 34 'ttl' 1 'ok' 5)
        Start-Sleep -Milliseconds 1700
        $x2 = Run $uniq 'dbA' 34 'ttl' 1 'ok' 8
        Check ((Loads) -eq 2 -and $x2.MinAmount -eq 8) 'entry expires and is read again'
        # 7) forma della chiave
        $k1 = [string]$keyMethod.Invoke($null, [object[]]@('Area', 'scopeX', 12, 'extraY'))
        $k2 = [string]$keyMethod.Invoke($null, [object[]]@('Area', 'scopeX', 13, 'extraY'))
        $k3 = [string]$keyMethod.Invoke($null, [object[]]@('Area', 'scopeX', 12, 'extraZ'))
        $k4 = [string]$keyMethod.Invoke($null, [object[]]@('Area', 'scopeW', 12, 'extraY'))
        $k0 = [string]$keyMethod.Invoke($null, [object[]]@('Area', '', 12, 'extraY'))
        Check ($k1.Contains('Area') -and $k1.Contains('scopeX') -and $k1.Contains('12') -and $k1.Contains('extraY') -and (@($k1, $k2, $k3, $k4 | Select-Object -Unique).Count -eq 4) -and $k0 -eq '') 'key carries area, database, company and extra key'
        # 8) invarianti dell'istantanea e della tabella
        $s1 = (New-Object -TypeName 'System.Object')
        $snap = $compiled.CompiledAssembly.GetType('FreeShippingPromoSnapshot', $true)
        $cons = $snap.GetConstructors()[0]
        $p1 = $cons.Invoke([object[]]@($true, [decimal]0))
        $p2 = $cons.Invoke([object[]]@($false, [decimal]7))
        $p3 = $cons.Invoke([object[]]@($true, [decimal]-1))
        $p4 = $cons.Invoke([object[]]@($true, [decimal]49))
        Check (-not $p1.HasPromo -and -not $p2.HasPromo -and $p2.MinAmount -eq 0 -and -not $p3.HasPromo -and $p4.HasPromo -and $p4.MinAmount -eq 49) 'free shipping snapshot is valid only with a positive amount'
        $tc = [string]$probe.GetMethod('TableCopies').Invoke($null, @())
        Check ($tc -ceq '1|1|True') 'cached table: every caller gets an independent copy, a null table is rejected'
    }
    finally { $compiler.Dispose() }
    return @{ Compiled = $true; Failed = @($failed) }
}

$helper = Read-Repo 'App_Code/StorefrontTenantScopedCache.vb'
$run = Invoke-HelperBehavior $helper
Assert-Source ($run.Compiled) 'HELPER_COMPILES'
Assert-Source (@($run.Failed).Count -eq 0) ('HELPER_BEHAVIOUR_OK' + $(if (@($run.Failed).Count -gt 0) { ' failed: ' + ($run.Failed -join ' | ') } else { '' }))

function Test-HelperMutation([string]$old, [string]$new, [string]$code) {
    $mutated = Mutate-Text $helper $old $new $code
    $r = Invoke-HelperBehavior $mutated
    if (-not $r.Compiled) { throw ('MUTATION_DOES_NOT_COMPILE=' + $code + ' ' + ($r.Failed -join '; ')) }
    Assert-Detected (@($r.Failed).Count -eq 0) $code
}
Test-HelperMutation 'companyId.ToString(CultureInfo.InvariantCulture) & "." & Convert.ToString(extraKey).Trim()' 'Convert.ToString(extraKey).Trim()' 'H01_KEY_WITHOUT_COMPANY'
Test-HelperMutation 'area.Trim() & "." & databaseScopeKey.Trim() & "."' 'area.Trim() & "."' 'H02_KEY_WITHOUT_DATABASE'
# Una durata nulla inserirebbe una voce gia scaduta: il comportamento e quasi equivalente, quindi la regola si controlla sul sorgente.
function Test-HelperDurationGuard([string]$h) { return $h.Contains('If key.Length = 0 OrElse ttlSeconds <= 0 Then Return SafeLoad(loader)') }
Assert-Source (Test-HelperDurationGuard $helper) 'HELPER_ZERO_DURATION_NEVER_CACHES'
Assert-Detected (Test-HelperDurationGuard (Mutate-Text $helper 'If key.Length = 0 OrElse ttlSeconds <= 0 Then Return SafeLoad(loader)' 'If key.Length = 0 Then Return SafeLoad(loader)' 'H03')) 'H03_ZERO_DURATION_CACHES'
Test-HelperMutation 'If String.IsNullOrWhiteSpace(area) OrElse String.IsNullOrWhiteSpace(databaseScopeKey) OrElse companyId <= 0 Then Return String.Empty' 'If String.IsNullOrWhiteSpace(area) Then Return String.Empty' 'H04_MISSING_SCOPE_CACHES'
Test-HelperMutation 'If loaded Is Nothing Then Return Nothing' 'If loaded Is Nothing Then loaded = CType(Activator.CreateInstance(GetType(T), New Object() {False, 0D}), T)' 'H05_FAILURE_BECOMES_EMPTY_RESULT'
Test-HelperMutation 'DateTime.UtcNow.AddSeconds(ttlSeconds)' 'DateTime.UtcNow.AddSeconds(ttlSeconds + 3600)' 'H06_NO_EXPIRY'
Test-HelperMutation '_table = table.Copy()' '_table = table' 'H07_TABLE_NOT_COPIED_ON_STORE'
Test-HelperMutation 'Return _table.Copy()' 'Return _table' 'H08_TABLE_NOT_COPIED_ON_READ'
Test-HelperMutation 'Me.HasPromo = hasPromo AndAlso minAmount > 0D' 'Me.HasPromo = hasPromo' 'H09_PROMO_WITHOUT_AMOUNT'

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 2 - controlli statici
# ---------------------------------------------------------------------------------------------------------------------------------
$ctx = Read-Repo 'App_Code/StorefrontSeoTenantContext.vb'
$policy = Read-Repo 'App_Code/StorefrontCanonicalHostPolicy.vb'
$header = Read-Repo 'Public/ui/controls/SiteHeader.ascx.vb'
$master = Read-Repo 'Page.master.vb'
$aspx = Read-Repo 'Default.aspx'
$vb = Read-Repo 'Default.aspx.vb'
$headerAscx = Read-Repo 'Public/ui/controls/SiteHeader.ascx'

function Test-TenantContext([string]$c, [string]$p) {
    return ($c.Contains('SELECT Id, Nome, Descrizione, url1, url2, LogoWeb, ListinoDefault, telefono, email FROM aziende ORDER BY Id') -and
            $c.Contains('identity.SupportPhone = SafeReaderString(reader, "telefono")') -and $c.Contains('identity.SupportEmail = SafeReaderString(reader, "email")') -and
            $c -notmatch 'FindConfiguredTenant' -and
            $p.Contains('Public Property SupportPhone As String') -and $p.Contains('Public Property SupportEmail As String'))
}
function Test-HeaderSource([string]$h) {
    $contacts = Get-Method $h 'BindCompanyContacts'
    $logo = Get-Method $h 'LoadHeaderLogoInfo'
    $tenantFn = Get-Method $h 'ResolveHeaderTenant'
    $promo = Get-Method $h 'BindFreeShippingPromo'
    $loader = [regex]::Match($h, '(?ms)^    Private Shared Function LoadFreeShippingPromoSnapshot\(.*?^    End Function').Value
    $sec = [regex]::Match($h, 'Private Const FreeShippingPromoCacheSeconds As Integer = (\d+)')
    return ($contacts.Contains('ResolveHeaderTenant()') -and $contacts.Contains('tenant.SupportPhone') -and $contacts.Contains('tenant.SupportEmail') -and
            $contacts.IndexOf('ResolveHeaderTenant()') -lt $contacts.IndexOf('SELECT telefono, email') -and
            $logo.Contains('ResolveHeaderTenant()') -and $logo.Contains('tenant.LogoFileName') -and $logo.IndexOf('ResolveHeaderTenant()') -lt $logo.IndexOf('SELECT LogoWeb') -and
            $tenantFn.Contains('StorefrontSeoTenantContext.Resolve(HttpContext.Current)') -and $tenantFn.Contains('If sessionCompanyId > 0 AndAlso sessionCompanyId <> tenant.CompanyId Then Return Nothing') -and
            $h.Contains('Private Function ResolveHeaderCompanyId() As Integer') -and $promo.Contains('Dim tenant As StorefrontSeoTenantIdentity = ResolveHeaderTenant()') -and
            $promo.Contains('If tenant Is Nothing Then Return') -and $promo.Contains('Dim companyId As Integer = tenant.CompanyId') -and $promo -notmatch 'ResolveHeaderCompanyId' -and
            $promo.Contains('StorefrontTenantScopedCache.GetOrLoad(Of FreeShippingPromoSnapshot)(') -and $promo.Contains('"HeaderFreeShipping"') -and
            [regex]::IsMatch($promo, 'GetOrLoad\(Of FreeShippingPromoSnapshot\)\(\s*\n\s*"HeaderFreeShipping",\s*\n\s*StorefrontSeoTenantContext\.ConfiguredDatabaseScopeKey\(\),\s*\n\s*companyId,\s*\n\s*listino\.ToString\(CultureInfo\.InvariantCulture\),\s*\n\s*FreeShippingPromoCacheSeconds') -and
            $promo.Contains('Function() LoadFreeShippingPromoSnapshot(companyId, listino)') -and -not $promo.Contains('CURDATE()') -and
            $loader.Contains('CURDATE()') -and $loader.Contains('AziendeID=@companyId') -and $loader.Contains('@listino') -and -not $loader.Contains('Catch') -and
            $sec.Success -and [int]$sec.Groups[1].Value -ge 30 -and [int]$sec.Groups[1].Value -le 300)
}
function Test-MasterSource([string]$m) {
    return ($m -notmatch 'Load_social_buttons' -and $m -notmatch 'social_buttons' -and $m -notmatch 'social_buttons_rules')
}
function Test-AspxViewState([string]$a) {
    $tags = [regex]::Matches($a, '<asp:Repeater\b[^>]*>')
    if ($tags.Count -lt 15) { return $false }
    foreach ($t in $tags) { if ($t.Value -notmatch 'EnableViewState="false"') { return $false } }
    return $true
}
function Test-DefaultVb([string]$v) {
    $load = Get-Method $v 'Page_Load'
    $loader = Get-Method $v 'LoadHomeNavigationAssortment'
    $reader = Get-Method $v 'ReadHomeNavigationAssortment'
    $sec = [regex]::Match($v, 'Private Const HomeAssortmentCacheSeconds As Integer = (\d+)')
    $uses = [regex]::Matches($v, 'StorefrontTenantScopedCache\.GetOrLoad').Count
    return ($load.Contains('BindHome()') -and $load -notmatch 'If Not IsPostBack Then\s*\n\s*BindHome\(\)' -and
            $loader.Contains('StorefrontTenantScopedCache.GetOrLoad(Of StorefrontCachedTable)(') -and $loader.Contains('"HomeAssortment"') -and
            [regex]::IsMatch($loader, 'GetOrLoad\(Of StorefrontCachedTable\)\(\s*\n\s*"HomeAssortment",\s*\n\s*StorefrontSeoTenantContext\.ConfiguredDatabaseScopeKey\(\),\s*\n\s*GetCurrentAziendaId\(\),\s*\n\s*listino\.ToString\(CultureInfo\.InvariantCulture\),') -and $loader.Contains('Return snapshot.CopyTable()') -and
            $loader.Contains('If snapshot Is Nothing Then Return Nothing') -and $loader.Contains('If listino <= 0 Then') -and
            $reader.Contains('MySqlDbType.Int32') -and $reader.Contains('Return Nothing') -and $reader.Contains('InvalidateHomeQueryConnection()') -and
            $sec.Success -and [int]$sec.Groups[1].Value -ge 30 -and [int]$sec.Groups[1].Value -le 300 -and $uses -eq 1)
}
function Test-CommercialNotCached([string]$v) {
    foreach ($n in @('GetDealOfferPool', 'GetNewArrivalsPool', 'GetIncomingPool', 'GetBestSellerPool', 'QueryProducts', 'TryLoadProducts', 'GetCatalogFallbackPool', 'GetRecentlyViewedProducts', 'PopulatePromotionDisplaySnapshot')) {
        $body = Get-Method $v $n
        if (-not $body) { return $false }
        if ($body -match 'StorefrontTenantScopedCache|HttpRuntime\.Cache|\.Cache\(') { return $false }
    }
    return $true
}
function Test-HeaderMobileViewState([string]$ascx, [string]$h) {
    foreach ($id in @('rptNavSettoriMobile', 'rptNavCategorieMobile', 'rptNavTipologieMobile')) {
        $tag = [regex]::Match($ascx, '<asp:Repeater ID="' + $id + '"[^>]*>').Value
        if (-not $tag -or $tag -notmatch 'EnableViewState="false"') { return $false }
    }
    $pre = Get-Method $h 'Page_PreRender'
    return ($pre.Contains('If IsPostBack Then') -and $pre.Contains('BindDesktopCatalog(catalogMenu)') -and $pre.Contains('BindMobileCatalog(catalogMenu)') -and
            $pre.IndexOf('If IsPostBack Then') -lt $pre.IndexOf('BindMobileCatalog(catalogMenu)') -and $h.Contains('rptNavSettoriMobile.DataBind()'))
}
function Test-ImageHints([string]$a, [string]$v) {
    $hero = [regex]::Match($a, '<img width="800" height="794"[^>]*>').Value
    $brand = [regex]::Match($a, '<img class="lazyload"[^>]*BrandImage[^>]*>').Value
    $hover = [regex]::Match($v, 'class=''img-hover lazyload''[^;]*?src=').Value
    $gallery = [regex]::Match($v, '<img class=''lazyload'' loading=''lazy'' decoding=''async'' src=').Value
    $cover = [regex]::Matches($v, 'class=''(?:lazyload img-product|img-product lazyload)'' decoding=''async'' src=')
    return ($hero.Contains('fetchpriority="high"') -and $hero.Contains('decoding="async"') -and $hero -notmatch 'lazyload|loading=' -and
            $brand.Contains('loading="lazy"') -and $hover.Contains('loading=''lazy''') -and $gallery -ne '' -and $cover.Count -eq 2 -and
            $v -notmatch 'img-product[^;]{0,40}loading=')
}
function Test-HelperUsers() {
    $files = @(& git -C $repoRoot grep -l -E 'StorefrontTenantScopedCache\.GetOrLoad' -- '*.vb' '*.aspx' '*.ascx' '*.master' | Where-Object { $_ -notmatch '^Tools/' })
    $expected = @('Default.aspx.vb', 'Public/ui/controls/SiteHeader.ascx.vb')
    return ((@($files | Sort-Object) -join '|') -ceq (($expected | Sort-Object) -join '|'))
}

Assert-Source (Test-TenantContext $ctx $policy) 'TENANT_IDENTITY_CARRIES_SUPPORT_CONTACTS'
Assert-Source (Test-HeaderSource $header) 'HEADER_USES_CACHED_IDENTITY_AND_CACHED_FREE_SHIPPING'
Assert-Source (Test-MasterSource $master) 'MASTER_HAS_NO_UNUSED_SOCIAL_QUERIES'
Assert-Source (Test-AspxViewState $aspx) 'HOME_REPEATERS_HAVE_NO_VIEWSTATE'
Assert-Source (Test-DefaultVb $vb) 'HOME_ASSORTMENT_CACHE_KEYED_AND_COPIED'
Assert-Source (Test-CommercialNotCached $vb) 'HOME_COMMERCIAL_POOLS_NEVER_CACHED'
Assert-Source (Test-HelperUsers) 'CACHE_HELPER_USED_ONLY_BY_THE_TWO_REVIEWED_CALLERS'
Assert-Source (Test-ImageHints $aspx $vb) 'HOME_IMAGE_PRIORITY_AND_LAZY_LOADING_HINTS'
Assert-Source (Test-HeaderMobileViewState $headerAscx $header) 'HEADER_MOBILE_MENU_HAS_NO_VIEWSTATE_AND_REBUILDS_AFTER_POSTBACK'

# mutazioni statiche
Assert-Detected (Test-TenantContext (Mutate-Text $ctx 'LogoWeb, ListinoDefault, telefono, email FROM aziende' 'LogoWeb, ListinoDefault FROM aziende' 'S01') $policy) 'S01_TENANT_QUERY_WITHOUT_CONTACTS'
Assert-Detected (Test-HeaderSource (Mutate-Text $header '        If sessionCompanyId > 0 AndAlso sessionCompanyId <> tenant.CompanyId Then Return Nothing
' '' 'S02')) 'S02_SESSION_COMPANY_DIFFERENT_FROM_HOST_IS_ACCEPTED'
Assert-Detected (Test-HeaderSource (Mutate-Text $header 'Dim tenant As StorefrontSeoTenantIdentity = ResolveHeaderTenant()
        If tenant IsNot Nothing Then
            If Not String.IsNullOrWhiteSpace(tenant.SupportPhone)' 'Dim tenant As StorefrontSeoTenantIdentity = Nothing
        If tenant IsNot Nothing Then
            If Not String.IsNullOrWhiteSpace(tenant.SupportPhone)' 'S03')) 'S03_CONTACTS_READ_AGAIN_FROM_DATABASE'
Assert-Detected (Test-HeaderSource (Mutate-Text $header '                listino.ToString(CultureInfo.InvariantCulture),
                FreeShippingPromoCacheSeconds' '                "x",
                FreeShippingPromoCacheSeconds' 'S04')) 'S04_SHIPPING_KEY_WITHOUT_PRICE_LIST'
Assert-Detected (Test-HeaderSource (Mutate-Text $header '            Dim tenant As StorefrontSeoTenantIdentity = ResolveHeaderTenant()
            If tenant Is Nothing Then Return
            Dim companyId As Integer = tenant.CompanyId' '            Dim companyId As Integer = ResolveHeaderCompanyId()' 'S27')) 'S27_SHIPPING_COMPANY_FROM_SESSION_ONLY'
Assert-Detected (Test-HeaderSource (Mutate-Text $header '                companyId,
                listino.ToString' '                1,
                listino.ToString' 'S05')) 'S05_SHIPPING_KEY_WITHOUT_COMPANY'
Assert-Detected (Test-HeaderSource (Mutate-Text $header '                StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(),
                companyId,' '                "fixed",
                companyId,' 'S06')) 'S06_SHIPPING_KEY_WITHOUT_DATABASE'
Assert-Detected (Test-HeaderSource (Mutate-Text $header 'FreeShippingPromoCacheSeconds As Integer = 120' 'FreeShippingPromoCacheSeconds As Integer = 3600' 'S07')) 'S07_SHIPPING_CACHE_TOO_LONG'
Assert-Detected (Test-HeaderSource (Mutate-Text $header 'Return New FreeShippingPromoSnapshot(False, 0D)
    End Function' 'Return New FreeShippingPromoSnapshot(False, 0D)
        Catch
            Return New FreeShippingPromoSnapshot(False, 0D)
    End Function' 'S08')) 'S08_SHIPPING_LOADER_SWALLOWS_FAILURE'
Assert-Detected (Test-HeaderSource (Mutate-Text $header 'AziendeID=@companyId AND v.Abilitato=1' 'AziendeID>0 AND v.Abilitato=1' 'S09')) 'S09_SHIPPING_QUERY_NOT_COMPANY_SCOPED'
Assert-Detected (Test-MasterSource ($master + "`nSub Load_social_buttons()`nEnd Sub`n")) 'S10_SOCIAL_QUERIES_COME_BACK'
Assert-Detected (Test-AspxViewState (Mutate-Text $aspx '<asp:Repeater ID="rptBestSeller" runat="server" EnableViewState="false">' '<asp:Repeater ID="rptBestSeller" runat="server">' 'S11')) 'S11_REPEATER_SAVES_VIEWSTATE_AGAIN'
Assert-Detected (Test-DefaultVb (Mutate-Text $vb 'BindHome()
    End Sub

    Private Sub MarkBodyAsHome()' 'If Not IsPostBack Then
            BindHome()
        End If
    End Sub

    Private Sub MarkBodyAsHome()' 'S12')) 'S12_POSTBACK_RENDERS_EMPTY_HOME'
Assert-Detected (Test-DefaultVb (Mutate-Text $vb '            GetCurrentAziendaId(),
            listino.ToString(CultureInfo.InvariantCulture),' '            1,
            listino.ToString(CultureInfo.InvariantCulture),' 'S13')) 'S13_ASSORTMENT_KEY_WITHOUT_COMPANY'
Assert-Detected (Test-DefaultVb (Mutate-Text $vb '            GetCurrentAziendaId(),
            listino.ToString(CultureInfo.InvariantCulture),' '            GetCurrentAziendaId(),
            "x",' 'S14')) 'S14_ASSORTMENT_KEY_WITHOUT_PRICE_LIST'
Assert-Detected (Test-DefaultVb (Mutate-Text $vb 'Return snapshot.CopyTable()' 'Return Nothing' 'S15')) 'S15_ASSORTMENT_NOT_HANDED_AS_COPY'
Assert-Detected (Test-DefaultVb (Mutate-Text $vb 'Private Const HomeAssortmentCacheSeconds As Integer = 120' 'Private Const HomeAssortmentCacheSeconds As Integer = 86400' 'S16')) 'S16_ASSORTMENT_CACHE_TOO_LONG'
Assert-Detected (Test-DefaultVb ($vb + "`n' StorefrontTenantScopedCache.GetOrLoad second use`n")) 'S17_SECOND_UNREVIEWED_CACHE_USE'
$poolMutated = Mutate-Text $vb 'Private Function GetBestSellerPool(ByVal limit As Integer) As DataTable
        Return QueryProducts(' 'Private Function GetBestSellerPool(ByVal limit As Integer) As DataTable
        Dim cached = StorefrontTenantScopedCache.GetOrLoad(Of StorefrontCachedTable)("x", "y", 1, "z", 60, Nothing)
        Return QueryProducts(' 'S18'
Assert-Detected (Test-CommercialNotCached $poolMutated) 'S18_PRICE_BEARING_POOL_GETS_CACHED'
Assert-Detected (Test-HeaderMobileViewState (Mutate-Text $headerAscx '<asp:Repeater ID="rptNavSettoriMobile" runat="server" EnableViewState="false"' '<asp:Repeater ID="rptNavSettoriMobile" runat="server"' 'S19') $header) 'S19_MOBILE_MENU_SAVES_VIEWSTATE_AGAIN'
Assert-Detected (Test-HeaderMobileViewState (Mutate-Text $headerAscx '<asp:Repeater ID="rptNavTipologieMobile" runat="server" EnableViewState="false">' '<asp:Repeater ID="rptNavTipologieMobile" runat="server">' 'S20') $header) 'S20_NESTED_MOBILE_REPEATER_SAVES_VIEWSTATE_AGAIN'
Assert-Detected (Test-HeaderMobileViewState $headerAscx (Mutate-Text $header '            BindMobileCatalog(catalogMenu)
        End If
    End Sub' '        End If
    End Sub' 'S21')) 'S21_MOBILE_MENU_EMPTY_AFTER_POSTBACK'
Assert-Detected (Test-ImageHints (Mutate-Text $aspx 'fetchpriority="high" ' '' 'S22') $vb) 'S22_HERO_LOSES_PRIORITY'
Assert-Detected (Test-ImageHints (Mutate-Text $aspx '<img width="800" height="794" fetchpriority="high"' '<img width="800" height="794" loading="lazy" fetchpriority="high"' 'S23') $vb) 'S23_HERO_BECOMES_LAZY'
Assert-Detected (Test-ImageHints (Mutate-Text $aspx 'loading="lazy" decoding="async" src=''<%# BrandImage' 'decoding="async" src=''<%# BrandImage' 'S24') $vb) 'S24_BRAND_LOGOS_EAGER_AGAIN'
Assert-Detected (Test-ImageHints $aspx (Mutate-Text $vb 'class=''img-hover lazyload'' loading=''lazy'' decoding=''async''' 'class=''img-hover lazyload'' decoding=''async''' 'S25')) 'S25_HOVER_IMAGES_EAGER_AGAIN'
Assert-Detected (Test-ImageHints $aspx (Mutate-Text $vb 'class=''img-product lazyload'' decoding=''async''' 'class=''img-product lazyload'' loading=''lazy'' decoding=''async''' 'S26')) 'S26_COVER_IMAGE_BECOMES_LAZY'
Write-Output 'HOME_PERF_CACHES_OK'
