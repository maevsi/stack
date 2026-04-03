# Contributing to stack

Thank you for your interest in contributing!

The fullstack environment composes several services, among those are the following first-party:

| Repository | Required | Profile | Access |
|---|---|---|---|
| [maevsi/android](https://github.com/maevsi/android) | optional | — | public |
| [maevsi/ios](https://github.com/maevsi/ios) | optional | — | public |
| [maevsi/postgraphile](https://github.com/maevsi/postgraphile) | ✅ | `default` | public |
| [maevsi/reccoom](https://github.com/maevsi/reccoom) | optional | `recommendation` | private |
| [maevsi/sqitch](https://github.com/maevsi/sqitch) | ✅ | `default` | public |
| [maevsi/stack](https://github.com/maevsi/stack) | ✅ | — | public |
| [maevsi/vibetype](https://github.com/maevsi/vibetype) | ✅ | `default` | public |

## Development Setup

There are two development modes:

| Mode | When to use | Setup | Where to start |
|---|---|---|---|
| **Frontend only** | Working on UI, i18n, or anything that doesn't require running backend services | Manual only | [Vibetype repository](https://github.com/maevsi/vibetype#development) |
| **Fullstack** | Working on backend services, the database, the API, or any cross-cutting concern | Automated or manual | This guide (continue reading) |

> 🪟 **Windows users:** Set up [WSL](https://docs.microsoft.com/en-us/windows/wsl/install) first and continue inside the Linux subsystem.
> If you use VS Code, see [VS Code + WSL](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-vscode).

### Automated Setup

Clone this repository into the directory where you want the project to live, then run the setup script from inside the cloned `stack` repository:
```sh
cd /path/to/where/you/want/the/project
git clone https://github.com/maevsi/stack.git
cd stack

```sh
bash scripts/setup.sh
```

The script will interactively ask which optional feature sets you want, then:

1. Clone the selected repositories as siblings inside a `vibetype/` parent directory.
2. Run `dargstack build <service>` for the selected services to build the required development container images.
3. Deploy the development stack with `dargstack deploy`.

> Per-repository setup (e.g. Node.js install for `vibetype`) is not yet automated here. Each repository will eventually provide its own `scripts/setup.sh` that this script will invoke. In the meantime, follow the manual steps below for repository-specific preparation.

### Manual Setup

If you prefer to step through each action yourself:

1. Install prerequisites

    1. [Git](https://git-scm.com/): version control
    2. [Docker](https://docs.docker.com/engine/install/): container runtime
    3. [dargstack](https://github.com/dargstack/dargstack#install): stack management CLI
    <!-- 4. [nvm](https://github.com/nvm-sh/nvm#installing-and-updating): Node.js version manager (for Vibetype frontend setup) -->

1. Create a parent directory and clone the sibling repositories into it:

   ```sh
   mkdir vibetype && cd vibetype
   git clone git@github.com:maevsi/android.git # optional
   git clone git@github.com:maevsi/ios.git # optional
   git clone git@github.com:maevsi/postgraphile.git
   git clone git@github.com:maevsi/reccoom.git # optional, private
   git clone git@github.com:maevsi/sqitch.git
   git clone git@github.com:maevsi/stack.git
   git clone git@github.com:maevsi/vibetype.git
   ```

   <details>
     <summary>Click here if you don't have SSH set up (you should!) to use HTTPS URLs instead</summary>


   ```sh
   mkdir vibetype && cd vibetype
   git clone https://github.com/maevsi/android.git # optional
   git clone https://github.com/maevsi/ios.git # optional
   git clone https://github.com/maevsi/postgraphile.git
   git clone https://github.com/maevsi/reccoom.git # optional, private
   git clone https://github.com/maevsi/sqitch.git
   git clone https://github.com/maevsi/stack.git
   git clone https://github.com/maevsi/vibetype.git
   ```
    </details>

2. Initialize all cloned projects for development according to their READMEs.

3. Build development container images:

   ```sh
   cd stack
   dargstack build
   ```

   An interactive selection dialog will let you choose which services to build.

4. Deploy:

   ```sh
   dargstack deploy
   ```

5. You should now be able to access Vibetype at [https://app.localhost](https://app.localhost) 🎉


## Guidelines

### Git & GitHub

Follow [@dargmuesli's Contributing Guidelines](https://gist.github.com/dargmuesli/430b7d902a22df02d88d1969a22a81b5#contribution-workflow) for branch naming, commit formatting, and the pull request workflow.

### Semantic Versioning

Read [@dargmuesli's guide on Semantic Versioning](https://gist.github.com/dargmuesli/430b7d902a22df02d88d1969a22a81b5#file-semantic-versioning-md) for how to format PR, issue and commit titles.

### dargstack

- Service files live in `src/development/<service>/compose.yaml` (full Compose document) and `src/production/<service>/compose.yaml` (production delta only).
- Run `dargstack build` to interactively select and build development container images after making changes to a service's source code.
- Run `dargstack document` to regenerate `artifacts/docs/README.md` after adding or modifying services.
- Do not edit `artifacts/` files directly: they are generated or gitignored.

### Code Style

- Keep YAML keys sorted lexicographically where order is semantically irrelevant.
- Use natural language in comments; refer to code artifacts with backticks.
- Do not use abbreviations in names unless omitting them would look unnatural.
