#!/bin/bash
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

# presentacion.d64, the presentation's test disk (the first C64 disk, without the start menu; NOTAS.md
# here), the files in this order:
#   "abadia"      the first stage (LOAD"*",8,1 + RUN): the presentation (c64/presentacion: the abadia.c,
#                 manuscrito.c, io.c, with the CPC's music): the parchment with the introduction text, then on a key
#                 the picture on the game's screen and the game's loader (cargador.s, run from $C3E8);
#   "abadia.koa"  the picture (as the program reads it), "text1.bin" the introduction text with this version's
#                 credits, "pp.bin" the parchment's border and glyphs (+ the glyphs 0 6 @ B);
#   "juego"       the stream the loader reads: the game's image (flujo.py), loaded under the picture;
#   "final"       the ending (the parchment with the CPC's ending text and music), loaded by the game's
#                 plat_final when it is won at 100 %; "text2.bin" the ending's text (the tape's).
#
#   construye.sh [--sin-compresion]
#
# The data is always stored as literal runs, without compression. --sin-compresion is accepted for compatibility;
# both invocations produce juego.prg and abadia64ks.d64 (no alternate disk or suffixed stream).
# DISCO_SALIDA selects another output path without replacing the ordinary disk.
#
# The game's image is the C64 build c64/juego_final/c64, rebuilt first unless CONSTRUYE_JUEGO=0. JUEGO=dir selects
# an existing alternate build without rebuilding it; CONSTRUYE_JUEGO=1 explicitly rebuilds that directory's parent
# with `C64=1 ./construye.sh`, never the original by mistake. Everything else is generated: the presentation, ending
# and the loader (c64/presentacion/construye.sh -> c64/presentacion/generado), the stream (flujo.py, checked by its
# model of the loader: flujo.txt), the disk (c1541; replaced atomically only after the new image is complete).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$(dirname "$(dirname "$D")")")")
PRES=$P/c64/presentacion
G=$PRES/generado
salida=${DISCO_SALIDA:-$D/presentacion.d64}
for argumento in "$@"; do
    case "$argumento" in
        --sin-compresion) ;; # compatibility: this is already the default
        *) echo "Usage: $0 [--sin-compresion]" >&2; exit 2 ;;
    esac
done
if [ -n "${JUEGO:-}" ]; then
    recompila=0
else
    JUEGO=$P/c64/juego_final/c64
    recompila=1
fi
case "${CONSTRUYE_JUEGO:-$recompila}" in
    1) (cd "$(dirname "$JUEGO")" && C64=1 ./construye.sh) ;;
    0) ;;
    *) echo "CONSTRUYE_JUEGO must be 0 or 1" >&2; exit 2 ;;
esac

# 1. the presentation and ending, the loader
"$PRES/construye.sh"

# 2. the stream
python3 -I "$P/c64/cinta/flujo.py" "$D/juego.prg" --juego "$JUEGO" --cargador "$G/cargador.lbl" --informe "$D/flujo.txt" \
    --sin-compresion

# 3. the disk: keep the existing one intact if any write or validation fails.
temporal=$(mktemp -d "$D/.presentacion.XXXXXX")
trap 'rm -f -- "$temporal/presentacion.d64"; rmdir -- "$temporal"' EXIT
c1541 -format "abadia64ks,ak" d64 "$temporal/presentacion.d64" -write "$G/abadia.prg" abadia \
    -write "$PRES/original/graphics/abadia.koa" abadia.koa -write "$G/text1.bin" text1.bin -write "$G/pp.bin" pp.bin \
    -write "$D/juego.prg" juego -write "$G/final.prg" final -write "$G/text2.bin" text2.bin > /dev/null
c1541 "$temporal/presentacion.d64" -list 2>/dev/null | grep -v -e '^Unit' -e '^D64' -e OPENCBM
chmod 644 "$temporal/presentacion.d64"
mv -fT -- "$temporal/presentacion.d64" "$salida"
