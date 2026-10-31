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

"""The C64 build's sound in VICE, deterministic, two scenes:

  comida  day 2, sexta (data/puro/estados/ram_d2h3.bin, converted by c64/presentacion/pruebas/estado_final.py):
          "cuando anda el abad, la música en el segundo día en la comida ... se oye mal"; Guillermo stands still for
          200 frames (the music starts after 50 without a movement key: 3CEA), then walks forward for 700;
  inicio  a new game (juego.bin as it is loaded): "cuando empieza una partida si doy un paso o dos ... si paro,
          comienza la música, pero se oye mal, como distorsionada"; Guillermo walks forward on frames 10-17, then
          stands still until frame 900 (the abbot comes to him and talks meanwhile).

    pasos.py OUTDIR [comida|inicio]...      (both by default)

The game (c64/juego_final/c64, `C64=1 ./construye.sh`) is written into VICE's RAM and started at principal_inicio as
arranca.py does.  Frames are counted at game_input_and_mirror; the CPC's cursor up (key 00h: forward; QAOP's Q) is
held as the host's key scripts do it: written into the keys-down bitmap (D64_SYS_KEYS_DOWN, the new press into
D64_SYS_KEYS_PENDING) right after sys_read_keyboard has read the matrix (VICE's monitor sets no joystick the CIA
reads).  VICE stops at the frames, at the starts of sounds (s_pon) and at the footsteps (snd_play_footstep) only.
Once the game has set its vector, the interrupt goes through a counter of this test's at $0100 (INC $0120 / $0121,
JMP plat_irq: the stack page's bottom, which the game's stack never reaches: a guard at $0198-$01AF is checked).
The SID's writes come from VICE's dump sound device (every write with its cycle), aligned with this test's clock
(CIA 2 as a 32-bit cycle counter) by a write of this test's to the SID's unused register 1Fh as the clock starts.
Voice 3's envelope is computed from those writes with reSID's envelope generator (rate counter with its 15-bit
wrap, the exponential counter; VICE's monitor gives no live ENV3: it reads a stale value).  Checked:

  the ticks (both scenes): the interrupts counted against CIA 1's underflows (3279 cycles a tick), frame by frame:
    their difference may move by one (where a frame falls in a tick), a lost tick moves it for good (before
    the DI spans of chr_cmd_write_path and hud_say_now and t_frase's character inside the interrupt lost
    up to five at a time);
  the music (both): it starts on channel C once Guillermo stands; in comida, while it plays no footstep starts there
    although snd_play_footstep is called (Guillermo walks), it ends at its end (its loop byte, D64_SND_SEQ_MUSIC +
    7Eh, F9h, is FFh by then) and the footsteps come back; in inicio it plays on;
  the footsteps' level (comida): voice 3's envelope at each of the 28 ticks after a footstep's start, its RMS (the
    level; the mean and the peak shown too), against a second run of the same frames with the earlier voicing
    (psg_paso's LDA #1 patched to LDA #0: gated again at each rise): the footsteps at half, the RMS
    ratio must be 0.4-0.6.

OUTDIR: <scene>_frames.tsv, <scene>_eventos.tsv, <scene>_sid.dump, pasos_<voicing>.tsv, screenshots.
"""
import os, struct, sys, tempfile
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(os.path.dirname(D)))
sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
sys.path.insert(0, os.path.join(P, "c64", "presentacion", "pruebas"))
sys.path.insert(0, D)
import vice_mb as V                                                      # noqa: E402
import estado_final                                                      # noqa: E402
from arranca import banco, escribe_banco                                 # noqa: E402

TICK = 3279
MUESTRAS = 28                           # the footstep's note: 4 tempo units of 7 ticks
CANAL_C = 0x0263                        # D64_SND_CHANNEL_C (mapa64.inc); its state at +0Eh
TECLAS, PENDIENTES = 0x05BC, 0x05C6     # D64_SYS_KEYS_DOWN, D64_SYS_KEYS_PENDING (row 0 bit 0: cursor up)
CONTADOR = 0x0120                       # the test's interrupt counter (16 bits), its code at $0100
TESTIGO = bytes((0xA5 + 11 * i) & 0xFF for i in range(0x18))            # $0198-$01AF: the stack must not reach it
MARCA = 0xA5                            # written to the SID's register 1Fh as this test's clock starts
CMD_CHECKPOINT_TOGGLE = 0x15
ESCENAS = {"comida": (200, 900), "inicio": (10, 18, 900)}
fallos = 0


def ok(cond, texto):
    global fallos
    print(("ok    " if cond else "FALLO ") + texto, flush=True)
    if not cond:
        fallos += 1


def operando(img, dir):
    return img[dir + 1] | img[dir + 2] << 8


def lee(v, banco_, a, b):
    _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, b, 0, banco_))
    return c[2:2 + b - a + 1]


def anda(escena, frame):
    """Guillermo walks on this frame (its keys are written after sys_read_keyboard)"""
    if escena == "comida":
        return frame >= ESCENAS["comida"][0]
    return ESCENAS["inicio"][0] <= frame < ESCENAS["inicio"][1]


def corre(img, e, out, nombre, escena, musica, fotos):
    """the run -> frames [(t, interrupts counted, channel C's state, the music's loop byte)], events [(t, frame,
    what, x, y, a)], the dump's file"""
    frames, eventos = [], []
    stub = bytes([0xEE, CONTADOR & 0xFF, CONTADOR >> 8, 0xD0, 0x03, 0xEE, (CONTADOR + 1) & 0xFF, CONTADOR >> 8,
                  0x4C, e["plat_irq"] & 0xFF, e["plat_irq"] >> 8])
    volcado = os.path.join(out, f"{nombre}_sid.dump")
    total = ESCENAS[escena][-1]
    with V.Vice(None, ["-warp", "-sounddev", "dump", "-soundarg", volcado],
                registro=os.path.join(out, f"vice_{nombre}.log")) as v:
        v.hasta(0xE5CD, limite=120)
        ram, io = banco(v, "ram"), banco(v, "io")
        for i in range(0x0002, 0x10000, 0x1000):
            escribe_banco(v, ram, i, img[i:min(0x10000, i + 0x1000)])
        escribe_banco(v, ram, 0x0100, stub)
        escribe_banco(v, ram, CONTADOR, b"\0\0")
        escribe_banco(v, ram, 0x0198, TESTIGO)
        v.pon_pc(e["principal_inicio"])
        escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff")
        escribe_banco(v, io, 0xDD0F, b"\x51")
        escribe_banco(v, io, 0xDD0E, b"\x11")
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 1, 0xD41F, 0xD41F, 0, io) + bytes([MARCA]))   # the clock's 0
        pts = {v.punto(e[n], temporal=False): n for n in ("game_input_and_mirror", "s_pon", "snd_play_footstep")}
        pts[v.punto(e["game_input_and_mirror"] + 3, temporal=False)] = "leida"    # after JSR sys_read_keyboard
        while len(frames) < total:
            v.golpes.clear()
            v.orden(V.CMD_EXIT)
            while not v.golpes:
                v._respuesta()
            ta, tb = struct.unpack("<HH", lee(v, io, 0xDD04, 0xDD07))
            t = (0xFFFF - tb) * 65536 + (0xFFFF - ta)
            for g in sorted(v.golpes):
                n = pts[g]
                if n == "leida":
                    if anda(escena, len(frames)):
                        escribe_banco(v, ram, TECLAS, bytes([lee(v, ram, TECLAS, TECLAS)[0] & 0xFE]))
                        if not anda(escena, len(frames) - 1):
                            escribe_banco(v, ram, PENDIENTES, bytes([lee(v, ram, PENDIENTES, PENDIENTES)[0] & 0xFE]))
                elif n == "game_input_and_mirror":
                    if not frames:                       # the game's vector is set: through the counter from now on
                        escribe_banco(v, ram, 0xFFFE, b"\x00\x01")
                    c = lee(v, ram, CONTADOR, CONTADOR + 1)
                    frames.append((t, c[0] | c[1] << 8, lee(v, ram, CANAL_C + 0x0E, CANAL_C + 0x0E)[0],
                                   lee(v, ram, musica + 0x7E, musica + 0x7E)[0]))
                    if len(frames) in fotos:
                        v.captura(os.path.join(out, f"{nombre}_frame_{len(frames)}.png"))
                else:
                    r = v.registros()
                    eventos.append((t, len(frames), n, r[1], r[2], r[0]))
        guarda = lee(v, ram, 0x0100, 0x0100 + len(stub) - 1) + lee(v, ram, 0x0198, 0x01AF)
        ok(guarda == stub + TESTIGO, f"{nombre}: the test's counter at $0100 and the guard at $0198-$01AF untouched "
           f"(the game's stack stayed above $01AF)")
    return frames, eventos, volcado


# reSID's envelope generator (envelope.cc), clocked over many cycles at once
PERIODO = [9, 32, 63, 95, 149, 220, 267, 313, 392, 977, 1954, 3126, 3907, 11720, 19532, 31251]
EXPO = {0xFF: 1, 0x5D: 2, 0x36: 4, 0x1A: 8, 0x0E: 16, 0x06: 30, 0x00: 1}


class Envolvente:
    def __init__(self):
        self.env, self.a, self.d, self.s, self.r, self.gate = 0, 0, 0, 0, 0, 0
        self.cuenta, self.expo, self.expo_per, self.estado = 0, 0, 1, "R"
        self.periodo, self.cero = PERIODO[0], True

    def reloj(self, n):
        paso = self.periodo - self.cuenta
        if paso <= 0:
            paso += 0x7FFF
        while n:
            if n < paso:
                self.cuenta += n
                if self.cuenta & 0x8000:
                    self.cuenta = (self.cuenta + 1) & 0x7FFF
                return
            self.cuenta = 0
            n -= paso
            if self.estado == "A" or (self.expo + 1) == self.expo_per:
                self.expo = 0
                if not self.cero:
                    if self.estado == "A":
                        self.env = (self.env + 1) & 0xFF
                        if self.env == 0xFF:
                            self.estado, self.periodo = "D", PERIODO[self.d]
                    elif self.estado == "D":
                        if self.env != self.s * 0x11:
                            self.env -= 1
                    else:
                        self.env = (self.env - 1) & 0xFF
                    if self.env in EXPO:
                        self.expo_per = EXPO[self.env]
                        if self.env == 0:
                            self.cero = True
            else:
                self.expo += 1
            paso = self.periodo

    def escribe(self, reg, v):
        if reg == 18:
            g = v & 1
            if not self.gate and g:
                self.estado, self.periodo, self.cero = "A", PERIODO[self.a], False
            elif self.gate and not g:
                self.estado, self.periodo = "R", PERIODO[self.r]
            self.gate = g
        elif reg == 19:
            self.a, self.d = v >> 4, v & 15
            if self.estado == "A":
                self.periodo = PERIODO[self.a]
            elif self.estado == "D":
                self.periodo = PERIODO[self.d]
        elif reg == 20:
            self.s, self.r = v >> 4, v & 15
            if self.estado == "R":
                self.periodo = PERIODO[self.r]


def envolvente(volcado, instantes):
    """voice 3's envelope (0-255) at the given cycles of this test's clock, from VICE's dump of the SID's writes"""
    escrituras, t, cero = [], 0, None
    for linea in open(volcado):
        d, reg, val = map(int, linea.split())
        t += d
        if reg == 31 and val == MARCA and cero is None:
            cero = t
        elif reg in (18, 19, 20):
            escrituras.append((t, reg, val))
    env, ahora, out, i = Envolvente(), 0, [], 0
    for x in sorted(instantes):
        objetivo = cero + x
        while i < len(escrituras) and escrituras[i][0] <= objetivo:
            env.reloj(escrituras[i][0] - ahora)
            ahora = escrituras[i][0]
            env.escribe(escrituras[i][1], escrituras[i][2])
            i += 1
        env.reloj(objetivo - ahora)
        ahora = objetivo
        out.append(env.env)
    return dict(zip(sorted(instantes), out))


def ticks(frames, nombre):
    t0, c0 = frames[1][0], frames[1][1]
    deriva, contados, prev = [], 0, c0
    for t, c, s, b in frames[1:]:
        contados += (c - prev) & 0xFFFF
        prev = c
        deriva.append((t - t0) // TICK - contados)
    ok(max(deriva) - min(deriva) <= 1, f"{nombre}: the ticks over {len(frames) - 1} frames ({(frames[-1][0] - t0) / 985248:.1f} s): "
       f"{contados} interrupts, CIA 1's underflows minus them from {min(deriva)} to {max(deriva)} (a lost tick moves it for "
       f"good)")


def tramos_musica(frames, arranques, llamadas, musica, paso, nombre):
    """the music's spans: from each start of it to the next start on channel C or the first frame it is not playing"""
    tramos = []
    for i, (ta, fr, s) in enumerate(arranques):
        if s != musica:
            continue
        sig = arranques[i + 1] if i + 1 < len(arranques) else None
        cero = next(((t, b) for t, c, st, b in frames if t > ta and not st & 1), None)
        if sig and (cero is None or sig[0] < cero[0]):
            tramos.append((ta, sig[0], "cut by " + ("a footstep" if sig[2] == paso else f"${sig[2]:04X}"), None))
        else:
            tramos.append((ta, cero[0] if cero else None, "its end" if cero else "the run's end", cero[1] if cero else None))
    for ta, tb, como, b in tramos:
        n = sum(1 for t, fr in llamadas if ta < t < (tb or 1 << 62))
        print(f"      {nombre}: the music from {ta / 985248:.1f} s to " + (f"{tb / 985248:.1f} s" if tb else "the run's end")
              + f": {como}, {n} footsteps called meanwhile" + (f", its loop byte {b:02X}h" if b is not None else ""))
    return tramos


def guarda_tsv(out, nombre, frames, eventos):
    with open(os.path.join(out, f"{nombre}_frames.tsv"), "w") as f:
        f.write("frame\tcycle\tinterrupts\tchannel_c_state\tmusic_loop_byte\n" +
                "".join(f"{i + 1}\t{t}\t{c}\t{s:02X}\t{b:02X}\n" for i, (t, c, s, b) in enumerate(frames)))
    with open(os.path.join(out, f"{nombre}_eventos.tsv"), "w") as f:
        f.write("cycle\tframe\tevent\tx\ty\ta\n" + "".join(f"{t}\t{fr}\t{n}\t{x:02X}\t{y:02X}\t{a:02X}\n"
                                                          for t, fr, n, x, y, a in eventos))


def main():
    out = os.path.abspath(sys.argv[1])
    os.makedirs(out, exist_ok=True)
    escenas = sys.argv[2:] or ["comida", "inicio"]
    e = V.etiquetas(os.path.join(D, "../c64/juego.lbl"))
    k = {}
    for l in open(os.path.join(D, "../mapa64.inc")):
        t = l.split()
        if len(t) >= 3 and t[1] == "=" and t[2].startswith("$"):
            k[t[0]] = int(t[2][1:], 16)
    musica, paso = k["D64_SND_SEQ_MUSIC"], k["D64_SND_SEQ_FOOTSTEP"]
    imagen = open(os.path.join(D, "../c64/juego.bin"), "rb").read()
    f9 = musica + 0x7E
    ok(imagen[f9] == 0xF9 and operando(imagen, f9) == musica,
       f"the music's loop at ${f9:04X}: F9h, ${musica:04X} (objetos_sonido.s S_MUSICA_F9)")
    lda1 = e["psg_paso"] + 11           # psg_paso: BNE, LDA onda+2, STA, LSR, LDA #1: the earlier voicing has LDA #0
    ok(imagen[lda1] == 0xA9 and imagen[lda1 + 1] == 1, f"psg_paso's LDA #1 at ${lda1:04X}")

    if "inicio" in escenas:
        frames, eventos, _ = corre(imagen, e, out, "inicio", "inicio", musica, {10, 18, 300, 900})
        guarda_tsv(out, "inicio", frames, eventos)
        ticks(frames, "inicio")
        arranques = [(t, fr, y | a << 8) for t, fr, n, x, y, a in eventos if n == "s_pon" and x == 0x30]
        llamadas = [(t, fr) for t, fr, n, x, y, a in eventos if n == "snd_play_footstep"]
        ok(llamadas and all(fr < ESCENAS["inicio"][1] + 2 for t, fr in llamadas),
           f"inicio: Guillermo walks a step or two: {len(llamadas)} footsteps called, on frames "
           f"{sorted({fr for t, fr in llamadas})}")
        tramos = tramos_musica(frames, arranques, llamadas, musica, paso, "inicio")
        ok(tramos and tramos[0][0] > frames[ESCENAS["inicio"][1]][0],
           "inicio: the music starts once Guillermo stands still")

    if "comida" in escenas:
        estado = os.path.join(P, "..", "data", "puro", "estados", "ram_d2h3.bin")
        img = bytearray(estado_final.memoria(os.path.join(tempfile.mkdtemp(prefix="pasos_"), "m.bin"), estado))
        quieto, total = ESCENAS["comida"]
        frames, eventos, volcado = corre(img, e, out, "comida", "comida", musica, {quieto, quieto + 200, total})
        guarda_tsv(out, "comida", frames, eventos)
        ticks(frames, "comida")
        arranques = [(t, fr, y | a << 8) for t, fr, n, x, y, a in eventos if n == "s_pon" and x == 0x30]
        llamadas = [(t, fr) for t, fr, n, x, y, a in eventos if n == "snd_play_footstep"]
        ok(any(s == musica and fr <= quieto for t, fr, s in arranques),
           "comida: the music starts on channel C while Guillermo stands")
        tramos = tramos_musica(frames, arranques, llamadas, musica, paso, "comida")
        con = [x for x in tramos if any(x[0] < t < (x[1] or 1 << 62) for t, fr in llamadas)]
        ok(con and all(como != "cut by a footstep" for ta, tb, como, b in tramos),
           f"comida: no footstep cuts the music: {len(con)} spans of it while Guillermo walks")
        fin = next((tb for ta, tb, como, b in con if como == "its end" and b == 0xFF), None)
        ok(fin is not None, "comida: the music ends at its end while Guillermo walks (its loop byte FFh)")
        despues = [t for t, fr, s in arranques if s == paso and fin and t > fin]
        ok(len(despues) >= 5, f"comida: the footsteps come back after it: {len(despues)} started")

        def nivel(arranques, volcado, nombre):
            """voice 3's envelope over the 28 ticks after each footstep start that no other start on channel C cuts"""
            inicios = [t for t, fr, s in arranques]
            pasos = []
            for t0, fr, s in arranques:
                sig = min((t for t in inicios if t > t0), default=None)
                if s == paso and (sig is None or sig > t0 + MUESTRAS * TICK):
                    pasos.append(t0)
            valores = envolvente(volcado, [t0 + (j + 1) * TICK for t0 in pasos for j in range(MUESTRAS)])
            filas = [[valores[t0 + (j + 1) * TICK] for j in range(MUESTRAS)] for t0 in pasos]
            with open(os.path.join(out, f"pasos_{nombre}.tsv"), "w") as f:
                f.write("cycle\t" + "\t".join(f"env3_{j}" for j in range(MUESTRAS)) + "\n")
                f.write("".join(f"{t0}\t" + "\t".join(map(str, m)) + "\n" for t0, m in zip(pasos, filas)))
            return filas
        fn = nivel(arranques, volcado, "nuevo")
        viejo = bytearray(img)
        viejo[lda1 + 1] = 0
        _, eventos_v, volcado_v = corre(viejo, e, out, "voz_anterior", "comida", musica, {total})
        arr_v = [(t, fr, y | a << 8) for t, fr, n, x, y, a in eventos_v if n == "s_pon" and x == 0x30]
        fv = nivel(arr_v, volcado_v, "voz_anterior")

        def cifras(filas):
            todas = [x for m in filas for x in m]
            return (sum(x * x for x in todas) / len(todas)) ** 0.5, sum(todas) / len(todas), max(todas)
        if fn and fv and any(any(m) for m in fv):
            (rn, mn, pn), (rv, mv, pv) = cifras(fn), cifras(fv)
            ok(0.4 <= rn / rv <= 0.6, f"comida: the footsteps' level (voice 3's envelope over {MUESTRAS} ticks, 0-255): "
               f"{len(fn)} footsteps, RMS {rn:.0f} (mean {mn:.0f}, peak {pn}); the earlier voicing: {len(fv)} footsteps, "
               f"RMS {rv:.0f} (mean {mv:.0f}, peak {pv}); RMS ratio {rn / rv:.2f} ({20 * __import__('math').log10(rn / rv):.1f} dB)")
        else:
            ok(False, f"comida: the footsteps' level: {len(fn)} / {len(fv)} footsteps measured")
    print(f"{fallos} checks failed" if fallos else "all checks passed")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
