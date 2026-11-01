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

"""A delivered video's title card made again (monta.py's portada, with what it shows now) and put in place of the
video's first PORTADA_S seconds; the rest of the video copied as it is, not encoded again (the video has a key frame
at PORTADA_S: checked), and the sound, the chapters and the metadata are the video's own.  The new card is encoded as
monta.py encodes it, and the two parts must share the same H.264 parameters (checked).  Before the video is replaced:
the same number of frames, the same sound packets, the same frames after the card (decoded and compared at the
start, the middle and the end), and no decoding error in the whole new video.

    cambia_portada.py VIDEO.mp4 es|en [--c128 | --p500]"""
import hashlib, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from monta import portada, PORTADA_S


def sale(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def fotogramas(mp4):
    return int(sale("ffprobe", "-v", "error", "-count_packets", "-select_streams", "v:0", "-show_entries",
                    "stream=nb_read_packets", "-of", "csv=p=0", str(mp4)).strip())


def huella(mp4, desde, dur, que="v:0"):
    """the md5 of the decoded frames (or sound) from desde for dur seconds"""
    return sale("ffmpeg", "-v", "error", "-ss", str(desde), "-i", str(mp4), "-t", str(dur), "-map", f"0:{que}",
                "-f", "md5", "-").strip()


def cabeceras(mp4):
    """the H.264 parameter sets the decoder is given (the sample entry's), and x264's settings"""
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(mp4), "-map", "0:v:0", "-frames:v", "1", "-c", "copy",
                        "-bsf:v", "h264_mp4toannexb", "-f", "h264", "-"], check=True, capture_output=True).stdout
    nal = [n for n in r.split(b"\x00\x00\x01") if n]
    sps_pps = b"".join(n.rstrip(b"\x00") for n in nal if n[0] & 0x1F in (7, 8))
    sei = [n for n in nal if n[0] & 0x1F == 6 and b"x264" in n]
    ajustes = sei[0][sei[0].index(b"x264"):].split(b"\x00")[0] if sei else b""
    return hashlib.md5(sps_pps).hexdigest(), ajustes


def main():
    args = sys.argv[1:]
    c128 = "--c128" in args
    if c128: args.remove("--c128")
    p500 = "--p500" in args
    if p500: args.remove("--p500")
    mp4, idioma = Path(args[0]).resolve(), args[1]
    m = "500" if p500 else "128" if c128 else ""
    claves = sale("ffprobe", "-v", "error", "-select_streams", "v:0", "-read_intervals", f"{PORTADA_S - 1}%+2",
                  "-show_entries", "frame=pts_time,key_frame", "-of", "csv=p=0", str(mp4)).split()
    if f"1,{PORTADA_S:.6f}" not in claves:
        sys.exit(f"{mp4}: no key frame at {PORTADA_S} s: the rest cannot be copied as it is")
    total = fotogramas(mp4)
    with tempfile.TemporaryDirectory(dir=mp4.parent) as tmp:
        tmp = Path(tmp)
        tarjeta = tmp / "portada.png"
        portada(idioma, c128, HERE / "grabaciones" / f"carga{m}_{idioma}.png", tarjeta, p500)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-framerate", "50", "-t", str(PORTADA_S),
                        "-i", str(tarjeta), "-vf", f"fps=50,format=yuv420p,setsar=1,fade=t=in:st=0:d=0.8,"
                        f"fade=t=out:st={PORTADA_S - 0.8}:d=0.8", "-an",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-profile:v", "high", "-g", "100",
                        "-video_track_timescale", "12800", str(tmp / "portada.mp4")], check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(PORTADA_S), "-i", str(mp4), "-map", "0:v:0",
                        "-c", "copy", "-video_track_timescale", "12800", str(tmp / "resto.mp4")], check=True)
        a, b = cabeceras(tmp / "portada.mp4"), cabeceras(tmp / "resto.mp4")
        if a[0] != b[0]:
            sys.exit(f"the card's H.264 parameter sets differ from the video's:\n  {a[1]!r}\n  {b[1]!r}")
        assert fotogramas(tmp / "portada.mp4") == PORTADA_S * 50
        assert fotogramas(tmp / "resto.mp4") == total - PORTADA_S * 50, "the rest does not start at the key frame"
        (tmp / "lista.txt").write_text("file 'portada.mp4'\nfile 'resto.mp4'\n")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(tmp / "lista.txt"),
                        "-c", "copy", str(tmp / "video.mp4")], check=True)
        nuevo = tmp / mp4.name
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp / "video.mp4"), "-i", str(mp4),
                        "-map", "0:v:0", "-map", "1:a:0", "-map_metadata", "1", "-map_chapters", "1", "-c", "copy",
                        "-movflags", "+faststart", str(nuevo)], check=True)
        # the checks
        assert fotogramas(nuevo) == total, "frames"
        assert huella(nuevo, 0, 10 ** 6, "a:0") == huella(mp4, 0, 10 ** 6, "a:0"), "sound"
        dur = float(sale("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(mp4)))
        for desde in (PORTADA_S, round(dur / 2), int(dur) - 8):
            assert huella(nuevo, desde, 5) == huella(mp4, desde, 5), f"the frames from {desde} s"
        cap = lambda f: json.loads(sale("ffprobe", "-v", "error", "-show_chapters", "-of", "json", str(f)))["chapters"]
        assert [(c["start_time"], c["tags"]["title"]) for c in cap(nuevo)] == \
               [(c["start_time"], c["tags"]["title"]) for c in cap(mp4)], "chapters"
        r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(nuevo), "-f", "null", "-"], capture_output=True, text=True)
        if r.stderr.strip():
            sys.exit(f"{nuevo}: decoding errors:\n{r.stderr[:2000]}")
        shutil.move(str(nuevo), str(mp4))
    print(mp4, "the title card replaced:", total, "frames, the rest as it was")


if __name__ == "__main__":
    main()
