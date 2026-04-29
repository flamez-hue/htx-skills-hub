# htx-cli

A Go-based command-line harness for the HTX (formerly Huobi) REST API, shipped
alongside a set of six Claude Code / Claude Agent skills that wrap it with
least-privilege API scopes.

## What's in this repo

| Path | Purpose |
| --- | --- |
| [`agent-harness-go/`](./agent-harness-go) | Go source for the `htx-cli` binary. |
| [`openapi/`](./openapi) | OpenAPI specs driving the CLI. |
| [`skills/`](./skills) | Six installable Claude skills (see table below). |
| [`build.sh`](./build.sh) | Cross-compile release binaries for macOS / Linux / Windows into `dist/`. |
| [`install.sh`](./install.sh) | Install the binary from a GitHub release (macOS / Linux). |
| [`install-local.sh`](./install-local.sh) | Install the binary from a local `dist/` directory. |
| [`install.ps1`](./install.ps1) | Windows (PowerShell) equivalent of `install.sh`. |
| [`install-all.sh`](./install-all.sh) | One-shot installer: binary **and** all six skills. |
| [`skills/install-all.sh`](./skills/install-all.sh) | Bulk install / uninstall skills only. |

## Skills at a glance

| Skill | Endpoints | Auth | Risk |
| --- | --- | --- | --- |
| [`spot-market`](./skills/htx/spot-market)       | 15 | none        | zero |
| [`spot-account`](./skills/htx/spot-account)     | 9  | read key    | low  |
| [`spot-trading`](./skills/htx/spot-trading)     | 11 | trade key   | high |
| [`futures-market`](./skills/htx/futures-market) | 36 | mostly none | zero |
| [`futures-account`](./skills/htx/futures-account) | 30 | read key  | low  |
| [`futures-trading`](./skills/htx/futures-trading) | 50 | trade key | high |

Skills are split by permission tier so agents load only what they need and
users can grant the narrowest possible API-key rights.

## Quick start

### Install everything (binary + skills)

```bash
./install-all.sh                              # binary (GitHub release) + all skills
./install-all.sh --local                      # binary from local ./dist + all skills
./install-all.sh --binary-only                # binary only
./install-all.sh --skills-only                # skills only
./install-all.sh --only spot-market,spot-account   # skills subset
./install-all.sh --uninstall                  # remove skills (binary left in place)
./install-all.sh --help
```
```bash
source ~/.zshrc # or source ~/.bashrc
```

Flags are forwarded to the delegated scripts. `npx` (Node.js ≥ 18) is required
for the skills step; if it's missing, the binary still installs and the script
prints a warning.

### Install only the binary

```bash
# From a GitHub release (stable):
./install.sh

# Latest pre-release:
./install.sh --beta

# From a locally built ./dist directory:
./install-local.sh
```

### Install only the skills

```bash
./skills/install-all.sh                       # all six from the local repo
./skills/install-all.sh --registry            # from npm registry (@htx-skills/*)
./skills/install-all.sh --only spot-market
./skills/install-all.sh --uninstall
```

Individual skills can be installed one at a time:

```bash
npx -y @htx-skills/spot-market install
npx -y @htx-skills/futures-trading install
```

## Build from source

Requires Go 1.23+.

```bash
./build.sh                  # version inferred from git
./build.sh v1.2.3           # explicit version tag
VERSION=v1.2.3 ./build.sh   # via env
```

Output goes to `./dist/`:

```
htx-cli-x86_64-apple-darwin
htx-cli-aarch64-apple-darwin
htx-cli-x86_64-unknown-linux-gnu
htx-cli-aarch64-unknown-linux-gnu
htx-cli-armv7-unknown-linux-gnueabihf
htx-cli-i686-unknown-linux-gnu
htx-cli-x86_64-pc-windows-msvc.exe
htx-cli-aarch64-pc-windows-msvc.exe
htx-cli-<version>-<target>.tar.gz|.zip
checksums.txt
```

After building, `./install-local.sh` (or `./install-all.sh --local`) will pick
up the binary for the current platform.

## Configure credentials

```bash
htx-cli config set-key    <AccessKeyId>
htx-cli config set-secret <SecretKey>
htx-cli config show
```

Recommended:

- Use a **read-only** key for `spot-account` / `futures-account`.
- Use a separate **trade-enabled** key (ideally IP-allow-listed, no withdrawal)
  for `spot-trading` / `futures-trading`.
- Market-data skills need **no key at all**.

Environment variables `HTX_API_KEY` and `HTX_SECRET_KEY` work as well.

## Supported platforms

- macOS: x86_64 (Intel), arm64 (Apple Silicon)
- Linux: x86_64, i686, aarch64, armv7l
- Windows: x86_64, aarch64 (use `install.ps1` / `install-local.ps1`)

## Layout

```
htx-cli/
├── agent-harness-go/     # Go source for the binary
├── openapi/              # OpenAPI specs
├── skills/
│   ├── install-all.sh    # skills bulk installer
│   └── htx/
│       ├── spot-market/
│       ├── spot-account/
│       ├── spot-trading/
│       ├── futures-market/
│       ├── futures-account/
│       └── futures-trading/
├── build.sh              # cross-compile
├── install.sh            # binary installer (remote)
├── install-local.sh      # binary installer (local dist)
├── install.ps1           # binary installer (Windows)
└── install-all.sh        # binary + skills unified installer
```

## License

MIT — see each skill's `LICENSE.md`.
