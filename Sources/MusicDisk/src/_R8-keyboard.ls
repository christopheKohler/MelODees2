
; hi ya there!
;
; this little beauty will pop out the scancode for every keypress that occures
; immedately, in the keyboarddata byte. hook it up to level 2 interrupt ($78)
; and go! simultaneous keystrokes can't be checked with this, with out
; modifiation. that's not to hard either. let me know if you need anything
; more!
;
; ps. make a testprogram so that you can acquire the scancodes (NOT the ascii
;     values). if you don't own a copy of hardware reference manual ofcourse
;     {page 255..}
; ds.
;
; your friend in amiga coding..
;
; /   dR.M 



lvl2_handler
;----------------------------------------------------------
	movem.l	d0-d1/a0/a2,-(a7)
	lea	$bfd100,a2
	moveq	#0,d0
	moveq	#$5f,d1
	lea	keyboarddata(pc),a0
	move.b	$1c01(a2),d0
	btst	#3,d0
	bne.s	l2_serial
l2_ok	
    movem.l	(a7)+,d0-d1/a0/a2
	move	#$4008,$dff09c
	nop			; think this IS needed (on '040 and up..)
	rte

l2_serial
	bsr.s	l2_readser
	bmi.s	l2s_rels
	move.b	d0,(a0)
	bra.s	l2_ok

;----------release----------------

l2s_rels
	clr.b	(a0)
	bra.s	l2_ok

l2_readser
	move.b	$1b01(a2),d0
	bchg	#6,$1d01(a2)

	move.b	$dff006,d1		; kb-handshake delay...
	addq.b	#2,d1
cmp	cmp.b	$dff006,d1
	bne.s	cmp

	clr.b	$1b01(a2)

	move.b	$dff006,d1
	addq.b	#2,d1
cmp2	cmp.b	$dff006,d1
	bne.s	cmp2

	bchg	#6,$1d01(a2)
	ror.b	#1,d0
	not.b	d0
	rts

keyboarddata	dc.b	0
		even

