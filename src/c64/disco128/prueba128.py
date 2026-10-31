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

"""The C128's disk in VICE (x128 3.10, warp, its KERNAL; drive 8 a true 1571 or 1541), deterministic (c64/disco128/NOTAS.md): the C128
started with abadia128ks.d64 in drive 8 boots it (the boot sector loads M); at the menu (menu.s's key loop) the keys
of OPTIONS typed into the KERNAL's keyboard buffer (KEYBUF $034A, NDX $D0: "Mapping the Commodore 128"), then SPACE;
the presentation passed with SPACE at each of conio's kbhit and cgetc; at the game's principal_inicio block 0
compared with the game's image (c64/juego_final/c128, or c128_en for English; the stage's own $C000-$C3FF and the
MMU's $FF00-$FF04 left out, the two sound calls as the options say), block 1's game data with juego.bin.banco1, the
options in plat_opciones, plat_unidad 8; then FRAMES game frames (cert_frame) and the screens saved.

    prueba128.py OUT_DIR [--opciones KEYS] [--frames N] [--final] [--guarda] [--unidad 1571|1541]
        KEYS: e.g. "" (Spanish, all on), "1" (English), "234" (no footsteps, no text sound, no Ave Maria)
--final: instead of the frames, the ending: the state one step from 100 % (c64/presentacion/pruebas/estado_final.py,
converted with the C128 build's own map; block 1's blocks to block 1, the KERNAL's page $0A00 left as the loader
put it) written over the loaded game, the game's code to plat_final, the KERNAL's "FINAL" loaded and run ($1C0D),
equal to final.prg, the menu's options at $0BFF, the ending's parchment on the screen.
--guarda: instead of the frames, the CTRL+TAB menu's save and load on the disk (a copy of it: ABADIA64.BS1 is written)
through the C128's KERNAL, as c64/juego_final/vice/guarda_carga.py on the C64: 60 frames, CTRL+TAB and S, 50 frames,
CTRL+TAB and L, 200 frames; the save and the load return with C clear, the game's pieces restored as saved."""
import os, socket, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
sys.path.insert(0, os.path.join(P, "c64", "juego_final", "vice"))
sys.path.insert(0, os.path.join(P, "c64", "cinta"))
os.environ["VICE_EMU"] = "x128"
import vice_mb as V                                   # noqa: E402
import arranca as A                                   # noqa: E402
from prueba_cinta import corre                        # noqa: E402
from PIL import Image                                 # noqa: E402

G = os.path.join(D, "generado")
G8 = os.path.join(P, "c64", "presentacion", "generado_c128")
OPCIONES = 0x0BFF
fallos = []


def ok(c, m):
    print(("ok    " if c else "FAIL  ") + m, flush=True)
    if not c:
        fallos.append(m)


def main():
    args = sys.argv[1:]
    def opcion(n, d):
        if n in args:
            i = args.index(n); v = args[i + 1]; del args[i:i + 2]; return v
        return d
    teclas = opcion("--opciones", "")
    frames = int(opcion("--frames", "300"))
    unidad = opcion("--unidad", "1571")             # drive 8: both must work (a 1541 loads slowly, IRQs on)
    assert unidad in ("1571", "1541"), unidad
    final = "--final" in args
    if final: args.remove("--final")
    guarda = "--guarda" in args
    if guarda: args.remove("--guarda")
    out = args[0]
    os.makedirs(out, exist_ok=True)
    opc = 0
    for k in teclas:
        opc ^= {"1": 1, "2": 2, "3": 4, "4": 8}[k]
    ingles = opc & 1
    jdir = os.path.join(P, "c64", "juego_final", "c128_en" if ingles else "c128")
    img = open(os.path.join(jdir, "juego.bin"), "rb").read()
    img1 = open(os.path.join(jdir, "juego.bin.banco1"), "rb").read()
    e = V.etiquetas(os.path.join(jdir, "juego.lbl"))
    menu = V.etiquetas(os.path.join(G, "menu.lbl"))
    pres = V.etiquetas(os.path.join(G8, "abadia.lbl"))
    disco = os.path.join(D, "abadia128ks.d64")
    if guarda:                                         # (the save writes to the disk: a copy)
        import shutil
        shutil.copy(disco, os.path.join(out, "abadia128ks.d64")); disco = os.path.join(out, "abadia128ks.d64")
    with V.Vice(None, ["-sounddev", "dummy", "-warp", "-drive8type", unidad, "-drive8truedrive"], disco=disco,
                registro=os.path.join(out, "vice.log")) as v:
        r0, r1 = A.banco(v, "ram00"), A.banco(v, "ram01")
        lee = lambda a, n, b=r0: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, b))[1][2:2 + n]
        def foto(nombre):
            w, h, rgb, _ = v.foto()
            Image.frombytes("RGB", (w, h), bytes(rgb)).resize((2 * w, 2 * h), Image.NEAREST).save(os.path.join(out, nombre))
        def tecla(c):
            A.escribe_banco(v, r0, 0x034A, bytes([c])); A.escribe_banco(v, r0, 0x00D0, b"\x01")
        def sigue():
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
            return v.registros()[3]
        # the menu
        v.hasta(menu["tecla"], limite=900)
        ok(True, "the menu reached (the boot sector, M)")
        t = v.punto(menu["tecla"], temporal=False)
        for k in teclas:
            tecla(ord(k)); sigue()
        sigue()
        foto("menu.png")
        ok(lee(OPCIONES, 1)[0] == opc, f"the options after the keys {teclas!r}: {lee(OPCIONES, 1)[0]} (expected {opc})")
        # the presentation, then the game
        pts = {v.punto(pres["_kbhit"], temporal=False): "kbhit", v.punto(pres["_cgetc"], temporal=False): "cgetc",
               v.punto(e["principal_inicio"], temporal=False): "juego", t: "menu"}
        tecla(ord(" "))
        n = 0
        cuenta = {}
        while True:
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            v.s.settimeout(120)
            try:
                while not v.golpes: v._respuesta()
            except socket.timeout:
                v.s.settimeout(None); v.para(); r = v.registros()
                cpu, io = A.banco(v, "cpu"), A.banco(v, "io")
                sp = r[4]
                ok(False, f"stuck: no breakpoint in 120 s, PC ${r[3]:04X} SP {sp:02X} stack {lee(0x101 + sp, 8).hex()} "
                          f"$0314 {lee(0x314, 4).hex()} D019/D01A {lee(0xD019, 2, io).hex()} FF00 {lee(0xFF00, 1, cpu).hex()} "
                          f"D506 {lee(0xD506, 1, io).hex()}; passes {cuenta}")
                sys.exit(1)
            v.s.settimeout(None)
            hits = {pts[g] for g in v.golpes if g in pts}
            for h in hits: cuenta[h] = cuenta.get(h, 0) + 1
            if "juego" in hits:
                break
            if hits == {"menu"}:
                continue
            if hits & {"kbhit", "cgetc"} and lee(0x00D0, 1)[0] == 0:
                if n == 0:
                    foto("pergamino.png")
                tecla(0x20); n += 1
            if n > 50:
                ok(False, "the presentation never ended"); return
        ok(True, f"the game reached ({n} spaces given to the presentation)")
        mem = b"".join(lee(a, 0x1000) for a in range(0, 0x10000, 0x1000))
        esperada = bytearray(img)
        for bit, nom, n, nuevo in ((2, "cinta_paso", 1, b"\x0F"), (4, "cinta_pitido", 1, b"\x0F"),
                                   (8, "c128_ave_llamada", 3, b"\xEA\xEA\xEA")):
            if opc & bit:
                esperada[e[nom]:e[nom] + n] = nuevo
            ok(mem[e[nom]:e[nom] + n] == esperada[e[nom]:e[nom] + n],
               f"{nom}: {'off (a rest, or 3 NOPs)' if opc & bit else 'kept'}: {mem[e[nom]:e[nom] + n].hex()}")
        # (left out: the stage's $C000-$C3FF, the MMU's $FF00-$FF04, the 8502's port, the KERNAL's page $0A00, which the
        # stage puts back on purpose, and the two bytes the stage writes)
        fuera = (set(range(0xC000, 0xC400)) | set(range(0xFF00, 0xFF05)) | set(range(0x0A00, 0x0B00))
                 | {0, 1, e["plat_unidad"], e["plat_opciones"]})
        malos = [a for a in range(0x10000) if a not in fuera and mem[a] != esperada[a]]
        ok(not malos, f"block 0 as the {'English' if ingles else 'Spanish'} image"
           + (f": {len(malos)} bytes differ: " + " ".join(f"{a:04X}" for a in malos[:12]) if malos else ""))
        b1 = lee(0x1000, len(img1), r1)
        ok(b1 == img1, f"block 1's game data ({len(img1)} bytes from $1000) as juego.bin.banco1")
        ok(mem[e["plat_opciones"]] == opc, f"plat_opciones = {mem[e['plat_opciones']]} (expected {opc})")
        a = e["c128_ave_llamada"]
        if opc & 8:
            ok(mem[a:a + 3] == b"\xEA\xEA\xEA", f"the Ave Maria off: its call 3 NOPs: {mem[a:a + 3].hex()}")
        else:
            ave = open(os.path.join(jdir, "ave.bin"), "rb").read()
            ok(mem[a] == 0x20 and lee(e["ave_muestra"], len(ave), r1) == ave,
               f"the Ave Maria on: its call kept, its {len(ave)} samples in block 1 at ${e['ave_muestra']:04X}")
        ok(mem[e["plat_unidad"]] == 8, f"plat_unidad = {mem[e['plat_unidad']]} (drive 8)")
        if guarda:
            prueba_guarda(v, r0, lee, e, jdir, img)
            print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
            sys.exit(1 if fallos else 0)
        if final:
            prueba_final(v, r0, r1, lee, foto, e, jdir, img, opc, out)
            print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
            sys.exit(1 if fallos else 0)
        f = v.punto(e["cert_frame"], temporal=False)
        for i in range(frames):
            v.golpes.clear(); v.orden(V.CMD_EXIT)
            while not v.golpes: v._respuesta()
        foto(f"juego_frame_{frames}.png")
        ok(True, f"{frames} game frames run; the screen in juego_frame_{frames}.png")
    print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
    sys.exit(1 if fallos else 0)


TECLA = {"CONTROL": 0x17, "TAB": 0x44, "S": 0x3C, "L": 0x24}


def filas(*teclas):
    f = [0xFF] * 10
    for t in teclas:
        k = TECLA[t]; f[k >> 3] &= ~(1 << (k & 7)) & 0xFF
    return bytes(f)


def prueba_guarda(v, r0, lee, e, jdir, img):
    R_A, R_PC, R_SP, R_FL = 0, 3, 4, 5
    inc = {}
    for l in open(os.path.join(jdir, "mapa64.inc")):
        p = l.split()
        if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
    piezas = [(inc["D64_STATE_PART1"], 0x2BE8 - 0x28D0), (inc["D64_SPR_MONK_FACES"], 8),
              (inc["D64_GAME_BOOK_POISON_COUNT"], 0x98), (inc["D64_CHR_COMMAND_BUFFERS"], 0xE0)]
    def pon(*pares):
        v.orden(V.CMD_REGISTERS_SET, struct.pack("<BH", 0, len(pares)) + b"".join(struct.pack("<BBH", 3, i, x) for i, x in pares))
    q = img.index(b"\xB9", e["plat_teclado_fila"])         # plat_teclado_fila's `lee: lda filas,y`
    filas_dir, en_lee = img[q + 1] | img[q + 2] << 8, q
    pts = {v.punto(e[n], temporal=False): n for n in ("cert_frame", "plat_teclado_fila", "plat_disco_guarda",
                                                     "plat_disco_carga", "obj_fix_owner_pointers")}
    ret_pts = {}
    fase, f, f_fase, guardado, nada = 0, 0, 0, None, filas()
    codigo = img[e["obj_fix_owner_pointers"]:e["obj_fix_owner_pointers"] + 124]
    while fase < 8:
        v.golpes.clear(); v.orden(V.CMD_EXIT)
        v.s.settimeout(120)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            v.s.settimeout(None); v.para()
            ok(False, f"phase {fase}, frame {f}: no stop in 120 s (PC {v.registros()[R_PC]:04X})"); return
        v.s.settimeout(None)
        regs = v.registros()
        hits = {pts[g] for g in v.golpes if g in pts} | {ret_pts[g] for g in v.golpes if g in ret_pts}
        if "cert_frame" in hits:
            f += 1
            if fase == 0 and f >= 60: fase = 1
            elif fase == 3: fase = 4; f_fase = f; ok(True, f"the save menu left: the game's frame {f}")
            elif fase == 4 and f - f_fase >= 50: fase = 5
            elif fase == 7 and f - f_fase >= 200: fase = 8
        if "plat_teclado_fila" in hits:
            if regs[R_A] == 0:
                tt = {1: filas("CONTROL", "TAB"), 2: filas("S"), 5: filas("CONTROL", "TAB"), 6: filas("L")}.get(fase, nada)
                if fase == 1: fase = 2
                elif fase == 5: fase = 6
                A.escribe_banco(v, r0, filas_dir, tt)
                pon((2, 0), (R_PC, en_lee))
            continue
        if "plat_disco_guarda" in hits:
            guardado = [lee(a, n) for a, n in piezas]
            sp = regs[R_SP]
            r = (lee(0x0100 + ((sp + 1) & 0xFF), 1)[0] | lee(0x0100 + ((sp + 2) & 0xFF), 1)[0] << 8) + 1
            ret_pts[v.punto(r, temporal=True)] = "guardado"
            fase = 3
        if "guardado" in hits:
            ok(not (regs[R_FL] & 0x01), f"the save returned with C clear (frame {f})")
        if "plat_disco_carga" in hits:
            sp = regs[R_SP]
            r = (lee(0x0100 + ((sp + 1) & 0xFF), 1)[0] | lee(0x0100 + ((sp + 2) & 0xFF), 1)[0] << 8) + 1
            ret_pts[v.punto(r, temporal=True)] = "cargado"
            fase = 7; f_fase = f
        if "cargado" in hits:
            ok(not (regs[R_FL] & 0x01), f"the load returned with C clear: the file's length right (frame {f})")
        if "obj_fix_owner_pointers" in hits and guardado is not None:
            ok(lee(e["obj_fix_owner_pointers"], 124) == codigo, "obj_fix_owner_pointers's code intact after the load")
            ahora = [lee(x, n) for x, n in piezas]
            for (x, n), g, h in zip(piezas, guardado, ahora):
                dd = [k for k in range(n) if g[k] != h[k]]
                ok(not dd, f"the restored piece ${x:04X} ({n} bytes) as saved" + (f": {len(dd)} differ, first at +{dd[0]:02X}" if dd else ""))
            guardado = None
    ok(True, f"200 frames after the load (frame {f}): the game goes on")


def completo_mapa(m, jdir, img):
    """abadia128ks (-D COMPLETO): the state comes from the CPC 64 KiB game (estado_final.py), whose room table, blocks,
    heights and room links are the 64 KiB map's; the build's are the full game's (data/completo/datos): those blocks
    from the build's own image (block 1's room table from juego.bin.banco1), and the mirror's two pointers as
    game_init_mirror sets them on that data: obj_mirror_height_ptr = the library's list's FFh, obj_mirror_entry_ptr =
    the byte after 1F AA in room 72h (11h closed / 51h open, as the state's obj_mirror_closed says)."""
    inc, tam = {}, {}
    for l in open(os.path.join(jdir, "mapa64.inc")):
        q = l.split()
        if len(q) >= 3 and q[1] == "=" and q[2].startswith("$"): inc[q[0]] = int(q[2][1:], 16)
    blq = [l.split("\t")[0] for l in open(os.path.join(P, "..", "data", "completo", "datos", "completo.tsv"))
           if l.startswith("D64_")]
    for c in (l.rstrip("\n").split("\t") for l in open(os.path.join(jdir, "mapa64.tsv")) if not l.startswith("#")):
        if len(c) > 6: tam[c[0]] = int(c[4])
    b1img = open(os.path.join(jdir, "juego.bin.banco1"), "rb").read()
    for nom in blq:
        a, n = inc[nom], tam[nom]
        if nom == "D64_ISO_ROOM_TABLE": m[a:a + n] = b1img[a - 0x1000:a - 0x1000 + n]
        else: m[a:a + n] = img[a:a + n]
    p = inc["D64_CHR_FLOOR2_HEIGHTS"]                  # the library's list: its FFh
    while m[p] != 0xFF: p += 5 if m[p] & 8 else 4
    m[inc["D64_OBJ_MIRROR_HEIGHT_PTR"]:inc["D64_OBJ_MIRROR_HEIGHT_PTR"] + 2] = bytes([p & 255, p >> 8])
    s = inc["D64_ISO_ROOM_TABLE"]                      # room 72h, its record 1F AA 51
    for _ in range(0x72): s += m[s]
    q = s + 1
    while not (m[q] == 0x1F and m[q + 1] == 0xAA and m[q + 2] in (0x51, 0x11)): q += 1
    cerrado = m[inc["D64_OBJ_MIRROR_CLOSED"]] != 0
    m[q + 2] = 0x11 if cerrado else 0x51
    if not cerrado: m[p] = 0xFF
    m[inc["D64_OBJ_MIRROR_ENTRY_PTR"]:inc["D64_OBJ_MIRROR_ENTRY_PTR"] + 2] = bytes([(q + 2) & 255, (q + 2) >> 8])

def prueba_final(v, r0, r1, lee, foto, e, jdir, img, opc, out):
    import time
    sys.path.insert(0, os.path.join(P, "c64", "presentacion", "pruebas"))
    import estado_final
    m = bytearray(estado_final.memoria(os.path.join(out, "estado_final.bin"), juego=jdir))
    b1 = [(int(c[3], 16), int(c[4])) for c in (l.rstrip("\n").split("\t") for l in open(os.path.join(jdir, "mapa64.tsv"))
          if not l.startswith("#")) if len(c) > 6 and c[6] == "banco1"]
    completo_mapa(m, jdir, img)                        # (abadia128ks: the full game's map, not the 64 KiB state's)
    for a, n in b1:                                    # block 1's blocks to block 1; block 0 keeps its code there
        A.escribe_banco(v, r1, a, bytes(m[a:a + n]))
        m[a:a + n] = img[a:a + n]
    m[e["plat_opciones"]] = opc
    m[e["plat_unidad"]] = 8
    for bit, nom, nuevo in ((2, "cinta_paso", b"\x0F"), (4, "cinta_pitido", b"\x0F"), (8, "c128_ave_llamada", b"\xEA\xEA\xEA")):
        if opc & bit:
            m[e[nom]:e[nom] + len(nuevo)] = nuevo
    for a, z in ((0x0002, 0x0A00), (0x0B00, 0xFF00), (0xFF05, 0x10000)):   # (the KERNAL's page $0A00 kept)
        A.escribe_banco(v, r0, a, bytes(m[a:z]))
    A.arranca_juego(v, e["principal_inicio"])
    corre(v, e["game_check_end"])
    corre(v, e["plat_final"])
    pct = lee(0x067A, 3)
    ok(pct == b"100", f"the state of day 7, tercia, solved: game_check_end, \"{pct.decode('latin-1')}\" per cent, plat_final")
    foto("final_1_juego_100.png")
    corre(v, 0x1C0D)                                   # the KERNAL's "FINAL" loaded, its BASIC line's SYS
    prg = open(os.path.join(G8, "final.prg"), "rb").read()
    ok(lee(0x1C01, len(prg) - 2) == prg[2:], f"the KERNAL loaded \"FINAL\" ({len(prg) - 2} bytes at $1C01: final.prg) and runs it")
    fi = V.etiquetas(os.path.join(G8, "final.lbl"))
    corre(v, fi["_main"])
    ok(lee(OPCIONES, 1)[0] == opc, f"OPCIONES = {lee(OPCIONES, 1)[0]} at the ending's start (the menu's: {opc})")
    corre(v, fi["_musicstart"])
    v.orden(V.CMD_EXIT); time.sleep(3); v.registros()  # (3 s of the parchment, in warp)
    foto("final_2_pergamino.png")
    ok(True, "the ending's parchment on the screen: final_2_pergamino.png")


if __name__ == "__main__":
    main()
