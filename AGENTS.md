---
applyTo: '**'
---
# Project Instructions

`stack` is the Docker Swarm configuration for [vibetype.app](https://vibetype.app/), an event community platform, managed with [dargstack](https://github.com/dargstack/dargstack/).

## Documentation Map

**For understanding the stack structure and deployment:**
- [README.md](README.md): Project overview, quick start
- [artifacts/docs/README.md](artifacts/docs/README.md): Auto-generated service, secret and volume reference (do not edit manually)
- [docs/multi-node.md](docs/multi-node.md): Which services are pinned to the storage node and why, plus how a node joins the swarm

**For contributing:**
- [CONTRIBUTING.md](CONTRIBUTING.md): Development setup, dargstack guidelines, code style, git workflow

**Cross-service contracts** (policies two or more services must implement identically, with no code shared between them):
- [docs/password-strength.md](docs/password-strength.md): Password strength requirements enforced by `vibetype` and `postgraphile`
- [docs/release-bundle.md](docs/release-bundle.md): What counts as a breaking change across services, how such changes wait on `beta` branches and how their majors are released together

## Code Style

- Do not use abbreviations in naming, except where omitting them would look unnatural
- Use natural language in any non-code text instead of referring to code directly, e.g. "the database's password" instead of "the `postgres_password`", except when a code reference is needed
- Use backticks in any non-code text to refer to code, e.g. "`postgres`" instead of "postgres"
- Sort YAML keys lexicographically except where order is semantically significant
- Code formatting is done by the editor via `.editorconfig`

## Git

- Git commit titles are lowercase only
- The commit scope should not be repeated in the commit description, e.g. `feat(postgres): add role` instead of `feat(postgres): add postgres role`
- Git commit scopes must be chosen as follows (ordered by priority):
  1. service name, e.g. `postgres`, `traefik`, `vibetype`
  2. simplified dependency name, e.g. `dargstack`, `docker`
  3. area, e.g. `secrets`, `volumes`, `certificates`
- A new major of a service is pinned through a pull request against `beta`, never `main`; see [docs/release-bundle.md](docs/release-bundle.md)

## Docker / dargstack

- Each service lives under `src/development/<service>/compose.yaml` as a full Compose document and optionally `src/production/<service>/compose.yaml` as a delta-only override
- Lines annotated with `# dargstack:dev-only` are stripped from production compose
- Run `dargstack build <service>` after changing a service's source code to rebuild its development container image
- Run `dargstack validate` to check the stack configuration
- Run `dargstack document` to regenerate `artifacts/docs/README.md` (do not edit that file manually)
- Do not commit files from `artifacts/` unless they are tracked (e.g. `artifacts/docs/SERVICES_ADDITIONAL.md`)
