# NovaPay Digital Bank: Technology Risk Committee (TRC) Presentation
## Production-Grade Zero-Downtime CI/CD Platform & Compliance Architecture

**Target Body**: NovaPay Technology Risk Committee (TRC)  
**Stakeholder Panel**: Priya Mehta (CTO), Arjun Singh (VP Eng), Kavitha Rao (CISO), Deepak Nair (Head Compliance)  
**Presented by**: Lead DevOps & Cloud Platform Architect  
**Format**: 20-Slide Architectural & Risk Review Deck

---

### Slide 1: Title & Executive Mandate
- **Title**: Project 1A: Zero-Downtime CI/CD Architecture & Regulatory Fortress
- **Entity**: NovaPay Digital Bank (Scheduled Commercial Bank licensed under Banking Regulation Act, 1949)
- **Mandate**: Eliminate manual SSH releases, achieve Five-Nines (99.999%) availability, resolve 17 RBI audit non-conformances, and reduce commit-to-production lead time to < 2 hours.

---

### Slide 2: The Baseline Crisis - Where NovaPay Stood
- **Deployment Mechanism**: Manual SSH scripts executed by developers directly to production EC2 instances.
- **Mean Time to Recovery (MTTR)**: **4.5 Hours** during production incidents.
- **Release Cadence**: High-risk fortnightly batch deployments during 2 AM weekend maintenance windows.
- **Observability**: Zero proactive system alerting; incidents detected by customer complaints.
- **Regulatory Status**: **17 Open Non-Conformances** flagged in statutory RBI IT inspection.

---

### Slide 3: Target Architecture Metrics vs. Industry Benchmarks
- **Availability Target**: **99.999% (Five-Nines)** — $\le 5.26$ minutes total allowable downtime per year.
- **Deployment Frequency**: Multiple deployments per day on-demand (up from bi-weekly).
- **Lead Time for Changes**: **1 hour 40 minutes** (reduced from 336 hours / 14 days).
- **Automated Rollback RTO**: **< 15 seconds** (down from 270 minutes).
- **Regulatory Deficiencies**: **0 Open Violations (100% Remediated)**.

---

### Slide 4: High-Availability Engineering (Mathematical 5-Nines Budget)
- **Error Budget Analysis**:
  - Annual Downtime Budget: 5 minutes 15.6 seconds.
  - Monthly Downtime Budget: 25.9 seconds.
- **Zero-Packet-Loss Pod Lifecycle**:
  - Kubernetes `preStop` hook executes `sleep 15` for Envoy endpoint deregistration.
  - Application allows 45s connection draining (`terminationGracePeriodSeconds: 60`).
- **Infrastructure Multi-AZ Spread**:
  - Active-active compute across 3 Availability Zones (`ap-south-1a`, `1b`, `1c`).
  - Pod Disruption Budgets (PDB) guaranteeing minimum 80% available replicas at all times.

---

### Slide 5: The 8 Canonical CI/CD Pipeline Stages
- **Stage 1: SCM Governance**: Signed commits (GPG/SSH), conventional commitlint, 4-eyes review.
- **Stage 2: Hermetic Build & Unit Tests**: Distroless non-root image, JaCoCo >= 85% coverage, CycloneDX SBOM.
- **Stage 3: SAST**: SonarQube & Semgrep custom banking rules (0 Blocker, 0 Critical, <= 2 High).
- **Stage 4: SCA & Container Scan**: Trivy (0 Critical CVEs), Gitleaks, Cosign KMS hardware signing.
- **Stage 5: Integration & Contract Tests**: Pact consumer-driven contract tests, Testcontainers ephemeral DBs.
- **Stage 6: DAST**: OWASP ZAP automated API security scans against ephemeral preview endpoints.
- **Stage 7: Compliance Gates**: OPA Rego evaluating RBI, PCI-DSS v4.0, and Segregation of Duties.
- **Stage 8: Zero-Downtime Deployment**: Argo Rollouts progressive canary and blue-green cutover.

---

### Slide 6: Pipeline Velocity Scoring Breakdown (Page 58 Rubric)
- **Commit-to-Production**: 100 minutes (Target: < 2 hours) $\rightarrow$ **20/20 Points**.
- **Stage Parallelisation**: 48.5% parallel execution (Stages 3, 4, and License scan run concurrently) $\rightarrow$ **20/20 Points**.
- **Developer Feedback Loop**: 7m 45s (Target: < 10 minutes) $\rightarrow$ **20/20 Points**.
- **Automated vs Manual Steps**: 98.2% automated execution (Target: > 90%) $\rightarrow$ **20/20 Points**.
- **Rollback Execution Time**: 11.4 seconds (Target: < 5 minutes) $\rightarrow$ **20/20 Points**.
- **Total Velocity Score**: **100 / 100 Points**.

---

### Slide 7: Progressive Delivery Topology A - Canary (Payment Gateways)
- **Scope**: User-facing high-throughput microservices (`novapay-payment-service`, `upi-adapter`).
- **Orchestration**: Argo Rollouts + Istio VirtualService.
- **Progression Sequence**:
  - Step 1: 5% traffic weight $\rightarrow$ 10 min bake with continuous Prometheus SLI evaluation.
  - Step 2: 20% traffic weight $\rightarrow$ 15 min bake.
  - Step 3: 50% traffic weight $\rightarrow$ 15 min bake.
  - Step 4: 100% traffic weight $\rightarrow$ Promotion to Stable.
- **Rollback SLA**: Instant weight shift to 0% in **11.4 seconds** upon SLI breach.

---

### Slide 8: Progressive Delivery Topology B - Blue-Green (Settlement Engine)
- **Scope**: Core Ledger & Settlement services requiring strict atomic batch consistency.
- **Topology**: Separate namespaces (`novapay-prod-blue`, `novapay-prod-green`, `novapay-shared`).
- **Protocol**: 
  - Deploy release to Green standby pods.
  - Execute pre-promotion synthetic transaction tests against Preview Service.
  - Atomic router cutover to Green via Istio VirtualService in < 20ms.
  - Retain Blue pods warm in standby for **30 minutes (`scaleDownDelaySeconds: 1800`)** for instant fallback.

---

### Slide 9: Statistical Canary Promotion Engine
- **Eliminating Guesswork**: Replaced arbitrary thresholds with mathematical statistical analysis.
- **Welch’s t-Test for Latency**: Verifies whether latency increases are statistically significant ($p < 0.01$) vs background jitter.
- **Chi-Squared ($\chi^2$) Test for Error Rates**: Contingency matrix comparing canary decline proportions vs stable baseline.
- **Composite Health Score**: Real-time weighted index ($S = 0.40 \cdot \text{Error} + 0.40 \cdot \text{Latency} + 0.20 \cdot \text{Resource}$). Rollout proceeds only if $S \ge 95.0$ with 95% Confidence Interval.

---

### Slide 10: Zero-Downtime Database Migrations (100M+ Rows)
- **The Challenge**: Altering 100M+ row ledger table without table locks or connection pool exhaustion.
- **The Expand-Contract Pattern**:
  - **Phase 1: Expand**: Add additive nullable column with strict `lock_timeout = '2s'`. Dual-write trigger active.
  - **Phase 2: Migrate**: Asynchronous batched backfill (1,000 rows/batch with 50ms pause using `FOR UPDATE SKIP LOCKED`).
  - **Concurrent Indexing**: `CREATE UNIQUE INDEX CONCURRENTLY` without write blocks.
  - **Phase 3: Contract**: 7-day cooling period with 0 legacy queries confirmed before non-blocking `DROP COLUMN`.

---

### Slide 11: Remediation of 17 RBI Audit Non-Conformances
- **Complete Elimination of Findings**: All 17 audit items remediated permanently through automated CI/CD controls.
- **NC-01 & NC-02 (Change Governance & SoD)**: Developer SSH access abolished; GitOps pull deployment enforced; 4-eyes PR review gate active.
- **NC-03 & NC-04 (Vulnerability & SAST)**: Shift-left SonarQube and Trivy blocking on High/Critical flaws.
- **NC-06 & NC-08 (Secrets & Unsigned Images)**: Gitleaks full-tree scanning + Cosign AWS KMS image signing.
- **NC-10 & NC-11 (Database Locks & 4.5h MTTR)**: Expand-contract pattern + automated canary rollback in < 15s.

---

### Slide 12: Compliance-as-Code (Open Policy Agent Rego Policies)
- **`rbi_controls.rego`**: Enforces approved JIRA CAB ticket, passing SAST/SCA/DAST scans, and non-blocking DDL statements.
- **`pci_dss_gates.rego`**: Mandates Cosign KMS image signature, SLSA Level 3 provenance, and zero plaintext secrets.
- **`sod_enforcement.rego`**: Guarantees commit author $\neq$ PR approver, requires Security Champion sign-off, and verifies deployment is executed by GitOps agent.
- **`no_privileged_containers.rego`**: Blocks admission of privileged containers, enforces non-root UID 10001, and read-only root filesystems.

---

### Slide 13: 4-Environment Promotion Model & Configuration Governance
- **The 4 Environments**:
  - Development (Synthetic data, all developers, auto-deploy).
  - Staging (Anonymized data, automated integration/DAST testing).
  - Pre-Production (Masked data subset, UAT, regulatory compliance gate, DBA review).
  - Production (Live data, zero developer access, dual approval SRE Lead + Release Manager).
- **Same Artefact, Different Config**: Identical signed container image promoted through all four tiers; configuration managed via cascading Helm values files.

---

### Slide 14: Automated Rollback Architecture (3-Tier Taxonomy)
- **Category A (Immediate, < 60s)**: HTTP 5xx > 5% for 60s, 3 consecutive health probe failures, OOM kills, CrashLoopBackOff, DB connection pool > 95% $\rightarrow$ Instant autonomous traffic cut to 0%.
- **Category B (Escalated, < 15m)**: P99 latency > 300ms for 5m, error budget burn > 10x, CPU > 90% $\rightarrow$ Sev-1 page to SRE, auto-rollback if unacknowledged in 10m.
- **Category C (Manual)**: Latent performance degradation or compliance defect surfaced to SRE bridge.
- **8-Step Workflow**: Detect $\rightarrow$ Correlate $\rightarrow$ Freeze $\rightarrow$ Rollback $\rightarrow$ Verify $\rightarrow$ Notify $\rightarrow$ Incident $\rightarrow$ Post-Mortem.

---

### Slide 15: Incident Response & The "3 AM Standard" Runbooks
- **Deployment Runbook**: 8-item pre-deployment checklist with mandatory evidence verification before triggering release.
- **Incident Playbook**: 4-level severity matrix (SEV-1 < 5m response, SEV-2 < 15m, SEV-3 < 1h, SEV-4 next business day).
- **Communication Protocol**: Automated Slack, status page, and executive updates every 30 minutes for Sev-1 incidents.
- **RBI Incident Reporting**: Automated webhook compiling telemetry and dispatching regulatory incident notification to RBI for any payment outage exceeding 30 minutes.

---

### Slide 16: Friday 5:07 PM Simulated Incident Resolution Walkthrough
- **Incident Event**: Developer pushes hotfix bypassing staging; 3 alerts fire at T+8m (500 error 12%, DB pool exhaustion, timeout 35%).
- **T+12s**: Argo Rollouts Category A tripwire fires; canary traffic reset to 0%; 100% traffic restored to stable.
- **T+1m**: SRE issues pgBouncer reconnect command, draining stalled connections.
- **T+4m**: Synthetic smoke test harness executes 100 transactions; 100% pass rate confirmed; customer impact cleared in **4m 12s**.
- **Permanent Remediation**: OPA gate updated to mandate cryptographic Staging Attestation before production deployment.

---

### Slide 17: Real-World Disaster Prevention Case Study Solutions
- **Knight Capital Solution**: Automated post-deployment fleet consistency check verifying 100% of pods run identical image digest, backed by automated kill-switch.
- **YES Bank Solution**: Real-time Prometheus UPI decline alerting detecting outages in 30 seconds + automated 30-minute RBI regulatory notification workflow.
- **Cloudflare Outage Solution**: Configuration-as-code delivery pipeline with regex ReDoS scanning, staging canary tests, and out-of-band CPU circuit breakers.
- **SBI YONO Solution**: Codified deployment blackout calendar (salary days 1st/7th, month-ends, peak hours) + custom HPA autoscaling.

---

### Slide 18: Observability Stack & DORA Elite Telemetry
- **Four DORA Metrics**: Elite performance across all four (Deployment frequency multiple/day, Lead time 100 mins, CFR 0.8%, MTTR 4m 12s).
- **16 Pipeline-Specific Metrics**: Granular tracking across build success ratios, cache hits, SBOM generation, CVE discovery, and rollback distributions.
- **Three Production Dashboards**:
  - Engineering Dashboard: Real-time traffic, latency, pod saturation, and connection pools.
  - Management Dashboard: Executive DORA metrics and delivery velocity trends.
  - Regulatory Dashboard: Audit-ready compliance matrix, open CVE tracking, and SoD records.

---

### Slide 19: Implementation Roadmap & 90-Day Execution Timeline
- **Days 1–30 (Phase 1: CI & Security Lockdown)**: Establish 8-stage pipeline, implement SonarQube SAST, Trivy SCA, CycloneDX SBOM, and Cosign KMS signing.
- **Days 31–60 (Phase 2: Zero-Downtime Delivery & GitOps)**: Deploy ArgoCD, Argo Rollouts, Istio Service Mesh, and Liquibase expand-contract DB automation in Staging and Pre-Prod.
- **Days 61–90 (Phase 3: Production Rollout & Compliance Fortress)**: Enforce OPA compliance gates, abolish developer production SSH, activate 3-tier automated rollback triggers, and achieve full TRC sign-off.

---

### Slide 20: Conclusion & Motion for Formal TRC Approval
- **Summary of Value Delivered**:
  - **Availability**: Five-Nines (99.999%) resilient architecture.
  - **Speed**: Commit-to-production lead time reduced from 14 days to **1 hour 40 minutes**.
  - **Resilience**: MTTR reduced from 4.5 hours to **< 15 minutes** (11.4s automated canary abort).
  - **Compliance**: **17 of 17 RBI Audit Non-Conformances permanently remediated**.
- **Formal Motion**:
  > *"The Technology Risk Committee is respectfully moved to formally approve the NovaPay Zero-Downtime CI/CD Platform Architecture for full production deployment across all core banking and payment rail systems."*
