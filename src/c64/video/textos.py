#!/usr/bin/env python3
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

"""The YouTube text of each video (title, description with every download of abbeyofcrime.com, chapters, credits, tags:
plain text to paste), with the chapters monta.py wrote (OUT.capitulos.txt), signed with the credits' name; the downloads
block (each package apart, its link, its MD5, the site's page) is the same in every video, the Commodore ones and the PC
ones (../abadia/partida/entrega.py).
textos.py es|en VIDEO.mp4 OUT.txt [--c128 | --p500]"""
import os
import sys
from pathlib import Path

import hashlib
ESCRITORIO = Path(os.environ.get("ABADIA_ENTREGA", os.path.expanduser("~/Escritorio/abbeyofcrime")))
U = "https://abbeyofcrime.com/download/"
# the downloads, each with its MD5 (of the file beside the videos, the one the site serves): (path in ESCRITORIO,
# Spanish, English); one missing is left out (the P500's until it is made)
PAQUETES = [("c64/abadia64ks_c64.zip", "Commodore 64 · paquete completo (cinta y disco, con instrucciones)",
             "Commodore 64 · complete package (tape and disk, with instructions)"),
            ("c128/abadia128ks_c128.zip", "Commodore 128 · paquete completo (disco, con instrucciones)",
             "Commodore 128 · complete package (disk, with instructions)"),
            ("p500/abadia128ks_p500.zip", "Commodore P500 · paquete completo (disco D80 para la 8050 y D64 para la 2031 o la "
             "4040, con instrucciones)", "Commodore P500 · complete package (a D80 disk for the 8050 and a D64 for the 2031 or "
             "the 4040, with instructions)"),
            ("pc/abadia_pc_msdos.zip", "PC · MS-DOS y disquete autoarrancable (monitor EGA y menú de opciones)",
             "PC · MS-DOS and self-booting floppy (EGA monitor and options menu)"),
            ("gnu/abadia_pc_gnu_x86_64.tar.gz", "PC · GNU/Linux x86-64 (ejecutable, recursos y código fuente; necesita SDL2, "
             "zlib y glibc 2.38 o posterior)", "PC · GNU/Linux x86-64 (executable, resources and source code; needs SDL2, zlib "
             "and glibc 2.38 or later)")]


def descargas(idioma):
    es = idioma == "es"
    l = ["DESCARGAS" if es else "DOWNLOADS",
         "Página del proyecto: https://abbeyofcrime.com" if es else "Project page: https://abbeyofcrime.com", ""]
    falta_p500 = False
    for rel, t_es, t_en in PAQUETES:
        f = ESCRITORIO / rel
        if not f.exists():
            falta_p500 = falta_p500 or "p500" in rel
            continue
        l += ["• " + (t_es if es else t_en), U + f.name, "MD5: " + hashlib.md5(f.read_bytes()).hexdigest(), ""]
    l.append("Todas las versiones permiten elegir español o inglés." if es else "Every version lets you choose English or Spanish.")
    if falta_p500:
        l[-1] += (" La versión para Commodore P500 está en desarrollo y todavía no tiene descarga." if es else
                  " The Commodore P500 version is in development and has no download yet.")
    return "\n".join(l)


TEXTO = {
"en": """TITLE
The Abbey of Crime (La abadía del crimen) - Commodore 64, English - Full playthrough

DESCRIPTION
The Abbey of Crime (La abadía del crimen), the great Opera Soft adventure inspired by Umberto Eco's novel The Name of the Rose, on the Commodore 64. This video shows a whole game from beginning to end: the start menu, the complete introduction parchment, the loading screen, the seven days that Brother William of Occam and his novice Adso spend in the abbey in the year 1327, and the complete ending parchment.

ABOUT THIS VERSION
abadia64ks is my version of the game for the Commodore 64: a faithful port of the Amstrad CPC 64 KiB tape version, with its map, its rules, its clock, its monks and its puzzles. It comes on tape and on disk (for a 1541 or a 1571 drive), with Spanish and English in the same release: the language is chosen in the start menu, along with the footsteps and the text sound. The game can be saved and loaded, on tape or on disk. This video is played in English.

THE HEADS
In this 64 KiB version the characters' heads are drawn with the multicolour bitmap, like the rest of the graphics. Drawing them in high resolution, with a black mask in the VIC-II's hardware sprites, was impossible here: the game fills the Commodore 64's RAM and there is no room left for the masks, the sprites and the code that places them. The Commodore 128 version, abadia128ks, does draw every head in high resolution, and it is the full game, with the map and the rooms of the Amstrad CPC 6128 and PC version.

{descargas}

HOW IT WAS RECORDED
Recorded in real time with the VICE emulator (x64sc 3.10, PAL), loading from the disk image with the 1541 drive fully emulated and the CRT filter on. The disk loads are cut, and the loading screen stays on for 15 seconds. The game is played by an automatic player I wrote for these videos: it only tells William and Adso where to go. William walks with the game's own route search and movement code, Adso keeps his own logic, the keys pressed are the real ones, and nothing is set by hand: no coordinates, objects, hours or victory.

CHAPTERS
{capitulos}

CREDITS
La abadía del crimen: Paco Menéndez (author), Juan Delcán (graphics and cover), Opera Soft, 1987, after the novel The Name of the Rose by Umberto Eco.
Commodore 64 version, automatic player and recording: Germán Luis Aracil Boned, 2026.
Dedicated to the whole Opera Soft team, with admiration and gratitude.

Germán Luis Aracil Boned
https://abbeyofcrime.com

TAGS
The Abbey of Crime, La abadia del crimen, La abadía del crimen, Opera Soft, Paco Menendez, Juan Delcan, 1987, Commodore 64, C64, abadia64ks, English, full playthrough, walkthrough, longplay, retro, retro gaming, 8-bit, adventure, isometric, The Name of the Rose, Umberto Eco, VICE
""",
"es": """TÍTULO
La abadía del crimen - Commodore 64, en español - Partida completa

DESCRIPCIÓN
La abadía del crimen, la gran aventura de Opera Soft inspirada en la novela El nombre de la rosa de Umberto Eco, en el Commodore 64. En este vídeo se ve una partida entera de principio a fin: el menú de inicio, el pergamino inicial completo, la pantalla de carga, los siete días que fray Guillermo de Occam y su novicio Adso pasan en la abadía en el año 1327 y el pergamino final completo.

SOBRE ESTA VERSIÓN
abadia64ks es mi versión del juego para el Commodore 64: una conversión fiel de la versión de cinta de 64 KiB del Amstrad CPC, con su mapa, sus reglas, su reloj, sus monjes y sus enigmas. Viene en cinta y en disco (para una unidad 1541 o 1571), con español e inglés en la misma edición: el idioma se elige en el menú de inicio, junto con el sonido de los pasos y el del texto. La partida se puede guardar y cargar, en cinta o en disco. Este vídeo está jugado en español.

LAS CABEZAS
En esta versión de 64 KiB las cabezas de los personajes se dibujan con el mapa de bits multicolor, como el resto de los gráficos. Ponerlas en alta resolución, con una máscara negra en los sprites del VIC-II, fue imposible aquí: el juego llena la RAM del Commodore 64 y no queda sitio para las máscaras, los sprites y el código que los coloca. La versión para Commodore 128, abadia128ks, sí dibuja todas las cabezas en alta resolución, y es el juego completo, con el mapa y las salas de la versión del Amstrad CPC 6128 y del PC.

{descargas}

CÓMO SE HA GRABADO
Grabado en tiempo real con el emulador VICE (x64sc 3.10, PAL), cargando desde la imagen de disco con la unidad 1541 emulada al completo y con el filtro de pantalla CRT. Las cargas del disco están recortadas y la pantalla de carga se ve 15 segundos. La partida la juega un jugador automático que he escrito para estos vídeos: solo les dice a Guillermo y a Adso adónde ir. Guillermo anda con la búsqueda de caminos y el movimiento del propio juego, Adso conserva su propia lógica, las teclas que se pulsan son las reales y nada se pone a mano: ni coordenadas, ni objetos, ni horas, ni la victoria.

CAPÍTULOS
{capitulos}

CRÉDITOS
La abadía del crimen: Paco Menéndez (autor), Juan Delcán (gráficos y carátula), Opera Soft, 1987, basado en la novela El nombre de la rosa de Umberto Eco.
Versión para Commodore 64, jugador automático y grabación: Germán Luis Aracil Boned, 2026.
Dedicado a todo el equipo de Opera Soft, con admiración y agradecimiento.

Germán Luis Aracil Boned
https://abbeyofcrime.com

ETIQUETAS
La abadía del crimen, La abadia del crimen, The Abbey of Crime, Opera Soft, Paco Menéndez, Juan Delcán, 1987, Commodore 64, C64, abadia64ks, español, partida completa, gameplay, longplay, retro, juegos retro, 8 bits, aventura, isométrico, El nombre de la rosa, Umberto Eco, VICE
""",
}


TEXTO128 = {
"en": """TITLE
The Abbey of Crime (La abadía del crimen) - Commodore 128, full game, English - Full playthrough

DESCRIPTION
The Abbey of Crime (La abadía del crimen), the great Opera Soft adventure inspired by Umberto Eco's novel The Name of the Rose, complete on the Commodore 128. This video shows a whole game from beginning to end: the start menu, the complete introduction parchment, the loading screen, the seven days that Brother William of Occam and his novice Adso spend in the abbey in the year 1327, and the complete ending parchment.

ABOUT THIS VERSION
abadia128ks is my version of the game for the Commodore 128, in the machine's own C128 mode: the full game, with the map, the rooms, the rules, the clock, the monks and the puzzles of the full version, as on the Amstrad CPC 6128 and the PC. It makes the most of the 128: the whole game is in memory at once, the processor runs at 2 MHz while the beam is in the borders, and the Ave Maria is heard at compline. The disk boots by itself (on a 1541 or a 1571 drive), with Spanish and English in the same release: the language is chosen in the start menu, along with the footsteps, the text sound and the Ave Maria. The game can be saved and loaded on disk, in ten slots. This video is played in English.

THE HIGH-RESOLUTION HEADS
In this version every character's head is drawn in high resolution, as on the PC: the black strokes of each face are a black mask in a high-resolution hardware sprite of the VIC-II, laid over the multicolour bitmap that keeps the colours. William, Adso, the monks and even the reflections in the mirror keep all the detail of the original faces. In the Commodore 64 version, abadia64ks, this was impossible for lack of RAM: the game fills the 64 KiB and there is no room left for the masks, the sprites and their code.

{descargas}

HOW IT WAS RECORDED
Recorded in real time with the VICE emulator (x128 3.10, PAL), booting from the disk image with the 1541 drive fully emulated and the CRT filter on. The disk loads are cut, and the loading screen stays on for 15 seconds. The game is played by an automatic player I wrote for these videos: it only tells William and Adso where to go. William walks with the game's own route search and movement code, Adso keeps his own logic, the keys pressed are the real ones, and nothing is set by hand: no coordinates, objects, hours or victory.

CHAPTERS
{capitulos}

CREDITS
La abadía del crimen: Paco Menéndez (author), Juan Delcán (graphics and cover), Opera Soft, 1987, after the novel The Name of the Rose by Umberto Eco.
Commodore 128 version, automatic player and recording: Germán Luis Aracil Boned, 2026.
Dedicated to the whole Opera Soft team, with admiration and gratitude.

Germán Luis Aracil Boned
https://abbeyofcrime.com

TAGS
The Abbey of Crime, La abadia del crimen, La abadía del crimen, Opera Soft, Paco Menendez, Juan Delcan, 1987, Commodore 128, C128, abadia128ks, full game, high resolution, English, full playthrough, walkthrough, longplay, retro, retro gaming, 8-bit, adventure, isometric, The Name of the Rose, Umberto Eco, VICE
""",
"es": """TÍTULO
La abadía del crimen - Commodore 128, juego completo, en español - Partida completa

DESCRIPCIÓN
La abadía del crimen, la gran aventura de Opera Soft inspirada en la novela El nombre de la rosa de Umberto Eco, completa en el Commodore 128. En este vídeo se ve una partida entera de principio a fin: el menú de inicio, el pergamino inicial completo, la pantalla de carga, los siete días que fray Guillermo de Occam y su novicio Adso pasan en la abadía en el año 1327 y el pergamino final completo.

SOBRE ESTA VERSIÓN
abadia128ks es mi versión del juego para el Commodore 128, en el propio modo C128 de la máquina: el juego completo, con el mapa, las salas, las reglas, el reloj, los monjes y los enigmas de la versión completa, como en el Amstrad CPC 6128 y en el PC. Aprovecha el 128 a fondo: todo el juego está en memoria a la vez, el procesador va a 2 MHz mientras el haz recorre los bordes y en completas suena el Ave María. El disco arranca solo (en una unidad 1541 o 1571), con español e inglés en la misma edición: el idioma se elige en el menú de inicio, junto con el sonido de los pasos, el del texto y el Ave María. La partida se puede guardar y cargar en disco, en diez huecos. Este vídeo está jugado en español.

LAS CABEZAS EN ALTA RESOLUCIÓN
En esta versión todas las cabezas de los personajes se dibujan en alta resolución, como en el PC: los trazos negros de cada cara son una máscara negra en un sprite de alta resolución del VIC-II, colocada sobre el mapa de bits multicolor que conserva los colores. Guillermo, Adso, los monjes y hasta los reflejos en el espejo conservan todo el detalle de las caras originales. En la versión para Commodore 64, abadia64ks, fue imposible por falta de RAM: el juego llena los 64 KiB y no queda sitio para las máscaras, los sprites y su código.

{descargas}

CÓMO SE HA GRABADO
Grabado en tiempo real con el emulador VICE (x128 3.10, PAL), arrancando desde la imagen de disco con la unidad 1541 emulada al completo y con el filtro de pantalla CRT. Las cargas del disco están recortadas y la pantalla de carga se ve 15 segundos. La partida la juega un jugador automático que he escrito para estos vídeos: solo les dice a Guillermo y a Adso adónde ir. Guillermo anda con la búsqueda de caminos y el movimiento del propio juego, Adso conserva su propia lógica, las teclas que se pulsan son las reales y nada se pone a mano: ni coordenadas, ni objetos, ni horas, ni la victoria.

CAPÍTULOS
{capitulos}

CRÉDITOS
La abadía del crimen: Paco Menéndez (autor), Juan Delcán (gráficos y carátula), Opera Soft, 1987, basado en la novela El nombre de la rosa de Umberto Eco.
Versión para Commodore 128, jugador automático y grabación: Germán Luis Aracil Boned, 2026.
Dedicado a todo el equipo de Opera Soft, con admiración y agradecimiento.

Germán Luis Aracil Boned
https://abbeyofcrime.com

ETIQUETAS
La abadía del crimen, La abadia del crimen, The Abbey of Crime, Opera Soft, Paco Menéndez, Juan Delcán, 1987, Commodore 128, C128, abadia128ks, juego completo, alta resolución, español, partida completa, gameplay, longplay, retro, juegos retro, 8 bits, aventura, isométrico, El nombre de la rosa, Umberto Eco, VICE
""",
}

TEXTO500 = {
"en": """TITLE
The Abbey of Crime (La abadía del crimen) - Commodore P500, full game, English - Full playthrough

DESCRIPTION
The Abbey of Crime (La abadía del crimen), the great Opera Soft adventure inspired by Umberto Eco's novel The Name of the Rose, complete on the Commodore P500. This video shows a whole game from beginning to end: the start menu, the complete introduction parchment, the loading screen, the seven days that Brother William of Occam and his novice Adso spend in the abbey in the year 1327, and the complete ending parchment.

ABOUT THIS VERSION
This is my version of the game for the Commodore P500, the CBM-II 510 with 128 KiB, a rare machine with the C64's VIC-II and SID: the full game, the same as my Commodore 128 version (abadia128ks), with the map, the rooms, the rules, the clock, the monks and the puzzles of the full version, as on the Amstrad CPC 6128 and the PC. The P500's processor, the MOS 6509, addresses up to 1 MiB in banks of 64 KiB: the game runs in bank 0, its rooms, texts, the faces' masks and the Ave Maria live in bank 1, and the chips in bank 15, all of it reached with the 6509's own instructions for reading and writing another bank. The disk (a D80 for the 8050 drive and a D64 for the 2031 or 4040) loads with SHIFT + RUN/STOP, with Spanish and English in the same release: the language is chosen in the start menu, along with the footsteps, the text sound and the Ave Maria at compline. The game can be saved and loaded on disk, in ten slots. This video is played in English.

THE HIGH-RESOLUTION HEADS
As on the Commodore 128, every character's head is drawn in high resolution, as on the PC: the black strokes of each face are a black mask in a high-resolution hardware sprite of the VIC-II, laid over the multicolour bitmap that keeps the colours.

{descargas}

HOW IT WAS RECORDED
Recorded in real time with the VICE emulator (xcbm5x0 3.10, a P500 with 128 KiB, PAL), loading from the disk image with the 8050 drive fully emulated and the CRT filter on. The disk loads are cut, and the loading screen stays on for 15 seconds. The game is played by an automatic player I wrote for these videos: it only tells William and Adso where to go. William walks with the game's own route search and movement code, Adso keeps his own logic, the keys pressed are the real ones, and nothing is set by hand: no coordinates, objects, hours or victory.

CHAPTERS
{capitulos}

CREDITS
La abadía del crimen: Paco Menéndez (author), Juan Delcán (graphics and cover), Opera Soft, 1987, after the novel The Name of the Rose by Umberto Eco.
Commodore P500 and Commodore 128 version, automatic player and recording: Germán Luis Aracil Boned, 2026.{foto}
Dedicated to the whole Opera Soft team, with admiration and gratitude.

Germán Luis Aracil Boned
https://abbeyofcrime.com

TAGS
The Abbey of Crime, La abadia del crimen, La abadía del crimen, Opera Soft, Paco Menendez, Juan Delcan, 1987, Commodore P500, CBM-II, CBM 510, MOS 6509, full game, high resolution, English, full playthrough, walkthrough, longplay, retro, retro gaming, 8-bit, adventure, isometric, The Name of the Rose, Umberto Eco, VICE
""",
"es": """TÍTULO
La abadía del crimen - Commodore P500, juego completo, en español - Partida completa

DESCRIPCIÓN
La abadía del crimen, la gran aventura de Opera Soft inspirada en la novela El nombre de la rosa de Umberto Eco, completa en el Commodore P500. En este vídeo se ve una partida entera de principio a fin: el menú de inicio, el pergamino inicial completo, la pantalla de carga, los siete días que fray Guillermo de Occam y su novicio Adso pasan en la abadía en el año 1327 y el pergamino final completo.

SOBRE ESTA VERSIÓN
Es mi versión del juego para el Commodore P500, el CBM-II 510 de 128 KiB, un ordenador poco común con el VIC-II y el SID del C64: el juego completo, el mismo que en mi versión para Commodore 128 (abadia128ks), con el mapa, las salas, las reglas, el reloj, los monjes y los enigmas de la versión completa, como en el Amstrad CPC 6128 y en el PC. El procesador del P500, el MOS 6509, direcciona hasta 1 MiB en bancos de 64 KiB: el juego corre en el banco 0, sus salas, textos, las máscaras de las caras y el Ave María viven en el banco 1 y los chips en el banco 15, todo ello alcanzado con las instrucciones propias del 6509 para leer y escribir en otro banco. El disco (un D80 para la unidad 8050 y un D64 para la 2031 o la 4040) se carga con SHIFT + RUN/STOP, con español e inglés en la misma edición: el idioma se elige en el menú de inicio, junto con el sonido de los pasos, el del texto y el Ave María de completas. La partida se puede guardar y cargar en disco, en diez huecos. Este vídeo está jugado en español.

LAS CABEZAS EN ALTA RESOLUCIÓN
Como en el Commodore 128, todas las cabezas de los personajes se dibujan en alta resolución, como en el PC: los trazos negros de cada cara son una máscara negra en un sprite de alta resolución del VIC-II, colocada sobre el mapa de bits multicolor que conserva los colores.

{descargas}

CÓMO SE HA GRABADO
Grabado en tiempo real con el emulador VICE (xcbm5x0 3.10, un P500 de 128 KiB, PAL), cargando desde la imagen de disco con la unidad 8050 emulada al completo y con el filtro de pantalla CRT. Las cargas del disco están recortadas y la pantalla de carga se ve 15 segundos. La partida la juega un jugador automático que he escrito para estos vídeos: solo les dice a Guillermo y a Adso adónde ir. Guillermo anda con la búsqueda de caminos y el movimiento del propio juego, Adso conserva su propia lógica, las teclas que se pulsan son las reales y nada se pone a mano: ni coordenadas, ni objetos, ni horas, ni la victoria.

CAPÍTULOS
{capitulos}

CRÉDITOS
La abadía del crimen: Paco Menéndez (autor), Juan Delcán (gráficos y carátula), Opera Soft, 1987, basado en la novela El nombre de la rosa de Umberto Eco.
Versión para Commodore P500 y Commodore 128, jugador automático y grabación: Germán Luis Aracil Boned, 2026.{foto}
Dedicado a todo el equipo de Opera Soft, con admiración y agradecimiento.

Germán Luis Aracil Boned
https://abbeyofcrime.com

ETIQUETAS
La abadía del crimen, La abadia del crimen, The Abbey of Crime, Opera Soft, Paco Menéndez, Juan Delcán, 1987, Commodore P500, CBM-II, CBM 510, MOS 6509, juego completo, alta resolución, español, partida completa, gameplay, longplay, retro, juegos retro, 8 bits, aventura, isométrico, El nombre de la rosa, Umberto Eco, VICE
""",
}


def main():
    args = sys.argv[1:]
    c128 = "--c128" in args
    if c128: args.remove("--c128")
    p500 = "--p500" in args
    if p500: args.remove("--p500")
    idioma, video, salida = args[:3]
    caps = Path(video).with_suffix(".capitulos.txt").read_text().strip()
    texto = (TEXTO500 if p500 else TEXTO128 if c128 else TEXTO)[idioma]
    foto = ""                               # (the P500's photograph in the cover and the thumbnail: its author's)
    if p500 and os.environ.get("ABADIA_FOTO_P500"):
        foto = ("\nFoto del Commodore P500 de la portada y la miniatura: Nightfall Crew (nightfallcrew.com)." if idioma == "es"
                else "\nPhotograph of the Commodore P500 in the cover and the thumbnail: Nightfall Crew (nightfallcrew.com).")
    extra = dict(foto=foto) if p500 else {}
    Path(salida).write_text(texto.format(descargas=descargas(idioma), capitulos=caps, **extra))
    print(salida)

if __name__ == "__main__":
    main()
