# Deliverable 7A: Production Deployment Runbook (The 3 AM Standard)

## 1. Operational Philosophy
This runbook is written to the **"3 AM Standard"**: an on-call engineer with minimal context awakened during a nocturnal release must be able to follow this procedure unambiguously with zero guesswork.

---

## 2. The 8-Item Pre-Deployment Checklist

Before any production deployment is triggered, the SRE Lead and Release Manager must verify the following eight items in the automated release portal:

| # | Checklist Item | Required Evidence Artifact | Validation Mechanism | Sign-Off Role |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Unit Tests & Code Coverage** | JaCoCo XML report showing line coverage $\ge$ 80% and branch coverage $\ge$ 70% | Automated GitHub Actions CI status check | Automated CI |
| **2** | **SAST Security Clearance** | SonarQube Quality Gate `PASSED` (0 Critical, $\le$ 2 High findings) | Webhook payload signed by SonarQube | Security Champion |
| **3** | **SCA, SBOM & Image Signature** | Trivy 0 Critical CVEs, CycloneDX JSON SBOM, Cosign signature verified | Cosign verification against AWS KMS public key | DevSecOps Lead |
| **4** | **API Contract Verification** | Pact Broker verification matrix showing 100% provider compatibility | `pact-broker can-i-deploy` return code `0` | QA Lead |
| **5** | **DAST Security Clearance** | OWASP ZAP scan report with 0 Critical/High findings | ZAP XML scan artifact in S3 | SecOps Engineer |
| **6** | **Regulatory Compliance Gates** | OPA Conftest attestation passing `rbi_controls.rego` & `pci_dss_gates.rego` | Signed JSON compliance bundle | Head of Compliance |
| **7** | **Database Lock Pre-Flight** | Script output confirming 0 active transactions > 10s and replica lag < 5s | `database/scripts/pre-migration-lock-check.sh` output | Primary DBA |
| **8** | **Change Governance (CAB) Approval** | JIRA ticket in status `APPROVED` with dual digital signatures | Conftest verification of `CAB-[0-9]+` | Release Manager & SRE |

---

## 3. Step-by-Step Deployment Execution Procedure

```
[ Step 1: Pre-Flight Lock Check ]
              │
              ▼
   Pass? ──NO──> [ ABORT: Reschedule with DBA ]
     │
    YES
     ▼
[ Step 2: Liquibase Expand Migration ]
              │
              ▼
   Pass? ──NO──> [ Rollback DB Change & Terminate ]
     │
    YES
     ▼
[ Step 3: Trigger GitOps Synchronization (ArgoCD) ]
              │
              ▼
[ Step 4: Progressive Canary Progression (1% -> 5% -> 25% -> 100%) ]
              │
              ├─────────── Anomaly / SLI Breach? ───────────┐
              ▼                                             ▼
          [ NO ]                                         [ YES ]
              │                                             │
              ▼                                             ▼
[ Step 5: Post-Deploy Synthetic Verification ]     [ AUTOMATED ROLLBACK (<15s) ]
              │                                    [ Traffic shifted to 0% ]
              ▼                                    [ Warm stable pods active ]
    [ DEPLOYMENT STABLE ]
```

### Detailed Execution Steps:
1. **Pre-Flight Verification**: Run `./database/scripts/pre-migration-lock-check.sh`. If active transactions exist, postpone migration by 15 minutes.
2. **Execute Expand Migration**: Trigger Liquibase runner. Verify new column exists and dual-write trigger is functioning.
3. **Trigger GitOps Rollout**:
   ```bash
   argocd app sync novapay-payment-service --prune
   ```
4. **Monitor Rollout Telemetry**:
   ```bash
   kubectl argo rollouts get rollout novapay-payment-service -n banking-production --watch
   ```
5. **Post-Deployment Verification**:
   ```bash
   python3 verification/synthetic-transactions.py --mode live --url https://payment-api.novapay.bank --count 100
   ```
