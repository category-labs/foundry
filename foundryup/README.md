# `foundryup`

Update or revert to a specific Foundry or Monad Foundry release with ease.

`foundryup` supports installing and managing multiple versions.

## Installing

```sh
curl -L https://raw.githubusercontent.com/category-labs/foundry/monad/foundryup/install | bash
```

Existing users with the legacy `foundryup 1.5.0` launcher must rerun this installer once. The old
launcher only parses `major.minor.patch` versions and cannot self-update to the Monad version scheme.

Monad foundryup versions use `<upstream-foundryup-version>-monad-v<fork-version>`. For example,
`1.5.0-monad-v1.0.0` is Monad foundryup v1.0.0 based on upstream foundryup 1.5.0.

## Usage

To install the latest stable **Monad Foundry** release:

```sh
foundryup --network monad
```

The stable Monad channel resolves to a concrete immutable release such as
`v1.7.1-monad-v1.0.0`. To install a specific Monad Foundry release instead:

```sh
foundryup --network monad --install v1.7.1-monad-v1.0.0
```

Running `foundryup` without `--network monad` installs upstream Foundry.

To install the latest **nightly** version:

```sh
foundryup --install nightly
```

To install a specific version (e.g. `v1.7.0`):

```sh
foundryup --install v1.7.0
```

To **list** all **versions** installed:

```sh
foundryup --list
```

To switch between different versions and **use**:

```sh
foundryup --use nightly-00efa0d5965269149f374ba142fb1c3c7edd6c94
```

To install a specific **branch** (in this case the `release/0.1.0` branch's latest commit):

```sh
foundryup --branch release/0.1.0
```

To install a **fork's main branch** (in this case `transmissions11/foundry`'s main branch):

```sh
foundryup --repo transmissions11/foundry
```

To install a **specific branch in a fork** (in this case the `patch-10` branch's latest commit in `transmissions11/foundry`):

```sh
foundryup --repo transmissions11/foundry --branch patch-10
```

To install from a **specific Pull Request**:

```sh
foundryup --pr 1071
```

To install from a **specific commit**:

```sh
foundryup -C 94bfdb2
```

To install a local directory or repository (e.g. one located at `~/git/foundry`, assuming you're in the home directory)

#### Note: --branch, --repo, and --version flags are ignored during local installations.

```sh
foundryup --path ./git/foundry
```

---

**Tip**: All flags have a single character shorthand equivalent! You can use `-i` instead of `--install`, etc.

---

## Uninstalling

Foundry contains everything in a `.foundry` directory, usually located in `/home/<user>/.foundry/` on Linux, `/Users/<user>/.foundry/` on MacOS and `C:\Users\<user>\.foundry` on Windows where `<user>` is your username.

To uninstall Foundry remove the `.foundry` directory.

#### Warning ⚠️: .foundry directory can contain keystores. Make sure to backup any keystores you want to keep.

Remove Foundry from PATH:

- Optionally Foundry can be removed from editing shell configuration file (`.bashrc`, `.zshrc`, etc.). To do so remove the line that adds Foundry to PATH:

```sh
export PATH="$PATH:/home/user/.foundry/bin"
```
