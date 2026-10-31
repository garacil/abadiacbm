<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Mapa-de-memoria.md: se edita la plantilla, no esta página. -->
# Mapa de memoria

[Inicio](Inicio.md) · anterior: [Del Z80 al 6502](Del-Z80-al-6502.md) · siguiente: [Arranque y bucle principal](Bucle-principal.md)

El juego de 64 KiB del CPC llena casi todos sus 64 KiB: 16 KiB de pantalla, unos 16 KiB de código del Z80 y el resto,
datos.  El C64 tiene los mismos 64 KiB, pero su imagen tiene otro formato y el código 6502 del juego ocupa más que el
del Z80.  Todo cabe porque el mapa se calcula bloque a bloque, y porque la propia pantalla del C64 deja sitio para
datos.

## El C64 durante la partida

Desconecto las ROM del BASIC y del KERNAL (`$01 = $35`: RAM en todas partes salvo la E/S de `$D000-$DFFF`); el KERNAL
solo vuelve para cargar o grabar en disco.

| Zona del C64 | Uso |
|---|---|
| `$0000-$0001` | el puerto del 6510 |
| `$0002-$0023` | los registros del Z80 como pares de la página cero y los bytes de trabajo (`zp.inc`) |
| `$0024-$009D` | los operandos que el código del Z80 reescribe: las variables más usadas |
| `$009E-$00FF` | 12 bytes para cada grupo de rutinas (`camino`, `objetos_sonido`, `motor_iso`…) |
| `$0100-$01FF` | la pila del 6502 |
| `$0200-$07FF` | los bloques de variables del CPC enteros y en el orden del CPC (personajes, sprites, puertas, objetos, las variables de la lógica, el estado del sonido, el teclado) y un poco de código 6502 |
| `$0800-$714D` | **el código**: todas las rutinas 6502 del juego, seguidas |
| `$7151-$BFFF` | los datos, empaquetados hacia abajo desde `$C000`: la tabla de salas, las alturas de los tres pisos, los bloques, los textos, los gráficos de los personajes, los búferes, cinco tablas de mezcla alineadas a página |
| `$C000-$C3E7` | la RAM de pantalla del bitmap multicolor (dos de las cuatro plumas de cada celda) |
| `$C400-$CFFF` | las tablas de mezcla de las baldosas, la pila del intérprete de bloques, las palabras, el búfer de alturas |
| `$D000-$DFFF` | **debajo de la E/S**: las baldosas, las caras, la puerta, los números de los días, la luz; se leen con la E/S desconectada |
| `$D800-$DBE7` | (E/S) la RAM de color: la tercera pluma de cada celda |
| `$E000-$FF3F` | el bitmap multicolor: la imagen de 256 × 192 del juego |
| dentro de `$E000-$FFF9` | los bytes invisibles del bitmap: 2042 bytes que nunca se ven, para tablas pequeñas y los datos del sonido |
| `$FFFA-$FFFF` | los vectores NMI, RESET e IRQ (en RAM: el KERNAL está desconectado) |

## Lo que queda libre

He contado los bytes que no usa nadie con el mapa del enlazador de la versión de cinta
(`src/c64/juego_final/c64cinta/juego.map`), quitando la página cero, la pila, la RAM de pantalla, las celdas visibles
del bitmap y los vectores: quedan **925 bytes** (970 en la versión de disco), repartidos en trozos de 64 bytes o menos
dentro del borde invisible del bitmap.  Entre el final del código y el comienzo de los datos quedan **3 bytes** en la
cinta (48 en el disco).  Por eso el C64 no tiene las cabezas en alta resolución con los sprites del VIC-II: sus
máscaras, los sprites y su código no caben.  El C128 y el P500 sí las tienen, porque sacan la tabla de salas y los
textos a su segundo banco de 64 KiB.

## Cómo se hace el mapa

Nada se coloca a mano.  Una tabla enumera cada bloque de datos que necesita el juego, con su dirección del CPC, su
longitud, su tipo y la zona a la que debe ir (los operandos de la página cero de la página anterior son filas así); un
generador los coloca:

[`src/c64/juego_final/mapa64.py`](../../../src/c64/juego_final/mapa64.py#L29-L33), líneas 29–33:

```python
and prints the budget.  Zones: zp from $24 (zp.inc keeps $02-$23), var $0200-$07FF, c4 $C400-$CFFF,
io $D000-$DFFF, hueco = the invisible cells of the bitmap (columns 0-3 and 36-39 of rows 0-23, row 24 and
$FF40-$FFF9: their screen RAM and colour RAM stay black, so their bytes never show), datos = packed down
from $C000; a block that does not fit its zone goes to datos.  The code lives from $0800 to the lowest datos.
"""
```

[`src/c64/juego_final/mapa64.py`](../../../src/c64/juego_final/mapa64.py#L41-L48), líneas 41–48:

```python
BITMAP = 0xE000
CODIGO = 0x0800
ARRIBA = 0xC000
MARCADOR = BITMAP + 320 * 20 + 32      # the score bar: bitmap rows 20-23, cells 4-35 (4 runs of 256 bytes, 320 apart)
TABLAS_C4 = ["tabla_and_tile_a", "tabla_or_tile_a", "tabla_and_tile_b", "tabla_or_tile_b"]
# graphics that also go under the I/O, after the tiles (read and flipped only with the I/O switched off)
BAJO_IO = ["caras", "puerta", "luz", "romanos"]
RESERVA_VAR = 96                       # bytes of $0200-$07FF kept free for the 6502 code's own variables
```

Sus salidas son `mapa64.tsv` (una fila por bloque: la dirección del CPC y la del C64, y cómo lo tratan las
comprobaciones) y `mapa64.inc`, que da a cada nombre `D64_` de las cabeceras de C su dirección en el C64, por ejemplo
`D64_CHR_GUILLERMO = $055B ; CPC 2B87h` (el registro de Guillermo) o `D64_GAME_HOUR = $02A6 ; CPC 28D2h` (la hora).
Después `datos64.py` convierte la imagen en segmentos de ca65 en esas direcciones y ld65 enlaza código y datos en una
sola imagen de 64 KiB.  Cada campo de puntero dentro de los datos (642, encontrados por `tools/punteros64.py`) se
recoloca a la dirección del C64 a la que apunta.

En el C128 y en el P500 el mismo generador saca la tabla de salas y los textos al segundo banco de 64 KiB (el bloque 1
del C128, el banco 1 del P500), lo que deja sitio en el primero para la velocidad y para las cabezas en alta
resolución (ver [El Commodore 128](Commodore-128.md) y [El Commodore P500](Commodore-P500.md)):

[`src/c64/juego_final/mapa64.py`](../../../src/c64/juego_final/mapa64.py#L53-L54), líneas 53–54:

```python
C128 = os.environ.get("C64_MAQUINA") in ("c128", "p500")
P500 = os.environ.get("C64_MAQUINA") == "p500"   # the P500 (CBM-II 510): the C128's layout, its own reserved bytes
```

## La pantalla

El juego del CPC dibuja en modo 1: 256 × 192 píxeles de cuatro colores, un byte con cuatro píxeles, 64 bytes por
línea.  En el C64 esa imagen pasa a ser de 128 × 192 píxeles multicolor (un píxel del C64 por cada pareja de píxeles
del CPC, así que un byte del CPC se convierte en un nibble del C64), centrada en los 160 píxeles de la pantalla, cuatro
celdas desde la izquierda:

[`src/c64/plataforma/pantalla.s`](../../../src/c64/plataforma/pantalla.s#L16-L25), líneas 16–25:

```asm
; The CPC screen on the C64: wscr(addr, v) writes the CPC mode 1 byte v at CPC screen address addr
; (C000h-FFFFh, 64 bytes a line: the game's CRTC setting) into the C64 multicolour bitmap.
;
; CPC address: line in the character row (a >> 11) & 7, row ((a & 7FFh) >> 6), byte column xb = a & 63.
; C64: the 256 CPC pixels are 128 multicolour pixels centred in 160 (4 cells from the left), so the
; byte goes to cell column xb / 2 + 4, high half when xb is even; bitmap address = BITMAP + 320 row +
; 8 column + line.  The byte's 4 pixels become 2 (tabla_pantalla.inc).  Rows 25-31 (outside the
; 200 lines) are ignored.
;
; void __fastcall__ wscr(unsigned int addr, unsigned char v)
```

Las cuatro plumas del CPC son las cuatro parejas de bits de una celda multicolor.  Un cambio de tinta del CPC no
reescribe ningún píxel, igual que en el CPC: cambia el registro de fondo, o llena la RAM de pantalla o la RAM de color
de las 32 × 24 celdas del juego:

[`src/c64/plataforma/tinta.s`](../../../src/c64/plataforma/tinta.s#L18-L29), líneas 18–29:

```asm
; plat_tinta: A = pen 0-16 (16 = the border), X = the C64 colour (the game's palette tables hold C64 colours,
; c64/datos/paleta.tsv).  A and X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
;   pen 3  -> $D021 (bit pair 00)
;   pen 0  -> the high nibble of the screen RAM of the game's 32 x 24 cells (bit pair 01)
;   pen 1  -> their low nibble (bit pair 10)
;   pen 2  -> their colour RAM (bit pair 11)
;   pen 16 -> $D020;  pens 4-15: nothing (mode 1 has four pens).
; As on the CPC no pixel is redrawn: the CPC's palette is global, so every game cell gets the same byte (the
; screen RAM byte holds both pens 0 and 1: their colours are kept here).  The cells outside columns 4-35 and
; rows 0-23 are not touched (they stay black: their bitmap bytes are data).  The fill is unrolled by rows: 24
; STA abs,X per column, 32 columns: 4000 cycles; one routine for both targets, its 24 operands' high bytes
; switched between the screen RAM ($C0-$C3) and the colour RAM ($D8-$DB) by EOR $18 when the target changes.
```

La pluma 3 y el borde son negros en todas las paletas del juego, así que las celdas que quedan fuera del área del
juego, cuya RAM de pantalla y de color siguen negras, nunca enseñan sus bytes del bitmap: guardan datos, igual que el
CPC guardaba datos en la parte oculta de su propia pantalla.
