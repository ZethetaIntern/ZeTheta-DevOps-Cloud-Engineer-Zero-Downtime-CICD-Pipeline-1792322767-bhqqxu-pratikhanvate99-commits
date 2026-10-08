# Deliverable 2A: Blue-Green Deployment Architecture Specification

## 1. Domain Context & Workload Classification
At NovaPay Digital Bank, the Blue-Green deployment strategy is applied strictly to **Core Settlement & Financial Ledger microservices** (`novapay-settlement-service`, `novapay-general-ledger`). These stateful, high-consistency engines process discrete, non-idempotent settlement batches where canary traffic splitting or concurrent multi-version writes risk ledger ledger discrepancy and reconciliation failure.

---

## 2. Infrastructure Topology & Namespace Architecture

NovaPay isolates workloads across three dedicated Kubernetes namespaces on AWS EKS:
- `novapay-prod-blue`: Hosts the currently active production release ($V_N$) serving 100% of consumer traffic.
- `novapay-prod-green`: Hosts the newly deployed release candidate ($V_{N+1}$) undergoing pre-promotion validation.
- `novapay-shared`: Houses shared persistence, caching, and messaging tiers (PostgreSQL 16 Aurora Cluster with pgBouncer, Redis 7 Cluster, RabbitMQ 3.13 Cluster).

```
                            [ External Ingress / NLB ]
                                        │
                                        ▼
                         [ Istio Ingress Gateway ]
                                        │
                   ┌────────────────────┴────────────────────┐
                   │  Istio VirtualService (Traffic Switch)   │
                   └────────────────────┬────────────────────┘
                                        │ (100% Traffic)
                        ┌───────────────┴───────────────┐
                        ▼                               ▼
            [ novapay-prod-blue ]           [ novapay-prod-green ]
             Active Stable (v2.1)            Preview Standby (v2.2)
                        │                               │
                        └───────────────┬───────────────┘
                                        ▼
                              [ novapay-shared ]
                     (Aurora PG16, Redis 7, RabbitMQ)
```

---

## 3. The 5-Step Atomic Traffic Switching Protocol

The cutover sequence is orchestrated via GitOps through an automated 5-step transaction:

1. **Step 1: Standby Environment Provisioning**:
   - ArgoCD deploys version $V_{N+1}$ into `novapay-prod-green`.
   - Pods initialize, run startup and readiness probes, and bind to `settlement-service-preview`.
2. **Step 2: Pre-Promotion Synthetic Verification**:
   - Automated synthetic transaction test runner executes end-to-end ledger reconciliation suites against the preview endpoint:
     `http://settlement-service-preview.novapay-prod-green.svc.cluster.local:8080`.
   - Invariant validation: verifies double-entry bookkeeping balances, account locks, and audit logging.
3. **Step 3: Ingress Router Atomic Cutover**:
   - Upon 100% pass of pre-promotion analysis, Istio `VirtualService` manifest is atomically patched to route 100% of production ingress traffic to the Green service.
   - Routing switch takes effect in Envoy data plane within **< 20 milliseconds**.
4. **Step 4: Graceful Connection Draining (Payment Draining)**:
   - Blue pods receive notification of router cutover.
   - Blue pods cease accepting new incoming connections.
   - `preStop` hook executes a configurable payment draining timeout:
     - Standard HTTP APIs: 60-second draining window.
     - Core Settlement / Batch processing jobs: up to **5 minutes (300 seconds)** allowing all in-flight transaction settlements to achieve finality.
5. **Step 5: Warm Standby & Post-Promotion Observation**:
   - Blue pods are **not** immediately terminated. They remain running in warm standby for **30 minutes (`scaleDownDelaySeconds: 1800`)**.
   - If an unexpected regression occurs within the 30-minute window, the router flips back to Blue in **< 5 seconds**.
   - After 30 minutes of flawless operation, Blue pods are gracefully decommissioned.

---

## 4. Distributed Session Management (Redis 7 Cluster)
To ensure zero consumer session drop during the router flip:
- User session state, security tokens, and idempotency keys are externalized to an in-memory Redis 7 cluster (3 master nodes, 3 replica nodes with multi-AZ replication in `novapay-shared`).
- Spring Session Data Redis manages serializable session objects with TLS encryption-in-transit.
- When traffic switches from Blue to Green, Green pods access the identical session store, resulting in zero session invalidation or user logout.

---

## 5. Rollback Procedures & RTO
- **Instant Rollback**: `kubectl argo rollouts undo novapay-settlement-service -n novapay-prod-green`.
- **RTO Guarantee**: **< 5 seconds** (instant Istio router reversal to warm Blue pods).
