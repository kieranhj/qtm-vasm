; Generated from QTM_Song.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.


init_type:                                           ;from v1.44 this checks format valid and initialises type - setting insts and songchans too
	STMFD	R13!,{R0-R3,R11,R14}                          ;On exit V set if not ProTracker song
qtm_song_adr0:                                       ; FNlong_adr("  ",11,textdata)
	.long	0xE24FB000+((qtm_song_adr0+8-textdata)&0xFF)
	.long	0xE24BBC00+(((qtm_song_adr0+8-textdata)&0xFF00)>>8)
	LDR	R0,[R12,#songaddr]
	LDR	R1,[R0,#8]
	LDR	R2,TINF
	CMP	R1,R2
	LDREQ	R1,[R0,#12]
	CMPEQ	R1,#4
	BEQ	unsupportedformat                               ;confirmed Tracker module
	LDR	R1,[R0]
	LDR	R2,BASS
	CMP	R1,R2
	BEQ	unsupportedformat                               ;confirmed Symphony Song/Sample/Mdule file
	LDRB	R1,[R0,#0x1D7]                                 ;load byte before max sequence byte (for 15 inst)
	CMP	R1,#0x78                                        ;if it is 'x' (or possibly 127 too?) then this is probably a 15 inst song
	ADDEQ	R1,R0,#472
	MOVEQ	R14,#15
	ADDNE	R1,R0,#952
	MOVNE	R14,#31                                       ;EQ = 15 inst, NE = 31 inst
	LDRB	R2,[R1,#-2]
	CMP	R2,#127                                         ;if more than 127 sequences... bye!
	BGT	unsupportedformat                               ;(but we are allowing 0 sequences at the mo...)
	MOV	R2,#127                                         ;positions to scan...
scanpatternnos:                                      ;max. no. patterns is now 100, but we'll allow up to 127!
	LDRB	R3,[R1,R2]
	CMP	R3,#127
	BGT	unsupportedformat                               ;no patterns>127 please!
	SUBS	R2,R2,#1
	BGE	scanpatternnos
	;STRB    R14,[R12,#insts]  ;nr, as songtype=0 means 15 insts
	CMP	R14,#15
	MOVEQ	R2,#0                                         ;SoundTracker 15 inst compatible
	MOVNE	R2,#1                                         ;SoundTracker 31 inst compatible
	MOV	R14,#4                                          ;assume 4 channels until we know otherwise
	MOV	R3,#1024                                        ;and 1024 byte patterns
	BEQ	init_typedone                                   ;if 15 insts, skip the rest of the checks
	LDR	R0,[R0,#1080]
	LDR	R1,[R11,#ch16-textdata]
	CMP	R0,R1
	LDRNE	R1,[R11,#ch24-textdata]
	CMPNE	R0,R1
	LDRNE	R1,[R11,#ch32-textdata]
	CMPNE	R0,R1
	LDRNE	R1,[R11,#flt2-textdata]
	CMPNE	R0,R1
	BEQ	unsupportedformat                               ;no channels>8 ...yet... ;-) (or <4!)
	LDR	R1,[R11,#mk-textdata]
	CMP	R0,R1
	MOVEQ	R2,#2                                         ;ProTracker
	LDR	R1,[R11,#flt4-textdata]
	CMP	R0,R1
	MOVEQ	R2,#3                                         ;FLT4 StarTrekker (only 4 channels initially)
	LDR	R1,[R11,#chn4-textdata]
	CMP	R0,R1
	MOVEQ	R2,#4                                         ;4CHN FastTracker
	LDR	R1,[R11,#flt8-textdata]
	CMP	R0,R1
	MOVEQ	R2,#0x10                                      ;FLT8, 8 channel (temporary type - will convert to StarTrekker, then set origin as 3)
	MOVEQ	R14,#8
	LDR	R1,[R11,#chn8-textdata]
	CMP	R0,R1
	LDR	R1,[R11,#cd81-textdata]
	CMPNE	R0,R1
	MOVEQ	R2,#4                                         ;8CHN FastTracker, new in v1.44! or Octalyser 8 channel, new in v1.45
	MOVEQ	R3,#2048
	MOVEQ	R14,#8
	CMP	R0,R1                                           ;only EQ if CD81
	MOVEQ	R2,#5
	LDR	R1,[R11,#chn6-textdata]
	CMP	R0,R1
	LDR	R1,[R11,#cd61-textdata]
	CMPNE	R0,R1
	MOVEQ	R2,#4                                         ;6CHN FastTracker, new in v1.44!
	MOVEQ	R3,#1536
	MOVEQ	R14,#6
	CMP	R0,R1                                           ;only EQ if CD61
	MOVEQ	R2,#5
	.if maxchans==4
	CMP	R14,#4
	BGT	unsupported_only4chan
	.endif
init_typedone:
	STRB	R2,[R12,#songtype]
	TEQ	R2,#4
	TEQNE	R2,#5
	LDREQB	R2,[R12,#songstatus]
	ORREQ	R2,R2,#8
	STREQB	R2,[R12,#songstatus]                         ;set 6-octave flag for FastTracker music
	STR	R3,[R12,#patternlen]
	STRB	R14,[R12,#songchans]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0-R3,R11,PC}


unsupportedformat:
	LDMFD	R13!,{R0-R3,R11,R14}
	B	stillbadsong


	.if maxchans==4
unsupported_only4chan:
	LDMFD	R13!,{R0-R3,R11,R14}
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,err_only4chan
	MOV	PC,R14

err_only4chan:
	.long	qtm_error+0x01
	.byte	"This custom QTM only supports 4 channel music, use the full version of QTM for 4/6/8 channels." ;updated v1.46
	.byte	0
	.p2align 2
	.endif


TINF:
	.byte	"TINF"
BASS:
	.byte	0x13
	.byte	0x13
	.byte	1
	.byte	2


	.p2align 2
initsong:                                            ;init_type must have been called before this is called!
	STMFD	R13!,{R0-R12,R14}
	LDR	R11,[R12,#songaddr]
	LDR	R10,[R12,#songlength]                           ;(0 if memory-loaded, or non-RMA transfered)
	BL	workoutlength                                    ;work out actual song length (from song), *still requires FLT8 checking!*
	CMP	R10,#0
	MOVEQ	R10,R0
	STREQ	R10,[R12,#songlength]
	SUBS	R0,R10,R0                                      ;work out 'garbage' data
	CMN	R0,R10                                          ;is r0 (-ve garbage)<(-ve length) (ie is -100<-10?)
	BLE	badsong                                         ;if so, this is a bad song, so error...
	STR	R0,[R12,#garbagedata]
	CMP	R0,#0
	BLMI	resizeRMA                                      ;if too short, then attempt to get more RMA (if in RMA)
	BVS	initsong_error
	LDRB	R1,[R12,#songtype]
	TEQ	R1,#0
	BLEQ	convert15inst                                  ;convert 15 inst to 31 inst
	BVS	initsong_error
	TEQ	R1,#0x10                                        ;R1 still has songtype
	BLEQ	convertFLT8                                    ;convert StarTrekker to FastTracker format (updates patternlen=2048, songtype=3)
	LDRB	R0,[R11,#950]
	STRB	R0,[R12,#maxsequence]
	BL	findmaxpatt                                      ;get max pattern into r0
	STRB	R0,[R12,#maxpattern]                           ;store it
	MOV	R9,#0x400
	ADD	R9,R9,#0x3C                                     ;get r9 to pattern start offset
	LDR	R1,[R12,#patternlen]
	MLA	R9,R1,R0,R9                                     ;add max patt*patternlen to pattern start, gets to sample start
	;LDRB    R1,[R12,#songtype]      ;v1.45 no longer require FLT8 test
	;TEQ     R1,#&10                 ;FLT8 type, needs +1024 to length
	;ADDEQ   R9,R9,#1024             ;...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
	ADD	R0,R9,R11                                       ;r0 - sample start address
	SUBS	R1,R10,R9                                      ;songlen-sample offset=sample len (in r1)
	BLT	badsong                                         ;**** was LE in v1.43 and earlier, but from v1.44 we allow no samples ****
	ADD	R2,R12,#linlognew-song_data
	BL	convsamps                                        ;convert samples from lin to log
	SUB	R10,R10,R9                                      ;r10 - songlen-samples offset = samples len
	ADD	R9,R9,R11                                       ;r9  - sample start pointer
	ADD	R8,R12,#sampletable-song_data                   ;r8  - pointer to QTM sample data table
	ADD	R7,R11,#20                                      ;r7  - pointer to sample data blocks
	MOV	R6,#31                                          ;r6  - count down through samples
	;
	;r4  - repeat length
	;r3  - repeat offset
	;r2  - sample length
	;r1  - sample start address
	;r0  - finetune and volume bytes
readsamples:
	LDRB	R5,[R7,#22]
	LDRB	R1,[R7,#23]
	ORR	R1,R1,R5,LSL #8
	MOV	R1,R1,LSL #1                                    ;load & correct (*2) sample length into r1
	LDRB	R5,[R7,#28]
	LDRB	R3,[R7,#29]
	ORRS	R3,R3,R5,LSL #8                                ;load repeat length
	BNE	skipzerofirsttwo                                ;v1.46 test change to improve chip tunes
	CMP	R1,#0                                           ; ...if repeat length=0 and sample length>0
	MOVGT	R5,#0                                         ; ...clear first two bytes
	STRGTB	R5,[R9,#0]                                   ; ...this now behaves like PT2.3f, not 2.3a
	STRGTB	R5,[R9,#1]                                   ; ...which always cleared first two bytes
skipzerofirsttwo:
	LDRB	R4,[R7,#24]                                    ;finetune
	AND	R4,R4,#0xF
	LDRB	R5,[R7,#25]
	CMP	R5,#64
	MOVGT	R5,#64                                        ;load volume, and ensure <= 64
	ORR	R4,R4,R5,LSL #24                                ;volume in last byte (<<24) of ft+vol word
	;CMP     R3,#1
	;BLE     skip_rep                ; ***** ignore *****  skip the repeat setting routine
	MOV	R3,R3,LSL #1                                    ;correct repeat length (*2)
	LDRB	R5,[R7,#26]
	LDRB	R2,[R7,#27]
	ORR	R2,R2,R5,LSL #8                                 ;load repeat offset
	ADD	R5,R3,R2,LSL #1                                 ;work out repeat offset (corrected!!!) + repeat length
	CMP	R5,R1                                           ;is it > sample length???
	MOVLE	R2,R2,LSL #1                                  ;if not, then use corrected (*2) repeat offset
	MOVGT	R5,R2,LSR #1                                  ;if it was >, then use unshifted repeat offset
	STRGTB	R5,[R7,#27]                                  ; ...and store this offset (>>1) back in song itself...
	MOVGT	R5,R5,LSR #8                                  ; ...(so QTMEditor works ok!!!)
	STRGTB	R5,[R7,#26]
skip_rep:                                            ;all regs ok now? (r0,r1?,r2,r3,r4)
	MOV	R0,R9                                           ;r0=sample start
	STMIA	R8!,{R0-R4}
	ADD	R9,R9,R1
	SUB	R10,R10,R1
	ADD	R7,R7,#30
	SUBS	R6,R6,#1
	BNE	readsamples
	LDMFD	R13!,{R0-R12,PC}
initsong_error:
	STR	R0,[R13,#0]                                     ;stack up error pointer for r0, if error
	LDMFD	R13!,{R0-R12,PC}


badsong:
	LDMFD	R13!,{R0-R12,R14}
stillbadsong:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,dunnothisone
	MOV	PC,R14


dunnothisone:
	.long	qtm_error+0x01
	.byte	"Unsupported song format, or corrupt file"    ;updated v1.45
	.byte	0
	.p2align 2


workoutlength:                                       ;init_type must have been called before this! Returns song len in R0, requires song addr in R11
	STMFD	R13!,{R14}
	LDRB	R2,[R12,#songtype]
	CMP	R2,#0                                           ;are we 15 inst song?
	MOVNE	R1,#31                                        ;set R1 (needed later)
	MOVEQ	R1,#15
	SUBEQ	R11,R11,#480                                  ;if 15 inst, fix start (as 31 inst) for 'findmaxpatt'
	MOVEQ	R4,#470+128+2
	MOVNE	R4,#0x400
	ADDNE	R4,R4,#0x3C
	BL	findmaxpatt                                      ;get max pattern into r0
	CMP	R2,#0                                           ;are we 15 inst song?
	ADDEQ	R11,R11,#480
	LDR	R3,[R12,#patternlen]
	MLA	R0,R3,R0,R4                                     ;add max patt*patternlen to pattern start, gets to sample start
	LDRB	R3,[R12,#songtype]                             ;v1.45 the following FLT8 check is still required, as 'workoutlength' called before conversion
	TEQ	R3,#0x10                                        ; FLT8 type, needs +1024 to length
	ADDEQ	R0,R0,#1024                                   ; ...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
	MOV	R4,R11
readlengths:
	LDRB	R2,[R4,#42]
	LDRB	R3,[R4,#43]
	ORR	R2,R3,R2,LSL #8
	ADD	R0,R0,R2,LSL #1
	SUBS	R1,R1,#1                                       ;loop until no. of samples done
	ADDNE	R4,R4,#30
	BNE	readlengths
	LDMFD	R13!,{PC}


resizeRMA:                                           ;r0=-ve size
	LDRB	R1,[R12,#songstatus]
	TST	R1,#2
	MOVEQ	PC,R14
	STMFD	R13!,{R14}                                    ;we're using RMA, so time to re-size
	RSB	R3,R0,#0
	MOV	R0,#13
	LDR	R2,[R12,#songaddr]
	SWI	XOS_Module
	ADRVS	R0,err_nospcRMA
	LDMVSFD	R13!,{PC}
	STR	R2,[R12,#songaddr]
	;LDR     R0,[R12,#workspaceptr]
	;STR     R2,[R0]
	MOV	R11,R2
	ADD	R2,R2,R10
	MOV	R0,#0
clearnew:
	STRB	R0,[R2],#1
	SUBS	R3,R3,#1
	BGT	clearnew
	LDMFD	R13!,{PC}


findmaxpatt:                                         ;returns r0=maxpat
	STMFD	R13!,{R1-R3,R14}
	MOV	R0,#0
	MOV	R1,#127
	ADD	R2,R11,#952
trypatt:
	LDRB	R3,[R2,R1]
	CMP	R3,R0
	MOVGT	R0,R3
	SUBS	R1,R1,#1
	BGE	trypatt
	ADDS	R0,R0,#1                                       ; Increase maxpat + clear V
	LDMFD	R13!,{R1-R3,PC}


convertFLT8:                                         ;convert StarTrekker to FastTracker format (updates patternlen=2048, songtype=3)
	STMFD	R13!,{R0-R3,R14}                              ;r10=track length (will be altered...)  r11=song addr
	MOV	R0,#0
	MOV	R1,#127
	ADD	R2,R11,#952
convertFLTseq:
	LDRB	R3,[R2,R1]
	MOV	R3,R3,LSR #1                                    ;divide pattern number by 2
	STRB	R3,[R2,R1]
	CMP	R3,R0
	MOVGT	R0,R3
	SUBS	R1,R1,#1
	BGE	convertFLTseq
	ADD	R1,R0,#1                                        ;increase maxpat
	SUB	R2,R11,#-(1084-2048)                            ;using pattern 1 to max, so sub 2048 from patt start
convertFLTpatts:
	ADD	R0,R2,R1,LSL #11                                ;pattern*2048
	BL	shufflepattern
	SUBS	R1,R1,#1
	BGT	convertFLTpatts                                 ;loop UNTIL pattern=0
qtm_song_adr1:                                       ; FNlong_adr("  ",0,textdata)
	.long	0xE24F0000+((qtm_song_adr1+8-textdata)&0xFF)
	.long	0xE2400C00+(((qtm_song_adr1+8-textdata)&0xFF00)>>8)
	LDR	R0,[R0,#chn8-textdata]
	STR	R0,[R11,#1080]                                  ;store an '8CHN' at 1080, to show that this is now FastTracker
	MOV	R0,#2048
	STR	R0,[R12,#patternlen]
	MOV	R0,#3
	STRB	R0,[R12,#songtype]
	LDMFD	R13!,{R0-R3,PC}


convert15inst:                                       ;as of v1.44 this is only called if songype=0 = 15 insts
	STMFD	R13!,{R0-R3,R14}                              ;r10=track length (will be altered...)  r11=song addr
	LDRB	R0,[R12,#songstatus]                           ;
	TST	R0,#2                                           ; v1.44 - note if userload 15 inst, need 484 bytes free
	; after...check documentation states this
	MOVNE	R0,#13
	MOV	R2,R11                                          ;put address in r2, even if not altering
	MOVNE	R3,#484                                       ;if we're in rma, then extend it by 484 bytes...
	SWINE	XOS_Module
	ADRVS	R0,err_nospcRMA
	BVS	doconvert_error
	CMP	R11,R2
	MOVNE	R11,R2
	STRNE	R11,[R12,#songaddr]
	;LDRNE   R0,[R12,#workspaceptr]
	;STRNE   R2,[R0]
	ADD	R0,R11,#470+128+2                               ;r0=start of 15 inst patterns
	ADD	R1,R0,#484                                      ;r1=start of new (31 inst patterns=+484)
	SUB	R2,R10,#470+128+2                               ;r2=length to move
	BL	movebackwards                                    ;move patterns and samples to 31 inst position
	ADD	R0,R11,#0x100
	ADD	R0,R0,#0xD6
	ADD	R1,R0,#480
	MOV	R2,#128+2
	BL	movebackwards                                    ;move sequence to 31 inst position
	MOV	R1,#480                                         ;r1=length to blank (r0 is already in position)
	BL	blankout                                         ;blank the gap where the extra 16 insts go
qtm_song_adr2:                                       ; FNlong_adr("  ",0,textdata)
	.long	0xE24F0000+((qtm_song_adr2+8-textdata)&0xFF)
	.long	0xE2400C00+(((qtm_song_adr2+8-textdata)&0xFF00)>>8)
	LDR	R0,[R0,#mk-textdata]
	STR	R0,[R11,#1080]                                  ;store an 'M,K,' at 1080, to show that this is now 31 inst
	ADD	R10,R10,#484                                    ;update track length!!!
	STR	R10,[R12,#songlength]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R0-R3,PC}
doconvert_error:
	STR	R0,[R13,#0]
	LDMFD	R13!,{R0-R3,PC}


err_nospcRMA:
	.long	qtm_error+0x06
	.byte	"Not enough space in RMA to initialise song"  ;update v1.45
	.byte	0
	.p2align 2


movebackwards:                                       ;r0=oldstart  r1=new start  r2=length
	STMFD	R13!,{R0-R3,R14}
moveb_loop:
	SUBS	R2,R2,#1
	LDRGEB	R3,[R0,R2]
	STRGEB	R3,[R1,R2]
	BGT	moveb_loop
	LDMFD	R13!,{R0-R3,PC}


blankout:                                            ;r0=start  r1=length
	STMFD	R13!,{R1-R2,R14}
	MOV	R2,#0
blank_loop:
	SUBS	R1,R1,#1
	STRGEB	R2,[R0,R1]
	BGT	blank_loop
	LDMFD	R13!,{R1-R2,PC}


convsamps:                                           ;r0=addr, r1=length (0 or below exits), r2=conversion table pointer (lintable, loglintab)
	STMFD	R13!,{R0-R12,R14}
convsample_36:
	SUBS	R1,R1,#36
	BLT	endconvert
	LDMIA	R0,{R3-R11}
	AND	R14,R11,#0x000000FF
	LDRB	R12,[R2,R14]
	AND	R14,R11,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R12,R12,R14,LSL #8
	AND	R14,R11,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R12,R12,R14,LSL #16
	LDRB	R14,[R2,R11,LSR #24]
	ORR	R12,R12,R14,LSL #24
	AND	R14,R10,#0x000000FF
	LDRB	R11,[R2,R14]
	AND	R14,R10,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R11,R11,R14,LSL #8
	AND	R14,R10,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R11,R11,R14,LSL #16
	LDRB	R14,[R2,R10,LSR #24]
	ORR	R11,R11,R14,LSL #24
	AND	R14,R9,#0x000000FF
	LDRB	R10,[R2,R14]
	AND	R14,R9,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R10,R10,R14,LSL #8
	AND	R14,R9,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R10,R10,R14,LSL #16
	LDRB	R14,[R2,R9,LSR #24]
	ORR	R10,R10,R14,LSL #24
	AND	R14,R8,#0x000000FF
	LDRB	R9,[R2,R14]
	AND	R14,R8,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R9,R9,R14,LSL #8
	AND	R14,R8,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R9,R9,R14,LSL #16
	LDRB	R14,[R2,R8,LSR #24]
	ORR	R9,R9,R14,LSL #24
	AND	R14,R7,#0x000000FF
	LDRB	R8,[R2,R14]
	AND	R14,R7,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R8,R8,R14,LSL #8
	AND	R14,R7,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R8,R8,R14,LSL #16
	LDRB	R14,[R2,R7,LSR #24]
	ORR	R8,R8,R14,LSL #24
	AND	R14,R6,#0x000000FF
	LDRB	R7,[R2,R14]
	AND	R14,R6,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R7,R7,R14,LSL #8
	AND	R14,R6,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R7,R7,R14,LSL #16
	LDRB	R14,[R2,R6,LSR #24]
	ORR	R7,R7,R14,LSL #24
	AND	R14,R5,#0x000000FF
	LDRB	R6,[R2,R14]
	AND	R14,R5,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R6,R6,R14,LSL #8
	AND	R14,R5,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R6,R6,R14,LSL #16
	LDRB	R14,[R2,R5,LSR #24]
	ORR	R6,R6,R14,LSL #24
	AND	R14,R4,#0x000000FF
	LDRB	R5,[R2,R14]
	AND	R14,R4,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R5,R5,R14,LSL #8
	AND	R14,R4,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R5,R5,R14,LSL #16
	LDRB	R14,[R2,R4,LSR #24]
	ORR	R5,R5,R14,LSL #24
	AND	R14,R3,#0x000000FF
	LDRB	R4,[R2,R14]
	AND	R14,R3,#0x0000FF00
	LDRB	R14,[R2,R14,LSR #8]
	ORR	R4,R4,R14,LSL #8
	AND	R14,R3,#0x00FF0000
	LDRB	R14,[R2,R14,LSR #16]
	ORR	R4,R4,R14,LSL #16
	LDRB	R14,[R2,R3,LSR #24]
	ORR	R4,R4,R14,LSL #24
	STMIA	R0!,{R4-R12}
	BGT	convsample_36
	LDMEQFD	R13!,{R0-R12,PC}
endconvert:
	ADD	R1,R1,#36
convsample_1:
	SUBS	R1,R1,#1
	LDRGEB	R3,[R0]
	LDRGEB	R3,[R2,R3]
	STRGEB	R3,[R0],#1
	BGT	convsample_1
	LDMFD	R13!,{R0-R12,PC}


	;.linlogtab     ;this is filled on module init -> move to RAM databank? v1.48
	;]
	;P%+=256;O%+=256
	;[OPT opt%


init_author:
	STMFD	R13!,{R0-R3,R14}
	BL	findauthor
	CMP	R0,#0
	STREQB	R0,[R12,#author_new-song_data]
	LDMEQFD	R13!,{R0-R3,PC}                             ;if no name found
	ADD	R1,R12,#0xA00
	ADD	R1,R1,#0xE5
	MOV	R2,#0
copy_author:
	LDRB	R3,[R0,R2]
	CMP	R3,#0
	CMPNE	R3,#32
	MOVLT	R3,#32
	STRB	R3,[R1,R2]
	ADD	R2,R2,#1
	CMP	R2,#22
	BLT	copy_author
	LDMFD	R13!,{R0-R3,PC}


findauthor:                                          ;r12=song data, r11=text data
	STMFD	R13!,{R1-R4,R14}
	LDR	R0,[R12,#songaddr]
	ADD	R0,R0,#20
	LDRB	R3,[R12,#songtype]                             ;was R12,#insts here
	TEQ	R3,#0                                           ;15 inst?
	MOVEQ	R3,#15                                        ;yes
	MOVNE	R3,#31
	MOV	R2,#22
authorloop:
	ADD	R1,R11,#by-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R1,R11,#of-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R1,R11,#copyright-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R1,R11,#cpy-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R1,R11,#hash-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R1,R11,#back-textdata
	BL	search                                           ;return with (C)arry set and r0=sample addr, if found
	LDMCSFD	R13!,{R1-R4,PC}
	ADD	R0,R0,#30
	SUBS	R3,R3,#1
	BNE	authorloop
	MOV	R0,#0
	LDMFD	R13!,{R1-R4,PC}


search:                                              ;r0=search string, r1=string to look for, r2=length of (r0)
	STMFD	R13!,{R3-R7}
	MOV	R3,#0
searchloop:
	MOV	R4,R3                                           ;current string offset
	MOV	R5,R1
bytecompare:
	LDRB	R7,[R5],#1
	CMP	R7,#0
	BEQ	foundstring                                     ;if we've been through the whole sub string - we've found it...
	CMP	R4,R2                                           ;has the offset into the main string overflowed?
	BGE	notfound                                        ;if so, we can't find it...
	LDRB	R6,[R0,R4]
	CMP	R6,#0x41                                        ; }
	ADDGE	R6,R6,#32                                     ; }_ set letters A-Z **ON LY**           *** FAST
	CMP	R6,#0x7A                                        ; }  to lower case (+32)                *** method!!!
	SUBGT	R6,R6,#32                                     ; }
	ADD	R4,R4,#1
	CMP	R6,R7                                           ;are the bytes from the main- and sub-strings the same?
	BEQ	bytecompare                                     ;if so, better check some more...
	ADD	R3,R3,#1
	CMP	R3,R2                                           ;run out of place to look?
	BLT	searchloop                                      ;- no, so loop back!
notfound:
	MOVS	R3,R3,LSR #1                                   ; Clear C
	LDMFD	R13!,{R3-R7}
	MOV	PC,R14
foundstring:
	LDMFD	R13!,{R3}                                     ;don't need r3 any more, so load it with the sample count
getnamestart:
	CMP	R4,R2                                           ;has the offset into the main string overflowed?
	BGE	trynewline
	LDRB	R6,[R0,R4]
	ADD	R4,R4,#1
	CMP	R6,#32
	CMPGT	R6,#0x2E
	CMPGT	R6,#0x3A
	BLE	getnamestart
	MOV	R4,#1
	MOVS	R4,R4,RRX                                      ; Set carry
	LDMFD	R13!,{R4-R7}
	MOV	PC,R14

trynewline:
	MOV	R4,#0
	SUBS	R3,R3,#1
	ADDGT	R0,R0,#30
	BGT	getnamestart
	MOV	R4,#1
	MOVS	R4,R4,RRX                                      ; Set carry
	LDMFD	R13!,{R4-R7}                                  ;no more samples to check, so it must be this one?
	MOV	PC,R14


init_title:                                          ;r11=text data, r12=song data
	STMFD	R13!,{R0-R3,R14}
	ADD	R0,R12,#songtitle_new-song_data
	LDR	R1,[R12,#songaddr]
	MOV	R2,#20
copytitle:
	LDRB	R3,[R1],#1
	CMP	R3,#0
	CMPNE	R3,#32
	MOVLT	R3,#32
	STRB	R3,[R0],#1
	SUBS	R2,R2,#1
	BNE	copytitle
	LDMFD	R13!,{R0-R3,PC}


deinit_samples:                                      ;convert back to lin samples
	STMFD	R13!,{R0-R2,R14}
	LDRB	R0,[R12,#maxpattern]
	LDR	R1,[R12,#patternlen]
	MUL	R0,R1,R0                                        ;max patt*patternlen
	;LDRB    R1,[R12,#songtype]      ;v1.45 no need for this any more...
	;TEQ     R1,#&10                 ;FLT8 type, needs +1024 to length
	;ADDEQ   R0,R0,#1024             ;...just a fudge-thing, because no. patts*patternlen (1024) is 1024 too few
	ADD	R0,R0,#0x400                                    ;***mega bug fix 8/4/97, was 1080!***
	ADD	R0,R0,#0x3C                                     ;now at sample start offset
	LDR	R1,[R12,#songlength]
	SUB	R1,R1,R0                                        ;length to convert
	LDR	R2,[R12,#songaddr]
	ADD	R0,R0,R2
	ADR	R2,loglintab
	BL	convsamps
	LDMFD	R13!,{R0-R2,PC}


loglintab:                                           ;this is precalculated and loaded from a data file at assembly
	.incbin "LOGdata"                                   ; 256 bytes -- OSCLI "Load ... LOGdata" in the driver

	;
	; Ultra compact pattern-shuffle, (c) STEP Harrison 2013
	;
	; uses precalculated table (64 bytes) and 80 bytes of code = 144 bytes total
	; in order to reshuffle 2048 bytes of pattern data using no additional memory
	;
	; input pattern format c1-4 events 0,1,2...63 then c5-8 events 0,1,2...63
	; output pattern format c1-8 events 0,1,2,3....61,62,63
	;
	; shuffle example input  0,1,2,3,4,5.....124,125,126,127
	;         example output 0,64,1,65,2,66,3,67,4....125,62,126,63,127
	;
	; shuffle table calculated by hand/using spreadsheet...is there a better way?
	;

shufflepattern:                                      ;reorder StarTrekker patters into FastTracker format
	STMFD	R13!,{R0-R12,R14}                             ;R0=start addr of 8 channel pattern to reshuffe
	ADR	R2,shuffletable                                 ;(alternate one offset from table, one from R1)
	;if table byte=0, skip, if table byte=255 end
	ADD	R1,R0,#64*16                                    ;(64 to 127, use inbetween table bytes)
	MOV	R3,R0                                           ;output address
shuffleloop:
	LDRB	R4,[R2],#1                                     ;load table byte
	TEQ	R4,#0                                           ;0=skip
	ADDEQ	R3,R3,#1*16                                   ;get to next event position
	BEQ	skipthisshuffle
	TEQ	R4,#255                                         ;255=exit
	LDMEQFD	R13!,{R0-R12,PC}
	LDMIA	R3,{R5,R6,R7,R8}                              ;load 4 channels from current event
	ADD	R4,R0,R4,LSL #4
	LDMIA	R4,{R9,R10,R11,R12}                           ;load 4 channels from destination event
	STMIA	R4,{R5,R6,R7,R8}
	STMIA	R3!,{R9,R10,R11,R12}                          ;swap them round and increment to next event
skipthisshuffle:
	LDMIA	R3,{R5,R6,R7,R8}                              ;...do the next event using R1 as swap address
	LDMIA	R1,{R9,R10,R11,R12}
	STMIA	R1!,{R5,R6,R7,R8}
	STMIA	R3!,{R9,R10,R11,R12}
	B	shuffleloop                                       ;keep going until end of table


shuffletable:
	.byte	0                                             ;1
	.byte	64
	.byte	64
	.byte	65
	.byte	64
	.byte	66
	.byte	65
	.byte	67
	.byte	64
	.byte	68
	.byte	66
	.byte	69
	.byte	65
	.byte	70
	.byte	67
	.byte	71                                            ;16
	.byte	64
	.byte	72
	.byte	68
	.byte	73
	.byte	66
	.byte	74
	.byte	69
	.byte	75
	.byte	65
	.byte	76
	.byte	70
	.byte	77
	.byte	67
	.byte	78
	.byte	71
	.byte	79                                            ;32
	.byte	64
	.byte	80
	.byte	72
	.byte	81
	.byte	0
	.byte	82
	.byte	100
	.byte	83
	.byte	0
	.byte	84
	.byte	0
	.byte	106
	.byte	98
	.byte	106
	.byte	101
	.byte	107                                           ;48
	.byte	0
	.byte	0
	.byte	0
	.byte	108
	.byte	0
	.byte	0
	.byte	0
	.byte	118
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	255                                           ;64
	; (stray ENDIF in source -- a no-op in BASIC)

