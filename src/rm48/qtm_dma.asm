; Generated from QTM_DMA.bas by tools/bas2vasm.py -- do not hand-edit.
; Mechanical translation; verify against ref/listing.txt.



	; on entry
	;          R0          \  sample end address            - sample end address
	;          R1           } -ve sample offset             - -ve sample offset
	;          R2           } (amiga type) pitch            - sample pitch increment (Arc)
	;          R3           } linear volume (0-64)          - sample volume (0-255)
	;          R4           } -ve repeat offset             - -ve repeat offset
	;          R5          /                                - load/store sample byte
	;          R6      -ve if channel handler changed       - channel counter (0->channel-1)
	;          R7      <unknown>                            -
	;          R8      uS <? - unknown>                     - ptr to 'DMA_blocks'
	;          R9      ptr to initblock                     - ptr to 'song_data' (usually R12)
	;          R10     DMA end                              - DMA end
	;          R11     DMA gap                              - DMA gap
	;          R12     DMA start                            - DMA ptr
	;          R13     stack                                - stack
	;          R14     exit                                 - end

a3_DMAsound:
	STMFD	R13!,{R14}
	SUB	R9,R9,#QTMblock                                 ;R9=start of QTM vars block (R12 usually)
	STR	R12,[R9,#DMABuffer]
	LDRB	R0,[R9,#armchip]
	CMP	R0,#3                                           ;* cache detection only works on Arm 3  *
	.long	0x0E120F10                                    ;* read Arm3 control state (cache etc.) *
	TSTLE	R0,#0b1                                       ;* and so no need to worry about 32-bitting Arm2 code ;) *
	BEQ	a2_DMAsnd_in
	LDRB	R0,[R9,#soundflags]
	TST	R0,#8                                           ;are we manually calculating the clock speed (pre-A5000 only)?
	BLNE	checkclockcalc
	.if qtmrast
	LDRB	R0,[R9,#rm_dmainprogress]                      ;
	TEQ	R0,#0                                           ;
	LDMNEFD	R13!,{PC}                                   ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
	MOV	R0,#1                                           ;
	STRB	R0,[R9,#rm_dmainprogress]                      ;
	;
	MOV	R12,R9                                          ;* v1.43se RasterMan special release (2013)
	LDRB	R0,[R9,#songstatus]                            ;* are we playing the song?
	TST	R0,#4                                           ;*
	BLNE	CIAhandler                                     ;* if so, sort the music first
	;*
	LDRB	R0,[R9,#vustate]                               ;* 1.43se_a 27/5/13
	CMP	R0,#0                                           ;*
	MOVNE	R0,#4                                         ;*
	BLNE	VUcontroller                                   ;*
	LDR	R12,[R9,#DMABuffer]                             ;* v1.45se reload R12
	.endif
	ADD	R8,R9,#DMA_blocks-song_data
	MOVS	R6,#0                                          ;put channel count as 0
	LDRB	R5,[R9,#chans_use]
	LDR	R4,[R9,#chanendflags]
a3_DMAchannels:
	BL	a3_chanctrl
	STR	R1,[R8,#DMA_offset]                             ;a3_chanend may skip this on return from a3_chanctrl
a3_DMAnextchan:
	MOV	R4,R4,LSR #2
	ADD	R8,R8,#24
	ADD	R12,R12,#1
	ADD	R6,R6,#1
	CMP	R6,R5
	BNE	a3_DMAchannels
	.if qtmrast
	MOV	R0,#0
	STRB	R0,[R9,#rm_dmainprogress]
	.endif
	LDMFD	R13!,{PC}


a3_chanctrl:                                         ;r6=channel number
	STMFD	R13!,{R4-R6,R12,R14}                          ;
	LDMIA	R8,{R0-R5}                                    ;r0=end addr r1=-ve offset r2=pitch r3=vol/flag r4=raddr r5=rlen
	CMN	R1,#4096                                        ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R7,#3                                         ; <put min loop len in r7>
	CMPGT	R7,R5                                         ; <backwards!!! this does CMP 3,len so LE if valid!!!)
	BGT	a3_chanend                                      ;if offset>-4096 and 3>repeat len, then exit
	CMP	R0,#0                                           ;v1.45 fixed huge bug, can't believe addr=0 worked for so long!
	CMPNE	R2,#0
	BLE	a3_chanend
a3_chanrunning:
	MOVS	R3,R3,LSL #24                                  ;if DMA_sampleflag set, CS because &FF shifted off
	ADDCC	R7,R9,#musicvoltable-song_data
	ADDCS	R7,R9,#samplevoltable-song_data
	LDRB	R3,[R7,R3,LSR #24]                             ;load Arc scaled volume
	CMP	R2,#1024                                        ;
	ADDLT	R7,R9,#arcperiods-song_data
	LDRLT	R2,[R7,R2,LSL #2]                             ;load Arc pitch increment
	BLGE	amigatoarcpitch_1024                           ;for high periods, use calculation - returns r2=arc pitch
	MOV	R7,#0b11                                        ;testing flags...
	;** R6 STILL has channel number in it!!! **
	MOV	R6,R6,LSL #1                                    ;channel * 2 (2 flags per channel!)
	MOV	R7,R7,LSL R6                                    ;shift flags << (channel*2)
	LDR	R6,[R9,#chanendflags]                           ;load current channel ending flags
	TST	R6,R7                                           ;are either of the 'ending/ended' bits set?
	BICNE	R6,R6,R7                                      ;if so, clear them, cos this channel IS running!
	STRNE	R6,[R9,#chanendflags]                         ;...and store them
	LDRB	R6,[R9,#actual_dma]                            ;v1.45 load the actual DMA size set by Sound_Configure
	MOV	R6,R6,LSL #4                                    ;...because we don't know what DMA size might be on RPi etc...
	MLAS	R6,R2,R6,R1                                    ;...mul to get ptr to offset at end of fill (10 cycles vs 3 prev)
	BLT	a3_not_ending                                   ;if still<0 then we haven't ended/looped, so don't check
	; CMP R5,#3
	; BGE a2_repeating -> a2 checks for repeating here
	;
	CMP	R3,#254                                         ;if volume is too low
	BGE	a3_endnovol                                     ;go to clear the channel...
	CMP	R3,#0                                           ;
	BEQ	a3_endfullvol                                   ;if vol is max. use max. vol fill routines
a3_endanyvol:                                        ;*** sample HAS TO end/repeat this TIME  ***
	LDRB	R6,[R0,R1,ASR #12]                             ;*** so we DON'T have to check to see if ***
	SUBS	R6,R6,R3                                       ;*** DMA ends - sample MUST end first!!! ***
	MOVMI	R6,#0                                         ;
	STRB	R6,[R12],R11                                   ;
	ADDS	R1,R1,R2                                       ;have we ended (offset becomes GE)?
	BLT	a3_endanyvol                                    ;if not... loop back
	CMP	R5,#2                                           ;
	BGT	a3_repanyvol                                    ;are we looping this time? - if so, lets go!
	MOV	R6,#0                                           ;
a3_endclear:                                         ;
	STRB	R6,[R12],R11                                   ;
	CMP	R12,R10                                         ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;only using 4 blankings per loop...
	BLT	a3_endclear                                     ;...cleared rest of channel
	LDMFD	R13!,{R4-R6,R12,PC}                           ;exit


a3_endfullvol:                                       ;*** sample HAS to end/repeat this time  ***
	LDRB	R6,[R0,R1,ASR #12]                             ;*** so we DON'T have to check to see if ***
	STRB	R6,[R12],R11                                   ;*** DMA ends - sample MUST end first!!! ***
	ADDS	R1,R1,R2                                       ;have we ended (offset becomes GE)?
	LDRLTB	R6,[R0,R1,ASR #12]
	STRLTB	R6,[R12],R11
	ADDLTS	R1,R1,R2
	BGE	a3_endedfv
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	LDRLTB	R6,[R0,R1,ASR #12]
	STRLTB	R6,[R12],R11
	ADDLTS	R1,R1,R2                                     ;only using 4 stores per loop...
	BLT	a3_endfullvol                                   ;if not... loop back
a3_endedfv:
	CMP	R5,#2                                           ;
	BGT	a3_repfullvol                                   ;are we looping this time? - if so, lets go!
	MOV	R6,#0                                           ;
a3_endfvclear:                                       ;
	STRB	R6,[R12],R11                                   ;
	CMP	R12,R10                                         ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;
	STRLTB	R6,[R12],R11                                 ;
	CMPLT	R12,R10                                       ;only using 4 blankings per loop...
	BLT	a3_endfvclear                                   ;...cleared rest of channel
	LDMFD	R13!,{R4-R6,R12,PC}                           ;exit


a3_endnovol:
	CMP	R5,#2
	BGT	a3_repnovol
	BL	a3_clearchannel
	MOV	R1,#0                                           ;set offset to 0, so it will call 'chanend' next time
	LDMFD	R13!,{R4-R6,R12,PC}


a3_repanyvol:                                        ;** NEW repeat handler **
	SUB	R1,R1,R5,LSL #12                                ;ready to repeat... set offset back to repeat start...
a3_repavloop:                                        ;
	LDRB	R6,[R4,R1,ASR #12]                             ;** remember to use REPEAT end address **
	SUBS	R6,R6,R3                                       ;
	MOVMI	R6,#0                                         ;
	STRB	R6,[R12],R11                                   ;
	ADDS	R1,R1,R2                                       ;finished repeat?
	CMPLT	R12,R10                                       ;if NOT finished, then check DMA end...
	BLT	a3_repavloop                                    ;if DMA ok and still repeating, then loop back
	TST	R1,#0x80000000                                  ;was it sample that ended? (this WON'T alter C flag)
	SUBEQ	R1,R1,R5,LSL #12                              ;...if so, get back to repeat start
	CMP	R12,R10                                         ;(could both end at same time as well!)
	BLT	a3_repavloop                                    ;if C is clear (& DMA not finished) then loop back...
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}


a3_repfullvol:
	SUB	R1,R1,R5,LSL #12                                ;ready to repeat... set offset back to repeat start...
a3_repfvloop:                                        ;
	LDRB	R6,[R4,R1,ASR #12]
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	CMPLT	R12,R10
	BLT	a3_repfvloop
	TST	R1,#0x80000000                                  ;was it sample that ended? (this WON'T alter C flag)
	SUBEQ	R1,R1,R5,LSL #12                              ;...if so, get back to repeat start
	CMP	R12,R10
	BLT	a3_repfvloop                                    ;if C is clear (ie. DMA not finished) then loop back...
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}


a3_repnovol:
	MOV	R6,#0
a3_repnovolloop:
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	CMPLT	R12,R10
	STRLTB	R6,[R12],R11
	ADDLTS	R1,R1,R2
	CMPLT	R12,R10
	BLT	a3_repnovolloop
	TST	R1,#0x80000000                                  ;was it sample that ended? (this WON'T alter C flag)
	SUBEQ	R1,R1,R5,LSL #12                              ;...if so, get back to repeat start
	CMP	R12,R10
	BLT	a3_repnovolloop                                 ;if C is clear (ie. DMA not finished) then loop back...
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}


a3_clearchannel:
	STMFD	R13!,{R6}
	MOV	R6,#0
a3_clearing:
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11                                   ;do 8
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11
	STRB	R6,[R12],R11                                   ;do 16
	CMP	R12,R10
	BLT	a3_clearing
	LDMFD	R13!,{R6}
	MOV	PC,R14


a3_not_ending:                                       ;on entry r5 = end offset
	CMP	R3,#254                                         ;volume too low?
	MOVGE	R1,R6                                         ;yup, so put end offset in offset reg...
	BLGE	a3_clearchannel                                ;...and clear the channel!
	LDMGEFD	R13!,{R4-R6,R12,PC}                         ;...then exit
	CMP	R3,#0                                           ;
	BEQ	a3_fullvolume                                   ;max. vol, so use max. routines
a3_anyvolume:
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 1
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 2
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 3
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 4
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 5
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 6
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 7
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11                                   ;store 8
	ADD	R1,R1,R2
	CMP	R12,R10
	BLT	a3_anyvolume
	LDMFD	R13!,{R4-R6,R12,PC}


a3_fullvolume:
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;1
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;2
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;3
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;4
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;5
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;6
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;7
	ADD	R1,R1,R2
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11                                   ;8
	ADD	R1,R1,R2
	CMP	R12,R10
	BLT	a3_fullvolume
	LDMFD	R13!,{R4-R6,R12,PC}


	; channel ending flags
	;                       %11 per channel (should be CLEAR when playing the sample)
	;                       /  \
	;   cleared DMA buffer 1    cleared DMA buffer 2 (so sample has REALLY finished - exit)


a3_chanend:
	LDR	R4,[R13,#0]                                     ;load channel end flags (r4)
	MOVS	R4,R4,LSR #1                                   ;shift off the first bit (REALLY ended test)
	LDMCSFD	R13!,{R4-R6,R12,R14}                        ;if it had 'REALLY ended' then reload (inc. r4) and exit
	ADDCS	PC,R14,#4                                     ;Skip STR R1,[R8,#DMA_offset] instruction
	BL	a3_clearchannel                                  ;clear this DMA buffer
	LDR	R6,[R13,#8]                                     ;load current channel (-1)
	MOV	R6,R6,LSL #1                                    ;channel*2
	MOVS	R4,R4,LSR #1                                   ;test 2nd bit of channel end flags
	LDR	R4,[R9,#chanendflags]                           ;(+load FULL current flags word, for alteration)
	MOVCC	R5,#0b10                                      ;if 2nd bit was clear, then channel has JUST ended
	MOVCS	R5,#0b01                                      ;if 2nd bit was set, then it ended 1 DMA fill ago (ie.done)
	ORR	R4,R4,R5,LSL R6                                 ;set altered flags in flag word
	STR	R4,[R9,#chanendflags]                           ;store flag word
	LDMFD	R13!,{R4-R6,R12,PC}                           ;reload+exit WITHOUT C flag set (so new offset is stored)


	;
	;
	;
	;


a3_TRNSsound:
	STMFD	R13!,{R9,R14}
	SUB	R9,R9,#QTMblock                                 ;R9=start of QTM vars block (R12 usually)
	STR	R12,[R9,#DMABuffer]
	LDRB	R0,[R9,#armchip]
	CMP	R0,#3                                           ;* cache detection only works on Arm 3 *
	.long	0x0E120F10                                    ;read Arm3 control state (cache etc.)
	TSTEQ	R0,#0b1
	BEQ	a2_TRNSsnd_in
	LDR	R9,[R9,#oldConfigure+12]                        ;transparent sound...!
	MOV	R14,PC                                          ;
	LDR	PC,[R9,#0]                                      ;go... and then back to QTM...
	LDMFD	R13!,{R9}                                     ;v1.49 replace FNlong_adr("  ",9,song_data)
	SUB	R9,R9,#QTMblock                                 ;R9=start of QTM vars block (R12 usually)
	LDRB	R0,[R9,#soundflags]
	TST	R0,#8
	BLNE	checkclockcalc
	.if qtmrast
	LDRB	R0,[R9,#rm_dmainprogress]                      ;
	TEQ	R0,#0                                           ;
	LDMNEFD	R13!,{PC}                                   ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
	MOV	R0,#1                                           ;
	STRB	R0,[R9,#rm_dmainprogress]                      ;
	;
	MOV	R12,R9                                          ;* v1.43se RasterMan special release (2013)
	LDRB	R0,[R9,#songstatus]                            ;* are we playing the song?
	TST	R0,#4                                           ;*
	BLNE	CIAhandler                                     ;* if so, sort the music first
	;*
	LDRB	R0,[R9,#vustate]                               ;* 1.43se_a 27/5/13
	CMP	R0,#0                                           ;*
	MOVNE	R0,#4                                         ;*
	BLNE	VUcontroller                                   ;*
	LDR	R12,[R9,#DMABuffer]                             ;* v1.45se reload R12
	.endif
	ADD	R8,R9,#DMA_blocks-song_data
	MOV	R6,#0                                           ;put channel count as 0
	LDRB	R5,[R9,#chans_use]
	LDR	R4,[R9,#chanendflags]
	LDRB	R0,[R9,#armchip]
	CMP	R0,#6
	BGE	a6_TRNSchannels
a3_TRNSchannels:
	TEQP	PC,#0x8000003                                  ;-> SVC, no interrupts
	ADD	R0,R6,#1
	MOV	R1,#0
	STMFD	R13!,{R14}
	SWI	XSound_ReadControlBlock
	LDMFD	R13!,{R14}
	TEQP	PC,#0x8000002                                  ;-> IRQ, no interrupts
	TST	R2,#0x8000000                                   ;Q  K  I  F  A  V F2 F1
	ADR	R14,a3_TRNSnextchan                             ;
	BNE	an_TRNSchan                                     ;            * - TSS chan active, don't fill DMA, update off/rep
	B	a3_chanctrl                                       ;              - TSS chan not active, fill with QTM sample
a3_TRNSnextchan:
	STR	R1,[R8,#4]
	MOV	R4,R4,LSR #2
	ADD	R8,R8,#24
	ADD	R12,R12,#1
	ADD	R6,R6,#1
	CMP	R6,R5
	BNE	a3_TRNSchannels
	.if qtmrast
	MOV	R0,#0
	STRB	R0,[R9,#rm_dmainprogress]
	.endif
	LDMFD	R13!,{PC}                                     ;v1.43 removed ^ - to enable Arthur OS compatibility!


a6_TRNSchannels:                                     ;32bit compatible code for ARM6+
	.long	0xE10F0000                                    ; FNmrs("","R0,CPSR")
	ORR	R1,R0,#0x83                                     ;-> SVC, no interrupts
	.long	0xE121F001                                    ; FNmsr("","CPSR_c,R1")
	STMFD	R13!,{R0,R14}
	ADD	R0,R6,#1                                        ;r0=channel
	MOV	R1,#0
	SWI	XSound_ReadControlBlock
	LDMFD	R13!,{R0,R14}
	.long	0xE121F000                                    ;-> IRQ, no interrupts
	TST	R2,#0x8000000                                   ;Q  K  I  F  A  V F2 F1
	ADR	R14,a6_TRNSnextchan                             ;
	BNE	an_TRNSchan                                     ;            * - TSS chan active, don't fill DMA, update off/rep
	B	a3_chanctrl                                       ;              - TSS chan not active, fill with QTM sample
a6_TRNSnextchan:
	STR	R1,[R8,#4]                                      ;store updated sample offset
	MOV	R4,R4,LSR #2                                    ;next block of chanendflags
	ADD	R8,R8,#24                                       ;next QTM DMA block
	ADD	R12,R12,#1                                      ;next DMA buffer offset
	ADD	R6,R6,#1                                        ;channel counter 0-3 or 0-7
	CMP	R6,R5                                           ;have we reached chans_use?
	BNE	a6_TRNSchannels                                 ;no, so loop
	LDMFD	R13!,{PC}


an_TRNSchan:                                         ;this code does not fill DMA, just updates sample offset/repeats
	STMFD	R13!,{R4-R6,R12,R14}
	LDMIA	R8,{R0-R5}                                    ;r0=end addr r1=-ve offset r2=pitch r3=vol/flag r4=raddr r5=rlen
	CMN	R1,#4096                                        ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R7,#3                                         ; <put min rep len in r7>
	CMPGT	R7,R5                                         ; <backwards!!! this does CMP 3,rlen so LE if valid!!!)
	;BGT     a3_chanend              ;if offset>-4096 and 3>rep len, then exit **?v1.45 fixed bug?**
	LDMGTFD	R13!,{R4-R6,R12,PC}                         ;if offset>-4096 and 3>repeat len, then exit
	CMP	R0,#0                                           ;v1.45 fixed huge bug, can't believe addr=0 worked for so long!
	CMPNE	R2,#0
	LDMLEFD	R13!,{R4-R6,R12,PC}                         ;(another bug fix v1.45) note <=0, exit
	; no need for volume setting code
	CMP	R2,#1024                                        ;
	ADDLT	R7,R9,#arcperiods-song_data
	LDRLT	R2,[R7,R2,LSL #2]                             ;load Arc pitch increment
	BLGE	amigatoarcpitch_1024                           ;for high periods, use calculation - returns r2=arc pitch
	; no need for DMA channel ending code
	LDRB	R12,[R9,#actual_dma]                           ;v1.45 load the actual DMA size set by Sound_Configure
	MOV	R12,R12,LSL #4                                  ;...because we don't know what DMA size might be on RPi etc...
	MLAS	R6,R2,R12,R1                                   ;...mul to get ptr to offset at end of fill (10 cycles vs 3 prev)
	MOVLT	R1,R6                                         ;
	LDMLTFD	R13!,{R4-R6,R12,PC}                         ;if still<0 then we haven't ended/looped, so don't check
	CMP	R5,#2                                           ;
	MOVLE	R1,#0                                         ;
	LDMLEFD	R13!,{R4-R6,R12,PC}                         ;exit with r1 offset=0 if no repeat
	;bug fix v1.49, was MOV R12,#208 (DMA) now R12=actual DMA (above)
an_TRNSrepeat:                                       ;if repeat length>2 then we're repeating...
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	SUBS	R12,R12,#8                                     ;do this 8 times, for best Arm3/Arm2 looping speeds
	BGT	an_TRNSrepeat                                   ; - though Arm2 looses out a bit!
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}




a2_TRNSsound:
	STMFD	R13!,{R9,R14}
	SUB	R9,R9,#QTMblock
	STR	R12,[R9,#DMABuffer]
a2_TRNSsnd_in:
	LDR	R9,[R9,#oldConfigure+12]                        ;transparent sound...!
	MOV	R14,PC                                          ;
	LDR	PC,[R9,#0]                                      ;go... and then back to QTM...
	LDMFD	R13!,{R9}                                     ;v1.49 replace FNlong_adr("  ",9,song_data)
	SUB	R9,R9,#QTMblock                                 ;R9=start of QTM vars block (R12 usually)
	LDRB	R0,[R9,#soundflags]
	TST	R0,#8
	BLNE	checkclockcalc
	.if qtmrast
	LDRB	R0,[R9,#rm_dmainprogress]                      ;
	TEQ	R0,#0                                           ;
	LDMNEFD	R13!,{PC}                                   ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
	MOV	R0,#1                                           ;
	STRB	R0,[R9,#rm_dmainprogress]                      ;
	;
	MOV	R12,R9                                          ;* v1.43se RasterMan special release (2013)
	LDRB	R0,[R9,#songstatus]                            ;* are we playing the song?
	TST	R0,#4                                           ;*
	BLNE	CIAhandler                                     ;* if so, sort the music first
	;*
	LDRB	R0,[R9,#vustate]                               ;* 1.43se_a 27/5/13
	CMP	R0,#0                                           ;*
	MOVNE	R0,#4                                         ;*
	BLNE	VUcontroller                                   ;*
	LDR	R12,[R9,#DMABuffer]                             ;* v1.45se reload R12
	.endif
	ADD	R8,R9,#DMA_blocks-song_data
	MOV	R6,#0                                           ;put channel count as 0
	LDRB	R5,[R9,#chans_use]
	LDR	R4,[R9,#chanendflags]
a2_TRNSchannels:
	TEQP	PC,#0x8000003
	ADD	R0,R6,#1
	MOV	R1,#0
	STMFD	R13!,{R14}
	SWI	XSound_ReadControlBlock
	LDMFD	R13!,{R14}
	TEQP	PC,#0x8000002
	TST	R2,#0x8000000                                   ;Q  K  I  F  A  V F2 F1
	ADR	R14,a2_TRNSnextchan                             ;v1.48 bug fix...
	BNE	an_TRNSchan                                     ;...ARM3 already fixed, but previous ARM2 code did BLNE then BL
	BL	a2_chanctrl                                      ;...so prioritised QTM over RISC OS, now RISC OS prioritised!
a2_TRNSnextchan:
	STR	R1,[R8,#4]
	MOV	R4,R4,LSR #2
	ADD	R8,R8,#24
	ADD	R12,R12,#1
	ADD	R6,R6,#1
	CMP	R6,R5
	BNE	a2_TRNSchannels
	.if qtmrast
	MOV	R0,#0
	STRB	R0,[R9,#rm_dmainprogress]
	.endif
	LDMFD	R13!,{PC}                                     ;v1.43 removed ^ - to enable Arthur OS compatibility!


	;                       **********************
	;                       ***   Arm 2 code   ***
	;                       **********************


a2_DMAsound:
	STMFD	R13!,{R14}
	SUB	R9,R9,#QTMblock
	STR	R12,[R9,#DMABuffer]
a2_DMAsnd_in:
	LDRB	R0,[R9,#soundflags]
	TST	R0,#8
	BLNE	checkclockcalc
	.if qtmrast
	LDRB	R0,[R9,#rm_dmainprogress]                      ;
	TEQ	R0,#0                                           ;
	LDMNEFD	R13!,{PC}                                   ;* v1.45se RasterMan - quit if DMA alread in progress (reentrant)
	MOV	R0,#1                                           ;
	STRB	R0,[R9,#rm_dmainprogress]                      ;
	;
	MOV	R12,R9                                          ;* v1.43se RasterMan special release (2013)
	LDRB	R0,[R9,#songstatus]                            ;* are we playing the song?
	TST	R0,#4                                           ;*
	BLNE	CIAhandler                                     ;* if so, sort the music first
	;*
	LDRB	R0,[R9,#vustate]                               ;* 1.43se_a 27/5/13
	CMP	R0,#0                                           ;*
	MOVNE	R0,#4                                         ;*
	BLNE	VUcontroller                                   ;*
	LDR	R12,[R9,#DMABuffer]                             ;* v1.45se reload R12
	.endif
	ADD	R8,R9,#DMA_blocks-song_data
	MOVS	R6,#0                                          ;put channel count as 0
	LDRB	R5,[R9,#chans_use]
	LDR	R4,[R9,#chanendflags]
	MOVS	R6,R6,LSL #1                                   ;(move 0>>1 - clear C flag)
a2_DMAchannels:                                      ;relys on C flag CLEAR at this point!!!
	BL	a2_chanctrl
	STRCC	R1,[R8,#4]
a2_DMAnextchan:
	MOV	R4,R4,LSR #2
	ADD	R8,R8,#24
	ADD	R12,R12,#1
	ADD	R6,R6,#1
	CMP	R6,R5                                           ;this will CLEAR the C flag if R6-R5 < 0 (all the time)!
	BNE	a2_DMAchannels
	.if qtmrast
	MOV	R0,#0
	STRB	R0,[R9,#rm_dmainprogress]
	.endif
	LDMFD	R13!,{PC}                                     ;v1.43 removed ^ - to enable Arthur OS compatibility!


a2_chanctrl:
	STMFD	R13!,{R4-R6,R12,R14}
	.if alphatest
	LDR	R14,[R9,#dma_calls]
	ADD	R14,R14,#1
	STR	R14,[R9,#dma_calls]
	.endif
	LDMIA	R8,{R0-R5}                                    ;r0=end addr, r1=-ve offset, r2=pitch, r3=vol/flag, r4=rlen
	CMN	R1,#4096                                        ;is offset >-4096? (ie. offset>>12 <1)?   (remember -ve!)
	MOVGT	R7,#3                                         ; <put min loop len in r7>
	CMPGT	R7,R5                                         ; <backwards!!! this does CMP 3,len so LE if valid!!!)
bgt_a2_chanend:
	BGT	a2_chanend                                      ;if offset>-4096 and 3>repeat len, then exit
	CMP	R0,#0                                           ;v1.45 - huge bug - can't believe address=0 has worked for so long!
	CMPNE	R2,#0
	BLE	a2_chanend
a2_chanrunning:
	MOVS	R3,R3,LSL #24                                  ;if DMA_sampleflag set, CS because &FF shifted off
	ADDCC	R7,R9,#musicvoltable-song_data
	ADDCS	R7,R9,#samplevoltable-song_data
	LDRB	R3,[R7,R3,LSR #24]                             ;load Arc scaled volume
	CMP	R2,#1024                                        ;
	ADDLT	R7,R9,#arcperiods-song_data
	LDRLT	R2,[R7,R2,LSL #2]                             ;load Arc pitch increment
	BLGE	amigatoarcpitch_1024                           ;for high periods, use calculation - returns r2=arc pitch
	MOV	R7,#0b11                                        ;testing flags...
	;** R6 STILL has channel number in it!!! **
	MOV	R6,R6,LSL #1                                    ;channel * 2 (2 flags per channel!)
	MOV	R7,R7,LSL R6                                    ;shift flags << (channel*2)
	LDR	R6,[R9,#chanendflags]                           ;load current channel ending flags
	TST	R6,R7                                           ;are either of the 'ending/ended' bits set?
	BICNE	R6,R6,R7                                      ;if so, clear them, cos this channel IS running!
	STRNE	R6,[R9,#chanendflags]                         ;...and store them
	;v1.45 leave DMAshift for Arm2 machines - fast as possible here
	ADD	R6,R1,R2,LSL #dmashift1                         ;4 * 2013  ;  \
	ADD	R6,R6,R2,LSL #dmashift2                         ;6 * v1.42 ;   } - pitch inc.*dma = DMA length (SHOULD BE!!!)
	ADDS	R6,R6,R2,LSL #dmashift3                        ;7 * =208  ;work out where the offset pointer will be after this fill
	BLT	a2_not_ending                                   ;if still<0 then we haven't ended/looped, so don't check
	CMP	R5,#3                                           ;
	;CMPGE   R4,R0                   ;
	BGE	a2_repeating                                    ;EQ       ;if repeat length>0 AND we've got same addr then use rep...
	CMP	R3,#254                                         ;if volume is too low
	BGE	a2_endnovol                                     ;go to clear the channel...
	CMP	R3,#0                                           ;
	.if alphatest
	LDREQ	R14,[R9,#dma_efv]
	ADDEQ	R14,R14,#1
	STREQ	R14,[R9,#dma_efv]
	.endif
	LDREQ	PC,jmp_a2_endfullvol                          ;if vol is max. use max. vol fill routines
	.if alphatest
	LDR	R14,[R9,#dma_eav]
	ADD	R14,R14,#1
	STR	R14,[R9,#dma_eav]
	.endif
	LDR	PC,jmp_a2_endanyvol


a2_endnovol:
	BL	a2_clearchannel
	MOV	R1,#0                                           ;set offset to 0, so it will call 'chanend' next time
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_repeating:
	CMP	R3,#254                                         ;if volume is too low
	.if alphatest
	LDRGE	R14,[R9,#dma_rnv]
	ADDGE	R14,R14,#1
	STRGE	R14,[R9,#dma_rnv]
	.endif
	LDRGE	PC,jmp_a2_repnovol                            ;go to clear the channel...
	CMP	R3,#0                                           ;
	.if alphatest
	LDREQ	R14,[R9,#dma_rfv]
	ADDEQ	R14,R14,#1
	STREQ	R14,[R9,#dma_rfv]
	.endif
	LDREQ	PC,jmp_a2_repfullvol                          ;if vol is max, use max. fill routines
	.if alphatest
	LDR	R14,[R9,#dma_rav]
	ADD	R14,R14,#1
	STR	R14,[R9,#dma_rav]
	.endif
	LDR	PC,jmp_a2_repanyvol


a2_clearchannel:
	STMFD	R13!,{R6,R14}
	MOV	R6,#0
	.if alphatest
	LDR	R14,[R9,#dma_clc]
	ADD	R14,R14,#1
	STR	R14,[R9,#dma_clc]
	.endif
	LDR	PC,jmp_a2_clearing


a2_not_ending:                                       ;on entry r5 = end offset
	CMP	R3,#254                                         ;volume too low?
	MOVGE	R1,R6                                         ;yup, so put end offset in offset reg...
	BLGE	a2_clearchannel                                ;...and clear the channel!
	LDMGEFD	R13!,{R4-R6,R12,PC}^                        ;...then exit
	CMP	R3,#0                                           ;
	.if alphatest
	LDREQ	R14,[R9,#dma_fv]
	ADDEQ	R14,R14,#1
	STREQ	R14,[R9,#dma_fv]
	.endif
	LDREQ	PC,jmp_a2_fullvolume                          ;max. vol, so use max. routines
	.if alphatest
	LDR	R14,[R9,#dma_an]
	ADD	R14,R14,#1
	STR	R14,[R9,#dma_an]
	.endif
	LDR	PC,jmp_a2_anyvolume


	; channel ending flags
	;                       %11 per channel (should be CLEAR when playing the sample)
	;                       /  \
	;   cleared DMA buffer 1    cleared DMA buffer 2 (so sample has REALLY finished - exit)


a2_chanend:
	LDR	R4,[R13,#0]                                     ;load channel end flags (r4)
	MOVS	R4,R4,LSR #1                                   ;shift off the first bit (REALLY ended test)
	.if alphatest
	LDRCS	R14,[R9,#dma_ce]
	ADDCS	R14,R14,#1
	STRCS	R14,[R9,#dma_ce]
	.endif
	LDMCSFD	R13!,{R4-R6,R12,PC}                         ;if it had 'REALLY ended' then reload (inc. r4) and exit
	BL	a2_clearchannel                                  ;clear this DMA buffer
	LDR	R6,[R13,#8]                                     ;load current channel (-1)
	MOV	R6,R6,LSL #1                                    ;channel*2
	MOVS	R4,R4,LSR #1                                   ;test 2nd bit of channel end flags
	LDR	R4,[R9,#chanendflags]                           ;(+load FULL current flags word, for alteration)
	MOVCC	R5,#0b10                                      ;if 2nd bit was clear, then channel has JUST ended
	MOVCS	R5,#0b01                                      ;if 2nd bit was set, then it ended 1 DMA fill ago (ie.done)
	ORR	R4,R4,R5,LSL R6                                 ;set altered flags in flag word
	STR	R4,[R9,#chanendflags]                           ;store flag word
	LDMFD	R13!,{R4-R6,R12,PC}^                          ;reload+exit WITHOUT C flag set (so new offset is stored)


	;                    ***************************
	;                    *** Sound INIT routines ***
	;                    ***************************


initQTMsound:                                        ;r12=song_data
	STMFD	R13!,{R0-R4,R14}
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1                                           ;are we already switched on?
	LDMNEFD	R13!,{R0-R4,R14}                            ; * v1.42 * bug fix
	BNE	checknewchannels                                ;yup!, but we'ed better make sure the chans are set...then exit
	;(v1.41 did 'BLNE checknewchannels' then 'LDMNEFD...' expecting same flags)
	ORR	R0,R0,#1                                        ;
	STRB	R0,[R12,#soundflags]                           ;set 'we're on now' flag
	BL	readstereos                                      ;read previous users stereo settings
	BL	setDMAblock                                      ;set up the channel handler block (inc. TRNS/DMA control)
	MOV	R0,#0                                           ;
	STR	R0,[R12,#chanendflags]                          ;set 'clear channels' flags
	;v1.45 - read OS settings first, so can set up TSS *before*
	MOV	R1,#0                                           ;        enabling QTM DMA
	MOV	R2,#0                                           ;
	MOV	R3,#0                                           ;
	MOV	R4,#0                                           ;
	SWI	XSound_Configure                                ;        this WILL briefly suffer the OS 3 bug, but QTM takes
	;        over in a sec
	ADD	R4,R12,#oldConfigure
	STMIA	R4,{R0-R3}                                    ;        store old configuration before enabling QTM DMA
	ADD	R4,R12,#QTMblock+8                              ;         - need on Beaglebd
	ADD	R3,R3,#8
	LDMIA	R3,{R0-R1}                                    ;        read conversion tables from OS
	STMIA	R4,{R0-R1}                                    ;        set OS tables in QTM's sound block
	BL	setsoundconfig                                   ;set up the system, and the stereos!
	LDMFD	R13!,{R0-R4,PC}                               ;exit


setsoundconfig:                                      ;sets sound system to current QTM settings (and stereos!)
	STMFD	R13!,{R4,R14}                                 ;returns previous system settings R0-R3 (R4 not required!)
	BL	makeuSok                                         ;this will make sure the sample speed is always ok!
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1
	LDMEQFD	R13!,{R4,PC}                                ;if called from SWI SetSampleSpeed QTM may not be DMA controller
	;exit if QTM isn't active (after checking sample speed ok)!
	LDRB	R1,[R12,#osversion]
	CMP	R1,#0xA3-0xA0
	BLT	doOS2setsound                                   ;OS 2 bug - only sets sample speed if < chans*15.75!
	LDRB	R2,[R12,#current_uS]
noOS2setproblem:
	LDRB	R0,[R12,#chans_use]                            ;
	LDRB	R1,[R12,#current_dma]                          ; * dma size/16
	MOV	R1,R1,LSL #4                                    ; * v1.42 change!
	; - OS 3.xx new comp BUG! <soln. - put R2=uS> - but OS2 bug!
	ADD	R3,R12,#QTMblock                                ;
	MOV	R4,#0                                           ;
	SWI	XSound_Configure                                ;ensure correct settings, and read sound system
	STMFD	R13!,{R2}
	ADD	R2,R12,#QTMstereos                              ;stereo pointer in r2
	BL	setstereos                                       ;set the stereos! (and set actual_dma)
	LDRB	R2,[R12,#soundflags]
	TST	R2,#0x80
	BLNE	recalc_uS_4clock_16bit                         ;JL-not sure how non-16bit version gets by without recalcing
	;   clock speeds here
	;SH-easy, either the calling SWI (setsamplespeed) calls it ;-)
	LDMFD	R13!,{R2,R4,PC}                               ;   or it's set up from initqtm on startup (initVIDCandpitch)


doOS2setsound:
	MOV	R0,#1                                           ;incase of risc os 2 bug (only sets uS<chans*15.75!)
	LDRB	R1,[R12,#current_dma]                          ; * dma size/16
	MOV	R1,R1,LSL #4                                    ; * v1.42 change!
	LDRB	R2,[R12,#current_uS]
	MOV	R3,#0                                           ;don't set handler yet (- not designed for only 1 channel)
	MOV	R4,#0
	SWI	XSound_Configure                                ;this always sets correct sample speed
	STMFD	R13!,{R0-R3}                                  ;put old OS configuration on stack
	LDRB	R0,[R12,#chans_use]
	MOV	R1,#0
	MOV	R2,#0
	ADD	R3,R12,#QTMblock
	MOV	R4,#0
	SWI	XSound_Configure                                ;v1.45 could store 'actual_dma' from R2 here (but n/r on RO2)
	ADD	R2,R12,#QTMstereos                              ;stereo pointer in r2
	BL	setstereos                                       ;set the stereos! (and set actual_dma)
	LDMFD	R13!,{R0-R4,PC}                               ;finally set channels correcty, and stereos, then exit


twangsoundsystem:                                    ;called to 'twang' the system! (for stereos & RISC OS 3 bug)
	STMFD	R13!,{R1-R4,R14}                              ;returns R0=old channels
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1
	BEQ	twangOSsound                                    ;this is for when resetting OS stereos!
	LDRB	R1,[R12,#osversion]
	CMP	R1,#0xA3-0xA0                                   ;read OS
	MOVLT	R2,#0                                         ;don't reset uS if on OS 2 (avoids uS<chans*15.75 bug!)
	LDRGEB	R2,[R12,#current_uS]                         ;** but we MUST reset uS to get round OS 3 bug! **
	LDRB	R0,[R12,#chans_use]                            ;
	LDRB	R1,[R12,#current_dma]                          ; * dma size/16
	MOV	R1,R1,LSL #4                                    ; * v1.42 change!
	; - OS 3.xx new comp BUG! <soln. - put R2=uS> - but messes OS2!
	ADD	R3,R12,#QTMblock                                ;
	MOV	R4,#0                                           ;
	SWI	XSound_Configure                                ;ensure correct settings, and read sound system
	; v1.45 now we store 'actual_dma' size, because on RPi/etc. setting DMA size to 208 doesn't work
	;   reading actual DMA works because we already tried setting to 'current_dma' before we got here
	;   so value returned in R1 is actual value Sound_Configure previously set DMA to when we tried.
	MOV	R1,R1,LSR #4
	STRB	R1,[R12,#actual_dma]                           ;in practice QTM DMA handler will be on for few uS before we set
	LDMFD	R13!,{R1-R4,PC}                               ;this correctly but should be OK as we set to current_dma on init


twangOSsound:
	MOV	R0,#0
	MOV	R1,#0
	MOV	R2,#0
	MOV	R3,#0
	MOV	R4,#0
	SWI	XSound_Configure                                ;this WILL suffer the OS 3 bug, but it's only the OS!!!
	LDMFD	R13!,{R1-R4,PC}


checknewchannels:                                    ;r12=song_data
	STMFD	R13!,{R0-R3,R14}                              ;*bug fix v1.43* previously corrupt R3 (via BL setsoundconfig)!
	BL	setsoundconfig                                   ;sets chans to QTM chans & set stereos, returns old setup *R0-R3*
	LDRB	R1,[R12,#chans_use]                            ;load QTM channels
	CMP	R0,R1                                           ;old chans same as QTM chans? (ie. did we just change no. chans?)
	LDMEQFD	R13!,{R0-R3,PC}                             ;same channels, so exit
	MOV	R0,#0                                           ;** new number of channels ** so we'ed better ensure that
	STR	R0,[R12,#chanendflags]                          ; they are cleared (else they'll buzz!) so clear 'ended'
	;LDRB    R0,[R12,#soundflags]    ;v1.44
	;TST     R0,#%1<<5               ;  |
	;BL      update14or58chans       ;  | if channels changed and using 5-8 for song, update DMA data
	TEQ	R1,#4
	ADDEQ	R0,R12,#DMA_blocks+24*4-song_data
	MOVEQ	R1,#24*4                                      ;...next, if change to 4 chans, wipe DMA data for channels 5-8
	BLEQ	blankmemory                                    ;v1.48 this replaces clearupperchans
	LDMFD	R13!,{R0-R3,PC}


	;.update14or58chans              ;v1.44 call after changing channels or altering bit 5 of soundflags
	;STMFD   R13!,{R0-R12,R14}
	;LDRB    R0,[R12,#soundflags]
	;TST     R0,#%1<<5
	;
	;FNlong_adr("NE",10,DMA_blocks)
	;ADDNE   R11,R10,#24*4           ;if set, copy 1-4 to 5-8
	;FNlong_adr("EQ",11,DMA_blocks)
	;ADDEQ   R10,R11,#24*4           ;if clear, copy 5-8 to 1-4
	;MOV     R9,#4
	;MOV     R7,#0
	;MOV     R8,#0
	;.copymusicchannels
	;LDRB    R0,[R10,#DMA_sampleflag]
	;TEQ     R0,#0
	;LDMEQIA R10,{R1-R6}
	;STMEQIA R11,{R1-R6}
	;MOVEQ   R3,#0 MOVEQ R4,#0 MOVEQ R5,#0 MOVEQ R6,#0
	;STMEQIA R10,{R3-R8}
	;ADD     R10,R10,#24
	;ADD     R11,R11,#24
	;SUBS    R9,R9,#1
	;BGT     copymusicchannels
	;LDMFD   R13!,{R0-R12,PC}        ;v1.44


makeuSok:                                            ;this ensures the sample speed (uS) is ok for the channels
	STMFD	R13!,{R0-R1,R14}                              ;called every time the sample speed is altered!
	LDRB	R0,[R12,#current_uS]
	LDRB	R1,[R12,#chans_use]
	MOV	R14,#0b11                                       ;(updated with v1.30a code on 16/4/2001)
	ORR	R14,R14,R1,LSR #1                               ;R14 now has %111 for 8 channels, %11 for 4 channels
	TST	R0,R14                                          ;any bad bits set in sample speed?
	BIC	R0,R0,R14
	ADDNE	R0,R0,R1                                      ;(eg. for 8 chans, 49 BIC %111 = 48, 48+8 = 56 - ok)
	;
	; minimum uS for n channels is n*3
	;
	ADD	R1,R1,R1,LSL #1                                 ;=R1*3!!! =channels*3 (n+n*2=n*3!)
	CMP	R0,R1
	MOVLT	R0,R1                                         ;R0 now has totally legal uS for this number of channels!
	STRB	R0,[R12,#current_uS]
	LDMFD	R13!,{R0-R1,PC}


setDMAblock:                                         ;this **should** affect the DMA controller in real time...
	STMFD	R13!,{R0-R4,R14}                              ;
	LDRB	R0,[R12,#armchip]                              ;Arm2/3/6 chip
	LDRB	R1,[R12,#soundflags]                           ;load current sound flags (TRNS state is bit1)
	CMP	R0,#3                                           ;was it an Arm3+? (if R0-3 >=0 then C flag is SET)
	TST	R1,#2                                           ;is bit1 of sound flags set (ie.TRNS) (sets Z flag, not C)
qtm_dma_adr0:                                        ;C set               (ie. Arm3+               )
	.long	0x224F0000+((qtm_dma_adr0+8-a3_DMAsound)&0xFF)
	.long	0x22400C00+(((qtm_dma_adr0+8-a3_DMAsound)&0xFF00)>>8)
qtm_dma_adr1:                                        ;C clear             (ie. Arm2                )
	.long	0x324F0000+((qtm_dma_adr1+8-a2_DMAsound)&0xFF)
	.long	0x32400C00+(((qtm_dma_adr1+8-a2_DMAsound)&0xFF00)>>8)
qtm_dma_adr2:                                        ;          Z clear   (ie.           TRNS bit=1)
	.long	0x124F0000+((qtm_dma_adr2+8-a2_TRNSsound)&0xFF)
	.long	0x12400C00+(((qtm_dma_adr2+8-a2_TRNSsound)&0xFF00)>>8)
qtm_dma_adr3:                                        ;C set and Z clear   (ie. Arm3+ and TRNS bit=1) works?????
	.long	0x824F0000+((qtm_dma_adr3+8-a3_TRNSsound)&0xFF)
	.long	0x82400C00+(((qtm_dma_adr3+8-a3_TRNSsound)&0xFF00)>>8)
	ADR	R1,overruncode                                  ;overrun fixup code
	;                               ;R2=OS linear-to-log table
	;                               ;R3=OS log-scale table
	ADD	R2,R12,#QTMblock                                ;address of 'channel handler block'
	STMIA	R2,{R0-R1}                                    ;set up block, except OS tables - done by initQTMsound!
	LDMFD	R13!,{R0-R4,PC}                               ;exit...


overruncode:
	MOV	PC,R14                                          ;apparently unused now


readstereos:
	STMFD	R13!,{R0-R4,R14}
	LDR	R3,[R12,#channelstate]                          ;see DMA filler section before altering c-state
	MOV	R4,#1
	ADD	R2,R12,#oldstereos
	MOV	R0,#1
readstloop:
	TST	R3,R4,LSL R0
	MVNNE	R1,#127
	SWINE	XSound_Stereo
	STRNEB	R1,[R2,R0]                                   ;if QTM's going to use this channel, read and store it's stereo
	ADD	R0,R0,#1                                        ;(^^^ *** should get stereo's using 8 bytes rather than 9 ***)
	CMP	R0,#8
	BLE	readstloop
	LDMFD	R13!,{R0-R4,PC}                               ;all OS stereos read


setstereos:                                          ;set to pointer in r2, r12=song_data
	STMFD	R13!,{R0-R4,R14}
	LDR	R3,[R12,#channelstate]                          ;see DMA filler section before altering c-state
	MOV	R4,#1
	MOV	R0,#1
stereoloop:
	TST	R3,R4,LSL R0                                    ;check channel is in use by QTM
	LDRNEB	R1,[R2,R0]
	MOVNE	R1,R1,LSL #24
	MOVNE	R1,R1,ASR #24                                 ;make 8bit -ve to 32bit -ve value
	SWINE	XSound_Stereo
	ADD	R0,R0,#1
	CMP	R0,#8
	BLE	stereoloop
	BL	twangsoundsystem                                 ;remember to force OS to update (internally) stereos (OS bug?)
	LDMFD	R13!,{R0-R4,PC}


resetsound:                                          ;r12=song_data
	STMFD	R13!,{R0-R4,R11,R14}
	LDRB	R0,[R12,#soundflags]
	TST	R0,#1
	LDMEQFD	R13!,{R0-R4,R11,PC}                         ;QTM wasn't using the sound system
	BIC	R0,R0,#1
	STRB	R0,[R12,#soundflags]                           ;clear sound flags, so next DMA buffer will clear next interrupt
	LDRB	R0,[R12,#chans_use]
	LDRB	R1,[R12,#actual_dma]                           ;dma/16
	MOV	R1,R1,LSL #4                                    ;*16
	MUL	R1,R0,R1                                        ;v1.45 this should reduce pops on the Pi
	LDR	R0,[R12,#DMABuffer]                             ;-added for F-00 crash bug (maybe due to v1.30a bug^^) fix12/9/97
	BL	blankmemory                                      ;clear *current* DMA buffer incase no interrupt before switch-off
	ADD	R1,R12,#oldConfigure+4
	LDMIA	R1,{R1-R3}
	MOV	R0,#1                                           ;only set uS with 1 chan active (bug only in RO2)
	MOV	R4,#0
	SWI	XSound_Configure                                ;*** USED TO DO THIS BEFORE BUFFER CLEAR, ok??? *** 16/4/2001
	LDRB	R0,[R12,#oldConfigure]                         ;ok to set chans now
	BL	clearoldSCCB
	MOV	R1,#0
	MOV	R2,#0                                           ;OS 3.xx new comp BUG! But unlikely to affect OS settings!
	MOV	R3,#0
	MOV	R4,#0
	SWI	XSound_Configure                                ;r0=old chans
	ADD	R2,R12,#oldstereos
	BL	setstereos                                       ;reset stereos to OS settings
	LDMFD	R13!,{R0-R4,R11,PC}


clearoldSCCB:                                        ;r0=chans to clear
	STMFD	R13!,{R0-R4,R14}
	MOV	R4,R0
	MOV	R1,#12
clearSCCBloop:
	MOV	R0,R4
	MOV	R2,#0
	SWI	XSound_WriteControlBlock
	SUBS	R4,R4,#1
	BNE	clearSCCBloop
	LDMFD	R13!,{R0-R4,PC}



amigatoarcpitch_1024:                                ;R2=amiga note (>=1024) to convert, returns R2=arc pitch
	STMFD	R13!,{R0-R1,R3-R11,R14}                       ; called by DMA and VU code only, and both use
	LDR	R10,Amiga_multiplier                            ; R9=block ptr (not R12!)
	LDR	R9,[R9,#actual_uS]                              ;actual uS<<12
	;MOV     R7,#19       ;default accuracy is 19bits
	;CMP     R2,#2        ;from amiga pitch 2, use 18bit accuracy
	;MOVGE   R7,#18
	;CMP     R2,#3        ;from amiga pitch 3, use 17bit
	;MOVGE   R7,#17
	;CMP     R2,#6        ;from amiga pitch 6, use 16bit
	;MOVGE   R7,#16
	;CMP     R2,#11       ;from amiga pitch 11, use 15bit
	;MOVGE   R7,#15
	;CMP     R2,#22       ;from amiga pitch 22, use 14bit
	;MOVGE   R7,#14
	;CMP     R2,#43       ;from amiga pitch 43, use 13bit
	;MOVGE   R7,#13
	;CMP     R2,#86       ;from amiga pitch 86, use 12bit
	;MOVGE   R7,#12
	;CMP     R2,#172      ;from amiga pitch 172, use 11bit
	;MOVGE   R7,#11
	;CMP     R2,#344      ;from amiga pitch 344, use 10bit
	;MOVGE   R7,#10
	;CMP     R2,#688      ;from amiga pitch 688, use 9bit
	;MOVGE   R7,#9
	MOV	R7,#9                                           ;default accuracy is 9bits
	CMP	R2,#1376                                        ;from amiga pitch 1376, use 8bit
	MOVGE	R7,#8
	CMP	R2,#2752                                        ;from amiga pitch 2752, use 7bit (next would be from 5504, 6bit)
	MOVGE	R7,#7
	RSB	R6,R7,#30                                       ;30-x
	MOV	R0,R10
	MOV	R1,R2
	BL	r0_div_r1
	MOV	R0,R0,LSR R7
	MOV	R1,R9
	MUL	R0,R1,R0
	MOV	R2,R0,LSR R6
	LDMFD	R13!,{R0-R1,R3-R11,PC}


Amiga_multiplier:
	.long	0xE3005235                                    ;PAL timing! ((7093789.2/2*1024)/1E6)*2^20!!! - unsigned
	;v1.44 corrected, but error was insignificant so no difference

	.p2align 2
reinit_arcpitch:                                     ;R0 = amiga note to convert
	STMFD	R13!,{R0-R1,R8-R11,R14}
	ADD	R11,R12,#arcperiods-song_data
	LDR	R10,Amiga_multiplier
	LDR	R9,[R12,#actual_uS]                             ;actual uS<<12
	;MOV     R9,#(32*4096 AND &FF0000)
	;ADD  R9,R9,#(32*4096 AND &00FF00)
	;ADD  R9,R9,#(32*4096 AND &0000FF)
	MOV	R8,#1                                           ;amiga pitch counter into 1024 table
	MOV	R7,#19                                          ;default accuracy is 19bits
workouttable:
	CMP	R8,#2                                           ;from amiga pitch 2, use 18bit accuracy
	MOVGE	R7,#18
	CMP	R8,#3                                           ;from amiga pitch 3, use 17bit
	MOVGE	R7,#17
	CMP	R8,#6                                           ;from amiga pitch 6, use 16bit
	MOVGE	R7,#16
	CMP	R8,#11                                          ;from amiga pitch 11, use 15bit
	MOVGE	R7,#15
	CMP	R8,#22                                          ;from amiga pitch 22, use 14bit
	MOVGE	R7,#14
	CMP	R8,#43                                          ;from amiga pitch 43, use 13bit
	MOVGE	R7,#13
	CMP	R8,#86                                          ;from amiga pitch 86, use 12bit
	MOVGE	R7,#12
	CMP	R8,#172                                         ;from amiga pitch 172, use 11bit
	MOVGE	R7,#11
	CMP	R8,#344                                         ;from amiga pitch 344, use 10bit
	MOVGE	R7,#10
	CMP	R8,#688                                         ;from amiga pitch 688, use 9bit (next would be from 1376, 8bit)
	MOVGE	R7,#9
	RSB	R6,R7,#30                                       ;30-x
	MOV	R0,R10
	MOV	R1,R8
	BL	r0_div_r1
	MOV	R0,R0,LSR R7
	MOV	R1,R9
	MUL	R0,R1,R0
	MOV	R0,R0,LSR R6
	STR	R0,[R11,R8,LSL #2]
	ADD	R8,R8,#1
	CMP	R8,#1024
	BLT	workouttable
	LDMFD	R13!,{R0-R1,R8-R11,PC}


readclock:
	.long	172
	.long	-1


	.p2align 2
recalc_uS_4clock:                                    ;Note - Don't use if 16bit sound available!
	STMFD	R13!,{R0-R6,R14}
	ADR	R0,readclock
	ADD	R1,R12,#numberbuf_new-song_data
	SWI	XOS_ReadVduVariables                            ;OS 2.00 (and below?) returns 0 as clock speed
	LDR	R0,[R1]                                         ;v1.48 moved answer to databank
	LDR	R1,[R12,#clockspeed]
	CMP	R0,R1                                           ;if NE, VIDC is clocked differently to what OS thinks!
	BNE	oldVIDCcalc                                     ; - so calculate as for an old machine with VIDC enhancer
newVIDCcalc:
	LDR	R2,[R12,#shiftclock]
	LDRB	R3,[R12,#current_uS]
	LDRB	R4,[R12,#chans_use]
	MOV	R5,#24
	MUL	R0,R2,R3
	MUL	R1,R4,R5
	BL	r0_div_r1
	MOV	R6,R0,LSR #12
	MUL	R6,R4,R6
	MOV	R0,R6,LSL #22
	MOV	R1,R2,LSR #2
	BL	r0_div_r1
	MUL	R0,R5,R0
	LDR	R1,[R12,#actual_uS]
	CMP	R0,R1
	STRNE	R0,[R12,#actual_uS]
	BLNE	reinit_arcpitch
	LDMFD	R13!,{R0-R6,PC}


oldVIDCcalc:
	MOV	R0,#0xC0000000                                  ;&C0000000 = 24*4096*4096*8
	LDR	R1,[R12,#shiftclock]
	MOV	R1,R1,LSR #2                                    ;make shiftclock from <<12 to <<10
	BL	r0_div_r1                                        ;24*4096*4096*8/(actual clock speed*1024)
	LDRB	R1,[R12,#current_uS]
	MUL	R0,R1,R0                                        ;*wanted us = real uS<<17
	MOV	R0,R0,LSR #5                                    ;real uS<<12 = 'actual_uS'
	LDR	R1,[R12,#actual_uS]
	CMP	R0,R1
	STRNE	R0,[R12,#actual_uS]
	BLNE	reinit_arcpitch
	LDMFD	R13!,{R0-R6,PC}


recalc_uS_4clock_16bit:                              ;JL-Only use if 16bit sound available!
	STMFD	R13!,{R0-R3,R14}
	MOV	R0,#1
	SWI	XSound_6                                        ;v1.42 fix, was XSound_SampleRate - RO3.6+ only
	; R2 = sample rate in Hz, *1024
	; We want sample period in uS, *4096
	; period=1000000*1024*4096/R2
	MOV	R0,#0xF4000
	ORR	R0,R0,#0x240                                    ; =1000000
	MOV	R1,#22
	MOV	R3,#0
	; cheapo division loop, relies on R0<R2
recalc16bit_loop:
	RSBS	R0,R2,R0,LSL #1
	ADC	R3,R3,R3
	ADDLO	R0,R0,R2
	SUBS	R1,R1,#1
	BNE	recalc16bit_loop
	LDR	R0,[R12,#actual_uS]
	CMP	R0,R3
	STRNE	R3,[R12,#actual_uS]
	BLNE	reinit_arcpitch
	LDMFD	R13!,{R0-R3,PC}


checkclockcalc:                                      ;does this ever get called by >ARM3? (does it really need 32bit?)
	STMFD	R13!,{R0-R12,R14}                             ;...probably not! Should only be called by pre-A5000 computers!
	MOV	R12,R9
	LDR	R2,[R12,#DMAinterrupts]
	ADD	R2,R2,#1
	STR	R2,[R12,#DMAinterrupts]
	TEQ	PC,PC
	.long	0x010F9000                                    ; FNmrs("EQ","R9,CPSR")
	MOVNE	R9,PC
	ORREQ	R8,R9,#0x83                                   ; SVC, no interrupts
	ORRNE	R8,R9,#0x8000003
	.long	0x0121F008                                    ; FNmsr("EQ","CPSR_c,R8")
	TEQNEP	R8,#0
	MOV	R0,R0
	STMFD	R13!,{R14}
	SWI	XOS_ReadMonotonicTime
	LDMFD	R13!,{R14}
	TEQ	PC,PC
	.long	0x0121F009                                    ; Restore original mode (IRQ, no interrupts)
	TEQNEP	R9,#0
	MOV	R0,R0
	LDR	R1,[R12,#ClockCalcEnd]
	CMP	R1,#0
	BEQ	initclockcalc                                   ;if "ClockCalcEnd" is 0, we're just starting out, so set up!
	CMP	R0,R1
	BGE	doclockcalc                                     ;if we've we're reached the end - let's do calculation
	LDMFD	R13!,{R0-R12,PC}


initclockcalc:                                       ;R0=current time, R2=DMAinterrupts
	ADD	R0,R0,#20
	STR	R0,[R12,#ClockCalcEnd]                          ;set quick calc end time to 200mS (20cS) for initial calculation
	LDRB	R0,[R12,#soundflags]
	ORR	R0,R0,#0x10                                     ;set bit 4 for 'quick calc'
	STRB	R0,[R12,#soundflags]
	LDMFD	R13!,{R0-R12,PC}


doclockcalc:                                         ;R0=current time, R2=DMAinterrupts
	MOV	R6,#0                                           ;use R6 as flag for quick calc or not!
	LDRB	R1,[R12,#soundflags]
	TST	R1,#0x10
	BICEQ	R1,R1,#8                                      ;if 'quick calc' clear, we're at end of full calc, so clear flag!
	BEQ	continuecalc
	BIC	R1,R1,#0x10                                     ;if we get here we're at end of quick calc, so set full calc
	ADD	R0,R0,#100
	STR	R0,[R12,#ClockCalcEnd]                          ;set full calc end time for 1 second (100cS)
	MOV	R0,#0
	STR	R0,[R12,#DMAinterrupts]                         ;clear DMAinterrupts *why?* could add these to full for 1.2s calc
	MOV	R0,#5
	MUL	R2,R0,R2                                        ;for quick calc (20cS), use 5 * DMAinterrupts (for 100cS)
	MOV	R6,#1                                           ;flag as now doing a quick calc
continuecalc:
	STRB	R1,[R12,#soundflags]                           ;update sound flags, altered above
	MOV	R0,#24*dma                                      ;v1.42 this now allows for varying DMA sizes, prev. fixed at 4992
	MUL	R2,R0,R2                                        ;v1.49 must change "*dma" to multiply by current_dma for RM!!!
	LDRB	R0,[R12,#current_uS]
	MUL	R0,R2,R0
	MOV	R1,#1000                                        ;dividing by 1000mS (change to 1200mS if add quick calc to full)
	BL	r0_div_r1                                        ;R0=clock speed, in KHz (ie. 25175KHz for 25.175MHz)
	MOV	R1,#0xBB00
	ADD	R1,R1,#0x80
	MOV	R2,#0x9C00
	ADD	R2,R2,#0x40
	CMP	R0,R2
	MOVLT	R1,#0x8C00
	ADDLT	R1,R1,#0xA0
	MOV	R2,#0x7500
	ADD	R2,R2,#0x30
	CMP	R0,R2
	MOVLT	R1,#0x6200
	ADDLT	R1,R1,#0x57
	MOV	R2,#0x6000
	ADD	R2,R2,#0xE0
	CMP	R0,R2
	MOVLT	R1,#0x5D00
	ADDLT	R1,R1,#0xC0                                   ;R1 has our estimated real clock speed!!!
	LDR	R2,[R12,#clockspeed]
	CMP	R2,R1
	LDMEQFD	R13!,{R0-R12,PC}
	CMP	R6,#1                                           ;quick calc?
	MOVEQ	R3,#0x5D00
	ADDEQ	R3,R3,#0xC0
	CMPEQ	R3,R2
	MOVEQ	R3,#0x6200
	ADDEQ	R3,R3,#0x57
	CMPEQ	R3,R1                                         ;give up if quick calc and current = 24MHz but new = 25.175MHz
	LDMEQFD	R13!,{R0-R12,PC}                            ;(quick calc routine isn't accurate enough for this!)
	STR	R1,[R12,#clockspeed]
	.if qtmrast
	;v1.49 bug fix (used R0 for clockspeed, should be R1!)
	AND	R0,R1,#0xFF00                                   ;v1.43se for RasterMan... adjust CIA dec value for VGA or other
	CMP	R0,#0x6200                                      ;are we currently 25175MHz? (well anywhere between 25088-25343)
	MOVNE	R0,#0x10000                                   ;if not, use CIA decrement value for 24/36/48MHz
	MOVEQ	R0,#0xF400                                    ;if 25175MHz then..
	ORREQ	R0,R0,#0x000D                                 ;..use CIA dec value for 25175MHz [CIAdec is n/r for normal QTM]
	STR	R0,[R12,#rm_CIAdec]                             ;store
	.endif
	MOV	R0,R1,LSL #12                                   ;R1 is still clockspeed at this point
	MOV	R1,#1000
	BL	r0_div_r1
	STR	R0,[R12,#shiftclock]
	TEQ	PC,PC                                           ;v1.49 this should only be called from ARM2/ARM3 no need for 32b
	.long	0x010F9000                                    ; FNmrs("EQ","R9,CPSR")
	MOVNE	R9,PC
	ORREQ	R8,R9,#0x83                                   ; SVC, no interrupts
	ORRNE	R8,R9,#0x8000003
	.long	0x0121F008                                    ; FNmsr("EQ","CPSR_c,R8")
	TEQNEP	R8,#0                                        ;we have to be in svc if 'recalc_uS_4clock' is called (for SWIs)
	MOV	R0,R0
	STMFD	R13!,{R14}
	BL	recalc_uS_4clock
	LDMFD	R13!,{R14}
	TEQ	PC,PC
	.long	0x0121F009                                    ; Back to original mode (IRQ, no interrupts)
	TEQNEP	R9,#0
	MOV	R0,R0
	LDMFD	R13!,{R0-R12,PC}


	; v1.48 test ARM2/3 unroll loops on loading


a2_jumptable:                                        ;**THIS EDITS MODULE** should move to RMA...
jmp_a2_endanyvol:
	.long	0                                             ;*
jmp_a2_endfullvol:
	.long	0                                             ;*
jmp_a2_repanyvol:
	.long	0                                             ;*
jmp_a2_repfullvol:
	.long	0                                             ;*
jmp_a2_repnovol:
	.long	0                                             ;*
jmp_a2_clearing:
	.long	0                                             ;*
jmp_a2_anyvolume:
	.long	0                                             ;*
jmp_a2_fullvolume:
	.long	0                                             ;*
	.long	0                                             ;terminate with 0-word

	;.rm_a2_endanyvol_unroll ;div 4
	; -> ADR     R14,endanyvol_loop  ;ADD/SUB R14,PC,#0
	;LDRB    R6,[R0,R1,ASR#12]       ;*** sample HAS to end this time ***
	;
	;.endanyvol_loop
	;SUBS    R6,R6,R3
	;MOVMI   R6,#0
	;STRB    R6,[R12],R11
	;ADDS    R1,R1,R2                ;CS if -ve cleared, VS if +ve gets too large (becomes -ve)
	;LDRLTB  R6,[R0,R1,ASR#12]
	;MOVGE   R6,#0                   ;v1.48 optimised to avoid BGE a2_clearend
	;
	; -> CMP     R12,R10
	; -> MOVLT   PC,R14
	;LDMFD   R13!,{R4-R6,R12,PC}^


a2_endanyvol_unroll:                                 ;code must be unrolled before use!
	.if qtmrast
	.p2align 2
	ADR	R14,a2_endanyvol_loop
	.endif
	LDRB	R6,[R0,R1,ASR #12]                             ;*** sample HAS to end this time ***
a2_endanyvol_loop:
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2                                       ;CS if -ve cleared, VS if +ve gets too large (becomes -ve)
	LDRLTB	R6,[R0,R1,ASR #12]
	MOVGE	R6,#0                                         ;v1.48 optimised to avoid BGE a2_clearend
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_endfullvol_unroll:
	.if qtmrast
	ADR	R14,a2_endfullvol_loop
	.endif
	CMP	R11,#0x0FF00000                                 ;ensure LT flags are set (r11 is ALWAYS <&0FF00000 chans!)
a2_endfullvol_loop:
	LDRLTB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11
	ADDLTS	R1,R1,R2
	MOVGE	R6,#0                                         ;put data=0 after sample has ended
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_repanyvol_unroll:
	.if qtmrast
	ADR	R14,a2_repanyvol_loop
	.endif
a2_repanyvol_loop:
	LDRB	R6,[R4,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12                              ;********** ron addr
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_repfullvol_unroll:
	.if qtmrast
	ADR	R14,a2_repfullvol_loop
	.endif
a2_repfullvol_loop:
	LDRB	R6,[R4,R1,ASR #12]
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12                              ;********** ron addr
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_repnovol_unroll:
	MOV	R6,#0
	.if qtmrast
	ADR	R14,a2_repnovol_loop
	.endif
a2_repnovol_loop:
	STRB	R6,[R12],R11
	ADDS	R1,R1,R2
	SUBGE	R1,R1,R5,LSL #12
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	STR	R4,[R8,#DMA_address]                            ;store repeat address as DMA address now!
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_clearing_unroll:
	.if qtmrast
	ADR	R14,a2_clearing_loop
	.endif
a2_clearing_loop:
	STRB	R6,[R12],R11
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	LDMFD	R13!,{R6,PC}^


a2_anyvolume_unroll:
	.if qtmrast
	ADR	R14,a2_anyvol_loop
	.endif
a2_anyvol_loop:
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11
	ADD	R1,R1,R2
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	LDMFD	R13!,{R4-R6,R12,PC}^


a2_fullvolume_unroll:
	.if qtmrast
	ADR	R14,a2_fullvol_loop
	.endif
a2_fullvol_loop:
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11
	ADD	R1,R1,R2
	.if qtmrast
	CMP	R12,R10
	MOVLT	PC,R14
	.endif
	LDMFD	R13!,{R4-R6,R12,PC}^


unroll_a2_DMA:
	STMFD	R13!,{R1-R2,R14}
	ADR	R1,unroll_table
	ADR	R0,a2_endanyvol_unroll
	BL	unroll_code
	STRVC	R0,jmp_a2_endanyvol
	ADRVC	R0,a2_endfullvol_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_endfullvol
	ADRVC	R0,a2_repanyvol_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_repanyvol
	ADRVC	R0,a2_repfullvol_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_repfullvol
	ADRVC	R0,a2_repnovol_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_repnovol
	ADRVC	R0,a2_clearing_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_clearing
	ADRVC	R0,a2_anyvolume_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_anyvolume
	ADRVC	R0,a2_fullvolume_unroll
	BLVC	unroll_code
	STRVC	R0,jmp_a2_fullvolume
	LDMFD	R13!,{R1-R2,PC}


release_a2_DMA:
	STMFD	R13!,{R0-R2,R14}
	ADR	R1,a2_jumptable
release_a2_loop:
	LDR	R0,[R1],#4
	TEQ	R0,#0
	LDMEQFD	R13!,{R0-R2,PC}^
	BL	releaseRMA
	BVC	release_a2_loop
	STR	R0,[R13,#0]
	LDMFD	R13!,{R0-R2,PC}


unroll_code:
	STMFD	R13!,{R2-R10,R14}                             ;r0=unroll addr, r1=unroll table; return r0=RMA addr, r1=next tab
	MOV	R9,R0                                           ;copy from addr
	MOV	R14,R1                                          ;temp store R1 (table) in R14
	MOV	R0,#0
unroll_findsize:
	LDR	R3,[R1],#4
	ANDS	R2,R3,#0xFF                                    ;number insts
	MOVNE	R3,R3,LSR #8                                  ;number reps
	MOVNE	R2,R2,LSL #2                                  ;size of insts
	MLANE	R0,R3,R2,R0                                   ;size of unrolled
	BNE	unroll_findsize
	MOV	R1,R14                                          ;restore R1 to top of this decode data table
	BL	claimRMA                                         ;R0=size in bytes
	LDMVSFD	R13!,{R2-R10,PC}
	MOV	R7,R0                                           ;destination addr
unroll_block:
	LDR	R8,[R1],#4
	TEQ	R8,#0                                           ;number insts and repeats, =0 if end of entry
	LDMEQFD	R13!,{R2-R10,PC}
	MOV	R6,R8,LSR #8                                    ;r6=number reps
unroll_codeloop:
	MOV	R4,R9                                           ;r4=copy from address
	AND	R5,R8,#0xFF                                     ;r5=number insts to copy per loop
unroll_copyinsts:
	LDR	R3,[R4],#4
	STR	R3,[R7],#4
	SUBS	R5,R5,#1
	BGT	unroll_copyinsts
	SUBS	R6,R6,#1
	BGT	unroll_codeloop
	MOV	R9,R4                                           ;next inst to copy
	B	unroll_block




unroll_table:                                        ;a2_endanyvol_unroll
	.long	0x102                                         ;rep 1 time, first inst, if qtmrast% add 1 more inst (ADR R14)
	.long	0x6806                                        ;repeat dmarep times (208 for non-RM QTM), 6 insts
	.long	0x103                                         ;rep 1 time, 1 inst, if qtmrast% add 2 more insts (CMP, MOVLT)
	.long	0
	.long	0x102                                         ;a2_endfullvol_unroll, if qtmrast% add 1 more inst (ADR R14)
	.long	0x6804
	.long	0x103                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.if qtmrast
	.long	0x101                                         ;repeat 1 time, first 1 inst (ADR R14,loop)
	.endif
	.long	0x6806                                        ;a2_repanyvol_unroll
	.long	0x104                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.if qtmrast
	.long	0x101                                         ;repeat 1 time, first 1 inst (ADR R14,loop)
	.endif
	.long	0x6804                                        ;a2_repfullvol_unroll
	.long	0x104                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.long	0x102                                         ;a2_repnovol_unroll, if qtmrast% add 1 more inst (ADR R14)
	.long	0x6803
	.long	0x104                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.if qtmrast
	.long	0x101                                         ;repeat 1 time, first 1 inst (ADR R14,loop)
	.endif
	.long	0x6801                                        ;a2_clearing_unroll
	.long	0x103                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.if qtmrast
	.long	0x101                                         ;repeat 1 time, first 1 inst (ADR R14,loop)
	.endif
	.long	0x6805                                        ;a2_anyvolume_unroll
	.long	0x103                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0
	.if qtmrast
	.long	0x101                                         ;repeat 1 time, first 1 inst (ADR R14,loop)
	.endif
	.long	0x6803                                        ;a2_fullvolume_unroll
	.long	0x103                                         ;if qtmrast% this adds 2 more insts (CMP, MOVLT PC,R14)
	.long	0


