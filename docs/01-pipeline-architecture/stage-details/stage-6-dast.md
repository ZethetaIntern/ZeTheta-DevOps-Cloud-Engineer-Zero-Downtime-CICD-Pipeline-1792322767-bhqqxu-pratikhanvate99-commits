# Stage 6 Specification: Dynamic Application Security Testing (DAST)

## 1. Tooling & Versions
- **Dynamic Security Engine**: OWASP ZAP (Zed Attack Proxy) v2.14+ / StackHawk CLI v3.8+
- **API Definition**: OpenAPI 3.0.3 / Swagger Schema Validator
- **Authentication Engine**: OAuth2 / mTLS Test Token Generator

## 2. Configuration Parameters
- **ZAP Execution Mode**: `zap-api-scan.py` running authenticated active and passive scans.
- **Scan Configuration (`zap.conf`)**:
  - `40012\tFAIL\t(Cross Site Scripting - Reflected)`
  - `40018\tFAIL\t(SQL Injection)`
  - `90020\tFAIL\t(Remote OS Command Injection)`
  - `10055\tFAIL\t(Insecure Transport - Cleartext)`
- **Target Endpoint**: Ephemeral preview ingress namespace in staging Kubernetes cluster (`https://preview-pr104.banking-staging.svc.cluster.local`).

## 3. Threshold Values & Gates
- **Critical Severity Vulnerabilities**: 0 tolerated.
- **High Severity Vulnerabilities**: 0 tolerated.
- **Medium Severity Vulnerabilities**: <= 3 tolerated (with formal risk acceptance).
- **OWASP Top 10 API Security**: 100% pass on API1:2023 (BOLA), API2:2023 (Broken Authentication), API3:2023 (BOPL), API8:2023 (Security Misconfiguration).

## 4. Failure Modes & Remediation
- **BOLA / IDOR Vulnerability**: Scan detects that User A token can query User B balance endpoint. ZAP generates HTTP request/response evidence. Pipeline aborts. Developer must enforce authorization check in controller.
- **SQL Injection**: Pipeline aborts. Developer must use parameterized prepared statements.

## 5. Retry & Skip Logic
- **Retries**: 0 retries on vulnerability detection; 1 retry on preview environment network readiness failure.
- **Skip Conditions**: None.

## 6. SLA Target
- **Execution Duration**: <= 900 seconds (15 minutes).
