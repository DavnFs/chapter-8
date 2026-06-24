#!/bin/bash
set -x

N=100

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')
ENDPOINT="${NODE_IP}:${NODE_PORT}"

START=$(date +%s)
for i in $(seq ${N}); do
	curl "http://${ENDPOINT}/sum?a=1&b=2"
done
END=$(date +%s)

RUNTIME=$((END-START))
AVG=$((RUNTIME/N))

test ${AVG} -lt 1
