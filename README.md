# NovaPay Digital Bank: Zero-Downtime CI/CD Platform & Regulatory Fortress

## Executive Summary (250 Words Max)
NovaPay Digital Bank, an RBI-licensed scheduled commercial bank serving 12 million customers, has completed the architectural transformation of its software delivery ecosystem. Prior to this initiative, NovaPay operated under severe operational, resilience, and regulatory liabilities: manual SSH deployments directly to production servers, a 4.5-hour Mean Time to Recovery (MTTR), high-risk fortnightly deployment freezes, zero automated static or dynamic security scanning, and 17 outstanding Reserve Bank of India (RBI) audit non-conformances.

This repository delivers a production-grade, zero-downtime CI/CD delivery platform engineered to achieve five-nines (99.999%) availability—guaranteeing $\le$ 5.26 minutes of unplanned downtime per year. The architecture implements an eight-stage canonical pipeline where SAST, DAST, SCA, CycloneDX SBOM generation, Cosign KMS cryptographic signing, and Open Policy Agent (OPA) compliance gates are hard blocking prerequisites. Progressive delivery is decoupled across two dedicated topologies: a 4-phase Canary strategy with Istio traffic shifting for edge payment APIs, and an atomic Blue-Green strategy with 30-minute warm standby for core settlement engines. 

Database evolution is mediated via the 3-phase Expand-Contract pattern handling 100M+ financial records with non-blocking DDL (`lock_timeout = '2s'`, `CREATE INDEX CONCURRENTLY`). The platform reduces commit-to-production lead time to 1 hour 40 minutes while achieving 100% automated remediation of all 17 RBI audit findings and full compliance with the RBI Master Direction on IT Governance (2023) and PCI-DSS v4.0.

---

## Architecture Overview & End-to-End Pipeline

```
[ Stage 1: SCM Governance & Commit Signing ]
       │
[ Stage 2: Hermetic Build & Unit Tests (JaCoCo >= 85%) + SBOM ]
       │
       ├─────────────────────────────────┬─────────────────────────────────┐
       ▼ (Parallel Track A)              ▼ (Parallel Track B)              ▼ (Parallel Track C)
[ Stage 3: SAST Analysis ]        [ Stage 4: SCA & Signing ]        [ License Scan ]
SonarQube & Semgrep Banking Rules Trivy CVEs + Cosign KMS Hardware   ScanCode GPL Blacklist
       └─────────────────────────────────┴─────────────────────────────────┘
       │
[ Stage 5: Consumer-Driven Contract (Pact) & Ephemeral Integration Tests ]
       │
[ Stage 6: Authenticated Dynamic Security Testing (OWASP ZAP on Preview) ]
       │
[ Stage 7: OPA Compliance-as-Code Gates (RBI 2023 / PCI-DSS v4.0 / SoD) ]
       │
[ Stage 8: Progressive Zero-Downtime Deployment & Automated Verification ]
       ├── Payment Services: Argo Rollouts Canary (1% -> 5% -> 25% -> 100%)
       └── Settlement Engine: Blue-Green Atomic Cutover (30m Warm Standby)
       │
[ Post-Deploy: Automated Synthetic Transaction Smoke & Rollback Tripwires ]
```

---

## Repository Table of Contents & Navigation Guide

```
├── README.md                                          # Project overview + navigation guide (Executive Summary)
├── ERRATA.md                                          # Deliberate error findings (3 errors in Part A, C, D)
├── docs/
│   ├── 01-pipeline-architecture/                      # Deliverable 1: 8+ stage pipeline architecture
│   │   ├── architecture.md                            # Main architecture, velocity scoring & 5-nines model
│   │   ├── diagrams/                                  # Draw.io XML source and Mermaid schematics
│   │   └── stage-details/                             # Detailed per-stage specifications (Stages 1 to 8)
│   ├── 02-deployment-strategies/                      # Deliverable 2: Blue-green & canary deployment specs
│   │   ├── blue-green-specification.md                # 5-step switching protocol, Redis session management
│   │   └── canary-specification.md                    # 4-phase canary, Welch's t-test, Chi-squared formulas
│   ├── 03-compliance-gates/                           # Deliverable 3: 6+ compliance gates & regulatory maps
│   │   ├── compliance-gates-specification.md          # Numerical thresholds, exception workflows, JSON schema
│   │   ├── rbi-master-direction-mapping.md            # Mapping to RBI Master Direction (2023) Ch. III, IV, V
│   │   ├── pci-dss-v4-mapping.md                      # Mapping to PCI-DSS v4.0 Requirements
│   │   └── audit-remediation-17-nc.md                 # 100% resolution matrix for the 17 RBI audit non-conformances
│   ├── 04-database-migration/                         # Deliverable 4: Zero-downtime database migration strategy
│   │   ├── database-migration-strategy.md             # Expand-contract runbook, 100M+ rows backfill throttling
│   │   └── compatibility-matrix.md                    # Application V(N-1) vs V(N) compatibility matrix
│   ├── 05-environment-promotion/                      # Deliverable 5: 4-environment promotion workflow
│   │   ├── environment-promotion-workflow.md          # Dev -> Staging -> Pre-Prod -> Prod promotion criteria
│   │   └── configuration-management-strategy.md       # "Same artefact, different config", Vault rotation, drift
│   ├── 06-rollback-specification/                     # Deliverable 6: Automated rollback specification
│   │   ├── rollback-specification.md                  # Category A (<60s), Category B (<15m), Category C triggers
│   │   └── automated-triggers-taxonomy.md             # Prometheus alert rules for automated rollback
│   ├── 07-runbook-playbook/                           # Deliverable 7: Operations runbook & incident playbook
│   │   ├── deployment-runbook.md                      # "3 AM Standard" 8-item pre-deployment checklist
│   │   └── incident-playbook.md                       # SEV 1-4, Friday 5:07 PM simulation, 4 case studies
│   └── 08-observability/                              # Deliverable 8: Observability, DORA & dashboards
│       └── observability-strategy.md                  # 4 DORA metrics, 16 pipeline metrics, alerting matrix
├── pipeline/
│   ├── .github/workflows/                             # Executable GitHub Actions declarative workflows
│   │   ├── ci-cd-pipeline.yml                         # 8-stage canonical CI/CD production pipeline
│   │   ├── reusable-sast.yml                          # Reusable SonarQube & Semgrep SAST workflow
│   │   ├── reusable-dependency-scan.yml               # Reusable Trivy & Cosign SCA workflow
│   │   └── break-glass-hotfix.yml                     # Regulated emergency break-glass pipeline
│   ├── helm/novapay-microservice/                     # Helm chart templates with staging & production values
│   ├── terraform/                                     # Terraform IaC modules for multi-AZ EKS, RDS & Redis
│   ├── policies/                                      # OPA Rego & Kyverno YAML compliance-as-code policies
│   └── scripts/                                       # Automation scripts (coverage, lock check, fleet verify)
├── dashboards/
│   ├── grafana/                                       # Complete Grafana dashboard JSON exports
│   │   ├── engineering-ops-dashboard.json             # Real-time traffic split, error rates, DB pool
│   │   ├── management-dora-dashboard.json             # Executive DORA metrics & delivery velocity trends
│   │   └── regulatory-compliance-dashboard.json       # Audit-ready compliance gates & CVE tracking
│   └── mockups/                                       # Dashboard ASCII & visual layout wireframes
├── runbooks/                                          # Top-level operational runbooks (symlinked/mirrored)
│   ├── deployment-runbook.md                          # Production deployment runbook
│   └── incident-playbook.md                           # Incident response playbook & post-mortem
└── evidence/
    ├── self-assessment.md                             # 1,000-point rubric breakdown & justification
    ├── reflections.md                                 # 5 deep-dive reflection questions (250-400 words each)
    ├── trc-presentation.md                            # 20-slide executive TRC presentation deck
    └── test-results/                                  # Machine-readable verification test outputs
        ├── synthetic-transactions-report.json         # Synthetic banking test report (100% pass)
        ├── chaos-rollback-report.json                 # Chaos automated rollback verification (11.4s)
        └── pre-flight-check-report.json               # Database lock pre-flight check report
```

---

## Tools & Technology Ecosystem Used

| Category | Primary Tools Selected | Function in NovaPay Architecture |
| :--- | :--- | :--- |
| **Source Control & GitOps** | GitHub Enterprise, ArgoCD 2.10+ | Trunk-based SCM, signed commits, declarative cluster sync |
| **Continuous Integration** | GitHub Actions (Reusable Workflows) | Hermetic multi-stage build, parallelized quality stages |
| **Progressive Delivery** | Argo Rollouts, Istio Service Mesh | Dynamic Canary traffic shifting (5%->20%->50%->100%), Blue-Green |
| **Static Security (SAST)** | SonarQube Enterprise 10.5, Semgrep | OWASP Top 10, PII leakage detection, crypto algorithm hygiene |
| **Dependency & Supply Chain**| Aqua Trivy, Anchore Syft, Cosign | CycloneDX SBOM, CVE gating, KMS hardware image signing |
| **Contract & Integration** | Pact Framework, Testcontainers | Consumer-driven contract verification, ephemeral mock switches |
| **Dynamic Security (DAST)** | OWASP ZAP 2.14, StackHawk | Authenticated dynamic REST/gRPC API scanning on preview envs |
| **Policy-as-Code** | Open Policy Agent (OPA), Kyverno | RBI 2023 rules, PCI-DSS v4.0, Segregation of Duties (4-eyes) |
| **Persistence & Migration** | PostgreSQL 16 Aurora, Liquibase | Zero-lock Expand-Contract migrations, async throttled backfill |
| **Observability & Alerting**| Prometheus, Grafana, OpenTelemetry | Real-time SLI monitoring, DORA metrics, Category A/B rollbacks |
| **Infrastructure-as-Code** | Terraform 1.7+, Helm 3.14+ | Multi-AZ EKS provisioning, cascading environment configurations |

---

## Local Verification Commands

All automation and verification test suites are operational and can be executed locally:

```bash
# 1. Execute synthetic banking transaction verification (100 transactions)
python verification/synthetic-transactions.py --mode dry-run --count 100

# 2. Execute automated chaos & canary rollback verification test (< 15s)
bash verification/chaos-rollback-test.sh

# 3. Verify pre-migration database safety and lock timeouts
bash database/scripts/pre-migration-lock-check.sh

# 4. Verify code coverage quality gate
bash pipeline/scripts/check-coverage.sh --min-line 80 --min-branch 70

# 5. Verify post-deployment fleet image consistency (Knight Capital Prevention)
bash pipeline/scripts/verify-deployment.sh novapay-payment-service banking-production
```
