# Stage 2 Specification: Hermetic Build & Unit Testing (With SBOM)

## 1. Tooling & Versions
- **Compiler / Runtime**: OpenJDK 21 LTS (Eclipse Temurin)
- **Build Tool**: Gradle 8.7 / Apache Maven 3.9.6
- **Test Coverage Engine**: JaCoCo v0.8.11
- **SBOM Generator**: Anchore Syft v1.2+ / CycloneDX Maven Plugin v2.8+
- **Container Engine**: Docker Buildx v0.13+ (rootless distroless base: `gcr.io/distroless/java21-debian12:nonroot`)

## 2. Configuration Parameters
- **Hermetic Build Flags**: `--no-daemon`, `--offline` (after dependency hydration), `--locked-dependencies`.
- **Docker Layer Caching**: GitHub Actions Cache (`type=gha,mode=max`) and ECR cache.
- **JaCoCo Target Rule**:
  - `element: BUNDLE`
  - `limit counter: LINE, value: COVEREDRATIO, minimum: 0.85` (85%)
  - `limit counter: BRANCH, value: COVEREDRATIO, minimum: 0.80` (80%)
- **SBOM Format**: CycloneDX 1.5 JSON & SPDX 2.3 JSON.

## 3. Threshold Values & Gates
- **Build Outcome**: 100% compilation success (0 errors, warnings treated as errors via `-Werror`).
- **Unit Test Pass Rate**: 100% (0 failures, 0 errors, 0 flaky tests tolerated).
- **Code Coverage**: Line coverage >= 85%, Branch coverage >= 80%.
- **SBOM Validation**: Valid CycloneDX JSON schema with cryptographic dependency hashes.

## 4. Failure Modes & Remediation
- **Coverage Deficit (< 85%)**: Build fails immediately. Pipeline generates JaCoCo HTML report highlighting untested branches. Developer must write unit tests before re-running.
- **Compilation Failure**: Immediate abort. Build log output displays specific file and line syntax error.
- **Dependency Drift / Lockfile Mismatch**: Build fails. Developer must run `gradle --write-locks` locally with valid credentials and commit lockfile update.

## 5. Retry & Skip Logic
- **Retries**: 1 automatic retry allowed only for network timeouts during initial dependency hydration; 0 retries for compilation or test failures.
- **Skip Conditions**: Never skipped.

## 6. SLA Target
- **Execution Duration**: <= 360 seconds (6 minutes).
- **Developer Feedback**: Feedback delivered in <= 8 minutes from push.
