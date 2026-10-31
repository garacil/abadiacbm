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

"""Compare a recorded WAV (the C64 playing the music) with the notes the CPC played (its sound chip's
register writes, `T REG VALUE` lines from cpc_carga.py --ay, T in Z80 T-states at 4 MHz).

    compara_audio.py CPC_AY.txt RECORDING.wav [--segundos N] [--hz HZ] [--salta S] [--referencia REF.wav] [-v]

The CPC side: for each moment, the frequencies of the enabled channels with volume > 0
(f = 1 MHz / (16 P)).  The recording: the strongest spectral peak of each 50 ms window.  Both are
aligned on their first note.  A window agrees when the peak is within a quarter tone of one of the
CPC's frequencies at that moment.

--hz HZ: the log's times are ticks of HZ per second (the GNU build's --ay and the C64 platform's tests:
300 ticks of the 300 Hz interrupt; the CPC's interrupt is 300.48 Hz).
Noise (the C64 platform's sound test): a window in which a channel with its noise enabled
sounds is counted apart: it agrees when the recording is noise-like there (spectral flatness above 0.03
between 200 Hz and 8 kHz) or its peak matches a channel playing tone only.
--salta S: the first note of the recording is looked for after its first S seconds (the click of the SID's
volume register at the start of a recording is not a note).
--referencia REF.wav: also the correlation of the loudness (RMS about the mean of each 50 ms window, both aligned on
their first sound) of the recording with REF (the GNU build's AY synthesis of the same log).
The WAV may be 8- or 16-bit PCM or 32-bit float, mono or stereo.
"""
import math, struct, sys
import numpy as np

PLANO = 0.03                            # spectral flatness: noise above, tones below (50 ms windows: the
                                        # SID's and the AY synthesis's tones exceed it in 1 % and 3 % of them)


def lee_wav(path):
    """(rate, samples scaled to 16-bit) of a PCM or IEEE float WAV"""
    d = open(path, "rb").read()
    k = 12
    fmt = None
    datos = b""
    while k + 8 <= len(d):
        tipo, largo = d[k:k + 4], struct.unpack("<I", d[k + 4:k + 8])[0]
        if tipo == b"fmt ":
            fmt = struct.unpack("<HHIIHH", d[k + 8:k + 24])
        elif tipo == b"data":
            datos = d[k + 8:k + 8 + largo]
            break
        k += 8 + largo + (largo & 1)
    codigo, canales, rate, _, _, bits = fmt
    if codigo == 3:
        x = np.frombuffer(datos[:len(datos) // 4 * 4], dtype="<f4").astype(float) * 32767
    elif bits == 16:
        x = np.frombuffer(datos[:len(datos) // 2 * 2], dtype="<i2").astype(float)
    else:
        x = (np.frombuffer(datos, dtype=np.uint8).astype(float) - 128) * 256
    if canales > 1:
        x = x[:len(x) // canales * canales].reshape(-1, canales).mean(axis=1)
    return rate, x


def cpc_timeline(path, hz=None):
    regs = [0] * 16
    regs[7] = 0x3F
    events = []
    for line in open(path):
        t, r, v = map(int, line.split())
        regs[r] = v
        freqs = []
        ruido = False
        for c in range(3):
            p = regs[2 * c] | (regs[2 * c + 1] & 0x0F) << 8
            on = not (regs[7] >> c) & 1
            noise = not (regs[7] >> (c + 3)) & 1
            vol = regs[8 + c] & 0x0F
            if vol and noise:
                ruido = True
            elif on and vol and p:
                freqs.append(1e6 / (16 * p))
        events.append((t / hz if hz else t / 4e6, tuple(freqs), ruido))
    return events


def ventanas(data, rate, win):
    """per window: (time, peak frequency or None when silent, spectral flatness, RMS)"""
    out = []
    for i in range(0, len(data) - win, win):
        seg = data[i:i + win] * np.hanning(win)
        rms = float(np.std(data[i:i + win]))          # (without its DC: the AY outputs a disabled channel's level)
        if np.abs(seg).max() < 200:
            out.append((i / rate, None, 0.0, rms))
            continue
        sp = np.abs(np.fft.rfft(seg, 8 * win))
        f = np.fft.rfftfreq(8 * win, 1 / rate)
        banda = (f > 200) & (f < 8000)
        pw = sp[banda] ** 2 + 1e-9
        plano = float(np.exp(np.mean(np.log(pw))) / np.mean(pw))
        sp[f < 60] = 0
        out.append((i / rate, f[sp.argmax()], plano, rms))
    return out


def main():
    hz = float(sys.argv[sys.argv.index("--hz") + 1]) if "--hz" in sys.argv else None
    ev = cpc_timeline(sys.argv[1], hz)
    rate, data = lee_wav(sys.argv[2])
    win = int(rate * 0.05)
    peaks = ventanas(data, rate, win)
    salta = float(sys.argv[sys.argv.index("--salta") + 1]) if "--salta" in sys.argv else 0.0
    t0_rec = next(t for t, f, _, _ in peaks if f and t >= salta)
    t0_cpc = next(t for t, fs, r in ev if fs or r)
    dur = float(sys.argv[sys.argv.index("--segundos") + 1]) if "--segundos" in sys.argv else 1e9
    ok = tot = ok_r = tot_r = 0
    k = 0
    cur = ((), False)
    for t, f, plano, _ in peaks:
        if f is None or t - t0_rec > dur: continue
        tc = t - t0_rec + t0_cpc
        while k < len(ev) and ev[k][0] <= tc:
            cur = ev[k][1:]
            k += 1
        fs, ruido = cur
        if not fs and not ruido: continue
        # the strongest peak may be an octave or an odd harmonic (3rd, 5th) of a note: square waves
        good = False
        for x in fs:
            for h in (1, 3, 5):
                cents = 1200 * math.log2(f / (x * h))
                cents -= 1200 * round(cents / 1200)
                if abs(cents) < 50: good = True
        if ruido:
            tot_r += 1
            if good or plano > PLANO: ok_r += 1
            elif "-v" in sys.argv:
                print(f"  t={t - t0_rec:6.2f} s: noise expected, flatness {plano:.3f}, peak {f:7.1f} Hz")
            continue
        tot += 1
        if good: ok += 1
        elif "-v" in sys.argv:
            print(f"  t={t - t0_rec:6.2f} s: peak {f:7.1f} Hz, CPC notes {', '.join(f'{x:.1f}' for x in fs)}")
    print(f"{ok} of {tot} windows of 50 ms agree with the CPC's notes (within a quarter tone; octaves and the 3rd/5th harmonics allowed)")
    if tot_r:
        print(f"{ok_r} of {tot_r} windows of 50 ms with the CPC's noise sound like noise (flatness > {PLANO}) or match a tone")
    if "--referencia" in sys.argv:
        rate_r, ref = lee_wav(sys.argv[sys.argv.index("--referencia") + 1])
        pr = ventanas(ref, rate_r, int(rate_r * 0.05))
        t0_ref = next(t for t, f, _, _ in pr if f)
        a = [r for t, f, _, r in peaks if t >= t0_rec and t - t0_rec <= dur]
        b = [r for t, f, _, r in pr if t >= t0_ref and t - t0_ref <= dur]
        n = min(len(a), len(b))
        c = float(np.corrcoef(a[:n], b[:n])[0, 1])
        print(f"loudness (RMS of 50 ms windows) correlates {c:.3f} with the reference over {n} windows")


if __name__ == "__main__":
    main()
