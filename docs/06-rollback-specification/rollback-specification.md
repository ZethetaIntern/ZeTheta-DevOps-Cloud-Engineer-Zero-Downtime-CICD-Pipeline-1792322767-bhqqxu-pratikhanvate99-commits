# Deliverable 6A: Automated Rollback Specification & 3-Tier Trigger Taxonomy

## 1. Executive Context & Availability Mandate
In an RBI-regulated banking environment processing high-velocity UPI and IMPS transactions, automated rollback is the fundamental safety net that enables continuous delivery while protecting the 99.999% availability SLA.

NovaPay implements a **3-Tier Rollback Taxonomy** operating across deterministic detection horizons.

---

## 2. The 3-Tier Rollback Trigger Taxonomy (Page 7 & 38 Specification)

### Category A: Immediate Triggers (< 60 Seconds)
*Action: Instant traffic re-routing and pod diversion executed autonomously by the platform with ZERO human intervention.*

| # | Trigger Name | Detection Method | Precise Threshold | Autonomous Action |
| :--- | :--- | :--- | :--- | :--- |
| **A1** | **HTTP 5xx Burst** | Prometheus Envoy Scrape | HTTP 5xx rate > 5.0% sustained for 60 seconds | Argo Rollouts aborts Canary; Istio weight reset to 0% |
| **A2** | **Health Probe Failure** | Kubelet Pod Status | 3 consecutive readiness/liveness probe failures | Kubernetes removes pod from endpoints; triggers Rollout abort |
| **A3** | **OOM Kill Event** | Kubelet / cAdvisor | Pod terminated with Exit Code 137 (`OOMKilled`) | Immediate rollout freeze and rollback to previous version |
| **A4** | **CrashLoopBackOff** | Kubernetes API Event | Pod restart count $\ge$ 3 within 90 seconds | Instant rollback; prevention of cascading pod restarts |
| **A5** | **DB Pool Exhaustion** | pgBouncer / HikariCP | Active DB connections > 95% of pool capacity for 30s | Instant traffic cutoff from canary to protect primary database |

### Category B: Escalated Triggers (< 15 Minutes)
*Action: Immediate high-priority page to on-call SRE with an automated rollback if the incident is not acknowledged and contained within the 10-minute escalation window.*

| # | Trigger Name | Detection Method | Precise Threshold | Action & Escalation Path |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | **P99 Latency Surge** | Prometheus Istio Metrics | P99 latency > 2x baseline (e.g. > 300ms) for 5 minutes | Page SRE Lead; auto-rollback if unacknowledged in 10m |
| **B2** | **Error Budget Burn** | Sloth / Prometheus SLO | 1-hour error budget burn rate > 10x nominal for 10 min | Sev-1 Alert; automated canary scale-down |
| **B3** | **Transaction Drop** | Banking Application Metric | Business transaction success rate drops > 2.0% below baseline | Escalated page; automated traffic reversal |
| **B4** | **Resource Saturation** | cAdvisor Pod Metrics | CPU > 90% OR Memory > 85% sustained for 5 minutes | HPA scale-up attempt; if saturation persists, rollback |

### Category C: Manual Decision Triggers (Human Judgement)
*Action: Real-time warnings surfaced on engineering dashboards; rollback requires human confirmation.*
1. **Gradual Degradation**: Slight increase in error rate or latency below automated tripwire thresholds.
2. **Customer Care / Dispute Reports**: Customer support receives surge in transaction dispute complaints.
3. **Downstream Banking Dependency Anomaly**: NPCI UPI switch or partner bank API begins intermittently dropping requests.
4. **Retroactive Compliance Discovery**: Discovery of a latent regulatory or audit defect post-deployment.

---

## 3. The 8-Step Rollback Execution Workflow

```
[ Step 1: DETECT ] ──> [ Step 2: CORRELATE ] ──> [ Step 3: FREEZE ] ──> [ Step 4: ROLLBACK ]
  Prometheus SLI         Alertmanager links       Halt all pipeline       Istio resets traffic
  threshold breached     anomaly to deploy SHA    progressions            weight to 0% (< 15s)
                                                                                  │
[ Step 8: POST-MORTEM ] <── [ Step 7: INCIDENT ] <── [ Step 6: NOTIFY ] <── [ Step 5: VERIFY ]
  Blameless RCA &        JIRA Sev-1 auto-ticket   Slack / PagerDuty       Synthetic smoke test
  action item tracking   opened for CISO review   broadcast payload       confirms health
```

1. **Step 1: DETECT**: Prometheus, Istio, or Kubelet detects metric threshold violation.
2. **Step 2: CORRELATE**: Alertmanager correlates metric anomaly directly to the deployment Git commit SHA and Rollout revision.
3. **Step 3: FREEZE**: CI/CD pipeline and deployment progressions are locked globally.
4. **Step 4: ROLLBACK**: Argo Rollouts controller sets Canary weight to 0% and shifts 100% traffic back to Stable ReplicaSet (Duration: **11.4 seconds**).
5. **Step 5: VERIFY**: Post-rollback synthetic verification suite automatically executes 50 test transactions to confirm error rates have cleared.
6. **Step 6: NOTIFY**: Automated notification dispatched to `#incident-sev1` Slack channel, PagerDuty, and email distribution list.
7. **Step 7: INCIDENT CREATION**: Incident management system creates ticket `INC-XXXXX` pre-populated with CloudWatch logs and Prometheus metrics.
8. **Step 8: POST-MORTEM**: Mandatory blameless post-mortem scheduled within 48 hours to document root cause and pipeline gate enhancements.
