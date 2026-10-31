#!/usr/bin/env python3
"""Check the idle flute on the real 6510/SID in VICE, without modifying the disk.

    flauta.py OUTDIR [--solo-unidades] [--graba] [--antes BASELINE_DIR]

The SID dump, not its write-only registers read back, is the source of truth.
Unit cases cover tone/noise, note frequencies, gate and ADSR, the return to
footsteps/beeps, reset, and preservation of channels A/B and the caller's X/Y.
The normal run also starts the actual game and waits for its own idle music.
--graba records twelve seconds after that music starts, at PAL 100%, no warp;
--antes adds the same scene from an older juego.bin/juego.lbl directory.
"""
from pathlib import Path
import argparse
import json
import re
import struct
import sys
import wave

D = Path(__file__).resolve().parent
H = D.parent
sys.path.insert(0, str(H.parent / "plataforma/pruebas"))
from arranca import V, banco, escribe_banco


def lee(v, bank, a, b):
    _, data = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, a, b, 0, bank))
    return data[2:2 + b - a + 1]


def run_to(v, address):
    checkpoint = v.punto(address, temporal=False)
    try:
        v.golpes.discard(checkpoint)
        v.orden(V.CMD_EXIT)
        v.s.settimeout(45)
        while checkpoint not in v.golpes:
            if v.jams:
                raise AssertionError("CPU JAM")
            v._respuesta()
        v.para()
    finally:
        v.s.settimeout(None)
        v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", checkpoint))


def inject(v, image):
    v.hasta(0xE5CD, limite=45)
    ram = banco(v, "ram")
    escribe_banco(v, ram, 2, image[2:])
    return ram


def dump(path):
    writes, time = [], 0
    for line in path.read_text().splitlines():
        delta, register, value = map(int, line.split())
        time += delta
        writes.append((time, register, value))
    return writes


def units(image, labels, symbols, out):
    path = out / "flauta_unidades_sid.dump"
    with V.Vice(None, ["-warp", "-sounddev", "dump", "-soundarg", str(path)],
                registro=str(out / "flauta_unidades_vice.log")) as v:
        ram = inject(v, image)

        def call(name=None, a=0, x=0x55, y=0xAA, compare=None, marker=None):
            code = bytearray((0x78, 0xD8, 0xA9, 0x35, 0x85, 1))
            if marker is not None:
                code.extend((0xA9, marker, 0x8D, 0x1F, 0xD4))
            code.extend((0xA2, x, 0xA0, y, 0xA9, a))
            if compare is not None:
                code.extend((0xC9, compare))
            if name:
                address = labels[name]
                code.extend((0x20, address & 255, address >> 8))
            code.extend((0x8E, 0x80, 1, 0x8C, 0x81, 1))
            stop = 0x100 + len(code)
            code.extend((0x4C, stop & 255, stop >> 8))
            escribe_banco(v, ram, 0x100, code)
            v.pon_pc(0x100)
            run_to(v, stop)
            return lee(v, ram, 0x180, 0x181)

        def ay(register, value):
            call("plat_psg", register, value)

        def selector(value, marker):
            kept = call("psg_paso", value, compare=symbols["D64_SND_SEQ_FOOTSTEP"] & 255, marker=marker)
            assert kept == bytes((0x55, 0xAA)), ("psg_paso clobbers X/Y", marker, kept)

        call("psg_inicio", marker=1)
        selector(symbols["D64_SND_SEQ_BEEP"] & 255, 2)
        for c in range(3):
            ay(2*c, 137)
            ay(2*c+1, 0)
            ay(8+c, 10)
        ay(7, 0x38)                  # all three tones, no noise
        selector(0xF9, 3)            # live pulse -> flute, unchanged mixer
        call(marker=4)
        ay(4, 137); ay(5, 0)
        for volume in (0, 5, 12, 6, 0):
            ay(10, volume)
        call(marker=5)
        ay(10, 10)
        ay(7, 0x18)                  # AY noise still overrides the triangle
        ay(7, 0x38)
        selector(symbols["D64_SND_SEQ_FOOTSTEP"] & 255, 6)
        call(marker=7)
        ay(10, 0)
        for volume in range(1, 13):
            ay(10, volume)
        for volume in range(11, -1, -1):
            ay(10, volume)
        selector(0xF9, 8)
        ay(10, 10)
        selector(symbols["D64_SND_SEQ_BEEP"] & 255, 9)
        ay(10, 0); ay(10, 10)
        selector(0xF9, 10)
        call("psg_inicio", marker=11)
        ay(4, 137); ay(5, 0); ay(10, 10); ay(7, 0x3B)
        assert not v.jams

    phases, current = {}, 0
    for _, register, value in dump(path):
        if register == 31:
            current = value
            phases.setdefault(current, [])
        else:
            phases.setdefault(current, []).append((register, value))
    controls = lambda phase: [value for register, value in phases[phase] if register == 18]
    assert 0x41 in controls(2), "default voice C is not a pulse"
    assert (23, 4) in phases[3] and 0x11 in controls(3), "idle selector does not choose triangle/no resonance"
    assert not any(register < 14 for register, _ in phases[3]), "idle selector changed voices A/B"
    assert not any(register in (5, 12, 19) for number, writes in phases.items() if number not in (1, 11)
                   for register, _ in writes), "AD changed outside reset"
    for register in (14, 15):
        old = [value for r, value in phases[2] if r == register][-1]
        new = [value for r, value in phases[4] if r == register][-1]
        assert old == new, "the flute changed AY note frequency"
    assert controls(4) == [0x10, 0x10, 0x11, 0x10, 0x11, 0x10], controls(4)
    assert [value for register, value in phases[4] if register == 20] == [0x01, 0x11, 0x91, 0x11, 0x01], "music lost its normal AY sustain levels"
    assert 0x81 in controls(5) and controls(5)[-1] == 0x11, "AY noise/mixer selection changed"
    assert (23, 0x84) in phases[6] and controls(6)[-1] == 0x41, "footstep did not restore pulse/filter"
    assert controls(7).count(0x41) == 1, "footsteps retrigger on their volume rises"
    assert (23, 0x84) in phases[9] and controls(9)[-1] == 0x41, "beep did not restore pulse/filter"
    assert (23, 0x84) in phases[11] and controls(11)[-1] == 0x41, "reset retained the flute"
    for voice in (0, 7):
        assert (voice+4, 0x41) in phases[2], "bell voices A/B are not pulses"
    print("ok: flute triangle/filter; AY frequency, note gates, noise and ADSR; pulse footsteps/beeps/reset; A/B and X/Y unchanged.", flush=True)


def idle(image, labels, symbols, out, recording=None):
    path = out / (recording + ".wav" if recording else "flauta_reposo_sid.dump")
    music = symbols["D64_SND_SEQ_MUSIC"]
    started, completed, playing, frames = False, False, 0, 0
    options = (["-speed", "100", "+warp", "-sounddev", "wav"] if recording
               else ["-warp", "-sounddev", "dump"])
    options += ["-soundarg", str(path)]
    music_cycle = None
    with V.Vice(None, options, registro=str(out / ((recording or "flauta_reposo") + "_vice.log"))) as v:
        ram = inject(v, image)
        io = banco(v, "io")
        escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff")
        escribe_banco(v, io, 0xDD0F, b"\x51")
        escribe_banco(v, io, 0xDD0E, b"\x11")

        def clock():
            low, high = struct.unpack("<HH", lee(v, io, 0xDD04, 0xDD07))
            return 0xFFFFFFFF - (high << 16 | low)

        v.pon_pc(labels["principal_inicio"])
        points = {v.punto(labels[n], temporal=False): n for n in ("game_input_and_mirror", "s_pon")}
        points[v.punto(labels["game_input_and_mirror"]+3, temporal=False)] = "keys"
        for _ in range(10000 if recording else 2000):
            v.golpes.clear()
            v.orden(V.CMD_EXIT)
            v.s.settimeout(45)
            while not v.golpes:
                if v.jams:
                    raise AssertionError("CPU JAM in idle game")
                v._respuesta()
            v.s.settimeout(None)
            v.para()
            for point in sorted(v.golpes):
                if points[point] == "keys":
                    if 10 <= frames < 18:
                        address = symbols["D64_SYS_KEYS_DOWN"]
                        escribe_banco(v, ram, address, bytes((lee(v, ram, address, address)[0] & 0xFE,)))
                elif points[point] == "s_pon":
                    registers = v.registros()
                    if registers[1] == 0x30:
                        sequence = registers[2] | registers[0] << 8
                        if sequence == music:
                            started = True
                            if music_cycle is None:
                                music_cycle = clock()
                        elif started:
                            completed = True
                else:
                    frames += 1
                    if started:
                        playing += 1
            if recording:
                elapsed = clock()
                if music_cycle is not None and elapsed-music_cycle >= 12*985248:
                    break
                assert elapsed < 29*985248, "idle music did not start soon enough for a short recording"
            elif completed or playing >= 80:
                break
        assert started and playing >= 8, ("the actual game did not play its idle music", frames, started, playing)
        if recording:
            assert music_cycle is not None and clock()-music_cycle >= 12*985248, "recording ended before twelve seconds of the idle scene"
        v.captura(str(out / ((recording or "flauta_reposo") + ".png")))
        assert not v.jams
    if recording:
        with wave.open(str(path), "rb") as audio:
            duration = audio.getnframes()/audio.getframerate()
        print(f"ok: {path.name}: {duration:.1f} s WAV, including 12 s after real idle music starts.", flush=True)
        return path
    writes = dump(path)
    flute = next((i for i, (_, r, value) in enumerate(writes) if r == 23 and value == 4), None)
    assert flute is not None, "the actual idle music did not select the flute"
    end = next((i for i in range(flute+1, len(writes)) if writes[i][1:] == (23, 0x84)), len(writes))
    controls = [value for _, r, value in writes[flute:end] if r == 18]
    assert 0x11 in controls and all(value & 0xF0 in (0, 0x10, 0x80) for value in controls), controls
    print(f"ok: real idle music uses the flute for {playing} game updates, no CPU JAM.", flush=True)


def spectrum(path):
    """Descriptive timbre figures for the last ten seconds, not a taste test."""
    import numpy as np
    with wave.open(str(path), "rb") as audio:
        assert audio.getsampwidth() == 2
        rate, channels = audio.getframerate(), audio.getnchannels()
        signal = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").astype(float)
    signal = signal.reshape(-1, channels).mean(axis=1)[-10*rate:]/32768
    signal -= signal.mean()
    n = 4096
    chunks = signal[:len(signal)//n*n].reshape(-1, n)
    energy = (abs(np.fft.rfft(chunks*np.hanning(n), axis=1))**2).sum(axis=0)
    frequencies = np.fft.rfftfreq(n, 1/rate)
    return {"rms": float(np.sqrt(np.mean(signal**2))),
            "centroid_hz": float((frequencies*energy).sum()/energy.sum()),
            "above_3khz_percent": float(100*energy[frequencies >= 3000].sum()/energy.sum())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--solo-unidades", action="store_true")
    parser.add_argument("--graba", action="store_true", help="record actual idle music at PAL 100%%, never warp")
    parser.add_argument("--antes", type=Path, help="optional older juego.bin and juego.lbl directory for a second WAV")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    image = (H / "c64/juego.bin").read_bytes()
    labels = V.etiquetas(H / "c64/juego.lbl")
    symbols = {n: int(a, 16) for n, a in re.findall(r"^(\w+) = \$([0-9A-F]+)", (H / "mapa64.inc").read_text(), re.M)}
    assert image[labels["psg_paso"]+11:labels["psg_paso"]+13] == bytes((0xA9, 1)), "footstep regression hook moved"
    units(image, labels, symbols, args.out)
    if not args.solo_unidades:
        idle(image, labels, symbols, args.out)
    if args.graba:
        recordings = {"flauta": idle(image, labels, symbols, args.out, "flauta")}
        if args.antes:
            recordings["pulso_anterior"] = idle((args.antes / "juego.bin").read_bytes(),
                V.etiquetas(args.antes / "juego.lbl"), symbols, args.out, "pulso_anterior")
        figures = {name: spectrum(path) for name, path in recordings.items()}
        (args.out / "timbres.json").write_text(json.dumps(figures, indent=2)+"\n")
        for name, values in figures.items():
            print(f"{name}: {values}", flush=True)
    print("all flute checks passed")


if __name__ == "__main__":
    main()
