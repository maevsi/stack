[![ci status][ci-image]][ci-url]

[ci-image]: https://img.shields.io/github/actions/workflow/status/maevsi/stack/ci.yml
[ci-url]: https://github.com/maevsi/stack/actions/workflows/ci.yml

# @maevsi/stack

The Docker stack configuration for [vibetype.app](https://vibetype.app/).

This project is managed with [dargstack](https://github.com/dargstack/dargstack/) and is closely related to [Vibetype's source code](https://github.com/maevsi/vibetype/).

## Documentation

To see which services, secrets and volumes this stack includes, head over to [`artifacts/docs/README.md`](artifacts/docs/README.md).

## Development Setup

> 💡 **Windows users:** Run these steps inside [WSL](https://docs.microsoft.com/en-us/windows/wsl/install).

> 📖 **New to the project? Read [CONTRIBUTING.md](CONTRIBUTING.md) first** to understand the repository structure, the development modes, and what each component does. You will need this context to work effectively beyond the quick setup below.

To start a local fullstack development environment, run the setup script from the directory where you want to clone the project:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/maevsi/stack/main/scripts/setup.sh)
```

Or, if you have already cloned this repository:

```sh
bash scripts/setup.sh
```
