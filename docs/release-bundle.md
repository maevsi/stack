# Release bundle

This document is the single source of truth for how changes that span several services of the stack are held back and released together.
It lives here, rather than in one of the services, because the stack is the only place that pins all of their versions, so it is the stack that turns separate releases into one deployment.

## Scope

It applies to every first-party service the stack pins: `sqitch`, `postgraphile`, `vibetype` and `reccoom`, and to the stack itself.

## What counts as breaking

A change to a service is breaking in either of two cases:

- It removes or changes something another service or a client relies on, for example a GraphQL field, a database function, a message format or an environment variable.
- It only works with something new from another service, for example a column that only a newer `sqitch` provides or a condition that only a newer `postgraphile` offers, even when nothing changes for users.

The second case is the one that is easy to miss.
A new major release is how the stack learns that it has to deploy the other service first, which a minor release cannot express.

Adding something that others may start to use is not breaking, as long as the service itself still works against the versions of the other services that are released.

## Where breaking changes go

- A breaking pull request carries `!` in its title and targets the service's `beta` branch, which publishes prereleases.
- Its body states what it requires: the service, the minimum version, and what happens when that is missing.
- While `beta` carries breaking changes, the service keeps one draft pull request from `beta` to `main`, titled `ci(release)!: v<major>`, that lists every breaking pull request and explains how to upgrade.
- `main` is brought into `beta` through pull requests titled `chore(beta): merge main`, merged with a merge commit so both branches keep sharing their history.
- Breaking changes stay on `beta` until the bundle is released, so a service publishes one major for many breaking changes instead of one each.

A service that is still on `0.x`, currently `reccoom`, has no `beta` branch and marks nothing with `!`.
Its minor releases are its breaking releases.
Renovate raises them in the stack as separate pull requests and does not merge them on its own, so such a release is merged where the versions it requires are pinned.

## How versions reach the stack

- The stack pins each service in `src/production/<service>/compose.yaml`.
- Renovate merges patch and minor releases of services from `1.0` on into `main` on its own, which is safe exactly because of the rule above: such a release works against what is already deployed.
- A new major of a service enters through a pull request against the stack's `beta` branch, titled `feat(<service>)!: upgrade to v<major>`, and is listed in the stack's own `ci(release)!: v<major>` pull request.
- The pull request Renovate opens for that major against `main` must not be merged before the bundle is released.

## Releasing a bundle

1. In each service that takes part, bring `main` into `beta` and merge its release pull request with a merge commit, in the order in which the services depend on each other: `sqitch`, `postgraphile`, then `vibetype` and `reccoom`.
   Each service is then built and tested against released versions of what it needs.
1. In the stack, pin the released majors on `beta` and collect the upgrade instructions of the services in the stack's release pull request.
1. Merge the stack's release pull request with a merge commit.
1. Deploy the new stack version, which `dargstack deploy` only accepts for a new major when called with `--major`.

Releasing a service's major on its own changes nothing in production, because the stack still pins the previous one.
