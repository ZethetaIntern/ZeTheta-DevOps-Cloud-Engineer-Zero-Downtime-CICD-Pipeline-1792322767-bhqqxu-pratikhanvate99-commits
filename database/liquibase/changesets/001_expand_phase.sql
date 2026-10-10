-- liquibase formatted sql
-- changeset novapay-dba:001-expand-account-v2-column stripComments:false failOnError:true
-- comment: Phase 1 (Expand) - Add account_num_v2 column and dual-write synchronization trigger

SET lock_timeout = '2s';
SET statement_timeout = '30s';

-- 1. Additive column creation (nullable, non-blocking)
ALTER TABLE accounts 
    ADD COLUMN IF NOT EXISTS account_num_v2 VARCHAR(34);

-- 2. Create trigger function to mirror writes from legacy account_num to account_num_v2
CREATE OR REPLACE FUNCTION fn_sync_account_num_v2()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.account_num IS NOT NULL AND NEW.account_num_v2 IS NULL THEN
        NEW.account_num_v2 := 'IN00' || LPAD(NEW.account_num::text, 14, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach trigger to table accounts
DROP TRIGGER IF EXISTS trg_sync_account_v2 ON accounts;
CREATE TRIGGER trg_sync_account_v2
    BEFORE INSERT OR UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_account_num_v2();

-- rollback ALTER TABLE accounts DROP COLUMN IF EXISTS account_num_v2;
-- rollback DROP TRIGGER IF EXISTS trg_sync_account_v2 ON accounts;
-- rollback DROP FUNCTION IF EXISTS fn_sync_account_num_v2();
