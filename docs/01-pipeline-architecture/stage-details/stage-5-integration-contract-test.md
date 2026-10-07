# Stage 5 Specification: Integration & Consumer-Driven Contract Testing

## 1. Tooling & Versions
- **Contract Testing Framework**: Pact JVM / Pact Foundation CLI v4.6+
- **Contract Broker**: PactFlow / Hosted Pact Broker v2.100+
- **Integration Framework**: Testcontainers Java v1.19+
- **Mock Services**: WireMock v3.4+ / MockServer (simulating NPCI UPI Switch, IMPS Node, RBI CBS)

## 2. Configuration Parameters
- **Pact Broker Verification**:
  - `pact.verifier.publishResults: true`
  - `provider.version: ${GIT_COMMIT_SHA}`
  - `consumerVersionSelectors: latest=true, deployed=true, environment=production`
- **Testcontainers Setup**:
  - `image: postgres:16-alpine` (configured with pgBouncer pooling)
  - `image: redis:7-alpine` (cluster mode)
  - `image: rabbitmq:3.13-management-alpine`

## 3. Threshold Values & Gates
- **Contract Compatibility**: 100% of Pact interactions verified with zero breaking schema changes (`can-i-deploy --pacticipant novapay-payment-service --version ${GIT_SHA} --to-environment production` must return SUCCESS).
- **Integration Test Pass Rate**: 100% (0 failures, 0 timeouts).
- **Latency Baseline**: Ephemeral integration endpoints must respond with P99 < 250ms under synthetic concurrency.

## 4. Failure Modes & Remediation
- **Breaking API Contract**: Pipeline fails at `can-i-deploy` check. Output displays missing fields or incompatible type transformations between consumer and provider. Developer must either make change backward-compatible or coordinate phased consumer upgrade.
- **Database Integration Failure**: Ephemeral Postgres container throws transaction rollback error. Developer analyzes SQL error in test log.

## 5. Retry & Skip Logic
- **Retries**: 1 automatic retry on ephemeral container startup timeout.
- **Skip Conditions**: None.

## 6. SLA Target
- **Execution Duration**: <= 720 seconds (12 minutes).
