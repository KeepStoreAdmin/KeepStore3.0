[CmdletBinding()]
param()

# PDP-SECTIONS-RESTYLE-1A. Scheda prodotto: sezioni sempre visibili con indice al posto delle schede, "Informazioni prodotto" a gruppi
# con i prezzi vicini e la promozione, nota e peso della spedizione spostati li, validita della promozione con giorno e mese giusti.
# Tre parti: (A) contratto dei sorgenti, (B) comportamento del modulo puro che compone la riga "Promozione" (compilato), (C) mutazioni.
# La geometria (salto dall'indice in giu e in su, 360/390/1366) e stata provata nel browser reale sul sito locale: non e automatizzata qui.
# Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    aspx     = Read-Repo 'articolo.aspx'
    vb       = Read-Repo 'articolo.aspx.vb'
    helper   = Read-Repo 'App_Code/ProductPromotionDisplayHelper.vb'
    resolver = Read-Repo 'App_Code/ProductPromotionEligibilityResolver.vb'
    info     = Read-Repo 'App_Code/KeepStorePdpInfo.vb'
    css      = Read-Repo 'Public/assets/keepstore/css/product-ui.css'
    js       = Read-Repo 'Public/assets/keepstore/js/ks-pdp-sections.js'
}

function Get-Between([string]$text, [string]$from, [string]$to) {
    $i = $text.IndexOf($from); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($to, $i + $from.Length); if ($j -lt 0) { return $text.Substring($i) }
    return $text.Substring($i, $j - $i)
}

function Test-Source([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]
    $a = $f.aspx

    # A1 niente schede ne residui del tema che nascondono i pannelli
    foreach ($bad in 'data-bs-toggle="tab"', 'tab-pane', 'flat-animate-tab', 'tab-content', 'menu-tab-line', 'role="tabpanel"') { if ($a.Contains($bad)) { $fail.Add('A1 residuo delle schede: ' + $bad) } }
    # A2 sezioni con gli ID di prima, nell'ordine deciso
    $order = @('id="prd-usually"', 'id="prd-des"', 'id="prd-infor"', 'id="prd-review"', 'id="prd-similar"', 'id="prd-related"', 'id="prd-recent"')
    $last = -1
    foreach ($o in $order) { $i = $a.IndexOf($o); if ($i -lt 0) { $fail.Add('A2 manca ' + $o) } elseif ($i -lt $last) { $fail.Add('A2 ordine: ' + $o) } else { $last = $i } }
    if (([regex]::Matches($a, '<section class="ks-pdp-section" id="prd-(usually|des|infor|review)" aria-labelledby="[A-Za-z]+" tabindex="-1">')).Count -ne 4) { $fail.Add('A2 quattro sezioni principali') }
    # A3 indice: ancore normali, voci condizionali legate allo stesso flag della sezione
    $toc = Get-Between $a '<nav class="ks-pdp-toc"' '</nav>'
    if ($toc -eq '') { $fail.Add('A3 indice assente') }
    if ($toc -notmatch 'aria-label="Sezioni della scheda"') { $fail.Add('A3 indice senza nome') }
    foreach ($h in '#prd-infor', '#prd-review') { if ($toc -notmatch ('<li><a class="ks-pdp-toc__link" href="' + $h + '">')) { $fail.Add('A3 voce fissa ' + $h) } }
    foreach ($pair in @(@('phBundleSection', '#prd-usually'), @('phDescSection', '#prd-des'), @('phSimilar', '#prd-similar'), @('phRelated', '#prd-related'))) {
        if ($toc -notmatch ('<% If ' + $pair[0] + '\.Visible Then %><li><a class="ks-pdp-toc__link" href="' + $pair[1] + '">[^<]+</a></li><% End If %>')) { $fail.Add('A3 voce condizionale ' + $pair[1]) }
    }
    if ($a -notmatch '<asp:PlaceHolder ID="phBundleSection" runat="server" Visible="false">\s*<section class="ks-pdp-section" id="prd-usually"') { $fail.Add('A3 sezione abbinamenti non condizionale') }
    if ($f.vb -notmatch 'phBundleSection\.Visible = \(bundleItems\.Count > 1\)') { $fail.Add('A3 flag abbinamenti') }
    if ($f.vb -notmatch 'phDescSection\.Visible = Not String\.IsNullOrWhiteSpace\(litLongDesc\.Text\)') { $fail.Add('A3 flag descrizione') }
    # A4 titoli: un h1 (nome), h2 con classe per le sezioni, h3 nel modulo recensione
    if (([regex]::Matches($a, '<h1[\s>]')).Count -ne 1 -or $a -notmatch '<h1 class="product-info-name fw-semibold">') { $fail.Add('A4 un solo h1 sul nome del prodotto') }
    if (([regex]::Matches($a, '<h2 class="ks-pdp-section__title"')).Count -ne 7) { $fail.Add('A4 sette h2 di sezione') }
    if ($a -match '<h2(?! class="ks-pdp-section__title")') { $fail.Add('A4 h2 senza classe di dimensione') }
    if ($a -notmatch '<h3 class="ks-pdp-review-form-title mb-2">Lascia una recensione</h3>') { $fail.Add('A4 titolo del modulo recensione') }
    # A5 Informazioni prodotto: gruppi e campi nell'ordine deciso, prezzi vicini, promozione nel gruppo prezzi
    $infoBlock = Get-Between $a 'id="prd-infor"' 'id="prd-review"'
    $seq = @('data-ks-info-group="identita"', 'ID="litMarcaInfo"', 'ID="litCategoryInfo"', 'ID="litCodice4"', 'ID="litEan4"',
        'data-ks-info-group="prezzi"', 'ID="litPriceInfo"', 'ID="litOfficialListPrice"', 'ID="litIvaInfo"', 'ID="litPromotionInfo"',
        'data-ks-info-group="spedizione"', 'ID="litAvailabilityInfo"', 'ID="litShippingWeight"', 'data-ks-shipping-note',
        'data-ks-info-group="garanzia"', 'ID="litWarrantySummary"', 'data-ks-info-group="altro"', 'ID="litVisitsInfo"')
    $last = -1
    foreach ($s in $seq) { $i = $infoBlock.IndexOf($s); if ($i -lt 0) { $fail.Add('A5 manca ' + $s) } elseif ($i -lt $last) { $fail.Add('A5 ordine: ' + $s) } else { $last = $i } }
    if ($infoBlock -notmatch '<asp:Literal ID="litPromotionInfo" runat="server" EnableViewState="false" />') { $fail.Add('A5 la riga promozione non deve essere ricodificata (niente Mode=Encode)') }
    # A6 nota e peso della spedizione: una volta sola, nel gruppo spedizione, non nel riquadro d'acquisto
    $buy = Get-Between $a 'ks-pdp-buybox-sticky' 'data-ks-pdp-sections'
    if ($buy -match 'costo definitivo|litShippingWeight|phShippingWeight') { $fail.Add('A6 nota o peso ancora nel riquadro d''acquisto') }
    if (([regex]::Matches($a, 'Le opzioni e il costo definitivo vengono mostrati nel carrello\.')).Count -ne 1) { $fail.Add('A6 nota spedizione non unica') }
    if (([regex]::Matches($a, 'ID="litShippingWeight"')).Count -ne 1) { $fail.Add('A6 peso non unico') }
    if ($f.vb -match '"Peso articolo: "') { $fail.Add('A6 etichetta del peso ripetuta nel valore') }
    # A7 nessun markup statico delle offerte nella pagina (un prodotto senza promozione non deve contenere ks-product-promos)
    if ($a -match 'ks-product-promos') { $fail.Add('A7 classe delle offerte scritta nella pagina') }
    if (($f.info + $f.js) -match 'ks-product-promos') { $fail.Add('A7 classe delle offerte nei file nuovi') }
    # A8 riga promozione: prodotta insieme al riquadro, stessa scelta netto/lordo, una riga per offerta
    if ($f.helper -notmatch 'model\.Html = RenderHtml\(model, useNetPrices\)\s*model\.InfoHtml = RenderInfoHtml\(model, useNetPrices\)') { $fail.Add('A8 InfoHtml non prodotto accanto a Html') }
    $ri = Get-Between $f.helper 'Private Function RenderInfoHtml' 'End Function'
    if ($ri -notmatch 'model\.ResolutionState <> ProductPromotionDisplayResolutionState\.ResolvedWithOffers') { $fail.Add('A8 stato di risoluzione non controllato') }
    if ($ri -notmatch 'For Each offer As ProductPromotionOffer In model\.Offers') { $fail.Add('A8 non una riga per offerta') }
    if ($ri -notmatch 'DisplayPrice\(offer\.PriceNet, offer\.PriceGross, useNetPrices\)') { $fail.Add('A8 prezzo non scelto col flag del riquadro') }
    if ($ri -notmatch 'offer\.Label,\s*KeepStorePdpInfo\.DiscountText\(offer\.DiscountPercent\),\s*FormatMoney\(offerPrice\),\s*FormatOfferValidity\(offer\.StartsOn, offer\.EndsOn\)') { $fail.Add('A8 dati non presi dalla stessa offerta') }
    if ($ri -match 'UseNetPriceDisplay\(\)|model\.Best(OfferLabel|DiscountPercent)') { $fail.Add('A8 dati presi dal modello invece che dall''offerta') }
    if ($f.vb -notmatch 'litPromotionInfo\.Text = If\(promotionModel IsNot Nothing AndAlso promotionModel\.HasOffers, If\(promotionModel\.InfoHtml, String\.Empty\), String\.Empty\)') { $fail.Add('A8 la pagina non legge InfoHtml dallo stesso modello') }
    # A9 validita della promozione: la data del connettore non si rilegge come testo
    $rd = Get-Between $f.resolver 'Private Function ReadDate' 'End Function'
    if ($rd -notmatch 'KeepStoreDates\.TryToDate\(value, parsed\)') { $fail.Add('A9 ReadDate senza KeepStoreDates') }
    if ($rd -match 'Date\.TryParse\(Convert\.ToString\(value\)') { $fail.Add('A9 ReadDate rilegge il testo') }
    # A10 dopo un errore di recensione la pagina resta sul messaggio
    if ((Get-Between $f.vb 'Protected Sub btnReviewSubmit_Click' 'End Sub') -notmatch 'Me\.MaintainScrollPositionOnPostBack = True') { $fail.Add('A10 posizione non mantenuta dopo errore di recensione') }
    # A11 stile e script: indice fisso sotto l'intestazione, scarto del salto, bersagli, misura dei titoli, sigle di versione
    $tocRule = [regex]::Match($f.css, '(?s)\.ks-pdp-toc \{([^}]*)\}')
    if (-not $tocRule.Success -or $tocRule.Groups[1].Value -notmatch 'position: sticky' -or $tocRule.Groups[1].Value -notmatch 'top: var\(--ks-pdp-header-offset, 0px\)') { $fail.Add('A11 indice non fisso sotto l''intestazione') }
    if ($f.css -notmatch '(?s)\.ks-pdp-section,\s*\.ks-product-list-section\[id\^="prd-"\] \{\s*scroll-margin-top: calc\(var\(--ks-pdp-toc-height, 52px\) \+ 12px\)') { $fail.Add('A11 scroll-margin-top') }
    $linkRule = [regex]::Match($f.css, '(?s)\.ks-pdp-toc__link \{([^}]*)\}')
    $mh = [regex]::Match($linkRule.Groups[1].Value, 'min-height: (\d+)px')
    if (-not $mh.Success -or [int]$mh.Groups[1].Value -lt 44) { $fail.Add('A11 voce dell''indice sotto i 44 px') }
    if ($f.css -notmatch '(?s)\.ks-pdp-section__title \{[^}]*font-size: 24px') { $fail.Add('A11 misura degli h2') }
    if ($f.css -notmatch '(?s)\.ks-product-page h1\.product-info-name \{[^}]*font-size: 22px;[^}]*line-height: 1\.25;') { $fail.Add('A11 misura dell''h1') }
    if ($f.js -notmatch "goingUp \? headerHeight\(\) : 0") { $fail.Add('A11 scarto del salto senza direzione') }
    if ($f.js -notmatch "setProperty\('--ks-pdp-header-offset', headerBottom\(\) \+ 'px'\)") { $fail.Add('A11 posizione dell''intestazione non pubblicata') }
    if ($f.js -notmatch "behavior: 'instant'") { $fail.Add('A11 salto non immediato') }
    if ($a -notmatch 'css/product-ui\.css"\) %>\?v=20261118-pdp-print-a4"') { $fail.Add('A11 sigla del foglio di stile') }
    if ($a -notmatch 'js/ks-pdp-sections\.js"\) %>\?v=20261118-pdp-sections1a"') { $fail.Add('A11 script non caricato') }
    if ((Get-Between $f.css 'PDP-SECTIONS-RESTYLE-1A' "`0") -match 'border-radius:\s*[1-9]') { $fail.Add('A11 angoli arrotondati nel blocco nuovo') }

    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

# ---- (B) comportamento del modulo puro -------------------------------------------------------------------------------------------
$probe = @'
Imports System
Imports System.Collections.Generic
Public Module PdpInfoProbe
    Public Function Run() As String
        Dim r As New List(Of String)()
        Dim applied As String = KeepStorePdpInfo.PromoRowHtml(True, True, "QUANTITA 1 PZ.", KeepStorePdpInfo.DiscountText(6D), "13,11", "dal 09/11/2026 al 06/12/2026")
        r.Add("B01=" & (applied.StartsWith("<li class=""ks-pdp-info-promo""><p class=""name-feature"">Promozione</p>") AndAlso applied.EndsWith("</p></li>")).ToString())
        r.Add("B02=" & (applied.Contains(">Promo immediata</strong>") AndAlso applied.Contains("__discount"">-6%</span>") AndAlso applied.Contains("__label"">QUANTITA 1 PZ.</span>")).ToString())
        r.Add("B03=" & (applied.Contains("__applied"">") AndAlso Not applied.Contains("13,11")).ToString())
        r.Add("B04=" & applied.Contains("dal 09/11/2026 al 06/12/2026</span>").ToString())
        Dim tier As String = KeepStorePdpInfo.PromoRowHtml(False, False, "DA 3 PZ.", KeepStorePdpInfo.DiscountText(12.5D), "9,90", "")
        r.Add("B05=" & (tier.Contains("__price"">da <strong>9,90</strong>") AndAlso tier.Contains("-12.5%") AndAlso Not tier.Contains("__dates") AndAlso Not tier.Contains("__applied")).ToString())
        Dim immediateNotPrimary As String = KeepStorePdpInfo.PromoRowHtml(True, False, "X", "", "8,00", "")
        r.Add("B06=" & (immediateNotPrimary.Contains("__price"">a <strong>8,00</strong>") AndAlso Not immediateNotPrimary.Contains("__discount")).ToString())
        Dim hostile As String = KeepStorePdpInfo.PromoRowHtml(False, False, "<script>alert(1)</script>""x", "<b>", "<i>1</i>", "<u>")
        r.Add("B07=" & (Not hostile.Contains("<script") AndAlso Not hostile.Contains("<b>") AndAlso Not hostile.Contains("<i>") AndAlso Not hostile.Contains("<u>") AndAlso hostile.Contains("&lt;script&gt;")).ToString())
        r.Add("B08=" & (KeepStorePdpInfo.DiscountText(0D) = "" AndAlso KeepStorePdpInfo.DiscountText(-3D) = "" AndAlso KeepStorePdpInfo.DiscountText(38D) = "-38%").ToString())
        Dim empty As String = KeepStorePdpInfo.PromoRowHtml(False, False, Nothing, Nothing, Nothing, Nothing)
        r.Add("B09=" & (empty.Contains("</strong></p></li>") AndAlso Not empty.Contains("__label")).ToString())
        r.Add("B10=" & (Not applied.Contains("ks-product-promos")).ToString())
        Return String.Join(";", r.ToArray())
    End Function
End Module
'@

function Test-Behaviour([string]$moduleText, [switch]$Quiet) {
    $p = New-Object CodeDom.Compiler.CompilerParameters
    $p.GenerateInMemory = $true
    [void]$p.ReferencedAssemblies.Add('System.dll')
    $c = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($p, [string[]]@($moduleText, $probe))
    if ($c.Errors.HasErrors) { if (-not $Quiet) { foreach ($e in $c.Errors) { Write-Host ('  COMPILE ' + $e.ErrorText) } }; return $false }
    $out = [string]$c.CompiledAssembly.GetType('PdpInfoProbe').GetMethod('Run').Invoke($null, @())
    $ok = $true
    foreach ($kv in $out.Split(';')) { if (-not $kv.EndsWith('=True')) { $ok = $false; if (-not $Quiet) { Write-Host ('  FAIL ' + $kv) } } }
    return $ok
}

$okSource = Test-Source $files
$okBehaviour = Test-Behaviour $files.info
if (-not ($okSource -and $okBehaviour)) { Write-Host 'PDP_SECTIONS FAIL'; exit 1 }

# ---- (C) mutazioni -----------------------------------------------------------------------------------------------------------------
$mutants = @(
    @{ Id = 'M01_TABS_BACK'; File = 'aspx'; Old = '<section class="ks-pdp-section" id="prd-des" aria-labelledby="prdDesTitle" tabindex="-1">'; New = '<section class="ks-pdp-section tab-pane" id="prd-des" aria-labelledby="prdDesTitle" tabindex="-1">' },
    @{ Id = 'M02_ID_CHANGED'; File = 'aspx'; Old = 'id="prd-review" aria-labelledby'; New = 'id="prd-reviews" aria-labelledby' },
    @{ Id = 'M03_BUNDLE_ALWAYS_IN_TOC'; File = 'aspx'; Old = '<% If phBundleSection.Visible Then %><li>'; New = '<li>' },
    @{ Id = 'M04_BUNDLE_FLAG'; File = 'vb'; Old = 'phBundleSection.Visible = (bundleItems.Count > 1)'; New = 'phBundleSection.Visible = True' },
    @{ Id = 'M05_PRICES_APART'; File = 'aspx'; Old = '<p class="name-feature">Prezzo di listino</p>'; New = '<p class="name-feature">Prezzo ufficiale</p><asp:Literal ID="litIvaInfo" runat="server" />' },
    @{ Id = 'M06_NOTE_IN_BUYBOX'; File = 'aspx'; Old = '<p class="body-md-2 fw-semibold">Spedizione</p>'; New = '<p class="body-md-2 fw-semibold">Spedizione</p><p>Il costo definitivo e nel carrello.</p>' },
    @{ Id = 'M07_PROMO_DOUBLE_ENCODED'; File = 'aspx'; Old = '<asp:Literal ID="litPromotionInfo" runat="server" EnableViewState="false" />'; New = '<asp:Literal ID="litPromotionInfo" runat="server" Mode="Encode" />' },
    @{ Id = 'M08_STATIC_PROMO_CLASS'; File = 'aspx'; Old = '<div class="ks-pdp-info-group" data-ks-info-group="prezzi">'; New = '<div class="ks-pdp-info-group ks-product-promos-info" data-ks-info-group="prezzi">' },
    @{ Id = 'M09_SESSION_FLAG'; File = 'helper'; Old = 'model.InfoHtml = RenderInfoHtml(model, useNetPrices)'; New = 'model.InfoHtml = RenderInfoHtml(model, UseNetPriceDisplay())' },
    @{ Id = 'M10_MIXED_OFFER_DATA'; File = 'helper'; Old = 'KeepStorePdpInfo.DiscountText(offer.DiscountPercent)'; New = 'KeepStorePdpInfo.DiscountText(model.BestDiscountPercent)' },
    @{ Id = 'M11_OLD_READDATE'; File = 'resolver'; Old = 'If KeepStoreDates.TryToDate(value, parsed) Then Return parsed'; New = 'If Date.TryParse(Convert.ToString(value), CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then Return parsed' },
    @{ Id = 'M12_NO_SCROLL_KEEP'; File = 'vb'; Old = 'Me.MaintainScrollPositionOnPostBack = True'; New = '' },
    @{ Id = 'M13_TOC_NOT_UNDER_HEADER'; File = 'css'; Old = 'top: var(--ks-pdp-header-offset, 0px);'; New = 'top: 0;' },
    @{ Id = 'M14_JUMP_IGNORES_DIRECTION'; File = 'js'; Old = '(goingUp ? headerHeight() : 0)'; New = '0' },
    @{ Id = 'M15_SMALL_TOC_TARGET'; File = 'css'; Old = "  min-height: 48px;`r`n  padding: 0 14px;"; New = "  min-height: 32px;`r`n  padding: 0 14px;" },
    @{ Id = 'M16_H5_NAME'; File = 'aspx'; Old = '<h1 class="product-info-name fw-semibold">'; New = '<h5 class="product-info-name fw-semibold">' },
    @{ Id = 'M17_NO_SCROLL_MARGIN'; File = 'css'; Old = 'scroll-margin-top: calc(var(--ks-pdp-toc-height, 52px) + 12px);'; New = 'scroll-margin-top: 0;' },
    @{ Id = 'M18_OLD_BUSTER'; File = 'aspx'; Old = 'css/product-ui.css") %>?v=20261118-pdp-print-a4"'; New = 'css/product-ui.css") %>?v=20261115-focus-obscured1a"' },
    @{ Id = 'M19_WEIGHT_LABEL_TWICE'; File = 'vb'; Old = 'Server.HtmlEncode(weightText & " " & shippingInfo.WeightUnit)'; New = 'Server.HtmlEncode("Peso articolo: " & weightText & " " & shippingInfo.WeightUnit)' }
)
$behaviourMutants = @(
    @{ Id = 'N01_NO_ENCODING'; Old = 'Return WebUtility.HtmlEncode(If(value, ""))'; New = 'Return If(value, "")' },
    @{ Id = 'N02_PRICE_REPEATED_WHEN_APPLIED'; Old = 'If isImmediate AndAlso isApplied Then'; New = 'If False Then' },
    @{ Id = 'N03_ZERO_DISCOUNT_SHOWN'; Old = 'If percent <= 0D Then Return ""'; New = 'If percent < -100D Then Return ""' },
    @{ Id = 'N04_KIND_SWAPPED'; Old = 'Enc(If(isImmediate, ImmediateKind, QuantityKind))'; New = 'Enc(If(isImmediate, QuantityKind, ImmediateKind))' },
    @{ Id = 'N05_DATES_ALWAYS'; Old = 'If Clean(validityText) <> "" Then'; New = 'If True Then' },
    @{ Id = 'N06_PROMO_CLASS_PREFIX'; Old = '<li class=""ks-pdp-info-promo"">'; New = '<li class=""ks-product-promos-row"">' }
)
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Source $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
foreach ($mu in $behaviourMutants) {
    if (-not $files.info.Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    if (Test-Behaviour ($files.info.Replace($mu.Old, $mu.New)) -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'PDP_SECTIONS FAIL (mutanti)'; exit 1 }
Write-Host ('PDP_SECTIONS PASS (' + ($mutants.Count + $behaviourMutants.Count) + ' mutanti)')
exit 0
