; Generated from QTM_Timer.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.



swi_qtmplayingtime:
	STMFD	R13!,{R14}
	BL	ensuresong
	LDMVSFD	R13!,{PC}
	STMFD	R13!,{R3-R5}
	CMN	R0,#1                                           ;v1.45 are we returning centiseconds (=-1)?
	MOVEQ	R5,#1 << 0xC                                  ;if so, multiplier =1
	MOVNE	R5,#0                                         ;...otherwise return seconds, multiplier =0.01
	ADDNE	R5,R5,#0x28                                   ;...this will only work up to 9.1 hours!
	SWI	XOS_ReadMonotonicTime
	LDR	R1,[R12,#start_time]
	LDR	R2,[R12,#total_time]
	LDR	R3,[R12,#pause_time]
	LDRB	R4,[R12,#songstatus]                           ;v1.44 spotted this was LDR - bug, but was ok as aligned...
	TST	R4,#1 << 2                                      ;playing?
	SUBEQ	R1,R3,R1                                      ;if stopped, time from last QTM_Start to QTM_Pause in r1
	MOVEQ	R0,R2                                         ;            accumulated total time in r0
	SUBNE	R1,R0,R1                                      ;if playing, calc current time since last QTM_Start in r1
	ADDNE	R0,R2,R1                                      ;            calc current total time in r0
	MUL	R0,R5,R0
	MOV	R0,R0,LSR #0xC
	MUL	R1,R5,R1                                        ;v1.45 improvement (was shifted 16 - only up to 18 mins!)
	MOV	R1,R1,LSR #0xC                                  ;      now shifted 12 = works up to 2.9 hours (174 mins)
	LDR	R2,[R12,#est_time]
	CMP	R2,#0
	BLEQ	calctime                                       ;v1.45 now returns r2 in centiseconds
	STREQ	R2,[R12,#est_time]
	MUL	R2,R5,R2
	MOV	R2,R2,LSR #0xC
	LDMFD	R13!,{R3-R5,PC}


	;
	;  QTM v1.22 timer code (c) 1993/4/5 Phoenix/Quantum
	;


tmr_crashed:
	MOV	R0,#0x80000000
	SUBS	R0,R0,#1                                       ; Set V
	LDMFD	R13!,{R0-R1,R3-R11,R14}
	ADR	R0,err_worktime
	MOV	PC,R14

err_worktime:
	.long	(qtm_error + 0xE)
	.byte	"Song time could not be calculated or song lasts over 9 hours!",0x00
	.p2align 2


tmr_setlinetime:
	;
	; R9  s=speed
	; R10 c=CIA tempo
	;
	; equation; time per line=10s/4c (*65536 for accuracy)
	;
	STMFD	R13!,{R0-R1,R14}
	MOV	R0,#0x28000
	MUL	R0,R9,R0
	MOV	R1,R10
	BL	r0_div_r1                                        ;do (10s<<16)/4c - result in r0<<16
	MOV	R8,R0
	LDMFD	R13!,{R0-R1,PC}


	; R12=song_data
	; R11=address of current word
	; R10=CIA tempo (32-255)
	; R9=speed (1-31)
	; R8=time per line = (10*speed/4*cia tempo)*65536
	; R7=time so far
	; R6=channel-1 (0-4/6/8)
	; R5=current word
	; R4=sequence
	; R3=event


calctime:
	STMFD	R13!,{R0-R1,R3-R11,R14}
	BL	tmr_resetvars
	MOV	R10,#0x7D
	MOV	R9,#6
	BL	tmr_setlinetime                                  ;R8=line time
	MOV	R7,#0                                           ;R7=total time
	MOV	R4,#0
	MOV	R3,#0
tmr_mainloop:
	LDRB	R0,[R12,#tm_patterndelay]
	CMP	R0,#0
	BNE	tmr_checkpattdel                                ;...pattern delayed...
	LDR	R3,[R12,#tm_currentevent]                       ;r3=sequence (16-24) event (0-7)
	MOV	R4,R3,LSR #0x10
	AND	R3,R3,#0xFF
	STRB	R4,[R12,#tm_lastsequence]
	LDR	R11,[R12,#songaddr]                             ;r11=song address
	ADD	R11,R11,#0x3B8                                  ;r11=sequence table address
	LDRB	R0,[R11,R4]                                    ;r0=pattern
	ADD	R11,R11,#0x84                                   ;add 132, to get to start of patterns, and put in r11
	LDR	R6,[R12,#patternlen]                            ;v1.44 support for 8CHN and 6CHN
	MLA	R11,R0,R6,R11                                   ;add current patt*patternlen to pattern start
	MOV	R6,R6,LSR #6                                    ;patternlen/64=eventlen (16/24/32 for 4, 8FLT/6/8)
	MLA	R11,R3,R6,R11                                   ;add on current event*event length (no longer just 16)
	MOV	R6,#0                                           ;r6=channel-1
tmr_dochannels:
	;TEQ     R6,#4                   ;v1.45 update, no longer need this...
	;LDREQB  R5,[R12,#songtype]      ;if chan 4 we must be > 4 chans (0-3) so either 6 or 8
	;TEQEQ   R5,#&10                 ;if also 'FLT8' type, need to get to next patt, add 1024
	;ADDEQ   R11,R11,#1024-16        ;...just a fudge-thing really
	LDR	R5,[R11,R6,LSL #2]                              ;load note word for this channel (r5)
	AND	R0,R5,#0xF0000                                  ; \
	CMP	R0,#0xB0000                                     ;  \_ if effects B,D,E,F
	CMPNE	R0,#0xD0000                                   ;  /  then deal with them...
	BLGE	tmr_checkoutFX                                 ; /
	LDRB	R0,[R12,#songchans]
	ADD	R6,R6,#1                                        ;add 1 to the channel counter
	CMP	R6,R0                                           ;is <4 or 8 (no more channels to do)?
	BLT	tmr_dochannels                                  ;if not, then loop back
	CMP	R9,#0                                           ;is speed 0, after doing all channels?
	BEQ	tmr_gottime                                     ;if so, we've got the time!
tmr_checkpattdel:
	LDRB	R0,[R12,#tm_patterndelay]
	SUBS	R0,R0,#1
	STRGEB	R0,[R12,#tm_patterndelay]                    ;take off pattern delay (if running)
	LDR	R3,[R12,#tm_currentevent]                       ;load r3 with sequence (16-23) event (0-7)
	ADDLE	R3,R3,#1                                      ;add 1 to event counter
	MOV	R4,R3,LSR #0x10
	LDRB	R0,[R12,#tm_breakflags]                        ;load the break flag byte
	CMP	R0,#0                                           ;is it 0?
	BNE	tmr_checkjumps                                  ;if so, go to jump checking routine...
tmr_checkevent:
	TST	R3,#0x40                                        ;are we still in this pattern (- is bit 6 clear)?
	STREQB	R3,[R12,#tm_currentevent]                    ;if so, so store event counter
	BEQ	tmr_nextline
	MOV	R3,#0                                           ;set event counter to 0, because we are at a new pattern
tmr_brokepattern:                                    ;  **-{pattern break code entry}-**
	ADD	R4,R4,#1                                        ;add 1 to current sequence
tmr_jumped2seq:                                      ; **-{jump to sequence code entry}-** <<< unused now >>>
	LDRB	R0,[R12,#maxsequence]
	CMP	R4,R0                                           ;is current sequence > max sequence?
	BGE	tmr_gottime
	LDRB	R2,[R12,#tm_lastsequence]                      ;load last sequence num
	CMP	R4,R2                                           ;is current sequence < last sequence?
	BLE	tmr_gottime
	ORR	R3,R3,R4,LSL #0x10
	STR	R3,[R12,#tm_currentevent]                       ;store sequence and event together
tmr_nextline:
	ADDS	R7,R7,R8
	BPL	tmr_mainloop
	B	tmr_crashed                                       ;if number has got too large and become negative, bad...


tmr_gottime:
	ADDLE	R7,R7,R8                                      ;v1.45 previously forgot to add time for the final line!!!
	MOV	R2,R7,LSR #7                                    ;
	MOV	R0,#0x64                                        ;v1.45 return value in centiseconds, for improved accuracy
	MUL	R2,R0,R2                                        ;      (may be better to redo linetime calc...consider...)
	MOV	R2,R2,LSR #9                                    ;put total time, in centiseconds, into r2...
	LDMFD	R13!,{R0-R1,R3-R11,PC}                        ;                                     ...and exit


tmr_checkjumps:                                      ; ** r4=sequence r3=event **
	MOV	R1,#0
	STRB	R1,[R12,#tm_breakflags]                        ;clear breakflags
	TST	R0,#1                                           ;is bit 1 set (='jump to seq')?
	LDRNEB	R3,[R12,#tm_pattbreakpos]                    ;for this code to be reached!!!
	BNE	tmr_brokepattern                                ;then go to update sequence code...
	;TST     R0,#%10                ;no need to test for loop flags - this is the only one
	LDRB	R3,[R12,#tm_pattbreakpos]                      ;if bit 2 set (='pattern loop') then load loop pos
	STRB	R3,[R12,#tm_currentevent]
	B	tmr_nextline


	;**********************************************************
	;*          'check out effects' routine next...           *
	;**********************************************************


tmr_checkoutFX:                                      ;r5=note word, r6=channel
	STMFD	R13!,{R0-R6,R14}                              ;only called with effects B,D,E,F
	AND	R0,R5,#0xF0000
	MOV	R0,R0,LSR #0x10
	MOV	R1,R5,LSR #0x18
	LDR	R2,[R12,#FXflags]                               ;load effect status flags
	MOV	R3,#1
	TST	R2,R3,LSL R0                                    ;is this effect's flag set on?
	BEQ	tmr_badFX                                       ;if not, skip it...
	CMP	R0,#0xB
	BEQ	tmr_jump2seq                                    ;B - jump to sequence
	CMP	R0,#0xD
	BEQ	tmr_patternbreak                                ;D - pattern break
	CMP	R0,#0xE
	BEQ	tmr_E_effects                                   ;E - E effects/commands
	BNE	tmr_setspeed                                    ;F - set speed/tempo
tmr_badFX:
	LDMFD	R13!,{R0-R6,PC}


	;**********************************************************
	;*         'check out E effects' routine next...          *
	;**********************************************************


tmr_E_effects:                                       ;r0=effect number (always &E!!!), r1=FX data, r9=channel
	MOV	R0,R1,LSR #4                                    ;r0 now has E effect number
	AND	R1,R1,#0xF                                      ;r1 now has data nibble for E effect
	LDR	R2,[R12,#E_FXflags]                             ;load E effect status flags
	MOV	R3,#1
	TST	R2,R3,LSL R0                                    ;is this effect's flag set on?
	BEQ	tmr_badFX                                       ;if not, skip it...
	CMP	R0,#6
	BEQ	tmr_pattloop                                    ;E6 - pattern loop
	CMP	R0,#0xE
	BEQ	tmr_pattdelay                                   ;EE - pattern delay
	B	tmr_badFX


tmr_jump2seq:                                        ; ***** 0B - jump to sequence *****
	MOV	R0,#1
	STRB	R0,[R12,#tm_breakflags]
	SUB	R1,R1,#1
	STRB	R1,[R12,#tm_currentseq]
	MOV	R0,#0
	STRB	R0,[R12,#tm_pattbreakpos]
	LDMFD	R13!,{R0-R6,PC}


tmr_patternbreak:                                    ; ***** 0D - pattern break *****
	MOV	R0,#1
	STRB	R0,[R12,#tm_breakflags]
	MOV	R0,R1,LSR #4
	AND	R1,R1,#0xF
	ADD	R1,R1,R0,LSL #3
	ADD	R1,R1,R0,LSL #1
	CMP	R1,#0x3F
	MOVGT	R1,#0                                         ;if >63, set it to 0, but don't clear break flags
	STRB	R1,[R12,#tm_pattbreakpos]
	LDMFD	R13!,{R0-R6,PC}


tmr_setspeed:                                        ; ***** 0F - set speed/tempo *****
	CMP	R1,#0x20
	MOVGE	R10,R1
	MOVLT	R9,R1
	CMP	R1,#0
	;BEQ     tmr_stopspeed          ;check stop speed after ALL channels done!
	BLNE	tmr_setlinetime                                ;(?don't set time, if speed 0?)
	LDMFD	R13!,{R0-R6,PC}


	;.tmr_stopspeed
	;LDMFD   R13!,{R0-R6,R14}
	;B       tmr_gottime


tmr_pattloop:                                        ; ***** E6 - pattern loop *****
	ADD	R2,R12,#tm_pattloopstart & 0xFF00
	ADD	R2,R2,#tm_pattloopstart & 0xFF
	ADD	R3,R2,#tm_pattloopcount - tm_pattloopstart
	CMP	R1,#0
	LDREQB	R0,[R12,#tm_currentevent]
	STREQB	R0,[R2,R6]
	LDMEQFD	R13!,{R0-R6,PC}                             ;if 'set loop', load event and put it in loop start
	LDRB	R0,[R3,R6]
	SUBS	R0,R0,#1                                       ;load current loop value, sub 1
	MOVMIS	R0,R1                                        ; if now <0 then it was 0 (so not in a loop) so set new
	STRGEB	R0,[R3,R6]                                   ; if new value used or (value-1)>=0, then store new value
	LDMEQFD	R13!,{R0-R6,PC}                             ; if (value-1)=0 then loop has ended, so exit
	LDRB	R0,[R2,R6]
	STRB	R0,[R12,#tm_pattbreakpos]                      ;store loop position in break pos
	LDRB	R0,[R12,#tm_breakflags]
	ORR	R0,R0,#2
	STRB	R0,[R12,#tm_breakflags]                        ;set break flags
	LDMFD	R13!,{R0-R6,PC}


tmr_pattdelay:                                       ; ***** EE - pattern delay *****
	LDRB	R0,[R12,#tm_patterndelay]
	CMP	R0,#0
	ADDEQ	R1,R1,#1
	STREQB	R1,[R12,#tm_patterndelay]                    ;add 1 to delay, and only store if not already in a delay!
	LDMFD	R13!,{R0-R6,PC}


	;.tmr_pattloopstart EQUD 0       ;w  - 1b per chan
	;                   EQUD 0       ;w  - 1b per chan
	;.tmr_pattloopcount EQUD 0       ;w  - 1b per chan
	;                   EQUD 0       ;w  - 1b per chan
	;.tmr_currentevent  EQUW 0       ;2b
	;.tmr_currentseq    EQUW 0       ;2b
	;.tmr_patterndelay  EQUB 0       ;b
	;.tmr_breakflags    EQUB 0       ;b
	;.tmr_pattbreakpos  EQUB 0       ;b
	;.tmr_lastsequence  EQUB 0       ;b
	;ALIGN

tmr_resetvars:
	STMFD	R13!,{R0,R14}
	MOV	R0,#0
	STR	R0,[R12,#tm_pattloopstart]
	STR	R0,[R12,#tm_pattloopstart + 4]
	STR	R0,[R12,#tm_pattloopcount]
	STR	R0,[R12,#tm_pattloopcount + 4]
	STR	R0,[R12,#tm_currentevent]                       ;& seq
	STR	R0,[R12,#tm_patterndelay]                       ;_
	;STRB    R0,[R12,#tm_breakflags]   ; } \
	;STRB    R0,[R12,#tm_pattbreakpos] ; }  }- all blanked by STR R0,tmr_patterndelay
	;STRB    R0,[R12,#tm_lastsequence] ; } /
	LDMFD	R13!,{R0,PC}

