# KeepStoreBrowserDriver - pilota minimo di Edge via Chrome DevTools Protocol, per le prove sul PC di sviluppo
# (Windows PowerShell 5.1, nessuna dipendenza: niente Node ne Playwright). Da includere con ". .\KeepStoreBrowserDriver.ps1".
#
# Sicurezza: la risoluzione dei domini e SEMPRE forzata a 127.0.0.1 con --host-resolver-rules, perche il file hosts del PC
# punta www.taikun.it e www.webaffare.it al server ONLINE. Nessun proxy, verifica TLS attiva, profilo temporaneo proprio.
# Solo ASCII: Windows PowerShell 5.1 legge i file senza BOM come ANSI.

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Web.Extensions
$script:KsEdgePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

function Start-KsBrowser {
    param(
        [Parameter(Mandatory = $true)][string[]]$LoopbackHosts,
        [int]$Width = 430, [int]$Height = 900, [switch]$Mobile,
        [string]$ExtraArgs = ''
    )
    if (-not (Test-Path -LiteralPath $script:KsEdgePath)) { throw 'EDGE_NOT_FOUND' }
    $profileDir = Join-Path ([IO.Path]::GetTempPath()) ('ks-edge-' + [Guid]::NewGuid().ToString('N'))
    $port = Get-Random -Minimum 20000 -Maximum 29000
    $rules = ($LoopbackHosts | ForEach-Object { 'MAP ' + $_ + ' 127.0.0.1' }) -join ', '
    $line = '--headless=new --disable-gpu --no-first-run --no-proxy-server "--host-resolver-rules=' + $rules + '" ' +
            '--remote-debugging-port=' + $port + ' --user-data-dir=' + $profileDir + ' --window-size=' + $Width + ',' + $Height + $(if ($ExtraArgs) { ' ' + $ExtraArgs } else { '' }) + ' about:blank'
    $null = Start-Process -FilePath $script:KsEdgePath -ArgumentList $line -WindowStyle Hidden -PassThru
    $target = $null
    for ($i = 0; $i -lt 60 -and -not $target; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $list = Invoke-RestMethod -Uri ('http://127.0.0.1:' + $port + '/json/list') -UseBasicParsing -TimeoutSec 3
            $target = @($list | Where-Object { $_.type -eq 'page' })[0]
        } catch { }
    }
    if (-not $target) { throw 'EDGE_DEBUG_PORT_NOT_READY' }
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $null = $ws.ConnectAsync([Uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $b = [pscustomobject]@{ Ws = $ws; Port = $port; Profile = $profileDir; NextId = 0 }
    $null = Invoke-KsCdp $b 'Page.enable' @{}
    $null = Invoke-KsCdp $b 'Runtime.enable' @{}
    if ($Mobile) {
        $null = Invoke-KsCdp $b 'Emulation.setDeviceMetricsOverride' @{ width = $Width; height = $Height; deviceScaleFactor = 2; mobile = $true }
    }
    return $b
}

function Invoke-KsCdp {
    param($Browser, [string]$Method, [hashtable]$Params = @{}, [int]$TimeoutSec = 60)
    $Browser.NextId++
    $id = $Browser.NextId
    $json = (@{ id = $id; method = $Method; params = $Params } | ConvertTo-Json -Depth 20 -Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $null = $Browser.Ws.SendAsync((New-Object 'System.ArraySegment[byte]' -ArgumentList (, $bytes)), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $buffer = New-Object byte[] 65536
    while ((Get-Date) -lt $deadline) {
        $ms = New-Object IO.MemoryStream
        do {
            $cts = New-Object Threading.CancellationTokenSource ([TimeSpan]::FromSeconds($TimeoutSec))
            $r = $Browser.Ws.ReceiveAsync((New-Object 'System.ArraySegment[byte]' -ArgumentList (, $buffer)), $cts.Token).GetAwaiter().GetResult()
            $ms.Write($buffer, 0, $r.Count)
        } while (-not $r.EndOfMessage)
        $msg = $ser.DeserializeObject([Text.Encoding]::UTF8.GetString($ms.ToArray()))
        if ($msg.ContainsKey('id') -and $msg['id'] -eq $id) {
            if ($msg.ContainsKey('error')) { throw ('CDP_ERROR ' + $Method + ': ' + $msg['error']['message']) }
            return $msg['result']
        }
    }
    throw ('CDP_TIMEOUT ' + $Method)
}

function Invoke-KsJs {
    # Esegue JavaScript nella pagina e restituisce il valore (serializzato per valore).
    param($Browser, [string]$Expression)
    $res = Invoke-KsCdp $Browser 'Runtime.evaluate' @{ expression = $Expression; returnByValue = $true; awaitPromise = $true }
    if ($res.ContainsKey('exceptionDetails')) { throw ('JS_ERROR: ' + $res['exceptionDetails']['text'] + ' ' + $Expression) }
    if ($res['result'].ContainsKey('value')) { return $res['result']['value'] }
    return $null
}

function Wait-KsLoad {
    param($Browser, [int]$TimeoutSec = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    Start-Sleep -Milliseconds 400
    while ((Get-Date) -lt $deadline) {
        try { if ((Invoke-KsJs $Browser 'document.readyState') -eq 'complete') { Start-Sleep -Milliseconds 600; return } } catch { }
        Start-Sleep -Milliseconds 400
    }
    throw 'PAGE_LOAD_TIMEOUT'
}

function Open-KsUrl {
    param($Browser, [string]$Url, [int]$TimeoutSec = 120)
    $null = Invoke-KsCdp $Browser 'Page.navigate' @{ url = $Url } $TimeoutSec
    Wait-KsLoad $Browser $TimeoutSec
}

function Invoke-KsClick {
    # Clic su un elemento (selettore CSS); attende il caricamento se la pagina cambia.
    param($Browser, [string]$Selector, [switch]$NoWait)
    $js = '(function(){var e=document.querySelector(' + (ConvertTo-Json $Selector -Compress) + ');if(!e){return "NOT_FOUND";}e.scrollIntoView({block:"center"});e.click();return "OK";})()'
    $r = Invoke-KsJs $Browser $js
    if ($r -ne 'OK') { throw ('ELEMENT_NOT_FOUND: ' + $Selector) }
    if (-not $NoWait) { Wait-KsLoad $Browser }
}

function Set-KsValue {
    param($Browser, [string]$Selector, [string]$Value)
    $js = '(function(){var e=document.querySelector(' + (ConvertTo-Json $Selector -Compress) + ');if(!e){return "NOT_FOUND";}e.focus();e.value=' + (ConvertTo-Json $Value -Compress) + ';e.dispatchEvent(new Event("input",{bubbles:true}));e.dispatchEvent(new Event("change",{bubbles:true}));return "OK";})()'
    if ((Invoke-KsJs $Browser $js) -ne 'OK') { throw ('ELEMENT_NOT_FOUND: ' + $Selector) }
}

function Get-KsText {
    param($Browser, [string]$Selector)
    $js = '(function(){var e=document.querySelector(' + (ConvertTo-Json $Selector -Compress) + ');return e?e.innerText:null;})()'
    return (Invoke-KsJs $Browser $js)
}

function Save-KsScreenshot {
    param($Browser, [string]$Path, [switch]$FullPage)
    $p = @{ format = 'png' }
    if ($FullPage) {
        $m = Invoke-KsCdp $Browser 'Page.getLayoutMetrics' @{}
        $cs = $m['cssContentSize']
        $p['clip'] = @{ x = 0; y = 0; width = [double]$cs['width']; height = [Math]::Min([double]$cs['height'], 6000); scale = 1 }
        $p['captureBeyondViewport'] = $true
    }
    $r = Invoke-KsCdp $Browser 'Page.captureScreenshot' $p 90
    [IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String($r['data']))
}

function Stop-KsBrowser {
    param($Browser)
    try { $Browser.Ws.Dispose() } catch { }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Browser.Profile) } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $Browser.Profile) { Remove-Item -LiteralPath $Browser.Profile -Recurse -Force -ErrorAction SilentlyContinue }
}
