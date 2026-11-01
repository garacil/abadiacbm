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

"""Carga inequívoca del piloto activo, conservando la identidad del módulo."""
import importlib.util
from pathlib import Path
import sys


def load_pilot():
    source = Path(__file__).resolve().with_name("piloto.py")
    spec = importlib.util.spec_from_file_location("piloto", source)
    module = sys.modules.get("piloto")
    if module is None:
        module = importlib.util.module_from_spec(spec)
        sys.modules["piloto"] = module
    module.__file__, module.__spec__, module.__loader__ = str(source), spec, spec.loader
    spec.loader.exec_module(module)
    if Path(module.Pilot.step.__code__.co_filename).resolve() != source:
        raise RuntimeError("Se ha cargado otra copia del piloto")
    return module
