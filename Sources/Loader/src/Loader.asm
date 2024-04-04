;-----------------------------------------------------------------
; Loading
; Oriens 2018-2024
;-----------------------------------------------------------------
	
NO_MEMORY_MANAGER = 1
USE_SPRITES = 1
EIGHTBITS = 1
SLOWMO = 1

    jmp	startup

	include "system.asm"	
	include "copper.asm"

    code

	include "../../LDOS/src/kernel.inc"	
	
; **************************************************************************
; ***************************** CODE_F SECTION *****************************
; **************************************************************************
	
startup:
    
	; Erase BSS
	lea		startdatabss,a0
	moveq.l	#0,d0
.clr:
	move.l	d0,(a0)+
	cmp.l	#enddatabss,a0
	bmi.b	.clr	

	; Init bitplans
    move.l #screenend-screen-1,d0
    lea screen,a0
.erase:
    move.b #0,(a0)+
    dbra d0,.erase

	; Set Video pointer (both copper)
	move.l	PointerVideoCurrent,d1
	move.w	d1,pointer1+6
	swap	d1
	move.w	d1,pointer1+2
	
	;bsr		sequencer_init ; Important system call!!!
	
	lea		copper,a0
	move.l	#main_irq,a1						; address of our irq callback routine
	bsr		dfm_setCopper					;activate our own irq and copperlist	
	
begincode:
SCREENHEIGHT=114

	; Init main volutes
	Bsr InitNextVolute
	Bsr InitNextVolute
	Bsr InitNextVolute
	Bsr InitNextVolute
	Bsr InitNextVolute    
	Bsr InitNextVolute ; details
	
	move.w #0,Flag_LoadingEnded
	
	; Preload next FX
	move.l (LDOS_BASE).w,a6
	jsr LDOS_PRELOAD_NEXT_FX(a6) ; Blocking function.
	
	move.w #1,Flag_LoadingEnded ; This is a signal to say that loading of  next part is done.
	
fx_update:
			
	cmp.w	#1,exitNow
	beq.s	.end
	
	bra.s	fx_update						; loop
.end:
	bra		anim_Endup
	rts

anim_Endup:

	rts	; Will go to next FX
	
Flag_LoadingEnded:
	dc.w	0
;----------------------------------------------------------------	
InitNextVolute:
	Move.l VoluteCurrent,a1 ; Current data pointer
	cmp.w #$F0F0,(a1)
	beq .end
	bsr initCircle
	add.l #SIZESTRUCTURECIRCLES,VoluteCurrent
.end
	rts

;----------------------------------------------------------------	
PointerVideoCurrent:
	dc.l	screen
drawVoluteNoRenderFlag: ; 1 for first call, we do  not want render
	dc.w 	0

VoluteCurrent:
	dc.l	VolutesCircleDatas

FinalFade: ; Reverse count
	dc.w	0
VoluteEnd:
    dc.w    0

;----------------------------------------------------------------
main_irq:	
	START_IRQ
	; --	

    cmp.w #0,VoluteEnd ; When volute are over, do not call anymore
    bne .novolute
	bsr drawAllVolutes
	bsr evolveAllVolutes
.novolute

	; Final fade ?
    cmp.w #0,FinalFade
    beq .nofinalfade
    bsr DoFinalFade
.nofinalfade:

	; --
	END_IRQ

; --------------------------------
; FinalFade 33 to 1 (0 = inactive)
DoFinalFade:
    sub.w #1,FinalFade

    ; Do fade off
    lea PaletteLogoRef,a0; [in]	a0.l : Source palette (list of words)
    lea PaletteCircles+2,a1; [in]	a1.l : Dest palette 
    move.w #1,d0 ; [in]	d0.w : colors count
    move.w FinalFade,d5 ; [in]	d5.w : multiplier (Current steps ?)
    move.w #5,d6 ; [in]	d6.w : decay. divider (number of steps ?) ... 
    bsr dfm_palette_fade0
    
    cmp.w #0,FinalFade
    bne .noend
    move.w #1,exitNow
.noend:

    rts

PaletteLogoRef:
    dc.w  LOGOCOLOR  

;---------------------------------------------------------------
drawAllVolutes:
	lea volutesdata,a0
	clr.l d0
.drawAllVolutestest:	
	cmp.b #0,0(a0)
	beq .next
	movem.l d0/a0,-(sp)
	bsr drawVolute ; a0 is volute
	movem.l (sp)+,d0/a0
.next:
	; try next one
	add.w #1,d0
	cmp.w #volutemax+1,d0
	beq .end
	; Go to next volume
	add.l #datavolutesize,a0
	bra .drawAllVolutestest
.end:
	rts
;---------------------------------------------------------------	
evolveAllVolutes:
	lea volutesdata,a0
	clr.l d0
    clr.l d1
.evolveAllVolutestest:	
	cmp.b #0,0(a0)
	beq .next
	movem.l d0-d1/a0,-(sp)
	bsr evolveVolute ; a0 is volute
	movem.l (sp)+,d0-d1/a0
    add.w #1,d1
.next:
	; try next one
	add.w #1,d0
	cmp.w #volutemax+1,d0
	beq .end
	; Go to next volume
	add.l #datavolutesize,a0
	bra .evolveAllVolutestest
.end:
    ; No volute updated ?
    cmp.w #0,d1
    bne .noendofvolutes
    ; Do loading ended ?
    cmp.w #1,Flag_LoadingEnded
    bne .noendofvolutes
    ; here all volutes are done
    ;move.w #1,exitNow
    move.w #32+1,FinalFade ; 32 steps from 33 to 1
    move.w #1,VoluteEnd
.noendofvolutes:

	rts
	
;---------------------------------------------------------------
; a1 structure with Circle datas
initCircle: ; Type4=Circle
	bsr getfreevolute ; Free volute in a0
	cmp.l #0,a0
	beq .initVoluteexit
	move.b #4,0(a0) ; Type 4 = Circle
	move.b #0,1(a0) ; Step
	; Current position (0,0 with global position at center of screen)
	move.w #$0000,2(a0) ; X (Warning limited to 256)
	move.w #$0000,4(a0) ; Y
	; Last draw points
	move.l 2(a0),6(a0)
	move.l 2(a0),10(a0)
	; Current width (half width)
	move.w 2(a1),14(a0)
	; Current lenght (not used for type 4)
	move.w #$0100,18(a0)	
	; Current angle
	; 0 degres means horizontal right. $8000 is half way, means 180°, $4000 is 90° down
	; Angle have 512 values, we step 2 by 2, so we use 00:00 to FF:00
	move.w 4(a1),22(a0)
	; Speed change
	move.w #$0000,16(a0) ; Change width 
	move.w #$0000,20(a0) ; Change length 
	; Change angle. This will step 2 values in angle table
	move.w 6(a1),24(a0) 
	; Change speed angle
	move.w #$0000,46(a0)  
	; Global coordinates (integrer values)
	;move.w #77,42(a0)
    move.w #640/2,42(a0) ; HR
	move.w #128-71,44(a0)
	; Set lifetime
	move.w 8(a1),48(a0)
	move.l #0,52(a0) ; no table	
	move.b #0,58(a0) ; Draw on bitplan 1
	move.w #$1,50(a0) ; start to bend shape left
	; -- Type 4 specific.
	move.w 0(a1),d0
	move.b d0,59(a0) ; Radius
	; Launch one fake draw to init first two points
	move.w #1,drawVoluteNoRenderFlag
	bsr drawVolute ; First update to init the shapes
	move.w #0,drawVoluteNoRenderFlag
	
.initVoluteexit:
	rts	

;---------------------------------------------------------------

	; 8:8 format is entire:fixed float.
	; 00:00 is 0.0f
	; 00:80 is 0.5f
	; 00:C0 is 0.75f
	; 01:00 is 1.0f
	; FF:80 is -0.5f
	; FF:40 is -0.75f
	; FF:00 is -1
	;
	; 04:80 (4.50) * 02:c0 (2.75) = 12.375 ( 0c:60 ) 
	;
	; 8 bits signed numbers:
	; Negative numbers (complements 2)
	; NOT +1
	; 80 -128
	; FF -1
	; 00 0
	; 01 1
	; 7F +12
	
;---------------------------------------------------------------
; Draw one volute. Input is a0
drawVolute:
	clr.l d1
	clr.l d2
	clr.l d5
	clr.l d3
	clr.l d4
	clr.l d6 ; radius min
	clr.l d7 ; radius max
	
	; Get radius
	move.b 59(a0),d6
	;move.b #16,d6 ; DEBUG
	move.b d6,d7
	move.w 14(a0),d5
	lsr.w #8,d5
	;move.w #2,d5 ; DEBUG
	sub.w d5,d6; radius min
	add.w d5,d7; radius max
	
	lea cos_tab_data,a1
	move.w 22(a0),d0 ; Angle 8:8 (0 to 256), we lsr by 6, so we keep entire value from 0 to 1024. And last bit to have even value
	lsr.w #6,d0 ; Shift 8 right, and 2 left
	and.w #$FFFE,d0 ; Keep even values
	move.w (a1,d0.w),d1 ; COS (*512, on 9 bits)
	asr.w #1,d1 ; 9 bit to 8. ASR to keep sign
	lea sin_tab_data,a1
	move.w (a1,d0.w),d2 ; SIN
	asr.w #1,d2 ; 9 bit to 8bits
	
	; D3-D4, X and Y of new point
	move.w d6,d3
	move.w d6,d4
	muls.w d1,d3 ; radius*cos
	muls.w d2,d4 ; radius*sin

	; Compute two new points
	move.w d3,34(a0)
	move.w d4,36(a0)
	
	; Second point, external radius
	move.w d7,d3
	move.w d7,d4
	muls.w d1,d3 ; radius*cos
	muls.w d2,d4 ; radius*sin
	
	move.w d3,38(a0)
	move.w d4,40(a0)
	
	; Debug
	;move.w d3,d0 ;  X of external point
	;bsr DisplayWord
	
	; Get global coordinates
	move.w 42(a0),d2 ; Global X
	move.w 44(a0),d3 ; Global Y
	
	cmp.w #1,drawVoluteNoRenderFlag
	beq .norender
	
	; We got the two new points, we can draw.
	; Copy our data into a "shape" structure, wich is roughly 4 points
	Lea quaddata,a1
	; First point X Y, reduce 8:8 to 8
	move.w 6(a0),d0
	;asr.w #8,d0 
    asr.w #7,d0 ; HR *2
	add.w d2,d0 ; Add global X
	move.w d0,0(a1)
	move.w 8(a0),d0
	asr.w #8,d0
	add.w d3,d0 ; Add global Y
	move.w d0,2(a1)
	; Second point
	move.w 10(a0),d0
	;asr.w #8,d0
    asr.w #7,d0 ; HR *2
	add.w d2,d0 ; Add global X
	move.w d0,4(a1)
	move.w 12(a0),d0
	asr.w #8,d0
	add.w d3,d0 ; Add global Y
	move.w d0,6(a1)	
	; Third point
	move.w 34(a0),d0
	;asr.w #8,d0
    asr.w #7,d0 ; HR *2
	add.w d2,d0 ; Add global X
	move.w d0,8(a1)
	move.w 36(a0),d0
	asr.w #8,d0
	add.w d3,d0 ; Add global Y
	move.w d0,10(a1)
	; fourth point
	move.w 38(a0),d0
	;asr.w #8,d0
    asr.w #7,d0 ; HR *2
	add.w d2,d0 ; Add global X
	move.w d0,12(a1)
	move.w 40(a0),d0
	asr.w #8,d0
	add.w d3,d0 ; Add global Y
	move.w d0,14(a1)	
	
	move.b 58(a0),28(a1) ; Copy plane id
	
	move.l a0,-(sp) ; Save volute pointer
	; Draw "shape"
	move.l a1,a0 ; Shape agrument is a0
	bsr drawshape
	move.l (sp)+,a0
	
.norender
	; Save the new points as last points (current position already have been saved)
	move.l 34(a0),6(a0)
	move.l 38(a0),10(a0)
	
	rts

;---------------------------------------------------------------
; a0 is volute structure
evolveVolute:	
	; Evolve values into structure. 
	; Common part
	move.w 24(a0),d0
	add.w d0,22(a0) ; Change angle 
	cmp.b #4,0(a0)
	beq evolveVoluteType4 ; Circle
	rts
	
evolveVoluteType4:
	; Nothing special as angle is already evolving alone.
	; reduce lifetime
	sub.W #1,48(a0)
	cmp.w #0,48(a0)
	bne .noend
	move.w 0,0(a0) ; end of volute
	Bsr InitNextVolute
.noend:
	rts
	
;---------------------------------------------------------------
; a0 Shape structure	
drawshape:
	move.l	a0,-(sp) ; Store on stack
	bsr computeminmax ; compute the limits, empty the zone
	; Draw a quad from a memory structure (quadtest)
	move.l	(sp),a0 ; Structure
	cmp.w #0,26(a0)
	beq .nodraw	
	bsr drawquad
	move.l	(sp),a0
	bsr fillbob
	move.l	(sp)+,a0 ; last time, we pop the value from stack
	bsr copybob	
	rts
.nodraw
	move.l	(sp)+,a0 ; Pop stack	
	rts
	
;---------------------------------------------------------------
drawquad:
	; 1 2 3 4 (each is 2 words) offset are 0=Point1 4=Point2 8=Point3 12=Point4 ... We trace 1-2 , 2-4, 4-3, 3-1
	; XMIN=16 YMIN=18
	move.l	a0,-(sp)
	move.w 0(a0),d0 ; 1x ; d0=x1  d1=y1  d2=x2  d3=y2
	move.w 2(a0),d1 ; 1y
	move.w 4(a0),d2 ; 2x
	move.w 6(a0),d3 ; 2y
	; Sub zone corners
	sub.w 16(a0),d0
	sub.w 18(a0),d1
	sub.w 16(a0),d2
	sub.w 18(a0),d3
	bsr drawline
	
	move.l	(sp),a0
	move.w 4(a0),d0 ; 2x ; d0=x1  d1=y1  d2=x2  d3=y2
	move.w 6(a0),d1 ; 2y
	move.w 12(a0),d2 ; 4x
	move.w 14(a0),d3 ; 4y
	; Sub zone corners
	sub.w 16(a0),d0
	sub.w 18(a0),d1
	sub.w 16(a0),d2
	sub.w 18(a0),d3
	bsr drawline

	move.l	(sp),a0
	move.w 12(a0),d0 ; 4x ; d0=x1  d1=y1  d2=x2  d3=y2
	move.w 14(a0),d1 ; 4y
	move.w 8(a0),d2 ; 3x
	move.w 10(a0),d3 ; 3y
	; Sub zone corners
	sub.w 16(a0),d0
	sub.w 18(a0),d1
	sub.w 16(a0),d2
	sub.w 18(a0),d3	
	bsr drawline

	move.l	(sp)+,a0
	move.w 8(a0),d0 ; 3x ; d0=x1  d1=y1  d2=x2  d3=y2
	move.w 10(a0),d1 ; 3y
	move.w 0(a0),d2 ; 1x
	move.w 2(a0),d3 ; 1y
	; Sub zone corners
	sub.w 16(a0),d0
	sub.w 18(a0),d1
	sub.w 16(a0),d2
	sub.w 18(a0),d3	
	bsr drawline	

	rts

;---------------------------------------------------------------
; A0, 4 pairs of X Y value, then two pairs of xmin ymin, and xmax ymax
; Erase memory
computeminmax:
	; x is 0 4 8 12
	; Y is 2 6 10 14
	; XMIN=16 YMIN=18
	; XMAX=20 YMAX=22
	; SIZEX(BYTES)=24, SIZEY=26
	move.w #0,20(a0) ; Max set to small value
	move.w #0,22(a0)
	move.w #$7FFF,16(a0) ; Min set to high value
	move.w #$7FFF,18(a0) ; Min set to high value
	move.l a0,a1
	move.w #4-1,d5
.computeminmaxloop
	move.w 0(a1),d0 ; X
	move.w 2(a1),d1 ; Y
	cmp.w 16(a0),d0 ; Compare X to min. Cmp A B , means compare B and A (BLT means B < A)
	bgt .computeminmaxloop1
	move.w d0,16(a0)
.computeminmaxloop1	
	cmp.w 18(a0),d1 ; Compare Y to min
	bgt .computeminmaxloop2
	move.w d1,18(a0)
.computeminmaxloop2	
	; Compare to max
	cmp.w 20(a0),d0 ; Compare X to max. Cmp A B , means compare B and A (bgt means B > A)
	blt .computeminmaxloop3
	move.w d0,20(a0)
.computeminmaxloop3	
	cmp.w 22(a0),d1 ; Compare Y to mac
	blt .computeminmaxloop4
	move.w d1,22(a0)
.computeminmaxloop4	
	add.l #4,a1 ; Next pair of X Y
	; Loop animation
	dbra d5,.computeminmaxloop
	; Check that X is not null
	move.w 20(a0),d0
	cmp.w 16(a0),d0
	bne .xnotnull
	move.w #0,24(a0) ; X diff is 0
	move.w #0,26(a0) ; Set Y to 0, so that nothing will be traced
	rts
.xnotnull	
	; Add x to Xmax to avoid overflow when tracing lines
	add.W #1,20(a0)
	; For x compute best limits for a 16 pixel alignement
	move.w 16(a0),d0 ; For min, floor 16 pixels
	and.w #$fff0,d0
	move.w d0,16(a0)
	move.w 20(a0),d0 ; For max, ceil 16 pixels
	add.w #15,d0
	and.w #$fff0,d0
	move.w d0,20(a0)
	; Compute size
	; x is 0 4 8 12
	; Y is 2 6 10 14
	; XMIN=16 YMIN=18
	; XMAX=20 YMAX=22
	; SIZEX(BYTES)=24, SIZEY=26	
	move.w 20(a0),d0 ; XMAX
	sub.w 16(a0),d0 ; XMIN
	lsr.w #3,d0 ; /8 = size in bytes
	move.w d0,24(a0) ; Store size X
	move.w 22(a0),d0
	sub.w 18(a0),d0
	move.w d0,26(a0)
	
	cmp.w #0,d0
	beq .exit	

	; Erase mem, using blitter
	lea bobzone,a1
	bsr waitblitter
	move.w #0,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	move.l a1,$dff054   ;destination address
	clr.l d0
	clr.l d1
	move.w 26(a0),d0
	lsl.l #6,d0
	move.w 24(a0),d1
	lsr.l #1,d1
	add.l d1,d0
	move.w d0,$dff058 ;blitter operation size	
	
.exit
	rts
		
	
	;----------------------------------------------------------
	; Fill the part where the bob is
fillbob:
	lea	$dff000,a5
	
	bsr waitblitter

	move.w	#$09f0,bltcon0(a5)
	move.w	#$0012,bltcon1(a5)
	move.w	#$ffff,bltafwm(a5)
	move.w	#$ffff,bltalwm(a5)

	move.l	#bobzone,a1 ; dest
;fillines=256
;fillwidth=40
	clr.l d0
	clr.l d1
	move.w	24(a0),d0 ; Width in bytes
	move.w  26(a0),d1; number of lines
	mulu d1,d0
	sub.l #2,d0
	add.l d0, a1
	;Add.l	#[fillines*fillwidth]-2,a0 ; end of screen minus 2 bytes.

	move.l	a1,bltapth(a5)		; Dernier mot
	move.l	a1,bltdpth(a5)
	move.w	#0,bltamod(a5) ; Modulos
	move.w	#0,bltdmod(a5)

	clr.l d0
	clr.l d1
	move.w	26(a0),d0 ; lines . Need *64
	lsl.l #6,d0 ; *64
	move.w  24(a0),d1; Width in bytes	
	lsr.w #1,d1 ; /2
	add.l d1, d0
	
	;move.w	#[fillines*64]+(fillwidth/2),bltsize(a5)
	move.w	d0,bltsize(a5)

	rts
;---------------------------------------------------------- 

;---------------------------------------------------------- 
; linedraw routine for use with filling
; preload:  
; A0 structure of polygons.
; d0=x1  d1=y1  d2=x2  d3=y2  
; Inside code:
; d5=screenwidth  
; a1=address  
; $dff060=screenwidth (word)  bltcmod 
; $dff072=-$8000 (longword)  
; $dff044=-1 (longword)
;---------------------------------------------------------- 
drawline:
	movem.l	d0-d5/a0-a5,-(a7)
	lea	$dff000,a5
	
;	bsr waitblitter

	move.l	#bobzone,a1
	
	cmp.w	d0,d2
	bgt.s	swap_point
	exg	d2,d0
	exg	d3,d1
swap_point:
	cmp.w	d1,d3
	bgt.b	line1
	exg	d0,d2
	exg	d1,d3
line1:
	cmp.w	d1,d3
	beq.b	out_fill	; horizontal

	move.w	d1,d4		; posy depart
	muls	24(a0),d4		; offset de depart

	move.w	d0,d5		; x de depart
	add.l	a1,d4		; d4 pointe sur la ligne de depart
	asr.w	#3,d5		; point/8 -> octets
	add.w	d5,d4		; d4 pointe sur le depart
	moveq	#0,d5
	sub.w	d1,d3		; deltay
	sub.w	d0,d2		; deltax
	bpl.s	line2
	moveq	#1,d5
	neg.w	d2
line2:	
    move.w	d3,d1		; d1=d3=deltay
	add.w	d1,d1		; d1=2*deltay
	cmp.w	d2,d1		;
	dbhi	d3,line3
line3:	
    move.w	d3,d1
	sub.w	d2,d1		; deltax-deltay
	bpl.s	line4
	exg	d2,d3
line4:	
    addx.w	d5,d5
	add.w	d2,d2		; 2*deltax
	move.w	d2,d1
	sub.w	d3,d2
	addx.w	d5,d5
	and.w	#15,d0
	ror.w	#4,d0
	or.w	#$a4a,d0

	bsr waitblitter
	
	move.l	#-$8000,bltbdat(a5)
	move.l	#-1,bltafwm(a5)
	move.w	24(a0),bltcmod(a5) ; Screen width (bytes)	 
	
	move.w	d2,bltaptl(a5)
	sub.w	d3,d2
	movem.w	d1/d2,bltbmod(a5)	
	lsl.w	#6,d3
	addq.w	#2,d3
	move.w	d0,bltcon0(a5)
	move.b	oct(pc,d5.w),bltcon1+1(a5)
	move.l	d4,bltcpth(a5)
	move.l	d4,bltdpth(a5)
	move.w	d3,bltsize(a5)
out_line:
out_fill:
	movem.l	(a7)+,d0-d5/a0-a5
	rts

oct:		
	dc.l	$3431353,$b4b1757   
ft_octs:
	dc.b	%0011011,%0000111,%0001111,%0011111
	dc.b	%0010111,%0001011,%0000011,%0010011

;---------------------------------------------------------- 
copybob:
	;lea screen+(40*100)+16,a0
	;lea data_bob,a1
	;move.w #8,d6 ; height
	;move.w #32,d5 ; width in pixels
	move.w	24(a0),d5 ; Width in bytes
	lsl.w #3,d5 ; Width in pixels
	move.w  26(a0),d6; lines
	; Compute Destination start position (do it before A0 is changed). Result in d1
	; Add X divided by 8 (in bytes)
	; Add screen width * lines
	clr.l d0
	clr.l d1
	; XMIN=16 YMIN=18
	move.w 16(a0),d0
	lsr.w #3,d0 ; pos X min in bytes
	move.w 18(a0),d1
	;mulu #40,d1 ; low res
	mulu #80,d1 ; HR
	add.l d0,d1	
	
	lea bobzone,a1 ; source
	lea screen,a0 ; destination
	add.l d1,a0 ; add start offset
	
	Bsr DisplayBob	
	
	rts
	
;---------------------------------------------------------------
; A0 Dest adresss (Screen). Planes are side by side.
; D0 Dest Decay (0 TO F)
; A1 Source data
; d5 with in bytes
DisplayBob:
	Clr.l	d2

	;Move.l	#screen+402,a0
	;move.w (a1)+,d5 ; Width in pixels (80) means 10 bytes, 5 words
	;move.w (a1)+,d6 ; Height in pixels (62)
	move.w d5,d7
	lsr #3,d7 ; divide by 8 = number of bytes
	
	;move.w #40,d4 ; next line modulo (screen is 40)
	move.w #80,d4 ; next line modulo (screen is 80)
	sub.w d7,d4 ; modulo
	
	clr.l d3
	lsl.l #6,d6 ; *64
	lsr #1,d7 ; Compute width words
	add.l d7,d6 ; bltsize

	Bsr	waitblitter

	; Modulos
	MOVE.W	#0,$DFF064	; MOD A Source
	MOVE.W	#0,$DFF062	; MOD B Mask
	MOVE.W	d4,$DFF060	; MOD C destination as source. Modulox2
	MOVE.W	d4,$DFF066	; MOD D Dest

	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word

	MOVE.L	a1,$DFF050  ; SOURCE A
	MOVE.L	a1,$DFF04C  ; SOURCE B
	MOVE.L	a0,$DFF054	; SOURCE D
	MOVE.L	a0,$DFF048	; SOURCE C (Screen)

	Move.w	#0,$dff042			; Decay source B + flag line trace
	Move.w	#0,d2 ; Decay value
	OR.W	#%0000111111100010,D2
	;             1234         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	
	move.w d6,$dff058 ; BltSize, height*64 , width launch transfert
	;Move.w	#[8*1*64]+3,$dff058 ; BltSize, height*64 , width launch transfert
	rts
	
waitblitter:	
	btst	#14,$dff002 ; Wait blitter to be ready
	Bne	waitblitter
	Rts
;----------------------------------------------------------------
; result in a0, 0 is no free volute	
getfreevolute:
	lea volutesdata,a0
	clr.l d0
.getfreevolutetest:	
	cmp.b #0,0(a0)
	bne .notfree
	rts ; We found one free so return
.notfree:
	; try next one
	add.w #1,d0
	cmp.w #volutemax,d0
	beq .nothingfound
	; Go to next volume
	add.l #datavolutesize,a0
	bra .getfreevolutetest
.nothingfound	
	move.l #0,a0
	rts
;----------------------------------------------------------------	

; *****************************************************************************
; dfm_palette_fade0
; Fade a palette from or to zero
; color sources are interpolated to 0 using mul/div (current step, total step).
; Colors are words and result is copied into same size buffer as input.
; [in]	a0.l : Source palette (list of words)
; [in]	a1.l : Dest palette 
; [in]	d0.w : colors count
; [in]	d5.w : multiplier (Current steps ?)
; [in]	d6.w : decay. divider (number of steps ?) ... 

dfm_palette_fade0:
	move.w	d0,d4 ; backup color count
	sub.w	#1,d4
.calCol:
	clr.w	d0							; dest color
	; blue
	move.w	(a0),d3						; input color
	and.l	#$f,d3
	mulu	d5,d3
	ext.l	d3
	lsr.l	d6,d3
	cmp.w	#$f,d3
	ble.s	.noClampBlue
	move.w	#$f,d3
.noClampBlue	
	move.w	d3,d0
	; green
	move.w	(a0),d3						; input color
	lsr.w	#4,d3
	and.l	#$f,d3
	mulu	d5,d3
	ext.l	d3
	lsr.l	d6,d3
	cmp.w	#$f,d3
	ble.s	.noClampGreen
	move.w	#$f,d3
.noClampGreen
	lsl.w	#4,d3
	or.w	d3,d0
	; red
	move.w	(a0)+,d3						; input color
	lsr.w	#4,d3
	lsr.w	#4,d3
	and.l	#$f,d3
	mulu	d5,d3
	ext.l	d3
	lsr.l	d6,d3
	cmp.w	#$f,d3
	ble.s	.noClampRed
	move.w	#$f,d3
.noClampRed
	lsl.w	#4,d3
	lsl.w	#4,d3
	or.w	d3,d0
	move.w	d0,(a1)+
	dbra	d4,.calCol ; Big loop
	rts		

endcode:

	bss_f
;---------------------------------------------------------------
;	data
;----------------------------------------------------------------	
startdatabss:
volute: ; Volute structure (x=offset)
	; Volute coordinates
	ds.b 1 ; (0) Type. 0=free
	ds.b 1 ; (1) Step
	; Current position (in 128,128 local coordinates 
	ds.w 2 ; (2) X,Y 8:8
	; Last draw points
	ds.w 2 ; (6) X,Y 8:8
	ds.w 2 ; (10) X,Y 8:8
	; Current width 8:8
	ds.w 1 ; (14)
	ds.w 1 ; (16) Width change speed
	; Current lenght 8:8
	ds.w 1 ; (18)
	ds.w 1 ; (20) Lenght change speed
	; Current Angle 8:8
	ds.w 1 ; (22)
	ds.w 1 ; (24) Angle speed
	ds.w 2 ; (26) direction (computed from angle)
	ds.w 2 ; (30) Normal (computed from angle)
	; New points (computed from current point, direction, lenght and normal)
	ds.w 2 ; (34,36) X,Y 8:8
	ds.w 2 ; (38,40) X,Y 8:8
	; Global coordinates (integer values). Added to local -128,128 values.
	ds.w 2 ; (42,44) X Y 
	; Angle speed change (acceleration)
	ds.w 1 ; (46) 8:8
	; Lifetime (in frame)
	ds.w 1 ; 48 (int word)
	; Custom value 1
	ds.w 1 ; 50
	; Table shape (pointeur to data) 0 if unused
	ds.l 1 ; 52 (4 bytes)
	; Custom value 2
	ds.w 1 ; 56
	; Plane 0 or 1 
	ds.b 1 ; 58
	; Radius (Type 4) (use position as center)
	ds.b 1 ; 59
	; Center (absolute) (for type 4)
	;dc.w 0,0 ; 60 (X) 62 (Y)
enddatavolute:
datavolutesize=enddatavolute-volute	
volutesdata:
volutemax=10 ; Number of maximum simultaneous volute
	ds.b datavolutesize*(volutemax+1) ; All is set to zero
;---------------------------------------------------------------
;---------------------------------------------------------- 
; 1 2
; 3 4 ... We trace 1-2 , 2-4, 4-3, 3-1
quaddata:
    ds.w 14
    ds.b 2

;	dc.w 	211,68  ; 0 2
;	dc.w	239,118 ; 4 6
;	dc.w	106,120 ; 8 10
;	dc.w	108,149 ; 12 14
;	; Computed min and max
;	dc.w	0,0 ; 16 18
;	dc.w	0,0 ; 20 22
;	; Size X=bytes, Y=lines
;	dc.W	0,0 ; 24 26
;	; Plane
;	dc.b	0 ; 28
;	dc.b	0 ; 29 dummy

enddatabss:

	data_f
	
; Volutes. 3 volutes are drawn at same time.
SIZESTRUCTURECIRCLES=2+2+2+2+2
	
VolutesCircleDatas: ; Circles infos. Each line is a volute. Radius = $F0F0 is end of volutes
	; radius, width, angle start, angle speed, duration
	dc.w 52,$0380, $4000, $0100, 257 ; Main volute 1 (bigger circle)
	dc.w 31,$0280, $0000, $FF00, 256 ; Main volute 2
	dc.w 9, $0280, $8000, $0100, 256 ; Main volute 3 (smaller circle)
	; 3 circle outer
	dc.w 58,$0400, 90<<8, $0080*2, (95-90)
	dc.w 58,$0400, 213<<8, $0080*2, (254-213)	
	;3 circle inner
	dc.w 46,$0400, 50<<8, $0080*2, (70-50)
	dc.w 46,$0400, 89<<8, $0080*2, (132-89)
	dc.w 46,$0400, 174<<8, $0080*2, (190-174)
	dc.w 46,$0400, 204<<8, $0080*2, (213-204)
	dc.w 46,$0400, 0<<8, $0080*2, (12-0)
	dc.w 46,$0400, 24<<8, $0080*2, (33-24)
	; 2 circle inner 1
	dc.w 31-3,$0300, 118<<8, $0080*2, (156-118)
	dc.w 31-3,$0300, 170<<8, $0080*2, (235-170)
	dc.w 31-3,$0300, 245<<8, $0080*2, ((256+65)-245)
	; 2 circle inner 2
	dc.w 31-3-6,$0300, 131<<8, $0080*2, (140-131)
	dc.w 31-3-6,$0300, 195<<8, $0080*2, (221-195)
	dc.w 31-3-6,$0300, 18<<8, $0080*2, (48-18)
	; 1 circle outer
	dc.w 9+2+4, $0400, 71<<8, $0080*2, (112-71)
	dc.w $F0F0
	
; cos and sin tabs with 512 entries multipled by 512
; 512 values. index 0 to 1024 (10bits). We can use 8:8 and lsr by 6 to get index. 
; means our angle go from 0 to FF:FF in 8:8 (no need to mask can never overflow). Need to be pair, so and last bit
; 9 bits precision.
; 1 is 0100 in 8:8
; here 1 is 511 = 9 bits, need to be shift one bit right
; index 0   is 0
; index 256 is 180
; index 512 is 360

; [BF START]
cos_tab_data:
	dc.w 511,511,511,511,511,511,510,510,509,508
	dc.w 508,507,506,505,504,503,502,500,499,498
	dc.w 496,495,493,491,489,488,486,484,482,479
	dc.w 477,475,473,470,468,465,462,460,457,454
	dc.w 451,448,445,442,439,435,432,429,425,422
	dc.w 418,414,411,407,403,399,395,391,387,383
	dc.w 379,375,370,366,362,357,353,348,343,339
	dc.w 334,329,324,319,314,310,304,299,294,289
	dc.w 284,279,273,268,263,257,252,246,241,235
	dc.w 230,224,218,213,207,201,195,190,184,178
	dc.w 172,166,160,154,148,142,136,130,124,118
	dc.w 112,106,99,93,87,81,75,68,62,56
	dc.w 50,43,37,31,25,18,12,6,0,-7
	dc.w -13,-19,-26,-32,-38,-44,-51,-57,-63,-69
	dc.w -76,-82,-88,-94,-100,-107,-113,-119,-125,-131
	dc.w -137,-143,-149,-155,-161,-167,-173,-179,-185,-191
	dc.w -196,-202,-208,-214,-219,-225,-231,-236,-242,-247
	dc.w -253,-258,-264,-269,-274,-280,-285,-290,-295,-300
	dc.w -305,-311,-315,-320,-325,-330,-335,-340,-344,-349
	dc.w -354,-358,-363,-367,-371,-376,-380,-384,-388,-392
	dc.w -396,-400,-404,-408,-412,-415,-419,-423,-426,-430
	dc.w -433,-436,-440,-443,-446,-449,-452,-455,-458,-461
	dc.w -463,-466,-469,-471,-474,-476,-478,-480,-483,-485
	dc.w -487,-489,-490,-492,-494,-496,-497,-499,-500,-501
	dc.w -503,-504,-505,-506,-507,-508,-509,-509,-510,-511
	dc.w -511,-511,-511,-511,-511,-511,-511,-511,-511,-511
	dc.w -511,-511,-511,-511,-510,-509,-509,-508,-507,-506
	dc.w -505,-504,-503,-501,-500,-499,-497,-496,-494,-492
	dc.w -490,-489,-487,-485,-483,-480,-478,-476,-474,-471
	dc.w -469,-466,-463,-461,-458,-455,-452,-449,-446,-443
	dc.w -440,-436,-433,-430,-426,-423,-419,-415,-412,-408
	dc.w -404,-400,-396,-392,-388,-384,-380,-376,-371,-367
	dc.w -363,-358,-354,-349,-344,-340,-335,-330,-325,-320
	dc.w -315,-311,-305,-300,-295,-290,-285,-280,-274,-269
	dc.w -264,-258,-253,-247,-242,-236,-231,-225,-219,-214
	dc.w -208,-202,-196,-191,-185,-179,-173,-167,-161,-155
	dc.w -149,-143,-137,-131,-125,-119,-113,-107,-100,-94
	dc.w -88,-82,-76,-69,-63,-57,-51,-44,-38,-32
	dc.w -26,-19,-13,-7,-1,6,12,18,25,31
	dc.w 37,43,50,56,62,68,75,81,87,93
	dc.w 99,106,112,118,124,130,136,142,148,154
	dc.w 160,166,172,178,184,190,195,201,207,213
	dc.w 218,224,230,235,241,246,252,257,263,268
	dc.w 273,279,284,289,294,299,304,310,314,319
	dc.w 324,329,334,339,343,348,353,357,362,366
	dc.w 370,375,379,383,387,391,395,399,403,407
	dc.w 411,414,418,422,425,429,432,435,439,442
	dc.w 445,448,451,454,457,460,462,465,468,470
	dc.w 473,475,477,479,482,484,486,488,489,491
	dc.w 493,495,496,498,499,500,502,503,504,505
	dc.w 506,507,508,508,509,510,510,511,511,511
	dc.w 511,511
sin_tab_data:
	dc.w 0,6,12,18,25,31,37,43,50,56
	dc.w 62,68,75,81,87,93,99,106,112,118
	dc.w 124,130,136,142,148,154,160,166,172,178
	dc.w 184,190,195,201,207,213,218,224,230,235
	dc.w 241,246,252,257,263,268,273,279,284,289
	dc.w 294,299,304,310,314,319,324,329,334,339
	dc.w 343,348,353,357,362,366,370,375,379,383
	dc.w 387,391,395,399,403,407,411,414,418,422
	dc.w 425,429,432,435,439,442,445,448,451,454
	dc.w 457,460,462,465,468,470,473,475,477,479
	dc.w 482,484,486,488,489,491,493,495,496,498
	dc.w 499,500,502,503,504,505,506,507,508,508
	dc.w 509,510,510,511,511,511,511,511,511,511
	dc.w 511,511,511,511,510,510,509,508,508,507
	dc.w 506,505,504,503,502,500,499,498,496,495
	dc.w 493,491,489,488,486,484,482,479,477,475
	dc.w 473,470,468,465,462,460,457,454,451,448
	dc.w 445,442,439,435,432,429,425,422,418,414
	dc.w 411,407,403,399,395,391,387,383,379,375
	dc.w 370,366,362,357,353,348,343,339,334,329
	dc.w 324,319,314,310,304,299,294,289,284,279
	dc.w 273,268,263,257,252,246,241,235,230,224
	dc.w 218,213,207,201,195,190,184,178,172,166
	dc.w 160,154,148,142,136,130,124,118,112,106
	dc.w 99,93,87,81,75,68,62,56,50,43
	dc.w 37,31,25,18,12,6,0,-7,-13,-19
	dc.w -26,-32,-38,-44,-51,-57,-63,-69,-76,-82
	dc.w -88,-94,-100,-107,-113,-119,-125,-131,-137,-143
	dc.w -149,-155,-161,-167,-173,-179,-185,-191,-196,-202
	dc.w -208,-214,-219,-225,-231,-236,-242,-247,-253,-258
	dc.w -264,-269,-274,-280,-285,-290,-295,-300,-305,-311
	dc.w -315,-320,-325,-330,-335,-340,-344,-349,-354,-358
	dc.w -363,-367,-371,-376,-380,-384,-388,-392,-396,-400
	dc.w -404,-408,-412,-415,-419,-423,-426,-430,-433,-436
	dc.w -440,-443,-446,-449,-452,-455,-458,-461,-463,-466
	dc.w -469,-471,-474,-476,-478,-480,-483,-485,-487,-489
	dc.w -490,-492,-494,-496,-497,-499,-500,-501,-503,-504
	dc.w -505,-506,-507,-508,-509,-509,-510,-511,-511,-511
	dc.w -511,-511,-511,-511,-511,-511,-511,-511,-511,-511
	dc.w -511,-511,-510,-509,-509,-508,-507,-506,-505,-504
	dc.w -503,-501,-500,-499,-497,-496,-494,-492,-490,-489
	dc.w -487,-485,-483,-480,-478,-476,-474,-471,-469,-466
	dc.w -463,-461,-458,-455,-452,-449,-446,-443,-440,-436
	dc.w -433,-430,-426,-423,-419,-415,-412,-408,-404,-400
	dc.w -396,-392,-388,-384,-380,-376,-371,-367,-363,-358
	dc.w -354,-349,-344,-340,-335,-330,-325,-320,-316,-311
	dc.w -306,-300,-295,-290,-285,-280,-274,-269,-264,-258
	dc.w -253,-247,-242,-236,-231,-225,-219,-214,-208,-202
	dc.w -196,-191,-185,-179,-173,-167,-161,-155,-149,-143
	dc.w -137,-131,-125,-119,-113,-107,-100,-94,-88,-82
	dc.w -76,-69,-63,-57,-51,-44,-38,-32,-26,-19
	dc.w -13,-7
;---------------------------------------------------------------

	even
    
exitNow:
    dc.w 0	

	bss_c

screen:
	ds.b 80*SCREENHEIGHT ; 1 bitplanes. Will be copied and erase with CPU
screenend:
bobzone:
	ds.b 1024 ; This can be reduced to the size of the biggest block (do it at end)
	
dmaconr=2
bltddat=$76
bltadat=$74
bltbdat=$72
bltcdat=$70
bltafwm=$44
bltalwm=$46
bltamod=$64
bltbmod=$62
bltcmod=$60
bltdmod=$66
bltcon0=$40
bltcon1=$42
bltsize=$58
bltapth=$50
bltaptl=$52
bltbpth=$4c
bltcpth=$48
bltdpth=$54
