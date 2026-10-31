; f_4C46 at 4C46 (64K)   PC: -   CPC 6128: -   called 26960 times by 4BFE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4C46 * ld a,(ix+000h)
4C49 * cp 0ffh
4C4B * ret z
4C4C * dec (ix+006h)
4C4F * ld a,(ix+006h)
4C52 * cp 0ffh
4C54 * jp nz,04d22h
4C57 * inc (ix+006h)
4C5A * call f_4EA5
4C5D * ld a,(ix+004h)
4C60 * xor (ix+000h)
4C63 * and (ix+004h)
4C66 * ld l,a
4C67 * ld a,(ix+005h)
4C6A * xor (ix+003h)
4C6D * and (ix+005h)
4C70 * ld h,a
4C71 * ld a,(ix+000h)
4C74 * and 001h
4C76 * ld (04caah),a
4C79 * push ix
4C7B * exx
4C7C * ld hl,08000h
4C7F * exx
4C80 * ld ix,02a6ch
4C84 * ld iy,02b59h
4C88 * add hl,hl
4C89 * push hl
4C8A * jp nc,04d07h
4C8D * ld a,(iy+000h)
4C90 * bit 0,a
4C92 * jp nz,04d07h
4C95 * bit 6,a
4C97 * jp nz,04d07h
4C9A * ld h,(iy+003h)
4C9D * ld l,(iy+002h)
4CA0 * ld a,(iy+004h)
4CA3 * bit 7,(iy+000h)
4CA7 * jr z,$+21
4CA9   ld a,000h
4CAB   and a
4CAC   jp nz,04d07h
4CAF   push hl
4CB0   inc hl
4CB1   ld e,(hl)
4CB2   inc hl
4CB3   ld d,(hl)
4CB4   ex de,hl
4CB5   ld e,(hl)
4CB6   inc hl
4CB7   ld d,(hl)
4CB8   inc hl
4CB9   ld a,(hl)
4CBA   ex de,hl
4CBB   pop de
4CBC * sub 000h
4CBE * cp 005h
4CC0 * jr nc,$+71
4CC2 * ld a,l
4CC3 * cp 000h
4CC5 * jr nz,$+66
4CC7 * ld a,h
4CC8 * cp 000h
4CCA * jr nz,$+61
4CCC * bit 7,(iy+000h)
4CD0 * jr z,$+15
4CD2   ld a,(de)
4CD3   exx
4CD4   xor l
4CD5   exx
4CD6   ld (de),a
4CD7   inc de
4CD8   inc de
4CD9   inc de
4CDA   ld a,(de)
4CDB   exx
4CDC   xor h
4CDD   exx
4CDE   ld (de),a
4CDF * call spr_mark_leaving
4CE2 * pop hl
4CE3 * pop de
4CE4 * push de
4CE5 * pop ix
4CE7 * ld (iy+002h),e
4CEA * ld (iy+003h),d
4CED * ld (iy+000h),081h
4CF1 * ld (ix+006h),010h
4CF5 * exx
4CF6 * ld a,(ix+000h)
4CF9 * or l
4CFA * ld (ix+000h),a
4CFD * ld a,(ix+003h)
4D00 * or h
4D01 * ld (ix+003h),a
4D04 * exx
4D05 * jr $+29
4D07 * ld bc,00005h
4D0A * add iy,bc
4D0C * ld bc,00014h
4D0F * add ix,bc
4D11 * exx
4D12 * srl h
4D14 * rr l
4D16 * exx
4D17 * pop hl
4D18 * ld a,(iy+000h)
4D1B * cp 0ffh
4D1D * jp nz,04c88h
4D20 * pop ix
4D22 * ld bc,00007h
4D25 * add ix,bc
4D27 * jp f_4C46
