#!/usr/bin/env bash
# Prueba con un archivo cifrado REAL del comando «cambiar-clave» que instala base/install-base.sh.
# Uso, desde la raíz del repositorio y en un equipo que tenga cryptsetup: bash base/probar-cambiar-clave.sh
# No toca discos: crea un archivo contenedor LUKS2 en un directorio temporal y lo borra al terminar.
# Lo único simulado es el usuario del sistema (chpasswd y getent); todo lo demás es cryptsetup de verdad.
# Imprime una línea PASS o FAIL por caso y, al final, TOTAL con la cuenta.
set -u
export LC_ALL=C.UTF-8
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$AQUI/install-base.sh"
[[ -f "$SRC" ]] || { echo "FAIL no existe $SRC"; exit 2; }
command -v cryptsetup >/dev/null 2>&1 || { echo "FAIL este equipo no tiene cryptsetup"; exit 2; }
DIR="$(mktemp -d)" || exit 2
trap 'rm -rf "$DIR"' EXIT

# Extrae el comando tal como lo instala el instalador y lo carga sin ejecutarlo.
awk "/<< 'CLAVE_SCRIPT'/ {p = 1; next} /^CLAVE_SCRIPT\$/ {p = 0} p" "$SRC" > "$DIR/cambiar-clave"
[[ -s "$DIR/cambiar-clave" ]] || { echo "FAIL no encontré el comando cambiar-clave en $SRC"; exit 2; }
# shellcheck source=/dev/null
source "$DIR/cambiar-clave"

IMG="$DIR/disco.img"
VIEJA='clave-vieja-123'
NUEVA='clave-nueva-456'
TERCERA='tercera-clave-789'
USUARIO_PASS=""
USUARIO_FALLA=""
QUITA_FALLA=""
RC=0
export SUDO_USER=ana

# Lo simulado: el usuario del sistema y la comprobación de root. El disco y las claves son reales.
es_root() { return 0; }
luks_device() { printf '%s\n' "$IMG"; }
getent() { [[ "${1:-}" == passwd ]]; }
usuario_hash() { printf 'h:%s' "$USUARIO_PASS"; }
cambia_usuario() {
    [[ "$USUARIO_FALLA" == rc ]] && return 1
    [[ "$USUARIO_FALLA" == noop ]] && return 0
    USUARIO_PASS="$2"
}
eval "$(declare -f quita_clave | sed '1s/quita_clave/quita_clave_real/')"
quita_clave() {
    if [[ "$QUITA_FALLA" == vieja && "$2" == "$VIEJA" ]]; then return 1; fi
    quita_clave_real "$@"
}

pass=0; fail=0
check() { # $1 = nombre, $2 = esperado, $3 = obtenido
    if [[ "$2" == "$3" ]]; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1 | esperado=[$2] obtenido=[$3]"; fail=$((fail + 1)); fi
}
nuevo_disco() { # $1 = clave inicial del disco y del usuario
    rm -f "$IMG"
    truncate -s 32M "$IMG"
    printf '%s' "$1" | cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --batch-mode "$IMG" - >/dev/null 2>&1
    USUARIO_PASS="$1"; USUARIO_FALLA=""; QUITA_FALLA=""
}
ab() { # ¿la clave $1 abre el disco? Comprobación independiente de la del comando: usa un archivo de claves.
    printf '%s' "$1" > "$DIR/k"
    if cryptsetup open --test-passphrase --type luks --key-file "$DIR/k" "$IMG" >/dev/null 2>&1; then echo SI; else echo NO; fi
}
corre() { # las entradas llegan por stdin, una por línea; la salida queda en $DIR/salida
    cambiar_clave < <(printf '%s\n' "$@") > "$DIR/salida" 2>&1
    RC=$?
}
fallo() { if (( RC != 0 )); then echo SI; else echo NO; fi; }
sin_cambios() { # el disco y el usuario siguen como estaban
    check "$1: el disco sigue abriendo solo con la clave de antes" "SI NO" "$(ab "$VIEJA") $(ab "$NUEVA")"
    check "$1: una sola ranura" 1 "$(ranuras "$IMG")"
    check "$1: el usuario conserva su contraseña" "h:$VIEJA" "$(usuario_hash x)"
}

nuevo_disco "$VIEJA"
check "formato real: abre con su clave y no con otra" "SI NO" "$(ab "$VIEJA") $(ab otra-cosa-123)"
check "formato real: una ranura" 1 "$(ranuras "$IMG")"

# Camino feliz, y dos cambios seguidos.
corre "$VIEJA" "$NUEVA" "$NUEVA" SI
check "feliz: sale con 0" 0 "$RC"
check "feliz: abre la nueva y no la vieja" "SI NO" "$(ab "$NUEVA") $(ab "$VIEJA")"
check "feliz: el usuario quedó con la nueva" "h:$NUEVA" "$(usuario_hash x)"
check "feliz: queda una sola ranura" 1 "$(ranuras "$IMG")"
corre "$NUEVA" "$TERCERA" "$TERCERA" SI
check "segundo cambio: sale con 0 y abre solo la tercera" "0 SI NO NO" "$RC $(ab "$TERCERA") $(ab "$NUEVA") $(ab "$VIEJA")"

# Cosas que deben parar sin tocar nada.
nuevo_disco "$VIEJA"; corre "equivocada-123" "$NUEVA" "$NUEVA" SI
check "clave actual equivocada: falla" SI "$(fallo)"; sin_cambios "clave actual equivocada"
nuevo_disco "$VIEJA"; corre "$VIEJA" "$NUEVA" "otra-distinta-1" SI
check "confirmación distinta: falla" SI "$(fallo)"; sin_cambios "confirmación distinta"
nuevo_disco "$VIEJA"; corre "$VIEJA" "abc" "abc" SI
check "clave corta: falla" SI "$(fallo)"; sin_cambios "clave corta"
nuevo_disco "$VIEJA"; corre "$VIEJA" "clave-ñandú-123" "clave-ñandú-123" SI
check "clave con acentos: falla" SI "$(fallo)"; sin_cambios "clave con acentos"
nuevo_disco "$VIEJA"; corre "$VIEJA" "$VIEJA" "$VIEJA" SI
check "clave igual a la actual: falla" SI "$(fallo)"; sin_cambios "clave igual"
nuevo_disco "$VIEJA"; corre "$VIEJA" "$NUEVA" "$NUEVA" no
check "no escribir SI: no cambia" SI "$(fallo)"; sin_cambios "sin confirmar"
OTRA='otra-clave-guardada-1'
nuevo_disco "$VIEJA"; printf '%s' "$OTRA" > "$DIR/k2"
printf '%s' "$VIEJA" | cryptsetup luksAddKey --batch-mode --key-file=- --pbkdf pbkdf2 --pbkdf-force-iterations 1000 "$IMG" "$DIR/k2" >/dev/null 2>&1
check "preparación: hay dos claves guardadas" 2 "$(ranuras "$IMG")"
corre "$VIEJA" "$OTRA" "$OTRA" SI
check "clave nueva que ya abre el disco: falla" SI "$(fallo)"
check "clave nueva que ya abre el disco: no se toca nada" "SI SI 2 h:$VIEJA" "$(ab "$VIEJA") $(ab "$OTRA") $(ranuras "$IMG") $(usuario_hash x)"

# Fallos a medias: nunca se pierde el acceso y se deshace lo hecho.
nuevo_disco "$VIEJA"; USUARIO_FALLA=rc; corre "$VIEJA" "$NUEVA" "$NUEVA" SI
check "chpasswd falla: sale con error" SI "$(fallo)"; sin_cambios "chpasswd falla"
nuevo_disco "$VIEJA"; USUARIO_FALLA=noop; corre "$VIEJA" "$NUEVA" "$NUEVA" SI
check "chpasswd no cambia nada: sale con error" SI "$(fallo)"; sin_cambios "chpasswd sin efecto"
nuevo_disco "$VIEJA"; QUITA_FALLA=vieja; corre "$VIEJA" "$NUEVA" "$NUEVA" SI
check "no se puede quitar la vieja: sale con error" SI "$(fallo)"
check "no se puede quitar la vieja: abren las dos claves" "SI SI" "$(ab "$VIEJA") $(ab "$NUEVA")"
check "no se puede quitar la vieja: dos ranuras" 2 "$(ranuras "$IMG")"
check "no se puede quitar la vieja: el usuario ya tiene la nueva" "h:$NUEVA" "$(usuario_hash x)"

echo "TOTAL pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
