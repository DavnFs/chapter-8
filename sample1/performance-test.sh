#!/bin/bash
set -x

N=100

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')
ENDPOINT="${NODE_IP}:${NODE_PORT}"

# 1. Gunakan milidetik (%3N) agar Bash bisa menghitung presisi rata-rata
START=$(date +%s%3N)
for i in $(seq ${N}); do
	# 2. Tambahkan -s (silent) dan -o /dev/null agar log Jenkins tetap bersih
	curl -s -o /dev/null "http://${ENDPOINT}/sum?a=1&b=2"
done
END=$(date +%s%3N)

TOTAL_MS=$((END-START))
AVG_MS=$((TOTAL_MS/N))

echo "========== PERFORMANCE REPORT =========="
echo "Total runtime    : ${TOTAL_MS} ms"
echo "Average response : ${AVG_MS} ms per request"
echo "========================================"

# 3. Validasi: Rata-rata response harus di bawah 1000ms (1 detik)
test ${AVG_MS} -lt 1000
