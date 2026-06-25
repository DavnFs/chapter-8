#!/bin/bash
set -x

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')

echo "Menunggu Spring Boot siap di http://${NODE_IP}:${NODE_PORT}..."
until curl -s --connect-timeout 2 http://${NODE_IP}:${NODE_PORT} > /dev/null; do
     echo "Aplikasi masih loading context internal, menunggu 3 detik lagi..."
     sleep 3
done

echo "Aplikasi aktif! Memulai Acceptance Test..."
./gradlew acceptanceTest -Dcalculator.url=http://${NODE_IP}:${NODE_PORT}
