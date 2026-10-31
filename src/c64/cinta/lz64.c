/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

/* lz64: the compressor of the data part of the stream "juego" (c64/cinta/FLUJO.md, "The stream").
 *
 *     lz64 IMAGE.bin SEGMENTS.txt OUT.bin [--literal]
 *
 * IMAGE.bin: 65536 bytes, the byte each segment writes at each address (the memory as the load leaves it).
 * SEGMENTS.txt: one segment a line, "ADDR LEN" (hex address, decimal length), in the order of the stream; "1 0" is the
 * mark (the address 1 and no tokens: the loader blackens the picture's side cells there, c64/presentacion/cargador.s).
 * OUT.bin: the data stream the loader (c64/pergamino/cargador.s) decodes:
 *
 *   for each segment: its address (2 bytes, low first), then tokens until the segment's end (the mark: 01 00 alone);
 *   after the last segment: 00 00.
 *   token  0 + gamma(n) + n bytes                  n literal bytes
 *          1 + gamma(h + 1) + byte l + gamma(k - 1)  k >= 2 bytes copied from dst - (256 h + l) (any address:
 *                                                    16 bits, wrapping), byte by byte forwards
 *          1 + gamma(257)                          the end of the segment
 *   gamma(v), v >= 1: for each bit of v below its leading 1 (most significant first) a 0 then the bit; then a 1.
 *   The bits are taken most significant first from bit bytes the decoder reads from the stream when it needs a
 *   bit and has none left; the bytes (literals, l, addresses) are read where they come.  The bit state goes on
 *   across segments.
 *
 * The parse is optimal for this format (cost in bits, dynamic programming from each segment's end): literal runs
 * up to 1024 bytes; matches at every offset 1-255 (from 2 bytes) and from the earlier written bytes whose 3-byte
 * hash matches (the last 64 such positions, lengths measured up to 512); each length tried with the cheapest
 * offset that reaches it, one by one up to 64 bytes, and the longest.  A match is valid when, for each of its bytes, the
 * source address was written by the stream before that byte is copied and holds the byte wanted (the memory
 * model: every address is written once, in the order of the segments).  --literal: no matches (each segment as
 * literal runs), for the load time without compression.  Deterministic.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LMAX 1024                 /* longest literal run considered */
#define KMAX_CORTO 64             /* match lengths tried one by one; longer: only the longest */
#define CAND 64                   /* hash chain steps */
#define LARGO_LEJOS 512           /* longest match measured for a far candidate */
#define NUNCA 0x7FFFFFFF

static uint8_t img[65536];
static int vindex[65536];         /* the stream position (virtual) at which an address is written; NUNCA */
static int cabeza[65536];
static int nseg, seg_ini[4096], seg_len[4096];
static int nv;                    /* virtual length */
static uint16_t *vdir;            /* virtual position -> address */
static uint8_t *vbyte;

static int gbits(unsigned v)      /* the bits of gamma(v) */
{
    int n = 0;
    while (v > 1) { v >>= 1; n += 2; }
    return n + 1;
}

/* ---- the output: bytes and bits interleaved as the decoder reads them ---- */
static uint8_t *out;
static long nout, cap, bitpos = -1;
static int nbits = 8;

static void pon_byte(uint8_t b)
{
    if (nout == cap) { cap = cap ? 2 * cap : 65536; out = realloc(out, (size_t)cap); }
    out[nout++] = b;
}

static void pon_bit(int b)
{
    if (nbits == 8) { bitpos = nout; pon_byte(0); nbits = 0; }
    if (b) out[bitpos] |= (uint8_t)(0x80 >> nbits);
    ++nbits;
}

static void pon_gamma(unsigned v)
{
    int k = 0;
    while ((v >> k) > 1) ++k;
    while (k--) { pon_bit(0); pon_bit((v >> k) & 1); }
    pon_bit(1);
}

/* ---- one segment ---- */
static long *coste;
static int *eleccion_len, *eleccion_off;  /* len > 0: match of len at offset; len < 0: literal of -len */
static int *prev;                         /* the previous virtual position with the same 3-byte hash; -1 */
static int corrida[256];                  /* near offsets: the match length at the position being parsed */

/* byte u (virtual) can be copied from offset off: the source address was written before and holds the byte */
static int vale(int u, int off)
{
    uint16_t r = (uint16_t)(vdir[u] - off);
    return vindex[r] < u && img[r] == vbyte[u];
}

static int largo_valido(int v, uint16_t src, int maxk)
{
    int t;
    for (t = 0; t < maxk; ++t) {
        uint16_t r = (uint16_t)(src + t);
        if (vindex[r] >= v + t || img[r] != vbyte[v + t]) break;
    }
    return t;
}

static unsigned hash3(int v) { return ((unsigned)vbyte[v] * 2654435761u ^ (unsigned)vbyte[v + 1] << 8 ^ vbyte[v + 2]) & 0xFFFFu; }

static void segmento(int s, int base, int literal)
{
    int n = seg_len[s], i, off;
    int largo_hi[256], off_hi[256];
    if (n == 0) {                                             /* the mark: its address alone */
        pon_byte((uint8_t)seg_ini[s]);
        pon_byte((uint8_t)(seg_ini[s] >> 8));
        return;
    }
    coste[n] = 1 + gbits(257);
    memset(corrida, 0, sizeof corrida);
    for (i = n - 1; i >= 0; --i) {
        int v = base + i, k, mejor_k = 0, mejor_off = 0, hi, cubierto;
        long mejor = -1;
        for (k = 1; k <= LMAX && i + k <= n; ++k) {
            long c = 1 + gbits((unsigned)k) + 8L * k + coste[i + k];
            if (mejor < 0 || c < mejor) { mejor = c; mejor_k = -k; }
        }
        for (off = 1; off < 256; ++off) corrida[off] = vale(v, off) ? corrida[off] + 1 : 0;
        if (!literal) {
            int vistos = 0, w;
            memset(largo_hi, 0, sizeof largo_hi);
            for (off = 1; off < 256; ++off)                    /* hi = 0: the near offsets */
                if (corrida[off] > largo_hi[0]) { largo_hi[0] = corrida[off]; off_hi[0] = off; }
            if (i + 3 <= n)                                   /* hi >= 1: the hash chain */
                for (w = prev[v]; w >= 0 && vistos < CAND; w = prev[w], ++vistos) {
                    int m;
                    off = (uint16_t)(vdir[v] - vdir[w]);
                    if (off < 256) continue;
                    m = largo_valido(v, vdir[w], n - i < LARGO_LEJOS ? n - i : LARGO_LEJOS);
                    if (m > largo_hi[off >> 8]) { largo_hi[off >> 8] = m; off_hi[off >> 8] = off; }
                }
            /* the cost of an offset grows with hi: each length is tried with the cheapest hi that reaches it */
            cubierto = 1;
            for (hi = 0; hi < 256; ++hi) {
                int m = largo_hi[hi], kk;
                if (m <= cubierto) continue;
                for (kk = cubierto + 1; kk <= m; ++kk) {
                    long c;
                    if (kk > KMAX_CORTO && kk != m) continue;
                    c = 1 + gbits((unsigned)hi + 1) + 8 + gbits((unsigned)(kk - 1)) + coste[i + kk];
                    if (c < mejor) { mejor = c; mejor_k = kk; mejor_off = off_hi[hi]; }
                }
                cubierto = m;
            }
        }
        coste[i] = mejor;
        eleccion_len[i] = mejor_k;
        eleccion_off[i] = mejor_off;
    }
    /* the tokens */
    pon_byte((uint8_t)seg_ini[s]);
    pon_byte((uint8_t)(seg_ini[s] >> 8));
    for (i = 0; i < n;) {
        int k = eleccion_len[i];
        if (k < 0) {
            int j;
            pon_bit(0);
            pon_gamma((unsigned)-k);
            for (j = 0; j < -k; ++j) pon_byte(vbyte[base + i + j]);
            i += -k;
        } else {
            off = eleccion_off[i];
            pon_bit(1);
            pon_gamma((unsigned)(off >> 8) + 1);
            pon_byte((uint8_t)off);
            pon_gamma((unsigned)(k - 1));
            i += k;
        }
    }
    pon_bit(1);
    pon_gamma(257);
}

int main(int argc, char **argv)
{
    FILE *f;
    char linea[256];
    int s, v, literal = argc > 4 && !strcmp(argv[4], "--literal");
    long total = 0;
    if (argc < 4) { fprintf(stderr, "usage: lz64 IMAGE.bin SEGMENTS.txt OUT.bin [--literal]\n"); return 2; }
    if (!(f = fopen(argv[1], "rb")) || fread(img, 1, 65536, f) != 65536) { fprintf(stderr, "lz64: cannot read %s\n", argv[1]); return 1; }
    fclose(f);
    if (!(f = fopen(argv[2], "r"))) { fprintf(stderr, "lz64: cannot read %s\n", argv[2]); return 1; }
    while (fgets(linea, sizeof linea, f)) {
        unsigned a; int n;
        if (linea[0] == '#' || sscanf(linea, "%x %d", &a, &n) != 2) continue;
        if (nseg == 4096 || a == 0 || (n <= 0 && !(a == 1 && n == 0)) || a + (unsigned)n > 65536) { fprintf(stderr, "lz64: bad segment %s", linea); return 1; }
        seg_ini[nseg] = (int)a; seg_len[nseg++] = n; total += n;
    }
    fclose(f);
    vdir = malloc(sizeof *vdir * (size_t)(total + 3));
    vbyte = calloc((size_t)total + 3, 1);
    prev = malloc(sizeof *prev * (size_t)(total + 3));
    for (v = 0; v < 65536; ++v) vindex[v] = NUNCA;
    for (s = 0, v = 0; s < nseg; ++s) {
        int i;
        for (i = 0; i < seg_len[s]; ++i, ++v) {
            uint16_t a = (uint16_t)(seg_ini[s] + i);
            if (vindex[a] != NUNCA) { fprintf(stderr, "lz64: %04X written twice\n", a); return 1; }
            vindex[a] = v; vdir[v] = a; vbyte[v] = img[a];
        }
    }
    nv = v;
    memset(cabeza, 0xFF, sizeof cabeza);
    for (v = 0; v < nv; ++v) {                               /* the chains: earlier positions only */
        if (v + 3 <= nv) { unsigned h = hash3(v); prev[v] = cabeza[h]; cabeza[h] = v; }
        else prev[v] = -1;
    }
    coste = malloc(sizeof *coste * (LMAX + 70000));
    eleccion_len = malloc(sizeof *eleccion_len * 70000);
    eleccion_off = malloc(sizeof *eleccion_off * 70000);
    for (s = 0, v = 0; s < nseg; ++s) {
        if (seg_len[s] > 69000) { fprintf(stderr, "lz64: segment too long\n"); return 1; }
        segmento(s, v, literal);
        v += seg_len[s];
    }
    pon_byte(0);
    pon_byte(0);
    if (!(f = fopen(argv[3], "wb")) || fwrite(out, 1, (size_t)nout, f) != (size_t)nout) { fprintf(stderr, "lz64: cannot write %s\n", argv[3]); return 1; }
    fclose(f);
    printf("%d segments, %ld bytes -> %ld bytes\n", nseg, total, nout);
    return 0;
}
