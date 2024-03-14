width		= 320
height		= 256
linemod		= width/8
bplSizeInBytes	= linemod*height


	include "hardware.i"

	code_f
	
		
START_IRQ:macro
	movem.l	d0-d7/a0-a6,-(sp)			;save all registers to stack
endm

END_IRQ:macro
	lea		$dff09c,a6
	moveq	#$10,d0
	move.w	d0,(a6)						;acknowledge the copper-irq.
	move.w	d0,(a6)						;this is done twice, due to some broken 68060 boards.
	movem.l	(sp)+,d0-d7/a0-a6			;retore all registers from stack
	nop									;this nop is also needed, because some 68060 cards are broken
	rte  								;end of irq
endm

	
dfm_waitMousePress:
	btst	#$06,$bfe001
	bne.b	dfm_waitMousePress
	rts

dfm_waitMouseRelease:
	btst	#$06,$bfe001
	beq.b	dfm_waitMouseRelease
	rts

dfm_waitMouseClick:
	jsr	dfm_waitMousePress
	jsr	dfm_waitMouseRelease
	rts
	
dfm_waitBlitter:
	move.w	#$8400,$dff096
.bl0:	
	btst	#$0e,$dff002
	bne.b	.bl0
	move.w	#$0400,$dff096
	rts		
	
	
;--------------------------------------------------------------------
;waits for the next vertical blank
dfm_vSync:	
		btst	#$00,$dff005
		beq.b	dfm_vSync
.vs0: 
		btst	#$00,$dff005
        bne.b	.vs0
		rts		
		
;--------------------------------------------------------------------
;sets a new copperlist and irq
;[in] a0 - the new copperlist
;[in] a1 - the new irq
dfm_setCopper:
		bsr.w	dfm_waitBlitter
		bsr.w	dfm_vSync
		move.w	#$8240,$dff096		;master & blitter dma
		;move.w	#$81a0,$dff096		;copper, bitplane & sprite dma
		move.w	#$8180,$dff096		;copper & bitplane dma
		move.w 	#(1<<4)|(1<<5)|(1<<6),$dff09a 		; switch off all level 3 interrupts
		move.l	a0,$dff080
		move.l	a1,$006c
		move.w	#$c010,$dff09a		;copper IRQ
		move.w	d0,$dff088			; avoid read/write
		rts
		

; [in] a0.l - beginning of the bitplane to clear
; [in] d0.l - value to clear with
dfm_clearBitPlane:
		move.l	d0,d1
		move.l	d0,d2
		move.l	d0,d3
		move.l	d0,d4
		move.l	d0,d5
		move.l	d0,d6
		move.l	d0,d7
		move.l	d0,a1								; clear 6 address registers (need to keep a0 for dest address and a7 for stack pointer)
		move.l	d0,a2
		move.l	d0,a3
		move.l	d0,a4
		move.l	d0,a5
		move.l	d0,a6

clearBitPlane_initialized:
		lea		10240(a0),a0						; bplSizeInBytes - go to the end of the buffer as the movem instruction will pre-decrease a0
		REPT	182									; we cleared 14 registers, and divide by 4 as the movem is on long words (4 bytes) --> 10240/(4*14)
			movem.l	d0-d7/a1-a6,-(a0)				
		ENDR
		; we did (4*14)*182 pixels = 10192. Remaining 48 pix = 12 longs
		movem.l	d0-d7/a1-a4,-(a0)				
		rts

		data_f
Mul40Table:
val	SET	0
	REPT 256
	dc.w val
val SET val+40
	ENDR
		


		