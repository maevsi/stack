# Sqitch major upgrade

A major release of `sqitch` consolidates its migrations into a clean set of base migrations.
Its plan no longer matches the change history recorded in a database deployed by the previous major, so a plain `sqitch deploy` aborts with `Cannot find change ... in sqitch.plan`.
The database therefore goes through a dump, upgrade and restore cycle, and the stack release that pins the new `sqitch` major is a major release itself.

The procedure below keeps the data in the same database instead of round-tripping it through a file.
The old schemas are renamed out of the way, the new major deploys fresh schemas next to them, and [`sqitch-major-upgrade.sql`](sqitch-major-upgrade.sql) copies the data across.
The copy takes only the columns both generations share, so a column the major dropped, or one that was applied by hand and never made it into a release, is reported and left behind instead of failing the restore.

## Before you start

The new stack release has to be tagged and pin the new `sqitch`, `postgraphile` and `vibetype` versions together, as the GraphQL API changes with the schema.
Never deploy that release the usual way before following this procedure: its `sqitch` fails on the old database, and the new `vibetype` then runs against the old schema.
Plan for downtime: the application is unavailable from the first step until the last.

Rehearse on a copy of the production data first.
[`sqitch-major-upgrade-rehearse.sh`](sqitch-major-upgrade-rehearse.sh) runs the steps below on a throwaway database and fails when a row goes missing:

```sh
docs/sqitch-major-upgrade-rehearse.sh <old sqitch version> <new sqitch version> <latest postgres-backup dump>
```

It surfaces the constraint violations and the columns left behind before production sees them, including those caused by changes that were applied to the database by hand.

All commands run on the node carrying the `vibetype.storage=true` label.
This shorthand runs `psql` inside the database container as its superuser:

```sh
psql_vibetype() {
  docker exec -i "$(docker ps -q -f name=vibetype_postgres.1)" \
    sh -c 'psql -v ON_ERROR_STOP=1 -U "$(cat /run/secrets/postgres-user)" -d "$(cat /run/secrets/postgres-db)"' "$@"
}
```

## Procedure

1. Stop every service that reads or writes the database, so nothing changes while the data moves:

   ```sh
   docker service scale vibetype_vibetype=0 vibetype_postgraphile=0 vibetype_reccoom=0 vibetype_reccoom-consumer=0 vibetype_grafana=0 vibetype_debezium=0
   ```

   Skip the services of profiles that are not deployed.

2. Take a full backup and keep it outside the container until the upgrade is verified:

   ```sh
   docker exec "$(docker ps -q -f name=vibetype_postgres.1)" \
     sh -c 'pg_dump -Fc -U "$(cat /run/secrets/postgres-user)" "$(cat /run/secrets/postgres-db)"' > vibetype-before-upgrade.dump
   ```

3. Move the old schemas and the sqitch registry out of the way:

   ```sh
   psql_vibetype <<'EOF'
   ALTER SCHEMA vibetype RENAME TO vibetype_old;
   ALTER SCHEMA vibetype_private RENAME TO vibetype_private_old;
   ALTER SCHEMA sqitch RENAME TO sqitch_old;
   EOF
   ```

   With the `event-streaming` profile deployed, also drop Debezium's replication slot and publication, which still point at the renamed tables:

   ```sh
   psql_vibetype -c "SELECT pg_drop_replication_slot('debezium')" -c 'DROP PUBLICATION IF EXISTS dbz_publication'
   ```

   Debezium recreates both on its next start and, as its `snapshot.mode` is `when_needed`, publishes a fresh snapshot of the captured tables, which `reccoom` processes like any other event change.

4. Deploy only the `sqitch` service of the new release, which creates the new schemas, roles and registry:

   ```sh
   dargstack deploy -e production --major --services sqitch
   docker service logs --follow vibetype_sqitch
   ```

   Wait until it logs its last change as `ok`.
   Roles and extensions survive the rename, and the new major only creates them when absent.

5. Copy the data:

   ```sh
   psql_vibetype < docs/sqitch-major-upgrade.sql
   ```

   It prints one line per table with the number of rows copied and the columns left behind, and lists tables the major removed.
   Everything happens in one transaction, so an error leaves the new schemas empty.
   A row that violates a constraint the major introduced aborts the copy and names the table and value.
   Fix that row in the `_old` schema, then run the script again.

6. Deploy the full release, which scales the stopped services back up against the new schema:

   ```sh
   dargstack deploy -e production --major
   ```

   `postgraphile` builds its GraphQL schema once at startup, so it has to start after step 5; when it was not stopped, restart it with `docker service update --force vibetype_postgraphile`.

7. Once the application works, drop the old generation:

   ```sh
   psql_vibetype -c 'DROP SCHEMA vibetype_old, vibetype_private_old, sqitch_old CASCADE'
   ```

## Rolling back

Until step 7, the old data is untouched in the `_old` schemas.
Drop the new schemas and the new registry, rename the `_old` schemas back, and deploy the previous stack release:

```sh
psql_vibetype <<'EOF'
DROP SCHEMA vibetype, vibetype_private, sqitch CASCADE;
ALTER SCHEMA vibetype_old RENAME TO vibetype;
ALTER SCHEMA vibetype_private_old RENAME TO vibetype_private;
ALTER SCHEMA sqitch_old RENAME TO sqitch;
EOF
dargstack deploy -e production --tag <previous release>
```

After step 7, restore the dump from step 2 with `pg_restore --clean`.

## Derived data

The copy runs with triggers disabled, so metadata timestamps, audit logs and notifications are not touched.
Data that triggers derive, like the event search vectors, is rebuilt at the end of the script by firing only the trigger that writes it.
A major that adds another such table has to extend that part of the script.
