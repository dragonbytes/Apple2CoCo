**********************************************************************
* Apple2Coco v1.0
* Written by Todd Wallace
*
* My Links:
* https://www.youtube.com/@tekdragon
* https://github.com/dragonbytes
* https://tektodd.com
**********************************************************************
* ROM loading/disk routines
**********************************************************************
progress_bar_char 		EQU  	$AF
progress_bar_interval  	EQU  	3

	include 	decbfs.asm
; ------------------------------------------------------------------
DISK_READ_SECTOR
	pshs  	U,Y,X,DP,D

	; restore DP to normal BASIC state of $00 and put coco3 in slow clock mode
	; since track seeking breaks sometimes in high-speed mode
	clra 
	tfr  	A,DP 
	sta  	>coco3_slow
	; track and sector values will already be set in calling routines
	lda  	#$02 		; 2 = Read sector operation
	sta  	>diskOpCode
	jsr  	[DSKCON] 	; execute DSKCON command
	orcc  	#$50
	sta  	>coco3_fast

	puls  	D,DP,X,Y,U,PC 
	
; -------------------------------------------------------------------------------
LOAD_APPLE_ROM
	pshs  	U,Y,X,DP,D

	lda  	#progress_bar_interval
	sta  	romProgessCounter
	lda  	#progress_bar_char  		; progress character
	jsr  	PRINT_CHAR
	; init a few needed disk routine variables first
	lda  	#$FF
	sta  	decbFileSectorRem
	sta  	decbFileCurSector
	ldd 	14,U
	std  	decbFileRemBytes 	; save number of bytes remaining on last sector
	lda  	13,U  			; grab filename entry byte containing first granule of file
	sta  	decbFileNextGran

	ldu  	#cpu6502mmuMap+5 	; only need the last 3 mmu pages
	ldb  	#3
	lda  	,U+
	sta  	curDiskMMUblock
	sta  	>$FFA3
	; start at $7000 since ROM file actually starts at $B000 on the Apple II (middle of a 8k page)
	ldx  	#$7000 
	ldy  	#decbGranMap
LOAD_APPLE_ROM_NEXT_SECTOR
	stx  	>diskDataPtr
	jsr  	DECB_GET_NEXT_SECTOR_IN_FILE
	bcs  	LOAD_APPLE_ROM_ERROR_SIZE  	; we ran out of sectors prematurely so file is wrong size
	jsr  	DISK_READ_SECTOR
	dec  	romProgessCounter
	bne  	LOAD_APPLE_ROM_SKIP_PROGRESS_BLOCK
	; if here, time to display another progress block character
	lda  	#progress_bar_char
	;jsr  	[$A002]
	jsr  	PRINT_CHAR
	; after each BASIC print char, we need to manually map our disk mmu block back in since BASIC clobbers it
	lda  	curDiskMMUblock
	sta  	>$FFA3
	lda  	#progress_bar_interval
	sta  	romProgessCounter
LOAD_APPLE_ROM_SKIP_PROGRESS_BLOCK
	leax  	256,X
	cmpx  	#$8000
	blo  	LOAD_APPLE_ROM_NEXT_SECTOR
	decb
	beq  	LOAD_APPLE_ROM_CHECK_SIZE
	; if here, we need a new MMU page swapped into memory
	lda  	,U+
	sta  	curDiskMMUblock
	sta  	>$FFA3
	ldx  	#$6000
	bra   	LOAD_APPLE_ROM_NEXT_SECTOR

LOAD_APPLE_ROM_CHECK_SIZE
	cmpx  	#$8000  	; for the correct ROM (20,480 bytes) we should end exactly at $8000 in ram
	bne  	LOAD_APPLE_ROM_ERROR_SIZE
	; if there are still sectors left in file, than its larger than expected 20,480 bytes and wrong size
	lda  	decbFileSectorRem  	
	bne  	LOAD_APPLE_ROM_ERROR_SIZE
LOAD_APPLE_ROM_DONE
	; restore stock BASIC mmu block value
	lda  	#$3B
	sta  	>$FFA3
	clr  	>$FF40 		; turn off the floppy motor
	clra  				; cleared carry flag means successfully loaded
	puls  	D,DP,X,Y,U,PC

LOAD_APPLE_ROM_ERROR_SIZE
	; restore stock BASIC mmu block value
	lda  	#$3B
	sta  	>$FFA3
	clr  	>$FF40 		; turn off the floppy motor
	orcc  	#1
	puls  	D,DP,X,Y,U,PC

*******************************************************************


