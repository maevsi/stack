# vibetype

The Docker stack configuration for [vibetype.app](https://vibetype.app/). See [maevsi](https://github.com/maevsi).

## Profiles

Profiles group services so you can deploy subsets on demand. Activate with `dargstack deploy --profiles <name>`.

### analytics

Services: cadvisor, grafana, node-exporter, prometheus

### default

Services: adminer, cloudflared, portainer, portainer-agent, postgraphile, postgres, sqitch, traefik, vibetype

### event-streaming

Services: debezium, debezium-postgres-connector, redpanda, redpanda-console

### recommendation

Services: reccoom, reccoom-consumer, reccoom-migration, reccoom-postgres

### upload

Services: minio, tusd

### zammad

Services: elasticsearch, memcached, redis, zammad-backup, zammad-init, zammad-nginx, zammad-railsserver, zammad-scheduler, zammad-websocket

## Services

Each service corresponds to a compose.yaml file. Descriptions are extracted from YAML comments in the source. Services marked *(production only)* exist only in the production overlay.

### adminer

You can access the database's frontend at [adminer.app.localhost](https://adminer.app.localhost/).
This information is required for login:

|          |                     |
| -------- | ------------------- |
| System   | PostgreSQL          |
| Server   | postgres            |
| Username | [postgres-user]     |
| Password | [postgres-password] |
| Database | [postgres-db]       |

Values in square brackets are [Docker secrets](https://docs.docker.com/engine/swarm/secrets/).

### cadvisor

You can access the container metrics at [cadvisor.app.localhost](https://cadvisor.app.localhost/).

### cloudflared *(production only)*

You can configure the secure tunnel at [dash.cloudflare.com](https://dash.cloudflare.com/).

### debezium

You can see how changes in the database end up in the event stream using `redpanda-console`.

### debezium-postgres-connector

You can check the database connector's setup logs using `portainer`.

### elasticsearch

You cannot access the search engine via a web interface.

### geoip

You cannot access the ip geolocator via a web interface.

### grafana

You can access the observation dashboard at [grafana.app.localhost](https://grafana.app.localhost/).

### jobber

You cannot access the jobber via a web interface.

### memcached

You cannot access the caching system via a web interface.

### minio

You can access the s3 console at [minio.app.localhost](https://minio.app.localhost/).
You can access the s3 api service at [s3.app.localhost](https://s3.app.localhost/) if you want to access via cli from outside the stack.

### node-exporter

You can view host metrics in the Grafana observation dashboard.

### portainer

You can access the container manager's frontend at [portainer.app.localhost](https://portainer.app.localhost/).

### portainer-agent

You cannot access the container manager's agent directly.

### postgraphile

You can access the GraphQL API for the PostgreSQL database at [postgraphile.app.localhost](https://postgraphile.app.localhost/).

### postgres

You can access the database via `adminer`.

### postgres-backup *(production only)*

You cannot access the database backup directly.

### prometheus

You can access the metrics monitoring at [prometheus.app.localhost](https://prometheus.app.localhost/).

### reccoom

You cannot access the recommendation service directly.

### reccoom-consumer

You can track the recommender's event streaming consumer using `redpanda-console`.

### reccoom-migration

You cannot access the recommender's database migration service directly.

### reccoom-postgres

You can access reccoom's database via `adminer`.

### redis

You cannot access the caching system via a web interface.

### redpanda

You can access the event streaming platform's ui as described under `redpanda-console`.

### redpanda-console

You can access the event streaming platform's ui at [redpanda.app.localhost](https://redpanda.app.localhost/).

### sqitch

You cannot access the database migrations directly.

### traefik

You can access the reverse proxy's dashboard at [traefik.app.localhost](https://traefik.app.localhost/).

### traefik-certs-dumper *(production only)*

You cannot access the reverse proxy's certificate helper directly.

### tusd

You can access the upload service at [tusd.app.localhost](https://tusd.app.localhost/).

### vibetype

You can access the main project's frontend at [app.localhost](https://app.localhost/).

### zammad-backup

You cannot access the helpdesk backup service via a web interface.

### zammad-init

You cannot access the helpdesk initialization service via a web interface.

### zammad-nginx

You can access the helpdesk at [zammad.app.localhost](https://zammad.app.localhost/).

### zammad-railsserver

You cannot access the helpdesk application server directly.

### zammad-scheduler

You cannot access the helpdesk scheduler directly.

### zammad-websocket

You cannot access the helpdesk websocket server directly.

