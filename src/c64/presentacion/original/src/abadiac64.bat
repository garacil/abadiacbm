REM abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
REM
REM Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
REM
REM This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
REM Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
REM option) any later version.
REM
REM This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
REM implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
REM for more details.
REM
REM You should have received a copy of the GNU General Public License along with this program.  If not, see
REM <https://www.gnu.org/licenses/>.

cl65 --register-vars -Cl -Ois -t c64 io.c manuscrito.c abadia.c -C c64.cfg -o bin/c64/abadia.prg 
