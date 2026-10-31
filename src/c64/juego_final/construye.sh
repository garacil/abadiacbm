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

# The 6502 game for the hybrid host's checks: juego.bin (the 64 KiB image from $0000: zero page, data, code from
# $0800) and juego.lbl (ld65's VICE label file: the routines' addresses; with PERFIL=1 also juego_todo.lbl,
# every label, the local ones too, for perfil64.py); with C64=1 the C64's game in c64/
# (the same image with the real platform layer, principal.s without its check hooks; FINAL is implied).
#   mapa64.py   bloques64.tsv + data/c64graf/graficos64.tsv -> mapa64.tsv, mapa64.inc (the memory map)
#   punteros64.py (tools)                       -> punteros64.tsv (the pointer fields)
#   datos64.py  the map, the pointers, the tape image, the converted graphics -> datos64.s, juego.cfg,
#               conversion64.tsv
#   stubs64.py  stubs64.s, stubs64.tsv: a trap for each function called but not translated (FINAL=1: none allowed)
# The graphics (data/c64graf) are made by tools/c64_graficos.py; the inventory checks by
# tools/inventario64.py (c64/NOTAS_MAPA.md).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
cd "$D"
# Regenerate the character retouches as well as the other converted assets.
# Editing retoques64.txt must be sufficient for the ordinary disk build.
RAM=$P/../data/cpc64/juego/ram.bin; GRAF=$P/../data/c64graf
if [ "${IDIOMA:-es}" = en ]; then
    # English (only on the tape: CINTA=1): the CPC image with the English texts and its graphics
    # (c64/ingles/datos.sh), the code's English strings (-D INGLES); the same layout as the Spanish image
    { [ -n "${CINTA:-}" ] || [ -n "${C128:-}" ] || [ -n "${P500:-}" ] || [ -n "${DISCO:-}" ]; } && [ -n "${C64:-}" ] || { echo "construye.sh: IDIOMA=en needs C64=1 and CINTA=1, DISCO=1, C128=1 or P500=1" >&2; exit 1; }
    RAM=$P/c64/ingles/generado/ram_en.bin; GRAF=$P/c64/ingles/generado/c64graf
    export C64_RAM=$RAM C64_GRAF=$GRAF
fi
# the generated files (mapa64.tsv/.inc, punteros64.tsv, datos64.s, juego.cfg, stubs64.s) next to the sources, or for
# the C128 (C128=1, milestone H10) in c128/ with its own map (C64_MAQUINA=c128: mapa64.py keeps $FF00-$FF04, the
# MMU's registers, free); mapa.inc picks the map
GEN=$D
# the P500 (P500=1, the CBM-II 510: doc/referencias/p500.md) as the C128's full game, in p500/ with its own map
# (C64_MAQUINA=p500: mapa64.py also keeps the bytes of the KERNAL's cross-bank return path free)
if [ -n "${C128:-}" ] || [ -n "${P500:-}" ]; then
    [ -n "${C64:-}" ] && [ -z "${CINTA:-}" ] || { echo "construye.sh: C128=1 or P500=1 needs C64=1 and no CINTA" >&2; exit 1; }
    MAQ=c128; [ -n "${P500:-}" ] && MAQ=p500
    GEN=$D/$MAQ; [ "${IDIOMA:-es}" = en ] && GEN=$D/${MAQ}_en
    mkdir -p "$GEN"; export C64_MAQUINA=$MAQ
    python3 -I "$P/c64/disco128/ave128.py" "$GEN" > /dev/null      # the Ave Maria: ave.bin, ave128.inc
    # the graphics as the C64's but the heads (c64_graficos.py --c128: the hires heads' black for its hardware
    # sprites, cabezas128.s), in their own directory; and the full game of the PC (abadia128ks, data/completo/
    # PLAN.md): its map blocks (tools/datos128.py, kept in data/completo/datos) and its 256 tiles
    # (--completo: the 64 KiB game's C64 graphic for every tile it shares, data/completo/baldosas128.tsv)
    GRAF=${GRAF}128; export C64_GRAF=$GRAF; GRAF_OPC="--c128 --completo"
    export C64_COMPLETO=$P/../data/completo/datos
fi
python3 -I "$P/../tools/c64_graficos.py" "$RAM" "$GRAF" ${GRAF_OPC:-} > /dev/null
python3 -I mapa64.py "$GEN" > /dev/null
python3 -I "$P/../tools/punteros64.py" "$GEN" > /dev/null    # into this build's directory
python3 -I datos64.py "$GEN" > /dev/null
python3 -I stubs64.py "$GEN" ${FINAL:+--final} ${C64:+--final} > /dev/null     # stubs: functions not translated yet (traps in the host)
objs=()
if [ -z "${C64:-}" ]; then
    # the checked build: the platform's mirrors (plataforma_prueba.s) and principal.s's hooks (-D PRUEBA)
    for s in *.s; do "$B/ca65" -D PRUEBA -o "${s%.s}.o" "$s"; objs+=("${s%.s}.o"); done
    "$B/ld65" -C juego.cfg -o juego.bin -Ln juego.lbl -m juego.map "${objs[@]}"
    if [ -n "${PERFIL:-}" ]; then
        # every label, the local ones too (ca65 -g), for perfil64.py: a second link in perfil/, the same image
        mkdir -p perfil; pobjs=()
        for s in *.s; do "$B/ca65" -g -D PRUEBA -o "perfil/${s%.s}.o" "$s"; pobjs+=("perfil/${s%.s}.o"); done
        "$B/ld65" -C juego.cfg -o perfil/juego.bin -Ln juego_todo.lbl "${pobjs[@]}"
        cmp -s juego.bin perfil/juego.bin || { echo "construye.sh: the -g image differs" >&2; exit 1; }
    fi
else
    # C64=1: the C64's game in c64/ (juego.bin, juego.lbl, juego.map): the real platform (c64/plataforma), no
    # stubs, no hooks.  CINTA=1: the tape's (c64/cinta: -D CINTA, its options and messages) in c64cinta/, in
    # English (IDIOMA=en, -D INGLES) in c64cinta_en/
    SAL=c64; DEF=()
    if [ -n "${C128:-}" ]; then
        # the Commodore 128 in its own mode (milestone H10; doc/referencias/c128.md): the MMU's $FF00 instead of the
        # 6510's port (MEMCFG, zp.inc / plat64.inc), in c128/
        SAL=c128; DEF=(-D C128 -D COMPLETO -D VELOZ)
        if [ "${IDIOMA:-es}" = en ]; then SAL=c128_en; DEF+=(-D INGLES); fi
    fi
    if [ -n "${P500:-}" ]; then
        # the P500: the C128's game (-D C128: the second bank's data, the hires heads, the Ave Maria) on the CBM-II
        # platform (-D P500: the 6509's indirect bank register for bank 1 and the I/O of bank 15), in p500/
        SAL=p500; DEF=(-D C128 -D P500 -D COMPLETO -D VELOZ)
        if [ "${IDIOMA:-es}" = en ]; then SAL=p500_en; DEF+=(-D INGLES); fi
    fi
    if [ -n "${CINTA:-}" ]; then
        SAL=c64cinta; DEF=(-D CINTA)
        if [ "${IDIOMA:-es}" = en ]; then SAL=c64cinta_en; DEF+=(-D INGLES); fi
    fi
    if [ -n "${DISCO:-}" ]; then
        # the C64's disk with the tape's menu (c64/disco64): the options, both languages, the ending from the disk
        SAL=c64disco; DEF=(-D DISCO)
        if [ "${IDIOMA:-es}" = en ]; then SAL=c64disco_en; DEF+=(-D INGLES); fi
    fi
    mkdir -p "$SAL"
    fuentes=()
    for s in *.s; do case "$s" in plataforma_prueba.s|plat_aleatorio_prueba.s|stubs64.s|datos64.s) ;; *) fuentes+=("$s") ;; esac; done
    fuentes+=("$GEN/datos64.s")
    if [ -n "${P500:-}" ]; then
        # the P500's platform: its own screen inks, keyboard, interrupt and KERNAL (bank 15), psg.s with -D P500
        for s in tinta500 teclado500 psg interrupcion500 p500; do fuentes+=("../plataforma/$s.s"); done
    else
        for s in tinta teclado psg interrupcion; do fuentes+=("../plataforma/$s.s"); done
        # the disk: disco.s (the C64's KERNAL), or on the C128 c128.s (its KERNAL, from the common RAM; and block 1)
        if [ -n "${C128:-}" ]; then fuentes+=("../plataforma/c128.s"); else fuentes+=("../plataforma/disco.s"); fi
    fi
    for s in "${fuentes[@]}"; do
        o=$SAL/$(basename "${s%.s}").o
        "$B/ca65" "${DEF[@]}" -D JUEGO -I "$D" -I "$D/../plataforma" -I "$GEN" -o "$o" "$s"; objs+=("$o")
    done
    "$B/ld65" -C "$GEN/juego.cfg" -o "$SAL/juego.bin" -Ln "$SAL/juego.lbl" -m "$SAL/juego.map" "${objs[@]}"
fi
