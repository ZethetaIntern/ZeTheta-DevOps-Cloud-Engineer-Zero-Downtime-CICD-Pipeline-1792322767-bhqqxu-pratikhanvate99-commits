# Stage 4 Specification: Dependency, Container & Secret Scanning

## 1. Tooling & Versions
- **Secret Scanner**: Gitleaks v8.18+ / Trufflehog v3.63+
- **SCA & Container Scanner**: Aqua Trivy v0.50+ / Anchore Grype v0.74+
- **License Scanner**: ScanCode Toolkit v32.0+ / FOSSA CLI v3.8+
- **Cryptographic Signing**: Sigstore Cosign v2.2+ backed by AWS KMS HSM (FIPS 140-3 Level 3)
- **Provenance Attestation**: in-toto SLSA Provenance Generator v1.9+

## 2. Configuration Parameters
- **Trivy Configuration**:
  - `scan-type: fs, image`
  - `severity: CRITICAL,HIGH`
  - `ignore-unfixed: false`
  - `exit-code: 1`
- **Cosign Key ARN**: `arn:aws:kms:ap-south-1:123456789012:key/novapay-image-signing-key`
- **License Policy**:
  - Whitelist: Apache-2.0, MIT, BSD-2-Clause, BSD-3-Clause, ISC
  - Blacklist: GPL-2.0, GPL-3.0, AGPL-3.0, SSPL, Commons Clause

## 3. Threshold Values & Gates
- **Secrets**: 0 hardcoded credentials, API keys, private keys, or passwords.
- **SCA / Container CVEs**:
  - `CRITICAL` (CVSS >= 9.0): 0 tolerated (Instant Hard Block).
  - `HIGH` (CVSS 7.0 - 8.9): Blocked if CVSS > 8.0 or if weaponized exploit exists. 72-hour remediation window for non-weaponized CVEs with CISO waiver.
- **Licenses**: 0 copyleft/viral license violations.
- **Image Signature**: Cryptographic signature present and verifiable against AWS KMS public key.
- **SLSA Provenance**: Level 3 attestation cryptographically attached.

## 4. Failure Modes & Remediation
- **Secret Detected**: Build immediately aborts, token revoking webhook fires to Vault/AWS IAM. Developer must purge commit using git-filter-repo, rotate secret, and push clean commit.
- **Critical CVE**: Build aborts. Trivy outputs package name and fixed version. Developer updates `pom.xml` / `build.gradle` dependency version.
- **Unsigned Image in Admission**: Kyverno rejects Pod admission in Kubernetes cluster.

## 5. Retry & Skip Logic
- **Retries**: 1 retry for CVE vulnerability database sync timeout.
- **Skip Conditions**: None.

## 6. SLA Target
- **Execution Duration**: <= 480 seconds (8 minutes). Runs in parallel with Stage 3.
