# Chapter 8: Continuous Delivery Pipeline — Execution Plan

## Goal
Run the complete CD pipeline from Chapter 8 using WSL Ubuntu: build, test, containerize, and deploy the Calculator app to Kubernetes (staging + production) via Jenkins.

---

## Phase 1: WSL & Base Tools Setup

- [ ] **1.1** Install/verify WSL Ubuntu 22.04+ on Windows
  ```powershell
  wsl --install -d Ubuntu-22.04
  ```
  → Verify: `wsl` drops into Ubuntu shell

- [ ] **1.2** Install Docker Engine inside WSL (not Docker Desktop)
  ```bash
  sudo apt update && sudo apt install -y docker.io
  sudo usermod -aG docker $USER
  newgrp docker
  ```
  → Verify: `docker run hello-world`

- [ ] **1.3** Install Java 11 JDK
  ```bash
  sudo apt install -y openjdk-11-jdk
  java -version
  ```
  → Verify: `java -version` shows 11.x

- [ ] **1.4** Install kubectl
  ```bash
  sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install kubectl /usr/local/bin/
  ```
  → Verify: `kubectl version --client`

---

## Phase 2: Local Kubernetes Clusters (Minikube)

- [ ] **2.1** Install Minikube
  ```bash
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  ```

- [ ] **2.2** Create **staging** cluster
  ```bash
  minikube start -p staging --driver=docker
  kubectl config rename-context staging staging
  ```
  → Verify: `kubectl --context staging get nodes`

- [ ] **2.3** Create **production** cluster
  ```bash
  minikube start -p production --driver=docker
  kubectl config rename-context production production
  ```
  → Verify: `kubectl --context production get nodes`

- [ ] **2.4** Verify both contexts exist
  ```bash
  kubectl config get-contexts
  ```
  → Verify: see `staging` and `production` listed

---

## Phase 3: Jenkins Setup (Docker container)

- [ ] **3.1** Run Jenkins in Docker with Docker socket mounted
  ```bash
  docker run -d --name jenkins \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $HOME/.kube:/var/jenkins_home/.kube \
    --user root \
    jenkins/jenkins:lts
  ```
  → Verify: open `http://localhost:8080` in browser

- [ ] **3.2** Complete Jenkins initial setup (unlock + install suggested plugins)

- [ ] **3.3** Install **Build Timestamp Plugin** via Manage Jenkins → Plugins
  - Configure timestamp: Manage Jenkins → Configure System → Build Timestamp → `yyyyMMdd-HHmm`

- [ ] **3.4** Add **Docker Hub credentials** in Jenkins
  - Manage Jenkins → Credentials → Add (Username/Password with your Docker Hub account)

---

## Phase 4: Docker Hub Prep

- [ ] **4.1** Create Docker Hub account (if not exists) at https://hub.docker.com
- [ ] **4.2** Update `Jenkinsfile` and `deployment.yaml` image names to use your Docker Hub username instead of `leszko/calculator`
  - Replace `leszko/calculator` → `<your-username>/calculator`

→ Verify: `grep -r "<your-username>" sample1/`

---

## Phase 5: Run the Calculator Pipeline (sample1)

- [ ] **5.1** Create a new Jenkins Pipeline job pointing to the local `sample1/` directory (or a Git repo if you pushed it)
  - Pipeline script from SCM or Pipeline script (paste Jenkinsfile)

- [ ] **5.2** Run the pipeline and watch stages execute:
  ```
  Compile → Unit test → Code coverage → Static code analysis →
  Build → Docker build → Docker push → Update version →
  Deploy to staging → Acceptance test → Release → Smoke test
  ```

- [ ] **5.3** Fix any failures (typical issues):
  - Gradle wrapper permissions: `chmod +x gradlew`
  - Docker socket permissions in Jenkins
  - kubectl can't reach Minikube: copy kubeconfig into Jenkins container
  - Acceptance test timeout: increase `sleep` value in Jenkinsfile

→ Verify: all stages green in Jenkins Blue Ocean / Stage View

---

## Phase 6: Run the Hello World Pipeline (exercise2)

- [ ] **6.1** Create a second Jenkins Pipeline job for `exercise2/`
- [ ] **6.2** Update image names to your Docker Hub username in `exercise2/`
- [ ] **6.3** Run and verify all stages pass (Docker build → push → deploy → performance test)

→ Verify: `kubectl --context staging get pods` shows hello pods running

---

## Phase 7: Verification & Cleanup

- [ ] **7.1** Verify Calculator app responds on staging
  ```bash
  kubectl --context staging get svc calculator-service
  # Get NodePort, then:
  minikube -p staging service calculator-service --url
  curl <url>/sum?a=1&b=2
  ```
  → Verify: returns `3`

- [ ] **7.2** Verify Calculator app responds on production
  ```bash
  minikube -p production service calculator-service --url
  curl <url>/sum?a=5&b=7
  ```
  → Verify: returns `12`

- [ ] **7.3** Verify Docker images are versioned in Docker Hub (not just `:latest`)

- [ ] **7.4** Cleanup (when done)
  ```bash
  minikube delete -p staging
  minikube delete -p production
  docker stop jenkins && docker rm jenkins
  ```

---

## Notes

- **Minikube limitation**: NodePort services are accessed via `minikube service --url`, not external IPs. The `acceptance-test.sh` and `smoke-test.sh` scripts use `kubectl get nodes` to find ExternalIP, which won't work with Minikube. You'll need to modify them:
  ```bash
  NODE_IP=$(minikube -p staging ip)
  NODE_PORT=$(kubectl get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')
  ```

- **Docker-in-Docker**: Jenkins running in Docker needs the Docker socket to build images. The `-v /var/run/docker.sock:/var/run/docker.sock` mount handles this.

- **kubeconfig sharing**: The `-v $HOME/.kube:/var/jenkins_home/.kube` mount gives Jenkins access to your Minikube clusters. You may need to fix paths inside the container.

- **WSL2 networking**: If you hit networking issues between WSL and browser, try `wsl hostname -I` to get the WSL IP and replace `localhost`.

---

## Troubleshooting & Common Issues Encountered

Berdasarkan pengalaman sebelumnya, berikut adalah kompilasi masalah yang telah terjadi dan solusinya (Sangat disarankan untuk mengantisipasinya dari awal):

1. **Error `./gradlew: not found` (Walaupun file ada)**: 
   - **Penyebab:** Format baris file di Windows berubah menjadi CRLF (`\r\n`), sehingga Linux membaca *hashbang* interpreter sebagai `sh\r` yang tidak dikenali.
   - **Solusi:** Lakukan konversi CRLF menjadi LF pada file `gradlew` dan `*.sh` di dalam repository. Sangat direkomendasikan mengonfigurasi Git dengan `git config --global core.autocrlf false` sebelum melakukan `git clone` di Windows.

2. **Error `Unsupported class file major version 65` (saat Gradle compile)**:
   - **Penyebab:** Jenkins berjalan dengan **Java 21** (major version 65), tetapi kode bawaan menggunakan Gradle `7.3.1` yang maksimal hanya men-*support* Java 17.
   - **Solusi:** Upgrade versi Gradle ke `8.5` di dalam `gradle/wrapper/gradle-wrapper.properties`.

3. **Plugin Error Spring Boot di Java 21**:
   - **Penyebab:** Setelah upgrade Gradle ke 8.5, kompiler akan tetap gagal (meskipun `sourceCompatibility='11'`) karena Spring Boot `2.6.x` dan plugin-nya tidak kompatibel dengan Java 21.
   - **Solusi:** Edit file `build.gradle`, naikkan versi plugin `org.springframework.boot` menjadi `2.7.18` dan `io.spring.dependency-management` menjadi `1.1.4`.

4. **Network Timeout / Could not resolve host di dalam Jenkins Pipeline**:
   - **Penyebab:** Koneksi internet / DNS di dalam jaringan internal Docker (terutama jika berjalan di backend WSL 2) terkadang mengalami *disconnect* atau *timeout* saat men-*download* dependency.
   - **Solusi:** Restart WSL (`wsl --shutdown`) atau yang paling stabil adalah dengan menjalankan / menginstall **Docker Desktop** saja, lalu merestart container Jenkins. Atau cukup tekan tombol `Build Now` sekali lagi karena seringkali ini hanya gangguan sesaat.

5. **`docker login` / Kredensial Docker Hub di Jenkinsfile**:
   - **Penyebab:** Jenkinsfile lama mungkin menggunakan `docker push` secara langsung tanpa proses login.
   - **Solusi:** Tambahkan blok `withCredentials` di *stage* Docker push dalam `Jenkinsfile` dan daftarkan *Global Credentials* di Jenkins dengan ID yang sesuai (misal: `dockerhub`).

6. **Error Permission Denied `gradlew` di Jenkins Pipeline**:
   - **Penyebab:** Jenkins mengambil file `gradlew` dari GitHub yang belum memiliki akses _executable_ (`+x`).
   - **Solusi:** Tambahkan command `sh "chmod +x gradlew"` tepat sebelum mengeksekusi `./gradlew compileJava` di *stage* pertama `Jenkinsfile`.
