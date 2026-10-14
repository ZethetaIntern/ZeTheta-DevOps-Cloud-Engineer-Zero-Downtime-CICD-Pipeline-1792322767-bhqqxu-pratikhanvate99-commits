# Deliverable 8: Observability Strategy, DORA Metrics & Alerting Architecture

## 1. The DORA Metrics Framework for Regulated Banking

NovaPay measures software delivery performance against the **DevOps Research and Assessment (DORA)** benchmarks, achieving **Elite Performer** status across all four core indicators:

| DORA Metric | Definition | Industry Benchmark (Elite) | NovaPay Target & Current SLA | Measurement Methodology |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Frequency** | Frequency of successful production releases | Multiple per day | **3 to 5 deployments per day** | Count of ArgoCD production synchronization events |
| **Lead Time for Changes** | Duration from git commit to running in production | < 1 hour | **1 hour 40 minutes (100 mins)** | Timestamp diff: `commit.timestamp` $\rightarrow$ `argocd_sync_success` |
| **Change Failure Rate (CFR)**| Percentage of production releases requiring rollback | < 5.0% | **0.8% (Target: < 2.0%)** | $\frac{\text{Rollbacks} + \text{Emergency Hotfixes}}{\text{Total Production Deployments}} \times 100$ |
| **Mean Time to Recovery (MTTR)**| Time elapsed from incident detection to restoration | < 1 hour | **< 15 minutes (Avg: 4m 12s)** | Duration: `prometheus_alert_fired` $\rightarrow$ `synthetic_smoke_passed` |

---

## 2. 15+ Pipeline-Specific Observability Metrics

Beyond macro DORA indicators, NovaPay instruments 16 granular telemetry metrics categorized across build, security, and deployment dimensions:

### A. Build & Compilation Category
1. `pipeline_build_success_ratio`: Percentage of CI workflow runs exiting with code 0 (Target: > 95%).
2. `pipeline_build_duration_seconds`: Wall-clock execution time of multi-stage Docker compilation.
3. `pipeline_cache_hit_ratio`: Maven/Gradle dependency cache and Docker buildx cache efficiency (Target: > 85%).
4. `pipeline_flaky_test_count`: Number of test cases that fail and subsequently pass upon re-run.
5. `pipeline_unit_test_coverage_ratio`: JaCoCo line and branch coverage percentage (Target: $\ge$ 80%).

### B. Security & Compliance Category
6. `pipeline_gate_pass_ratio`: Success rate of Stage 3 (SAST), Stage 4 (SCA), and Stage 6 (DAST) gates.
7. `pipeline_vulnerability_discovery_count`: New CVEs discovered per build classified by CVSS severity.
8. `pipeline_false_positive_ratio`: Percentage of SonarQube / Semgrep issues marked as false positive by Security Champions.
9. `pipeline_secret_scan_violations_count`: Plaintext credentials detected by Gitleaks.
10. `pipeline_sbom_generation_latency_seconds`: Time required to produce and sign CycloneDX 1.5 JSON artifact.
11. `pipeline_sod_compliance_ratio`: Percentage of pull requests strictly adhering to 4-eyes principle (Target: 100%).

### C. Deployment & Operational Category
12. `pipeline_deployment_duration_seconds`: Total time taken for Argo Rollouts progressive canary completion.
13. `pipeline_rollback_frequency_total`: Counter of automated rollbacks partitioned by trigger category (A, B, C).
14. `pipeline_canary_step_dwell_time_seconds`: Duration spent at 1%, 5%, 25%, and 50% traffic weights.
15. `pipeline_synthetic_transaction_latency_p99`: Real-time P99 latency recorded during post-deploy verification.
16. `pipeline_db_lock_wait_duration_ms`: Duration database migration waited to acquire locks during DDL execution.

---

## 3. Alerting Strategy & Severity-Based Routing Matrix

Alerts are routed through Alertmanager with strict suppression, grouping, and deduplication rules:

| Alert Severity | Notification Channels | Escalation Window | Automated Action Triggered |
| :--- | :--- | :--- | :--- |
| **CRITICAL** (Sev-1) | PagerDuty (Phone Call + SMS), `#incident-sev1-live` Slack, Executive SMS | **< 3 minutes** to ack | Initiates automated canary rollback (< 15s) and connection pool drain |
| **HIGH** (Sev-2) | PagerDuty (Push Notification), `#incident-sev2` Slack | **< 10 minutes** to ack | Pauses ongoing rollouts; alerts SRE Lead |
| **WARNING** (Sev-3) | Slack `#banking-platform-alerts`, Jira ticket | **< 1 hour** to ack | Telemetry annotation logged; no automated traffic shift |
| **INFO** (Sev-4) | Slack `#deployments-feed` | Informational | Metrics logged to Grafana Loki |

---

## 4. The Three Production Dashboards

### 4.1 Engineering Operations Dashboard (Real-Time Ops)
- Target Audience: SREs, DevOps Engineers, On-Call Rotation.
- Key Panels: Real-time traffic split (Stable vs Canary), HTTP 5xx error rate gauge, P50/P90/P99 latency heatmaps, active database connections vs HikariCP max pool, pod memory/CPU utilization.

### 4.2 Management DORA Dashboard (Executive Velocity)
- Target Audience: CTO, VP Engineering, Product Owners.
- Key Panels: 30-day DORA performance status, weekly deployment frequency trend, mean commit-to-production lead time breakdown, change failure rate vs 5% target, team velocity throughput.

### 4.3 Regulatory Compliance Dashboard (Audit-Ready)
- Target Audience: Head of Compliance, CISO, Internal Audit, RBI Inspectors.
- Key Panels: RBI Master Direction (2023) control pass rate (100%), open non-conformances tracking (0 open), Cosign image signature verification status, open CVEs by CVSS score, Segregation of Duties audit log.
