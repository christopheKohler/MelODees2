; --------------------------------------------------------------------
;
; Music Disk - Intro
;
; Fx1 : 3d letters
; Fx2 : Presents
; Fx3 : Rotating letter, scrolling
; Fx4 : Logo
;
; Oriens January 2024
;
; --------------------------------------------------------------------

	code

	include "../../ldos/kernel.inc"
    
    ; Clean mem
    lea BufferChips,a0 ; must be aligned 4 bytes
    move.l #((endfx1chip-BufferChips)/16)-1,d0
.cleanmem:
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+    
    dbra d0,.cleanmem
    
    ; No planes for start
    lea Planes87,a0
    move.w #($0200|(0<<12)),2(a0) ; 0 planes
    bsr Fx2_DisableCenterGradient
    
    bsr SetSpriteInCopper
  
    ; install interrupt handler
    bsr		pollVSync		
    move.w	#(1<<5),$dff09a			; disable VBL
    move.w	#(1<<5),$dff09c
    lea		copper,a0
    bsr		copperInstall
    move.l	#InterruptLevel3,$6c.w		;ma vbl
    move.w	#$8000|(1<<5)| (1<<6)|(1<<7)|(1<<8)|(1<<10),$dff096	; Sprite, Blitter, Copper, Bitplans, Nasty Bit
    move.w	#$c000|(1<<4),$dff09a		;interruption copper

    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_MUSIC_START(a6)

    ; Set Background effect
    move.w #0,VBLCount
    move.w #5,StepCurrent ; Launch IRQ FX5 (Fade)
    
    move.w #50,d0
    bsr WaitFrames ; Wait 1 second (music fade)

    ;bra DEBUGFX3
    ;bra DEBUGFX2
    ;bra DEBUGFX4
    
    ; -- DEBUG, go to next effect
;    move.l	(LDOS_BASE).w,a6
;    jsr		LDOS_MUSIC_STOP(a6)
;    move.w #100,d0
;    bsr WaitFrames ; Wait 2 second (music fade out)    
;    ; TODO Unalloc Music space
;    move.l	(LDOS_BASE).w,a6
;    jsr		LDOS_FREE_MEM_MUSIC(a6)    
;    move.l	(LDOS_BASE).w,a6
;    jsr		LDOS_PRELOAD_NEXT_FX(a6)
;    ; we now can terminate this part by RTS. Next part will execute a start music command
;    rts         ; end of this part
    ; -- end Debug

    ; -- FX1 ---------------------------------------------------
    ; Init FX1
    move.w #1,StepCurrent
    Bsr Fx1_Init
Loop1: ; Loop FX1
    Bsr Fx1_Loop
    bsr DotAnimation ; Change object position
    cmp.w #1,StepCurrent ; Stop fx now ? (else will fail at synchro)
    bne nextFX1
	; -- Swap screens
	; Work -> Displayed 
	; WorkNext -> Work
	; Displayed -> WorkNext
	move.l ScreenDisplayed,a0
	move.l ScreenWork,a1
	move.l ScreenWorkNext,a2
	move.l a1,ScreenDisplayed	
	move.l a2,ScreenWork
	move.l a0,ScreenWorkNext
	move.b #1,ScreenAskSwap ; Ask swap buffer (in IRQ)
	move.b #0,ScreenSwapDone
WaitNextFrame:	
	cmp.b #1,ScreenSwapDone ; Wait for IRQ to be executed
	bne WaitNextFrame
    move.b #0,ScreenSwapDone
    ; Do we need to copy the buffer ?
    cmp.w #0,AskForCopyLetter
    beq .nocopybuffer
    bsr Fx1_CopyBuffers
.nocopybuffer
    cmp.w #1,StepCurrent
    beq Loop1 ; endless loop
nextFX1:

    move.w #50*5,d0
    bsr WaitFrames ; Wait

DEBUGFX2:
    ; -- FX2 ---------------------------------------------------
    ; Init FX2
    move.w #2,StepCurrent
    Bsr Fx2_Init
Loop2:
    Bsr Fx2_Loop
    cmp.w #2,StepCurrent
    beq Loop2 ; endless loop

    move.w #50*3,d0
    bsr WaitFrames ; Wait


DEBUGFX3:
    ; ----------------------------------------------------------
    ; FX3
    ;move.w #$3,$100
    move.w #3,StepCurrent
    bsr Fx3_Init
Loop3:
    bsr Fx3_Loop
    cmp.w #3,StepCurrent
    beq Loop3 ; endless loop
    ; -------------------------------------------
DEBUGFX4:
    ; ----------------------------------------------------------
    ; FX4
    move.w #4,StepCurrent
    bsr Fx4_Init
Loop4:
    bsr Fx4_Loop
    cmp.w #4,StepCurrent
    beq Loop4 ; endless loop
    ; -------------------------------------------
    
    ;move.w #$ff,$104
    
    ; Fade out colors. (StepCurrent = 6)
    move.w #0,VBLCount
    ;move.w #100,d0
    ;bsr WaitFrames ; Wait 2 second (music fade out)  
    
    ; Stop with fade
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_STOP(a6)  ; Stop with fade
    move.w #10,d0
    bsr WaitFrames ; Wait a bit (music fade out)       
    ; Unalloc Music space
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_FREE_MEM_MUSIC(a6)    
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_PRELOAD_NEXT_FX(a6)
    ; we now can terminate this part by RTS. Next part will execute a start music command
    rts ; End main loop, end of FX

StepCurrent:
    dc.w    0 ; 1 = Fx 1, 2 = Fx 2, 3 , 4
AskForCopyLetter: ; Ask to copy letter to tripple buffer
    dc.w    0 ; 0=inactive, 1 copy R, 2, 3
VBLCount:
    dc.w 0
WaitCount:
    dc.w 0    

WaitFrames:
    move.w #0,WaitCount
.wait:
    cmp.w WaitCount,d0
    bpl .wait
    rts

; ------------------------------------------------------		
InterruptLevel3:
    btst	#4,$dff01f
    beq.s	.intError
    ;IFNE	PROFILING
    ;move.w	#7,copPal+2
    ;ENDC
    movem.l	d0-a6,-(a7)

    add.w #1,VBLCount ; Count 3 frames for FX3
    add.w #1,WaitCount ; Used to wait
    
    bsr BackgroundAnimation ; All mangement of background colors

    cmp.w #1,StepCurrent
    bne .nostep1
    bsr Fx1_Irq
    bra .Irq_end
.nostep1:
    cmp.w #2,StepCurrent
    bne .nostep2
    bsr Fx2_Irq
    bra .Irq_end
.nostep2:
    cmp.w #3,StepCurrent
    bne .nostep3
    bsr Fx3_Irq
    bra .Irq_end
.nostep3:
    cmp.w #4,StepCurrent
    bne .nostep4
    bsr Fx4_Irq
    bra .Irq_end
.nostep4:
    cmp.w #5,StepCurrent
    bne .nostep5
    bsr Fx5_Irq
    bra .Irq_end
.nostep5:
    cmp.w #6,StepCurrent
    bne .nostep6
    bsr Fx6_Irq
    bra .Irq_end
.nostep6:

.Irq_end:

    ; Get music trigger value
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_MUSIC_GET_TRIGGER(a6) ; Trigger value in d0. Trigger is internally erased
   
    cmp.w #0,d0
    beq .notrigger
    ;bsr BackgroundAnimation_TriggerFrontAnim
    bsr BackgroundAnimation_TriggerBackAnim
    ;add.b #1,$100
.notrigger   

    cmp.w #0,LogoRSEFlash
    beq .noLogoRSEFlash
    bsr FX1_DoRSEFlash
.noLogoRSEFlash:  
    
    movem.l	(a7)+,d0-a6

    ;IFNE	PROFILING
    ;move.w	#0,$dff180
    ;ENDC
.none:		
    move.w	#1<<4,$dff09c		;clear copper interrupt bit
    move.w	#1<<4,$dff09c		;clear VBL interrupt bit
    nop
    rte
    
    ; -----------------------------------------------------------------
			
.intError:	
    illegal
			
pollVSync:	
    btst	#0,$dff005
    beq.s	pollVSync
.wdown:		
    btst	#0,$dff005
	bne.s	.wdown
	rts

copperInstall:
    move.w	#(1<<7),$dff096		; swith OFF copper DMA
    move.l	a0,$dff080
    move.w	#($8000|(1<<7)),$dff096
    rts

setPalette:	    
    lea		.palette(pc),a0
    lea		copPal,a1
    moveq	#8-1,d0
.Loop2:	        
    move.w	(a0)+,d1
    move.w	d1,2(a1)
    addq #4,a1
    dbf	d0,.Loop2
    rts

.palette:		
    dc.w	$000,$ddd,$ddd,$fff,$747,$605,$323,$555

SetBackPalette:
    lea BackPalette,a0
    lea ZONE1_PAL,a1
    move.w (a0),6(a1)
    lea ZONE1b_PAL,a1
    move.w (a0)+,6(a1)    
    lea ZONE2_PAL,a1
    move.w (a0),6(a1)
    lea ZONE2b_PAL,a1
    move.w (a0)+,6(a1)    
    lea ZONE3_PAL,a1
    move.w (a0),6(a1)
    lea ZONE3b_PAL,a1
    move.w (a0)+,6(a1)   
    lea ZONE4_PAL,a1
    move.w (a0),6(a1)
    lea ZONE4b_PAL,a1
    move.w (a0)+,6(a1)    
    lea ZONE5_PAL,a1
    move.w (a0),6(a1)
    lea ZONE5b_PAL,a1
    move.w (a0)+,6(a1)    
    lea ZONE6_PAL,a1
    move.w (a0),6(a1)
    lea ZONE6b_PAL,a1
    move.w (a0)+,6(a1)
    ; Central part
    lea ZONE7_PAL,a1
    move.w (a0)+,6(a1)
    rts
; This palette have the flash inside
BackPalette: ; Palette for background ; 6 zones + central. (work palette)
    dc.w $000,$000,$000,$000,$000,$000,$000
; This is the current refence palette, can be a result of a fade    
BackPaletteOriginal: ; Palette for background. Bright. ; 6 zones + central.
    dc.w $000,$000,$000,$000,$000,$000,$000
BackPaletteScrollPalette:
    dc.w $000,$000,$000,$000,$000,$000,$000 ; Here copy the palette to scroll to BackPaletteOriginal
; These are all fixed palettes
BackPaletteOriginal_Bright:
    dc.w $AAD,$99D,$88C,$77B,$77A,$669,$558 
BackPaletteOriginal_Dark:
    dc.w $559,$558,$447,$446,$335,$224,$001
BackPaletteOriginal_Dark2: ; End logo
    dc.w $667,$556,$546,$445,$334,$223,$000    
BackPaletteOriginal_DarkFull:
    dc.w $000,$000,$000,$000,$000,$000,$000 


BackGroundCounterBackToFrontAnim:
    dc.w 0 ; 0 is inactive.
BackGroundCounterFrontToBackAnim:
    dc.w 0 ; 0 is inactive. 
BackGroundCounterScrollPalette:
    dc.w 0 ; 0 is inactive, else 7*4 steps (copy 7 colors)


BACKCOUNTERANIM = 24

; Manage the whole background
; Also check if we switch palette
BackgroundAnimation:

    bsr BackgroundAnimation_CopyOriginal
    
    ; 3 -- Check if we are switching palette.
    cmp.w #0,BackGroundCounterScrollPalette
    beq .noscrollpalette
    
    sub.w #1,BackGroundCounterScrollPalette
    
    move.w BackGroundCounterScrollPalette,d0 ; 28 to 0
    lsr.w #2,d0 ; 7 to 0
    move.l #7,d1
    ;move.w d1,$106
    sub.w d0,d1 ; 0 to 7
    
    cmp.w #0,d1
    beq .noscrollpalette
    ; Copy palette
    lea BackPaletteScrollPalette,a0
    lea BackPaletteOriginal,a1
    sub.w #1,d1
.loop
    move.w (a0)+,(a1)+
    dbra d1,.loop
    bsr BackgroundAnimation_CopyOriginal
    
    ;move.w BackGroundCounterScrollPalette,$104

.noscrollpalette:   
    ; 1 -- Check Back to Front animation
    cmp.w #0,BackGroundCounterBackToFrontAnim
    beq .nobacktofrontanim
    
    cmp.w #1,BackGroundCounterBackToFrontAnim ; last image, do nothing
    beq .donothing    
    move.w BackGroundCounterBackToFrontAnim,d0 ; 24 to 0
    lsr #2,d0 ; 6 to 0
    lsl #1,d0 ; 12 to 0
    lea BackPalette,a1
    move.w #$0fff,(a1,d0.w)
.donothing:
    ;bsr SetBackPalette
    sub.w #1,BackGroundCounterBackToFrontAnim
    cmp.w #0,BackGroundCounterBackToFrontAnim
    bne .nobacktofrontanim
    ; Reset
    ; Do nothing
    ;bsr BackgroundAnimation_TriggerBackAnim
.nobacktofrontanim:

    ; 2 -- Check Front to Back animation
    cmp.w #0,BackGroundCounterFrontToBackAnim
    beq .nofronttobackanim

    cmp.w #1,BackGroundCounterFrontToBackAnim ; last image, do nothing
    beq .donothing2    
    move.w BackGroundCounterFrontToBackAnim,d0 ; 24 to 0
    lsr #2,d0 ; 6 to 0
    move.w #6,d1
    exg.w d0,d1
    sub.w d1,d0 ; 0 to 6
    lsl #1,d0 ; 0 to 12
    lea BackPalette,a1
    move.w #$0fff,(a1,d0.w)
.donothing2:
    ;bsr SetBackPalette
    sub.w #1,BackGroundCounterFrontToBackAnim
    cmp.w #0,BackGroundCounterFrontToBackAnim
    bne .nofronttobackanim
    ; Reset
    ;bsr BackgroundAnimation_TriggerFrontAnim
    ; Do nothing
.nofronttobackanim:

    ; 4 -- In all case, set the palette to the copper
    bsr SetBackPalette    
    
    rts

; Fade for first display
Fx5_Irq:
    lea BackPaletteOriginal_Dark,a0 ; 0 to this
    lea BackPaletteOriginal,a1
    move.w #7,d0
    move.w VBLCount,d5
    cmp.w #32,d5
    bpl .nofade
    move.w #5,d6 ; 32 steps
    bsr dfm_palette_fade0
.nofade    
    rts
 
BackgroundAnimation_CopyOriginal:
    ; Copy original to work palette (each frame)
    lea BackPaletteOriginal,a0
    lea BackPalette,a1
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+ 
    rts
    ; ---------------------------------------------


    
; Fade out and logo clear (line by line, top and bottom to center)
Fx6_Irq:
    lea BackPaletteOriginal_Dark,a0 ; This to 0 , Steps need to be 32 to 0
    lea BackPaletteOriginal,a1
    move.w #7,d0 ; nb colors to fade
    move.w VBLCount,d5
    cmp.w #33,d5
    bne .noend
    move.w #10,StepCurrent ; End for IRQ
    rts
.noend:

    move.w #32,d5
    sub.w VBLCount,d5 ; Step reverse

    move.w #5,d6 ; 32 steps
    bsr dfm_palette_fade0
   
    ; Erase planes lines.
    ; TOP LINES
    lea BufferChips,a1 ; 87 lines high
    add.l #((87-66)/2)*40,a1 ; Center Y ; Start. use 65 because one line missing
    ; 64 lines on 4 planes.
    ; Each plane 87*40
    clr.l d0
    move.w VBLCount,d0 ; 32 steps
    mulu #40,d0
    add.l d0,a1
    move.w #5-1,d1
.eraseoneline:
    move.w #20-1,d2
.line1:
    ; Clear 40 bytes
    move.w #0,(a1)+
    dbra d2,.line1
    add.l #87*40-40,a1
    dbra d1,.eraseoneline
    ; -- BOTTOM LINES -----------------------------
    lea BufferChips,a1 ; 87 lines high
    add.l #(((87-64)/2)*40)+64*40,a1 ; Center Y ; Start.
    clr.l d0
    move.w VBLCount,d0 ; 32 steps
    mulu #40,d0
    sub.l d0,a1
    move.w #5-1,d1
.eraseoneline2:
    move.w #20-1,d2
.line2:
    ; Clear 40 bytes
    move.w #0,(a1)+
    dbra d2,.line2
    add.l #87*40-40,a1
    dbra d1,.eraseoneline2

.nofade:

    rts    

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
  

BackgroundAnimation_TriggerFrontAnim:
    move.w #BACKCOUNTERANIM,BackGroundCounterBackToFrontAnim
    rts

BackgroundAnimation_TriggerBackAnim:
    move.w #BACKCOUNTERANIM,BackGroundCounterFrontToBackAnim
    rts

BackgroundAnimation_SwitchToDarkPalette:
    lea BackPaletteOriginal_Dark,a0
    lea BackPaletteScrollPalette,a1
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+ 
    move.w #7*4,BackGroundCounterScrollPalette
    rts
    
BackgroundAnimation_SwitchToDarkPalette2: ; End logo
    lea BackPaletteOriginal_Dark2,a0
    lea BackPaletteScrollPalette,a1
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+ 
    move.w #7*4,BackGroundCounterScrollPalette
    rts    

BackgroundAnimation_SwitchToBrightPalette:
    lea BackPaletteOriginal_Bright,a0
    lea BackPaletteScrollPalette,a1
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+ 
    move.w #7*4,BackGroundCounterScrollPalette
    rts

erasebackscreen:
    ; Erase HALF of the screen. Right part, we do not need to erase the other half
	move.l SCR3,a0
    add.l #20,a0    
    bsr waitblitter ; Wait blitter to be ready
	move.w #20,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
    move.l a0,$dff054   ;destination address
	move.w #(SCREENH*64)+(LINE_PITCH/2/2),$dff058 ;blitter operation size    
    rts

triplebufferswap:
    ; SWAP
    move.l SCR1,a0 ; Visible screen
    move.l SCR2,a1 ; Back screen (draw)
    move.l SCR3,a2 ; Clear screen

    move.l a1,SCR1 ; Back screen become front screen
    move.l a2,SCR2 ; Cleared screen decome back screen (draw)
    move.l a0,SCR3 ; Visible screen become screen to be cleared

    ; Set in copper, view buffer
    move.l SCR1,d0
    lea copScrSet,a1
.sloop:     
    move.w  d0,6(a1)
    swap    d0
    move.w  d0,2(a1) 
    rts

; ------------------------------------------------------
; FX1 : 3d
; ------------------------------------------------------

Fx1_Init:

    ; Set Planes, Set Colors.
    lea Planes87,a0
    move.w #($0200|(3<<12)),2(a0) ; 3 planes

    bsr Init_DitherData
    ; Clean mem (already cleaned)
    bsr Init_LetterR
    bsr initPalette
	bsr DoScreenSet ; set bitplans  

    rts

; --------------------------------------------------------	
DoScreenSet:
	; set bitplans
	move.l ScreenDisplayed,d0
	Lea copScrSet,a1
	swap d0
	move.w d0,2(a1)
	swap d0
	move.w d0,6(a1)
	add.l #8,a1
	add.l #bitplanesizebytes,d0
	; Plane2
	swap d0
	move.w d0,2(a1)
	swap d0
	move.w d0,6(a1)
	add.l #8,a1
	add.l #bitplanesizebytes,d0
	; Plane 3
	swap d0
	move.w d0,2(a1)
	swap d0
	move.w d0,6(a1)
    ; Clear flags
	move.b #0,ScreenAskSwap
	move.b #1,ScreenSwapDone
	rts
    
Fx1_Irq:
	; All code is outside the IRQ, we only synchronise the display
	; Check if we need to swap buffers
	cmp.b #1,ScreenAskSwap
	bne 	noswap
    bsr DoScreenSet
noswap:

    rts

; Copy logo to screen, using a mask not to erase what is below  
; A3 plan dest  , screen1 screen2 screen13
Fx1_CopySmallLogo:
    clr.l d0
    clr.l d1
    clr.l d2
    lea LogoSmall+26,a0       ; plan 1
    lea LogoSmall+26+36*11,a1 ; plan 2
    lea LogoSmall+26+(36*11*2),a2 ; Plan 3
    add.l #2+76*40,a3 ; Dest plan 1
    move.l a3,a4 
    add.l #bitplanesizebytes,a4 ; Dest plan 2
    move.l a4,a5
    add.l #bitplanesizebytes,a5 ; Dest plan 3
    ; 11 lines
    move.w #11-1,d0
.loop
    move.w #9-1,d1 ; horizontal line
.loop288pixels
    ; Build mask
    move.l (a0),d3
    or.l (a1),d3
    or.l (a2),d3 ; d3 is mask (1 = pixel)
    not.l d3 ; Inverse mask
    ; We make a "hole" in background and OR data
    
    ; Plan 1
    move.l (a3),d5 ; Background data
    and.l d3,d5 ; Make hole
    or.l (a0)+,d5
    move.l d5,(a3)+
    ; Plan 2
    move.l (a4),d5 ; Background data
    and.l d3,d5 ; Make hole
    or.l (a1)+,d5
    move.l d5,(a4)+
    ; Plan 3
    move.l (a5),d5 ; Background data
    and.l d3,d5 ; Make hole
    or.l (a2)+,d5
    move.l d5,(a5)+
    
    dbra d1,.loop288pixels
    ; Next line
    add.l #4,a3
    add.l #4,a4
    add.l #4,a5
    dbra d0,.loop ; next line.

    rts

; Copy displayed buffer to the 2 others.
; IT have been asked so do it once
; 1 2 3 each part of the screen. 96 pixels.
; Copy from logo LogoRSE: ; 96*3 x 77 .... Incbin "data/LogoRSE.ami"
; Copy to 3 display buffer ScreenDisplayed ScreenWork ScreenWorkNext       
Fx1_CopyBuffers:
    ;move.w AskForCopyLetter,$100

    move.l #2,d0 ; Start offset
    cmp.w #2,AskForCopyLetter
    bne .no2
    add.l #96/8,d0
.no2
    cmp.w #3,AskForCopyLetter
    bne .no3
    add.l #96/8*2,d0
    move.w #2,StepCurrent ; Ask for next GFX
.no3

    bsr Fx1_CopyLogoToScreenDisplayed ; Copy the logo nice letter to display buffer

	;move.l ScreenDisplayed,a0
	;move.l ScreenWork,a1
	;move.l ScreenWorkNext,a2
    ; Copy 3 planes. 96 large, 87 high
    move.l ScreenDisplayed,a0 ; Source
    add.l d0,a0
    move.l ScreenWork,a1
    add.l d0,a1
    ; Copy 3 planes. 87*3
    move.w #87*3-1,d1
.loop1
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    add.l #40-(96/8),a0
    add.l #40-(96/8),a1
    dbra d1,.loop1
    ; Copy to third buffer
    move.l ScreenDisplayed,a0 ; Source
    add.l d0,a0
    move.l ScreenWorkNext,a1
    add.l d0,a1
    ; Copy 3 planes. 87*3
    move.w #87*3-1,d1
.loop2
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    move.l (a0)+,(a1)+
    add.l #40-(96/8),a0
    add.l #40-(96/8),a1
    dbra d1,.loop2
    
    cmp.w #3,AskForCopyLetter
    bne .nolastletter
    ; Copy small logo is was the last letter
    lea screen1,a3
    bsr Fx1_CopySmallLogo
    lea screen2,a3
    bsr Fx1_CopySmallLogo
    lea screen3,a3
    bsr Fx1_CopySmallLogo     
.nolastletter:
    move.w #0,AskForCopyLetter ; Reset the request
    rts
    
Fx1_CopyLogoToScreenDisplayed:
    move.w #5,LogoRSEFlash ; Ask Flash white to palette, very quick

    lea LogoRSE+26,a0 ; Source
    add.l d0,a0 ; offset 
    sub.l #2,a0 ; need to remove the 16 pixels of screen offset
    move.l a0,a1
    add.l #36*77,a1 ; Plane 2
    move.l a1,a2
    add.l #36*77,a2 ; Plane 3
    ; Dest
    move.l ScreenDisplayed,a3 ; Dest plane 1
    add.l #5*40,a3 ; The Logo RSE picture is smaller than the 87 pixel zone
    add.l d0,a3
    move.l a3,a4
    add.l #40*87,a4 ; plane 2
    move.l a4,a5
    add.l #40*87,a5 ; plane 3
    ; Copy 3 planes. 77 lines
    move.w #77-1,d1
.loop1
    move.l (a0)+,(a3)+ ; 32 pixels
    move.l (a1)+,(a4)+
    move.l (a2)+,(a5)+
    move.l (a0)+,(a3)+ ; 32 pixels
    move.l (a1)+,(a4)+
    move.l (a2)+,(a5)+
    move.l (a0)+,(a3)+ ; 32 pixels
    move.l (a1)+,(a4)+
    move.l (a2)+,(a5)+    
    add.l #36-12,a0
    add.l #36-12,a1
    add.l #36-12,a2
    add.l #40-(96/8),a3
    add.l #40-(96/8),a4
    add.l #40-(96/8),a5
    dbra d1,.loop1
    rts
    
LogoRSEFlash:
    dc.w    0 ; 0 inactive.
    
FX1_DoRSEFlash:
    ; LogoRSEFlash can be 5 4 3 2 1
    cmp.w #5,LogoRSEFlash
    bne .no5
    lea Pal5,a0
    bsr FX1_CopyRSEPal
    bra .end
.no5
    cmp.w #4,LogoRSEFlash
    bne .no4
    lea Pal4,a0
    bsr FX1_CopyRSEPal
    bra .end
.no4     
    cmp.w #3,LogoRSEFlash
    bne .no3
    lea Pal3,a0
    bsr FX1_CopyRSEPal
    bra .end
.no3
    cmp.w #2,LogoRSEFlash
    bne .no2
    lea Pal2,a0
    bsr FX1_CopyRSEPal
    bra .end
.no2  
    lea Pal1,a0
    bsr FX1_CopyRSEPal
.end
    sub.w #1,LogoRSEFlash
    rts
; A0 color 1 to 8
FX1_CopyRSEPal:
    lea copPal+4+2,a1 ; point to color 1 (ignore 0)
    move.w #7-1,d0
.copy:
    move.w (a0)+,(a1)+
    add.l #2,a1
    dbra d0,.copy
    rts

Pal5:    dc.w    $fff,$fff,$fff,$fff,$fff,$fff,$fff
Pal4:    dc.w    $bbb,$bbc,$eee,$eee,$eee,$eef,$fff
Pal3:    dc.w    $888,$99a,$ccd,$ccd,$dde,$ddf,$fef
Pal2:    dc.w    $444,$666,$aac,$aac,$ccd,$ccf,$fef
Pal1:    dc.w    $112,$445,$88B,$99B,$BAD,$CBF,$FEF
    

Fx1_Loop:

bitplanelines=87 ; 128 pixel high    
bitplanesizebytes=40*bitplanelines ; Size of one bitplane. We got 3 like this
bitplaneusedwidthinbytes=16 ; 128 pixels wide    
    
	; -- ClearScreen
	; The 3 buffers are consecutives
    ; Width is 16 bytes = 128 pixels.
    ; Height is 128 pixels
	bsr waitblitter
	
    ; Clean 128 pixels
    ;move.w #24,$dff066			;destination modulo
	;move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	;move.l ScreenWork,d0
	;;add.l #12,d0 ; Decay with.
	;move.l d0,$dff054   ;destination address
	;move.w #bitplanelines*3*64+(16/2),$dff058 ;blitter operation size
    
    ; Clean 96 pixels (12  bytes)
    move.w #40-12,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	move.l ScreenWorkNext,d0 ; Clean 3rd buffer
    clr.l d1
    move.w offsetStartXClean,d1
	add.l d1,d0 ; Decay with. ; TODO For 3 letters
	move.l d0,$dff054   ;destination address
	move.w #bitplanelines*3*64+(12/2),$dff058 ;blitter operation size   
 
	;move.w #$00f0,$dff180
	; -- Do point projection
	;lea points,a0
	move.l P_Obj3d,a0
	move.w OFFSET_NBVERTICES(a0),d4 ; Nb Vertices
	move.l P_Vertices,a0
	lea pointsprojeted,a1
	sub.w #1,d4
    
DoProjection:
	clr.l d7
	clr.l d6
	move.w (a0)+,d7 ; x
	move.w (a0)+,d6 ; y
	move.w (a0)+,d0 ; Z
	asr.w #8,d7 ; Convert from 8:8 to 1
	asr.w #8,d6
	asr.w #8,d0
	; Translate
	add.w DotCurrent,d0 ; Translate in Z (500 to 800)
	;	cette partie de programme transforme les trois coordonnees
	;	d'un point x=d7 y=d6 z=d0 en deux coordonnees x=d7 y=d6
	Move.l #$800000,d5
	divu d0,d5
	muls d5,d7
	add.l d7,d7
	swap d7
	muls d5,d6
	add.l d6,d6
	swap d6
	; End projection*
	; D7 should be between -64 and +64 ($FFBF) ($40) 
	; D6 should be between -64 and +64
	add.w #64,d7
	and.w #$007F,d7
    add.w offsetStartXDraw,d7 ; TODO For 3 letters 0 for R
	;add.w #160-64,d7 ; X add center of screen. 160-64 to 160+64 ($60 to $E0)
	add.w #(88/2)+4,d6 ; Y add center of screen 0 to 128 ($00 to $80)
	and.w #$007F,d6 ; Limit to $00 to $80
	move.w d7,(a1)+
	move.w d6,(a1)+
	dbra d4,DoProjection
    
	;move.w countertest,d0
	;bsr DisplayWord

	; Draw 16 points
	; lea screen,a1 
	; lea pointsprojeted,a2
	; move.w #16-1,d4
; DisplayPoints:
	; move.w (a2)+,d1 ; x
	; move.w (a2)+,d2 ; y
	; move.w #1,d3 ; color
	; bsr Plot
	; dbra d4,DisplayPoints	
	
	;move.w #$00ff,$dff180
	; -- Draw quads
	;move.w #1,BigDebugLoopCounter
;BigDebugLoop:
	;move.w #74,FaceLimiter ; Debug
	move.l P_Quads,a2
	cmp.l #$FFFFFFFF,(a2)
	beq .endfacesquads
	;add.l #6*10,a2 ; Skip first faces
	; Point 0 1 4 5 (multiply by 4 to get correct offset in vertice projected table)
.looponfaces
    ;add.b #1,$102
	Lea quaddata,a0
	Lea pointsprojeted,a1 ; All vertices
	clr.l d0
	move.b (a2),d0 ; index of point 1
	lsl #2,d0
	move.l (a1,d0.w),0(a0) ; Set point 1
	clr.l d0
	move.b 1(a2),d0 ; index of point 2
	lsl #2,d0	
	move.l (a1,d0.w),4(a0) ; Set point 2
	clr.l d0
	move.b 2(a2),d0 ; index of point 3
	lsl #2,d0	
	move.l (a1,d0.w),8(a0) ; Set point 3
	clr.l d0
	move.b 3(a2),d0 ; index of point 4
	lsl #2,d0	
	move.l (a1,d0.w),12(a0) ; Set point 4
	
	; -- Get Z of normal
	move.l P_Normals,a1
	clr.l d0
	move.b 5(a2),d0 ; index of normal
	move.w d0,d1
	lsl #2,d0 ; *4
	lsl #1,d1 ; *2
	add.w d1,d0 ; index *6
	add.l #4,d0 ; Skip x and Y
	move.w (a1,d0.w),d0 ; Value of Z in 8:8 format. -100 to +100. Facing us is -1.
	;bsr DisplayWordInWorkScreen	
	cmp.w #0,d0
	bge .nextface
	neg d0 ; Get positive value. From $000 tp $100
	lsr #4,d0 ; Back to 0 16 value.
	add.w #7,d0 ; Add a bit of brighness
	
	; Compute Best color. We have a table with "colorblend" brightness from 0% to 200% (16+16 values)
	move.w DotCurrent,d1 ; Current depth (translation) 500 to 1000
	; 500 is near, brightness should be 31. 1000 is far, brightness is 0
	; Amplitude is 512. Divide by 16, make 32
	sub.w #500,d1 ; 0 to 500
	lsr.w #6,d1 ; /128 ( 0 to 3 )
	sub.w d1,d0 ; Sub to global brightness
	;bsr DisplayWordInWorkScreen
	;lsr.w #4,d1 ; 0 to 32
	;neg d1
	;add.w #31,d0
	;and.w #$001F,d0 ; D0 is brightness. 0 to 31.
	;move.w #12,d0 ; Debug, force brightness	
	; D0 is brightness. 0 to 31
	;move.w #15,d0 ; Debug
	bsr clampbrightness ; Clam d0 to 0 31
	lsl #2,d0 ; *4, to have offset in table
	move.w d0,d1
	;bsr DisplayWordInWorkScreen
	move.l P_ColorBlend,a4
	;clr.l d0
	move.b 4(a2),d0 ; Color of material. 128 bytes for each materials
	lsl #7,d0 ; *128
	add.l d0,a4 ; We got the correct color, now get the brighness. 32 word. at middle, normal color
	add.l d1,a4 ; Add brightness
	move.l (a4),colorblend ; Color to use.
    
	move.l a2,-(sp)
	; Draw face
	bsr drawshape ; FAIL INSIDE THIS, last frame, maybe going out of screen ?
	move.l (sp)+,a2
    
.nextface
	add.l #6,a2 ; Next face
	;sub.w #1,FaceLimiter
	;beq .endfacesquads
	cmp.l #$FFFFFFFF,(a2)
	bne .looponfaces
    
.endfacesquads:	
	;sub.w #1,BigDebugLoopCounter ; debug
	;bne BigDebugLoop

	;move.w #$0088,$dff180
	
	;bra .endfacestris ; Debug
	; Draw triangles 
	move.l P_Triangles,a2 ; A2 structure of faces, same as quads but have 3 points insteade of 4.
	cmp.l #$FFFFFFFF,(a2)
	beq .endfacestris
.looponfacestri
    ;add.b #1,$103
	Lea quaddata,a0
	Lea pointsprojeted,a1 ; All vertices
	clr.l d0
	move.b (a2),d0
	lsl #2,d0
	move.l (a1,d0.w),0(a0) ; Set point 1
	clr.l d0
	move.b 1(a2),d0
	lsl #2,d0	
	move.l (a1,d0.w),4(a0) ; Set point 2
	clr.l d0
	move.b 2(a2),d0
	lsl #2,d0	
	move.l (a1,d0.w),8(a0) ; Set point 3
	move.l 8(a0),12(a0) ; Set point 4 (same as point 3)
	
	; -- Get Z of normal
	move.l P_Normals,a1
	clr.l d0
	move.b 5(a2),d0 ; index of normal
	move.w d0,d1
	lsl #2,d0 ; *4
	lsl #1,d1 ; *2
	add.w d1,d0 ; index *6
	add.l #4,d0 ; Skip x and Y
	move.w (a1,d0.w),d0 ; Value of Z in 8:8 format. -100 to +100. Facing us is -1.
	;bsr DisplayWordInWorkScreen	
	cmp.w #0,d0
	bge .nextfacetri
	neg d0 ; Get positive value. From $000 tp $100
	lsr #4,d0 ; Back to 0 16 value.	
	add.w #7,d0 ; Add a bit of brighness
	
	; Compute Best color. We have a table with "colorblend" brightness from 0% to 200% (16+16 values)
	move.w DotCurrent,d1 ; Current depth (translation) 500 to 1000
	; Amplitude is 512. Divide by 16, make 32
	sub.w #500,d1 ; 0 to 500
	lsr.w #6,d1 ; /128 ( 0 to 3 )
	sub.w d1,d0 ; Sub to global brightness	
	;sub.w #500,d0 ; 0 to 500
	;lsr.w #4,d0 ; 0 to 32
	;neg d0
	;add.w #31,d0
	;and.w #$001F,d0 ; D0 is brightness. 0 to 31.
    
    ;move.w #12,d0 ; Debug, force brightness	
    
	bsr clampbrightness ; Clam d0 to 0 31
	lsl #2,d0 ; *4, to have offset in table
	move.w d0,d1
	;bsr DisplayWordInWorkScreen
	; 500 is near, brightness should be 31. 1000 is far, brightness is 0
	move.l P_ColorBlend,a4
	;clr.l d0
	move.b 4(a2),d0 ; Color of material. 128 bytes for each materials
	lsl #7,d0 ; *128
	add.l d0,a4 ; We got the correct color, now get the brighness. 32 word. at middle, normal color
	add.l d1,a4 ; Add brightness
	move.l (a4),colorblend ; Color to use.

	move.l a2,-(sp)
	bsr drawshapetriangle ; Draw face
	move.l (sp)+,a2
.nextfacetri	
	add.l #6,a2 ; Next face
	cmp.l #$FFFFFFFF,(a2)
	bne .looponfacestri
.endfacestris

    rts
    
;---------------------------------------------------------------
Init_LetterR:
    ; Init R
    move.l #Obj3d_R, P_Obj3d
    move.w #2,offsetStartXClean ; Start of X zone (of 96 pixels)
    move.w #0,offsetStartXDraw ; Offset for drawing
    move.w #2000,DotCurrent ; Put position back
    move.w #1,DotAnimdirection ; Back to front
	bsr Init_Object3d ; Init pointer to 3D objects
    rts
;---------------------------------------------------------------
Init_LetterS:
    ; Init S
    move.l #Obj3d_S, P_Obj3d
    move.w #2+(96/8),offsetStartXClean ; Start of X zone (of 96 pixels)
    move.w #96,offsetStartXDraw ; Offset for drawing
    move.w #2000,DotCurrent ; Put position back
    move.w #1,DotAnimdirection ; Back to front
	bsr Init_Object3d ; Init pointer to 3D objects    
    rts
 ;---------------------------------------------------------------
Init_LetterE:   
    ; Init E
    move.l #Obj3d_E, P_Obj3d
    move.w #2+((96*2)/8),offsetStartXClean ; Start of X zone (of 96 pixels)
    move.w #96*2,offsetStartXDraw ; Offset for drawing  
    move.w #2000,DotCurrent ; Put position back
    move.w #1,DotAnimdirection ; Back to front  
    bsr Init_Object3d ; Init pointer to 3D objects
    rts

Init_DitherData:
    lea Dither12,a0
    lea Dither12_data,a1
    bsr Init_DitherData_Sub
    lea Dither25,a0
    lea Dither25_data,a1
    bsr Init_DitherData_Sub
    lea Dither37,a0
    lea Dither37_data,a1
    bsr Init_DitherData_Sub
    lea Dither50,a0
    lea Dither50_data,a1
    bsr Init_DitherData_Sub
    lea Dither62,a0
    lea Dither62_data,a1
    bsr Init_DitherData_Sub
    lea Dither75,a0
    lea Dither75_data,a1
    bsr Init_DitherData_Sub
    lea Dither87,a0
    lea Dither87_data,a1
    bsr Init_DitherData_Sub    
    rts

; Fill dither table
; a0 dither place
; a1 dither data
Init_DitherData_Sub:
    ; 20 patterns of 4 lines.
    move.w #20-1,d0
.loop:
    move.l (a1),d1
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l 4(a1),d1
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+    
    move.l 8(a1),d1
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+ 
    move.l 12(a1),d1
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+
    move.l d1,(a0)+ 
    dbra d0,.loop
    rts

;DITHERMAXHEIGHT=80
;DITHERMAXHEIGHT*16 ; 4 long wide
Dither12_data: 
    dc.l $11111111
    dc.l $00000000
    dc.l $44444444
    dc.l $00000000
Dither25_data: 
    dc.l $55555555
    dc.l $00000000
    dc.l $55555555
    dc.l $00000000
Dither37_data: 
    dc.l $55555555
    dc.l $22222222
    dc.l $55555555
    dc.l $88888888
Dither50_data: 
    dc.l $55555555
    dc.l $AAAAAAAA
    dc.l $55555555
    dc.l $AAAAAAAA
Dither62_data: 
    dc.l $AAAAAAAA
    dc.l $DDDDDDDD
    dc.l $AAAAAAAA
    dc.l $77777777
Dither75_data: 
    dc.l $AAAAAAAA
    dc.l $FFFFFFFF
    dc.l $AAAAAAAA
    dc.l $FFFFFFFF
Dither87_data: 
    dc.l $EEEEEEEE
    dc.l $FFFFFFFF
    dc.l $BBBBBBBB
    dc.l $FFFFFFFF    
    

;---------------------------------------------------------------
; Clamp d0 to 0 31
clampbrightness:	
	cmp.w #0,d0
	bge .checkhighvalue
	move.w #0,d0
	rts
.checkhighvalue	
	cmp.w #31,d0
	ble .exit
	move.w #31,d0
.exit	
	rts
	
FaceLimiter:
	dc.w	0
BigDebugLoopCounter:
	dc.w	0
    
 offsetStartXClean: ; Start of X zone (of 96 pixels)
    dc.w    0
 offsetStartXDraw: ; Offset for drawing
    dc.w    0
; Triple buffer system
; The buffer we currently seeing
; The buffer we work in
; The buffer we worked after (to avoid transition problems)
ScreenDisplayed:
		dc.l	screen1
ScreenWork:
		dc.l	screen2
ScreenWorkNext:
		dc.l	screen3		
		
        CNOP 0,4
        
ScreenAskSwap:
		dc.b	0
		even
ScreenSwapDone:
		dc.b	0
		even
countertest:
		dc.w	0

OFFSET_NBVERTICES=0
OFFSET_NBNORMALS=2
OFFSET_NBQUADS=4
OFFSET_NBTRIANGLES=6
OFFSET_NBCOLORS=8

; Binary struct (Word, Long, Byte)
; Header:
; W : Nb Vertices (Max 256)
; W : Nb Normals (Max 256)
; W : Nb Quads (Max 256)
; W : Nb Triangles (Max 256)
; W : NB Colors (Max 256)
; Vertices: N*6bytes
; W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
; Normals: N*6bytes
; W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
; Quads: N*6bytes
; B B B B B B: Index1,2,3,4, color, Normal
; L End Marker : FFFFFFFF
; Triangles: N*6bytes
; B B B B : Index 1 2 3, Dummy, Color, Normal
; L End Marker : FFFFFFFF
; Base palette: 
; W : 8 colors ( 16 bytes)
; Color table: N colordithered
; For each color, 32 colorsdithered. Color 1, color 2, Dither id. = 16 bits (2 bytes)
; N*32*2 = N*64 bytes per color.
Init_Object3d:
	move.l P_Obj3d,a0
	move.l a0,a1
	add.l #10,a1
	move.l a1,P_Vertices ; Save pointer to Vertices
	clr.l d0
	clr.l d1
	move.w OFFSET_NBVERTICES(a0),d0 ; Nb Vertices
	mulu #6,d0
	add.l d0,a1
	move.l a1,P_Normals ; Save pointer to Normals
	move.w OFFSET_NBNORMALS(a0),d1 ; Normals
	mulu #6,d1
	add.l d1,a1
	move.l a1,P_Quads ; Save pointer to Quads
	move.w OFFSET_NBQUADS(a0),d1 ; Quads
	mulu #6,d1
	add.l d1,a1
	add.l #4,a1 ; End marker
	move.l a1,P_Triangles ; Save pointer to Triangles
	move.w OFFSET_NBTRIANGLES(a0),d1 ; Triangles
	mulu #6,d1
	add.l d1,a1
	add.l #4,a1 ; End marker	
	move.l a1,P_Palette ; Save pointer to Palette 
	add.l #16,a1 ; 8 colors
	move.l a1,P_ColorBlend  ; Save pointer to ColorBlend 
	rts
initPalette:
	move.l P_Palette,a0
    add.l #2,a0 ; Skip first color
    ;move.w 6(a0),$100
    ;move.w 14(a0),$102
	lea copPal+4,a1
	add.l #2,a1 ;
	move.w #7-1,d0
.initPaletteloop
	move.w (a0)+,(a1)
	add.l #4,a1
	dbra d0,.initPaletteloop
	rts
    
    CNOP 0,4
    
P_Obj3d:
	dc.l	Obj3d_R
P_Vertices:
	dc.l	0
P_Normals:
	dc.l	0
P_Quads:
	dc.l	0
P_Triangles:
	dc.l	0
P_Palette:
	dc.l	0
P_ColorBlend
	dc.l	0

;----------------------------------------------------------------		
; Dot animation
DotDepthStart:
		dc.w 530	
DotDepthEnd:
		dc.w 2000 ; 500 + 16*31
DotAnimdirection: ; 0 = raising, 1=decreasing , 2 = do nothing
		dc.w 1
DotCurrent: 
		dc.w 2000
;----------------------------------------------------------------	
DotAnimation:
    ;add.b #1,$100
	;lea points,a0
	;add.l #4,a0 ; point to Z
	lea DotCurrent,a1
	lea DotAnimdirection,a2
	;move.w #1-1,d5
.DotAnimationLoop
    moveq #0,d0
	move.w (a1),d0 ; Current depth
	;move.w countertest,d0
	;bsr DisplayWord
    cmp.w #2,(a2)
    beq .end
	cmp.w #1,(a2)
	beq .decreasing
	; Raising
SPEED3D=17    
	add.w #SPEED3D,d0
	cmp.w DotDepthEnd,d0
	blt.w .copyvaluestotable
	move.w #1,(a2) ; Change animation way
	bra .copyvaluestotable
.decreasing:	
	sub.w #SPEED3D,d0 ; TODO: Debug no move
	cmp.w DotDepthStart,d0 ; 530
	bgt.w .copyvaluestotable
	;move.w #0,(a2) ; Change animation way
    move.w #2,(a2) ; Stop
    ; Reset animation, to next letter
    ; If was R, then init S
    cmp.l #Obj3d_R,P_Obj3d
    bne .wasnotR
    bsr Init_LetterS
    move.w #1,AskForCopyLetter ; Letter R will be copied to all buffers
    bra .wasnotS
.wasnotR: 
    ; If was S then init E
    cmp.l #Obj3d_S,P_Obj3d
    bne .wasnotS
    bsr Init_LetterE
    move.w #2,AskForCopyLetter ; Letter S will be copied to all buffers
    bra .wasnotE
.wasnotS:    
    ; if was E then only ask for copy
    cmp.l #Obj3d_E,P_Obj3d
    bne .wasnotE
    move.w #3,AskForCopyLetter ; Letter S will be copied to all buffers
    ; Copy resistance small logo when letter is last one
    ; Ask for next GFX after call AskCopyLetter
.wasnotE: 
 
.copyvaluestotable:
	move.w d0,(a1)+ ; Store current point and go to next point
	;move.w d0,(a0)
	;add.l #6,a0 ; go to next point
	;add.l #2,a2 ; next direction
	;dbra d5,.DotAnimationLoop	
.end: 
	rts

;----------------------------------------------------------------
; 3D Coordinates:
; X positive Right	
; Y positive down
; Z positive far
;----------------------------------------------------------------
;----------------------------------------------------------------	
; znear = 270	
; Z middle = 500
; Z very far = 2000
;points: ; Centered in 0
; Line 1
;		dc.w -110,-110,700 ; Offset 0
;		dc.w  -35,-110,700 ; Offset 6
;		dc.w   35,-110,700 ; Offset 12
;		dc.w  110,-110,700 ; Offset 18
; Line 2
;		dc.w -110,-35,700 ; Offset 24
;		dc.w  -35,-35,750 ; Offset 30
;		dc.w   35,-35,750 ; Offset 36
;		dc.w  110,-35,700 ; Offset 42
; Line 3
;		dc.w -110,35,700 ; Offset 48
;		dc.w  -35,35,750 ; Offset 54
;		dc.w   35,35,750 ; Offset 60
;		dc.w  110,35,700 ; Offset 66
; Line 4
;		dc.w -110,110,700 ; Offset 72
;		dc.w  -35,110,700 ; Offset 78
;		dc.w   35,110,700 ; Offset 84
;		dc.w  110,110,700 ; Offset 90
		
; ------ Faces infos
; 9 faces
;faces:  ; points(4), virtual index (0 to 256), shade (0,256), free, free
;		dc.b 0,1,4,5, 1,0,0,0
;		dc.b 1,2,5,6, 1,0,0,0
;		dc.b 2,3,6,7, 1,0,0,0
;		dc.b 4,5,8,9, 1,0,0,0
;		dc.b 5,6,9,10, 1,0,0,0
;		dc.b 6,7,10,11, 1,0,0,0
;		dc.b 8,9,12,13, 1,0,0,0
;		dc.b 9,10,13,14, 1,0,0,0
;		dc.b 10,11,14,15, 1,0,0,0
;		dc.l $FFFFFFFF
		
;---------------------------------------------------------------
;ObjX:	dc.w 128
;ObjY:	dc.w 128			;Move it up to learn unbuffered gfx ;)
w=320				;screen width, height, depth
h=256
bpls=1				;handy values:
bpl=(w/16)*2				;byte-width of 1 bitplane line
bwid=bpls*bpl			;byte-width of 1 pixel line (all bpls)
Plot:					;d1=x, d2=y, d3=color, a1=screen
	movem.l d1-d5/a1,-(sp)
	muls #bwid,d2			;Address offset for line
	move.w d1,d4			;left-to-right x position,
	not.w d4			;to bit 7-0 (other bits unused by bset)
	asr.w #3,d1			;Byte offset for x position
	ext.l d1			;(big offsets for large screens?)
	add.l d1,d2			;added to final address offset.
	moveq #bpls-1,d5		;Loop through bitplanes:
.l:	ror.b #1,d3			;color bit for bitplane set?
	bpl.s .noset
	bset d4,(a1,d2.l)		;then set bit.
.noset: lea bpl(a1),a1		        ;go to next bitplane
	dbf d5,.l
	movem.l (sp)+,d1-d5/a1
	rts	
	
;---------------------------------------------------------------
; a0 Shape structure	
drawshape: ; Quad

	move.l	a0,-(sp) ; Store on stack
	bsr computeminmax ; compute the limits, empty the zone
	; Draw a quad from a memory structure (quadtest)
	move.l	(sp),a0 ; restore Structure
	cmp.w #0,26(a0)
	beq .nodraw
    
	bsr drawquad
    
	move.l	(sp),a0 ; restore Structure
    
	bsr fillbob

	move.l	(sp)+,a0 ; last time, we pop the value from stack
    
	bsr copybob ; FAIL INSIDE
	
	rts
    
.nodraw
	move.l	(sp)+,a0 ; Pop stack
	rts
	
	
; a0 Shape structure	
drawshapetriangle: ; Quad
	move.l	a0,-(sp) ; Store on stack
	bsr computeminmax ; compute the limits, empty the zone
	; Draw a quad from a memory structure (quadtest)
	move.l	(sp),a0 ; Structure
	cmp.w #0,26(a0)
	beq .nodraw	
	bsr drawtriangle
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
drawtriangle:
	; 1 2 3 x (each is 2 words) offset are 0=Point1 4=Point2 8=Point3 12=Point4 ... We trace 1-2 , 2-3, 3-1
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
	move.w 0(a0),d2 ; 3x
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
	; Add 1 to Xmax to avoid overflow when tracing lines
	add.w #1,20(a0)
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
	; -- Erase mem (Cpu for now)
	;clr.l d0
	;move.w 24(a0),d0 ; bytes width
	;mulu.w 26(a0),d0 ; Total number of lines
	;lsr.l #1,d0 ; Total number of words
	;sub.w #1,d0 ; For looping on correct number
	lea bobzone,a1
;.eraseloop:
;	move.w #0,(a1)+
;	dbra d0,.eraseloop

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
	mulu.w d1,d0
	sub.l #2,d0
	add.l d0,a1
	;Add.l	#[fillines*fillwidth]-2,a0 ; end of screen minus 2 bytes.
	move.l	a1,bltapth(a5)	; Dernier mot
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
	movem.l	d0-d6/a0-a5,-(a7)
	lea	$dff000,a5
	
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
line2:	move.w	d3,d1		; d1=d3=deltay
	add.w	d1,d1		; d1=2*deltay
	cmp.w	d2,d1		;
	dbhi	d3,line3
line3:	move.w	d3,d1
	sub.w	d2,d1		; deltax-deltay
	bpl.s	line4
	exg	d2,d3
line4:	addx.w	d5,d5
	add.w	d2,d2		; 2*deltax
	move.w	d2,d1
	sub.w	d3,d2
	addx.w	d5,d5
	and.w	#15,d0
	ror.w	#4,d0
	or.w	#$a4a,d0

	bsr waitblitter

	move.w	24(a0),d6 ; Screen width (bytes)
	move.w	d6,bltcmod(a5)
	move.l	#-$8000,bltbdat(a5)
	move.l	#-1,bltafwm(a5)    
	
	move.w	d2,bltaptl(a5)
	sub.w	d3,d2
	lsl.w	#6,d3
	addq.w	#2,d3
	move.w	d0,bltcon0(a5)
	move.b	oct(pc,d5.w),bltcon1+1(a5)
	move.l	d4,bltcpth(a5)
	move.l	d4,bltdpth(a5)
	movem.w	d1/d2,bltbmod(a5)
	move.w	d3,bltsize(a5)
out_line:
out_fill:
	movem.l	(a7)+,d0-d6/a0-a5
	rts
    
    CNOP 0,4

oct:		
	dc.l	$3431353,$b4b1757   
ft_octs:
	dc.b	%0011011,%0000111,%0001111,%0011111
	dc.b	%0010111,%0001011,%0000011,%0010011

;---------------------------------------------------------- 
; a0 Shape structure
copybob:

	; Debug color blend
	;lea colorblend,a1
	; Blend 1 to 2 with 50%
	;move.b #1,(a1)
	;add.l #1,a1
	;move.b #2,(a1)
	;add.l #1,a1
	;move.b #4,(a1)
	; That give.
	; Color1*!Dither MIXEDWITH Color2*Dither
	; Plane1 : 1*!D MIXEDWITH 0*D : Mode 4 (inverted dither)
	; Plane2 : 0*!D MIXEDWITH 1*D : Mode 3 (dither)
	; Plane3 : 0*!D MIXEDWITH 0*D : Mode 2 (empty)
	
	;move.b #6,(a1) ; Color 1
	;add.l #1,a1
	;move.b #7,(a1) ; Color 2
	;add.l #1,a1
	;move.b #0,(a1) ; Dither level
	
	; -- First start du analyse the blend color and decide what to do for each plan
	; colorblend : B = index color 1, B = index color 2 , B = dither
	; This allow to compute a combinaison for each 3 planes.
	; We are going to copy each 3 planes with a special mode.
	; Either plain (mode 1), or full empty (mode 2), or mixed with dither (mode3), or mix with negative dither (mode 4)
	; That is 4 different modes.
    ; For each plan (each bit).
	; Result = Color1*!Pattern Mixed with Color2*Pattern
	; Dither = 0 , We only use color 1
	; Dither = 8 , We only use color 2
	; Dither = 1 to 7 , we mix color 1 and color 2
	;
	; d0 color 1
	; d1 color 2
	; d2 Dithering 
	clr.l d0
	clr.l d1
	clr.l d2
	lea colorblend,a1
	;move.w 2(a1),d0
	;bsr DisplayWordInWorkScreen ; Debug
	move.b (a1)+,d0 ; Color 1
	move.b (a1)+,d1 ; Color 2
	move.b (a1)+,d2 ; Dithering
	
	; -- Test the values
	cmp.b #0,d2
	beq .useColor1Only
	cmp.b #8,d2
	beq .useColor2Only
	; Else we are going to blend two colors
	move.w #2,copybobModePlane1
	move.w #2,copybobModePlane2
	move.w #2,copybobModePlane3
	move.w d2,copybobDitherPlane1
	move.w d2,copybobDitherPlane2
	move.w d2,copybobDitherPlane3
	; First plane, compute mode
	; d0 color1
	; d1 color2
	; d3 bit to test
	; a1 result mode
	; a2 dither mode
	lea copybobModePlane1,a1
	lea copybobDitherPlane1,a2
	move.w #0,d3
	bsr computedithermode
	; Plane 2
	lea copybobModePlane2,a1
	lea copybobDitherPlane2,a2
	move.w #1,d3
	bsr computedithermode	
	; Plane 3
	lea copybobModePlane3,a1
	lea copybobDitherPlane3,a2
	move.w #2,d3
	bsr computedithermode
    
	bra .next
.useColor1Only:
	move.w #2,copybobModePlane1
	move.w #2,copybobModePlane2
	move.w #2,copybobModePlane3
	btst #0,d0
	beq .nosetplane1 ; Equal to 0 ?
	move.w #1,copybobModePlane1
.nosetplane1
	btst #1,d0
	beq .nosetplane2 ; Equal to 0 ?
	move.w #1,copybobModePlane2
.nosetplane2
	btst #2,d0
	beq .nosetplane3 ; Equal to 0 ?
	move.w #1,copybobModePlane3
.nosetplane3
	bra .next
	
.useColor2Only	
	move.w #2,copybobModePlane1
	move.w #2,copybobModePlane2
	move.w #2,copybobModePlane3
	btst #0,d1
	beq .nosetplane1b ; Equal to 0 ?
	move.w #1,copybobModePlane1
.nosetplane1b
	btst #1,d1
	beq .nosetplane2b ; Equal to 0 ?
	move.w #1,copybobModePlane2
.nosetplane2b
	btst #2,d1
	beq .nosetplane3b ; Equal to 0 ?
	move.w #1,copybobModePlane3
.nosetplane3b	
	bra .next
.next	
	
	; Check values
	;move.w copybobModePlane1,d0 ; Should be 4
	;move.w copybobModePlane2,d0 ; Should be 3
	;move.w copybobModePlane3,d0 ; Should be 2
	;move.w colorblend,d0
	;move.w d2,d0
	;bsr DisplayWordInWorkScreen


	; -- Get bob size and compute start offset (in d1)
	move.w	24(a0),d5 ; Width in bytes
	move.w  26(a0),d6 ; lines
	; Compute Destination start position (do it before A0 is changed). Result in d1
	; Add X divided by 8 (in bytes)
	; Add screen width * lines
	clr.l d0
	clr.l d1
	; XMIN=16 YMIN=18
	move.w 16(a0),d0
	lsr.w #3,d0 ; pos X min in bytes
	move.w 18(a0),d1
	mulu #40,d1
	add.l d0,d1	; Start offset

	; First plane
	lea bobzone,a1 ; source
	move.l ScreenWork,a0 ; destination	
	add.l d1,a0 ; add start offset
	movem.l d1-d6,-(sp)
	move.w copybobDitherPlane1,d0 ; Dither value (0 to 8)
	move.w copybobModePlane1,d1 ; Copy mode (1 2 3 4)	
	Bsr DisplayBob	; use 0 to not dither.
	movem.l (sp)+,d1-d6
.endplane1:
	
	; Second plane
	lea bobzone,a1 ; source
	move.l ScreenWork,a0 ; destination	
	add.l #bitplanesizebytes,a0 ; Second screen
	add.l d1,a0 ; add start offset
	movem.l d1-d6,-(sp)
	move.w copybobDitherPlane2,d0 ; Dither value (0 to 8)
	move.w copybobModePlane2,d1 ; Copy mode (1 2 3 4)
	Bsr DisplayBob	
	movem.l (sp)+,d1-d6
.endplane2:

	; Third plane
	lea bobzone,a1 ; source
	move.l ScreenWork,a0 ; destination	
	add.l #bitplanesizebytes*2,a0 ; Second screen
	add.l d1,a0 ; add start offset
	movem.l d1-d6,-(sp)
	move.w copybobDitherPlane3,d0 ; Dither value (0 to 8)
	move.w copybobModePlane3,d1 ; Copy mode (1 2 3 4)
	Bsr DisplayBob	
	movem.l (sp)+,d1-d6
.endplane3:	
	
	rts
    
    
;---------------------------------------------------------- 
; A0 should not be changed, d0 and d1 d2 neither
	; d0 color1
	; d1 color2
	; d2 dither value
	; d3 bit to test
	; a1 result mode
	; a2 dither mode
computedithermode:
	btst d3,d0
	beq .color1isNull
	; ------ Color1 is at value 1
.color1isNotNull	
	btst d3,d1 ; Test color 2
	beq .color1isNotNullAndColor2isNull
	; Color2 is 1
	move.w #1,(a1) ; Color1 is 1, color 2 is 1, Use copy mode (mode 1)
	bra .colorexit
.color1isNotNullAndColor2isNull
	; Color2 is 0
	move.w #4,(a1) ; Color1 is 1, color 2 is 0, Use dither inverted (mode 4)
	bra .colorexit
	; ------ Color1 is at value 0
.color1isNull
	btst d3,d1 ; Test color 2
	beq .color1isNullAndColor2isNull
	; Color2 is 1
	move.w #3,(a1) ; Color1 is 0, color 2 is 1, Use dither (mode 3)
	bra .colorexit
.color1isNullAndColor2isNull
	; Color2 is 0
	move.w #2,(a1) ; Color1 is 0, color 2 is 0, so we copy in "empty" mode (2)
	;bra .colorexit
.colorexit
	rts
	
    CNOP 0,4
    
;---------------------------------------------------------- 
copybobModePlane1: ; 1 2 3 4
	dc.w	0
copybobDitherPlane1: ; 0 1 2 3 4 5 6 7 8
	dc.w	0
copybobModePlane2:
	dc.w	0
copybobDitherPlane2:
	dc.w	0	
copybobModePlane3:
	dc.w	0
copybobDitherPlane3:
	dc.w	0	
;---------------------------------------------------------------
    CNOP 0,4

colorblend: 
	dc.l	0 ; Which color to use. BBBB. B: Color1 index B: Color2 index B: Dither	
DitherTable:
	dc.l Dither12 ; 1
	dc.l Dither25 ; 2
	dc.l Dither37 ; 3
	dc.l Dither50 ; 4
	dc.l Dither62 ; 5
	dc.l Dither75 ; 6
	dc.l Dither87 ; 7

; D0 dither
; 1=12.5% 2=25% 3=37.5% 4=50% 5=62.5% 6=75% 7=87.5%
; Invert dither
DitherInv:
	move.w d1,-(sp)
	move.w #8,d1
	sub.w d0,d1
	move.w d1,d0
	move.w (sp)+,d1
	rts
;---------------------------------------------------------------
; A0 Dest adresss (Screen). Planes are side by side.
; A1 Source data
; d0 dithering (I use for dither 0=no dither, 1 to 7 is dither)
; d1 mode : 1 plain, 2 empty , 3 dither, 4 inv dither
; d5 with in bytes
; d6 lines nb
DisplayBob:

	; TODO MODE2. Make "hole".

	cmp.w #2,d1 ; For now mode 2 copy nothing
	beq .exit
	
	cmp.w #4,d1 ; Inverted dither
	bne .noinvertdither
	move.w #3,d1
	bsr DitherInv ; Inverse dither d0
.noinvertdither

	
	Clr.l	d2
	move.w d5,d7
	;lsr #3,d7 ; divide by 8 = number of bytes
	move.w #40,d4 ; next line modulo (screen is 40)
	sub.w d7,d4 ; modulo
	clr.l d3
	lsl.l #6,d6 ; *64
	lsr #1,d7 ; Compute width words
	add.l d7,d6 ; bltsize
    
    bsr	waitblitter
    
	; Modulos
	MOVE.W	#0,$DFF064	; MOD A Source
	MOVE.W	d4,$DFF060	; MOD C destination as source. Modulox2
	MOVE.W	d4,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	a1,$DFF050  ; SOURCE A
	MOVE.L	a0,$DFF048	; SOURCE C (Screen)	
	MOVE.L	a0,$DFF054	; SOURCE D
	Move.w	#0,$dff042	; Decay source B + flag line trace

	cmp.w #1,d1 ; Mode plain, no dither
	beq .withoutdither

	cmp.w #0,d0
	bne .withdither
	
.withoutdither:	
	; -- Without SOURCE B
	Move.w	#%0000101111111010,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	;         DDDDABCDMMMMMMMM 
	; All give 1 exept combinaison aBc and abc
	bra .next
.withdither:	
	; -- With source B (Dither)
	; Dither picture is 128pixels width, 100 lines high
	; Modulo is 16 - Widthbyte
	move.w #16,d2
	sub.w d5,d2
	MOVE.W	d2,$DFF062	; MOD B Mask
	sub.l #1,d0
	lsl.l #2,d0
	Lea DitherTable,a0
	MOVE.L	(a0,d0.w),$DFF04C  ; SOURCE B	
	Move.w	#%0000111111001010,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	;         DDDDABCDMMMMMMMM
	; Give0: AbC (pattern) LF5 aBc=LF2 abc=LF0  
.next	
	
	move.w d6,$dff058 ; BltSize, height*64 , width launch transfert
	;Move.w	#[8*1*64]+3,$dff058 ; BltSize, height*64 , width launch transfert
.exit:
	Rts
	
waitblitter:	
    ;tst.w	$dff002
.bltwt:	
    btst	#6,$dff002
    bne.s   .bltwt
    rts

    CNOP 0,4
;---------------------------------------------------------- 
; 1 2
; 3 4 ... We trace 1-2 , 2-4, 4-3, 3-1
quaddata:
;	dc.w	10,10 ; 1
;	dc.w	50,15 ; 2
;	dc.w	15,200 ; 3
;	dc.w    45,190 ; 4
	dc.w 	211,68
	dc.w	239,118
	dc.w	106,120
	dc.w	108,149
	; Computed min and max
	dc.w	0,0
	dc.w	0,0
	; Size X=bytes, Y=lines
	dc.W	0,0



; ------------------------------------------------------
; FX2 : Presents
; ------------------------------------------------------

Fx2_Init:

    bsr BackgroundAnimation_SwitchToBrightPalette
    
    ; Clear Screen.
    ; Clean 128 pixels
    bsr waitblitter
    move.w #0,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	move.l #screenBuffer1,d0
	move.l d0,$dff054   ;destination address
	move.w #87*64+(40/2),$dff058 ;blitter operation size
    
	move.l #screenBuffer1,d0
	Lea copScrSet,a1
	swap d0
	move.w d0,2(a1)
	swap d0
	move.w d0,6(a1)  

    lea Planes87,a0
    move.w #($0200|(1<<12)),2(a0) ; 1 plane
    
    bsr Fx2_EnableCenterGradient
    
    ; Set colors
    lea copPal+6,a0
    move.w #$fff,(a0)
    
    bsr Fx2_InitNextLine
    bsr Fx2_InitNextLine
    bsr Fx2_InitNextLine
    bsr Fx2_InitNextLine
    bsr Fx2_InitNextLine
    rts

Fx2_Loop:

    rts

Fx2_Irq:
    bsr Fx2_DoProcessParalelLines
    rts

Fx2_EnableCenterGradient:
   ;PresentPAL:
   ;dc.l	(PRESENTLINESTART<<24)|($09fffe)    ,$01820669 ; Line 1 
    lea PresentPAL+4,a0
    move.w #29-1,d0
.loop
    move.w #$0182,(a0)
    add.l #8,a0
    dbra d0,.loop
    rts
    
Fx2_DisableCenterGradient:
    lea PresentPAL+4,a0
    move.w #29-1,d0
.loop
    move.w #$00F6,(a0) ; Bitplan 6 pointer
    add.l #8,a0
    dbra d0,.loop
    rts    


; ----------------------------------
; d1.w = X, d2.w = Y
Fx2_DrawPixel:
    movem.l a1/d1-d4,-(a7)
    ; Center screen
    add.w #(320-(79+85)-10)/2,d1 ; Center X
    add.w #(87-30)/2,d2 ; Center Y

    mulu.w #40,d2 ; Y
    move.b d1,d3 ; X
    lsr.b #3,d1 ; /8 = byte (0 to 40)
    and.l #$000000ff,d1
    and.l #$00000007,d3 ; pixel (0 to 7)
    ;move.b d1,$102
    ;move.b d3,$103
    lea screenBuffer1,a1
    add.l d2,a1 ; Y
    add.w d1,a1 ; X byte
    move.b #$80,d4
    lsr.b d3,d4
    or.b d4,(a1)
    movem.l (a7)+,a1/d1-d4   
    rts

; ----------------------------------

Fx2_DoProcessParalelLines:
    ; Check all entries and do the process for all the active ones
    move.w #$FAFA,d0 ; Flag mean "nothing active", to test end.
    lea ArrayLineProcessed,a0
    move.w #NUMBERPARALELLINES-1,d7
.loop:
    cmp.w #$ffff,(a0)
    beq .notactive
    ; Process line draw : Check if arrived (then stop), else Draw point and move next.
    move.w 8(a0),d0
    cmp.w (a0),d0
    bne .notend
    move.w 10(a0),d0
    cmp.w 2(a0),d0
    bne .notend
    ; End reached
    move.w #$FFFF,(a0)
    bsr Fx2_InitNextLine ; Next line
    bra .notactive
.notend:
    ; Draw pixel
    move.w (a0),d1
    move.w 2(a0),d2
    bsr Fx2_DrawPixel
    ; Add increments
    move.w 4(a0),d0
    add.w d0,(a0)
    move.w 6(a0),d0
    add.w d0,2(a0)
    ; Go to next line
.notactive
    add.l #6*2,a0 ; Next line
    dbra d7,.loop
    ; No line active ?
    cmp.w #$FAFA,d0
    bne .stillactive
    move.w #3,StepCurrent ; End current FX, go to next 
.stillactive:    
    rts
; ----------------------------------
FindFreeParalelLines:
    ; Check all entries and do the process for all the active ones
    lea ArrayLineProcessed,a0
    move.w #NUMBERPARALELLINES-1,d7
.loop:
    cmp.w #$ffff,(a0)
    bne .active
    rts ; return A0 ok
.active
    add.l #6*2,a0 ; Next line
    dbra d7,.loop
    move.l #-1,a0 ; a0 = -1 = Not found
    rts
; ----------------------------------

Fx2_InitNextLine:
    move.l PointerToLineOperation,a1 ; Pointer to offset to line.
    
    cmp.b #$FF,(a1)
    beq .endfxreached
    
    add.l #1,PointerToLineOperation
    
    clr.l d0
    move.b (a1),d0 ; Offset to lines
    move.b #$FE,(a1) ; flag "processed"
    lsl #2,d0 ; *4 = Offset
    lea DataPresents,a1
    add.l d0,a1 ; // Here we got data (in byte)
    
    bsr FindFreeParalelLines ; Slot a0 is free
    cmp.l #-1,a0
    beq .endreached ; Nothing free

    clr.l d0
    clr.l d1
    clr.l d2
    clr.l d3
    
    ; Start
    
    move.b (a1),d0 ; Start X
    move.w d0,(a0) ; Current X

    move.b 1(a1),d1 ; Start Y
    move.w d1,2(a0) ; Current Y
    
    ; End
    move.b 2(a1),d2 ; End X
    move.w d2,8(a0)

    move.b 3(a1),d3 ; End Y
    move.w d3,10(a0)

    ; Increment 0 1 or -1
    
    clr.w 4(a0) ; Clear increments.
    clr.w 6(a0)
    
    ; Increment X
    cmp.w d0,d2
    beq .processY
    bgt .destXsuperior
    move.w #-1,4(a0)
    bra .processY
.destXsuperior
    move.w #1,4(a0)

.processY
    ; Increment Y
    cmp.w d1,d3
    beq .endreached
    bgt .destYsuperior
    move.w #-1,6(a0)
    bra .endreached
.destYsuperior
    move.w #1,6(a0)

.endreached:
    rts
    
.endfxreached:
    ;move.w #3,StepCurrent ; End current FX, go to next    
    rts  


; ----------------------------------
NUMBERPARALELLINES = 10

ArrayLineProcessed:
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"
    dc.w $FFFF,0,0,0,0,0 ; Current X, Current Y, Increment X, Increment Y, end X, End Y .... $FFFF for first X means "Free"

NUMBERLINES=77

PointerToLineOperation:
    dc.l LinesOperations

LinesOperations: ; $fe means done.
    dc.b 63
    dc.b 36
    dc.b 1
    dc.b 4
    dc.b 69
    dc.b 39
    dc.b 25
    dc.b 73
    dc.b 61
    dc.b 54
    dc.b 11
    dc.b 20
    dc.b 3
    dc.b 50
    dc.b 27
    dc.b 22
    dc.b 29
    dc.b 26
    dc.b 72
    dc.b 56
    dc.b 13
    dc.b 9
    dc.b 44
    dc.b 58
    dc.b 28
    dc.b 30
    dc.b 74
    dc.b 43
    dc.b 48
    dc.b 16
    dc.b 62
    dc.b 21
    dc.b 7
    dc.b 41
    dc.b 5
    dc.b 38
    dc.b 6
    dc.b 18
    dc.b 57
    dc.b 67
    dc.b 0
    dc.b 47
    dc.b 12
    dc.b 70
    dc.b 37
    dc.b 52
    dc.b 64
    dc.b 65
    dc.b 17
    dc.b 42
    dc.b 46
    dc.b 32
    dc.b 19
    dc.b 59
    dc.b 53
    dc.b 33
    dc.b 2
    dc.b 75
    dc.b 71
    dc.b 45
    dc.b 76
    dc.b 51
    dc.b 55
    dc.b 23
    dc.b 31
    dc.b 34
    dc.b 15
    dc.b 66
    dc.b 49
    dc.b 60
    dc.b 8
    dc.b 35
    dc.b 10
    dc.b 40
    dc.b 14
    dc.b 68
    dc.b 24
    dc.b $ff; End list 

DataPresents:
    ; P
    dc.b 1,1,1,27
    dc.b 2,8,2,27
    dc.b 3,20,3,27
    dc.b 4,20,4,27
    ; P Diagonals
    dc.b 8,1,16,9
    dc.b 16,10,8,18
    dc.b 8,3,14,9
    dc.b 14,10,8,16
    dc.b 8,5,12,9
    dc.b 12,10,8,14
    ; R
    dc.b 1+19,1,1+19,27
    dc.b 2+19,8,2+19,27
    dc.b 3+19,20,3+19,27
    dc.b 4+19,20,4+19,27
    ; R Diagonals
    dc.b 8+19,1,16+19,9
    dc.b 16+19,10,8+19,18
    dc.b 8+19,3,14+19,9
    dc.b 14+19,10,8+19,16
    dc.b 8+19,5,12+19,9
    dc.b 12+19,10,8+19,14
    ; R bottom diagonal
    dc.b 27,18,36,27
    dc.b 27,19,35,27
    ; E
    dc.b 39,1,57,1
    dc.b 39,1,39,27
    dc.b 39,27,57,27
    dc.b 41,14,56,14
    dc.b 44,10,54,10
    dc.b 44,11,54,11
    dc.b 44,17,54,17
    dc.b 44,18,54,18
    ; S
    dc.b 61,1,78,1
    dc.b 61,1,61,14
    dc.b 61,14,79,14
    dc.b 79,14,79,27
    dc.b 79,27,61,27
    dc.b 64,3,76,3
    dc.b 65,4,75,4
    dc.b 65,11,75,11
    dc.b 64,12,76,12
    dc.b 64,16,76,16
    dc.b 65,17,75,17
    dc.b 65,24,75,24
    dc.b 64,25,76,25
    ; E
    dc.b 39+43,1,57+43,1
    dc.b 39+43,1,39+43,27
    dc.b 39+43,27,57+43,27
    dc.b 41+43,14,56+43,14
    dc.b 44+43,10,54+43,10
    dc.b 44+43,11,54+43,11
    dc.b 44+43,17,54+43,17
    dc.b 44+43,18,54+43,18
    ; N
    dc.b 103,1,103,27
    dc.b 104,7,104,27
    dc.b 105,20,105,27
    dc.b 106,20,106,27
    ; diag
    dc.b 104,7,120,23
    ;
    dc.b 118,1,118,8
    dc.b 119,1,119,8
    dc.b 120,1,120,23
    dc.b 121,1,121,27
    ; T
    dc.b 126,1,142,1
    dc.b 130,3,138,3
    dc.b 130,4,138,4
    dc.b 134,5,134,27
    ; S
    dc.b 61+85,1,78+85,1
    dc.b 61+85,1,61+85,14
    dc.b 61+85,14,79+85,14
    dc.b 79+85,14,79+85,27
    dc.b 79+85,27,61+85,27
    dc.b 64+85,3,76+85,3
    dc.b 65+85,4,75+85,4
    dc.b 65+85,11,75+85,11
    dc.b 64+85,12,76+85,12
    dc.b 64+85,16,76+85,16
    dc.b 65+85,17,75+85,17
    dc.b 65+85,24,75+85,24
    dc.b 64+85,25,76+85,25
    dc.b $ff ; End
	
	even


; ------------------------------------------------------
; FX3 : Rotating letters, scrolling
; ------------------------------------------------------

Fx3_Init:
    bsr setPalette 
    bsr SetBackPalette
    
    move.w #SCROLLMINI,scrollcount ; For faster machines, be sure that scroll have done the minimum steps. USe SCROLLMINI so will not work for first time.
    
    ; Clean video memory
    bsr waitblitter ; Wait blitter to be ready
	move.w #0,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	move.l #BufferChips,a0
    move.l a0,$dff054   ;destination address
	move.w #(SCREENH*4*64)+(LINE_PITCH/2),$dff058 ; blitter operation size. Triple buffer + scrolling plane
    bsr waitblitter ; Wait end of clean operation.  
    
    ;bsr BackgroundAnimation_TriggerBackAnim
    bsr triplebufferswap
    
    move.l #BigScroll,d0
    lea     copScrSet,a1
    addq.w  #8,a1
    move.w  d0,6(a1)
    swap    d0
    move.w  d0,2(a1)

    lea Planes87,a0
    move.w #($0200|(2<<12)),2(a0) ; 2 plane
    
    bsr Fx2_DisableCenterGradient ; disable copper gradient
    
    ; Clean array
    lea ArrayQuad,a0
    move.w #255,d0
.erase
    move.w #0,(a0)+
    dbra d0,.erase
    rts

; -------------------------------------------------------------------------------
Fx3_Loop:
    bsr waitblitter ; Be sure that erase is finished (for faster machines)
    bsr triplebufferswap
    bsr erasebackscreen ; SCR3
    bsr Fx3_drawletter ; This can take 1, 2, 3 frames depending on machine speed
.testVBL 
    cmp.w #2,VBLCount ; Some machine already have 2 VBL when coming here (some have 3).
    bge .ok
    bsr pollVSync
    bra .testVBL
.ok:
    move.w #0,VBLCount ; Reset VBL count.
    rts
    
; -------------------------------------------------------------------------------
Fx3_Irq:
    bsr Fx3_DoScroll ; Need to be done after scroll display.
    cmp.w #0,forceWait
    beq .notinuse
    sub.w #1,forceWait ; Decrease this counter here, so it is constant
.notinuse:    
    rts   
    
; -------------------------------------------------------------------------------
Fx3_DoScroll:
    add.w #1,scrollcount
    bsr waitblitter ; Wait blitter to be ready
	MOVE.W	#0,$DFF064	; MOD A Source
	MOVE.W	#0,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFF0,$DFF044 ; First word mask and last word
	MOVE.L	#BigScroll+(21*40)+2,$DFF050  ; SOURCE A
	MOVE.L	#BigScroll+(21*40),$DFF054	; SOURCE D
	Move.w	#0,$dff042			; Decay source B + flag line trace
	Move.w	#0,d2 ; Decay value
SCROLLTEXTSPEED = 1    
	Move.w	#((16-SCROLLTEXTSPEED)<<12),d2 ; Decay value
	OR.W	#%0000100111110000,D2 ; X9f0 , X is speed 16-Speed
	;             1234         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	move.w #(47<<6)+20,$dff058 ; BltSize, height*64 , width launch transfert
    rts

NBSTEPS = 18 ; Animation steps

    CNOP 0,8

drawstep:
    dc.l  (NBSTEPS-1)*100 ; 0 to 100*49  
currentletter:
    dc.l LettersSequence
LettersSequence:

    dc.l LetterA
    
    dc.l 0

    dc.l LetterN
    dc.l LetterE
    dc.l LetterW 
    
    dc.l 0
    
    dc.l LetterP   
    dc.l LetterR
    dc.l LetterO      
    dc.l LetterD
    dc.l LetterU  
    dc.l LetterC
    dc.l LetterT
    dc.l LetterI
    dc.l LetterO
    dc.l LetterN
    
    dc.l 0
 
    dc.l LetterC
    dc.l LetterA
    dc.l LetterL
    dc.l LetterL
    dc.l LetterE
    dc.l LetterD
    
    dc.l 0
    dc.l 0
    dc.l 0
    dc.l 0
        
    dc.l $ffffffff
  
forceWait: ; For Space character
    dc.w    0
scrollcount:
    dc.w    0 ; Be sure that scroll have enough moved before launching next letter.
    
SCROLLMINI = 58 ; // Minimum pixels before drawing next letter (for faster machines)

; -----------------------------------------------------
Fx3_drawletter:

    ; For space, need to wait some time before next letter.
    ; The counter decrease is done in IRQ, so time is constant on fast machines.
    ;move.w forceWait,$100
    cmp.w #0,forceWait
    beq .nowait
    ;sub.w #1,forceWait ; Done in IRQ
    rts
.nowait:
    ; If draw steps is over
    ;move.w scrollcount,$100
    ;move.l drawstep,$102
    cmp.l #(NBSTEPS-1)*100,drawstep ; Do we just ended a letter ?
    bne .nowaitscroll
    cmp.w #SCROLLMINI,scrollcount ; for faster machines, be sure scrolling have move enough
    bhi .nowaitscroll
    rts
.nowaitscroll:

    cmp.l #(NBSTEPS-1)*100,drawstep ; Do we just ended a letter ?
    bne .noresetscroll
    move.w #0,scrollcount ; reset scroll count
.noresetscroll:

    ; Draw Letter
    move.l currentletter,a1 ; A1 current polygon
    move.l (a1),a1
    cmp.l #0,a1 ; Space Again ?
    beq drawletter_nextletter
    cmp.l #$ffffffff,a1
    beq drawletter_EndSequence ; End sequence

    ; Draw a letter
    lea Pointrotating,a0
    add.l drawstep,a0
    
    ; Reset min and max. (will need to be updated)
    move.b #255,ArrayQuadMinY
    move.b #0,ArrayQuadMaxY ; This is max Y

drawletter_looppolygon:

    cmp.b #$fe,1(a1)
    beq drawletter_endpoly
    
    ; Draw line between index (a1) and 1(a1)
    moveq #0,d0
    moveq #0,d1
    move.b (a1),d0
    move.b 1(a1),d1
    subq #1,d0
    subq #1,d1
    bsr drawlineinarrayfromindex ; Draw line in array

    addq #1,a1
    bra drawletter_looppolygon ; Next line

drawletter_endpoly:
    
    bsr DrawArray
    addq #2,a1

    cmp.b #$ff,(a1)
    beq drawletter_end ; Last quad reached.
    
    bra drawletter_looppolygon ; Next polygon

drawletter_end:
    ; Next frame
    sub.l #100,drawstep
    cmp.l #-100,drawstep ; Last draw step was 0
    bne drawletter_end2
    ; End of one letter
    bsr copylettertoscroll
    move.l #(NBSTEPS-1)*100,drawstep
    ; -- next letter ------------------
drawletter_nextletter: 
    add.l #4,currentletter
    move.l currentletter,a0
    ; Test end sequence
    cmp.l #$ffffffff,(a0)
    bne drawletter_noend
drawletter_EndSequence:     
    ;move.w #$4,$100
    move.w #4,StepCurrent ; End current FX, go to next
    move.w #100,forceWait
    bra drawletter_end2
drawletter_noend:
    ; Test Space
    cmp.l #$0,(a0)
    bne drawletter_end2
    move.w #SCROLLMINI-15,forceWait ; Wait a bit to create space
    add.l #4,currentletter
    ;bra drawletter_end2
drawletter_end2:
    rts
    ; -------------------------
    ; d0 index 1
    ; d1 index 2
drawlineinarrayfromindex:
    movem.l a0-a1,-(a7)
    ; Get pixel coords
    lsl.l #1,d0 ; index Point 1
    lsl.l #1,d1 ; Index Point 2
    ;move.b #1,$102
    lea dataline,a4
    move.b 1(a0,d0.w),d2; 3(a4) ; Y1    
    move.b 1(a0,d1.w),d3; 7(a4) ; Y2
    ; Y going up or down ?
    ; Default is down
    ;move.w 2(a4),d6
    ;cmp.w 6(a4),d6
    cmp.b d2,d3
    bhi .nochange
    ; Going up, so need to switch points and draw on right side of array
    ; -- Exchange both points.
    move.l #1,ArrayOffsetIfUp
    move.b (a0,d1.w),1(a4) ; X2
    move.b (a0,d0.w),5(a4) ; X1    
    move.b d2,7(a4) ; Exchange Y
    move.b d3,3(a4)
    ; Exchange D2 and D3
    exg.b d2,d3
    bra .next
.nochange
    move.l #0,ArrayOffsetIfUp ; First descend
    move.b (a0,d0.w),1(a4) ; X1
    move.b d2,3(a4) ; No Exchange Y
    move.b (a0,d1.w),5(a4) ; X2 
    move.b d3,7(a4)
    
.next:
    ; -- Check min and max of Y
    ;move.b 3(a4),d0
    cmp.b ArrayQuadMinY,d2 ; start at 255, we want the min value
    bhi .nomin
    move.b d2,ArrayQuadMinY
.nomin
    ;move.b 7(a4),d0
    cmp.b ArrayQuadMaxY,d3 ; start at 0, we want the max value
    bmi .nomax
    move.b d3,ArrayQuadMaxY
.nomax

    lea dataline,a1
    bsr drawlineinarray

    movem.l (a7)+,a0-a1
    rts

;    Pointrotating: ; 49 points ; 50 frames. Reverse. 
; include "d:\Kristof\Amiga_Dev\OriensSequencerTool\Bin\framepoints.txt"
;
;LetterA:
;    dc.b 2,7,40,45,46,41,32,2,$fe
;    dc.b 2,32,29,2,$fe
;    dc.b 2,29,30,26,11,5,2,$fe
;    dc.b 30,35,43,48,49,44,26,30,$fe
;    dc.b $ff

; Letter is in SCR3 + 26 (to 40)
; Big scroll + 26 to 40
; 87 lines.

copylettertoscroll:
    movem.l a0-a1/d0,-(a7)
    ; Source
    move.l SCR2,a0
    add.l #26,a0
    add.l #21*40,a0 ; First lines are empty
    ; Dest
    move.l #BigScroll,a1
    add.l #26,a1
    add.l #21*40,a1 ; First lines are empty
    move.w #47-1,d0
.loop
    move.w (a0)+,d1
    or.w d1,(a1)+
    move.w (a0)+,d1
    or.w d1,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    move.w (a0)+,(a1)+
    add.l #40-10,a0
    add.l #40-10,a1
    dbra.w d0,.loop
    
    ; Clear source.
    move.l SCR2,a0
    add.l #26,a0
    add.l #21*40,a0 ; First lines are empty
    move.w #47-1,d0
.loop2
    clr.w (a0)+
    clr.w (a0)+
    clr.w (a0)+
    clr.w (a0)+
    clr.w (a0)+
    add.l #40-10,a0
    dbra.w d0,.loop2
    
    movem.l (a7)+,a0-a1/d0
    rts
  
; ----------------------------------
; Draw array of 256 lines, with pair of X start X end.
; First pixel is 1 .... 8 is last pixel of first byte.
; 9 is first pixel of bytes 2 and so on.
DrawArray:
    ;move.w #$0f0,$dff180

    movem.l a0-a6/d0-d7,-(a7)

    moveq #0,d0
    moveq #0,d2
    move.b ArrayQuadMinY,d0
    move.b d0,d2 ; Keep start Y
    lsl.w #1,d0
    lea ArrayQuad,a0
    add.l d0,a0 ; Start Y adress
    
    moveq #0,d1
    move.b ArrayQuadMaxY,d1
    lsl.l #1,d1
    lea ArrayQuad,a1
    add.l d1,a1 ; End Y adress
    
    moveq #0,d1
    
    ; A3 = Line to draw
    moveq #0,d3
    move.l d2,d3
    move.l d2,d4
    
    ;mulu #40,d3
    lsl.l #5,d3;*32
    lsl.l #3,d4;*8

    move.l SCR2,a3
    add.l d3,a3 ; Start line Y
    add.l d4,a3 ; Start line Y
    add.l #26,a3 ; Offset X.
    
    ;move.b #1,$104 ; For breakpoint    
    
.drawArray
    ;move.w #$040,$dff180
    moveq.l #0,d1
    move.b (a0),d1 ; X start
    ;cmp.b #0,d1 ; Not possible to have 0 on X
    beq .next
    ; Same pixel ?
    move.b 1(a0),d0
    cmp.b d0,d1
    bne .noegal
    bsr DrawPixelOnLine ; A3 is start of current line
    bra .next
.noegal: 
    ;move.w #$060,$dff180
    cmp.b d0,d1 ; 1(a0) X start should always be lower than D2.
    bhi .next ; TODO should never happend (else line trace is bad) 

    ;moveq.l #0,d2
    moveq.l #0,d5  
    
    ; Get X start and X end.
    subq #1,d1 ; Align to rest from 0 to 7 (instead of 1 to 8)
    move.b d1,d5 
    and.b #$07,d5 ; Rest of division by 8, means, number of pixels, not to draw
    lsr.w #3,d1 ; Start byte
    move.l a3,a4 ; Copy line screen
    add.l d1,a4 ; Add start bytes screen 
    moveq #0,d2
    moveq #0,d6 ; Important
    move.b d0,d2 ; X End 1(a0)
    subq #1,d2
    move.b d2,d6
    and.b #$07,d6 ; Rest of division by 8, means, number of pixels, not to draw
    lsr.w #3,d2 ; End BYTE
    
    ; -- Test if start byte is same as end byte.
    cmp.b d1,d2
    bne .nosamebyte
    ;move.w #$080,$dff180
    ; Need to draw only the difference pixels
    ; D5 to D6
    ; Example Xstart=12, Xend=14.... Same byte. Pixel start 4 , pixel end 6.
    moveq #0,d7 ; Important
    move.b #$7,d0
    sub.b d5,d0 ; Start bit.
    ; Count bits to set
    sub.b d5,d6 ; Number of bits to set.
.setbits
    bset.b d0,d7
    subq #1,d0
    dbra d6,.setbits
    or.b d7,(a4)+
    bra .next ; -- End on same byte   
.nosamebyte:     
    ; -- Test if first byte is complete or not.
    cmp.b #0,d5
    beq .firstbyteiscomplete
    ;move.w #$0a0,$dff180
    ; process first byte
    move.w #$FF,d7 ; Full 8 pixels, decayed on right
    lsr.w d5,d7
    or.b d7,(a4)+ ; Print pixels
    addq #1,d1 ; Skip first byte
.firstbyteiscomplete: 
    ;move.w #$0c0,$dff180
    sub.b d1,d2 ; Number of steps
    beq .processlastbyte ; maybe we do not have some middle values, so go to end value
    subq #1,d2
.loopline ; -- Process all middle bytes
    ;cmp.b d1,d2 ; D1 should always be lower or equal than D2.
    ;beq .processlastbyte ; maybe we do not have some middle values, so go to end value
    ; Process all middle bytes (this can be optimized)
    ; D1 to D2 (not included)
    move.b #$ff,(a4)+
    ;add.l #1,a4 ; DEBUG, display nothing
    addq #1,d1    
    ;bra .loopline
    dbra d2,.loopline
    ; -- Process last byte
.processlastbyte
    ;move.w #$0e0,$dff180
    cmp.b #7,d6 ; 0 to 7
    beq .lastbyteiscomplete2
    move.w #$00FF,d7 ; Full 8 pixels, decayed on left
    moveq #$7,d2
    sub.w d6,d2 ; 1 to 7 converted to 7 to 1
    lsl.w d2,d7
    or.b d7,(a4) ; Print pixels
    bra .next
.lastbyteiscomplete2: 
    move.b #$FF,(a4)
.next:
    ;move.w #$0f0,$dff180
    
    addq #2,a0 ; next pair of X/X
    add.l #40,a3 ; Next line on screen.

    ; -- Test end of array
    cmp.l a0,a1
    beq EndDrawArray
    bra .drawArray
EndDrawArray:
    
    movem.l (a7)+,a0-a6/d0-d7
    
    ;move.w #$000,$dff180
    rts

; ----------------------------------
; d1.w = X, a3=Start of line
DrawPixelOnLine:
    movem.l a3/d1-d4,-(a7)
    subq #1,d1 ; Be sure to draw pixel 1 to 8 on one byte
    move.w d1,d3 ; X
    lsr.w #3,d1 ; /8 = byte (0 to 40)
    and.l #$000000ff,d1
    and.l #$00000007,d3 ; pixel (1 to 8) convert to 0 to 7
;    bne .no0
;    move.w #8,d3 ; If value is 0 then convert to 8
;    sub.l #1,d1
;.no0:
    add.w d1,a3 ; X byte
    move.w #$80,d4
    lsr.w d3,d4
    or.b d4,(a3)
    movem.l (a7)+,a3/d1-d4   
    rts
;---------------------------------------------------------------
; Toujours tracer vers Y en bas (augmentent). Seuls X peuvent aller droite ou gauche
; 0(a1) X1
; 2(a1) Y1
; 4(a1) X2
; 6(a1) Y2
drawlineinarray:
    ;move.w #$00F,$dff180
    movem.l d0-d6/a0-a2,-(a7)
    
    lea ArrayQuad,a2
    moveq #0,d3
    move.w 2(a1),d3
    lsl #1,d3 ; *2
    add.l d3,a2

    move.b 3(a1),d1 ; Same Y ? TODO special case, one line only
    cmp.b 7(a1),d1
    beq exitarrayOneLine
    
    add.l ArrayOffsetIfUp,a2 ; 0 or 1, column left or right    

    ; X2 = 0 is not possible
    cmp.b #0,5(a1)
    beq exitarray
    
    ; X1 = 0 is not possible
    cmp.b #0,1(a1)
    beq exitarray    

    bsr z3_calc_chiffre ; Calc increment.
    
    ; Trace ligne
    moveq #0,d1
    move.w (a1),d1 ; X start
    moveq #0,d2
    move.w 2(a1),d2 ; Y Start
    ;move.b #1,$101 ; Debug breakpoint
    move.w etape3d,d6
    subq #1,d6
    move.l incrx3d,d5
    move.l incry3d,d3 ; 1 or -1
    ;move.l incry3d,d7 ; 1 or -1
    ;move.l d7,d3 ; -1 or 1
    lsl.l #1,d3 ; -2 or 2 ; Increment Y
;    cmp.b #1,ArrayOffsetIfUp
;    bne .noup
;    add.l d3,a2 ; Next line in Y array (up or down) ; CK : Why ?
;.noup

    ; Add 0.5 to everyone, so do not change line for small values.
    ; USELESS
    ;add.l #$00008000,d1 ; Add 0.5 to round the pixel position


    ; Go left or right
    ; This seem bugged !! ==> Yes, USELESS
;    swap d1
;    cmp.l #0,d5
;    bpl .goright
;    ;sub.l #$00008000,d1 ; Go left, sub 0.5 to round the pixel position
;    sub.l #$00000800,d1 ; Go left, sub 0.5 to round the pixel position
;    bra .goend
;.goright    
;    ;add.l #$00008000,d1 ; Add 0.5 to round the pixel position
;    add.l #$00000800,d1 ; Add 0.5 to round the pixel position
;.goend
;    swap d1
    
.alllines
    move.b d1,(a2) ; Fill array
    ;bsr DrawPixel ; DEBUG d1=X d2=Y
    
    swap d1
    add.l d5,d1 ; Increment X
    swap d1
    
    ;add.l d7,d2 ; next Y
    add.l d3,a2 ; Next line in Y array (up or down)
    
    dbra d6,.alllines
    
exitarray:    
    movem.l (a7)+,d0-d6/a0-a2
    ;move.w #$000,$dff180
    rts
    
exitarrayOneLine
    ; Fill only one line, so fill X start, X end and exit.
    move.b 1(a1),(a2)
    move.b 5(a1),1(a2)
    ; 0(a1) X1
    ; 2(a1) Y1
    ; 4(a1) X2    
    movem.l (a7)+,d0-d6/a0-a2
    ;move.w #$000,$dff180
    rts  

    CNOP 0,4    

ArrayQuad:
    blk.w 256 ; // Each line is 2 bytes. X start, X end.
ArrayQuadMinY;
    dc.b    0
ArrayQuadMaxY;
    dc.b    0    
ArrayOffsetIfUp: ; 0 first column, 1 second column (going up)
    dc.l    0
    
; Point1 (X/Y) 12/14
; Point2       70/120
; Delta X = 70-12 = 58
; Delta Y = 120-14 = 106
; Chaque Y, X avance de 58/106 = 0,5471698113207547169811320754717
; En 16 bits 
; 35859,320754716981132075471698113 = $8c13

;$00008c00 .... Increment en float fixe. = incrx3d
;  incry3d = 1 or -1
;  etape3d.w = $6a = 106
; invert_incr_3x = 0 si on increment les X, sinon 1 si on decremente

dataline:
    dc.w    0,0
    dc.w    0,0
    
    CNOP 0,4

;---------------------------------------------------------------
incrx3d:		dc.l	0
incry3d:		dc.l	1
etape3d:		dc.w	0
		even
;----------------------------------------------------------------------
; .w (a1)  X1
; .w 2(a1) Y1
; .w 4(a1) X2
; .w 6(a1) Y2
; Will compute incrx3d, incry3d, etape3d and invert_incr_3x
z3_calc_chiffre:
    ;move.w #$f00,$dff180 ; RED
	move.l	#1,incry3d
	clr.b	d5; invert_incr_3x
	move.w	2(a1),d1 ; Y1
	move.w	6(a1),d0 ; Y2
	ext.l	d1
	ext.l	d0
	cmp.l	d1,d0
	bpl	ok_3y
	exg.l	d0,d1
	neg.l	incry3d
ok_3y:
	sub.l	d1,d0		; diff des y
    add.l   #1,d0       ; Add one to draw last Y. We want [Y1 to Y2] both included
	move.w	d0,etape3d	; nombre de points en y
    ; X
	move.w	(a1),d2
	move.w	4(a1),d1
	ext.l	d2
	ext.l	d1
	cmp.l	d2,d1
	bpl	ok_3x
	exg.l	d2,d1
	move.b	#1,d5; invert_incr_3x
ok_3x:	
    sub.l	d2,d1
    add.l #1,d1 ; Add 1 to have correct increment.
	; d0.l difference des y
	; d1.l difference des x
	move.l	d1,d2
	divu.w	d0,d2		; y x
	and.l	#$0000ffff,d2	; partie entière
	lsl.l	#8,d1	;x	; mulu $10000		pb si d1 > 255
	divu.w	d0,d1		; d1 = incrementation
	lsl.l	#8,d1		; ...	
	and.l	#$0000ffff,d1
	swap	d2
	add.l	d2,d1		; d1 le chiffre a vigule
	tst.b	d5; invert_incr_3x
	beq	.no_invert
	neg.l	d1
.no_invert
	move.l	d1,incrx3d
    ;move.w #$00F,$dff180
	rts
    
    CNOP 0,4

SCR1:           dc.l    screenBuffer1
SCR2:           dc.l    screenBuffer2
SCR3:           dc.l    screenBuffer3
frame:          dc.w    0


; ----------------------------------------
; FX4 Logo
; ----------------------------------------

Fx4_Init:

    bsr BackgroundAnimation_SwitchToDarkPalette2 ; Switch to dark palette for final logo.
    
    ; Background effect
    ; bsr SetBackPalette ; useless ?
    move.w #0,VBLCount ; Reset VBL count.    
    
    ; Delete 4 planes of 87 lines.
    bsr waitblitter ; Wait blitter to be ready
	move.w #0,$dff066			;destination modulo
	move.l #$01000000,$dff040	;set operation type in BLTCON0/1
	move.l #BufferChips,a0
    move.l a0,$dff054   ;destination address
	move.w #(SCREENH*4*64)+(40/2),$dff058 ;blitter operation size 
    bsr waitblitter ; Wait blitter to be ready
    
    ; Set planes pointers
    move.l #BufferChips,d0
    lea     copScrSet,a1
    move.w #4-1,d1
.loopsetplanes
    move.w  d0,6(a1)
    swap    d0
    move.w  d0,2(a1)
    swap    d0
    add.l #87*40,d0
    add.l #8,a1
    dbra d1,.loopsetplanes
    ; Set Palette from ami
    lea Logo,a0
    add.l #2+2+2+4,a0 ; Skip header
    lea copPal+4,a1 ; dest
    add.l #2,a1
    add.l #2,a0 ; skip first color (black)
    move.w #16-1-1,d0
.loopcopycolors
    move.w (a0)+,(a1)
    add.l #4,a1
    dbra d0,.loopcopycolors
    
    ; Set 4 planes
    lea Planes87,a0
    move.w #($0200|(4<<12)),2(a0) ; 4 plane
    
    ; Wait a bit so the colors are correct (transition)
    move.w #50,d0
    bsr WaitFrames ; Wait 1 second
    
    ; Set data from ami
    ; copScrSet: 
    ;40*64 per plane
    lea Logo,a0
    add.l #2+2+2+4,a0 ; Skip header
    add.l #16*2,a0 ; skip colors
    lea BufferChips,a1 ; 87 lines high
    add.l #((87-64)/2)*40,a1 ; Center Y
    move.w #4-1,d4
.planes
    ; Copy one plane
    move.w #(40*64)-1,d3
.copyplane
    move.b (a0)+,(a1)+
    dbra d3,.copyplane
    add.l #(87-64)*40,a1
    dbra d4,.planes

    

    
    rts

Fx4_Loop:
    ;move.w VBLCount,$102

    move.w #1,d0
    bsr WaitFrames ; Wait 1 Frame
    
    ; -- Get pattern position
    
   move.l	(LDOS_BASE).w,a6
   jsr		LDOS_MUSIC_GET_POSITION(a6) ; d0 = position d1 = pattern
   ;move.w d0,$100
   ;move.w d1,$102

   cmp.w #7,d0
   bne .noend
    ;cmp.w #12*50,VBLCount ; 12 seconds of logo
    ;bmi .noend
   move.w #0,VBLCount
   move.w #6,StepCurrent ; end of effect , fade out
.noend:

    rts

Fx4_Irq:

    rts
    
    
; ------------------------------------------- 
; Set Minimal Sprite in copper 
; While Sprite zone is computed
SetSpriteInCopper:
    ; Set 8 sprites to 0
 	Lea	SpritesCopper,a0
    move.l	#NullSprite,d0
    move.w #8-1,d1
.setnulsprite:    
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
    swap    d0
    add.l #8*1,a0    
    dbra d1,.setnulsprite  

    ; Set test sprite
    Lea	SpritesCopper,a0
    move.l	#SpriteLine,d0
    Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)

    Lea	SpritesCopper+8,a0
    move.l	#SpriteLine2,d0
    Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)
    
    ; Also set blank planes and negative modulos
    
    move.l #EmpyLine,d0
    lea copScrSetPlan1,a1
    move.w  d0,6(a1)
    swap    d0
    move.w  d0,2(a1) 
    ; modulo is -40 so will loop on same line again and again

    move.l #EmpyLine,d0
    lea copScrSetPlan1b,a1
    move.w  d0,6(a1)
    swap    d0
    move.w  d0,2(a1) 
    ; modulo is -40 so will loop on same line again and again
    
    rts
 
; ----------------------------------------
; Data Fast mem
; ----------------------------------------
 
	data_f

; EFFECT 1 : 3D letters

Obj3d_R:
	Incbin	"data/Obj_R.bin"	
		
Obj3d_S:
	Incbin	"data/Obj_S.bin"	
    
Obj3d_E:
	Incbin	"data/Obj_E.bin"	


; EFFECT 3 : Letters scrolling
 
Pointrotating: ; 49 points ; 50 frames. Reverse. 
 include "data\framepoints.txt"

LetterA: ; Index from 1 to 49 ... (code need to remove 1)
    dc.b 2,7,12,17,19,11,5,2,$fe ;      40,45,46,41,32,2,$fe
    dc.b 12,40,45,46,41,32,21,17,12,$fe
    dc.b 21,32,29,30,22,21,$fe
    dc.b 21,32,29,21,$fe ; add this to fix hole
    dc.b 11,19,22,30,26,11,$fe
    dc.b 30,35,43,48,49,44,26,30,$fe
    dc.b $ff
LetterN:
    dc.b 1,7,40,45,46,41,17,1,$fe
    dc.b 1,17,18,15,11,6,1,$fe
    dc.b 18,42,47,49,44,15,18,$fe
    dc.b $ff
LetterE:
    dc.b 1,7,39,46,32,13,1,$fe
    dc.b 1,13,14,10,6,1,$fe
    dc.b 27,28,18,17,27,$fe
    dc.b 32,46,49,44,38,36,32,$fe
    dc.b $ff
LetterW:
    dc.b 1,7,37,46,32,8,2,1,$fe
    dc.b 32,46,49,38,35,32,$fe
    dc.b 33,34,4,3,33,$fe
    dc.b 35,38,11,6,5,19,35,$fe
    dc.b $ff
LetterP:
    dc.b 1,7,40,45,46,41,17,1,$fe
    dc.b 1,17,20,15,10,6,1,$fe
    dc.b 20,26,15,20,$fe
    dc.b 20,22,25,29,31,26,20,$fe
    dc.b $ff
LetterR:
    dc.b 2,7,12,17,19,15,10,6,2,$fe
    dc.b 12,40,45,46,41,21,17,12,$fe
    dc.b 17,27,24,17,$fe
    dc.b 15,19,33,35,26,15,$fe
    dc.b 33,42,47,49,44,38,35,33,$fe
    dc.b $ff
LetterO:
    dc.b 7,17,20,11,6,2,7,$fe
    dc.b 7,39,46,32,27,17,7,$fe
    dc.b 32,33,27,32,$fe
    dc.b 32,46,49,44,35,32,$fe
    dc.b 35,44,11,20,35,$fe
    dc.b $ff
LetterD:
    dc.b 1,45,32,17,1,$fe
    dc.b 32,45,49,44,35,32,$fe
    dc.b 1,17,20,11,6,1,$fe
    dc.b 35,44,11,20,35,$fe
    dc.b $ff
LetterU:   
    dc.b 1,7,40,46,32,8,2,1,$fe 
    dc.b 32,46,49,44,38,33,32,$fe
    dc.b 9,33,38,11,6,4,9,$fe
    dc.b $ff
LetterC:    
    dc.b 2,7,39,46,32,17,2,$fe
    dc.b 2,17,19,15,11,6,2,$fe
    dc.b 32,46,49,44,38,36,32,$fe
    dc.b $ff
LetterT:
    dc.b 2,7,12,16,21,19,15,11,6,2,$fe
    dc.b 19,21,41,47,19,$fe
    dc.b $ff
LetterI:   
    dc.b 3,8,21,18,3,$fe
    ;dc.b 21,41,47,43,22,18,21,$fe 
    dc.b 13,41,47,43,22,18,13,$fe 
    dc.b $ff
LetterL:    
    dc.b 2,7,40,46,32,8,2,$fe
    dc.b 32,46,49,44,38,36,32,$fe
    dc.b $ff
    
    even

   
Logo: ; 16 colors, 320x64
        Incbin	"data/logo.ami" 
        
LogoSmall: ; 8 colors, same as 3D. 288x11 pixels
        Incbin	"data/LogoSmall.ami"

LogoRSE: ; 96*3 x 77
        Incbin "data/LogoRSE.ami"
        
        blk.b 40*1,$F5 ; Padding data , overwritted by LDOS system ?
        

; -----------------------------------------
; Data chip
; -----------------------------------------

	data_c

; Position of lines (black line)  
ZONE2 = 10 ; End of zone 1.
ZONE3 = 51
ZONE4 = 72
ZONE5 = 81
ZONE6 = 86
ZONE7 = 89
CENTRALZONE = 256-((ZONE7+1)*2)  ; 76
   
				
copper:	
                dc.l	$01fc0000
				; screen 320*256
				dc.l	$008e2881
				dc.l	$009028c1
				dc.l	$00920038
				dc.l	$009400d0				
copperdecay:
				dc.l	$01020000 ; Decay
				dc.l	$01060000
ModuloStart:
				dc.l	$01080000 ; Modulo 
				dc.l	$010a0000 ; Modulo
				dc.l	$01000200 | (1 <<12) ; Planes

				dc.l	$009c8000 |(1<<4)		; fire copper interrupt
                
SpritesCopper: ; 8 sprites		 
        dc.l	$01200000,$01220000 ; Spr 0
		dc.l	$01240000,$01260000 ; Spr 1
        dc.l    $01280000,$012a0000 ; Spr 2
		dc.l	$012c0000,$012e0000 ; Spr 3
        dc.l    $01300000,$01320000 ; Spr 4
		dc.l	$01340000,$01360000 ; Spr 5
        dc.l    $01380000,$013a0000 ; Spr 6
		dc.l	$013c0000,$013e0000 ; Spr 7
        ; registres
        dc.l    $01040024 ; BPLCON2. All sprite in front.                

ZONE1_PAL:
				dc.l	(24<<24)|($09fffe)      ; wait few lines so CPU has time to patch copper list
copPal:         
                dc.l    $01800000,$01820000,$01840000,$01860000
                dc.l    $01880000,$018a0000,$018c0000,$018e0000
                dc.l    $01900000,$01920000,$01940000,$01960000
                dc.l    $01980000,$019a0000,$019c0000,$019e0000
                dc.l    $01a00000,$01a20000,$01a40000,$01a60000 ; all colors blacks
                dc.l    $01a80000,$01aa0000,$01ac0000,$01ae0000
                dc.l    $01b00000,$01b20000,$01b40000,$01b60000
                dc.l    $01b80000,$01ba0000,$01bc0000,$01be0000                
copScrSetPlan1:      
                dc.l    $00e00000,$00e20000
                dc.l	$0108FFD8 ; -40 (-40), to loop on same line again and again
                
ZONE2_BLACK:    dc.l	(($28+ZONE2)<<24)|($09fffe),$01800000      
ZONE2_PAL:      dc.l	(($28+ZONE2+1)<<24)|($09fffe),$01800000                 
                
ZONE3_BLACK:    dc.l	(($28+ZONE3)<<24)|($09fffe),$01800000      
ZONE3_PAL:      dc.l	(($28+ZONE3+1)<<24)|($09fffe),$01800000  

ZONE4_BLACK:    dc.l	(($28+ZONE4)<<24)|($09fffe),$01800000      
ZONE4_PAL:      dc.l	(($28+ZONE4+1)<<24)|($09fffe),$01800000  

ZONE5_BLACK:    dc.l	(($28+ZONE5)<<24)|($09fffe),$01800000  
    
ZONE5_PAL:      dc.l	(($28+ZONE5+1)<<24)|($09fffe),$01800000  

                ;dc.l	(($28+83)<<24)|($09fffe)
                ;dc.l	$01000200 | (0 <<12) ; no plane, to not consomme them

                ; -- Display xx planes, in far right of the screen.
                dc.l	(($28+84)<<24)|($09fffe)
                
copScrSet:                 
                dc.l    $00e00000,$00e20000
                dc.l    $00e40000,$00e60000
                dc.l    $00e80000,$00ea0000
                dc.l    $00ec0000,$00ee0000
                ;dc.l    $00f00000,$00f20000 ; We only need 4 plans
Planes87:
                dc.l	$01000200 | (2 <<12)
                dc.l	$01080000
                
ZONE6_BLACK:    dc.l	(($28+ZONE6)<<24)|($09fffe),$01800000      
ZONE6_PAL:      dc.l	(($28+ZONE6+1)<<24)|($09fffe),$01800000                

ZONE7_BLACK:    dc.l	(($28+ZONE7)<<24)|($09fffe),$01800000      
ZONE7_PAL:      dc.l	(($28+ZONE7+1)<<24)|($09fffe),$01800000 
                
                ; Presents
                ; Background is 558 , highlight is 669 77a 88b 99c aad bbe ccf
PRESENTLINESTART=$28+ZONE7+1+23
PresentPAL:
                dc.l	(PRESENTLINESTART<<24)|($09fffe)    ,$01820669 ; Line 1
                dc.l	((PRESENTLINESTART+1)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+2)<<24)|($09fffe),$0182077a
                dc.l	((PRESENTLINESTART+3)<<24)|($09fffe),$0182077a ; Highlight
                dc.l	((PRESENTLINESTART+4)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+5)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+6)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+7)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+8)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+9)<<24)|($09fffe),$0182077a ; Highlight
                dc.l	((PRESENTLINESTART+10)<<24)|($09fffe),$0182077a 
                dc.l	((PRESENTLINESTART+11)<<24)|($09fffe),$0182077a 
                dc.l	((PRESENTLINESTART+12)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+13)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+14)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+15)<<24)|($09fffe),$0182077a ; Highlight 
                dc.l	((PRESENTLINESTART+16)<<24)|($09fffe),$0182077a 
                dc.l	((PRESENTLINESTART+17)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+18)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+19)<<24)|($09fffe),$0182077a ; Highlight
                dc.l	((PRESENTLINESTART+20)<<24)|($09fffe),$01820669
                dc.l	((PRESENTLINESTART+21)<<24)|($09fffe),$01820669                
                dc.l	((PRESENTLINESTART+22)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+23)<<24)|($09fffe),$0182077a 
                dc.l	((PRESENTLINESTART+24)<<24)|($09fffe),$0182077a 
                dc.l	((PRESENTLINESTART+25)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+26)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+27)<<24)|($09fffe),$01820669 
                dc.l	((PRESENTLINESTART+28)<<24)|($09fffe),$01820fff 
                ; End 27

ZONE6b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE)<<24)|($09fffe),$01800000      
ZONE6b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+1)<<24)|($09fffe),$01800000 

ZONE5b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE6))<<24)|($09fffe),$01800000      
ZONE5b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE6)+1)<<24)|($09fffe),$01800000 

                dc.l	(($28+84+SCREENH)<<24)|($09fffe) ; 171
                dc.l	$01001200
                ; End planes
copScrSetPlan1b:      
                dc.l    $00e00000,$00e20000
                dc.l	$0108FFD8 ; -40 (-40), to loop on same line again and again
                
ZONE4b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE5))<<24)|($09fffe),$01800000      
ZONE4b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE5)+1)<<24)|($09fffe),$01800000 

ZONE3b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE4))<<24)|($09fffe),$01800000      
ZONE3b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE4)+1)<<24)|($09fffe),$01800000 

ZONE2b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE3))<<24)|($09fffe),$01800000 ; 253      
ZONE2b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE3)+1)<<24)|($09fffe),$01800000 ; 254

                 ; Wait 255
                 dc.w $ffdf,$fffe  ; 255

ZONE1b_BLACK:    dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE2)-256)<<24)|($09fffe),$01800000  ; 284    
ZONE1b_PAL:      dc.l	(($28+ZONE7+CENTRALZONE+(ZONE7-ZONE2)+1-256)<<24)|($09fffe),$01800000 

                ;dc.l    $01800000

				dc.l	-2

EmpyLine:
NullSprite:
  dc.l 0 ; Stop (4 bytes)
  blk.b 36,0 ; 40 bytes
  
SpriteLine:
  ; -- Zone 2, part 1
  dc.w $3240,$4200
  ; WORD 1
  ;Bits 15-8 contain the low 8 bits of VSTART
  ;Bits 7-0 contain the high 8 bits of HSTART
  ; WORD 2
  ;Bits 15-8       The low eight bits of VSTOP
  ;Bit 7           Attach bit !!
  ;Bits 6-3        Unused (make zero)
  ;Bit 2           The VSTART high bit
  ;Bit 1           The VSTOP high bit
  ;Bit 0           The HSTART low bit
  ; data
  dc.w $8000,$0000 ; 16x16
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000
  dc.w $0080,$0000
  dc.w $0040,$0000
  dc.w $0020,$0000
  dc.w $0010,$0000
  dc.w $0008,$0000
  dc.w $0004,$0000
  dc.w $0002,$0000
  dc.w $0001,$0000
  ; -- Zone 2, part 3 (end)
  dc.w $5250,$5b00 ; !link Control
  dc.w $8000,$0000 ; 16x16
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000
  dc.w $0080,$0000

  ; -- Zone 3, part 2 (end)
  dc.w $6cb8,$7000 ; control
  dc.w $0001,$0000
  dc.w $0002,$0000
  dc.w $0004,$0000
  dc.w $0008,$0000

  ; -- Zone 5, small vertical line
  dc.w $7a8c,$7e00
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  
  ; -- Middle
  
  ; -- Zone 6 mirror, 76 for central zone ... $82 + 76 = 206
  dc.b $ce,$68,$ce+3,$00
  dc.l $00010000
  dc.l $00020000
  dc.l $00040000
  
  ; -- Zone 4 mirror
  dc.b $d6,$b4,$d6+8,$00 ; !link Control
  dc.w $8000,$0000 
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000  

  ; -- Zone 3 mirror, part 2 (end)
  dc.b $ee,$5c,$ee+5,$00
  dc.w $0001,$0000
  dc.w $0002,$0000
  dc.w $0004,$0000
  dc.w $0008,$0000
  dc.w $0010,$0000
  
  ; Zone 1 mirror
  dc.b $1c,$d0,$1c+16,$06 ; $06 for hibits of VStart and Vstop 
  dc.w $8000,$0000 ; 16x16
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000
  dc.w $0080,$0000
  dc.w $0040,$0000
  dc.w $0020,$0000
  dc.w $0010,$0000
  dc.w $0008,$0000
  dc.w $0004,$0000
  dc.w $0002,$0000
  dc.w $0001,$0000
 
  dc.w 0,0 ; stop

SpriteLine2:

  ; -- Zone 1, small vertical line
  dc.w $278c,$3200
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000

  ; -- Zone 2, part 2
  dc.w $4248,$5200 ; !link Control
  dc.w $8000,$0000 ; 16x16
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000
  dc.w $0080,$0000
  dc.w $0040,$0000
  dc.w $0020,$0000
  dc.w $0010,$0000
  dc.w $0008,$0000
  dc.w $0004,$0000
  dc.w $0002,$0000
  dc.w $0001,$0000
  
  ; -- Zone 3, part 1
  dc.w $5cc0,$6c00 ; control
  dc.w $0001,$0000
  dc.w $0002,$0000
  dc.w $0004,$0000
  dc.w $0008,$0000
  dc.w $0010,$0000
  dc.w $0020,$0000
  dc.w $0040,$0000
  dc.w $0080,$0000
  dc.w $0100,$0000
  dc.w $0200,$0000
  dc.w $0400,$0000
  dc.w $0800,$0000
  dc.w $1000,$0000
  dc.w $2000,$0000
  dc.w $4000,$0000
  dc.w $8000,$0000 
  
  ; -- Zone 4
  dc.w $715e,$7900 ; !link Control
  dc.w $8000,$0000 ; 16x16
  dc.w $4000,$0000
  dc.w $2000,$0000
  dc.w $1000,$0000
  dc.w $0800,$0000
  dc.w $0400,$0000
  dc.w $0200,$0000
  dc.w $0100,$0000

  ; -- Zone 6, last small diag
  dc.b $7f,$af,$7f+3,$00
  dc.l $00010000
  dc.l $00020000
  dc.l $00040000

  ; -- Center

  ; -- Zone 5 mirror, center small vertical line
  dc.w $d18c,$d500
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  
  ; -- Zone 3 mirror , Part 1
  dc.b $de,$64,$de+16,$00
  dc.w $0001,$0000
  dc.w $0002,$0000
  dc.w $0004,$0000
  dc.w $0008,$0000
  dc.w $0010,$0000
  dc.w $0020,$0000
  dc.w $0040,$0000
  dc.w $0080,$0000
  dc.w $0100,$0000
  dc.w $0200,$0000
  dc.w $0400,$0000
  dc.w $0800,$0000
  dc.w $1000,$0000
  dc.w $2000,$0000
  dc.w $4000,$0000
  dc.w $8000,$0000  

  ; Zone 2 mirror - Part 1
  ; $f4  
  dc.b $f4,$8c,$04+24,$02 ; $f4+16 for end = 104
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000  
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000  
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000 
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000
  dc.l $00010000 
  
  dc.w 0,0 ; stop
  
; ----------------------------------------
; bss fast
; ----------------------------------------     
        
        bss_f

; ----------------------------------------
; Chip mem
; ----------------------------------------

        bss_c

        even

; 3D : Triple buffer of 8 colors. 81 pixels. 29 KB
; Present 27 pixels (1 plan. 1KB
; Scrolling of letters : 87 pixels, triple buffer 40 1 plan, and scroll 87 1 plan = 14 KB
; Logo : 16 colors. 10 KB

;EFFET 1 : Lettres en 3D : 81 pixels (3 plans)
;EFFET 2 : Presents : 27 pixels (1 plan)
;EFFET 3 : Scroll : 87 pixels (2 plans)
;EFFET 4 : Logo : 64 pixels (4 plans....16 colors)


BufferChips:
     ds.b 43448 ; FX1 have max values
     ds.b 40*20 ; Security

; Mapping for FX1 (3D)
screen1= BufferChips ; blk.b bitplanesizebytes*3,erasebytes = 9720
screen2= screen1 + bitplanesizebytes*3 ; blk.b bitplanesizebytes*3,erasebytes
screen3= screen2 + bitplanesizebytes*3 ; blk.b bitplanesizebytes*3,erasebytes
safezone= screen3 + bitplanesizebytes*3 ; blk.b 40*50 = 2000 ,$77
pointsprojeted= safezone + 40*50 ; blk.w 512*2 = 2048 ; Space for projected points  ; to screen (with center added)
bobzone= pointsprojeted + 512*2 ; blk.b 10240,$55 ; This can be reduced to the size of the biggest block (do it at end)	
endfx1chip = bobzone + 10240

; Mapping for FX2 (Presents)

; Mapping for FX3 (Rotating letters, scrolling)
screenBuffer1 = BufferChips
screenBuffer2 = screenBuffer1 + LINE_PITCH*SCREENH
screenBuffer3 = screenBuffer2 + LINE_PITCH*SCREENH
BigScroll     = screenBuffer3 + LINE_PITCH*SCREENH

; Mapping for FX4 (Logo)

    ; Dither patterns. 80 lines max. 128 pixels width (16 bytes) Each dither is 1280 bytes
DITHERMAXHEIGHT=80
Dither12: ds.b DITHERMAXHEIGHT*16
;$11111111,
;$00000000,
;$44444444,
;$00000000,
Dither25: ds.b DITHERMAXHEIGHT*16
;$55555555,
;$00000000,
;$55555555,
;$00000000,
Dither37: ds.b DITHERMAXHEIGHT*16
;$55555555
;$22222222
;$55555555
;$88888888
Dither50: ds.b DITHERMAXHEIGHT*16
;$55555555
;$AAAAAAAA
;$55555555
;$AAAAAAAA
Dither62: ds.b DITHERMAXHEIGHT*16
;$AAAAAAAA
;$DDDDDDDD
;$AAAAAAAA
;$77777777
Dither75: ds.b DITHERMAXHEIGHT*16
;$AAAAAAAA
;$FFFFFFFF
;$AAAAAAAA
;$FFFFFFFF
Dither87: ds.b DITHERMAXHEIGHT*16
;$EEEEEEEE
;$FFFFFFFF
;$BBBBBBBB
;$FFFFFFFF

; -----------------------------------------------------------
; DEFINE

SCREENW					=	320
SCREENH					=	87 ; Animated letters
MUSIC					=	0
CIA_PLAYER				=	0
SPRITE_COUNT            =   8
FRAME_COUNT             =   512
LINE_PITCH	            =	40		; 40 octets par ligne
PROFILING				=	0

Sp1			=		4
Sp2			=		6
Sp3			=		10
Sp4			=		8
Dp1			=		46*2
Dp2			=		48*2
Dp3			=		36*2
Dp4			=		40*2

coprbase=$dff000
custom=coprbase
dmaconr=2
joy0dat=$a
joy1dat=$c
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
cop1lch=$80
copjmp1=$88
