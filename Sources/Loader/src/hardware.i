BLTBASE		= $dff000
CUSTOM		= $dff000

BLTDDAT		= $000		
DMACONR		= $002

BLTCON0		= $040		
BLTCON1		= $042		
BLTAFWM		= $044		
BLTALWM		= $046		
BLTCPTR		= $048
BLTCPTH		= $048
BLTCPTL		= $04A
BLTBPTR		= $04c
BLTBPTH		= $04C
BLTBPTL 	= $04E
BLTAPTH		= $050
BLTAPTR		= $050
BLTAPTL		= $052
BLTDPTR		= $054
BLTDPTH		= $054
BLTDPTL		= $056
BLTSIZE		= $058
BLTCMOD		= $060
BLTBMOD		= $062
BLTAMOD		= $064
BLTDMOD		= $066
BLTCDAT 	= $070
BLTBDAT 	= $072
BLTADAT		= $074
DIWSTRT		= $08E
DIWSTOP		= $090
DDFSTRT  	= $092
DDFSTOP  	= $094
DMACON		= $096
INTREQR     = $01e
INTENA		= $09a
INTREQ		= $09c

BPLCON0		= $100
BPLCON1		= $102
BPLCON2		= $104
BPLCON3     = $106
BPL1MOD     = $108
BPL2MOD     = $10a
BPLCON4     = $10c

BPL1PTH		= $0e0
BPL1PTL		= $0e2
BPL2PTH		= $0e4
BPL2PTL		= $0e6
BPL3PTH		= $0e8
BPL3PTL		= $0ea
BPL4PTH		= $0ec
BPL4PTL		= $0ee
BPL5PTH		= $0f0
BPL5PTL		= $0f2
BPL6PTH		= $0f4
BPL6PTL		= $0f6
BPL7PTH		= $0f8
BPL7PTL		= $0fa
BPL8PTH		= $0fc
BPL8PTL		= $0fe

BPL1DAT   	= $110
BPL2DAT   	= $112
BPL3DAT   	= $114
BPL4DAT   	= $116
BPL5DAT   	= $118
BPL6DAT 	= $11a

COP1LCH		= $080
COP1LCL		= $082
COP2LCH		= $084
COP2LCL		= $086
COPJMP1		= $088
COPJMP2		= $08A

SPR0PTH		= $120
SPR0PTL		= $122
SPR1PTH		= $124
SPR1PTL		= $126
SPR2PTH		= $128
SPR2PTL		= $12a
SPR3PTH		= $12c
SPR3PTL		= $12e
SPR4PTH		= $130
SPR4PTL		= $132
SPR5PTH		= $134
SPR5PTL		= $136
SPR6PTH		= $138
SPR6PTL		= $13a
SPR7PTH		= $13c
SPR7PTL		= $13e

SPR0CTL		= $142	; Sprite 0 vert stop position and control data
SPR0DATA 	= $144  ; Sprite 0 image data register A
SPR0DATB 	= $146  ; Sprite 0 image data register B
SPR1POS  	= $148  ; Sprite 1 vert-horiz start position data
SPR1CTL  	= $14A  ; Sprite 1 vert stop position and control data
SPR1DATA 	= $14C  ; Sprite 1 image data register A
SPR1DATB 	= $14E  ; Sprite 1 image data register B
SPR2POS  	= $150  ; Sprite 2 vert-horiz start position data
SPR2CTL  	= $152  ; Sprite 2 vert stop position and control data
SPR2DATA 	= $154  ; Sprite 2 image data register A
SPR2DATB 	= $156  ; Sprite 2 image data register B
SPR3POS  	= $158  ; Sprite 3 vert-horiz start position data
SPR3CTL		= $15A  ; Sprite 3 vert stop position and control data
SPR3DATA	= $15C  ; Sprite 3 image data register A
SPR3DATB	= $15E  ; Sprite 3 image data register B
SPR4POS 	= $160  ; Sprite 4 vert-horiz start position data
SPR4CTL		= $162  ; Sprite 4 vert stop position and control data
SPR4DATA	= $164  ; Sprite 4 image data register A
SPR4DATB	= $166  ; Sprite 4 image data register B
SPR5POS		= $168  ; Sprite 5 vert-horiz start position data
SPR5CTL		= $16A  ; Sprite 5 vert stop position and control data
SPR5DATA	= $16C  ; Sprite 5 image data register A
SPR5DATB	= $16E  ; Sprite 5 image data register B
SPR6POS		= $170  ; Sprite 6 vert-horiz start position data
SPR6CTL		= $172  ; Sprite 6 vert stop position and control data
SPR6DATA	= $174  ; Sprite 6 image data register A
SPR6DATB	= $176  ; Sprite 6 image data register B
SPR7POS 	= $178  ; Sprite 7 vert-horiz start position data
SPR7CTL		= $17A  ; Sprite 7 vert stop position and control data
SPR7DATA	= $17C  ; Sprite 7 image data register A
SPR7DATB	= $17E  ; Sprite 7 image data register B

COLOR0		= $180
COLOR1		= $182
COLOR2		= $184
COLOR3		= $186
COLOR4		= $188
COLOR5		= $18a
COLOR6		= $18c
COLOR7		= $18e
COLOR8		= $190
COLOR9		= $192
COLOR10		= $194
COLOR11		= $196
COLOR12		= $198
COLOR13		= $19a
COLOR14		= $19c
COLOR15		= $19e
COLOR16		= $1a0
COLOR17		= $1a2
COLOR18		= $1a4
COLOR19		= $1a6
COLOR20		= $1a8
COLOR21		= $1aa
COLOR22		= $1ac
COLOR23		= $1ae
COLOR24		= $1b0
COLOR25		= $1b2
COLOR26		= $1b4
COLOR27		= $1b6
COLOR28		= $1b8
COLOR29		= $1ba
COLOR30		= $1bc
COLOR31		= $1be

FMODE		= $1fc
COPNOP		= $1fe

BLITTER_COPY = $09f00000	; A->D copy, no shifts, ascending mode

BlitWait_Inline		macro
.Wait\@				btst	#6,DMACONR(a6)
					bne.s	.Wait\@
					endm
	
	ifd DONOTCOMPILE
	
BLTCON0 & BLTCON1					
                    AREA MODE ("normal")
                 -------------------------
                 BIT# BLTCON0     BLTCON1
                 ---- -------     -------
                 15   ASH3        BSH3
                 14   ASH2        BSH2
                 13   ASH1        BSH1
                 12   ASA0        BSH0
                 11   USEA         X
                 10   USEB         X
                 09   USEC         X
                 08   USED         X
                 07   LF7(ABC)    DOFF
                 06   LF6(ABc)     X
                 05   LF5(AbC)     X
                 04   LF4(Abc)    EFE
                 03   LF3(aBC)    IFE
                 02   LF2(aBc)    FCI
                 01   LF1(abC)    DESC
                 00   LF0(abc)    LINE(=0)

                 ASH3-0  Shift value of A source
                 BSH3-0  Shift value of B source
                 USEA    Mode control bit to use source A
                 USEB    Mode control bit to use source B
                 USEC    Mode control bit to use source C
                 USED    Mode control bit to use destination D
                 LF7-0   Logic function minterm select lines
                 EFE     Exclusive fill enable
                 IFE     Inclusive fill enable
                 FCI     Fill carry input
                 DESC    Descending (decreasing address) control bit
                 LINE    Line mode control bit (set to 0)

	endc