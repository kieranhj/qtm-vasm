; Generated from QTM_Data.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.


	;**********************************************************
	;*            Init data & other vars routine...           *
	;**********************************************************


clearsongvars:                                       ;clear all vars except song addr and mod vars
	STMFD	R13!,{R0-R12,R14}
	MOV	R11,#1
	B	continueinit

init:                                                ;R12 already set up on entry
	STMFD	R13!,{R0-R12,R14}                             ;
	MOV	R11,#0                                          ;clear all vars
continueinit:
	;
	;  Reset song data to default
	;
	CMP	R11,#1                                          ;0 (NE) if a full re-init
	MOV	R0,#0x20000                                     ;CIA delay (100th sec takes off 1<<16, so 2<<16 gives 50Hz)
	MOV	R1,#0                                           ;CIA counter
	MOV	R2,#0x00000006                                  ;speed (6), counter, pattern delay }_ bytes in the
	ORR	R2,R2,#0x7D000000                               ;CIA tempo (&7D = 125)             }  same word
	MOVNE	R3,#0
	STRNE	R3,[R12,#patternlen]                          ;if full init, reset pattern length to 0
	LDREQ	R3,[R12,#songaddr]
	MOV	R4,#0                                           ;current event, sequence
	MOV	R5,#0                                           ;last event, pattern, sequence
	LDR	R6,[R12,#vuflags]                               ;don't wipe vu flags/state/gravity
	BIC	R6,R6,#0xFF000000                               ;            ...but wipe last byte (songstopflags)
	MOVNE	R7,#0                                         ;if init, clear break flags/pos & max sequence/pattern
	LDREQ	R7,[R12,#breakflags]                          ;
	BICEQ	R7,R7,#0x000000FF                             ;if 'clear song vars', clear break flags/pos, but not
	BICEQ	R7,R7,#0x0000FF00                             ;  max sequence/pattern
	STMIA	R12,{R0-R7}                                   ;reset/blank first 32 bytes
	ADDNE	R10,R12,#8*4+16                               ;skip first 32b & effect flags & vu heights - don't reset these!
	MOVNE	R0,#0                                         ;
	MOVNE	R2,#0                                         ;
	MOVNE	R3,#0                                         ;clear start/pause times
	STMNEIA	R10!,{R0-R3}                                ;that's the first 64 bytes reset (only if full init)
	ADDNE	R10,R10,#4                                    ;don't overwrite 'workspaceptr'
	MOVNE	R0,#0                                         ;song state/type/actual_dma/chans (4+64) - ok to blank actual dma, resets in init_db
	MOVNE	R1,#0                                         ;song length (8+64)
	MOVNE	R2,#0                                         ;garbage data (12+64)
	STMNEIA	R10!,{R0-R2}                                ;(wipe above if full init)
	;don't wipe rest of module vars (like clock speeds etc.)
	; + skip all sound data vars
	ADD	R0,R12,#channeldata-song_data
	MOV	R1,#512
	BL	blankmemory                                      ;v1.48 this replaces clearmusicblocks
	MOV	R1,#0
	BL	clearDMAchans                                    ;if R1=0 clear ALL channel sample DMA output data
	LDMFD	R13!,{R0-R12,PC}                              ;(  R1=&FF to only clear music channels)


clearDMAchans:                                       ;on entry R1=0 to clear all, R1=&FF to clear music only
	STMFD	R13!,{R0,R2-R7,R12,R14}
	MOV	R0,#0
	MOV	R2,#0
	MOV	R3,#0
	MOV	R4,#0
	MOV	R5,#0
	MOV	R6,#0
	MOV	R14,#8
	ADD	R12,R12,#DMA_blocks-song_data
clearDMAchanloop:
	LDRB	R7,[R12,#DMA_sampleflag]                       ;R7=0 for music sample, &FF for user sample
	ANDS	R7,R7,R1                                       ;now always EQ if R1=0 (all), if R1=&FF only EQ if R7=0 (music)
	STMEQIA	R12,{R0,R2-R6}                              ;clear channel if required
	ADD	R12,R12,#24
	SUBS	R14,R14,#1
	BGT	clearDMAchanloop                                ;loop for next
	LDMFD	R13!,{R0,R2-R7,R12,PC}








