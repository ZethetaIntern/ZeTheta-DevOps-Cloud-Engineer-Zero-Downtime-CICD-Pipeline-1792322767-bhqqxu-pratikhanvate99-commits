# Stage 7 Specification: Policy & Compliance Gates (Policy-as-Code)

## 1. Tooling & Versions
- **Policy Engine**: Open Policy Agent (OPA) v0.63+ / Conftest v0.50+
- **Kubernetes Admission**: Kyverno v1.12+ / Gatekeeper v3.15+
- **Infrastructure Linter**: Checkov v3.2+ / tfsec v1.28+

## 2. Configuration Parameters
- **Policy Evaluation Paths**:
  - `compliance/policies/rbi_controls.rego`
  - `compliance/policies/pci_dss_gates.rego`
  - `compliance/policies/sod_enforcement.rego`
  - `compliance/policies/no_privileged_containers.rego`
- **Audit Attestation**: Signed JSON output exported with HMAC-SHA256 digest to immutable compliance S3 bucket.

## 3. Threshold Values & Gates
- **RBI Governance Gate**: Mandatory validated Change Advisory Board ticket in status `APPROVED` with >= 2 CAB approvers.
- **Segregation of Duties (SoD)**: Committer $\neq$ Approver; release initiated exclusively by GitOps service account (`argocd-service-account`).
- **Container Hardening**:
  - `runAsNonRoot: true`
  - `runAsUser > 0` (UID 10001)
  - `readOnlyRootFilesystem: true`
  - `allowPrivilegeEscalation: false`
  - `capabilities.drop: ["ALL"]`
- **Supply Chain Trust**: Cosign KMS signature verified; SLSA Level 3 provenance confirmed.

## 4. Failure Modes & Remediation
- **CAB Ticket Missing or Unapproved**: Conftest prints `RBI NC-01 Violation`. Engineer must obtain formal CAB sign-off in JIRA ITSM before pipeline re-evaluation.
- **Root Container Spec**: Conftest prints `PCI-DSS 6.4.1 Violation`. Engineer updates deployment security context.

## 5. Retry & Skip Logic
- **Retries**: 0 retries.
- **Skip Conditions**: Strict dual-approval bypass available only via `break-glass-hotfix.yml` with CISO hardware token.

## 6. SLA Target
- **Execution Duration**: <= 180 seconds (3 minutes).
