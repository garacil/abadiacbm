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

"""The presentation's test disk (presentacion.d64, construye.sh here) in VICE (x64sc, a 1541 with true drive emulation, warp) on Xvfb :99, driven through its
binary monitor only while the emulation is stopped (c64/plataforma/pruebas/vice_mb.py): the results depend on the
emulated cycles alone (VICE's random autostart delay off, its random seed fixed).  c64/presentacion/pruebas/disco_prueba/NOTAS.md;
c64/presentacion/NOTAS.md.

    prueba.py [--disco D64] [--frames N] [--sin-final] [OUTDIR]

A. The disk from BASIC's READY:
 1. LOAD"*",8,1 typed (VICE's keyboard buffer feed), "abadia" (the presentation) loaded and started: timed
    (CIA 2's timers as a 32-bit cycle counter, set while stopped); RUN.
 2. The parchment with the introduction text: the music's AY register writes (the calls of _musica_registro, with
    the interrupt count, logged in windows of ticks: a stop of the emulation each) against the CPC's own
    (data/pruebas/salida_musica_inicial/cpc_ticks.txt, made by data/pruebas/prueba_musica.sh: the Z80 simulator
    running the tape's stage) over its first 64 s, and against the player's C reference (c64/pergamino/musica.c on the
    host, data/pruebas/prueba_musica.c) with the same stop; each page, complete when the nextpage is called and at
    the text's end (cgetc), against the page model (c64/presentacion/datos.py: the bitmap's text area and its cells'
    colours); the last page is the credits.
 3. SPACE put down (a snapshot with the KEYBOARD module patched, as c64/plataforma/pruebas/prueba.py does) at the
    text's end; released when the loader starts.
 4. The loader (generado/cargador.lbl): at its start the picture on the game's screen (bitmap $E000, screen RAM
    $C000, colour RAM, VIC bank 3, $D018 = $08, multicolour bitmap mode) as abadia.koa; at the mark still intact,
    after it the side cells black; at the end of the data the 768 middle cells intact.  The load timed.
 5. principal_inicio: the whole RAM against the game's image (c64/juego_final/c64/juego.bin) over every byte the game
    needs (flujo.necesarios, the zero page and the cleared play area); then the game: its first frame (the merge
    tables rebuilt: compared with the image), frames 50 and N, whose screens must equal a second run's where the image
    is written straight into the RAM and started at principal_inicio (no loader, as c64/juego_final/vice/arranca.py).
B. That second run.
C. The ending through the game's own code: the C64 memory of the state where the game ends at 100 % at once
   (c64/presentacion/pruebas/estado_final.py: day 7, tercia, the investigation solved), written into the RAM with
   the disk attached, the CPU at principal_inicio: game_check_end, the percentage 100, plat_final, "final" loaded from
   the disk (timed), the parchment with the ending text: every page against the model, the AY writes against
   the CPC's (salida_musica_final: until its first stop) and against the host's player with this run's own stops and
   restarts; at the text's end SPACE: the parchment again with the music restarted; SPACE after 40 characters of it:
   the text ends at once and the parchment starts a third time.  (--sin-final: not run.)

Writes OUTDIR (default c64/presentacion/resultados): the pictures, vice*.log, resultados.txt.  Exits 1 when a check
fails.
"""
import os, shutil, struct, subprocess, sys, tempfile

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(D))))
PRES = os.path.join(P, "c64", "presentacion")
GEN = os.path.join(PRES, "generado")
PRUEBAS = os.path.join(P, "c64", "plataforma", "pruebas")
for x in (os.path.join(P, "c64", "cinta"), PRUEBAS, PRES, os.path.join(PRES, "pruebas")):
    sys.path.insert(0, x)
sys.dont_write_bytecode = True
import vice_mb as V                                                  # noqa: E402
import teclado_mapa as T                                             # noqa: E402
import flujo                                                         # noqa: E402
import datos as Dt                                                   # noqa: E402
import estado_final                                                  # noqa: E402

CMD_BANKS, CMD_TECLADO = 0x82, 0x72
SEG = 985248                        # PAL cycles a second
VENTANA_INICIO = 19130              # the AY writes logged: the introduction's first 64 s (the CPC log's span)
VENTANA_FINAL = 9039                # the ending's first 30 s (the CPC log's, to its first stop)
VENTANA_PASADA = 3000               # 10 s of each pass after a re-entry
fallos, lineas = [], []


def dice(texto):
    print(texto, flush=True)
    lineas.append(texto)


def ok(cond, texto):
    dice(("ok    " if cond else "FALLO ") + texto)
    if not cond:
        fallos.append(texto)


def bancos(v):
    _, c = v.orden(CMD_BANKS)
    n = struct.unpack("<H", c[:2])[0]
    out, k = {}, 2
    for _ in range(n):
        tam = c[k]
        bid = struct.unpack("<H", c[k + 1:k + 3])[0]
        nlen = c[k + 3]
        out[c[k + 4:k + 4 + nlen].decode()] = bid
        k += 1 + tam
    return out


def lee(v, banco, ini, fin):
    out = b""
    while ini <= fin:
        f = min(fin, ini + 0x3FFF)
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, ini, f, 0, banco))
        out += c[2:2 + struct.unpack("<H", c[:2])[0]]
        ini = f + 1
    return out


def teclas(v, base, nuevo, lista):
    """the machine with these C64 keys down (none: all up): a snapshot, its KEYBOARD module patched, restored"""
    v.instantanea(base)
    d = bytearray(open(base, "rb").read())
    i = d.find(b"KEYBOARD\0") + 22
    for k in range(16 + 8):
        struct.pack_into("<I", d, i + 4 * k, 0)
    for t in lista:
        col, fila = T.C64[t]
        struct.pack_into("<I", d, i + 4 * col, struct.unpack_from("<I", d, i + 4 * col)[0] | 1 << fila)
        struct.pack_into("<I", d, i + 64 + 4 * fila, struct.unpack_from("<I", d, i + 64 + 4 * fila)[0] | 1 << col)
    open(nuevo, "wb").write(d)
    v.restaura(nuevo)


def escribe(v, texto):
    """text into the KERNAL's keyboard buffer (VICE's keyboard feed)"""
    t = texto.encode("ascii")
    v.orden(CMD_TECLADO, bytes([len(t)]) + t)


def corre_hasta(v, dir, golpes=1, limite=900):
    """run until the checkpoint at dir has been hit `golpes` times (the PC is then dir)"""
    num = v.punto(dir, temporal=False)
    try:
        for _ in range(golpes):
            v.golpes.discard(num)
            v.orden(V.CMD_EXIT)
            v.s.settimeout(limite)
            while num not in v.golpes:
                v._respuesta()
            v.s.settimeout(None)
        v.para()
        pc = v.registros()[3]
        if pc != dir:
            raise RuntimeError(f"stopped at {pc:04X}, not at {dir:04X}")
    finally:
        v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", num))


class Puntos:
    """several checkpoints at once: siguiente() runs until one of them is hit and returns its address"""
    def __init__(self, v):
        self.v, self.num = v, {}

    def pon(self, dir):
        if dir not in self.num.values():
            self.num[self.v.punto(dir, temporal=False)] = dir

    def quita(self, dir):
        for n, d in list(self.num.items()):
            if d == dir:
                self.v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", n))
                del self.num[n]

    def siguiente(self, limite=900):
        v = self.v
        v.golpes.clear()
        v.orden(V.CMD_EXIT)
        v.s.settimeout(limite)
        try:
            while not v.golpes & self.num.keys():
                v._respuesta()
        finally:
            v.s.settimeout(None)
        v.para()
        pc = v.registros()[3]
        if pc not in self.num.values():
            raise RuntimeError(f"stopped at {pc:04X}, not at a checkpoint")
        return pc

    def fuera(self):
        for n in list(self.num):
            self.v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", n))
        self.num = {}


def escribe_banco(v, banco, ini, datos):
    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, ini, ini + len(datos) - 1, 0, banco) + bytes(datos))


def reloj_pon(v, io):
    """CIA 2's timers A and B cascaded: a 32-bit counter of cycles, from $FFFFFFFF down (their interrupts masked: the
    loader and the game mask CIA 2; the KERNAL's serial code uses CIA 1's timer B, not these)"""
    escribe_banco(v, io, 0xDD0E, [0x00])
    escribe_banco(v, io, 0xDD0F, [0x00])
    escribe_banco(v, io, 0xDD04, [0xFF, 0xFF, 0xFF, 0xFF])
    escribe_banco(v, io, 0xDD0F, [0x51])          # B: force load, start, counts A's underflows
    escribe_banco(v, io, 0xDD0E, [0x11])          # A: force load, start, continuous


def reloj_lee(v, io):
    t = lee(v, io, 0xDD04, 0xDD07)
    a, b = t[0] | t[1] << 8, t[2] | t[3] << 8
    return 0xFFFFFFFF - (b << 16 | a)


# ---- the parchment: its pages and its music ---------------------------------------------------------------------

ZONA = [(f, c) for f in range(2, 22) for c in range(9, 31)]     # the text area: rows 2-21, cells 9-30 (x 72-247)


def zona(v, ram):
    """the text area of the parchment (io.h: bitmap $C000, screen RAM $E000): (bitmap bytes, screen RAM bytes)"""
    bm = lee(v, ram, 0xC000, 0xDF3F)
    pant = lee(v, ram, 0xE000, 0xE3E7)
    return ({(f, c, l): bm[f * 320 + c * 8 + l] for f, c in ZONA for l in range(8)},
            {(f, c): pant[f * 40 + c] for f, c in ZONA})


def compara_pagina(base, ahora, pag, nombre):
    """the page as the model has it: the base's bitmap with the ink's bits cleared, the inked cells' colour the last
    one written there"""
    bm, pant = dict(base[0]), dict(base[1])
    for (x, y), _ in pag["tinta"].items():
        if 72 <= x < 248 and 16 <= y < 176:
            bm[(y >> 3, x >> 3, y & 7)] &= ~(0x80 >> (x & 7)) & 0xFF
    for celda, color in pag["celdas"].items():
        f, c = celda // 40, celda % 40
        if (f, c) in pant:
            pant[(f, c)] = color
    mal_b = sum(1 for k in bm if bm[k] != ahora[0][k])
    mal_c = sum(1 for k in pant if pant[k] != ahora[1][k])
    texto = pag["texto"].strip("\n").replace("\n", " / ")
    ok(mal_b == 0 and mal_c == 0, f"{nombre}: the page as the model ({mal_b} bitmap bytes, {mal_c} cell colours differ): "
       f"\"{texto[:60]}{'...' if len(texto) > 60 else ''}\"")


class Musica:
    """the AY writes the parchment makes: (tick, register, value), tick = the interrupts counted before.  Logged
    through a checkpoint at _musica_registro (each costs a stop of the emulation: ~20 ms), so only in windows of
    ticks: a window [a, b) holds every write of its ticks; and each stop's own write (musica_para's)."""
    def __init__(self, v, ram, lbl):
        self.v, self.ram, self.lbl = v, ram, lbl
        self.log, self.eventos, self.ventanas, self.paradas = [], [], [], []
        self.fin = None                            # the open window's end, or None
        self.alto, self.ultimo = 0, 0              # sid.s's count is 16 bits: its wraps (read at every stop)
        self.parada = False                        # a stop whose re-entry (the next window) is not logged yet

    def tick(self):
        """the interrupts counted (sid.s's _musica_ticks, its wraps added: it is read at least every 65536 ticks)"""
        t = lee(self.v, self.ram, self.lbl["_musica_ticks"], self.lbl["_musica_ticks"] + 1)
        t = t[0] | t[1] << 8
        if t < self.ultimo:
            self.alto += 0x10000
        self.ultimo = t
        return self.alto + t

    def abre(self, ticks):
        """a window from the next tick on; after a stop, the re-entry (musicstart's musica_reinicia, with the
        interrupt off) at the tick before it: an interrupt may come between musicstop's musica_para and its
        musica_irq_off, a tick of the player with its channels stopped, which the reference must run too"""
        a = self.tick()
        if self.parada:
            self.eventos.append(f"r{a - 1}")
            self.parada = False
        self.ventanas.append([a, a + ticks])
        self.fin = a + ticks

    def cierra(self):
        if self.fin is not None:
            self.ventanas[-1][1] = min(self.fin, self.tick())
            self.fin = None

    def apunta(self):
        """at _musica_registro: the write, if its tick is in the window (else the window is over: False)"""
        r = self.v.registros()
        t = self.tick() - 1
        if self.fin is not None and t >= self.fin:
            self.fin = None
            return False
        self.log.append((t, r[0] & 0xFF, r[1] & 0xFF))
        return True

    def corre(self, puntos, limite=1800):
        """run until one of `puntos` (Puntos, the registro's checkpoint added while a window is open), logging"""
        reg = self.lbl["_musica_registro"]
        while True:
            if self.fin is not None:
                puntos.pon(reg)
            pc = puntos.siguiente(limite=limite)
            if pc != reg:
                self.tick()                        # (the count's wraps)
                return pc
            if not self.apunta():
                puntos.quita(reg)

    def hasta_parada(self):
        """run to the stop after a key (musicstop's musica_para), the window's writes logged, and the stop's own"""
        pts = Puntos(self.v)
        pts.pon(self.lbl["_musica_para"])
        self.corre(pts)
        self.cierra()
        t = self.tick() - 1
        self.eventos.append(f"p{t}")
        self.parada = True
        self.paradas.append(t)
        pts.fuera()
        pts.pon(self.lbl["_musica_registro"])
        pts.siguiente()
        r = self.v.registros()
        self.log.append((self.tick() - 1, r[0] & 0xFF, r[1] & 0xFF))
        pts.fuera()

    def hasta(self, dir, veces=1):
        """run, logging, until dir has been reached `veces` times"""
        pts = Puntos(self.v)
        pts.pon(dir)
        while veces:
            self.corre(pts)
            veces -= 1
        pts.fuera()


def compara_cpc(mus, fichero, hasta, nombre):
    """the writes of the first window before tick `hasta` against the CPC's log (data/pruebas/salida_musica_*/
    cpc_ticks.txt, made by data/pruebas/prueba_musica.sh)"""
    cpc = [tuple(map(int, l.split())) for l in open(fichero)]
    hasta = min(hasta, cpc[-1][0] + 1, mus.ventanas[0][1])
    a = [x for x in mus.log if x[0] < hasta]
    b = [x for x in cpc if x[0] < hasta]
    ok(a == b, f"{nombre}: the AY writes of ticks 0-{hasta - 1} ({hasta / 300:.1f} s) as the CPC's: {len(a)} writes"
       + ("" if a == b else f", the first difference at {next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))}"))


def compara_anfitrion(mus, musica_c, nombre, tmp):
    """the logged writes against the player's C reference on the host (c64/pergamino/musica.c, data/pruebas/
    prueba_musica.c) given the same stops and re-entries: its writes in the windows, and its stops' writes"""
    exe = os.path.join(tmp, "prueba_musica")
    subprocess.run(["gcc", "-O1", "-I", os.path.join(P, "c64", "pergamino"), "-o", exe,
                    os.path.join(P, "..", "data", "pruebas", "prueba_musica.c"), os.path.join(P, "c64", "pergamino", "musica.c"),
                    musica_c], check=True)
    n = mus.log[-1][0] + 1
    r = subprocess.run([exe, str(n)] + mus.eventos, capture_output=True, text=True, check=True).stdout
    ref = [tuple(map(int, l.split())) for l in r.splitlines()]
    ultimas = {t: max(i for i, w in enumerate(ref) if w[0] == t) for t in mus.paradas}
    sel = [w for i, w in enumerate(ref) if any(a <= w[0] < b for a, b in mus.ventanas) or i in ultimas.values()]
    ventanas = ", ".join(f"{a}-{b - 1}" for a, b in mus.ventanas)
    ok(mus.log == sel and all(ref[i][1:] == (7, 0x3F) for i in ultimas.values()),
       f"{nombre}: the AY writes of the ticks {ventanas} and of the stops at {mus.paradas} as musica.c's given the same "
       f"stops and re-entries: {len(mus.log)} writes" + ("" if mus.log == sel else f" against {len(sel)}"))


def parchment(v, ram, io, lbl, pags, nombre, fotos, out, mus, ventana):
    """the manusrun from its musicstart to its end (cgetc): each page checked at nextpage and at the end; the AY
    writes of its first `ventana` ticks logged.  -> the cycles from musicstart to the end"""
    pts = Puntos(v)
    for d in ("_nextpage", "_cgetc"):
        pts.pon(lbl[d])
    reloj_pon(v, io)
    base_pag = zona(v, ram)
    mus.abre(ventana)
    k = 0
    while True:
        pc = mus.corre(pts)
        if pc == lbl["_nextpage"]:
            compara_pagina(base_pag, zona(v, ram), pags[k], f"{nombre}, page {k + 1}")
            if k + 1 in fotos:
                v.captura(os.path.join(out, fotos[k + 1] + ".png"))
                dice(f"      picture: {os.path.join(out, fotos[k + 1] + '.png')}")
            k += 1
            pts.pon(lbl["_kbhit"])
        elif pc == lbl["_kbhit"]:
            base_pag = zona(v, ram)                  # the new page's blank text area
            pts.quita(lbl["_kbhit"])
        elif pc == lbl["_cgetc"]:
            t = reloj_lee(v, io)
            compara_pagina(base_pag, zona(v, ram), pags[k], f"{nombre}, page {k + 1} (the last, at the text's end)")
            ok(k + 1 == len(pags), f"{nombre}: {k + 1} pages written, the model's {len(pags)}")
            pts.fuera()
            mus.cierra()
            return t


def main():
    args = sys.argv[1:]
    def opcion(n, defecto):
        if n in args:
            i = args.index(n)
            x = args[i + 1]
            del args[i:i + 2]
            return x
        return defecto
    disco = opcion("--disco", os.path.join(D, "presentacion.d64"))
    frames = int(opcion("--frames", "200"))
    sin_final = "--sin-final" in args
    if sin_final:
        args.remove("--sin-final")
    out = args[0] if args else os.path.join(PRES, "resultados")
    os.makedirs(out, exist_ok=True)
    ab = V.etiquetas(os.path.join(GEN, "abadia.lbl"))
    fi = V.etiquetas(os.path.join(GEN, "final.lbl"))
    carg = V.etiquetas(os.path.join(GEN, "cargador.lbl"))
    jdir = os.path.join(P, "c64", "juego_final", "c64")
    juego = V.etiquetas(os.path.join(jdir, "juego.lbl"))
    img = open(os.path.join(jdir, "juego.bin"), "rb").read()
    nec = flujo.necesarios(os.path.join(jdir, "juego.map"))
    gl = Dt.glifos(open(os.path.join(GEN, "pp.bin"), "rb").read())
    pags1 = Dt.paginas(open(os.path.join(GEN, "text1.bin"), "rb").read(), gl)
    pags2 = Dt.paginas(open(os.path.join(GEN, "text2.bin"), "rb").read(), gl)
    k_bm, k_pant, k_col = flujo.koala()
    tmp = tempfile.mkdtemp(prefix="disco_")
    copia = os.path.join(tmp, "abadia64ks.d64")
    shutil.copy(disco, copia)
    base, nuevo = os.path.join(tmp, "base.vsf"), os.path.join(tmp, "teclas.vsf")
    def foto(v, nombre):
        v.captura(os.path.join(out, nombre + ".png"))
        dice(f"      picture: {os.path.join(out, nombre + '.png')}")
    def pantalla_es_la_imagen(v, ram, io, nombre, celdas=range(1000), negras=()):
        """the screen memory: the picture's cells as abadia.koa, the `negras` cells' colours 0; the VIC as the game's"""
        bm, pant = lee(v, ram, 0xE000, 0xFF3F), lee(v, ram, 0xC000, 0xC3E7)
        col = bytes(x & 15 for x in lee(v, io, 0xD800, 0xDBE7))
        vic = lee(v, io, 0xD011, 0xD018)
        dd00 = lee(v, io, 0xDD00, 0xDD00)[0]
        malas = flujo.imagen_intacta(_mem(bm, pant), col, celdas=celdas)
        no_negras = [i for i in negras if pant[i] or col[i]]
        modo = vic[0] & 0x60 == 0x20 and vic[5] & 0x10 and vic[7] & 0xFE == 0x08 and dd00 & 3 == 0   # ($D018 bit 0 reads 1)
        ok(not malas and not no_negras and modo, f"{nombre}: the picture's {len(celdas)} cells as abadia.koa "
           f"({len(malas)} differ){f', the {len(negras)} side cells black ({len(no_negras)} not)' if negras else ''}; "
           f"multicolour bitmap, bank 3, $D018 = ${vic[7] & 0xFE:02X}")
    def _mem(bm, pant):
        m = bytearray(0x10000)
        m[0xE000:0xE000 + 8000] = bm
        m[0xC000:0xC000 + 1000] = pant
        return m
    lados = [i for i in range(1000) if flujo.celda_lado(i)]
    medio = [i for i in range(1000) if not flujo.celda_lado(i)]
    try:
        # ---- A. the disk ----
        with V.Vice(None, ["-sounddev", "dummy", "-warp", "-drive8type", "1541", "-drive8truedrive"], disco=copia,
                    registro=os.path.join(out, "vice.log")) as v:
            v.hasta(0xE5CD, limite=120)                 # READY: the screen editor waits for a key
            b = bancos(v)
            ram, io = b["ram"], b["io"]
            reloj_pon(v, io)
            escribe(v, 'LOAD"*",8,1\rRUN\r')         # (RUN waits in the keyboard buffer while it loads)
            corre_hasta(v, ab["_main"], limite=900)
            t0 = reloj_lee(v, io)
            dice(f"      \"abadia\" ({os.path.getsize(os.path.join(GEN, 'abadia.prg'))} bytes) loaded by the KERNAL and "
                 f"started: {t0} cycles = {t0 / SEG:.1f} s from LOAD typed to its main")
            corre_hasta(v, ab["_manusintro"], limite=900)
            t1 = reloj_lee(v, io)
            foto(v, "1_cargando")
            corre_hasta(v, ab["_musicstart"], limite=900)
            t2 = reloj_lee(v, io)
            dice(f"      abadia.koa read at {t1 / SEG:.1f} s, the parchment (text1.bin, pp.bin read) on the screen at "
                 f"{t2 / SEG:.1f} s")
            mus = Musica(v, ram, ab)
            tp = parchment(v, ram, io, ab, pags1, "the introduction", {1: "2_pergamino_pagina_1"}, out, mus, VENTANA_INICIO)
            dice(f"      the introduction written in {tp / SEG:.1f} s ({len(pags1)} pages; the CPC: 386 s for its 8)")
            foto(v, "3_pergamino_creditos")
            teclas(v, base, nuevo, ["SPACE"])
            mus.hasta_parada()
            corre_hasta(v, carg["inicio"])
            teclas(v, base, nuevo, [])
            mus.eventos = mus.eventos[:1]                  # (no re-entry)
            compara_cpc(mus, os.path.join(P, "..", "data", "pruebas", "salida_musica_inicial", "cpc_ticks.txt"), 1 << 30,
                        "the introduction's music")
            compara_anfitrion(mus, os.path.join(GEN, "musica_inicio.c"), "the introduction's music", tmp)
            pantalla_es_la_imagen(v, ram, io, "the loader's start")
            reloj_pon(v, io)
            corre_hasta(v, carg["segmento"])             # (the file opened: the picture on the screen for a while)
            foto(v, "4_imagen")
            corre_hasta(v, carg["negro"])
            tm = reloj_lee(v, io)
            foto(v, "5_imagen_antes_de_la_marca")
            pantalla_es_la_imagen(v, ram, io, "the mark")
            corre_hasta(v, carg["tras_negro"])
            foto(v, "6_lados_negros")
            pantalla_es_la_imagen(v, ram, io, "after the mark", medio, lados)
            corre_hasta(v, carg["fin"])
            tf = reloj_lee(v, io)
            foto(v, "7_fin_de_los_datos")
            pantalla_es_la_imagen(v, ram, io, "the end of the data", medio, lados)
            corre_hasta(v, juego["principal_inicio"])
            t4 = reloj_lee(v, io)
            foto(v, "8_salto")
            dice(f"      the load: the mark at {tm / SEG:.1f} s, the data at {tf / SEG:.1f} s, principal_inicio at {t4} "
                 f"cycles = {t4 / SEG:.1f} s (the CPC tape's block: 501.8 s)")
            m = lee(v, ram, 0x0000, 0xFFFF)
            vistos = malos = 0
            difs = []
            for a in range(2, 0x10000):
                if nec[a] or a < 0x100 or flujo.area_juego(a):
                    vistos += 1
                    if m[a] != img[a]:
                        malos += 1
                        if len(difs) < 16:
                            difs.append(f"{a:04X}:{m[a]:02X}/{img[a]:02X}")
            ok(malos == 0, f"principal_inicio: the RAM equals juego.bin over {vistos} bytes (the game's segments but BSS "
               f"and the merge tables, the zero page, the play area){': ' + ' '.join(difs) if difs else ''}")
            otros = sum(1 for a in range(2, 0x10000) if m[a] != img[a])
            dice(f"      bytes different from the image anywhere: {otros} (the stack page, the screen RAM, BSS, the merge "
                 f"tables where the loader was...: all outside what the game needs)")
            corre_hasta(v, juego["game_input_and_mirror"])
            m = lee(v, ram, 0x0000, 0xFFFF)
            tablas = [(0xBB00, 0xC000), (0xC400, 0xC800), (0xEA06, 0xEA16)]
            mal_t = sum(1 for i, j in tablas for a in range(i, j) if m[a] != img[a])
            ok(mal_t == 0, f"the game's first frame: the 2320 bytes of the merge tables rebuilt as in the image ({mal_t} differ)")
            foto(v, "9_juego_frame_1")
            corre_hasta(v, juego["game_input_and_mirror"], golpes=49)
            vistas = {50: v.foto()[3]}
            corre_hasta(v, juego["game_input_and_mirror"], golpes=frames - 50)
            foto(v, f"10_juego_frame_{frames}")
            vistas[frames] = v.foto()[3]
        # ---- B. the reference: the image written into the RAM, started at principal_inicio ----
        with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=os.path.join(out, "vice_inyectado.log")) as v:
            v.hasta(0xE5CD, limite=120)
            ram = bancos(v)["ram"]
            for i in range(0x0002, 0x10000, 0x1000):
                escribe_banco(v, ram, i, img[i:min(0x10000, i + 0x1000)])
            v.pon_pc(juego["principal_inicio"])
            corre_hasta(v, juego["game_input_and_mirror"], golpes=50)
            ref = {50: v.foto()[3]}
            corre_hasta(v, juego["game_input_and_mirror"], golpes=frames - 50)
            ref[frames] = v.foto()[3]
        for n in sorted(ref):
            d = sum(1 for x, y in zip(vistas[n], ref[n]) if x != y)
            ok(d == 0, f"frame {n}: the screen as with the image written straight into the RAM ({d} pixels differ)")
        # ---- C. the ending through the game's own code ----
        if not sin_final:
            estado = estado_final.memoria(os.path.join(tmp, "estado_final.bin"))
            with V.Vice(None, ["-sounddev", "dummy", "-warp", "-drive8type", "1541", "-drive8truedrive"], disco=copia,
                        registro=os.path.join(out, "vice_final.log")) as v:
                v.hasta(0xE5CD, limite=120)
                b = bancos(v)
                ram, io = b["ram"], b["io"]
                for i in range(0x0002, 0x10000, 0x1000):
                    escribe_banco(v, ram, i, estado[i:min(0x10000, i + 0x1000)])
                v.pon_pc(juego["principal_inicio"])
                corre_hasta(v, juego["game_check_end"], limite=900)
                corre_hasta(v, juego["plat_final"], limite=900)
                pct = lee(v, ram, 0x067A, 0x067C)        # D64_GAME_PERCENT_DIGITS (c64/juego_final/mapa64.tsv)
                ok(pct == b"100", f"the game from the state of day 7, tercia, investigation solved: game_check_end, the "
                   f"percentage \"{pct.decode('latin-1')}\", plat_final (\"CARGANDO EL FINAL\")")
                reloj_pon(v, io)
                corre_hasta(v, 0xFF84, limite=900)      # IOINIT: plat_final's stub calls it once "final" is loaded
                t = reloj_lee(v, io)                     # (and it stops CIA 2's timers: the clock is set again below)
                foto(v, "11_juego_100")                  # (the game's screen stays while "final" loads)
                dice(f"      \"final\" ({os.path.getsize(os.path.join(GEN, 'final.prg'))} bytes) loaded by plat_final's KERNAL "
                     f"LOAD in {t / SEG:.1f} s (the CPC tape's ending block: 82.4 s)")
                corre_hasta(v, fi["_main"], limite=900)
                reloj_pon(v, io)
                corre_hasta(v, fi["_musicstart"], limite=900)
                t2 = reloj_lee(v, io)
                dice(f"      the ending's parchment (text2.bin and pp.bin read by the code) on the screen {t2 / SEG:.1f} s "
                     f"after its main; {(t + t2) / SEG:.1f} s after plat_final")
                mus = Musica(v, ram, fi)
                tp = parchment(v, ram, io, fi, pags2, "the ending", {1: "12_final_pagina_1"}, out, mus, VENTANA_FINAL)
                dice(f"      the ending written in {tp / SEG:.1f} s ({len(pags2)} pages; the CPC: 680 s)")
                foto(v, "13_final_ultima_pagina")
                # SPACE at its end: the music stops, the parchment again
                teclas(v, base, nuevo, ["SPACE"])
                mus.hasta_parada()
                teclas(v, base, nuevo, [])
                corre_hasta(v, fi["_musicstart"], limite=900)
                # the second pass: SPACE after 40 characters (manusrun's kbhit, once a character)
                mus.abre(VENTANA_PASADA)
                mus.hasta(fi["_kbhit"], 40)
                foto(v, "14_final_segunda_pasada")
                teclas(v, base, nuevo, ["SPACE"])
                pts = Puntos(v)                      # the characters manusrun still starts before it ends: its kbhit
                pts.pon(fi["_kbhit"])                # calls until final.c's cgetc
                pts.pon(fi["_cgetc"])
                tarde = 0
                while mus.corre(pts) == fi["_kbhit"]:
                    tarde += 1
                pts.fuera()
                ok(tarde <= 2, f"SPACE while the ending writes (its second pass, after 40 characters): its text ends at "
                   f"once (manusrun tested the keyboard {tarde} more times, i.e. {max(0, tarde - 1)} more characters: the "
                   f"key is seen at the KERNAL's next scan, every fifth tick) and final.c's cgetc takes the key")
                mus.hasta_parada()
                teclas(v, base, nuevo, [])
                corre_hasta(v, fi["_musicstart"], limite=900)
                mus.abre(VENTANA_PASADA)
                mus.hasta(fi["_nextpage"])
                mus.cierra()
                foto(v, "15_final_tercera_pasada")
                ok(len(mus.paradas) == 2, f"the music stopped and restarted twice (after the ticks {mus.paradas})")
                compara_cpc(mus, os.path.join(P, "..", "data", "pruebas", "salida_musica_final", "cpc_ticks.txt"), 9039,
                            "the ending's music, until the CPC log's first stop")
                compara_anfitrion(mus, os.path.join(GEN, "musica_final.c"), "the ending's music", tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    dice(f"{len(fallos)} checks failed" if fallos else "all checks passed")
    open(os.path.join(out, "resultados.txt"), "w").write("\n".join(lineas) + "\n")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
