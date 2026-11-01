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

"""The certification's C64 side (c64/certifica): the real C64 build (normal or CABEZAS) in VICE, frame by frame in
step with the hybrid host's external mode (juego/m6502/sombra6502.c with parche_externo.py), which compares its RAM
with the CPC's Z80 at every frame.

    vice_cert.py JUEGO_DIR FIFO_PREFIX [LOG]

FIFO_PREFIX.out (the host writes: "CERT" and the converted start memory, then per frame its number, the 10 keyboard
rows and the Z80's R), FIFO_PREFIX.in (this writes: per frame a status byte and the 64 KiB of RAM).

The start memory is the host's conversion of the CPC state (sombra6502_juego_inicio) with every code segment of the
build put back from its image (BAJO, CODE*: the host keeps its platform mirrors at $07C0, the start-up code lives in
the sprite buffer, which the conversion fills).  The CPU starts at principal_inicio (SP = FFh, I set, as the host).
The host's model is reproduced exactly (sombra6502.c j_corre, j_pasa):
  - the interrupts: the real ones off (CIA 1's mask cleared when the game reaches game_main: plat_inicio enabled
    it; its ICR then read with side effects: a request raised meanwhile would come at the first CLI); one tick due at every pass of a wait (cert_espera: the frame wait's pass, the host's plat_espera; cert_pausa1
    and cert_pausa2 when its branch is taken: the waits 20C7 and 3EB8, the host's plat_pausa), delivered at once when
    the I flag is clear (else kept, as the host's j_pendientes): an IRQ made by hand (PC and the status pushed, I set,
    PC := the vector at $FFFE), its return to the same address not counted as a pass;
  - the keyboard: plat_teclado_escanea answered with the host's 10 rows (plat_filas; Z = 1, A = 0 when all FFh) and
    a return made by hand; or, the earlier platform, plat_teclado_fila with A = 0 (the row that scans):
    the host's rows written into its rows and the CPU sent to its `lda filas,y` with Y = 0; plat_aleatorio: A = the
    host's R;
  - the frame points: cert_frame (the host's plat_frame) and the waits' passes (after their tick); plat_final:
    status 2.  Status bit 7: game_init_new_game ran in the frame (the host's j_es_nueva).
Deterministic: VICE only runs between checkpoints, no real time involved."""
import os, struct, sys, re
P = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))          # c64/
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
import vice_mb as V
import arranca as A

R_A, R_X, R_Y, R_PC, R_SP, R_FL = 0, 1, 2, 3, 4, 5        # VICE's ids (its "registers available", command 0x83)


def segmentos_codigo(mapa):
    out, lista = [], False
    for l in open(mapa):
        if l.startswith("Segment list"): lista = True
        elif lista and l.startswith("Exports list"): break
        t = l.split()
        if lista and len(t) >= 3 and (t[0] in ("BAJO", "COMUN") or t[0].startswith("CODE")) and len(t[1]) == 6:
            out.append((int(t[1], 16), int(t[2], 16)))
    return out


def banco1(juego):
    """the C128 build's blocks in block 1 (mapa64.tsv zone banco1): [(start, length)]; [] for a C64 build"""
    m = os.path.join(juego, "mapa64.tsv")
    if not os.path.exists(os.path.join(juego, "juego.bin.banco1")) or not os.path.exists(m): return []
    return [(int(c[3], 16), int(c[4])) for c in (l.rstrip("\n").split("\t") for l in open(m) if not l.startswith("#"))
            if len(c) > 6 and c[6] == "banco1"]


def main():
    juego, pref = sys.argv[1], sys.argv[2]
    log = sys.argv[3] if len(sys.argv) > 3 else os.devnull
    img = open(os.path.join(juego, "juego.bin"), "rb").read()
    # the C128 (milestone H10): x128 in its own mode, block 0 the C64's image, block 1 the moved blocks (their
    # bytes go to the host where the map puts them: the host compares data blocks only, never the code there)
    b1 = banco1(juego)
    c128 = bool(b1) or os.path.exists(os.path.join(juego, "juego.bin.banco1"))
    if c128: os.environ["VICE_EMU"] = "x128"
    e = V.etiquetas(os.path.join(juego, "juego.lbl"))
    fin_ = open(pref + ".out", "rb")
    fout = open(pref + ".in", "wb")
    def lee(n):
        b = fin_.read(n)
        if len(b) != n: raise SystemExit("vice_cert: the host closed")
        return b
    if lee(4) != b"CERT": raise SystemExit("vice_cert: not the host's external mode")
    mem = bytearray(lee(0x10000))
    mem1 = {a: bytes(mem[a:a + n]) for a, n in b1}        # (the host's start state of block 1's blocks)
    for a, z in segmentos_codigo(os.path.join(juego, "juego.map")):
        mem[a:z + 1] = img[a:z + 1]
    with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=log) as v:
        # BASIC waiting for a key: the C64 KERNAL's loop at $E5CD; the C128's screen editor's at $C25E (measured
        # in x128 3.10 with its ROMs: the PC samples after the start-up were $C25E, $C260, $C262)
        v.hasta(0xC25E if c128 else 0xE5CD, limite=120)
        ram, io = A.banco(v, "ram00" if c128 else "ram"), A.banco(v, "io")
        if c128:
            cpu = A.banco(v, "cpu")
            v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, cpu) + b"\x3e")   # block 0 + the I/O
            ram1 = A.banco(v, "ram01")
            img1 = open(os.path.join(juego, "juego.bin.banco1"), "rb").read()
            A.escribe_banco(v, ram1, 0x1000, img1)
            for a, n in b1:                             # the host's start state of those blocks
                A.escribe_banco(v, ram1, a, mem1[a])
            A.escribe_banco(v, ram, 0x0002, bytes(mem[2:0xFF00]))
            A.escribe_banco(v, ram, 0xFF05, bytes(mem[0xFF05:0x10000]))
        else:
            A.escribe_banco(v, ram, 0x0002, bytes(mem[2:0x10000]))
        lmem = lambda a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, ram))[1][2:2 + n]
        lmem1 = (lambda a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, ram1))[1][2:2 + n]) if c128 else None
        def pon(*pares):
            cuerpo = b"".join(struct.pack("<BBH", 3, i, x) for i, x in pares)
            v.orden(V.CMD_REGISTERS_SET, struct.pack("<BH", 0, len(pares)) + cuerpo)
        r = v.registros()
        pon((R_PC, e["principal_inicio"]), (R_SP, 0xFF), (R_FL, r[R_FL] | 0x04))
        fila = "plat_teclado_escanea" not in e             # the earlier platform: plat_teclado_fila
        nombres = ("game_main", "cert_frame", "cert_espera", "cert_pausa1", "cert_pausa2", "game_init_new_game",
                   "plat_teclado_fila" if fila else "plat_teclado_escanea", "plat_aleatorio", "plat_final")
        pts = {v.punto(e[n], temporal=False): n for n in nombres}
        if fila:
            # plat_teclado_fila: A = 0 scans the C64 into its rows, then `lee: lda filas,y / rts`; the first
            # absolute,Y load (B9) of the routine is that instruction: its operand is the rows' address
            q = img.index(b"\xB9", e["plat_teclado_fila"])
            filas, en_lee = img[q + 1] | img[q + 2] << 8, q
        else:
            filas = e["plat_filas"]
        pend, ignora, nueva, cia_off = 0, None, False, False
        entrada = lee(15)                                   # frame 1's inputs
        teclas, rr = entrada[4:14], entrada[14]
        def manda(st):
            nonlocal nueva
            fout.write(bytes([st | (0x80 if nueva else 0)]))
            m = bytearray(b"".join(lmem(a, 0x1000) for a in range(0, 0x10000, 0x1000)))
            for a, n in b1:
                m[a:a + n] = lmem1(a, n)
            fout.write(bytes(m))
            fout.flush()
            nueva = False
        def rts(regs):
            sp = regs[R_SP]
            b = lmem(0x0100 + ((sp + 1) & 0xFF), 1)[0] | lmem(0x0100 + ((sp + 2) & 0xFF), 1)[0] << 8
            return (b + 1) & 0xFFFF, (sp + 2) & 0xFF
        def pasa(regs):
            """a pass of a wait: one tick due; delivered now (an IRQ made by hand) when I is clear: True"""
            nonlocal pend, ignora
            pend += 1
            if regs[R_FL] & 0x04: return False
            pend -= 1
            sp, pc, fl = regs[R_SP], regs[R_PC], regs[R_FL]
            A.escribe_banco(v, ram, 0x0100 + sp, bytes([pc >> 8]))
            A.escribe_banco(v, ram, 0x0100 + ((sp - 1) & 0xFF), bytes([pc & 0xFF]))
            A.escribe_banco(v, ram, 0x0100 + ((sp - 2) & 0xFF), bytes([(fl | 0x20) & ~0x10 & 0xFF]))
            vec = lmem(0xFFFE, 2)
            pon((R_SP, (sp - 3) & 0xFF), (R_FL, fl | 0x04), (R_PC, vec[0] | vec[1] << 8))
            ignora = pc
            return True
        pausa_pend = None                                   # a wait's pass whose tick runs first: its frame after
        traza = open(os.environ["CERT_TRAZA"], "w") if os.environ.get("CERT_TRAZA") else None
        nframe = 1
        while True:
            v.golpes.clear()
            v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
            regs = v.registros()
            pc = regs[R_PC]
            hits = {pts[g] for g in v.golpes if g in pts}
            if traza and nframe <= 6:
                traza.write(f"frame {nframe} pc {pc:04X} hits {sorted(hits)} I {regs[R_FL] >> 2 & 1} pend {pend} ignora {ignora} scroll {lmem(0x02BF, 1)[0]:02X} systicks {lmem(0x02C5, 1)[0]:02X}\n"); traza.flush()
            if ignora is not None and pc == ignora:         # the made IRQ's return: not a new pass
                ignora = None
                if pausa_pend is not None:                  # the wait's frame, after its tick (the host's order)
                    manda(1); pausa_pend = None
                    entrada = lee(15); teclas, rr = entrada[4:14], entrada[14]
                continue
            if "game_main" in hits and not cia_off:
                A.escribe_banco(v, io, 0xDC0D, b"\x7f"); cia_off = True
                # a request the CIA raised before (its timer ran since plat_inicio enabled it) stays until ICR is
                # read: read it as the CPU would (the monitor's read with side effects)
                v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 1, 0xDC0D, 0xDC0D, 0, io))
            if "game_init_new_game" in hits: nueva = True
            if "plat_teclado_fila" in hits:
                if regs[R_A] == 0:                          # row 0: the host's rows instead of the C64's scan
                    A.escribe_banco(v, ram, filas, bytes(teclas))
                    pon((R_Y, 0), (R_PC, en_lee))
                continue
            if "plat_teclado_escanea" in hits:
                A.escribe_banco(v, ram, filas, bytes(teclas))
                nada = all(x == 0xFF for x in teclas)
                ret, sp = rts(regs)
                pon((R_A, 0 if nada else 1), (R_FL, (regs[R_FL] & ~0x02 & 0xFF) | (0x02 if nada else 0)), (R_PC, ret), (R_SP, sp))
                continue
            if "plat_aleatorio" in hits:
                ret, sp = rts(regs)
                pon((R_A, rr), (R_FL, (regs[R_FL] & ~0x82 & 0xFF) | (0x02 if rr == 0 else 0) | (rr & 0x80)), (R_PC, ret), (R_SP, sp))
                continue
            if "plat_final" in hits:
                manda(2); break
            if "cert_espera" in hits:
                pasa(regs); continue
            if "cert_pausa1" in hits or ("cert_pausa2" in hits and regs[R_FL] & 0x02):
                if pasa(regs): pausa_pend = pc              # its frame once the tick has run
                else:
                    manda(1); entrada = lee(15); teclas, rr = entrada[4:14], entrada[14]
                continue
            if "cert_frame" in hits:
                nframe += 1
                manda(1)
                entrada = lee(15); teclas, rr = entrada[4:14], entrada[14]


if __name__ == "__main__":
    main()
