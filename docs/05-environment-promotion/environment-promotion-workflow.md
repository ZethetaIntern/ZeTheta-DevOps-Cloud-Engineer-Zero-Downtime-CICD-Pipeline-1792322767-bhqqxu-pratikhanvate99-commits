# Deliverable 5A: 4-Environment Promotion Workflow & Governance

## 1. The 4-Environment Model in Regulated Banking

In compliance with RBI Master Direction (2023) Chapter III, Para 15 and PCI-DSS v4.0 Requirement 6.4, NovaPay strictly isolates systems across four environments. The principle of **"Same Artefact, Different Config"** governs the promotion lifecycle: the identical, immutable, signed container image is promoted through all stages—only externalized configurations vary.

| Environment | Purpose | Data Profile | Access Control | Deployment Trigger |
| :--- | :--- | :--- | :--- | :--- |
| **Development** | Feature development, unit testing, component integration | **Synthetic / Mock data only** (Zero real customer data) | All Developers | **Automatic on PR merge** to feature branch |
| **Staging** | Integration testing, DAST, contract testing, performance baseline | **Anonymised production-like data** | Dev Team + QA | **Automatic** after development gates pass |
| **Pre-Production** | User Acceptance Testing (UAT), regulatory compliance verification | **Masked production data subset** | QA + Compliance + DBA | **Manual approval** after staging verification |
| **Production** | Live customer-facing core banking & payment processing | **Real production data** | **SRE + Release Manager only** (Zero developer access) | **Dual approval** (Release Manager + SRE Lead) |

---

## 2. Explicit Promotion Criteria Across Stages

### 2.1 Transition: Development $\rightarrow$ Staging (Automated)
- [x] All unit tests pass (100% pass rate, 0 test failures tolerated).
- [x] Code coverage $\ge$ 80% line coverage, $\ge$ 70% branch coverage (JaCoCo).
- [x] SAST scan: 0 Critical vulnerabilities, $\le$ 2 High findings (SonarQube).
- [x] Build artefact signed with Cosign and pushed to container registry with SemVer tag + Git SHA.
- [x] **Automated promotion**: No human approval required if all automated quality gates pass.

### 2.2 Transition: Staging $\rightarrow$ Pre-Production (Technical Gating)
- [x] All integration tests pass, including Pact consumer-driven contract tests.
- [x] DAST scan complete with 0 Critical and 0 High findings from OWASP API Top 10.
- [x] Performance baseline test: P99 latency < 500ms under 2x expected production peak load.
- [x] Dependency scan: 0 Critical CVEs, CycloneDX SBOM generated and cryptographically archived.
- [x] License compliance check passed: zero GPL/AGPL/SSPL copyleft dependencies detected.
- [x] **Tech Lead Approval**: Required via GitHub Environment Protection Gate.

### 2.3 Transition: Pre-Production $\rightarrow$ Production (Dual Governance Gating)
- [x] **UAT Sign-off**: Formal written approval from Product Owner.
- [x] **Regulatory Compliance Verification**: OPA policies pass validating 100% mapping to RBI Master Direction and PCI-DSS v4.0.
- [x] **Database Migration Validation**: Liquibase Expand changeset executed and validated in pre-prod against 100M+ masked records with zero lockouts.
- [x] **Deployment Runbook Verification**: Runbook reviewed, updated, and signed off by SRE Lead.
- [x] **Change Advisory Board (CAB) Approval**: Validated JIRA ticket `CAB-[0-9]+` in status `APPROVED`.
- [x] **Dual Approval (Segregation of Duties)**: Independent digital sign-off from both Release Manager AND SRE Lead.
- [x] **Deployment Window Verification**: Validated not in blackout calendar (not on salary day 1st/7th, not during peak UPI window 10 AM-12 PM or 5 PM-8 PM IST).
- [x] **On-Call Availability Confirmed**: Primary and secondary SREs briefed and confirmed present on release bridge.
