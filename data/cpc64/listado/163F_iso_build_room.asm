; iso_build_room at 163F (64K)   PC: 2967   CPC 6128: 1A0A   called 102 times by 162B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
163F * ld a,(ix+000h)
1642 * cp 0ffh
1644 * ret z
1645 * and 0feh
1647 * ld hl,011ddh
164A * add a,l
164B * ld l,a
164C * adc a,h
164D * sub l
164E * ld h,a
164F * ld e,(hl)
1650 * inc hl
1651 * ld d,(hl)
1652 * ld (01697h),de
1656 * ld a,(ix+001h)
1659 * ld c,a
165A * and 01fh
165C * ld l,a
165D * ld a,c
165E * rlca
165F * rlca
1660 * rlca
1661 * and 007h
1663 * ld c,a
1664 * ld a,(ix+002h)
1667 * ld b,a
1668 * and 01fh
166A * ld h,a
166B * ld a,b
166C * rlca
166D * rlca
166E * rlca
166F * and 007h
1671 * ld b,a
1672 * ld de,00000h
1675 * ld (01bech),de
1679 * ld a,(ix+000h)
167C * inc ix
167E * inc ix
1680 * inc ix
1682 * and 001h
1684 * ld a,0ffh
1686 * jr z,$+7
1688 * ld a,(ix+000h)
168B * inc ix
168D * ld (01bebh),a
1690 * push hl
1691 * ld hl,0163fh
1694 * ex (sp),hl
1695 * push hl
1696 * ld hl,00000h
1699 * ld e,(hl)
169A * inc hl
169B * ld d,(hl)
169C * inc hl
169D * ex (sp),hl
169E * jp iso_enter_block
