# NovaPay Digital Bank: Zero-Downtime CI/CD Platform Architecture

## 1. Executive Summary & Problem Context

NovaPay Digital Bank is a scheduled commercial bank licensed by the Reserve Bank of India (RBI), serving over 12 million retail and MSME customers with high-throughput payment rails (UPI, IMPS, NEFT, RTGS) and core banking transaction processing. 

### 1.1 The Legacy Baseline (Current State)
Prior to this architectural transformation, NovaPay operated under severe operational, resilience, and regulatory liabilities:
- **Deployment Mechanism**: Manual SSH scripts executed by developers connecting directly to production EC2 instances (`ssh deployer@prod-core-01 'git pull && systemctl restart novapay-core'`).
- **Mean Time to Recovery (MTTR)**: **4.5 hours** during production incidents due to lack of automated rollbacks, unversioned configuration drift, and manual database rollbacks.
- **Deployment Frequency**: Fortnightly (every 14 days) batch releases deployed in high-risk maintenance windows (typically Saturdays 01:00 - 05:00 IST), causing frequent transaction disruptions and service degradation.
- **Compliance & Security**: Zero automated static or dynamic security scanning in the deployment path.
- **Audit Deficiencies**: **17 outstanding RBI audit non-conformances** spanning IT Governance, Cyber Security Framework, and PCI-DSS v4.0 violations—most critically relating to Segregation of Duties (SoD), developer access to production, missing audit trails, and unverified change controls.

### 1.2 Target Architectural Metrics & SLOs
| Metric | Legacy Baseline | Target Architecture | Implementation Mechanism |
| :--- | :--- | :--- | :--- |
| **System Availability** | 99.4% (~52.5h downtime/yr) | **99.999% (Five-Nines)** | Multi-AZ active-active, Istio mesh, zero-downtime rollouts |
| **Commit-to-Production Lead Time** | 14 days (336 hours) | **< 2 hours (120 mins)** | Hermetic parallel CI stages, GitOps automated synchronization |
| **Mean Time to Recovery (MTTR)** | 4.5 hours (270 mins) | **< 15 minutes** | Automated SLI-driven canary rollback, instant Blue-Green traffic flip |
| **Deployment Frequency** | Bi-weekly batch | **Multiple per day on-demand** | Decoupled microservices, automated compliance gates |
| **Automated Security Gates** | 0% (Manual sign-offs) | **100% Shift-Left Coverage** | SAST, SCA, SBOM, DAST, OPA compliance policies |
| **RBI Audit Non-Conformances** | 17 Open Violations | **0 Open Violations (100% Remediated)** | GitOps audit trails, immutable container signing, SoD enforcement |

---

## 2. High-Availability Engineering: Achieving Five-Nines (99.999%)

### 2.1 The Five-Nines Error Budget Breakdown
In an RBI-regulated banking environment, achieving 99.999% availability means total unplanned downtime must not exceed:
- **Per Year**: 5 minutes, 15.6 seconds (315.6 seconds)
- **Per Quarter**: 1 minute, 18.9 seconds (78.9 seconds)
- **Per Month (30 days)**: 25.9 seconds
- **Per Day**: 0.86 seconds

```
Availability (%) = (Total Time - Downtime) / Total Time * 100
99.999% = (525,600 mins - 5.256 mins) / 525,600 mins * 100
```

To operate within this budget, **routine software deployments must introduce exactly 0.00 seconds of user-perceived downtime**. Any packet drop, dropped TCP connection, or 5xx burst immediately consumes the annual error budget.

### 2.2 Mathematical Resilience Architecture
To eliminate single points of failure (SPOF) and guarantee five-nines across both compute and network layers:

1. **Multi-AZ Active-Active Topology**:
   - Compute runs on AWS EKS across 3 Availability Zones (`ap-south-1a`, `ap-south-1b`, `ap-south-1c`) within the Mumbai region, with warm disaster recovery standby in Hyderabad (`ap-south-2`).
   - Cluster nodes are balanced using Topology Spread Constraints:
     ```yaml
     topologySpreadConstraints:
       - maxSkew: 1
         topologyKey: topology.kubernetes.io/zone
         whenUnsatisfiable: DoNotSchedule
         labelSelector:
           matchLabels:
             app.kubernetes.io/name: novapay-payment-service
     ```
2. **Pod Disruption Budgets (PDB)**:
   - Every banking workload enforces a strict PDB guaranteeing minimum available instances during rolling upgrades or node drains:
     ```yaml
     apiVersion: policy/v1
     kind: PodDisruptionBudget
     metadata:
       name: novapay-payment-service-pdb
     spec:
       minAvailable: "80%"
       selector:
         matchLabels:
           app: novapay-payment-service
     ```
3. **Graceful Connection Draining & Zero-Packet-Loss Pod Lifecycle**:
   - Kubernetes pod termination sequence is decoupled from service endpoint removal:
     - `preStop` hook executes `sleep 15` to ensure iptables/IPVS and Envoy endpoint sync completes across all nodes before SIGTERM is sent.
     - Application listens for SIGTERM, ceases accepting new connections, and allows in-flight financial transactions up to 45 seconds to finalize before exiting (`terminationGracePeriodSeconds: 60`).
4. **Resilient Service Mesh (Istio)**:
   - Outlier detection (circuit breaking) ejects misbehaving pods after 3 consecutive 5xx errors for a 30-second isolation window.
   - Retries with exponential backoff and jitter on idempotent read-only requests.

---

## 3. The 8 Canonical CI/CD Pipeline Stages

The automated delivery pipeline is structured into 8 deterministic, policy-enforced stages:

```
[ Stage 1: SCM & Branching ] 
       │
[ Stage 2: Hermetic Build & Unit Testing ]
       │
[ Stage 3: SAST (Static Application Security Testing) ]
       │
[ Stage 4: Dependency & Container Security (SCA, SBOM, Signing) ]
       │
[ Stage 5: Integration & Contract Testing ]
       │
[ Stage 6: DAST (Dynamic Application Security Testing) ]
       │
[ Stage 7: Policy & Compliance Gates (RBI, PCI-DSS, SoD) ]
       │
[ Stage 8: Deployment & Automated Verification (Canary / Blue-Green) ]
```

### Detailed Stage Specifications

#### Stage 1: Source Control & GitOps Governance
- **Repository Strategy**: Trunk-based development (`main` branch) with short-lived feature branches (`feat/*`, `fix/*`).
- **Commit Integrity**: Mandatory GPG/SSH cryptographic signing for all commits (`git commit -S`). Unsigned commits are rejected by branch protection rules.
- **Pull Request Controls**:
  - Minimum 2 approvals required (one Tech Lead, one Security Champion).
  - Mandatory link to an approved JIRA Change Advisory Board (CAB) ticket.
  - Linear git history enforced (squash or rebase only).

#### Stage 2: Hermetic Build & Unit Testing
- **Reproducible Builds**: Multi-stage Docker builds using minimal rootless distroless base images (`gcr.io/distroless/java17-debian12:nonroot`).
- **Caching**: Remote build cache leveraging GitHub Actions cache / Harbor cache to reduce compilation time.
- **Unit Testing**: Strict coverage enforcement requiring >= 85% line coverage and >= 80% branch coverage via JaCoCo. Failure to meet thresholds aborts the pipeline.
- **SBOM Generation**: Automatic generation of CycloneDX and SPDX Software Bill of Materials (SBOM) tracking every binary dependency and sha256 hash.

#### Stage 3: SAST (Static Application Security Testing)
- **Engine**: SonarQube Enterprise and Semgrep with custom banking rulesets.
- **Coverage**:
  - OWASP Top 10 2021 & CWE Top 25.
  - Financial data handling checks (detecting unmasked Account Numbers, UPI IDs, PAN, Aadhaar numbers).
  - Insecure cryptographic algorithms (banning MD5, SHA-1, DES, 3DES; enforcing AES-GCM-256 and SHA-256/384).
- **Quality Gate**: Zero Blocker, zero Critical, zero High severity issues allowed.

#### Stage 4: Dependency, Secret & Container Scanning
- **Secret Scanning**: Gitleaks and Trufflehog scanning the full commit tree for API keys, AWS credentials, certificates, and private keys.
- **SCA (Software Composition Analysis)**: Trivy and Snyk inspecting all transitive third-party dependencies against the National Vulnerability Database (NVD).
  - Remediation SLA: Zero unresolved Critical or High CVEs with known exploits allowed to pass.
- **Container Vulnerability Scan**: Trivy image scanner checking operating system packages and libraries.
- **Cryptographic Provenance**: Cosign signs the verified image using AWS KMS-backed keys and attaches the SLSA Level 3 provenance attestation to the private registry (AWS ECR / Harbor).

#### Stage 5: Integration & Contract Testing
- **Consumer-Driven Contract Testing**: Pact framework verifying API schema compatibility between NovaPay mobile banking microservices, payment gateways, and core ledger services.
- **Ephemeral Integration Harness**: Testcontainers spins up isolated PostgreSQL, Redis, and simulated NPCI/UPI switch mock servers in memory.
- **Backward Compatibility Gate**: New API schemas are verified against the active production API schema to prevent breaking payload changes.

#### Stage 6: DAST (Dynamic Application Security Testing)
- **Deployment**: Pipeline triggers an ephemeral review environment in the staging Kubernetes cluster.
- **Scanning Engine**: OWASP ZAP and StackHawk run automated authenticated dynamic scans against REST and gRPC endpoints.
- **Verification**:
  - Injection attacks (SQLi, NoSQLi, Command Injection).
  - Broken Object Level Authorization (BOLA / IDOR).
  - Security header validation (HSTS, Content-Security-Policy, X-Frame-Options).
  - TLS 1.3 cipher suite enforcement.

#### Stage 7: Policy & Compliance Gates
- **Engine**: Open Policy Agent (OPA) / Conftest.
- **Regulatory Rule Sets**:
  - **RBI Master Direction (2023)**: Validates approved CAB ticket, verification of testing sign-offs, and automated audit logging.
  - **PCI-DSS v4.0**: Validates encryption-in-transit, non-root container user execution, read-only root filesystems, and vulnerability scans.
  - **Segregation of Duties (SoD)**: Verifies that the committer is not the approver (4-eyes principle), that no developer possesses direct production deployment privileges, and that deployment tokens are strictly service-bound and short-lived.

#### Stage 8: Deployment & Automated Verification
- **Execution Engine**: ArgoCD GitOps operator listening to signed git tags.
- **Topology Dispatch**:
  - **Payment Gateway / Edge APIs**: Canary Deployment via Argo Rollouts with progressive traffic splitting (5% -> 20% -> 50% -> 100%) and continuous metric evaluation.
  - **Core Banking Settlement Engine**: Blue-Green Deployment via Argo Rollouts with preview validation and zero-loss cutover.
- **Verification & Rollback**: Real-time Prometheus SLI analysis templates monitor error rates and latency. If thresholds are breached, traffic is rolled back in < 15 seconds automatically.

---

## 4. Dual Deployment Topologies

```
                             [ INGRESS TRAFFIC ]
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
         [ Payment Services ]              [ Settlement Services ]
           Canary Strategy                   Blue-Green Strategy
      (Argo Rollouts + Istio)              (Argo Rollouts + Switch)
                     │                                 │
     5% -> 20% -> 50% -> 100%                 Active (Blue) -> Standby (Green)
  Prometheus SLI Gate at each step         Automated Smoke Test on Preview Service
  Instant rollback if 5xx > 0.05%          Atomic router cutover with 0s downtime
```

### 4.1 Canary Strategy (User-Facing Payment Services)
- Applied to latency-sensitive, high-volume HTTP/gRPC services (e.g. `payment-service`, `upi-switch-adapter`).
- Istio VirtualService dynamically manipulates weight-based routing based on Argo Rollout step definitions:
  - **Step 1**: Route 5% traffic to Canary. Pause 10 minutes. Evaluate Prometheus metrics.
  - **Step 2**: Route 20% traffic to Canary. Pause 15 minutes. Evaluate Prometheus metrics.
  - **Step 3**: Route 50% traffic to Canary. Pause 15 minutes. Evaluate Prometheus metrics.
  - **Step 4**: Route 100% traffic to Canary. Promote Canary to Stable.
- Rollback condition: If HTTP 5xx error rate exceeds 0.05% or P99 latency exceeds 150ms over a 2-minute rolling window, Argo Rollouts immediately resets traffic weight to 0% on Canary and restores 100% to Stable.

### 4.2 Blue-Green Strategy (Core Settlement & Ledger Services)
- Applied to stateful, mission-critical ledger and batch settlement processors where split-brain or multi-version concurrent processing is impermissible.
- Two identical environments: **Active (Blue)** and **Preview (Green)**.
- New release is deployed to Green while Blue serves 100% of live traffic.
- Synthetic transaction test suite runs against the internal Preview Service to validate database connections, ledger reconciliation, and payment rails.
- Upon successful verification, the production Service selector flips atomically to Green.
- Blue pods are kept alive in standby for 30 minutes (`scaleDownDelaySeconds: 1800`) to enable instant fallback before decommissioning.

---

## 5. End-to-End Latency & Commit-to-Production SLA (< 2 Hours)

| Stage | Operations | Allocated Time | Optimization Strategy |
| :--- | :--- | :--- | :--- |
| **Stage 1: SCM** | Commit signing check, commitlint, PR review verification | 2 min | Automated GitHub checks |
| **Stage 2: Build & Unit Test** | Hermetic multi-stage build, unit tests, JaCoCo, CycloneDX SBOM | 8 min | Layer caching, parallel test runners |
| **Stage 3: SAST** | Semgrep, SonarQube rule engine | 6 min | Differential scanning on PR diff |
| **Stage 4: SCA & Signing** | Trivy, Snyk, Gitleaks, Cosign keyless signing | 7 min | Vulnerability DB pre-caching |
| **Stage 5: Integration** | Pact contract tests, Testcontainers ephemeral DB | 12 min | Concurrent integration suites |
| **Stage 6: DAST** | OWASP ZAP targeted API dynamic scan | 15 min | Focused OpenAPI endpoint attack plan |
| **Stage 7: Compliance** | OPA Conftest policies (RBI, PCI-DSS, SoD) | 2 min | In-memory Rego evaluation |
| **Stage 8: Deployment** | GitOps sync, Canary progression (5%->20%->50%->100%), SLI verification | 45 min | Automated step progression with Prometheus |
| **Post-Deploy Smoke** | Synthetic transaction verification | 3 min | Automated Python verification suite |
| **Total Lead Time** | **Complete Commit-to-Production** | **1 hour 40 min** | **Well within the 2-hour target** |

---

## 6. Audit Remediation & Segregation of Duties (SoD) Framework

### 6.1 Elimination of Production SSH Access
- Direct developer SSH/bastion access to production instances is completely abolished.
- Production Kubernetes clusters operate in private VPC subnets with no public ingress for administrative ports (`22`, `6443`).
- All changes are delivered via GitOps pull-based synchronization through ArgoCD running within the cluster.
- In emergency operational scenarios, access is mediated exclusively via AWS Systems Manager (SSM) Session Manager with time-delimited IAM role elevation, multi-party authorization, full keystroke recording to an immutable S3 bucket with Object Lock (WORM), and automatic notification to the Chief Information Security Officer (CISO).

### 6.2 Cryptographic Chain of Custody
Every artifact deployed to production possesses an unalterable cryptographic trail:
1. **Developer**: GPG-signed commit.
2. **Reviewers**: Cryptographically signed GitHub PR approval via WebAuthn/FIDO2.
3. **CI Pipeline**: Container image signed with Cosign using ephemeral OIDC tokens tied to the GitHub repository identity.
4. **SLSA Level 3 Provenance**: In-toto attestation capturing git commit SHA, build environment, builder identity, and input dependencies.
5. **Admission Controller (Kyverno/OPA Gatekeeper)**: Rejects any pod admission in production if the container image lacks a valid signature from the NovaPay CI KMS key or fails SLSA provenance verification.
