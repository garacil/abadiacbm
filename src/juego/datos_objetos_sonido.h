/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

/* abadia64ks: the 64K data addresses of the group objetos_sonido (64K 0983-128E: objects, doors, the
 * sprite projection of doors and objects, the sound sequencer and its triggers, the AY writes).
 * PC names (c/include/direcciones.h of the PC rebuild) where the datum is the same. */
#ifndef DATOS_OBJETOS_SONIDO_H
#define DATOS_OBJETOS_SONIDO_H

/* ---- objects and doors ---- */

#define D64_CHR_PATH_ALTERNATIVES   0x0203u  /* candidate destinations of the route search, 3 bytes each, FF ends; PC chr_path_alternatives AAC3 */
#define D64_CHR_PATH_ALT_PTR        0x0213u  /* word: the candidate being tried; PC chr_path_alt_ptr AAD3 */
#define D64_OBJ_DOOR_ORIENT_TABLE   0x021Du  /* door sprites, 4 entries of 8 bytes by (door orientation - camera) & 3: screen dx, dy, depth, flip bit, grid dx, dy; PC obj_door_orient_table AADD */
#define D64_OBJ_ENTITY_CALLBACK     0x09BAu  /* word, SMC: the operand of CALL NC at 09B9, the callback of obj_for_each_visible (0A2B objects, 0A42 doors); PC obj_entity_callback AC69 */
#define D64_OBJ_FOR_EACH_PATCH      0x09D4u  /* SMC: 00h (NOP) obj_for_each_visible goes on, C9h (RET, set by obj_redraw_one_object) it stops after one entry; PC CS_ST_OBJ_FOR_EACH_PATCH 1214 */
#define D64_OBJ_ROOM_REDRAW         0x0A6Du  /* SMC: the operand of OR at 0A6C (written by 21B4), ORed into byte 0 of every door sprite; PC obj_room_redraw AC65 */
#define D64_OBJ_DOOR_MOVED          0x0A6Fu  /* SMC: the operand of OR at 0A6E, 80h while the door being processed changes state, else 0; PC obj_door_moved AC63 */
#define D64_OBJ_DOOR_CELL_STEPS     0x0AB4u  /* words: the height-buffer step along a door leaf by door orientation, +1, -24, -1, +24; PC obj_door_cell_steps AC3D */
#define D64_OBJ_DOOR_CAMERA_OFFSETS 0x0B0Du  /* door sprites, entry (3 - camera) & 3 of 4 bytes: screen dx, dy, grid dx, dy; PC obj_door_camera_offsets AC45 */
#define D64_CHR_PROJECT_TEST        0x2684u  /* SMC in chr_project: 00h (NOP) normal, C9h (RET) while spr_project_entity runs: it returns after the position; PC CS_ST_L_25D9 */
#define D64_OBJ_DOOR_GFX_FLIPPED    0x28C9u  /* the current mirror state of the door graphic; PC obj_door_gfx_flipped B833 */
#define D64_OBJ_DOOR_FLIP_WANTED    0x2900u  /* OR of the flip bits the visible doors need; PC obj_door_flip_wanted B86C */
#define D64_ISO_ROOM_CHANGED        0x2909u  /* not 0 when the room is to be redrawn; PC iso_room_changed B875 */
#define D64_OBJ_DOOR_PERMISSIONS    0x292Au  /* 3-byte entries and FF: the door bits a character may open, word pointer to its x, y (Guillermo first, Adso at +3); PC obj_door_permissions B897 */
#define D64_SPR_TABLE               0x2968u  /* the sprite records, 14h bytes each; PC spr_table B8D5 */
#define D64_SPR_DOORS               (D64_SPR_TABLE + 6 * 0x14)    /* 29E0: the door sprites; PC B94D */
#define D64_SPR_OBJECTS             (D64_SPR_TABLE + 13 * 0x14)   /* 2A6C: the object sprites; PC B9D9 */
#define D64_OBJ_DOORS               0x2B35u  /* 5-byte door records and FF: orientation, flags (bit 7 fixed, 6 open, 5 opening direction, 0-4 its bit), x, y, z (its height); PC obj_doors BAA2 */
#define D64_OBJ_OBJECTS             0x2B59u  /* 5-byte object records and FF: bit 7 of byte 0 carried, orientation, x, y, z; PC obj_objects BAC6 */
#define D64_OBJ_DOOR_CHECK_MASK     0x37F3u  /* the doors whose opening is checked (10h always); PC obj_door_check_mask C017 */
#define D64_OBJ_DOOR_GFX            0xAA49u  /* the graphic of the door leaf, 6 bytes x 28h lines; PC obj_door_gfx 1A6B */

/* ---- the sound: the AY sequencer run by the interrupt (snd_interrupt 0CD0) ---- */

#define D64_SND_MIXER               0x0C06u  /* the AY mixer (register 7) the interrupt builds: 3Fh, each channel XORs its enable bits */
#define D64_SND_MIXER_SENT          0x0C07u  /* the mixer value last written to the AY */
#define D64_SND_TEMPO               0x0C08u  /* the tempo counter 6..0: the sequences advance when it is 0 */
#define D64_SND_ENV_PERIOD_LO       0x0C09u  /* the AY envelope period (register 11) of a volume envelope entry 8xh */
#define D64_SND_ENV_PERIOD_HI       0x0C0Au  /* (register 12) */
#define D64_SND_ENV_SHAPE           0x0C0Bu  /* the AY envelope shape (register 13) */
#define D64_SND_NOISE_PERIOD        0x0C0Cu  /* the AY noise period (register 6) of the last note with noise */
#define D64_SND_CHANNEL_A           0x0C10u  /* the channel records, 18h apart (fields below) */
#define D64_SND_CHANNEL_B           0x0C28u
#define D64_SND_CHANNEL_C           0x0C40u
#define D64_SND_NOTE_PERIODS        0x0C55u  /* 12 words: the AY tone periods of the lowest octave (EEEh ... 7E9h) */
#define D64_SND_COMMANDS            0x0F76u  /* 6 entries of 3 bytes: a sequence command byte and its handler (FE start channel B, FD start channel C, FB tone envelope, FC nothing, FA volume envelope, F9 jump) */

/* the sequences the triggers start (operands of their LD HL) */
#define D64_SND_SEQ_MUSIC           0x106Eu  /* channel C */
#define D64_SND_SEQ_MIRROR_OPEN     0x10F0u  /* channel A (starts 10FD on channel B) */
#define D64_SND_SEQ_FOOTSTEP        0x1106u  /* channel C */
#define D64_SND_SEQ_OBJECT_TAKEN    0x110Fu  /* channel B */
#define D64_SND_SEQ_OBJECT_DROPPED  0x1118u  /* channel B */
#define D64_SND_SEQ_BEEP            0x1121u  /* channel C */
#define D64_SND_SEQ_TERCIA_BELLS    0x112Au  /* channel A (starts 1142 on channel B) */
#define D64_SND_SEQ_DOOR_OPEN       0x1157u  /* channel B */
#define D64_SND_SEQ_HOUR_BELLS      0x1163u  /* channel A (starts 11AE, 11B7 on channel B) */
#define D64_SND_SEQ_SEVERINO        0x11C0u  /* channel B */
#define D64_SND_SEQ_DOOR_CLOSE      0x11D0u  /* channel B */

/* a channel record: offsets from D64_SND_CHANNEL_x; the three bytes before it are fixed */
#define SND_REG_TONE                (-3)     /* its AY tone register (0, 2, 4; +1 the coarse one) */
#define SND_REG_VOLUME              (-2)     /* its AY volume register (8, 9, 10) */
#define SND_MIXER_BITS              (-1)     /* its tone and noise bits of the AY mixer (09h, 12h, 24h) */
#define SND_SEQ                     0x00     /* word: the next byte of its sequence */
#define SND_LEFT                    0x02     /* tempo ticks left of the note */
#define SND_PERIOD                  0x03     /* word: the AY tone period */
#define SND_TONE_ENV                0x05     /* word: the tone envelope (FB): entries steps, delta, rate; 7Fh holds, 80h restarts */
#define SND_VOLUME                  0x07     /* the volume, 0-15 */
#define SND_TONE_STEPS              0x08     /* steps left of the tone envelope entry */
#define SND_TONE_INDEX              0x09     /* offset of the next tone envelope entry */
#define SND_VOL_ENV                 0x0A     /* word: the volume envelope (FA): entries steps, delta, rate; 7Fh holds, 80h restarts; 8xh the AY envelope x, period lo, hi, rate */
#define SND_VOL_INDEX               0x0C     /* offset of the next volume envelope entry */
#define SND_VOL_STEPS               0x0D     /* steps left of the volume envelope entry */
#define SND_STATE                   0x0E     /* bit 0 playing, 1 noise, 2 starting (nothing sent before its first note), 3 noise period to send, 4 AY envelope, 5 volume to send, 6 period to send, 7 silent (a rest) */
#define SND_TONE_RATE               0x0F     /* ticks between tone envelope steps */
#define SND_VOL_RATE                0x10     /* ticks between volume envelope steps */
#define SND_TONE_COUNT              0x11
#define SND_VOL_COUNT               0x12
#define SND_TONE_DELTA              0x13     /* signed, added to the period */
#define SND_VOL_DELTA               0x14     /* added to the volume (4 bits) */

#endif
