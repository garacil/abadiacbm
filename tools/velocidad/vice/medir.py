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

"""Measure, in VICE (x64sc 3.10, binary monitor), the real C64 frame of the abadia64ks game image: the cycles of
every main-loop frame (as c64/juego_final/vice/arranca.py counts them: CIA 2 as a 32-bit cycle counter, frame n =
the interval between the (n-1)-th and the n-th call of game_input_and_mirror), split into its phases, and the
cycles of every 300 Hz interrupt (plat_irq entry to its RTI), with the sound work (s_interrupcion), the phrase
work (t_frase) and every SID write (plat_psg) inside it timed separately.

Deterministic: the emulation is a function of the emulated cycles alone (VICE's random seed fixed, no autostart
delay, no keys); the emulator is driven only at checkpoints (stops), and every stop reads the CIA 2 counter.
The same image gives the same tables (the wall time in resumen.txt is the only non-deterministic figure).

    medir.py IMGDIR OUTDIR --hasta M [--ligero --instantaneas DIR --cada K] [--instantanea FILE --desde N]
        IMGDIR      juego.bin, juego.lbl, juego.map (copies of the build)
        --hasta M   measure up to frame M (the M-th call of game_input_and_mirror)
        --ligero    only the frame checkpoint (arranca.py's measurement: ciclos.tsv), and with --instantaneas
                    DIR --cada K a VICE snapshot DIR/hit_N.vsf at every K-th call (N = K, 2K, ...)
        --instantanea FILE --desde N   start from the snapshot taken at the N-th call: frames N+1 .. M (a chunk
                    of the whole run, so that chunks run in parallel; the chunks' tables join seamlessly: une.py)
    OUTDIR gets ciclos.tsv (arranca.py's table), fases.tsv (the frame's phases and the interrupt's share),
    ticks.tsv (one line per interrupt), psg.tsv (one line per SID write), resumen.txt, vice.log
    VICE_DISPLAY (default :90): the X display for x64sc (an Xvfb of our own, never :98 / :99 / :1)

Checkpoints (addresses from juego.lbl and the image, see sitios()):
    FRAME   game_input_and_mirror      the frame starts (its first instruction is JSR sys_read_keyboard)
    TECLADO the return of that JSR     -> phase 0 = sys_read_keyboard (the keyboard scan, plat_teclado_fila)
    ESPERA  the frame-wait loop head   -> phase 1 = the rest of the main loop's work before the wait
    SALIDA  the instruction after it   -> phase 2 = the wait (LDA D64_SYS_TICKS / CMP / BCS / JMP, 11 cycles a pass)
    (next FRAME)                       -> phase 3 = footstep test, spr_draw_or_darken, sys_key_down, loop head
    IRQ     plat_irq                   the interrupt's entry (7 cycles of IRQ sequence already spent)
    RTI     plat_irq's own RTI         the stop before the RTI (6 cycles to come)
    SND     s_interrupcion             at its entry a checkpoint at sys_tick's return address, deleted at its hit
    FRASE   t_frase                    idem
    PSG     plat_psg                   at its entry a checkpoint at the return address on the stack, deleted at
                                       its hit (so the JMP plat_psg tail calls of snd_psg_write are timed too)
(A checkpoint created while stopped must be a normal one: VICE 3.10's temporary checkpoints created a few
cycles before their address never stop the emulation, measured: prueba_temp.py, 0 of 200 against 200 of 200.)
The CIA 2 counter read at a stop that falls in the cycle where timer A has just reloaded but timer B has not yet
counted the underflow reads 65536 low (VICE 3.10, measured: 6 of ~190000 stops in the first full run); the stops
of the full mode are never more than one tick period apart, so such a read is below the previous stop's time and
is corrected by +65536 (a read more than 70000 cycles after the previous stop stops the program: never seen).
Cycle costs of the entry/exit instructions not covered by the stops (7 for the IRQ sequence, 6 for RTI, 6 for the
JSR before an entry stop) are the 6502's as cc65's sim65 core gives them: juego/m6502/6502.c lines 4771 (IRQ:
Cycles = 7), 1858 (RTI 6), 1556 (JSR 6).  VICE's IRQ sequence is checked by measurement (resumen.txt: the
"underflow to handler" distances from CIA 1 timer A at the entry; its minimum is 7 + 1).
"""
import argparse, os, re, struct, sys, time
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(D, "..", "..", "..", "src", "c64", "plataforma", "pruebas"))   # vice_mb
import vice_mb as V

CMD_BANKS = 0x82
CMD_REGISTERS_AVAILABLE = 0x83
TICK = 3279                                          # CICLOS_TICK, c64/plataforma/plat64.inc
IRQ_SEQ, RTI_C, JSR_C = 7, 6, 6                      # 6502.c 4771, 1858, 1556
REG_PC, REG_SP = 3, 4                                # VICE's 6510 register ids (CMD_REGISTERS_AVAILABLE)


def segmentos(mapa):
    """ld65's map file -> {segment: (start, end)} from its 'Segment list'"""
    out, dentro = {}, False
    for linea in open(mapa):
        if linea.startswith("Segment list"):
            dentro = True
        elif dentro:
            t = linea.split()
            if len(t) == 5 and re.fullmatch(r"[0-9A-F]{6}", t[1]):
                out[t[0]] = (int(t[1], 16), int(t[2], 16))
            elif not t and out:
                break
    return out


def sitios(img, e, seg):
    """the addresses: the wait loop by its bytes (LDA zp $50 / CMP zp $3C / BCS +3 / JMP self), the JSR sites
    of the routines timed by their return address (JSR abs = $20 lo hi inside the code segments CODE and BAJO)"""
    zt, zf = 0x50, 0x3C                              # D64_SYS_TICKS, D64_SYS_FRAME_TICKS (mapa64.inc, zp)
    pat = bytes([0xA5, zt, 0xC5, zf, 0xB0, 0x03, 0x4C])
    i = img.find(pat)
    assert i >= 0 and img[i + 7] | (img[i + 8] << 8) == i, "wait loop not found"
    assert img.find(pat, i + 1) < 0, "more than one wait loop"
    s = {"ESPERA": i, "SALIDA": i + 9}
    codigo = [seg["CODE"], seg["BAJO"]]
    def rets(nombre, opcodes=(0x20,)):
        a = e[nombre]
        out = []
        for op in opcodes:
            p = bytes([op, a & 0xFF, a >> 8])
            j = img.find(p)
            while j >= 0:
                if any(ini <= j <= fin for ini, fin in codigo):
                    out.append(j + 3)
                j = img.find(p, j + 1)
        return sorted(out)
    s["FRAME"] = e["game_input_and_mirror"]
    assert img[s["FRAME"]:s["FRAME"] + 3] == bytes([0x20, e["sys_read_keyboard"] & 0xFF, e["sys_read_keyboard"] >> 8])
    s["TECLADO"] = s["FRAME"] + 3
    s["IRQ"] = e["plat_irq"]
    fin = img.find(bytes([0x68, 0x85, 0x01, 0x68, 0x40]), s["IRQ"])   # plat_irq's exit: PLA / STA $01 / PLA / RTI
    assert 0 < fin - s["IRQ"] < 64, "plat_irq's RTI not found"
    s["RTI"] = fin + 4
    s["SND"] = e["s_interrupcion"]
    s["FRASE"] = e["t_frase"]
    s["PSG"] = e["plat_psg"]
    # the sound: plat_irq's own call site (since round 5 a BIT abs that the sound code turns into a JSR while a
    # channel plays, plataforma/interrupcion.s), not the Z80 entry's JSR in objetos_sonido.s
    r = [x for x in rets("s_interrupcion", (0x20, 0x2C)) if s["IRQ"] <= x - 3 < s["RTI"]]
    assert len(r) == 1, "plat_irq's call of s_interrupcion"; s["SND_RET"] = r[0]
    r = rets("t_frase"); assert len(r) == 1; s["FRASE_RET"] = r[0]
    s["PSG_JSR"] = rets("plat_psg")                  # (information only: the returns are read from the stack)
    return s


def banco(v, nombre):
    _, c = v.orden(CMD_BANKS)
    n = struct.unpack("<H", c[:2])[0]
    k = 2
    for _ in range(n):
        tam = c[k]
        bid = struct.unpack("<H", c[k + 1:k + 3])[0]
        nlen = c[k + 3]
        nom = c[k + 4:k + 4 + nlen].decode()
        if nom == nombre:
            return bid
        k += 1 + tam
    raise RuntimeError(f"no bank {nombre}")


def escribe_banco(v, b, ini, datos):
    for i in range(0, len(datos), 0x1000):
        trozo = datos[i:i + 0x1000]
        a = ini + i
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, a, a + len(trozo) - 1, 0, b) + bytes(trozo))


def arranca_juego(v, pc):
    """as arranca.py: the CPU sent to pc with the interrupts disabled"""
    r = v.registros()
    v.orden(V.CMD_REGISTERS_SET, struct.pack("<BHBBHBBH", 0, 2, REG_PC, 3, pc, 3, 5, r[5] | 0x04))


class Medida:
    def __init__(self, v, io):
        self.v, self.io = v, io
        self.puntos = {}                             # number -> name

    def punto(self, nombre, dir, temporal=False):
        _, c = self.v.orden(V.CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", dir, dir, 1, 1, 4, 1 if temporal else 0, 0))
        n = struct.unpack("<I", c[:4])[0]
        self.puntos[n] = nombre
        return n

    def borra(self, n):
        self.v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", n))
        self.puntos.pop(n, None)

    def tiempo(self):
        _, c = self.v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xDD04, 0xDD07, 0, self.io))
        ta, tb = struct.unpack("<HH", c[2:6])
        return (0xFFFF - tb) * 65536 + (0xFFFF - ta)

    def cia1_ta(self):
        _, c = self.v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xDC04, 0xDC05, 0, self.io))
        return struct.unpack("<H", c[2:4])[0]

    def retorno(self):
        """the return address of the routine just entered (the stack's top word + 1)"""
        sp = self.v.registros()[REG_SP]
        _, c = self.v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0x101 + sp, 0x102 + sp, 0, 0))
        return (struct.unpack("<H", c[2:4])[0] + 1) & 0xFFFF

    def sigue(self):
        """resume and wait for the next stop: (pc, [(checkpoint number, VICE's hit count)...])"""
        v = self.v
        golpes = []
        v.orden(V.CMD_EXIT)
        while True:
            tipo, error, rid, cuerpo = v._respuesta()
            if tipo == V.RESP_CHECKPOINT and rid == V.EVENTO and cuerpo[4]:
                golpes.append((struct.unpack("<I", cuerpo[:4])[0], struct.unpack("<I", cuerpo[13:17])[0]))
            elif tipo == V.RESP_STOPPED:
                return v.pc, golpes
            elif tipo == V.RESP_JAM:
                raise RuntimeError(f"CPU jam at {v.pc:04X}")


def arranque(v, img, e):
    """the machine booted, the image in the RAM, the CPU at principal_inicio, CIA 2 counting (arranca.py)"""
    v.hasta(0xE5CD, limite=120)                      # the KERNAL's screen editor waits for a key: booted
    ram = banco(v, "ram")
    escribe_banco(v, ram, 0x0002, img[2:0x10000])
    arranca_juego(v, e["principal_inicio"])
    io = banco(v, "io")
    escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff")   # CIA 2: timer A counts the clock from FFFFh,
    escribe_banco(v, io, 0xDD0F, b"\x51")                # timer B its underflows
    escribe_banco(v, io, 0xDD0E, b"\x11")
    return io


def nuevo_acum():
    return {"ticks": 0, "irq": 0, "irq_base": 0, "snd_n": 0, "snd": 0, "frase_n": 0, "frase": 0,
            "psg_n": 0, "psg": 0, "anidadas": 0, "irq_fase": [0, 0, 0, 0]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("imgdir"); ap.add_argument("out")
    ap.add_argument("--hasta", type=int, required=True)
    ap.add_argument("--ligero", action="store_true")
    ap.add_argument("--instantaneas"); ap.add_argument("--cada", type=int, default=0)
    ap.add_argument("--instantanea"); ap.add_argument("--desde", type=int, default=0)
    ap.add_argument("--opciones", default="+VICIIvsync", help="extra x64sc options (default +VICIIvsync: 7x faster stops)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    img = open(os.path.join(a.imgdir, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(a.imgdir, "juego.lbl"))
    s = sitios(img, e, segmentos(os.path.join(a.imgdir, "juego.map")))
    os.environ.setdefault("VICE_DISPLAY", ":90")
    t0 = time.time()
    opciones = ["-sounddev", "dummy", "-warp"] + a.opciones.split()
    with V.Vice(None, opciones, registro=os.path.join(a.out, "vice.log")) as v:
        io = arranque(v, img, e)
        m = Medida(v, io)
        frame = 0
        if a.instantanea:
            v.orden(V.CMD_UNDUMP, struct.pack("<B", len(a.instantanea)) + a.instantanea.encode())
            v.para()
            pc = v.registros()[REG_PC]
            if pc != s["FRAME"]:
                raise RuntimeError(f"the snapshot is not at game_input_and_mirror: PC {pc:04X}")
            frame = a.desde
        _, c = v.orden(CMD_REGISTERS_AVAILABLE, b"\x00")
        n = struct.unpack("<H", c[:2])[0]
        regs, k = [], 2
        for _ in range(n):
            tam, rid, bits, nlen = c[k], c[k + 1], c[k + 2], c[k + 3]
            regs.append((rid, c[k + 4:k + 4 + nlen].decode()))
            k += 1 + tam
        assert dict(regs)[REG_PC] == "PC" and dict(regs)[REG_SP] == "SP"
        fijos = {"FRAME": m.punto("FRAME", s["FRAME"])}
        if not a.ligero:
            for nombre in ("TECLADO", "ESPERA", "SALIDA", "IRQ", "RTI", "SND", "FRASE", "PSG"):
                fijos[nombre] = m.punto(nombre, s[nombre])
        # ---- the measurement
        ciclos, fases, ticks, psg = [], [], [], []
        t_frame = m.tiempo() if a.instantanea else 0 # the current frame's start (0: the counter's start)
        fase_t = {0: t_frame} if a.instantanea else {}
        fase_actual = 0 if a.instantanea else None
        pila_irq = []                                # [entry, snd, frase, psg_n, psg, nested cycles] of the IRQs in progress
        n_tick = 0
        snd_t = frase_t = psg_t = None
        pend = {}                                    # name -> the return checkpoint's number, while it waits
        acum = nuevo_acum()
        cuenta = {"snd": 0, "frase": 0, "psg": 0, "anidadas": 0, "rti_sin_irq": 0, "retorno_sin_entrada": 0,
                  "entrada_sin_retorno": 0, "sin_espera": 0}
        ta_hist = {}
        paradas = 0
        contadores = {}
        tiempos_hit = {}
        t_prev = t_frame
        correcciones = 0
        while True:
            pc, golpes = m.sigue()
            paradas += 1
            for num, cnt in golpes:
                contadores[num] = cnt
            t = m.tiempo()
            if t < t_prev:                           # the counter's low word wrapped before its high word counted
                t += 65536; correcciones += 1
            if not a.ligero and n_tick and t - t_prev > 70000:   # (before the first tick: the start-up's SEI span)
                raise RuntimeError(f"a jump of {t - t_prev} cycles between stops at {pc:04X}")
            t_prev = t
            if pc == s["FRAME"]:
                frame += 1
                fase_t[4] = t
                fases.append((frame, t_frame, t - t_frame, fase_t.get(1), fase_t.get(2), fase_t.get(3), t, acum))
                ciclos.append((frame, t))
                if a.ligero and a.instantaneas and a.cada and frame % a.cada == 0 and frame < a.hasta:
                    nombre = os.path.join(os.path.realpath(a.instantaneas), f"hit_{frame:04d}.vsf")
                    v.orden(V.CMD_DUMP, struct.pack("<BBB", 0, 0, len(nombre)) + nombre.encode())
                    tiempos_hit[frame] = t
                if frame >= a.hasta:
                    break
                if not a.ligero and "ESPERA" not in fijos:
                    cuenta["sin_espera"] += 1          # the previous frame left the wait loop unseen (no SALIDA)
                    fijos["ESPERA"] = m.punto("ESPERA", s["ESPERA"])
                t_frame = t
                fase_t = {0: t}
                fase_actual = 0
                acum = nuevo_acum()
            elif pc == s["TECLADO"]:
                fase_t[1] = t; fase_actual = 1
            elif pc == s["ESPERA"]:
                fase_t[2] = t; fase_actual = 2
                m.borra(fijos.pop("ESPERA"))         # the loop's later passes must not stop
            elif pc == s["SALIDA"]:
                fase_t[3] = t; fase_actual = 3
                fijos["ESPERA"] = m.punto("ESPERA", s["ESPERA"])
            elif pc == s["IRQ"]:
                if pila_irq:
                    cuenta["anidadas"] += 1; acum["anidadas"] += 1
                pila_irq.append([t, 0, 0, 0, 0, 0])
                d = (TICK - 1) - m.cia1_ta()         # cycles from timer A's underflow to this instruction
                ta_hist[d] = ta_hist.get(d, 0) + 1
                n_tick += 1
                pila_irq[-1].append(d)
            elif pc == s["RTI"]:
                if not pila_irq:
                    cuenta["rti_sin_irq"] += 1
                    continue
                ent = pila_irq.pop()
                dur = (t + RTI_C) - (ent[0] - IRQ_SEQ)
                propio = dur - ent[5]                # its own cycles (a nested tick's excluded)
                ticks.append((n_tick, frame + 1, fase_actual, ent[0] - IRQ_SEQ, dur, propio, ent[1], ent[2], ent[3], ent[4], len(pila_irq), ent[6]))
                acum["ticks"] += 1
                acum["irq"] += propio
                acum["irq_fase"][fase_actual if fase_actual is not None else 0] += propio
                acum["snd"] += ent[1]; acum["frase"] += ent[2]; acum["psg_n"] += ent[3]; acum["psg"] += ent[4]
                acum["irq_base"] += propio - ent[1] - ent[2]
                if pila_irq:
                    pila_irq[-1][5] += dur
            elif pc == s["SND"]:
                if snd_t is not None: cuenta["entrada_sin_retorno"] += 1
                snd_t = t
                if "SND" not in pend: pend["SND"] = m.punto("SND_RET", s["SND_RET"])
            elif pc == s["SND_RET"]:
                m.borra(pend.pop("SND"))
                if snd_t is None or not pila_irq:
                    cuenta["retorno_sin_entrada"] += 1
                else:
                    pila_irq[-1][1] += (t - snd_t) + JSR_C
                    acum["snd_n"] += 1; cuenta["snd"] += 1
                snd_t = None
            elif pc == s["FRASE"]:
                if frase_t is not None: cuenta["entrada_sin_retorno"] += 1
                frase_t = t
                if "FRASE" not in pend: pend["FRASE"] = m.punto("FRASE_RET", s["FRASE_RET"])
            elif pc == s["FRASE_RET"]:
                m.borra(pend.pop("FRASE"))
                if frase_t is None or not pila_irq:
                    cuenta["retorno_sin_entrada"] += 1
                else:
                    pila_irq[-1][2] += (t - frase_t) + JSR_C
                    acum["frase_n"] += 1; cuenta["frase"] += 1
                frase_t = None
            elif pc == s["PSG"]:
                if psg_t is not None:
                    cuenta["entrada_sin_retorno"] += 1
                    m.borra(pend.pop("PSG"))
                psg_t = t
                psg_ret = m.retorno()
                pend["PSG"] = m.punto("PSG_RET", psg_ret)
            elif psg_t is not None and pc == psg_ret:
                m.borra(pend.pop("PSG"))
                d = (t - psg_t) + JSR_C
                psg.append((n_tick, frame + 1, fase_actual, psg_t, d, len(pila_irq), psg_ret))
                if pila_irq:
                    pila_irq[-1][3] += 1; pila_irq[-1][4] += d
                else:
                    acum["psg_n"] += 1; acum["psg"] += d  # a write from the main code (counted in the frame, not in a tick)
                cuenta["psg"] += 1
                psg_t = None
            else:
                raise RuntimeError(f"stopped at {pc:04X} ({[m.puntos.get(n, '?') for n, _ in golpes]}) unexpectedly")
        dt = time.time() - t0
        # ---- output
        with open(os.path.join(a.out, "ciclos.tsv"), "w") as o:
            o.write("frame\tcycles_since_start\tcycles_of_frame\n")
            prev = fases[0][1] if fases else 0
            for f, t in ciclos:
                o.write(f"{f}\t{t}\t{t - prev}\n"); prev = t
        if not a.ligero:
            with open(os.path.join(a.out, "fases.tsv"), "w") as o:
                o.write("frame\tstart\tcycles\tteclado_raw\ttrabajo1_raw\tespera_raw\ttrabajo2_raw\t"
                        "irq_teclado\tirq_trabajo1\tirq_espera\tirq_trabajo2\t"
                        "teclado_net\ttrabajo1_net\tespera_net\ttrabajo2_net\twork_net\t"
                        "ticks\tirq_total\tirq_base\tsnd_n\tsnd\tfrase_n\tfrase\tpsg_n\tpsg\tanidadas\n")
                for (f, t0f, cyc, t1, t2, t3, t4, ac) in fases:
                    t0p = fase_t0 = t0f
                    raw = [t1 - t0f if t1 is not None else -1,
                           t2 - t1 if t1 is not None and t2 is not None else -1,
                           t3 - t2 if t2 is not None and t3 is not None else -1,
                           t4 - t3 if t3 is not None else -1]
                    irqf = ac["irq_fase"]
                    net = [r - i if r >= 0 else -1 for r, i in zip(raw, irqf)]
                    work = sum(x for k, x in enumerate(net) if k != 2 and x >= 0)
                    o.write(f"{f}\t{t0f}\t{cyc}\t" + "\t".join(map(str, raw)) + "\t" + "\t".join(map(str, irqf)) + "\t"
                            + "\t".join(map(str, net)) + f"\t{work}\t{ac['ticks']}\t{ac['irq']}\t{ac['irq_base']}\t"
                            f"{ac['snd_n']}\t{ac['snd']}\t{ac['frase_n']}\t{ac['frase']}\t{ac['psg_n']}\t{ac['psg']}\t{ac['anidadas']}\n")
            with open(os.path.join(a.out, "ticks.tsv"), "w") as o:
                o.write("tick\tframe\tphase\tirq_start\tcycles\town\tsnd\tfrase\tpsg_n\tpsg\tdepth\tlatency\n")
                for r in ticks:
                    o.write("\t".join(str(x) for x in r) + "\n")
            with open(os.path.join(a.out, "psg.tsv"), "w") as o:
                o.write("tick\tframe\tphase\tstart\tcycles\tdepth\treturn\n")
                for r in psg:
                    o.write("\t".join(str(x) if not isinstance(x, int) or i != 6 else f"{x:04X}" for i, x in enumerate(r)) + "\n")
        with open(os.path.join(a.out, "resumen.txt"), "w") as o:
            o.write(f"image: {os.path.join(a.imgdir, 'juego.bin')}\nmode: {'light' if a.ligero else 'full'}\n")
            o.write(f"frames: {fases[0][0] if fases else '-'}..{fases[-1][0] if fases else '-'} ({len(fases)})\nstops: {paradas}\n")
            o.write(f"wall time (s): {dt:.1f} (not deterministic; the cycle tables are)\n")
            o.write(f"x64sc options: {' '.join(opciones)}\n")
            o.write("registers available: " + " ".join(f"{rid}={nom}" for rid, nom in regs) + "\n")
            o.write("sites: " + " ".join(f"{k}={val:04X}" if isinstance(val, int) else f"{k}={','.join('%04X' % x for x in val)}" for k, val in s.items()) + "\n")
            o.write(f"counts: {cuenta}\ncounter reads corrected by +65536 (the low word wrapped before the high word counted): {correcciones}\n")
            o.write("VICE hit counts of the fixed checkpoints: " + " ".join(f"{m.puntos.get(n, '?')}={c}" for n, c in sorted(contadores.items()) if n in fijos.values()) + "\n")
            o.write(f"ticks timed: {len(ticks)}; SID writes timed: {len(psg)}\n")
            if tiempos_hit:
                o.write("snapshots (hit: cycles): " + " ".join(f"{f}:{t}" for f, t in sorted(tiempos_hit.items())) + "\n")
            o.write("CIA 1 timer A at the IRQ entry, (3278 - TA) = cycles from the underflow to plat_irq's first instruction (distance:ticks): "
                    + " ".join(f"{d}:{n}" for d, n in sorted(ta_hist.items())) + "\n")
        print(open(os.path.join(a.out, "resumen.txt")).read())


if __name__ == "__main__":
    main()
