# Deliverable 3: Automated Compliance Gate Architecture (6+ Gates)

## 1. Compliance Architecture Overview
In compliance with Section A.4.3 (Page 9) of the ZeTheta Regulatory Specification, NovaPay implements **six (6) mandatory, automated compliance gates** in the CI/CD pipeline. Every gate is non-optional and hard-blocking, possessing:
1. Precise numerical pass/fail thresholds.
2. Direct remediation guidance for developers.
3. Formal, time-delimited exception workflows.
4. Structured audit trail output in cryptographically signed JSON schema.
5. Direct mapping to RBI Master Direction (2023) and PCI-DSS v4.0 clauses.

---

## 2. Canonical Compliance Gates Master Matrix

| # | Gate | Tool | Precise Threshold | Action On Failure | Formal Exception Workflow | Regulatory Mapping |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **SAST Gate** | SonarQube Enterprise & Semgrep | 0 Critical, $\le$ 2 High, $\ge$ 80% line coverage, 0 PII leaks | Pipeline blocked, auto-ticket opened | CISO cryptographic approval token (24-hour SLA) | RBI 2023 Ch.IV Para 23; PCI-DSS v4.0 Req 6.2 |
| **2** | **DAST Gate** | OWASP ZAP & StackHawk | 0 Critical/High findings from OWASP API Top 10 | Pipeline blocked | Formal Risk Acceptance Form + Technology Risk Committee (TRC) approval | RBI 2023 Annex 1 Para 8; PCI-DSS v4.0 Req 6.4, 11.3 |
| **3** | **Dependency Gate** | Aqua Trivy & Snyk | 0 Critical CVEs (CVSS $\ge$ 9.0), SBOM generated in CycloneDX | Pipeline blocked if CVSS $\ge$ 8.0 or exploit published | 72-hour remediation window with CISO waiver | RBI 2023 Ch.IV Para 22, 31; PCI-DSS v4.0 Req 6.3 |
| **4** | **License Gate** | ScanCode Toolkit & FOSSA | 0 GPL / AGPL / SSPL copyleft licenses | Legal review triggered, build held | Legal Counsel cryptographic sign-off | RBI 2023 Ch.IV Para 31 (Third Party Legal Risk) |
| **5** | **Policy Gate** | OPA / Conftest & Kyverno | 100% of Kubernetes admission and SoD policies pass | Deployment rejected | Dual Approval Override (Head of Eng + SRE Lead) | RBI 2023 Ch.III Para 14, 15; PCI-DSS Req 6.4.2 |
| **6** | **Infra Gate** | Checkov & tfsec | 0 Privileged containers, memory/CPU limits set, encrypted EBS | PR status check blocked | Tech Lead exemption with documented compensating control | RBI 2023 Annex 1 Para 3; PCI-DSS Req 6.4.1 |

---

## 3. Deep-Dive Specification for Each Gate

### Gate 1: Static Application Security Testing (SAST)
- **Precise Thresholds**:
  - Critical Severity = 0
  - High Severity $\le$ 2 (with CVSS < 8.0)
  - Unit Test Code Coverage $\ge$ 80% line, $\ge$ 70% branch
  - Technical Debt Ratio $\le$ 5% on new code
  - Unmasked PII (PAN, Aadhaar, PIN, Account) = 0
- **Remediation Guidance**: SonarQube PR decoration provides specific line-number refactoring instructions and CWE reference links.
- **Exception Workflow**: Requires formal submission of CISO Approval Form within 24 hours. The waiver is registered in Vault with an auto-expiry TTL of 14 days.

### Gate 2: Dynamic Application Security Testing (DAST)
- **Precise Thresholds**:
  - 0 Critical or High severity vulnerabilities across OWASP API Security Top 10.
  - Mandatory validation of TLS 1.3, HSTS (`max-age=31536000; includeSubDomains`), and zero BOLA/IDOR authorization bypasses.
- **Remediation Guidance**: OWASP ZAP export contains reproduction curl commands and HTTP request/response traces.
- **Exception Workflow**: Requires formal submission of Risk Acceptance Form signed by TRC Chairman.

### Gate 3: Dependency Vulnerability Scanning (SCA)
- **Precise Thresholds**:
  - 0 Critical CVEs (CVSS 9.0–10.0).
  - High CVEs (CVSS 7.0–8.9) blocked if exploit exists in CISA KEV (Known Exploited Vulnerabilities) database.
  - Valid CycloneDX 1.5 JSON Software Bill of Materials (SBOM) generated.
- **Remediation Guidance**: Trivy outputs dependency graph, showing the exact root package and minimal upgraded version.
- **Exception Workflow**: 72-hour temporary waiver issued by CISO if no patch is upstream available, provided network mitigation (WAF/EnvoyFilter) is deployed.

### Gate 4: Open-Source License Compliance Gate
- **Precise Thresholds**:
  - Permitted: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC.
  - Prohibited: GPL-2.0, GPL-3.0, AGPL-3.0, SSPL, LGPL (without dynamic linking), Commons Clause.
- **Remediation Guidance**: ScanCode identifies offending transitive dependency. Developer must replace with an enterprise-permissive equivalent.
- **Exception Workflow**: Formal sign-off by General Counsel / Legal Department.

### Gate 5: Kubernetes Policy-as-Code & Segregation of Duties (Policy Gate)
- **Precise Thresholds**:
  - `sod_enforcement.rego`: Author $\neq$ Approver; PR Approvers $\ge$ 2.
  - `no_privileged_containers.rego`: `privileged == false`, `readOnlyRootFilesystem == true`.
  - Deployment triggered by authorized GitOps Service Account only.
- **Remediation Guidance**: Conftest outputs failed Rego rule name and file path.
- **Exception Workflow**: Dual cryptographic authorization required via `break-glass-hotfix.yml`.

### Gate 6: Infrastructure-as-Code (IaC) Security Gate
- **Precise Thresholds**:
  - Checkov scans Terraform modules: 0 High/Critical misconfigurations.
  - Enforces AWS KMS customer-managed keys for EBS/RDS/S3, private subnets, and zero `0.0.0.0/0` security group ingress for administrative ports.
- **Remediation Guidance**: Checkov outputs Terraform line number and compliant HCL code block.
- **Exception Workflow**: Tech Lead exemption with compensating security control documented in JIRA.

---

## 4. Structured Audit Trail Format (JSON Schema)

Every gate execution emits a standardized, cryptographically signed JSON attestation archived to an immutable AWS S3 Glacier WORM bucket:

```json
{
  "$schema": "https://compliance.novapay.bank/schemas/v1/gate-audit.json",
  "audit_event_id": "AUDIT-20261019-98214",
  "timestamp": "2026-10-19T13:48:22Z",
  "pipeline_run_id": "8921849120",
  "git_commit_sha": "a1b2c3d4e5f67890123456789abcdef012345678",
  "cab_ticket_id": "CAB-10492",
  "actor": {
    "login": "deployer-bot",
    "role": "GitOps-Automator",
    "authenticated_via": "OIDC-AWS-KMS"
  },
  "gates_evaluated": [
    { "gate_name": "SAST", "tool": "SonarQube-10.5", "status": "PASSED", "critical_count": 0, "high_count": 1, "coverage_line": 88.5 },
    { "gate_name": "DAST", "tool": "OWASP-ZAP-2.14", "status": "PASSED", "critical_count": 0, "high_count": 0 },
    { "gate_name": "Dependency", "tool": "Trivy-0.50", "status": "PASSED", "critical_count": 0, "high_count": 0, "sbom_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
    { "gate_name": "License", "tool": "ScanCode-32", "status": "PASSED", "copyleft_detected": 0 },
    { "gate_name": "Policy-SoD", "tool": "OPA-0.63", "status": "PASSED", "distinct_approvers": 2, "author_approval": false },
    { "gate_name": "Infra", "tool": "Checkov-3.2", "status": "PASSED", "privileged_containers": 0 }
  ],
  "overall_compliance_verdict": "APPROVED_FOR_PRODUCTION",
  "cosign_signature": "MEQCIG9nZ5e3...",
  "regulatory_references": [
    "RBI Master Direction 2023 Ch.III Para 14-18",
    "RBI Master Direction 2023 Ch.IV Para 20-32",
    "PCI-DSS v4.0 Req 6.2-6.5, 10.2, 11.3"
  ]
}
```
