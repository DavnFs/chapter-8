#!/bin/bash
set -x

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="ExternalIP")].address }')

# Fallback ke InternalIP jika ExternalIP tidak tersedia (minikube)
if [ -z "$NODE_IP" ]; then
  NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
fi

NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')

# ============================================================
# TRICK: TUNGGU SAMPAI SPRING BOOT BENAR-BENAR SELESAI BOOTING
# ============================================================
echo "Menunggu Spring Boot siap menerima koneksi di http://${NODE_IP}:${NODE_PORT}..."
until curl -s --connect-timeout 2 http://${NODE_IP}:${NODE_PORT} > /dev/null; do
    echo "Aplikasi masih loading context internal, menunggu 3 detik lagi..."
    sleep 3
done
echo "Aplikasi terdeteksi aktif! Memulai Acceptance Test..."
# ============================================================

./gradlew acceptanceTest -Dcalculator.url=http://${NODE_IP}:${NODE_PORT}
