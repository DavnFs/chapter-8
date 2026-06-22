# Lecture Presentation Flow — Chapter 8: Continuous Delivery Pipeline

## Overview

This document is your **speaker guide**. Each slide includes:
- **Show** — what's on screen / what command to run
- **Do** — the action you take (click, type, etc.)
- **Say** — what to explain to the audience

---

## Slide 1 — Title

**Show:** Title slide with "Continuous Delivery Pipeline — Chapter 8"

**Say:** "Today we're looking at Chapter 8: a complete Continuous Delivery pipeline that takes code from a developer's machine all the way to production on Kubernetes, fully automated."

---

## Slide 2 — What is Continuous Delivery?

**Show:** Definition slide — "CD = code always in deployable state"

**Say:** "Continuous Delivery means every code change that passes automated tests is ready to be released. The key idea: you can deploy at any time with the push of a button. It's not Continuous Deployment — that's where every change auto-deploys. CD keeps a manual gate before production."

---

## Slide 3 — The Traditional Problem

**Show:** Side-by-side comparison of "Before CD" vs "After CD"

| Before CD | After CD |
|-----------|----------|
| Code on dev machine for days | Every commit verified |
| Integration hell | Continuous integration |
| Manual steps → errors | Automated pipeline |
| Slow feedback (days) | Fast feedback (minutes) |

**Say:** "Without CD, code sits on a developer's machine for days. When you merge, everything breaks — integration hell. Deployment is manual, error-prone, and feedback takes forever. CD solves all of this by automating the entire path."

**Ask the audience:** "How many have experienced 'works on my machine' syndrome?" (This gets engagement.)

---

## Slide 4 — Architecture Overview

**Show:** The three projects table

| Project | Language | What it does |
|---------|----------|-------------|
| **sample1** | Java + Spring Boot | Full CD pipeline — Calculator REST API |
| **exercise1** | Python + Flask | Hello World + perf test (standalone) |
| **exercise2** | Python + Flask | Hello World + its own 5-stage pipeline |

**Say:** "Three projects in this chapter. The star is sample1 — a Java Calculator app with an 11-stage pipeline. Exercise 1 is a warm-up: a Python Hello World with a performance test. Exercise 2 puts that Hello World into its own CD pipeline."

**Key point to emphasize:** "The same pipeline pattern applies whether your app is Java or Python."

---

## Slide 5 — The Calculator App (Live Code Tour)

**Show:** Open the code:
```bash
cd sample1/src/main/java/com/leszko/calculator/
cat CalculatorApplication.java
cat CalculatorController.java
cat Calculator.java
```

**Say (pointing at each file):**

- **CalculatorApplication.java** — "Standard Spring Boot entry point. Two things to notice: `@EnableCaching` activates caching, and the `hazelcastClientConfig` bean connects to a Hazelcast server in Kubernetes."

- **CalculatorController.java** — "Single REST endpoint: `GET /sum?a=1&b=2` returns the sum as text. Dead simple."

- **Calculator.java** — "This is the interesting part. `@Cacheable("sum")` caches results in Hazelcast. See `Thread.sleep(3000)`? That simulates an expensive computation on the first call. The second call with the same numbers returns instantly from cache."

**Live demo:** Run it locally if possible:
```bash
cd sample1 && ./gradlew bootRun
```
Then in another terminal:
```bash
curl "http://localhost:8080/sum?a=3&b=4"
# Takes ~3 seconds — "See how it's slow?"
curl "http://localhost:8080/sum?a=3&b=4"
# Instant! — "That's caching. Now imagine 3 pod replicas sharing this cache."
```

**Say:** "Why does this matter for CD? Because the cache is **distributed** via Hazelcast — all 3 pods share it. Our pipeline needs to deploy Hazelcast alongside the app."

---

## Slide 6 — Pipeline Overview (The Big Picture)

**Show:** The full 11-stage pipeline — either the Jenkinsfile or a diagram:

```
Compile → Unit test → Coverage → Static analysis → Package →
Docker build → Docker push → Update version →
Deploy to staging → Acceptance test → Release → Smoke test
```

**Say:** "Here's the full 11-stage pipeline. Let me walk through each group..."

**Group them into sections for the audience:**

1. **CODE QUALITY** (stages 1-4): Compile, Unit test, Coverage, Static analysis
2. **BUILD & SHIP** (stages 5-7): Package, Docker build, Docker push
3. **DEPLOY & VERIFY** (stages 8-11): Update version, Deploy to staging, Acceptance test, Release, Smoke test

---

## Slide 7 — The Jenkinsfile (Live Code)

**Show:** Open the Jenkinsfile:
```bash
cat sample1/Jenkinsfile
```

**Say:** "This is a declarative Jenkins pipeline written in Groovy. Two important things at the top:"
- `agent any` — "Runs on any available Jenkins agent"
- `triggers { pollSCM('* * * * *') }` — "Polls Git every minute for changes. Any commit triggers the pipeline."

**Walk through stages one by one, pointing at each in the file.**

---

## Slide 8 — Stages 1-4: Code Quality Gates

**Show:** Running the quality stages:
```bash
cd sample1
./gradlew compileJava
./gradlew test
./gradlew jacocoTestReport
./gradlew checkstyleMain
```

**Say (demonstrate each):**

- **Compile** — "Does it compile? Java won't run if it doesn't. Fastest check."
- **Unit test** — "Runs JUnit 4 tests. The test checks `calculator.sum(2,3) == 5`. If this fails, the pipeline stops immediately."
- **Code coverage** — "JaCoCo measures what percentage of code is covered by tests. The pipeline enforces a minimum of 20% line coverage. This prevents untested code from reaching production."
- **Static analysis** — "Checkstyle enforces coding conventions. This one checks `ConstantName` — making sure constants are named in UPPER_CASE."

**Key teaching point:** "These four stages run BEFORE any Docker image is built. Fail fast — catch issues when they're cheap to fix."

**Show the build.gradle:**
```bash
cat build.gradle | grep -A5 jacocoTestCoverageVerification
```

**Say:** "See `minimum = 0.2`? That's the 20% threshold. You can set this to whatever makes sense for your project."

---

## Slide 9 — Stages 5-7: From JAR to Docker Image

**Show:** Build and Dockerize:
```bash
cd sample1
ls build/libs/
# Shows: calculator-0.0.1-SNAPSHOT.jar
cat Dockerfile
```

**Dockerfile content:**
```dockerfile
FROM openjdk:11-jre
COPY build/libs/calculator-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Say:** "Stage 5 packages the JAR. Stage 6 wraps it in a Docker container. The image is tagged with a **timestamp**: `leszko/calculator:20250315-1430`. Why a timestamp?"

**Ask the audience:** "Why not just `:latest`?" (Wait for answers.)

**Answer:** "Because `:latest` is mutable. If you need to roll back, you don't know what `:latest` points to. A timestamp is unique and traceable — you always know exactly which version is running."

**Show Docker Hub (optional):** If you have images pushed, show them.

---

## Slide 10 — Stage 8: The Version Update Trick

**Show:** The `{{VERSION}}` placeholder pattern:
```bash
grep "{{VERSION}}" sample1/deployment.yaml
```

**Say:** "Our deployment.yaml lives in Git. It can't have a hardcoded version number because we don't know the timestamp until the pipeline runs. Solution: use `{{VERSION}}` as a placeholder."

**Show the sed command:**
```bash
sed 's/{{VERSION}}/20250315-1430/g' deployment.yaml
```

**Say:** "In the pipeline, after the Docker push produces a real timestamp, `sed` replaces the placeholder. Then the manifest is applied to Kubernetes. Clean, simple, no template engine needed."

---

## Slide 11 — Stages 9-10: Deploy to Staging

**Show:** Deploy to staging:
```bash
kubectl config use-context staging
kubectl apply -f hazelcast.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

**Say (run each command and explain):**

- `use-context staging` — "Switch kubectl to talk to the staging cluster."
- `apply -f hazelcast.yaml` — "Deploy Hazelcast — our distributed cache. This runs as its own pod."
- `apply -f deployment.yaml` — "Deploy 3 Calculator pods. The image tag is the timestamp from stage 6."
- `apply -f service.yaml` — "Expose the app via NodePort so we can reach it."

**Wait... then show acceptance test:**
```bash
sleep 60
# Check pods are running
kubectl get pods
# Run Cucumber tests
./gradlew acceptanceTest -Dcalculator.url=http://<node-ip>:<node-port>
```

**Say:** "We wait 60 seconds for Kubernetes to pull the image and start the pods. Then the Cucumber acceptance test runs — it makes actual HTTP calls to the deployed service and checks it returns the correct sum."

**Show the Cucumber feature:**
```bash
cat src/test/resources/feature/calculator.feature
```

**Say:** "This is Gherkin syntax — plain English that non-developers can read: 'Given I have two numbers... When the calculator sums them... Then I receive 3 as a result.'"

**Important:** "If this test fails, the pipeline stops. The bad code never reaches production."

---

## Slide 12 — Stage 11: Release to Production

**Show:** Deploy to production:
```bash
kubectl config use-context production
kubectl apply -f hazelcast.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
sleep 60
./gradlew smokeTest -Dcalculator.url=http://<node-ip>:<node-port>
```

**Say:** "This is identical to the staging deployment — same image, same manifests. The image was already tested on staging, so we know it works."

**Key principle (emphasize this):** "**The same Docker image that passed acceptance tests on staging is deployed to production. We never rebuild.** If it passed staging, it's blessed for production."

"The smoke test is a quick sanity check — same Cucumber tests, just making sure the production pods actually started and respond."

---

## Slide 13 — The Two-Cluster Strategy

**Show:** The cluster architecture diagram:
```
                    +-------------------+
                    |   Jenkins Pipeline|
                    +--------+----------+
                             |
              +--------------+--------------+
              |                             |
         [staging]                    [production]
              |                             |
         Calculator (3 pods)          Calculator (3 pods)
         Hazelcast                    Hazelcast
```

**Say:** "Two Minikube clusters. Staging is the testing ground — it catches issues before users see them. Production is the live environment."

**Ask the audience:** "Why two separate clusters instead of two namespaces in one cluster?"

**After answers:** "Isolation. If staging causes a resource problem, it takes down your production too. Separate clusters mean staging can't affect production. And it mimics real infrastructure — most companies have dev, staging, and production in separate clusters."

---

## Slide 14 — Hazelcast: Distributed Caching (Live Demo)

**Show:** The caching in action:
```bash
# Terminal 1: Deploy to staging and test
kubectl --context staging get pods -w

# Terminal 2: After pods are up
NODE_IP=$(minikube -p staging ip)
NODE_PORT=$(kubectl --context staging get svc calculator-service -o=jsonpath='{.spec.ports[0].nodePort}')
time curl "$NODE_IP:$NODE_PORT/sum?a=7&b=8"
# ~3 seconds — slow
time curl "$NODE_IP:$NODE_PORT/sum?a=7&b=8"
# Instantly — cached!
```

**Say:** "The first request takes 3 seconds because it simulates an expensive computation. But that result gets stored in Hazelcast. The second request is instant."

"Because Hazelcast is distributed, all 3 Calculator pods share the same cache. If pod 1 computes `2+3=5`, pod 2 can retrieve that result instantly without recomputing."

**Show the Hazelcast pod:**
```bash
kubectl --context staging get pods | grep hazelcast
```

**Say:** "Hazelcast runs as its own pod. The Calculator connects to it using the Kubernetes service DNS name 'hazelcast:5701'."

---

## Slide 15 — Exercise 1: Performance Test (Warm-Up)

**Show:** Open and run the Python Hello World:
```bash
cd exercise1
python3 app.py &
curl http://localhost:5000/hello
# Returns: "Hello World!"
```

**Say:** "Exercise 1 introduces a simple Python Flask app. It returns 'Hello World!' on `/hello`. The task: write a performance test."

**Show the performance test script:**
```bash
cat performance-test.sh
```

**Say:** "This script sends 100 requests, measures total time, and checks that the average response is under 1 second. Simple but teaches the concept: **before you containerize, know your baseline performance**."

**Run the perf test:**
```bash
chmod +x performance-test.sh
./performance-test.sh localhost:5000
# Should pass — exit code 0
echo $?
# Shows: 0 (pass)
```

---

## Slide 16 — Exercise 2: Hello World Pipeline

**Show:** The exercise2 structure:
```bash
cd exercise2
cat app.py
cat Dockerfile
cat deployment.yaml
cat Jenkinsfile
```

**Say:** "Exercise 2 puts that Hello World into its own CD pipeline. It's like sample1 but simplified — only 5 stages because Python doesn't need compile/coverage/static analysis."

**Show the pipeline flow:**
```
Docker build → Docker push → Update version → Deploy to staging → Performance test
```

**Say:** "No compile stage (Python is interpreted). No separate acceptance/smoke test — a single performance test does both. And it only deploys to staging, not production."

**Show the key difference in the Jenkinsfile:**
```bash
grep -c "stage(" exercise2/Jenkinsfile
# 5 stages
grep -c "stage(" sample1/Jenkinsfile
# 11 stages
```

**Say:** "Same CD principles, smaller scope. This shows that CD pipelines aren't one-size-fits-all — you adapt them to your application."

---

## Slide 17 — Running the Full Pipeline (Live Demo)

**Show:** The Jenkins pipeline running:

1. Open Jenkins at `http://localhost:8080`
2. Show the Blue Ocean view or Stage View
3. Run the pipeline
4. Watch stages turn green one by one

**Narrate each stage as it runs:**
- "Compile... green. Tests passing..."
- "JaCoCo checking coverage..."
- "Checkstyle verifying code style..."
- "Docker building the image..."
- "Pushing to Docker Hub..."
- "Deploying to staging..."
- "Waiting 60 seconds for pods..."
- "Running acceptance tests..."
- "Tests passed! Releasing to production..."
- "Smoke tests passed! Pipeline complete."

**Show the final state:**
```bash
kubectl --context staging get svc calculator-service
kubectl --context production get svc calculator-service
```

**Show Docker Hub:** Open `https://hub.docker.com/r/<your-username>/calculator` and show the versioned tags.

---

## Slide 18 — Verification: Test Both Clusters

**Show:** Verify the app on both clusters:
```bash
# Terminal 1 — staging
STAGING_URL=$(minikube -p staging service calculator-service --url)
curl "$STAGING_URL/sum?a=1&b=2"
# Returns: 3

# Terminal 2 — production
PROD_URL=$(minikube -p production service calculator-service --url)
curl "$PROD_URL/sum?a=5&b=7"
# Returns: 12
```

**Say:** "Both clusters are running the Calculator. Staging and production both serve requests. The acceptance test verified staging, and the same image is running on production."

---

## Slide 19 — Key Takeaways

**Show:** Bullet list

**Say:**
1. **CD automates everything** — from `git push` to production deployment
2. **Quality gates catch bugs early** — compile, test, coverage, linting all run before anything ships
3. **Containers ensure consistency** — the same JAR runs on your laptop, staging, and production
4. **Staging → Production flow** — validate before release, never rebuild for production
5. **Versioned images** — timestamp tags mean every deploy is traceable and rollback-able
6. **Distributed caching** — Hazelcast makes your app faster and handles pod failures
7. **Same image, every environment** — what passes staging is what runs in production

---

## Slide 20 — Common Gotchas & Troubleshooting

**Show:** A troubleshooting slide

| Problem | Solution |
|---------|----------|
| Gradle can't run | `chmod +x gradlew` |
| Docker permission denied | Add user to `docker` group |
| kubectl can't reach cluster | Mount `~/.kube` into Jenkins container |
| Acceptance test timeout | Increase `sleep 60` to `sleep 90` |
| No ExternalIP on Minikube | Use `minikube -p staging ip` instead |
| Memory pressure | Lower Minikube memory or increase WSL2 limit |

**Say:** "These are the real issues you'll hit. The most common is that `acceptance-test.sh` uses `kubectl get nodes` to find the ExternalIP — but Minikube nodes are local Docker containers, they don't have ExternalIPs. You need to use `minikube ip` instead."

---

## Slide 21 — Discussion Questions

**Show:** Questions for the audience

**Say/ask:**
1. "What happens if the acceptance test fails?" — *The pipeline stops. The developer fixes the code and pushes again.*
2. "How would you add rollback?" — *Re-deploy the previous timestamp-tagged image. As long as it's in Docker Hub, you can rollback.*
3. "What other quality gates would you add?" — *Security scan (Trivy/Snyk), performance benchmark, integration tests with database.*
4. "Is Hazelcast worth the complexity?" — *Depends. For the Calculator? Overkill. For a real app with expensive computations? Absolutely.*
5. "When would you use 1 cluster with namespaces vs 2 clusters?" — *Namespaces for cost savings, separate clusters for full isolation.*

---

## Slide 22 — Cleanup / End

**Show:** Cleanup commands:
```bash
minikube delete -p staging
minikube delete -p production
docker stop jenkins && docker rm jenkins
```

**Say (if time):** "If you want to try this yourself, the setup instructions are in the README. The key requirements are Docker, Minikube, and Jenkins — all free and open source."

**Closing:** "Continuous Delivery transforms how teams ship software. The 11-stage pipeline we saw today is the foundation — you can extend it with security scans, performance tests, canary deployments, and more. But the core idea is the same: automate everything, catch issues early, and ship with confidence."

---

## Timing Guide

| Slide | Topic | Duration |
|-------|-------|----------|
| 1 | Title | 1 min |
| 2-3 | What is CD / The Problem | 3 min |
| 4 | Architecture Overview | 2 min |
| 5 | Calculator App (live code) | 5 min |
| 6 | Pipeline Overview | 2 min |
| 7 | Jenkinsfile (live code) | 3 min |
| 8 | Quality Gates (live) | 4 min |
| 9 | Docker Build | 3 min |
| 10 | Version Update | 2 min |
| 11 | Deploy to Staging (live) | 5 min |
| 12 | Release to Production | 3 min |
| 13 | Two-Cluster Strategy | 3 min |
| 14 | Hazelcast Demo (live) | 4 min |
| 15 | Exercise 1 (live) | 3 min |
| 16 | Exercise 2 | 3 min |
| 17 | Full Pipeline Demo | 5 min |
| 18 | Verification (live) | 2 min |
| 19-22 | Takeaways / Cleanup | 5 min |
| **Total** | | **~58 min** |
