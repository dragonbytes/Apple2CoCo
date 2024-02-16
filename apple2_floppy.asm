
diskOpCode 	EQU  	$00EA
diskTrack  	EQU 	$00EC	
diskSector  	EQU  	$00ED
diskDataPtr 	EQU  	$00EE
diskStatus  	EQU 	$00F0

; ----------------------------------------------------------------------
DSKCON_READ_SECTOR
	pshs  	A,DP

	; swap BASIC routines in
	ldb  	#$3F 
	stb  	>mmu_bank7
	clrb 
	tfr  	B,DP

	sta   	>coco3_slow  	; put coco3 into slow mode for DECB disk access
	clr  	>diskStatus 	; init this to 0 so we can tell if a disk error happened afterwards
	; track and sector values will already be set in calling routines
	lda  	#$02 		; 2 = Read sector operation
	sta  	>diskOpCode
	ldd  	#sectorBuffer
	std  	>diskDataPtr
	jsr  	[DSKCON] 	; execute DSKCON command

	; restore custom blocks to MMU
	ldb  	#code_mmu_blk
	stb  	>mmu_bank7

	sta  	>coco3_fast 	; restore coco3 into fast mode 
	
	ldb  	>diskStatus

	puls  	DP,A,PC 