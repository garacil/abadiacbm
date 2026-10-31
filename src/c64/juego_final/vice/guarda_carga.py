"""The save and load menu (CTRL + TAB, S / L: the disk's ABADIA64.BS1) of the C64 game in VICE, deterministic: the
game's image written into the RAM (as arranca.py), the disk attached to a true 1541 for the KERNAL's SAVE and LOAD;
the keys answered at plat_teclado_escanea (the CPC rows in plat_filas, as c64/certifica's driver does):
  frames 1-60 nothing; CONTROL + TAB (the menu); S until plat_disco_guarda runs; nothing until the game's next frame;
  50 frames; CONTROL + TAB; L until plat_disco_carga runs; nothing; 200 frames.
Checked: the save and the load reached and returned (C clear: the file's length right), obj_fix_owner_pointers's code
the image's at its call after the load (estado_texto.s: at $0100 in the CABEZAS build, where disco.s kept the
KERNAL's part before), the restored state (the gathered pieces: c64/juego_final/principal.s piezas_r) equal to what
was saved, and every frame reached within 30 s.   guarda_carga.py JUEGO_DIR DISK.d64 OUT"""
import os, shutil, socket, struct, sys, tempfile
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
import vice_mb as V
import arranca as A

R_A, R_PC, R_SP, R_FL = 0, 3, 4, 5
TECLA = {"CONTROL": 0x17, "TAB": 0x44, "S": 0x3C, "L": 0x24, "ESC": 0x42}


def filas(*teclas):
    f = [0xFF] * 10
    for t in teclas:
        k = TECLA[t]; f[k >> 3] &= ~(1 << (k & 7)) & 0xFF
    return bytes(f)


def main():
    juego, disco, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    img = open(os.path.join(juego, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(juego, "juego.lbl"))
    inc = {}
    for l in open(os.path.join(juego, "mapa64.inc")):
        p = l.split()
        if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
    piezas = [(inc["D64_STATE_PART1"], 0x2BE8 - 0x28D0), (inc["D64_SPR_MONK_FACES"], 8),
              (inc["D64_GAME_BOOK_POISON_COUNT"], 0x98), (inc["D64_CHR_COMMAND_BUFFERS"], 0xE0)]
    tmp = tempfile.mkdtemp(prefix="guarda_carga_")
    copia = os.path.join(tmp, "disco.d64"); shutil.copy(disco, copia)
    fallos = []
    def ok(c, m):
        print(("ok    " if c else "FAIL  ") + m, flush=True)
        if not c: fallos.append(m)
    try:
        with V.Vice(None, ["-sounddev", "dummy", "-warp", "-drive8type", "1541", "-drive8truedrive"], disco=copia,
                    registro=os.path.join(out, "vice.log")) as v:
            v.hasta(0xE5CD, limite=120)
            ram = A.banco(v, "ram")
            A.escribe_banco(v, ram, 0x0002, img[2:0x10000])
            A.arranca_juego(v, e["principal_inicio"])
            lee = lambda a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, ram))[1][2:2 + n]
            def pon(*pares):
                v.orden(V.CMD_REGISTERS_SET, struct.pack("<BH", 0, len(pares)) + b"".join(struct.pack("<BBH", 3, i, x) for i, x in pares))
            fila = "plat_teclado_escanea" not in e     # the earlier platform: plat_teclado_fila
            if fila:                                   # its `lee: lda filas,y / rts` (the first absolute,Y load)
                q = img.index(b"\xB9", e["plat_teclado_fila"])
                filas_dir, en_lee = img[q + 1] | img[q + 2] << 8, q
            pts = {v.punto(e[n], temporal=False): n for n in ("cert_frame", "plat_teclado_fila" if fila else "plat_teclado_escanea",
                                                             "plat_disco_guarda", "plat_disco_carga", "obj_fix_owner_pointers")}
            ret_pts = {}
            fase, f, f_fase, guardado, nada = 0, 0, 0, None, filas()
            codigo = img[e["obj_fix_owner_pointers"]:e["obj_fix_owner_pointers"] + 124] if e["obj_fix_owner_pointers"] >= 0x0200 else None
            while fase < 8:
                v.golpes.clear()
                v.orden(V.CMD_EXIT)
                v.s.settimeout(60)
                try:
                    while not v.golpes: v._respuesta()
                except socket.timeout:
                    ok(False, f"phase {fase}, frame {f}: no stop in 60 s (PC {v.registros()[R_PC]:04X})"); break
                finally:
                    v.s.settimeout(None)
                regs = v.registros(); pc = regs[R_PC]
                hits = {pts[g] for g in v.golpes if g in pts} | {ret_pts[g] for g in v.golpes if g in ret_pts}
                if "cert_frame" in hits:
                    f += 1
                    if fase == 0 and f >= 60: fase = 1
                    elif fase == 3: fase = 4; f_fase = f; ok(True, f"the save menu left: the game's frame {f}")
                    elif fase == 4 and f - f_fase >= 50: fase = 5
                    elif fase == 7 and f - f_fase >= 200: fase = 8
                if "plat_teclado_fila" in hits:
                    if regs[R_A] == 0:                         # row 0, the scan: this test's rows instead
                        t = {1: filas("CONTROL", "TAB"), 2: filas("S"), 5: filas("CONTROL", "TAB"), 6: filas("L")}.get(fase, nada)
                        if fase == 1: fase = 2
                        elif fase == 5: fase = 6
                        A.escribe_banco(v, ram, filas_dir, t)
                        pon((2, 0), (R_PC, en_lee))           # (Y: VICE's register id 2)
                    continue
                if "plat_teclado_escanea" in hits:
                    t = {1: filas("CONTROL", "TAB"), 2: filas("S"), 5: filas("CONTROL", "TAB"), 6: filas("L")}.get(fase, nada)
                    if fase == 1: fase = 2                                  # (the menu opens on this scan)
                    elif fase == 5: fase = 6
                    A.escribe_banco(v, ram, e["plat_filas"], t)
                    sp = regs[R_SP]
                    r = lee(0x0100 + ((sp + 1) & 0xFF), 1)[0] | lee(0x0100 + ((sp + 2) & 0xFF), 1)[0] << 8
                    vacio = t == nada
                    pon((R_A, 0 if vacio else 1), (R_FL, (regs[R_FL] & ~0x02 & 0xFF) | (0x02 if vacio else 0)),
                        (R_PC, (r + 1) & 0xFFFF), (R_SP, (sp + 2) & 0xFF))
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
                    a = e["obj_fix_owner_pointers"]
                    esperado = codigo if codigo is not None else None
                    if a < 0x0200:                                   # the stack page's copy: the image's own bytes
                        mp = open(os.path.join(juego, "juego.map")).read()
                        esperado = None
                    actual = lee(a, 124)
                    if a < 0x0200:
                        # the code at $0100 is the start-up segment's copy: compare with the image's CODEINICIO bytes
                        carga = e["pila_carga"]
                        esperado = img[carga:carga + 124]
                    ok(actual == esperado, f"obj_fix_owner_pointers's code at ${a:04X} intact when it is called after the load")
                    ahora = [lee(x, n) for x, n in piezas]
                    for (x, n), g, h in zip(piezas, guardado, ahora):
                        d = [k for k in range(n) if g[k] != h[k]]
                        ok(not d, f"the restored piece ${x:04X} ({n} bytes) as saved" + (f": {len(d)} differ, first at +{d[0]:02X}" if d else ""))
            if fase == 8: ok(True, f"200 frames after the load (frame {f}): the game goes on")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("all checks passed" if not fallos else f"{len(fallos)} checks failed")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
