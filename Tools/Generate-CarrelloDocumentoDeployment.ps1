[CmdletBinding()]
param(
    [string]$HistoricalCreatePath = 'C:\Temp\Carrello_Documento_STORICA_TARGET.sql',
    [string]$OutputRoot = 'C:\Temp\KeepStore_Carrello_Documento_Atomic_Deployment_Germano_FINAL'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$migrationRoot = Join-Path $repo 'Database Taikun\Migrations'
$historicalFingerprint = '6689fd5206acabd453c5f631d52e08beaa4e9c6025f70fd9894034b5fd6122d2'
$newFingerprint = '6d50508d402d4f35e5a8918825a5e6b66b5cfdcf5e4cf5fc41697b5535b6af23'
$placeholder = '__KEEPSTORE_HISTORICAL_DEFINER__'

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $HistoricalCreatePath)) { throw 'backup storico assente' }
$historical = [IO.File]::ReadAllText($HistoricalCreatePath)
$normalized = $historical -replace "`r`n", "`n" -replace "`r", "`n"
if (([regex]::Matches($normalized, '(?i)\bCREATE\s+(?:DEFINER\s*=\s*[^\s]+\s+)?PROCEDURE\b')).Count -ne 1) { throw 'CREATE PROCEDURE non unica' }
if (([regex]::Matches($normalized, '(?i)\b(DROP|ALTER|GRANT|CREATE\s+USER)\b')).Count -ne 0) { throw 'istruzione non consentita nel backup' }
$bodyMatch = [regex]::Match($normalized, '(?is)\bBEGIN[\s\S]*?END\s*;?\s*$')
if (-not $bodyMatch.Success) { throw 'corpo storico assente' }
$digest = [Security.Cryptography.SHA256]::Create()
try { $bodyHash = (-join ($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($bodyMatch.Value)) | ForEach-Object { $_.ToString('x2') })) } finally { $digest.Dispose() }
if ($bodyHash -ne $historicalFingerprint) { throw 'fingerprint storica non corrispondente' }
$definerMatch = [regex]::Match($normalized, '(?i)^CREATE\s+DEFINER\s*=\s*(?<d>[^\s]+)\s+PROCEDURE')
if (-not $definerMatch.Success) { throw 'DEFINER assente' }
$definer = $definerMatch.Groups['d'].Value

$files = [ordered]@{
    '00_preflight.sql' = '20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_preflight.sql'
    '02_verify.sql' = '20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_verify.sql'
    '03_rollback_preflight.sql' = '20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_rollback_preflight.sql'
}
if (Test-Path -LiteralPath $OutputRoot) { Remove-Item -LiteralPath $OutputRoot -Recurse -Force }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
foreach ($name in $files.Keys) {
    $text = Get-Content -Raw (Join-Path $migrationRoot $files[$name])
    Write-Utf8 (Join-Path $OutputRoot $name) ($text.Replace('__KEEPSTORE_NEW_FINGERPRINT__', $newFingerprint))
}
$forward = Get-Content -Raw (Join-Path $migrationRoot '20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_forward.sql')
$rollback = Get-Content -Raw (Join-Path $migrationRoot '20260911_ORDER_INVENTORY_ATOMIC_RESERVATION_1A_rollback.sql')
if (([regex]::Matches($forward, [regex]::Escape($placeholder))).Count -ne 1) { throw 'placeholder forward non valido' }
if (([regex]::Matches($rollback, [regex]::Escape($placeholder))).Count -ne 1) { throw 'placeholder rollback non valido' }
Write-Utf8 (Join-Path $OutputRoot '01_forward.sql') ($forward.Replace($placeholder, $definer))
Write-Utf8 (Join-Path $OutputRoot '04_rollback.sql') ($rollback.Replace($placeholder, $definer))
$readme = @(
    'KEEPSTORE — DEPLOYMENT GUIDATO CARRELLO_DOCUMENTO WEBV1', '',
    'Target esplicito: database taikun.',
    "Eseguire esclusivamente nell'ordine indicato e dopo la review.", '',
    '1. 00_preflight.sql: sola lettura; tutti i controlli bloccanti devono essere OK.',
    '2. Inviare a ChatGPT i soli risultati sanitizzati e attendere autorizzazione.',
    '3. 01_forward.sql: eseguire una sola volta dopo autorizzazione.',
    '4. Chiudere la connessione SQLyog e aprirne una nuova.',
    '5. 02_verify.sql: verificare tutti gli OK.', '',
    'Fermarsi per qualsiasi STOP o errore SQL. Non ripetere il forward senza analisi.',
    'Rollback soltanto dopo autorizzazione: 03_rollback_preflight.sql e poi 04_rollback.sql.',
    'Non eseguire ordini, pagamenti, email o gateway. Non rendere pronta o mergiare la PR.', '',
    "Fingerprint nuova laboratorio: $newFingerprint"
) -join "`n"
Write-Utf8 (Join-Path $OutputRoot 'README_OPERATIVO.txt') $readme
$digest = [Security.Cryptography.SHA256]::Create()
try {
    $lines = Get-ChildItem -LiteralPath $OutputRoot -File | Sort-Object Name | ForEach-Object {
        $h = (-join ($digest.ComputeHash([IO.File]::ReadAllBytes($_.FullName)) | ForEach-Object { $_.ToString('x2') }))
        "$h  $($_.Name)"
    }
} finally { $digest.Dispose() }
Write-Utf8 (Join-Path $OutputRoot 'SHA256SUMS.txt') (($lines -join "`n") + "`n")
$zip = "$OutputRoot.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $OutputRoot '*') -DestinationPath $zip -CompressionLevel Optimal
Remove-Item -LiteralPath $HistoricalCreatePath -Force
Write-Output 'REV14_FINAL_COMPLETED'
