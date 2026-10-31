<!-- Made by tools/wiki.py from doc/wiki/fuentes/Parchments.md: edit the template, not this page. -->
# Presentation and ending

[Home](Home.md) · previous: [Loading: tape and disks](Loading.md) · next: [Building and certification](Building.md)

The game begins and ends with a **parchment**: a page of gothic writing that fills itself letter by letter, with
music.  On the Commodores these are separate programs, written in C with cc65 in September 2016 for this game (`abadia.c`,
`manuscrito.c`, `io.c` in `src/c64/presentacion/`), kept as they were with only the changes the releases needed
(`src/c64/presentacion/NOTAS.md` lists each one as a diff, with its reason).

## The introduction

`abadia.c` reads the loading picture first ("Loading"), then writes the introduction's parchment; a key ends it, the
music stops, and `gameload` puts the picture on the game's screen and starts the game's loader under it:

[`src/c64/presentacion/abadia.c`](../../src/c64/presentacion/abadia.c#L29-L93), lines 29–93:

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

## Writing a parchment

`manusrun` reads the text — the CPC tape's own text, byte for byte, in the CPC's codes — and draws each glyph pixel by
pixel at the pace of the original; a capital letter is drawn in red, two pixels to the left; at the bottom of the page
it turns the page:

[`src/c64/presentacion/manuscrito.c`](../../src/c64/presentacion/manuscrito.c#L192-L240), lines 192–240:

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

The glyphs and the page's border are those of the CPC tape (`pp.bin`), plus four glyphs drawn in the font's style for
the credits (0, 6, @ and B).  The credits page comes after the original text: *version commodore: German Luis Aracil
Boned, garacilb@gmail.com, 2016 - 2026* (the font has no accents).

## The music

The parchments' tunes are the CPC tape's: its player was translated to 6502 (`src/c64/pergamino/musica.s`) and its
register writes go to the SID through the same voicing as the game's sound (`src/c64/presentacion/sid.s`), which also
scans the keyboard every fifth tick so that the C code's key tests work.  The writes are checked one by one against the
CPC's: 2828 identical writes over the introduction's first 64 seconds.

## The ending

At 100 % the game loads "FINAL": the same parchment code with the CPC's ending text, then the dedication to all of Opera
Soft's team, over and over, as the CPC did:

[`src/c64/presentacion/final.c`](../../src/c64/presentacion/final.c#L18-L25), lines 18–25:

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

## Both languages

The tape and the disks carry both languages' texts, glyphs and pictures inside the programs (the English parchments
are a translation made for this version, broken into lines with the glyphs' own widths and hyphenated by syllables:
`src/c64/ingles/pergamino_en.py`); the menu's language decides which are shown.

## The test disk

`src/c64/presentacion/pruebas/disco_prueba/` builds a disk with the presentation, the game and the ending, and checks it
in VICE: every page of both parchments against a model of the pages (which is itself checked against the CPC's
screen, page for page), the music's writes against the CPC's, the picture during the load, the game's memory at its
start, and the ending reached through the game's own code.  40 checks, all passing.
