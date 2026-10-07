# Stage 1 Specification: Source Control Management & Trigger Governance

## 1. Tooling & Versions
- **Tool**: GitHub Enterprise Server v3.12+ / GitHub Actions Runner v2.316+
- **Commit Signing**: GnuPG v2.4+ / OpenSSH v9.6+
- **Linter**: Commitlint v19.2+ with `@commitlint/config-conventional`

## 2. Configuration Parameters
- **Branching Model**: Trunk-Based Development (`main` branch protected).
- **Branch Protection Settings**:
  - `require_signed_commits: true`
  - `required_approving_review_count: 2` (1 Tech Lead + 1 Security Champion)
  - `dismiss_stale_reviews: true`
  - `require_code_owner_reviews: true`
  - `strict: true` (branch must be up-to-date with `main` before merging)
  - `allow_force_pushes: false`
  - `allow_deletions: false`
- **Monorepo Triggering**: Path-based filtering (`paths: ['services/payment-service/**', 'libs/common/**']`).

## 3. Threshold Values & Gates
- **GPG/SSH Signature**: 100% of commits must evaluate to status `G` (Good) or `U` (Untrusted Key with verified fingerprint).
- **Commit Message Format**: Regex: `^(feat|fix|perf|refactor|chore)\([a-zA-Z0-9_-]+\): (\[CAB-[0-9]+\] )?.+$`.
- **Author vs Approver**: Approver ID $\neq$ Author ID (SoD gate).

## 4. Failure Modes & Remediation
- **Unsigned Commit**: Git push rejected at pre-receive hook. Developer must sign commit using `git commit --amend -S` and re-push.
- **Unconventional Commit**: Commitlint blocks PR status check. Developer must reword commit message following conventional spec with JIRA CAB reference.
- **Self-Approval Attempt**: OPA Gate blocks merge. PR requires distinct peer and security champion approvals.

## 5. Retry & Skip Logic
- **Retries**: 0 retries (deterministic cryptographic check).
- **Skip Conditions**: Strict `skip` forbidden for any PR targeting `main`.

## 6. SLA Target
- **Execution Duration**: <= 120 seconds (2 minutes).
