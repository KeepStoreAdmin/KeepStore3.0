Set-StrictMode -Version 2.0

function Import-KeepStoreConfigurationReader {
    [CmdletBinding()]
    param([string]$ReaderSource = (Join-Path $PSScriptRoot 'KeepStoreConfigurationReader.vb'))
    if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
        throw 'DBCFG_WINDOWS_POWERSHELL_51_REQUIRED'
    }
    if ('KeepStoreConfigurationReader' -as [type]) { return }
    $provider = $null
    try {
        $sourcePath = [IO.Path]::GetFullPath($ReaderSource)
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw 'DBCFG_READER_SOURCE_MISSING' }
        $assemblyPath = Join-Path (Split-Path -Parent (Split-Path -Parent $sourcePath)) 'bin\MySql.Data.dll'
        if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) { throw 'DBCFG_DATABASE_PROVIDER_MISSING' }
        [Reflection.Assembly]::LoadFrom($assemblyPath) | Out-Null
        Add-Type -AssemblyName System.Configuration
        Add-Type -AssemblyName System.Web
        $provider = New-Object Microsoft.VisualBasic.VBCodeProvider
        $options = New-Object CodeDom.Compiler.CompilerParameters
        $options.GenerateInMemory = $true
        $options.CompilerOptions = '/optionexplicit+ /optionstrict+'
        foreach ($reference in @('System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Xml.dll', 'System.Configuration.dll', 'System.Web.dll', $assemblyPath)) {
            [void]$options.ReferencedAssemblies.Add($reference)
        }
        $result = $provider.CompileAssemblyFromFile($options, $sourcePath)
        if ($result.Errors.HasErrors) { throw 'DBCFG_READER_COMPILATION_FAILED' }
        $result.CompiledAssembly | Out-Null
    } catch {
        throw 'DBCFG_READER_LOAD_FAILED'
    } finally {
        if ($provider) { $provider.Dispose() }
    }
}
