# NovaPay Digital Bank: PCI-DSS v4.0 Compliance Matrix

This document maps the technical and procedural controls implemented within NovaPay's Zero-Downtime CI/CD Platform directly to the **Payment Card Industry Data Security Standard (PCI-DSS) version 4.0**, specifically addressing software development lifecycle, access control, vulnerability management, and audit logging.

---

## PCI-DSS v4.0 Requirements Mapping

| PCI-DSS v4.0 Requirement | Standard Specification | NovaPay CI/CD Pipeline Implementation | Automated Enforcement Tool |
| :--- | :--- | :--- | :--- |
| **Req 3.3.1**<br>Protection of Sensitive Cardholder Data | Sensitive authentication data (SAD) and PAN must be protected and masked whenever stored or processed. | Static analysis scanning for hardcoded PAN/SAD patterns; automated masking in application logs. | Semgrep custom regex rules + FluentBit edge log redaction. |
| **Req 6.2.1**<br>Bespoke & Custom Software Security | Software developed for or impacting the CDE is developed securely in accordance with industry standards. | Mandatory SAST scanning in Stage 3 targeting OWASP Top 10, CWE-259, and injection vulnerabilities. | SonarQube Enterprise Quality Gate + Semgrep Banking Ruleset. |
| **Req 6.2.4**<br>Software Vulnerability Remediation | Software vulnerabilities must be identified and mitigated before release to production. | Automated SAST and DAST gates block pull request merging and staging deployment if High/Critical issues exist. | SonarQube + Semgrep (SAST) + OWASP ZAP (DAST). |
| **Req 6.3.1**<br>Software Vulnerability Identification | Security vulnerabilities in third-party software components are identified, evaluated, and addressed. | Automated Software Composition Analysis (SCA) in Stage 4 scans all libraries against CVE databases. | Trivy and Snyk SCA vulnerability scanners. |
| **Req 6.3.2**<br>Software Inventory & Components | An inventory of bespoke and third-party software components is maintained to facilitate vulnerability management. | Automated generation of CycloneDX and SPDX Software Bill of Materials (SBOM) for every release build. | Syft SBOM generator integrated into Stage 2 build process. |
| **Req 6.4.1**<br>Separation of Environments | Development, test, and production environments are strictly separated to prevent unauthorized access and changes. | Isolated AWS accounts and Kubernetes namespaces; developers have zero access to production CDE. | AWS Organizations + Kubernetes RBAC + GitOps pull architecture. |
| **Req 6.4.2**<br>Segregation of Duties (SoD) | Separation of duties between personnel assigning and developing changes and personnel approving/deploying them. | Developer cannot approve their own pull request; deployment is executed only by ArgoCD service accounts. | GitHub branch protection + `compliance/policies/sod_enforcement.rego`. |
| **Req 6.4.3**<br>Production Change Control | All changes to system components in production follow established change control procedures with back-out plans. | Mandatory CAB ticket validation, automated zero-downtime Canary/Blue-Green deployment, and automated rollback triggers. | OPA `compliance/policies/rbi_controls.rego` + Argo Rollouts `AnalysisTemplate`. |
| **Req 6.5.1**<br>Changes Approved Prior to Release | Changes are tested and authorized before being applied to production components. | Stage 2, 5, 6, and 7 testing gates must pass with cryptographic attestations prior to production deployment. | Open Policy Agent (OPA) / Conftest release gate evaluation. |
| **Req 7.2.1**<br>Least Privilege Access Model | Access to system components and cardholder data is restricted to individuals whose roles require such access. | Direct developer SSH and interactive shell access to production is eliminated; deployments mediated via GitOps. | AWS IAM OIDC roles with short-lived tokens; zero developer SSH keys. |
| **Req 8.3.1**<br>Multi-Factor Authentication (MFA) | Multi-factor authentication is required for all administrative access and all access into the CDE. | Hardware security key (FIDO2/WebAuthn) MFA enforced on GitHub, AWS IAM, and the Break-Glass emergency pipeline. | GitHub Enterprise Managed Users + AWS IAM MFA enforcement. |
| **Req 10.2.1**<br>Audit Logging of Changes | Audit logs record all administrative actions, changes to system components, and initialization of audit logs. | Git commit SHA, author identity, CAB approval, scan outputs, and Cosign signatures captured in immutable audit bundle. | AWS S3 Object Lock (WORM compliance mode) with 7-year retention. |
| **Req 10.2.2**<br>Audit Log Details | Audit logs capture date and time, event type, identity, event outcome, and affected component. | Automated release provenance generated via SLSA Level 3 attestations capturing all contextual build metadata. | SLSA provenance generator + in-toto attestation format. |
| **Req 11.3.1**<br>Vulnerability Assessments | Internal and external vulnerability assessments are performed regularly and after significant changes. | Automated DAST scanning executed in Stage 6 against ephemeral environments before every production release. | OWASP ZAP API automated dynamic security scanner. |

---

## Cryptographic Key Management & Storage Controls (PCI-DSS Req 3.5 & 3.6)
1. **Container Image Signing Keys**:
   - Managed inside dedicated AWS Key Management Service (KMS) FIPS 140-3 Level 3 Hardware Security Modules (HSMs).
   - Keys are strictly non-exportable.
   - Access to `kms:Sign` is granted exclusively to the CI/CD GitHub Actions runner via short-lived OIDC session tokens restricted to repository `main` branch.
2. **Kubernetes Secret Storage**:
   - Database credentials, payment gateway keys, and HSM tokens are stored in AWS Secrets Manager / HashiCorp Vault.
   - Synchronized to Kubernetes secrets using the External Secrets Operator with automated 90-day rotation.
   - Secrets are never committed to Git, baked into container images, or displayed in CI logs.
