#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../basico/helpers.sh"
show_script_version "Monitores Lua y espacios de trabajo" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Configurando monitores dinamicos"
mkdir -p "$HOME/.local/bin" "$HOME/.config/hypr/modules"

cat > "$HOME/.config/hypr/modules/monitors.lua" <<'LUA'
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
LUA

cat > "$HOME/.local/bin/hypr-monitor-workspaces" <<'SCRIPT'
#!/usr/bin/env bash
set -u
configure() {
    mapfile -t monitors < <(hyprctl monitors -j 2>/dev/null | jq -r 'sort_by(.x, .y) | .[].name')
    ((${#monitors[@]})) || return 0
    local index=0 start workspace monitor
    for monitor in "${monitors[@]}"; do
        start=$((index * 5 + 1))
        for ((workspace=start; workspace<start+5; workspace++)); do
            hyprctl keyword workspace "$workspace,monitor:$monitor,default:false" >/dev/null
        done
        index=$((index + 1))
    done
}
configure
[[ ${1:-} == --watch ]] || exit 0
socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
[[ -S $socket ]] || exit 1
while IFS= read -r event; do
    case "$event" in monitoradded\>*|monitorremoved\>*) sleep 1; configure ;; esac
done < <(socat -U - UNIX-CONNECT:"$socket")
SCRIPT
chmod 755 "$HOME/.local/bin/hypr-monitor-workspaces"
ok "Cinco espacios de trabajo por monitor configurados"
