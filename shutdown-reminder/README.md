# Shutdown Reminder - Recordatori de Reinici

Aplicació portable per programar un reinici del sistema a les 23:30 amb notificacions de compte enrere.

## 📋 Característiques

- ⏰ Programa un reinici automàtic a les 23:30
- 🔔 Notificacions periòdiques amb compte enrere
- 📊 Freqüència adaptativa de notificacions:
  - Cada 60 minuts si queda més d'1 hora
  - Cada 5 minuts si queden entre 15-60 minuts
  - Cada 1 minut si queden menys de 15 minuts
- ✅ Executable portable (no requereix instal·lació)
- 🛡️ Missatges de recordatori per desar la feina

## 🚀 Ús Ràpid

### Opció 1: Executar el Script PowerShell Directament

```powershell
# Obre PowerShell com a Administrador
.\ShutdownReminder.ps1
```

### Opció 2: Usar l'Executable Portable (Recomanat)

1. Compila l'executable utilitzant el script de build
2. Executa `ShutdownReminder.exe` com a Administrador

## 🔨 Compilar l'Executable

### Mètode Automàtic

Executa el script de build que s'encarregarà de tot:

```powershell
# Obre PowerShell com a Administrador
.\Build.ps1
```

Aquest script:
- Instal·larà PS2EXE si no està present
- Compilarà el script a un executable portable
- Crearà `ShutdownReminder.exe` a la mateixa carpeta

### Mètode Manual

Si prefereixes fer-ho manualment:

1. **Instal·la PS2EXE:**
   ```powershell
   Install-Module -Name ps2exe -Scope CurrentUser -Force
   ```

2. **Compila l'executable:**
   ```powershell
   Invoke-PS2EXE -inputFile .\ShutdownReminder.ps1 `
                 -outputFile .\ShutdownReminder.exe `
                 -title "Shutdown Reminder" `
                 -description "Recordatori automàtic de reinici programat" `
                 -version "1.0.0.0" `
                 -noConsole `
                 -requireAdmin
   ```

## ⚙️ Requisits

- Windows 10/11
- PowerShell 5.1 o superior
- Privilegis d'Administrador (necessaris per programar reinicis)
- PS2EXE (només per compilar l'executable)

## 📖 Com Funciona

1. **Càlcul del Temps:** Calcula els segons restants fins a les 23:30
2. **Programa el Reinici:** Utilitza `shutdown /r` per programar el reinici
3. **Notificacions:** Mostra notificacions al system tray amb el temps restant
4. **Bucle de Monitoratge:** Actualitza el compte enrere periòdicament

## 🛑 Cancel·lar el Reinici

Si necessites cancel·lar el reinici programat:

```powershell
shutdown /a
```

O des del Command Prompt com a Administrador:

```cmd
shutdown /a
```

## 📁 Estructura del Projecte

```
shutdown-reminder/
├── ShutdownReminder.ps1    # Script principal de PowerShell
├── Build.ps1               # Script per compilar l'executable
├── README.md               # Aquesta documentació
└── ShutdownReminder.exe    # Executable portable (generat després de compilar)
```

## 🔧 Personalització

Pots personalitzar els següents paràmetres editant `ShutdownReminder.ps1`:

### Canviar l'Hora del Reinici

```powershell
# Línia 8: Modifica l'hora i els minuts
$targetTime = Get-Date -Hour 23 -Minute 30 -Second 0
```

### Ajustar la Freqüència de Notificacions

```powershell
# Línies 42-50: Modifica els intervals de temps
if ($totalMinutes -gt 60) {
    Start-Sleep -Seconds 3600  # Cada 60 min
}
elseif ($totalMinutes -gt 15) {
    Start-Sleep -Seconds 300   # Cada 5 min
}
else {
    Start-Sleep -Seconds 60    # Cada 1 min
}
```

### Modificar el Missatge de Reinici

```powershell
# Línia 14: Personalitza el missatge
shutdown /r /t $seconds /c "EL TEU MISSATGE PERSONALITZAT"
```

## 🎯 Executar Automàticament a l'Inici

Per executar l'aplicació automàticament quan inicies sessió:

1. Prem `Win + R` i escriu `shell:startup`
2. Crea un accés directe a `ShutdownReminder.exe` en aquesta carpeta
3. Propietats → Avançat → Marcar "Executar com a administrador"

O utilitza el Programador de Tasques de Windows per més control.

## ⚠️ Notes Importants

- **Desa la teva feina:** L'aplicació programarà un reinici real del sistema
- **Privilegis d'Administrador:** Necessaris per utilitzar el comandament `shutdown`
- **Hora del Sistema:** Assegura't que l'hora del sistema és correcta
- **Aplicació Única:** Només s'hauria d'executar una instància a la vegada

## 🐛 Resolució de Problemes

### "No es pot programar el reinici"
- Executa PowerShell o l'executable com a Administrador

### "L'executable no es crea"
- Verifica que PS2EXE està instal·lat correctament
- Comprova que tens permisos d'escriptura a la carpeta

### "Les notificacions no es mostren"
- Verifica que les notificacions estan habilitades al sistema
- Comprova que el Centre d'Accions de Windows està actiu

## 📝 Llicència

Aquest projecte forma part del repositori JROJOAL.

## 👤 Autor

JROJOAL

---

**Advertència:** Utilitza aquesta aplicació sota la teva responsabilitat. Assegura't de desar tota la feina important abans del reinici programat.
