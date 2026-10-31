/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

/* The tables of translated functions of every group (each group file defines traducidas_<group>). */
#include "juego.h"

extern const traducida_t traducidas_base[];
extern const traducida_t traducidas_motor_iso[];
extern const traducida_t traducidas_camino[];
extern const traducida_t traducidas_personajes[];
extern const traducida_t traducidas_estado_texto[];
extern const traducida_t traducidas_objetos_sonido[];
extern const traducida_t traducidas_logica_a[];
extern const traducida_t traducidas_logica_b[];

const traducida_t *const grupos[] = {
    traducidas_base,
    traducidas_motor_iso,
    traducidas_camino,
    traducidas_personajes,
    traducidas_estado_texto,
    traducidas_objetos_sonido,
    traducidas_logica_a,
    traducidas_logica_b,
    NULL
};
