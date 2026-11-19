[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants)

# PDP-BUNDLE-PRICE-GAP-1A. Richiesta del PO del 2026-11-19: in "Spesso acquistati insieme" il prezzo e il prezzo precedente erano
# attaccati ("19,9929,00"). Regole provate:
#  - nel markup dei prezzi delle schede della scheda prodotto c'e uno spazio fra i due importi (testo corretto anche senza stile,
#    per la sintesi vocale e per la copia);
#  - nella sezione i due importi stanno sulla stessa riga con 12 px di distanza (come nel riquadro di acquisto), oppure il prezzo
#    precedente va a capo SOTTO il prezzo, dentro la scheda (caso provato forzando una larghezza stretta);
#  - le schede dei correlati tengono la loro distanza.
# (A) sorgenti, (B) mutazioni, (C) sito LAB reale (https, 127.0.0.1, porta 18843) a 390 e 1280 px. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$files = @{
    vb = [IO.File]::ReadAllText((Join-Path $root 'articolo.aspx.vb'), $utf8)
    css = [IO.File]::ReadAllText((Join-Path $root 'Public\assets\keepstore\css\product-ui.css'), $utf8)
    aspx = [IO.File]::ReadAllText((Join-Path $root 'articolo.aspx'), $utf8)
}
function Get-Block([string]$text, [string]$start, [string]$end) {
    $i = $text.IndexOf($start, [StringComparison]::Ordinal); if ($i -lt 0) { return '' }
    $j = $text.IndexOf($end, $i + $start.Length, [StringComparison]::Ordinal); if ($j -lt 0) { return '' }
    return $text.Substring($i, $j - $i + $end.Length)
}

function Test-Source([hashtable]$f) {
    $fail = New-Object Collections.Generic.List[string]
    $build = Get-Block $f.vb 'Private Function BuildPriceHtml(' 'End Function'
    # S01 uno spazio fra prezzo e prezzo precedente nel markup
    if (-not $build.Contains('</span> <span class=""old-price body-md-2 text-main-2 fw-normal"">')) { $fail.Add('S01 spazio fra i due importi nel markup') }
    if ($build.Contains('</span><span class=""old-price')) { $fail.Add('S01 importi attaccati nel markup') }
    # S02 il paragrafo dei prezzi della sezione e una riga flessibile con distanza; solo il paragrafo, non lo span interno
    $css = $f.css -replace "`r`n", "`n"
    $rule = [regex]::Match($css, '(?m)^\.ks-product-page \.card-usually p\.price-text \{\n([^}]*)\}')
    if (-not $rule.Success) { $fail.Add('S02 regola sul paragrafo dei prezzi della sezione') }
    else {
        $body = $rule.Groups[1].Value
        foreach ($decl in @('display: flex;', 'align-items: baseline;', 'flex-wrap: wrap;', 'gap: 4px 12px;')) { if (-not $body.Contains($decl)) { $fail.Add('S02 dichiarazione assente: ' + $decl) } }
    }
    if ($css -match '(?m)^\.ks-product-page \.card-usually \.price-text \{') { $fail.Add('S02 il selettore non deve colpire lo span interno del prezzo') }
    # S03 la sezione usa ancora il paragrafo con PrezzoHtml
    if (-not $f.aspx.Contains('<p class="price-text fw-medium"><%# Eval("PrezzoHtml") %></p>')) { $fail.Add('S03 markup della sezione invariato') }
    return $fail
}

$sourceFail = @(Test-Source $files)
foreach ($x in $sourceFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFail.Count -gt 0) { Write-Host 'PDP_BUNDLE_PRICE_GAP FAIL (sorgenti)'; if ($SkipLab) { exit 1 } } else { Write-Host 'PDP_BUNDLE_PRICE_GAP sorgenti OK' }

if (-not $SkipMutants -and $sourceFail.Count -eq 0) {
    $mutants = @(
        @{ Id = 'M01_SPACE_REMOVED'; F = 'vb'; Old = '</span> <span class=""old-price body-md-2 text-main-2 fw-normal"">'; New = '</span><span class=""old-price body-md-2 text-main-2 fw-normal"">' },
        @{ Id = 'M02_RULE_REMOVED'; F = 'css'; Old = '.ks-product-page .card-usually p.price-text {'; New = '.ks-product-page .card-usually p.price-text-off {' },
        @{ Id = 'M03_SELECTOR_HITS_SPAN'; F = 'css'; Old = '.ks-product-page .card-usually p.price-text {'; New = '.ks-product-page .card-usually .price-text {' },
        @{ Id = 'M04_NO_GAP'; F = 'css'; Old = '  gap: 4px 12px;' + "`r`n" + '}' + "`r`n`r`n" + '.ks-product-page .tab-usually > .icon {'; New = '  gap: 0;' + "`r`n" + '}' + "`r`n`r`n" + '.ks-product-page .tab-usually > .icon {' },
        @{ Id = 'M05_NO_WRAP'; F = 'css'; Old = '  flex-wrap: wrap;' + "`r`n" + '  gap: 4px 12px;' + "`r`n" + '}' + "`r`n`r`n" + '.ks-product-page .tab-usually > .icon {'; New = '  gap: 4px 12px;' + "`r`n" + '}' + "`r`n`r`n" + '.ks-product-page .tab-usually > .icon {' }
    )
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        if (([regex]::Matches($files[$mu.F], [regex]::Escape($mu.Old))).Count -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
        $m = @{ vb = $files.vb; css = $files.css; aspx = $files.aspx }
        $m[$mu.F] = $files[$mu.F].Replace($mu.Old, $mu.New)
        if (@(Test-Source $m).Count -eq 0) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('PDP_BUNDLE_PRICE_GAP FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('PDP_BUNDLE_PRICE_GAP mutanti rilevati: ' + $mutants.Count)
}

if (-not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    $measure = "(function(){function rows(sel,wrap){var o=[];var ps=document.querySelectorAll(sel);for(var i=0;i<ps.length;i++){var p=ps[i],n=p.querySelector('.new-price'),d=p.querySelector('.old-price');if(!n){continue;}var c=p.closest('.card-usually, .card-product');var rc=c?c.getBoundingClientRect():p.getBoundingClientRect();" +
        "var rn=n.getBoundingClientRect();if(rn.width<=0){continue;}var sp=getComputedStyle(p);var row={two:!!d,text:p.textContent.replace(/\s+/g,' ').trim(),display:sp.display,colGap:sp.columnGap};if(d){var rd=d.getBoundingClientRect();row.visible=(rd.width>0&&rd.height>0&&getComputedStyle(d).visibility!=='hidden');row.sameLine=(rd.top<rn.bottom-2&&rd.bottom>rn.top+2);row.below=(rd.top>=rn.bottom-2);row.gap=Math.round(rd.left-rn.right);row.inside=(rd.right<=rc.right+1&&rd.left>=rc.left-1&&rn.left>=rc.left-1&&rn.right<=rc.right+1&&rd.bottom<=rc.bottom+1&&rn.top>=rc.top-1);" +
        "if(wrap){var old=p.style.width;p.style.width='86px';var a=n.getBoundingClientRect(),b=d.getBoundingClientRect();row.wrapBelow=(b.top>=a.bottom-2);row.wrapInside=(b.left>=rc.left-1&&b.bottom<=rc.bottom+40);p.style.width=old;}}o.push(row);}return o;}" +
        "return JSON.stringify({bundle:rows('#prd-usually .card-usually p.price-text',true),related:rows('.ks-product-list-section .card-product .price-wrap',false),section:!!document.querySelector('#prd-usually')});})()"
    $fail = New-Object Collections.Generic.List[string]
    foreach ($vp in @(@{ W = 390; H = 844; M = $true }, @{ W = 1280; H = 900; M = $false })) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            Open-KsUrl $b 'https://www.taikun.it:18843/articolo.aspx?id=20033' 240
            Start-Sleep -Milliseconds 2000
            $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
            $tag = 'C' + $vp.W
            if (-not $r.section) { $fail.Add($tag + ' sezione assente nella pagina di prova'); continue }
            $two = @($r.bundle | Where-Object { $_.two })
            if ($two.Count -lt 1) { $fail.Add($tag + ' nessuna scheda della sezione con due prezzi (dati di prova cambiati)') }
            foreach ($x in $two) {
                if ($x.text -notmatch '^\S+ \S+$') { $fail.Add($tag + ' testo dei prezzi senza spazio: ' + $x.text) }
                if ($x.display -ne 'flex' -or $x.colGap -ne '12px') { $fail.Add($tag + ' stile calcolato del paragrafo dei prezzi: ' + $x.display + ' / ' + $x.colGap) }
                if (-not $x.visible) { $fail.Add($tag + ' prezzo precedente non visibile') }
                if (-not $x.inside) { $fail.Add($tag + ' prezzi fuori dalla scheda') }
                if ($x.sameLine) { if ($x.gap -lt 10 -or $x.gap -gt 14) { $fail.Add($tag + ' distanza fra i due prezzi: ' + $x.gap + ' px') } }
                elseif (-not $x.below) { $fail.Add($tag + ' prezzo precedente ne affiancato ne sotto il prezzo') }
                if (-not $x.wrapBelow -or -not $x.wrapInside) { $fail.Add($tag + ' in uno spazio stretto il prezzo precedente non va a capo sotto il prezzo') }
            }
            $rel = @($r.related | Where-Object { $_.two -and $_.sameLine })
            if ($rel.Count -lt 1) { $fail.Add($tag + ' nessuna coppia di prezzi fra i correlati (dati di prova cambiati): confronto non eseguito') }
            foreach ($x in $rel) { if ($x.gap -lt 8 -or $x.gap -gt 14) { $fail.Add($tag + ' correlati, distanza fra i due prezzi: ' + $x.gap + ' px') } }
            Write-Host ('  ' + $tag + ': sezione, schede con due prezzi ' + $two.Count + ' (distanze ' + ((@($two | ForEach-Object { $_.gap })) -join ',') + '); correlati con due prezzi ' + $rel.Count)
        } catch { $fail.Add('C' + $vp.W + ' ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($fail.Count -gt 0) { foreach ($x in ($fail | Select-Object -Unique)) { Write-Host ('  FAIL ' + $x) }; Write-Host 'PDP_BUNDLE_PRICE_GAP FAIL (sito LAB)'; exit 1 }
    Write-Host 'PDP_BUNDLE_PRICE_GAP sito LAB OK'
}
if ($sourceFail.Count -gt 0) { exit 1 }
Write-Host 'PDP_BUNDLE_PRICE_GAP OK'
exit 0
