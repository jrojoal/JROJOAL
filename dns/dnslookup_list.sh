#!/bin/bash
###############################################################
# Nom: dnslookup_list.sh
# Autor: Pep Rojo SCC-UPF
# Data: 2025-06-04
# Versio: 2.8.0
#
# Descripcio: Script hibrid inspirat en MVP i versio enterprise.
#             Admet entrada manual o fitxer, mostra resultats a pantalla
#             i opcionalment exporta resultats a JSON.
#
# Canvis v2.8.0 (correccions de bugs i millores):
#   - BUG: LOG_FILE es definia pero mai s'escrivia. Ara s'usa per registrar.
#   - BUG: Variables 'a','b' de les funcions de carrega no eren locals,
#          contaminant l'espai global i col·lidint amb la variable 'a' del
#          registre DNS a executar_verificacio(). Ara son locals i renomenades.
#   - BUG: nslookup pot retornar multiples registres A (balanceig de carrega);
#          el valor tenia salts de linia, generant JSON invalid. Ara s'uneixen
#          amb comes.
#   - BUG: Els valors de host/ptr/a no s'escapaven per a JSON. Ara hi ha
#          una funcio json_escape() per evitar corrupcio del fitxer.
#   - BUG: Amb --input no es verificava que el fitxer existis i fos llegible
#          abans de passar-lo a carregar_entrades(). Ara hi ha validacio.
#   - BUG: El filtre 'grep -v "#53"' per als registres A era fragil. Ara
#          es fa servir awk per saltar la primera linia Address (servidor).
#   - MILLORA: S'afegeix comprovacio que nslookup esta instal·lat.
#   - MILLORA: S'afegeix opcio --help amb instruccions d'us.
#   - MILLORA: El JSON exportat esta formatat amb sagnats per facilitar
#              la lectura i depuracio.
#   - MILLORA: S'elimina l'emoji del missatge d'exportacio per compatibilitat
#              amb entorns sense UTF-8 complet (logs, cron, etc.).
###############################################################
set -euo pipefail

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

DNS_SERVER="${DNS_SERVER:-mns.s.upf.edu}"
LOG_DIR="./logs"
METRICS_DIR="./metrics"

mkdir -p "$LOG_DIR" "$METRICS_DIR"

# FIX: Usa la mateixa marca de temps per als dos fitxers per consistencia.
_TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/dns_checker_${_TS}.log"
METRICS_FILE="$METRICS_DIR/resum_${_TS}.json"

IPS=()
HOSTS=()
RESULTATS=()

# ---------------------------------------------------------------
# log MSG  — escriu missatge datat al fitxer de log I a stderr.
# FIX: Abans el LOG_FILE mai s'emplenava.
# ---------------------------------------------------------------
log() {
  local msg="[$(date +%Y-%m-%dT%H:%M:%S)] $*"
  echo "$msg" >> "$LOG_FILE"
  echo -e "$msg" >&2
}

# ---------------------------------------------------------------
# json_escape STR — retorna el text amb els caracters especials
# JSON escapats (\, ", i salts de linia).
# FIX: Sense escapament, qualsevol " o \ als valors corrompria el JSON.
# ---------------------------------------------------------------
json_escape() {
  local s="$1"
  # Ordre important: primer la barra invertida, despres les comes i salts.
  s="${s//\\/\\\\}"   # \ -> \\
  s="${s//\"/\\\"}"   # " -> \"
  s="${s//$'\n'/\\n}" # newline -> \n
  s="${s//$'\r'/\\r}" # CR -> \r
  s="${s//$'\t'/\\t}" # tab -> \t
  printf '%s' "$s"
}

validar_ip() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS='.'
  # FIX: declarem 'parts' com a local per no contaminar l'ambit global.
  local -a parts
  read -ra parts <<< "$1"
  local part
  for part in "${parts[@]}"; do
    (( part >= 0 && part <= 255 )) || return 1
  done
  return 0
}

# ---------------------------------------------------------------
# FIX: les variables temporals de parsatge ('col1','col2') son ara
# locals i s'han reanomenat per evitar la col·lisio amb la variable
# 'a' usada per als resultats DNS a executar_verificacio().
# ---------------------------------------------------------------
carregar_entrades() {
  local input="$1"
  local line col1 col2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    col1=$(echo "$line" | awk '{print $1}')
    col2=$(echo "$line" | awk '{print $2}')
    if validar_ip "$col1" && [[ -n "$col2" ]]; then
      IPS+=("$col1"); HOSTS+=("$col2")
    elif validar_ip "$col2" && [[ -n "$col1" ]]; then
      IPS+=("$col2"); HOSTS+=("$col1")
    else
      log "WARN: Linia ignorada (format invalid): '$line'"
    fi
  done < "$input"
}

carregar_entrades_manual() {
  echo -e "\n${BOLD}${PURPLE}Introdueix parelles HOSTNAME IP (una per linia). Ctrl+D per acabar:${NC}"
  local line col1 col2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    col1=$(echo "$line" | awk '{print $1}')
    col2=$(echo "$line" | awk '{print $2}')
    if validar_ip "$col1" && [[ -n "$col2" ]]; then
      IPS+=("$col1"); HOSTS+=("$col2")
    elif validar_ip "$col2" && [[ -n "$col1" ]]; then
      IPS+=("$col2"); HOSTS+=("$col1")
    else
      log "WARN: Linia ignorada (format invalid): '$line'"
    fi
  done
}

check_dns() {
  nslookup "$1" "$DNS_SERVER" 2>/dev/null
}

executar_verificacio() {
  echo -e "\n${BOLD}${GREEN}=== RESULTATS DE LA CONSULTA DNS A ${YELLOW}$DNS_SERVER ${GREEN}===${NC}\n"
  log "INFO: Iniciant consultes DNS contra $DNS_SERVER"

  local i ip host ptr_raw ptr a_raw a_joined
  for ((i=0; i<${#IPS[@]}; i++)); do
    ip="${IPS[i]}"
    host="${HOSTS[i]}"

    echo -e "${BOLD}${PURPLE}Parell #$((i+1))${NC}"
    echo -e "${BOLD}IP:   ${NC}${YELLOW}$ip${NC}"
    echo -e "${BOLD}HOST: ${NC}${YELLOW}$host${NC}\n"

    # --- PTR (resolucio inversa) ---
    echo -e "${CYAN}Resolucio inversa (PTR):${NC}"
    # FIX: 'ptr' ara es local per no contaminar l'ambit global.
    ptr_raw=$(check_dns "$ip" | grep "name = " | awk -F'name = ' '{print $2}' | sed 's/\.$//' || true)
    ptr="${ptr_raw}"
    if [[ -n "$ptr" ]]; then
      echo -e "${GREEN}$ip  PTR: $ptr${NC}"
      log "INFO: PTR $ip -> $ptr"
    else
      echo -e "${RED}No s'ha trobat registre PTR${NC}"
      log "WARN: No PTR per a $ip"
    fi

    # --- A (resolucio directa) ---
    echo -e "\n${CYAN}Resolucio directa (A):${NC}"
    # FIX: nslookup pot retornar multiples adreces A (salts de linia).
    #      S'agafen totes les linies "Address:" excepte la del servidor
    #      (que te format "address#port"). Ara s'usa awk per descartar
    #      adreces amb '#' en lloc de grep -v "#53" (mes robust).
    a_raw=$(check_dns "$host" \
      | awk '/^Address:/ && $2 !~ /#/ {print $2}' \
      || true)
    # Uneix multiples IPs amb comes per a visualitzacio i JSON valid.
    a_joined=$(echo "$a_raw" | paste -sd ',' - || true)

    if [[ -n "$a_joined" ]]; then
      echo -e "${GREEN}$host  A: $a_joined${NC}"
      log "INFO: A $host -> $a_joined"
    else
      echo -e "${RED}No s'ha trobat registre A${NC}"
      log "WARN: No A per a $host"
    fi

    echo -e "${BLUE}----------------------------------------${NC}"

    # FIX: Escapament JSON dels valors per evitar JSON malformat.
    RESULTATS+=("{\"host\":\"$(json_escape "$host")\",\"ip\":\"$(json_escape "$ip")\",\"ptr\":\"$(json_escape "$ptr")\",\"a\":\"$(json_escape "$a_joined")\"}")
  done
}

# ---------------------------------------------------------------
# FIX: El JSON ara esta formatat amb sagnats per facilitar la
# lectura i depuracio. Cada objecte ocupa la seva propia linia.
# FIX: S'elimina l'emoji per compatibilitat amb entorns no-UTF8.
# ---------------------------------------------------------------
exportar_json() {
  local n="${#RESULTATS[@]}"
  {
    echo "["
    local j
    for ((j=0; j<n; j++)); do
      if (( j < n - 1 )); then
        echo "  ${RESULTATS[j]},"
      else
        echo "  ${RESULTATS[j]}"
      fi
    done
    echo "]"
  } > "$METRICS_FILE"

  echo -e "\nExportat resum a: ${YELLOW}$METRICS_FILE${NC}"
  log "INFO: JSON exportat a $METRICS_FILE"
}

mostrar_ajuda() {
  cat <<EOF
Us: $(basename "$0") [OPCIONS]

Comprova registres DNS directes (A) i inversos (PTR) per a una llista
de parelles hostname/IP contra un servidor DNS.

Opcions:
  --input FILE   Llegeix parelles de l'arxiu FILE (format: HOST IP o IP HOST)
  --help         Mostra aquest missatge i surt

Variables d'entorn:
  DNS_SERVER     Servidor DNS a consultar (per defecte: mns.s.upf.edu)

Format d'arxiu d'entrada:
  hostname.exemple.com  10.0.0.1
  10.0.0.2              altre.host.com

Sense --input, demana les parelles interactivament per stdin (Ctrl+D per acabar).
EOF
}

main() {
  # FIX: --help s'avalua abans de qualsevol altra comprovacio per poder
  # mostrar l'ajuda fins i tot si nslookup no esta instal·lat.
  case "${1:-}" in
    --help|-h)
      mostrar_ajuda
      exit 0
      ;;
  esac

  # FIX: Comprovacio que nslookup esta disponible.
  if ! command -v nslookup &>/dev/null; then
    echo -e "${RED}ERROR: 'nslookup' no esta instal·lat o no es troba al PATH.${NC}" >&2
    exit 2
  fi

  echo -e "${BOLD}${GREEN}COMPROVADOR DNS - UPF${NC}"
  echo -e "${CYAN}Servidor DNS: ${YELLOW}$DNS_SERVER${NC}\n"
  log "INFO: Script iniciat. DNS_SERVER=$DNS_SERVER"

  case "${1:-}" in
    --input)
      local input_file="${2:-}"
      if [[ -z "$input_file" ]]; then
        echo -e "${RED}ERROR: --input requereix un nom de fitxer.${NC}" >&2
        mostrar_ajuda
        exit 1
      fi
      # FIX: Verificacio que el fitxer existeix i es llegible.
      if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}ERROR: El fitxer '$input_file' no existeix.${NC}" >&2
        exit 1
      fi
      if [[ ! -r "$input_file" ]]; then
        echo -e "${RED}ERROR: El fitxer '$input_file' no es llegible (permisos insuficients).${NC}" >&2
        exit 1
      fi
      carregar_entrades "$input_file"
      ;;
    "")
      carregar_entrades_manual
      ;;
    *)
      echo -e "${RED}ERROR: Opcio desconeguda: '${1}'.${NC}" >&2
      mostrar_ajuda
      exit 1
      ;;
  esac

  if [[ ${#IPS[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No s'han introduit entrades valides.${NC}" >&2
    exit 1
  fi

  executar_verificacio
  exportar_json

  echo -e "\n${BOLD}${PURPLE}Total de parells analitzats:${NC} ${YELLOW}${#IPS[@]}${NC}"
  echo -e "${BOLD}${PURPLE}Log guardat a:${NC} ${YELLOW}${LOG_FILE}${NC}\n"
  log "INFO: Script finalitzat. Total parells: ${#IPS[@]}"
}

main "$@"
