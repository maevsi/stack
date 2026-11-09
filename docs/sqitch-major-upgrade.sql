-- Copies the data of a schema generation renamed to `<schema>_old` into the schemas a fresh `sqitch deploy` of the next major created.
-- Only columns that exist in both generations are copied, so columns dropped by the major are left behind instead of failing the whole restore.
-- Constraints (check, not null, unique) stay enforced; triggers and foreign key checks are skipped, so tables can be filled in any order.
-- Run as the database superuser with `psql -v ON_ERROR_STOP=1`; everything happens in one transaction and is undone on any error.

BEGIN;

SET LOCAL session_replication_role = replica;

DO $$
DECLARE
  _table RECORD;
  _columns TEXT;
  _values TEXT;
  _overriding TEXT;
  _count BIGINT;
  _left_behind TEXT;
BEGIN
  FOR _table IN
    SELECT n.nspname AS schema_name, c.relname AS table_name, c.oid AS table_new, to_regclass(format('%I.%I', n.nspname || '_old', c.relname)) AS table_old
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('vibetype', 'vibetype_private') AND c.relkind IN ('r', 'p')
    ORDER BY 1, 2
  LOOP
    IF _table.table_old IS NULL THEN
      RAISE NOTICE '%.%: new table, nothing to copy', _table.schema_name, _table.table_name;
      CONTINUE;
    END IF;

    SELECT
      string_agg(format('%I', a_new.attname), ', ' ORDER BY a_new.attnum),
      -- a differing type is mostly an enum or composite of the old schema generation, which converts through its text form
      string_agg(
        CASE WHEN a_new.atttypid = a_old.atttypid THEN format('%I', a_new.attname)
        ELSE format('%I::TEXT::%s', a_new.attname, format_type(a_new.atttypid, a_new.atttypmod)) END,
        ', ' ORDER BY a_new.attnum
      ),
      CASE WHEN bool_or(a_new.attidentity = 'a') THEN 'OVERRIDING SYSTEM VALUE' ELSE '' END
    INTO _columns, _values, _overriding
    FROM pg_attribute a_new
    JOIN pg_attribute a_old ON a_old.attrelid = _table.table_old AND a_old.attname = a_new.attname AND a_old.attnum > 0 AND NOT a_old.attisdropped
    WHERE a_new.attrelid = _table.table_new AND a_new.attnum > 0 AND NOT a_new.attisdropped AND a_new.attgenerated = '';

    EXECUTE format('INSERT INTO %s (%s) %s SELECT %s FROM %s', _table.table_new::regclass, _columns, _overriding, _values, _table.table_old);
    GET DIAGNOSTICS _count = ROW_COUNT;

    SELECT string_agg(a_old.attname, ', ' ORDER BY a_old.attnum) INTO _left_behind
    FROM pg_attribute a_old
    WHERE a_old.attrelid = _table.table_old AND a_old.attnum > 0 AND NOT a_old.attisdropped
      AND NOT EXISTS (SELECT 1 FROM pg_attribute a_new WHERE a_new.attrelid = _table.table_new AND a_new.attname = a_old.attname AND NOT a_new.attisdropped);

    RAISE NOTICE '%.%: % rows%', _table.schema_name, _table.table_name, _count, CASE WHEN _left_behind IS NULL THEN '' ELSE ', left behind: ' || _left_behind END;
  END LOOP;

  FOR _table IN
    SELECT n.nspname AS schema_name, c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('vibetype_old', 'vibetype_private_old') AND c.relkind IN ('r', 'p')
      AND to_regclass(format('%I.%I', left(n.nspname, -4), c.relname)) IS NULL
  LOOP
    RAISE NOTICE '%.%: removed by the major, left behind', _table.schema_name, _table.table_name;
  END LOOP;

  -- the copy wrote explicit ids, so sequences have to continue after them
  FOR _table IN
    SELECT s.oid AS sequence_name, a.attrelid::regclass AS table_name, a.attname AS column_name
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype IN ('a', 'i')
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
    JOIN pg_namespace n ON n.oid = s.relnamespace
    WHERE s.relkind = 'S' AND n.nspname IN ('vibetype', 'vibetype_private')
  LOOP
    EXECUTE format('SELECT setval(%L, COALESCE((SELECT max(%I) FROM %s), 0) + 1, false)', _table.sequence_name::regclass, _table.column_name, _table.table_name);
  END LOOP;
END
$$;

-- Foreign keys were not checked while copying, so rows referencing nothing would otherwise go unnoticed.
DO $$
DECLARE
  _constraint RECORD;
  _orphans BIGINT;
BEGIN
  FOR _constraint IN
    SELECT
      c.conname,
      c.conrelid::regclass AS table_child,
      c.confrelid::regclass AS table_parent,
      (SELECT string_agg(format('child.%I IS NOT NULL', a.attname), ' AND ') FROM unnest(c.conkey) AS k(attnum) JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) AS condition_present,
      (SELECT string_agg(format('parent.%I = child.%I', ap.attname, ac.attname), ' AND ') FROM unnest(c.conkey, c.confkey) AS k(attnum_child, attnum_parent) JOIN pg_attribute ac ON ac.attrelid = c.conrelid AND ac.attnum = k.attnum_child JOIN pg_attribute ap ON ap.attrelid = c.confrelid AND ap.attnum = k.attnum_parent) AS condition_match
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE c.contype = 'f' AND n.nspname IN ('vibetype', 'vibetype_private')
  LOOP
    EXECUTE format('SELECT count(*) FROM %s AS child WHERE %s AND NOT EXISTS (SELECT 1 FROM %s AS parent WHERE %s)', _constraint.table_child, _constraint.condition_present, _constraint.table_parent, _constraint.condition_match)
    INTO _orphans;

    IF _orphans > 0 THEN
      RAISE EXCEPTION '%: % rows reference no row in %', _constraint.conname, _orphans, _constraint.table_parent;
    END IF;
  END LOOP;
END
$$;

-- Derived data is written by triggers, which the copy skipped.
-- Firing only that trigger leaves the metadata, audit and notification triggers out of it.
ALTER TABLE vibetype.event ENABLE ALWAYS TRIGGER search_vector;
UPDATE vibetype.event SET name = name;
ALTER TABLE vibetype.event ENABLE TRIGGER search_vector;

COMMIT;
