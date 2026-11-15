[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [string]$Reply,
    [ValidateSet('medium', 'high', 'xhigh')][string]$Effort = 'high',
    [int]$TimeoutMinutes = 20,
    [string]$Questions = ''
)

# Lancia la revisione ChatGPT (Codex CLI con login ChatGPT, SOLA LETTURA, nessuna API a consumo) su una cartella di scambio (.ai-review/<task>/) che contiene
# proposta.md e le prove numerate. Sostituisce gli script usa-e-getta: risolve il pacchetto per NOME ('OpenAI.Codex', non il glob, che trova anche i runtime),
# usa un prompt standard e uccide il processo oltre il timeout. Esce con 0 se la risposta e stata scritta, 1 altrimenti. Mai segreti, token o dati personali nella cartella.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.
# Uso:  powershell -NoProfile -File Tools\Invoke-KeepStoreCodexReview.ps1 -Folder .ai-review\<task> [-Effort xhigh]   (in background, ~6-10 minuti)

$ErrorActionPreference = 'Stop'
$dir = (Resolve-Path -LiteralPath $Folder).Path
if (-not (Test-Path -LiteralPath (Join-Path $dir 'proposta.md'))) { throw 'PROPOSTA_MD_MISSING_IN_FOLDER' }
if (-not $Reply) { $Reply = Join-Path $dir 'risposta-chatgpt.txt' }
$pkg = @(Get-AppxPackage -Name 'OpenAI.Codex')
if ($pkg.Count -eq 0) { Write-Output 'CODEX_NON_DISPONIBILE'; exit 1 }
$exe = Join-Path $pkg[0].InstallLocation 'app\resources\codex.exe'
if (-not (Test-Path -LiteralPath $exe)) { Write-Output 'CODEX_EXE_NOT_FOUND'; exit 1 }
if (Test-Path -LiteralPath $Reply) { Remove-Item -LiteralPath $Reply -Force }
$stderr = [IO.Path]::GetTempFileName()
$stdout = [IO.Path]::GetTempFileName()

$prompt = 'Sei un revisore tecnico indipendente e avversariale (esperto del dominio del task: WebForms/VB.NET, CSS, accessibilita, ecommerce mobile-first, sicurezza), in modalita approfondita. ' +
    'Leggi proposta.md e i file della cartella corrente (sola lettura, non modificare nulla, non usare la rete). Rispondi in italiano, in modo verificabile, in quest ordine: ' +
    '1) diagnosi indipendente delle domande della proposta PRIMA di giudicare la soluzione (cita file e riga); ' +
    '2) verdetto su ogni affermazione e su ogni punto della soluzione: CONFERMATO / SMENTITO / NON VERIFICABILE, con la prova; controlla specificita, ordine, chiamanti e casi limite riga per riga; ' +
    '3) che cosa nessuno ha visto: classi di casi, stati, regressioni, falsi positivi o negativi dell oracolo di test, mutazioni mancanti; ' +
    '4) difetti classificati BLOCCANTE / CONSIGLIATO / OPZIONALE, ciascuno con il caso concreto che lo fa fallire e la correzione minima. ' +
    'Non ripetere la proposta: il tuo valore e contraddire con prove e cercare cio che manca. Se un fatto non e verificabile dai file, dillo e indica la misura che lo risolverebbe. Sii conciso (sotto 2000 parole).'
if ($Questions) { $prompt += ' Domande specifiche del task: ' + $Questions }

$argString = 'exec --sandbox read-only --ephemeral --skip-git-repo-check -C "' + $dir + '" -c model_reasoning_effort=' + $Effort + ' -o "' + $Reply + '" "' + $prompt.Replace('"', "'") + '"'
$p = Start-Process -FilePath $exe -ArgumentList $argString -NoNewWindow -PassThru -RedirectStandardError $stderr -RedirectStandardOutput $stdout
if (-not $p.WaitForExit($TimeoutMinutes * 60 * 1000)) {
    try { $p.Kill() } catch { }
    Write-Output ('CODEX_TIMEOUT_' + $TimeoutMinutes + 'MIN')
    exit 1
}
Remove-Item -LiteralPath $stderr, $stdout -Force -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $Reply) -and ((Get-Item -LiteralPath $Reply).Length -gt 200)) {
    Write-Output ('CODEX_REVIEW_OK reply=' + $Reply + ' bytes=' + (Get-Item -LiteralPath $Reply).Length)
    exit 0
}
Write-Output 'CODEX_REVIEW_EMPTY_REPLY'
exit 1
