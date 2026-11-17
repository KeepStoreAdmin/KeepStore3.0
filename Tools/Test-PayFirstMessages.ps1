[CmdletBinding()]
param([switch]$SkipMutations)

# PAYPAL-RESUBMIT-WORDING-1A - i messaggi che il pay-first mostra al cliente non devono promettere cio che il flusso non fa.
# Fatto verificato sul codice (PayPalPayFirst.vb, ordine.aspx.vb): dopo "sessione di conferma non valida" (Resubmit) o "carrello cambiato" (Changed) il cliente
# conferma di nuovo dal carrello con una NUOVA bozza: parte una nuova approvazione PayPal (nuova autorizzazione), mai "nessun nuovo pagamento"; la vecchia
# autorizzazione non viene annullata subito (si libera piu tardi con la pulizia). Un'autorizzazione e una riserva di fondi: nessun importo e addebitato.
# Oracolo: il VERO elenco delle costanti Msg* letto da App_Code/PayPalPayFirst.vb; Resubmit e Changed dicono che occorre approvare di nuovo il pagamento e che
# nessun importo e addebitato, e nessun messaggio contiene le promesse false. Mutazioni su copie in memoria. Solo ASCII: Windows PowerShell 5.1.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Read-Repo([string]$rel) { return (Norm ([IO.File]::ReadAllText((Join-Path $repoRoot $rel), [Text.Encoding]::UTF8))) }
function Assert-Source([bool]$condition, [string]$code) { if (-not $condition) { throw $code }; Write-Output ('PASS ' + $code) }
function Mutate-Text([string]$text, [string]$old, [string]$new, [string]$code) {
    $out = $text.Replace($old, $new)
    if ($out -eq $text) { throw ('MUTATION_NOT_APPLIED=' + $code) }
    return $out
}
function Assert-Detected([bool]$stillPasses, [string]$code) { if ($stillPasses) { throw ('MUTATION_NOT_DETECTED=' + $code) }; Write-Output ('PASS MUTATION_DETECTED ' + $code) }

$source = Read-Repo 'App_Code/PayPalPayFirst.vb'
function Get-Messages([string]$text) {
    $found = [ordered]@{}
    foreach ($m in [regex]::Matches($text, '(?m)^\s*Public Const (Msg\w+) As String = "((?:[^"]|"")*)"\s*$')) { $found[$m.Groups[1].Value] = $m.Groups[2].Value.Replace('""', '"') }
    return $found
}
function Test-Messages([string]$text) {
    $msg = Get-Messages $text
    if ($msg.Count -ne 7) { return $false }
    foreach ($k in @('MsgNotStarted', 'MsgCanceled', 'MsgExpired', 'MsgBusy', 'MsgManual', 'MsgChanged', 'MsgResubmit')) { if (-not $msg.Contains($k)) { return $false } }
    foreach ($k in $msg.Keys) {
        $t = $msg[$k]
        if ($t -match '[^\x20-\x7E]') { return $false }
        if ($t -match '(?i)non ti verra chiesto|nessun nuovo pagamento|viene annullata|viene annullato|rimborsat') { return $false }
    }
    foreach ($k in @('MsgChanged', 'MsgResubmit')) {
        if ($msg[$k] -notmatch 'approvare di nuovo il pagamento') { return $false }
        if ($msg[$k] -notmatch 'Nessun importo e stato addebitato') { return $false }
        if ($msg[$k] -notmatch "l'ordine non e stato creato") { return $false }
    }
    return $true
}
Assert-Source (Test-Messages $source) 'P01_RESUBMIT_AND_CHANGED_SAY_THE_PAYMENT_MUST_BE_APPROVED_AGAIN_AND_PROMISE_NOTHING_FALSE'

if ($SkipMutations) { Write-Output 'MUTATIONS_SKIPPED'; exit 0 }
$msg = Get-Messages $source
$resubmit = $msg['MsgResubmit']; $changed = $msg['MsgChanged']
$mutants = @(
    @{ Id = 'M01_FALSE_PROMISE_BACK_IN_RESUBMIT'; Old = 'ti verra chiesto di approvare di nuovo il pagamento.'; New = 'non ti verra chiesto un nuovo pagamento.'; Target = $resubmit },
    @{ Id = 'M02_APPROVE_AGAIN_REMOVED_FROM_RESUBMIT'; Old = 'ti verra chiesto di approvare di nuovo il pagamento'; New = 'ti verra chiesto di confermare'; Target = $resubmit },
    @{ Id = 'M03_NO_CHARGE_STATEMENT_REMOVED_FROM_RESUBMIT'; Old = 'Nessun importo e stato addebitato'; New = 'Tutto a posto'; Target = $resubmit },
    @{ Id = 'M04_VOID_PROMISE_BACK_IN_CHANGED'; Old = 'Nessun importo e stato addebitato.'; New = 'Nessun importo e stato addebitato e l''autorizzazione precedente viene annullata.'; Target = $changed },
    @{ Id = 'M05_ORDER_NOT_CREATED_REMOVED_FROM_CHANGED'; Old = "l'ordine non e stato creato"; New = 'tutto ok'; Target = $changed },
    @{ Id = 'M06_ACCENT_IN_A_MESSAGE'; Old = 'non e stato creato'; New = 'non è stato creato'; Target = $resubmit }
)
foreach ($mu in $mutants) {
    $mutatedMessage = Mutate-Text $mu.Target $mu.Old $mu.New $mu.Id
    $mutatedSource = Mutate-Text $source $mu.Target $mutatedMessage $mu.Id
    Assert-Detected (Test-Messages $mutatedSource) $mu.Id
}
Write-Output ('PAYFIRST_MESSAGES_TEST_PASS mutants=' + $mutants.Count)
