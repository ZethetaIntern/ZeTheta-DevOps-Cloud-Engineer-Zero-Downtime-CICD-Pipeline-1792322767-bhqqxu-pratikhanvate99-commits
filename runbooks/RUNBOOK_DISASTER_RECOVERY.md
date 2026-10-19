# NovaPay Digital Bank: Disaster Recovery & Rapid Rollback Runbook (MTTR < 15 Min)

## 1. Purpose & Incident Response SLA
This standard operating procedure (SOP) defines the operational protocols to maintain **99.999% availability** and guarantee a **Mean Time to Recovery (MTTR) of less than 15 minutes** during production failures, deployment regressions, or catastrophic infrastructure events.

---

## 2. Fast Rollback Procedures by Deployment Topology

### 2.1 Canary Rollback (Payment Gateway Services)
Argo Rollouts automatically aborts canaries when Prometheus SLIs breach thresholds. However, if manual operator intervention is warranted:

1. **Immediate Manual Abort & Reset**:
   ```bash
   # Abort canary and instantly reset traffic weight to 0%
   kubectl argo rollouts abort novapay-payment-service -n banking-production
   
   # Confirm stable pods are serving 100% traffic
   kubectl argo rollouts status novapay-payment-service -n banking-production
   ```
2. **Revert to Previous Known-Good ReplicaSet**:
   ```bash
   kubectl argo rollouts undo novapay-payment-service -n banking-production
   ```
3. **Recovery Verification**:
   Execute the synthetic transaction test to confirm API health:
   ```bash
   python3 verification/synthetic-transactions.py --mode live --url https://payment-api.novapay.bank
   ```
   **Expected RTO**: < 30 seconds.

### 2.2 Blue-Green Rollback (Core Settlement Engine)
In the Blue-Green topology, the previous active Blue environment is maintained warm for 30 minutes (`scaleDownDelaySeconds: 1800`).

1. **Instant Router Flip**:
   If an anomaly is detected immediately following cutover:
   ```bash
   # Abort promotion or flip active service selector back to previous blue version
   kubectl argo rollouts undo novapay-settlement-service -n banking-production
   ```
2. **Manual Service Selector Overwrite (Emergency Fallback)**:
   ```bash
   kubectl patch service settlement-service-active -n banking-production -p '{"spec":{"selector":{"app":"novapay-settlement-service","color":"blue"}}}'
   ```
   **Expected RTO**: < 5 seconds.

---

## 3. Database Disaster Recovery & Reversal (Expand-Contract)

Because schema changes follow the 3-phase Expand-Contract pattern, database recovery does not require destructive rollbacks or data restoration:

1. **If Application Fails During Phase 1 (Expand)**:
   - Application rollback requires **zero database action**. Old application version N continues reading and writing to legacy columns.
   - The new column `account_num_v2` and trigger remain dormant until the next release.
2. **If Backfill Fails During Phase 2 (Migrate)**:
   - Backfill is throttled and asynchronous. Terminate the backfill job.
   - Live transaction processing on both versions is completely unimpeded.
3. **If Regression Occurs in Phase 3 (Contract)**:
   - Phase 3 is executed only after a 7-day cooling period with zero queries hitting legacy columns.
   - If emergency reversal is required prior to dropping columns, re-enable application dual-write and re-attach trigger.

---

## 4. Multi-Region Active-Warm Disaster Recovery (Mumbai -> Hyderabad)

In the event of a total AWS Mumbai region (`ap-south-1`) failure:

```
[ DNS / Route 53 Health Checks ]
              │
       ┌──────┴──────┐
       ▼             ▼
  [ Mumbai ]   [ Hyderabad ]
 (Active Primary) (Warm Standby)
```

1. **Route 53 Automated Failover**:
   - Health check probes test Istio ingress health endpoints every 10 seconds from 8 external monitoring nodes.
   - Upon 3 consecutive failures (30 seconds), Route 53 DNS routes traffic to AWS Hyderabad (`ap-south-2`).
2. **Aurora Global Database Failover**:
   - Promote Hyderabad read replica to standalone primary:
     ```bash
     aws rds failover-global-cluster \
         --global-cluster-identifier novapay-aurora-global \
         --target-db-cluster-identifier arn:aws:rds:ap-south-2:123456789012:cluster:novapay-aurora-hyd-cluster
     ```
3. **ArgoCD GitOps Sync to Hyderabad**:
   - Hyderabad EKS cluster scales from warm standby (20% capacity) to 100% capacity via Karpenter autoscaler in < 180 seconds.
   **Total Multi-Region RTO**: < 8 minutes | **RPO**: < 1 second.
