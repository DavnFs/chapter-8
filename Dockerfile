FROM jenkins/jenkins:lts
USER root

# 1. Install Docker CLI & Curl
RUN apt-get update && apt-get install -y docker.io curl

# 2. Install kubectl
RUN curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# 3. Skrip startup otomatis: Ambil config dari host, salin agar writable, lalu set IP Minikube
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'mkdir -p /root/.kube' >> /entrypoint.sh && \
    echo 'if [ -f /host/.kube/config ]; then' >> /entrypoint.sh && \
    echo '  cp /host/.kube/config /root/.kube/config' >> /entrypoint.sh && \
    echo '  kubectl config set-cluster staging --server=https://192.168.49.2:8443' >> /entrypoint.sh && \
    echo '  kubectl config set-cluster production --server=https://192.168.58.2:8443' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo 'exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
