# Deliverable 7B: Incident Response Playbook & Real-World Case Study Solutions

## 1. Severity Classification Framework (Page 11 Specification)

| Severity | Definition | Response SLA | Escalation Path | Mandatory Communications |
| :--- | :--- | :--- | :--- | :--- |
| **SEV-1** | Complete service outage, data corruption, or payment switch halt | **< 5 minutes** | CTO + CISO + VP Engineering + Head SRE | Internal Slack war room, status page update every 30m, RBI notification if > 30m |
| **SEV-2** | Major feature degradation affecting > 10% of banking users | **< 15 minutes** | VP Engineering + SRE Lead + QA Lead | Internal Slack, status page update hourly |
| **SEV-3** | Minor degradation with existing technical workaround | **< 1 hour** | SRE On-Call + Application Tech Lead | Internal Jira incident update |
| **SEV-4** | Cosmetic or non-customer-impacting operational defect | **Next business day** | Assigned Feature Engineer | Standard Jira defect backlog |

---

## 2. The 7-Step Incident Response Workflow
1. **DETECT**: Monitoring system (Prometheus/CloudWatch) or automated canary tripwire fires alert.
2. **TRIAGE**: On-call SRE validates severity classification within 30 seconds.
3. **MOBILIZE**: PagerDuty initiates automated Sev-1 war room bridge (`#incident-sev1-live`).
4. **CONTAIN / ROLLBACK**: Execute automated or manual rollback in < 15 seconds. Terminate faulty canary traffic.
5. **REMEDIATE**: Isolate underlying fault (deadlock, memory leak, network partition) in sandbox environment.
6. **VERIFY**: Run synthetic banking transaction suite against production to verify error rates $\le$ 0.01% and P99 $\le$ 150ms.
7. **POST-MORTEM**: Convene blameless RCA within 48 hours; submit report to Technology Risk Committee (TRC).

---

## 3. Communication Templates

### 3.1 Initial Acknowledgement (SEV-1) - T+5 Minutes
> **Subject**: [SEV-1 INCIDENT DECLARED] Elevated Error Rates on Payment Gateway  
> **Audience**: Executive Leadership, TRC, SRE War Room  
> **Content**:  
> At 17:07 IST, monitoring detected elevated HTTP 5xx error rates (12%) affecting the NovaPay Payment Gateway. Incident Commander [Name] has mobilized the Sev-1 war room. Automated canary rollback has been initiated. Next update in 30 minutes. Status page: https://status.novapay.bank

### 3.2 Regular Update Template - Every 30 Minutes
> **Status Update #1 (17:35 IST)**:  
> Traffic to canary has been isolated (0% weight). Stable replica set is processing 100% of payment requests. PostgreSQL connection pool has stabilized from 95% down to 24%. Synthetic transaction verification confirms nominal UPI processing (success rate 99.99%). Engineering is analyzing heap dumps from isolated canary pods.

### 3.3 Resolution & Post-Mortem Report Template
> **Incident Summary**: INC-99214  
> **Duration**: 17:07 IST to 17:18 IST (11 minutes total impact, MTTR < 15m).  
> **Root Cause**: Bypassed staging deployment introduced unindexed query in UPI handler, exhausting PostgreSQL connection pool.  
> **Permanent Remediation**: Codified OPA gate rejecting any pull request that bypasses staging environments.

---

## 4. Friday 5:07 PM Incident Simulation Walkthrough (Section B5)

### Scenario Context
At **5:07 PM IST on Friday**, a developer pushed a "critical hotfix" that bypassed staging. The canary deployment ran for 8 minutes before three alerts fired simultaneously:
1. `ALERT: HTTP 500 error rate at 12% (threshold: 5%) - Severity: CRITICAL`
2. `ALERT: PostgreSQL connection pool exhaustion on primary - Severity: HIGH`
3. `ALERT: Downstream payment gateway timeout rate at 35% - Severity: CRITICAL`

### Step-by-Step Decision & Action Timeline
- **T+0 (17:07:00)**: Prometheus alert rules fire simultaneously across Envoy proxy and pgBouncer metrics.
- **T+12s (17:07:12)**: **Automated Canary Rollback Triggered**: Argo Rollouts `AnalysisTemplate` detects Category A breach (HTTP 5xx > 5% for 60s). Controller automatically overrides Istio weight to **0% on Canary** and restores **100% on Stable**.
- **T+30s (17:07:30)**: SRE On-Call acknowledges PagerDuty Sev-1 page. Confirms live dashboard shows traffic has diverted completely away from faulty pods.
- **T+1m (17:08:00)**: SRE executes connection pool drain command on pgBouncer to clear stalled connections caused by canary:
  ```bash
  psql -h pgbouncer.novapay -p 6432 -c "RECONNECT novapay_banking;"
  ```
- **T+2m (17:09:00)**: Automated communication broadcast sent to `#incident-sev1` Slack and executive status page updated.
- **T+4m (17:11:00)**: SRE launches synthetic smoke test harness:
  ```bash
  python3 verification/synthetic-transactions.py --mode live --count 100
  ```
  Result: 100% success rate, 32ms average latency. System fully healthy. Total customer impact duration: **4 minutes 12 seconds (MTTR well under 15-minute target)**.
- **T+10m (17:17:00)**: SRE isolates the stopped canary pods for forensic investigation (heap dump and slow query logs extracted to S3 compliance bucket).

### Root Cause Analysis & Gate Gap Evaluation
- **Why did this happen?**: The developer used a manual override flag (`--bypass-staging`) which lacked formal dual-authorization.
- **Missing Pipeline Gate**: Stage 7 lacked an immutable OPA policy strictly verifying that the image digest had been actively verified in the `staging` namespace with a signed attestation before allowing production admission.
- **Remediation**: Implemented `compliance/policies/rbi_controls.rego` requiring cryptographic Staging Attestation (`staging_tested == true`), mathematically preventing any unverified hotfix from deploying to production.

---

## 5. Real-World Case Study Simulation Solutions (Part C)

### 5.1 Case Study 1: Knight Capital Disaster Prevention Step
- **Challenge**: Manual server-by-server deployment missed the 8th server, which executed dead trading code, losing $440M in 45 minutes.
- **NovaPay Solution - Deployment Verification Kill-Switch**:
  1. Pre-deployment fleet inventory queries Kubernetes API to catalog all active pod digests.
  2. Post-deployment verification step executes `scripts/verify-fleet-consistency.sh`:
     - Asserts that 100% of running pods in the deployment run the identical, single container image digest (`sha256:...`).
     - Validates that environment configurations and ConfigMaps match across all pods.
  3. **Automated Kill-Switch**: If any pod returns a divergent image digest or legacy binary hash, an automated kill-switch isolates the workload in **< 10 seconds**, preventing financial trade execution.

### 5.2 Case Study 2: YES Bank Observability & RBI Reporting Stack
- **Challenge**: Digital systems and UPI collapsed during March 2020 moratorium; incidents detected only by customer complaints; untested DR.
- **NovaPay Solution - 30-Second UPI Detection & Regulatory Workflow**:
  1. Real-time Prometheus alerting rule (`UPI_TechnicalDeclineRateSurge`): evaluates UPI transaction declines over 30-second rolling window. Fires SEV-1 if technical decline rate exceeds 0.5%.
  2. Automated status page integration triggers immediate notification to retail users within 60 seconds.
  3. **RBI 30-Minute Regulatory Notification Workflow**: In compliance with RBI Master Direction (2023) Chapter V Para 36, if any critical payment rail outage exceeds **30 minutes**, an automated webhook compiles telemetry, incident timeline, and customer impact estimates into a formal encrypted dispatch directly transmitted to the RBI Department of Supervision.

### 5.3 Case Study 3: Cloudflare Outage WAF Configuration Pipeline
- **Challenge**: Misconfigured WAF regex deployed globally without canary testing caused 100% CPU exhaustion across all edge servers, taking 27 minutes to recover.
- **NovaPay Solution - WAF & Configuration Delivery Pipeline**:
  1. All WAF rules, routing filters, and Envoy configurations must pass through the identical 8-stage CI/CD pipeline as application code.
  2. Pre-deployment stage runs automated regex backtracking linters (preventing ReDoS).
  3. Canary testing in staging environment compares CPU and memory baselines against historical norms.
  4. **Out-of-Band Independent Rollback**: Rollback controller runs on an isolated management plane independent of edge proxy CPU state, with automated circuit breaker tripwire: if proxy CPU > 80%, rule is ejected within **5 seconds**.

### 5.4 Case Study 4: SBI YONO Deployment Blackout Calendar & Autoscaling
- **Challenge**: Mobile banking app collapsed repeatedly during predictable traffic spikes (salary days 1st and 7th, month-ends, festivals) due to poor capacity planning and deployment timing conflicts.
- **NovaPay Solution - Deployment Blackout Calendar & Dynamic Scaling**:
  1. **Codified Blackout Engine**: OPA policy `compliance/policies/deployment_blackout.rego` blocks any non-emergency production deployment during:
     - Salary disbursement windows: 1st, 7th, and 15th of every month.
     - Month-end reconciliation: 28th through 31st of every month.
     - Major national festival days (Diwali, Eid, Holi, Christmas).
     - Daily peak UPI settlement windows: 10:00 AM–12:00 PM and 5:00 PM–8:00 PM IST.
  2. **Automated Elastic Autoscaling**: Kubernetes Horizontal Pod Autoscaler (HPA) configured with custom Prometheus metrics:
     - Scales up when CPU > 70%, or RabbitMQ queue depth > 1,000 messages, or P99 latency > 300ms.
  3. **Mandatory 48-Hour Pre-Peak Load Testing**: Any release deployed within 48 hours of a high-traffic window must pass a synthetic 3x peak load test in pre-prod.
