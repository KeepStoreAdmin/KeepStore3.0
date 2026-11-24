[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Red, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# CATALOG-DOWNLOAD-FILENAME-1A. Il file scaricato (PDF o Excel) si chiama Listino_<azienda>_<gg-mm-aaaa>.<pdf|xls>.
# Parte 1 (unitaria): l'helper App_Code\KeepStoreCatalogExportFileName.vb si compila da solo e si prova su casi estremi (vuoto, simboli, CON, percorsi, CR/LF,
#   virgolette, 200 caratteri, surrogato isolato, cirillico, cifre arabe, lettere a tutta larghezza, cultura thai); mutanti sull'helper compilato in memoria.
# Parte 2 (HTTP sul LAB, https 127.0.0.1:18843, utente di prova): per PDF ed Excel la risposta ha UN SOLO Content-Disposition uguale all'atteso, calcolato qui
#   con una funzione indipendente dal nome azienda della tabella aziende (host della richiesta) e dalla data di oggi; mutanti sulla pagina LAB.
# -Red: nessuna copia dei file del repo (mostra il test rosso prima del codice). Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'CATALOG_FILENAME FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$helperRel = 'App_Code\KeepStoreCatalogExportFileName.vb'
$files = @('listino-catalogo.aspx', 'listino-catalogo.aspx.vb', 'App_Code\KeepStoreCatalogExportSnapshot.vb', 'App_Code\KeepStoreCatalogExportImages.vb',
    'App_Code\KeepStoreCatalogPdfWriter.vb', 'App_Code\KeepStoreCatalogXlsWriter.vb', $helperRel, 'App_Code\StorefrontCanonicalHostPolicy.vb', 'App_Code\KeepStoreAccountTiles.vb')
$repoBytes = @{}; $origBytes = @{}
foreach ($f in $files) {
    $rp = Join-Path $root $f; $sp = Join-Path $SitePath $f
    $repoBytes[$f] = if (Test-Path -LiteralPath $rp) { [IO.File]::ReadAllBytes($rp) } else { $null }
    $origBytes[$f] = if (Test-Path -LiteralPath $sp) { [IO.File]::ReadAllBytes($sp) } else { $null }
}
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$tmp = Join-Path $env:TEMP ('ks-catname-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
. (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')
$jar = Join-Path $tmp 'auth.txt'

# ---------------- Parte 1: helper puro compilato da solo ----------------------------------------------------------------------------------------------------
$probeCode = @"
Option Strict On
Option Explicit On
Public Class FileNameProbe
    Public Function B(ByVal name As String, ByVal d As Date, ByVal asExcel As Boolean) As String
        Return CatalogExportFileName.Build(name, d, asExcel)
    End Function
End Class
"@
function New-Probe([string]$helperSource) {
    $cp = New-Object CodeDom.Compiler.CompilerParameters
    $cp.GenerateInMemory = $true
    $cp.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$cp.ReferencedAssemblies.Add($_) }
    $res = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($cp, [string[]]@($helperSource, $probeCode))
    if ($res.Errors.HasErrors) { throw ('HELPER_COMPILE ' + (($res.Errors | Select-Object -First 3 | ForEach-Object { $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($res.CompiledAssembly.GetType('FileNameProbe', $true))
}
$d0 = New-Object DateTime 2026, 11, 24
$emoji = [char]::ConvertFromUtf32(0x1F600)
$cases = @(
    @{ N = 'Taikun s.r.l.'; X = $false; E = 'Listino_Taikun_srl_24-11-2026.pdf' },
    @{ N = ('Caf' + [char]0xE8 + '  Rossi & Figli'); X = $true; E = 'Listino_Cafe_Rossi_Figli_24-11-2026.xls' },
    @{ N = ''; X = $false; E = 'Listino_KeepStore_24-11-2026.pdf' },
    @{ N = $null; X = $true; E = 'Listino_KeepStore_24-11-2026.xls' },
    @{ N = '!!!///'; X = $false; E = 'Listino_KeepStore_24-11-2026.pdf' },
    @{ N = 'CON'; X = $false; E = 'Listino_CON_24-11-2026.pdf' },
    @{ N = '../../etc/passwd'; X = $false; E = 'Listino_etc_passwd_24-11-2026.pdf' },
    @{ N = ('A' + [char]13 + [char]10 + 'B"C;D'); X = $false; E = 'Listino_A_B_C_D_24-11-2026.pdf' },
    @{ N = ('A' * 200); X = $false; E = ('Listino_' + ('A' * 40) + '_24-11-2026.pdf') },
    @{ N = (('A' * 118) + $emoji.Substring(0, 1)); X = $false; E = ('Listino_' + ('A' * 40) + '_24-11-2026.pdf') },
    @{ N = (('B' * 39) + ' CCCC'); X = $false; E = ('Listino_' + ('B' * 39) + '_24-11-2026.pdf') },
    @{ N = ([string][char]0x41C + [char]0x43E + [char]0x441 + [char]0x43A + [char]0x432 + [char]0x430); X = $false; E = 'Listino_KeepStore_24-11-2026.pdf' },
    @{ N = ('Gro' + [char]0xDF + 'handel'); X = $false; E = 'Listino_Gro_handel_24-11-2026.pdf' },
    @{ N = ([string][char]0x663 + [char]0x663 + [char]0x663 + 'abc'); X = $false; E = 'Listino_abc_24-11-2026.pdf' },
    @{ N = ([string][char]0xFF21 + [char]0xFF22 + [char]0xFF23); X = $false; E = 'Listino_ABC_24-11-2026.pdf' },
    @{ N = ([string][char]0xFB01 + 'ne'); X = $false; E = 'Listino_fine_24-11-2026.pdf' },
    @{ N = '-Rossi-'; X = $false; E = 'Listino_Rossi_24-11-2026.pdf' }
)
function Test-Cases($probe, [string]$tag) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($c in $cases) {
        $got = ''
        try { $got = [string]$probe.B($c.N, $d0, $c.X) } catch { $got = 'EXCEPTION ' + $_.Exception.Message }
        if ($got -cne $c.E) { $bad.Add('[' + $got + '] atteso [' + $c.E + ']') }
    }
    # cultura thai: l'anno deve restare 2026
    $old = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('th-TH')
        $got = [string]$probe.B('Taikun', $d0, $false)
        if ($got -cne 'Listino_Taikun_24-11-2026.pdf') { $bad.Add('cultura thai: [' + $got + ']') }
    } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $old }
    return $bad.ToArray()
}

    function Wait-Site {
        $ok = 0
        for ($i = 0; $i -lt 80; $i++) {
            $st = 0; try { $st = (Invoke-Http '/privacy.aspx' (Join-Path $tmp 'wait.txt')).Status } catch { $st = 0 }
            if ($st -eq 200) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
            Start-Sleep -Seconds 3
        }
        throw 'SITE_NOT_BACK'
    }
    function Set-SiteFile([string]$f, $bytes) {
        $sp = Join-Path $SitePath $f
        if ($null -eq $bytes) { if (Test-Path -LiteralPath $sp) { Remove-Item -LiteralPath $sp -Force } } else { [IO.File]::WriteAllBytes($sp, $bytes) }
    }
    function Deploy-Repo { if ($Red) { return }; foreach ($f in $files) { if ($null -ne $repoBytes[$f]) { Set-SiteFile $f $repoBytes[$f] } }; Start-Sleep -Seconds 3; Wait-Site }
    function Restore-Site { foreach ($f in $files) { Set-SiteFile $f $origBytes[$f] }; Start-Sleep -Seconds 3; Wait-Site }
    function Set-Mutant([string]$f, [string]$text) { $bom = ($repoBytes[$f].Length -ge 3 -and $repoBytes[$f][0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $f), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }
    function Get-Form([string]$jarFile, [string]$suffix) {
        $x = Invoke-Http '/listino-catalogo.aspx' $jarFile
        $fields = New-Object Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($x.Body, '<input[^>]*type="hidden"[^>]*>')) {
            $n = [regex]::Match($m.Value, 'name="([^"]*)"'); $v = [regex]::Match($m.Value, 'value="([^"]*)"')
            if ($n.Success) { $fields.Add($n.Groups[1].Value + '=' + [Uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($(if ($v.Success) { $v.Groups[1].Value } else { '' })))) }
        }
        $btn = [regex]::Match($x.Body, 'name="([^"]*' + $suffix + ')"')
        return @{ Fields = $fields; Button = $(if ($btn.Success) { $btn.Groups[1].Value } else { '' }) }
    }
    # POST con intestazioni salvate (-D): restituisce stato, tipo e le righe Content-Disposition
    function Post-Download([string]$jarFile, $form, [string]$label) {
        $parts = New-Object Collections.Generic.List[string]
        foreach ($f in $form.Fields) { $parts.Add($f) }
        $parts.Add([Uri]::EscapeDataString($form.Button) + '=' + [Uri]::EscapeDataString($label))
        $body = Join-Path $tmp ('post' + [Guid]::NewGuid().ToString('N') + '.txt'); $hdr = Join-Path $tmp ('hdr' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('out' + [Guid]::NewGuid().ToString('N') + '.bin')
        [IO.File]::WriteAllText($body, ($parts -join '&'), $utf8)
        $a = @('--noproxy', '*', '-s', '--max-time', '600', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-b', $jarFile, '-c', $jarFile, '-o', $out, '-D', $hdr, '-w', '%{http_code}|%{content_type}',
            '-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + '/listino-catalogo.aspx'), '--data', ('@' + $body), ($base + '/listino-catalogo.aspx'))
        $w = ((& curl.exe @a) -join '').Split('|')
        $disp = @(Get-Content -LiteralPath $hdr -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(?i)content-disposition:' })
        return @{ Status = [int]$w[0]; Type = $w[1]; Disp = $disp }
    }
    # funzione di prova INDIPENDENTE dall'helper (regex): stessa regola scritta a mano
    function Expected-Part([string]$name) {
        $s = $name.Normalize([Text.NormalizationForm]::FormKD)
        $s = [regex]::Replace($s, '\p{Mn}', '')
        $s = $s -replace "[.,']", ''
        $s = [regex]::Replace($s, '[^A-Za-z0-9-]+', '_')
        if ($s.Length -gt 40) { $s = $s.Substring(0, 40) }
        $s = $s.Trim('_', '-')
        if ($s -eq '') { $s = 'KeepStore' }
        return $s
    }


$exit = 0
try {
    if ($null -eq $repoBytes[$helperRel]) {
        Check $false 'unitaria: l''helper KeepStoreCatalogExportFileName.vb esiste'
    } else {
        $helperText = Get-Text $repoBytes[$helperRel]
        $probe = New-Probe $helperText
        $bad = @(Test-Cases $probe 'repo')
        foreach ($b in $bad) { Write-Host ('    ' + $b) }
        Check ($bad.Count -eq 0) ('unitaria: ' + ($cases.Count + 1) + ' casi estremi (vuoto, simboli, CON, percorsi, CR/LF, 200 caratteri, surrogato, cirillico, cifre arabe, thai)')
        # nessun carattere fuori da A-Z a-z 0-9 _ - . nel risultato, qualunque cosa entri (robustezza su 2000 stringhe casuali)
        $rnd = New-Object Random 7; $rejected = 0
        for ($i = 0; $i -lt 2000; $i++) {
            $len = $rnd.Next(0, 60); $sb = New-Object Text.StringBuilder
            for ($k = 0; $k -lt $len; $k++) { [void]$sb.Append([char]$rnd.Next(0, 0xFFFF)) }
            $r = ''; try { $r = [string]$probe.B($sb.ToString(), $d0, $false) } catch { $r = 'EXC' }
            if ($r -notmatch '^Listino_[A-Za-z0-9_-]{1,40}_24-11-2026\.pdf$') { $rejected++ }
        }
        Check ($rejected -eq 0) ('unitaria: 2000 stringhe casuali danno sempre un nome sicuro (anomalie ' + $rejected + ')')
        if (-not $SkipMutants -and -not $Red) {
            $um = [ordered]@{
                'U01_NO_CUT'        = @{ From = '''NAME_CUT'; To = ''''; Pre = 'part = part.Substring(0, MaxCompanyLength)' }
                'U02_ISLETTERORDIGIT' = @{ From = 'IsAsciiAllowed(ch)'; To = 'Char.IsLetterOrDigit(ch)' }
                'U03_FORMD'         = @{ From = 'NormalizationForm.FormKD'; To = 'NormalizationForm.FormD' }
                'U04_NO_SURROGATE'  = @{ From = 'Char.IsSurrogate(ch)'; To = 'False' }
                'U05_NO_TRIM'       = @{ From = '.Trim("_"c, "-"c)'; To = '' }
            }
            $kill = 0; $tot = 0
            foreach ($id in $um.Keys) {
                if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
                $tot++; $m = $um[$id]
                $src = $helperText
                if ($id -eq 'U01_NO_CUT') {
                    $src = ($helperText -replace "(?m)^.*'NAME_CUT.*$", '')
                } elseif ($src.Contains($m.From)) { $src = $src.Replace($m.From, $m.To) } else { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
                $dead = $false
                try { $pm = New-Probe $src; $dead = (@(Test-Cases $pm 'mut').Count -gt 0) } catch { $dead = $true }
                if ($dead) { $kill++; Write-Host ('  ok   mutante ' + $id + ' ucciso') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            }
            Write-Host ('  mutanti unitari uccisi ' + $kill + '/' + $tot)
        }
    }

    # ---------------- Parte 2: HTTP sul sito LAB -------------------------------------------------------------------------------------------------------
    $companyName = (Get-Scalar "SELECT Nome AS ksval FROM aziende WHERE URL1 = 'www.taikun.it' LIMIT 1;")
    Check ($companyName -ne '') ('fixture: nome azienda dell''host letto da SQL (' + $companyName + ')')
    $today = (Get-Date).ToString('dd-MM-yyyy', [Globalization.CultureInfo]::InvariantCulture)
    $expPdf = 'Listino_' + (Expected-Part $companyName) + '_' + $today + '.pdf'
    $expXls = 'Listino_' + (Expected-Part $companyName) + '_' + $today + '.xls'

    Deploy-Repo
    $null = Invoke-Login $jar $false
    function Check-Download([string]$suffix, [string]$label, [string]$expected, [string]$tag) {
        $f = Get-Form $jar $suffix
        if ($f.Button -eq '') { Check $false ($tag + ': pulsante presente'); return $null }
        $r = Post-Download $jar $f $label
        $okOne = ($r.Disp.Count -eq 1)
        $line = if ($r.Disp.Count -ge 1) { ([string]$r.Disp[0]).Trim() } else { '' }
        $want = 'Content-Disposition: attachment; filename="' + $expected + '"'
        $todayAfter = (Get-Date).ToString('dd-MM-yyyy', [Globalization.CultureInfo]::InvariantCulture)
        $wantAfter = 'Content-Disposition: attachment; filename="' + ($expected -replace '_[0-9]{2}-[0-9]{2}-[0-9]{4}[.]', ('_' + $todayAfter + '.')) + '"'
        Check ($okOne -and ($line -ceq $want -or $line -ceq $wantAfter)) ($tag + ': un solo Content-Disposition uguale a ' + $expected + ' (visto: ' + $line + ', righe ' + $r.Disp.Count + ')')
        return $r
    }
    $null = Check-Download 'btnPdf' 'Scarica il PDF' $expPdf 'PDF'
    $null = Check-Download 'btnXls' 'Scarica Excel' $expXls 'Excel'

    if (-not $SkipMutants -and -not $Red -and $exit -eq 0 -and $e2e.Count -eq 0) {
        $page = Get-Text $repoBytes['listino-catalogo.aspx.vb']
        $mutants = [ordered]@{
            'M01_EXT_SWAPPED'  = @{ From = 'snapshot.GeneratedOn, asExcel) ''FILE_NAME'; To = 'snapshot.GeneratedOn, Not asExcel) ''FILE_NAME' }
            'M02_DATE_SHIFTED' = @{ From = 'snapshot.GeneratedOn, asExcel) ''FILE_NAME'; To = 'snapshot.GeneratedOn.AddDays(1), asExcel) ''FILE_NAME' }
            'M03_OLD_NAME'     = @{ From = 'fileName = CatalogExportFileName.Build('; To = 'fileName = "listino-offerte-" & CatalogExportFileName.Build(' }
        }
        $killed = 0; $total = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $total++; $mu = $mutants[$id]
            if (-not $page.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            try {
                Set-Mutant 'listino-catalogo.aspx.vb' ($page.Replace($mu.From, $mu.To))
                $null = Invoke-Login $jar $false
                $f2 = Get-Form $jar 'btnPdf'; $r2 = Post-Download $jar $f2 'Scarica il PDF'
                $line2 = if ($r2.Disp.Count -ge 1) { ([string]$r2.Disp[0]).Trim() } else { '' }
                $dead = ($r2.Disp.Count -ne 1 -or $line2 -cne ('Content-Disposition: attachment; filename="' + $expPdf + '"'))
                if ($dead) { $killed++; Write-Host ('  ok   mutante ' + $id + ' ucciso (visto: ' + $line2 + ')') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
            } finally { Deploy-Repo }
        }
        Write-Host ('  mutanti HTTP uccisi ' + $killed + '/' + $total)
    }

    # pin statici
    $pageText = if ($null -ne $repoBytes['listino-catalogo.aspx.vb']) { Get-Text $repoBytes['listino-catalogo.aspx.vb'] } else { '' }
    $iName = $pageText.IndexOf('CatalogExportFileName.Build('); $iBytes = $pageText.IndexOf('bytes = If(asExcel')
    Check ($iName -ge 0 -and $iBytes -gt $iName) 'pin: il nome del file e calcolato prima dei writer (un errore dopo non lascia un file senza nome)'
    Check ($pageText.Contains('snapshot.GeneratedOn') -and -not $pageText.Contains('Date.Today.ToString("yyyyMMdd"')) 'pin: la data viene dallo snapshot, nessun nome fisso o seconda lettura dell''orologio'
    Check ($pageText.Contains('bytes = Nothing')) 'pin: un errore nel ramo di generazione azzera i byte (nessun file con stato 500)'
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    Close-LabSite
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'CATALOG_FILENAME PASS' } else { Write-Host 'CATALOG_FILENAME FAIL' }
exit $exit
