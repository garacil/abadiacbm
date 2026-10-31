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

/* The music player of the CPC 64 KiB version's first stage (musica.c). */
#ifndef MUSICA_H
#define MUSICA_H

extern unsigned char ay[16];                /* the sound chip's registers as written */
extern unsigned char ay_cambio;

void musica_inicia(const unsigned char *musica, unsigned int longitud, const unsigned char *estado);
void musica_reinicia(void);                 /* the parchment entered again */
void musica_tick(void);                     /* one 300 Hz interrupt */
void musica_para(void);

/* called for every register write, in the CPC's order (the platform's sound, or a test log) */
void musica_registro(unsigned char reg, unsigned char valor);

#endif
