# Multi-node placement

The swarm runs on more than one node.
Only one of them, the node carrying the `vibetype.storage=true` label, may run services that keep local state.
Every other service is free to be scheduled anywhere.

## Why the label exists

Two things in this stack are tied to a single machine.

Named volumes use Docker's `local` driver, so their contents live on whichever node the task happened to run on.
A service rescheduled to a different node finds an empty volume rather than its data.
For the database that means an empty database served to a live application, which is why placement is pinned rather than left to the scheduler.

Bind mounts of files under `configurations/` resolve to an absolute path on the node the stack was deployed from.
On any other node that path does not exist, and Docker silently creates an empty directory in its place, so the service starts misconfigured instead of failing.

## Which services are pinned

Services holding a production volume: `debezium`, `elasticsearch`, `grafana`, `portainer`, `postgres`, `postgres-backup`, `prometheus`, `reccoom-postgres`, `redis`, `redpanda`, `temporal-worker`, `traefik`, `traefik-certs-dumper` and all six `zammad` services.

Services holding only a `configurations/` bind mount: `adminer`, `debezium-postgres-connector`, `redpanda-console`, `temporal`.

Some of these also share a volume and therefore have to land on the same node as each other, which the shared label already guarantees: `postgres` with `postgres-backup` with `temporal-worker`, `traefik` with `traefik-certs-dumper`, and the six `zammad` services with one another.

## Adding a service

A new service needs the constraint below in its production delta if it declares a named volume that survives into production, or mounts anything from its `configurations/` directory.

```yaml
services:
  example:
    deploy:
      placement:
        constraints:
          - node.labels.vibetype.storage == true
```

Add the constraint in `src/production/<service>/compose.yaml` only.
Development runs on a single unlabelled node, where the constraint would leave the service unschedulable.

Where the development compose already declares constraints of its own, prepend `- (( append ))` to the list so the production entry adds to them instead of replacing them.

## Node setup

The storage node is the swarm's only manager and the machine `dargstack deploy --environment production` is run from.
Additional nodes join as workers, which keeps `traefik` a single instance and avoids a two-manager cluster, where losing either machine costs quorum.

Label the storage node once:

```sh
docker node update --label-add vibetype.storage=true <node>
```

### Private network

Every node attaches to the same Hetzner Cloud network, and the swarm binds to it.
The overlay network's data plane is not encrypted, so over public addresses the database credentials passed between services would travel in the clear.

Both the control plane and the data plane have to be moved.
The control plane address is what other nodes use to reach the manager, and the data plane address is the endpoint the overlay's VXLAN tunnels terminate on.
Leaving `--data-path-addr` unset silently defaults it to the advertise address, which puts container traffic back on the public interface.

Attaching a network to a running server does not configure the interface for it.
Give the private interface a netplan entry of its own so the address survives a reboot, otherwise the swarm loses its data path the next time the node restarts.

The private interface has to allow `2377/tcp` for cluster management, `7946/tcp` and `7946/udp` for node discovery, and `4789/udp` for the overlay data plane.
None of those ports belong on the public interface.

### Moving an existing single-node swarm onto the private network

A node has two addresses, and they move independently.
The data plane address is the endpoint the overlay's VXLAN tunnels terminate on, and it surfaces as `Status.Addr`.
The control plane address is what other nodes are told to use to reach the manager, and it surfaces as `ManagerStatus.Addr` and in `/var/lib/docker/swarm/state.json`.

`docker swarm init --force-new-cluster` rebinds the data plane address but leaves the control plane address untouched.
It restores the raft state from the existing snapshot, and the manager's own address is part of that snapshot.
Restarting the Docker daemon does not move it either, even though `/var/lib/docker/swarm/docker-state.json` records the requested address by then.

That distinction matters because a worker does not keep the address it joined on.
It replaces its stored remote with whatever the manager advertises, and libnetwork seeds the overlay's gossip cluster from that list on port `7946`.
A manager advertising a public address therefore breaks the overlay on every worker, whichever address the worker was joined with.

The failure is quiet.
The worker's dispatcher session stays up on the address it originally dialled, so `docker node ls` reports the node `Ready` while no gossip ever reaches it.
Service names then resolve only to the tasks on the local node, and containers on different nodes cannot reach each other by name.

Changing the control plane address means a genuine reinitialisation.

```sh
docker swarm leave --force
docker swarm init --advertise-addr <node-private> --data-path-addr <node-private> --listen-addr <node-private>
```

Every address flag takes a bare address: `10.99.1.1`, never `10.99.1.1/32`.

That destroys the raft store, and with it every service, secret and config, along with the storage label.
Volumes are left alone, so no data is lost, but the stack has to be redeployed afterwards and the label reapplied.

#### Preserving the secrets

Production secrets are external, so `dargstack deploy` does not recreate them and no copy exists on the host.
The raft store is their only home, and `docker secret inspect` does not return values.
Read them out of a container before leaving the swarm, and stage them somewhere that never touches the disk.

```sh
docker service create --name secret-dump --constraint node.hostname==<manager> --restart-condition none \
  $(docker secret ls --format '{{.Name}}' | sed 's/^/--secret /' | tr '\n' ' ') busybox:latest sleep 3600
mkdir -p /dev/shm/secrets
docker exec "$(docker ps -q -f name=secret-dump)" tar cf - -C /run/secrets . | tar xf - -C /dev/shm/secrets
docker service rm secret-dump
```

Confirm the dump holds every secret and that none of the files came out empty, then recreate them once the new swarm is up.

```sh
cd /dev/shm/secrets && for f in *; do docker secret create "$f" "$f"; done
```

Remove the staging directory afterwards with `rm -rf /dev/shm/secrets`.
It lives in `tmpfs`, so its contents never reach persistent storage, but they do not survive a reboot either, and between leaving the old swarm and recreating the secrets it holds the only copy.

Registry credentials need the same treatment.
Swarm embeds them into the service spec at deploy time rather than storing them centrally, so a rebuild leaves private images unpullable until `docker login` runs again and the affected services are updated with `--with-registry-auth`.

### Joining a node

Read the worker token on the manager with `docker swarm join-token worker`, then join with the private addresses rather than the command it prints.

```sh
docker swarm join --token <token> --advertise-addr <node-private> --data-path-addr <node-private> <manager-private>:2377
```

Confirm the address took before deploying anything, since a node that joined on its public address looks healthy and quietly moves container traffic back onto the internet.

```sh
docker node inspect <node> --format '{{.Status.Addr}}'
```

Check the manager's control plane address as well, since the two are set separately and only one of them is visible from the joining node.

```sh
docker node inspect <manager> --format '{{.ManagerStatus.Addr}}'
```

Neither reading proves the overlay works.
That takes a name resolving across nodes: with a global service running everywhere, its `tasks.` name has to return one address per node rather than only the local one.

```sh
docker exec <container> nslookup tasks.<service>
```

### Network MTU

Hetzner Cloud's private networks run at an MTU of 1450 rather than the 1500 the overlay driver assumes, so `src/production/compose.yaml` sizes the stack's network down to 1400 to leave room for the VXLAN header.

Docker never updates an existing network's options on deploy, so changing that value takes `dargstack deploy --environment production --force`, which removes the stack before recreating it.

Getting it wrong does not look like a network fault.
Health checks and small requests keep succeeding while large payloads stall, which reads as an application bug for as long as anyone is willing to chase it.
A multi-megabyte transfer between containers on different nodes settles it, where a health check would not.
