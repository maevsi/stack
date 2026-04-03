#!/usr/bin/env bash
# Bootstrap a local Vibetype fullstack development environment.
#
# Usage (one-shot, without cloning first):
#   bash <(curl -fsSL https://raw.githubusercontent.com/maevsi/stack/main/scripts/setup.sh)
#
# Usage (when stack is already cloned):
#   bash scripts/setup.sh

set -euo pipefail

PARENT_DIR="vibetype"

# ── helpers ──────────────────────────────────────────────────────────────────

info()    { printf '\033[0;34m➜ %s\033[0m\n' "$*"; }
success() { printf '\033[0;32m✔ %s\033[0m\n' "$*"; }
warn()    { printf '\033[0;33m⚠ %s\033[0m\n' "$*"; }
die()     { printf '\033[0;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

# Ask a yes/no question; defaults to yes on empty input.
confirm() {
  local prompt="$1"
  local reply
  read -r -p "$(printf '\033[0;36m? %s [Y/n] \033[0m' "$prompt")" reply
  [[ "${reply:-y}" =~ ^[Yy]$ ]]
}

require() {
  command -v "$1" &>/dev/null || die "'$1' is required but not found. See: $2"
}

clone_if_missing() {
  local repo_url="$1"
  local repo_name
  repo_name="$(basename "$repo_url" .git)"
  if [[ -d "$repo_name/.git" ]]; then
    warn "$repo_name already exists, skipping clone."
    return
  fi
  if [[ -d "$repo_name" ]]; then
    die "Destination directory '$repo_name' already exists but is not a git repository. Remove or rename it, then rerun setup."
  fi

  # Prefer SSH; fall back to HTTPS if SSH authentication fails.
  local ssh_url="git@github.com:${repo_url#https://github.com/}"
  info "Cloning $repo_name …"
  if git clone "$ssh_url" 2>/dev/null; then
    return
  fi
  warn "SSH clone failed for $repo_name. Falling back to HTTPS."
  if git clone "$repo_url"; then
    return
  fi
  die "Failed to clone $repo_url via SSH and HTTPS."
}

# ── prerequisites ─────────────────────────────────────────────────────────────

info "Step 1/4 — Checking prerequisites (git, docker, dargstack) …"

require git    "https://git-scm.com/"
require docker "https://docs.docker.com/engine/install/"

# Check that the Docker daemon is actually reachable.
if ! docker info &>/dev/null; then
  die "Docker is installed but not running. Start Docker and try again."
fi

if ! command -v dargstack &>/dev/null; then
  if command -v go &>/dev/null; then
    info "Installing dargstack via go install …"
    go install github.com/dargstack/dargstack/v4/cmd/dargstack@latest

    # Check if dargstack is now in PATH; if not, try adding GOPATH/bin
    if ! command -v dargstack &>/dev/null; then
      go_bin="$(go env GOPATH)/bin"
      if [[ -f "$go_bin/dargstack" ]]; then
        export PATH="$go_bin:$PATH"
        info "Added $go_bin to PATH for this session."
      else
        die "dargstack installation completed, but binary not found at $go_bin/dargstack.
  Please ensure \$(go env GOPATH)/bin is in your PATH and restart the script.
  Or install a pre-built binary from https://github.com/dargstack/dargstack/releases"
      fi
    fi
  else
    die "'dargstack' is not installed and Go was not found.
  Install Go from https://go.dev/doc/install, then run:
    go install github.com/dargstack/dargstack/v4/cmd/dargstack@latest
  Or install a pre-built binary from https://github.com/dargstack/dargstack/releases"
  fi
fi

# ── detect working directory ──────────────────────────────────────────────────

CURRENT_DIR="$(pwd)"
if [[ "$(basename "$CURRENT_DIR")" == "stack" && -f "$CURRENT_DIR/dargstack.yaml" ]]; then
  TARGET_DIR="$(dirname "$CURRENT_DIR")"
  info "Running from inside the stack repo. Using parent directory: $TARGET_DIR"
else
  TARGET_DIR="$CURRENT_DIR/$PARENT_DIR"
  info "Creating project directory: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
fi

# ── profile / feature selection ───────────────────────────────────────────────

printf '\n\033[1mWhich optional feature sets do you want to set up?\033[0m\n'
printf '(The default profile (vibetype, postgres, postgraphile, sqitch, traefik, etc.) is always included.)\n\n'

CLONE_APP=false
CLONE_RECCOOM=false
EXTRA_PROFILES=()

if confirm "mobile app development (android, ios)"; then
  CLONE_APP=true
fi

if confirm "recommendation service (requires ssh authentication)"; then
  CLONE_RECCOOM=true
  EXTRA_PROFILES+=("recommendation")
fi

printf '\n'

# ── clone repositories ────────────────────────────────────────────────────────

info "Step 2/4 — Cloning repositories …"

cd "$TARGET_DIR"

# Always required
clone_if_missing "https://github.com/maevsi/postgraphile.git"
clone_if_missing "https://github.com/maevsi/sqitch.git"
clone_if_missing "https://github.com/maevsi/stack.git"
clone_if_missing "https://github.com/maevsi/vibetype.git"

# Optional
if $CLONE_APP; then
  clone_if_missing "https://github.com/maevsi/android.git"
  clone_if_missing "https://github.com/maevsi/ios.git"
fi

if $CLONE_RECCOOM; then
  clone_if_missing "https://github.com/maevsi/reccoom.git"
fi

success "Repositories ready."

# ── per-repo setup ────────────────────────────────────────────────────────────

info "Step 3/4 — Per-repository setup …"
info "  Each repository may need its own initialisation (e.g. installing Node.js dependencies for vibetype)."
info "  This step is not yet automated. If you want to start development in a specific repository, you have to manually set it up according to the project's README instructions first."
# TODO: Once each cloned repository ships its own `scripts/setup.sh`, invoke
#       them here uniformly instead of repository-specific logic. For example:
#
#   for repo in postgraphile sqitch stack vibetype reccoom android ios; do
#     if [[ -f "$TARGET_DIR/$repo/scripts/setup.sh" ]]; then
#       info "Running $repo setup …"
#       bash "$TARGET_DIR/$repo/scripts/setup.sh"
#     fi
#   done
#
# Vibetype-specific Node.js setup is intentionally skipped here for now.
# Run it manually if needed:
#
#   cd "$TARGET_DIR/vibetype"
#   nvm install
#   corepack enable
#   pnpm install

# ── build & deploy ────────────────────────────────────────────────────────────

info "Step 4/4 — Using dargstack to build development images and to deploy the stack …"
info "  'dargstack build' builds the development Dockerfiles for cloned first-party services."
info "  'dargstack deploy' runs the stack, a set of services, for development."
info "  Use --help on any dargstack command to learn more about it."

cd "$TARGET_DIR/stack"

# Build all services whose source code lives in a cloned repository.
SERVICES_TO_BUILD=("postgraphile" "sqitch" "vibetype")
$CLONE_RECCOOM && SERVICES_TO_BUILD+=("reccoom")

info "Building development container images: ${SERVICES_TO_BUILD[*]} …"
for svc in "${SERVICES_TO_BUILD[@]}"; do
  dargstack build "$svc" || warn "Build failed for $svc. You can retry with: dargstack build $svc"
done

success "Development images ready."

# Build the deploy command with any extra profiles.
DEPLOY_ARGS=()
for p in "${EXTRA_PROFILES[@]}"; do
  DEPLOY_ARGS+=("--profiles" "$p")
done

info "Deploying the development stack …"
dargstack deploy "${DEPLOY_ARGS[@]}"

success "Setup complete! Vibetype is available at https://app.localhost 🎉"
