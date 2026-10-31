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

"""A WAV of what the CPC's sound chip played, from its register writes (`T REG VALUE` lines of
cpc_carga.py --ay, T in T-states at 4 MHz): three square-wave channels (AY clock 1 MHz, f = 1e6 /
(16 P)) at the AY's logarithmic volume levels (MAME's table), mixer bits as written.  Noise and the
hardware envelope are not used by the parchment music and not modelled.

    ay_a_wav.py CPC_AY.txt OUT.wav [--segundos N]
"""
import sys, wave
import numpy as np

NIVEL = [0, 0.0137, 0.0205, 0.0291, 0.0423, 0.0618, 0.0847, 0.1369, 0.1691, 0.2647, 0.3527, 0.4499,
         0.5704, 0.6873, 0.8482, 1.0]


def main():
    rate = 22050
    ev = [tuple(map(int, l.split())) for l in open(sys.argv[1])]
    t0 = ev[0][0]
    secs = float(sys.argv[sys.argv.index("--segundos") + 1]) if "--segundos" in sys.argv else (ev[-1][0] - t0) / 4e6 + 1
    n = int(secs * rate)
    out = np.zeros(n)
    regs = [0] * 16; regs[7] = 0x3F
    phase = [0.0, 0.0, 0.0]
    i = 0
    for s in range(n):
        t = t0 + s * 4e6 / rate
        while i < len(ev) and ev[i][0] <= t:
            regs[ev[i][1]] = ev[i][2]; i += 1
        v = 0.0
        for c in range(3):
            p = regs[2 * c] | (regs[2 * c + 1] & 0x0F) << 8
            if (regs[7] >> c) & 1 or p == 0: continue
            f = 1e6 / (16 * p)
            phase[c] = (phase[c] + f / rate) % 1.0
            v += NIVEL[regs[8 + c] & 0x0F] * (1 if phase[c] < 0.5 else -1)
        out[s] = v / 3
    pcm = (out * 26000).astype(np.int16)
    w = wave.open(sys.argv[2], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(pcm.tobytes()); w.close()


if __name__ == "__main__":
    main()
