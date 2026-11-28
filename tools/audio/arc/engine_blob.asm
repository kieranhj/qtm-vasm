; engine_blob -- the part of the sound-test engine copied into the RMA: the channel
; handler block, the fill state, the fill routine, then the phases' segment lists.
;
; Segment record (12 bytes): count (word, 0 = end of list), type (byte: 0 square,
; 1 table), A, B, pad, then a word: the half period for a square, or the table's offset
; from blob_start for a table. A table is its length (word) then that many codes.
;
; Fill: R9 = block (= blob base), R10 = buffer end, R11 = gap (channels), R12 = start.
; With more than one channel the buffer is first filled with the background code, then
; the playing slot is written at R12 + slot, every R11 bytes.

	.p2align 2
blob_start:
	.skip	80

fill:
	STMFD	R13!,{R0-R8,R14}
	LDR	R0,[R9,#ST_PEND]
	CMP	R0,#0
	BEQ	no_pend
	LDR	R0,[R9,#ST_PSEQ]
	MOV	R1,#0
	ADD	R8,R9,#ST_REGS
	STMIA	R8,{R0,R1}			; next record, nothing left of the current one
	MOV	R0,#0
	STR	R0,[R9,#ST_DONE]
	STR	R0,[R9,#ST_PEND]
no_pend:
	CMP	R11,#1
	BLS	no_bg
	LDR	R1,[R9,#ST_BG]
	MOV	R0,R12
bg_fill:
	STR	R1,[R0],#4
	CMP	R0,R10
	BLO	bg_fill
	LDR	R0,[R9,#ST_SLOT]
	ADD	R12,R12,R0
no_bg:
	ADD	R8,R9,#ST_REGS
	LDMIA	R8,{R0-R7}
loop:	CMP	R12,R10
	BHS	out
	SUBS	R1,R1,#1
	BMI	next_seg
emit:	TEQ	R7,#0
	BNE	tab
	STRB	R3,[R12],R11
	SUBS	R2,R2,#1
	BNE	loop
	TEQ	R3,R4
	MOVEQ	R3,R5
	MOVNE	R3,R4
	MOV	R2,R6
	B	loop
tab:	LDRB	R3,[R4,R2]
	STRB	R3,[R12],R11
	ADD	R2,R2,#1
	CMP	R2,R5
	MOVHS	R2,#0
	B	loop

next_seg:
	LDR	R1,[R0],#4
	CMP	R1,#0
	BEQ	seq_end
	LDRB	R7,[R0],#1
	LDRB	R4,[R0],#1
	LDRB	R5,[R0],#1
	ADD	R0,R0,#1
	LDR	R6,[R0],#4
	TEQ	R7,#0
	MOVEQ	R3,R4
	MOVEQ	R2,R6
	ADDNE	R4,R9,R6
	LDRNE	R5,[R4],#4
	MOVNE	R2,#0
	LDR	R8,[R9,#ST_INDEX]
	ADD	R8,R8,#1
	STR	R8,[R9,#ST_INDEX]
	SUB	R1,R1,#1
	B	emit

seq_end:					; silence until the next phase
	SUB	R0,R0,#4
	MVN	R1,#0x80000000
	MOV	R7,#0
	MOV	R3,#0
	MOV	R4,#0
	MOV	R5,#0
	MOV	R6,#0x10000
	MOV	R2,R6
	MOV	R8,#1
	STR	R8,[R9,#ST_DONE]
	B	emit

out:	ADD	R8,R9,#ST_REGS
	STMIA	R8,{R0-R7}
	LDMFD	R13!,{R0-R8,PC}

overrun:
	MOV	PC,R14
