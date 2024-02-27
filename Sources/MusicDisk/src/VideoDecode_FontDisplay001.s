;-----------------------------------------------------------------
; display font
; oriens
;-----------------------------------------------------------------

;---------------------------------------------------------------
; Display Font
; Font binary format:	
;// 0/ Global parameters infos. Size = 4 bytes
;//    Font base size (1 byte)
;//    font Line height
;//    Table2 size
;// 1/ TABLE1: Table of all ascii characters : Table of 256 byte value. (Size 256 bytes)
;//  0 means "no character in font", else there is an id of "character structure"
;// Size is 128x2 (256 bytes). (Check if we need 256 values here, I guess no)
;// 2/ TABLE2: Character structure table (6 * number entries)
;//  For each existing character in font, we store values.
;//  Offset of data bob since first bob (word)
;//  XAdvance (byte)
;//  XOffset (byte) can be negative
;//  Yoffset (byte) can be negative
;//  Dummy (byte)
;// 3/ TABLE3: Data for BOB. (strandard structure of bob, see ConvertBob util).
;//  Word : width in pixel
;//  Word : height in pixels
;//  data (line by line), with 16 pixel right margin

;Debug:
;	dc.w	$A5A5
;Debug2:	
;	dc.w	0
DisplayTextPlaneWidth:
	dc.w	40
	
FontBase:
	dc.w	0
FontLineHeight:
	dc.w	0
FontAsciiTable: ; Table 1
	dc.l	0
FontCharTable:	; Table 2
	dc.l	0
FontBobTable:	; Table 3
	dc.l	0
XAdvance: ; Written by each character when it is displayed (kind of return value)
	dc.w	0 ; Value change for each character
TextStartX:
	dc.w	0 ; Start value of text
;---------------------------------------------------------------
; a0 adress of Font binary file
; Set all pointers and values	
Initfont:
	clr.l d0
	move.b (a0)+,d0
	move.w d0,FontBase
	move.b (a0)+,d0
	mulu #2,d0
	divs #3,d0 ; use 75% of line height
	move.w d0,FontLineHeight
	clr.l d0
	move.w (a0)+,d0 ; Size of table 2.
	move.l a0,FontAsciiTable
	add.l #128,a0
	move.l a0,FontCharTable
	add.l d0,a0
	move.l a0,FontBobTable
	rts
;---------------------------------------------------------------
; a0 text
; d0 X
; d1 Y	
DisplayText:
	; Init Font pointers (do once only)
	move.w d0,TextStartX	 ; Save value
	; Display a letter
.DisplayTextLoop:
	clr.l d2
	move.b (a0)+,d2 ; Letter
	bsr DisplayLetter
	add.w XAdvance,d0
	cmp.b #$FF,(a0)
	beq .endtext
	cmp.b #$00,(a0)
	bne .DisplayTextLoop	
	add.w FontLineHeight,d1
	move.w TextStartX,d0
	bra .DisplayTextLoop
.endtext:	
	rts
	
;---------------------------------------------------------------	
DisplayTextCentered:
	move.l d0,-(sp)
	bsr FontGetTextSize
	move.w d0,d2
	move.l (sp)+,d0
	lsr.w #1,d2
	sub.w d2,d0
	Bsr DisplayText
	rts
;---------------------------------------------------------------
; A0 is ascii text
; d0 wil get size	
FontGetTextSize:
	move.l a0,-(sp)
	clr.l d0
.DisplayTextLoop:
	clr.l d2
	move.b (a0)+,d2 ; Letter
	move.l FontAsciiTable,a1
	move.b (a1,d2.w),d2 ; Index of structure data
	cmp.b #$FF,d2 ; Letter is not in our table
	beq .unknownletter
	mulu #6,d2
	move.l FontCharTable,a2
	add.l d2,a2 ; a0 is structure
	; 0 offset (word)
	; 2 is Xadvance (byte)
	; 3 is XOffset (byte)
	; 4 is Y Offset (byte)
	; 5 is dummy (byte)
	clr.l d3
	move.b 2(a2),d3
	add.w d3,d0
.unknownletter
	cmp.b #$0,(a0) ; endline
	beq .endtext
	cmp.b #$FF,(a0) ; skip line, so we stop
	beq .endtext	
	bra .DisplayTextLoop
.endtext:	
	move.l (sp)+,a0
	rts	
;---------------------------------------------------------------
; d0 x
; d1 y	
; d2 ascii code of letter	
DisplayLetter:
	movem.l	d0-d6/a0-a6,-(sp)
	
	; Sub base to Y
	sub.w FontBase,d1

	move.l FontAsciiTable,a0
	move.b (a0,d2.w),d2 ; Index of structure data
	
	cmp.b #$FF,d2 ; Letter is not in our table
	beq .unknownletter
	
	mulu #6,d2
	move.l FontCharTable,a0
	add.l d2,a0 ; a0 is structure
	move.w (a0),d2 ; d0 is offset in bob table
	; 0 offset (word)
	; 2 is Xadvance (byte)
	; 3 is XOffset (byte)
	; 4 is Y Offset (byte)
	; 5 is dummy (byte)
	clr.l d3
	move.b 2(a0),d3
	move.w d3,XAdvance ; Save to global, this will be used after this fonction return
	move.b 3(a0),d3
	ext.w d3
	add.w d3,d0 ; Add XOffset
	move.b 4(a0),d3
	ext.w d3
	add.w d3,d1 ; Add YOffset
	
	move.l FontBobTable,a1
	add.l d2,a1 ; a0 is adress of BOB
	
	;move.w (a1),Debug
	;move.w 2(a1),Debug2
	
;	Lea plans1+40*4,a0 ; d0 and d1 already filled
;	cmp.l #COPP2,copper_work
;	bne .nochange
;	Lea plans2+40*4,a0 ; d0 and d1 already filled
;.nochange	

	move.l fontplanebase,a0

	Bsr DisplayBobWithDecay
	
.unknownletter
	movem.l	(sp)+,d0-d6/a0-a6	
	rts

;---------------------------------------------------------------
; A0 Dest adresss (Screen). start of screen
; D0 X
; d1 Y
; A1 Source data
; DisplayTextPlaneWidth is width of screen (of one line)
DisplayBobWithDecay:
	; Compute dest adress
	move.w DisplayTextPlaneWidth,d4 ; Size of plane (byte, width) can be anything
	
	clr.l d2
	clr.l d6
	clr.l d7
	move.w d0,d2
	and.w #$000F,d0 ; Decay
	and.w #$FFF0,d2 ; Pos X, modulo 16
	lsr.w #3,d2
	add.l d2,a0
	mulu d4,d1
	add.l d1,a0 ; a0 is dest adress

	move.w (a1)+,d5
	move.w (a1)+,d6
	move.w d5,d7
	lsr.w #3,d7 ; divide by 8 = number of bytes
	sub.w d7,d4 ; modulo
	lsl.l #6,d6 ; *64
	lsr.w #1,d7 ; Compute width words
	add.l d7,d6 ; bltsize
	; Modulos
	Bsr	waitblitter	
	MOVE.W	#0,$DFF064	; MOD A Source
	MOVE.W	#0,$DFF062	; MOD B Mask
	MOVE.W	d4,$DFF060	; MOD C destination as source. Modulox2
	MOVE.W	d4,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	a1,$DFF050  ; SOURCE A
	MOVE.L	a1,$DFF04C  ; SOURCE B
	MOVE.L	a0,$DFF054	; DEST   D (Screen)
	MOVE.L	a0,$DFF048	; SOURCE C (Screen)
	lsl.w #8,D0
	lsl.w #4,D0	
	Move.w	d0,$dff042			; Decay source B + flag line trace
	Move.w	d0,d2 ; Decay value
	OR.W	#%0000111111100010,D2
	;             1234         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	move.w d6,$dff058 ; BltSize, height*64 , width launch transfert
	Rts	

; ---------------------------------------------------
; Display font (specific for scrolling)
; ---------------------------------------------------
;Debug:
;	dc.w	$A5A5
;Debug2:	
;	dc.w	0
DisplayTextPlaneWidthScroll:
	dc.w	46
	
DisplayColors:
    dc.w    0 ; 0 is default (white), 1 is alternate color
    
    
FontBaseScroll:
	dc.w	0
FontLineHeightScroll:
	dc.w	0
FontAsciiTableScroll: ; Table 1
	dc.l	0
FontCharTableScroll:	; Table 2
	dc.l	0
FontBobTableScroll:	; Table 3
	dc.l	0
XAdvanceScroll: ; Written by each character when it is displayed (kind of return value)
	dc.w	0   ; Value change for each character
TextStartXScroll:
	dc.w	0   ; Start value of text
;---------------------------------------------------------------
; a0 adress of Font binary file
; Set all pointers and values	
InitfontScroll:
	clr.l d0
	move.b (a0)+,d0
	move.w d0,FontBaseScroll
	move.b (a0)+,d0
	mulu #2,d0
	divs #3,d0 ; use 75% of line height
	move.w d0,FontLineHeightScroll
	clr.l d0
	move.w (a0)+,d0 ; Size of table 2.
	move.l a0,FontAsciiTableScroll
	add.l #128,a0
	move.l a0,FontCharTableScroll
	add.l d0,a0
	move.l a0,FontBobTableScroll
	rts
;---------------------------------------------------------------
; DisplayTextScroll
; a0 text
; d0 X. X posiion
; d1 Y	Y position (bottom of letter)
;DisplayTextScroll:
;	; Init Font pointers (do once only)
;	move.w d0,TextStartXScroll	 ; Save value
;	; Display a letter
;;.DisplayTextLoop:
;	clr.l d2
;	move.b (a0)+,d2 ; Letter
;	bsr DisplayLetterScroll
;	add.w XAdvanceScroll,d0
;	;cmp.b #$FF,(a0)
;	;beq .endtext
;	cmp.b #$00,(a0)
;	bne .DisplayTextLoop	
;	add.w FontLineHeightScroll,d1
;	move.w TextStartXScroll,d0
;	;bra .DisplayTextLoop
;.endtext:	
;	rts
	
;---------------------------------------------------------------	
;DisplayTextCenteredScroll:
;	move.l d0,-(sp)
;	bsr FontGetTextSizeScroll
;	move.w d0,d2
;	move.l (sp)+,d0
;	lsr.w #1,d2
;	sub.w d2,d0
;	Bsr DisplayTextScroll
;	rts
;---------------------------------------------------------------
; A0 is ascii text
; d0 wil get size	
FontGetTextSizeScroll:
	move.l a0,-(sp)
	clr.l d0
.DisplayTextLoop:
	clr.l d2
	move.b (a0)+,d2 ; Letter
	move.l FontAsciiTableScroll,a1
	move.b (a1,d2.w),d2 ; Index of structure data
	cmp.b #$FF,d2 ; Letter is not in our table
	beq .unknownletter
	mulu #6,d2
	move.l FontCharTableScroll,a2
	add.l d2,a2 ; a0 is structure
	; 0 offset (word)
	; 2 is Xadvance (byte)
	; 3 is XOffset (byte)
	; 4 is Y Offset (byte)
	; 5 is dummy (byte)
	clr.l d3
	move.b 2(a2),d3
	add.w d3,d0
.unknownletter
	cmp.b #$0,(a0) ; endline
	beq .endtext
	cmp.b #$FF,(a0) ; skip line, so we stop
	beq .endtext	
	bra .DisplayTextLoop
.endtext:	
	move.l (sp)+,a0
	rts	
;---------------------------------------------------------------
; d0 x
; d1 y	
; d2 ascii code of letter	
DisplayLetterScroll:
	movem.l	d0-d6/a0-a6,-(sp)
    
    moveq #0,d3
    moveq #0,d4
    moveq #0,d5
    moveq #0,d6
    move.l #0,a0
    move.l #0,a1
    move.l #0,a2
    move.l #0,a3
    move.l #0,a4
    move.l #0,a5
    move.l #0,a6
    
    ;move.b d2,$100
	
	; Sub base to Y
	sub.w FontBaseScroll,d1

	move.l FontAsciiTableScroll,a0
	move.b (a0,d2.w),d2 ; Index of structure data
	
	cmp.b #$FF,d2 ; Letter is not in our table
	beq .unknownletter

	mulu #6,d2
	move.l FontCharTableScroll,a0
	add.l d2,a0 ; a0 is structure
	move.w (a0),d2 ; d0 is offset in bob table
	; 0 offset (word)
	; 2 is Xadvance (byte)
	; 3 is XOffset (byte)
	; 4 is Y Offset (byte)
	; 5 is dummy (byte)
    
	clr.l d3
	move.b 2(a0),d3
	move.w d3,XAdvanceScroll ; Width of letter. Save to global, this will be used after this fonction return
	
    ;move.b 3(a0),d3
	;ext.w d3
	;add.w d3,d0 ; Add XOffset. This is offset of current letter. 0 to 15.
    ;add.w d3,XAdvanceScroll ; for next letter.
	
    clr.l d3
    move.b 4(a0),d3
	ext.w d3
	add.w d3,d1 ; Add YOffset
    ;clr.l d1 ; debug
	
	move.l FontBobTableScroll,a1
	add.l d2,a1 ; a1 is adress of BOB
	
	;move.w (a1),Debug
	;move.w 2(a1),Debug2
	
;	Lea plans1+40*4,a0 ; d0 and d1 already filled
;	cmp.l #COPP2,copper_work
;	bne .nochange
;	Lea plans2+40*4,a0 ; d0 and d1 already filled
;.nochange	

	move.l fontplanebaseScroll,a0 ; dest

	Bsr DisplayBobWithDecayScrollCPU ; Do not use blitter, so using only fast mem
	
.unknownletter
	movem.l	(sp)+,d0-d6/a0-a6	
	rts

;---------------------------------------------------------------
; d2 ascii code of letter	
; return D0
GetLetterXOffsetScroll:
	movem.l	d0-d6/a0-a6,-(sp)
	move.l FontAsciiTableScroll,a0
	move.b (a0,d2.w),d2 ; Index of structure data
	cmp.b #$FF,d2 ; Letter is not in our table
	beq .unknownletter
	mulu #6,d2
	move.l FontCharTableScroll,a0
	add.l d2,a0 ; a0 is structure
	; 0 offset (word)
	; 2 is Xadvance (byte)
	; 3 is XOffset (byte)
	; 4 is Y Offset (byte)
	; 5 is dummy (byte)
	clr.l d3
	move.b 3(a0),d3
	ext.w d3
	move.w d3,d0 ; Get XOffset. This is offset of current letter (each letter can have its own X offset). 0 to 15.
    move.w d0,$102
.unknownletter
	movem.l	(sp)+,d0-d6/a0-a6	
	rts

;---------------------------------------------------------------
; A0 Dest adresss (Screen). start of screen
; D0 X
; d1 Y
; A1 Source data
; DisplayTextPlaneWidth is width of screen (of one line)
DisplayBobWithDecayScroll:

	; Compute dest adress
	move.w DisplayTextPlaneWidthScroll,d4 ; Size of plane (byte, width) can be anything. 46 here
	
	clr.l d2
	clr.l d6
	clr.l d7
	move.w d0,d2
	and.w #$000F,d0 ; Decay
	and.w #$FFF0,d2 ; Pos X, modulo 16
	lsr.w #3,d2
	add.l d2,a0
	mulu d4,d1
    add.l d1,a0 ; a0 is dest adress
    add.l d1,a0 ; need to add 3 time (coz 3 bitplanes side by side)
	add.l d1,a0 ; a0 is dest adress

	move.w (a1)+,d5 ; bob width
	move.w (a1)+,d6 ; bob height
	
    ; Debug, Rought CPU version
    ; Display only 32 bytes versions
    ; a1 data source, a0 plan dest 
;    cmp.w #32,d5
;    beq .continue
;    rts
;.continue
;    sub.w #1,d6
;loopcpu:
;    ;move.b (a1)+,(a0)+
;    ;move.b (a1)+,(a0)+
;    ;move.b (a1)+,(a0)+
;    ;move.b (a1)+,(a0)+
;    move.b #$55,(a0)
;    move.b #$55,1(a0)
;    move.b #$55,2(a0)
;    move.b #$55,3(a0)    
;    add.l #46,a0 ; next plane (or next line)
; 
;    dbra d6,loopcpu
;    rts
    
    move.w d5,d7
	lsr.w #3,d7 ; divide by 8 = number of bytes
	sub.w d7,d4 ; modulo
	lsl.l #6,d6 ; *64
	lsr.w #1,d7 ; Compute width words
	add.l d7,d6 ; bltsize
    
	; Modulos
	Bsr	waitblitter	
	MOVE.W	#0,$DFF064	; MOD A Source
	MOVE.W	#0,$DFF062	; MOD B Mask
	MOVE.W	d4,$DFF060	; MOD C destination as source. Modulox2
	MOVE.W	d4,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	a1,$DFF050  ; SOURCE A
	MOVE.L	a1,$DFF04C  ; SOURCE B
	MOVE.L	a0,$DFF054	; DEST   D (Screen)
	MOVE.L	a0,$DFF048	; SOURCE C (Screen)
	lsl.w #8,D0
	lsl.w #4,D0	
	Move.w	d0,$dff042			; Decay source B + flag line trace
	Move.w	d0,d2 ; Decay value
	OR.W	#%0000111111100010,D2
	;             1234         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	move.w d6,$dff058 ; BltSize, height*64 , width launch transfert
	rts
    
;---------------------------------------------------------------
; A0 Dest adresss (Screen). start of screen
; D0 X
; d1 Y
; A1 Source data
; DisplayTextPlaneWidth is width of screen (of one line)
; DECAY is not supported so should always be 0
DisplayBobWithDecayScrollCPU:

	; Compute dest adress
    moveq #0,d4
	move.w DisplayTextPlaneWidthScroll,d4 ; Size of plane (byte, width) can be anything. 46 here
	
	moveq #0,d2
	moveq #0,d6
	moveq #0,d7
	move.w d0,d2 ; X
	;and.w #$000F,d0 ; Decay ==> Should always be zero
	;and.w #$FFF0,d2 ; Pos X, modulo 16
	lsr.w #3,d2 ; /8
	add.l d2,a0 ; Get destination.
	
    mulu.w d4,d1 ; Add Y (width of screen *3)
    add.l d1,a0 
    add.l d1,a0 
    add.l d1,a0
	add.l d1,a0 ; a0 is dest adress

	move.w (a1)+,d5 ; bob width
	move.w (a1)+,d6 ; bob height
	
    ; Debug, Rought CPU version
    ; Display only 32 bytes versions
    ; a1 data source, a0 plan dest 
    ;move.w d0,$104 ; decay
    
;    cmp.w #32,d5 ; Width is 32 ?
;    beq do32pixelsversion  ; All letter seem to be 32 pixels (for music disk)
    ;move.w d5,$102
;    rts

    cmp.w #0,DisplayColors ; if 1, then display alternate colors
    bne do32pixelsversion_coloralternate

    ; else normal colors (white)

    clr.l d0
    clr.l d1
    clr.l d2

    divu.w #3,d6 ; Nombre of lines (not line * plans)

    sub.w #4,d4 ; modulo for next line
    sub.w #1,d6

    clr.l d3 ; plane 4 is 0
    
    jsr	waitblitter ; As we are writing in the same buffer, we need to do not when SCROLLING is done.

    ; 4 planes version, the data only have 3 planes.
    ; 32 pixels is 2 words. 4 bytes.
.loopcpu0:
    move.w (a1)+,d0
    swap d0
    move.w (a1)+,d0
    swap d0
    
    move.w (a1)+,d1
    swap d1
    move.w (a1)+,d1
    swap d1
   
    move.w (a1)+,d2
    swap d2
    move.w (a1)+,d2
    swap d2

    ; d3 is "mask" for plane 4. here 0

    ; Write to planes
    move.w d0,(a0)
    move.w d1,46(a0)
    move.w d2,(46*2)(a0)
    move.w d3,(46*3)(a0)
    swap d0
    swap d1
    swap d2
    swap d3
    move.w d0,2(a0)
    move.w d1,(46+2)(a0)
    move.w d2,((46*2)+2)(a0)
    move.w d3,((46*3)+2)(a0)

    add.l #46*4,a0 ; Next line.

    dbra d6,.loopcpu0
    rts

do32pixelsversion_coloralternate:
    clr.l d0
    clr.l d1
    clr.l d2

    divu.w #3,d6 ; Nombre of lines (not line * plans)

    sub.w #4,d4 ; modulo for next line
    sub.w #1,d6
    
    jsr	waitblitter ; As we are writing in the same buffer, we need to do not when SCROLLING is done.
    ; TODO delay this to do it at another time.

; 3 planes version    
;.loopcpu:
;    move.w (a1)+,(a0)+
;    move.w (a1)+,(a0)+
;    add.l d4,a0 ; next plane (or next line)
;    dbra d6,.loopcpu

; 4 planes version, the data only have 3 planes.
; 32 pixels is 2 words. 4 bytes.
.loopcpu:
    move.w (a1)+,d0
    swap d0
    move.w (a1)+,d0
    swap d0
    
    move.w (a1)+,d1
    swap d1
    move.w (a1)+,d1
    swap d1
   
    move.w (a1)+,d2
    swap d2
    move.w (a1)+,d2
    swap d2

    move.l d0,d3
    or.l d1,d3
    or.l d2,d3 ; d3 is "mask" for plane 4.

    ; Write to planes
    move.w d0,(a0)
    move.w d1,46(a0)
    move.w d2,(46*2)(a0)
    move.w d3,(46*3)(a0)
    swap d0
    swap d1
    swap d2
    swap d3
    move.w d0,2(a0)
    move.w d1,(46+2)(a0)
    move.w d2,((46*2)+2)(a0)
    move.w d3,((46*3)+2)(a0)

    add.l #46*4,a0 ; Next line.

    dbra d6,.loopcpu
    
    rts
  
    
