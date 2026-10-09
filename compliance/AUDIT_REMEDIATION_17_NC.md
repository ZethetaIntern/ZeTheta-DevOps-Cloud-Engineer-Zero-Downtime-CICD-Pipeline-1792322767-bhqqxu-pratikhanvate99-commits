# NovaPay Digital Bank: RBI Audit Remediation Matrix (17 Non-Conformances)

This document establishes the comprehensive, automated remediation strategy for all 17 outstanding Reserve Bank of India (RBI) audit non-conformances identified during the statutory IT examination of NovaPay Digital Bank. Every non-conformance is remediated permanently through shift-left automated gates, GitOps workflows, and cryptographic enforcement within the zero-downtime CI/CD pipeline.

---

## Summary Status Dashboard

| NC Ref | Domain / Area | Severity | Legacy Finding Summary | Automated CI/CD Remediation | Target Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **NC-01** | Change Governance | Critical | Manual deployments via SSH without CAB approval | Enforce mandatory CAB ID validation in GitOps PR gate | **CLOSED / AUTOMATED** |
| **NC-02** | Segregation of Duties | Critical | Developers hold SSH and write access to production | Complete revocation of SSH keys; GitOps pull-only deployment | **CLOSED / AUTOMATED** |
| **NC-03** | Vulnerability Mgmt | High | Unscanned third-party libraries deployed to prod | Automated Trivy/Snyk SCA gate blocking on High/Critical CVEs | **CLOSED / AUTOMATED** |
| **NC-04** | Static Code Security | High | No automated SAST scanning prior to deployment | Semgrep & SonarQube quality gates blocking code promotion | **CLOSED / AUTOMATED** |
| **NC-05** | Dynamic Security Testing | High | No DAST or API security testing in release cycle | Automated OWASP ZAP dynamic scan on ephemeral preview envs | **CLOSED / AUTOMATED** |
| **NC-06** | Secret Management | Critical | Hardcoded credentials and API tokens in source code | Pre-commit and pipeline Gitleaks/Trufflehog secret detection | **CLOSED / AUTOMATED** |
| **NC-07** | Supply Chain Security | High | Untracked software components; no SBOM | Automatic generation of CycloneDX & SPDX SBOM with signing | **CLOSED / AUTOMATED** |
| **NC-08** | Artifact Integrity | Critical | Production images not verified for tampering | Cosign cryptographic signing with AWS KMS & Kyverno admission | **CLOSED / AUTOMATED** |
| **NC-09** | Testing & Code Coverage | Medium | Lack of automated unit/integration test gates | Enforced >=85% line coverage & Pact contract test verification | **CLOSED / AUTOMATED** |
| **NC-10** | Database Change Control | High | Manual, unreviewed DDL scripts executed directly | Liquibase versioned changesets with expand-contract automation | **CLOSED / AUTOMATED** |
| **NC-11** | High Availability / RTO | Critical | 4.5h MTTR during failed production deployments | Automated Canary/Blue-Green rollouts with <15s rollback | **CLOSED / AUTOMATED** |
| **NC-12** | Audit Logging & Trail | High | Incomplete audit trail of production changes | Immutable Git commit history + SLSA Level 3 provenance logs | **CLOSED / AUTOMATED** |
| **NC-13** | Emergency Changes | Critical | Unregulated hotfix deployments bypassing review | Automated "Break-Glass" pipeline with dual-CISO authorization | **CLOSED / AUTOMATED** |
| **NC-14** | Container Privilege | High | Containers running as root with writable rootfs | Distroless non-root images + OPA read-only rootfs policies | **CLOSED / AUTOMATED** |
| **NC-15** | Data Protection / Masking | High | Unmasked customer PII/card data in debug logs | Semgrep regex rules banning logging of PAN/Aadhaar/UPI PIN | **CLOSED / AUTOMATED** |
| **NC-16** | Cryptographic Standards | Medium | Legacy algorithms (SHA-1, 3DES) found in code | SonarQube security rules enforcing AES-GCM-256 and SHA-256+ | **CLOSED / AUTOMATED** |
| **NC-17** | Configuration Drift | High | Production server configs diverged from Git | GitOps reconciliation via ArgoCD enforcing desired state | **CLOSED / AUTOMATED** |

---

## Detailed Remediation Specifications

### NC-01: Unauthorized & Manual Production Deployments
- **Regulatory Citation**: RBI Master Direction on IT Governance (2023), Chapter III, Para 15 (Change Management).
- **Finding**: Production deployments were conducted manually over SSH by individual engineers using untracked commands, without verified Change Advisory Board (CAB) approval.
- **Root Cause**: Lack of automated release orchestration and absence of CI/CD pipeline integration with IT Service Management (ITSM).
- **Automated CI/CD Control**:
  - Open Policy Agent (OPA) gate in Stage 7 queries JIRA/ServiceNow API.
  - Pull Request title and Git metadata must contain a validated, approved `CAB-[0-9]+` ticket in status `APPROVED`.
  - Pipeline automatically fails if the ticket is missing, rejected, or unapproved.
- **Audit Evidence Artifact**: Signed JSON attestation in immutable S3 compliance bucket containing `cab_ticket_id`, `cab_approver_identity`, and `timestamp`.

### NC-02: Violation of Segregation of Duties (SoD) in Production
- **Regulatory Citation**: RBI Cyber Security Framework for Banks, Annex 1, Para 2 (Access Control) & PCI-DSS v4.0 Req 6.4.1.
- **Finding**: Software developers who author source code possess direct SSH access and sudo privileges to production infrastructure.
- **Root Cause**: Shared bastion hosts and absence of GitOps boundary.
- **Automated CI/CD Control**:
  - Elimination of all SSH keys and administrative credentials on production nodes.
  - Deployment is strictly executed by ArgoCD running inside the Kubernetes cluster pulling from Git.
  - GitHub branch protection enforces the "4-eyes principle": the author of a commit/PR is strictly barred from approving their own PR (`sod_enforcement.rego`).
- **Audit Evidence Artifact**: GitHub branch protection rule configuration export and ArgoCD sync audit logs demonstrating zero human credentials used in deployment.

### NC-03: Deployed Dependencies Not Screened for Vulnerabilities
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 22 (Vulnerability Assessment) & PCI-DSS v4.0 Req 6.3.2.
- **Finding**: Multiple third-party Java/Node dependencies in production contained unpatched CVEs with published exploit code.
- **Root Cause**: Dependency updates were manual; no automated Software Composition Analysis (SCA) existed in the build lifecycle.
- **Automated CI/CD Control**:
  - Stage 4 executes Trivy and Snyk against `pom.xml`, `package.json`, and lockfiles.
  - Gate policy rejects build if any vulnerability with severity `CRITICAL` or `HIGH` is detected without an active, CISO-approved security exemption waiver.
- **Audit Evidence Artifact**: Standardized CycloneDX JSON vulnerability report generated per build, stored in the compliance archive.

### NC-04: Absence of Automated Static Application Security Testing (SAST)
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 23 (Secure Application Development).
- **Finding**: Code pushed to production underwent only peer functional reviews, with no static analysis for security flaws or anti-patterns.
- **Root Cause**: Lack of CI scanning tooling; development deadlines prioritized feature velocity over automated verification.
- **Automated CI/CD Control**:
  - Stage 3 runs Semgrep and SonarQube Enterprise on 100% of pull requests.
  - Custom rulesets inspect for OWASP Top 10, SQL injection, insecure deserialization, and path traversal.
  - Quality Gate blocks PR merging if security rating drops below `A`.
- **Audit Evidence Artifact**: SonarQube Quality Gate webhook payload cryptographically signed and linked to the build summary.

### NC-05: Missing Dynamic Security & API Vulnerability Scanning (DAST)
- **Regulatory Citation**: RBI Cyber Security Framework, Annex 1, Para 8 (Application Security Testing).
- **Finding**: Web APIs and payment switch endpoints deployed without dynamic vulnerability scanning or runtime fuzzing.
- **Root Cause**: DAST tools were run only annually prior to external audit.
- **Automated CI/CD Control**:
  - Stage 6 spins up an ephemeral preview environment mirroring production configurations.
  - OWASP ZAP runs automated, authenticated API security scans using OpenAPI/Swagger specs to test for IDOR/BOLA, injection, and auth bypass.
  - Builds fail automatically on any High/Critical dynamic finding.
- **Audit Evidence Artifact**: OWASP ZAP XML/HTML executive and technical scan report archived in S3 with build SHA.

### NC-06: Hardcoded Credentials and Secrets in Source Repositories
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 27 (Cryptographic Controls) & PCI-DSS v4.0 Req 8.3.
- **Finding**: Database passwords, payment gateway private keys, and third-party API tokens discovered committed in plaintext in git repositories.
- **Root Cause**: Absence of automated secret scanning and local environment variable mismanagement.
- **Automated CI/CD Control**:
  - Gitleaks and Trufflehog execute as pre-commit hooks and as Stage 4 CI gates.
  - Scans complete git commit history for API keys, private keys, AWS credentials, and tokens.
  - Secret scanning alerts immediately revoke compromised keys and block pipeline execution.
  - All application runtime secrets are injected dynamically via HashiCorp Vault / AWS Secrets Manager via External Secrets Operator.
- **Audit Evidence Artifact**: Gitleaks zero-violation report logged per commit SHA.

### NC-07: Inability to Trace Software Supply Chain & Bill of Materials
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 31 (Cyber Security in Third Party Arrangements).
- **Finding**: The bank was unable to provide a comprehensive inventory of open-source and proprietary components during critical zero-day notifications (e.g., Log4Shell).
- **Root Cause**: No automated generation of Software Bill of Materials (SBOM).
- **Automated CI/CD Control**:
  - Stage 2 invokes Syft/CycloneDX to generate standardized SBOMs in CycloneDX 1.5 JSON and SPDX 2.3 formats.
  - SBOM captures every dependency, version, license, and cryptographic digest.
  - SBOMs are signed with Cosign and pushed to the container registry alongside the container image.
- **Audit Evidence Artifact**: Registry-indexed SBOM artifacts cryptographically linked to production container digests.

### NC-08: Unsigned Container Images and Lack of Image Integrity Proof
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 20 (Integrity of Software & Data).
- **Finding**: Images deployed to production could be modified or substituted in transit without detection.
- **Root Cause**: Standard Docker pushes without signing or verification infrastructure.
- **Automated CI/CD Control**:
  - Stage 4 signs built images using `cosign sign` backed by AWS KMS HSM keys.
  - SLSA Level 3 provenance attestation is attached to the image digest.
  - Kubernetes cluster admission controller (Kyverno / OPA Gatekeeper) blocks any pod from scheduling if the image signature is invalid or absent.
- **Audit Evidence Artifact**: Cosign signature verification log and Kyverno admission audit logs in AWS CloudWatch.

### NC-09: Insufficient Code Testing Coverage & Lack of Contract Testing
- **Regulatory Citation**: RBI Master Direction (2023), Chapter III, Para 16 (Quality Assurance and Testing).
- **Finding**: Features released with untested edge cases, causing core ledger reconciliation discrepancies between microservices.
- **Root Cause**: Unit test coverage was voluntary; zero contract testing between microservices.
- **Automated CI/CD Control**:
  - Stage 2 enforces JaCoCo code coverage threshold: minimum 85% line coverage, 80% branch coverage.
  - Stage 5 enforces Pact consumer-driven contract testing; breaking API changes fail the build before deployment.
- **Audit Evidence Artifact**: JaCoCo XML execution report and Pact Broker verification status matrix.

### NC-10: Uncontrolled and Destructive Database Schema Alterations
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 24 (Data Integrity and Management).
- **Finding**: Manual SQL scripts with table locks executed during production hours, causing database lockups and connection pool exhaustion.
- **Root Cause**: Ad-hoc database alterations executed directly by DBAs via psql/pgAdmin.
- **Automated CI/CD Control**:
  - Transition to Liquibase version-controlled declarative migrations.
  - Enforcement of the Expand-Contract pattern: all schema changes must be backward-compatible.
  - Pre-flight migration lock script sets `lock_timeout = '2s'` and fails immediately if locks cannot be acquired safely.
- **Audit Evidence Artifact**: Liquibase `DATABASECHANGELOG` table audit records with commit author, MD5 checksum, and execution timestamp.

### NC-11: Excessive Recovery Times (4.5h MTTR) Due to Lack of Automated Rollback
- **Regulatory Citation**: RBI Master Direction (2023), Chapter V, Para 35 (Disaster Recovery & Business Continuity) & Five-Nines Availability Mandate.
- **Finding**: A failed production deployment resulted in a 4.5-hour service outage due to manual recovery steps and data inconsistencies.
- **Root Cause**: Monolithic manual deployment scripts with no automated canary validation or instant traffic-shifting mechanisms.
- **Automated CI/CD Control**:
  - Argo Rollouts with progressive Canary deployment (5% -> 20% -> 50% -> 100%) and Blue-Green deployment.
  - Real-time Prometheus SLI analysis templates monitoring 5xx error rate and p99 latency.
  - Automatic rollback executed in < 15 seconds upon SLI threshold breach without human intervention.
- **Audit Evidence Artifact**: Argo Rollouts `AnalysisRun` telemetry data and Prometheus rollback event logs.

### NC-12: Inadequate Audit Logging and Non-Repudiation for Deployments
- **Regulatory Citation**: RBI Cyber Security Framework, Annex 1, Para 10 (Audit Logging) & PCI-DSS v4.0 Req 10.2.
- **Finding**: Audit logs lacked correlation between git commits, build artifacts, approval tickets, and deployed container versions.
- **Root Cause**: Log fragments scattered across CI server logs, SSH bash history, and CloudTrail without unified correlation.
- **Automated CI/CD Control**:
  - End-to-end GitOps traceability: Git Commit SHA -> JIRA CAB Ticket -> Sonar/Trivy Scan Digests -> Cosign KMS Signature -> Container Image SHA -> Kubernetes Deployment Spec.
  - Metadata bundle exported to AWS S3 Glacier with Object Lock (Compliance Mode WORM) retaining logs for 7 years as mandated by RBI.
- **Audit Evidence Artifact**: Immutable deployment manifest bundle in S3 Glacier with tamper-proof cryptographic checksum.

### NC-13: Unaudited Emergency Changes ("Break-Glass" Deployments)
- **Regulatory Citation**: RBI Master Direction (2023), Chapter III, Para 18 (Emergency Changes).
- **Finding**: Emergency bug fixes were pushed directly to production instances without post-incident reviews or authorization records.
- **Root Cause**: Emergency procedures lacked a formalized automated workflow.
- **Automated CI/CD Control**:
  - Dedicated `break-glass-hotfix.yml` pipeline requiring dual cryptographic authorization: Head of Core Banking + CISO.
  - Generates time-boxed (2-hour) deployment tokens.
  - Triggers automated post-incident audit ticket requiring CAB retro-reconciliation within 24 hours.
- **Audit Evidence Artifact**: Break-glass execution log signed by CISO hardware key, registered in SIEM (Splunk/Elastic).

### NC-14: Containers Operating with Elevated Root Privileges
- **Regulatory Citation**: RBI Cyber Security Framework, Annex 1, Para 3 (Operating System Security).
- **Finding**: Production containers were running as root user (`UID 0`) with read-write root filesystems.
- **Root Cause**: Default Docker configurations used in microservice templates.
- **Automated CI/CD Control**:
  - Multi-stage Dockerfile builds enforce `USER 10001:10001` (non-root distroless base).
  - Kubernetes security context strictly enforces:
    `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`.
  - OPA Gatekeeper policy blocks admission of any container failing these specifications.
- **Audit Evidence Artifact**: Kyverno security policy validation logs and Kubernetes Pod security standard (PSS) compliance reports.

### NC-15: Exposure of Sensitive Customer Data (PII/Cardholder Data) in Logs
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 25 (Customer Information Protection) & PCI-DSS v4.0 Req 3.3.
- **Finding**: Bank account numbers, Aadhaar numbers, and cardholder data found unmasked in application application debug logs.
- **Root Cause**: Developers used unrestricted log statements (`log.info("Processing payload: {}", payload)`) without automated masking.
- **Automated CI/CD Control**:
  - Semgrep custom static rules scan code for logging statements containing sensitive field names or regex patterns matching PAN, Aadhaar, CVV, or passwords.
  - Pipeline fails immediately on match.
  - FluentBit log forwarding pipeline implements real-time regex redaction at edge nodes before transmitting to central logging.
- **Audit Evidence Artifact**: Semgrep PII scan clean report and FluentBit redaction rule configuration test results.

### NC-16: Use of Deprecated and Cryptographically Weak Algorithms
- **Regulatory Citation**: RBI Master Direction (2023), Chapter IV, Para 27 (Cryptographic Controls) & PCI-DSS v4.0 Req 4.2.
- **Finding**: Core payment gateway components utilized legacy SHA-1 hashing and DES/3DES encryption algorithms.
- **Root Cause**: Legacy code retained across platform updates without cryptographic code review.
- **Automated CI/CD Control**:
  - SonarQube and Semgrep rules enforce strict cryptographic standards:
    Bans `MD5`, `SHA-1`, `DES`, `3DES`, `RC4`, `RSA < 2048`.
    Enforces `AES-GCM-256`, `SHA-256/384/512`, `ChaCha20-Poly1305`, `RSA 4096 / ECDSA P-384`.
  - Pipeline fails on discovery of banned cryptographic primitives.
- **Audit Evidence Artifact**: Cryptographic inventory scan report generated per release.

### NC-17: Configuration Drift Between Environments
- **Regulatory Citation**: RBI Master Direction (2023), Chapter III, Para 17 (Configuration Management).
- **Finding**: Configuration parameters in production diverged significantly from staging and version-controlled repositories due to ad-hoc manual hotfixes.
- **Root Cause**: In-situ editing of configuration files directly on production hosts.
- **Automated CI/CD Control**:
  - GitOps single source of truth: all environment configurations, ConfigMaps, and Secrets are maintained in Git.
  - ArgoCD operates in `selfHeal: true` and `prune: true` mode: any manual alteration made in production is automatically overwritten by ArgoCD within 60 seconds to match the Git state.
- **Audit Evidence Artifact**: ArgoCD drift reconciliation event logs and Git configuration change history.
