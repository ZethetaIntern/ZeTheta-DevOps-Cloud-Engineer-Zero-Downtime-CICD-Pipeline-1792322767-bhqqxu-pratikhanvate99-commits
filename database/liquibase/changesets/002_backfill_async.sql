-- liquibase formatted sql
-- changeset novapay-dba:002-migrate-backfill-account-v2 stripComments:false failOnError:true endDelimiter:/
-- comment: Phase 2 (Migrate) - Asynchronous batched backfill without locking tables

DO $$
DECLARE
    v_batch_size INT := 1000;
    v_updated_rows INT;
    v_total_updated INT := 0;
BEGIN
    LOOP
        -- Update records in non-locking discrete batches using primary key
        WITH batch AS (
            SELECT id
            FROM accounts
            WHERE account_num_v2 IS NULL
              AND account_num IS NOT NULL
            LIMIT v_batch_size
            FOR UPDATE SKIP LOCKED
        )
        UPDATE accounts a
        SET account_num_v2 = 'IN00' || LPAD(a.account_num::text, 14, '0')
        FROM batch
        WHERE a.id = batch.id;

        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
        v_total_updated := v_total_updated + v_updated_rows;

        -- Exit loop when all pending rows are populated
        EXIT WHEN v_updated_rows = 0;

        -- Sleep 50ms to yield lock and prevent IO/CPU saturation
        PERFORM pg_sleep(0.05);
    END LOOP;

    RAISE NOTICE 'Completed backfill. Total accounts updated: %', v_total_updated;
END $$;
/

-- changeset novapay-dba:002-migrate-index-and-constraint stripComments:false failOnError:true
-- comment: Phase 2 (Migrate) - Concurrent index creation and non-blocking constraint validation

-- Note: In PostgreSQL, CONCURRENTLY cannot run inside a transaction block
-- Liquibase changeset attribute runInTransaction: false should be set for production runners

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_accounts_account_num_v2 
    ON accounts(account_num_v2);

-- Add constraint as NOT VALID first (instant metadata lock)
ALTER TABLE accounts 
    ADD CONSTRAINT chk_account_v2_not_null 
    CHECK (account_num_v2 IS NOT NULL) NOT VALID;

-- Validate constraint without blocking concurrent inserts/updates
ALTER TABLE accounts 
    VALIDATE CONSTRAINT chk_account_v2_not_null;

-- rollback ALTER TABLE accounts DROP CONSTRAINT IF EXISTS chk_account_v2_not_null;
-- rollback DROP INDEX CONCURRENTLY IF EXISTS idx_accounts_account_num_v2;
