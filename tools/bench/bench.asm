; Standalone mixer-loop benchmark for an 8MHz ARM2 (OPTIMISATION.md step 5).
;
; Measures the candidate inner loops in isolation, before committing to the
; qtm_play.asm changes Turbo needs.  The question is whether lane packing is
; worth what the clock-count model says (-16%) or what the memory-traffic
; argument says (-25%); MEASUREMENTS.md shows the ARM2 runs the real mixer at
; 1.54-2.16x its textbook timing, so only measurement settles it.
;
; Each test fills one DMA buffer -- 4 channels x 208 samples, interleaved with
; stride 4, exactly QTM's layout -- and repeats that R3 times.
;
; Entry (BBC BASIC CALL puts A%..H% in R0..R7):
;   R0 = test number   R1 = dest buffer (832 bytes)
;   R2 = sample bank   R3 = repeat count
;
; The four channels read from regions 8K apart so the DRAM page behaviour is
; representative; reading them all from one page would flatter the packed
; loops, which is the whole thing being measured.

	.equ	FILL,208                ; samples per channel per fill
	.equ	INC,0xD00               ; 0.8125 in 20.12 -- a typical increment
	.equ	VOL,0x30                ; log-domain volume subtract
	.equ	CHANSTEP,0x2000000      ; 8192 bytes, in 20.12

bench:
	STMFD	R13!,{R0-R12,R14}
	MOV	R8,R1                   ; dest
	MOV	R9,R2                   ; bank
	MOV	R10,R3                  ; reps
	CMP	R0,#0
	BEQ	t_anyvol
	CMP	R0,#1
	BEQ	t_fullvol
	CMP	R0,#2
	BEQ	t_packed
	CMP	R0,#3
	BEQ	t_packed_pre
	CMP	R0,#4
	BEQ	t_packed8
	B	t_packed26

; ---------------------------------------------------------------- test 0
; QTM as it stands: any-volume, one strided pass per channel.
; LDRB 3 + SUBS 1 + MOVMI 1 + STRB 2 + ADD 1 = 8 clocks/byte.
t_anyvol:
	MOV	R7,#0
ta_chan:
	ADD	R0,R9,R7,LSL #13        ; channel base
	ADD	R0,R0,#0x1000           ; ...+4096 = "sample end"
	MOV	R1,#0xFF000000          ; offset -4096 bytes, in 20.12
	MOV	R2,#INC
	MOV	R3,#VOL
	ADD	R12,R8,R7               ; dest = buffer + channel
	MOV	R11,#4                  ; stride = channel count
	.rept	FILL
	LDRB	R6,[R0,R1,ASR #12]
	SUBS	R6,R6,R3
	MOVMI	R6,#0
	STRB	R6,[R12],R11
	ADD	R1,R1,R2
	.endr
	ADD	R7,R7,#1
	CMP	R7,#4
	BLT	ta_chan
	SUBS	R10,R10,#1
	BGT	t_anyvol
	B	done

; ---------------------------------------------------------------- test 1
; QTM's full-volume path, for reference: 6 clocks/byte.
t_fullvol:
	MOV	R7,#0
tf_chan:
	ADD	R0,R9,R7,LSL #13
	ADD	R0,R0,#0x1000
	MOV	R1,#0xFF000000
	MOV	R2,#INC
	ADD	R12,R8,R7
	MOV	R11,#4
	.rept	FILL
	LDRB	R6,[R0,R1,ASR #12]
	STRB	R6,[R12],R11
	ADD	R1,R1,R2
	.endr
	ADD	R7,R7,#1
	CMP	R7,#4
	BLT	tf_chan
	SUBS	R10,R10,#1
	BGT	t_fullvol
	B	done

; ---------------------------------------------------------------- test 2
; Turbo Form A: one interleaved pass, four bytes ORRed into a word and stored
; once.  Volume is an immediate -- patched at tick rate in the real thing --
; which is what frees the four volume registers.  ORRPL does the silence clamp
; for free, since contributing nothing to the lane *is* zero.
; MOV 1 + 4x(LDRB 3 + SUBS 1 + ORRPL 1 + ADD 1) + STR 2 = 27 per 4 bytes
;                                                       = 6.75 clocks/byte.
t_packed:
	MOV	R0,R9                   ; shared bank base
	MOV	R1,#0                   ; four absolute 20.12 offsets into the bank
	MOV	R2,#CHANSTEP
	MOV	R3,#CHANSTEP * 2
	MOV	R4,#CHANSTEP * 3
	MOV	R5,#INC
	MOV	R6,#INC
	MOV	R7,#INC
	MOV	R11,#INC
	MOV	R12,R8                  ; dest
	.rept	FILL
	MOV	R14,#0
	LDRB	R10,[R0,R1,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R14,R14,R10
	ADD	R1,R1,R5
	LDRB	R10,[R0,R2,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R14,R14,R10,LSL #8
	ADD	R2,R2,R6
	LDRB	R10,[R0,R3,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R14,R14,R10,LSL #16
	ADD	R3,R3,R7
	LDRB	R10,[R0,R4,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R14,R14,R10,LSL #24
	ADD	R4,R4,R11
	STR	R14,[R12],#4
	.endr
	LDR	R10,[R13,#12]           ; reps back off the stack (R10 was reused)
	SUBS	R10,R10,#1
	STR	R10,[R13,#12]
	BGT	t_packed
	B	done

; ---------------------------------------------------------------- test 3
; Turbo with prescaled samples: no volume subtract, no clamp.
; MOV 1 + 4x(LDRB 3 + ORR 1 + ADD 1) + STR 2 = 23 per 4 bytes = 5.75/byte.
t_packed_pre:
	MOV	R0,R9
	MOV	R1,#0
	MOV	R2,#CHANSTEP
	MOV	R3,#CHANSTEP * 2
	MOV	R4,#CHANSTEP * 3
	MOV	R5,#INC
	MOV	R6,#INC
	MOV	R7,#INC
	MOV	R11,#INC
	MOV	R12,R8
	.rept	FILL
	MOV	R14,#0
	LDRB	R10,[R0,R1,LSR #12]
	ORR	R14,R14,R10
	ADD	R1,R1,R5
	LDRB	R10,[R0,R2,LSR #12]
	ORR	R14,R14,R10,LSL #8
	ADD	R2,R2,R6
	LDRB	R10,[R0,R3,LSR #12]
	ORR	R14,R14,R10,LSL #16
	ADD	R3,R3,R7
	LDRB	R10,[R0,R4,LSR #12]
	ORR	R14,R14,R10,LSL #24
	ADD	R4,R4,R11
	STR	R14,[R12],#4
	.endr
	LDR	R10,[R13,#12]
	SUBS	R10,R10,#1
	STR	R10,[R13,#12]
	BGT	t_packed_pre

; ---------------------------------------------------------------- test 4
; Turbo Form A as it would actually have to be built.
;
; Tests 2 and 3 unroll all 208 words, which cannot work in the real player:
; the volume immediates have to be patched every fill, and 208 words x 4
; channels is 832 patch sites -- as much work as the fill itself.  Unrolling
; by 8 and looping cuts that to 32 sites, at the cost of one counter register
; and a branch every 8 words.
;
; This is also the real register allocation, and it uses all 14:
;   R0 bank  R1-R4 offsets  R5-R8 increments  R9 dest
;   R10 scratch  R11 output word  R12 inner count  R14 outer count
; R13 is left alone, which is the constraint OPTIMISATION 3.2.1 originally
; missed.
t_packed8:
	MOV	R14,R10                 ; reps
tp8_rep:
	MOV	R0,R9                   ; bank base   (R9 still holds bank here)
	MOV	R9,R8                   ; dest
	MOV	R1,#0
	MOV	R2,#CHANSTEP
	MOV	R3,#CHANSTEP * 2
	MOV	R4,#CHANSTEP * 3
	MOV	R5,#INC
	MOV	R6,#INC
	MOV	R7,#INC
	MOV	R8,#INC
	MOV	R12,#FILL / 8
tp8_inner:
	.rept	8
	MOV	R11,#0
	LDRB	R10,[R0,R1,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10
	ADD	R1,R1,R5
	LDRB	R10,[R0,R2,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #8
	ADD	R2,R2,R6
	LDRB	R10,[R0,R3,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #16
	ADD	R3,R3,R7
	LDRB	R10,[R0,R4,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #24
	ADD	R4,R4,R8
	STR	R11,[R9],#4
	.endr
	SUBS	R12,R12,#1
	BNE	tp8_inner
	MOV	R8,R9                   ; restore dest/bank for the next rep
	SUB	R8,R8,#FILL * 4
	MOV	R9,R0
	SUBS	R14,R14,#1
	BGT	tp8_rep

; ---------------------------------------------------------------- test 5
; The same, unrolled by 26 instead of 8 (208 = 26 x 8, so the loop runs 8
; times).  Test 4 lost far more to its branch than the 4 cycles/iteration the
; timings predict, because a taken branch breaks sequential instruction fetch
; and with it MEMC's page mode.  If that is the cause, a longer body should
; recover most of it -- and 26 x 4 = 104 volume patch sites per fill is still
; affordable, where 832 is not.
t_packed26:
	MOV	R14,R10
tp26_rep:
	MOV	R0,R9
	MOV	R9,R8
	MOV	R1,#0
	MOV	R2,#CHANSTEP
	MOV	R3,#CHANSTEP * 2
	MOV	R4,#CHANSTEP * 3
	MOV	R5,#INC
	MOV	R6,#INC
	MOV	R7,#INC
	MOV	R8,#INC
	MOV	R12,#FILL / 26
tp26_inner:
	.rept	26
	MOV	R11,#0
	LDRB	R10,[R0,R1,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10
	ADD	R1,R1,R5
	LDRB	R10,[R0,R2,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #8
	ADD	R2,R2,R6
	LDRB	R10,[R0,R3,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #16
	ADD	R3,R3,R7
	LDRB	R10,[R0,R4,LSR #12]
	SUBS	R10,R10,#VOL
	ORRPL	R11,R11,R10,LSL #24
	ADD	R4,R4,R8
	STR	R11,[R9],#4
	.endr
	SUBS	R12,R12,#1
	BNE	tp26_inner
	MOV	R8,R9
	SUB	R8,R8,#FILL * 4
	MOV	R9,R0
	SUBS	R14,R14,#1
	BGT	tp26_rep

done:
	LDMFD	R13!,{R0-R12,PC}

; Measured on an A3000 (ARM2 8MHz, MODE 0), 10 fills per test, 8320 bytes:
;
;   test                                cycles  cyc/byte  vs test 0
;   0  QTM any-volume (today)           114360    13.75      --
;   1  QTM full-volume                   92256    11.09    -19.3%
;   2  Turbo Form A, unrolled x208       85595    10.29    -25.2%
;   3  Turbo prescaled,  unrolled x208   80089     9.63    -30.0%
;   4  Turbo Form A, unrolled x8 + loop  96549    11.60    -15.6%
;   5  Turbo Form A, unrolled x26 + loop 86048    10.34    -24.8%
;
; Full unrolling is not buildable -- 208 words x 4 channels is 832 volume
; patch sites per fill.  Unrolling by 8 makes that 32 but costs 12.8%,
; because a taken branch breaks sequential instruction fetch and MEMC's page
; mode with it.  Unrolling by 26 comes within 0.5% of full unrolling with 104
; patch sites, and is the shape to build.
;
; See MEASUREMENTS.md step 5.
