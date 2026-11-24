[CmdletBinding()]
param([switch]$SkipMutants)

# PAYPAL-EXPIRED-ORDER-RETRY-1A. Un ordine PayPal abbandonato (tentativo locale CREATED, mai approvato) dopo 180 minuti di inattivita si puo sostituire con un nuovo
# tentativo. Il denaro e protetto da due invarianti del sito (la capture esiste solo per il tentativo corrente, sotto lock; intent CAPTURE senza cattura automatica),
# non dalla finestra. Parti: (1) tabella della politica compilata da sola (stato locale x remoto x scaduto x origine x capture) e mutanti; (2) confine di 180 minuti
# sull'orologio del DATABASE (LAB, sola lettura) e colonna UpdatedAt con aggiornamento automatico; (3) pin sul testo di repository e pagina (eta controllata SOTTO
# lock, politica rivalutata, nessuna rotazione per i lanci dal carrello) con mutanti sul testo. Limite dichiarato: nessun test end-to-end con interleaving su
# database ne PayPal vero. Solo ASCII (Windows PowerShell 5.1).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$fail = New-Object Collections.Generic.List[string]
function Check([bool]$ok, [string]$name) { if ($ok) { Write-Host ('  ok   ' + $name) } else { Write-Host ('  FAIL ' + $name); $fail.Add($name) } }
function Read-Repo([string]$rel) { return [IO.File]::ReadAllText((Join-Path $root $rel), $utf8) }

# ---------------- 1. Politica compilata da sola ----------------
$probeCode = @"
Option Strict On
Option Explicit On
Public Class PolicyProbe
    Public Function S(ByVal origin As String, ByVal local As String, ByVal remote As String, ByVal capture As String, ByVal expired As Boolean) As Boolean
        Return PayPalAttemptPolicy.MaySupersede(origin, local, remote, capture, expired)
    End Function
    Public Function Minutes() As Integer
        Return PayPalAttemptPolicy.ExpiryMinutes
    End Function
End Class
"@
function New-Probe([string]$src) {
    $cp = New-Object CodeDom.Compiler.CompilerParameters
    $cp.GenerateInMemory = $true
    $cp.CompilerOptions = '/optionInfer+ /optionExplicit+ /optionStrict+ /imports:Microsoft.VisualBasic'
    @('System.dll', 'System.Core.dll') | ForEach-Object { [void]$cp.ReferencedAssemblies.Add($_) }
    $res = (New-Object Microsoft.VisualBasic.VBCodeProvider).CompileAssemblyFromSource($cp, [string[]]@($src, $probeCode))
    if ($res.Errors.HasErrors) { throw ('POLICY_COMPILE ' + (($res.Errors | Select-Object -First 3 | ForEach-Object { $_.ErrorText }) -join ' | ')) }
    return [Activator]::CreateInstance($res.CompiledAssembly.GetType('PolicyProbe', $true))
}
# origine, locale, remoto, capture, scaduto, atteso, nome
$table = @(
    @('INTERNO', 'CREATED', 'CREATED', '', $true, $true, 'scaduto, CREATED/CREATED: si sostituisce'),
    @('INTERNO', 'CREATED', 'PAYER_ACTION_REQUIRED', '', $true, $true, 'scaduto, remoto PAYER_ACTION_REQUIRED: si sostituisce'),
    @('INTERNO', ' created ', 'created', '', $true, $true, 'spazi e maiuscole irrilevanti'),
    @('INTERNO', 'CREATED', 'CREATED', '', $false, $false, 'NON scaduto: resta lo stesso ordine (come oggi)'),
    @('INTERNO', 'CREATED', 'APPROVED', '', $true, $false, 'remoto APPROVED: mai'),
    @('INTERNO', 'CREATED', 'COMPLETED', '', $true, $false, 'remoto COMPLETED: mai'),
    @('INTERNO', 'CREATED', 'PENDING', '', $true, $false, 'remoto PENDING: mai'),
    @('INTERNO', 'CREATED', 'CREATED', 'COMPLETED', $true, $false, 'capture completata: mai'),
    @('INTERNO', 'CREATED', 'CREATED', 'PENDING', $true, $false, 'capture in sospeso: mai'),
    @('INTERNO', 'CAPTURING', 'CREATED', '', $true, $false, 'locale CAPTURING: mai'),
    @('INTERNO', 'AUTHORIZED', 'CREATED', '', $true, $false, 'locale AUTHORIZED: mai (solo CREATED scade)'),
    @('INTERNO', 'UNKNOWN', 'CREATED', '', $true, $false, 'locale UNKNOWN: mai'),
    @('INTERNO', 'CREATED', '', '', $true, $false, 'remoto sconosciuto: mai'),
    @('WEB', 'CREATED', 'CREATED', '', $true, $false, 'origine WEB: mai'),
    @('', 'CREATED', 'CREATED', '', $true, $false, 'origine vuota: mai'),
    @('INTERNO', 'CREATED', 'VOIDED', '', $false, $true, 'regola esistente: remoto VOIDED'),
    @('INTERNO', 'CANCELED', 'CREATED', '', $false, $true, 'regola esistente: locale CANCELED + remoto CREATED'),
    @('INTERNO', 'FAILED', 'CREATED', '', $false, $true, 'regola esistente: locale FAILED + remoto CREATED'),
    @('INTERNO', 'CANCELED', 'APPROVED', '', $false, $false, 'regola esistente: APPROVED mai')
)
function Test-Table($probe) {
    $bad = New-Object Collections.Generic.List[string]
    foreach ($r in $table) { $got = $null; try { $got = [bool]$probe.S($r[0], $r[1], $r[2], $r[3], [bool]$r[4]) } catch { $got = 'EXC' }; if ($got -ne $r[5]) { $bad.Add($r[6] + ' (visto ' + $got + ')') } }
    if ([int]$probe.Minutes() -ne 180) { $bad.Add('finestra diversa da 180 minuti') }
    return $bad.ToArray()
}
$policyRel = 'App_Code\PayPalAttemptPolicy.vb'
$policySrc = Read-Repo $policyRel
$probe = $null
try { $probe = New-Probe $policySrc } catch { Check $false ('politica compilabile: ' + $_.Exception.Message) }
if ($null -ne $probe) {
    $bad = @(Test-Table $probe)
    foreach ($b in $bad) { Write-Host ('    ' + $b) }
    Check ($bad.Count -eq 0) ('politica: ' + $table.Count + ' casi della tabella e finestra di 180 minuti')
    if (-not $SkipMutants) {
        $mut = [ordered]@{
            'P1_EXPIRY_IGNORED'   = @{ From = 'If expired AndAlso previous = "CREATED"'; To = 'If previous = "CREATED"' }
            'P2_ANY_LOCAL_STATE'  = @{ From = 'previous = "CREATED" AndAlso (remote = "CREATED"'; To = 'previous <> "CAPTURING" AndAlso (remote = "CREATED"' }
            'P3_REMOTE_IGNORED'   = @{ From = 'AndAlso (remote = "CREATED" OrElse remote = "PAYER_ACTION_REQUIRED") Then Return True ''EXPIRED_RULE'; To = 'Then Return True ''EXPIRED_RULE' }
            'P4_WINDOW_SHORTER'   = @{ From = 'ExpiryMinutes As Integer = 180'; To = 'ExpiryMinutes As Integer = 60' }
            'P5_ORIGIN_IGNORED'   = @{ From = 'If Not String.Equals(orderOrigin, "INTERNO", StringComparison.OrdinalIgnoreCase) Then Return False'; To = '' }
        }
        $kill = 0
        foreach ($id in $mut.Keys) {
            $m = $mut[$id]
            if (-not $policySrc.Contains($m.From)) { Write-Host ('  FAIL ' + $id + ': punto di mutazione non trovato'); $fail.Add($id); continue }
            $dead = $false; try { $dead = (@(Test-Table (New-Probe ($policySrc.Replace($m.From, $m.To)))).Count -gt 0) } catch { $dead = $true }
            if ($dead) { $kill++; Write-Host ('  ok   mutante ' + $id + ' ucciso') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $fail.Add($id) }
        }
        Write-Host ('  mutanti della politica uccisi ' + $kill + '/' + $mut.Count)
    }
}

# ---------------- 2. Orologio e colonna del database (LAB, sola lettura) ----------------
$utf8b = $utf8
$tmp = Join-Path $env:TEMP ('ks-ppexp-' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    . (Join-Path $root 'Tools\KeepStoreLabSiteHttp.ps1')
    $extra = Get-Scalar "SELECT EXTRA AS ksval FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='paypal_checkout_transazioni' AND COLUMN_NAME='UpdatedAt';"
    Check ($extra -match '(?i)on update CURRENT_TIMESTAMP') 'database: UpdatedAt si aggiorna da sola a ogni modifica della riga (letto dal LAB)'
    function Age-Test([int]$seconds) { return (Get-Scalar ("SELECT (TIMESTAMPDIFF(MINUTE, TIMESTAMP(CURRENT_TIMESTAMP - INTERVAL $seconds SECOND), CURRENT_TIMESTAMP) >= 180) AS ksval;")) }
    $a = Age-Test (179 * 60 + 59); $b = Age-Test (180 * 60); $c = Age-Test (181 * 60)
    Check ($a -eq '0' -and $b -eq '1' -and $c -eq '1') ('database: confine di eta, 179 min 59 s = no, 180 min = si, 181 min = si (visto ' + $a + $b + $c + ')')
} catch { Check $false ('prova sul database: ' + $_.Exception.Message) } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------- 3. Pin sul testo di repository e pagina ----------------
function Test-Pins([string]$repo, [string]$page) {
    $bad = New-Object Collections.Generic.List[string]
    $i = $repo.IndexOf('Public Function StartNextAttempt')
    $body = if ($i -ge 0) { $repo.Substring($i, [math]::Min(5200, $repo.Length - $i)) } else { '' }
    if ($body -notmatch 'allowExpired') { $bad.Add('StartNextAttempt non ha il parametro allowExpired') }
    $sel = [regex]::Match($body, 'SELECT Id,Stato,PayPalOrderId[^"]*FOR UPDATE')
    if (-not $sel.Success -or $sel.Value -notmatch 'TIMESTAMPDIFF\(MINUTE,UpdatedAt,CURRENT_TIMESTAMP\)') { $bad.Add('l''eta non e letta con l''orologio del database nella stessa SELECT ... FOR UPDATE') }
    if ($body -match 'CreatedAt' -and $body -match 'TIMESTAMPDIFF\(MINUTE,CreatedAt') { $bad.Add('l''eta usa CreatedAt (sbagliato: la riga puo essere riusata ore dopo)') }
    if ([regex]::Matches($body, 'MaySupersede\(').Count -lt 2) { $bad.Add('la politica non e rivalutata sotto lock') }
    $j = $page.IndexOf('IsTrustedApprovalUrl(details.Snapshot.ApprovalUrl)')
    $seg = if ($j -ge 0) { $page.Substring($j, [math]::Min(1300, $page.Length - $j)) } else { '' }
    if ($seg -notmatch 'Not viaLaunch') { $bad.Add('la rotazione non esclude i lanci dal carrello') }
    $iRot = $seg.IndexOf('StartNextAttempt('); $iRed = $seg.IndexOf('RedirectTerminal(details.Snapshot.ApprovalUrl)')
    if ($iRot -lt 0 -or $iRed -lt 0 -or $iRot -gt $iRed) { $bad.Add('la rotazione deve essere tentata PRIMA del rimando al vecchio link') }
    if ($seg -notmatch 'StartNextAttempt\(doc, cfg, tx, details\.Snapshot, True\)') { $bad.Add('la pagina non chiede la rotazione per scadenza') }
    return $bad.ToArray()
}
$repoText = Read-Repo 'App_Code\PayPalCheckoutRepository.vb'; $pageText = Read-Repo 'paypalcheckout.aspx.vb'
$pb = @(Test-Pins $repoText $pageText)
foreach ($b in $pb) { Write-Host ('    ' + $b) }
Check ($pb.Count -eq 0) 'pin: eta sotto lock con orologio del database, politica rivalutata, pagina senza rotazione per i lanci dal carrello'
if (-not $SkipMutants) {
    $tm = [ordered]@{
        'T1_AGE_OUTSIDE_LOCK' = @{ Where = 'repo'; From = 'TIMESTAMPDIFF(MINUTE,UpdatedAt,CURRENT_TIMESTAMP)'; To = '0' }
        'T2_CREATEDAT'        = @{ Where = 'repo'; From = 'TIMESTAMPDIFF(MINUTE,UpdatedAt,CURRENT_TIMESTAMP)'; To = 'TIMESTAMPDIFF(MINUTE,CreatedAt,CURRENT_TIMESTAMP)' }
        'T3_LAUNCH_ROTATES'   = @{ Where = 'page'; From = 'Not viaLaunch'; To = 'True' }
    }
    $k = 0
    foreach ($id in $tm.Keys) {
        $m = $tm[$id]; $src = if ($m.Where -eq 'repo') { $repoText } else { $pageText }
        if (-not $src.Contains($m.From)) { Write-Host ('  FAIL ' + $id + ': punto non trovato'); $fail.Add($id); continue }
        $r2 = if ($m.Where -eq 'repo') { $src.Replace($m.From, $m.To) } else { $repoText }; $p2 = if ($m.Where -eq 'page') { $src.Replace($m.From, $m.To) } else { $pageText }
        if (@(Test-Pins $r2 $p2).Count -gt 0) { $k++; Write-Host ('  ok   mutante ' + $id + ' ucciso') } else { Write-Host ('  FAIL mutante ' + $id + ' sopravvissuto'); $fail.Add($id) }
    }
    Write-Host ('  mutanti sul testo uccisi ' + $k + '/' + $tm.Count)
}
if ($fail.Count -eq 0) { Write-Host 'PAYPAL_EXPIRED PASS'; exit 0 } else { Write-Host 'PAYPAL_EXPIRED FAIL'; exit 1 }
