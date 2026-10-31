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

"""SkoolKit's Z80 simulator without the Spectrum ROM: its pure-Python Simulator ignores writes below
4000h (the 48K ROM); the CPC has RAM there once the loader turns the ROMs off.  The class is built
from SkoolKit's own source with that test removed, so the venv is not touched."""
import importlib.util, re, skoolkit.simulator as _orig

_src = open(_orig.__file__).read()
_src = re.sub(r"(\w+) > 0x3FFF", r"True", _src)
_spec = importlib.util.spec_from_loader("z80sim_core", loader=None)
_mod = importlib.util.module_from_spec(_spec)
exec(compile(_src, _orig.__file__ + " (sin ROM)", "exec"), _mod.__dict__)
Simulator = _mod.Simulator
