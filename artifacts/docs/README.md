# vibetype

The Docker stack configuration for [vibetype.app](https://vibetype.app/). See [maevsi](https://github.com/maevsi).

## Profiles

Profiles group services so you can deploy subsets on demand. Activate with `dargstack deploy --profiles <name>`.

### analytics

Services: cadvisor, docker-socket-proxy, grafana, node-exporter, postgres, prometheus, sqitch, swarm-scheduler-exporter, traefik

### default

Services: adminer, cloudflared, portainer, portainer-agent, postgraphile, postgres, sqitch, traefik, vibetype

### event-streaming

Services: debezium, debezium-postgres-connector, gizmosql, gizmosql-maintenance, postgres, redpanda, redpanda-cluster-config, redpanda-connect, redpanda-console, sqitch, traefik
