# The C64 tape: KERNAL encoding and the TAP format

Sources:
- **W**: C64-Wiki, "Datassette Encoding", https://c64-wiki.com/wiki/Datassette_Encoding
- **C**: Clock Signal emulator, `Storage/Tape/Formats/TapePRG.cpp` and `.hpp` (synthesises a tape from a PRG),
  https://github.com/TomHarte/CLK/blob/master/Storage/Tape/Formats/TapePRG.cpp
- **T**: C64-Wiki, "TAP", https://c64-wiki.com/wiki/TAP
- **S**: Peter Schepers, "TAP.TXT" rev. 1.1 (2004-03-11), https://ist.uwaterloo.ca/~schepers/formats/TAP.TXT
- (MAME `src/lib/formats/cbm_tap.cpp` could not be fetched: HTTP 403.)

## The TAP file (S, T)

| Offset | Contents |
|---|---|
| $0000-$000B | "C64-TAPE-RAW" |
| $000C | version: $00 original, $01 updated |
| $000D-$000F | future expansion ($00 in S's example) |
| $0010-$0013 | the size of the file data, **not including this header**, little endian (S) |
| $0014- | the data: one byte per pulse, length = byte x 8 CPU cycles (PAL clock 985248 Hz, NTSC 1022730: S) |

Version 1: a byte $00 is followed by **three bytes, LOW/HIGH (little endian), the pulse's exact length in cycles**,
for pulses longer than 255 x 8 cycles (S).  One TAP byte is the time between two triggers of the C64's tape input
(CIA 1's FLAG, one edge per wave): a full wave; S does not say it in those words, T's VICE windows imply it
(short $24-$36, medium $37-$49, long $4A-$64).  **Checked** (VICE 3.10 x64sc, its KERNAL ROM): a tape
written with one byte per full wave (src/c64/cinta/cinta.py) loads.

## The KERNAL's encoding (W, C, T)

- **Pulses** (full waves): W, PAL: short 2 x 182.7 us, medium 2 x 265.7 us, long 2 x 348.8 us (NTSC 2 x 176,
  256, 336 us); at 985248 Hz: about 360, 524, 687 cycles = TAP $2D, $41, $56.  C (C64): zero 2 x 169 us, one
  2 x 247, marker 2 x 328, leader 2 x 179 (about TAP $2A, $3D, $51, $2C).  VICE's windows (T): short $24-$36,
  medium $37-$49, long $4A-$64.
- **A byte**: the byte marker (long, medium); 8 data bits, **least significant first**; bit 0 = (short, medium),
  bit 1 = (medium, short); then the check bit, odd parity: 1 XOR b0 XOR ... XOR b7 (W; C: 1 when the byte has an
  even number of 1 bits).  The end of a block: (long, short).
- **A file**: the header block and the data block, each recorded twice.  Before the first copy a leader (W: about
  10 s before the first block, 2 s before the others; C: 20000 + 5000 leader tokens of 2 short waves before the
  header, 5000 before each other copy), then the countdown **$89 $88 ... $81** (first copy) or **$09 ... $01**
  (repeat), then the payload, then the checksum byte, then the end-of-block marker.  Between the header's second
  copy and the data C puts 20 ms of silence.
- **The checksum**: W: XOR of $00 and all the payload bytes (the countdown not included).  C's code seems to XOR
  the countdown into the data block's checksum (not the header's).  **Checked** (VICE 3.10 with the real
KERNAL ROM): W's rule (payload only) loads without error, with the pulses $2D/$41/$56, leaders 27136 and 5376 short
waves, the countdowns $89-$81 / $09-$01 and the end marker (long, short) after the checksum.
- **The header block** (192 bytes; W, C): byte 0 the type ($01 relocatable BASIC program, $03 program loaded at its
  own address; $02 data, $04 sequential file header, $05 end of tape), bytes 1-2 the start address, bytes 3-4 the
  end address (C: start + length, one past the last byte), bytes 5-20 the name (16 bytes, padded with $20),
  bytes 21-191 $20 (W: "usually").  `LOAD"NAME",1` loads a type $01 file at the start of BASIC, a type $03 one at
  its own address (W).

## What the turbo blocks of abadia64ks use (ours, src/c64/cinta)

Not a standard: its own pulses and block format, read by the loader with CIA 1's timer B in one-shot mode (its
start bit clears itself at the underflow: CIA 6526 data sheet) and the FLAG bit of CIA 1's interrupt register,
polled.  Described in src/c64/cinta/NOTAS.md once written and checked.
