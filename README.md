# End-to-End DevOps Automation Platform (Labs 1–4 & Capstone Project)

A production-grade, reproducible DevOps automation platform serving both the **DevOps & Automation Lab curriculum (Labs 1–4)** and the **Capstone Project**, featuring an **AI-powered FastAPI Chatbot** integrated with the **Google Gemini REST API** (via pure HTTP requests), orchestrated across version control, Jenkins CI/CD gates, containerization, Kubernetes, GitOps (Argo CD & Argo Rollouts), observability, DevSecOps, and disaster recovery.

## Author & Academic Information

- **Student Name:** Gopesh Aggarwal
- **Roll No.:** 2301730158
- **Email:** [gopeshaggarwal18@gmail.com](mailto:gopeshaggarwal18@gmail.com)
- **Curriculum:** DevOps and Automation Lab (Labs 1–4) & Capstone Project
- **Repository:** [https://github.com/gopesh353/devops-lab](https://github.com/gopesh353/devops-lab)
- **License:** Open Source ([MIT](LICENSE))

---

## Reports, Screenshots & Sample Evidence

> [!IMPORTANT]
> Complete execution evidence, terminal command outputs, configuration files, and visual screenshots for Labs 1–4 and Capstone Project are included in [Lab-1.pdf](Lab-1.pdf), [Lab-2.pdf](Lab-2.pdf), [Lab-3.pdf](Lab-3.pdf), [Lab-4.pdf](Lab-4.pdf) and [Capstone-Report](Capstone-Report.pdf) and Tracked sample logs, JUnit test results, Bandit SAST output, and Disaster Recovery RTO/RPO reports are also available in [`samples/`](samples/).

---

## Prerequisites & System Requirements

### Recommended Operating Systems

- **Fedora Linux** (tested on Fedora 44)
- **Ubuntu Linux** (22.04 LTS / 24.04 LTS)

### Required Software Packages


| Tool              | Purpose                                 | Verification Command       |
| ----------------- | --------------------------------------- | -------------------------- |
| **Git**           | Source Code Management                  | `git --version`            |
| **Python 3.11+**  | Application Runtime & Testing           | `python3 --version`        |
| **Docker Engine** | Containerization & Compose              | `docker --version`         |
| **Jenkins**       | Continuous Integration & Deployment     | `systemctl status jenkins` |
| **kubectl**       | Kubernetes CLI Client                   | `kubectl version --client` |
| **Minikube**      | Local Kubernetes Cluster                | `minikube version`         |
| **Ansible**       | Infrastructure Configuration Management | `ansible --version`              |
| **Terraform**     | Infrastructure as Code (IaC)            | `terraform version`              |
| **Argo Rollouts** | Blue-Green & Canary CLI Plugin          | `kubectl argo rollouts version`  |

## Quickstart Guide

### 1. Clone the Repository

```bash
git clone https://github.com/gopesh353/devops-lab.git
cd devops-lab
```

### 2. Setup Application Environment & Secrets

Create your local environment file from the provided template:

```bash
cp .env.example .env
```

Edit `.env` and set your Google Gemini API Key:

```ini
GEMINI_API_KEY="your_actual_gemini_api_key_here"
GEMINI_MODEL="gemini-3.5-flash-lite"
APP_PORT=8000
```

*(Note: `.env` is strictly ignored by `.gitignore` to prevent credential leaks).*

### 3. Setup Python Virtual Environment & Dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 4. Run & Test the Application Locally

```bash
# Start the application using automated deployment script
bash deploy.sh

# Access the chatbot in your browser at http://localhost:8000

# Run CI unit tests (mocked, no API key required)
pytest tests/test_unit.py -v

# Run live integration & Gemini API test suites (with server running)
pytest tests/test_integration.py -v
python test_app.py
```

## Architecture Overview

```
+---------------------------------------------------------------------------------------------------+
|                                      DEVELOPER WORKSTATION                                        |
|  - Git Version Control (Branching, Merging, Tagging)                                              |
|  - FastAPI AI Chatbot (Google Gemini REST API, Multi-Turn Session Memory)                         |
|  - Automated PyTest Suite & Local Zero-Downtime Deployment (deploy.sh)                            |
+--------------------------------------------------|------------------------------------------------+
                                                   | git push
                                                   v
+---------------------------------------------------------------------------------------------------+
|                                        GITHUB REPOSITORY                                          |
|                         Source Code, Dockerfile, K8s Manifests, IaC                               |
+--------------------------------------------------|------------------------------------------------+
                                                   | SCM Polling / Webhook Trigger
                                                   v
+---------------------------------------------------------------------------------------------------+
|                                       JENKINS CI/CD SERVER                                        |
|  [Install] ──> [Unit Tests] ──> [Integration Tests] ──> [Bandit SAST] ──> [Vault Secret Check]    |
+--------------------------------------------------|------------------------------------------------+
                                                   | Container Build & GitOps Sync
                                                   v
+---------------------------------------------------------------------------------------------------+
|                             CONTAINERIZATION, KUBERNETES & GITOPS                                 |
|  - Docker: Multi-stage slim images (`v1`, `v2`), Named Volumes, Bind Mounts, Bridge Networks      |
|  - Kubernetes & Argo CD: RollingUpdate, Blue-Green (Preview/Promote), Canary (10/25/50/100%)      |
+--------------------------------------------------|------------------------------------------------+
                                                   | Telemetry, Security & Recovery
                                                   v
+---------------------------------------------------------------------------------------------------+
|                          OBSERVABILITY, IAC, SECURITY & DISASTER RECOVERY                         |
|  - Ansible & Terraform: Automated Node Configuration & Declarative Worker Provisioning            |
|  - Prometheus, Grafana & Logging: `/metrics` Scraping, Structured JSON Logs, Metric Analysis      |
|  - DevSecOps: Bandit SAST, Trivy Container CVE Scanning & HashiCorp Vault KV v2 Secrets           |
|  - Recoverability: Backup, Namespace Loss DR Drill & Failback with Measured RTO/RPO               |
+---------------------------------------------------------------------------------------------------+
```

---

## Detailed Lab Breakdown

---

### Lab 1: DevOps Foundations & Continuous Integration

**Objective:** Build a foundational Git-based CI/CD pipeline automating application builds, zero-downtime deployment, and test reporting.

#### Key Highlights & Implemented Features:

1. **Application Architecture (`app.py`):**
   - High-performance FastAPI application serving an interactive glassmorphic chat interface.
   - Direct HTTP communication with Google Gemini REST API (`generateContent`) without heavyweight external SDKs.
   - Stateful multi-turn conversation session memory (`history` array conforming to Gemini API role requirements).
   - Dynamic runtime `/health`, `/metrics`, and `/api/features` endpoints.
2. **Git Version Control & Branching Strategy:**
   - Isolated feature branching (`chatbot-memory-fix`).
   - Atomic conventional commit structure.
   - Non-fast-forward merge (`git merge --no-ff`) preserving topological history evidence for evaluation.
3. **Automated Deployment Script (`deploy.sh`):**
   - Discovers and gracefully terminates stale processes on port 8000 (`SIGTERM` fallback).
   - Starts Uvicorn in the background with `nohup` and PID tracking in `.server.pid`.
   - Automated polling loop against `/health` with retry backoff to verify deployment before succeeding.
4. **Declarative Jenkins Pipeline (`Jenkinsfile`):**
   - Integrates with Git SCM to automate setup, deployment, and testing.
   - Initially implemented as **Build (`deploy.sh`) → Deploy → Test (`pytest test_app.py`, `test-results.xml`)**, and later expanded into the full multi-stage CI test & SAST gate (`tests/test_unit.py`, `tests/test_integration.py`, `bandit -r app.py -ll`, and masked Vault check).
   - **Post Actions:** Archives JUnit XML test reports and logs pipeline status banners.

---

### Lab 2: Containerization & Kubernetes Orchestration

**Objective:** Containerize the application using Docker, manage multi-container networks and persistent storage, and orchestrate deployment on a Kubernetes (Minikube) cluster with zero-downtime rolling updates.

#### Key Highlights & Implemented Features:

1. **Containerization (`Dockerfile` & `.dockerignore`):**
   - Built on `python:3.11-slim` with layer caching (installing `requirements.txt` before copying code).
   - Built-in container healthcheck via Python urllib.
2. **Docker Storage Experiments:**
   - **Ephemeral Layer:** Demonstrated data loss when writing to a container layer and deleting the container.
   - **Named Volume (`chatbot-vol`):** Proved persistent data survival across container recreations.
   - **Host Bind Mount (`./logs`):** Demonstrated bidirectional real-time file synchronization between container and host.
3. **Docker Networking Experiments:**
   - Custom bridge network (`chatbot-net`).
   - Proved inter-container communication using **Container Names** (Docker internal DNS) and **Container IP Addresses**.
4. **Kubernetes Orchestration on Minikube (`k8s/`):**
   - **Deployment (`k8s/deployment.yaml`):** 2 replicas, resource requests/limits, HTTP liveness and readiness probes.
   - **Service (`k8s/service.yaml`):** NodePort service exposing port 8000 via node port 30080.
   - **ConfigMap & Secret (`k8s/configmap.yaml`, `k8s/secret.yaml.example`):** Externalized application configurations and encrypted credentials.
5. **Deployment Strategies:**
   - **Dynamic Replica Scaling:** Scaled pods dynamically from 2 to 4 replicas (`kubectl scale`).
   - **Zero-Downtime Rolling Update:** Deployed image updates (`v1` to `v2`) with `maxSurge=1` and `maxUnavailable=0` (`kubectl rollout status`).
   - **Instant Rollback:** Reverted failed deployments with `kubectl rollout undo`.
6. **Continuous Deployment (`deploy_k8s.sh`):**
   - Single-command automated script that validates cluster health, injects secrets from `.env`, applies manifests, and blocks until rollout completion.

---

### Lab 3: Monitoring, Logging & DevSecOps

**Objective:** Implement full-stack observability, centralized logging, automated infrastructure provisioning, security scanning, and release quality engineering.

#### Key Highlights & Implemented Features:

1. **Infrastructure Automation (Ansible):**
   - `ansible/playbook.yml` automated directory provisioning, configuration checks, and runtime environment verification across target nodes with zero failed tasks.
2. **Infrastructure as Code (Terraform):**
   - `terraform/main.tf` defined declarative, parameterized compute instances with local state tracking (`terraform init`, `plan`, `apply`).
3. **Observability & Metrics Monitoring (Prometheus & Grafana):**
   - FastAPI exposed real-time telemetry on `/metrics` using `prometheus_client`.
   - Prometheus container scraped application metrics over Docker gateway (`172.17.0.1:8000`) on port 9090.
   - Grafana connected on port 3000 to visualize request counts (`http_requests_total`) and latency trends.
4. **Centralized Logging (Elasticsearch):**
   - Elasticsearch search cluster deployed on port 9200.
   - Ingested structured JSON application access logs into the `chatbot-logs` index with full-text search capability.
5. **DevSecOps (Shift-Left Security):**
   - **SAST (Static Application Security Testing):** Executed `bandit -r app.py` confirming 0 security findings across the application source.
   - **Container Vulnerability Scanning:** Executed `trivy image devops-chatbot:v1`, generating full CVE vulnerability audit reports across OS layers and dependencies.
6. **Release Engineering & Testing:**
   - **Feature Flags:** In-memory runtime flags (`/api/features`) allowing dynamic toggle of features (e.g., `beta_summarizer`) without server restart.
   - **Concurrency Load Testing (`scripts/load_test.py`):** Multi-threaded benchmark testing `/health` with 100 requests across 10 workers to measure req/s throughput.
   - **Automated UI Verification (`scripts/test_selenium.py`):** Verified essential frontend DOM elements (input, chat box, action handlers).

---

### Lab 4: Advanced Deployment Strategies & Enterprise DevOps

**Objective:** Replace manual releases with controlled, observable deployment strategies: automated test gates, blue-green and canary releases, GitOps reconciliation, centralized secrets, and a measured disaster-recovery drill.

#### Key Highlights & Implemented Features:

1. **Versioned Release Artifact:**
   - `APP_VERSION` build argument produces `devops-chatbot:v1` and `:v2` from one codebase.
   - Every response carries `X-App-Version`; `/health` returns version and pod hostname for traffic proof.
2. **Automated Test & Security Gate (`Jenkinsfile`):**
   - Install → Unit Tests (`tests/test_unit.py`, 8 tests) → Integration Tests (`tests/test_integration.py`, 5 tests) → Bandit SAST (`bandit -r app.py -ll`) → optional Vault check.
   - A deployable artifact is only produced after the tests and security gate pass; `FAIL_DEMO=1` demonstrates a blocked release.
3. **Blue-Green Deployment (Argo Rollouts):**
   - `chatbot-active` (NodePort 30090) and `chatbot-preview` Services; manual promotion (`autoPromotionEnabled: false`).
   - Promotion probe: 148 requests, 0 failures, both v1 and v2 observed during the switch.
4. **Canary with Metric Analysis:**
   - Steps 10% → 25% → 50% → 100% with a Prometheus `AnalysisTemplate` (success rate ≥ 95%).
   - Measured splits matched the configured weights (11.5% and 52.5% in 200-request samples); `kubectl argo rollouts abort` returns traffic to stable immediately.
5. **GitOps with Argo CD:**
   - Two Applications (`chatbot-bluegreen`, `chatbot-canary`) sync from Git; no manual `kubectl apply` for releases.
   - Automated sync/prune/self-heal; a local Git smart-HTTP mirror stands in for GitHub because pushes were prohibited.
6. **Secret Management with Vault:**
   - API key stored in Vault KV v2 (`secret/chatbot`), synced to the `chatbot-secret` Kubernetes Secret; value is never printed or committed.
   - Jenkins uses a masked `vault-token` credential and has no Docker or Kubernetes permissions.
7. **Disaster Recovery with Measured RTO/RPO:**
   - `scripts/lab4_dr.sh` backs up the release manifest, deletes the namespace, restores into `chatbot-dr`, resyncs the secret from Vault, and fails back.
   - Drill result: **RTO 19 s**, **RPO 60 s**, service healthy on the same NodePort after restore.

---

## Directory Structure

```text
devops-lab/
├── app.py                      # FastAPI Chatbot backend, UI template, metrics, and feature flags
├── test_app.py                 # Live socket test suite (Health, UI, Validation, Memory)
├── deploy.sh                   # Local zero-downtime automated deployment script
├── requirements.txt            # Minimal Python dependencies
├── Dockerfile                  # Container build specification (python:3.11-slim)
├── .dockerignore               # Container build exclusions
├── docker-compose.yml          # Multi-container orchestration (Chatbot + Client)
├── Jenkinsfile                 # Declarative CI/CD pipeline specification
├── deploy_k8s.sh               # Automated Kubernetes Continuous Deployment script
├── .env.example                # Sample environment template
├── .gitignore                  # Production gitignore (ignores venvs, secrets, logs, tfstate)
├── LICENSE                     # MIT License
├── README.md                   # Master repository documentation
├── Lab-1.pdf                   # Lab 1 report and screenshots
├── Lab-2.pdf                   # Lab 2 report and screenshots
├── Lab-3.pdf                   # Lab 3 report and screenshots
├── Lab-4.pdf                   # Lab 4 report and screenshots
│
├── k8s/                        # Kubernetes Manifests
│   ├── deployment.yaml         # K8s Deployment (Replicas, Probes, RollingUpdate)
│   ├── service.yaml            # K8s NodePort Service (Port 30080 -> 8000)
│   ├── configmap.yaml          # K8s ConfigMap (App configurations)
│   ├── secret.yaml.example     # Safe Secret template (live secret.yaml ignored by Git)
│   ├── gitops/
│   │   ├── bluegreen/all.yaml  # Blue-green Rollout, active/preview Services
│   │   └── canary/all.yaml     # Canary Rollout, Ingress, AnalysisTemplate
│   └── platform/
│       └── prometheus.yaml     # In-cluster Prometheus scrape config
│
├── gitops/
│   └── argocd-apps.yaml        # Argo CD Applications (GitOps source of truth)
│
├── tests/
│   ├── test_unit.py            # Mocked unit tests (CI gate)
│   └── test_integration.py     # Live-server integration tests (CI gate)
│
├── ansible/                    # Configuration Management
│   ├── inventory.ini           # Ansible target host inventory
│   └── playbook.yml            # Infrastructure automation playbook
│
├── terraform/                  # Infrastructure as Code (IaC)
│   └── main.tf                 # Declarative scalable compute resources
│
├── monitoring/                 # System Observability
│   └── prometheus.yml          # Prometheus scrape configurations
│
├── samples/                    # Sample Logs, Test Reports, Security & DR Evidence
│   ├── sample_app_logs.json    # Sample structured JSON application logs
│   ├── bandit_report.txt       # Bandit SAST scan output
│   ├── unit_test_results.xml   # JUnit XML unit test report
│   ├── dr_rto_report.txt       # Measured Disaster Recovery RTO/RPO output
│   └── dr_health.json          # Restored service health check output
│
└── scripts/                    # Testing & Automation Utilities
    ├── load_test.py            # Concurrent load testing benchmark suite
    ├── test_selenium.py        # Automated UI DOM validation script
    ├── lab4_platform.sh        # Minikube, Argo CD/Rollouts, Prometheus, Git mirror bootstrap
    ├── lab4_build.sh           # Build and load the v1/v2 images
    ├── lab4_bluegreen.sh       # Preview, promote, rollback, zero-downtime probe
    ├── lab4_canary.sh          # Canary load, traffic sampling, promote/abort
    ├── lab4_dr.sh              # Backup, disaster drill (RTO/RPO), failback
    ├── lab4_secrets.sh         # Vault write and Kubernetes secret sync
    └── lab4_traffic.py         # Version-aware traffic probe/sampler
```

---

## Command Quick Reference

### Run Application & Tests

```bash
bash deploy.sh                        # Start / restart application
pytest tests/test_unit.py -v          # Run unit tests (mocked)
pytest tests/test_integration.py -v   # Run integration tests (live server)
python test_app.py                    # Run live Gemini API & memory tests
```

### Docker

```bash
docker build -t devops-chatbot:v1 .                      # Build container
docker run -d -p 8000:8000 --env-file .env devops-chatbot:v1 # Run container
docker compose up -d                                      # Multi-container setup
```

### Kubernetes (Minikube)

```bash
minikube start --driver=docker                            # Start cluster
minikube image load devops-chatbot:v1                     # Load image
bash deploy_k8s.sh                                        # Automated deploy
kubectl get pods,svc -l app=gemini-chatbot               # Inspect resources
```

### Lab 4: Advanced Deployments & DR

```bash
bash scripts/lab4_platform.sh                 # Minikube + Argo CD/Rollouts + Prometheus + Git mirror
bash scripts/lab4_build.sh                    # Build/load devops-chatbot v1 and v2
kubectl apply -f gitops/argocd-apps.yaml      # Register GitOps Applications
bash scripts/lab4_secrets.sh start            # Vault -> Kubernetes secret
bash scripts/lab4_bluegreen.sh promote        # Blue-green promote with zero-downtime probe
bash scripts/lab4_canary.sh load-start 600    # Canary ingress traffic
bash scripts/lab4_canary.sh sample 200        # Verify the traffic split
bash scripts/lab4_dr.sh backup                # Backup manifest
bash scripts/lab4_dr.sh drill                 # Delete namespace, restore, report RTO/RPO
bash scripts/lab4_dr.sh failback              # Return to the primary namespace
```

### Monitoring & Security

```bash
# Prometheus & Grafana
docker run -d --name prometheus -p 9090:9090 -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
docker run -d --name grafana -p 3000:3000 grafana/grafana

# Security Scans
bandit -r app.py                                          # SAST code scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image devops-chatbot:v1 # CVE scan

# Quality Testing
python scripts/load_test.py                               # Load test
python scripts/test_selenium.py                           # Automated UI test
```

---
