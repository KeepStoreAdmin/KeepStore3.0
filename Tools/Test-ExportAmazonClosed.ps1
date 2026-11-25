[CmdletBinding()]
param([switch]$SkipMutants, [string]$MutantFilter = '', [switch]$Baseline, [string]$SitePath = 'C:\Temp\KeepStoreRegOrderLab-20261025\site')

# EXPORT-AMAZON-CLOSE-1A. export_amazon.aspx era pubblica e senza autenticazione: con fase=1 mostrava la configurazione della tabella export_amazon, con fase=3 scriveva
# nella tabella con testo SQL concatenato (iniezione con scrittura), senza fase produceva un file con parametri presi dall'indirizzo. Ora la PAGINA risponde SEMPRE 410 con il
# testo fisso 'Servizio non disponibile', senza connessione al database, senza leggere la richiesta, senza eco, con Cache-Control no-store.
# Limite dichiarato: la pipeline comune (Global.asax, resolver azienda, HTTPS/host canonico) non e toccata; le richieste del test sono locali (IsLocal) e non la attraversano.
# Prova HTTP sul sito LAB (https, 127.0.0.1 forzato, porta 18843, DB LAB). Ordine: mutex di sito, identita del LAB, POI le fotografie (file del sito, riga export_amazon).
# Si copiano nel sito LAB export_amazon.aspx.vb (e .aspx se diverso) del repository e poi si rimettono i byte originali: solo se il test li ha scritti.
# Oracolo di non-accesso al database: la serie gira anche con la tabella export_amazon RINOMINATA (una pagina che la toccasse darebbe errore invece di 410; la lettura
# silenziata da Try/Catch la ferma solo l'elenco chiuso delle righe del sorgente). Il nome e sempre ripristinato, anche dopo un'interruzione (un solo residuo noto).
# -Baseline: NON installa il codice del repository (il sito resta com'e): serve a vedere il test ROSSO sul codice vecchio; solo qui si usa Reset-App (il vecchio codice perde
# connessioni al database e il LAB ha max_connections=40): il test normale non tocca web.config e non riavvia l'applicazione.
# Un solo uso del sito LAB alla volta: mutex di sistema Global\KeepStoreLabSite18843 (le query usano gia Global\KeepStoreLocalLabSql); vale per chi lo usa.
# Mai password in output. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($SitePath -notmatch '^C:\\Temp\\KeepStoreRegOrderLab-[0-9]+\\site$') { Write-Host 'EXPORT_AMAZON FAIL: il sito di prova deve essere quello del LAB'; exit 1 }
$vbFile = 'export_amazon.aspx.vb'; $aspxFile = 'export_amazon.aspx'
$repoVb = [IO.File]::ReadAllBytes((Join-Path $root $vbFile))
$repoAspx = [IO.File]::ReadAllBytes((Join-Path $root $aspxFile))
function Get-Text([byte[]]$bytes) { $o = 0; if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $o = 3 }; return $utf8.GetString($bytes, $o, $bytes.Length - $o) }

$base = 'https://www.taikun.it:18843'
$expectBody = 'Servizio non disponibile'
$expectBytes = $utf8.GetBytes($expectBody)
$tmp = Join-Path $env:TEMP ('ks-exportamazon-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$labSql = Join-Path $root 'Tools\Invoke-KeepStoreLabSql.ps1'
$e2e = New-Object Collections.Generic.List[string]
$script:failSrc = 0; $script:failHttp = 0
# kind: 'src' = controllo sul sorgente, 'http' = oracolo comportamentale
function Check([bool]$ok, [string]$name, [string]$kind = 'http') {
    if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $e2e.Add($name); if ($kind -eq 'src') { $script:failSrc++ } else { $script:failHttp++ } }
}

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
function Sql-Hex([string]$col) { return ('IFNULL(HEX(CAST(' + $col + ' AS CHAR)), ''NULL'')') }
# Impronta di TUTTE le colonne della riga (nessun valore in output, solo l'MD5).
$cols = @('Abilitato', 'nuovo_inserimento', 'Aggiornamenti', 'avvio_forzato_aggiornamento', 'avvio_forzato_nuovo_inserimento', 'stato_esecuzione', 'Mode', 'Note', 'NListino', 'IvaTipo', 'Giacenza', 'SpeseSpedizione', 'GiorniSpedizione', 'Azienda', 'IdVettore', 'NListino2', 'NoVettoreSuGratis')
$hashSql = 'SELECT MD5(CONCAT_WS(''|'', ' + (($cols | ForEach-Object { Sql-Hex $_ }) -join ', ') + ')) AS ksval FROM export_amazon;'
function Get-RowHash { return (Get-Scalar $hashSql) }
function Restore-Row($r0) {
    $s = if ($r0.S -eq 'NULL') { 'NULL' } else { 'CONVERT(UNHEX(''' + $r0.S + ''') USING utf8mb4)' }
    $null = Invoke-Sql ('UPDATE export_amazon SET stato_esecuzione = ' + $s + ', avvio_forzato_aggiornamento = ' + $r0.A + ', avvio_forzato_nuovo_inserimento = ' + $r0.N + ';') -Write
}

# Una richiesta: stato, intestazioni e corpo (byte e testo). Metodo GET, POST o HEAD. La query e il corpo sono gia codificati dal chiamante.
function Invoke-Probe([string]$method, [string]$query, [string]$postBody, [string]$path = '/export_amazon.aspx') {
    if ($Baseline -and -not $script:inReset -and $script:reqCount -ge 12) { Reset-App }
    $script:reqCount++
    $hdr = Join-Path $tmp ('h' + [Guid]::NewGuid().ToString('N') + '.txt'); $out = Join-Path $tmp ('b' + [Guid]::NewGuid().ToString('N') + '.txt')
    $url = $base + $path + $(if ($query -ne '') { '?' + $query } else { '' })
    $a = @('--noproxy', '*', '-s', '--max-time', '120', '--resolve', 'www.taikun.it:18843:127.0.0.1', '-D', $hdr, '-o', $out, '-w', '%{http_code}|%{remote_ip}')
    if ($method -eq 'HEAD') { $a += '-I' } elseif ($method -eq 'POST') { $a += @('-X', 'POST', '--data-raw', $postBody, '-H', 'Content-Type: application/x-www-form-urlencoded') }
    $a += $url
    $w = ''; $parts = @('0', '')
    for ($try = 0; $try -lt 6; $try++) {
        $w = (& curl.exe @a) -join ''
        $parts = $w.Split('|')
        if ($parts.Count -ge 2 -and $parts[1] -ne '127.0.0.1' -and $parts[1] -ne '') { throw ('NOT_LOOPBACK ' + $w) }
        if ($parts[0] -ne '000' -and $parts[0] -ne '503') { break }
        Start-Sleep -Seconds 4   # il sito LAB e condiviso: una ripartenza dell'applicazione di un altro test dura pochi secondi
    }
    $h = if (Test-Path -LiteralPath $hdr) { [IO.File]::ReadAllText($hdr) } else { '' }
    [byte[]]$bytes = New-Object byte[] 0
    if ($method -ne 'HEAD' -and (Test-Path -LiteralPath $out)) { $bytes = [IO.File]::ReadAllBytes($out) }
    Remove-Item -LiteralPath $hdr, $out -Force -ErrorAction SilentlyContinue
    return @{ Status = [int]$parts[0]; Headers = $h; Bytes = $bytes; Body = $utf8.GetString($bytes) }
}
function Wait-Site {
    $ok = 0
    for ($i = 0; $i -lt 60; $i++) {
        $st = 0; try { $st = (Invoke-Probe 'GET' 'probe=1' '').Status } catch { $st = 0 }
        if ($st -ne 0 -and $st -ne 503) { $ok++; if ($ok -ge 2) { return } } else { $ok = 0 }
        Start-Sleep -Seconds 3
    }
    throw 'SITE_NOT_BACK'
}
$script:reqCount = 0; $script:inReset = $false; $script:siteTouched = $false
function Reset-App {
    $script:inReset = $true
    try { (Get-Item -LiteralPath (Join-Path $SitePath 'web.config')).LastWriteTime = Get-Date; Start-Sleep -Seconds 6; $script:reqCount = 0; Wait-Site; $script:reqCount = 0 } finally { $script:inReset = $false }
}
function Deploy-Repo {
    $script:siteTouched = $true
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$repoAspx, [byte[]]$script:origAspx)) { [IO.File]::WriteAllBytes((Join-Path $SitePath $aspxFile), $repoAspx) }
    [IO.File]::WriteAllBytes((Join-Path $SitePath $vbFile), $repoVb); Start-Sleep -Seconds 3; Wait-Site
}
function Restore-Site { [IO.File]::WriteAllBytes((Join-Path $SitePath $aspxFile), $script:origAspx); [IO.File]::WriteAllBytes((Join-Path $SitePath $vbFile), $script:origVb); Start-Sleep -Seconds 3; Wait-Site }
function Set-Mutant([string]$text) { $script:siteTouched = $true; $bom = ($repoVb.Length -ge 3 -and $repoVb[0] -eq 0xEF); [IO.File]::WriteAllText((Join-Path $SitePath $vbFile), $text, (New-Object Text.UTF8Encoding($bom))); Start-Sleep -Seconds 3; Wait-Site }

# Marcatori unici: se la pagina li rimandasse indietro (eco) o li scrivesse, i casi falliscono.
$mk = 'KSMARK' + ([Guid]::NewGuid().ToString('N').Substring(0, 10))
$apos = [string][char]39
$cases = @(
    @{ N = 'fase=1 (configurazione)'; M = 'GET'; Q = 'fase=1'; B = ''; W = $false },
    @{ N = 'fase=3 con apice'; M = 'GET'; Q = ('fase=3&azione=x&statoesecuzione=' + $mk + 'a' + [Uri]::EscapeDataString($apos)); B = ''; W = $true },
    @{ N = 'fase=3 con or 1=1'; M = 'GET'; Q = ('fase=3&azione=nuovoinserimento&statoesecuzione=' + $mk + 'b' + [Uri]::EscapeDataString($apos + ' or 1=1 -- ')); B = ''; W = $true },
    @{ N = 'fase=3 azione normale'; M = 'GET'; Q = ('fase=3&azione=aggiornamento&statoesecuzione=' + $mk + 'c'); B = ''; W = $true },
    @{ N = 'nessuna fase'; M = 'GET'; Q = ''; B = ''; W = $false },
    @{ N = 'feed con formatString e header'; M = 'GET'; Q = ('formatString=%23Codice%23&header=' + $mk + 'h'); B = ''; W = $false },
    @{ N = 'script nei parametri'; M = 'GET'; Q = ('fase=1&x=' + [Uri]::EscapeDataString('<script>alert(1)</script>') + $mk + 'd'); B = ''; W = $false },
    @{ N = 'byte nulli e non validi'; M = 'GET'; Q = ('fase=1&x=%00&y=%FF&z=%' + $mk + 'z'); B = ''; W = $false },
    @{ N = 'valore lungo'; M = 'GET'; Q = ('fase=3&statoesecuzione=' + $mk + ('Z' * 1500)); B = ''; W = $true },
    @{ N = 'POST con fase=3 nel corpo'; M = 'POST'; Q = ''; B = ('fase=3&azione=x&statoesecuzione=' + $mk + 'e' + [Uri]::EscapeDataString($apos + ' or 1=1 -- ')); W = $true },
    @{ N = 'POST con fase=3 anche in query'; M = 'POST'; Q = ('fase=3&statoesecuzione=' + $mk + 'f'); B = ('statoesecuzione=' + $mk + 'g'); W = $true },
    @{ N = 'POST con <x nel corpo'; M = 'POST'; Q = ''; B = ('a=' + [Uri]::EscapeDataString('<x onclick=1>') + '&fase=3&statoesecuzione=' + $mk + 'k'); W = $true },
    @{ N = 'POST con __VIEWSTATE non valido'; M = 'POST'; Q = ''; B = ('__VIEWSTATE=AAAA&__EVENTVALIDATION=BBBB&fase=3&statoesecuzione=' + $mk + 'v'); W = $true },
    @{ N = 'HEAD'; M = 'HEAD'; Q = 'fase=1'; B = ''; W = $false }
)

# Elenco CHIUSO delle righe di codice ammesse (commenti e righe vuote esclusi): qualunque riga in piu o in meno e una decisione, non un dettaglio.
$allowedLines = @(
    'Partial Class export_amazon',
    'Inherits System.Web.UI.Page',
    'Public Overrides Sub ProcessRequest(ByVal context As System.Web.HttpContext)',
    'Dim r As System.Web.HttpResponse = context.Response',
    'r.Clear()',
    'r.StatusCode = 410',
    'r.StatusDescription = "Gone"',
    'r.TrySkipIisCustomErrors = True',
    'r.Cache.SetCacheability(System.Web.HttpCacheability.NoCache)',
    'r.Cache.SetNoStore()',
    'r.ContentType = "text/plain"',
    'r.Charset = "utf-8"',
    'r.Write("Servizio non disponibile")',
    'End Sub',
    'End Class'
)
function Test-Source([string]$src, [string]$label) {
    $code = @($src -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and -not $_.StartsWith("'") })
    $same = ($code.Count -eq $allowedLines.Count)
    if ($same) { for ($i = 0; $i -lt $code.Count; $i++) { if ($code[$i] -cne $allowedLines[$i]) { $same = $false; break } } }
    Check $same ($label + ' sorgente = elenco chiuso di ' + $allowedLines.Count + ' righe (nessun database, nessuna lettura della richiesta, nessun helper)') 'src'
}

function Test-Response($c, $r, [string]$label) {
    $n = $label + ' ' + $c.N
    Check ($r.Status -eq 410) ($n + ' -> stato 410 (visto ' + $r.Status + ')')
    if ($c.M -ne 'HEAD') { Check ([Linq.Enumerable]::SequenceEqual([byte[]]$r.Bytes, [byte[]]$expectBytes)) ($n + ' -> corpo identico byte per byte (' + $r.Bytes.Length + ' byte)') }
    else { Check ($r.Bytes.Length -eq 0) ($n + ' -> nessun corpo') }
    Check ($r.Headers -match '(?im)^Cache-Control:[^\r\n]*no-store') ($n + ' -> Cache-Control no-store')
    Check ($r.Headers -match '(?im)^Content-Type:\s*text/plain;\s*charset=utf-8\s*$') ($n + ' -> Content-Type text/plain; charset=utf-8')
    Check ($r.Headers -notmatch '(?im)^Content-Disposition:') ($n + ' -> nessun Content-Disposition')
    Check ($r.Headers -notmatch '(?im)^Location:') ($n + ' -> nessun reindirizzamento')
    Check (($r.Body + $r.Headers) -notmatch [regex]::Escape($mk)) ($n + ' -> nessuna eco della richiesta')
}

function Run-Cases([string]$srcText) {
    Test-Source $srcText 'S'
    $h0 = Get-RowHash
    Check ($h0 -match '^[0-9a-f]{32}$') 'impronta della riga export_amazon letta'
    foreach ($c in $cases) {
        $r = Invoke-Probe $c.M $c.Q $c.B
        Test-Response $c $r 'A'
        if ($c.W) { Check ((Get-RowHash) -eq $h0) ('A ' + $c.N + ' -> la riga export_amazon non e cambiata') }
    }
    Check ((Get-RowHash) -eq $h0) 'A riga export_amazon identica dopo tutta la serie'
    # Serie B: tabella rinominata. Una pagina che la leggesse o scrivesse darebbe errore (non 410).
    $tmpName = 'export_amazon_ks' + ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = Invoke-Sql ('RENAME TABLE export_amazon TO ' + $tmpName + ';') -Write
    try {
        $gone = Get-Scalar 'SELECT COUNT(*) AS ksval FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=''export_amazon'';'
        Check ($gone -eq '0') 'B tabella export_amazon rinominata sul LAB'
        foreach ($c in $cases) { $r = Invoke-Probe $c.M $c.Q $c.B; Test-Response $c $r 'B' }
    } finally {
        $null = Invoke-Sql ('RENAME TABLE ' + $tmpName + ' TO export_amazon;') -Write
    }
    Check ((Get-RowHash) -eq $h0) 'B tabella ripristinata, riga identica'
}

$exit = 0
$labHeld = $false
$siteMutex = New-Object System.Threading.Mutex($false, 'Global\KeepStoreLabSite18843')
$row0 = $null
$script:origVb = $null; $script:origAspx = $null
try {
    # 1) mutex di sito, 2) identita del LAB, 3) solo dopo le fotografie.
    try { $labHeld = $siteMutex.WaitOne(1800000) } catch [System.Threading.AbandonedMutexException] { $labHeld = $true }
    if (-not $labHeld) { throw 'LAB_SITE_BUSY' }
    $uuid = Get-Scalar 'SELECT @@server_uuid AS ksval;'
    if ($uuid -ne '1167ebae-d0c0-11f1-b348-9c7bef540c10') { throw 'NOT_THE_LAB' }
    # Un nome temporaneo rimasto da una prova interrotta (uno solo): si rimette a posto prima di partire.
    $left = Get-Scalar 'SELECT IFNULL(GROUP_CONCAT(table_name), '''') AS ksval FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name LIKE ''export\_amazon\_ks%'';'
    $have = Get-Scalar 'SELECT COUNT(*) AS ksval FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=''export_amazon'';'
    if ($left -ne '' -and $have -eq '0' -and $left -notmatch ',') { $null = Invoke-Sql ('RENAME TABLE ' + $left + ' TO export_amazon;') -Write; $have = '1'; $left = '' }
    if ($have -ne '1' -or $left -ne '') { throw 'EXPORT_AMAZON_TABLE_STATE_UNEXPECTED' }
    $rows = Get-Scalar 'SELECT COUNT(*) AS ksval FROM export_amazon;'
    if ($rows -ne '1') { throw ('EXPORT_AMAZON_ROW_COUNT_' + $rows) }
    $script:origVb = [IO.File]::ReadAllBytes((Join-Path $SitePath $vbFile))
    $script:origAspx = [IO.File]::ReadAllBytes((Join-Path $SitePath $aspxFile))
    # Salvataggio delle sole colonne che la pagina vecchia scrive (valori in esadecimale, mai in output).
    $row0 = @{
        S = (Get-Scalar 'SELECT IFNULL(HEX(stato_esecuzione), ''NULL'') AS ksval FROM export_amazon;')
        A = (Get-Scalar 'SELECT avvio_forzato_aggiornamento AS ksval FROM export_amazon;')
        N = (Get-Scalar 'SELECT avvio_forzato_nuovo_inserimento AS ksval FROM export_amazon;')
        H = (Get-RowHash)
    }
    $unref = @(Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -in '.aspx', '.master', '.ascx', '.asax' } | Where-Object { (Get-Text ([IO.File]::ReadAllBytes($_.FullName))) -match 'import_amazon' })
    Check ($unref.Count -eq 0) 'import_amazon.asp.vb non e CodeFile ne riferito da nessuna pagina (residuo non compilato)' 'src'
    Check ((Get-Text $repoAspx).Trim() -ceq '<%@ Page Language="VB" AutoEventWireup="false" CodeFile="export_amazon.aspx.vb" Inherits="export_amazon" %>') 'export_amazon.aspx e solo la direttiva (nessun markup)' 'src'

    if (-not $Baseline) { Deploy-Repo } else { Wait-Site }
    $imp = Invoke-Probe 'GET' '' '' '/import_amazon.asp.vb'
    Check ($imp.Status -ne 200 -and $imp.Body -notmatch 'Partial Class') ('GET /import_amazon.asp.vb non serve il sorgente (stato ' + $imp.Status + ')')
    $src = Get-Text $repoVb
    Run-Cases $src
    if ($e2e.Count -gt 0) { $exit = 1 }

    # --- Mutanti: ognuno deve far fallire almeno un controllo; si contano separatamente i morti per sorgente e per HTTP ---
    if (-not $SkipMutants -and -not $Baseline -and $exit -eq 0) {
        $anchor = '        r.Write("Servizio non disponibile")'
        $cs = 'System.Configuration.ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString'
        $mutants = [ordered]@{
            'M1_STATUS_200'        = @{ From = 'r.StatusCode = 410'; To = 'r.StatusCode = 200' }
            'M2_NO_STORE_REMOVED'  = @{ From = '        r.Cache.SetNoStore()'; To = '        r.Cache.SetCacheability(System.Web.HttpCacheability.Private)' }
            'M3_TEXT_CHANGED'      = @{ From = 'r.Write("Servizio non disponibile")'; To = 'r.Write("Servizio non disponibile.")' }
            'M4_ECHO_PARAM'        = @{ From = $anchor; To = ($anchor + "`r`n" + '        r.Write(context.Request.QueryString("statoesecuzione"))') }
            'M5_READ_TABLE_SILENT' = @{ From = $anchor; To = ($anchor + "`r`n" + '        Try' + "`r`n" + '            Using c As New MySql.Data.MySqlClient.MySqlConnection(' + $cs + ')' + "`r`n" + '                c.Open()' + "`r`n" + '                Using m As New MySql.Data.MySqlClient.MySqlCommand("select * from export_amazon", c)' + "`r`n" + '                    m.ExecuteReader().Close()' + "`r`n" + '                End Using' + "`r`n" + '            End Using' + "`r`n" + '        Catch' + "`r`n" + '        End Try') }
            'M6_WRITE_CONCAT'      = @{ From = $anchor; To = ($anchor + "`r`n" + '        Using c As New MySql.Data.MySqlClient.MySqlConnection(' + $cs + ')' + "`r`n" + '            c.Open()' + "`r`n" + '            Using m As New MySql.Data.MySqlClient.MySqlCommand("UPDATE export_amazon SET stato_esecuzione = ''" & context.Request.QueryString("statoesecuzione") & "''", c)' + "`r`n" + '                m.ExecuteNonQuery()' + "`r`n" + '            End Using' + "`r`n" + '        End Using') }
            'M7_REQUEST_READ'      = @{ From = $anchor; To = ($anchor + "`r`n" + '        Dim ignored As String = context.Request.QueryString("fase")') }
            'M8_REDIRECT'          = @{ From = $anchor; To = ($anchor + "`r`n" + '        r.Redirect("~/404.aspx")') }
            'M9_CONTENT_TYPE_HTML' = @{ From = 'r.ContentType = "text/plain"'; To = 'r.ContentType = "text/html"' }
            'M10_OVERRIDE_REMOVED' = @{ From = 'Public Overrides Sub ProcessRequest(ByVal context As System.Web.HttpContext)'; To = 'Public Sub ProcessRequestX(ByVal context As System.Web.HttpContext)' }
            'M11_APPSETTINGS'      = @{ From = $anchor; To = ($anchor + "`r`n" + '        Dim cfg As String = System.Configuration.ConfigurationManager.AppSettings("x")') }
        }
        $killed = 0; $total = 0; $bySrc = 0; $byHttp = 0
        foreach ($id in $mutants.Keys) {
            if ($MutantFilter -ne '' -and $id -notmatch $MutantFilter) { continue }
            $mu = $mutants[$id]
            $total++
            if (-not $src.Contains($mu.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $exit = 1; continue }
            $before = $e2e.Count; $s0 = $script:failSrc; $h0f = $script:failHttp
            try {
                $mText = $src.Replace($mu.From, $mu.To)
                Set-Mutant $mText
                # un mutante che non compila da 500 (reindirizzo alla pagina di errore): ucciderebbe per il motivo sbagliato
                $v = Invoke-Probe 'GET' '' ''
                $loc = ''; $m = [regex]::Match($v.Headers, '(?im)^Location:\s*(\S+)'); if ($m.Success) { $loc = $m.Groups[1].Value }
                if ($loc -match '(?i)InternalError|GenericErrorPage') { Write-Host ('  FAIL ' + $id + ' mutante NON VALIDO (non compila o va in errore: ' + $v.Status + ' ' + $loc + ')'); $exit = 1; continue }
                Run-Cases $mText
                $dSrc = $script:failSrc - $s0; $dHttp = $script:failHttp - $h0f
                if (($dSrc + $dHttp) -gt 0) {
                    $killed++; if ($dSrc -gt 0) { $bySrc++ }; if ($dHttp -gt 0) { $byHttp++ }
                    Write-Host ('  ok   mutante ' + $id + ' ucciso (sorgente ' + $dSrc + ', HTTP ' + $dHttp + ')')
                } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $exit = 1 }
                # i FAIL dei mutanti non sono fallimenti del test: li riporto fuori dall'elenco
                while ($e2e.Count -gt $before) { $e2e.RemoveAt($e2e.Count - 1) }
                $script:failSrc = $s0; $script:failHttp = $h0f
            } finally {
                # un mutante che scrive tocca la riga del LAB: la si rimette com'era prima del test
                if ((Get-RowHash) -ne $row0.H) { Restore-Row $row0 }
            }
        }
        Write-Host ('  mutanti uccisi ' + $killed + '/' + $total + ' (di cui visti dal sorgente ' + $bySrc + ', visti dal comportamento HTTP ' + $byHttp + ')')
    }
} catch {
    Write-Host ('  FAIL ' + $_.Exception.Message); $exit = 1
} finally {
    # si ripristina SOLO cio che questo processo ha scritto, e solo dopo aver preso il mutex
    if ($labHeld -and $script:siteTouched) {
        try { Restore-Site } catch { Write-Host ('  ATTENZIONE: ripristino del sito non riuscito: ' + $_.Exception.Message); $exit = 1 }
    }
    # La pagina vecchia (e i mutanti che scrivono) cambiano la riga: la si rimette com'era.
    if ($labHeld -and $null -ne $row0) {
        try {
            if ((Get-RowHash) -ne $row0.H) {
                Restore-Row $row0
                Write-Host ('  nota: la riga export_amazon del LAB e stata ripristinata (impronta uguale: ' + ((Get-RowHash) -eq $row0.H) + ')')
            }
        } catch { Write-Host ('  ATTENZIONE: ripristino della riga non riuscito: ' + $_.Exception.Message); $exit = 1 }
    }
    if ($labHeld) { try { $siteMutex.ReleaseMutex() } catch { } }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($e2e.Count -gt 0) { $exit = 1 }
if ($exit -eq 0) { Write-Host 'EXPORT_AMAZON PASS' } else { Write-Host 'EXPORT_AMAZON FAIL' }
exit $exit
