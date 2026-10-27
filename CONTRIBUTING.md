# Contributing

Thanks for looking. This is a small tool: a bash CLI that owns the state, an
Omarchy bar widget that reads it, and an installer that wires both. Keep it that
way — the CLI is the single source of truth, the widget never touches docker or
sudo by itself.

## Layout

| Path | What it is |
|---|---|
| `bin/devstack` | the CLI (orchestration layer): service order, waits, health checks, pidfiles, docker elevation, notifications, `--force` take-over, `menu` block generation |
| `devstack here` (in `bin/devstack`) | the context layer: resolves which project a path (or the focused terminal, with `--window`) belongs to, and forwards subcommands there. Pure bash on top of `hyprctl` + `omarchy-cmd-terminal-cwd` — the widget stays dumb and calls it every 5 s |
| `lib/scan.sh` | the detection layer: reads a repo and **proposes** a stack. Read-only by contract — it never runs the project, never elevates, and never copies `.env` values (only ports and local URLs) |
| `bin/devstack-mcp` | the MCP server (a thin translator: each tool calls the CLI, so the guarantees are the same). Its tests are a real JSON-RPC transcript — if you add a tool, add its assertion there |
| `test/fixtures/` + `test/scan_test.sh` | toy repos reproducing the shapes we support (two-package, single app at the root, nothing recognisable, agent-documented commands) and the assertions on what the detector must infer |
| `Panel.qml` | the bar widget (an Omarchy `bar-widget` plugin). Reads `devstack json`, renders the four-colour state, one chip per service and the action buttons |
| `manifest.json` | the plugin manifest: id, entry point, and the settings schema (project, command, intervals, colours) |
| `install.sh` / `uninstall.sh` | plugin lifecycle + CLI + config + Omarchy menu block |
| `config/*.json` | example stacks. `demo.json` needs nothing but python3 |
| `docs/` | screenshot and the working-state GIF used by the README |

## Try it in one minute

```bash
export DEVDATA_CONFIG="$PWD/config"      # use the repo configs, not ~/.config
export DEVDATA_PROJECT=demo
bin/devstack demo up        # starts a python http.server on :8080
bin/devstack demo status
bin/devstack demo json | jq
bin/devstack demo down
```

No docker, no node, no Omarchy needed for that path: the CLI only requires bash,
`jq` and `ss` (iproute2), and the Omarchy-specific bits
(`omarchy-launch-browser`, `omarchy-sudo-docker`, `notify-send`) are optional
and detected at runtime.

## Add a project config

Copy `config/example.json` to `~/.config/devstack/<name>.json` and describe the
services in start order:

- `type: "docker"` → `compose` (file, relative to `dir`) + `container` + `port`.
  Brought down last, `--keep-docker` leaves it.
- `type: "process"` (default) → `dir` + `cmd` + `port` + `health`. Started with
  `setsid` so `down` can kill the whole process group.
- `health` is what turns the state green and what `report_ready` checks before
  opening the browser. `open: true` marks the service the browser button opens.
- `tasks[]` are extra commands (`seed`, `migrate`, …) with `needs: ["db"]` to
  lift dependencies first.

## Adding a framework or a signal

1. Add the branch to `scan_node_package()` (or `scan_other_project()`) in
   `lib/scan.sh`: the dependency that identifies it, its dev command, its default
   port, its health path, and its tasks.
2. Add (or extend) a fixture under `test/fixtures/` that looks like a real repo of
   that shape — including the `.env` and the compose file if the guess depends on
   them.
3. Add the `check`/`check_raw` lines to `test/scan_test.sh`. CI runs them, and a
   detector that guesses wrong is a bug: prefer "no reconocí" over inventing a
   service.

The detector must stay read-only. If a signal needs to execute the target repo to
be read, it does not belong here.

## Testing the widget

The widget is a plugin folder, so the shell validates it for you:

```bash
omarchy plugin validate .                 # manifest schema + entry point exists
omarchy plugin add "$PWD" --yes          # install from a local clone
omarchy plugin enable meperdonas.devstack --section right
omarchy restart shell
omarchy plugin list                      # should say: enabled  third-party bar-widget
journalctl --user _PID=$(pgrep -x omarchy-shell) | grep "Plugin widget"
```

Two rules learned the hard way:

- A QML file that fails to load makes the shell log `Plugin widget <id> failed:
  …` and **drop the widget silently**. Always grep the journal after touching
  `Panel.qml`.
- Do not redeclare a property the `Panel` base already has (`bar`, `moduleName`,
  `settings`, `ipcTarget`), and do not declare the same property twice — QML
  refuses the whole file with `Duplicate property name`.

To screenshot the popup without clicking it, temporarily replace
`Component.onCompleted: refresh()` with `Component.onCompleted: { refresh(); open() }`
in the installed copy, `omarchy restart shell`, capture, then
`git -C ~/.config/omarchy/plugins/meperdonas.devstack reset --hard HEAD`.

## Code style

- bash: `set -euo pipefail`, quoting everywhere, no `cd` without a subshell,
  comments that explain *why* (the ordering rules, the `set -e` traps, the
  process-group guard). Every command substitution that can fail either gets
  `|| true` or is used in a condition — a failing `ps`/`grep` under `set -e`
  aborts the whole script silently.
- QML: 2-space indent, `readonly property` for derived state, settings through
  `setting("key", fallback)`, no animating anything that is not in the working
  state.
- Colours come from the manifest defaults (`colorOff`, `colorError`,
  `colorWorking`, `colorOk`) so users can restyle without editing QML.

## Commits and releases

- One logical change per commit, imperative subject, body explaining the *why*.
- Update `README.md` when behaviour changes; keep the English section and the
  Spanish section in sync.
- Bump `version` in `manifest.json` for anything users will pull with
  `omarchy plugin update`.
