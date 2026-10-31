; f_441E at 441E (64K)   PC: -   CPC 6128: -   called 76643 times by 4392 43A6 43CD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
441E * ld a,h
441F * add a,a
4420 * add a,a
4421 * add a,a
4422 * add a,a
4423 * or l
4424 * ld e,a
4425 * ld d,000h
4427 * ld ix,(03f73h)
442B * add ix,de
442D * ret
442E   jp 020beh
4431   in a,(0abh)
4433   ld e,c
4434   xor e
4435   in a,(0abh)
4437   ld d,e
4438   xor h
4439   cp e
443A   xor l
443B   res 5,h
443D   cp e
443E   xor l
443F   ld c,b
4440   xor l
4441   cp e
4442   defb 0edh;next byte illegal after ed
4443   set 5,h
4445   cp e
4446   in c,(c)
4448   defb 0edh;next byte illegal after ed
4449   in a,(0ebh)
444B   ld e,c
444C   ex de,hl
444D   in a,(0ebh)
444F   ld d,e
4450   call pe,0e000h
4453   inc bc
4454   ret m
4455   rlca
4456   call m,0fc07h
4459   rrca
445A   cp 00fh
445C   cp 01fh
445E   rst 38h
445F   rra
4460   rst 38h
4461   rra
4462   rst 38h
4463   rra
4464   rst 38h
4465   rrca
4466   cp 00fh
4468   cp 007h
446A   call m,0fc07h
446D   inc bc
446E   ret m
446F   nop
4470   ret po
4471   nop
4472   nop
4473   nop
4474   nop
4475   nop
4476   nop
4477   dec bc
4478   ld a,b
4479   or c
447A   jr nz,$-3
447C   ret
447D * ld (04473h),sp
4481 * ld hl,07f80h
4484 * ld (04471h),hl
4487 * ld hl,00000h
448A * ld c,h
448B * push hl
448C * ld hl,02968h
448F * ld de,00014h
4492 * ld a,(hl)
4493 * cp 0ffh
4495 * jr z,$+15
4497 * cp 0feh
4499 * jr z,$+8
449B * push hl
449C * bit 7,a
449E * jr z,$+3
44A0 * inc c
44A1 * add hl,de
44A2 * jr $-16
44A4 * ld (02be1h),sp
44A8 * di
44A9 * ld a,c
44AA * and a
44AB * jr nz,$+8
44AD * ld sp,(04473h)
44B1 * ei
44B2 * ret
44B3 * ld sp,(02be1h)
44B7 * ld b,000h
44B9 * pop de
44BA * pop hl
44BB * ld a,l
44BC * or h
44BD * jr nz,$+8
44BF * ld a,b
44C0 * and a
44C1 * jr nz,$-14
44C3 * jr $+21
44C5 * ld a,(de)
44C6 * and 03fh
44C8 * ld c,a
44C9 * ld a,(hl)
44CA * and 03fh
44CC * cp c
44CD * jr c,$+5
44CF * push hl
44D0 * jr $-23
44D2 * inc b
44D3 * push de
44D4 * push hl
44D5 * pop hl
44D6 * jr $-29
44D8 * ld sp,(02be1h)
44DC * ld (02be3h),sp
44E0 * ld hl,00000h
44E3 * add hl,sp
44E4 * di
44E5 * ld sp,(02be3h)
44E9 * pop de
44EA * ld (02be3h),sp
44EE * ld sp,hl
44EF * ei
44F0 * ld a,e
44F1 * or d
44F2 * jp z,047ach
44F5 * push de
44F6 * pop ix
44F8 * res 6,(ix+000h)
44FC * bit 7,(ix+000h)
4500 * jr z,$-32
4502 * ld l,(ix+001h)
4505 * ld h,(ix+002h)
4508 * ld d,(ix+006h)
450B * ld e,(ix+005h)
450E * res 7,e
4510 * call f_48FC
4513 * ld (02928h),de
4517 * ld (02926h),hl
451A * ld l,(ix+003h)
451D * ld h,(ix+004h)
4520 * ld d,(ix+00ah)
4523 * ld e,(ix+009h)
4526 * call f_4886
4529 * ld hl,(02926h)
452C * ld (ix+00ch),l
452F * ld (ix+00dh),h
4532 * ld a,l
4533 * and 0fch
4535 * ld e,a
4536 * srl a
4538 * add a,e
4539 * ld e,a
453A * ld a,000h
453C * adc a,a
453D * ld d,a
453E * push de
453F * ld l,h
4540 * ld h,000h
4542 * add hl,hl
4543 * add hl,hl
4544 * ld e,l
4545 * ld d,h
4546 * add hl,hl
4547 * add hl,de
4548 * pop de
4549 * add hl,de
454A * ld de,08594h
454D * add hl,de
454E * ld (02be6h),hl
4551 * ld hl,(02928h)
4554 * ld (ix+00eh),l
4557 * ld (ix+00fh),h
455A * ld a,h
455B * ld h,000h
455D * call f_48EB
4560 * ld hl,(04471h)
4563 * ld (04690h),hl
4566 * ld (ix+010h),l
4569 * ld (ix+011h),h
456C * ld b,d
456D * ld c,e
456E * push hl
456F * add hl,bc
4570 * ld (04471h),hl
4573 * ld de,0877eh
4576 * sbc hl,de
4578 * pop de
4579 * jp nc,047ach
457C * set 6,(ix+000h)
4580 * ld l,e
4581 * ld h,d
4582 * inc de
4583 * dec bc
4584 * ld (hl),000h
4586 * ldir
4588 * ld bc,00000h
458B * ld (04972h),bc
458F * ld sp,(02be1h)
4593 * ld (04475h),sp
4597 * ld hl,00000h
459A * add hl,sp
459B * di
459C * ld sp,(04475h)
45A0 * pop de
45A1 * ld (04475h),sp
45A5 * ld sp,hl
45A6 * ei
45A7 * ld a,d
45A8 * or e
45A9 * jp nz,045bfh
45AC * ld bc,0fcfch
45AF * ld a,000h
45B1 * ld (0491bh),a
45B4 * call f_4925
45B7 * ld a,0c9h
45B9 * ld (0491bh),a
45BC * jp 044e0h
45BF * push de
45C0 * pop iy
45C2 * bit 7,(iy+005h)
45C6 * jr nz,$-47
45C8 * ld a,(02926h)
45CB * ld l,a
45CC * ld a,(02928h)
45CF * ld e,a
45D0 * ld h,(iy+001h)
45D3 * ld d,(iy+005h)
45D6 * call f_3786
45D9 * jp nc,04597h
45DC * ld (046a7h),a
45DF * ld a,h
45E0 * ld (0467ch),a
45E3 * ld (04703h),a
45E6 * ld a,l
45E7 * ld (04694h),a
45EA * ld a,(02927h)
45ED * ld l,a
45EE * ld a,(02929h)
45F1 * ld e,a
45F2 * ld h,(iy+002h)
45F5 * ld d,(iy+006h)
45F8 * call f_3786
45FB * jp nc,04597h
45FE * ld (046a4h),a
4601 * ld a,h
4602 * ld (04614h),a
4605 * ld a,l
4606 * ld (04684h),a
4609 * ld c,(iy+012h)
460C * ld b,(iy+013h)
460F * call f_4925
4612 * exx
4613 * ld hl,00000h
4616 * ld a,0cch
4618 * ld (046aeh),a
461B * ld a,023h
461D * ld (046c3h),a
4620 * ld a,l
4621 * ld (046a1h),a
4624 * cp 00ah
4626 * jr c,$+69
4628 * bit 7,(iy+00bh)
462C * jr nz,$+63
462E * ld a,l
462F * sub 00ah
4631 * ld l,a
4632 * ld a,(iy+005h)
4635 * ld (046c9h),a
4638 * call f_48EB
463B * ld a,(iy+00bh)
463E * ld hl,04431h
4641 * add a,a
4642 * add a,l
4643 * ld l,a
4644 * adc a,h
4645 * sub l
4646 * ld h,a
4647 * ld a,(hl)
4648 * inc hl
4649 * ld h,(hl)
464A * ld l,a
464B * ld a,h
464C * res 6,h
464E * add hl,de
464F * bit 6,a
4651 * jr z,$+42
4653 * ld a,0c4h
4655 * ld (046aeh),a
4658 * ld a,02bh
465A * ld (046c3h),a
465D * ld a,(0467ch)
4660 * neg
4662 * add a,(iy+005h)
4665 * dec a
4666 * ld (0467ch),a
4669 * jr $+18
466B * ld a,(iy+005h)
466E * ld (046c9h),a
4671 * call f_48EB
4674 * ld l,(iy+007h)
4677 * ld h,(iy+008h)
467A * add hl,de
467B * ld a,000h
467D * add a,l
467E * ld l,a
467F * adc a,h
4680 * sub l
4681 * ld h,a
4682 * push hl
4683 * ld hl,00000h
4686 * ld a,(02928h)
4689 * ld (0470bh),a
468C * call f_48EB
468F * ld hl,07f80h
4692 * add hl,de
4693 * ld a,000h
4695 * add a,l
4696 * ld e,a
4697 * adc a,h
4698 * sub e
4699 * ld d,a
469A * pop hl
469B * ld a,h
469C * or l
469D * jp z,0472dh
46A0 * ld c,000h
46A2 * exx
46A3 * ld b,000h
46A5 * exx
46A6 * ld b,000h
46A8 * push de
46A9 * push hl
46AA * ld a,(hl)
46AB * and a
46AC * jr z,$+23
46AE * call z,f_4717
46B1 * exx
46B2 * ld l,a
46B3 * rrca
46B4 * rrca
46B5 * rrca
46B6 * rrca
46B7 * or l
46B8 * jr z,$+8
46BA * cpl
46BB * ld h,a
46BC * exx
46BD * ld a,(de)
46BE * exx
46BF * and h
46C0 * or l
46C1 * exx
46C2 * ld (de),a
46C3 * inc hl
46C4 * inc de
46C5 * djnz $-27
46C7 * pop hl
46C8 * ld de,00000h
46CB * add hl,de
46CC * pop de
46CD * inc c
46CE * ld a,c
46CF * cp 00ah
46D1 * jr nz,$+57
46D3 * ld a,(iy+00bh)
46D6 * bit 7,a
46D8 * jr nz,$+50
46DA * ld hl,04431h
46DD * add a,a
46DE * add a,l
46DF * ld l,a
46E0 * adc a,h
46E1 * sub l
46E2 * ld h,a
46E3 * ld a,(hl)
46E4 * inc hl
46E5 * ld h,(hl)
46E6 * bit 6,h
46E8 * jr z,$+26
46EA * ld l,a
46EB * ld a,0c4h
46ED * ld (046aeh),a
46F0 * ld a,02bh
46F2 * ld (046c3h),a
46F5 * ld a,(04703h)
46F8 * neg
46FA * add a,(iy+005h)
46FD * dec a
46FE * ld (04703h),a
4701 * ld a,l
4702 * add a,000h
4704 * ld l,a
4705 * adc a,h
4706 * sub l
4707 * ld h,a
4708 * res 6,h
470A * ld a,000h
470C * add a,e
470D * ld e,a
470E * adc a,d
470F * sub e
4710 * ld d,a
4711 * exx
4712 * djnz $-109
4714 * jp 04597h
