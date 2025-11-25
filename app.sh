#!/bin/bash

################################################################################
# app.sh - Gestor Interactiu de Registres DNS
#
# Script per gestionar massivament registres DNS (zones A i PTR)
# amb funcionalitats de backup automàtic
################################################################################

set -e

# Colors per la interfície
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directoris
DNS_DIR="./dns"
ZONES_DIR="${DNS_DIR}/zones"
BACKUPS_DIR="${DNS_DIR}/backups"
RECORDS_DIR="${DNS_DIR}/records"
CONFIG_DIR="${DNS_DIR}/config"

# Fitxers de configuració
ZONES_FILE="${CONFIG_DIR}/zones.conf"

################################################################################
# Funcions auxiliars
################################################################################

# Mostrar missatges amb color
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Inicialitzar estructura
init_structure() {
    mkdir -p "${ZONES_DIR}" "${BACKUPS_DIR}" "${RECORDS_DIR}" "${CONFIG_DIR}"

    if [ ! -f "${ZONES_FILE}" ]; then
        touch "${ZONES_FILE}"
    fi
}

# Validar IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Extreure la xarxa reverse de la IP (per PTR)
get_reverse_zone() {
    local ip=$1
    IFS='.' read -ra octets <<< "$ip"
    echo "${octets[2]}.${octets[1]}.${octets[0]}.in-addr.arpa"
}

# Obtenir l'últim octet per PTR
get_ptr_host() {
    local ip=$1
    IFS='.' read -ra octets <<< "$ip"
    echo "${octets[3]}"
}

################################################################################
# Gestió de Zones
################################################################################

listar_zones() {
    echo ""
    print_info "=== ZONES DNS CONFIGURADES ==="
    echo ""

    if [ ! -s "${ZONES_FILE}" ]; then
        print_warning "No hi ha zones configurades"
        return
    fi

    echo "Zones Forward (A):"
    grep "^FORWARD:" "${ZONES_FILE}" 2>/dev/null | cut -d: -f2 | while read zone; do
        echo "  - $zone"
    done

    echo ""
    echo "Zones Reverse (PTR):"
    grep "^REVERSE:" "${ZONES_FILE}" 2>/dev/null | cut -d: -f2 | while read zone; do
        echo "  - $zone"
    done
    echo ""
}

afegir_zona() {
    echo ""
    print_info "=== AFEGIR ZONA DNS ==="
    echo ""

    echo "Tipus de zona:"
    echo "  1) Forward (A records)"
    echo "  2) Reverse (PTR records)"
    read -p "Selecciona opció [1-2]: " zone_type

    case $zone_type in
        1)
            read -p "Nom de la zona forward (ex: upf.edu): " zone_name
            if [ -z "$zone_name" ]; then
                print_error "El nom de la zona no pot estar buit"
                return 1
            fi

            if grep -q "^FORWARD:${zone_name}$" "${ZONES_FILE}" 2>/dev/null; then
                print_warning "La zona $zone_name ja existeix"
                return 1
            fi

            echo "FORWARD:${zone_name}" >> "${ZONES_FILE}"
            touch "${ZONES_DIR}/${zone_name}.hosts"
            print_success "Zona forward $zone_name afegida correctament"
            ;;
        2)
            read -p "Xarxa reverse (ex: 10.0.1 per 1.0.10.in-addr.arpa): " network
            if [ -z "$network" ]; then
                print_error "La xarxa no pot estar buida"
                return 1
            fi

            IFS='.' read -ra octets <<< "$network"
            if [ ${#octets[@]} -ne 3 ]; then
                print_error "Format incorrecte. Usa 3 octets (ex: 10.0.1)"
                return 1
            fi

            rev_zone="${octets[2]}.${octets[1]}.${octets[0]}.in-addr.arpa"

            if grep -q "^REVERSE:${rev_zone}$" "${ZONES_FILE}" 2>/dev/null; then
                print_warning "La zona reverse $rev_zone ja existeix"
                return 1
            fi

            echo "REVERSE:${rev_zone}" >> "${ZONES_FILE}"
            touch "${ZONES_DIR}/${rev_zone}.rev"
            print_success "Zona reverse $rev_zone afegida correctament"
            ;;
        *)
            print_error "Opció no vàlida"
            return 1
            ;;
    esac
}

eliminar_zona() {
    echo ""
    print_info "=== ELIMINAR ZONA DNS ==="
    echo ""

    listar_zones

    read -p "Nom complet de la zona a eliminar: " zone_name

    if [ -z "$zone_name" ]; then
        print_error "El nom de la zona no pot estar buit"
        return 1
    fi

    if grep -q "^FORWARD:${zone_name}$" "${ZONES_FILE}" 2>/dev/null; then
        # Fer backup abans d'eliminar
        if [ -f "${ZONES_DIR}/${zone_name}.hosts" ]; then
            backup_file="${BACKUPS_DIR}/${zone_name}.hosts.deleted.$(date +%Y%m%d_%H%M%S)"
            cp "${ZONES_DIR}/${zone_name}.hosts" "$backup_file"
            print_info "Backup guardat a: $backup_file"
        fi

        sed -i "/^FORWARD:${zone_name}$/d" "${ZONES_FILE}"
        rm -f "${ZONES_DIR}/${zone_name}.hosts"
        print_success "Zona forward $zone_name eliminada"
    elif grep -q "^REVERSE:${zone_name}$" "${ZONES_FILE}" 2>/dev/null; then
        # Fer backup abans d'eliminar
        if [ -f "${ZONES_DIR}/${zone_name}.rev" ]; then
            backup_file="${BACKUPS_DIR}/${zone_name}.rev.deleted.$(date +%Y%m%d_%H%M%S)"
            cp "${ZONES_DIR}/${zone_name}.rev" "$backup_file"
            print_info "Backup guardat a: $backup_file"
        fi

        sed -i "/^REVERSE:${zone_name}$/d" "${ZONES_FILE}"
        rm -f "${ZONES_DIR}/${zone_name}.rev"
        print_success "Zona reverse $zone_name eliminada"
    else
        print_error "La zona $zone_name no existeix"
        return 1
    fi
}

################################################################################
# Gestió de Registres
################################################################################

afegir_registres_massius() {
    echo ""
    print_info "=== ALTA MASSIVA DE REGISTRES DNS ==="
    echo ""

    echo "Format del fitxer d'entrada:"
    echo "  - Una línia per registre"
    echo "  - Format: IP HOSTNAME o HOSTNAME IP"
    echo "  - Exemple: 10.0.1.100 server01.upf.edu"
    echo "  - Exemple: web.upf.edu 10.0.1.200"
    echo ""

    read -p "Ruta al fitxer amb els registres: " input_file

    if [ ! -f "$input_file" ]; then
        print_error "El fitxer $input_file no existeix"
        return 1
    fi

    local count_success=0
    local count_errors=0
    local temp_log=$(mktemp)

    while IFS= read -r line || [ -n "$line" ]; do
        # Saltar línies buides i comentaris
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Llegir IP i hostname
        read -r field1 field2 <<< "$line"

        local ip=""
        local hostname=""

        # Determinar quin camp és IP i quin hostname
        if validate_ip "$field1"; then
            ip="$field1"
            hostname="$field2"
        elif validate_ip "$field2"; then
            ip="$field2"
            hostname="$field1"
        else
            print_error "Línia invàlida (no s'ha trobat IP vàlida): $line"
            echo "ERROR: $line" >> "$temp_log"
            ((count_errors++))
            continue
        fi

        if [ -z "$hostname" ]; then
            print_error "Línia invàlida (hostname buit): $line"
            echo "ERROR: $line" >> "$temp_log"
            ((count_errors++))
            continue
        fi

        # Extreure la zona del hostname
        local zone=$(echo "$hostname" | rev | cut -d. -f1,2 | rev)

        # Verificar que la zona existeix
        if ! grep -q "^FORWARD:${zone}$" "${ZONES_FILE}" 2>/dev/null; then
            print_warning "Zona $zone no configurada, s'afegeix automàticament"
            echo "FORWARD:${zone}" >> "${ZONES_FILE}"
            touch "${ZONES_DIR}/${zone}.hosts"
        fi

        # Afegir registre A
        local zone_file="${ZONES_DIR}/${zone}.hosts"

        # Comprovar si ja existeix
        if grep -q "^${ip}[[:space:]]\\+${hostname}" "$zone_file" 2>/dev/null; then
            print_warning "Registre ja existeix: $ip $hostname"
        else
            echo "${ip}	${hostname}" >> "$zone_file"
            print_success "Afegit registre A: $ip -> $hostname"
            ((count_success++))
        fi

        # Afegir registre PTR
        local rev_zone=$(get_reverse_zone "$ip")
        local ptr_host=$(get_ptr_host "$ip")

        # Crear zona reverse si no existeix
        if ! grep -q "^REVERSE:${rev_zone}$" "${ZONES_FILE}" 2>/dev/null; then
            print_warning "Zona reverse $rev_zone no configurada, s'afegeix automàticament"
            echo "REVERSE:${rev_zone}" >> "${ZONES_FILE}"
            touch "${ZONES_DIR}/${rev_zone}.rev"
        fi

        local rev_file="${ZONES_DIR}/${rev_zone}.rev"

        if grep -q "^${ptr_host}[[:space:]]\\+${hostname}" "$rev_file" 2>/dev/null; then
            print_warning "Registre PTR ja existeix: $ptr_host -> $hostname"
        else
            echo "${ptr_host}	${hostname}" >> "$rev_file"
            print_success "Afegit registre PTR: $ptr_host.$rev_zone -> $hostname"
        fi

    done < "$input_file"

    echo ""
    print_info "=== RESUM ==="
    print_success "Registres afegits: $count_success"
    if [ $count_errors -gt 0 ]; then
        print_error "Errors: $count_errors"
        print_info "Revisa el fitxer de log: $temp_log"
    else
        rm -f "$temp_log"
    fi
}

eliminar_registres_massius() {
    echo ""
    print_info "=== BAIXA MASSIVA DE REGISTRES DNS ==="
    echo ""

    echo "Format del fitxer d'entrada:"
    echo "  - Una línia per registre"
    echo "  - Format: IP HOSTNAME o HOSTNAME IP"
    echo ""

    read -p "Ruta al fitxer amb els registres: " input_file

    if [ ! -f "$input_file" ]; then
        print_error "El fitxer $input_file no existeix"
        return 1
    fi

    local count_success=0
    local count_errors=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Saltar línies buides i comentaris
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Llegir IP i hostname
        read -r field1 field2 <<< "$line"

        local ip=""
        local hostname=""

        # Determinar quin camp és IP i quin hostname
        if validate_ip "$field1"; then
            ip="$field1"
            hostname="$field2"
        elif validate_ip "$field2"; then
            ip="$field2"
            hostname="$field1"
        else
            print_error "Línia invàlida: $line"
            ((count_errors++))
            continue
        fi

        # Extreure la zona del hostname
        local zone=$(echo "$hostname" | rev | cut -d. -f1,2 | rev)
        local zone_file="${ZONES_DIR}/${zone}.hosts"

        # Eliminar registre A
        if [ -f "$zone_file" ]; then
            if grep -q "^${ip}[[:space:]]\\+${hostname}" "$zone_file"; then
                sed -i "/^${ip}[[:space:]]\\+${hostname}/d" "$zone_file"
                print_success "Eliminat registre A: $ip -> $hostname"
                ((count_success++))
            else
                print_warning "Registre A no trobat: $ip $hostname"
            fi
        fi

        # Eliminar registre PTR
        local rev_zone=$(get_reverse_zone "$ip")
        local ptr_host=$(get_ptr_host "$ip")
        local rev_file="${ZONES_DIR}/${rev_zone}.rev"

        if [ -f "$rev_file" ]; then
            if grep -q "^${ptr_host}[[:space:]]\\+${hostname}" "$rev_file"; then
                sed -i "/^${ptr_host}[[:space:]]\\+${hostname}/d" "$rev_file"
                print_success "Eliminat registre PTR: $ptr_host -> $hostname"
            else
                print_warning "Registre PTR no trobat: $ptr_host $hostname"
            fi
        fi

    done < "$input_file"

    echo ""
    print_info "=== RESUM ==="
    print_success "Registres eliminats: $count_success"
    if [ $count_errors -gt 0 ]; then
        print_error "Errors: $count_errors"
    fi
}

################################################################################
# Sistema de Backups
################################################################################

fer_backup() {
    echo ""
    print_info "=== BACKUP DE ZONES DNS ==="
    echo ""

    local date_suffix=$(date +%Y%m%d)
    local backup_count=0

    # Backup de zones forward
    for zone_file in "${ZONES_DIR}"/*.hosts; do
        if [ -f "$zone_file" ]; then
            local zone_name=$(basename "$zone_file" .hosts)
            local backup_name="${zone_name}.upf.edu.hosts.${date_suffix}"
            cp "$zone_file" "${BACKUPS_DIR}/${backup_name}"
            print_success "Backup creat: ${backup_name}"
            ((backup_count++))
        fi
    done

    # Backup de zones reverse
    for rev_file in "${ZONES_DIR}"/*.rev; do
        if [ -f "$rev_file" ]; then
            local rev_name=$(basename "$rev_file" .rev)
            # Format: x.y.z.rev.YYYYMMDD
            local backup_name="${rev_name}.rev.${date_suffix}"
            cp "$rev_file" "${BACKUPS_DIR}/${backup_name}"
            print_success "Backup creat: ${backup_name}"
            ((backup_count++))
        fi
    done

    # Backup de configuració
    if [ -f "${ZONES_FILE}" ]; then
        cp "${ZONES_FILE}" "${BACKUPS_DIR}/zones.conf.${date_suffix}"
        print_success "Backup de configuració creat"
        ((backup_count++))
    fi

    echo ""
    print_success "Total backups creats: $backup_count"
    print_info "Ubicació: ${BACKUPS_DIR}/"
}

listar_backups() {
    echo ""
    print_info "=== BACKUPS DISPONIBLES ==="
    echo ""

    if [ ! -d "${BACKUPS_DIR}" ] || [ -z "$(ls -A ${BACKUPS_DIR} 2>/dev/null)" ]; then
        print_warning "No hi ha backups disponibles"
        return
    fi

    ls -lh "${BACKUPS_DIR}" | tail -n +2 | awk '{print $9, "("$5")"}'
}

################################################################################
# Menú Principal
################################################################################

show_menu() {
    clear
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         GESTOR INTERACTIU DE REGISTRES DNS               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  GESTIÓ DE REGISTRES:"
    echo "    1) Afegir registres massius (alta)"
    echo "    2) Eliminar registres massius (baixa)"
    echo ""
    echo "  GESTIÓ DE ZONES:"
    echo "    3) Afegir zona"
    echo "    4) Eliminar zona"
    echo "    5) Llistar zones"
    echo ""
    echo "  BACKUPS:"
    echo "    6) Fer backup de totes les zones"
    echo "    7) Llistar backups disponibles"
    echo ""
    echo "  ALTRES:"
    echo "    8) Generar fitxer d'exemple"
    echo "    9) Sortir"
    echo ""
    echo "════════════════════════════════════════════════════════════"
}

generar_exemple() {
    local example_file="./dns/exemple_registres.txt"

    cat > "$example_file" << 'EOF'
# Fitxer d'exemple per alta/baixa massiva de registres DNS
# Format: IP HOSTNAME o HOSTNAME IP (ambdós formats són vàlids)
#
# Línes que comencen amb # són comentaris i seran ignorades

# Servidors
10.0.1.10 server01.upf.edu
10.0.1.11 server02.upf.edu
server03.upf.edu 10.0.1.12

# Serveis web
web01.upf.edu 10.0.2.10
10.0.2.11 web02.upf.edu

# Bases de dades
10.0.3.20 db-master.upf.edu
10.0.3.21 db-slave.upf.edu

# DHCP (rang dinàmic - només exemple)
10.0.4.100 workstation01.upf.edu
10.0.4.101 workstation02.upf.edu
EOF

    print_success "Fitxer d'exemple creat: $example_file"
    echo ""
    print_info "Pots editar aquest fitxer i usar-lo a les opcions 1 o 2"
}

main() {
    init_structure

    while true; do
        show_menu
        read -p "Selecciona una opció [1-9]: " choice

        case $choice in
            1)
                afegir_registres_massius
                ;;
            2)
                eliminar_registres_massius
                ;;
            3)
                afegir_zona
                ;;
            4)
                eliminar_zona
                ;;
            5)
                listar_zones
                ;;
            6)
                fer_backup
                ;;
            7)
                listar_backups
                ;;
            8)
                generar_exemple
                ;;
            9)
                echo ""
                print_success "Adéu!"
                exit 0
                ;;
            *)
                print_error "Opció no vàlida"
                ;;
        esac

        echo ""
        read -p "Prem ENTER per continuar..."
    done
}

# Executar programa principal
main
