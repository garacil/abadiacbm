<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Herramientas.md: se edita la plantilla, no esta página. -->
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

# Mis herramientas

[Inicio](Inicio.md) · anterior: [Gráficos y herramientas](Graficos.md) · siguiente: [Glosario](Glosario.md)

Todo lo de este proyecto lo hice, lo comprobé y lo medí con herramientas que escribí para él, y están todas en el
repositorio, con la misma licencia que el juego: `doc/HERRAMIENTAS.md` las enumera todas, agrupadas por lo que hago
con ellas.  Aquí enseño cómo funcionan las más importantes.  Todas cumplen tres reglas: con las mismas entradas dan
las mismas salidas, byte a byte; cada dato de la máquina sale de la documentación oficial o del código que se mide,
nunca de memoria; y todo lo que cambia el juego va seguido de las comprobaciones que demuestran que sigue siendo el
mismo juego.

## El anfitrión híbrido: cada rutina contra el Z80

Nunca me fié de la traducción a C ni de las rutinas 6502 por leerlas: `src/juego/hibrido` ejecuta el programa Z80
original del CPC, y cada vez que el Z80 llama a una función que he traducido, primero se ejecuta la traducción desde
el mismo estado, después la máquina vuelve atrás y el original Z80 hace la misma llamada:

[`src/juego/hibrido.c`](../../../src/juego/hibrido.c#L498-L518), líneas 498–518:

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

La comparación abarca los 64 KiB enteros, SP, PC y los resultados que declara cada función (sus banderas, sus
registros); solo se deja fuera la pila muerta por debajo de la entrada, que una función en C nunca escribe:

[`src/juego/hibrido.c`](../../../src/juego/hibrido.c#L445-L458), líneas 445–458:

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

Con `--6502 DIR` las rutinas 6502 del juego (`src/c64/juego_final`) se comprueban igual sobre el núcleo 6502 de
sim65 (`src/juego/m6502/sombra6502.c`), y con `--juego6502 DIR` el juego 6502 entero corre al paso del Z80 y su
memoria se compara en cada fotograma.  Las comprobaciones recorren las 8 sesiones de exploración, 16 guiones largos,
cada día y cada hora del juego y el final (`src/c64/juego_final/comprueba.sh`, `dias.sh`): 0 diferencias.

## La certificación en las máquinas de verdad

El anfitrión prueba el código 6502; la certificación prueba las ediciones.  `src/c64/certifica/certifica.py` ejecuta
la construcción real del C64 en VICE fotograma a fotograma, al paso del Z80 del anfitrión, a través de dos FIFO;
`src/c64/certifica/pc/lote.sh` ejecuta los discos del C128 y del P500 en VICE (`corre128.py`, `corre500.py`: el P500
desde su propio disco, con su menú, su pergamino y su cargador) junto a mi reconstrucción del juego completo de PC
con las mismas teclas, y `compara.py` compara 237 datos en cada fotograma.

## Los ciclos sacados del propio código del emulador

Para el trabajo de velocidad necesitaba el coste exacto de cada instrucción.  `tools/velocidad/analizador/ciclos6502.py`
no lleva una tabla de ciclos: los lee del propio `6502.c` de sim65, de su tabla de códigos de operación y de las
macros de cada manejador, y cada cifra guarda las líneas del fuente de donde salió:

[`tools/velocidad/analizador/ciclos6502.py`](../../../tools/velocidad/analizador/ciclos6502.py#L73-L96), líneas 73–96:

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

`prueba_sim65.py` comprueba después el analizador contra la realidad: un programa pequeño para cada código de
operación legal, cruzando página y sin cruzarla, y un programa de bucles, todo medido con `sim65 --cycles` (200 casos,
0 diferencias).

## Medir el fotograma real en VICE

`tools/velocidad/vice/medir.py` mide el fotograma del C64 en VICE sin estorbarlo: solo para el emulador en puntos de
control y en cada parada lee el CIA 2 como un contador de ciclos de 32 bits, así que cada cifra es exacta:

[`tools/velocidad/vice/medir.py`](../../../tools/velocidad/vice/medir.py#L38-L46), líneas 38–46:

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

## Mi licencia en cada fichero

`tools/licencia.py` pone mi cabecera en cada fichero de texto del repositorio, con la sintaxis de comentario de cada
uno, y dice cuáles no la tienen (`--comprueba --git`, antes de cada commit):

[`tools/licencia.py`](../../../tools/licencia.py#L114-L124), líneas 114–124:

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

## Esta wiki

`tools/wiki.py` hace estas páginas a partir de sus plantillas: cada fragmento se corta de las fuentes al construir la
wiki, con su fichero y sus números de línea, así que ninguno se copia a mano y ninguno puede quedarse viejo:

[`tools/wiki.py`](../../../tools/wiki.py#L64-L90), líneas 64–90:

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

`tools/wiki_github.py` publica las páginas de los dos idiomas en la wiki de GitHub del repositorio.
