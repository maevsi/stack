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

Services holding a production volume: `debezium`, `elasticsearch`, `grafana`, `jobber`, `portainer`, `postgres`, `postgres-backup`, `prometheus`, `reccoom-postgres`, `redis`, `redpanda`, `traefik`, `traefik-certs-dumper` and all six `zammad` services.

Services holding only a `configurations/` bind mount: `adminer`, `debezium-postgres-connector`, `redpanda-console`.

Some of these also share a volume and therefore have to land on the same node as each other, which the shared label already guarantees: `postgres` with `postgres-backup` with `jobber`, `traefik` with `traefik-certs-dumper`, and the six `zammad` services with one another.

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

A node's data plane address is fixed when it joins, and there is no command to change it in place.
Rebinding an existing manager means `docker swarm init --force-new-cluster`, which keeps every service, secret, config and volume.

Get the flags right the first time.
The daemon stops the running swarm node before it validates the request, so a rejected argument leaves the node stopped and no longer a manager, and retrying then fails because the command requires a manager to begin with.
Both flags take a bare address: `10.99.1.1`, never `10.99.1.1/32`.
Recovering from that state means restarting the Docker daemon, which rebuilds the swarm node from `/var/lib/docker/swarm/`.

### Joining a node

Read the worker token on the manager with `docker swarm join-token worker`, then join with the private addresses rather than the command it prints.

```sh
docker swarm join --token <token> --advertise-addr <node-private> --data-path-addr <node-private> <manager-private>:2377
```

Confirm the address took before deploying anything, since a node that joined on its public address looks healthy and quietly moves container traffic back onto the internet.

```sh
docker node inspect <node> --format '{{.Status.Addr}}'
```

### Network MTU

Hetzner Cloud's private networks run at an MTU of 1450 rather than the 1500 the overlay driver assumes, so `src/production/compose.yaml` sizes the stack's network down to 1400 to leave room for the VXLAN header.

Docker never updates an existing network's options on deploy, so changing that value takes `dargstack deploy --environment production --force`, which removes the stack before recreating it.

Getting it wrong does not look like a network fault.
Health checks and small requests keep succeeding while large payloads stall, which reads as an application bug for as long as anyone is willing to chase it.
