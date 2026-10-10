# Deliverable 4B: Database Version Compatibility Matrix

This matrix specifies the operational compatibility between application releases ($V_{N-1}$ and $V_N$) and the four database schema states during an Expand-Contract migration.

---

## Compatibility Matrix: Application Versions vs. Schema States

| Migration Phase | Schema State Description | Database Invariants & Triggers | Application Version $V_{N-1}$ (Legacy) | Application Version $V_N$ (Target Release) | Compatibility Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **State 0**<br>(Baseline) | Initial table schema with legacy `transaction_ref` column only. | Single column, standard indexes. | **Fully Functional**<br>(Reads & writes to legacy column) | **Not Deployed** | **COMPATIBLE** |
| **State 1**<br>(Expand) | Additive `transaction_ref_v2` column added (nullable). Dual-write trigger active. | DB trigger mirrors legacy writes to `v2`. No table locks. | **Fully Functional**<br>(Ignores `v2` column; writes mirrored via trigger) | **Fully Functional**<br>(Reads legacy; dual-writes to both) | **COMPATIBLE**<br>(Zero downtime; fully reversible by dropping column) |
| **State 2**<br>(Migrate) | Asynchronous backfill running in background batches. Concurrent index created. | Batched `UPDATE SKIP LOCKED` with 50ms pause. | **Fully Functional**<br>(Zero lock escalation; unaffected by backfill) | **Fully Functional**<br>(Operates normally) | **COMPATIBLE**<br>(Idempotent backfill; retriable on interruption) |
| **State 3**<br>(Cutover / Activate) | Backfill 100% complete. `NOT NULL` constraint validated. | Dual-write trigger active or handled in app. | **Fully Functional**<br>(Can still operate in rollback scenario) | **Fully Functional**<br>(Reads and writes exclusively to `v2`) | **COMPATIBLE**<br>(Both versions functional concurrently) |
| **State 4**<br>(Contract) | 7-day cooling period passed. Trigger dropped. Legacy column dropped. | Clean schema with only `transaction_ref_v2`. | **Incompatible**<br>(Must be fully decommissioned prior to this phase) | **Fully Functional**<br>(Reads & writes to `v2`) | **FORWARD ONLY**<br>(Irreversible without new expand cycle) |

---

## Phase Rollback Protocol
- **State 1 (Expand) Failure**: Execute rollback script: `ALTER TABLE financial_transactions DROP COLUMN transaction_ref_v2; DROP TRIGGER trg_sync_tx_ref;`. Application $V_{N-1}$ is unaffected.
- **State 2 (Migrate) Failure**: Stop asynchronous backfill script. Application processing is completely unimpeded. Fix data mapping logic and restart backfill from latest checkpoint.
- **State 3 (Cutover) Failure**: If Application $V_N$ encounters unexpected errors, rollback to Application $V_{N-1}$. Since dual-write was maintained, $V_{N-1}$ reads and writes remain 100% consistent.
