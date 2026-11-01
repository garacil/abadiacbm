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

"""The YouTube cut of a real-time recording of sesion64.py (the loading picture for about 15
seconds, no waits for the loads: they are cut).  From the session's marcas.json (wall-clock times; the
video's 0 is the mark "grabacion", when ffmpeg started) four pieces are kept and the disk's loads between them cut:

  1. the menu: from 1 s before it to 1.5 s after its SPACE (in English the language switched on the screen);
  2. the introduction parchment, whole, its last page held, the SPACE, and 15 s of the loading picture
     (the game's load under it: the rest of it is cut);
  3. the game: from 1.5 s before principal_inicio (the picture gives way to the game) to 4 s after plat_final (the
     score bar's "loading the ending");
  4. the ending parchment, whole, and its last page held 15 s.

Out: the MP4 (1920x1080: the picture scaled to 1080 lines, black at the sides; H.264, AAC 192 kb/s, 50 fps), its
chapters (YouTube's "m:ss title" lines, also inside the MP4) by the session's day and hour marks, and a JSON of the
pieces.  Before them, the title card (a title card at the head of each video saying what
it is): 7 s, faded in and out, silent: the loading picture (captura_carga.py) and what the video is.
    monta.py GRABACION_DIR VIDEO.mkv es|en OUT.mp4 [--c128 | --p500] [--prueba SECONDS: only the first seconds of each piece]"""
import json, os, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PORTADA_S = 7
FUENTES = [f for f in ("/usr/share/fonts/TTF/Arial-Black.ttf", "/usr/share/fonts/liberation/LiberationSans-Bold.ttf",
                       "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf") if os.path.exists(f)]
PORTADA = {"es": ("La abadía del crimen", "Commodore {m}  ·  {r}", "Partida completa, en español",
                  "Grabada en tiempo real en el emulador VICE  ·  versión de Germán Luis Aracil Boned  ·  abbeyofcrime.com"),
           "en": ("The Abbey of Crime", "Commodore {m}  ·  {r}", "Full playthrough, in English",
                  "Recorded in real time in the VICE emulator  ·  version by Germán Luis Aracil Boned  ·  abbeyofcrime.com")}


def portada(idioma, c128, captura, salida, p500=False):
    """the title card, 1920x1080: the loading picture (VICE's 384x272 screenshot, the picture at 32,35) at 4:3 above,
    the lines below"""
    lienzo = Image.new("RGB", (1920, 1080), (0, 0, 0))
    img = Image.open(captura).convert("RGB").crop((32, 35, 352, 235)).resize((880, 660), Image.BOX)
    lienzo.paste(img, ((1920 - 880) // 2, 50))
    d = ImageDraw.Draw(lienzo)
    l1, l2, l3, l4 = PORTADA[idioma]
    l2 = l2.format(m="P500" if p500 else "128" if c128 else "64", r="abadia128ks" if c128 or p500 else "abadia64ks")
    if p500:                                            # the P500: the computer drawn at the left of the picture
        sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
        from ordenador_p500 import dibuja
        maq = dibuja(440)
        lienzo.paste(maq, ((520 - maq.width) // 2, 380 - maq.height // 2), maq)
    for texto, tam, y, color in ((l1, 64, 735, (255, 232, 130)), (l2, 44, 830, (255, 255, 255)),
                                 (l3, 44, 900, (255, 255, 255)), (l4, 24, 1000, (170, 170, 170))):
        f = ImageFont.truetype(FUENTES[0], tam)
        w = d.textlength(texto, font=f)
        d.text(((1920 - w) / 2, y), texto, font=f, fill=color)
    lienzo.save(salida)

HORAS = {"es": ["Noche", "Prima", "Tercia", "Sexta", "Nona", "Vísperas", "Completas"],
         "en": ["Night", "Prime", "Terce", "Sext", "Nones", "Vespers", "Compline"]}
TEXTOS = {"es": dict(menu="Menú de inicio", intro="Pergamino inicial", carga="Pantalla de carga", dia="Día",
                     final="Pergamino final"),
          "en": dict(menu="Start menu", intro="Introduction parchment", carga="Loading screen", dia="Day",
                     final="Ending parchment")}


def mmss(t):
    t = int(t)
    return f"{t // 3600}:{t // 60 % 60:02}:{t % 60:02}" if t >= 3600 else f"{t // 60}:{t % 60:02}"


def main():
    args = sys.argv[1:]
    prueba = None
    if "--prueba" in args:
        i = args.index("--prueba"); prueba = float(args[i + 1]); del args[i:i + 2]
    c128 = "--c128" in args
    if c128: args.remove("--c128")
    p500 = "--p500" in args
    if p500: args.remove("--p500")
    gdir, video, idioma, salida = Path(args[0]), Path(args[1]), args[2], Path(args[3])
    tarjeta = salida.with_suffix(".portada.png")
    portada(idioma, c128, HERE / "grabaciones" / f"carga{'500' if p500 else '128' if c128 else ''}_{idioma}.png", tarjeta, p500)
    marcas = json.loads((gdir / "marcas.json").read_text())
    m = {}
    for nombre, t in marcas:
        m.setdefault(nombre, t)
    t0 = m["grabacion"]
    rel = lambda n: m[n] - t0
    # (sessions press SPACE as soon as the parchment ends: its last page is held here, 2.5 s
    # frozen; the earlier recordings held it 4 s in the machine)
    congela = 2.5 if rel("carga_juego") - rel("introduccion_fin") < 1 else 0
    piezas = [("menu", rel("menu") - 1, rel("menu_espacio") + 1.5),
              ("intro", rel("introduccion") - 1, rel("carga_juego") + 15),
              ("juego", rel("juego") - 1.5, rel("final_carga") + 4),
              ("final", rel("final") - 1, rel("final_fin") + 15)]
    for i in range(1, len(piezas)):        # (the P500 starts its parchment 1.3 s after the menu's space, less than the
        n, a, b = piezas[i]                 #  margins above: a piece then begins where the one before ends)
        if a < piezas[i - 1][2]:
            piezas[i] = (n, piezas[i - 1][2], b)
    for i in range(1, len(piezas)):
        assert piezas[i][1] >= piezas[i - 1][2], f"the pieces overlap: {piezas[i - 1]} {piezas[i]}"
    if prueba:
        piezas = [(n, a, min(b, a + prueba)) for n, a, b in piezas]
    # the chapters: the pieces, and inside the game each hour (the session's marks diaD_horaH)
    T = TEXTOS[idioma]
    def edit(t):                                        # a recording time in the cut video (after the title card)
        acc = PORTADA_S
        for k, (_, a, b) in enumerate(piezas):
            extra = congela if (k == 1 and t > rel("introduccion_fin") + 0.3) else 0
            if a <= t <= b: return acc + t - a + extra
            acc += b - a + (congela if k == 1 else 0)
        return None
    caps = [(0, T["menu"]), (edit(piezas[1][1]), T["intro"]), (edit(rel("carga_juego")), T["carga"])]
    for nombre, t in marcas:
        if nombre.startswith("dia") and "_hora" in nombre:
            d, h = nombre[3:].split("_hora")
            e = edit(t - t0)
            if e is not None:
                caps.append((e, f"{T['dia']} {d}, {HORAS[idioma][int(h)]}"))
    caps.append((edit(piezas[3][1]), T["final"]))
    caps = [c for c in caps if c[0] is not None]
    limpios = []                                        # YouTube: 10 s at least each (a shorter one merges into the next)
    for k, (t, titulo) in enumerate(caps):
        siguiente = caps[k + 1][0] if k + 1 < len(caps) else 1e9
        if siguiente - t >= 10 or k + 1 == len(caps):
            if limpios and limpios[-1][0] == t: limpios[-1] = (t, titulo)
            else: limpios.append((t, titulo))
    limpios[0] = (0, limpios[0][1])                     # (YouTube: the first chapter at 0:00)
    total = PORTADA_S + sum(b - a for _, a, b in piezas) + congela
    # the cut: trim and atrim per piece, concatenated, scaled to 1080 lines, padded to 1920
    f = []
    for k, (_, a, b) in enumerate(piezas):
        if k == 1 and congela:      # the intro: its last page frozen, then the loading picture
            fin = rel("introduccion_fin") + 0.3
            f.append(f"[0:v]trim=start={a:.3f}:end={fin:.3f},setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration={congela}[v{k}a]")
            f.append(f"[0:a]atrim=start={a:.3f}:end={fin:.3f},asetpts=PTS-STARTPTS,apad=pad_dur={congela}[a{k}a]")
            f.append(f"[0:v]trim=start={fin:.3f}:end={b:.3f},setpts=PTS-STARTPTS[v{k}b]")
            f.append(f"[0:a]atrim=start={fin:.3f}:end={b:.3f},asetpts=PTS-STARTPTS[a{k}b]")
            f.append(f"[v{k}a][a{k}a][v{k}b][a{k}b]concat=n=2:v=1:a=1[v{k}][a{k}]")
            continue
        f.append(f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=PTS-STARTPTS[v{k}]")
        f.append(f"[0:a]atrim=start={a:.3f}:end={b:.3f},asetpts=PTS-STARTPTS[a{k}]")
    f.append("".join(f"[v{k}][a{k}]" for k in range(len(piezas))) + f"concat=n={len(piezas)}:v=1:a=1[vc][ac]")
    f.append("[vc]scale=-2:1080:flags=lanczos,pad=1920:1080:(ow-iw)/2:0:black,fps=50,format=yuv420p,setsar=1[vo]")
    f.append(f"[2:v]fps=50,format=yuv420p,setsar=1,fade=t=in:st=0:d=0.8,fade=t=out:st={PORTADA_S - 0.8}:d=0.8[vt]")
    # the sound: VICE's SID through the recording's null sink peaks about -21 dB: a fixed gain that brings the cut's
    # peak to -1 dB (measured first on the kept pieces; no compression, the dynamics as they are)
    solo_audio = [x.replace("concat=n=2:v=1:a=1[v1][a1]", "concat=n=2:v=0:a=1[a1]").replace("[v1a]", "").replace("[v1b]", "")
                  for x in f if x.startswith("[0:a]") or x.startswith("[v1a]")]
    solo_audio.append("".join(f"[a{k}]" for k in range(len(piezas))) + f"concat=n={len(piezas)}:v=0:a=1,volumedetect[am]")
    medida = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(video), "-filter_complex", ";".join(solo_audio),
                             "-map", "[am]", "-f", "null", "-"], capture_output=True, text=True)
    pico = float([l for l in medida.stderr.splitlines() if "max_volume" in l][-1].split()[-2])
    ganancia = -1.0 - pico
    f.append(f"[ac]volume={ganancia:.1f}dB[ao]")
    f.append("[vt][3:a][vo][ao]concat=n=2:v=1:a=1[vf][af]")
    meta = salida.with_suffix(".capitulos.ffmeta")
    with open(meta, "w") as o:
        o.write(";FFMETADATA1\n")
        for k, (t, titulo) in enumerate(limpios):
            fin = limpios[k + 1][0] if k + 1 < len(limpios) else total
            o.write(f"[CHAPTER]\nTIMEBASE=1/1000\nSTART={int(t * 1000)}\nEND={int(fin * 1000)}\ntitle={titulo}\n")
    cmd = ["ffmpeg", "-hide_banner", "-y", "-i", str(video), "-i", str(meta),
           "-loop", "1", "-framerate", "50", "-t", str(PORTADA_S), "-i", str(tarjeta),
           "-f", "lavfi", "-t", str(PORTADA_S), "-i", "anullsrc=r=48000:cl=stereo",
           "-filter_complex", ";".join(f),
           "-map", "[vf]", "-map", "[af]", "-map_metadata", "1", "-map_chapters", "1",
           "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-profile:v", "high", "-g", "100",
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", str(salida)]
    subprocess.run(cmd, check=True)
    caps_txt = "\n".join(f"{mmss(t)} {titulo}" for t, titulo in limpios)
    salida.with_suffix(".capitulos.txt").write_text(caps_txt + "\n")
    salida.with_suffix(".piezas.json").write_text(json.dumps(dict(piezas=piezas, total=total, capitulos=limpios,
                                                                  pico_db=pico, ganancia_db=round(ganancia, 1)),
                                                             ensure_ascii=False, indent=1))
    print(caps_txt)
    print(f"{salida}: {mmss(total)}")


if __name__ == "__main__":
    main()
