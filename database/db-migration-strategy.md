# NovaPay Digital Bank: Zero-Downtime Database Migration Strategy (Expand-Contract Pattern)

In an RBI-regulated banking institution operating high-volume payment switches (UPI, IMPS, RTGS) and continuous transaction settlement, any table lock exceeding a few hundred milliseconds results in connection pool exhaustion, request queuing, cascaded timeouts, and violation of the 99.999% availability SLA.

This document outlines the strict technical guidelines and 3-phase **Expand-Contract (Parallel Run)** database migration framework designed for NovaPay's PostgreSQL / Aurora databases.

---

## 1. Zero-Lock DDL Principles for PostgreSQL / Aurora

Every database migration executed via the CI/CD pipeline must adhere to the following non-negotiable DDL constraints:

1. **Mandatory Lock and Statement Timeouts**:
   All migration scripts must begin by setting aggressive session timeouts:
   ```sql
   SET lock_timeout = '2s';
   SET statement_timeout = '30s';
   ```
   If a migration cannot acquire an `AccessExclusiveLock` within 2 seconds (e.g., due to a long-running transaction), it aborts cleanly rather than queuing behind transactions and causing a connection blackout.

2. **No Exclusive Table Locks for Indexes**:
   - Standard `CREATE INDEX` acquires `ShareLock`, blocking writes.
   - **Enforced Rule**: All indexes must be created using `CREATE INDEX CONCURRENTLY`.
   - Cannot run inside an explicit transaction block (`autocommit=true` / `disableTransactionHandling`).

3. **No Non-Nullable Column Additions Without Defaults in PostgreSQL < 11**:
   - In modern PostgreSQL (11+), adding a column with a constant `DEFAULT` is a metadata-only change (`O(1)`).
   - Adding a column with a volatile default function (e.g. `DEFAULT random()`) requires a full table rewrite and is strictly forbidden.
   - Columns must be added `NULL` first, backfilled asynchronously, and then constrained using `NOT VALID` + `VALIDATE CONSTRAINT`.

4. **Two-Step Non-Blocking Constraints**:
   - Foreign keys and Check constraints must be applied in two phases:
     ```sql
     -- Step A: Fast metadata lock, only validates new rows
     ALTER TABLE accounts ADD CONSTRAINT check_balance_positive CHECK (balance >= 0) NOT VALID;
     
     -- Step B: Validates existing data concurrently without blocking concurrent DML
     ALTER TABLE accounts VALIDATE CONSTRAINT check_balance_positive;
     ```

---

## 2. The 3-Phase Expand-Contract Migration Lifecycle

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 1: EXPAND PHASE                           │
│  - Apply additive, non-blocking DDL (new columns, shadow tables)       │
│  - Deploy dual-write triggers or dual-write application logic          │
│  - Application Version N+1 reads from OLD column, writes to BOTH       │
│  - Zero impact on Version N (Full backward compatibility)              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 2: MIGRATE PHASE                          │
│  - Asynchronous background backfill of legacy data in batched chunks   │
│  - Lock-free execution: UPDATE in batches of 1000 with 50ms pause      │
│  - Create indexes concurrently on the new column                       │
│  - Validate data invariants (Row count parity, checksum parity)        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 3: CONTRACT PHASE                         │
│  - Deploy Application Version N+2                                      │
│  - Application reads from NEW column, writes only to NEW column        │
│  - Drop dual-write trigger and deprecate old column                    │
│  - Observe 7-day cooling period with 0 queries against legacy column   │
│  - Execute non-blocking DROP COLUMN                                    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Concrete Example: Account Number Migration to IBAN / VPA Format

In this scenario, NovaPay's core banking table `accounts` must transition from a legacy 12-digit numeric account number (`account_num`) to an expanded 34-character alphanumeric IBAN/Virtual Account number (`account_num_v2`) across 25 million records without a single millisecond of downtime.

### Phase 1: Expand Changeset (`001_expand_phase.sql`)
- Add nullable column `account_num_v2 VARCHAR(34)`.
- Create a row-level `BEFORE INSERT OR UPDATE` trigger that automatically computes and populates `account_num_v2` for any new writes or updates occurring on legacy application version.
- Deploy Application N+1 (supports writing both formats).

### Phase 2: Migrate Changeset (`002_backfill_async.sql`)
- Execute a PL/pgSQL stored procedure that updates existing records where `account_num_v2 IS NULL`.
- Backfills in batches of 1,000 rows with a `pg_sleep(0.05)` throttle to maintain CPU and replication lag below thresholds.
- Create index: `CREATE UNIQUE INDEX CONCURRENTLY idx_accounts_num_v2 ON accounts(account_num_v2);`.
- Enforce `NOT NULL` constraint via `NOT VALID` followed by `VALIDATE CONSTRAINT`.

### Phase 3: Contract Changeset (`003_contract_phase.sql`)
- Deploy Application N+2 (all reads and writes use `account_num_v2`).
- Drop database trigger `trg_sync_account_v2`.
- Drop legacy column: `ALTER TABLE accounts DROP COLUMN account_num;`.
