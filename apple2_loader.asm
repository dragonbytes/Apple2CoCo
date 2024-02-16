**********************************************************************
* Apple2Coco v1.0
* Written by Todd Wallace
*
* My Links:
* https://www.youtube.com/@tekdragon
* https://github.com/dragonbytes
* https://tektodd.com
**********************************************************************

payload_dest 		EQU  	$E000
mmu_bank7 		EQU 	$FFA7
mmu_bank15  		EQU  	$FFAF

diskOpCode 		EQU  	$00EA
diskDriveNum  	EQU  	$00EB
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
coco3_slow   		EQU  	$FFD8
coco3_fast  		EQU  	$FFD9
CASBUF  		EQU  	$01DA

;debugger_enabled   	EQU  	1

		pragma 	6309
; ----------------------------------------------------------------
; This small routine is stashed in the little-used cassette buffer
; because it is a protected area of memory that BASIC never swaps
; out. When calling CONSOLE OUT from a hi-res text mode, BASIC
; normally clobbers the MMU blocks which would break my loader in
; various ways. This routine bypasses the issue :)
; ----------------------------------------------------------------
		org  		CASBUF 	
PRINT_CHAR
	sts  	backupStackPtr
	lds  	#tempStackStart
	jsr  	[$A002]
	lds  	backupStackPtr
	rts
	  		RMB  	32
tempStackStart
backupStackPtr  	RMB  	2
; -----------------------------------------------------
		org 		$2800
		
			FDB  		APPLE_BEEP
			FDB  		POLDRAGON
			FDB  		UPDATE_SCREEN_GFX_MODE
			FDB  		UPDATE_SCREEN_LO_RES_GFX
		;FDB  		FLOPPY_READ_SECTOR
columnCounter 	FCB  	40 
appleRowPtr  		RMB  	2
charPtr  		RMB  	2
tempByte  		RMB  	1
romProgessCounter  	RMB  	1
curDiskMMUblock  	RMB  	1

		include 	apple2_keyboard.asm
		;include  	apple2_floppy.asm
		include  	apple2_rom_load.asm
; -----------------------------------------------------------------
PRINT_NULL_STRING
	pshs  	Y,D

	clrb 
PRINT_NULL_STRING_NEXT_CHAR
	lda  	,Y+
	beq   	PRINT_NULL_STRING_DONE
	jsr  	PRINT_CHAR
	;jsr  	$0167
	decb 
	bne  	PRINT_NULL_STRING_NEXT_CHAR
	; if here, overflowed passed 256 bytes
PRINT_NULL_STRING_DONE
	puls  	D,Y,PC

 IFDEF use_BASIC_keyboard
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
	
 ENDC 
	*************************************************************************************************
START
	orcc  	#$50

	sts  	origStackptr
	lds  	#$2800

	; display emulator title/info
	ldy  	#strEmuInfo
	jsr  	PRINT_NULL_STRING
	; tell user we are searching for APPLE2.ROM file
	ldy  	#strROMsearching
	jsr  	PRINT_NULL_STRING
	; before doing any disk reading, get the disk's FAT sector
	ldy  	#decbGranMap
	jsr  	DECB_GET_FAT
	ldy  	#strAppleROMfilename
	jsr  	DECB_FIND_FILENAME
	lbcs  	LOAD_ROM_ERROR_FILE_NOT_FOUND
	ldy  	#strROMloading
	jsr  	PRINT_NULL_STRING
	jsr  	LOAD_APPLE_ROM
	lbcs  	LOAD_ROM_ERROR_INVALID_SIZE
	; if here, we successfully loaded in a valid ROM file
	orcc  	#$50  			; MAKE SURE INTERRUPTS ARE DISABLED
	clr  	>coco3_fast

	; configure gfx lookup tables
	ldx  	#loResGfxLookupTable
	clrw 
	lda  	#16
LORES_GFX_GENERATE_TABLE_NEXT_MSB
	ldb  	#16
LORES_GFX_GENERATE_TABLE_NEXT_LSB
	stw  	,X++
	adde  	#$11
	decb 
	bne   	LORES_GFX_GENERATE_TABLE_NEXT_LSB
	addf  	#$11 
	clre 
	deca 
	bne  	LORES_GFX_GENERATE_TABLE_NEXT_MSB

	; configure large lookup table for lo res gfx text rendering
	ldx  	#loResGfxTextTable
	clrf 
LORES_GFX_TEXT_GENERATE_TABLE_NEXT
	tfr  	F,B
	sex 
	anda  	#$F0 
	sta  	<tempByte 
	lslb 
	sex 
	anda  	#$0F
	ora 	<tempByte
	sta  	,X+
	lslb 
	sex 
	anda  	#$F0 
	sta  	<tempByte
	lslb 
	sex 
	anda  	#$0F 
	ora  	<tempByte
	sta  	,X+
	lslb 
	sex 
	anda  	#$F0 
	sta  	<tempByte
	lslb 
	sex 
	anda  	#$0F 
	ora  	<tempByte
	sta  	,X+
	lslb 
	sex 
	anda  	#$F0 
	sta  	<tempByte
	lslb 
	sex 
	anda  	#$0F 
	ora  	<tempByte
	sta  	,X+
	incf 
	bne  	LORES_GFX_TEXT_GENERATE_TABLE_NEXT

	jsr  	SETUP_VIDEO_GFX

	; set monchrome text default color to white
	lda  	#16
	sta  	>gime_palette1
	jsr   	UPDATE_SCREEN_GFX_MODE

	; before anything else, we need to swap in another MMU block for $E000-$FE00 region so we don't nuke BASIC
	lda  	#code_mmu_blk		
	sta  	>mmu_bank7  	
	sta  	>mmu_bank15   	; VERY IMPORTANT. THE LAST MMU BANK IN EACH TASK MUST BE MIRRORED TO
					; WHERE OUR 6502 CORE CODE LIVES
	
	ldx  	#PAYLOAD_BODY 	; start of actual main code
	ldy  	#payload_dest 	; destination address
	ldw  	#payload_body_sz
	tfm  	X+,Y+

	clr     >$FF40 		; turn off the floppy motor

	jmp  	[PAYLOAD_EXEC]

LOAD_ROM_ERROR_FILE_NOT_FOUND
	ldy  	#strROMfileNotFound
	jsr  	PRINT_NULL_STRING
	bra  	LOAD_ROM_ERROR_EXIT

LOAD_ROM_ERROR_INVALID_SIZE
	ldy  	#strROMinvalidSize
	jsr  	PRINT_NULL_STRING
LOAD_ROM_ERROR_EXIT
	lds  	origStackptr
	sta  	>coco3_slow
	rts

*****************************************************************************
PAYLOAD_EXEC 		EQU  	*
PAYLOAD_BODY 		EQU  	*+2
	includebin 	cpu6502payload.bin
payload_body_sz 	EQU 	*-PAYLOAD_BODY

strAppleROMfilename 	FCC  	"APPLE2  ROM"

strEmuInfo		FCC  	"        -= APPLE2COCO =-\r\r"
			FCC 	"   A SIMPLE APPLE II EMULATOR\r"
			FCC  	" FOR THE TANDY COLOR COMPUTER 3\r\r"
			FCN  	"    WRITTEN BY TODD WALLACE\r\r"

strROMsearching  	FCN  	"LOOKING FOR APPLE2.ROM FILE...\r"
strROMloading  	FCN  	"FOUND ROM FILE. LOADING...\r"
strROMfileNotFound  	FCN  	"ERROR: FILE NOT FOUND\r\r"
strROMinvalidSize  	FCN  	"\r\rERROR: APPLE2.ROM DOES NOT HAVE\rEXPECTED SIZE OF 20480 BYTES\r\r"

fontBitmap  		EQU  	*
	includebin  	font8x8.bin  	; 64 non-inverted chars followed by the 64 inverted versions
	includebin 	font8x8_inverted.bin

cpu6502mmuMap 	FCB  	$00,$02,$03,$04,$05,$06,$07,$01 ; skip $01 since its our special buffer for >$E000
mmuRemapAfterBASIC 	FCB  	$00,$02,$03,$04,$05,$06,$07,code_mmu_blk
totalPages  		FCB  	$00
clearScrnByte		FCB  	$A0
origStackptr  	FDB  	$0000
paletteTable  	FCB  	0,33,8,40,2,7,29,57,6,38,56,47,16,48,26,63

loResTxtVidPtrTable 	FDB  	$0400,$0480,$0500,$0580,$0600,$0680,$0700,$0780
			FDB  	$0428,$04A8,$0528,$05A8,$0628,$06A8,$0728,$07A8
			FDB  	$0450,$04D0,$0550,$05D0,$0650,$06D0,$0750,$07D0 
			FDB  	0 		; null terminator NEEDED 

loResGfxVidPtrTable  FDB  	$0400,$0480,$0500,$0580,$0600,$0680,$0700,$0780
			FDB  	$0428,$04A8,$0528,$05A8,$0628,$06A8,$0728,$07A8
			FDB  	$0450,$04D0,$0550,$05D0
			FDB  	$FFFF  	; flag to tell routine to check for mixed text mode
			; these last 4 rows are used in some modes as mixed text+graphics
			FDB  	$0650,$06D0,$0750,$07D0 
			FDB  	0 		; null terminator NEEDED 

zeroByte  		FCB  	0
loResGfxLookupTable	RMB  	512
loResGfxTextTable  	RMB  	1024
*******************************************************************
 IFDEF use_opening_title
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
 ENDC 
; ---------------------------------
; Setup 320x192 gfx mode in GIME
; ---------------------------------
SETUP_VIDEO_GFX
	pshs 	Y,X,D,CC
	orcc 	#$50

	; setup color palette
	;lda  	#1 		; background color 0 for background (dark blue)
	clra 			; black background
	sta 	>gime_border
	ldb  	#16
	ldy  	#gime_palette0
	ldx  	#paletteTable
SETUP_VIDEO_GFX_PALETTE_NEXT
	lda  	,X+
	sta  	,Y+
	decb 
	bne  	SETUP_VIDEO_GFX_PALETTE_NEXT

	ldd 	#$4000			; Point GIME screen memory to $20000 real address
	std 	gime_vert_offset

	lda 	#%10000000
	sta 	gime_vmode
	lda 	#%00001100
	sta 	gime_vres
	lda 	#%01000100
	sta 	gime_init0
	clra
	sta 	gime_init1

	puls 	CC,D,X,Y,PC

; ------------------------------------------------------
; render an apple 2 low-res text screen using coco gfx 
; ------------------------------------------------------
UPDATE_SCREEN_GFX_MODE
	pshs  	U,Y,DP,X,D
	pshsw

	; map coco video memory into $6000 and 6502 address $0000 into coco address $0000
	ldd  	#$0010
	sta  	>mmu_bank0 
	stb  	>mmu_bank3

	ldw  	#$6000
	ldu  	#loResTxtVidPtrTable
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
	ldd  	#$383B
	sta  	>mmu_bank0
	stb  	>mmu_bank3

	pulsw
	puls  	D,X,DP,Y,U,PC 

; ------------------------------------------------------
; render an apple 2 low-res text screen using coco gfx 
; ------------------------------------------------------
UPDATE_SCREEN_LO_RES_GFX
	pshs  	U,Y,DP,X,D
	pshsw

	; map coco video memory into $4000 and 6502 address $0000 into coco address $6000
	clr  	>mmu_bank0 
	ldq  	#$10111213
	stq  	>mmu_bank3 

	lda  	#$28
	tfr   	A,DP 
	ldw 	#$6000
	ldu  	#loResGfxVidPtrTable
UPDATE_SCREEN_LO_RES_GFX_NEXT_ROW
	lda  	#40
	sta  	<columnCounter
UPDATE_SCREEN_LO_RES_GFX_NO_TEXT
	ldy  	,U++
	bmi  	UPDATE_SCREEN_LO_RES_GFX_CHECK_MIXED
	lbeq  	UPDATE_SCREEN_LO_RES_GFX_DONE
UPDATE_SCREEN_LO_RES_GFX_NEXT_BLOCK
	ldb  	,Y+ 
	clra 
	lsld 
	ldx  	#loResGfxLookupTable
	addr  	D,X 
	lda 	,X+
	tfr  	A,B 
	; do top-half of character-based "pixel"
	std   	,W  		; 5
	std   	2,W  		; 7
	std  	(160*1),W 	; 7
	std  	(160*1)+2,W   ; 7 
	std   	(160*2),W  	; 7
	std  	(160*2)+2,W  	; 7
	std   	(160*3),W  	; 7
	std  	(160*3)+2,W  	; 7
	; now render the bottom-half 
	lda  	,X
	tfr  	A,B 
	std   	(160*4),W  	; 5
	std   	(160*4)+2,W	; 7
	std  	(160*5),W 	; 7
	std  	(160*5)+2,W   ; 7 
	std   	(160*6),W  	; 7
	std  	(160*6)+2,W  	; 7
	std   	(160*7),W  	; 7
	std  	(160*7)+2,W  	; 7	

	addw  	#4  		; move to next 8-pixel wide start point
	dec  	<columnCounter
	bne  	UPDATE_SCREEN_LO_RES_GFX_NEXT_BLOCK
	addw  	#160*7  		; add 7 scanline rows more of pixels to get us to next char row
	bra  	UPDATE_SCREEN_LO_RES_GFX_NEXT_ROW

UPDATE_SCREEN_LO_RES_GFX_CHECK_MIXED
	lda  	2,S  		; this should be pointing at entry A register on stack containing video mode
	cmpa  	#$53 
	bne  	UPDATE_SCREEN_LO_RES_GFX_NO_TEXT
	ldy  	,U++
	stu  	<appleRowPtr 
	tfr   	W,U  		; for the text stuff, change to using U as coco vram ptr 
UPDATE_SCREEN_LO_RES_GFX_NEXT_TEXT_ROW
	lda  	#40
	sta  	<columnCounter
UPDATE_SCREEN_LO_RES_GFX_NEXT_CHAR
	ldb  	,Y
	andb  	#%00111111
	clra 
	lsld 
	lsld 
	lsld 
	addd  	#fontBitmap
	tst  	,Y+
	bmi  	UPDATE_SCREEN_LO_RES_GFX_NOT_INVERTED
	addd  	#$0200  	; add offset to inverted font bitmap
UPDATE_SCREEN_LO_RES_GFX_NOT_INVERTED
	tfr  	D,X  
	sty  	<charPtr
	ldy 	#loResGfxTextTable

	ldb  	,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	,U 

	ldb  	1,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*1),U

	ldb  	2,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*2),U

	ldb  	3,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*3),U

	ldb  	4,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*4),U

	ldb  	5,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*5),U

	ldb  	6,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*6),U

	ldb  	7,X
	clra 
	lsld 
	lsld 
	ldq  	D,Y
	stq  	(160*7),U

	ldy   	<charPtr 
	leau  	4,U 
	dec  	<columnCounter
	lbne  	UPDATE_SCREEN_LO_RES_GFX_NEXT_CHAR
	leau  	(160*7),U 
	ldw  	<appleRowPtr 
	ldy  	,W++
	beq   	UPDATE_SCREEN_LO_RES_GFX_DONE
	stw  	<appleRowPtr
	lbra  	UPDATE_SCREEN_LO_RES_GFX_NEXT_TEXT_ROW
UPDATE_SCREEN_LO_RES_GFX_DONE
	; restore original MMU state
	lda  	#$38
	sta  	>mmu_bank0
	ldq  	#$3B3C3D3E
	stq  	>mmu_bank3

	pulsw
	puls  	D,X,DP,Y,U,PC 

; ---------------------------------------------------------------------
SCREEN_GFX_CLEAR
	pshs  	Y,X,D
	pshsw 

	ldq  	#$10111213
	stq  	>mmu_bank3 

	ldx  	#$6000
	ldy  	#zeroByte
	ldw  	#$7800
	tfm  	Y,X+

	ldq  	#$3B3C3D3E
	stq  	>mmu_bank3

	pulsw 
	puls  	D,X,Y,PC 	

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

