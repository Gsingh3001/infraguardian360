param(
    [string]$IG360Server = "your-ig360-server",
    [string]$OpenSearchPort = "9200",
    [string]$PrometheusPort = "9182"
)

function Write-Log  { Write-Host "[IG360]  $args" -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[  OK  ] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[ WARN ] $args" -ForegroundColor Yellow }
function Write-Fail { Write-Host "[ FAIL ] $args" -ForegroundColor Red; exit 1 }

Clear-Host
Write-Host "  InfraGuardian360 - Windows Agent Installer" -ForegroundColor Cyan
Write-Host "  github.com/Gsingh3001/infraguardian360" -ForegroundColor DarkCyan
Write-Host ""

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn "Not running as Administrator - some installs may fail"
}

$Hostname = $env:COMPUTERNAME
$HostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object -First 1).IPAddress

Write-Host ""
Write-Log "Installing windows_exporter..."
$WinExporterVersion = "0.28.1"
$WinExporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$WinExporterVersion/windows_exporter-$WinExporterVersion-amd64.msi"
$WinExporterMsi = "$env:TEMP\windows_exporter.msi"

try {
    Write-Log "Downloading windows_exporter v$WinExporterVersion..."
    Invoke-WebRequest -Uri $WinExporterUrl -OutFile $WinExporterMsi -UseBasicParsing
    $Collectors = "cpu,cs,logical_disk,net,os,service,memory,process,tcp,logon,system"
    Start-Process msiexec.exe -ArgumentList "/i `"$WinExporterMsi`" /quiet ENABLED_COLLECTORS=`"$Collectors`" LISTEN_PORT=$PrometheusPort" -Wait
    Start-Sleep -Seconds 3
    $svc = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Ok "windows_exporter running on :$PrometheusPort"
    } else {
        Write-Warn "windows_exporter installed but not running yet - check Services"
    }
} catch {
    Write-Warn "windows_exporter install failed: $_"
}

Write-Host ""
Write-Log "Writing Fluent Bit config template..."
$FluentBitConfDir = "C:\Program Files\fluent-bit\conf"
$FluentBitConfig = Join-Path $FluentBitConfDir "fluent-bit.conf"

$ConfigLines = @(
    "[SERVICE]",
    "    Flush         5",
    "    Log_Level     warn",
    "",
    "[INPUT]",
    "    Name          winlog",
    "    Channels      Application,Security,System",
    "    Interval_Sec  5",
    "    Tag           windows.eventlog",
    "",
    "[FILTER]",
    "    Name          record_modifier",
    "    Match         windows.*",
    "    Record        hostname $Hostname",
    "    Record        platform infraguardian360",
    "    Record        os windows",
    "",
    "[OUTPUT]",
    "    Name          opensearch",
    "    Match         windows.*",
    "    Host          $IG360Server",
    "    Port          $OpenSearchPort",
    "    Index         ig360-logs-windows",
    "    HTTP_User     admin",
    "    HTTP_Passwd   admin",
    "    tls           Off",
    "    Suppress_Type_Name On"
)

if (Test-Path $FluentBitConfDir) {
    $ConfigLines | Set-Content -Path $FluentBitConfig
    Write-Ok "Fluent Bit config written"
} else {
    Write-Warn "Fluent Bit not installed - skipping config"
    Write-Log "Install Fluent Bit from: https://packages.fluentbit.io/windows"
}

Write-Host ""
Write-Host "  Add to your Prometheus scrape config:" -ForegroundColor Cyan
Write-Host "  - job_name: windows" -ForegroundColor DarkCyan
Write-Host "    static_configs:" -ForegroundColor DarkCyan
Write-Host "      - targets: ['${HostIP}:${PrometheusPort}']" -ForegroundColor DarkCyan
Write-Host "        labels:" -ForegroundColor DarkCyan
Write-Host "          hostname: '$Hostname'" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Windows agent setup complete!" -ForegroundColor Green
Write-Host "  Metrics: http://${HostIP}:${PrometheusPort}/metrics" -ForegroundColor Cyan
Write-Host ""
