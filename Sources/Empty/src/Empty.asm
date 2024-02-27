; --------------------------------------------------------------------
;
; Empty code, to have empty memory
;
; Oriens January 2024
;
; --------------------------------------------------------------------

	code

	include "../../ldos/kernel.inc"
    
    move.w #$000,$dff180
    
    ; Free all possible memory
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_PERSISTENT_CHIP_TRASH(a6)    
    
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_FREE_MEM_DATA(a6)  

    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_PRELOAD_NEXT_FX(a6)
    ; we now can terminate this part by RTS. Next part will execute a start music command
    
    rts         ; end of this part
