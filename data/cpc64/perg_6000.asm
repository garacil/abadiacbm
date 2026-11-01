; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; z80dasm 1.1.6
; command line: z80dasm -a -l -g 0x6000 cpc64/perg_6000.bin

	org	06000h

	call z,sub_6114h		;6000
	di			;6003
	call sub_604ch		;6004
	ld bc,00228h		;6007
	ld l,006h		;600a
	add hl,de			;600c
	rst 38h			;600d
	ld a,0c3h		;600e
	ld (00038h),a		;6010
	ld hl,l613fh		;6013
	ld (00039h),hl		;6016
	ld hl,08000h		;6019
	ld a,(083ffh)		;601c
	ld (06201h),a		;601f
	call sub_61bah		;6022
	di			;6025
	ld ix,08400h		;6026
	call sub_6503h		;602a
l602dh:
	call sub_605fh		;602d
	ld a,02fh		;6030
	call sub_60dch		;6032
	jr z,l602dh		;6035
	di			;6037
	call sub_64f1h		;6038
	call sub_6114h		;603b
	ld hl,0c000h		;603e
	ld e,l			;6041
	ld d,h			;6042
	inc de			;6043
	ld (hl),000h		;6044
	ld bc,03fffh		;6046
	ldir		;6049
	ret			;604b
sub_604ch:
	pop hl			;604c
l604dh:
	ld b,0bch		;604d
	ld c,(hl)			;604f
	inc hl			;6050
	push hl			;6051
	inc c			;6052
	ret z			;6053
	dec c			;6054
	pop hl			;6055
	out (c),c		;6056
	inc b			;6058
	ld c,(hl)			;6059
	out (c),c		;605a
	inc hl			;605c
	jr l604dh		;605d
sub_605fh:
	di			;605f
	ld bc,0f40eh		;6060
	out (c),c		;6063
	ld b,0f6h		;6065
	in a,(c)		;6067
	and 030h		;6069
	ld c,a			;606b
	or 0c0h		;606c
	out (c),a		;606e
	out (c),c		;6070
	inc b			;6072
	ld a,092h		;6073
	out (c),a		;6075
	push bc			;6077
	ld hl,l60aeh		;6078
	ld de,l60b8h		;607b
l607eh:
	set 6,c		;607e
	ld b,0f6h		;6080
	out (c),c		;6082
	ld b,0f4h		;6084
	in a,(c)		;6086
	ld b,a			;6088
	call sub_60a8h		;6089
	ld a,b			;608c
	or (hl)			;608d
	cpl			;608e
	ld (hl),b			;608f
	ld b,a			;6090
	ld a,(de)			;6091
	and b			;6092
	or (hl)			;6093
	ld (de),a			;6094
	inc c			;6095
	inc de			;6096
	inc hl			;6097
	ld a,c			;6098
	and 00fh		;6099
	cp 00ah		;609b
	jr c,l607eh		;609d
	pop bc			;609f
	ld a,082h		;60a0
	out (c),a		;60a2
	dec b			;60a4
	out (c),c		;60a5
	ret			;60a7
sub_60a8h:
	ld a,c			;60a8
	and 00fh		;60a9
	ret			;60ab
	nop			;60ac
	nop			;60ad
l60aeh:
	rst 38h			;60ae
	rst 38h			;60af
	rst 38h			;60b0
	rst 38h			;60b1
	rst 38h			;60b2
	rst 38h			;60b3
	rst 38h			;60b4
	rst 38h			;60b5
	rst 38h			;60b6
	rst 38h			;60b7
l60b8h:
	rst 38h			;60b8
	rst 38h			;60b9
	rst 38h			;60ba
	rst 38h			;60bb
	rst 38h			;60bc
	rst 38h			;60bd
	rst 38h			;60be
	rst 38h			;60bf
	rst 38h			;60c0
	rst 38h			;60c1
	rst 38h			;60c2
	rst 38h			;60c3
	rst 38h			;60c4
	rst 38h			;60c5
	rst 38h			;60c6
	rst 38h			;60c7
	rst 38h			;60c8
	rst 38h			;60c9
	rst 38h			;60ca
	rst 38h			;60cb
	push hl			;60cc
	push de			;60cd
	ld de,l60b8h		;60ce
	call sub_60e7h		;60d1
	push af			;60d4
	ld a,(de)			;60d5
	or (hl)			;60d6
	ld (de),a			;60d7
	pop af			;60d8
	pop de			;60d9
	pop hl			;60da
	ret			;60db
sub_60dch:
	push hl			;60dc
	push de			;60dd
	ld de,l60aeh		;60de
	call sub_60e7h		;60e1
	pop de			;60e4
	pop hl			;60e5
	ret			;60e6
sub_60e7h:
	ld c,a			;60e7
	srl a		;60e8
	srl a		;60ea
	srl a		;60ec
	add a,e			;60ee
	ld e,a			;60ef
	adc a,d			;60f0
	sub e			;60f1
	ld d,a			;60f2
	ld a,c			;60f3
	and 007h		;60f4
	ld hl,l6102h		;60f6
	add a,l			;60f9
	ld l,a			;60fa
	adc a,h			;60fb
	sub l			;60fc
	ld h,a			;60fd
	ld a,(de)			;60fe
	cpl			;60ff
	and (hl)			;6100
	ret			;6101
l6102h:
	ld bc,00402h		;6102
	ex af,af'			;6105
	djnz $+34		;6106
	ld b,b			;6108
	add a,b			;6109
l610ah:
	inc d			;610a
	inc d			;610b
	inc d			;610c
	inc d			;610d
	inc d			;610e
l610fh:
	inc c			;610f
	inc d			;6110
	inc e			;6111
	rlca			;6112
	inc e			;6113
sub_6114h:
	ld hl,l610ah		;6114
	jr l611ch		;6117
sub_6119h:
	ld hl,l610fh		;6119
l611ch:
	di			;611c
	ld a,004h		;611d
	ld b,07fh		;611f
l6121h:
	ld c,a			;6121
	dec c			;6122
	out (c),c		;6123
	ld c,(hl)			;6125
	inc hl			;6126
	set 6,c		;6127
	out (c),c		;6129
	dec a			;612b
	jr nz,l6121h		;612c
	ld c,010h		;612e
	out (c),c		;6130
	ld c,(hl)			;6132
	set 6,c		;6133
	out (c),c		;6135
	ei			;6137
	ret			;6138
l6139h:
	dec bc			;6139
	ld a,b			;613a
	or c			;613b
	jr nz,l6139h		;613c
	ret			;613e
l613fh:
	di			;613f
	push af			;6140
	call sub_61dbh		;6141
	pop af			;6144
	ei			;6145
	reti		;6146
l6148h:
	inc a			;6148
l6149h:
	inc a			;6149
l614ah:
	add hl,bc			;614a
l614bh:
	nop			;614b
l614ch:
	nop			;614c
l614dh:
	nop			;614d
l614eh:
	nop			;614e
	nop			;614f
	ex af,af'			;6150
	add hl,bc			;6151
l6152h:
	ld e,c			;6152
	add a,b			;6153
	ld (bc),a			;6154
	ld l,d			;6155
	nop			;6156
	dec c			;6157
	add a,b			;6158
	ex af,af'			;6159
	rst 38h			;615a
	inc bc			;615b
	ld de,00980h		;615c
	inc b			;615f
l6160h:
	ld bc,014ffh		;6160
	ld d,l			;6163
	ld a,(bc)			;6164
	nop			;6165
	rst 38h			;6166
	ld (bc),a			;6167
	add hl,bc			;6168
	ld (de),a			;6169
l616ah:
	jp po,01281h		;616a
	ld h,l			;616d
	ld bc,0800dh		;616e
	dec b			;6171
	cp 003h		;6172
	dec de			;6174
	add a,b			;6175
	add hl,bc			;6176
	ld bc,0ff01h		;6177
	ld e,094h		;617a
	ld (de),a			;617c
	nop			;617d
	rst 38h			;617e
	inc b			;617f
	ld a,(bc)			;6180
	inc h			;6181
l6182h:
	ld (hl),080h		;6182
l6184h:
	nop			;6184
	nop			;6185
	nop			;6186
	nop			;6187
	nop			;6188
	nop			;6189
	nop			;618a
	nop			;618b
	nop			;618c
	nop			;618d
	nop			;618e
	nop			;618f
l6190h:
	nop			;6190
	nop			;6191
	nop			;6192
	nop			;6193
	nop			;6194
	nop			;6195
	nop			;6196
l6197h:
	xor 00eh		;6197
	jr l61a9h		;6199
	ld c,l			;619b
	dec c			;619c
	adc a,(hl)			;619d
	inc c			;619e
	jp c,02f0bh		;619f
	dec bc			;61a2
	adc a,a			;61a3
	ld a,(bc)			;61a4
	rst 30h			;61a5
	add hl,bc			;61a6
	ld l,b			;61a7
	add hl,bc			;61a8
l61a9h:
	pop hl			;61a9
	ex af,af'			;61aa
	ld h,c			;61ab
	ex af,af'			;61ac
	jp (hl)			;61ad
	rlca			;61ae
	ld ix,l6182h		;61af
	ld a,(ix+00eh)		;61b3
	and a			;61b6
	ret nz			;61b7
	jr l61cah		;61b8
sub_61bah:
	ld ix,l6152h		;61ba
	jr l61cah		;61be
	ld ix,l616ah		;61c0
	jr l61cah		;61c4
	ld ix,l6182h		;61c6
l61cah:
	di			;61ca
	ld (ix+00eh),005h		;61cb
	ld (ix+000h),l		;61cf
	ld (ix+001h),h		;61d2
	ld (ix+002h),001h		;61d5
	ei			;61d9
	ret			;61da
sub_61dbh:
	di			;61db
	push af			;61dc
	ld a,(l6160h)		;61dd
	push bc			;61e0
	ld c,a			;61e1
	ld a,(06178h)		;61e2
	or c			;61e5
	ld c,a			;61e6
	ld a,(l6190h)		;61e7
	or c			;61ea
	and 001h		;61eb
	jr nz,l61f4h		;61ed
l61efh:
	pop bc			;61ef
	pop af			;61f0
	ei			;61f1
	reti		;61f2
l61f4h:
	push hl			;61f4
	push de			;61f5
	push ix		;61f6
	ld a,(l614ah)		;61f8
	dec a			;61fb
	cp 0ffh		;61fc
	jr nz,l6202h		;61fe
	ld a,00bh		;6200
l6202h:
	ld (l614ah),a		;6202
	ld a,03fh		;6205
	ld (l6148h),a		;6207
	ld ix,l6152h		;620a
	call sub_62c7h		;620e
	ld ix,l616ah		;6211
	call sub_62c7h		;6215
	ld ix,l6182h		;6218
	call sub_62c7h		;621c
	ld ix,l6152h		;621f
	call sub_624bh		;6223
	ld ix,l616ah		;6226
	call sub_624bh		;622a
	ld ix,l6182h		;622d
	call sub_624bh		;6231
	ld hl,(l6148h)		;6234
	ld a,l			;6237
	cp h			;6238
	jr z,l6244h		;6239
	ld (l6149h),a		;623b
	ld c,a			;623e
	ld a,007h		;623f
	call sub_64c9h		;6241
l6244h:
	pop ix		;6244
	pop de			;6246
	pop hl			;6247
	jp l61efh		;6248
sub_624bh:
	ld l,(ix+00eh)		;624b
	bit 0,l		;624e
	ret z			;6250
	bit 2,l		;6251
	ret nz			;6253
	bit 7,l		;6254
	ret nz			;6256
	bit 6,l		;6257
	jr z,l626eh		;6259
	ld c,(ix+003h)		;625b
	ld a,(ix-003h)		;625e
	call sub_64c9h		;6261
	ld c,(ix+004h)		;6264
	ld a,(ix-003h)		;6267
	inc a			;626a
	call sub_64c9h		;626b
l626eh:
	bit 5,l		;626e
	jr z,l62a4h		;6270
	bit 4,l		;6272
	jr nz,l6281h		;6274
	ld a,(ix-002h)		;6276
	ld c,(ix+007h)		;6279
	call sub_64c9h		;627c
	jr l62a4h		;627f
l6281h:
	ld a,(l614bh)		;6281
	ld c,a			;6284
	ld a,00bh		;6285
	call sub_64c9h		;6287
	ld a,(l614ch)		;628a
	ld c,a			;628d
	ld a,00ch		;628e
	call sub_64c9h		;6290
	ld a,(l614dh)		;6293
	ld c,a			;6296
	ld a,00dh		;6297
	call sub_64c9h		;6299
	ld a,(ix-002h)		;629c
	ld c,010h		;629f
	call sub_64c9h		;62a1
l62a4h:
	ld a,007h		;62a4
	bit 1,l		;62a6
	jr z,l62bbh		;62a8
	ld a,03fh		;62aa
	bit 3,l		;62ac
	jr z,l62bbh		;62ae
	ld a,(l614eh)		;62b0
	ld c,a			;62b3
	ld a,006h		;62b4
	call sub_64c9h		;62b6
	ld a,03fh		;62b9
l62bbh:
	and (ix-001h)		;62bb
	ld c,a			;62be
	ld a,(l6148h)		;62bf
	xor c			;62c2
	ld (l6148h),a		;62c3
	ret			;62c6
sub_62c7h:
	ld a,(ix+00eh)		;62c7
	bit 0,a		;62ca
	ret z			;62cc
	and 087h		;62cd
	ld (ix+00eh),a		;62cf
	ld a,(l614ah)		;62d2
	and a			;62d5
	jp nz,l6372h		;62d6
	dec (ix+002h)		;62d9
	jp nz,l6372h		;62dc
	ld (ix+00eh),001h		;62df
	ld e,(ix+000h)		;62e3
	ld d,(ix+001h)		;62e6
l62e9h:
	ld b,006h		;62e9
	ld hl,l6481h		;62eb
l62eeh:
	ld a,(de)			;62ee
	cp (hl)			;62ef
	jr nz,l6303h		;62f0
	inc hl			;62f2
	ld a,(hl)			;62f3
	inc hl			;62f4
	ld h,(hl)			;62f5
	ld l,a			;62f6
	ld bc,l62e9h		;62f7
	push bc			;62fa
	ex de,hl			;62fb
	inc hl			;62fc
	ld c,(hl)			;62fd
	inc hl			;62fe
	ld b,(hl)			;62ff
	inc hl			;6300
	ex de,hl			;6301
	jp (hl)			;6302
l6303h:
	inc hl			;6303
	inc hl			;6304
	inc hl			;6305
	djnz l62eeh		;6306
	cp 0ffh		;6308
	jr nz,l6311h		;630a
	ld (ix+00eh),000h		;630c
	ret			;6310
l6311h:
	ex de,hl			;6311
	ld b,001h		;6312
	ld (ix+011h),b		;6314
	ld (ix+008h),b		;6317
	ld (ix+012h),b		;631a
	ld (ix+00dh),b		;631d
	dec b			;6320
	ld (ix+00ch),b		;6321
	ld (ix+009h),b		;6324
	ld c,(hl)			;6327
	inc hl			;6328
	ld a,(hl)			;6329
	inc hl			;632a
	ld (ix+002h),a		;632b
	bit 7,c		;632e
	jr z,l633fh		;6330
	ld a,(hl)			;6332
	ld (l614eh),a		;6333
	set 1,(ix+00eh)		;6336
	set 3,(ix+00eh)		;633a
	inc hl			;633e
l633fh:
	ld (ix+007h),000h		;633f
	ld (ix+000h),l		;6343
	ld (ix+001h),h		;6346
	set 7,(ix+00eh)		;6349
	ld a,c			;634d
	and 00fh		;634e
	cp 00fh		;6350
	ret z			;6352
	res 7,(ix+00eh)		;6353
	add a,a			;6357
	ld hl,l6197h		;6358
	call sub_64c3h		;635b
	ld e,(hl)			;635e
	inc hl			;635f
	ld d,(hl)			;6360
	ld a,c			;6361
	rrca			;6362
	rrca			;6363
	rrca			;6364
	rrca			;6365
	and 007h		;6366
	ex de,hl			;6368
	call sub_64e7h		;6369
	ld (ix+003h),l		;636c
	ld (ix+004h),h		;636f
l6372h:
	bit 7,(ix+00eh)		;6372
	ret nz			;6376
	bit 2,(ix+00eh)		;6377
	ret nz			;637b
	call sub_63f0h		;637c
	dec (ix+011h)		;637f
	ret nz			;6382
	dec (ix+008h)		;6383
	call z,sub_63ach		;6386
	ld a,(ix+00fh)		;6389
	ld (ix+011h),a		;638c
	ld a,(ix+013h)		;638f
	ld d,000h		;6392
	bit 7,a		;6394
	jr z,l6399h		;6396
	dec d			;6398
l6399h:
	ld l,(ix+003h)		;6399
	ld h,(ix+004h)		;639c
	ld e,a			;639f
	add hl,de			;63a0
	ld (ix+003h),l		;63a1
	ld (ix+004h),h		;63a4
	set 6,(ix+00eh)		;63a7
	ret			;63ab
sub_63ach:
	ld a,(ix+009h)		;63ac
	ld l,(ix+005h)		;63af
	ld h,(ix+006h)		;63b2
	call sub_64c3h		;63b5
	ld a,(hl)			;63b8
	cp 07fh		;63b9
	jr nz,l63cdh		;63bb
	ld a,0ffh		;63bd
	ld (ix+011h),a		;63bf
	ld (ix+00fh),a		;63c2
	ld (ix+008h),a		;63c5
	ld (ix+013h),000h		;63c8
	ret			;63cc
l63cdh:
	cp 080h		;63cd
	jr nz,l63d7h		;63cf
	xor a			;63d1
	ld (ix+009h),a		;63d2
	jr sub_63ach		;63d5
l63d7h:
	ld (ix+008h),a		;63d7
	inc hl			;63da
	ld a,(hl)			;63db
	ld (ix+013h),a		;63dc
	inc hl			;63df
	ld a,(hl)			;63e0
	ld (ix+00fh),a		;63e1
	ld (ix+011h),a		;63e4
	ld a,(ix+009h)		;63e7
	add a,003h		;63ea
	ld (ix+009h),a		;63ec
	ret			;63ef
sub_63f0h:
	dec (ix+012h)		;63f0
	ret nz			;63f3
	dec (ix+00dh)		;63f4
	call z,sub_6416h		;63f7
	set 5,(ix+00eh)		;63fa
	ld a,(ix+010h)		;63fe
	ld (ix+012h),a		;6401
	bit 4,(ix+00eh)		;6404
	ret nz			;6408
	ld a,(ix+007h)		;6409
	add a,(ix+014h)		;640c
	and 00fh		;640f
	ld (ix+007h),a		;6411
	ld c,a			;6414
	ret			;6415
sub_6416h:
	ld a,(ix+00ch)		;6416
	ld l,(ix+00ah)		;6419
	ld h,(ix+00bh)		;641c
	call sub_64c3h		;641f
	ld a,(hl)			;6422
	cp 07fh		;6423
	jr nz,l6437h		;6425
	ld a,0ffh		;6427
	ld (ix+012h),a		;6429
	ld (ix+010h),a		;642c
	ld (ix+00dh),a		;642f
	ld (ix+014h),000h		;6432
	ret			;6436
l6437h:
	cp 080h		;6437
	jr nz,l6441h		;6439
	xor a			;643b
	ld (ix+00ch),a		;643c
	jr sub_6416h		;643f
l6441h:
	bit 7,a		;6441
	jr z,l6468h		;6443
	and 00fh		;6445
	ld (l614dh),a		;6447
	inc hl			;644a
	ld a,(hl)			;644b
	ld (l614bh),a		;644c
	inc hl			;644f
	ld a,(hl)			;6450
	ld (l614ch),a		;6451
	inc hl			;6454
	ld a,(hl)			;6455
	ld (ix+012h),a		;6456
	ld (ix+00dh),001h		;6459
	set 4,(ix+00eh)		;645d
	ld a,(ix+00ch)		;6461
	add a,004h		;6464
	jr l647dh		;6466
l6468h:
	ld (ix+00dh),a		;6468
	inc hl			;646b
	ld a,(hl)			;646c
	ld (ix+014h),a		;646d
	inc hl			;6470
	ld a,(hl)			;6471
	ld (ix+010h),a		;6472
	ld (ix+012h),a		;6475
	ld a,(ix+00ch)		;6478
	add a,003h		;647b
l647dh:
	ld (ix+00ch),a		;647d
	ret			;6480
l6481h:
	cp 096h		;6481
	ld h,h			;6483
	defb 0fdh,0a5h	;and iyl		;6484
	ld h,h			;6486
	ei			;6487
	or h			;6488
	ld h,h			;6489
	call m,sub_64c2h		;648a
	jp m,l64bbh		;648d
	ld sp,hl			;6490
	sub e			;6491
	ld h,h			;6492
	ld d,b			;6493
	ld e,c			;6494
	ret			;6495
	ld (l616ah),bc		;6496
	ld a,005h		;649a
	ld (06178h),a		;649c
	ld a,001h		;649f
	ld (l616ah+2),a		;64a1
	ret			;64a4
	ld (l6182h),bc		;64a5
	ld a,005h		;64a9
	ld (l6190h),a		;64ab
	ld a,001h		;64ae
	ld (l6184h),a		;64b0
	ret			;64b3
	ld (ix+005h),c		;64b4
	ld (ix+006h),b		;64b7
	ret			;64ba
l64bbh:
	ld (ix+00ah),c		;64bb
	ld (ix+00bh),b		;64be
	ret			;64c1
sub_64c2h:
	ret			;64c2
sub_64c3h:
	add a,l			;64c3
	ld l,a			;64c4
	adc a,h			;64c5
	sub l			;64c6
	ld h,a			;64c7
	ret			;64c8
sub_64c9h:
	ld b,0f4h		;64c9
	out (c),a		;64cb
	ld b,0f6h		;64cd
	in a,(c)		;64cf
	or 0c0h		;64d1
	out (c),a		;64d3
	and 03fh		;64d5
	out (c),a		;64d7
	ld b,0f4h		;64d9
	out (c),c		;64db
	ld b,0f6h		;64dd
	ld c,a			;64df
	or 080h		;64e0
	out (c),a		;64e2
	out (c),c		;64e4
	ret			;64e6
sub_64e7h:
	and a			;64e7
	ret z			;64e8
l64e9h:
	srl h		;64e9
	rr l		;64eb
	dec a			;64ed
	jr nz,l64e9h		;64ee
	ret			;64f0
sub_64f1h:
	ld a,084h		;64f1
	ld (l6160h),a		;64f3
	ld (06178h),a		;64f6
	ld (l6190h),a		;64f9
	ld c,03fh		;64fc
	ld a,007h		;64fe
	jp sub_64c9h		;6500
sub_6503h:
	push ix		;6503
	call sub_6114h		;6505
	call sub_6515h		;6508
	call sub_6119h		;650b
	pop ix		;650e
	ei			;6510
	call sub_668bh		;6511
	ret			;6514
sub_6515h:
	ld hl,0c000h		;6515
	push hl			;6518
	ld d,h			;6519
	ld e,l			;651a
	inc de			;651b
	ld (hl),000h		;651c
	ld bc,03fffh		;651e
	ldir		;6521
	pop hl			;6523
	ld c,0c8h		;6524
l6526h:
	ld b,010h		;6526
	ld a,0f0h		;6528
	push hl			;652a
	ld de,00040h		;652b
	ex de,hl			;652e
	add hl,de			;652f
l6530h:
	push bc			;6530
	ld (hl),a			;6531
	ldi		;6532
	pop bc			;6534
	djnz l6530h		;6535
	pop hl			;6537
	call sub_6858h		;6538
	dec c			;653b
	jr nz,l6526h		;653c
	ld hl,0c780h		;653e
	ld b,008h		;6541
l6543h:
	push bc			;6543
	push hl			;6544
	ld e,l			;6545
	ld d,h			;6546
	inc de			;6547
	ld bc,0004fh		;6548
	ldir		;654b
	pop hl			;654d
	call sub_6858h		;654e
	pop bc			;6551
	djnz l6543h		;6552
	ld hl,00020h		;6554
	call sub_682dh		;6557
	ld de,0788ah		;655a
	call sub_6581h		;655d
	ld hl,000dah		;6560
	call sub_682dh		;6563
	ld de,07a0ah		;6566
	call sub_6594h		;6569
	ld hl,00020h		;656c
	call sub_682dh		;656f
	ld de,07b8ah		;6572
	call sub_6594h		;6575
	ld hl,0b820h		;6578
	call sub_682dh		;657b
	ld de,07d0ah		;657e
sub_6581h:
	ld c,030h		;6581
l6583h:
	ld b,008h		;6583
	push hl			;6585
l6586h:
	ld a,(de)			;6586
	ld (hl),a			;6587
	call sub_6858h		;6588
	inc de			;658b
	djnz l6586h		;658c
	pop hl			;658e
	inc hl			;658f
	dec c			;6590
	jr nz,l6583h		;6591
	ret			;6593
sub_6594h:
	ld b,0c0h		;6594
l6596h:
	ld a,(de)			;6596
	ld (hl),a			;6597
	inc hl			;6598
	inc de			;6599
	ld a,(de)			;659a
	ld (hl),a			;659b
	dec hl			;659c
	inc de			;659d
	call sub_6858h		;659e
	djnz l6596h		;65a1
	ret			;65a3
sub_65a4h:
	push hl			;65a4
	push bc			;65a5
	ld d,000h		;65a6
	ld a,l			;65a8
	add a,004h		;65a9
	ld l,a			;65ab
	ld a,030h		;65ac
	sub c			;65ae
	add a,a			;65af
	add a,a			;65b0
	ld e,a			;65b1
	ex de,hl			;65b2
	add hl,hl			;65b3
	ld bc,0788ah		;65b4
	add hl,bc			;65b7
	ex de,hl			;65b8
	call sub_682dh		;65b9
	push hl			;65bc
	ld b,008h		;65bd
l65bfh:
	ld a,(de)			;65bf
	ld (hl),a			;65c0
	call sub_6858h		;65c1
	inc de			;65c4
	djnz l65bfh		;65c5
	pop hl			;65c7
	inc hl			;65c8
	ld b,008h		;65c9
l65cbh:
	ld a,(de)			;65cb
	ld (hl),a			;65cc
	call sub_6858h		;65cd
	inc de			;65d0
	djnz l65cbh		;65d1
	pop bc			;65d3
	push bc			;65d4
	ld a,c			;65d5
	dec a			;65d6
	dec a			;65d7
	dec a			;65d8
	add a,a			;65d9
	add a,a			;65da
	ld h,a			;65db
	ld l,0dah		;65dc
	ld e,a			;65de
	ld d,000h		;65df
	ex de,hl			;65e1
	add hl,hl			;65e2
	ld bc,07a0ah		;65e3
	add hl,bc			;65e6
	ex de,hl			;65e7
	call sub_682dh		;65e8
	ld b,008h		;65eb
l65edh:
	ld a,(de)			;65ed
	ld (hl),a			;65ee
	inc hl			;65ef
	inc de			;65f0
	ld a,(de)			;65f1
	ld (hl),a			;65f2
	dec hl			;65f3
	inc de			;65f4
	call sub_6858h		;65f5
	djnz l65edh		;65f8
	pop bc			;65fa
	pop hl			;65fb
	ret			;65fc
sub_65fdh:
	ld b,02dh		;65fd
	ld c,003h		;65ff
	ld hl,000d3h		;6601
l6604h:
	push bc			;6604
	push hl			;6605
	ld b,c			;6606
	call sub_686ch		;6607
	ld bc,007d0h		;660a
	call sub_672ch		;660d
	pop hl			;6610
	pop bc			;6611
	call sub_65a4h		;6612
	dec l			;6615
	dec l			;6616
	dec l			;6617
	dec l			;6618
	inc c			;6619
	djnz l6604h		;661a
	call sub_65a4h		;661c
	ld b,02eh		;661f
	ld c,02fh		;6621
	ld hl,00420h		;6623
l6626h:
	push bc			;6626
	ld b,c			;6627
	push hl			;6628
	call sub_686ch		;6629
	ld bc,007d0h		;662c
	call sub_672ch		;662f
	pop hl			;6632
	push hl			;6633
	ld a,h			;6634
	sub 004h		;6635
	ld h,a			;6637
	push af			;6638
	call sub_682dh		;6639
	pop af			;663c
	ld e,a			;663d
	ld d,000h		;663e
	ex de,hl			;6640
	add hl,hl			;6641
	ld bc,07b8ah		;6642
	add hl,bc			;6645
	ex de,hl			;6646
	ld b,004h		;6647
l6649h:
	ld a,(de)			;6649
	ld (hl),a			;664a
	inc de			;664b
	inc hl			;664c
	ld a,(de)			;664d
	ld (hl),a			;664e
	inc de			;664f
	dec hl			;6650
	call sub_6858h		;6651
	djnz l6649h		;6654
	pop hl			;6656
	pop bc			;6657
	push bc			;6658
	push hl			;6659
	call sub_666bh		;665a
	pop hl			;665d
	ld a,h			;665e
	add a,004h		;665f
	ld h,a			;6661
	pop bc			;6662
	dec c			;6663
	djnz l6626h		;6664
	call sub_666bh		;6666
	ld c,000h		;6669
sub_666bh:
	ld a,c			;666b
	add a,a			;666c
	add a,a			;666d
	ld e,a			;666e
	ld d,000h		;666f
	add a,020h		;6671
	ld l,a			;6673
	ld h,0b8h		;6674
	call sub_682dh		;6676
	ex de,hl			;6679
	add hl,hl			;667a
	ld bc,07d0ah		;667b
	add hl,bc			;667e
	ex de,hl			;667f
	ld b,008h		;6680
l6682h:
	ld a,(de)			;6682
	ld (hl),a			;6683
	inc de			;6684
	call sub_6858h		;6685
	djnz l6682h		;6688
	ret			;668a
sub_668bh:
	ld l,02ch		;668b
	ld h,010h		;668d
	ld (l6770h),hl		;668f
l6692h:
	push ix		;6692
	call sub_605fh		;6694
	ei			;6697
	ld a,02fh		;6698
	call sub_60dch		;669a
	pop ix		;669d
	ret nz			;669f
	ld a,(ix+000h)		;66a0
	cp 01ah		;66a3
	jr z,l6692h		;66a5
	inc ix		;66a7
	cp 00dh		;66a9
	jr nz,l66b5h		;66ab
	ld hl,(l6770h)		;66ad
	call sub_6744h		;66b0
	jr l6692h		;66b3
l66b5h:
	cp 020h		;66b5
	jr nz,l66c0h		;66b7
	ld a,00ah		;66b9
	call sub_6733h		;66bb
	jr l6692h		;66be
l66c0h:
	cp 00ah		;66c0
	jr nz,l66c9h		;66c2
	call sub_6756h		;66c4
	jr l6692h		;66c7
l66c9h:
	ld c,a			;66c9
	and 060h		;66ca
	cp 040h		;66cc
	ld a,0ffh		;66ce
	jr z,l66d4h		;66d0
	ld a,00fh		;66d2
l66d4h:
	ld (06726h),a		;66d4
	ld a,c			;66d7
	ld hl,06772h		;66d8
	sub 020h		;66db
	add a,a			;66dd
	call sub_64c3h		;66de
	ld e,(hl)			;66e1
	inc hl			;66e2
	ld d,(hl)			;66e3
	push de			;66e4
	pop iy		;66e5
l66e7h:
	ld bc,00320h		;66e7
	call sub_672ch		;66ea
	ld a,(iy+000h)		;66ed
	inc iy		;66f0
	ld c,a			;66f2
	and 0f0h		;66f3
	cp 0f0h		;66f5
	jr nz,l6701h		;66f7
	ld a,c			;66f9
	and 00fh		;66fa
	call sub_6733h		;66fc
	jr l6692h		;66ff
l6701h:
	ld a,c			;6701
	and 00fh		;6702
	ld hl,(l6770h)		;6704
	add a,l			;6707
	ld l,a			;6708
	push af			;6709
	ld a,c			;670a
	rlca			;670b
	rlca			;670c
	rlca			;670d
	rlca			;670e
	and 00fh		;670f
	add a,h			;6711
	ld h,a			;6712
	call sub_682dh		;6713
	pop af			;6716
	and 003h		;6717
	ld b,a			;6719
	ld a,088h		;671a
	jr z,l6721h		;671c
l671eh:
	rrca			;671e
	djnz l671eh		;671f
l6721h:
	ld c,a			;6721
	cpl			;6722
	and (hl)			;6723
	ld b,a			;6724
	ld a,00fh		;6725
	and c			;6727
	or b			;6728
	ld (hl),a			;6729
	jr l66e7h		;672a
sub_672ch:
	nop			;672c
	dec bc			;672d
	ld a,b			;672e
	or c			;672f
	jr nz,sub_672ch		;6730
	ret			;6732
sub_6733h:
	push af			;6733
	ld bc,00bb8h		;6734
	call sub_672ch		;6737
	pop af			;673a
	ld hl,(l6770h)		;673b
	add a,l			;673e
	ld l,a			;673f
	ld (l6770h),hl		;6740
	ret			;6743
sub_6744h:
	ld bc,0ea60h		;6744
	call sub_672ch		;6747
	ld a,010h		;674a
	ld l,02ch		;674c
	add a,h			;674e
	ld h,a			;674f
	ld (l6770h),hl		;6750
	cp 0a4h		;6753
	ret c			;6755
sub_6756h:
	ld hl,0102ch		;6756
	ld (l6770h),hl		;6759
	ld b,003h		;675c
l675eh:
	push bc			;675e
	ld bc,00000h		;675f
	call sub_672ch		;6762
	pop bc			;6765
	djnz l675eh		;6766
	push ix		;6768
	call sub_65fdh		;676a
	pop ix		;676d
	ret			;676f
l6770h:
	sbc a,b			;6770
	djnz l6773h		;6771
l6773h:
	nop			;6773
	nop			;6774
	nop			;6775
	nop			;6776
	nop			;6777
	nop			;6778
	nop			;6779
	nop			;677a
	nop			;677b
	nop			;677c
	nop			;677d
	nop			;677e
	nop			;677f
	nop			;6780
	nop			;6781
	nop			;6782
	nop			;6783
	nop			;6784
	nop			;6785
	nop			;6786
	nop			;6787
	nop			;6788
	nop			;6789
	xor l			;678a
	ld l,b			;678b
	or h			;678c
	ld l,b			;678d
	push bc			;678e
	ld l,b			;678f
	nop			;6790
	nop			;6791
	nop			;6792
	nop			;6793
	jp z,0e068h		;6794
	ld l,b			;6797
	inc b			;6798
	ld l,c			;6799
	nop			;679a
	nop			;679b
	nop			;679c
	nop			;679d
	nop			;679e
	nop			;679f
	inc h			;67a0
	ld l,c			;67a1
	nop			;67a2
	nop			;67a3
	nop			;67a4
	nop			;67a5
	ccf			;67a6
	ld l,c			;67a7
	ld c,b			;67a8
	ld l,c			;67a9
	nop			;67aa
	nop			;67ab
	nop			;67ac
	nop			;67ad
	nop			;67ae
	nop			;67af
	nop			;67b0
	nop			;67b1
	nop			;67b2
	nop			;67b3
	adc a,(hl)			;67b4
	ld l,c			;67b5
	nop			;67b6
	nop			;67b7
	sbc a,069h		;67b8
	inc a			;67ba
	ld l,d			;67bb
	and e			;67bc
	ld l,d			;67bd
	nop			;67be
	nop			;67bf
	xor 06ah		;67c0
	ld e,l			;67c2
	ld l,e			;67c3
	nop			;67c4
	nop			;67c5
	or e			;67c6
	ld l,e			;67c7
	nop			;67c8
	nop			;67c9
	pop af			;67ca
	ld l,e			;67cb
	inc sp			;67cc
	ld l,h			;67cd
	nop			;67ce
	nop			;67cf
	and e			;67d0
	ld l,h			;67d1
	ld c,06dh		;67d2
sub_67d4h:
	nop			;67d4
	nop			;67d5
	nop			;67d6
	nop			;67d7
	ld (hl),d			;67d8
	ld l,l			;67d9
	jp nc,0006dh		;67da
	nop			;67dd
	nop			;67de
	nop			;67df
	nop			;67e0
	nop			;67e1
	nop			;67e2
	nop			;67e3
	dec d			;67e4
	ld l,(hl)			;67e5
	nop			;67e6
	nop			;67e7
	nop			;67e8
	nop			;67e9
	nop			;67ea
	nop			;67eb
	nop			;67ec
	nop			;67ed
	nop			;67ee
	nop			;67ef
	nop			;67f0
	nop			;67f1
	nop			;67f2
	nop			;67f3
	ld (hl),l			;67f4
	ld l,(hl)			;67f5
	sbc a,l			;67f6
	ld l,(hl)			;67f7
	call z,0ea6eh		;67f8
	ld l,(hl)			;67fb
	add hl,de			;67fc
	ld l,a			;67fd
	add hl,sp			;67fe
	ld l,a			;67ff
	ld e,l			;6800
	ld l,a			;6801
	adc a,h			;6802
	ld l,a			;6803
	cp e			;6804
	ld l,a			;6805
	jp nc,0f06fh		;6806
	ld l,a			;6809
	inc d			;680a
	ld (hl),b			;680b
	cpl			;680c
	ld (hl),b			;680d
	ld l,c			;680e
	ld (hl),b			;680f
	adc a,a			;6810
	ld (hl),b			;6811
	or h			;6812
	ld (hl),b			;6813
	rst 18h			;6814
	ld (hl),b			;6815
	dec c			;6816
	ld (hl),c			;6817
	add hl,hl			;6818
	ld (hl),c			;6819
	ld b,l			;681a
	ld (hl),c			;681b
	ld l,c			;681c
	ld (hl),c			;681d
	adc a,a			;681e
	ld (hl),c			;681f
	or e			;6820
	ld (hl),c			;6821
	pop hl			;6822
	ld (hl),c			;6823
	cp 071h		;6824
	jr z,l689ah		;6826
	nop			;6828
	nop			;6829
	nop			;682a
	nop			;682b
	nop			;682c
sub_682dh:
	push de			;682d
	srl l		;682e
	srl l		;6830
	ld a,l			;6832
	ex af,af'			;6833
	push af			;6834
	ld a,h			;6835
	and 0f8h		;6836
	ld l,a			;6838
	ld a,h			;6839
	ld h,000h		;683a
	add hl,hl			;683c
	ld d,h			;683d
	ld e,l			;683e
	add hl,hl			;683f
	add hl,hl			;6840
	add hl,de			;6841
	and 007h		;6842
	add a,a			;6844
	add a,a			;6845
	add a,a			;6846
	or h			;6847
	or 0c0h		;6848
	ld h,a			;684a
	pop af			;684b
	ex af,af'			;684c
	add a,l			;684d
	ld l,a			;684e
	adc a,h			;684f
	sub l			;6850
	ld h,a			;6851
	ld de,00008h		;6852
	add hl,de			;6855
	pop de			;6856
	ret			;6857
sub_6858h:
	ld a,h			;6858
	add a,008h		;6859
	jr c,l685fh		;685b
	ld h,a			;685d
	ret			;685e
l685fh:
	ld a,h			;685f
	and 0c7h		;6860
	ld h,a			;6862
	ld a,050h		;6863
	add a,l			;6865
	ld l,a			;6866
	ret nc			;6867
	adc a,h			;6868
	sub l			;6869
	ld h,a			;686a
	ret			;686b
sub_686ch:
	call sub_682dh		;686c
	ld d,000h		;686f
l6871h:
	ld c,004h		;6871
l6873h:
	push bc			;6873
	push hl			;6874
	ld a,c			;6875
	dec a			;6876
	push hl			;6877
	ld hl,l68a9h		;6878
	call sub_64c3h		;687b
	ld a,(hl)			;687e
	pop hl			;687f
	ld e,000h		;6880
	ld (l6897h+1),a		;6882
l6885h:
	ld a,d			;6885
	cp e			;6886
	jr z,l6897h		;6887
	ld (hl),0f0h		;6889
	dec b			;688b
	jr nz,l6893h		;688c
	inc e			;688e
	inc hl			;688f
	inc b			;6890
	jr l6885h		;6891
l6893h:
	inc b			;6893
	call sub_64c3h		;6894
l6897h:
	ld (hl),000h		;6897
	inc hl			;6899
l689ah:
	ld (hl),000h		;689a
	pop hl			;689c
	call sub_6858h		;689d
	pop bc			;68a0
	dec c			;68a1
	jr nz,l6873h		;68a2
	inc e			;68a4
	inc d			;68a5
	djnz l6871h		;68a6
	ret			;68a8
l68a9h:
	ret p			;68a9
	ret po			;68aa
	ret nz			;68ab
	add a,b			;68ac
	and d			;68ad
	and e			;68ae
	or d			;68af
	or e			;68b0
	jp 0f4d2h		;68b1
	ld (hl),b			;68b4
	add a,b			;68b5
	sub c			;68b6
	add a,c			;68b7
	add a,d			;68b8
	sub d			;68b9
	sub e			;68ba
	add a,e			;68bb
	ld (hl),e			;68bc
	ld (hl),h			;68bd
	add a,h			;68be
	ld (hl),l			;68bf
	add a,l			;68c0
	add a,(hl)			;68c1
	add a,(hl)			;68c2
	sub a			;68c3
	ret m			;68c4
	and d			;68c5
	and e			;68c6
	or d			;68c7
	or e			;68c8
	call p,05160h		;68c9
	ld b,d			;68cc
	inc sp			;68cd
	ld b,e			;68ce
	ld d,e			;68cf
	ld d,d			;68d0
	ld h,e			;68d1
	ld h,d			;68d2
	ld (hl),e			;68d3
	ld (hl),d			;68d4
	add a,e			;68d5
	add a,d			;68d6
	sub e			;68d7
	sub d			;68d8
	and e			;68d9
	and d			;68da
	or e			;68db
	or d			;68dc
	jp 0f5b4h		;68dd
	ld h,b			;68e0
	ld d,b			;68e1
	ld b,c			;68e2
	ld (03433h),a		;68e3
	dec (hl)			;68e6
	ld b,h			;68e7
	ld b,l			;68e8
	ld b,(hl)			;68e9
	ld d,(hl)			;68ea
	ld d,l			;68eb
	ld h,l			;68ec
	ld h,h			;68ed
	ld (hl),h			;68ee
	ld (hl),e			;68ef
	add a,e			;68f0
	add a,d			;68f1
	sub d			;68f2
	sub c			;68f3
	and c			;68f4
	and b			;68f5
	or b			;68f6
	ret nz			;68f7
	or c			;68f8
	or d			;68f9
	or e			;68fa
	jp 0c4b4h		;68fb
	or l			;68fe
	and (hl)			;68ff
	or l			;6900
	and (hl)			;6901
	sub a			;6902
	ret m			;6903
	ld d,b			;6904
	ld b,c			;6905
	ld (03433h),a		;6906
	ld b,e			;6909
	ld b,h			;690a
	ld b,l			;690b
	ld b,(hl)			;690c
	scf			;690d
	ld b,(hl)			;690e
	ld d,l			;690f
	ld h,h			;6910
	ld (hl),e			;6911
	ld (hl),d			;6912
	ld (hl),e			;6913
	ld (hl),h			;6914
	add a,l			;6915
	sub (hl)			;6916
	sub l			;6917
	and (hl)			;6918
	and l			;6919
	or l			;691a
	call nz,0b3c3h		;691b
	jp nz,0b1b2h		;691e
	and b			;6921
	sub b			;6922
	ret m			;6923
	ld d,b			;6924
	ld b,c			;6925
	ld (03433h),a		;6926
	ld b,e			;6929
	ld b,h			;692a
	ld b,l			;692b
	ld b,(hl)			;692c
	scf			;692d
	ld b,(hl)			;692e
	ld d,l			;692f
	ld h,h			;6930
	ld (hl),e			;6931
	add a,d			;6932
	add a,e			;6933
	sub d			;6934
	sub e			;6935
	and d			;6936
	and e			;6937
	or d			;6938
	or e			;6939
	jp 081b4h		;693a
	add a,h			;693d
	ret m			;693e
	ld (hl),d			;693f
	ld (hl),e			;6940
	add a,d			;6941
	add a,e			;6942
	and d			;6943
	and e			;6944
	or d			;6945
	or e			;6946
	call p,07372h		;6947
	add a,d			;694a
	add a,e			;694b
	and d			;694c
	and e			;694d
	or d			;694e
	or e			;694f
	jp 0f4d2h		;6950
	ld d,b			;6953
	ld b,c			;6954
	ld d,d			;6955
	ld d,c			;6956
	ld h,d			;6957
	ld h,c			;6958
	ld (hl),d			;6959
	ld (hl),c			;695a
	add a,d			;695b
	add a,c			;695c
	sub d			;695d
	sub c			;695e
	and d			;695f
	and c			;6960
	or d			;6961
	or c			;6962
	pop bc			;6963
	ret nz			;6964
	ret nc			;6965
	ld h,e			;6966
	ld d,h			;6967
	ld b,l			;6968
	ld d,(hl)			;6969
	ld d,l			;696a
	ld h,(hl)			;696b
	ld h,l			;696c
	halt			;696d
	ld (hl),l			;696e
	add a,(hl)			;696f
	add a,l			;6970
	sub (hl)			;6971
	sub l			;6972
	and (hl)			;6973
	and l			;6974
	or (hl)			;6975
	or l			;6976
	push bc			;6977
	call nz,sub_67d4h		;6978
	ld e,b			;697b
	ld c,c			;697c
	ld e,d			;697d
	ld e,c			;697e
	ld l,d			;697f
	ld l,c			;6980
	ld a,d			;6981
	ld a,c			;6982
	adc a,d			;6983
	adc a,c			;6984
	sbc a,d			;6985
	sbc a,c			;6986
	xor d			;6987
	xor c			;6988
	cp d			;6989
	cp c			;698a
	ret			;698b
	ret z			;698c
	ret p			;698d
	ld (00413h),hl		;698e
	dec b			;6991
	ld b,015h		;6992
	inc d			;6994
	dec h			;6995
	ld d,017h		;6996
	daa			;6998
	ld h,035h		;6999
	ld (hl),037h		;699b
	jr c,l69e6h		;699d
	ld c,b			;699f
	ld d,a			;69a0
	ld e,b			;69a1
	ld e,c			;69a2
	ld l,b			;69a3
	ld a,c			;69a4
	ld l,c			;69a5
	ld a,b			;69a6
	ld a,d			;69a7
	adc a,d			;69a8
	adc a,c			;69a9
	sbc a,c			;69aa
	sbc a,d			;69ab
	sbc a,e			;69ac
	xor d			;69ad
	xor e			;69ae
	cp d			;69af
	cp e			;69b0
	cp h			;69b1
	set 3,e		;69b2
	call z,0dcddh		;69b4
	ld h,b			;69b7
	ld d,c			;69b8
	ld b,d			;69b9
	ld b,e			;69ba
	ld b,h			;69bb
	ld d,h			;69bc
	ld d,e			;69bd
	ld d,d			;69be
	ld h,e			;69bf
	ld h,h			;69c0
	ld (hl),e			;69c1
	add a,d			;69c2
	sub d			;69c3
	and c			;69c4
	or c			;69c5
	ret nz			;69c6
	ret nc			;69c7
	pop bc			;69c8
	pop de			;69c9
	jp nc,0d3c2h		;69ca
	call nz,09383h		;69cd
	add a,h			;69d0
	sub h			;69d1
	add a,l			;69d2
	sub l			;69d3
	add a,(hl)			;69d4
	sub (hl)			;69d5
	add a,a			;69d6
	sub a			;69d7
	adc a,b			;69d8
	sbc a,b			;69d9
	ld h,l			;69da
	ld h,(hl)			;69db
	ld h,a			;69dc
	cp 003h		;69dd
	ld (de),a			;69df
	ld hl,03222h		;69e0
	ld sp,04140h		;69e3
l69e6h:
	ld b,d			;69e6
	ld d,d			;69e7
	ld d,c			;69e8
	ld d,b			;69e9
	ld h,b			;69ea
	ld h,c			;69eb
	ld h,d			;69ec
	ld (hl),d			;69ed
	ld (hl),c			;69ee
	ld (hl),b			;69ef
	add a,b			;69f0
	add a,c			;69f1
	add a,d			;69f2
	add a,e			;69f3
	sub e			;69f4
	sub d			;69f5
	sub c			;69f6
	sub b			;69f7
	and c			;69f8
	and d			;69f9
	or c			;69fa
	jp nz,0a3b2h		;69fb
	or e			;69fe
	jp 0c4d4h		;69ff
	or h			;6a02
	and h			;6a03
	and l			;6a04
	or l			;6a05
	push bc			;6a06
	push de			;6a07
	sub 0c6h		;6a08
	or (hl)			;6a0a
	or a			;6a0b
	rst 0			;6a0c
	rst 10h			;6a0d
	ret c			;6a0e
	ret z			;6a0f
	cp b			;6a10
	cp c			;6a11
	ret			;6a12
	exx			;6a13
	jp z,0bbbah		;6a14
	res 7,h		;6a17
	xor l			;6a19
	inc h			;6a1a
	dec h			;6a1b
	ld h,016h		;6a1c
	rla			;6a1e
	rlca			;6a1f
	ex af,af'			;6a20
	jr $+27		;6a21
	add hl,bc			;6a23
	ld a,(de)			;6a24
	dec de			;6a25
	inc c			;6a26
	dec (hl)			;6a27
	ld (hl),045h		;6a28
	ld b,(hl)			;6a2a
	ld d,l			;6a2b
	ld d,(hl)			;6a2c
	ld h,(hl)			;6a2d
	ld h,l			;6a2e
	ld (hl),l			;6a2f
	halt			;6a30
	add a,l			;6a31
	jr z,l6a6ch		;6a32
	ld c,b			;6a34
	ld e,b			;6a35
	ld l,b			;6a36
	ld a,b			;6a37
	adc a,b			;6a38
	sbc a,b			;6a39
	xor b			;6a3a
	cp 000h		;6a3b
	djnz l6a50h		;6a3d
	ld hl,02212h		;6a3f
	inc de			;6a42
	inc hl			;6a43
	inc sp			;6a44
	inc (hl)			;6a45
	inc h			;6a46
	inc d			;6a47
	dec d			;6a48
	dec h			;6a49
	dec (hl)			;6a4a
	ld (hl),026h		;6a4b
	ld d,017h		;6a4d
	daa			;6a4f
l6a50h:
	scf			;6a50
	jr c,l6a7bh		;6a51
	jr l6a6eh		;6a53
	add hl,hl			;6a55
	add hl,sp			;6a56
	ld c,c			;6a57
	ld c,d			;6a58
	ld a,(02b2ah)		;6a59
	dec sp			;6a5c
	inc a			;6a5d
	ld c,h			;6a5e
	ld c,e			;6a5f
	ld e,d			;6a60
	ld e,e			;6a61
	ld e,h			;6a62
	ld l,h			;6a63
	ld l,e			;6a64
	ld l,d			;6a65
	ld a,d			;6a66
	ld a,e			;6a67
	ld a,h			;6a68
	adc a,h			;6a69
	adc a,e			;6a6a
	adc a,d			;6a6b
l6a6ch:
	sbc a,d			;6a6c
	sbc a,e			;6a6d
l6a6eh:
	sbc a,h			;6a6e
	xor h			;6a6f
	xor e			;6a70
	xor d			;6a71
	cp e			;6a72
	cp d			;6a73
	ret			;6a74
	ret c			;6a75
	ret z			;6a76
	rst 0			;6a77
	rst 10h			;6a78
	sub 0c6h		;6a79
l6a7bh:
	or (hl)			;6a7b
	or l			;6a7c
	push bc			;6a7d
	call nz,0b3b4h		;6a7e
	jp 0b2c2h		;6a81
	pop bc			;6a84
	ret nc			;6a85
	ld b,d			;6a86
	ld d,d			;6a87
	ld d,e			;6a88
	ld h,e			;6a89
	ld h,d			;6a8a
	ld (hl),d			;6a8b
	ld (hl),e			;6a8c
	add a,e			;6a8d
	add a,d			;6a8e
	sub e			;6a8f
	sub d			;6a90
	and e			;6a91
	and l			;6a92
	sub l			;6a93
	add a,l			;6a94
	ld (hl),l			;6a95
	ld h,l			;6a96
	ld d,l			;6a97
	ld b,l			;6a98
	ld h,(hl)			;6a99
	ld h,a			;6a9a
	ld l,b			;6a9b
	ld l,c			;6a9c
	adc a,c			;6a9d
	adc a,b			;6a9e
	add a,a			;6a9f
	add a,(hl)			;6aa0
	ld (hl),c			;6aa1
	cp 020h		;6aa2
	ld de,00302h		;6aa4
	inc b			;6aa7
	inc de			;6aa8
	inc d			;6aa9
	dec d			;6aaa
	inc h			;6aab
	inc (hl)			;6aac
	inc sp			;6aad
	ld b,e			;6aae
	ld b,d			;6aaf
	ld d,d			;6ab0
	ld d,e			;6ab1
	ld h,e			;6ab2
	ld h,d			;6ab3
	ld (hl),e			;6ab4
	ld (hl),d			;6ab5
	add a,e			;6ab6
	add a,d			;6ab7
	sub d			;6ab8
	and d			;6ab9
	or c			;6aba
	ret nz			;6abb
	and h			;6abc
	sub l			;6abd
	add a,(hl)			;6abe
	add a,l			;6abf
	halt			;6ac0
	ld (hl),l			;6ac1
	ld h,(hl)			;6ac2
	ld h,l			;6ac3
	ld d,(hl)			;6ac4
	ld d,l			;6ac5
	ld b,(hl)			;6ac6
	ld b,l			;6ac7
	ld (hl),027h		;6ac8
	jr $+11		;6aca
	ld a,(bc)			;6acc
	add hl,de			;6acd
	ld a,(de)			;6ace
	dec de			;6acf
	dec hl			;6ad0
	ld hl,(0d23ah)		;6ad1
	jp 0b4c4h		;6ad4
	or l			;6ad7
	push bc			;6ad8
	or (hl)			;6ad9
	add a,0b7h		;6ada
	rst 0			;6adc
	rst 10h			;6add
	ret z			;6ade
	cp c			;6adf
	cp d			;6ae0
	xor e			;6ae1
	ld h,b			;6ae2
	ld (hl),c			;6ae3
	ld (hl),h			;6ae4
	ld (hl),a			;6ae5
	ld h,a			;6ae6
	ld l,b			;6ae7
	ld e,b			;6ae8
	ld e,c			;6ae9
	ld l,c			;6aea
	ld l,d			;6aeb
	ld e,e			;6aec
	cp 080h		;6aed
	sub c			;6aef
	sub d			;6af0
	sub e			;6af1
	add a,e			;6af2
	add a,h			;6af3
	add a,l			;6af4
	halt			;6af5
	ld (hl),a			;6af6
	ld l,b			;6af7
	ld a,b			;6af8
	ld l,c			;6af9
	ld a,c			;6afa
	ld a,d			;6afb
	ld l,d			;6afc
	ld l,e			;6afd
	ld l,h			;6afe
	ld a,e			;6aff
	adc a,d			;6b00
	adc a,e			;6b01
	sbc a,d			;6b02
	sbc a,e			;6b03
	xor d			;6b04
	xor e			;6b05
	cp d			;6b06
	cp e			;6b07
	jp z,0dacbh		;6b08
	in a,(0eah)		;6b0b
	ex de,hl			;6b0d
	call c,0d8c9h		;6b0e
	rst 10h			;6b11
	rst 20h			;6b12
	and 0d6h		;6b13
	push hl			;6b15
	push de			;6b16
	push bc			;6b17
	call nc,0d3e4h		;6b18
	call nz,0c2c3h		;6b1b
	pop bc			;6b1e
	or d			;6b1f
	or e			;6b20
	or h			;6b21
	and h			;6b22
	and e			;6b23
	and d			;6b24
	sub d			;6b25
	sub e			;6b26
	sub h			;6b27
	add a,e			;6b28
	add a,d			;6b29
	ld (hl),d			;6b2a
	ld (hl),e			;6b2b
	ld (hl),h			;6b2c
	ld h,h			;6b2d
	ld h,e			;6b2e
	ld h,d			;6b2f
	ld d,d			;6b30
	ld d,e			;6b31
	ld d,h			;6b32
	ld b,h			;6b33
	ld b,e			;6b34
	ld b,d			;6b35
	ld (03433h),a		;6b36
	djnz l6b5ch		;6b39
	ld (02423h),hl		;6b3b
	dec d			;6b3e
	ld d,007h		;6b3f
	rla			;6b41
	ex af,af'			;6b42
	jr l6b4eh		;6b43
	add hl,de			;6b45
	jr z,l6b71h		;6b46
	ld a,(de)			;6b48
	ld hl,(03a39h)		;6b49
	dec hl			;6b4c
	inc e			;6b4d
l6b4eh:
	ld h,036h		;6b4e
	ld b,(hl)			;6b50
	ld d,(hl)			;6b51
	ld h,(hl)			;6b52
	halt			;6b53
	add a,(hl)			;6b54
	sub (hl)			;6b55
	and (hl)			;6b56
	or (hl)			;6b57
	add a,0d6h		;6b58
	ret c			;6b5a
	ret z			;6b5b
l6b5ch:
	cp 000h		;6b5c
	ld de,01312h		;6b5e
	inc b			;6b61
	dec b			;6b62
	ld b,007h		;6b63
	ld d,015h		;6b65
	inc d			;6b67
	inc h			;6b68
	dec h			;6b69
	ld h,036h		;6b6a
	dec (hl)			;6b6c
	inc (hl)			;6b6d
	ld b,h			;6b6e
	ld b,l			;6b6f
	ld b,(hl)			;6b70
l6b71h:
	ld d,(hl)			;6b71
	ld d,l			;6b72
	ld d,h			;6b73
	ld h,h			;6b74
	ld h,l			;6b75
	ld h,(hl)			;6b76
	halt			;6b77
	ld (hl),l			;6b78
	ld (hl),h			;6b79
	add a,h			;6b7a
	add a,l			;6b7b
	add a,(hl)			;6b7c
	sub (hl)			;6b7d
	sub l			;6b7e
	sub h			;6b7f
	and h			;6b80
	and l			;6b81
	and (hl)			;6b82
	or l			;6b83
	call nz,0c3b4h		;6b84
	or e			;6b87
	or d			;6b88
	and d			;6b89
	and c			;6b8a
	or b			;6b8b
	ld (03223h),hl		;6b8c
	ld b,d			;6b8f
	ld d,d			;6b90
	ld h,d			;6b91
	ld (hl),d			;6b92
	add a,d			;6b93
	sub d			;6b94
	sub a			;6b95
	adc a,b			;6b96
	ld a,c			;6b97
	ld l,d			;6b98
	ld e,d			;6b99
	ld c,d			;6b9a
	ld a,(04857h)		;6b9b
	add hl,sp			;6b9e
	ld c,c			;6b9f
	ld c,d			;6ba0
	dec sp			;6ba1
	ld e,d			;6ba2
	ld e,c			;6ba3
	ld l,c			;6ba4
	ld l,d			;6ba5
	ld a,d			;6ba6
	adc a,c			;6ba7
	adc a,d			;6ba8
	sbc a,c			;6ba9
	sbc a,d			;6baa
	xor c			;6bab
	xor d			;6bac
	cp c			;6bad
	jp z,0bbbah		;6bae
	xor h			;6bb1
	cp 03ah		;6bb2
	dec hl			;6bb4
	ld hl,(01a1bh)		;6bb5
	ld a,(bc)			;6bb8
	add hl,bc			;6bb9
	add hl,de			;6bba
	jr l6be4h		;6bbb
	ld (hl),047h		;6bbd
	scf			;6bbf
	ld b,(hl)			;6bc0
	ld d,a			;6bc1
	ld d,(hl)			;6bc2
	ld h,a			;6bc3
	ld h,(hl)			;6bc4
	ld (hl),a			;6bc5
	halt			;6bc6
	add a,a			;6bc7
	add a,(hl)			;6bc8
	sub a			;6bc9
	sub (hl)			;6bca
	and a			;6bcb
	and (hl)			;6bcc
	or (hl)			;6bcd
	push bc			;6bce
	call nc,0c3d3h		;6bcf
	jp nc,0c1c2h		;6bd2
	or c			;6bd5
	or b			;6bd6
	and b			;6bd7
	and c			;6bd8
	or d			;6bd9
	and c			;6bda
	sub c			;6bdb
	sub b			;6bdc
	add a,b			;6bdd
	add a,c			;6bde
	ld (hl),c			;6bdf
	ld h,d			;6be0
	or h			;6be1
	and h			;6be2
	sub h			;6be3
l6be4h:
	add a,h			;6be4
	ld (hl),h			;6be5
	ld h,h			;6be6
	ld d,h			;6be7
	ld b,h			;6be8
	inc (hl)			;6be9
	dec h			;6bea
	ld d,007h		;6beb
	ld d,l			;6bed
	add a,l			;6bee
	ld d,c			;6bef
	call m,00110h		;6bf0
	ld (bc),a			;6bf3
	inc bc			;6bf4
	inc d			;6bf5
	inc de			;6bf6
	inc hl			;6bf7
	ld (03332h),hl		;6bf8
	ld b,h			;6bfb
	ld b,l			;6bfc
	ld b,(hl)			;6bfd
	ld b,a			;6bfe
	ld c,b			;6bff
	add hl,sp			;6c00
	ld hl,(01a29h)		;6c01
	add hl,de			;6c04
	add hl,bc			;6c05
	ex af,af'			;6c06
	jr $+25		;6c07
	ld h,036h		;6c09
	dec (hl)			;6c0b
	ld d,h			;6c0c
	ld d,l			;6c0d
	ld d,(hl)			;6c0e
	ld h,(hl)			;6c0f
	ld h,l			;6c10
	ld h,h			;6c11
	ld (hl),h			;6c12
	ld (hl),l			;6c13
	halt			;6c14
	add a,(hl)			;6c15
	add a,l			;6c16
	add a,h			;6c17
	sub h			;6c18
	sub l			;6c19
	sub (hl)			;6c1a
	and l			;6c1b
	and h			;6c1c
	or e			;6c1d
	jp nz,0b5b4h		;6c1e
	or (hl)			;6c21
	add a,0b7h		;6c22
	rst 0			;6c24
	cp b			;6c25
	ret z			;6c26
	cp c			;6c27
	ret			;6c28
	cp d			;6c29
	cp e			;6c2a
	xor h			;6c2b
	xor b			;6c2c
	sbc a,b			;6c2d
	adc a,b			;6c2e
	ld a,b			;6c2f
	ld l,b			;6c30
	ld e,b			;6c31
	cp 0b0h		;6c32
	or c			;6c34
	and d			;6c35
	and c			;6c36
	sub d			;6c37
	sub c			;6c38
	add a,d			;6c39
	add a,c			;6c3a
	ld (hl),d			;6c3b
	ld (hl),c			;6c3c
	ld h,d			;6c3d
	ld h,c			;6c3e
	ld d,d			;6c3f
	ld d,c			;6c40
	ld b,d			;6c41
	ld b,c			;6c42
	ld sp,02132h		;6c43
	jr nz,l6c69h		;6c46
	ld (00413h),hl		;6c48
	dec b			;6c4b
	inc d			;6c4c
	inc h			;6c4d
	inc (hl)			;6c4e
	ld b,h			;6c4f
	ld d,h			;6c50
	ld h,h			;6c51
	ld (hl),h			;6c52
	add a,h			;6c53
	sub h			;6c54
	and h			;6c55
	or h			;6c56
	jp 0d1d2h		;6c57
	ret nc			;6c5a
	dec d			;6c5b
	ld d,025h		;6c5c
	ld h,027h		;6c5e
	ld (hl),037h		;6c60
	ld b,(hl)			;6c62
	ld b,a			;6c63
	ld d,(hl)			;6c64
	ld d,a			;6c65
	ld h,(hl)			;6c66
	ld h,a			;6c67
	halt			;6c68
l6c69h:
	ld (hl),a			;6c69
	add a,(hl)			;6c6a
	add a,a			;6c6b
	sub (hl)			;6c6c
	sub a			;6c6d
	and (hl)			;6c6e
	and a			;6c6f
	or a			;6c70
	or (hl)			;6c71
	add a,0d6h		;6c72
	push de			;6c74
	rst 0			;6c75
	sub 018h		;6c76
	add hl,bc			;6c78
	ld a,(bc)			;6c79
	ld a,(de)			;6c7a
	add hl,de			;6c7b
	add hl,hl			;6c7c
	add hl,sp			;6c7d
	ld c,c			;6c7e
	ld e,c			;6c7f
	ld l,c			;6c80
	ld a,c			;6c81
	adc a,c			;6c82
	sbc a,c			;6c83
	xor c			;6c84
	cp c			;6c85
	ret			;6c86
	dec de			;6c87
	ld hl,(02c2bh)		;6c88
	dec sp			;6c8b
	inc a			;6c8c
	ld c,e			;6c8d
	ld c,h			;6c8e
	ld e,e			;6c8f
	ld e,h			;6c90
	ld l,e			;6c91
	ld l,h			;6c92
	ld a,e			;6c93
	ld a,h			;6c94
	adc a,e			;6c95
	adc a,h			;6c96
	sbc a,e			;6c97
	sbc a,h			;6c98
	xor e			;6c99
	xor h			;6c9a
	cp h			;6c9b
	cp e			;6c9c
	set 3,d		;6c9d
	ld l,d			;6c9f
	ld h,l			;6ca0
	ld h,h			;6ca1
	cp 012h		;6ca2
	ld (03221h),hl		;6ca4
	ld sp,04030h		;6ca7
	ld b,c			;6caa
	ld b,d			;6cab
	ld d,d			;6cac
	ld d,c			;6cad
	ld d,b			;6cae
	ld h,b			;6caf
	ld h,c			;6cb0
	ld h,d			;6cb1
	ld (hl),d			;6cb2
	ld (hl),c			;6cb3
	ld (hl),b			;6cb4
	add a,b			;6cb5
	add a,c			;6cb6
	add a,d			;6cb7
	sub d			;6cb8
	sub c			;6cb9
	sub b			;6cba
	and c			;6cbb
	and d			;6cbc
	or d			;6cbd
	or e			;6cbe
	jp 0b4c4h		;6cbf
	push bc			;6cc2
	sub 0c6h		;6cc3
	rst 0			;6cc5
	or a			;6cc6
	cp b			;6cc7
	cp c			;6cc8
	xor b			;6cc9
	xor c			;6cca
	xor d			;6ccb
	xor e			;6ccc
	sbc a,e			;6ccd
	sbc a,d			;6cce
	sbc a,c			;6ccf
	sbc a,b			;6cd0
	adc a,b			;6cd1
	adc a,c			;6cd2
	adc a,d			;6cd3
	adc a,e			;6cd4
	ld a,e			;6cd5
	ld a,d			;6cd6
	ld a,c			;6cd7
	ld a,b			;6cd8
	ld l,b			;6cd9
	ld l,c			;6cda
	ld l,d			;6cdb
	ld l,e			;6cdc
	ld e,e			;6cdd
	ld e,d			;6cde
	ld e,c			;6cdf
	ld e,b			;6ce0
	ld c,b			;6ce1
	ld c,b			;6ce2
	ld c,c			;6ce3
	ld c,d			;6ce4
	ld c,e			;6ce5
	dec sp			;6ce6
	ld a,(03839h)		;6ce7
	add hl,hl			;6cea
	jr z,l6d05h		;6ceb
	daa			;6ced
	rla			;6cee
	rlca			;6cef
	ld b,016h		;6cf0
	ld h,015h		;6cf2
	dec b			;6cf4
	inc b			;6cf5
	inc d			;6cf6
	inc de			;6cf7
	inc bc			;6cf8
	inc de			;6cf9
	ld (hl),035h		;6cfa
	ld b,l			;6cfc
	ld b,(hl)			;6cfd
	ld d,(hl)			;6cfe
	ld d,l			;6cff
	ld d,(hl)			;6d00
	ld h,(hl)			;6d01
	ld h,l			;6d02
	ld (hl),l			;6d03
	halt			;6d04
l6d05h:
	add a,(hl)			;6d05
	add a,l			;6d06
	sub l			;6d07
	sub (hl)			;6d08
	and l			;6d09
	and h			;6d0a
	ld d,a			;6d0b
	add a,a			;6d0c
	call m,00403h		;6d0d
	inc d			;6d10
	inc de			;6d11
	ld (de),a			;6d12
	ld (02423h),hl		;6d13
	inc (hl)			;6d16
	inc sp			;6d17
	ld (04342h),a		;6d18
	ld b,h			;6d1b
	ld d,h			;6d1c
	ld d,e			;6d1d
	ld d,d			;6d1e
	ld h,d			;6d1f
	ld h,e			;6d20
	ld h,h			;6d21
	ld (hl),h			;6d22
	ld (hl),e			;6d23
	ld (hl),d			;6d24
	add a,d			;6d25
	add a,e			;6d26
	add a,h			;6d27
	sub h			;6d28
	sub e			;6d29
	sub d			;6d2a
	and d			;6d2b
	and e			;6d2c
	and h			;6d2d
	or h			;6d2e
	or e			;6d2f
	or d			;6d30
	jp nz,0c4c3h		;6d31
	out (0d2h),a		;6d34
	pop de			;6d36
	ret nz			;6d37
	djnz l6d5bh		;6d38
	dec h			;6d3a
	ld d,026h		;6d3b
	daa			;6d3d
	rla			;6d3e
	rlca			;6d3f
	ex af,af'			;6d40
	jr l6d4ch		;6d41
	add hl,de			;6d43
	ld a,(de)			;6d44
	dec de			;6d45
	inc e			;6d46
	dec c			;6d47
	dec hl			;6d48
	ld hl,(03929h)		;6d49
l6d4ch:
	ld a,(04b3bh)		;6d4c
	ld c,d			;6d4f
	ld c,c			;6d50
	ld e,c			;6d51
	ld e,d			;6d52
	ld e,e			;6d53
	ld l,e			;6d54
	ld l,d			;6d55
	ld l,c			;6d56
	ld a,c			;6d57
	ld a,d			;6d58
	ld a,e			;6d59
	adc a,c			;6d5a
l6d5bh:
	ld a,b			;6d5b
	adc a,b			;6d5c
	sbc a,b			;6d5d
	sub a			;6d5e
	add a,a			;6d5f
	ld (hl),a			;6d60
	halt			;6d61
	add a,(hl)			;6d62
	ld (hl),l			;6d63
	ld h,l			;6d64
	ld h,c			;6d65
	ld (hl),b			;6d66
	scf			;6d67
	ld b,a			;6d68
	ld d,a			;6d69
	ld h,a			;6d6a
	ld (hl),a			;6d6b
	and a			;6d6c
	or a			;6d6d
	rst 0			;6d6e
	sub 048h		;6d6f
	cp 0d0h		;6d71
	pop bc			;6d73
	or d			;6d74
	jp nz,0c3b3h		;6d75
	or h			;6d78
	call nz,0c5b5h		;6d79
	sub 0c6h		;6d7c
	rst 0			;6d7e
	rst 10h			;6d7f
	ret c			;6d80
	ret z			;6d81
	exx			;6d82
	ret			;6d83
	jp z,0bbbah		;6d84
	xor h			;6d87
	xor e			;6d88
	xor d			;6d89
	sbc a,d			;6d8a
	sbc a,e			;6d8b
	sbc a,h			;6d8c
	sbc a,l			;6d8d
	adc a,h			;6d8e
	adc a,e			;6d8f
	adc a,d			;6d90
	ld a,e			;6d91
	ld a,d			;6d92
	ld l,c			;6d93
	ld a,c			;6d94
	ld a,b			;6d95
	ld l,b			;6d96
	ld h,a			;6d97
	ld (hl),a			;6d98
	halt			;6d99
	ld h,(hl)			;6d9a
	ld h,l			;6d9b
	ld (hl),l			;6d9c
	ld h,h			;6d9d
	ld (hl),h			;6d9e
	ld (hl),e			;6d9f
	ld h,e			;6da0
	ld h,d			;6da1
	ld d,c			;6da2
	ld d,d			;6da3
	ld d,e			;6da4
	ld b,d			;6da5
	ld b,e			;6da6
	inc sp			;6da7
	inc h			;6da8
	dec h			;6da9
	dec d			;6daa
	ld b,016h		;6dab
	ld h,027h		;6dad
	rla			;6daf
	rlca			;6db0
	ex af,af'			;6db1
	jr l6ddch		;6db2
	jr c,l6dffh		;6db4
	add hl,sp			;6db6
	add hl,hl			;6db7
	add hl,de			;6db8
	ld a,(de)			;6db9
	ld hl,(02b3ah)		;6dba
	inc e			;6dbd
	dec c			;6dbe
	ld e,b			;6dbf
	add a,l			;6dc0
	sub h			;6dc1
	and e			;6dc2
	ld h,b			;6dc3
	ld (hl),b			;6dc4
	ld (hl),c			;6dc5
	add a,c			;6dc6
	add a,d			;6dc7
	sub d			;6dc8
	sub e			;6dc9
	sub h			;6dca
	sub l			;6dcb
	sub (hl)			;6dcc
	sub a			;6dcd
	sbc a,b			;6dce
	xor c			;6dcf
	cp c			;6dd0
	cp 020h		;6dd1
	ld de,01202h		;6dd3
	inc bc			;6dd6
	inc de			;6dd7
	inc b			;6dd8
	inc d			;6dd9
	dec b			;6dda
	dec d			;6ddb
l6ddch:
	dec h			;6ddc
	ld h,016h		;6ddd
	ld b,007h		;6ddf
	rla			;6de1
	daa			;6de2
	jr z,l6dfdh		;6de3
	ex af,af'			;6de5
	add hl,de			;6de6
	add hl,hl			;6de7
	ld a,(de)			;6de8
	ld hl,(01b2bh)		;6de9
	inc e			;6dec
	dec c			;6ded
	inc (hl)			;6dee
	ld b,e			;6def
	ld b,h			;6df0
	ld d,e			;6df1
	ld d,h			;6df2
	ld h,e			;6df3
	ld h,h			;6df4
	ld (hl),e			;6df5
	ld (hl),h			;6df6
	add a,e			;6df7
	add a,h			;6df8
	sub e			;6df9
	sub h			;6dfa
	and e			;6dfb
	and h			;6dfc
l6dfdh:
	or e			;6dfd
	or h			;6dfe
l6dffh:
	call nz,0c5b5h		;6dff
	push de			;6e02
	sub 0c6h		;6e03
	rst 0			;6e05
	rst 10h			;6e06
	ret z			;6e07
	cp b			;6e08
	cp c			;6e09
	xor c			;6e0a
	sbc a,d			;6e0b
	and a			;6e0c
	sub a			;6e0d
	add a,a			;6e0e
	ld (hl),a			;6e0f
	ld h,a			;6e10
	ld d,a			;6e11
	ld b,a			;6e12
	scf			;6e13
	cp 020h		;6e14
	ld de,00302h		;6e16
	inc d			;6e19
	inc de			;6e1a
	ld (de),a			;6e1b
	ld (02423h),hl		;6e1c
	inc (hl)			;6e1f
	inc sp			;6e20
	ld (04342h),a		;6e21
	ld b,h			;6e24
	ld d,h			;6e25
	ld d,e			;6e26
	ld d,d			;6e27
	ld h,d			;6e28
	ld h,e			;6e29
	ld h,h			;6e2a
	ld (hl),h			;6e2b
	ld (hl),l			;6e2c
	halt			;6e2d
	ld (hl),a			;6e2e
	ld a,b			;6e2f
	ld a,c			;6e30
	ld l,b			;6e31
	ld l,c			;6e32
	ld l,d			;6e33
	ld e,d			;6e34
	ld e,c			;6e35
	ld e,b			;6e36
	ld c,b			;6e37
	ld c,c			;6e38
	ld c,d			;6e39
	ld a,(03839h)		;6e3a
	jr z,l6e68h		;6e3d
	ld hl,(02a1bh)		;6e3f
	add hl,de			;6e42
	jr l6e4dh		;6e43
	rlca			;6e45
	ld d,027h		;6e46
	ld h,036h		;6e48
	ld b,a			;6e4a
	ld b,(hl)			;6e4b
	ld d,(hl)			;6e4c
l6e4dh:
	ld h,(hl)			;6e4d
	halt			;6e4e
	add a,(hl)			;6e4f
	add a,l			;6e50
	sub h			;6e51
	sub e			;6e52
	and d			;6e53
	and e			;6e54
	and h			;6e55
	or h			;6e56
	or e			;6e57
	or d			;6e58
	jp nz,0c4c3h		;6e59
	call nc,0c5d5h		;6e5c
	add a,0b7h		;6e5f
	xor b			;6e61
	sbc a,c			;6e62
	sbc a,d			;6e63
	xor e			;6e64
	xor d			;6e65
	cp e			;6e66
	cp d			;6e67
l6e68h:
	set 1,d		;6e68
	exx			;6e6a
	ret z			;6e6b
	or a			;6e6c
	and (hl)			;6e6d
	sub l			;6e6e
	sub h			;6e6f
	sub e			;6e70
	add a,d			;6e71
	add a,c			;6e72
	sub b			;6e73
	cp 040h		;6e74
	ld b,c			;6e76
	ld d,c			;6e77
	ld d,d			;6e78
	ld b,e			;6e79
	ld b,h			;6e7a
	ld d,h			;6e7b
	ld d,l			;6e7c
	ld b,(hl)			;6e7d
	ld h,l			;6e7e
	ld h,h			;6e7f
	ld (hl),l			;6e80
	ld (hl),h			;6e81
	add a,h			;6e82
	add a,l			;6e83
	sub l			;6e84
	sub h			;6e85
	and h			;6e86
	and l			;6e87
	or h			;6e88
	or l			;6e89
	or (hl)			;6e8a
	push bc			;6e8b
	or h			;6e8c
	jp 0c1c2h		;6e8d
	or d			;6e90
	or c			;6e91
	or b			;6e92
	and c			;6e93
	and b			;6e94
	sub c			;6e95
	sub b			;6e96
	add a,c			;6e97
	add a,b			;6e98
	ld (hl),c			;6e99
	ld (hl),d			;6e9a
	add a,e			;6e9b
	ret m			;6e9c
	ld bc,01110h		;6e9d
	ld (de),a			;6ea0
	ld hl,03222h		;6ea1
	ld sp,04241h		;6ea4
	ld d,d			;6ea7
	ld d,c			;6ea8
	ld h,c			;6ea9
	ld h,d			;6eaa
	ld (hl),d			;6eab
	ld (hl),c			;6eac
	add a,c			;6ead
	add a,d			;6eae
	sub d			;6eaf
	sub c			;6eb0
	and d			;6eb1
	and c			;6eb2
	or b			;6eb3
	or c			;6eb4
	or d			;6eb5
	or e			;6eb6
	jp nz,0c4c3h		;6eb7
	or l			;6eba
	or (hl)			;6ebb
	and l			;6ebc
	and (hl)			;6ebd
	sub l			;6ebe
	sub (hl)			;6ebf
	add a,l			;6ec0
	add a,(hl)			;6ec1
	ld (hl),l			;6ec2
	halt			;6ec3
	ld h,l			;6ec4
	ld h,(hl)			;6ec5
	ld d,l			;6ec6
	ld d,(hl)			;6ec7
	ld b,l			;6ec8
	ld b,h			;6ec9
	ld d,e			;6eca
	ret m			;6ecb
	or (hl)			;6ecc
	or l			;6ecd
	call nz,0c2c3h		;6ece
	or e			;6ed1
	or d			;6ed2
	or c			;6ed3
	or b			;6ed4
	and c			;6ed5
	and d			;6ed6
	sub d			;6ed7
	sub c			;6ed8
	add a,d			;6ed9
	add a,c			;6eda
	ld (hl),d			;6edb
	ld (hl),c			;6edc
	ld h,d			;6edd
	ld h,c			;6ede
	ld d,d			;6edf
	ld d,c			;6ee0
	ld b,e			;6ee1
	ld b,h			;6ee2
	ld b,l			;6ee3
	ld d,h			;6ee4
	ld d,l			;6ee5
	ld d,(hl)			;6ee6
	ld h,(hl)			;6ee7
	ld h,l			;6ee8
	ret m			;6ee9
	ld d,b			;6eea
	ld d,c			;6eeb
	ld h,b			;6eec
	ld h,c			;6eed
	ld (hl),b			;6eee
	ld (hl),c			;6eef
	add a,b			;6ef0
	sub b			;6ef1
	add a,c			;6ef2
	sub c			;6ef3
	and b			;6ef4
	and c			;6ef5
	or b			;6ef6
	or c			;6ef7
	or d			;6ef8
	pop bc			;6ef9
	jp nz,0b4c3h		;6efa
	or l			;6efd
	or (hl)			;6efe
	and l			;6eff
	and h			;6f00
	sub l			;6f01
	sub h			;6f02
	add a,l			;6f03
	add a,h			;6f04
	ld (hl),l			;6f05
	ld (hl),h			;6f06
	ld h,l			;6f07
	ld h,h			;6f08
	ld d,l			;6f09
	ld d,h			;6f0a
	ld d,e			;6f0b
	ld b,h			;6f0c
	ld b,e			;6f0d
	ld b,d			;6f0e
	inc sp			;6f0f
	ld (02231h),a		;6f10
	ld hl,01120h		;6f13
	djnz l6f18h		;6f16
l6f18h:
	rst 30h			;6f18
	and (hl)			;6f19
	or l			;6f1a
	call nz,0c2c3h		;6f1b
	or e			;6f1e
	or d			;6f1f
	or c			;6f20
	or b			;6f21
	and c			;6f22
	and d			;6f23
	sub c			;6f24
	sub d			;6f25
	add a,c			;6f26
	add a,d			;6f27
	ld (hl),c			;6f28
	ld (hl),d			;6f29
	ld h,c			;6f2a
	ld h,d			;6f2b
	ld d,c			;6f2c
	ld d,d			;6f2d
	ld b,e			;6f2e
	ld b,h			;6f2f
	ld b,l			;6f30
	ld d,h			;6f31
	ld d,l			;6f32
	ld d,(hl)			;6f33
	ld h,(hl)			;6f34
	ld h,l			;6f35
	ld (hl),h			;6f36
	add a,e			;6f37
	ret m			;6f38
	jp nz,0b2b3h		;6f39
	or c			;6f3c
	and d			;6f3d
	and c			;6f3e
	sub d			;6f3f
	sub c			;6f40
	add a,d			;6f41
	add a,c			;6f42
	ld (hl),d			;6f43
	ld (hl),c			;6f44
	ld h,d			;6f45
	ld h,c			;6f46
	ld d,d			;6f47
	ld d,c			;6f48
	ld b,d			;6f49
	ld b,c			;6f4a
	ld b,d			;6f4b
	ld sp,02132h		;6f4c
	ld (01211h),hl		;6f4f
	inc bc			;6f52
	inc b			;6f53
	inc d			;6f54
	dec d			;6f55
	ld d,040h		;6f56
	ld b,c			;6f58
	ld b,d			;6f59
	ld b,e			;6f5a
	ld b,h			;6f5b
	rst 30h			;6f5c
	or e			;6f5d
	or d			;6f5e
	or c			;6f5f
	and d			;6f60
	and c			;6f61
	and b			;6f62
	and b			;6f63
	and b			;6f64
	sub c			;6f65
	sub b			;6f66
	add a,c			;6f67
	add a,b			;6f68
	ld (hl),c			;6f69
	ld (hl),b			;6f6a
	ld h,c			;6f6b
	ld h,b			;6f6c
	ld d,b			;6f6d
	ld d,c			;6f6e
	ld b,d			;6f6f
	ld b,e			;6f70
	ld b,h			;6f71
	ld d,e			;6f72
	ld d,h			;6f73
	ld d,l			;6f74
	ld h,h			;6f75
	ld d,(hl)			;6f76
	ld h,l			;6f77
	ld (hl),h			;6f78
	ld (hl),l			;6f79
	add a,h			;6f7a
	add a,l			;6f7b
	sub h			;6f7c
	sub l			;6f7d
	and h			;6f7e
	and l			;6f7f
	or h			;6f80
	or l			;6f81
	push bc			;6f82
	call nz,0d4d5h		;6f83
	ex (sp),hl			;6f86
	jp po,0d1d2h		;6f87
	ret nc			;6f8a
	rst 30h			;6f8b
	inc bc			;6f8c
	ld (bc),a			;6f8d
	ld de,01010h		;6f8e
	ld hl,03120h		;6f91
	jr nc,l6fd7h		;6f94
	ld b,b			;6f96
	ld d,c			;6f97
	ld d,b			;6f98
	ld h,c			;6f99
	ld h,b			;6f9a
	ld (hl),c			;6f9b
	ld (hl),b			;6f9c
	add a,c			;6f9d
	add a,b			;6f9e
	sub c			;6f9f
	sub b			;6fa0
	and c			;6fa1
	and b			;6fa2
	or b			;6fa3
	or c			;6fa4
	pop bc			;6fa5
	or d			;6fa6
	ld h,d			;6fa7
	ld d,e			;6fa8
	ld b,h			;6fa9
	ld d,l			;6faa
	ld d,h			;6fab
	ld h,l			;6fac
	ld h,h			;6fad
	ld (hl),l			;6fae
	ld (hl),h			;6faf
	add a,l			;6fb0
	add a,h			;6fb1
	sub l			;6fb2
	sub h			;6fb3
	and h			;6fb4
	and l			;6fb5
	or h			;6fb6
	or l			;6fb7
	push bc			;6fb8
	or (hl)			;6fb9
	rst 30h			;6fba
	ld d,b			;6fbb
	ld b,c			;6fbc
	ld d,d			;6fbd
	ld d,c			;6fbe
	ld h,c			;6fbf
	ld h,d			;6fc0
	ld (hl),d			;6fc1
	ld (hl),c			;6fc2
	add a,c			;6fc3
	add a,d			;6fc4
	sub d			;6fc5
	sub c			;6fc6
	and c			;6fc7
	and d			;6fc8
	or d			;6fc9
	or c			;6fca
	jp nz,021b3h		;6fcb
	ld de,02221h		;6fce
	push af			;6fd1
	ld b,h			;6fd2
	ld d,e			;6fd3
	ld d,h			;6fd4
	ld d,l			;6fd5
	ld h,h			;6fd6
l6fd7h:
	ld h,l			;6fd7
	ld (hl),l			;6fd8
	ld (hl),h			;6fd9
	add a,h			;6fda
	add a,l			;6fdb
	sub l			;6fdc
	sub h			;6fdd
	and h			;6fde
	and l			;6fdf
	or l			;6fe0
	or h			;6fe1
	call nz,0d5c5h		;6fe2
	call nc,0e3e4h		;6fe5
	jp po,0d1d2h		;6fe8
	inc h			;6feb
	inc d			;6fec
	inc d			;6fed
	dec h			;6fee
	ret m			;6fef
	ld b,b			;6ff0
	ld b,c			;6ff1
	ld b,d			;6ff2
	ld d,c			;6ff3
	ld d,d			;6ff4
	ld h,c			;6ff5
	ld h,d			;6ff6
	ld (hl),c			;6ff7
	ld (hl),d			;6ff8
	add a,c			;6ff9
	add a,d			;6ffa
	sub c			;6ffb
	sub d			;6ffc
	and c			;6ffd
	and d			;6ffe
	or d			;6fff
