# Gestor Interactiu de Registres DNS

Sistema automatitzat per la gestió massiva de registres DNS (zones A i PTR) amb funcionalitats de backup automàtic.

## Característiques

- ✅ Alta i baixa massiva de registres DNS
- ✅ Gestió automàtica de zones Forward (A) i Reverse (PTR)
- ✅ Creació automàtica de zones quan calgui
- ✅ Sistema de backups amb nomenclatura estandarditzada
- ✅ Validació d'IPs i hostnames
- ✅ Interfície interactiva amb menú
- ✅ Format flexible d'entrada (IP+hostname o hostname+IP)

## Estructura de Directoris

```
dns/
├── zones/          # Fitxers de zones DNS (.hosts i .rev)
├── backups/        # Backups amb format temporal
├── records/        # Registres individuals (reservat)
├── config/         # Configuració de zones
└── README.md       # Aquesta documentació
```

## Instal·lació

L'script ja està preparat per usar. Només cal executar-lo:

```bash
./app.sh
```

## Format del Fitxer d'Entrada

Els fitxers d'entrada per alta/baixa massiva accepten ambdós formats:

```
# Format 1: IP primer
10.0.1.10 server01.example.com
10.0.1.11 server02.example.com

# Format 2: Hostname primer
web01.example.com 10.0.2.10
db01.example.com 10.0.3.20

# Les línies que comencen amb # són comentaris i s'ignoren
```

### Exemple Complet

```
# Servidors web
10.0.1.10 web01.example.com
10.0.1.11 web02.example.com
10.0.1.12 web03.example.com

# Bases de dades
db-master.example.com 10.0.2.20
db-slave.example.com 10.0.2.21

# Servidors d'aplicacions
10.0.3.30 app01.example.com
10.0.3.31 app02.example.com
```

## Funcionalitats del Menú

### 1. Afegir Registres Massius

Processa un fitxer amb registres DNS i els afegeix automàticament:
- Crea registres A (forward) a les zones corresponents
- Crea registres PTR (reverse) automàticament
- Si la zona no existeix, es crea automàticament
- Valida IPs i hostnames
- Evita duplicats

**Exemple d'ús:**

1. Crea un fitxer `alta_servidors.txt` amb els registres
2. Selecciona opció 1 del menú
3. Proporciona la ruta al fitxer
4. L'script processa tot automàticament

### 2. Eliminar Registres Massius

Processa un fitxer amb registres DNS i els elimina:
- Elimina registres A de les zones forward
- Elimina registres PTR de les zones reverse
- Informa dels registres no trobats

### 3. Afegir Zona

Crea una nova zona DNS:

**Zona Forward (A records):**
- Demana el nom de la zona (ex: `example.com`)
- Crea el fitxer `example.com.hosts`
- Registra la zona a la configuració

**Zona Reverse (PTR records):**
- Demana la xarxa (ex: `10.0.1` per 1.0.10.in-addr.arpa)
- Crea el fitxer de zona reverse
- Registra la zona a la configuració

### 4. Eliminar Zona

Elimina una zona existent:
- Fa backup automàtic abans d'eliminar
- Elimina els fitxers de zona
- Actualitza la configuració

### 5. Llistar Zones

Mostra totes les zones configurades:
- Zones Forward (A records)
- Zones Reverse (PTR records)

### 6. Fer Backup

Crea backups de totes les zones amb nomenclatura estandarditzada:

**Format de Backups:**
- Zones forward: `zona.example.com.hosts.YYYYMMDD`
- Zones reverse: `x.y.z.in-addr.arpa.rev.YYYYMMDD`
- Configuració: `zones.conf.YYYYMMDD`

**Exemple:**
```
example.com.example.com.hosts.20251125
1.0.10.in-addr.arpa.rev.20251125
zones.conf.20251125
```

### 7. Llistar Backups

Mostra tots els backups disponibles amb la seva mida.

### 8. Generar Fitxer d'Exemple

Crea un fitxer d'exemple `dns/exemple_registres.txt` amb el format correcte per començar a treballar.

## Fitxers Generats

### Zones Forward (.hosts)

Format dels fitxers de zones forward:

```
# Contingut de example.com.hosts
10.0.1.10	server01.example.com
10.0.1.11	server02.example.com
10.0.2.20	web01.example.com
```

### Zones Reverse (.rev)

Format dels fitxers de zones reverse:

```
# Contingut de 1.0.10.in-addr.arpa.rev
10	server01.example.com
11	server02.example.com
```

### Configuració (zones.conf)

Registre de zones actives:

```
FORWARD:example.com
FORWARD:example.com
REVERSE:1.0.10.in-addr.arpa
REVERSE:2.0.10.in-addr.arpa
```

## Exemples d'Ús

### Cas 1: Alta de Nous Servidors

1. Crea fitxer `nous_servidors.txt`:
```
10.0.1.100 srv-app01.example.com
10.0.1.101 srv-app02.example.com
10.0.1.102 srv-app03.example.com
```

2. Executa `./app.sh`
3. Selecciona opció 1
4. Proporciona ruta: `./nous_servidors.txt`

Resultat:
- Es creen 3 registres A a `example.com.hosts`
- Es creen 3 registres PTR a `1.0.10.in-addr.arpa.rev`

### Cas 2: Baixa de Servidors Antics

1. Crea fitxer `baixa_servidors.txt`:
```
10.0.1.50 old-srv01.example.com
10.0.1.51 old-srv02.example.com
```

2. Executa `./app.sh`
3. Selecciona opció 2
4. Proporciona ruta: `./baixa_servidors.txt`

### Cas 3: Backup Abans de Canvis Importants

1. Executa `./app.sh`
2. Selecciona opció 6
3. Els backups es guarden a `dns/backups/`

### Cas 4: Afegir Nova Zona

1. Executa `./app.sh`
2. Selecciona opció 3
3. Selecciona tipus de zona (Forward/Reverse)
4. Introdueix el nom o xarxa

## Validacions i Seguretat

- **Validació d'IPs**: Comprova format i rang (0-255 per octet)
- **Detecció de duplicats**: Evita registres duplicats
- **Backups automàtics**: Abans d'eliminar zones es fan backups
- **Comentaris**: Les línies amb `#` s'ignoren
- **Línes buides**: S'ignoren automàticament

## Solució de Problemes

### Error: "La zona X no existeix"

**Solució:** Crea la zona primer amb l'opció 3 del menú, o deixa que es creï automàticament quan afegeixes registres.

### Error: "IP invàlida"

**Solució:** Comprova que la IP té el format correcte: `X.X.X.X` amb valors 0-255.

### Els registres PTR no es creen

**Solució:** Comprova que la zona reverse corresponent existeix o deixa que es creï automàticament.

### Format del fitxer incorrecte

**Solució:** Usa l'opció 8 per generar un fitxer d'exemple i segueix el format.

## Notes Tècniques

- Els registres es separen amb tabuladors (tabs)
- Les zones reverse segueixen l'estàndard in-addr.arpa
- Els backups inclouen timestamp per evitar sobreescriptura
- El sistema és idempotent: pots executar la mateixa alta múltiples vegades sense duplicar registres

## Roadmap Futur

- [ ] Suport per zones IPv6
- [ ] Integració amb servidors DNS reals (BIND, PowerDNS)
- [ ] API REST per gestió remota
- [ ] Validació de sintaxi FQDN més estricta
- [ ] Històric de canvis amb diff
- [ ] Restauració de backups des del menú
- [ ] Suport per altres tipus de registres (CNAME, MX, TXT)

## Autor

Script desenvolupat per automatitzar la gestió DNS a ORGANITZACIO.