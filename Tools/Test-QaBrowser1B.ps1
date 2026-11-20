[CmdletBinding()]
param()

# KS-QA-BROWSER-1B. Tre difetti del carrello visti dal PO nel browser reale (2026-11-18):
#  (1) il contatore del carrello in alto era nascosto su desktop sotto i 1400 px (classi d-none d-xxl-flex);
#  (2) nella pagina carrello la giacenza compariva due volte (un campo tecnico reso visibile dal code-behind);
#  (3) la nota "Prezzi IVA inclusa / esclusa" era scritta a 7 punti, di fatto invisibile.
# Il test controlla i sorgenti e falsifica ogni controllo con una mutazione. Solo ASCII.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

$files = @{
    header = Read-Repo 'Public/ui/controls/SiteHeader.ascx'
    aspx   = Read-Repo 'carrello.aspx'
    vb     = Read-Repo 'carrello.aspx.vb'
    css    = Read-Repo 'Public/assets/keepstore/css/cart-ui.css'
    footer = Read-Repo 'Public/ui/controls/SiteFooter.ascx'
    logout = Read-Repo 'logout.aspx'
    logoutVb = Read-Repo 'logout.aspx.vb'
    dash   = Read-Repo 'myaccount.aspx'
}

function Test-Contract([hashtable]$f, [switch]$Quiet) {
    $fail = New-Object Collections.Generic.List[string]

    # (1) contatore in alto: il segnaposto desktop non e nascosto da classi di larghezza, e resta agganciato allo script.
    $m = [regex]::Match($f.header, '<span class="([^"]*)" data-ks-cart-count><asp:Label ID="lblCarrelloCount" runat="server" Text="0" /></span>')
    if (-not $m.Success) { $fail.Add('B01 contatore desktop non trovato') }
    elseif ($m.Groups[1].Value -match '(^|\s)d-none(\s|$)') { $fail.Add('B02 contatore desktop nascosto da d-none') }
    elseif ($m.Groups[1].Value -notmatch '(^|\s)count-box(\s|$)') { $fail.Add('B03 contatore desktop senza count-box') }
    if ($f.header -notmatch '<span class="count-box style-pst-2" data-ks-cart-count><asp:Label ID="lblCarrelloCountMobile"') { $fail.Add('B04 contatore telefono cambiato') }
    $w = [regex]::Match($f.header, '<span class="([^"]*)"><asp:Label ID="lblWishlistCount"')
    if (-not $w.Success -or $w.Groups[1].Value -match '(^|\s)d-none(\s|$)') { $fail.Add('B05 contatore preferiti nascosto') }

    # (2) giacenza doppia: il campo tecnico resta invisibile, nel markup e nel code-behind.
    $labels = [regex]::Matches($f.aspx, '<asp:Label ID="lblDispo"[^\r\n]*')
    if ($labels.Count -ne 2) { $fail.Add('S01 attesi due campi tecnici lblDispo, trovati ' + $labels.Count) }
    foreach ($l in $labels) { if ($l.Value -notmatch 'Visible="False"') { $fail.Add('S02 lblDispo visibile nel markup') } }
    if ($f.vb -match '(?im)^\s*(If dispo IsNot Nothing Then\s+)?dispo\.Visible\s*=\s*True') { $fail.Add('S03 il code-behind rende visibile la giacenza tecnica') }
    if (([regex]::Matches($f.aspx, 'AvailabilityDisplayHelper\.BuildHtml\(Container\.DataItem')).Count -lt 2) { $fail.Add('S04 il riquadro disponibilita non e piu in entrambe le liste') }

    # (3) nota IVA: leggibile, vicino al conteggio degli articoli, testo senza asterisco.
    $note = [regex]::Match($f.aspx, '<asp:Label ID="lblPrezzi"[^>]*>')
    if (-not $note.Success) { $fail.Add('V01 nota IVA assente') }
    else {
        if ($note.Value -match 'Font-Size|Font-Names') { $fail.Add('V02 nota IVA con carattere fisso minuscolo') }
        if ($note.Value -notmatch 'CssClass="ks-cart-price-note"') { $fail.Add('V03 nota IVA senza classe') }
    }
    if ($f.aspx -notmatch '(?s)<div class="body-text-3 ks-cart-heading-meta">(?:(?!</div>).)*<asp:Label ID="lblPrezzi"') { $fail.Add('V04 nota IVA fuori dalla riga del conteggio') }
    if ($f.vb -notmatch 'lblPrezzi\.Text = "Prezzi IVA esclusa"') { $fail.Add('V05 testo IVA esclusa') }
    if ($f.vb -notmatch 'lblPrezzi\.Text = "Prezzi IVA inclusa"') { $fail.Add('V06 testo IVA inclusa') }
    if ($f.vb -match 'lblPrezzi\.Text = "\*') { $fail.Add('V07 asterisco nella nota IVA') }
    $rule = [regex]::Match($f.css, '(?s)\.ks-cart-page \.ks-cart-price-note\s*\{([^}]*)\}')
    if (-not $rule.Success) { $fail.Add('V08 stile della nota IVA assente') }
    else {
        $fs = [regex]::Match($rule.Groups[1].Value, 'font-size:\s*(\d+)px')
        if (-not $fs.Success -or [int]$fs.Groups[1].Value -lt 13) { $fail.Add('V09 nota IVA sotto i 13 px') }
        if ($rule.Groups[1].Value -match 'border-radius:\s*[1-9]') { $fail.Add('V10 angoli arrotondati non previsti') }
    }
    if ($f.css -notmatch '\.ks-cart-page\.ks-cart-is-empty \.ks-cart-price-note\s*\{\s*display:\s*none') { $fail.Add('V11 nota IVA visibile a carrello vuoto') }
    if ($f.aspx -match 'cart-ui\.css"\)\s*&\s*"\?v=20261117-pay-guide-2a"') { $fail.Add('V12 cache buster del CSS non aggiornato') }

    # (4) nome dell'area cliente: "La tua Dashboard" (decisione PO 2026-11-18) in intestazione, menu, pie di pagina e pannello.
    if ($f.header -notmatch '<span id="lblLogin" runat="server">La tua Dashboard</span>') { $fail.Add('D01 etichetta intestazione') }
    if ($f.header -notmatch 'class="mb-menu-link"><span>La tua Dashboard</span>') { $fail.Add('D02 etichetta menu telefono') }
    if ($f.footer -notmatch '<a class="link" href="myaccount\.aspx">La tua Dashboard</a>') { $fail.Add('D03 etichetta pie di pagina') }
    if ($f.dash -notmatch '(?s)ContentPlaceHolderID="TitleContent"[^>]*>\s*La tua Dashboard\s*</asp:Content>') { $fail.Add('D04 titolo del pannello') }
    if (($f.header + $f.footer + $f.dash) -match 'Il mio account|Area personale|area personale') { $fail.Add('D05 vecchio nome rimasto') }

    # (5) pagina di uscita: titolo vero, conferma, due azioni; la sessione si chiude al primo caricamento.
    if ($f.logout -notmatch '<h1 class="ks-logout__title">Hai effettuato l''uscita</h1>') { $fail.Add('L01 titolo uscita') }
    if ($f.logout -notmatch 'id="hlLogoutHome" href="<%= ResolveUrl\("~/Default\.aspx"\) %>" class="tf-btn"') { $fail.Add('L02 azione principale') }
    if ($f.logout -notmatch 'id="hlLogoutLogin" href="<%= ResolveUrl\("~/login\.aspx"\) %>" class="tf-btn btn-line"') { $fail.Add('L03 azione accedi di nuovo') }
    if ($f.logout -match 'border-radius:\s*[1-9]') { $fail.Add('L04 angoli arrotondati non previsti') }
    if ($f.logoutVb -notmatch '(?s)Session\.Clear\(\).*Session\.Abandon\(\)') { $fail.Add('L05 la sessione non viene chiusa') }

    if (-not $Quiet) { foreach ($x in $fail) { Write-Host ('  FAIL ' + $x) } }
    return ($fail.Count -eq 0)
}

if (-not (Test-Contract $files)) { Write-Host 'QA_BROWSER_1B FAIL'; exit 1 }

# Mutazioni: ognuna deve far fallire il contratto.
$mutants = @(
    @{ Id = 'M01_BADGE_HIDDEN'; File = 'header'; Old = 'class="count-box style-pst-2" data-ks-cart-count><asp:Label ID="lblCarrelloCount"'; New = 'class="count-box style-pst-2 d-none d-xxl-flex" data-ks-cart-count><asp:Label ID="lblCarrelloCount"' },
    @{ Id = 'M02_BADGE_UNHOOKED'; File = 'header'; Old = 'class="count-box style-pst-2" data-ks-cart-count><asp:Label ID="lblCarrelloCount"'; New = 'class="count-box style-pst-2"><asp:Label ID="lblCarrelloCount"' },
    @{ Id = 'M03_WISHLIST_HIDDEN'; File = 'header'; Old = 'class="count-box style-pst-2"><asp:Label ID="lblWishlistCount"'; New = 'class="count-box style-pst-2 d-none d-xxl-flex"><asp:Label ID="lblWishlistCount"' },
    @{ Id = 'M04_STOCK_VISIBLE_CODE'; File = 'vb'; Old = 'ElseIf DispoTipo = 2 Then' + "`r`n" + '        img.Visible = False'; New = 'ElseIf DispoTipo = 2 Then' + "`r`n" + '        img.Visible = False' + "`r`n" + '        dispo.Visible = True' },
    @{ Id = 'M05_STOCK_VISIBLE_MARKUP'; File = 'aspx'; Old = '<asp:Label ID="lblDispo" runat="server" Text=''<%#: Eval("giacenza") %>'' Visible="False">'; New = '<asp:Label ID="lblDispo" runat="server" Text=''<%#: Eval("giacenza") %>''>' },
    @{ Id = 'M06_NOTE_TINY'; File = 'aspx'; Old = '<asp:Label ID="lblPrezzi" runat="server" Text="" CssClass="ks-cart-price-note">'; New = '<asp:Label ID="lblPrezzi" runat="server" Text="" Font-Size="7pt" CssClass="ks-cart-price-note">' },
    @{ Id = 'M07_NOTE_ASTERISK'; File = 'vb'; Old = 'lblPrezzi.Text = "Prezzi IVA esclusa"'; New = 'lblPrezzi.Text = "*Prezzi Iva Esclusa"' },
    @{ Id = 'M08_NOTE_SMALL_CSS'; File = 'css'; Old = '.ks-cart-page .ks-cart-price-note{'; New = '.ks-cart-page .ks-cart-price-note-off{' },
    @{ Id = 'M10_OLD_NAME_HEADER'; File = 'header'; Old = '<span id="lblLogin" runat="server">La tua Dashboard</span>'; New = '<span id="lblLogin" runat="server">Il mio account</span>' },
    @{ Id = 'M11_OLD_NAME_FOOTER'; File = 'footer'; Old = 'href="myaccount.aspx">La tua Dashboard</a>'; New = 'href="myaccount.aspx">Il mio account</a>' },
    @{ Id = 'M12_LOGOUT_NO_TITLE'; File = 'logout'; Old = '<h1 class="ks-logout__title">'; New = '<h2 class="ks-logout__title">' },
    @{ Id = 'M13_LOGOUT_NO_ABANDON'; File = 'logoutVb'; Old = 'Session.Abandon()'; New = '' },
    @{ Id = 'M14_LOGOUT_NO_LOGIN_LINK'; File = 'logout'; Old = 'id="hlLogoutLogin"'; New = 'id="hlOther"' },    @{ Id = 'M09_OLD_BUSTER'; File = 'aspx'; Old = 'cart-ui.css") & "?v=20261120-recent-1b"'; New = 'cart-ui.css") & "?v=20261117-pay-guide-2a"' }
)
$bad = 0
foreach ($mu in $mutants) {
    $copy = @{}; foreach ($k in $files.Keys) { $copy[$k] = $files[$k] }
    if (-not $copy[$mu.File].Contains($mu.Old)) { Write-Host ('  MUTANT_NOT_APPLICABLE ' + $mu.Id); $bad++; continue }
    $copy[$mu.File] = $copy[$mu.File].Replace($mu.Old, $mu.New)
    if (Test-Contract $copy -Quiet) { Write-Host ('  MUTANT_SURVIVED ' + $mu.Id); $bad++ }
}
if ($bad -gt 0) { Write-Host 'QA_BROWSER_1B FAIL (mutanti)'; exit 1 }
Write-Host ('QA_BROWSER_1B PASS (' + $mutants.Count + ' mutanti)')
exit 0
