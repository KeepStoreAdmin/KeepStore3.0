# Aiuti condivisi per le prove reali sul SITO LAB (https, 127.0.0.1 forzato, porta 18843, database LAB).
# Uso:  . (Join-Path $PSScriptRoot 'KeepStoreLabSiteHttp.ps1')   dopo aver definito $root e $utf8. Solo ASCII (Windows PowerShell 5.1).
# Mai password, valori dei cookie o dati personali in output. Tools/Invoke-KeepStoreLabSql.ps1 prende da solo il blocco del LAB: non tenerlo qui.
# Copia delle funzioni di Tools/Test-StaySignedInPages.ps1 (AUTH-STAY-SIGNED-IN-2B), che resta autonomo.

$base = 'https://www.taikun.it:18843'
$secretFile = Join-Path $env:APPDATA 'KeepStore\smoke-8443-webuser-prova.dpapi'
$testUser = 'PROVA'
$tmp = Join-Path $env:TEMP ('ks-labsite-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$col = 'Pass' + 'word'
$e2e = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name) } }

function Invoke-Sql([string]$sql, [switch]$Write) {
    $f = Join-Path $tmp ('q' + [Guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($f, $sql, $utf8)
    try {
        if ($Write) { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f -Write }
        else { $o = & powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File $labSql -SqlFile $f }
        return @($o)
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
function Get-Scalar([string]$sql) {
    $o = @(Invoke-Sql $sql)
    for ($i = 0; $i -lt $o.Count - 1; $i++) { if ([string]$o[$i] -eq 'ksval') { return ([string]$o[$i + 1]).Trim() } }
    return ''
}
function Invoke-Http([string]$path, [string]$jar, [string]$bodyFile = '', [string]$referer = '') {
    $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.html'); $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt')
    $a = @('--noproxy', '*', '-s', '--max-time', '180', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-b', $jar, '-c', $jar, '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}')
    if ($bodyFile -ne '') { $a += @('-H', ('Origin: ' + $base), '-H', ('Referer: ' + $base + $referer), '--data', ('@' + $bodyFile)) }
    $a += ($base + $path)
    $w = (& curl.exe @a) -join ''
    $parts = $w.Split('|')
    if ($parts.Count -lt 2 -or $parts[1] -ne '127.0.0.1') { throw ('NOT_LOOPBACK ' + $w) }
    $headers = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out, [Text.Encoding]::UTF8) } else { '' }
    $loc = ''; $mm = [regex]::Match($headers, '(?im)^Location:\s*(\S+)'); if ($mm.Success) { $loc = $mm.Groups[1].Value }
    return [pscustomobject]@{ Status = [int]$parts[0]; Location = $loc; Headers = $headers; Body = $body }
}
# Tutti i campi del modulo della pagina (nascosti e di testo), poi quelli indicati.
function New-FormFile([string]$html, [hashtable]$set) {
    $fields = @{}
    foreach ($mm in [regex]::Matches($html, '<input\b[^>]*>')) {
        $tag = $mm.Value
        $n = [regex]::Match($tag, '\bname="([^"]*)"'); if (-not $n.Success) { continue }
        $t = [regex]::Match($tag, '\btype="([^"]*)"'); $type = if ($t.Success) { $t.Groups[1].Value.ToLowerInvariant() } else { 'text' }
        if (@('submit', 'button', 'image', 'checkbox', 'radio', 'file', 'reset') -contains $type) { continue }
        $v = [regex]::Match($tag, '\bvalue="([^"]*)"')
        $fields[[Net.WebUtility]::HtmlDecode($n.Groups[1].Value)] = if ($v.Success) { [Net.WebUtility]::HtmlDecode($v.Groups[1].Value) } else { '' }
    }
    foreach ($k in $set.Keys) { $fields[$k] = [string]$set[$k] }
    $pairs = New-Object Collections.Generic.List[string]
    foreach ($k in $fields.Keys) { $pairs.Add(([Uri]::EscapeDataString($k)) + '=' + ([Uri]::EscapeDataString([string]$fields[$k]))) }
    $f = Join-Path $tmp ('f' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($f, ($pairs -join '&'), $utf8)
    return $f
}
function Get-FieldName([string]$html, [string]$suffix) {
    $mm = [regex]::Match($html, 'name="([^"]*\$' + [regex]::Escape($suffix) + ')"'); if ($mm.Success) { return [Net.WebUtility]::HtmlDecode($mm.Groups[1].Value) } else { return '' }
}
function Get-Secret {
    $sec = ConvertTo-SecureString (Get-Content -LiteralPath $secretFile)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
function Invoke-Login([string]$jar, [bool]$stay, [string]$word = '') {
    $page = Invoke-Http '/login.aspx' $jar
    $set = @{ '__EVENTTARGET' = (Get-FieldName $page.Body 'btnLogin'); '__EVENTARGUMENT' = '' }
    if ($set['__EVENTTARGET'] -eq '') { $set['__EVENTTARGET'] = 'ctl00$MainContent$btnLogin' }
    $set[(Get-FieldName $page.Body 'tbUsername')] = $testUser
    $set[(Get-FieldName $page.Body 'tbPassword')] = if ($word -ne '') { $word } else { Get-Secret }
    if ($stay) { $set['ctl00$MainContent$chkStaySignedIn'] = 'on' }
    $f = New-FormFile $page.Body $set
    try { $r = Invoke-Http '/login.aspx' $jar $f '/login.aspx' } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    # AUTH-LOGIN-SESSION-RENEW-1A: dopo l'accesso il sito cambia sessione e rinvia a login.aspx?k=1; il rinvio si segue qui, cosi il jar resta
    # collegato e la risposta restituita e quella con la destinazione (302 verso la pagina richiesta), come prima del cambio.
    if ($r.Status -eq 302 -and $r.Location -match '(?i)login\.aspx\?k=1$') { return (Invoke-Http '/login.aspx?k=1' $jar) }
    return $r
}
function Get-JarValue([string]$jar, [string]$name) {
    if (-not (Test-Path -LiteralPath $jar)) { return '' }
    foreach ($line in [IO.File]::ReadAllLines($jar)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[5] -eq $name) { return $c[6] } }
    return ''
}
function Set-JarValue([string]$jar, [string]$name, [string]$value) {
    $lines = [IO.File]::ReadAllLines($jar)
    $outLines = New-Object Collections.Generic.List[string]
    foreach ($line in $lines) {
        $c = $line.Split("`t")
        if ($c.Count -ge 7 -and $c[5] -eq $name) { if ($value -ne '') { $c[6] = $value; $outLines.Add(($c -join "`t")) } } else { $outLines.Add($line) }
    }
    [IO.File]::WriteAllLines($jar, $outLines.ToArray())
}
function Get-SetCookie([string]$headers, [string]$name) {
    $mm = [regex]::Match($headers, '(?im)^Set-Cookie:\s*' + [regex]::Escape($name) + '=([^;\r\n]*)(;[^\r\n]*)?')
    if ($mm.Success) { return [pscustomobject]@{ Found = $true; Empty = ($mm.Groups[1].Value -eq ''); Attr = $mm.Groups[2].Value } }
    return [pscustomobject]@{ Found = $false; Empty = $false; Attr = '' }
}
function Test-CookieAttr([string]$attr) { return ($attr -match '(?i);\s*path=/(;|$)' -and $attr -match '(?i);\s*secure' -and $attr -match '(?i);\s*HttpOnly' -and $attr -match '(?i);\s*SameSite=Lax' -and $attr -notmatch '(?i);\s*domain=') }

# Nome del cookie di sessione del sito (configurazione privata del sito: non e sempre ASP.NET_SessionId).
function Get-SessionCookieName {
    $probeJar = Join-Path $tmp ('probe' + [Guid]::NewGuid().ToString('N') + '.txt')
    $null = Invoke-Http '/login.aspx' $probeJar
    foreach ($line in [IO.File]::ReadAllLines($probeJar)) { $c = $line.Split("`t"); if ($c.Count -ge 7 -and $c[6].Length -eq 24 -and -not $c[5].StartsWith('__Host-')) { return $c[5] } }
    return ''
}

# True se il testo compare nella risposta o nel suo __VIEWSTATE decodificato (UTF-8 o UTF-16). Non stampa nulla.
function Test-ResponseContains([string]$html, [string]$needle) {
    if ([string]::IsNullOrEmpty($needle)) { return $false }
    if ($html.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return $true }
    foreach ($mm in [regex]::Matches($html, 'name="__VIEWSTATE[^"]*"[^>]*value="([^"]*)"')) {
        try { $bytes = [Convert]::FromBase64String([Net.WebUtility]::HtmlDecode($mm.Groups[1].Value)) } catch { continue }
        $latin = [Text.Encoding]::GetEncoding(28591)
        $hay = $latin.GetString($bytes)
        if ($hay.IndexOf($latin.GetString([Text.Encoding]::UTF8.GetBytes($needle)), [StringComparison]::Ordinal) -ge 0) { return $true }
        if ($hay.IndexOf($latin.GetString([Text.Encoding]::Unicode.GetBytes($needle)), [StringComparison]::Ordinal) -ge 0) { return $true }
    }
    return $false
}
# Tutti i campi del modulo: input (non pulsanti), opzione scelta di ogni select, textarea; poi quelli indicati.
function New-FullFormFile([string]$html, [hashtable]$set) {
    $fields = @{}
    foreach ($mm in [regex]::Matches($html, '<input\b[^>]*>')) {
        $tag = $mm.Value
        $n = [regex]::Match($tag, '\bname="([^"]*)"'); if (-not $n.Success) { continue }
        $t = [regex]::Match($tag, '\btype="([^"]*)"'); $type = if ($t.Success) { $t.Groups[1].Value.ToLowerInvariant() } else { 'text' }
        if (@('submit', 'button', 'image', 'file', 'reset') -contains $type) { continue }
        if (@('checkbox', 'radio') -contains $type -and $tag -notmatch '\bchecked\b') { continue }
        $v = [regex]::Match($tag, '\bvalue="([^"]*)"')
        $fields[[Net.WebUtility]::HtmlDecode($n.Groups[1].Value)] = if ($v.Success) { [Net.WebUtility]::HtmlDecode($v.Groups[1].Value) } elseif (@('checkbox', 'radio') -contains $type) { 'on' } else { '' }
    }
    foreach ($mm in [regex]::Matches($html, '(?s)<select\b[^>]*\bname="([^"]*)"[^>]*>(.*?)</select>')) {
        $o = [regex]::Match($mm.Groups[2].Value, '<option\b[^>]*\bselected\b[^>]*\bvalue="([^"]*)"|<option\b[^>]*\bvalue="([^"]*)"[^>]*\bselected\b')
        if (-not $o.Success) { $o = [regex]::Match($mm.Groups[2].Value, '<option\b[^>]*\bvalue="([^"]*)"') }
        if ($o.Success) { $val = if ($o.Groups[1].Success -and $o.Groups[1].Value -ne '') { $o.Groups[1].Value } else { $o.Groups[2].Value }; $fields[[Net.WebUtility]::HtmlDecode($mm.Groups[1].Value)] = [Net.WebUtility]::HtmlDecode($val) }
    }
    foreach ($mm in [regex]::Matches($html, '(?s)<textarea\b[^>]*\bname="([^"]*)"[^>]*>(.*?)</textarea>')) { $fields[[Net.WebUtility]::HtmlDecode($mm.Groups[1].Value)] = [Net.WebUtility]::HtmlDecode($mm.Groups[2].Value.Trim()) }
    foreach ($k in $set.Keys) { $fields[$k] = [string]$set[$k] }
    $pairs = New-Object Collections.Generic.List[string]
    foreach ($k in $fields.Keys) { $pairs.Add(([Uri]::EscapeDataString($k)) + '=' + ([Uri]::EscapeDataString([string]$fields[$k]))) }
    $f = Join-Path $tmp ('f' + [Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($f, ($pairs -join '&'), $utf8)
    return $f
}
function Get-PostTarget([string]$html, [string]$suffix) {
    $mm = [regex]::Match($html, '__doPostBack\((?:&#39;|'')([^&'']*' + [regex]::Escape($suffix) + ')(?:&#39;|'')')
    if ($mm.Success) { return $mm.Groups[1].Value } else { return '' }
}
# Invia "Dati account" con i valori indicati (chiavi = suffisso del nome del campo). Restituisce la risposta.
function Send-AccountEdit([string]$jar, [hashtable]$values) {
    $page = Invoke-Http '/my-account-edit.aspx' $jar
    $set = @{ '__EVENTTARGET' = (Get-PostTarget $page.Body 'btnSave'); '__EVENTARGUMENT' = '' }
    foreach ($k in $values.Keys) { $n = Get-FieldName $page.Body $k; if ($n -eq '') { $n = 'ctl00$MainContent$' + $k }; $set[$n] = $values[$k] }
    $f = New-FullFormFile $page.Body $set
    try { return (Invoke-Http '/my-account-edit.aspx' $jar $f '/my-account-edit.aspx') } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
# Impronta di un codice di recupero come la calcola il sito (SHA-256 del testo UTF-8, esadecimale minuscolo).
function Get-Sha256Hex([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (-join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString('x2') })) } finally { $sha.Dispose() }
}
function Close-LabSite { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
