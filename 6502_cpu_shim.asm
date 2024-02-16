**********************************************************************
* Apple2Coco v1.0
* Written by Todd Wallace
*
* My Links:
* https://www.youtube.com/@tekdragon
* https://github.com/dragonbytes
* https://tektodd.com
**********************************************************************
* The shim below handles all of the actual writes/reads to/from the
* 6502 memory space as well as reacting to hardware I/O registers/ports
**********************************************************************

CPU_6502_VARS
; 6502 Registers
cpu6502RegA 		RMB  	1
cpu6502RegX  		RMB  	1
cpu6502RegY  		RMB  	1
cpu6502RegSP 		RMB  	1
cpu6502RegPC		RMB  	2
cpu6502RegStatus 	RMB 	1
cpu6502CycleCounter 	RMB 	2
tempWord  		RMB 	2

; Apple II HW IO Variables
apple2keyStatus	RMB  	1
apple2spkrCounter 	FCB  	120
vidRefreshCounter  	FCB 	2
vidRefreshFlag  	FCB  	0
apple2videoUpdatePtr RMB  	2
apple2videoMode  	FCB  	$50  	; default for lo-res text-only mode
 IFDEF debugger_enabled
debugScreenToggle  	FCB  	0
 ENDC

; -------------------------------------------------------------------------------------------
; read_op_byte calls return the result in F so it can eventually can get used in an indexed operation
; Entry: X = current 6502 program counter
; Exit: F or B = read op byte
; -------------------------------------------------------------------------------------------
CPU_READ_OP_BYTE_INTO_F_INC
	ldf  	#1
	stf  	>$FF91 
	cmpx  	#$E000 
	blo  	CPU_READ_OP_BYTE_INTO_F_INC_NO_SHIM_CONFLICT
	stf  	>mmu_bank8
	ldf  	$2000,X
	leax  	1,X    	
	clr  	>mmu_bank8
	clr  	>$FF91 
	rts 
CPU_READ_OP_BYTE_INTO_F_INC_NO_SHIM_CONFLICT
	ldf  	,X+
	clr  	>$FF91 
	rts 

CPU_READ_OP_BYTE_INTO_B_INC
	ldb  	#1
	stb  	>$FF91 
	cmpx  	#$E000 
	blo  	CPU_READ_OP_BYTE_INTO_B_INC_NO_SHIM_CONFLICT
	stb  	>mmu_bank8
	ldb  	$2000,X
	leax  	1,X 
	clr  	>mmu_bank8
	clr  	>$FF91    	
	rts 
CPU_READ_OP_BYTE_INTO_B_INC_NO_SHIM_CONFLICT
	ldb  	,X+
	clr  	>$FF91    	
	rts 

; -------------------------------------------------------------------------------------------
; read_data_byte calls return the result in B so it can eventually can get used in final operation
; Entry: W = address to read from
; Exit: B = read data byte
; -------------------------------------------------------------------------------------------
CPU_READ_DATA_BYTE_INTO_B
	cmpe  	#$C0 
	bne  	CPU_READ_DATA_BYTE_INTO_B_NOT_IO
	tstf 
	beq  	CPU_READ_DATA_BYTE_INTO_B_RETURN_KEYPRESS
	cmpf  	#$10
	bne  	CPU_READ_DATA_BYTE_INTO_B_CHECK_SPKR
	; program is clearing the keyboard strobe flag
	aim  	#%01111111;<apple2keyStatus
	rts
CPU_READ_DATA_BYTE_INTO_B_RETURN_KEYPRESS
	; program is reading $C000 for valid keystroke
	ldb  	<apple2keyStatus
	rts  
CPU_READ_DATA_BYTE_INTO_B_CHECK_SPKR
	cmpf 	#$30
	bne   	CPU_READ_DATA_BYTE_INTO_B_CHECK_VID_MIXED
	ldb  	<apple2spkrCounter
	bne  	CPU_READ_DATA_BYTE_INTO_B_EXIT
	; beep the speaker
	jsr  	[bell_char_ptr]
	; reset counter to wait another 15 VSYNC intervals (1/2 of a second) before permitting another beep
	ldb  	#120 	
	stb  	<apple2spkrCounter
	rts 
CPU_READ_DATA_BYTE_INTO_B_CHECK_VID_MIXED
	cmpf  	#$53
	bne  	CPU_READ_DATA_BYTE_INTO_B_CHECK_VID_TEXT
	; if here, set video mode for mixed lo-res gfx and 4 rows of text on bottom 
	stf  	<apple2videoMode
	; change coco3 video mode to 16 colors on 320x192
	ldb 	#%00011110
	stb 	>gime_vres
	ldb  	#33
	stb  	>gime_palette1
	ldb  	>apple2_lores_gfx_update
	stb  	<apple2videoUpdatePtr
	ldb  	>apple2_lores_gfx_update+1
	stb  	<apple2videoUpdatePtr+1
	rts 
CPU_READ_DATA_BYTE_INTO_B_CHECK_VID_TEXT
	cmpf  	#$51 
	bne  	CPU_READ_DATA_BYTE_INTO_B_CHECK_FLOPPY_READ
	ldb 	#%00001100
	stb 	>gime_vres
	ldb  	#16 		; white text 
	stb  	>gime_palette1
	ldb  	>apple2_lores_text_update
	stb  	<apple2videoUpdatePtr
	ldb  	>apple2_lores_text_update+1
	stb  	<apple2videoUpdatePtr+1
	rts 	
CPU_READ_DATA_BYTE_INTO_B_CHECK_FLOPPY_READ
	;cmpf  	#$8C 
	;bne  	CPU_READ_DATA_BYTE_INTO_B_UNSUPPORTED_IO
	; if here, code is trying to read some kind of byte from the floppy interface 
	;ldb  	<floppyReadH	

CPU_READ_DATA_BYTE_INTO_B_UNSUPPORTED_IO
	rts
CPU_READ_DATA_BYTE_INTO_B_NOT_IO	
	ldb  	#1
	stb  	>$FF91 
	cmpe  	#$E0
	blo  	CPU_READ_DATA_BYTE_INTO_B_NO_SHIM_CONFLICT
	stb  	>mmu_bank8
	ldb  	$2000,W   
	clr  	>mmu_bank8
	clr 	>$FF91	
	rts 
CPU_READ_DATA_BYTE_INTO_B_NO_SHIM_CONFLICT
	ldb  	,W
	clr 	>$FF91	
CPU_READ_DATA_BYTE_INTO_B_EXIT
	rts 

; --------------------------------------------------------------------------------------------
; read a full data word from address pointed to by X and increment X by 2
; Entry: X = ptr to 6502 memory to read little-endian word
; Exit: W = result converted to big-endian
; --------------------------------------------------------------------------------------------
CPU_READ_WORD_FROM_X_INC 
	ldf  	#1
	stf  	>$FF91 
	cmpx  	#$DFFF 
	blo  	CPU_READ_WORD_FROM_X_INC_NO_SHIM_CONFLICT
	bhi  	CPU_READ_WORD_FROM_X_INC_SHIM_CONFLICT
	; if here, current address if exactly #$DFFF 
	stf  	>mmu_bank8
	lde  	>$0000
	clr  	>mmu_bank8
	ldf  	,X++ 
	clr  	>$FF91 
	rts 

CPU_READ_WORD_FROM_X_INC_SHIM_CONFLICT
	cmpx 	#$FFFF   	
	bne  	CPU_READ_WORD_FROM_X_INC_SHIM_CONFLICT_NO_WRAP
	; if here, the 6502 address will roll over into $0000 for next byte
	stf  	>mmu_bank8
	ldf  	>$1FFF  	; this is equivalent to $FFFF (last byte of 512 reserved area)
	clr  	>mmu_bank8 
	lde  	$0000
	leax  	2,X 
	clr 	>$FF91	
	rts 

CPU_READ_WORD_FROM_X_INC_SHIM_CONFLICT_NO_WRAP
	stf  	>mmu_bank8
	ldw  	$2000,X 
	exg  	E,F  
	leax  	2,X 
	clr  	>mmu_bank8
	clr  	>$FF91 
	rts  

CPU_READ_WORD_FROM_X_INC_NO_SHIM_CONFLICT
	ldw 	,X++
	exg  	E,F 
	clr  	>$FF91 
	rts   

; ------------------------------------------------------------------------------------------
; read_data_byte calls return the result in A so it can eventually can get used in final operation
; this variant does not check IO addresses. only CPU_READ_DATA_BYTE_INTO_B does that
; Entry: W = address to read from
; Exit: A = read data byte
; -------------------------------------------------------------------------------------------
CPU_READ_DATA_BYTE_INTO_A
	lda  	#1
	sta  	>$FF91 
	cmpe  	#$E0
	blo  	CPU_READ_DATA_BYTE_INTO_A_NO_SHIM_CONFLICT
	sta  	>mmu_bank8
	lda  	$2000,W
	clr  	>mmu_bank8  
	clr  	>$FF91 	
	rts 
CPU_READ_DATA_BYTE_INTO_A_NO_SHIM_CONFLICT
	lda  	,W
	clr 	>$FF91	
	rts 

; --------------------------------------------------------------------------------------------
; cpu_write_byte calls expect source byte in B 
; Entry: W = destination 6502 address
; --------------------------------------------------------------------------------------------
CPU_WRITE_BYTE
	;cmpw  	#$F001 
	;bne  	CPU_WRITE_BYTE_NOT_KOWALSKI_SIM
	;tfr  	B,A 
	;jsr  	[print_char_ptr]
	;rts 

;CPU_WRITE_BYTE_NOT_KOWALSKI_SIM
	lda  	#1
	sta  	>$FF91 
	cmpe  	#$E0
	blo  	CPU_WRITE_BYTE_NO_SHIM_CONFLICT
	sta  	>mmu_bank8
	stb  	$2000,W 
	clr  	>mmu_bank8
	clr  	>$FF91   	
	rts 
CPU_WRITE_BYTE_NO_SHIM_CONFLICT
	cmpe  	#$04
	blo   	CPU_WRITE_BYTE_NO_SHIM_CONFLICT_NOT_VRAM
	cmpe  	#$08
	bhs  	CPU_WRITE_BYTE_NO_SHIM_CONFLICT_NOT_VRAM
	; if here, something is writing to vram. set flag to request video update
	ste  	<vidRefreshFlag
CPU_WRITE_BYTE_NO_SHIM_CONFLICT_NOT_VRAM
	stb  	,W
	clr 	>$FF91	
	rts 

; --------------------------------------------------------------------------------------------
; Entry: D = word to push on stack
; --------------------------------------------------------------------------------------------
CPU_PUSH_WORD
	ldf  	#1
	stf  	>$FF91 
	ldf  	<cpu6502RegSP
	lde  	#$01 
	sta  	,W
	decf 
	stb  	,W 
	decf 
	stf  	<cpu6502RegSP
	clr 	>$FF91	
	rts 

; --------------------------------------------------------------------------------------------
; Exit: D = word pulled from stack
; --------------------------------------------------------------------------------------------
CPU_PULL_WORD
	ldf  	#1
	stf  	>$FF91 
	ldf  	<cpu6502RegSP
	lde  	#$01 
	incf
	ldb  	,W
	incf 
	lda  	1,W 
	stf  	<cpu6502RegSP
	clr 	>$FF91	
	rts 

; ------------------------------------------------------------------
; for debugging/testing
; ------------------------------------------------------------------
;PRINT_DATA
;	; swap 6502 address space into ram for debugging
;	lda  	#1
;	sta 	>$FF91 
;PRINT_DATA_LOOP
;	bra  	PRINT_DATA_LOOP