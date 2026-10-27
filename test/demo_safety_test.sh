#!/usr/bin/env bash
# El demo no puede usar un cwd compartido ni el modo normal de Python: corre
# `python3 -I` dentro de un directorio 0700. Un `socket.py` plantado ahí no se
# importa (sin -I, CPython antepone el cwd al sys.path y lo ejecutaría).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DEVSTACK="$PWD/bin/devstack"

tmp=$(mktemp -d)
port=$((40000 + RANDOM % 20000))
cleanup() {
    "$DEVSTACK" demo down >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT

export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Copia el demo con un puerto libre, sin tocar el original.
mkdir -p "$XDG_CONFIG_HOME/devstack"
jq --argjson p "$port" '
  .services[0].port = $p
  | .services[0].url = "http://127.0.0.1:\($p)"
  | .services[0].health = "http://127.0.0.1:\($p)"
  | .services[0].cmd = (.services[0].cmd | gsub("8080"; ($p | tostring)))
' config/demo.json >"$XDG_CONFIG_HOME/devstack/demo.json"

demo_dir="$HOME/.local/state/devstack/demo"
marker="$tmp/pwned"
mkdir -p "$demo_dir"
cat >"$demo_dir/socket.py" <<PY
from pathlib import Path
Path("$marker").write_text("executed")
PY

export DEVDATA_CONFIG="$XDG_CONFIG_HOME/devstack" DEVDATA_PROJECT=demo
"$DEVSTACK" demo up >/dev/null

[[ $(stat -c '%a' "$demo_dir") == 700 ]] \
    || { echo "el directorio del demo no quedó 0700" >&2; exit 1; }
[[ ! -e $marker ]] \
    || { echo "el demo importó un módulo del cwd" >&2; exit 1; }
"$DEVSTACK" demo --running

"$DEVSTACK" demo down >/dev/null
printf '\033[1;32mdemo: todo bien\033[0m\n'
