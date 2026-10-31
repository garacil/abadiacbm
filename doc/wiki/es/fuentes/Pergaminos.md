# Presentación y final

[Inicio](Inicio.md) · anterior: [La carga: cinta y discos](Carga.md) · siguiente: [Construcción y certificación](Construccion.md)

El juego empieza y termina con un **pergamino**: una página de letra gótica que se va escribiendo letra a letra, con
música.  En los Commodore son programas aparte, que escribí en C con cc65 en septiembre de 2016 para este juego
(`abadia.c`, `manuscrito.c`, `io.c` en `src/c64/presentacion/`), y que conservo como estaban, con solo los cambios que
han necesitado las ediciones (`src/c64/presentacion/NOTAS.md` enumera cada uno como un diff, con su motivo).

## La presentación

`abadia.c` lee primero la pantalla de carga («Loading») y después escribe el pergamino de la presentación; una tecla lo
termina, la música se para y `gameload` pone la imagen en la pantalla del juego y arranca debajo el cargador del juego:

{{code src/c64/presentacion/abadia.c | ^int main\(void\) | ^\x7d}}

## Escribir un pergamino

`manusrun` lee el texto (el propio texto de la cinta del CPC, byte a byte, con los códigos del CPC) y dibuja cada letra
píxel a píxel al ritmo del original; una mayúscula se dibuja en rojo, dos píxeles a la izquierda; al llegar al final de
la página, pasa la página:

{{code src/c64/presentacion/manuscrito.c | ^void manusrun\(unsigned char \*text\) | ^				color = }}

Las letras y el borde de la página son los de la cinta del CPC (`pp.bin`), más cuatro letras dibujadas en el estilo de
la fuente para los créditos (0, 6, @ y B).  La página de los créditos va después del texto original: *version
commodore: German Luis Aracil Boned, garacilb@gmail.com, 2016 - 2026* (la fuente no tiene tildes).

## La música

Las melodías de los pergaminos son las de la cinta del CPC: traduje su reproductor al 6502
(`src/c64/pergamino/musica.s`) y sus escrituras de registros van al SID con el mismo timbre que el sonido del juego
(`src/c64/presentacion/sid.s`), que además explora el teclado cada quinto tick para que funcionen las pruebas de teclas
del código en C.  Comprobé las escrituras una a una contra las del CPC: 2828 escrituras idénticas en los primeros 64
segundos de la presentación.

## El final

Con el 100 % el juego carga «FINAL»: el mismo código de pergamino con el texto del final del CPC y después la
dedicatoria a todo el equipo de Opera Soft, una y otra vez, como hacía el CPC:

{{code src/c64/presentacion/final.c | ^/\* "final": the ending parchment | ^#include}}

## Los dos idiomas

La cinta y los discos llevan dentro de los programas los textos, las letras y las imágenes de los dos idiomas (los
pergaminos en inglés son una traducción hecha para esta versión, partida en líneas con los anchos de las propias letras
y con guiones por sílabas: `src/c64/ingles/pergamino_en.py`); el idioma del menú decide cuáles se enseñan.

## El disco de pruebas

`src/c64/presentacion/pruebas/disco_prueba/` construye un disco con la presentación, el juego y el final, y lo
comprueba en VICE: cada página de los dos pergaminos contra un modelo de las páginas (que a su vez está comprobado
contra la pantalla del CPC, página a página), las escrituras de la música contra las del CPC, la imagen durante la
carga, la memoria del juego al empezar y el final alcanzado con el propio código del juego.  40 comprobaciones, todas
correctas.
