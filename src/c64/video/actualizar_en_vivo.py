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
