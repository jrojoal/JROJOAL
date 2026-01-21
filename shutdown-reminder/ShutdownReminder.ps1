# Reinici únic a les 23:30 i notificacions amb compte enrere

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Hora objectiu
$targetTime = Get-Date -Hour 23 -Minute 30 -Second 0
$now = Get-Date
$seconds = [int]($targetTime - $now).TotalSeconds

if ($seconds -gt 0) {
    # Programa el reinici
    shutdown /r /t $seconds /c "ATENCIÓ: El sistema es reiniciarà a les 23:00 per actualització programada mensual. Desa la teva feina!"

    Write-Host "√ Reinici ÚNIC programat per les 23:30" -ForegroundColor Green
    Write-Host " Temps restant: $([math]::Round($seconds/60, 1)) minuts" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Per cancel·lar aquest reinici: shutdown /a" -ForegroundColor Yellow

    # Crea l'objecte de notificació
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.BalloonTipTitle = "⚠️ Reinici programat"

    # Bucle de notificació
    while ((Get-Date) -lt $targetTime) {
        $now = Get-Date
        $remaining = $targetTime - $now
        $totalMinutes = [math]::Floor($remaining.TotalMinutes)
        $secondsLeft = $remaining.Seconds

        $msg = "Reinici a les 23:00. Temps restant: $totalMinutes min $secondsLeft s. Desa la feina!"
        $notify.BalloonTipText = $msg
        $notify.ShowBalloonTip(60000)  # Mostra 60 segons

        # Freqüència de notificació
        if ($totalMinutes -gt 60) {
            Start-Sleep -Seconds 3600  # Cada 60 min
        }
        elseif ($totalMinutes -gt 15) {
            Start-Sleep -Seconds 300   # Cada 5 min
        }
        else {
            Start-Sleep -Seconds 60    # Cada 1 min
        }
    }

    $notify.Dispose()
}
else {
    Write-Host "X Les 23:30 ja han passat avui!" -ForegroundColor Red
}
