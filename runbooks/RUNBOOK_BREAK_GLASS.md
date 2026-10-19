# NovaPay Digital Bank: Regulated Break-Glass Emergency Access Protocol

## 1. Regulatory Context (RBI Master Direction 2023, Chapter III, Para 18)
Under RBI guidelines, direct emergency access to production environments must:
- Be invoked only for Sev-1 Critical Incidents threatening financial stability or system availability.
- Require dual-authorization (Chief Information Security Officer + Head of Engineering).
- Enforce time-limited access (maximum 120 minutes).
- Retain complete keystroke session logging in immutable storage (WORM compliance).
- Require retroactive CAB reconciliation within 24 hours.

---

## 2. Step-by-Step Break-Glass Invocation Protocol

### Step 1: Incident Declaration & Approval Request
1. Incident Commander declares Sev-1 Incident in Incident Management System (`INC-XXXXX`).
2. Incident Commander initiates emergency request:
   ```bash
   ./scripts/request-break-glass.sh --incident INC-99214 --duration 120m --reason "Core payment switch deadlocked"
   ```
3. Cryptographic approval tokens are generated and dispatched to CISO and Head of Engineering via secure out-of-band channels (Hardware FIDO2 WebAuthn prompt).

### Step 2: Emergency Pipeline Execution
Once both tokens are signed, the emergency pipeline `.github/workflows/break-glass-hotfix.yml` is triggered via `workflow_dispatch`.

```bash
gh workflow run break-glass-hotfix.yml \
   -f incident_id="INC-99214" \
   -f ciso_approval_token="TOKEN_CISO_ECDSA_SIGNATURE" \
   -f head_of_eng_approval="TOKEN_HOE_ECDSA_SIGNATURE" \
   -f justification="Emergency database lock clearance and switch hotfix"
```

### Step 3: Ephemeral Production Access (AWS SSM Session Manager)
If live interactive container inspection is strictly required (zero SSH keys allowed):
- Access is provisioned via AWS SSM Session Manager with temporary STS credentials expiring after 60 minutes.
- Every command and shell output is streamed simultaneously to CloudWatch Logs and an encrypted, immutable S3 bucket (`s3://novapay-immutable-compliance-audit/session-logs/`) with S3 Object Lock in Compliance Mode.
- Direct root login is disabled; all commands execute under an unprivileged auditor role with sudo commands logged via PAM auditd.

### Step 4: Post-Emergency Retroactive Reconciliation (24-Hour SLA)
Within 24 hours of incident resolution:
1. Automated JIRA ticket `CAB-RETRO-INC-99214` is populated with all git diffs, pipeline execution logs, and session recordings.
2. Formal RCA and post-mortem signed off by CISO, Head of Engineering, and Head of Internal Audit.
3. Remediation report filed with the RBI Department of Supervision if required by statutory circulars.
