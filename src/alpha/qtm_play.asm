; Generated from QTM_Play.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.



	;  __________________________________________
	; |                                          |\
	; | QTM v1.49 (c) 1993-2013 Phoenix/Quantum  | |
	; |__________________________________________| |
	;  \__________________________________________\|
	;

	.if qtmrast
CIAhandler:                                          ;r12 = song_data on entry
	STMFD	R13!,{R0-R2,R14}                              ; * stack r0,r1,r14 and for v1.43se RasterMan, also store r2
	LDMIA	R12,{R0-R1}                                   ;r0=CIA delay, r1=CIA counter
	LDR	R2,[R12,#rm_CIAdec]                             ; * v1.43se RasterMan
	SUBS	R1,R1,R2                                       ; * take 1st lump (50Hz) of accurate time off CIA counter
	ADDLE	R1,R1,R0                                      ;if counter<=0 then add total CIA delay to it
	STR	R1,[R12,#CIAcounter]                            ;store CIA counter
	BLLE	ControlSong                                    ; * as we're now at 50Hz (but code expects 100Hz) so call twice!
	SUBS	R1,R1,R2                                       ; * take 2nd lump (50Hz) of accurate time off CIA counter
	ADDLE	R1,R1,R0                                      ;if counter<=0 then add total CIA delay to it
	STR	R1,[R12,#CIAcounter]                            ;store CIA counter
	LDMFD	R13!,{R0-R2,R14}                              ; * reload r0,r1,r14 and r2
	MOVGT	PC,R14                                        ;if CIA counter didn't run out, then exit
	.else
CIAhandler:                                          ;r12 = song_data on entry
	STMFD	R13!,{R0-R1}                                  ;stack r0,r1
	LDMIA	R12,{R0-R1}                                   ;r0=CIA delay, r1=CIA counter
	SUBS	R1,R1,#0x10000                                 ;take 1 lump of accurate time off CIA counter
	ADDLE	R1,R1,R0                                      ;if counter<=0 then add total CIA delay to it
	STR	R1,[R12,#CIAcounter]                            ;store CIA counter
	LDMFD	R13!,{R0-R1}                                  ;reload r0,r1
	MOVGT	PC,R14                                        ;if CIA counter didn't run out, then exit
	.endif
ControlSong:
	STMFD	R13!,{R0-R11,R14}
	LDRB	R0,[R12,#counter]                              ;load speed counter
	SUBS	R0,R0,#1                                       ;take off 1 (can be <0 if speed 0 used to stop song?)
	LDRLEB	R0,[R12,#speed]                              ;if counter<=0 then reload it with the speed
	STRB	R0,[R12,#counter]                              ;store counter
	BGT	doFX                                            ;if counter didn't get to 0, then go and do the effects...
	LDRB	R0,[R12,#patterndelay]                         ;load pattern delay time
	CMP	R0,#0                                           ;is it 0?
	BNE	waitdelay                                       ;if not, then go to the delay effects/count down routine
GetNewNote:
	LDRB	R1,[R12,#songstopflags]                        ;now all channels have been checked, test for stop-speed
	TEQ	R1,#0
	BLNE	stopflagset                                    ;returns if we don't stop
	ADD	R11,R12,#songaddr                               ;r11=addr of song address, then current event vars
	LDMIA	R11,{R0,R1}                                   ;r0=song address, r1=sequence (16-24) event (0-7)
	ADD	R0,R0,#952                                      ;r0=sequence table address
	LDRB	R2,[R0,R1,LSR #16]                             ;r2=pattern
	ORR	R1,R1,R2,LSL #8                                 ;r1=sequence (16-24) pattern (8-15) event (0-7)
	STR	R1,[R12,#lastevent]                             ;store a copy of the position vars
	AND	R1,R1,#0xFF                                     ;r1=event
	ADD	R8,R0,#132                                      ;add 132 to r0, to get to start of patterns, and put in r10
	LDR	R0,[R12,#patternlen]                            ;v1.44 support for 8CHN and 6CHN
	MLA	R8,R2,R0,R8                                     ;add current patt*patternlen to pattern start, gets to this pattern start
	MOV	R0,R0,LSR #6                                    ;patternlen/64 = event length (16/24/32 for 4, 8 FLT/6/8)
	MLA	R8,R1,R0,R8                                     ;add on current event*event length (no longer just 16)
	STR	R8,[R12,#tempaddrptr]
	ADD	R11,R12,#0x80                                   ;r11=addr of channel blocks
	MOV	R9,#0                                           ;r9=channel-1
dochannels:
	ADD	R10,R12,#DMA_blocks-song_data                   ;work out each time, incase of fake DMA!!!
	ADD	R10,R10,R9,LSL #4
	ADD	R10,R10,R9,LSL #3                               ;(channel DMA blocks are 24 bytes long)
	LDRB	R0,[R12,#songchans]                            ;v1.44
	TEQ	R0,#4                                           ; |   if 4 channels
	LDREQB	R0,[R12,#soundflags]                         ;v1.44  load sound flags
	TST	R0,#0x20                                        ; |   is b5 (play on c5-8) set? (songchans<32 chans, will be 0)
	LDRNEB	R0,[R12,#chans_use]                          ; |
	TEQNE	R0,#4                                         ; |  (***not checking for 8, but checking NOT 4!***)
	ADDNE	R10,R10,#4*24                                 ; |  if 'play on chan5-8' and 8 chans selected, do so! 28/6/96
	ADD	R11,R11,#64                                     ;...now at this channel's 64 byte channel data block
	LDR	R8,[R12,#tempaddrptr]
	LDR	R8,[R8,R9,LSL #2]                               ;load note word for this channel (r8)
	LDR	R0,[R12,#channelstate]                          ; *****              ** R8 must have note word
	MOV	R1,#0b10                                        ;      *****        **     by this point
	TST	R0,R1,LSL R9                                    ;      *****    ** **
	ADDEQ	R10,R12,#0x400                                ; *****          ***
	ADDEQ	R10,R10,#0x28                                 ; *****          ***
	BEQ	skipall                                         ;using fake DMA slot, so chan is left ok...
	TEQ	R8,#0                                           ;fix v1.46 18/1/22, only reset period for music
	BNE	checksampleset                                  ;                   (v1.44/5 didn't reset any!)
	LDRB	R0,[R10,#DMA_sampleflag]                       ;R0=0 music sample, 255=sound sample
	TEQ	R0,#255
	BNE	skipnote                                        ;skipnote resets period (needed for music FX)
	B	skipall                                           ;skipall doesn't reset period (use for sound sample)
checksampleset:
	AND	R0,R8,#0x00000010                               ;upper 1 bit of sample number
	AND	R1,R8,#0x00F00000                               ;lower 4 bits of sample number
	ORRS	R7,R0,R1,LSR #20                               ;r7 = sample number
	BEQ	donesample                                      ;if sample number was 0, then skip sample setting bit...
	STRB	R7,[R11,#samplenumber]                         ;store (new) sample number in channel's block
	SUB	R0,R7,#1                                        ;r0=sample-1
	ADD	R7,R12,#sampletable-song_data                   ;get addr of sample data table in r5
	ADD	R7,R7,R0,LSL #4                                 ;add (sample-1)*16 = correct info block for sample
	ADD	R7,R7,R0,LSL #2                                 ;(+4) ******************* -(*20)
	LDMIA	R7,{R0-R4}                                    ;r0=addr, r1=len, r2=rep off, r3=rep len, r4=ftune/volume
	ADD	R5,R2,R0                                        ; v1.48 -> R5 = rep address -> used by invertloop
	CMP	R3,#2                                           ;if we are repeating we'd better use replen+off as the real
	ADDGT	R1,R3,R2                                      ;...length - so the repeat is started at the right place!!!
	ADD	R0,R0,R1                                        ;turn address to end address
	STMIA	R11,{R0,R1,R3,R4,R5}                          ;***{NOTE} don't need to store the repeat offset now***
	MOV	R4,R4,LSR #24                                   ;
	STR	R4,[R10,#DMA_volume]                            ;set volume for DMA   *** And clear sample flag ***
donesample:
	AND	R0,R8,#0x00000007                               ;**v1.44 test for 8CHN** upper 3 (was 2) bits of note period
	AND	R1,R8,#0x0000FF00                               ;lower 8 bits of note period
	MOV	R0,R0,LSL #8                                    ;
	ORRS	R7,R0,R1,LSR #8                                ;r7 = amiga note period (1-4095)
	;
	; could disallow >1023 if not FastTracker (as would have been previous behaviour)
	;
	BEQ	skipnote                                        ;if note is 0, skip the note setting bit...
	CMP	R7,#1920                                        ;v1.44 if >=1920, revert to notenumber=0 (lowest note)
	MOVGE	R6,#0                                         ;
	ADDLT	R6,R12,#div8notetable-song_data
	ADDLT	R6,R6,R7,LSR #3                               ;if <1920, use 'div8' table
	CMP	R7,#150                                         ;
	ADDLT	R6,R12,#div1notetable-song_data
	ADDLT	R6,R6,R7                                      ;if <150, use 'div1' table
	LDRB	R6,[R6]                                        ;load note number - this is only used for finetuning
	;...could check if notenum=255 to skip processing if illegal note (not implemented)
	AND	R0,R8,#0x000F0000                               ;mask off effect number into r0
	CMP	R0,#0x000E0000                                  ;is it 'E'?
	ANDEQ	R0,R8,#0xF0000000                             ;if so, mask off effect data into r0...
	CMPEQ	R0,#0x50000000                                ;...is the command 'E5' (set fine tune)?
	MOVEQ	R0,R8,LSR #24                                 ;...if it is, then get data shifted into r0
	ANDEQ	R0,R0,#0xF                                    ;...and mask out the new fine tune byte
	BEQ	gotfinetune                                     ;...then go to 'gotfinetune' routine...
	LDRB	R0,[R11,#finetune]                             ;load this sample's fine tune byte, from the channel data
	CMP	R0,#0                                           ;is it 0?
	BEQ	nofinetune                                      ;if so, skip the fine tune setting bit...
gotfinetune:
	ADR	R7,amigaperiodz                                 ;get addr of amiga period tables
	MOV	R1,R0,LSL #4                                    ;fine tune *16  }_
	ADD	R0,R1,R0,LSL #7                                 ;          *128 }  *144 = offset for correct tuning DCW table
	ADD	R7,R7,R0                                        ;get to address of table (r7)
	MOVS	R1,R6,LSR #1                                   ;CS if odd numbered note
	LDR	R7,[R7,R1,LSL #2]                               ;fine tuned note (table+note number/2*4) b0-15=even, b16-31 odd
	MOVCC	R7,R7,LSL #16                                 ;
	MOV	R7,R7,LSR #16                                   ;v1.48 half size note tables
nofinetune:
	AND	R0,R8,#0x000F0000                               ;mask in effect number
	CMP	R0,#0x00030000                                  ;is it command 3?
	CMPNE	R0,#0x00050000                                ;or command 5?
	BEQ	settoneporta                                    ;if so, then go and set the tone portamento    ;
	;
	STR	R7,[R11,#amigaperiod]                           ;store (finetuned) amiga period                ;
	STRB	R6,[R11,#notenumber]                           ;store note number                             ;
	;
	MOV	R2,#1                                           ;
	LDRB	R1,[R12,#vuflags]                              ;
	ORR	R1,R1,R2,LSL R9                                 ;
	STRB	R1,[R12,#vuflags]                              ;new note, so set VU flag                      ;
	;
	CMP	R0,#0x000E0000                                  ;^^^ r0 should still have effect number in it /
	ANDEQ	R0,R8,#0xF0000000
	CMPEQ	R0,#0xD0000000                                ;if note delay (ED) then clear DMA data ****NO! (ex VOL/PD)
	BEQ	skipall                                         ; + don't do the vibrato/tremelo wave retrigging (no need!)
	;******** fix 26/2/95 - DON'T SET PERIOD! or blank DMA!
	;                     - leave previous note playing!
	MOV	R0,#0
	LDRB	R1,[R11,#vibrato_wave]                         ;load vibrato wave config
	TST	R1,#0b100                                       ;is the "Don't restart wave each note" bit set?
	STREQB	R0,[R11,#vibrato_pos]                        ;if not, then reset the wave offset
	LDRB	R1,[R11,#tremolo_wave]                         ;load tremolo wave config
	TST	R1,#0b100                                       ;is the "Don't restart wave each note" bit set?
	STREQB	R0,[R11,#tremolo_pos]                        ;if not, then reset the wave offset
	LDMIA	R11,{R0-R1}                                   ;r0=addr, r1=len
	MOV	R1,R1,LSL #12                                   ;
	RSB	R1,R1,#0                                        ;
	STMIA	R10,{R0-R1}                                   ;new note, so reset addr and offset for sample
skipnote:
	LDRB	R0,[R12,#songtype]                             ; **
	CMP	R0,#2                                           ; ** v1.49 is this a PT M.K. mod?
	LDREQB	R0,[R12,#musicoptbyte]                       ; **
	TSTEQ	R0,#8                                         ; ** if so, is musicopt bit 3 set (no reset) or clear (reset)?
	LDREQB	R0,[R11,#currentvol]                         ; ** v1.49 - bit 3 clear, do as PT 2.3D editor and reset vol on
	STREQB	R0,[R10,#DMA_volume]                         ; **         each event note, needed for 4mat's Django2 track!
	LDR	R0,[R11,#amigaperiod]                           ;load the (altered) amiga note for this channel
	STR	R0,[R10,#DMA_pitch]                             ;store it as the DMA increment
skipall:                                             ;if channel disabled, this is jumped to, with fake DMA r10
	;
	; v1.46 check if (R8 AND &FF0F0000) is zero = no need to check effects...!
	;
	AND	R0,R8,#0x000F0000                               ;v1.46 moved from checkoutFX, to save CPU cycles if no FX
	MOVS	R0,R0,LSR #16                                  ;r0=effect num (and set EQ if 0)
	MOV	R1,R8,LSR #24                                   ;r1=effect data
	STRB	R0,[R11,#currentFXnum]                         ;store effect number
	STRB	R1,[R11,#currentFXdata]                        ;store effect data
	TSTEQ	R1,#0xFF                                      ;if effect num was 0, is effect data?
	BLNE	checkoutFX                                     ;deal with the effects (needs r0=FX, r1=data)...if any...
	LDR	R0,[R11,#smp_addr]                              ;load end address
	LDR	R1,[R11,#smp_replen]                            ;load repeat length
	ADD	R2,R10,#DMA_repaddr                             ;
	STMIA	R2,{R0-R1}                                    ;store as repeat end address and repeat length
	; PT2.3F sets DMA volume to sample vol here (and doesn't set in effects)
dontsetrepeats:
	LDRB	R0,[R12,#songchans]
	ADD	R9,R9,#1                                        ;add 1 to the channel counter
	CMP	R9,R0                                           ;is >=max (no more channels to do)?
	BLT	dochannels                                      ;if not, then loop back
	;used to check for stop-speed here, but now do it on next note
	LDR	R7,[R12,#currentevent]                          ;load r7 with sequence (16-23) event (0-7)
check_pattdel:
	LDRB	R0,[R12,#patterndelay]
	SUBS	R0,R0,#1
	STRGEB	R0,[R12,#patterndelay]                       ;take off pattern delay (if running)
	ADDLE	R7,R7,#1                                      ;add 1 to event counter
	MOV	R9,R7,LSR #16                                   ;put sequence in r9 < this is here so ok for patt delay!!!
	LDRB	R0,[R12,#breakflags]                           ;load the break flag byte
	CMP	R0,#0                                           ;is it 0?
	BNE	checkjumps                                      ;if so, go to jump checking routine...
checkevent:
	TST	R7,#64                                          ;are we still in this pattern (- is bit 6 clear)?
	STREQB	R7,[R12,#currentevent]                       ;if so, so store event counter
	LDMEQFD	R13!,{R0-R11,PC}                            ; and exit... no "...PC}^" because of pattern delay
	MOV	R7,#0                                           ;set event counter to 0, because we are at a new pattern
brokepattern:                                        ;  **-{pattern break code entry}-**
	ADD	R9,R9,#1                                        ;add 1 to current sequence
jumped2seq:                                          ; **-{jump to sequence code entry}-** <<< unused now >>>
	LDRB	R0,[R12,#maxsequence]
	CMP	R9,R0                                           ;is current sequence > max sequence?
	ORRLT	R7,R7,R9,LSL #16                              ;if not, merge sequence and event, ready to store...
	STR	R7,[R12,#currentevent]                          ;store sequence (16-23) event (0-7)
	LDRB	R0,[R12,#songstopflags]                        ;'songstopflags' bit 0 end, bit 1 repeating, bit 2 F-00
	ORRGE	R0,R0,#0b001                                  ;bit 0 lowest priority (song ended), bit 2 highest (F-00)
	LDRB	R1,[R12,#lastsequence]
	CMP	R9,R1
	ORRLE	R0,R0,#0b010                                  ;if current <= last we've repeated...
	STRB	R0,[R12,#songstopflags]
	LDMFD	R13!,{R0-R11,PC}                              ; and exit... no "...PC}^" because of pattern delay


checkjumps:                                          ; ** r0=breakflags, r7=sequence (16-23) event (0-7) **
	MOV	R1,#0
	STRB	R1,[R12,#breakflags]                           ;clear breakflags
	TST	R0,#0b1                                         ;is bit 1 set (='jump to seq')?
	LDRNEB	R7,[R12,#pattbreakpos]                       ; for this code to be reached!!!
	BNE	brokepattern                                    ;then go to update sequence code...
	;TST     R0,#%10                ;no need to test for loop flags - this is the only one
	LDRB	R7,[R12,#pattbreakpos]                         ;if bit 2 set (='pattern loop') then load loop pos
	STRB	R7,[R12,#currentevent]                         ; store it as current event
	LDMFD	R13!,{R0-R11,PC}                              ; and exit... no "...PC}^" because of pattern delay


waitdelay:                                           ;r0-r11,r14 stored
	LDR	R7,[R12,#currentevent]
	ADR	R14,doFX
	STMFD	R13!,{R0-R11,R14}
	B	check_pattdel





	;**********************************************************
	;*           'process effects' routine next...            *
	;**********************************************************


doFX:                                                ;r0-r11,r14 stored
	MOV	R9,#0                                           ;r9=channel-1
checkchannels:
	ADD	R11,R12,#channeldata-song_data                  ;r11=addr of channel blocks
	ADD	R11,R11,R9,LSL #6                               ;...now at this channel's 64 byte channel data block
	ADD	R10,R12,#DMA_blocks-song_data                   ;r10=addr of DMA blocks
	ADD	R10,R10,R9,LSL #4
	ADD	R10,R10,R9,LSL #3                               ;...now at this channel's 24 byte DMA block
	LDRB	R0,[R12,#songchans]                            ;v1.44
	TEQ	R0,#4                                           ; |    if 4 channels
	LDREQB	R0,[R12,#soundflags]                         ;v1.44 load sound flags
	TST	R0,#0x20                                        ; |    is bit 5 (play on c5-8) set? (songchans<32, will be 0)
	LDRNEB	R0,[R12,#chans_use]                          ; |
	TEQNE	R0,#4                                         ; |  (***not checking for 8, but checking NOT 4!***)
	ADDNE	R10,R10,#4*24                                 ; |  if 'play on channels 5-8' and 8 channels selected, do so!
	LDRB	R0,[R11,#invloopspd]                           ;v1.48
	TEQ	R0,#0                                           ; |
	BLNE	updatefunk                                     ; | invert loop **needs R0=invloopspd**
	LDR	R0,[R12,#channelstate]                          ;disabled channel (ie. effects only?)
	MOV	R1,#2                                           ;
	TST	R0,R1,LSL R9                                    ;
	BEQ	nextFX                                          ;if so, skip effects processing
	LDRB	R0,[R11,#currentFXnum]                         ;load effect number
	LDRB	R1,[R11,#currentFXdata]                        ;load effect data
	LDR	R2,[R12,#FXflags]                               ;load effect status flags
	MOV	R3,#1
	TST	R2,R3,LSL R0                                    ;is this effect's flag set on?
	BEQ	nextFX                                          ;if not, skip it...
	CMP	R0,#end_doFXtbl-strt_doFXtbl
	ADDCC	PC,PC,R0,LSL #2
	B	nextFX
strt_doFXtbl:                                        ;may corrupt R0-R8, on entry R0=FX num, R1=FX data, R2=FX flags
	;*must* preserve - R9=chan, R10=DMA blk, R11=chan data blk, R12=song_data
	B	do_arpeggio                                       ;0 - arpeggio
	B	do_portaup                                        ;1 - portamento up
	B	do_portadown                                      ;2 - portamento down
	B	do_toneporta                                      ;3 - tone portamento
	B	do_vibrato                                        ;4 - vibrato
	B	do_tonevol                                        ;5 - tone portamento & volume slide
	B	do_vibvol                                         ;6 - vibrato & volume slide
	B	do_tremolo                                        ;7 - tremolo
	B	nextFX                                            ;8 - unused
	B	nextFX                                            ;9 - set sample offset
	B	do_volslide                                       ;A - volume slide
	B	nextFX                                            ;B - jump to sequence
	B	nextFX                                            ;C - set sample volume
	B	nextFX                                            ;D - pattern break
	B	do_E_effects                                      ;E - E effects/commands
	B	nextFX                                            ;F - set speed/tempo
end_doFXtbl:
nextFX:
	ADD	R9,R9,#1                                        ;add 1 to channel counter
	LDRB	R0,[R12,#songchans]                            ;v1.44 check up to max channels for track!
	CMP	R9,R0                                           ;has it done chans 0-3? <-was huge bug v1.40-1.43, no FX chans>4!
	BLT	checkchannels                                   ;if note, loop back...
	LDMFD	R13!,{R0-R11,PC}                              ;exit


	;**********************************************************
	;*          'process E effects' routine next...           *
	;**********************************************************


do_E_effects:                                        ;r0=effect number (always &E!!!) r1=FX data r6=channel
	MOV	R2,R1,LSR #4                                    ;r2 now has E effect number
	LDR	R3,[R12,#E_FXflags]                             ;load E effect status flags
	MOV	R4,#1
	TST	R3,R4,LSL R2                                    ;is this effect's flag set on?
	BEQ	nextFX                                          ;if not, skip it...
	CMP	R2,#end_E_FXtbl-strt_E_FXtbl
	ADDCC	PC,PC,R2,LSL #2
	B	nextFX
strt_E_FXtbl:
	B	do_setfilter                                      ;E0 - set filter
	B	do_fineslideup                                    ;E1 - fine slide up
	B	do_fineslidedown                                  ;E2 - fine slide down
	B	do_glissando                                      ;E3 - set glissando
	B	do_setvibratowave                                 ;E4 - set vibrato waveform
	B	do_setfinetuning                                  ;E5 - set fine tuning
	B	do_patternloop                                    ;E6 - pattern loop
	B	do_settremolowave                                 ;E7 - set tremolo waveform
	B	nextFX                                            ;E8 - unused
	B	do_retrignote                                     ;E9 - retrig note
	B	do_finevolumeup                                   ;EA - fine volume slide up
	B	do_finevolumedown                                 ;EB - fine volume slide down
	B	do_notecut                                        ;EC - note cut
	B	do_notedelay                                      ;ED - note delay
	B	do_patterndelay                                   ;EE - pattern delay
	B	do_invertloop                                     ;EF - invert loop
end_E_FXtbl:

	;the program should never get here!!!


	;**********************************************************
	;*          'check out effects' routine next...           *
	;**********************************************************


checkoutFX:                                          ;r0=FX, r1=data, r8=note wd, r9=chan, r10=DMA addr, r11=chan blk
	STMFD	R13!,{R0-R7,R14}
	;AND     R0,R8,#&000F0000       ;v1.46 moved to calling code...test if no effects before calling
	;MOV     R0,R0,LSR#16
	;MOV     R1,R8,LSR#24
	;STRB    R0,[R11,#currentFXnum] ;store effect number
	;STRB    R1,[R11,#currentFXdata];store effect data
	LDR	R2,[R12,#FXflags]                               ;load effect status flags
	MOV	R3,#1
	TST	R2,R3,LSL R0                                    ;is this effect's flag set on?
	BEQ	unknownFX                                       ;if not, skip it...
	CMP	R0,#end_chkFXtbl-strt_chkFXtbl
	ADDCC	PC,PC,R0,LSL #2
	B	unknownFX
strt_chkFXtbl:
	B	set_arpeggio                                      ;0 - arpeggio
	B	set_portaup                                       ;1 - portamento up
	B	set_portadown                                     ;2 - portamento down
	B	set_toneporta                                     ;3 - tone portamento
	B	set_vibrato                                       ;4 - vibrato
	B	set_tonevol                                       ;5 - tone portamento & volume slide
	B	set_vibvol                                        ;6 - vibrato & volume slide
	B	set_tremolo                                       ;7 - tremolo
	B	musicint_unused                                   ;8 - unused, so call unused effect routine
	B	set_setsampleoff                                  ;9 - set sample offset
	B	set_volslide                                      ;A - volume slide
	B	set_jump2seq                                      ;B - jump to sequence
	B	set_setsampvol                                    ;C - set sample volume
	B	set_patternbreak                                  ;D - pattern break
	B	set_E_effects                                     ;E - E effects/commands
	B	set_setspeed                                      ;F - set speed/tempo
end_chkFXtbl:
unknownFX:
	LDMFD	R13!,{R0-R7,PC}


	;**********************************************************
	;*         'check out E effects' routine next...          *
	;**********************************************************


set_E_effects:                                       ;r0=effect number (always &E!!!), r1=FX data, r9=channel
	MOV	R0,R1,LSR #4                                    ;r0 now has E effect number
	AND	R1,R1,#0x0F                                     ;r1 now has data nibble for E effect
	LDR	R2,[R12,#E_FXflags]                             ;load E effect status flags
	MOV	R3,#1
	TST	R2,R3,LSL R0                                    ;is this effect's flag set on?
	BEQ	unknownFX                                       ;if not, skip it...
	CMP	R0,#end_chkE_FXtbl-strt_chkE_FXtbl
	ADDCC	PC,PC,R0,LSL #2
	B	unknownFX
strt_chkE_FXtbl:
	B	set_setfilter                                     ;E0 - set filter
	B	set_fineslideup                                   ;E1 - fine slide up
	B	set_fineslidedown                                 ;E2 - fine slide down
	B	set_glissando                                     ;E3 - set glissando
	B	set_setvibratowave                                ;E4 - set vibrato waveform
	B	set_setfinetuning                                 ;E5 - set fine tuning
	B	set_patternloop                                   ;E6 - pattern loop
	B	set_settremolowave                                ;E7 - set tremolo waveform
	B	unknownFX                                         ;E8 - unused
	B	set_retrignote                                    ;E9 - retrig note
	B	set_finevolumeup                                  ;EA - fine volume slide up
	B	set_finevolumedown                                ;EB - fine volume slide down
	B	set_notecut                                       ;EC - note cut
	B	set_notedelay                                     ;ED - note delay
	B	set_patterndelay                                  ;EE - pattern delay
	B	set_invertloop                                    ;EF - invert loop
end_chkE_FXtbl:

	;the program should never get here!!!


set_arpeggio:                                        ; ***** 00 - arpeggio *****
	CMP	R1,#0
	LDMEQFD	R13!,{R0-R7,PC}
	MOV	R0,#2
	STRB	R0,[R11,#arpeggiovars]                         ;if arpeggio, reset its timer
	LDMFD	R13!,{R0-R7,PC}


set_toneporta:                                       ; ***** 03 - tone portamento *****
	CMP	R1,#0
	STRNEB	R1,[R11,#tportaspeed]
	LDMFD	R13!,{R0-R7,PC}


set_vibrato:                                         ; ***** 04 - vibrato *****
	CMP	R1,#0
	LDMEQFD	R13!,{R0-R7,PC}
	LDRB	R0,[R11,#vibrato_speed]
	ANDS	R2,R1,#0x0F                                    ;r2=depth
	ANDNE	R0,R0,#0xF0                                   ;r0=old speed, but not depth
	ORRNE	R0,R0,R2
	ANDS	R2,R1,#0xF0                                    ;r2=speed
	ANDNE	R0,R0,#0x0F                                   ;r1=(old) depth, but not speed
	ORRNE	R0,R0,R2
	STRB	R0,[R11,#vibrato_speed]
	LDMFD	R13!,{R0-R7,PC}


set_tremolo:                                         ; ***** 07 - tremolo *****
	CMP	R1,#0
	LDMEQFD	R13!,{R0-R7,PC}
	LDRB	R0,[R11,#tremolo_speed]
	ANDS	R2,R1,#0x0F                                    ;r2=depth
	ANDNE	R0,R0,#0xF0                                   ;r0=old speed, but not depth
	ORRNE	R0,R0,R2
	ANDS	R2,R1,#0xF0                                    ;r2=speed
	ANDNE	R0,R0,#0x0F                                   ;r1=(old) depth, but not speed
	ORRNE	R0,R0,R2
	STRB	R0,[R11,#tremolo_speed]
	LDMFD	R13!,{R0-R7,PC}


set_setsampleoff:                                    ; ***** 09 - set sample offset *****
	;TST     R8,#&00000007           ;v1.44 anything in upper 3 (was 2) bits of note period?
	;TSTEQS  R8,#&0000FF00           ;no!, so anything in lower 8 bits of note period?...
	;LDMEQFD R13!,{R0-R7,PC}         ;still no! - so we're not going to set the offset!
	; - moved down to the end, for v1.47 bug fix, this stops retrig effect...
	CMP	R1,#0
	LDREQB	R1,[R11,#setsampoff]
	STRNEB	R1,[R11,#setsampoff]
	; bug fix v1.47, must set new DMA offset and set shorter len in channel data block
	; or next note played with no sample number, will reset to base -ve len
	LDR	R0,[R11,#smp_length]
	CMP	R0,R1,LSL #8
	MOVLE	R1,#0                                         ;* if offset too large, then use 0 as off to force loop *
	MOVLE	R2,#2
	;* ...as on PT, which sets len=2 bytes *
	;* by set len=2 bytes, off=0 should do same here!  *
	SUBGT	R2,R0,R1,LSL #8                               ; } smp_length-new offset
	STR	R2,[R11,#smp_length]                            ; } v1.47 bug fix [mod.way to rude, pos 32]
	MOVGT	R3,R0,LSL #12
	RSBGT	R3,R3,#0
	ADDGT	R3,R3,R1,LSL #8+12                            ;if value was ok, get to new sample offset
	TST	R8,#0x00000007                                  ;v1.44 anything in upper 3 (was 2) bits of note period?
	TSTEQS	R8,#0x0000FF00                               ;no!, so anything in lower 8 bits of note period?...
	LDMEQFD	R13!,{R0-R7,PC}                             ;no new note, so exit
	STR	R3,[R10,#DMA_offset]                            ;only set DMA_offset if new note this time... v1.47 fudge fix
	;
	; now add offset a second time (PT2.3D bug? calls mt_CheckMoreFX twice if new note and FX=9!)
	;
	SUBS	R2,R2,R1,LSL #8
	MOVLE	R2,#2
	STR	R2,[R11,#smp_length]
	LDMFD	R13!,{R0-R7,PC}


set_jump2seq:                                        ; ***** 0B - jump to sequence *****
	MOV	R0,#0b1
	STRB	R0,[R12,#breakflags]
	SUB	R1,R1,#1
	STRB	R1,[R12,#currentseq]
	MOV	R0,#0
	STRB	R0,[R12,#pattbreakpos]
	LDMFD	R13!,{R0-R7,PC}


set_setsampvol:                                      ; ***** 0C - set sample volume *****
	CMP	R1,#64
	MOVGT	R1,#64
	STRB	R1,[R11,#currentvol]
	STRB	R1,[R10,#DMA_volume]
	LDMFD	R13!,{R0-R7,PC}


set_patternbreak:                                    ; ***** 0D - pattern break *****
	MOV	R0,#0b1
	STRB	R0,[R12,#breakflags]
	MOV	R0,R1,LSR #4
	AND	R1,R1,#0xF
	ADD	R1,R1,R0,LSL #3
	ADD	R1,R1,R0,LSL #1
	CMP	R1,#63
	MOVGT	R1,#0                                         ;if >63, set it to 0, but don't clear break flags
	STRB	R1,[R12,#pattbreakpos]
	LDMFD	R13!,{R0-R7,PC}


set_setspeed:                                        ; ***** 0F - set speed/tempo *****
	LDRB	R2,[R12,#musicoptbyte]
	TST	R2,#1
	BNE	skipciatest                                     ;if vblank flag set, skip the check for cia tempos
	CMP	R1,#32
	BGE	setCIA
skipciatest:
	CMP	R1,#0
	STRNEB	R1,[R12,#speed]
	STRNEB	R1,[R12,#counter]                            ;if not speed 0, store new speed in counter as well...
	LDRB	R1,[R12,#songstopflags]
	TSTEQ	R2,#4
	BICNE	R1,R1,#0b100                                  ;clear stop flag if ignore flag set in options or not speed 0...
	ORREQ	R1,R1,#0b100
	STRB	R1,[R12,#songstopflags]
	LDMFD	R13!,{R0-R7,PC}
setCIA:
	STRB	R1,[R12,#CIAtempo]
	MOV	R1,R1,LSL #2                                    ;temp*4
	MOV	R0,#0x3E80000
	BL	r0_div_r1
	STR	R0,[R12,#CIAdelay]
	;STR     R0,[R12,#CIAcounter]   ;- hum...? resetting accurate counter - will this lower accuracy??
	LDMFD	R13!,{R0-R7,PC}


stopflagset:                                         ;entry R1=cause of stoppage, %001=end, %010 repeat, %100=speed 0
	STMFD	R13!,{R14}
	LDRB	R0,[R12,#songstatus]
	ORR	R0,R0,#0x10
	STRB	R0,[R12,#songstatus]                           ;v1.49 set songstatus bit4 to indicate song has looped/ended
	MOV	R0,#0
	BL	musicinterrupt                                   ;QTMv1.45d re-enabled music interrupts
	LDMFD	R13!,{R14}                                    ;  ...these should be OK if used correctly
	MOV	R0,#0
	STRB	R0,[R12,#songstopflags]
	TST	R1,#0b100
	BNE	stopthesong                                     ;if caused by F-00
	TST	R1,#0b010
	MOVNE	PC,R14                                        ;if caused by repeating, exit
	LDRB	R2,[R12,#musicoptbyte]                         ;if caused by song end, check if we are ending or repeating...
	TST	R2,#2
	MOVEQ	PC,R14                                        ;if stop-on-end flag clear, then exit
stopthesong:                                         ;** v1.43 added 32bit compatibility ;)
	.if qtmrast
	MOV	PC,R14
	.endif
	TEQ	PC,PC                                           ;* Test 32bit
	.long	0x010F7000                                    ;*      32bit PSR in R7
	ORREQ	R8,R7,#0x83                                   ;*      32bit SVC, no IRQs
	.long	0x0121F008                                    ;*      32bit set
	TEQNEP	PC,#0x8000003                                ;* 26bit SVC mode with ints disabled *not32bit!
	MOV	R0,R0
	STMFD	R13!,{R14}
	BL	swi_qtmpause                                     ;note - qtmpause must not wait for DMA to clear, or this hangs!
	LDMFD	R13!,{R14}
	TEQ	PC,PC                                           ;* Test 32bit
	.long	0x0121F007                                    ;*      32bit restore original mode
	TEQNEP	PC,#0x8000002                                ;* 26bit irq mode, ints off (next must be NOP)
	MOV	R0,#0
	STRB	R0,[R12,#counter]                              ;set counter to 0 if song stopped, so it can restart instantly
	LDMFD	R13!,{R0-R11,PC}


set_fineslideup:                                     ; ***** E1 - fine slide up *****
	LDR	R0,[R11,#amigaperiod]
	CMP	R0,#0                                           ;ensure period>0!
	LDMEQFD	R13!,{R0-R7,PC}
	LDRB	R7,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R7,#8                                           ;
	MOVNE	R7,#28                                        ;
	MOVEQ	R7,#113                                       ;if 3-octaves, max amiga period is 113, if 6-octaves, max is 28
	SUB	R0,R0,R1
	CMP	R0,R7
	MOVLT	R0,R7                                         ;load period, sub decrement (increase pitch), ensure >= max
	STR	R0,[R11,#amigaperiod]
	STR	R0,[R10,#DMA_pitch]
	LDMFD	R13!,{R0-R7,PC}


set_fineslidedown:                                   ; ***** E2 - fine slide down *****
	LDR	R0,[R11,#amigaperiod]
	CMP	R0,#0                                           ;ensure period>0!
	LDMEQFD	R13!,{R0-R7,PC}
	LDRB	R7,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R7,#8                                           ;
	MOVNE	R7,#1712                                      ;
	MOVEQ	R7,#856                                       ;if 3-octaves, min amiga period is 856, if 6-octaves, min is 1712
	ADD	R0,R0,R1
	CMP	R0,R7
	MOVGT	R0,R7                                         ;load period, add increment (decrease pitch), ensure <= min
	STR	R0,[R11,#amigaperiod]
	STR	R0,[R10,#DMA_pitch]
	LDMFD	R13!,{R0-R7,PC}


set_glissando:                                       ; ***** E3 - set glissando *****
	STRB	R1,[R11,#glissando]
	LDMFD	R13!,{R0-R7,PC}


set_setvibratowave:                                  ; ***** E4 - set vibrato waveform *****
	AND	R1,R1,#0b111                                    ; v1.49 only 0=sine,1=sawtooth,2=sqr supported (pt treats 3 as 2)
	STRB	R1,[R11,#vibrato_wave]                         ; +bit 2 set (4,5,6) = don't reset wave on each note
	LDMFD	R13!,{R0-R7,PC}


set_setfinetuning:                                   ; ***** E5 - set fine tuning *****
	STRB	R1,[R11,#finetune]
	LDMFD	R13!,{R0-R7,PC}


set_patternloop:                                     ; ***** E6 - set pattern loop *****
	CMP	R1,#0
	LDREQB	R0,[R12,#currentevent]
	STREQB	R0,[R11,#pattloopstart]
	LDMEQFD	R13!,{R0-R7,PC}                             ;if 'set loop', load event and put it in loop start
	LDRB	R0,[R11,#pattloopcount]
	SUBS	R0,R0,#1                                       ;load current loop value, sub 1
	MOVMIS	R0,R1                                        ; if now <0 then it was 0 (so not in a loop) so set new
	STRGEB	R0,[R11,#pattloopcount]                      ; if new value used or (value-1)>=0, then store new value
	LDMEQFD	R13!,{R0-R7,PC}                             ; if (value-1)=0 then loop has ended, so exit
	LDRB	R0,[R11,#pattloopstart]
	STRB	R0,[R12,#pattbreakpos]                         ;store loop position in break pos
	LDRB	R0,[R12,#breakflags]
	ORR	R0,R0,#0b10
	STRB	R0,[R12,#breakflags]                           ;set break flags
	LDMFD	R13!,{R0-R7,PC}


set_settremolowave:                                  ; ***** E7 - set tremolo waveform *****
	AND	R1,R1,#0b111                                    ; v1.49 only 0=sine,1=sawtooth,2=sqr supported (pt treats 3 as 2)
	STRB	R1,[R11,#tremolo_wave]                         ; +bit 2 set (4,5,6) = don't reset wave on each note
	LDMFD	R13!,{R0-R7,PC}


set_retrignote:                                      ; ***** E9 - set retrig note *****
	STRB	R1,[R11,#retrigtimer]
	CMP	R1,#0
	LDMEQFD	R13!,{R0-R7,PC}                             ;store retrig value - if 0, exit
	AND	R0,R8,#0x00000007                               ;v1.44 upper 3 (was 2) bits of note period
	AND	R2,R8,#0x0000FF00                               ;lower 8 bits of note period
	MOV	R0,R0,LSL #8
	ORRS	R0,R0,R2,LSR #8                                ;r0 = amiga note
	STREQB	R0,[R11,#retrigtimer]                        ;if no new note on this line, then don't allow retrig!!!
	LDMFD	R13!,{R0-R7,PC}


set_finevolumeup:                                    ; ***** EA - set fine volume slide up *****
	LDRB	R0,[R11,#currentvol]
	ADD	R0,R0,R1
	CMP	R0,#64
	MOVGT	R0,#64                                        ;load volume, add increment, ensure <=64
	STRB	R0,[R11,#currentvol]
	STRB	R0,[R10,#DMA_volume]
	LDMFD	R13!,{R0-R7,PC}


set_finevolumedown:                                  ; ***** EB - set fine volume slide down *****
	LDRB	R0,[R11,#currentvol]
	SUBS	R0,R0,R1
	MOVMI	R0,#0                                         ;load volume, sub decrement, ensure >=0
	STRB	R0,[R11,#currentvol]
	STRB	R0,[R10,#DMA_volume]
	LDMFD	R13!,{R0-R7,PC}


set_notecut:                                         ; ***** EC - set note cut *****
	STRB	R1,[R11,#notecuttimer]
	LDMFD	R13!,{R0-R7,PC}


set_notedelay:                                       ; ***** ED - set note delay *****
	STRB	R1,[R11,#notedeltimer]
	CMP	R1,#0
	LDMEQFD	R13!,{R0-R7,PC}                             ;store note delay value, if 0, exit
	AND	R0,R8,#0x00000007                               ;v1.44 upper 3 (was 2) bits of note period
	AND	R2,R8,#0x0000FF00                               ;lower 8 bits of note period
	MOV	R0,R0,LSL #8
	ORRS	R0,R0,R2,LSR #8                                ;r0 = amiga note
	STREQB	R0,[R11,#notedeltimer]                       ;if no new note on this line, then don't allow note delay!
	;MOVNE   R0,#0
	;STRNE   R0,[R10,#DMA_offset]    ; ***** fix 26/2/95 - DONT BLANK DMA! or set Period!
	;STRNE   R0,[R10,#DMA_replen]    ;if there was a new note, then blank it for the delay
	LDMFD	R13!,{R0-R7,R14}                              ;...and DON'T exit back to main routine...
	B	dontsetrepeats                                    ;<- MUST NOT set the repeats, or sample starts anyway!!!


set_patterndelay:                                    ; ***** EE - pattern delay *****
	LDRB	R0,[R12,#patterndelay]
	CMP	R0,#0
	ADDEQ	R1,R1,#1
	STREQB	R1,[R12,#patterndelay]                       ;add 1 to delay, and only store if not already in a delay!
	LDMFD	R13!,{R0-R7,PC}


	; ** These effects are only called every 'beat' - *not* on the new-note interrupt **

set_setfilter:                                       ;E0 - set filter (not possible on RISC OS!)
set_invertloop:                                      ;EF - invert loop
set_portaup:                                         ;1 - portamento up
set_portadown:                                       ;2 - portamento down
set_tonevol:                                         ;5 - tone portamento & volume slide
set_vibvol:                                          ;6 - vibrato & volume slide
set_volslide:                                        ;A - volume slide
	LDMFD	R13!,{R0-R7,PC}


do_retrignote:                                       ; ***** E9 - retrig note *****
	LDRB	R0,[R11,#retrigtimer]
	SUBS	R0,R0,#1
	ANDEQ	R0,R1,#0xF                                    ;*v1.46 fix 17/1/22, was MOVEQ R0,R1 but R1=&9x...!*
	STRGEB	R0,[R11,#retrigtimer]                        ;sub 1 from retrig timer, if 0, then reset for next
	BNE	nextFX
	LDR	R1,[R11,#smp_length]
	MOV	R1,R1,LSL #12
	RSB	R1,R1,#0
	STR	R1,[R10,#DMA_offset]                            ;...and do retrig (not sure - should reset addr too??) ****
	B	nextFX


do_notecut:                                          ; ***** EC - note cut *****
	LDRB	R0,[R11,#notecuttimer]
	SUBS	R0,R0,#1
	BMI	nextFX                                          ;sub 1 from note cut timer, if <0 then no cutting to do
	STRB	R0,[R11,#notecuttimer]
	STREQB	R0,[R10,#DMA_volume]
	STREQB	R0,[R11,#currentvol]                         ;if timer=0 then do the note cut (set vol to 0)
	B	nextFX


do_notedelay:                                        ; ***** ED - note delay *****
	LDRB	R0,[R11,#notedeltimer]
	SUBS	R0,R0,#1
	BMI	nextFX                                          ;sub 1 from delay timer - if <0 then no delay, so exit
	STRB	R0,[R11,#notedeltimer]
	BNE	nextFX                                          ;if delay >0 then still time to wait, so exit
	LDMIA	R11,{R0-R2}                                   ;r0=end addr, r1=len, r2=rlen
	MOV	R1,R1,LSL #12
	RSB	R1,R1,#0
	STMIA	R10,{R0-R1}                                   ;delay ended, so set addr, length and replen to start...
	ADD	R3,R10,#DMA_repaddr
	STMIA	R3,{R0,R2}                                    ;set repeat addr and len
	LDR	R0,[R11,#amigaperiod]                           ;load the amiga note for this channel ******}_ Not in PT,
	STR	R0,[R10,#DMA_pitch]                             ;store it as the DMA increment        ******}  BUT IS reqd?
	B	nextFX


do_invertloop:                                       ; ***** EF - invert loop ***** -<( NOT PRESENT IN QTMv1.29 )>-
	; r0=effect num (&E) r1=FX data (&Fx) r2=E FX num (&F) r6=chan
	ANDS	R0,R1,#0xF                                     ; r1=E FX data r11=chan data block r10=DMA
	STRB	R0,[R11,#invloopspd]
	BLNE	updatefunk
	B	nextFX
updatefunk:                                          ;R0=invloopspeed, not called if spd=0 (check above and in do_FX)
	STMFD	R13!,{R0-R2,R14}
	ADR	R14,funktable
	LDRB	R0,[R14,R0]
	LDRB	R1,[R11,#invloopoff]
	ADD	R1,R1,R0
	STRB	R1,[R11,#invloopoff]
	TST	R1,#0x80
	LDMEQFD	R13!,{R0-R2,PC}
	MOV	R1,#0
	STRB	R1,[R11,#invloopoff]
	LDR	R0,[R11,#smp_addr]                              ;end address
	LDR	R1,[R11,#invaddress]
	ADD	R1,R1,#1
	CMP	R1,R0
	LDRGT	R1,[R11,#smp_replen]
	SUBGT	R1,R0,R1
	STR	R1,[R11,#invaddress]
	LDRB	R0,[R1]
	EOR	R0,R0,#1                                        ;invert bit 0 = change sign!
	STRB	R0,[R1]
	LDMFD	R13!,{R0-R2,PC}
	; - this very rare effect inverts actual sample data (in memory),
	;   and is the only effect NOT included in QTM<v1.48. Although I
	;   coded the routine, I never found a song which uses it, until
	;   4mat provided a test track ;) thanks! Now fully implememnted.
	;                                                             SH
funktable:
	.byte	0
	.byte	5
	.byte	6
	.byte	7
	.byte	8
	.byte	10
	.byte	11
	.byte	13
	.byte	16
	.byte	19
	.byte	22
	.byte	26
	.byte	32
	.byte	43
	.byte	64
	.byte	128
	.p2align 2



	; ** These effects are called *only* on the new-note interrupt **

do_setfilter:                                        ;E0 - set filter
do_fineslideup:                                      ;E1 - fine slide up
do_fineslidedown:                                    ;E2 - fine slide down
do_glissando:                                        ;E3 - set glissando
do_setvibratowave:                                   ;E4 - set vibrato waveform
do_setfinetuning:                                    ;E5 - set fine tuning
do_patternloop:                                      ;E6 - pattern loop
do_settremolowave:                                   ;E7 - set tremolo waveform
do_finevolumeup:                                     ;EA - fine volume slide up
do_finevolumedown:                                   ;EB - fine volume slide down
do_patterndelay:                                     ;EE - pattern delay
do_setsampleoff:                                     ;9 - set sample offset
do_jump2seq:                                         ;B - jump to sequence
do_setsampvol:                                       ;C - set sample volume
do_patternbreak:                                     ;D - pattern break
do_setspeed:                                         ;F - set speed/tempo
	B	nextFX


do_arpeggio:                                         ; ***** 00 - arpeggio *****
	CMP	R1,#0
	BEQ	nextFX                                          ;nothing to do, so skip the code...
	LDRB	R0,[R11,#arpeggiovars]
	SUBS	R0,R0,#1
	MOVLT	R0,#2
	STRB	R0,[R11,#arpeggiovars]
	LDRLT	R0,[R11,#amigaperiod]
	BLT	endarpeg                                        ;if counter = 2, then no alteration
	LDRB	R2,[R11,#finetune]
	ADR	R6,amigaperiodz
	ADD	R6,R6,R2,LSL #7
	ADD	R6,R6,R2,LSL #4
	LDR	R2,[R11,#amigaperiod]
	LDRB	R3,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R3,#8                                           ;
	MOVNE	R3,#0                                         ;if 6-octaves, use range 0-71
	MOVNE	R5,#71
	MOVEQ	R3,#12                                        ;if 3-octaves, use range 12-47
	MOVEQ	R5,#47
arpegloop:
	MOVS	R4,R3,LSR #1
	LDR	R4,[R6,R4,LSL #2]
	MOVCC	R4,R4,LSL #16
	MOV	R4,R4,LSR #16                                   ;v1.48 half size note tables *combine with CMP below?*
	CMP	R4,R2
	BLE	arpeggot
	CMP	R3,R5                                           ;v1.44 fix - previously had '36' should have been 35 or overrun next table
	ADDLT	R3,R3,#1
	BLT	arpegloop
arpeggot:
	CMP	R0,#1
	ADDEQ	R3,R3,R1,LSR #4                               ;if counter = 1, then add top 4 bits of data
	ANDLT	R4,R1,#0x0F
	ADDLT	R3,R3,R4                                      ;if counter < 1 (0), then add bottom 4 bits
	MOVS	R0,R3,LSR #1
	LDR	R0,[R6,R0,LSL #2]                               ;load amiga period
	MOVCC	R0,R0,LSL #16
	MOV	R0,R0,LSR #16                                   ;v1.48 half size note tables
endarpeg:
	STR	R0,[R10,#DMA_pitch]                             ;store in DMA block - don't alter non-DMA period or number
	B	nextFX


do_portaup:                                          ; ***** 01 - portamento up *****
	LDRB	R2,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R2,#8                                           ;
	MOVNE	R2,#28                                        ;
	MOVEQ	R2,#113                                       ;if 3-octaves, max amiga period is 113, if 6-octaves, max is 28
	LDR	R0,[R11,#amigaperiod]
	SUB	R0,R0,R1
	CMP	R0,R2
	MOVLT	R0,R2
	STR	R0,[R11,#amigaperiod]
	STR	R0,[R10,#DMA_pitch]
	B	nextFX


do_portadown:                                        ; ***** 02 - portamento down *****
	LDRB	R2,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R2,#8                                           ;
	MOVNE	R2,#1712                                      ;
	MOVEQ	R2,#856                                       ;if 3-octaves, min amiga period is 856, if 6-octaves, min is 1712
	LDR	R0,[R11,#amigaperiod]
	ADD	R0,R0,R1
	CMP	R0,R2
	MOVGT	R0,R2
	STR	R0,[R11,#amigaperiod]
	STR	R0,[R10,#DMA_pitch]
	B	nextFX


do_toneporta:                                        ; ***** 03 - tone portamento *****
	LDR	R0,[R11,#tportawanted]
	LDR	R1,[R11,#amigaperiod]
	CMP	R0,#0
	CMPNE	R1,#0
	BEQ	nextFX                                          ;if target period, or current period = 0, nothing to do
	LDRB	R2,[R11,#tportaspeed]
	CMP	R0,R1
	BGT	tporta_add
	SUB	R1,R1,R2
	CMP	R0,R1
	MOVGT	R1,R0
	MOVGE	R0,#0
	STRGE	R0,[R11,#tportawanted]                        ;blank target, once we've got there
	STR	R1,[R11,#amigaperiod]                           ;store target note, now we're here
	LDRB	R0,[R11,#glissando]
	CMP	R0,#1
	BEQ	tporta_setgliss                                 ;if gliss, do that
	STR	R1,[R10,#DMA_pitch]
	B	nextFX

tporta_add:
	ADD	R1,R1,R2
	CMP	R0,R1
	MOVLT	R1,R0
	MOVLE	R0,#0
	STRLE	R0,[R11,#tportawanted]                        ;blank target, once we've got there
	STR	R1,[R11,#amigaperiod]                           ;store target note, now we're here
	LDRB	R0,[R11,#glissando]
	CMP	R0,#1
	BEQ	tporta_setgliss                                 ;if gliss, do that
	STR	R1,[R10,#DMA_pitch]
	B	nextFX

tporta_setgliss:
	ADR	R3,amigaperiodz
	LDRB	R4,[R11,#finetune]
	ADD	R3,R3,R4,LSL #4
	ADD	R3,R3,R4,LSL #7
	LDRB	R0,[R12,#songstatus]                           ;v1.44 need to test bit 3, for 3 or 6 octaves
	TST	R0,#8                                           ;
	MOVNE	R0,#0                                         ;if 6-octaves, use range 0-71
	MOVNE	R5,#71
	MOVEQ	R0,#12                                        ;if 3-octaves, use range 12-47
	MOVEQ	R5,#47
glissloop:
	MOVS	R4,R0,LSR #1
	LDR	R4,[R3,R4,LSL #2]
	MOVCC	R4,R4,LSL #16                                 ;
	MOV	R4,R4,LSR #16                                   ;v1.48 half size note tables
	CMP	R1,R4
	BGE	foundgliss
	ADD	R0,R0,#1
	CMP	R0,R5
	BLE	glissloop
foundgliss:
	STR	R4,[R10,#DMA_pitch]
	B	nextFX


settoneporta:                                        ;(called from note decode) R7=(fine tuned) note period R6=notenum
	LDR	R0,[R11,#amigaperiod]                           ;
	CMP	R0,#0                                           ;must store new wanted note, EVEN if it is the same as the
	STRNE	R7,[R11,#tportawanted]                        ;current period, because tporta may not have found last one
	B	skipnote                                          ;return to channel routine


do_vibrato:                                          ; ***** 04 - vibrato *****
	LDR	R0,[R11,#amigaperiod]
	CMP	R0,#0
	BEQ	nextFX
	LDR	R1,[R11,#vibrato_speed]                         ;0-7 speed/depth, 8-15 wave, 26-31 pos (signed)
	AND	R3,R1,#0x7C000000                               ;get pos in bits 26-30 (bit 31 is sign, so clear it)
	TST	R1,#0x100
	BNE	vib_rampdown                                    ;
	TST	R1,#0x200
	MOVNE	R3,#255
	;ADDEQ   R4,R12,#(vibratotable-song_data) AND &FF00
	;ADDEQ   R4,R4,#(vibratotable-song_data) AND &00FF
	ADREQ	R4,vibratotable_new
	LDREQB	R3,[R4,R3,LSR #26]
vib_set:
	AND	R4,R1,#0x0F
	MUL	R3,R4,R3
	ANDS	R2,R1,#0xFF000000                              ;26-31 pos (+sign) (bits 24 & 25 are 0, because shifted 2)
	ADDGE	R0,R0,R3,LSR #7
	SUBMI	R0,R0,R3,LSR #7
	STR	R0,[R10,#DMA_pitch]
	MOV	R1,R1,LSR #2
	AND	R1,R1,#0x3C
	ADD	R2,R1,R2,ASR #24                                ;v1.46a this should probably be ASR#24 (was LSR)
	STRB	R2,[R11,#vibrato_pos]
	B	nextFX

vib_rampdown:
	MOV	R3,R3,LSR #23
	TST	R1,#0x80000000
	RSBNE	R3,R3,#255
	B	vib_set


do_tonevol:                                          ; ***** 05 - tone portamento & volume slide *****
	LDRB	R0,[R11,#currentvol]
	TST	R1,#0xF0
	ADDNE	R0,R0,R1,LSR #4
	ANDEQ	R1,R1,#0x0F
	SUBEQ	R0,R0,R1
	CMP	R0,#0
	MOVMI	R0,#0
	CMP	R0,#64
	MOVGT	R0,#64
	STRB	R0,[R11,#currentvol]
	STRB	R0,[R10,#DMA_volume]
	B	do_toneporta


do_vibvol:                                           ; ***** 06 - vibrato & volume slide *****
	LDRB	R0,[R11,#currentvol]
	TST	R1,#0xF0
	ADDNE	R0,R0,R1,LSR #4
	ANDEQ	R1,R1,#0x0F
	SUBEQ	R0,R0,R1
	CMP	R0,#0
	MOVMI	R0,#0
	CMP	R0,#64
	MOVGT	R0,#64
	STRB	R0,[R11,#currentvol]
	STRB	R0,[R10,#DMA_volume]
	B	do_vibrato


vibratotable_new:                                    ; v1.48 no longer pre-build this in the databank area
	.byte	0
	.byte	24
	.byte	49
	.byte	74
	.byte	97
	.byte	120
	.byte	141
	.byte	161
	.byte	180
	.byte	197
	.byte	212
	.byte	224
	.byte	235
	.byte	244
	.byte	250
	.byte	253
	.byte	255
	.byte	253
	.byte	250
	.byte	244
	.byte	235
	.byte	224
	.byte	212
	.byte	197
	.byte	180
	.byte	161
	.byte	141
	.byte	120
	.byte	97
	.byte	74
	.byte	49
	.byte	24
	.p2align 2


do_tremolo:                                          ; ***** 07 - tremolo *****
	LDRB	R0,[R11,#currentvol]
	LDR	R1,[R11,#tremolo_speed]                         ;0-3 depth, 4-7 speed, 8-9 wave, 10=no reset, 26-30 pos, 31 sign
	AND	R3,R1,#0x7C000000                               ;=&7C<<24 ;get pos in bits 26-30 (bit 31 is sign, so clear it)
	TST	R1,#0x300
	;ADDEQ   R4,R12,#(vibratotable-song_data) AND &FF00
	;ADDEQ   R4,R4,#(vibratotable-song_data) AND &00FF
	ADREQ	R4,vibratotable_new
	LDREQB	R3,[R4,R3,LSR #26]                           ;not ASR, as b31 just used to flag add/sub value
	BEQ	trem_set                                        ;PT prioritises 0/4 (sine)
	TST	R1,#0x100                                       ;...then 1/5 (sawtooth)
	BNE	trem_rampdown
	MOV	R3,#255                                         ;1 seems to work with 4mat test track  ;...then 2/6 (sqr, and 3/7 treated as 2/6)
trem_set:
	AND	R4,R1,#0x0F                                     ;depth
	MUL	R3,R4,R3                                        ;depth*value
	ANDS	R2,R1,#0xFF000000                              ;R2=bits 26-30 pos (+b31 sign) (b24 & b25=0, because pos 26-30)
	ADDPL	R0,R0,R3,LSR #6
	SUBMIS	R0,R0,R3,LSR #6
	MOVMI	R0,#0
	CMP	R0,#64
	MOVGT	R0,#64
	STRB	R0,[R10,#DMA_volume]
	AND	R1,R1,#0xF0                                     ;=speed in bits %11110000
	ADD	R2,R2,R1,LSL #(24-2)                            ;add speed to pos (bits 26-30 + b31 sign)
	MOV	R2,R2,ASR #24                                   ;keep sign, move to bits 0-7 (v1.49 fix - vibrato was fixed in 1.46a!)
	STRB	R2,[R11,#tremolo_pos]
	B	nextFX

trem_rampdown:
	MOV	R3,R3,LSR #23
	TST	R1,#0x80000000
	RSBNE	R3,R3,#255
	B	trem_set


do_volslide:                                         ; ***** 0A - volume slide *****
	LDRB	R0,[R11,#currentvol]
	TST	R1,#0xF0
	ADDNE	R0,R0,R1,LSR #4
	ANDEQ	R1,R1,#0x0F
	SUBEQ	R0,R0,R1
	CMP	R0,#0
	MOVMI	R0,#0
	CMP	R0,#64
	MOVGT	R0,#64
	STRB	R0,[R11,#currentvol]
	STRB	R0,[R10,#DMA_volume]
	B	nextFX


musicint_unused:                                     ;R1 has data byte here
	MOV	R0,#0x108
	BL	musicinterrupt
	LDMFD	R13!,{R0-R7,PC}


	; align so ADR works with next table
	;EQUD 0;EQUD 0
	.long	0
	.if (qtmrast) == 0
	.long	0
	.endif

amigaperiodz:
	.include "qtm_amiperiods.asm"                       ; 2304 bytes -- PROCinit_amiperiods writes here after assembly




