# Build Script - Crea un executable portable del Shutdown Reminder
# Aquest script converteix ShutdownReminder.ps1 a un executable .exe portable

Write-Host "=== Shutdown Reminder - Build Script ===" -ForegroundColor Cyan
Write-Host ""

# Comprova si PS2EXE està instal·lat
Write-Host "Comprovant PS2EXE..." -ForegroundColor Yellow
$ps2exeInstalled = Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue

if (-not $ps2exeInstalled) {
    Write-Host "PS2EXE no trobat. Instal·lant..." -ForegroundColor Yellow

    # Instal·la PS2EXE des de PowerShell Gallery
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "✓ PS2EXE instal·lat correctament" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error instal·lant PS2EXE: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternativa: Descarrega ps2exe manualment des de:" -ForegroundColor Yellow
        Write-Host "https://github.com/MScholtes/PS2EXE" -ForegroundColor Cyan
        exit 1
    }
}
else {
    Write-Host "✓ PS2EXE ja està instal·lat" -ForegroundColor Green
}

Write-Host ""
Write-Host "Creant executable portable..." -ForegroundColor Yellow

# Defineix les rutes
$scriptPath = Join-Path $PSScriptRoot "ShutdownReminder.ps1"
$exePath = Join-Path $PSScriptRoot "ShutdownReminder.exe"

# Comprova que el script existeix
if (-not (Test-Path $scriptPath)) {
    Write-Host "✗ Error: No s'ha trobat ShutdownReminder.ps1" -ForegroundColor Red
    exit 1
}

# Converteix el script a executable
try {
    Invoke-PS2EXE -inputFile $scriptPath -outputFile $exePath `
        -title "Shutdown Reminder" `
        -description "Recordatori automàtic de reinici programat" `
        -company "JROJOAL" `
        -version "1.0.0.0" `
        -noConsole `
        -requireAdmin

    Write-Host "✓ Executable creat correctament!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ubicació: $exePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Per executar l'aplicació:" -ForegroundColor Yellow
    Write-Host "  1. Obre PowerShell com a Administrador" -ForegroundColor White
    Write-Host "  2. Executa: .\ShutdownReminder.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "L'executable és portable i no requereix instal·lació." -ForegroundColor Green
}
catch {
    Write-Host "✗ Error creant l'executable: $_" -ForegroundColor Red
    exit 1
}
