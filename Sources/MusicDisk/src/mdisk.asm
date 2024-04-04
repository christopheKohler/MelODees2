;----------------------------------------------------------------
; Music disk 2
; Resistance 2022-2024
;
; Logo 64 pixels 32 colors
; Background 112 pixels
; Scroll 16 pixels
; GUI 64 pixels 32 colors
;
; WinUAE special version, display memory place from $100 (4 words/8bytes) up to $107.
;
; Oriens 2022-2024
; -------------------------------------------------------
; Tracks and data :
; 00 Tebirod-Earth_sorrow_alt.p61
; 01 Intro/Intro.bin
; 02 Empty/Empty.bin
; 03 MusicDisk/mdisk.bin
; 04 mA2E-Limitless_Delights.p61  .... Track id=1 .... 2+id*2 (currentmusic)
; 05 datas/Level5.bin             .... id=1 .... 3+id*2
; AceMan-Hi-school_Girls.p61 ; Track 2
; datas/Level7.bin
; Nainnain-Izar.p61 ; 3
; datas/Level3.bin
; Ok3an0s_TEK-star-studded_skies.p61 ; 4
; datas/Level2.bin
; AceMan_-_Le_voyage_fantastique.p61 ; 5
; datas/Level8.bin
; Koola-ballade.p61 ; 6
; datas/Level1.bin
; Ok3an0s_TEK-through_the_gate.p61 ; 7
; datas/Level4.bin
; Tebirod-Flyn_fall_opt.p61 ; 8
; datas/Level6.bin
;
; Debug colors:
; color 2 = grey (for free) then 3 to 10 for each label
; First line = Chip
; Second line = Fast
;MEMLABEL_SYSTEM		=	$7f ; 10 0008 DARK BLUE
;MEMLABEL_TRACKLOAD		=	$7e ; 9  0808 DARK PURPLE
;MEMLABEL_PRECACHED_FX	=	$7d ; 8  00FF LIGHT BLUE
;MEMLABEL_MUSIC			=	$7c ; 7  0FF0 YELLOW
;MEMLABEL_DEBUG_SCREEN	=	$7b ; 6  0F0F PURPLE
;MEMLABEL_BOOTREAD		=	$7a ; 5  000F BLUE
;MEMLABEL_USER_FX		=	$79 ; 4  00F0 GREEN
;MEMLABEL_PERSISTENT_CHIP=	$78 ; 3  0F00 RED
;----------------------------------------------------------------

	jmp	startup
	
DISPLAYDEBUGMEMORY=0 ; 1 display memory  
SHOWRASTER=0 ; Show some info for blitter/cpu

ALTERNATETIME = 60*50 ; Switch palette each
;ALTERNATETIME = 15*50 ; Debug 
;ALTERNATETIME = 35*50 
 
;----------------------------------------------------------------

	include "../../LDOS/src/kernel.inc"

	code_f
	
startup:

    bsr InitRandom
    
	lea	$DFF000,A6	
    move.l	#$28613091,$8e(a6)	; Screen definition and size
	move.l	#$003800d0,$92(a6)	; 40 de large
	move.w	#%1000001111111111,$96(a6) ; Turn on DMA Bit 15=Set. 10=NastyBlitter 9=AllDma 8-4=DMAs 3-0=Audio
    
    move.b #1,first_launch ; first music counter
   
    ; Aga compatibility ;fmode DFF1FC,0 ;Chip Ram fetch mode (0=OCS)
	;bplcon3 DFF106,$0c00 ;bplcon4 DFF10C,$0011 ;AGA compat, dual playfield related 
    move.w #0,$DFF1FC ; ECS COMPATIBILITY (16 bits)
    move.w #$0c00,$DFF106
    move.w #$0011,$DFF10C
    
    ; Test chip ram. Do we have 512KB or 1MB ??
    ; If enough chipram, then the second module (highschool girls) can fully load
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_GETMEMBLOCKTABLE(a6) ; d0 = chip, d1 = fast/fake   
    move.l d0,a0 ; Get table of chip mem. 256 blocks = 512*2 mem, else 128 blocks = 512 Ko
    cmp.b #$7f,255(a0) ; MEMLABEL_SYSTEM, means no memory available (set in LDOS core)
    beq .noextrachip
    move.w #1,haveenoughchip ; Tell the music disk that there are plenty of chip mem :)
.noextrachip: 

    bsr AllocateChipMemForParalax ; Allocate 90K at end of chip mem
    
    ; -- Loading first module (same code as in DoLoading !)
    move.w #1,currentmusic ; Start with first module
    ;move.w #3,currentmusic ; Debug Plane
    ;move.w #6,currentmusic ; Debug Butterfly
    ;move.w #7,currentmusic ; Debug SnC city futurist
	; Preload music
	move.l (LDOS_BASE).w,a6
	move.w currentmusic,d0 ; 1 to 8
    lsl.w #1,d0 ; *2
	add.w #2,d0 ; To get the correct music    
	jsr LDOS_MUSIC_PRELOAD(a6) ; Blocking function.
 	; install music
	move.l (LDOS_BASE).w,a6
	jsr LDOS_MUSIC_RELOC(a6) ; Blocking function.
 	; Play music
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_START(a6)
    
    ; -- Load data
    ; LoadedLevel destination
	move.l (LDOS_BASE).w,a6
    move.w currentmusic,d0
    lsl.w #1,d0 ; *2 ; First level is file 5
	add.w #3,d0 ; To get the correct data level
	jsr LDOS_DATA_LOAD(a6) ; Alloc Fast mem. Blocking function. d0.l = adress, d1.l = size   
    move.l d0,LoadedLevel ; Adress of allocated data

    ; Empty zone for empty palette
    move.w #(64*3)-1,d0
    lea PaletteZero,a0
.loopempty:
    move.b #0,(a0)+
    dbra d0,.loopempty
    
    ; -- Construct graphic data from loaded level data.
    bsr constructgraphicdata
    
    ; -- Init all data after loading of module
    bsr Do_Loading_PostProcess
    
    ; hide 16 pixel on left
    LEA	$DFF000,A6
    move.l	#$2c912cc1,$8e(a6)	; Screen definition and size. Remove 16 pixels on the left
	bsr		Init
    lea COPP1,a0
    move.l	a0,$dff080
	Lea 	main_irq,a0
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_INSTALL_VCALLBACK(a6)
    
    move.w #0,frame_count ; set frame counter to 0 (used for displaying specific text 1)

    move.w #50*3,d0 ; 3 seconds
    jsr waitxxFrames ; Wait xx second    
    
    ; ------------------------------------------------------
BigLoop: ; Main loop CPU

    bsr wait1Frame
    bsr UpdateDisplayMusicName ; CPU Display names (can be slow so here in cpu loop)   

    ; -- Check first scrolltext force
    cmp.b #1,first_launch ; first music counter
    bne .nofirst
    add.w #1,frame_count
    cmp.w #8*50,frame_count ; Time to wait before launching first scroll (after main)
    bne .nofirst
    ; Force first text scroll
    move.b #0,first_launch
    move.l Scroll1Pointer,a1 ; main text
    move.w #0,DisplayColors
    move.l a1,ScrollMainTextSave ; Save main text
    move.b #1,ScrollIsSpecificText ; Set we are playing now specific text
    bsr switchtext1 ; random choose text1
    clr.l d0
    move.w currentmusic,d0 ; 1 to 8
    sub.w #1,d0
    lsl #2,d0; *4
    lea TEXTSCROLLSTABLE,a0
    add.l d0,a0
    move.l (a0),a0 
    move.l a0,Scroll1Pointer
.nofirst:    

    cmp.w #1,request_loading ; user have request a loading, we wait for "loading" to be there to do the effective load
    bne .noloadingasked
    ; If name display if active, then do not do loading
    cmp.w #0,DisplayNameMode
    bne BigLoop ; Loop to wait until all name display are done.
    ; Here display name is finished, we can do the loading
    move.w #0,request_loading
    bsr Do_Loading
    bra BigLoop
.noloadingasked:  
    ; Check music loop
    ; Get music info
	move.l (LDOS_BASE).w,a6
	jsr LDOS_MUSIC_GET_POSITION(a6) ; d0 track pos, d1 pattern line pos
    cmp.w music_last_pattern_pos,d0 ; compare with previous save
    bge .nomusicend
    ; Here music ended
    ; if seq mode then go to next module, else do nothing
    cmp.b #-1,music_mode
    beq NextClicked
.nomusicend
    move.w d0,music_last_pattern_pos
    
    ; Test mouse click
    ; Not working in LDOS: And Exit if BOTH left and right mouse button are pressed
	Btst	#6,$bfe001		; Left mouse button
	Bne.w	BigLoop
    ; ----- BIG LOOP END -------------------------------------------
   
MouseClicTest:

    ; If here, module is not loading.
    cmp.b #1,gui_flag_mouse_on_next
    beq NextClicked
    
    cmp.b #1,gui_flag_mouse_on_prev
    beq PrevClicked
    
    cmp.b #1,gui_flag_mouse_on_mode
    beq ModeClicked    
    
    cmp.b #1,gui_flag_mouse_on_play ; test just clicked
    beq PlayClicked

    bra BigLoop

    ; -- load next module

GUITILEPRESSEDON=10 ; x frames = 1 second 
NBMODULES=8   
    ; -- Next bouton clicked
NextClicked:
    bsr InitCursorMouseWait
    
    move.b #0,first_launch ; first music counter
    
    clr.l d0
    move.w currentmusic,d0
    bsr RequestEraseMusicName  

    move.w currentmusic,d0
    move.w d0,previousmusic ; Save previous module

    add.w #1,currentmusic ; next module
    cmp.w #NBMODULES+1,currentmusic
    bne .nomoduleoverflow
    move.w #1,currentmusic ; reset to first module
.nomoduleoverflow:  
    
    cmp.w #1,currentmusic
    bne .no1
    bsr switchtext1 ; random choose text1
.no1:

    move.b #GUITILEPRESSEDON,gui_count_next_justclicked
    ; Display "on" icon
    lea gui_next,a0
    move.l #1,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon  

    ; Force icon to be "Pause" (because we can be paused here)
    move.b #-1,music_is_paused
    bsr GetPlayPauseIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon 

    move.w #1,request_loading
    move.b #1,flag_module_is_loading

	bra BigLoop 
    ; -------------------------------------------------------------
    
    ; -- Prev bouton clicked    
    ; -- load prev module
PrevClicked:
    bsr InitCursorMouseWait
    
    move.b #0,first_launch ; first music counter
    
    clr.l d0
    move.w currentmusic,d0
    bsr RequestEraseMusicName 

    move.w currentmusic,d0
    move.w d0,previousmusic ; Save previous module    

    cmp.w #1,currentmusic
    bne .nomoduleoverflow
    move.w #NBMODULES+1,currentmusic ; reset to last module
.nomoduleoverflow:   
    sub.w #1,currentmusic ; prev module 

    cmp.w #1,currentmusic
    bne .no1
    bsr switchtext1 ; random choose text1
.no1:

    move.b #GUITILEPRESSEDON,gui_count_prev_justclicked
    ; Display "on" icon
    lea gui_prev,a0
    move.l #1,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon  

    ; Force icon to be "Pause" (because we can be paused here)
    move.b #-1,music_is_paused
    bsr GetPlayPauseIconDataInA0
    moveq.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
 
    move.w #1,request_loading
    move.b #1,flag_module_is_loading

	bra BigLoop 

    ;---------------------------------------------------------------
Do_Loading: ; this is blocking, done when "loading" is fully displayed
    bsr LoadingModule
Do_Loading_PostProcess: ; Can be called directly after load of first module 
    move.w #0,music_last_pattern_pos
    clr.l d0
    move.w currentmusic,d0
    bsr RequestDisplayMusicName
    bsr InitCursorMouse
    bsr FadeInGradientTransition ; first transition black to palette
    bsr SpriteCentral_AskComeFromLeft ; Ask ain sprite to arrive from left
    rts
    ; ---------------------------------------------
    
    ; -- Mode clicked
ModeClicked: 
    neg.b music_mode
    move.b #GUITILEPRESSEDON,gui_count_mode_justclicked
    ; Display "on" icon
    bsr GetMusicModeIconDataInA0
    move.l #1,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon 
    bsr waitabit
	bra BigLoop   

    ; -- Play/Pause clicked
PlayClicked: 
    neg.b music_is_paused ; start playing = -1
    move.b #GUITILEPRESSEDON,gui_count_play_justclicked
    ; Display "on" icon
    bsr GetPlayPauseIconDataInA0
    move.l #1,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon 
    ; Not working well
    cmp.b #1,music_is_paused ; Need to pause ?
    bne .needtoresume
.needtopause:
	move.l (LDOS_BASE).w,a6
	jsr LDOS_MUSIC_STOP(a6) ; Pause/Unpause
    bra .next
.needtoresume:
	move.l (LDOS_BASE).w,a6
	jsr LDOS_MUSIC_START(a6) ; Pause/Unpause
.next:
	;move.l (LDOS_BASE).w,a6
	;jsr LDOS_MUSIC_PAUSE(a6) ; Pause/Unpause
    ; wait a bit (click to be undone)
    bsr waitabit
	bra BigLoop 
    
; -------------------------------------------------------------------------------
switchtext1:
    ; random choose for text1, order vary.
    lea TEXTSCROLLSTABLE,a0
    bsr GetRandom ; d0.w
    
    move.l #TEXTMODULE1,(a0)
    
    cmp.b #$80,d0
    bpl .nochange
    move.l #TEXTMODULE1ALT,(a0)
.nochange: 
    rts

;-----------------------------------------------------------------------
; Return random number in d0.w
GetRandom:	
    Movem.l	d1-d2,-(a7)
	Move.w	SBPA,d0
	Move.w	d0,d1
	Move.w	d0,d2
	And.w	#%0000000001000000,d0	
	And.w	#%0000000000000001,d2	
	Lsr	#6,d0
	eor.w	d0,d2
	Lsl.w	#1,d1
	Or.w	d2,d1
	Move.w	d1,SBPA
    move.w  d1,d0
    move.w d0,$100 ; Debug
	Movem.l	(a7)+,d1-d2
	Rts
SBPA: ; Sequence Binaire Pseudo Aleatoire	
    Dc.w	$7fa5
;-----------------------------------------------------------------------
InitRandom:				; call once at init
	Move.w	$dff006,SBPA
	Rts

; -------------------------------------------------------------------------------
; Allocate chip persistant (end of chip mem block)
AllocateChipMemForParalax:
    move.l #paralaxsize,d0 ; Size of chip block ; paralaxsize=7600+17200+20640+20640+24000
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_PERSISTENT_CHIP_ALLOC(a6) ; in : d0.l: size of block
    ; d0 result
    move.l d0,paralaxChipPtr
    ; Clear start zone. 
    move.l d0,a0
    move.w #(paralaxsize/40)-1,d1 ; Bug 1 line appearing, so erase the full zone
.clearoneline:
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    move.l #0,(a0)+ ; 4 bytes
    dbra d1,.clearoneline
    
    ; Set double buffer for paralax
    move.l d0,a0
    add.l #planesparalax1_offset,a0
    lea ParalaxDoubleBuffer,a1
    move.l a0,(a1)
    ; Second plan
    move.l d0,a0
    add.l #planesparalax2_offset,a0
    move.l a0,4(a1)
    ; Set Plans dff100 values
    move.l #$01005200,BackgroundPlanControl ;  5 plans 
    move.l #$01080028,BackgroundModuloControl ; Set modulos
    
    move.l #$01004200,BackgroundPlanControl3 ;  4 plans  
    move.l #$01080002,BackgroundModuloControl2 ; Modulos
    move.l #$01080050,BackgroundModuloControl3 ; Modulos
    rts
    
FreeChipMemForParalax:
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_PERSISTENT_CHIP_TRASH(a6)
    ;move.l paralaxChipPtr,d0
    move.l #0,paralaxChipPtr ; This will stop the scrolling of background
    ; Disable Plans dff100 values (to hide any problems)
    move.l #$01001200,BackgroundPlanControl  ;  1 plan 
    move.l #$01001200,BackgroundPlanControl3 ;  1 plan
    ; Set modulos (-40 to loop on same line again and again)
    move.l #$0108FFD8,BackgroundModuloControl
    move.l #$0108FFD8,BackgroundModuloControl2
    move.l #$0108FFD8,BackgroundModuloControl3 
    ; First planes point to empty line.
    move.l #emptyline,d0
    lea BackgroundPlans_Part1,a1
    lea BackgroundPlans_Part2,a2
    lea BackgroundPlans_Part3,a3
    move.w d0,6(a1)
    move.w d0,6(a2)
    move.w d0,6(a3)
    swap d0
    move.w d0,2(a1)
    move.w d0,2(a2)
    move.w d0,2(a3)
    rts  
; ------------------------------------------------------------------------------- 

music_is_paused:
    dc.b -1 ; -1 = play 1 = pause
    
music_mode:
    dc.b -1 ; -1 = sequence 1 = loop
    
first_launch:
    dc.b 1 ; 0 if any module have been loaded (for scroll text)

flag_module_is_loading: ; true if loading
        dc.b 0
gui_count_next_justclicked:
        dc.b 0 ; if positive then display "on" state (and nothign else)
gui_count_prev_justclicked:
        dc.b 0 ; if positive then display "on" state (and nothign else) 
gui_count_play_justclicked:
        dc.b 0 ; if positive then display "on" state (and nothign else) 
gui_count_mode_justclicked:
        dc.b 0 ; if positive then display "on" state (and nothign else) 

    even 
    
frame_count:
    dc.w    0 ; For scroll if first launch
    
alternatepalette_counter: ; number of frame when palette is changed
    dc.w    0
plane_counter: ; use to create plane animation
    dc.w    0


music_last_pattern_pos: ; use for detection of loop of music
    dc.w 0
    
request_loading:
    dc.w 0
 
TablePaletteCurrent:
    dc.l TablesPalettes+8
    
; -- Tables palettes
TablesPalettes:
    dc.l PaletteZero    ; 0 ; Black
    dc.l PaletteZero    ; 4
    ; First set of palette
    dc.l Palette32_1    ; 8*1 + 0 ; Set 1
    dc.l Palette64_1    ; 8*1 + 4
    ; Second set of palette
    dc.l Palette32_2    ; 8*2 + 0 ; Set 2
    dc.l Palette64_2    ; 8*2 + 4
    ; End marker
    dc.l 0
    dc.l 0

;--------------------------------------------------------------- 
FadeInGradientTransition:
    lea PaletteZero,a2
    lea PaletteZero,a3
    lea Palette32_1,a4
    lea Palette64_1,a5
    move.l #TablesPalettes+8,TablePaletteCurrent ; prepare next transition
    bra LaunchGradientTransition_SetPalettes
;--------------------------------------------------------------- 
FadeOutGradientTransition:
    move.l TablePaletteCurrent,a5 ; content of TablePaletteCurrent. start at TablesPalettes
    move.l (a5),a2 ; src palette
    move.l 4(a5),a3 ; src palette gradient
    lea PaletteZero,a4
    lea PaletteZero,a5
    bra LaunchGradientTransition_SetPalettes    
;---------------------------------------------------------------    
LaunchGradientTransition: ; Switch between set 1 and 2.
    move.l TablePaletteCurrent,a6 ; content of TablePaletteCurrent. start at TablesPalettes
    move.l (a6),a2 ; src palette
    move.l 4(a6),a3 ; src palette gradient
    add.l #8,TablePaletteCurrent
    move.l TablePaletteCurrent,a6
    cmp.l #0,(a6)
    bne .noreset
    move.l #TablesPalettes+8,TablePaletteCurrent
    move.l TablePaletteCurrent,a6
.noreset:
    move.l (a6),a4 ; dest palette
    move.l 4(a6),a5 ; dest palette gradient   
LaunchGradientTransition_SetPalettes:  
    move.w #32*3,d4 ; 32 colors
    move.l a2,a0
    move.l a4,a1
    movem.l	a2-a5,-(sp)
    bsr ComputeSteps ; steps for gradient of palette .
    movem.l	(sp)+,a2-a5
    
    move.w #64*3,d4 ; 64 colors
    move.l a3,a0
    move.l a5,a1
    movem.l	a2-a5,-(sp)
    bsr ComputeStepsBackGradient ; steps for gradient of background palette.  

    ; reset switch palette counter
    move.w #0,alternatepalette_counter
    
    movem.l	(sp)+,a2-a5
    rts
    
; ----------------------------    
; Request the gui data for the play pause data.
; If playing then display the PAUSE icon
; If Pausing then display PLAY
GetPlayPauseIconDataInA0:
    ; PLAY or PAUSE
    cmp.b #-1,music_is_paused ; pause or play ?
    bne .isplaying
    lea gui_pause,a0
    bra .display
.isplaying    
    lea gui_play,a0
.display 
    rts
    
; ----------------------------    
; Request the gui data for the mode data.
GetMusicModeIconDataInA0:
    cmp.b #-1,music_mode
    beq .isseq
    lea gui_modeloop,a0
    bra .end
.isseq    
    lea gui_modeseq,a0 ; icon for "sequence" mode (auto load)
.end 
    rts   
	
; ----------------------------
; Wait 1 seconds (50 frames)  
waitabit:    
    ; Wait a bit
	move.w #0,wait
.wait:
	cmp.w #50,wait
	bne .wait    
    rts
    
; ----------------------------
; Wait xx  frames
; d0 number of frames
waitxxFrames:    
    ; Wait a bit
	move.w #0,wait
.wait:
	cmp.w wait,d0
	bne .wait    
    rts    

; ----------------------------
; Wait  
wait1Frame:    
	; Wait a bit
	move.w #0,wait
.wait:
	cmp.w #1,wait
	bne .wait    
    rts
    
; -------------------------------------------------------------------------
; -- Loading and playing module
; currentmusic 1 to 8 .... 2 is the big one, need to free chipmem
LoadingModule:
    
    cmp.b #1,flag_do_not_change_scroll
    beq .noscrollchange
    
    ; Set loading text
    lea TEXTLOADING,a0
    clr.l d0
    move.w currentmusic,d0 ; 1 to 8
    sub.w #1,d0
    lsl #2,d0 ; *4
    add.l d0,a0
    move.l (a0),a0 ; a0 contain start of specific loading text
    ; If not specific text playing, save main text position
    cmp.b #0,ScrollIsSpecificText
    bne .nospecific
    move.l Scroll1Pointer,a1 ; main text
    move.l a1,ScrollMainTextSave ; Save main text
    move.b #1,ScrollIsSpecificText ; Set we are playing now specific text
.nospecific  
    move.l a0,ScrollTextChangeRequest ; Will be set to Scroll1Pointer at next IRQ
 
.noscrollchange
	
    ; -- If big module (2), free memory of paralax and stop music
    cmp.w #1,haveenoughchip
    beq .nobigmodule
    move.w currentmusic,d0 ; 1 to 8
    cmp.w #2,d0
    bne .nobigmodule
    ; Stop with fade
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_STOP(a6)  ; Stop with fade
    ; Delete background line by line. (at least 2 seconds)
    bsr EraseParalaxBackground
    bsr FreeChipMemForParalax
    bsr LaunchGradientTransition ; ask palette transition
    ; Free memory of music
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_FREE_MEM_MUSIC(a6)  ; Stop with fade
    ; Free also fast mem segment
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_FREE_MEM_DATA(a6)     
.nobigmodule:

    ; -- If WAS big module (2), free memory of music
    cmp.w #1,haveenoughchip
    beq .nobigmodule1b    
    move.w previousmusic,d0 ; 1 to 8
    cmp.w #2,d0
    bne .nobigmodule1b
    ; Stop with fade
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_STOP(a6)  ; Stop with fade
    move.w #100,d0 ; 2 seconds (for fade and stop)
    jsr waitxxFrames ; Wait xx second      
    ; Free memory of music
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_FREE_MEM_MUSIC(a6)  ; Stop with fade
.nobigmodule1b:
    
	; Preload music
    clr.l d0
	move.l (LDOS_BASE).w,a6
	move.w currentmusic,d0 ; 1 to 8
    lsl.w #1,d0 ; *2
	add.w #2,d0 ; To get the correct music    
	jsr LDOS_MUSIC_PRELOAD(a6) ; Blocking function.
    
    ; Stop with fade
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_STOP(a6)  ; Stop with fade

    ; Background palette fade to 0
    bsr FadeOutGradientTransition 
    bsr SpriteCentral_AskSlowRight ; Ask Sprite to go right

    move.w #150,d0 ; 3 seconds
    jsr waitxxFrames ; Wait xx second
    
	; install music
	move.l (LDOS_BASE).w,a6
	jsr LDOS_MUSIC_RELOC(a6) ; Blocking function.
	
    ; TODO: Wait here, kill DMA ?
    move.w #50,d0 ; 1 seconds
    jsr waitxxFrames ; Wait xx second
	move.w	#%0000000000001111,$dff096 ; Turn off Audio Dma. 4 Channels

	move.l (LDOS_BASE).w,a6
	jsr		LDOS_MUSIC_START(a6)
    
    move.b #0,flag_module_is_loading
    
    ; reset mouse flags
    clr.b gui_flag_mouse_on_next
    clr.b gui_flag_mouse_on_prev
    clr.b gui_flag_mouse_on_mode
    clr.b gui_flag_mouse_on_play
    
    ; Init Specific scrolling
    cmp.b #1,flag_do_not_change_scroll
    beq .noscrollchange2    
    clr.l d0
    move.w currentmusic,d0 ; 1 to 8
    sub.w #1,d0
    lsl #2,d0; *4
    lea TEXTSCROLLSTABLE,a0
    add.l d0,a0
    move.l (a0),a0 
    ;move.l a0,Scroll1Pointer 
    move.l a0,ScrollTextChangeRequest
    ;move.w #0,DisplayColors    
.noscrollchange2
    
    ; -- Here need to wait that fade is over.
.waitfadegradientend:
    cmp.b #255,gradient_nbsteps
    beq .fadefinish
    jsr wait1Frame
    bra .waitfadegradientend
.fadefinish:

    ; -- Load data
    ; Free previous data
    ; this only releasing the data loaded or free also some other data ??
    ; TODO Check this
    move.l	(LDOS_BASE).w,a6
    jsr		LDOS_FREE_MEM_DATA(a6) 
    
    ; LoadedLevel destination
    ; First level is file 4.
    ; Warning TrackLoad will allocate some ChipMem
	move.l (LDOS_BASE).w,a6
    clr.l d0
    move.w currentmusic,d0
    lsl.w #1,d0 ; *2
	add.w #3,d0 ; To get the correct data level
	jsr LDOS_DATA_LOAD(a6) ; Alloc Fast mem (TAG DATA). Blocking function. d0.l = adress, d1.l = size   
    move.l d0,LoadedLevel
    
    ; If big module (2), then realloc mem for paralax
    cmp.w #1,haveenoughchip
    beq .nobigmodule2
    move.w currentmusic,d0 ; 1 to 8
    cmp.w #2,d0
    bne .nobigmodule2
    bsr AllocateChipMemForParalax ; Realloc
.nobigmodule2:  

    ; -- Construct graphic data from loaded level data.
    move.w #1,SpriteStopUpdate
    bsr SetMinimalSpriteInCopper ; Set null sprite while others are computed.
    bsr constructgraphicdata
    ; Set back full sprites
    lea SpriteFrame1Ptrs,a4 ; 12 pointers here
    Bsr SetSpritePointerInCopper
    move.w #0,SpriteStopUpdate
 
    rts

;----------------------------------------------------------------
; Init	
Init:
    ; Init values
    move.w #0,BackgroundXPos ; arj7 routine is writing here. TODO Debug why

    ; -- Init Logo. 32 colors
    ;LogoData:
    ;    incbin  "data/logo_melodees.ami"
    ; word - numcolors
    ; word - bitplane-width in bytes
    ; word - bitplane-size in bytes
    ; long - image-size (all bitplanes) in bytes
    ; numcolors { word - palette }
    ;image-size { byte - bitplanes }      
    ;    
    ;    LogoPalette:
    ;    LogoPlans:

    lea LogoData,a0
    add.l #2+2+2+4,a0
    lea LogoPalette,a1 ; dest
    add.l #2,a1
    move.w #32-1,d0
.loopcopycolors
    move.w (a0)+,(a1)
    add.l #4,a1
    dbra d0,.loopcopycolors
    
    ; Set pointers. Logo is 64 lines. 5 planes
 	move.l	a0,d0
	Lea		LogoPlans,a0
    Bsr     Put_pointeurs 
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs

	; Clear planes
	lea		start_planes,a0
	moveq.l	#$0,d0
.clr2:
	move.l	d0,(a0)+
	cmp.l	#end_planes,a0
	bmi.b	.clr2
    
    if DISPLAYDEBUGMEMORY==1
   	; Fill debug planes (in white)
	lea		plansDebugMem,a0
    lea     plansDebugMem+(12*40),a1
    move.l	#$FFFFFFFF,d0 ; Color 1 is white
.clr3:
	move.l	d0,(a0)+
	cmp.l	a1,a0
	bmi.b	.clr3    
	; Set SYSTEM DEBUG (Memory block display)
	Move.l	#plansDebugMem,d0
	Lea		P1DBG,a0
    Bsr     Put_pointeurs
	Move.l	#plansDebugMem+(12*40),d0
	Lea		P2DBG,a0
    Bsr     Put_pointeurs
	Move.l	#plansDebugMem+(12*40*2),d0
	Lea		P3DBG,a0
    Bsr     Put_pointeurs
	Move.l	#plansDebugMem+(12*40*3),d0
	Lea		P4DBG,a0
    Bsr     Put_pointeurs
    endc
	
    ; -- Init fonts
	Lea Font1,a0
	Bsr InitfontScroll ; Init Font for scrolling
    
	; Sprite init (cursor)
    ; As sprite of mouse is a re-use of sprite 0, the data are chained 
    ; With Sprite1a. So no need to init anything, the DMA will do the job automatically
    
    lea SpriteFrame1Ptrs,a4 ; 12 pointers here
    Bsr SetSpritePointerInCopper

    ; -- Init Gui. 32 colors
    lea GuiData,a0
    add.l #2+2+2+4,a0
    lea GuiPalette,a1 ; dest
    add.l #2,a1
    move.w #32-1,d0
.loopcopycolorsc
    move.w (a0)+,(a1)
    add.l #4,a1
    dbra d0,.loopcopycolorsc
    
    ; Set pointers. Logo is 64 lines. 5 planes
 	move.l	a0,d0
    ; skip 6 lines.
    add.l #6*40,d0
	Lea		GuiPlans,a0
    Bsr     Put_pointeurs 
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #64*40,d0
    add.l   #8,a0
    Bsr     Put_pointeurs     
    
    ; Set Paralax
    ; ParalaxPlanesPtr. 40 x 5 side by side
    ; planesparalax
    Move.l	ParalaxDoubleBuffer,d0
	Lea		BackgroundPlans_Part2,a0
    Bsr     Put_pointeurs
    add.l   #40*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs        
    add.l   #40*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs    
    add.l   #40*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs 
    add.l   #40*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs 
    
    ; -- Set scrolling part
    ; 8 colors
    ; Set plan
    Move.l	#planescrolling1+2,d0
	Lea		ScrollPlans,a0
    Bsr     Put_pointeurs
    add.l   #46,d0
    add.l   #8,a0
    Bsr     Put_pointeurs        
    add.l   #46,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #46,d0
    add.l   #8,a0
    Bsr     Put_pointeurs    
   
    ; Display basic GUI icons
    bsr GetPlayPauseIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon
    
    bsr GetMusicModeIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon 

    lea gui_next,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon    
    
    lea gui_prev,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon   

    ; initialize the old counters, so the mouse will not jump on first movement
    move.w  $dff00a,d0
    move.b  d0,oldhorizcnt
    lsr.w   #8,d0
    move.b  d0,oldvertcnt  

    ; Update at least one to set colors, so copper colors are filled
    move.w #32,d4 ; 32 colors
    bsr UpdateSteps
    move.w #64,d4 ; 64 colors
    bsr UpdateStepsCopper       
    
    move.b #1,ParalaxFlagSwitch
    bsr UpdateBackgroundScroll ; At least update pointers
    move.b #0,ParalaxFlagSwitch
    bsr ParalaxDoDoubleBuffer
    
	rts
; ------------------------------------------- 
; Set Minimal Sprite in copper 
; While Sprite zone is computed
SetMinimalSpriteInCopper:
    ; Set 8 sprites to 0
 	Lea	SprCentral,a0
    move.l	#NullSprite,d0
    move.w #8-1,d1
.setnulsprite:    
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
    swap    d0
    add.l #8*1,a0    
    dbra d1,.setnulsprite
    
    ; Sprite 1 to cursor zone
    Lea	SprCentral,a0
    move.l	#SpriteCursor,d0
    Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)
    
    ; Sprite 2 & 3 to Gui top
    add.l #8*2,a0
    move.l	#SpriteGui1,d0
    Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)
    
    add.l #8*1,a0
    move.l	#SpriteGui2,d0
    Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)

    rts
    
; ------------------------------------------- 
;  A4 12 pointer (sprite)
SetSpritePointerInCopper:  
    ; Central Sprite
    ; part 1 (2 sprites)
 	Lea	SprCentral,a0
    move.l	OFFSETSpriteMain1aPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0) 

 	Lea	SprCentral,a0
    add.l #8*1,a0
    move.l	OFFSETSpriteMain1bPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)     
    
    ; part 2 (2 sprites)
 	Lea	SprCentral,a0
    add.l #8*2,a0
    move.l	OFFSETSpriteMain2aPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)

 	Lea	SprCentral,a0
    add.l #8*3,a0
    move.l	OFFSETSpriteMain2bPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0) 

    ; part 3 (2 sprites)
 	Lea	SprCentral,a0
    add.l #8*4,a0
    move.l	OFFSETSpriteMain3aPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)

 	Lea	SprCentral,a0
    add.l #8*5,a0
    move.l	OFFSETSpriteMain3bPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0) 

    ; part 4 (2 sprites)
 	Lea	SprCentral,a0
    add.l #8*6,a0
    move.l	OFFSETSpriteMain4aPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0)

 	Lea	SprCentral,a0
    add.l #8*7,a0
    move.l	OFFSETSpriteMain4bPtr(a4),a1
	Move.l	a1,d0
	Move.w	d0,6(a0)
	Swap	d0
	Move.w	d0,2(a0) 

    rts
; ----------------------------------------------    
LoadedLevel:
    dc.l 0 ; Fast mem
paralaxChipPtr:
    dc.l 0 ; Chip mem

constructgraphicdata:
    ;LoadedLevel:
    ;incbin "data/file.bin" ; All loaded data in one block.
    ; 32*2 bytes    : palette
    ; 12400 bytes : pictureparalax back  320x62x5   SIDE by SIDE
    ; 29760 bytes : pictureparalax front 640x93_16c SIDE by SIDE
    ; 3440 bytes  : front mask 640x43x1
LEVELDATA_PALETTE=0
LEVELDATA_BACK=LEVELDATA_PALETTE+64    
LEVELDATA_FRONT=LEVELDATA_BACK+12400
LEVELDATA_MASK=LEVELDATA_FRONT+29760
LEVELDATA_PALETTERGB=LEVELDATA_MASK+3440 ; 32*3*2 = 96*2
LEVELDATA_GRADIENTRGB=LEVELDATA_PALETTERGB+(32*3*2) ; 64*3*2 = 192*2
LEVELDATA_SPRITES=LEVELDATA_GRADIENTRGB+(64*3*2) ; Height * 4 * 8 (Height can Very, so keep this for end) 

    ; -- BACK - TOP - 32 COLORS --------------------------------
    ; From loaded data to 
    ; paralax_backtop_640x19: ; 7600 bytes
    ; We have source data side by side and dest data plane by plane
    ; We need to duplicate the image to go from 320 to 640
    ; Plane 1
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK,a0 ; plane1    
    
    move.l paralaxChipPtr,a1
    add.l #paralax_backtop_640x19_offset,a1
    
    ; paralaxsize=7600+17200+20640+20640+24000
    ; Store in paralaxChipPtr
;paralax_backtop_640x19_offset=0
;paralax_back_640x43_offset=paralax_backtop_640x19_offset+7600
;paralax_front_960x43_offset=paralax_back_640x43_offset+17200
;paralax_front_960x43_mask_offset=paralax_front_960x43_offset+20640
;paralax_frontbottom_960x50_offset=paralax_front_960x43_mask_offset+20640      

    move.l #19-1,d1
.alllines
    move.l #40-1,d0
.line
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines
    ; Plane 2
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK,a0 
    add.l #40,a0 ; plane 2
    move.l paralaxChipPtr,a1
    add.l #paralax_backtop_640x19_offset,a1
    add.l #80*19*1,a1 ; plane 2
    move.l #19-1,d1
.alllines2
    move.l #40-1,d0
.line2
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line2
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines2   
    ; Plane 3
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK,a0 
    add.l #40*2,a0 ; plane 3
    move.l paralaxChipPtr,a1
    add.l #paralax_backtop_640x19_offset,a1
    add.l #80*19*2,a1 ; plane 3
    move.l #19-1,d1
.alllines3
    move.l #40-1,d0
.line3
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line3
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines3 
    ; Plane 4
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK,a0 
    add.l #40*3,a0 ; plane 4
    move.l paralaxChipPtr,a1
    add.l #paralax_backtop_640x19_offset,a1
    add.l #80*19*3,a1 ; plane 4
    move.l #19-1,d1
.alllines4
    move.l #40-1,d0
.line4
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line4
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines4 
    ; Plane 5
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK,a0 
    add.l #40*4,a0 ; plane 5
    move.l paralaxChipPtr,a1
    add.l #paralax_backtop_640x19_offset,a1
    add.l #80*19*4,a1 ; plane 5
    move.l #19-1,d1
.alllines5
    move.l #40-1,d0
.line5
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line5
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines5
    ; -----------------
Back2:
        
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK+(40*19*5),a0 ; plane1 
    move.l paralaxChipPtr,a1    
    add.l #paralax_back_640x43_offset,a1 ; 80*43*5
    move.l #43-1,d1
.alllines
    move.l #40-1,d0
.line
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines
    ; Plane 2
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK+(40*19*5),a0
    add.l #40,a0 ; plane 2
    move.l paralaxChipPtr,a1
    add.l #paralax_back_640x43_offset,a1
    add.l #80*43*1,a1 ; plane 2
    move.l #43-1,d1
.alllines2
    move.l #40-1,d0
.line2
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line2
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines2   
    ; Plane 3
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK+(40*19*5),a0 
    add.l #40*2,a0 ; plane 3
    move.l paralaxChipPtr,a1
    add.l #paralax_back_640x43_offset,a1
    add.l #80*43*2,a1 ; plane 3
    move.l #43-1,d1
.alllines3
    move.l #40-1,d0
.line3
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line3
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines3 
    ; Plane 4
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK+(40*19*5),a0
    add.l #40*3,a0 ; plane 4
    move.l paralaxChipPtr,a1
    add.l #paralax_back_640x43_offset,a1
    add.l #80*43*3,a1 ; plane 4
    move.l #43-1,d1
.alllines4
    move.l #40-1,d0
.line4
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line4
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines4 
    ; Plane 5
    move.l LoadedLevel,a0
    add.l #LEVELDATA_BACK+(40*19*5),a0 
    add.l #40*4,a0 ; plane 5
    move.l paralaxChipPtr,a1
    add.l #paralax_back_640x43_offset,a1
    add.l #80*43*4,a1 ; plane 5
    move.l #43-1,d1
.alllines5
    move.l #40-1,d0
.line5
    move.b (a0),40(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line5
    add.l #4*40,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines5
    
    ; -----------------
Front:    
    ; 640 to 960, 4 planes, 43 lines. 120 bytes
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT,a0 ; plane1 
    move.l paralaxChipPtr,a1    
    add.l #paralax_front_960x43_offset,a1
    move.w #43-1,d1
.alllines
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.w #40-1,d0
.linea
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.linea
    move.w #40-1,d0
.lineb
    move.b (a0)+,(a1)+
    dbra d0,.lineb
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines
    ; Plane 2
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT,a0
    add.l #80*1,a0 ; plane 2
    move.l paralaxChipPtr,a1
    add.l #paralax_front_960x43_offset,a1
    add.l #120*43*1,a1 ; plane 2
    move.l #43-1,d1
.alllines2
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line2a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line2a
    move.l #40-1,d0
.line2b
    move.b (a0)+,(a1)+
    dbra d0,.line2b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines2   
    ; Plane 3
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT,a0 
    add.l #80*2,a0 ; plane 3
    move.l paralaxChipPtr,a1
    add.l #paralax_front_960x43_offset,a1
    add.l #120*43*2,a1 ; plane 3
    move.l #43-1,d1
.alllines3
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line3a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line3a
    move.l #40-1,d0
.line3b
    move.b (a0)+,(a1)+
    dbra d0,.line3b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines3 
    ; Plane 4
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT,a0
    add.l #80*3,a0 ; plane 4
    move.l paralaxChipPtr,a1
    add.l #paralax_front_960x43_offset,a1
    add.l #120*43*3,a1 ; plane 4
    move.l #43-1,d1
.alllines4
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line4a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line4a
    move.l #40-1,d0
.line4b
    move.b (a0)+,(a1)+
    dbra d0,.line4b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines4 
    
    ; ------
    ; mask
    ; 32*2 bytes    : palette
    ; 12400 bytes : pictureparalax back  320x62x5   SIDE by SIDE
    ; 29760 bytes : pictureparalax front 640x93_16c SIDE by SIDE
    ; 3440 bytes  : front mack 640x43x1    

Mask:   
    move.l LoadedLevel,a0
    add.l #LEVELDATA_MASK,a0 ; plane1 of mask data (3440 bytes = 80*43)  

    move.l paralaxChipPtr,a1
    add.l #paralax_front_960x43_mask_offset,a1 ; plane1
    move.l a1,a2
    add.l #120*43,a2 ; plane 2
    move.l a2,a3
    add.l #120*43,a3 ; plane3
    move.l a3,a4
    add.l #120*43,a4 ; plane4
    
    move.l #43-1,d1
.alllines
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.linea
    move.b (a0),80(a1)
    move.b (a0),80(a2)
    move.b (a0),80(a3)
    move.b (a0),80(a4)
    move.b (a0),(a2)+
    move.b (a0),(a3)+
    move.b (a0),(a4)+
    move.b (a0)+,(a1)+
    dbra d0,.linea
    move.l #40-1,d0
.lineb
    move.b (a0),(a2)+
    move.b (a0),(a3)+
    move.b (a0),(a4)+
    move.b (a0)+,(a1)+
    dbra d0,.lineb
    add.l #40,a1 ; skip other half
    add.l #40,a2 ; skip other half
    add.l #40,a3 ; skip other half
    add.l #40,a4 ; skip other half
    dbra d1,.alllines
    ; ----------------------
    
Front_Bottom:
    ; paralax_frontbottom_960x50
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT+(80*43*4),a0 ; plane1  
    move.l paralaxChipPtr,a1
    add.l #paralax_frontbottom_960x50_offset,a1
    move.l #50-1,d1
.alllines
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.linea
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.linea
    move.l #40-1,d0
.lineb
    move.b (a0)+,(a1)+
    dbra d0,.lineb
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines
    ; Plane 2
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT+(80*43*4),a0 ; plane1
    add.l #80*1,a0 ; plane 2
    move.l paralaxChipPtr,a1
    add.l #paralax_frontbottom_960x50_offset,a1
    add.l #120*50*1,a1 ; plane 2
    move.l #50-1,d1
.alllines2
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line2a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line2a
    move.l #40-1,d0
.line2b
    move.b (a0)+,(a1)+
    dbra d0,.line2b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines2   
    ; Plane 3
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT+(80*43*4),a0 ; plane1
    add.l #80*2,a0 ; plane 3
    move.l paralaxChipPtr,a1
    add.l #paralax_frontbottom_960x50_offset,a1
    add.l #120*50*2,a1 ; plane 3
    move.w #50-1,d1
.alllines3
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line3a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line3a
    move.l #40-1,d0
.line3b
    move.b (a0)+,(a1)+
    dbra d0,.line3b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines3 
    ; Plane 4
    move.l LoadedLevel,a0
    add.l #LEVELDATA_FRONT+(80*43*4),a0 ; plane1
    add.l #80*3,a0 ; plane 4
    move.l paralaxChipPtr,a1
    add.l #paralax_frontbottom_960x50_offset,a1
    add.l #120*50*3,a1 ; plane 4
    move.l #50-1,d1
.alllines4
    ; Copy 640, then copy again 40 first bytes. Total 40+40+40 = 120
    move.l #40-1,d0
.line4a
    move.b (a0),80(a1)
    move.b (a0)+,(a1)+
    dbra d0,.line4a
    move.l #40-1,d0
.line4b
    move.b (a0)+,(a1)+
    dbra d0,.line4b
    add.l #3*80,a0 ; Skip others planes
    add.l #40,a1 ; skip other half
    dbra d1,.alllines4 

    ; Erase empty space
	; Clear planes
;	lea		paralax_frontbottom_960x50_Empty_Start,a0
;	moveq.l	#$00,d0
;.clr2:
;	move.l	d0,(a0)+
;	cmp.l	#paralax_frontbottom_960x50_Empty_End,a0
;	bmi.b	.clr2 

    ; -- Set pointers to palettes. . Copy 2 palettes
    ;TablesPalettes
    ; First long : Adresse of first palette 32 colors.
    ; Second long ; Adress of second palette 64 colors.
    move.l LoadedLevel,a0
    add.l #LEVELDATA_PALETTERGB,a0 ; blk.b 32*3*2,0
    lea Palette32_1,a1
    move.l #(32*3*2)-1,d0 ; d0
.loop1
    move.b (a0)+,(a1)+
    dbra d0,.loop1
    ; Gradient (background). Copy 2 palettes
    move.l LoadedLevel,a0
    add.l #LEVELDATA_GRADIENTRGB,a0 ; blk.b 64*3*2    
    lea Palette64_1,a1
    move.l #(64*3*2)-1,d0 ; d0
.loop2
    move.b (a0)+,(a1)+
    dbra d0,.loop2

    ; Sprite - Init motion
    Bsr InitMotion

    ; -- Sprites. Build sprite zone
    ; A0 Source data (fastmem) for Main sprite
    ; A1 Dest in sprit zone
    ; A4 structure of 12 pointer

OFFSETSpriteCursorPtr=0*4;
OFFSETSpriteGui1Ptr=1*4; 
OFFSETSpriteGui2Ptr=2*4; 
OFFSETSpriteMain1aPtr=3*4; 
OFFSETSpriteMain1bPtr=4*4; 
OFFSETSpriteMain2aPtr=5*4; 
OFFSETSpriteMain2bPtr=6*4; 
OFFSETSpriteMain3aPtr=7*4; 
OFFSETSpriteMain3bPtr=8*4; 
OFFSETSpriteMain4aPtr=9*4; 
OFFSETSpriteMain4bPtr=10*4; 
OFFSETNullSpritePtr=11*4; 

    move.l #SpriteFrame1Ptrs,SpriteCurrentFrame ; Reset the sprite animation pointer
    
    ; Clear table
    Lea SpriteFrameTable,a5 ; ... table with sprite pointers (0 to end). All set to 0 at start
    move.l #0,(a5)+ ; 6 steps maximum.
    move.l #0,(a5)+
    move.l #0,(a5)+
    move.l #0,(a5)+
    move.l #0,(a5)+
    move.l #0,(a5)+
    Bsr SpriteAnimationResetTable

    ; Clear all pointers zone.
    ; 6 zones of 12 pointer. 6*12*4=288 bytes
    ;SpriteFrame1Ptrs:   blk.l 12,0
    ;SpriteFrame2Ptrs:   blk.l 12,0
    ;SpriteFrame3Ptrs:   blk.l 12,0
    ;SpriteFrame4Ptrs:   blk.l 12,0
    ;SpriteFrame5Ptrs:   blk.l 12,0
    ;SpriteFrame6Ptrs:   blk.l 12,0
    lea   SpriteFrame1Ptrs,a0
    move.l #6-1,d0
.loopspriteinitpointersreset:
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    move.l #0,(a0)+
    dbra d0,.loopspriteinitpointersreset
    
    move.l LoadedLevel,a0
    Lea SpriteFrameTable,a5
    add.l #LEVELDATA_SPRITES,a0 ; Source data
    move.w (a0)+,SpriteNbFrames; Number of frames
    ; -- Fill Sprite 1
    lea SpriteZone,a1 ; Dest
    lea SpriteFrame1Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone
    ; -- If needed fill sprite 2
    cmp.w #2,SpriteNbFrames
    blt .end
    ; Continue A0 to read second frame
    ; Continue A1
    lea SpriteFrame2Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone
    ; -- If needed fill sprite 3
    cmp.w #3,SpriteNbFrames
    blt .end
    ; Continue A0 to read second frame
    ; Continue A1
    lea SpriteFrame3Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone 
    ; -- If needed fill sprite 4
    cmp.w #4,SpriteNbFrames
    blt .end
    ; Continue A0 to read second frame
    ; Continue A1
    lea SpriteFrame4Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone 
    ; -- If needed fill sprite 5
    cmp.w #5,SpriteNbFrames
    blt .end
    ; Continue A0 to read second frame
    ; Continue A1
    lea SpriteFrame5Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone 
    ; -- If needed fill sprite 6
    cmp.w #6,SpriteNbFrames
    blt .end
    ; Continue A0 to read second frame
    ; Continue A1
    lea SpriteFrame6Ptrs,a4 ; 12 pointers here
    move.l a4,(a5)+ ; fill SpriteFrameTable
    bsr FillSpriteZone 
.end
    ; -- Process specific animation for sprites. ------------
    
    
    cmp.w #4,currentmusic ; Plane, 2 frames anim, 2 set
    bne .nomusic4
    lea   SpriteFrameTable,a0 
    ; Create 2 sets of anims
    ; 0  Frame1 Frame1
    ; 4  Frame2 Frame2
    ; 8  Frame3 0
    ; 12 Frame4 Frame3
    ; 16 0      Frame4
    move.l 12(a0),d0
    move.l d0,16(a0)
    move.l 8(a0),d0
    move.l d0,12(a0)
    move.l #0,8(a0)
    ; Reset animation counter
    move.w #0,plane_counter
    bra .endallsprite
.nomusic4:  
    
    
    cmp.w #5,currentmusic ; Whale 4 frames. Add two ping pong frame at end
    bne .nomusic5
    lea   SpriteFrameTable,a0 ; 4 frames, create 6 frames. 
    ; 0 4 8 12 8(16) 4(20)
    move.l 8(a0),d0
    move.l d0,16(a0)
    move.l 4(a0),d0
    move.l d0,20(a0)    
    bra .endallsprite
.nomusic5:    
    
    cmp.w #6,currentmusic ; Butter fly. 3 frames. Add center frame at end.
    bne .nomusic6
    lea   SpriteFrameTable,a0 ; 3 frames, create 4 frames. Add second frame at position 4
    move.l 4(a0),d0
    move.l d0,12(a0)
    bra .endallsprite
.nomusic6:

.endallsprite:
.debugnosprite:
    rts

PlaneSwitchAnim:
    movem.l d0-d1/a0,-(a7)
    lea   SpriteFrameTable,a0 
    ; Create 2 sets of anims
    ; 0  Frame1 Frame3
    ; 4  Frame2 Frame4
    ; 8  0      0
    ; 12 Frame3 Frame1
    ; 16 Frame4 Frame4
    ; Switch 12 and 0
    move.l 0(a0),d1 
    move.l 12(a0),d0
    move.l d0,0(a0)
    move.l d1,12(a0)
    ; Switch 16 and 4
    move.l 4(a0),d1 
    move.l 16(a0),d0
    move.l d0,4(a0)
    move.l d1,16(a0)
    movem.l (a7)+,d0-d1/a0
    rts

; ------------------------------------------- 
; FillSpriteZone
; A0 zone source
; A1 zone to fill (dest)
; A4 pointers to store (12 pointers) 
; A5 should not be touched
FillSpriteZone:
    moveq #0,d0
    moveq #0,d4
    move.b (a0),d0 ; Height
    move.w d0,SpriteHeight ; Store height somewhere
    move.w d0,d4
    lsl.l  #2,d4 ; Number of byte of each sprite
    add.l #2,a0 ; Go to first sprite.
    ; ----------------------------------------------------------
    ; -- Sprite 1 ----------------------------------------------
    move.l a1,OFFSETSpriteMain1aPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop1
    move.b (a0)+,(a1)+
    dbra d5,.loop1
    ; -- Sprite Cursor
    ; Warning: DMA will chain with cursor sprite. So keep this here.
    move.l a1,OFFSETSpriteCursorPtr(a4)
    move.l #$225a3d00,(a1)+ ; Header
    lea SpriteCursorDataOnly,a2 ; Copy data from that place
    move.l #(16*4)-1,d5
.loop1cursor
    move.b (a2)+,(a1)+
    dbra d5,.loop1cursor 
    move.l #$00000000,(a1)+ ; stop
    ; ----------------------------------------------------------
    ; -- Sprite 2
    move.l a1,OFFSETSpriteMain1bPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop1b
    move.b (a0)+,(a1)+
    dbra d5,.loop1b 
    move.l #$00000000,(a1)+ ; stop
    ; ----------------------------------------------------------
    ; -- Sprite 3
    move.l a1,OFFSETSpriteMain2aPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop2a
    move.b (a0)+,(a1)+
    dbra d5,.loop2a 
    ; -- Sprite Gui 1
    ;  Warning: DMA will chain with cursor sprite. So keep this here.
    move.l a1,OFFSETSpriteGui1Ptr(a4)
    lea SpriteGui1,a2 ; Copy data from that place
    move.l #(18*4)-1,d5
.loop1gui1
    move.b (a2)+,(a1)+
    dbra d5,.loop1gui1  
    ; ----------------------------------------------------------    
    ; -- Sprite 4
    move.l a1,OFFSETSpriteMain2bPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop2b
    move.b (a0)+,(a1)+
    dbra d5,.loop2b 
    ; -- Sprite Gui 2
    ; Warning: DMA will chain with cursor sprite. So keep this here.
    move.l a1,OFFSETSpriteGui2Ptr(a4)
    lea SpriteGui2,a2 ; Copy data from that place
    move.l #(18*4)-1,d5
.loop1gui2
    move.b (a2)+,(a1)+
    dbra d5,.loop1gui2 
    ; ----------------------------------------------------------     
    ; -- Sprite 5
    move.l a1,OFFSETSpriteMain3aPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop3a
    move.b (a0)+,(a1)+
    dbra d5,.loop3a 
    move.l #$00000000,(a1)+ ; stop
    ; ----------------------------------------------------------
    ; -- Sprite 6
    move.l a1,OFFSETSpriteMain3bPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop3b
    move.b (a0)+,(a1)+
    dbra d5,.loop3b 
    move.l #$00000000,(a1)+ ; stop
    ; ----------------------------------------------------------
    ; -- Sprite 7
    move.l a1,OFFSETSpriteMain4aPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop4a
    move.b (a0)+,(a1)+
    dbra d5,.loop4a 
    move.l #$00000000,(a1)+ ; stop   
    ; ----------------------------------------------------------    
    ; -- Sprite 8
    move.l a1,OFFSETSpriteMain4bPtr(a4)
    move.l #$225a3d00,(a1)+
    move.w d4,d5
    sub.w #1,d5
.loop4b
    move.b (a0)+,(a1)+
    dbra d5,.loop4b 
    move.l a1,OFFSETNullSpritePtr(a4)
    move.l #$00000000,(a1)+ ; stop  
    ; All A0 should be consummed
    rts

; ------------------------------------------- 
EraseParalaxBackground:
    ; -- BACK - TOP - 32 COLORS --------------------------------
    move.l paralaxChipPtr,a0
    add.l #paralax_backtop_640x19_offset,a0 ; 80 bytes x 19 on 5 planes (one after the other)
    move.l a0,a1
    add.l #80*19,a1 ; plane 2
    move.l a1,a2
    add.l #80*19,a2
    move.l a2,a3
    add.l #80*19,a3
    move.l a3,a4
    add.l #80*19,a4
    ; Each plane is 80*19 bytes 
    move.l #19-1,d0
.loop1:
    move.l #80-1,d1
.loopline:    
    move.b #0,(a0)+
    move.b #0,(a1)+
    move.b #0,(a2)+
    move.b #0,(a3)+
    move.b #0,(a4)+
    dbra d1,.loopline
    ; Wait 1 frame
    bsr wait1Frame
    dbra d0,.loop1
    
    ; -- BACK 2
    move.l paralaxChipPtr,a0    
    add.l #paralax_back_640x43_offset,a0 ; 80*43*5
    ;add.l #80*43*1,a1 ; plane 2
    move.l a0,a1
    add.l #80*43,a1 ; plane 2
    move.l a1,a2
    add.l #80*43,a2
    move.l a2,a3
    add.l #80*43,a3
    move.l a3,a4
    add.l #80*43,a4
    ; Each plane is 80*43 bytes 
    move.l #43-1,d0
.loop1b:
    move.l #80-1,d1
.looplineb:    
    move.b #0,(a0)+
    move.b #0,(a1)+
    move.b #0,(a2)+
    move.b #0,(a3)+
    move.b #0,(a4)+
    dbra d1,.looplineb
    ; Wait 1 frame
    bsr wait1Frame
    dbra d0,.loop1b
    
    ; -- Front
    move.l paralaxChipPtr,a0    
    add.l #paralax_front_960x43_offset,a0 ; 4 planes
    ;add.l #120*43*1,a1 ; plane 2
    move.l a0,a1
    add.l #120*43,a1 ; plane 2
    move.l a1,a2
    add.l #120*43,a2
    move.l a2,a3
    add.l #120*43,a3
    ; Each plane is 120*43 bytes 
    move.l #43-1,d0
.loop1c:
    move.l #120-1,d1
.looplinec:    
    move.b #0,(a0)+
    move.b #0,(a1)+
    move.b #0,(a2)+
    move.b #0,(a3)+
    dbra d1,.looplinec
    ; Wait 1 frame
    bsr wait1Frame
    dbra d0,.loop1c

    ; paralax_frontbottom_960x50 ; 4 planes
    move.l paralaxChipPtr,a0
    add.l #paralax_frontbottom_960x50_offset,a0
    ;add.l #120*50*1,a1 ; plane 2
    move.l a0,a1
    add.l #120*50,a1 ; plane 2
    move.l a1,a2
    add.l #120*50,a2
    move.l a2,a3
    add.l #120*50,a3
    ; Each plane is 120*50 bytes 
    move.l #50-1,d0
.loop1d:
    move.l #120-1,d1
.looplined:    
    move.b #0,(a0)+
    move.b #0,(a1)+
    move.b #0,(a2)+
    move.b #0,(a3)+
    dbra d1,.looplined
    ; Wait 1 frame
    bsr wait1Frame
    dbra d0,.loop1d

    rts


; -------------------------------------------    
;
BackgroundPositionBack: ; Background is 320, so position is 0 to 319
    dc.w    0
BackgroundPositionFront: ; Front is 640, so position is 0 to 639
    dc.w    0 

BackgroundPositionBack_Prev: ; Background is 320, so position is 0 to 319
    dc.w    0
BackgroundPositionFront_Prev: ; Front is 640, so position is 0 to 639
    dc.w    0     
    
ParalaxDoubleBuffer:
    dc.l    0 ; planesparalax1 ; Display
    dc.l    0 ; planesparalax2 ; Compute
;---------------------------------------------------------------    
ParalaxDoDoubleBuffer:

    ; Swap front and back
    move.l ParalaxDoubleBuffer,a0
    move.l ParalaxDoubleBuffer+4,a1
    move.l a1,ParalaxDoubleBuffer
    move.l a0,ParalaxDoubleBuffer+4    

    ; Set Paralax
    ; ParalaxPlanesPtr. 42 x 5 one after the another
    ; planesparalax
    Move.l	ParalaxDoubleBuffer,d0
	Lea		BackgroundPlans_Part2,a0
    Bsr     Put_pointeurs
    add.l   #42*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs        
    add.l   #42*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs    
    add.l   #42*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs 
    add.l   #42*43,d0
    add.l   #8,a0
    Bsr     Put_pointeurs 
    
    move.w BackgroundPositionBack,d0
    move.w d0,BackgroundPositionBack_Prev ; Save the scrolling where the buffer was calculated

    move.w BackgroundPositionFront,d0
    move.w d0,BackgroundPositionFront_Prev ; Save the scrolling where the buffer was calculated
    rts
    
;---------------------------------------------------------------  
; FIRST PART of parallax (the zone of 43 pixels with back+Front)
; Here we transfert the background. From 640 image to screen (which is empty at that stage)  
Paralax_1_Background:

    ; -- Compute front plane hardware decay 0 to 16 in d4
    moveq #0,d4
    moveq #0,d3
    move.w BackgroundPositionFront,d3 ; Decay of hardware scroll. Right. We need to compensate
    and.w  #$000F,d3
    move.w #$f,d4
    sub.w d3,d4

    ; -- Copy background.
    moveq #0,d0
    move.w BackgroundPositionBack,d0
    add.w d4,d0 ; Compensation of front hardware scroll
    
    lsr.w #4,d0 ; /16
    lsl.w #1,d0 ; *2 to get bytes
    
    move.l paralaxChipPtr,a0
    add.l #paralax_back_640x43_offset,a0 ; Source 80*43*5
    add.l d0,a0

    move.w BackgroundPositionBack,d1
    add.w d4,d1 ; Compensation of front hardware scroll
    and.w #$000f,d1 ; Decay
    move.w #$000f,d2
    sub.w d1,d2 ; d2 got the right shift (0-16)

    ; Blitter version
    ; A = background in 640 (80) pixels width, 5 planes
    ; D = screen, in 320+16 (42) 5 planes.
    ; All side by side.
    
    if SHOWRASTER==1
    move.w #$FFF,$dff180
    endc
        
	jsr	waitblitter	
    
    if SHOWRASTER==1
    move.w #$888,$dff180
    endc

WIDTH1=42 
	MOVE.W	#(80-WIDTH1),$DFF064	; MOD A Source
	MOVE.W	#42-WIDTH1,$DFF066	; MOD D Dest (dest = 44)
    MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	a0,$DFF050  ; SOURCE A
	MOVE.L	ParalaxDoubleBuffer+4,a4
    sub.l #2,a4
    move.l a4,$DFF054	; dest D (screen)
	Move.w	#0,$dff042			; Decay source B + flag line trace
    lsl.w #8,d2
	lsl.w #4,d2 ; Decay value
	OR.W	#%0000100111110000,D2 ; 09f0
	;         ssss1234mmmmmmmm         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	move.w #((43*5)<<6)+(WIDTH1/2),$dff058 ; BltSize, height*64 , width (WORDS!!) launch transfert
    rts

;---------------------------------------------------------------
; Copy 4 planes (Front), using mask.
; Copy on top of back already on screen
Paralax_2_Background:
    
    moveq #0,d0
    moveq #0,d1
    move.w BackgroundPositionFront,d0
    ;add.w #2,d0 ; next frame
    lsr #4,d0 ; /16
    lsl #1,d0 ; *2

    move.l paralaxChipPtr,a0
    add.l	#paralax_front_960x43_offset,a0 ; Source A (width 120)
    move.l paralaxChipPtr,a1
    add.l	#paralax_front_960x43_mask_offset,a1 ; Source B (width 120)
    add.l d0,a0
    add.l d0,a1
    
    move.l  ParalaxDoubleBuffer+4,a2
PARALAXFRONTLINES=43
    ; Plane 1 to 4
    moveq #0,d2 ; decay
    
	jsr	waitblitter
WIDTH2=40	
	MOVE.W	#120-WIDTH2,$DFF064	; MOD A Source (4 planes)
    MOVE.W	#120-WIDTH2,$DFF062	    ; MOD B Source
    MOVE.W	#42-WIDTH2,$DFF060	; MOD C Source
	MOVE.W	#42-WIDTH2,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	a0,$DFF050  ; SOURCE A
    MOVE.L	a1,$DFF04C  ; SOURCE B
    MOVE.L	a2,$DFF048	; Source C (screen)
	MOVE.L	a2,$DFF054	; dest D (screen)
	Move.w	#0,$dff042	; Decay source B + flag line trace
    lsl.w #8,d2
	lsl.w #4,d2 ; Decay value
	OR.W	#%0000111110111000,D2 
	;         ssssABCDmmmmmmmm         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
    ;move.w #(PARALAXFRONTLINES*4<<6)+20,$dff058 ; BltSize, height*64 , width (WORDS!!) launch transfert	
    move.w #(PARALAXFRONTLINES*4<<6)+(WIDTH2/2),$dff058 ; BltSize, height*64 , width (WORDS!!) launch transfert	    
    
    rts

;---------------------------------------------------------------
; Front middle part, copy last plane (5). Source is always 0. So only use mask.
Paralax_3_Background:

    moveq #0,d0
    moveq #0,d1
    move.w BackgroundPositionFront,d0
    ;add.w #2,d0 ; next frame
    lsr #4,d0 ; /16
    lsl #1,d0 ; *2

    move.l paralaxChipPtr,a1
    add.L	#paralax_front_960x43_mask_offset,a1 ; Source B (width 120)
    add.l d0,a1
    move.l  ParalaxDoubleBuffer+4,a2
    add.l #43*42*4,a2 ; go to plane 5
    moveq #0,d2
    ; Plane 5
    ; source A is always 0. mask b=0 should let A go.
    ; 0-abc=c=0
    ; 1-abC=C=0
    ; 2-aBc=a=0
    ; 3-aBC=a=1
    ; 4-Abc=c=0
    ; 5-AbC=C=0
    ; 6-ABc=A=0
    ; 7-ABC=A=1    
    
	jsr	waitblitter	
    
    if SHOWRASTER==1
    move.w #$00F,$dff180
    endc
    
WIDTH3=40
	;MOVE.W	#82+3*122,$DFF064	; MOD A Source
    MOVE.W	#120-WIDTH3,$DFF062	; MOD B Source
    MOVE.W	#42-WIDTH3,$DFF060	; MOD C Source
	MOVE.W	#42-WIDTH3,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	;MOVE.L	a0,$DFF050  ; SOURCE A
    MOVE.L	a1,$DFF04C  ; SOURCE B
    MOVE.L	a2,$DFF048	; Source C (screen)
	MOVE.L	a2,$DFF054	; dest D (screen)
	Move.w	#0,$dff042			; Decay source B + flag line trace
    lsl.w #8,d2
	lsl.w #4,d2 ; Decay value
	OR.W	#%0000011110001000,D2 ; 09f0
	;         ssssABCDmmmmmmmm         
	MOVE.W	D2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
    move.w #(PARALAXFRONTLINES<<6)+(WIDTH3/2),$dff058 ; BltSize, height*64 , width (WORDS!!) launch transfert    
   
    rts
	
;-------------------------------
main_irq:	

	bsr VideoIrq

    if DISPLAYDEBUGMEMORY==1
    bsr fillDebugMem
    endc
    
	rts  								;end of irq	
;----------------------------------------------------------------

ParalaxFlagSwitch: ; 25 fps , so compute one picture on 2 images
    dc.b    0

    even
    
SpriteStopUpdate:
    dc.w    0
    
    

;---------------------------------------------------------------
; Work done during interruption (scrolling)
VideoIrq:

	add.w	#1,wait
    
    ; -- Update sprite position (very early in IRQ, copper will set them at start)
    cmp.w #1,SpriteStopUpdate
    beq .nospriteupdate
    bsr updateSpriteCentralData ; CPU. Update position of central sprite    
.nospriteupdate:
 
    cmp.l #0,paralaxChipPtr ; Memory not allocated for paralax ? so do nothing
    beq .paralaxnext
    
    bsr UpdateBackgroundScroll  ; CPU. Scrolling of graphic background (Only moving pointers here)      
    
    add.b #1,ParalaxFlagSwitch
    cmp.b #2,ParalaxFlagSwitch
    bne .noswitch
    bsr ParalaxDoDoubleBuffer  ; CPU Switch background buffers
    move.b #0,ParalaxFlagSwitch
.noswitch:

    ; We compute on 2 frames.
    ; -- Paralax phase 1 (frame 1)
    cmp.b #0,ParalaxFlagSwitch
    bne .noparalax1
    bsr Paralax_1_Background ; BLITTER operation
    bra .paralaxnext
.noparalax1:    
    ; -- Paralax phase 2 (frame 2)
    bsr Paralax_2_Background ; BLITTER operation
.paralaxnext

    ; -- Update all sprite (early in irq, not to conflict while displaying)
    cmp.w #1,SpriteStopUpdate
    beq .nospriteupdate2
    bsr AnimateSprite            ; CPU. Change pointers
    bsr CentralSpriteoscillation ; CPU Central Sprite oscillation
.nospriteupdate2:
    bsr TestMouseAndMoveSprite
    bsr DisplaySpriteCursor
    ; -- Update gui flags
    bsr UpdateMouseGuiFlags ; CPU
    bsr UpdateGuiIcons      ; CPU

    ; -- Text scroll
    bsr DoScrollText ; BLITTER (BUG Inside, to Debug)
    
    ; -- Gradient
    move.w #32,d4 ; 32 colors
    bsr UpdateSteps ; CPU
    move.w #64,d4 ; 64 colors
    bsr UpdateStepsCopper ; CPU
    
    ; -- Last part of Paralax
    cmp.l #0,paralaxChipPtr ; Memory not allocated for paralax ? so do nothing
    beq .noparalaxPhase2    
    cmp.b #1,ParalaxFlagSwitch
    bne .noparalaxPhase2
    bsr Paralax_3_Background ; BLITTER operation
 .noparalaxPhase2:
 

    ; If song 4, move plane and switch anim.
    cmp.w #4,currentmusic
    bne .nomusic4
    cmp.b #1,flag_module_is_loading
    beq .nomusic4 ; Not when loading
    move.w plane_counter,d0 ; Keep old value
    add.w #1,plane_counter
    clr.l d1
    move.w plane_counter,d1
    ; -- Move down, during 32 seconds
    cmp.w #1600,d1 
    bhi .planenostep1
    ; During 32 seconds, go down
    ; 0 to 32*50 ... 0 to 1600
    move.w #133,SprCentral_y
    lsr.w #6,d1 ; /64 ... 0 to 25
    add.w d1,SprCentral_y
    bra .nomusic4
.planenostep1: 
    ; Move up during 16 seconds
    cmp.w #2400,d1
    bhi .planenostep2   
    ; animation switch ?
    cmp.w #1600,d0
    bne .noswitchplane
    bsr PlaneSwitchAnim
.noswitchplane: 
    ; During 16 seconds go up
    ; 1600 to 2400
    ; need to remove 25 steps.
    sub.w #1600,d1
    lsr.w #5,d1 ; /32 , 0 to 25
    move.w #25,d2
    sub.w d1,d2 ; d2 = 25 to 0
    move.w #133,SprCentral_y
    add.w d2,SprCentral_y
    bra .nomusic4
.planenostep2: 
    ; -- Animation over, restart
    ; reset counter and switch anim
    move.w #0,plane_counter
    move.w #133,SprCentral_y
    bsr PlaneSwitchAnim
.nomusic4
    ;move.w SprCentral_y,$100

    ; switch palette
    add.w #1,alternatepalette_counter
    cmp.w #ALTERNATETIME,alternatepalette_counter
    bne .noswitchpal
    bsr LaunchGradientTransition ; Switch between set 1 and 2.
.noswitchpal:

	rts
;---------------------------------------------------------------
CentralSpriteoscillation:
    ; Central Sprite oscillation
    add.w #1,CentraSpriteTableSpeed
    cmp.w #3,CentraSpriteTableSpeed
    bmi .noresettable
    move.w #0,CentraSpriteTableSpeed
    move.l CentraSpriteTableYPtr,a0
    moveq #0,d0
    move.b (a0),d0
    move.w d0,CentralSpriteOffsetY
    add.l #1,a0
    move.l a0,CentraSpriteTableYPtr
    cmp.b #$ff,(a0)
    bne .noresettable
    move.l #CentralSpriteTableY,CentraSpriteTableYPtr
 .noresettable:
    rts


; --------------------------------------------  
; This table will be dynamycally filled when init sprite  
SpriteFrameTable:     
    dc.l 0 ; SpriteFrame1Ptrs   
    dc.l 0 ; SpriteFrame2Ptrs
    dc.l 0 ; SpriteFrame3Ptrs
    dc.l 0 ; SpriteFrame4Ptrs
    dc.l 0 ; SpriteFrame5Ptrs
    dc.l 0 ; SpriteFrame6Ptrs
    dc.l 0 ; End is 0
SpriteFrameTablePtr:
    dc.l SpriteFrameTable
SpriteFrameTableTimer:
    dc.w 0
SpriteAnimSpeed:
    dc.w 5 ; Number of frame to wait for next animation

; --------------------------------------------  
SpriteAnimationResetTable:
    move.l #SpriteFrameTable,SpriteFrameTablePtr
    lea SpriteFrameTableTimer+1,a0
    move.b #0,(a0)
    rts

; --------------------------------------------       
AnimateSprite:
    lea SpriteFrameTableTimer+1,a0
    add.b #1,(a0)
    move.w SpriteAnimSpeed,d0 ; 5 default
    cmp.w SpriteFrameTableTimer,d0
    bne .Animate_End
    lea SpriteFrameTableTimer+1,a0
    move.b #0,(a0)
    
    ; next frame
    add.l #4,SpriteFrameTablePtr
    move.l SpriteFrameTablePtr,a0
    cmp.l #0,(a0)
    bne .okframe
    bsr SpriteAnimationResetTable
.okframe:
    ; Change frame of sprite
    move.l SpriteFrameTablePtr,a0 ; 12 pointers
    move.l (a0),SpriteCurrentFrame ; Save current pointer frame
    move.l SpriteCurrentFrame,a4 ; 12 pointers here
    Bsr SetSpritePointerInCopper ; init sprite in copper  
.Animate_End:
    rts

; --------------------------------------------    
InitCursorMouse:
    lea SpriteCursorDataOnly,a0
    lea SpriteFrame1Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame2Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull 
    lea SpriteFrame3Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame4Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame5Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame6Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull 
    rts

; --------------------------------------------     
InitCursorMouseWait:
    lea SpriteCursorWaitDataOnly,a0
    lea SpriteFrame1Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame2Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull 
    lea SpriteFrame3Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame4Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame5Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull
    lea SpriteFrame6Ptrs,a4 ; 12 sprites pointers
    bsr CopySpriteDataIfPointerNotNull    
    rts 

; --------------------------------------------   
CopySpriteDataIfPointerNotNull:
    move.l OFFSETSpriteCursorPtr(a4),a1  
    cmp.l #0,a1
    beq .copylong_end
    move.l a0,a2
    add.l #4,a1
    move.l #(16/4)-1,d0
.copylong:
    move.l (a2)+,(a1)+
    move.l (a2)+,(a1)+
    move.l (a2)+,(a1)+
    move.l (a2)+,(a1)+    
    dbra d0,.copylong
.copylong_end:    
    rts
    
; -------------------------------------------- 
; DisplayGuiIcon
; Display an ami file in the gui bitplan. 
; a0 structure
; style 0=off 1=on 2=rollover
;gui_prev:               dc.b 16,28,40,19   ; sizex, sizey, posx, posy
;                        dc.l gui_prev_off  ; adresse of 3 ami files
;                        dc.l gui_prev_on
;                        dc.l gui_prev_rollover
DisplayGuiIcon:  
    move.l a0,a1
    ; -- Get Ami data adress
    add.l #4,a1 ; jump header
    lsl.l #2,d0 ; *4
    add.l d0,a1 ; do to style pointer
    move.l (a1),a1 ; get ami adresse in A1
    add.l #(2+2+2+4+32*2),a1 ; Start of bitplans
    ; -- Get start gui adress bitplan (in a2)
    lea GuiData,a2
    add.l #(2+2+2+4+32*2),a2 ; Start of bitplan. 5 bitplans. 320x64
    clr.l d0
    move.b 2(a0),d0 ; Pos X
    lsr.l #3,d0 ; /8
    add.l d0,a2 ; Add X
    moveq #0,d0
    move.b 3(a0),d0 ; Pos Y
    mulu #40,d0
    add.l d0,a2 ; Start of destination in bitplan.
    ; -- Get size X and size Y.
    ; As size X can be 1 or 2 bytes, we do two special loops.
    moveq #0,d0
    move.b 1(a0),d0 ; Size Y  
    cmp.b #16,(a0); SizeX : 8 or 16
    beq  DisplayGuiIcon_Loop16pixels
    ; -- Copy 8 pixels bob
DisplayGuiIcon_Loop8pixels:
    ; module is 39 bytes (40-1)
    move.w #5-1,d6
.loopbitplans
    move.l a2,a3
    move.w d0,d1 ; Y
    sub.w #1,d1
.looplines
    move.b (a1)+,(a3) ; Copy 1 byte
    add.l #40,a3
    dbra d1,.looplines
    add.l #40*64,a2 ; next bitplan
    dbra d6,.loopbitplans
    bra DisplayGuiIcon_End
    ; -- Copy 16 pixels bob
DisplayGuiIcon_Loop16pixels:
     ; module is 38 bytes (40-2)
    move.l #5-1,d6
.loopbitplans
    move.l a2,a3
    move.w d0,d1 ; Y
    sub.w #1,d1
.looplines
    move.b (a1)+,(a3) ; Copy 1 word, but can be non aligned
    move.b (a1)+,1(a3) ; Copy 1 word, but can be non aligned
    add.l #40,a3
    dbra d1,.looplines
    add.l #40*64,a2 ; next bitplan
    dbra d6,.loopbitplans   
DisplayGuiIcon_End:
    rts
    
;---------------------------------------------------------------  
DisplayNameDestPtr: ; Gui screen
    dc.l    0
DisplayNameSourcePtr: ; Title arts
    dc.l    0
DisplayNameMode:
    dc.b    0 ; 1 = fade int (left to right), 2=fade out (right to left)

    even

DisplayNamePosIndex:
    dc.w    0 ; -8 to 25+8 for fade in, 25+8 to -8 for fade out.
    
    even
    
;--------------------------------------------------------------- 
; d0.l id of music 1 to 8 (9 is loading)
RequestDisplayMusicName:
    ; -- Get start gui adress bitplan (in a2)
    lea GuiData,a2
    add.l #(2+2+2+4+32*2),a2 ; Start of bitplan. 5 bitplans. 320x64
    add.l #11,a2 ; Add X
    add.l #26*40,a2 ; Start of destination in bitplan. 
    move.l a2,DisplayNameDestPtr
    
    ; Source data
    ; -- Set source
    lea song_titles,a1
    add.l #(2+2+2+4+32*2),a1
    sub.l #1,d0
    mulu #25*16,d0
    add.l d0,a1 ; Start of input data.   
    move.l a1,DisplayNameSourcePtr
    
    move.w #1,DisplayNameMode
    move.w #-8,DisplayNamePosIndex
    rts
; -----------------------------------------------------    
RequestEraseMusicName:    
    ; -- Get start gui adress bitplan (in a2)
    lea GuiData,a2
    add.l #(2+2+2+4+32*2),a2 ; Start of bitplan. 5 bitplans. 320x64
    add.l #11,a2 ; Add X
    add.l #26*40,a2 ; Start of destination in bitplan. 
    move.l a2,DisplayNameDestPtr
    
    ; Source data
    ; -- Set source
    lea song_titles,a1
    add.l #(2+2+2+4+32*2),a1
    sub.l #1,d0
    mulu #25*16,d0
    add.l d0,a1 ; Start of input data.   
    move.l a1,DisplayNameSourcePtr
    
    move.w #2,DisplayNameMode
    move.w #-8,DisplayNamePosIndex
    rts   
    
;---------------------------------------------------------------    
UpdateDisplayMusicName:
    ; Test if active
    cmp.w #0,DisplayNameMode
    beq UpdateDisplayMusicName_Exit
    
    bsr DisplayMusicNameWithPattern  
    
    add.w #1,DisplayNamePosIndex
    cmp.w #25+8,DisplayNamePosIndex
    bne UpdateDisplayMusicName_Exit
    ; -- end fade
    
    ; If fade of and a module is loading, then display "loading".
    cmp.b #1,flag_module_is_loading
    bne .noloading
    cmp.w #2,DisplayNameMode
    bne .noloading
    
    ; Display "loading"
    moveq #0,d0
    move.w #(NBMODULES+1),d0 ; loading
    bsr RequestDisplayMusicName ; with scrolling  
    bra    UpdateDisplayMusicName_Exit
    
.noloading   
    move.w #0,DisplayNameMode

UpdateDisplayMusicName_Exit:
    rts
    
DisplayMusicNameWithPattern:
    ; Display 8 slices of 1byte*16 lines on 5 planes, using a pattern
    ; The pattern is going out on left and right, so need also to be managed by slide
    
    moveq #0,d0
    move.w DisplayNamePosIndex,d0 ; Slice number -8 to 25*8    
    move.l #title_mask_data,a2 ; slice data
    ; For fade out, start by end of slice.
    cmp.w #2,DisplayNameMode
    bne .nofadeout
    add.l #7,a2 ; start by end of patterns
.nofadeout:
    
    move.l #8-1,d6 ; 8 slices
    
DisplayMusicNameWithPattern_sliceloop: 

    cmp.l #0,d0
    bmi .nextslice
    
    cmp.l #25,d0
    bpl .nextslice
    
    move.l DisplayNameSourcePtr,a0
    move.l DisplayNameDestPtr,a1
    
    ; Display slice d0 on screen, using a2 pattern
    ; -- 16 bytes (vertical) on 5 planes
    add.l d0,a0
    move.l a0,a3 ; Src
    add.l d0,a1
    move.l a1,a4; Dest
    move.l a2,a5; Pattern
    
    move.l #5-1,d5 ; -- 5 planes
.planes
    move.l #16-1,d4
.lines
    ; Copy 16 lines
    move.b (a3),d3
    and.b (a5),d3 ; Apply mask
    move.b d3,(a4)

    add.l #25,a3 ; next line source
    add.l #40,a4 ; next line dest
    add.l #8,a5 ; Next mask line

    dbra d4,.lines

    ; Next plan
    add.l #25*(NBMODULES+1)*16,a0 ; next plane source ( 9 titles of 16 lines) 25 bytes width
    add.l #40*64,a1 ; next plane dest
    move.l a0,a3 ; Src
    move.l a1,a4 ; Dest    
    move.l a2,a5 ; Pattern , reset pattern
    
    dbra d5,.planes ; 5 planes

.nextslice:
    
    add.l #1,d0  ; next slice position

    add.l #1,a2  ; next slide pattern
    cmp.w #2,DisplayNameMode
    bne .nofadeout2
    sub.l #2,a2  ; prev slide pattern
.nofadeout2:
    
    dbra d6,DisplayMusicNameWithPattern_sliceloop

    rts
;---------------------------------------------------------------
SpriteCentral_motionStep:
    dc.w    0 ; 0=do nothing, 1=come from left, 2=slow to right, 3=fast to right.

SpriteCentral_AskComeFromLeft:
    move.w #1,SpriteCentral_motionStep
    move.w #SPRITECENTRAL_STARTX,SprCentral_x
    rts
    
SpriteCentral_AskDoNothing:
    move.w #0,SpriteCentral_motionStep  
    rts

SpriteCentral_AskSlowRight:
    move.w #2,SpriteCentral_motionStep
    rts

SpriteCentral_AskFastRight:
    move.w #3,SpriteCentral_motionStep
    rts    
;---------------------------------------------------------------
updateSpriteCentralData:
    ; Update position
    ; Come from left
    cmp.w #1,SpriteCentral_motionStep
    bne .nostep1
    add.w #1,SprCentral_x
    cmp.w #SPRITECENTRAL_CENTERX,SprCentral_x
    bne .nostep1
    ; end of motion left to center
    bsr SpriteCentral_AskDoNothing
.nostep1
    ; Going right
    cmp.w #2,SpriteCentral_motionStep
    bne .nostep2
    add.w #1,SprCentral_x
    cmp.w #SPRITECENTRAL_ENDX,SprCentral_x
    bne .nostep2
    ; end of motion left to center
    bsr SpriteCentral_AskDoNothing
.nostep2
    ; Going right (fast)
    cmp.w #3,SpriteCentral_motionStep
    bne .nostep3
    add.w #4,SprCentral_x
    cmp.w #SPRITECENTRAL_ENDX,SprCentral_x
    bmi .nostep3
    ; end of motion left to center
    bsr SpriteCentral_AskDoNothing
.nostep3

    ; Sprite part 1
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain1aPtr(a0),a0
    move.l #0,d2 ; offset X
    bsr updateSpriteCentralDataOneSprite
    
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain1bPtr(a0),a0
    move.l #0,d2 ; offset X    
    bsr updateSpriteCentralDataOneSprite  

    ; Sprite part 2
    move.l SpriteCurrentFrame,a0 ; 12 pointers here    
	move.l	OFFSETSpriteMain2aPtr(a0),a0
    move.l #16,d2 ; offset X
    bsr updateSpriteCentralDataOneSprite
    
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain2bPtr(a0),a0
    move.l #16,d2 ; offset X    
    bsr updateSpriteCentralDataOneSprite 

    ; Sprite part 3
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain3aPtr(a0),a0
    move.l #32,d2 ; offset X
    bsr updateSpriteCentralDataOneSprite
    
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain3bPtr(a0),a0
    move.l #32,d2 ; offset X    
    bsr updateSpriteCentralDataOneSprite 
 
    ; Sprite part 4
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain4aPtr(a0),a0
    move.l #48,d2 ; offset X
    bsr updateSpriteCentralDataOneSprite
    
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
	move.l	OFFSETSpriteMain4bPtr(a0),a0
    move.l #48,d2 ; offset X    
    bsr updateSpriteCentralDataOneSprite 
 
    rts

;---------------------------------------------------------------
; A0 is sprite structure. Word 0 and word 1 are control words.
; We consider these 2 words as 4 bytes. 0 1 2 3
; one bit is on last byte (not convenient).
; E7 E6 E5 E4 E3 E2 E1 E0 = VSTART
; H8 H7 H6 H5 H4 H3 H2 H1 = HSTART
; L7 L6 L5 L4 L3 L2 L1 L0 = VSTOP
; AT 0  0  0  0  E8 L8 H0

updateSpriteCentralDataOneSprite:
	moveq #0,d0
	moveq #0,d1
;CENTRALSPRITEHEIGHT=34

	Move.w	SprCentral_x,d0	; X
    add.w d2,d0 ; Offset of X
    ; -- HSTART. Bit 0 byte 3, is horizontal first bit.
	Bclr	#0,3(a0)
	Btst	#0,d0
	Beq.b	.no_first
	Bset	#0,3(a0)
.no_first:
    ; -- Set horizontal pos (the remaining 8 bits)
    lsr	#1,d0 ; divide X by 2 (we set the last bit)
 	Move.b	d0,1(a0) ; Byte 1 is H8 to H1. (HSTART)
    ; -- Take care of Y now.
	moveq #0,d0
	Move.w	SprCentral_y,d0
    add.w   CentralSpriteOffsetY,d0 ; offset to make central element move
	Move.l	d0,d1
	Add.w	SpriteHeight,d1
	Move.b	d0,(a0)  ; VSTART (not higher bit)
	Move.b	d1,2(a0) ; VSTOP  (not higher bit)
	; -- Write higher bits of VSTART/VSTOP
	And.w	#$ff00,d0
	And.w	#$ff00,d1
	Lsr	    #8,d0
	Lsr	    #8,d1
    ; Clear and set E8
	Bclr	#2,3(a0)
    ; test and write bit
	Btst	#0,d0
	Beq.b	.no_first_1
	Bset	#2,3(a0)
.no_first_1:
    ; Clear and set L8
	Bclr	#1,3(a0)
	Btst	#0,d1
	Beq.b	.no_first_2
	Bset	#1,3(a0)
.no_first_2:
    ; Set attached bit
    Bset	#7,3(a0)
    rts

SPRITECENTRAL_CENTERX=$f0
SPRITECENTRAL_STARTX=0
SPRITECENTRAL_ENDX=$1c0
; Sprite position X and Y
SprCentral_x:
    dc.w 0
SprCentral_y:
    Dc.w	$85 ; Middle of height
  
; Copy list for motion to usage table, end by $ff  
CopyMotion:
.loop
    cmp.b #$ff,(a0)
    beq .end
    move.b (a0)+,(a1)+
    bra .loop
.end:
    rts
  
InitNoMotion:
    lea CentralSpriteTableY_NoMotion,a0
    lea CentralSpriteTableY,a1
    bsr CopyMotion
    rts

InitSmallMotion:
    lea CentralSpriteTableY_SmallMotion,a0
    lea CentralSpriteTableY,a1
    bsr CopyMotion
    rts

InitBigMotion:
    lea CentralSpriteTableY_BigMotion,a0
    lea CentralSpriteTableY,a1
    bsr CopyMotion
    rts    

 
;--------------------------------------------------------------- 
; Init motion of sprite
; currentmusic 1 to 8 
InitMotion:    
    move.w currentmusic,d0
    
    move.w #5,SpriteAnimSpeed ; Default animationspeed
    bsr InitBigMotion ; Default motion
    
    cmp.w #1,d0 ; Jungle, star ship
    bne .no1
    move.w #133,SprCentral_y
    bra .end
.no1
    
    cmp.w #2,d0 ; Jazzy car
    bne .no2
    move.w #184,SprCentral_y
    bra .end
.no2

    cmp.w #3,d0 ; Dragon
    bne .no3
    move.w #133,SprCentral_y
    bra .end
.no3

    cmp.w #4,d0 ; Plane
    bne .no4
    move.w #133,SprCentral_y
    bra .end
.no4

    cmp.w #5,d0 ; Whale
    bne .no5
    move.w #120,SprCentral_y
    move.w #10,SpriteAnimSpeed ; Default animationspeed
    bsr InitNoMotion
    bra .end
.no5  

    cmp.w #6,d0 ; Butterfly
    bne .no6
    move.w #112,SprCentral_y
    move.w #6,SpriteAnimSpeed
    bra .end
.no6

    cmp.w #7,d0 ; Flying car 2
    bne .no7
    move.w #174,SprCentral_y
    bra .end
.no7  

    cmp.w #8,d0 ; SpaceShip 2
    bne .no8
    move.w #143,SprCentral_y
    bra .end
.no8  

.end
    rts

;---------------------------------------------------------------
DisplaySpriteCursor:
	moveq #0,d0
	moveq #0,d1
    move.l SpriteCurrentFrame,a0 ; 12 pointers here
    move.l OFFSETSpriteCursorPtr(a0),a0  
    ; Also update the default cursor
    lea SpriteCursor,a1
	Move.w	Spr_x,d0	; X
	Bclr	#0,3(a0)
    Bclr	#0,3(a1)
	Btst	#0,d0
	Beq.b	.no_first
	Bset	#0,3(a0)
    Bclr	#0,3(a1)
.no_first:
    lsr.w	#1,d0
	Move.b	d0,1(a0)
    Move.b	d0,1(a1)
	moveq #0,d0
	Move.w	Spr_y,d0
	Move.l	d0,d1
	Add.l	#16,d1 ; height
	Move.b	d0,(a0)
	Move.b	d1,2(a0)
	Move.b	d0,(a1)
	Move.b	d1,2(a1)		
	And.w	#$ff00,d0
	And.w	#$ff00,d1
	Lsr.w	#8,d0
	Lsr.w	#8,d1
	Bclr	#2,3(a0)
    Bclr	#2,3(a1)
	Btst	#0,d0
	Beq.b	.no_first_1
	Bset	#2,3(a0)
    Bset	#2,3(a1)
.no_first_1:
	Bclr	#1,3(a0)
    Bclr	#1,3(a1)
	Btst	#0,d1
	Beq.b	.no_first_2
	Bset	#1,3(a0)
    Bset	#1,3(a1)
.no_first_2:

    rts

;---------------------------------------------------------------
;	Mouse
;--------------------------------------------------------------- 
TestMouseAndMoveSprite:
        moveq #0,d0
        moveq #0,d1
        move.w  $dff00a,d1
        move.w  d1,d0
        sub.b   oldhorizcnt,d0
        ext.w   d0
        add.w   d0,Spr_x
        move.b  d1,oldhorizcnt
        lsr.w   #8,d1
        move.b  oldvertcnt,d0
        move.b  d1,oldvertcnt
        sub.b   d0,d1
        ext.w   d1
        add.w   d1,Spr_y 
    
        ; -- limit spr_Y and spr_X
        
MOUSELIMIT_YMIN=$f3  
MOUSELIMIT_YMAX=$f0+(7*8) 
;MOUSELIMIT_XMIN=$a0-8-8  
MOUSELIMIT_XMIN=$90-8-8 
MOUSELIMIT_XMAX=$1c0-8
        
        cmp.w	#MOUSELIMIT_YMIN,Spr_y	; top
        bpl .noup
        move.w #MOUSELIMIT_YMIN,Spr_y
.noup        
        cmp.w	#MOUSELIMIT_YMAX,Spr_y	; bottom
        bmi .nobottom
        move.w #MOUSELIMIT_YMAX,Spr_y
.nobottom        
        cmp.w	#MOUSELIMIT_XMIN,Spr_x	; left
        bpl .noleft
        move.w #MOUSELIMIT_XMIN,Spr_x
.noleft        
        cmp.w	#MOUSELIMIT_XMAX,Spr_x	; right
        bmi .noright
        move.w #MOUSELIMIT_XMAX,Spr_x
.noright   
        ; Display values
        ;move.w Spr_x,$100
        ;move.w Spr_y,$102
        rts
 
;---------------------------------------------------------------
Spr_x:		Dc.w	$90 ; min X
Spr_y:		Dc.w	$f0 ; min Y
  
oldhorizcnt:
        ds.b    1
oldvertcnt:
        ds.b    1  

gui_flag_mouse_on_next:
        dc.b    0
gui_flag_mouse_on_prev:
        dc.b    0       
gui_flag_mouse_on_play:
        dc.b    0  
gui_flag_mouse_on_mode:
        dc.b    0    

gui_flag_mouse_on_next_save:
        dc.b    0
gui_flag_mouse_on_prev_save:
        dc.b    0       
gui_flag_mouse_on_play_save:
        dc.b    0  
gui_flag_mouse_on_mode_save:
        dc.b    0   

        even
        
; -------------------------
UpdateMouseGuiFlags:
    ; save states
    move.b gui_flag_mouse_on_next,d0
    move.b d0,gui_flag_mouse_on_next_save
    move.b gui_flag_mouse_on_prev,d0
    move.b d0,gui_flag_mouse_on_prev_save
    move.b gui_flag_mouse_on_play,d0
    move.b d0,gui_flag_mouse_on_play_save
    move.b gui_flag_mouse_on_mode,d0
    move.b d0,gui_flag_mouse_on_mode_save
    
    ; Get new states
    lea gui_flag_mouse_on_prev,a0
    lea gui_coords_prev,a1
    bsr TestOnGuiFlag
    
    lea gui_flag_mouse_on_next,a0
    lea gui_coords_next,a1
    bsr TestOnGuiFlag    

    lea gui_flag_mouse_on_play,a0
    lea gui_coords_play,a1
    bsr TestOnGuiFlag 
    
    lea gui_flag_mouse_on_mode,a0
    lea gui_coords_mode,a1
    bsr TestOnGuiFlag     

    rts

; -------------------------
; a0 byte to update (0 1)
; a1 coords
TestOnGuiFlag:
    ; a1 contain X min, X max, Y min, Y max
    move.b #0,(a0)
    
    move.w Spr_y,d0
    
    cmp.w	4(a1),d0	; top
    bpl .noup
    rts
.noup        
    cmp.w	6(a1),d0	; bottom
    bmi .nobottom
    rts
.nobottom  
    move.w Spr_x,d0      
    cmp.w	(a1),d0	; left
    bpl .noleft
    rts
.noleft        
    cmp.w	2(a1),d0	; right
    bmi .noright
    rts
.noright  
    ; all is ok
    move.b #1,(a0)
    rts

; -------------------------
UpdateGuiIcons:
    ; test if "on" states are here
    cmp.b #0,gui_count_next_justclicked
    beq .no_on1
    sub.b #1,gui_count_next_justclicked
    cmp.b #0,gui_count_next_justclicked
    bne .no_on1    
    ; Display off icon
    lea gui_next,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon    
.no_on1:  
    cmp.b #0,gui_count_prev_justclicked
    beq .no_on2
    sub.b #1,gui_count_prev_justclicked
    cmp.b #0,gui_count_prev_justclicked
    bne .no_on2    
    ; Display off icon
    lea gui_prev,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon    
.no_on2:  

    cmp.b #0,gui_count_play_justclicked
    beq .no_on3
    sub.b #1,gui_count_play_justclicked
    cmp.b #0,gui_count_play_justclicked
    bne .no_on3    
    ; Display off icon
    bsr GetPlayPauseIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon    
.no_on3: 

    cmp.b #0,gui_count_mode_justclicked
    beq .no_on4
    sub.b #1,gui_count_mode_justclicked
    cmp.b #0,gui_count_mode_justclicked
    bne .no_on4    
    ; Display off icon
    bsr GetMusicModeIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon    
.no_on4: 

    ; If loading, then do not update anything
    cmp.b #1,flag_module_is_loading
    beq .exit

    ; -- Rollover. Detect if mouse just entered the zone
    cmp.b #1,gui_flag_mouse_on_next
    bne .norollover1
    cmp.b #0,gui_flag_mouse_on_next_save
    bne .norollover1
    ; next rollover start
    lea gui_next,a0
    move.l #2,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norollover1

    cmp.b #1,gui_flag_mouse_on_prev
    bne .norollover2
    cmp.b #0,gui_flag_mouse_on_prev_save
    bne .norollover2
    ; prev rollover start
    lea gui_prev,a0
    move.l #2,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norollover2

    cmp.b #1,gui_flag_mouse_on_play
    bne .norollover3
    cmp.b #0,gui_flag_mouse_on_play_save
    bne .norollover3
    ; play rollover start
    bsr GetPlayPauseIconDataInA0
    move.l #2,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norollover3

    cmp.b #1,gui_flag_mouse_on_mode
    bne .norollover4
    cmp.b #0,gui_flag_mouse_on_mode_save
    bne .norollover4
    ; mode rollover start
    bsr GetMusicModeIconDataInA0
    move.l #2,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norollover4

    ; -- Rollover End. Detect if mouse just quit the zone
    cmp.b #0,gui_flag_mouse_on_next
    bne .norolloverexit1
    cmp.b #1,gui_flag_mouse_on_next_save
    bne .norolloverexit1
    ; next rollover start
    lea gui_next,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norolloverexit1

    cmp.b #0,gui_flag_mouse_on_prev
    bne .norolloverexit2
    cmp.b #1,gui_flag_mouse_on_prev_save
    bne .norolloverexit2
    ; next rollover start
    lea gui_prev,a0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norolloverexit2

    cmp.b #0,gui_flag_mouse_on_play
    bne .norolloverexit3
    cmp.b #1,gui_flag_mouse_on_play_save
    bne .norolloverexit3
    ; play rollover start
    bsr GetPlayPauseIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norolloverexit3

    cmp.b #0,gui_flag_mouse_on_mode
    bne .norolloverexit4
    cmp.b #1,gui_flag_mouse_on_mode_save
    bne .norolloverexit4
    ; mode rollover start
    bsr GetMusicModeIconDataInA0
    move.l #0,d0 ; style 0=off 1=on 2=rollover
    bsr DisplayGuiIcon      
.norolloverexit4
    
.exit:    
    rts

    
; ---------------------------------------------------    
; Scrolling of background
; CPU - Only moving pointers here.
;
; Update all pointers for background scrolling. 
; There are 3 zones. 
;BackgroundPositionBack: ; Background is 320, so position is 0 to 319
;    dc.w    0
;BackgroundPositionFront: ; Front is 640, so position is 0 to 639
;    dc.w    0
    
UpdateBackgroundScroll:

    ; -- Update position
    ; As we are doing this one frame out of two
    ; Background speed is 0.5, front is 1.0

    cmp.b #1,ParalaxFlagSwitch ; only one frame out of 2
    bne .noparalax1
    ; Background plane position
    add.w #1,BackgroundPositionBack ; Add 1 pixel
    cmp.w #320,BackgroundPositionBack
    bmi .nooverflow
    sub.w #320,BackgroundPositionBack
.nooverflow
    ; Front plane position
    add.w #2,BackgroundPositionFront
    cmp.w #640,BackgroundPositionFront
    ble .nooverflow1
    sub.w #640,BackgroundPositionFront
.nooverflow1

    ; TOP - Set planes pointers
    moveq #0,d0
    moveq #0,d1
    move.w BackgroundPositionBack,d0
    ; Add 16 because the blitter operation is decayed of one word (to FIX the border problem)
    add.w #16-1,d0 ; Change to 15 because with 16, there is a 1 pixel decay
    ; test if under 0
    cmp.w #0,d0
    bpl .nounder
    add.w #320,d0
.nounder
    ; test if above 320
    cmp.w #320,d0
    ble .notabove
    sub.w #320,d0
.notabove    
    move.w d0,d1
    lsr.w #4,d0 ; byte adress
    lsl.w #1,d0 ; multiple of 2
    and.w  #$000F,d1
    move.w #$f,d2
    sub.w d1,d2
    move.w d2,d1
    lsl.w #4,d1
    or.w d1,d2
    lea BackgroundScroll_Part1,a2
    move.w d2,2(a2)
    ; -- Set pointers 32 colors
    move.l paralaxChipPtr,a0
    add.l #paralax_backtop_640x19_offset,a0
    ;add.l #4,a0
 	add.l	d0,a0
    move.l  a0,d0 ; final adress of planes
	Lea		BackgroundPlans_Part1,a0 ; copper pointers
    Bsr     Put_pointeurs 
    add.l   #19*80,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #19*80,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #19*80,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #19*80,d0
    add.l   #8,a0
    Bsr     Put_pointeurs

    ; BOTTOM - Set planes pointers
    moveq #0,d0
    moveq #0,d1
    move.w BackgroundPositionFront,d0
    sub.w #2,d0 ; Fix decay [Aug23]
    move.w d0,d1
    lsr.w #4,d0 ; byte adress
    lsl.w #1,d0 ; multiple of 2
    and.w  #$000F,d1
    move.w #$f,d2
    sub.w d1,d2
    move.w d2,d1
    lsl.w #4,d1
    or.w d1,d2
    lea BackgroundScroll_Part3,a2
    move.w d2,2(a2)
    ; -- Set pointers 32 colors
    move.l paralaxChipPtr,a0
    add.l #paralax_frontbottom_960x50_offset,a0
 	add.l	d0,a0
    move.l  a0,d0 ; final adress of planes
	Lea		BackgroundPlans_Part3,a0 ; copper pointers
    Bsr     Put_pointeurs 
    add.l   #50*120,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #50*120,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    add.l   #50*120,d0
    add.l   #8,a0
    Bsr     Put_pointeurs
    
    ; MIDDLE - Set planes pointers
    moveq #0,d1
    move.w BackgroundPositionFront_Prev,d1
    and.w  #$000F,d1
    move.w #$f,d2
    sub.w d1,d2
    move.w d2,d1
    lsl.w #4,d1
    or.w d1,d2    
    lea BackgroundScroll_Part2,a2
    move.w d2,2(a2)

.noparalax1

    rts

    if DISPLAYDEBUGMEMORY==1
;---------------------------------------------------------------
; Convert mem block label to color (to be able to track them)    
fillDebugMem:

sizedebugmemplan=12*40
    ; Convert colors, to pixels. 0 to 9 (one for each type of mem block). 1 Block = 4Kb.
    ; Display LABEL Chip ram.
    
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_GETMEMBLOCKTABLE(a6) ; d0 = chip, d1 = fast   
    move.l d0,a0 ; Get table of chip mem
    lea plansDebugMem+40,a1 ; dest
    ;move.l #(128/8)-1,d6 ; 128 blocks
    move.l #(256/8)-1,d6 ; 512*2 Kb
fillDebugMem_mainloop1:
    move.w #7,d7 ; loop on 8 pixels
    moveq #0,d0 ; d0 to d3 for each plan
    moveq #0,d1
    moveq #0,d2
    moveq #0,d3
fillDebugMem_8pixelsloop1:
    move.b (a0)+,d5 ; get color to convert
; color 2 = grey (for free) then 3 to 10 for each label
;MEMLABEL_SYSTEM		=	$7f ; 10 0008 DARK BLUE
;MEMLABEL_TRACKLOAD		=	$7e ; 9  0808 DARK PURPLE
;MEMLABEL_PRECACHED_FX	=	$7d ; 8  00FF LIGHT BLUE
;MEMLABEL_MUSIC			=	$7c ; 7  0FF0 YELLOW
;MEMLABEL_DEBUG_SCREEN	=	$7b ; 6  0F0F PURPLE
;MEMLABEL_BOOTREAD		=	$7a ; 5  000F BLUE
;MEMLABEL_USER_FX		=	$79 ; 4  00F0 GREEN
;MEMLABEL_PERSISTENT_CHIP=	$78 ; 3  0F00 RED
        
    cmp.b #0,d5
    beq .isfree
    sub.b #$75,d5 ; remap $78 tp $7f to 3 to 10  .... $78-$74 = 
    bra .endcolorremap
.isfree
    move.b #2,d5; grey
.endcolorremap
    ; test plan 1
    btst #0,d5
    beq .nobitplan1
    bset d7,d0
.nobitplan1
    ; test plan 2
    btst #1,d5
    beq .nobitplan2
    bset d7,d1
.nobitplan2
    ; test plan 3
    btst #2,d5
    beq .nobitplan3
    bset d7,d2
.nobitplan3
    ; test plan 4
    btst #3,d5
    beq .nobitplan4
    bset d7,d3
.nobitplan4
    dbra d7,fillDebugMem_8pixelsloop1
    ; one each byt is computed, write to dest
    move.b d0,(a1)
    move.b d1,sizedebugmemplan(a1)
    move.b d2,(sizedebugmemplan*2)(a1)
    move.b d3,(sizedebugmemplan*3)(a1)
    add.l #1,a1
    dbra d6,fillDebugMem_mainloop1
    
    ; Fast mem
	move.l (LDOS_BASE).w,a6
	jsr		LDOS_GETMEMBLOCKTABLE(a6) ; d0 = chip, d1 = fast   
    
    ;lea DebugMemData,a0 ; source data
    move.l d1,a0 ; Get table of chip mem
    lea plansDebugMem+40*3,a1 ; dest
    ;move.l #(128/8)-1,d6 ; 128 blocks of 4 Ko
    move.l #(256/8)-1,d6 ; 192 blocks of 4 Ko
fillDebugMem_mainloop2:
    move.w #7,d7 ; loop on 8 pixels
    clr.b d0 ; d0 to d3 for each plan
    clr.b d1
    clr.b d2
    clr.b d3
fillDebugMem_8pixelsloop2:
    move.b (a0)+,d5 ; get color to convert
; color 2 = grey (for free) then 3 to 10 for each label
;MEMLABEL_SYSTEM		=	$7f ; 10
;MEMLABEL_TRACKLOAD		=	$7e ; 9
;MEMLABEL_PRECACHED_FX	=	$7d ; 8
;MEMLABEL_MUSIC			=	$7c ; 7
;MEMLABEL_DEBUG_SCREEN	=	$7b ; 6
;MEMLABEL_BOOTREAD		=	$7a ; 5
;MEMLABEL_USER_FX		=	$79 ; 4
;MEMLABEL_PERSISTENT_CHIP=	$78 ; 3 
    cmp.b #0,d5
    beq .isfree
    sub.b #$75,d5 ; remap $78 tp $7f to 3 to 10  .... $78-$74 =
    bra .endcolorremap
.isfree
    move.b #2,d5; grey
.endcolorremap
    ; test plan 1
    btst #0,d5
    beq .nobitplan1
    bset d7,d0
.nobitplan1
    ; test plan 2
    btst #1,d5
    beq .nobitplan2
    bset d7,d1
.nobitplan2
    ; test plan 3
    btst #2,d5
    beq .nobitplan3
    bset d7,d2
.nobitplan3
    ; test plan 4
    btst #3,d5
    beq .nobitplan4
    bset d7,d3
.nobitplan4
    dbra d7,fillDebugMem_8pixelsloop2
    ; one each byt is computed, write to dest
    move.b d0,(a1)
    move.b d1,sizedebugmemplan(a1)
    move.b d2,(sizedebugmemplan*2)(a1)
    move.b d3,(sizedebugmemplan*3)(a1)
    add.l #1,a1
    dbra d6,fillDebugMem_mainloop2    
    rts
    endc
;-----------------------------------------------------------------
wait:	dc.w	0 ; Wait frame

TEXTSCROLLSTABLE:
    dc.l TEXTMODULE1
    dc.l TEXTMODULE2
    dc.l TEXTMODULE3
    dc.l TEXTMODULE4
    dc.l TEXTMODULE5
    dc.l TEXTMODULE6
    dc.l TEXTMODULE7
    dc.l TEXTMODULE8
    
TEXTLOADING:
    dc.l TEXTLOADING1
    dc.l TEXTLOADING2
    dc.l TEXTLOADING3
    dc.l TEXTLOADING4
    dc.l TEXTLOADING5
    dc.l TEXTLOADING6
    dc.l TEXTLOADING7
    dc.l TEXTLOADING8 

; Textes: 400 characters for 30 secondes. 800 for 1 minute. (approx)
	
TEXTMAIN:
	dc.b "",1,"RESISTANCE",0,", back on the ",1,"Amiga",0," again, with a new A500 music disk. Released at the ",1,"REVISION",0," demoparty 2024, on the 31 of March 2024.                      Tunes by ",1,"AceMan, Koopa, mAZE, Nainain, Ok3an0s/TEK & Tebirod.",0,"                 Credits: Code by ",1,"Oriens",0," ... Arts by ",1,"Fra, Gr4ss666, Oriens, Rahow, SnC & Vectrex28",0," ... LDOS system by ",1,"Leonard/Oxygene",0,". Debug help by ",1,"StingRay",0,". P61 routine by ",1,"Photon/Scoopex",0,". Testing by ",1,"4Play & Sachy",0,". Hello to others Resistance members: ",1,"Dissident, luNix, Ozzyboshi, Axi0maT, Gligli, Nytrik, Magnetic-Fox.",0,"          Greetings to: ",1,"Desire, Focus Design, The Electronic Knights, Planet Jazz, Software Failure, Ephidrena, Insane, Abyss, Loonies, Wanted Team, Oxyron, Nah-Kolor, Lemon., Ghostown, Deadliners, Oxygene, Scarab.",0,"                 "
    dc.b "If you want to read the full text for each module, you can use the ",1,"LOOP",0," icon on the control interface.        "
    dc.b "Here are some technical details about that music disk. It is running on an Amiga 500 OCS with 1 MB of RAM. It should runs on most Amiga models and can be launched from a hard drive (execute hdd_loader.exe, while having the ADF file in the same directory). The total uncompressed data size of the modules is 1120 KB. If you only have 512 KB of chip RAM, It will need to stop the music and free the scrolling memory to load the second module, HI-SCHOOL GIRLS, which is 375 KB! Each module has a 32-color background. The total data on the disk, is 1600 KB once uncompressed. The music disk runs with a customized version of the LDOS track system by ",1,"LEONARD",0,". Thanks again to him for sharing.      "
    
    dc.b "If you enjoy this music disk, you should consider listening to the first opus, ",1,"Mel'O'Dees",0,", released in 2021. On PC, you can listen to ",1,"Marine Melodies",0," (2022). Also, try ",1,"SNES Music Pack 1",0," (2021). In any case, make sure to turn on your best hi-fi system to fully appreciate these great tunes. "

    dc.b "We are currently working on issue 3 of this series. If you want to ",1,"contribute",0,", either with a tune or design, feel free to ",1,"contact",0," us.         "
    
    ; RJ Mical text here ??
    
    dc.b "                                        ",$FF
  
    even
; --  

TEXTLOADING1: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"LIMITLESS DELIGHTS",0," (43 KB) is loading... "
    dc.b "Please wait while ",1,"LIMITLESS DELIGHTS",0," (43 KB) is loading... " 
    dc.b "Please wait while ",1,"LIMITLESS DELIGHTS",0," (43 KB) is loading... "
    dc.b "Please wait while ",1,"LIMITLESS DELIGHTS",0," (43 KB) is loading... "
    dc.b "Please wait while ",1,"LIMITLESS DELIGHTS",0," (43 KB) is loading... "
    dc.b "                                        ",$FF    
    even

TEXTMODULE1:
    ; As these text are too long, I'll randomly switch the order (Once Maze+Vectrex28, once Vectrex28+Maze)
    dc.b "..... You are listening to ",1,"LIMITLESS DELIGHTS",0," BY ",1,"mA2E",0," (1'50). Art by ",1,"Vectrex28.",0
    dc.b "..... Hey, ",1,"mA2E",0," here. So a short scrolltext for my tune is coming up. Not sure what to write, but I guess I'll figure out something along the way. The tune you are listening right now if you don't have turned the volume all the way to zero, is a old tune I started on over two years ago, but never finished it before now. It's nothing fancy, and were planned for an other project which never happened. I felt it had been a wip long enough now. Anyway, I enjoyed making it. So not much more to say actually. Some quick salutations to my friends in ",1,"Desire, Fatzone, Moods Plateau and Proxima..",0," Also a big greetings and thanks to my wife that let me sit hours after hours composing. And also as mentioned before, thanks to the whole Amiga community and their support and inspiration. Without you, I would have stopped making music many many years ago. ",1,"mA2E",0," out..... "
    ; Scroll text end after "my part on this music disk". 1400 characters left.
    dc.b "Yoooooooo! ",1,"Vectrex28",0," here at the keyboard! First off, sorry it took so long. Having a full-time job is no joke really... But I'm glad I finally managed to finish my part on this music disk. It was first supposed to be a jungle, but it ended up being half a jungle, half a mountain backdrop. But I'm not complaining, as it turned out to be quite neat anyway. I don't really know what else to put in here, maybe just a few greetz to everyone at ",1,"Resistance?",0," I'm a bit tipsy anyway so remembering might not be my strong suit at the time I'm writing this, I've had a few sours and some sake at the local izakaya, and even with higher than average alcohol tolerance it does affect the way you write your scrollies, heh... Some extra greetz go to the folks in the PC Engine scene, which is the console I am making a game on that the moment. In no particular order: ",1,"Aetherbyte, David Shadoff, Turboxray, Yoshiharu Takaoka, asie, Gorimuchuu, Chris Covell, and all I forgot.",0," It's still a small community but some of those peeps are super talented! Also looking forward at perhaps making a PC Engine/Supergrafx intro at least for Resistance. It truly is a piece of hardware I love, and on which, despite being 8-bit, you could do a lot more than you might think, even surpassing the Megadrive on many aspects. But I'm likely getting ahead of myself, despite my love for the 'Engine, it's been an honour to be part of a prod on a machine as iconic as the Amiga (Love both my 500 and my 1200), and looking forward to be part of another music disk if I ever get the chance (and the time especially) to make it happen. Peaceeeeee"
    dc.b ".....          ",$FF
    even
    
TEXTMODULE1ALT:
    ; As these text are too long, I'll randomly switch the order (Once Maze+Vectrex28, once Vectrex28+Maze)
    dc.b "..... You are listening to ",1,"LIMITLESS DELIGHTS",0," BY ",1,"mA2E",0," (1'50). Art by ",1,"Vectrex28. ",0
    dc.b "Yoooooooo! ",1,"Vectrex28",0," here at the keyboard! First off, sorry it took so long. Having a full-time job is no joke really... But I'm glad I finally managed to finish my part on this music disk. It was first supposed to be a jungle, but it ended up being half a jungle, half a mountain backdrop. But I'm not complaining, as it turned out to be quite neat anyway. I don't really know what else to put in here, maybe just a few greetz to everyone at ",1,"Resistance?",0," I'm a bit tipsy anyway so remembering might not be my strong suit at the time I'm writing this, I've had a few sours and some sake at the local izakaya, and even with higher than average alcohol tolerance it does affect the way you write your scrollies, heh... Some extra greetz go to the folks in the PC Engine scene, which is the console I am making a game on that the moment. In no particular order: ",1,"Aetherbyte, David Shadoff, Turboxray, Yoshiharu Takaoka, asie, Gorimuchuu, Chris Covell, and all I forgot.",0," It's still a small community but some of those peeps are super talented! Also looking forward at perhaps making a PC Engine/Supergrafx intro at least for Resistance. It truly is a piece of hardware I love, and on which, despite being 8-bit, you could do a lot more than you might think, even surpassing the Megadrive on many aspects. But I'm likely getting ahead of myself, despite my love for the 'Engine, it's been an honour to be part of a prod on a machine as iconic as the Amiga (Love both my 500 and my 1200), and looking forward to be part of another music disk if I ever get the chance (and the time especially) to make it happen. Peaceeeeee"
    dc.b "..... Hey, ",1,"mA2E",0," here. So a short scrolltext for my tune is coming up. Not sure what to write, but I guess I'll figure out something along the way. The tune you are listening right now if you don't have turned the volume all the way to zero, is a old tune I started on over two years ago, but never finished it before now. It's nothing fancy, and were planned for an other project which never happened. I felt it had been a wip long enough now. Anyway, I enjoyed making it. So not much more to say actually. Some quick salutations to my friends in ",1,"Desire, Fatzone, Moods Plateau and Proxima..",0," Also a big greetings and thanks to my wife that let me sit hours after hours composing. And also as mentioned before, thanks to the whole Amiga community and their support and inspiration. Without you, I would have stopped making music many many years ago. ",1,"mA2E",0," out..... "

    dc.b ".....          ",$FF
    even
    

; --  

TEXTLOADING2: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"HI-SCHOOL GIRLS",0," (374 KB) is loading... "
    dc.b "Please wait while ",1,"HI-SCHOOL GIRLS",0," (374 KB) is loading... " 
    dc.b "Please wait while ",1,"HI-SCHOOL GIRLS",0," (374 KB) is loading... "
    dc.b "Please wait while ",1,"HI-SCHOOL GIRLS",0," (374 KB) is loading... "
    dc.b "Please wait while ",1,"HI-SCHOOL GIRLS",0," (374 KB) is loading... "
    dc.b "                                        ",$FF 
    even
    
TEXTMODULE2: ; Should allow 1900 characters
    
    dc.b "..... You are listening to ",1,"HI-SCHOOL GIRLS",0," by ",1,"ACEMAN",0," (2'23). Art by ",1,"RAHOW/REBELS",0,"..... Well hello there, here is ",1,"AceMan",0," at the keyboard. It is great pleasure to participate again in the second part of this noble music disc! Such fun to see what the graphic designers came up with while listening to my tunes :) So, about the tune. I made this one with the idea of jazz musician playing in the dirty night streets of the city or maybe some sleazy bar. I collected samples from all sorts of sources - I found chords and drums in some random packages, sax solos are chopped and mixed sequences from freesound.org. Everything was kept in lofi style (due to the memory limitations of the A500, but it also fits nice with the general idea). I was terribly missing some dialogue insert, so after a little research I chose Matthew McConaughey's quote from the movie 'Dazed and Confused' :) I hope you enjoy this piece. Cheers!"
    ; 800 characters left. (Rahow want only 1 text, I put on next one.)
    dc.b ".....          ",$FF
    even
    
; --  

TEXTLOADING3: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"IZAR",0," (62 KB) is loading... "
    dc.b "Please wait while ",1,"IZAR",0," (62 KB) is loading... " 
    dc.b "Please wait while ",1,"IZAR",0," (62 KB) is loading... "
    dc.b "Please wait while ",1,"IZAR",0," (62 KB) is loading... "
    dc.b "Please wait while ",1,"IZAR",0," (62 KB) is loading... "
    dc.b "                                        ",$FF 
    even

TEXTMODULE3: ; Should allow 2800 chracters
    dc.b "..... You are listening to ",1,"IZAR",0," by ",1,"NAINNAIN",0," (3'35). Art by ",1,"RAHOW/REBELS",0,"..... Hello dear demoscene friends, I hope my humble contribution will entertain you. I would like to greet all the members of our group, Resistance, as well as all the artists and developers who maintain alive our wonderful platforms from our childhood...."
    ; 2400 left for RAHOW text.
    dc.b "",1,"RAHOW",0," at the kayboard now ... Thanx to ",1,"Oriens",0,", to have came in 2018 to involve me with the ",1,"The Fall",0," demo, you made me realise my dream to be in the winner prod of a big Amiga demo competition." 
    ; 2200 left here.    
    dc.b ".....          ",$FF
    
    even
    
; -- 

TEXTLOADING4: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"STAR-STUDDED SKIES",0," (30 KB) is loading... "
    dc.b "Please wait while ",1,"STAR-STUDDED SKIES",0," (30 KB) is loading... " 
    dc.b "Please wait while ",1,"STAR-STUDDED SKIES",0," (30 KB) is loading... "
    dc.b "Please wait while ",1,"STAR-STUDDED SKIES",0," (30 KB) is loading... "
    dc.b "Please wait while ",1,"STAR-STUDDED SKIES",0," (30 KB) is loading... "
    dc.b "                                        ",$FF 
    even
 
TEXTMODULE4: ; Should allow 1600 characters
    dc.b "..... You are listening to ",1,"STAR-STUDDED SKIES",0," by ",1,"OK3AN0S/TEK",0," (2'01). Art by ",1,"ORIENS",0,"..... This module was composed around the same time than 'adrift in space' which was composed in 2019. This one is a kind of sequel. It seems I like titles related to space and stars :) The whole module is constructed around the groovy bassline otherwise I have not much to say about this one so it's time for some greetings. First of all I'd like to thank ",1,"4play",0," and the whole ",1,"RESISTANCE",0," team for letting me participate to this musicdisk. I also want to greet all my friends around. They know who they are :p      "
    ; 900 characters left.
    dc.b " ",1,"ORIENS",0," back at the keyboard. My next contribution to the Amiga scene will be a game named ",1,"Ninja Carnage",0,". I've developed it for 8-bit computers (Commodore 64 & Amstrad CPC). It has also been ported to the Spectrum by ",1,"Clive Townsend",0,". Currently, I'm working on porting it to the Amiga. It's a point-and-click, die-and-retry graphic adventure game. The display will be in HAM6 mode. I hope to release it soon. Stay tuned.               "
    ; 500 characters left.
    dc.b ".....          ",$FF
    
    even

; -- 

TEXTLOADING5:
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"LE VOYAGE FANTASTIQUE",0," (234 KB) is loading... "
    dc.b "Please wait while ",1,"LE VOYAGE FANTASTIQUE",0," (234 KB) is loading... " 
    dc.b "Please wait while ",1,"LE VOYAGE FANTASTIQUE",0," (234 KB) is loading... "
    dc.b "Please wait while ",1,"LE VOYAGE FANTASTIQUE",0," (234 KB) is loading... "
    dc.b "Please wait while ",1,"LE VOYAGE FANTASTIQUE",0," (234 KB) is loading... "
    dc.b "                                        ",$FF 
    even
 
TEXTMODULE5: ; 4000 characters available.
    dc.b "..... You are listening to ",1,"LE VOYAGE FANTASTIQUE",0," by ",1,"ACEMAN",0," (5'03). Art by ",1,"ORIENS",0,"..... Hi, here's ",1,"AceMan",0," again. So with this second piece it's like this: I wanted to go back a bit to the old Amiga days when people composed MODs using small samples ripped from synthesizers or ",1,"ST-XX",0," disks. The mood of the track was supposed to be electronic, melodic, Jarre-esque, sounding also like a game soundtrack. And I think it came out pretty well :) Enjoy!          "
    ; 3500 characters left.
	dc.b "Hi there, ",1,"StingRay",0," at the keys. It has been a lot of fun helping "
	dc.b "with this music disk. Oriens contacted me some days ago and "
	dc.b "asked if I could help with some compatibility problems with "
	dc.b "the music disk. I happily offered my help for several reasons: "
	dc.b "I once was member of ",1,"RSE",0," and helping old friends is always a "
	dc.b "pleasure. The other reason is that this way I could participate "
	dc.b "in a Revision release without having one of my own. Real life "
	dc.b "is really taking its toll these days, leaving almost no time "
	dc.b "for Amiga stuff. When you have to manage a team of of several "
	dc.b "SAP developers, you really do not feel like spending more time "
	dc.b "coding outside of work. I am not complaining though, it's "
	dc.b "interesting and challenging, it just doesn't leave much time "
	dc.b "for scene stuff. Which is why I am glad that I could help with "
	dc.b "this music disk release a bit. I am looking forward to working "
	dc.b "together with Oriens again as it has been a very pleasant "
	dc.b "experience. Greetings to all my old friends in RSE, everyone in "
	dc.b 1,"Scarab",0,", everyone in ",1,"Scoopex",0," and everyone in ",1,"Fanatic2k",0," (special "
	dc.b "greetings to ",1,"Nlk",0,", I am enjoying our conversations a lot!). "
	dc.b "Everyone at Revision: ",1,"have a lot of fun",0,", due to other "
	dc.b "commitments I will not be in Saarbruecken this year. I will "
	dc.b "hopefully be back at Revision next year! Take care everyone and "
	dc.b "have a lot of fun. Before leaving the keyboard, I want to "
	dc.b "send some personal greetings to ",0,"Sensenstahl, 4play, Alpha One, "
	dc.b "Galahad, Musashi5150, Britelite, Frequent, Slummy, Loaderror, "
	dc.b "Photon, Sniper, Oriens, Leonard, Motion, Virgill",0," and everyone "
	dc.b "I may have forgotten. If intentionally or not is for you to decide :) "
	; 1900 characters left.
    dc.b ".....          ",$FF

    even    

; -- 

    
TEXTLOADING6:
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"BALLADE",0," (67 KB) is loading... "
    dc.b "Please wait while ",1,"BALLADE",0," (67 KB) is loading... " 
    dc.b "Please wait while ",1,"BALLADE",0," (67 KB) is loading... "
    dc.b "Please wait while ",1,"BALLADE",0," (67 KB) is loading... "
    dc.b "Please wait while ",1,"BALLADE",0," (67 KB) is loading... "
    dc.b "                                        ",$FF 
    even
 
TEXTMODULE6: ; 2000 characters
    dc.b "..... You are listening to ",1,"BALLADE",0," by ",1,"KOOPA",0," (2'42). Art by ",1,"FRA & ORIENS",0,"..... "
    dc.b 1,"KOOPA",0," on the keyboard. Last night, I fought this dragon. it was not an easy task. Unfortunately there were some losses amongst the team. Now a new day can begin and, I hope, an encounter with a peaceful life. Your humble servant..... "
    dc.b 1,"ORIENS",0," back on keyboard, now this is time for some personal greetings:  ",1,"Locust2802, Rodrik, Bird/Syntex, Deckard, Wookie, Parsec, friends of Deadliners Soundy, Made, Dascon, Dan & Facet from Lemon., Leonard & Mon from Oxygene, Ziggy Stardust.",0," "
    dc.b "And of course my wife ",1,"Ana",0,", for understanding my passion for the Amiga. Love you."
    ; 1300 characters left.
    dc.b ".....          ",$FF
    
    even

; --

TEXTLOADING7: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"THROUGH THE GATE",0," (34 KB) is loading... "
    dc.b "Please wait while ",1,"THROUGH THE GATE",0," (34 KB) is loading... " 
    dc.b "Please wait while ",1,"THROUGH THE GATE",0," (34 KB) is loading... "
    dc.b "Please wait while ",1,"THROUGH THE GATE",0," (34 KB) is loading... "
    dc.b "Please wait while ",1,"THROUGH THE GATE",0," (34 KB) is loading... "
    dc.b "                                        ",$FF 
    even
  
TEXTMODULE7: ; 2000 characters
    dc.b "..... You are listening to ",1,"THROUGH THE GATE",0," by ",1,"OK3AN0S/TEK",0," (2'33). Art by ",1,"SnC",0,"..... ",1,"OK3AN0S",0," on the keyboard. I set myself a reminder for all the time that I err. So that I may always remember that I am but a prisoner. This module is one of the rare ones I have composed with a sad melody. I usually make happy and cheesy melodies when composing chiptunes. For this one, I wanted to make something which sounded like the old cracktros or some kind of RPG like games I played on 8bit consoles. I'm pretty satisfied with the result as it sounds exactly how I wanted it to be.   "
    
    dc.b "",1,"SnC",0," on keyboard. Heyo friends - and welcome to another fine musicdisk by your favourite misfits! We hope you enjoy the nice tunes by our super talented house musicians - on the beloved ",1,"AMIGA",0,"! :: I just want to thank the rest of the team for all the amazing work put into this disk, a round of applause to all of you for making it possible, and for keeping the Amiga alive! Enjoy the show - ",1,"Enjoy Amiga",0,"" 
    ; 900 characters left    
    dc.b ".....          ",$FF
    
    even

; --  

TEXTLOADING8: 
    dc.b " ... Loading ... "
    dc.b "Please wait while ",1,"FLY'N FALL",0," (165 KB) is loading... "
    dc.b "Please wait while ",1,"FLY'N FALL",0," (165 KB) is loading... " 
    dc.b "Please wait while ",1,"FLY'N FALL",0," (165 KB) is loading... "
    dc.b "Please wait while ",1,"FLY'N FALL",0," (165 KB) is loading... "
    dc.b "Please wait while ",1,"FLY'N FALL",0," (165 KB) is loading... "
    dc.b "                                        ",$FF 
    even


TEXTMODULE8: ; 3600 characters available
    dc.b "..... You are listening to ",1,"FLY'N FALL",0," by ",1,"TEBIROD",0," (4'33). Art by ",1,"ORIENS & WILL",0,"..... Hi all, this is ",1,"ORIENS",0," at the keyboard. It has been a pleasure to code and create some graphics for this music disk. There are so many talented people involved. Thanks once again to ",1,"LEONARD",0," for sharing his ",1,"LDOS",0," system. This music disk is dedicated to my friend ",1,"TEBIROD",0," who passed away in June 2023. I had the privilege of working with him for 30 years, he was a truly remarkable person. The tune used in the intro is also his, and it has a special story. This module was initially created for the intro of our ",1,"HAWK mega demo EARTH SORROWS",0," in 1991. It was the first version for the intro. After reviewing all the artistic effects, I asked ",1,"TEBIROD",0," if he could improve the module, and he crafted a (perfect) second version for the mega demo. This first module had been left unused until today. I'm glad to finally be able to use it. The ",1,"FLY'N FALL",0," module is also an unused piece from ",1,"TEBIROD",0,". I truly adore this song, it's a perfect choice to conclude this music disk. ",1,"ORIENS",0," signing off."
    ; 2500 characters left.
    dc.b ".....          ",$FF
    
    even


; ------------------------------------------------------

Scroll1NextLetter:
	dc.w	1
Scroll1Pointer:
	dc.l	TEXTMAIN
ScrollMainTextSave:
    dc.l    0 ; When switching to specific text, save main text pointer
ScrollTextChangeRequest:
    dc.l    0 ; Ask for text change, will be managed in IRQ, at one place.
Scroll1Letter:
	dc.b	' ',$FF
ScrollIsSpecificText:
    dc.b    0 ; 1 if a specific text is playing
	
	even

; ------------------------------------------------------
	
fontplanebase:
	dc.l	planescrolling1 ; do not use
	
fontplanebaseScroll:
	dc.l	planescrolling1+2	
	
;---------------------------------------------------------------
; Display letters on scrolling buffer    
DoScrollText:
	move.l Scroll1Pointer,a0
	cmp.b #$FF,(a0)
	beq .endscroll1

	jsr	waitblitter
	
	MOVE.W	#2,$DFF064	; MOD A Source
	MOVE.W	#2,$DFF066	; MOD D Dest
	MOVE.L	#$FFFFFFFF,$DFF044 ; First word mask and last word
	MOVE.L	#planescrolling1+2,$DFF050  ; SOURCE A
	MOVE.L	#planescrolling1,$DFF054	; SOURCE D
	Move.w	#0,$dff042			; Decay source B + flag line trace
	Move.w	#0,d2 ; Decay value
SCROLLTEXTSPEED = 2    
	Move.w	#((16-SCROLLTEXTSPEED)<<12),d2 ; Decay value
	OR.W	#%0000100111110000,D2 ; X9f0 , X is speed 16-Speed
	;             1234         
	MOVE.W	d2,$DFF040 ; 4 Shift Source A + 4 Dma Activation + 8 mintern
	;move.w #((16*3)<<6)+22,$dff058 ; BltSize, height*64 , width launch transfert
    move.w #((16*4)<<6)+22,$dff058 ; BltSize, height*64 , width launch transfert

	; Copy new letter ?
	sub.w #SCROLLTEXTSPEED,Scroll1NextLetter ; Same as Speed in decay above
	cmp.w #0,Scroll1NextLetter
	bgt .nonew
    
.GetNextLetter: ; -- Get next letter ------------------------
	move.l Scroll1Pointer,a0
	move.b (a0),Scroll1Letter
	add.l #1,Scroll1Pointer
    ; -- Test color flags
    cmp.b #0,(a0)
    bne .noflagcolornormal
    move.w #0,DisplayColors ; Set font white, the normal one 8 first colors
    bra .GetNextLetter
.noflagcolornormal:     
    cmp.b #1,(a0)
    bne .noflagcoloralternate
    move.w #1,DisplayColors ; Ask for alternate font, 8 next colors
    bra .GetNextLetter
.noflagcoloralternate: 

    
	; -- Display letter to end of scroll1 plan ----------------------------------
	move.l #320,d0 ; X (width). round value (for CPU Display)
SCROLLBASEHEIGHT=13 ; g and y are a bit cut   
	move.l #SCROLLBASEHEIGHT,d1 ; Y (height, bottom of character, base line)
    moveq #0,d2	
	move.b Scroll1Letter,d2
    
    ;move.b d2,$100
	bsr DisplayLetterScroll     ; TODO: We can optimise here, the transfer can be done on next frame (before scroll)

	move.w XAdvanceScroll,d0 ; Get back size of letter.
    add.w #1,d0 ; CK: Add 1 space between characters
    ;add.w #32,d0
    ; Space ?
    cmp.b #' ',d2
    bne .nospace
    add.w #3,d0 ; add more value to space character
.nospace  
    ; Apostrophe ?
    cmp.b #"'",d2
    bne .noapostrophe
    add.w #3,d0 ; add more value to apostrophe character
.noapostrophe 

	add.w d0,Scroll1NextLetter ; Number of pixels to wait before displaying next letter

    ; End of scrolling ?
	move.l Scroll1Pointer,a0
	add.l #1,a0
	cmp.b #$FF,(a0)
	bne .noendscroll
	
    ; -- End of scrolling.
    ; Test if specific text was playing or if this is main scroll.
    cmp.b #1,ScrollIsSpecificText
    beq .specifictext
    ; Main text is looping
    move.l #TEXTMAIN,Scroll1Pointer
    bra .noendscroll
.specifictext ; -- Specific text was playing, so go back to main text
    move.b #0,ScrollIsSpecificText
    move.l ScrollMainTextSave,a0
    ; We search for last dot, to have a complete sentence. (or Start of scrolltext)
.finddotorStart:
    cmp.b #'.',-1(a0)
    beq .found
    cmp.l #TEXTMAIN,a0
    beq .found
    subq #1,a0 ; back one character
    bra .finddotorStart
.found
    move.l a0,Scroll1Pointer
    move.w #0,DisplayColors
    
.noendscroll
.endscroll1:	
.nonew:
    
    ; Scroll change was requested.
    cmp.l #0,ScrollTextChangeRequest
    beq .notextchange
    move.l ScrollTextChangeRequest,a0
    move.l #0,ScrollTextChangeRequest ; clear request
    move.l a0,Scroll1Pointer     ; Set current text
    move.w #0,DisplayColors ; reset color
.notextchange:

	rts

;----------------------------------------------------------------
; Side by side pointers
Put_pointeurs:
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
	swap	d0
	rts
;---------------------------------------------------------------
; font display
	include "VideoDecode_FontDisplay001.s"

;---------------------------------------------------------------	
waitblitter:	
	btst	#14,$dff002 ; Wait blitter to be ready
	Bne	waitblitter
	Rts

;---------------------------------------------------------------
; Fade palette, from source byte_r byte_g byte_b (0 to 255 format)
; to dest 3 bytes, and convert to 16 byte color 0XXX
; Time for doing the transition can be constant (no need to handle any duration)
; Example
; From 0,17,255 to 45,78,45, in 16 steps (or more)
; We need a table to handle the current value (word for each component), and the fixed step (for each component)
; and a table get the final result (one word).
;color_start:
;    dc.b 16,17,255 ; $01f
;color_end:
;    dc.b 64,78,45 ; $452

; Temporary buffers
gradient_current:
    ds.w    32*3
; Steps can be positive and negative. We want 256 steps.
; 0 to 255 (max) Step is 00FF
; 0 to 128       Step is 0080
; 128 to 0       Step is FF80
; 255 to 0       Step is FF01
gradient_steps:
    ds.w    32*3
gradient_result:
    ds.w    32

gradient_current_copper: ; 64 line for main screen, and 80 for intro
    ds.w    80*3    
gradient_steps_copper:
    ds.w    80*3
gradient_result_copper:
    ds.w    80    
    
gradient_nbsteps: ; 0 to 255
    dc.b    0
    even
;---------------------------------------------------------------
; We use word with 8 bits round and 8 bits fractions
; Step: (dest<<8-source<<8)>>8 , it is simple  dest-source (signed)
ComputeSteps:
    ; d4 is number of colors component (color * 3). up to 64 (for background)
    ; a0 color start
    ; a1 color end
    lea gradient_current,a2
    lea gradient_steps,a3
    sub.w #1,d4
.loop:    
    clr.l d0
    clr.l d1
    move.b (a1)+,d1 ; dest color
    move.b (a0)+,d0 ; source color
    sub.w d0,d1 ; compute steps (signed)
    move.w d1,(a3)+ ; store steps (fraction of 255)
    lsl #8,d0
    move.w d0,(a2)+
    dbra d4,.loop  
 
    move.b #0,gradient_nbsteps
    
    ;move.w (a3),$100
    ;move.w (a2),$102
    
    rts   
;---------------------------------------------------------------
ComputeStepsBackGradient
    ; d4 is number of colors (component, color * 3). up to 64 (for background)
    ; a0 color start
    ; a1 color end
    lea gradient_current_copper,a2
    lea gradient_steps_copper,a3
    sub.w #1,d4
.loop:    
    clr.l d0
    clr.l d1
    move.b (a1)+,d1
    move.b (a0)+,d0
    sub.w d0,d1
    move.w d1,(a3)+
    lsl #8,d0
    move.w d0,(a2)+
    dbra d4,.loop  
    rts    
;---------------------------------------------------------------
; 32 Colors palette
; d4.w number of colors components (1 color = 3 components)   
UpdateSteps:
    cmp.b #255,gradient_nbsteps
    beq UpdateSteps_end

    add.b #1,gradient_nbsteps ;move.b gradient_nbsteps,$106 ; DEBUG 

    lea gradient_current,a2
    lea gradient_steps,a3
    lea gradient_result,a4 ; color RGB
    sub.w #1,d4
.loop:    
    moveq #0,d0
    moveq #0,d1 ; result color
    ; Red component
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.l #$0800,d0 ; BUG HERE, we might already by at maximum
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    lsl.w #8,d0 ; shift
    move.w d0,d1 ; Store RED
    ; Green component
    ;clr.l d0
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.l #$0800,d0
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    lsl.w #4,d0 ; shift
    or.w d0,d1 ; Store Green
    ; Blue component
    ;clr.l d0
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.l #$0800,d0
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    or.w d0,d1 ; Store RED  
    ; -- store result
    move.w d1,(a4)+ ; RGB color
    dbra d4,.loop
    
    ; Copy all colors to copper
    
    ; -- Init Background. 32 colors
    lea gradient_result,a0
    lea BackgroundPalette,a1 ; dest
    add.l #2,a1
    move.w #32-1,d0
.loopcopycolorsb
    move.w (a0)+,(a1)
    add.l #4,a1
    dbra d0,.loopcopycolorsb    
    
UpdateSteps_end:
    rts
   
; ---------------------------------------------  
; 64 colors gradient  
; d4 number of colors (1 color = 3 components)   
UpdateStepsCopper:
    cmp.b #255,gradient_nbsteps
    beq UpdateStepsCopper_end

    lea gradient_current_copper,a2
    lea gradient_steps_copper,a3
    lea gradient_result_copper,a4 ; color RGB
    sub.w #1,d4
.loop:    
    moveq #0,d0
    moveq #0,d1 ; result color
    ; Red component
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.w #$0800,d0
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    lsl.w #8,d0 ; shift
    move.w d0,d1 ; Store RED
     ; Green component
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.w #$0800,d0
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    lsl.w #4,d0 ; shift
    or.w d0,d1 ; Store Green
    ; Blue component
    move.w (a3)+,d0
    add.w d0,(a2)
    move.w (a2)+,d0
    ;add.w #$0800,d0
    lsr.w #8,d0 ; only keep higher 4 bits
    lsr.w #4,d0 ; only keep higher 4 bits
    or.w d0,d1 ; Store RED  
    ; -- store result
    move.w d1,(a4)+ ; RGB color
    dbra d4,.loop
    ;move.w d1,$102
    ; Copy all colors to copper
    ; -- Init Copper Background. 64 colors
    lea gradient_result_copper,a0
    lea CopperGradient1,a1 ; dest
    add.l #6,a1
    move.w #18-1,d0 ; 18 lines
.loopcopycolorsb
    move.w (a0)+,(a1)
    add.l #16,a1
    dbra d0,.loopcopycolorsb 
    ; Part 2
    lea CopperGradient2,a1 ; dest
    add.l #6,a1
    move.w #43-1,d0 ; 43 lines
.loopcopycolorsb2
    move.w (a0)+,(a1)
    add.l #16,a1
    dbra d0,.loopcopycolorsb2
    ; Part 3 (3 lines)
;    lea CopperGradient3,a1 ; dest
;    add.l #6,a1
;    move.w #3-1,d0 ; 3 lines
;.loopcopycolorsb3
;    move.w (a0)+,(a1)
;    add.l #16,a1
;    dbra d0,.loopcopycolorsb3
    
    ; -- Bottom gradient is 4 colors.
    ; Report same as last colors of main gradient
    lea gradient_result_copper+60*2,a0
    lea Bottom1+6,a1
    move.w (a0),(a1)
    lea gradient_result_copper+61*2,a0
    lea Bottom2+6,a1
    move.w (a0),(a1) 
    lea Bottom34+6,a1
    lea gradient_result_copper+62*2,a0
    move.w (a0),(a1) 
    add.l #16,a1
    lea gradient_result_copper+63*2,a0
    move.w (a0),(a1) 
    
    ; If loading big module then fill all the gap
    ; Not good visual result
    ;lea CopperGradient2_LastLines+6,a0
    ;move.w (a0),d0
    ;move.w d0,8(a0)
    ;move.w d0,16(a0)
    ;move.w d0,(16+8)(a0)
    ;move.w d0,32(a0)
    ;move.w d0,(32+8)(a0) 
    ;move.w d0,48(a0)
    ;move.w d0,(48+8)(a0)     
   

UpdateStepsCopper_end:
    rts    

	data_c
        
;---------------------------------------------------------------
; Main copper list
COPP1:	
		dc.l	$01000200 ; 0 planes
        dc.l    $01020000 ; horizontal scroll 0-16 (BPLCON1) 
        dc.l    $010a0000,$01080000 ; Modulo 0
        ;dc.l    $010aFFFE,$0108FFFE ; Modulo -2 (logo 40, screen 42)
		dc.l	$01fc0000,$010c0011
        
SprCentral: ; 8 sprites		 
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
        
        ; -- LOGO
        
LogoPalette:
 		dc.w    $0180,$0000,$0182,$0000 ; 32 colors
		dc.w    $0184,$0000,$0186,$0000
		dc.w    $0188,$0000,$018A,$0000
		dc.w    $018C,$0000,$018E,$0000
		dc.w    $0190,$0000,$0192,$0000
		dc.w    $0194,$0000,$0196,$0000
		dc.w    $0198,$0000,$019A,$0000
		dc.w    $019C,$0000,$019E,$0000
		dc.w    $01A0,$0000,$01A2,$0000
		dc.w    $01A4,$0000,$01A6,$0000
		dc.w    $01A8,$0000,$01AA,$0000
		dc.w    $01AC,$0000,$01AE,$0000
		dc.w    $01B0,$0000,$01B2,$0000
		dc.w    $01B4,$0000,$01B6,$0000
		dc.w    $01B8,$0000,$01BA,$0000
		dc.w    $01BC,$0000,$01BE,$0000          
        
		dc.b $2c,$df,$ff,$fe ; First line 
LogoPlans:
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
		Dc.l	$00ec0000,$00ee0000
		Dc.l	$00f00000,$00f20000        
		Dc.l    $01005200 ;  5 planes
		
		; -- Background zone
        
		dc.b $2c+64,$df,$ff,$fe ; logo end. Background start.
        Dc.l    $01000200 ;  0 planes
        
BackgroundPlans_Part1:		
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
		Dc.l	$00ec0000,$00ee0000
		Dc.l	$00f00000,$00f20000 
BackgroundModuloControl:        
        dc.l    $01080028,$010a0028 ; Modulo 40 (width 80) 
BackgroundPlanControl:        
        dc.l    $01005200 ;  5 planes        
BackgroundScroll_Part1:
        dc.l    $01020000 ; scroll $00XX, X 0 to F
        dc.l    $008e2c91 ; DFFSTR. Cut 16 pixels on left
        dc.l    $00902cb1 ; Cut 16 pixels on the right
        
BackgroundPalette:
 		dc.w    $0182,$0000,$0182,$0000 ; 32 colors (ignoring first one)
		dc.w    $0184,$0000,$0186,$0000
		dc.w    $0188,$0000,$018A,$0000
		dc.w    $018C,$0000,$018E,$0000
		dc.w    $0190,$0000,$0192,$0000
		dc.w    $0194,$0000,$0196,$0000
		dc.w    $0198,$0000,$019A,$0000
		dc.w    $019C,$0000,$019E,$0000
		dc.w    $01A0,$0000,$01A2,$0000
		dc.w    $01A4,$0000,$01A6,$0000
		dc.w    $01A8,$0000,$01AA,$0000
		dc.w    $01AC,$0000,$01AE,$0000
		dc.w    $01B0,$0000,$01B2,$0000
		dc.w    $01B4,$0000,$01B6,$0000
		dc.w    $01B8,$0000,$01BA,$0000
		dc.w    $01BC,$0000,$01BE,$0000 
    
        ; Gradient 64 lines
CopperGradient1:
        ;dc.b $2c+66,$45,$ff,$fe,   $01,$80,$00,$00, $2c+66,$df,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+66,$45,$ff,$fe,   $01,$80,$00,$00, $2c+66,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+67,$45,$ff,$fe,   $01,$80,$00,$00, $2c+67,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+68,$45,$ff,$fe,   $01,$80,$00,$00, $2c+68,$d5,$ff,$fe,   $01,$80,$00,$00 
		dc.b $2c+69,$45,$ff,$fe,   $01,$80,$00,$00, $2c+69,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+70,$45,$ff,$fe,   $01,$80,$00,$00, $2c+70,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+71,$45,$ff,$fe,   $01,$80,$00,$00, $2c+71,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+72,$45,$ff,$fe,   $01,$80,$00,$00, $2c+72,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+73,$45,$ff,$fe,   $01,$80,$00,$00, $2c+73,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+74,$45,$ff,$fe,   $01,$80,$00,$00, $2c+74,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+75,$45,$ff,$fe,   $01,$80,$00,$00, $2c+75,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+76,$45,$ff,$fe,   $01,$80,$00,$00, $2c+76,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+77,$45,$ff,$fe,   $01,$80,$00,$00, $2c+77,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+78,$45,$ff,$fe,   $01,$80,$00,$00, $2c+78,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+79,$45,$ff,$fe,   $01,$80,$00,$00, $2c+79,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+80,$45,$ff,$fe,   $01,$80,$00,$00, $2c+80,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+81,$45,$ff,$fe,   $01,$80,$00,$00, $2c+81,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+82,$45,$ff,$fe,   $01,$80,$00,$00, $2c+82,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+83,$45,$ff,$fe,   $01,$80,$00,$00, $2c+83,$d5,$ff,$fe,   $01,$80,$00,$00
        
BackgroundModuloControl2: 
        dc.l    $01080002,$010a0002 ; 40 on screen ... All planes after the others 
BackgroundScroll_Part2: ; Middle part, 43 pixels high, back and front with parallax
        dc.l    $01020000 ; scroll $00XX, X 0 to F  
BackgroundPlans_Part2:		
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
		Dc.l	$00ec0000,$00ee0000
		Dc.l	$00f00000,$00f20000 

CopperGradient2:        
        dc.b $2c+84,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+84,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+85,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+85,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+86,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+86,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+87,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+87,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+88,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+88,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+89,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+89,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+90,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+90,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+91,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+91,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+92,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+92,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+93,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+93,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+94,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+94,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+95,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+95,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+96,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+96,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+97,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+97,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+98,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+98,$d5,$ff,$fe,   $01,$80,$00,$00
		dc.b $2c+99,$45,$ff,$fe,   $01,$80,$00,$00 , $2c+99,$d5,$ff,$fe,   $01,$80,$00,$00
        dc.b $2c+100,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+100,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+101,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+101,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+102,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+102,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+103,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+103,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+104,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+104,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+105,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+105,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+106,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+106,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+107,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+107,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+108,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+108,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+109,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+109,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+110,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+110,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+111,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+111,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+112,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+112,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+113,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+113,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+114,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+114,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+115,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+115,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+116,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+116,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+117,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+117,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+118,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+118,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+119,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+119,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+120,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+120,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+121,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+121,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+122,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+122,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+123,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+123,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+124,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+124,$d5,$ff,$fe,  $01,$80,$00,$00
		dc.b $2c+125,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+125,$d5,$ff,$fe,  $01,$80,$00,$00
        dc.b $2c+126,$45,$ff,$fe,  $01,$80,$00,$00 , $2c+126,$d5,$ff,$fe,  $01,$80,$00,$00

BackgroundPlans_Part3:		
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
		Dc.l	$00ec0000,$00ee0000
BackgroundModuloControl3:         
        dc.l    $01080050,$010a0050 ; Modulo 80 (width 120)   
BackgroundScroll_Part3:
        dc.l    $01020000
BackgroundPlanControl3:          
        dc.l    $01004200 ; scroll $00XX, X 0 to F.   4 planes. 
;CopperGradient3: 
;		dc.b $2c+127,$47,$ff,$fe,   $01,$80,$00,$00 , $2c+127,$d5,$ff,$fe,   $01,$80,$00,$00
;        dc.b $2c+128,$47,$ff,$fe,   $01,$80,$00,$00 , $2c+128,$d5,$ff,$fe,   $01,$80,$00,$00
;		dc.b $2c+129,$47,$ff,$fe,   $01,$80,$00,$00 , $2c+129,$d5,$ff,$fe,   $01,$80,$00,$00
        
        ; -- Scrolling of Text (16 pixels)
        ; Last art color is $0AD7
        
        dc.b    $2c+64+112,$df,$ff,$fe
        dc.l    $01000200 ; 0 plane
Bottom1: ; Bottom Gradient Line 1
        dc.b    $2c+64+113,$47,$ff,$fe , $01,$80, $00,$00
ScrollPalette:
 		dc.w    $0182,$0222 ; 8 colors. Grey gradient
		dc.w    $0184,$0444,$0186,$0666
		dc.w    $0188,$0888,$018A,$0aaa
		dc.w    $018C,$0ccc,$018E,$0FFF 
 		dc.w    $0190,$0000,$0192,$0221 ; 8 others colors. Green
		dc.w    $0194,$0442,$0196,$0463
		dc.w    $0198,$0583,$019a,$0694
		dc.w    $019c,$07b5,$019e,$08d5 
        ;dc.l    $010a0062,$01080062 ; Modulo 6 + 46 + 46 
        dc.l    $010a0090,$01080090 ; Modulo 6 + 46 + 46 + 46
        dc.l    $01020000; no scrolling 
        dc.b    $2c+64+113,$d7,$ff,$fe , $01,$80, $00,$00 ; background end, Color 00

Bottom2:  ; Bottom Gradient Line 2   
        dc.b $2c+64+114,$47,$ff,$fe, $01,$80,  $00,$00 

        ; Palette sprite 16 color (gui top made with 16 colo sprite)
        dc.w $01a2,$0211
        dc.w $01a4,$0333
        dc.w $01a6,$0555 
        dc.w $01a8,$0666 
        dc.w $01aa,$0777
        dc.w $01ac,$0777
        dc.w $01ae,$0888
        dc.w $01b0,$0999        
        dc.w $01b2,$0aaa
        dc.w $01b4,$0aaa
        dc.w $01b6,$0bbb 
        dc.w $01b8,$0bbb 
        dc.w $01ba,$0ccc
        dc.w $01bc,$0ddd
        dc.w $01be,$0eee 
        dc.b $2c+64+114,$d7,$ff,$fe, $01,$80,  $00,$00; background end, Color 00
Bottom34: ; Bottom Gradient Line 3 & 4       
		dc.b $2c+64+115,$47,$ff,$fe, $01,$80,  $00,$00 , $2c+64+115,$d7,$ff,$fe, $01,$80,  $00,$00; background end, Color 00
        dc.b $2c+64+116,$47,$ff,$fe, $01,$80,  $00,$00 
        ; Scrolling
ScrollPlans:		
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
        Dc.l	$00ec0000,$00ee0000
        dc.l    $008e2c89 ; DFFSTR. No 16 pixels cut on left
        dc.l    $009038d9        
        dc.b    $2c+64+116,$d7,$ff,$fe, $01,$80,  $00,$00; background end, Color 00        

        ;dc.l    $01003200 ; 3 plane  
        dc.l    $01004200 ; 4 plane  
		
; Bottom5 (black)        
        dc.b    $2c+64+117,$47,$ff,$fe, $01,$80,  $00,$00 
               
        ; --------------------------------------------
        ; GUI(and sprite)
        
        dc.b $2c+64+116+16,$df,$ff,$fe, $01,$80,  $00,$00
        
GuiPlans:		
		Dc.l	$00e00000,$00e20000
		Dc.l	$00e40000,$00e60000
		Dc.l	$00e80000,$00ea0000
		Dc.l	$00ec0000,$00ee0000
		Dc.l	$00f00000,$00f20000 
 		Dc.l    $01005200    ; 5 plans 
        dc.l    $010a0000,$01080000 ; Modulo 0 
        ;dc.l    $010aFFFE  ,$0108FFFE   ; Modulo -2 (screen 42, pic 40)
      
GuiPalette:
 		dc.w    $0182,$0000,$0182,$0000 ; 32 colors (ignoring first one)
		dc.w    $0184,$0888,$0186,$0000
		dc.w    $0188,$00F0,$018A,$0000
		dc.w    $018C,$0F0F,$018E,$0000
		dc.w    $0190,$00FF,$0192,$0000
		dc.w    $0194,$0008,$0196,$0000
		dc.w    $0198,$088F,$019A,$0000
		dc.w    $019C,$08F8,$019E,$0000
		dc.w    $01A0,$0000,$01A2,$0000 ; 4 colors shared with sprite
		dc.w    $01A4,$0888,$01A6,$0000
		dc.w    $01A8,$00F0,$01AA,$0000
		dc.w    $01AC,$0F0F,$01AE,$0000
		dc.w    $01B0,$00FF,$01B2,$0000
		dc.w    $01B4,$0008,$01B6,$0000
		dc.w    $01B8,$088F,$01BA,$0000
		dc.w    $01BC,$08F8,$01BE,$0000  

		dc.w 	$ffdf,$fffe ; Line 255
        
        dc.w 	$22df,$fffe
        
        if DISPLAYDEBUGMEMORY==1
		;  -- Debug zone (to display mem. 12 lines)
		dc.w    $0180,$0000,$0182,$0FFF ; Color 1 is white
		dc.w    $0184,$0888,$0186,$0F00 ; Color 2 is grey, 3 is red
		dc.w    $0188,$00F0,$018A,$000F
		dc.w    $018C,$0F0F,$018E,$0FF0
		dc.w    $0190,$00FF,$0192,$0808
		dc.w    $0194,$0008,$0196,$0FF8
		dc.w    $0198,$088F,$019A,$0F88
		dc.w    $019C,$08F8,$019E,$0F84
        dc.w 	$23df,$fffe
P1DBG:	Dc.l	$00e00000,$00e20000
P2DBG:	Dc.l	$00e40000,$00e60000
P3DBG:	Dc.l	$00e80000,$00ea0000
P4DBG:	Dc.l	$00ec0000,$00ee0000
		Dc.l    $01004200
		dc.l 	$30dffffe,$018000F0,$01000200        
        endc
        
        if DISPLAYDEBUGMEMORY==0
		dc.l 	$2adffffe,$01800000,$01000200
        endc
        
		Dc.l	$fffffffe

; Default Sprite. Will be used when computing the full animated chain.
; Sprite 1 = Cursor
; Sprite 3 & 4 = Gui Interface

SpriteCursor: ; Wait data, as we only use this as temporary data
  dc.w $225a,$3d00
  ; data
  dc.w $0f40,$16a0 ; 16x16
  dc.w $3fe0,$5f50
  dc.w $61f0,$bfe8
  dc.w $7bf8,$fff4
  dc.w $f7f8,$fff6
  dc.w $e10c,$fff2
  dc.w $7fdc,$fff3
  dc.w $7fbe,$bfe1
  dc.w $3f0c,$5ff3
  dc.w $0ff8,$37c7
  dc.w $01e0,$0e1e
  dc.w $0700,$0ef8
  dc.w $0fc0,$1730
  dc.w $07b0,$0a68
  dc.w $0038,$07c4
  dc.w $0010,$002e
  dc.w 0,0 ; stop 
SpriteGui1:
  dc.w $e7d8,$f180 ; these are correct. 9 pixel displaid (not 16)
  ; data  
  dc.w $001e,$0000
  dc.w $00ba,$0070
  dc.w $049e,$021c
  dc.w $0dce,$118a
  dc.w $7d1c,$6100
  dc.w $7e96,$7890
  dc.w $6dee,$7574
  dc.w $6fae,$3ba4
  dc.w $5fd6,$68d4
  dc.w $7f8e,$4c04
  dc.w $ff7e,$0004
  dc.w $7ec4,$dc04
  dc.w $060c,$0004
  dc.w $3aee,$f086
  dc.w $3fee,$f146
  dc.w $fefe,$dc1c 
  dc.w 0,0 ; stop
SpriteGui2:
  dc.w $e7d8,$f180 ; these are correct. 9 pixel displaid (not 16)
  ; data  
  dc.w $0000,$0000
  dc.w $000a,$0004
  dc.w $01ee,$0004
  dc.w $097a,$0604
  dc.w $18f8,$3e06
  dc.w $3168,$7e06
  dc.w $3188,$7e06
  dc.w $7358,$7c06
  dc.w $3128,$7e06
  dc.w $31f8,$7e06
  dc.w $3df8,$7e06
  dc.w $21f8,$7e06
  dc.w $03f8,$fc06
  dc.w $cbfa,$f404
  dc.w $c6fa,$f804
  dc.w $23ea,$f804
  dc.w 0,0 ; stop

emptyline: ; Need 40 empty bytes here  
NullSprite:
  dc.l 0 ; Stop (4 bytes)
  blk.b 36,0 ; 36 bytes to get the 40 empty bytes
  
;--------------------------------------------------------------
LogoData:
    incbin  "data/logo_melodees.ami" ; 40 width wide, so pointing directly to it.
GuiData:
    incbin  "data/gui.ami" ; 40 width wide, so pointing directly to it. 
GuiData_End:
  
;--------------------------------------------------------------

	data_f

    
SpriteCursorDataOnly:
  ; data
  dc.w $0000,$e000 ; 16x16
  dc.w $4000,$b000
  dc.w $6000,$9800
  dc.w $7000,$cc00
  dc.w $7800,$c600
  dc.w $7c00,$e300
  dc.w $7e00,$e180
  dc.w $7f00,$f0c0
  dc.w $7f80,$f060
  dc.w $7e00,$f9e0
  dc.w $7c00,$f7e0
  dc.w $6600,$dd80
  dc.w $0200,$ff80
  dc.w $0300,$76c0
  dc.w $0100,$03c0
  dc.w $0000,$03c0

SpriteCursorWaitDataOnly:
  ; data
  dc.w $0f40,$16a0 ; 16x16
  dc.w $3fe0,$5f50
  dc.w $61f0,$bfe8
  dc.w $7bf8,$fff4
  dc.w $f7f8,$fff6
  dc.w $e10c,$fff2
  dc.w $7fdc,$fff3
  dc.w $7fbe,$bfe1
  dc.w $3f0c,$5ff3
  dc.w $0ff8,$37c7
  dc.w $01e0,$0e1e
  dc.w $0700,$0ef8
  dc.w $0fc0,$1730
  dc.w $07b0,$0a68
  dc.w $0038,$07c4
  dc.w $0010,$002e
  
; --------------------------------------
; GUI buttons
; 16x28. coord 40x19  
gui_prev:               dc.b 16,28,40,19
                        dc.l gui_prev_off
                        dc.l gui_prev_on
                        dc.l gui_prev_rollover
gui_prev_off:           incbin "data/gui_prev_off.ami"
gui_prev_on:            incbin "data/gui_prev_on.ami"
gui_prev_rollover:	    incbin "data/gui_prev_rollover.ami"

; 16x28. coord 64x19
gui_next:               dc.b 16,28,64,19
                        dc.l gui_next_off
                        dc.l gui_next_on
                        dc.l gui_next_rollover
gui_next_off:	        incbin "data/gui_next_off.ami"
gui_next_on:	        incbin "data/gui_next_on.ami"
gui_next_rollover:	    incbin "data/gui_next_rollover.ami"

; 8x18. coord 56x18
gui_play:               dc.b 8,18,56,18
                        dc.l gui_play_off
                        dc.l gui_play_on
                        dc.l gui_play_rollover
gui_play_off:	        incbin "data/gui_play_off.ami"
gui_play_on:	        incbin "data/gui_play_on.ami"
gui_play_rollover:	    incbin "data/gui_play_rollover.ami"

; 8x18. coord 56x18
gui_pause:               dc.b 8,18,56,18
                        dc.l gui_pause_off
                        dc.l gui_pause_on
                        dc.l gui_pause_rollover
gui_pause_off:	        incbin "data/gui_pause_off.ami"
gui_pause_on:	        incbin "data/gui_pause_on.ami"
gui_pause_rollover:	    incbin "data/gui_pause_rollover.ami"

; 8x10. coord 56x37
gui_modeseq:            dc.b 8,10,56,37
                        dc.l gui_modeseq_off
                        dc.l gui_modeseq_on
                        dc.l gui_modeseq_rollover
gui_modeseq_off:	    incbin "data/gui_modeseq_off.ami"
gui_modeseq_on:	        incbin "data/gui_modeseq_on.ami"
gui_modeseq_rollover:	incbin "data/gui_modeseq_rollover.ami"

; 8x10. coord 56x37
gui_modeloop:           dc.b 8,10,56,37
                        dc.l gui_modeloop_off
                        dc.l gui_modeloop_on
                        dc.l gui_modeloop_rollover
gui_modeloop_off:	    incbin "data/gui_modeloop_off.ami"
gui_modeloop_on:	    incbin "data/gui_modeloop_on.ami"
gui_modeloop_rollover:	incbin "data/gui_modeloop_rollover.ami" 

; titles are displayed at position : 88x26
song_titles: ; 200x16*8+1titles 32 colors
                        incbin "data/song_titles2.ami"
title_mask: ; 64x16 2 colors. 8 bytes width.
                        incbin "data/title_mask_16_2colors.ami"
title_mask_data= title_mask+((2+2+2+4+2*2))                       
                        
gui_coords_prev: ; Xmin, Xmax, Ymin, Ymax
    dc.w $ac,$b6,$ff,$11c
gui_coords_next:
    dc.w $c1,$ca,$ff,$11c                         
gui_coords_play:
    dc.w $b6,$c1,$ff,$112                          
gui_coords_mode:
    dc.w $b6,$c1,$112,$11c 

CentralSpriteOffsetY:
    dc.w    $0000
CentralSpriteTableY: ; 67 values
    dc.b    0,0,0,1,0,0,2,0,0,0,1,1,1,2,0,1,1,2,0,1,2,1,2,3,2,1,2,1
    dc.b    1,1,0,1,0,1,2,1,2,3,2,1,2,1,1,1,2,1,2,1,0,1,0,0,1,1,0,$ff
    even
CentralSpriteTableY_NoMotion:
    dc.b    0,0,0,0,0,0,0,0,0,$ff
    even
CentralSpriteTableY_SmallMotion:
    dc.b    1,1,1,1,1,0,1,1,1,1,2,$ff
    even
CentralSpriteTableY_BigMotion: ; 67 values
    dc.b    0,0,0,1,0,0,2,0,0,0,1,1,1,2,0,1,1,2,0,1,2,1,2,3,2,1,2,1
    dc.b    1,1,0,1,0,1,2,1,2,3,2,1,2,1,1,1,2,1,2,1,0,1,0,0,1,1,0,$ff
    even    
    
CentraSpriteTableYPtr:
    dc.l CentralSpriteTableY
CentraSpriteTableSpeed:
    dc.w    0

BackgroundXPos:
    dc.w    0 ; 0 to 640  
  
currentmusic: ; Module from 1 to 8
	dc.w 0 
previousmusic: ; Module from 1 to 8 (Used to know if last module was a big module)
	dc.w 0     
haveenoughchip: ; Have at least 512+256 chip ram ??
    dc.w 0
    
    
flag_do_not_change_scroll:
    dc.b 0
    
    even   

SpriteHeight:       dc.w 0 ; Height of central sprite, same for all frames
SpriteNbFrames:     dc.w 0 ; Number of frames
SpriteCurrentFrame: dc.l SpriteFrame1Ptrs
SpriteFrame1Ptrs:   blk.l 12,0
SpriteFrame2Ptrs:   blk.l 12,0
SpriteFrame3Ptrs:   blk.l 12,0
SpriteFrame4Ptrs:   blk.l 12,0
SpriteFrame5Ptrs:   blk.l 12,0
SpriteFrame6Ptrs:   blk.l 12,0
;OFFSETSpriteCursorPtr=0*4;
;OFFSETSpriteGui1Ptr=1*4; 
;OFFSETSpriteGui2Ptr=2*4; 
;OFFSETSpriteMain1aPtr=3*4; 
;OFFSETSpriteMain1bPtr=4*4; 
;OFFSETSpriteMain2aPtr=5*4; 
;OFFSETSpriteMain2bPtr=6*4; 
;OFFSETSpriteMain3aPtr=7*4; 
;OFFSETSpriteMain3bPtr=8*4; 
;OFFSETSpriteMain4aPtr=9*4; 
;OFFSETSpriteMain4bPtr=10*4; 
;OFFSETNullSpritePtr=11*4; 
 
; One frame is 12 pointers.
;SpriteCursorPtr:    dc.l 0 ; Chained with Sprite 1 of central element
;SpriteGui1Ptr:      dc.l 0 ; Chained with Sprite 3 of central element
;SpriteGui2Ptr:      dc.l 0 ; Chained with Sprite 4 of central element
;SpriteMain1aPtr:    dc.l 0
;SpriteMain1bPtr:    dc.l 0
;SpriteMain2aPtr:    dc.l 0
;SpriteMain2bPtr:    dc.l 0
;SpriteMain3aPtr:    dc.l 0
;SpriteMain3bPtr:    dc.l 0
;SpriteMain4aPtr:    dc.l 0
;SpriteMain4bPtr:    dc.l 0
NullSpritePtr:      dc.l 0
    
Font1:
	incbin "data/Font16.bin" ; Done with blitter so should be. 14K    
    
;--------------------------------------------------------------

	bss_c

start_planes:	

    if DISPLAYDEBUGMEMORY==1
plansDebugMem
	ds.b	12*40*4 ; 4 planes. 1920 bytes
    endc

planescrolling1:
	ds.b	46*16*4	; 8 colors scrolling. 2208 bytes .... plus one plane , for 16 colors
    ; Some letters are bigger than 16 pixels (yjg)
    ds.b    46*4*1 ; Add 1 more lines

;planesparalax1:
;    ds.b    43*42*5 ; 43 lines for 5 planes. 9 KB. Double buffered
;planesparalax2:
;    ds.b    43*42*5 ; 43 lines for 5 planes. 9 KB

end_planes:

;---------------------------------------------------------------
; Sprite zone (in chip ram). This zone is generated from loaded level
; Animated sprite can be up to 100 in height.
; So one picture can be up to (100+2)*4*8 = 3264 bytes (for one frame)
; Cursor is 18*4 = 72
; Sprite gui is 18*4 = 72 * 2
SPRITENUMFRAMESMAX=6
; One line = 4*8 ... 32 bytes 
; 1 = (100+2)*3frames = 306 = 9792 bytes
; 2 = (20+2)*2 = 
; 3 = (64+2)*3 = 198
; 4
; 5 = (45+2)*2
; 6
; 7 = (29+2)*2
; 8 = (47+2)*4 = 196

SpriteZone: ; Generated from level loaded. 
        ds.b (9792)+((72+72+72)*SPRITENUMFRAMESMAX), 0 ; 7176 bytes for 2 frames

;---------------------------------------------------------------
; This part is fully computed from loaded data (loaded data in fast).
; Loaded data are smaller, we duplicate data here to allow one block copy of looping background
; Background -- chip data
; Back -- Paralax top part
; This part is 90K
; We allocate this at end of chip ram, in one block.
paralaxsize=7600+17200+20640+20640+24000+9030+9030
paralax_backtop_640x19_offset=0
paralax_back_640x43_offset=paralax_backtop_640x19_offset+7600
paralax_front_960x43_offset=paralax_back_640x43_offset+17200
paralax_front_960x43_mask_offset=paralax_front_960x43_offset+20640
paralax_frontbottom_960x50_offset=paralax_front_960x43_mask_offset+20640 ; 24000 bytes
planesparalax1_offset = paralax_frontbottom_960x50_offset + 24000 ; 9030
planesparalax2_offset = planesparalax1_offset + 9030 ; (43*42*5)= 9030

;paralax_backtop_640x19: ; Pointed by CopperList directly
;    blk.b 80*19*5; ; 7600 bytes
;    
;paralax_back_640x43:
;    blk.b 80*43*5 ;  17200 bytes
;    
;; Front -- Paralax top part    
;paralax_front_960x43:
;    blk.b 120*43*4 ; 20640 bytes
;    
;; Front -- Paralax top part mask     
;paralax_front_960x43_mask: ; width = 960 , 43 * 4 planes (same) 20640 bytes
;    ;incbin "data/paralax_front_960x43_mask_invx4.bob" 
;    blk.b 120*43*4 ; 20640 bytes
;    
;; Front -- Paralax Bottom part (4 bitplanes) no mask   
;paralax_frontbottom_960x50: ; Pointed by CopperList directly
;    ;incbin "data/paralax_frontbottom_960x50.bob" ; 16 colors
;    blk.b 120*50*4 ; 24000 bytes
;---------------------------------------------------------------    

; 76 Kb of data are lost in chip mem, should be allocated after start ? to fill the holes


;--------------------------------------------------------------

	bss_f

PaletteZero: ; Should be empty
    blk.b 64*3,0 ; 64 colors to Zero.
Palette32_1:
    blk.b 32*3,0
Palette32_2:
    blk.b 32*3,0    
Palette64_1:
    blk.b 64*3,0  
Palette64_2:
    blk.b 64*3,0

    ; Loaded level
    ;LoadedLevel:
    ;blk.b 64000 ; TODO Set this to max data size
    ;incbin "data/file.bin" ; All loaded data in one block.
    ; 32 bytes    : palette
    ; 12400 bytes : pictureparalax back  320x62x5   SIDE by SIDE
    ; 29760 bytes : pictureparalax front 640x93_16c SIDE by SIDE
    ; 3440 bytes  : front mack 640x43x1