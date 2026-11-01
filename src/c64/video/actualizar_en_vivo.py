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

"""Run inside a session that is playing (sesion*.py --actualizar-piloto PID: sys.remote_exec): Pilot.follow taken
again from piloto.py, compiled alone with the running module's own globals (nothing else of the module runs again),
and the constants it reads; the next call of follow() uses it."""
import ast
import sys

mod = sys.modules["piloto"]
arbol = ast.parse(open(mod.__file__, encoding="utf-8").read())
clase = next(n for n in arbol.body if isinstance(n, ast.ClassDef) and n.name == "Pilot")
funcion = next(n for n in clase.body if isinstance(n, ast.FunctionDef) and n.name == "follow")
nuevas = {}
exec(compile(ast.Module(body=[funcion], type_ignores=[]), mod.__file__, "exec"), mod.__dict__, nuevas)
for n in arbol.body:                    # the module's constants (VAIVEN...), the assignments of plain values only
    if isinstance(n, ast.Assign) and isinstance(n.value, ast.Constant) and len(n.targets) == 1 \
            and isinstance(n.targets[0], ast.Name) and n.targets[0].id.isupper():
        setattr(mod, n.targets[0].id, n.value.value)
mod.Pilot.follow = nuevas["follow"]
print("Piloto actualizado en vivo: follow (el vaivén del seguido)", flush=True)
