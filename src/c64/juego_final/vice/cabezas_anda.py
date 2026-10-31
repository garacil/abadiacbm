"""The heads' build (milestone H7 on the C64 hardware disk; H10 on the C128: cabezas128.s) in VICE with Guillermo
walking: as arranca.py the image written into the RAM and started at principal_inicio (the C128: x128, block 0 and
block 1 from juego.bin.banco1, as c64/certifica/vice_cert.py); the CPC keys held as the host's scripts do (the
keys-down bitmap D64_SYS_KEYS_DOWN and the new press in D64_SYS_KEYS_PENDING written right after sys_read_keyboard:
game_input_and_mirror + 3).  Walk: forward (CPC key 0) with turns right (key 1) and left (key 8).  Checked: every
frame reached within 30 s (no hang); the heads' tables unchanged from frame 2 to the end (the C64: TAB_A, G_CAB_TAB_B;
the C128: G_CABEZAS_NEGRO, the blacks); the frames with the hardware sprites 0/1 on ($D015).  Pictures at some
frames.   cabezas_anda.py JUEGO_DIR OUT FRAMES"""
import os, socket, struct, sys
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../.."))
sys.path.insert(0, os.path.join(P, "plataforma/pruebas")); sys.path.insert(0, os.path.join(P, "juego_final/vice"))
juego, out, total = sys.argv[1], sys.argv[2], int(sys.argv[3])
C128 = os.path.exists(os.path.join(juego, "juego.bin.banco1"))
if C128: os.environ["VICE_EMU"] = "x128"
import vice_mb as V
import arranca as A
os.makedirs(out, exist_ok=True)
img = open(os.path.join(juego, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(juego, "juego.lbl"))
inc = {}
for l in open(os.path.join(juego, "mapa64.inc") if C128 else os.path.join(P, "juego_final", "mapa64.inc")):   # (the C64's: one map)
    p = l.split()
    if len(p) >= 3 and p[1] == "=" and p[2].startswith("$"): inc[p[0]] = int(p[2][1:], 16)
TECLAS, PEND = inc["D64_SYS_KEYS_DOWN"], inc["D64_SYS_KEYS_PENDING"]
if C128: TABLAS = [(inc["G_CABEZAS_NEGRO"], 780)]
elif "G_CAB_RT" in inc: TABLAS = [(inc["G_CAB_RT"] + 156, 16), (inc["G_CAB_TAB_B"], 26)]
else: TABLAS = []
def teclas(f):
    """the CPC keys down on frame f: (row, bit) list"""
    k = (f // 300) % 4
    if f < 20: return []
    if 150 <= f % 300 < 156: return [(0, 1)] if k % 2 == 0 else [(1, 0)]     # a turn: right, then left
    return [(0, 0)]                                                           # forward
fotos = {60, 300, 700, 1200, total}
ok = True
with V.Vice(None, ["-sounddev", "dummy", "-warp"], registro=os.path.join(out, "vice.log")) as v:
    if C128:
        v.hasta(0xC25E, limite=120)                                 # the KERNAL's idle loop
        ram, io = A.banco(v, "ram00"), A.banco(v, "io")
        cpu = A.banco(v, "cpu")
        v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xFF00, 0xFF00, 0, cpu) + b"\x3e")
        A.escribe_banco(v, ram, 0x0002, img[2:0xFF00]); A.escribe_banco(v, ram, 0xFF05, img[0xFF05:])
        A.escribe_banco(v, A.banco(v, "ram01"), 0x1000, open(os.path.join(juego, "juego.bin.banco1"), "rb").read())
    else:
        v.hasta(0xE5CD, limite=120)
        ram, io = A.banco(v, "ram"), A.banco(v, "io")
        A.escribe_banco(v, ram, 0x0002, img[2:0x10000])
    A.arranca_juego(v, e["principal_inicio"])
    lee = lambda b, a, n: v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, a + n - 1, 0, b))[1][2:2 + n]
    pf = v.punto(e["game_input_and_mirror"], temporal=False)
    pk = v.punto(e["game_input_and_mirror"] + 3, temporal=False)
    f, ref, encendidos, antes = 0, None, [0, 0], []
    while f < total:
        v.golpes.clear()
        v.orden(V.CMD_EXIT)
        v.s.settimeout(30)
        try:
            while not v.golpes: v._respuesta()
        except socket.timeout:
            v.orden(V.CMD_PING)
            v.captura(os.path.join(out, f"sin_frame_{f}.png"))
            pila = lee(ram, 0x0100, 0x100)
            sp = v.registros()[4]
            rets = [(pila[(sp + 1 + 2 * i) & 0xFF] | pila[(sp + 2 + 2 * i) & 0xFF] << 8) + 1 for i in range(6)]
            fin = e.get("game_check_end", 0)
            dentro = [r for r in rets if fin <= r < fin + 0x100]
            if dentro:
                print(f"end   frame {f}: the game is over (a return into game_check_end at {dentro[0]:04X}: its wait for SPACE)")
            else:
                print(f"FAIL  frame {f}: no frame point in 30 s (the game hung); PC {v.registros()[3]:04X}, returns " + " ".join(f"{r:04X}" for r in rets)); ok = False
                for n in filter(None, os.environ.get("CAB_DIAG", "").split(",")):   # names "label" or "label:bytes"
                    nom, _, k = n.partition(":")
                    a = int(nom[1:], 16) if nom.startswith("$") else e[nom]
                    print(f"      {nom} ${a:04X}: {lee(ram, a, int(k or 1)).hex(' ')}")
            break
        finally:
            v.s.settimeout(None)
        if pk in v.golpes:
            t = teclas(f)
            if t:
                fila = bytearray(lee(ram, TECLAS, 10)); pen = bytearray(lee(ram, PEND, 10))
                for r, b in t:
                    fila[r] &= ~(1 << b) & 0xFF
                    if (r, b) not in antes: pen[r] &= ~(1 << b) & 0xFF
                A.escribe_banco(v, ram, TECLAS, bytes(fila)); A.escribe_banco(v, ram, PEND, bytes(pen))
            antes = t
        if pf in v.golpes:
            f += 1
            tab = b"".join(lee(ram, a, n) for a, n in TABLAS)
            if f == 2: ref = tab
            elif ref is not None and tab != ref:
                print(f"FAIL  frame {f}: the heads' tables changed"); ok = False; ref = tab
            d015 = lee(io, 0xD015, 1)[0]
            for s in (0, 1):
                if d015 & (1 << s): encendidos[s] += 1
            if f in fotos:
                v.captura(os.path.join(out, f"frame_{f}.png"))
                vic = lee(io, 0xD000, 0x11)
                print(f"      frame {f}: $D015 {d015:02X}, " + ", ".join(f"sprite {s} at {vic[2 * s] | ((vic[16] >> s) & 1) << 8},{vic[2 * s + 1]}"
                                                                for s in range(8) if d015 & (1 << s)))
print(f"{'ok  ' if ok else 'FAIL'}  {f} frames walked; hardware sprite 0 on in {encendidos[0]} frames, sprite 1 in {encendidos[1]}")
sys.exit(0 if ok else 1)
