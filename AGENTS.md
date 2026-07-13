---
applyTo: '**'
---
# Project Instructions

`stack` is the Docker Swarm configuration for [vibetype.app](https://vibetype.app/), an event community platform, managed with [dargstack](https://github.com/dargstack/dargstack/).

## Documentation Map

**For understanding the stack structure and deployment:**
- [README.md](README.md): Project overview, quick start
- [artifacts/docs/README.md](artifacts/docs/README.md): Auto-generated service, secret and volume reference (do not edit manually)

**For contributing:**
- [CONTRIBUTING.md](CONTRIBUTING.md): Development setup, dargstack guidelines, code style, git workflow

## Code Style

- Do not use abbreviations in naming, except where omitting them would look unnatural
- Use natural language in any non-code text instead of referring to code directly, e.g. "the database's password" instead of "the `postgres_password`", except when a code reference is needed
- Use backticks in any non-code text to refer to code, e.g. "`postgres`" instead of "postgres"
- Sort YAML keys lexicographically except where order is semantically significant
- Code formatting is done by the editor via `.editorconfig`

## Git

- Work on branches other than the default branch
  - Use this branch naming pattern: `<type>/<scope>/<description>`
- Git commit titles must follow the Conventional Commits specification and be lowercase only
  - The commit scope should not be repeated in the commit description, e.g. `feat(postgres): add role` instead of `feat(postgres): add postgres role`
- Git commit scopes must be chosen as follows (ordered by priority):
  1. service name, e.g. `postgres`, `traefik`, `vibetype`
  2. simplified dependency name, e.g. `dargstack`, `docker`
  3. area, e.g. `secrets`, `volumes`, `certificates`
- Commit bodies are only to be filled in when necessary, e.g. to mention a resolved issue link

## Docker / dargstack

- Each service lives under `src/development/<service>/compose.yaml` as a full Compose document and optionally `src/production/<service>/compose.yaml` as a delta-only override
- Lines annotated with `# dargstack:dev-only` are stripped from production compose
- Run `dargstack build <service>` after changing a service's source code to rebuild its development container image
- Run `dargstack validate` to check the stack configuration
- Run `dargstack document` to regenerate `artifacts/docs/README.md` (do not edit that file manually)
- Do not commit files from `artifacts/` unless they are tracked (e.g. `artifacts/docs/SERVICES_ADDITIONAL.md`)
