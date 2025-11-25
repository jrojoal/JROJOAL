# Guia Ràpida d'Ús - Gestor DNS

## Inici Ràpid en 3 Passos

### 1. Executa l'aplicació

```bash
./app.sh
```

### 2. Genera un fitxer d'exemple

Des del menú, selecciona l'opció **8** per generar un fitxer d'exemple amb el format correcte.

### 3. Afegeix els teus registres

Edita el fitxer generat (`dns/exemple_registres.txt`) i després usa l'opció **1** per afegir-los massivement.

---

## Casos d'Ús Comuns

### 📥 Alta Massiva de Servidors

1. Crea un fitxer `servidors.txt`:
   ```
   10.0.1.10 server01.upf.edu
   10.0.1.11 server02.upf.edu
   10.0.1.12 server03.upf.edu
   ```

2. Executa `./app.sh`
3. Selecciona opció **1** (Afegir registres massius)
4. Proporciona la ruta: `servidors.txt`

**Resultat:** Es creen automàticament els registres A i PTR per cada servidor.

---

### 📤 Baixa Massiva de Servidors

1. Crea un fitxer `baixa.txt` amb els servidors a eliminar
2. Executa `./app.sh`
3. Selecciona opció **2** (Eliminar registres massius)
4. Proporciona la ruta del fitxer

**Resultat:** S'eliminen els registres A i PTR especificats.

---

### 🌐 Crear Nova Zona DNS

**Zona Forward (per hostnames com server.upf.edu):**

1. Executa `./app.sh`
2. Selecciona opció **3** (Afegir zona)
3. Selecciona tipus **1** (Forward)
4. Introdueix el nom: `upf.edu`

**Zona Reverse (per IPs com 10.0.1.x):**

1. Executa `./app.sh`
2. Selecciona opció **3** (Afegir zona)
3. Selecciona tipus **2** (Reverse)
4. Introdueix la xarxa: `10.0.1`

---

### 💾 Fer Backup

1. Executa `./app.sh`
2. Selecciona opció **6** (Fer backup)

**Resultat:** Es creen backups amb el format:
- `zona.upf.edu.hosts.20251125`
- `1.0.10.in-addr.arpa.rev.20251125`

---

## Format del Fitxer d'Entrada

Ambdós formats són vàlids:

```
# Format 1: IP primer
10.0.1.10 server01.upf.edu

# Format 2: Hostname primer
server01.upf.edu 10.0.1.10
```

### Exemples Reals

```
# Servidor web
10.0.1.100 web.upf.edu

# Base de dades
db.upf.edu 10.0.2.50

# Múltiples servidors
10.0.3.10 app01.upf.edu
10.0.3.11 app02.upf.edu
10.0.3.12 app03.upf.edu

# Comentaris (ignorats)
# Aquest és un comentari
```

---

## Estructura de Fitxers Generats

```
dns/
├── zones/
│   ├── upf.edu.hosts              # Registres A
│   └── 1.0.10.in-addr.arpa.rev    # Registres PTR
├── backups/
│   ├── upf.edu.upf.edu.hosts.20251125
│   └── 1.0.10.in-addr.arpa.rev.20251125
└── config/
    └── zones.conf                  # Configuració de zones
```

---

## Menú Principal

```
  GESTIÓ DE REGISTRES:
    1) Afegir registres massius (alta)
    2) Eliminar registres massius (baixa)

  GESTIÓ DE ZONES:
    3) Afegir zona
    4) Eliminar zona
    5) Llistar zones

  BACKUPS:
    6) Fer backup de totes les zones
    7) Llistar backups disponibles

  ALTRES:
    8) Generar fitxer d'exemple
    9) Sortir
```

---

## Característiques Clau

✅ **Automàtic**: Crea zones automàticament si no existeixen
✅ **Segur**: Valida IPs i evita duplicats
✅ **Dual**: Crea registres A i PTR simultàniament
✅ **Flexible**: Accepta IP+hostname o hostname+IP
✅ **Backup**: Sistema automàtic amb timestamps

---

## Troubleshooting

### No es creen els registres PTR

**Causa:** La zona reverse no existeix.
**Solució:** L'script la crea automàticament. Si continues tenint problemes, crea-la manualment amb l'opció 3.

### Error "IP invàlida"

**Causa:** Format d'IP incorrecte.
**Solució:** Usa el format `X.X.X.X` amb valors 0-255.

### Registres duplicats

**Solució:** L'script detecta i evita duplicats automàticament. Veuràs un warning però no es duplicarà.

---

## Exemple Complet Pas a Pas

### Escenari: Afegir 3 nous servidors web

**1. Crea el fitxer `nous_web.txt`:**

```bash
cat > nous_web.txt << EOF
10.0.2.10 web01.upf.edu
10.0.2.11 web02.upf.edu
10.0.2.12 web03.upf.edu
EOF
```

**2. Executa l'app:**

```bash
./app.sh
```

**3. Selecciona l'opció 1**

**4. Introdueix la ruta:** `nous_web.txt`

**5. Resultat:**

```
✓ Afegit registre A: 10.0.2.10 -> web01.upf.edu
✓ Afegit registre PTR: 10.2.0.10.in-addr.arpa -> web01.upf.edu
✓ Afegit registre A: 10.0.2.11 -> web02.upf.edu
✓ Afegit registre PTR: 11.2.0.10.in-addr.arpa -> web02.upf.edu
✓ Afegit registre A: 10.0.2.12 -> web03.upf.edu
✓ Afegit registre PTR: 12.2.0.10.in-addr.arpa -> web03.upf.edu

=== RESUM ===
✓ Registres afegits: 3
```

**6. Verifica els fitxers:**

```bash
cat dns/zones/upf.edu.hosts
cat dns/zones/2.0.10.in-addr.arpa.rev
```

**7. Fes un backup (opcional):**

Selecciona l'opció 6 del menú.

---

## Documentació Completa

Per més detalls, consulta [dns/README.md](dns/README.md)
