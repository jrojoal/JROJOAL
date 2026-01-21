# 🚀 Guia Ràpida d'Inici

## Per Usuaris (Sense Compilar)

### Opció 1: Usar el Fitxer .BAT (Més Fàcil)
1. Fes clic dret sobre `RunAsAdmin.bat`
2. Selecciona "Executar com a administrador"
3. Fet! L'aplicació començarà a funcionar

### Opció 2: PowerShell Directe
1. Obre PowerShell com a Administrador
   - Cerca "PowerShell" al menú Inici
   - Clic dret → "Executar com a administrador"
2. Navega a la carpeta:
   ```powershell
   cd ruta\a\shutdown-reminder
   ```
3. Executa:
   ```powershell
   .\ShutdownReminder.ps1
   ```

## Per Desenvolupadors (Compilar Executable)

### 1. Compilar l'Executable

```powershell
# Obre PowerShell com a Administrador
cd ruta\a\shutdown-reminder
.\Build.ps1
```

### 2. Executar l'Executable

Després de compilar, simplement executa:
- Clic dret sobre `ShutdownReminder.exe`
- "Executar com a administrador"

## ❓ Què fa l'aplicació?

- ⏰ Programa un reinici a les **23:30**
- 🔔 Mostra notificacions periòdiques amb el temps restant
- 💾 Et recorda desar la feina abans del reinici

## 🛑 Cancel·lar el Reinici

Si canvies d'opinió:

```powershell
shutdown /a
```

## ⚠️ Recordatori Important

**Necessites privilegis d'Administrador!** Sempre executa l'aplicació com a Administrador per poder programar el reinici del sistema.

---

Per més informació, consulta el [README.md](README.md) complet.
