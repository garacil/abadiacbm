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

# resultados.tsv of the integrated build: the groups' declarations merged (tools/resultados64.py).
# The sources are named in their group's workspace (their owner); !file: a group's file left out of the build.
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
cd "$D/.."
python3 -I "$P/../tools/resultados64.py" --cambia="$D/resultados_integra.tsv" "$D/resultados.tsv" \
    juego_camino/camino.s juego_motor_iso/motor_iso.s juego_motor_iso/motor_iso_spr.s.pendiente \
    juego_logica_a/logica_a.s juego_logica_a/logica_a_cam.s juego_logica_a/logica_a_spr.s \
    juego_personajes/personajes.s juego_estado_texto/estado_texto.s '!juego_estado_texto/estado_texto_tabla.s' \
    juego_logica_b/logica_b.s juego_logica_b/logica_b_guiones.s juego_objetos_sonido/objetos_sonido.s \
    -- juego_motor_iso juego_camino juego_personajes juego_estado_texto juego_objetos_sonido juego_logica_a juego_logica_b
