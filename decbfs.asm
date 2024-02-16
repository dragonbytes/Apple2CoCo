**********************************************************************
* Apple2Coco v1.0
* Written by Todd Wallace
*
* My Links:
* https://www.youtube.com/@tekdragon
* https://github.com/dragonbytes
* https://tektodd.com
**********************************************************************
* DECB Filesystem Access Routines 
**********************************************************************

; Equates
decb_ext_offset 		EQU 	8
decb_type_offset 		EQU 	11
decb_flag_offset 		EQU 	12
decb_granule_offset 		EQU 	13
decb_rem_bytes_offset 	EQU 	14

decb_type_basic 		EQU 	0
decb_type_data 		EQU 	1
decb_type_exec 		EQU 	2
decb_type_text 		EQU 	3

decb_flag_ascii 		EQU 	$FF
decb_flag_binary 		EQU 	0

; --------------------------------------------------------------------------
; 1) Fills 68 byte array you point to with granule map from drive specified.
; 2) counts up how many granules are free 
; Entry: Y = points to play to store sector that has FAT
; Exit:  everything preserved 
; 	freeGranules gets set 
; --------------------------------------------------------------------------
DECB_GET_FAT
	pshs 	D,X,Y,U 

	ldd  	#sectorBuffer
	std  	>diskDataPtr
	lda 	#17
	sta 	>diskTrack
	lda 	#2
	sta 	>diskSector 	
	jsr 	DISK_READ_SECTOR
	ldu 	#sectorBuffer
	ldx 	#68
	clrb 
	; Y is pointing to FAT array to fill 
DECB_GET_FAT_NEXT_GRANULE
	lda 	,U+
	sta 	,Y+ 		; add to granule map 
	cmpa 	#$FF 	; $FF means granule is free
	bne 	DECB_GET_FAT_NOT_FREE
	incb 
DECB_GET_FAT_NOT_FREE
	leax 	-1,X 
	bne 	DECB_GET_FAT_NEXT_GRANULE
	stb 	freeGranules
	andcc  	#$FE  		; clear carry to show successfully grabbed FAT 
DECB_GET_FAT_DISK_ERROR_EXIT
	puls 	U,Y,X,D,PC 

; --------------------------------------
; Search for a filename match on specified DECB disk directory 
; Entry: Y = pointer to string of 11-character DECB space-padded filename to search for 
; Exit: success, carry clear. U = points to position in sectorBuffer where file was found. track and sector variables 
; 	will contain location where file was found 
; 	fail, carry set. everything preserved 
; --------------------------------------
DECB_FIND_FILENAME 
	pshs 	D,X,Y,U

	ldu 	#sectorBuffer
	stu  	>diskDataPtr
	lda 	#17
	sta 	>diskTrack 
	lda 	#3
DECB_FIND_FILENAME_NEXT_SECTOR
	sta 	>diskSector 
	jsr 	DISK_READ_SECTOR
	ldu 	#sectorBuffer
DECB_FIND_FILENAME_NEXT_ENTRY
	ldy 	4,S 	; grab pointer to filename to search for from stack 
	leax 	,U  
	ldb 	#11 	; should always be 11 characters to check 
DECB_FIND_FILENAME_NEXT_CHAR
	lda 	,X+
	cmpa 	,Y+
	bne	DECB_FIND_FILENAME_CUR_ENTRY_MISMATCH
	decb 
	bne 	DECB_FIND_FILENAME_NEXT_CHAR
	; if we are here, then success !!
	; clear carry for success, track and sector variables will contain location where file was found 
	; dont restore U register so it will contain the offset in 256 sector buffer where filename begins 
	andcc 	#%11111110 	; clear carry for success 
	puls 	Y,X,D 
	leas 	2,S 	; skip U on the stack 
	rts 		; return 

DECB_FIND_FILENAME_CUR_ENTRY_MISMATCH
	leau 	32,U  		; increment to next entry 
	cmpu 	#sectorBuffer+256
	blo 	DECB_FIND_FILENAME_NEXT_ENTRY
	; setup to get the next sector 
	lda 	>diskSector 
	inca 
	cmpa 	#11
	bls 	DECB_FIND_FILENAME_NEXT_SECTOR
DECB_FIND_FILENAME_NO_MATCH
	orcc 	#1 	; set carry flag for fail 
	puls 	U,Y,X,D,PC 	; restore everything and return 

; ----------------------------------------
; Entry: Y = pointing to filename and/or path to convert 
; 	X = address to save 11 byte DECB space-padded filename 
; Exit: on success, Y = pointing to final null byte or space byte. X = points to byte after 11 byte decb filename 
;       on fail, all registers restored to original values and carry set 
; ----------------------------------
DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY
	pshs 	D,X,Y

	ldb 	#11 	; counter for full padded filename 
DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NEXT_CHAR_NAME
	lda 	,Y+
	beq 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	cmpa  	#':'
	bne  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NAME_NOT_COLON
	; if here, user is specifying specific driver number. handle it
	jsr  	DECB_HANDLE_DRIVE_NUM
	bcc  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	bra   	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NAME_NOT_COLON
	cmpa 	#'.'
	beq 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_NAME
	jsr 	CONVERT_CHAR_TO_UPPERCASE 		; convert each new char to uppercase 
	sta 	,X+
	decb 
	beq 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DONE
	bra 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NEXT_CHAR_NAME

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_NAME
	cmpb 	#3
	beq  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DO_EXTENSION
	blo 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME
	lda 	#' '
	sta 	,X+
	decb 
	bra 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_NAME

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DO_EXTENSION
	;cmpy 	,U 
	;bhs 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	lda 	,Y+ 
	beq 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	cmpa  	#':'
	bne  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NOT_COLON
	; if here, user is specifying specific driver number. handle it
	jsr  	DECB_HANDLE_DRIVE_NUM
	bcc  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	bra   	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_NOT_COLON
	jsr 	CONVERT_CHAR_TO_UPPERCASE
	sta 	,X+
	decb 
	beq 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DONE
	bra 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DO_EXTENSION

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST
	lda 	#' '
DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST_NEXT
	sta 	,X+
	decb 
	bne 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_FILL_REST_NEXT
	bra 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_EXIT

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_DONE
	;cmpy 	,U 
	;bhi 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME
	lda 	,Y+  	
	beq   	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_EXIT
	cmpa  	#':'
	bne 	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME
	; if here, user is specifying specific driver number. handle it
	jsr  	DECB_HANDLE_DRIVE_NUM
	bcs  	DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME
DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_EXIT
	; annnnd we are done successfully! 
	andcc 	#%11111110 	; clear carry 
	puls 	Y,X,D,PC  	; restore all registers and return 

DECB_CONVERT_FILENAME_FOR_DIRECTORY_ENTRY_ERROR_INVALID_FILENAME
	orcc 	#1 		; set carry 
	puls 	Y,X,D,PC  	; restore all registers and return 

; --------------------------------------------------------
DECB_HANDLE_DRIVE_NUM
	pshs  	A

	lda  	,Y+
	suba  	#$30 	; convert ASCII to value
	cmpa  	#3 	; ensure drive num is between 0 and 3
	bhi  	DECB_HANDLE_DRIVE_NUM_INVALID
	tst  	,Y  	; make sure theres nothing after drive number except null
	bne  	DECB_HANDLE_DRIVE_NUM_INVALID
	sta  	>diskDriveNum
	andcc  	#$FE
	puls  	A,PC

DECB_HANDLE_DRIVE_NUM_INVALID
	orcc  	#1
	puls  	A,PC 

; -----------------------------------------
; Set the "track" and "sector" variables based on granule number
; Entry: A = granule to use to set variables 
; Exit: A = new track, B = new sector 
; -----------------------------------------
DECB_GET_TRACK_SECTOR_FROM_GRANULE
	lsra 		; assumes A contains granule number 
	bcc 	DECB_GET_TRACK_SECTOR_FROM_GRANULE_EVEN
	ldb 	#10
	bra 	DECB_GET_TRACK_SECTOR_FROM_GRANULE_SAVE

DECB_GET_TRACK_SECTOR_FROM_GRANULE_EVEN
	ldb 	#1
DECB_GET_TRACK_SECTOR_FROM_GRANULE_SAVE
	stb 	>diskSector 

	cmpa 	#17
	blo 	DECB_GET_TRACK_SECTOR_FROM_GRANULE_NO_EXTRA
	inca 
DECB_GET_TRACK_SECTOR_FROM_GRANULE_NO_EXTRA
	sta 	>diskTrack 
	rts

; ----------------------------------------------
; Entry: Y = pointer to FAT table for drive in question
; 	For FIRST PASS, decbFileNextGran should be initilized with first granule number in file and 
; 	decbFileSectorRem and decbFileCurSector should be set to $FF.
; Exit: Everything preserved. If sector is left, track and sector variables are set and carry cleared.
; 	 		   If there are no more sectors to get, then track/sector variables are not changed and 
; 			   carry set.
; NOTE: decbFileSectorRem can be checked between calls to determine if the sector returned is the last (and maybe partial)
; 	by checking if its 0 after the routine finishes/returns. 
; ----------------------------------------------
DECB_GET_NEXT_SECTOR_IN_FILE
	pshs 	D

	ldb 	decbFileSectorRem 			; get amount of FULL sectors remaining in current granule 
	beq 	DECB_GET_NEXT_SECTOR_IN_FILE_NONE_LEFT
	bmi 	DECB_GET_NEXT_SECTOR_IN_FILE_NOT_LAST 	; bit 7 set means the counter for last sectors in final granule
							; hasnt been set yet
	dec 	decbFileSectorRem	
	; if we are here, we are on the last granule. no need to worry about sector boundries for granule.
	; increment sector no matter what 
	ldb 	decbFileCurSector
	bra 	DECB_GET_NEXT_SECTOR_IN_FILE_INC_SECTOR

DECB_GET_NEXT_SECTOR_IN_FILE_NONE_LEFT
	orcc 	#1 		; set carry to show this is the final sector in the file 
	puls 	D,PC

DECB_GET_NEXT_SECTOR_IN_FILE_NOT_LAST
	ldb 	decbFileCurSector
	cmpb 	#18
	bhs 	DECB_GET_NEXT_SECTOR_IN_FILE_CHECK_GRAN 		; if 18, we need new granule. also makes sure $FF does the same 
	cmpb 	#9
	beq 	DECB_GET_NEXT_SECTOR_IN_FILE_CHECK_GRAN
DECB_GET_NEXT_SECTOR_IN_FILE_INC_SECTOR
	incb 
	stb 	decbFileCurSector
	lda 	decbFileCurTrack
	std 	>diskTrack
	andcc 	#%11111110 	; clear carry for success 
	puls 	D,PC

DECB_GET_NEXT_SECTOR_IN_FILE_CHECK_GRAN
	lda 	decbFileNextGran
	ldb 	A,Y 					; Get the next granule in the chain and save it for next pass
	cmpb 	#%11000000				; If 2 most significant bits are set, this is the last granule in file 
	bhs 	DECB_GET_NEXT_SECTOR_IN_FILE_LAST_GRAN 	; through the routine 
	stb 	decbFileNextGran 	
	bra 	DECB_GET_NEXT_SECTOR_IN_FILE_SAVE_GRAN_EXIT

DECB_GET_NEXT_SECTOR_IN_FILE_LAST_GRAN
	andb 	#%00001111 		; Strip rest of the bits of and leave low 4 bits which is how many sectors remaining
	decb 				; Decrement one since we are returning the first of the last sectors now 
	stb 	decbFileSectorRem
DECB_GET_NEXT_SECTOR_IN_FILE_SAVE_GRAN_EXIT
	jsr 	DECB_GET_TRACK_SECTOR_FROM_GRANULE 		; Use granule number in A to calculate track/sector 
	std 	decbFileCurTrack 				; Save both track/sector into the two variables 
	std 	>diskTrack
	andcc 	#%11111110 	; clear carry for success 
	puls 	D,PC

; ---------------------------------------
; Convert char to uppercase 
; Entry: A = contains character to check and/or convert 
; Exit: A = converted character, or no change if not lowercase 
; ---------------------------------------
CONVERT_CHAR_TO_UPPERCASE
	cmpa 	#$61
	blo 	CONVERT_CHAR_TO_UPPERCASE_DO_NOTHING
	cmpa 	#$7A
	bhi 	CONVERT_CHAR_TO_UPPERCASE_DO_NOTHING
	suba 	#$20
CONVERT_CHAR_TO_UPPERCASE_DO_NOTHING
	rts 
	
*************************************************
; Variables section 
; DECB variables 
freeGranules 		FCB 	$00
decbGranFilesize 	FCB 	$00
decbFileCurTrack 	RMB 	1
decbFileCurSector	RMB 	1
decbFileNextGran 	RMB 	1
decbFileSectorRem	RMB 	1
decbFileRemBytes 	RMB 	2
decbPreamble 		RMB 	5
decbGranMap 		FILL 	$FF,68
decbFilesizeGran	FCB 	$00
decbFilesizeBytes 	RMB  	4
decbPaddedFilename 	RMB  	11

sectorBuffer  	RMB  	256




