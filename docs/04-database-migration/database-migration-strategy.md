# Deliverable 4: Zero-Downtime Database Migration Architecture (100M+ Rows)

## 1. Context & Financial Data Scale
NovaPay Digital Bank operates a transaction ledger table (`financial_transactions`) with **over 100 million rows** and high-frequency writes (> 2,500 TPS during peak UPI windows). Executing an unthrottled `ALTER TABLE` or table-locking DDL operation results in immediate connection pool exhaustion, transaction deadlocks, and violation of the 99.999% availability SLA.

This document establishes the zero-downtime database migration architecture utilizing the **Expand-Contract (Parallel Run)** pattern, automated tooling (`pgroll` / Liquibase), and strict lock prevention.

---

## 2. Tooling Selection & Online Schema Migration Framework
- **PostgreSQL Solution**: `pgroll` (native Postgres zero-downtime migration tool using updatable views) and Liquibase declarative versioned changesets.
- **MySQL Alternative**: `gh-ost` (GitHub's triggerless online schema change) or `pt-online-schema-change`.
- **Abort Criteria (Page 7)**: If migration impact increases query latency by **more than 20%** or replica lag exceeds **5.0 seconds**, the migration is automatically aborted and the on-call DBA alerted.

---

## 3. Step-by-Step Expand-Contract Execution Lifecycle

```
Schema State 0: BASELINE (V1)
      │
      ▼ [Step 1: EXPAND - Add additive column with lock_timeout=2s]
Schema State 1: EXPANDED
      │ (App V1 reads/writes old; App V2 writes both, reads old)
      ▼ [Step 2: MIGRATE - Asynchronous batched backfill 100M+ rows]
Schema State 2: BACKFILLED
      │ (Concurrent index created; constraints added NOT VALID -> VALIDATE)
      ▼ [Step 3: CUTOVER - Deploy App V2 reading & writing new schema]
Schema State 3: ACTIVATED
      │ (7-Day Cooling Period: 0 queries touching legacy columns)
      ▼ [Step 4: CONTRACT - Safe non-blocking DROP COLUMN]
Schema State 4: FINAL CLEAN (V2)
```

### Phase 1: Expand (Non-Blocking DDL)
1. Set aggressive timeouts: `SET lock_timeout = '2s'; SET statement_timeout = '30s';`.
2. Add nullable column: `ALTER TABLE financial_transactions ADD COLUMN transaction_ref_v2 VARCHAR(64);`.
3. Create row-level synchronization trigger or use `pgroll` view rewriting so that all new inserts and updates write to both `transaction_ref` and `transaction_ref_v2`.
4. Deploy Application Version $V_N$: App continues reading from old column while ensuring dual-write consistency.

### Phase 2: Migrate (Batched Asynchronous Backfill of 100M+ Rows)
- **Problem**: Updating 100 million rows in a single query locks the table, exhausts WAL buffers, causes catastrophic replication lag, and risks transaction rollback.
- **Batched Backfill Architecture**:
  - Discrete batch size: **1,000 to 5,000 rows per chunk**.
  - Query pattern using primary key range scan:
    ```sql
    UPDATE financial_transactions
    SET transaction_ref_v2 = compute_v2_ref(transaction_ref)
    WHERE id BETWEEN :start_id AND :end_id
      AND transaction_ref_v2 IS NULL;
    ```
  - **Dynamic Throttling**: 50ms to 100ms pause (`pg_sleep(0.05)`) between batches.
  - **Lock Avoidance**: Executes `SELECT ... FOR UPDATE SKIP LOCKED`.
  - **Checkpointing**: Tracks progress in `migration_checkpoints` table so that failures resume without re-scanning.
- **Concurrent Indexing**:
  `CREATE UNIQUE INDEX CONCURRENTLY idx_tx_ref_v2 ON financial_transactions(transaction_ref_v2);`
- **Constraint Enforcement**:
  `ALTER TABLE financial_transactions ADD CONSTRAINT chk_ref_v2_not_null CHECK (transaction_ref_v2 IS NOT NULL) NOT VALID;`
  `ALTER TABLE financial_transactions VALIDATE CONSTRAINT chk_ref_v2_not_null;`

### Phase 3: Contract (Safe Deprecation & Cleanup)
1. Deploy Application Version $V_{N+1}$: Reads and writes exclusively to `transaction_ref_v2`.
2. Drop synchronization trigger: `DROP TRIGGER IF EXISTS trg_sync_tx_ref ON financial_transactions;`.
3. **7-Day Cooling Period**: Query statistics (`pg_stat_statements`) monitored for 7 consecutive days to guarantee 0 queries touch legacy column.
4. Execute non-blocking drop: `ALTER TABLE financial_transactions DROP COLUMN transaction_ref;`.

---

## 4. Migration Governance & DBA Approval Framework

Every schema change must clear a 5-point DBA approval checklist prior to pipeline promotion:
1. **[ ] Lock Timeout Verification**: DDL script starts with `SET lock_timeout = '2s'`.
2. **[ ] Concurrency Verification**: All indexes use `CONCURRENTLY`.
3. **[ ] Constraint Verification**: Foreign keys / Checks use `NOT VALID` + `VALIDATE CONSTRAINT`.
4. **[ ] Reversibility / Rollback Script**: Tested down-migration script verified in pre-prod.
5. **[ ] Backfill Sizing & Throttling Plan**: Backfill script includes batch boundaries and sleep pauses.
