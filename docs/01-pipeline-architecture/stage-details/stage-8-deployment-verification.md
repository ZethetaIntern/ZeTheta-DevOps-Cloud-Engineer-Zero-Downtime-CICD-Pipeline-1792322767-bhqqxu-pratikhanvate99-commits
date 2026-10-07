# Stage 8 Specification: Deployment & Automated Verification (Canary & Blue-Green)

## 1. Tooling & Versions
- **GitOps Controller**: ArgoCD v2.10+
- **Progressive Delivery**: Argo Rollouts v1.6.6+
- **Service Mesh**: Istio v1.21+ (Envoy Proxy 1.29)
- **Metrics Scraper**: Prometheus v2.51+
- **Verification Harness**: Python 3.11+ Synthetic Banking Test Suite

## 2. Configuration Parameters
- **Canary Strategy Progression (Payment Gateway Microservice)**:
  - Step 1: Set weight 5%, pause 10 minutes, evaluate SLIs.
  - Step 2: Set weight 20%, pause 15 minutes, evaluate SLIs.
  - Step 3: Set weight 50%, pause 15 minutes, evaluate SLIs.
  - Step 4: Promote to 100% stable.
- **Blue-Green Strategy Progression (Settlement Engine)**:
  - Deploy to Green Preview Service.
  - Run `prePromotionAnalysis` synthetic batch test suite.
  - Atomic router switch to Green; maintain Blue warm for 30 minutes (`scaleDownDelaySeconds: 1800`).
- **Connection Draining**: `lifecycle.preStop: sleep 15`, `terminationGracePeriodSeconds: 60`.

## 3. Threshold Values & Rollback Triggers
- **HTTP 5xx Error Rate**: Rate > 0.05% (0.0005) triggers instant rollback.
- **P99 Latency**: P99 > 150ms triggers instant rollback.
- **Synthetic Test Pass Rate**: < 99.99% triggers instant rollback.
- **Automated Rollback RTO**: <= 15 seconds.

## 4. Failure Modes & Remediation
- **Canary Anomaly Detected**: Argo Rollouts aborts rollout automatically, drops canary weight to 0%, restores 100% traffic to stable, and dispatches PagerDuty alert.
- **Database Lock Contention**: Pre-migration check script (`lock_timeout = '2s'`) aborts migration before deployment begins, preserving system availability.

## 5. Retry & Skip Logic
- **Retries**: 0 retries on degraded SLIs; instant rollback is mandatory.
- **Skip Conditions**: None.

## 6. SLA Target
- **Execution Duration**: 50 minutes (Canary progression) / 15 minutes (Blue-Green).
- **Post-Deploy Smoke Test**: 4 minutes.
