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

"""A recording to its YouTube kit (everything into ~/Escritorio/abbeyofcrime/c64/, or ABADIA_ENTREGA/c64/, with its
thumbnails, its title, description, keywords and links, and the game beside the videos in a zip): the cut video (monta.py: title card, the loads cut, chapters inside), its text (textos.py), its
thumbnail (miniaturas.py, made from the loading picture) and the release's zip (empaqueta.py), into
~/Escritorio/abbeyofcrime/c64 (abadia64ks) or c128 (abadia128ks), with the names below.  Then the MP4 is decoded
whole (ffmpeg -v error) to check it.

    entrega.py GRABACION_DIR VIDEO.mkv es|en [--c128 | --p500]"""
import os, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ESCRITORIO = Path(os.environ.get("ABADIA_ENTREGA", os.path.expanduser("~/Escritorio/abbeyofcrime")))
NOMBRES = {("64", "en"): "Abbey_of_Crime_C64_English_full_playthrough_20261030",
           ("64", "es"): "La_Abadia_del_Crimen_C64_espanol_partida_completa_20261030",
           ("128", "en"): "Abbey_of_Crime_C128_English_full_playthrough_20261030",
           ("128", "es"): "La_Abadia_del_Crimen_C128_espanol_partida_completa_20261030",
           ("500", "en"): "Abbey_of_Crime_P500_English_full_playthrough_20261031",
           ("500", "es"): "La_Abadia_del_Crimen_P500_espanol_partida_completa_20261031"}


def main():
    args = sys.argv[1:]
    c128 = "--c128" in args
    if c128: args.remove("--c128")
    p500 = "--p500" in args
    if p500: args.remove("--p500")
    gdir, video, idioma = Path(args[0]), Path(args[1]), args[2]
    m = "500" if p500 else "128" if c128 else "64"
    dest = ESCRITORIO / ("p500" if p500 else "c128" if c128 else "c64")
    dest.mkdir(parents=True, exist_ok=True)
    base = dest / NOMBRES[(m, idioma)]
    opc = ["--p500"] if p500 else ["--c128"] if c128 else []
    zipf = dest / ("abadia128ks_p500.zip" if p500 else "abadia128ks_c128.zip" if c128 else "abadia64ks_c64.zip")
    py = [sys.executable, "-I"]
    subprocess.run(py + [str(HERE / "empaqueta.py"), str(zipf)] + opc, check=True)   # (first: its MD5 goes in the text)
    trabajo = HERE / "grabaciones" / f"montaje_{m}_{idioma}"
    trabajo.mkdir(exist_ok=True)
    mp4 = trabajo / (base.name + ".mp4")
    subprocess.run(py + [str(HERE / "monta.py"), str(gdir), str(video), idioma, str(mp4)] + opc, check=True)
    subprocess.run(py + [str(HERE / "textos.py"), idioma, str(mp4), str(base) + ".txt"] + opc, check=True)
    subprocess.run(py + [str(HERE / "miniaturas.py"), idioma,
                         str(HERE / "grabaciones" / f"carga{m if m != '64' else ''}_{idioma}.png"), str(base) + ".png"] + opc,
                   check=True)
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(mp4), "-f", "null", "-"], capture_output=True, text=True)
    if r.stderr.strip():
        sys.exit(f"{mp4}: decoding errors:\n{r.stderr[:2000]}")
    shutil.move(str(mp4), str(base) + ".mp4")
    print("delivered:", *sorted(str(p) for p in dest.glob(base.name + ".*")), zipf, sep="\n  ")


if __name__ == "__main__":
    main()
