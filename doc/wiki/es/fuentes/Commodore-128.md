# El Commodore 128

[Inicio](Inicio.md) · anterior: [La plataforma del Commodore 64](Plataforma-C64.md) · siguiente: [El Commodore P500](Commodore-P500.md)

abadia128ks funciona en el propio modo C128, no en su modo C64.  Es el mismo juego 6502, ensamblado con `-D C128` (la
máquina), `-D COMPLETO` (el juego completo de las versiones de CPC 6128 y PC) y `-D VELOZ` (el trabajo de velocidad), y
aprovecha lo que añade el C128: otros 64 KiB de RAM, los 2 MHz y sitio para las cabezas en alta resolución.  Cada dato
del C128 que uso lo leí en *Mapping the Commodore 128* (Ottis R. Cowper, COMPUTE! Books, 1986;
`doc/referencias/c128.md`) y lo comprobé en el x128 de VICE.

## Dos bloques de RAM

El juego corre en el bloque 0, como en el C64; el registro de configuración de la MMU, `$FF00`, hace el papel del `$01`
del C64.  El bloque 1 guarda lo que el generador del mapa sacó del bloque 0: la tabla de salas, los textos y los
trazos negros de las cabezas.  La RAM común de abajo (4 KiB, siempre del bloque 0) guarda las rutinas que llegan al
bloque 1 y las rutinas de interrupción, para que una interrupción pueda llegar esté puesto el bloque que esté:

{{code src/c64/plataforma/c128.s | ^; abadia64ks, the Commodore 128's own platform | ^; SALA: 256 bytes}}

El juego lee la tabla de salas a través de dos macros (`LEE_SALA`, `PON_SALA`, ver [Del Z80 al 6502](Del-Z80-al-6502.md))
que en el C128 se convierten en `JSR far_lee` / `JSR far_pon`, y el registro de una sala se copia entero a la RAM común
antes de construirla.

## 2 MHz en los bordes

El 8502 puede ir a 2 MHz, pero entonces el VIC-II no puede enseñar imagen.  El juego pasa a 2 MHz mientras el haz está
por encima y por debajo de la ventana de imagen, donde el VIC-II no lee nada (112 de las 312 líneas de un cuadro PAL),
con dos temporizadores de la CIA 2 sincronizados con el haz, cuyas NMI cambian el reloj:

{{code src/c64/plataforma/c128.s | ^; Speed \(everything optimised for speed\) | +9}}

{{code src/c64/plataforma/interrupcion.s | ^; the C128: CIA 2's timers switch the 8502's clock | ^\.endproc}}

## Las cabezas en alta resolución

El bitmap multicolor reduce a la mitad la resolución horizontal, y las caras de los personajes pierden sus rasgos de
un píxel.  En el C128 cada cabeza (la de Guillermo, la de Adso, la cara de cada monje y sus reflejos en el espejo) recibe
sus trazos negros de un **sprite por hardware en alta resolución** del VIC-II, a la resolución completa del PC, puesto
encima de la cabeza multicolor, que conserva los rellenos.  El sprite y el bitmap tienen que cambiar en el mismo cuadro
que se enseña, y una baldosa que está delante de una cabeza tiene que tapar también los píxeles de su sprite:

{{code src/c64/juego_final/cabezas128.s | ^; Heads h = 0-5: the sprite records 0-5 | ^; slot and the VIC-II's registers set}}

En las salas a oscuras de la biblioteca el juego compone solo el rectángulo de la luz de la lámpara, con los
personajes mezclados en él; las cabezas que se mezclan ahí también se registran, así que sus trazos en alta resolución
siguen a la luz:

{{code src/c64/juego_final/cabezas128.s | ^; The dark rooms \(the library with the lamp | +7}}

## El Ave María

En completas la versión de PC tocaba un Ave María digitalizado.  El C128 toca las mismas muestras (8062 por segundo,
de los datos de la versión de PC) a través del registro de volumen del SID, con el juego parado mientras suena, como en
el PC:

{{code src/c64/plataforma/c128.s | ^; c128_ave: the game frozen | +7}}

La opción 4 del menú de inicio lo quita: el cargador sustituye su llamada por tres `NOP` y las muestras ni siquiera se
cargan.

## La carga del final

Con el 100 % el juego carga el programa del final («FINAL») con el KERNAL.  El juego había sobrescrito el código y los
vectores de interrupción del KERNAL en la RAM (`$FF05-$FF44`, `$FFFA-$FFFF`) de los dos bloques; con una 1541, la carga
lenta admite interrupciones entre byte y byte, que saltaban al código del juego.  Por eso `plat_final` los vuelve a
copiar primero de la ROM a la RAM de los dos bloques, como hace el propio reinicio del KERNAL, y el final se carga con
una 1541 o con una 1571:

{{code src/c64/plataforma/c128.s | ^        ldy     #\$40                    ; the KERNAL's interrupt | ^        bcs     kram}}

## Todas las rutinas de las cabezas

{{rutinas src/c64/juego_final/cabezas128.s}}
