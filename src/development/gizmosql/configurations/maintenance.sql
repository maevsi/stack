-- DuckLake takes ownership of registered files, so later checkpoints rewrite and delete them in place.
SET VARIABLE landing_files = (
  SELECT coalesce(list(file ORDER BY file), [])
  FROM glob('r2://test/landing/*.parquet')
  WHERE file NOT IN (SELECT path FROM lakehouse.ingested_file)
);
-- One transaction, so a crash never leaves a file registered but missing from the ledger.
BEGIN;
CALL ducklake_add_data_files('lakehouse', 'envelope', getvariable('landing_files'));
INSERT INTO lakehouse.ingested_file SELECT unnest(getvariable('landing_files'));
COMMIT;

-- Erasure runs every time because an account's event envelopes can land after its `account.deleted`.
-- `->>` binds weaker than `IN`, so the parentheses are required.
DELETE FROM lakehouse.envelope
WHERE aggregate_type = 'event'
  AND (data->>'created_by') IN (
    SELECT data->>'account_id' FROM lakehouse.envelope WHERE type = 'account.deleted'
  );

-- Only checkpoints delete landing files, and a deleted file never comes back.
DELETE FROM lakehouse.ingested_file
WHERE path NOT IN (SELECT file FROM glob('r2://test/landing/*.parquet'));
