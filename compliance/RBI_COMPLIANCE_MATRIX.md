# NovaPay Digital Bank: RBI Master Direction & Cyber Security Framework Compliance Matrix

This document provides a formal compliance mapping between the **RBI Master Direction on Information Technology Governance, Risk, Controls and Assurance Practices (2023)** and the **RBI Cyber Security Framework for Banks (Annex 1)** to the automated controls embedded within NovaPay's Zero-Downtime CI/CD delivery platform.

---

## 1. RBI Master Direction on IT Governance, Risk, Controls and Assurance Practices (2023)

### Chapter III: IT Operations & Change Management

| Section & Para | Regulatory Requirement | NovaPay CI/CD Automated Implementation | Technical Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **Para 14**<br>IT Change Governance | All changes must be formally requested, evaluated, prioritized, authorized, tested, and tracked. | Pull requests automatically require validated JIRA Change Advisory Board (CAB) ticket in `APPROVED` status before pipeline progression. | `compliance/policies/rbi_controls.rego` queries CAB ticket ID from PR metadata and verifies digital signatures. |
| **Para 15**<br>Segregation of Duties (SoD) | Clear separation between individuals who design/develop software and those who test or promote to production. | Developers cannot approve their own pull requests (4-eyes principle). Direct human access to production is eliminated; deployments executed exclusively via ArgoCD. | `compliance/policies/sod_enforcement.rego` verifies committer != approver; zero IAM developer write access to prod cluster. |
| **Para 16**<br>Quality Assurance & Testing | Rigorous testing protocols including unit, integration, performance, and regression testing prior to production. | Stage 2 enforces >=85% unit test code coverage; Stage 5 executes consumer-driven contract tests (Pact) and ephemeral banking mocks. | JaCoCo code coverage gate fails build if coverage < 85%; Pact broker contract verification gate. |
| **Para 17**<br>Configuration Management | Base configuration baselines must be documented, versioned, and monitored for unauthorized drift. | All Kubernetes manifests, Helm charts, and environment configs stored in GitOps repository. Production divergence is reconciled automatically. | ArgoCD `selfHeal: true` continuously syncs production state to Git repository within 60 seconds of any unauthorized change. |
| **Para 18**<br>Emergency Changes ("Break-Glass") | Emergency changes must follow an expedited, strictly authorized procedure with full audit logging and post-facto review. | Dedicated `break-glass-hotfix.yml` pipeline requiring dual cryptographic digital approvals (Head of Engineering + CISO). | Time-boxed 2-hour elevated credentials, automatic Jira incident creation, and mandatory retro-reconciliation gate. |

### Chapter IV: Information & Cyber Security Controls

| Section & Para | Regulatory Requirement | NovaPay CI/CD Automated Implementation | Technical Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **Para 20**<br>Integrity of Software | Mechanism to ensure that software deployed to production has not been altered or tampered with. | Container images signed with Cosign using AWS KMS hardware security modules. Kyverno admission controller blocks unsigned pods. | In-toto SLSA Level 3 provenance attestations and Kyverno image verification policies. |
| **Para 22**<br>Vulnerability Management | Automated vulnerability assessment of software and infrastructure components prior to production deployment. | Stage 4 executes Trivy and Snyk scanning all third-party libraries and container OS layers against NVD. | Automated gate blocks pipeline if any unresolved `CRITICAL` or `HIGH` CVE with CVSS >= 7.0 is detected. |
| **Para 23**<br>Secure Coding & SAST | Implementation of secure software development lifecycle (SSDLC) with automated static analysis scanning. | Stage 3 executes SonarQube Enterprise and Semgrep with custom banking rules checking for OWASP Top 10 and CWE Top 25. | Quality Gate blocks merging if Security Rating is below `A` or if security hotspots remain unreviewed. |
| **Para 24**<br>Data Integrity in Database Operations | Database migrations and updates must not compromise data consistency, induce locking, or cause transactional corruption. | Expand-Contract zero-downtime database migration pattern with non-blocking DDL and dual-write triggers. | Liquibase change management with pre-flight lock checks (`lock_timeout = '2s'`) and automated rollback scripts. |
| **Para 25**<br>Customer Data Protection | Customer Personally Identifiable Information (PII) and sensitive financial data must be masked in non-prod environments and logs. | Static code scanning blocks logging of sensitive variables (account numbers, UPI PINs, Aadhaar, PAN). | Custom Semgrep regex rules detect unmasked logging; FluentBit edge log masking active at runtime. |
| **Para 27**<br>Cryptographic Hygiene | Mandatory use of approved cryptographic standards; deprecation of obsolete algorithms (SHA-1, 3DES, MD5). | Automated SAST checks flag and reject legacy algorithms; pipeline enforces AES-GCM-256 and SHA-256/384. | SonarQube Cryptography Ruleset + TLS 1.3 enforcement on all Istio ingress gateways. |
| **Para 31**<br>Third-Party & Supply Chain Risk | Comprehensive inventory of open-source and third-party software components and dependencies. | CycloneDX and SPDX Software Bill of Materials (SBOM) generated automatically for every container image and signed with Cosign. | Syft SBOM generator integrated in Stage 2; pushed to Harbor/ECR alongside container image. |

### Chapter V: Business Continuity & Disaster Recovery

| Section & Para | Regulatory Requirement | NovaPay CI/CD Automated Implementation | Technical Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **Para 33**<br>High Availability Architecture | Banking systems must be engineered with high resilience, eliminating single points of failure (SPOF) to achieve five-nines availability. | Multi-AZ active-active deployment across 3 availability zones with topology spread constraints and Pod Disruption Budgets (PDB). | Kubernetes TopologySpreadConstraints + Istio outlier detection + automated replica autoscaling (HPA). |
| **Para 35**<br>Recovery Time Objective (RTO) & Rollbacks | Systems must support rapid rollback and recovery within strict RTO limits during deployment failures. | Argo Rollouts progressive Canary (5%->20%->50%->100%) and Blue-Green deployments with automated rollback in < 15 seconds. | Prometheus `AnalysisTemplate` monitoring HTTP 5xx errors and latency; instant traffic diversion upon threshold violation. |

---

## 2. RBI Cyber Security Framework for Banks (Annex 1 Mapping)

| Annex 1 Clause | Control Description | NovaPay CI/CD Implementation |
| :--- | :--- | :--- |
| **Para 2**<br>User Access Management | Principle of Least Privilege and Segregation of Duties for production systems. | Developers possess zero production access; CI/CD pipeline runs on short-lived OIDC IAM roles. |
| **Para 3**<br>Operating System Security | Hardened, minimal operating system configurations with non-essential services disabled. | Rootless, distroless container images (`gcr.io/distroless/java17:nonroot`) with read-only root filesystems. |
| **Para 8**<br>Application Security Testing | Dynamic application security testing (DAST) and API security testing prior to live release. | Stage 6 executes OWASP ZAP and StackHawk authenticated dynamic scans against ephemeral preview clusters. |
| **Para 10**<br>Audit Logging & Trail | Comprehensive, tamper-resistant logging of all system access and modification events. | SLSA Level 3 provenance + Git commit hashes + CAB approvals archived in AWS S3 Glacier Object Lock (WORM) for 7 years. |
| **Para 13**<br>Incident Management | Rapid detection, containment, and recovery from security and operational anomalies. | Real-time Prometheus alerting integrated with automated Argo Rollout abortion and Slack/PagerDuty incident broadcast. |
