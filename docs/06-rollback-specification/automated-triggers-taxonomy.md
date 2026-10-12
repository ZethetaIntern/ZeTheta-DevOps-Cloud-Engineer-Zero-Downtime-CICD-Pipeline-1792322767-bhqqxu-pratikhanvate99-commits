# Deliverable 6B: Prometheus Alerting Rules for Automated Rollback

This specification defines the production Prometheus alerting rules configured in Alertmanager to trigger Category A and Category B rollbacks automatically.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: novapay-rollback-alert-rules
  namespace: monitoring
  labels:
    role: alert-rules
    app.kubernetes.io/part-of: novapay-banking-platform
spec:
  groups:
    - name: novapay-immediate-rollback-category-a
      rules:
        # Category A1: HTTP 5xx Error Rate > 5% for 60 seconds
        - alert: CanaryHTTP5xxRateExceeded
          expr: |
            (
              sum(rate(istio_requests_total{reporter="destination", destination_workload="novapay-payment-service", response_code=~"5.*"}[1m]))
              /
              (sum(rate(istio_requests_total{reporter="destination", destination_workload="novapay-payment-service"}[1m])) + 0.0001)
            ) > 0.05
          for: 60s
          labels:
            severity: critical
            category: rollback-category-a
            tier: tier-1-payment
          annotations:
            summary: "Canary HTTP 5xx error rate exceeded 5% threshold"
            description: "Canary payment-service is returning {{ $value | humanizePercentage }} errors. Automated rollback initiated."
            action: "argo-rollouts-abort"

        # Category A2: Consecutive Health Check Failure
        - alert: PodReadinessConsecutiveFailures
          expr: |
            sum by (pod) (increase(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", namespace="banking-production"}[2m])) > 2
          for: 30s
          labels:
            severity: critical
            category: rollback-category-a
          annotations:
            summary: "Pod entered CrashLoopBackOff in production"
            description: "Pod {{ $labels.pod }} restarted multiple times. Automated rollback triggered."

        # Category A5: PostgreSQL Database Connection Pool Exhaustion (> 95%)
        - alert: DatabaseConnectionPoolCritical
          expr: |
            (hikaricp_connections_active{pool="NovaPayDBPool"} / hikaricp_connections_max{pool="NovaPayDBPool"}) > 0.95
          for: 30s
          labels:
            severity: critical
            category: rollback-category-a
          annotations:
            summary: "Database connection pool reached 95% capacity"
            description: "HikariCP active connections at {{ $value | humanizePercentage }}. Cutting traffic to prevent database lockup."

    - name: novapay-escalated-rollback-category-b
      rules:
        # Category B1: P99 Latency > 2x Baseline (300ms) for 5 minutes
        - alert: CanaryP99LatencyDegraded
          expr: |
            histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket{reporter="destination", destination_workload="novapay-payment-service"}[2m])) by (le)) > 300
          for: 5m
          labels:
            severity: warning
            category: rollback-category-b
          annotations:
            summary: "Canary P99 latency exceeded 300ms for 5 minutes"
            description: "Current P99 latency is {{ $value }}ms. SRE paged. Automated rollback in 10 minutes if unacknowledged."

        # Category B2: Multi-Window Error Budget Burn Rate > 10x
        - alert: ErrorBudgetBurnRateTooHigh
          expr: |
            (
              sum(rate(istio_requests_total{reporter="destination", destination_workload="novapay-payment-service", response_code=~"5.*"}[10m]))
              /
              sum(rate(istio_requests_total{reporter="destination", destination_workload="novapay-payment-service"}[10m]))
            ) > (1 - 0.99999) * 10
          for: 10m
          labels:
            severity: critical
            category: rollback-category-b
          annotations:
            summary: "Error budget burn rate is 10x above sustainable five-nines limit"
            description: "High burn rate threatening monthly availability SLA."
```
