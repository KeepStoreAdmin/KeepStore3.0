[CmdletBinding()]
param([switch]$SkipLab, [switch]$SkipMutants, [string]$BaseRef = '')

# CART-BOTTOM-BLANK-LINES-1A. Richiesta del PO del 2026-11-19 ("Si, toglile"): in fondo al carrello non restano righe vuote nel markup
# (due <br /> dopo il pannello del carrello aggiungevano circa 48 px prima del piede di pagina). Solo presentazione.
# Facoltativo: -BaseRef <commit> confronta il file INTERO con quella versione meno le sole due righe (prova una tantum del task).
# (A) sorgenti: il tratto finale della pagina (dal riepilogo degli errori al pannello nascosto dei campi storici) e ESATTAMENTE quello
#     atteso, spazi a parte: nessun a capo, stessi controlli, stessi attributi, stesso ordine; gli altri 7 a capo della pagina restano;
# (B) mutazioni; (C) sito LAB reale (https, 127.0.0.1, porta 18843), a 390 e 1280 px, carrello vuoto e con un articolo (stato verificato):
#     nessun <br> figlio del contenitore e distanza fra l'ultimo blocco e il PIEDE di pagina entro il margine previsto dallo stile,
#     mai sotto 24 px (a carrello vuoto il margine viene dalla regola .ks-cart-empty-card di theme-overrides.css).
# Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$aspx = [IO.File]::ReadAllText((Join-Path $root 'carrello.aspx'), $utf8)
$theme = [IO.File]::ReadAllText((Join-Path $root 'Public\assets\keepstore\css\theme-overrides.css'), $utf8)
$emptyRule = '.ks-cart-page .ks-cart-empty-card { margin-bottom: 32px; }'

$expectedTail = '<asp:validationsummary id="ValidationSummary1" runat="server" HeaderText="Attenzione!" ShowMessageBox="True" ShowSummary="False"></asp:validationsummary> ' +
    '<!--<script type="text/javascript" language="Javascript" src="Public/script/slide.js"> </script> --> ' +
    '<!-- Controllo se esiste l''immagine --> ' +
    '<asp:Panel ID="pLegacyCheckoutBindings" runat="server" Visible="false" style="display:none;">'

function Test-Source([string]$a) {
    $fail = New-Object Collections.Generic.List[string]
    $iStart = $a.IndexOf('<asp:validationsummary id="ValidationSummary1"')
    $legacy = [regex]::Match($a, '<asp:Panel ID="pLegacyCheckoutBindings"[^>]*>')
    if ($iStart -lt 0 -or -not $legacy.Success -or $legacy.Index -lt $iStart) { $fail.Add('S01 riepilogo degli errori e pannello dei campi storici presenti e nello stesso ordine'); return $fail }
    if (([regex]::Matches($a, '<asp:validationsummary id="ValidationSummary1"')).Count -ne 1) { $fail.Add('S01 un solo riepilogo degli errori in fondo alla pagina') }
    $tail = ($a.Substring($iStart, $legacy.Index + $legacy.Length - $iStart) -replace '\s+', ' ').Trim()
    if ($tail -cne $expectedTail) { $fail.Add('S02 tratto finale della pagina diverso da quello atteso (a capo, controlli, attributi o ordine)') }
    # prima del riepilogo: il pannello del carrello si chiude e nient'altro si frappone
    $before = $a.Substring(0, $iStart)
    if (($before -replace '\s+$', '') -notmatch '</asp:Panel>$') { $fail.Add('S03 fra il pannello del carrello e il riepilogo degli errori non c''e altro') }
    $count = ([regex]::Matches($a, '(?i)<br\b')).Count
    if ($count -ne 7) { $fail.Add('S04 gli altri a capo della pagina restano 7: trovati ' + $count) }
    if (([regex]::Matches($a, '<asp:Panel ID="Panel_Unico" runat="server" CssClass="ks-checkout-panel">')).Count -ne 1) { $fail.Add('S05 pannello del carrello invariato') }
    return $fail
}

$sourceFail = @(Test-Source $aspx)
# a carrello vuoto il margine dal piede viene dallo stile, non da righe vuote
if (([regex]::Matches($theme, [regex]::Escape($emptyRule))).Count -ne 1) { $sourceFail += 'S07 margine del carrello vuoto nel foglio di stile' }
if ($BaseRef -ne '') {
    # confronto fatto da Git sui byte del file: ammesse solo le due righe tolte
    $numstat = ((& git -C $root diff --numstat $BaseRef -- carrello.aspx) -join ' ').Trim()
    $changed = @(& git -C $root diff --unified=0 $BaseRef -- carrello.aspx | Where-Object { $_ -match '^[+-]' -and $_ -notmatch '^(\+\+\+|---) ' })
    $onlyTwo = ($numstat -match '^0\s+2\s+carrello\.aspx$' -and $changed.Count -eq 2 -and $changed[0] -ceq '-<br />' -and $changed[1] -ceq '-    <br />')
    if (-not $onlyTwo) { $sourceFail += 'S06 il file differisce dalla base ' + $BaseRef + ' per piu delle due righe tolte (' + $numstat + ')' } else { Write-Host ('  ok   file intero uguale a ' + $BaseRef + ' meno le sole due righe') }
}
foreach ($x in $sourceFail) { Write-Host ('  FAIL ' + $x) }
if ($sourceFail.Count -gt 0) { Write-Host 'CART_BOTTOM_BLANK_LINES FAIL (sorgenti)'; if ($SkipLab) { exit 1 } } else { Write-Host 'CART_BOTTOM_BLANK_LINES sorgenti OK' }

if (-not $SkipMutants -and $sourceFail.Count -eq 0) {
    $legacyOpen = '<asp:Panel ID="pLegacyCheckoutBindings" runat="server" Visible="false" style="display:none;">'
    $summary = '<asp:validationsummary id="ValidationSummary1" runat="server" HeaderText="Attenzione!" ShowMessageBox="True" ShowSummary="False"></asp:validationsummary>'
    $mutants = @(
        @{ Id = 'M01_ONE_BR_BACK'; Old = $legacyOpen; New = '<br />' + "`r`n" + $legacyOpen },
        @{ Id = 'M02_BR_UPPERCASE_BACK'; Old = $legacyOpen; New = '<BR>' + "`r`n" + $legacyOpen },
        @{ Id = 'M03_NBSP_SPACER'; Old = $legacyOpen; New = '<p>&nbsp;</p>' + "`r`n" + $legacyOpen },
        @{ Id = 'M04_SUMMARY_VISIBLE'; Old = 'ShowMessageBox="True" ShowSummary="False"'; New = 'ShowMessageBox="True" ShowSummary="True"' },
        @{ Id = 'M05_SUMMARY_OTHER_GROUP'; Old = $summary; New = $summary.Replace(' runat="server"', ' runat="server" ValidationGroup="missing-group"') },
        @{ Id = 'M06_LEGACY_PANEL_VISIBLE'; Old = $legacyOpen; New = $legacyOpen.Replace('Visible="false"', 'Visible="true"') },
        @{ Id = 'M07_BR_BEFORE_SUMMARY'; Old = $summary; New = '<br />' + "`r`n" + $summary; DropOther = $true },
        @{ Id = 'M08_OTHER_BR_REMOVED'; Old = ''; New = ''; DropOther = $true }
    )
    $survived = New-Object Collections.Generic.List[string]
    foreach ($mu in $mutants) {
        $text = $aspx
        if ($mu.ContainsKey('DropOther')) {
            # toglie un altro a capo della pagina (cosi il totale resta 7 nel caso M07, scende a 6 nel caso M08)
            $m = [regex]::Match($text, '(?i)<br\b[^>]*>'); if (-not $m.Success) { $survived.Add($mu.Id + ' (nessun altro a capo)'); continue }
            $text = $text.Remove($m.Index, $m.Length)
        }
        if ($mu.Old -ne '') {
            if (([regex]::Matches($text, [regex]::Escape($mu.Old))).Count -ne 1) { $survived.Add($mu.Id + ' (ancora non unica)'); continue }
            $text = $text.Replace($mu.Old, $mu.New)
        }
        if (@(Test-Source $text).Count -eq 0) { $survived.Add($mu.Id) }
    }
    if ($survived.Count -gt 0) { Write-Host ('CART_BOTTOM_BLANK_LINES FAIL mutanti sopravvissuti: ' + ($survived -join ', ')); exit 1 }
    Write-Host ('CART_BOTTOM_BLANK_LINES mutanti rilevati: ' + $mutants.Count)
}

if (-not $SkipLab) {
    . (Join-Path $PSScriptRoot 'KeepStoreBrowserDriver.ps1')
    # distanza fra il fondo dell'ultimo blocco visibile (quello che porta il margine inferiore) e l'inizio del piede; il margine previsto dallo stile
    # e quello piu grande fra gli ultimi discendenti impilati in fondo (collasso dei margini)
    $measure = "(function(){var m=document.querySelector('.ks-account-main'),f=document.querySelector('footer.tf-footer');if(!m||!f){return JSON.stringify({ok:false});}var br=0,last=null;" +
        "for(var i=0;i<m.children.length;i++){var c=m.children[i];if(c.tagName==='BR'){br++;continue;}var s=getComputedStyle(c);if(s.display==='none'||s.position==='fixed'||s.position==='absolute'){continue;}if(c.getBoundingClientRect().height>0){last=c;}}" +
        "if(!last){return JSON.stringify({ok:false});}var allowed=0,owner=last,x=last;while(x){var cs=getComputedStyle(x);var mb=parseFloat(cs.marginBottom)||0;if(mb>allowed){allowed=mb;owner=x;}var n=null;for(var k=x.children.length-1;k>=0;k--){var d=x.children[k],ds=getComputedStyle(d);if(ds.display!=='none'&&ds.position!=='absolute'&&ds.position!=='fixed'&&d.getBoundingClientRect().height>0){n=d;break;}}x=n;}" +
        "var shell=document.querySelector('.ks-account-shell'),ss=shell?getComputedStyle(shell):null;var shellPad=ss?(parseFloat(ss.paddingBottom)||0):0;" +
        "return JSON.stringify({ok:true,br:br,gap:Math.round(f.getBoundingClientRect().top-owner.getBoundingClientRect().bottom),allowed:Math.round(allowed+shellPad),rows:document.querySelectorAll('tr.tf-cart-item[data-ks-cart-row-id]').length,empty:!!document.querySelector('.ks-cart-empty'),scroll:document.documentElement.scrollWidth-window.innerWidth});})()"
    $fail = New-Object Collections.Generic.List[string]
    foreach ($vp in @(@{ W = 390; H = 844; M = $true }, @{ W = 1280; H = 900; M = $false })) {
        $b = $null
        try {
            if ($vp.M) { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H -Mobile } else { $b = Start-KsBrowser -LoopbackHosts @('www.taikun.it') -Width $vp.W -Height $vp.H }
            $tag = 'C' + $vp.W
            foreach ($state in @('vuoto', 'con un articolo')) {
                if ($state -ne 'vuoto') { Open-KsUrl $b 'https://www.taikun.it:18843/articoli.aspx' 240; Invoke-KsClick $b 'button.js-ks-cart-link' -NoWait }
                $r = $null
                for ($try = 0; $try -lt 6; $try++) {
                    if ($state -ne 'vuoto') { Start-Sleep -Seconds 3 }
                    Open-KsUrl $b 'https://www.taikun.it:18843/carrello.aspx' 240
                    $r = (Invoke-KsJs $b $measure) | ConvertFrom-Json
                    if ($state -eq 'vuoto' -or ($r.ok -and $r.rows -ge 1)) { break }
                }
                if (-not $r.ok) { $fail.Add($tag + ' carrello ' + $state + ': contenitore o piede non trovati'); continue }
                if ($state -eq 'vuoto' -and ($r.rows -ne 0 -or -not $r.empty)) { $fail.Add($tag + ' stato vuoto non verificato (righe ' + $r.rows + ')'); continue }
                if ($state -ne 'vuoto' -and $r.rows -lt 1) { $fail.Add($tag + ' stato con un articolo non verificato: aggiunta al carrello non riuscita'); continue }
                if ($r.br -ne 0) { $fail.Add($tag + ' carrello ' + $state + ': righe vuote in fondo: ' + $r.br) }
                if ($r.gap -lt 24) { $fail.Add($tag + ' carrello ' + $state + ': contenuto attaccato al piede: ' + $r.gap + ' px') }
                if ($r.gap -lt 0 -or $r.gap -gt ($r.allowed + 1)) { $fail.Add($tag + ' carrello ' + $state + ': ' + $r.gap + ' px fra l''ultimo blocco e il piede (previsti dallo stile al massimo ' + $r.allowed + ')') }
                if ($r.scroll -gt 1) { $fail.Add($tag + ' carrello ' + $state + ': scorrimento orizzontale ' + $r.scroll + ' px') }
                Write-Host ('  ' + $tag + ' carrello ' + $state + ': righe del carrello ' + $r.rows + ', righe vuote ' + $r.br + ', distanza dal piede ' + $r.gap + ' px (prevista al massimo ' + $r.allowed + ')')
            }
        } catch { $fail.Add('C' + $vp.W + ' ' + $_.Exception.Message) } finally { if ($b) { Stop-KsBrowser $b } }
    }
    if ($fail.Count -gt 0) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) }; Write-Host 'CART_BOTTOM_BLANK_LINES FAIL (sito LAB)'; exit 1 }
    Write-Host 'CART_BOTTOM_BLANK_LINES sito LAB OK'
}
if ($sourceFail.Count -gt 0) { exit 1 }
Write-Host 'CART_BOTTOM_BLANK_LINES OK'
exit 0
