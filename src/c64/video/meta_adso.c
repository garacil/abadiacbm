/* Optional host-side goals; original NPC route and movement code are unchanged. */
#define ai_adso_think ai_adso_think_original
#include "../../../juego/f_logica_b.c"
#undef ai_adso_think
#include "../../../juego/datos_camino.h"
#define META_WORKSPACE 0x3568u

uint8_t meta_adso_active;
uint8_t meta_adso_x, meta_adso_y, meta_adso_z, meta_adso_o;
uint8_t meta_guillermo_active;
uint8_t meta_guillermo_stream[45];

void meta_guillermo_behaviour(uint16_t chr, uint16_t spr, uint16_t self)
{
    uint8_t saved[45];
    uint16_t pointer;
    if (!meta_guillermo_active) {
        chr_guillermo_behaviour(chr, spr, self);
        return;
    }
    if (rb(D64_GAME_CAMERA_OTHER) != 0) return;
    pointer = rw(chr + 12);
    memcpy(saved, ram + META_WORKSPACE, 45);
    memcpy(ram + META_WORKSPACE, meta_guillermo_stream, 45);
    ww(chr + 12, META_WORKSPACE);
    chr_ai_follow_commands(chr, spr);
    ww(chr + 12, pointer);
    memcpy(ram + META_WORKSPACE, saved, 45);
}

void ai_adso_think(uint16_t chr)
{
    ai_adso_think_original(chr);
    if (!meta_adso_active) return;
    wb(D64_AI_ADSO_DEST, 0);
    wb(D64_AI_ADSO_PLACES, meta_adso_x);
    wb(D64_AI_ADSO_PLACES + 1, meta_adso_y);
    wb(D64_AI_ADSO_PLACES + 2, (uint8_t)(meta_adso_z | (meta_adso_o << 6)));
}
