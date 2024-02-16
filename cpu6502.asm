**********************************************************************
* Apple2Coco v1.0
* Written by Todd Wallace
*
* My Links:
* https://www.youtube.com/@tekdragon
* https://github.com/dragonbytes
* https://tektodd.com
**********************************************************************
* This file contains the core 6502 CPU emulation which also governs
* the sort-of "mainloop" of the entire Apple II+ emulation. I chose
* to put this all at $E000 so that I could use all 7 of the remaining
* 8k MMU blocks in GIME Task 1 for the 6502 address space.
**********************************************************************
	pragma		6309
	opt  		c
	opt  		cd 
	opt  		ct

cpu_nmi_vector 		EQU  	$FFFA  
cpu_reset_vector 		EQU  	$FFFC 	
cpu_irq_brk_vector 		EQU 	$FFFE

cpu_status_N_flag 		EQU  	%10000000
cpu_status_V_flag 		EQU  	%01000000
cpu_status_reserved		EQU  	%00100000
cpu_status_B_flag  		EQU  	%00010000
cpu_status_D_flag 		EQU  	%00001000
cpu_status_I_flag  		EQU  	%00000100
cpu_status_Z_flag  		EQU  	%00000010
cpu_status_C_flag 		EQU 	%00000001
cpu_status_N_flag_inverted	EQU  	%01111111
cpu_status_V_flag_inverted	EQU  	%10111111
cpu_status_B_flag_inverted	EQU  	%11101111
cpu_status_D_flag_inverted	EQU  	%11110111
cpu_status_I_flag_inverted	EQU  	%11111011
cpu_status_Z_flag_inverted	EQU  	%11111101
cpu_status_C_flag_inverted	EQU 	%11111110

mmu_bank0  			EQU  	$FFA0
mmu_bank3   			EQU  	$FFA3
mmu_bank8  			EQU 	$FFA8
gime_palette1 		EQU 	$FFB1

coco3_fast  			EQU  	$FFD9
gime_init0 			EQU 	$FF90 
gime_init1 			EQU 	$FF91
gime_vmode 			EQU 	$FF98
gime_vres 			EQU 	$FF99
bell_char_ptr  		EQU  	$2800
get_char_ptr  		EQU  	$2802
apple2_lores_text_update	EQU  	$2804
apple2_lores_gfx_update  	EQU  	$2806

;debugger_enabled   		EQU  	1
*******************************************************************************************************
	FDB  		START 	; first 2 bytes of this assembled program is pointer to executation address
	
	org 		$E000
	setdp  	$E0  	; BEGINNING OF DP ADDRESS SPACE (should be $E000)
	; The shim below handles all of the actual writes/reads to/from the 6502 memory space
	; as well as reacting to hardware I/O registers/ports
	include 	6502_cpu_shim.asm 
*******************************************************************************************************
; Variables/constants area
origStackPtr  	RMB  	2
currentStackPtr 	RMB  	2
originalDP 		RMB  	1

cpu6502mmuMap 	FCB  	$00,$02,$03,$04,$05,$06,$07 ; skip $01 since its our special buffer for >$E000

opcodeJumpTable  	FDB 	7,ADDRESS_MODE_IMP,OPERATION_BRK,DEBUG_DISASM_IMP		; $00 (7 cycles)
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_ORA,DEBUG_DISASM_IND_X		; $01 indirect X (6 cycles)
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP			; $02 HALTs CPU (the data bus will be set to #$FF)
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_SLO_IND_X,DEBUG_DISASM_IND_X	; $03 indirect X (8 cycles)
			FDB 	3,ADDRESS_MODE_ZP,ILLEGAL_NOP_ZP,DEBUG_DISASM_ZP			; $04 (illegal) (3 cycles)
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_ORA,DEBUG_DISASM_ZP			; $05 zero-page  (3 cycles)
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_ASL,DEBUG_DISASM_ZP			; $06 zero-page (5 cycles)
			FDB  	5,ADDRESS_MODE_ZP,ILLEGAL_SLO_ZP,DEBUG_DISASM_ZP			; $07 (illegal) zero-page (5 cycles)
			FDB  	3,ADDRESS_MODE_IMP,OPERATION_PHP,DEBUG_DISASM_IMP		; $08 implied (3 cycles)
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_ORA_SKIP_READ,DEBUG_DISASM_IMM	; $09 immediate (2 cycles)
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_ASL_IMP,DEBUG_DISASM_ACC  		; $0A implied (2 cycles)
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_ANC_IMM,DEBUG_DISASM_IMM  		; $0B 2 cycles this command performs an AND operation only, but bit 7 is put into the carry, as if the ASL/ROL would have been executed.
			FDB  	4,ADDRESS_MODE_ABS,ILLEGAL_NOP_ABS,DEBUG_DISASM_ABS  		; $0C 4 cycles
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_ORA,DEBUG_DISASM_ABS		; $0D 4 cycles
			FDB  	6,ADDRESS_MODE_ABS,OPERATION_ASL,DEBUG_DISASM_ABS		; $0E 6 cycles
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_SLO_ABS,DEBUG_DISASM_ABS		; $0F 6 cycles

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BPL,DEBUG_DISASM_REL		; $10 2 cycles +1 if branch succeeds +2 if to a new page
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_ORA,DEBUG_DISASM_IND_Y	; $11 
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $12
			FDB 	8,ADDRESS_MODE_IND_Y,ILLEGAL_SLO_IND_Y,DEBUG_DISASM_IND_Y 	; $13
			FDB 	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X  	; $14
			FDB 	4,ADDRESS_MODE_ZP_X,OPERATION_ORA,DEBUG_DISASM_ZP_X  		; $15
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_ASL,DEBUG_DISASM_ZP_X  		; $16
			FDB 	6,ADDRESS_MODE_ZP_X,ILLEGAL_SLO_ZP_X,DEBUG_DISASM_ZP_X  	; $17
			FDB 	2,ADDRESS_MODE_IMP,OPERATION_CLC,DEBUG_DISASM_IMP		; $18
			FDB 	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_ORA,DEBUG_DISASM_ABS_Y 	; $19
			FDB 	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP 			; $1A
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_SLO_ABS_Y,DEBUG_DISASM_ABS_Y 	; $1B
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $1C
			FDB 	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_ORA,DEBUG_DISASM_ABS_X	; $1D
			FDB 	7,ADDRESS_MODE_ABS_X,OPERATION_ASL,DEBUG_DISASM_ABS_X		; $1E
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_SLO_ABS_X,DEBUG_DISASM_ABS_X  	; $1F

			FDB 	6,ADDRESS_MODE_ABS,OPERATION_JSR,DEBUG_DISASM_ABS  		; $20
			FDB 	6,ADDRESS_MODE_IND_X,OPERATION_AND,DEBUG_DISASM_IND_X 		; $21
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP  		; $22
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_RLA_IND_X,DEBUG_DISASM_IND_X  	; $23
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_BIT,DEBUG_DISASM_ZP  		; $24
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_AND,DEBUG_DISASM_ZP			; $25
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_ROL,DEBUG_DISASM_ZP 			; $26
			FDB  	5,ADDRESS_MODE_ZP,ILLEGAL_RLA_ZP,DEBUG_DISASM_ZP  		; $27
			FDB  	4,ADDRESS_MODE_IMP,OPERATION_PLP,DEBUG_DISASM_IMP  		; $28
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_AND_SKIP_READ,DEBUG_DISASM_IMM 	; $29
			FDB 	2,ADDRESS_MODE_IMP,OPERATION_ROL_IMP,DEBUG_DISASM_ACC 		; $2A
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_ANC_IMM,DEBUG_DISASM_IMM  		; $2B
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_BIT,DEBUG_DISASM_ABS  		; $2C
			FDB 	4,ADDRESS_MODE_ABS,OPERATION_AND,DEBUG_DISASM_ABS 		; $2D
			FDB  	6,ADDRESS_MODE_ABS,OPERATION_ROL,DEBUG_DISASM_ABS  		; $2E
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_RLA_ABS,DEBUG_DISASM_ABS  		; $2F

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BMI,DEBUG_DISASM_REL  		; $30
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_AND,DEBUG_DISASM_IND_Y 	; $31
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $32
			FDB  	8,ADDRESS_MODE_IND_Y,ILLEGAL_RLA_IND_Y,DEBUG_DISASM_IND_Y 	; $33
			FDB  	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X 		; $34
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_AND,DEBUG_DISASM_ZP_X  		; $35
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_ROL,DEBUG_DISASM_ZP_X 		; $36
			FDB  	6,ADDRESS_MODE_ZP_X,ILLEGAL_RLA_ZP_X,DEBUG_DISASM_ZP_X 		; $37
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_SEC,DEBUG_DISASM_IMP  		; $38
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_AND,DEBUG_DISASM_ABS_Y 	; $39
			FDB  	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP  		; $3A
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_RLA_ABS_Y,DEBUG_DISASM_ABS_Y  	; $3B
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $3C
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_AND,DEBUG_DISASM_ABS_X 	; $3D
			FDB  	7,ADDRESS_MODE_ABS_X,OPERATION_ROL,DEBUG_DISASM_ABS_X  		; $3E
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_RLA_ABS_X,DEBUG_DISASM_ABS_X 	; $3F

			FDB  	6,ADDRESS_MODE_IMP,OPERATION_RTI,DEBUG_DISASM_IMP  		; $40
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_EOR,DEBUG_DISASM_IND_X  		; $41
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $42  	
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_SRE_IND_X,DEBUG_DISASM_IND_X 	; $43
			FDB  	3,ADDRESS_MODE_ZP,ILLEGAL_NOP_ZP,DEBUG_DISASM_ZP 		; $44
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_EOR,DEBUG_DISASM_ZP  		; $45
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_LSR,DEBUG_DISASM_ZP  		; $46
			FDB  	5,ADDRESS_MODE_ZP,ILLEGAL_SRE_ZP,DEBUG_DISASM_ZP 		; $47
			FDB  	3,ADDRESS_MODE_IMP,OPERATION_PHA,DEBUG_DISASM_IMP  		; $48
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_EOR_SKIP_READ,DEBUG_DISASM_IMM 	; $49
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_LSR_IMP,DEBUG_DISASM_ACC  		; $4A
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_ALR_IMM,DEBUG_DISASM_IMM 		; $4B
			FDB  	3,ADDRESS_MODE_ABS,OPERATION_JMP,DEBUG_DISASM_ABS 		; $4C
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_EOR,DEBUG_DISASM_ABS  		; $4D
			FDB  	6,ADDRESS_MODE_ABS,OPERATION_LSR,DEBUG_DISASM_ABS  		; $4E
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_SRE_ABS,DEBUG_DISASM_ABS 		; $4F

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BVC,DEBUG_DISASM_REL 		; $50
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_EOR,DEBUG_DISASM_IND_Y 	; $51
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $52
			FDB  	8,ADDRESS_MODE_IND_Y,ILLEGAL_SRE_IND_Y,DEBUG_DISASM_IND_Y 	; $53
			FDB  	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X 		; $54
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_EOR,DEBUG_DISASM_ZP_X  		; $55
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_LSR,DEBUG_DISASM_ZP_X  		; $56
			FDB  	6,ADDRESS_MODE_ZP_X,ILLEGAL_SRE_ZP_X,DEBUG_DISASM_ZP_X 		; $57
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_CLI,DEBUG_DISASM_IMP 		; $58
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_EOR,DEBUG_DISASM_ABS_Y 	; $59
			FDB  	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP  		; $5A
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_SRE_ABS_Y,DEBUG_DISASM_ABS_Y 	; $5B
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $5C
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_EOR,DEBUG_DISASM_ABS_X 	; $5D
			FDB  	7,ADDRESS_MODE_ABS_X,OPERATION_LSR,DEBUG_DISASM_ABS_X  		; $5E
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_SRE_ABS_X,DEBUG_DISASM_ABS_X  	; $5F

			FDB  	6,ADDRESS_MODE_IMP,OPERATION_RTS,DEBUG_DISASM_IMP 		; $60
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_ADC,DEBUG_DISASM_IND_X 		; $61
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $62
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_RRA_IND_X,DEBUG_DISASM_IND_X 	; $63
			FDB  	3,ADDRESS_MODE_ZP,ILLEGAL_NOP_ZP,DEBUG_DISASM_ZP 		; $64
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_ADC,DEBUG_DISASM_ZP  		; $65
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_ROR,DEBUG_DISASM_ZP 			; $66
			FDB  	5,ADDRESS_MODE_ZP,ILLEGAL_RRA_ZP,DEBUG_DISASM_ZP 		; $67
			FDB  	4,ADDRESS_MODE_IMP,OPERATION_PLA,DEBUG_DISASM_IMP  		; $68
			FDB 	2,ADDRESS_MODE_IMM,OPERATION_ADC_SKIP_READ,DEBUG_DISASM_IMM 	; $69
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_ROR_IMP,DEBUG_DISASM_ACC 		; $6A
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_ARR_IMM,DEBUG_DISASM_IMM 		; $6B
			FDB  	5,ADDRESS_MODE_INDIRECT,OPERATION_JMP,DEBUG_DISASM_INDIRECT  	; $6C
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_ADC,DEBUG_DISASM_ABS  		; $6D
			FDB 	6,ADDRESS_MODE_ABS,OPERATION_ROR,DEBUG_DISASM_ABS  		; $6E
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_RRA_ABS,DEBUG_DISASM_ABS  		; $6F

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BVS,DEBUG_DISASM_REL  		; $70
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_ADC,DEBUG_DISASM_IND_Y 	; $71
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $72
			FDB  	8,ADDRESS_MODE_IND_Y,ILLEGAL_RRA_IND_Y,DEBUG_DISASM_IND_Y  	; $73
			FDB  	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X  	; $74
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_ADC,DEBUG_DISASM_ZP_X  		; $75
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_ROR,DEBUG_DISASM_ZP_X 		; $76
			FDB  	6,ADDRESS_MODE_ZP_X,ILLEGAL_RRA_ZP_X,DEBUG_DISASM_ZP_X 		; $77
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_SEI,DEBUG_DISASM_IMP  		; $78
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_ADC,DEBUG_DISASM_ABS_Y 	; $79
			FDB  	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP  		; $7A
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_RRA_ABS_Y,DEBUG_DISASM_ABS_Y 	; $7B
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $7C
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_ADC,DEBUG_DISASM_ABS_X	; $7D
			FDB  	7,ADDRESS_MODE_ABS_X,OPERATION_ROR,DEBUG_DISASM_ABS_X 		; $7E
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_RRA_ABS_X,DEBUG_DISASM_ABS_X	; $7F

			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_NOP_IMM,DEBUG_DISASM_IMM		; $80
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_STA,DEBUG_DISASM_IND_X 		; $81
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_NOP_IMM,DEBUG_DISASM_IMM 		; $82
			FDB  	6,ADDRESS_MODE_IND_X,ILLEGAL_SAX_IND_X,DEBUG_DISASM_IND_X	; $83
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_STY,DEBUG_DISASM_ZP			; $84
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_STA,DEBUG_DISASM_ZP			; $85
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_STX,DEBUG_DISASM_ZP			; $86
			FDB  	3,ADDRESS_MODE_ZP,ILLEGAL_SAX_ZP,DEBUG_DISASM_ZP 		; $87
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_DEY,DEBUG_DISASM_IMP		; $88
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_NOP_IMM,DEBUG_DISASM_IMM  		; $89
			FDB   	2,ADDRESS_MODE_IMP,OPERATION_TXA,DEBUG_DISASM_IMP 		; $8A
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_XAA_IMM,DEBUG_DISASM_IMM 		; $8B
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_STY,DEBUG_DISASM_ABS 		; $8C
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_STA,DEBUG_DISASM_ABS  		; $8D
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_STX,DEBUG_DISASM_ABS  		; $8E
			FDB  	4,ADDRESS_MODE_ABS,ILLEGAL_SAX_ABS,DEBUG_DISASM_ABS		; $8F

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BCC,DEBUG_DISASM_REL  		; $90
			FDB  	6,ADDRESS_MODE_IND_Y,OPERATION_STA,DEBUG_DISASM_IND_Y 		; $91
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP  		; $92
			FDB  	6,ADDRESS_MODE_IND_Y,ILLEGAL_AHX_IND_Y,DEBUG_DISASM_IND_Y 	; $93
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_STY,DEBUG_DISASM_ZP_X  		; $94
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_STA,DEBUG_DISASM_ZP_X  		; $95
			FDB  	4,ADDRESS_MODE_ZP_Y,OPERATION_STX,DEBUG_DISASM_ZP_Y 		; $96
			FDB 	4,ADDRESS_MODE_ZP_Y,ILLEGAL_SAX_ZP_Y,DEBUG_DISASM_ZP_Y  	; $97
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_TYA,DEBUG_DISASM_IMP 		; $98
			FDB  	5,ADDRESS_MODE_ABS_Y,OPERATION_STA,DEBUG_DISASM_ABS_Y 		; $99
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_TXS,DEBUG_DISASM_IMP 		; $9A
			FDB  	5,ADDRESS_MODE_ABS_Y,ILLEGAL_TAS_ABS_Y,DEBUG_DISASM_ABS_Y 	; $9B
			FDB  	5,ADDRESS_MODE_ABS_X,ILLEGAL_SHY_ABS_X,DEBUG_DISASM_ABS_X	; $9C
			FDB  	5,ADDRESS_MODE_ABS_X,OPERATION_STA,DEBUG_DISASM_ABS_X 		; $9D
			FDB  	5,ADDRESS_MODE_ABS_Y,ILLEGAL_SHX_ABS_Y,DEBUG_DISASM_ABS_Y 	; $9E
			FDB  	5,ADDRESS_MODE_ABS_Y,ILLEGAL_AHX_ABS_Y,DEBUG_DISASM_ABS_Y  	; $9F

			FDB  	2,ADDRESS_MODE_IMM,OPERATION_LDY_SKIP_READ,DEBUG_DISASM_IMM	; $A0
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_LDA,DEBUG_DISASM_IND_X 		; $A1
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_LDX_SKIP_READ,DEBUG_DISASM_IMM	; $A2
			FDB  	6,ADDRESS_MODE_IND_X,ILLEGAL_LAX_IND_X,DEBUG_DISASM_IND_X 	; $A3
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_LDY,DEBUG_DISASM_ZP  		; $A4
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_LDA,DEBUG_DISASM_ZP  		; $A5
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_LDX,DEBUG_DISASM_ZP			; $A6
			FDB  	3,ADDRESS_MODE_ZP,ILLEGAL_LAX_ZP,DEBUG_DISASM_ZP  		; $A7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_TAY,DEBUG_DISASM_IMP  		; $A8
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_LDA_SKIP_READ,DEBUG_DISASM_IMM	; $A9
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_TAX,DEBUG_DISASM_IMP 		; $AA
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_LAX_IMM,DEBUG_DISASM_IMM		; $AB
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_LDY,DEBUG_DISASM_ABS		; $AC
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_LDA,DEBUG_DISASM_ABS 		; $AD
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_LDX,DEBUG_DISASM_ABS 		; $AE
			FDB  	4,ADDRESS_MODE_ABS,ILLEGAL_LAX_ABS,DEBUG_DISASM_ABS		; $AF

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BCS,DEBUG_DISASM_REL 		; $B0
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_LDA,DEBUG_DISASM_IND_Y	; $B1
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP  		; $B2
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,ILLEGAL_LAX_IND_Y,DEBUG_DISASM_IND_Y 	; $B3
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_LDY,DEBUG_DISASM_ZP_X  		; $B4
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_LDA,DEBUG_DISASM_ZP_X 		; $B5
			FDB  	4,ADDRESS_MODE_ZP_Y,OPERATION_LDX,DEBUG_DISASM_ZP_Y 		; $B6
			FDB  	4,ADDRESS_MODE_ZP_Y,ILLEGAL_LAX_ZP_Y,DEBUG_DISASM_ZP_Y 		; $B7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_CLV,DEBUG_DISASM_IMP 		; $B8
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_LDA,DEBUG_DISASM_ABS_Y 	; $B9
			FDB 	2,ADDRESS_MODE_IMP,OPERATION_TSX,DEBUG_DISASM_IMP 		; $BA
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,ILLEGAL_LAS_ABS_Y,DEBUG_DISASM_ABS_Y ; $BB
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_LDY,DEBUG_DISASM_ABS_X	; $BC
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_LDA,DEBUG_DISASM_ABS_X	; $BD
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_LDX,DEBUG_DISASM_ABS_Y	; $BE
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,ILLEGAL_LAX_ABS_Y,DEBUG_DISASM_ABS_Y ; $BF

			FDB  	2,ADDRESS_MODE_IMM,OPERATION_CPY_SKIP_READ,DEBUG_DISASM_IMM	; $C0
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_CMP,DEBUG_DISASM_IND_X		; $C1
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_NOP_IMM,DEBUG_DISASM_IMM		; $C2
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_DCP_IND_X,DEBUG_DISASM_IND_Y	; $C3
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_CPY,DEBUG_DISASM_ZP 			; $C4
			FDB 	3,ADDRESS_MODE_ZP,OPERATION_CMP,DEBUG_DISASM_ZP			; $C5
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_DEC,DEBUG_DISASM_ZP			; $C6
			FDB  	5,ADDRESS_MODE_ZP,ILLEGAL_DCP_ZP,DEBUG_DISASM_ZP			; $C7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_INY,DEBUG_DISASM_IMP		; $C8
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_CMP_SKIP_READ,DEBUG_DISASM_IMM	; $C9
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_DEX,DEBUG_DISASM_IMP		; $CA
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_AXS_IMM,DEBUG_DISASM_IMM		; $CB
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_CPY,DEBUG_DISASM_ABS		; $CC
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_CMP,DEBUG_DISASM_ABS		; $CD
			FDB  	6,ADDRESS_MODE_ABS,OPERATION_DEC,DEBUG_DISASM_ABS		; $CE
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_DCP_ABS,DEBUG_DISASM_ABS		; $CF

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BNE,DEBUG_DISASM_REL		; $D0
			FDB  	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_CMP,DEBUG_DISASM_IND_Y	; $D1
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP			; $D2
			FDB  	8,ADDRESS_MODE_IND_Y,ILLEGAL_DCP_IND_Y,DEBUG_DISASM_IND_Y	; $D3
			FDB  	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X		; $D4 
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_CMP,DEBUG_DISASM_ZP_X		; $D5 
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_DEC,DEBUG_DISASM_ZP_X		; $D6
			FDB  	6,ADDRESS_MODE_ZP_X,ILLEGAL_DCP_ZP_X,DEBUG_DISASM_ZP_X		; $D7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_CLD,DEBUG_DISASM_IMP 		; $D8
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_CMP,DEBUG_DISASM_ABS_Y	; $D9
			FDB  	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP			; $DA 
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_DCP_ABS_Y,DEBUG_DISASM_ABS_Y	; $DB 
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $DC
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_CMP,DEBUG_DISASM_ABS_X	; $DD
			FDB  	7,ADDRESS_MODE_ABS_X,OPERATION_DEC,DEBUG_DISASM_ABS_X		; $DE
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_DCP_ABS_X,DEBUG_DISASM_ABS_X	; $DF

			FDB  	2,ADDRESS_MODE_IMM,OPERATION_CPX_SKIP_READ,DEBUG_DISASM_IMM	; $E0
			FDB  	6,ADDRESS_MODE_IND_X,OPERATION_SBC,DEBUG_DISASM_IND_X		; $E1
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_NOP_IMM,DEBUG_DISASM_IMM 		; $E2
			FDB  	8,ADDRESS_MODE_IND_X,ILLEGAL_ISC_IND_X,DEBUG_DISASM_IND_X	; $E3
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_CPX,DEBUG_DISASM_ZP			; $E4
			FDB  	3,ADDRESS_MODE_ZP,OPERATION_SBC,DEBUG_DISASM_ZP			; $E5
			FDB  	5,ADDRESS_MODE_ZP,OPERATION_INC,DEBUG_DISASM_ZP			; $E6
			FDB 	5,ADDRESS_MODE_ZP,ILLEGAL_ISC_ZP,DEBUG_DISASM_ZP 		; $E7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_INX,DEBUG_DISASM_IMP		; $E8
			FDB  	2,ADDRESS_MODE_IMM,OPERATION_SBC_SKIP_READ,DEBUG_DISASM_IMM	; $E9
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_NOP,DEBUG_DISASM_IMP		; $EA
			FDB  	2,ADDRESS_MODE_IMM,ILLEGAL_SBC_IMM,DEBUG_DISASM_IMM		; $EB
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_CPX,DEBUG_DISASM_ABS		; $EC
			FDB  	4,ADDRESS_MODE_ABS,OPERATION_SBC,DEBUG_DISASM_ABS		; $ED
			FDB  	6,ADDRESS_MODE_ABS,OPERATION_INC,DEBUG_DISASM_ABS		; $EE
			FDB  	6,ADDRESS_MODE_ABS,ILLEGAL_ISC_ABS,DEBUG_DISASM_ABS		; $EF

			FDB  	2,ADDRESS_MODE_REL,OPERATION_BEQ,DEBUG_DISASM_REL 		; $F0
			FDB 	5,ADDRESS_MODE_IND_Y_EXTRA,OPERATION_SBC,DEBUG_DISASM_IND_Y 	; $F1
			FDB  	0,ADDRESS_MODE_NULL,ILLEGAL_KIL,DEBUG_DISASM_IMP 		; $F2
			FDB  	8,ADDRESS_MODE_IND_Y,ILLEGAL_ISC_IND_Y,DEBUG_DISASM_IND_Y	; $F3
			FDB  	4,ADDRESS_MODE_ZP_X,ILLEGAL_NOP_ZP_X,DEBUG_DISASM_ZP_X		; $F4
			FDB  	4,ADDRESS_MODE_ZP_X,OPERATION_SBC,DEBUG_DISASM_ZP_X		; $F5
			FDB  	6,ADDRESS_MODE_ZP_X,OPERATION_INC,DEBUG_DISASM_ZP_X		; $F6
			FDB  	6,ADDRESS_MODE_ZP_X,ILLEGAL_ISC_ZP_X,DEBUG_DISASM_ZP_X		; $F7
			FDB  	2,ADDRESS_MODE_IMP,OPERATION_SED,DEBUG_DISASM_IMP		; $F8
			FDB  	4,ADDRESS_MODE_ABS_Y_EXTRA,OPERATION_SBC,DEBUG_DISASM_ABS_Y	; $F9
			FDB  	2,ADDRESS_MODE_IMP,ILLEGAL_NOP,DEBUG_DISASM_IMP			; $FA
			FDB  	7,ADDRESS_MODE_ABS_Y,ILLEGAL_ISC_ABS_Y,DEBUG_DISASM_ABS_Y	; $FB
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,ILLEGAL_NOP_ABS_X,DEBUG_DISASM_ABS_X ; $FC
			FDB  	4,ADDRESS_MODE_ABS_X_EXTRA,OPERATION_SBC,DEBUG_DISASM_ABS_X	; $FD
			FDB  	7,ADDRESS_MODE_ABS_X,OPERATION_INC,DEBUG_DISASM_ABS_X		; $FE
			FDB  	7,ADDRESS_MODE_ABS_X,ILLEGAL_ISC_ABS_X,DEBUG_DISASM_ABS_X	; $FF

ILLEGAL_KIL
	jmp  	ILLEGAL_KIL
ILLEGAL_SLO_IND_X
ILLEGAL_NOP_ZP
ILLEGAL_SLO_ZP
ILLEGAL_ANC_IMM
ILLEGAL_NOP_ABS
ILLEGAL_SLO_ABS
ILLEGAL_SLO_IND_Y
ILLEGAL_NOP_ZP_X
ILLEGAL_SLO_ZP_X
ILLEGAL_NOP
ILLEGAL_SLO_ABS_Y
ILLEGAL_NOP_ABS_X
ILLEGAL_SLO_ABS_X
ILLEGAL_RLA_IND_X
ILLEGAL_RLA_ZP
ILLEGAL_RLA_ABS
ILLEGAL_RLA_ZP_X
ILLEGAL_RLA_ABS_Y
ILLEGAL_RLA_ABS_X
ILLEGAL_SRE_IND_X
ILLEGAL_SRE_ZP
ILLEGAL_ALR_IMM
ILLEGAL_SRE_ABS
ILLEGAL_SRE_IND_Y
ILLEGAL_SRE_ZP_X
ILLEGAL_SRE_ABS_Y
ILLEGAL_SRE_ABS_X
ILLEGAL_RRA_IND_X
ILLEGAL_RRA_ZP
ILLEGAL_ARR_IMM
ILLEGAL_RRA_ABS
ILLEGAL_RLA_IND_Y
ILLEGAL_RRA_IND_Y
ILLEGAL_RRA_ABS_X
ILLEGAL_RRA_ABS_Y
ILLEGAL_RRA_ZP_X
ILLEGAL_NOP_IMM
ILLEGAL_SAX_IND_X
ILLEGAL_SAX_ZP
ILLEGAL_XAA_IMM
ILLEGAL_SAX_ABS
ILLEGAL_AHX_IND_Y
ILLEGAL_SAX_ZP_Y
ILLEGAL_TAS_ABS_Y
ILLEGAL_SHY_ABS_X
ILLEGAL_SHX_ABS_Y
ILLEGAL_AHX_ABS_Y
ILLEGAL_LAX_IND_X
ILLEGAL_LAX_ZP
ILLEGAL_LAX_IMM
ILLEGAL_LAX_ABS
ILLEGAL_LAX_IND_Y
ILLEGAL_LAX_ZP_Y
ILLEGAL_LAS_ABS_Y
ILLEGAL_LAX_ABS_Y
ILLEGAL_DCP_IND_X
ILLEGAL_DCP_ZP
ILLEGAL_AXS_IMM
ILLEGAL_DCP_ABS
ILLEGAL_DCP_IND_Y
ILLEGAL_DCP_ZP_X
ILLEGAL_DCP_ABS_Y
ILLEGAL_DCP_ABS_X
ILLEGAL_ISC_IND_X
ILLEGAL_ISC_ZP
ILLEGAL_SBC_IMM
ILLEGAL_ISC_ABS
ILLEGAL_ISC_IND_Y
ILLEGAL_ISC_ZP_X
ILLEGAL_ISC_ABS_Y
ILLEGAL_ISC_ABS_X

 IFNDEF debugger_enabled
DEBUG_DISASM_REL
DEBUG_DISASM_ACC
DEBUG_DISASM_IMP
DEBUG_DISASM_IMM
DEBUG_DISASM_ABS
DEBUG_DISASM_ABS_X
DEBUG_DISASM_ABS_Y
DEBUG_DISASM_INDIRECT
DEBUG_DISASM_IND_X
DEBUG_DISASM_IND_Y
DEBUG_DISASM_ZP
DEBUG_DISASM_ZP_X
DEBUG_DISASM_ZP_Y
 ENDC
	rts 

*********************************************************************************

START

	pshs  	U,Y,X,DP,D,CC 

	orcc 	#$50  			; disable all interrupts
	sts  	origStackPtr
	ldmd  	#1  			; activate native 6309 mode with reduced cycle timings

	sta  	>coco3_fast
	ldd  	#cpu6502RegA
	tfr  	A,DP 

	ldd  	>apple2_lores_text_update 	; default to standard lo res text mode
	std  	<apple2videoUpdatePtr

	; configure task 1 MMU registers for their own discrete 6502 address space. the last MMU bank
	; remains the same as task 0 which is where this code lives and needs to be always mapped
	ldb  	#7  
	ldy  	#mmu_bank8
	ldx  	#cpu6502mmuMap
SETUP_MMU_TASK_NEXT
	lda  	,X+
	sta  	,Y+
	decb 
	bne  	SETUP_MMU_TASK_NEXT

	; perform a RESET on the 6502
	ldw  	#cpu_reset_vector 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr   	CPU_READ_DATA_BYTE_INTO_A
	tfr  	D,X 
	clrd 	; to init the cycle counter to 0 first time through
	bra  	CPU_MAINLOOP_SAVE_CYCLE_COUNT

	opt  	cc
CPU_MAINLOOP_ADD_CYCLE_COUNT
	ldd 	<cpu6502CycleCounter
	addr 	Y,D 
CPU_MAINLOOP_SAVE_CYCLE_COUNT
	std  	<cpu6502CycleCounter
CPU_MAINLOOP
	; check for address indicating BELL/BEEP routine
	cmpx  	#$FF3A
	bne  	CPU_MAINLOOP_NOT_BELL
	; if here, program is trying to call BELL which on Apple 2 generates beep. so we do the same on coco
	jsr  	[bell_char_ptr] 	
CPU_MAINLOOP_NOT_BELL
	cmpd  	#1000
	blo  	CPU_MAINLOOP_NO_SCREEN_DRAW
	clrd 
	std  	<cpu6502CycleCounter
	; decrement spkr counter to periodically allow reads from SPKR IO to trigger beep
	ldb  	<apple2spkrCounter
	beq  	CPU_MAINLOOP_SPKR_SKIP
	decb 
	stb  	<apple2spkrCounter
CPU_MAINLOOP_SPKR_SKIP
	; check if apple 2 is ready for a new keypress and poll coco for one if it is
	tst  	<apple2keyStatus
	bmi  	CPU_MAINLOOP_KEYBOARD_SKIP 		; apple 2 not ready
	; if here, apple 2 is ready to accept a new keypress
	jsr  	[get_char_ptr]  		; poll coco
	beq  	CPU_MAINLOOP_KEYBOARD_SKIP 	; no key currently pressed on coco. skip 
	cmpa  	#$BD 				; FOR NOW, THIS REPRESENTS A CTRL-RESET 
	bne  	CPU_MAINLOOP_NOT_CTRL_RESET
	ldx  	#$FA9B  			; CTRL-RESET activated and so set PCR to cold start basic entry point
	bra   	CPU_MAINLOOP_KEYBOARD_SKIP

CPU_MAINLOOP_NOT_CTRL_RESET
	cmpa  	#$BE
	bne  	CPU_MAINLOOP_NOT_DEBUGGER
 IFDEF debugger_enabled
	; toggle between debugger screen and normal emulator
	eim  	#1;<debugScreenToggle
	beq   	CPU_MAINLOOP_APPLE_SCREEN_ENABLE
	; enable debug screen
	jsr  	SETUP_VIDEO_80
	bra  	CPU_MAINLOOP_KEYBOARD_SKIP

CPU_MAINLOOP_APPLE_SCREEN_ENABLE
	jsr  	SETUP_VIDEO_GFX
	bra  	CPU_MAINLOOP_KEYBOARD_SKIP
 ENDC
CPU_MAINLOOP_NOT_DEBUGGER
	; if here, coco has a keypressed AND apple 2 is ready to accept a new keystroke
	ora  	#$80  				; set bit 7 high to let apple 2 HW know we have a valid keypress
	sta  	<apple2keyStatus
CPU_MAINLOOP_KEYBOARD_SKIP
	; only update the screen every other iteration
	;dec  	<vidRefreshCounter
	;bne   	CPU_MAINLOOP_NO_SCREEN_DRAW
	;lda  	#3
	;sta  	<vidRefreshCounter
	lda  	<vidRefreshFlag
	beq  	CPU_MAINLOOP_NO_SCREEN_DRAW 	; screen hasnt changed. skip
	dec 	<vidRefreshCounter
	bne  	CPU_MAINLOOP_NO_SCREEN_DRAW
	clr  	<vidRefreshFlag  			; reset flag 
	lda  	#2
	sta  	<vidRefreshCounter
	lda  	<apple2videoMode 	; pass apple2videoMode flag to update routine
	jsr   	[apple2videoUpdatePtr]
CPU_MAINLOOP_NO_SCREEN_DRAW
 IFDEF debugger_enabled
 	stx  	>instructionStart
 ENDC
	jsr  	CPU_READ_OP_BYTE_INTO_B_INC
	clra 
 IFDEF debugger_enabled
 	std  	>opcodeWord
 ENDC
	lsld  
	lsld 
	lsld 
	addd 	#opcodeJumpTable
	tfr  	D,U 
	ldy  	,U++		; grab the base amount of cycles for specific instrtuction
	jsr  	[,U++]		; take care of address mode stuff next
	jsr  	[,U++]  	; call the actual operation for opcode
 IFDEF debugger_enabled
 	jsr  	[,U]  	; print debug disassembly text based on last entry in opcode table
 ENDC
	bra  	CPU_MAINLOOP_ADD_CYCLE_COUNT

	puls  	CC,D,DP,X,Y,U,PC 

; ------------------------------------------------------------------------------------------------------
ADDRESS_MODE_NULL
ADDRESS_MODE_IMP
	rts  		; do nothing since this opcode doesnt have any operands

ADDRESS_MODE_IMM
ADDRESS_MODE_REL
	jsr  	CPU_READ_OP_BYTE_INTO_B_INC
 IFDEF debugger_enabled
  	stb  	>operandByte
 ENDC
	rts

ADDRESS_MODE_ZP
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC
	clre
	rts 	

ADDRESS_MODE_ZP_X
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC 	
	addf  	<cpu6502RegX
	clre 
	rts 

ADDRESS_MODE_ZP_Y
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC 	
	addf  	<cpu6502RegY
	clre 
	rts 

ADDRESS_MODE_IND_X
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC 	
	addf  	<cpu6502RegX
	clre
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	tfr  	D,W 
	rts 

ADDRESS_MODE_IND_Y 			
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC 	
	clre 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	ldf  	<cpu6502RegY
	clre 
	addr  	D,W 
	rts 

ADDRESS_MODE_IND_Y_EXTRA 			
	jsr  	CPU_READ_OP_BYTE_INTO_F_INC
 IFDEF debugger_enabled
  	stf  	>operandByte
 ENDC 	
	clre 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	addb  	<cpu6502RegY
	bcc  	ADDRESS_MODE_IND_Y_EXTRA_NO_PAGE_CROSS
	leay  	1,Y  		; add an extra cycle for crossing page boundary
	inca
ADDRESS_MODE_IND_Y_EXTRA_NO_PAGE_CROSS
	tfr  	D,W 
	rts 

ADDRESS_MODE_ABS
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	rts 
	
ADDRESS_MODE_ABS_X
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	ldb  	<cpu6502RegX
	clra 
	addr  	D,W 
	rts 

ADDRESS_MODE_ABS_X_EXTRA
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	tfr  	W,D 
	addb  	<cpu6502RegX
	bcc  	ADDRESS_MODE_ABS_X_EXTRA_NO_PAGE_CROSS
	leay  	1,Y  		; add an extra cycle for crossing page boundary
	inca  
ADDRESS_MODE_ABS_X_EXTRA_NO_PAGE_CROSS
	tfr  	D,W 
	rts 

ADDRESS_MODE_ABS_Y
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	ldb  	<cpu6502RegY
	clra 
	addr  	D,W 
	rts 

ADDRESS_MODE_ABS_Y_EXTRA
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	tfr  	W,D 
	addb  	<cpu6502RegY
	bcc  	ADDRESS_MODE_ABS_Y_EXTRA_NO_PAGE_CROSS
	leay  	1,Y  		; add an extra cycle for crossing page boundary
	inca  
ADDRESS_MODE_ABS_Y_EXTRA_NO_PAGE_CROSS
	tfr  	D,W 
	rts 

ADDRESS_MODE_INDIRECT
	jsr  	CPU_READ_WORD_FROM_X_INC
 IFDEF debugger_enabled
  	stw  	>operandWord
 ENDC 	
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	tfr  	D,W
	rts 

; ------------------------------------------------------------------------------------------------------
OPERATION_ADC
	; NOTE: THIS DOES NOT CURRENTLY SUPPORT DECIMAL BCD OPERATION YET
	jsr  	CPU_READ_DATA_BYTE_INTO_B 
OPERATION_ADC_SKIP_READ
	lda  	<cpu6502RegStatus
	lsra 
	adcb 	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	stbt  	A,1,6,cpu6502RegStatus  	; save overflow flag to right place in 6502 status register
	stb  	<cpu6502RegA
	rts 

OPERATION_AND
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_AND_SKIP_READ
	andb  	<cpu6502RegA
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stb  	<cpu6502RegA
	rts 

OPERATION_ASL
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_ASL_SKIP_READ
	aslb 
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	jsr  	CPU_WRITE_BYTE
	rts

OPERATION_ASL_IMP
	asl 	<cpu6502RegA  		; this directly modifies memory byte so no need to STB later
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	rts

OPERATION_BIT
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	bitb  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag from operation to right place in status register
	stbt  	B,7,7,cpu6502RegStatus  	; copy bit 7 from memory byte to status bit 7
	stbt  	B,6,6,cpu6502RegStatus  	; copy bit 6 from memory byte to status bit 6
	rts 

OPERATION_BCC
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_C_flag 
	beq  	OPERATION_BRANCH_TAKEN	
	rts  	; no branch taken. return	

OPERATION_BCS
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_C_flag 
	bne  	OPERATION_BRANCH_TAKEN	
	rts  	; no branch taken. return	

OPERATION_BEQ
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_Z_flag 
	bne  	OPERATION_BRANCH_TAKEN	; in this case, coco not equaling zero means 6502 IS equal to zero
	rts  	; no branch taken. return

OPERATION_BNE
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_Z_flag 
	beq  	OPERATION_BRANCH_TAKEN	; in this case, coco equaling zero means 6502 is NOT equal to zero
	rts  	; no branch taken. return

OPERATION_BMI
	lda  	<cpu6502RegStatus 			; negative flag on coco is also bit 7, so all we need is LDA
	bmi 	OPERATION_BRANCH_TAKEN 	
	rts  	; no branch taken. return

OPERATION_BPL
	lda  	<cpu6502RegStatus 			; negative flag on coco is also bit 7, so all we need is LDA
	bpl  	OPERATION_BRANCH_TAKEN
	rts  	; no branch taken. return

OPERATION_BVC
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_V_flag 
	beq  	OPERATION_BRANCH_TAKEN	
	rts  	; no branch taken. return	

OPERATION_BVS
	lda  	<cpu6502RegStatus
	bita  	#cpu_status_V_flag 
	bne  	OPERATION_BRANCH_TAKEN	
	rts  	; no branch taken. return	

OPERATION_BRANCH_TAKEN 		; branch was taken
	jsr  	TAKE_RELATIVE_BRANCH
	rts 

OPERATION_BRK
	tfr  	X,D 
	incd 
	jsr  	CPU_PUSH_WORD
	ldf  	<cpu6502RegSP
	lde 	#$01 
	ldb 	<cpu6502RegStatus
	orb  	#cpu_status_B_flag+cpu_status_reserved	
	jsr  	CPU_WRITE_BYTE
	dec 	<cpu6502RegSP
	ldw  	#cpu_irq_brk_vector
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incw 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	tfr  	D,X 
	rts 

OPERATION_CLC 				
	aim  	#cpu_status_C_flag_inverted;<cpu6502RegStatus
	rts 

OPERATION_CLD
	aim 	#cpu_status_D_flag_inverted;<cpu6502RegStatus
	rts 

OPERATION_CLI
	aim 	#cpu_status_I_flag_inverted;<cpu6502RegStatus
	rts 

OPERATION_CLV
	aim 	#cpu_status_V_flag_inverted;<cpu6502RegStatus
	rts 

OPERATION_CMP
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_CMP_SKIP_READ
	lda  	<cpu6502RegA
	cmpr 	B,A  
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	; the next EIM must be last since it changes N,Z, and V flags 
	eim  	#1;<cpu6502RegStatus  	; invert the carry flag to represent a "borrow" instead
	rts 

OPERATION_CPX
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_CPX_SKIP_READ
	lda  	<cpu6502RegX
	cmpr 	B,A  
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	; the next EIM must be last since it changes N,Z, and V flags 
	eim  	#1;<cpu6502RegStatus  	; invert the carry flag to represent a "borrow" instead
	rts 

OPERATION_CPY
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_CPY_SKIP_READ
	lda  	<cpu6502RegY
	cmpr 	B,A  
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	; the next EIM must be last since it changes N,Z, and V flags 
	eim  	#1;<cpu6502RegStatus  	; invert the carry flag to represent a "borrow" instead
	rts 

OPERATION_DEC
	jsr   	CPU_READ_DATA_BYTE_INTO_B
	decb
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_DEX 
	dec  	<cpu6502RegX
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_DEY 
	dec  	<cpu6502RegY
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_EOR
	jsr   	CPU_READ_DATA_BYTE_INTO_B
OPERATION_EOR_SKIP_READ
	eorb  	<cpu6502RegA 
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stb  	<cpu6502RegA
	rts 

OPERATION_INC
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incb 
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_INX 
	inc  	<cpu6502RegX
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_INY
	inc  	<cpu6502RegY
 	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_JMP
	tfr 	W,X 
	rts 

OPERATION_JSR
	tfr  	X,D 
	tfr  	W,X 
	decd  				; this ends up making PCR return/continue address minus one
	jsr   	CPU_PUSH_WORD  	; push return address-1 onto the stack first (wipes out W register)
	rts 

OPERATION_LDA
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_LDA_SKIP_READ
	stb  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_LDX
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_LDX_SKIP_READ
	stb  	<cpu6502RegX
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_LDY
	jsr  	CPU_READ_DATA_BYTE_INTO_B
OPERATION_LDY_SKIP_READ
	stb  	<cpu6502RegY
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 

OPERATION_LSR
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	lsrb 
	tfr  	CC,A
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	aim  	#cpu_status_N_flag_inverted;cpu6502RegStatus 	; clear negative flag 
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_LSR_IMP
	lsr  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	aim  	#cpu_status_N_flag_inverted;cpu6502RegStatus 	; clear negative flag 
	rts 

OPERATION_NOP
	rts 

OPERATION_ORA
	jsr   	CPU_READ_DATA_BYTE_INTO_B
OPERATION_ORA_SKIP_READ
	orb  	<cpu6502RegA 
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stb  	<cpu6502RegA
	rts 

OPERATION_PHA
	ldf  	<cpu6502RegSP
	lde  	#$01    	
	ldb  	<cpu6502RegA
	jsr   	CPU_WRITE_BYTE
	dec  	<cpu6502RegSP
	rts 

OPERATION_PHP
	; this instruction always sets the BREAK and RESERVED bit to 1 on the byte pushed to stack
	;oim 	#cpu_status_B_flag+cpu_status_reserved;<cpu6502RegStatus
	ldb  	<cpu6502RegStatus
	orb  	#cpu_status_B_flag+cpu_status_reserved
	ldf  	<cpu6502RegSP
	lde  	#$01    	
	jsr   	CPU_WRITE_BYTE
	dec  	<cpu6502RegSP
	rts 

OPERATION_PLA
	inc  	<cpu6502RegSP  		; 5 cycles
	ldf  	<cpu6502RegSP 		; 4 cycles 
	lde  	#$01
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	stb  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register 
	rts 

OPERATION_PLP
	inc  	<cpu6502RegSP  		; 5 cycles
	ldf  	<cpu6502RegSP 		; 4 cycles 
	lde  	#$01
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	stb  	<cpu6502RegStatus
	rts 

OPERATION_ROL
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	ldbt  	CC,0,0,cpu6502RegStatus 	; copy the 6502 carry flag into the coco carry so we can rotate in
	rolb 
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	jsr  	CPU_WRITE_BYTE
	rts

OPERATION_ROL_IMP
	ldbt  	CC,0,0,cpu6502RegStatus  	; copy the 6502 carry flag into the coco carry so we can rotate in
	rol  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	rts 

OPERATION_ROR
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	ldbt  	CC,0,0,cpu6502RegStatus  	; copy the 6502 carry flag into the coco carry so we can rotate in
	rorb 
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	jsr  	CPU_WRITE_BYTE
	rts

OPERATION_ROR_IMP
	ldbt  	CC,0,0,cpu6502RegStatus  	; copy the 6502 carry flag into the coco carry so we can rotate in
	ror  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	A,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	rts 

OPERATION_RTI
	ldf  	<cpu6502RegSP
	incf 
	lde  	#$01 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	stb  	<cpu6502RegStatus
	incf 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incf 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	stf  	<cpu6502RegSP
	tfr  	D,X  				; set PCR to return address on stack 
	rts 

OPERATION_RTS
	ldf  	<cpu6502RegSP
	incf 
	lde  	#$01 
	jsr  	CPU_READ_DATA_BYTE_INTO_B
	incf 
	jsr  	CPU_READ_DATA_BYTE_INTO_A
	stf  	<cpu6502RegSP
	incd 
	tfr  	D,X 				; set the PCR to the actual address to return to
	rts 

OPERATION_SBC
	; NOTE: THIS DOES NOT CURRENTLY SUPPORT DECIMAL BCD OPERATION YET
	jsr  	CPU_READ_DATA_BYTE_INTO_B 
OPERATION_SBC_SKIP_READ
	coma 					; this ALWAYS sets coco carry to 1
	; this next instruction will use the coco carry=1 to invert bit 0 of cpu6502RegStatus and save in CC
	beor  	CC,0,0,cpu6502RegStatus 	
	lda  	<cpu6502RegA
	sbcr   B,A   				; 4 cycles
	tfr  	CC,B
	stbt  	B,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	B,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	stbt  	B,0,0,cpu6502RegStatus  	; save carry flag to right place in 6502 status register
	stbt  	B,1,6,cpu6502RegStatus  	; save overflow flag to right place in 6502 status register
	; the next EIM must be last since it changes N,Z, and V flags 
	eim  	#1;<cpu6502RegStatus  	; invert the carry flag to represent a "borrow" instead
	sta  	<cpu6502RegA
	rts 

OPERATION_SEC 				
	oim  	#cpu_status_C_flag;<cpu6502RegStatus
	rts 

OPERATION_SED 				
	oim  	#cpu_status_D_flag;<cpu6502RegStatus
	rts 

OPERATION_SEI				
	oim  	#cpu_status_I_flag;<cpu6502RegStatus
	rts 

OPERATION_STA
	ldb  	<cpu6502RegA
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_STX
	ldb  	<cpu6502RegX
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_STY
	ldb  	<cpu6502RegY
	jsr  	CPU_WRITE_BYTE
	rts 

OPERATION_TAX
	ldb  	<cpu6502RegA
	stb  	<cpu6502RegX
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register 
	rts 	

OPERATION_TAY
	ldb  	<cpu6502RegA
	stb  	<cpu6502RegY
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 	

OPERATION_TSX
	ldb  	<cpu6502RegSP
	stb  	<cpu6502RegX
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 	

OPERATION_TXA 
	ldb  	<cpu6502RegX
	stb  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 		

OPERATION_TXS
	ldb  	<cpu6502RegX
	stb  	<cpu6502RegSP
	; interestingly, this instruction does not touch any the flags like the other transfer ones do :-)
	rts 	

OPERATION_TYA
	ldb  	<cpu6502RegY
	stb  	<cpu6502RegA
	tfr  	CC,A
	stbt  	A,3,7,cpu6502RegStatus 	; save negative flag to right place in 6502 status register
	stbt  	A,2,1,cpu6502RegStatus	; save zero flag to right place in 6502 status register
	rts 	

CLEANUP_NULL
	; this is just a dummy branch that isnt used and makes the lookup table an even 8 bytes (cuz LSLD)
	lbra  	CPU_MAINLOOP_ADD_CYCLE_COUNT

**************************************************************************************************************
* Subroutines area
**************************************************************************************************************
; -------------------------------------------------------------------
; Entry: Y = current cycles before branching 
; 	  X = 6502 PCR pointing to next instruction opcode
; Exit: X = new PCR after branch. Y updated for extra cycles if needed
; -------------------------------------------------------------------
TAKE_RELATIVE_BRANCH
	stx  	<tempWord
	leax  	B,X 			; X should have current PCR value in it
 IFDEF debugger_enabled
  	stx  	>operandWord
 ENDC
	tfr  	X,W 
	lda  	#1  			; we are branching so at least 1 more cycle
	cmpe  	<tempWord  		; compare the MSB of the new PCR with MSB of pre-branch PCR
	beq  	TAKE_RELATIVE_BRANCH_NO_PAGE_CROSS
	inca  				; another cycle for crossing page boundary
TAKE_RELATIVE_BRANCH_NO_PAGE_CROSS
	leay  	A,Y 
	rts 

***********************************************************************************************************
* These COPY_FLAGS subroutines were meant to be a substitute for the rare 6309 instructions like STBT, EIM,
* etc that directly manipulate and move bits around as some emulators do not properly support them. They
* are not currently used though and i'm not sure if they work properly :-P
***********************************************************************************************************
; ----------------------------------------------------------------
COPY_FLAGS_Z_C
	tfr  	CC,A
	beq  	COPY_FLAGS_Z_C_RESULT_ZERO
	ldb  	<cpu6502RegStatus 
	andb  	#cpu_status_Z_flag_inverted
	bra  	COPY_FLAGS_DO_CARRY  

COPY_FLAGS_Z_C_RESULT_ZERO
	ldb  	<cpu6502RegStatus 
	orb  	#cpu_status_Z_flag
	bra 	COPY_FLAGS_DO_CARRY

; ----------------------------------------------------------------
COPY_FLAGS_N_Z
	beq  	COPY_FLAGS_N_Z_RESULT_ZERO
	bpl  	COPY_FLAGS_N_Z_NOT_NEGATIVE
	ldb  	<cpu6502RegStatus
	orb  	#cpu_status_N_flag
	andb  	#cpu_status_Z_flag_inverted
	bra  	COPY_FLAGS_STORE_RESULT

COPY_FLAGS_N_Z_NOT_NEGATIVE
	ldb  	<cpu6502RegStatus
	andb  	#cpu_status_N_flag_inverted
	andb  	#cpu_status_Z_flag_inverted
	bra  	COPY_FLAGS_STORE_RESULT 

COPY_FLAGS_N_Z_RESULT_ZERO
	ldb  	<cpu6502RegStatus 
	orb  	#cpu_status_Z_flag
	andb  	#cpu_status_N_flag_inverted
	bra  	COPY_FLAGS_STORE_RESULT

; ----------------------------------------------------------------
COPY_FLAGS_N_Z_C
	tfr   	CC,A 
	beq  	COPY_FLAGS_N_Z_C_RESULT_ZERO
	bpl  	COPY_FLAGS_N_Z_C_NOT_NEGATIVE
	ldb  	<cpu6502RegStatus
	orb  	#cpu_status_N_flag
	andb  	#cpu_status_Z_flag_inverted
	bra  	COPY_FLAGS_DO_CARRY

COPY_FLAGS_N_Z_C_NOT_NEGATIVE
	ldb  	<cpu6502RegStatus
	andb  	#cpu_status_N_flag_inverted
	andb  	#cpu_status_Z_flag_inverted
	bra  	COPY_FLAGS_DO_CARRY

COPY_FLAGS_N_Z_C_RESULT_ZERO
	ldb  	<cpu6502RegStatus 
	orb  	#cpu_status_Z_flag
	andb  	#cpu_status_N_flag_inverted
COPY_FLAGS_DO_CARRY
	lsrb
	lsra 
	rolb 
COPY_FLAGS_STORE_RESULT
	stb  	<cpu6502RegStatus
	rts 

*****************************************************************************************
 IFDEF debugger_enabled
; ---------------------------------
; Setup 320x192 gfx mode in GIME
; ---------------------------------
SETUP_VIDEO_GFX
	pshs 	Y,X,D,CC
	orcc 	#$50

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

	include 	cpu6502_debugger.asm
 ENDC

	END 	START
