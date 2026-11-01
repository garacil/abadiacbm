# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 German Luis Aracil Boned <garacilb@gmail.com> (Spain)
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
MAPA
----

pergascr contiene la posición donde pintar cada cuadro.
pergagraf contiene el índice relativo del gráfico 
          a pintar y determina el final con 255
perga contiene los gráficos.

text1 contiene el texto inicial del pergamino. termina con 0x1a
letters contiene la definición de las letras (0x68ad - 0x727d)
pletters contiene el índice absoluto a las letras (0x678a - 0x6827)

pp.bin contiene todos los datos, menos textos:
0x0000/0x00b9 pergascr
0x00ba/0x0117 pergagraf
0x0118/0x02b5 perga
0x02b6/0x0355 pletters (absoluto, pasar a relativo)
0x0356/0x0d26 letters