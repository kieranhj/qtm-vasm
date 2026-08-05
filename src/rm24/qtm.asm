; QTM v1.49b -- top level.  Generated from PROCassm in the driver by
; tools/mktoplevel.py; do not hand-edit.
;
; The original assembles at P%=0 into a pre-zeroed 63K buffer with O%=code%, so
; module addresses are relative to the module base: .org 0 with -Fbin.  The
; include order below is PROCassm's own, and is what fixes the module layout.

	.include "qtm_offsets.h.asm"
	.include "swis.h.asm"

	.org 0

	.include "qtm_mod.asm"                              ;QTM_Mod  (incl. timer code and VU code)
	.include "qtm_play.asm"                             ;QTM_Play (v1.48 datablocks now at the end of module)
	.include "qtm_song.asm"                             ;QTM_Song
	.include "qtm_dma.asm"                              ;QTM_DMA


	; Trial of improved and shorter looped DIV code

	; on entry - R0=A +ve; R1=B +ve >0
	; on exit - R0=A DIV B; R1=A MOD B

	;R0=num
	;R1=den
	;R2=cnt
	;R3=mod

	; seems to equal the unrolled AU div routine when dividing large 32 bit numbers by 512+

r0_div_r1:
	STMFD	R13!,{R1-R3,R14}
	MOV	R2,#28
	MOV	R3,R0,LSR #4
	CMP	R1,R3,LSR #12
	SUBLE	R2,R2,#16
	MOVLE	R3,R3,LSR #16
	CMP	R1,R3,LSR #4
	SUBLE	R2,R2,#8
	MOVLE	R3,R3,LSR #8
	CMP	R1,R3
	SUBLE	R2,R2,#4
	MOVLE	R3,R3,LSR #4
	MOV	R0,R0,LSL R2
	RSB	R14,R1,#0
	ADDS	R0,R0,R0
	RSB	R2,R2,#32
divloo:
	ADCS	R3,R14,R3,LSL #1
	SUBLO	R3,R3,R14
	ADCS	R0,R0,R0
	ADCS	R3,R14,R3,LSL #1
	SUBLO	R3,R3,R14
	ADCS	R0,R0,R0
	ADCS	R3,R14,R3,LSL #1
	SUBLO	R3,R3,R14
	ADCS	R0,R0,R0
	ADCS	R3,R14,R3,LSL #1
	SUBLO	R3,R3,R14
	ADCS	R0,R0,R0
	SUB	R2,R2,#4
	TEQ	R2,#0
	BNE	divloo
	;MOV   R1,R3
	LDMFD	R13!,{R1-R3,PC}
	;FNAUdiv                         ;assembles R0/R1 -> R0 (*** UNSIGNED!!! ***)
	;MOV     PC,R14


	; Arm type detect v2.60, (c) Phoenix 1995
	;           updated by Jeffrey Lee to avoid clash with bug in FPE module 4.12-4.31 (2000-2013)
	;
	; On entry
	;           -
	;           * Only call from SVC mode *
	; On exit
	;           R0 = processor type (Arm 2, 3 or 6 - for Arm600 and above)


armcheck:                                            ;v2.60 by Phoenix  / updated by Jeffrey Lee
	MOVS	R0,#0                                          ;- sets 'Z' (EQ) flag in CPSR
	.long	0xE10F0000                                    ;MRS R0,CPSR  ;Arm 2/3 decodes as 'TST PC,R0'
	.p2align 2
	CMP	R0,#0
	MOVNE	R0,#6
	MOVNE	PC,R14                                        ;32bit will always exit here
	STMFD	R13!,{R1-R3,R14}
	MOV	R0,#0x8000003
	TEQP	R0,#0                                          ;no interrupts, as we temporarily poke the undefined inst vector
	MOV	R3,#4
	LDR	R1,addpclr4
	LDR	R2,[R3]                                         ;get current vector
	STR	R1,[R3]                                         ;replace with "ADD PC,LR,#4"
	MOV	R0,#2                                           ;assume ARM2
	.long	0xEE101F10                                    ;read Arm ID number (designer, manufacture, type, version)
	MOV	R0,#3                                           ;this will only execute on arm3!
	STR	R2,[R3]                                         ;reset to previous handler
	MOV	R1,#3
	TEQP	R1,#0
	LDMFD	R13!,{R1-R3,PC}^                              ;exit 26bit style


addpclr4:
	ADD	PC,R14,#4                                       ;return from undefined inst vector, skipping the instruction
	;which aborted and the next instruction after it

	.include "qtm_data.asm"                             ;QTM_Data

endcode:
