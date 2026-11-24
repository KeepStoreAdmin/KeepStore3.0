[CmdletBinding()]
param([switch]$SkipMutants)

# CATALOG-DOWNLOAD-1D. Pulizia della descrizione azienda (aziende.Descrizione) che compare nella prima pagina del listino (PDF ed Excel):
# App_Code\KeepStoreCatalogExportText.vb si compila da solo (System.Web per HttpUtility) e si prova su testi con HTML, entita doppie, spazi, controlli,
# indirizzi web, vuoto e testo lungo (anche con un surrogato al punto di taglio); mutanti sull'helper compilato in memoria. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$rel = 'App_Code\KeepStoreCatalogExportText.vb'
$path = Join-Path $root $rel
$fail = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $fail.Add($name) } }

$probeCode = @"
Option Strict On
Option Explicit On
Public Class TextProbe
    Public Function D(ByVal raw As String) As String
        Return CatalogExportText.Description(raw)
    End Function
End Class
"@
function New-Probe([string]$source) {
    $cp = New-Object CodeDom.Compiler.CompilerParameters
    $cp.GenerateInMemory = $true
    $cp.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll', 'System.Web.dll') | ForEach-Object { [void]$cp.ReferencedAssemblies.Add($_) }
    $res = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($cp, [string[]]@($source, $probeCode))
    if ($res.Errors.HasErrors) { throw ('TEXT_COMPILE ' + (($res.Errors | Select-Object -First 3 | ForEach-Object { $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($res.CompiledAssembly.GetType('TextProbe', $true))
}
$long = ('parola ' * 60).Trim()
$emoji = [char]::ConvertFromUtf32(0x1F600)
$edge = ('A' * 251) + $emoji + 'BBBB'
$cases = @(
    @{ I = "  Vendita   on-line`r`n a prezzi  "; E = 'Vendita on-line a prezzi' },
    @{ I = 'Vendita &lt;b&gt;hardware&lt;/b&gt; &amp; software'; E = 'Vendita hardware & software' },
    @{ I = '<p>Ciao</p><script>x</script>'; E = 'Ciao x' },
    @{ I = ('Distributore ' + [char]0xE8 + ' Centro TIM - Sky'); E = ('Distributore ' + [char]0xE8 + ' Centro TIM - Sky') },
    @{ I = ('A' + [char]0 + 'B' + [char]7 + 'C' + [char]0x1F + 'D'); E = 'A B C D' },
    @{ I = 'https://www.example.test/promo'; E = '' },
    @{ I = 'HTTP://example.test'; E = '' },
    @{ I = 'visita http://example.test'; E = 'visita http://example.test' },
    @{ I = ''; E = '' },
    @{ I = $null; E = '' },
    @{ I = '   '; E = '' },
    @{ I = '<br><br>'; E = '' }
)
function Test-All($probe) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($c in $cases) {
        $got = ''; try { $got = [string]$probe.D($c.I) } catch { $got = 'EXCEPTION ' + $_.Exception.Message }
        if ($got -cne $c.E) { $bad.Add('[' + $got + '] atteso [' + $c.E + ']') }
    }
    $g = [string]$probe.D($long)
    if ($g.Length -gt 255 -or $g.Length -lt 250 -or -not $g.EndsWith('...') -or -not $long.StartsWith($g.Substring(0, 250))) { $bad.Add('testo lungo: lunghezza ' + $g.Length) }
    $e = ''; try { $e = [string]$probe.D($edge) } catch { $e = 'EXCEPTION' }
    if ($e.Length -gt 255 -or $e -match '[\uD800-\uDBFF]($|[^\uDC00-\uDFFF])' -or -not $e.EndsWith('...')) { $bad.Add('taglio sul surrogato: [' + $e.Length + ']') }
    return $bad.ToArray()
}

if (-not (Test-Path -LiteralPath $path)) {
    Check $false 'l''helper KeepStoreCatalogExportText.vb esiste'
} else {
    $src = [IO.File]::ReadAllText($path, $utf8)
    $probe = New-Probe $src
    $bad = @(Test-All $probe)
    foreach ($b in $bad) { Write-Host ('    ' + $b) }
    Check ($bad.Count -eq 0) ('pulizia della descrizione: ' + ($cases.Count + 2) + ' casi (HTML, entita doppie, spazi, controlli, http, vuoto, testo lungo, surrogato al taglio)')
    $rnd = New-Object Random 11; $anomalies = 0
    for ($i = 0; $i -lt 2000; $i++) {
        $len = $rnd.Next(0, 400); $sb = New-Object Text.StringBuilder
        for ($k = 0; $k -lt $len; $k++) { [void]$sb.Append([char]$rnd.Next(0, 0xFFFF)) }
        $r = ''; try { $r = [string]$probe.D($sb.ToString()) } catch { $r = $null }
        if ($null -eq $r -or $r.Length -gt 255 -or $r -match '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' -or $r -ne $r.Trim()) { $anomalies++ }
    }
    Check ($anomalies -eq 0) ('2000 stringhe casuali: mai eccezioni, mai oltre 255 caratteri, mai controlli (anomalie ' + $anomalies + ')')
    if (-not $SkipMutants) {
        $mut = [ordered]@{
            'T01_NO_DECODE' = @{ From = 'HttpUtility.HtmlDecode(raw)'; To = 'raw' }
            'T02_NO_TAGS'   = @{ From = '"<[^>]*>"'; To = '"<<NEVER>>"' }
            'T03_NO_HTTP'   = @{ From = 'StartsWith("http", StringComparison.OrdinalIgnoreCase)'; To = 'StartsWith("zzzz", StringComparison.OrdinalIgnoreCase)' }
            'T04_NO_CUT'    = @{ From = 'If text.Length > MaxLength Then'; To = 'If False Then' }
            'T05_NO_SPACES' = @{ From = '"\s+"'; To = '"\s\s\s\s\s"' }
        }
        $kill = 0
        foreach ($id in $mut.Keys) {
            $m = $mut[$id]
            if (-not $src.Contains($m.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $fail.Add($id); continue }
            $dead = $false; try { $dead = (@(Test-All (New-Probe ($src.Replace($m.From, $m.To)))).Count -gt 0) } catch { $dead = $true }
            if ($dead) { $kill++; Write-Host ('  ok   mutante ' + $id + ' ucciso') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $fail.Add($id) }
        }
        Write-Host ('  mutanti uccisi ' + $kill + '/' + $mut.Count)
    }
}
if ($fail.Count -eq 0) { Write-Host 'CATALOG_TEXT PASS'; exit 0 } else { Write-Host 'CATALOG_TEXT FAIL'; exit 1 }
