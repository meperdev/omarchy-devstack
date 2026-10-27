#!/usr/bin/env bash
# Propiedad de puertos y aislamiento entre proyectos: dos stacks con el mismo
# puerto no se pisan, empezar el segundo mueve el suyo, bajar uno no baja el
# otro, el pin no toca el proyecto de casa, el menú se instala/verifica y el
# compose de cada proyecto queda aislado. Corre en CI (sin Omarchy).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DEVSTACK="$PWD/bin/devstack"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/xdg/devstack" "$tmp/run" "$tmp/a" "$tmp/b" "$tmp/c" "$tmp/plain" \
    "$tmp/xdg/omarchy/extensions"
printf '{\n}\n' >"$tmp/xdg/omarchy/extensions/omarchy-menu.jsonc"

export XDG_CONFIG_HOME="$tmp/xdg" XDG_RUNTIME_DIR="$tmp/run"

# Dos proyectos que declaran el MISMO puerto. El comando usa {port}: devstack
# reescribe el literal al mover el puerto.
printf '{"name":"A","dir":"%s/a","services":[{"id":"web","label":"web","type":"process","dir":"","cmd":"python3 -m http.server {port} --bind 127.0.0.1","port":4820,"url":"http://127.0.0.1:4820","health":"http://127.0.0.1:4820/","wait":5}]}\n' \
    "$tmp" >"$tmp/xdg/devstack/a.json"
printf '{"name":"B","dir":"%s/b","services":[{"id":"web","label":"web","type":"process","dir":"","cmd":"python3 -m http.server {port} --bind 127.0.0.1","port":4820,"url":"http://127.0.0.1:4820","health":"http://127.0.0.1:4820/","wait":5}]}\n' \
    "$tmp" >"$tmp/xdg/devstack/b.json"

fail=0
ok() { printf '\033[1;32m[ok]\033[0m   %s\n' "$1"; }
bad() {
    printf '\033[1;31m[fail]\033[0m %s\n' "$1" >&2
    fail=1
}
jget() { "$DEVSTACK" "$1" json | jq -r "$2"; }

printf 'ownership (puertos con dueño)\n'

"$DEVSTACK" a up >/dev/null 2>&1 && ok "A levanta en su puerto" || bad "A no levantó"
[[ $(jget a '.services[0].port') == 4820 ]] && ok "A conserva :4820 (arrancó primero)" \
    || bad "A cambió de puerto sin necesidad"
"$DEVSTACK" b up >/dev/null 2>&1 && ok "B levanta compartiendo el config" || bad "B no levantó"

bport=$(jget b '.services[0].port')
[[ $bport != 4820 ]] && ok "B se movió a :$bport" || bad "B se quedó en el puerto de A"
[[ $(jget a '.services[0].up') == true && $(jget a '.services[0].owner') == a ]] \
    && ok "A sigue arriba y se reconoce como dueño" || bad "A perdió su estado"
[[ $(jget b '.services[0].up') == true && $(jget b '.services[0].owner') == b ]] \
    && ok "B está arriba en el puerto nuevo" || bad "B no quedó arriba"

# El estado de un proyecto que comparte puerto con otro ENCENDIDO no puede
# decir "arriba": el que contesta es el otro.
"$DEVSTACK" a down >/dev/null 2>&1
[[ $(jget b '.services[0].up') == true ]] && ok "bajar A no baja B" || bad "bajar A tumbó B"

cp "$tmp/xdg/devstack/b.json" "$tmp/xdg/devstack/c.json"
jq '.name = "C" | .dir = "'"$tmp"'/c"' "$tmp/xdg/devstack/c.json" >"$tmp/c.json" && mv "$tmp/c.json" "$tmp/xdg/devstack/c.json"
[[ $(jget c '.services[0].conflict') == true && $(jget c '.services[0].up') == false \
    && $(jget c '.services[0].owner') == b ]] \
    && ok "si el puerto lo tiene otro proyecto, no cuenta como arriba" \
    || bad "el conflicto se ve como 'arriba'"
rm -f "$tmp/xdg/devstack/c.json"

printf 'pin (separado del proyecto de casa)\n'
"$DEVSTACK" use b >/dev/null 2>&1
"$DEVSTACK" pin a >/dev/null 2>&1
[[ $(cd "$tmp/plain" && "$DEVSTACK" pin) == a ]] && ok "pin guarda el proyecto fijado" || bad "pin no guarda"
[[ $(cd "$tmp/plain" && "$DEVSTACK" use) == b ]] && ok "fijar no cambia el proyecto de casa" || bad "fijar pisó use"
json=$(cd "$tmp/plain" && "$DEVSTACK" here json --default)
[[ $(printf '%s' "$json" | jq -r .project) == b && $(printf '%s' "$json" | jq -r .pinned) == a ]] \
    && ok "here sigue usando el default y expone el pin aparte" || bad "here mezcló pin y default"
"$DEVSTACK" pin --clear >/dev/null 2>&1
[[ -z $("$DEVSTACK" pin) && $(cd "$tmp/plain" && "$DEVSTACK" use) == b ]] \
    && ok "despinar no borra el proyecto de casa" || bad "despinar borró use"

printf 'menu (ruta verificada)\n'
"$DEVSTACK" menu --ensure a >/dev/null 2>&1
grep -Fq '"dev.a"' "$tmp/xdg/omarchy/extensions/omarchy-menu.jsonc" \
    && ok "menu --ensure instala la ruta dev.a" || bad "menu --ensure no instaló dev.a"
"$DEVSTACK" menu --ensure a >/dev/null 2>&1
[[ $(grep -cF '"dev.a"' "$tmp/xdg/omarchy/extensions/omarchy-menu.jsonc") == 1 ]] \
    && ok "menu --ensure es idempotente" || bad "menu --ensure duplicó el bloque"
"$DEVSTACK" menu --remove >/dev/null 2>&1
grep -Fq '"dev.a"' "$tmp/xdg/omarchy/extensions/omarchy-menu.jsonc" \
    && bad "menu --remove dejó la ruta" || ok "menu --remove quita el bloque"

printf 'compose aislado\n'
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    mkdir -p "$tmp/d"
    cat >"$tmp/d/docker-compose.yml" <<'YAML'
services:
  postgres:
    image: postgres:15-alpine
    container_name: postgres-db
    environment:
      POSTGRES_USER: admin
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
volumes:
  postgres_data:
YAML
    printf '{"name":"D","dir":"%s/d","services":[{"id":"db","label":"postgres","type":"docker","compose":"docker-compose.yml","container":"postgres-db","port":5432}]}\n' \
        "$tmp" >"$tmp/xdg/devstack/d.json"
    if out=$("$DEVSTACK" d compose-file db 2>/dev/null); then
        [[ $(printf '%s' "$out" | jq -r .name) == devstack-d ]] \
            && ok "el compose usa un proyecto propio" || bad "el compose no cambió de proyecto"
        [[ $(printf '%s' "$out" | jq -r '.services.postgres | has("container_name")') == false ]] \
            && ok "no queda container_name fijo" || bad "el container_name fijo sigue"
        [[ $(printf '%s' "$out" | jq -r '.volumes.postgres_data.name') == devstack-d_postgres_data ]] \
            && ok "el volumen es del proyecto" || bad "el volumen es compartido"
        [[ $(printf '%s' "$out" | jq -r '.services.postgres.ports[0].published') == 5432 ]] \
            && ok "el puerto publicado se conserva" || bad "el puerto publicado se perdió"
    else
        bad "no pude generar el compose aislado"
    fi
    rm -f "$tmp/xdg/devstack/d.json"
else
    ok "(docker no disponible: compose se salta)"
fi

printf 'apagar todo\n'
# Un runtime huérfano (proyecto ya borrado) no puede sobrevivir a `all down`.
mkdir -p "$tmp/run/devstack/huerfano"
setsid sleep 30 &
orphan=$!
printf '%s\n' "$orphan" >"$tmp/run/devstack/huerfano/web.pid"
"$DEVSTACK" all down --force >/dev/null 2>&1 || true
sleep 0.5
kill -0 "$orphan" 2>/dev/null && bad "el huérfano sigue vivo" || ok "all down baja los huérfanos"
[[ $(jget b '.services[0].up') == false ]] && ok "all down bajó el stack declarado" \
    || bad "all down dejó B arriba"

if ((fail)); then
    printf '\033[1;31mownership: hay fallos\033[0m\n' >&2
    exit 1
fi
printf '\033[1;32mownership: todo bien\033[0m\n'
