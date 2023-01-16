
************************************************************************************************
* This loader is responsible for copying the 6502 emulation core into ram address $E000 in a
* way that doesn't kill BASIC's LOADM command, but once running, let's us have MOST of the
* coco address space contiguously to store the 6502's ram into. (MMU Task 1 from $0000 to $E000)
* This code also contains the vram renderer and the beep code as well as remote IO calls to
* talk to BASIC's GET/PUT character routines
************************************************************************************************

payload_dest 		EQU  	$E000
mmu_bank7 		EQU 	$FFA7
mmu_bank15  		EQU  	$FFAF

diskOpCode 		EQU  	$00EA
diskTrack  		EQU 	$00EC	
diskSector  		EQU  	$00ED
diskDataPtr 		EQU  	$00EE
diskStatus  		EQU 	$00F0
DSKCON  		EQU  	$C004

gime_init0 		EQU 	$FF90 
gime_init1 		EQU 	$FF91
gime_timer 		EQU 	$FF94
gime_vmode 		EQU 	$FF98
gime_vres 		EQU 	$FF99
gime_border 		EQU 	$FF9A
gime_vert_scroll 	EQU 	$FF9C
gime_vert_offset	EQU 	$FF9D
gime_palette0 	EQU 	$FFB0
gime_palette1 	EQU 	$FFB1
gime_palette2 	EQU 	$FFB2
gime_palette3 	EQU 	$FFB3
gime_palette4 	EQU 	$FFB4
gime_palette5 	EQU 	$FFB5
gime_palette6 	EQU 	$FFB6
gime_palette7 	EQU 	$FFB7
gime_palette8 	EQU 	$FFB8
gime_palette9 	EQU 	$FFB9
gime_palette10	EQU 	$FFBA
gime_palette11 	EQU 	$FFBB
gime_palette12 	EQU 	$FFBC
gime_palette13 	EQU 	$FFBD
gime_palette14 	EQU 	$FFBE
gime_palette15 	EQU 	$FFBF

mmu_bank0  		EQU  	$FFA0
mmu_bank1  		EQU  	$FFA1
mmu_bank2  		EQU  	$FFA2
mmu_bank3  		EQU  	$FFA3
mmu_bank4 		EQU 	$FFA4 		; Controls Task 1 $8000-$9FFF
mmu_bank5  		EQU  	$FFA5   		; Controls Task 1 $A000-$BFFF

code_mmu_blk 		EQU  	$08
coco3_fast  		EQU  	$FFD9

		pragma 	6309
		org 		$2800
		FDB  		APPLE_BEEP
		FDB  		POLDRAGON
		FDB  		UPDATE_SCREEN_GFX_MODE

		include 	apple2_keyboard.asm
; -----------------------------------------------------------------
PRINT_CHAR
	pshs  	Y,X,D,DP

	; swap BASIC routines in
	ldb  	#$3F 
	stb  	>mmu_bank7
	clrb 
	tfr  	B,DP
	jsr  	[$A002]
	orcc  	#$50  		; just in case interrupts are re-enabled from BASIC

	ldb  	#code_mmu_blk
	stb  	>mmu_bank7

	ldy  	#$FFA8 
	ldx  	#mmuRemapAfterBASIC
	ldb  	#8 
PRINT_CHAR_REMAP_MMU
	lda  	,X+
	sta  	,Y+
	decb 
	bne  	PRINT_CHAR_REMAP_MMU

	puls  	D,X,Y,DP,PC

; -----------------------------------------------------------------
GET_CHAR
	pshs  	B,DP

	; swap BASIC routines in
	ldb  	#$3F 
	stb  	>mmu_bank7
	clrb 
	tfr  	B,DP
	jsr  	[$A000]
	orcc  	#$50

	ldb  	#code_mmu_blk
	stb  	>mmu_bank7

	tsta 

	puls  	B,DP,PC
	

	*************************************************************************************************
START
	orcc  	#$50

	sts  	<origStackptr
	lds  	#$2800
	clr  	>coco3_fast

	; clear 6502 video ram and insert my author credits in there
	;clr  	>mmu_bank2 
	;ldx  	#$4400
	;ldy 	#clearScrnByte	; should be $00 at the time of calling this copy instruction
	;ldw  	#$0400
	;tfm  	Y,X+

	;ldy  	#strEmuName
	;ldx  	,Y++
	;jsr   	PRINT_INFO
	;ldy  	#strEmuDescription1
	;ldx  	,Y++
	;jsr  	PRINT_INFO
	;ldy  	#strEmuDescription2
	;ldx  	,Y++
	;jsr  	PRINT_INFO
	;ldy  	#strEmuAuthor
	;ldx  	,Y++
	;jsr   	PRINT_INFO

;	lda  	#$3A 
;	sta  	>mmu_bank2

	jsr  	SETUP_VIDEO_GFX
	jsr   	UPDATE_SCREEN_GFX_MODE

	; before anything else, we need to swap in another MMU block for $E000-$FE00 region so we don't nuke BASIC
	lda  	#code_mmu_blk		
	sta  	>mmu_bank7  	
	sta  	>mmu_bank15   	; VERY IMPORTANT. THE LAST TWO MMU BANKS MUST BE MIRRORED WHERE OUR CODE LIVES
	
	ldx  	#PAYLOAD_BODY 	; start of actual main code
	ldy  	#payload_dest 	; destination address
	ldw  	#payload_body_sz
	tfm  	X+,Y+

	clr     >$FF40 		; turn off the floppy motor

	jmp  	[PAYLOAD_EXEC]

PAYLOAD_EXEC 		EQU  	*
PAYLOAD_BODY 		EQU  	*+2
	includebin 	cpu6502payload.bin
payload_body_sz 	EQU 	*-PAYLOAD_BODY

strEmuName  		FDB  	$4500+15
			FCN  	"APPLE2COCO"
strEmuDescription1 	FDB  	$44A8+7
			FCN  	"A SIMPLE APPLE II EMULATOR"
strEmuDescription2 	FDB  	$45A8+5
			FCN  	"FOR THE TANDY COLOR COMPUTER 3"
strEmuAuthor  	FDB  	$4550+9
			FCN  	"WRITTEN BY TODD WALLACE"

fontBitmap  		EQU  	*
	includebin  	font8x8.bin  	; 64 non-inverted chars followed by the 64 inverted versions
	includebin 	font8x8_inverted.bin

cpu6502mmuMap 	FCB  	$00,$02,$03,$04,$05,$06,$07,$01 ; skip $01 since its our special buffer for >$E000
mmuRemapAfterBASIC 	FCB  	$00,$02,$03,$04,$05,$06,$07,code_mmu_blk
totalPages  		FCB  	$00
clearScrnByte		FCB  	$A0
origStackptr  	FDB  	$0000

appleVidPtrTable  	FDB  	$6400,$6480,$6500,$6580,$6600,$6680,$6700,$6780
			FDB  	$6428,$64A8,$6528,$65A8,$6628,$66A8,$6728,$67A8
			FDB  	$6450,$64D0,$6550,$65D0,$6650,$66D0,$6750,$67D0
			FDB  	0 		; null terminator NEEDED 

columnCounter 	FCB  	40
*******************************************************************
PRINT_INFO
	pshs  	D 
	clrb
PRINT_INFO_NEXT_CHAR
	lda  	,Y+
	beq  	PRINT_INFO_DONE
	ora  	#$80 
	sta  	,X+
	decb  
	bne  	PRINT_INFO_NEXT_CHAR
PRINT_INFO_DONE
	puls  	D,PC

; ---------------------------------
; Setup 320x192 gfx mode in GIME
; ---------------------------------
SETUP_VIDEO_GFX
	pshs 	D,CC
	orcc 	#$50

	; setup color palette
	;lda  	#1 		; background color 0 for background (dark blue)
	clra 			; black background
	sta 	>gime_palette0
	sta 	>gime_border
	lda 	#16  		; foreground text color 0 (green)
	sta  	>gime_palette1 	; for background cursor color 

	ldd 	#$D800			; Point GIME screen memory to $6C000 real address
	std 	gime_vert_offset

	lda 	#%10000000
	sta 	gime_vmode
	lda 	#%00001100
	sta 	gime_vres
	lda 	#%01000100
	sta 	gime_init0
	clra
	sta 	gime_init1

	puls 	CC,D,PC

; ------------------------------------------------------
; render an apple 2 low-res text screen using coco gfx 
; ------------------------------------------------------
UPDATE_SCREEN_GFX_MODE
	pshs  	U,Y,DP,X,D
	pshsw

	; map coco video memory into $4000 and 6502 address $0000 into coco address $6000
	ldd  	#$3600
	std  	>mmu_bank2 

	ldw  	#$4000
	ldu  	#appleVidPtrTable
UPDATE_SCREEN_GFX_MODE_NEXT_ROW
	lda  	#40
	sta  	>columnCounter
	ldy  	,U++
	beq  	UPDATE_SCREEN_GFX_MODE_DONE
UPDATE_SCREEN_GFX_MODE_NEXT_CHAR
	ldb  	,Y
	andb  	#%00111111
	clra 
	lsld 
	lsld 
	lsld 
	addd  	#fontBitmap
	tst  	,Y+
	bmi  	UPDATE_SCREEN_GFX_MODE_NOT_INVERTED
	addd  	#$0200  	; add offset to inverted font bitmap
UPDATE_SCREEN_GFX_MODE_NOT_INVERTED
	tfr  	D,X  
	ldd  	,X
	sta  	,W
	stb  	40,W   	; 40 bytes per row
	ldd  	2,X 
	sta  	80,W 
	stb  	120,W 
	ldd  	4,X 
	sta  	160,W 
	stb  	200,W 
	ldd  	6,X 
	sta  	240,W 
	stb  	280,W 
	incw 
	dec  	>columnCounter
	bne  	UPDATE_SCREEN_GFX_MODE_NEXT_CHAR
	addw  	#40*7  		; add 7 scanline rows more of pixels to get us to next char row
	bra  	UPDATE_SCREEN_GFX_MODE_NEXT_ROW

UPDATE_SCREEN_GFX_MODE_DONE
	; restore original MMU state
	ldd  	#$3A3B 
	std  	>mmu_bank2  

	pulsw
	puls  	D,X,DP,Y,U,PC 

; ---------------------------------------------------------------------
; Special thanks to MrDave6309 for showing me this simple BEEP routine!
; ---------------------------------------------------------------------
APPLE_BEEP
	pshs  	D
	pshsw 

	bsr 	APPLE_BEEP_SENA
APPLE_BEEP_SOUND
	lde 	#34
APPLE_BEEP_LOOP1
	lda 	#$F8
	sta 	$FF20
	jsr 	APPLE_BEEP_SDLY
	jsr 	APPLE_BEEP_SDLY
	lda 	#$0C
	sta 	$FF20
	jsr 	APPLE_BEEP_SDLY
	jsr 	APPLE_BEEP_SDLY
	dece
	bne 	APPLE_BEEP_LOOP1
	inc 	SCNT
	lda 	SCNT
	cmpa 	#3
	bne 	APPLE_BEEP_SOUND
	clr 	SCNT
	pulsw 
	puls 	D,PC

APPLE_BEEP_SDLY
	ldb 	SDAT1
APPLE_BEEP_SLOP
	decb
	bne 	APPLE_BEEP_SLOP
	rts

APPLE_BEEP_SENA
	lda 	$FF01
	anda 	#$F7
	sta 	$FF01
	lda 	$FF03
	anda 	#$F7
	sta 	$FF03
	lda 	$FF23
	ora 	#8
	sta 	$FF23
	rts 

SDAT1 	FCB 	$74 		; this adjusts pitch
SCNT 	FCB 	$00

	END 	START

