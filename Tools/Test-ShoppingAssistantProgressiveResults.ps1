[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PlaywrightModulePath,
    [Parameter(Mandatory=$true)][string]$BrowserExecutable,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if(-not $output.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or $output -eq $tempBase.TrimEnd('\')){throw 'EVIDENCE_MUST_BE_SCOPED_TEMP_DIRECTORY'}
if(-not (Test-Path -LiteralPath $PlaywrightModulePath) -or -not (Test-Path -LiteralPath $BrowserExecutable)){throw 'EXISTING_BROWSER_RUNTIME_REQUIRED_NO_INSTALL'}
[void][IO.Directory]::CreateDirectory($output)
$payload=Join-Path $output 'server-payloads.json'
$serverLog=Join-Path $output 'server-tests.log'
& (Join-Path $PSScriptRoot 'Test-SearchSuggestCommercialContext.ps1') -GuidedPayloadPath $payload *> $serverLog
if(-not (Select-String -LiteralPath $serverLog -Pattern '^SEARCH_SUGGEST_SYNTHETIC_SUITE=PASS$' -Quiet)){throw 'COMMERCIAL_CONTRACT_SUITE_FAILED'}
$node=(Get-Command node -CommandType Application -ErrorAction Stop).Source
& $node (Join-Path $PSScriptRoot 'ShoppingAssistantProgressiveResults.test.js') $root $PlaywrightModulePath $BrowserExecutable $output $payload
if($LASTEXITCODE -ne 0){throw 'PROGRESSIVE_BROWSER_SUITE_FAILED'}
$journal=Get-Content -LiteralPath (Join-Path $output 'resource-journal.json') -Raw | ConvertFrom-Json
if(-not $journal.browserClosed){throw 'BROWSER_CLEANUP_NOT_ATTESTED'}
Write-Output 'SHOPPING_PROGRESSIVE_SUITE=PASS; HTTP_UPSTREAM=0; DATABASE_CONNECTIONS=0'
Write-Output 'OWN_BROWSER_CONTEXTS_CLOSED=PASS; EVIDENCE_RETAINED=YES; NO_SERVICE_STARTED'
