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

# The groups' own checks of what the exploration sessions never reach (forced paths, synthetic calls,
# every room...), each through the hybrid host's shadow check.  Exit 1 if any reports a difference.
set -uo pipefail
J=$(dirname "$(realpath "$0")")
fallo=0
for t in pruebas_motor_iso/prueba.sh pruebas_camino/forzado.sh pruebas_personajes/caminos.sh pruebas_estado_texto/sintetica.sh pruebas_logica_a/prueba_unidad.sh pruebas_principal/sintetica.sh; do
    echo "== $t"
    bash "$J/$t" 2>&1 | tail -6 || true
    [ "${PIPESTATUS[0]}" -eq 0 ] || fallo=1
done
exit $fallo
