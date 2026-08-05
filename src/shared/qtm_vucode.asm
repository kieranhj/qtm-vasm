; Generated from QTM_VUcode.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.


swi_qtmreadvulevels:                                 ;R0=0 for 1-4 only, &80 for 1-8
	STMFD	R13!,{R14}
	CMP	R0,#0
	CMPNE	R0,#0x80
	BLNE	checkchannel
	LDMVSFD	R13!,{PC}
	TEQ	R0,#0
	TEQNE	R0,#0x80
	BEQ	loadvuaswords
	LDRB	R14,[R12,#chans_use]
	CMP	R0,R14
	MOVGT	R0,#0
	ADDLE	R14,R12,#vuheights - 1
	LDRLEB	R0,[R14,R0]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{PC}
loadvuaswords:
	TEQ	R0,#0x80
	LDR	R0,[R12,#vuheights]
	LDREQ	R1,[R12,#vuheights58]
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{PC}


swi_qtmvubarctrl:                                    ;R0=0-3 or -1,  R1=gravity or -1
	STMFD	R13!,{R14}                                    ;can be internally called (eg. exit code)
	CMN	R0,#1
	BLT	err_swi_qtmvubarctrl
	CMP	R0,#3
	BGT	err_swi_qtmvubarctrl
	STMFD	R13!,{R2-R3}
	LDRB	R2,[R12,#vustate]
	LDRB	R3,[R12,#vugravity]
	CMN	R0,#1                                           ;if not -1
	CMPNE	R0,R2                                         ;and not same as current
	BLNE	switchVUsoff                                   ;switch vus off (will return if current=0)
	LDMVSFD	R13!,{R2-R3,PC}
	CMP	R0,#1
	CMPNE	R0,#2
	CMPNE	R0,#3
	BLEQ	switchVUson
	LDMVSFD	R13!,{R2-R3,PC}
	MOV	R0,R2
	CMP	R1,#0
	STRGTB	R1,[R12,#vugravity]
	MOV	R1,R3
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R2-R3,PC}
err_swi_qtmvubarctrl:
	MOV	R0,#0x8000000
	SUBS	R0,R0,#1                                       ; Set V
	ADR	R0,err_vustate
	LDMFD	R13!,{PC}


err_vustate:
	.long	(qtm_error + 0xF)
	.byte	"Bad VU controller state"
	.byte	0
	.p2align 2


switchVUsoff:
	CMP	R2,#0
	MOVEQ	PC,R14
	STMFD	R13!,{R0-R2,R14}
	.if (qtmrast) == 0
	MOV	R0,#0x10                                        ;Event not used in RasterMan version, this is called from DMA IRQ
	ADR	R1,VUcontroller
	MOV	R2,R12
	SWI	XOS_Release
	BVS	vus_err
	MOV	R0,#0xD
	MOV	R1,#4
	SWI	XOS_Byte
	.endif
	MOV	R1,#0
	STRB	R1,[R12,#vustate]
	LDMVCFD	R13!,{R0-R2,PC}
vus_err:
	STR	R0,[R13]
	LDMFD	R13!,{R0-R2,PC}


switchVUson:
	CMP	R2,R0
	MOVEQ	PC,R14                                        ;exit if new=current
	STMFD	R13!,{R0-R2,R14}
	STRB	R0,[R12,#vustate]
	.if (qtmrast) == 0
	MOV	R0,#0x10                                        ;Event not used in RasterMan version, this is called from DMA IRQ
	ADR	R1,VUcontroller
	MOV	R2,R12
	SWI	XOS_Claim
	BVS	vus_err
	MOV	R0,#0xE
	MOV	R1,#4
	SWI	XOS_Byte
	.endif
	LDMFD	R13!,{R0-R2,PC}


VUcontroller:
	STMFD	R13!,{R14}
	CMP	R0,#4
	LDMNEFD	R13!,{PC}
	LDRB	R14,[R12,#vustate]
	CMP	R14,#3
	BEQ	realVUs
	CMP	R14,#2
	BEQ	effectVUs
	B	fakeVUs


fakeVUs:                                             ;r14 stored, r12=song_data
	STMFD	R13!,{R0-R5}
	LDRB	R0,[R12,#vuflags]
	LDRB	R1,[R12,#vugravity]
	LDR	R2,[R12,#vuheights]
	MOV	R14,#8
fakevuloop:
	MOV	R5,R2,LSR #0x18
	MOV	R4,R2,LSR #0x10
	AND	R4,R4,#0xFF
	MOV	R3,R2,LSR #8
	AND	R3,R3,#0xFF
	AND	R2,R2,#0xFF
	TST	R0,#1 << 0                                      ;1st/5th chan
	MOVNE	R2,#0x40
	SUBEQ	R2,R2,R1
	CMP	R2,#0
	MOVMI	R2,#0
	TST	R0,#1 << 1                                      ;2nd/6th chan
	MOVNE	R3,#0x40
	SUBEQ	R3,R3,R1
	CMP	R3,#0
	ORRGT	R2,R2,R3,LSL #8
	TST	R0,#1 << 2                                      ;3rd/7th chan
	MOVNE	R4,#0x40
	SUBEQ	R4,R4,R1
	CMP	R4,#0
	ORRGT	R2,R2,R4,LSL #0x10
	TST	R0,#1 << 3                                      ;4th/8th chan
	MOVNE	R5,#0x40
	SUBEQ	R5,R5,R1
	CMP	R5,#0
	ORRGT	R2,R2,R5,LSL #0x18
	SUBS	R14,R14,#8
	STRGE	R2,[R12,#vuheights]
	MOVGE	R2,#0
	STRGEB	R2,[R12,#vuflags]
	LDRGE	R2,[R12,#vuheights58]
	MOVGE	R0,R0,LSR #4
	BGE	fakevuloop
	STR	R2,[R12,#vuheights58]
	LDMFD	R13!,{R0-R5,PC}


effectVUs:                                           ;r14 stored, r12=song_data
	STMFD	R13!,{R0-R6,R10,R11}
	ADD	R11,R12,#channeldata - song_data
	ADD	R10,R12,#DMA_blocks - song_data
	LDRB	R0,[R12,#vuflags]
	LDRB	R1,[R12,#vugravity]
	MOV	R2,#1
	ADD	R3,R12,#vuheights
	MOV	R4,#0
seteffectVUs:
	LDRB	R5,[R3,R4]
	TST	R0,R2,LSL R4
	LDRNEB	R5,[R11,#currentvol]
	BNE	doneeffectVU                                    ;note just played, so set to current volume
	LDRB	R6,[R11,#currentFXnum]
	CMP	R6,#5
	CMPNE	R6,#6
	CMPNE	R6,#0xA
	CMPNE	R6,#0xC
	LDREQB	R5,[R11,#currentvol]                         ;any of those effects, then set height to current volume
	BEQ	doneeffectVU
	CMP	R6,#7                                           ;volume wobble? - set to actual (DMA) volume
	LDREQB	R5,[R10,#DMA_volume]                         ;fixed 29/6/97 (applied 16/4/01!)-didn't read from correct DMA addr
	BEQ	doneeffectVU
	CMP	R6,#0xE
	BNE	graveffectVU                                    ;VU not affected by any effects...
	LDRB	R6,[R11,#currentFXdata]
	MOV	R6,R6,LSR #4
	CMP	R6,#0xA
	CMPNE	R6,#0xB
	CMPNE	R6,#0xC
	CMPNE	R6,#0xD
	LDREQB	R5,[R11,#currentvol]
	BEQ	doneeffectVU
graveffectVU:
	SUBS	R5,R5,R1
	MOVMI	R5,#0
doneeffectVU:
	STRB	R5,[R3,R4]
	ADD	R4,R4,#1
	ADD	R11,R11,#0x40
	ADD	R10,R10,#0x18
	CMP	R4,#8
	BLT	seteffectVUs
	MOV	R0,#0
	STRB	R0,[R12,#vuflags]
	LDMFD	R13!,{R0-R6,R10,R11,PC}


	;
	; New real VU code 18/4/2001
	;
	; This code calculates the VU levels by examining the samples QTM is currently playing
	; rather than scanning the RISC OS DMA buffer data and calculating the levels from there.
	;
	; The new routine produces identical output to scanning the DMA buffer (on 8bit sound comps)
	; however now works on RiscPCs with 16bit sound, which do not have an 8bit sound buffer!
	;


realVUs:                                             ;new realVUs code (gives correct result on 16bit sound)
	STMFD	R13!,{R0-R12}                                 ;r14 stored already
	MOV	R0,#0
	STRB	R0,[R12,#vuflags]
	MOV	R9,R12                                          ;R9=start of QTM vars block (R12 usually)
	ADD	R8,R9,#DMA_blocks - song_data                   ;R8=channel DMA data
	LDRB	R11,[R9,#chans_use]                            ;R11=4 or 8 chans (=4 or 8 bytes to skip each chan byte)
	LDR	R2,[R9,#vuheights]                              ;old heights for channels 1-4
	MOV	R3,#0                                           ;new heights for channels 1-4, 5-8
	MOV	R6,#0
realvu_channelloop:
	BL	realvu_chanctrl                                  ;returns R0=new average vu height for this channel
	AND	R1,R2,#0xFF                                     ;old average vu height for this channel
	ADD	R1,R1,R0
	ORR	R3,R3,R1,LSR #1                                 ;put averaged value in R3
	MOV	R3,R3,ROR #8
	MOV	R2,R2,ROR #8
	ADD	R8,R8,#0x18
	ADD	R6,R6,#1
	TEQ	R6,#4
	STREQ	R3,[R9,#vuheights]                            ;store new heights for channels 1-4
	MOVEQ	R3,#0
	LDREQ	R2,[R9,#vuheights58]                          ;old heights for channels 5-8
	CMP	R6,R11
	BLT	realvu_channelloop
	STR	R3,[R9,#vuheights58]                            ;store new heights for channels 5-8
	LDMFD	R13!,{R0-R12,PC}


realvu_chanctrl:                                     ;r6=channel-1 (0-7)
	STMFD	R13!,{R1-R12,R14}                             ;
	LDMIA	R8,{R0-R5}                                    ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
	CMN	R1,#0x1000                                      ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R7,#3                                         ; <put min loop len in r7>
	CMPGT	R7,R5                                         ; <backwards!!! this does CMP 3,len so LE if valid!!!)
	BGT	realvu_blankchannel                             ;if offset>-4096 and 3>repeat len, then exit
	CMP	R0,#0                                           ;v1.45 - huge bug - can't believe address=0 worked for so long!
	CMPNE	R2,#0
	BLE	realvu_blankchannel                             ;pitch is 0, so sample is blank
realvu_chanrunning:
	MOVS	R3,R3,LSL #0x18                                ;if DMA_sampleflag set, CS because &FF shifted off
	ADDCC	R7,R9,#musicvoltable - song_data
	ADDCS	R7,R9,#samplevoltable - song_data
	LDRB	R3,[R7,R3,LSR #0x18]                           ;load Arc scaled volume
	CMP	R3,#0xFE                                        ;if volume is too low
	BGE	realvu_blankchannel                             ;channel is blank....
	CMP	R2,#0x400                                       ;
	ADDLT	R7,R9,#arcperiods - song_data
	LDRLT	R2,[R7,R2,LSL #2]                             ;load Arc pitch increment
	BLGE	amigatoarcpitch_1024                           ;for high periods, use calculation - returns r2=arc pitch
	CMP	R5,#2                                           ;is this sample a looping sample?
	MOVLT	R5,#2                                         ;if not, make repoff=2, so when sample ends, last 2 bytes repeat
qtm_vucode_adr314:                                   ; FNlong_adr("  ",10,loglintab)
	.long	0xE28FA000-(((loglintab-qtm_vucode_adr314)>>31)&0x00400000)+((((loglintab-qtm_vucode_adr314-8)^((loglintab-qtm_vucode_adr314-8)>>31))-((loglintab-qtm_vucode_adr314-8)>>31))&0xFF)
	.long	0xE28AAC00-(((loglintab-qtm_vucode_adr314)>>31)&0x00400000)+(((((loglintab-qtm_vucode_adr314-8)^((loglintab-qtm_vucode_adr314-8)>>31))-((loglintab-qtm_vucode_adr314-8)>>31))>>8)&0xFF)
	MOV	R11,#0
	MOV	R12,#0x80                                       ;get average real vu height from 128 bytes of DMA data
realvu_sampleloop:                                   ;this code handles samples which play/repeat/end at any vol
	LDRB	R14,[R0,R1,ASR #0xC]                           ;load a byte of sample data
	SUBS	R14,R14,R3                                     ;scale for volume
	BICGT	R14,R14,#1                                    ;make +ve log (=even no.s)
	LDRGTB	R14,[R10,R14]                                ;load +ve linear byte (0-127)
	ADDGT	R11,R11,R14                                   ;if>0 accumulate
	ADDS	R1,R1,R2,LSL #1                                ;add pitch*2, have we ended? (offset becomes GE)?
	SUBGES	R1,R1,R5,LSL #0xC                            ;...if so, get back to repeat start (and check offset now ok)
	SUBGE	R1,R1,R5,LSL #0xC                             ;...if offset still -ve, get back to repeat start
	SUBS	R12,R12,#2
	BGT	realvu_sampleloop                               ;if fake DMA ok and still playing, then loop back
	; now R11 has 64*bytes (0 to 127), so need to divide by 128 (= >>7)to get value 0-63
	MOV	R0,R11,LSR #7                                   ;return R0=average vu level (0-64) for this DMA fill
	;ADD     R0,R0,R0,LSR#2          ;**old** linear scale-up so the vu fills 0-64 better
	;AND     R0,R0,#63               ; (..this on does 0-80, then clips down to 0-63!)
	RSB	R0,R0,#0x40                                     ;better log sq'd scale-up routine (T's ;-)
	MOV	R1,R0                                           ;
	MUL	R0,R1,R0                                        ;
	MOV	R0,R0,LSR #6                                    ;
	RSB	R0,R0,#0x40                                     ;this does 0-64 on a log (sq'd) curve, so low vols are more amp'd
	CMP	R0,R0                                           ; Clear V
	LDMFD	R13!,{R1-R12,PC}


realvu_blankchannel:
	MOV	R0,#0
	LDMFD	R13!,{R1-R12,PC}                              ;exit with R0=vu height for this channel


	;
	; SWI QTM_DMABuffer and fake DMA Buffer creation routine for 16bit sound RiscPCs
	;


swi_qtmdmabuffer:
	LDR	R0,[R12,#fake8bitDMA]
	TEQ	R0,#0
	LDREQ	R0,[R12,#DMABuffer]
	MOVEQ	PC,R14
	STMFD	R13!,{R14}
	BL	calcscope                                        ;update fake DMA block for 16bit-sound RiscPCs
	LDMFD	R13!,{PC}


calcscope:                                           ;called by SWI QTM_DMABuffer on 16bit sound RiscPCs
	STMFD	R13!,{R0-R12,R14}                             ;to generate a fake 8bit sound DMA buffer for progs use!
	MOV	R9,R12                                          ;R9=start of QTM vars block (R12 usually)
	LDR	R12,[R9,#fake8bitDMA]                           ;R12=fake DMA address
	ADD	R8,R9,#DMA_blocks - song_data                   ;R8=channel DMA data
	LDRB	R11,[R9,#chans_use]                            ;R11=4 or 8 chans (=4 or 8 bytes to skip each chan byte)
	ADD	R10,R12,R11,LSL #4
	ADD	R10,R10,R11,LSL #6                              ;v1.45
	ADD	R10,R10,R11,LSL #7                              ;***** fake DMA is always 208 bytes * no. of channels
	MOV	R6,R11
calcscope_channelloop:
	BL	calcscope_chanctrl
	ADD	R8,R8,#0x18
	ADD	R12,R12,#1
	SUBS	R6,R6,#1
	BGT	calcscope_channelloop
	LDMFD	R13!,{R0-R12,PC}


calcscope_chanctrl:
	STMFD	R13!,{R0-R12,R14}                             ;
	LDMIA	R8,{R0-R5}                                    ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
	CMN	R1,#0x1000                                      ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R7,#3                                         ; <put min loop len in r7>
	CMPGT	R7,R5                                         ; <backwards!!! this does CMP 3,len so LE if valid!!!)
	BGT	calcscope_blankchannel                          ;if offset>-4096 and 3>repeat len, then exit
	CMP	R0,#0                                           ;v1.45 - huge bug - can't believe address=0 worked for so long!
	CMPNE	R2,#0
	BLE	calcscope_blankchannel
calcscope_chanrunning:
	MOVS	R3,R3,LSL #0x18                                ;if DMA_sampleflag set, CS because &FF shifted off
	ADDCC	R7,R9,#musicvoltable - song_data
	ADDCS	R7,R9,#samplevoltable - song_data
	LDRB	R3,[R7,R3,LSR #0x18]                           ;load Arc scaled volume
	CMP	R3,#0xFE                                        ;if volume is too low
	BGE	calcscope_blankchannel                          ;go to clear the channel...
	CMP	R2,#0x400                                       ;
	ADDLT	R7,R9,#arcperiods - song_data
	LDRLT	R2,[R7,R2,LSL #2]                             ;load Arc pitch increment
	BLGE	amigatoarcpitch_1024                           ;for high periods, use calculation - returns r2=arc pitch
	CMP	R5,#2                                           ;is this sample a looping sample?
	MOVLT	R5,#2                                         ;if not, make repoff=2, so when sample ends, last 2 bytes repeat
calcscope_sampleloop:                                ;this code handles samples which play/repeat/end at any vol
	LDRB	R6,[R0,R1,ASR #0xC]                            ;load a byte of sample data
	SUBS	R6,R6,R3                                       ;scale for volume
	MOVMI	R6,#0                                         ;reset to 0 if vol too low
	STRB	R6,[R12],R11                                   ;store in fake DMA block
	ADDS	R1,R1,R2                                       ;have we ended (offset becomes GE)?
	SUBGE	R1,R1,R5,LSL #0xC                             ;...if so, get back to repeat start
	CMP	R12,R10                                         ;check fake DMA end...
	BLT	calcscope_sampleloop                            ;if fake DMA ok and still playing, then loop back
	LDMFD	R13!,{R0-R12,PC}


calcscope_blankchannel:
	MOV	R6,#0                                           ;
calcscope_clear:                                     ;
	STRB	R6,[R12],R11                                   ;
	CMP	R12,R10                                         ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;only using 4 blankings per loop...
	BLT	calcscope_clear                                 ;...cleared rest of channel
	LDMFD	R13!,{R0-R12,PC}                              ;exit

