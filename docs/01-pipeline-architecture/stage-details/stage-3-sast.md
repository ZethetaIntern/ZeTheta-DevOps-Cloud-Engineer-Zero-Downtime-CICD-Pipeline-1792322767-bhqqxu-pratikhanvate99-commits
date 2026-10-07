# Stage 3 Specification: Static Application Security Testing (SAST)

## 1. Tooling & Versions
- **Primary Static Analysis**: SonarQube Enterprise Server v10.5+ / SonarCloud Scanner
- **Rule Engine**: Semgrep Community & Enterprise Engine v1.68+
- **Security Profiles**: OWASP Top 10 2021, CWE Top 25, Sans Top 25, Custom NovaPay Banking Rulepack v2.1

## 2. Configuration Parameters
- **Sonar Quality Profile**:
  - `sonar.qualitygate.wait: true`
  - `sonar.java.binaries: target/classes`
  - `sonar.coverage.jacoco.xmlReportPaths: target/site/jacoco/jacoco.xml`
- **Semgrep Configs**: `p/owasp-top-ten`, `p/cwe-top-25`, `p/banking-pii-leakage`, `p/insecure-crypto`
- **Differential Scanning**: PR diff analysis scanning changed lines and call graph implications.

## 3. Threshold Values & Gates
- **Critical Severity**: 0 tolerated (Hard block).
- **High Severity**: <= 2 tolerated (provided CVSS < 8.0 and no active exploit).
- **Technical Debt Ratio**: <= 5.0% on new code.
- **Security Hotspots**: 100% reviewed and acknowledged.
- **Cryptographic Algorithms**: Absolute ban on MD5, SHA-1, DES, 3DES, RC4; mandatory AES-GCM-256 and SHA-256/384.
- **PII Leakage**: 0 unmasked instances of Aadhaar, PAN, UPI PIN, or Account Number in log statements.

## 4. Failure Modes & Remediation
- **Blocker / Critical Finding Detected**: Quality Gate webhook returns `FAIL`. Pipeline terminates. SonarQube PR decoration posts direct code annotation with remediation snippet. Developer must refactor code.
- **Exception Path**: If false positive, Security Champion can review in SonarQube and mark `Won't Fix` or `False Positive` with formal cryptographic audit justification.

## 5. Retry & Skip Logic
- **Retries**: 1 retry allowed on SonarQube API network timeout.
- **Skip Conditions**: Strictly prohibited.

## 6. SLA Target
- **Execution Duration**: <= 420 seconds (7 minutes).
