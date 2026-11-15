[CmdletBinding()]
param()

# KS-A04-HOME-CARDS-1A - card della HOME come quelle del catalogo (solo presentazione).
# Parte 1: il VERO RenderGridCard / RenderActionButtons di Default.aspx.vb sono compilati e provati (targhetta Novita/In arrivo con soli due testi
#          ammessi e sempre codificata, foto di scorrimento senza nome accessibile duplicato, pulsanti di azione identici a prima).
# Parte 2: controlli statici sul foglio di stile (riquadro quadrato a una sola cornice, azioni dentro il riquadro per fasce di larghezza ricavate
#          dalla geometria, titolo e prezzo come il catalogo, focus da tastiera, contrasto del grigio, nessuna perdita verso la scheda offerta).
# Ogni regola e provata con mutazioni: se la regola viene tolta il test deve fallire.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'HOME_CARDS_REQUIRES_PS51' }
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
function Method-Map([string]$source) {
    $map = @{}
    foreach ($m in [regex]::Matches($source, '(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^    End (?:Function|Sub)')) {
        $n = $m.Groups[1].Value
        if (-not $map.ContainsKey($n)) { $map[$n] = @() }
        $map[$n] += $m.Value
    }
    return $map
}
function Get-Method([string]$source, [string]$name) {
    $m = [regex]::Match($source, '(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) ' + [regex]::Escape($name) + '\b.*?^    End (?:Function|Sub)')
    if (-not $m.Success) { return '' }
    return $m.Value
}
function Normalize-Id([string]$html) { return [regex]::Replace($html, "(?i)(data-ks-request-id=')[a-f0-9]{32}", '$1FIXTURE_REQUEST_ID') -replace "(?i)(ksCartAction' value=')[^']*", '$1FIXTURE_ACTION' }

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 1 - comportamento reale
# ---------------------------------------------------------------------------------------------------------------------------------
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
$vbSource = Read-Repo 'Default.aspx.vb'
$wordNovita = 'Novit' + [char]0x00E0
$wordIncoming = 'In arrivo'
$encNovita = [System.Web.HttpUtility]::HtmlEncode($wordNovita)   # il testo esce sempre codificato (a con accento -> entita)

function Compile-Probe([string]$pageSource) {
    $methods = Method-Map $pageSource
    $names = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $queue = New-Object 'Collections.Generic.Queue[string]'
    @('RenderGridCard', 'EmptyProductsTable', 'RenderActionButtons') | ForEach-Object { $queue.Enqueue($_) }
    while ($queue.Count) {
        $n = $queue.Dequeue()
        if (-not $names.Add($n)) { continue }
        if (-not $methods.ContainsKey($n)) { throw ('HOME_CARDS_MISSING_METHOD ' + $n) }
        foreach ($body in $methods[$n]) { foreach ($call in [regex]::Matches($body, '\b(\w+)\s*\(')) { $d = $call.Groups[1].Value; if ($methods.ContainsKey($d) -and -not $names.Contains($d)) { $queue.Enqueue($d) } } }
    }
    $bodies = foreach ($n in $names) { $methods[$n] }
    $wrapper = @'
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Public Sub Configure(company As Integer, listino As Integer, authenticated As Boolean, included As Boolean)
        _priceDisplayContext = New StorefrontPriceDisplayContext(company, listino, authenticated, If(included, StorefrontVatDisplayMode.VatIncluded, StorefrontVatDisplayMode.VatExcluded), Nothing, -1, "", False)
    End Sub
    Public Function Table() As DataTable
        Dim rows As DataTable = EmptyProductsTable()
        If Not rows.Columns.Contains("TCid") Then rows.Columns.Add("TCid", GetType(Integer))
        Return rows
    End Function
    Public Function Card(row As DataRow) As String
        Return RenderGridCard(row.Table.DefaultView(row.Table.Rows.IndexOf(row)))
    End Function
    Public Function Buttons(row As DataRow) As String
        Return RenderActionButtons(row, False)
    End Function
'@
    $code = "Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text`nImports System.Text.RegularExpressions`nImports System.Web`nPublic Class CardProbe`n" + ($bodies -join "`n") + "`n" + $wrapper + "`nEnd Class"
    $cart = Method-Map ([IO.File]::ReadAllText((Join-Path $repoRoot 'App_Code/CartMutationIdempotencyService.vb')))
    $cartCode = "Imports System`nImports System.Globalization`nImports System.Web`nPublic Class CartMutationIdempotencyService`n" + ((@('CreateRequestId', 'BuildNativeActionValue', 'NormalizeTCId') | ForEach-Object { $cart[$_] }) -join "`n") + "`nEnd Class"
    $shared = @('StorefrontPriceDisplayContext.vb', 'UiPriceFormatter.vb', 'AvailabilityDisplayHelper.vb', 'ThemeManager.vb', 'UiData.vb', 'StorefrontEffectivePriceSqlBuilder.vb', 'StorefrontPromotionDisplayPolicy.vb', 'StorefrontProductImageSlots.vb', 'StorefrontCommercialIsolationPolicy.vb', 'CartStorefrontScopePolicy.vb') |
        ForEach-Object { [IO.File]::ReadAllText((Join-Path $repoRoot ('App_Code/' + $_))) }
    $inv = Method-Map ([IO.File]::ReadAllText((Join-Path $repoRoot 'App_Code/OrderInventoryAvailabilityService.vb')))
    $shared += ("Imports System`nPublic Class OrderInventoryAvailabilityService`n" + $inv['CalculateNetAvailableQuantity'][0] + "`nEnd Class")
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    $p.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Xml.dll', 'System.Web.dll', 'System.Configuration.dll') | ForEach-Object { [void]$p.ReferencedAssemblies.Add($_) }
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]](@($code, $cartCode) + $shared))
    if ($c.Errors.HasErrors) { throw ('HOME_CARDS_COMPILE ' + (($c.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 5 | ForEach-Object { 'line ' + $_.Line + ': ' + $_.ErrorText }) -join '; ')) }
    return [Activator]::CreateInstance($c.CompiledAssembly.GetType('CardProbe', $true))
}

function New-Row($probe, [string]$label, [bool]$informative, [bool]$withLabelColumn) {
    $t = $probe.Table()
    if ($withLabelColumn) { [void]$t.Columns.Add('HomeMerchandisingLabel', [string]) }
    [void]$t.Columns.Add('HomeInformativeOnly', [bool])
    $r = $t.NewRow()
    $r['id'] = 4242
    $r['Descrizione1'] = 'Cavo di prova'
    $r['Descrizione2'] = 'lungo 2 metri'
    $r['HomeInformativeOnly'] = $informative
    if ($withLabelColumn) { $r['HomeMerchandisingLabel'] = $label }
    [void]$t.Rows.Add($r)
    return $r
}

function Test-CardBehaviour($probe, [string]$name) {
    $probe.Configure(101, 1, $false, $true)
    $ok = $true
    # R01 targhetta ammessa: dentro la categoria, codificata, senza la vecchia barra
    $r = New-Row $probe $wordNovita $false $true
    $html = $probe.Card($r)
    $catMatch = [regex]::Match($html, "(?s)<p class='caption text-main-2 font-2 ks-card-category'>(.*?)</p>")
    $tagOk = $catMatch.Success -and $catMatch.Groups[1].Value.StartsWith("<span class='ks-card-tag'>" + $encNovita + '</span>', [StringComparison]::Ordinal) -and ($html -notmatch 'badge bg-light') -and ($html -notmatch 'mb-8')
    $tagBeforeTitle = $html.IndexOf("class='ks-card-tag'") -gt $html.IndexOf("class='card-product-info'") -and $html.IndexOf("class='ks-card-tag'") -lt $html.IndexOf("name-product")
    # R02 secondo testo ammesso
    $incoming = $probe.Card((New-Row $probe $wordIncoming $true $true))
    $incomingOk = $incoming.Contains("<span class='ks-card-tag'>In arrivo</span>")
    # R03 testi non ammessi, vuoti o colonna assente: nessuna targhetta e nessun markup grezzo
    $evil = $probe.Card((New-Row $probe '<img src=x onerror=alert(1)>' $false $true))
    $other = $probe.Card((New-Row $probe 'Offerta' $false $true))
    $empty = $probe.Card((New-Row $probe '' $false $true))
    $noCol = $probe.Card((New-Row $probe '' $false $false))
    $noTagOk = ($evil -notmatch 'ks-card-tag') -and ($evil -notmatch 'onerror') -and ($other -notmatch 'ks-card-tag') -and ($empty -notmatch 'ks-card-tag') -and ($noCol -notmatch 'ks-card-tag')
    # R04 foto di scorrimento: nessun nome accessibile duplicato; foto principale con nome
    $hover = [regex]::Match($html, "<img class='img-hover[^>]*>").Value
    $main = [regex]::Match($html, "<img class='img-product[^>]*>").Value
    $imgOk = $hover.Contains("alt='' aria-hidden='true'") -and ($main -match "alt='[^']+'")
    # R05 le azioni stanno dentro il riquadro e sono quelle di prima; le schede solo informative non le hanno
    $wrapperStart = $html.IndexOf("<div class='card-product-wrapper'>")
    $wrapperEnd = $html.IndexOf("<div class='card-product-info'>")
    $actions = $probe.Buttons($r)
    $wrapperHtml = if (($wrapperStart -ge 0) -and ($wrapperEnd -gt $wrapperStart)) { $html.Substring($wrapperStart, $wrapperEnd - $wrapperStart) } else { '' }
    $inside = (Normalize-Id $wrapperHtml).Contains((Normalize-Id $actions))
    $liCount = ([regex]::Matches($actions, '<li\b')).Count
    $classesOk = $actions.Contains('js-ks-cart-link') -and $actions.Contains('js-ks-wishlist-link') -and $actions.Contains('js-ks-quickview') -and $actions.Contains('js-ks-compare') -and $actions.Contains("form='ksNativeCartForm'")
    $informativeOk = ($incoming -notmatch 'list-product-btn')
    # R06 prezzo: la variante compatta non porta piu la classe di peso del tema
    $priceOk = $html -match "<span class='new-price body-md-2 mb-0 ks-home-price-value ks-home-price-value--current'>" -and $html -notmatch 'body-md-2 fw-medium'
    $script:lastDetail = ('tagOk=' + $tagOk + ' tagBeforeTitle=' + $tagBeforeTitle + ' incomingOk=' + $incomingOk + ' noTagOk=' + $noTagOk + ' imgOk=' + $imgOk + ' inside=' + $inside + ' liCount=' + $liCount + ' classesOk=' + $classesOk + ' informativeOk=' + $informativeOk + ' priceOk=' + $priceOk)
    return ($tagOk -and $tagBeforeTitle -and $incomingOk -and $noTagOk -and $imgOk -and $inside -and ($liCount -eq 4) -and $classesOk -and $informativeOk -and $priceOk)
}

$probe = Compile-Probe $vbSource
$probe.Configure(101, 1, $false, $true)
$r = New-Row $probe $wordNovita $false $true
$html = $probe.Card($r)
$behaviourOk = Test-CardBehaviour $probe 'candidate'
if (-not $behaviourOk) { throw ('CARD_BEHAVIOUR_FAILED ' + $script:lastDetail) }
Assert-Source $behaviourOk 'CARD_BEHAVIOUR_TAG_IMG_ACTIONS_PRICE'
Assert-Source ($html.Contains("<span class='ks-card-tag'>" + $encNovita + '</span>') -and $encNovita -ne $wordNovita) 'CARD_TAG_NOVITA_IN_CATEGORY_LINE_ENCODED'
Assert-Source ((Normalize-Id $probe.Buttons($r)) -eq (Normalize-Id ([regex]::Match($html, "(?s)<ul class='list-product-btn top-0 end-0'>.*?</ul>").Value))) 'CARD_ACTION_STACK_IS_RENDERACTIONBUTTONS_OUTPUT'

# impronta del renderer dei pulsanti: il markup degli handler non cambia in questo task (l'hash e quello della versione di partenza dd8452a0)
$sha = [Security.Cryptography.SHA256]::Create()
$normBody = (Get-Method $vbSource 'RenderActionButtons')
$hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normBody))) -replace '-', '').ToLower()
$expectedHash = 'e1c547b4e02f02dd41530288e9d24174651929f99194d9aa3fe5625c10026e93'
Assert-Source ($hash -eq $expectedHash) 'ACTION_BUTTONS_RENDERER_UNCHANGED'

# mutazioni sul codice VB (compilate)
function Mutated-Probe([string]$old, [string]$new, [string]$code) { return (Compile-Probe (Mutate-Text $vbSource $old $new $code)) }
$m = Mutated-Probe "merchandisingTag = `"<span class='ks-card-tag'>`" & HttpUtility.HtmlEncode(label) & `"</span>`"" "merchandisingTag = `"<span class='badge bg-light text-dark mb-8'>`" & HttpUtility.HtmlEncode(label) & `"</span>`"" 'V01'
Assert-Detected (Test-CardBehaviour $m 'V01') 'V01_OLD_BAR_BADGE_BACK'
$oldIf = ('If label = "Novit' + [char]0x00E0 + '" OrElse label = "In arrivo" Then')
$m = Mutated-Probe $oldIf 'If label.Length > 0 Then' 'V02'
Assert-Detected (Test-CardBehaviour $m 'V02') 'V02_ANY_LABEL_ACCEPTED'
$m = Mutated-Probe '"<span class=''ks-card-tag''>" & HttpUtility.HtmlEncode(label) & "</span>"' '"<span class=''ks-card-tag''>" & label & "</span>"' 'V03'
$m.Configure(101, 1, $false, $true)
$novitaRow = New-Row $m $wordNovita $false $true
Assert-Detected ($m.Card($novitaRow).Contains("<span class='ks-card-tag'>" + $encNovita + '</span>')) 'V03_LABEL_NOT_ENCODED'
$m = Mutated-Probe "' alt='' aria-hidden='true'>" "' alt='x'>" 'V04'
Assert-Detected (Test-CardBehaviour $m 'V04') 'V04_HOVER_IMAGE_NAMED_AGAIN'
$m = Mutated-Probe '"new-price body-md-2 mb-0") & " ks-home-price-value' '"new-price body-md-2 fw-medium mb-0") & " ks-home-price-value' 'V05'
Assert-Detected (Test-CardBehaviour $m 'V05') 'V05_PRICE_WEIGHT_UTILITY_BACK'
$m = Mutated-Probe 'If Not informativeOnly Then sb.Append(RenderActionButtons(row, False))' 'sb.Append(RenderActionButtons(row, False))' 'V06'
Assert-Detected (Test-CardBehaviour $m 'V06') 'V06_INFORMATIVE_CARDS_GET_ACTIONS'

# ---------------------------------------------------------------------------------------------------------------------------------
# Parte 2 - foglio di stile e pagina
# ---------------------------------------------------------------------------------------------------------------------------------
$css = Read-Repo 'Public/assets/keepstore/css/theme-overrides.css'
$master = Read-Repo 'Page.master'

function Get-CardsBlock([string]$c) {
    $i = $c.IndexOf('KS-A04-HOME-CARDS-1A')
    if ($i -lt 0) { return '' }
    return $c.Substring($i)
}
function Hex-ToLuminance([string]$hex) {
    $h = $hex.TrimStart('#'); if ($h.Length -eq 3) { $h = ($h.ToCharArray() | ForEach-Object { "$_$_" }) -join '' }
    $v = @(0, 2, 4) | ForEach-Object { [Convert]::ToInt32($h.Substring($_, 2), 16) / 255.0 } | ForEach-Object { if ($_ -le 0.03928) { $_ / 12.92 } else { [Math]::Pow(($_ + 0.055) / 1.055, 2.4) } }
    return (0.2126 * $v[0] + 0.7152 * $v[1] + 0.0722 * $v[2])
}
function Contrast([string]$a, [string]$b) {
    $la = Hex-ToLuminance $a; $lb = Hex-ToLuminance $b
    if ($la -lt $lb) { $t = $la; $la = $lb; $lb = $t }
    return (($la + 0.05) / ($lb + 0.05))
}
$tile = 'body.ks-page-home #ksHomePage .ks-grid-card .card-product-wrapper'

function Test-TileRule([string]$c) {
    $b = Get-CardsBlock $c
    return ([regex]::IsMatch($b, '(?s)' + [regex]::Escape($tile) + ' \{\s*aspect-ratio: 1 / 1;\s*height: auto;\s*min-height: 0;\s*padding: 0;\s*border: 0;\s*background: #fff;\s*container: ks-tile / inline-size;\s*\}') -and
            [regex]::IsMatch($b, '(?s)' + [regex]::Escape($tile) + ' \.product-img \{\s*width: 100%;\s*height: 100%;\s*min-height: 0;\s*background: #fff;\s*\}') -and
            [regex]::IsMatch($b, '(?s)' + [regex]::Escape($tile) + ' \.img-product,\s*' + [regex]::Escape($tile) + ' \.img-hover \{\s*width: 100%;\s*height: 100%;\s*padding: 0;\s*object-fit: contain;\s*\}') -and
            $b.Contains('body.ks-page-home #ksHomePage .ks-grid-card { padding: 12px; }'))
}
function Test-ActionTiers([string]$c) {
    $b = Get-CardsBlock $c
    # fasce ricavate dalla geometria: 10px sopra e sotto, pulsanti da 40px, distanza 8px
    $edge = 10; $btn = 40; $gap = 8
    $needFour = 4 * $btn + 3 * $gap + 2 * $edge      # 204
    $needThree = 3 * $btn + 2 * $gap + 2 * $edge     # 156
    $q1 = [regex]::Match($b, '@container ks-tile \(max-width: ([\d.]+)px\) \{\s*body\.ks-page-home #ksHomePage \.ks-grid-card \.list-product-btn > li:has\(> \.js-ks-compare\) \{ display: none; \}\s*\}')
    $q2 = [regex]::Match($b, '(?s)@container ks-tile \(max-width: ([\d.]+)px\) \{\s*body\.ks-page-home #ksHomePage \.ks-grid-card \.list-product-btn > li:has\(> \.js-ks-quickview\) \{ display: none; \}\s*body\.ks-page-home #ksHomePage \.ks-grid-card \.list-product-btn \.box-icon \{\s*width: 44px;\s*height: 44px;\s*\}\s*\}')
    if (-not $q1.Success -or -not $q2.Success) { return $false }
    $t1 = [double]::Parse($q1.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    $t2 = [double]::Parse($q2.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    return ([Math]::Abs($t1 - ($needFour - 0.02)) -lt 0.001 -and [Math]::Abs($t2 - ($needThree - 0.02)) -lt 0.001 -and
            ((2 * 44 + 1 * $gap + 2 * $edge) -le $needThree))
}
function Test-TagAndText([string]$c) {
    $b = Get-CardsBlock $c
    $cat = [regex]::Match($b, 'ks-card-category,\s*\r?\n?body\.ks-page-home #HomeRecentlyViewedSection \.ks-recent-card \.ks-card-category \{ color: (#[0-9a-fA-F]{3,6}); \}')
    $tagM = [regex]::Match($b, '(?s)\.ks-grid-card \.ks-card-tag \{\s*display: inline;\s*margin-right: 6px;\s*padding: 1px 6px;\s*border-radius: 4px;\s*background: (#[0-9a-fA-F]{3,6});\s*color: (#[0-9a-fA-F]{3,6});\s*font-size: 11px;\s*font-weight: 700;\s*white-space: nowrap;')
    if (-not $cat.Success -or -not $tagM.Success) { return $false }
    $titleOk = [regex]::IsMatch($b, '(?s)\.ks-grid-card \.name-product,\s*body\.ks-page-home #HomeRecentlyViewedSection \.ks-recent-card \.name-product \{\s*font-size: 14px;\s*line-height: 22px;\s*font-weight: 600;\s*text-transform: none;\s*\}')
    return ($titleOk -and (Contrast $cat.Groups[1].Value '#ffffff') -ge 4.5 -and (Contrast $tagM.Groups[2].Value $tagM.Groups[1].Value) -ge 4.5)
}
function Test-RecentRules([string]$c) {
    $b = Get-CardsBlock $c
    $rw = 'body.ks-page-home #HomeRecentlyViewedSection .ks-recent-card .card-product-wrapper'
    return ([regex]::IsMatch($b, '(?s)' + [regex]::Escape($rw) + ' \{\s*aspect-ratio: 1 / 1;\s*height: auto;\s*min-height: 0;\s*background: #fff;\s*\}') -and
            [regex]::IsMatch($b, '(?s)' + [regex]::Escape($rw) + ' \.product-img \{\s*width: 100%;\s*height: 100%;\s*min-height: 0;\s*\}') -and
            [regex]::IsMatch($b, '(?s)' + [regex]::Escape($rw) + ' \.img-product,\s*' + [regex]::Escape($rw) + ' \.img-hover \{\s*width: 100%;\s*height: 100%;\s*padding: 0;\s*object-fit: contain;\s*\}'))
}
function Test-KeyboardRules([string]$c) {
    $b = Get-CardsBlock $c
    return ([regex]::IsMatch($b, '(?s)\.ks-grid-card:has\(:focus-visible\) \.list-product-btn > li \{\s*opacity: 1;\s*visibility: visible;\s*transform: none;\s*transition: none;\s*\}') -and
            [regex]::IsMatch($b, '(?s)\.ks-grid-card \.list-product-btn \.box-icon:focus-visible \{\s*outline: 2px solid var\(--primary-2, #D80027\);\s*outline-offset: -4px;\s*\}'))
}
function Test-PriceRule([string]$c) {
    return [regex]::IsMatch($c, '(?s)#ksHomePage \.ks-grid-card \.new-price\.ks-home-price-value--current \{\s*color: var\(--black, #121212\);\s*font-size: 22px;\s*line-height: 26px;\s*font-weight: 700;\s*white-space: nowrap;\s*\}')
}
function Test-NoLeakToDeals([string]$c) {
    $b = Get-CardsBlock $c
    if ($b.Length -lt 500) { return $false }
    $b = $b.Substring($b.IndexOf('*/') + 2)
    $b = [regex]::Replace($b, '(?s)/\*.*?\*/', '')
    # ogni selettore del blocco riguarda solo le card della griglia o dei visti di recente: mai la scheda offerta
    $selectors = [regex]::Matches($b, '(?m)^\s*([^{}/@\r\n][^{}\r\n]*?)\s*(?:,|\{)\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() }
    $bad = $selectors | Where-Object { $_ -match 'ks-deal' -or ($_ -notmatch 'ks-grid-card|ks-recent-card') }
    return (@($bad).Count -eq 0) -and ($b -notmatch 'ks-deal')
}
function Test-Buster([string]$m) { return $m.Contains('ThemeManager.Asset("css/theme-overrides.css") & "?v=20261115-home-cards1a"') }

Assert-Source (Test-TileRule $css) 'CSS_TILE_SQUARE_ONE_FRAME_NO_FIXED_HEIGHT'
Assert-Source (Test-ActionTiers $css) 'CSS_ACTION_TIERS_FROM_GEOMETRY_204_156'
Assert-Source (Test-TagAndText $css) 'CSS_TAG_TITLE_CATEGORY_CONTRAST_AA'
Assert-Source (Test-RecentRules $css) 'CSS_RECENT_CARDS_SAME_TILE'
Assert-Source (Test-KeyboardRules $css) 'CSS_KEYBOARD_REVEAL_AND_FOCUS_RING'
Assert-Source (Test-PriceRule $css) 'CSS_PRICE_22_26_700_NOWRAP'
Assert-Source (Test-NoLeakToDeals $css) 'CSS_BLOCK_NEVER_TOUCHES_DEAL_CARD'
Assert-Source (Test-Buster $master) 'MASTER_CACHE_BUSTER_BUMPED'
Assert-Source ((Contrast '#666666' '#ffffff') -ge 4.5 -and (Contrast '#73787d' '#ffffff') -lt 4.5) 'CONTRAST_HELPER_KNOWS_THE_OLD_GREY_FAILS'

# mutazioni sul foglio di stile e sulla pagina
$m = Mutate-Text $css 'aspect-ratio: 1 / 1;
  height: auto;
  min-height: 0;
  padding: 0;
  border: 0;
  background: #fff;
  container: ks-tile / inline-size;' 'height: auto;
  min-height: 0;
  padding: 0;
  border: 0;
  background: #fff;
  container: ks-tile / inline-size;' 'C01'
Assert-Detected (Test-TileRule $m) 'C01_TILE_NOT_SQUARE'
$m = Mutate-Text $css '  padding: 0;
  border: 0;
  background: #fff;
  container: ks-tile / inline-size;' '  padding: 0;
  border: 1px solid #edf0f3;
  background: #fff;
  container: ks-tile / inline-size;' 'C02'
Assert-Detected (Test-TileRule $m) 'C02_SECOND_FRAME_BACK'
$m = Mutate-Text $css '  min-height: 0;
  padding: 0;
  border: 0;' '  min-height: 160px;
  padding: 0;
  border: 0;' 'C03'
Assert-Detected (Test-TileRule $m) 'C03_FIXED_MIN_HEIGHT_BACK'
$m = Mutate-Text $css '  height: 100%;
  padding: 0;
  object-fit: contain;
}

/* Azioni sempre' '  height: 100%;
  padding: 10px;
  object-fit: contain;
}

/* Azioni sempre' 'C04'
Assert-Detected (Test-TileRule $m) 'C04_IMAGE_PADDING_BACK'
$m = Mutate-Text $css '@container ks-tile (max-width: 203.98px)' '@container ks-tile (max-width: 183.98px)' 'C05'
Assert-Detected (Test-ActionTiers $m) 'C05_FOUR_ACTIONS_THRESHOLD_TOO_LOW'
$m = Mutate-Text $css '@container ks-tile (max-width: 155.98px)' '@container ks-tile (max-width: 135.98px)' 'C06'
Assert-Detected (Test-ActionTiers $m) 'C06_THREE_ACTIONS_THRESHOLD_TOO_LOW'
$m = Mutate-Text $css 'li:has(> .js-ks-compare) { display: none; }' 'li:has(> .js-ks-compare) { display: flex; }' 'C07'
Assert-Detected (Test-ActionTiers $m) 'C07_COMPARE_NOT_HIDDEN_WHEN_NARROW'
$m = Mutate-Text $css 'li:has(> .js-ks-quickview) { display: none; }' 'li:has(> .js-ks-quickview) { display: flex; }' 'C08'
Assert-Detected (Test-ActionTiers $m) 'C08_QUICKVIEW_NOT_HIDDEN_WHEN_NARROW'
$m = Mutate-Text $css '    width: 44px;
    height: 44px;
  }
}' '    width: 36px;
    height: 36px;
  }
}' 'C09'
Assert-Detected (Test-ActionTiers $m) 'C09_TOUCH_TARGET_SHRINKS'
$m = Mutate-Text $css 'ks-card-category,
body.ks-page-home #HomeRecentlyViewedSection .ks-recent-card .ks-card-category { color: #666; }' 'ks-card-category,
body.ks-page-home #HomeRecentlyViewedSection .ks-recent-card .ks-card-category { color: #73787d; }' 'C10'
Assert-Detected (Test-TagAndText $m) 'C10_CATEGORY_GREY_BELOW_AA'
$m = Mutate-Text $css '  font-weight: 600;
  text-transform: none;
}' '  font-weight: 600;
  text-transform: uppercase;
}' 'C11'
Assert-Detected (Test-TagAndText $m) 'C11_FORCED_UPPERCASE_BACK'
$m = Mutate-Text $css '  background: #f1f3f5;
  color: #303842;' '  background: #f1f3f5;
  color: #aab2bd;' 'C12'
Assert-Detected (Test-TagAndText $m) 'C12_TAG_CONTRAST_BELOW_AA'
$m = Mutate-Text $css 'body.ks-page-home #ksHomePage .ks-grid-card:has(:focus-visible) .list-product-btn > li {' 'body.ks-page-home #ksHomePage .ks-grid-card:hover .list-product-btn > li {' 'C13'
Assert-Detected (Test-KeyboardRules $m) 'C13_ACTIONS_REVEALED_ONLY_BY_MOUSE'
$m = Mutate-Text $css 'body.ks-page-home #ksHomePage .ks-grid-card:has(:focus-visible) .list-product-btn > li {' 'body.ks-page-home #ksHomePage .ks-grid-card:focus-within .list-product-btn > li {' 'C13B'
Assert-Detected (Test-KeyboardRules $m) 'C13B_MOUSE_CLICK_LEAVES_ACTIONS_OPEN'
$m = Mutate-Text $css '  outline: 2px solid var(--primary-2, #D80027);
  outline-offset: -4px;' '  outline: none;
  outline-offset: -4px;' 'C14'
Assert-Detected (Test-KeyboardRules $m) 'C14_NO_FOCUS_INDICATOR'
$m = Mutate-Text $css '  outline-offset: -4px;' '  outline-offset: 3px;' 'C15'
Assert-Detected (Test-KeyboardRules $m) 'C15_FOCUS_RING_OUTSIDE_CLIPPED_TILE'
$m = Mutate-Text $css '  font-size: 22px;
  line-height: 26px;
  font-weight: 700;
  white-space: nowrap;' '  font-size: 20px;
  line-height: 22px;
  font-weight: 500;
  white-space: nowrap;' 'C16'
Assert-Detected (Test-PriceRule $m) 'C16_PRICE_BACK_TO_20_500'
$m = Mutate-Text $css 'white-space: nowrap;
}
body.ks-page-home #ksHomePage .ks-grid-card .old-price' 'white-space: normal;
}
body.ks-page-home #ksHomePage .ks-grid-card .old-price' 'C17'
Assert-Detected (Test-PriceRule $m) 'C17_PRICE_AMOUNT_CAN_BREAK'
$m = Mutate-Text $css 'body.ks-page-home #HomeRecentlyViewedSection .ks-recent-card .card-product-wrapper {
  aspect-ratio: 1 / 1;' 'body.ks-page-home #HomeRecentlyViewedSection .ks-recent-card .card-product-wrapper {
  aspect-ratio: auto;' 'C18'
Assert-Detected (Test-RecentRules $m) 'C18_RECENT_TILE_NOT_SQUARE'
$m = Mutate-Text $css 'body.ks-page-home #ksHomePage .ks-grid-card { padding: 12px; }' 'body.ks-page-home #ksHomePage .ks-grid-card, body.ks-page-home #ksHomePage .ks-deal-card { padding: 12px; }' 'C19'
Assert-Detected (Test-NoLeakToDeals $m) 'C19_DEAL_CARD_RESTYLED_BY_MISTAKE'
$m = Mutate-Text $master 'v=20261115-home-cards1a' 'v=20261114-deadcode-c1a' 'C20'
Assert-Detected (Test-Buster $m) 'C20_STALE_CSS_CACHE_BUSTER'

Write-Output 'HOME_CARDS_PARITY_ALL_PASS'
