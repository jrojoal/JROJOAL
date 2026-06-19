#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Neteja d'actualitzacions antigues de Windows i alliberament d'espai en disc.
.DESCRIPTION
    Atura els serveis d'actualització, neteja el Component Store (WinSxS),
    purga SoftwareDistribution i elimina fitxers temporals del sistema.
.NOTES
    Cal executar com a Administrador.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = @{ INFO = 'Cyan'; WARN = 'Yellow'; ERROR = 'Red' }[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-FreeDiskSpaceGB {
    param([string]$Drive = $env:SystemDrive)
    $disk = Get-PSDrive -Name ($Drive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($disk) { return [math]::Round($disk.Free / 1GB, 2) }
    return $null
}

function Stop-ServiceSafely {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Log "Servei '$Name' no trobat, s'omet." 'WARN'; return }
    if ($svc.Status -ne 'Stopped') {
        Write-Log "Aturant servei: $Name"
        Stop-Service -Name $Name -Force
        $svc.WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
    }
}

function Start-ServiceSafely {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Log "Servei '$Name' no trobat, s'omet." 'WARN'; return }
    Write-Log "Iniciant servei: $Name"
    Start-Service -Name $Name
}

function Remove-DirectoryContents {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -Path $Path)) {
        Write-Log "Directori no trobat: $Path" 'WARN'
        return
    }
    Write-Log "Purgant $Label..."
    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
}

# --- Inici ---
Write-Log "=== Neteja d'actualitzacions de Windows ==="
$spaceBefore = Get-FreeDiskSpaceGB
if ($spaceBefore) { Write-Log "Espai lliure inicial: $spaceBefore GB" }

$services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')

# 1. Aturar serveis
Write-Log "--- Pas 1/4: Aturant serveis ---"
foreach ($svc in $services) { Stop-ServiceSafely -Name $svc }

# 2. Neteja del Component Store (WinSxS)
Write-Log "--- Pas 2/4: Netejant el Component Store (DISM) ---"
Write-Log "Això pot trigar diversos minuts..."
try {
    $dismResult = & dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "DISM ha retornat el codi $LASTEXITCODE. Detalls: $dismResult" 'WARN'
    } else {
        Write-Log "DISM completat correctament."
    }
} catch {
    Write-Log "Error executant DISM: $_" 'ERROR'
}

# 3. Purgar SoftwareDistribution
Write-Log "--- Pas 3/4: Purgant SoftwareDistribution ---"
$sdPath = "$env:SystemRoot\SoftwareDistribution"
Remove-DirectoryContents -Path "$sdPath\Download"  -Label 'SoftwareDistribution\Download'
Remove-DirectoryContents -Path "$sdPath\DataStore" -Label 'SoftwareDistribution\DataStore'

# Neteja addicional: logs de CBS i fitxers temporals del sistema
Remove-DirectoryContents -Path "$env:SystemRoot\Logs\CBS"  -Label 'CBS Logs'
Remove-DirectoryContents -Path "$env:TEMP"                  -Label 'Carpeta TEMP d''usuari'
Remove-DirectoryContents -Path "$env:SystemRoot\Temp"       -Label 'Carpeta TEMP del sistema'

# 4. Reiniciar serveis
Write-Log "--- Pas 4/4: Reiniciant serveis ---"
foreach ($svc in ($services | Select-Object -Last 4 | Sort-Object -Descending)) {
    Start-ServiceSafely -Name $svc
}

# --- Resum ---
$spaceAfter = Get-FreeDiskSpaceGB
Write-Log "=== Operació completada ==="
if ($spaceBefore -and $spaceAfter) {
    $freed = [math]::Round($spaceAfter - $spaceBefore, 2)
    $sign  = if ($freed -ge 0) { '+' } else { '' }
    Write-Log "Espai lliure final : $spaceAfter GB  (${sign}${freed} GB)"
}
