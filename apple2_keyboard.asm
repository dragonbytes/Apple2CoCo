
	pragma  	cescapes

******************************
* Entry: call POLDRAGON 
* Exit: A will be 0 for no keypress, ASCII code otherwise.
******************************
POLDRAGON
	pshs 	B,X,Y,U 
	pshsw 

	clr 	keyResult
	ldx 	#asciiKeyTable
	ldy 	#keyboardBuffer
	ldu 	#rolloverTable

	ldb 	#%01111111
	stb 	$FF02
	lda 	$FF00
	sta 	,Y
	ldb 	#%10111111
	stb 	$FF02
	lda 	$FF00
	sta 	1,Y
	ldb 	#%11011111
	stb 	$FF02
	lda 	$FF00
	sta 	2,Y
	ldb 	#%11101111
	stb 	$FF02
	lda 	$FF00
	sta 	3,Y
	ldb 	#%11110111
	stb 	$FF02
	lda 	$FF00
	sta 	4,Y
	ldb 	#%11111011
	stb 	$FF02
	lda 	$FF00
	sta 	5,Y
	ldb 	#%11111101
	stb 	$FF02
	lda 	$FF00
	sta 	6,Y
	ldb 	#%11111110
	stb 	$FF02
	lda 	$FF00
	sta 	7,Y

	ldf 	#8
POLDRAGON_NEXT_COLUMN
	stx  	tempPtr
	ldb 	,Y+
	orb 	#%10000000 	; mask out joystick bit 
	lda 	keyboardBuffer 
	bita 	#%01000000
	beq 	POLDRAGON_SHIFT_PRESSED
	; if we are here, shift is NOT pressed. 
	leax 	6,X 
POLDRAGON_SHIFT_PRESSED
	lda 	keyboardBuffer+7
	coma 	; invert the bits so we can properly test 
	anda 	#%01000000
	beq 	POLDRAGON_SKIP_ENTER_CHECK
	bita 	rolloverTable+7
	bne 	POL_DRAGON_ENTER_KEY
POLDRAGON_SKIP_ENTER_CHECK
	; check for clear key 
	lda 	#%01000000
	bita 	keyboardBuffer+6
	bne 	POLDRAGON_SKIP_CLEAR_CHECK
	bita 	rolloverTable+6
	bne 	POLDRAGON_CLEAR_KEY
POLDRAGON_SKIP_CLEAR_CHECK
	; check for break key 
	lda 	#%01000000
	bita 	keyboardBuffer+5
	bne 	POLDRAGON_SKIP_BREAK_CHECK
	bita 	rolloverTable+5
	bne 	POLDRAGON_BREAK_KEY
POLDRAGON_SKIP_BREAK_CHECK
	bsr 	SCAN_FOR_ASCII
	beq 	POLDRAGON_SAVE_STATE
	sta 	keyResult
POLDRAGON_SAVE_STATE
	stb 	,U+
	ldx  	tempPtr 
	decf
	beq 	POLDRAGON_DONE_ALL_COLUMNS
	leax 	12,X
	bra 	POLDRAGON_NEXT_COLUMN

POL_DRAGON_ENTER_KEY
	lda 	#$0D
	sta 	keyResult
	bra 	POLDRAGON_SAVE_STATE

POLDRAGON_CLEAR_KEY
	lda 	#$BD
	sta 	keyResult
	bra 	POLDRAGON_SAVE_STATE

POLDRAGON_BREAK_KEY
	lda 	#$03 	; treat the BREAK as CTRL+C on apple 2
	sta 	keyResult
	bra 	POLDRAGON_DONE_ALL_COLUMNS

POLDRAGON_DONE_ALL_COLUMNS
	lda 	keyResult

	pulsw
	puls 	U,Y,X,B,PC 

; ------------------------------
; Entry: B = current row value from PIA 
; 	U = pointing to rollover table for appropriate column 
; 	X = pointing to ascii table for column/row character 
; -----------------------------
SCAN_FOR_ASCII
	pshs 	B 

	lde 	#6
	lda 	,U 
SCAN_FOR_ASCII_NEXT_ROW
	lsrb 
	bcc 	SCAN_FOR_ASCII_CHECK_ROLLOVER
	dece
	beq 	SCAN_FOR_ASCII_ZERO
	lsra 
	bra 	SCAN_FOR_ASCII_NEXT_ROW

SCAN_FOR_ASCII_CHECK_ROLLOVER
	lsra 
	bcs 	SCAN_FOR_ASCII_NOT_ALREADY_PRESSED
	dece
	beq 	SCAN_FOR_ASCII_ZERO
	bra 	SCAN_FOR_ASCII_NEXT_ROW

SCAN_FOR_ASCII_NOT_ALREADY_PRESSED
	ldb 	#6
	subr 	E,B
	lda 	B,X 
	bra 	SCAN_FOR_ASCII_EXIT
SCAN_FOR_ASCII_ZERO
	clra 
SCAN_FOR_ASCII_EXIT
	puls 	B,PC 

***************************************
keyboardBuffer 	FILL 	$FF,8
rolloverTable 	FILL 	$FF,8
keyResult 	FCB 	$00
tempPtr  	FDB  	0

asciiKeyTable 	FCC 	"GOW '?"
		FCC 	"gow 7/"
		FCC 	"FNV\t&>"
		FCC 	"fnv\t6."
		FCC 	"EMU\b%="
		FCC 	"emu\b5-"
		FCC 	"DLT\n$<"
		FCC 	"dlt\n4,"
		FCC 	"CKS\v#+"
		FCC 	"cks\v3;"
		FCC 	"BJRZ\x22*"
		FCC 	"bjrz2:"
		FCC 	"AIQY!)"
		FCC 	"aiqy19"
		FCC 	"@HPX0("
		FCC 	"@hpx08"

