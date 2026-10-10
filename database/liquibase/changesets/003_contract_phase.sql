-- liquibase formatted sql
-- changeset novapay-dba:003-contract-remove-legacy-column stripComments:false failOnError:true
-- comment: Phase 3 (Contract) - Drop dual-write trigger and deprecate legacy column

SET lock_timeout = '2s';
SET statement_timeout = '30s';

-- 1. Remove the synchronization trigger as all applications now read/write account_num_v2 directly
DROP TRIGGER IF EXISTS trg_sync_account_v2 ON accounts;
DROP FUNCTION IF EXISTS fn_sync_account_num_v2();

-- 2. Drop the legacy column
-- Pre-requisite: Staging monitoring confirmed 0 queries touching account_num for >= 7 days
ALTER TABLE accounts 
    DROP COLUMN IF EXISTS account_num;

-- rollback ALTER TABLE accounts ADD COLUMN account_num BIGINT;
