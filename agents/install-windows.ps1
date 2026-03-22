# ============================================================
#  InfraGuardian360 — Windows Agent Installer
#  Installs: lldpd-win + windows_exporter + Fluent Bit
#  Run as Administrator in PowerShell
#  Usage: Set-ExecutionPolicy Bypass -Scope Process -Force
#         .\install-windows.ps1
# ============================================================

param(
    [string]$IG360Server = "your-ig360-server",
    [string]$OpenSearchPort = "9200",
    [string]$PrometheusPort = "9182"
)

# ── COLOURS ──────────────────────────────────────────────────
function Write-Log   { Write-Host "[IG360]  $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[  OK  ] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[ WARN ] $args" -ForegroundColor Yellow }
function Write-Fail  { Write-Host "[ FAIL ] $args" -ForegroundColor Red; exit 1 }

# ── BANNER ───────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  InfraGuardian360 — Windows Agent Installer" -ForegroundColor Cyan
Write-Host "  Installs: windows_exporter + Fluent Bit + LLDP" -ForegroundColor Cyan
Write-Host "  github.com/Gsingh3001/infraguardian360" -ForegroundColor DarkCyan
Write-Host ""

# ── ADMIN CHECK ───────────────────────────────────────────────
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Please run PowerShell as Administrator"
}
Write-Ok "Running as Administrator"

# ── WINGET / CHOCOLATEY CHECK ─────────────────────────────────
$UseWinget = $false
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Log "Package manager: winget available"
    $UseWinget = $true
} elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Package manager: Chocolatey available"
} else {
    Write-Log "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Ok "Chocolatey installed"
}

# ── INSTALL WINDOWS EXPORTER ─────────────────────────────────
Write-Host ""
Write-Log "Installing windows_exporter (Prometheus metrics)..."

$WinExporterVersion = "0.28.1"
$WinExporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v${WinExporterVersion}/windows_exporter-${WinExporterVersion}-amd64.msi"
$WinExporterMsi = "$env:TEMP\windows_exporter.msi"

Write-Log "Downloading windows_exporter v$WinExporterVersion..."
Invoke-WebRequest -Uri $WinExporterUrl -OutFile $WinExporterMsi -UseBasicParsing

Write-Log "Installing windows_exporter..."
$Collectors = "cpu,cs,logical_disk,net,os,service,memory,process,tcp,logon,system"
Start-Process msiexec.exe -ArgumentList "/i `"$WinExporterMsi`" /quiet ENABLED_COLLECTORS=`"$Collectors`" LISTEN_PORT=$PrometheusPort" -Wait

# Verify
Start-Sleep -Seconds 3
$Service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
if ($Service -and $Service.Status -eq "Running") {
    Write-Ok "windows_exporter running on :$PrometheusPort"
} else {
    Write-Warn "windows_exporter may not be running — check Services"
}

# ── INSTALL FLUENT BIT ────────────────────────────────────────
Write-Host ""
Write-Log "Installing Fluent Bit log forwarder..."

$FluentBitVersion = "3.2.2"
$FluentBitUrl = "https://packages.fluentbit.io/windows/fluent-bit-${FluentBitVersion}-win64.exe"
$FluentBitExe = "$env:TEMP\fluent-bit-installer.exe"

Write-Log "Downloading Fluent Bit v$FluentBitVersion..."
Invoke-WebRequest -Uri $FluentBitUrl -OutFile $FluentBitExe -UseBasicParsing

Write-Log "Installing Fluent Bit silently..."
Start-Process $FluentBitExe -ArgumentList "/S" -Wait

# Write Fluent Bit config
$FluentBitConfig = "C:\Program Files\fluent-bit\conf\fluent-bit.conf"
$Hostname = $env:COMPUTERNAME

$ConfigContent = @"
[SERVICE]
    Flush         5
    Log_Level     warn

[INPUT]
    Name          winlog
    Channels      Application,Security,System
    Interval_Sec  5
    Tag           windows.eventlog

[INPUT]
    Name          tail
    Tag           windows.iis
    Path          C:\inetpub\logs\LogFiles\*\*.log
    DB            C:\fluent-bit-iis.db
    Refresh_Interval 10

[FILTER]
    Name          record_modifier
    Match         windows.*
    Record        hostname $Hostname
    Record        platform infraguardian360
    Record        os windows

[OUTPUT]
    Name          opensearch
    Match         windows.*
    Host          $IG360Server
    Port          $OpenSearchPort
    Index         ig360-logs-windows
    Type          _doc
    HTTP_User     admin
    HTTP_Passwd   admin
    tls           Off
    Suppress_Type_Name On
"@

if (Test-Path "C:\Program Files\fluent-bit\conf") {
    Set-Content -Path $FluentBitConfig -Value $ConfigContent
    Write-Ok "Fluent Bit configured"
} else {
    Write-Warn "Fluent Bit install directory not found — configure manually"
}

# ── SHOW PROMETHEUS CONFIG ────────────────────────────────────
Write-Host ""
Write-Host "  Add this to your Prometheus config:" -ForegroundColor Cyan
Write-Host ""
$HostIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet* | Select-Object -First 1).IPAddress
Write-Host "  - job_name: windows-exporter" -ForegroundColor DarkCyan
Write-Host "    static_configs:" -ForegroundColor DarkCyan
Write-Host "      - targets: ['${HostIP}:${PrometheusPort}']" -ForegroundColor DarkCyan
Write-Host "        labels:" -ForegroundColor DarkCyan
Write-Host "          hostname: '$Hostname'" -ForegroundColor DarkCyan
Write-Host "          os: 'windows'" -ForegroundColor DarkCyan

# ── SUMMARY ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  Windows agents installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Collecting:" -ForegroundColor Cyan
Write-Host "  -> CPU, memory, disk, network metrics"
Write-Host "  -> Windows Services status"
Write-Host "  -> Running processes"
Write-Host "  -> TCP connection stats"
Write-Host "  -> Windows Event Log (Application, Security, System)"
Write-Host "  -> IIS logs (if present)"
Write-Host ""
Write-Host "  Metrics:  http://${HostIP}:${PrometheusPort}/metrics" -ForegroundColor Cyan
Write-Host "  Logs to:  ${IG360Server}:${OpenSearchPort}" -ForegroundColor Cyan
Write-Host ""