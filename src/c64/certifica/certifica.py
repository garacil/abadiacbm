"""The certification of the C64 game against the CPC 64 KiB original (the whole game
certified: the monks' behaviour of the Amstrad CPC 64 KiB original and of this C64 version the same, the objects
appearing where and when they must, every room walkable): the hybrid host runs the CPC's Z80 from a
start state with a key script, and in step with it the real C64 build in VICE (vice_cert.py) gets the same keys, the
same R and the host's interrupt model; at every frame the host compares the C64's whole RAM with the Z80's memory
through the build's own memory map (every data block of mapa64.tsv: the characters, their AI state and commands, the
objects and their holders, the doors, the clock, the scripts' variables, the sound state...), with the exclusions of
c64/juego_final/juego6502.tsv.

    certifica.py BUILD_DIR OUT NAME RAM SCRIPT TO_FRAME     (BUILD_DIR: c64/juego_final/c64, c64cinta or c128)

Writes OUT/NAME.host.txt (the host's report: per frame the first differing bytes, then its summary) and
OUT/NAME.vice.log.  The host is a private copy of juego/ with the external mode (parche_externo.py); its build tree a
copy of c64/juego_final's files as links with the build's image, labels (the host's own frame labels added at 0: the
external mode does not use them), and for a CABEZAS build its own map files, graphics (data/c64graf_hw) and pointer
table (the fields of blocks its map dropped left out)."""
import os, shutil, subprocess, sys, tempfile, time

AQUI = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(AQUI))
FINAL = os.path.join(P, "c64", "juego_final")
T = os.path.join(P, "..", "data")
POR_MAPA = ("mapa64.tsv", "mapa64.inc", "stubs64.tsv", "conversion64.tsv", "punteros64.tsv")


def arbol(juego, base):
    """the host's build tree for the C64 build juego: base/src/c64/juego (returned), base/data"""
    hw = os.path.exists(os.path.join(juego, "mapa64.tsv"))     # the build has its own map (CABEZAS, the C128)
    graf_hw = os.path.basename(juego) == "c64hw"                 # (only CABEZAS has its own graphics)
    d = os.path.join(base, "src", "c64", "juego")
    os.makedirs(d)
    os.symlink(os.path.join(P, "c64", "datos"), os.path.join(base, "src", "c64", "datos"))
    os.makedirs(os.path.join(base, "data"))
    for x in os.listdir(T):
        os.symlink(os.path.join(T, "c64graf_hw") if (graf_hw and x == "c64graf") else os.path.join(T, x),
                   os.path.join(base, "data", x))
    for x in os.listdir(FINAL):
        if x not in ("juego.bin", "juego.lbl") and not (hw and x in POR_MAPA):
            os.symlink(os.path.join(FINAL, x), os.path.join(d, x))
    if hw:
        for x in POR_MAPA:
            if x != "punteros64.tsv": os.symlink(os.path.join(juego, x), os.path.join(d, x))
        hay = {l.split("\t")[0] for l in open(os.path.join(juego, "mapa64.tsv")) if not l.startswith("#")}
        with open(os.path.join(d, "punteros64.tsv"), "w") as o:
            for l in open(os.path.join(juego, "punteros64.tsv")):
                c = l.split("\t")
                if l.startswith("#") or len(c) < 2 or c[1] in hay or not c[1].startswith("D64_"): o.write(l)
    shutil.copy(os.path.join(juego, "juego.bin"), d)
    lbl = open(os.path.join(juego, "juego.lbl")).read()
    nombres = {l.split()[2].lstrip(".") for l in lbl.splitlines() if l.startswith("al ")}
    faltan = {l.split()[2].lstrip(".") for l in open(os.path.join(FINAL, "juego.lbl")) if l.startswith("al ")} - nombres
    with open(os.path.join(d, "juego.lbl"), "w") as f:
        f.write(lbl + "".join(f"al 000000 .{n}\n" for n in sorted(faltan)))
    return d


def anfitrion():
    """the host with the external mode: a copy of juego/'s sources in anfitrion/ (git-ignored build product), patched
    by parche_externo.py and built; rebuilt when a source of juego/ is newer than it"""
    d = os.path.join(AQUI, "anfitrion")
    fuentes = [os.path.join(r, f) for r, _, fs in os.walk(os.path.join(P, "juego")) for f in fs
               if f.endswith((".c", ".h")) or f == "Makefile"]
    exe = os.path.join(d, "hibrido")
    if os.path.exists(exe) and all(os.path.getmtime(f) <= os.path.getmtime(exe) for f in fuentes):
        return exe
    shutil.rmtree(d, ignore_errors=True)
    for f in fuentes:
        r = os.path.relpath(f, os.path.join(P, "juego"))
        if r.split(os.sep)[0] in ("gnu", "puro") or r.startswith("pruebas"): continue
        os.makedirs(os.path.dirname(os.path.join(d, r)), exist_ok=True)
        shutil.copy(f, os.path.join(d, r))
    subprocess.run([sys.executable, "-I", os.path.join(AQUI, "parche_externo.py"), d], check=True)
    subprocess.run(["make", "hibrido"], cwd=d, check=True, capture_output=True)
    return exe


def main():
    juego, out, nombre, ram, guion, hasta = sys.argv[1:7]
    juego, ram, guion = os.path.abspath(juego), os.path.abspath(ram), os.path.abspath(guion)
    os.makedirs(out, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="certifica_", dir="/tmp")
    os.chmod(tmp, 0o755)
    try:
        d = arbol(juego, os.path.join(tmp, "arbol"))
        pref = os.path.join(tmp, "fifo")
        os.mkfifo(pref + ".out"); os.mkfifo(pref + ".in")
        host = anfitrion()
        conductor = subprocess.Popen([sys.executable, "-I", os.path.join(AQUI, "vice_cert.py"), juego, pref,
                                      os.path.join(out, nombre + ".vice.log")],
                                     env=dict(os.environ, DISPLAY=os.environ.get("DISPLAY", ":99")),
                                     stdout=open(os.path.join(out, nombre + ".driver.txt"), "w"), stderr=subprocess.STDOUT)
        with open(os.path.join(out, nombre + ".host.txt"), "w") as rep:
            h = subprocess.run([host, ram, os.path.join(T, "cpc64", "inicio_juego", "estado.txt"),
                                os.path.join(T, "sincrono", "puntos64.txt"), "--guion", guion, "--hasta", hasta,
                                "--limite", "50000000", "--juego6502", d, "--max-fallos", "40"],
                               cwd=os.path.join(P, "juego"), env=dict(os.environ, SOMBRA6502_EXTERNO=pref),
                               stdout=rep, stderr=subprocess.STDOUT)
        conductor.wait(timeout=60) if conductor.poll() is None else None
        print(f"{nombre}: host exit {h.returncode}; " + (open(os.path.join(out, nombre + ".host.txt")).read().strip().splitlines() or ["(no output)"])[-1])
    finally:
        if 'conductor' in dir() and conductor.poll() is None: conductor.kill()
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
