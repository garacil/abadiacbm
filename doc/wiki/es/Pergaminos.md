<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Pergaminos.md: se edita la plantilla, no esta página. -->
# Presentación y final

[Inicio](Inicio.md) · anterior: [La carga: cinta y discos](Carga.md) · siguiente: [Construcción y certificación](Construccion.md)

El juego empieza y termina con un **pergamino**: una página de letra gótica que se va escribiendo letra a letra, con
música.  En los Commodore son programas aparte, que escribí en C con cc65 en septiembre de 2016 para este juego
(`abadia.c`, `manuscrito.c`, `io.c` en `src/c64/presentacion/`), y que conservo como estaban, con solo los cambios que
han necesitado las ediciones (`src/c64/presentacion/NOTAS.md` enumera cada uno como un diff, con su motivo).

## La presentación

`abadia.c` lee primero la pantalla de carga («Loading») y después escribe el pergamino de la presentación; una tecla lo
termina, la música se para y `gameload` pone la imagen en la pantalla del juego y arranca debajo el cargador del juego:

[`src/c64/presentacion/abadia.c`](../../../src/c64/presentacion/abadia.c#L29-L93), líneas 29–93:

```c
int main(void)
{
    FILE* fp;
    unsigned int k;
    unsigned char *buffer;
#if defined(__CBM510__)    
    unsigned int s;
#endif

#if defined(__CBM510__) && defined(CINTA)
    menu500();         // The P500's disk: the start menu (menu500.c), as the Commodore 128's
#endif
    bgcolor(0);
    bordercolor(0);
    textcolor(1);
    clrscr();
    puts("Loading");

#if defined(CINTA)
    buffer = CINTA_INGLES ? cinta_koa_en : cinta_koa_es;    /* the tape: in the program (presentacion.h) */
#else
    fp = fopen("abadia.koa", "rb");
#if defined(__CBM510__)
    fread((unsigned char*) VIC_MEM, 1, 8000, fp);
    fread((unsigned char*) VIC_SCR, 1, 1000, fp);
    buffer = malloc(1000);
    fread((unsigned char*)  buffer, 1, 1000, fp);
    fclose(fp);
    for (s = 0; s < 1000; s++) {
        pokebsys(VIC_COL + s, buffer[s]);
    }
  free(buffer);    
#else
    buffer = malloc(10000);
    fread((unsigned char*) buffer       , 1, 8000, fp);
    fread((unsigned char*) buffer + 8000, 1, 1000, fp);
    fread((unsigned char*) buffer + 9000, 1, 1000, fp);
    fclose(fp);
#endif
#endif

#if defined(__CBM510__) && !defined(CINTA)
    screenbitmapmulticolor();

    while(1) {
        k = (int)cgetc();
        if (k)
            break;
    }
#endif

    manusintro();

    while(1) {
        k = (int)cgetc();
        if (k)
            break;
    }
#if !defined(__CBM510__) || defined(CINTA)
    musicstop();       // The parchment's music ends with it (presentacion.c)
    gameload(buffer);  // The picture on the game's screen, the game loads under it and starts: never returns
#endif
    //screenbitmap();
  return EXIT_SUCCESS;
}
```

## Escribir un pergamino

`manusrun` lee el texto (el propio texto de la cinta del CPC, byte a byte, con los códigos del CPC) y dibuja cada letra
píxel a píxel al ritmo del original; una mayúscula se dibuja en rojo, dos píxeles a la izquierda; al llegar al final de
la página, pasa la página:

[`src/c64/presentacion/manuscrito.c`](../../../src/c64/presentacion/manuscrito.c#L192-L240), líneas 192–240:

```c
void manusrun(unsigned char *text)
{
    unsigned int posX;
    unsigned int posY;
    unsigned int newPosX, newPosY;
    char color;
    unsigned char *charOffset;
    unsigned int pixeladdr;
    unsigned char bit;
    unsigned char capital;

    if (!text)
        return;
    manusini();
    musicstart(); // The parchment's music starts with it (presentacion.c)
    posX = 76;
    posY = 16;
    while (1) {
#if !(defined(CINTA) && defined(FINAL))   /* the tape's ending: no key does anything */
        if (kbhit()) // A key ends the parchment at once, as space on the CPC (the caller's cgetc takes it)
            break;
#endif
        switch(*text) {

            case 0x1a: // The end
                break;

            case 0x0d: // New line
                posX = 76;
                posY += 16;
                if (posY > 164){
                    posX = 76;
                    posY = 16;
                    nextpage();
                }
                break;

            case 0x20: // space
                posX += 10;
                break;

            case 0x0a: // New page
                posX = 76;
                posY = 16;
                nextpage();
                break;

            default:
                color = ((*text & 0x60) == 0x40) ? 0xa2 : 0xa0; // Select colour to write letter
```

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

[`src/c64/presentacion/final.c`](../../../src/c64/presentacion/final.c#L18-L25), líneas 18–25:

```c
/* "final": the ending parchment, the program the game loads (plat_final, c64/plataforma/disco.s) when it is won at
 * 100 %, as the CPC tape's ABADIA64.BN1: the parchment (manuscrito.c's manusrun) with the CPC's ending text
 * (text2.bin, the tape's bytes plus the credits and dedication: datos.py) and the ending's music, written
 * over and over as the CPC does (its end
 * routine calls the parchment for ever, 3376h): a key ends the text at once (manusrun's kbhit) or waits at its end
 * (cgetc, as the abadia.c), the music stops (6038h) and the parchment is drawn again with the music from the
 * start of its channel A (6019h-6022h).  In the style of abadia.c's main and manuscrito.c's manusintro. */
#include <conio.h>
```

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
