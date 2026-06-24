#!/bin/bash
set -x

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="ExternalIP")].address }')

# FIX: Fallback ke InternalIP jika ExternalIP tidak tersedia (Khas Minikube)
if [ -z "$NODE_IP" ]; then
  NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
fi

NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')

./gradlew smokeTest -Dcalculator.url=http://${NODE_IP}:${NODE_PORT}
