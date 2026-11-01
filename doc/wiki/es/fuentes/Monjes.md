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

# La mente de los monjes

[Inicio](Inicio.md) · anterior: [Alturas y búsqueda de caminos](Caminos.md) · siguiente: [Objetos, puertas y el espejo](Objetos.md)

Cada uno de los otros cinco personajes tiene un **guion**: una rutina escrita en un pequeño lenguaje del programa
original, que decide **adónde va** el personaje y **qué dice**, según el día, la hora, dónde está Guillermo y las
variables de la historia.  El movimiento en sí (la ruta, los pasos) es cosa del buscador de caminos.  Los guiones están
en `src/c64/juego_final/logica_b_guiones.s` y su máquina virtual en `logica_b.s`.

## Los conductores

Cada fotograma `game_run_npc_behaviours` llama al conductor de cada personaje (Adso, Malaquías, el abad, el registro de
Berengario y el de Severino).  Un conductor apunta IY al registro del personaje e IX a su tabla de **lugares**, ejecuta
su guion, le da las puertas que puede abrir, le mueve un paso y después planea una ruta si el guion ha cambiado su
destino:

{{code src/c64/juego_final/camino.s | ^; The common part of the drivers | +4}}

{{code src/c64/juego_final/camino.s | ^; 03AC \(ai_plan_route | +6}}

Los tres bytes que hay antes de la tabla de lugares son la interfaz del guion: el lugar **alcanzado**, el **estado** del
personaje y el **destino** (un número de lugar, o FF Guillermo, FE el abad, FD el libro, FC el pergamino).  Los lugares
son los puntos fijos de la abadía: la iglesia, el refectorio, las mesas del scriptorium, las celdas, la entrada, la
cocina, el paso a la biblioteca…

## El lenguaje de los guiones

Los guiones del original son código del Z80 con dos ayudantes, `RST 08h` (probar) y `RST 10h` (asignar), cada uno
seguido de una **expresión en notación postfija** sobre las variables del juego: `[87] 08 = [94] 02 = &` se lee
«Malaquías ha llegado al lugar 8 y Severino al lugar 2».  Las comparaciones dan 00 cuando son verdad; `*` y `&` son el
*o* y el *y* lógicos sobre esos valores.  Hay 570 de esas llamadas en el programa, todas en los guiones (51E7h-60F2h en
el juego de 64 KiB).

Traducirlas como llamadas del 6502 con datos detrás habría costado unos 7 KiB; en vez de eso, los guiones siguen siendo
**código de bytes**: cada rutina de guion es `JSR logica_b_vm` seguido de los propios bytes del Z80 (los mismos códigos,
`JR`, `JP`, `CALL`, `RET`, las expresiones detrás de la instrucción) con operandos del 6502, más unas cuantas formas
compactas para las pruebas más frecuentes.  Un generador (`guiones64.py`) traduce los guiones del Z80 de la memoria de
la cinta a esta forma, con cada expresión escrita como comentario.  Este es el contrato de la máquina virtual:

{{code src/c64/juego_final/logica_b.s | ^; logica_b_vm: a script function is | ^; the expression at zhl}}

Dicho en una tabla (v es el número de la variable por dos, el desplazamiento de su palabra en `AI_SCRIPT_VARS`):

| Código | Qué hace |
|---|---|
| `CF` expr | probar: A = C = el valor, Z si es 0 |
| `D7` v expr | asignar una expresión |
| `20` e / `18` e | `JR NZ` / `JR` |
| `C2` nn / `C3` nn | `JP NZ` / `JP` dentro del código de bytes |
| `C3` k `00` | saltar a una rutina nativa (la k de una tabla) |
| `CD` nn, `CD` k `00` b | llamar a una rutina nativa (con un byte detrás si lo lleva) |
| `CD 0A 00` w… `0` | el *switch* de `util_jump_table_inline` |
| `C9` | `RET` |
| `3E` n / `01` | `LD A,n` / `XOR A` |
| `F8`+p a n e, `E2` v n e | la prueba `v n =`, con el salto cuando es falsa / verdadera |
| `E3`/`E4`, `E5`/`E6` v n e | `v n >` (v ≥ n) y `v n <`, saltando cuando es falsa / verdadera |
| `E7`/`E8` v w e | `v w =` entre dos variables |
| `E9`/`EA` v m n e | `v m * n =` (v AND m = n) |
| `EB` v e / `EC` v m e | el valor de v (o v AND m), saltando si no es 0 |
| `A0`+p, `A8`+p, `B0`+p a n e | las mismas pruebas encadenadas |
| `DB`/`DC`/`DD`/`DE` v n | v := v OR / + / AND / − n |
| `D8` v n, `D9` v n, `DA` v n w m | asignar un literal; asignarlo y volver; dos asignaciones seguidas |
| `D0` b / `D1` b | `hud_say` / `hud_say_now` con la frase b |
| `D2` / `D3` / `D4` | `ai_guillermo_is_close` / quitar 2 de obsequium / quedarse quieto (`ai_stay`) |

El puntero de instrucción es `zhl + Y`: Y avanza por las instrucciones y se suma a `zhl` cuando llega a 128, en cada
salto y en cada expresión.  La A y las banderas del Z80 viven en dos bytes (`lb_va`, `lb_vf`), porque los guiones las
miran después de muchas instrucciones.  Las expresiones las evalúa `ai_script_eval` (3926h).

El principio del guion del abad: las reglas que van antes que nada (Guillermo en el ala izquierda a prima o el día I;
Guillermo en la biblioteca después de la noche; la expulsión):

{{code src/c64/juego_final/logica_b_guiones.s | ^; 5B21 ai_abbot_think | +40}}

## Los personajes

**El abad.**  Primero las reglas: Guillermo en el ala izquierda a prima o el primer día, o en la biblioteca cuando no
debe, significa la expulsión (estado 0Bh: va hacia Guillermo y, cuando está cerca, *NO HABÉIS RESPETADO MIS ÓRDENES.
ABANDONAD PARA SIEMPRE ESTA ABADÍA*).  El día I a nona hace la visita de bienvenida (la entrada, la primera parada, su
celda, la celda de Guillermo), y se para cada vez que Guillermo se queda atrás (*OS ORDENO QUE VENGÁIS*, y −2 de
obsequium).  Dirige las ceremonias (ver [El reloj](Reloj.md)), manda a todos a sus celdas en completas, vigila de
noche, pide el pergamino cuando Berengario le ha contado que Guillermo lo cogió, y a tercia y a nona de algunos días
llama a Guillermo (*VENID AQUÍ, FRAY GUILLERMO*) para darle las noticias: la muerte de Venancio, la desaparición de
Berengario, la llegada de Bernardo Gui, la muerte de Severino y, el día VII, el final de la investigación.

Mientras lleva a Guillermo a algún sitio (su estado 13h), el abad solo avanza hacia su destino si Guillermo está
«cerca» (`ai_guillermo_is_close`); si no, se vuelve a buscarlo:

{{code src/c64/juego_final/logica_b_guiones.s | ^        ; \[ai_abbot_dest\] 08h = \[ai_abbot_state\] 13h >= and | +9}}

**Malaquías**, el bibliotecario, está sentado en su mesa junto al paso a la biblioteca y lo bloquea cuando Guillermo se
acerca (*LO SIENTO, VENERABLE HERMANO, NO PODÉIS SUBIR A LA BIBLIOTECA*); en vísperas coge la llave 3 de su mesa, saca a
Guillermo del edificio, avisa al abad si se queda, cierra las puertas del ala izquierda y se va a la cocina.  El día V
mata a Severino a tercia, y en vísperas muere envenenado (*ERA VERDAD, TENÍA EL PODER DE MIL ESCORPIONES*).

**El registro de Berengario**: Berengario en su mesa del scriptorium (que denuncia el pergamino si Guillermo lo coge),
luego el monje encapuchado que se lleva el libro de noche, la presentación de Jorge y, desde el día IV, **Bernardo
Gui**, que le pide el pergamino a Guillermo y al final se va de la abadía.

**El registro de Severino**: Severino el herbolario, que se presenta, avisa de las cosas extrañas de la abadía y
encuentra un libro extraño en su celda; desde el día VI **Jorge**, que espera en el finis Africae la última escena: el
libro, los guantes, el veneno y el final.

**Adso** sigue a Guillermo, va a la iglesia y al refectorio en las ceremonias, necesita la lámpara en la biblioteca
(*DEBEMOS ENCONTRAR UNA LÁMPARA, MAESTRO*), avisa cuando se agota y, de noche en la celda, pregunta *¿DORMIMOS?,
MAESTRO*: S (o Y en inglés) o no contestar pasan al día siguiente; N los deja despiertos.

## Hablar

Un guion dice una frase con `hud_say` y un número de frase detrás; la frase se desplaza por el marcador mientras el
juego sigue (ver [El texto y el marcador](Texto.md)).  `ai_guillermo_is_close` (Guillermo en el mismo piso y dentro de
una caja delante del monje) decide cuándo un monje le habla.  La caja es de 24 × 12 casillas, tumbada según hacia dónde
mira el monje (la tabla `AI_CLOSE_BOX_TABLE`, cuatro bytes por orientación):

| El monje mira hacia | Guillermo cerca si x − x del monje está en | y y − y del monje está en |
|---|---|---|
| +x (0) | −6 … +17 | −6 … +5 |
| −y (1) | −6 … +5 | −12 … +11 |
| −x (2) | −12 … +11 | −6 … +5 |
| +y (3) | −6 … +5 | −6 … +17 |


{{code src/c64/juego_final/estado_texto.s | ^; 39AE ai_guillermo_is_close | ^@no:}}

## Todas las rutinas de la lógica

{{rutinas src/c64/juego_final/logica_b.s}}

{{rutinas src/c64/juego_final/logica_b_guiones.s}}
