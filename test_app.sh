#!/bin/bash

# Script de test per validar funcions del gestor DNS

source <(grep -A 1000 "^# Colors per la interfície" app.sh | grep -B 1000 "^main()" | head -n -1)

echo "=== TEST VALIDACIÓ D'IPs ==="
echo -n "Test IP vàlida (10.0.1.1): "
if validate_ip "10.0.1.1"; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

echo -n "Test IP invàlida (256.1.1.1): "
if validate_ip "256.1.1.1"; then
    echo "✗ FAIL"
else
    echo "✓ PASS"
fi

echo -n "Test IP invàlida (10.0.1): "
if validate_ip "10.0.1"; then
    echo "✗ FAIL"
else
    echo "✓ PASS"
fi

echo ""
echo "=== TEST ZONA REVERSE ==="
reverse=$(get_reverse_zone "10.0.1.100")
echo "IP 10.0.1.100 -> Zona reverse: $reverse"
if [ "$reverse" == "1.0.10.in-addr.arpa" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL (esperat: 1.0.10.in-addr.arpa)"
fi

echo ""
echo "=== TEST PTR HOST ==="
ptr=$(get_ptr_host "10.0.1.100")
echo "IP 10.0.1.100 -> PTR host: $ptr"
if [ "$ptr" == "100" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL (esperat: 100)"
fi

echo ""
echo "=== TEST ESTRUCTURA DE DIRECTORIS ==="
if [ -d "./dns/zones" ]; then
    echo "✓ Directori zones existeix"
else
    echo "✗ Directori zones no existeix"
fi

if [ -d "./dns/backups" ]; then
    echo "✓ Directori backups existeix"
else
    echo "✗ Directori backups no existeix"
fi

if [ -d "./dns/config" ]; then
    echo "✓ Directori config existeix"
else
    echo "✗ Directori config no existeix"
fi

echo ""
echo "=== TESTS COMPLETATS ==="
