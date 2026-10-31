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
