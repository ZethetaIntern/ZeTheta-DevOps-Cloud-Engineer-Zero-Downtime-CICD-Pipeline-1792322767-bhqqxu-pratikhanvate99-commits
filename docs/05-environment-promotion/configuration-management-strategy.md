# Deliverable 5B: Configuration Management & Secrets Governance Strategy

## 1. Core Architectural Tenet: "Same Artefact, Different Config"
In compliance with cloud-native 12-factor principles and financial auditing standards:
- **No Environment-Specific Branches**: Branches like `staging` or `prod` are prohibited. The `main` branch produces the identical, immutable container binary for all environments.
- **Binary Immutability**: The container image built in Stage 2 and signed in Stage 4 is promoted unchanged from Dev $\rightarrow$ Staging $\rightarrow$ Pre-Prod $\rightarrow$ Production. Environment differences are externalized strictly into configuration.

---

## 2. Configuration Hierarchy (Helm Values Cascade)
NovaPay structures configurations using a three-tier inheritance model:
```
[ Tier 1: Base Configuration (values.yaml) ]
  - Shared defaults, JVM heap heuristics, common logging format, telemetry exporters
                    │
                    ▼
[ Tier 2: Environment Overrides (values-{env}.yaml) ]
  - values-staging.yaml: 2 replicas, standard ingress host, relaxed resource requests
  - values-preprod.yaml: 4 replicas, masked service endpoints
  - values-production.yaml: 10 replicas, multi-AZ spread constraints, strict PDBs
                    │
                    ▼
[ Tier 3: Service-Specific Customisations ]
  - Microservice-specific environment variables and circuit breaker parameters
```

---

## 3. Secrets Management & Automated Rotation
- **Zero Plaintext Secrets**: Plaintext secrets, private keys, or passwords in Git, Helm values, or Kubernetes manifests are blocked by Gitleaks and OPA.
- **Provider Tier**: HashiCorp Vault / AWS Secrets Manager backed by AWS KMS HSM.
- **Kubernetes Synchronization**: External Secrets Operator (ESO) fetches encrypted secrets directly into ephemeral Kubernetes Secret objects in cluster memory.
- **Rotation Schedules**:
  - Database Passwords: Automated rotation every **90 days**.
  - API Keys & Payment Gateway Tokens: Automated rotation every **30 days**.
  - Emergency Rotation: Immediate one-click rotation via Vault API during incident containment.

---

## 4. Feature Flag Governance & Progressive Exposure
- **Toggle Architecture**: Integration with Unleash / LaunchDarkly enterprise feature toggle engines.
- **Decoupling Deployment from Release**: Code deploys to production with new features dormant (`enabled: false`).
- **Progressive Exposure**:
  - Step 1: Internal NovaPay staff (Whitelisted account numbers) $\rightarrow$ 1% traffic.
  - Step 2: 10% of retail consumers.
  - Step 3: 50% of retail consumers.
  - Step 4: 100% General Availability.
- **Kill-Switch**: Any feature flag can be toggled to `false` in **< 1 second** via API without a container redeployment.

---

## 5. Configuration Drift Detection & Self-Healing
- **ArgoCD Reconciliation**: ArgoCD's controller evaluates live cluster state against Git-declared manifests every **3 minutes (180 seconds)**.
- **Out-of-Sync Alerts**: Any manual tampering (e.g. `kubectl edit`, unauthorized replica adjustments) immediately alerts the SRE Slack channel (`#bank-infra-drift`).
- **Self-Healing Enforcement**: ArgoCD operates with `selfHeal: true` and `prune: true`, automatically overwriting unauthorized production mutations within 60 seconds to re-establish the Git source of truth.
