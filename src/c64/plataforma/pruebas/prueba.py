#!/usr/bin/env python3
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

"""The C64 platform layer's tests (c64/plataforma/README.md): each feature's test program built with ca65/ld65
and run in VICE (x64sc) on Xvfb :99 through its binary monitor (vice_mb.py), deterministic.

    prueba.py [tinta] [teclado] [psg] [sid] [irq] [disco] [tamanos]     (no argument: all)

Builds into obj/, writes pictures, recordings and logs into resultados/; prints one line per check and exits
with 1 when one fails.
"""
import os, struct, subprocess, sys, wave

AQUI = os.path.dirname(os.path.abspath(__file__))
PLAT = os.path.dirname(AQUI)
P = os.path.dirname(os.path.dirname(PLAT))
while not os.path.isdir(os.path.join(P, "..", "tools", "terceros", "cc65")):  # (a copy of the platform deeper in c64/)
    if P == os.path.dirname(P):
        raise SystemExit("prueba.py: no project (tools/terceros/cc65) above " + PLAT)
    P = os.path.dirname(P)
B = os.path.join(P, "..", "tools", "terceros", "cc65", "bin")
OBJ = os.path.join(AQUI, "obj")
RES = os.path.join(AQUI, "resultados")
sys.dont_write_bytecode = True
sys.path.insert(0, AQUI)
import vice_mb                                         # noqa: E402

MODULOS = ["tinta", "teclado", "psg", "interrupcion", "disco"]
fallos = []


def ok(cond, texto):
    print(("ok    " if cond else "FALLO ") + texto, flush=True)
    if not cond:
        fallos.append(texto)


def ca65(fuente, obj, *defs):
    subprocess.run([os.path.join(B, "ca65"), "-I", PLAT, "-I", os.path.join(P, "c64", "juego"), "-I", OBJ, "--bin-include-dir", OBJ,
                    *[f"-D{d}" for d in defs], "-o", obj, fuente], check=True)


def construye(nombre, *defs):
    """the test program t_<nombre>.s with the whole platform layer: obj/<nombre>.prg, .lbl, .map"""
    os.makedirs(OBJ, exist_ok=True)
    objs = []
    for m in MODULOS:
        o = os.path.join(OBJ, m + ".o")
        ca65(os.path.join(PLAT, m + ".s"), o)
        objs.append(o)
    ca65(os.path.join(AQUI, "cabecera.s"), os.path.join(OBJ, "cabecera.o"))
    ca65(os.path.join(AQUI, f"t_{nombre}.s"), os.path.join(OBJ, f"t_{nombre}.o"), *defs)
    base = os.path.join(OBJ, nombre)
    subprocess.run([os.path.join(B, "ld65"), "-C", os.path.join(AQUI, "pruebas.cfg"), "-o", base + ".prg",
                    "-Ln", base + ".lbl", "-m", base + ".map", os.path.join(OBJ, "cabecera.o"),
                    os.path.join(OBJ, f"t_{nombre}.o"), *objs], check=True)
    return base + ".prg", vice_mb.etiquetas(base + ".lbl")


def vice(prg, *opciones, disco=None, nombre="vice"):
    os.makedirs(RES, exist_ok=True)
    return vice_mb.Vice(prg, ["-sounddev", "dummy", "-warp", *opciones], disco=disco,
                        registro=os.path.join(RES, nombre + ".log"))


# ---------------------------------------------------------------------------------------------- plat_tinta

def prueba_tinta():
    os.makedirs(OBJ, exist_ok=True)
    subprocess.run([sys.executable, "-I", os.path.join(AQUI, "pantalla_prueba.py"), os.path.join(OBJ, "sala_mapa.bin")],
                   check=True)
    prg, e = construye("tinta")
    fotos = {}
    with vice(prg, nombre="tinta") as v:
        for b in ("negra", "dia", "noche", "prueba"):
            v.hasta(e["b_" + b])
            ancho, alto, rgb, idx = v.foto()
            vice_mb.png(os.path.join(RES, f"tinta_{b}.png"), ancho, alto, rgb)
            fotos[b] = (ancho, alto, idx)
            v.pasa(e["b_" + b])
        v.hasta(e["b_ciclos"])
        c = v.lee(e["ciclos"], e["ciclos"] + 15)
    ciclos = [c[2 * i] | c[2 * i + 1] << 8 for i in range(8)]
    base = ciclos[7] - 12                        # the measure's own cost (a JSR to an RTS is 12 cycles)
    nombres = ["pen 0", "pen 1", "pen 2", "pen 3", "border", "pen 4", "plat_crtc"]
    for n, k in zip(nombres, ciclos):
        print(f"      {n}: {k - base} cycles (JSR + routine + RTS)")
    ok(all(k - base < 5000 for k in ciclos[:3]), "plat_tinta fills a pen in under 5000 cycles")
    # where the 320 x 200 picture is: the test palette's border is green (5), its background red (2)
    ancho, alto, idx = fotos["prueba"]
    def tramo(valores):                          # the first run of non-green
        i = next(k for k, c in enumerate(valores) if c != 5)
        j = next((k for k in range(i, len(valores)) if valores[k] == 5), len(valores))
        return i, j - i
    y0, alto_v = tramo([idx[y * ancho + ancho // 2] for y in range(alto)])
    x0, ancho_v = tramo([idx[(alto // 2) * ancho + x] for x in range(ancho)])
    ok((ancho_v, alto_v) == (320, 200), f"the display window is {ancho_v} x {alto_v} at ({x0}, {y0}) of the {ancho} x {alto} picture")
    # every palette: the game's cells show only its four colours, the rest of the screen is black
    paletas = {"negra": (0, 0, 0, 0, 0), "dia": (0, 7, 8, 3, 0), "noche": (0, 12, 4, 6, 0)}
    for b, (p3, p2, p1, p0, borde) in paletas.items():
        ancho, alto, idx = fotos[b]
        dentro, fuera = set(), set()
        for y in range(alto):
            for x in range(ancho):
                juego = y0 <= y < y0 + 192 and x0 + 32 <= x < x0 + 288
                (dentro if juego else fuera).add(idx[y * ancho + x])
        ok(dentro == {p3, p2, p1, p0} and fuera == {0},
           f"palette {b}: the game's cells in {sorted(dentro)}, the rest {sorted(fuera)} (black)")
    # the test palette: pen 3 red shows the invisible bytes' 00 pairs in red, the border green
    ancho, alto, idx = fotos["prueba"]
    fuera_rojo = sum(1 for y in range(y0, y0 + 200) for x in range(x0, x0 + 320)
                     if not (y < y0 + 192 and x0 + 32 <= x < x0 + 288) and idx[y * ancho + x] == 2)
    ok(fuera_rojo > 0 and idx[0] == 5, f"pen 3 -> $D021 ({fuera_rojo} red pixels outside the game's cells), border -> $D020")


# ---------------------------------------------------------------------------------------------- plat_teclado_fila

def entradas(base, nuevo, teclas, joy):
    """a copy of the VICE snapshot `base` with these C64 keys down and joystick port 2 at joy: the KEYBOARD
    module (keyarr[16], rev_keyarr[8]: 32-bit words, keyarr[column] bit row) and the joystick module (in VICE
    3.10's C64 snapshot the module JOYSTICK0 holds control port 2's value, as measured)"""
    import teclado_mapa as T
    d = bytearray(open(base, "rb").read())
    i = d.find(b"KEYBOARD\0") + 22
    for t in teclas:
        col, fila = T.C64[t]
        k = i + 4 * col
        struct.pack_into("<I", d, k, struct.unpack_from("<I", d, k)[0] | 1 << fila)
        k = i + 64 + 4 * fila
        struct.pack_into("<I", d, k, struct.unpack_from("<I", d, k)[0] | 1 << col)
    j = d.find(b"JOYSTICK0\0") + 22
    struct.pack_into("<H", d, j, joy)
    open(nuevo, "wb").write(d)


def prueba_teclado():
    import teclado_mapa as T
    prg, e = construye("teclado")
    # (three keys at the corners of a rectangle of the C64 matrix make the fourth corner read as down, a
    # property of the hardware: LEFT SHIFT + CRSR DOWN + CRSR RIGHT reads A too; the cases avoid it)
    casos = [((), 0)] + [((t,), 0) for t in T.C64]
    casos += [(("LEFT SHIFT", "CRSR DOWN"), 0), (("RIGHT SHIFT", "CRSR RIGHT"), 0),
              (("RIGHT SHIFT", "CRSR DOWN", "CRSR RIGHT"), 0), (("Q", "R"), 0), (("CTRL", "LEFT ARROW"), 0),
              (("RUN/STOP", "SPACE"), 0), (("3", "S"), 0), (("0", "L"), 0)]
    casos += [((), 1 << b) for b in range(5)] + [((), 0x11), ((), 0x1F)]
    casos += [(("SPACE",), 0x01), (("R",), 0x04), (("Q", "R"), 0x04), (("CRSR DOWN",), 0x01), (("A",), 0x10)]
    casos += [(("Q", "O"), 0), (("Q", "P"), 0), (("Q", "A"), 0), (("Q", "P", "SPACE"), 0), (("O", "P"), 0),
              (("Q", "R", "P"), 0), (("LEFT SHIFT", "A"), 0), (("Q",), 0x04), (("RIGHT SHIFT", "Q"), 0)]
    base, nuevo = os.path.join(OBJ, "teclado_base.vsf"), os.path.join(OBJ, "teclado_caso.vsf")
    malos = 0
    with vice(prg, nombre="teclado") as v:
        v.hasta(e["b_lee"])
        v.instantanea(base)
        for teclas, joy in casos:
            entradas(base, nuevo, teclas, joy)
            v.restaura(nuevo)
            v.pasa(e["b_lee"])
            v.hasta(e["b_lee"])
            filas = list(v.lee(e["leidas"], e["leidas"] + 9))
            ranura = chr(v.lee(e["ranura"], e["ranura"])[0])
            esp, esp_ranura = T.esperado(teclas, joy)
            if (filas, ranura) != (esp, esp_ranura):
                malos += 1
                print(f"      {'+'.join(teclas) or '-'} joy {joy:02X}: " + " ".join(f"{x:02X}" for x in filas)
                      + f" slot {ranura}; expected " + " ".join(f"{x:02X}" for x in esp) + f" slot {esp_ranura}")
    ok(malos == 0, f"plat_teclado_fila: {len(casos) - malos} of {len(casos)} key / joystick cases as TECLADO.md "
       "(every C64 key alone, SHIFT + cursors, the joystick, joystick + keys, digits -> slot)")


# ---------------------------------------------------------------------------------------------- plat_psg

def vice_graba(prg, wav, ciclos):
    """run prg in VICE in real time for `ciclos` cycles, the sound to wav (VICE's wav sound device: it does not
    record in warp mode; it starts at a moment of the host's, so two recordings differ by a few milliseconds of
    offset and their resampling phase: the comparisons align on the first note)"""
    import tempfile, shutil
    casa = tempfile.mkdtemp(prefix="vice_rec_")
    os.makedirs(os.path.join(casa, ".local/state/vice"))
    os.makedirs(os.path.join(casa, "xdg"), mode=0o700)
    entorno = dict(os.environ, HOME=casa, XDG_RUNTIME_DIR=os.path.join(casa, "xdg"), DISPLAY=":99")
    with open(wav + ".log", "w") as reg:
        subprocess.run(["x64sc", "-default", "-seed", "64", "+autostart-delay-random", "-sounddev", "wav", "-soundarg", wav, "-autostart", prg,
                        "-autostartprgmode", "1", "-limitcycles", str(ciclos)], env=entorno, stdout=reg,
                       stderr=subprocess.STDOUT, timeout=900)
    shutil.rmtree(casa, ignore_errors=True)


def compara(log, wav, hz, ref=None, salta=0.0):
    orden = [sys.executable, "-I", os.path.join(P, "..", "tools", "compara_audio.py"), log, wav,
             "--hz", str(hz), "--salta", str(salta)] + (["--referencia", ref] if ref else [])
    out = subprocess.run(orden, capture_output=True, text=True, check=True).stdout
    for linea in out.splitlines():
        print("      " + linea)
    def pct(clave):
        for linea in out.splitlines():
            if clave in linea:
                a, b = linea.split(" of ")[0], linea.split(" of ")[1].split()[0]
                return int(a) / max(1, int(b))
        return None
    corr = next((float(l.split("correlates ")[1].split()[0]) for l in out.splitlines() if "correlates" in l), None)
    return pct("CPC's notes"), pct("noise"), corr


def prueba_psg():
    import shutil
    os.makedirs(OBJ, exist_ok=True)
    os.makedirs(RES, exist_ok=True)
    J = os.path.join(P, "juego")
    galeria = os.path.join(OBJ, "galeria_ay")
    subprocess.run(["gcc", "-std=c99", "-O2", "-DJUEGO_PURO", "-I" + J, "-o", galeria, os.path.join(AQUI, "galeria_ay.c")]
                   + sorted(os.path.join(J, f) for f in os.listdir(J) if f.startswith("f_") and f.endswith(".c"))
                   + [os.path.join(J, "funciones.c")], check=True, stderr=subprocess.DEVNULL)
    # the logs: the gallery of the game's sounds; a session of the GNU build (azar1, its first 20 s)
    subprocess.run([galeria, os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin"), os.path.join(OBJ, "galeria_ay.txt")],
                   check=True, stderr=subprocess.DEVNULL)
    xdg = os.path.join(OBJ, "xdg")
    os.makedirs(xdg, mode=0o700, exist_ok=True)
    entorno = dict(os.environ, DISPLAY=":99", XDG_RUNTIME_DIR=xdg, SDL_AUDIODRIVER="dummy")
    gnu_ay, gnu_wav = os.path.join(OBJ, "azar1_ay.txt"), os.path.join(OBJ, "azar1_gnu.wav")
    subprocess.run([os.path.join(J, "gnu", "abadia64ks-puro"), "--rapido", "--etapa", "juego", "--guion",
                    os.path.join(P, "..", "data", "cpc64", "exploracion", "azar1.txt"), "--hasta", "1500", "--ay", gnu_ay,
                    "--wav", gnu_wav], cwd=os.path.join(J, "gnu"), env=entorno, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    copia = os.path.join(OBJ, "azar1_sintesis.wav")
    subprocess.run([galeria, "--sintetiza", gnu_ay, copia], check=True)
    a, b = open(gnu_wav, "rb").read(), open(copia, "rb").read()
    n = min(len(a), len(b)) - 44
    ok(len(a) > 44 and a[44:44 + n] == b[44:44 + n],
       f"galeria_ay's synthesis = the GNU build's --wav, sample for sample ({n // 4} samples of azar1)")
    os.remove(copia)
    hz_c64 = 985248 / 3279
    for nombre, log, opciones in (("azar1", gnu_ay, ["--hasta", "6000"]), ("galeria", os.path.join(OBJ, "galeria_ay.txt"), [])):
        bin_ = os.path.join(OBJ, "secuencia.bin")
        log_c64 = os.path.join(RES, f"psg_{nombre}_ay.txt")
        r = subprocess.run([sys.executable, "-I", os.path.join(AQUI, "secuencia_ay.py"), log, bin_, "--log", log_c64]
                           + opciones, check=True, capture_output=True, text=True).stdout.strip()
        print(f"      {nombre}: {r}")
        ultimo = max(int(l.split()[0]) for l in open(log_c64))
        prg, e = construye("psg")
        shutil.copy(prg, os.path.join(OBJ, f"psg_{nombre}.prg"))
        ref = os.path.join(RES, f"psg_{nombre}_gnu.wav")
        subprocess.run([galeria, "--sintetiza", log_c64, ref], check=True)
        wav = os.path.join(RES, f"psg_{nombre}_c64.wav")
        vice_graba(os.path.join(OBJ, f"psg_{nombre}.prg"), wav, (ultimo + 900) * 3279 + 4000000)
        print(f"      the GNU synthesis against the log ({nombre}):")
        g_notas, g_ruido, _ = compara(log_c64, ref, 300)
        print(f"      the C64 (VICE) against the log ({nombre}):")
        c_notas, c_ruido, corr = compara(log_c64, wav, hz_c64, ref, salta=0.5)
        # (the measure's ceiling is the GNU synthesis's own score on the same log: two channels at once, the
        # strongest peak a harmonic... the C64 must be as good, within 3 points)
        ok(c_notas is not None and c_notas >= g_notas - 0.03, f"{nombre}: {c_notas:.1%} of the tone windows agree "
           f"(the GNU synthesis of the same log: {g_notas:.1%})")
        if g_ruido is not None:
            ok(c_ruido is not None and c_ruido >= 0.9, f"{nombre}: {c_ruido:.1%} of the noise windows sound as noise "
               f"(the GNU synthesis: {g_ruido:.1%})")
        ok(corr is not None and corr >= 0.8, f"{nombre}: the loudness correlates {corr:.3f} with the GNU synthesis")


# ---------------------------------------------------------------------------------------------- plat_psg against the AY's timing

def prueba_sid():
    """plat_psg against pruebas/psg_referencia.s (the player before the SID voicing: the AY as it is) on sim65's core
    (sid_igual.c): for every write and every tick, each voice's gate changes, and its frequency and waveform kind while
    gated, the same; A, X and the I flag kept; from memory full of $A5 the same SID writes.  Streams: every period of
    every channel with the tone on, off and with the noise, every noise period and volume; 400 000 random writes; the
    gallery (every sound of the game, galeria_ay); the GNU build's session azar1 (its first 20 s, as the psg test)."""
    import shutil, tempfile
    os.makedirs(OBJ, exist_ok=True)
    t = tempfile.mkdtemp(prefix="sid_igual_")
    try:
        nucleo = os.path.join(P, "juego", "m6502")
        for f in ("6502.c", "6502.h", "m6502.c", "m6502.h", "peripherals.h", "paravirt.h", "trace.h", "error.h"):
            shutil.copy(os.path.join(nucleo, f), t)
        shutil.copy(os.path.join(AQUI, "memoria_gancho.h"), os.path.join(t, "memory.h"))
        prog = os.path.join(t, "sid_igual")
        subprocess.run(["gcc", "-O2", "-I", t, "-o", prog, os.path.join(AQUI, "sid_igual.c"), os.path.join(t, "m6502.c"),
                        os.path.join(t, "6502.c")], check=True)
        imagenes = []
        for nombre, fuente in (("ref", os.path.join(AQUI, "psg_referencia.s")), ("nuevo", os.path.join(PLAT, "psg.s"))):
            o = os.path.join(t, nombre + ".o")
            subprocess.run([os.path.join(B, "ca65"), "-I", PLAT, "-o", o, fuente], check=True)
            subprocess.run([os.path.join(B, "ld65"), "-C", os.path.join(AQUI, "sid_igual.cfg"), "-o", os.path.join(t, nombre + ".bin"),
                            "-Ln", os.path.join(t, nombre + ".lbl"), o], check=True)
            imagenes += [os.path.join(t, nombre + ".bin"), os.path.join(t, nombre + ".lbl"), "-"]
        flujos = ["exhaustivo", "azar"]
        galeria = os.path.join(OBJ, "galeria_ay.txt")
        if not os.path.exists(galeria):
            J = os.path.join(P, "juego")
            g = os.path.join(t, "galeria_ay")
            subprocess.run(["gcc", "-std=c99", "-O2", "-DJUEGO_PURO", "-I" + J, "-o", g, os.path.join(AQUI, "galeria_ay.c")]
                           + sorted(os.path.join(J, f) for f in os.listdir(J) if f.startswith("f_") and f.endswith(".c"))
                           + [os.path.join(J, "funciones.c")], check=True, stderr=subprocess.DEVNULL)
            subprocess.run([g, os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin"), galeria], check=True,
                           stderr=subprocess.DEVNULL)
        flujos.append(galeria)
        azar1 = os.path.join(OBJ, "azar1_ay.txt")
        if os.path.exists(azar1):
            flujos.append(azar1)
        r = subprocess.run([prog, "--regs", "--a5", "plat_psg", "psg_inicio", "0", *imagenes, *flujos], capture_output=True,
                           text=True)
        for linea in r.stdout.splitlines():
            print("      " + linea)
        ok(r.returncode == 0, "plat_psg: the gates and the frequencies of the AY's notes, write for write, as the player "
           "before the SID voicing (" + ", ".join(os.path.basename(f) for f in flujos) + ")")
    finally:
        shutil.rmtree(t, ignore_errors=True)


# ---------------------------------------------------------------------------------------------- the interrupt, the cycles

CICLOS_NOMBRES = ["a bare JSR / RTS", "plat_teclado_fila row 0 (the scan, nothing down)", "plat_teclado_fila row 5",
                  "plat_psg mixer, no change", "plat_psg fine period", "plat_psg coarse, P = 1235, silent voice",
                  "plat_psg mixer: tone on (frequency, gate)", "plat_psg volume up (gate again)",
                  "plat_psg volume down", "plat_psg fine period", "plat_psg coarse, P = 95 (< 128)",
                  "plat_psg fine period", "plat_psg coarse, P = 200 (the table, odd)", "plat_psg fine period",
                  "plat_psg coarse, P = 3758 (four shifts)", "plat_psg noise period", "plat_psg mixer: tone + noise",
                  "plat_psg volume 0", "plat_psg mixer: all off", "plat_aleatorio", "plat_di", "plat_ei", "plat_modo"]


def prueba_ciclos():
    prg, e = construye("ciclos")
    with vice(prg, nombre="ciclos") as v:
        v.hasta(e["b_fin"])
        n = struct.unpack("<H", v.lee(e["interrupciones"], e["interrupciones"] + 1))[0]
        sin = struct.unpack("<I", v.lee(e["sin_irq"], e["sin_irq"] + 3))[0]
        con = struct.unpack("<I", v.lee(e["con_irq"], e["con_irq"] + 3))[0]
        m = v.lee(e["medidas"], e["medidas"] + 2 * len(CICLOS_NOMBRES) - 1)
        nmi = v.lee(e["nmi_ok"], e["nmi_ok"])[0]
    por_irq = (con - sin) / n if n else 0
    print(f"      the loop: {sin} cycles with the interrupts off, {con} on, {n} interrupts: {por_irq:.1f} cycles each")
    print(f"      (the empty sys_tick's INC / BNE: 9 cycles of them: plat_irq's own, with the IRQ sequence, the JSR"
          f" and the RTS: {por_irq - 9:.1f})")
    ok(n > 150 and 45 < por_irq - 9 < 70, f"the 300 Hz interrupt: {n} delivered, {por_irq - 9:.1f} cycles of its own each")
    ok(abs(n - con / 3279) <= 1, f"the interrupt's period: {n} in {con} cycles (the CIA's 3279 each: {con / 3279:.1f})")
    ok(nmi == 1, "an NMI (CIA 2, as the RESTORE key) returns through plat_nmi's RTI")
    base = m[0] | m[1] << 8
    for i, nombre in enumerate(CICLOS_NOMBRES[1:], 1):
        print(f"      {nombre}: {(m[2 * i] | m[2 * i + 1] << 8) - base + 12} cycles (JSR + routine + RTS)")


# ---------------------------------------------------------------------------------------------- the disk

def c1541(*args):
    return subprocess.run(["c1541", *args], capture_output=True, text=True).stdout


def prueba_disco():
    final_prg = os.path.join(P, "c64", "pergamino", "final.prg")
    disco = os.path.join(OBJ, "disco.d64")
    os.makedirs(OBJ, exist_ok=True)
    if os.path.exists(disco):
        os.remove(disco)
    c1541("-format", "abadia64ks,ak", "d64", disco, "-write", final_prg, "final")
    prg, e = construye("disco")
    with vice(prg, nombre="disco", disco=disco) as v:
        v.hasta(e["b_fin"], limite=900)
        r = v.lee(e["resultados"], e["resultados"] + 11)
    print("      results: " + " ".join(f"{x:02X}" for x in r))
    ok(r[0] == 0, "plat_disco_guarda: C = 0")
    ok(r[1] == 0 and r[3] == 0, f"the zero page $02-$FF and $0200-$03FF intact after the save ({r[1]} bytes changed) "
       f"and after the load ({r[3]})")
    ok(r[2] == 0 and r[4] == 0, f"plat_disco_carga: C = 0, the block as saved ({r[4]} bytes wrong)")
    ok(r[5] == 1, "a slot with no file: C = 1")
    ok(r[6] == 0 and r[7] == 0 and r[8] == 0, f"a save over the first (scratched first) and its load ({r[8]} bytes wrong)")
    ok(95 <= r[9] <= 125, f"the 300 Hz interrupt delivered again after the KERNAL ({r[9]} in a loop of ~330000 "
       "cycles, ~370000 with the display's stolen cycles)")
    ok(r[10] > 0xAE, f"the stack: the calls reached ${0x100 + r[10]:04X} (SP ${0x100 + r[11]:04X} at the call), above the "
       f"aside area $0100-$01AE")
    print(f"      (stack used by the calls and the KERNAL: {r[11] - r[10] + 1} bytes)")
    lista = c1541(disco, "-list")
    print("      " + lista.replace("\n", "\n      ").rstrip())
    salida = os.path.join(OBJ, "abadia64.bs3")
    if os.path.exists(salida):
        os.remove(salida)
    c1541(disco, "-read", "abadia64.bs3", salida)
    datos = open(salida, "rb").read() if os.path.exists(salida) else b""
    esperado = bytes([0xCD, 0x9C]) + bytes((0x77 + i) & 0xFF for i in range(1500))
    ok(datos == esperado, f"ABADIA64.BS3 on the disk: load address $9CCD and the 1500 bytes saved ({len(datos)} bytes)")
    # the ending: plat_final loads "FINAL" (c64/pergamino/final.prg) and runs it; VICE's own picture at a fixed
    # cycle (warp, -limitcycles, -exitscreenshot: deterministic)
    import shutil, tempfile
    prg, e = construye("disco", "SOLO_FINAL")
    copia = os.path.join(OBJ, "final.d64")
    shutil.copy(disco, copia)
    foto = os.path.join(RES, "disco_final.png")
    casa = tempfile.mkdtemp(prefix="vice_final_")
    os.makedirs(os.path.join(casa, ".local/state/vice"))
    os.makedirs(os.path.join(casa, "xdg"), mode=0o700)
    entorno = dict(os.environ, HOME=casa, XDG_RUNTIME_DIR=os.path.join(casa, "xdg"), DISPLAY=":99")
    if os.path.exists(foto):
        os.remove(foto)
    with open(os.path.join(RES, "final.log"), "w") as reg:
        subprocess.run(["x64sc", "-default", "-seed", "64", "+autostart-delay-random", "-sounddev", "dummy", "-warp", "-8", copia, "-autostart", prg,
                        "-autostartprgmode", "1", "-limitcycles", "110000000", "-exitscreenshot", foto], env=entorno,
                       stdout=reg, stderr=subprocess.STDOUT, timeout=900)
    shutil.rmtree(casa, ignore_errors=True)
    from PIL import Image
    im = Image.open(foto).convert("RGB")
    colores = {c: n for n, c in im.getcolors(1 << 24)}
    total = sum(colores.values())
    rojizo = sum(n for (r, g, b), n in colores.items() if r > 150 and g < 140 and b < 140)
    print(f"      the picture: {', '.join(f'{c}: {100 * n / total:.0f} %' for c, n in sorted(colores.items(), key=lambda x: -x[1])[:4])}")
    ok(rojizo > total * 0.3, f"plat_final: the ending parchment is on the screen (reddish {100 * rojizo / total:.0f} % of {foto})")


# ---------------------------------------------------------------------------------------------- sizes

def prueba_tamanos():
    """the bytes of each module's segments and of each routine (.proc), from ld65's map and debug file"""
    d = os.path.join(OBJ, "tamanos")
    os.makedirs(d, exist_ok=True)
    objs = []
    for m in MODULOS + ["t_ciclos"]:
        o = os.path.join(d, m + ".o")
        fuente = os.path.join(AQUI if m.startswith("t_") else PLAT, m + ".s")
        subprocess.run([os.path.join(B, "ca65"), "-g", "-I", PLAT, "-I", os.path.join(P, "c64", "juego"), "-o", o, fuente],
                       check=True)
        objs.append(o)
    ca65(os.path.join(AQUI, "cabecera.s"), os.path.join(OBJ, "cabecera.o"))
    subprocess.run([os.path.join(B, "ld65"), "-C", os.path.join(AQUI, "pruebas.cfg"), "-o", os.path.join(d, "x.prg"),
                    "--dbgfile", os.path.join(d, "x.dbg"), "-m", os.path.join(d, "x.map"), os.path.join(OBJ, "cabecera.o"),
                    *objs], check=True)
    mods = {}
    for linea in open(os.path.join(d, "x.dbg")):
        campos = dict(c.split("=", 1) for c in linea.split("\t", 1)[-1].strip().split(",") if "=" in c)
        if linea.startswith("mod"):
            mods[campos["id"]] = campos["name"].strip('"')
        elif linea.startswith("scope") and campos.get("type") == "scope":
            m = mods.get(campos["mod"], "?")
            if not m.startswith("t_"):
                print(f"      {m:16s} {campos['name'].strip(chr(34)):20s} {int(campos['size']):5d}")
    total = {}
    actual = None
    for linea in open(os.path.join(d, "x.map")):
        if linea.strip().endswith(".o:"):
            actual = linea.strip()[:-1]
        elif actual and "Size=" in linea and actual[:-2] in MODULOS:
            seg = linea.split()[0]
            n = int(linea.split("Size=")[1].split()[0], 16)
            total.setdefault(actual, {})[seg] = n
        elif linea.startswith("Segment list"):
            break
    suma = {}
    for m, segs in total.items():
        print(f"      {m:16s} " + ", ".join(f"{k} {v}" for k, v in segs.items()) + f": {sum(segs.values())}")
        for k, v in segs.items():
            suma[k] = suma.get(k, 0) + v
    print("      all              " + ", ".join(f"{k} {v}" for k, v in suma.items()) + f": {sum(suma.values())}")


# ---------------------------------------------------------------------------------------------- main

PRUEBAS = {"tamanos": prueba_tamanos, "tinta": prueba_tinta, "teclado": prueba_teclado, "ciclos": prueba_ciclos,
           "disco": prueba_disco, "psg": prueba_psg, "sid": prueba_sid}


def main():
    pedidas = sys.argv[1:] or list(PRUEBAS)
    for n in pedidas:
        print(f"== {n}", flush=True)
        PRUEBAS[n]()
    print(f"{len(fallos)} checks failed" if fallos else "all checks passed")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
