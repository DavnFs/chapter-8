#!/bin/bash
set -x
set -e # PENTING: Hentikan script segera jika ada command yang gagal (seperti curl error)

N=100

NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
NODE_PORT=$(kubectl get svc hello -o=jsonpath='{.spec.ports[0].nodePort}')
ENDPOINT="${NODE_IP}:${NODE_PORT}"

START=$(date +%s)
for i in $(seq ${N}); do
    # -s (silent) dan -o /dev/null agar log Jenkins tidak penuh dengan progress bar curl
    curl -s -o /dev/null http://${ENDPOINT}/hello
done
END=$(date +%s)

RUNTIME=$((END-START))
echo "Total waktu eksekusi untuk $N request: ${RUNTIME} detik"

# PERBAIKAN LOGIKA:
# Karena bash tidak bisa menghitung desimal, kita ubah persamaannya.
# Jika Rata-rata < 1 detik, maka Total Waktu (RUNTIME) harus < N (100 detik).
test ${RUNTIME} -lt ${N}
