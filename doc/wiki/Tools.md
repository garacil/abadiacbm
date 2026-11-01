<!-- Made by tools/wiki.py from doc/wiki/fuentes/Tools.md: edit the template, not this page. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# My tools

[Home](Home.md) · previous: [Graphics and tools](Graphics.md) · next: [Glossary](Glossary.md)

I made, checked and measured everything in this project with tools I wrote for it, and they are all in the
repository, under the same licence as the game: `doc/HERRAMIENTAS.md` lists every one, grouped by what I use it for.
This page shows how the most important ones work.  Three rules hold for all of them: the same inputs give the same
outputs, byte for byte; every machine fact comes from the official documentation or from the code being measured,
never from memory; and whatever changes the game is followed by the checks that prove it is still the same game.

## The hybrid host: every routine against the Z80

The C translation and the 6502 routines were never trusted by reading them: `src/juego/hibrido` runs the original
Z80 program of the CPC, and every time the Z80 calls a function I translated, the translation runs first from the
same state, then the machine is put back and the Z80 original runs the same call:

[`src/juego/hibrido.c`](../../src/juego/hibrido.c#L498-L518), lines 498–518:

```c
static void llamada_traducida(const traducida_t *t)
{
    z80 c0 = cpu, cz, zz;
    ++llamadas_c;
    plataforma_t pe, pz;
    if (solo_c) { sp_entrada = sp_minimo = cpu.sp; t->envoltorio(); return; }
    hibrido_plataforma(&pe);
    memcpy(ram0, ram, sizeof ram);
    sp_entrada = sp_minimo = cpu.sp;
    t->envoltorio();                          /* the C function: registers -> parameters -> results, RET */
    cz = cpu;
    memcpy(ram_c, ram, sizeof ram);
    memcpy(ram, ram0, sizeof ram);            /* back to the entry state: the Z80 original */
    cpu = c0;
    corre_z80_hasta_retorno();
    zz = cpu;
    compara(t, &cz, &zz);
    hibrido_plataforma(&pz);
    if (con_6502) sombra6502_comprueba(t->nombre, &c0, ram0, &zz, ram, &pe, &pz);
    if (sustituye) { memcpy(ram, ram_c, sizeof ram); cpu = cz; }
}
```

The comparison takes the whole 64 KiB, SP, PC and the results each function declares (its flags, its registers);
only the dead stack below the entry, which a C function never writes, is left out:

[`src/juego/hibrido.c`](../../src/juego/hibrido.c#L445-L458), lines 445–458:

```c
static void compara(const traducida_t *t, const z80 *cz, const z80 *zz)
{
    unsigned i, n = 0;
    char reg[128] = "";
    for (i = 0; i < 0x10000; ++i) if (ram_c[i] != ram[i] && !muerta(i)) ++n;
    if (cz->sp != zz->sp || cz->pc != zz->pc) snprintf(reg, sizeof reg, " SP/PC C %04X/%04X Z80 %04X/%04X", cz->sp, cz->pc, zz->sp, zz->pc);
    if (!n && !reg[0] && t->resultados(cz, zz, reg, sizeof reg)) return;
    ++fallos_c;
    if (fallos_c <= (unsigned long)max_fallos) {
        fprintf(stderr, "DIFF %s (%04X) frame %u call %lu: %u RAM bytes differ%s\n", t->nombre, t->dir, frame, llamadas_c, n, reg);
        for (i = 0, n = 0; i < 0x10000 && n < 12; ++i)
            if (ram_c[i] != ram[i] && !muerta(i)) { fprintf(stderr, "   %04X: C %02X  Z80 %02X  (before %02X)\n", i, ram_c[i], ram[i], ram0[i]); ++n; }
    }
}
```

With `--6502 DIR` the game's 6502 routines (`src/c64/juego_final`) are checked the same way on sim65's 6502 core
(`src/juego/m6502/sombra6502.c`), and with `--juego6502 DIR` the whole 6502 game runs in step with the Z80, its
memory compared at every frame.  The checks run over the 8 exploration sessions, 16 long scripts, every day and hour
of the game and the ending (`src/c64/juego_final/comprueba.sh`, `dias.sh`): 0 differences.

## The certification on the real machines

The host proves the 6502 code; the certification proves the releases.  `src/c64/certifica/certifica.py` runs the real
C64 build in VICE frame by frame in step with the host's Z80 through two FIFOs; `src/c64/certifica/pc/lote.sh` runs
the C128's and the P500's disks in VICE (`corre128.py`, `corre500.py`: the P500 from its own disk, its menu, its
parchment and its loader) beside my PC rebuild of the full game with the same keys, and `compara.py` compares 237
data at every frame.

## Cycles taken from the emulator's own source

For the speed work I needed the exact cost of every instruction.  `tools/velocidad/analizador/ciclos6502.py` does not
carry a table of cycles: it reads them from sim65's `6502.c` itself, its opcode table and the macros of each handler,
and every figure keeps the source lines it was taken from:

[`tools/velocidad/analizador/ciclos6502.py`](../../tools/velocidad/analizador/ciclos6502.py#L73-L96), lines 73–96:

```python
def parse_6502c(path):
    """Build {opcode: op} from 6502.c.  op = dict(opcode, mn, mode, length, cycles, cross, branch, src)."""
    with open(path, encoding='utf-8', errors='replace') as f:
        src = f.read().split('\n')
    n = len(src)
    const = {}
    adr = {}
    macros = {}
    i = 0
    while i < n:
        line = src[i]
        m = re.match(r'#define\s+((?:ALU|STO|RMW|RMW2)_CY_[A-Z_0-9]+)\s+(\S+)\s*$', line)
        if m:
            const[m.group(1)] = (m.group(2), i + 1)
        m = re.match(r'#define\s+ADR_([A-Z_]+)\(ad\)', line)
        if m:
            text, j = _macro_body(src, i)
            pc = re.search(r'Regs\.PC\s*\+=\s*(\d+)', text)
            adr[m.group(1)] = {'cross': ('PAGE_CROSS' in text and '++Cycles' in text),
                               'length': int(pc.group(1)), 'lines': (i + 1, j + 1)}
            i = j
        m = re.match(r'#define\s+(MEM_AD_OP_IMM|ALU_OP_IMM|AC_OP_IMM|ALU_OP|AC_OP|STO_OP|MEM_OP|BRANCH)\(', line)
        if m:
            text, j = _macro_body(src, i)
```

`prueba_sim65.py` then checks the analyzer against reality: a small program for every legal opcode, with and without
page crossings, and a program of loops, all measured by `sim65 --cycles` (200 cases, 0 differences).

## Measuring the real frame in VICE

`tools/velocidad/vice/medir.py` measures the C64's frame in VICE without disturbing it: it only stops the emulator at
checkpoints and reads CIA 2 as a 32-bit cycle counter at each stop, so every figure is exact:

[`tools/velocidad/vice/medir.py`](../../tools/velocidad/vice/medir.py#L38-L46), lines 38–46:

```python
Checkpoints (addresses from juego.lbl and the image, see sitios()):
    FRAME   game_input_and_mirror      the frame starts (its first instruction is JSR sys_read_keyboard)
    TECLADO the return of that JSR     -> phase 0 = sys_read_keyboard (the keyboard scan, plat_teclado_fila)
    ESPERA  the frame-wait loop head   -> phase 1 = the rest of the main loop's work before the wait
    SALIDA  the instruction after it   -> phase 2 = the wait (LDA D64_SYS_TICKS / CMP / BCS / JMP, 11 cycles a pass)
    (next FRAME)                       -> phase 3 = footstep test, spr_draw_or_darken, sys_key_down, loop head
    IRQ     plat_irq                   the interrupt's entry (7 cycles of IRQ sequence already spent)
    RTI     plat_irq's own RTI         the stop before the RTI (6 cycles to come)
    SND     s_interrupcion             at its entry a checkpoint at sys_tick's return address, deleted at its hit
```

## My licence on every file

`tools/licencia.py` puts my header on every text file of the repository in the file's own comment syntax, and says
which ones lack it (`--comprueba --git`, before every commit):

[`tools/licencia.py`](../../tools/licencia.py#L114-L124), lines 114–124:

```python
def cabecera(est, texto=TEXTO):
    """The header as text in a comment style: "c", "asm", "hash", "html" or "rem" (for the generators); texto: TEXTO
    or TEXTO_ORIGINAL."""
    if est == "c":
        return "/*\n" + "".join((" * " + l).rstrip() + "\n" for l in texto) + " */\n"
    if est == "html":
        return "<!--\n" + "".join(("  " + l).rstrip() + "\n" for l in texto) + "-->\n"
    if est == "rem":
        return "".join(("REM " + l).rstrip() + "\r\n" for l in texto)
    pre = ";" if est == "asm" else "#"
    return "".join((pre + " " + l).rstrip() + "\n" for l in texto)
```

## This wiki

`tools/wiki.py` makes these pages from their templates: every excerpt is cut from the sources when the wiki is built,
with its file and its line numbers, so no excerpt is copied by hand and none can go stale:

[`tools/wiki.py`](../../tools/wiki.py#L64-L90), lines 64–90:

```python
def extracto(pagina, ruta, ini, fin, idioma):
    f = RAIZ / ruta
    if not f.is_file():
        falla(pagina, f"{ruta}: no such file")
    lineas = f.read_text(encoding="utf-8", errors="replace").split("\n")
    try:
        r = re.compile(ini)
        rf = None if fin.startswith("+") else re.compile(fin)
    except re.error as e:
        falla(pagina, f"{ruta}: a bad pattern: {e}")
    hallados = [i for i, l in enumerate(lineas) if r.search(l)]
    if len(hallados) != 1:
        falla(pagina, f"{ruta}: /{ini}/ matches {len(hallados)} lines (it must match one)")
    a = hallados[0]
    if fin.startswith("+"):
        b = a + int(fin[1:]) - 1
    else:
        b = next((i for i in range(a + 1, len(lineas)) if rf.search(lineas[i])), None)
        if b is None:
            falla(pagina, f"{ruta}: /{fin}/ matches no line after line {a + 1}")
    b = min(b, len(lineas) - 1)
    if b - a + 1 > MAX_LINEAS:
        falla(pagina, f"{ruta}: the excerpt from line {a + 1} has {b - a + 1} lines (at most {MAX_LINEAS})")
    profundidad = "../" * len(idioma["salida"].relative_to(RAIZ).parts)
    titulo = f"[`{ruta}`]({profundidad}{ruta}#L{a + 1}-L{b + 1}), {idioma['lineas']} {a + 1}–{b + 1}"
    codigo = "\n".join(lineas[a:b + 1]).replace("\t", "    ")
    return f"{titulo}:\n\n```{LENGUAJE.get(f.suffix, 'text')}\n{codigo}\n```"
```

`tools/wiki_github.py` publishes the pages of both languages in the repository's GitHub wiki.
