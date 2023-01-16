
********************************************************************************
* This ROM loader expects to load from a custom-made disk where the APPLE II
* ROM starts at Track 24 Sector 1 and continues contiguously until Track 28 
* Sector 8 which is the final sector. This was just a quick and dirty way to
* conviently put the apple rom into coco RAM. Someday i'd like to read it off
* an actual DECB filesystem instead. It's nice to have goals in life :-P
********************************************************************************

payload_dest 	EQU  	$E000
mmu_bank7 	EQU 	$FFA7
mmu_bank15  	EQU  	$FFAF

diskOpCode 	EQU  	$00EA
diskTrack  	EQU 	$00EC	
diskSector  	EQU  	$00ED
diskDataPtr 	EQU  	$00EE
diskStatus  	EQU 	$00F0
DSKCON  	EQU  	$C004

code_mmu_blk 	EQU  	$08

	pragma 6309
	org 	$2800

; ------------------------------------------------------------------
DISK_READ_SECTOR
	pshs  	U,Y,X,D

	; track and sector values will already be set in calling routines
	lda  	#$02 		; 2 = Read sector operation
	sta  	>diskOpCode
	jsr  	[DSKCON] 	; execute DSKCON command
	orcc  	#$50

	puls  	D,X,Y,U,PC 

; -----------------------------------------------------------------
LOAD_TEST_ROM
	;pshs  	Y,X,D 
	pshs  	U,Y,X,DP,D,CC

	clra 
	tfr  	A,DP 

	ldy  	#cpu6502mmuMap+5 	; only need the last 3 mmu pages
	lda  	#24  		; apple II rom starts at track 24
	sta  	>diskTrack  

	ldb  	#1 		; start at sector 1
	lda  	,Y+
	sta  	>$FFA2
	adda 	#$30
	sta  	>$0400
	ldx  	#$5000 		; in 6502 address space, this is $B000 since $4000 on coco is $A000 on 6502
LOAD_TEST_ROM_NEXT_SECTOR
	stb  	>diskSector
	stx  	>diskDataPtr
	jsr  	DISK_READ_SECTOR
	leax  	256,X 
	cmpx  	#$6000
	blo  	LOAD_TEST_ROM_INCREMENT_SECTOR
	; if here, we need a new page
	lda  	,Y+
	sta 	>$FFA2
	adda 	#$30
	sta  	>$0400
	ldx  	#$4000
LOAD_TEST_ROM_INCREMENT_SECTOR
	; check if we just copied Sector 8 from Track 28, which is the final sector of ROM
	cmpb  	#8 
	bne  	LOAD_TEST_ROM_INCREMENT_SECTOR_NOT_FINAL_SECTOR_NUMBER
	lda  	>diskTrack
	cmpa  	#28
	beq   	LOAD_TEST_ROM_DONE
LOAD_TEST_ROM_INCREMENT_SECTOR_NOT_FINAL_SECTOR_NUMBER
	incb 
	cmpb  	#18
	bls  	LOAD_TEST_ROM_NEXT_SECTOR
	ldb  	#1 	; reset sector to 1
	inc  	>diskTrack 		; advance to next track
	bra  	LOAD_TEST_ROM_NEXT_SECTOR
	
LOAD_TEST_ROM_DONE
	;puls  	D,X,Y,PC 
	puls  	CC,D,DP,X,Y,U,PC 
	
	*************************************************************************************************

START
	orcc  	#$50

	; DO NOT ACTIVATE 6309 NATIVE MODE BEFORE THIS. DISK ACCESS WILL CRASH THE MACHINE
	jsr  	LOAD_TEST_ROM

	clr     >$FF40 		; turn off the floppy motor

	rts 

cpu6502mmuMap 	FCB  	$00,$02,$03,$04,$05,$06,$07,$01 ; skip $01 since its our special buffer for >$E000
mmuRemapAfterBASIC 	FCB  	$00,$02,$03,$04,$05,$06,$07,code_mmu_blk
totalPages  		FCB  	$00
tempByte  		FCB  	$00
*******************************************************************

	END 	START

