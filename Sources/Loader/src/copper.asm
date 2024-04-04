	
	
		data_c

			cnop 0,4
	
LOGOCOLOR EQU $0AAD

	
	; -- Copper list. 16 colors
copper:		
	dc.l	$008e2410		; set DIWSTRT
	dc.l	$009034f0
	dc.l	$00920038		; set DDFSTRT and DFFSTOP to work on recent amiga (not set by the OS before bootsector)
	dc.l	$009400d0
	dc.w	$0096,$0020
	dc.w	$0104,$0000
	dc.w	$0100,$0200	; $dff100 = number of planes. Bit #9, color for genlocked/scandoubled displays
	dc.w	$0108,$0000
	dc.w	$010A,$0000

	dc.w	$0180,$0000 ; Back color, always zero
PaletteCircles:	
	dc.w    $0182,LOGOCOLOR ; First color, for circle only (first plane)
PaletteOrange0:	dc.l 	$01840000,$01860000,$01880000,$018A0000,$018C0000 ; 5 orange colors
PaletteGrey0:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors

	dc.l    $30fdfffe
	; First line is $30
	; Text start at line 71
	; -- First line for all, set the pointer. There is 4 blank line before the text is starting.
	dc.l    $77fdfffe ; 30 + 71
	;dc.w	$0180,$0FFF
pointer1:	dc.w	$00e0,$0000,$00e2,$0000
;pointer2:	dc.w	$00e4,$0000,$00e6,$0000
;pointer3:	dc.w	$00e8,$0000,$00ea,$0000
;pointer4:	dc.w	$00ec,$0000,$00ee,$0000	
	dc.w	$0100,$9200	; $dff100 = number of planes
	; ZONE_CIRCLE is starting now. Right half of screen
	; ZONE_TEXT_1 "The Fall".
;PaletteGrey1:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_2 "Presented at".
;	dc.l    $86fdfffe ; $77 + 4 + 11
;PaletteGrey2:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_3 "Logo".
;	dc.l    $93fdfffe ; $77 + 4 + 24
;PaletteOrange3:	dc.l 	$01840000,$01860000,$01880000,$018A0000,$018C0000 ; 5 orange colors
;PaletteGrey3:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_4 
;	dc.l    $A9fdfffe ; $77 + 4 + 45
;PaletteOrange4:	dc.l 	$01840000,$01860000,$01880000,$018A0000,$018C0000 ; 5 orange colors
;PaletteGrey4:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_5 
;	dc.l    $B5fdfffe ; $77 + 4 + 58
;PaletteGrey5:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_6
;	dc.l    $C3fdfffe ; $77 + 4 + 72
;PaletteGrey6:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_7 
;	dc.l    $CFfdfffe ; $77 + 4 + 84
;PaletteGrey7:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	; ZONE_TEXT_8 
;	dc.l    $D9fdfffe ; $77 + 4 + 94
;PaletteGrey8:	dc.l 	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors

	dc.l    $E9fdfffe ; 30 + 71 + 114
	dc.w	$0100,$0200	; $dff100 = number of planes
	;dc.w	$0180,$0000
	dc.l	$009c8010,$fffffffe	; end copper	
; ------------------------------------------------------------------

;	; -- Copper list. 16 colors. Same but simplier palette for global fade out.
;copper2:		
;	dc.w	$0096,$0020
;	dc.w	$0104,$0000
;	dc.w	$0100,$0000	; $dff100 = number of planes
;	dc.w	$0108,$0000
;	dc.w	$010A,$0000
;	dc.w	$0180,$0000 ; Back color, always zero
;PaletteAll: ; 15 colors	
;	dc.w    $0182,LOGOCOLOR ; First color, for circle only (first plane)
;	dc.l	$01840000,$01860000,$01880000,$018A0000,$018C0000 ; 5 orange colors
;	dc.l	$018E0000,$01900000,$01920000,$01940000,$01960000,$01980000,$019A0000,$019C0000,$019E0000 ; 9 grey colors
;	dc.l    $30fdfffe
;	dc.l    $77fdfffe ; 30 + 71
;pointer1b:	dc.w	$00e0,$0000,$00e2,$0000
;;pointer2b:	dc.w	$00e4,$0000,$00e6,$0000
;;pointer3b:	dc.w	$00e8,$0000,$00ea,$0000
;;pointer4b:	dc.w	$00ec,$0000,$00ee,$0000	
;	dc.w	$0100,$1200	; $dff100 = number of planes
;	dc.l    $E9fdfffe ; 30 + 71 + 114
;	dc.w	$0100,$0000	; $dff100 = number of planes
;	dc.l	$009c8010,$fffffffe	; end copper
	
; ------------------------------------------------------------------