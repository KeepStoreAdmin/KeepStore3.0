[CmdletBinding()]
param()
# KS-A04-HOME-IMG-ENCODE-1A
# 1) ThemeManager.ProductImageUrl / ProductThumbnailImageUrl never return an external URL or data URI that could
#    close an HTML attribute or open a tag; safe values stay verbatim. The real module is compiled and executed.
# 2) The live HOME card renderers (RenderDealCard, RenderGridCard) write every image URL through EncodeAttr.
# Both checks are mutation-tested: the test must fail when the protection is removed.
# Windows PowerShell 5.1, no network, no database, no configuration.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'WINDOWS_POWERSHELL_51_REQUIRED' }
$root = Split-Path -Parent $PSScriptRoot
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work = Join-Path $tempBase ('ks-image-url-safety-' + [Guid]::NewGuid().ToString('N'))
$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$utf8 = New-Object Text.UTF8Encoding($false)
$results = New-Object 'System.Collections.Generic.List[string]'

function Read-Lf([string]$path) { return [IO.File]::ReadAllText((Join-Path $root $path)).Replace(([string][char]13 + [string][char]10), [string][char]10) }
function Mutate([string]$text, [string]$old, [string]$new) {
    if (-not $text.Contains($old)) { throw ('MUTATION_NOT_APPLICABLE ' + $old) }
    return $text.Replace($old, $new)
}

$harness = @'
Imports System
Module ProductImageUrlSafetyHarness
    Private failures As Integer = 0
    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        If ok Then
            Console.WriteLine("PASS " & name)
        Else
            Console.WriteLine("FAIL " & name)
            failures += 1
        End If
    End Sub
    Private Function Clean(ByVal value As String) As Boolean
        Return value.IndexOf("'"c) < 0 AndAlso value.IndexOf(""""c) < 0 AndAlso value.IndexOf("<"c) < 0 AndAlso value.IndexOf(">"c) < 0
    End Function
    Function Main() As Integer
        Dim placeholder As String = ThemeManager.PlaceholderProductImageUrl()
        Check(Clean(placeholder), "placeholder is attribute safe")
        Dim safeValues As String() = {"https://img.example.test/a/b.jpg", "http://img.example.test/a.jpg?x=1&y=2", "https://img.example.test/a b.jpg",
            "https://img.example.test/p%C3%A8.jpg", "data:image/png;base64,iVBORw0KGgo=", "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4="}
        For Each value As String In safeValues
            Check(ThemeManager.ProductImageUrl(value) = value, "safe value kept verbatim: " & value)
            Check(ThemeManager.ProductThumbnailImageUrl(value) = value, "safe value kept verbatim by thumbnail: " & value)
        Next
        Dim hostile As String() = {"https://x.test/a'onerror='alert(1).jpg", "https://x.test/a""onload=""x.jpg", "https://x.test/a<b>.jpg",
            "https://x.test/a`b.jpg", "https://x.test/a" & vbLf & "b.jpg", "http://x.test/" & New String("a"c, 3000),
            "data:text/html;base64,PHNjcmlwdD4=", "data:image/html;base64,PHNjcmlwdD4=","data:image/png;base64,AAAA' onerror='x", "data:image/svg+xml,<svg onload=alert(1)>",
            "data:image/png;base64,AA""AA", "javascript:alert(1)", "https://x.test/a'b", "https://x.test/a<b.jpg", "https://x.test/a>b.jpg",
            "https://x.test/a""b.jpg", "https://x.test/a`b.jpg"}
        For Each value As String In hostile
            Dim full As String = ThemeManager.ProductImageUrl(value)
            Dim thumb As String = ThemeManager.ProductThumbnailImageUrl(value)
            Dim label As String = If(value.Length > 40, value.Substring(0, 40) & "...", value).Replace(vbLf, "<LF>")
            Check(full <> value AndAlso Clean(full), "hostile value not returned by ProductImageUrl: " & label)
            Check(thumb <> value AndAlso Clean(thumb), "hostile value not returned by ProductThumbnailImageUrl: " & label)
        Next
        Check(ThemeManager.ProductImageUrl(Nothing) = placeholder AndAlso ThemeManager.ProductImageUrl(DBNull.Value) = placeholder, "empty value gives placeholder")
        Console.WriteLine("HARNESS_FAILURES=" & failures)
        Return If(failures = 0, 0, 1)
    End Function
End Module
'@

function Invoke-Variant([string]$name, [string]$themeSource) {
    $dir = Join-Path $work $name
    [void][IO.Directory]::CreateDirectory($dir)
    $themePath = Join-Path $dir 'ThemeManager.vb'
    $harnessPath = Join-Path $dir 'Harness.vb'
    [IO.File]::WriteAllText($themePath, $themeSource, $utf8)
    [IO.File]::WriteAllText($harnessPath, $harness, $utf8)
    $exe = Join-Path $dir 'Harness.exe'
    $log = Join-Path $dir 'compile.log'
    $compileArgs = @('/nologo', '/target:exe', '/optioninfer+', '/main:ProductImageUrlSafetyHarness', ('/out:' + $exe),
        ('/reference:' + (Join-Path $framework 'System.dll')), ('/reference:' + (Join-Path $framework 'System.Web.dll')),
        ('/reference:' + (Join-Path $framework 'System.Configuration.dll')), $themePath, $harnessPath)
    & (Join-Path $framework 'vbc.exe') @compileArgs *> $log
    if ($LASTEXITCODE -ne 0) { throw ('COMPILE_FAILED ' + $name + ' ' + ((Get-Content $log -Raw))) }
    $output = & $exe 2>&1
    $code = $LASTEXITCODE
    return @{ Code = $code; Output = @($output) }
}

try {
    [void][IO.Directory]::CreateDirectory($work)
    $theme = Read-Lf 'App_Code/ThemeManager.vb'
    $actual = Invoke-Variant 'actual' $theme
    $fails = @($actual.Output | Where-Object { $_ -like 'FAIL*' })
    if ($actual.Code -ne 0 -or $fails.Count -gt 0) { throw ('IMAGE_URL_SAFETY_FAIL ' + ($fails -join ' | ')) }
    $passes = @($actual.Output | Where-Object { $_ -like 'PASS*' }).Count
    $results.Add('ThemeManager harness: ' + $passes + ' PASS')

    # Mutations of the module: each one must be caught by the executed cases.
    $mutants = @(
        @{ Name = 'no http validation'; Old = 'Then Return IsSafeExternalImageReference(raw)'; New = 'Then Return True' },
        @{ Name = 'no data validation'; Old = 'Then Return IsSafeImageDataUri(raw)'; New = 'Then Return True' },
        @{ Name = 'quote allowed'; Old = 'OrElse ch = "''"c'; New = '' },
        @{ Name = 'angle bracket allowed'; Old = 'OrElse ch = "<"c'; New = '' },
        @{ Name = 'closing angle bracket allowed'; Old = 'OrElse ch = ">"c'; New = '' },
        @{ Name = 'double quote allowed'; Old = 'OrElse ch = """"c'; New = '' },
        @{ Name = 'backtick allowed'; Old = 'OrElse ch = "`"c'; New = '' },
        @{ Name = 'control characters allowed'; Old = 'code < 32 OrElse code = 127 OrElse '; New = '' },
        @{ Name = 'any data mime allowed'; Old = '(?:png|jpe?g|gif|webp|avif|svg\+xml)'; New = '[a-z+]+' }
    )
    foreach ($m in $mutants) {
        $variant = Invoke-Variant ('mut-' + ($m.Name -replace '[^a-z]', '')) (Mutate $theme $m.Old $m.New)
        $caught = ($variant.Code -ne 0) -or (@($variant.Output | Where-Object { $_ -like 'FAIL*' }).Count -gt 0)
        if (-not $caught) { throw ('MUTANT_SURVIVED ' + $m.Name) }
        $results.Add('mutant caught: ' + $m.Name)
    }

    # HOME renderers: every image URL goes through EncodeAttr.
    $homeSource = Read-Lf 'Default.aspx.vb'
    function Extract-Function([string]$source, [string]$name) {
        $m = [regex]::Match($source, '(?ms)^    Protected Function ' + [regex]::Escape($name) + '\(.*?^    End Function')
        if (-not $m.Success) { throw ('FUNCTION_MISSING ' + $name) }
        return $m.Value
    }
    function Check-Renderer([string]$body, [string]$label) {
        $imgLines = @($body -split "`n" | Where-Object { $_ -match '<img ' })
        if ($imgLines.Count -eq 0) { throw ('NO_IMG_IN ' + $label) }
        foreach ($line in $imgLines) {
            $sources = [regex]::Matches($line, "(?:src|data-src)='""\)\.Append\(([^\r\n]*?)\)\.Append\(""'")
            if ($sources.Count -lt 2) { throw ('NO_SRC_APPEND_IN ' + $label) }
            foreach ($s in $sources) {
                if (-not $s.Groups[1].Value.StartsWith('EncodeAttr(')) { throw ('UNENCODED_IMAGE_URL ' + $label + ': ' + $s.Groups[1].Value) }
            }
        }
        return $imgLines.Count
    }
    $deal = Extract-Function $homeSource 'RenderDealCard'
    $grid = Extract-Function $homeSource 'RenderGridCard'
    $n1 = Check-Renderer $deal 'RenderDealCard'
    $n2 = Check-Renderer $grid 'RenderGridCard'
    $results.Add('HOME renderers encode image URLs: deal ' + $n1 + ' img lines, grid ' + $n2 + ' img lines')
    foreach ($label in @('deal', 'grid')) {
        $body = if ($label -eq 'deal') { $deal } else { $grid }
        $mutated = $body.Replace('EncodeAttr(', '(')
        $caught = $false
        try { [void](Check-Renderer $mutated $label) } catch { $caught = $true }
        if (-not $caught) { throw ('RENDERER_MUTANT_SURVIVED ' + $label) }
        $results.Add('renderer mutant caught: ' + $label)
    }
    $results | ForEach-Object { Write-Output $_ }
    Write-Output 'PRODUCT_IMAGE_URL_SAFETY=PASS; SQL_EXECUTED=NO; NETWORK=NO'
}
finally {
    if (Test-Path -LiteralPath $work) {
        $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $work).Path)
        if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or $resolved -eq $tempBase.TrimEnd('\')) { throw 'UNSAFE_CLEANUP' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
